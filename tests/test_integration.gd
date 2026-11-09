extends SceneTree
## Player-flow checks against the actual main scene; headless, no screenshot claim.
## Justina (contrato v1): si Reglas o Vista aun no implementan el contrato, la prueba usa los
## sustitutos minimos de este mismo archivo (clases StubRules / StubWorld) y lo declara en el informe.
## Escribe el informe en evidence/justina-ui/ (no toca evidence/ de 0.1.0). Aislar APPDATA antes de correr.

const RealRules = preload("res://scripts/game_rules.gd")
const RealWorld = preload("res://scripts/world_view.gd")

var game: Node
var checks := 0
var failures: Array = []
var report: Dictionary = {"suite": "main_scene_player_flow", "kind": "headless_scene_integration", "engine": Engine.get_version_info().string}

func _initialize() -> void:
	# Hermetico: el perfil no puede arrastrar intentos, diario ni ajustes de otra corrida (la tarjeta inicial crece con los intentos).
	for stale in ["campaign.json", "justina_progress.json", "humahuaca_progress.json", "humahuaca_checkpoint.json", "settings.cfg", "save_norte_f5.json", "save_justine_f5.json"]:
		if FileAccess.file_exists("user://" + stale):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + stale))
	call_deferred("_run")

func _contract_present() -> Dictionary:
	var r = RealRules.new()
	var w = RealWorld.new()
	var out := {"rules": r.has_method("plan_route") and r.has_method("campaign_report"), "world": w.has_method("get_minimap_texture") and w.has_method("pick_units_in_rect")}
	w.free()
	return out

func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	if scene == null:
		check(false, "Main scene loads")
		_finish()
		return
	game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.settings.auto_pause = false  # los guiones automaticos no pueden esperar a que el jugador reanude
	check(game.mode == "menu", "Opening the delivery reaches scenario selection")
	check(_find_button("EL RÍO OFRECE") != null, "Menu offers the Justina scenario")
	check(_find_button("SOSTENER EL NORTE") != null, "Menu offers the northern scenario")
	var menu_texts := ""
	for l in game.find_children("*", "RichTextLabel", true, false):
		menu_texts += str(l.text) + "
"
	check(menu_texts.to_lower().find("documentada") < 0 and menu_texts.find("diseño propio") >= 0, "Menu does not call the recreation 'documentada' and says it has its own design")
	game.jev.force_local = true
	var present := _contract_present()
	report["rules_stub"] = not present.rules
	report["world_stub"] = not present.world
	if not present.rules:
		game.rules = StubRules.new()
	if not present.world:
		game.world_script = StubWorld
	await _justina()
	await _norte()
	await _transiciones()
	await _campana()
	await _norte_por_humahuaca()
	await _p4b()
	await _qa_ronda2()
	report.final_scenario = game.rules.state.scenario
	report.final_status = game.rules.state.status
	if is_instance_valid(game.audio_manager):
		game.audio_manager.set_muted(true)
		game.audio_manager.set_environment("")
	await create_timer(0.12).timeout
	game.queue_free()
	await process_frame
	game = null
	scene = null
	_finish()

# ------------------------------------------------------------------ Justina
func _justina() -> void:
	game.forced_seed = 1806  # B-045: sin semilla fija el fondo del río cambia en cada partida y la secuencia del vado, la señal y el abordaje fallaba 1 de cada 21 corridas
	check(_press("EL RÍO OFRECE"), "Justina starts through its menu button")
	await process_frame
	await process_frame
	check(game.mode == "play" and game.rules.state.scenario == "justine", "Justina scene and rules agree")
	check(game.paused, "Justina starts paused for the first decision")
	check(game.world.unit_nodes.size() >= 5, "Three groups and two scouts have 3D nodes")
	# Briefing inicial
	check(is_instance_valid(game.modal), "Briefing modal opens at the start")
	var ctxt := _modal_text()
	check(ctxt.find("Objetivo") >= 0 and ctxt.find("Perder no es grave") >= 0 and ctxt.find("Empezar") >= 0, "R1: la tarjeta inicial dice el objetivo, que perder no es grave y ofrece Empezar")
	# P4b: la tarjeta es ahora la pantalla de misión (mockup 05, como el briefing del II): a los costados suma fuerzas, enemigo, reloj del río,
	# cronología y una cita, que son datos de consulta y no texto que haya que leer para empezar. «Corta» se mide sobre el mensaje (los textos
	# con formato y los botones), con el mismo tope de 900; antes se contaban también los rótulos y las ayudas emergentes de todo el modal.
	var msg := ""
	for n in game.modal.find_children("*", "", true, false):
		if n is RichTextLabel: msg += str(n.text) + "\n"
		elif n is Button: msg += str(n.text) + "\n"
	check(msg.length() < 900, "R1: el mensaje de la tarjeta inicial es corto (%d caracteres)" % msg.length())
	check(ctxt.find("TUS FUERZAS") >= 0 and ctxt.find("ENEMIGO") >= 0 and ctxt.find("EL RÍO") >= 0 and ctxt.find("CRONOLOGÍA") >= 0 and ctxt.find("Gillespie") >= 0, "P4b: la tarjeta inicial tiene la composición del mockup 05 (fuerzas, enemigo, río, cronología y cita con fuente)")
	# Ronda 5: la tarjeta sigue corta aunque el perfil tenga muchos intentos y una pista larga; fases, pista y avisos
	var gu: Dictionary = game.rules.get_unit("guemes")
	var st0 = gu.stage
	game.rules.state.capture = 40.0
	gu.stage = "boarding"
	check(game._phase() == "boarding" and game._next_step().text.find("explorador") < 0, "R5: la pista sigue la fase (abordaje, no sondeo)")
	check(game._goal_text().find("ABORDAJE") >= 0 and game._state_text(100.0).find("hay que sondear") < 0, "R5: el objetivo y el estado dejan de hablar del vado en el abordaje")
	game._select_ids(["guemes"])
	game._do_action("withdraw")
	check(game.confirm_action == "withdraw" and str(game.rules.get_unit("guemes").stage) == "boarding", "R5: «Retirar» en el abordaje pide confirmar")
	game.confirm_action = ""
	game.confirm_timer = 0.0
	gu.stage = "moving"
	gu.strength = 20.0
	game.rules.state.capture = 0.0
	var alert_ids: Array = []
	for al in game._compute_alerts():
		alert_ids.append(str(al.id))
	check(alert_ids.has("disp_guemes"), "R5: bajo 30 %% de fuerza hay aviso fuerte de dispersion")
	gu.strength = 100.0
	gu.stage = st0
	check(game._learn_line("Pozo del flanco norte").begins_with("Sond") and game._learn_line("Esta vez: x").length() > 0, "R5: lo aprendido usa verbos")
	# P4b: con la pantalla de misión abierta todo el HUD se apaga a propósito (queda solo la escena); fuera de ella no se atenúa.
	check(game.right_panel.modulate.a >= 0.99 or (is_instance_valid(game.modal) and game.mission_hidden.has(game.right_panel)), "R5: el panel de objetivo no se atenua")
	check(game.top_stack.is_ancestor_of(game.toast_label), "R5: el aviso transitorio vive en la pila superior, no sobre los botones")
	game._briefing_dialog()
	var btxt := _modal_text()
	check(btxt.find("Tradición") >= 0 and btxt.find("Documentado") >= 0 and btxt.find("Reconstrucción") >= 0 and btxt.find("Diseño") >= 0, "Briefing shows the four source tags")
	check(btxt.find(str(game.rules.state.briefing).substr(0, 40)) >= 0, "Briefing shows state.briefing")
	check(btxt.count("•") >= 3, "Briefing shows three tips")
	check(btxt.find("Qué hacer, en 4 pasos") >= 0 and btxt.find("TIEMPO REAL con pausa") >= 0, "R7: el briefing abre con TIEMPO REAL y los 4 pasos")
	check(btxt.find("Palabras del juego") >= 0, "R7: el glosario y los consejos viven en su propia pestaña")
	check(game.rules.get_unit("zavala").tag == "tradicion" and game._ujg("zavala") == game._tag_glyph("tradicion"), "R7: el glifo de cada unidad sale de su tag de fuente (Reserva: tradicion)")
	check(game._ujg("guemes") != "●" or str(game.rules.get_unit("guemes").tag) == "documentado", "R7: ● queda solo para lo documentado")
	check(game._river_word() == "alta" and game.phase_label.text.find("río alta") >= 0, "R7: el rotulo del rio sale del reloj (alta al inicio)")
	var rules_txt := FileAccess.get_file_as_string("res://scripts/game_rules.gd") + FileAccess.get_file_as_string("res://data/justina_map.json")
	check(rules_txt.find("La batería Abascal") < 0 and rules_txt.find("La batería todavía") < 0, "R7: ningun texto visible nombra la bateria Abascal"
	)
	_key(KEY_F1)
	game._close_modal()
	check(not is_instance_valid(game.modal) and game.paused, "Closing the briefing keeps the game paused")
	_key(KEY_F1)
	check(is_instance_valid(game.modal), "F1 reopens the briefing")
	game._close_modal()
	await process_frame
	game._apply_camera()
	# Camara inicial
	var cam_cfg: Dictionary = game.rules.map_data().camera
	# La camara inicial muestra contexto: grupos, barranca y buque a la vez, sin ser el mapa entero.
	var vis := Rect2(Vector2.ZERO, game.get_viewport().get_visible_rect().size)
	var ship_p: Vector2 = game.rules.ship_position()
	var ship_s: Vector2 = game.camera.unproject_position(Vector3(ship_p.x, game._ground_y(ship_p.x, ship_p.y), ship_p.y))
	check(vis.has_point(ship_s) and not game.camera.is_position_behind(Vector3(ship_p.x, 0, ship_p.y)), "Initial camera shows the ship")
	for gid in ["guemes", "arias", "zavala"]:
		var gp: Vector2 = game.camera.unproject_position(game.world.unit_nodes[gid].root.global_position)
		check(vis.has_point(gp), "Initial camera shows group " + gid)
	check(game.camera_distance >= float(cam_cfg.initial_height_m), "Initial camera is not closer than camera.initial_height_m")
	var fr: PackedVector2Array = game.world.camera_frustum_on_ground(game.camera)
	var focus := Vector2(float(cam_cfg.focus_start[0]), float(cam_cfg.focus_start[1]))
	var bounds: Rect2 = game.world.camera_bounds()
	var whole := Rect2(Vector2.ZERO, game.rules.map_size())
	var seen := Rect2(fr[0], Vector2.ZERO)
	for p in fr:
		seen = seen.expand(p)
	check(seen.size.x < whole.size.x * 1.6, "Initial view is a regional view, not the horizon")
	# Ver todo
	game._view_all()
	game.camera_target = game.cam_goal_target
	game.camera_distance = game.cam_goal_distance
	game._apply_camera()
	var all_ok := true
	for c in [Vector2(0, 0), Vector2(whole.size.x, 0), whole.size, Vector2(0, whole.size.y)]:
		var cs: Vector2 = game.camera.unproject_position(Vector3(c.x, 0, c.y))
		if not vis.grow(2).has_point(cs):
			all_ok = false
	# En la ventana headless el viewport es casi cuadrado (1440x1440): ahi el zoom maximo (900 m) no alcanza; se admite el tope.
	check(all_ok or game.camera_distance >= float(cam_cfg.max_distance_m) - 0.01, "View-all frames the four corners of the map (or reaches max zoom-out)")
	game._reset_camera_j()
	game._apply_camera()
	# HUD y paneles
	await _frames(3)
	_layout_checks("Justina inicio")
	# Seleccion
	_key(KEY_2)
	check(game.sel_ids == ["arias"], "Key 2 selects the second group")
	_key(KEY_5)
	check(game.sel_ids == ["scout_2"], "Key 5 selects the second scout")
	_key(KEY_TAB)
	check(game.sel_ids == ["guemes"], "Tab cycles the selection")
	_key(KEY_1)
	check(_press("2 Voluntarios"), "Roster button selects a group")
	check(game.selected == "arias", "Roster closure selects the correct actor")
	# Caja de seleccion sobre dos grupos
	game._center_on(Vector2(199, 268), 120.0)
	game.camera_distance = game.cam_goal_distance
	game.camera_target = game.cam_goal_target
	game._apply_camera()
	var pg := _screen("guemes")
	var pa := _screen("arias")
	var pz := _screen("zavala")
	var rect := Rect2(pg, Vector2.ZERO).expand(pa).grow(22)
	check(not rect.has_point(pz), "Test box does not contain the third group")
	_mouse_press(rect.position, MOUSE_BUTTON_LEFT)
	_mouse_move(rect.end)
	check(game.box_active, "Dragging more than 6 px draws a selection box")
	_mouse_release(rect.end, MOUSE_BUTTON_LEFT)
	check(game.sel_ids == ["guemes", "arias"], "Box selection returns both groups")
	_mouse_click(pz, MOUSE_BUTTON_LEFT, true)
	check(game.sel_ids == ["guemes", "arias", "zavala"], "Shift adds to the selection")
	_mouse_click(pa, MOUSE_BUTTON_LEFT, false, true)
	check(game.sel_ids == ["guemes", "zavala"], "Ctrl toggles a member out")
	_key(KEY_1)
	check(game.sel_ids == ["guemes"], "Key 1 selects Guemes alone")
	# Acciones: botones, glifos y motivos de bloqueo
	await _frames(2)
	for a in game.rules.list_actions("group"):
		check(game.action_buttons.has(a), "Group action button exists: " + a)
		if game.action_buttons.has(a):
			var b: Button = game.action_buttons[a]
			var tag: String = str(game.rules.action_info(a).get("tag", "diseno"))
			check(b.text.find(game._tag_glyph(tag)) >= 0 and b.text.find(game._action_label(a)) >= 0, "Button shows tag glyph and label: " + a)
			if b.disabled:
				check(str(b.get_meta("why", "")) != "", "Blocked action carries a reason: " + a)
	check(game.action_buttons["board"].disabled and str(game.action_buttons["board"].get_meta("why")).find("Liniers") >= 0, "Board is blocked until Liniers authorises, with the reason")
	check(game.action_buttons.has("distract_fire") and game.action_buttons.has("retreat_all"), "Global actions are always offered")
	_key(KEY_5)
	await _frames(2)
	for a in ["probe", "mark_ford", "recall"]:
		check(game.action_buttons.has(a), "Scout action button exists: " + a)
	check(not game.action_buttons.has("muster"), "Group actions are hidden while only a scout is selected")
	# Camara: teclas, borde, arrastre, rueda, limites
	game._select_ids(["guemes"])
	var t0: Vector3 = game.camera_target
	game.qa_keys[KEY_W] = true
	game._camera_keys(0.5)
	game.qa_keys.clear()
	check(game.camera_target.distance_to(t0) > 5.0, "W pans the free camera")
	var t1: Vector3 = game.camera_target
	game.qa_focus_override = 1
	game.hover_mouse = Vector2(2, 400)
	game._camera_keys(0.5)
	game.qa_focus_override = 0
	check(game.camera_target.x < t1.x - 1.0, "The screen edge pans when the window is focused")
	var t2: Vector3 = game.camera_target
	game.hover_mouse = Vector2(2, 400)
	game._camera_keys(0.5)
	check(game.camera_target.is_equal_approx(t2), "The screen edge does nothing without window focus")
	game.qa_focus_override = -1
	game.hover_mouse = Vector2(700, 400)
	game.camera_target = Vector3(5000, 0, -5000)
	game._camera_keys(0.1)
	check(bounds.grow(0.01).has_point(Vector2(game.camera_target.x, game.camera_target.z)), "The camera target never leaves camera_bounds")
	game._center_on(focus)
	game._apply_camera()
	var anchor := Vector2(700, 380)
	var g_before = game.world.ground_xz_from_screen(game.camera, anchor)
	_mouse_press(anchor, MOUSE_BUTTON_RIGHT)
	_mouse_move(anchor + Vector2(-80, 30))
	check(game.drag_active(), "Right button moved more than 6 px starts dragging the map")
	_mouse_release(anchor + Vector2(-80, 30), MOUSE_BUTTON_RIGHT)
	var g_after = game.world.ground_xz_from_screen(game.camera, anchor + Vector2(-80, 30))
	check(g_before != null and g_after != null and g_before.distance_to(g_after) < 1.5, "Dragging grabs the map: the point under the cursor follows it")
	check(game.rules.get_unit("guemes").order.is_empty(), "A right drag does not issue an order")
	for i in range(60):
		_wheel(Vector2(700, 400), true)
	check(game.camera_distance >= float(cam_cfg.min_distance_m) - 0.001, "Zoom respects the 25 m minimum")
	for i in range(80):
		_wheel(Vector2(700, 400), false)
	check(game.camera_distance <= float(cam_cfg.max_distance_m) + 0.001, "Zoom respects the 900 m maximum")
	check(bounds.grow(0.01).has_point(Vector2(game.camera_target.x, game.camera_target.z)), "Zoom keeps the target inside the bounds")
	game._center_on(focus)
	game.camera_distance = float(cam_cfg.initial_height_m)
	game._apply_camera()
	var y_floor: float = game._ground_y(game.camera.position.x, game.camera.position.z)
	check(game.camera.position.y >= y_floor + 2.9, "The camera stays above the terrain")
	# Minimapa, brujula, escala
	var mm := game.minimap_rect() as Rect2
	check(mm.size.x >= 300.0 and mm.size.y >= 173.0, "Minimap is at least 300x173 logical px (360 px at 1080p)")
	check((game.compass_rect() as Rect2).size.x >= 48.0, "Compass is at least 48 px")
	var si: Dictionary = game._scale_info()
	check(float(si.px) >= 80.0 and float(si.px) <= 160.0, "Scale bar is 80-160 px (%d m, %d px)" % [int(si.m), int(si.px)])
	check(absf(float(si.px) * float(game.world.meters_per_pixel(game.camera)) - float(si.m)) / float(si.m) < 0.05, "Scale bar length matches meters_per_pixel within 5 %")
	var local := mm.size * 0.5
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = local
	game._map_gui_input(ev)
	check(Vector2(game.camera_target.x, game.camera_target.z).distance_to(Vector2(450, 260)) < 2.0, "Left click on the minimap centres the camera there")
	game._apply_camera()
	var fr2: PackedVector2Array = game.world.camera_frustum_on_ground(game.camera)
	var c2 := Vector2.ZERO
	for p in fr2:
		c2 += p
	c2 /= 4.0
	check(c2.distance_to(Vector2(450, 260)) < 200.0, "The camera frame on the minimap follows the click")
	game._map_gui_input(InputEventMouseMotion.new())
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	game._map_gui_input(up)
	# Nombre del paraje
	game._center_on(Vector2(150, 265))
	game._update_place()
	check(game.place_label.text.find("Plaza de Toros") >= 0 or game.place_label.text.find("Playa") >= 0 or game.place_label.text.find("Barranca") >= 0, "Place name describes the centre: " + game.place_label.text)
	game._center_on(Vector2(412, 264))
	game._update_place()
	check(game.place_label.text.find("Banco central") < 0 and game.place_label.text.find("pozo") < 0 and game.place_label.text.find("Pozo") < 0, "Hidden bank and pit are not named before reconnaissance")
	# Ritmo
	_key(KEY_G)
	check(game.pace == "gallop", "G selects gallop")
	_key(KEY_C)
	check(game.pace == "walk", "C selects walking")
	_key(KEY_T)
	check(game.pace == "trot", "T selects trot")
	# Tabla unica de teclas: sin repetidas, y cada fila documentada en docs/CONTROLES.md
	var seen_codes := {}
	var dups: Array = []
	for row in game.J_KEY_TABLE:
		for k in row.keys:
			if seen_codes.has(k):
				dups.append(OS.get_keycode_string(k))
			seen_codes[k] = row.label
	for act in game.ACTION_KEYS:
		var kc: int = game.ACTION_KEYS[act]
		if seen_codes.has(kc):
			dups.append(OS.get_keycode_string(kc) + " (" + act + ")")
		seen_codes[kc] = act
	check(dups.is_empty(), "Justina key table has no repeated key: " + str(dups))
	var docs := FileAccess.get_file_as_string("res://docs/CONTROLES.md")
	var undocumented: Array = []
	for row in game.J_KEY_TABLE:
		if docs.find("| " + str(row.label) + " |") < 0:
			undocumented.append(row.label)
	for act in game.ACTION_KEYS:
		var ks := OS.get_keycode_string(game.ACTION_KEYS[act])
		if docs.find("| " + ks + " |") < 0:
			undocumented.append(ks)
	check(undocumented.is_empty(), "Every Justina key is in docs/CONTROLES.md: " + str(undocumented))
	# --- Ronda 1: tiempo real, panel de agrupaciones, acciones contextuales, deshacer, avisos, tutorial y despliegue ---
	await _justina_r1_ui()
	# Reinicio con R (confirmacion) y pitch en RePag/AvPag
	_key(KEY_R)
	check(is_instance_valid(game.modal), "R asks to confirm the restart in Justina")
	game._close_modal()
	var pitch_before: float = game.camera_pitch
	game.qa_keys[KEY_PAGEDOWN] = true
	game._camera_keys_j(0.2)
	game.qa_keys.erase(KEY_PAGEDOWN)
	check(game.camera_pitch < pitch_before, "AvPag tilts the camera down")
	# Capa 'labels' apagada y estado de partida
	check(game.world.layer_state.get("labels", true) == false, "The view labels layer is off (the UI draws its own)")
	game._update_hud()
	check(game.clock_label.text.begins_with("Quedan") and game.state_label.text.find("Peligro") >= 0, "Countdown and risk are shown")
	# Ronda 4 (ui_feel): un solo reloj en el panel, sin jerga, rotulos limpios, siluetas separadas y parte de derrota concreto
	check(game.state_label.text.find("Quedan") < 0 and game.state_label.text.find("cierra en") < 0, "R4: el panel de estado no repite el reloj principal")
	var jargon_txt: String = (game.state_label.text + game.goal_label.text + game.info_label.text).to_lower()
	var jargon_ok := true
	for bad in ["sin confirmar", "dudoso", "zoc", "halted_by_expiry", "(diseño)", "(ubicación hipotética)"]:
		if jargon_txt.find(bad) >= 0:
			jargon_ok = false
	check(jargon_ok, "R4: el panel no usa jerga ni etiquetas de trabajo")
	check(game._clean_label("Buque Justina (ubicación hipotética)") == "Buque Justina" and game._clean_label("Camino de la barranca (diseño)") == "Camino de la barranca", "R4: los rotulos del mapa no llevan etiquetas de fuente")
	var gdisp: Dictionary = game._group_disp()
	var seps_ok := gdisp.size() >= 2
	var ids_d: Array = gdisp.keys()
	for i in range(ids_d.size()):
		for j in range(i + 1, ids_d.size()):
			var da: Vector2 = gdisp[ids_d[i]].disp
			var db: Vector2 = gdisp[ids_d[j]].disp
			if absf(da.x - db.x) < game._sil_k() * 0.9 and absf(da.y - db.y) < game._sil_k() * 1.2:
				seps_ok = false
	check(seps_ok and game._sil_k() >= 30.0, "R4: las siluetas de grupo miden >= 30 px y no se pisan entre si")
	var story: Dictionary = game._defeat_story({"elapsed": 215.0, "stumbles": 0, "counter_hits": 0, "shots_taken": 0})
	check(str(story.get("cause", "")).find("03:35") >= 0 and str(story.get("advice", "")).find("Probá de nuevo con lo que anotaste") < 0, "R4: la derrota dice cuando paso y da un consejo concreto")
	# Vista previa de ruta y confirmacion por tramo sin reconocer
	game._select_ids(["guemes"])
	game._center_on(Vector2(280, 264))
	game.camera_distance = 300.0
	game._apply_camera()
	var wet_pt := Vector2(280, 264)
	game._set_preview_point(wet_pt, true)
	check(game.hover_info.get("kind", "") == "route" and bool(game.hover_info.ok), "Aiming a destination calls plan_route and keeps a preview")
	check(str(game.hover_info.text).find("riesgo alto") >= 0 or str(game.hover_info.text).find("riesgo desconocido") >= 0, "Preview towards unexplored water shows high risk: " + str(game.hover_info.text))
	check(str(game.hover_info.text).find("sin reconocer") >= 0, "Preview reports metres without reconnaissance")
	var wet_screen: Vector2 = game.camera.unproject_position(Vector3(wet_pt.x, 0, wet_pt.y))
	_mouse_click(wet_screen, MOUSE_BUTTON_RIGHT)
	check(game.rules.get_unit("guemes").order.is_empty() and game.pending_pt != null, "A route over unknown water asks for confirmation first")
	_mouse_click(wet_screen, MOUSE_BUTTON_RIGHT)
	check(game.rules.get_unit("guemes").order.get("action", "") == "move", "The second right click confirms the move")
	game._do_action("cancel")
	check(game.rules.get_unit("guemes").order.is_empty(), "Cancel clears the order")
	# El mismo tramo, ya sondeado, deja de ser riesgoso
	# Con la nueva geografia el rio alto no deja sondear: se espera a que baje (bajante desde 60 s).
	game.paused = false
	var water_start: float = game.rules.water_level_m()
	for i in range(40):
		if float(game.rules.state.get("t", 0.0)) >= 260.0:
			break
		_play_step(10.0)
	game.paused = true
	check(game.rules.water_level_m() < water_start, "The river drops while the scout works")
	game.paused = false
	game._select_ids(["scout_1"])
	game._do_action("probe")
	check(game.aim == "probe", "Reconocer enters aiming mode")
	game._set_preview_point(Vector2(330, 264), true)
	check(str(game.hover_info.text).find("sondeo de") >= 0, "Probe preview shows length and time: " + str(game.hover_info.text))
	game._aim_click(Vector2(200, 264), true)
	check(game.aim == "probe" and game.aim_pts.size() == 1, "Shift keeps adding probe points")
	game._aim_click(Vector2(330, 264), false)
	check(game.aim == "" and game.rules.scouts()[0].stage != "idle", "The last click orders the probe")
	for i in range(40):
		_play_step(10.0)
		if game.rules.scouts()[0].stage == "idle":
			break
	game.paused = true
	check(game.rules.probes().size() >= 1 and game.rules.knowledge_at(250, 264) in ["probed", "marked", "visible"], "The probed lane is now known")
	game._select_ids(["guemes"])
	game._set_preview_point(Vector2(240, 264), true)
	check(float(game.hover_info.plan.unknown_m) < 1.0 and str(game.hover_info.risk) in ["bajo", "medio"], "Probing the same stretch lowers the risk: " + str(game.hover_info.text))
	# Marcar vado (el explorador 1 puede haber caído bajo el fuego del buque: marca el 2 sobre el carril ya sondeado)
	game._select_ids(["scout_2"])
	var balizas0: int = int(game.rules.resources().balizas)
	game._do_action("mark_ford")
	game._aim_click(Vector2(230, 264), true)
	game._aim_click(Vector2(250, 264), false)
	game.paused = false
	for i in range(12):
		_play_step(5.0)
		if int(game.rules.resources().balizas) < balizas0:
			break
	game.paused = true
	check(int(game.rules.resources().balizas) < balizas0, "Marking a ford spends beacons (as the work advances: %d -> %d)" % [balizas0, int(game.rules.resources().balizas)])
	# Orden de avance, ritmo y paso hasta el abordaje
	game._select_ids(["guemes"])
	game._do_action("signal_liniers")
	game.paused = false
	for i in range(30):
		_play_step(10.0)
		if bool(game.rules.resources().advance_authorized):
			break
	check(bool(game.rules.resources().advance_authorized), "Signalling Liniers grants the advance order")
	game.paused = true
	game._update_hud()
	await _frames(2)
	# El planificador rechaza abordar mientras el fondo estimado del vado del buque supera el limite del caballo:
	# se deja correr el tiempo (baja el rio) hasta que lo acepta, como hace la estrategia "central a ciegas".
	game.paused = false
	for i in range(80):
		if bool(game.rules.action_availability("guemes", "board", game.rules.board_point()).ok):
			break
		_play_step(5.0)
	game.paused = true
	game._update_hud()
	await _frames(2)
	game._select_ids(["guemes", "arias", "zavala"])
	check(not game.action_buttons["board"].disabled, "Board is available once the advance order exists")
	game._do_action("board")
	var ordered := 0
	for u in game.rules.state.units:
		if str(u.order.get("action", "")) == "board":
			ordered += 1
	if ordered == 0:
		check(game.confirm_action == "board", "Board toward unexplored water asks for a second press")
		game._do_action("board")
		for u in game.rules.state.units:
			if str(u.order.get("action", "")) == "board":
				ordered += 1
	check(ordered == 3, "Board is ordered for the three selected groups")
	game.paused = false
	for i in range(120):
		_play_step(10.0)
		if game.rules.state.status != "playing":
			break
	game.paused = true
	await process_frame
	check(game.rules.state.status in ["victory", "defeat"] and game.outcome_shown, "A scripted blind crossing (no reconnaissance, no support) ends the game (%s, %s) and opens the campaign report" % [game.rules.state.status, str(game.rules.state.get("defeat_cause", ""))])
	check(is_instance_valid(game.modal), "The campaign report is a modal")
	var won_run: bool = game.rules.state.status == "victory"
	var ot := _modal_text()
	if won_run:
		check(ot.find("MEDALLA DE") >= 0 and ot.find("Seguir: Humahuaca") >= 0 and bool(game.progress.justina_ganada), "R1/D-03: la victoria muestra medalla y el paso al nivel II (Humahuaca), y fija el progreso")
	else:
		check(ot.find("Probá esto") >= 0 and ot.find("Reintentar") >= 0 and ot.find("Seguir: Humahuaca") < 0 and ot.find("Sostener el norte") < 0 and ot.find("campaña del norte") < 0, "R1: la derrota explica y ofrece reintentar, nunca el nivel siguiente")
	var rep: Dictionary = game.rules.campaign_report()
	game._report_dialog(true)
	var mt := _modal_text()
	check(mt.find(str(rep.outcome_title)) >= 0 or mt.find(str(rep.reason)) >= 0, "The report shows the title/outcome of campaign_report()")
	for g in rep.groups:
		check(mt.find(str(g.name)) >= 0, "The report lists group " + str(g.name))
	check(mt.find("Qué fue historia") >= 0 and mt.find("Tradición") >= 0 and mt.find("Documentado") >= 0, "The report ends with 'Qué fue historia' tagged lines")
	check((_find_button("Seguir: Humahuaca") != null) == won_run, "The full report offers the next level (II, Humahuaca) after a win and only then")
	_layout_checks("Justina parte")
	game._outcome_dialog()
	check(_press("Rejugar") if won_run else _press("Reintentar"), "Outcome provides a working restart")
	await process_frame
	await process_frame
	check(game.rules.state.status == "playing" and float(game.rules.state.capture) == 0, "Restart resets capture and terminal state")
	game._close_modal()
	# Derrota por plazo
	for i in range(20):
		game.rules.tick(60)
	game._process(0.0)
	await process_frame
	check(game.rules.state.status == "defeat" and game.outcome_shown, "Passivity ends in defeat and opens the report")
	check(_find_button("Reintentar") != null, "Defeat also permits immediate restart")
	game._close_modal()
	# Retirada general con confirmacion
	game.forced_seed=1806
	game._start_game("justine")
	game._close_modal()
	game._do_action("retreat_all")
	check(is_instance_valid(game.modal) and game.rules.state.status == "playing", "Retirada general asks for confirmation")
	check(_modal_text().find("Distinta de «Retirar» (L)") >= 0, "R7: la retirada general explica la diferencia con Retirar (L)")
	check(game.action_buttons["retreat_all"].tooltip_text.find("PELIGRO") >= 0, "R7: Retirada general se marca como peligrosa en su tooltip")
	check(_press("Sí, terminar la partida"), "Retirada general can be confirmed")
	check(game.rules.state.status == "defeat", "Confirmed retreat ends the game")
	game._process(0.0)
	game._close_modal()
	# Parte parcial con P
	game.forced_seed=1806
	game._start_game("justine")
	game._close_modal()
	_key(KEY_P)
	check(is_instance_valid(game.modal) and _modal_text().find("parcial") >= 0, "P opens a partial report during play")
	game._close_modal()
	# Guardado de version anterior: motivo + Nueva partida
	if game.rules.has_method("load_game") and "load_reject" in game.rules:
		game.rules.load_reject = true
		_key(KEY_F9)
		check(is_instance_valid(game.modal) and _modal_text().find("versión anterior") >= 0, "A rejected old save shows the reason")
		check(_find_button("Nueva partida") != null, "...and offers a new game")
		game._close_modal()
	# Textos prohibidos
	game.forced_seed=1806
	game._start_game("justine")
	game._close_modal()
	game._select_ids(["guemes"])
	await _frames(2)
	var all_text := _ui_text(game.ui).to_lower()
	check(all_text.find("fragata") < 0 and all_text.find("goleta") < 0, "No UI text says fragata or goleta")
	check(all_text.find("güemes mandó") < 0 and all_text.find("güemes comandó") < 0 and all_text.find("al mando de güemes") < 0, "No UI text states that Guemes commanded")
	check(game.sel_info.text.find("Tradición") >= 0, "The vanguard shows its Tradición label when selected")
	game.forced_seed=1806
	game._start_game("justine")
	game._close_modal()
	var cp = game.rules.campaign_report()
	for h in cp.history:
		check(str(h.text).to_lower().find("fragata") < 0 and str(h.text).to_lower().find("goleta") < 0, "History line without fragata/goleta")

# ------------------------------------------------------------------ Norte
func _norte() -> void:
	game.rules = RealRules.new()
	game.world_script = RealWorld
	game._return_menu()
	await process_frame
	check(game.mode == "menu", "Return-menu flow reaches scenario selection")
	game.campaign.data.north_unlocked = false
	game._progress_sync()
	game._menu()
	await process_frame
	var north_btn := _find_button("SOSTENER EL NORTE")
	check(north_btn != null and north_btn.disabled and north_btn.text.find("Ganá la Justina para abrirlo") >= 0, "R1: sin haber ganado la Justina el Norte esta con candado")
	game.campaign.data.north_unlocked = true
	game._progress_sync()
	game._menu()
	await process_frame
	north_btn = _find_button("SOSTENER EL NORTE")
	check(north_btn != null and not north_btn.disabled, "R1: tras ganar la Justina el Norte se abre")
	check(_press("SOSTENER EL NORTE"), "North starts through its menu button")
	await process_frame
	check(game.rules.state.scenario == "norte" and game.world.scenario == "norte", "Northern rules and world agree")
	check(game.rules.state.round == 1, "Northern scenario starts in round one")
	check(game.action_buttons.has("protect") and not game.action_buttons.protect.disabled, "Initial legal resource order is available")
	check(_press("Proteger víveres"), "Campaign action button is connected")
	check(game.rules.get_unit("guemes").order.get("action", "") == "protect", "Action closure queues the intended campaign action")
	check(_press("2 · Arias"), "Arias can be selected from the HUD")
	game.sector = "quebrada"
	game._refresh_actions()
	game._update_hud()
	check(_press("Reconocer"), "Legal neighboring reconnaissance is available")
	check(game.rules.get_unit("arias").order.get("action", "") == "scout", "Reconnaissance is queued for Arias")
	game.jev.force_local = true
	check(_press("Resolver ronda"), "Round-resolution button is connected")
	check(game.pending_round, "Round enters bounded asynchronous preparation")
	for i in range(6):
		await process_frame
	check(not game.pending_round and int(game.rules.state.round) == 2, "Local fallback completes one real round")
	check(game.rules.state.external_decisions.size() == 1, "Exactly one applied intention is recorded")
	check(game.rules.state.external_decisions[0].source == "local_fallback", "Offline intent is labeled accurately")
	var after_round := int(game.rules.state.round)
	game._resolve_round()
	check(int(game.rules.state.round) == after_round and not game.pending_round, "Repeated resolution during animation does not duplicate the round")
	game._process(1.0)
	check(FileAccess.file_exists(game._save_path("norte")), "Round completion automatically saves the campaign")

	game._start_game("norte")
	game.jev.force_local = true
	game._campaign_order("protect")
	game._save_game(false)
	var saved_bytes := FileAccess.get_file_as_string(game._save_path("norte"))
	var saved_game_id: String = str(game.rules.state.game_id)
	game._resolve_round()
	game._save_game(false)
	check(FileAccess.get_file_as_string(game._save_path("norte")) == saved_bytes, "Save during a pending request does not overwrite the last complete save")
	game._load_game("norte")
	for i in range(6):
		await process_frame
	check(not game.pending_round and int(game.rules.state.round) == 1, "Loading during a request discards the old round response")
	check(game.rules.state.external_decisions.is_empty(), "Late response is not appended after loading")
	check(str(game.rules.state.game_id) != saved_game_id, "Loading campaign changes request identity")
	check(game.rules.get_unit("guemes").order.get("action", "") == "protect", "Campaign load restores the pending player order")
	game._process(1.0)
	var invalid_save := FileAccess.open(game._save_path("norte"), FileAccess.WRITE)
	invalid_save.store_string("invalid JSON")
	invalid_save.close()
	game._resolve_round()
	var before_invalid_load: String = str(game.rules.state.game_id)
	_key(KEY_F9)
	for i in range(3):
		await process_frame
	check(str(game.rules.state.game_id) == before_invalid_load and int(game.rules.state.round) == 1, "Failed load preserves the active campaign")
	check(not game.pending_round and not game.action_buttons.protect.disabled, "Failed load during a request restores legal action controls")
	game._save_game(false)
	game._resolve_round()
	var restarted_id: String = str(game.rules.state.game_id)
	_key(KEY_R)
	for i in range(3):
		await process_frame
	check(is_instance_valid(game.modal) and str(game.rules.state.game_id) == restarted_id, "R asks for confirmation and does not restart by itself")
	game._do_restart()
	for i in range(6):
		await process_frame
	check(str(game.rules.state.game_id) != restarted_id and int(game.rules.state.round) == 1, "Restart during a pending round begins a clean match")
	check(not game.pending_round and game.rules.state.external_decisions.is_empty(), "Restart leaves no stale decision or pending lock")

# ------------------------------------------------------------------ transiciones entre niveles (P4: T-001, T-003, T-004)
func _world_envs() -> Array:
	return game.find_children("*", "WorldEnvironment", true, false).filter(func(n): return n.is_inside_tree())

func _transiciones() -> void:
	# T-001: con el II vivo, empezar el III (o cargarlo) libera el II en el mismo cuadro: un solo ambiente, sin lluvia, cámara del Norte.
	game._menu()
	await _frames(2)
	game._start_game("humahuaca")
	await _frames(4)
	check(game.mode == "hx" and is_instance_valid(game.hx), "T-001: el nivel II arranca (controlador vivo)")
	game._start_game("norte")
	await process_frame
	var envs := _world_envs()
	check(envs.size() == 1 and is_instance_valid(game.world) and game.world.is_ancestor_of(envs[0]), "T-001: tras _start_game(\"norte\") con el II vivo queda un solo WorldEnvironment y es el del Norte (%d)" % envs.size())
	check(game.find_children("lluvia_rayas", "", true, false).is_empty(), "T-001: no queda la lluvia del II")
	check(game.hx == null and game.mode == "play" and str(game.rules.state.scenario) == "norte", "T-001: el controlador del II quedó liberado y el Norte está en juego")
	check(game.camera.current and is_equal_approx(game.camera.far, 400.0) and game.camera.position.distance_to(game.camera_target) < 200.0, "T-001: la cámara es la del Norte (far %.0f, a %.0f m del objetivo)" % [game.camera.far, game.camera.position.distance_to(game.camera_target)])
	game._save_game(false)
	game._start_game("humahuaca")
	await _frames(4)
	game._load_game("norte")
	await process_frame
	check(_world_envs().size() == 1 and game.hx == null and game.find_children("lluvia_rayas", "", true, false).is_empty() and str(game.rules.state.scenario) == "norte", "T-001: cargar el Norte con el II vivo también lo libera")
	# T-004: tras el III el menú vuelve con el plano lejano de arranque.
	game._menu()
	await process_frame
	check(is_equal_approx(game.camera.far, 4000.0), "T-004: tras el Norte el menú repone camera.far = 4000 (es %.0f)" % game.camera.far)
	# T-003: tras la Justina a 1280x720 el menú (y por lo tanto el II) vuelve con content_scale_factor 1.
	var old_size: Vector2i = root.size
	root.size = Vector2i(1280, 720)
	await _frames(3)
	game.forced_seed = 1806
	game._start_game("justine")
	await _frames(3)
	var cs_play: float = game.get_window().content_scale_factor
	game._menu()
	await _frames(3)
	check(is_equal_approx(game.get_window().content_scale_factor, 1.0), "T-003: tras la Justina el menú deja content_scale_factor en 1 (en juego era %.2f, en el menú %.2f)" % [cs_play, game.get_window().content_scale_factor])
	root.size = old_size
	await _frames(3)

# ------------------------------------------------------------------ progresión I -> II -> III y cierre (P4: D-03, D-04, D-05, D-09, V-01)
func _campana() -> void:
	game.campaign.data.north_unlocked = false
	game.campaign.data.justina_won = false
	game._progress_sync()
	game._menu()
	await _frames(2)
	var hxb := _find_button("HUMAHUACA")
	var nb := _find_button("SOSTENER EL NORTE")
	check(hxb != null and nb != null and hxb.clip_text and hxb.get_child_count() > 0 and hxb.get_theme_color("font_color").a == 0.0, "V-01: los niveles son tarjetas de capítulo (texto accesible oculto, rótulos propios)")
	var t1 := _ui_text(_find_button("EL RÍO OFRECE"))
	check(_ui_text(nb).find("CON CANDADO") >= 0 and (t1.find("EMPEZÁ ACÁ") >= 0 or t1.find("EN CURSO") >= 0), "V-01: la tarjeta dice el estado (I: empezá acá o en curso; III: con candado)")
	game.campaign.data.north_unlocked = true
	game.campaign.data.justina_won = true
	game._progress_sync()
	game._menu()
	await _frames(2)
	check(_ui_text(_find_button("HUMAHUACA")).find("RECOMENDADO AHORA") >= 0 and _ui_text(_find_button("SOSTENER EL NORTE")).find("RECOMENDADO") < 0, "D-03: tras ganar la Justina el menú recomienda el II, no el III")
	# Victoria de la Justina: el botón principal lanza el nivel II
	game.forced_seed = 1806
	game._start_game("justine")
	await _frames(2)
	game._close_modal()
	# P-003: cerrar con Esc la ventana de una decisión no la deja oculta con el reloj corriendo
	game.paused = false
	game.rules.state.pending_choice = {"title": "Un mensajero", "options": [{"id": "a", "label": "Opción A"}]}
	game._choice_dialog()
	game._close_modal()
	game._update_hud()
	check(game.paused and game.alert_panel.visible and game.alert_btn.text == "Ver la decisión", "P-003: tras cerrar una decisión pendiente el reloj sigue detenido y un aviso la vuelve a abrir")
	game._alert_click()
	check(is_instance_valid(game.modal) and game.modal.has_meta("choice"), "P-003: «Ver la decisión» reabre la ventana")
	game._close_modal()
	game.rules.state.pending_choice = {}
	game._update_hud()
	game.rules.state.status = "victory"
	game.rules.state.reason = "Buque capturado"
	game.rules.state.capture = 100.0
	game.attempt_logged = false
	game.beat_enabled = false
	game.campaign.data.justina_won = false  # primera victoria: es la que anuncia el desbloqueo
	game._outcome_dialog()
	await _frames(2)
	var vt := _modal_text()
	check(vt.find("Seguir: Humahuaca") >= 0 and vt.find("Se abrió el nivel II") >= 0 and vt.find("escenario 2") < 0, "D-03: la victoria de la Justina anuncia el nivel II y no dice «escenario 2»")
	check(_press("Seguir: Humahuaca"), "D-03: el botón principal de la victoria existe")
	await _frames(3)
	check(game.mode == "hx" and is_instance_valid(game.hx), "D-03: tras ganar la Justina el botón principal lleva al nivel II (Humahuaca)")
	# II -> III: el controlador sale con «norte» y main arranca el III limpio
	game.hx.exited.emit("norte")
	await _frames(2)
	check(game.mode == "play" and str(game.rules.state.scenario) == "norte" and game.hx == null and _world_envs().size() == 1, "D-03: la salida del II hacia el norte arranca el III sin restos del II")
	# III: metas a la vista, paso concreto y sin «Jev» para un perfil sin clave
	game._update_hud()
	var et: String = str(game.enemy_label.text)
	check(et.find("meta ≤ 22") >= 0 and et.find("meta ≤ 42") >= 0 and et.find("meta ≤ 45") >= 0 and et.find("de 7") >= 0 and et.find("ronda 10") >= 0, "D-05: el panel del III muestra las tres metas, la presión «x de 7» y la ronda 10")
	check(game.capture_bar.value < 1.0, "D-05: la barra de victoria arranca vacía (%.1f)" % game.capture_bar.value)
	check(str(game.tutorial_label.text).begins_with("Siguiente paso · Arias reconoce la Quebrada") and game.next_btn != null and game.next_btn.visible, "D-09: en la ronda 1 la guía da una orden concreta y un botón para prepararla")
	check(not game.jev_label.visible and _ui_text(game.ui).find("Jev") < 0, "D-09: sin clave configurada no aparece la palabra «Jev»")
	check(_press("Preparar la orden sugerida") and str(game.rules.get_unit("arias").order.get("action", "")) == "scout", "D-09: «Preparar» deja la orden sugerida preparada en un clic")
	# P-001: pasar el mouse por una orden no mueve la bandeja (el clic cae donde se apuntó)
	await _frames(2)
	var r0: Rect2 = game.action_buttons["scout"].get_global_rect()
	var rr0: Rect2 = game.round_button.get_global_rect()
	game._show_campaign_reason("assault")
	await _frames(2)
	check(game.action_buttons["scout"].get_global_rect() == r0 and game.round_button.get_global_rect() == rr0, "P-001: la ayuda de una orden no cambia el alto de la bandeja (%s -> %s)" % [str(r0), str(game.action_buttons["scout"].get_global_rect())])
	game._show_campaign_reason("")
	var asec: String = str(game.rules.get_unit("arias").sector_id)
	game.rules.get_sector(asec).known = true
	game.rules.get_sector("humahuaca").known = true
	var fake := {"id": "guemes", "strength": 100.0, "supply": 100.0, "fatigue": 0.0, "sector_id": "humahuaca"}
	check(game.rules.campaign_order_reason("arias", "assault", asec).find("sector Humahuaca") >= 0 and str(game.rules._validate_campaign_order(fake, "assault", "humahuaca").reason).find("Arias") >= 0, "P-010: el bloqueo de «Operar en Humahuaca» dice qué falta (sector o agrupación)")
	# D-04: fin del III -> pantalla final con «En tu partida» y «En la historia»
	game.rules.state.status = "victory"
	game.rules.state.reason = "La presión volvió insostenible la invasión y forzó su retirada."
	game._outcome_dialog()
	await _frames(2)
	var ft := _modal_text()
	check(ft.find("EN TU PARTIDA") >= 0 and ft.find("EN LA HISTORIA") >= 0 and ft.find("La Justina · 1806") >= 0 and ft.find("Humahuaca · 1817") >= 0 and ft.find("Sostener el norte") >= 0, "D-04: la pantalla final muestra I, II y III frente a la historia")
	check(ft.find("TRADICIÓN") >= 0 and ft.find("DOCUMENTADO") >= 0 and ft.find("DISEÑO") >= 0 and ft.find("tradición no probada") >= 0 and ft.find("no estuvo en el asalto") >= 0, "D-04: cada renglón histórico lleva su etiqueta y respeta las reglas de historia")
	check(ft.find("Infernales") < 0 and ft.find("coronel mayor") < 0 and ft.find("general Güemes") < 0 and ft.find("según La Serna") < 0, "D-04: sin afirmaciones vedadas por las reglas de historia")
	check(bool(game.campaign.data.north_won) and bool(game.campaign.data.north_played), "D-04: el resultado del III queda en el progreso")
	check(Rect2(Vector2.ZERO, game.get_viewport().get_visible_rect().size).encloses((game.modal.get_child(1) as Control).get_global_rect()) and game.modal.find_children("*", "ScrollContainer", true, false).is_empty(), "D-04: la pantalla final entra sin scroll")
	check(_press("Volver al menú"), "D-04: la pantalla final vuelve al menú")
	await _frames(2)
	check(game.mode == "menu" and _ui_text(_find_button("SOSTENER EL NORTE")).find("GANADA") >= 0, "D-04: tras la campaña el menú marca el III como ganado")

# P-007: ganar Humahuaca también abre el III (y queda en el progreso)
func _norte_por_humahuaca() -> void:
	game.campaign.data.north_unlocked = false
	game.campaign.data.justina_won = false
	game.campaign.save_progress()
	game._progress_sync()
	var f := FileAccess.open("user://humahuaca_progress.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "attempts": 1, "defeats_in_row": 0, "best_medal": "bronce", "won": true, "best_golpe": 61.0, "world_index": 1, "tutorial_seen": true, "diary": []}))
	f.close()
	game._menu()
	await _frames(2)
	var nb := _find_button("SOSTENER EL NORTE")
	check(nb != null and not nb.disabled and bool(game.campaign.data.north_unlocked), "P-007: ganar Humahuaca abre el III en el menú y en el progreso")
	check(_ui_text(_find_button("HUMAHUACA")).find("GANADA") >= 0 and _ui_text(_find_button("EL RÍO OFRECE")).find("GANADA") < 0, "P-007: el menú no da por ganada la Justina por haber ganado Humahuaca")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://humahuaca_progress.json"))

# ------------------------------------------------------------------ utilidades
# P4b: P-005 (mensajes del contraataque), P-015 (un intento no jugado no cuenta), P-017 (ronda sin órdenes avisada), D-10 (la intención del
# invasor mostrada es la que se resuelve, por el camino real del juego) y P-019 (la ventana chica se ajusta a su contenido).
func _p4b() -> void:
	game.forced_seed = 1806
	game._start_game("justine")
	await _frames(2)
	check(is_instance_valid(game.modal) and game.right_panel.modulate.a < 0.01 and game.bottom_panel.modulate.a < 0.01, "P4b: con la pantalla de misión abierta el HUD queda apagado")
	game._intro_close()
	await _frames(1)
	check(game.right_panel.modulate.a > 0.99 and game.bottom_panel.modulate.a > 0.99 and game.right_panel.size.y < 600.0, "P4b: al cerrar la pantalla de misión vuelve el HUD, con su tamaño")
	# P-015
	var a0 := int(game.campaign.data.attempts)
	game._start_game("justine")
	await _frames(1)
	check(int(game.campaign.data.attempts) == a0, "P-015: empezar otro intento sin haber jugado el anterior no suma intentos (%d -> %d)" % [a0, int(game.campaign.data.attempts)])
	game._close_modal()
	# P-005: el contraataque llega con pausa automática y se rechaza con el reloj detenido
	game.settings.auto_pause = true
	game.settings.tutorial = true
	game.auto_start_pending = false
	var g: Dictionary = game.rules.get_unit("guemes")
	g.stage = "boarding"
	game.rules.state.ammo = 9
	game.rules.state.counter.active = true
	game.rules.state.counter.answered = false
	game.rules.state.counter.until = float(game.rules.state.elapsed) + 12.0
	game.paused = false
	game._select_ids(["guemes"])
	game._update_hud()
	check(game.paused and game.alert_panel.visible and game.pause_banner.text.find("rechazarlo") >= 0, "P-005: el contraataque pausa y pide rechazarlo")
	game._do_boarding_action("repel")
	game._update_hud()
	var b_txt: String = str(game.pause_banner.text) if game.pause_banner.visible else ""
	check(bool(game.rules.state.counter.answered) and not game.alert_panel.visible and b_txt.find("rechazarlo") < 0 and game.pause_banner.text.find("rechazarlo") < 0, "P-005: rechazado el contraataque, ningún cartel lo sigue pidiendo (cartel: «%s»)" % str(game.pause_banner.text))
	check(game.toast_label.text.find("rechaza") >= 0 and game.action_buttons["repel"].text.find("rechazado") >= 0, "P-005: el aviso y el botón dicen lo mismo: el contraataque está rechazado")
	check(game.tutorial_label.text.find("Abordaje: cuando el buque contraataque") < 0 or not game.hint_panel.visible, "P-005: el cartel del tutorial deja de pedir el rechazo una vez hecho")
	game.rules.state.counter.active = false
	game.settings.auto_pause = false
	game.pause_reason = ""
	game.paused = true
	g.stage = "ready"
	# P-015: volver al menú sin jugar descuenta el intento
	var a1 := int(game.campaign.data.attempts)
	game.rules.state.elapsed = 0.0
	game.rules.state.orders = []
	game.order_log = []
	game._menu()
	await _frames(1)
	check(int(game.campaign.data.attempts) == a1 - 1 or not game.rules.probes().is_empty(), "P-015: volver al menú sin jugar no cuenta el intento (%d -> %d)" % [a1, int(game.campaign.data.attempts)])
	# D-10 y P-017 por el camino real de la interfaz (_resolve_round con la alternativa local)
	game._start_game("norte")
	game.jev.force_local = true
	await _frames(1)
	if is_instance_valid(game.modal): game._close_modal()
	game._update_hud()
	check(str(game.enemy_label.text).find("Intención del invasor: no se sabe") >= 0, "D-10: sin reconocimiento la intención del invasor no se muestra")
	game._resolve_round()
	for i in range(6):
		await process_frame
	check(int(game.rules.state.round) == 2 and game.toast_label.text.find("sin órdenes") >= 0, "P-017: una ronda resuelta sin órdenes lo avisa: " + str(game.toast_label.text))
	game.rules.issue_campaign_order("arias", "scout", "quebrada")
	game.resolution_remaining = 0.0
	game._resolve_round()
	for i in range(6):
		await process_frame
	game.resolution_remaining = 0.0
	var shown := 0
	var matched := 0
	for k in range(8):
		if str(game.rules.state.status) != "playing":
			break
		# Se sigue reconociendo donde está el invasor (o hacia donde avanza) para que haya varias rondas con inteligencia.
		for uid in ["guemes", "zavala"]:
			for target in [str(game.rules.state.enemy.position), "jujuy", "quebrada"]:
				if game.rules.issue_campaign_order(uid, "scout", target).ok:
					break
		game._update_hud()
		var intel: Dictionary = game.rules.north_enemy_intel()
		var et: String = str(game.enemy_label.text)
		if bool(intel.get("known", false)):
			shown += 1
		game._resolve_round()
		for i in range(6):
			await process_frame
		game.resolution_remaining = 0.0
		if bool(intel.get("known", false)) and et.find("INTENCIÓN DEL INVASOR") >= 0 and et.find(str(intel.label)) >= 0 and str(game.rules.state.enemy.intent) == str(intel.intent):
			matched += 1
	check(shown >= 2 and matched == shown, "D-10: con reconocimiento reciente la interfaz muestra la intención y es la que se resuelve (%d de %d rondas)" % [matched, shown])
	# P-019: la ventana chica se ajusta al alto de su contenido
	game._round_report()
	await _frames(3)
	var panel := game.modal.get_child(1) as Control
	check(panel.size.y <= panel.get_combined_minimum_size().y + 10.0 and panel.size.y < 560.0, "P-019: «Consecuencias de la ronda» no deja espacio vacío abajo (alto %.0f)" % panel.size.y)
	game._close_modal()

# ------------------------------------------------------------------ corrección QA ronda 2 (Q-101, Q-102, Q-103, Q-104, Q-105, Q-107)
func _qa_ronda2() -> void:
	# Q-101: una partida de la Justina a ×4 con «Pausa auto»: ningún aviso de campo baja la velocidad; los avisos críticos pausan y al
	# reanudar (Espacio) vuelve la velocidad elegida. Se juega con el _process real (1 s de juego por paso) y se deciden los mensajeros.
	game.forced_seed = 1806
	game._start_game("justine")
	await _frames(2)
	if is_instance_valid(game.modal): game._close_modal()
	game.settings.auto_pause = true
	game.settings["auto_fast"] = false
	game.auto_start_pending = false
	game.rules.issue_scout("scout_1", "probe", [Vector2(200, 264), Vector2(330, 264)])
	game._set_speed(4.0)
	game.paused = false
	var fe0: int = (game.rules.state.events_done as Array).size()
	var drops := 0
	var resumes := 0
	var resume_kept := 0
	var choices := 0
	var steps := 0
	while str(game.rules.state.status) == "playing" and float(game.rules.state.elapsed) < 450.0 and steps < 1500:
		steps += 1
		if is_instance_valid(game.modal):
			var pc: Dictionary = game.rules.state.get("pending_choice", {})
			if game.modal.has_meta("choice") and not pc.is_empty():
				game._choice_pick(str(pc.options[0].id))
				choices += 1
			else:
				game._close_modal()
			continue
		if game.paused:
			game._toggle_pause()  # Espacio: con una decisión pendiente la reabre; si no, reanuda
			if not game.paused and not is_instance_valid(game.modal):
				resumes += 1
				if game.speed == 4.0: resume_kept += 1
			continue
		game._process(0.25)
		if not game.paused and not is_instance_valid(game.modal) and game.speed != 4.0:
			drops += 1
		await process_frame
	var fired: int = (game.rules.state.events_done as Array).size() - fe0
	check(fired >= 7 and choices >= 1 and drops == 0, "Q-101: a ×4, %d avisos de campo y %d decisiones no bajan la velocidad (%d caídas; reloj %.0f s)" % [fired, choices, drops, float(game.rules.state.elapsed)])
	check(resumes >= 1 and resume_kept == resumes, "Q-101: después de cada pausa automática, Espacio reanuda a la velocidad elegida (%d de %d)" % [resume_kept, resumes])
	# Q-101 sin «Pausa auto»: solo un aviso crítico baja a ×1, y la velocidad elegida vuelve sola cuando el aviso se resuelve.
	game.forced_seed = 1806
	game._start_game("justine")
	await _frames(2)
	if is_instance_valid(game.modal): game._close_modal()
	game.settings.auto_pause = false
	game.auto_start_pending = false
	game._set_speed(4.0)
	game.paused = false
	game._handle_events([{"kind": "liniers", "text": "Liniers: «Quedan seis minutos de plazo.»", "field_event": "liniers_3"}, {"kind": "tide", "text": "El río llegó a su mínimo.", "field_event": "rio_minimo"}])
	check(game.speed == 4.0, "Q-101: sin pausa automática, un aviso de campo no baja la velocidad (×%d)" % int(game.speed))
	var g: Dictionary = game.rules.get_unit("guemes")
	g.stage = "boarding"
	game.rules.state.ammo = 9
	game.rules.state.counter.active = true
	game.rules.state.counter.answered = false
	game.rules.state.counter.until = float(game.rules.state.elapsed) + 12.0
	game._select_ids(["guemes"])
	game._update_hud()
	check(game.speed == 1.0 and int(game.speed_restore) == 4 and not game.paused, "Q-101: sin pausa automática, el contraataque (aviso crítico) baja a ×1 y recuerda ×4")
	game._do_boarding_action("repel")
	if is_instance_valid(game.modal): game._close_modal()
	game.paused = false
	for k in range(16):
		game._update_hud()
		game._feel_tick(0.25)
	check(game.speed == 4.0 and bool(game.rules.state.counter.answered), "Q-101: rechazado el contraataque, vuelve sola la velocidad elegida (×%d)" % int(game.speed))
	game.rules.state.counter.active = false
	g.stage = "ready"
	# Q-102: con una decisión cerrada por Esc, Espacio la reabre y el reloj no corre (con y sin pausa automática)
	for ap in [false, true]:
		game.forced_seed = 1806
		game._start_game("justine")
		await _frames(2)
		if is_instance_valid(game.modal): game._close_modal()
		game.settings.auto_pause = ap
		game.auto_start_pending = false
		game.paused = false
		var t_now := float(game.rules.state.elapsed)
		game.rules.state.pending_choice = {"id": "prueba", "title": "Un mensajero", "default": "a", "until": t_now + 25.0, "options": [{"id": "a", "label": "Opción A"}]}
		game._choice_dialog()
		_key(KEY_ESCAPE)
		game._update_hud()
		check(game.paused and game.alert_btn.text == "Ver la decisión" and game.alert_label.text.find("reloj sigue detenido") >= 0, "Q-102 (pausa auto %s): Esc deja la decisión esperando con el reloj detenido" % str(ap))
		_key(KEY_SPACE)
		check(is_instance_valid(game.modal) and game.modal.has_meta("choice") and game.paused, "Q-102 (pausa auto %s): Espacio reabre la decisión en vez de largar el reloj" % str(ap))
		_key(KEY_ESCAPE)
		game.paused = false  # aunque algo suelte la pausa (la primera orden, un clic en «Reanudar»), el reloj no corre con la decisión pendiente
		for k in range(12):
			game._process(0.25)
		check(is_equal_approx(float(game.rules.state.elapsed), t_now) and game.paused and game.mode_label.text.find("PAUSA") >= 0, "Q-102 (pausa auto %s): con la decisión pendiente el reloj no avanza (%.2f -> %.2f s) y la cabecera dice pausa" % [str(ap), t_now, float(game.rules.state.elapsed)])
		game._alert_click()
		check(is_instance_valid(game.modal) and game.modal.has_meta("choice"), "Q-102 (pausa auto %s): «Ver la decisión» la vuelve a abrir" % str(ap))
		game._choice_pick("a")
		game.paused = false
		game._process(0.25)
		check(float(game.rules.state.elapsed) > t_now and not game.paused, "Q-102 (pausa auto %s): elegida la opción, el reloj vuelve a correr" % str(ap))
	game.settings.auto_pause = false
	# Q-103: Esc cierra el parte de victoria, pero se puede reabrir (P, Espacio, el botón de la cabecera, la pausa) y la pausa de una partida
	# terminada no ofrece «Abandonar» ni «Seguir jugando».
	game.forced_seed = 1806
	game._start_game("justine")
	await _frames(2)
	if is_instance_valid(game.modal): game._close_modal()
	game.rules._finish("victory", "La dotación se rinde. El buque queda capturado.", "capturado")
	game._process(0.0)
	await _frames(2)
	check(is_instance_valid(game.modal) and _find_button("Seguir: Humahuaca") != null, "Q-103: el parte de victoria ofrece «Seguir: Humahuaca»")
	_key(KEY_ESCAPE)
	game._update_hud()
	check(not is_instance_valid(game.modal) and game.pause_button.text.find("Ver el parte") >= 0 and game.reason_label.text.find("Ver el parte") >= 0, "Q-103: tras Esc, la cabecera y la línea «AHORA» ofrecen «Ver el parte» (botón: «%s»)" % game.pause_button.text)
	_key(KEY_P)
	check(is_instance_valid(game.modal) and _find_button("Seguir: Humahuaca") != null, "Q-103: P reabre el parte con «Seguir: Humahuaca»")
	_key(KEY_ESCAPE)
	_key(KEY_SPACE)
	check(is_instance_valid(game.modal) and _find_button("Seguir: Humahuaca") != null, "Q-103: Espacio (y el botón «Ver el parte») también lo reabren")
	_key(KEY_ESCAPE)
	_key(KEY_ESCAPE)
	var pm := _modal_text()
	check(is_instance_valid(game.modal) and pm.find("Abandonar") < 0 and pm.find("Seguir jugando") < 0 and pm.find("Ver el parte") >= 0 and pm.find("Seguir: Humahuaca") >= 0, "Q-103: la pausa de una partida ganada ofrece «Ver el parte» y «Seguir: Humahuaca», sin «Abandonar»")
	check(_press("Ver el parte"), "Q-103: el botón «Ver el parte» de la pausa responde")
	check(is_instance_valid(game.modal) and _find_button("Seguir: Humahuaca") != null and _find_button("Rejugar") != null, "Q-103: «Ver el parte» de la pausa vuelve al parte de victoria")
	game._close_modal()
	# Q-105: la ficha 3 elegida durante el abordaje entra entera (sin «munici…») y el rótulo del paraje no queda detrás de «AGRUPACIONES»
	for id in ["guemes", "arias", "zavala"]:
		var u: Dictionary = game.rules.get_unit(id)
		u.stage = "boarding"
		u.fatigue = 30.0
	game.rules.state.status = "playing"
	game._select_ids(["zavala"])
	game._update_hud()
	await _frames(2)
	game._update_hud()
	var rb: Button = game.roster_buttons["zavala"]
	var fnt := rb.get_theme_font("font")
	var fs := rb.get_theme_font_size("font_size")
	var widest := 0.0
	for ln in rb.text.split("\n"): widest = maxf(widest, fnt.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	check(widest <= rb.size.x - 16.0 + 2.0 and rb.text.find("munición") >= 0, "Q-105: la ficha 3 desplegada entra entera (%d <= %d px): %s" % [int(widest), int(rb.size.x - 16.0), rb.text.replace("\n", " / ")])
	game.place_label.text = "Bajo el cursor: Agua turbia (sin reconocer)"
	game.place_label.visible = true
	await _frames(1)
	check(not game.place_label.get_global_rect().intersects(game.roster_panel.get_global_rect()) and not game.place_label.get_global_rect().intersects(game.minimap_rect()), "Q-105: el rótulo del paraje no asoma detrás de «AGRUPACIONES» ni pisa el minimapa")
	game.place_label.visible = false
	# Q-104 (III): al empezar, las tres agrupaciones quedan fuera de la ayuda «Siguiente paso» y del panel inferior
	game._start_game("norte")
	game.jev.force_local = true
	await _frames(4)
	if is_instance_valid(game.modal): game._close_modal()
	game._update_hud()
	await _frames(1)
	var band: Vector2 = game._norte_free_band()
	var hidden := []
	for u in game.rules.state.units:
		var gx := float(u.x) - 3.3
		var gz := float(u.z) + 2.8
		var sp: Vector2 = game.camera.unproject_position(game.world.to_global(Vector3(gx, game.world.terrain_height(gx, gz), gz)))
		if sp.y + 30.0 > band.y or sp.y - 40.0 < band.x: hidden.append("%s@%d" % [str(u.id), int(sp.y)])
	check(hidden.is_empty() and game.hint_panel.visible, "Q-104: en el primer cuadro del III ninguna agrupación queda bajo «Siguiente paso» (franja %s; tapadas: %s)" % [str(band), str(hidden)])
	# Q-107: el autoguardado de la ronda no pisa el F5; F9 carga el F5 y dice cuál cargó
	game._campaign_order("protect")
	_key(KEY_F5)
	check(FileAccess.file_exists(game._manual_save_path("norte")) and FileAccess.file_exists(game._save_path("norte")), "Q-107: F5 guarda aparte el guardado del jugador")
	game.resolution_remaining = 0.0
	game._resolve_round()
	for i in range(6):
		await process_frame
	game.resolution_remaining = 0.0
	check(int(game.rules.state.round) == 2, "Q-107: la ronda se resolvió (ronda %d) y se autoguardó" % int(game.rules.state.round))
	_key(KEY_F9)
	for i in range(3):
		await process_frame
	check(int(game.rules.state.round) == 1 and game.toast_label.text.find("guardado F5") >= 0 and game.toast_label.text.find("ronda 1") >= 0, "Q-107: F9 vuelve al F5 (ronda 1), no al autoguardado, y lo dice: «%s»" % game.toast_label.text)
	game._save_game(false)  # autoguardado (como el de cada ronda)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game._manual_save_path("norte")))
	_key(KEY_F9)
	for i in range(3):
		await process_frame
	check(game.toast_label.text.find("autoguardado") >= 0, "Q-107: sin F5, F9 carga el autoguardado y lo nombra: «%s»" % game.toast_label.text)

## Un paso del reloj por el _process real. Q-102: con una decisión pendiente el reloj de la Justina queda detenido hasta que se elige, así
## que el guion contesta como lo haría el plazo vencido (la opción por defecto, contada como «sin respuesta») y sigue.
func _play_step(dt: float) -> void:
	var pc: Dictionary = game.rules.state.get("pending_choice", {})
	if not pc.is_empty() and str(game.rules.state.status) == "playing":
		game.rules.resolve_choice(str(pc.get("default", pc.options[0].id)), true)
		if is_instance_valid(game.modal) and game.modal.has_meta("choice"): game._close_modal()
		game.paused = false
	game._process(dt)

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame

func _key(code: Key, shift := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	event.shift_pressed = shift
	game._unhandled_input(event)

func _mb(pos: Vector2, button: int, pressed: bool, shift := false, ctrl := false) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.position = pos
	e.global_position = pos
	e.button_index = button
	e.pressed = pressed
	e.shift_pressed = shift
	e.ctrl_pressed = ctrl
	return e

func _mouse_press(pos: Vector2, button: int, shift := false, ctrl := false) -> void:
	game._unhandled_input(_mb(pos, button, true, shift, ctrl))

func _mouse_release(pos: Vector2, button: int, shift := false, ctrl := false) -> void:
	game._input(_mb(pos, button, false, shift, ctrl))

func _mouse_move(pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	game._unhandled_input(e)

func _mouse_click(pos: Vector2, button: int, shift := false, ctrl := false) -> void:
	_mouse_press(pos, button, shift, ctrl)
	_mouse_release(pos, button, shift, ctrl)

func _wheel(pos: Vector2, up: bool) -> void:
	game._unhandled_input(_mb(pos, MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN, true))

func _screen(id: String) -> Vector2:
	return game.camera.unproject_position(game.world.unit_nodes[id].root.global_position)

func _modal_text() -> String:
	if not is_instance_valid(game.modal):
		return ""
	return _ui_text(game.modal)

func _ui_text(node: Node) -> String:
	var out := ""
	for n in node.find_children("*", "", true, false):
		if n is RichTextLabel:
			out += n.text + "\n"
		elif n is Label or n is Button:
			out += n.text + "\n"
		if n is Control and n.tooltip_text != "":
			out += n.tooltip_text + "\n"
	return out

func _justina_r1_ui() -> void:
	game.paused = true
	game._update_hud()
	check(game.mode_label.text.find("PAUSA") >= 0, "Header shows EN PAUSA while paused")
	game.settings.tutorial = true
	game.tut_step = 0
	game._update_hud()
	check(game.hint_panel.visible and game.tutorial_label.text.find("Espacio") >= 0 and not game.pause_banner.visible, "R1: while paused at the start the guide says Espacio starts the clock (no duplicate banner)")
	check(game.pause_button.text.find("Iniciar") >= 0, "Before the first second the pause button says Iniciar")
	game.paused = false
	game._update_hud()
	check(game.mode_label.text.begins_with("TIEMPO REAL") and game.mode_label.text.find("×1") >= 0, "Header shows TIEMPO REAL ×1 while running: " + game.mode_label.text)
	check(not game.pause_banner.visible, "The pause banner is hidden while the clock runs")
	game._set_speed(2.0)
	check(game.speed == 2.0 and game.mode_label.text.find("×2") >= 0 and game.speed_buttons[2].button_pressed, "The ×2 speed button sets the speed and the indicator")
	_key(KEY_F4)
	check(game.speed == 4.0 and game.speed_buttons[4].button_pressed, "F4 selects ×4")
	_key(KEY_F2)
	check(game.speed == 1.0, "F2 selects ×1")
	game.paused = true
	game._update_hud()
	# Panel lateral de agrupaciones
	check(game.roster_buttons.size() == 5 and game.roster_panel.is_visible_in_tree(), "The five-group side panel is always visible")
	for id in game.ALL_ACTORS:
		var ct: String = game.roster_buttons[id].text
		check(ct.find(game._order_text(id)) >= 0 and ct.find(game._short_name(id)) >= 0 and ct.find("Orden:") < 0, "Card %s shows name and current order" % id)
	for id in game.GROUP_IDS:
		check(game.roster_buttons[id].text.find("%d %%" % int(game.rules.get_unit(id).strength)) >= 0 and game.roster_buttons[id].text.find("munición") >= 0, "Card %s shows strength and ammunition" % id)
	game.roster_buttons["zavala"].pressed.emit()
	check(game.sel_ids == ["zavala"], "Clicking a side card selects that group")
	# Despliegue previo
	game._deploy_dialog()
	var dt := _modal_text()
	check(is_instance_valid(game.modal) and dt.find("Despliegue previo") >= 0 and dt.find("Explorador 1") >= 0 and dt.find("Punto de partida") >= 0, "The deployment dialog lists the five groups with starting points")
	game._close_modal()
	var g0: float = float(game.rules.get_unit("guemes").strength)
	var a0: float = float(game.rules.get_unit("arias").strength)
	var tr: Dictionary = game.rules.deploy_transfer("zavala", "arias", 5.0)
	check(bool(tr.ok) and float(game.rules.get_unit("arias").strength) == a0 + 5.0, "Deployment can move strength between groups: " + str(tr.reason))
	check(is_equal_approx(float(game.rules.campaign_report().groups[1].start_strength), a0 + 5.0), "The report uses the redeployed starting strength")
	var all_ok := true
	for i in range(5):
		if not bool(game.rules.deploy_transfer("zavala", "arias", 5.0).ok):
			all_ok = false
	check(not all_ok, "Deployment transfers stop at the +-15 limit")
	for gid in ["zavala", "arias"]:
		var base := 60.0 if gid == "zavala" else 70.0
		game.rules.state.stats.start_strength[gid] = base
		game.rules.get_unit(gid).strength = base
	check(not bool(game.rules.deploy_transfer("zavala", "zavala", 5.0).ok), "Deployment rejects the same group twice")
	check(g0 == 100.0, "Guemes keeps its starting strength")
	# Ronda 3: reubicar puntos de partida (limite 14 m, solo tierra firme) y textos de claridad
	var e0 := Vector2(float(game.rules.get_unit("arias").x), float(game.rules.get_unit("arias").z))
	var pl: Dictionary = game.rules.deploy_place("arias", e0.x, e0.y - 7.0)
	check(bool(pl.ok) and is_equal_approx(float(game.rules.get_unit("arias").z), e0.y - 7.0), "R3: deployment moves a starting point on dry land: " + str(pl.reason))
	check(not bool(game.rules.deploy_place("arias", e0.x, e0.y - 40.0).ok), "R3: deployment refuses a start more than 14 m from the original")
	check(not bool(game.rules.deploy_place("arias", e0.x + 12.0, e0.y).ok) or game.rules.water_depth_at(e0.x + 12.0, e0.y) <= 0.05, "R3: deployment never puts a group in the water")
	check(not bool(game.rules.deploy_place("nadie", 0.0, 0.0).ok), "R3: deployment rejects an unknown actor")
	game._deploy_nudge(0, Vector2(0, 7))
	game._close_modal()
	check(game.clock_label.text.ends_with("min") and game.clock_label.text.find("Quedan") == 0, "R3: the header says the remaining time is in minutes: " + game.clock_label.text)
	check(game._short_name("guemes").find("trad.") >= 0, "R3: the Guemes group name carries the tradition mark")
	game.rules.state.elapsed = 5.0
	check(not bool(game.rules.deploy_place("arias", e0.x, e0.y).ok), "R3: deployment is closed once the clock has run")
	game.rules.state.elapsed = 0.0
	game.rules.get_unit("arias").z = e0.y
	game.rules.get_unit("guemes").z = 240.0
	game._briefing_dialog()
	check(_modal_text().find("en seco") >= 0 and _modal_text().find("Baliza") >= 0, "R3: the help says Gillespie writes left dry and glosses baliza")
	game._close_modal()
	# Orden con ETA y deshacer
	game._select_ids(["guemes"])
	var sx: float = float(game.rules.get_unit("guemes").x)
	game._commit_move(Vector2(sx, 300.0), true)
	check(game.order_log.size() == 1 and str(game.rules.get_unit("guemes").order.get("action", "")) == "move", "A move order is given and logged")
	game._update_hud()
	check(game.roster_buttons["guemes"].text.find("ETA") >= 0, "The card shows the ETA of the order: " + game.roster_buttons["guemes"].text)
	check(game._eta_s("guemes") > 0.0, "ETA is positive for a moving group")
	game._do_action("undo")
	check(game.order_log.is_empty() and game.rules.get_unit("guemes").order.is_empty() and str(game.rules.get_unit("guemes").stage) == "ready", "Deshacer reverts the last order")
	game._update_hud()
	check(game.action_buttons["undo"].disabled, "Deshacer is greyed out with nothing to undo")
	# Acciones contextuales: motivo legible, siguiente paso, Volver sin error
	var bb: Button = game.action_buttons["board"]
	check(bb.disabled and str(bb.get_meta("why")).find("Pedir carga a Liniers") >= 0 and str(bb.get_meta("why")).find("K") >= 0, "Blocked board explains the Liniers chain in plain words: " + str(bb.get_meta("why")))
	game.settings.tutorial = true
	game.tut_step = 0
	game._update_hud()
	check(game.reason_label.text == "" and not game.reason_label.visible and game.hint_panel.visible, "R5/D-07: with the tutorial on there is a single guide message (the tray line is hidden): «" + game.reason_label.text + "»")
	var tut_prev: bool = bool(game.settings.tutorial)
	game.settings.tutorial = false
	game._update_hud()
	check(game.reason_label.text.find("En gris") < 0 and game.reason_label.text.count("
") == 0, "R3: la guia es una sola linea, sin la lista de acciones en gris")
	check(game.reason_label.text.begins_with("AHORA"), "With nothing hovered and no tutorial the bar says the next step: " + game.reason_label.text)
	check(game.reason_label.text.find("límite de 1 ") < 0 and game.reason_label.text.find("(tocá o pasá") < 0, "R5: the grey-reason note is not cut at the decimal: " + game.reason_label.text)
	check(game._player_text("Texto. La variante con el banco expuesto es una decisión pendiente tuya.").find("pendiente") < 0, "R5: production notes are stripped from player text")
	check(str(game._order_text("guemes")).length() > 0 and game._friendly_reason("board", "El fondo estimado en ese punto supera el límite de 1.3 m.").begins_with("El camino hasta el buque"), "R5: the board reason says to probe toward the ship first")
	game._show_action_info("board")
	check(game.reason_label.text.find("No disponible") >= 0 and game.reason_label.text.find("Liniers") >= 0, "Hovering a blocked action shows why")
	game._show_action_info("")
	game.settings.tutorial = tut_prev
	game._update_hud()
	check(str(game.action_buttons["board"].tooltip_text).find("No disponible ahora") >= 0 and str(game.action_buttons["board"].tooltip_text).find("Liniers") >= 0, "D-07: with the tutorial on, the blocked reason lives in the button tooltip (the tray does not change height under the cursor)")
	game._select_ids(["scout_1"])
	var rb: Button = game.action_buttons["recall"]
	check(not rb.disabled and str(rb.get_meta("why")).find("desconocida") < 0, "Volver is valid for a live scout (no 'Acción desconocida')")
	check(game.action_buttons.has("probe_careful") and game.action_buttons.has("mark_ford"), "Scout bar lists careful probe and mark ford")
	game._select_ids(["guemes"])
	check(game.action_buttons.has("repel") and game.action_buttons.has("evacuate") and game.action_buttons["repel"].disabled, "Group bar lists repel and evacuate (greyed out until a counterattack)")
	game._select_ids(["scout_1"])
	# Tutorial interactivo
	game.settings.tutorial = true
	game.tut_step = 0
	game._update_hud()
	check(game.hint_panel.visible and game.tutorial_label.text.begins_with("1/4"), "Tutorial step 1/4 is shown: " + game.tutorial_label.text)
	game._tut_skip()
	check(game.tutorial_label.text.begins_with("2/4"), "Tutorial steps can be skipped")
	game._tut_close()
	check(not game.hint_panel.visible and not bool(game.settings.tutorial), "The tutorial can be closed")
	game.settings.tutorial = true
	game.tut_step = 0
	# Avisos criticos con pausa automatica (contraataque)
	game.settings.auto_pause = true
	game.paused = false
	var saved_counter: Dictionary = game.rules.state.counter.duplicate(true)
	game.rules.state.counter.active = true
	game.rules.state.counter.answered = false
	game.rules.state.counter.until = float(game.rules.state.elapsed) + 14.0
	game._select_ids(["guemes"])
	game._update_hud()
	check(not game.paused and game.alert_panel.visible and game.alert_label.text.find("Ningún grupo aborda") >= 0, "Counterattack with nobody boarding warns, does not auto-pause and says what to do")
	check(game.action_buttons.has("repel") and not game.action_buttons["repel"].visible, "Rechazar is hidden while nobody is boarding")
	var boarder_r4: Dictionary = game.rules.get_unit("guemes")
	var stage_r4 = boarder_r4.stage
	boarder_r4.stage = "boarding"
	game.alert_ids_seen = {}
	game._update_hud()
	check(game.action_buttons["repel"].visible, "Rechazar appears when a group is boarding")
	check(game.paused and game.alert_panel.visible and game.alert_label.text.find("CONTRAATAQUE") >= 0 and game.alert_label.text.find("14") >= 0, "A counterattack alert pauses the game and shows the countdown: " + game.alert_label.text)
	check(game.pause_banner.text.find("PAUSA AUTOMÁTICA") >= 0 and not game.pause_banner.visible, "R1: the pause was automatic and its reason lives in the alert (the banner does not repeat it)")
	check(game.alert_btn.visible and game.alert_btn.text.find("Rechazar") >= 0, "The alert offers a Rechazar button")
	check(not game.hint_panel.visible, "The tutorial panel hides while a critical alert is on screen")
	check(game._reason_with_help("El fondo estimado en ese punto supera el límite de 1.3 m.").find("explorador") >= 0 and game._reason_with_help("La barranca solo se sube por las dos bajadas; ese punto no es transitable.").find("Camino de la barranca") >= 0, "Rejected destinations say the cause and the alternative")
	check(game._short_name("guemes").find("Güemes") >= 0 and game._card_text("guemes").find("◆") >= 0, "Güemes' card keeps his name and the tradition mark")
	check(game._deploy_consequences().find("Fuerza total") >= 0, "The deployment screen explains the consequences of strength")
	check(game.info_label.text.find("Captura del buque") >= 0 and game.info_label.text.find("Moral de la dotación") >= 0, "Capture and morale are labelled separately")
	# Ronda 2 (ui_feel): lenguaje sin jerga y tarjetas compactas
	game._select_ids(["guemes"])
	game._update_hud()
	check(game.phase_label.text.find("diseño") < 0 and game.left_foot.text.find("avisos") < 0 and game.state_label.text.find("ETA") < 0, "R2: la cabecera y el panel no traen etiquetas de diseño ni jerga: " + game.phase_label.text)
	check(game.deploy_btn.text.begins_with("Ajustar tropas") and game.roster_buttons["guemes"].custom_minimum_size.y > game.roster_buttons["zavala"].custom_minimum_size.y, "R2: el despliegue es opcional («Ajustar tropas») y solo la tarjeta elegida es grande")
	check(game._plain("Tropezaste en 1 pozo(s)") == "Tropezaste en 1 pozo" and game._plain("2 pozo(s)") == "2 pozos", "R2: el plural de pozo se arma bien")
	check(game.sel_info.text.find("Diseño") < 0 and game.sel_info.text.find("cansancio") >= 0 and game.sel_info.text.find("fatiga") < 0, "R2: la seleccion usa «cansancio» y no rotula todo como diseño")
	check(not game.auto_start_pending and game.TUT_STEPS.size() == 5 and game.TUT_STEPS[0].find("explorador") >= 0, "R2: el tutorial es corto y arranca por el explorador")
	boarder_r4.stage = stage_r4
	game.rules.state.counter = saved_counter
	game.settings.auto_pause = false
	game.alert_ids_seen = {}
	game.pause_reason = ""
	game.paused = true
	game._update_hud()
	check(not game.alert_panel.visible, "The alert disappears once the window is over")
	# Minimapa claro y camara libre
	check(game.mm_bar.is_visible_in_tree() and game.mm_bar.get_global_rect().end.y <= game.minimap_rect().position.y + 1.0, "The minimap has a camera bar above it")
	game._select_ids(["guemes"])
	game.paused = true
	game._update_hud()

func _layout_checks(label: String) -> void:
	var view := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	var rects: Array = []
	for panel in game.hud_panels:
		if is_instance_valid(panel) and panel.is_visible_in_tree():
			var r: Rect2 = panel.get_global_rect()
			rects.append(r)
			check(view.encloses(r), "%s: panel inside the viewport %s (%s)" % [label, str(view.size), str(r)])
	var n := 0
	for i in range(rects.size()):
		for j in range(i + 1, rects.size()):
			if (rects[i] as Rect2).intersects(rects[j]):
				n += 1
				print("OVERLAP ", label, " ", rects[i], " ", rects[j], " view=", view)
	check(n == 0, "%s: HUD panels do not overlap" % label)
	var cr: Rect2 = game.compass_rect()
	var mr: Rect2 = game.minimap_rect()
	var sr: Rect2 = game.scale_rect()
	check(view.encloses(mr) and view.encloses(sr), "%s: minimap and scale bar inside the screen" % label)
	check(mr.encloses(cr), "%s: compass sits in the minimap corner" % label)
	for p in game.hud_panels:
		if p != game.map_widget and is_instance_valid(p) and p.is_visible_in_tree():
			check(not (p.get_global_rect() as Rect2).intersects(mr) and not (p.get_global_rect() as Rect2).intersects(sr), "%s: minimap and scale bar are clear of other panels" % label)

func _find_button(part: String) -> Button:
	if game == null or not is_instance_valid(game.ui):
		return null
	for node in game.ui.find_children("*", "Button", true, false):
		if str(node.text).contains(part):
			return node
	return null

func _press(part: String) -> bool:
	var button := _find_button(part)
	if button == null or button.disabled:
		return false
	button.pressed.emit()
	return true

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)

func _finish() -> void:
	report.checks = checks
	report.failures = failures
	report.ok = failures.is_empty()
	# El informe va a user:// (no ensucia un archivo versionado). Para publicarlo como evidencia: --evidence=<carpeta res://...>
	var out_path := "user://integration-test-results.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence="):
			out_path = arg.trim_prefix("--evidence=").path_join("integration-test-results.json")
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(arg.trim_prefix("--evidence=")))
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

# ------------------------------------------------------------------ sustitutos del contrato
## NO son el juego: no validan el fondo, la fisica, el fuego ni el equilibrio del escenario.

class StubRules extends RefCounted:
	var state: Dictionary = {}
	var _m: Dictionary = {}
	var _events: Array = []
	var load_reject := false
	var calls := {"plan_route": 0}
	const HITO := {"muster": Vector2(14, 225), "resupply": Vector2(36, 205), "signal_liniers": Vector2(28, 345)}
	const COST := {"move": "según ritmo", "probe": "ocupa al explorador", "mark_ford": "1 baliza / 10 m", "muster": "40 s · voluntarios", "resupply": "25 s · +16 munición", "signal_liniers": "10 s · +8 munición", "board": "12 s para desmontar", "withdraw": "a la playa seca", "rally": "descansa", "cancel": "—", "recall": "vuelve", "distract_fire": "8 munición · 45 s", "retreat_all": "termina la partida"}

	func map_data() -> Dictionary:
		if _m.is_empty():
			_m = JSON.parse_string(FileAccess.get_file_as_string("res://data/justina_map.json"))
		return _m
	func map_size() -> Vector2:
		return Vector2(900, 520)
	func board_point() -> Vector2:
		return Vector2(548, 262)
	func ship_position() -> Vector2:
		return Vector2(580, 262)
	func get_unit(id: String) -> Dictionary:
		for u in state.get("units", []):
			if u.id == id:
				return u
		return {}
	func _unit(g: Dictionary) -> Dictionary:
		return {"id": g.id, "name": g.name, "x": g.x, "z": g.z, "strength": g.strength, "fatigue": 0.0, "supply": 100.0, "mounted": true, "stage": "ready", "order": {}, "path": [], "sector_id": "", "dismount_remaining": 0.0, "revealed_until": 0, "blocked_until": 0.0, "pace": "trot", "work": {}, "stumble_remaining": 0.0, "tag": g.tag}
	func new_game(scenario: String, seed_value: int = 1806) -> Dictionary:
		var m := map_data()
		var units: Array = []
		var start := {}
		for g in m.groups:
			units.append(_unit(g))
			start[g.id] = g.strength
		var scouts: Array = []
		for s in m.scouts:
			scouts.append({"id": s.id, "name": s.name, "x": s.x, "z": s.z, "hp": 3, "stage": "idle", "order": {}, "path": [], "work_remaining": 0.0, "tag": s.tag})
		state = {"schema_version": 3, "game_id": "stub-%d" % Time.get_ticks_usec(), "state_version": 1, "scenario": "justine", "seed": seed_value, "elapsed": 0.0, "status": "playing", "reason": "", "round": 1, "units": units, "log": [], "orders": [], "external_decisions": [], "first_order_at": -1.0,
			"map_id": "justina", "map_version": 1, "water_level_m": 1.65, "water_level": 0.95, "tide_phase": "alta", "capture": 0.0, "crew_morale": 100.0, "next_volley": 7.5, "deadline": 900.0,
			"ammo": 16, "ammo_max": 40, "balizas": 16, "volunteers_pool": 60.0, "advance_authorized": false, "fire_support": {"until": 0.0, "ready_at": 0.0},
			"probes": [], "scouts": scouts, "hazards_found": [], "fords_found": [], "briefing": m.texts.briefing, "historical_note": m.texts.historical_note,
			"stats": {"start_strength": start, "probe_m": 0.0, "marked_m": 0.0, "stumbles": 0, "ammo_used": 0, "balizas_used": 0, "fire_support_uses": 0, "scouts_lost": 0, "shots_taken": 0, "damage_taken": 0.0, "boarded_at": -1.0, "level_at_boarding": -1.0}}
		_event(m.texts.objective, "objective")
		return state
	func _event(text: String, kind: String = "info", pos = null) -> void:
		var e := {"time": state.elapsed, "round": 1, "text": text, "kind": kind}
		if pos != null:
			e["pos"] = {"x": pos.x, "z": pos.y}
		state.log.append(e)
		_events.append(e)
	func tide_marks() -> Dictionary:
		var t: Dictionary = map_data().time
		return {"drop_start": t.drop_start_s, "drop_end": t.drop_end_s, "low_hold_end": t.low_hold_end_s, "rise_end": t.rise_end_s, "deadline": t.deadline_s}
	func tide_at(t: float) -> Dictionary:
		var hi := 1.65
		var lvl := hi
		var phase := "alta"
		if t >= 645.0:
			phase = "subiendo"
			lvl = minf(hi, hi * (t - 645.0) / 180.0)
		elif t >= 375.0:
			phase = "baja"
			lvl = 0.0
		elif t >= 45.0:
			phase = "bajando"
			lvl = hi * (1.0 - (t - 45.0) / 330.0)
		return {"level_m": lvl, "level_norm": 0.05 + 0.9 * lvl / hi, "phase": phase}
	func water_level_m() -> float:
		return float(state.water_level_m)
	func _base_h(x: float) -> float:
		var pts: Array = map_data().bed_profile.points_x_elev
		if x <= pts[0][0]:
			return pts[0][1]
		for i in range(pts.size() - 1):
			if x <= pts[i + 1][0]:
				return lerpf(pts[i][1], pts[i + 1][1], (x - pts[i][0]) / (pts[i + 1][0] - pts[i][0]))
		return pts[pts.size() - 1][1]
	func terrain_height_at(x: float, z: float) -> float:
		if x < 40.0:
			return 12.0
		if x < 66.0:
			return lerpf(12.0, 3.0, smoothstep(40.0, 66.0, x))
		var e := _base_h(x)
		if absf(z - 265.0) < 20.0 and x > 272.0 and x < 500.0:
			e = maxf(e, -0.25)
		if Vector2(x, z).distance_to(Vector2(415, 264)) < 11.0:
			e = -1.9
		return e
	func water_depth_at(x: float, z: float) -> float:
		return water_level_m() - terrain_height_at(x, z)
	func knowledge_at(x: float, z: float) -> String:
		if x < 66.0 or water_depth_at(x, z) <= 0.3:
			return "visible"
		var best := "unknown"
		for p in state.probes:
			var pts: Array = p.pts
			var near := false
			if pts.size() == 1:
				near = Vector2(pts[0].x, pts[0].z).distance_to(Vector2(x, z)) <= p.width * 0.5
			for i in range(pts.size() - 1):
				var cp := Geometry2D.get_closest_point_to_segment(Vector2(x, z), Vector2(pts[i].x, pts[i].z), Vector2(pts[i + 1].x, pts[i + 1].z))
				if cp.distance_to(Vector2(x, z)) <= p.width * 0.5:
					near = true
			if near:
				best = "marked" if p.kind == "marked" else (best if best == "marked" else "probed")
		return best
	func perceived_depth_at(x: float, z: float) -> float:
		if knowledge_at(x, z) == "unknown":
			return water_level_m() - (_base_h(x) + 0.5)
		return water_depth_at(x, z)
	func terrain_kind_at(x: float, z: float) -> String:
		if x < 40.0:
			return "meseta"
		if x < 66.0:
			return "barranca"
		var d := water_depth_at(x, z)
		if d <= 0.0:
			return "firme" if -d >= 0.6 else "barro"
		if d <= 0.6:
			return "somera"
		return "agua" if d <= 1.3 else "honda"
	func exposure_at(x: float, z: float) -> float:
		if water_depth_at(x, z) <= 0.0 or Vector2(x, z).distance_to(ship_position()) > 280.0:
			return 0.0
		return 0.5 if float(state.fire_support.until) > float(state.elapsed) else 1.0
	func _pace_v(pace: String, depth: float) -> float:
		var v: float = map_data().movement.paces_mps[pace]
		if depth > 0.6:
			return minf(v, 2.0)
		if depth > 0.0:
			return minf(v, 2.0)
		return v if depth < -0.6 else minf(v, 1.5)
	func plan_route(id: String, target: Vector2, pace: String = "trot", opts: Dictionary = {}) -> Dictionary:
		calls.plan_route += 1
		var ms := map_size()
		if target.x < 0 or target.y < 0 or target.x > ms.x or target.y > ms.y:
			return {"ok": false, "reason": "Destino fuera del mapa."}
		if terrain_kind_at(target.x, target.y) in ["meseta", "barranca"]:
			return {"ok": false, "reason": "Destino no transitable: barranca o meseta."}
		if knowledge_at(target.x, target.y) != "unknown" and perceived_depth_at(target.x, target.y) > 1.3:
			return {"ok": false, "reason": "Destino en agua honda ya reconocida."}
		var u := get_unit(id)
		var pts: Array = [Vector2(u.x, u.z)]
		for w in opts.get("waypoints", []):
			pts.append(w)
		pts.append(target)
		var length := 0.0
		var eta := 0.0
		var unknown := 0.0
		var exposed := 0.0
		var maxd := -9.0
		for i in range(pts.size() - 1):
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var n := maxi(1, int(a.distance_to(b) / 4.0))
			var seg := a.distance_to(b) / n
			for k in range(n):
				var q := a.lerp(b, (k + 0.5) / n)
				var d := perceived_depth_at(q.x, q.y)
				var v := _pace_v(pace, d)
				length += seg
				eta += seg / v
				maxd = maxf(maxd, d)
				if knowledge_at(q.x, q.y) == "unknown" and d > 0.0:
					unknown += seg
				var ex := exposure_at(q.x, q.y)
				if ex > 0.0:
					exposed += ex * seg / v
		var risk := "bajo"
		if unknown > 80.0:
			risk = "alto"
		elif unknown > 0.0:
			risk = "medio"
		elif maxd > 0.6 * 1.3:
			risk = "medio"
		if knowledge_at(target.x, target.y) == "unknown" and perceived_depth_at(target.x, target.y) > 0.0:
			risk = "desconocido"
		var path: Array = []
		for p in pts:
			path.append({"x": p.x, "z": p.y})
		return {"ok": true, "reason": "", "path": path, "length_m": length, "eta_s": eta, "unknown_m": unknown, "exposed_s": exposed, "max_depth_m": maxd, "arrives_in_window": false, "risk": risk, "warnings": []}
	func ford_window(x: float, z: float, mounted: bool = true) -> Dictionary:
		var sur := Vector2(x, z).distance_to(Vector2(305, 403)) < 40.0
		var certain := knowledge_at(x, z) != "unknown"
		return {"known": certain, "certain": certain, "opens_at": 295.0 if sur else 315.0, "closes_at": 688.0 if sur else 677.0, "depth_at_low_m": 1.0}
	func action_info(action: String) -> Dictionary:
		var a: Dictionary = map_data().actions.get(action, {})
		if a.is_empty():
			return {}
		var out := a.duplicate(true)
		out["id"] = action
		return out
	func list_actions(kind: String) -> Array:
		if kind == "group":
			return ["move", "board", "muster", "resupply", "signal_liniers", "withdraw", "rally", "cancel"]
		if kind == "scout":
			return ["probe", "mark_ford", "recall"]
		return ["distract_fire", "retreat_all"]
	func resources() -> Dictionary:
		return {"ammo": state.ammo, "ammo_max": state.ammo_max, "balizas": state.balizas, "volunteers_pool": state.volunteers_pool, "advance_authorized": state.advance_authorized}
	func scouts() -> Array:
		return state.scouts.duplicate(true)
	func probes() -> Array:
		return state.probes.duplicate(true)
	func ship_state() -> Dictionary:
		return {"x": 580.0, "z": 262.0, "heading_deg": 0.0, "guns_total": 26, "broadside_guns": 13, "range_m": 280.0, "next_volley_in": 7.5 - fmod(float(state.elapsed), 7.5), "crew_morale": state.crew_morale, "capture": state.capture, "fire_support_active": float(state.fire_support.until) > float(state.elapsed), "fire_support_ready_in": maxf(0.0, float(state.fire_support.ready_at) - float(state.elapsed))}
	func action_availability(actor_id: String, action: String, target: Vector2 = Vector2.ZERO) -> Dictionary:
		var tag: String = str(action_info(action).get("tag", "diseno"))
		var cost: String = COST.get(action, "")
		var r := _why_not(actor_id, action)
		return {"ok": r.is_empty(), "reason": r, "cost_text": cost, "tag": tag}
	func _why_not(actor_id: String, action: String) -> String:
		if state.status != "playing":
			return "La partida ya terminó."
		var u := get_unit(actor_id)
		if not u.is_empty() and float(u.strength) <= 5.0 and action != "retreat_all":
			return "El grupo está disperso."
		match action:
			"signal_liniers":
				if state.advance_authorized:
					return "La orden de avance ya fue concedida."
			"board":
				if not state.advance_authorized:
					return "Falta la orden de avance de Liniers: señalá primero."
			"muster":
				if float(state.volunteers_pool) <= 0.0:
					return "No quedan voluntarios en el reservorio."
				if not u.is_empty() and float(u.strength) >= 100.0:
					return "La fuerza ya está al máximo."
			"resupply":
				if int(state.ammo) >= int(state.ammo_max):
					return "La munición está al tope."
			"distract_fire":
				if int(state.ammo) < 8:
					return "Falta munición (hacen falta 8, quedan %d)." % int(state.ammo)
				if float(state.elapsed) < float(state.fire_support.ready_at):
					return "Recargando: faltan %d s." % int(float(state.fire_support.ready_at) - float(state.elapsed))
			"mark_ford":
				if int(state.balizas) <= 0:
					return "Faltan balizas (quedan 0)."
		if action in ["probe", "mark_ford", "recall"]:
			for s in state.scouts:
				if s.id == actor_id and s.stage == "lost":
					return "El explorador está perdido."
		return ""
	func issue_order(group_id: String, action: String, target: Vector2 = Vector2.ZERO, opts: Dictionary = {}) -> Dictionary:
		var u := get_unit(group_id)
		var why := _why_not(group_id, action)
		if u.is_empty() or not why.is_empty():
			return {"ok": false, "reason": why if not why.is_empty() else "Grupo desconocido."}
		var pace: String = str(opts.get("pace", "trot"))
		if action in ["move", "board"]:
			var tgt := board_point() if action == "board" else target
			var plan := plan_route(group_id, tgt, pace, opts)
			if not plan.ok:
				return plan
			u.order = {"action": action, "x": tgt.x, "z": tgt.y}
			u.path = plan.path.slice(1)
			u.stage = "moving"
			u.pace = pace
			_record(group_id, action)
			return {"ok": true, "reason": "Orden aceptada: %s." % action, "path": u.path, "plan": plan}
		if action in HITO:
			var h: Vector2 = HITO[action]
			u.order = {"action": action, "x": h.x, "z": h.y}
			u.path = [{"x": h.x, "z": h.y}]
			u.stage = "moving"
			_record(group_id, action)
			return {"ok": true, "reason": "Marcha al hito para %s." % action, "path": u.path, "plan": {}}
		if action == "withdraw":
			u.order = {"action": "withdraw", "x": 150.0, "z": u.z}
			u.path = [{"x": 150.0, "z": u.z}]
			u.stage = "moving"
			return {"ok": true, "reason": "Retirada a la playa seca.", "path": u.path, "plan": {}}
		if action == "rally":
			u.stage = "rally"
			u.order = {"action": "rally"}
			return {"ok": true, "reason": "Reagrupa.", "path": [], "plan": {}}
		if action == "cancel":
			u.stage = "ready"
			u.order = {}
			u.path = []
			u.work = {}
			return {"ok": true, "reason": "Orden cancelada.", "path": [], "plan": {}}
		return {"ok": false, "reason": "Orden táctica desconocida."}
	func _record(id: String, action: String) -> void:
		state.orders.append({"unit": id, "action": action, "time": state.elapsed})
		if float(state.first_order_at) < 0.0:
			state.first_order_at = state.elapsed
	func issue_scout(scout_id: String, action: String, points: Array = []) -> Dictionary:
		var sc: Dictionary = {}
		for s in state.scouts:
			if s.id == scout_id:
				sc = s
		if sc.is_empty():
			return {"ok": false, "reason": "Explorador desconocido."}
		if sc.stage == "lost":
			return {"ok": false, "reason": "El explorador está perdido."}
		if action == "recall":
			sc.stage = "idle"
			sc.path = []
			return {"ok": true, "reason": "El explorador vuelve a la playa seca."}
		if points.is_empty() or points.size() > 3:
			return {"ok": false, "reason": "Hacen falta de 1 a 3 puntos."}
		for p in points:
			if p.x < 0 or p.y < 0 or p.x > 900 or p.y > 520:
				return {"ok": false, "reason": "Punto fuera del mapa."}
		if action == "probe":
			sc.stage = "probing"
			sc.order = {"action": "probe", "points": []}
			sc.path = []
			for p in points:
				sc.path.append({"x": p.x, "z": p.y})
			state.probes.append({"id": "p%d" % (state.probes.size() + 1), "kind": "lane", "pts": [{"x": sc.x, "z": sc.z}], "width": 6.0, "t": state.elapsed, "scout": scout_id})
			return {"ok": true, "reason": "El explorador sondea %d punto(s)." % points.size()}
		if action == "mark_ford":
			var len := 0.0
			for i in range(points.size() - 1):
				len += points[i].distance_to(points[i + 1])
			var on_lane := true
			for p in points:
				on_lane = on_lane and knowledge_at(p.x, p.y) in ["probed", "marked", "visible"]
			if not on_lane:
				return {"ok": false, "reason": "Marcar vado exige un tramo ya sondeado."}
			var cost := int(ceil(maxf(len, 10.0) / 10.0))
			if cost > int(state.balizas):
				return {"ok": false, "reason": "Faltan balizas (quedan %d)." % int(state.balizas)}
			state.balizas -= cost
			state.stats.balizas_used += cost
			var pp: Array = []
			for p in points:
				pp.append({"x": p.x, "z": p.y})
			state.probes.append({"id": "p%d" % (state.probes.size() + 1), "kind": "marked", "pts": pp, "width": 16.0, "t": state.elapsed, "scout": scout_id})
			state.stats.marked_m += len
			return {"ok": true, "reason": "Vado marcado (%d balizas)." % cost}
		return {"ok": false, "reason": "Acción desconocida."}
	func call_fire_support() -> Dictionary:
		var why := _why_not("guemes", "distract_fire")
		if not why.is_empty():
			return {"ok": false, "reason": why}
		state.ammo -= 8
		state.fire_support = {"until": state.elapsed + 45.0, "ready_at": state.elapsed + 90.0}
		state.stats.fire_support_uses += 1
		_event("La batería Abascal distrae al buque.", "fire_support")
		return {"ok": true, "reason": "Fuego de distracción durante 45 s."}
	func retreat_all() -> Dictionary:
		if state.status != "playing":
			return {"ok": false, "reason": "La partida ya terminó."}
		_finish("defeat", "Retirada general ordenada. La partida termina.")
		return {"ok": true, "reason": state.reason}
	func _finish(status: String, reason: String) -> void:
		state.status = status
		state.reason = reason
		_event(reason, status)
	func tick(dt: float) -> Array:
		_events = []
		var rest := minf(dt, 60.0)
		while rest > 0.0 and state.status == "playing":
			var s := minf(rest, 0.25)
			rest -= s
			_step(s)
		state.state_version += 1
		return _events
	func _step(s: float) -> void:
		state.elapsed += s
		var td := tide_at(state.elapsed)
		state.water_level_m = td.level_m
		state.water_level = td.level_norm
		state.tide_phase = td.phase
		for u in state.units:
			if u.stage == "moving":
				_advance(u, _pace_v(u.pace, water_depth_at(u.x, u.z)), s, true)
			elif u.stage == "working":
				u.work.remaining -= s
				if u.work.remaining <= 0.0:
					_work_done(u)
			elif u.stage == "boarding":
				state.capture += float(u.strength) / 100.0 * 0.19 * s
				state.crew_morale = maxf(0.0, state.crew_morale - float(u.strength) / 100.0 * 0.12 * s)
		for sc in state.scouts:
			if sc.stage == "probing":
				var probe: Dictionary = state.probes[state.probes.size() - 1]
				for p in state.probes:
					if p.scout == sc.id:
						probe = p
				var wet := water_depth_at(sc.x, sc.z) > 0.0
				_advance(sc, 1.0 if wet else 3.0, s, false)
				var last: Dictionary = probe.pts[probe.pts.size() - 1]
				if Vector2(last.x, last.z).distance_to(Vector2(sc.x, sc.z)) >= 6.0 or sc.path.is_empty():
					probe.pts.append({"x": sc.x, "z": sc.z})
					state.stats.probe_m += 6.0
				if sc.path.is_empty():
					sc.stage = "idle"
		if float(state.capture) >= 100.0:
			state.capture = 100.0
			_finish("victory", "El buque se rinde ante la caballería. Captura completa.")
		elif state.elapsed >= float(state.deadline):
			_finish("defeat", "Plazo agotado: el río volvió a subir sin que el buque fuera tomado.")
	func _advance(u: Dictionary, v: float, s: float, is_group: bool) -> void:
		if u.path.is_empty():
			if is_group:
				_arrive(u)
			return
		var tgt := Vector2(u.path[0].x, u.path[0].z)
		var pos := Vector2(u.x, u.z)
		var step := v * s
		if pos.distance_to(tgt) <= step:
			pos = tgt
			u.path.pop_front()
		else:
			pos += (tgt - pos).normalized() * step
		u.x = pos.x
		u.z = pos.y
		if is_group and u.path.is_empty():
			_arrive(u)
	func _arrive(u: Dictionary) -> void:
		var a: String = str(u.order.get("action", ""))
		if a in HITO:
			u.stage = "working"
			u.work = {"kind": a, "remaining": 10.0 if a == "signal_liniers" else 25.0}
		elif a == "board":
			u.stage = "boarding"
			state.stats.boarded_at = state.elapsed
			state.stats.level_at_boarding = state.water_level_m
			_event("El grupo desmonta junto al buque.", "boarding", Vector2(u.x, u.z))
		else:
			u.stage = "ready"
			u.order = {}
	func _work_done(u: Dictionary) -> void:
		var k: String = str(u.work.kind)
		if k == "signal_liniers":
			state.advance_authorized = true
			state.ammo = mini(int(state.ammo_max), int(state.ammo) + 8)
			_event("Liniers concede la orden de avance.", "signal", Vector2(u.x, u.z))
		elif k == "resupply":
			state.ammo = mini(int(state.ammo_max), int(state.ammo) + 16)
			_event("Munición repuesta.", "ammo")
		elif k == "muster":
			u.strength = minf(100.0, float(u.strength) + 25.0)
			state.volunteers_pool -= 25.0
			_event("Se suman jinetes.", "muster")
		u.stage = "ready"
		u.work = {}
		u.order = {}
	func campaign_report() -> Dictionary:
		var groups: Array = []
		for u in state.units:
			var s0: float = state.stats.start_strength[u.id]
			groups.append({"id": u.id, "name": u.name, "tag": u.tag, "start_strength": s0, "end_strength": u.strength, "loss_pct": maxf(0.0, 100.0 * (s0 - float(u.strength)) / s0)})
		var titles := {"victory": "Buque capturado", "defeat": "Plazo agotado" if str(state.reason).begins_with("Plazo") else ("Retirada general" if str(state.reason).begins_with("Retirada") else "Grupos dispersos"), "playing": "Parte parcial"}
		return {"status": state.status, "reason": state.reason, "elapsed": state.elapsed, "outcome_title": titles[state.status], "groups": groups, "route": "ninguna", "route_notes": [], "probe_m": state.stats.probe_m, "marked_m": state.stats.marked_m, "stumbles": 0, "ammo_used": 0, "balizas_used": state.stats.balizas_used, "fire_support_uses": state.stats.fire_support_uses, "scouts_lost": 0, "shots_taken": 0, "damage_taken": 0.0, "level_at_boarding": state.stats.level_at_boarding, "boarded_at": state.stats.boarded_at, "exposure_s": {"central": 0.0, "sur": 0.0, "otra": 0.0},
			"history": [{"text": "Un buque mercante de 26 cañones varó frente al Retiro.", "tag": "documentado"}, {"text": "La caballería de Pueyrredón tomó el buque.", "tag": "documentado"}, {"text": "Güemes al frente de los jinetes es una tradición no probada.", "tag": "tradicion"}, {"text": "La distancia de unos 390 m y la profundidad del vado son cifras divulgativas.", "tag": "diseno"}, {"text": "Bancos, canal, vados, pozo, tiempos, fuerzas y munición son diseño del juego.", "tag": "diseno"}]}
	func save_game(path: String) -> Error:
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			return ERR_CANT_CREATE
		f.store_string(JSON.stringify(state))
		f.close()
		return OK
	func load_game(path: String) -> Dictionary:
		if load_reject:
			return {"ok": false, "reason": "Este guardado es de una versión anterior del escenario Justina y no es compatible."}
		return {"ok": false, "reason": "El sustituto de Reglas no carga guardados."}
	func snapshot() -> Dictionary:
		return state.duplicate(true)


class StubWorld extends Node3D:
	signal minimap_changed
	var rules
	var scenario := "justine"
	var unit_nodes := {}
	var unit_labels := {}
	var sector_nodes := {}
	var selected_rings := {}
	var selected := ""
	var selected_ids: Array = []
	var selected_sector := ""
	var show_paths := true
	var layers := {}
	var water: MeshInstance3D
	var route_root := Node3D.new()

	func build(r, quality: String = "media") -> void:
		rules = r
		var land := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(900, 520)
		land.mesh = pm
		var lm := StandardMaterial3D.new()
		lm.albedo_color = Color("8a7a58")
		land.material_override = lm
		land.position = Vector3(450, 0, 260)
		add_child(land)
		water = MeshInstance3D.new()
		var wm := PlaneMesh.new()
		wm.size = Vector2(700, 520)
		water.mesh = wm
		var wmat := StandardMaterial3D.new()
		wmat.albedo_color = Color("4a5d63")
		water.material_override = wmat
		water.position = Vector3(550, 0.01, 260)
		add_child(water)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-60, 30, 0)
		add_child(sun)
		add_child(route_root)
		for id in ["guemes", "arias", "zavala", "scout_1", "scout_2"]:
			var root := Node3D.new()
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(4, 3, 8)
			mi.mesh = bm
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color("e2bc72") if id == "guemes" else (Color("7fd0c4") if id == "arias" else (Color("e0a3bd") if id == "zavala" else Color("d8d2c0")))
			mi.material_override = mat
			root.add_child(mi)
			add_child(root)
			unit_nodes[id] = {"root": root, "mounted": true}
		var ship := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(14, 8, 40)
		ship.mesh = sm
		ship.position = Vector3(580, 4, 262)
		add_child(ship)
		update_state(0.0)
	func _actor(id: String) -> Dictionary:
		if id.begins_with("scout"):
			for s in rules.state.scouts:
				if s.id == id:
					return s
			return {}
		return rules.get_unit(id)
	func update_state(_delta: float) -> void:
		if rules == null or water == null:
			return
		water.position.y = float(rules.water_level_m())
		for id in unit_nodes:
			var a := _actor(id)
			if a.is_empty():
				continue
			unit_nodes[id].root.position = Vector3(float(a.x), maxf(rules.terrain_height_at(a.x, a.z), rules.water_level_m()) + 1.5, float(a.z))
	func pick_ground(camera: Camera3D, mouse_pos: Vector2) -> Variant:
		var o := camera.project_ray_origin(mouse_pos)
		var d := camera.project_ray_normal(mouse_pos)
		return Plane(Vector3.UP, 0.0).intersects_ray(o, d)
	func ground_xz_from_screen(camera: Camera3D, mouse_pos: Vector2) -> Variant:
		var p = pick_ground(camera, mouse_pos)
		if p == null:
			return null
		return Vector2(p.x, p.z)
	func pick_unit(camera: Camera3D, mouse_pos: Vector2) -> String:
		var best := ""
		var bd := 55.0
		for id in ["guemes", "arias", "zavala", "scout_1", "scout_2"]:
			var wp: Vector3 = unit_nodes[id].root.global_position
			if camera.is_position_behind(wp):
				continue
			var d := camera.unproject_position(wp).distance_to(mouse_pos)
			if d < bd:
				bd = d
				best = id
		return best
	func pick_sector(_camera: Camera3D, _mouse_pos: Vector2) -> String:
		return ""
	func pick_units_in_rect(camera: Camera3D, screen_rect: Rect2) -> Array:
		var out: Array = []
		for id in ["guemes", "arias", "zavala", "scout_1", "scout_2"]:
			var wp: Vector3 = unit_nodes[id].root.global_position
			if not camera.is_position_behind(wp) and screen_rect.has_point(camera.unproject_position(wp)):
				out.append(id)
		return out
	func refresh_paths() -> void:
		pass
	func cannon_effect(_from: Vector2 = Vector2.ZERO, _to: Vector2 = Vector2.ZERO) -> void:
		pass
	func terrain_height(x: float, z: float) -> float:
		return rules.terrain_height_at(x, z)
	func map_size() -> Vector2:
		return Vector2(900, 520)
	func world_to_map(p: Vector2) -> Vector2:
		return Vector2(p.x / 900.0, p.y / 520.0)
	func map_to_world(uv: Vector2) -> Vector2:
		return Vector2(uv.x * 900.0, uv.y * 520.0)
	func camera_bounds() -> Rect2:
		return Rect2(-60, -60, 1020, 640)
	func clamp_camera_target(p: Vector3) -> Vector3:
		var b := camera_bounds()
		var x := clampf(p.x, b.position.x, b.end.x)
		var z := clampf(p.z, b.position.y, b.end.y)
		return Vector3(x, maxf(rules.terrain_height_at(x, z), rules.water_level_m()), z)
	func camera_frustum_on_ground(camera: Camera3D) -> PackedVector2Array:
		var v := camera.get_viewport().get_visible_rect().size
		var out := PackedVector2Array()
		var b := camera_bounds()
		for c in [Vector2(0, 0), Vector2(v.x, 0), Vector2(v.x, v.y), Vector2(0, v.y)]:
			var g = ground_xz_from_screen(camera, c)
			if g == null:
				var o := camera.project_ray_origin(c)
				var d := camera.project_ray_normal(c)
				g = Vector2(o.x + d.x * 1500.0, o.z + d.z * 1500.0)
			out.append(Vector2(clampf(g.x, b.position.x, b.end.x), clampf(g.y, b.position.y, b.end.y)))
		return out
	func meters_per_pixel(camera: Camera3D, screen_pos: Vector2 = Vector2(-1, -1)) -> float:
		var v := camera.get_viewport().get_visible_rect().size
		var p := v * 0.5 if screen_pos.x < 0 else screen_pos
		var a = ground_xz_from_screen(camera, p)
		var b = ground_xz_from_screen(camera, p + Vector2(1, 0))
		if a == null or b == null:
			return 1.0
		return a.distance_to(b)
	func pick_landmark(camera: Camera3D, mouse_pos: Vector2) -> String:
		var best := ""
		var bd := 40.0
		for lm in rules.map_data().landmarks:
			if not lm.has("x"):
				continue
			var wp := Vector3(lm.x, 0, lm.z)
			if camera.is_position_behind(wp):
				continue
			var d := camera.unproject_position(wp).distance_to(mouse_pos)
			if d < bd:
				bd = d
				best = lm.id
		return best
	func get_landmark_info(id: String) -> Dictionary:
		for lm in rules.map_data().landmarks:
			if lm.id == id:
				return {"id": id, "name": lm.name, "type": lm.type, "tag": lm.tag, "source": lm.source, "x": lm.get("x", 0.0), "z": lm.get("z", 0.0)}
		return {}
	func landmark_labels(camera: Camera3D) -> Array:
		var out: Array = []
		for lm in rules.map_data().landmarks:
			if not lm.has("x"):
				continue
			var wp := Vector3(lm.x, 6, lm.z)
			var behind := camera.is_position_behind(wp)
			out.append({"id": lm.id, "name": lm.name, "tag": lm.tag, "screen": camera.unproject_position(wp), "behind": behind})
		return out
	func set_layer_visible(layer: String, on: bool) -> void:
		layers[layer] = on
	func set_selected_ids(ids: Array) -> void:
		selected_ids = ids.duplicate()
		selected = str(ids[0]) if not ids.is_empty() else ""
	func get_minimap_texture(size: Vector2i) -> Texture2D:
		var img := Image.create(size.x, size.y, false, Image.FORMAT_RGB8)
		img.fill(Color("4a5d63"))
		img.fill_rect(Rect2i(0, 0, int(size.x * 190.0 / 900.0), size.y), Color("8a7a58"))
		img.fill_rect(Rect2i(0, 0, int(size.x * 66.0 / 900.0), size.y), Color("5e5a45"))
		return ImageTexture.create_from_image(img)
	func minimap_refresh(_force: bool = false) -> void:
		pass
