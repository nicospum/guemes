extends Node
## Controlador de «humahuaca» (CONTRATO 3.5 y 7). Primera versión de ui_feel (R1.0), hecha a partir de la cáscara de T0 (stubs/stub_ui.gd).
## Lo que suma a la cáscara es lo único que el contrato pide en esta ronda: arma el nivel con la clase real de cada capa (terreno, reglas,
## progreso y vista) o, si falta o no parsea, con su versión mínima de stubs/ (carga con respaldo; start(opts.force_stub) fuerza el reemplazo),
## avisa con una línea roja qué capa corre en respaldo y mantiene el reloj, la pausa y las velocidades. Si falta hasta la versión mínima, el
## nivel arranca igual y se vuelve al menú con Esc. El HUD completo, las tarjetas, la cámara con entrada y las órdenes llegan en R1.
## Dependencia solo hacia abajo (V19): importa vocabularios; las capas se cargan con load() diferido por rutas en constantes, nunca con preload.
## Lo que toca de `main` (camera.far y fov) lo restaura stop(), que es idempotente. Se libera con queue_free(), nunca con free().

signal exited(to: String)  # "menu" | "norte"

const V = preload("res://scripts/humahuaca/humahuaca_vocab.gd")
const R = preload("res://scripts/humahuaca/rules/vocab_rules.gd")
const W = preload("res://scripts/humahuaca/view/vocab_view.gd")
const U = preload("res://scripts/humahuaca/ui/vocab_ui.gd")

## Por capa: [clase real, versión mínima]. Son cadenas sueltas (no load literal) para que un archivo ausente no rompa el grafo de dependencias.
const LAYER_PATHS := {
	"terrain": ["res://scripts/humahuaca/terrain/humahuaca_terrain.gd", "res://scripts/humahuaca/stubs/stub_terrain.gd"],
	"rules": ["res://scripts/humahuaca/rules/humahuaca_rules.gd", "res://scripts/humahuaca/stubs/stub_rules.gd"],
	"progress": ["res://scripts/humahuaca/rules/humahuaca_progress.gd", "res://scripts/humahuaca/stubs/stub_progress.gd"],
	"view": ["res://scripts/humahuaca/view/humahuaca_view.gd", "res://scripts/humahuaca/stubs/stub_view.gd"]}

const DEFAULT_SEED := 1817
const HUD_PERIOD := 0.2  # segundos entre dos lecturas de hud_state()
const MAX_FRAME_DT := 0.25  # un cuadro lento no avanza más que esto (antes de multiplicar por la velocidad)
const MAX_STEP_S := 3600.0  # tope de qa_step: una llamada no puede colgar la herramienta
const PAPER := Color("e9e3d4")
const GOLD := Color("d9b576")
const PANEL_BG := Color(0.075, 0.095, 0.062, 0.94)
const PANEL_BORDER := Color("50543a")
const WARN_BG := Color("7a2e26")
const WARN_BORDER := Color("b8584b")
const WARN_TEXT := Color("fff1e6")
## Respaldo mínimo si ui.json no se pudo leer (los textos del juego salen de ese archivo, no del código).
const FALLBACK_TITLE := "Humahuaca: el depósito de la retaguardia"
const FALLBACK_RUNNING := "Tiempo real · ▶ ×%d"
const FALLBACK_PAUSED := "‖ En pausa"

var main: Node
var rules: RefCounted  # reglas (la clase real o su versión mínima); null si no hay ninguna de las dos
var progress: RefCounted
var view: Node3D  # la vista; null si no hay ninguna o no hay reglas que dibujar
var paused := true
var speed := 1.0
var layers: Dictionary = {}  # id de capa → "real" | "minimo" | "falta"

var _opts: Dictionary = {}
var _cli: Dictionary = {}
var _texts: Dictionary = {}
var _force: Array = []
var _scripts: Dictionary = {}  # id de capa → Script elegido
var _seed := DEFAULT_SEED
var _attempt := 1
var _start_phase := ""
var _skip_intro := false
var _clock := 0.0  # reloj propio: solo cuenta cuando no hay reglas
var _saved_cam: Dictionary = {}
var _cam := {"target": Vector2(450.0, 325.0), "dist": 600.0, "pitch_deg": 55.0, "yaw_deg": 0.0}
var _hud: VBoxContainer
var _title: Label
var _clock_label: Label
var _objective: Label
var _next: Label
var _warn_panel: PanelContainer
var _warn: Label
var _hud_data: Dictionary = {}
var _hud_timer := 0.0
var _notice := ""
var _ended := false
var _end_line := ""

# ---------------------------------------------------------------------------------------------------------------------
# Arranque y cierre

## opts: {load, qa, attempt, seed, phase, skip_intro, force_stub}. Las banderas --hx-seed, --hx-phase y --hx-skip-intro completan lo que opts no trae.
func start(m: Node, opts: Dictionary = {}) -> void:
	main = m
	_opts = opts.duplicate(true)
	_cli = _cli_flags()
	_texts = _load_texts()
	_read_options()
	if is_instance_valid(main.camera):
		_saved_cam = {"far": main.camera.far, "fov": main.camera.fov}
		main.camera.far = 9000.0
		main.camera.fov = 46.0
	_build_hud()
	_build_layers()
	_begin_game()
	_build_view()
	_apply_initial_camera()
	_apply_camera()
	_refresh_hud(true)

## Libera lo propio y deja `main` como estaba; main.gd libera este nodo y vuelve al menú o al norte. Se puede llamar más de una vez.
func stop() -> void:
	if main != null and is_instance_valid(main.camera):
		if not _saved_cam.is_empty():
			main.camera.far = _saved_cam.far
			main.camera.fov = _saved_cam.fov
		main.camera.current = true
	_saved_cam = {}
	if is_instance_valid(view):
		view.queue_free()
	view = null
	if is_instance_valid(_hud):
		_hud.queue_free()
	_hud = null
	_title = null
	_clock_label = null
	_objective = null
	_next = null
	_warn_panel = null
	_warn = null
	rules = null
	progress = null
	main = null
	set_process(false)
	set_process_unhandled_input(false)

func _read_options() -> void:
	_force = []
	var forced: Variant = _opts.get("force_stub", [])
	if forced is Array:
		for id in forced:
			if U.LAYER_IDS.has(str(id)) and not _force.has(str(id)):
				_force.append(str(id))
	_skip_intro = bool(_opts.get("skip_intro", _cli.get("skip_intro", false)))
	var wanted := str(_opts.get("phase", _cli.get("phase", "")))
	_start_phase = wanted if R.PHASES.has(wanted) and wanted != "epilogo" else ""

static func _cli_flags() -> Dictionary:
	var out := {}
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("--hx-seed="):
			out["seed"] = int(text.trim_prefix("--hx-seed="))
		elif text.begins_with("--hx-phase="):
			out["phase"] = text.trim_prefix("--hx-phase=")
		elif text == "--hx-skip-intro":
			out["skip_intro"] = true
	return out

func _load_texts() -> Dictionary:
	var data := V.load_json(V.UI_PATH)
	var texts: Variant = data.get("texts", {})
	return texts if texts is Dictionary else {}

# ---------------------------------------------------------------------------------------------------------------------
# Capas con respaldo (CONTRATO 7)

func _build_layers() -> void:
	for id in U.LAYER_IDS:
		var picked := _pick_layer(str(id))
		_scripts[id] = picked.script
		layers[id] = picked.kind
	progress = _make_progress(_scripts.get("progress"))
	rules = _make_rules(_scripts.get("rules"))
	if rules == null:
		layers["rules"] = "falta"

## La clase real si carga; si no (o si se la fuerza), la versión mínima; si tampoco, ninguna.
func _pick_layer(id: String) -> Dictionary:
	var paths: Array = LAYER_PATHS[id]
	if not _force.has(id):
		var real := _try_load(str(paths[0]))
		if real != null:
			return {"script": real, "kind": "real"}
	var minimal := _try_load(str(paths[1]))
	if minimal != null:
		return {"script": minimal, "kind": "minimo"}
	return {"script": null, "kind": "falta"}

static func _try_load(path: String) -> Script:
	if not ResourceLoader.exists(path):
		return null
	var res: Resource = load(path)
	if res == null or not (res is Script):
		return null
	var loaded: Script = res
	return loaded if loaded.can_instantiate() else null

static func _script_has(layer_script: Script, method: String) -> bool:
	for entry in layer_script.get_script_method_list():
		if str(entry.name) == method:
			return true
	return false

func _make_progress(layer_script: Script) -> RefCounted:
	if layer_script == null:
		return null
	var progress_path: String = V.PROGRESS_PATH
	var checkpoint_path: String = V.CHECKPOINT_PATH
	if bool(_opts.get("qa", false)) or bool(main.qa_mode):
		progress_path = "user://qa_humahuaca_progress.json"
		checkpoint_path = "user://qa_humahuaca_checkpoint.json"
	var made: Variant = layer_script.new(progress_path, checkpoint_path)
	if not (made is RefCounted):
		return null
	var made_progress: RefCounted = made
	if made_progress.has_method("load_progress"):
		made_progress.call("load_progress")
	return made_progress

## Si el terreno corre en su versión mínima (falta la clase real o se la forzó) y las reglas aceptan que se les dé uno, se lo damos.
func _make_rules(layer_script: Script) -> RefCounted:
	if layer_script == null:
		return null
	var made: Variant = layer_script.new()
	if not (made is RefCounted):
		return null
	var made_rules: RefCounted = made
	var terrain_script: Script = _scripts.get("terrain")
	if str(layers.get("terrain", "")) == "minimo" and terrain_script != null and made_rules.has_method("set_terrain"):
		var terrain: Variant = terrain_script.call("load_default") if _script_has(terrain_script, "load_default") else terrain_script.new()
		if terrain != null:
			made_rules.call("set_terrain", terrain)
	return made_rules

func _build_view() -> void:
	if is_instance_valid(view):
		view.queue_free()
	view = null
	var view_script: Script = _scripts.get("view")
	if view_script == null or rules == null:
		return
	var made: Variant = view_script.new()
	if not (made is Node3D):
		if made is Node:
			(made as Node).free()
		return
	view = made
	add_child(view)
	view.call("build", rules, _quality())

func _quality() -> String:
	var wanted := str(main.settings.get("quality", "media"))
	return wanted if W.QUALITY.has(wanted) else "media"

# ---------------------------------------------------------------------------------------------------------------------
# Partida

func _begin_game() -> void:
	_seed = _pick_seed()
	_attempt = int(_opts.get("attempt", 0))
	if _attempt <= 0:
		var done: Variant = progress.get("attempts") if progress != null else null
		_attempt = 1 + (int(done) if typeof(done) == TYPE_INT or typeof(done) == TYPE_FLOAT else 0)
	if bool(_opts.get("load", false)) and _try_load_save():
		return
	_new_attempt({}, true)

func _pick_seed() -> int:
	if _opts.has("seed"):
		return int(_opts.seed)
	if _cli.has("seed"):
		return int(_cli.seed)
	if progress != null and progress.has_method("world_seed"):
		var from_progress: Variant = progress.call("world_seed")
		if typeof(from_progress) == TYPE_INT or typeof(from_progress) == TYPE_FLOAT:
			return int(from_progress)
	return DEFAULT_SEED

## Empieza un intento (o lo reinicia). `extra` pisa las opciones de new_game; la vista se rearma si ya existía.
func _new_attempt(extra: Dictionary = {}, count_attempt: bool = false) -> void:
	_ended = false
	_end_line = ""
	_clock = 0.0
	if rules == null:
		return
	var new_opts := {}
	if _skip_intro:
		new_opts["skip_intro"] = true
	if _start_phase != "":
		new_opts["phase"] = _start_phase
	if not _force.is_empty():
		new_opts["force_stub"] = _force.duplicate()
	new_opts.merge(extra, true)
	rules.call("new_game", _seed, _attempt, new_opts)
	if count_attempt and progress != null and progress.has_method("begin_attempt"):
		progress.call("begin_attempt", rules)
	if is_instance_valid(view):
		_build_view()

## «Continuar» y F9 llegan con opts.load. Si el guardado falta, está dañado o las reglas lo rechazan, se explica y se empieza de cero.
func _try_load_save() -> bool:
	var reason := ""
	var path := str(main._save_path(V.SCENARIO))
	if rules == null:
		reason = _t("load.reasons.no_rules", "")
	elif not FileAccess.file_exists(path):
		reason = _t("load.reasons.missing", "")
	else:
		var parser := JSON.new()  # parse() devuelve un código de error; parse_string() imprime un ERROR en la consola si el archivo está dañado
		var parsed: Variant = parser.data if parser.parse(FileAccess.get_file_as_string(path)) == OK else null
		if not (parsed is Dictionary) or (parsed as Dictionary).is_empty():
			reason = _t("load.reasons.broken", "")
		else:
			var result: Variant = rules.call("load_game", path)
			if result is Dictionary and bool(result.get("ok", false)):
				return true
			reason = str(result.get("reason", "")) if result is Dictionary else ""
			if reason.strip_edges() == "":
				reason = _t("load.reasons.broken", "")
	_notice = _t("load.failed", "%s") % reason
	return false

func _rules_state() -> Dictionary:
	if rules == null:
		return {}
	var state: Variant = rules.get("state")
	return state if state is Dictionary else {}

func _elapsed() -> float:
	return float(_rules_state().get("elapsed", 0.0)) if rules != null else _clock

func _phase() -> String:
	var fallback := _start_phase if _start_phase != "" else "briefing"
	return str(_rules_state().get("phase", fallback))

func _playing() -> bool:
	return rules == null or str(_rules_state().get("status", "playing")) == "playing"

func _advance(dt: float) -> void:
	if rules == null:
		_clock += dt
		return
	rules.call("tick", dt)
	if progress != null and progress.has_method("checkpoint_tick"):
		progress.call("checkpoint_tick", rules)
	_check_end()

## Al terminar la partida se frena el reloj y se dice cómo salió. El parte completo llega en R1.
func _check_end() -> void:
	if rules == null or _ended:
		return
	var status := str(_rules_state().get("status", "playing"))
	if status == "playing":
		return
	_ended = true
	paused = true
	var detail := ""
	var report: Variant = rules.call("campaign_report")
	if report is Dictionary:
		detail = str(report.get("cause", "")) if status == "defeat" else str(report.get("outcome_title", ""))
	var head := _t("result.victory", "") if status == "victory" else _t("result.defeat", "")
	_end_line = "%s%s  ·  %s" % [head, (": " + detail) if detail != "" else "", _t("result.exit", "")]

# ---------------------------------------------------------------------------------------------------------------------
# Cuadro a cuadro

func _process(delta: float) -> void:
	if main == null:
		return
	if not paused and _playing():
		_advance(minf(delta, MAX_FRAME_DT) * speed)
	if is_instance_valid(view) and view.has_method("update_state"):
		view.call("update_state", delta)
	_apply_camera()
	_hud_timer -= delta
	if _hud_timer <= 0.0:
		_refresh_hud()

func _unhandled_input(event: InputEvent) -> void:
	if main == null or not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			exited.emit("menu")
			return
		KEY_SPACE:
			paused = not paused
		KEY_F2:
			speed = U.SPEEDS[0]
		KEY_F3:
			speed = U.SPEEDS[1]
		KEY_F4:
			speed = U.SPEEDS[2]
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			_shift_speed(1)
		KEY_MINUS, KEY_KP_SUBTRACT:
			_shift_speed(-1)
		_:
			return
	get_viewport().set_input_as_handled()
	_refresh_hud(true)

func _shift_speed(direction: int) -> void:
	var index := clampi(U.SPEEDS.find(speed) + direction, 0, U.SPEEDS.size() - 1)
	speed = U.SPEEDS[index]

# ---------------------------------------------------------------------------------------------------------------------
# Cámara mínima: apunta a main.camera al nivel (main la mueve con la del menú en cada cuadro; este nodo corre después por ser su hijo)

func _apply_initial_camera() -> void:
	if not is_instance_valid(view) or not is_instance_valid(main.camera) or not view.has_method("initial_frame"):
		return
	var frame: Variant = view.call("initial_frame", main.camera)
	if frame is Dictionary and frame.get("target", null) is Vector3:
		var focus: Vector3 = frame.target
		_cam.target = Vector2(focus.x, focus.z)
		_cam.dist = float(frame.get("distance", _cam.dist))
		_cam.pitch_deg = clampf(float(frame.get("pitch_deg", _cam.pitch_deg)), 5.0, 89.0)
		_cam.yaw_deg = float(frame.get("yaw_deg", _cam.yaw_deg))

func _apply_camera() -> void:
	if main == null or not is_instance_valid(main.camera):
		return
	var focus: Vector2 = _cam.target
	var ground := float(rules.call("terrain_height_at", focus.x, focus.y)) if rules != null and rules.has_method("terrain_height_at") else 0.0
	var pitch := deg_to_rad(float(_cam.pitch_deg))
	var yaw := deg_to_rad(float(_cam.yaw_deg))
	var center := Vector3(focus.x, ground, focus.y)
	var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * float(_cam.dist)
	main.camera.position = center + offset
	main.camera.look_at(center)

# ---------------------------------------------------------------------------------------------------------------------
# Interfaz mínima: una cabecera, el objetivo, el siguiente paso y, si hace falta, la línea roja

func _t(path: String, fallback: String = "") -> String:
	var cur: Variant = _texts
	for part in path.split("."):
		if cur is Dictionary and (cur as Dictionary).has(part):
			cur = cur[part]
		else:
			return fallback
	return str(cur) if typeof(cur) == TYPE_STRING else fallback

func _build_hud() -> void:
	if not is_instance_valid(main.ui):
		return
	_hud = VBoxContainer.new()
	_hud.name = "HumahuacaHud"
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.anchor_right = 1.0
	_hud.offset_left = 14.0
	_hud.offset_top = 10.0
	_hud.offset_right = -14.0
	_hud.offset_bottom = 10.0
	_hud.add_theme_constant_override("separation", 6)
	main.ui.add_child(_hud)
	var bar := _make_panel(PANEL_BG, PANEL_BORDER)
	_hud.add_child(bar)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	bar.add_child(column)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", 16)
	column.add_child(head)
	_title = _make_label(head, 17, PAPER)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if main.title_font != null:
		_title.add_theme_font_override("font", main.title_font)
	_clock_label = _make_label(head, 16, GOLD)
	_clock_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_objective = _make_label(column, 16, PAPER)
	_next = _make_label(column, 16, GOLD)
	_warn_panel = _make_panel(WARN_BG, WARN_BORDER)
	_hud.add_child(_warn_panel)
	_warn = _make_label(_warn_panel, 15, WARN_TEXT)

func _make_panel(background: Color, border: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _make_label(parent: Node, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _refresh_hud(_force_now: bool = false) -> void:
	_hud_timer = HUD_PERIOD
	if main == null or not is_instance_valid(_hud):
		return
	_hud_data = {}
	if rules != null:
		var state: Variant = rules.call("hud_state")
		if state is Dictionary:
			_hud_data = state
	var phase_info: Dictionary = _dict(_hud_data.get("fase"))
	var phase_name := str(phase_info.get("nombre", ""))
	if phase_name == "":
		phase_name = _t("phase_names." + _phase(), "")
	var clock_text := str(phase_info.get("reloj", ""))
	if clock_text == "":
		clock_text = _mmss(_elapsed())
	_title.text = "%s  ·  %s  ·  %s" % [_t("title", FALLBACK_TITLE), phase_name, clock_text]
	var pattern := _t("clock_running", FALLBACK_RUNNING)
	var indicator := _t("clock_paused", FALLBACK_PAUSED) if paused else (pattern % int(speed) if pattern.find("%d") >= 0 else pattern)
	_clock_label.text = indicator.to_upper()  # el contrato fija «TIEMPO REAL · ▶ ×1» y «‖ EN PAUSA»; en el JSON van en minúsculas para que ninguna cadena de texto quede entera en mayúsculas
	var next_text := str(_dict(_hud_data.get("siguiente")).get("texto", ""))
	if _ended:
		_objective.text = _end_line
		next_text = ""
	else:
		var goal := str(_hud_data.get("objetivo", ""))
		_objective.text = goal if goal != "" else _t("objective", "")
	_next.text = next_text
	_next.visible = next_text != ""
	_warn.text = _warn_text()
	_warn_panel.visible = _warn.text != ""

static func _dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}

static func _mmss(seconds: float) -> String:
	return "%d:%02d" % [floori(seconds / 60.0), int(seconds) % 60]

## La línea roja: qué capas corren en su versión mínima (o no corren) y por qué no se pudo abrir el guardado.
func _warn_text() -> String:
	var minimal: Array = []
	var absent: Array = []
	for id in U.LAYER_IDS:
		var kind := str(layers.get(id, "real"))
		if kind == "minimo":
			minimal.append(str(id))
		elif kind == "falta":
			absent.append(str(id))
	var lines: Array = []
	if not absent.is_empty():
		lines.append(_t("layers.missing", "%s") % _layer_names(absent))
	if minimal.size() == 1:
		lines.append(_t("layers.one." + str(minimal[0]), ""))
	elif minimal.size() > 1:
		lines.append(_t("layers.many", "%s") % _layer_names(minimal))
	if _notice != "":
		lines.append(_notice)
	return "\n".join(PackedStringArray(lines))

func _layer_names(ids: Array) -> String:
	var names: Array = []
	for id in ids:
		names.append(_t("layers.labels." + str(id), str(id)))
	if names.size() <= 1:
		return "".join(PackedStringArray(names))
	return ", ".join(PackedStringArray(names.slice(0, names.size() - 1))) + " y " + str(names[names.size() - 1])

func _visible_controls() -> int:
	var count := 0
	if is_instance_valid(_hud):
		for control in _hud.find_children("*", "BaseButton", true, false):
			if (control as Control).is_visible_in_tree():
				count += 1
	return count

func _text_chars() -> int:
	var count := 0
	if is_instance_valid(_hud):
		for label in _hud.find_children("*", "Label", true, false):
			if (label as Label).is_visible_in_tree():
				count += str(label.text).length()
	return count

# ---------------------------------------------------------------------------------------------------------------------
# API de QA estable (contrato 3.5): ninguna prueba toca atributos privados de main ni del controlador

func qa_state() -> Dictionary:
	_refresh_hud(true)
	var alerts: Array = []
	var alert_list: Variant = _hud_data.get("alertas", [])
	if alert_list is Array:
		for entry in alert_list:
			if entry is Dictionary:
				alerts.append({"id": str(entry.get("id", "")), "nivel": str(entry.get("nivel", "info"))})
	var fronts := {"bateria": "guardado", "cuartel": "guardado", "posta": "guardado"}
	var front_list: Variant = _hud_data.get("frentes", [])
	if front_list is Array:
		for entry in front_list:
			if entry is Dictionary and fronts.has(str(entry.get("id", ""))):
				fronts[str(entry.id)] = str(entry.get("estado", "guardado"))
	var focus: Vector2 = _cam.target
	return {"phase": _phase(), "elapsed": _elapsed(), "paused": paused, "speed": speed, "selected": [],
		"camera": {"target": [focus.x, focus.y], "dist": float(_cam.dist), "pitch_deg": float(_cam.pitch_deg), "yaw_deg": float(_cam.yaw_deg)},
		"visible_controls": _visible_controls(), "text_chars": _text_chars(), "alerts": alerts, "front_states": fronts,
		"status": str(_rules_state().get("status", "playing")), "layers": layers.duplicate()}

func qa_set_camera(target: Vector2, dist: float, pitch_deg: float, yaw_deg: float) -> void:
	_cam = {"target": target, "dist": clampf(dist, 5.0, 3000.0), "pitch_deg": clampf(pitch_deg, 5.0, 89.0), "yaw_deg": yaw_deg}
	_apply_camera()

## Fija el reloj de juego. Las reglas no retroceden: si piden un tiempo anterior, se empieza el intento de nuevo y se avanza hasta ahí.
func qa_set_time(t: float) -> void:
	var target_time := maxf(t, 0.0)
	if rules == null:
		_clock = target_time
		return
	if target_time < _elapsed() - 0.001:
		_new_attempt()
	if target_time > _elapsed() and rules.has_method("advance_to"):
		rules.call("advance_to", target_time)
	_check_end()
	_refresh_hud(true)

## Avanza `seconds` de juego a ×1 y vuelve a pausar. Se detiene si termina la partida o si queda una decisión sin resolver.
func qa_step(seconds: float) -> void:
	var left := minf(maxf(seconds, 0.0), MAX_STEP_S)
	if rules == null:
		_clock += left
	else:
		while left > 0.0 and _playing() and not _decision_pending():
			var dt := minf(left, 1.0)
			rules.call("tick", dt)
			left -= dt
		if progress != null and progress.has_method("checkpoint_tick"):
			progress.call("checkpoint_tick", rules)
		_check_end()
	paused = true
	if is_instance_valid(view) and view.has_method("update_state"):
		view.call("update_state", 0.0)
	_refresh_hud(true)

func _decision_pending() -> bool:
	var pending: Variant = rules.call("pending_choice")
	return pending is Dictionary and not (pending as Dictionary).is_empty()

## Una captura y un qa_report.json en main.qa_path. Las 7 vistas canónicas (con y sin interfaz) llegan en R1; por ahora `views` va vacío.
func qa_run() -> void:
	var dir := str(main.qa_path) if main != null else ""
	if dir.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(dir)
	_refresh_hud(true)
	await RenderingServer.frame_post_draw
	if main == null:
		return
	var image: Image = main.get_viewport().get_texture().get_image()
	if image != null and not image.is_empty():
		image.save_png(dir.path_join("humahuaca-inicio.png"))
	var report := FileAccess.open(dir.path_join("qa_report.json"), FileAccess.WRITE)
	if report:
		report.store_string(JSON.stringify({"controlador": "r1.0", "capas": layers, "views": [], "state": qa_state()}, "\t"))
		report.close()

## Deja el nivel en pleno ataque (las reglas empiezan en esa fase) y corriendo, para medir el cuadro con lluvia, fichas y efectos.
func benchmark_prepare() -> void:
	if main == null:
		return
	_start_phase = "ataque"
	_skip_intro = true
	_new_attempt()
	paused = false
	speed = U.SPEEDS[0]
	_refresh_hud(true)
