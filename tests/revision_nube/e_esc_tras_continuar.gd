extends SceneTree
## Revisión en la nube, lente E (interfaz y flujo). Hallazgo: tras «Continuar» (o F9 desde el menú) con un guardado de menos de 20 s, Esc tira la partida al menú sin preguntar.
## humahuaca_ui_play._escape (l. 263-270) vuelve al menú «porque no hay nada que perder» si order_count == 0 y el reloj va por menos de esc_menu_free_s (20 s). Pero
## order_count es un contador de la sesión: _begin_game → _try_load_save (humahuaca_ui_base.gd l. 594-596) recupera una partida con órdenes en marcha y lo deja en 0, y
## load_game (humahuaca_ui_play.gd l. 22-41) tampoco lo toma del estado cargado. Resultado: con la partida recuperada (reconocedores en marcha, 8 s de reloj) Esc sale al
## menú de un golpe, mientras el botón «Menú» del HUD, con el mismo estado, abre el menú de pausa. Esperado: Esc se comporta como el botón «Menú» (o cuenta las órdenes
## de la partida recuperada).
## godot --headless --path . --script tests/revision_nube/e_esc_tras_continuar.gd   (perfil user:// aislado). Sale con 1 si el defecto sigue.

const Fx = preload("res://tests/hx_fixtures.gd")

var game: Node
var hx: Node
var failures := 0


func _initialize() -> void:
	if not Fx.profile_isolated():
		print("perfil NO aislado: exportá un user:// con «ap_iso» en el nombre")
		quit(2)
		return
	OS.set_low_processor_usage_mode_sleep_usec(300)
	call_deferred("_run")


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _key(code: int) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		root.push_input(e)
		await process_frame


func _check(ok: bool, text: String) -> void:
	print(("OK: " if ok else "FALLA: ") + text)
	if not ok:
		failures += 1


func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	game = scene.instantiate()
	root.add_child(game)
	await _frames(4)
	game.jev.force_local = true
	game.settings.auto_pause = false
	if is_instance_valid(game.audio_manager):
		game.audio_manager.set_muted(true)
	root.size = Vector2i(1280, 720)
	await _frames(6)
	var path := str(game._save_path("humahuaca"))
	game._start_humahuaca({"skip_intro": true})
	await _frames(4)
	hx = game.hx
	hx.hud.next_btn.pressed.emit()  # una orden real (los reconocedores salen a mirar)
	hx.qa_step(8.0)
	await _key(KEY_F5)
	_check(FileAccess.file_exists(path), "F5 escribe el guardado a los 8 s")
	game._stop_humahuaca()
	await _frames(2)
	game._load_game("humahuaca")  # lo que hace «Continuar»
	await _frames(4)
	hx = game.hx
	var stage := str(hx.rules.get_unit("reconocedores").stage)
	_check(game.mode == "hx" and stage == "moving", "la partida recuperada tiene a los reconocedores en marcha (%s)" % stage)
	await _key(KEY_ESCAPE)
	await _frames(3)
	var exited: bool = str(game.mode) == "menu"
	_check(not exited, "Esc sobre la partida recuperada abre el menú de pausa en vez de salir al menú sin preguntar (modo de main: «%s»; ventana: «%s»)" % [str(game.mode), str(hx.qa_state().dialog) if is_instance_valid(hx) else "—"])
	if is_instance_valid(game.hx):
		game._stop_humahuaca()
		await _frames(2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	game.queue_free()
	await process_frame
	print("resultado: %d fallas" % failures)
	quit(1 if failures > 0 else 0)
