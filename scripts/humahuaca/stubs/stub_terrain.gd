extends RefCounted
## Terreno de respaldo del nivel «humahuaca» (contrato 3.1 y 7). Dueña: relieve_mapa. Primer commit de la pista (R1.0): queda CONGELADO
## desde el merge (se corrige solo por addendum) y no depende del código real de la pista (solo de los vocabularios).
##
## Qué es: la API COMPLETA de HumahuacaTerrain (3.1) con valores válidos sobre un terreno PLANO a +17 m (la cota del templo), los 21 hitos de
## data/humahuaca_map.json y, además, lo que las reglas necesitan para calibrarse desde R1 contra muros y no contra un plano vacío: lee
## data/humahuaca_level.json y rasteriza UNA vez, en la malla de 4 m, las tapias y barricadas (sólidas y opacas), los portillos (huecos
## que se abren), las zanjas y acequias (paso ×0,5), las calles y caminos, los patios, las parcelas irrigadas y el río (agua y sedimento).
## Qué NO es: relieve. No hay cerro, plataforma, quebraditas ni micro-relieve: height_at() vale siempre FLAT_M y report() lo dice (tag diseno).
##
## Convenciones de la malla de rutas (nav_grid): 226 × 164 nodos, el nodo (i, j) está en x = i·4, z = j·4 y manda en ±2 m; el índice es
## j·nx + i y se obtiene con roundi(x / cell). `weight` es el multiplicador de costo de cruzar el nodo (1,0 = suelo libre; 1 / velocidad si es
## más lento), como el `weight_scale` de AStarGrid2D; los nodos sólidos valen 1,0 (no se cruzan). Es estático: los portillos cerrados son sólidos.
## `open_gaps` (is_blocked, los): ids de portillo ("p_norte"), diccionarios con "id", o posiciones (Vector2, {x,z} o [x,z]): abre el portillo más cercano.
## Simplificaciones declaradas del respaldo: las manzanas, el camino cubierto (solo su suelo) y los edificios de los hitos no son sólidos para
## el paso (los edificios sí tapan la vista); un `mounted` no cambia nada; la humedad del suelo usa una tabla propia del respaldo.

const V = preload("res://scripts/humahuaca/humahuaca_vocab.gd")
const VT = preload("res://scripts/humahuaca/terrain/vocab_terrain.gd")

const FLAT_M := 17.0
const CELL_M := 4.0
const CTX_NX := 121
const CTX_NZ := 91
const CTX_CELL_M := 30.0
const CTX_ORIGIN := Vector2(-1350.0, -1025.0)
const WALL_H_M := 2.0  # alto de una tapia sin `height_m`
const BARRICADE_H_M := 1.6
const GATE_ALONG_MIN_M := 3.0  # el hueco de un portillo mide al menos esto a lo largo de la tapia (un nodo si es chico)
const GATE_ACROSS_M := 3.2  # y esto a lo ancho: libera el nodo de la tapia en cualquier orientación
const FORD_RADIUS_M := 14.0
const MUD_OTHER := 0.9  # velocidad con barro de una superficie que el mapa no lista en surfaces.mud
const MUD_FALLBACK := {"camino": 0.9, "suelo_seco": 0.95, "sedimento_humedo": 0.75, "irrigado": 0.6, "zanja": 0.5, "agua": 0.5}
const WET := {  # superficie → [humedad base, ganancia por lluvia]
	"suelo_seco": [0.0, 0.8], "sedimento_humedo": [0.5, 0.5], "piedra": [0.0, 0.3], "churqui": [0.0, 0.7], "irrigado": [0.4, 0.6],
	"agua": [1.0, 0.0], "camino": [0.0, 0.9], "patio": [0.0, 0.9], "zanja": [0.7, 0.3], "muro": [0.0, 0.0]}
const RIVER_FALLBACK := [[572.0, 0.0], [859.0, 325.0], [862.0, 340.0], [900.0, 406.0]]  # entra por el norte, cruza z = 325 en x = 859, pasa por el vado y sale por el este
const MINIMAP_COLOR := Color("B99A72")
const BOX_TYPES := ["hito", "objetivo", "edificio", "torre"]  # los hitos de estos tipos con altura tapan la vista

static var _default: RefCounted = null

var size_m := Vector2(900.0, 650.0)
var cell_m := CELL_M
var nx := 226
var nz := 164
var datum_asl_m := 2940.0
var anchor := Vector2(450.0, 325.0)

var _map: Dictionary = {}
var _level: Dictionary = {}
var _lamina_off := Vector2(450.0, 325.0)
var _imax := 225
var _jmax := 162
var _landmarks: Array = []
var _lm_by_id: Dictionary = {}
var _river: Dictionary = {}
var _river_pts := PackedVector2Array()
var _ford_pts := PackedVector2Array()
var _mud: Dictionary = {}
var _sid: Dictionary = {}
var _solid := PackedByteArray()
var _surf := PackedByteArray()
var _obst := PackedFloat32Array()
var _weight := PackedFloat32Array()
var _walls: Array = []  # segmentos opacos: [a, b, alto, índice de pared, arco al inicio, largo]
var _wall_gates: Array = []  # por pared: [[id, arco0, arco1, abierto_de_origen], ...]
var _gates: Dictionary = {}  # id de portillo → posición
var _gate_of_node: Dictionary = {}  # índice de nodo → id de portillo (los nodos que se liberan al abrirlo)
var _boxes: Array = []  # edificios que tapan la vista: {id, poly, h}
var _hf: Dictionary = {}
var _cf: Dictionary = {}
var _counts: Dictionary = {}
var _stages_ms: Dictionary = {}
var _bake_ms := 0.0
var _t_lap := 0

## `new()` a secas arma el terreno con los datos del juego; `new(mapa, nivel)`, con esos diccionarios (las pruebas usan niveles sintéticos).
func _init(map: Dictionary = {}, level: Dictionary = {}) -> void:
	if map.is_empty():
		map = V.load_json(V.MAP_PATH)
		level = V.load_json(V.LEVEL_PATH)  # si falta, el terreno queda sin rasgos (load_json ya avisó)
	_bake(map, level)

## El terreno de respaldo del proceso (caché). null, con push_error, si falta o no sirve data/humahuaca_map.json.
static func load_default() -> RefCounted:
	if _default != null:
		return _default
	var map: Dictionary = V.load_json(V.MAP_PATH)
	if map.is_empty():
		push_error("Terreno de respaldo: falta o no sirve " + V.MAP_PATH)
		return null
	_default = new(map, V.load_json(V.LEVEL_PATH))
	return _default

## Arma un terreno con los diccionarios dados, sin caché.
static func from_data(map: Dictionary, level: Dictionary = {}) -> RefCounted:
	return new(map, level)

# ---------------------------------------------------------------------------------------------------------------------
# Conversión lámina ↔ juego

func lamina_to_game(e: float, n: float) -> Vector2:
	return Vector2(e + _lamina_off.x, _lamina_off.y - n)

func game_to_lamina(p: Vector2) -> Vector2:
	return Vector2(p.x - _lamina_off.x, _lamina_off.y - p.y)

# ---------------------------------------------------------------------------------------------------------------------
# Altura: plana

@warning_ignore("unused_parameter")
func height_at(x: float, z: float) -> float:
	return FLAT_M

@warning_ignore("unused_parameter")
func height_dem_only(x: float, z: float) -> float:
	return FLAT_M

func asl_at(x: float, z: float) -> float:
	return height_at(x, z) + datum_asl_m

@warning_ignore("unused_parameter")
func normal_at(x: float, z: float) -> Vector3:
	return Vector3.UP

@warning_ignore("unused_parameter")
func slope_deg_at(x: float, z: float) -> float:
	return 0.0

func elevation_advantage(a: Vector2, b: Vector2) -> float:
	return height_at(a.x, a.y) - height_at(b.x, b.y)

# ---------------------------------------------------------------------------------------------------------------------
# Superficie, humedad, paso y visión

func surface_at(x: float, z: float) -> String:
	if not _in_world(x, z):
		return "suelo_seco"
	return str(VT.SURFACES[_surf[_node_index(x, z)]])

func wetness_at(x: float, z: float, rain: float = 0.0) -> float:
	return _wet_of(surface_at(x, z), rain)

@warning_ignore("unused_parameter")
func is_blocked(x: float, z: float, mounted: bool = false, open_gaps: Array = []) -> bool:
	if not _in_world(x, z):
		return true
	var idx := _node_index(x, z)
	if _solid[idx] == 0:
		return false
	if not open_gaps.is_empty() and _gate_of_node.has(idx):
		return not _open_ids(open_gaps).has(_gate_of_node[idx])
	return true

@warning_ignore("unused_parameter")
func speed_factor_at(x: float, z: float, rain: float = 0.0, mounted: bool = false) -> float:
	if not _in_world(x, z):
		return 0.0
	var idx := _node_index(x, z)
	if _solid[idx] == 1 and not _gate_of_node.has(idx):
		return 0.0  # el nodo de un portillo se cruza (is_blocked dice si está abierto); una tapia no
	return _speed_for(_surf[idx], rain)

## Visión entre dos puntos del plano a la altura de los ojos de cada uno: la tapan las tapias (salvo portillos abiertos) y los edificios de los hitos;
## quien está dentro de un edificio lo ignora (la torre ve hacia afuera). El terreno es plano: la altura del rayo sobre el suelo es lineal.
func los(a: Vector2, b: Vector2, eye_a: float = 1.6, eye_b: float = 1.6, open_gaps: Array = []) -> bool:
	if a.distance_to(b) < 0.001:
		return true
	var open_ids: Array = _open_ids(open_gaps) if not open_gaps.is_empty() else []
	for w in _walls:
		var hit := _seg_hit(a, b, w[0], w[1])
		if hit.x < 0.0:
			continue
		if lerpf(eye_a, eye_b, hit.x) >= float(w[2]):
			continue
		if _gate_open_at(int(w[3]), float(w[4]) + hit.y * float(w[5]), open_ids):
			continue
		return false
	for bx in _boxes:
		var poly: PackedVector2Array = bx["poly"]
		if Geometry2D.is_point_in_polygon(a, poly) or Geometry2D.is_point_in_polygon(b, poly):
			continue
		var t_in := 2.0
		var t_out := -1.0
		for k in range(poly.size()):
			var edge_hit := _seg_hit(a, b, poly[k], poly[(k + 1) % poly.size()])
			if edge_hit.x >= 0.0:
				t_in = minf(t_in, edge_hit.x)
				t_out = maxf(t_out, edge_hit.x)
		if t_out < 0.0:
			continue
		var top := float(bx["h"])
		if lerpf(eye_a, eye_b, t_in) < top or lerpf(eye_a, eye_b, t_out) < top:
			return false
	return true

# ---------------------------------------------------------------------------------------------------------------------
# Hitos y rasgos

func landmark(id: String) -> Dictionary:
	return (_lm_by_id[id] as Dictionary).duplicate(true) if _lm_by_id.has(id) else {}

## `variant` es la variante del mundo ({dim: valor}); {} devuelve todos. Un hito con `variant` aparece solo si el mundo no lo contradice.
func landmarks(variant: Dictionary = {}) -> Array:
	var out: Array = []
	for lm in _landmarks:
		var need: Variant = (lm as Dictionary).get("variant", {})
		var ok := true
		if need is Dictionary and not variant.is_empty():
			for k in need:
				if variant.has(k) and str(variant[k]) != str(need[k]):
					ok = false
					break
		if ok:
			out.append((lm as Dictionary).duplicate(true))
	return out

## Los rasgos de `humahuaca_level.json` de ese tipo (VT.FEATURE_KINDS), con `feature_kind` agregado. `layout` "" = todos; "A" o "B" filtra.
func features(kind: String, layout: String = "") -> Array:
	var out: Array = []
	for f in _raw_features(kind, layout):
		var copy: Dictionary = (f as Dictionary).duplicate(true)
		copy["feature_kind"] = kind
		out.append(copy)
	return out

func features_near(p: Vector2, radius_m: float, kind: String = "", layout: String = "") -> Array:
	var out: Array = []
	var kinds: Array = [kind] if kind != "" else VT.FEATURE_KINDS
	for k in kinds:
		for f in _raw_features(str(k), layout):
			if _feature_distance(f, p) <= radius_m:
				var copy: Dictionary = (f as Dictionary).duplicate(true)
				copy["feature_kind"] = str(k)
				out.append(copy)
	return out

func river() -> Dictionary:
	return _river.duplicate(true)

func is_ford(x: float, z: float) -> bool:
	for p in _ford_pts:
		if p.distance_to(Vector2(x, z)) <= FORD_RADIUS_M:
			return true
	return false

# ---------------------------------------------------------------------------------------------------------------------
# Campos para la vista y la navegación

func heightfield() -> Dictionary:
	if _hf.is_empty():
		var h := PackedFloat32Array()
		h.resize(nx * nz)
		h.fill(FLAT_M)
		_hf = {"nx": nx, "nz": nz, "cell": cell_m, "origin_x": 0.0, "origin_z": 0.0, "h": h}
	return _hf

func context_field() -> Dictionary:
	if _cf.is_empty():
		var h := PackedFloat32Array()
		h.resize(CTX_NX * CTX_NZ)
		h.fill(FLAT_M)
		_cf = {"nx": CTX_NX, "nz": CTX_NZ, "cell": CTX_CELL_M, "origin_x": CTX_ORIGIN.x, "origin_z": CTX_ORIGIN.y, "h": h}
	return _cf

func nav_grid() -> Dictionary:
	if _weight.is_empty():
		var by_surface := PackedFloat32Array()  # costo por superficie, con el suelo seco
		for sid in range(VT.SURFACES.size()):
			by_surface.append(1.0 / maxf(_speed_for(sid, 0.0), 0.05))
		_weight.resize(nx * nz)
		for idx in range(nx * nz):
			_weight[idx] = 1.0 if _solid[idx] == 1 else by_surface[_surf[idx]]
	return {"nx": nx, "nz": nz, "cell": cell_m, "origin_x": 0.0, "origin_z": 0.0, "solid": _solid, "weight": _weight}

## Un solo color (el respaldo no dibuja relieve), norte arriba y sin unidades.
@warning_ignore("unused_parameter")
func minimap_image(px: Vector2i, opts: Dictionary = {}) -> Image:
	var img := Image.create_empty(clampi(px.x, 1, 4096), clampi(px.y, 1, 4096), false, Image.FORMAT_RGBA8)
	img.fill(MINIMAP_COLOR)
	return img

func report() -> Dictionary:
	return {"source": "stub_plano", "tag": "diseno", "uncertainty_m": 25.0, "smooth_m": 0.0, "h_min": FLAT_M, "h_max": FLAT_M,
		"design_layers": [], "prominence_bateria_m": 0.0, "slope_cells_pct_ge8": 0.0, "vertical_features": [],
		"lamina_check": {"n": 0, "ok": 0, "max_err_m": 0.0, "failed": []},
		"bake_ms": _bake_ms, "bake_stages_ms": _stages_ms.duplicate(), "counts": _counts.duplicate(),
		"stub": true, "nota": "Terreno plano de respaldo (diseño, +17 m): no es relieve ni dato de ninguna fuente."}

# ---------------------------------------------------------------------------------------------------------------------
# Horneado (una sola vez)

func _bake(map: Dictionary, level: Dictionary) -> void:
	var t_start := Time.get_ticks_usec()
	_t_lap = t_start
	_map = map
	_level = level
	_read_basics()
	_lap("lectura")
	_raster_river()
	_lap("rio")
	var layer_a := "A"
	var n_gates := 0
	_paint_polys(_raw_features("parcela", layer_a), "irrigado")
	_paint_polys(_raw_features("patio", layer_a), "patio")
	_paint_zones()
	_paint_strokes(_raw_features("calle", layer_a), "camino", 4.0)
	_paint_strokes(_raw_features("camino", layer_a), "camino", 2.5)
	_paint_strokes(_raw_features("camino_cubierto", layer_a), "camino", 2.5)
	_paint_strokes(_raw_features("zanja", layer_a), "zanja", 0.0)
	_paint_strokes(_raw_features("acequia", layer_a), "zanja", 0.0)
	_lap("superficies")
	var walls_by_id := {}
	for f in _raw_features("tapia", layer_a):
		var pts := _pts(f.get("pts", []))
		if pts.size() >= 2:
			walls_by_id[str(f.get("id", "tapia_%d" % walls_by_id.size()))] = _add_wall(pts, float(f.get("height_m", WALL_H_M)))
	for f in _raw_features("barricada", layer_a):
		var pts := _pts(f.get("pts", []))
		if pts.size() >= 2:
			_add_wall(pts, BARRICADE_H_M)
	_lap("muros")
	for f in _raw_features("portillo", layer_a):
		if _carve_gate(f, walls_by_id, n_gates):
			n_gates += 1
	_lap("portillos")
	_add_boxes()
	_lap("edificios")
	var solid_nodes := 0
	for idx in range(nx * nz):
		solid_nodes += _solid[idx]
	_counts = {"hitos": _landmarks.size(), "tapias": walls_by_id.size(), "segmentos_opacos": _walls.size(), "portillos": n_gates,
		"zanjas": _raw_features("zanja", layer_a).size(), "acequias": _raw_features("acequia", layer_a).size(), "edificios_opacos": _boxes.size(),
		"nodos": nx * nz, "nodos_solidos": solid_nodes}
	_bake_ms = snappedf(float(Time.get_ticks_usec() - t_start) / 1000.0, 0.01)

func _lap(stage: String) -> void:
	var now := Time.get_ticks_usec()
	_stages_ms[stage] = snappedf(float(now - _t_lap) / 1000.0, 0.01)
	_t_lap = now

func _read_basics() -> void:
	var sz: Variant = _map.get("size_m", null)
	if sz is Dictionary:
		size_m = Vector2(float((sz as Dictionary).get("x", 900.0)), float((sz as Dictionary).get("z", 650.0)))
	var an: Variant = _map.get("anchor", null)
	if an is Dictionary:
		anchor = Vector2(float((an as Dictionary).get("x", 450.0)), float((an as Dictionary).get("z", 325.0)))
	var lam: Variant = _map.get("lamina", null)
	if lam is Dictionary:
		_lamina_off = Vector2(float((lam as Dictionary).get("offset_x", 450.0)), float((lam as Dictionary).get("offset_z", 325.0)))
	datum_asl_m = float(_map.get("datum_asl_m", 2940.0))
	cell_m = CELL_M
	_imax = floori(size_m.x / cell_m)
	_jmax = floori(size_m.y / cell_m)
	nx = ceili(size_m.x / cell_m) + 1
	nz = ceili(size_m.y / cell_m) + 1
	for i in range(VT.SURFACES.size()):
		_sid[VT.SURFACES[i]] = i
	_mud = MUD_FALLBACK.duplicate()
	var surfaces: Variant = _map.get("surfaces", null)
	if surfaces is Dictionary and (surfaces as Dictionary).get("mud", null) is Dictionary:
		var mud: Dictionary = (surfaces as Dictionary)["mud"]
		for k in mud:
			_mud[str(k)] = clampf(float(mud[k]), 0.0, 1.0)
	_landmarks = []
	_lm_by_id = {}
	var lms: Variant = _map.get("landmarks", [])
	if lms is Array:
		for lm in lms:
			if lm is Dictionary and (lm as Dictionary).has("id"):
				var copy: Dictionary = (lm as Dictionary).duplicate(true)
				for key in ["tag_parts", "variant", "footprint"]:  # la API siempre trae estas claves, aunque el JSON no las ponga
					if not (copy.get(key, null) is Dictionary):
						copy[key] = {}
				for key in ["yaw_deg", "height_m"]:
					copy[key] = float(copy.get(key, 0.0))
				_landmarks.append(copy)
				_lm_by_id[str(copy["id"])] = copy
	_solid.resize(nx * nz)
	_solid.fill(0)
	_surf.resize(nx * nz)
	_surf.fill(_sid["suelo_seco"])
	_obst.resize(nx * nz)
	_obst.fill(0.0)
	for j in range(nz):  # los nodos fuera de la ventana (el último renglón, z = 652 m) no se pisan
		for i in range(nx):
			if float(i) * cell_m > size_m.x or float(j) * cell_m > size_m.y:
				_solid[j * nx + i] = 1
	_read_river()

func _read_river() -> void:
	var rv: Variant = _map.get("river", null)
	_river_pts = PackedVector2Array()
	_ford_pts = PackedVector2Array()
	if rv is Dictionary and (rv as Dictionary).get("pts", null) is Array and ((rv as Dictionary)["pts"] as Array).size() >= 2:
		_river = (rv as Dictionary).duplicate(true)
		_river_pts = _pts((rv as Dictionary)["pts"])
		var fords: Variant = (rv as Dictionary).get("fords", [])
		if fords is Array:
			for f in fords:
				_ford_pts.append(_pt(f))
	else:
		for p in RIVER_FALLBACK:
			_river_pts.append(Vector2(p[0], p[1]))
		_river = {"id": "rio_grande", "bed_width_m": {"min": 25.0, "max": 40.0}, "depth_m": {"min": 0.2, "max": 0.6}, "fords": [],
			"tag": "diseno", "source": "Trazo mínimo del respaldo (4 puntos de DISENO §3); la traza de 14 puntos de la lámina 03 llega con el terreno real"}
	if _ford_pts.is_empty() and _lm_by_id.has("vado_este"):
		_ford_pts.append(_pt(_lm_by_id["vado_este"]))
	var pts_out: Array = []
	for p in _river_pts:
		pts_out.append({"x": p.x, "z": p.y})
	_river["pts"] = pts_out
	var fords_out: Array = []
	for p in _ford_pts:
		fords_out.append({"x": p.x, "z": p.y})
	_river["fords"] = fords_out

func _raster_river() -> void:
	var bed: Variant = _river.get("bed_width_m", {})
	var half := 16.0
	if bed is Dictionary:
		half = 0.25 * (float((bed as Dictionary).get("min", 25.0)) + float((bed as Dictionary).get("max", 40.0)))
	var core := half * 0.5
	var s_agua: int = _sid["agua"]
	var s_sed: int = _sid["sedimento_humedo"]
	for k in range(_river_pts.size() - 1):
		var a := _river_pts[k]
		var b := _river_pts[k + 1]
		for j in range(maxi(0, ceili((minf(a.y, b.y) - half) / cell_m)), mini(_jmax, floori((maxf(a.y, b.y) + half) / cell_m)) + 1):
			for i in range(maxi(0, ceili((minf(a.x, b.x) - half) / cell_m)), mini(_imax, floori((maxf(a.x, b.x) + half) / cell_m)) + 1):
				var p := Vector2(float(i) * cell_m, float(j) * cell_m)
				var d := p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))
				if d <= core:
					_surf[j * nx + i] = s_agua
				elif d <= half and _surf[j * nx + i] != s_agua:
					_surf[j * nx + i] = s_sed

func _paint_polys(feats: Array, surface: String) -> void:
	for f in feats:
		_paint(_poly_nodes(_pts((f as Dictionary).get("poly", []))), surface)

func _paint_zones() -> void:
	var zones: Variant = _level.get("zones", [])
	if not (zones is Array):
		return
	for z in zones:  # corrales, polvorines y parques son suelo apisonado; las demás zonas son de reglas y no cambian el suelo
		if z is Dictionary and ["corral", "polvorin", "parque"].has(str((z as Dictionary).get("kind", ""))):
			_paint(_poly_nodes(_pts((z as Dictionary).get("poly", []))), "patio")

func _paint_strokes(feats: Array, surface: String, default_width_m: float) -> void:
	for f in feats:
		var width := float((f as Dictionary).get("width_m", default_width_m))
		_paint(_stroke_nodes(_pts((f as Dictionary).get("pts", [])), width * 0.5), surface)

func _paint(nodes: PackedInt32Array, surface: String) -> void:
	var sid: int = _sid[surface]
	for idx in nodes:
		if _solid[idx] == 0:
			_surf[idx] = sid

## Registra una pared opaca y sólida: sus segmentos para la visión y sus nodos para el paso. Devuelve su índice.
func _add_wall(pts: PackedVector2Array, height_m: float) -> int:
	var wi := _wall_gates.size()
	_wall_gates.append([])
	var arc := 0.0
	for k in range(pts.size() - 1):
		var seg_len := pts[k].distance_to(pts[k + 1])
		_walls.append([pts[k], pts[k + 1], height_m, wi, arc, seg_len])
		arc += seg_len
	var s_muro: int = _sid["muro"]
	for idx in _stroke_nodes(pts, 0.0):
		_solid[idx] = 1
		_obst[idx] = maxf(_obst[idx], height_m)
		_surf[idx] = s_muro
	return wi

## Abre un hueco en la tapia que cita `f.tapia` en `f.at` (fracción de 0 a 1 o metros desde el inicio; también acepta x/z propios).
func _carve_gate(f: Dictionary, walls_by_id: Dictionary, n: int) -> bool:
	var wall_id := str(f.get("tapia", ""))
	if not walls_by_id.has(wall_id):
		return false
	var wi: int = walls_by_id[wall_id]
	var width := float(f.get("width_m", 2.5))
	var is_open := str(f.get("state", "cerrado")) == "abierto"
	var at_arc := 0.0
	var total := 0.0
	var center := Vector2.ZERO
	var dir := Vector2.RIGHT
	var found := false
	for w in _walls:
		if int(w[3]) == wi:
			total = float(w[4]) + float(w[5])
	var at: Variant = f.get("at", 0.5)
	var has_pos := f.has("x") and f.has("z")
	var pos := Vector2(float(f["x"]), float(f["z"])) if has_pos else Vector2.ZERO
	if not has_pos and (at is Dictionary or at is Array):
		pos = _pt(at)
		has_pos = true
	if has_pos:  # una posición propia: se proyecta sobre la tapia
		var best := INF
		for w in _walls:
			if int(w[3]) != wi:
				continue
			var q := Geometry2D.get_closest_point_to_segment(pos, w[0], w[1])
			if pos.distance_to(q) < best:
				best = pos.distance_to(q)
				center = q
				at_arc = float(w[4]) + (w[0] as Vector2).distance_to(q)
				dir = ((w[1] as Vector2) - (w[0] as Vector2)).normalized()
				found = true
	else:  # una distancia a lo largo de la tapia: fracción de 0 a 1, o metros desde el inicio
		var s := clampf(float(at) * total if float(at) <= 1.0 else float(at), 0.0, total)
		at_arc = s
		for w in _walls:
			if int(w[3]) == wi and s >= float(w[4]) - 0.0001 and s <= float(w[4]) + float(w[5]) + 0.0001:
				dir = ((w[1] as Vector2) - (w[0] as Vector2)).normalized()
				center = (w[0] as Vector2) + dir * (s - float(w[4]))
				found = true
				break
	if not found:
		return false
	var id := str(f.get("id", "portillo_%d" % n))
	_gates[id] = center
	(_wall_gates[wi] as Array).append([id, at_arc - width * 0.5, at_arc + width * 0.5, is_open])
	var along_lim := maxf(width * 0.5, GATE_ALONG_MIN_M)
	var s_camino: int = _sid["camino"]
	for j in range(maxi(0, floori((center.y - along_lim - GATE_ACROSS_M) / cell_m)), mini(_jmax, ceili((center.y + along_lim + GATE_ACROSS_M) / cell_m)) + 1):
		for i in range(maxi(0, floori((center.x - along_lim - GATE_ACROSS_M) / cell_m)), mini(_imax, ceili((center.x + along_lim + GATE_ACROSS_M) / cell_m)) + 1):
			var rel := Vector2(float(i) * cell_m, float(j) * cell_m) - center
			if absf(rel.dot(dir)) > along_lim or absf(rel.cross(dir)) > GATE_ACROSS_M:
				continue
			var idx := j * nx + i
			if _solid[idx] == 0:
				continue
			_surf[idx] = s_camino
			if is_open:
				_solid[idx] = 0
				_obst[idx] = 0.0
			else:
				_gate_of_node[idx] = id
	return true

func _add_boxes() -> void:
	for lm in _landmarks:
		var d: Dictionary = lm
		if not BOX_TYPES.has(str(d.get("type", ""))) or float(d.get("height_m", 0.0)) <= 0.0:
			continue
		var poly := _footprint_poly(d)
		if poly.size() >= 3:
			_boxes.append({"id": str(d["id"]), "poly": poly, "h": float(d["height_m"])})

# ---------------------------------------------------------------------------------------------------------------------
# Rasterizado simple

## Nodos que toca un trazo: la línea fina (sin saltos en diagonal, para que una pared no se pueda cruzar por una esquina) y, si es ancho,
## todos los nodos a menos de `half_w` del eje.
func _stroke_nodes(pts: PackedVector2Array, half_w: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	if pts.size() == 1:
		out.append(_node_index(pts[0].x, pts[0].y))
	for k in range(pts.size() - 1):
		var a := pts[k]
		var b := pts[k + 1]
		var steps := maxi(1, ceili(a.distance_to(b) / (cell_m * 0.25)))
		var pi := -1
		var pj := -1
		for s in range(steps + 1):
			var p := a.lerp(b, float(s) / float(steps))
			var i := clampi(roundi(p.x / cell_m), 0, _imax)
			var j := clampi(roundi(p.y / cell_m), 0, _jmax)
			if pi >= 0 and i != pi and j != pj:
				out.append(pj * nx + i)
				out.append(j * nx + pi)
			out.append(j * nx + i)
			pi = i
			pj = j
		if half_w > cell_m * 0.5:
			for j in range(maxi(0, ceili((minf(a.y, b.y) - half_w) / cell_m)), mini(_jmax, floori((maxf(a.y, b.y) + half_w) / cell_m)) + 1):
				for i in range(maxi(0, ceili((minf(a.x, b.x) - half_w) / cell_m)), mini(_imax, floori((maxf(a.x, b.x) + half_w) / cell_m)) + 1):
					var q := Vector2(float(i) * cell_m, float(j) * cell_m)
					if q.distance_to(Geometry2D.get_closest_point_to_segment(q, a, b)) <= half_w:
						out.append(j * nx + i)
	return out

## Nodos cuyo centro cae dentro del polígono.
func _poly_nodes(poly: PackedVector2Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	if poly.size() < 3:
		return out
	var lo := poly[0]
	var hi := poly[0]
	for p in poly:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	for j in range(maxi(0, ceili(lo.y / cell_m)), mini(_jmax, floori(hi.y / cell_m)) + 1):
		for i in range(maxi(0, ceili(lo.x / cell_m)), mini(_imax, floori(hi.x / cell_m)) + 1):
			if Geometry2D.is_point_in_polygon(Vector2(float(i) * cell_m, float(j) * cell_m), poly):
				out.append(j * nx + i)
	return out

func _footprint_poly(lm: Dictionary) -> PackedVector2Array:
	var fp: Variant = lm.get("footprint", {})
	var c := Vector2(float(lm.get("x", 0.0)), float(lm.get("z", 0.0)))
	var yaw := deg_to_rad(float(lm.get("yaw_deg", 0.0)))
	var poly := PackedVector2Array()
	if not (fp is Dictionary):
		return poly
	var f: Dictionary = fp
	if f.get("poly", null) is Array:
		return _pts(f["poly"])
	if f.has("w") and f.has("d"):
		var hw := float(f["w"]) * 0.5
		var hd := float(f["d"]) * 0.5
		for corner in [Vector2(-hw, -hd), Vector2(hw, -hd), Vector2(hw, hd), Vector2(-hw, hd)]:
			poly.append(c + (corner as Vector2).rotated(yaw))
	elif f.has("r"):
		for k in range(8):
			poly.append(c + Vector2(float(f["r"]), 0.0).rotated(TAU * float(k) / 8.0))
	return poly

# ---------------------------------------------------------------------------------------------------------------------
# Utilidades

func _in_world(x: float, z: float) -> bool:
	return x >= 0.0 and z >= 0.0 and x <= size_m.x and z <= size_m.y

func _node_index(x: float, z: float) -> int:
	return clampi(roundi(z / cell_m), 0, _jmax) * nx + clampi(roundi(x / cell_m), 0, _imax)

func _wet_of(surface: String, rain: float) -> float:
	var w: Array = WET.get(surface, [0.0, 0.8])
	return clampf(float(w[0]) + clampf(rain, 0.0, 1.0) * float(w[1]), 0.0, 1.0)

func _speed_for(surface_id: int, rain: float) -> float:
	var s := str(VT.SURFACES[surface_id])
	if s == "zanja":
		return float(_mud.get("zanja", 0.5))  # la zanja frena igual con o sin lluvia
	return clampf(lerpf(1.0, float(_mud.get(s, MUD_OTHER)), _wet_of(s, rain)), 0.0, 1.0)

func _raw_features(kind: String, layout: String) -> Array:
	var key := str(VT.FEATURE_KEYS.get(kind, ""))
	var feats: Variant = _level.get("features", null)
	if key == "" or not (feats is Dictionary):
		return []
	var raw: Variant = (feats as Dictionary).get(key, null)
	var list: Array = []
	if raw is Array:
		list = raw
	elif raw is Dictionary:
		list = [raw]
	var out: Array = []
	for f in list:
		if f is Dictionary and (layout == "" or str((f as Dictionary).get("layout", "AB")).contains(layout)):
			out.append(f)
	return out

func _feature_distance(f: Dictionary, p: Vector2) -> float:
	if f.get("pts", null) is Array:
		var pts := _pts(f["pts"])
		var best := INF
		if pts.size() == 1:
			best = pts[0].distance_to(p)
		for k in range(pts.size() - 1):
			best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, pts[k], pts[k + 1])))
		return best
	if f.get("poly", null) is Array:
		var poly := _pts(f["poly"])
		if poly.size() >= 3 and Geometry2D.is_point_in_polygon(p, poly):
			return 0.0
		var best := INF
		for k in range(poly.size()):
			best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, poly[k], poly[(k + 1) % poly.size()])))
		return best
	if f.has("x") and f.has("z"):
		return Vector2(float(f["x"]), float(f["z"])).distance_to(p)
	if f.get("center", null) != null:
		return _pt(f["center"]).distance_to(p)
	return INF

## Los ids de portillo que nombra `open_gaps`: ids, diccionarios con "id" o posiciones (abre el portillo más cercano, a menos de 6 m).
func _open_ids(open_gaps: Array) -> Array:
	var ids: Array = []
	for g in open_gaps:
		if g is String or g is StringName:
			ids.append(str(g))
		elif g is Dictionary and (g as Dictionary).has("id"):
			ids.append(str((g as Dictionary)["id"]))
		elif g is Vector2 or g is Dictionary or g is Array:
			var p := _pt(g)
			var best := ""
			var best_d := 6.0
			for gid in _gates:
				if (_gates[gid] as Vector2).distance_to(p) < best_d:
					best_d = (_gates[gid] as Vector2).distance_to(p)
					best = str(gid)
			if best != "":
				ids.append(best)
	return ids

func _gate_open_at(wall_index: int, arc: float, open_ids: Array) -> bool:
	for g in _wall_gates[wall_index]:
		if arc >= float(g[1]) and arc <= float(g[2]) and (bool(g[3]) or open_ids.has(g[0])):
			return true
	return false

## Cruce de dos segmentos: (t sobre a→b, u sobre c→d) o (−1, −1).
static func _seg_hit(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> Vector2:
	var r := b - a
	var s := d - c
	var den := r.cross(s)
	if absf(den) < 0.000001:
		return Vector2(-1.0, -1.0)
	var ca := c - a
	var t := ca.cross(s) / den
	var u := ca.cross(r) / den
	if t < 0.0 or t > 1.0 or u < 0.0 or u > 1.0:
		return Vector2(-1.0, -1.0)
	return Vector2(t, u)

## Un punto del JSON: {x, z}, [x, z] o un hito/rasgo con x y z.
static func _pt(p: Variant) -> Vector2:
	if p is Vector2:
		return p
	if p is Dictionary:
		return Vector2(float((p as Dictionary).get("x", 0.0)), float((p as Dictionary).get("z", 0.0)))
	if p is Array and (p as Array).size() >= 2:
		return Vector2(float(p[0]), float(p[1]))
	return Vector2.ZERO

static func _pts(arr: Variant) -> PackedVector2Array:
	var out := PackedVector2Array()
	if arr is Array:
		for p in arr:
			out.append(_pt(p))
	return out
