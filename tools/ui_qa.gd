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

func _modal_buttons() -> Array:
	return game.modal.find_children("*", "Button", true, false) if is_instance_valid(game.modal) else []

func _modal_text_all() -> String:
	var t := ""
	if is_instance_valid(game.modal):
		for l in game.modal.find_children("*", "RichTextLabel", true, false):
			t += str(l.text) + "\n"
		for l in game.modal.find_children("*", "Label", true, false):
			t += str(l.text) + "\n"
		for b in game.modal.find_children("*", "Button", true, false):
			t += str(b.text) + "\n"
	return t

func _inside_scroll(n: Node) -> bool:
	var p := n.get_parent()
	while p != null:
		if p is ScrollContainer:
			return true
		p = p.get_parent()
	return false

func _modal_fits() -> bool:
	return is_instance_valid(game.modal) and Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses((game.modal.get_child(1) as Control).get_global_rect())

func _ux_checks() -> void:
	## Ronda 2 (ui_feel): mensajero, ultimo esfuerzo, reloj que arranca con la primera orden y un solo mensaje a la vez.
	game._retry(false)
	await _frames(4)
	game._close_modal()
	var r = game.rules
	# Mensajero de Liniers forzado
	var ch = null
	for ev in r.map_data().get("field_events", {}).get("list", []):
		if str(ev.kind) == "choice":
			ch = ev
			break
	check(ch != null, "R2: el mapa trae un mensajero con eleccion")
	if ch != null:
		r.state.pending_choice = {"id": ch.id, "until": float(r.state.elapsed) + 30.0, "options": (ch.options as Array).duplicate(true), "default": str(ch.default)}
		game.choice_text = str(ch.text)
		game._choice_dialog()
		await _frames(6)
		check(is_instance_valid(game.modal) and _modal_text_all().find("ensajero") >= 0, "R2: el mensajero abre su dialogo")
		check(_modal_fits(), "R2: el dialogo del mensajero entra en pantalla")
		await _shot("justina-mensajero")
		var first_label := str(ch.options[0].label)
		var ob := _button(first_label)
		check(ob != null, "R2: el mensajero ofrece la opcion «%s»" % first_label)
		if ob != null:
			await _click(ob.get_global_rect().get_center())
			await _frames(4)
		check(not is_instance_valid(game.modal) and r.state.pending_choice.is_empty(), "R2: elegir con el mensajero cierra el dialogo y resuelve la eleccion")
	# Ultimo esfuerzo forzado
	r.state.volunteers_pool = 100.0
	for u in r.state.units:
		u.shaken = true
	r.state.last_effort = {"used": false, "until": float(r.state.elapsed) + 20.0}
	game.paused = true
	game._update_hud()
	await _frames(6)
	check(game.alert_panel.visible and game.alert_btn.visible and game.alert_btn.text.find("ltimo esfuerzo") >= 0 and not game.alert_btn.disabled, "R2: con todo quebrado aparece el aviso con el boton «¡Último esfuerzo!» activo")
	check(not game.toast_label.visible, "R2: con un aviso critico en pantalla no hay otro cartel encima")
	await _shot("justina-ultimo-esfuerzo")
	await _click(game.alert_btn.get_global_rect().get_center())
	await _frames(4)
	check(bool(r.state.last_effort.used), "R2: el boton «¡Último esfuerzo!» lo ejecuta de verdad")
	# El reloj arranca con la primera orden (tras «Empezar») y un cartel importante tapa la guia
	game._retry(false)
	await _frames(4)
	game._close_modal()
	game.paused = true
	game.auto_start_pending = true
	game._select_ids(["scout_1"])
	check(game.paused, "R2: antes de la primera orden el reloj sigue detenido")
	game.rules.issue_scout("scout_1", "probe", [Vector2(200, 264)])
	game._update_hud()
	check(not game.paused and not game.auto_start_pending, "R2: la primera orden arranca el reloj sola")
	game.settings.tutorial = true
	game.tut_step = 0
	game.toast_timer = 0.0
	game._update_hud()
	check(game.hint_panel.visible, "R2: sin otros mensajes se ve la guia del tutorial")
	game._toast("importante", 4.0, true, 2)
	game._update_hud()
	check(not game.hint_panel.visible, "R2: un cartel importante tapa la guia (un solo mensaje a la vez)")
	game.toast_timer = 0.0
	game.paused = true
	await _frames(2)

func _defeat_screen_checks() -> void:
	## Ronda de diversion R1 (ui_feel): parte que ensena, reintento rapido con el mismo rio, diario, candado del Norte, menu de pausa.
	var view := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	var all_txt := _modal_text_all()
	check(game.rules.state.status == "defeat", "R1: el intento de prueba termino en derrota (%s)" % str(game.rules.state.status))
	check(all_txt.find("Reintentar") >= 0 and all_txt.find("Probá esto") >= 0 and all_txt.find("LO APRENDIDO") >= 0, "R1: el parte de derrota tiene causa, consejo, reintentar y lo aprendido")
	check(all_txt.find("campaña del norte") < 0 and all_txt.find("Ir a Sostener el Norte") < 0, "R1: la derrota nunca ofrece ir al Norte")
	var retry_b: Button = null
	for b in _modal_buttons():
		if str(b.text).begins_with("Reintentar"):
			retry_b = b
	check(retry_b != null and retry_b.is_visible_in_tree() and view.encloses(retry_b.get_global_rect()), "R1: «Reintentar» es visible sin scroll (%s)" % (str(retry_b.get_global_rect()) if retry_b != null else "no existe"))
	check(retry_b != null and not _inside_scroll(retry_b), "R1: «Reintentar» no queda dentro de un area desplazable")
	for jg in game.JARGON_BLACKLIST:
		check(all_txt.find(jg) < 0, "R1: el parte de derrota no usa la jerga «%s»" % jg)
	check(_modal_fits(), "R1: el parte de derrota entra en pantalla")
	var diary_b: Button = null
	for b in _modal_buttons():
		if str(b.text).begins_with("Abrir el diario"):
			diary_b = b
	check(diary_b != null and not diary_b.is_visible_in_tree(), "R2: lo secundario del parte (diario, parte completo, fuentes) queda plegado en «Más opciones»")
	check(all_txt.find("Reintentar (mismo mapa)") >= 0 and all_txt.find("Mapa distinto") >= 0, "R2: los botones dicen qué hacen: mismo mapa / mapa distinto")
	check(game._plain("Tropezaste en 1 pozo(s): sondeá").find("1 pozo:") >= 0 and game._plain("en 2 pozo(s)").find("2 pozos") >= 0, "R2: el plural de «pozo» se arma bien")
	await _shot("justina-derrota")
	check(int(game.progress.intentos) >= 1 and int(game.progress.derrotas_seguidas) >= 1, "R1: el intento perdido queda contado en el progreso")
	check(not game.progress.diario.is_empty(), "R1: el diario anoto algo del intento (%d entradas)" % game.progress.diario.size())
	var causes: Dictionary = game.rules.map_data().campaign.defeat_causes
	for k in causes:
		var dt: Dictionary = causes[k]
		check(str(dt.cause).length() <= 140 and str(dt.advice).length() > 10, "R1: la causa «%s» tiene texto <= 140 caracteres y consejo" % k)
		for jg in game.JARGON_BLACKLIST:
			check(str(dt.cause).find(jg) < 0 and str(dt.advice).find(jg) < 0, "R1: la causa «%s» no usa la jerga «%s»" % [k, jg])
	# El diario sobrevive a cerrar y abrir el juego
	var n_diario: int = game.progress.diario.size()
	game._progress_load()
	check(game.progress.diario.size() == n_diario and int(game.progress.intentos) >= 1, "R1: el progreso (diario, intentos) sobrevive a cerrar y abrir (%d entradas)" % n_diario)
	game._diary_dialog()
	await _frames(6)
	await _shot("justina-diario")
	check(_modal_text_all().find("Todavía no anotaste") >= 0 or _modal_text_all().find("anotad") >= 0 or n_diario > 0, "R1: el diario se abre y lista lo anotado")
	check(_modal_fits(), "R1: el diario entra en pantalla")
	game._close_modal()
	# Reintento con el mismo rio (semilla guardada); Rio nuevo cambia la semilla
	game.forced_seed = -1
	game.campaign.data.world_seed = 0
	game._start_game("justine")
	await _frames(4)
	var seed_a: int = int(game.rules.state.seed)
	check(seed_a == int(game.progress.seed) and seed_a >= 0, "R1: el rio guardado en el progreso es el que se juega")
	game._close_modal()
	for i in range(3):
		game._retry(false)
		await _frames(2)
		check(int(game.rules.state.seed) == seed_a, "R1: reintentar %d mantiene el mismo rio" % (i + 1))
	var t0 := Time.get_ticks_msec()
	game._retry(false)
	await _frames(2)
	var retry_ms := Time.get_ticks_msec() - t0
	notes["reintento_ms"] = retry_ms
	check(retry_ms <= 3000, "R1: del clic en Reintentar al primer cuadro jugable pasan <= 3 s (%d ms)" % retry_ms)
	game._retry(true)
	await _frames(2)
	check(int(game.rules.state.seed) != seed_a and game.progress.diario.is_empty(), "R1: «Río nuevo» cambia el rio y vacia el diario")
	# Intento nuevo con diario: las marcas «anotado» se dibujan solo si falta confirmar
	game.campaign.data.diary = [{"key": "pozo:pozo_central", "kind": "pozo", "text": "Pozo del banco central: te hizo tropezar 2 veces.", "x": 345.0, "z": 264.0, "n": 2}, {"key": "vado:vado_sur", "kind": "vado", "text": "Vado de la ribera (sur): reconocido.", "x": 305.0, "z": 403.0, "n": 1}]
	game.campaign.data.attempts = 3  # begin_attempt ya sumo el intento en curso: la tarjeta muestra "Intento 3"
	game.campaign.data.defeats_in_row = 2
	game.campaign.save_progress()
	game._progress_sync()
	game.rules.set_diary_marks(game.campaign.diary_marks())
	game._close_modal()
	game.camera_target = Vector3(300, 0, 300)
	game.camera_distance = 160.0
	game._apply_camera()
	await _frames(8)
	await _shot("justina-diario-marcas")
	game._intro_card()
	await _frames(4)
	check(_modal_text_all().find("Intento 3") >= 0 and _modal_text_all().find("Pista") >= 0, "R1: tras dos derrotas, la tarjeta inicial muestra el intento y una pista del diario")
	await _shot("justina-tarjeta-intento3")
	game._close_modal()
	game.campaign.data.defeats_in_row = 5
	game._intro_card()
	await _frames(4)
	var all_assist: String = _modal_text_all()
	check(all_assist.find("aqueano") >= 0 and all_assist.find("ajante") >= 0, "Ciclo: tras 5 derrotas la tarjeta ofrece baqueano y bajante generosa")
	check(Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses((game.modal.get_child(1) as Control).get_global_rect()), "Ciclo: la tarjeta con ayudas entra en pantalla")
	await _shot("justina-tarjeta-ayudas")
	game._close_modal()
	game.campaign.data.defeats_in_row = 2
	game._reset_camera_j()
	game._apply_camera()
	# Ronda 3: «Reintentar desde el cruce», marca de punto sin retorno, «Cargar sin orden» y rotulos dentro de pantalla
	game._start_game("justine")
	game._close_modal()
	game.paused = false
	for sec in range(215):
		game.rules.tick(1.0)
	game.campaign.checkpoint_path = "user://qa_checkpoint.json"
	check(game.campaign.checkpoint_tick(game.rules) and game.campaign.has_checkpoint(), "R3: el punto de control se guarda antes del vado")
	var t_cp: float = float(game.rules.state.elapsed)
	for sec in range(120):
		game.rules.tick(1.0)
	game._update_hud()
	await _frames(2)
	check(game._compute_alerts().any(func(x): return str(x.id) == "lost_cause") or float(game.rules.state.no_return_s) > float(game.rules.state.elapsed), "R3: pasado el punto sin retorno sin cargar aparece «Reintentar ya»")
	game.sel_ids = ["guemes"]
	game._refresh_actions()
	game._update_action_states()
	var own_b: Button = game.action_buttons.get("board_own")
	check(own_b != null and own_b.visible and not own_b.disabled and own_b.text.find("Cargar sin orden") >= 0, "R3: «Cargar sin orden» se ofrece (con su costo) cuando falta el permiso de Liniers")
	var hidden_grey := 0
	for ak in game.action_buttons:
		var ab2: Button = game.action_buttons[ak]
		if ab2.visible and ab2.disabled and str(game._next_step().action) != ak:
			hidden_grey += 1
	check(hidden_grey == 0, "R3: las acciones no disponibles se ocultan en vez de mostrarse en gris (%d en gris)" % hidden_grey)
	game.rules.state.status = "defeat"
	game._outcome_dialog()
	await _frames(4)
	var cp_b: Button = _button("Reintentar desde el cruce")
	check(cp_b != null and cp_b.is_visible_in_tree() and Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(cp_b.get_global_rect()), "R3: la derrota ofrece «Reintentar desde el cruce» sin scroll")
	check(_modal_fits(), "R3: el parte con tres botones entra en pantalla")
	await _shot("justina-derrota-cruce")
	if cp_b != null:
		var t1 := Time.get_ticks_msec()
		cp_b.pressed.emit()
		await _frames(2)
		check(Time.get_ticks_msec() - t1 <= 3000 and game.rules.state.status == "playing" and absf(float(game.rules.state.elapsed) - t_cp) < 3.0 and not game.paused, "R3: «Desde el cruce» devuelve el mando en <= 3 s, en el tiempo guardado")
	game.campaign.checkpoint_path = game.campaign.CHECKPOINT_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://qa_checkpoint.json"))
	game.paused = true
	game._update_hud()
	await _frames(2)
	await _shot("justina-despues-cruce")
	game._start_game("justine")
	game._close_modal()
	await _frames(3)
	# Una sola cosa por vez: los carteles menores no pisan a uno importante
	game._toast("⚠ importante", 4.0, true, 2)
	game._toast("menor", 2.0, true, 0)
	check(game.toast_label.text.find("importante") >= 0, "R1: un cartel menor no pisa a uno importante")
	game._toast("otro importante", 4.0, true, 2)
	check(game.toast_label.text == "otro importante", "R1: un cartel nuevo reemplaza al anterior (uno solo a la vez)")
	game.toast_timer = 0.0
	# Detalle plegado: el panel derecho abre limpio
	check(not game.details_open and not game.res_label.visible and not game.tide_label.visible and not game.risk_label.visible, "R1: el detalle (municion, avisos, rio) arranca plegado")
	game._toggle_details()
	await _frames(2)
	check(game.res_label.visible and game.res_label.text.find("Munición") >= 0, "R1: «Detalles» despliega la munición y los avisos")
	var jtxt: String = game.res_label.text + game.goal_label.text + game.info_label.text + game.left_foot.text + game.tutorial_label.text
	for bad in ["Balizas", "Orden de avance", "Señales de Liniers", "pólvora de reserva"]:
		check(jtxt.find(bad) < 0, "R1: el panel no usa la jerga «%s»" % bad)
	await _shot("justina-detalles")
	game._toggle_details()
	# La botonera principal no trae la accion peligrosa; el menu de pausa la separa y pide confirmar
	await _key(KEY_ESCAPE)
	await _frames(4)
	var pm := _modal_text_all()
	check(is_instance_valid(game.modal) and pm.find("Abandonar") >= 0 and pm.find("ACCIONES QUE CORTAN EL INTENTO") >= 0, "R1: Esc abre el menú de pausa con las acciones que cortan el intento aparte")
	await _shot("justina-menu-pausa")
	check(_modal_fits(), "R1: el menú de pausa entra en pantalla")
	var ab := _button("Abandonar")
	check(ab != null, "R1: el menú de pausa ofrece abandonar")
	if ab != null:
		await _click(ab.get_global_rect().get_center())
		await _frames(4)
		check(is_instance_valid(game.modal) and game.rules.state.status == "playing" and _modal_text_all().find("Sí, terminar la partida") >= 0, "R1: abandonar pide una segunda confirmación y no termina solo")
	game._close_modal()
	# Cuenta regresiva del buque sobre el propio buque
	game.settings.tutorial = true
	game.tut_step = 0
	game.rules.state.pending_shot = {"tid": "guemes", "scout": false, "ax": 250.0, "az": 264.0, "at": float(game.rules.state.elapsed) + 3.2, "strong": false, "radius": 9.0}
	game.rules.state.next_volley = float(game.rules.state.elapsed) + 12.0
	game.paused = false
	await _frames(14)
	await _shot("justina-descarga-aviso")
	game.paused = true
	game._update_hud()
	check(game.paused and game.mode_label.text.find("PAUSA") >= 0, "R1: el indicador marca la pausa")
	await _frames(4)
	await _shot("justina-pausa-marco")
	# Medallas alcanzables y candado del Norte
	game.rules.state.fords_found = []
	game.campaign.data.north_unlocked = false
	game._progress_sync()
	game._menu()
	await _frames(6)
	var nb := _button("SOSTENER EL NORTE")
	check(nb != null and nb.disabled and nb.text.find("Ganá la Justina para abrirlo") >= 0, "R1: perfil nuevo: el Norte está con candado y dice cómo abrirlo")
	await _shot("menu-norte-bloqueado")
	game.campaign.data.north_unlocked = true
	game._progress_sync()
	game._menu()
	await _frames(6)
	nb = _button("SOSTENER EL NORTE")
	check(nb != null and not nb.disabled, "R1: tras ganar, el Norte queda habilitado")
	game.forced_seed = 1806
	game.campaign.data.north_unlocked = false
	game.campaign.data.justina_won = false
	game.campaign.save_progress()
	game._progress_sync()
	game._start_game("justine")
	await _frames(10)
	game._close_modal()
	# Victoria simulada para ver la pantalla de medalla
	game.settings.auto_pause = false
	game.rules.state.fords_found = ["vado_buque"]
	game.rules.state.status = "victory"
	game.rules.state.reason = "Buque capturado"
	game.rules.state.defeat_cause = ""
	game.rules.state.capture = 100.0
	game.rules.state.elapsed = 640.0
	game.outcome_shown = false
	game.attempt_logged = false
	game.beat_enabled = true
	game._outcome_dialog()
	await _frames(30)
	check(is_instance_valid(game.outcome_beat) or game.qa_mode, "R2: la victoria arranca con un cierre breve (banner sobre el buque) antes del resultado")
	await _shot("justina-victoria-cierre")
	game._close_modal()
	if is_instance_valid(game.outcome_beat):
		game.outcome_beat.queue_free()
	game.beat_enabled = false
	game.outcome_shown = false
	game._outcome_dialog()
	await _frames(8)
	var vt := _modal_text_all()
	check(vt.find("MEDALLA DE") >= 0 and vt.find("Se desbloqueó el escenario 2") >= 0 and vt.find("Ir a Sostener el Norte") >= 0, "R1: la victoria muestra medalla, desbloqueo y el paso al Norte")
	check(bool(game.progress.justina_ganada), "R1: ganar fija justina_ganada en el progreso")
	check(vt.find("Esta vez") >= 0 and vt.find("Tu mejor medalla") >= 0, "R2: la victoria separa la medalla de esta vez de la mejor")
	await _shot("justina-victoria")
	check(_modal_fits(), "R1: la pantalla de victoria entra en pantalla")
	game._close_modal()
	game.forced_seed = 1806
	game._start_game("justine")
	await _frames(10)
	game._close_modal()

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
	check(is_instance_valid(game.modal), "Justina: la tarjeta inicial se muestra al empezar")
	await _shot("justina-tarjeta-inicial")
	var card_txt := ""
	for l in game.modal.find_children("*", "RichTextLabel", true, false):
		card_txt += str(l.text) + " "
	check(card_txt.find("Objetivo") >= 0 and card_txt.find("Perder no es grave") >= 0 and card_txt.find("mismo río") >= 0, "R1: la tarjeta inicial dice el objetivo y que perder no es grave")
	check(game.find_children("*", "Button", true, false).any(func(c): return str(c.text) == "Empezar"), "R1: la tarjeta inicial tiene «Empezar» como boton principal")
	check(game.find_children("*", "Button", true, false).any(func(c): return str(c.text) == "Saltar tutorial") and game.find_children("*", "Button", true, false).any(func(c): return str(c.text) == "Cómo se juega"), "R1: la tarjeta ofrece saltar el tutorial y la ayuda completa")
	check(card_txt.length() < 700, "R1: la tarjeta inicial es corta (%d caracteres)" % card_txt.length())
	check(Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses((game.modal.get_child(1) as Control).get_global_rect()), "R1: la tarjeta inicial entra en pantalla %s" % str((game.modal.get_child(1) as Control).get_global_rect()))
	game._briefing_dialog()
	await _frames(6)
	await _shot("justina-briefing")
	check(game.find_children("*", "Button", true, false).any(func(c): return str(c.text).begins_with("Jugar")), "R5: el briefing tiene «Jugar» como boton principal")
	check(game.find_children("*", "Button", true, false).any(func(c): return str(c.text) == "Jugar (empieza en pausa)"), "R6: el boton Jugar aclara que la partida empieza en pausa")
	check(not str(game.place_label.text).contains(" x "), "R6: el rotulo de lugar no muestra coordenadas crudas")
	check(not game.find_children("*", "RichTextLabel", true, false).any(func(l): return str(l.text).find("pendiente tuya") >= 0), "R5: el briefing no muestra notas de produccion")
	check(Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses((game.modal.get_child(1) as Control).get_global_rect()), "R5: el briefing entra en pantalla")
	game._deploy_dialog()
	await _frames(10)
	check(is_instance_valid(game.modal) and game.find_children("*", "Label", true, false).any(func(l): return str(l.text).find("Punto de partida") >= 0), "Justina: el despliegue previo muestra puntos de partida")
	check(Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses((game.modal.get_child(1) as Control).get_global_rect()), "Justina: el despliegue previo entra en pantalla")
	check(game.find_children("*", "RichTextLabel", true, false).any(func(l): return str(l.text).find("Consecuencias") >= 0), "Justina: el despliegue previo muestra las consecuencias de la fuerza")
	check(game.find_children("*", "CheckButton", true, false).any(func(c): return str(c.text).find("Pausa autom") >= 0), "Justina: el despliegue previo ofrece la pausa automatica")
	check(game.find_children("*", "Button", true, false).any(func(c): return str(c.text).find("Norte") >= 0), "R3: el despliegue ofrece reubicar los puntos de partida")
	check(game.clock_label.text.ends_with("min"), "R3: la cabecera dice minutos")
	check(game.find_children("*", "Control", true, false).any(func(c): return c.tooltip_text.begins_with("Puntos de partida de las cinco")), "R7: el despliegue muestra un mapa con los puntos de partida")
	check(game.find_children("*", "Button", true, false).any(func(c): return str(c.text).begins_with("Empezar a ordenar")), "R7: el despliegue ofrece empezar a ordenar en pausa")
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
	# En una vista baja (720p, 1280x720 logicos) los mismos paneles son una fraccion mayor de la pantalla: el limite es 40 % con 900 logicos de alto y 55 % de ocupacion con menos de 800 (la interfaz no se encoge: se prefiere letra legible).
	var free_min := 60.0 if root.get_visible_rect().size.y >= 800.0 else 40.0
	check(float(notes["justina_free_con_ayuda"].free_pct) >= free_min, "Justina: la interfaz deja libre al menos %s %% de la vista (libre %s %%)" % [str(free_min), str(notes["justina_free_con_ayuda"].free_pct)])
	# Tiempo real con pausa, evidente desde el primer cuadro
	check(game.mode_label.text.find("PAUSA") >= 0 and game.hint_panel.visible and game.tutorial_label.text.find("Espacio") >= 0 and not game.pause_banner.visible, "Justina: la pausa se anuncia (indicador) y la guia dice como arrancar el reloj, sin cartel duplicado")
	check(game.roster_buttons.size() == 5 and game.roster_panel.is_visible_in_tree(), "Justina: el panel lateral muestra las cinco agrupaciones")
	check(game.hint_panel.visible and game.tutorial_label.text.begins_with("1/4"), "Justina: el tutorial arranca en el paso 1/4")
	check(game.moral_label.text.find("Moral") >= 0 and game.info_label.text.find("Captura del buque 0") >= 0, "Justina: captura y moral van rotuladas por separado")
	check(game.roster_buttons["guemes"].text.find("Güemes") >= 0 and game.roster_buttons["guemes"].text.find("◆") >= 0, "Justina: la ficha de Güemes lleva su nombre y la marca de tradicion")
	game.hover_info = {"kind": "route", "ok": false, "text": "x", "risk": "alto", "point": Vector3.ZERO}
	game._close_modal()
	game._update_hover_j(0.2)
	check(game.hover_info.is_empty() or game.hover_mouse == Vector2(-1, -1), "Justina: no hay cartel de error colgado al empezar")
	check(game.settings.auto_pause == true and game.autopause_button.text.find("☑") >= 0, "Justina: la pausa automatica esta activa en la primera partida")
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
	# Sin ningun grupo abordando, el contraataque avisa pero NO pausa y dice que hacer.
	check(not game.paused and game.alert_panel.visible and game.alert_label.text.find("Ningún grupo aborda") >= 0, "Justina: contraataque sin grupo abordando no pausa y explica la accion util")
	check(game.action_buttons.has("repel") and not game.action_buttons["repel"].visible, "Justina: Rechazar no se muestra si nadie aborda")
	game.tut_step = 4
	game.settings.tutorial = true
	check(game._tutorial_j().is_empty() or game.rules.state.counter.active, "Justina: el paso de abordaje del tutorial no aparece sin abordaje")
	var boarder: Dictionary = game.rules.get_unit("guemes")
	var stage_backup = boarder.stage
	boarder.stage = "boarding"
	game.alert_ids_seen = {}
	game._update_hud()
	await _frames(12)
	check(game.action_buttons["repel"].visible, "Justina: Rechazar aparece con un grupo abordando")
	check(game.paused and game.alert_panel.visible and game.pause_banner.text.find("PAUSA AUTOMÁTICA") >= 0, "Justina: el contraataque pausa solo y muestra el aviso")
	check(not game.hint_panel.visible, "Justina: el tutorial se oculta mientras hay un aviso critico")
	check(str(game.reason_label.text).find("tutorial de arriba") < 0, "R7: no se manda a mirar un tutorial que no esta visible")
	check(game.action_buttons["retreat_all"].tooltip_text.find("PELIGRO") >= 0, "R7: la retirada general lleva aviso de peligro")
	check(not game.action_buttons["retreat_all"].visible, "R1: la retirada general no esta en la botonera principal")
	check(game.top_stack.get_global_rect().end.x <= root.get_visible_rect().size.x and game.top_stack.get_global_rect().position.x >= 0.0, "R7: la pila central de avisos entra a lo ancho")
	_justina_layout("Justina aviso")
	await _shot("justina-aviso-contraataque")
	boarder.stage = stage_backup
	game.tut_step = 0
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
	await _defeat_screen_checks()
	game._close_modal()
	await _ux_checks()

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
