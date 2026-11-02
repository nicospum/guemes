extends SceneTree
## Capturas reales de la vista del nivel «humahuaca» (dueña: visual; CONTRATO 1.2). Con ventana (NO --headless): arma la vista sobre el terreno y las reglas
## (los stubs de las otras pistas si existen; si no, unas copias mínimas de este archivo), recorre las 7 vistas canónicas, mide `initial_frame` en cuatro
## resoluciones, prueba el picking y guarda JPEG de ≤ 300 KB más metrics_visual.json. No toca el repositorio: escribe solo en --out.
##
##   godot --path <repo> --resolution 1280x720 --audio-driver Dummy --script tools/vis_humahuaca.gd -- --out=<carpeta> [--view=stub|real] [--fakes] [--relief=<carpeta>]
##         [--quality=baja|media|alta] [--views=a,b,c] [--extras] [--index-base=N] [--bench] [--bench-tod=0.5 --bench-rain=0.4] [--tag=r1] [--hide=Grupo1,Grupo2]
##         [--scenes=aproximacion,ataque,extraccion] [--no-views] [--cam=ui] [--flow=aproximacion,extraccion@321,ataque@300/cam=418;335;110;45;35] [--hero]
## `--view` elige la vista (por defecto la REAL si existe view/humahuaca_view.gd; `--view=stub` fuerza el stub). `--relief=<carpeta>` le da a la vista un relieve de verdad
## (humahuaca_dem.json de 91 × 66 a 10 m y humahuaca_fondo.json de 121 × 91 a 30 m, el DEM de Copernicus GLO-30 que preparó el explorador, FUERA del repositorio) sobre el
## terreno de respaldo: hasta que llegue la clase real de relieve_mapa, sin eso el suelo es un plano de +17 m. `--hero` suma el render héroe: el templo de cerca, la hoja de
## los tres arquetipos y el realista en color y en escala de grises a 48 px (mide el contraste de luminosidad L* entre pares).
## Con APPDATA aislado (export APPDATA="$TEMP/ap_iso_<pista>"). Los nombres de archivo son NN_<vista>_<tag>.jpg.
## `--scenes` arma las reglas (stub_rules) en esa fase y captura la cámara inicial con la luz y la lluvia que dan las reglas (sin override): es el cuadro
## que ve el jugador, no una vista canónica. De cada captura del cuadro de juego se informan la saturación del suelo, la parte de píxeles de «naranja
## saturado» (la medida del hallazgo I-R1.0-3) y los cruces entre anillos de visibilidad. Cada escena puede llevar un tiempo (`extraccion@321`: el reloj
## del stub de reglas se pisa a 321 s, el alba con la extracción en marcha). `--flow` hace lo mismo pero por la escena real (main.tscn + el controlador de
## ui_feel, con su interfaz y su cámara): es lo que ve el jugador y lo que captura el integrador.

const V = preload("res://scripts/humahuaca/humahuaca_vocab.gd")
const Gfx = preload("res://scripts/humahuaca/view/humahuaca_gfx.gd")
const Gen = preload("res://scripts/humahuaca/view/humahuaca_gen.gd")
const STUB_VIEW := "res://scripts/humahuaca/stubs/stub_view.gd"
const REAL_VIEW := "res://scripts/humahuaca/view/humahuaca_view.gd"
const STUB_RULES := "res://scripts/humahuaca/stubs/stub_rules.gd"
const VIEW_IDS := ["acceso_so", "desde_bateria", "patio_posta", "panorama_alto", "grupos_en_accion", "juego_noche", "juego_alba"]
const SIZES := [Vector2i(1024, 640), Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]
## La fase de las reglas con que se arma cada vista canónica (qué fichas, luces, torre y defensores hay en escena).
const VIEW_PHASE := {"acceso_so": "aproximacion", "desde_bateria": "ataque", "patio_posta": "extraccion", "panorama_alto": "aproximacion", "grupos_en_accion": "ataque",
	"juego_noche": "aproximacion", "juego_alba": "ataque@300"}
const JPEG_QUALITY := 0.82
const JPEG_MAX_BYTES := 300 * 1024

var out_dir := ""
var which := "auto"
var relief_dir := ""
var hero := false
var dress := true
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
var scenes: PackedStringArray = PackedStringArray()
var no_views := false
var flow: PackedStringArray = PackedStringArray()
var game: Node = null
var cam_ui := false  ## --cam=ui: la cámara como la arma hoy el controlador de ui_feel (posición a `yaw` del objetivo), no como rumbo de la mirada
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
		elif a.begins_with("--relief="):
			relief_dir = a.trim_prefix("--relief=")
		elif a == "--hero":
			hero = true
		elif a == "--no-dress":
			dress = false
		elif a.begins_with("--quality="):
			quality = a.trim_prefix("--quality=")
		elif a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
		elif a.begins_with("--views="):
			only = a.trim_prefix("--views=").split(",")
		elif a.begins_with("--hide="):
			hide = a.trim_prefix("--hide=").split(",")
		elif a.begins_with("--scenes="):
			scenes = a.trim_prefix("--scenes=").split(",", false)
		elif a == "--no-views":
			no_views = true
		elif a == "--cam=ui":
			cam_ui = true
		elif a.begins_with("--flow="):
			flow = a.trim_prefix("--flow=").split(",", false)
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
	if hero:
		await _run_hero()
		return
	if flow.size() > 0:
		await _run_flow()
		return
	var t0 := Time.get_ticks_usec()
	var terrain_rules := _make_rules()
	rules = terrain_rules
	cam = Camera3D.new()
	cam.fov = 46.0
	cam.far = 9000.0
	root.add_child(cam)
	cam.current = true
	var view_path := REAL_VIEW if which != "stub" and ResourceLoader.exists(REAL_VIEW) else STUB_VIEW
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
		if no_views or (only.size() > 0 and not only.has(id)):
			continue
		index += 1
		await _capture_view(index, id)
	for scene_name in scenes:
		index += 1
		await _capture_scene(index, scene_name)
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
	if cam_ui:  # como `humahuaca_ui._apply_camera`: la cámara está a `yaw` del objetivo y mira hacia él
		var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
		return Transform3D(Basis.looking_at(-offset, Vector3.UP), target + offset)
	var look := Vector3(sin(yaw) * cos(pitch), -sin(pitch), -cos(yaw) * cos(pitch))
	return Transform3D(Basis.looking_at(look, Vector3.UP), target - look * distance)


func _capture_view(index: int, id: String) -> void:
	rules = _make_rules(str(VIEW_PHASE.get(id, "aproximacion")))
	view.build(rules, quality)
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
	(report.views[id] as Dictionary).merge(_image_stats(img), true)


func _save_shot(index: int, name_: String, img: Image) -> String:
	var file_name := "%02d_%s_%s.jpg" % [index, name_, tag]
	var path := out_dir.path_join(file_name)
	img.save_jpg(path, JPEG_QUALITY)
	var bytes := FileAccess.get_file_as_bytes(path).size()
	_check(bytes <= JPEG_MAX_BYTES, "%s pesa %d bytes (tope %d)" % [file_name, bytes, JPEG_MAX_BYTES])
	report.views[name_] = {"file": file_name, "bytes": bytes, "px": [img.get_width(), img.get_height()]}
	return file_name


## El cuadro de juego tal como lo arman las reglas en una fase (la luz y la lluvia salen de `environment()`, sin override): lo que ve el jugador de verdad.
## Informa la saturación del suelo y los cruces entre anillos de visibilidad (la medida del hallazgo I-R1.0-3).
func _capture_scene(index: int, scene_name: String) -> void:
	var r := _make_rules(scene_name)
	rules = r
	view.build(r, quality)
	for node_name in hide:
		var hidden: Node3D = view.get_node_or_null(node_name)
		if hidden != null:
			hidden.visible = false
	view.set_time_override(-1.0, 0.0)
	var f: Dictionary = view.initial_frame(cam)
	cam.transform = _cam_xf(f.target, f.distance, f.pitch_deg, f.yaw_deg)
	view.update_state(0.0)
	await _frames(4)
	view.update_state(0.016)
	await _frames(2)
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var key := "juego_" + scene_name.replace("@", "_")
	_save_shot(index, key, img)
	var stats := _image_stats(img)
	var state: Dictionary = r.render_state() if r.has_method("render_state") else {}
	var env: Dictionary = state.get("env", {}) if state.get("env", null) is Dictionary else {}
	var pools: Array = state.get("visibility_pools", [])
	stats["tod"] = snappedf(float(env.get("time_of_day", -1.0)), 0.001)
	stats["lluvia"] = snappedf(float(env.get("rain", -1.0)), 0.001)
	stats["visibilidad_m"] = snappedf(float(env.get("visibility_m", -1.0)), 0.1)
	stats["anillos"] = pools.size()
	stats["pares_de_anillos_que_se_cruzan"] = _crossing_pairs(pools)
	var arcs: Array = _drawn_pool_arcs(pools)
	stats["anillos_dibujados_dentro_de_otros_m"] = snappedf(_arc_length_inside_others(arcs, pools), 0.1)
	stats["anillos_alpha"] = _pool_alpha(pools)
	(report.views[key] as Dictionary).merge(stats, true)
	_judge_stats(key, stats)


## Pisa el reloj del stub de reglas (solo para capturar, p. ej. el alba con la extracción en marcha) y marca el estado como cambiado.
func _set_clock(r: RefCounted, seconds: float) -> void:
	var inner: Variant = r.get("base")
	var target: RefCounted = inner if inner is RefCounted else r
	var state: Variant = target.get("state")
	if state is Dictionary and (state as Dictionary).has("elapsed"):
		state["elapsed"] = seconds
		state["render_state_version_bump"] = true
		state["render_version"] = int(state.get("render_version", 0)) + 1


## Las fases del juego por la escena real: main.tscn con el controlador de ui_feel (interfaz, cámara y reglas de verdad), como la captura el integrador.
func _run_flow() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	game = scene.instantiate()
	root.add_child(game)
	await _frames(4)
	game.jev.force_local = true  # nada de esta herramienta debe tocar la red
	game.settings.auto_pause = false
	if is_instance_valid(game.audio_manager):
		game.audio_manager.set_muted(true)
	report["window_px"] = [root.get_visible_rect().size.x, root.get_visible_rect().size.y]
	report["gpu"] = RenderingServer.get_video_adapter_name()
	report["godot"] = Engine.get_version_info().string
	report["quality"] = quality
	report["mode"] = "flow"
	var index := index_base
	for spec in flow:
		index += 1
		var pieces := spec.split("/")  # fase[@segundos][/cam=x;z;distancia;inclinación;guiñada]
		var parts := pieces[0].split("@")
		var close := false
		game._start_humahuaca({"skip_intro": true, "phase": parts[0]})
		await _frames(6)
		rules = game.hx.get("rules")
		view = game.hx.get("view")
		if parts.size() > 1 and rules != null:
			_set_clock(rules, float(parts[1]))
			await _frames(3)
		for extra in pieces.slice(1):
			if extra.begins_with("cam="):
				var c := extra.trim_prefix("cam=").split(";")
				if c.size() == 5:
					game.hx.call("qa_set_camera", Vector2(float(c[0]), float(c[1])), float(c[2]), float(c[3]), float(c[4]))
					close = true
		await _frames(3)
		game.hx.call("qa_state")  # refresca la interfaz
		await _frames(4)
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		var key := "flujo_" + pieces[0].replace("@", "_") + ("_cerca" if close else "")
		_save_shot(index, key, img)
		var below := img.get_region(Rect2i(0, int(img.get_height() * 0.16), img.get_width(), img.get_height() - int(img.get_height() * 0.16)))  # sin la cabecera
		var stats := _image_stats(below)
		var state: Dictionary = rules.render_state() if rules != null else {}
		var env: Dictionary = state.get("env", {}) if state.get("env", null) is Dictionary else {}
		var pools: Array = state.get("visibility_pools", [])
		stats["tod"] = snappedf(float(env.get("time_of_day", -1.0)), 0.001)
		stats["visibilidad_m"] = snappedf(float(env.get("visibility_m", -1.0)), 0.1)
		stats["anillos"] = pools.size()
		stats["pares_de_anillos_que_se_cruzan"] = _crossing_pairs(pools)
		stats["anillos_dibujados_dentro_de_otros_m"] = snappedf(_arc_length_inside_others(_drawn_pool_arcs(pools), pools), 0.1)
		stats["anillos_alpha"] = _pool_alpha(pools)
		stats["capas"] = game.hx.get("layers")
		if view != null:
			var cam3: Camera3D = game.camera
			stats["camara"] = {"pos": [snappedf(cam3.global_position.x, 0.1), snappedf(cam3.global_position.y, 0.1), snappedf(cam3.global_position.z, 0.1)],
				"mira_a": [snappedf(-cam3.global_transform.basis.z.x, 0.001), snappedf(-cam3.global_transform.basis.z.z, 0.001)], "fov": cam3.fov, "keep_aspect": cam3.keep_aspect,
				"viewport_logico": [cam3.get_viewport().get_visible_rect().size.x, cam3.get_viewport().get_visible_rect().size.y], "escala_pantalla": snappedf(root.get_screen_transform().get_scale().y, 0.001)}
			var heights := {}
			var screen_scale := root.get_screen_transform().get_scale().y
			for id in view.unit_nodes:
				var node: Node3D = view.unit_nodes[id]
				var top := node.global_position.y
				for mi in node.find_children("*", "MeshInstance3D", true, false):
					if not (str(mi.name) in ["anillo", "borde", "seleccion"]):
						top = maxf(top, ((mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()).end.y)
				var base_px := cam3.unproject_position(node.global_position)
				var top_px := cam3.unproject_position(Vector3(node.global_position.x, top, node.global_position.z))
				heights[id] = {"alto_px": snappedf(absf(base_px.y - top_px.y) * screen_scale, 0.1), "escala_y": snappedf(node.scale.y, 0.01), "distancia_m": snappedf(cam3.global_position.distance_to(node.global_position), 0.1), "en_pantalla": Rect2(Vector2.ZERO, root.get_visible_rect().size).has_point(base_px),
					"pantalla": [snappedf(base_px.x, 1.0), snappedf(base_px.y, 1.0)]}
			stats["fichas"] = heights
		(report.views[key] as Dictionary).merge(stats, true)
		_judge_stats(key, stats)
		report.checks["flujo %s: el controlador arma la vista" % spec] = view != null
		if view == null:
			fail_count += 1
			report.ok = false
	game.queue_free()
	await _frames(2)
	report["nodes"] = 0
	report["checks_total"] = report.checks.size()
	report["fallas"] = fail_count
	var file := FileAccess.open(out_dir.path_join("metrics_visual.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "	"))
	file.close()
	print("VIS_HUMAHUACA " + JSON.stringify({"flow": flow, "fallas": fail_count, "out": out_dir}))
	quit(0 if fail_count == 0 else 1)


## Saturación y brillo medios (HSV de los píxeles de pantalla) y el porcentaje de «naranja saturado» (S ≥ 0,55, V ≥ 0,30 y matiz entre 15° y 50°): lo que el
## hallazgo I-R1.0-3 llama «lava todo de naranja». Se mide sobre una copia reducida (288 px de ancho) para que cueste ≈ 0,1 s.
func _image_stats(img: Image) -> Dictionary:
	var small: Image = img.duplicate()
	var w := 288
	var h := maxi(int(round(float(w) * float(img.get_height()) / float(maxi(img.get_width(), 1)))), 1)
	small.resize(w, h, Image.INTERPOLATE_BILINEAR)
	var total := float(w * h)
	var sum_s := 0.0
	var sum_v := 0.0
	var orange := 0
	var saturated := 0
	for y in range(h):
		for x in range(w):
			var c := small.get_pixel(x, y)
			sum_s += c.s
			sum_v += c.v
			if c.s >= 0.55:
				saturated += 1
				if c.v >= 0.30 and c.h * 360.0 >= 15.0 and c.h * 360.0 <= 50.0:
					orange += 1
	return {"sat_media": snappedf(sum_s / total, 0.001), "val_media": snappedf(sum_v / total, 0.001), "naranja_saturado_pct": snappedf(100.0 * float(orange) / total, 0.1),
		"sat_alta_pct": snappedf(100.0 * float(saturated) / total, 0.1)}


## Los umbrales del hallazgo I-R1.0-3 sobre las medidas de un cuadro de juego: el alba (luz entre la noche y el día) no se pasa de «naranja saturado» y los trazos
## de visibilidad no se cruzan. La ficha de un cuadro de la escena real mide lo que pide V03 (≥ 48 px reales).
func _judge_stats(key: String, stats: Dictionary) -> void:
	var tod := float(stats.get("tod", -1.0))
	if tod >= 0.2 and tod <= 0.9:
		_check(float(stats.get("naranja_saturado_pct", 100.0)) <= 5.0, "%s: el alba no lava el cuadro de naranja saturado (%.1f %% de los píxeles; tope 5 %%)" % [key, float(stats.get("naranja_saturado_pct", 100.0))])
		_check(float(stats.get("sat_media", 1.0)) <= 0.42, "%s: la saturación media del cuadro es de %.3f (tope 0,42)" % [key, float(stats.get("sat_media", 1.0))])
	if stats.has("anillos_dibujados_dentro_de_otros_m"):
		_check(float(stats.anillos_dibujados_dentro_de_otros_m) <= 5.0, "%s: los trazos de visibilidad no se cruzan (%.1f m de trazo dentro de otro círculo; tope 5 m)" % [key, float(stats.anillos_dibujados_dentro_de_otros_m)])
	var tokens: Variant = stats.get("fichas", null)
	if tokens is Dictionary:
		for id in tokens:
			if bool(tokens[id].en_pantalla):
				_check(float(tokens[id].alto_px) >= 48.0, "%s: la ficha de %s mide %.1f px reales de alto en la escena real (V03 pide ≥ 48)" % [key, id, float(tokens[id].alto_px)])


## La opacidad con que la vista dibuja los anillos de visibilidad (la vista que no sabe de eso los dibujaba siempre a 0,5).
func _pool_alpha(pools: Array) -> float:
	var seen := 0.0
	for p in pools:
		seen = maxf(seen, float(p.r))
	return snappedf(float(view.call("pool_alpha", seen)), 0.001) if view != null and view.has_method("pool_alpha") else 0.5


## Pares de círculos de visibilidad que se cortan (cada par deja dos cruces de líneas si se dibujan los círculos enteros).
func _crossing_pairs(pools: Array) -> int:
	var pairs := 0
	for i in range(pools.size()):
		for j in range(i + 1, pools.size()):
			var a := Vector2(float(pools[i].x), float(pools[i].z))
			var b := Vector2(float(pools[j].x), float(pools[j].z))
			var d := a.distance_to(b)
			var ri := float(pools[i].r)
			var rj := float(pools[j].r)
			if d < ri + rj and d > absf(ri - rj):
				pairs += 1
	return pairs


## Los trazos de visibilidad que la vista dibuja: los que arma la vista si sabe (`_pool_arcs`) o, si no, los círculos enteros.
func _drawn_pool_arcs(pools: Array) -> Array:
	if view != null and view.has_method("_pool_arcs"):
		var arcs: Array = []
		for arc in view.call("_pool_arcs", pools):
			arcs.append(arc.pts if arc is Dictionary else arc)
		return arcs
	var full: Array = []
	for p in pools:
		var c := Vector2(float(p.x), float(p.z))
		var ring := PackedVector2Array()
		for k in range(73):
			var a := TAU * float(k) / 72.0
			ring.append(c + Vector2(cos(a), sin(a)) * float(p.r))
		full.append(ring)
	return full


## Metros de trazo que caen más de 0,5 m dentro de algún círculo de visibilidad (los puntos de su propio círculo están justo sobre el borde).
func _arc_length_inside_others(arcs: Array, pools: Array) -> float:
	var total := 0.0
	for arc in arcs:
		var pts: PackedVector2Array = arc
		for k in range(pts.size() - 1):
			var mid := (pts[k] + pts[k + 1]) * 0.5
			for p in pools:
				if mid.distance_to(Vector2(float(p.x), float(p.z))) < float(p.r) - 0.5:
					total += pts[k].distance_to(pts[k + 1])
					break
	return total


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
		fits["%dx%d" % [s.x, s.y]] = {"fits": f.fits, "distance": snappedf(float(f.distance), 0.1), "target": [snappedf(f.target.x, 0.1), snappedf(f.target.z, 0.1)],
			"puntos": {"rumbo": _frame_points(c, f, s, false), "controlador": _frame_points(c, f, s, true)}}
		_check(bool(f.fits), "initial_frame().fits a %dx%d (incluye los 3 objetivos y la zona de partida)" % [s.x, s.y])
		sub.queue_free()
	report["initial_frame"] = fits
	await _frames(1)


## Dónde caen en pantalla los tres objetivos, el centro de la zona de partida y las cinco partidas con el cuadro inicial, para las dos formas de leer `yaw_deg`:
## «rumbo» (hacia dónde mira la cámara: la de initial_frame, canonical_view y el diseño 11.3) y «controlador» (a qué ángulo del objetivo está la cámara: la que arma hoy
## humahuaca_ui._apply_camera, que es el espejo de la anterior). Devuelve {id: {x, y, margen_pct, atras}} y un resumen; `margen_pct` es la distancia al borde más cercano
## en % del lado correspondiente (negativo = fuera del cuadro).
func _frame_points(c: Camera3D, f: Dictionary, size: Vector2i, controller_way: bool) -> Dictionary:
	var saved := cam_ui
	cam_ui = controller_way
	c.transform = _cam_xf(f.target, f.distance, f.pitch_deg, f.yaw_deg)
	cam_ui = saved
	var out := {}
	var worst := 1000.0
	var all_in := true
	for id in ["bateria", "cuartel", "posta", "zona_partida", "spawn_rodriguez", "spawn_portal", "spawn_arias", "spawn_reconocedores", "spawn_arreo"]:
		var lm: Dictionary = view.get_landmark_info(id)
		if lm.is_empty():
			continue
		var at := Vector3(float(lm.x), float(lm.y), float(lm.z))
		var p := c.unproject_position(at)
		var margin := minf(minf(p.x, float(size.x) - p.x) / float(size.x), minf(p.y, float(size.y) - p.y) / float(size.y)) * 100.0
		var behind := c.is_position_behind(at)
		out[id] = {"x": snappedf(p.x, 1.0), "y": snappedf(p.y, 1.0), "margen_pct": snappedf(margin, 0.1), "atras": behind}
		worst = minf(worst, margin)
		all_in = all_in and margin >= 0.0 and not behind
	out["_resumen"] = {"todos_dentro": all_in, "peor_margen_pct": snappedf(worst, 0.1)}
	return out


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
		var inside := Rect2(Vector2.ZERO, root.get_visible_rect().size).has_point(base_px)  # con los datos reales alguna partida cae fuera del cuadro inicial
		token_px[id] = {"en_pantalla": inside, "alto": snappedf(absf(base_px.y - top_px.y) * screen_scale, 0.1), "escala": snappedf(node.scale.y, 0.01), "cima_m": snappedf(top - node.global_position.y, 0.01),
			"distancia_m": snappedf(cam.global_position.distance_to(node.global_position), 0.1)}
		_check(not inside or float(token_px[id].alto) >= (48.0 if str(report.get("view_script", "")).ends_with("humahuaca_view.gd") else 40.0), "la ficha de %s mide %.1f px reales de alto con el cuadro inicial (V03 pide ≥ 48; el stub llega a ≈ 42 en el borde inferior)" % [id, float(token_px[id].alto)])
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
# Render héroe (cierre de R1): el templo de cerca, los arquetipos de figura en fila y su lectura en escala de grises a 48 px

func _studio(parent: Node3D, sun_el: float, sun_az: float, warm: bool) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.66, 0.68)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.74, 0.8, 0.9)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	var sun := DirectionalLight3D.new()
	var el := deg_to_rad(sun_el)
	var az := deg_to_rad(sun_az)
	sun.transform = Transform3D(Basis.looking_at(-Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el)), Vector3.UP), Vector3.ZERO)
	sun.light_color = Color(1.0, 0.94, 0.84) if warm else Color(1.0, 1.0, 1.0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	parent.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400.0, 400.0)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("B99A72")
	gm.roughness = 0.95
	ground.material_override = gm
	parent.add_child(ground)


## La variante de ropa por defecto de un arquetipo (units.archetypes o units.realista_1817 del JSON).
func _arch_variant(gen, visual: Dictionary, id: String) -> Dictionary:
	var units: Dictionary = visual.get("units", {})
	if id == "realista_1817":
		return gen.archetype_variant(units.get("realista_1817", {}))
	for a in units.get("archetypes", []):
		if str(a.get("id", "")) == id:
			return gen.archetype_variant(a)
	return {}


func _hero_cam(target: Vector3, distance: float, pitch_deg: float, yaw_deg: float, fov: float = 34.0) -> Camera3D:
	var c := Camera3D.new()
	c.fov = fov
	c.far = 3000.0
	root.add_child(c)
	c.current = true
	var yaw := deg_to_rad(yaw_deg)
	var pitch := deg_to_rad(pitch_deg)
	var look := Vector3(sin(yaw) * cos(pitch), -sin(pitch), -cos(yaw) * cos(pitch))
	c.transform = Transform3D(Basis.looking_at(look, Vector3.UP), target - look * distance)
	return c


func _figure_node(parent: Node3D, gfx, parts: Dictionary, pos: Vector3, yaw_deg: float = 0.0) -> Node3D:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation_degrees.y = yaw_deg
	parent.add_child(holder)
	for key in parts:
		gfx.part_node(holder, str(key), parts[key], gfx.vertex_mat(), true)
	return holder


func _run_hero() -> void:
	var visual: Dictionary = V.load_json(V.VISUAL_PATH)
	var gfx = Gfx.new()
	gfx.setup(visual, quality, null, Vector2(900.0, 650.0))
	var gen = Gen.new(gfx.palette)
	var spec: Dictionary = (visual.get("props", {}) as Dictionary).get("por_id", {}).get("templo", {})
	var hero_report := {}
	var index := index_base
	# 1) el templo: nave de adobe encalado a dos aguas, sin torres ni fachada de 1880
	var studio := Node3D.new()
	root.add_child(studio)
	_studio(studio, 24.0, 118.0, true)
	var mb = gen.builder()
	gen.add_temple(mb, {"w": 22.0, "d": 8.0, "ridge_m": 7.0, "eave_ratio": float(spec.get("eave_ratio", 0.78)), "color": str(spec.get("color", "cal_envejecida")),
		"roof_color": str(spec.get("roof_color", "paja")), "trim_color": str(spec.get("trim_color", "madera_oscura"))})
	var temple_mesh: ArrayMesh = mb.build()
	var temple := MeshInstance3D.new()
	temple.mesh = temple_mesh
	temple.material_override = gfx.props_mat
	studio.add_child(temple)
	var cam1 := _hero_cam(Vector3(2.0, 3.0, 3.0), 36.0, 14.0, 332.0)
	await _frames(6)
	await RenderingServer.frame_post_draw
	index += 1
	_save_shot(index, "heroe_templo", root.get_texture().get_image())
	var top_m: float = gen.mesh_top(temple_mesh)
	hero_report["templo"] = {"altura_max_m": snappedf(top_m, 0.01), "triangulos": (temple_mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3, "caballete_m": 7.0, "sin_torres": top_m <= 7.01}
	_check(top_m <= 7.01, "héroe: ningún vértice del templo pasa del caballete de 7 m (%.2f m)" % top_m)
	cam1.queue_free()
	studio.queue_free()
	await _frames(2)
	# 2) los arquetipos y los animales, en fila y de cerca
	studio = Node3D.new()
	root.add_child(studio)
	_studio(studio, 26.0, 130.0, true)
	var variants: Array = (visual.get("units", {}) as Dictionary).get("variants", [])
	var arch_ids := ["poncho_sombrero", "camisa_gorra", "artillero", "realista_1817"]
	var x := -7.5
	for k in range(arch_ids.size()):
		_figure_node(studio, gfx, gen.figure(arch_ids[k], _arch_variant(gen, visual, arch_ids[k]), "de_pie", 0.022), Vector3(x, 0.0, 0.0), 188.0)
		x += 2.2
	x += 0.8
	_figure_node(studio, gfx, gen.rider({"camisa": "lino_crudo", "abrigo": "lana_parda", "sombrero": "madera_oscura", "acento": ""}, 0.04), Vector3(x + 1.0, 0.0, 0.0), 150.0)
	_figure_node(studio, gfx, gen.mule(0.04), Vector3(x + 4.6, 0.0, 0.2), 125.0)
	var cam2 := _hero_cam(Vector3(-0.2, 1.2, 0.0), 23.0, 8.0, 0.0, 30.0)
	await _frames(6)
	await RenderingServer.frame_post_draw
	index += 1
	_save_shot(index, "heroe_arquetipos", root.get_texture().get_image())
	cam2.queue_free()
	studio.queue_free()
	await _frames(2)
	# 3) los mismos, en escala de grises a 48 px de alto: silueta rellena y diferencia de luminosidad L* entre pares
	var sheet: Dictionary = await _grayscale_sheet(gfx, gen, variants, visual)
	index += 1
	_save_shot(index, "heroe_grises_48px", sheet.image)
	hero_report["grises"] = sheet.metrics
	for pair in sheet.metrics.pares_arquetipos:
		_check(float(pair.delta_L) >= 15.0, "héroe: %s y %s se distinguen en grises a 48 px (ΔL* %.1f; piso 15)" % [pair.a, pair.b, float(pair.delta_L)])
	report["heroe"] = hero_report
	report["checks_total"] = report.checks.size()
	report["fallas"] = fail_count
	var file := FileAccess.open(out_dir.path_join("metrics_visual.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("VIS_HUMAHUACA " + JSON.stringify({"hero": true, "fallas": fail_count, "out": out_dir}))
	quit(0 if fail_count == 0 else 1)


## L* de CIELAB (0 a 100) de un color sRGB.
func _lstar(c: Color) -> float:
	var l := c.srgb_to_linear()
	var y := 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b
	var f := pow(y, 1.0 / 3.0) if y > 0.008856 else 7.787 * y + 16.0 / 116.0
	return 116.0 * f - 16.0


## Cada figura (los 4 arquetipos y las 5 siluetas de las fichas) se dibuja sin luz sobre un fondo transparente, se baja a 48 px de alto y se mide: la parte del cuadro que
## ocupa la silueta, su L* medio (el color de la ropa en grises) y la diferencia de L* entre cada par de arquetipos. Devuelve {image, metrics}.
func _grayscale_sheet(gfx, gen, variants: Array, _visual: Dictionary) -> Dictionary:
	var names: Array = ["poncho_sombrero", "camisa_gorra", "artillero", "realista_1817", "ficha_jinete", "ficha_infante_fusil", "ficha_infante_banderin", "ficha_agachados", "ficha_mula_cargada"]
	var cells: Array = []
	gfx.set_albedo(true)  # sin luz: el color de la paleta tal cual (es lo que se compara)
	for k in range(names.size()):
		var nm: String = names[k]
		var parts: Dictionary
		if nm.begins_with("ficha_"):
			match nm.trim_prefix("ficha_"):
				"jinete":
					parts = gen.rider({"camisa": "lino_crudo", "abrigo": "lana_parda", "sombrero": "madera_oscura", "acento": ""}, 0.04)
				"mula_cargada":
					parts = gen.mule(0.04)
				"agachados":
					parts = gen.figure("poncho_sombrero", gen.variant_for(1, variants), "agachado", 0.04)
				"infante_banderin":
					parts = gen.figure("camisa_gorra", {"camisa": "lana_natural", "abrigo": "lana_parda", "sombrero": "azul_elegido", "acento": ""}, "de_pie", 0.04)
				_:
					parts = gen.figure("camisa_gorra", gen.variant_for(0, variants), "de_pie", 0.04)
		else:
			parts = gen.figure(nm, _arch_variant(gen, _visual, nm), "de_pie", 0.022)
		var sv := SubViewport.new()
		sv.size = Vector2i(384, 384)
		sv.transparent_bg = true
		sv.own_world_3d = true
		sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(sv)
		var env := Environment.new()
		env.background_mode = Environment.BG_CLEAR_COLOR
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color.WHITE
		env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		var we := WorldEnvironment.new()
		we.environment = env
		sv.add_child(we)
		var holder := Node3D.new()
		holder.rotation_degrees.y = 35.0  # de tres cuartos: ni de frente ni de espaldas
		sv.add_child(holder)
		var lo := Vector3(1.0e9, 1.0e9, 1.0e9)
		var hi := Vector3(-1.0e9, -1.0e9, -1.0e9)
		for key in parts:
			var mi: MeshInstance3D = gfx.part_node(holder, str(key), parts[key], gfx.vertex_mat(), false)
			var box: AABB = mi.mesh.get_aabb()
			lo = Vector3(minf(lo.x, box.position.x), minf(lo.y, box.position.y), minf(lo.z, box.position.z))
			hi = Vector3(maxf(hi.x, box.end.x), maxf(hi.y, box.end.y), maxf(hi.z, box.end.z))
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = (hi.y - lo.y) * 1.12
		cam.near = 0.05
		cam.far = 100.0
		sv.add_child(cam)
		cam.transform = Transform3D(Basis.IDENTITY, Vector3((lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5, 30.0))
		cam.current = true
		cells.append({"name": nm, "sv": sv})
	await _frames(4)
	await RenderingServer.frame_post_draw
	var metrics := {"alto_px": 48, "figuras": {}, "pares_arquetipos": []}
	var sheet := Image.create(48 * 9 + 20 * 10, 48 + 40, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.466, 0.466, 0.466))  # un gris medio (L* ≈ 50)
	var cell_l: Dictionary = {}
	for k in range(cells.size()):
		var cell: Dictionary = cells[k]
		var img: Image = (cell.sv as SubViewport).get_texture().get_image()
		var fig_px := int(round(384.0 / 1.12))  # el alto de la figura en la imagen de 384 px (la cámara deja 12 % de aire)
		var scale_f := 48.0 / float(fig_px)
		var side := maxi(int(round(384.0 * scale_f)), 1)
		img.resize(side, side, Image.INTERPOLATE_BILINEAR)
		var sum_l := 0.0
		var covered := 0
		for y in range(img.get_height()):
			for xx in range(img.get_width()):
				var px := img.get_pixel(xx, y)
				if px.a > 0.5:
					covered += 1
					sum_l += _lstar(Color(px.r, px.g, px.b))
		var mean_l := sum_l / float(maxi(covered, 1))
		cell_l[cell.name] = mean_l
		var bounds := _alpha_bounds(img)
		metrics.figuras[cell.name] = {"L_media": snappedf(mean_l, 0.1), "alto_px": bounds.size.y, "ancho_px": bounds.size.x,
			"relleno_pct": snappedf(100.0 * float(covered) / float(maxi(bounds.size.x * bounds.size.y, 1)), 0.1)}
		sheet.blend_rect(_to_gray(img), Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i(10 + k * 68, 6))
		(cell.sv as SubViewport).queue_free()
	var pairs: Array = []
	for i in range(4):
		for j in range(i + 1, 4):
			pairs.append({"a": names[i], "b": names[j], "delta_L": snappedf(absf(float(cell_l[names[i]]) - float(cell_l[names[j]])), 0.1)})
	metrics.pares_arquetipos = pairs
	gfx.set_albedo(false)
	return {"image": sheet, "metrics": metrics}


func _alpha_bounds(img: Image) -> Rect2i:
	var lo := Vector2i(img.get_width(), img.get_height())
	var hi := Vector2i(-1, -1)
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			if img.get_pixel(x, y).a > 0.5:
				lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
				hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
	return Rect2i(lo, hi - lo + Vector2i.ONE) if hi.x >= 0 else Rect2i()


## La silueta en grises: el L* de cada píxel mostrado como gris perceptual (lo que se vería en escala de grises).
func _to_gray(img: Image) -> Image:
	var out := img.duplicate() as Image
	for y in range(out.get_height()):
		for x in range(out.get_width()):
			var c := out.get_pixel(x, y)
			if c.a > 0.0:
				var g := _lstar(Color(c.r, c.g, c.b)) / 100.0
				var v := Color(g, g, g, c.a).linear_to_srgb()
				out.set_pixel(x, y, Color(v.r, v.g, v.b, c.a))
	return out


# ---------------------------------------------------------------------------------------------------------------------
# Reglas y terreno: los stubs de las otras pistas si existen; si no, unas copias mínimas

func _make_rules(spec: String = "aproximacion") -> RefCounted:
	var parts := spec.split("@")
	var phase := parts[0]
	if not use_fakes and ResourceLoader.exists(STUB_RULES):
		var script := load(STUB_RULES) as GDScript
		if script != null and script.can_instantiate():
			var r: RefCounted = script.new()
			var opts := {"skip_intro": true, "phase": phase}
			if relief_dir != "":
				var relief := ReliefTerrain.new()
				if relief.load_relief(relief_dir):
					opts["terrain"] = relief
					report["relieve"] = "DEM de Copernicus GLO-30 (explorador) sobre el terreno de respaldo, solo para esta captura"
			r.new_game(1817, 1, opts)
			if parts.size() > 1:
				_set_clock(r, float(parts[1]))
			report["rules_source"] = STUB_RULES
			if dress:  # el stub de reglas no trae defensores, torre ni fogatas (los da la clase real): se los suma solo para la captura
				return DressedRules.new(r, phase)
			return r
	report["rules_source"] = "copias mínimas de tools/vis_humahuaca.gd"
	var fake := FakeRules.new()
	if phase == "extraccion" or phase == "ataque":
		fake.set_scene("alba")
	return fake



## Terreno de respaldo con RELIEVE DE VERDAD solo para las capturas (hasta que llegue la clase real de relieve_mapa): la ventana de 10 m y el contexto de 30 m del DEM de
## Copernicus que preparó el explorador (humahuaca_dem.json y humahuaca_fondo.json, en m s. n. m., FUERA del repositorio), el domo de 12 m de la batería con su plataforma,
## las dos quebraditas y el cauce tallado. Hereda del stub (hitos, rasgos, superficies y río) y solo cambia las alturas. No entra al juego.
class ReliefTerrain extends "res://scripts/humahuaca/stubs/stub_terrain.gd":
	const WIN_NX := 91
	const WIN_NZ := 66
	const CTX_NX_ := 121
	const CTX_NZ_ := 91
	var win_dem := PackedFloat32Array()
	var ctx_dem := PackedFloat32Array()
	var _rf: Dictionary = {}
	var _cf2: Dictionary = {}
	var _river_line := PackedVector2Array()

	func load_relief(dir: String) -> bool:
		var a: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("humahuaca_dem.json")))
		var b: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("humahuaca_fondo.json")))
		if not (a is Dictionary) or not (b is Dictionary):
			return false
		var za: Array = a.z
		var zb: Array = b.z
		win_dem.resize(za.size())
		ctx_dem.resize(zb.size())
		for k in range(za.size()):
			win_dem[k] = float(za[k]) - 2940.0
		for k in range(zb.size()):
			ctx_dem[k] = float(zb[k]) - 2940.0
		# el DEM es de SUPERFICIE (techos y árboles de hoy): se lo suaviza con un promedio de 7 × 7 celdas (≈ 30 m), como pide el contrato 2.1
		var smooth := PackedFloat32Array()
		smooth.resize(win_dem.size())
		for j in range(WIN_NZ):
			for i in range(WIN_NX):
				var sum := 0.0
				var n := 0
				for dj in range(-3, 4):
					for di in range(-3, 4):
						var ii := clampi(i + di, 0, WIN_NX - 1)
						var jj := clampi(j + dj, 0, WIN_NZ - 1)
						sum += win_dem[jj * WIN_NX + ii]
						n += 1
				smooth[j * WIN_NX + i] = sum / float(n)
		win_dem = smooth
		var river_dict: Dictionary = river()
		for p in river_dict.get("pts", []):
			_river_line.append(Vector2(float(p.x), float(p.z)))
		return true

	func _bilinear(arr: PackedFloat32Array, nx_: int, nz_: int, ox: float, oz: float, cell: float, x: float, z: float) -> float:
		var fx := clampf((x - ox) / cell, 0.0, float(nx_ - 1) - 0.0001)
		var fz := clampf((z - oz) / cell, 0.0, float(nz_ - 1) - 0.0001)
		var i := int(fx)
		var j := int(fz)
		var tx := fx - float(i)
		var tz := fz - float(j)
		var a := lerpf(arr[j * nx_ + i], arr[j * nx_ + i + 1], tx)
		var b := lerpf(arr[(j + 1) * nx_ + i], arr[(j + 1) * nx_ + i + 1], tx)
		return lerpf(a, b, tz)

	func _design(x: float, z: float, base: float) -> float:
		var h := base
		var d := Vector2(x - 305.0, z - 345.0).length()
		h += 13.0 * exp(-pow(d / 44.0, 2.0))  # el domo de la batería (12 m de prominencia sobre su anillo; diseño)
		var box := Vector2(maxf(absf(x - 318.0) - 14.0, 0.0), maxf(absf(z - 350.0) - 9.0, 0.0)).length()  # plataforma de 28 × 18 m, plana
		var plateau := 13.0 * exp(-pow(Vector2(318.0 - 305.0, 350.0 - 345.0).length() / 44.0, 2.0)) + _bilinear(win_dem, WIN_NX, WIN_NZ, 0.0, 0.0, 10.0, 318.0, 350.0)
		h = lerpf(plateau, h, smoothstep(0.0, 10.0, box))
		h -= 2.5 * exp(-pow((x - 282.0) / 22.0, 2.0) - pow((z - 298.0) / 6.0, 2.0)) + 2.5 * exp(-pow((x - 288.0) / 22.0, 2.0) - pow((z - 402.0) / 6.0, 2.0))
		var best := 1.0e9
		for k in range(_river_line.size() - 1):
			best = minf(best, Geometry2D.get_closest_point_to_segment(Vector2(x, z), _river_line[k], _river_line[k + 1]).distance_to(Vector2(x, z)))
		h -= 3.2 * exp(-pow(best / 17.0, 2.0))
		return h

	func height_at(x: float, z: float) -> float:
		var ctx_h := _bilinear(ctx_dem, CTX_NX_, CTX_NZ_, -1350.0, -1025.0, 30.0, x, z)
		var out := maxf(maxf(-x, x - 900.0), maxf(-z, z - 650.0))
		var inside := 1.0 - smoothstep(0.0, 60.0, out)
		if inside <= 0.0:
			return ctx_h
		var win_h := _bilinear(win_dem, WIN_NX, WIN_NZ, 0.0, 0.0, 10.0, clampf(x, 0.0, 900.0), clampf(z, 0.0, 650.0))
		return lerpf(ctx_h, _design(x, z, win_h), inside)

	func height_dem_only(x: float, z: float) -> float:
		return _bilinear(win_dem, WIN_NX, WIN_NZ, 0.0, 0.0, 10.0, clampf(x, 0.0, 900.0), clampf(z, 0.0, 650.0))

	func heightfield() -> Dictionary:
		if _rf.is_empty():
			var h := PackedFloat32Array()
			h.resize(nx * nz)
			for j in range(nz):
				for i in range(nx):
					h[j * nx + i] = height_at(float(i) * cell_m, float(j) * cell_m)
			_rf = {"nx": nx, "nz": nz, "cell": cell_m, "origin_x": 0.0, "origin_z": 0.0, "h": h}
		return _rf

	func context_field() -> Dictionary:
		if _cf2.is_empty():
			_cf2 = {"nx": CTX_NX_, "nz": CTX_NZ_, "cell": 30.0, "origin_x": -1350.0, "origin_z": -1025.0, "h": ctx_dem}
		return _cf2



## Las reglas de respaldo «vestidas» solo para las capturas: el stub no trae defensores, torre, fogatas ni líneas de fuego (los entrega la clase real de reglas_historia),
## así que se los suma a `render_state()` con las formas del contrato 3.2.3: centinelas y guardias en los tres objetivos, artilleros en la batería, la torre con su volea
## y las fogatas de la guardia al alba. No cambia nada de las reglas y no entra al juego.
class DressedRules extends RefCounted:
	var base: RefCounted
	var phase := "aproximacion"

	func _init(b: RefCounted, phase_id: String = "aproximacion") -> void:
		base = b
		phase = phase_id

	func terrain() -> RefCounted:
		return base.terrain()

	func map_size() -> Vector2:
		return base.map_size()

	func environment() -> Dictionary:
		return base.environment()

	func render_state() -> Dictionary:
		var st: Dictionary = base.render_state().duplicate(true)
		var alba: bool = float((st.get("env", {}) as Dictionary).get("time_of_day", 0.0)) >= 0.3
		var enemies: Array = []
		for e in [["c_bat", "centinela", 311.0, 344.0], ["a_bat1", "artillero", 309.5, 345.8], ["a_bat2", "artillero", 309.5, 350.0], ["a_bat3", "artillero", 309.5, 354.2],
				["c_cuartel", "centinela", 426.0, 330.0], ["g_cuartel1", "guardia", 405.0, 344.0], ["g_cuartel2", "guardia", 414.0, 345.0], ["g_cuartel3", "fusilero", 424.0, 345.0],
				["c_posta", "centinela", 584.0, 311.0], ["g_posta1", "guardia", 598.0, 300.0], ["g_posta2", "guardia", 580.0, 296.0]]:
			enemies.append({"id": e[0], "kind": e[1], "x": e[2], "z": e[3], "alert": 0.1 if not alba else 0.7, "firing": alba and e[0] == "a_bat2"})
		st["enemies"] = enemies
		if phase != "aproximacion" or alba:
			st["tower"] = {"x": 426.0, "z": 326.0, "next_volley_in_s": 3.0, "period_s": 7.5, "dead_angle_m": 12.0, "firing": alba}
		if alba:
			var lights: Array = (st.get("lights", []) as Array).duplicate()
			lights.append({"id": "fogata_1", "kind": "fogata", "x": 330.0, "z": 330.0, "r_m": 16.0})
			lights.append({"id": "fogata_2", "kind": "fogata", "x": 560.0, "z": 318.0, "r_m": 16.0})
			st["lights"] = lights
			st["fire_lines"] = [{"from": {"x": 426.0, "z": 326.0}, "to": {"x": 350.0, "z": 381.0}, "kind": "torre"}]
		st["version"] = int(st.get("version", 0)) + 1000
		return st


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
