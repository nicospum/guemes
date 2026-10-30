extends RefCounted
class_name GameRules
## Authoritative, presentation-independent, JSON-serializable rules.
## Escenario Justina: todas las cifras salen de data/justina_map.json (map_data()); ver docs/CONTRATO_JUSTINA.md y docs/DISENO_REGLAS.md.

const SAVE_VERSION := 1
const JUSTINE_SAVE_VERSION := 3
const MAP_PATH := "res://data/justina_map.json"
const MAX_ROUNDS := 14
const STEP := 0.25
## Ritmo del norte: la retirada realista solo es posible desde esta ronda y con esta presion acumulada (ver docs/BALANCE_NORTE.md).
const RETREAT_MIN_ROUND := 10
const RETREAT_MIN_PRESSURE := 7
## Ocupacion de Salta: fuente S4 y Ideario p. 40 la ubican el 15/4/1817, dentro de la ronda 10 (12-22 abr).
const SALTA_OCCUPATION_ROUND := 10
const DATES := ["15 dic 1816", "29 dic 1816", "12 ene 1817", "26 ene 1817", "9 feb 1817", "23 feb 1817", "1 mar 1817", "15 mar 1817", "29 mar 1817", "12 abr 1817", "22 abr 1817", "30 abr 1817", "4 may 1817", "5 may 1817"]
const CAMPAIGN_ACTIONS := ["move", "scout", "protect", "raid", "rest", "withdraw", "assault"]

## Justina: constantes de implementacion (no son cifras del escenario; las cifras estan en el JSON).
const CELL := 4.0                      ## resolucion de la malla de rutas (contrato 1.5)
const NX := 226                        ## nodos en x: 0..900 cada CELL
const NZ := 131                        ## nodos en z: 0..520 cada CELL
const BLEND_DEFAULT := 4.0             ## contrato 1.3.1: hazards y casco usan blend=4
const NAV_LEVEL_QUANT := 0.05          ## contrato 1.5: el nivel se cuantiza a 0,05 m para reconstruir la malla
const BUCKET := 32.0                   ## indice espacial de sondas
const ROUTE_BANK_MIN_S := 10.0         ## segundos sobre un banco para contarlo en la ruta del parte
const PROBE_POINT_SPACING := 4.0       ## cada cuantos metros el sondeo agrega un punto
const MARK_POINT_SPACING := 2.0
const BEACH_MARGIN_M := 40.0           ## playa seca = x <= shore_high + 40 (texto de actions.rally.regen_requires, JSON)
const BOARDING_EXPOSURE_MULT := 0.6    ## valor por defecto; el escenario lo fija en ship.capture.boarding_exposure_mult
const LOG_MAX := 400                   ## tope del registro de acontecimientos en el estado
const SAVE_MAX_BYTES := 3000000        ## tope del guardado en BYTES utf-8 (load_game rechaza > LOAD_MAX_BYTES)
const LOAD_MAX_BYTES := 4000000
const SAVE_LOG_FALLBACK := 60          ## si aun asi se pasa, se recorta el registro a esto al guardar
const JUSTINE_GROUPS :=["guemes", "arias", "zavala"]
const JUSTINE_STAGES := ["ready", "moving", "working", "stumbling", "rally", "blocked", "dismounting", "boarding", "routed"]
## Despliegue previo (Justina): paso y margen para reasignar fuerza inicial entre los tres grupos (UI de la ronda 1; aditivo, no toca el balance por defecto).
const DEPLOY_STEP := 5.0
const DEPLOY_MARGIN := 15.0
const DEPLOY_MOVE_M := 14.0 ## Ronda 3: cuanto puede moverse el punto de partida (m) respecto del de diseno, sobre tierra firme
const JUSTINE_ORDER_ACTIONS := ["move", "board", "rally", "withdraw", "muster", "resupply", "signal_liniers", "repel", "evacuate"]
const SAVE_ORDERS_FALLBACK := 120      ## si el guardado se pasa del tope, se conservan solo las ultimas ordenes
const SAVE_PROBE_STRIDE := 3           ## y las sondas se aligeran conservando 1 de cada N puntos (mas los extremos)
const SCOUT_ACTIONS_ALL := ["probe", "probe_careful", "mark_ford", "recall"]
const SCOUT_STAGES := ["idle", "moving", "probing", "marking", "lost"]
const PACES := ["walk", "trot", "gallop"]
const TIDE_PHASES := ["alta", "bajando", "baja", "subiendo"]
const WORK_ACTIONS := ["muster", "resupply", "signal_liniers"]
const WORK_KIND := {"muster": "muster", "resupply": "resupply", "signal_liniers": "signal"}
const BLOCKED_KINDS := ["meseta", "barranca", "obstaculo", "casco"]

## Cache compartida (el mapa es de solo lectura y unico por proceso).
static var _S_loaded := false
static var _S_map: Dictionary = {}
static var _S_geo: Dictionary = {}
static var _S_static_ready := false
static var _S_real_h := PackedFloat32Array()
static var _S_cls := PackedByteArray()
static var _S_base_col := PackedFloat32Array()
static var _S_static_ms := 0.0

var state: Dictionary = {}
var _events: Array = []
var _navigation_revision := -999
# Resultado oculto de la partida: hoyos variantes que NO existen en el fondo de esta partida (se sortean con la semilla).
var _inactive: Dictionary = {}
var _real_h_inst := PackedFloat32Array()
var _real_h_ready := false

# Malla de rutas (por instancia: depende del nivel del rio y de lo que el jugador sabe).
var _nav: AStarGrid2D
var _nav_key := Vector2i(-1, -1)
var _nav_solid := PackedByteArray()
var _nav_wt := PackedFloat32Array()
var _nav_build_ms := 0.0
var _nav_builds := 0
# Conocimiento (sondas): segmentos indexados y trama por nodo.
var _seg_a := PackedVector2Array()
var _seg_b := PackedVector2Array()
var _seg_half := PackedFloat32Array()
var _seg_kind := PackedByteArray()
var _bucket: Dictionary = {}
var _know_r := PackedByteArray()
var _know_sig := -1

# ---------------------------------------------------------------------------
# Mapa (data/justina_map.json)

func map_data() -> Dictionary:
	if not _S_loaded:
		_load_map()
	return _S_map

static func _load_map() -> void:
	_S_loaded = true
	_S_map = {}
	_S_geo = {}
	var f := FileAccess.open(MAP_PATH, FileAccess.READ)
	if f == null:
		push_error("No se pudo abrir " + MAP_PATH)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not parsed is Dictionary:
		push_error("El mapa de Justina no es un JSON valido")
		return
	for key in ["id", "map_version", "size", "time", "tide", "movement", "shore_high", "barranca", "bed_profile", "banks", "channels", "fords", "hazards", "hull", "obstacles", "landmarks", "ship", "groups", "scouts", "resources", "knowledge", "actions", "texts", "camera", "minimap", "outcome", "play_targets", "source_tags"]:
		if not parsed.has(key):
			push_error("Mapa de Justina incompleto: falta " + key)
			return
	_S_map = parsed
	_build_geo()
	_S_static_ready = false

static func _vpoly(a: Array, swap: bool = false) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in a:
		out.append(Vector2(float(p[1]), float(p[0])) if swap else Vector2(float(p[0]), float(p[1])))
	return out

static func _interp(pts: PackedVector2Array, t: float) -> float:
	## Interpolacion lineal de una polilinea (x creciente = parametro, y = valor), con extremos fijos.
	var n := pts.size()
	if n == 0:
		return 0.0
	if t <= pts[0].x:
		return pts[0].y
	for i in range(1, n):
		if t <= pts[i].x:
			var span := pts[i].x - pts[i - 1].x
			return pts[i].y if span <= 0.0 else lerpf(pts[i - 1].y, pts[i].y, (t - pts[i - 1].x) / span)
	return pts[n - 1].y

static func _make_layer(mode: String, pts: PackedVector2Array, half: float, value: float, blend: float) -> Dictionary:
	var lo := pts[0]
	var hi := pts[0]
	for p in pts:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var reach := half + blend
	return {"mode": mode, "pts": pts, "half": half, "value": value, "blend": blend,
		"rect": Rect2(lo - Vector2(reach, reach), (hi - lo) + Vector2(reach, reach) * 2.0)}

static func _build_geo() -> void:
	var m := _S_map
	var b: Dictionary = m.barranca
	var crest_h := PackedVector2Array()
	for i in range(b.crest.size()):
		crest_h.append(Vector2(float(b.crest[i][1]), float(b.crest_height_m[i])))
	var layers: Array = []
	for bank in m.banks:
		layers.append(_make_layer("max", _vpoly(bank.centerline), float(bank.half_width_m), float(bank.top_m), float(bank.blend_m)))
	for ch in m.channels:
		layers.append(_make_layer("set", _vpoly(ch.centerline), float(ch.half_width_m), float(ch.bed_m), float(ch.blend_m)))
	## DESVIO del contrato 1.3.1: los vados se aplican en modo "set", no "max". Con "max", la cola del banco sur eleva el vado del
	## buque a -0,935 m (contradice la altura de referencia -1,0 m y la ventana 315..677 s); con "set" las siete alturas de referencia coinciden.
	for fd in m.fords:
		if fd.has("centerline"):
			layers.append(_make_layer("set", _vpoly(fd.centerline), float(fd.half_width_m), float(fd.top_m), float(fd.blend_m)))
		else:
			layers.append(_make_layer("set", PackedVector2Array([Vector2(float(fd.center[0]), float(fd.center[1]))]), float(fd.radius_m), float(fd.top_m), float(fd.blend_m)))
	for hz in m.hazards:
		var hl := _make_layer("set", PackedVector2Array([Vector2(float(hz.center[0]), float(hz.center[1]))]), float(hz.radius_m), float(hz.bed_m), BLEND_DEFAULT)
		hl["hid"] = str(hz.id)
		layers.append(hl)
	layers.append(_make_layer("set", PackedVector2Array([Vector2(float(m.hull.center[0]), float(m.hull.center[1]))]), float(m.hull.radius_m), float(m.hull.bed_m), BLEND_DEFAULT))
	var obstacles: Array = []
	for o in m.obstacles:
		var size := Vector2(float(o.w), float(o.d))
		obstacles.append(Rect2(Vector2(float(o.x), float(o.z)) - size * 0.5, size))
	_S_geo = {
		"crest": _vpoly(b.crest, true), "toe": _vpoly(b.toe, true), "crest_h": crest_h,
		"base": _vpoly(m.bed_profile.points_x_elev), "layers": layers, "obstacles": obstacles,
		"warp": _vpoly(m.get("bed_warp", {}).get("points_z_dx", [])), "warp_cfg": m.get("bed_warp", {}),
		"tilt": _vpoly(m.get("bed_warp", {}).get("tilt_z_dx", [])),
		"hull_c": Vector2(float(m.hull.center[0]), float(m.hull.center[1])), "hull_r": float(m.hull.radius_m),
		"ramps": [], "access": []
	}
	## Bajadas: banda en z sobre la pendiente de la barranca.
	for r in b.ramps:
		_S_geo.ramps.append({"cz": float(r.center[1]), "hw": float(r.width_m) * 0.5})
	## Accesos a la meseta: del borde superior de cada bajada al hito de trabajo mas cercano (ver docs/DISENO_REGLAS.md).
	var by_id := {}
	for lm in m.landmarks:
		by_id[str(lm.id)] = lm
	var seen := {}
	for act_id in ["muster", "resupply", "signal_liniers"]:
		var lm_id := str(m.actions[act_id].at)
		if seen.has(lm_id) or not by_id.has(lm_id):
			continue
		seen[lm_id] = true
		var c := Vector2(float(by_id[lm_id].x), float(by_id[lm_id].z))
		var best_ramp: Dictionary = _S_geo.ramps[0]
		var best_d := INF
		for ramp in _S_geo.ramps:
			var top := Vector2(_interp(_S_geo.crest, ramp.cz), ramp.cz)
			if top.distance_to(c) < best_d:
				best_d = top.distance_to(c)
				best_ramp = ramp
		_S_geo.access.append({"a": Vector2(_interp(_S_geo.crest, best_ramp.cz), best_ramp.cz), "b": c, "hw": best_ramp.hw})

func map_size() -> Vector2:
	var m := map_data()
	return Vector2(float(m.size.w), float(m.size.h)) if not m.is_empty() else Vector2.ZERO

func board_point() -> Vector2:
	var p: Array = map_data().ship.capture.boarding_point
	return Vector2(float(p[0]), float(p[1]))

func ship_position() -> Vector2:
	var s: Dictionary = map_data().ship
	return Vector2(float(s.x), float(s.z))

func _mv() -> Dictionary:
	return map_data().movement

func _horse_limit() -> float:
	return float(_mv().deep_water.horse_max_depth_m)

func _foot_limit() -> float:
	return float(_mv().deep_water.foot_max_depth_m)

func _limit_for(mounted: bool) -> float:
	return _horse_limit() if mounted else _foot_limit()

func new_game(scenario: String, seed_value: int = 1806) -> Dictionary:
	if scenario not in ["justine", "norte"]:
		scenario = "justine"
	state = {
		"schema_version": JUSTINE_SAVE_VERSION if scenario == "justine" else SAVE_VERSION, "game_id": _new_id(scenario), "state_version": 1,
		"scenario": scenario, "seed": seed_value, "rng_state": maxi(1, absi(seed_value) % 2147483647),
		"elapsed": 0.0, "accumulator": 0.0, "status": "playing", "reason": "", "round": 1,
		"units": [], "log": [], "orders": [], "external_decisions": [], "first_order_at": -1.0
	}
	_events = []
	_navigation_revision = -999
	_nav = null
	_nav_key = Vector2i(-1, -1)
	_know_sig = -1
	_inactive = {}
	_real_h_ready = false
	_clear_knowledge()
	if scenario == "justine":
		_setup_justine()
	else:
		_setup_norte()
	return state

func _new_id(scenario: String) -> String:
	return "%s-%d" % [scenario, Time.get_ticks_usec()]

func _unit(id: String, title: String, x: float, z: float, sector_id: String = "") -> Dictionary:
	return {"id": id, "name": title, "x": x, "z": z, "strength": 100.0, "fatigue": 0.0,
		"supply": 100.0, "mounted": true, "stage": "ready", "order": {}, "path": [],
		"sector_id": sector_id, "dismount_remaining": 0.0, "revealed_until": 0, "blocked_until": 0.0}

## Resultado oculto fijo por partida: elige UNA variante por grupo con la semilla (generador propio: no consume el flujo de azar del juego).
func _roll_hidden(seed_value: int) -> Dictionary:
	var picks := {}
	var x: int = (absi(seed_value) * 1103515245 + 12345) % 2147483648
	for grp in map_data().get("hidden_layout", {}).get("groups", []):
		for _k in range(5):
			x = (x * 1103515245 + 12345) % 2147483648
		var variants: Array = grp.variants
		picks[str(grp.id)] = str(variants[((x >> 13) ^ (x >> 21)) % variants.size()])
	## Ronda 3: condiciones del río de la partida (viento) sorteadas DESPUÉS de los grupos de hoyos, así los fondos de cada semilla no cambian.
	var tv: Array = map_data().get("time", {}).get("variants", [])
	var tide_id := "normal"
	if not tv.is_empty():
		var slots: Array = []
		for v in tv:
			for _w in range(maxi(1, int(v.get("weight", 1)))):
				slots.append(str(v.id))
		for _k in range(5):
			x = (x * 1103515245 + 12345) % 2147483648
		tide_id = str(slots[((x >> 13) ^ (x >> 21)) % slots.size()])
	return {"picks": picks, "tide": tide_id}

## Calcula los hoyos variantes inactivos a partir de lo elegido (state.hidden) y descarta la malla de alturas de la partida anterior.
func _apply_hidden() -> void:
	_inactive = {}
	_real_h_ready = false
	var picks: Dictionary = state.get("hidden", {}).get("picks", {})
	for hz in map_data().hazards:
		if hz.has("variant_group") and str(picks.get(str(hz.variant_group), "")) != str(hz.id):
			_inactive[str(hz.id)] = true

func hazard_active(id: String) -> bool:
	return not _inactive.has(id)

func _setup_justine() -> void:
	var m := map_data()
	if m.is_empty():
		push_error("Escenario Justina sin mapa")
		return
	state.hidden = _roll_hidden(int(state.seed))
	_apply_hidden()
	var units: Array = []
	var start_strength := {}
	for g in m.groups:
		var u := _unit(str(g.id), str(g.name), float(g.x), float(g.z))
		u.strength = float(g.strength)
		u.merge({"pace": "trot", "work": {}, "stumble_remaining": 0.0, "tag": str(g.tag), "wounded": 0.0, "evac_remaining": 0.0})
		units.append(u)
		start_strength[str(g.id)] = float(g.strength)
	state.units = units
	var scouts: Array = []
	for s in m.scouts:
		scouts.append({"id": str(s.id), "name": str(s.name), "x": float(s.x), "z": float(s.z), "hp": int(m.resources.scout_hp),
			"stage": "idle", "order": {}, "path": [], "work_remaining": 0.0, "cautious": false})
	var tide := tide_at(0.0)
	var res: Dictionary = m.resources
	state.merge({"map_id": str(m.id), "map_version": int(m.map_version),
		"water_level_m": tide.level_m, "water_level": tide.level_norm, "tide_phase": tide.phase,
		"capture": 0.0, "crew_morale": float(m.ship.crew.morale), "next_volley": float(m.ship.fire.volley_interval_s),
		"deadline": float(m.time.deadline_s), "bajante_announced": false, "rising_announced": false,
		"ammo": int(res.ammo_start), "ammo_max": int(res.ammo_max), "balizas": int(res.balizas_start), "volunteers_pool": float(res.volunteers_pool),
		"advance_authorized": false, "advance_until": -1.0, "fire_support": {"until": 0.0, "ready_at": 0.0},
		"ammo_reserve": int(res.ammo_reserve), "signals_left": int(res.signals_max),
		"counter": {"next_at": -1.0, "active": false, "until": 0.0, "answered": false, "count": 0},
		"probes": [], "scouts": scouts, "hazards_found": [], "fords_found": [], "defeat_cause": "",
		"stats": {"start_strength": start_strength, "shots_taken": 0, "damage_taken": 0.0, "stumbles": 0, "probe_m": 0.0, "marked_m": 0.0,
			"ammo_used": 0, "balizas_used": 0, "fire_support_uses": 0, "muster_gain": 0.0, "scouts_lost": 0, "horses_lost": 0.0, "melee_loss": 0.0, "drowned": 0.0,
			"counter_hits": 0, "counter_repelled": 0, "counter_loss": 0.0, "evacuations": 0, "wounded_recovered": 0.0, "halted_by_expiry": 0,
			"exposure_s": {"central": 0.0, "sur": 0.0, "otra": 0.0}, "bank_s": {"central": 0.0, "sur": 0.0},
			"stumble_at": {}, "boarded_at": -1.0, "level_at_boarding": -1.0, "first_water_entry_at": -1.0},
		"historical_note": str(m.texts.historical_note), "briefing": str(m.texts.briefing)})
	_event(str(m.texts.objective), "objective")

func _sector(id: String, title: String, x: float, z: float, neighbors: Array, known: bool, crates: int = 2) -> Dictionary:
	return {"id": id, "name": title, "x": x, "z": z, "neighbors": neighbors, "known": known,
		"intel_until": 0, "protected_until": 0, "crates": crates, "enemy": id in ["humahuaca", "quebrada", "oran"]}

func _setup_norte() -> void:
	state.sectors = [
		_sector("humahuaca", "Humahuaca", 5, -27, ["quebrada"], false, 1),
		_sector("quebrada", "Quebrada", -1, -21, ["humahuaca", "jujuy"], false, 1),
		_sector("jujuy", "Jujuy", 1, -13, ["quebrada", "salta", "oran", "lerma"], true, 2),
		_sector("salta", "Salta", 0, 8, ["jujuy", "lerma", "rosario"], true, 3),
		_sector("lerma", "Valle de Lerma", -7, 6, ["jujuy", "salta", "chicoana", "rosario"], true, 3),
		_sector("chicoana", "Chicoana", -9, 18, ["lerma", "rosario"], true, 3),
		_sector("oran", "Orán", 23, -12, ["jujuy"], false, 2),
		_sector("rosario", "Rosario de la Frontera", 8, 22, ["salta", "lerma", "chicoana"], true, 3)
	]
	state.units = [_unit("guemes", "Güemes", -7, 6, "lerma"), _unit("arias", "Manuel Eduardo Arias", 1, -13, "jujuy"), _unit("zavala", "Partida del valle", -9, 18, "chicoana")]
	state.merge({"enemy": {"supply": 88.0, "cohesion": 88.0, "communications": 90.0,
		"position": "quebrada", "occupied_salta": false, "intent": "forage"}, "population": 82.0,
		"stores": 65.0, "humahuaca": false, "pressure_actions": 0, "date": DATES[0], "last_results": [],
		"historical_note": "Campaña de 1816–1817. Las agrupaciones, rutas y cifras son una abstracción. Humahuaca se atribuye a Arias. El desenlace histórico fue la retirada realista a comienzos de mayo; tus resultados pueden producir otra cronología."})
	_event("Sostené a la población y cortá los abastecimientos. Ocupar Salta no decide por sí solo la campaña.", "objective")

func get_unit(id: String) -> Dictionary:
	for u in state.get("units", []):
		if u.id == id:
			return u
	return {}

func get_scout(id: String) -> Dictionary:
	for s in state.get("scouts", []):
		if s.id == id:
			return s
	return {}

func get_sector(id: String) -> Dictionary:
	for s in state.get("sectors", []):
		if s.id == id:
			return s
	return {}

# ---------------------------------------------------------------------------
# Terreno real (una sola implementacion; la Vista la llama)

func terrain_height_at(x: float, z: float) -> float:
	if map_data().is_empty():
		return 0.0
	var g := _S_geo
	var m := _S_map
	var cx := _interp(g.crest, z)
	if x <= cx:
		return _interp(g.crest_h, z)
	var tx := _interp(g.toe, z)
	if x < tx:
		return lerpf(_interp(g.crest_h, z), float(m.barranca.toe_elevation_m), smoothstep(0.0, 1.0, (x - cx) / (tx - cx)))
	var e := _interp(g.base, x - _bed_warp(x, z, tx) - _bed_tilt(x, z))
	var p := Vector2(x, z)
	for layer in g.layers:
		if not layer.rect.has_point(p):
			continue
		if not _inactive.is_empty() and layer.has("hid") and _inactive.has(layer.hid):
			continue
		var pts: PackedVector2Array = layer.pts
		var d := INF
		if pts.size() == 1:
			d = p.distance_to(pts[0])
		else:
			for i in range(pts.size() - 1):
				d = minf(d, p.distance_to(Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])))
		var w := 1.0 - smoothstep(layer.half, layer.half + layer.blend, d)
		if w <= 0.0:
			continue
		if layer.mode == "max":
			if layer.value > e:
				e = lerpf(e, layer.value, w)
		else:
			e = lerpf(e, layer.value, w)
	return e

## Desplazamiento (m) en x del perfil de fondo: meandros y bahías de la playa baja (data bed_warp, Diseño). Cero al pie de la barranca y mar adentro,
## para que el terreno quede continuo; solo mueve las curvas de nivel de la franja húmeda.
func _bed_warp(x: float, z: float, toe_x: float) -> float:
	var w: PackedVector2Array = _S_geo.warp
	if w.is_empty():
		return 0.0
	var c: Dictionary = _S_geo.warp_cfg
	var fin := smoothstep(toe_x + float(c.fade_in_from_toe_m), toe_x + float(c.fade_in_from_toe_m) + float(c.fade_in_len_m), x)
	var fout := 1.0 - smoothstep(float(c.fade_out_from_x), float(c.fade_out_to_x), x)
	return _interp(w, z) * fin * fout

## Inclinacion NO-SE de la costa (Ronda 4, data bed_warp.tilt_z_dx): corre todo el perfil de la playa en x segun z; el pie de la barranca ya viene
## desplazado igual en el JSON (toe), asi que el terreno es continuo. Se desvanece mar adentro con el mismo fade_out que los meandros.
func _bed_tilt(x: float, z: float) -> float:
	var w: PackedVector2Array = _S_geo.get("tilt", PackedVector2Array())
	if w.is_empty():
		return 0.0
	var c: Dictionary = _S_geo.warp_cfg
	return _interp(w, z) * (1.0 - smoothstep(float(c.fade_out_from_x), float(c.fade_out_to_x), x))

func _interp_crest(z: float) -> float:
	return _interp(_S_geo.crest, z)

func _base_height(x: float) -> float:
	return _interp(_S_geo.base, x)

func water_level_m() -> float:
	if state.has("water_level_m"):
		return float(state.water_level_m)
	var m := map_data()
	return float(m.tide.level_high_m) if not m.is_empty() else 0.0

func water_depth_at(x: float, z: float) -> float:
	return water_level_m() - terrain_height_at(x, z)

func _toe_x(z: float) -> float:
	return _interp(_S_geo.toe, z)

func _in_access(p: Vector2) -> bool:
	for a in _S_geo.access:
		if p.distance_to(Geometry2D.get_closest_point_to_segment(p, a.a, a.b)) <= a.hw:
			return true
	return false

func _in_ramp_band(z: float) -> bool:
	for r in _S_geo.ramps:
		if absf(z - r.cz) <= r.hw:
			return true
	return false

func _land_kind(x: float, z: float, margin: float) -> String:
	## "" si el punto es zona de agua/playa (la altura decide); si no, el tipo de suelo que no depende del nivel del rio.
	var m := _S_map
	if x < 0.0 or x > float(m.size.w) or z < 0.0 or z > float(m.size.h):
		return "obstaculo"
	var p := Vector2(x, z)
	for o in _S_geo.obstacles:
		if (o as Rect2).grow(margin).has_point(p):
			return "obstaculo"
	if p.distance_to(_S_geo.hull_c) <= _S_geo.hull_r + margin:
		return "casco"
	var cx := _interp(_S_geo.crest, z)
	if x <= cx:
		return "bajada" if _in_access(p) else "meseta"
	if x < _interp(_S_geo.toe, z):
		return "bajada" if _in_ramp_band(z) else "barranca"
	return ""

func terrain_kind_at(x: float, z: float) -> String:
	if map_data().is_empty():
		return "obstaculo"
	var lk := _land_kind(x, z, 0.0)
	if lk != "":
		return lk
	var d := water_depth_at(x, z)
	if d <= 0.0:
		return "firme" if -d >= float(_mv().mud.firm_min_height_m) else "barro"
	if d <= float(_mv().shallow_water.max_depth_m):
		return "somera"
	return "agua" if d <= _horse_limit() else "honda"

## Velocidad por tipo de suelo; `kind` es "bajada", un tipo bloqueado o "" (agua/playa decidida por la profundidad d).
func _speed_core(kind: String, d: float, pace: String, mounted: bool, lane: bool) -> float:
	if kind in BLOCKED_KINDS:
		return 0.0
	var mv := _mv()
	var paces: Dictionary = mv.paces_mps
	var v := float(paces.get(pace, paces.trot))
	var trot := float(paces.trot)
	if not mounted:
		v = minf(v, float(paces.walk))
	if kind == "bajada":
		return minf(v, trot) * float(mv.ramp_speed_factor)
	var out := 0.0
	if d <= 0.0:
		var h := -d
		var firm := float(mv.mud.firm_min_height_m)
		if h >= firm:
			out = v
		else:
			out = minf(minf(v, trot), lerpf(float(mv.mud.speed_at_waterline_mps), float(mv.mud.speed_at_top_mps), h / firm))
	elif d <= float(mv.shallow_water.max_depth_m):
		out = minf(minf(v, trot), float(mv.shallow_water.horse_mps) if mounted else float(mv.shallow_water.foot_mps))
	elif d <= _limit_for(mounted):
		out = minf(minf(v, trot), float(mv.deep_water.speed_mps))
	else:
		return 0.0
	if lane:
		out *= float(mv.column_unmarked_lane_factor)
	return out

func speed_at(x: float, z: float, pace: String, mounted: bool) -> float:
	if map_data().is_empty():
		return 0.0
	var lk := _land_kind(x, z, 0.0)
	if lk != "":
		return _speed_core(lk, 0.0, pace, mounted, false)
	var d := water_depth_at(x, z)
	var lane := d > float(map_data().knowledge.visibility_depth_m) and _probe_kind_at(x, z) == 1
	return _speed_core("", d, pace, mounted, lane)

func is_walkable(x: float, z: float, mounted: bool = true) -> bool:
	if not is_finite(x) or not is_finite(z) or map_data().is_empty():
		return false
	return speed_at(x, z, "walk", mounted) > 0.0

# ---------------------------------------------------------------------------
# Tiempo y rio

## Variante de río de esta partida (viento): corre los cuatro hitos del descenso/subida. "normal" = los valores base de time.
var _tide_override := ""  ## solo al validar un guardado ajeno: usa SU condición del río, no la de la partida en curso

func tide_variant_id() -> String:
	var id := _tide_override if _tide_override != "" else str(state.get("hidden", {}).get("tide", "normal"))
	for v in map_data().get("time", {}).get("variants", []):
		if str(v.id) == id:
			return id
	return "normal"

func _time_cfg() -> Dictionary:
	var base: Dictionary = map_data().time
	var id := tide_variant_id()
	if id == "normal":
		return base
	for v in base.get("variants", []):
		if str(v.id) == id:
			var out: Dictionary = base.duplicate()
			for k in ["drop_start_s", "drop_end_s", "low_hold_end_s", "rise_end_s"]:
				out[k] = float(v.get(k, base[k]))
			return out
	return base

func tide_at(t: float) -> Dictionary:
	var m := map_data()
	var tm: Dictionary = _time_cfg()
	var hi := float(m.tide.level_high_m)
	var lo := float(m.tide.level_low_m)
	var lvl := hi
	var phase := "alta"
	if t < float(tm.drop_start_s):
		lvl = hi
	elif t < float(tm.drop_end_s):
		lvl = lerpf(hi, lo, (t - float(tm.drop_start_s)) / (float(tm.drop_end_s) - float(tm.drop_start_s)))
		phase = "bajando"
	elif t < float(tm.low_hold_end_s):
		lvl = lo
		phase = "baja"
	else:
		lvl = lerpf(lo, hi, clampf((t - float(tm.low_hold_end_s)) / (float(tm.rise_end_s) - float(tm.low_hold_end_s)), 0.0, 1.0))
		phase = "subiendo"
	var norm: Dictionary = m.tide.legacy_normalized
	return {"level_m": lvl, "level_norm": float(norm.low) + (float(norm.high) - float(norm.low)) * (lvl - lo) / (hi - lo), "phase": phase}

func tide_marks() -> Dictionary:
	var tm: Dictionary = _time_cfg()
	return {"drop_start": float(tm.drop_start_s), "drop_end": float(tm.drop_end_s), "low_hold_end": float(tm.low_hold_end_s),
		"rise_end": float(tm.rise_end_s), "deadline": float(tm.deadline_s)}

func ford_window(x: float, z: float, mounted: bool = true) -> Dictionary:
	var m := map_data()
	var certain := knowledge_at(x, z) != "unknown"
	var h := terrain_height_at(x, z) if certain else perceived_height_at(x, z)
	var thr := h + _limit_for(mounted)
	var tm: Dictionary = _time_cfg()
	var hi := float(m.tide.level_high_m)
	var lo := float(m.tide.level_low_m)
	var opens := -1.0
	var closes := -1.0
	if thr >= hi:
		opens = 0.0
		closes = float(tm.deadline_s)
	elif thr >= lo:
		var f_down := (hi - thr) / (hi - lo)
		var f_up := (thr - lo) / (hi - lo)
		opens = float(tm.drop_start_s) + f_down * (float(tm.drop_end_s) - float(tm.drop_start_s))
		closes = float(tm.low_hold_end_s) + f_up * (float(tm.rise_end_s) - float(tm.low_hold_end_s))
	return {"known": certain, "certain": certain, "opens_at": opens, "closes_at": closes, "depth_at_low_m": lo - h}

# ---------------------------------------------------------------------------
# Conocimiento: sondas, trama y percepcion

func _clear_knowledge() -> void:
	_seg_a = PackedVector2Array()
	_seg_b = PackedVector2Array()
	_seg_half = PackedFloat32Array()
	_seg_kind = PackedByteArray()
	_bucket = {}
	_know_r = PackedByteArray()
	_know_r.resize(NX * NZ)
	_know_r.fill(0)

func _calc_sig() -> int:
	var pts := 0
	for p in state.get("probes", []):
		pts += (p.pts as Array).size()
	return state.get("probes", []).size() * 1000003 + pts * 31 + state.get("hazards_found", []).size() * 7 + state.get("fords_found", []).size() * 13 + 1

## Reconstruye el indice si el estado de las sondas cambio por fuera (carga, pruebas).
func _know_sync() -> void:
	if state.get("scenario", "") != "justine":
		return
	var sig := _calc_sig()
	if sig == _know_sig:
		return
	_clear_knowledge()
	for p in state.probes:
		var pts: Array = p.pts
		var half := float(p.width) * 0.5
		var kind := 2 if p.kind == "marked" else 1
		if pts.size() == 1:
			_seg_register(Vector2(pts[0].x, pts[0].z), Vector2(pts[0].x, pts[0].z), half, kind)
		for i in range(1, pts.size()):
			_seg_register(Vector2(pts[i - 1].x, pts[i - 1].z), Vector2(pts[i].x, pts[i].z), half, kind)
	## Solo para el planificador: un pozo o vado descubierto se conoce entero (su fondo real), aunque la sonda solo lo haya rozado.
	for id in state.hazards_found:
		_stamp_hazard(str(id))
	for id in state.fords_found:
		_stamp_ford(str(id))
	_know_sig = sig

func _stamp_ford(id: String) -> void:
	for fd in map_data().fords:
		if str(fd.id) == id:
			if fd.has("centerline"):
				var pts := _vpoly(fd.centerline)
				_stamp(pts[0], pts[1], float(fd.half_width_m) + float(fd.blend_m), 3)
			else:
				var c := Vector2(float(fd.center[0]), float(fd.center[1]))
				_stamp(c, c, float(fd.radius_m) + float(fd.blend_m), 3)

func _stamp_hazard(id: String) -> void:
	for hz in map_data().hazards:
		if str(hz.id) == id:
			var c := Vector2(float(hz.center[0]), float(hz.center[1]))
			var reach := float(hz.radius_m) + BLEND_DEFAULT
			_stamp(c, c, reach, 3)

func _stamp(a: Vector2, b: Vector2, half: float, kind: int) -> void:
	var lo := Vector2(minf(a.x, b.x) - half, minf(a.y, b.y) - half)
	var hi := Vector2(maxf(a.x, b.x) + half, maxf(a.y, b.y) + half)
	for j in range(maxi(0, ceili(lo.y / CELL)), mini(NZ - 1, floori(hi.y / CELL)) + 1):
		for i in range(maxi(0, ceili(lo.x / CELL)), mini(NX - 1, floori(hi.x / CELL)) + 1):
			var p := Vector2(i * CELL, j * CELL)
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)) <= half + 0.000001:
				var idx := j * NX + i
				if kind > _know_r[idx]:
					_know_r[idx] = kind

func _seg_register(a: Vector2, b: Vector2, half: float, kind: int) -> void:
	_seg_a.append(a)
	_seg_b.append(b)
	_seg_half.append(half)
	_seg_kind.append(kind)
	var idx := _seg_a.size() - 1
	var lo := Vector2(minf(a.x, b.x) - half, minf(a.y, b.y) - half)
	var hi := Vector2(maxf(a.x, b.x) + half, maxf(a.y, b.y) + half)
	for ix in range(maxi(0, floori(lo.x / BUCKET)), floori(hi.x / BUCKET) + 1):
		for iz in range(maxi(0, floori(lo.y / BUCKET)), floori(hi.y / BUCKET) + 1):
			var key := ix + iz * 64
			if not _bucket.has(key):
				_bucket[key] = []
			_bucket[key].append(idx)
	_stamp(a, b, half, kind)

## 0 = ninguna, 1 = lane, 2 = marked (ignora lo emergido).
func _probe_kind_at(x: float, z: float) -> int:
	_know_sync()
	if _seg_a.is_empty():
		return 0
	var key := floori(x / BUCKET) + floori(z / BUCKET) * 64
	if not _bucket.has(key):
		return 0
	var p := Vector2(x, z)
	var best := 0
	for idx in _bucket[key]:
		var k: int = _seg_kind[idx]
		if k <= best:
			continue
		if p.distance_to(Geometry2D.get_closest_point_to_segment(p, _seg_a[idx], _seg_b[idx])) <= _seg_half[idx] + 0.000001:
			best = k
	return best

func knowledge_at(x: float, z: float) -> String:
	if map_data().is_empty():
		return "unknown"
	if x < _toe_x(z):
		return "visible"
	if water_depth_at(x, z) <= float(map_data().knowledge.visibility_depth_m):
		return "visible"
	var k := _probe_kind_at(x, z)
	return "marked" if k == 2 else ("probed" if k == 1 else "unknown")

func perceived_height_at(x: float, z: float) -> float:
	if knowledge_at(x, z) != "unknown":
		return terrain_height_at(x, z)
	return _base_height(x) + float(map_data().knowledge.unknown_optimism_m)

func perceived_depth_at(x: float, z: float) -> float:
	return water_level_m() - perceived_height_at(x, z)

## Velocidad que el jugador cree tener en un punto en el instante t (planificacion).
func _perceived_speed(p: Vector2, t: float, pace: String, mounted: bool) -> Dictionary:
	var lk := _land_kind(p.x, p.y, 0.0)
	if lk != "":
		return {"v": _speed_core(lk, 0.0, pace, mounted, false), "d": -9.0, "known": true}
	var level := float(tide_at(t).level_m)
	var kn := knowledge_at(p.x, p.y)
	var h := terrain_height_at(p.x, p.y) if kn != "unknown" else _base_height(p.x) + float(map_data().knowledge.unknown_optimism_m)
	var d := level - h
	return {"v": _speed_core("", d, pace, mounted, kn == "probed"), "d": d, "known": kn != "unknown"}

# ---------------------------------------------------------------------------
# Fuego del buque

func _ship_range() -> float:
	return float(map_data().ship.fire.range_m)

func exposure_at(x: float, z: float) -> float:
	var m := map_data()
	if m.is_empty():
		return 0.0
	var sp := ship_position()
	var v := Vector2(x, z) - sp
	if v.length() > _ship_range():
		return 0.0
	var heading := deg_to_rad(float(m.ship.heading_deg))
	var beam := Vector2(cos(heading), sin(heading))
	var angle := 0.0 if v.length() < 0.001 else rad_to_deg(acos(clampf(absf(v.dot(beam)) / v.length(), 0.0, 1.0)))
	var arc: Dictionary = m.ship.fire.arc_factors
	var f := float(arc.chaser)
	if angle <= float(arc.broadside_half_deg):
		f = float(arc.broadside)
	elif angle <= float(arc.quarter_half_deg):
		f = float(arc.quarter)
	if _fire_support_active():
		f *= float(m.actions.distract_fire.exposure_mult)
	return f

func _fire_support_active() -> bool:
	return state.has("fire_support") and float(state.get("elapsed", 0.0)) < float(state.fire_support.until)

func exposure_for(u: Dictionary) -> float:
	if float(u.strength) <= float(map_data().outcome.routed_strength_threshold):
		return 0.0
	var e := exposure_at(float(u.x), float(u.z))
	if u.stage in ["boarding", "dismounting"]:
		e *= float(map_data().ship.capture.get("boarding_exposure_mult", BOARDING_EXPOSURE_MULT))
	return e


# ---------------------------------------------------------------------------
# Malla de rutas (A* sobre celdas de 4 m) y planificacion con el conocimiento del jugador

func _ensure_static() -> void:
	if _S_static_ready:
		return
	var t0 := Time.get_ticks_usec()
	var n := NX * NZ
	_S_real_h = PackedFloat32Array()
	_S_real_h.resize(n)
	_S_cls = PackedByteArray()
	_S_cls.resize(n)
	_S_base_col = PackedFloat32Array()
	_S_base_col.resize(NX)
	for i in range(NX):
		_S_base_col[i] = _base_height(i * CELL)
	var keep_inactive := _inactive
	_inactive = {}  ## la malla estatica se hornea con TODAS las variantes; cada partida corrige las suyas (_real_heights)
	for j in range(NZ):
		for i in range(NX):
			var x := i * CELL
			var z := j * CELL
			var idx := j * NX + i
			_S_real_h[idx] = terrain_height_at(x, z)
			var lk := _land_kind(x, z, CELL)
			_S_cls[idx] = 0 if lk == "" else (2 if lk == "bajada" else 1)
	_inactive = keep_inactive
	_S_static_ready = true
	_S_static_ms = float(Time.get_ticks_usec() - t0) / 1000.0

## Alturas reales de la malla para ESTA partida: la malla estatica con los hoyos variantes inactivos recalculados.
func _real_heights() -> PackedFloat32Array:
	if _inactive.is_empty():
		return _S_real_h
	if _real_h_ready:
		return _real_h_inst
	_real_h_inst = _S_real_h.duplicate()
	for hz in map_data().hazards:
		if not _inactive.has(str(hz.id)):
			continue
		var c := Vector2(float(hz.center[0]), float(hz.center[1]))
		var reach := float(hz.radius_m) + BLEND_DEFAULT + CELL
		for j in range(maxi(0, floori((c.y - reach) / CELL)), mini(NZ - 1, ceili((c.y + reach) / CELL)) + 1):
			for i in range(maxi(0, floori((c.x - reach) / CELL)), mini(NX - 1, ceili((c.x + reach) / CELL)) + 1):
				_real_h_inst[j * NX + i] = terrain_height_at(i * CELL, j * CELL)
	_real_h_ready = true
	return _real_h_inst

func _ensure_nav() -> void:
	_ensure_static()
	_know_sync()
	var level := water_level_m()
	var key := Vector2i(roundi(level / NAV_LEVEL_QUANT), _know_sig)
	if _nav != null and key == _nav_key:
		return
	var t0 := Time.get_ticks_usec()
	var mv := _mv()
	var trot := float(mv.paces_mps.trot)
	var ramp_w := 1.0 / float(mv.ramp_speed_factor)
	var vis := float(map_data().knowledge.visibility_depth_m)
	var opt := float(map_data().knowledge.unknown_optimism_m)
	var firm := float(mv.mud.firm_min_height_m)
	var v_wl := float(mv.mud.speed_at_waterline_mps)
	var v_top := float(mv.mud.speed_at_top_mps)
	var shallow := float(mv.shallow_water.max_depth_m)
	var v_shallow := minf(trot, float(mv.shallow_water.horse_mps))
	var v_deep := minf(trot, float(mv.deep_water.speed_mps))
	var limit := _horse_limit()
	var real_h := _real_heights()
	var known_w := 0.8  ## contrato 1.5: lo reconocido cuesta x0,8 frente a lo desconocido
	if _nav == null:
		_nav = AStarGrid2D.new()
		_nav.region = Rect2i(0, 0, NX, NZ)
		_nav.cell_size = Vector2(1, 1)
		_nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		_nav.default_compute_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
		_nav.default_estimate_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
		_nav.update()
		_nav_solid = PackedByteArray()
		_nav_solid.resize(NX * NZ)
		_nav_solid.fill(0)
		_nav_wt = PackedFloat32Array()
		_nav_wt.resize(NX * NZ)
		_nav_wt.fill(1.0)
	for j in range(NZ):
		for i in range(NX):
			var idx := j * NX + i
			var cls: int = _S_cls[idx]
			var solid := 0
			var w := 1.0
			if cls == 1:
				solid = 1
			elif cls == 2:
				w = ramp_w
			else:
				var hr: float = real_h[idx]
				var known := (level - hr) <= vis or _know_r[idx] != 0
				var d := level - (hr if known else _S_base_col[i] + opt)
				if d > limit:
					solid = 1
				else:
					var v := trot
					if d <= 0.0:
						if -d < firm:
							v = minf(trot, lerpf(v_wl, v_top, -d / firm))
					elif d <= shallow:
						v = v_shallow
					else:
						v = v_deep
					w = trot / v
					if known and d > 0.0:
						w *= known_w
			if solid != _nav_solid[idx]:
				_nav.set_point_solid(Vector2i(i, j), solid == 1)
				_nav_solid[idx] = solid
			if absf(w - _nav_wt[idx]) > 0.0001:
				_nav.set_point_weight_scale(Vector2i(i, j), w)
				_nav_wt[idx] = w
	_nav_key = key
	_nav_builds += 1
	_nav_build_ms = float(Time.get_ticks_usec() - t0) / 1000.0

func _cell_of(p: Vector2) -> Vector2i:
	return Vector2i(clampi(roundi(p.x / CELL), 0, NX - 1), clampi(roundi(p.y / CELL), 0, NZ - 1))

func _cell_solid(c: Vector2i) -> bool:
	return _nav_solid[c.y * NX + c.x] == 1

func _nearest_free_cell(c: Vector2i, radius: int) -> Vector2i:
	if not _cell_solid(c):
		return c
	var best := Vector2i(-1, -1)
	var best_d := INF
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var q := Vector2i(c.x + dx, c.y + dy)
			if q.x < 0 or q.y < 0 or q.x >= NX or q.y >= NZ or _cell_solid(q):
				continue
			var d := float(dx * dx + dy * dy)
			if d < best_d:
				best_d = d
				best = q
	return best

func _line_clear(a: Vector2, b: Vector2) -> bool:
	var dist := a.distance_to(b)
	var steps := maxi(1, ceili(dist / (CELL * 0.5)))
	for k in range(1, steps + 1):
		var p := a.lerp(b, float(k) / float(steps))
		if _land_kind(p.x, p.y, 0.0) not in ["", "bajada"]:
			return false
		if _cell_solid(_cell_of(p)):
			return false
	return true

## Ruta suavizada con el conocimiento actual. {"ok", "reason", "pts": Array[Vector2]} (sin el punto de partida).
func _plan_points(from: Vector2, to: Vector2) -> Dictionary:
	_ensure_nav()
	if from.distance_to(to) < 0.5:
		return {"ok": true, "reason": "", "pts": []}
	var s := _nearest_free_cell(_cell_of(from), 3)
	if s.x < 0:
		return {"ok": false, "reason": "El punto de partida no tiene salida transitable con el nivel actual del río.", "pts": []}
	var gcell := _cell_of(to)
	var g := _nearest_free_cell(gcell, 2)
	if g.x < 0:
		return {"ok": false, "reason": "No hay un punto transitable cerca del destino con el nivel actual del río.", "pts": []}
	var ids: Array[Vector2i] = _nav.get_id_path(s, g)
	if ids.is_empty():
		return {"ok": false, "reason": "No hay una ruta transitable hasta ese punto con el nivel actual del río.", "pts": []}
	var end := to
	if g != gcell or _cell_solid(gcell):
		end = Vector2(g.x * CELL, g.y * CELL)
	var raw: Array = [from]
	for i in range(1, ids.size() - 1):
		raw.append(Vector2(ids[i].x * CELL, ids[i].y * CELL))
	raw.append(end)
	## Costo acumulado de la ruta cruda (metros x peso de la celda de llegada): un atajo solo se acepta si no sale mas caro,
	## asi la ruta no abandona los carriles reconocidos (mas baratos) para cortar por fondo desconocido.
	var acc: Array = [0.0]
	for k in range(1, raw.size()):
		acc.append(float(acc[k - 1]) + (raw[k - 1] as Vector2).distance_to(raw[k]) * float(_nav_wt[_cell_of(raw[k]).y * NX + _cell_of(raw[k]).x]))
	var out: Array = []
	var i := 0
	while i < raw.size() - 1:
		var j: int = raw.size() - 1
		while j > i + 1 and not (_line_clear(raw[i], raw[j]) and _line_cost(raw[i], raw[j]) <= float(acc[j]) - float(acc[i]) + CELL * 0.5):
			j -= 1
		out.append(raw[j])
		i = j
	return {"ok": true, "reason": "", "pts": out}

func _line_cost(a: Vector2, b: Vector2) -> float:
	var dist := a.distance_to(b)
	var steps := maxi(1, ceili(dist / (CELL * 0.5)))
	var sub := dist / float(steps)
	var cost := 0.0
	for k in range(1, steps + 1):
		var c := _cell_of(a.lerp(b, float(k) / float(steps)))
		cost += sub * float(_nav_wt[c.y * NX + c.x])
	return cost

func _path_dicts(pts: Array) -> Array:
	var out: Array = []
	for p in pts:
		out.append({"x": p.x, "z": p.y})
	return out

func _in_map(p: Vector2) -> bool:
	var sz := map_size()
	return is_finite(p.x) and is_finite(p.y) and p.x >= 0.0 and p.y >= 0.0 and p.x <= sz.x and p.y <= sz.y

func _target_reject(p: Vector2, mounted: bool) -> String:
	## Motivo concreto por el que un destino no sirve (con lo que el jugador sabe), o "".
	if not _in_map(p):
		return "El destino está fuera del mapa."
	var lk := _land_kind(p.x, p.y, 0.0)
	match lk:
		"obstaculo":
			return "Hay un obstáculo (cañaveral o carretas) en ese punto."
		"casco":
			return "Ahí está el casco del buque."
		"meseta", "barranca":
			return "La barranca solo se sube por las dos bajadas; ese punto no es transitable."
	var kn := knowledge_at(p.x, p.y)
	var limit := _limit_for(mounted)
	if kn != "unknown":
		var d := water_depth_at(p.x, p.y)
		if d > limit:
			return "Agua demasiado honda en ese punto (%.1f m, el límite es %.1f m)." % [d, limit]
	elif perceived_depth_at(p.x, p.y) > limit:
		return "El fondo estimado en ese punto supera el límite de %.1f m." % limit
	return ""

func plan_route(group_id: String, target: Vector2, pace: String = "trot", opts: Dictionary = {}) -> Dictionary:
	var empty := {"ok": false, "reason": "", "path": [], "length_m": 0.0, "eta_s": 0.0, "unknown_m": 0.0, "exposed_s": 0.0,
		"max_depth_m": 0.0, "arrives_in_window": false, "risk": "desconocido", "warnings": []}
	if state.get("scenario", "") != "justine" or map_data().is_empty():
		empty.reason = "La planificación de rutas solo existe en Justina."
		return empty
	var u := get_unit(group_id)
	if u.is_empty():
		empty.reason = "Agrupación desconocida."
		return empty
	if pace not in PACES:
		pace = "trot"
	var mounted: bool = u.mounted
	if not mounted:
		pace = "walk"
	var waypoints: Array = opts.get("waypoints", [])
	if waypoints.size() > 4:
		empty.reason = "Hasta 4 puntos intermedios."
		return empty
	var legs: Array = []
	for w in waypoints:
		legs.append(w as Vector2)
	legs.append(target)
	var start := Vector2(u.x, u.z)
	var pts: Array = []
	var from := start
	for k in range(legs.size()):
		var to: Vector2 = legs[k]
		var rej := _target_reject(to, mounted)
		if rej != "":
			empty.reason = rej if legs.size() == 1 else ("Tramo %d: %s" % [k + 1, rej])
			return empty
		var leg := _plan_points(from, to)
		if not leg.ok:
			empty.reason = leg.reason if legs.size() == 1 else ("Tramo %d: %s" % [k + 1, leg.reason])
			return empty
		pts.append_array(leg.pts)
		from = to if leg.pts.is_empty() else leg.pts[leg.pts.size() - 1]
	var res := _estimate_route(start, pts, pace, mounted, float(u.fatigue))
	res.ok = true
	res.reason = "Ruta calculada."
	res.path = _path_dicts(pts)
	var dest: Vector2 = start if pts.is_empty() else pts[pts.size() - 1]
	var dest_p := _perceived_speed(dest, float(state.elapsed), pace, mounted)
	var dest_unknown_water: bool = (not dest_p.known) and float(dest_p.d) > 0.0
	var limit := _limit_for(mounted)
	if float(res.unknown_m) > 80.0:
		res.risk = "alto"
	elif float(res.unknown_m) <= 0.0 and float(res.max_depth_m) <= 0.6 * limit:
		res.risk = "bajo"
	elif dest_unknown_water:
		res.risk = "desconocido"
	else:
		res.risk = "medio"
	if float(res.unknown_m) > 0.0:
		res.warnings.append("%d m de agua sin reconocer: el fondo real puede ser distinto." % roundi(res.unknown_m))
	if float(res.max_depth_m) > 0.6 * limit:
		res.warnings.append("Profundidad estimada de hasta %.1f m (el caballo no pasa de %.1f m)." % [res.max_depth_m, limit])
	if not res.arrives_in_window:
		res.warnings.append("Con este ritmo no llegaría al vado del buque dentro de su ventana abierta.")
	if pace == "gallop":
		res.warnings.append("El galope solo vale en terreno firme; en barro y agua se limita al trote.")
	if dest.distance_to(board_point()) <= float(map_data().ship.capture.boarding_radius_m) and bool(state.get("advance_authorized", false)) and float(state.get("advance_until", -1.0)) >= 0.0:
		var left := float(state.advance_until) - float(state.elapsed)
		if float(res.eta_s) > left:
			res.warnings.append("La orden de avance de Liniers vence en %d s y la marcha lleva ≈ %d s: el grupo se detendría antes de llegar." % [roundi(left), roundi(res.eta_s)])
	return res

## Integra la ruta paso a paso con las velocidades PERCIBIDAS en el nivel de cada instante estimado.
func _estimate_route(start: Vector2, pts: Array, pace: String, mounted: bool, fatigue: float) -> Dictionary:
	var fat := 1.0  ## el cansancio no frena la marcha (contrato 1.3.3: la velocidad sale solo del terreno); solo resta poder de abordaje
	var t := float(state.elapsed)
	var t0 := t
	var length := 0.0
	var unknown := 0.0
	var exposed := 0.0
	var max_depth := -9.0
	var closes := false
	var prev := start
	for target in pts:
		var seg: float = prev.distance_to(target)
		var n := maxi(1, ceili(seg / CELL))
		var sub := seg / float(n)
		for k in range(n):
			var p: Vector2 = prev.lerp(target, (float(k) + 0.5) / float(n))
			var info := _perceived_speed(p, t, pace, mounted)
			var v := float(info.v) * fat
			if v <= 0.05:
				closes = true
				v = 0.3
			var dt := sub / v
			if not bool(info.known) and float(info.d) > 0.0:
				unknown += sub
			if float(info.d) > max_depth:
				max_depth = float(info.d)
			exposed += exposure_at(p.x, p.y) * dt
			t += dt
			length += sub
		prev = target
	var bp := board_point()
	var win := ford_window(bp.x, bp.y, mounted)
	var arrive := t
	var in_window: bool = float(win.opens_at) >= 0.0 and arrive >= float(win.opens_at) and arrive <= float(win.closes_at) and not closes
	var warnings: Array = []
	if closes:
		warnings.append("Parte de la ruta quedaría cubierta por el agua antes de llegar.")
	return {"length_m": length, "eta_s": t - t0, "unknown_m": unknown, "exposed_s": exposed, "max_depth_m": maxf(max_depth, 0.0) if max_depth > -9.0 else 0.0,
		"arrives_in_window": in_window, "warnings": warnings}

## Instrumentacion para el informe de rendimiento de las pruebas.
func nav_stats() -> Dictionary:
	return {"build_ms": _nav_build_ms, "builds": _nav_builds, "static_ms": _S_static_ms}

func rebuild_navigation() -> void:
	_nav_key = Vector2i(-1, -1)
	_ensure_nav()


# ---------------------------------------------------------------------------
# Ordenes de grupo

func _shore_x(z: float) -> float:
	## x de la linea de agua inicial (shore_high) a la altura z.
	var pts := PackedVector2Array()
	for p in map_data().shore_high.polyline:
		pts.append(Vector2(float(p[1]), float(p[0])))
	return _interp(pts, z)

func _beach_margin() -> float:
	return BEACH_MARGIN_M

func _on_dry_beach(p: Vector2) -> bool:
	## Playa seca: x <= shore_high + 40 y fuera del alcance del buque (accion rally).
	return p.x <= _shore_x(p.y) + _beach_margin() and _outside_range(p)

func _outside_range(p: Vector2) -> bool:
	return p.distance_to(ship_position()) > _ship_range()

func _landmark(id: String) -> Dictionary:
	for lm in map_data().landmarks:
		if str(lm.id) == id:
			return lm
	return {}

func _work_site(action: String) -> Dictionary:
	## {"pos": Vector2, "radius": float, "work_s": float, "landmark": id}
	var a: Dictionary = map_data().actions[action]
	var lm := _landmark(str(a.at))
	return {"pos": Vector2(float(lm.x), float(lm.z)), "radius": float(a.radius_m), "work_s": float(a.work_s), "landmark": str(a.at)}

func _stumble_stop(u: Dictionary) -> String:
	return "El grupo tropezó y se reorganiza (%d s más)." % ceili(float(u.stumble_remaining))

## Acciones de cubierta: solo para grupos que ya abordan. {"ok", "reason"}.
func _check_boarding_action(u: Dictionary, action: String) -> Dictionary:
	if state.get("status", "") != "playing":
		return _no("La partida ya terminó.")
	if float(u.strength) <= float(map_data().outcome.routed_strength_threshold):
		return _no("Esa agrupación ya no puede recibir órdenes.")
	var cap: Dictionary = map_data().ship.capture
	if u.stage != "boarding":
		return _no("Solo un grupo que ya está abordando el buque puede hacerlo.")
	if action == "repel":
		var c: Dictionary = state.counter
		if not bool(c.active):
			return _no("No hay un contraataque en curso: la dotación todavía no se lanzó.")
		if bool(c.answered):
			return _no("El contraataque ya fue rechazado.")
		if int(state.ammo) < int(cap.counter.repel_ammo):
			return _no("Faltan municiones para rechazar el contraataque: hacen falta %d y quedan %d." % [int(cap.counter.repel_ammo), int(state.ammo)])
		return {"ok": true, "reason": "Disponible: quedan %d s de ventana." % ceili(float(c.until) - float(state.elapsed))}
	if float(u.evac_remaining) > 0.0:
		return _no("El grupo ya está evacuando heridos (%d s)." % ceili(float(u.evac_remaining)))
	if float(u.wounded) < float(cap.evacuate_min_wounded):
		return _no("No hay heridos que evacuar (hacen falta al menos %.0f; hay %.1f)." % [float(cap.evacuate_min_wounded), float(u.wounded)])
	return {"ok": true, "reason": "Disponible: recupera %.0f de fuerza y el grupo no suma captura %d s." % [float(u.wounded) * float(cap.evacuate_recover), roundi(float(cap.evacuate_s))]}

## Condiciones de una orden de grupo que no dependen de la ruta. {"ok", "reason"}.
func _check_group_action(u: Dictionary, action: String) -> Dictionary:
	if state.get("status", "") != "playing":
		return _no("La partida ya terminó.")
	if float(u.strength) <= float(map_data().outcome.routed_strength_threshold):
		return _no("Esa agrupación ya no puede recibir órdenes.")
	if action == "cancel":
		return {"ok": true, "reason": "Disponible."}
	if action in ["repel", "evacuate"]:
		return _check_boarding_action(u, action)
	if u.stage == "dismounting" or (u.stage == "boarding" and action != "withdraw"):
		return _no("El grupo ya desmontó y está abordando el buque: solo puede retirarse, rechazar el contraataque o evacuar heridos.")
	if u.stage == "stumbling":
		return _no(_stumble_stop(u))
	var m := map_data()
	var here := Vector2(u.x, u.z)
	match action:
		"move":
			pass
		"board":
			if not bool(state.advance_authorized):
				return _no("Falta la orden de avance de Liniers: señalá primero.")
		"rally":
			if not _on_dry_beach(here):
				return _no("Reagrupá en la playa seca y fuera del alcance del buque: el grupo está fuera de ella.")
		"withdraw":
			if _on_dry_beach(here) and exposure_at(here.x, here.y) <= 0.0:
				return _no("El grupo ya está en la playa seca.")
		"muster":
			if float(state.volunteers_pool) <= 0.0:
				return _no("No quedan voluntarios en el reservorio de la Plaza de Toros.")
			if float(u.strength) >= 100.0 - 0.001:
				return _no("El grupo ya tiene toda su fuerza (100).")
			if int(state.ammo) < int(m.actions.muster.get("ammo_cost", 0)):
				return _no("Faltan municiones para armar a los reclutas: hacen falta %d y quedan %d." % [int(m.actions.muster.ammo_cost), int(state.ammo)])
		"resupply":
			if int(state.ammo) >= int(state.ammo_max):
				return _no("El depósito de munición está lleno (%d/%d)." % [int(state.ammo), int(state.ammo_max)])
			if int(state.ammo_reserve) <= 0:
				return _no("Las piezas del Retiro no tienen más pólvora de reserva.")
		"signal_liniers":
			if bool(state.advance_authorized):
				return _no("La orden de avance de Liniers ya fue concedida.")
			if int(state.signals_left) <= 0:
				return _no("Liniers no concede más órdenes de avance: ya se usaron las %d señales." % int(m.resources.signals_max))
		_:
			return _no("Orden táctica desconocida.")
	if m.is_empty():
		return _no("El escenario no tiene mapa.")
	return {"ok": true, "reason": "Disponible."}

func issue_order(group_id: String, action: String, target: Vector2 = Vector2.ZERO, opts: Dictionary = {}) -> Dictionary:
	if state.get("status", "") != "playing":
		return _no("La partida ya terminó.")
	var u := get_unit(group_id)
	if u.is_empty() or float(u.strength) <= 5.0:
		return _no("Esa agrupación ya no puede recibir órdenes.")
	if state.scenario == "norte":
		var sid := str(u.sector_id)
		var nearest := INF
		for s in state.sectors:
			var distance := target.distance_to(Vector2(s.x, s.z))
			if distance < nearest:
				nearest = distance
				sid = s.id
		return issue_campaign_order(group_id, action, sid)
	if action == "cancel":
		return cancel_order(group_id)
	if action not in JUSTINE_ORDER_ACTIONS:
		return _no("Orden táctica desconocida.")
	var chk := _check_group_action(u, action)
	if not chk.ok:
		return chk
	if action == "repel":
		var rc: Dictionary = map_data().ship.capture.counter
		var ra: Dictionary = map_data().actions.repel
		state.ammo = int(state.ammo) - int(rc.repel_ammo)
		state.stats.ammo_used = int(state.stats.ammo_used) + int(rc.repel_ammo)
		state.counter.answered = true
		u.fatigue = minf(100.0, float(u.fatigue) + float(ra.fatigue_gain))
		_record_order(group_id, action, {})
		_event("%s cierra filas para rechazar el contraataque (−%d de munición)." % [u.name, int(rc.repel_ammo)], "counter", {"unit": u.id, "tag": str(ra.tag)})
		return {"ok": true, "reason": "El grupo rechaza el contraataque.", "path": [], "plan": {}}
	if action == "evacuate":
		u.evac_remaining = float(map_data().ship.capture.evacuate_s)
		_record_order(group_id, action, {})
		_event("%s evacúa a sus heridos (%d s sin sumar captura)." % [u.name, roundi(float(u.evac_remaining))], "boarding", {"unit": u.id})
		return {"ok": true, "reason": "Evacuación de heridos en curso.", "path": [], "plan": {}}
	if action == "withdraw" and u.stage == "boarding":
		u.evac_remaining = 0.0
		var wb := float(u.wounded) * float(map_data().ship.capture.evacuate_recover) * 0.5  ## los heridos se retiran con el grupo (la mitad que al evacuar)
		u.strength = minf(100.0, float(u.strength) + wb)
		state.stats.wounded_recovered = float(state.stats.wounded_recovered) + wb
		u.wounded = 0.0
		u.mounted = true  ## los caballos esperaban en el vado
		_clear_motion(u)
	var pace := str(opts.get("pace", u.pace))
	if pace not in PACES:
		pace = "trot"
	if not u.mounted:
		pace = "walk"
	var here := Vector2(u.x, u.z)
	if action == "rally":
		_clear_motion(u)
		u.stage = "rally"
		u.order = {"action": "rally"}
		_record_order(group_id, action, {})
		return {"ok": true, "reason": "El grupo descansa en la playa seca.", "path": [], "plan": {}}
	var dest := target
	if action == "board":
		dest = board_point()
	elif action == "withdraw":
		dest = Vector2(minf(here.x, _shore_x(here.y)), here.y)
		if pace == "gallop":
			pace = "trot"
	elif action in WORK_ACTIONS:
		var site := _work_site(action)
		dest = site.pos
		if here.distance_to(site.pos) <= float(site.radius):
			_clear_motion(u)
			u.order = {"action": action, "x": dest.x, "z": dest.y}
			_start_work(u, action)
			_record_order(group_id, action, {"x": dest.x, "z": dest.y})
			return {"ok": true, "reason": "El grupo empieza a trabajar.", "path": [], "plan": {}}
	var plan := plan_route(group_id, dest, pace, opts if action in ["move", "board"] else {})
	if not plan.ok:
		return _no(str(plan.reason))
	_clear_motion(u)
	u.pace = pace
	u.path = (plan.path as Array).duplicate(true)
	u.order = {"action": action, "x": dest.x, "z": dest.y}
	u.stage = "moving"
	_record_order(group_id, action, {"x": dest.x, "z": dest.y})
	if u.path.is_empty():
		_arrived(u)
	return {"ok": true, "reason": "Orden recibida.", "path": u.path.duplicate(true), "plan": plan}

func _clear_motion(u: Dictionary) -> void:
	u.path = []
	u.work = {}
	u.dismount_remaining = 0.0
	u.stumble_remaining = 0.0
	u.stage = "ready"

func _start_work(u: Dictionary, action: String) -> void:
	var site := _work_site(action)
	u.path = []
	u.stage = "working"
	u.work = {"kind": WORK_KIND[action], "remaining": float(site.work_s)}

## Despliegue previo: pasa 'amount' de fuerza de un grupo a otro antes de empezar y antes de la primera orden. Conserva el total; cada grupo
## queda a +-DEPLOY_MARGIN de su fuerza de partida y nunca pasa de 100. Actualiza la fuerza inicial del parte para que las bajas se midan bien.
func deploy_transfer(from_id: String, to_id: String, amount: float = DEPLOY_STEP) -> Dictionary:
	if state.get("scenario", "") != "justine" or state.get("status", "") != "playing":
		return _no("El despliegue solo existe en la Justina.")
	if float(state.elapsed) > 0.0 or not (state.orders as Array).is_empty():
		return _no("El despliegue solo se ajusta antes de empezar y antes de dar órdenes.")
	var a := get_unit(from_id)
	var b := get_unit(to_id)
	if a.is_empty() or b.is_empty() or from_id == to_id:
		return _no("Elegí dos grupos distintos.")
	if not is_finite(amount) or amount <= 0.0:
		return _no("La cantidad debe ser positiva.")
	var base := {}
	for g in map_data().groups:
		base[str(g.id)] = float(g.strength)
	var new_a := float(a.strength) - amount
	var new_b := float(b.strength) + amount
	if new_a < float(base.get(from_id, 0.0)) - DEPLOY_MARGIN - 0.001 or new_b > minf(100.0, float(base.get(to_id, 0.0)) + DEPLOY_MARGIN) + 0.001:
		return _no("Límite del despliegue: cada grupo puede variar hasta ±%d de su fuerza de partida y no pasar de 100." % roundi(DEPLOY_MARGIN))
	a.strength = new_a
	b.strength = new_b
	state.stats.start_strength[from_id] = new_a
	state.stats.start_strength[to_id] = new_b
	state.state_version = int(state.state_version) + 1
	return {"ok": true, "reason": "Pasaste %d de fuerza de %s a %s (ahora %d y %d)." % [roundi(amount), a.name, b.name, roundi(new_a), roundi(new_b)]}

## Ronda 3 (aditivo): reubica el punto de partida de un grupo o explorador antes de empezar y antes de la primera orden.
## Limite: DEPLOY_MOVE_M metros del punto de diseno y solo sobre tierra firme (is_walkable). No toca fuerza ni reglas del Norte.
func deploy_place(actor_id: String, x: float, z: float) -> Dictionary:
	if state.get("scenario", "") != "justine" or state.get("status", "") != "playing":
		return _no("El despliegue solo existe en la Justina.")
	if float(state.elapsed) > 0.0 or not (state.orders as Array).is_empty():
		return _no("El despliegue solo se ajusta antes de empezar y antes de dar órdenes.")
	if not is_finite(x) or not is_finite(z):
		return _no("Posición inválida.")
	var actor := get_unit(actor_id)
	var base := Vector2.ZERO
	var found := false
	for g in map_data().groups:
		if str(g.id) == actor_id:
			base = Vector2(float(g.x), float(g.z)); found = true
	for s in map_data().scouts:
		if str(s.id) == actor_id:
			base = Vector2(float(s.x), float(s.z)); found = true
	if actor.is_empty():
		for s2 in state.scouts:
			if str(s2.id) == actor_id:
				actor = s2
	if actor.is_empty() or not found:
		return _no("Ese grupo no existe.")
	if Vector2(x, z).distance_to(base) > DEPLOY_MOVE_M + 0.001:
		return _no("Límite del despliegue: el punto de partida solo puede moverse hasta %d m del original." % roundi(DEPLOY_MOVE_M))
	if not is_walkable(x, z, true) or water_depth_at(x, z) > 0.05:
		return _no("Ese punto no es tierra firme: elegí un lugar seco de la playa alta.")
	actor.x = x
	actor.z = z
	state.state_version = int(state.state_version) + 1
	return {"ok": true, "reason": "%s parte ahora de x %d · z %d." % [str(actor.name), roundi(x), roundi(z)]}

func cancel_order(group_id: String) -> Dictionary:
	var u := get_unit(group_id)
	if u.is_empty() or state.get("status", "") != "playing":
		return _no("No hay una orden que cancelar.")
	if u.stage in ["dismounting", "boarding"]:
		return _no("El grupo ya desmontó y está abordando: no se puede cancelar.")
	u.order = {}
	u.path = []
	u.stage = "ready"
	u.dismount_remaining = 0.0
	if u.has("work"):
		u.work = {}
		u.stumble_remaining = 0.0
	_record_order(group_id, "cancel", {})
	return {"ok": true, "reason": "Orden cancelada."}

func _record_order(id: String, action: String, target: Dictionary) -> void:
	if float(state.first_order_at) < 0:
		state.first_order_at = float(state.elapsed)
	state.orders.append({"time": state.elapsed, "round": state.round, "unit": id, "action": action, "target": target.duplicate(true)})
	state.state_version = int(state.state_version) + 1

# ---------------------------------------------------------------------------
# Exploradores y acciones globales

func _scout_check(s: Dictionary, action: String, points: Array) -> Dictionary:
	if state.get("status", "") != "playing":
		return _no("La partida ya terminó.")
	if s.is_empty():
		return _no("Explorador desconocido.")
	if s.stage == "lost" or int(s.hp) <= 0:
		return _no("%s fue abatido y no recibe órdenes." % s.name)
	if action == "recall":
		return {"ok": true, "reason": "Disponible."}
	if action not in ["probe", "probe_careful", "mark_ford"]:
		return _no("Orden de explorador desconocida.")
	var a: Dictionary = map_data().actions[action]
	if points.is_empty():
		return _no("Indicá al menos un punto.")
	var max_pts := int(a.waypoints_max) if action != "mark_ford" else 2
	if points.size() > max_pts:
		return _no("Máximo %d puntos para esta acción." % max_pts)
	for p in points:
		var v := p as Vector2
		if not _in_map(v):
			return _no("Un punto está fuera del mapa.")
		var lk := _land_kind(v.x, v.y, 0.0)
		if lk == "obstaculo":
			return _no("Un punto cae sobre un obstáculo.")
		if lk in ["casco", "meseta", "barranca"]:
			return _no("Un punto no es transitable para el explorador.")
	if action == "mark_ford":
		for p in points:
			if not _on_lane(p as Vector2, 3.0):
				return _no("Marcá solo sobre un carril ya sondeado (a menos de 3 m de su eje).")
		var need := _mark_balizas(points)
		if need > int(state.balizas):
			return _no("Faltan balizas (quedan %d)." % int(state.balizas))
	return {"ok": true, "reason": "Disponible."}

func _on_lane(p: Vector2, tol: float) -> bool:
	_know_sync()
	for i in range(_seg_a.size()):
		if _seg_kind[i] == 1 and p.distance_to(Geometry2D.get_closest_point_to_segment(p, _seg_a[i], _seg_b[i])) <= tol:
			return true
	return false

func _lane_dir_at(p: Vector2) -> Vector2:
	var best := INF
	var dir := Vector2(1, 0)
	for i in range(_seg_a.size()):
		if _seg_kind[i] != 1:
			continue
		var d := p.distance_to(Geometry2D.get_closest_point_to_segment(p, _seg_a[i], _seg_b[i]))
		if d < best and _seg_a[i].distance_to(_seg_b[i]) > 0.001:
			best = d
			dir = (_seg_b[i] - _seg_a[i]).normalized()
	return dir

func _mark_segment(points: Array) -> Array:
	## [A, B]: con un punto se marca un tramo de baliza_per_10m centrado en el punto, siguiendo el carril.
	var a := (points[0] as Vector2)
	if points.size() >= 2:
		return [a, points[1] as Vector2]
	var half := 5.0
	var dir := _lane_dir_at(a)
	return [a - dir * half, a + dir * half]

func _mark_balizas(points: Array) -> int:
	var seg := _mark_segment(points)
	var per := float(map_data().actions.mark_ford.balizas_per_10m)
	return ceili((seg[0] as Vector2).distance_to(seg[1] as Vector2) / 10.0 * per - 0.000001)

func issue_scout(scout_id: String, action: String, points: Array = [], opts: Dictionary = {}) -> Dictionary:
	var s := get_scout(scout_id)
	if action == "probe" and bool(opts.get("cautious", false)):
		action = "probe_careful"
	var chk := _scout_check(s, action, points)
	if not chk.ok:
		return chk
	var careful := action == "probe_careful"
	if careful:
		action = "probe"
	var here := Vector2(s.x, s.z)
	var route_pts: Array = []
	var order: Dictionary = {}
	var stage := "moving"
	match action:
		"recall":
			var dest := Vector2(minf(here.x, _shore_x(here.y) - 10.0), here.y)
			var leg := _plan_points(here, dest)
			if not leg.ok:
				return _no(str(leg.reason))
			route_pts = leg.pts
		"probe":
			var leg := _plan_points(here, points[0] as Vector2)
			if not leg.ok:
				return _no("No hay camino hasta el primer punto: " + str(leg.reason))
			route_pts = leg.pts
			for i in range(1, points.size()):
				route_pts.append(points[i] as Vector2)
			order = {"action": "probe", "points": _path_dicts(points)}
			stage = "probing"
		"mark_ford":
			var seg := _mark_segment(points)
			var leg := _plan_points(here, seg[0] as Vector2)
			if not leg.ok:
				return _no("No hay camino hasta el tramo a marcar: " + str(leg.reason))
			route_pts = leg.pts
			order = {"action": "mark_ford", "points": _path_dicts(seg)}
	var risk := {}
	if action == "probe":
		risk = scout_risk(scout_id, points, careful)
	s.order = order
	s.cautious = careful
	s.path = _path_dicts(route_pts)
	s.stage = stage
	s.work_remaining = 0.0
	s.erase("probe_id")
	s.erase("mark_done")
	s.erase("mark_charged")
	_record_order(scout_id, action, {"points": _path_dicts(points)})
	if route_pts.is_empty():
		_scout_arrived(s)
	var why := "Orden recibida."
	if not risk.is_empty():
		why += " " + str(risk.text)
	return {"ok": true, "reason": why, "path": s.path.duplicate(true), "risk": risk}

## Riesgo decidible del sondeo: horas expuestas al fuego, impactos esperados y probabilidad de baja, suponiendo que el explorador es el unico blanco
## (el peor caso) y sin contar un apoyo de fuego futuro. No tiene efectos.
func scout_risk(scout_id: String, points: Array, careful: bool = false) -> Dictionary:
	var out := {"exposed_s": 0.0, "expected_hits": 0.0, "death_pct": 0.0, "hp": 0, "careful": careful, "text": ""}
	var s := get_scout(scout_id)
	if s.is_empty() or points.is_empty() or map_data().is_empty():
		return out
	var fire: Dictionary = map_data().ship.fire
	var pa: Dictionary = map_data().actions.probe
	var hit := float(fire.get("scout_hit_chance", 1.0))
	var speed_mult := 1.0
	if careful:
		var pc: Dictionary = map_data().actions.probe_careful
		hit *= float(pc.hit_mult)
		speed_mult = float(pc.speed_mult)
	var gap := float(fire.volley_interval_s)
	var prev := Vector2(s.x, s.z)
	var hits := 0.0
	var exposed := 0.0
	for pt in points:
		var target: Vector2 = pt
		var seg := prev.distance_to(target)
		var n := maxi(1, ceili(seg / 2.0))
		var sub := seg / float(n)
		for k in range(n):
			var p := prev.lerp(target, (float(k) + 0.5) / float(n))
			var e := exposure_at(p.x, p.y)
			var v := (float(pa.speed_mps_water) if water_depth_at(p.x, p.y) > 0.0 else float(pa.speed_mps_dry)) * (speed_mult if e > 0.0 else 1.0)
			var dt := sub / maxf(0.05, v)
			exposed += e * dt
			hits += e * dt / gap * hit
		prev = target
	var hp := int(s.hp)
	## Poisson: P(impactos >= salud)
	var p_alive := 0.0
	var term := exp(-hits)
	for i in range(hp):
		p_alive += term
		term *= hits / float(i + 1)
	out.exposed_s = exposed
	out.expected_hits = hits
	out.hp = hp
	out.death_pct = clampf((1.0 - p_alive) * 100.0, 0.0, 100.0)
	if exposed < 0.5:
		out.text = "Sin exposición al fuego del buque."
		return out
	out.text = "Riesgo: %d s expuesto, ≈ %.1f impactos esperados (salud %d), %d %% de baja%s." % [roundi(exposed), hits, hp, roundi(float(out.death_pct)), " (cauteloso)" if careful else ""]
	return out

func call_fire_support() -> Dictionary:
	if state.get("status", "") != "playing" or state.get("scenario", "") != "justine":
		return _no("La partida ya terminó.")
	var a: Dictionary = map_data().actions.distract_fire
	if int(state.ammo) < int(a.ammo_cost):
		return _no("Faltan municiones: hacen falta %d y quedan %d." % [int(a.ammo_cost), int(state.ammo)])
	if float(state.elapsed) < float(state.fire_support.ready_at):
		return _no("La batería todavía recarga (%d s)." % ceili(float(state.fire_support.ready_at) - float(state.elapsed)))
	state.ammo = int(state.ammo) - int(a.ammo_cost)
	state.fire_support = {"until": float(state.elapsed) + float(a.duration_s), "ready_at": float(state.elapsed) + float(a.cooldown_s)}
	state.crew_morale = maxf(0.0, float(state.crew_morale) - float(a.ship_morale_loss))
	state.stats.fire_support_uses = int(state.stats.fire_support_uses) + 1
	state.stats.ammo_used = int(state.stats.ammo_used) + int(a.ammo_cost)
	var bat := _landmark(str(a.from))
	_event("Las piezas de a 18 del Retiro y los tiradores de la barranca atraen el fuego del buque durante %d s." % int(a.duration_s), "fire_support", {"pos": {"x": float(bat.x), "z": float(bat.z)}, "tag": str(a.tag)})
	_record_order("global", "distract_fire", {})
	return {"ok": true, "reason": "Fuego de distracción en curso."}

func retreat_all() -> Dictionary:
	if state.get("status", "") != "playing" or state.get("scenario", "") != "justine":
		return _no("La partida ya terminó.")
	_record_order("global", "retreat_all", {})
	_finish("defeat", "Retirada general ordenada. La partida termina como una retirada ordenada, sin captura del buque.", "retirada")
	return {"ok": true, "reason": "Retirada general."}

# ---------------------------------------------------------------------------
# Consultas de presentacion (copias)

func ship_state() -> Dictionary:
	var m := map_data()
	var sh: Dictionary = m.ship
	return {"x": float(sh.x), "z": float(sh.z), "heading_deg": float(sh.heading_deg), "guns_total": int(sh.guns_total), "broadside_guns": int(sh.broadside_guns),
		"range_m": float(sh.fire.range_m), "next_volley_in": maxf(0.0, float(state.get("next_volley", 0.0)) - float(state.get("elapsed", 0.0))),
		"crew_morale": float(state.get("crew_morale", 0.0)), "capture": float(state.get("capture", 0.0)), "fire_support_active": _fire_support_active(),
		"fire_support_ready_in": maxf(0.0, float(state.get("fire_support", {}).get("ready_at", 0.0)) - float(state.get("elapsed", 0.0)))}

func resources() -> Dictionary:
	return {"ammo": int(state.ammo), "ammo_max": int(state.ammo_max), "ammo_reserve": int(state.get("ammo_reserve", 0)), "signals_left": int(state.get("signals_left", 0)), "balizas": int(state.balizas), "volunteers_pool": float(state.volunteers_pool), "advance_authorized": bool(state.advance_authorized),
		"advance_remaining_s": maxf(0.0, float(state.get("advance_until", -1.0)) - float(state.get("elapsed", 0.0))) if bool(state.advance_authorized) and float(state.get("advance_until", -1.0)) >= 0.0 else 0.0}

func scouts() -> Array:
	return state.get("scouts", []).duplicate(true)

func probes() -> Array:
	return state.get("probes", []).duplicate(true)

func action_info(action: String) -> Dictionary:
	var acts: Dictionary = map_data().get("actions", {})
	if not acts.has(action):
		return {}
	var d: Dictionary = (acts[action] as Dictionary).duplicate(true)
	d["id"] = action
	return d

func list_actions(actor_kind: String) -> Array:
	match actor_kind:
		"group":
			return ["move", "board", "muster", "resupply", "signal_liniers", "withdraw", "repel", "evacuate", "rally", "cancel"]
		"scout":
			return ["probe", "probe_careful", "mark_ford", "recall"]
		"global":
			return ["distract_fire", "retreat_all"]
	return []

func _cost_text(action: String) -> String:
	var a := action_info(action)
	var parts: Array = []
	if a.has("ammo_cost"):
		parts.append("%d munición" % int(a.ammo_cost))
	if a.has("work_s"):
		parts.append("%d s" % int(a.work_s))
	if a.has("duration_s"):
		parts.append("%d s" % int(a.duration_s))
	if a.has("balizas_per_10m"):
		parts.append("%d baliza por 10 m" % int(a.balizas_per_10m))
	if a.has("strength_gain"):
		parts.append("+%d fuerza" % int(a.strength_gain))
	if a.has("ammo_gain"):
		parts.append("+%d munición" % int(a.ammo_gain))
	if action in ["probe", "probe_careful"]:
		parts.append("hasta %d puntos" % int(a.waypoints_max))
	if action == "probe_careful":
		parts.append("×%.1f de velocidad, ×%.2f de riesgo" % [float(a.speed_mult), float(a.hit_mult)])
	if action == "board":
		parts.append("desmonta %d s" % int(map_data().ship.capture.dismount_s))
	return " · ".join(parts)

func action_availability(actor_id: String, action: String, target: Vector2 = Vector2.ZERO) -> Dictionary:
	var info := action_info(action)
	var out := {"ok": false, "reason": "", "cost_text": _cost_text(action), "tag": str(info.get("tag", "diseno"))}
	if state.get("scenario", "") != "justine":
		out.reason = "Solo en Justina."
		return out
	if info.is_empty() and action not in ["retreat_all"]:
		out.reason = "Acción desconocida."
		return out
	if action == "retreat_all":
		out.tag = "diseno"
		out.cost_text = "termina la partida"
		out.ok = state.status == "playing"
		out.reason = "Disponible." if out.ok else "La partida ya terminó."
		return out
	if action == "distract_fire":
		var chk := _fire_support_check()
		out.ok = chk.ok
		out.reason = chk.reason
		return out
	var s := get_scout(actor_id)
	if not s.is_empty():
		if action in SCOUT_ACTIONS_ALL:
			var pts: Array = [] if target == Vector2.ZERO else [target]
			if action == "recall":
				pts = []
			var chk2 := _scout_check(s, action, pts) if (pts.size() > 0 or action == "recall") else _scout_ready(s, action)
			out.ok = chk2.ok
			out.reason = chk2.reason
			if out.ok and action in ["probe", "probe_careful"] and pts.size() > 0:
				out.reason = str(chk2.reason) + " " + str(scout_risk(actor_id, pts, action == "probe_careful").text)
		else:
			out.reason = "Esa acción no es de exploradores."
		return out
	var u := get_unit(actor_id)
	if u.is_empty():
		out.reason = "Actor desconocido."
		return out
	if action in SCOUT_ACTIONS_ALL:
		out.reason = "Esa acción es de exploradores."
		return out
	var c := _check_group_action(u, action)
	out.ok = c.ok
	out.reason = c.reason
	if c.ok and ((action == "move" and target != Vector2.ZERO) or action == "board"):
		var dest := board_point() if action == "board" else target
		var plan := plan_route(actor_id, dest, str(u.pace))
		if not plan.ok:
			out.ok = false
			out.reason = str(plan.reason)
		else:
			out.reason = "Disponible. Ruta de %d m, ≈ %d s, riesgo %s." % [roundi(plan.length_m), roundi(plan.eta_s), plan.risk]
	return out

func _scout_ready(s: Dictionary, action: String) -> Dictionary:
	if state.get("status", "") != "playing":
		return _no("La partida ya terminó.")
	if s.stage == "lost" or int(s.hp) <= 0:
		return _no("%s fue abatido y no recibe órdenes." % s.name)
	if action == "mark_ford" and int(state.balizas) <= 0:
		return _no("Faltan balizas (quedan 0).")
	return {"ok": true, "reason": "Disponible. Elegí los puntos en el mapa."}

func _fire_support_check() -> Dictionary:
	if state.get("status", "") != "playing":
		return _no("La partida ya terminó.")
	var a: Dictionary = map_data().actions.distract_fire
	if int(state.ammo) < int(a.ammo_cost):
		return _no("Faltan municiones: hacen falta %d y quedan %d." % [int(a.ammo_cost), int(state.ammo)])
	if float(state.elapsed) < float(state.fire_support.ready_at):
		return _no("La batería todavía recarga (%d s)." % ceili(float(state.fire_support.ready_at) - float(state.elapsed)))
	return {"ok": true, "reason": "Disponible."}


# ---------------------------------------------------------------------------
# Simulacion (paso fijo)

func tick(dt: float) -> Array:
	_events = []
	if state.get("status", "") != "playing" or state.get("scenario", "") != "justine" or not is_finite(dt) or dt <= 0:
		return _events
	state.accumulator = float(state.accumulator) + minf(dt, 60.0)
	while float(state.accumulator) + 0.000001 >= STEP and state.status == "playing":
		state.accumulator = maxf(0.0, float(state.accumulator) - STEP)
		_justine_step(STEP)
	return _events

func _bank_of(p: Vector2) -> String:
	## Banco/vado donde esta un punto: "central", "sur" u "otra".
	var best := "otra"
	var m := map_data()
	for bank in m.banks:
		if str(bank.id) in ["banco_central", "banco_sur"]:
			var pts := _vpoly(bank.centerline)
			var d := INF
			for i in range(max(1, pts.size() - 1)):
				d = minf(d, p.distance_to(Geometry2D.get_closest_point_to_segment(p, pts[i], pts[mini(i + 1, pts.size() - 1)])))
			if d <= float(bank.half_width_m) + float(bank.blend_m):
				best = "central" if str(bank.id) == "banco_central" else "sur"
	for fd in m.fords:
		if str(fd.id) == "vado_sur":
			var pts2 := _vpoly(fd.centerline)
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p, pts2[0], pts2[1])) <= float(fd.half_width_m) + float(fd.blend_m):
				best = "sur"
	return best

func _justine_step(dt: float) -> void:
	state.elapsed = float(state.elapsed) + dt
	var elapsed := float(state.elapsed)
	var m := map_data()
	var tide := tide_at(elapsed)
	state.water_level_m = tide.level_m
	state.water_level = tide.level_norm
	state.tide_phase = tide.phase
	var marks := tide_marks()
	if not state.bajante_announced and elapsed >= marks.drop_start:
		state.bajante_announced = true
		_event("El río empieza a bajar. Es una regla del juego, no una predicción histórica: aprovechá la bajante para reconocer el fondo.", "tide")
	if not state.rising_announced and elapsed >= marks.low_hold_end:
		state.rising_announced = true
		_event("El agua vuelve a subir: quedan %d s para asegurar la captura." % roundi(marks.deadline - elapsed), "warning")
	if bool(state.advance_authorized) and float(state.get("advance_until", -1.0)) >= 0.0 and elapsed >= float(state.advance_until):
		state.advance_authorized = false
		var halted := 0
		for hu in state.units:
			## La orden de avance vale hasta llegar: un grupo que aun marcha hacia el buque se detiene cuando vence (los que ya desmontaron siguen).
			if hu.stage in ["moving", "blocked", "stumbling"] and str(hu.order.get("action", "")) == "board":
				var hn := str(hu.name)
				_clear_motion(hu)
				hu.order = {}
				halted += 1
				_event("%s se detiene: venció la orden de avance antes de llegar al buque." % hn, "warning", {"unit": hu.id, "pos": {"x": hu.x, "z": hu.z}})
		state.stats.halted_by_expiry = int(state.stats.halted_by_expiry) + halted
		_event("La orden de avance de Liniers venció: hay que volver a señalar para cargar%s." % ("" if int(state.signals_left) > 0 else " (ya no quedan más señales)"), "warning")
	var board_power := 0.0
	var alive := 0
	var routed_hp: float = float(m.outcome.routed_strength_threshold)
	for u in state.units:
		if float(u.strength) <= routed_hp:
			if u.stage != "routed":
				_event("%s se dispersa." % u.name, "warning", {"unit": u.id, "pos": {"x": u.x, "z": u.z}})
			u.stage = "routed"
			u.path = []
			u.order = {}
			u.work = {}
			u.stumble_remaining = 0.0
			continue
		alive += 1
		board_power += _step_group(u, dt)
	for s in state.scouts:
		_step_scout(s, dt)
	_account_exposure(dt)
	if board_power > 0.0:
		var cap: Dictionary = m.ship.capture
		state.capture = minf(100.0, float(state.capture) + board_power * float(cap.rate_per_power_per_s) * dt)
		state.crew_morale = maxf(0.0, float(state.crew_morale) - board_power * float(cap.morale_loss_per_power_per_s) * dt)
	_step_counter()
	if elapsed >= float(state.next_volley):
		var gap := float(m.ship.fire.volley_interval_s)
		if _fire_support_active():
			gap += float(m.actions.distract_fire.volley_interval_add_s)
		state.next_volley = float(state.next_volley) + gap
		_artillery()
	if alive == 0:
		_finish("defeat", "Las agrupaciones se dispersaron antes de asegurar la captura.", "dispersos")
	elif float(state.capture) >= float(m.outcome.victory.capture_pct):
		_finish("victory", "La dotación se rinde. El buque queda capturado; los caballos permanecen fuera de la cubierta.", "capturado")
	elif elapsed >= float(state.deadline):
		_finish("defeat", "El plazo se agotó sin asegurar el buque.", "plazo")
	state.state_version = int(state.state_version) + 1

func _boarders() -> Array:
	var out: Array = []
	for u in state.units:
		if u.stage in ["boarding", "dismounting"] and float(u.strength) > float(map_data().outcome.routed_strength_threshold):
			out.append(u)
	return out

## Contraataque de la dotacion: se abre una ventana de decision; sin respuesta (accion 'repel') golpea a los que abordan y retrocede la captura.
func _step_counter() -> void:
	var cfg: Dictionary = map_data().ship.capture.counter
	var c: Dictionary = state.counter
	var elapsed := float(state.elapsed)
	var boarders := _boarders()
	if not bool(c.active):
		if boarders.is_empty() or float(state.crew_morale) < float(cfg.min_crew_morale):
			if boarders.is_empty():
				c.next_at = -1.0  ## sin nadie abordando se reinicia el reloj del contraataque
			return
		if float(c.next_at) < 0.0:
			c.next_at = elapsed + float(cfg.first_after_boarding_s)
			return
		if elapsed >= float(c.next_at):
			c.active = true
			c.answered = false
			c.until = elapsed + float(cfg.window_s)
			_event("La dotación contraataca sobre la cubierta: hay %d s para rechazarlo (Rechazar contraataque, %d de munición) o se pierde terreno." % [roundi(float(cfg.window_s)), int(cfg.repel_ammo)], "counter", {"tag": str(cfg.tag)})
		return
	if elapsed < float(c.until):
		return
	var mult := float(cfg.repelled_mult) if bool(c.answered) else 1.0
	c.active = false
	c.count = int(c.count) + 1
	var jitter := (_random() * 2.0 - 1.0) * float(cfg.jitter_s)
	c.next_at = elapsed + float(cfg.interval_s) + jitter
	var live := _boarders()
	if live.is_empty():
		return
	var dmg := float(cfg.damage) * mult
	var share := dmg / float(live.size())
	var share_w := float(map_data().ship.capture.wounded_share)
	for u in live:
		var lost := minf(share, float(u.strength))
		u.strength = float(u.strength) - lost
		u.wounded = minf(100.0, float(u.wounded) + lost * share_w)
		state.stats.counter_loss = float(state.stats.counter_loss) + lost
	var cap_loss := float(cfg.capture_loss_pct) * mult
	state.capture = maxf(0.0, float(state.capture) - cap_loss)
	if bool(c.answered):
		state.stats.counter_repelled = int(state.stats.counter_repelled) + 1
		_event("El contraataque se rechaza: −%.0f de fuerza repartidos y la captura cede %.1f %%." % [dmg, cap_loss], "counter", {"tag": str(cfg.tag)})
	else:
		state.stats.counter_hits = int(state.stats.counter_hits) + 1
		_event("El contraataque no fue contestado: −%.0f de fuerza repartidos y la captura retrocede %.0f %%." % [dmg, cap_loss], "warning", {"tag": str(cfg.tag)})

func _account_exposure(dt: float) -> void:
	for u in state.units:
		var e := exposure_for(u)
		if e > 0.0:
			var k := "otra" if u.stage in ["boarding", "dismounting"] else _bank_of(Vector2(u.x, u.z))
			state.stats.exposure_s[k] = float(state.stats.exposure_s[k]) + e * dt
	for u in state.units:
		if u.stage in ["routed", "boarding", "dismounting"]:
			continue
		var b := _bank_of(Vector2(u.x, u.z))
		if state.stats.bank_s.has(b):
			state.stats.bank_s[b] = float(state.stats.bank_s[b]) + dt

## Devuelve el poder de abordaje que aporta el grupo en este paso.
func _step_group(u: Dictionary, dt: float) -> float:
	var elapsed := float(state.elapsed)
	var mounted: bool = u.mounted
	var here := Vector2(u.x, u.z)
	if not (u.stage in ["dismounting", "boarding"]) and speed_at(here.x, here.y, "walk", mounted) <= 0.0:
		_rescue_submerged(u)
		return 0.0
	if state.stats.first_water_entry_at < 0.0 and water_depth_at(here.x, here.y) > 0.0 and u.stage != "routed":
		state.stats.first_water_entry_at = elapsed
	match str(u.stage):
		"moving":
			var act := str(u.order.get("action", ""))
			if act == "board" and here.distance_to(board_point()) <= float(map_data().ship.capture.boarding_radius_m):
				## Basta llegar al borde de la zona de abordaje (boarding_radius_m) para empezar a desmontar.
				u.path = []
				_arrived(u)
				return 0.0
			if act in WORK_ACTIONS:
				var site := _work_site(act)
				if here.distance_to(site.pos) <= float(site.radius):
					_start_work(u, act)
					return 0.0
			_move_unit(u, dt)
		"working":
			u.work.remaining = float(u.work.remaining) - dt
			if float(u.work.remaining) <= 0.0:
				_finish_work(u)
		"stumbling":
			u.stumble_remaining = maxf(0.0, float(u.stumble_remaining) - dt)
			if float(u.stumble_remaining) <= 0.0:
				_replan(u, true)
		"blocked":
			if elapsed >= float(u.blocked_until):
				_replan(u, false)
		"dismounting":
			_boarding_hazards(u, dt)
			u.dismount_remaining = maxf(0.0, float(u.dismount_remaining) - dt)
			if float(u.dismount_remaining) <= 0.0:
				u.mounted = false
				u.stage = "boarding"
				u.pace = "walk"
				if float(state.stats.boarded_at) < 0.0:
					state.stats.boarded_at = elapsed
					state.stats.level_at_boarding = water_level_m()
				_event("%s desmontó. Los caballos quedan en el vado mientras la partida exige la rendición." % u.name, "boarding", {"unit": u.id, "pos": {"x": u.x, "z": u.z}})
		"boarding":
			_boarding_hazards(u, dt)
			u.fatigue = minf(100.0, float(u.fatigue) + 0.05 * dt)
			if float(u.strength) <= float(map_data().outcome.routed_strength_threshold):
				return 0.0
			if float(u.evac_remaining) > 0.0:
				## Evacuando heridos: el grupo no aporta poder de captura hasta terminar.
				u.evac_remaining = maxf(0.0, float(u.evac_remaining) - dt)
				if float(u.evac_remaining) <= 0.0:
					var cap: Dictionary = map_data().ship.capture
					var back := float(u.wounded) * float(cap.evacuate_recover)
					u.strength = minf(100.0, float(u.strength) + back)
					state.stats.wounded_recovered = float(state.stats.wounded_recovered) + back
					state.stats.evacuations = int(state.stats.evacuations) + 1
					u.wounded = 0.0
					_event("%s evacúa a sus heridos: recupera %.0f de fuerza." % [u.name, back], "boarding", {"unit": u.id, "pos": {"x": u.x, "z": u.z}})
				return 0.0
			return (float(u.strength) / 100.0) * maxf(0.4, 1.0 - float(u.fatigue) * 0.004)
		"rally":
			if _on_dry_beach(here):
				var rally: Dictionary = map_data().actions.rally
				u.fatigue = maxf(0.0, float(u.fatigue) - float(rally.regen_fatigue_per_s) * dt)
				u.strength = minf(100.0, float(u.strength) + float(rally.regen_strength_per_s) * dt)
	return 0.0

## Costo de abordar: cuerpo a cuerpo con la dotación (mientras conserve moral) y el agua que sube sobre quien esta a pie en el vado.
func _boarding_hazards(u: Dictionary, dt: float) -> void:
	var cap: Dictionary = map_data().ship.capture
	if u.stage == "boarding":
		var melee := float(cap.get("melee_loss_per_s", 0.0)) * (float(state.crew_morale) / 100.0) * dt
		u.strength = maxf(0.0, float(u.strength) - melee)
		u.wounded = minf(100.0, float(u.wounded) + melee * float(cap.wounded_share))
		state.stats.melee_loss = float(state.stats.melee_loss) + melee
	var depth_here := water_depth_at(float(u.x), float(u.z))
	if depth_here > float(cap.tide_warn_fraction) * _foot_limit() and depth_here <= _foot_limit() and int(float(state.elapsed) * 4.0) % 40 == 0:
		_event("%s: el agua sube en el vado (%.2f m); a partir de %.1f m los de a pie no aguantan. Retirá a los grupos o evacuá a los heridos." % [u.name, depth_here, _foot_limit()], "warning", {"unit": u.id, "pos": {"x": u.x, "z": u.z}})
	var excess := depth_here - _foot_limit()
	if excess > 0.0:
		var loss := float(cap.get("drown_loss_per_m_s", 0.0)) * (excess + 0.1) * dt
		u.strength = maxf(0.0, float(u.strength) - loss)
		state.stats.drowned = float(state.stats.drowned) + loss
		if int(float(state.elapsed) * 4.0) % 80 == 0:
			_event("%s lucha con el agua que sube en el vado: el río supera lo que un hombre a pie puede vadear y se pierden jinetes." % u.name, "warning", {"unit": u.id, "pos": {"x": u.x, "z": u.z}})

func _fatigue_rate(pace: String, d: float, h_mud: bool) -> float:
	var f: Dictionary = _mv().fatigue_per_s
	var r := float(f[pace])
	if d > 0.0:
		r *= float(f.water_mult)
	elif h_mud:
		r *= float(f.mud_mult)
	return r

func _move_unit(u: Dictionary, dt: float) -> void:
	if u.path.is_empty():
		_arrived(u)
		return
	var mounted: bool = u.mounted
	var pace := str(u.pace) if mounted else "walk"
	var cur := Vector2(u.x, u.z)
	var p: Dictionary = u.path[0]
	var wp := Vector2(p.x, p.z)
	var fat := 1.0
	var v := speed_at(cur.x, cur.y, pace, mounted) * fat
	if v <= 0.0:
		_block(u, "%s detiene el avance: el terreno ya no es transitable. Podés cancelar y dar otra orden." % u.name)
		return
	var nxt := cur.move_toward(wp, v * dt)
	var v2 := speed_at(nxt.x, nxt.y, pace, mounted) * fat
	if v2 <= 0.0:
		var depth := water_depth_at(nxt.x, nxt.y)
		if _land_kind(nxt.x, nxt.y, 0.0) == "" and depth > _limit_for(mounted) and knowledge_at(nxt.x, nxt.y) == "unknown":
			_stumble(u, cur, nxt)
		else:
			_block(u, "%s detiene el avance: el agua cubre la ruta. Se replanifica." % u.name)
		return
	if v2 < v:
		nxt = cur.move_toward(wp, v2 * dt)
	var d_here := water_depth_at(nxt.x, nxt.y)
	var firm := d_here <= 0.0 and -d_here >= float(_mv().mud.firm_min_height_m) and _land_kind(nxt.x, nxt.y, 0.0) == ""
	## El galope solo se sostiene en terreno firme: en barro, agua o bajadas el esfuerzo es el del trote.
	var eff_pace := "trot" if (pace == "gallop" and not firm) else pace
	u.x = nxt.x
	u.z = nxt.y
	u.fatigue = minf(100.0, float(u.fatigue) + _fatigue_rate(eff_pace, d_here, d_here <= 0.0 and not firm) * dt)
	if nxt.distance_to(wp) < 0.01:
		u.path.pop_front()
		if u.path.is_empty():
			_arrived(u)

func _block(u: Dictionary, why: String) -> void:
	u.path = []
	u.stage = "blocked"
	u.blocked_until = float(state.elapsed) + 5.0
	_event(why, "warning", {"unit": u.id, "pos": {"x": u.x, "z": u.z}})

func _replan(u: Dictionary, after_stumble: bool) -> void:
	if u.order.is_empty():
		u.stage = "ready"
		return
	var dest := Vector2(float(u.order.get("x", u.x)), float(u.order.get("z", u.z)))
	var leg := _plan_points(Vector2(u.x, u.z), dest)
	if leg.ok:
		u.path = _path_dicts(leg.pts)
		u.stage = "moving"
		if u.path.is_empty():
			_arrived(u)
		elif after_stumble:
			_event("%s se reorganiza y retoma el avance por una ruta que evita el punto hallado." % u.name, "info", {"unit": u.id})
	else:
		u.path = []
		u.stage = "blocked"
		u.blocked_until = float(state.elapsed) + 5.0
		if after_stumble:
			_event("%s no encuentra otra ruta hacia su destino: queda detenido (%s)" % [u.name, leg.reason], "warning", {"unit": u.id, "pos": {"x": u.x, "z": u.z}})

func _arrived(u: Dictionary) -> void:
	var act := str(u.order.get("action", ""))
	var here := Vector2(u.x, u.z)
	if act == "board":
		if here.distance_to(board_point()) <= float(map_data().ship.capture.boarding_radius_m):
			if u.mounted:
				u.stage = "dismounting"
				u.dismount_remaining = float(map_data().ship.capture.dismount_s)
				_event("%s llegó al vado del buque y desmonta (%d s)." % [u.name, roundi(u.dismount_remaining)], "boarding", {"unit": u.id, "pos": {"x": u.x, "z": u.z}})
			else:
				u.stage = "boarding"
			return
		u.stage = "ready"
		u.order = {}
	elif act in WORK_ACTIONS:
		var site := _work_site(act)
		if here.distance_to(site.pos) <= float(site.radius):
			_start_work(u, act)
		else:
			u.stage = "ready"
			u.order = {}
			_event("%s no llegó a %s." % [u.name, site.landmark], "warning", {"unit": u.id})
	else:
		u.stage = "ready"
		u.order = {}

func _finish_work(u: Dictionary) -> void:
	var kind := str(u.work.kind)
	var a: Dictionary
	u.work = {}
	u.stage = "ready"
	u.order = {}
	var pos := {"x": u.x, "z": u.z}
	match kind:
		"muster":
			a = map_data().actions.muster
			var gain := minf(minf(float(a.strength_gain), 100.0 - float(u.strength)), float(state.volunteers_pool))
			u.strength = float(u.strength) + gain
			state.volunteers_pool = float(state.volunteers_pool) - gain
			state.stats.muster_gain = float(state.stats.muster_gain) + gain
			var raw_fat := float(a.get("fatigue_gain", 0.0)) * (gain / maxf(0.001, float(a.strength_gain)))
			u.fatigue = minf(100.0, float(u.fatigue) + raw_fat)
			var ac := mini(int(a.get("ammo_cost", 0)), int(state.ammo))
			state.ammo = int(state.ammo) - ac
			state.stats.ammo_used = int(state.stats.ammo_used) + ac
			_event("%s reúne jinetes en la Plaza de Toros: +%.0f de fuerza (reclutas sin entrenar: +%.0f de fatiga, −%d de munición)." % [u.name, gain, raw_fat, ac], "muster", {"unit": u.id, "pos": pos})
		"resupply":
			a = map_data().actions.resupply
			var got := mini(mini(int(a.ammo_gain), int(state.ammo_max) - int(state.ammo)), int(state.ammo_reserve))
			state.ammo = int(state.ammo) + got
			state.ammo_reserve = int(state.ammo_reserve) - got
			_event("%s abastece munición en las piezas del Retiro: +%d (quedan %d de reserva)." % [u.name, got, int(state.ammo_reserve)], "ammo", {"unit": u.id, "pos": pos})
		"signal":
			a = map_data().actions.signal_liniers
			state.advance_authorized = true
			state.signals_left = maxi(0, int(state.signals_left) - 1)
			state.advance_until = float(state.elapsed) + float(a.get("valid_s", 1.0e9))
			var got2 := mini(int(a.ammo_gain), int(state.ammo_max) - int(state.ammo))
			state.ammo = int(state.ammo) + got2
			_event("Liniers concede la orden de avanzar (vale %d s). Regla del juego: el relato de Obligado (1920) la hace partir de Liniers hacia la caballería de Pueyrredón. +%d de munición. Quedan %d señales." % [roundi(float(a.get("valid_s", 0.0))), got2, int(state.signals_left)], "signal", {"unit": u.id, "pos": pos, "tag": str(a.tag)})

func _touch_hazards(p: Vector2, reach: float) -> void:
	var m := map_data()
	var changed := false
	for hz in m.hazards:
		if _inactive.has(str(hz.id)):
			continue
		var c := Vector2(float(hz.center[0]), float(hz.center[1]))
		if p.distance_to(c) <= float(hz.radius_m) + reach and str(hz.id) not in state.hazards_found:
			state.hazards_found.append(str(hz.id))
			changed = true
			_event("Se descubre %s." % str(hz.name), "recon", {"pos": {"x": c.x, "z": c.y}, "tag": str(hz.tag)})
	for fd in m.fords:
		var d := INF
		if fd.has("centerline"):
			var pts := _vpoly(fd.centerline)
			d = p.distance_to(Geometry2D.get_closest_point_to_segment(p, pts[0], pts[1])) - float(fd.half_width_m)
		else:
			d = p.distance_to(Vector2(float(fd.center[0]), float(fd.center[1]))) - float(fd.radius_m)
		if d <= reach and str(fd.id) not in state.fords_found:
			state.fords_found.append(str(fd.id))
			changed = true
			_event("Se reconoce el %s." % str(fd.name), "ford", {"tag": str(fd.tag)})
	if changed:
		_know_sig = -1

func _add_probe_record(kind: String, start: Vector2, scout_id: String) -> Dictionary:
	var width := float(map_data().knowledge.probe_lane_width_m) if kind == "lane" else float(map_data().knowledge.marked_corridor_width_m)
	var rec := {"id": "p%d" % (state.probes.size() + 1), "kind": kind, "pts": [{"x": start.x, "z": start.y}], "width": width, "t": float(state.elapsed), "scout": scout_id}
	state.probes.append(rec)
	_know_sync()
	return rec

func _probe_by_id(id: String) -> Dictionary:
	for p in state.probes:
		if p.id == id:
			return p
	return {}

const MAX_PROBES := 400
const MAX_PROBE_POINTS := 200

func _probe_add_point(rec: Dictionary, pt: Vector2) -> Dictionary:
	## Agrega un punto al sondeo y lo registra en el indice. Si se llena, abre otro registro. Devuelve el registro vigente.
	_know_sync()
	var pts: Array = rec.pts
	var last := Vector2(pts[pts.size() - 1].x, pts[pts.size() - 1].z)
	var half := float(rec.width) * 0.5
	var kind := 2 if rec.kind == "marked" else 1
	pts.append({"x": pt.x, "z": pt.y})
	_seg_register(last, pt, half, kind)
	_know_sig = _calc_sig()
	if pts.size() >= MAX_PROBE_POINTS and state.probes.size() < MAX_PROBES:
		return _add_probe_record(str(rec.kind), pt, str(rec.scout))
	return rec

func _stumble(u: Dictionary, cur: Vector2, nxt: Vector2) -> void:
	var hz_cfg: Dictionary = {}
	var hz_id := "otro"
	var best := INF
	for hz in map_data().hazards:
		if _inactive.has(str(hz.id)):
			continue
		var c := Vector2(float(hz.center[0]), float(hz.center[1]))
		var d := nxt.distance_to(c) - float(hz.radius_m)
		if d < best and d <= BLEND_DEFAULT + float(map_data().knowledge.probe_lane_width_m):
			best = d
			hz_cfg = hz.stumble
			hz_id = str(hz.id)
	if hz_cfg.is_empty():
		for ch in map_data().channels:
			var cpts := _vpoly(ch.centerline)
			var dc := INF
			for ci in range(cpts.size() - 1):
				dc = minf(dc, nxt.distance_to(Geometry2D.get_closest_point_to_segment(nxt, cpts[ci], cpts[ci + 1])))
			if dc <= float(ch.half_width_m) + float(ch.blend_m) and ch.has("stumble"):
				hz_cfg = ch.stumble
				hz_id = str(ch.id)
	if hz_cfg.is_empty():
		hz_cfg = map_data().hazards[0].stumble
	u.path = []
	u.stage = "stumbling"
	u.stumble_remaining = float(hz_cfg.stop_s)
	u.fatigue = minf(100.0, float(u.fatigue) + float(hz_cfg.fatigue))
	u.strength = maxf(0.0, float(u.strength) - float(hz_cfg.strength_loss))
	state.stats.stumbles = int(state.stats.stumbles) + 1
	state.stats.horses_lost = float(state.stats.horses_lost) + float(hz_cfg.strength_loss)
	state.stats.stumble_at[hz_id] = int(state.stats.stumble_at.get(hz_id, 0)) + 1
	var dir := (nxt - cur).normalized() if nxt.distance_to(cur) > 0.001 else Vector2(1, 0)
	var lane_len := float(map_data().knowledge.probe_lane_width_m)
	var tip := cur + dir * lane_len
	tip.x = clampf(tip.x, 0.0, map_size().x)
	tip.y = clampf(tip.y, 0.0, map_size().y)
	if state.probes.size() < MAX_PROBES:
		var rec := _add_probe_record("lane", cur, "")
		_probe_add_point(rec, tip)
		state.stats.probe_m = float(state.stats.probe_m) + cur.distance_to(tip)
	_touch_hazards(nxt, BLEND_DEFAULT)
	_know_sig = -1
	_event("%s cae en un hoyo del fondo que no estaba reconocido: se pierden caballos y jinetes, y el grupo queda detenido %d s (+%d fatiga, −%d fuerza)." % [u.name, roundi(hz_cfg.stop_s), roundi(hz_cfg.fatigue), roundi(hz_cfg.strength_loss)], "stumble", {"unit": u.id, "pos": {"x": nxt.x, "z": nxt.y}})

func _nearest_dry_point(from: Vector2, mounted: bool) -> Vector2:
	## Punto firme y seco de la playa mas cercano; Vector2(INF, INF) si no hay.
	var firm := float(_mv().mud.firm_min_height_m)
	for r in range(0, 400, 4):
		var steps := 1 if r == 0 else 24
		for k in range(steps):
			var a := TAU * float(k) / float(steps)
			var p := from + Vector2(cos(a), sin(a)) * float(r)
			if not _in_map(p) or p.x > _shore_x(p.y) + _beach_margin():
				continue
			if _land_kind(p.x, p.y, 0.0) != "":
				continue
			if water_depth_at(p.x, p.y) <= -firm and speed_at(p.x, p.y, "trot", mounted) > 0.0:
				return p
	return Vector2(INF, INF)

func _rescue_submerged(u: Dictionary) -> void:
	var dry := _nearest_dry_point(Vector2(u.x, u.z), u.mounted)
	if not is_finite(dry.x):
		return
	u.x = dry.x
	u.z = dry.y
	_clear_motion(u)
	u.order = {}
	u.fatigue = minf(100.0, float(u.fatigue) + 10.0)
	_event("%s quedó cubierto por el agua y es llevado de vuelta a un punto seco de la playa (+10 fatiga). Deberá dar otra orden." % u.name, "warning", {"unit": u.id, "pos": {"x": u.x, "z": u.z}})

# --- exploradores ---------------------------------------------------------

func _scout_speed(p: Vector2, s: Dictionary = {}) -> float:
	var a: Dictionary = map_data().actions.probe
	var v := float(a.speed_mps_water) if water_depth_at(p.x, p.y) > 0.0 else float(a.speed_mps_dry)
	if bool(s.get("cautious", false)) and str(s.get("stage", "")) == "probing" and exposure_at(p.x, p.y) > 0.0:
		v *= float(map_data().actions.probe_careful.speed_mult)  ## solo se avanza agachado donde el buque alcanza
	return v

func _scout_arrived(s: Dictionary) -> void:
	var act := str(s.order.get("action", ""))
	var here := Vector2(s.x, s.z)
	if act == "mark_ford":
		var pts: Array = s.order.points
		var a := Vector2(pts[0].x, pts[0].z)
		var b := Vector2(pts[1].x, pts[1].z)
		s.stage = "marking"
		s.work_remaining = a.distance_to(b)
		s.mark_done = 0.0
		s.mark_charged = 0
		s.probe_id = str(_add_probe_record("marked", a, str(s.id)).id)
		s.x = a.x
		s.z = a.y
		return
	if act == "probe":
		var rec := _probe_by_id(str(s.get("probe_id", "")))
		if not rec.is_empty():
			_probe_add_point(rec, here)
		_event("%s terminó el sondeo." % s.name, "recon", {"unit": s.id, "pos": {"x": s.x, "z": s.z}})
	s.stage = "idle"
	s.order = {}
	s.path = []
	s.work_remaining = 0.0
	s.erase("probe_id")

func _scout_stop(s: Dictionary, cur: Vector2, nxt: Vector2, why: String) -> void:
	## El explorador se detiene en el borde: revela esa celda (lane corto) y descubre lo que toque.
	var dir := (nxt - cur).normalized() if nxt.distance_to(cur) > 0.001 else Vector2(1, 0)
	var rec := _probe_by_id(str(s.get("probe_id", "")))
	if not rec.is_empty():
		rec = _probe_add_point(rec, cur + dir * minf(3.0, cur.distance_to(nxt) + 1.0))
	var reach := float(map_data().knowledge.probe_lane_width_m) * 0.5
	## El explorador sondea con la lanza desde el borde: si lo que lo frena es un pozo conocido por su centro, la franja llega hasta ahí.
	for hz in map_data().hazards:
		if _inactive.has(str(hz.id)):
			continue
		var c := Vector2(float(hz.center[0]), float(hz.center[1]))
		if nxt.distance_to(c) <= float(hz.radius_m) + reach + BLEND_DEFAULT and not rec.is_empty():
			rec = _probe_add_point(rec, c)
	_touch_hazards(nxt, reach + BLEND_DEFAULT)
	_know_sig = -1
	s.stage = "idle"
	s.order = {}
	s.path = []
	s.erase("probe_id")
	_event("%s se detiene: %s" % [s.name, why], "recon", {"unit": s.id, "pos": {"x": nxt.x, "z": nxt.y}})

func _step_scout(s: Dictionary, dt: float) -> void:
	if s.stage in ["idle", "lost"]:
		return
	if s.stage == "marking":
		_step_marking(s, dt)
		return
	if s.path.is_empty():
		_scout_arrived(s)
		return
	var cur := Vector2(s.x, s.z)
	var p: Dictionary = s.path[0]
	var wp := Vector2(p.x, p.z)
	var nxt := cur.move_toward(wp, _scout_speed(cur, s) * dt)
	if _land_kind(nxt.x, nxt.y, 0.0) not in ["", "bajada"]:
		_scout_stop(s, cur, nxt, "el terreno no es transitable.")
		return
	if s.stage == "probing":
		if water_depth_at(nxt.x, nxt.y) > float(map_data().actions.probe.max_depth_m):
			_scout_stop(s, cur, nxt, "el fondo supera %.1f m y no se puede seguir sondeando." % float(map_data().actions.probe.max_depth_m))
			return
	s.x = nxt.x
	s.z = nxt.y
	if s.stage == "probing":
		var rec := _probe_by_id(str(s.get("probe_id", "")))
		if rec.is_empty():
			rec = _add_probe_record("lane", cur, str(s.id))
			s.probe_id = str(rec.id)
		var pts: Array = rec.pts
		var last := Vector2(pts[pts.size() - 1].x, pts[pts.size() - 1].z)
		if nxt.distance_to(last) >= PROBE_POINT_SPACING:
			if water_depth_at(nxt.x, nxt.y) > 0.0:
				state.stats.probe_m = float(state.stats.probe_m) + nxt.distance_to(last)
			rec = _probe_add_point(rec, nxt)
			s.probe_id = str(rec.id)
			_touch_hazards(nxt, float(map_data().knowledge.probe_lane_width_m) * 0.5)
	if nxt.distance_to(wp) < 0.01:
		s.path.pop_front()
		if s.path.is_empty():
			_scout_arrived(s)

func _step_marking(s: Dictionary, dt: float) -> void:
	var a: Dictionary = map_data().actions.mark_ford
	var pts: Array = s.order.points
	var pa := Vector2(pts[0].x, pts[0].z)
	var pb := Vector2(pts[1].x, pts[1].z)
	var total := pa.distance_to(pb)
	var done := float(s.get("mark_done", 0.0))
	var adv := minf(float(a.work_mps) * dt, total - done)
	var blocks := ceili((done + adv) / 10.0 - 0.000001)
	var charged := int(s.get("mark_charged", 0))
	if blocks > charged:
		if int(state.balizas) <= 0:
			_event("%s se queda sin balizas: el tramo trabajado queda marcado." % s.name, "ford", {"unit": s.id, "pos": {"x": s.x, "z": s.z}})
			_finish_marking(s)
			return
		state.balizas = int(state.balizas) - 1
		state.stats.balizas_used = int(state.stats.balizas_used) + 1
		s.mark_charged = charged + 1
	done += adv
	s.mark_done = done
	state.stats.marked_m = float(state.stats.marked_m) + adv
	var pos := pa.lerp(pb, done / total) if total > 0.0 else pa
	s.x = pos.x
	s.z = pos.y
	s.work_remaining = total - done
	var rec := _probe_by_id(str(s.get("probe_id", "")))
	if not rec.is_empty():
		var last := Vector2(rec.pts[rec.pts.size() - 1].x, rec.pts[rec.pts.size() - 1].z)
		if pos.distance_to(last) >= MARK_POINT_SPACING or done >= total - 0.000001:
			rec = _probe_add_point(rec, pos)
			s.probe_id = str(rec.id)
	if done >= total - 0.000001:
		_event("%s termina de marcar el vado (%d m)." % [s.name, roundi(total)], "ford", {"unit": s.id, "pos": {"x": s.x, "z": s.z}})
		_finish_marking(s)

func _finish_marking(s: Dictionary) -> void:
	s.stage = "idle"
	s.order = {}
	s.path = []
	s.work_remaining = 0.0
	s.erase("probe_id")
	s.erase("mark_done")
	s.erase("mark_charged")

# --- fuego -----------------------------------------------------------------

func _artillery() -> void:
	var fire: Dictionary = map_data().ship.fire
	var targets: Array = []
	var weights: Array = []
	for u in state.units:
		if exposure_for(u) > 0.0:
			targets.append(u)
			weights.append(float(fire.target_weights.group))
	for s in state.scouts:
		if int(s.hp) > 0 and s.stage != "lost" and exposure_at(float(s.x), float(s.z)) > 0.0:
			targets.append(s)
			weights.append(float(fire.target_weights.scout))
	if targets.is_empty():
		return
	var total := 0.0
	for w in weights:
		total += float(w)
	var roll := _random() * total
	var pick: Dictionary = targets[targets.size() - 1]
	for i in range(targets.size()):
		roll -= float(weights[i])
		if roll <= 0.0:
			pick = targets[i]
			break
	state.stats.shots_taken = int(state.stats.shots_taken) + 1
	if pick.has("hp"):
		## Un explorador pierde 1 de salud si el impacto prospera con probabilidad = exposicion (el fuego de distraccion lo protege).
		var hit_p := exposure_at(float(pick.x), float(pick.z)) * float(fire.get("scout_hit_chance", 1.0))
		if bool(pick.get("cautious", false)) and str(pick.stage) == "probing":
			hit_p *= float(map_data().actions.probe_careful.hit_mult)
		if _random() >= hit_p:
			_event("El buque dispara cerca de %s y no lo alcanza." % pick.name, "shot", {"unit": pick.id, "pos": {"x": pick.x, "z": pick.z}})
			return
		pick.hp = maxi(0, int(pick.hp) - 1)
		_event("El buque dispara sobre %s." % pick.name, "shot", {"unit": pick.id, "pos": {"x": pick.x, "z": pick.z}})
		if int(pick.hp) <= 0:
			pick.stage = "lost"
			pick.order = {}
			pick.path = []
			pick.work_remaining = 0.0
			state.stats.scouts_lost = int(state.stats.scouts_lost) + 1
			_event("%s cae abatido." % pick.name, "warning", {"unit": pick.id, "pos": {"x": pick.x, "z": pick.z}})
		return
	var expo := exposure_for(pick)
	var damage := lerpf(float(fire.damage_min), float(fire.damage_max), _random()) * expo * maxf(float(fire.morale_floor), float(state.crew_morale) / 100.0)
	pick.strength = maxf(0.0, float(pick.strength) - damage)
	pick.fatigue = minf(100.0, float(pick.fatigue) + damage * 0.2)
	state.stats.damage_taken = float(state.stats.damage_taken) + damage
	_event("Artillería sobre %s: −%.1f efectivos. Exposición %s." % [pick.name, damage, "baja" if expo < 0.5 else "alta"], "shot", {"unit": pick.id, "pos": {"x": pick.x, "z": pick.z}})

# --- parte de campana -------------------------------------------------------

func _history_lines() -> Array:
	var m := map_data()
	var ship: Dictionary = m.ship
	var vado: Dictionary = {}
	for fd in m.fords:
		if str(fd.id) == "vado_buque":
			vado = fd
	var depth_low := float(m.tide.level_low_m) - float(vado.top_m)
	var tags: Dictionary = {}
	for g in m.groups:
		tags[str(g.id)] = g
	return [
		{"text": "Un mercante británico de %d cañones, que combatió el día de la rendición, fue tomado por caballería al cerrar el 12 de agosto de 1806 por una súbita bajada del río (Gillespie 1818, documentado en transcripción; sin tipo, tonelaje ni capitán documentados)." % int(ship.guns_total), "tag": str(ship.get("tag_parts", {}).get("descripcion", "documentado"))},
		{"text": "Fuentes divulgativas (edisalta, La Nación, Recalada; aún no incorporadas a la bibliografía S1-S8) lo ubican varado frente al Retiro, cerca de la Plaza de Toros; Gillespie no da el lugar, por eso el lugar es reconstrucción. La investigación de apoyo lo trata como una zona, no como un punto.", "tag": "reconstruccion"},
		{"text": "Que la caballería fuera la de Pueyrredón figura en Concha (15 de agosto de 1806) y en Liniers (Archivo Pueyrredón, t. I, p. 54) según la investigación del repo, sin cotejo propio del original (por eso se rotula Tradición); Obligado 1920 cuenta además que Liniers dio la orden de avanzar.", "tag": str(tags["zavala"].tag)},
		{"text": "Güemes al frente de los jinetes es una tradición no probada (Ideario pp. 33, 390-392): Obligado 1920 lo hace ayudante de Liniers, y Gillespie no nombra al jefe.", "tag": str(tags["guemes"].tag)},
		{"text": "La distancia de ~%d m al buque (un material bonaerense de 2006 habla de ~400 m desde la barranca: tradición discutida; el juego mide %d m desde el pie de la barranca) y los %.1f m de agua del vado con el río en mínimo son diseño." % [roundi(float(ship.distance_from_shore_high_m)), roundi(float(ship.distance_from_shore_high_m)), depth_low], "tag": str(ship.distance_tag)},
		{"text": "Bancos, canal, vados, hoyos, tiempos de bajante, fuerzas, munición, el cuerpo a cuerpo y el puesto de Liniers son diseño del juego: no existe sondeo de 1806 del Retiro.", "tag": "diseno"}
	]

func campaign_report() -> Dictionary:
	var m := map_data()
	var st: Dictionary = state.stats
	var groups: Array = []
	for u in state.units:
		var start := float(st.start_strength.get(u.id, 100.0))
		groups.append({"id": u.id, "name": u.name, "tag": str(u.get("tag", "diseno")), "start_strength": start, "end_strength": float(u.strength),
			"loss_pct": clampf((start - float(u.strength)) / start * 100.0, 0.0, 100.0) if start > 0.0 else 0.0})
	## Bajas reales = todo lo que el fuego, el cuerpo a cuerpo, el agua, los hoyos y los contraataques quitaron (nunca negativas: reunir jinetes no las compensa).
	var start_total := 0.0
	for sid in st.start_strength:
		start_total += float(st.start_strength[sid])
	var casualties := float(st.damage_taken) + float(st.melee_loss) + float(st.drowned) + float(st.horses_lost) + float(st.counter_loss)
	var loss_total_pct := clampf(casualties / maxf(1.0, start_total + float(st.muster_gain)) * 100.0, 0.0, 100.0)
	var title := "En curso"
	match str(state.get("defeat_cause", "")):
		"plazo":
			title = "Plazo agotado"
		"dispersos":
			title = "Grupos dispersos"
		"retirada":
			title = "Retirada general"
	if state.status == "victory":
		title = "Buque capturado"
	var cs := float(st.bank_s.central)
	var ss := float(st.bank_s.sur)
	var route := "ninguna"
	if cs >= ROUTE_BANK_MIN_S and ss >= ROUTE_BANK_MIN_S:
		route = "mixta"
	elif cs >= ROUTE_BANK_MIN_S:
		route = "central"
	elif ss >= ROUTE_BANK_MIN_S:
		route = "sur"
	var notes: Array = []
	for hid in st.stumble_at:
		var hname := str(hid)
		for hz in m.hazards:
			if str(hz.id) == hid:
				hname = str(hz.name).to_lower()
		notes.append("Tropezaron en el %s (%d %s)" % [hname, int(st.stumble_at[hid]), "vez" if int(st.stumble_at[hid]) == 1 else "veces"])
	if route != "ninguna":
		notes.append("Ruta: banco %s." % route)
	if float(st.boarded_at) >= 0.0:
		notes.append("Abordaje a los %d s con el río a %.2f m." % [roundi(st.boarded_at), float(st.level_at_boarding)])
	if int(st.counter_hits) + int(st.counter_repelled) > 0:
		notes.append("Contraataques de la dotación: %d rechazados, %d sin contestar." % [int(st.counter_repelled), int(st.counter_hits)])
	return {"status": state.status, "reason": state.reason, "elapsed": float(state.elapsed), "outcome_title": title,
		"groups": groups, "route": route, "route_notes": notes, "casualties": casualties, "loss_total_pct": loss_total_pct,
		"counter_hits": int(st.counter_hits), "counter_repelled": int(st.counter_repelled), "counter_loss": float(st.counter_loss),
		"evacuations": int(st.evacuations), "wounded_recovered": float(st.wounded_recovered), "halted_by_expiry": int(st.halted_by_expiry),
		"hidden_picks": (state.get("hidden", {}).get("picks", {}) as Dictionary).duplicate(true),
		"probe_m": float(st.probe_m), "marked_m": float(st.marked_m), "stumbles": int(st.stumbles), "ammo_used": int(st.ammo_used),
		"balizas_used": int(st.balizas_used), "fire_support_uses": int(st.fire_support_uses), "scouts_lost": int(st.scouts_lost),
		"horses_lost": float(st.horses_lost), "melee_loss": float(st.melee_loss), "drowned": float(st.drowned),
		"shots_taken": int(st.shots_taken), "damage_taken": float(st.damage_taken), "level_at_boarding": float(st.level_at_boarding), "boarded_at": float(st.boarded_at),
		"exposure_s": (st.exposure_s as Dictionary).duplicate(true), "history": _history_lines()}

func issue_campaign_order(group_id: String, action: String, sector_id: String = "") -> Dictionary:
	if state.get("scenario", "") != "norte" or state.get("status", "") != "playing":
		return _no("La campaña no está activa.")
	if action == "cancel":
		return cancel_order(group_id)
	var u := get_unit(group_id)
	if u.is_empty():
		return _no("Agrupación desconocida.")
	if sector_id.is_empty():
		sector_id = str(u.sector_id)
	var check := _validate_campaign_order(u, action, sector_id)
	if not check.ok:
		return check
	u.order = {"action": action, "sector_id": sector_id}
	u.stage = "ordered"
	_record_order(group_id, action, {"sector_id": sector_id})
	return {"ok": true, "reason": "Orden preparada. Podés cambiarla o cancelarla antes de resolver la ronda."}

func legal_campaign_actions(group_id: String, sector_id: String) -> Array:
	var u := get_unit(group_id)
	var actions: Array = []
	if u.is_empty() or state.get("scenario", "") != "norte" or state.get("status", "") != "playing":
		return actions
	for action in CAMPAIGN_ACTIONS:
		if _validate_campaign_order(u, action, sector_id).ok:
			actions.append(action)
	return actions

func campaign_order_reason(group_id: String, action: String, sector_id: String) -> String:
	var u := get_unit(group_id)
	if u.is_empty():
		return "Agrupación desconocida."
	return str(_validate_campaign_order(u, action, sector_id).reason)

func _validate_campaign_order(u: Dictionary, action: String, sector_id: String) -> Dictionary:
	if float(u.strength) <= 5.0:
		return _no("La agrupación está dispersa.")
	if action not in CAMPAIGN_ACTIONS:
		return _no("Orden de campaña desconocida.")
	var s := get_sector(sector_id)
	var origin := get_sector(str(u.sector_id))
	if s.is_empty() or origin.is_empty():
		return _no("Sector desconocido.")
	var same := sector_id == str(u.sector_id)
	if not same and sector_id not in origin.neighbors:
		return _no("El sector no es vecino: desplazate por las rutas del mapa.")
	if action == "rest":
		if not same:
			return _no("El descanso se realiza en el sector actual.")
		if s.enemy:
			return _no("No se puede descansar en un sector ocupado. Replegate primero.")
		if float(state.stores) < 8:
			return _no("Faltan 8 reservas para reponer esta agrupación. Protegé víveres.")
	if action == "move" and same:
		return _no("La agrupación ya se encuentra en ese sector.")
	if action == "withdraw" and (same or s.enemy):
		return _no("Elegí un sector vecino sin ocupación enemiga para replegarte.")
	if action in ["raid", "assault"]:
		if not s.known:
			return _no("Primero reconocé ese sector con exploradores.")
		if float(u.supply) < (18.0 if action == "assault" else 11.0):
			return _no("Faltan suministros en la agrupación. Descansá en un sector seguro.")
		if float(u.fatigue) > 78.0:
			return _no("La fatiga impide otro combate. Replegate o descansá.")
		if float(u.strength) < (45.0 if action == "assault" else 25.0):
			return _no("No quedan fuerzas suficientes para esa operación.")
	if action == "raid" and sector_id not in ["humahuaca", "quebrada", "jujuy", "salta", "oran"]:
		return _no("No pasa un abastecimiento realista por ese sector.")
	if action == "protect":
		if not same:
			return _no("La protección de víveres se organiza en el sector actual.")
		if s.enemy:
			return _no("El sector está ocupado; trasladá la partida a una zona propia.")
		if int(s.crates) <= 0:
			return _no("Ya se retiraron los víveres de este sector. Elegí otro lugar.")
	if action == "assault":
		if u.id != "arias" or sector_id != "humahuaca":
			return _no("La operación de Humahuaca corresponde a Manuel Eduardo Arias.")
		if int(state.round) < 7:
			return _no("Humahuaca estará disponible desde la ronda del 1 de marzo de 1817.")
		if state.humahuaca:
			return _no("Humahuaca ya fue recuperada.")
	return {"ok": true, "reason": "Disponible."}

func enemy_choices() -> Dictionary:
	if state.get("scenario", "") != "norte":
		return {}
	var choices := {"forage": "Buscar víveres en sectores conocidos para sostener al ejército invasor.",
		"guard": "Proteger comunicaciones y convoyes; reduce el efecto de los hostigamientos de esta ronda."}
	if _enemy_can_advance():
		choices["advance"] = "Avanzar hacia Salta: gana presencia, pero consume abastecimientos."
	if _enemy_can_retreat():
		choices["retreat"] = "Ordenar una retirada: la combinación de pérdidas, suministros y comunicaciones vuelve inviable la campaña."
	return choices

func enemy_fallback() -> String:
	if _enemy_can_retreat():
		return "retreat"
	if float(state.enemy.supply) < 58.0:
		return "forage"
	if _enemy_can_advance() and int(state.round) >= 3:
		return "advance"
	return "guard"

func enemy_observation() -> Dictionary:
	if state.get("scenario", "") != "norte":
		return {}
	var visible: Array = []
	for u in state.units:
		if int(u.revealed_until) >= int(state.round):
			visible.append({"sector": u.sector_id, "force_estimate": int(round(float(u.strength) / 20.0) * 20), "last_observed_round": state.round})
	var known: Array = []
	var resources: Array = []
	for s in state.sectors:
		if s.enemy or s.id == state.enemy.position:
			known.append({"id": s.id, "occupied": s.enemy})
			resources.append({"sector": s.id, "foraging_blocked": int(s.protected_until) >= int(state.round)})
	return {"actor": "ejercito_realista", "scenario": "norte", "round": state.round,
		"self_forces": "agrupaciones agregadas", "self_supplies": state.enemy.supply,
		"self_cohesion": state.enemy.cohesion, "known_sectors": known, "visible_enemies": visible,
		"visible_resources": resources, "public_events": {"humahuaca_lost": state.humahuaca, "salta_occupied": state.enemy.occupied_salta},
		"goal": "Sostener la invasión; conservar tropas si continuar resulta inviable.",
		"situation": {"own_communications": state.enemy.communications, "position": state.enemy.position}}

## Avanzar de la Quebrada a Jujuy es libre; entrar en Salta solo desde la ronda de la ocupacion documentada.
func _enemy_can_advance() -> bool:
	if state.get("scenario", "") != "norte" or state.enemy.occupied_salta:
		return false
	return str(state.enemy.position) == "quebrada" or int(state.round) >= SALTA_OCCUPATION_ROUND

func _enemy_can_retreat() -> bool:
	if state.get("scenario", "") != "norte" or int(state.round) < RETREAT_MIN_ROUND or int(state.pressure_actions) < RETREAT_MIN_PRESSURE:
		return false
	return (float(state.enemy.supply) <= 22.0 and float(state.enemy.cohesion) <= 42.0 and float(state.enemy.communications) <= 45.0) or (float(state.enemy.cohesion) <= 22.0 and float(state.enemy.supply) <= 38.0)

func resolve_round(enemy_intent: String = "forage") -> Array:
	_events = []
	if state.get("scenario", "") != "norte" or state.get("status", "") != "playing":
		return _events
	var choices := enemy_choices()
	if not choices.has(enemy_intent):
		enemy_intent = enemy_fallback()
	state.enemy.intent = enemy_intent
	var before: Dictionary = {"enemy_supply": state.enemy.supply, "enemy_cohesion": state.enemy.cohesion,
		"enemy_communications": state.enemy.communications, "population": state.population, "stores": state.stores}
	var protected_this_round := 0
	for u in state.units:
		var order: Dictionary = u.order.duplicate(true)
		u.order = {}
		u.stage = "ready"
		if order.is_empty() or float(u.strength) <= 5.0:
			u.fatigue = maxf(0.0, float(u.fatigue) - 3.0)
			continue
		var action := str(order.get("action", ""))
		var sector_id := str(order.get("sector_id", ""))
		var check := _validate_campaign_order(u, action, sector_id)
		if not check.ok:
			_event("%s no ejecutó la orden: %s" % [u.name, check.reason], "blocked")
			continue
		var s := get_sector(sector_id)
		if action in ["move", "withdraw", "raid", "assault"]:
			u.sector_id = sector_id
			u.x = float(s.x)
			u.z = float(s.z)
		if action == "move":
			u.fatigue = minf(100.0, float(u.fatigue) + 7.0)
			u.supply = maxf(0.0, float(u.supply) - 4.0)
			s.known = true
			_event("%s se desplaza a %s." % [u.name, s.name], "move")
		elif action == "withdraw":
			u.fatigue = maxf(0.0, float(u.fatigue) - 16.0)
			u.supply = maxf(0.0, float(u.supply) - 3.0)
			u.revealed_until = 0
			_event("%s se repliega a %s y conserva sus fuerzas." % [u.name, s.name], "withdraw")
		elif action == "scout":
			s.known = true
			s.intel_until = int(state.round) + 3
			for adjacent in s.neighbors:
				get_sector(adjacent).known = true
			u.fatigue = minf(100.0, float(u.fatigue) + 5.0)
			u.supply = maxf(0.0, float(u.supply) - 3.0)
			_event("Exploradores de %s reconocen %s. Inteligencia útil durante tres rondas." % [u.name, s.name], "scout")
		elif action == "protect":
			s.crates = maxi(0, int(s.crates) - 1)
			s.protected_until = int(state.round) + 2
			state.stores = minf(150.0, float(state.stores) + 18.0)
			state.population = minf(100.0, float(state.population) + 9.0)
			u.fatigue = minf(100.0, float(u.fatigue) + 5.0)
			protected_this_round += 1
			_event("Víveres y animales de %s a resguardo: +18 reservas y +9 apoyo. El enemigo encontrará menos recursos." % s.name, "protect")
		elif action == "rest":
			state.stores = maxf(0.0, float(state.stores) - 8.0)
			u.strength = minf(100.0, float(u.strength) + 9.0)
			u.supply = minf(100.0, float(u.supply) + 27.0)
			u.fatigue = maxf(0.0, float(u.fatigue) - 34.0)
			u.revealed_until = 0
			_event("%s repone caballos y fuerzas: +27 suministros, −34 fatiga; cuesta 8 reservas." % u.name, "rest")
		elif action == "raid":
			_resolve_raid(u, s, enemy_intent)
		elif action == "assault":
			state.humahuaca = true
			s.enemy = false
			state.enemy.supply = maxf(0.0, float(state.enemy.supply) - 12.0)
			state.enemy.cohesion = maxf(0.0, float(state.enemy.cohesion) - 8.0)
			state.enemy.communications = maxf(0.0, float(state.enemy.communications) - 20.0)
			state.pressure_actions = int(state.pressure_actions) + 2
			u.strength = maxf(0.0, float(u.strength) - 10.0)
			u.supply = maxf(0.0, float(u.supply) - 18.0)
			u.fatigue = minf(100.0, float(u.fatigue) + 22.0)
			u.revealed_until = int(state.round) + 1
			_event("Arias recupera Humahuaca: la operación coordinada neutraliza artillería, cuartel y depósito de pólvora. −20 comunicaciones realistas.", "humahuaca")
	_apply_enemy(enemy_intent, protected_this_round)
	state.population = maxf(0.0, float(state.population) - (6.0 if state.enemy.occupied_salta else 3.5))
	state.stores = maxf(0.0, float(state.stores) - 5.0)
	var surviving := 0
	for u in state.units:
		u.supply = maxf(0.0, float(u.supply) - 3.0)
		if float(u.supply) <= 0.0:
			u.strength = maxf(0.0, float(u.strength) - 9.0)
		if float(state.stores) <= 0.0:
			u.fatigue = minf(100.0, float(u.fatigue) + 5.0)
		if float(u.strength) > 5.0:
			surviving += 1
		else:
			u.stage = "routed"
	if int(state.round) == 8:
		_event("Llega una noticia del frente de Chile: Chacabuco (12 de febrero) da sentido estratégico a sostener el norte. Mensaje dramatizado; San Martín no aparece como refuerzo en Salta.", "history")
	if surviving == 0 or float(state.population) <= 10.0:
		_finish("defeat", "La defensa perdió sus agrupaciones o el sostén de las poblaciones. La invasión conserva capacidad de continuar.")
	elif _enemy_can_retreat():
		var chronology := "La presión volvió insostenible la invasión y forzó su retirada."
		if int(state.round) < 13:
			chronology += " Desenlace alternativo anticipado: la retirada histórica ocurrió a comienzos de mayo."
		_finish("victory", chronology)
	elif int(state.round) >= MAX_ROUNDS:
		_finish("defeat", "Llegó mayo y el ejército invasor todavía mantiene recursos y cohesión. Esperar sin cortarle el abastecimiento no alcanza.")
	state.last_results = [{"label": "Abastecimiento realista", "before": before.enemy_supply, "after": state.enemy.supply},
		{"label": "Cohesión realista", "before": before.enemy_cohesion, "after": state.enemy.cohesion},
		{"label": "Comunicaciones realistas", "before": before.enemy_communications, "after": state.enemy.communications},
		{"label": "Apoyo de la población", "before": before.population, "after": state.population},
		{"label": "Reservas propias", "before": before.stores, "after": state.stores}]
	if state.status == "playing":
		state.round = int(state.round) + 1
		state.date = DATES[mini(MAX_ROUNDS - 1, int(state.round) - 1)]
	state.state_version = int(state.state_version) + 1
	return _events

func _resolve_raid(u: Dictionary, s: Dictionary, intent: String) -> void:
	var informed := int(s.intel_until) >= int(state.round)
	var guard_factor := 0.68 if intent == "guard" else 1.0
	var effectiveness := maxf(0.45, (float(u.strength) / 100.0) * (1.0 - float(u.fatigue) * 0.003))
	var supply_loss := (20.0 if informed else 14.0) * effectiveness * guard_factor
	var casualties := (4.0 if informed else 8.0) + _random() * 4.0
	if s.id == state.enemy.position:
		casualties += 3.0
	if intent == "guard":
		casualties += 3.0
	u.strength = maxf(0.0, float(u.strength) - casualties)
	u.supply = maxf(0.0, float(u.supply) - 11.0)
	u.fatigue = minf(100.0, float(u.fatigue) + (16.0 if informed else 21.0))
	u.revealed_until = int(state.round) + 1
	state.enemy.supply = maxf(0.0, float(state.enemy.supply) - supply_loss)
	state.enemy.cohesion = maxf(0.0, float(state.enemy.cohesion) - 4.0 * effectiveness)
	state.enemy.communications = maxf(0.0, float(state.enemy.communications) - 6.0 * effectiveness)
	state.pressure_actions = int(state.pressure_actions) + 1
	_event("%s hostiga %s: −%.1f abastecimiento enemigo; pierde %.1f efectivos. %s" % [u.name, s.name, supply_loss, casualties, "La exploración redujo el riesgo." if informed else "Sin reconocimiento reciente, el riesgo fue mayor."], "raid")

func _apply_enemy(intent: String, protected_this_round: int) -> void:
	state.enemy.supply = maxf(0.0, float(state.enemy.supply) - 6.0)
	state.enemy.communications = maxf(0.0, float(state.enemy.communications) - (2.0 if state.humahuaca else 0.5))
	if float(state.enemy.supply) < 30.0:
		state.enemy.cohesion = maxf(0.0, float(state.enemy.cohesion) - 3.0)
	else:
		state.enemy.cohesion = minf(100.0, float(state.enemy.cohesion) + 1.0)
	var guarded_sectors := protected_this_round
	for s in state.sectors:
		if int(s.protected_until) >= int(state.round):
			guarded_sectors += 1
	if intent == "forage":
		var recovered := maxf(0.0, 16.0 - guarded_sectors * 2.5 - (4.0 if state.humahuaca else 0.0))
		state.enemy.supply = minf(100.0, float(state.enemy.supply) + recovered)
		state.population = maxf(0.0, float(state.population) - (4.0 if recovered > 7.0 else 0.0))
		_event("Los realistas buscan víveres: recuperan %.0f abastecimiento. La protección de recursos limita esa recuperación." % recovered, "enemy")
	elif intent == "guard":
		state.enemy.communications = minf(100.0, float(state.enemy.communications) + 3.0)
		_event("El invasor escolta sus convoyes. Los hostigamientos causaron menos daño y mayor riesgo.", "enemy")
	elif intent == "advance":
		state.enemy.supply = maxf(0.0, float(state.enemy.supply) - 7.0)
		if state.enemy.position == "quebrada":
			_enemy_moves_to("jujuy")
		else:
			_enemy_moves_to("salta")
			state.enemy.occupied_salta = true
		_event("Avance realista hacia %s: consume 7 abastecimiento adicional." % get_sector(state.enemy.position).name, "enemy")
	elif intent == "retreat":
		_event("El mando realista ordena preparar su retirada ante la situación insostenible.", "enemy")
	if int(state.round) >= SALTA_OCCUPATION_ROUND and not state.enemy.occupied_salta:
		state.enemy.occupied_salta = true
		_enemy_moves_to("salta")
		_event("Salta queda ocupada por los realistas (en esta ronda, del 12 al 22 de abril de 1817, se sitúa la ocupación documentada del 15 de abril). La campaña sigue: el invasor necesita abastecimientos y comunicaciones para sostenerse.", "occupation")

func _enemy_moves_to(sector_id: String) -> void:
	# Marca solo el sector donde esta el invasor. Humahuaca se conserva como foco hasta que Arias lo recupere.
	var old := str(state.enemy.position)
	if old != sector_id and old != "humahuaca":
		get_sector(old).enemy = false
	state.enemy.position = sector_id
	get_sector(sector_id).enemy = true

func record_external_decision(decision: Dictionary) -> bool:
	var context: Dictionary = decision.get("context", {})
	if state.is_empty() or state.status != "playing" or str(context.get("game_id", "")) != str(state.game_id) or int(context.get("round", -1)) != int(state.round) or int(context.get("state_version", -1)) != int(state.state_version):
		return false
	if not enemy_choices().has(str(decision.get("choice", ""))):
		return false
	state.external_decisions.append(decision.duplicate(true))
	return true


func _random() -> float:
	state.rng_state = (int(state.rng_state) * 48271) % 2147483647
	return float(state.rng_state) / 2147483647.0

func _finish(status: String, reason: String, cause: String = "") -> void:
	if state.status != "playing":
		return
	state.status = status
	state.reason = reason
	if state.has("defeat_cause"):
		state.defeat_cause = cause if status == "defeat" else ""
	for u in state.units:
		u.order = {}
		u.path = []
		if u.has("work"):
			u.work = {}
			u.stumble_remaining = 0.0
	for s in state.get("scouts", []):
		s.order = {}
		s.path = []
		s.work_remaining = 0.0
		if s.stage != "lost":
			s.stage = "idle"
		s.erase("probe_id")
		s.erase("mark_done")
		s.erase("mark_charged")
	_event(reason, status)

func _event(message: String, kind: String = "info", extra: Dictionary = {}) -> void:
	var event := {"time": state.get("elapsed", 0.0), "round": state.get("round", 1), "text": message, "kind": kind}
	for key in extra:
		event[key] = extra[key]
	state.log.append(event)
	if state.log.size() > LOG_MAX:
		state.log = (state.log as Array).slice(state.log.size() - LOG_MAX)
	_events.append(event)

func _no(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}

func snapshot() -> Dictionary:
	return state.duplicate(true)

func save_game(path: String) -> Error:
	if state.is_empty():
		return ERR_UNCONFIGURED
	var text := JSON.stringify(state, "", true, true)
	## El tope se mide en BYTES (utf-8), no en caracteres: los acentos de los textos ocupan 2 bytes y load_game rechaza > 4 MB de archivo.
	if text.to_utf8_buffer().size() > SAVE_MAX_BYTES:
		## Guardado compacto y, si aun asi se pasa, copia aligerada (sin tocar la partida en curso): registro, ordenes y sondas.
		var slim := state.duplicate(true)
		slim.log = (slim.log as Array).slice(maxi(0, slim.log.size() - SAVE_LOG_FALLBACK))
		_slim_for_save(slim)
		text = JSON.stringify(slim, "", true, true)
		if text.to_utf8_buffer().size() > SAVE_MAX_BYTES:
			return ERR_FILE_CORRUPT
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.flush()
	file.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path))

## Aligera una COPIA del estado para el guardado de emergencia: recorta ordenes y sondas, y conserva lo que importa para el conocimiento.
func _slim_for_save(slim: Dictionary) -> void:
	var orders: Array = slim.orders
	if orders.size() > SAVE_ORDERS_FALLBACK:
		## Se conserva la primera orden (la coherencia exige que coincida con first_order_at) y las mas recientes.
		var kept: Array = [orders[0]]
		kept.append_array(orders.slice(orders.size() - (SAVE_ORDERS_FALLBACK - 1)))
		slim.orders = kept
	if slim.has("probes"):
		for p in slim.probes:
			var pts: Array = p.pts
			if pts.size() <= 4:
				continue
			var thin: Array = []
			for i in range(pts.size()):
				if i == 0 or i == pts.size() - 1 or i % SAVE_PROBE_STRIDE == 0:
					thin.append(pts[i])
			p.pts = thin

func load_game(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _no("No hay una partida guardada.")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > LOAD_MAX_BYTES:
		return _no("El archivo guardado no es válido.")
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return _no("El archivo guardado está dañado o no contiene JSON válido.")
	var parsed: Variant = parser.data
	var check := validate_snapshot(parsed)
	if not check.ok:
		return check
	state = parsed.duplicate(true)
	state.previous_game_id = state.game_id
	state.game_id = _new_id(str(state.scenario))
	state.state_version = int(state.state_version) + 1
	_navigation_revision = -999
	_nav = null
	_nav_key = Vector2i(-1, -1)
	_know_sig = -1
	_clear_knowledge()
	_apply_hidden()
	_events = []
	_event("Partida recuperada. Las respuestas externas de la sesión anterior quedan invalidadas.", "load")
	return {"ok": true, "reason": "Partida recuperada.", "state": state}

func _point_ok(p: Variant, bx: float, bz: float) -> bool:
	return p is Dictionary and _number_in(p.get("x"), -bx, bx) and _number_in(p.get("z"), -bz, bz)

func _point_in_map(p: Variant) -> bool:
	var sz := map_size()
	return p is Dictionary and _number_in(p.get("x"), 0, sz.x) and _number_in(p.get("z"), 0, sz.y)

func validate_snapshot(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return _no("El guardado no contiene un estado válido.")
	var d: Dictionary = value
	for key in ["schema_version", "game_id", "state_version", "scenario", "seed", "rng_state", "elapsed", "accumulator", "status", "reason", "round", "units", "log", "orders", "external_decisions", "first_order_at"]:
		if not d.has(key):
			return _no("Guardado incompleto: falta %s." % key)
	if not d.scenario is String or d.scenario not in ["justine", "norte"] or not d.status is String or d.status not in ["playing", "victory", "defeat"]:
		return _no("Escenario o resultado inválido en el guardado.")
	var is_j: bool = d.scenario == "justine"
	var expected := JUSTINE_SAVE_VERSION if is_j else SAVE_VERSION
	if is_j and _number_in(d.schema_version, SAVE_VERSION, JUSTINE_SAVE_VERSION - 1):  ## Ronda 5: cualquier versión anterior de Justina (v1, v2 de la preview 3) da el aviso claro
		return _no("Este guardado es de una versión anterior del escenario Justina y no es compatible.")
	if not _number_in(d.schema_version, expected, expected):
		return _no("Versión de guardado incompatible; se necesita la versión %d." % expected)
	if not d.game_id is String or not d.reason is String or not _number_in(d.state_version, 1, 1000000000) or not _number_in(d.seed, -2147483647, 2147483647) or not _number_in(d.first_order_at, -1, 86400):
		return _no("Identidad o versión de estado inválidas.")
	if not _number_in(d.elapsed, 0, 86400) or not _number_in(d.round, 1, MAX_ROUNDS) or not _number_in(d.rng_state, 1, 2147483646) or not _number_in(d.accumulator, 0, 60):
		return _no("Los tiempos o la semilla del guardado son inválidos.")
	if not d.units is Array or d.units.size() != 3 or not d.log is Array or not d.orders is Array or not d.external_decisions is Array:
		return _no("Las agrupaciones o el registro del guardado son inválidos.")
	if is_j and map_data().is_empty():
		return _no("No se pudo cargar el mapa de Justina.")
	for event in d.log:
		if not event is Dictionary or not event.get("text") is String or not event.get("kind") is String or not _number_in(event.get("time"), 0, 86400) or not _number_in(event.get("round"), 1, MAX_ROUNDS):
			return _no("Registro de acontecimientos corrupto.")
	for order in d.orders:
		if not order is Dictionary or not order.has_all(["time", "round", "unit", "action", "target"]) or not order.target is Dictionary:
			return _no("Historial de órdenes corrupto.")
	for decision in d.external_decisions:
		if not decision is Dictionary or not decision.get("context") is Dictionary or not decision.get("choice") is String:
			return _no("Registro de decisiones externas corrupto.")
	var ids: Array = []
	var stages: Array = JUSTINE_STAGES if is_j else ["ready", "moving", "rally", "waiting_tide", "blocked", "dismounting", "boarding", "routed", "ordered"]
	for u in d.units:
		if not u is Dictionary:
			return _no("Agrupación corrupta.")
		for key in ["id", "name", "x", "z", "strength", "fatigue", "supply", "mounted", "stage", "order", "path", "sector_id", "dismount_remaining", "revealed_until", "blocked_until"]:
			if not u.has(key):
				return _no("Agrupación incompleta.")
		if not u.id is String or u.id not in JUSTINE_GROUPS or u.id in ids:
			return _no("Identificadores de agrupación inválidos.")
		ids.append(u.id)
		if is_j:
			for key in ["pace", "work", "stumble_remaining", "tag", "wounded", "evac_remaining"]:
				if not u.has(key):
					return _no("Agrupación incompleta.")
			if not _number_in(u.wounded, 0, 100) or not _number_in(u.evac_remaining, 0, 60) or (float(u.evac_remaining) > 0.0 and u.stage != "boarding"):
				return _no("Heridos o evacuación inválidos.")
			if not _point_in_map(u):
				return _no("Agrupación fuera del mapa.")
			if not u.pace is String or u.pace not in PACES or not u.work is Dictionary or not _number_in(u.stumble_remaining, 0, 60) or not u.tag is String:
				return _no("Ritmo, trabajo o tropiezo inválidos.")
			if not u.work.is_empty() and (not u.work.get("kind") is String or u.work.kind not in ["muster", "resupply", "signal"] or not _number_in(u.work.get("remaining"), 0, 120)):
				return _no("Trabajo en curso inválido.")
		elif not _number_in(u.x, -38, 38) or not _number_in(u.z, -28, 28):
			return _no("Agrupación fuera del mapa.")
		for key in ["strength", "fatigue", "supply"]:
			if not _number_in(u[key], 0, 100):
				return _no("Recursos de agrupación inválidos.")
		if not u.order is Dictionary or not u.path is Array or not u.mounted is bool:
			return _no("Orden o trayecto corrupto.")
		if not u.name is String or not u.sector_id is String or not u.stage is String or u.stage not in stages or not _number_in(u.dismount_remaining, 0, 60) or not _number_in(u.blocked_until, 0, 86400) or not _number_in(u.revealed_until, 0, MAX_ROUNDS + 1):
			return _no("Estado de agrupación inválido.")
		if not u.order.is_empty():
			if is_j:
				if not u.order.get("action") is String or u.order.get("action", "") not in JUSTINE_ORDER_ACTIONS:
					return _no("Orden táctica inválida.")
				if u.order.action != "rally" and not _point_in_map(u.order):
					return _no("Destino táctico inválido.")
			elif u.order.get("action", "") not in CAMPAIGN_ACTIONS or not u.order.get("sector_id") is String:
				return _no("Orden de campaña inválida.")
		for point in u.path:
			if is_j:
				if not _point_in_map(point):
					return _no("Trayecto fuera del mapa.")
			elif not point is Dictionary or not _number_in(point.get("x"), -38, 38) or not _number_in(point.get("z"), -28, 28):
				return _no("Trayecto fuera del mapa.")
	if is_j:
		var jc := _validate_justine_fields(d)
		if not jc.ok:
			return jc
	else:
		for key in ["sectors", "enemy", "population", "stores", "humahuaca", "pressure_actions", "date", "last_results", "historical_note"]:
			if not d.has(key):
				return _no("Estado de campaña incompleto.")
		if not d.sectors is Array or d.sectors.size() != 8 or not d.enemy is Dictionary or not _number_in(d.population, 0, 100) or not _number_in(d.stores, 0, 150):
			return _no("Recursos o sectores de campaña inválidos.")
		if not d.humahuaca is bool or not _number_in(d.pressure_actions, 0, 1000) or not d.last_results is Array or d.date != DATES[int(d.round) - 1]:
			return _no("Progreso o fecha de campaña inválidos.")
		for key in ["supply", "cohesion", "communications"]:
			if not _number_in(d.enemy.get(key), 0, 100):
				return _no("Recursos realistas inválidos.")
		if not d.enemy.has_all(["position", "occupied_salta", "intent"]):
			return _no("Estado realista incompleto.")
		if not d.enemy.occupied_salta is bool or d.enemy.intent not in ["forage", "guard", "advance", "retreat"]:
			return _no("Intención realista inválida.")
		var sector_ids: Array = []
		for sector in d.sectors:
			if not sector is Dictionary or not sector.has_all(["id", "name", "x", "z", "neighbors", "known", "intel_until", "protected_until", "crates", "enemy"]):
				return _no("Sector incompleto.")
			if sector.id not in ["humahuaca", "quebrada", "jujuy", "salta", "lerma", "chicoana", "oran", "rosario"] or sector.id in sector_ids or not sector.neighbors is Array:
				return _no("Sector o conexión inválidos.")
			if not sector.name is String or not _number_in(sector.x, -38, 38) or not _number_in(sector.z, -28, 28) or not sector.known is bool or not sector.enemy is bool or not _number_in(sector.crates, 0, 3) or not _number_in(sector.intel_until, 0, MAX_ROUNDS + 3) or not _number_in(sector.protected_until, 0, MAX_ROUNDS + 2):
				return _no("Recursos o estado de sector inválidos.")
			sector_ids.append(sector.id)
		if d.enemy.position not in sector_ids:
			return _no("Posición realista inexistente.")
		for sector in d.sectors:
			for neighbor in sector.neighbors:
				if neighbor not in sector_ids:
					return _no("La ruta enlaza con un sector inexistente.")
		for u in d.units:
			if u.sector_id not in sector_ids:
				return _no("Agrupación en un sector inexistente.")
			if not u.order.is_empty() and u.order.sector_id not in sector_ids:
				return _no("Orden hacia un sector inexistente.")
		for result in d.last_results:
			if not result is Dictionary or not result.get("label") is String or not _number_in(result.get("before"), 0, 150) or not _number_in(result.get("after"), 0, 150):
				return _no("Resumen de ronda corrupto.")
	return _validate_coherence(d)

func _validate_justine_fields(d: Dictionary) -> Dictionary:
	var m := map_data()
	for key in ["map_id", "map_version", "water_level_m", "water_level", "tide_phase", "capture", "crew_morale", "next_volley", "deadline", "bajante_announced", "rising_announced", "ammo", "ammo_max", "balizas", "volunteers_pool", "advance_authorized", "advance_until", "fire_support", "probes", "scouts", "hazards_found", "fords_found", "stats", "historical_note", "briefing", "hidden", "ammo_reserve", "signals_left", "counter"]:
		if not d.has(key):
			return _no("Estado de la ribera incompleto: falta %s." % key)
	# resultado oculto: una variante valida por grupo
	var picked: Dictionary = {}
	if not d.hidden is Dictionary or not d.hidden.get("picks") is Dictionary:
		return _no("Resultado oculto de la partida inválido.")
	for grp in m.get("hidden_layout", {}).get("groups", []):
		var pick: Variant = d.hidden.picks.get(str(grp.id))
		if not pick is String or pick not in grp.variants:
			return _no("Resultado oculto: variante inválida en el grupo %s." % str(grp.id))
		picked[str(grp.id)] = pick
	if d.hidden.picks.size() != picked.size():
		return _no("Resultado oculto con grupos desconocidos.")
	if d.hidden.has("tide"):
		var tid_ok := false
		for v in m.get("time", {}).get("variants", []):
			if d.hidden.tide is String and str(v.id) == d.hidden.tide:
				tid_ok = true
		if not tid_ok and not (d.hidden.tide is String and d.hidden.tide == "normal"):
			return _no("Resultado oculto: condición del río inválida.")
	if not _number_in(d.ammo_reserve, 0, int(m.resources.ammo_reserve)) or not _number_in(d.signals_left, 0, int(m.resources.signals_max)):
		return _no("Reserva de munición o señales inválidas.")
	var cn: Variant = d.counter
	if not cn is Dictionary or not cn.has_all(["next_at", "active", "until", "answered", "count"]) or not cn.active is bool or not cn.answered is bool or not _number_in(cn.next_at, -1, 100000) or not _number_in(cn.until, 0, 100000) or not _number_in(cn.count, 0, 10000):
		return _no("Estado del contraataque inválido.")
	if not d.map_id is String or d.map_id != str(m.id) or not _number_in(d.map_version, int(m.map_version), int(m.map_version)):
		return _no("El guardado es de otro mapa o de otra versión del mapa de Justina.")
	var hi := float(m.tide.level_high_m)
	var norm: Dictionary = m.tide.legacy_normalized
	if not _number_in(d.water_level_m, float(m.tide.level_low_m) - 0.000001, hi + 0.000001) or not _number_in(d.water_level, float(norm.low) - 0.000001, float(norm.high) + 0.000001):
		return _no("Estado del río inválido.")
	if not _number_in(d.capture, 0, 100) or not _number_in(d.crew_morale, 0, 100):
		return _no("Captura o moral inválidas.")
	if not _number_in(d.next_volley, 0, 2000) or not _number_in(d.deadline, 1, 3600) or not d.bajante_announced is bool or not d.rising_announced is bool or not d.tide_phase is String or d.tide_phase not in TIDE_PHASES:
		return _no("Fase o tiempos del río inválidos.")
	var res: Dictionary = m.resources
	if not _number_in(d.ammo_max, 1, 10000) or not _number_in(d.ammo, 0, d.ammo_max if _number_in(d.ammo_max, 1, 10000) else 0) or not _number_in(d.balizas, 0, int(res.balizas_start)) or not _number_in(d.volunteers_pool, 0, float(res.volunteers_pool)) or not d.advance_authorized is bool or not _number_in(d.advance_until, -1, 100000):
		return _no("Recursos inválidos (munición, balizas o voluntarios).")
	if not d.fire_support is Dictionary or not _number_in(d.fire_support.get("until"), 0, 100000) or not _number_in(d.fire_support.get("ready_at"), 0, 100000):
		return _no("Apoyo de fuego inválido.")
	if not d.historical_note is String or not d.briefing is String:
		return _no("Textos del escenario inválidos.")
	if d.has("defeat_cause") and not d.defeat_cause is String:
		return _no("Causa de derrota inválida.")
	# sondas
	if not d.probes is Array or d.probes.size() > MAX_PROBES:
		return _no("Sondas inválidas o demasiadas.")
	var widths := [float(m.knowledge.probe_lane_width_m), float(m.knowledge.marked_corridor_width_m)]
	for p in d.probes:
		if not p is Dictionary or not p.has_all(["id", "kind", "pts", "width", "t", "scout"]) or not p.id is String or not p.kind is String or p.kind not in ["lane", "marked"] or not p.scout is String:
			return _no("Sonda corrupta.")
		if not _number_in(p.width, 0, 100) or not widths.has(float(p.width)) or not _number_in(p.t, 0, 86400) or not p.pts is Array or p.pts.is_empty() or p.pts.size() > MAX_PROBE_POINTS:
			return _no("Sonda con ancho, tiempo o puntos inválidos.")
		for pt in p.pts:
			if not _point_in_map(pt):
				return _no("Sonda fuera del mapa.")
	# exploradores
	if not d.scouts is Array or d.scouts.size() != m.scouts.size():
		return _no("Exploradores inválidos.")
	var sids: Array = []
	for s in d.scouts:
		if not s is Dictionary or not s.has_all(["id", "name", "x", "z", "hp", "stage", "order", "path", "work_remaining", "cautious"]) or not s.id is String or s.id in sids or not s.cautious is bool:
			return _no("Explorador corrupto.")
		sids.append(s.id)
		var known_scout := false
		for cfg in m.scouts:
			known_scout = known_scout or str(cfg.id) == s.id
		if not known_scout or not s.name is String or not _number_in(s.hp, 0, int(res.scout_hp)) or not s.stage is String or s.stage not in SCOUT_STAGES or not _point_in_map(s) or not s.order is Dictionary or not s.path is Array or not _number_in(s.work_remaining, 0, 10000):
			return _no("Explorador con datos inválidos.")
		if not s.order.is_empty():
			if s.order.get("action", "") not in ["probe", "mark_ford"] or not s.order.get("points") is Array or s.order.points.is_empty():
				return _no("Orden de explorador inválida.")
			for pt in s.order.points:
				if not _point_in_map(pt):
					return _no("Orden de explorador fuera del mapa.")
		for pt in s.path:
			if not _point_in_map(pt):
				return _no("Trayecto de explorador fuera del mapa.")
	# hallazgos
	var hz_ids: Array = []
	for hz in m.hazards:
		hz_ids.append(str(hz.id))
	var fd_ids: Array = []
	for fd in m.fords:
		fd_ids.append(str(fd.id))
	if not d.hazards_found is Array or not d.fords_found is Array:
		return _no("Hallazgos inválidos.")
	for id in d.hazards_found:
		if not id is String or id not in hz_ids:
			return _no("Hallazgo de pozo inexistente.")
		for hz in m.hazards:
			if str(hz.id) == id and hz.has("variant_group") and str(picked.get(str(hz.variant_group), "")) != id:
				return _no("Hallazgo de un pozo que no existe en el fondo de esta partida.")
	for id in d.fords_found:
		if not id is String or id not in fd_ids:
			return _no("Hallazgo de vado inexistente.")
	# estadisticas
	if not d.stats is Dictionary or not d.stats.has_all(["start_strength", "shots_taken", "damage_taken", "stumbles", "probe_m", "marked_m", "ammo_used", "balizas_used", "fire_support_uses", "muster_gain", "scouts_lost", "horses_lost", "melee_loss", "drowned", "exposure_s", "boarded_at", "level_at_boarding", "first_water_entry_at", "counter_hits", "counter_repelled", "counter_loss", "evacuations", "wounded_recovered", "halted_by_expiry"]):
		return _no("Estadísticas incompletas.")
	if not d.stats.start_strength is Dictionary or not d.stats.exposure_s is Dictionary:
		return _no("Estadísticas inválidas.")
	for id in JUSTINE_GROUPS:
		if not _number_in(d.stats.start_strength.get(id), 0, 100):
			return _no("Estadísticas: falta la fuerza inicial de %s." % id)
	for key in ["shots_taken", "damage_taken", "stumbles", "probe_m", "marked_m", "ammo_used", "balizas_used", "fire_support_uses", "muster_gain", "scouts_lost", "horses_lost", "melee_loss", "drowned", "counter_hits", "counter_repelled", "counter_loss", "evacuations", "wounded_recovered", "halted_by_expiry"]:
		if not _number_in(d.stats[key], 0, 1000000):
			return _no("Estadísticas fuera de rango.")
	for key in ["central", "sur", "otra"]:
		if not _number_in(d.stats.exposure_s.get(key), 0, 1000000):
			return _no("Exposición acumulada inválida.")
	for key in ["boarded_at", "level_at_boarding", "first_water_entry_at"]:
		if not _number_in(d.stats[key], -1, 86400):
			return _no("Estadísticas de tiempo inválidas.")
	return {"ok": true, "reason": "Campos válidos."}

## Coherencia entre campos: cada campo puede ser valido por separado y aun asi contradecir a otro.
func _validate_coherence(d: Dictionary) -> Dictionary:
	var playing: bool = d.status == "playing"
	if playing != (d.reason == ""):
		return _no("Incoherencia: el motivo de cierre no corresponde al estado de la partida.")
	for event in d.log:
		if int(event.round) > int(d.round) or float(event.time) > float(d.elapsed) + 0.001:
			return _no("Incoherencia: el registro contiene acontecimientos posteriores al estado actual.")
	if d.orders.is_empty() != (float(d.first_order_at) < 0.0):
		return _no("Incoherencia: la primera orden no concuerda con el historial de órdenes.")
	if not d.orders.is_empty() and absf(float(d.orders[0].time) - float(d.first_order_at)) > 0.001:
		return _no("Incoherencia: el momento de la primera orden no coincide con el historial.")
	for order in d.orders:
		if int(order.round) > int(d.round) or float(order.time) > float(d.elapsed) + 0.001:
			return _no("Incoherencia: hay órdenes posteriores al estado actual.")
	for u in d.units:
		if u.stage == "routed" and float(u.strength) > 5.0:
			return _no("Incoherencia: agrupación dispersa con efectivos suficientes.")
		if u.stage == "dismounting" and not u.mounted:
			return _no("Incoherencia: agrupación desmontando que ya está desmontada.")
		if u.stage == "boarding" and u.mounted:
			return _no("Incoherencia: agrupación abordando que sigue montada.")
		if float(u.dismount_remaining) > 0.0 and u.stage not in ["dismounting", "routed"]:
			return _no("Incoherencia: tiempo de desmontaje en una agrupación que no desmonta.")
		if not playing and (not u.order.is_empty() or not u.path.is_empty()):
			return _no("Incoherencia: partida terminada con órdenes o trayectos pendientes.")
	if d.scenario == "justine":
		return _validate_justine_coherence(d, playing)
	return _validate_norte_coherence(d, playing)

func _validate_justine_coherence(d: Dictionary, playing: bool) -> Dictionary:
	_tide_override = str(d.hidden.get("tide", "normal"))
	var out := _validate_justine_coherence_inner(d, playing)
	_tide_override = ""
	return out

func _validate_justine_coherence_inner(d: Dictionary, playing: bool) -> Dictionary:
	var m := map_data()
	var tide := tide_at(float(d.elapsed))
	if d.tide_phase != tide.phase or absf(float(d.water_level_m) - float(tide.level_m)) > 0.002:
		return _no("Incoherencia: el nivel y la fase del río no corresponden al tiempo transcurrido.")
	if absf(float(d.water_level) - float(tide.level_norm)) > 0.002:
		return _no("Incoherencia: el nivel normalizado no se deriva del nivel real del río.")
	var marks := tide_marks()
	if d.bajante_announced != (float(d.elapsed) >= marks.drop_start) or d.rising_announced != (float(d.elapsed) >= marks.low_hold_end):
		return _no("Incoherencia: los avisos del río no corresponden al tiempo transcurrido.")
	if playing:
		if float(d.capture) >= 100.0 or float(d.elapsed) > float(d.deadline) + 0.001:
			return _no("Incoherencia: partida en curso con captura completa o plazo vencido.")
		if float(d.accumulator) >= STEP + 0.001:
			return _no("Incoherencia: acumulador de tiempo mayor que un paso.")
		if float(d.next_volley) <= float(d.elapsed):
			return _no("Incoherencia: la próxima descarga ya debería haber ocurrido.")
	elif d.status == "victory" and float(d.capture) < 100.0:
		return _no("Incoherencia: victoria sin captura completa.")
	if float(d.capture) >= 100.0 and d.status != "victory":
		return _no("Incoherencia: captura completa sin victoria.")
	if float(d.fire_support.until) > float(d.fire_support.ready_at):
		return _no("Incoherencia: el apoyo de fuego termina después de que podría repetirse.")
	if bool(d.advance_authorized):
		var signaled := false
		for order in d.orders:
			signaled = signaled or order.action == "signal_liniers"
		if not signaled:
			return _no("Incoherencia: orden de avance concedida sin que se haya señalado a Liniers.")
	for p in d.probes:
		if float(p.t) > float(d.elapsed) + 0.001:
			return _no("Incoherencia: una sonda es posterior al estado actual.")
	for u in d.units:
		var working: bool = not u.work.is_empty()
		if (u.stage == "working") != working:
			return _no("Incoherencia: el trabajo en curso no concuerda con la etapa del grupo.")
		if (u.stage == "stumbling") != (float(u.stumble_remaining) > 0.0):
			return _no("Incoherencia: el tropiezo no concuerda con la etapa del grupo.")
		if u.stage in ["moving", "blocked", "rally"] and u.order.is_empty():
			return _no("Incoherencia: agrupación en marcha sin orden.")
		if u.stage == "moving" and u.path.is_empty():
			return _no("Incoherencia: agrupación en marcha sin trayecto.")
		if not u.path.is_empty() and u.stage != "moving":
			return _no("Incoherencia: trayecto pendiente en una agrupación que no avanza.")
		if u.stage == "working" and u.order.is_empty():
			return _no("Incoherencia: grupo trabajando sin orden.")
	var group_ok := false
	for u in d.units:
		group_ok = group_ok or float(u.strength) > float(m.outcome.routed_strength_threshold)
	if playing and not group_ok:
		return _no("Incoherencia: partida en curso sin agrupaciones activas.")
	for s in d.scouts:
		if (s.stage == "lost") != (int(s.hp) <= 0):
			return _no("Incoherencia: el estado del explorador no concuerda con su salud.")
		if s.stage == "moving" and s.path.is_empty():
			return _no("Incoherencia: explorador en marcha sin trayecto.")
		if s.stage in ["probing", "marking"] and s.order.is_empty():
			return _no("Incoherencia: explorador trabajando sin orden.")
		if s.stage in ["idle", "lost"] and (not s.path.is_empty() or not s.order.is_empty()):
			return _no("Incoherencia: explorador inactivo con orden o trayecto.")
	return {"ok": true, "reason": "Guardado válido."}

func _validate_norte_coherence(d: Dictionary, playing: bool) -> Dictionary:
	var by_id := {}
	for sector in d.sectors:
		by_id[sector.id] = sector
	for sector in d.sectors:
		for neighbor in sector.neighbors:
			if neighbor == sector.id or sector.id not in by_id[neighbor].neighbors:
				return _no("Incoherencia: la ruta entre sectores no es recíproca.")
	for u in d.units:
		var here: Dictionary = by_id[u.sector_id]
		if absf(float(u.x) - float(here.x)) > 0.001 or absf(float(u.z) - float(here.z)) > 0.001:
			return _no("Incoherencia: la agrupación no está en las coordenadas de su sector.")
		if (u.stage == "ordered") == u.order.is_empty() and u.stage != "routed":
			return _no("Incoherencia: la orden pendiente no concuerda con el estado de la agrupación.")
		if not u.order.is_empty() and u.order.sector_id != u.sector_id and u.order.sector_id not in here.neighbors:
			return _no("Incoherencia: orden hacia un sector inalcanzable.")
		if not u.path.is_empty():
			return _no("Incoherencia: trayecto táctico en la campaña.")
	var enemy: Dictionary = d.enemy
	if not by_id[enemy.position].enemy:
		return _no("Incoherencia: el sector del invasor no está marcado como ocupado.")
	if (enemy.position == "salta") != enemy.occupied_salta:
		return _no("Incoherencia: la ocupación de Salta no concuerda con la posición del invasor.")
	if playing and int(d.round) > SALTA_OCCUPATION_ROUND and not enemy.occupied_salta:
		return _no("Incoherencia: Salta debería estar ocupada en esta ronda.")
	if by_id["humahuaca"].enemy == d.humahuaca:
		return _no("Incoherencia: la recuperación de Humahuaca no concuerda con el sector.")
	if d.humahuaca and (int(d.round) < 7 or int(d.pressure_actions) < 2):
		return _no("Incoherencia: Humahuaca figura recuperada antes de la ronda posible.")
	if int(d.pressure_actions) > 3 * int(d.round) + 2:
		return _no("Incoherencia: más acciones de presión que las posibles hasta esta ronda.")
	if playing:
		if float(d.population) <= 10.0:
			return _no("Incoherencia: partida en curso con la población agotada.")
		var alive := false
		for u in d.units:
			alive = alive or float(u.strength) > 5.0
		if not alive:
			return _no("Incoherencia: partida en curso sin agrupaciones activas.")
		if d.last_results.size() != (0 if int(d.round) == 1 else 5):
			return _no("Incoherencia: el resumen de ronda no concuerda con la ronda actual.")
	return {"ok": true, "reason": "Guardado válido."}

func _number_in(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high
