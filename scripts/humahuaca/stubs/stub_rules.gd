extends RefCounted
## Stub de HumahuacaRules (CONTRATO 3.2 y 7). Lo escribe reglas_historia en R1.0 y queda CONGELADO desde el merge (se corrige solo por addendum).
## Es la versión mínima, jugable y determinista de las reglas del nivel «humahuaca»: 5 agrupaciones, 3 frentes, reloj con fases (noche, alba, día),
## las 9 acciones de R1 (más sostener y cancelar), la señal, la toma de los frentes, la torre del cuartel, el botín en 5 clases, el refuerzo y el desenlace.
## Sirve para que el controlador, la vista y las pruebas de las otras pistas trabajen contra una capa que ya habla el contrato mientras llegan las
## reglas reales (R1). No es el balance: las cifras salen de data/humahuaca_rules.json y data/humahuaca_level.json (las mismas que leerá la clase real)
## y la fórmula de toma es una simplificación.
##
## Garantiza (CONTRATO 7): la firma completa de 3.2; hud_state, render_state, campaign_report y plan_route con la forma de 3.6; una victoria
## alcanzable («A su puesto» ×3, «Atacar» ×3 y «Salir por el este» con el arreo) y la derrota `amanecio` si nadie ataca; snapshot, guardado, carga,
## validación y restauración básicos. Con opts.phase ("aproximacion", "ataque", "extraccion") las pruebas empiezan en cualquier fase.
## No hace: rutas que rodeen tapias o zanjas (va en línea recta), doble capa de conocimiento, decisiones del campo ni las acciones de R2a.
## Partes: las consultas de solo lectura (hud_state, render_state, campaign_report, planes) viven en stub_rules_info.gd y el guardado y la validación
## en stub_rules_save.gd, para que cada archivo quede por debajo de las ~1 500 líneas del contrato; la API pública sigue toda acá.
## Convenciones de este stub: `list_actions("scout"|"train")` suma «Mover» (el arreo llega a la posta con `move`); «Salir por el este» sin carga hace
## que el arreo cargue solo lo que entra por densidad (para que «tomar los tres frentes y salir» alcance); `retreat_all()` funciona siempre.
##
## Independencia (V19): solo importa vocabularios. El terreno lo toma, si existe, de la clase real o del stub por ruta en tiempo de ejecución, o lo
## recibe en set_terrain() o en opts.terrain de new_game; si no hay ninguno, terrain() devuelve null y las alturas valen +17 m (el plano del stub del terreno).
## Determinismo: RNG congruencial propio (`rng_state`), nunca azar ni reloj del sistema. Los puntos de `state` son {x, z}; el rumbo `yaw_deg` va de
## 0 (norte, -z) a 90 (este, +x).

const V = preload("res://scripts/humahuaca/humahuaca_vocab.gd")
const R = preload("res://scripts/humahuaca/rules/vocab_rules.gd")
const Info = preload("res://scripts/humahuaca/stubs/stub_rules_info.gd")
const Save = preload("res://scripts/humahuaca/stubs/stub_rules_save.gd")

const SCENARIO := "humahuaca"
const SAVE_VERSION := 1
const STEP := 0.25
const MAX_DT := 60.0
const LOG_MAX := 400
const TERRAIN_REAL := "res://scripts/humahuaca/terrain/humahuaca_terrain.gd"
const TERRAIN_STUB := "res://scripts/humahuaca/stubs/stub_terrain.gd"
const FLAT_HEIGHT_M := 17.0  # el plano del stub del terreno (cota del templo sobre el cero local)
## Coordenadas de respaldo, solo para cuando el mapa todavía no trae el hito (DISENO 3 y 5.1). La fuente es humahuaca_map.json (landmarks).
const FALLBACK_HITOS := {
	"templo": Vector2(450, 325), "bateria": Vector2(318, 350), "cuartel": Vector2(418, 335), "posta": Vector2(590, 300),
	"torre_casa_cura": Vector2(426, 326), "torre_templo": Vector2(466, 322), "plaza": Vector2(450, 392), "polvorin": Vector2(601, 292),
	"parque": Vector2(583, 304), "corral_posta": Vector2(618, 302), "quebradita_norte": Vector2(282, 298), "quebradita_sur": Vector2(288, 402),
	"vado_este": Vector2(862, 340), "salida_este": Vector2(895, 332), "entrada_sur": Vector2(540, 650), "zona_partida": Vector2(160, 550),
	"spawn_rodriguez": Vector2(70, 470), "spawn_portal": Vector2(110, 580), "spawn_arias": Vector2(260, 625),
	"spawn_reconocedores": Vector2(230, 480), "spawn_arreo": Vector2(60, 625)}

static var _json_cache: Dictionary = {}

var state: Dictionary = {}
var _rules: Dictionary = {}
var _level: Dictionary = {}
var _map: Dictionary = {}
var _merged: Dictionary = {}
var _terrain: RefCounted = null
var _terrain_tried := false
var _events: Array = []
var _info_inst: Info = null

# ---------------------------------------------------------------------------------------------------------------------
# Utilidades

static func _json(path: String) -> Dictionary:
	if not _json_cache.has(path):
		_json_cache[path] = V.load_json(path)
	return _json_cache[path]

static func _pt(x: float, z: float) -> Dictionary:
	return {"x": x, "z": z}

static func _dist(ax: float, az: float, bx: float, bz: float) -> float:
	return sqrt((ax - bx) * (ax - bx) + (az - bz) * (az - bz))

static func _clock(seconds: float) -> String:
	var s := maxi(0, int(floor(seconds)))
	return "%d:%02d" % [floori(float(s) / 60.0), s % 60]

static func _fmt(template: String, vars: Dictionary) -> String:
	var out := template
	for k in vars:
		out = out.replace("{" + str(k) + "}", str(vars[k]))
	return out

func _init() -> void:
	_rules = _json(V.RULES_PATH)
	_level = _json(V.LEVEL_PATH)
	_map = _json(V.MAP_PATH)

## Un texto de rules.texts por ruta con puntos («errores.rango»); "" si no existe.
func _tx(path: String) -> Variant:
	var cur: Variant = _rules.get("texts", {})
	for part in path.split("."):
		if cur is Dictionary and (cur as Dictionary).has(part):
			cur = cur[part]
		else:
			return ""
	return cur

func _ts(path: String, vars: Dictionary = {}) -> String:
	return _fmt(str(_tx(path)), vars)

func _no(key: String, vars: Dictionary = {}) -> Dictionary:
	return {"ok": false, "reason": _ts("errores." + key, vars)}

## El hito del mapa (o su respaldo) como Vector2(x, z).
func _hito_pos(id: String) -> Vector2:
	for lm in _map.get("landmarks", []):
		if lm is Dictionary and str(lm.get("id", "")) == id:
			return Vector2(float(lm.x), float(lm.z))
	return FALLBACK_HITOS.get(id, Vector2(450.0, 325.0))

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
	if _rules.is_empty() or _level.is_empty():
		return {}
	if _merged.is_empty():
		for src in [_map, _level, _rules]:
			for k in src:
				if not _merged.has(k):
					_merged[k] = src[k]
	return _merged

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

## Extensión del stub (no figura en 3.2): el controlador le da el terreno que eligió (el real o el mínimo) cuando esa capa corre en respaldo. new_game lo acepta en opts.terrain.
func set_terrain(t: RefCounted) -> void:
	_terrain = t
	_terrain_tried = true

func map_size() -> Vector2:
	var sz: Dictionary = _map.get("size_m", {})
	return Vector2(float(sz.get("x", 900.0)), float(sz.get("z", 650.0)))

func terrain_height_at(x: float, z: float) -> float:
	var t := terrain()
	if t != null and t.has_method("height_at"):
		return float(t.call("height_at", x, z))
	return FLAT_HEIGHT_M

## En R1 el mundo es fijo (el de variants.fixed); desde R2b sorteará solo las dimensiones activas con la semilla.
func world_from_seed(_seed_value: int) -> Dictionary:
	var variants: Dictionary = _rules.get("variants", {})
	var world: Dictionary = (variants.get("fixed", {}) as Dictionary).duplicate(true)
	world["loot"] = (variants.get("loot_fixed", {}) as Dictionary).duplicate(true)
	return world

# ---------------------------------------------------------------------------------------------------------------------
# Nueva partida

func new_game(seed_value: int = 1817, attempt: int = 1, opts: Dictionary = {}) -> Dictionary:
	_events = []
	if _rules.is_empty() or _level.is_empty():
		state = {}
		return {}
	if opts.get("terrain", null) is RefCounted:
		_terrain = opts.terrain
	var world := _make_world(seed_value, opts)
	state = {
		"schema_version": SAVE_VERSION, "game_id": "humahuaca-%d-%d" % [seed_value, maxi(1, attempt)], "state_version": 1, "scenario": SCENARIO,
		"map_id": "humahuaca", "map_version": int(_rules.get("map_version", 1)), "contract": V.CONTRACT,
		"seed": seed_value, "rng_state": maxi(1, absi(seed_value) % 2147483647), "attempt": maxi(1, attempt), "elapsed": 0.0, "accumulator": 0.0,
		"status": "playing", "reason": "", "phase": "briefing", "resistencia": false, "world": world,
		"alarm": {"level": 0.0, "first_shot_at": -1.0, "signaled": false, "signal_at": -1.0, "messenger": "none", "reinforcement_at": -1.0, "reinforcement_arrived": false},
		"objectives": _make_objectives(), "units": _make_units(), "loot": _make_loot(world),
		"recon": {"geometry": true, "fronts": []},
		"stats": {"start_strength": {}, "detections": 0, "losses": 0.0, "support_events": 0, "horses_lost": 0, "powder_wet": 0,
			"pacing": {"decision_gap_max_s": 0.0, "decision_gap_attack_max_s": 0.0, "first_decision_s": -1.0, "events_per_min": 0.0, "visible_actions_t0": 4},
			"charges_total": 0, "charges_in_gap": 0},
		"log": [], "orders": [], "pacing_last": {"any": 0.0, "attack": -1.0}, "fire_lines": [], "outcome": {}, "render_version": 1, "smoke_used": 0, "smoke_adv": 0.0,
		"mercy_level": clampi(int(opts.get("mercy_level", 0)), 0, 3),
		"assists": (opts.get("assists", []) as Array).duplicate() if opts.get("assists", []) is Array else [],
		"diary_marks": (opts.get("diary_marks", []) as Array).duplicate(true) if opts.get("diary_marks", []) is Array else []}
	for u in state.units:
		state.stats.start_strength[u.id] = float(u.strength)
	_apply_start(opts)
	return state

func _make_world(seed_value: int, opts: Dictionary) -> Dictionary:
	var base := world_from_seed(seed_value)
	var world := {}
	for dim in R.VARIANTS:
		world[dim] = base[dim]
	var override: Variant = opts.get("variant", {})
	if override is Dictionary:
		for dim in override:
			if R.VARIANTS.has(dim) and (R.VARIANTS[dim] as Array).has(override[dim]):
				world[dim] = override[dim]
	var traits: Dictionary = (base.get("loot", {}) as Dictionary).duplicate(true)
	var ot: Variant = opts.get("loot_traits", {})
	if ot is Dictionary:
		for k in ot:
			if R.WORLD_TRAITS.has(k) and (R.WORLD_TRAITS[k] as Array).has(ot[k]):
				traits[k] = ot[k]
	world["loot_traits"] = traits
	world["known"] = []
	world["rumors"] = []
	return world

func _make_units() -> Array:
	var out: Array = []
	for id in V.GROUPS:
		var g: Dictionary = _rules.groups[id]
		var p := _hito_pos("spawn_" + id)
		out.append({"id": id, "name": str(g.name), "kind": str(g.kind), "x": p.x, "z": p.y, "yaw_deg": 0.0, "strength": float(g.strength), "fatigue": 0.0,
			"morale": 100.0, "armed": float(g.armed), "men": int(g.men), "mounted": bool(g.mounted), "pace": str(g.pace), "stage": "idle", "order": {}, "path": [],
			"noise": 0.0, "detected": false, "custody": 0, "horses": int(g.horses), "carry_kg": 0.0, "capacity_kg": float(g.capacity_kg), "tag": str(g.tag), "work": {}})
	return out

func _make_objectives() -> Dictionary:
	var out := {}
	for id in V.OBJECTIVES:
		var g := float((_rules.objectives[id] as Dictionary).garrison)
		out[id] = {"state": "guardado", "toma": 0.0, "garrison": g, "garrison_max": g, "alert": 0.0, "surprise_until": -1.0, "reconocido": 0.0,
			"held_by": "", "custody": 0, "taken_at": -1.0, "supporters": []}
	out.cuartel["tower"] = {"active": false, "armed": false, "volleys_left": int(_rules.tower.volleys), "next_volley_at": -1.0}
	out.bateria["battery"] = {"facing": str(_level.features.gola_bateria.lado), "pieces": 3}
	return out

func _make_loot(world: Dictionary) -> Dictionary:
	var items: Array = []
	var traits: Dictionary = world.loot_traits
	for kind in R.LOOT_KINDS_R1:
		if kind == "plata" and not bool(traits.get("plata", true)):
			continue
		var cls: Dictionary = _rules.loot.classes[kind]
		var total_lots := 0
		for lot in cls.lots:
			total_lots += int(lot.count)
		var n := 0
		for lot in cls.lots:
			for i in range(int(lot.count)):
				n += 1
				var site := _hito_pos(str(lot.site))
				var qty := int(lot.qty)
				var prefix: String = "pieza" if str(kind) == "canones" else str(kind)
				items.append({"id": "%s_%d" % [prefix, n], "kind": str(kind), "qty": qty, "unit_kg": float(lot.get("unit_kg", cls.unit_kg)),
					"unit_value": float(cls.points) / float(total_lots) / float(qty), "state": "en_sitio", "x": site.x + 3.0 * float(n % 3),
					"z": site.y + 3.0 * float(floori(float(n) / 3.0)), "where": str(cls.where), "front": str(lot.front), "carried_by": "", "spot": "", "safe": false,
					"wet": kind == "polvora" and str(traits.get("polvora", "seca")) == "humeda"})
	var cap: Dictionary = _rules.loot.capacity
	return {"items": items, "capacity_kg": float(cap.own_mules) * float(cap.kg_per_mule), "load_kg": 0.0, "delivered_value": 0.0, "destroyed_value": 0.0,
		"hidden_value": 0.0, "lost_value": 0.0, "total_value": 100.0}

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
	if state.is_empty() or str(state.status) != "playing":
		return _take_events()
	var remaining := clampf(dt, 0.0, MAX_DT)
	if remaining > 0.0:
		_ensure_started()
	state.accumulator = float(state.accumulator) + remaining
	while float(state.accumulator) >= STEP - 1e-9 and str(state.status) == "playing":
		state.accumulator = float(state.accumulator) - STEP
		_step()
	return _take_events()

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
	_step_alert(t)
	_step_units(t)
	_step_combat(t)
	_step_tower(t)
	_step_reinforcement(t)
	_step_fire_lines(t)
	state.resistencia = bool(state.objectives.cuartel.tower.active) or (str(state.phase) == "ataque" and not _all_taken())
	_check_end(t)

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
# Ambiente

func environment() -> Dictionary:
	if state.is_empty():
		return {"phase": "noche", "time_of_day": 0.03, "rain": 0.9, "visibility_m": 35.0, "mud": 0.55, "firearm_reliability": 0.55}
	return _env_at(float(state.elapsed))

func _env_at(t: float) -> Dictionary:
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
	return {"phase": str(seg.phase), "time_of_day": lerpf(float(seg.time_of_day[0]), float(seg.time_of_day[1]), f), "rain": lerpf(float(seg.rain[0]), float(seg.rain[1]), f),
		"visibility_m": lerpf(float(seg.visibility_m[0]), float(seg.visibility_m[1]), f), "mud": mud,
		"firearm_reliability": lerpf(float(seg.firearm_reliability[0]), float(seg.firearm_reliability[1]), f)}

## 1 con luz (visibilidad >= 100 m) y `assault_min` en plena oscuridad: la noche cuesta poder de asalto (DISENO 2).
func _dark_factor() -> float:
	var dc: Dictionary = _rules.stealth.dark_cost
	var vis := float(environment().visibility_m)
	var k := clampf((vis - float(dc.ramp_from_m)) / (float(dc.ramp_to_m) - float(dc.ramp_from_m)), 0.0, 1.0)
	return lerpf(float(dc.assault_min), 1.0, k)

# ---------------------------------------------------------------------------------------------------------------------
# Alerta y desvelo

func _step_alert(t: float) -> void:
	var env := _env_at(t)
	var vis := float(env.visibility_m)
	var drift: Dictionary = _rules.stealth.dawn_drift
	var drift_rate := float(drift.per_s_factor) * vis / float(drift.reference_visibility_m)
	var en: Dictionary = _rules.enemy.alert
	var top := 0.0
	for fid in V.OBJECTIVES:
		var o: Dictionary = state.objectives[fid]
		if str(o.state) == "tomado":
			continue
		var a := float(o.alert)
		if t >= float(_rules.time.alba_start_s):
			a += drift_rate * STEP
		if float(state.alarm.first_shot_at) >= 0.0:
			a = maxf(a, clampf((t - float(state.alarm.first_shot_at)) / float(_rules.time.surprise_s), 0.0, 1.0))
		var c := _hito_pos(str(_rules.objectives[fid].hito))
		for u in state.units:
			if float(u.noise) <= 0.0 or str(u.stage) == "exited":
				continue
			if _dist(float(u.x), float(u.z), c.x, c.y) < vis * (1.0 + float(_rules.stealth.detection.noise_mult) * float(u.noise)):
				a += float(en.detect_gain_per_s) * STEP * (1.0 + float(u.noise))
		a = clampf(a, 0.0, 1.0)
		o.alert = a
		top = maxf(top, a)
		if a >= float(en.alarma_at) and (str(o.state) == "guardado" or str(o.state) == "alertado"):
			o.state = "en_alarma"
			_event("alarm", _ts("eventos.alarma", {"frente": str(_rules.objectives[fid].full_name)}), {"objective": fid, "strong": true})
			_bump()
		elif a >= float(en.alertado_at) and str(o.state) == "guardado":
			o.state = "alertado"
			_bump()
	state.alarm.level = top

# ---------------------------------------------------------------------------------------------------------------------
# Agrupaciones: ruido, marcha, trabajo

func _noise_of(u: Dictionary, env: Dictionary) -> float:
	var st := str(u.stage)
	var n := 0.0
	if st == "moving" or st == "retreating":
		n = float(_rules.stealth.pace[str(u.pace)].noise)
	elif st == "attacking":
		n = 0.8
	elif st == "loading":
		n = 0.3
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

func _unit_speed(u: Dictionary, env: Dictionary) -> float:
	var sp := float(_rules.stealth.pace[str(u.pace)].speed)
	sp *= 1.0 - float(_rules.environment.mud_slow) * float(env.mud)
	var vado := _hito_pos("vado_este")
	if _dist(float(u.x), float(u.z), vado.x, vado.y) < 25.0:
		sp *= float(_rules.transport.ford_mult)
	return maxf(sp, 0.1)

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
			_move_unit(u, env)
		elif st == "scouting" or st == "loading":
			_work_unit(u)
		else:
			u.fatigue = maxf(0.0, float(u.fatigue) - 0.01 * STEP)
		if _is_combat(u) and float(u.strength) <= float(_rules.combat.rout_strength) and str(u.stage) != "routed" and str(u.stage) != "exited":
			u.stage = "routed"
			u.order = {}
			u.path = []
			_bump()
			if not _all_taken():
				var fid := str(_rules.groups[u.id].front)
				_finish("defeat", "frente_roto", {"grupo": str(u.name), "lugar": str(_rules.objectives[fid].place)})

func _move_unit(u: Dictionary, env: Dictionary) -> void:
	var path: Array = u.path
	if path.is_empty():
		_arrive(u)
		return
	var budget := _unit_speed(u, env) * STEP
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
			_complete_destroy(u, str(w.item))
	_bump()

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
	var dc: Dictionary = _rules.stealth.dark_cost
	var dark := 1.0 - clampf((float(environment().visibility_m) - float(dc.ramp_from_m)) / (float(dc.ramp_to_m) - float(dc.ramp_from_m)), 0.0, 1.0)
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
	_note_order(_pt(0.0, 0.0))
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
	_set_phase("ataque")
	for fid in V.OBJECTIVES:
		state.objectives[fid].surprise_until = t + float(_rules.time.surprise_s)
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
	u.order = {"action": "attack", "front": front, "posture": posture}
	u.stage = "attacking"
	u.path = []
	u.fatigue = minf(100.0, float(u.fatigue) + float(_rules.combat.fatigue_per_attack))
	if front == "cuartel":
		state.stats.charges_total = int(state.stats.charges_total) + 1
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
	return float(u.men) * (0.5 + 0.5 * float(u.armed)) * float(u.strength) / 100.0 * fatigue_mult * float(posture.power) * _dark_factor()

func _step_combat(t: float) -> void:
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
		var cover := float((_rules.objectives[fid] as Dictionary).cover)
		if float(o.alert) >= 1.0:
			cover *= float(cb.alarm_cover_mult)
		var defense := maxf(float(o.garrison) * cover, 1.0)
		var surprise := 1.0 + float(cb.surprise_bonus_max) * (1.0 - float(o.alert))
		o.toma = minf(100.0, float(o.toma) + float(cb.capture_k) * atk / defense * surprise * STEP)
		o.garrison = float(o.garrison_max) * (1.0 - float(o.toma) / 100.0)
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

func _tower_pos() -> Vector2:
	return _hito_pos(str(_rules.tower.hito[str(state.world.torre_en)]))

func _step_tower(t: float) -> void:
	var tw: Dictionary = state.objectives.cuartel.tower
	var tcfg: Dictionary = _rules.tower
	if not bool(tw.armed) and bool(state.alarm.signaled) and str(state.objectives.cuartel.state) != "tomado":
		if t >= float(state.alarm.first_shot_at) + float(tcfg.arm_delay_s[str(state.world.guardia)]):
			tw.armed = true
			tw.active = true
			tw.next_volley_at = t + float(tcfg.volley_period_s)
			_event("tower", _ts("eventos.torre"), {"objective": "cuartel", "pos": _pt(_tower_pos().x, _tower_pos().y)})
			_bump()
	if not bool(tw.active):
		return
	if t + 1e-9 < float(tw.next_volley_at):
		return
	var tp := _tower_pos()
	var dm: Dictionary = tcfg.damage_mult
	for u in state.units:
		var st := str(u.stage)
		if st == "exited" or st == "routed":
			continue
		var d := _dist(float(u.x), float(u.z), tp.x, tp.y)
		## Quien asalta el cuartel baja por la calle bajo la torre aunque su puesto quede un poco más lejos: de a fondo en calle abierta, con cautela tras las tapias.
		var storming := st == "attacking" and str(u.order.get("front", "")) == "cuartel"
		if (d <= float(tcfg.radius_m) or storming) and d > float(tcfg.dead_angle_m):
			var mult := 1.0
			if storming:
				mult = float(dm.calle_abierta) if str(u.order.get("posture", "")) == "a_fondo" else float(dm.tapia)
			elif st == "moving" and (str(u.pace) == "run" or str(u.pace) == "gallop" or str(u.pace) == "trot"):
				mult = float(dm.corriendo)
			var jitter := 1.0 + 0.5 * (_random() - 0.5)
			u.strength = maxf(0.0, float(u.strength) - float(tcfg.damage_per_volley_pct) * mult * jitter)
			(state.fire_lines as Array).append({"from": _pt(tp.x, tp.y), "to": _pt(float(u.x), float(u.z)), "kind": "torre", "until": t + 1.5})
	tw.volleys_left = int(tw.volleys_left) - 1
	tw.next_volley_at = t + float(tcfg.volley_period_s)
	if int(tw.volleys_left) <= 0:
		tw.active = false
		_event("tower", _ts("eventos.torre_calla"), {"objective": "cuartel"})
		_bump()

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
			_finish("defeat", "sin_carga")
		elif _combat_strength_pct() < float(oc.victory.strength_min_pct):
			_finish("defeat", "dispersos")
		else:
			_finish("victory", "")
		return
	if bool(state.alarm.reinforcement_arrived):
		_finish("defeat", "interceptados")
		return
	if float(state.alarm.first_shot_at) < 0.0 and t >= float(tm.dawn_discovery_s):
		_finish("defeat", "amanecio")
		return
	if bool(state.alarm.signaled) and _combat_strength_pct() < float(oc.victory.strength_min_pct):
		_finish("defeat", "dispersos")
		return
	if t >= float(tm.deadline_s):
		_finish("defeat", "plazo")

func _finish(status: String, cause_id: String, ctx: Dictionary = {}) -> void:
	if str(state.status) != "playing":
		return
	var oc: Dictionary = _rules.outcome
	state.status = status
	state.reason = cause_id if status == "defeat" else "victoria"
	for u in state.units:
		if str(u.stage) != "exited":
			u.order = {}
			u.path = []
			u.work = {}
			if str(u.stage) == "moving" or str(u.stage) == "scouting" or str(u.stage) == "loading" or str(u.stage) == "retreating":
				u.stage = "idle"
		u.noise = 0.0
	_finalize_loot()
	_set_phase("epilogo")
	var out := {"cause_id": "", "title": "", "cause": "", "advice": ""}
	if status == "victory":
		out.title = str(oc.victory.titulo)
		out.cause = str(oc.victory.por_que)
	else:
		var c: Dictionary = oc.causes[cause_id]
		var vars := {"t": _clock(float(state.elapsed)), "lugar": str(ctx.get("lugar", _default_place())), "grupo": str(ctx.get("grupo", _tx("una_partida")))}
		out.cause_id = cause_id
		out.title = str(c.titulo)
		out.cause = _fmt(str(c.texto), vars)
		out.advice = str(c.consejo)
	state.outcome = out
	_event(status, str(out.cause), {"strong": true})

func _default_place() -> String:
	var worst := "bateria"
	for fid in V.OBJECTIVES:
		if str(state.objectives[fid].state) != "tomado" and float(state.objectives[fid].alert) >= float(state.objectives[worst].alert):
			worst = fid
	return str(_rules.objectives[worst].place)

func _finalize_loot() -> void:
	var l: Dictionary = state.loot
	for it in l.items:
		if str(it.state) == "en_sitio" or str(it.state) == "cargado":
			l.lost_value = float(l.lost_value) + float(it.qty) * float(it.unit_value)
			it.state = "abandonado"
			it.carried_by = ""

# ---------------------------------------------------------------------------------------------------------------------
# Reconocimiento y botín

func _recon_radius_for(fid: String) -> float:
	var rc: Dictionary = _rules.stealth.recon
	var base := float(rc.radius_m)
	if float(environment().visibility_m) < float(rc.dark_below_m):
		base = float(rc.radius_dark_m)
	for lg in _level.lights:
		if str(lg.get("objective", "")) == fid:
			return maxf(base, float(rc.lit_radius_m))
	return base

func _complete_recon(u: Dictionary) -> void:
	var rc: Dictionary = _rules.stealth.recon
	for fid in V.OBJECTIVES:
		var c := _hito_pos(str(_rules.objectives[fid].hito))
		if _dist(float(u.x), float(u.z), c.x, c.y) > _recon_radius_for(fid):
			continue
		var o: Dictionary = state.objectives[fid]
		var first := float(o.reconocido) < 1.0
		o.reconocido = 1.0
		if not (state.recon.fronts as Array).has(fid):
			(state.recon.fronts as Array).append(fid)
		if first:
			_event("recon", _ts("eventos.reconocido", {"texto": str(_rules.objectives[fid].reveal_text)}), {"objective": fid, "unit": str(u.id), "pos": _pt(c.x, c.y), "strong": true})
		var risk := float(rc.risk_base) + float(rc.risk_per_noise) * float(_rules.stealth.pace.march.noise) + float(rc.risk_per_alert) * float(o.alert)
		if _random() < risk:
			u.detected = true
			state.stats.detections = int(state.stats.detections) + 1
			o.alert = minf(1.0, float(o.alert) + 0.15)
			_event("detected", _ts("eventos.detectado", {"frente": str(_rules.objectives[fid].place)}), {"objective": fid, "unit": str(u.id)})
	_bump()

func _item(id: String) -> Dictionary:
	for it in state.loot.items:
		if str(it.id) == id:
			return it
	return {}

func _item_kg(it: Dictionary) -> float:
	return float(it.qty) * float(it.unit_kg)

func _item_value(it: Dictionary) -> float:
	return float(it.qty) * float(it.unit_value)

## El lote en sitio de un frente ya tomado que más puntos da por kilo, que entre en `room_kg` (o -1 para cualquiera), cerca de `near` si se pide.
func _best_item(room_kg: float, near: Variant = null, radius: float = -1.0, destroying: bool = false) -> Dictionary:
	var best: Dictionary = {}
	var best_density := -1.0
	for it in state.loot.items:
		if str(it.state) != "en_sitio" or str(state.objectives[str(it.front)].state) != "tomado":
			continue
		if room_kg >= 0.0 and _item_kg(it) > room_kg + 1e-6:
			continue
		if near is Vector2 and radius >= 0.0 and _dist(float(it.x), float(it.z), (near as Vector2).x, (near as Vector2).y) > radius:
			continue
		var density := _item_value(it) / _item_kg(it)
		if destroying:
			density = _item_value(it) / float(_rules.loot.classes[str(it.kind)].destroy_s)  # lo que más valor quita por segundo
		if density > best_density:
			best_density = density
			best = it
	return best

func _complete_load(u: Dictionary, item_id: String) -> void:
	var it := _item(item_id)
	if it.is_empty() or str(it.state) != "en_sitio":
		return
	it.state = "cargado"
	it.carried_by = str(u.id)
	u.carry_kg = float(u.carry_kg) + _item_kg(it)
	state.loot.load_kg = float(state.loot.load_kg) + _item_kg(it)
	_event("load", _ts("eventos.carga", {"carga": "%s (%d kg)" % [str(_rules.loot.classes[str(it.kind)].name).to_lower(), roundi(_item_kg(it))]}), {"unit": str(u.id)})

func _complete_destroy(u: Dictionary, item_id: String) -> void:
	var it := _item(item_id)
	if it.is_empty() or str(it.state) != "en_sitio":
		return
	it.state = "destruido"
	state.loot.destroyed_value = float(state.loot.destroyed_value) + _item_value(it) * float(_rules.loot.treatments.destruir)
	_event("destroy", _ts("eventos.destruido", {"carga": str(_rules.loot.classes[str(it.kind)].name).to_lower()}), {"unit": str(u.id)})
	if str(it.kind) == "polvora":
		var sm: Dictionary = _rules.reinforcement.smoke_advance_s
		var per := float(sm.first) if int(state.smoke_used) == 0 else float(sm.next)
		var adv := minf(per, float(sm.cap) - float(state.smoke_adv))
		if float(state.alarm.reinforcement_at) >= 0.0 and adv > 0.0:
			state.alarm.reinforcement_at = float(state.alarm.reinforcement_at) - adv
			state.smoke_adv = float(state.smoke_adv) + adv
		state.smoke_used = int(state.smoke_used) + 1

func _exit_unit(u: Dictionary) -> void:
	var l: Dictionary = state.loot
	var delivered := 0.0
	var kg := 0.0
	for it in l.items:
		if str(it.state) == "cargado" and str(it.carried_by) == str(u.id):
			var mult := float(_rules.loot.treatments.entregar)
			if bool(it.get("wet", false)):
				mult *= float(_rules.loot.powder_wet_mult)
				state.stats.powder_wet = 1
			delivered += _item_value(it) * mult
			kg += _item_kg(it)
			it.state = "entregado"
			it.carried_by = ""
	l.delivered_value = float(l.delivered_value) + delivered
	l.load_kg = maxf(0.0, float(l.load_kg) - kg)
	u.carry_kg = 0.0
	u.stage = "exited"
	u.order = {}
	u.path = []
	_event("exit", _ts("eventos.salio", {"kg": roundi(kg)}), {"unit": str(u.id), "strong": true})
	_bump()

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
			var d := _dist(target.x, target.y, c.x, c.y)
			if d < best_d:
				best_d = d
				best = fid
		if best_d <= 60.0:
			return best
	return default_front

func _attack_post(front: String, opts: Dictionary) -> Vector2:
	var posts: Array = _level.access.attack_posts[front]
	var approach := str(opts.get("approach", ""))
	for p in posts:
		if approach != "" and str(p.get("approach", "")) == approach:
			return Vector2(float(p.x), float(p.z))
	return Vector2(float(posts[0].x), float(posts[0].z))

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
	var ctx := {"ok": true, "reason": "", "unit": u, "pace": pace, "dest": Vector2.ZERO, "front": "", "item": {}, "waypoints": _waypoints(opts)}
	if (ctx.waypoints as Array).size() > 4:
		return _no("paradas")
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
			ctx.dest = _attack_post(fp, opts)
		"attack":
			var fa := _front_from(target, opts, str(_rules.groups[u.id].front))
			if fa == "" or not _is_combat(u):
				return _no("sin_frente" if fa == "" else "no_corresponde")
			if str(state.objectives[fa].state) == "tomado":
				return _no("frente_tomado")
			var c := _hito_pos(str(_rules.objectives[fa].hito))
			if _dist(float(u.x), float(u.z), c.x, c.y) > float(_rules.combat.attack_range_m):
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
			if _dist(float(u.x), float(u.z), float(it.x), float(it.z)) > radius:
				return _no("lejos_carga", {"radio": roundi(radius)})
			if action == "load" and float(state.loot.load_kg) + _item_kg(it) > float(state.loot.capacity_kg) + 1e-6:
				return _no("no_entra", {"kg": roundi(float(state.loot.load_kg) + _item_kg(it) - float(state.loot.capacity_kg))})
			ctx.item = it
		"leave":
			if not _all_taken():
				return _no("sin_tomar")
	return ctx

func _go(u: Dictionary, points: Array, order: Dictionary) -> void:
	var path: Array = []
	for p in points:
		path.append(_pt((p as Vector2).x, (p as Vector2).y))
	u.path = path
	u.order = order
	u.stage = "moving"
	u.work = {}

func _note_order(target: Dictionary) -> void:
	var t := float(state.elapsed)
	var pace_stats: Dictionary = state.stats.pacing
	var last: Dictionary = state.pacing_last
	if float(pace_stats.first_decision_s) < 0.0:
		pace_stats.first_decision_s = t
	pace_stats.decision_gap_max_s = maxf(float(pace_stats.decision_gap_max_s), t - float(last.any))
	if str(state.phase) == "ataque":
		var from := float(last.attack) if float(last.attack) >= 0.0 else float(state.alarm.signal_at)
		pace_stats.decision_gap_attack_max_s = maxf(float(pace_stats.decision_gap_attack_max_s), t - from)
		last.attack = t
	last.any = t
	pace_stats.events_per_min = 60.0 * float((state.log as Array).size()) / maxf(t, 60.0)
	(state.orders as Array).append({"time": t, "round": 1, "unit": "", "action": "", "target": target})
	if (state.orders as Array).size() > 200:
		state.orders = (state.orders as Array).slice((state.orders as Array).size() - 200)

func issue_order(actor_id: String, action: String, target: Vector2 = Vector2.ZERO, opts: Dictionary = {}) -> Dictionary:
	if action == "give_signal":
		var r := give_signal()
		return {"ok": bool(r.ok), "reason": str(r.reason), "path": [], "plan": {}}
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
	_note_order(_pt(float(c.dest.x), float(c.dest.y)))
	var last: Dictionary = (state.orders as Array)[(state.orders as Array).size() - 1]
	last.unit = str(u.id)
	last.action = action
	last["prev"] = {"stage": str(u.stage), "order": (u.order as Dictionary).duplicate(true)}
	u.detected = false
	u.pace = str(c.pace)
	var posture := str(opts.get("posture", "con_cautela"))
	if not R.POSTURES.has(posture):
		posture = "con_cautela"
	match action:
		"move":
			_go(u, (c.waypoints as Array) + [c.dest], {"action": "move", "x": float(c.dest.x), "z": float(c.dest.y)})
		"position":
			_go(u, (c.waypoints as Array) + [c.dest], {"action": "position", "front": str(c.front)})
		"attack":
			u.order = {"posture": posture}
			_start_attack(u, str(c.front))
		"support":
			_go(u, (c.waypoints as Array) + [c.dest], {"action": "support", "front": str(c.front), "posture": posture})
		"recon":
			_go(u, (c.waypoints as Array) + [_recon_stop(u, c.dest)], {"action": "recon", "x": float(c.dest.x), "z": float(c.dest.y)})
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
			if str(u.id) == "arreo" and float(u.carry_kg) <= 0.0:
				_auto_load(u)
			_go(u, [_hito_pos("vado_este"), _hito_pos("salida_este")], {"action": "leave"})
		"hold":
			u.order = {}
			u.path = []
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
		if _dist(target.x, target.y, c.x, c.y) <= r:
			var from := Vector2(float(u.x), float(u.z))
			var d := from.distance_to(c)
			if d <= r * 0.9:
				return from
			return c + (from - c).normalized() * r * 0.9
	return target

## Convención del stub: al salir sin carga, el arreo se lleva lo que entra por densidad (puntos por kilo).
func _auto_load(u: Dictionary) -> void:
	while true:
		var room := float(state.loot.capacity_kg) - float(state.loot.load_kg)
		var it := _best_item(room)
		if it.is_empty():
			break
		_complete_load(u, str(it.id))

func cancel_order(actor_id: String) -> Dictionary:
	return issue_order(actor_id, "cancel")

func undo_last() -> Dictionary:
	if state.is_empty() or str(state.status) != "playing":
		return _no("partida_terminada")
	var orders: Array = state.orders
	while not orders.is_empty():
		var last: Dictionary = orders.pop_back()
		var u := _unit(str(last.get("unit", "")))
		if u.is_empty() or str(last.get("action", "")) == "":
			continue
		u.order = {}
		u.path = []
		u.work = {}
		if str(u.stage) != "exited" and str(u.stage) != "routed":
			u.stage = "idle"
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

func set_mercy(level: int) -> void:
	if not state.is_empty():
		state.mercy_level = clampi(level, 0, 3)

func apply_assist(_kind: String) -> Dictionary:
	return _no("sin_ayuda")

func pending_choice() -> Dictionary:
	return {}

func resolve_choice(_option_id: String, _by_timeout: bool = false) -> Dictionary:
	return _no("sin_decision")

# Decisiones del mando realista (forma del Norte): en el stub solo la alternativa local, sin tabla.
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
# Consultas de solo lectura (stub_rules_info.gd)

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

## Las aproximaciones de cada frente desde la zona de partida (línea recta al puesto de ataque de cada enfoque). Solo lectura.
func route_atlas(front: String = "") -> Array:
	return _info().route_atlas(front)

# ---------------------------------------------------------------------------------------------------------------------
# Guardado y validación (stub_rules_save.gd)

func snapshot() -> Dictionary:
	return state.duplicate(true)

func save_game(path: String) -> Error:
	return Save.write(path, state)

func load_game(path: String) -> Dictionary:
	var read := Save.read(path)
	if not bool(read.ok):
		return {"ok": false, "reason": str(read.reason)}
	var check := validate_snapshot(read.data)
	if not bool(check.ok):
		return check
	var loaded: Dictionary = (read.data as Dictionary).duplicate(true)
	Save.fix_ints(loaded)
	loaded.previous_game_id = str(loaded.game_id)
	loaded.state_version = int(loaded.state_version) + 1
	loaded.game_id = "humahuaca-%d-%d-%d" % [int(loaded.seed), int(loaded.attempt), int(loaded.state_version)]
	state = loaded
	_events = []
	_event("info", _ts("eventos.guardado"))
	return {"ok": true, "reason": "Partida recuperada.", "state": state}

## Reemplaza el estado por `d` si es válido, sin tocar archivos ni el id (la usan la ramificación de decisiones y los puntos de control).
func restore_snapshot(d: Dictionary) -> Dictionary:
	var check := validate_snapshot(d)
	if not bool(check.ok):
		return check
	state = d.duplicate(true)
	Save.fix_ints(state)
	_events = []
	return {"ok": true, "reason": ""}

func validate_snapshot(v: Variant) -> Dictionary:
	return Save.validate(v, float(_rules.get("map_version", 1)), map_size())
