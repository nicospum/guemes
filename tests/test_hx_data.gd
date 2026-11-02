extends "res://tests/hx_validators.gd"

## Pruebas de datos y documentos del nivel «humahuaca» (CONTRATO 2.4: reglas V1 a V22, encendidas por ronda). Dueño: compuertas y documentos.
## Sin ventana ni escritura: godot --headless --path . --script tests/test_hx_data.gd [-- --ronda=r1]
##
## Ronda: `--ronda=<id>` o la línea «Ronda vigente: rX» de docs/humahuaca/TRAZA.md (tools/qa_gate.sh pasa el mismo valor).
## Encendidas en R0: V1, V2, V3, V4, V5, V7, V8, V9, V17, V19 y V20, más guardas de documentos (vocabularios solo-agregar, ejemplos de forma,
## ganchos de herramientas y reglas de Git). En R1.0 todavía NO corrían (el informe las lista en `reglas_pendientes`); desde `r1` corren V6, V10 a V16, V18, V21 y V22 sobre los datos de las
## cuatro pistas (BACKLOG B-013) y `reglas_pendientes` queda vacío.
##
## Cada regla es un validador puro que devuelve la lista de violaciones. Cada validador se prueba contra los datos reales Y contra copias rotas a
## propósito (`_test_self_mutations`): si no ve el error plantado, el test falla. Un validador que nunca falla no protege nada.
## Piso anti-desactivación (CONTRATO 5.1): 40 comprobaciones en R0 y R1, 60 desde R2a. Tiempo objetivo: < 5 s (falla a los 15 s).
const HISTORY_PATH := "res://data/history.json"
const CONTRACT_PATH := "res://docs/CONTRATO_HUMAHUACA.md"
const QA_PATH := "res://docs/QA_NIVEL2.md"
## Excepciones fechadas de V11 (ADDENDA A-13): una pista de reintento de 123 caracteres (el tope es 120) que entregó reglas_historia en R1. Vence en r2a: desde esa ronda la
## pista vuelve a fallar si sigue igual. Cada excepción es una ruta y la ronda en que deja de valer; ninguna sirve para relajar un tope en silencio.
const V11_ACCEPTED := {"campaign.tips.dispersos[0]": "r2a"}
const FLOOR_BY_ROUND := {"r0": 40, "r1.0": 40, "r1": 40, "r2a": 60, "r2b": 60, "r3": 60, "r4": 60}

const REPORT_PENDING_RULES := {
	"V6": "geometría de hitos y rasgos dentro de [0,900]×[0,650] (r1.0)", "V10": "jerga en cadenas visibles (r1.0)", "V11": "límites de texto (r1.0)",
	"V12": "res:// citado por los JSON existe (r1.0)", "V13": "vocabulario contra rules.groups/objectives/actions/loot/variants (r1.0; el solo-agregar ya corre)",
	"V14": "variantes legales (r1)", "V15": "7 vistas canónicas con must_show (r1.0)", "V16": "reloj ordenado y botín que suma 100 (r1.0)",
	"V18": "créditos del relieve (r1)", "V21": "una sola fuente por número de juego (r1)", "V22": "vistas canónicas coherentes con la cámara (r1)"}

var suite := Fx.new()

var round_id := "r0"

var pista := ""  # vacío = todas las pistas

var parsed_files: Dictionary = {}

var parse_errors: Dictionary = {}

var raw_bytes: Dictionary = {}

func _initialize() -> void:
	suite.begin("hx_data", OS.get_cmdline_user_args())
	round_id = suite.round_id
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--pista="):
			pista = str(arg).trim_prefix("--pista=")
	suite.extra["pista"] = pista
	_load_all()
	_test_round_helpers()
	_test_v1_files_and_identity()
	_test_v2_required_keys()
	_test_v3_key_ownership()
	_test_v4_tags()
	_test_v5_ids_and_refs()
	_test_v7_height_grid()
	_test_v8_sizes()
	_test_v9_palette()
	_test_r1_rules()
	_test_v13_vocab_add_only()
	_test_v13_rules_vs_vocab()
	_test_v17_history()
	_test_v19_dependency_graph()
	_test_v20_traceability()
	_test_forma_examples()
	_test_tooling_hooks()
	_test_self_mutations()
	suite.extra["reglas_activas"] = ["V1", "V2", "V3", "V4", "V5", "V7", "V8", "V9", "V13 (solo-agregar)", "V17", "V19", "V20"]
	if _r1_rules_on():
		suite.extra["reglas_activas"] += ["V6", "V10", "V11", "V12", "V13 (completa)", "V14", "V15", "V16", "V18", "V21", "V22"]
		suite.extra["reglas_pendientes"] = {}
	else:
		suite.extra["reglas_pendientes"] = REPORT_PENDING_RULES
	## El objetivo del contrato es < 5 s (suele tardar 0,5 s). Falla recién a los 15 s: con cuatro pistas corriendo su compuerta a la vez la PC va más lenta.
	suite.check(suite.elapsed_ms() < 15000, "test_hx_data corre en poco tiempo (objetivo < 5 s, CONTRATO 5.1; falla a los 15 s): %d ms" % suite.elapsed_ms())
	suite.require_floor(int(FLOOR_BY_ROUND.get(round_id, 40)))
	suite.finish(self)

# ---------------------------------------------------------------------------------------------------------------------
# Carga

func _load_all() -> void:
	for key in FILES:
		var path: String = FILES[key]
		if not FileAccess.file_exists(path):
			raw_bytes[key] = PackedByteArray()
			parsed_files[key] = null
			parse_errors[key] = "el archivo no existe"
			continue
		raw_bytes[key] = FileAccess.get_file_as_bytes(path)
		var parsed := Fx.parse_json_text(raw_bytes[key].get_string_from_utf8())
		parsed_files[key] = parsed.data if parsed.ok else null
		parse_errors[key] = parsed.error

func _files_copy() -> Dictionary:
	return parsed_files.duplicate(true)

func _test_round_helpers() -> void:
	suite.check(Fx.ROUNDS.has(round_id), "la ronda vigente «%s» es una de %s" % [round_id, str(Fx.ROUNDS)])
	suite.check(Fx.round_ge("r1", "r0") and Fx.round_ge("r1", "r1") and not Fx.round_ge("r0", "r1.0") and Fx.round_ge("r2a", "r1.0"), "round_ge ordena las rondas")
	suite.check(Fx.round_ge("r0", "ronda_inexistente"), "una ronda de vencimiento desconocida se exige (falla antes que ocultar)")

func _test_v1_files_and_identity() -> void:
	var v := v1_identity(parsed_files, parse_errors)
	for key in FILES:
		var own := v.filter(func(m): return String(m).begins_with("V1 " + FILES[key] + ":"))
		suite.check(own.is_empty(), "V1 %s parsea, declara contract 1 y su map_version coincide%s" % [FILES[key], "" if own.is_empty() else ": " + str(own[0])])
	var general := v.filter(func(m): return not String(m).begins_with("V1 res://data/"))
	suite.check(general.is_empty(), "V1 sin errores generales de identidad%s" % ("" if general.is_empty() else ": " + str(general[0])))
	for key in FILES:
		var fmt := v1_format(FILES[key], raw_bytes[key], parsed_files[key])
		suite.check(fmt.is_empty(), "V1 formato de %s (UTF-8 sin BOM, LF, sin comas finales, sin NaN)%s" % [FILES[key], "" if fmt.is_empty() else ": " + str(fmt[0])])

func _test_v2_required_keys() -> void:
	var active := 0
	for req in REQ:
		if not _required_now(req, round_id, pista):
			continue
		active += 1
		var one := v2_required({req[0]: parsed_files[req[0]]}, round_id, pista).filter(func(m): return String(m).find("«%s»" % req[1]) >= 0)
		suite.check(one.is_empty(), "V2 %s.%s (%s) presente%s" % [req[0], req[1], req[2], "" if one.is_empty() else ": " + str(one[0])])
	suite.extra["v2_claves_exigidas"] = active

func _test_v3_key_ownership() -> void:
	var result := v3_ownership(parsed_files)
	for key in FILES:
		var own: Array = (result.violations as Array).filter(func(m): return String(m).begins_with("V3 " + FILES[key] + ":"))
		suite.check(own.is_empty(), "V3 %s solo tiene claves de su dueño%s" % [FILES[key], "" if own.is_empty() else ": " + str(own[0])])
	suite.extra["v3_claves_sin_dueno_conocido"] = result.unknown

func _test_v4_tags() -> void:
	var v := v4_tags(parsed_files)
	for key in FILES:
		var own := v.filter(func(m): return String(m).begins_with("V4 " + FILES[key]))
		suite.check(own.is_empty(), "V4 etiquetas de %s (tag válido, tag_parts coherente, source ≤ 120)%s" % [FILES[key], "" if own.is_empty() else ": " + str(own[0])])
	var anchor: Dictionary = (parsed_files.map.get("anchor", {}) if parsed_files.map is Dictionary else {})
	suite.check(str(anchor.get("tag", "")) == "razonado", "V4 el ancla del templo es «razonado» (el sitio es inferencia, no dato)")
	var meta: Dictionary = (parsed_files.height.get("meta", {}) if parsed_files.height is Dictionary else {})
	suite.check(TAGS.has(str(meta.get("tag", ""))), "V4 el relieve declara su etiqueta (height.meta.tag = «%s»)" % str(meta.get("tag", "")))

func _test_v5_ids_and_refs() -> void:
	var v := v5_ids_and_refs(parsed_files, round_id, not (round_id == "r1.0" and pista != ""))
	suite.check(v.is_empty(), "V5 ids únicos por arreglo y referencias que resuelven (%d violaciones)%s" % [v.size(), "" if v.is_empty() else ": " + str(v[0])])
	var lm_ids := _landmark_ids(parsed_files)
	suite.extra["v5_hitos"] = lm_ids.size()
	if _required_now(["map", "landmarks", "array", "r1.0"], round_id, pista):
		suite.check(lm_ids.size() >= 21, "V5 el mapa trae los 21 hitos obligatorios (hay %d)" % lm_ids.size())

func _test_v7_height_grid() -> void:
	var v := v7_grid(parsed_files.height, parsed_files.map)
	suite.check(v.is_empty(), "V7 grilla de relieve íntegra (tamaños, decímetros enteros, rango, bordes ventana-contexto, fuente)%s" % ("" if v.is_empty() else ": " + str(v[0])))
	if parsed_files.height is Dictionary:
		var win: Dictionary = parsed_files.height.get("window", {})
		var ctx: Dictionary = parsed_files.height.get("context", {})
		suite.check(int(win.get("nx", 0)) == 91 and int(win.get("nz", 0)) == 66 and (win.get("h", []) as Array).size() == 6006, "V7 la ventana son 91 × 66 = 6 006 nodos de 10 m (900 × 650 m)")
		suite.check(int(ctx.get("nx", 0)) == 121 and int(ctx.get("nz", 0)) == 91 and (ctx.get("h", []) as Array).size() == 11011, "V7 el contexto son 121 × 91 = 11 011 nodos de 30 m centrados en el ancla")
		var meta: Dictionary = parsed_files.height.get("meta", {})
		suite.extra["relieve_fuente"] = str(meta.get("source", "?"))
		suite.extra["relieve_tag"] = str(meta.get("tag", "?"))
		if str(meta.get("source", "")) == "copernicus_glo30":
			suite.check(FileAccess.file_exists("res://docs/humahuaca/CREDITOS_RELIEVE.md"), "V18 (adelanto) con fuente Copernicus debe existir docs/humahuaca/CREDITOS_RELIEVE.md")

# ---------------------------------------------------------------------------------------------------------------------
# V8: tamaños y tipos de archivo en data/

func _all_files(dir: String) -> Array:
	var found: Array = []
	var da := DirAccess.open(dir)
	if da == null:
		return found
	for sub in da.get_directories():
		found.append_array(_all_files(dir.path_join(sub)))
	for f in da.get_files():
		found.append(dir.path_join(f))
	return found

func _test_v8_sizes() -> void:
	var sizes := {}
	for key in FILES:
		sizes[key] = (raw_bytes[key] as PackedByteArray).size()
	var data_files := _all_files("res://data")
	var v := v8_sizes(sizes, data_files)
	for key in FILES:
		var own := v.filter(func(m): return String(m).begins_with("V8 " + FILES[key] + " "))
		suite.check(own.is_empty(), "V8 %s pesa %.1f KB (tope %d KB)%s" % [FILES[key], float(sizes[key]) / 1024.0, SIZE_CAPS_KB[key], "" if own.is_empty() else ": " + str(own[0])])
	var strays := v.filter(func(m): return String(m).find("solo admite .json") >= 0)
	suite.check(strays.is_empty(), "V8 data/ tiene solo archivos .json (%d archivos)%s" % [data_files.size(), "" if strays.is_empty() else ": " + str(strays[0])])
	suite.extra["v8_tamanos_kb"] = {"height": snappedf(float(sizes.height) / 1024.0, 0.1), "map": snappedf(float(sizes.map) / 1024.0, 0.1)}

func _test_v9_palette() -> void:
	var v := v9_palette(parsed_files.visual)
	suite.check(v.is_empty(), "V9 la paleta son exactamente los 24 HEX de la lámina 06 y props/tokens no tienen colores sueltos%s" % ("" if v.is_empty() else ": " + str(v[0])))
	suite.check(PALETTE_24.size() == 24 and PALETTE_24.duplicate().size() == 24, "V9 la constante de la lámina 06 tiene 24 entradas")
	var unique := {}
	for h in PALETTE_24:
		unique[h] = true
	suite.check(unique.size() == 24, "V9 los 24 HEX de la lámina 06 son distintos entre sí")

func _test_v13_vocab_add_only() -> void:
	for vocab_name in Fx.VOCAB_PATHS:
		var script := Fx.load_script(Fx.VOCAB_PATHS[vocab_name])
		if not suite.check(script != null, "V13 %s carga y parsea" % vocab_name):
			continue
		var actual: Dictionary = {}
		var consts: Dictionary = script.get_script_constant_map()
		for c in consts:
			actual[str(c)] = consts[c]
		var v := v13_vocab_add_only(vocab_name, actual)
		suite.check(v.is_empty(), "V13 %s conserva todos sus ids iniciales (solo-agregar; %d constantes)%s" % [vocab_name, (Fx.VOCAB_MIN[vocab_name] as Dictionary).size(), "" if v.is_empty() else ": " + str(v[0])])
	# la función compartida del integrador funciona
	var shared := Fx.load_script(Fx.VOCAB_PATHS["humahuaca_vocab.gd"])
	if shared != null:
		suite.check(str(shared.call("tag_min", ["razonado", "diseno", "documentado"])) == "diseno" and str(shared.call("tag_min", [])) == "", "V13 humahuaca_vocab.tag_min devuelve la etiqueta más débil")
		var loaded: Dictionary = shared.call("load_json", "res://data/humahuaca_map.json")
		suite.check(int(loaded.get("contract", 0)) == 1, "V13 humahuaca_vocab.load_json lee un JSON del nivel con contract 1")

func _test_v13_rules_vs_vocab() -> void:
	var v := v13_rules_vs_vocab(parsed_files.rules, round_id)
	suite.check(v.is_empty(), "V13 las claves de rules.groups/objectives/actions/loot son los ids de los vocabularios%s" % ("" if v.is_empty() else ": " + str(v[0])))
	var rules: Variant = parsed_files.rules
	suite.extra["v13_rules_secciones"] = [] if not (rules is Dictionary) else ["groups", "objectives", "actions", "loot"].filter(func(k): return (rules as Dictionary).has(k))

func _test_v17_history() -> void:
	var history: Variant = Fx.read_json(HISTORY_PATH)
	suite.check(history is Dictionary, "V17 data/history.json parsea")
	var v := v17_history(history)
	suite.check(v.is_empty(), "V17 historia: scenarios.humahuaca completo, justine/norte/hecho del Norte/47 fuentes intactos y fuentes nuevas desde S46%s" % ("" if v.is_empty() else ": " + str(v[0])))
	if history is Dictionary:
		var sources: Array = history.get("sources", [])
		suite.extra["v17_fuentes"] = sources.size()
		suite.extra["v17_fuentes_nuevas"] = maxi(sources.size() - HISTORY_BASE_SOURCES, 0)

func _gather_script_sources() -> Dictionary:
	var sources := {}
	for path in Fx.list_files(SCRIPTS_DIR, "gd"):
		sources[path] = FileAccess.get_file_as_string(path)
	return sources

func _test_v19_dependency_graph() -> void:
	var sources := _gather_script_sources()
	suite.check(sources.size() >= 7, "V19 hay al menos 7 scripts en scripts/humahuaca/ (vocabularios, cáscara y copia): hay %d" % sources.size())
	var graph := v19_graph(sources)
	suite.check(graph.violations.is_empty(), "V19 grafo de dependencias: solo hacia abajo, sin ciclos, stubs independientes (%d scripts, %d aristas)%s" % [graph.files, graph.edges, "" if graph.violations.is_empty() else ": " + str(graph.violations[0])])
	suite.extra["v19_scripts"] = graph.files
	suite.extra["v19_aristas"] = graph.edges
	var conv_sources := sources.duplicate()
	for path in Fx.list_files("res://tests", "gd"):
		var file_name := String(path).get_file()
		if file_name.begins_with("test_hx_") or file_name == "hx_fixtures.gd" or file_name == "hx_validators.gd":
			conv_sources[path] = FileAccess.get_file_as_string(path)
	var conv := v19_conventions(conv_sources)
	suite.check(conv.violations.is_empty(), "V19 convenciones del código del nivel (sin class_name, LF, tabs, ≤ 1 500 líneas, reglas deterministas) en %d archivos%s" % [conv_sources.size(), "" if conv.violations.is_empty() else ": " + str(conv.violations[0])])
	suite.extra["v19_archivos_largos"] = conv.long_files
	# cada script se carga solo (sin caché) y parsea
	for path in sources:
		var res: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		var ok: bool = res != null and res is Script and (res as Script).can_instantiate()
		suite.check(ok, "V19 %s se carga solo (sin caché) y parsea" % String(path).trim_prefix("res://"))

func _read_project_text(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""

func _test_v20_traceability() -> void:
	var traza := _read_project_text(Fx.TRAZA_PATH)
	suite.check(traza != "", "V20 existe docs/humahuaca/TRAZA.md")
	suite.check(traza.find("Ronda vigente:") >= 0, "V20 TRAZA.md declara la «Ronda vigente:» (la leen esta prueba y tools/qa_gate.sh)")
	var result := v20_traza(traza, _read_project_text(CONTRACT_PATH), _read_project_text(QA_PATH), round_id, Callable(self, "_read_project_text"))
	suite.check(result.rows >= 40, "V20 TRAZA.md tiene filas para las exigencias (hay %d; mínimo 40)" % result.rows)
	suite.check(result.sections >= 15, "V20 el contrato tiene al menos 15 subsecciones numeradas en las secciones 3 a 5 (hay %d)" % result.sections)
	suite.check(result.violations.is_empty(), "V20 cada fila apunta a una prueba que existe cuando su ronda ya llegó, y ninguna sección 3 a 5 queda sin fila (%d violaciones)%s" % [result.violations.size(), "" if result.violations.is_empty() else ": " + str(result.violations[0])])
	suite.check(result.active >= 1, "V20 hay filas activas (ronda ya llegada) que resuelven a funciones reales: %d" % result.active)
	suite.extra["v20_filas"] = {"total": result.rows, "activas": result.active, "pendientes": result.pending, "adelantadas": result.advanced}

func _test_forma_examples() -> void:
	suite.check(Fx.FORMA_NAMES.size() == 5, "3.6 hay cinco ejemplos de forma: hud_state, render_state, campaign_report, plan_route y qa_state")
	for forma_name in Fx.FORMA_NAMES:
		var path: String = Fx.FORMA_DIR + forma_name + ".json"
		var forma := Fx.load_forma(forma_name)
		if not suite.check(not forma.is_empty(), "3.6 %s.json existe, parsea y es un objeto" % forma_name):
			continue
		var raw := FileAccess.get_file_as_bytes(path)
		suite.check(not raw.has(13) and not (raw.size() >= 3 and raw[0] == 0xEF), "3.6 %s.json es UTF-8 sin BOM y con LF" % forma_name)
		suite.check(forma.meta is Dictionary and typeof(forma.meta.get("nota", null)) == TYPE_STRING and forma.meta.get("opcionales", null) is Array, "3.6 %s.json trae «_forma» con «nota» y «opcionales»" % forma_name)
		var example: Dictionary = forma.example
		suite.check(example.size() >= 5, "3.6 %s.json trae todas las claves de la forma (%d claves de primer nivel)" % [forma_name, example.size()])
		var bad_optional: Array = (forma.optional as Array).filter(func(p): return not _path_exists_in_example(example, str(p)))
		suite.check(bad_optional.is_empty(), "3.6 %s.json: las rutas opcionales existen en el ejemplo%s" % [forma_name, "" if bad_optional.is_empty() else " (no existe " + str(bad_optional[0]) + ")"])
		var v := forma_vocab_violations(forma_name, example)
		suite.check(v.is_empty(), "3.6 %s.json usa ids y rangos del vocabulario del contrato%s" % [forma_name, "" if v.is_empty() else ": " + str(v[0])])
		suite.check(Fx.shape_diff(example, example, forma.optional).is_empty(), "3.6 %s.json tiene la forma de sí mismo (el comparador no inventa diferencias)" % forma_name)

# ---------------------------------------------------------------------------------------------------------------------
# Ganchos de herramientas y reglas de Git (CONTRATO 4.4)

func _test_tooling_hooks() -> void:
	var run_qa := _read_project_text("res://tools/run_qa.py")
	suite.check(run_qa.find("\"humahuaca\"") >= 0 and run_qa.find("choices=[\"justine\",\"humahuaca\",\"norte\"]") >= 0, "4.4 tools/run_qa.py acepta --scenario=humahuaca")
	for hermetic in ["res://tests/test_integration.gd", "res://tools/ui_qa.gd"]:
		var text := _read_project_text(hermetic)
		suite.check(text.find("humahuaca_progress.json") >= 0 and text.find("humahuaca_checkpoint.json") >= 0, "4.4 %s limpia humahuaca_progress.json y humahuaca_checkpoint.json (hermeticidad de perfil)" % hermetic.trim_prefix("res://"))
	var gitignore := _read_project_text("res://.gitignore")
	for rule in ["evidence/humahuaca/*", "!evidence/humahuaca/r4/", "*.tif", "evidence/humahuaca/**/_appdata/"]:
		suite.check(gitignore.split("\n").has(rule), "4.4 .gitignore tiene la regla «%s»" % rule)
	var attributes := _read_project_text("res://.gitattributes")
	for rule in ["scripts/humahuaca/** text eol=lf", "data/humahuaca_*.json text eol=lf", "shaders/humahuaca_* text eol=lf", "tests/test_hx_*.gd text eol=lf"]:
		suite.check(attributes.split("\n").has(rule), "4.4 .gitattributes tiene la regla «%s»" % rule)

# ---------------------------------------------------------------------------------------------------------------------
# Sanidad de los validadores: cada uno ve un error plantado

# ---------------------------------------------------------------------------------------------------------------------
# V6, V10 a V16, V18, V21 y V22 (BACKLOG B-013): corren desde r1 sobre los datos de las cuatro pistas

func _r1_rules_on() -> bool:
	return Fx.round_ge(round_id, "r1")

func _fmt_v(v: Array) -> String:
	return "" if v.is_empty() else ": " + str(v[0])

func _test_r1_rules() -> void:
	if not _r1_rules_on():
		return
	var f := parsed_files
	var v6 := v6_geometry(f.map, f.level)
	suite.check(v6.is_empty(), "V6 hitos y rasgos dentro de 900 × 650 m, objetivos separados 80 m o más y tapias sin cruzar un objetivo (%d violaciones)%s" % [v6.size(), _fmt_v(v6)])
	var v10 := v10_jargon(f.rules, f.ui)
	var seen: Array = []
	for key in ["texts", "field_events", "outcome", "actions"]:
		_visible_strings((f.rules as Dictionary).get(key, null) if f.rules is Dictionary else null, key, seen)
	for key in ["texts", "tutorial_steps"]:
		_visible_strings((f.ui as Dictionary).get(key, null) if f.ui is Dictionary else null, key, seen)
	suite.check(v10.is_empty(), "V10 ninguna de las %d cadenas visibles tiene jerga, snake_case ni mayúsculas enteras (%d violaciones)%s" % [seen.size(), v10.size(), _fmt_v(v10)])
	suite.extra["v10_cadenas_visibles"] = seen.size()
	var v11 := v11_limits(f.rules, round_id, V11_ACCEPTED)
	suite.check(v11.is_empty(), "V11 causas ≤ 140, página 1 del briefing ≤ 250 y pistas ≤ 120 caracteres (%d violaciones)%s" % [v11.size(), _fmt_v(v11)])
	suite.extra["v11_excepciones_fechadas"] = V11_ACCEPTED
	var v12 := v12_res_paths(f)
	suite.check(v12.is_empty(), "V12 todo res:// que citan los JSON existe (%d violaciones)%s" % [v12.size(), _fmt_v(v12)])
	var v13 := v13_variants_vs_vocab(f.rules)
	suite.check(v13.is_empty(), "V13 las dimensiones de rules.variants son las del vocabulario%s" % _fmt_v(v13))
	var v14 := v14_variants(f.rules, f.level, f.map)
	suite.check(v14.is_empty(), "V14 variantes y layouts legales (%d violaciones)%s" % [v14.size(), _fmt_v(v14)])
	var v15 := v15_views(f.visual)
	suite.check(v15.is_empty(), "V15 las 7 vistas canónicas con sus campos y 5 rasgos, y el cuadro inicial (%d violaciones)%s" % [v15.size(), _fmt_v(v15)])
	var v16 := v16_clock_and_loot(f.rules, round_id)
	suite.check(v16.is_empty(), "V16 el reloj ordenado y el botín suma exactamente 100 (%d violaciones)%s" % [v16.size(), _fmt_v(v16)])
	var credits := _read_project_text("res://docs/humahuaca/CREDITOS_RELIEVE.md")
	suite.check(credits != "", "V18 existe docs/humahuaca/CREDITOS_RELIEVE.md")
	var v18 := v18_credits(f.height, f.map, credits)
	suite.check(v18.is_empty(), "V18 los créditos del relieve traen lo que exige su fuente (%d violaciones)%s" % [v18.size(), _fmt_v(v18)])
	var v21 := v21_single_source(f.map, f.level, f.rules)
	suite.check(v21.is_empty(), "V21 una sola fuente por número: puestos de ataque a 60–120 m, spawn_* en la zona de partida y sin números de juego en el mapa ni el nivel (%d violaciones)%s" % [v21.size(), _fmt_v(v21)])
	var v22 := v22_camera_and_quality(f.visual, f.ui)
	suite.check(v22.is_empty(), "V22 las vistas canónicas y el cuadro inicial son coherentes con la cámara y quality trae los tres presupuestos (%d violaciones)%s" % [v22.size(), _fmt_v(v22)])

## Sanidad por mutación de las reglas encendidas en r1: cada una ve lo que se le planta y deja pasar lo legal.
func _mut_r1_rules() -> void:
	var base := _files_copy()
	var clean := v6_geometry(base.map, base.level).is_empty() and v10_jargon(base.rules, base.ui).is_empty() and v12_res_paths(base).is_empty() \
		and v14_variants(base.rules, base.level, base.map).is_empty() and v15_views(base.visual).is_empty() and v16_clock_and_loot(base.rules, round_id).is_empty() \
		and v21_single_source(base.map, base.level, base.rules).is_empty() and v22_camera_and_quality(base.visual, base.ui).is_empty()
	if not clean:
		suite.extra["sanidad_r1_omitida"] = "los datos reales ya tienen violaciones de estas reglas: la falla real está informada arriba"
		return
	var lms: Array = base.map.landmarks
	var bat_i := -1
	for i in range(lms.size()):
		if str(lms[i].id) == "bateria":
			bat_i = i
	var bat: Dictionary = lms[bat_i]
	# V6
	_flaw(base, "un hito fuera del mapa", func(f): f.map.landmarks[3].x = 1500.0, func(f): return v6_geometry(f.map, f.level))
	_flaw(base, "dos objetivos a 10 m", func(f): _lm_set(f, "cuartel", float(bat.x) + 10.0, float(bat.z)), func(f): return v6_geometry(f.map, f.level))
	_flaw(base, "una tapia que cruza el objetivo sin portillo", func(f): f.level.features.tapias.append({"id": "tapia_plantada", "pts": [{"x": float(bat.x) - 30.0, "z": float(bat.z)}, {"x": float(bat.x) + 30.0, "z": float(bat.z)}]}), func(f): return v6_geometry(f.map, f.level))
	var outside_ok := base.duplicate(true)
	outside_ok.map.landmarks[3].x = 1500.0
	outside_ok.map.landmarks[3]["outside"] = true
	suite.check(v6_geometry(outside_ok.map, outside_ok.level).is_empty(), "sanidad: un hito marcado outside: true puede quedar fuera del mapa")
	# V10
	_flaw(base, "la palabra «spawn» en un título", func(f): f.ui.texts["title"] = "II · spawn Humahuaca", func(f): return v10_jargon(f.rules, f.ui))
	_flaw(base, "la sigla ETA en un texto de reglas", func(f): f.rules.texts["objetivo"] = "Llegá a tiempo: ETA 3 min", func(f): return v10_jargon(f.rules, f.ui))
	_flaw(base, "un identificador snake_case en una causa", func(f): f.rules.outcome.causes.amanecio["texto"] = "A los {t} frente_roto en {deLugar}", func(f): return v10_jargon(f.rules, f.ui))
	_flaw(base, "un texto entero en mayúsculas", func(f): f.ui.texts["title"] = "HUMAHUACA", func(f): return v10_jargon(f.rules, f.ui))
	_flaw(base, "la lista negra vacía", func(f): f.ui["jargon_blacklist"] = [], func(f): return v10_jargon(f.rules, f.ui))
	_flaw(base, "una lista negra sin siglas", func(f): f.ui["jargon_blacklist"] = ["spawn", "loot"], func(f): return v10_jargon(f.rules, f.ui))
	var legal := base.duplicate(true)
	legal.ui.texts["title"] = "II · Los de Humahuaca, con tilde y sin sigla: sondeo de los caminos"
	suite.check(not v10_jargon(legal.rules, legal.ui).is_empty(), "sanidad: «sondeo» (palabra de la lista) se ve aunque la frase tenga «Los»")
	legal.ui.texts["title"] = "II · Los de Humahuaca"
	suite.check(v10_jargon(legal.rules, legal.ui).is_empty(), "sanidad: «Los» no dispara la sigla LOS (las siglas se buscan respetando mayúsculas)")
	# V11
	_flaw(base, "una causa de 200 caracteres", func(f): f.rules.outcome.causes.plazo["texto"] = "x".repeat(200), func(f): return v11_limits(f.rules, round_id, {}))
	_flaw(base, "la página 1 del briefing de 300 caracteres", func(f): f.rules.texts.briefing["pagina_1"] = "x".repeat(300), func(f): return v11_limits(f.rules, round_id, {}))
	_flaw(base, "una pista de 130 caracteres", func(f): f.rules.campaign.tips.plazo[0] = "x".repeat(130), func(f): return v11_limits(f.rules, round_id, {}))
	var late := base.duplicate(true)
	late.rules.campaign.tips.plazo[0] = "x".repeat(130)
	var dated := {"campaign.tips.plazo[0]": "r2a", "campaign.tips.dispersos[0]": "r2a"}  # la real (dispersos) y la plantada (plazo)
	suite.check(v11_limits(late.rules, "r1", dated).is_empty(), "sanidad: una excepción fechada deja pasar la pista hasta su ronda")
	suite.check(not v11_limits(late.rules, "r2a", dated).filter(func(m): return String(m).find("plazo[0]") >= 0).is_empty(), "sanidad: la excepción fechada vence en su ronda y la pista vuelve a fallar")
	# V12
	_flaw(base, "un res:// que no existe", func(f): f.rules["ruta_plantada"] = "res://data/no_existe_nunca.json", func(f): return v12_res_paths(f))
	# V13 (variantes)
	_flaw(base, "una dimensión de variante que no está en el vocabulario", func(f): f.rules.variants.dimensions["inventada"] = {"values": ["a"]}, func(f): return v13_variants_vs_vocab(f.rules))
	# V14
	_flaw(base, "un valor de variante ilegal", func(f): f.rules.variants.dimensions.guardia["values"] = ["descuidada", "distraida"], func(f): return v14_variants(f.rules, f.level, f.map))
	_flaw(base, "una dimensión inactiva sin valor fijo", func(f): f.rules.variants.fixed.erase("refugio"), func(f): return v14_variants(f.rules, f.level, f.map))
	_flaw(base, "un layout C", func(f): f.level.features.tapias[0]["layout"] = "C", func(f): return v14_variants(f.rules, f.level, f.map))
	_flaw(base, "una dimensión activa desconocida", func(f): f.rules.variants.active.append("clima"), func(f): return v14_variants(f.rules, f.level, f.map))
	# V15
	_flaw(base, "una vista de menos", func(f): f.visual.canonical_views.pop_back(), func(f): return v15_views(f.visual))
	_flaw(base, "una vista con 4 rasgos", func(f): f.visual.canonical_views[0].must_show.pop_back(), func(f): return v15_views(f.visual))
	_flaw(base, "una vista sin yaw", func(f): f.visual.canonical_views[1].erase("yaw_deg"), func(f): return v15_views(f.visual))
	# V16
	_flaw(base, "el alba antes de su comienzo", func(f): f.rules.time["alba_full_s"] = 100, func(f): return v16_clock_and_loot(f.rules, round_id))
	_flaw(base, "un botín que suma 101", func(f): f.rules.loot.classes.polvora["points"] = int(f.rules.loot.classes.polvora.points) + 1, func(f): return v16_clock_and_loot(f.rules, round_id))
	_flaw(base, "la salida de los desvelados antes del alba", func(f): f.rules.time["dawn_discovery_s"] = 100, func(f): return v16_clock_and_loot(f.rules, round_id))
	# V18
	var credits_ok := _read_project_text("res://docs/humahuaca/CREDITOS_RELIEVE.md")
	suite.check(v18_credits(base.height, base.map, credits_ok).is_empty(), "sanidad: los créditos reales cumplen V18")
	suite.check(not v18_credits(base.height, base.map, "sin nada").is_empty(), "sanidad: V18 ve unos créditos sin OpenStreetMap ni ODbL")
	var cop := base.duplicate(true)
	cop.height.meta["source"] = "copernicus_glo30"
	suite.check(not v18_credits(cop.height, cop.map, credits_ok.replace("produced using Copernicus WorldDEM-30", "")).is_empty(), "sanidad: V18 ve que con Copernicus falta el aviso")
	_flaw(base, "una procedencia sin la ODbL", func(f): f.map.provenance = {"lines": ["Relieve: lámina 03"]}, func(f): return v18_credits(f.height, f.map, credits_ok))
	# V21
	_flaw(base, "un puesto de ataque a 200 m", func(f): f.level.access.attack_posts.bateria[0] = {"x": float(bat.x) - 200.0, "z": float(bat.z)}, func(f): return v21_single_source(f.map, f.level, f.rules))
	_flaw(base, "un número de juego en el nivel", func(f): f.level.features["attack_range_m"] = 150, func(f): return v21_single_source(f.map, f.level, f.rules))
	_flaw(base, "un spawn fuera de la zona de partida", func(f): _lm_set(f, "spawn_portal", 800.0, 100.0), func(f): return v21_single_source(f.map, f.level, f.rules))
	# V22
	_flaw(base, "un cuadro inicial a 5 000 m", func(f): f.visual.initial_frame["distance"] = 5000.0, func(f): return v22_camera_and_quality(f.visual, f.ui))
	_flaw(base, "una vista de juego que no repite el cuadro inicial", func(f): _view_set(f, "juego_noche", "yaw_deg", 10.0), func(f): return v22_camera_and_quality(f.visual, f.ui))
	_flaw(base, "una hora del día fuera de 0..1", func(f): f.visual.canonical_views[0]["time_of_day"] = 1.5, func(f): return v22_camera_and_quality(f.visual, f.ui))
	_flaw(base, "un perfil de calidad de menos", func(f): f.visual.quality.erase("alta"), func(f): return v22_camera_and_quality(f.visual, f.ui))
	_flaw(base, "un presupuesto de cuadro distinto del de D14", func(f): f.visual.quality.media["frame_ms_mean_max"] = 9.0, func(f): return v22_camera_and_quality(f.visual, f.ui))

func _lm_set(f: Dictionary, id: String, x: float, z: float) -> void:
	for lm in f.map.landmarks:
		if str(lm.id) == id:
			lm.x = x
			lm.z = z

func _view_set(f: Dictionary, id: String, key: String, value: Variant) -> void:
	for view in f.visual.canonical_views:
		if str(view.id) == id:
			view[key] = value

func _flaw(files: Dictionary, label: String, mutate: Callable, validator: Callable) -> void:
	var copy := files.duplicate(true)
	mutate.call(copy)
	var found: Array = validator.call(copy)
	suite.check(not found.is_empty(), "sanidad: el validador ve «%s»" % label)

## Cada grupo de mutaciones parte de los datos reales: si los datos reales ya tienen violaciones de esa regla, el grupo se omite (la falla real ya
## está informada arriba y las copias rotas solo repetirían el ruido). Los grupos sintéticos (V8, V13, V19, V20, formas) siempre corren.
func _test_self_mutations() -> void:
	var base := _files_copy()
	var clean := {
		"v1": v1_identity(base, parse_errors).is_empty(),
		"v2": v2_required(base, round_id, pista).is_empty(),
		"v3": v3_ownership(base).violations.is_empty(),
		"v4": v4_tags(base).is_empty(),
		"v5": v5_ids_and_refs(base, round_id, not (round_id == "r1.0" and pista != "")).is_empty(),
		"v7": v7_grid(base.height, base.map).is_empty(),
		"v9": v9_palette(base.visual).is_empty(),
		"v17": v17_history(Fx.read_json(HISTORY_PATH)).is_empty()}
	var skipped: Array = []
	if clean.v1:
		_mut_v1(base)
	else:
		skipped.append("v1")
	if clean.v2:
		_mut_v2(base)
	else:
		skipped.append("v2")
	if clean.v3:
		_mut_v3(base)
	else:
		skipped.append("v3")
	if clean.v4:
		_mut_v4(base)
	else:
		skipped.append("v4")
	if clean.v5:
		_mut_v5(base)
	else:
		skipped.append("v5")
	if clean.v7:
		_mut_v7(base)
	else:
		skipped.append("v7")
	_mut_v8()
	if clean.v9:
		_mut_v9(base)
	else:
		skipped.append("v9")
	_mut_v13()
	_mut_v13b()
	if clean.v17:
		_mut_v17()
	else:
		skipped.append("v17")
	if _r1_rules_on():
		_mut_r1_rules()
	_mut_v19()
	_mut_v20()
	_mut_formas()
	suite.extra["sanidad_omitida"] = skipped

func _mut_v1(base: Dictionary) -> void:
	_flaw(base, "contract = 2", func(f): f.map.contract = 2, func(f): return v1_identity(f, parse_errors))
	_flaw(base, "map_version distinto en el nivel", func(f): f.level.map_version = 7, func(f): return v1_identity(f, parse_errors))
	_flaw(base, "archivo que no parsea", func(f): f.rules = null, func(f): return v1_identity(f, {"rules": "línea 1: x"}))
	suite.check(trailing_comma_line("{\"a\": [1, 2,\n ]}") == 1 and trailing_comma_line("{\"a\": [1,\n2,\n]}") == 2 and trailing_comma_line("{\"a\": \"x,]\"}") == 0 and trailing_comma_line("{\"a\": 1}") == 0, "sanidad: la coma final se detecta en el arreglo y no en una cadena")
	suite.check(not v1_format("x", PackedByteArray([0xEF, 0xBB, 0xBF, 0x7B, 0x7D]), {}).is_empty(), "sanidad: V1 ve un BOM")
	suite.check(not v1_format("x", "{\r\n}".to_utf8_buffer(), {}).is_empty(), "sanidad: V1 ve fines de línea CRLF")
	suite.check(not v1_format("x", "{\"a\": [1,]}".to_utf8_buffer(), {}).is_empty(), "sanidad: V1 ve una coma final")
	suite.check(not v1_format("x", "{}".to_utf8_buffer(), {"a": INF}).is_empty(), "sanidad: V1 ve un número infinito")
	suite.check(not v1_format("x", "[]".to_utf8_buffer(), {"h": [1.0, INF]}).is_empty(), "sanidad: V1 ve un número infinito dentro de un arreglo")

func _mut_v2(base: Dictionary) -> void:
	_flaw(base, "falta height.meta.source", func(f): f.height.meta.erase("source"), func(f): return v2_required(f, "r0"))
	_flaw(base, "map.anchor.x con tipo texto", func(f): f.map.anchor.x = "450", func(f): return v2_required(f, "r0"))
	_flaw(base, "falta map.landmarks en r1.0", func(f): f.map.erase("landmarks"), func(f): return v2_required(f, "r1.0"))
	suite.check(v2_required(base, "r0").filter(func(m): return String(m).find("landmarks") >= 0).is_empty(), "sanidad: map.landmarks todavía no se exige en r0")

func _mut_v3(base: Dictionary) -> void:
	_flaw(base, "«actions» dentro del mapa", func(f): f.map["actions"] = {}, func(f): return v3_ownership(f).violations)
	_flaw(base, "«landmarks» dentro del nivel", func(f): f.level["landmarks"] = [], func(f): return v3_ownership(f).violations)
	_flaw(base, "«features» dentro del mapa", func(f): f.map["features"] = {}, func(f): return v3_ownership(f).violations)
	suite.check(v3_ownership({"level": {"lights": []}, "visual": {"lights": {}}, "rules": {"texts": {}}, "ui": {"texts": {}}}).violations.is_empty(), "sanidad: lights (nivel y visual) y texts (reglas e interfaz) tienen dos dueños legítimos")

func _mut_v4(base: Dictionary) -> void:
	_flaw(base, "tag inventado", func(f): f.map.anchor.tag = "inventado", func(f): return v4_tags(f))
	_flaw(base, "tag_parts con la parte más débil mal", func(f): f.map.anchor["tag_parts"] = {"posicion": "diseno", "forma": "razonado"}, func(f): return v4_tags(f))
	_flaw(base, "tag_parts con una sola parte", func(f): f.map.anchor["tag_parts"] = {"posicion": "razonado"}, func(f): return v4_tags(f))
	_flaw(base, "hito sin source", func(f): f.map["landmarks"] = [{"id": "templo", "tag": "razonado"}], func(f): return v4_tags(f))
	_flaw(base, "source de 130 caracteres", func(f): f.map.anchor["source"] = "x".repeat(130), func(f): return v4_tags(f))
	var weakest_ok := base.duplicate(true)
	weakest_ok.map.anchor["tag"] = "diseno"
	weakest_ok.map.anchor["tag_parts"] = {"posicion": "diseno", "forma": "razonado"}
	suite.check(v4_tags(weakest_ok).is_empty(), "sanidad: tag_parts con tag = la parte más débil es válido")

## La mutación de «access que cita hitos sin mapa» no puede depender de que el mapa real esté vacío: apenas relieve_mapa entrega los hitos,
## «zona_partida» resuelve y el error plantado dejaba de existir (corrección del integrador en R1.0, ADDENDA A-06). Se vacía el registro de la copia.
func _plant_access_without_map_landmarks(f: Dictionary) -> void:
	f.map["landmarks"] = []
	f.level["access"] = {"zona_partida": "zona_partida"}

func _mut_v5(base: Dictionary) -> void:
	_flaw(base, "ids repetidos en un arreglo", func(f): f.map["landmarks"] = [{"id": "a", "tag": "razonado", "source": "x"}, {"id": "a", "tag": "razonado", "source": "x"}], func(f): return v5_ids_and_refs(f, "r0"))
	_flaw(base, "access que cita hitos sin mapa", _plant_access_without_map_landmarks, func(f): return v5_ids_and_refs(f, "r0"))
	_flaw(base, "hito obligatorio ausente", func(f): f.map["landmarks"] = [{"id": "templo", "tag": "razonado", "source": "x"}], func(f): return v5_ids_and_refs(f, "r1.0"))
	_flaw(base, "zona con un objetivo inexistente", func(f): f.level["zones"] = [{"id": "z1", "objective": "fortin"}], func(f): return v5_ids_and_refs(f, "r0"))
	var refs_ok := base.duplicate(true)
	var lms: Array = []
	for lm_id in MANDATORY_LANDMARKS:
		lms.append({"id": lm_id, "tag": "diseno", "source": "prueba"})
	refs_ok.map["landmarks"] = lms
	refs_ok.level["access"] = {"spawns": {"rodriguez": "spawn_rodriguez", "portal": "spawn_portal", "arias": "spawn_arias", "reconocedores": "spawn_reconocedores", "arreo": "spawn_arreo"},
		"zona_partida": "zona_partida", "south_entry": "entrada_sur", "exit": {"vado": "vado_este", "salida": "salida_este"},
		"attack_posts": {"bateria": [], "cuartel": [], "posta": []}}
	refs_ok.level["zones"] = [{"id": "z1", "objective": "bateria"}]
	suite.check(v5_ids_and_refs(refs_ok, "r1.0").is_empty(), "sanidad: un access completo con los 21 hitos resuelve todas sus referencias")
	_flaw(refs_ok, "spawns sin una agrupación", func(f): f.level.access.spawns.erase("arreo"), func(f): return v5_ids_and_refs(f, "r1.0"))
	_flaw(refs_ok, "spawn que apunta a un hito que no es spawn_*", func(f): f.level.access.spawns.portal = "templo", func(f): return v5_ids_and_refs(f, "r1.0"))
	_flaw(refs_ok, "attack_posts sin un frente", func(f): f.level.access.attack_posts.erase("posta"), func(f): return v5_ids_and_refs(f, "r1.0"))
	_flaw(refs_ok, "salida que cita un hito inexistente", func(f): f.level.access.exit.vado = "vado_oeste", func(f): return v5_ids_and_refs(f, "r1.0"))
	_flaw(refs_ok, "referencia «landmark» a un hito inexistente en las reglas", func(f): f.rules["objectives"] = {"bateria": {"landmark": "fortin"}}, func(f): return v5_ids_and_refs(f, "r1.0"))

func _mut_v7(base: Dictionary) -> void:
	_flaw(base, "una celda menos", func(f): f.height.window.h.pop_back(), func(f): return v7_grid(f.height, f.map))
	_flaw(base, "un nodo del borde 5 dm distinto del contexto", func(f): f.height.window.h[0] = 175, func(f): return v7_grid(f.height, f.map))
	_flaw(base, "un valor fuera de rango", func(f): f.height.window.h[3000] = 5000, func(f): return v7_grid(f.height, f.map))
	_flaw(base, "un valor no entero", func(f): f.height.context.h[10] = 170.5, func(f): return v7_grid(f.height, f.map))
	_flaw(base, "fuente desconocida", func(f): f.height.meta.source = "google_earth", func(f): return v7_grid(f.height, f.map))
	_flaw(base, "datum distinto entre height y map", func(f): f.map.datum_asl_m = 2950.0, func(f): return v7_grid(f.height, f.map))
	_flaw(base, "paso de celda 5 m", func(f): f.height.window.cell_m = 5.0, func(f): return v7_grid(f.height, f.map))

func _mut_v8() -> void:
	suite.check(not v8_sizes({"height": 460 * 1024}, []).is_empty(), "sanidad: V8 ve un height de 460 KB (tope 450)")
	suite.check(not v8_sizes({}, ["res://data/relieve.bin"]).is_empty(), "sanidad: V8 ve un binario en data/")
	suite.check(v8_sizes({"height": 450 * 1024}, ["res://data/a.json"]).is_empty(), "sanidad: V8 acepta justo el tope y un .json")

func _mut_v9(base: Dictionary) -> void:
	_flaw(base, "un HEX distinto", func(f): f.visual.palette[0].hex = "#B99A73", func(f): return v9_palette(f.visual))
	_flaw(base, "una entrada de menos", func(f): f.visual.palette.pop_back(), func(f): return v9_palette(f.visual))
	_flaw(base, "un id repetido", func(f): f.visual.palette[1].id = f.visual.palette[0].id, func(f): return v9_palette(f.visual))
	_flaw(base, "un HEX suelto en props", func(f): f.visual["props"] = {"templo": {"wall_color": "#112233"}}, func(f): return v9_palette(f.visual))
	_flaw(base, "un color que no cita la paleta", func(f): f.visual["props"] = {"templo": {"wall_color": "verde_loro"}}, func(f): return v9_palette(f.visual))
	var props_ok := base.duplicate(true)
	props_ok.visual["props"] = {"templo": {"wall_color": "adobe"}}
	props_ok.visual["markers"] = {"celeste": "#7FAAC4"}
	suite.check(v9_palette(props_ok.visual).is_empty(), "sanidad: props que citan un id de paleta y markers con HEX («interfaz») son válidos")

func _mut_v13() -> void:
	var vocab_now: Dictionary = (Fx.VOCAB_MIN["vocab_ui.gd"] as Dictionary).duplicate(true)
	suite.check(v13_vocab_add_only("vocab_ui.gd", vocab_now).is_empty(), "sanidad: un vocabulario idéntico al inicial cumple el solo-agregar")
	var grown := vocab_now.duplicate(true)
	grown["TOAST_LEVELS"] = ["info", "aviso", "critica", "debug"]
	suite.check(v13_vocab_add_only("vocab_ui.gd", grown).is_empty(), "sanidad: agregar un id es legal")
	var shrunk := vocab_now.duplicate(true)
	shrunk["TOAST_LEVELS"] = ["info", "aviso"]
	suite.check(not v13_vocab_add_only("vocab_ui.gd", shrunk).is_empty(), "sanidad: quitar un id del vocabulario se ve")
	var reordered := (Fx.VOCAB_MIN["humahuaca_vocab.gd"] as Dictionary).duplicate(true)
	reordered["GROUPS"] = ["portal", "rodriguez", "arias", "reconocedores", "arreo"]
	suite.check(not v13_vocab_add_only("humahuaca_vocab.gd", reordered).is_empty(), "sanidad: reordenar GROUPS (teclas 1 a 5) se ve")

func _mut_v13b() -> void:
	var rules_ok := {"groups": {}, "objectives": {}, "actions": {}, "loot": {"kinds": {}}}
	for g in GROUPS:
		rules_ok.groups[g] = {}
	for o in OBJECTIVES:
		rules_ok.objectives[o] = {}
	for a in _all_actions():
		rules_ok.actions[a] = {}
	for k in _vocab("vocab_rules.gd", "LOOT_KINDS_R1"):
		rules_ok.loot.kinds[k] = {}
	suite.check(v13_rules_vs_vocab(rules_ok, "r1.0").is_empty(), "sanidad: reglas con todos los ids del vocabulario y las 5 clases de botín de R1 cumplen V13")
	var no_arreo := rules_ok.duplicate(true)
	no_arreo.groups.erase("arreo")
	suite.check(not v13_rules_vs_vocab(no_arreo, "r1.0").is_empty(), "sanidad: V13 ve una agrupación del vocabulario que falta en rules.groups")
	var extra_group := rules_ok.duplicate(true)
	extra_group.groups["hereje"] = {}
	suite.check(not v13_rules_vs_vocab(extra_group, "r1.0").is_empty(), "sanidad: V13 ve una agrupación que no está en el vocabulario")
	var no_cancel := rules_ok.duplicate(true)
	no_cancel.actions.erase("cancel")
	suite.check(not v13_rules_vs_vocab(no_cancel, "r1.0").is_empty(), "sanidad: V13 ve una acción del vocabulario que falta en rules.actions")
	var odd_loot := rules_ok.duplicate(true)
	odd_loot.loot.kinds["tesoro"] = {}
	suite.check(not v13_rules_vs_vocab(odd_loot, "r1.0").is_empty(), "sanidad: V13 ve una clase de botín que no está en LOOT_KINDS")
	suite.check(not v13_rules_vs_vocab(rules_ok, "r2a").is_empty(), "sanidad: V13 exige las 9 clases de botín desde r2a")

func _mut_v17() -> void:
	var history: Variant = Fx.read_json(HISTORY_PATH)
	if history is Dictionary:
		var hist_base := (history as Dictionary).duplicate(true)
		suite.check(v17_history(hist_base).is_empty(), "sanidad: la historia sin tocar cumple V17")
		var h1 := hist_base.duplicate(true)
		h1.scenarios.norte.title = h1.scenarios.norte.title + "."
		suite.check(not v17_history(h1).is_empty(), "sanidad: V17 ve un cambio en scenarios.norte")
		var h2 := hist_base.duplicate(true)
		h2.sources[3].title = "otro"
		suite.check(not v17_history(h2).is_empty(), "sanidad: V17 ve un cambio en una de las 47 fuentes")
		var h3 := hist_base.duplicate(true)
		h3.scenarios.erase("humahuaca")
		suite.check(not v17_history(h3).is_empty(), "sanidad: V17 ve que falta scenarios.humahuaca")
		var h4 := hist_base.duplicate(true)
		h4.sources.append({"id": "S40", "title": "x"})
		suite.check(not v17_history(h4).is_empty(), "sanidad: V17 ve una fuente nueva que no empieza en S46 (S40 ya existe)")
		var h5 := hist_base.duplicate(true)
		# El id libre siguiente, no «S46» a ciegas: apenas reglas_historia agrega sus fuentes (S46 en adelante), plantar S46 de nuevo es un id repetido
		# y la mutación fallaba por un defecto suyo y no de V17 (ADDENDA A-12; el mismo patrón que la sanidad de V5 en A-06).
		var next_n := 46
		var sid_rx := RegEx.new()
		sid_rx.compile("^S(\\d+)[a-z]?$")
		for existing in h5.sources:
			var sid_m := sid_rx.search(str(existing.get("id", "")) if existing is Dictionary else "")
			if sid_m != null:
				next_n = maxi(next_n, int(sid_m.get_string(1)) + 1)
		var new_sid := "S%d" % next_n
		h5.sources.append({"id": new_sid, "title": "nueva"})
		suite.check(v17_history(h5).is_empty(), "sanidad: agregar una fuente con el id libre siguiente (%s, desde S46) es legal" % new_sid)
		h5.sources.append({"id": new_sid, "title": "repetida"})
		suite.check(not v17_history(h5).is_empty(), "sanidad: V17 ve un id de fuente repetido")
		var h6 := hist_base.duplicate(true)
		for fact in h6.scenarios.norte.facts:
			if str(fact.get("title", "")) == HISTORY_FACT_TITLE:
				fact["text"] = String(fact.text) + " "
		suite.check(not v17_history(h6).is_empty(), "sanidad: V17 ve un cambio en el hecho «Humahuaca: Arias al mando»")
		var h7 := hist_base.duplicate(true)
		h7.scenarios.humahuaca.erase("facts")
		suite.check(not v17_history(h7).is_empty(), "sanidad: V17 ve que a scenarios.humahuaca le falta «facts»")

func _mut_v19() -> void:
	var good_sources := {
		SCRIPTS_DIR + "/humahuaca_vocab.gd": "extends RefCounted\nconst A := 1\n",
		SCRIPTS_DIR + "/terrain/humahuaca_terrain.gd": "extends RefCounted\nconst V = preload(\"res://scripts/humahuaca/humahuaca_vocab.gd\")\n",
		SCRIPTS_DIR + "/rules/humahuaca_rules.gd": "extends RefCounted\nconst T = preload(\"res://scripts/humahuaca/terrain/humahuaca_terrain.gd\")\n",
		SCRIPTS_DIR + "/view/humahuaca_view.gd": "extends Node3D\nconst R = preload(\"res://scripts/humahuaca/rules/humahuaca_rules.gd\")\n",
		SCRIPTS_DIR + "/ui/humahuaca_ui.gd": "extends Node\nconst W = preload(\"res://scripts/humahuaca/view/humahuaca_view.gd\")\n# preload(\"res://scripts/humahuaca/rules/humahuaca_rules.gd\") en un comentario no cuenta\n",
		SCRIPTS_DIR + "/stubs/stub_rules.gd": "extends RefCounted\nconst V = preload(\"res://scripts/humahuaca/humahuaca_vocab.gd\")\nconst S = preload(\"res://scripts/humahuaca/stubs/stub_terrain.gd\")\n",
		SCRIPTS_DIR + "/stubs/stub_terrain.gd": "extends RefCounted\n"}
	suite.check(v19_graph(good_sources).violations.is_empty(), "sanidad: un grafo hacia abajo, con un stub que cita a otro stub y un comentario con preload, no tiene violaciones")
	var up := good_sources.duplicate()
	up[SCRIPTS_DIR + "/terrain/humahuaca_terrain.gd"] += "const U = preload(\"res://scripts/humahuaca/ui/humahuaca_ui.gd\")\n"
	suite.check(not v19_graph(up).violations.is_empty(), "sanidad: V19 ve una arista hacia arriba (terreno → interfaz)")
	var cyc := good_sources.duplicate()
	cyc[SCRIPTS_DIR + "/rules/humahuaca_progress.gd"] = "extends RefCounted\nconst R = preload(\"res://scripts/humahuaca/rules/humahuaca_rules.gd\")\n"
	cyc[SCRIPTS_DIR + "/rules/humahuaca_rules.gd"] += "const P = preload(\"res://scripts/humahuaca/rules/humahuaca_progress.gd\")\n"
	suite.check(not v19_graph(cyc).violations.is_empty(), "sanidad: V19 ve un ciclo entre dos scripts de la misma capa")
	var stub_real := good_sources.duplicate()
	stub_real[SCRIPTS_DIR + "/stubs/stub_rules.gd"] += "const X = preload(\"res://scripts/humahuaca/rules/humahuaca_rules.gd\")\n"
	suite.check(not v19_graph(stub_real).violations.is_empty(), "sanidad: V19 ve un stub que depende del código real de su pista")
	var missing := good_sources.duplicate()
	missing[SCRIPTS_DIR + "/ui/humahuaca_ui.gd"] += "const Z = load(\"res://scripts/humahuaca/view/no_existe.gd\")\n"
	suite.check(not v19_graph(missing).violations.is_empty(), "sanidad: V19 ve un import de un archivo que no existe")
	suite.check(not v19_graph({SCRIPTS_DIR + "/otra_cosa/x.gd": "extends Node\n"}).violations.is_empty(), "sanidad: V19 ve un script fuera de las carpetas de capa")
	suite.check(imports_of("extends Node\nvar x = \"#\" + str(1)\nconst A = preload(\"res://scripts/humahuaca/humahuaca_vocab.gd\") # y load(\"res://scripts/humahuaca/ui/x.gd\")\n").size() == 1, "sanidad: imports_of ignora los comentarios y respeta un # dentro de una cadena")
	suite.check(imports_of("extends \"res://scripts/humahuaca/terrain/x.gd\"\n").size() == 1, "sanidad: imports_of lee «extends» por ruta")
	suite.check(not v19_conventions({"a.gd": "class_name Foo\nextends Node\n"}).violations.is_empty(), "sanidad: V19 ve un class_name")
	suite.check(not v19_conventions({"a.gd": "extends Node\r\nvar x = 1\r\n"}).violations.is_empty(), "sanidad: V19 ve fines de línea CRLF")
	suite.check(not v19_conventions({"a.gd": "extends Node\nfunc f():\n    pass\n"}).violations.is_empty(), "sanidad: V19 ve indentación con espacios")
	suite.check(not v19_conventions({"a.gd": "extends Node\n" + "var x = 1\n".repeat(1700)}).violations.is_empty(), "sanidad: V19 ve un archivo de más de 1 600 líneas")
	suite.check(not v19_conventions({SCRIPTS_DIR + "/rules/humahuaca_rules.gd": "extends RefCounted\nfunc f():\n\treturn randf()\n"}).violations.is_empty(), "sanidad: V19 ve randf() en las reglas")
	suite.check(v19_conventions({SCRIPTS_DIR + "/rules/humahuaca_rules.gd": "extends RefCounted\nfunc f(rng):\n\treturn rng.randf() # y randi() en un comentario\n"}).violations.is_empty(), "sanidad: rng.randf() y un comentario no son azar global")
	suite.check(v19_conventions({"a.gd": "extends Node\nvar texto = \"\"\"\n    con espacios\n\"\"\"\n"}).violations.is_empty(), "sanidad: el texto de una cadena de varias líneas no cuenta como indentación")

func _mut_v20() -> void:
	var contract_text := "### 3.1 Algo\n#### 3.2.1 Estado\n### 4.1 Menú\n### 5.2 Líneas base\n### 1.2 Archivos\n"
	var qa_text := "| T01 | T | Protegidos |\n| C04 | C | Menú |\n"
	var files_in_memory := {"res://tests/test_hx_x.gd": "func _test_algo():\n\tpass\nstatic func _test_otra():\n\tpass\n", "res://tools/qa_gate.sh": "step_protected() {\n}\nfunction step_otro() {\n}\n"}
	var reader := func(p): return files_in_memory.get(p, "")
	var good_traza := "| ID | Sección | Exigencia | Prueba | Desde |\n|---|---|---|---|---|\n| TR-001 | 3.1 | a | `test_hx_x::_test_algo` | r0 |\n| TR-002 | 3.2.1 | b | test_hx_x::_test_otra | r0 |\n| TR-003 | 4.1 | c | qa_gate::step_protected | r0 |\n| TR-004 | 5.2 | d | QA:T01 | r0 |\n| TR-005 | 5.2 | e | test_hx_y::_test_futura | r2a |\n"
	var ok_result := v20_traza(good_traza, contract_text, qa_text, "r0", reader)
	suite.check(ok_result.violations.is_empty() and ok_result.active == 4 and ok_result.pending == 1, "sanidad: V20 acepta filas que existen y una pendiente de una ronda futura (%s)" % str(ok_result))
	var gone := good_traza.replace("_test_algo", "_test_borrada")
	suite.check(not v20_traza(gone, contract_text, qa_text, "r0", reader).violations.is_empty(), "sanidad: V20 ve una fila que apunta a una función que no existe")
	suite.check(not v20_traza(good_traza, contract_text, qa_text, "r2a", reader).violations.is_empty(), "sanidad: V20 exige la fila futura cuando llega su ronda")
	suite.check(not v20_traza(good_traza.replace("| TR-003 | 4.1 |", "| TR-003 | 4.2 |"), contract_text, qa_text, "r0", reader).violations.is_empty(), "sanidad: V20 ve una sección del contrato sin fila")
	suite.check(not v20_traza(good_traza.replace("QA:T01", "QA:Z99"), contract_text, qa_text, "r0", reader).violations.is_empty(), "sanidad: V20 ve un ítem de rúbrica que no existe")
	suite.check(not v20_traza(good_traza.replace("TR-002", "TR-001"), contract_text, qa_text, "r0", reader).violations.is_empty(), "sanidad: V20 ve un id de fila repetido")
	suite.check(not v20_traza(good_traza.replace("test_hx_x::_test_algo", "sin_formato"), contract_text, qa_text, "r0", reader).violations.is_empty(), "sanidad: V20 ve una prueba sin forma archivo::función")
	suite.check(v20_traza(good_traza, contract_text, qa_text, "r0", reader).sections == 4, "sanidad: V20 cuenta solo las subsecciones 3.x, 4.x y 5.x del contrato")

func _mut_formas() -> void:
	for forma_name in Fx.FORMA_NAMES:
		var forma := Fx.load_forma(forma_name)
		if forma.is_empty():
			continue
		var cut: Dictionary = forma.example.duplicate(true)
		cut.erase(forma.example.keys()[1])
		suite.check(not Fx.shape_diff(forma.example, cut, forma.optional).is_empty(), "sanidad: la comparación de formas ve que a %s le falta la clave «%s»" % [forma_name, forma.example.keys()[1]])
