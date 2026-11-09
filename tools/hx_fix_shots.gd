extends SceneTree
## Capturas fijas de antes/después para la ronda de corrección del QA (Q-204 parcelas, Q-209 escala del minimapa, Q-210 mañana y minimapa de día y rótulos).
## Con ventana real. Juega por la guía (siguiente paso + qa_step) con la semilla 1817 y saca, a los 2, 330 y 450 s de juego, los mismos encuadres con qa_set_camera
## (solo mueve la cámara) y un recorte del minimapa. Sirve para cualquier versión del nivel que tenga qa_set_camera y qa_step (se corre también sobre la base).
## Uso: godot --path <repo> --resolution 1280x720 --script tools/hx_fix_shots.gd -- --out=<carpeta> [--size=1280x720] [--tiempos=2,330,450]

var game: Node
var hx: Node
var out := ""
var wsize := Vector2i(1280, 720)
var log_lines: Array = []

const POSES := [["general", Vector2(450, 325), 470.0, 42.0, 325.0], ["parcela_oeste", Vector2(155, 410), 150.0, 32.0, 325.0],
	["parcela_este", Vector2(730, 340), 230.0, 34.0, 325.0], ["bateria_cerca", Vector2(-1, -1), 200.0, 30.0, 325.0]]
var TIMES := [2.0, 330.0, 450.0]


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--tiempos="):
			TIMES = []
			for t in a.trim_prefix("--tiempos=").split(","):
				TIMES.append(float(t))
		elif a.begins_with("--size="):
			var p := a.trim_prefix("--size=").split("x")
			wsize = Vector2i(int(p[0]), int(p[1]))
	DirAccess.make_dir_recursive_absolute(out)
	call_deferred("_run")


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _real_wait(s: float) -> void:
	var t0 := Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t0) / 1000.0 < s:
		await process_frame


func _shot(name_: String, crop: Rect2i = Rect2i()) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	if crop.size.x > 0:
		img = img.get_region(crop)
	img.save_png(out.path_join(name_ + ".png"))
	log_lines.append("SHOT %s %dx%d" % [name_, img.get_width(), img.get_height()])


func _minimap_rect() -> Rect2i:
	var mm: Control = hx.get("minimap") as Control
	if mm == null or not mm.is_visible_in_tree():
		return Rect2i()
	var r := mm.get_global_rect()
	var xf := root.get_final_transform()
	var p0 := xf * r.position
	var p1 := xf * r.end
	return Rect2i(Vector2i(int(p0.x) - 4, int(p0.y) - 4), Vector2i(int(p1.x - p0.x) + 8, int(p1.y - p0.y) + 8)).intersection(Rect2i(Vector2i.ZERO, root.size))


func _shoot(tag: String) -> void:
	for p in POSES:
		var at: Vector2 = p[1]
		if at.x < 0.0:
			at = hx.landmark_pos("bateria")
		hx.qa_set_camera(at, p[2], p[3], p[4])
		await _real_wait(0.6)
		await _shot("%s_%s" % [tag, p[0]])
	hx.reset_camera()
	await _real_wait(0.6)
	await _shot("%s_minimapa" % tag, _minimap_rect())
	var mm: Variant = hx.get("minimap")
	if mm != null and mm.has_method("scale_bar"):
		log_lines.append("ESCALA %s %s" % [tag, JSON.stringify(mm.call("scale_bar"))])


func _run() -> void:
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await _frames(10)
	root.mode = Window.MODE_WINDOWED
	root.size = wsize
	await _frames(6)
	game.jev.force_local = true
	game.settings.auto_pause = false
	if is_instance_valid(game.audio_manager):
		game.audio_manager.set_muted(true)
	game._start_humahuaca({"skip_intro": true, "seed": 1817})
	await _frames(6)
	hx = game.hx
	if str(hx.mode) != "play" and hx.has_method("_start_play_after_briefing"):
		hx._start_play_after_briefing(true)
		await _frames(4)
	var idx := 0
	var guard := 0
	while idx < TIMES.size() and guard < 2000:
		guard += 1
		var st: Dictionary = hx.qa_state()
		if str(st.get("mode", "")) != "play" or str(st.get("status", "playing")) != "playing":
			break
		if float(st.elapsed) >= float(TIMES[idx]):
			log_lines.append("T %.1f fase %s" % [float(st.elapsed), str(st.get("phase", ""))])
			await _shoot("t%03d" % int(TIMES[idx]))
			idx += 1
			continue
		hx._on_hud("next", null)
		hx.qa_step(minf(3.0, maxf(0.5, float(TIMES[idx]) - float(st.elapsed))))
		await _frames(2)
	var f := FileAccess.open(out.path_join("shots.log"), FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(log_lines) + "\n")
		f.close()
	print("HX_FIX_SHOTS ", JSON.stringify(log_lines))
	quit(0)
