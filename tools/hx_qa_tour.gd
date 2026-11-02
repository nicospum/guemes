extends SceneTree
## Recorrido de QA del nivel «humahuaca» con ventana real (CONTRATO 5.1; QA_NIVEL2 anexo D, pedido Q2). Dueño: compuertas y documentos.
## Uso: godot --path . --resolution 1280x720 --audio-driver Dummy [--disable-vsync] --script tools/hx_qa_tour.gd -- --out=<carpeta> [--size=WxH] [--seed=N] [--no-bot]
## Corre la escena real (main.tscn con el controlador) y escribe en --out el paquete que revisa el QA, con los mismos nombres que pide el anexo D:
##   vista_<id>.png y vista_<id>_sin_ui.png de las 7 vistas canónicas, más humahuaca-inicio.png y qa_report.json (lo escribe qa_run() del controlador, el mismo
##   que corre `--qa=humahuaca`); calib_inicial.png, calib_patio_posta.png y calib_grupos.png en render de albedo (set_albedo_mode), sin interfaz ni lluvia ni
##   fogonazos y con la cámara a 40° o más; limite_n/s/e/o.png con la cámara en el borde del mundo; hoja_fichas.png (5 celdas iguales en una fila, fondo liso,
##   fichas al tamaño real de pantalla de 1280 × 720); scene_names.txt (nodos de la vista y rutas de recursos).
## A qa_report.json le suma: schema, size_px, scene_build_ms, frame_ms_mean y frame_ms_p95 (intervalos de pared de 120 cuadros: con vsync activado no son el
## presupuesto del benchmark; usar --disable-vsync), templo_aabb_h_m, token_px, views.<id>.horizon_y, capas, controles visibles, límites, calibración y, salvo
## --no-bot, el arco de un bot que sigue el «siguiente paso» por la escena real (bot) y, medido sobre ese arco, jerga (palabras de la lista negra de humahuaca_ui.json en
## todo el texto visible), desbordes_texto (controles con texto que salen del cuadro), brecha_decision_s (el mayor tiempo sin un «siguiente paso» que se pueda apretar) y
## gramatica (contracciones sin hacer, como «de el cuartel»: se informan, no fallan la compuerta).
## POSICIONES EN PÍXELES DE LA CAPTURA: la vista y el controlador las dan en píxeles lógicos (el cuadro de 1440 × 900 que escala la ventana: 1600 × 900 en 16:9) y qa_imagen.py
## (V06) las usa como píxeles de la imagen; el recorrido convierte probes[].rect, views.<id>.horizon_y, initial_frame.targets y limites[].horizon_y y deja el valor original en
## *_logico y la escala en `escala`.
## Imprime «HX_QA_TOUR {json}» y sale con 0 si no hubo fallas. No es una partida humana. No usa semillas reservadas al QA: la semilla viene por --seed.

const V = preload("res://scripts/humahuaca/humahuaca_vocab.gd")
const VV = preload("res://scripts/humahuaca/view/vocab_view.gd")
const SHEET_BG := Color(1.0, 0.0, 1.0)  # fondo liso de la hoja de fichas: ningún color de la paleta se le parece
const SHEET_CELL := 160
const DIFF_MIN := 0.08  # suma de diferencias por canal (0 a 3) a partir de la cual un píxel es de la ficha

var game: Node
var hx: Node
var out_dir := ""
var out_abs := ""
var want_size := Vector2i.ZERO
var seed_arg := -1
var with_bot := true
var checks := 0
var failures: Array = []
var files: Array = []
var last_shot_size := Vector2i.ZERO
var ui_json: Dictionary = {}


func _initialize() -> void:
	if DisplayServer.get_name() == "headless" or OS.get_cmdline_args().has("--headless"):
		print("HX_QA_TOUR requiere ventana real (sin --headless): el motor headless no dibuja y las capturas saldrían vacías. Salida 2.")
		quit(2)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			if parts.size() == 2:
				want_size = Vector2i(int(parts[0]), int(parts[1]))
		elif arg.begins_with("--seed="):
			seed_arg = int(arg.trim_prefix("--seed="))
		elif arg == "--no-bot":
			with_bot = false
	if out_dir == "":
		push_error("hx_qa_tour: falta --out=<carpeta> (sin eso no se escribe en evidence/)")
		quit(2)
		return
	for stale in ["settings.cfg", "campaign.json", "justina_progress.json", "humahuaca_progress.json", "humahuaca_checkpoint.json", "save_humahuaca.json", "qa_humahuaca_progress.json"]:
		if FileAccess.file_exists("user://" + stale):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + stale))
	call_deferred("_run")


# ---------------------------------------------------------------------------------------------------------------------
# Ayudas

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func check(cond: bool, what: String) -> bool:
	checks += 1
	if not cond:
		failures.append(what)
		push_error(what)
	return cond


func _grab() -> Image:
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	last_shot_size = img.get_size()
	return img


func _shot(shot_name: String) -> Image:
	var img := await _grab()
	img.save_png(out_abs.path_join(shot_name + ".png"))
	files.append(shot_name + ".png")
	return img


func _apply_size() -> void:
	## Una ventana sin bordes cuyo tamaño se fija después del arranque llega a resoluciones que el SO recortaría con bordes (ver ui_qa_humahuaca).
	if want_size == Vector2i.ZERO:
		return
	root.mode = Window.MODE_WINDOWED
	root.borderless = true
	root.size = want_size
	root.position = Vector2i.ZERO
	await _frames(12)


func _pose(target: Vector2, dist: float, pitch: float, yaw: float) -> void:
	hx.qa_set_camera(target, dist, pitch, yaw)
	await _frames(5)


func _horizon_y(camera: Camera3D) -> float:
	## Altura en pantalla (px lógicos) del horizonte: el punto lejano en la dirección horizontal de la mirada, a la altura de la cámara. Negativa: queda sobre el cuadro.
	var t := camera.global_transform
	var fwd := -t.basis.z
	fwd.y = 0.0
	if fwd.length() < 0.001:
		return -1.0
	var far := t.origin + fwd.normalized() * 20000.0
	if camera.is_position_behind(far):
		return -1.0
	return snappedf(camera.unproject_position(far).y, 0.1)


func _node_bounds(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var b := m.global_transform * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


# ---------------------------------------------------------------------------------------------------------------------

func _run() -> void:
	out_abs = ProjectSettings.globalize_path(out_dir)
	DirAccess.make_dir_recursive_absolute(out_abs)
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await _frames(20)
	await _apply_size()
	game.jev.force_local = true
	game.settings.auto_pause = false
	game.qa_mode = true
	game.qa_path = out_abs
	if is_instance_valid(game.audio_manager):
		game.audio_manager.set_muted(true)
	var opts := {"qa": true, "skip_intro": true}
	if seed_arg >= 0:
		opts["seed"] = seed_arg
	game._start_humahuaca(opts)
	await _frames(30)
	hx = game.hx
	if not check(game.mode == "hx" and is_instance_valid(hx) and hx.has_method("qa_run") and hx.has_method("qa_state"), "Nivel: el controlador de Humahuaca arrancó con su API de QA"):
		await _finish({})
		return
	var state0: Dictionary = hx.qa_state()
	check(not bool(state0.get("shell", false)), "Nivel: el controlador es el real y no la cáscara")
	ui_json = V.load_json(V.UI_PATH)
	var camera: Camera3D = game.camera
	var build_ms := int(game.scene_build_ms)
	# 1) las 7 vistas canónicas con y sin interfaz y el qa_report.json del controlador (el mismo recorrido que `--qa=humahuaca`)
	await hx.qa_run()
	var report := _read_report()
	check(not report.is_empty(), "qa_run escribió qa_report.json")
	for id in VV.VIEW_IDS:
		check(FileAccess.file_exists(out_abs.path_join("vista_%s.png" % id)) and FileAccess.file_exists(out_abs.path_join("vista_%s_sin_ui.png" % id)), "Vista %s con y sin interfaz" % id)
	report["schema"] = "hx_qa_tour_v1"
	var git_out: Array = []
	if OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "rev-parse", "HEAD"], git_out) == 0 and git_out.size() > 0:
		report["commit"] = str(git_out[0]).strip_edges()
	report["engine"] = Engine.get_version_info().string
	report["renderer"] = RenderingServer.get_video_adapter_name()
	report["vsync"] = DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
	report["scene_build_ms"] = build_ms
	# 2) el horizonte y los probes de cada vista (para V06) y el cuadro inicial
	var views: Dictionary = report.get("views", {}) if report.get("views", null) is Dictionary else {}
	for id in VV.VIEW_IDS:
		var cv: Dictionary = hx.view.call("canonical_view", str(id))
		if cv.is_empty():
			continue
		var t3: Vector3 = cv.target
		await _pose(Vector2(t3.x, t3.z), float(cv.distance), float(cv.pitch_deg), float(cv.yaw_deg))
		var entry: Dictionary = views.get(str(id), {}) if views.get(str(id), null) is Dictionary else {}
		entry["horizon_y"] = _horizon_y(camera)
		entry["camera"] = {"target": [t3.x, t3.z], "dist": float(cv.distance), "pitch_deg": float(cv.pitch_deg), "yaw_deg": float(cv.yaw_deg), "time_of_day": float(cv.time_of_day), "rain": float(cv.rain)}
		views[str(id)] = entry
	report["views"] = views
	hx.reset_camera()
	hx.view.call("set_time_override", -1.0, -1.0)
	await _frames(6)
	# 3) tamaños de las fichas y del templo con el cuadro inicial
	var scale_y := root.get_final_transform().get_scale().y
	var token_px: Array = []
	for p in hx.view.call("probes", camera):
		if str((p as Dictionary).get("kind", "")) == "ficha":
			var rr: Array = (p as Dictionary).rect
			token_px.append({"id": str(p.id), "w": snappedf(float(rr[2]) * scale_y, 0.1), "h": snappedf(float(rr[3]) * scale_y, 0.1)})
	report["token_px"] = token_px
	check(token_px.size() == V.GROUPS.size(), "Cuadro inicial: las 5 fichas a la vista (%d)" % token_px.size())
	var temple: Variant = hx.view.buildings.lm_nodes.get("templo", null) if hx.view.buildings != null else null
	if temple is Node3D:
		report["templo_aabb_h_m"] = snappedf(_node_bounds(temple as Node3D).size.y, 0.01)
		check(float(report.templo_aabb_h_m) <= 8.0, "Templo: la caja de la forma mide %.2f m de alto (tope 8 m, sin torres de campanas)" % float(report.templo_aabb_h_m))
	# 4) intervalo de cuadro con el cuadro inicial (indicativo)
	await _frames(30)
	var samples: Array = []
	for i in range(120):
		var before := Time.get_ticks_usec()
		await process_frame
		samples.append((Time.get_ticks_usec() - before) / 1000.0)
	samples.sort()
	var total := 0.0
	for s in samples:
		total += float(s)
	report["frame_ms_mean"] = snappedf(total / samples.size(), 0.01)
	report["frame_ms_p95"] = snappedf(float(samples[int(samples.size() * 0.95)]), 0.01)
	# 5) calibración de albedo, límites de cámara, hoja de fichas y nombres de la escena
	report["calibracion"] = await _calibration()
	report["limites"] = await _limits()
	report["hoja_fichas"] = await _token_sheet()
	_scene_names()
	# 6) interfaz y capas
	var q: Dictionary = hx.qa_state()
	report["capas"] = q.get("layers", {})
	report["controles"] = {"visibles": int(q.get("visible_controls", 0)), "botones": int(q.get("visible_buttons", 0)), "caracteres": int(q.get("text_chars", 0)), "caracteres_juego": int(q.get("text_chars_juego", 0))}
	if with_bot:
		report["bot"] = await _bot_arc(report)
	_pixelize(report)
	_write_report(report)
	await _finish(report)


func _read_report() -> Dictionary:
	var f := FileAccess.open(out_abs.path_join("qa_report.json"), FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if parsed is Dictionary else {}


func _write_report(report: Dictionary) -> void:
	report["size_px"] = [last_shot_size.x, last_shot_size.y]
	var present := Array(DirAccess.get_files_at(out_abs))
	present.sort()
	report["archivos"] = present
	report["checks"] = checks
	report["failures"] = failures
	var f := FileAccess.open(out_abs.path_join("qa_report.json"), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "\t"))
		f.close()


func _finish(report: Dictionary) -> void:
	if report.is_empty():
		_write_report({})
	print("HX_QA_TOUR " + JSON.stringify({"checks": checks, "failures": failures, "ok": failures.is_empty(), "archivos": DirAccess.get_files_at(out_abs).size(), "size_px": [last_shot_size.x, last_shot_size.y]}))
	await _frames(3)
	quit(0 if failures.is_empty() else 1)


# ---------------------------------------------------------------------------------------------------------------------
# Calibración de albedo (V04): sin luz, niebla, exposición ni sombras; lluvia 0; sin interfaz; cámara a 40° o más

func _calibration() -> Dictionary:
	var out := {}
	hx.qa_set_ui_visible(false)
	hx.view.call("set_time_override", 0.5, 0.0)
	hx.view.call("set_albedo_mode", true)
	await _frames(4)
	var f: Dictionary = hx.initial_pose()
	await _pose(f.target, float(f.dist), maxf(float(f.pitch_deg), 40.0), float(f.yaw_deg))
	await _shot("calib_inicial")
	out["calib_inicial"] = {"pitch_deg": maxf(float(f.pitch_deg), 40.0)}
	var posta := hx.landmark_pos("posta") as Vector2
	await _pose(posta, 110.0, 55.0, 90.0)
	await _shot("calib_patio_posta")
	out["calib_patio_posta"] = {"pitch_deg": 55.0}
	var cx := 0.0
	var cz := 0.0
	for g in V.GROUPS:
		var u: Dictionary = hx.rules.get_unit(str(g))
		cx += float(u.x)
		cz += float(u.z)
	await _pose(Vector2(cx / V.GROUPS.size(), cz / V.GROUPS.size()), 260.0, 50.0, 325.0)
	await _shot("calib_grupos")
	out["calib_grupos"] = {"pitch_deg": 50.0}
	hx.view.call("set_albedo_mode", false)
	hx.view.call("set_time_override", -1.0, -1.0)
	hx.qa_set_ui_visible(true)
	await _frames(4)
	return out


# ---------------------------------------------------------------------------------------------------------------------
# Cámara en el borde del mundo (R06): mirando hacia afuera, para que se vea si hay huecos o borde

func _limits() -> Array:
	var out: Array = []
	var bounds: Rect2 = hx.view.call("camera_bounds")
	hx.qa_set_ui_visible(false)
	var poses := {
		"n": {"target": Vector2(450.0, bounds.position.y), "yaw": 0.0},
		"s": {"target": Vector2(450.0, bounds.end.y), "yaw": 180.0},
		"e": {"target": Vector2(bounds.end.x, 325.0), "yaw": 90.0},
		"o": {"target": Vector2(bounds.position.x, 325.0), "yaw": 270.0}}
	for key in ["n", "s", "e", "o"]:
		var p: Dictionary = poses[key]
		await _pose(p.target, 160.0, 14.0, float(p.yaw))  # poca inclinación: el horizonte entra en el cuadro y se ve si hay huecos o borde del mundo
		await _shot("limite_" + key)
		var camera: Camera3D = game.camera
		out.append({"borde": key, "target": [(p.target as Vector2).x, (p.target as Vector2).y], "yaw_deg": float(p.yaw), "horizon_y": _horizon_y(camera), "cam_y": snappedf(camera.global_position.y, 0.1)})
	hx.qa_set_ui_visible(true)
	hx.reset_camera()
	await _frames(4)
	return out


# ---------------------------------------------------------------------------------------------------------------------
# Hoja de fichas (V03): cada ficha recortada por diferencia entre el cuadro con y sin la capa de fichas, sobre fondo liso y a escala de 1280 × 720

func _token_sheet() -> Dictionary:
	var info := {"celdas": 0, "alto_px": {}}
	hx.qa_set_ui_visible(false)
	hx.view.call("set_time_override", 0.9, 0.0)
	var pose: Dictionary = hx.initial_pose()  # el zoom por defecto; cada ficha se centra en el cuadro para que ni el borde ni otra ficha la recorten
	var camera: Camera3D = game.camera
	var fichas := hx.view.get_node_or_null("Fichas") as Node3D
	var anillos := hx.view.get_node_or_null("Anillos") as Node3D
	var aros: Array = []  # los anillos propios de cada ficha no son parte de su silueta: se apagan para la hoja
	if fichas != null:
		for mi in fichas.find_children("*", "MeshInstance3D", true, false):
			if str(mi.name) in ["anillo", "borde", "seleccion"] and (mi as MeshInstance3D).visible:
				aros.append(mi)
				(mi as MeshInstance3D).visible = false
	if anillos != null:
		anillos.visible = false
	var sheet := Image.create(SHEET_CELL * V.GROUPS.size(), SHEET_CELL, false, Image.FORMAT_RGBA8)
	sheet.fill(SHEET_BG)
	for i in range(V.GROUPS.size()):
		var gid := str(V.GROUPS[i])
		var u: Dictionary = hx.rules.get_unit(gid)
		await _pose(Vector2(float(u.x), float(u.z)), float(pose.dist), float(pose.pitch_deg), float(pose.yaw_deg))
		await _frames(3)
		var probes: Array = hx.view.call("probes", camera)
		var with_img := await _grab()
		if fichas != null:
			fichas.visible = false
		await _frames(4)
		var bare_img := await _grab()
		if fichas != null:
			fichas.visible = true
		var k := float(with_img.get_width()) / root.get_visible_rect().size.x  # píxeles de imagen por píxel lógico
		var real_scale := 720.0 / float(with_img.get_height())  # a cuántos píxeles de 1280 × 720 equivale un píxel de esta captura
		var rect := Rect2()
		for p in probes:
			if str((p as Dictionary).get("kind", "")) == "ficha" and str((p as Dictionary).get("id", "")) == gid:
				var rr: Array = (p as Dictionary).rect
				rect = Rect2(float(rr[0]), float(rr[1]), float(rr[2]), float(rr[3]))
		if rect.size == Vector2.ZERO:
			continue
		var grown := rect.grow(maxf(24.0, rect.size.y * 0.75))  # holgado: la ficha de los reconocedores (agachados) es más ancha que su rectángulo
		var area := Rect2i(Vector2i(grown.position * k), Vector2i(grown.size * k)).intersection(Rect2i(Vector2i.ZERO, with_img.get_size()))
		var token := _cut_token(with_img, bare_img, area)
		if token == null:
			continue
		if not is_equal_approx(real_scale, 1.0):
			token.resize(maxi(1, int(round(token.get_width() * real_scale))), maxi(1, int(round(token.get_height() * real_scale))), Image.INTERPOLATE_NEAREST)
		var dst := Vector2i(i * SHEET_CELL + (SHEET_CELL - token.get_width()) / 2, SHEET_CELL - 12 - token.get_height())
		sheet.blend_rect(token, Rect2i(Vector2i.ZERO, token.get_size()), dst)
		info.celdas += 1
		(info.alto_px as Dictionary)[gid] = token.get_height()
	if anillos != null:
		anillos.visible = true
	for mi in aros:
		(mi as MeshInstance3D).visible = true
	sheet.convert(Image.FORMAT_RGB8)
	sheet.save_png(out_abs.path_join("hoja_fichas.png"))
	files.append("hoja_fichas.png")
	check(int(info.celdas) == V.GROUPS.size(), "Hoja de fichas: las 5 celdas tienen su ficha (%d)" % int(info.celdas))
	hx.view.call("set_time_override", -1.0, -1.0)
	hx.qa_set_ui_visible(true)
	hx.reset_camera()
	await _frames(4)
	return info


## El recorte (RGBA, transparente fuera de la ficha) de lo que cambia entre las dos capturas dentro de `area`: el mayor componente conexo de píxeles distintos.
@warning_ignore("integer_division")
func _cut_token(with_img: Image, bare_img: Image, area: Rect2i) -> Image:
	var w := area.size.x
	var h := area.size.y
	if w < 4 or h < 4:
		return null
	var mask := PackedByteArray()
	mask.resize(w * h)
	for y in range(h):
		for x in range(w):
			var a := with_img.get_pixel(area.position.x + x, area.position.y + y)
			var b := bare_img.get_pixel(area.position.x + x, area.position.y + y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > DIFF_MIN:
				mask[y * w + x] = 1
	var seen := PackedByteArray()
	seen.resize(w * h)
	var best: Array = []
	for start in range(w * h):
		if mask[start] == 0 or seen[start] == 1:
			continue
		var comp: Array = []
		var stack: Array = [start]
		seen[start] = 1
		while not stack.is_empty():
			var i: int = stack.pop_back()
			comp.append(i)
			var x := i % w
			var y := i / w
			for n in [Vector2i(x - 1, y), Vector2i(x + 1, y), Vector2i(x, y - 1), Vector2i(x, y + 1)]:
				if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h:
					continue
				var ni: int = n.y * w + n.x
				if mask[ni] == 1 and seen[ni] == 0:
					seen[ni] = 1
					stack.append(ni)
		if comp.size() > best.size():
			best = comp
	if best.size() < 30:
		return null
	var x0 := w
	var y0 := h
	var x1 := 0
	var y1 := 0
	for i in best:
		var x: int = int(i) % w
		var y: int = int(i) / w
		x0 = mini(x0, x)
		y0 = mini(y0, y)
		x1 = maxi(x1, x)
		y1 = maxi(y1, y)
	var token := Image.create(x1 - x0 + 1, y1 - y0 + 1, false, Image.FORMAT_RGBA8)
	token.fill(Color(0, 0, 0, 0))
	for i in best:
		var x: int = int(i) % w
		var y: int = int(i) / w
		var c := with_img.get_pixel(area.position.x + x, area.position.y + y)
		token.set_pixel(x - x0, y - y0, Color(c.r, c.g, c.b, 1.0))
	return token


# ---------------------------------------------------------------------------------------------------------------------
# Nombres de la escena (H02): nodos de la vista con su clase y las rutas de recursos que cargan

func _scene_names() -> void:
	var lines: Array = []
	var shaders := {}
	var meshes := {}
	if is_instance_valid(hx.view):
		_walk(hx.view, "", lines, shaders, meshes)
	lines.append("")
	lines.append("# shaders")
	for p in shaders.keys():
		lines.append(str(p))
	lines.append("# mallas con ruta de recurso")
	for p in meshes.keys():
		lines.append(str(p))
	var f := FileAccess.open(out_abs.path_join("scene_names.txt"), FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(PackedStringArray(lines)))
		f.close()
		files.append("scene_names.txt")
	check(lines.size() > 20, "scene_names.txt trae los nodos de la vista (%d líneas)" % lines.size())


func _walk(n: Node, path: String, lines: Array, shaders: Dictionary, meshes: Dictionary) -> void:
	var here := path + "/" + str(n.name)
	var extra := ""
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null and mi.mesh.resource_path != "":
			extra += " mesh=" + mi.mesh.resource_path
			meshes[mi.mesh.resource_path] = true
		for mat in [mi.material_override, mi.get_active_material(0)]:
			if mat is ShaderMaterial and (mat as ShaderMaterial).shader != null and (mat as ShaderMaterial).shader.resource_path != "":
				shaders[(mat as ShaderMaterial).shader.resource_path] = true
	var script: Variant = n.get_script()
	if script is Script and (script as Script).resource_path != "":
		extra += " script=" + (script as Script).resource_path
	lines.append("%s [%s]%s" % [here, n.get_class(), extra])
	for c in n.get_children():
		_walk(c, here, lines, shaders, meshes)


# ---------------------------------------------------------------------------------------------------------------------
# El arco de un bot que sigue el «siguiente paso» por la escena real (como la política «interfaz» de humahuaca_playthrough). Mientras juega mide el texto
# visible en cada paso (jerga y contracciones sin hacer), los controles con texto que salen del cuadro cada 15 s (después de dibujar) y la brecha de decisión: el mayor tiempo sin
# un «siguiente paso» que se pueda apretar.

func _bot_arc(report: Dictionary) -> Dictionary:  # corrutina: espera cuadros para medir la geometría
	hx.view.call("set_time_override", -1.0, -1.0)
	hx.qa_set_time(0.0)
	var used := 0.0
	var last_press := 0.0
	var gap_max := 0.0
	var gap_attack_max := 0.0
	var texts := {}
	var overflow := {}
	while used < 900.0 and str(hx.rules.state.status) == "playing":
		var phase := str(hx.rules.state.get("phase", ""))
		if hx.qa_press_next():
			gap_max = maxf(gap_max, used - last_press)
			if phase == "ataque":
				gap_attack_max = maxf(gap_attack_max, used - last_press)
			last_press = used
		hx.qa_step(1.0)
		used += 1.0
		_sample_texts(texts, overflow, false)  # el texto cambia en cada paso; la geometría de los contenedores solo vale después de dibujar
		if int(used) % 15 == 0:
			await _frames(3)
			_sample_texts(texts, overflow, true)
	await _frames(3)
	_sample_texts(texts, overflow, true)
	var st: Dictionary = hx.rules.state
	var rep: Variant = hx.rules.call("campaign_report") if hx.rules.has_method("campaign_report") else {}
	var q: Dictionary = hx.qa_state()
	var out := {"status": str(st.get("status", "")), "elapsed_s": snappedf(float(st.get("elapsed", used)), 0.1), "primera_orden_s": q.get("first_order_s", -1), "ordenes": int(q.get("orders", 0))}
	if st.get("outcome", null) is Dictionary:
		out["cause_id"] = str((st.outcome as Dictionary).get("cause_id", ""))
	if rep is Dictionary:
		out["medal"] = str((rep as Dictionary).get("medal", ""))
	check(str(out.status) != "playing", "Bot: el intento terminó (%s)" % str(out.status))
	# lo medido sobre el texto y los controles que el bot tuvo a la vista
	var jerga: Array = []
	var gramatica: Array = []
	var rx_contraction := RegEx.new()
	rx_contraction.compile("(?i)(?<![\\p{L}])(de|a) el(?![\\p{L}])")  # «de el cuartel», «a el cuartel»: tendría que ser «del» y «al»
	for t in texts.keys():
		for hit in _jargon_hits(str(t)):
			jerga.append({"termino": hit, "texto": str(t).left(80)})
		var m := rx_contraction.search(str(t))
		if m != null:
			gramatica.append({"problema": "«%s» sin contraer" % m.get_string(), "texto": str(t).left(80)})
	_write_texts(texts)
	report["jerga"] = {"textos_distintos": texts.size(), "aciertos": jerga.size(), "detalle": jerga.slice(0, 8)}
	var overflow_list: Array = []
	for path in overflow.keys():
		overflow_list.append({"control": str(path).get_file(), "ruta": str(path).trim_prefix("/root/PatriaGuemes/"), "texto": overflow[path].texto, "rect": overflow[path].rect, "cuadro": overflow[path].cuadro})
	report["desbordes_texto"] = {"controles": overflow.size(), "detalle": overflow_list.slice(0, 8)}
	report["brecha_decision_s"] = {"max": snappedf(gap_max, 0.1), "ataque_max": snappedf(gap_attack_max, 0.1), "definicion": "mayor tiempo de juego entre dos «siguiente paso» que se pudieron apretar (la política del bot)"}
	report["gramatica"] = {"aciertos": gramatica.size(), "detalle": gramatica.slice(0, 8), "nota": "se informa y no falla la compuerta: lo decide el QA con los textos del juego"}
	check(jerga.is_empty(), "Texto: sin palabras de la lista negra en lo que el bot tuvo a la vista (%d textos distintos; %s)" % [texts.size(), str(jerga.slice(0, 3))])
	check(overflow.is_empty(), "Texto: ningún control con texto sale del cuadro durante el arco del bot (%s)" % str(overflow_list.slice(0, 3)))
	return out


## Todo el texto que se ve ahora (etiquetas, botones y textos con formato de la interfaz) y los controles con texto cuyo rectángulo sale del cuadro. Un control con opacidad
## efectiva casi nula (un aviso que entra o sale con su animación) no se ve y no cuenta.
func _sample_texts(texts: Dictionary, overflow: Dictionary, geometry: bool) -> void:
	if not is_instance_valid(game) or game.get("ui") == null:
		return
	var vp := Rect2(Vector2.ZERO, root.get_visible_rect().size).grow(1.0)
	for c in (game.ui as Node).find_children("*", "Control", true, false):
		var ctl := c as Control
		if not ctl.is_visible_in_tree() or _effective_alpha(ctl) < 0.05:
			continue
		var t := ""
		if ctl is Label:
			t = (ctl as Label).text
		elif ctl is Button:
			t = (ctl as Button).text
		elif ctl is RichTextLabel:
			t = (ctl as RichTextLabel).get_parsed_text()
		if t == "":
			continue
		texts[t] = true
		if not geometry:
			continue
		var r := ctl.get_global_rect()
		if r.size.x > 1.0 and r.size.y > 1.0 and not vp.encloses(r):
			var path := str(ctl.get_path())
			if not overflow.has(path):
				overflow[path] = {"texto": t.left(60), "rect": [snappedf(r.position.x, 0.1), snappedf(r.position.y, 0.1), snappedf(r.size.x, 0.1), snappedf(r.size.y, 0.1)], "cuadro": [vp.size.x, vp.size.y]}


## Todo el texto distinto que el bot tuvo a la vista, uno por línea y ordenado (textos_visibles.txt): para auditar a ojo o con grep la jerga, las contracciones y los anacronismos.
func _write_texts(texts: Dictionary) -> void:
	var lines: Array = []
	for t in texts.keys():
		lines.append(str(t).replace("\n", " ⏎ "))
	lines.sort()
	var f := FileAccess.open(out_abs.path_join("textos_visibles.txt"), FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(PackedStringArray(lines)) + "\n")
		f.close()
		files.append("textos_visibles.txt")


func _effective_alpha(item: CanvasItem) -> float:
	var a := item.self_modulate.a
	var n: Node = item
	while n is CanvasItem:
		a *= (n as CanvasItem).modulate.a
		n = n.get_parent()
	return a


func _fold(text: String) -> String:
	var out := text.to_lower()
	var from := "áéíóúüñ"
	var to := "aeiouun"
	for i in range(from.length()):
		out = out.replace(from[i], to[i])
	return out


## Las palabras de la lista negra de humahuaca_ui.json (siglas sensibles a mayúsculas, palabras sin distinguir mayúsculas ni tildes) y los identificadores en snake_case:
## la misma regla que usa tools/ui_qa_humahuaca.gd.
func _jargon_hits(text: String) -> Array:
	var hits: Array = []
	var folded := _fold(text)
	for term in ui_json.get("jargon_blacklist", []):
		var t := str(term)
		var is_sigla := t.length() >= 2 and t == t.to_upper()
		var rx := RegEx.new()
		rx.compile("(?<![A-Za-z0-9_])" + (t if is_sigla else _fold(t)) + "(?![A-Za-z0-9_])")
		if rx.search(text if is_sigla else folded) != null:
			hits.append(t)
	var snake := RegEx.new()
	snake.compile("\\b[a-z]+(?:_[a-z0-9]+)+\\b")
	if snake.search(text) != null:
		hits.append("snake_case")
	return hits


# ---------------------------------------------------------------------------------------------------------------------
# Posiciones en píxeles de la captura (lo que lee qa_imagen.py): la vista y el controlador las dan en píxeles lógicos

func _pixelize(report: Dictionary) -> void:
	var vis := root.get_visible_rect().size
	if vis.x <= 0.0 or last_shot_size.x <= 0:
		return
	var k := float(last_shot_size.x) / vis.x
	report["escala"] = {"captura_px": [last_shot_size.x, last_shot_size.y], "logico_px": [vis.x, vis.y], "px_por_unidad_logica": snappedf(k, 0.0001), "unidad_de_posiciones": "píxeles de la captura"}
	var shot := Rect2(0.0, 0.0, float(last_shot_size.x), float(last_shot_size.y))
	var views: Dictionary = report.get("views", {}) if report.get("views", null) is Dictionary else {}
	for id in views.keys():
		var e: Dictionary = views[id]
		if e.has("horizon_y"):
			e["horizon_y_logico"] = e["horizon_y"]
			e["horizon_y"] = snappedf(float(e["horizon_y"]) * k, 0.1)
		for p in e.get("probes", []):
			var rr: Array = p["rect"]
			p["rect_logico"] = rr.duplicate()
			var px := Rect2(float(rr[0]) * k, float(rr[1]) * k, float(rr[2]) * k, float(rr[3]) * k)
			p["rect"] = [snappedf(px.position.x, 0.1), snappedf(px.position.y, 0.1), snappedf(px.size.x, 0.1), snappedf(px.size.y, 0.1)]
			p["en_cuadro"] = px.intersects(shot)
	var frame: Dictionary = report.get("initial_frame", {}) if report.get("initial_frame", null) is Dictionary else {}
	for t in frame.get("targets", []):
		t["x_logico"] = t["x"]
		t["y_logico"] = t["y"]
		t["x"] = snappedf(float(t["x"]) * k, 0.1)
		t["y"] = snappedf(float(t["y"]) * k, 0.1)
	for lim in report.get("limites", []):
		lim["horizon_y_logico"] = lim["horizon_y"]
		lim["horizon_y"] = snappedf(float(lim["horizon_y"]) * k, 0.1)
