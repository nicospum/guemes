extends SceneTree
var game: Node
func p(s): print(s)
func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code; event.physical_keycode = code; event.pressed = true
	game._unhandled_input(event)
func _find_button(part: String) -> Button:
	for node in game.ui.find_children("*", "Button", true, false):
		if str(node.text).contains(part): return node
	return null
func _initialize(): call_deferred("_run")
func _run():
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.jev.force_local = true
	var sp: String = game._save_path("justine")
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	# ---- A: single save slot overwritten by Menu autosave
	game._start_game("justine")
	game._select_unit("all"); game._tactical_order("direct")
	game.paused = false
	for i in range(5): game._process(60.0)   # 300 s
	game.paused = true
	_key(KEY_F5)
	var saved = JSON.parse_string(FileAccess.get_file_as_string(sp))
	p("A manual F5 save: elapsed=%.0f status=%s" % [saved.elapsed, saved.status])
	# accidental restart with R (no confirmation)
	var id_before = game.rules.state.game_id
	_key(KEY_R)
	p("A after one R press: elapsed=%.0f game_id changed=%s orders=%d" % [game.rules.state.elapsed, str(id_before != game.rules.state.game_id), game.rules.state.orders.size()])
	game._return_menu()
	await process_frame
	saved = JSON.parse_string(FileAccess.get_file_as_string(sp))
	p("A save slot after Menu from fresh restarted game: elapsed=%.0f (manual save at 300 lost? %s)" % [saved.elapsed, str(saved.elapsed < 300)])
	# ---- B: defeat -> Menu overwrites slot with the defeat; Continue returns to defeat
	game._start_game("justine")
	game.paused = false
	for i in range(16): game._process(60.0)
	await process_frame
	p("B status=%s outcome_shown=%s" % [game.rules.state.status, str(game.outcome_shown)])
	game._close_modal()
	game._return_menu()
	await process_frame
	saved = JSON.parse_string(FileAccess.get_file_as_string(sp))
	p("B slot after Menu: status=%s elapsed=%.0f" % [saved.status, saved.elapsed])
	var cont = _find_button("Continuar")
	p("B Continue enabled=%s" % str(cont != null and not cont.disabled))
	game._load_game("justine")
	for i in range(3): await process_frame
	p("B after Continue: status=%s outcome modal=%s" % [game.rules.state.status, str(is_instance_valid(game.modal))])
	# ---- C: water move order, mixed selection toast
	game._start_game("justine")
	game._select_unit("all")
	game._tactical_order("move", Vector2(0, 22))
	p("C move to deep water: orders=%d" % game.rules.state.orders.size())
	# ---- D: Norte pending + Menu then new game
	game._start_game("norte")
	game._resolve_round()
	game._return_menu()
	for i in range(5): await process_frame
	p("D after Menu during pending: mode=%s round=%d pending=%s ext=%d" % [game.mode, game.rules.state.round, str(game.pending_round), game.rules.state.external_decisions.size()])
	game._start_game("norte")
	for i in range(5): await process_frame
	p("D new norte game: round=%d pending=%s ext=%d" % [game.rules.state.round, str(game.pending_round), game.rules.state.external_decisions.size()])
	# ---- E: pending then keyboard mash
	game._resolve_round()
	for k in [KEY_1, KEY_2, KEY_3, KEY_BRACKETRIGHT, KEY_X, KEY_SPACE, KEY_SPACE, KEY_F5, KEY_T]:
		_key(k)
	for i in range(6): await process_frame
	p("E after key mash during pending: round=%d ext=%d pending=%s" % [game.rules.state.round, game.rules.state.external_decisions.size(), str(game.pending_round)])
	# ---- F: passivity in real scene
	game._start_game("norte")
	var rounds = 0
	while game.rules.state.status == "playing" and rounds < 20:
		game._resolve_round()
		for i in range(4): await process_frame
		game.resolution_remaining = 0
		rounds += 1
	p("F passivity: status=%s round=%d presses=%d pop=%.0f" % [game.rules.state.status, game.rules.state.round, rounds, game.rules.state.population])
	game.audio_manager.set_muted(true)
	await create_timer(0.1).timeout
	game.queue_free(); await process_frame
	quit(0)
