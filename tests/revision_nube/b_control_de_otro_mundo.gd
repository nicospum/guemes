extends SceneTree
## Revisión nube, lente B (guardado y carga). Falla hoy.
## Hallazgo: el punto de control «posiciones» no está atado al mundo. `new_world()` (humahuaca_progress.gd l. 142-143) solo suma `_world_index` y no toca `_cp` ni el
## archivo; `has_checkpoint` (l. 322-323) y `retry_options` (l. 347-353) lo ofrecen por tipo, y `restore_checkpoint` (l. 329-345) no compara la semilla del control con
## `world_seed()`. Resultado: después de «Mundo nuevo» el parte ofrece «Reintentar desde las posiciones» del mundo anterior y, al elegirlo, vuelve la partida del
## mundo viejo (state.seed y game_id del mundo anterior) mientras el progreso y qa_state().seed dicen el mundo nuevo. En R1 los mundos son iguales (solo cambia el
## azar); con las variantes por semilla (R2b) el jugador vería otro pueblo.
## Uso: godot --headless --path . --script tests/revision_nube/b_control_de_otro_mundo.gd   (perfil user:// aislado: borra progreso, control y guardado del nivel)
## Sale con 1 si falla y 0 si pasa.

var game: Node
var hx: Node

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame

func rm(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	game = scene.instantiate()
	root.add_child(game)
	await _frames(4)
	game.jev.force_local = true
	game.settings.auto_pause = false
	if is_instance_valid(game.audio_manager):
		game.audio_manager.set_muted(true)
	for p in ["user://humahuaca_progress.json", "user://humahuaca_checkpoint.json", "user://save_humahuaca.json"]:
		rm(p)
	game._start_humahuaca({"skip_intro": true})
	await _frames(4)
	hx = game.hx
	var seed_a := int(hx.rules.state.seed)
	hx.hud.next_btn.pressed.emit()
	var steps := 0
	while steps < 80 and not hx.progress.has_checkpoint("posiciones"):
		hx.qa_press_next()
		hx.qa_step(5.0)
		steps += 1
	var got_cp: bool = hx.progress.has_checkpoint("posiciones")
	hx.rules.call("retreat_all")
	hx.qa_step(1.0)
	hx.retry("mundo_nuevo")
	await _frames(2)
	var seed_b := int(hx.rules.state.seed)
	var offered := false
	for o in hx.progress.retry_options():
		if str(o.id) == "posiciones" and bool(o.available):
			offered = true
	hx.hud.next_btn.pressed.emit()
	hx.qa_step(10.0)
	hx.rules.call("retreat_all")
	hx.qa_step(1.0)
	hx.retry("posiciones")
	await _frames(2)
	var seed_restored := int(hx.rules.state.seed)
	print("mundo A: semilla %d, control «posiciones» guardado: %s · «Mundo nuevo» -> semilla %d" % [seed_a, str(got_cp), seed_b])
	print("esperaba: tras «Mundo nuevo» el control del mundo A no se ofrece, o al restaurarlo la partida es del mundo B (%d)" % seed_b)
	print("obtuve:   se ofrece=%s; tras «Reintentar desde las posiciones» state.seed=%d game_id=%s · progress.world_seed=%d qa_state().seed=%d" % [str(offered), seed_restored, str(hx.rules.state.game_id), int(hx.progress.world_seed()), int(hx.qa_state().seed)])
	var failed := got_cp and seed_b != seed_a and (offered and seed_restored != seed_b)
	print("RESULTADO: ", "FALLA" if failed else "PASA")
	game._stop_humahuaca()
	await _frames(2)
	for p in ["user://humahuaca_progress.json", "user://humahuaca_checkpoint.json", "user://save_humahuaca.json"]:
		rm(p)
	game.queue_free()
	await process_frame
	quit(1 if failed else 0)

func _initialize() -> void:
	if OS.get_user_data_dir().to_lower().find("ap_iso") < 0:
		push_error("perfil NO aislado: exportá APPDATA=\"$TEMP/ap_iso_revision\" antes de correr (la prueba escribe o borra archivos de user://)")
		quit(2)
		return
	_run()
