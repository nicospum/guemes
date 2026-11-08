extends SceneTree
## Revisión en la nube, lente E (interfaz y flujo). Hallazgo: un gesto del mouse que empieza antes de que se abra una ventana no termina nunca.
## humahuaca_ui_play.gd `_unhandled_input` (l. 165-166) descarta TODO el mouse mientras hay un diálogo abierto, incluida la soltada del botón: si el jugador
## arrastra el mapa con el botón del medio (o dibuja una caja con el izquierdo) y abre la ayuda (F1), el menú de pausa (Esc) o llega una ventana, la soltada se pierde,
## `_middle_drag`/`_pressing` quedan en true y `cam.drag_end()` no se llama. Al cerrar la ventana la cámara sigue pegada al mouse sin ningún botón apretado (y la
## caja de selección sigue creciendo) hasta el próximo clic. Esperado: cerrar o abrir una ventana termina el gesto (o la soltada se atiende aunque haya ventana).
## godot --headless --path . --script tests/revision_nube/e_arrastre_dialogo.gd   (perfil user:// aislado). Sale con 1 si el defecto sigue.

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


func _mouse_move(p: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = root.get_final_transform() * p
	e.global_position = e.position
	root.push_input(e)
	await process_frame


func _button(p: Vector2, button: int, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.position = root.get_final_transform() * p
	e.global_position = e.position
	e.button_index = button
	e.pressed = pressed
	e.button_mask = (1 << (button - 1)) if pressed else 0
	root.push_input(e)
	await process_frame


func _check(ok: bool, text: String) -> void:
	print(("OK: " if ok else "FALLA: ") + text)
	if not ok:
		failures += 1


func _target() -> Vector2:
	var t: Array = hx.qa_state().camera.target
	return Vector2(float(t[0]), float(t[1]))


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
	hx.qa_set_camera(Vector2(450, 325), 300.0, 50.0, 0.0)
	await _frames(2)
	var center := Vector2(640, 360)
	# 1) arrastre con el botón del medio, F1 con el botón apretado, soltada con la ayuda abierta, Esc
	await _mouse_move(center)
	await _button(center, MOUSE_BUTTON_MIDDLE, true)
	await _key(KEY_F1)
	await _button(center, MOUSE_BUTTON_MIDDLE, false)
	await _key(KEY_ESCAPE)
	_check(str(hx.qa_state().dialog) == "", "la ayuda se cerró con Esc (ventana: «%s»)" % str(hx.qa_state().dialog))
	var t0 := _target()
	await _mouse_move(center + Vector2(220, 0))
	await _frames(2)
	var t1 := _target()
	_check(not hx.cam.dragging(), "tras cerrar la ventana no queda un arrastre en curso (cam.dragging() = %s; esperaba false)" % str(hx.cam.dragging()))
	_check(t0.distance_to(t1) <= 1.0, "mover el mouse sin ningún botón apretado no mueve la cámara (objetivo %s → %s; esperaba igual)" % [str(t0), str(t1)])
	await _button(center, MOUSE_BUTTON_MIDDLE, true)
	await _button(center, MOUSE_BUTTON_MIDDLE, false)
	# 2) caja de selección con el botón izquierdo, Esc (menú de pausa) con el botón apretado, soltada con el menú abierto, Esc
	hx.hud.next_btn.pressed.emit()  # una orden: Esc abre el menú de pausa en vez de salir al menú
	await _frames(1)
	await _mouse_move(center)
	await _button(center, MOUSE_BUTTON_LEFT, true)
	await _mouse_move(center + Vector2(60, 40))
	await _key(KEY_ESCAPE)
	_check(str(hx.qa_state().dialog) == "pausa", "Esc con el botón apretado abre el menú de pausa (ventana: «%s»)" % str(hx.qa_state().dialog))
	await _button(center + Vector2(60, 40), MOUSE_BUTTON_LEFT, false)
	await _key(KEY_ESCAPE)
	await _mouse_move(center + Vector2(200, 150))
	await _frames(2)
	var box: Rect2 = hx.box_rect
	_check(box.size.length() < 3.0, "tras cerrar el menú no queda una caja de selección viva que siga al mouse (box_rect = %s; esperaba vacía)" % str(box))
	game._stop_humahuaca()
	await _frames(2)
	game.queue_free()
	await process_frame
	print("resultado: %d fallas" % failures)
	quit(1 if failures > 0 else 0)
