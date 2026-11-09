extends SceneTree
## Capturas comparables «antes/después» del menú y de los tres niveles (encuadres por defecto de cada nivel, tras unos segundos de juego).
## Uso (ventana real, NO --headless):
##   godot --path . --resolution 1440x900 --script tools/captura_tres_niveles.gd -- --out=<carpeta absoluta> [--tag=antes]
## No es una prueba de reglas: arranca main.tscn, entra a cada nivel por _start_game y guarda PNG. Escribe solo en --out.
var game: Node
var out_dir := ""
var tag := "captura"

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--tag="): tag = arg.trim_prefix("--tag=")
	if out_dir == "":
		push_error("captura_tres_niveles: falta --out=<carpeta>")
		quit(2)
		return
	call_deferred("_run")

func _frames(n: int) -> void:
	for i in range(n): await process_frame

func _shot(n: String) -> void:
	await _frames(6)
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	var p := out_dir.path_join(tag + "_" + n + ".png")
	img.save_png(p)
	print("CAPTURA ", p)

func _secs(s: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(s * 1000.0):
		await process_frame

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	game.opening_pan = false  # visual/r1 paneo: sin paneo de apertura, el guion mide el encuadre inicial tal cual
	await _secs(2.0)
	await _shot("00_menu")
	# Nivel I
	game.jev.force_local = true
	game._start_game("justine")
	await _secs(1.5)
	await _shot("10_justina_intro")
	if game.has_method("_close_modal"): game._close_modal()
	await _secs(1.0)
	await _shot("11_justina_inicio")
	game.paused = false
	await _secs(6.0)
	await _shot("12_justina_en_juego")
	# Nivel II
	game._start_game("humahuaca")
	await _secs(2.5)
	await _shot("20_humahuaca_inicio")
	# Enter = «Empezar» en el briefing del nivel II (humahuaca_ui_play.gd), como lo haría el jugador
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = KEY_ENTER
		ev.physical_keycode = KEY_ENTER
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await process_frame
	await _secs(2.0)
	await _shot("21_humahuaca_tras_briefing")
	# Nivel III
	game._start_game("norte")
	await _secs(2.0)
	await _shot("30_norte_inicio")
	game._menu()
	await _secs(1.0)
	print("CAPTURA_FIN ok")
	quit(0)
