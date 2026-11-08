extends SceneTree
## Revisión nube, lente B (guardado y carga). Falla hoy.
## Hallazgo: un F9 que no puede cargar (no hay archivo, o está dañado) deja en la línea roja del HUD el aviso «No se pudo abrir la partida guardada: …
## Empezás de nuevo.» de forma permanente, aunque la partida en curso sigue exactamente igual (no se empieza de nuevo). El texto sale de `_try_load_save`
## (humahuaca_ui_base.gd l. 709, `_notice`) y lo pinta `_warn_text` (humahuaca_ui_play.gd l. 706) en cada refresco del HUD; `load_game()` (humahuaca_ui_play.gd l. 22)
## solo lo limpia al empezar y nunca después de un fallo. El menú de pausa apaga «Cargar (F9)» sin archivo, pero la tecla F9 no está gateada.
## Uso: godot --headless --path . --script tests/revision_nube/b_f9_aviso_empezas_de_nuevo.gd   (perfil user:// aislado: borra save_humahuaca.json)
## Sale con 1 si falla (el aviso queda) y 0 si pasa.

var game: Node
var hx: Node

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame

func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	game = scene.instantiate()
	root.add_child(game)
	await _frames(4)
	game.jev.force_local = true
	game.settings.auto_pause = false
	if is_instance_valid(game.audio_manager):
		game.audio_manager.set_muted(true)
	var save_path := str(game._save_path("humahuaca"))
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	game._start_humahuaca({"skip_intro": true})
	await _frames(4)
	hx = game.hx
	hx.hud.next_btn.pressed.emit()
	hx.qa_step(30.0)
	var t_before := float(hx.qa_state().elapsed)
	var ok: bool = hx.load_game()  # F9 sin archivo guardado
	hx.qa_step(10.0)  # la partida sigue
	hx._refresh_hud(true)
	var warn := str(hx.hud.warn_l.text)
	var t_after := float(hx.qa_state().elapsed)
	var continues := not ok and str(hx.qa_state().status) == "playing" and t_after > t_before
	print("F9 sin archivo: ok=%s, la partida sigue (t %.1f -> %.1f): %s" % [str(ok), t_before, t_after, str(continues)])
	print("esperaba: la línea roja del HUD sin «Empezás de nuevo» (la partida no empezó de nuevo)")
	print("obtuve:   «%s»" % warn)
	var failed := warn.find("Empezás de nuevo") >= 0 or not continues
	print("RESULTADO: ", "FALLA" if failed else "PASA")
	game._stop_humahuaca()
	await _frames(2)
	game.queue_free()
	await process_frame
	quit(1 if failed else 0)

func _initialize() -> void:
	if OS.get_user_data_dir().to_lower().find("ap_iso") < 0:
		push_error("perfil NO aislado: exportá APPDATA=\"$TEMP/ap_iso_revision\" antes de correr (la prueba escribe o borra archivos de user://)")
		quit(2)
		return
	_run()
