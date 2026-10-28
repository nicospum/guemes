extends SceneTree
## QA de interfaz con ventana real y entrada inyectada por el Viewport (push_input).
## Uso: godot --path . --resolution 1440x900 --script tools/ui_qa.gd
## No es una partida humana ni una prueba con teclado físico del sistema operativo.

var game: Node
var out_dir := "res://evidence/fase2/interfaz"
var checks := 0
var failures: Array = []
var notes: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame

func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(out_dir).path_join(shot_name + ".png"))

func check(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		failures.append(what)
		push_error(what)

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		root.push_input(e)
		await process_frame

func _move(pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	root.push_input(e)
	await process_frame

func _click(pos: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	await _move(pos)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.position = pos
		e.global_position = pos
		e.button_index = button
		e.pressed = pressed
		e.button_mask = (1 << (button - 1)) if pressed else 0
		root.push_input(e)
		await process_frame

func _button(part: String) -> Button:
	for b in game.find_children("*", "Button", true, false):
		if b is Button and part in b.text and b.is_visible_in_tree():
			return b
	return null

func _free_area() -> Dictionary:
	var img := Image.create(1440, 900, false, Image.FORMAT_L8)
	img.fill(Color.WHITE)
	for r in game._blocked_rects():
		var rr: Rect2 = r.grow(-4.0)
		img.fill_rect(Rect2i(rr).intersection(Rect2i(0, 0, 1440, 900)), Color.BLACK)
	var free := 0
	for v in img.get_data():
		if v > 127:
			free += 1
	return {"free_px": free, "total_px": 1440 * 900, "free_pct": snappedf(100.0 * free / (1440.0 * 900.0), 0.1)}

func _overlaps(rects: Array) -> int:
	var n := 0
	for i in range(rects.size()):
		for j in range(i + 1, rects.size()):
			if (rects[i] as Rect2).intersects(rects[j]):
				n += 1
	return n

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await _frames(20)
	game.jev.force_local = true
	game._start_game("justine")
	await _frames(40)
	await _shot("justine-inicio")
	notes["justine_free_con_ayuda"] = _free_area()
	game.hint_timer = 0.0
	game._update_hud()
	notes["justine_free"] = _free_area()
	game.hint_timer = 18.0
	notes["justine_overlaps_inicio"] = _overlaps(game.last_overlay_rects)
	check(_overlaps(game.last_overlay_rects) == 0, "Justine inicio: etiquetas sin solapamiento")
	await _key(KEY_2)
	check(game.selected == "arias", "Tecla 2 selecciona la segunda agrupacion")
	check(game.select_flash > 0.0, "La seleccion dispara un destello")
	await _frames(6)
	await _shot("justine-seleccion-destello")
	await _frames(40)
	await _shot("justine-seleccion-persistente")
	await _move(Vector2(700, 380))
	await _frames(12)
	notes["hover_water"] = game.hover_info.get("text", "")
	notes["hover_pick"] = str(game.world.pick_ground(game.camera, Vector2(700, 380))) + " mouse=" + str(game.hover_mouse) + " status=" + str(game.rules.state.status)
	await _shot("justine-hover-invalido")
	for candidate in [Vector2(420, 250), Vector2(500, 350), Vector2(560, 300), Vector2(330, 120), Vector2(470, 500), Vector2(600, 520)]:
		await _move(candidate)
		await _frames(12)
		if bool(game.hover_info.get("ok", false)):
			break
	notes["hover_land"] = game.hover_info.get("text", "")
	await _shot("justine-hover-valido")
	var direct := _button("Banco directo")
	check(direct != null, "Boton Banco directo visible")
	if direct:
		await _click(direct.get_global_rect().get_center())
	check(game.rules.get_unit("arias").order.get("action", "") == "direct", "Click real en Banco directo ordena a la agrupacion elegida")
	await _frames(20)
	await _shot("justine-orden-ruta")
	await _key(KEY_4)
	check(game.selected == "all", "Tecla 4 selecciona todas")
	var flank := _button("Rodeo sur")
	await _click(flank.get_global_rect().get_center())
	await _frames(20)
	await _shot("justine-todas-rodeo")
	var board := _button("Abordar")
	check(board != null and board.disabled, "Abordar esta bloqueado con el agua alta")
	notes["justine_reason_text"] = game.reason_label.text
	var rally := _button("Reagrupar")
	await _click(rally.get_global_rect().get_center())
	check(game.confirm_action == "rally", "Reagrupar pide confirmacion")
	var n_orders: int = game.rules.state.orders.size()
	await _frames(2)
	rally = _button("Reagrupar")
	await _click(rally.get_global_rect().get_center())
	check(game.rules.state.orders.size() > n_orders, "Segundo clic ejecuta Reagrupar")
	await _key(KEY_1)
	var direct2 := _button("Banco directo")
	await _click(direct2.get_global_rect().get_center())
	game.paused = false
	for i in range(12):
		game._process(5.0)
		if game.rules.get_unit("guemes").stage == "waiting_tide":
			break
	game.paused = true
	if game.rules.get_unit("guemes").stage != "waiting_tide":
		notes["wait_forced"] = true
		game.rules.get_unit("guemes").stage = "waiting_tide"
		game.rules.get_unit("guemes").order = {"action": "direct", "x": 12.0, "z": 0.0}
	notes["guemes_stage_at"] = [game.rules.get_unit("guemes").stage, game.rules.state.elapsed]
	await _frames(10)
	await _shot("justine-espera-bajante")
	notes["wait_seconds_unit0"] = game._wait_seconds(game.rules.get_unit("guemes"))
	check(float(notes["wait_seconds_unit0"]) >= 0.0, "La agrupacion que espera la bajante muestra una estimacion")
	await _key(KEY_TAB)
	check(root.gui_get_focus_owner() != null, "Tab da foco a la interfaz")
	await _frames(3)
	await _shot("justine-foco-teclado")
	await _key(KEY_TAB)
	check(root.gui_get_focus_owner() != null, "Tab recorre los botones")
	await _key(KEY_ESCAPE)
	check(root.gui_get_focus_owner() == null, "Esc suelta el foco")
	check(not is_instance_valid(game.modal), "Esc con foco no abre modal")
	var focusable := 0
	var total := 0
	for b in game.ui.find_children("*", "Button", true, false):
		total += 1
		if b.focus_mode == Control.FOCUS_ALL:
			focusable += 1
	notes["buttons_focusable"] = "%d de %d" % [focusable, total]
	var d0: float = game.camera_distance
	for i in range(3):
		var e := InputEventMouseButton.new()
		e.position = Vector2(900, 400)
		e.button_index = MOUSE_BUTTON_WHEEL_UP
		e.pressed = true
		root.push_input(e)
		await process_frame
	check(game.camera_distance < d0, "La rueda acerca la camara")
	for i in range(60):
		var e2 := InputEventMouseButton.new()
		e2.position = Vector2(900, 400)
		e2.button_index = MOUSE_BUTTON_WHEEL_UP
		e2.pressed = true
		root.push_input(e2)
		await process_frame
	check(game.camera_distance >= 18.0, "Zoom con limite inferior")
	await _key(KEY_F)
	await _frames(70)
	await _shot("justine-cerca-enfoque")
	notes["justine_overlaps_cerca"] = _overlaps(game.last_overlay_rects)
	check(_overlaps(game.last_overlay_rects) == 0, "Justine cerca: etiquetas sin solapamiento")
	await _key(KEY_P)
	await _frames(6)
	await _shot("justine-parte-abierto")
	notes["justine_free_parte_abierto"] = _free_area()
	await _key(KEY_P)

	game._return_menu()
	await _frames(10)
	game._start_game("norte")
	await _frames(50)
	await _shot("norte-inicio")
	notes["norte_free_con_ayuda"] = _free_area()
	game.hint_timer = 0.0
	game._update_hud()
	notes["norte_free"] = _free_area()
	game.hint_timer = 18.0
	notes["norte_overlaps_inicio"] = _overlaps(game.last_overlay_rects)
	check(_overlaps(game.last_overlay_rects) == 0, "Norte inicio: etiquetas sin solapamiento")
	var sid_pos: Vector2 = game.camera.unproject_position(game.world.sector_nodes["lerma"].root.global_position + Vector3(0, 1, 0))
	await _move(sid_pos + Vector2(10, 4))
	await _frames(12)
	notes["norte_hover"] = game.hover_info.get("text", "")
	await _shot("norte-hover-sector")
	var target0: Vector3 = game.camera_target
	var sector_before: String = game.sector
	game.sector_option.grab_focus()
	await _frames(2)
	await _key(KEY_ENTER)
	await _frames(4)
	await _key(KEY_DOWN)
	await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	await _frames(6)
	notes["sector_before_after"] = [sector_before, game.sector]
	check(game.sector != sector_before, "El desplegable cambia de sector con Enter y flechas")
	check(game.camera_target.is_equal_approx(target0), "Las flechas con el desplegable enfocado no mueven la camara")
	check(root.gui_get_focus_owner() == null, "Tras elegir, el desplegable suelta el foco")
	await _key(KEY_BRACKETRIGHT)
	notes["sector_after_bracket"] = game.sector
	await _frames(10)
	await _shot("norte-sector-teclado")
	await _key(KEY_3)
	check(game.selected == "zavala", "Tras el desplegable, la tecla 3 selecciona")
	game._show_campaign_reason("assault")
	notes["norte_reason_assault"] = game.reason_label.text
	check(game.action_buttons["assault"].disabled and game.reason_label.text.find("Bloqueada") >= 0, "Orden bloqueada muestra el motivo bajo la bandeja")
	await _frames(4)
	await _shot("norte-motivo-bloqueo")
	game.camera_target = Vector3(500, 0, -500)
	game._camera_keys(0.1)
	check(absf(game.camera_target.x) <= 40.0 and absf(game.camera_target.z) <= 32.0, "El objetivo de camara respeta los limites")

	var out := {"suite": "ui_qa_window", "kind": "window_injected_input", "engine": Engine.get_version_info().string, "renderer": RenderingServer.get_video_adapter_name(), "checks": checks, "failures": failures, "notes": notes}
	var f := FileAccess.open(ProjectSettings.globalize_path(out_dir).path_join("ui_qa_report.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "\t"))
	f.close()
	print("UI_QA ", JSON.stringify(out))
	await game._finish_automation(0 if failures.is_empty() else 1)
