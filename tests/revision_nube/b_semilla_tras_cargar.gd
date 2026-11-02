extends SceneTree
## Revisión nube, lente B (guardado y carga). Falla hoy.
## Hallazgo: al abrir un guardado con «Continuar», el controlador conserva la semilla del progreso (`_seed = _pick_seed()` en `_begin_game`, humahuaca_ui_base.gd l. 588
## y 594-596) y no la de la partida cargada (`state.seed`). `qa_state().seed` la informa mal y, al perder, «Empezar de nuevo (mismo mundo)» (`retry`, humahuaca_ui_play.gd
## l. 1094-1102) arranca con la semilla del progreso: no es el mundo de la partida que se acaba de jugar. En R1 el mundo es fijo (world_from_seed ignora la semilla), así
## que hoy solo cambia el azar; con las variantes por semilla (R2b) sería otro mundo.
## Uso: godot --headless --path . --script tests/revision_nube/b_semilla_tras_cargar.gd   (perfil user:// aislado: pisa save_humahuaca.json y humahuaca_progress.json)
## Sale con 1 si falla y 0 si pasa.

var game: Node
var hx: Node

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame

func _run() -> void:
	var R = load("res://scripts/humahuaca/rules/humahuaca_rules.gd")
	var r = R.new()
	r.new_game(4242, 1, {"skip_intro": true})
	r.advance_to(30.0)
	var snap: Dictionary = r.snapshot()
	var scene := load("res://scenes/main.tscn") as PackedScene
	game = scene.instantiate()
	root.add_child(game)
	await _frames(4)
	game.jev.force_local = true
	game.settings.auto_pause = false
	if is_instance_valid(game.audio_manager):
		game.audio_manager.set_muted(true)
	for p in ["user://humahuaca_progress.json", "user://humahuaca_checkpoint.json"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	var save_path := str(game._save_path("humahuaca"))
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(snap, "", true, true))
	f.close()
	game._load_game("humahuaca")
	await _frames(5)
	hx = game.hx
	var seed_qa := int(hx.qa_state().seed)
	var seed_state := int(hx.rules.state.seed)
	hx.rules.retreat_all()
	hx.qa_step(1.0)
	hx.retry("mismo_mundo")
	await _frames(2)
	var seed_retry := int(hx.rules.state.seed)
	print("guardado con semilla %d; progreso nuevo (mundo %d)" % [int(snap.seed), int(hx.progress.world_seed())])
	print("esperaba: qa_state().seed == %d y «mismo mundo» con semilla %d" % [int(snap.seed), int(snap.seed)])
	print("obtuve:   qa_state().seed=%d, state.seed=%d, tras «mismo mundo» state.seed=%d" % [seed_qa, seed_state, seed_retry])
	var failed := seed_qa != int(snap.seed) or seed_retry != int(snap.seed)
	print("RESULTADO: ", "FALLA" if failed else "PASA")
	game._stop_humahuaca()
	await _frames(2)
	for p in [save_path, "user://humahuaca_progress.json", "user://humahuaca_checkpoint.json"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	game.queue_free()
	await process_frame
	quit(1 if failed else 0)

func _initialize() -> void:
	if OS.get_user_data_dir().to_lower().find("ap_iso") < 0:
		push_error("perfil NO aislado: exportá APPDATA=\"$TEMP/ap_iso_revision\" antes de correr (la prueba escribe o borra archivos de user://)")
		quit(2)
		return
	_run()
