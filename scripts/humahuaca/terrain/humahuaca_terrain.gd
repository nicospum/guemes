extends RefCounted
## HumahuacaTerrain: el terreno del nivel «Humahuaca» (CONTRATO 3.1). Dueña: relieve_mapa. UNA sola implementación de la altura, horneada en una
## malla de 4 m (226 × 164 nodos) y servida en O(1); la consumen las reglas (rutas, velocidad, visión), la vista (malla, picking) y la interfaz
## (mapa chico, rótulo del paraje). Ninguna otra clase interpola la grilla por su cuenta.
##
## Cómo se arma la altura (docs/humahuaca/RELIEVE.md):
##   1. VENTANA de 91 × 66 nodos a 10 m (data/humahuaca_height.json, decímetros enteros sobre el cero local de 2 940 m) → «relieve de juego»
##      (el builder ya la suavizó a `meta.smooth_m`) → Catmull-Rom separable a la malla de 4 m. Es lo que devuelve `height_dem_only`.
##   2. Se le suman las CAPAS DE DISEÑO de `humahuaca_map.json` (micro-relieve de semilla fija, quebraditas, cauce, y el domo de la batería como
##      RESIDUO: su `delta_m` se resuelve acá, al cargar, para que la prominencia final sea la pedida con CUALQUIER fuente) y la plataforma.
##   3. Fuera de la ventana: el CONTEXTO de 121 × 91 nodos a 30 m (bilineal) con mezcla continua en los 60 m exteriores; más allá del contexto
##      la lectura se sujeta al borde (continua hasta x ∈ [−1350, 2250], z ∈ [−1050, 1700] y más).
## Las superficies y los rasgos (tapias, zanjas, caminos, río) se rasterizan UNA vez desde humahuaca_level.json y el mapa.
## Todo es dato actual del relieve (rotulado «razonado», ±10 m con la lámina 03) MÁS capas de diseño que `report()` rotula como tales.
## Sin `class_name`; solo importa vocabularios y los auxiliares de su carpeta (regla de dependencia hacia abajo, V19).

const V = preload("res://scripts/humahuaca/humahuaca_vocab.gd")
const VT = preload("res://scripts/humahuaca/terrain/vocab_terrain.gd")
const Relief = preload("res://scripts/humahuaca/terrain/terrain_relief.gd")
const Raster = preload("res://scripts/humahuaca/terrain/terrain_raster.gd")
const Sight = preload("res://scripts/humahuaca/terrain/terrain_sight.gd")
const Minimap = preload("res://scripts/humahuaca/terrain/terrain_minimap.gd")

const CELL_M := 4.0
const EXTERIOR_BLEND_M := 60.0  # mezcla continua entre la ventana y el contexto
const FORD_RADIUS_M := 14.0
const MUD_OTHER := 0.9  # velocidad con barro de una superficie que el mapa no lista en surfaces.mud
const MUD_FALLBACK := {"camino": 0.9, "suelo_seco": 0.95, "sedimento_humedo": 0.75, "irrigado": 0.6, "zanja": 0.5, "agua": 0.5}
const WET := {  # superficie → [humedad base, ganancia por lluvia]
	"suelo_seco": [0.0, 0.8], "sedimento_humedo": [0.5, 0.5], "piedra": [0.0, 0.3], "churqui": [0.0, 0.7], "irrigado": [0.4, 0.6],
	"agua": [1.0, 0.0], "camino": [0.0, 0.9], "patio": [0.0, 0.9], "zanja": [0.7, 0.3], "muro": [0.0, 0.0]}
const FLAT_DM := 170.0  # sin archivo de relieve: plano a +17 m (la cota del templo), rotulado «diseno» en report()
const LAMINA_OK_M := 12.0  # R02: al menos 37 de 41 puntos a 12 m o menos de la estimación de la lámina
const LAMINA_MAX_M := 20.0  # y ninguno a más de 20 m

static var _default: RefCounted = null

# --- contrato 3.1: propiedades ---
var size_m := Vector2(900.0, 650.0)
var cell_m := CELL_M
var nx := 226
var nz := 164
var datum_asl_m := 2940.0
var anchor := Vector2(450.0, 325.0)

# --- datos de entrada ---
var _map: Dictionary = {}
var _level: Dictionary = {}
var _meta: Dictionary = {}
var _lamina_off := Vector2(450.0, 325.0)
var _imax := 225
var _jmax := 162
var _win := PackedFloat32Array()  # ventana de 10 m en metros sobre el cero local
var _wnx := 91
var _wnz := 66
var _wcell := 10.0
var _ctx := PackedFloat32Array()
var _cnx := 121
var _cnz := 91
var _ccell := 30.0
var _cox := -1350.0
var _coz := -1025.0
var _height_ok := true

# --- relieve horneado (malla de 4 m) ---
var _hd := PackedFloat32Array()  # solo el DEM de juego
var _h := PackedFloat32Array()  # altura final: DEM + capas de diseño + micro-relieve
var _h_macro := PackedFloat32Array()  # idem sin el micro-relieve (la lee el mapa chico: curvas de nivel y sombreado del relieve, no de las ondas finas)
var _h_pre := PackedFloat32Array()  # altura final sin domo ni plataforma (para medir «con y sin el rasgo»)
var _grad := PackedFloat32Array()  # módulo del gradiente por nodo (tangente de la pendiente)
var _slopef := PackedFloat32Array()  # factor de velocidad por pendiente por nodo
var _slope_start_deg := 8.0
var _slope_per_deg := 0.03
var _slope_floor := 0.6
var _slope_pct_ge8 := 0.0

# --- superficies, paso y visión (rasterizado una sola vez) ---
var _sid: Dictionary = {}
var _surf := PackedByteArray()
var _solid := PackedByteArray()
var _weight := PackedFloat32Array()
var _mud_by_sid := PackedFloat32Array()
var _wet_base := PackedFloat32Array()
var _wet_gain := PackedFloat32Array()
var _walls: Array = []  # segmentos opacos: [a, b, alto, índice de pared, arco al inicio, largo]
var _wall_gates: Array = []  # por pared: [[id, arco0, arco1, abierto_de_origen], ...]
var _gates: Dictionary = {}  # id de portillo → posición
var _gate_of_node: Dictionary = {}  # índice de nodo → id de portillo (los nodos que se liberan al abrirlo)
var _boxes: Array = []  # edificios que tapan la vista: {id, poly, h, ground}
var _platforms: Array = []  # plataformas de diseño (la visión pasa por encima de su propio borde): {id, cx, cz, ca, sa, half_l, half_w, falloff}
var _map_layers: Array = []  # surfaces.layers del mapa

# --- hitos, río y capas ---
var _landmarks: Array = []
var _lm_by_id: Dictionary = {}
var _river: Dictionary = {}
var _river_pts := PackedVector2Array()
var _river_w := PackedFloat32Array()
var _ford_pts := PackedVector2Array()
var _ford_r := PackedFloat32Array()
var _rd := PackedFloat32Array()  # distancia al eje del río por nodo (1e9 lejos del cauce)
var _rhw := PackedFloat32Array()  # semiancho del lecho en el punto más cercano
var _layers: Array = []  # capas de diseño leídas del mapa, con los valores resueltos
var _micro: Dictionary = {}

# --- caché e informe ---
var _hf: Dictionary = {}
var _cf: Dictionary = {}
var _minimap_cache: Dictionary = {}
var _vertical: Array = []
var _vertical_done := false
var _lamina: Dictionary = {"n": 0, "ok": 0, "max_err_m": 0.0, "failed": []}
var _prominence := 0.0
var _counts: Dictionary = {}
var _stages_ms: Dictionary = {}
var _bake_ms := 0.0
var _t_lap := 0


## `new()` a secas arma el terreno con los datos del juego. `new({"map": ..., "height": ..., "level": ...})` arma uno con otras fuentes: cada valor es un
## Dictionary ya leído o la ruta de un JSON (res:// o user://). Así la prueba A/B de fuente carga una fuente nueva desde un archivo temporal sin tocar nada.
func _init(sources: Dictionary = {}) -> void:
	var map: Dictionary = _source(sources.get("map", V.MAP_PATH))
	var level: Dictionary = _source(sources.get("level", V.LEVEL_PATH))
	var height_src: Variant = sources.get("height", null)
	if height_src == null:
		height_src = str((map.get("relief", {}) as Dictionary).get("height_file", V.HEIGHT_PATH)) if not map.is_empty() else V.HEIGHT_PATH
	_bake(map, _source(height_src), level)


## El terreno del proceso (caché). null, con push_error, si faltan los JSON de relieve o de mapa.
static func load_default() -> RefCounted:
	if _default != null:
		return _default
	var map: Dictionary = V.load_json(V.MAP_PATH)
	var height: Dictionary = V.load_json(V.HEIGHT_PATH)
	if map.is_empty() or height.is_empty():
		push_error("Terreno de Humahuaca: faltan o no sirven " + V.MAP_PATH + " y " + V.HEIGHT_PATH)
		return null
	_default = new({"map": map, "height": height, "level": V.LEVEL_PATH})
	return _default


## Arma un terreno con los diccionarios dados, sin caché.
static func from_data(map: Dictionary, height: Dictionary, level: Dictionary = {}) -> RefCounted:
	return new({"map": map, "height": height, "level": level})


## Arma un terreno con otros archivos (la prueba A/B de fuente), sin caché.
static func from_paths(map_path: String, height_path: String, level_path: String = V.LEVEL_PATH) -> RefCounted:
	return new({"map": map_path, "height": height_path, "level": level_path})


static func _source(v: Variant) -> Dictionary:
	if v is Dictionary:
		return v
	if v is String and str(v) != "":
		return V.load_json(str(v))
	return {}


# ---------------------------------------------------------------------------------------------------------------------
# Conversión lámina ↔ juego (la única permitida: x = E + 450, z = 325 − N)

func lamina_to_game(e: float, n: float) -> Vector2:
	return Vector2(e + _lamina_off.x, _lamina_off.y - n)


func game_to_lamina(p: Vector2) -> Vector2:
	return Vector2(p.x - _lamina_off.x, _lamina_off.y - p.y)


# ---------------------------------------------------------------------------------------------------------------------
# Altura

## Metros sobre el cero local. Continua en todo el plano: dentro de la ventana, bilineal sobre la malla de 4 m (la misma que dibuja la vista);
## afuera, el contexto con la mezcla de los 60 m exteriores.
func height_at(x: float, z: float) -> float:
	if x >= 0.0 and z >= 0.0 and x <= size_m.x and z <= size_m.y:
		var fx := x * 0.25
		var fz := z * 0.25
		var i := mini(int(fx), nx - 2)
		var j := mini(int(fz), nz - 2)
		var tx := fx - float(i)
		var tz := fz - float(j)
		var k := j * nx + i
		var a := _h[k]
		var b := _h[k + 1]
		var c := _h[k + nx]
		var d := _h[k + nx + 1]
		return a + (b - a) * tx + (c - a) * tz + (a - b - c + d) * tx * tz
	return _outside(_h, x, z)


## Solo el «relieve de juego» (DEM suavizado a 30 m e interpolado a 4 m), sin capas de diseño ni micro-relieve: es lo que se compara con la lámina 03.
func height_dem_only(x: float, z: float) -> float:
	return _hf_lookup(_hd, x, z)


func asl_at(x: float, z: float) -> float:
	return height_at(x, z) + datum_asl_m


func normal_at(x: float, z: float) -> Vector3:
	var e := 1.0
	var gx := (height_at(x + e, z) - height_at(x - e, z)) / (2.0 * e)
	var gz := (height_at(x, z + e) - height_at(x, z - e)) / (2.0 * e)
	return Vector3(-gx, 1.0, -gz).normalized()


## Pendiente en grados (diferencias centrales de 2 m de cada lado sobre height_at).
func slope_deg_at(x: float, z: float) -> float:
	var e := 2.0
	var gx := (height_at(x + e, z) - height_at(x - e, z)) / (2.0 * e)
	var gz := (height_at(x, z + e) - height_at(x, z - e)) / (2.0 * e)
	return rad_to_deg(atan(sqrt(gx * gx + gz * gz)))


func elevation_advantage(a: Vector2, b: Vector2) -> float:
	return height_at(a.x, a.y) - height_at(b.x, b.y)


## Lectura de una malla de 4 m (la final, la del DEM o una alternativa) con la misma regla de la ventana y del contexto.
func _hf_lookup(arr: PackedFloat32Array, x: float, z: float) -> float:
	if x >= 0.0 and z >= 0.0 and x <= size_m.x and z <= size_m.y:
		return Relief.bilerp(arr, nx, nz, cell_m, x, z)
	return _outside(arr, x, z)


## Fuera de la ventana: el contexto, más la diferencia que trae el borde de la ventana respecto del contexto, apagada en `EXTERIOR_BLEND_M` metros.
func _outside(arr: PackedFloat32Array, x: float, z: float) -> float:
	var cx := clampf(x, 0.0, size_m.x)
	var cz := clampf(z, 0.0, size_m.y)
	var d := Vector2(x - cx, z - cz).length()
	var base := _ctx_at(x, z)
	if d >= EXTERIOR_BLEND_M:
		return base
	var inside := Relief.bilerp(arr, nx, nz, cell_m, cx, cz)
	var edge := _ctx_at(cx, cz)
	return base + (inside - edge) * (1.0 - Relief.sstep(0.0, EXTERIOR_BLEND_M, d))


func _ctx_at(x: float, z: float) -> float:
	var fx := clampf((x - _cox) / _ccell, 0.0, float(_cnx - 1))
	var fz := clampf((z - _coz) / _ccell, 0.0, float(_cnz - 1))
	var i := mini(int(fx), _cnx - 2)
	var j := mini(int(fz), _cnz - 2)
	var tx := fx - float(i)
	var tz := fz - float(j)
	var k := j * _cnx + i
	var a := _ctx[k]
	var b := _ctx[k + 1]
	var c := _ctx[k + _cnx]
	var d := _ctx[k + _cnx + 1]
	return a + (b - a) * tx + (c - a) * tz + (a - b - c + d) * tx * tz


# ---------------------------------------------------------------------------------------------------------------------
# Superficie, humedad, paso y visión

func surface_at(x: float, z: float) -> String:
	if not _in_world(x, z):
		return "suelo_seco"
	return str(VT.SURFACES[_surf[_node_index(x, z)]])


func wetness_at(x: float, z: float, rain: float = 0.0) -> float:
	if not _in_world(x, z):
		return 0.0
	return _wet_of(_surf[_node_index(x, z)], rain)


## ¿Se puede pasar? Falso afuera del mundo y sobre muro o tapia (salvo un portillo que `open_gaps` abre). El agua del Río Grande se vadea: no bloquea.
## `mounted` no cambia nada en R1 (reservado).
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


## Fracción de la velocidad de marcha que se conserva en ese punto: superficie (con barro según la lluvia) por pendiente. 0 = intransitable.
@warning_ignore("unused_parameter")
func speed_factor_at(x: float, z: float, rain: float = 0.0, mounted: bool = false) -> float:
	if not _in_world(x, z):
		return 0.0
	var idx := _node_index(x, z)
	if _solid[idx] == 1 and not _gate_of_node.has(idx):
		return 0.0  # el nodo de un portillo se cruza (is_blocked dice si está abierto); una tapia no
	return _speed_for(_surf[idx], rain) * _slopef[idx]


## Visión entre dos puntos del plano a la altura de los ojos de cada uno, sobre relieve, tapias (salvo portillos abiertos) y edificios.
func los(a: Vector2, b: Vector2, eye_a: float = 1.6, eye_b: float = 1.6, open_gaps: Array = []) -> bool:
	return Sight.los(self, a, b, eye_a, eye_b, open_gaps)


## Lo mismo sobre una malla de alturas alternativa (4 m): la prueba de «rasgos verticales con consecuencia» compara con y sin cada rasgo.
func los_on(heights: PackedFloat32Array, a: Vector2, b: Vector2, eye_a: float = 1.6, eye_b: float = 1.6, open_gaps: Array = []) -> bool:
	return Sight.los(self, a, b, eye_a, eye_b, open_gaps, heights)


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
	for n in range(_ford_pts.size()):
		if _ford_pts[n].distance_to(Vector2(x, z)) <= _ford_r[n]:
			return true
	return false


## Las alturas de la malla de 4 m SIN el domo ni la plataforma de la batería (el DEM más el micro-relieve, las quebraditas y el cauce): sirve para medir con
## `los_on` qué cambia el rasgo de diseño. Solo lectura.
func heights_without_dome() -> PackedFloat32Array:
	return _h_pre


## Polígono de la huella de un hito (VP-03: esquinas = centro + R(yaw)·(±w/2, ±d/2), giro horario visto en el mapa). Vacío si no hay hito.
func footprint_polygon(id: String) -> PackedVector2Array:
	if not _lm_by_id.has(id):
		return PackedVector2Array()
	return Raster.footprint_poly(_lm_by_id[id])


# ---------------------------------------------------------------------------------------------------------------------
# Campos para la vista y la navegación

## La malla de juego (226 × 164 nodos de 4 m, origen en (0, 0)): es la que el terreno lee en height_at. Solo lectura.
func heightfield() -> Dictionary:
	if _hf.is_empty():
		_hf = {"nx": nx, "nz": nz, "cell": cell_m, "origin_x": 0.0, "origin_z": 0.0, "h": _h}
	return _hf


## El contexto de 121 × 91 nodos de 30 m (el dominio de la lámina 03), tal como está en el archivo (sin la mezcla de la ventana). Solo lectura.
func context_field() -> Dictionary:
	if _cf.is_empty():
		_cf = {"nx": _cnx, "nz": _cnz, "cell": _ccell, "origin_x": _cox, "origin_z": _coz, "h": _ctx}
	return _cf


## Malla de rutas estática (los portillos cerrados son sólidos): `solid` 1 = no se cruza; `weight` = multiplicador de costo (1 / velocidad en seco).
func nav_grid() -> Dictionary:
	return {"nx": nx, "nz": nz, "cell": cell_m, "origin_x": 0.0, "origin_z": 0.0, "solid": _solid, "weight": _weight}


## Mapa chico: relieve sombreado, curvas de 20 m y cauce, norte arriba y sin unidades. Mide EXACTAMENTE `px`. opts: shade, contours, river, surfaces, exaggeration.
func minimap_image(px: Vector2i, opts: Dictionary = {}) -> Image:
	var key := "%d,%d,%s" % [px.x, px.y, JSON.stringify(opts)]
	if not _minimap_cache.has(key):
		if _minimap_cache.size() > 6:
			_minimap_cache.clear()
		_minimap_cache[key] = Minimap.render(self, px, opts)
	return (_minimap_cache[key] as Image).duplicate()


# ---------------------------------------------------------------------------------------------------------------------
# Informe

func report() -> Dictionary:
	var h_min := 1.0e9
	var h_max := -1.0e9
	for v in _h:
		h_min = minf(h_min, v)
		h_max = maxf(h_max, v)
	var layers_out: Array = []
	for l in _layers:
		layers_out.append({"id": l["id"], "kind": l["kind"], "delta_m": snappedf(float(l.get("delta_m", 0.0)), 0.01),
			"prominence_target_m": float(l.get("prominence_target_m", 0.0)), "tag": str(l.get("tag", "diseno"))})
	if not _vertical_done:
		_vertical = _vertical_features()
		_vertical_done = true
	return {"source": str(_meta.get("source", "ausente")), "tag": str(_meta.get("tag", "diseno")), "uncertainty_m": float(_meta.get("uncertainty_m", 25.0)),
		"smooth_m": float(_meta.get("smooth_m", 0.0)), "h_min": snappedf(h_min, 0.01), "h_max": snappedf(h_max, 0.01), "design_layers": layers_out,
		"prominence_bateria_m": snappedf(_prominence, 0.001), "slope_cells_pct_ge8": snappedf(_slope_pct_ge8, 0.001), "vertical_features": _vertical.duplicate(true),
		"lamina_check": _lamina.duplicate(true), "bake_ms": _bake_ms, "bake_stages_ms": _stages_ms.duplicate(), "counts": _counts.duplicate(),
		"labels": {
			"dato_actual": ["relieve base (ventana de 10 m y contexto de 30 m): dato actual, no restitución del suelo de 1817", "traza moderna del Río Grande (OpenStreetMap, ODbL)"],
			"diseno": ["cerro_bateria", "plataforma_bateria", "quebradita_norte", "quebradita_sur", "cauce_rio", "micro_relieve", "tapias, zanjas y superficies de level.json", "vados"],
			"texto": "Dato actual, no restitución del suelo de 1817: relieve de la fuente «%s» (±%s m). Las capas de diseño están rotuladas como tales." % [str(_meta.get("source", "ausente")), str(_meta.get("uncertainty_m", 25.0))]},
		"height_file_ok": _height_ok, "dome_delta_m": snappedf(float(_dome_delta()), 0.001)}


func _dome_delta() -> float:
	for l in _layers:
		if str(l["kind"]) == "dome":
			return float(l.get("delta_m", 0.0))
	return 0.0


## Rasgos verticales con consecuencia (R2a lo exige; R1 lo informa): cuántos pares de puntos cambian su visión (`los`) o su velocidad con y sin el rasgo.
func _vertical_features() -> Array:
	var out: Array = []
	for l in _layers:
		var kind := str(l["kind"])
		if kind != "dome" and kind != "gully":
			continue
		var without := PackedFloat32Array()
		if kind == "dome":
			without = _h_pre
		else:
			without = _h.duplicate()
			Relief.add_gully(without, nx, nz, cell_m, l["center"], float(l["length_m"]), float(l["width_m"]), float(l.get("yaw_deg", 0.0)),
				-float(l["delta_m"]), float(l.get("falloff_m", 10.0)), str(l.get("open_side", "oeste")), -float(l.get("bank_m", 0.0)))
		var c: Vector2 = l["center"]
		var reach := float(l.get("radius_m", 0.5 * float(l.get("length_m", 20.0)) + 30.0))
		var los_pairs := 0
		var speed_pairs := 0
		for k in range(12):
			var ang := TAU * float(k) / 12.0
			var dir := Vector2(cos(ang), sin(ang))
			for dist in [0.35, 0.7, 1.2, 1.8]:
				var p := c + dir * reach * float(dist)
				if not _in_world(p.x, p.y):
					continue
				var a := c
				if kind == "dome":
					a = c + Vector2(13.0, 5.0)  # la plataforma de la batería
				if los(a, p, 1.6, 1.6) != los_on(without, a, p, 1.6, 1.6):
					los_pairs += 1
				if absf(_slopef_on(_h, p) - _slopef_on(without, p)) > 0.01:
					speed_pairs += 1
		out.append({"id": str(l["id"]), "los_pairs": los_pairs, "speed_pairs": speed_pairs})
	return out


## Factor de velocidad por pendiente en un punto sobre una malla dada (diferencias centrales de un nodo): sirve para comparar con y sin un rasgo.
func _slopef_on(arr: PackedFloat32Array, p: Vector2) -> float:
	var gx := (_hf_lookup(arr, p.x + cell_m, p.y) - _hf_lookup(arr, p.x - cell_m, p.y)) / (2.0 * cell_m)
	var gz := (_hf_lookup(arr, p.x, p.y + cell_m) - _hf_lookup(arr, p.x, p.y - cell_m)) / (2.0 * cell_m)
	var deg := rad_to_deg(atan(sqrt(gx * gx + gz * gz)))
	return clampf(1.0 - _slope_per_deg * (deg - _slope_start_deg), _slope_floor, 1.0) if deg > _slope_start_deg else 1.0


# ---------------------------------------------------------------------------------------------------------------------
# Horneado (una sola vez, por etapas)

func _bake(map: Dictionary, height: Dictionary, level: Dictionary) -> void:
	var t_start := Time.get_ticks_usec()
	_t_lap = t_start
	_map = map
	_level = level
	_read_basics(height)
	_lap("lectura")
	_bake_relief()
	_lap("relieve")
	_bake_layers()
	_lap("capas")
	Raster.bake_slopes(self)
	_lap("pendiente")
	Raster.bake_surfaces(self)
	_lap("superficies")
	Raster.bake_walls(self)
	Raster.bake_boxes(self)
	_lap("muros")
	Raster.bake_nav(self)
	_lap("navegacion")
	_finish_stats()
	_lap("informe")
	_bake_ms = snappedf(float(Time.get_ticks_usec() - t_start) / 1000.0, 0.01)


func _lap(stage: String) -> void:
	var now := Time.get_ticks_usec()
	_stages_ms[stage] = snappedf(float(now - _t_lap) / 1000.0, 0.01)
	_t_lap = now


func _read_basics(height: Dictionary) -> void:
	var sz: Variant = _map.get("size_m", null)
	if sz is Dictionary:
		size_m = Vector2(float((sz as Dictionary).get("x", 900.0)), float((sz as Dictionary).get("z", 650.0)))
	var an: Variant = _map.get("anchor", null)
	if an is Dictionary:
		anchor = Vector2(float((an as Dictionary).get("x", 450.0)), float((an as Dictionary).get("z", 325.0)))
	var lam: Variant = _map.get("lamina", null)
	if lam is Dictionary:
		_lamina_off = Vector2(float((lam as Dictionary).get("offset_x", 450.0)), float((lam as Dictionary).get("offset_z", 325.0)))
	cell_m = CELL_M
	_imax = floori(size_m.x / cell_m)
	_jmax = floori(size_m.y / cell_m)
	nx = ceili(size_m.x / cell_m) + 1
	nz = ceili(size_m.y / cell_m) + 1
	_meta = (height.get("meta", {}) as Dictionary) if height.get("meta", null) is Dictionary else {}
	datum_asl_m = float(_meta.get("datum_asl_m", _map.get("datum_asl_m", 2940.0)))
	_read_grids(height)
	for i in range(VT.SURFACES.size()):
		_sid[VT.SURFACES[i]] = i
	var mud: Dictionary = MUD_FALLBACK.duplicate()
	var surfaces: Variant = _map.get("surfaces", null)
	_map_layers = []
	if surfaces is Dictionary:
		if (surfaces as Dictionary).get("mud", null) is Dictionary:
			for k in (surfaces as Dictionary)["mud"]:
				mud[str(k)] = clampf(float(surfaces["mud"][k]), 0.0, 1.0)
		if (surfaces as Dictionary).get("layers", null) is Array:
			_map_layers = surfaces["layers"]
		var sp: Variant = (surfaces as Dictionary).get("slope_penalty", null)
		if sp is Dictionary:
			_slope_start_deg = float((sp as Dictionary).get("start_deg", 8.0))
			_slope_per_deg = float((sp as Dictionary).get("per_deg", 0.03))
			_slope_floor = float((sp as Dictionary).get("floor", 0.6))
	for sname in VT.SURFACES:
		_mud_by_sid.append(float(mud.get(sname, MUD_OTHER)))
		var w: Array = WET.get(sname, [0.0, 0.8])
		_wet_base.append(float(w[0]))
		_wet_gain.append(float(w[1]))
	_read_landmarks()
	_read_river()
	_read_layers()
	_surf.resize(nx * nz)
	_surf.fill(_sid["suelo_seco"])
	_solid.resize(nx * nz)
	_solid.fill(0)
	for j in range(nz):  # los nodos fuera de la ventana (el último renglón, z = 652 m) no se pisan
		for i in range(nx):
			if float(i) * cell_m > size_m.x or float(j) * cell_m > size_m.y:
				_solid[j * nx + i] = 1
	_weight.resize(nx * nz)
	_grad.resize(nx * nz)
	_slopef.resize(nx * nz)
	_counts = {"hitos": _landmarks.size(), "nodos": nx * nz, "capas_de_diseno": _layers.size(), "puntos_de_rio": _river_pts.size()}


## Ventana y contexto del archivo de relieve (decímetros enteros → metros). Sin archivo o con una forma que no cierra: plano a +17 m, rotulado «diseno».
func _read_grids(height: Dictionary) -> void:
	var win: Variant = height.get("window", null)
	var ctx: Variant = height.get("context", null)
	_height_ok = win is Dictionary and ctx is Dictionary
	if _height_ok:
		_wnx = int((win as Dictionary).get("nx", 91))
		_wnz = int((win as Dictionary).get("nz", 66))
		_wcell = float((win as Dictionary).get("cell_m", 10.0))
		_cnx = int((ctx as Dictionary).get("nx", 121))
		_cnz = int((ctx as Dictionary).get("nz", 91))
		_ccell = float((ctx as Dictionary).get("cell_m", 30.0))
		_cox = float((ctx as Dictionary).get("origin_x", -1350.0))
		_coz = float((ctx as Dictionary).get("origin_z", -1025.0))
		var wh: Variant = (win as Dictionary).get("h", null)
		var ch: Variant = (ctx as Dictionary).get("h", null)
		_height_ok = wh is Array and ch is Array and (wh as Array).size() == _wnx * _wnz and (ch as Array).size() == _cnx * _cnz \
			and float((win as Dictionary).get("origin_x", 0.0)) == 0.0 and float((win as Dictionary).get("origin_z", 0.0)) == 0.0
		if _height_ok:
			_win = PackedFloat32Array(wh)
			_ctx = PackedFloat32Array(ch)
			for k in range(_win.size()):
				_win[k] *= 0.1
			for k in range(_ctx.size()):
				_ctx[k] *= 0.1
	if not _height_ok:
		_wnx = 91
		_wnz = 66
		_wcell = 10.0
		_cnx = 121
		_cnz = 91
		_ccell = 30.0
		_cox = -1350.0
		_coz = -1025.0
		_win.resize(_wnx * _wnz)
		_win.fill(FLAT_DM * 0.1)
		_ctx.resize(_cnx * _cnz)
		_ctx.fill(FLAT_DM * 0.1)
		_meta = {"source": "ausente", "tag": "diseno", "uncertainty_m": 25.0, "smooth_m": 0.0}


func _read_landmarks() -> void:
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


func _read_river() -> void:
	var rv: Variant = _map.get("river", null)
	_river_pts = PackedVector2Array()
	_river_w = PackedFloat32Array()
	_ford_pts = PackedVector2Array()
	_ford_r = PackedFloat32Array()
	if rv is Dictionary and (rv as Dictionary).get("pts", null) is Array and ((rv as Dictionary)["pts"] as Array).size() >= 2:
		_river = (rv as Dictionary).duplicate(true)
		var bed: Variant = (rv as Dictionary).get("bed_width_m", {})
		var mid := 32.5
		if bed is Dictionary:
			mid = 0.5 * (float((bed as Dictionary).get("min", 25.0)) + float((bed as Dictionary).get("max", 40.0)))
		for p in (rv as Dictionary)["pts"]:
			_river_pts.append(_pt(p))
			_river_w.append(float((p as Dictionary).get("w", mid)) if p is Dictionary else mid)
		var fords: Variant = (rv as Dictionary).get("fords", [])
		if fords is Array:
			for f in fords:
				_ford_pts.append(_pt(f))
				_ford_r.append(float((f as Dictionary).get("r_m", FORD_RADIUS_M)) if f is Dictionary else FORD_RADIUS_M)
	else:
		_river = {"id": "rio_grande", "bed_width_m": {"min": 25.0, "max": 40.0}, "depth_m": {"min": 0.2, "max": 0.6}, "fords": [], "tag": "diseno",
			"source": "Sin traza en el mapa: el terreno no tiene río"}
	if _ford_pts.is_empty() and _lm_by_id.has("vado_este"):
		_ford_pts.append(_pt(_lm_by_id["vado_este"]))
		_ford_r.append(FORD_RADIUS_M)
	var pts_out: Array = []
	for n in range(_river_pts.size()):
		pts_out.append({"x": _river_pts[n].x, "z": _river_pts[n].y, "w": _river_w[n]})
	_river["pts"] = pts_out
	var fords_out: Array = []
	for n in range(_ford_pts.size()):
		fords_out.append({"x": _ford_pts[n].x, "z": _ford_pts[n].y, "r_m": _ford_r[n]})
	_river["fords"] = fords_out


## Capas de diseño del mapa (relief.design_layers) en la forma que usa el horneado: centro como Vector2 y el resto de los números del JSON.
func _read_layers() -> void:
	_layers = []
	var relief: Variant = _map.get("relief", null)
	if not (relief is Dictionary):
		return
	var micro: Variant = (relief as Dictionary).get("micro", null)
	_micro = (micro as Dictionary).duplicate(true) if micro is Dictionary else {}
	var dl: Variant = (relief as Dictionary).get("design_layers", [])
	if not (dl is Array):
		return
	for l in dl:
		if not (l is Dictionary) or not VT.LAYER_KINDS.has(str((l as Dictionary).get("kind", ""))):
			continue
		var info: Dictionary = (l as Dictionary).duplicate(true)
		info["center"] = _pt(info.get("center", {}))
		_layers.append(info)


## Datos de una capa de diseño por id ({} si no existe): lo usan las reglas de superficie («ring» y «layer_area»).
func _layer_info(id: String) -> Dictionary:
	for l in _layers:
		if str(l["id"]) == id:
			return l
	return {}


func _bake_relief() -> void:
	_hd = Relief.resample_catmull(_win, _wnx, _wnz, _wcell, nx, nz, cell_m)
	var exaggeration := float(((_map.get("relief", {}) as Dictionary).get("exaggeration", 1.0))) if _map.get("relief", null) is Dictionary else 1.0
	if absf(exaggeration - 1.0) > 0.0001:  # solo el componente DEM, alrededor de la cota del ancla (rotulado diseño)
		var ref := Relief.bilerp(_hd, nx, nz, cell_m, anchor.x, anchor.y)
		for k in range(_hd.size()):
			_hd[k] = ref + (_hd[k] - ref) * exaggeration
	_h = _hd.duplicate()


## Quebraditas, cauce, domo (como residuo) y plataforma sobre el DEM, y después el micro-relieve (que la plataforma apaga, porque es plana). El domo se
## resuelve acá: la plataforma de la batería queda a `prominence_target_m` sobre la media de su anillo de 135 m (la medida del QA), vale lo que valga el
## DEM de la fuente. El micro-relieve se calcula aparte: la lectura bilineal es lineal, así que su aporte al anillo es exacto.
func _bake_layers() -> void:
	var micro_field := PackedFloat32Array()
	micro_field.resize(nx * nz)
	if not _micro.is_empty():
		var params := Relief.micro_params(int(_micro.get("seed", 1817)), float(_micro.get("wavelength_m", 25.0)))
		Relief.add_micro(micro_field, nx, nz, cell_m, params, float(_micro.get("amp_m", 0.5)), float(_micro.get("edge_fade_m", 40.0)), size_m)
	var dome: Dictionary = {}
	var plat: Dictionary = {}
	var carve: Dictionary = {}
	for l in _layers:
		match str(l["kind"]):
			"gully":
				Relief.add_gully(_h, nx, nz, cell_m, l["center"], float(l["length_m"]), float(l["width_m"]), float(l.get("yaw_deg", 0.0)), float(l["delta_m"]),
					float(l.get("falloff_m", 10.0)), str(l.get("open_side", "oeste")), float(l.get("bank_m", 0.0)))
			"dome":
				dome = l
			"platform":
				plat = l
			"carve":
				carve = l
	_rd.resize(nx * nz)
	_rd.fill(1.0e9)
	_rhw.resize(nx * nz)
	_rhw.fill(0.0)
	if not carve.is_empty() and _river_pts.size() >= 2:
		var rc: Array = Relief.carve_river(_h, nx, nz, cell_m, _river_pts, _river_w, float(carve["delta_m"]), float(carve.get("falloff_m", 12.0)))
		_rd = rc[0]
		_rhw = rc[1]
	_h_pre = _h.duplicate()
	for k in range(_h_pre.size()):
		_h_pre[k] += micro_field[k]
	var flat_w := PackedFloat32Array()
	flat_w.resize(nx * nz)
	if not dome.is_empty():
		var dc: Vector2 = dome["center"]
		var support := float(dome["radius_m"])
		var core := float(dome.get("core_m", 16.0))
		var at: Vector2 = plat["center"] if not plat.is_empty() else dc
		var ring := Relief.ring_mean(_h, nx, nz, cell_m, dc) + Relief.ring_mean(micro_field, nx, nz, cell_m, dc)
		var level := ring + float(dome.get("prominence_target_m", 12.0))
		var profile_at := Relief.dome_profile(at.distance_to(dc), core, support)
		var delta := (level - Relief.bilerp(_hd, nx, nz, cell_m, at.x, at.y)) / maxf(profile_at, 0.05)
		dome["delta_m"] = delta
		dome["ring_mean_m"] = ring
		dome["level_m"] = level
		Relief.add_dome(_h, nx, nz, cell_m, dc, core, support, delta)
		if not plat.is_empty():
			flat_w = Relief.level_platform(_h, nx, nz, cell_m, at, float(plat["length_m"]), float(plat["width_m"]), float(plat.get("yaw_deg", 0.0)),
				float(plat.get("falloff_m", 6.0)), level)
			plat["delta_m"] = level - Relief.bilerp(_hd, nx, nz, cell_m, at.x, at.y)
			var yaw := deg_to_rad(float(plat.get("yaw_deg", 0.0)))
			_platforms.append({"id": str(plat["id"]), "cx": at.x, "cz": at.y, "ca": cos(yaw), "sa": sin(yaw), "half_l": 0.5 * float(plat["length_m"]),
				"half_w": 0.5 * float(plat["width_m"]), "falloff": float(plat.get("falloff_m", 6.0))})
	_h_macro = _h.duplicate()
	for k in range(_h.size()):
		_h[k] += micro_field[k] * (1.0 - flat_w[k])


func _finish_stats() -> void:
	_prominence = 0.0
	if _lm_by_id.has("bateria"):
		var bat: Dictionary = _lm_by_id["bateria"]
		var centre := Vector2(305.0, 345.0)
		var dome := _first_layer("dome")
		if not dome.is_empty():
			centre = dome["center"]
		_prominence = height_at(float(bat["x"]), float(bat["z"])) - Relief.ring_mean(_h, nx, nz, cell_m, centre)
	var pts: Variant = (_map.get("relief", {}) as Dictionary).get("lamina_points", []) if _map.get("relief", null) is Dictionary else []
	var n := 0
	var ok := 0
	var worst := 0.0
	var failed: Array = []
	if pts is Array:
		for p in pts:
			if not (p is Dictionary):
				continue
			var g := lamina_to_game(float(p.get("E", 0.0)), float(p.get("N", 0.0)))
			var err := absf(height_dem_only(g.x, g.y) + datum_asl_m - float(p.get("est_m", 0.0)))
			n += 1
			worst = maxf(worst, err)
			if err <= LAMINA_OK_M:
				ok += 1
			else:
				failed.append(str(p.get("id", "?")))
	_lamina = {"n": n, "ok": ok, "max_err_m": snappedf(worst, 0.01), "failed": failed}
	_counts["gradiente_maximo_grados"] = snappedf(rad_to_deg(atan(_max_of(_grad))), 0.1)
	var solid_nodes := 0
	for idx in range(nx * nz):
		solid_nodes += _solid[idx]
	_counts["nodos_solidos"] = solid_nodes
	_counts["segmentos_opacos"] = _walls.size()
	_counts["edificios_opacos"] = _boxes.size()
	_counts["zanjas"] = _raw_features("zanja", "A").size()
	_counts["acequias"] = _raw_features("acequia", "A").size()


func _first_layer(kind: String) -> Dictionary:
	for l in _layers:
		if str(l["kind"]) == kind:
			return l
	return {}


static func _max_of(arr: PackedFloat32Array) -> float:
	var best := 0.0
	for v in arr:
		best = maxf(best, v)
	return best


# ---------------------------------------------------------------------------------------------------------------------
# Utilidades

func _in_world(x: float, z: float) -> bool:
	return x >= 0.0 and z >= 0.0 and x <= size_m.x and z <= size_m.y


func _node_index(x: float, z: float) -> int:
	return clampi(roundi(z / cell_m), 0, _jmax) * nx + clampi(roundi(x / cell_m), 0, _imax)


func _wet_of(sid: int, rain: float) -> float:
	return clampf(_wet_base[sid] + clampf(rain, 0.0, 1.0) * _wet_gain[sid], 0.0, 1.0)


func _speed_for(sid: int, rain: float) -> float:
	if str(VT.SURFACES[sid]) == "zanja":
		return _mud_by_sid[sid]  # la zanja frena igual con o sin lluvia
	return clampf(lerpf(1.0, _mud_by_sid[sid], _wet_of(sid, rain)), 0.0, 1.0)


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
		var best2 := INF
		for k in range(poly.size()):
			best2 = minf(best2, p.distance_to(Geometry2D.get_closest_point_to_segment(p, poly[k], poly[(k + 1) % poly.size()])))
		return best2
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
