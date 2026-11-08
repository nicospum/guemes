extends SceneTree
## Revisión nube, lente B (guardado y carga). Falla hoy.
## Hallazgo: un guardado (o un punto de control) con la partida ya terminada (`status` victory/defeat, `phase` epilogo) pasa `validate_snapshot` y `load_game` /
## `restore_snapshot` lo aceptan (humahuaca_rules_save.gd l. 171-184 solo exige coherencia, no `status == "playing"`). La interfaz no distingue el caso: `_try_load_save`
## (humahuaca_ui_base.gd l. 689-710) pone `_ended = false`, `load_game()` deja `mode = "play"` y `_check_end` solo corre dentro de `_advance` (que exige `_playing()`),
## así que el jugador queda en el HUD de una partida terminada: sin parte, sin reintentos, con el «siguiente paso» en «fin». La interfaz nunca escribe un guardado
## así (`save_game()` exige `_playing()`), pero el archivo se edita y el punto de control se restaura por la misma API.
## Uso: godot --headless --path . --script tests/revision_nube/b_carga_partida_terminada.gd   (perfil user:// aislado: pisa save_humahuaca.json)
## Sale con 1 si falla (se carga y no hay parte) y 0 si pasa (se rechaza, o se abre el parte).

var game: Node
var hx: Node

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame

func _run() -> void:
	var R = load("res://scripts/humahuaca/rules/humahuaca_rules.gd")
	var r = R.new()
	r.new_game(1817, 1, {"phase": "extraccion"})
	r.retreat_all()
	var snap: Dictionary = r.snapshot()
	var scene := load("res://scenes/main.tscn") as PackedScene
	game = scene.instantiate()
	root.add_child(game)
	await _frames(4)
	game.jev.force_local = true
	game.settings.auto_pause = false
	if is_instance_valid(game.audio_manager):
		game.audio_manager.set_muted(true)
	var save_path := str(game._save_path("humahuaca"))
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(snap, "", true, true))
	f.close()
	game._load_game("humahuaca")  # «Continuar»
	await _frames(5)
	hx = game.hx
	var q: Dictionary = hx.qa_state()
	print("guardado con status=%s phase=%s" % [str(snap.status), str(snap.phase)])
	print("esperaba: rechazo con motivo (briefing), o el parte de la partida terminada (dialog «parte» / mode «ended»)")
	print("obtuve:   mode=%s status=%s dialog=«%s» siguiente=«%s»" % [str(q.mode), str(q.status), str(q.dialog), str(q.guide.text)])
	var failed := str(q.status) != "playing" and str(q.dialog) != "parte" and str(q.mode) != "ended"
	print("RESULTADO: ", "FALLA" if failed else "PASA")
	game._stop_humahuaca()
	await _frames(2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	game.queue_free()
	await process_frame
	quit(1 if failed else 0)

func _initialize() -> void:
	if OS.get_user_data_dir().to_lower().find("ap_iso") < 0:
		push_error("perfil NO aislado: exportá APPDATA=\"$TEMP/ap_iso_revision\" antes de correr (la prueba escribe o borra archivos de user://)")
		quit(2)
		return
	_run()
