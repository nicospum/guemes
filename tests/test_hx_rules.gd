extends SceneTree
## Pruebas de la capa de reglas del nivel «humahuaca» (CONTRATO 3.2, 3.3, 3.6 y 5.1). Dueña: reglas_historia. Sin ventana:
##   godot --headless --path . --script tests/test_hx_rules.gd [-- --ronda=r1 --skip-strategies --impl=stub|real]
## Prueba la capa EFECTIVA: la clase real (rules/humahuaca_rules.gd y humahuaca_progress.gd) si existe y, si no, el stub; `--impl=` fuerza una u otra. Las cifras se leen de
## data/humahuaca_rules.json (no se repiten acá) y las partidas ganadas las juega la biblioteca de políticas, no un guion aparte. Rutas de A*, visión, torre, ritmo, controles y
## políticas viven en tests/hx_rules_checks.gd (tope de líneas del contrato) y cuentan en esta misma suite. La línea final trae `performance` (nav_build_ms_avg ≤ 80,
## plan_route_ms_avg ≤ 30, tick_ms_avg ≤ 2). Lo que no se puede evaluar queda en `pending` y pasa a ser falla desde su ronda («no evaluable = falla»). `--skip-strategies` es el
## modo rápido de la compuerta; la matriz de enfoques, el barrido de la señal y las recetas de extracción son de R2b. Piso de comprobaciones: 150 desde r1. Tiempo: < 60 s.
## Escribe solo en user:// y se niega a correr sin APPDATA aislado (export APPDATA="$TEMP/ap_iso_<pista>").

const Fx = preload("res://tests/hx_fixtures.gd")
const V = preload("res://scripts/humahuaca/humahuaca_vocab.gd")
const R = preload("res://scripts/humahuaca/rules/vocab_rules.gd")
const Checks = preload("res://tests/hx_rules_checks.gd")

const SAVE_PATH := "user://hx_rules_test_save.json"
const PROGRESS_PATH := "user://hx_rules_test_progress.json"
const CHECKPOINT_PATH := "user://hx_rules_test_checkpoint.json"
const TOLERANCE := 1e-6
## Las cinco muestras de VP-01: [segundos de juego, time_of_day pedido]. La tolerancia del pedido es ±0,05.
const VP01_SAMPLES := [[0.0, 0.0], [240.0, 0.0], [285.0, 0.5], [330.0, 0.67], [420.0, 1.0]]
const VP01_TOLERANCE := 0.05
## Campos que `state` tiene que traer (CONTRATO 3.2.1) y su tipo («int» exige entero; los demás son los de Fx.kind_of).
const STATE_FIELDS := {
	"schema_version": "int", "game_id": "string", "state_version": "int", "scenario": "string", "map_id": "string", "map_version": "int", "contract": "int",
	"seed": "int", "rng_state": "int", "attempt": "int", "elapsed": "number", "accumulator": "number", "status": "string", "reason": "string", "phase": "string",
	"resistencia": "bool", "world": "dict", "alarm": "dict", "objectives": "dict", "units": "array", "loot": "dict", "recon": "dict", "stats": "dict", "log": "array"}
const WORLD_FIELDS := ["guardia", "torre_en", "refugio", "lluvia", "refuerzo", "layout", "loot_traits", "known", "rumors"]
const ALARM_FIELDS := ["level", "first_shot_at", "signaled", "signal_at", "messenger", "reinforcement_at", "reinforcement_arrived"]
const OBJECTIVE_FIELDS := ["state", "toma", "garrison", "garrison_max", "alert", "surprise_until", "reconocido", "held_by", "custody", "taken_at", "supporters"]
const UNIT_FIELDS := ["id", "name", "kind", "x", "z", "strength", "fatigue", "morale", "armed", "men", "mounted", "pace", "stage", "order", "path", "noise", "detected",
	"custody", "horses", "carry_kg", "capacity_kg", "tag"]
const LOOT_FIELDS := ["items", "capacity_kg", "load_kg", "delivered_value", "destroyed_value", "hidden_value", "lost_value", "total_value"]
const ITEM_FIELDS := ["id", "kind", "qty", "unit_kg", "unit_value", "state", "x", "z", "where", "carried_by", "spot", "safe"]
const STATS_FIELDS := ["start_strength", "detections", "losses", "support_events", "horses_lost", "powder_wet", "pacing", "charges_total", "charges_in_gap"]
const PACING_FIELDS := ["decision_gap_max_s", "decision_gap_attack_max_s", "first_decision_s", "events_per_min", "visible_actions_t0"]

var suite := Fx.new()
var round_id := "r0"
var impl := "stub"
var rules_script: Script = null
var progress_script: Script = null
var cfg: Dictionary = {}
var level: Dictionary = {}
var map: Dictionary = {}
var game_rules_script: Script = null
var pol: Script = null  # la biblioteca de políticas (rules/humahuaca_policies.gd); null si falta o no carga
var nav_script: Script = null  # la grilla de navegación (rules/humahuaca_nav.gd)

func _initialize() -> void:
	suite.begin("hx_rules", OS.get_cmdline_user_args())
	round_id = suite.round_id
	var forced := ""
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--impl="):
			forced = str(arg).trim_prefix("--impl=")
	if not Fx.profile_isolated():
		ck(false, "perfil NO aislado (%s): exportá APPDATA=\"$TEMP/ap_iso_<pista>\" antes de correr; esta prueba escribe en user://" % OS.get_user_data_dir())
		print(JSON.stringify(suite.report()))
		quit(2)
		return
	cfg = _dict(Fx.read_json(V.RULES_PATH))
	level = _dict(Fx.read_json(V.LEVEL_PATH))
	map = _dict(Fx.read_json(V.MAP_PATH))
	var real_rules := Fx.load_script(Fx.REAL_PATHS.rules)
	var real_progress := Fx.load_script(Fx.REAL_PATHS.progress)
	for key in ["rules", "progress"]:
		if ResourceLoader.exists(Fx.REAL_PATHS[key]) and Fx.load_script(Fx.REAL_PATHS[key]) == null:
			ck(false, "la clase real de %s existe pero no carga ni se puede instanciar (%s): no se la reemplaza por el stub en silencio" % [key, Fx.REAL_PATHS[key]])
	if forced == "real":
		ck(real_rules != null and real_progress != null, "--impl=real pide las dos clases reales y falta alguna")
	var want_real := forced != "stub"
	rules_script = real_rules if want_real and real_rules != null else Fx.load_script(Fx.STUB_PATHS.rules)
	progress_script = real_progress if want_real and real_progress != null else Fx.load_script(Fx.STUB_PATHS.progress)
	impl = "real" if want_real and real_rules != null else "stub"
	suite.extra["impl_progreso"] = "real" if want_real and real_progress != null else "stub"
	game_rules_script = load("res://scripts/game_rules.gd")
	pol = Fx.load_script("res://scripts/humahuaca/rules/humahuaca_policies.gd")
	nav_script = Fx.load_script("res://scripts/humahuaca/rules/humahuaca_nav.gd")
	suite.extra["impl"] = impl
	suite.extra["modo"] = "rapido" if OS.get_cmdline_user_args().has("--skip-strategies") else "completo"
	if not ck(rules_script != null and progress_script != null and not cfg.is_empty() and not level.is_empty() and not map.is_empty(), "cargan las clases de reglas y progreso (%s) y los tres JSON" % impl):
		suite.finish(self)
		return
	_cleanup_files()
	_test_api()
	_test_state_fields()
	_test_determinism()
	_test_world_from_seed()
	_test_phases()
	_test_environment_curve()
	_test_hud_state_all_phases()
	_test_render_state()
	_test_render_state_blindness()
	_test_render_state_tower()
	_test_campaign_report_shape()
	_test_plan_route_shape()
	_test_actions_r1()
	_test_order_errors()
	_test_stealth_and_signal()
	_test_tower()
	_test_reinforcement()
	_test_loot_and_treatments()
	_test_outcomes()
	_test_event_kinds()
	_test_save_roundtrip()
	_test_save_mutations()
	_test_foreign_saves()
	_test_progress()
	_test_progress_win_next()
	_checks().call("_test_progress_checkpoints_and_diary")
	_checks().call("_test_nav_and_routes")
	_checks().call("_test_sentinels_and_tower_sight")
	_checks().call("_test_pacing_offers")
	_test_policies_extremes()
	_test_policies_blindness()
	_test_performance()
	_test_pending_for_r1()
	suite.check(suite.elapsed_ms() < 60000, "test_hx_rules corre en poco tiempo (objetivo < 60 s, CONTRATO 5.1): %d ms" % suite.elapsed_ms())
	_cleanup_files()
	suite.finish(self)

# ---------------------------------------------------------------------------------------------------------------------
# Ayudas

func ck(cond: bool, what: String) -> bool:
	return suite.check(cond, what)

## Lo que solo el stub garantiza.
func stub_only() -> bool:
	return impl == "stub"

## Lo que solo tiene la clase real (rutas de A*, visión de los centinelas, causa «descubiertos», puntos de control).
func real_only() -> bool:
	return impl == "real"

static func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}

func _cleanup_files() -> void:
	for p in [SAVE_PATH, PROGRESS_PATH, CHECKPOINT_PATH, PROGRESS_PATH + ".tmp", SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func new_rules(seed_value: int = 1817, opts: Dictionary = {}, attempt: int = 1) -> RefCounted:
	var r: RefCounted = rules_script.new()
	r.call("new_game", seed_value, attempt, opts)
	return r

func new_progress() -> RefCounted:
	return progress_script.new(PROGRESS_PATH, CHECKPOINT_PATH)

func kind_ok(v: Variant, kind: String) -> bool:
	if kind == "int":
		return typeof(v) == TYPE_INT
	return Fx.kind_of(v) == kind

func missing_keys(d: Variant, keys: Array) -> Array:
	var out: Array = []
	if not (d is Dictionary):
		return keys.duplicate()
	for k in keys:
		if not (d as Dictionary).has(k):
			out.append(k)
	return out

func hito(id: String) -> Vector2:
	for lm in map.get("landmarks", []):
		if lm is Dictionary and str(lm.get("id", "")) == id:
			return Vector2(float(lm.x), float(lm.z))
	return Vector2(-1.0, -1.0)

func snap_hash(r: RefCounted) -> String:
	return JSON.stringify(r.call("snapshot"), "", true, true).sha256_text()

## Avanza de a `dt` hasta `t_end` (o hasta que la partida termine).
func run_to(r: RefCounted, t_end: float, dt: float = 1.0) -> void:
	var guard := 0
	while str(r.state.status) == "playing" and float(r.state.elapsed) < t_end - 1e-9 and guard < 5000:
		guard += 1
		r.call("tick", minf(dt, t_end - float(r.state.elapsed)))

## Avanza hasta que `pred` sea verdadero o pasen `limit_s` de juego. Devuelve si se cumplió.
func run_until(r: RefCounted, pred: Callable, limit_s: float, dt: float = 1.0) -> bool:
	var t_stop := float(r.state.elapsed) + limit_s
	while float(r.state.elapsed) < t_stop and str(r.state.status) == "playing":
		if pred.call():
			return true
		r.call("tick", dt)
	return pred.call()

func unit_of(r: RefCounted, id: String) -> Dictionary:
	return _dict(r.call("get_unit", id))

## La agrupación del estado (no una copia): las pruebas que arman una situación la editan.
func unit_dict(r: RefCounted, id: String) -> Dictionary:
	for u in r.state.units:
		if str(u.id) == id:
			return u
	return {}

func order(r: RefCounted, actor: String, action: String, target: Vector2 = Vector2.ZERO, opts: Dictionary = {}) -> Dictionary:
	return _dict(r.call("issue_order", actor, action, target, opts))

func same(a: Variant, b: Variant) -> bool:
	if (a is float or a is int) and (b is float or b is int):
		return absf(float(a) - float(b)) <= TOLERANCE
	if a is Dictionary and b is Dictionary:
		if (a as Dictionary).size() != (b as Dictionary).size():
			return false
		for k in a:
			if not (b as Dictionary).has(k) or not same(a[k], b[k]):
				return false
		return true
	if a is Array and b is Array:
		if (a as Array).size() != (b as Array).size():
			return false
		for i in (a as Array).size():
			if not same(a[i], b[i]):
				return false
		return true
	return a == b

## `state` sin lo que cambia al guardar y cargar (CONTRATO 3.2.4): ids, versión y el evento de carga.
func strip(s: Dictionary) -> Dictionary:
	var d: Dictionary = s.duplicate(true)
	for k in ["game_id", "previous_game_id", "state_version", "log"]:
		d.erase(k)
	return d

## Compara la forma de una salida con el ejemplo de docs/humahuaca/forma/ (CONTRATO 3.6). Una comprobación.
func shape(forma_name: String, out: Variant, label: String) -> bool:
	var forma := Fx.load_forma(forma_name)
	if forma.is_empty():
		return ck(false, "existe el ejemplo de forma %s" % forma_name)
	var diffs := Fx.shape_diff(forma.example, out, forma.optional) if out is Dictionary else ["no es un Dictionary"]
	return ck(diffs.is_empty(), "forma de %s en %s: %s" % [forma_name, label, str(diffs)])

## Juega `policy` de la biblioteca única (decide, aplica y avanza de a un segundo) hasta `until_s` o hasta que termine la partida.
func play_policy(r: RefCounted, policy: String, until_s: float = 900.0) -> void:
	if pol == null:
		return
	var mem := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 1817
	var guard := 0
	while str(r.state.status) == "playing" and float(r.state.elapsed) < until_s - 1e-9 and guard < 5000:
		guard += 1
		var view: Dictionary = pol.call("make_view", r, policy, mem)
		pol.call("apply_orders", r, pol.call("decide", policy, view, rng))
		r.call("tick", minf(1.0, until_s - float(r.state.elapsed)))

## La partida ganadora de la prueba: la del experto (reconoce, lleva cada partida a su puesto, da la señal, socorre, carga lo que más puntos da por kilo y sale).
func play_by_hand(r: RefCounted, until_s: float = 840.0) -> void:
	play_policy(r, "experto", until_s)

## Sigue el «siguiente paso» de hud_state() una orden por segundo hasta que termine la partida (la política «obediente» del contrato 3.2.5, mínima).
## Devuelve las fases por las que pasó y todos los eventos que entregó tick.
func follow_next_step(r: RefCounted, max_s: float = 900.0) -> Dictionary:
	var phases: Array = []
	var events: Array = []
	var last := ""
	while str(r.state.status) == "playing" and float(r.state.elapsed) < max_s:
		var nxt: Dictionary = _dict(r.call("hud_state")).get("siguiente", {})
		var act := str(nxt.get("action", ""))
		if act == "give_signal":
			r.call("give_signal")
		elif act != "" and act != "hold" and act != "cancel":
			var tgt := Vector2.ZERO
			var t_raw: Variant = nxt.get("target", {})
			if t_raw is Dictionary and not (t_raw as Dictionary).is_empty():
				tgt = Vector2(float(t_raw.x), float(t_raw.z))
			order(r, str(nxt.actor), act, tgt)
		events.append_array(r.call("tick", 1.0))
		if str(r.state.phase) != last:
			last = str(r.state.phase)
			phases.append(last)
	return {"phases": phases, "events": events}

# ---------------------------------------------------------------------------------------------------------------------
# API y estado

func _test_api() -> void:
	ck(Fx.api_missing(rules_script, "rules").is_empty(), "la clase de reglas tiene toda la API del contrato 3.2: %s" % str(Fx.api_missing(rules_script, "rules")))
	ck(Fx.api_missing(progress_script, "progress").is_empty(), "la clase de progreso tiene toda la API del contrato 3.3: %s" % str(Fx.api_missing(progress_script, "progress")))
	var consts: Dictionary = rules_script.get_script_constant_map()
	ck(str(consts.get("SCENARIO", "")) == "humahuaca", "SCENARIO es «humahuaca» (nunca se le pasa a GameRules)")
	ck(int(consts.get("SAVE_VERSION", 0)) == 1, "SAVE_VERSION es 1")
	ck(absf(float(consts.get("STEP", 0.0)) - 0.25) < TOLERANCE, "STEP es 0,25 s (paso fijo)")
	var r := new_rules()
	ck(r.call("map_size") == Vector2(900.0, 650.0), "map_size() es 900 × 650 m")
	var md: Dictionary = _dict(r.call("map_data"))
	ck(md.has("landmarks") and md.has("features") and md.has("environment") and md.has("tower"), "map_data() fusiona mapa, nivel y reglas (hitos, rasgos, ambiente y torre)")
	ck(r.call("terrain_height_at", 450.0, 325.0) is float, "terrain_height_at devuelve un número")

func _test_state_fields() -> void:
	var r := new_rules(1817)
	var s: Dictionary = r.state
	var bad: Array = []
	for k in STATE_FIELDS:
		if not s.has(k) or not kind_ok(s[k], STATE_FIELDS[k]):
			bad.append(k)
	ck(bad.is_empty(), "state trae los campos mínimos de 3.2.1 con su tipo: %s" % str(bad))
	ck(int(s.schema_version) == 1 and str(s.scenario) == "humahuaca" and str(s.map_id) == "humahuaca" and int(s.contract) == 1, "identidad del estado: schema 1, escenario, mapa y contrato")
	ck(int(s.map_version) == int(map.get("map_version", -1)), "map_version del estado = el del JSON del mapa")
	ck(int(s.seed) == 1817 and int(s.attempt) == 1 and float(s.elapsed) == 0.0 and str(s.status) == "playing" and str(s.phase) == "briefing", "arranca en el briefing, jugando, en 0:00 y con la semilla pedida")
	ck(int(s.rng_state) > 0, "rng_state propio y positivo")
	ck(missing_keys(s.world, WORLD_FIELDS).is_empty(), "state.world tiene %s" % str(missing_keys(s.world, WORLD_FIELDS)))
	ck(missing_keys(s.alarm, ALARM_FIELDS).is_empty(), "state.alarm tiene %s" % str(missing_keys(s.alarm, ALARM_FIELDS)))
	ck(float(s.alarm.first_shot_at) == -1.0 and float(s.alarm.signal_at) == -1.0 and not bool(s.alarm.signaled), "sin disparos ni señal al empezar (first_shot_at y signal_at valen -1)")
	ck((s.objectives as Dictionary).keys() == V.OBJECTIVES, "state.objectives trae los tres frentes en el orden del vocabulario")
	for fid in V.OBJECTIVES:
		var o: Dictionary = s.objectives[fid]
		ck(missing_keys(o, OBJECTIVE_FIELDS).is_empty() and R.FRONT_STATES.has(str(o.state)) and str(o.state) == "guardado", "frente %s: campos de 3.2.1 y estado inicial guardado (falta %s)" % [fid, str(missing_keys(o, OBJECTIVE_FIELDS))])
	ck((s.objectives.cuartel as Dictionary).has("tower") and (s.objectives.bateria as Dictionary).has("battery"), "la torre cuelga del cuartel y la batería de la batería")
	ck((s.units as Array).size() == 5, "hay 5 agrupaciones")
	var ids: Array = []
	for u in s.units:
		ids.append(u.id)
		var gaps := missing_keys(u, UNIT_FIELDS)
		var u_ok: bool = gaps.is_empty() and R.STAGES.has(str(u.stage)) and R.PACES.has(str(u.pace)) and V.TAGS.has(str(u.tag)) and R.UNIT_KINDS.has(str(u.kind))
		u_ok = u_ok and float(u.x) >= 0.0 and float(u.x) <= 900.0 and float(u.z) >= 0.0 and float(u.z) <= 650.0
		u_ok = u_ok and float(u.strength) >= 0.0 and float(u.strength) <= 100.0 and float(u.fatigue) >= 0.0 and float(u.noise) >= 0.0 and float(u.noise) <= 1.0
		ck(u_ok, "unidad %s: campos de 3.2.1, vocabulario y rangos (falta %s)" % [str(u.get("id", "?")), str(gaps)])
	ck(ids == V.GROUPS, "las unidades son las cinco agrupaciones, sin repetir y en el orden de teclas 1 a 5")
	ck(missing_keys(s.loot, LOOT_FIELDS).is_empty() and absf(float(s.loot.total_value) - 100.0) < TOLERANCE, "state.loot trae sus campos y total_value = 100")
	var item_bad: Array = []
	var total := 0.0
	for it in s.loot.items:
		total += float(it.qty) * float(it.unit_value)
		if not missing_keys(it, ITEM_FIELDS).is_empty() or not R.LOOT_KINDS.has(str(it.kind)) or not R.LOOT_STATES.has(str(it.state)):
			item_bad.append(str(it.get("id", "?")))
	ck(item_bad.is_empty() and not (s.loot.items as Array).is_empty(), "cada lote trae sus campos y sus ids de vocabulario: %s" % str(item_bad))
	ck(absf(total - 100.0) < 1e-4, "los lotes suman 100 puntos de golpe (suman %.4f)" % total)
	if not Fx.round_ge(round_id, "r2a"):
		var kinds := {}
		for it in s.loot.items:
			kinds[str(it.kind)] = true
		var outside_r1: Array = []
		for k in kinds:
			if not R.LOOT_KINDS_R1.has(k):
				outside_r1.append(k)
		ck(outside_r1.is_empty(), "en R1 el botín tiene solo las 5 clases de LOOT_KINDS_R1 (fuera de la lista: %s)" % str(outside_r1))
	ck(missing_keys(s.stats, STATS_FIELDS).is_empty() and missing_keys(s.stats.pacing, PACING_FIELDS).is_empty(), "state.stats y stats.pacing traen sus campos: %s %s" % [str(missing_keys(s.stats, STATS_FIELDS)), str(missing_keys(s.stats.pacing, PACING_FIELDS))])
	var sum_start := 0
	for g in V.GROUPS:
		sum_start += 1 if (s.stats.start_strength as Dictionary).has(g) else 0
	ck(sum_start == 5, "stats.start_strength tiene la fuerza inicial de las cinco agrupaciones")
	ck((s.log as Array).size() <= 400, "state.log respeta el tope de 400 eventos")
	ck(bool(_dict(r.call("validate_snapshot", r.call("snapshot"))).ok), "el estado inicial pasa validate_snapshot")

# ---------------------------------------------------------------------------------------------------------------------
# Determinismo y mundo

func _test_determinism() -> void:
	var a := new_rules(1817, {"skip_intro": true})
	var b := new_rules(1817, {"skip_intro": true})
	ck(snap_hash(a) == snap_hash(b), "la misma semilla da el mismo estado inicial")
	if pol != null:
		play_by_hand(a, 60.0)
		play_by_hand(b, 60.0)
		ck(snap_hash(a) == snap_hash(b), "dos partidas con las mismas órdenes dan el mismo estado a los 60 s")
		play_by_hand(a, 200.0)
		play_by_hand(b, 200.0)
		ck(snap_hash(a) == snap_hash(b), "...y a los 200 s")
	var split_a := new_rules(1817, {"phase": "ataque"})
	var split_b := new_rules(1817, {"phase": "ataque"})
	var split_c := new_rules(1817, {"phase": "ataque"})
	for i in range(60):
		split_a.call("tick", 1.0)
	for i in range(240):
		split_b.call("tick", 0.25)
	split_c.call("tick", 60.0)
	ck(snap_hash(split_a) == snap_hash(split_b) and snap_hash(split_b) == snap_hash(split_c), "tick(1)×60, tick(0,25)×240 y tick(60) dan el mismo estado (paso fijo con acumulador)")
	var adv := new_rules(1817, {"phase": "ataque"})
	adv.call("advance_to", float(adv.state.elapsed) + 60.0)
	ck(snap_hash(adv) == snap_hash(split_a), "advance_to(t) avanza igual que tick")
	var other := new_rules(3, {"skip_intro": true})
	ck(int(other.state.rng_state) != int(new_rules(1817, {"skip_intro": true}).state.rng_state), "otra semilla da otro rng_state (RNG propio, no el global)")
	var capped := new_rules(1817, {"phase": "ataque"})
	var before := float(capped.state.elapsed)
	capped.call("tick", 600.0)
	ck(float(capped.state.elapsed) - before <= 60.0 + 0.26, "MAX_DT = 60: un tick de 600 s no avanza más de 60 s (avanzó %.2f)" % (float(capped.state.elapsed) - before))
	var rng_a := new_rules(1817, {"phase": "ataque"})
	rng_a.call("tick", 30.0)
	ck(int(rng_a.state.state_version) > 1, "state_version sube con cada paso")

func _test_world_from_seed() -> void:
	var r := new_rules()
	var first: Dictionary = _dict(r.call("world_from_seed", 1817))
	var dims_ok := true
	for dim in R.VARIANTS:
		if not first.has(dim) or not (R.VARIANTS[dim] as Array).has(first[dim]):
			dims_ok = false
	ck(dims_ok, "world_from_seed trae las seis dimensiones con valores legales: %s" % str(first))
	var traits: Dictionary = _dict(first.get("loot", {}))
	var traits_ok := true
	for k in R.WORLD_TRAITS:
		if not traits.has(k) or not (R.WORLD_TRAITS[k] as Array).has(traits[k]):
			traits_ok = false
	ck(traits_ok, "...y los rasgos del botín del mundo (corral, plata, pólvora) legales: %s" % str(traits))
	ck(same(first, _dict(r.call("world_from_seed", 1817))), "world_from_seed es determinista")
	if not Fx.round_ge(round_id, "r2b"):
		var all_same := true
		for sd in [3, 5, 7, 11, 13, 17, 19, 23, 29, 31]:
			if not same(first, _dict(r.call("world_from_seed", sd))):
				all_same = false
		ck(all_same, "en R1 el mundo es fijo: todas las semillas dan el mismo mundo")
	var s: Dictionary = r.state
	var from_state := true
	for dim in R.VARIANTS:
		if str(s.world[dim]) != str(first[dim]):
			from_state = false
	ck(from_state, "el mundo de la partida es el de world_from_seed")
	var forced := new_rules(1817, {"variant": {"torre_en": "templo", "guardia": "atenta"}})
	ck(str(forced.state.world.torre_en) == "templo" and str(forced.state.world.guardia) == "atenta", "opts.variant fuerza una dimensión legal")
	var bad_variant := new_rules(1817, {"variant": {"torre_en": "marte"}})
	ck(str(bad_variant.state.world.torre_en) != "marte", "opts.variant ignora un valor ilegal")
	var traited := new_rules(1817, {"loot_traits": {"polvora": "humeda", "corral": "desbandado"}})
	ck(str(traited.state.world.loot_traits.polvora) == "humeda" and str(traited.state.world.loot_traits.corral) == "desbandado", "opts.loot_traits fuerza rasgos legales del botín")

# ---------------------------------------------------------------------------------------------------------------------
# Fases y reloj

func _test_phases() -> void:
	var tm: Dictionary = cfg.time
	var starts: Dictionary = tm.phase_starts
	var r := new_rules()
	ck(str(r.state.phase) == "briefing", "new_game empieza en el briefing")
	var fresh := new_rules(1817, {"skip_intro": true})
	ck(str(fresh.state.phase) == "aproximacion" and float(fresh.state.elapsed) == 0.0, "opts.skip_intro arranca en la aproximación, en 0:00")
	for ph in ["aproximacion", "ataque", "extraccion"]:
		var g := new_rules(1817, {"phase": ph})
		ck(str(g.state.phase) == ph and str(g.state.status) == "playing", "opts.phase = %s arranca en esa fase, jugando" % ph)
		ck(absf(float(g.state.elapsed) - float(starts[ph])) < 1e-6, "...con el reloj en time.phase_starts.%s (%.0f s)" % [ph, float(starts[ph])])
		ck(bool(_dict(g.call("validate_snapshot", g.call("snapshot"))).ok), "...y el estado de esa fase pasa validate_snapshot")
	var atk := new_rules(1817, {"phase": "ataque"})
	ck(bool(atk.state.alarm.signaled) and float(atk.state.alarm.first_shot_at) >= 0.0, "la fase de ataque empieza con la señal dada")
	var ext := new_rules(1817, {"phase": "extraccion"})
	var all_taken := true
	for fid in V.OBJECTIVES:
		if str(ext.state.objectives[fid].state) != "tomado":
			all_taken = false
	ck(all_taken, "la fase de extracción empieza con los tres frentes tomados")
	var inv := new_rules(1817, {"phase": "epilogo"})
	ck(str(inv.state.phase) != "epilogo", "opts.phase no puede abrir el epílogo")
	if pol != null:
		var seq := new_rules(1817, {"skip_intro": true})
		seq.call("tick", 1.0)
		ck(str(seq.state.phase) == "aproximacion", "el reloj en marcha deja la fase de aproximación")
		play_by_hand(seq, 840.0)
		ck(str(seq.state.phase) == "epilogo" and str(seq.state.status) == "victory", "la partida del experto pasa por ataque y extracción y termina en el epílogo con victoria")
		var walk := follow_next_step(new_rules(1817, {"skip_intro": true}), 840.0)
		ck(walk.phases == ["aproximacion", "ataque", "extraccion", "epilogo"], "siguiendo el siguiente paso las fases se suceden en orden: %s" % str(walk.phases))
	var dawn := new_rules(1817, {"skip_intro": true})
	run_to(dawn, 900.0)
	ck(str(dawn.state.status) == "defeat" and str(dawn.state.reason) == "amanecio", "sin señal, la partida termina por amanecio")
	ck(absf(float(dawn.state.elapsed) - float(tm.dawn_discovery_s)) <= 0.5, "...a los %.0f s (time.dawn_discovery_s): terminó a los %.2f" % [float(tm.dawn_discovery_s), float(dawn.state.elapsed)])
	ck(str(dawn.state.phase) == "epilogo", "al terminar la fase es epilogo")
	var elapsed_end := float(dawn.state.elapsed)
	dawn.call("tick", 30.0)
	ck(float(dawn.state.elapsed) == elapsed_end, "terminada la partida el reloj no avanza")

func _test_environment_curve() -> void:
	var r := new_rules(1817, {"skip_intro": true})
	for pair in VP01_SAMPLES:
		r.state.elapsed = float(pair[0])
		var env: Dictionary = _dict(r.call("environment"))
		var tod := float(env.get("time_of_day", -1.0))
		ck(absf(tod - float(pair[1])) <= VP01_TOLERANCE, "VP-01: time_of_day a los %.0f s vale %.3f y el pedido es %.2f ± %.2f" % [float(pair[0]), tod, float(pair[1]), VP01_TOLERANCE])
	var monotone := true
	var smooth := true
	var in_range := true
	var prev := -1.0
	var phases: Array = []
	var env_ok := true
	var t := 0.0
	while t <= 900.0:
		r.state.elapsed = t
		var e: Dictionary = _dict(r.call("environment"))
		if not missing_keys(e, ["phase", "time_of_day", "rain", "visibility_m", "mud", "firearm_reliability"]).is_empty():
			env_ok = false
		var v := float(e.get("time_of_day", -1.0))
		if v < 0.0 or v > 1.0 or float(e.rain) < 0.0 or float(e.rain) > 1.0 or float(e.mud) < 0.0 or float(e.mud) > 1.0 or float(e.firearm_reliability) < 0.0 or float(e.firearm_reliability) > 1.0 or float(e.visibility_m) <= 0.0:
			in_range = false
		if prev >= 0.0:
			if v < prev - 1e-9:
				monotone = false
			if v - prev > 0.02:
				smooth = false
		prev = v
		if phases.is_empty() or phases[phases.size() - 1] != str(e.phase):
			phases.append(str(e.phase))
		t += 1.0
	ck(env_ok, "environment() trae phase, time_of_day, rain, visibility_m, mud y firearm_reliability en todo el reloj")
	ck(in_range, "time_of_day, lluvia, barro y fiabilidad quedan en 0..1 y la visibilidad es positiva en todo el reloj")
	ck(monotone, "VP-01: time_of_day nunca baja (creciente entre las muestras)")
	ck(smooth, "VP-01: time_of_day es continuo (no salta más de 0,02 por segundo)")
	ck(phases == R.ENV_PHASES, "la fase del ambiente pasa por noche, alba y día, en ese orden: %s" % str(phases))
	var tm: Dictionary = cfg.time
	r.state.elapsed = float(tm.alba_start_s) - 1.0
	ck(str(r.call("environment").phase) == "noche", "antes de alba_start_s (%.0f s) es de noche" % float(tm.alba_start_s))
	r.state.elapsed = float(tm.alba_start_s) + 1.0
	ck(str(r.call("environment").phase) == "alba", "después de alba_start_s es el alba")
	r.state.elapsed = float(tm.alba_full_s) + 1.0
	ck(str(r.call("environment").phase) == "dia", "después de alba_full_s es de día")
	r.state.elapsed = float(tm.day_full_s)
	ck(absf(float(r.call("environment").time_of_day) - 1.0) <= VP01_TOLERANCE, "en day_full_s (%.0f s) time_of_day llega a 1" % float(tm.day_full_s))
	# el reloj llega a 420 s con la partida en juego si ya se dio la señal; una partida pasiva termina a los 390 s y su reloj se detiene ahí
	var live := new_rules(1817, {"phase": "ataque"})
	live.call("advance_to", 420.0)
	ck(str(live.state.status) == "playing" and absf(float(live.state.elapsed) - 420.0) < 1e-6, "una partida con la señal dada llega a 420 s jugando")
	if str(live.state.status) == "playing":
		ck(absf(float(live.call("environment").time_of_day) - 1.0) <= VP01_TOLERANCE, "VP-01 en vivo: a los 420 s de una partida en juego time_of_day vale %.3f" % float(live.call("environment").time_of_day))
	var passive := new_rules(1817, {"skip_intro": true})
	passive.call("advance_to", 420.0)
	ck(str(passive.state.status) == "defeat" and float(passive.state.elapsed) < 420.0, "una partida pasiva termina antes de los 420 s y su reloj se detiene (por eso VP-01 se mide con el reloj fijado o con la señal dada)")
	var pre: RefCounted = rules_script.new()
	ck(absf(float(pre.call("environment").time_of_day)) <= VP01_TOLERANCE, "antes de new_game el ambiente es el del instante 0 (noche)")

# ---------------------------------------------------------------------------------------------------------------------
# hud_state, render_state y campaign_report

func _states_for_shapes() -> Array:
	var out: Array = []
	out.append(["briefing", new_rules(1817)])
	out.append(["aproximacion", new_rules(1817, {"skip_intro": true})])
	var mid := new_rules(1817, {"skip_intro": true})
	run_to(mid, 100.0)
	out.append(["aproximacion a los 100 s", mid])
	var atk := new_rules(1817, {"phase": "ataque"})
	run_to(atk, float(atk.state.elapsed) + 40.0)
	out.append(["ataque", atk])
	out.append(["extraccion", new_rules(1817, {"phase": "extraccion"})])
	var lost := new_rules(1817, {"skip_intro": true})
	run_to(lost, 900.0)
	out.append(["derrota por el alba", lost])
	if pol != null:
		var won := new_rules(1817, {"skip_intro": true})
		play_by_hand(won, 840.0)
		out.append(["victoria", won])
	return out

func _test_hud_state_all_phases() -> void:
	for pair in _states_for_shapes():
		var label: String = pair[0]
		var r: RefCounted = pair[1]
		var hud: Dictionary = _dict(r.call("hud_state"))
		shape("hud_state", hud, label)
		ck(R.PHASES.has(str(_dict(hud.get("fase", {})).get("id", ""))), "hud.fase.id es una fase del vocabulario en %s" % label)
		var fe: Array = []
		var fr_ok := true
		for f in hud.get("frentes", []):
			fe.append(f.id)
			if not R.FRONT_STATES.has(str(f.estado)) or not V.TAGS.has(str(f.tag)) or float(f.toma_pct) < 0.0 or float(f.toma_pct) > 100.0 or float(f.alerta) < 0.0 or float(f.alerta) > 1.0:
				fr_ok = false
		ck(fe == V.OBJECTIVES and fr_ok, "hud.frentes: los tres frentes, con estado, etiqueta y rangos válidos en %s" % label)
		var ge: Array = []
		var gr_ok := true
		for g in hud.get("grupos", []):
			ge.append(g.id)
			if not R.NOISE_STATES.has(str(g.ruido)) or not V.TAGS.has(str(g.tag)) or float(g.fuerza_pct) < 0.0 or float(g.fuerza_pct) > 100.0 or str(g.etapa_txt) == "":
				gr_ok = false
		ck(ge == V.GROUPS and gr_ok, "hud.grupos: las cinco agrupaciones, con ruido en palabras y etiqueta en %s" % label)
		var al_ok := true
		for a in hud.get("alertas", []):
			if not R.ALERT_LEVELS.has(str(a.nivel)) or str(a.corto) == "":
				al_ok = false
		ck(al_ok, "hud.alertas: nivel del vocabulario y texto corto en %s" % label)
		var criticas := 0
		for a in hud.get("alertas", []):
			criticas += 1 if str(a.nivel) == "critica" else 0
		ck(criticas <= 1, "hay a lo sumo una alerta crítica a la vez en %s (%d)" % [label, criticas])
		var nxt: Dictionary = _dict(hud.get("siguiente", {}))
		var all_actions: Array = []
		for k in R.ACTIONS:
			all_actions.append_array(R.ACTIONS[k])
		ck([0, 1, 2].has(int(nxt.get("urgencia", -1))) and V.GROUPS.has(str(nxt.get("actor", ""))) and all_actions.has(str(nxt.get("action", ""))) and str(nxt.get("texto", "")) != "", "hud.siguiente es uno solo, con actor y acción del vocabulario y un texto en %s" % label)
		ck(R.REINFORCEMENT_STATES.has(str(_dict(hud.get("refuerzo", {})).get("estado", ""))), "hud.refuerzo.estado es del vocabulario en %s" % label)
		var gp: Dictionary = _dict(hud.get("golpe", {}))
		ck(absf(float(gp.get("entregado", 0.0)) + float(gp.get("destruido", 0.0)) + float(gp.get("oculto", 0.0)) + float(gp.get("pendiente", 0.0)) - float(gp.get("total", -1.0))) < 1e-4 and absf(float(gp.get("total", 0.0)) - 100.0) < TOLERANCE, "hud.golpe: entregado, destruido, oculto y pendiente suman 100 en %s" % label)
		var sg: Dictionary = _dict(hud.get("senal", {}))
		ck(float(sg.get("oscuridad_pct", -1.0)) >= 0.0 and float(sg.get("oscuridad_pct", 101.0)) <= 100.0 and float(sg.get("desvelo_pct", -1.0)) >= 0.0 and float(sg.get("desvelo_pct", 101.0)) <= 100.0, "hud.senal: oscuridad y desvelo en 0..100 en %s" % label)
		ck(JSON.stringify(hud) != "" and str(_dict(hud.get("mundo", {})).get("linea", "")) != "" and str(hud.get("objetivo", "")) != "", "hud serializable, con objetivo de una línea y línea del mundo en %s" % label)
	var empty: RefCounted = rules_script.new()
	ck(empty.call("hud_state") is Dictionary and empty.call("render_state") is Dictionary and empty.call("campaign_report") is Dictionary, "las tres consultas devuelven un Dictionary aun sin partida")

func _test_render_state() -> void:
	for pair in _states_for_shapes():
		var label: String = pair[0]
		var r: RefCounted = pair[1]
		var rs: Dictionary = _dict(r.call("render_state"))
		shape("render_state", rs, label)
		var vocab_ok := R.ENV_PHASES.has(str(_dict(rs.get("env", {})).get("phase", ""))) and R.PHASES.has(str(rs.get("phase", "")))
		for u in rs.get("units", []):
			if not R.STAGES.has(str(u.stage)) or not V.GROUPS.has(str(u.id)) or not R.NOISE_STATES.has(str(u.noise_state)) or int(u.men_visible) < 2 or int(u.men_visible) > 14:
				vocab_ok = false
		for o in rs.get("objectives", []):
			if not R.FRONT_STATES.has(str(o.state)) or not V.OBJECTIVES.has(str(o.id)):
				vocab_ok = false
		for e in rs.get("enemies", []):
			if not R.ENEMY_KINDS.has(str(e.kind)):
				vocab_ok = false
		for it in rs.get("loot", []):
			if not R.LOOT_KINDS.has(str(it.kind)) or not R.LOOT_STATES.has(str(it.state)):
				vocab_ok = false
		for lg in rs.get("lights", []):
			if not R.LIGHT_KINDS.has(str(lg.kind)):
				vocab_ok = false
		ck(vocab_ok, "render_state usa solo ids del vocabulario (fases, etapas, ruido, frentes, enemigos, botín y luces) en %s" % label)
		ck((rs.get("units", []) as Array).size() == 5 and (rs.get("objectives", []) as Array).size() == 3, "render_state trae las 5 unidades y los 3 frentes en %s" % label)
		ck(JSON.stringify(rs) != "" and typeof(rs.get("version", null)) == TYPE_INT, "render_state es serializable y su versión es un entero en %s" % label)
		var lights: Array = rs.get("lights", [])
		var objs_lit := {}
		for lg in lights:
			if str(lg.get("objective", "")) != "":
				objs_lit[str(lg.objective)] = true
		ck(lights.size() >= 3 and objs_lit.size() == 3, "render_state trae las 3 luces de objetivo (la guardia se delata de lejos) en %s" % label)
	# la versión sube con cada cambio visible (VP-02)
	var r2 := new_rules(1817, {"skip_intro": true})
	var v0 := int(_dict(r2.call("render_state")).version)
	r2.call("tick", 1.0)
	order(r2, "portal", "position")
	var v1 := int(_dict(r2.call("render_state")).version)
	ck(v1 > v0, "VP-02: render_state().version sube al dar una orden (%d → %d)" % [v0, v1])
	var guard := 0
	while not bool(_dict(r2.call("signal_info")).can_give) and guard < 400:
		r2.call("tick", 1.0)
		guard += 1
	var v2 := int(_dict(r2.call("render_state")).version)
	r2.call("give_signal")
	var v3 := int(_dict(r2.call("render_state")).version)
	ck(v3 > v2 and str(_dict(r2.call("render_state")).phase) == "ataque", "VP-02: la versión sube al dar la señal y la fase pasa a ataque (%d → %d)" % [v2, v3])
	var v4 := v3
	var bumps := 0
	for i in range(240):
		r2.call("tick", 1.0)
		var vn := int(_dict(r2.call("render_state")).version)
		if vn != v4:
			bumps += 1
			v4 = vn
	ck(bumps >= 3 and v4 >= v3, "VP-02: durante el ataque la versión sigue subiendo con los cambios visibles (%d subidas) y nunca baja" % bumps)

func _test_render_state_blindness() -> void:
	var r := new_rules(1817, {"skip_intro": true})
	var rs: Dictionary = _dict(r.call("render_state"))
	var all_hidden := true
	for o in rs.objectives:
		if float(o.garrison_pct) != -1.0:
			all_hidden = false
	ck(all_hidden, "garrison_pct vale -1 en los tres frentes mientras no se los reconoce")
	var guards := 0
	for e in rs.enemies:
		if str(e.kind) in ["centinela", "guardia", "artillero", "fusilero"]:
			guards += 1
	ck(guards == 0, "sin reconocer no se dibuja ningún centinela ni guardia (%d)" % guards)
	var hud: Dictionary = _dict(r.call("hud_state"))
	var unknown_ok := true
	for f in hud.frentes:
		if bool(f.guardia.conocida):
			unknown_ok = false
		if int(f.guardia.min) > int(f.guardia.max):
			unknown_ok = false
	ck(unknown_ok, "hud.frentes[].guardia.conocida es falso y trae un rango (min ≤ max) antes de reconocer")
	var plan: Dictionary = _dict(r.call("plan_recon", "reconocedores", [hito("bateria")]))
	ck(bool(plan.get("ok", false)) and plan.has("risk_pct") and plan.has("time_s") and plan.has("reveals"), "plan_recon decide el riesgo antes de ordenar: %s" % str(plan).substr(0, 160))
	var res := order(r, "reconocedores", "recon", hito("bateria"))
	ck(bool(res.get("ok", false)), "recon sobre la batería se acepta: %s" % str(res.get("reason", "")))
	var revealed := run_until(r, func(): return float(r.state.objectives.bateria.reconocido) >= 1.0, 120.0)
	ck(revealed, "los reconocedores revelan la batería (a los %.0f s)" % float(r.state.elapsed))
	ck(float(r.state.elapsed) <= 60.0, "la primera revelación llega antes de los 60 s de juego (contrato del diseño: antes de los 40 s; llegó a los %.0f s)" % float(r.state.elapsed))
	var rs2: Dictionary = _dict(r.call("render_state"))
	var known := 0
	var hidden := 0
	for o in rs2.objectives:
		if float(o.garrison_pct) >= 0.0:
			known += 1
			ck(str(o.id) == "bateria", "solo el frente reconocido muestra su guardia (%s)" % str(o.id))
		else:
			hidden += 1
	ck(known == 1 and hidden == 2, "tras reconocer uno quedan dos sin conocer (%d conocidos)" % known)
	var hud2: Dictionary = _dict(r.call("hud_state"))
	var bat: Dictionary = {}
	for f in hud2.frentes:
		if str(f.id) == "bateria":
			bat = f
	ck(bool(bat.get("guardia", {}).get("conocida", false)), "el HUD marca la guardia de la batería como conocida")
	var revealed_events := 0
	for e in r.state.log:
		if str(e.kind) == "recon":
			revealed_events += 1
	ck(revealed_events >= 1, "la revelación deja un evento de tipo recon en el registro")

func _test_render_state_tower() -> void:
	for variant in ["casa_cura", "templo"]:
		var r := new_rules(1817, {"phase": "ataque", "variant": {"torre_en": variant}})
		ck(str(r.state.world.torre_en) == variant, "la partida usa torre_en = %s" % variant)
		var seen := run_until(r, func(): return not (_dict(r.call("render_state")).get("tower", {}) as Dictionary).is_empty(), 90.0)
		ck(seen, "VP-02: con torre_en = %s la torre aparece en render_state a los %.0f s" % [variant, float(r.state.elapsed)])
		var tw: Dictionary = _dict(_dict(r.call("render_state")).get("tower", {}))
		var lm := hito("torre_casa_cura" if variant == "casa_cura" else "torre_templo")
		var other := hito("torre_templo" if variant == "casa_cura" else "torre_casa_cura")
		if not tw.is_empty():
			var p := Vector2(float(tw.x), float(tw.z))
			ck(p.distance_to(lm) < 40.0, "VP-02: la torre de %s cae a %.1f m de su hito (menos de 40 m)" % [variant, p.distance_to(lm)])
			ck(p.distance_to(lm) < p.distance_to(other), "VP-02: la torre de %s queda más cerca de su hito que del de la otra variante" % variant)
			ck(missing_keys(tw, ["x", "z", "next_volley_in_s", "period_s", "dead_angle_m", "firing"]).is_empty(), "la torre trae anillo de recarga, ángulo muerto y estado de fuego")
			var tower_enemy := false
			for e in _dict(r.call("render_state")).enemies:
				if str(e.kind) == "torre":
					tower_enemy = true
			ck(tower_enemy, "la torre figura también entre los enemigos visibles")
		else:
			ck(false, "VP-02: la torre no apareció en render_state con torre_en = %s" % variant)

func _test_campaign_report_shape() -> void:
	for pair in _states_for_shapes():
		var label: String = pair[0]
		var r: RefCounted = pair[1]
		var rep: Dictionary = _dict(r.call("campaign_report"))
		shape("campaign_report", rep, label)
		ck(R.STATUS.has(str(rep.get("status", ""))) and R.MEDALS.has(str(rep.get("medal", "x"))) and (str(rep.get("cause_id", "")) == "" or R.CAUSES.has(str(rep.get("cause_id", "")))), "campaign_report: estado, medalla y causa del vocabulario en %s" % label)
		ck(String(rep.get("cause", "")).length() <= 140, "campaign_report: la causa mide %d caracteres (máximo 140) en %s" % [String(rep.get("cause", "")).length(), label])
		ck(JSON.stringify(rep) != "" and (rep.get("objectives", []) as Array).size() == 3 and (rep.get("groups", []) as Array).size() == 5, "campaign_report serializable, con 3 frentes y 5 agrupaciones en %s" % label)
		var gp: Dictionary = _dict(rep.get("golpe", {}))
		var sum := float(gp.get("entregado", 0.0)) + float(gp.get("destruido", 0.0)) + float(gp.get("oculto", 0.0)) + float(gp.get("perdido", 0.0))
		ck(sum <= 100.0 + 1e-4 and absf(float(gp.get("total", 0.0)) - 100.0) < TOLERANCE, "campaign_report.golpe: entregado + destruido + oculto + perdido ≤ 100 en %s" % label)
	var ended := new_rules(1817, {"skip_intro": true})
	run_to(ended, 900.0)
	var rep2: Dictionary = _dict(ended.call("campaign_report"))
	ck(str(rep2.status) == "defeat" and str(rep2.cause_id) == "amanecio" and str(rep2.advice) != "" and str(rep2.outcome_title) != "", "el parte de una derrota trae causa, consejo y título")
	ck(str(rep2.cause).find(":") >= 0 and str(rep2.cause).find("6:30") >= 0, "la causa de la derrota nombra el momento (m:ss): «%s»" % str(rep2.cause))
	var epi: Array = ended.call("epilogue")
	ck(not epi.is_empty() and missing_keys(epi[0], ["fecha", "texto", "tag"]).is_empty(), "epilogue() trae líneas con fecha, texto y etiqueta")
	var tags_ok := true
	for line in epi:
		if not V.TAGS.has(str(line.tag)) or String(line.texto).strip_edges() == "":
			tags_ok = false
	ck(tags_ok, "todas las líneas del epílogo tienen etiqueta del vocabulario y texto")
	var cannons: Array = []
	for it in ended.state.loot.items:
		if str(it.kind) == "canones":
			cannons.append(it)
	if cannons.size() >= 3:
		cannons[0].state = "destruido"
		cannons[1].state = "entregado"
		var tu := ""
		for line in ended.call("epilogue"):
			if str(line.fecha).begins_with("9 al 16"):
				tu = str(line.texto)
		ck(tu.find("1 llevada,") >= 0 and tu.find("1 clavada,") >= 0 and tu.find("llevadas") < 0 and tu.find("clavadas") < 0 and tu.find("%d abandonadas" % (cannons.size() - 2)) >= 0,
			"el epílogo cuenta las piezas de la partida con singular y plural: «%s»" % tu.right(75))

func _test_plan_route_shape() -> void:
	var r := new_rules(1817, {"skip_intro": true})
	var before := snap_hash(r)
	var plan: Dictionary = _dict(r.call("plan_route", "portal", Vector2(400, 400), {"pace": "run", "waypoints": [Vector2(200, 500)]}))
	shape("plan_route", plan, "plan_route con una parada")
	ck(bool(plan.get("ok", false)) and (plan.path as Array).size() >= 2 and float(plan.length_m) > 0.0 and float(plan.time_s) > 0.0, "plan_route con parada: ruta, largo y tiempo positivos")
	ck(R.ROUTE_RISKS.has(str(plan.get("risk", ""))) and float(plan.seen_risk) >= 0.0 and float(plan.seen_risk) <= 1.0, "plan_route: riesgo en palabras (%s) y seen_risk en 0..1" % str(plan.get("risk", "")))
	var last: Dictionary = (plan.path as Array)[(plan.path as Array).size() - 1]
	ck(Vector2(float(last.x), float(last.z)).distance_to(Vector2(400, 400)) < 1.0, "la ruta termina en el destino")
	var stops := 0
	for p in plan.path:
		if Vector2(float(p.x), float(p.z)).distance_to(Vector2(200, 500)) < 1.0:
			stops += 1
	ck(stops >= 1, "la ruta pasa por la parada pedida")
	ck(snap_hash(r) == before, "plan_route no tiene efectos (el estado no cambia)")
	var quiet: Dictionary = _dict(r.call("plan_route", "portal", Vector2(400, 400), {"pace": "sneak"}))
	var fast: Dictionary = _dict(r.call("plan_route", "portal", Vector2(400, 400), {"pace": "run"}))
	ck(float(quiet.time_s) > float(fast.time_s), "ir en silencio tarda más que correr (%.0f s contra %.0f s)" % [float(quiet.time_s), float(fast.time_s)])
	ck(float(quiet.noise) < float(fast.noise), "ir en silencio hace menos ruido que correr")
	var bad: Dictionary = _dict(r.call("plan_route", "nadie", Vector2(400, 400)))
	ck(not bool(bad.get("ok", true)) and str(bad.get("reason", "")) != "", "plan_route de un actor inexistente dice por qué no: «%s»" % str(bad.get("reason", "")))
	var pr: Dictionary = _dict(r.call("plan_recon", "reconocedores", [hito("bateria")]))
	ck(bool(pr.get("ok", false)) and float(pr.risk_pct) >= 0.0 and float(pr.risk_pct) <= 100.0 and (pr.reveals as Array).size() >= 1, "plan_recon: riesgo en %, tiempo y qué revela")
	ck(snap_hash(r) == before, "plan_recon tampoco tiene efectos")
	var atlas: Array = r.call("route_atlas")
	ck(not atlas.is_empty() and missing_keys(atlas[0], ["front", "approach", "length_m", "time_s", "seen_risk", "unknown_m", "cost_est"]).is_empty(), "route_atlas devuelve aproximaciones con largo, tiempo y riesgo")
	var by_front := {}
	for a in atlas:
		by_front[str(a.front)] = int(by_front.get(str(a.front), 0)) + 1
	ck(by_front.size() == 3, "route_atlas cubre los tres frentes (%s)" % str(by_front))
	ck(snap_hash(r) == before, "route_atlas es de solo lectura")

# ---------------------------------------------------------------------------------------------------------------------
# Órdenes

func _test_actions_r1() -> void:
	var r := new_rules(1817, {"skip_intro": true})
	var kinds_found := {}
	for kind in R.ACTOR_KINDS:
		var acts: Array = r.call("list_actions", kind)
		ck(acts is Array, "list_actions(%s) devuelve un arreglo" % kind)
		for a in acts:
			kinds_found[str(a)] = true
			ck(not _dict(r.call("action_info", str(a))).is_empty(), "action_info(%s) existe para la acción que ofrece %s" % [str(a), kind])
	for a in ["move", "position", "give_signal", "attack", "support", "recon", "load", "destroy", "leave"]:
		ck(kinds_found.has(a), "la acción de R1 «%s» se ofrece a algún tipo de actor" % a)
		var info: Dictionary = _dict(r.call("action_info", a))
		ck(str(info.get("name", "")) != "" and V.TAGS.has(str(info.get("tag", ""))) and str(info.get("id", "")) == a, "action_info(%s): nombre, etiqueta e id" % a)
	ck(_dict(r.call("action_info", "nada")).is_empty(), "action_info de una acción inexistente es {}")
	var av: Dictionary = _dict(r.call("action_availability", "portal", "position"))
	ck(missing_keys(av, ["ok", "reason", "cost_text", "tag"]).is_empty() and bool(av.ok) and str(av.cost_text) != "" and V.TAGS.has(str(av.tag)), "action_availability trae ok, motivo, costo en texto y etiqueta: %s" % str(av))
	# move
	var rm := order(r, "rodriguez", "move", Vector2(300, 350))
	ck(bool(rm.ok) and not (rm.path as Array).is_empty() and rm.has("plan"), "move se acepta y devuelve ruta y plan")
	ck(str(unit_of(r, "rodriguez").stage) == "moving" and not (unit_of(r, "rodriguez").path as Array).is_empty(), "move deja a la agrupación en marcha, con camino")
	var fat0 := float(unit_of(r, "rodriguez").fatigue)
	run_to(r, 30.0)
	ck(float(unit_of(r, "rodriguez").fatigue) > fat0, "marchar cuesta fatiga")
	ck(float(r.state.stats.pacing.first_decision_s) >= 0.0, "la primera orden queda anotada en stats.pacing.first_decision_s")
	# cancel
	var rc := order(r, "rodriguez", "cancel")
	ck(bool(rc.ok) and str(unit_of(r, "rodriguez").stage) == "idle" and (unit_of(r, "rodriguez").path as Array).is_empty(), "cancel deja a la agrupación quieta y sin camino")
	# position y hold
	var rp := order(r, "portal", "position")
	ck(bool(rp.ok), "position se acepta: %s" % str(rp.get("reason", "")))
	var post_c: Dictionary = level.access.attack_posts.cuartel[0]
	var arrived := run_until(r, func(): return str(unit_of(r, "portal").stage) == "waiting_signal", 300.0)
	ck(arrived and Vector2(float(unit_of(r, "portal").x), float(unit_of(r, "portal").z)).distance_to(Vector2(float(post_c.x), float(post_c.z))) < 4.0, "position lleva a la partida a su puesto de ataque y queda esperando la señal")
	var rh := order(r, "rodriguez", "hold")
	ck(bool(rh.ok) and str(unit_of(r, "rodriguez").stage) == "holding", "hold deja a la agrupación sosteniendo")
	# give_signal
	var sig_before := int(r.state.state_version)
	var rs: Dictionary = _dict(r.call("give_signal"))
	ck(bool(rs.ok) and bool(r.state.alarm.signaled) and str(r.state.phase) == "ataque", "give_signal abre el ataque")
	ck(absf(float(r.state.alarm.first_shot_at) - float(r.state.elapsed)) < 1e-6 and float(r.state.alarm.signal_at) == float(r.state.alarm.first_shot_at), "la señal fija first_shot_at y signal_at en el reloj actual")
	ck(int(r.state.state_version) >= sig_before, "la señal no retrocede la versión")
	var surprise := float(r.state.objectives.bateria.surprise_until) - float(r.state.elapsed)
	ck(absf(surprise - float(cfg.time.surprise_s)) < 1e-6, "la señal abre la ventana de sorpresa de %.0f s" % float(cfg.time.surprise_s))
	ck(float(r.state.alarm.reinforcement_at) > float(r.state.elapsed), "la señal arma el reloj del refuerzo")
	ck(str(unit_of(r, "portal").stage) == "attacking" and str(unit_of(r, "portal").order.get("front", "")) == "cuartel", "quien esperaba en su puesto ataca su frente al dar la señal")
	var again: Dictionary = _dict(r.call("give_signal"))
	ck(not bool(again.ok) and str(again.reason) != "", "una segunda señal se rechaza con motivo")
	# attack con costo de fatiga y señal automática
	var ra := new_rules(1817, {"skip_intro": true})
	order(ra, "rodriguez", "position")
	run_until(ra, func(): return str(unit_of(ra, "rodriguez").stage) == "waiting_signal", 300.0)
	var fat_a := float(unit_of(ra, "rodriguez").fatigue)
	var rat := order(ra, "rodriguez", "attack")
	ck(bool(rat.ok) and str(unit_of(ra, "rodriguez").stage) == "attacking", "attack desde el puesto se acepta y la agrupación ataca")
	ck(absf(float(unit_of(ra, "rodriguez").fatigue) - fat_a - float(cfg.combat.fatigue_per_attack)) < 0.5, "attack cuesta %.0f de fatiga (combat.fatigue_per_attack)" % float(cfg.combat.fatigue_per_attack))
	ck(bool(ra.state.alarm.signaled), "atacar sin señal previa dispara la señal (las primeras descargas rompen el silencio)")
	run_until(ra, func(): return str(ra.state.objectives.bateria.state) == "tomado", 300.0)
	ck(str(ra.state.objectives.bateria.state) == "tomado" and float(ra.state.objectives.bateria.toma) >= 100.0, "el ataque de Rodríguez toma la batería (a los %.0f s)" % float(ra.state.elapsed))
	ck(int(ra.state.objectives.bateria.custody) > 0 and int(unit_of(ra, "rodriguez").custody) > 0, "quien toma un frente deja custodia")
	# support
	var rsu := new_rules(1817, {"skip_intro": true})
	var sup := order(rsu, "arias", "support", Vector2.ZERO, {"front": "cuartel"})
	ck(bool(sup.ok), "support se acepta con el frente elegido: %s" % str(sup.get("reason", "")))
	run_until(rsu, func(): return str(unit_of(rsu, "arias").stage) == "attacking", 400.0)
	ck(str(unit_of(rsu, "arias").stage) == "attacking" and (rsu.state.objectives.cuartel.supporters as Array).has("arias"), "support lleva a Arias a atacar el cuartel y la deja como apoyo")
	ck(int(rsu.state.stats.support_events) == 1, "stats.support_events cuenta el apoyo")
	# recon y plan de reconocimiento ya probados; leave/load/destroy en la extracción
	var rx := new_rules(1817, {"phase": "extraccion"})
	var item := {}
	for it in rx.state.loot.items:
		if str(it.kind) == "viveres":
			item = it
			break
	var near_pos := Vector2(float(item.x), float(item.z))
	var load_kg0 := float(rx.state.loot.load_kg)
	var rl := order(rx, "arreo", "load", near_pos, {"item": str(item.id)})
	if not bool(rl.get("ok", false)):
		ck(str(rl.get("reason", "")).strip_edges() != "" and float(rx.state.loot.load_kg) == load_kg0, "load lejos de la carga se rechaza con motivo y sin cargar nada: «%s»" % str(rl.get("reason", "")))
		order(rx, "arreo", "move", near_pos)
		run_until(rx, func(): return str(unit_of(rx, "arreo").stage) == "idle", 200.0)
		rl = order(rx, "arreo", "load", near_pos, {"item": str(item.id)})
	ck(bool(rl.ok), "load a la distancia de carga se acepta: %s" % str(rl.get("reason", "")))
	if bool(rl.ok):
		ck(str(unit_of(rx, "arreo").stage) == "loading", "cargar lleva tiempo: la agrupación queda cargando")
		var need := float(item.qty) * float(item.unit_kg) / (float(cfg.transport.load_kg_per_s_per_team) * float(cfg.transport.teams_max))
		run_until(rx, func(): return str(unit_of(rx, "arreo").stage) != "loading", 200.0)
		ck(absf(float(rx.state.elapsed) - float(cfg.time.phase_starts.extraccion) - need) < 90.0, "la carga tarda lo que dice transport (≈ %.1f s de carga)" % need)
		ck(absf(float(rx.state.loot.load_kg) - load_kg0 - float(item.qty) * float(item.unit_kg)) < 1e-6, "load suma el peso del lote a la carga (+%.0f kg)" % (float(item.qty) * float(item.unit_kg)))
	var victim := {}
	for it in rx.state.loot.items:
		if str(it.state) == "en_sitio" and str(it.front) == str(item.front):
			victim = it
			break
	if not victim.is_empty():
		var vpos := Vector2(float(victim.x), float(victim.z))
		var destroyed0 := float(rx.state.loot.destroyed_value)
		var rd := order(rx, "arreo", "destroy", vpos, {"item": str(victim.id)})
		ck(bool(rd.ok), "destroy de un lote a mano se acepta: %s" % str(rd.get("reason", "")))
		if bool(rd.ok):
			run_until(rx, func(): return str(unit_of(rx, "arreo").stage) != "loading", 200.0)
			var gain := float(rx.state.loot.destroyed_value) - destroyed0
			ck(absf(gain - float(victim.qty) * float(victim.unit_value) * float(cfg.loot.treatments.destruir)) < 1e-6, "destruir vale ×%.2f del puntaje del lote (ganó %.3f)" % [float(cfg.loot.treatments.destruir), gain])
	var rleave := order(rx, "arreo", "leave")
	ck(bool(rleave.ok) and str(unit_of(rx, "arreo").stage) == "moving", "leave pone al arreo en marcha hacia el vado y la salida del este")
	run_until(rx, func(): return str(unit_of(rx, "arreo").stage) == "exited" or str(rx.state.status) != "playing", 400.0)
	ck(str(unit_of(rx, "arreo").stage) == "exited" or str(rx.state.status) != "playing", "el arreo sale por el este o la partida termina")
	var undo := new_rules(1817, {"skip_intro": true})
	order(undo, "portal", "move", Vector2(300, 300))
	var ru: Dictionary = _dict(undo.call("undo_last"))
	ck(bool(ru.ok) and str(unit_of(undo, "portal").stage) == "idle", "undo_last deshace la última orden")
	ck(not bool(_dict(undo.call("undo_last")).ok), "undo_last sin órdenes se rechaza con motivo")
	var avail_ok := true
	for case in [["portal", "position", Vector2.ZERO], ["rodriguez", "attack", Vector2.ZERO], ["arreo", "load", Vector2.ZERO], ["portal", "recon", Vector2(300, 300)], ["nadie", "move", Vector2(1, 1)]]:
		var fresh := new_rules(1817, {"skip_intro": true})
		var h0 := snap_hash(fresh)
		var a2: Dictionary = _dict(fresh.call("action_availability", case[0], case[1], case[2]))
		var same_hash := snap_hash(fresh) == h0
		var o2 := order(fresh, case[0], case[1], case[2])
		if not same_hash or bool(a2.ok) != bool(o2.ok) or (not bool(a2.ok) and str(a2.reason) != str(o2.reason)):
			avail_ok = false
	ck(avail_ok, "action_availability no tiene efectos y coincide con lo que después hace issue_order (ok y motivo)")

func _test_order_errors() -> void:
	var r := new_rules(1817, {"skip_intro": true})
	var cases := [
		["actor inexistente", "nadie", "move", Vector2(300, 300), {}],
		["acción inexistente", "rodriguez", "volar", Vector2(300, 300), {}],
		["mover sin destino", "rodriguez", "move", Vector2.ZERO, {}],
		["destino fuera del mapa", "portal", "move", Vector2(2000, 300), {}],
		["atacar lejos del frente", "rodriguez", "attack", Vector2.ZERO, {}],
		["reconocer con una partida", "portal", "recon", Vector2(300, 300), {}],
		["cargar sin frente tomado", "arreo", "load", Vector2.ZERO, {}],
		["salir sin tomar los tres frentes", "arreo", "leave", Vector2.ZERO, {}],
		["acción de una ronda posterior", "rodriguez", "secure_horses", Vector2.ZERO, {}],
		["galope sin caballos", "portal", "move", Vector2(300, 300), {"pace": "gallop"}],
		["demasiadas paradas", "portal", "move", Vector2(300, 300), {"waypoints": [Vector2(1, 1), Vector2(2, 2), Vector2(3, 3), Vector2(4, 4), Vector2(5, 5)]}],
		["señal sin nadie en su puesto", "", "give_signal", Vector2.ZERO, {}]]
	var snake := RegEx.new()
	snake.compile("[a-z]+_[a-z]+")
	for c in cases:
		var h0 := snap_hash(r)
		var res := order(r, c[1], c[2], c[3], c[4])
		var reason := str(res.get("reason", ""))
		ck(not bool(res.get("ok", true)), "%s se rechaza" % c[0])
		ck(reason.strip_edges() != "" and reason.find(" ") > 0 and snake.search(reason) == null and reason.find("{") < 0, "%s: el motivo es una frase concreta, sin identificadores ni marcas sin completar: «%s»" % [c[0], reason])
		ck(snap_hash(r) == h0 and (res.get("path", []) as Array).is_empty(), "%s no cambia el estado ni deja un camino" % c[0])
	var done: RefCounted = new_rules(1817, {"skip_intro": true})
	run_to(done, 900.0)
	var late := order(done, "portal", "move", Vector2(300, 300))
	ck(not bool(late.get("ok", true)) and str(late.get("reason", "")) != "", "con la partida terminada ninguna orden se acepta: «%s»" % str(late.get("reason", "")))
	ck(not bool(_dict(done.call("give_signal")).ok), "con la partida terminada la señal se rechaza")

# ---------------------------------------------------------------------------------------------------------------------
# Sigilo, señal, torre y refuerzo

func _noise_rank(state_text: String) -> int:
	return R.NOISE_STATES.find(state_text)

func _test_stealth_and_signal() -> void:
	var ranks := {}
	for pace in ["sneak", "march", "run"]:
		var r := new_rules(1817, {"skip_intro": true})
		order(r, "portal", "move", Vector2(300, 480), {"pace": pace})
		r.call("tick", 2.0)
		var unit: Dictionary = {}
		for u in _dict(r.call("render_state")).units:
			if str(u.id) == "portal":
				unit = u
		ranks[pace] = _noise_rank(str(unit.get("noise_state", "")))
		ck(ranks[pace] >= 0, "el ruido de la marcha «%s» se ve en palabras (%s)" % [pace, str(unit.get("noise_state", ""))])
	ck(ranks.sneak <= ranks.march and ranks.march <= ranks.run and ranks.sneak < ranks.run, "el ruido crece con el ritmo: silencio, marcha y carrera (%s)" % str(ranks))
	var quiet := new_rules(1817, {"skip_intro": true})
	var idle_unit: Dictionary = {}
	for u in _dict(quiet.call("render_state")).units:
		if str(u.id) == "rodriguez":
			idle_unit = u
	ck(str(idle_unit.get("noise_state", "")) == "silencio", "una agrupación quieta no hace ruido")
	# señal: quién falta, oscuridad y desvelo
	var r2 := new_rules(1817, {"skip_intro": true})
	var si0: Dictionary = _dict(r2.call("signal_info"))
	ck(missing_keys(si0, ["can_give", "reason", "in_position", "waiting", "dark_pct", "drift_pct"]).is_empty(), "signal_info trae sus seis campos")
	ck(not bool(si0.can_give) and str(si0.reason) != "" and (si0.in_position as Array).is_empty(), "sin nadie en su puesto no se puede dar la señal y se dice por qué: «%s»" % str(si0.get("reason", "")))
	ck(float(si0.dark_pct) >= 99.0 and float(si0.drift_pct) == 0.0, "a la hora cero la oscuridad es plena (%.0f %%) y no hay desvelo" % float(si0.dark_pct))
	order(r2, "rodriguez", "position")
	order(r2, "portal", "position")
	run_until(r2, func(): return bool(_dict(r2.call("signal_info")).can_give), 300.0)
	var si1: Dictionary = _dict(r2.call("signal_info"))
	ck(bool(si1.can_give) and (si1.in_position as Array).size() >= 1, "con una partida en su puesto ya se puede dar la señal")
	ck((si1.waiting as Array).size() >= 1, "signal_info dice quién todavía no llegó (%s)" % str(si1.waiting))
	var hud: Dictionary = _dict(r2.call("hud_state"))
	ck(bool(hud.senal.puede) == bool(si1.can_give) and (hud.senal.faltan as Array).size() == (si1.waiting as Array).size(), "hud.senal repite lo que dice signal_info")
	var waiting_cmd := order(r2, "arias", "position")
	ck(bool(waiting_cmd.ok), "Arias va a su puesto aunque la señal esté disponible")
	var dark_early := float(_dict(r2.call("signal_info")).dark_pct)
	r2.state.elapsed = float(cfg.time.day_full_s)
	ck(float(_dict(r2.call("signal_info")).dark_pct) < dark_early and float(_dict(r2.call("signal_info")).dark_pct) < 1.0, "con luz de día el costo de la oscuridad se va (%.0f %% → %.0f %%)" % [dark_early, float(_dict(r2.call("signal_info")).dark_pct)])
	var drift_a := new_rules(1817, {"skip_intro": true})
	drift_a.state.elapsed = float(cfg.time.alba_start_s) - 1.0
	var d0 := float(_dict(drift_a.call("signal_info")).drift_pct)
	drift_a.state.elapsed = float(cfg.time.alba_start_s) + 60.0
	var d1 := float(_dict(drift_a.call("signal_info")).drift_pct)
	drift_a.state.elapsed = float(cfg.time.dawn_discovery_s)
	var d2 := float(_dict(drift_a.call("signal_info")).drift_pct)
	ck(d0 == 0.0 and d1 > d0 and d2 > d1 and d2 <= 100.0, "el desvelo corre desde el alba y crece hasta el amanecer (%.0f %% → %.0f %% → %.0f %%)" % [d0, d1, d2])
	# la guardia se desvela sola desde el alba
	var calm := new_rules(1817, {"skip_intro": true})
	run_to(calm, float(cfg.time.alba_start_s) - 5.0)
	var alert_before := 0.0
	for fid in V.OBJECTIVES:
		alert_before = maxf(alert_before, float(calm.state.objectives[fid].alert))
	run_to(calm, float(cfg.time.dawn_discovery_s) - 5.0)
	var alert_after := 0.0
	for fid in V.OBJECTIVES:
		alert_after = maxf(alert_after, float(calm.state.objectives[fid].alert))
	ck(alert_after > alert_before and alert_after > 0.2, "la alerta de la guardia sube sola desde el alba (%.2f → %.2f)" % [alert_before, alert_after])
	# sorpresa: la ventana decae y la cuenta del HUD baja
	var atk := new_rules(1817, {"phase": "ataque"})
	var s0 := float(_dict(atk.call("hud_state")).frentes[0].sorpresa_s)
	atk.call("tick", 10.0)
	var s1 := float(_dict(atk.call("hud_state")).frentes[0].sorpresa_s)
	ck(absf(s0 - float(cfg.time.surprise_s)) < 1e-6 and s1 < s0 and s1 > 0.0, "la cuenta de sorpresa del HUD arranca en %.0f s y baja (%.1f → %.1f)" % [float(cfg.time.surprise_s), s0, s1])

func _test_tower() -> void:
	var tcfg: Dictionary = cfg.tower
	var r := new_rules(1817, {"phase": "ataque"})
	var armed := run_until(r, func(): return not (_dict(r.call("hud_state")).get("torre", {}) as Dictionary).is_empty(), 90.0)
	ck(armed, "la torre abre fuego tras la señal (a los %.0f s)" % float(r.state.elapsed))
	var delay := float(r.state.elapsed) - float(r.state.alarm.first_shot_at)
	ck(delay >= float(tcfg.arm_delay_s[str(r.state.world.guardia)]) - 1e-6 and delay <= float(tcfg.arm_delay_s[str(r.state.world.guardia)]) + 2.0, "la torre tarda lo que dice tower.arm_delay_s para la guardia %s (%.2f s)" % [str(r.state.world.guardia), delay])
	var tw: Dictionary = _dict(_dict(r.call("hud_state")).get("torre", {}))
	ck(missing_keys(tw, ["activa", "municion_pct", "proxima_en_s", "periodo_s", "angulo_muerto_m"]).is_empty(), "hud.torre trae munición, próxima descarga, período y ángulo muerto")
	ck(absf(float(tw.get("periodo_s", 0.0)) - float(tcfg.volley_period_s)) < TOLERANCE and absf(float(tw.get("angulo_muerto_m", 0.0)) - float(tcfg.dead_angle_m)) < TOLERANCE, "el período (%.1f s) y el ángulo muerto (%.0f m) salen del JSON" % [float(tcfg.volley_period_s), float(tcfg.dead_angle_m)])
	ck(float(tw.get("proxima_en_s", 99.0)) <= float(tcfg.volley_period_s) + 1e-6, "la próxima descarga está a menos de un período")
	var ammo_start := float(tw.get("municion_pct", 0.0))
	var t_armed := float(r.state.elapsed)
	run_to(r, t_armed + float(tcfg.volley_period_s) * 3.0 + 0.5)
	var ammo_mid := float(_dict(_dict(r.call("hud_state")).get("torre", {})).get("municion_pct", ammo_start))
	ck(ammo_mid < ammo_start and ammo_mid > 0.0, "la munición baja con cada descarga (%.0f %% → %.0f %%)" % [ammo_start, ammo_mid])
	var volleys_expected := ceili(float(tcfg.volleys) * 1.0)
	run_to(r, t_armed + float(tcfg.volley_period_s) * float(volleys_expected) + 10.0)
	var hud_end: Dictionary = _dict(r.call("hud_state"))
	var done_ok := str(r.state.status) != "playing" or (hud_end.torre as Dictionary).is_empty() or not bool(hud_end.torre.get("activa", true))
	ck(done_ok, "la torre se queda sin munición tras %d descargas de %.1f s (≈ 90 s)" % [int(tcfg.volleys), float(tcfg.volley_period_s)])
	ck(not bool(r.state.objectives.cuartel.tower.active) or str(r.state.status) != "playing", "al terminar la munición la torre deja de estar activa")
	var cap_only := float(tcfg.volley_period_s) * float(tcfg.volleys)
	ck(absf(cap_only - 90.0) < 1e-6, "en R1 la torre es un temporizador de 90 s (12 × 7,5)")
	var alerts_with_tower := false
	var r2 := new_rules(1817, {"phase": "ataque"})
	run_until(r2, func(): return not (_dict(r2.call("hud_state")).get("torre", {}) as Dictionary).is_empty(), 90.0)
	for a in _dict(r2.call("hud_state")).alertas:
		if str(a.id) == "torre":
			alerts_with_tower = true
	ck(alerts_with_tower, "cuando la torre abre fuego el HUD lo avisa")
	var dmg := new_rules(1817, {"phase": "ataque"})
	var before := float(unit_of(dmg, "portal").strength)
	run_to(dmg, float(dmg.state.elapsed) + 60.0)
	ck(float(unit_of(dmg, "portal").strength) < before, "la torre y el asalto le cuestan fuerza a quien ataca el cuartel (%.1f → %.1f)" % [before, float(unit_of(dmg, "portal").strength)])

func _test_reinforcement() -> void:
	var rf: Dictionary = cfg.reinforcement
	var r := new_rules(1817, {"phase": "ataque"})
	var delay := float(rf.delay_s[str(r.state.world.refuerzo)])
	ck(absf(float(r.state.alarm.reinforcement_at) - float(r.state.alarm.signal_at) - delay) < 1e-6, "el refuerzo llega a la señal + %.0f s (reinforcement.delay_s.%s)" % [delay, str(r.state.world.refuerzo)])
	for variant in ["temprano", "normal", "tardio"]:
		var rv := new_rules(1817, {"phase": "ataque", "variant": {"refuerzo": variant}})
		ck(absf(float(rv.state.alarm.reinforcement_at) - float(rv.state.alarm.signal_at) - float(rf.delay_s[variant])) < 1e-6, "con refuerzo %s llega %.0f s después de la señal" % [variant, float(rf.delay_s[variant])])
	var hud_state0: Dictionary = _dict(_dict(r.call("hud_state")).refuerzo)
	ck(str(hud_state0.estado) == "desconocido" and (hud_state0.banda as Array).size() == 2, "en el ataque el refuerzo es desconocido y el HUD trae su banda de [mín, máx]")
	var ext := new_rules(1817, {"phase": "extraccion"})
	var hud_ext: Dictionary = _dict(_dict(ext.call("hud_state")).refuerzo)
	ck(str(hud_ext.estado) in ["en_camino", "visible"], "en la extracción el refuerzo se anuncia en camino (%s)" % str(hud_ext.estado))
	var warn_at := float(ext.state.alarm.reinforcement_at) - float(rf.warning_lead_s)
	run_to(ext, warn_at + 1.0)
	var warned := false
	for e in ext.state.log:
		if str(e.kind) == "reinforcement_warning":
			warned = true
	ck(warned and str(_dict(_dict(ext.call("hud_state")).refuerzo).estado) == "visible", "%.0f s antes de llegar hay aviso (polvareda al sur) y el HUD lo muestra visible" % float(rf.warning_lead_s))
	var rest := float(_dict(_dict(ext.call("hud_state")).refuerzo).restante_s)
	ck(rest > 0.0 and rest <= float(rf.warning_lead_s), "el HUD cuenta los segundos que faltan (%.0f s)" % rest)
	var crit := false
	for a in _dict(ext.call("hud_state")).alertas:
		if str(a.nivel) == "critica":
			crit = true
	ck(crit, "con el refuerzo a la vista hay una alerta crítica con cuenta regresiva")
	run_to(ext, float(ext.state.alarm.reinforcement_at) + 2.0)
	ck(str(ext.state.status) == "defeat" and str(ext.state.reason) == "interceptados", "si la columna no salió antes, el refuerzo la intercepta (interceptados)")
	ck(bool(ext.state.alarm.reinforcement_arrived), "el estado registra que el refuerzo llegó")
	var smoke := new_rules(1817, {"phase": "extraccion"})
	var base_at := float(smoke.state.alarm.reinforcement_at)
	var powder: Array = []
	for it in smoke.state.loot.items:
		if str(it.kind) == "polvora":
			powder.append(it)
	ck(powder.size() >= 3, "hay al menos tres lotes de pólvora para quemar")
	var advances: Array = []
	var arreo_pos := Vector2(float(powder[0].x), float(powder[0].z))
	order(smoke, "arreo", "move", arreo_pos)
	run_until(smoke, func(): return str(unit_of(smoke, "arreo").stage) == "idle", 200.0)
	for it in powder:
		var before_at := float(smoke.state.alarm.reinforcement_at)
		var res := order(smoke, "arreo", "destroy", Vector2(float(it.x), float(it.z)), {"item": str(it.id)})
		if not bool(res.ok):
			continue
		run_until(smoke, func(): return str(unit_of(smoke, "arreo").stage) != "loading", 120.0)
		advances.append(before_at - float(smoke.state.alarm.reinforcement_at))
	var adv_total := base_at - float(smoke.state.alarm.reinforcement_at)
	var sm: Dictionary = rf.smoke_advance_s
	ck(advances.size() >= 3 and absf(float(advances[0]) - float(sm.first)) < 1e-6 and absf(float(advances[1]) - float(sm.next)) < 1e-6, "quemar pólvora adelanta el refuerzo %.0f s la primera vez y %.0f s las siguientes (%s)" % [float(sm.first), float(sm.next), str(advances)])
	ck(adv_total <= float(sm.cap) + 1e-6 and adv_total > 0.0, "el adelanto total tiene tope de %.0f s (adelantó %.0f s)" % [float(sm.cap), adv_total])
	var band: Array = rf.band_initial_s
	ck(float(band[0]) < float(band[1]) and float(band[0]) > 0.0, "la banda inicial del reloj del refuerzo es creciente: [%.0f, %.0f]" % [float(band[0]), float(band[1])])

# ---------------------------------------------------------------------------------------------------------------------
# Botín y puntaje

func _test_loot_and_treatments() -> void:
	var r := new_rules(1817, {"skip_intro": true})
	var lt: Dictionary = cfg.loot
	var cap: Dictionary = lt.capacity
	var cap0 := float(cap.own_mules) * float(cap.kg_per_mule)
	ck(absf(float(r.state.loot.capacity_kg) - cap0) < 1e-6, "antes de la posta la capacidad es la de las mulas propias (%.0f kg)" % cap0)
	var ls: Dictionary = _dict(r.call("loot_state"))
	ck(missing_keys(ls, ["items", "capacity_kg", "load_kg", "golpe"]).is_empty() and missing_keys(ls.golpe, ["entregado", "destruido", "oculto", "perdido", "pendiente", "total"]).is_empty(), "loot_state trae lotes, capacidad, carga y el golpe en seis partes")
	ck(absf(float(ls.golpe.pendiente) - 100.0) < 1e-6 and float(ls.golpe.entregado) == 0.0, "al empezar todo el golpe está pendiente")
	var ext := new_rules(1817, {"phase": "extraccion"})
	var mules := float(cap.corral_mules[str(ext.state.world.loot_traits.corral)])
	ck(absf(float(ext.state.loot.capacity_kg) - (float(cap.own_mules) + mules) * float(cap.kg_per_mule)) < 1e-6, "con la posta tomada se suman las mulas del corral (%.0f kg)" % float(ext.state.loot.capacity_kg))
	var thin := new_rules(1817, {"phase": "extraccion", "loot_traits": {"corral": "desbandado"}})
	ck(float(thin.state.loot.capacity_kg) < float(ext.state.loot.capacity_kg), "con el corral desbandado la capacidad es menor (%.0f kg)" % float(thin.state.loot.capacity_kg))
	# carga que no entra
	var small := new_rules(1817, {"phase": "extraccion", "loot_traits": {"corral": "desbandado"}})
	small.state.loot.capacity_kg = 50.0
	var big := {}
	for it in small.state.loot.items:
		if float(it.qty) * float(it.unit_kg) > 100.0:
			big = it
			break
	var near_big := Vector2(float(big.x), float(big.z))
	order(small, "arreo", "move", near_big)
	run_until(small, func(): return str(unit_of(small, "arreo").stage) == "idle", 200.0)
	var too_much := order(small, "arreo", "load", near_big, {"item": str(big.id)})
	ck(not bool(too_much.get("ok", true)) and str(too_much.get("reason", "")).find("kg") >= 0, "un lote que no entra en la capacidad se rechaza diciendo cuántos kg faltan: «%s»" % str(too_much.get("reason", "")))
	# contabilidad del golpe: entregar, destruir y abandonar
	var acc := new_rules(1817, {"skip_intro": true})
	if pol != null:
		play_by_hand(acc, 840.0)
		var rep: Dictionary = _dict(acc.call("campaign_report"))
		var g: Dictionary = rep.golpe
		ck(str(rep.status) == "victory", "la partida a mano termina en victoria")
		ck(float(g.entregado) > 0.0 and absf(float(g.entregado) + float(g.destruido) + float(g.oculto) + float(g.perdido) - 100.0) < 1e-3, "al terminar el golpe suma 100: entregado %.1f + destruido %.1f + oculto %.1f + perdido %.1f" % [float(g.entregado), float(g.destruido), float(g.oculto), float(g.perdido)])
		var abandoned := 0
		var delivered_items := 0
		for it in acc.state.loot.items:
			if str(it.state) == "abandonado":
				abandoned += 1
			elif str(it.state) == "entregado":
				delivered_items += 1
		ck(delivered_items >= 1, "lo cargado se entrega y lo que queda en el sitio se da por abandonado (%d entregados, %d abandonados)" % [delivered_items, abandoned])
		ck(float(acc.state.loot.load_kg) == 0.0, "la carga del arreo queda en 0 al salir")
	var wet := new_rules(1817, {"phase": "extraccion", "loot_traits": {"polvora": "humeda"}})
	var dry := new_rules(1817, {"phase": "extraccion", "loot_traits": {"polvora": "seca"}})
	var gp_wet := 0.0
	var gp_dry := 0.0
	for pair in [[wet, "wet"], [dry, "dry"]]:
		var rr: RefCounted = pair[0]
		var powder := {}
		for it in rr.state.loot.items:
			if str(it.kind) == "polvora":
				powder = it
				break
		var pos := Vector2(float(powder.x), float(powder.z))
		order(rr, "arreo", "move", pos)
		run_until(rr, func(): return str(unit_of(rr, "arreo").stage) == "idle", 200.0)
		order(rr, "arreo", "load", pos, {"item": str(powder.id)})
		run_until(rr, func(): return str(unit_of(rr, "arreo").stage) != "loading", 200.0)
		order(rr, "arreo", "leave")
		run_until(rr, func(): return str(unit_of(rr, "arreo").stage) == "exited" or str(rr.state.status) != "playing", 400.0)
		var delivered := float(rr.state.loot.delivered_value)
		if pair[1] == "wet":
			gp_wet = delivered
		else:
			gp_dry = delivered
	ck(gp_dry > 0.0 and absf(gp_wet - gp_dry * float(lt.powder_wet_mult)) < 1e-6, "la pólvora mojada vale ×%.1f al entregarla (%.2f contra %.2f)" % [float(lt.powder_wet_mult), gp_wet, gp_dry])
	var tr: Dictionary = lt.treatments
	ck(absf(float(tr.entregar) - 1.0) < TOLERANCE and float(tr.destruir) < float(tr.ocultar) and float(tr.ocultar) < float(tr.entregar) and float(tr.abandonar) == 0.0, "tratamientos: entregar ×1, ocultar ×%.2f, destruir ×%.2f y abandonar ×0 (en orden)" % [float(tr.ocultar), float(tr.destruir)])
	var points := 0.0
	for k in lt.classes:
		points += float(lt.classes[k].points)
	ck(absf(points - 100.0) < TOLERANCE, "las clases del botín suman exactamente 100 puntos (%.0f)" % points)

# ---------------------------------------------------------------------------------------------------------------------
# Desenlaces

func _test_outcomes() -> void:
	var oc: Dictionary = cfg.outcome
	ck((oc.causes as Dictionary).keys() == R.CAUSES, "outcome.causes tiene las 8 causas del vocabulario en su orden")
	var snake := RegEx.new()
	snake.compile("[a-z]+_[a-z]+")
	for id in R.CAUSES:
		var c: Dictionary = oc.causes[id]
		var shown := String(c.texto).replace("{t}", "10:00").replace("{lugar}", "la zona de partida").replace("{deLugar}", "de la zona de partida").replace("{aLugar}", "a la zona de partida").replace("{grupo}", "la partida de Portal")
		ck(String(c.titulo) != "" and String(c.consejo) != "" and shown.length() <= 140 and snake.search(shown) == null and snake.search(String(c.consejo)) == null, "causa %s: título, consejo y texto de %d caracteres (máximo 140), sin jerga" % [id, shown.length()])
	var reached := {}
	# amanecio
	var a := new_rules(1817, {"skip_intro": true})
	run_to(a, 900.0)
	reached[str(a.state.reason)] = _dict(a.call("campaign_report"))
	# retirada
	var rt := new_rules(1817, {"skip_intro": true})
	rt.call("tick", 5.0)
	ck(bool(_dict(rt.call("retreat_all")).ok) and str(rt.state.status) == "defeat" and str(rt.state.reason) == "retirada", "retreat_all termina en derrota por retirada")
	reached[str(rt.state.reason)] = _dict(rt.call("campaign_report"))
	# interceptados
	var it := new_rules(1817, {"phase": "extraccion"})
	run_to(it, 900.0)
	reached[str(it.state.reason)] = _dict(it.call("campaign_report"))
	# frente_roto: una partida de combate cae bajo el umbral de fuga antes de tomar su frente
	var fr := new_rules(1817, {"phase": "ataque"})
	fr.state.units[0].strength = float(cfg.combat.rout_strength) - 1.0
	fr.call("tick", 1.0)
	reached[str(fr.state.reason)] = _dict(fr.call("campaign_report"))
	# dispersos: las tres partidas por debajo de la fuerza mínima
	var ds := new_rules(1817, {"phase": "ataque"})
	for g in V.COMBAT_GROUPS:
		ds.state.units[V.GROUPS.find(g)].strength = float(cfg.outcome.victory.strength_min_pct) - 2.0
	ds.call("tick", 1.0)
	reached[str(ds.state.reason)] = _dict(ds.call("campaign_report"))
	# sin_carga: sale la columna con menos golpe que el mínimo
	var sc := new_rules(1817, {"phase": "extraccion"})
	for it2 in sc.state.loot.items:
		it2.state = "abandonado"
	sc.state.units[4].stage = "exited"
	sc.call("tick", 1.0)
	reached[str(sc.state.reason)] = _dict(sc.call("campaign_report"))
	# plazo: se cumple el plazo duro
	var pl := new_rules(1817, {"phase": "extraccion"})
	pl.state.alarm.reinforcement_at = 99999.0
	pl.state.elapsed = float(cfg.time.deadline_s) - 0.25
	pl.call("tick", 1.0)
	reached[str(pl.state.reason)] = _dict(pl.call("campaign_report"))
	if real_only():
		_checks().call("_test_discovered", reached)
	var reached_ids: Array = []
	for k in reached:
		reached_ids.append(k)
		var rep: Dictionary = reached[k]
		ck(str(rep.get("cause_id", "")) == k and String(rep.get("cause", "")).length() <= 140 and String(rep.get("advice", "")) != "" and String(rep.get("cause", "")).find("{") < 0, "causa %s alcanzada: texto de %d caracteres, consejo y sin marcas sin completar" % [k, String(rep.get("cause", "")).length()])
		ck(String(rep.get("cause", "")).find(":") > 0, "causa %s: el texto nombra el momento (m:ss): «%s»" % [k, String(rep.get("cause", ""))])
	ck(reached_ids.size() >= (7 if stub_only() else 8), "se alcanzan %d de las 8 causas de derrota (%s)" % [reached_ids.size(), str(reached_ids)])
	if stub_only():
		suite.pend("causa-descubiertos", "el stub no produce la causa «descubiertos» (BACKLOG B-019): la clase real cubre las 8", "r1")
	# victoria
	if pol != null:
		var w := new_rules(1817, {"skip_intro": true})
		play_by_hand(w, 840.0)
		var rep_w: Dictionary = _dict(w.call("campaign_report"))
		ck(str(rep_w.status) == "victory" and str(rep_w.cause_id) == "" and R.MEDALS.has(str(rep_w.medal)) and str(rep_w.medal) != "", "la victoria no tiene causa y trae medalla (%s)" % str(rep_w.medal))
		var gold := float(rep_w.golpe.entregado) + float(rep_w.golpe.destruido) + float(rep_w.golpe.oculto)
		ck(gold >= float(oc.victory.golpe_min), "ganar exige un golpe de al menos %.0f (hizo %.1f)" % [float(oc.victory.golpe_min), gold])
		ck(str(rep_w.outcome_title) == str(oc.victory.titulo) and String(rep_w.medal_label) != "", "la victoria trae su título y la etiqueta de la medalla")
		ck((rep_w.pieces as Array).size() == 7, "el parte lista las 7 piezas de artillería para el epílogo (%d)" % (rep_w.pieces as Array).size())
		var won_snapshot: Dictionary = w.call("snapshot")
		ck(bool(_dict(w.call("validate_snapshot", won_snapshot)).ok), "el estado de la victoria pasa validate_snapshot")
	var med: Dictionary = oc.medals
	ck(float(med.plata.golpe_min) < float(med.oro.golpe_min) and float(med.oro.loss_max_pct) < float(med.plata.loss_max_pct), "las medallas son más exigentes de bronce a oro")

func _test_event_kinds() -> void:
	var all_events: Array = []
	for opts in [{"skip_intro": true}, {"phase": "ataque"}, {"phase": "extraccion"}]:
		var r := new_rules(1817, opts)
		all_events.append_array(follow_next_step(r).events)
		ck((r.state.log as Array).size() <= 400, "el registro respeta el tope de 400 eventos")
		var in_log := 0
		for e in all_events:
			if (r.state.log as Array).has(e):
				in_log += 1
		ck(in_log >= 1, "los eventos que devuelve tick también quedan en state.log")
	var bad_kind: Array = []
	var bad_shape: Array = []
	var kinds_seen := {}
	for e in all_events:
		kinds_seen[str(e.get("kind", ""))] = true
		if not R.EVENT_KINDS.has(str(e.get("kind", ""))):
			bad_kind.append(str(e.get("kind", "?")))
		if not missing_keys(e, ["time", "round", "text", "kind"]).is_empty() or String(e.get("text", "")).strip_edges() == "" or float(e.get("time", -1.0)) < 0.0:
			bad_shape.append(str(e))
	ck(bad_kind.is_empty(), "todo evento trae un kind de EVENT_KINDS (fuera del vocabulario: %s)" % str(bad_kind))
	ck(bad_shape.is_empty() and all_events.size() > 20, "todo evento trae time, round, kind y un texto no vacío (%d eventos; mal formados: %d)" % [all_events.size(), bad_shape.size()])
	for k in ["signal", "capture", "tower", "exit", "victory", "dawn"]:
		ck(kinds_seen.has(k), "en las partidas de la prueba aparece un evento «%s»" % k)
	var no_dup := true
	var last_time := -1.0
	var r2 := new_rules(1817, {"phase": "ataque"})
	for i in range(120):
		for e in r2.call("tick", 1.0):
			if float(e.time) < last_time - 1e-9:
				no_dup = false
			last_time = float(e.time)
	ck(no_dup, "los eventos salen en orden de tiempo")
	var drained := new_rules(1817, {"phase": "ataque"})
	drained.call("tick", 5.0)
	ck((drained.call("tick", 0.0) as Array).is_empty(), "un tick sin avance no repite los eventos ya entregados")

# ---------------------------------------------------------------------------------------------------------------------
# Guardado, carga y validación

## Las 34 mutaciones del guardado (las 18 obligatorias y las 13 deseables de la rúbrica del QA, más 3 propias): [nombre, cambio]. Todas tienen que rechazarse.
func _mutations() -> Array:
	return [
		["otro escenario (justine)", func(d): d.scenario = "justine"],
		["otro escenario (norte)", func(d): d.scenario = "norte"],
		["schema_version 99", func(d): d.schema_version = 99],
		["otro map_version", func(d): d.map_version = int(d.map_version) + 1],
		["una unidad menos", func(d): d.units.pop_back()],
		["ids de unidad repetidos", func(d): d.units[1].id = d.units[0].id],
		["x fuera del mapa", func(d): d.units[0].x = -5.0],
		["z fuera del mapa", func(d): d.units[0].z = 9999.0],
		["etapa inexistente", func(d): d.units[0].stage = "volando"],
		["ritmo inexistente", func(d): d.units[0].pace = "teletransporte"],
		["orden con acción inexistente", func(d): d.units[0].order = {"action": "hackear"}],
		["guardia ilegal", func(d): d.world.guardia = "furiosa"],
		["total del botín distinto de 100", func(d): d.loot.total_value = 99.0],
		["entregado + destruido > 100", func(d): d.loot.delivered_value = 80.0; d.loot.destroyed_value = 30.0],
		["carga mayor que la capacidad", func(d): d.loot.load_kg = float(d.loot.capacity_kg) + 100.0],
		["primer disparo en el futuro", func(d): d.alarm.first_shot_at = float(d.elapsed) + 500.0],
		["victoria sin los tres frentes tomados", func(d): d.status = "victory"; d.objectives.bateria.state = "guardado"],
		["en marcha sin camino ni orden", func(d): d.units[0].stage = "moving"; d.units[0].path = []; d.units[0].order = {}],
		["fuerza mayor que 100", func(d): d.units[0].strength = 500.0],
		["fuerza negativa", func(d): d.units[0].strength = -10.0],
		["toma mayor que 100", func(d): d.objectives.bateria.toma = 500.0],
		["reloj negativo", func(d): d.elapsed = -5.0],
		["reloj que no es número", func(d): d.elapsed = "abc"],
		["rng_state que no es número", func(d): d.rng_state = "x"],
		["contrato 2", func(d): d.contract = 2],
		["sin objetivos", func(d): d.erase("objectives")],
		["fase inexistente", func(d): d.phase = "luna"],
		["estado inexistente", func(d): d.status = "triunfo"],
		["estado de frente inexistente", func(d): d.objectives.cuartel.state = "destruido"],
		["hombres negativos", func(d): d.units[1].men = -3],
		["mundo que no es un objeto", func(d): d.world = []],
		["torre_en ilegal", func(d): d.world.torre_en = "luna"],
		["rasgo del botín ilegal", func(d): d.world.loot_traits.polvora = "mojadisima"],
		["montada que no es booleano", func(d): d.units[2].mounted = "si"]]

func _test_save_roundtrip() -> void:
	var r := new_rules(1817, {"phase": "ataque"})
	r.call("advance_to", float(r.state.elapsed) + 45.0)
	ck(r.call("save_game", SAVE_PATH) == OK and FileAccess.file_exists(SAVE_PATH), "save_game escribe el archivo")
	ck(not FileAccess.file_exists(SAVE_PATH + ".tmp"), "la escritura es atómica: no queda el .tmp")
	var size := FileAccess.get_file_as_bytes(SAVE_PATH).size()
	ck(size > 0 and size <= 3000000, "el guardado pesa %d B (tope 3 000 000)" % size)
	var r2: RefCounted = rules_script.new()
	var lg: Dictionary = _dict(r2.call("load_game", SAVE_PATH))
	ck(bool(lg.get("ok", false)), "load_game carga el guardado: %s" % str(lg.get("reason", "")))
	ck(same(strip(r2.call("snapshot")), strip(r.call("snapshot"))), "guardar y cargar no cambia snapshot() (tolerancia 1e-6, RNG exacto)")
	ck(int(r2.state.rng_state) == int(r.state.rng_state), "el RNG vuelve exacto")
	ck(str(r2.state.game_id) != str(r.state.game_id) and str(r2.state.previous_game_id) == str(r.state.game_id), "la carga da un game_id nuevo y guarda el anterior en previous_game_id")
	r.call("advance_to", float(r.state.elapsed) + 40.0)
	r2.call("advance_to", float(r2.state.elapsed) + 40.0)
	ck(same(strip(r2.call("snapshot")), strip(r.call("snapshot"))), "seguir jugando tras cargar da lo mismo que seguir con la partida original")
	var snap: Dictionary = r.call("snapshot")
	ck(snap_hash(r) == JSON.stringify(snap, "", true, true).sha256_text() and not snap.is_empty(), "snapshot() es una copia del estado")
	(snap.units as Array)[0].x = 1.0
	ck(float(r.state.units[0].x) != 1.0, "snapshot() es una copia profunda: tocarla no toca el estado")
	var before: Dictionary = r.call("snapshot")
	r.call("advance_to", float(r.state.elapsed) + 20.0)
	var back: Dictionary = _dict(r.call("restore_snapshot", before))
	ck(bool(back.get("ok", false)) and same(r.call("snapshot"), before), "restore_snapshot vuelve al estado exacto, sin tocar archivos")
	var broken: Dictionary = before.duplicate(true)
	broken.scenario = "norte"
	var kept := snap_hash(r)
	var no_back: Dictionary = _dict(r.call("restore_snapshot", broken))
	ck(not bool(no_back.get("ok", true)) and str(no_back.get("reason", "")) != "" and snap_hash(r) == kept, "restore_snapshot rechaza lo inválido con motivo y deja el estado como estaba")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	ck(parsed is Dictionary and int(parsed.map_version) == int(map.get("map_version", -1)), "el guardado lleva el map_version del mapa")

func _test_save_mutations() -> void:
	var r := new_rules(1817, {"phase": "ataque"})
	r.call("advance_to", float(r.state.elapsed) + 45.0)
	var good: Dictionary = r.call("snapshot")
	ck(bool(_dict(r.call("validate_snapshot", good)).ok), "el estado sano pasa validate_snapshot")
	ck(not bool(_dict(r.call("validate_snapshot", "no es un objeto")).ok) and not bool(_dict(r.call("validate_snapshot", null)).ok) and not bool(_dict(r.call("validate_snapshot", [])).ok), "validate_snapshot rechaza lo que ni siquiera es un objeto")
	var before := snap_hash(r)
	var table := _mutations()
	var rejected := 0
	var accepted: Array = []
	var no_reason: Array = []
	for m in table:
		var d: Dictionary = good.duplicate(true)
		m[1].call(d)
		var res: Dictionary = _dict(r.call("validate_snapshot", d))
		if not bool(res.get("ok", true)):
			rejected += 1
			if str(res.get("reason", "")).strip_edges() == "":
				no_reason.append(m[0])
		else:
			accepted.append(m[0])
	ck(rejected >= 30, "validate_snapshot rechaza al menos 30 mutaciones (rechazó %d de %d; aceptó: %s)" % [rejected, table.size(), str(accepted)])
	ck(rejected == table.size(), "...y las %d de la lista, ninguna se cuela" % table.size())
	ck(no_reason.is_empty(), "...todas con un motivo escrito (sin motivo: %s)" % str(no_reason))
	ck(snap_hash(r) == before, "validar no toca el estado")
	var other: Dictionary = good.duplicate(true)
	table[0][1].call(other)
	var other_scenario := _dict(r.call("validate_snapshot", other))
	ck(str(other_scenario.get("reason", "")).find("otro escenario") >= 0, "un guardado de otro escenario dice «Este guardado es de otro escenario»: «%s»" % str(other_scenario.get("reason", "")))
	# archivos rotos: se rechazan con motivo sin tocar el estado
	r.call("save_game", SAVE_PATH)
	var text := FileAccess.get_file_as_string(SAVE_PATH)
	for pair in [["la mitad del archivo", text.substr(0, text.length() / 2)], ["texto que no es JSON", "esto no es json"], ["archivo vacío", ""], ["un arreglo", "[]"]]:
		var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		f.store_string(pair[1])
		f.close()
		var rx: Dictionary = _dict(r.call("load_game", SAVE_PATH))
		ck(not bool(rx.get("ok", true)) and str(rx.get("reason", "")) != "" and snap_hash(r) == before, "load_game de %s se rechaza con motivo y no toca el estado" % pair[0])
	var missing: Dictionary = _dict(r.call("load_game", "user://hx_rules_no_existe.json"))
	ck(not bool(missing.get("ok", true)) and str(missing.get("reason", "")) != "", "load_game de un archivo que no existe se rechaza con motivo")

func _test_foreign_saves() -> void:
	var r := new_rules(1817, {"phase": "ataque"})
	var before := snap_hash(r)
	for esc in ["justine", "norte"]:
		var g: RefCounted = game_rules_script.new()
		g.call("new_game", esc, 1806)
		g.call("save_game", SAVE_PATH)
		var res: Dictionary = _dict(r.call("load_game", SAVE_PATH))
		ck(not bool(res.get("ok", true)) and String(res.get("reason", "")).find("otro escenario") >= 0, "un guardado de %s se rechaza: «%s»" % [esc, str(res.get("reason", ""))])
		ck(snap_hash(r) == before, "...y el estado de Humahuaca queda intacto")
	var g2: RefCounted = game_rules_script.new()
	g2.call("new_game", "justine", 1806)
	var gs: Dictionary = g2.call("snapshot")
	ck(not bool(_dict(r.call("validate_snapshot", gs)).ok), "validate_snapshot rechaza el estado de la Justina")
	var j2: RefCounted = game_rules_script.new()
	var try_hx: Dictionary = _dict(j2.call("new_game", "humahuaca", 1806))
	ck(str(try_hx.get("scenario", "justine")) == "justine", "GameRules.new_game(«humahuaca») sigue devolviendo la Justina (nunca se le pasa el nivel)")

# ---------------------------------------------------------------------------------------------------------------------
# Progreso (CONTRATO 3.3)

func _test_progress() -> void:
	var seeds: Array = cfg.campaign.world_seeds
	var p := new_progress()
	p.call("reset_all")
	ck(int(p.call("world_seed")) == int(seeds[0]) and int(p.attempts) == 0 and not bool(p.won) and int(p.defeats_in_row) == 0 and str(p.best_medal) == "", "el progreso nuevo empieza en la primera semilla, sin intentos, derrotas ni medalla")
	var rg := new_rules(int(p.call("world_seed")), {"skip_intro": true})
	var b: Dictionary = _dict(p.call("begin_attempt", rg))
	ck(int(b.get("attempt", 0)) == 1 and int(p.attempts) == 1, "begin_attempt cuenta el intento")
	run_to(rg, 900.0)
	var rr: Dictionary = _dict(p.call("record_result", rg))
	ck(not bool(rr.won) and str(rr.cause_id) == "amanecio" and int(p.defeats_in_row) == 1 and not bool(rr.next_available), "record_result de una derrota: causa, racha en 1 y sin acceso al nivel siguiente")
	ck(missing_keys(rr, ["won", "medal", "medal_label", "record_line", "cause_id", "cause", "advice", "hint", "defeats_in_row", "offered_assists", "lines", "new_diary", "facts", "next_available", "next_label"]).is_empty(), "record_result trae todos los campos de 3.3: falta %s" % str(missing_keys(rr, ["won", "medal", "medal_label", "record_line", "cause_id", "cause", "advice", "hint", "defeats_in_row", "offered_assists", "lines", "new_diary", "facts", "next_available", "next_label"])))
	ck(missing_keys(rr.facts, ["frentes", "golpe", "bajas", "tiempo"]).is_empty() and str(rr.record_line) != "", "los tres datos del parte y la línea de récord están")
	ck(int(p.call("world_seed")) == int(seeds[0]), "el mundo no cambia hasta ganar (sigue la semilla %d)" % int(seeds[0]))
	var retry: Array = p.call("retry_options")
	var retry_ids: Array = []
	for o in retry:
		retry_ids.append(o.id)
	ck(retry_ids == R.RETRY and missing_keys(retry[0], ["id", "label", "available", "at_s"]).is_empty(), "retry_options ofrece las cuatro opciones del vocabulario con etiqueta y disponibilidad")
	var avail_ids: Array = []
	for o in retry:
		if bool(o.available):
			avail_ids.append(o.id)
	ck(avail_ids.has("mismo_mundo") and avail_ids.has("mundo_nuevo"), "siempre se puede reintentar el mismo mundo o pedir uno nuevo")
	ck(p.call("save_progress") and FileAccess.file_exists(PROGRESS_PATH) and not FileAccess.file_exists(PROGRESS_PATH + ".tmp"), "save_progress escribe de forma atómica")
	var p2 := new_progress()
	ck(p2.call("load_progress") and int(p2.attempts) == 1 and int(p2.defeats_in_row) == 1, "load_progress recupera intentos y racha")
	var f := FileAccess.open(PROGRESS_PATH, FileAccess.WRITE)
	f.store_string("{roto")
	f.close()
	var p3 := new_progress()
	ck(not p3.call("load_progress") and str(p3.load_note) != "" and int(p3.attempts) == 0, "un progreso dañado se descarta con una nota y se empieza de cero: «%s»" % str(p3.load_note))
	var f2 := FileAccess.open(PROGRESS_PATH, FileAccess.WRITE)
	f2.store_string(JSON.stringify({"version": 99, "attempts": 3}))
	f2.close()
	var p4 := new_progress()
	ck(not p4.call("load_progress") and str(p4.load_note) != "", "un progreso de otra versión se descarta con aviso y no bloquea")
	ck(bool(p4.call("recommended_by_profile", {"justina_ganada": true})) and not bool(p4.call("recommended_by_profile", {})) and not bool(p4.call("recommended_by_profile", {"justina_ganada": false})), "la nota «Recomendado tras la Justina» depende solo de justina_ganada")
	ck(bool(p4.call("tutorial_pending")), "el tutorial queda pendiente hasta marcarlo visto")
	p4.call("mark_tutorial_seen")
	ck(not bool(p4.call("tutorial_pending")), "mark_tutorial_seen lo marca visto")
	var empty_assists: Array = p4.call("offered_assists", rg)
	ck(empty_assists is Array, "offered_assists devuelve un arreglo")
	ck(p4.call("diary_entries") is Array and p4.call("diary_marks") is Array and p4.call("has_checkpoint", "posiciones") is bool, "diario y puntos de control devuelven valores válidos")

func _test_progress_win_next() -> void:
	var p := new_progress()
	p.call("reset_all")
	var seed_before := int(p.call("world_seed"))
	if pol != null:
		var rg := new_rules(seed_before, {"skip_intro": true})
		p.call("begin_attempt", rg)
		play_by_hand(rg, 840.0)
		var rr: Dictionary = _dict(p.call("record_result", rg))
		ck(bool(rr.won) and bool(p.won) and str(p.best_medal) != "" and float(p.best_golpe) > 0.0, "una victoria queda registrada: won, medalla y mejor golpe")
		ck(bool(rr.next_available) and str(rr.next_label).find("Sostener el norte") >= 0, "ganar habilita «Ver la campaña completa: Sostener el norte»")
		ck(int(p.defeats_in_row) == 0, "ganar pone la racha de derrotas en 0")
		ck(int(p.call("world_seed")) != seed_before, "al ganar el mundo se vuelve a sortear (de la semilla %d a la %d)" % [seed_before, int(p.call("world_seed"))])
		ck(str(rr.medal_label) != "" and str(rr.record_line).find("bajas") >= 0, "la línea de récord de la victoria trae medalla, golpe y bajas: «%s»" % str(rr.record_line))
		var rank_before := R.MEDALS.find(str(p.best_medal))
		var rg2 := new_rules(int(p.call("world_seed")), {"skip_intro": true})
		p.call("begin_attempt", rg2)
		run_to(rg2, 900.0)
		p.call("record_result", rg2)
		ck(R.MEDALS.find(str(p.best_medal)) >= rank_before and bool(p.won), "perder después de ganar no baja la mejor medalla ni quita la victoria")
		var p2 := new_progress()
		ck(p2.call("load_progress") and bool(p2.won) and str(p2.best_medal) == str(p.best_medal) and int(p2.attempts) == int(p.attempts), "la victoria y los intentos sobreviven a cerrar y abrir")
		p.call("reset_all")
		ck(int(p.attempts) == 0 and not bool(p.won) and str(p.best_medal) == "", "reset_all vuelve todo a cero")
	ck(bool(p.call("recommended_by_profile", {"justina_ganada": true})), "la capa de progreso lee justina_ganada")

# ---------------------------------------------------------------------------------------------------------------------
# Rutas, visión, ritmo, controles y políticas (tests/hx_rules_checks.gd)

var checks: RefCounted = null

func _checks() -> RefCounted:
	if checks == null:
		checks = Checks.new(self)
	return checks

## TR-075 (CONTRATO 3.2.5): el experto gana y el pasivo pierde.
func _test_policies_extremes() -> void:
	_checks().call("_test_policies_extremes")

## TR-076: las políticas sin ventaja no leen estado oculto.
func _test_policies_blindness() -> void:
	_checks().call("_test_policies_blindness")

# ---------------------------------------------------------------------------------------------------------------------
# Rendimiento (CONTRATO 5.1) y lo que todavía no se puede evaluar

func _test_performance() -> void:
	_checks().call("_test_performance")

func _test_pending_for_r1() -> void:
	if stub_only():
		suite.pend("api-real-rules", "la prueba corrió contra el stub: la clase real rules/humahuaca_rules.gd es la que se certifica (CONTRATO 7 y 8.2)", "r1")
		suite.pend("api-real-progress", "la prueba corrió contra el stub: la clase real rules/humahuaca_progress.gd es la que se certifica (CONTRATO 7 y 8.2)", "r1")
		suite.pend("causa-descubiertos", "el stub no produce la causa «descubiertos» (BACKLOG B-019): la clase real cubre las 8", "r1")
	if pol == null:
		suite.pend("politicas", "la biblioteca de políticas rules/humahuaca_policies.gd (experto gana, pasivo pierde) falta o no carga (CONTRATO 3.2.5 y 8.2)", "r1")
	else:
		ck(pol.get_script_method_list().size() > 0, "la biblioteca de políticas carga")
	suite.pend("barrido-senal", "el barrido del instante de la señal (compuerta 7) y la matriz de enfoques (compuerta 6) llegan en R2b", "r2b")
