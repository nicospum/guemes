extends Node
## Controlador de «humahuaca», parte 1 de 3 (CONTRATO 3.5 y 7): estado, constantes, capas con respaldo, interfaz, partida, textos y cámara. Hijo de `main`: arma el nivel con la clase real de cada capa (terreno, reglas, progreso y vista) o, si
## falta o no parsea, con su versión mínima de stubs/ (carga con respaldo; start(opts.force_stub) fuerza el reemplazo) y avisa con una línea roja qué capa
## corre en respaldo. Reparte el trabajo en archivos por responsabilidad (todos en ui/): humahuaca_hud.gd (lo que se ve fijo: cabecera, frentes, dock),
## humahuaca_overlay.gd (rutas, flecha y rótulos sobre el mundo), humahuaca_minimap.gd, humahuaca_dialogs.gd (briefing, pausa, ayuda, decisión, parte),
## humahuaca_orders.gd (barra de acciones, modo apuntado, clic derecho), humahuaca_camera.gd y humahuaca_ui_kit.gd. Este archivo es el director: el
## reloj, la entrada, la selección, los eventos y la API de QA. Dependencia solo hacia abajo (V19): importa vocabularios y archivos hermanos; las capas
## se cargan con load() diferido por rutas en constantes, nunca con preload.
## Reglas del controlador: el HUD solo pinta hud_state(); la velocidad nunca cambia sola (el ×2 se sugiere); la pausa automática es corta (≤ 2 s) salvo las
## decisiones (≤ 25 s); las teclas propias se marcan como manejadas; stop() es idempotente y restaura lo que main tenía; se libera con queue_free().

signal exited(to: String)  # "menu" | "norte"

const V = preload("res://scripts/humahuaca/humahuaca_vocab.gd")
const R = preload("res://scripts/humahuaca/rules/vocab_rules.gd")
const W = preload("res://scripts/humahuaca/view/vocab_view.gd")
const U = preload("res://scripts/humahuaca/ui/vocab_ui.gd")
const Kit = preload("res://scripts/humahuaca/ui/humahuaca_ui_kit.gd")
const Cam = preload("res://scripts/humahuaca/ui/humahuaca_camera.gd")
const Hud = preload("res://scripts/humahuaca/ui/humahuaca_hud.gd")
const Overlay = preload("res://scripts/humahuaca/ui/humahuaca_overlay.gd")
const Minimap = preload("res://scripts/humahuaca/ui/humahuaca_minimap.gd")
const Dialogs = preload("res://scripts/humahuaca/ui/humahuaca_dialogs.gd")
const Orders = preload("res://scripts/humahuaca/ui/humahuaca_orders.gd")

## Por capa: [clase real, versión mínima]. Son cadenas sueltas (no load literal) para que un archivo ausente no rompa el grafo de dependencias.
const LAYER_PATHS := {
	"terrain": ["res://scripts/humahuaca/terrain/humahuaca_terrain.gd", "res://scripts/humahuaca/stubs/stub_terrain.gd"],
	"rules": ["res://scripts/humahuaca/rules/humahuaca_rules.gd", "res://scripts/humahuaca/stubs/stub_rules.gd"],
	"progress": ["res://scripts/humahuaca/rules/humahuaca_progress.gd", "res://scripts/humahuaca/stubs/stub_progress.gd"],
	"view": ["res://scripts/humahuaca/view/humahuaca_view.gd", "res://scripts/humahuaca/stubs/stub_view.gd"]}

const DEFAULT_SEED := 1817
const MAX_FRAME_DT := 0.25  # un cuadro lento no avanza más que esto (antes de multiplicar por la velocidad)
const MAX_STEP_S := 3600.0  # tope de qa_step: una llamada no puede colgar la herramienta
const END_DELAY_S := 1.2  # lo que se ve la última escena antes del parte
const CLICK_PX := 6.0  # menos que esto entre apretar y soltar es un clic; más, una caja
const FALLBACK_TITLE := "Humahuaca"

# --- estado público (lo leen las pruebas, las herramientas y los módulos hermanos) ---
var main: Node
var rules: RefCounted  # reglas (la clase real o su versión mínima); null si no hay ninguna de las dos
var progress: RefCounted
var view: Node3D  # la vista; null si no hay ninguna o no hay reglas que dibujar
var paused := true
var speed := 1.0
var layers: Dictionary = {}  # id de capa → "real" | "minimo" | "falta"
var mode := "briefing"  # U.MODES
var selected: Array = []
var guide: Dictionary = {}
var texts: Dictionary = {}
var ui_data: Dictionary = {}
var source_tags: Dictionary = {}
var group_fronts: Dictionary = {}
var title_font: Font = null
var ui_scale := 1.0  # cuánto se agranda la interfaz propia en ventanas menores que la base (1,0 si no hace falta)
var orders: Orders
var cam: Cam
var hud: Hud
var overlay: Overlay
var minimap: Minimap
var dialogs: Dialogs
var box_rect := Rect2()
var hide_world_overlay := false
var edge_pan := true
var retry_ms := -1
var first_order_s := -1.0
var order_count := 0

var _opts: Dictionary = {}
var _cli: Dictionary = {}
var _force: Array = []
var _scripts: Dictionary = {}
var _seed := DEFAULT_SEED
var _attempt := 1
var _start_phase := ""
var _skip_intro := false
var _clock := 0.0  # reloj propio: solo cuenta cuando no hay reglas
var _saved: Dictionary = {}
var _fitted := false
var _hs: Dictionary = {}
var _rs: Dictionary = {}
var _rs_frame := -100000
var _hud_timer := 0.0
var _notice := ""
var _ended := false
var _end_delay := 0.0
var _rec: Dictionary = {}
var _auto_start := true
var _view_thread_path := ""  ## Q-205: el script de la vista que se está cargando en un hilo ("" si ninguno)
var _attempt_pending := false  ## Q-208: el intento de esta entrada desde el menú todavía no se contó (nadie dio una orden)
var _auto_resume := 0.0
var _paused_before_dialog := true
var _confirm_back := ""  # a dónde vuelve «No» de una confirmación: "" al menú de pausa (retirada) o "juego" (destruir sin que lo pida el siguiente paso)
var _dialog_back := ""  # a qué ventana vuelve «Cerrar» en el diario y la ayuda: "pausa" si se abrieron desde el menú de pausa (si no, al juego; en el parte, siempre al parte)
var _decision_left := 0.0
var _decision_id := ""
var _keys_down: Dictionary = {}
var _key_map: Dictionary = {}
var _key_rows: Array = []
var _mouse_pos := Vector2.ZERO
var _yaw_override := -1.0  # solo QA: rumbo de la mirada del cuadro inicial mientras la vista no traiga 325° (A-11)
var _mouse_seen := false  # el borde de la pantalla solo mueve la cámara después de ver el mouse dentro de la ventana
var _press_pos := Vector2.ZERO
var _press_unit := ""
var _pressing := false
var _middle_drag := false
var _motive_text := ""
var _motive_until := 0.0
var _hover_motive := ""
var _toast_cur: Dictionary = {}
var _toast_queue: Array = []
var _shake := 0.0
var _calm_s := 0.0
var _idle_first_s := 0.0  # segundos reales con el nivel en pausa y sin ninguna orden dada (onboarding.first_order_hint_s)
var _idle_first_done := false
var _suggest_x2 := false
var _suggest_toast_real := -999.0  # cuándo se avisó por última vez «podés acelerar con ×2» (reloj real)
var _last_alarm_real := -999.0  # cuándo llegó el último aviso importante de las reglas (reloj real)
var _saved_by_player := false
var _alert_seen: Dictionary = {}
var _info_alert_seen: Dictionary = {}
var _subtitle: Label = null
var _skip_hint: Label = null
var _modal_layer: Control = null
var _size_cb: Callable = Callable()
var _load_reason := ""  # el motivo de la última carga fallida, como fragmento de frase (para el aviso de F9 en plena partida)
var _world_seen := -1  # el mundo del progreso (world_seed) cuando se fijó _seed: si cambia (victoria o «Mundo nuevo»), el reintento toma el mundo nuevo
var _checkpoint_path := ""  # el archivo de los puntos de control que usa el progreso (normal o de QA)
var _backdrop: Control = null  # el fondo de pantalla completa del briefing y de los partes (tinta y viñeta fuerte)


# ---------------------------------------------------------------------------------------------------------------------
# Arranque y cierre


func _remember_global_state() -> void:
	var vp: Viewport = main.get_viewport()
	_saved = {"scale3d": vp.scaling_3d_scale, "msaa": vp.msaa_3d, "content_scale": main.get_window().content_scale_factor,
		"last_save": str(main.settings.get("last_save", "")), "audio_env": ""}
	if is_instance_valid(main.camera):
		_saved["far"] = main.camera.far
		_saved["fov"] = main.camera.fov
	if is_instance_valid(main.audio_manager):
		var env: Variant = main.audio_manager.get("_scenario")
		_saved["audio_env"] = str(env) if env != null else ""


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


## Las banderas del contrato 4.3 (--hx-seed=N, --hx-phase=<fase>, --hx-skip-intro) a partir de una lista de argumentos.
static func parse_flags(args: Array) -> Dictionary:
	var out := {}
	for arg in args:
		var text := str(arg)
		if text.begins_with("--hx-seed="):
			out["seed"] = int(text.trim_prefix("--hx-seed="))
		elif text.begins_with("--hx-phase="):
			out["phase"] = text.trim_prefix("--hx-phase=")
		elif text == "--hx-skip-intro":
			out["skip_intro"] = true
	return out


static func _cli_flags() -> Dictionary:
	return parse_flags(OS.get_cmdline_user_args())


func _read_json() -> void:
	ui_data = V.load_json(V.UI_PATH)
	var t: Variant = ui_data.get("texts", {})
	texts = t if t is Dictionary else {}
	var st: Variant = ui_data.get("source_tags", {})
	source_tags = st if st is Dictionary else {}
	_key_rows = []
	var rows: Variant = ui_data.get("key_table", [])
	if rows is Array:
		for r in rows:
			if r is Dictionary:
				_key_rows.append(r)
	_build_key_map()
	if main != null:
		title_font = main.title_font


# ---------------------------------------------------------------------------------------------------------------------
# Textos y datos para los módulos hermanos

func tx(path: String, fallback: String = "") -> String:
	var cur: Variant = texts
	for part in path.split("."):
		if cur is Dictionary and (cur as Dictionary).has(part):
			cur = cur[part]
		else:
			return fallback
	return str(cur) if typeof(cur) == TYPE_STRING else fallback


func _ui_num(section: String, key: String, fallback: float) -> float:
	var s: Variant = ui_data.get(section, {})
	if s is Dictionary and (s as Dictionary).has(key):
		var v: Variant = (s as Dictionary)[key]
		if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
			return float(v)
	return fallback


func layout_num(path: Array, fallback: float) -> float:
	var cur: Variant = ui_data.get("layout", {})
	for part in path:
		if cur is Dictionary and (cur as Dictionary).has(part):
			cur = cur[part]
		else:
			return fallback
	return float(cur) if (typeof(cur) == TYPE_INT or typeof(cur) == TYPE_FLOAT) else fallback


func margin() -> float:
	return layout_num(["margin"], 12.0)


func key_rows() -> Array:
	return _key_rows


func key_label_for(action: String) -> String:
	for row in _key_rows:
		if str((row as Dictionary).get("action", "")) == action:
			return str((row as Dictionary).get("show", ""))
	return ""


func font() -> Font:
	if main != null and main.theme_main != null and main.theme_main.default_font != null:
		return main.theme_main.default_font
	return ThemeDB.fallback_font


func camera3d() -> Camera3D:
	return main.camera if main != null and is_instance_valid(main.camera) else null


## Cuántos píxeles reales mide una unidad local de la interfaz (la escala de la ventana por la de la interfaz): sirve para dimensionar lo que se dibuja sobre el mundo.
func screen_scale() -> float:
	if main == null:
		return 1.0
	return main.get_viewport().get_final_transform().get_scale().x * ui_scale


func camera_yaw_deg() -> float:
	return cam.yaw_deg if cam != null else 0.0


func ground_height(x: float, z: float) -> float:
	return cam.ground_h(x, z) if cam != null else 17.0


## Un punto del mundo (x, z) a las coordenadas locales de la interfaz (las del HUD y las de la capa de dibujo: la interfaz va escalada en ventanas chicas), o null si queda
## detrás de la cámara. `lift` sube el punto sobre el suelo, en metros.
func ui_point(p: Vector2, lift: float = 0.0) -> Variant:
	var cam3 := camera3d()
	if cam3 == null or not cam3.is_inside_tree():
		return null
	var v := Vector3(p.x, ground_height(p.x, p.y) + lift, p.y)
	if cam3.is_position_behind(v):
		return null
	return cam3.unproject_position(v) / maxf(ui_scale, 0.01)


## Lo que ningún aviso debe tapar, en coordenadas locales de la interfaz: cada ficha con su número encima y cada frente con su rótulo.
func avoid_rects() -> Array:
	var out: Array = []
	if rules == null:
		return out
	# visual/r1 F1: las fichas van a escala real; lo que no hay que tapar es su marca chica, su rótulo de una línea y la figura (lo mide la capa de dibujo)
	if is_instance_valid(overlay):
		for m in overlay.token_marks():
			out.append(((m.body as Rect2).merge(m.label_rect as Rect2)).grow(6.0))
	for fid in V.OBJECTIVES:
		var fp: Variant = ui_point(landmark_pos(str(fid)), 9.0)
		if fp is Vector2:
			out.append(Rect2((fp as Vector2) + Vector2(-46.0, -22.0), Vector2(100.0, 72.0)))
	return out


## El texto que cuentan las reglas sobre el nivel (briefing, objetivo, notas), tal como está en humahuaca_rules.json: la FUENTE ÚNICA del briefing. La interfaz no guarda
## copias de esas frases (antes tenía dos de respaldo): si las reglas no las traen, la tarjeta sale sin ellas y la línea roja dice qué capa falta.
func _rules_texts() -> Dictionary:
	if rules != null and rules.has_method("map_data"):
		var md: Variant = rules.call("map_data")
		if md is Dictionary:
			var t: Variant = (md as Dictionary).get("texts", {})
			if t is Dictionary:
				return t
	return {}


func briefing_data() -> Dictionary:
	var rt := _rules_texts()
	var b: Variant = rt.get("briefing", {})
	var lines: Array = []
	if b is Dictionary and str((b as Dictionary).get("pagina_1", "")) != "":
		for line in str((b as Dictionary).get("pagina_1", "")).split("\n"):
			if line.strip_edges() != "":
				lines.append(line.strip_edges())
	var mundo := ""
	var hs_now: Variant = rules.call("hud_state") if rules != null else {}
	var w: Variant = (hs_now as Dictionary).get("mundo", {}) if hs_now is Dictionary else {}
	if w is Dictionary:
		mundo = str((w as Dictionary).get("linea", ""))
	return {"lines": lines, "carta": (b as Dictionary).get("carta", {}) if b is Dictionary else {},
		"nota_fecha": (b as Dictionary).get("nota_fecha", {}) if b is Dictionary else {},
		"nota_relieve": rt.get("nota_relieve", {}), "nota_refuerzo": rt.get("nota_refuerzo", {}), "mundo": mundo}


func time_note() -> Variant:
	var n: Variant = _rules_texts().get("aclaracion_tiempo", {})
	return n if n is Dictionary and not (n as Dictionary).is_empty() else null


func landmark_pos(id: String) -> Vector2:
	if rules != null and rules.has_method("terrain"):
		var t: Variant = rules.call("terrain")
		if t != null and (t as Object).has_method("landmark"):
			var lm: Variant = t.call("landmark", id)
			if lm is Dictionary and not (lm as Dictionary).is_empty():
				return Vector2(float((lm as Dictionary).get("x", 0.0)), float((lm as Dictionary).get("z", 0.0)))
	return Vector2.ZERO


func front_label(fid: String) -> Dictionary:
	var name_text := fid
	if rules != null:
		var t: Variant = rules.call("terrain")
		if t != null:
			var lm: Variant = t.call("landmark", fid)
			if lm is Dictionary:
				name_text = str((lm as Dictionary).get("short", (lm as Dictionary).get("name", fid)))
	var taken := false
	for f in _hs.get("frentes", []):
		if str((f as Dictionary).get("id", "")) == fid:
			taken = str((f as Dictionary).get("estado", "")) == "tomado"
	return {"text": name_text, "taken": taken}


## render_state() de las reglas, a lo sumo cada 50 ms (la interfaz dibuja a 60 cuadros por segundo; las figuras se mueven despacio): evita armarlo en cada cuadro.
func render_state_cached() -> Dictionary:
	var now := Time.get_ticks_msec()
	if rules != null and (now - _rs_frame >= 50 or _rs.is_empty()):
		var rs: Variant = rules.call("render_state")
		_rs = rs if rs is Dictionary else {}
		_rs_frame = now
	return _rs


func tower_state() -> Dictionary:
	var t: Variant = render_state_cached().get("tower", {})
	return t if t is Dictionary else {}


# ---------------------------------------------------------------------------------------------------------------------
# Capas con respaldo (CONTRATO 7)

func _build_layers() -> void:
	for id in U.LAYER_IDS:
		# Q-205: con la vista diferida detrás del briefing, el script de la vista (≈ 200 ms de compilación la primera vez, con gfx, edificios, fichas y efectos)
		# se carga en un hilo mientras se lee el briefing; ensure_view() lo recoge
		if str(id) == "view" and not _force.has("view") and has_method("_wants_deferred_view") and bool(call("_wants_deferred_view")) \
				and ResourceLoader.load_threaded_request(str(LAYER_PATHS.view[0]), "Script") == OK:
			_view_thread_path = str(LAYER_PATHS.view[0])
			_scripts[id] = null
			layers[id] = "real"
			continue
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
	_checkpoint_path = checkpoint_path
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


## Recoge el script de la vista cargado en un hilo (espera si todavía no terminó); si no sirve, la versión mínima.
func _collect_view_script() -> void:
	if _view_thread_path == "":
		return
	var res: Resource = ResourceLoader.load_threaded_get(_view_thread_path)
	_view_thread_path = ""
	if res is Script and (res as Script).can_instantiate():
		_scripts["view"] = res
		layers["view"] = "real"
	else:
		var picked := _pick_layer("view")
		_scripts["view"] = picked.script
		layers["view"] = picked.kind


func _build_view() -> void:
	_collect_view_script()
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
	if view.has_method("set_layer_visible"):
		view.call("set_layer_visible", "labels", false)  # los números de las fichas los dibuja la interfaz, junto a cada ficha y sin pisar el HUD
	if view.has_method("set_selected_ids"):
		view.call("set_selected_ids", selected)
	if cam != null:
		cam.view = view


func _quality() -> String:
	var wanted := str(main.settings.get("quality", "media"))
	return wanted if W.QUALITY.has(wanted) else "media"


# ---------------------------------------------------------------------------------------------------------------------
# Interfaz

func _build_ui() -> void:
	if not is_instance_valid(main.ui):
		return
	orders = Orders.new()
	orders.setup(self)
	cam = Cam.new()
	var emit_cb := Callable(self, "_on_hud")
	hud = Hud.new()
	hud.build(main.ui, texts, ui_data.get("layout", {}), source_tags, emit_cb, title_font, minimap_width())
	overlay = Overlay.new()
	overlay.ui = self
	hud.root.add_child(overlay)
	hud.root.move_child(overlay, 0)
	if hud.vignette != null:
		hud.root.move_child(hud.vignette, 0)  # la viñeta va debajo de todo, también de las rutas y los rótulos sobre el mundo
	minimap = Minimap.new()
	hud.root.add_child(minimap)
	minimap.setup(self, ui_data.get("minimap", {}), font())
	_modal_layer = Control.new()
	_modal_layer.name = "HxModalLayer"
	_modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.ui.add_child(_modal_layer)
	_subtitle = Label.new()
	_subtitle.name = "HxSubtitle"
	_subtitle.add_theme_font_size_override("font_size", 20)
	_subtitle.add_theme_color_override("font_color", Kit.PAPER)
	_subtitle.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.02, 1.0))
	_subtitle.add_theme_constant_override("outline_size", 6)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle.anchor_left = 0.1
	_subtitle.anchor_right = 0.9
	_subtitle.anchor_top = 1.0
	_subtitle.anchor_bottom = 1.0
	_subtitle.offset_top = -120.0
	_subtitle.offset_bottom = -70.0
	_subtitle.visible = false
	_modal_layer.add_child(_subtitle)
	_skip_hint = Label.new()
	_skip_hint.name = "HxSkipHint"
	_skip_hint.add_theme_font_size_override("font_size", 16)
	_skip_hint.add_theme_color_override("font_color", Kit.PAPER)
	_skip_hint.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.02, 1.0))
	_skip_hint.add_theme_constant_override("outline_size", 5)
	_skip_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skip_hint.anchor_left = 1.0
	_skip_hint.anchor_right = 1.0
	_skip_hint.anchor_top = 1.0
	_skip_hint.anchor_bottom = 1.0
	_skip_hint.offset_left = -360.0
	_skip_hint.offset_right = -16.0
	_skip_hint.offset_top = -40.0
	_skip_hint.offset_bottom = -14.0
	_skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_skip_hint.visible = false
	_modal_layer.add_child(_skip_hint)
	dialogs = Dialogs.new()
	dialogs.setup(self, _modal_layer, Callable(self, "_on_dialog"))
	var win: Window = main.get_window()
	_size_cb = Callable(self, "_fit_scale")
	if not win.size_changed.is_connected(_size_cb):
		win.size_changed.connect(_size_cb)


func minimap_width() -> float:
	var v: Variant = ui_data.get("minimap", {}).get("default_size_px", [260, 188])
	return float((v as Array)[0]) if v is Array and (v as Array).size() >= 2 else 260.0


## En ventanas menores que la base de 1440 × 900 la interfaz no se encoge por debajo de 1:1 (a 720p el texto quedaba en ≈ 13 px). main.gd ya usa el factor de
## contenido de la ventana para la Justina y lo vuelve a 1,0 cada vez que cambia el tamaño, así que acá se escalan las raíces de la propia interfaz
## (el HUD y las ventanas): su tamaño es el del cuadro dividido por la escala. No se toca nada de main.
func _fit_scale() -> void:
	if main == null or not is_instance_valid(main):
		return
	var win: Window = main.get_window()
	var f := 1.0
	var enabled := true
	var fit: Variant = ui_data.get("layout", {}).get("fit_scale", {})
	if fit is Dictionary:
		enabled = bool((fit as Dictionary).get("enabled", true))
	if enabled:
		var base := Vector2(win.content_scale_size)
		if base.x <= 0.0 or base.y <= 0.0:
			base = Vector2(1440.0, 900.0)
		var s0 := minf(float(win.size.x) / base.x, float(win.size.y) / base.y)
		if s0 > 0.0 and s0 < 1.0:
			f = 1.0 / s0
	ui_scale = f
	_apply_ui_scale()


func _apply_ui_scale() -> void:
	if main == null or not is_instance_valid(main):
		return
	var logical := main.get_viewport().get_visible_rect().size
	var roots: Array = [_modal_layer]
	if hud != null:
		roots.append(hud.root)
	for n in roots:
		if n != null and is_instance_valid(n):
			var c := n as Control
			c.set_anchors_preset(Control.PRESET_TOP_LEFT)
			c.position = Vector2.ZERO
			c.size = logical / ui_scale
			c.scale = Vector2(ui_scale, ui_scale)


# ---------------------------------------------------------------------------------------------------------------------
# Partida

func _begin_game() -> void:
	_seed = _pick_seed()
	_attempt = int(_opts.get("attempt", 0))
	if _attempt <= 0:
		var done: Variant = progress.get("attempts") if progress != null else null
		_attempt = 1 + (int(done) if typeof(done) == TYPE_INT or typeof(done) == TYPE_FLOAT else 0)
	_find_group_fronts()
	if bool(_opts.get("load", false)) and _try_load_save():
		_auto_start = false
		return
	# Q-208: el intento de una entrada desde el menú se prepara (diario a las reglas) pero se cuenta recién con la primera orden o al terminar la partida
	_new_attempt({}, false, false)
	if progress != null and progress.has_method("commit_attempt"):
		progress.call("begin_attempt", rules, false)
		_attempt_pending = true
	elif progress != null and progress.has_method("begin_attempt"):
		progress.call("begin_attempt", rules)


## Cuenta el intento preparado si todavía no se contó (primera orden o final de la partida).
func commit_attempt() -> void:
	if _attempt_pending and progress != null and progress.has_method("commit_attempt"):
		progress.call("commit_attempt")
	_attempt_pending = false


func _find_group_fronts() -> void:
	group_fronts = {}
	if rules == null:
		return
	var md: Variant = rules.call("map_data")
	var g: Variant = (md as Dictionary).get("groups", {}) if md is Dictionary else {}
	for id in V.GROUPS:
		var front := ""
		if g is Dictionary and (g as Dictionary).has(id):
			front = str(((g as Dictionary)[id] as Dictionary).get("front", ""))
		group_fronts[id] = front
		var short := str(((g as Dictionary)[id] as Dictionary).get("short", "")) if g is Dictionary and (g as Dictionary).has(id) else ""
		if short != "" and hud != null:
			hud.short_by_id[id] = short


func _pick_seed() -> int:
	_world_seen = _progress_world()
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
func _new_attempt(extra: Dictionary = {}, count_attempt: bool = false, rebuild_view: bool = true) -> void:
	clear_transients()
	_ended = false
	_end_delay = 0.0
	_rec = {}
	_clock = 0.0
	_auto_start = true
	order_count = 0
	first_order_s = -1.0
	_alert_seen = {}
	_info_alert_seen = {}
	_toast_cur = {}
	_toast_queue = []
	_calm_s = 0.0
	_idle_first_s = 0.0
	_idle_first_done = false
	_suggest_x2 = false
	selected = []
	if orders != null:
		orders.cancel_aim()
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
		_attempt_pending = false
		progress.call("begin_attempt", rules)
	if _start_phase != "" or bool(new_opts.get("skip_intro", false)) and new_opts.has("phase"):
		_auto_start = false
	if rebuild_view and _scripts.get("view") != null:
		_build_view()
	_find_group_fronts()


## Lo pasajero de la interfaz que no debe sobrevivir a empezar un intento ni a recuperar una partida (B-046 b): el motivo de la última orden rechazada, el que
## muestra el cartel de un botón, la orden en la mano y las paradas sueltas.
func clear_transients() -> void:
	_motive_text = ""
	_motive_until = 0.0
	_hover_motive = ""
	if orders != null:
		orders.cancel_aim()
		orders.waypoints = []
		orders.motive = ""
		orders.last_error = ""


## Un motivo de rechazo tal como lo dicen las reglas (texts.errores.<clave>), o «» si no lo traen.
func rules_error(key: String) -> String:
	var e: Variant = _rules_texts().get("errores", {})
	return str((e as Dictionary).get(key, "")) if e is Dictionary else ""


func _progress_world() -> int:
	if progress != null and progress.has_method("world_seed"):
		var w: Variant = progress.call("world_seed")
		if typeof(w) == TYPE_INT or typeof(w) == TYPE_FLOAT:
			return int(w)
	return -1


## «Continuar» y F9 llegan con opts.load. Si el guardado falta, está dañado o las reglas lo rechazan, se explica y se empieza de cero.
## Revisión B-2: un guardado de una partida ya terminada (estado victoria o derrota) se rechaza con su motivo y la partida que había queda como estaba.
## Revisión B-3 y E-8: tras una carga buena, la semilla del controlador es la del guardado (así «Empezar de nuevo (mismo mundo)» repite ese mundo) y el contador de
## órdenes cuenta las del guardado (Esc ya no sale al menú sin preguntar como si no hubiera nada que perder).
func _try_load_save() -> bool:
	var reason := ""
	var path := str(main._save_path(V.SCENARIO))
	if rules == null:
		reason = tx("load.reasons.no_rules", "")
	elif not FileAccess.file_exists(path):
		reason = tx("load.reasons.missing", "")
	else:
		var parser := JSON.new()  # parse() devuelve un código de error; parse_string() imprime un ERROR en la consola si el archivo está dañado
		var parsed: Variant = parser.data if parser.parse(FileAccess.get_file_as_string(path)) == OK else null
		if not (parsed is Dictionary) or (parsed as Dictionary).is_empty():
			reason = tx("load.reasons.broken", "")
		else:
			var before: Dictionary = (rules.call("snapshot") as Dictionary) if rules.has_method("snapshot") and not _rules_state().is_empty() else {}
			var result: Variant = rules.call("load_game", path)
			if result is Dictionary and bool(result.get("ok", false)):
				if str(_rules_state().get("status", "playing")) != "playing":
					reason = tx("load.reasons.finished", "esa partida ya había terminado")
					if not before.is_empty() and rules.has_method("restore_snapshot"):
						rules.call("restore_snapshot", before)
				else:
					_ended = false
					var st := _rules_state()
					_seed = int(st.get("seed", _seed))
					_world_seen = _progress_world()
					order_count = (st.get("orders", []) as Array).size() if st.get("orders", []) is Array else 0
					_load_reason = ""
					return true
			else:
				reason = str(result.get("reason", "")) if result is Dictionary else ""
			if reason.strip_edges() == "":
				reason = tx("load.reasons.broken", "")
	_load_reason = _reason_fragment(reason)
	_notice = tx("load.failed", "%s") % _load_reason
	return false


## El motivo de una carga fallida para meterlo en una frase (B-046 a): sin el punto final que ya trae («Este guardado es de otro escenario.») y con la primera
## letra en minúscula, salvo que sea una sigla.
static func _reason_fragment(reason: String) -> String:
	var t := reason.strip_edges()
	while t.ends_with(".") or t.ends_with(" "):
		t = t.left(t.length() - 1)
	if t.length() > 1 and t[0] != t[0].to_lower() and t[1] == t[1].to_lower():
		t = t[0].to_lower() + t.substr(1)
	return t


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


func _setup_camera() -> void:
	if cam == null:
		return
	cam.setup(ui_data.get("camera", {}), rules, view)
	cam.ground_from_screen = Callable(self, "ground_from_screen")
	var frame := initial_pose()
	cam.set_frame(frame.target, frame.dist, frame.pitch_deg, frame.yaw_deg)
	apply_camera()


## El cuadro inicial que dice la vista (incluye los tres objetivos y la zona de partida); si no hay vista, uno de respaldo.
func initial_frame() -> Dictionary:
	var out := {"target": Vector2(350.0, 470.0), "dist": 470.0, "pitch_deg": 52.0, "yaw_deg": 325.0, "fits": true}
	if is_instance_valid(view) and view.has_method("initial_frame") and is_instance_valid(main.camera):
		var f: Variant = view.call("initial_frame", main.camera)
		if f is Dictionary and (f as Dictionary).get("target", null) is Vector3:
			var t: Vector3 = (f as Dictionary).target
			out = {"target": Vector2(t.x, t.z), "dist": float((f as Dictionary).get("distance", 470.0)), "pitch_deg": float((f as Dictionary).get("pitch_deg", 52.0)),
				"yaw_deg": float((f as Dictionary).get("yaw_deg", 325.0)), "fits": bool((f as Dictionary).get("fits", true))}
	if _yaw_override >= 0.0:
		out["yaw_deg"] = _yaw_override
	return out


## El cuadro inicial tal como lo muestra la interfaz: la vista sugiere el cuadro (initial_frame, con `fits` para V02) y la cámara decide el encuadre con su política
## (humahuaca_camera.fit_initial, data/humahuaca_camera.json): lo más cerca que se puede con los puntos «duros» del preset activo (los tres objetivos y la zona de
## partida) dentro del cuadro y de la banda que dejan libre la cabecera y el dock, y las cinco partidas si cuesta poco. El ajuste vivía acá (B-015, B-021: las cinco
## partidas a 6 % del costado, que dejaba la cámara a 489 m); desde el pedido del usuario del 2-11-2026 («la cámara está demasiado lejos») lo hace la cámara y se mide
## en tests/test_hx_camera.gd (docs/humahuaca/CAMARA.md).
func initial_pose(yaw_override: float = -1.0) -> Dictionary:
	var f := initial_frame()
	if yaw_override >= 0.0:
		f["yaw_deg"] = yaw_override
	if main == null or not is_instance_valid(main.camera) or not main.camera.is_inside_tree() or rules == null or cam == null:
		return f
	var margin_px := float(layout_num(["margin"], 12.0))
	var hud := {"top_px": (margin_px + layout_num(["header_h"], 46.0)) * ui_scale, "bottom_px": (margin_px + layout_num(["dock_h"], 136.0)) * ui_scale, "ui_scale": ui_scale}
	return cam.fit_initial(main.camera, f, hud)


## Ubica main.camera (VP-07: el rumbo es el de la mirada). Se llama ANTES de view.update_state (VP-08).
func apply_camera() -> void:
	if cam == null or main == null or not is_instance_valid(main.camera):
		return
	cam.apply(main.camera)
	if _shake > 0.001:
		var s := _shake
		main.camera.position += Vector3(sin(_clock_real() * 61.0), sin(_clock_real() * 47.0 + 1.3), sin(_clock_real() * 53.0 + 2.1)) * s * 1.2


func _clock_real() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


func screen_to_ground(pos: Vector2) -> Variant:
	return ground_from_screen(pos)


func ground_from_screen(a: Variant, b: Variant = null) -> Variant:
	var camera: Camera3D = camera3d()
	var pos: Vector2 = Vector2.ZERO
	if a is Camera3D:  # firma de la cámara propia: (cámara, posición)
		camera = a
		pos = b
	else:
		pos = a
	if camera == null or not camera.is_inside_tree():
		return null
	if is_instance_valid(view) and view.has_method("ground_xz_from_screen"):
		var g: Variant = view.call("ground_xz_from_screen", camera, pos)
		if g is Vector2:
			return g
		return null
	var o := camera.project_ray_origin(pos)
	var d := camera.project_ray_normal(pos)
	if absf(d.y) < 0.0001:
		return null
	var t := (17.0 - o.y) / d.y
	if t < 0.0:
		return null
	return Vector2(o.x + d.x * t, o.z + d.z * t)


func pick_front_at(pos: Vector2) -> String:
	var camera: Camera3D = camera3d()
	if camera == null:
		return ""
	if is_instance_valid(view) and view.has_method("pick_front"):
		return str(view.call("pick_front", camera, pos))
	var best := ""
	var best_d := 60.0
	for fid in V.OBJECTIVES:
		var p := landmark_pos(str(fid))
		var v := Vector3(p.x, ground_height(p.x, p.y) + 2.0, p.y)
		if not camera.is_position_behind(v):
			var d := camera.unproject_position(v).distance_to(pos)
			if d < best_d:
				best_d = d
				best = str(fid)
	return best


func pick_unit_at(pos: Vector2) -> String:
	var camera: Camera3D = camera3d()
	if camera != null and is_instance_valid(view) and view.has_method("pick_unit"):
		return str(view.call("pick_unit", camera, pos))
	return ""


func minimap_click(world: Vector2) -> void:
	if cam == null or mode == "opening":
		return
	cam.center_on(world)
	apply_camera()


func center_on_front(fid: String) -> void:
	if cam == null or fid == "":
		return
	cam.center_on(landmark_pos(fid))
	apply_camera()


func reset_camera() -> void:
	if cam == null:
		return
	var f := initial_pose()
	cam.set_frame(f.target, f.dist, f.pitch_deg, f.yaw_deg)
	apply_camera()


# ---------------------------------------------------------------------------------------------------------------------
# Cuadro a cuadro

func _build_key_map() -> void:
	_key_map = {}
	for row in _key_rows:
		if str((row as Dictionary).get("group", "")) == "ordenes":
			continue
		for name_text in (row as Dictionary).get("keys", []):
			var parts := str(name_text).split("+")
			var key_name := parts[parts.size() - 1]
			var code := _keycode(key_name)
			if code == 0:
				continue
			var ctrl := parts.has("Ctrl")
			if not _key_map.has(code):
				_key_map[code] = []
			(_key_map[code] as Array).append({"id": str((row as Dictionary).get("id", "")), "ctrl": ctrl, "action": str((row as Dictionary).get("action", ""))})


static func _keycode(key_name: String) -> int:
	match key_name:
		"KP Add":
			return KEY_KP_ADD
		"KP Subtract":
			return KEY_KP_SUBTRACT
		"Plus":
			return KEY_PLUS
		"Equal":
			return KEY_EQUAL
		"Minus":
			return KEY_MINUS
		"BackSpace":
			return KEY_BACKSPACE
		"Escape":
			return KEY_ESCAPE
		"Delete":
			return KEY_DELETE
	return int(OS.find_keycode_from_string(key_name))
