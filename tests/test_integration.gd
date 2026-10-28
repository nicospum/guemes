extends SceneTree
## Player-flow checks against the actual main scene; headless, no screenshot claim.

var game: Node
var checks := 0
var failures: Array = []
var report: Dictionary = {"suite": "main_scene_player_flow", "kind": "headless_scene_integration", "engine": Engine.get_version_info().string}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	if scene == null:
		check(false, "Main scene loads")
		_finish()
		return
	game = scene.instantiate()
	root.add_child(game)
	await process_frame
	check(game.mode == "menu", "Opening the delivery reaches scenario selection")
	check(_find_button("EL RÍO OFRECE") != null, "Menu offers the Justine scenario")
	check(_find_button("SOSTENER EL NORTE") != null, "Menu offers the northern scenario")
	game.jev.force_local = true
	check(_press("EL RÍO OFRECE"), "Justine starts through its menu button")
	await process_frame
	check(game.mode == "play" and game.rules.state.scenario == "justine", "Justine scene and rules agree")
	check(game.paused, "Justine starts paused for the first decision")
	check(game.world.unit_nodes.size() == 3, "Three controllable 3D groups are present")
	check(_press("2 · Voluntarios"), "Second group button is clickable")
	check(game.selected == "arias", "Group-button closure selects the correct group")
	check(_press("4 · Seleccionar todas"), "Select-all control is accessible")
	check(game.selected == "all", "Select all sets the intended selection")
	check(_press("Banco directo"), "Tactical route button is connected")
	for unit in game.rules.state.units:
		check(unit.order.get("action", "") == "direct", "Route applies to selected group " + str(unit.id))
	game.world.update_state(0.01)
	var all_marked := true
	for ring in game.world.selected_rings.values():
		all_marked = all_marked and ring.visible
	check(all_marked, "All selected groups carry visible selection rings")
	var elapsed := float(game.rules.state.elapsed)
	game._process(1.0)
	check(float(game.rules.state.elapsed) == elapsed, "Paused scene does not advance tactical rules")
	_key(KEY_SPACE)
	game._process(0.5)
	check(float(game.rules.state.elapsed) > elapsed, "Space resumes the actual tactical clock")
	game._controls_dialog()
	var modal_elapsed := float(game.rules.state.elapsed)
	game._process(1.0)
	check(float(game.rules.state.elapsed) == modal_elapsed, "Controls modal pauses the mission")
	game._close_modal()
	check(not game.paused, "Closing modal restores the previous pause state")
	game.paused = true
	_key(KEY_F5)
	check(FileAccess.file_exists(game._save_path("justine")), "F5 saves from the real HUD flow")
	var old_id: String = str(game.rules.state.game_id)
	_key(KEY_X)
	check(game.rules.get_unit("guemes").order.is_empty(), "Cancel keyboard control clears pending route")
	_key(KEY_F9)
	await process_frame
	check(str(game.rules.state.game_id) != old_id, "F9 starts a new request epoch")
	check(game.rules.get_unit("guemes").order.get("action", "") == "direct", "F9 restores the saved route")
	check(game.paused and game.selected == "guemes", "Loaded mission is immediately controllable and paused")
	game._select_unit("all")
	game.paused = false
	for i in range(4):
		game._process(60.0)
	game.paused = true
	check(game.rules.state.tide_phase == "baja", "Mission process advances the actual river phase")
	check(absf(float(game.world.water.position.y) - float(game.rules.state.water_level)) < 0.0001, "Visible water follows rules after the tide changes")
	check(game.world.route_root.get_child_count() > 0, "Selected approach has visible path markers")

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

	game._start_game("justine")
	game._select_unit("all")
	game._tactical_order("direct")
	for i in range(15):
		if game.rules.state.status != "playing":
			break
		game.rules.tick(60)
	game._process(0.0)
	await process_frame
	check(game.rules.state.status == "victory" and game.outcome_shown, "A real tactical victory opens its outcome UI")
	check(_find_button("Ir a la campaña del norte") != null, "Victory offers continuation to the second scenario")
	check(_press("Volver a jugar"), "Outcome provides a working restart")
	await process_frame
	check(game.rules.state.status == "playing" and float(game.rules.state.capture) == 0, "Outcome restart resets capture and terminal state")
	check(not is_instance_valid(game.modal), "Restart removes the old terminal modal")
	for i in range(15):
		game.rules.tick(60)
	game._process(0.0)
	await process_frame
	check(game.rules.state.status == "defeat" and game.outcome_shown, "A real tactical defeat opens its outcome UI")
	check(_find_button("Volver a jugar") != null, "Defeat also permits immediate restart")

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

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	game._unhandled_input(event)

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
	var file := FileAccess.open("res://evidence/integration-test-results.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
