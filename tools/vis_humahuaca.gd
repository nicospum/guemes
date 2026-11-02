extends SceneTree
## Capturas reales de la vista del nivel «humahuaca» (dueña: visual; CONTRATO 1.2). Con ventana (NO --headless): arma la vista sobre el terreno y las reglas
## (los stubs de las otras pistas si existen; si no, unas copias mínimas de este archivo), recorre las 7 vistas canónicas, mide `initial_frame` en cuatro
## resoluciones, prueba el picking y guarda JPEG de ≤ 300 KB más metrics_visual.json. No toca el repositorio: escribe solo en --out.
##
##   godot --path <repo> --resolution 1280x720 --audio-driver Dummy --script tools/vis_humahuaca.gd -- --out=<carpeta> [--view=stub|real] [--fakes]
##         [--quality=baja|media|alta] [--views=a,b,c] [--extras] [--index-base=N] [--bench] [--bench-tod=0.5 --bench-rain=0.4] [--tag=r1] [--hide=Grupo1,Grupo2]
## Con APPDATA aislado (export APPDATA="$TEMP/ap_iso_<pista>"). Los nombres de archivo son NN_<vista>_<tag>.jpg.

const STUB_VIEW := "res://scripts/humahuaca/stubs/stub_view.gd"
const REAL_VIEW := "res://scripts/humahuaca/view/humahuaca_view.gd"
const STUB_RULES := "res://scripts/humahuaca/stubs/stub_rules.gd"
const VIEW_IDS := ["acceso_so", "desde_bateria", "patio_posta", "panorama_alto", "grupos_en_accion", "juego_noche", "juego_alba"]
const SIZES := [Vector2i(1024, 640), Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const JPEG_QUALITY := 0.82
const JPEG_MAX_BYTES := 300 * 1024

var out_dir := ""
var which := "stub"
var quality := "media"
var tag := "r1"
var use_fakes := false
var bench := false
var extras := false
var index_base := 0
var bench_tod := 0.0
var bench_rain := 0.9
var only: PackedStringArray = PackedStringArray()
var hide: PackedStringArray = PackedStringArray()
var report := {"tool": "vis_humahuaca", "ok": true, "notes": [], "views": {}, "checks": {}}
var cam: Camera3D
var view = null
var rules: RefCounted
var fail_count := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var a := str(arg)
		if a.begins_with("--out="):
			out_dir = a.trim_prefix("--out=")
		elif a.begins_with("--view="):
			which = a.trim_prefix("--view=")
		elif a.begins_with("--quality="):
			quality = a.trim_prefix("--quality=")
		elif a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
		elif a.begins_with("--views="):
			only = a.trim_prefix("--views=").split(",")
		elif a.begins_with("--hide="):
			hide = a.trim_prefix("--hide=").split(",")
		elif a == "--fakes":
			use_fakes = true
		elif a == "--bench":
			bench = true
		elif a == "--extras":
			extras = true
		elif a.begins_with("--index-base="):
			index_base = int(a.trim_prefix("--index-base="))
		elif a.begins_with("--bench-tod="):
			bench_tod = float(a.trim_prefix("--bench-tod="))
		elif a.begins_with("--bench-rain="):
			bench_rain = float(a.trim_prefix("--bench-rain="))
	if out_dir == "":
		push_error("vis_humahuaca: falta --out=<carpeta>")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()


func _check(ok: bool, what: String) -> void:
	report.checks[what] = ok
	if not ok:
		fail_count += 1
		report.ok = false
		print("FALLA: " + what)


func _frames(n: int) -> void:
	for _i in range(n):
		await process_frame


func _run() -> void:
	await _frames(2)
	var t0 := Time.get_ticks_usec()
	var terrain_rules := _make_rules()
	rules = terrain_rules
	cam = Camera3D.new()
	cam.fov = 46.0
	cam.far = 9000.0
	root.add_child(cam)
	cam.current = true
	var view_path := REAL_VIEW if which == "real" and ResourceLoader.exists(REAL_VIEW) else STUB_VIEW
	report["view_script"] = view_path
	view = (load(view_path) as GDScript).new()
	root.add_child(view)
	view.build(rules, quality)
	for node_name in hide:  # depuración: oculta grupos de la vista por nombre (Terreno, Rasgos, Hitos, Fichas, Luces, Anillos, Defensores, Botin, Etiquetas, Efectos)
		var hidden: Node3D = view.get_node_or_null(node_name)
		if hidden != null:
			hidden.visible = false
	report["build_ms_total"] = float(Time.get_ticks_usec() - t0) / 1000.0
	report["build_ms_view"] = float(view.get("build_ms")) if view.get("build_ms") != null else -1.0
	report["window_px"] = [root.get_visible_rect().size.x, root.get_visible_rect().size.y]
	report["gpu"] = RenderingServer.get_video_adapter_name()
	report["godot"] = Engine.get_version_info().string
	report["quality"] = quality
	await _frames(3)
	var index := index_base
	for id in VIEW_IDS:
		if only.size() > 0 and not only.has(id):
			continue
		index += 1
		await _capture_view(index, id)
	if extras:
		await _capture_extras(index)
	await _frame_checks()
	await _picking_checks()
	if bench:
		await _bench()
	_finish()


# ---------------------------------------------------------------------------------------------------------------------
# Capturas

func _cam_xf(target: Vector3, distance: float, pitch_deg: float, yaw_deg: float) -> Transform3D:
	var yaw := deg_to_rad(yaw_deg)
	var pitch := deg_to_rad(pitch_deg)
	var look := Vector3(sin(yaw) * cos(pitch), -sin(pitch), -cos(yaw) * cos(pitch))
	return Transform3D(Basis.looking_at(look, Vector3.UP), target - look * distance)


func _capture_view(index: int, id: String) -> void:
	var v: Dictionary = view.canonical_view(id)
	_check(not v.is_empty() and (v.must_show as Array).size() == 5, "canonical_view(%s) devuelve la vista con 5 must_show" % id)
	if v.is_empty():
		return
	var target: Vector3 = v.target
	var distance: float = v.distance
	var pitch: float = v.pitch_deg
	var yaw: float = v.yaw_deg
	if id == "juego_noche" or id == "juego_alba":  # la cámara de juego es la inicial (puede ensancharse según el aspecto)
		var f: Dictionary = view.initial_frame(cam)
		target = f.target
		distance = f.distance
		pitch = f.pitch_deg
		yaw = f.yaw_deg
	cam.transform = _cam_xf(target, distance, pitch, yaw)
	view.set_time_override(float(v.time_of_day), float(v.rain))
	if rules.has_method("set_scene"):
		rules.set_scene("alba" if float(v.time_of_day) >= 0.4 else "noche")
	view.update_state(0.0)
	await _frames(4)
	view.update_state(0.016)
	await _frames(2)
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var file_name := "%02d_%s_%s.jpg" % [index, id, tag]
	var path := out_dir.path_join(file_name)
	img.save_jpg(path, JPEG_QUALITY)
	var bytes := FileAccess.get_file_as_bytes(path).size()
	_check(bytes <= JPEG_MAX_BYTES, "%s pesa %d bytes (tope %d)" % [file_name, bytes, JPEG_MAX_BYTES])
	report.views[id] = {"file": file_name, "bytes": bytes, "px": [img.get_width(), img.get_height()], "target": [target.x, target.y, target.z], "distance": distance,
		"pitch_deg": pitch, "yaw_deg": yaw, "time_of_day": float(v.time_of_day), "rain": float(v.rain), "must_show": v.must_show}


func _save_shot(index: int, name_: String, img: Image) -> String:
	var file_name := "%02d_%s_%s.jpg" % [index, name_, tag]
	var path := out_dir.path_join(file_name)
	img.save_jpg(path, JPEG_QUALITY)
	var bytes := FileAccess.get_file_as_bytes(path).size()
	_check(bytes <= JPEG_MAX_BYTES, "%s pesa %d bytes (tope %d)" % [file_name, bytes, JPEG_MAX_BYTES])
	report.views[name_] = {"file": file_name, "bytes": bytes, "px": [img.get_width(), img.get_height()]}
	return file_name


## Extras de apoyo: render de albedo (calibración de la paleta), minimapa, y selección con efectos.
func _capture_extras(index: int) -> void:
	var f: Dictionary = view.initial_frame(cam)
	cam.transform = _cam_xf(f.target, f.distance, f.pitch_deg, f.yaw_deg)
	view.set_time_override(1.0, 0.0)
	view.set_albedo_mode(true)
	await _frames(4)
	await RenderingServer.frame_post_draw
	_save_shot(index + 1, "albedo_inicial", root.get_texture().get_image())
	view.set_albedo_mode(false)
	var tex: Texture2D = view.get_minimap_texture(Vector2i(260, 188))
	_save_shot(index + 2, "minimapa", tex.get_image())
	view.set_time_override(0.5, 0.42)
	view.set_selected_ids(["portal", "arias"])
	for fx_spec in [["explosion", Vector2(318.0, 350.0)], ["humo", Vector2(418.0, 335.0)], ["captura", Vector2(590.0, 300.0)], ["senal", Vector2(350.0, 470.0)], ["fogonazo", Vector2(430.0, 340.0)]]:
		view.fx(fx_spec[0], fx_spec[1], {"scale": 2.5})
	view.update_state(0.35)
	await _frames(3)
	await RenderingServer.frame_post_draw
	_save_shot(index + 3, "seleccion_y_efectos", root.get_texture().get_image())
	view.set_selected_ids([])
	view.update_state(5.0)


func _frame_checks() -> void:
	var fits := {}
	for s in SIZES:
		var sub := SubViewport.new()
		sub.size = s
		sub.render_target_update_mode = SubViewport.UPDATE_DISABLED
		root.add_child(sub)
		var c := Camera3D.new()
		c.fov = 46.0
		sub.add_child(c)
		var f: Dictionary = view.initial_frame(c)
		fits["%dx%d" % [s.x, s.y]] = {"fits": f.fits, "distance": snappedf(float(f.distance), 0.1), "target": [snappedf(f.target.x, 0.1), snappedf(f.target.z, 0.1)]}
		_check(bool(f.fits), "initial_frame().fits a %dx%d (incluye los 3 objetivos y la zona de partida)" % [s.x, s.y])
		sub.queue_free()
	report["initial_frame"] = fits
	await _frames(1)


func _picking_checks() -> void:
	var f: Dictionary = view.initial_frame(cam)
	cam.transform = _cam_xf(f.target, f.distance, f.pitch_deg, f.yaw_deg)
	view.set_time_override(0.0, 0.9)
	await _frames(3)
	view.update_state(0.016)  # el controlador lo llama cada cuadro: recién ahí las fichas toman la escala de esta cámara
	await _token_heights()  # el alto de las fichas se mide con el cuadro inicial real
	cam.transform = _cam_xf(Vector3(250.0, 20.0, 500.0), 720.0, 52.0, 35.0)  # y el picking, con un cuadro amplio donde entran las cinco partidas
	await _frames(2)
	view.update_state(0.016)
	var picked := {"units": {}, "fronts": {}, "ground": {}}
	for id in ["rodriguez", "portal", "arias", "reconocedores", "arreo"]:
		var node: Node3D = view.unit_nodes.get(id)
		if node == null:
			continue
		var p := cam.unproject_position(_token_center(node))
		var got: String = view.pick_unit(cam, p)
		picked.units[id] = got
		_check(got == id, "pick_unit sobre la ficha de %s devuelve %s (devolvió «%s»)" % [id, id, got])
	_check(view.pick_unit(cam, Vector2(2.0, 2.0)) == "", "pick_unit en una esquina vacía devuelve «»")
	for id in ["bateria", "cuartel", "posta"]:
		var lm: Dictionary = view.get_landmark_info(id)
		if lm.is_empty():
			_check(false, "get_landmark_info(%s) existe" % id)
			continue
		var p := cam.unproject_position(Vector3(float(lm.x), float(lm.y) + 2.0, float(lm.z)))
		var got: String = view.pick_front(cam, p)
		picked.fronts[id] = got
		_check(got == id, "pick_front sobre %s devuelve %s (devolvió «%s»)" % [id, id, got])
		var g: Variant = view.ground_xz_from_screen(cam, cam.unproject_position(Vector3(float(lm.x), float(lm.y), float(lm.z))))
		if g is Vector2:
			picked.ground[id] = [snappedf(g.x, 0.1), snappedf(g.y, 0.1)]
			_check(Vector2(g.x, g.y).distance_to(Vector2(float(lm.x), float(lm.z))) < 3.0, "ground_xz_from_screen vuelve al hito %s a menos de 3 m (%.2f m)" % [id, Vector2(g.x, g.y).distance_to(Vector2(float(lm.x), float(lm.z)))])
		else:
			_check(false, "ground_xz_from_screen sobre %s devuelve un punto" % id)
	var all_units: Array = view.pick_units_in_rect(cam, Rect2(Vector2.ZERO, root.get_visible_rect().size))
	_check(all_units.size() == 5 and all_units[0] == "rodriguez", "pick_units_in_rect con toda la pantalla devuelve las 5 agrupaciones en el orden de GROUPS (%s)" % str(all_units))
	var frustum: PackedVector2Array = view.camera_frustum_on_ground(cam)
	_check(frustum.size() == 4, "camera_frustum_on_ground devuelve 4 puntos")
	var mpp: float = view.meters_per_pixel(cam)
	_check(mpp > 0.2 and mpp < 1.2, "meters_per_pixel en la cámara inicial ronda 0,55 m/px (%.3f)" % mpp)
	var tex: Texture2D = view.get_minimap_texture(Vector2i(260, 188))
	_check(tex != null and tex.get_width() == 260 and tex.get_height() == 188, "get_minimap_texture(260×188) devuelve una textura de ese tamaño")
	var labels: Array = view.landmark_labels(cam)
	_check(labels.size() >= 15, "landmark_labels devuelve los hitos (%d)" % labels.size())
	var probes: Array = view.probes(cam)
	var kinds := {}
	for p in probes:
		kinds[str(p.kind)] = int(kinds.get(str(p.kind), 0)) + 1
	_check(kinds.has("ficha") and kinds.has("objetivo") and kinds.has("suelo"), "probes trae fichas, objetivos y suelo (%s)" % str(kinds))
	report["picking"] = picked
	report["frustum_m"] = [[snappedf(frustum[0].x, 1.0), snappedf(frustum[0].y, 1.0)], [snappedf(frustum[2].x, 1.0), snappedf(frustum[2].y, 1.0)]] if frustum.size() == 4 else []
	report["meters_per_pixel"] = snappedf(mpp, 0.001)
	report["probe_kinds"] = kinds
	pass


func _token_heights() -> void:
	var screen_scale := root.get_screen_transform().get_scale().y  # píxeles reales por píxel lógico
	var token_px := {}
	for id in view.unit_nodes:  # alto parado de la figura (sin los anillos): de la base a la cima de sus piezas, proyectado, en píxeles reales
		var node: Node3D = view.unit_nodes[id]
		var top := node.global_position.y
		var wide := 0.0
		for mi in node.find_children("*", "MeshInstance3D", true, false):
			if str(mi.name) in ["anillo", "borde", "seleccion"]:
				continue
			var box: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			top = maxf(top, box.end.y)
			wide = maxf(wide, box.size.x)
		var base_px := cam.unproject_position(node.global_position)
		var top_px := cam.unproject_position(Vector3(node.global_position.x, top, node.global_position.z))
		token_px[id] = {"alto": snappedf(absf(base_px.y - top_px.y) * screen_scale, 0.1), "escala": snappedf(node.scale.y, 0.01), "cima_m": snappedf(top - node.global_position.y, 0.01),
			"distancia_m": snappedf(cam.global_position.distance_to(node.global_position), 0.1)}
		_check(float(token_px[id].alto) >= 40.0, "la ficha de %s mide %.1f px reales de alto con el cuadro inicial (el stub llega a ≈ 42 en el borde inferior; la vista real debe dar ≥ 48)" % [id, float(token_px[id].alto)])
	report["token_px"] = token_px
	report["screen_scale"] = snappedf(screen_scale, 0.001)


## El punto medio de la figura (de la base a la cima de sus piezas, sin los anillos).
func _token_center(node: Node3D) -> Vector3:
	var top := node.global_position.y
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		if not (str(mi.name) in ["anillo", "borde", "seleccion"]):
			top = maxf(top, ((mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()).end.y)
	return Vector3(node.global_position.x, (node.global_position.y + top) * 0.5, node.global_position.z)


func _bench() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var f: Dictionary = view.initial_frame(cam)
	cam.transform = _cam_xf(f.target, f.distance, f.pitch_deg, f.yaw_deg)
	view.set_time_override(bench_tod, bench_rain)
	await _frames(30)
	var times: Array = []
	var last := Time.get_ticks_usec()
	for _i in range(180):
		view.update_state(0.016)
		await process_frame
		var now := Time.get_ticks_usec()
		times.append(float(now - last) / 1000.0)
		last = now
	times.sort()
	var sum := 0.0
	for t in times:
		sum += float(t)
	report["bench"] = {"frames": times.size(), "frame_ms_mean": snappedf(sum / float(times.size()), 0.01), "frame_ms_p95": snappedf(float(times[int(times.size() * 0.95)]), 0.01),
		"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), "quality": quality, "time_of_day": bench_tod, "rain": bench_rain}


func _finish() -> void:
	report["nodes"] = view.find_children("*", "", true, false).size()
	report["checks_total"] = report.checks.size()
	report["fallas"] = fail_count
	var file := FileAccess.open(out_dir.path_join("metrics_visual.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("VIS_HUMAHUACA " + JSON.stringify({"checks": report.checks.size(), "fallas": fail_count, "build_ms_view": report.get("build_ms_view", -1.0), "out": out_dir}))
	quit(0 if fail_count == 0 else 1)


# ---------------------------------------------------------------------------------------------------------------------
# Reglas y terreno: los stubs de las otras pistas si existen; si no, unas copias mínimas

func _make_rules() -> RefCounted:
	if not use_fakes and ResourceLoader.exists(STUB_RULES):
		var script := load(STUB_RULES) as GDScript
		if script != null and script.can_instantiate():
			var r: RefCounted = script.new()
			r.new_game(1817, 1, {"skip_intro": true, "phase": "aproximacion"})
			report["rules_source"] = STUB_RULES
			return r
	report["rules_source"] = "copias mínimas de tools/vis_humahuaca.gd"
	return FakeRules.new()


class FakeTerrain extends RefCounted:
	var size_m := Vector2(900.0, 650.0)
	const LANDMARKS := [
		["templo", "Templo", "edificio", 450, 325, 0, {"w": 22, "d": 8}, 7.0, "sin_datos"],
		["bateria", "Batería de Santa Bárbara", "objetivo", 318, 350, 0, {"w": 28, "d": 18}, 3.0, "diseno"],
		["cuartel", "Cuartel, casa del cura", "objetivo", 418, 335, 0, {"w": 22, "d": 14}, 3.6, "diseno"],
		["posta", "Posta", "objetivo", 590, 300, 0, {"w": 30, "d": 24}, 2.4, "diseno"],
		["torre_casa_cura", "Torre de la casa del cura", "torre", 426, 326, 0, {"w": 3.5, "d": 3.5}, 10.0, "sin_datos"],
		["torre_templo", "Torre del templo", "torre", 466, 322, 0, {"w": 3.5, "d": 3.5}, 10.0, "sin_datos"],
		["plaza", "Plaza", "plaza", 450, 392, 0, {"w": 56, "d": 50}, 0.0, "diseno"],
		["polvorin", "Polvorín", "edificio", 604, 291, 0, {"w": 6, "d": 5}, 2.6, "diseno"],
		["parque", "Parque de artillería", "hito", 575, 312, 0, {"w": 10, "d": 6}, 1.2, "diseno"],
		["corral_posta", "Corral de la posta", "hito", 612, 314, 0, {"w": 20, "d": 14}, 1.2, "diseno"],
		["quebradita_norte", "Quebradita norte", "refugio", 282, 298, 0, {"w": 36, "d": 8}, 0.0, "diseno"],
		["quebradita_sur", "Quebradita sur", "refugio", 288, 402, 0, {"w": 36, "d": 8}, 0.0, "diseno"],
		["vado_este", "Vado del este", "acceso", 862, 340, 0, {"r": 12}, 0.0, "diseno"],
		["salida_este", "Salida este", "salida", 895, 332, 0, {"r": 10}, 0.0, "diseno"],
		["entrada_sur", "Entrada sur", "entrada", 540, 645, 0, {"r": 14}, 0.0, "diseno"],
		["zona_partida", "Zona de partida", "partida", 150, 505, 0, {"poly": [{"x": 60, "z": 470}, {"x": 260, "z": 470}, {"x": 260, "z": 570}, {"x": 60, "z": 570}]}, 0.0, "diseno"],
		["spawn_rodriguez", "Partida de Rodríguez", "partida", 92, 455, 0, {"r": 14}, 0.0, "diseno"],
		["spawn_portal", "Partida de Portal", "partida", 140, 500, 0, {"r": 14}, 0.0, "diseno"],
		["spawn_arias", "Partida de Arias", "partida", 190, 545, 0, {"r": 14}, 0.0, "diseno"],
		["spawn_reconocedores", "Partida de los reconocedores", "partida", 230, 480, 0, {"r": 14}, 0.0, "diseno"],
		["spawn_arreo", "Partida del arreo", "partida", 70, 520, 0, {"r": 14}, 0.0, "diseno"]]
	const RIVER := [[572, 0], [585, 40], [600, 85], [640, 120], [690, 150], [730, 190], [760, 230], [800, 262], [830, 300], [850, 335], [870, 365], [885, 385], [895, 402], [900, 406]]

	func height_at(x: float, z: float) -> float:
		var h := 17.0 + (450.0 - x) * 0.02 + (z - 325.0) * 0.004
		h += 12.0 * exp(-pow(Vector2(x - 305.0, z - 345.0).length() / 70.0, 2.0))
		h -= 2.5 * exp(-pow((x - 282.0) / 30.0, 2.0) - pow((z - 298.0) / 6.0, 2.0)) + 2.5 * exp(-pow((x - 288.0) / 30.0, 2.0) - pow((z - 402.0) / 6.0, 2.0))
		h -= 4.5 * exp(-pow(_river_dist(x, z) / 28.0, 2.0))
		return h + 0.4 * sin(x * 0.045) * sin(z * 0.05)

	func _river_dist(x: float, z: float) -> float:
		var best := 1.0e9
		for k in range(RIVER.size() - 1):
			var a := Vector2(RIVER[k][0], RIVER[k][1])
			var b := Vector2(RIVER[k + 1][0], RIVER[k + 1][1])
			best = minf(best, Geometry2D.get_closest_point_to_segment(Vector2(x, z), a, b).distance_to(Vector2(x, z)))
		return best

	func surface_at(x: float, z: float) -> String:
		var d := _river_dist(x, z)
		if d < 9.0:
			return "agua"
		if d < 30.0:
			return "sedimento_humedo"
		if d < 70.0 and x < 880.0:
			return "irrigado"
		if x < 300.0 and absf(z - 350.0) < 130.0:
			return "churqui"
		return "suelo_seco"

	func landmarks(_variant: Dictionary = {}) -> Array:
		var out: Array = []
		for r in LANDMARKS:
			out.append({"id": r[0], "name": r[1], "short": r[1], "type": r[2], "x": r[3], "z": r[4], "yaw_deg": r[5], "footprint": r[6], "height_m": r[7], "tag": r[8],
				"source": "copia mínima de tools/vis_humahuaca.gd", "priority": 1, "variant": {}})
		return out

	func landmark(id: String) -> Dictionary:
		for l in landmarks():
			if l.id == id:
				return l
		return {}

	func features(kind: String, _layout: String = "") -> Array:
		var out: Array = []
		if kind == "tapia":
			for line in [[[380, 240], [380, 300], [350, 330]], [[350, 360], [380, 380], [380, 450]], [[500, 230], [500, 300]], [[500, 350], [500, 440]], [[340, 440], [420, 440], [480, 440]],
					[[540, 250], [540, 330], [570, 330]], [[430, 250], [480, 250]], [[390, 300], [440, 300]], [[460, 360], [520, 360]], [[600, 340], [650, 340], [650, 400]],
					[[300, 400], [340, 400]], [[620, 250], [680, 250], [680, 300]], [[560, 420], [600, 420]]]:
				var pts: Array = []
				for p in line:
					pts.append({"x": p[0], "z": p[1]})
				out.append({"id": "t%d" % out.size(), "pts": pts, "height_m": 2.0 + float(out.size() % 3) * 0.2, "thickness_m": 0.5})
		elif kind == "zanja":
			for line in [[[560, 270], [610, 270]], [[620, 330], [660, 330]], [[470, 410], [520, 410]], [[330, 470], [400, 470]]]:
				out.append({"id": "z%d" % out.size(), "pts": [{"x": line[0][0], "z": line[0][1]}, {"x": line[1][0], "z": line[1][1]}], "width_m": 1.6})
		elif kind == "camino":
			out.append({"id": "camino_sur", "pts": [{"x": 540, "z": 650}, {"x": 530, "z": 560}, {"x": 470, "z": 450}, {"x": 450, "z": 390}], "width_m": 6.0})
		return out

	func river() -> Dictionary:
		var pts: Array = []
		for p in RIVER:
			pts.append({"x": p[0], "z": p[1]})
		return {"id": "rio_grande", "pts": pts, "bed_width_m": {"min": 25.0, "max": 40.0}}

	func minimap_image(px: Vector2i, _opts: Dictionary = {}) -> Image:
		var small := Vector2i(maxi(px.x / 4, 8), maxi(px.y / 4, 8))
		var img := Image.create(small.x, small.y, false, Image.FORMAT_RGBA8)
		for j in range(small.y):
			for i in range(small.x):
				var x := float(i) / float(small.x) * size_m.x
				var z := float(j) / float(small.y) * size_m.y
				var shade := clampf(0.72 + (height_at(x - 8.0, z) - height_at(x + 8.0, z)) * 0.04 + (height_at(x, z) - 17.0) * 0.004, 0.4, 1.0)
				img.set_pixel(i, j, Color(0.73 * shade, 0.60 * shade, 0.45 * shade) if surface_at(x, z) != "agua" else Color(0.55, 0.61, 0.57))
		img.resize(px.x, px.y, Image.INTERPOLATE_BILINEAR)
		return img


class FakeRules extends RefCounted:
	var _terrain := FakeTerrain.new()
	var _scene := "noche"
	var _version := 1

	func set_scene(scene_name: String) -> void:
		if scene_name != _scene:
			_scene = scene_name
			_version += 1

	func terrain() -> RefCounted:
		return _terrain

	func map_size() -> Vector2:
		return Vector2(900.0, 650.0)

	func environment() -> Dictionary:
		return {"phase": "noche" if _scene == "noche" else "alba", "time_of_day": 0.0 if _scene == "noche" else 0.5, "rain": 0.9 if _scene == "noche" else 0.4, "visibility_m": 35.0,
			"mud": 0.5, "firearm_reliability": 0.6}

	func render_state() -> Dictionary:
		var alba := _scene == "alba"
		var units: Array = []
		for u in [["rodriguez", 92.5, 455.0, 35.0, true], ["portal", 140.0, 500.0, 35.0, false], ["arias", 190.0, 545.0, 40.0, false], ["reconocedores", 230.0, 480.0, 60.0, false], ["arreo", 70.0, 520.0, 20.0, false]]:
			units.append({"id": u[0], "x": u[1], "z": u[2], "yaw_deg": u[3], "kind": "partida", "mounted": u[4], "stage": "idle", "strength_pct": 100.0, "men_visible": 8, "noise_state": "silencio",
				"detected": false, "carry_ratio": 0.0})
		var enemies: Array = []
		for e in [["c1", "centinela", 322.0, 338.0], ["c2", "centinela", 412.0, 322.0], ["c3", "centinela", 585.0, 288.0], ["g1", "guardia", 420.0, 348.0], ["a1", "artillero", 312.0, 356.0], ["g2", "guardia", 600.0, 310.0]]:
			enemies.append({"id": e[0], "kind": e[1], "x": e[2], "z": e[3], "alert": 0.0, "firing": alba and e[0] == "a1"})
		var lights: Array = [{"id": "luz_bateria", "kind": "brasero", "x": 316.0, "z": 348.0, "r_m": 26.0, "objective": "bateria"},
			{"id": "luz_cuartel", "kind": "ventana", "x": 418.0, "z": 330.0, "r_m": 22.0, "objective": "cuartel"}, {"id": "luz_posta", "kind": "candil", "x": 588.0, "z": 296.0, "r_m": 24.0, "objective": "posta"}]
		if alba:
			lights.append({"id": "fogata_1", "kind": "fogata", "x": 330.0, "z": 330.0, "r_m": 16.0})
			lights.append({"id": "fogata_2", "kind": "fogata", "x": 560.0, "z": 318.0, "r_m": 16.0})
		return {"version": _version, "t": 95.0, "phase": "ataque" if alba else "aproximacion", "env": environment(), "units": units,
			"objectives": [{"id": "bateria", "x": 318.0, "z": 350.0, "state": "guardado", "toma": 0.0, "alert": 0.1, "garrison_pct": -1.0, "under_fire": false},
				{"id": "cuartel", "x": 418.0, "z": 335.0, "state": "alertado" if alba else "guardado", "toma": 0.0, "alert": 0.1, "garrison_pct": -1.0, "under_fire": alba},
				{"id": "posta", "x": 590.0, "z": 300.0, "state": "guardado", "toma": 0.0, "alert": 0.0, "garrison_pct": -1.0, "under_fire": false}],
			"enemies": enemies,
			"loot": [{"id": "canones_bateria", "kind": "canones", "state": "en_sitio", "x": 318.0, "z": 346.0, "qty": 3}, {"id": "polvora_posta", "kind": "polvora", "state": "en_sitio", "x": 604.0, "z": 293.0, "qty": 4},
				{"id": "viveres_posta", "kind": "viveres", "state": "en_sitio", "x": 596.0, "z": 310.0, "qty": 5}],
			"fire_lines": [], "visibility_pools": [{"x": 92.5, "z": 455.0, "r": 35.0}, {"x": 230.0, "z": 480.0, "r": 35.0}], "marks": [], "horses": [], "lights": lights,
			"tower": {"x": 426.0, "z": 326.0, "next_volley_in_s": 3.0, "period_s": 7.5, "dead_angle_m": 12.0, "firing": alba}}
