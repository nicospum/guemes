extends SceneTree
## Revisión en la nube, lente E (interfaz y flujo). Hallazgo: F2/F3/F4, + y − y los botones ×1 ×2 ×4 quitan la pausa.
## humahuaca_ui_play.set_speed_index (l. 245-254): «if paused and _playing() and not dialog: paused = false». CONTROLES.md dice que «el reloj arranca con tu primera
## orden o con Espacio» y la Justina (main._set_speed, l. 2004-2006) cambia la velocidad sin tocar la pausa; test_hx_flow (l. 413) describe lo esperado como «el ajuste
## de velocidad no cambia la pausa que ya estaba» (pero mide otra cosa). Quien pausa para pensar y deja lista la ×2 ve correr el reloj sin querer.
## Esperado: cambiar la velocidad con el juego en pausa deja la pausa como estaba.
## godot --headless --path . --script tests/revision_nube/e_velocidad_quita_pausa.gd   (perfil user:// aislado). Sale con 1 si el defecto sigue.

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
	game._start_humahuaca({"skip_intro": true})
	await _frames(4)
	hx = game.hx
	_check(bool(hx.qa_state().paused), "el nivel empieza en pausa")
	await _key(KEY_F3)
	_check(float(hx.qa_state().speed) == 2.0, "F3 fija ×2 (%.0f)" % float(hx.qa_state().speed))
	_check(bool(hx.qa_state().paused), "F3 con el juego en pausa lo deja en pausa (indicador: «%s»; esperaba «‖ EN PAUSA»)" % hx.hud.clock_l.text)
	hx.paused = true
	hx.refresh_hud_now()
	await _key(KEY_EQUAL)
	_check(bool(hx.qa_state().paused), "+ con el juego en pausa lo deja en pausa (indicador: «%s»)" % hx.hud.clock_l.text)
	hx.paused = true
	hx.refresh_hud_now()
	hx.hud.btn_speed[0].pressed.emit()
	await _frames(1)
	_check(bool(hx.qa_state().paused), "el botón ×1 con el juego en pausa lo deja en pausa (indicador: «%s»)" % hx.hud.clock_l.text)
	game._stop_humahuaca()
	await _frames(2)
	game.queue_free()
	await process_frame
	print("resultado: %d fallas" % failures)
	quit(1 if failures > 0 else 0)
