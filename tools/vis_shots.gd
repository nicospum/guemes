extends SceneTree
## Capturas del aspecto de Justina (ronda 4). Uso: godot --path . --resolution 1440x900 --script tools/vis_shots.gd -- --out=<carpeta> [--tag=antes] [--only=texto]
## Ventana real (no --headless). No es una prueba de reglas: solo fija camara y marea y guarda PNG.
var game: Node
var out_dir := "res://evidence/justina-ui/calidad_r1"
var tag := ""
var only := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--tag="): tag = arg.trim_prefix("--tag=")
		elif arg.begins_with("--only="): only = arg.trim_prefix("--only=")
	call_deferred("_run")

func _frames(n: int) -> void:
	for i in range(n): await process_frame

func _shot(n: String) -> void:
	if only != "" and only not in n: return
	await _frames(4)
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(out_dir).path_join((tag + "_" if tag != "" else "") + n + ".png"))

func _cam(tx: float, tz: float, dist: float, pitch_deg: float, yaw_deg: float) -> void:
	game.cam_goal_active = false
	game.camera_target = Vector3(tx, game._ground_y(tx, tz), tz)
	game.camera_distance = dist
	game.camera_pitch = deg_to_rad(pitch_deg)
	game.camera_yaw = deg_to_rad(yaw_deg)
	game._apply_camera()

func _tide(t: float) -> void:
	game.rules.state.elapsed = t
	if game.rules.has_method("tide_at"):
		game.rules.state.water_level_m = float(game.rules.tide_at(t).level_m)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await _frames(10)
	game.jev.force_local = true
	game.forced_seed = 1806
	game._start_game("justine")
	await _frames(20)
	game._close_modal()
	await _frames(20)
	game.paused = true
	await _shot("01_inicial")
	_cam(330, 260, 520, 40, 0); await _shot("02_cenital_alto")
	game._view_all(); await _frames(90); await _shot("03_ver_todo")
	_cam(200, 260, 140, 35, -90); await _shot("04_costa_hacia_rio")
	_cam(120, 260, 60, 25, 90); await _shot("05_desde_barranca")
	_cam(230, 260, 90, 12, 0); await _shot("06_baja_orilla")
	_cam(450, 262, 220, 20, 0); await _shot("07_rio_buque")
	_cam(580, 262, 70, 15, -60); await _shot("08_buque_cerca")
	_cam(160, 220, 80, 28, 0); await _shot("09_alameda_fuerte")
	_cam(250, 300, 60, 45, 0); await _shot("10_grupos")
	_tide(450.0); await _frames(10)
	_cam(380, 280, 330, 38, 0); await _shot("11_bajante_bancos")
	_cam(300, 260, 100, 14, -90); await _shot("12_bajante_horizonte")
	_cam(450, 262, 600, 8, 90); await _shot("13_extremo_hacia_costa")
	_tide(0.0); await _frames(10)
	_cam(400, 260, 420, 5, 0); await _shot("14_cielo_horizonte_sur")
	_cam(200, 260, 700, 70, 180); await _shot("15_extremo_cenital_yaw180")
	_cam(120, 520, 300, 18, 135); await _shot("16_extremo_esquina_sur")
	_cam(120, 0, 300, 18, 45); await _shot("17_extremo_esquina_norte")
	var u0 = game.rules.state.units[0]
	_cam(float(u0.x), float(u0.z), 45, 28, -70); await _shot("18_grupo_cerca")
	_cam(134, 150, 160, 22, 0); await _shot("19_circo_desde_norte")
	_cam(580, 262, 70, 20, -125); await _shot("20_buque_popa_ensign")
	_cam(400, 262, 1100, 55, 0); await _shot("21_panorama_alto")
	quit()
