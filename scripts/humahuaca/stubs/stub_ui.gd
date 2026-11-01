extends Node
## Cáscara del controlador de «humahuaca» (contrato 3.5 y 7), escrita por el integrador en T0. Vive en stubs/stub_ui.gd (el respaldo
## que main.gd carga si el controlador real falta o no parsea) y copiada en ui/humahuaca_ui.gd hasta que ui_feel la reemplace en R1.0.
## Queda congelada (se corrige solo por addendum) y no depende de ningún otro archivo del nivel. Lo que toca de `main` lo restaura en stop().

signal exited(to: String)  # "menu" | "norte"

const PHASE_TEXT := {"briefing": "Preparación", "aproximacion": "Aproximación", "ataque": "Ataque", "extraccion": "Extracción", "epilogo": "Epílogo"}

var main: Node
var paused := true
var speed := 1.0
var elapsed := 0.0
var phase := "briefing"
var _label: Label
var _saved := {"far": 4000.0, "fov": 46.0}
var _cam := {"target": [450.0, 325.0], "dist": 600.0, "pitch_deg": 55.0, "yaw_deg": 0.0}

## opts: {load, qa, attempt, seed, phase, skip_intro, force_stub}. La cáscara no carga partidas ni reemplaza capas.
func start(m: Node, opts: Dictionary = {}) -> void:
	main = m
	phase = str(opts.get("phase", "briefing"))
	if is_instance_valid(main.camera):
		_saved = {"far": main.camera.far, "fov": main.camera.fov}
		main.camera.far = 9000.0
		main.camera.fov = 46.0
	_label = Label.new()
	_label.position = Vector2(20, 14)
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color("e9e3d4"))
	(main.ui if is_instance_valid(main.ui) else self).add_child(_label)
	_refresh()

## Libera lo propio y deja `main` como estaba; main.gd libera este nodo y vuelve al menú o al norte.
func stop() -> void:
	if main != null and is_instance_valid(main.camera):
		main.camera.far = _saved.far
		main.camera.fov = _saved.fov
		main.camera.current = true
	if is_instance_valid(_label):
		_label.queue_free()
	_label = null
	main = null

func _process(delta: float) -> void:
	if main == null:
		return
	if not paused:
		elapsed += delta * speed
	_refresh()

func _refresh() -> void:
	if not is_instance_valid(_label):
		return
	var clock := "%d:%02d" % [floori(elapsed / 60.0), int(elapsed) % 60]
	var time_text := "‖ EN PAUSA" if paused else "TIEMPO REAL · ▶ ×%d" % int(speed)
	_label.text = "Humahuaca (versión mínima)  ·  %s  ·  %s  ·  %s  ·  Espacio: pausa  ·  Esc: menú" % [PHASE_TEXT.get(phase, ""), clock, time_text]

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
			speed = 1.0
		KEY_F3:
			speed = 2.0
		KEY_F4:
			speed = 4.0
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			speed = minf(speed * 2.0, 4.0)
		KEY_MINUS, KEY_KP_SUBTRACT:
			speed = maxf(speed * 0.5, 1.0)
		_:
			return
	get_viewport().set_input_as_handled()

# --- API de QA estable (contrato 3.5): valores válidos y de la forma del contrato ---
func qa_state() -> Dictionary:
	var chars := _label.text.length() if is_instance_valid(_label) else 0
	return {"shell": true, "phase": phase, "elapsed": elapsed, "paused": paused, "speed": speed, "selected": [], "camera": _cam.duplicate(true),
		"visible_controls": 0, "text_chars": chars, "alerts": [], "front_states": {"bateria": "guardado", "cuartel": "guardado", "posta": "guardado"}}

func qa_set_camera(target: Vector2, dist: float, pitch_deg: float, yaw_deg: float) -> void:
	_cam = {"target": [target.x, target.y], "dist": dist, "pitch_deg": pitch_deg, "yaw_deg": yaw_deg}

func qa_set_time(t: float) -> void:
	elapsed = maxf(t, 0.0)

func qa_step(seconds: float) -> void:
	elapsed += maxf(seconds, 0.0)
	paused = true
	_refresh()

## Una captura y un qa_report.json en main.qa_path (la cáscara no tiene las 7 vistas canónicas: `views` va vacío).
func qa_run() -> void:
	var dir := str(main.qa_path) if main != null else ""
	if dir.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(dir)
	var viewport: Viewport = main.get_viewport()
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	if image != null and not image.is_empty():
		image.save_png(dir.path_join("humahuaca-cascara.png"))
	var report := FileAccess.open(dir.path_join("qa_report.json"), FileAccess.WRITE)
	if report:
		report.store_string(JSON.stringify({"shell": true, "views": [], "state": qa_state()}, "\t"))
		report.close()

func benchmark_prepare() -> void:
	pass  # sin escena que preparar: la cáscara no dibuja lluvia, fichas ni efectos
