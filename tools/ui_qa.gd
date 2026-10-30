extends SceneTree
## QA de interfaz con ventana real y entrada inyectada por el Viewport (push_input).
## Uso: godot --path . --resolution 1440x900 --script tools/ui_qa.gd [-- --out=<carpeta>]
## Resoluciones probadas: 1280x720, 1440x900, 1920x1080 y 2560x1440 (la interfaz usa anclas;
## el informe registra el tamano logico del viewport y comprueba que los paneles no se salgan ni se pisen).
## --size=WxH fija el tamano real de la ventana (sin bordes, tras el arranque) para que el SO no la recorte a la altura util del monitor
## (con --resolution a secas, 2560x1440 y 1920x1080 salian de 2560x1062 y 1920x1062 en un monitor 1920x1080). Se verifica el tamano de la
## captura y, si no coincide, el QA falla salvo que se pase --allow-clip; el informe guarda captura_px y resolucion_real.
## --out cambia la carpeta de capturas e informe (por defecto evidence/justina-ui/interfaz; no pisa evidence/fase2).
## No es una partida humana ni una prueba con teclado físico del sistema operativo.

var game: Node
var out_dir := "res://evidence/justina-ui/interfaz"
var checks := 0
var failures: Array = []
var notes: Dictionary = {}
var want_size := Vector2i.ZERO
var allow_clip := false
var last_shot_size := Vector2i.ZERO

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			if parts.size() == 2:
				want_size = Vector2i(int(parts[0]), int(parts[1]))
		elif arg == "--allow-clip":
			allow_clip = true
	# Instalacion nueva: los ajustes guardados por otras pruebas (p. ej. auto_pause=false) no deben contaminar la primera partida.
	if FileAccess.file_exists("user://settings.cfg"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings.cfg"))
	call_deferred("_run")

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame

func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	last_shot_size = img.get_size()
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
	# Pila central (pausa, avisos y tutorial): dentro de la pantalla, sin pisar paneles ni entre si
	var stack_rects: Array = []
	for extra in [game.pause_banner, game.alert_panel, game.hint_panel]:
		if is_instance_valid(extra) and extra.is_visible_in_tree():
			var er: Rect2 = extra.get_global_rect()
			stack_rects.append(er)
			check(view.encloses(er), "%s: %s dentro del viewport (%s)" % [label, extra.name, str(er)])
			for pr in rects:
				check(not er.intersects(pr), "%s: %s no pisa ningun panel (%s vs %s)" % [label, extra.name, str(er), str(pr)])
	check(_overlaps(stack_rects) == 0, "%s: pausa, avisos y tutorial no se pisan" % label)
	var mr: Rect2 = game.minimap_rect()
	var sc: float = root.get_final_transform().get_scale().x
	var min_px := 260.0 if DisplayServer.window_get_size().y >= 1080 else 230.0  # el requisito de 260 px es para 1080p o mas
	check(mr.size.x * sc >= min_px and mr.size.y * sc >= 0.55 * min_px, "%s: minimapa legible (>= %d px fisicos de ancho; es %s)" % [label, int(min_px), str(mr.size * sc)])
	notes["rects_" + label] = rects.map(func(r): return str(r))
	check(view.encloses(game.scale_rect()) and view.encloses(game.compass_rect()), "%s: escala y brujula dentro de la pantalla" % label)
	notes["justina_layout_" + label] = {"viewport": [view.size.x, view.size.y], "minimapa": [mr.size.x, mr.size.y], "paneles": rects.size()}

func _apply_size() -> void:
	## Un monitor de 1920x1080 no admite una ventana de SO decorada de 2560x1440 (o de 1080 de alto): el SO la recorta
	## (p. ej. 1062 px). Una ventana sin bordes cuyo tamano se fija despues del arranque si llega a 2560x1440, y la
	## captura (textura del viewport) tiene entonces el tamano pedido. Se verifica y se registra; si no se logra, falla.
	if want_size == Vector2i.ZERO:
		return
	root.mode = Window.MODE_WINDOWED
	root.borderless = true
	root.size = want_size
	root.position = Vector2i.ZERO
	await _frames(12)
	notes["tamano_pedido"] = [want_size.x, want_size.y]
	notes["ventana_px_tras_ajuste"] = [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y]
	notes["monitor_px"] = [DisplayServer.screen_get_size().x, DisplayServer.screen_get_size().y]

func _check_real_size() -> void:
	if want_size == Vector2i.ZERO:
		return
	var real := last_shot_size == want_size
	notes["captura_px"] = [last_shot_size.x, last_shot_size.y]
	notes["resolucion_real"] = real
	if not real:
		notes["limitacion"] = "El monitor/SO no permitio una captura de %dx%d (se obtuvo %dx%d)." % [want_size.x, want_size.y, last_shot_size.x, last_shot_size.y]
	check(real or allow_clip, "Captura a la resolucion pedida %s (obtenida %s)" % [str(want_size), str(last_shot_size)])

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await _frames(20)
	await _apply_size()
	notes["viewport_logico"] = [root.get_visible_rect().size.x, root.get_visible_rect().size.y]
	notes["ventana_px"] = [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y]
	var salir := _button("Salir")
	check(salir != null and Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(salir.get_global_rect()), "Menu: Salir visible dentro del viewport")
	await _shot("menu")
	_check_real_size()
	check(game.find_children("*", "RichTextLabel", true, false).filter(func(l): return "documentada" in str(l.text).to_lower()).is_empty(), "Menu: sin la palabra 'documentada' como autodefinicion")
	check(game.find_children("*", "RichTextLabel", true, false).filter(func(l): return "diseño propio" in str(l.text)).size() == 1, "Menu: texto honesto 'recreacion historica con diseño propio'")
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
	game.forced_seed=1806
	game._start_game("justine")
	await _frames(30)
	check(is_instance_valid(game.modal), "Justina: el briefing se muestra al empezar")
	await _shot("justina-briefing")
	game._deploy_dialog()
	await _frames(10)
	check(is_instance_valid(game.modal) and game.find_children("*", "Label", true, false).any(func(l): return str(l.text).find("Punto de partida") >= 0), "Justina: el despliegue previo muestra puntos de partida")
	check(Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses((game.modal.get_child(1) as Control).get_global_rect()), "Justina: el despliegue previo entra en pantalla")
	check(game.find_children("*", "RichTextLabel", true, false).any(func(l): return str(l.text).find("Consecuencias") >= 0), "Justina: el despliegue previo muestra las consecuencias de la fuerza")
	check(game.find_children("*", "CheckButton", true, false).any(func(c): return str(c.text).find("Pausa autom") >= 0), "Justina: el despliegue previo ofrece la pausa automatica")
	check(game.find_children("*", "Button", true, false).any(func(c): return str(c.text).find("Norte") >= 0), "R3: el despliegue ofrece reubicar los puntos de partida")
	check(game.clock_label.text.ends_with("min"), "R3: la cabecera dice minutos")
	await _shot("justina-despliegue")
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
	# Con el panel lateral de agrupaciones siempre visible y el tutorial, la interfaz ocupa mas que antes (era 22 %); el limite es 40 %.
	check(float(notes["justina_free_con_ayuda"].free_pct) >= 60.0, "Justina: la interfaz no tapa mas del 40 %% de la vista (libre %s %%)" % str(notes["justina_free_con_ayuda"].free_pct))
	# Tiempo real con pausa, evidente desde el primer cuadro
	check(game.mode_label.text.find("PAUSA") >= 0 and game.pause_banner.visible and game.pause_banner.text.find("tiempo detenido") >= 0, "Justina: la pausa se anuncia (indicador y cartel)")
	check(game.roster_buttons.size() == 5 and game.roster_panel.is_visible_in_tree(), "Justina: el panel lateral muestra las cinco agrupaciones")
	check(game.hint_panel.visible and game.tutorial_label.text.begins_with("1/6"), "Justina: el tutorial arranca en el paso 1/6")
	check(game.moral_label.text.find("Moral") >= 0 and game.info_label.text.find("Captura del buque 0") >= 0, "Justina: captura y moral van rotuladas por separado")
	check(game.roster_buttons["guemes"].text.find("Güemes") >= 0 and game.roster_buttons["guemes"].text.find("◆") >= 0, "Justina: la ficha de Güemes lleva su nombre y la marca de tradicion")
	game.hover_info = {"kind": "route", "ok": false, "text": "x", "risk": "alto", "point": Vector3.ZERO}
	game._close_modal()
	game._update_hover_j(0.2)
	check(game.hover_info.is_empty() or game.hover_mouse == Vector2(-1, -1), "Justina: no hay cartel de error colgado al empezar")
	check(game.settings.auto_pause == true and game.autopause_button.text.find("sí") >= 0, "Justina: la pausa automatica esta activa en la primera partida")
	check(str(game._reason_with_help("El fondo estimado en ese punto supera el límite de 1.3 m.")).find("explorador") >= 0, "Justina: el rechazo por fondo estimado dice que hacer")
	await _shot("justina-pausa-tutorial")
	notes["justina_overlaps_inicio"] = _overlaps(game.last_overlay_rects)
	notes["justina_overlay_rects_inicio"] = game.last_overlay_rects.map(func(r): return str(r))
	check(_overlaps(game.last_overlay_rects) == 0, "Justina inicio: etiquetas y fichas sin solapamiento")
	# Contexto inicial, rotulos propios, estado de partida
	var vis := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	var ship_p: Vector2 = game.rules.ship_position()
	var ship_s: Vector2 = game.camera.unproject_position(Vector3(ship_p.x, game._ground_y(ship_p.x, ship_p.y), ship_p.y))
	var grp_s: Vector2 = game.camera.unproject_position(game.world.unit_nodes["guemes"].root.global_position)
	check(vis.has_point(ship_s) and vis.has_point(grp_s), "Camara inicial: se ven a la vez los grupos y el buque")
	check(game.world.layer_state.get("labels", true) == false, "La capa 'labels' de la vista esta apagada (rotulos propios de la interfaz)")
	var dup := 0
	for l in game.world.find_children("*", "Label3D", true, false):
		if l.is_visible_in_tree() and (game.world.labels_root.is_ancestor_of(l) or game.world.unit_labels.values().has(l)):
			dup += 1
	check(dup == 0, "Sin rotulos 3D duplicados de hitos ni unidades (%d visibles)" % dup)
	check(game.state_label.text.find("Quedan") >= 0 and game.clock_label.text.begins_with("Quedan"), "El estado y la cuenta regresiva se muestran")
	check(game.state_label.text.find("Riesgo") >= 0 and game.state_label.text.find("Vado") >= 0, "El estado indica vados y riesgo")
	var pitch0: float = game.camera_pitch
	game.qa_keys[KEY_PAGEUP] = true
	await _frames(10)
	game.qa_keys.erase(KEY_PAGEUP)
	check(game.camera_pitch > pitch0, "RePag inclina la camara")
	var d_before: float = game.camera_distance
	await _key(KEY_0)
	await _frames(90)
	check(game.camera_distance > d_before * 0.99 or game.camera_distance > 450.0, "La tecla 0 aleja la vista para ver todo el mapa (%d m)" % int(game.camera_distance))
	var corners_ok := true
	for c in [Vector2(0, 0), Vector2(900, 0), Vector2(900, 520), Vector2(0, 520)]:
		var cs: Vector2 = game.camera.unproject_position(Vector3(c.x, 0, c.y))
		if not vis.has_point(cs) or game.camera.is_position_behind(Vector3(c.x, 0, c.y)):
			corners_ok = false
	check(corners_ok, "Ver todo: las cuatro esquinas del mapa entran en la pantalla")
	await _shot("justina-ver-todo")
	game._reset_camera_j()
	game._apply_camera()
	await _frames(6)
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
	await _click(mr.position + Vector2(mr.size.x * 0.5, mr.size.y * 0.5))
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
	await create_timer(0.5).timeout
	await _frames(4)
	notes["preview_sondeo"] = game.hover_info.get("text", "")
	await _shot("justina-apuntar-sondeo")
	game._cancel_aim()
	game._select_ids(["guemes"])
	game.camera_distance = 260.0
	game._center_on(Vector2(300, 264))
	game._apply_camera()
	await _frames(4)
	var wet_pt := Vector2(300, 264)
	for cand in [Vector2(300, 264), Vector2(230, 262), Vector2(225, 275), Vector2(215, 255)]:
		if bool(game.rules.plan_route("guemes", cand, "trot", {}).get("ok", false)):
			wet_pt = cand
			break
	game._center_on(wet_pt)
	game._apply_camera()
	await _frames(4)
	var wet: Vector2 = game.camera.unproject_position(Vector3(wet_pt.x, 0, wet_pt.y))
	await _move(wet)
	# Determinista: el cursor real del SO puede mover hover_mouse; se fija a mano y se fuerza el calculo (que es por tiempo, no por cuadros)
	game.hover_mouse = wet
	game.hover_timer = 0.0
	game._update_hover_j(0.2)
	await _frames(2)
	notes["preview_ruta_sin_reconocer"] = game.hover_info.get("text", "")
	check(str(game.hover_info.get("text", "")).find("riesgo") >= 0, "Vista previa de ruta muestra el riesgo")
	await _shot("justina-vista-previa-riesgo")
	game.hover_mouse = game.minimap_rect().get_center()
	game.hover_timer = 0.0
	game._update_hover_j(0.2)
	check(game.hover_info.is_empty(), "Justina: sobre el minimapa no queda colgado el cartel de ruta o de error")
	# Atajos nuevos: ? abre la ayuda, Ctrl+Z deshace, coma sin grupo abordando avisa sin romper
	await _key(KEY_QUESTION)
	await _frames(4)
	check(is_instance_valid(game.modal), "La tecla ? abre la ayuda de la Justina")
	check(game.find_children("*", "RichTextLabel", true, false).any(func(l): return "TIEMPO REAL" in str(l.text)), "La ayuda explica el tiempo real con pausa")
	await _shot("justina-ayuda")
	await _key(KEY_ESCAPE)
	await _frames(4)
	game._select_ids(["guemes"])
	game._commit_move(Vector2(float(game.rules.get_unit("guemes").x), 330.0), true)
	check(not game.rules.get_unit("guemes").order.is_empty(), "La orden de marcha de prueba se da")
	for pressed in [true, false]:
		var ez := InputEventKey.new()
		ez.keycode = KEY_Z
		ez.physical_keycode = KEY_Z
		ez.ctrl_pressed = true
		ez.pressed = pressed
		root.push_input(ez)
		await process_frame
	check(game.rules.get_unit("guemes").order.is_empty(), "Ctrl+Z (teclado inyectado) deshace la ultima orden")
	await _key(KEY_COMMA)
	await _frames(2)
	check(is_instance_valid(game.toast_label) and game.toast_label.text.find("abordando") >= 0, "La coma sin grupo abordando explica por que no hace nada: " + game.toast_label.text)
	# Tiempo real: orden con ruta, destino y ETA; indicador TIEMPO REAL
	game._select_ids(["guemes"])
	game.camera_distance = 220.0
	game._center_on(Vector2(215, 270))
	game._apply_camera()
	var sx0: float = float(game.rules.get_unit("guemes").x)
	game._commit_move(Vector2(sx0, 330.0), true)
	game.paused = false
	game._update_hud()
	game.toast_timer = 0.0
	await _frames(20)
	check(game.mode_label.text.begins_with("TIEMPO REAL"), "Justina: el indicador dice TIEMPO REAL mientras corre")
	check(game.roster_buttons["guemes"].text.find("ETA") >= 0, "Justina: la ficha muestra la ETA de la orden")
	await _shot("justina-tiempo-real-eta")
	game._undo_order()
	check(game.rules.get_unit("guemes").order.is_empty(), "Justina: Ctrl+Z deshace la orden de marcha")
	game.paused = true
	# Aviso interruptor: contraataque con pausa automatica
	game.settings.auto_pause = true
	game.paused = false
	var counter_backup: Dictionary = game.rules.state.counter.duplicate(true)
	game.rules.state.counter.active = true
	game.rules.state.counter.answered = false
	game.rules.state.counter.until = float(game.rules.state.elapsed) + 14.0
	game._update_hud()
	await _frames(12)
	check(game.paused and game.alert_panel.visible and game.pause_banner.text.find("PAUSA AUTOMÁTICA") >= 0, "Justina: el contraataque pausa solo y muestra el aviso")
	check(not game.hint_panel.visible, "Justina: el tutorial se oculta mientras hay un aviso critico")
	_justina_layout("Justina aviso")
	await _shot("justina-aviso-contraataque")
	game.rules.state.counter = counter_backup
	game.alert_ids_seen = {}
	game.pause_reason = ""
	game.settings.auto_pause = false
	game._update_hud()
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
	for s in range(1100):
		if game.rules.state.status != "playing":
			break
		game._handle_events(game.rules.tick(1.0))
	game.paused = false
	await _frames(20)
	await _shot("justina-parte")
	check(game.rules.state.status != "playing" and is_instance_valid(game.modal), "El parte de campaña aparece al terminar")
	_justina_layout("Justina parte")
	game._close_modal()

	# Reinicio con R y confirmacion
	var el0: float = game.rules.state.elapsed
	await _key(KEY_R)
	await _frames(4)
	check(is_instance_valid(game.modal), "R abre la confirmacion de reinicio en Justina")
	await _key(KEY_ESCAPE)
	await _frames(4)
	check(not is_instance_valid(game.modal) and game.rules.state.elapsed == el0, "Esc cancela el reinicio y no pierde la partida")
	await _key(KEY_R)
	await _frames(4)
	var yes := _button("Sí, reiniciar")
	check(yes != null, "La confirmacion ofrece 'Si, reiniciar'")
	if yes != null:
		await _click(yes.get_global_rect().get_center())
		await _frames(20)
	check(float(game.rules.state.elapsed) == 0.0 and str(game.rules.state.status) == "playing", "Confirmar reinicia la partida")
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
