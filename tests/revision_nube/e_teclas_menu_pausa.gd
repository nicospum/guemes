extends SceneTree
## Revisión en la nube, lente E (interfaz y flujo). Hallazgo: con el menú de pausa abierto, sus botones anuncian «Guardar (F5)», «Cargar (F9)» y «Cómo se juega (F1)»
## (texts.pause en humahuaca_ui.json l. 163-165, humahuaca_dialogs.show_pause l. 170-177), pero humahuaca_ui_play._handle_key (l. 74-87) consume toda tecla mientras
## hay una ventana abierta: F5 no guarda, F9 no carga y F1 no abre la ayuda (solo Esc, Enter/Espacio y F11 hacen algo). Esperado: o las teclas anunciadas funcionan
## dentro del menú, o los rótulos no las anuncian.
## godot --headless --path . --script tests/revision_nube/e_teclas_menu_pausa.gd   (perfil user:// aislado). Sale con 1 si el defecto sigue.

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


func _label(id: String) -> String:
	var b := game.find_child("HxPause_%s" % id, true, false) as Button
	return str(b.text) if b != null else ""


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
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	game._start_humahuaca({"skip_intro": true})
	await _frames(4)
	hx = game.hx
	hx.hud.next_btn.pressed.emit()
	hx.qa_step(20.0)
	await _key(KEY_ESCAPE)
	_check(str(hx.qa_state().dialog) == "pausa", "Esc abre el menú de pausa (ventana «%s»)" % str(hx.qa_state().dialog))
	# F5
	var save_label := _label("save")
	await _key(KEY_F5)
	await _frames(1)
	var saved := FileAccess.file_exists(path)
	_check(not (save_label.find("F5") >= 0 and not saved), "el botón «%s» anuncia F5 y F5 guarda con el menú abierto (guardó: %s)" % [save_label, str(saved)])
	# F1
	var help_label := _label("help")
	await _key(KEY_F1)
	var dlg := str(hx.qa_state().dialog)
	_check(not (help_label.find("F1") >= 0 and dlg != "ayuda"), "el botón «%s» anuncia F1 y F1 abre la ayuda con el menú abierto (ventana: «%s»)" % [help_label, dlg])
	if dlg == "ayuda":
		await _key(KEY_ESCAPE)
	# F9 (con un guardado real hecho por el botón)
	(game.find_child("HxPause_save", true, false) as Button).pressed.emit()
	await _frames(1)
	var saved_elapsed := float(hx.qa_state().elapsed)
	await _key(KEY_ESCAPE)
	hx.qa_step(30.0)
	await _key(KEY_ESCAPE)
	var load_label := _label("load")
	await _key(KEY_F9)
	await _frames(1)
	var loaded := is_equal_approx(float(hx.qa_state().elapsed), saved_elapsed)
	_check(not (load_label.find("F9") >= 0 and not loaded), "el botón «%s» anuncia F9 y F9 carga con el menú abierto (reloj %.0f s, guardado %.0f s)" % [load_label, float(hx.qa_state().elapsed), saved_elapsed])
	hx.dialogs.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	game._stop_humahuaca()
	await _frames(2)
	game.queue_free()
	await process_frame
	print("resultado: %d fallas" % failures)
	quit(1 if failures > 0 else 0)
