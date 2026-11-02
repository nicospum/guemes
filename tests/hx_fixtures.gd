extends RefCounted
## Fixtures y utilidades compartidas por las pruebas del nivel «humahuaca» (CONTRATO 5.1 y 7). Dueño: compuertas y documentos.
## Sin class_name: se usa con `const Fx = preload("res://tests/hx_fixtures.gd")`. No depende de ningún archivo del nivel: lo que necesita
## de las capas lo carga en tiempo de ejecución (si falta o no parsea, la función devuelve null y la prueba lo informa; no se cae al compilar).
##
## Un solo archivo, tres usos:
##   1. Funciones estáticas sin estado: rondas, lectura de JSON, forma de las salidas (shape_diff), reflexión de scripts, perfil aislado.
##   2. Constructores de los stubs vecinos (terrain_stub, rules_stub, progress_stub, view_stub, ui_shell): así la prueba de una pista
##      no depende de que otra haya entregado. Cada stub lo escribe su dueño en R1.0; hasta entonces devuelven null.
##   3. Una INSTANCIA es el acumulador de una suite (`var s := Fx.new(); s.begin("hx_data", OS.get_cmdline_user_args())`): cuenta
##      comprobaciones, junta fallas y «pendientes» y, con finish(), imprime UNA línea JSON que lee tools/qa_gate.sh
##      ({suite, ronda, checks, failures, ok, pending, duration_ms}). Las pruebas de las pistas pueden usarla para dar la misma salida.

const ROUNDS := ["r0", "r1.0", "r1", "r2a", "r2b", "r3", "r4"]
const TRAZA_PATH := "res://docs/humahuaca/TRAZA.md"
const FORMA_DIR := "res://docs/humahuaca/forma/"
const FORMA_NAMES := ["hud_state", "render_state", "campaign_report", "plan_route", "qa_state"]
const LAYERS := ["terrain", "rules", "progress", "view", "ui"]
## Las capas que el controlador real arma con respaldo y se reemplazan con start(opts.force_stub) (los ids de vocab_ui.LAYER_IDS). La interfaz no está:
## se reemplaza instanciando la cáscara (stubs/stub_ui.gd) en lugar del controlador.
const SWAPPABLE := ["terrain", "rules", "progress", "view"]
const STUB_PATHS := {
	"terrain": "res://scripts/humahuaca/stubs/stub_terrain.gd",
	"rules": "res://scripts/humahuaca/stubs/stub_rules.gd",
	"progress": "res://scripts/humahuaca/stubs/stub_progress.gd",
	"view": "res://scripts/humahuaca/stubs/stub_view.gd",
	"ui": "res://scripts/humahuaca/stubs/stub_ui.gd"}
const REAL_PATHS := {
	"terrain": "res://scripts/humahuaca/terrain/humahuaca_terrain.gd",
	"rules": "res://scripts/humahuaca/rules/humahuaca_rules.gd",
	"progress": "res://scripts/humahuaca/rules/humahuaca_progress.gd",
	"view": "res://scripts/humahuaca/view/humahuaca_view.gd",
	"ui": "res://scripts/humahuaca/ui/humahuaca_ui.gd"}
const VOCAB_PATHS := {
	"humahuaca_vocab.gd": "res://scripts/humahuaca/humahuaca_vocab.gd",
	"vocab_terrain.gd": "res://scripts/humahuaca/terrain/vocab_terrain.gd",
	"vocab_rules.gd": "res://scripts/humahuaca/rules/vocab_rules.gd",
	"vocab_view.gd": "res://scripts/humahuaca/view/vocab_view.gd",
	"vocab_ui.gd": "res://scripts/humahuaca/ui/vocab_ui.gd"}
## Archivos de perfil que las pruebas borran al empezar (hermeticidad, igual que test_integration y ui_qa). SOLO con APPDATA aislado.
const PROFILE_FILES := ["campaign.json", "justina_progress.json", "humahuaca_progress.json", "humahuaca_checkpoint.json", "settings.cfg", "save_humahuaca.json", "save_justine.json", "save_norte.json"]

## Nombres que el contrato fija para cada capa (secciones 3.1 a 3.5). Los stubs y las clases reales deben tener TODOS (la firma
## completa la verifica cada dueño; acá solo se comprueba que el nombre exista, que es lo que rompe a las capas vecinas).
const API := {
	"terrain": {
		"methods": ["load_default", "lamina_to_game", "game_to_lamina", "height_at", "height_dem_only", "asl_at", "normal_at", "slope_deg_at",
			"surface_at", "wetness_at", "is_blocked", "speed_factor_at", "los", "elevation_advantage", "landmark", "landmarks", "features",
			"features_near", "river", "is_ford", "heightfield", "context_field", "nav_grid", "minimap_image", "report"],
		"props": ["size_m", "cell_m", "nx", "nz", "datum_asl_m", "anchor"], "signals": []},
	"rules": {
		"methods": ["new_game", "world_from_seed", "map_data", "terrain", "map_size", "terrain_height_at", "tick", "advance_to", "environment",
			"hud_state", "render_state", "units", "get_unit", "objectives", "objective", "loot_state", "list_actions", "action_info",
			"action_availability", "issue_order", "cancel_order", "undo_last", "plan_route", "plan_recon", "give_signal", "retreat_all",
			"pending_choice", "resolve_choice", "set_mercy", "apply_assist", "campaign_report", "epilogue", "signal_info", "route_atlas",
			"restore_snapshot", "snapshot", "save_game", "load_game", "validate_snapshot", "enemy_observation", "enemy_choices",
			"enemy_fallback", "record_external_decision"],
		"props": ["state"], "signals": []},
	"progress": {
		"methods": ["load_progress", "save_progress", "world_seed", "new_world", "begin_attempt", "record_result", "offered_assists",
			"apply_assists", "diary_entries", "diary_marks", "checkpoint_tick", "has_checkpoint", "checkpoint_time", "restore_checkpoint",
			"retry_options", "tutorial_pending", "mark_tutorial_seen", "reset_all", "recommended_by_profile"],
		"props": ["load_note", "attempts", "defeats_in_row", "best_medal", "won", "best_golpe"], "signals": []},
	"view": {
		"methods": ["build", "update_state", "ground_xz_from_screen", "pick_unit", "pick_units_in_rect", "pick_front", "pick_landmark",
			"get_landmark_info", "landmark_labels", "camera_bounds", "clamp_camera_target", "camera_frustum_on_ground", "meters_per_pixel",
			"world_to_map", "map_to_world", "get_minimap_texture", "set_selected_ids", "set_layer_visible", "layer_visible", "fx",
			"initial_frame", "canonical_view", "set_time_override", "set_albedo_mode", "probes"],
		"props": ["selected_ids", "unit_nodes", "unit_labels"], "signals": ["minimap_changed"]},
	"ui": {
		"methods": ["start", "stop", "qa_state", "qa_set_camera", "qa_set_time", "qa_run", "qa_step", "benchmark_prepare"],
		"props": [], "signals": ["exited"]}}

## Contenido inicial de los cinco vocabularios (CONTRATO 3.0, copiado literal en T0). Cada vocabulario es SOLO-AGREGAR: sumar ids no pide addendum;
## quitar o renombrar uno, sí. test_hx_data::_test_v13_vocab_add_only exige que todo lo de acá siga en el archivo de su dueño.
const VOCAB_MIN := {
	"humahuaca_vocab.gd": {
		"CHECKPOINT_PATH": "user://humahuaca_checkpoint.json",
		"COMBAT_GROUPS": ["rodriguez", "portal", "arias"],
		"CONTRACT": 1,
		"EXITS": ["menu", "norte"],
		"GROUPS": ["rodriguez", "portal", "arias", "reconocedores", "arreo"],
		"HEIGHT_PATH": "res://data/humahuaca_height.json",
		"LEVEL_PATH": "res://data/humahuaca_level.json",
		"MAP_PATH": "res://data/humahuaca_map.json",
		"OBJECTIVES": ["bateria", "cuartel", "posta"],
		"PROGRESS_PATH": "user://humahuaca_progress.json",
		"RULES_PATH": "res://data/humahuaca_rules.json",
		"SCENARIO": "humahuaca",
		"TAGS": ["documentado", "razonado", "discutido", "sin_datos", "diseno"],
		"UI_PATH": "res://data/humahuaca_ui.json",
		"VISUAL_PATH": "res://data/humahuaca_visual.json"
	},
	"vocab_rules.gd": {
		"ACTIONS": {
			"global": ["give_signal", "retreat_all"],
			"group": ["move", "position", "attack", "support", "hold", "secure_horses", "breach", "retreat", "cancel"],
			"scout": ["recon", "decoy", "watch", "cancel"],
			"train": ["bring", "load", "destroy", "hide", "leave", "drop", "cancel"]
		},
		"ACTIONS_R1": ["move", "position", "give_signal", "attack", "support", "recon", "load", "destroy", "leave", "hold", "cancel"],
		"ACTIVE_DIMS": ["guardia", "torre_en", "refuerzo"],
		"APPROACHES": {"bateria": ["frontal", "gola", "distraccion"], "cuartel": ["calle", "patios", "piezas"], "posta": ["directa", "distraccion"]},
		"CAUSES": ["amanecio", "descubiertos", "frente_roto", "sin_carga", "interceptados", "dispersos", "plazo", "retirada"],
		"EVENT_KINDS": ["objective", "briefing", "weather", "dawn", "noise", "detected", "alarm", "signal", "shot", "melee", "capture", "tower", "support",
			"horses", "recon", "decoy", "messenger", "reinforcement_warning", "reinforcement", "loot", "load", "destroy", "hide", "exit", "decision", "hint",
			"assist", "enemy_choice", "checkpoint", "victory", "defeat", "info", "warning"],
		"EXTRACTIONS": ["cargar_todo", "destruir_todo", "ocultar", "ligera", "mixta"],
		"FRONT_STATES": ["guardado", "alertado", "en_alarma", "asaltado", "tomado"],
		"LOOT_KINDS": ["polvora", "canones", "fusiles", "viveres", "ganado", "plata", "prisioneros", "bandera", "ornamentos"],
		"LOOT_KINDS_R1": ["polvora", "canones", "fusiles", "viveres", "plata"],
		"LOOT_STATES": ["en_sitio", "cargado", "destruido", "oculto", "abandonado", "entregado"],
		"MEDALS": ["", "bronce", "plata", "oro"],
		"PACES": ["sneak", "march", "run", "trot", "gallop"],
		"PHASES": ["briefing", "aproximacion", "ataque", "extraccion", "epilogo"],
		"RETRY": ["posiciones", "salida", "mismo_mundo", "mundo_nuevo"],
		"STAGES": ["idle", "moving", "waiting_signal", "attacking", "holding", "loading", "retreating", "routed", "dismounting", "scouting", "exited"],
		"STATUS": ["playing", "victory", "defeat"],
		"TREATMENTS": ["entregar", "destruir", "ocultar", "abandonar"],
		"VARIANTS": {
			"guardia": ["descuidada", "atenta"],
			"layout": ["A", "B"],
			"lluvia": ["copiosa", "garua"],
			"refuerzo": ["temprano", "normal", "tardio"],
			"refugio": ["norte", "sur"],
			"torre_en": ["templo", "casa_cura"]
		},
		"WORLD_TRAITS": {"corral": ["completo", "desbandado"], "plata": [true, false], "polvora": ["seca", "humeda"]}
	},
	"vocab_terrain.gd": {
		"FEATURE_KINDS": ["tapia", "zanja", "acequia", "barricada", "portillo", "calle", "manzana", "patio", "parcela", "camino", "camino_cubierto"],
		"LANDMARK_TYPES": ["hito", "objetivo", "edificio", "torre", "refugio", "acceso", "salida", "entrada", "partida", "plaza", "cerro"],
		"LAYER_KINDS": ["dome", "platform", "pad", "step", "bank", "gully", "ditch", "carve"],
		"SURFACES": ["suelo_seco", "sedimento_humedo", "piedra", "churqui", "irrigado", "agua", "camino", "patio", "zanja", "muro"]
	},
	"vocab_ui.gd": {
		"TOAST_LEVELS": ["info", "aviso", "critica"],
		"TUTORIAL_STEPS": ["reconocer", "puestos", "senal", "tres_a_la_vez", "cargar", "salir"]
	},
	"vocab_view.gd": {
		"FX_KINDS": ["fogonazo", "humo", "impacto", "captura", "pisadas", "explosion", "senal"],
		"LAYERS": ["paths", "visibility", "exposure", "labels", "landmarks", "diary", "enemy", "lights"],
		"QUALITY": ["baja", "media", "alta"],
		"VIEW_IDS": ["acceso_so", "desde_bateria", "patio_posta", "panorama_alto", "grupos_en_accion", "juego_noche", "juego_alba"]
	}
}

# ---------------------------------------------------------------------------------------------------------------------
# Rondas

static func round_index(round_id: String) -> int:
	return ROUNDS.find(round_id)

## ¿La ronda `current` ya llegó a la ronda `due`? Una ronda de vencimiento desconocida se EXIGE (falla antes que ocultar).
static func round_ge(current: String, due: String) -> bool:
	var due_i := ROUNDS.find(due)
	if due_i < 0:
		return true
	return maxi(ROUNDS.find(current), 0) >= due_i

## La ronda vigente: `--ronda=<id>` en los argumentos de la prueba, o la línea «Ronda vigente: rX» de docs/humahuaca/TRAZA.md, o r0.
static func current_round(args: Array = []) -> String:
	for arg in args:
		if str(arg).begins_with("--ronda="):
			return str(arg).trim_prefix("--ronda=")
	if FileAccess.file_exists(TRAZA_PATH):
		var rx := RegEx.new()
		rx.compile("(?m)^Ronda vigente:\\s*(r[0-9a-z.]+)")
		var found := rx.search(FileAccess.get_file_as_string(TRAZA_PATH))
		if found != null:
			return found.get_string(1)
	return "r0"

# ---------------------------------------------------------------------------------------------------------------------
# Archivos y JSON

static func read_text(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""

## {ok, data, error}: error trae la línea y el motivo del parser de Godot.
static func parse_json_text(text: String) -> Dictionary:
	var parser := JSON.new()
	var err := parser.parse(text)
	if err != OK:
		return {"ok": false, "data": null, "error": "línea %d: %s" % [parser.get_error_line(), parser.get_error_message()]}
	return {"ok": true, "data": parser.data, "error": ""}

## El JSON ya parseado, o null si el archivo falta o no parsea.
static func read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var parsed := parse_json_text(FileAccess.get_file_as_string(path))
	return parsed.data if parsed.ok else null

## Hash canónico de un subárbol de JSON (claves ordenadas, precisión completa): es el «byte a byte» de V17.
static func canon_hash(value: Variant) -> String:
	return JSON.stringify(value, "", true, true).sha256_text()

## Rutas de los archivos con la extensión pedida bajo `dir` (recursivo), ordenadas.
static func list_files(dir: String, ext: String) -> Array:
	var found: Array = []
	var da := DirAccess.open(dir)
	if da == null:
		return found
	for sub in da.get_directories():
		found.append_array(list_files(dir.path_join(sub), ext))
	for f in da.get_files():
		if f.ends_with("." + ext):
			found.append(dir.path_join(f))
	found.sort()
	return found

# ---------------------------------------------------------------------------------------------------------------------
# Forma de las salidas (CONTRATO 3.6)

static func kind_of(v: Variant) -> String:
	match typeof(v):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "bool"
		TYPE_INT, TYPE_FLOAT:
			return "number"
		TYPE_STRING, TYPE_STRING_NAME:
			return "string"
		TYPE_DICTIONARY:
			return "dict"
		TYPE_ARRAY, TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY:
			return "array"
	return "otro(" + type_string(typeof(v)) + ")"

## Compara la forma de `actual` con la del ejemplo: al menos TODAS las claves del ejemplo, con el mismo tipo (número/texto/bool/objeto/arreglo);
## los arreglos se comparan por su primer elemento (un arreglo vacío no se compara). `optional` lista rutas («torre», «lights[].objective»)
## que pueden faltar o venir vacías ({} o []). Las claves del ejemplo que empiezan con «_» son metadatos y se ignoran.
## Devuelve las diferencias en español (vacío = misma forma).
static func shape_diff(example: Variant, actual: Variant, optional: Array = [], path: String = "") -> Array:
	var diffs: Array = []
	var ek := kind_of(example)
	var ak := kind_of(actual)
	var shown := path if path != "" else "(raíz)"
	if ek == "null":
		return diffs
	if optional.has(path) and (ak == "null" or ((ak == "dict" or ak == "array") and actual.size() == 0)):
		return diffs
	if ak != ek:
		diffs.append("tipo de `%s`: el ejemplo es %s y la salida es %s" % [shown, ek, ak])
		return diffs
	if ek == "dict":
		for key in example:
			if str(key).begins_with("_"):
				continue
			var sub: String = str(key) if path == "" else path + "." + str(key)
			if not actual.has(key):
				if not optional.has(sub):
					diffs.append("falta `%s`" % sub)
				continue
			diffs.append_array(shape_diff(example[key], actual[key], optional, sub))
	elif ek == "array":
		if example.size() > 0 and actual.size() > 0:
			diffs.append_array(shape_diff(example[0], actual[0], optional, path + "[]"))
	return diffs

## El ejemplo de forma `name` (sin la clave «_forma») y sus rutas opcionales: {example, optional, meta}; {} si falta o no parsea.
static func load_forma(forma_name: String) -> Dictionary:
	var data: Variant = read_json(FORMA_DIR + forma_name + ".json")
	if not (data is Dictionary):
		return {}
	var meta: Dictionary = data.get("_forma", {})
	var example: Dictionary = (data as Dictionary).duplicate(true)
	example.erase("_forma")
	return {"example": example, "optional": meta.get("opcionales", []), "meta": meta}

# ---------------------------------------------------------------------------------------------------------------------
# Reflexión de scripts y stubs vecinos

## El script cargado, o null si falta, no parsea o no se puede instanciar.
static func load_script(path: String) -> Script:
	if not ResourceLoader.exists(path):
		return null
	var res: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
	if res == null or not (res is Script):
		return null
	var script: Script = res
	return script if script.can_instantiate() else null

static func script_method_names(script: Script) -> Array:
	var names: Array = []
	for m in script.get_script_method_list():
		names.append(str(m.name))
	return names

static func script_prop_names(script: Script) -> Array:
	var names: Array = []
	for p in script.get_script_property_list():
		names.append(str(p.name))
	return names

static func script_signal_names(script: Script) -> Array:
	var names: Array = []
	for s in script.get_script_signal_list():
		names.append(str(s.name))
	return names

## Lo que le falta a `script` respecto del contrato de la capa (`layer` ∈ LAYERS): lista de «método x», «propiedad y», «señal z».
static func api_missing(script: Script, layer: String) -> Array:
	var missing: Array = []
	var spec: Dictionary = API.get(layer, {})
	var methods := script_method_names(script)
	var props := script_prop_names(script)
	var signals_ := script_signal_names(script)
	for m in spec.get("methods", []):
		if not methods.has(m):
			missing.append("método " + str(m))
	for p in spec.get("props", []):
		if not props.has(p):
			missing.append("propiedad " + str(p))
	for s in spec.get("signals", []):
		if not signals_.has(s):
			missing.append("señal " + str(s))
	return missing

## ¿Existe el stub de esa capa (lo escribe su dueño en R1.0; la cáscara de la interfaz existe desde T0)?
static func has_stub(layer: String) -> bool:
	return load_script(STUB_PATHS.get(layer, "")) != null

static func terrain_stub() -> RefCounted:
	var script := load_script(STUB_PATHS.terrain)
	if script == null:
		return null
	if script_method_names(script).has("load_default"):
		return script.call("load_default")
	return script.new()

static func rules_stub(seed_value: int = 1817, attempt: int = 1, opts: Dictionary = {}) -> RefCounted:
	var script := load_script(STUB_PATHS.rules)
	if script == null:
		return null
	var rules: RefCounted = script.new()
	rules.call("new_game", seed_value, attempt, opts)
	return rules

static func progress_stub(path: String = "user://hx_fx_progress.json", checkpoint_path: String = "user://hx_fx_checkpoint.json") -> RefCounted:
	var script := load_script(STUB_PATHS.progress)
	return script.new(path, checkpoint_path) if script != null else null

static func view_stub(rules: RefCounted, quality: String = "media") -> Node3D:
	var script := load_script(STUB_PATHS.view)
	if script == null:
		return null
	var view: Node3D = script.new()
	view.call("build", rules, quality)
	return view

## La cáscara del controlador (stubs/stub_ui.gd, escrita por el integrador en T0): existe siempre.
static func ui_shell() -> Node:
	var script := load_script(STUB_PATHS.ui)
	return script.new() if script != null else null

## Compara las capas efectivas de una corrida con UNA capa forzada contra las de una corrida sin forzar nada. Las dos son {id de capa: "real" | "minimo" |
## "falta"} (la clave `layers` de qa_state() del controlador). La capa forzada tiene que correr en su versión mínima y ninguna otra puede haber cambiado.
## Devuelve los problemas en español (vacío = bien). Sin ninguna clase real, la corrida normal ya es toda «minimo» y forzar una capa no cambia nada:
## eso no es un problema de esta comparación, lo informa test_hx_smoke en `degradadas`.
static func forced_layer_problems(baseline: Dictionary, observed: Dictionary, forced: String) -> Array:
	var problems: Array = []
	var got := str(observed.get(forced, "(sin dato)"))
	if got != "minimo":
		problems.append("la capa forzada «%s» corre como «%s» y no como «minimo»" % [forced, got])
	for id in baseline:
		var now := str(observed.get(id, "(sin dato)"))
		if str(id) != forced and now != str(baseline[id]):
			problems.append("la capa «%s» cambió sin que se la forzara: era «%s» y ahora es «%s»" % [str(id), str(baseline[id]), now])
	return problems

## ¿Difieren dos mapas de capas efectivas? (no importa el orden de las claves)
static func layers_differ(a: Dictionary, b: Dictionary) -> bool:
	for id in a:
		if str(a[id]) != str(b.get(id, "(sin dato)")):
			return true
	for id in b:
		if not a.has(id):
			return true
	return false

# ---------------------------------------------------------------------------------------------------------------------
# Perfil aislado

## Las pruebas que borran archivos de perfil exigen APPDATA aislado (export APPDATA="$TEMP/ap_iso_<pista>"): con el perfil real
## borrarían el campaign.json del usuario. El nombre canónico lleva «ap_iso».
static func profile_isolated() -> bool:
	return OS.get_user_data_dir().to_lower().find("ap_iso") >= 0

static func clean_profile(names: Array = PROFILE_FILES) -> void:
	for profile_file in names:
		var path := "user://" + str(profile_file)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

# ---------------------------------------------------------------------------------------------------------------------
# Acumulador de suite (instancia)

var suite_name := ""
var round_id := "r0"
var checks := 0
var failures: Array = []
var pending: Array = []
var extra: Dictionary = {}
var _started_ms := 0

func begin(name_: String, args: Array = []) -> void:
	suite_name = name_
	round_id = current_round(args)
	checks = 0
	failures = []
	pending = []
	extra = {}
	_started_ms = Time.get_ticks_msec()

func check(condition: bool, description: String) -> bool:
	checks += 1
	if not condition:
		failures.append(description)
		push_error("FALLA: " + description)
	return condition

## Algo que todavía no se puede evaluar. Antes de la ronda `due` queda en `pending` (se informa); desde `due` es una falla:
## «no evaluable = falla» (QA_NIVEL2.md, sección 2).
func pend(id: String, reason: String, due: String) -> void:
	if round_ge(round_id, due):
		check(false, "NO EVALUABLE (exigido desde %s): %s [%s]" % [due, reason, id])
	else:
		pending.append({"id": id, "reason": reason, "due": due})

## Piso anti-desactivación (CONTRATO 5.1): cuenta también esta comprobación.
func require_floor(minimum: int) -> void:
	check(checks + 1 >= minimum, "piso de comprobaciones de %s en %s: %d (mínimo %d)" % [suite_name, round_id, checks + 1, minimum])

func elapsed_ms() -> int:
	return Time.get_ticks_msec() - _started_ms

func report() -> Dictionary:
	var out := {"suite": suite_name, "ronda": round_id, "checks": checks, "failures": failures, "ok": failures.is_empty(), "pending": pending, "duration_ms": elapsed_ms()}
	out.merge(extra)
	return out

## Imprime la línea final (una sola línea JSON que empieza con «{») y sale con 0 si no hubo fallas.
func finish(tree: SceneTree) -> void:
	print(JSON.stringify(report()))
	tree.quit(0 if failures.is_empty() else 1)
