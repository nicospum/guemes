extends SceneTree
## QA de interfaz con ventana real y entrada inyectada por el Viewport (push_input).
## Uso: godot --path . --resolution 1440x900 --script tools/ui_qa.gd [-- --out=<carpeta>]
## Resoluciones probadas: 1280x720, 1440x900, 1920x1080 y 2560x1440 (la interfaz usa anclas;
## el informe registra el tamano logico del viewport y comprueba que los paneles no se salgan ni se pisen).
## --out cambia la carpeta de capturas e informe (por defecto evidence/justina-ui/interfaz; no pisa evidence/fase2).
## No es una partida humana ni una prueba con teclado físico del sistema operativo.

var game: Node
var out_dir := "res://evidence/justina-ui/interfaz"
var checks := 0
var failures: Array = []
var notes: Dictionary = {}

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
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

func _to_window(pos: Vector2) -> Vector2:
	## push_input espera coordenadas de ventana; las posiciones de la interfaz son del canvas (base 1440x900 escalada).
	return root.get_final_transform() * pos

func _move(pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = _to_window(pos)
	e.global_position = e.position
	root.push_input(e)
	await process_frame

func _click(pos: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	await _move(pos)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.position = _to_window(pos)
		e.global_position = e.position
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
	var view := Vector2i(root.get_visible_rect().size)
	var img := Image.create(view.x, view.y, false, Image.FORMAT_L8)
	img.fill(Color.WHITE)
	for r in game._blocked_rects():
		var rr: Rect2 = r.grow(-4.0)
		img.fill_rect(Rect2i(rr).intersection(Rect2i(0, 0, view.x, view.y)), Color.BLACK)
	var free := 0
	for v in img.get_data():
		if v > 127:
			free += 1
	return {"free_px": free, "total_px": view.x * view.y, "free_pct": snappedf(100.0 * free / float(view.x * view.y), 0.1)}

func _overlaps(rects: Array) -> int:
	var n := 0
	for i in range(rects.size()):
		for j in range(i + 1, rects.size()):
			if (rects[i] as Rect2).intersects(rects[j]):
				n += 1
	return n

func _layout_checks(label: String) -> void:
	## Los paneles de la interfaz deben quedar dentro del viewport y sin pisarse entre si.
	var view := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	var rects: Array = []
	for panel in game.hud_panels:
		if is_instance_valid(panel) and panel.is_visible_in_tree():
			var r: Rect2 = panel.get_global_rect()
			rects.append(r)
			check(view.encloses(r), "%s: panel dentro del viewport %s (%s)" % [label, str(view.size), str(r)])
	check(_overlaps(rects) == 0, "%s: paneles de la interfaz sin solaparse" % label)
	if is_instance_valid(game.hint_panel) and game.hint_panel.visible:
		var hr: Rect2 = game.hint_panel.get_global_rect()
		check(view.encloses(hr), "%s: ayuda contextual dentro del viewport" % label)
		check(not hr.intersects(game.bottom_panel.get_global_rect()), "%s: ayuda contextual no pisa el panel inferior" % label)
	var bottom_r: Rect2 = game.bottom_panel.get_global_rect()
	check(absf((bottom_r.position.x + bottom_r.size.x * 0.5) - view.size.x * 0.5) < 2.0, "%s: panel inferior centrado" % label)
	check(absf(bottom_r.end.y - (view.size.y - 10.0)) < 2.0, "%s: panel inferior pegado al borde inferior" % label)
	var header_r: Rect2 = game.hud_panels[0].get_global_rect()
	check(absf(header_r.position.x - 20.0) < 2.0 and (absf(view.size.x - header_r.end.x - 20.0) < 2.0 or absf(header_r.size.x - game.hud_panels[0].get_combined_minimum_size().x) < 1.0) and header_r.end.x <= view.size.x, "%s: cabecera ocupa el ancho con margen 20 (o su ancho minimo) (%s)" % [label, str(header_r)])

func _drag(a: Vector2, b: Vector2, button: int) -> void:
	await _move(a)
	var e := InputEventMouseButton.new()
	e.position = _to_window(a)
	e.global_position = e.position
	e.button_index = button
	e.pressed = true
	e.button_mask = 1 << (button - 1)
	root.push_input(e)
	await process_frame
	for k in range(1, 9):
		var m := InputEventMouseMotion.new()
		m.position = _to_window(a.lerp(b, k / 8.0))
		m.global_position = m.position
		m.button_mask = 1 << (button - 1)
		root.push_input(m)
		await process_frame
	var u := InputEventMouseButton.new()
	u.position = _to_window(b)
	u.global_position = u.position
	u.button_index = button
	u.pressed = false
	root.push_input(u)
	await process_frame

func _justina_layout(label: String) -> void:
	var view := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	var rects: Array = []
	for panel in game.hud_panels:
		if is_instance_valid(panel) and panel.is_visible_in_tree():
			var r: Rect2 = panel.get_global_rect()
			rects.append(r)
			check(view.encloses(r), "%s: panel dentro del viewport %s (%s)" % [label, str(view.size), str(r)])
	check(_overlaps(rects) == 0, "%s: paneles sin solaparse" % label)
	var mr: Rect2 = game.minimap_rect()
	check(mr.size.x >= 260.0 and mr.size.y >= 150.0, "%s: minimapa de al menos 260x150" % label)
	check(view.encloses(game.scale_rect()) and view.encloses(game.compass_rect()), "%s: escala y brujula dentro de la pantalla" % label)
	notes["justina_layout_" + label] = {"viewport": [view.size.x, view.size.y], "minimapa": [mr.size.x, mr.size.y], "paneles": rects.size()}

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await _frames(20)
	notes["viewport_logico"] = [root.get_visible_rect().size.x, root.get_visible_rect().size.y]
	notes["ventana_px"] = [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y]
	var salir := _button("Salir")
	check(salir != null and Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(salir.get_global_rect()), "Menu: Salir visible dentro del viewport")
	await _shot("menu")
	game.jev.force_local = true
	var T := preload("res://tests/test_integration.gd")
	var RR := preload("res://scripts/game_rules.gd")
	var RW := preload("res://scripts/world_view.gd")
	var probe_r = RR.new()
	var probe_w = RW.new()
	var has_rules: bool = probe_r.has_method("plan_route") and probe_r.has_method("campaign_report")
	var has_world: bool = probe_w.has_method("get_minimap_texture") and probe_w.has_method("pick_units_in_rect")
	probe_w.free()
	notes["rules_stub"] = not has_rules
	notes["world_stub"] = not has_world
	if not has_rules:
		game.rules = T.StubRules.new()
	if not has_world:
		game.world_script = T.StubWorld
	game._start_game("justine")
	await _frames(30)
	check(is_instance_valid(game.modal), "Justina: el briefing se muestra al empezar")
	await _shot("justina-briefing")
	game._close_modal()
	await _frames(30)
	_justina_layout("Justina inicio")
	await _shot("justina-inicio")
	game.hint_timer = 0.0
	game._update_hud()
	notes["justina_free_sin_ayuda"] = _free_area()
	game.hint_timer = 18.0
	game._update_hud()
	notes["justina_free_con_ayuda"] = _free_area()
	check(float(notes["justina_free_con_ayuda"].free_pct) >= 75.0, "Justina: la interfaz no tapa mas del 25 %% de la vista (libre %s %%)" % str(notes["justina_free_con_ayuda"].free_pct))
	notes["justina_overlaps_inicio"] = _overlaps(game.last_overlay_rects)
	check(_overlaps(game.last_overlay_rects) == 0, "Justina inicio: etiquetas y fichas sin solapamiento")
	# Seleccion con entrada real inyectada
	await _key(KEY_2)
	check(game.sel_ids == ["arias"], "Tecla 2 selecciona el segundo grupo")
	await _frames(6)
	await _shot("justina-seleccion")
	var pg: Vector2 = game.camera.unproject_position(game.world.unit_nodes["guemes"].root.global_position)
	var pa: Vector2 = game.camera.unproject_position(game.world.unit_nodes["arias"].root.global_position)
	var box := Rect2(pg, Vector2.ZERO).expand(pa).grow(24)
	await _drag(box.position, box.end, MOUSE_BUTTON_LEFT)
	check(game.sel_ids.has("guemes") and game.sel_ids.has("arias") and not game.sel_ids.has("zavala"), "Caja de seleccion real sobre dos grupos")
	await _frames(4)
	await _shot("justina-caja")
	# Minimapa con clic real
	var mr: Rect2 = game.minimap_rect()
	await _click(mr.position + Vector2(130, 75))
	await _frames(4)
	check(Vector2(game.camera_target.x, game.camera_target.z).distance_to(Vector2(450, 260)) < 6.0, "Clic real en el minimapa centra la camara")
	await _shot("justina-minimapa-clic")
	# Arrastre derecho real y rueda
	var t_before: Vector3 = game.camera_target
	await _drag(Vector2(800, 400), Vector2(700, 440), MOUSE_BUTTON_RIGHT)
	check(game.camera_target.distance_to(t_before) > 3.0, "Arrastre derecho real mueve la camara")
	var d0: float = game.camera_distance
	for i in range(3):
		var e := InputEventMouseButton.new()
		e.position = _to_window(Vector2(800, 400))
		e.button_index = MOUSE_BUTTON_WHEEL_UP
		e.pressed = true
		root.push_input(e)
		await process_frame
	check(game.camera_distance < d0, "Rueda real acerca la camara")
	for i in range(80):
		var e2 := InputEventMouseButton.new()
		e2.position = _to_window(Vector2(800, 400))
		e2.button_index = MOUSE_BUTTON_WHEEL_UP
		e2.pressed = true
		root.push_input(e2)
		await process_frame
	check(game.camera_distance >= 25.0 - 0.01, "Zoom con minimo de 25 m")
	game.camera_distance = 90.0
	game._center_on(Vector2(140, 265))
	game._apply_camera()
	await _frames(6)
	# Escala y brujula
	var si: Dictionary = game._scale_info()
	notes["justina_escala"] = si
	check(float(si.px) >= 80.0 and float(si.px) <= 160.0, "Barra de escala entre 80 y 160 px (%d m, %d px)" % [int(si.m), int(si.px)])
	check((game.compass_rect() as Rect2).size.x >= 48.0, "Brujula de al menos 48 px")
	game.camera_yaw = 0.8
	game._apply_camera()
	await _frames(6)
	await _shot("justina-brujula-girada")
	game.camera_yaw = 0.0
	game._apply_camera()
	# Exploradores y vista previa de riesgo
	game.paused = false
	await _key(KEY_5)
	game._do_action("probe")
	await _move(Vector2(520, 300))
	await _frames(14)
	notes["preview_sondeo"] = game.hover_info.get("text", "")
	await _shot("justina-apuntar-sondeo")
	game._cancel_aim()
	game._select_ids(["guemes"])
	game.camera_distance = 260.0
	game._center_on(Vector2(300, 264))
	game._apply_camera()
	await _frames(4)
	var wet: Vector2 = game.camera.unproject_position(Vector3(300, 0, 264))
	await _move(wet)
	await _frames(14)
	notes["preview_ruta_sin_reconocer"] = game.hover_info.get("text", "")
	check(str(game.hover_info.get("text", "")).find("riesgo") >= 0, "Vista previa de ruta muestra el riesgo")
	await _shot("justina-vista-previa-riesgo")
	# Mitad de bajante, cruce y parte
	game._select_ids(["scout_1"])
	game.rules.issue_scout("scout_1", "probe", [Vector2(200, 264), Vector2(330, 264)])
	game.paused = true
	for s in range(210):
		game._handle_events(game.rules.tick(1.0))
	game._update_hud()
	await _frames(20)
	await _shot("justina-mitad-bajante")
	game._select_ids(["guemes"])
	game._do_action("signal_liniers")
	for s in range(90):
		game._handle_events(game.rules.tick(1.0))
	game._select_ids(["guemes", "arias", "zavala"])
	game._do_action("board")
	if game.confirm_action == "board":
		game._do_action("board")
	for s in range(150):
		game._handle_events(game.rules.tick(1.0))
	game._update_hud()
	await _frames(20)
	await _shot("justina-cruce")
	for s in range(500):
		if game.rules.state.status != "playing":
			break
		game._handle_events(game.rules.tick(1.0))
	game.paused = false
	await _frames(20)
	await _shot("justina-parte")
	check(game.rules.state.status != "playing" and is_instance_valid(game.modal), "El parte de campaña aparece al terminar")
	_justina_layout("Justina parte")
	game._close_modal()

	game.rules = RR.new()
	game.world_script = RW
	game._return_menu()
	await _frames(10)
	game._start_game("norte")
	await _frames(50)
	await _shot("norte-inicio")
	_layout_checks("Norte")
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
