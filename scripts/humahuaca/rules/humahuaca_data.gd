extends RefCounted
## Datos y textos de la capa de reglas del nivel «humahuaca» (CONTRATO 2.3 y 3.2). Dueña: reglas_historia.
## Un solo lugar donde se leen los tres JSON de reglas (mapa, diseño de nivel y reglas), se arman los textos con sus marcas ({t}, {lugar}…) y se nombran
## los lugares del mapa. Sin estado de partida: todo es estático y de solo lectura. Cada número del juego sale de data/humahuaca_rules.json; los hitos,
## de data/humahuaca_map.json (el registro de coordenadas); los rasgos y los puestos de ataque, de data/humahuaca_level.json.
## Independencia (V19): solo importa el vocabulario compartido.

const V = preload("res://scripts/humahuaca/humahuaca_vocab.gd")

## Coordenadas de respaldo, solo para cuando el mapa todavía no trae el hito (DISENO 3 y 5.1). La fuente es humahuaca_map.json (landmarks).
const FALLBACK_HITOS := {
	"templo": Vector2(450, 325), "bateria": Vector2(318, 350), "cuartel": Vector2(418, 335), "posta": Vector2(590, 300),
	"torre_casa_cura": Vector2(426, 326), "torre_templo": Vector2(466, 322), "plaza": Vector2(450, 392), "polvorin": Vector2(601, 292),
	"parque": Vector2(583, 304), "corral_posta": Vector2(618, 302), "quebradita_norte": Vector2(282, 298), "quebradita_sur": Vector2(288, 402),
	"vado_este": Vector2(862, 340), "salida_este": Vector2(895, 332), "entrada_sur": Vector2(540, 650), "zona_partida": Vector2(160, 550),
	"spawn_rodriguez": Vector2(70, 470), "spawn_portal": Vector2(110, 580), "spawn_arias": Vector2(260, 625),
	"spawn_reconocedores": Vector2(230, 480), "spawn_arreo": Vector2(60, 625)}

static var _cache: Dictionary = {}
static var _hitos: Dictionary = {}
static var _merged: Dictionary = {}

## Un JSON de datos del nivel con caché por proceso ({} si falta; load_json ya avisa con push_error).
static func json(path: String) -> Dictionary:
	if not _cache.has(path):
		_cache[path] = V.load_json(path)
	return _cache[path]

static func rules() -> Dictionary:
	return json(V.RULES_PATH)

static func level() -> Dictionary:
	return json(V.LEVEL_PATH)

static func map() -> Dictionary:
	return json(V.MAP_PATH)

## Mapa, diseño de nivel y reglas fusionados (solo lectura; la primera clave de cada archivo gana, V3 garantiza que no se repiten). {} si falta alguno.
static func merged() -> Dictionary:
	if _merged.is_empty():
		var r := rules()
		var l := level()
		if r.is_empty() or l.is_empty():
			return {}
		for src in [map(), l, r]:
			for k in src:
				if not _merged.has(k):
					_merged[k] = src[k]
	return _merged

## Olvida lo leído (las pruebas que cambian un JSON en memoria lo usan).
static func reset_cache() -> void:
	_cache = {}
	_hitos = {}
	_merged = {}

# ---------------------------------------------------------------------------------------------------------------------
# Hitos y lugares

## El hito del mapa (o su respaldo) como Vector2(x, z).
static func hito(id: String) -> Vector2:
	if _hitos.is_empty():
		for lm in map().get("landmarks", []):
			if lm is Dictionary and lm.has("id") and lm.has("x") and lm.has("z"):
				_hitos[str(lm.id)] = Vector2(float(lm.x), float(lm.z))
	if _hitos.has(id):
		return _hitos[id]
	return FALLBACK_HITOS.get(id, Vector2(450.0, 325.0))

static func map_size() -> Vector2:
	var sz: Dictionary = map().get("size_m", {})
	return Vector2(float(sz.get("x", 900.0)), float(sz.get("z", 650.0)))

## El lugar del mapa más cercano a `p`, dicho en palabras («la batería», «el vado»); «el campo» si no hay ninguno a menos de lugares.radio_m.
## `tx_lugares` sale de rules.texts.lugares: {radio_m, campo, hitos: {id de hito: frase}}.
static func place_of(p: Vector2) -> String:
	var cfg: Dictionary = rules().get("texts", {}).get("lugares", {})
	var best := str(cfg.get("campo", "el campo"))
	var best_d := float(cfg.get("radio_m", 140.0))
	var hitos: Dictionary = cfg.get("hitos", {})
	for id in hitos:
		var d := p.distance_to(hito(str(id)))
		if d < best_d:
			best_d = d
			best = str(hitos[id])
	return best

## «de la batería» / «del cuartel»: el lugar con su preposición contraída.
static func de_place(place: String) -> String:
	if place.begins_with("el "):
		return "del " + place.substr(3)
	return "de " + place

# ---------------------------------------------------------------------------------------------------------------------
# Textos

static func fmt(template: String, vars: Dictionary) -> String:
	var out := template
	for k in vars:
		out = out.replace("{" + str(k) + "}", str(vars[k]))
	return out

## Un texto de rules.texts por ruta con puntos («errores.rango»); "" si no existe.
static func tx(path: String) -> Variant:
	var cur: Variant = rules().get("texts", {})
	for part in path.split("."):
		if cur is Dictionary and (cur as Dictionary).has(part):
			cur = cur[part]
		else:
			return ""
	return cur

static func ts(path: String, vars: Dictionary = {}) -> String:
	return fmt(str(tx(path)), vars)

## Segundos como m:ss («6:30»).
static func clock(seconds: float) -> String:
	var s := maxi(0, int(floor(seconds)))
	return "%d:%02d" % [floori(float(s) / 60.0), s % 60]

static func pt(x: float, z: float) -> Dictionary:
	return {"x": x, "z": z}

static func dist(ax: float, az: float, bx: float, bz: float) -> float:
	return sqrt((ax - bx) * (ax - bx) + (az - bz) * (az - bz))
