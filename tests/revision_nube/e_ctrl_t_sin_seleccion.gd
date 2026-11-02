extends SceneTree
## Revisión en la nube, lente E (interfaz y flujo). Hallazgo: Ctrl+T (atacar a fondo) sin ninguna agrupación elegida no dice nada.
## humahuaca_ui_play._do_key (l. 138-139) manda Ctrl+T directo a orders.issue_selected("attack", …, {"posture": "a_fondo"}) sin pasar por orders.press, que es quien
## avisa «Elegí primero una agrupación (teclas 1 a 5).» (humahuaca_orders.gd l. 195-198). issue_selected (l. 221-240) recorre una selección vacía, no encuentra motivo y
## devuelve false sin llamar a on_order_failed: ni motivo, ni sonido de error. T a secas sí avisa. Esperado: el mismo aviso que T.
## godot --headless --path . --script tests/revision_nube/e_ctrl_t_sin_seleccion.gd   (perfil user:// aislado). Sale con 1 si el defecto sigue.

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


func _key(code: int, ctrl: bool) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		e.ctrl_pressed = ctrl
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
	game._start_humahuaca({"skip_intro": true})
	await _frames(4)
	hx = game.hx
	hx.select([], "replace")
	hx.set_motive("", false)
	await _key(KEY_T, false)
	await _frames(1)
	var plain := str(hx.qa_state().motive)
	_check(plain != "", "T sin selección avisa («%s»)" % plain)
	hx.set_motive("", false)
	hx.orders.last_error = ""
	await _key(KEY_T, true)
	await _frames(1)
	var with_ctrl := str(hx.qa_state().motive)
	_check(with_ctrl != "", "Ctrl+T sin selección avisa como T (motivo: «%s»; esperaba «%s»)" % [with_ctrl, plain])
	game._stop_humahuaca()
	await _frames(2)
	game.queue_free()
	await process_frame
	print("resultado: %d fallas" % failures)
	quit(1 if failures > 0 else 0)
