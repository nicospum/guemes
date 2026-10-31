extends SceneTree
## Capturas de la ronda 5 (aspecto): vistas de juego a distintas mareas, buque, abordaje. Ventana real.
## Uso: godot --path . --resolution 1600x900 --script tools/vis_r5.gd -- --out=<carpeta> --tag=<tag> [--only=txt]
var game: Node
var out_dir := "res://evidence/justina-ui/diversion_r5"
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
	await _frames(6)
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
	game.rules.state.water_level_m = float(game.rules.tide_at(t).level_m)

func _hide_ui() -> Array:
	var hidden: Array = []
	for c in game.get_children():
		if c is CanvasLayer and c.visible: c.visible = false; hidden.append(c)
	return hidden

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
	var hid := _hide_ui()
	await _shot("a01_inicio_sinui")
	_cam(430, 270, 300, 50, -90); await _shot("a02_juego_marea_alta")
	for t in [200.0, 360.0, 520.0, 660.0]:
		_tide(t); await _frames(10)
		_cam(430, 270, 300, 50, -90); await _shot("b_juego_t%d" % int(t))
	_tide(660.0); await _frames(10)
	_cam(580, 262, 90, 28, -70); await _shot("c1_buque_minimo")
	_cam(580, 262, 55, 14, -100); await _shot("c2_buque_rasante")
	_cam(480, 262, 140, 22, -90); await _shot("c3_buque_desde_oeste")
	_tide(0.0); await _frames(10)
	_cam(580, 262, 90, 28, -70); await _shot("c4_buque_alto")
	_tide(450.0); await _frames(10)
	_cam(450, 262, 600, 45, 90); await _shot("d1_panorama_baj")
	_cam(250, 270, 130, 30, -90); await _shot("d2_orilla_baj")
	_cam(160, 200, 120, 25, -90); await _shot("d3_barranca_fuerte")
	_cam(130, 150, 70, 22, 60); await _shot("d4_fuerte")
	# Abordaje: grupos junto al casco
	_tide(520.0); await _frames(10)
	var bp: Vector2 = game.rules.board_point()
	var k := 0
	for u in game.rules.state.units:
		u.x = bp.x - 6.0 + k * 3.0; u.z = bp.y + 6.0 * k - 6.0; u.stage = "boarding"; u.strength = 70.0; k += 1
	game.rules.state.capture = 42.0
	game.rules.state.boarded_at = 300.0
	await _frames(900)
	_cam(580, 262, 70, 35, -70); await _shot("e1_abordaje")
	_cam(540, 262, 160, 40, -90); await _shot("e2_abordaje_medio")
	game.rules.state.capture = 100.0
	await _frames(30)
	_cam(580, 262, 70, 35, -70); await _shot("e3_captura")
	for c in hid: c.visible = true
	await _shot("f_con_ui")
	quit()
