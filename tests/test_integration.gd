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
	check(_press("EL RÍO OFRECE"), "Justina starts through its menu button")
	await process_frame
	await process_frame
	check(game.mode == "play" and game.rules.state.scenario == "justine", "Justina scene and rules agree")
	check(game.paused, "Justina starts paused for the first decision")
	check(game.world.unit_nodes.size() >= 5, "Three groups and two scouts have 3D nodes")
	# Briefing inicial
	check(is_instance_valid(game.modal), "Briefing modal opens at the start")
	var btxt := _modal_text()
	check(btxt.find("Tradición") >= 0 and btxt.find("Documentado") >= 0 and btxt.find("Reconstrucción") >= 0 and btxt.find("Diseño") >= 0, "Briefing shows the four source tags")
	check(btxt.find(str(game.rules.state.briefing).substr(0, 40)) >= 0, "Briefing shows state.briefing")
	check(btxt.count("•") >= 3, "Briefing shows three tips")
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
	check(game.clock_label.text.begins_with("Quedan") and game.state_label.text.find("Riesgo") >= 0, "Countdown and risk are shown")
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
		game._process(10.0)
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
		game._process(10.0)
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
		game._process(5.0)
		if int(game.rules.resources().balizas) < balizas0:
			break
	game.paused = true
	check(int(game.rules.resources().balizas) < balizas0, "Marking a ford spends beacons (as the work advances: %d -> %d)" % [balizas0, int(game.rules.resources().balizas)])
	# Orden de avance, ritmo y paso hasta el abordaje
	game._select_ids(["guemes"])
	game._do_action("signal_liniers")
	game.paused = false
	for i in range(30):
		game._process(10.0)
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
		game._process(5.0)
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
		game._process(10.0)
		if game.rules.state.status != "playing":
			break
	game.paused = true
	await process_frame
	check(game.rules.state.status in ["victory", "defeat"] and game.outcome_shown, "A scripted blind crossing (no reconnaissance, no support) ends the game (%s, %s) and opens the campaign report" % [game.rules.state.status, str(game.rules.state.get("defeat_cause", ""))])
	check(is_instance_valid(game.modal), "The campaign report is a modal")
	var rep: Dictionary = game.rules.campaign_report()
	var mt := _modal_text()
	check(mt.find(str(rep.outcome_title)) >= 0 or mt.find(str(rep.reason)) >= 0, "The report shows the title/outcome of campaign_report()")
	for g in rep.groups:
		check(mt.find(str(g.name)) >= 0, "The report lists group " + str(g.name))
	check(mt.find("Qué fue historia") >= 0 and mt.find("Tradición") >= 0 and mt.find("Documentado") >= 0, "The report ends with 'Qué fue historia' tagged lines")
	check(_find_button("Ir a la campaña del norte") != null, "Victory offers continuation to the second scenario")
	_layout_checks("Justina parte")
	check(_press("Volver a jugar"), "Outcome provides a working restart")
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
	check(_find_button("Volver a jugar") != null, "Defeat also permits immediate restart")
	game._close_modal()
	# Retirada general con confirmacion
	game.forced_seed=1806
	game._start_game("justine")
	game._close_modal()
	game._do_action("retreat_all")
	check(is_instance_valid(game.modal) and game.rules.state.status == "playing", "Retirada general asks for confirmation")
	check(_press("Sí, ordenar la retirada"), "Retirada general can be confirmed")
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

# ------------------------------------------------------------------ utilidades
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
	check(game.pause_banner.visible and game.pause_banner.text.find("órdenes con el tiempo detenido") >= 0, "A banner explains that orders can be given while paused")
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
		check(ct.find("Orden:") >= 0 and ct.find(game._short_name(id)) >= 0, "Card %s shows name and current order" % id)
	for id in game.GROUP_IDS:
		check(game.roster_buttons[id].text.find("%d %%" % int(game.rules.get_unit(id).strength)) >= 0 and game.roster_buttons[id].text.find("mun.") >= 0, "Card %s shows strength and ammunition" % id)
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
	check(bb.disabled and str(bb.get_meta("why")).find("Señalar a Liniers") >= 0 and str(bb.get_meta("why")).find("K") >= 0, "Blocked board explains the Liniers chain in plain words: " + str(bb.get_meta("why")))
	check(game.reason_label.text.begins_with("SIGUIENTE"), "With nothing hovered the bar says the next step: " + game.reason_label.text)
	game._show_action_info("board")
	check(game.reason_label.text.find("No disponible") >= 0 and game.reason_label.text.find("Liniers") >= 0, "Hovering a blocked action shows why")
	game._show_action_info("")
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
	check(game.hint_panel.visible and game.tutorial_label.text.begins_with("1/6"), "Tutorial step 1/6 is shown: " + game.tutorial_label.text)
	game._tut_skip()
	check(game.tutorial_label.text.begins_with("2/6"), "Tutorial steps can be skipped")
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
	game._update_hud()
	check(game.paused and game.alert_panel.visible and game.alert_label.text.find("CONTRAATAQUE") >= 0 and game.alert_label.text.find("14") >= 0, "A counterattack alert pauses the game and shows the countdown: " + game.alert_label.text)
	check(game.pause_banner.visible and game.pause_banner.text.find("PAUSA AUTOMÁTICA") >= 0, "The banner says the pause was automatic")
	check(game.alert_btn.visible and game.alert_btn.text.find("Rechazar") >= 0, "The alert offers a Rechazar button")
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
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://evidence/justina-ui"))
	var file := FileAccess.open("res://evidence/justina-ui/integration-test-results.json", FileAccess.WRITE)
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
		state = {"schema_version": 2, "game_id": "stub-%d" % Time.get_ticks_usec(), "state_version": 1, "scenario": "justine", "seed": seed_value, "elapsed": 0.0, "status": "playing", "reason": "", "round": 1, "units": units, "log": [], "orders": [], "external_decisions": [], "first_order_at": -1.0,
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
