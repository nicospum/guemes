extends SceneTree
## Revisión nube · lente F (enganches) · robustez de los ganchos H3/H5 con el controlador del nivel vivo.
##
## main._start_humahuaca() empieza con _stop_humahuaca() (ADDENDA A-04: «si el nivel se arranca dos veces seguidas… el controlador anterior quedaba vivo y
## huérfano»), pero el caso simétrico no está cubierto: main._start_game("justine"|"norte") (main.gd l. 436-459) y main._load_game("justine"|"norte")
## (l. 922-938) no llaman a _stop_humahuaca(). Si se los invoca con mode == "hx", la Justina o el Norte arrancan con el controlador de Humahuaca
## todavía vivo e hijo de main: dos juegos a la vez, `hx` sigue apuntando al controlador y éste sigue moviendo main.camera en su _process (los dos
## _process pisan la misma cámara por cuadro). Ninguna pantalla ni tecla del juego llega hoy a ese camino (el menú detiene el nivel antes, F9/R solo
## valen con mode == "play" y exited("norte") detiene primero): es un borde de API, no una pantalla rota.
## Sale con 1 si después de _start_game("justine") o de _load_game("justine") con hx vivo el controlador sigue vivo o sigue siendo hijo de main.
## Perfil aislado obligatorio (borra archivos de perfil).
##   godot --headless --path . --script tests/revision_nube/f_start_game_con_hx_vivo.gd

const CLEAN := ["campaign.json", "justina_progress.json", "humahuaca_progress.json", "humahuaca_checkpoint.json", "settings.cfg", "save_humahuaca.json", "save_justine.json", "save_norte.json"]

var game: Node
var checks := 0
var failures: Array = []


func _initialize() -> void:
	if OS.get_user_data_dir().to_lower().find("ap_iso") < 0:
		print("perfil NO aislado (%s): esta prueba borra archivos de perfil; salida 2" % OS.get_user_data_dir())
		quit(2)
		return
	for n in CLEAN:
		if FileAccess.file_exists("user://" + n):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + n))
	call_deferred("_run")


func check(c: bool, what: String) -> bool:
	checks += 1
	if not c:
		failures.append(what)
	print(("ok: " if c else "FALLA: ") + what)
	return c


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _hx_children() -> int:
	var n := 0
	for c in game.get_children():
		var s: Script = c.get_script()
		if s != null and str(s.resource_path).find("humahuaca") >= 0:
			n += 1
	return n


func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	if not check(scene != null, "la escena principal carga"):
		_finish()
		return
	game = scene.instantiate()
	root.add_child(game)
	await _frames(4)
	game.jev.force_local = true
	game.settings.auto_pause = false
	game.forced_seed = 1806
	if is_instance_valid(game.audio_manager):
		game.audio_manager.set_muted(true)
	# una Justina guardada, para que _load_game("justine") tenga qué cargar
	game._start_game("justine")
	await _frames(3)
	if is_instance_valid(game.modal):
		game._close_modal()
	game._save_game(false)
	game._menu()
	await _frames(3)
	check(FileAccess.file_exists(game._save_path("justine")), "hay una partida de la Justina guardada")
	# (a) _start_game("justine") con el nivel vivo
	game._start_game("humahuaca")
	await _frames(3)
	check(game.mode == "hx" and is_instance_valid(game.hx) and _hx_children() == 1, "el nivel arranca (mode hx, un controlador hijo)")
	game._start_game("justine")
	await _frames(3)
	check(game.mode == "play" and str(game.rules.state.scenario) == "justine", "_start_game(\"justine\") arranca la Justina (mode play)")
	check(not is_instance_valid(game.hx) and game.hx == null and _hx_children() == 0, "H3: tras _start_game(\"justine\") el controlador de Humahuaca queda liberado y no es hijo de main (hx válido: %s, hijos del nivel: %d)" % [str(is_instance_valid(game.hx)), _hx_children()])
	game._stop_humahuaca()
	game._menu()
	await _frames(3)
	# (b) _load_game("justine") con el nivel vivo
	game._start_game("humahuaca")
	await _frames(3)
	check(game.mode == "hx" and is_instance_valid(game.hx) and _hx_children() == 1, "el nivel arranca otra vez (mode hx, un controlador hijo)")
	game._load_game("justine")
	await _frames(3)
	check(game.mode == "play" and str(game.rules.state.scenario) == "justine", "_load_game(\"justine\") carga la Justina (mode play)")
	check(not is_instance_valid(game.hx) and game.hx == null and _hx_children() == 0, "H5: tras _load_game(\"justine\") el controlador de Humahuaca queda liberado y no es hijo de main (hx válido: %s, hijos del nivel: %d)" % [str(is_instance_valid(game.hx)), _hx_children()])
	game._stop_humahuaca()
	game._menu()
	await _frames(3)
	# (c) T-001: _start_game("norte") con el nivel vivo; tras UN cuadro, un solo ambiente (el del Norte), sin lluvia y con la cámara del Norte.
	game._start_game("humahuaca")
	await _frames(3)
	game._start_game("norte")
	await process_frame
	var envs: Array = game.find_children("*", "WorldEnvironment", true, false).filter(func(n): return n.is_inside_tree())
	check(envs.size() == 1 and is_instance_valid(game.world) and game.world.is_ancestor_of(envs[0]), "T-001: tras _start_game(\"norte\") hay un solo WorldEnvironment y es el de game.world (%d)" % envs.size())
	check(game.find_children("lluvia_rayas", "", true, false).is_empty(), "T-001: no queda ningún nodo lluvia_rayas")
	check(is_equal_approx(game.camera.far, 400.0) and game.camera.current, "T-001: camera.far == 400 y la cámara de main es la vigente (far %.0f)" % game.camera.far)
	check(not is_instance_valid(game.hx) and _hx_children() == 0, "T-001: el controlador del II quedó liberado")
	game._menu()
	await _frames(3)
	for n in CLEAN:
		if FileAccess.file_exists("user://" + n):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + n))
	_finish()


func _finish() -> void:
	print(JSON.stringify({"suite": "revision_nube/f_start_game_con_hx_vivo", "checks": checks, "failures": failures}))
	if is_instance_valid(game):
		game.queue_free()
	await process_frame
	quit(1 if not failures.is_empty() else 0)
