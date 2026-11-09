extends SceneTree
## Perfil de la construcción del nivel II al entrar desde el menú (QA ronda 2, Q-205). Con ventana real: arranca main.tscn, espera el precalentado del menú y
## aprieta el botón del capítulo II con un clic inyectado (como un jugador); anota main.scene_build_ms (lo que mide el benchmark), los pasos de hx.start()
## (start_stages_ms), los de la vista (view.build_stages_ms) y lo que tarda en llegar el primer cuadro dibujado. Una entrada por proceso: así se mide la PRIMERA
## entrada, la que vio el QA. Imprime «HX_BUILD {json}» y, con --out=<archivo>, agrega una línea JSON a ese archivo.
## Uso: godot --path . --resolution 1280x720 --script tools/hx_build_profile.gd -- [--out=<archivo.jsonl>] [--boot-wait=2.5]

var game: Node
var out := ""
var boot_wait := 2.5


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--boot-wait="):
			boot_wait = float(a.trim_prefix("--boot-wait="))
	call_deferred("_run")


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _button(part: String) -> Button:
	for b in root.find_children("*", "Button", true, false):
		var bb := b as Button
		if bb != null and bb.is_visible_in_tree() and not bb.disabled and part in bb.text:
			return bb
	return null


func _click(b: Control) -> void:
	var p := root.get_final_transform() * b.get_global_rect().get_center()
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = p
		e.global_position = p
		root.push_input(e)
		await process_frame


func _run() -> void:
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await _frames(20)
	game.jev.force_local = true
	game.settings.auto_pause = false
	if is_instance_valid(game.audio_manager):
		game.audio_manager.set_muted(true)
	var t_wait := Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t_wait) / 1000.0 < boot_wait:
		await process_frame
	var b := _button("HUMAHUACA")
	var t0 := Time.get_ticks_msec()
	if b != null:
		await _click(b)
	else:
		game._start_humahuaca({})
	await process_frame
	await RenderingServer.frame_post_draw
	var first_frame_ms := Time.get_ticks_msec() - t0
	await _frames(30)
	var hx: Node = game.hx
	var rep := {"scene_build_ms": int(game.scene_build_ms), "primer_cuadro_ms": first_frame_ms, "boton": b != null,
		"start": hx.get("start_stages_ms") if is_instance_valid(hx) else {}, "vista": hx.view.get("build_stages_ms") if is_instance_valid(hx) and is_instance_valid(hx.view) else {},
		"vista_total_ms": hx.view.get("build_ms") if is_instance_valid(hx) and is_instance_valid(hx.view) else -1.0, "mode": str(hx.get("mode")) if is_instance_valid(hx) else ""}
	print("HX_BUILD ", JSON.stringify(rep))
	if out != "":
		var f := FileAccess.open(out, FileAccess.READ_WRITE) if FileAccess.file_exists(out) else FileAccess.open(out, FileAccess.WRITE)
		if f != null:
			f.seek_end()
			f.store_line(JSON.stringify(rep))
			f.close()
	quit(0)
