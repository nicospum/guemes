extends SceneTree
## Revisión en la nube, lente E (interfaz y flujo). Hallazgo: F9 (y «Cargar (F9)» del menú de pausa con un archivo dañado) dice «… Empezás de nuevo.» y no empieza nada.
## humahuaca_ui_base._try_load_save (l. 689-710) arma el aviso con texts.load.failed («No se pudo abrir la partida guardada: %s. Empezás de nuevo.»), pensado para
## «Continuar» desde el menú (donde sí se empieza de cero). humahuaca_ui_play.load_game (l. 22-28) reutiliza ese aviso en plena partida y vuelve sin tocar nada: el
## reloj y las órdenes siguen donde estaban mientras el cartel afirma que se empieza de nuevo. Esperado: o el aviso de F9 dice que la partida sigue como estaba,
## o F9 hace lo que el aviso dice.
## godot --headless --path . --script tests/revision_nube/e_f9_texto_empezas_de_nuevo.gd   (perfil user:// aislado). Sale con 1 si el defecto sigue.

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
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	game._start_humahuaca({"skip_intro": true})
	await _frames(4)
	hx = game.hx
	hx.hud.next_btn.pressed.emit()
	hx.qa_step(30.0)
	var before := float(hx.qa_state().elapsed)
	await _key(KEY_F9)
	await _frames(2)
	var toast := str(hx.qa_state().toast)
	var after := float(hx.qa_state().elapsed)
	var restarted := after < 0.5
	var claims_restart := toast.find("Empezás de nuevo") >= 0
	print("F9 sin guardado: aviso «%s»; reloj %.0f s → %.0f s" % [toast, before, after])
	_check(not (claims_restart and not restarted), "el aviso de F9 no dice «Empezás de nuevo» cuando la partida sigue donde estaba (aviso: «%s»; reloj %.0f s)" % [toast, after])
	# el mismo aviso por «Cargar (F9)» del menú de pausa con un archivo dañado (el botón está habilitado porque el archivo existe)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("esto no es json {")
	f.close()
	await _key(KEY_ESCAPE)
	var btn := game.find_child("HxPause_load", true, false) as Button
	if btn != null and not btn.disabled:
		btn.pressed.emit()
		await _frames(2)
		var toast2 := str(hx.qa_state().toast)
		var after2 := float(hx.qa_state().elapsed)
		print("«Cargar» con archivo dañado: aviso «%s»; ventana «%s»; reloj %.0f s" % [toast2, str(hx.qa_state().dialog), after2])
		_check(not (toast2.find("Empezás de nuevo") >= 0 and after2 >= 0.5), "el aviso de «Cargar» tampoco dice «Empezás de nuevo» cuando la partida sigue (aviso: «%s»)" % toast2)
	else:
		_check(false, "el botón «Cargar (F9)» existe y está habilitado con un archivo presente")
	hx.dialogs.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	game._stop_humahuaca()
	await _frames(2)
	game.queue_free()
	await process_frame
	print("resultado: %d fallas" % failures)
	quit(1 if failures > 0 else 0)
