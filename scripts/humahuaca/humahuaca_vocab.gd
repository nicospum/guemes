extends RefCounted
## Vocabulario compartido del nivel «humahuaca» (contrato 3.0). Lo escribe el integrador y casi no cambia: solo lo que
## cruza TODAS las capas. Cada capa importa estas listas en vez de repetir cadenas (const V = preload("res://scripts/humahuaca/humahuaca_vocab.gd")).
## Es solo-agregar: sumar un id no necesita addendum; quitar o renombrar uno, sí (docs/humahuaca/ADDENDA.md).
## Los vocabularios propios de cada capa viven en terrain/vocab_terrain.gd, rules/vocab_rules.gd, view/vocab_view.gd y ui/vocab_ui.gd.

const SCENARIO := "humahuaca"  # nunca se pasa a GameRules (convertiría cualquier nombre desconocido en "justine")
const CONTRACT := 1
const MAP_PATH := "res://data/humahuaca_map.json"
const HEIGHT_PATH := "res://data/humahuaca_height.json"
const LEVEL_PATH := "res://data/humahuaca_level.json"
const RULES_PATH := "res://data/humahuaca_rules.json"
const VISUAL_PATH := "res://data/humahuaca_visual.json"
const UI_PATH := "res://data/humahuaca_ui.json"
const PROGRESS_PATH := "user://humahuaca_progress.json"
const CHECKPOINT_PATH := "user://humahuaca_checkpoint.json"
const GROUPS := ["rodriguez", "portal", "arias", "reconocedores", "arreo"]  # teclas 1..5
const COMBAT_GROUPS := ["rodriguez", "portal", "arias"]
const OBJECTIVES := ["bateria", "cuartel", "posta"]
const TAGS := ["documentado", "razonado", "discutido", "sin_datos", "diseno"]  # de más fuerte a más débil
const EXITS := ["menu", "norte"]


## Lee un JSON de datos del nivel. Devuelve {} (con push_error) si el archivo falta, no es un objeto o no declara "contract": 1.
static func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Humahuaca: falta el archivo de datos " + path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		push_error("Humahuaca: " + path + " no se pudo leer como un objeto JSON")
		return {}
	if int(parsed.get("contract", 0)) != CONTRACT:
		push_error("Humahuaca: " + path + " no declara \"contract\": " + str(CONTRACT))
		return {}
	return parsed


## La etiqueta más débil de la lista (la fuerza de evidencia sigue el orden de TAGS). Devuelve "" si no hay ninguna etiqueta válida.
static func tag_min(tags: Array) -> String:
	var weakest := -1
	for tag in tags:
		weakest = maxi(weakest, TAGS.find(str(tag)))
	return TAGS[weakest] if weakest >= 0 else ""
