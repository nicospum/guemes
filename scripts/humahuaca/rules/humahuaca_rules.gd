extends RefCounted
## HumahuacaRules: las reglas del nivel «humahuaca» (CONTRATO 3.2). Dueña: reglas_historia. Clase real de R1, con el mundo fijo y las 9 acciones de la ronda.
## Misma filosofía que GameRules (paso fijo de 0,25 s, RNG congruencial propio, eventos, `state` serializable) sin heredar sus constantes ni sus ramas: las cinco
## agrupaciones, los tres frentes, el reloj con noche, alba y día, la señal con sus contrapesos (la oscuridad cuesta y esperar la luz también), la sorpresa de 45 s,
## la torre del cuartel (12 descargas de 7,5 s), el botín en 5 clases que suma 100, el refuerzo y las 8 causas de derrota.
## Cada número sale de data/humahuaca_rules.json y data/humahuaca_level.json (nada se repite acá); los hitos, de data/humahuaca_map.json. El terreno real
## (HumahuacaTerrain) pone la velocidad, los muros y la visión: las rutas son de A* sobre su grilla de navegación (humahuaca_nav.gd) y la detección de los
## centinelas y el fuego de la torre piden línea de visión. Sin terreno real usa el de respaldo y, sin ninguno, un plano a +17 m sin muros.
##
## Partes: las consultas de solo lectura (hud_state, render_state, campaign_report, planes) viven en humahuaca_rules_info.gd y el guardado y la validación en
## humahuaca_rules_save.gd, para que cada archivo quede por debajo de las ~1 500 líneas del contrato; la API pública sigue toda acá.
## Determinismo: RNG congruencial propio (`rng_state`), nunca azar ni reloj del sistema. Los puntos de `state` son {x, z}; el rumbo `yaw_deg` va de 0 (norte, -z) a
## 90 (este, +x). Independencia (V19): importa vocabularios, datos, navegación e info/guardado de su propia carpeta; el terreno lo carga por ruta en tiempo de ejecución.
## Convenciones: `list_actions("scout"|"train")` suma «Mover» (el arreo llega a la posta con `move`); «Salir por el este» exige que el arreo lleve algo (no hay carga
## gratis: lo que se entrega se cargó, mula por mula, y eso cuesta tiempo); `retreat_all()` funciona siempre.

const V = preload("res://scripts/humahuaca/humahuaca_vocab.gd")
const R = preload("res://scripts/humahuaca/rules/vocab_rules.gd")
const D = preload("res://scripts/humahuaca/rules/humahuaca_data.gd")
const Nav = preload("res://scripts/humahuaca/rules/humahuaca_nav.gd")
const Info = preload("res://scripts/humahuaca/rules/humahuaca_rules_info.gd")
const Save = preload("res://scripts/humahuaca/rules/humahuaca_rules_save.gd")
const Setup = preload("res://scripts/humahuaca/rules/humahuaca_setup.gd")
const Field = preload("res://scripts/humahuaca/rules/humahuaca_rules_field.gd")

const SCENARIO := "humahuaca"
const SAVE_VERSION := 1
const STEP := 0.25
const MAX_DT := 60.0
const LOG_MAX := R.LOG_MAX
const TERRAIN_REAL := "res://scripts/humahuaca/terrain/humahuaca_terrain.gd"
const TERRAIN_STUB := "res://scripts/humahuaca/stubs/stub_terrain.gd"
const FLAT_HEIGHT_M := 17.0  # el plano del terreno de respaldo (cota del templo sobre el cero local)

var state: Dictionary = {}
var _rules: Dictionary = {}
var _level: Dictionary = {}
var _map: Dictionary = {}
var _terrain: RefCounted = null
var _terrain_tried := false
var _nav: RefCounted = null
var _events: Array = []
var _info_inst: Info = null
var _field_inst: Field = null
var _env_key := -1.0
var _env_val: Dictionary = {}

# ---------------------------------------------------------------------------------------------------------------------
# Utilidades

func _init() -> void:
	_rules = D.rules()
	_level = D.level()
	_map = D.map()

func _tx(path: String) -> Variant:
	return D.tx(path)

func _ts(path: String, vars: Dictionary = {}) -> String:
	return D.ts(path, vars)

func _no(key: String, vars: Dictionary = {}) -> Dictionary:
	return {"ok": false, "reason": _ts("errores." + key, vars)}

func _hito_pos(id: String) -> Vector2:
	return D.hito(id)

func _unit(id: String) -> Dictionary:
	for u in state.get("units", []):
		if str(u.id) == id:
			return u
	return {}

func _actor_kind(u: Dictionary) -> String:
	match str(u.kind):
		"reconocedores":
			return "scout"
		"arreo":
			return "train"
	return "group"

func _is_combat(u: Dictionary) -> bool:
	return V.COMBAT_GROUPS.has(str(u.id))

func _bump() -> void:
	state.render_version = int(state.get("render_version", 0)) + 1

func _set_phase(phase: String) -> void:
	if str(state.phase) != phase:
		state.phase = phase
		_bump()

func _event(kind: String, text: String, extra: Dictionary = {}) -> void:
	if not R.EVENT_KINDS.has(kind):
		kind = "info"
	var e := {"time": float(state.get("elapsed", 0.0)), "round": 1, "text": text, "kind": kind}
	for k in extra:
		e[k] = extra[k]
	(state.log as Array).append(e)
	state.pacing_last.events = int(state.pacing_last.events) + 1
	if (state.log as Array).size() > LOG_MAX:
		state.log = (state.log as Array).slice((state.log as Array).size() - LOG_MAX)
	_events.append(e.duplicate(true))

## Un paso del generador congruencial (0, 1). Es el único azar de las reglas.
func _random() -> float:
	state.rng_state = (int(state.rng_state) * 48271) % 2147483647
	return float(state.rng_state) / 2147483647.0

# ---------------------------------------------------------------------------------------------------------------------
# Datos y terreno

func map_data() -> Dictionary:
	return D.merged()

func terrain() -> RefCounted:
	if _terrain == null and not _terrain_tried:
		_terrain_tried = true
		for path in [TERRAIN_REAL, TERRAIN_STUB]:
			if not ResourceLoader.exists(path):
				continue
			var script: Variant = load(path)
			if not (script is Script) or not (script as Script).can_instantiate():
				continue
			var inst: Variant = null
			for m in (script as Script).get_script_method_list():
				if str(m.name) == "load_default":
					inst = script.call("load_default")
			if inst == null:
				inst = script.new()
			if inst is RefCounted:
				_terrain = inst
				break
	return _terrain

## El controlador le da el terreno que eligió (el real o el mínimo) cuando esa capa corre en respaldo. new_game también lo acepta en opts.terrain.
func set_terrain(t: RefCounted) -> void:
	_terrain = t
	_terrain_tried = true
	_nav = null

## La grilla de navegación del terreno (caché por terreno); null si no hay terreno o no entrega nav_grid().
func nav() -> RefCounted:
	if _nav == null:
		_nav = Nav.for_terrain(terrain())
	return _nav

func map_size() -> Vector2:
	return D.map_size()

func terrain_height_at(x: float, z: float) -> float:
	var t := terrain()
	if t != null and t.has_method("height_at"):
		return float(t.call("height_at", x, z))
	return FLAT_HEIGHT_M

## El mundo de una semilla: las dimensiones activas (variants.active, las ACTIVE_DIMS del vocabulario) se sortean con un congruencial propio de la semilla; las
## inactivas quedan en variants.fixed. Determinista y sin azar de Godot. Las constantes de mezcla (variants.seed_mix) están elegidas para que las semillas de
## calibración cubran cada valor ≥ 2 veces, cada mitad de la compuerta ≥ 3 y las 60 del QA ≥ 3, para que la semilla 1817 (el mundo guiado) dé el mundo fijo y la 7
## (la de las pruebas de interfaz) una guardia descuidada.
func world_from_seed(seed_value: int) -> Dictionary:
	var variants: Dictionary = _rules.get("variants", {})
	var world: Dictionary = (variants.get("fixed", {}) as Dictionary).duplicate(true)
	world["loot"] = (variants.get("loot_fixed", {}) as Dictionary).duplicate(true)
	var dims: Dictionary = variants.get("dimensions", {})
	var mix: Dictionary = variants.get("seed_mix", {})
	var h := (absi(seed_value) * int(mix.get("mult", 1735)) + int(mix.get("add", 7))) % 2147483647
	for dim in variants.get("active", []):
		if not dims.has(dim) or not R.VARIANTS.has(dim):
			continue
		var values: Array = dims[dim].values
		h = (h * 48271 + 12345) % 2147483647
		var pick: Variant = values[(h >> 8) % values.size()]
		if (R.VARIANTS[dim] as Array).has(pick):
			world[dim] = pick
	return world

# ---------------------------------------------------------------------------------------------------------------------
# Nueva partida

func new_game(seed_value: int = 1817, attempt: int = 1, opts: Dictionary = {}) -> Dictionary:
	_events = []
	_env_key = -1.0
	if _rules.is_empty() or _level.is_empty():
		state = {}
		return {}
	if opts.get("terrain", null) is RefCounted:
		set_terrain(opts.terrain)
	if seed_value > 2147483647 or seed_value < -2147483647:
		seed_value = posmod(seed_value, 2147483647)  # una semilla fuera del rango del esquema se pliega (el RNG ya reduce módulo 2³¹−1): la partida se puede guardar (C-1)
	var world := Setup.make_world(world_from_seed(seed_value), opts)
	state = {
		"schema_version": SAVE_VERSION, "game_id": "humahuaca-%d-%d" % [seed_value, maxi(1, attempt)], "state_version": 1, "scenario": SCENARIO,
		"map_id": "humahuaca", "map_version": int(_rules.get("map_version", 1)), "contract": V.CONTRACT,
		"seed": seed_value, "rng_state": maxi(1, absi(seed_value) % 2147483647), "attempt": maxi(1, attempt), "elapsed": 0.0, "accumulator": 0.0,
		"status": "playing", "reason": "", "phase": "briefing", "resistencia": false, "world": world,
		"alarm": {"level": 0.0, "first_shot_at": -1.0, "signaled": false, "signal_at": -1.0, "messenger": "none", "reinforcement_at": -1.0, "reinforcement_arrived": false, "pre_signal": []},
		"objectives": Setup.make_objectives(), "units": Setup.make_units(), "loot": Setup.make_loot(world),
		"recon": {"geometry": true, "fronts": []},
		"stats": {"start_strength": {}, "detections": 0, "losses": 0.0, "support_events": 0, "horses_lost": 0, "powder_wet": 0,
			"pacing": {"decision_gap_max_s": 0.0, "decision_gap_attack_max_s": 0.0, "first_decision_s": -1.0, "events_per_min": 0.0, "visible_actions_t0": 4},
			"charges_total": 0, "charges_in_gap": 0},
		"log": [], "orders": [], "pacing_last": {"offer": -1.0, "gap_start": 0.0, "attack_gap_start": -1.0, "events": 0}, "fire_lines": [], "outcome": {}, "render_version": 1,
		"decision": {}, "decisions_done": [],
		"smoke_used": 0, "smoke_adv": 0.0,
		"mercy_level": clampi(int(opts.get("mercy_level", 0)), 0, 3),
		"assists": (opts.get("assists", []) as Array).duplicate() if opts.get("assists", []) is Array else [],
		"diary_marks": (opts.get("diary_marks", []) as Array).duplicate(true) if opts.get("diary_marks", []) is Array else []}
	for u in state.units:
		state.stats.start_strength[u.id] = float(u.strength)
	_apply_start(opts)
	return state

## opts.phase / opts.skip_intro: arranca en otra fase sin guiones de 200 s (para pruebas y capturas).
func _apply_start(opts: Dictionary) -> void:
	var phase := str(opts.get("phase", ""))
	if phase == "" and bool(opts.get("skip_intro", false)):
		phase = "aproximacion"
	if phase == "" or phase == "briefing" or not R.PHASES.has(phase) or phase == "epilogo":
		return
	_set_phase("aproximacion")
	if phase == "aproximacion":
		return
	var starts: Dictionary = _rules.time.phase_starts
	state.elapsed = float(starts.ataque)
	for g in V.COMBAT_GROUPS:
		var u := _unit(g)
		var posts: Array = _level.access.attack_posts[str(_rules.groups[g].front)]
		u.x = float(posts[0].x)
		u.z = float(posts[0].z)
		u.stage = "waiting_signal"
		u.order = {"action": "position", "front": str(_rules.groups[g].front)}
	_fire_signal(false)
	var arreo := _unit("arreo")  # el arreo ya llegó a la posta, como en la partida guiada
	var gate := _hito_pos("posta") + Vector2(0.0, 30.0)
	arreo.x = gate.x
	arreo.z = gate.y
	if phase == "ataque":
		return
	state.elapsed = float(starts.extraccion)
	var idx := 0
	for fid in V.OBJECTIVES:
		_capture(fid)
		state.objectives[fid].taken_at = float(state.elapsed) - 30.0 * float(idx)
		idx += 1
	for g in V.COMBAT_GROUPS:
		_unit(g).strength = 80.0
	_set_phase("extraccion")

# ---------------------------------------------------------------------------------------------------------------------
# Reloj

func tick(dt: float) -> Array:
	if state.is_empty() or str(state.status) != "playing" or not is_finite(dt):  # un dt NaN o infinito no avanza el reloj (A-09)
		return _take_events()
	var remaining := clampf(dt, 0.0, MAX_DT)
	if remaining > 0.0:
		_ensure_started()
	state.accumulator = float(state.accumulator) + remaining
	while float(state.accumulator) >= STEP - 1e-9 and str(state.status) == "playing":
		state.accumulator = maxf(0.0, float(state.accumulator) - STEP)  # el paso se consume con tolerancia: el resto nunca queda negativo (A-07)
		_step()
	return _take_events()

## Solo pruebas y QA: avanza el reloj hasta `t` sin dar órdenes.
func advance_to(t: float) -> Array:
	var all: Array = []
	var guard := 0
	while not state.is_empty() and str(state.status) == "playing" and float(state.elapsed) + STEP <= t + 1e-9 and guard < 100000:
		all.append_array(tick(minf(MAX_DT, t - float(state.elapsed))))
		guard += 1
	return all

func _take_events() -> Array:
	var out := _events
	_events = []
	return out

func _ensure_started() -> void:
	if str(state.phase) == "briefing":
		_set_phase("aproximacion")
		_event("briefing", _ts("eventos.empieza"))

func _step() -> void:
	state.elapsed = float(state.elapsed) + STEP
	state.state_version = int(state.state_version) + 1
	var t := float(state.elapsed)
	_step_events(t)
	_field()._step_decisions(t)
	_field()._step_spotted(t)
	_step_alert(t)
	_step_units(t)
	_step_combat(t)
	_step_tower(t)
	_step_reinforcement(t)
	_step_fire_lines(t)
	state.resistencia = bool(state.objectives.cuartel.tower.active) or (str(state.phase) == "ataque" and not _all_taken())
	_check_end(t)
	if str(state.status) == "playing" and int(roundf(t / STEP)) % 4 == 0:
		_note_offers(t)

func _step_events(t: float) -> void:
	for id in _rules.field_events:
		var fe: Dictionary = _rules.field_events[id]
		if fe.has("at_s") and t >= float(fe.at_s) and t - STEP < float(fe.at_s):
			_event("dawn" if id == "alba" else "info", str(fe.texto), {"field_event": id})
			_bump()

func _all_taken() -> bool:
	for fid in V.OBJECTIVES:
		if str(state.objectives[fid].state) != "tomado":
			return false
	return true

# ---------------------------------------------------------------------------------------------------------------------
# Ritmo: las ofertas de decisión (stats.pacing). Una oferta es un «siguiente paso» con algo para hacer, una alerta con botón o una decisión pendiente; la brecha
# es el tiempo seguido sin ninguna. Se mide una vez por segundo de juego. La medida de decisiones significativas la hace tools/humahuaca_playthrough.gd.

func _note_offers(t: float) -> void:
	_record_offer(t, _info().offer_now())

## Una orden dada es una oferta que existía: cuenta como decisión posible aunque el «siguiente paso» ya no la muestre cuando se mide (el jugador se le adelantó).
func _record_offer(t: float, offered: bool) -> void:
	var pace_stats: Dictionary = state.stats.pacing
	var last: Dictionary = state.pacing_last
	var attacking := str(state.phase) == "ataque"
	if attacking and float(last.attack_gap_start) < 0.0:
		last.attack_gap_start = t
	if offered:
		if float(pace_stats.first_decision_s) < 0.0:
			pace_stats.first_decision_s = t
		pace_stats.decision_gap_max_s = maxf(float(pace_stats.decision_gap_max_s), t - float(last.gap_start))
		if attacking:
			pace_stats.decision_gap_attack_max_s = maxf(float(pace_stats.decision_gap_attack_max_s), t - float(last.attack_gap_start))
		last.gap_start = t
		last.attack_gap_start = t if attacking else -1.0
		last.offer = t
	else:
		pace_stats.decision_gap_max_s = maxf(float(pace_stats.decision_gap_max_s), t - float(last.gap_start))
		if attacking:
			pace_stats.decision_gap_attack_max_s = maxf(float(pace_stats.decision_gap_attack_max_s), t - float(last.attack_gap_start))
	pace_stats.events_per_min = 60.0 * float(int(last.events)) / maxf(t, 60.0)

# ---------------------------------------------------------------------------------------------------------------------
# Ambiente

## La curva sale de rules.environment.segments. `time_of_day` pasa por las cinco muestras de VP-01 (ADDENDA A-07 y A-08): 0 a los 0 y 240 s, 0,5 a los 285 s,
## 0,67 a los 330 s y 1 a los 420 s (`day_full_s`). Una partida pasiva termina a los 390 s por `amanecio` y su reloj se detiene ahí: para medir la muestra de
## 420 s hay que fijar `state.elapsed` o tener la señal dada. Antes de new_game vale lo que vale el instante 0.
func environment() -> Dictionary:
	if state.is_empty():
		if not _rules.is_empty() and (_rules.get("environment", {}) as Dictionary).has("segments"):
			return _env_at(0.0)
		return {"phase": "noche", "time_of_day": 0.0, "rain": 0.9, "visibility_m": 35.0, "mud": 0.55, "firearm_reliability": 0.55}
	return _env_at(float(state.elapsed))

func _env_at(t: float) -> Dictionary:
	if t == _env_key:
		return _env_val
	var cfg: Dictionary = _rules.environment
	var segments: Array = cfg.segments
	var seg: Dictionary = segments[segments.size() - 1]
	for s in segments:
		if t >= float(s.from_s) and t < float(s.to_s):
			seg = s
			break
	var span := maxf(float(seg.to_s) - float(seg.from_s), 0.001)
	var f := clampf((t - float(seg.from_s)) / span, 0.0, 1.0)
	var mud := float(cfg.mud_start)
	if t > float(cfg.mud_dry_from_s):
		mud = maxf(0.0, mud - float(cfg.mud_dry_per_s) * (t - float(cfg.mud_dry_from_s)))
	_env_val = {"phase": str(seg.phase), "time_of_day": lerpf(float(seg.time_of_day[0]), float(seg.time_of_day[1]), f), "rain": lerpf(float(seg.rain[0]), float(seg.rain[1]), f),
		"visibility_m": lerpf(float(seg.visibility_m[0]), float(seg.visibility_m[1]), f), "mud": mud,
		"firearm_reliability": lerpf(float(seg.firearm_reliability[0]), float(seg.firearm_reliability[1]), f)}
	_env_key = t
	return _env_val

## 0 en plena oscuridad (visibilidad de la noche) y 1 con luz (visibilidad de 100 m o más): la rampa de rules.stealth.dark_cost.
func _light_k() -> float:
	var dc: Dictionary = _rules.stealth.dark_cost
	var vis := float(environment().visibility_m)
	return clampf((vis - float(dc.ramp_from_m)) / (float(dc.ramp_to_m) - float(dc.ramp_from_m)), 0.0, 1.0)

## 1 con luz y `assault_min` en plena oscuridad: la noche cuesta poder de asalto (DISENO 2).
func _dark_factor() -> float:
	return lerpf(float(_rules.stealth.dark_cost.assault_min), 1.0, _light_k())

## Puntería del fuego propio: 1 con luz y `aim_min` en plena oscuridad, por la fiabilidad de las armas de chispa respecto de la del alba (la lluvia las moja a los dos bandos).
func _fire_factor() -> float:
	var dc: Dictionary = _rules.stealth.dark_cost
	return lerpf(float(dc.aim_min), 1.0, _light_k()) * _reliability_rel()

func _reliability_rel() -> float:
	return clampf(float(environment().firearm_reliability) / float(_rules.combat.reliability_ref), 0.0, 1.0)

## La humedad con que se mide el suelo: la lluvia que cae o el barro que queda, lo que sea más.
func _wet_rain() -> float:
	var env := environment()
	return clampf(maxf(float(env.rain), float(env.mud)), 0.0, 1.0)

# ---------------------------------------------------------------------------------------------------------------------
# Alerta, detección y desvelo

func _vis_mult_at(fid: String) -> float:
	return float(_rules.stealth.detection.tower_height_mult) if fid == "bateria" or (fid == "cuartel" and bool(state.objectives.cuartel.tower.armed)) else 1.0

## Lo que cambia con la guardia del mundo (enemy.guard.<descuidada|atenta>): cuánto ven los centinelas, cuánto dura la sorpresa y cuánto rinde contra el cuartel.
func _guard_cfg() -> Dictionary:
	var guard: Dictionary = (_rules.get("enemy", {}) as Dictionary).get("guard", {})
	return guard.get(str(state.world.guardia), {}) if not state.is_empty() else {}

func _detect_mult() -> float:
	return float(_guard_cfg().get("detect_mult", 1.0))

func _surprise_s() -> float:
	return float(_guard_cfg().get("surprise_s", _rules.time.surprise_s))

func _surprise_bonus_max(fid: String) -> float:
	if fid == "cuartel" and _guard_cfg().has("cuartel_surprise_bonus"):
		return float(_guard_cfg().cuartel_surprise_bonus)
	return float(_rules.combat.surprise_bonus_max)

func _sentinel_points(fid: String) -> Array:
	var c := _hito_pos(str(_rules.objectives[fid].hito))
	var out: Array = []
	for s in _rules.objectives[fid].sentinels:
		out.append(Vector2(c.x + float(s.dx), c.y + float(s.dz)))
	return out

## ¿Alguno de los centinelas del frente ve a la agrupación? Cuenta la distancia (visibilidad × (1 + 2 × ruido), ×1,5 en altura) y que ningún muro tape la vista.
func _sentinel_sees(fid: String, u: Dictionary, vis: float) -> bool:
	var reach := vis * (1.0 + float(_rules.stealth.detection.noise_mult) * float(u.noise)) * _vis_mult_at(fid) * _detect_mult()
	var p := Vector2(float(u.x), float(u.z))
	var t := terrain()
	for s in _sentinel_points(fid):
		if p.distance_to(s) >= reach:
			continue
		if t == null or not t.has_method("los") or bool(t.call("los", s, p, 1.8, 1.6)):
			return true
	return false

func _step_alert(t: float) -> void:
	var env := _env_at(t)
	var vis := float(env.visibility_m)
	var drift: Dictionary = _rules.stealth.dawn_drift
	var drift_rate := float(drift.per_s_factor) * vis / float(drift.reference_visibility_m)
	var en: Dictionary = _rules.enemy.alert
	var top := 0.0
	var al: Dictionary = state.alarm
	for fid in V.OBJECTIVES:
		var o: Dictionary = state.objectives[fid]
		if str(o.state) == "tomado":
			continue
		var a := float(o.alert)
		if t >= float(_rules.time.alba_start_s):
			a += drift_rate * STEP
		if float(al.first_shot_at) >= 0.0:
			a = maxf(a, clampf((t - float(al.first_shot_at)) / _surprise_s(), 0.0, 1.0))
		var seen_now := false
		for u in state.units:
			if float(u.noise) <= 0.0 or str(u.stage) == "exited":
				continue
			if _sentinel_sees(fid, u, vis):
				seen_now = true
				a += float(en.detect_gain_per_s) * STEP * (1.0 + float(u.noise))
				if not bool(u.detected) and a >= float(en.alertado_at):
					u.detected = true
					state.stats.detections = int(state.stats.detections) + 1
		a = clampf(a, 0.0, 1.0)
		o.alert = a
		top = maxf(top, a)
		if a >= float(en.alarma_at) and (str(o.state) == "guardado" or str(o.state) == "alertado"):
			_raise_alarm(fid, o, seen_now, t)
		elif a >= float(en.alertado_at) and str(o.state) == "guardado":
			o.state = "alertado"
			_bump()
	al.level = top
	_step_messenger(t)
	_step_spread(t)
	if not bool(al.signaled) and (al.pre_signal as Array).size() >= V.OBJECTIVES.size() and str(state.status) == "playing":
		## Q-207 (QA ronda 2): el parte nombra al frente que DIO LA VOZ (el primero en alarma antes de la señal), no al último al que le llegó: con la guardia atenta la voz
		## corre y el último suele ser la posta aunque a los reconocedores los vieran en la batería
		var first := str((al.pre_signal as Array)[0])
		_finish("defeat", "descubiertos", {"frente": first})

func _noise_of(u: Dictionary, env: Dictionary) -> float:
	var st := str(u.stage)
	var n := 0.0
	if st == "moving" or st == "retreating":
		n = float(_rules.stealth.pace[str(u.pace)].noise)
	elif st == "attacking":
		n = float(_rules.stealth.noise_attacking)
	elif st == "loading":
		n = float(_rules.stealth.noise_loading)
	if n > 0.0 and float(env.rain) >= 0.5:
		n *= float(_rules.stealth.rain_noise_mult)
	return n

func _noise_state(u: Dictionary) -> String:
	var ns: Dictionary = _rules.stealth.noise_states
	var n := float(u.noise)
	if n >= float(ns.los_oyen_from):
		return "los_oyen"
	if n >= float(ns.se_oye_from):
		return "se_oye"
	return "silencio"

## El factor de suelo que el terreno da en (x, z): barro, pendiente y zanjas. 1 si no hay terreno.
func _ground_factor(x: float, z: float, mounted: bool) -> float:
	var t := terrain()
	if t == null or not t.has_method("speed_factor_at"):
		return 1.0 - float(_rules.environment.mud_slow) * float(environment().mud)
	return float(t.call("speed_factor_at", x, z, _wet_rain(), mounted))

## Metros por segundo de una agrupación que marcha con `pace` por (x, z). El vado se cruza a media velocidad (transport.ford_mult), sin sumarse al agua del terreno.
func _speed_at(x: float, z: float, pace: String, mounted: bool) -> float:
	var f := _ground_factor(x, z, mounted)
	if f <= 0.0:  # una esquina de muro que la ruta rozó: se pasa despacio, no se queda clavada la agrupación
		f = float(_rules.stealth.blocked_speed_mult)
	var vado := _hito_pos("vado_este")
	if D.dist(x, z, vado.x, vado.y) < float(_rules.transport.ford_radius_m):
		f = minf(f, float(_rules.transport.ford_mult))
	return maxf(float(_rules.stealth.pace[pace].speed) * f, 0.1)

func _unit_speed(u: Dictionary) -> float:
	return _speed_at(float(u.x), float(u.z), str(u.pace), bool(u.mounted))

func _step_units(t: float) -> void:
	var env := _env_at(t)
	for u in state.units:
		var st := str(u.stage)
		if st == "routed" or st == "exited":
			u.noise = 0.0
			continue
		u.noise = _noise_of(u, env)
		if st == "moving" or st == "retreating":
			u.fatigue = minf(100.0, float(u.fatigue) + float(_rules.stealth.pace[str(u.pace)].fatigue_per_s) * STEP)
			_move_unit(u)
		elif st == "scouting" or st == "loading":
			_work_unit(u)
		else:
			u.fatigue = maxf(0.0, float(u.fatigue) - float(_rules.stealth.rest_fatigue_per_s) * STEP)
		if _is_combat(u) and float(u.strength) <= float(_rules.combat.rout_strength) and str(u.stage) != "routed" and str(u.stage) != "exited":
			var fid := _broken_front(u)  # el frente en pie donde se rompió (no el propio si ya lo había tomado, A-04)
			u.stage = "routed"
			u.order = {}
			u.path = []
			_bump()
			if not _all_taken():
				_finish("defeat", "frente_roto", {"grupo": str(_rules.groups[str(u.id)].phrase), "frente": fid})

## Dónde se rompió una partida: el frente que atacaba o socorría si sigue en pie; si no, el propio si sigue en pie; si no, el frente en pie más cercano.
func _broken_front(u: Dictionary) -> String:
	var ordered := str((u.order as Dictionary).get("front", ""))
	if V.OBJECTIVES.has(ordered) and str(state.objectives[ordered].state) != "tomado":
		return ordered
	var own := str(_rules.groups[str(u.id)].front)
	if str(state.objectives[own].state) != "tomado":
		return own
	var best := own
	var best_d := 1.0e9
	for fid in V.OBJECTIVES:
		if str(state.objectives[fid].state) == "tomado":
			continue
		var c := _hito_pos(str(_rules.objectives[fid].hito))
		var d := D.dist(float(u.x), float(u.z), c.x, c.y)
		if d < best_d:
			best_d = d
			best = fid
	return best

func _move_unit(u: Dictionary) -> void:
	var path: Array = u.path
	if path.is_empty():
		_arrive(u)
		return
	var budget := _unit_speed(u) * STEP
	while budget > 0.0 and not path.is_empty():
		var tgt: Dictionary = path[0]
		var dx := float(tgt.x) - float(u.x)
		var dz := float(tgt.z) - float(u.z)
		var d := sqrt(dx * dx + dz * dz)
		if d <= budget:
			u.x = float(tgt.x)
			u.z = float(tgt.z)
			budget -= d
			path.pop_front()
		else:
			u.x = float(u.x) + dx / d * budget
			u.z = float(u.z) + dz / d * budget
			u.yaw_deg = rad_to_deg(atan2(dx, -dz))
			budget = 0.0
	if path.is_empty():
		_arrive(u)

func _arrive(u: Dictionary) -> void:
	var action := str(u.order.get("action", ""))
	var front := str(u.order.get("front", ""))
	u.path = []
	match action:
		"position":
			if bool(state.alarm.signaled):
				_start_attack(u, front)
			else:
				u.stage = "waiting_signal"
				_bump()
		"attack":
			_start_attack(u, front)
		"support":
			_start_support(u, front)
		"recon":
			u.stage = "scouting"
			u.work = {"kind": "recon", "remaining_s": float(_rules.stealth.recon.duration_s)}
		"leave":
			_exit_unit(u)
		"destroy":  # Q-203: la cadena de destruir llegó caminando al lote siguiente del frente
			var nxt := _item(str(u.order.get("item", "")))
			var chain_front := str(u.order.get("front", ""))
			u.stage = "idle"
			u.order = {}
			if not nxt.is_empty() and str(nxt.state) == "en_sitio" and D.dist(float(u.x), float(u.z), float(nxt.x), float(nxt.z)) <= float(_rules.transport.destroy_radius_m):
				_start_destroy(u, nxt)
			else:
				_continue_destroy(u, chain_front)
			_bump()
		_:
			u.stage = "idle"
			u.order = {}
			_bump()

func _work_unit(u: Dictionary) -> void:
	var w: Dictionary = u.work
	if w.is_empty():
		u.stage = "idle"
		return
	w.remaining_s = float(w.remaining_s) - STEP
	if float(w.remaining_s) > 0.0:
		return
	var kind := str(w.kind)
	u.work = {}
	u.stage = "idle"
	u.order = {}
	match kind:
		"recon":
			_complete_recon(u)
		"load":
			_complete_load(u, str(w.item))
		"destroy":
			var it_front := str(_item(str(w.item)).get("front", ""))
			_complete_destroy(u, str(w.item))
			_continue_destroy(u, it_front)
	_bump()

## Q-203: la cadena de destruir (humahuaca_rules_field.gd).
func _continue_destroy(u: Dictionary, front: String) -> void:
	_field()._continue_destroy(u, front)

func _start_destroy(u: Dictionary, it: Dictionary) -> void:
	_field()._start_destroy(u, it)

# ---------------------------------------------------------------------------------------------------------------------
# Señal, ataque y toma

func signal_info() -> Dictionary:
	var in_position: Array = []
	var waiting: Array = []
	for g in V.COMBAT_GROUPS:
		var u := _unit(g)
		if u.is_empty():
			continue
		var st := str(u.stage)
		if st == "waiting_signal" or st == "attacking" or st == "holding":
			in_position.append(g)
		elif st != "routed" and st != "exited":
			waiting.append(g)
	var c := _check_signal()
	var dark := 1.0 - _light_k()
	var drift := 0.0  # el desvelo corre con el reloj: de 0 en la primera luz a 100 en el amanecer
	if not state.is_empty():
		var tm: Dictionary = _rules.time
		drift = clampf((float(state.elapsed) - float(tm.alba_start_s)) / (float(tm.dawn_discovery_s) - float(tm.alba_start_s)), 0.0, 1.0)
	return {"can_give": bool(c.ok), "reason": str(c.reason), "in_position": in_position, "waiting": waiting, "dark_pct": 100.0 * dark, "drift_pct": 100.0 * drift}

func _check_signal() -> Dictionary:
	if state.is_empty() or str(state.status) != "playing":
		return _no("partida_terminada")
	if bool(state.alarm.signaled):
		return _no("ya_dada")
	for g in V.COMBAT_GROUPS:
		if str(_unit(g).stage) == "waiting_signal":
			return {"ok": true, "reason": ""}
	return _no("sin_puesto")

func give_signal() -> Dictionary:
	var c := _check_signal()
	if not bool(c.ok):
		return {"ok": false, "reason": str(c.reason)}
	_ensure_started()
	_note_order(_pt(0.0, 0.0), "", "give_signal")
	_record_offer(float(state.elapsed), true)
	_fire_signal(false)
	return {"ok": true, "reason": ""}

func retreat_all() -> Dictionary:
	if state.is_empty() or str(state.status) != "playing":
		return _no("partida_terminada")
	_finish("defeat", "retirada")
	return {"ok": true, "reason": ""}

func _fire_signal(auto: bool) -> void:
	var al: Dictionary = state.alarm
	if bool(al.signaled):
		return
	var t := float(state.elapsed)
	al.signaled = true
	al.signal_at = t
	al.first_shot_at = t
	al.reinforcement_at = t + float(_rules.reinforcement.delay_s[str(state.world.refuerzo)])
	if str(al.messenger) == "escaped":
		al.reinforcement_at = float(al.reinforcement_at) - float(_rules.reinforcement.get("messenger_advance_s", 0.0))
	_set_phase("ataque")
	for fid in V.OBJECTIVES:
		state.objectives[fid].surprise_until = t + _surprise_s()
	_event("signal", _ts("eventos.senal_temprana" if auto else "eventos.senal"), {"strong": true})
	for u in state.units:
		if str(u.stage) == "waiting_signal":
			_start_attack(u, str(u.order.get("front", "")))
	_bump()

func _start_attack(u: Dictionary, front: String) -> void:
	if not state.objectives.has(front) or str(state.objectives[front].state) == "tomado":
		u.stage = "holding" if front != "" else "idle"
		u.order = {}
		u.path = []
		return
	var posture := str(u.order.get("posture", "con_cautela"))
	u.order = {"action": "attack", "front": front, "posture": posture, "approach": str(u.order.get("approach", _approach_of(front, Vector2(float(u.x), float(u.z)))))}
	u.stage = "attacking"
	u.path = []
	u.fatigue = minf(100.0, float(u.fatigue) + float(_rules.combat.fatigue_per_attack))
	if front == "cuartel":
		state.stats.charges_total = int(state.stats.charges_total) + 1
		if _tower_in_gap():
			state.stats.charges_in_gap = int(state.stats.charges_in_gap) + 1
			var tw: Dictionary = state.objectives.cuartel.tower
			if bool(tw.active):  # la carga que sale en el hueco llega al pie de la torre antes de la próxima descarga: esa descarga no la alcanza
				u.tower_cover_until = float(tw.next_volley_at) + 0.1
	if not bool(state.alarm.signaled):
		_fire_signal(true)
	_bump()

func _start_support(u: Dictionary, front: String) -> void:
	if not state.objectives.has(front) or str(state.objectives[front].state) == "tomado":
		u.stage = "idle"
		u.order = {}
		return
	u.order = {"action": "support", "front": front, "posture": str(u.order.get("posture", "con_cautela"))}
	u.stage = "attacking"
	var o: Dictionary = state.objectives[front]
	if not (o.supporters as Array).has(u.id):
		(o.supporters as Array).append(str(u.id))
		state.stats.support_events = int(state.stats.support_events) + 1
		_event("support", _ts("eventos.apoyo", {"grupo": str(u.name), "frente": str(_rules.objectives[front].place)}), {"unit": str(u.id), "objective": front})
	if not bool(state.alarm.signaled):
		_fire_signal(true)
	_bump()

func _power(u: Dictionary) -> float:
	var cb: Dictionary = _rules.combat
	var posture: Dictionary = cb.posture[str(u.order.get("posture", "con_cautela"))]
	var fatigue_mult := maxf(float(cb.fatigue_power_min), 1.0 - float(cb.fatigue_power_per_pt) * float(u.fatigue))
	var fire := 0.5 + 0.5 * float(u.armed) * _fire_factor()
	return float(u.men) * fire * float(u.strength) / 100.0 * fatigue_mult * float(posture.power) * _dark_factor()

## Lo que le resta al ataque la defensa: la cobertura del frente (×1,25 en alarma, porque se atrincheran) y las armas de chispa de la guardia, que la lluvia también moja.
func _defense_of(fid: String, o: Dictionary) -> float:
	var cb: Dictionary = _rules.combat
	var cover := float((_rules.objectives[fid] as Dictionary).cover)
	if float(o.alert) >= 1.0:
		cover *= float(cb.alarm_cover_mult)
	var d_armed := float(_rules.enemy.armed_share)
	var fire := (0.5 + 0.5 * d_armed * _reliability_rel()) / (0.5 + 0.5 * d_armed)
	return maxf(float(o.garrison) * cover * fire, 1.0)

func _step_combat(_t: float) -> void:
	var cb: Dictionary = _rules.combat
	for fid in V.OBJECTIVES:
		var o: Dictionary = state.objectives[fid]
		if str(o.state) == "tomado":
			continue
		var attackers: Array = []
		for u in state.units:
			if str(u.stage) == "attacking" and str(u.order.get("front", "")) == fid:
				attackers.append(u)
		if attackers.is_empty():
			continue
		if str(o.state) != "asaltado":
			o.state = "asaltado"
			_bump()
		var atk := 0.0
		var cas := 0.0
		for u in attackers:
			atk += _power(u)
			cas += float(cb.posture[str(u.order.get("posture", "con_cautela"))].casualties)
		cas /= float(attackers.size())
		var defense := _defense_of(fid, o)
		var surprise := 1.0 + _surprise_bonus_max(fid) * (1.0 - float(o.alert))
		o.toma = minf(100.0, float(o.toma) + float(cb.capture_k) * atk / defense * surprise * STEP)
		o.garrison = float(o.garrison_max) * (1.0 - float(o.toma) / 100.0)
		if bool(o.get("turned_out", false)):  # la guardia que salió entera y atrincherada tira mejor
			cas *= float(_rules.enemy.alert.get("turnout_casualty_mult", 1.0))
		var loss := float(cb.casualty_k) * defense / maxf(atk, 1.0) * cas * STEP
		for u in attackers:
			u.strength = maxf(0.0, float(u.strength) - loss)
			state.stats.losses = float(state.stats.losses) + loss
		if float(o.toma) >= 100.0:
			_capture(fid)

func _capture(fid: String) -> void:
	var o: Dictionary = state.objectives[fid]
	if str(o.state) == "tomado":
		return
	o.state = "tomado"
	o.toma = 100.0
	o.garrison = 0.0
	o.taken_at = float(state.elapsed)
	var best := ""
	for u in state.units:
		if str(u.stage) == "attacking" and str(u.order.get("front", "")) == fid:
			if str(u.order.get("action", "")) == "attack":
				u.stage = "holding"
				u.custody = maxi(1, roundi(float(u.men) * float(_rules.combat.custody_pct) / 100.0))
				o.custody = int(u.custody)
				if best == "":
					best = str(u.id)
			else:
				u.stage = "idle"
			u.order = {}
	o.held_by = best
	o.supporters = []
	_event("capture", _ts("eventos.tomado", {"frente": str(_rules.objectives[fid].full_name)}), {"objective": fid, "strong": true})
	if fid == "cuartel":
		o.tower.active = false
	if fid == "posta":
		var cap: Dictionary = _rules.loot.capacity
		var mules := int(cap.corral_mules[str(state.world.loot_traits.corral)])
		var arreo := _unit("arreo")
		state.loot.capacity_kg = (float(cap.own_mules) + float(mules)) * float(cap.kg_per_mule)
		arreo.capacity_kg = float(state.loot.capacity_kg)
	if _all_taken() and str(state.phase) != "extraccion":
		_set_phase("extraccion")
		_event("objective", str(_tx("alertas.deposito_tomado.corto")), {"strong": true})
	_bump()

# ---------------------------------------------------------------------------------------------------------------------
# Torre del cuartel (en R1 es un temporizador: 12 descargas de 7,5 s)

func _step_fire_lines(t: float) -> void:
	var keep: Array = []
	for l in state.fire_lines:
		if float(l.until) > t:
			keep.append(l)
	state.fire_lines = keep

# ---------------------------------------------------------------------------------------------------------------------
# Refuerzo y desenlace

func _step_reinforcement(t: float) -> void:
	var al: Dictionary = state.alarm
	if float(al.reinforcement_at) < 0.0 or bool(al.reinforcement_arrived):
		return
	var lead := float(_rules.reinforcement.warning_lead_s)
	if t >= float(al.reinforcement_at) - lead and t - STEP < float(al.reinforcement_at) - lead:
		_event("reinforcement_warning", _ts("eventos.refuerzo_visto"), {"strong": true})
		_bump()
	if t >= float(al.reinforcement_at):
		al.reinforcement_arrived = true
		_event("reinforcement", _ts("eventos.refuerzo_llego"), {"strong": true})
		_bump()

func _combat_strength_pct() -> float:
	var total := 0.0
	for g in V.COMBAT_GROUPS:
		total += float(_unit(g).strength)
	return total / float(V.COMBAT_GROUPS.size())

func _loss_pct() -> float:
	var start := 0.0
	var now := 0.0
	for g in V.COMBAT_GROUPS:
		start += float(state.stats.start_strength[g])
		now += float(_unit(g).strength)
	return clampf(100.0 * (1.0 - now / maxf(start, 1.0)), 0.0, 100.0)

func _golpe_value() -> float:
	var l: Dictionary = state.loot
	return float(l.delivered_value) + float(l.destroyed_value) + float(l.hidden_value)

func _check_end(t: float) -> void:
	if str(state.status) != "playing":
		return
	var tm: Dictionary = _rules.time
	var oc: Dictionary = _rules.outcome
	var arreo := _unit("arreo")
	if str(arreo.stage) == "exited":
		if not _all_taken() or _golpe_value() < float(oc.victory.golpe_min):
			_finish("defeat", "sin_carga", {"lugar": D.ts("lugares_fijos.vado")})
		elif _combat_strength_pct() < float(oc.victory.strength_min_pct):
			_finish("defeat", "dispersos")
		else:
			_finish("victory", "")
		return
	if bool(state.alarm.reinforcement_arrived):
		_finish("defeat", "interceptados", {"lugar": D.place_of(Vector2(float(arreo.x), float(arreo.z)))})
		return
	if float(state.alarm.first_shot_at) < 0.0 and t >= float(tm.dawn_discovery_s):
		_finish("defeat", "amanecio")
		return
	if bool(state.alarm.signaled) and _combat_strength_pct() < float(oc.victory.strength_min_pct):
		_finish("defeat", "dispersos")
		return
	if t >= float(tm.deadline_s):
		_finish("defeat", "plazo", {"lugar": D.place_of(Vector2(float(arreo.x), float(arreo.z)))})

## El centro de las tres partidas de combate (para decir «cerca de…» en una causa que no es de un frente).
func _combat_centroid() -> Vector2:
	var c := Vector2.ZERO
	for g in V.COMBAT_GROUPS:
		var u := _unit(g)
		c += Vector2(float(u.x), float(u.z))
	return c / float(V.COMBAT_GROUPS.size())

## ctx: {frente: id de frente, lugar: frase, grupo: nombre}. Cierra la partida; la derrota por rotura o dispersión de un frente que la guardia ya esperaba (alarma antes
## de la señal) se cuenta como `descubiertos`: es la lección que sirve.
func _finish(status: String, cause_id: String, ctx: Dictionary = {}) -> void:
	if str(state.status) != "playing":
		return
	var oc: Dictionary = _rules.outcome
	var pre: Array = state.alarm.get("pre_signal", [])
	if status == "defeat" and not pre.is_empty():
		if cause_id == "dispersos" or (cause_id == "frente_roto" and pre.has(str(ctx.get("frente", "")))):
			cause_id = "descubiertos"
			ctx = {"frente": str(pre[0])}
	state.status = status
	state.reason = cause_id if status == "defeat" else "victoria"
	for u in state.units:
		if str(u.stage) != "exited":
			u.order = {}
			u.path = []
			u.work = {}
			if str(u.stage) in ["moving", "scouting", "loading", "retreating", "attacking"]:
				u.stage = "idle"  # sin orden no hay ataque en curso (A-12)
		u.noise = 0.0
	_finalize_loot()
	_set_phase("epilogo")
	var out := {"cause_id": "", "title": "", "cause": "", "advice": ""}
	if status == "victory":
		out.title = str(oc.victory.titulo)
		out.cause = str(oc.victory.por_que)
	else:
		var c: Dictionary = oc.causes[cause_id]
		var place := str(ctx.get("lugar", ""))
		if str(ctx.get("frente", "")) != "" and V.OBJECTIVES.has(str(ctx.frente)):
			place = str(_rules.objectives[str(ctx.frente)].place)
		if place == "":
			place = D.place_of(_combat_centroid())
		var vars := {"t": D.clock(float(state.elapsed)), "lugar": place, "deLugar": D.de_place(place), "aLugar": D.a_place(place), "grupo": str(ctx.get("grupo", _tx("una_partida")))}
		out.cause_id = cause_id
		out.title = str(c.titulo)
		out.cause = D.fmt(str(c.texto), vars)
		out.advice = str(c.consejo)
		if cause_id == "descubiertos" and c.has("consejo_reconocedores") and _seen_recon(str(ctx.get("frente", ""))):
			out.advice = str(c.consejo_reconocedores)  # Q-207: la voz la dio un centinela que vio a los reconocedores: el consejo es retirarlos con el aviso
	state.outcome = out
	_event(status, str(out.cause), {"strong": true})

func _seen_recon(fid: String) -> bool:
	return _field()._seen_recon(fid)

func _finalize_loot() -> void:
	var l: Dictionary = state.loot
	for it in l.items:
		if str(it.state) == "en_sitio" or str(it.state) == "cargado":
			l.lost_value = float(l.lost_value) + float(it.qty) * float(it.unit_value)
			it.state = "abandonado"
			it.carried_by = ""
	## lo que quedó en las mulas se abandonó: ni la columna ni el chip de carga lo siguen contando (A-12). La que salió ya entregó lo suyo.
	l.load_kg = 0.0
	for u in state.units:
		if str(u.stage) != "exited":
			u.carry_kg = 0.0

# ---------------------------------------------------------------------------------------------------------------------
# Órdenes

func list_actions(actor_kind: String) -> Array:
	var out: Array = []
	if not R.ACTIONS.has(actor_kind):
		return out
	var base: Array = (R.ACTIONS[actor_kind] as Array).duplicate()
	if actor_kind == "scout" or actor_kind == "train":
		base.insert(0, "move")
	for a in base:
		if R.ACTIONS_R1.has(a) and not out.has(a):
			out.append(a)
	return out

func action_info(action: String) -> Dictionary:
	var actions: Dictionary = _rules.get("actions", {})
	if not actions.has(action):
		return {}
	var d: Dictionary = (actions[action] as Dictionary).duplicate(true)
	d["id"] = action
	return d

func action_availability(actor_id: String, action: String, target: Vector2 = Vector2.ZERO, opts: Dictionary = {}) -> Dictionary:
	var c := _check(actor_id, action, target, opts)
	var info: Dictionary = (_rules.get("actions", {}) as Dictionary).get(action, {})
	return {"ok": bool(c.ok), "reason": str(c.reason), "cost_text": str(info.get("cost_text", "")), "tag": str(info.get("tag", "diseno"))}

func _front_from(target: Vector2, opts: Dictionary, default_front: String) -> String:
	var f := str(opts.get("front", ""))
	if V.OBJECTIVES.has(f):
		return f
	if target != Vector2.ZERO:
		var best := ""
		var best_d := 1.0e9
		for fid in V.OBJECTIVES:
			var c := _hito_pos(str(_rules.objectives[fid].hito))
			var d := target.distance_to(c)
			if d < best_d:
				best_d = d
				best = fid
		if best_d <= float(_rules.combat.front_pick_m):
			return best
	return default_front

## El puesto de ataque de un frente (level.access.attack_posts): el del enfoque pedido en opts.approach; si no, el más cercano a `near` (el punto que marcó
## el jugador o el «siguiente paso»: así el botón de la pista elige el enfoque sin opciones); si no, el primero.
func _attack_post(front: String, opts: Dictionary, near: Vector2 = Vector2.ZERO) -> Vector2:
	var posts: Array = _level.access.attack_posts[front]
	var approach := str(opts.get("approach", ""))
	for p in posts:
		if approach != "" and str(p.get("approach", "")) == approach:
			return Vector2(float(p.x), float(p.z))
	if near != Vector2.ZERO:
		var best := Vector2(float(posts[0].x), float(posts[0].z))
		for p in posts:
			var q := Vector2(float(p.x), float(p.z))
			if q.distance_to(near) < best.distance_to(near):
				best = q
		return best
	return Vector2(float(posts[0].x), float(posts[0].z))

## El enfoque (calle, patios, gola…) del puesto de un frente en el que está `p`; "" si no está en ninguno (a menos de 25 m).
func _approach_of(front: String, p: Vector2) -> String:
	for post in _level.access.attack_posts[front]:
		if Vector2(float(post.x), float(post.z)).distance_to(p) <= 25.0:
			return str(post.get("approach", ""))
	return ""

func _waypoints(opts: Dictionary) -> Array:
	var out: Array = []
	var wps: Variant = opts.get("waypoints", [])
	if wps is Array:
		for w in wps:
			if w is Vector2:
				out.append(w)
	return out

func _in_map(p: Vector2) -> bool:
	var sz := map_size()
	return p.x >= 0.0 and p.y >= 0.0 and p.x <= sz.x and p.y <= sz.y

## `p` sin salirse del mapa: la ruta nunca tiene un punto afuera aunque alguien le pida un destino o una parada que lo esté (las órdenes ya los rechazan; esto es la red).
func _clamp_to_map(p: Vector2) -> Vector2:
	var sz := map_size()
	return Vector2(clampf(p.x, 0.0, sz.x), clampf(p.y, 0.0, sz.y))

## La ruta de `from` a `to` pasando por `stops`: puntos de mundo sin el de partida. {"ok": false} si algún tramo no tiene camino. Sin grilla de navegación, va en línea recta.
func _route(from: Vector2, stops: Array, to: Vector2) -> Dictionary:
	var pts: Array = []
	var cur := from
	var targets: Array = stops.duplicate()
	targets.append(to)
	var n := nav()
	if n != null and n.has_method("avoiding"):
		n = _field().route_nav(n)  # antes de la señal la ruta rodea lo que vigilan los centinelas de los frentes en pie (stealth.route_avoid)
	for raw in targets:
		var tgt := _clamp_to_map(raw)
		if n == null:
			pts.append(tgt)
			cur = tgt
			continue
		var seg: Array = n.find_path(cur, tgt)
		if seg.is_empty():
			return {"ok": false, "pts": []}
		for k in range(1, seg.size()):
			var q := _clamp_to_map(seg[k])
			if not pts.is_empty() and (pts[pts.size() - 1] as Vector2).distance_to(q) < 3.0:
				pts[pts.size() - 1] = q  # dos puntos a menos de 3 m son uno solo (el vado y la celda de la grilla que lo contiene)
			else:
				pts.append(q)
		cur = tgt
	return {"ok": true, "pts": pts}

## Todas las comprobaciones de una orden, sin efectos. Si sale bien trae además el contexto que usa _apply_order.
func _check(actor_id: String, action: String, target: Vector2, opts: Dictionary) -> Dictionary:
	if state.is_empty() or str(state.status) != "playing":
		return _no("partida_terminada")
	var actions: Dictionary = _rules.get("actions", {})
	if not actions.has(action):
		return _no("sin_accion")
	if str(actions[action].round) != "R1":
		return _no("no_disponible")
	if action == "give_signal":
		return _check_signal()
	var u := _unit(actor_id)
	if u.is_empty():
		return _no("sin_actor")
	if str(u.stage) == "exited":
		return _no("fuera_de_juego")
	if str(u.stage) == "routed":
		return _no("quebrada")
	if not (actions[action].who as Array).has(_actor_kind(u)):
		return _no("no_corresponde")
	var pace := str(opts.get("pace", u.pace))
	if not R.PACES.has(pace):
		pace = str(_rules.groups[u.id].pace)
	if bool(_rules.stealth.pace[pace].get("mounted", false)) and not bool(u.mounted):
		return _no("ritmo_montado")
	var ctx := {"ok": true, "reason": "", "unit": u, "pace": pace, "dest": Vector2.ZERO, "front": "", "item": {}, "waypoints": _waypoints(opts), "route": []}
	if (ctx.waypoints as Array).size() > 4:
		return _no("paradas")
	for stop in (ctx.waypoints if ["move", "position", "support", "recon", "leave"].has(action) else []):  # solo las órdenes de marcha recorren paradas
		if not _in_map(stop):  # H-R1-5: una parada fuera del mapa dejaba una ruta fuera del mapa y un guardado que no se podía volver a abrir
			return _no("parada_fuera")
	match action:
		"move", "recon":
			if target == Vector2.ZERO:
				return _no("sin_destino")
			if not _in_map(target):
				return _no("fuera_del_mapa")
			ctx.dest = target
		"position":
			var fp := str(_rules.groups[u.id].front)
			if fp == "":
				return _no("no_corresponde")
			ctx.front = fp
			ctx.dest = _attack_post(fp, opts, target)
			ctx["approach"] = _approach_of(fp, ctx.dest)
		"attack":
			var fa := _front_from(target, opts, str(_rules.groups[u.id].front))
			if fa == "" or not _is_combat(u):
				return _no("sin_frente" if fa == "" else "no_corresponde")
			if str(state.objectives[fa].state) == "tomado":
				return _no("frente_tomado")
			var c := _hito_pos(str(_rules.objectives[fa].hito))
			if D.dist(float(u.x), float(u.z), c.x, c.y) > float(_rules.combat.attack_range_m):
				return _no("rango", {"rango": roundi(float(_rules.combat.attack_range_m))})
			ctx.front = fa
		"support":
			var fs := _front_from(target, opts, str(_rules.groups[u.id].front))
			if fs == "" or not _is_combat(u):
				return _no("sin_frente" if fs == "" else "no_corresponde")
			if str(state.objectives[fs].state) == "tomado":
				return _no("frente_tomado")
			ctx.front = fs
			ctx.dest = _attack_post(fs, opts)
		"load", "destroy":
			var it: Dictionary = {}
			var radius := float(_rules.transport.load_radius_m if action == "load" else _rules.transport.destroy_radius_m)
			if str(opts.get("item", "")) != "":
				it = _item(str(opts.item))
				if it.is_empty() or str(it.state) != "en_sitio":
					return _no("ya_cargada")
			else:
				var near: Variant = target if target != Vector2.ZERO else Vector2(float(u.x), float(u.z))
				var room: float = float(state.loot.capacity_kg) - float(state.loot.load_kg) if action == "load" else -1.0
				it = _best_item(room, near, radius * 1.5, action == "destroy")
				if it.is_empty():
					return _no("sin_carga_cerca")
			if str(state.objectives[str(it.front)].state) != "tomado":
				return _no("frente_no_tomado")
			if D.dist(float(u.x), float(u.z), float(it.x), float(it.z)) > radius:
				return _no("lejos_carga", {"radio": roundi(radius)})
			if action == "load" and float(state.loot.load_kg) + _item_kg(it) > float(state.loot.capacity_kg) + 1e-6:
				return _no("no_entra", {"kg": roundi(float(state.loot.load_kg) + _item_kg(it) - float(state.loot.capacity_kg))})
			ctx.item = it
		"leave":
			if not _all_taken():
				return _no("sin_tomar")
			if str(u.id) == "arreo" and float(u.carry_kg) <= 0.0:
				return _no("sin_carga_para_salir")
	if action in ["move", "position", "support", "recon", "leave"]:
		var from := Vector2(float(u.x), float(u.z))
		var stops: Array = ctx.waypoints
		var route: Dictionary
		if action == "leave":
			route = _route(from, stops + [_hito_pos("vado_este")], _hito_pos("salida_este"))
		elif action == "recon":
			route = _route(from, stops, _recon_stop(u, ctx.dest))
		else:
			route = _route(from, stops, ctx.dest)
		if not bool(route.ok):
			return _no("sin_paso")
		ctx.route = route.pts
	return ctx

func _go(u: Dictionary, points: Array, order: Dictionary) -> void:
	var path: Array = []
	for p in points:
		path.append(_pt((p as Vector2).x, (p as Vector2).y))
	u.path = path
	u.order = order
	u.stage = "moving"
	u.work = {}

static func _pt(x: float, z: float) -> Dictionary:
	return {"x": x, "z": z}

## Anota la orden para deshacerla (Ctrl+Z). El ritmo del juego (stats.pacing) se mide aparte, por ofertas.
func _note_order(target: Dictionary, unit_id: String, action: String) -> void:
	var t := float(state.elapsed)
	(state.orders as Array).append({"time": t, "round": 1, "unit": unit_id, "action": action, "target": target})
	if (state.orders as Array).size() > 200:
		state.orders = (state.orders as Array).slice((state.orders as Array).size() - 200)

func issue_order(actor_id: String, action: String, target: Vector2 = Vector2.ZERO, opts: Dictionary = {}) -> Dictionary:
	if action == "give_signal":
		var r := give_signal()
		return {"ok": bool(r.ok), "reason": str(r.reason), "path": [], "plan": {}}
	if action == "decide":  # el botón de un aviso con decisión: `actor_id` trae la opción elegida
		var rd := resolve_choice(actor_id, false)
		return {"ok": bool(rd.ok), "reason": str(rd.reason), "path": [], "plan": {}}
	var c := _check(actor_id, action, target, opts)
	if not bool(c.ok):
		return {"ok": false, "reason": str(c.reason), "path": [], "plan": {}}
	var plan: Dictionary = {}
	if action == "move" or action == "position" or action == "support":
		plan = plan_route(actor_id, c.dest, opts)
	elif action == "recon":
		plan = plan_recon(actor_id, [c.dest], opts)
	_apply_order(c, action, opts)
	var u: Dictionary = c.unit
	return {"ok": true, "reason": "", "path": (u.path as Array).duplicate(true), "plan": plan}

func _apply_order(c: Dictionary, action: String, opts: Dictionary) -> void:
	var u: Dictionary = c.unit
	_ensure_started()
	var prev := {"stage": str(u.stage), "order": (u.order as Dictionary).duplicate(true)}
	_note_order(_pt(float(c.dest.x), float(c.dest.y)), str(u.id), action)
	_record_offer(float(state.elapsed), true)
	var last: Dictionary = (state.orders as Array)[(state.orders as Array).size() - 1]
	last["prev"] = prev
	u.detected = false
	u.pace = str(c.pace)
	var posture := str(opts.get("posture", "con_cautela"))
	if not R.POSTURES.has(posture):
		posture = "con_cautela"
	match action:
		"move":
			_go(u, c.route, {"action": "move", "x": float(c.dest.x), "z": float(c.dest.y)})
		"position":
			_go(u, c.route, {"action": "position", "front": str(c.front), "posture": posture, "approach": str(c.get("approach", ""))})
		"attack":
			u.order = {"posture": posture}
			_start_attack(u, str(c.front))
		"support":
			_go(u, c.route, {"action": "support", "front": str(c.front), "posture": posture})
		"recon":
			_go(u, c.route, {"action": "recon", "x": float(c.dest.x), "z": float(c.dest.y)})
		"load":
			var it: Dictionary = c.item
			var rate := float(_rules.transport.load_kg_per_s_per_team) * float(_rules.transport.teams_max)
			u.order = {"action": "load", "item": str(it.id)}
			u.work = {"kind": "load", "item": str(it.id), "remaining_s": _item_kg(it) / rate}
			u.stage = "loading"
			u.path = []
		"destroy":
			var it2: Dictionary = c.item
			u.order = {"action": "destroy", "item": str(it2.id)}
			u.work = {"kind": "destroy", "item": str(it2.id), "remaining_s": float(_rules.loot.classes[str(it2.kind)].destroy_s)}
			u.stage = "loading"
			u.path = []
		"leave":
			_go(u, c.route, {"action": "leave"})
		"hold":
			u.path = []
			u.work = {}  # lo que tenía entre manos (destruir, cargar) se suelta (A-12)
			if not bool(state.alarm.signaled) and str(u.stage) == "waiting_signal":
				pass  # en su puesto antes de la señal, «sostener» es quedarse donde está esperando la señal: sigue contando para la señal (A-02)
			else:
				u.order = {}
				u.stage = "holding"
		"cancel":
			u.order = {}
			u.path = []
			u.work = {}
			u.stage = "idle"
	_bump()

## El reconocedor se detiene a 0,9 del radio de lo que quiere mirar (dentro de él), no encima de la guardia.
func _recon_stop(u: Dictionary, target: Vector2) -> Vector2:
	for fid in V.OBJECTIVES:
		var c := _hito_pos(str(_rules.objectives[fid].hito))
		var r := _recon_radius_for(fid)
		if target.distance_to(c) <= r:
			var from := Vector2(float(u.x), float(u.z))
			var d := from.distance_to(c)
			if d <= r * 0.9:
				return from
			return c + (from - c).normalized() * r * 0.9
	return target

func cancel_order(actor_id: String) -> Dictionary:
	return issue_order(actor_id, "cancel")

func undo_last() -> Dictionary:
	if state.is_empty() or str(state.status) != "playing":
		return _no("partida_terminada")
	var orders: Array = state.orders
	while not orders.is_empty():
		var last: Dictionary = orders[orders.size() - 1]
		if str(last.get("action", "")) == "give_signal" or str(last.get("unit", "")) == "":
			return _no("deshacer")  # la señal no se deshace, y deshacer no salta a la orden de otra partida (A-08)
		orders.pop_back()
		var u := _unit(str(last.get("unit", "")))
		if u.is_empty() or str(last.get("action", "")) == "":
			continue
		u.path = []
		u.work = {}
		if str(u.stage) != "exited" and str(u.stage) != "routed":
			## vuelve a lo que la orden anotó (`prev`) si se puede retomar sin ruta ni trabajo a medias; si no, queda quieta
			var prev: Dictionary = last.get("prev", {})
			var back := str(prev.get("stage", "idle"))
			var prev_front := str((prev.get("order", {}) as Dictionary).get("front", ""))
			var at_post := V.OBJECTIVES.has(prev_front) and _approach_of(prev_front, Vector2(float(u.x), float(u.z))) != ""
			if back in ["idle", "waiting_signal", "holding"] and not (back == "waiting_signal" and (bool(state.alarm.signaled) or not at_post)):
				u.stage = back
				u.order = (prev.get("order", {}) as Dictionary).duplicate(true) if back == "waiting_signal" else {}
			else:
				u.stage = "idle"
				u.order = {}
		_event("info", _ts("eventos.parte_deshacer"), {"unit": str(u.id)})
		_bump()
		return {"ok": true, "reason": ""}
	return _no("deshacer")

# ---------------------------------------------------------------------------------------------------------------------
# Consultas

func units() -> Array:
	return (state.get("units", []) as Array).duplicate(true)

func get_unit(id: String) -> Dictionary:
	return _unit(id).duplicate(true)

func objectives() -> Array:
	var out: Array = []
	for fid in V.OBJECTIVES:
		out.append(objective(fid))
	return out

func objective(id: String) -> Dictionary:
	if state.is_empty() or not state.objectives.has(id):
		return {}
	var d: Dictionary = (state.objectives[id] as Dictionary).duplicate(true)
	d["id"] = id
	d["name"] = str(_rules.objectives[id].name)
	return d

func loot_state() -> Dictionary:
	var l: Dictionary = state.loot
	var delivered := float(l.delivered_value)
	var destroyed := float(l.destroyed_value)
	var hidden := float(l.hidden_value)
	var lost := float(l.lost_value)
	return {"items": (l.items as Array).duplicate(true), "capacity_kg": float(l.capacity_kg), "load_kg": float(l.load_kg),
		"golpe": {"entregado": delivered, "destruido": destroyed, "oculto": hidden, "perdido": lost, "pendiente": maxf(0.0, 100.0 - delivered - destroyed - hidden - lost), "total": 100.0}}

## Extensión de R1 (no figura en 3.2): HumahuacaProgress.begin_attempt le da las marcas «anotado» del diario; se dibujan en render_state().marks y no cuentan como reconocimiento.
func set_diary_marks(marks: Array) -> void:
	if not state.is_empty():
		state.diary_marks = marks.duplicate(true)
		_bump()

func set_mercy(level: int) -> void:
	if not state.is_empty():
		state.mercy_level = clampi(level, 0, 3)

func apply_assist(_kind: String) -> Dictionary:
	return _no("sin_ayuda")

func pending_choice() -> Dictionary:
	return _field().pending_choice() if not state.is_empty() else {}

func resolve_choice(option_id: String, by_timeout: bool = false) -> Dictionary:
	return _field().resolve_choice(option_id, by_timeout) if not state.is_empty() else _no("partida_terminada")

# Decisiones del mando realista (forma del Norte): en R1 solo la alternativa local, sin tabla. Jev queda fuera del MVP (D4).
func enemy_observation() -> Dictionary:
	var fronts := {}
	for fid in V.OBJECTIVES:
		fronts[fid] = {"state": str(state.objectives[fid].state), "alert": float(state.objectives[fid].alert), "toma": float(state.objectives[fid].toma)}
	return {"elapsed": float(state.elapsed), "phase": str(state.phase), "signaled": bool(state.alarm.signaled), "fronts": fronts}

func enemy_choices() -> Array:
	return ["atrincherar"]

func enemy_fallback() -> String:
	return "atrincherar"

func record_external_decision(decision: Dictionary) -> Dictionary:
	if not enemy_choices().has(str(decision.get("choice", ""))):
		return _no("opcion_ilegal")
	return {"ok": true, "reason": ""}

# ---------------------------------------------------------------------------------------------------------------------
# Alarma, torre, reconocimiento, botín y decisiones de campo (humahuaca_rules_field.gd)

func _field() -> Field:
	if _field_inst == null:
		_field_inst = Field.new(self)
	return _field_inst

func _raise_alarm(fid: String, o: Dictionary, seen: bool, t: float) -> void:
	_field()._raise_alarm(fid, o, seen, t)

func _step_messenger(t: float) -> void:
	_field()._step_messenger(t)

func _step_spread(t: float) -> void:
	_field()._step_spread(t)

func _tower_in_gap() -> bool:
	return _field()._tower_in_gap()

func _tower_pos() -> Vector2:
	return _field()._tower_pos()

func _tower_hit_mult(u: Dictionary, tp: Vector2) -> float:
	return _field()._tower_hit_mult(u, tp)

func _step_tower(t: float) -> void:
	_field()._step_tower(t)

func _recon_radius_for(fid: String) -> float:
	return _field()._recon_radius_for(fid)

func _complete_recon(u: Dictionary) -> void:
	_field()._complete_recon(u)

func _item(id: String) -> Dictionary:
	return _field()._item(id)

func _item_kg(it: Dictionary) -> float:
	return _field()._item_kg(it)

func _item_value(it: Dictionary) -> float:
	return _field()._item_value(it)

func _best_item(room_kg: float, near: Variant = null, radius: float = -1.0, destroying: bool = false) -> Dictionary:
	return _field()._best_item(room_kg, near, radius, destroying)

func _complete_load(u: Dictionary, item_id: String) -> void:
	_field()._complete_load(u, item_id)

func _complete_destroy(u: Dictionary, item_id: String) -> void:
	_field()._complete_destroy(u, item_id)

func _exit_unit(u: Dictionary) -> void:
	_field()._exit_unit(u)

# ---------------------------------------------------------------------------------------------------------------------
# Consultas de solo lectura (humahuaca_rules_info.gd)

func _info() -> Info:
	if _info_inst == null:
		_info_inst = Info.new(self)
	return _info_inst

func hud_state() -> Dictionary:
	return _info().hud_state() if not state.is_empty() else {}

func render_state() -> Dictionary:
	return _info().render_state() if not state.is_empty() else {}

func campaign_report() -> Dictionary:
	return _info().campaign_report() if not state.is_empty() else {}

func epilogue() -> Array:
	return _info().epilogue() if not _rules.is_empty() else []

func plan_route(actor_id: String, target: Vector2, opts: Dictionary = {}) -> Dictionary:
	return _info().plan_route(actor_id, target, opts)

func plan_recon(actor_id: String, points: Array, opts: Dictionary = {}) -> Dictionary:
	return _info().plan_recon(actor_id, points, opts)

## Las aproximaciones de cada frente desde la zona de partida (ruta de A* al puesto de ataque de cada enfoque). Solo lectura.
func route_atlas(front: String = "") -> Array:
	return _info().route_atlas(front)

# ---------------------------------------------------------------------------------------------------------------------
# Guardado y validación (humahuaca_rules_save.gd)

func snapshot() -> Dictionary:
	return state.duplicate(true)

## Nunca escribe un guardado que después no se pueda abrir: si el estado en curso no pasa validate_snapshot (un defecto de las reglas, no del jugador), devuelve
## ERR_INVALID_DATA y deja intacto el archivo anterior. La interfaz lo cuenta como «no se pudo guardar» en vez de decir «Partida guardada» y fallar en F9 (H-R1-5).
func save_game(path: String) -> Error:
	if not state.is_empty() and not bool(validate_snapshot(state).ok):
		return ERR_INVALID_DATA
	return Save.write(path, state)

func load_game(path: String) -> Dictionary:
	var read := Save.read(path)
	if not bool(read.ok):
		return {"ok": false, "reason": str(read.reason)}
	var check := validate_snapshot(read.data)
	if not bool(check.ok):
		return check
	if str((read.data as Dictionary).get("status", "")) != "playing":
		return _no("partida_terminada")  # un guardado de una partida ya terminada no se carga: dejaría al jugador sin parte ni reintentos (B-2)
	var loaded: Dictionary = (read.data as Dictionary).duplicate(true)
	Save.fix_ints(loaded)
	loaded.previous_game_id = str(loaded.game_id)
	loaded.state_version = int(loaded.state_version) + 1
	loaded.game_id = "humahuaca-%d-%d-%d" % [int(loaded.seed), int(loaded.attempt), int(loaded.state_version)]
	state = loaded
	_events = []
	_env_key = -1.0
	_event("info", _ts("eventos.guardado"))
	state.pacing_last.events = int(state.pacing_last.events) - 1  # el aviso de la carga no cuenta: seguir jugando da lo mismo que seguir con la partida original
	return {"ok": true, "reason": "Partida recuperada.", "state": state}

## Reemplaza el estado por `d` si es válido, sin tocar archivos ni el id (la usan la ramificación de decisiones y los puntos de control).
func restore_snapshot(d: Dictionary) -> Dictionary:
	var check := validate_snapshot(d)
	if not bool(check.ok):
		return check
	state = d.duplicate(true)
	Save.fix_ints(state)
	_events = []
	_env_key = -1.0
	return {"ok": true, "reason": ""}

func validate_snapshot(v: Variant) -> Dictionary:
	return Save.validate(v, float(_rules.get("map_version", 1)), map_size())
