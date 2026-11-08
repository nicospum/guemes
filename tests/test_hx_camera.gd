extends SceneTree
## Cámara del nivel «humahuaca», medida SIN ventana (dueña: ui_feel; pedido del usuario del 2-11-2026: «la cámara está demasiado lejos, se ve todo muy chico»).
##   godot --headless --path . --audio-driver Dummy --script tests/test_hx_camera.gd [-- --ronda=r2a --informe=<ruta.json>]
## Con el perfil aislado (XDG_DATA_HOME o APPDATA con «ap_iso»). Arranca main.tscn con el controlador real, fija el tamaño de la ventana a 1024 × 640, 1280 × 720,
## 1920 × 1080 y 2560 × 1440 y mide con Camera3D.unproject_position, que no necesita dibujar: alcanza con que la ventana tenga tamaño (el cuadro lógico de 1440 × 900
## se estira a la ventana como en el juego, y la escala real/lógico sale de get_final_transform). Todas las cifras en píxeles son píxeles REALES de la ventana.
## Qué mide, con el cuadro inicial tal como lo deja reset_camera() a cada tamaño:
##   · dónde caen los tres objetivos, la zona de partida, las cinco partidas, el templo y la plaza (margen al borde, en % del lado menor; `on_screen` con la regla de
##     _initial_frame_report, V02) y si `initial_frame().fits` es verdadero;
##   · el alto de cada ficha de pie (de la base a la cima de sus piezas, sin anillos: la medida de V03 y de notes.token_px) y el ancho y alto de los edificios (probes);
##   · metros por píxel en la plaza y qué fracción del cuadro ocupa el pueblo (casco de las manzanas, el templo, la plaza y los tres objetivos) y los tres objetivos;
##   · el zoom por rueda: límites, cuántos pasos hay hasta el mínimo y que el punto del suelo bajo el cursor no se mueve;
##   · el centrado con la tecla de una agrupación (4 y 5: la ficha misma) y si la cámara la sigue cuando marcha.
## Imprime una línea JSON (hx_fixtures) con `camara` por tamaño; con --informe=<ruta> escribe lo mismo en ese archivo para docs/humahuaca/CAMARA.md.

const Fx = preload("res://tests/hx_fixtures.gd")
const V = preload("res://scripts/humahuaca/humahuaca_vocab.gd")

const SIZES := [Vector2i(1024, 640), Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const V02_IDS := ["bateria", "cuartel", "posta", "zona_partida"]
const SPAWN_IDS := ["spawn_rodriguez", "spawn_portal", "spawn_arias", "spawn_reconocedores", "spawn_arreo"]
const TOWN_IDS := ["templo", "plaza", "bateria", "cuartel", "posta", "corral_posta"]
const BUILDING_IDS := ["bateria", "cuartel", "posta", "torre_casa_cura", "torre_templo", "polvorin", "parque", "corral_posta"]
const V02_MARGIN_PCT := 10.0  # QA_NIVEL2 v1.5, V02: los tres objetivos (y la zona de partida, si el preset la exige) a ≥ 10 % del borde; la herramienta de QA marca on_screen con 5 %
const TOKEN_MIN_PX := 48.0  # V03
const TOKEN_GOAL_PX := 64.0  # el pedido del usuario; las fichas son de tamaño fijo en píxeles (humahuaca_visual.json: tokens.*.min_px), así que se informa, no se exige acá
const ZOOM_NOTCH := 0.86  # ui.camera.zoom_step

var suite := Fx.new()
var game: Node
var hx: Node
var report_path := ""
var by_size: Dictionary = {}


func _initialize() -> void:
	suite.begin("hx_camera", OS.get_cmdline_user_args())
	if not Fx.profile_isolated():
		suite.check(false, "perfil NO aislado (%s): exportá XDG_DATA_HOME o APPDATA con «ap_iso» antes de correr; esta prueba borra archivos de perfil" % OS.get_user_data_dir())
		print(JSON.stringify(suite.report()))
		quit(2)
		return
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--informe="):
			report_path = str(arg).trim_prefix("--informe=")
	Fx.clean_profile()
	OS.set_low_processor_usage_mode_sleep_usec(300)
	call_deferred("_run")


# ---------------------------------------------------------------------------------------------------------------------
# Ayudas

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _set_window(size: Vector2i) -> void:
	root.size = size
	await _frames(6)


func _scale() -> Vector2:
	return root.get_final_transform().get_scale()


func _cam() -> Camera3D:
	return game.camera


func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, float(hx.ground_height(x, z)), z)


## Un punto del mundo en píxeles reales de la ventana, o null si queda detrás de la cámara.
func _real(p: Vector3) -> Variant:
	var c := _cam()
	if c.is_position_behind(p):
		return null
	return c.unproject_position(p) * _scale()


## Margen al borde en % del lado correspondiente (el menor de los cuatro); negativo si queda fuera; −1000 si está detrás de la cámara.
func _margin_pct(p: Vector3, size: Vector2i) -> float:
	var s: Variant = _real(p)
	if s == null:
		return -1000.0
	var v := s as Vector2
	return 100.0 * minf(minf(v.x, float(size.x) - v.x) / float(size.x), minf(v.y, float(size.y) - v.y) / float(size.y))


func _unit_pos(id: String) -> Vector2:
	var u: Dictionary = hx.rules.get_unit(id)
	return Vector2(float(u.get("x", 0.0)), float(u.get("z", 0.0)))


## El alto de pie de cada ficha visible (base a cima de sus piezas, sin anillos) en píxeles reales: la medida de V03 (tools/ui_qa_humahuaca.gd, _token_px).
func _token_px() -> Dictionary:
	var out := {}
	if not is_instance_valid(hx.view) or not "unit_nodes" in hx.view:
		return out
	hx.view.call("_update_scales")  # la escala que corresponde a la cámara de este instante (en el juego la pone el _process de la vista)
	var c := _cam()
	var k := _scale().y
	for id in V.GROUPS:
		if not hx.view.unit_nodes.has(id):
			continue
		var node: Node3D = hx.view.unit_nodes[id]
		if c.is_position_behind(node.global_position):
			continue
		var top := node.global_position.y
		for mi in node.find_children("*", "MeshInstance3D", true, false):
			if str(mi.name) in ["anillo", "borde", "seleccion"]:
				continue
			var box: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			top = maxf(top, box.end.y)
		var base_px := c.unproject_position(node.global_position)
		var top_px := c.unproject_position(Vector3(node.global_position.x, top, node.global_position.z))
		out[id] = snappedf(absf(base_px.y - top_px.y) * k, 0.1)
	return out


## Ancho y alto proyectados (píxeles reales) de un nodo 3D por las 8 esquinas de la caja de sus mallas.
func _node_px(node: Node3D) -> Array:
	var box := AABB()
	var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var b := m.global_transform * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first:
		return [0.0, 0.0]
	var lo := Vector2(1.0e9, 1.0e9)
	var hi := Vector2(-1.0e9, -1.0e9)
	for i in range(8):
		var s: Variant = _real(box.get_endpoint(i))
		if s == null:
			return [0.0, 0.0]
		lo = Vector2(minf(lo.x, (s as Vector2).x), minf(lo.y, (s as Vector2).y))
		hi = Vector2(maxf(hi.x, (s as Vector2).x), maxf(hi.y, (s as Vector2).y))
	return [snappedf(hi.x - lo.x, 0.1), snappedf(hi.y - lo.y, 0.1)]


## Los edificios que miden las sondas de la vista (objetivos, edificios y la torre del mundo), en píxeles reales: [ancho, alto].
func _building_px() -> Dictionary:
	var out := {}
	var k := _scale()
	for p in hx.view.probes(_cam()):
		var d := p as Dictionary
		if str(d.get("kind", "")) in ["objetivo", "edificio"] and BUILDING_IDS.has(str(d.get("id", ""))):
			var r: Array = d.rect
			out[str(d.id)] = [snappedf(float(r[2]) * k.x, 0.1), snappedf(float(r[3]) * k.y, 0.1)]
	var temple: Variant = hx.view.buildings.lm_nodes.get("templo", null) if hx.view.buildings != null else null
	if temple is Node3D:
		out["templo"] = _node_px(temple as Node3D)
	return out


## Las esquinas en el suelo del pueblo: las manzanas del diseño de nivel más las huellas del templo, la plaza, los tres objetivos y el corral de la posta.
func _town_corners() -> Array:
	var pts: Array = []
	var terrain: Variant = hx.rules.call("terrain")
	if terrain != null and (terrain as Object).has_method("features"):
		var blocks: Variant = terrain.call("features", "manzana")
		if blocks is Array:
			for b in blocks:
				for q in (b as Dictionary).get("poly", []):
					pts.append(Vector2(float((q as Dictionary).get("x", 0.0)), float((q as Dictionary).get("z", 0.0))))
	var buildings: Variant = hx.view.buildings
	for id in TOWN_IDS:
		if buildings != null and buildings.lm_by_id.has(id):
			for c in buildings.footprint_corners(buildings.footprint(buildings.lm_by_id[id])):
				pts.append(c)
	return pts


## Qué fracción del cuadro (en %) ocupa el casco convexo de `world_pts` proyectado, y el ancho y alto de su caja en % del cuadro.
func _hull_pct(world_pts: Array, size: Vector2i) -> Dictionary:
	var screen := PackedVector2Array()
	for p in world_pts:
		var s: Variant = _real(_ground((p as Vector2).x, (p as Vector2).y))
		if s != null:
			screen.append(s as Vector2)
	if screen.size() < 3:
		return {"area_pct": 0.0, "ancho_pct": 0.0, "alto_pct": 0.0}
	var hull := Geometry2D.convex_hull(screen)
	var area := 0.0
	for i in range(hull.size()):
		var a := hull[i]
		var b := hull[(i + 1) % hull.size()]
		area += a.x * b.y - b.x * a.y
	area = absf(area) * 0.5
	var lo := Vector2(1.0e9, 1.0e9)
	var hi := Vector2(-1.0e9, -1.0e9)
	for s in screen:
		lo = Vector2(minf(lo.x, s.x), minf(lo.y, s.y))
		hi = Vector2(maxf(hi.x, s.x), maxf(hi.y, s.y))
	var whole := float(size.x) * float(size.y)
	return {"area_pct": snappedf(100.0 * area / whole, 0.1), "ancho_pct": snappedf(100.0 * (hi.x - lo.x) / float(size.x), 0.1), "alto_pct": snappedf(100.0 * (hi.y - lo.y) / float(size.y), 0.1)}


func _camera_dict() -> Dictionary:
	var c: Dictionary = hx.qa_state().camera
	return {"objetivo": [snappedf(float(c.target[0]), 0.1), snappedf(float(c.target[1]), 0.1)], "distancia_m": snappedf(float(c.dist), 0.1), "inclinacion_deg": snappedf(float(c.pitch_deg), 0.1), "rumbo_deg": snappedf(float(c.yaw_deg), 0.1)}


# ---------------------------------------------------------------------------------------------------------------------

func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	if not suite.check(scene != null, "la escena principal carga"):
		suite.finish(self)
		return
	game = scene.instantiate()
	root.add_child(game)
	await _frames(4)
	game.jev.force_local = true
	game.settings.auto_pause = false
	if is_instance_valid(game.audio_manager):
		game.audio_manager.set_muted(true)
	await _set_window(Vector2i(1280, 720))
	game._start_humahuaca({"skip_intro": true, "seed": 1817})
	await _frames(4)
	hx = game.hx
	if not suite.check(game.mode == "hx" and is_instance_valid(hx) and is_instance_valid(hx.view) and hx.rules != null, "el nivel arranca con el controlador, la vista y las reglas reales"):
		suite.finish(self)
		return
	if str(hx.mode) != "play":
		hx._start_play_after_briefing(true)
		await _frames(2)
	suite.extra["fov_deg"] = snappedf(float(_cam().fov), 0.1)
	suite.extra["zoom_min_max_m"] = [snappedf(float(hx.cam.min_dist()), 0.1), snappedf(float(hx.cam.max_dist()), 0.1)]
	for size in SIZES:
		await _measure_initial(size)
	await _set_window(Vector2i(1280, 720))
	await _test_zoom(Vector2i(1280, 720))
	await _test_centering()
	suite.extra["camara"] = by_size
	suite.extra["nota"] = "píxeles reales de la ventana; el margen es el menor de los cuatro bordes en % del lado; las fichas son de tamaño fijo en píxeles (tokens.min_px)"
	_write_report()
	suite.require_floor(35)
	suite.finish(self)


## El cuadro inicial a un tamaño de ventana: puntos clave, fichas, edificios y el pueblo.
func _measure_initial(size: Vector2i) -> void:
	await _set_window(size)
	hx.reset_camera()
	await _frames(3)
	var label := "%dx%d" % [size.x, size.y]
	var entry := {"ventana_px": [size.x, size.y], "logico_px": [snappedf(root.get_visible_rect().size.x, 0.1), snappedf(root.get_visible_rect().size.y, 0.1)], "escala_real_por_logico": snappedf(_scale().y, 0.0001),
		"escala_interfaz": snappedf(float(hx.ui_scale), 0.001), "camara": _camera_dict(), "fits_vista": bool(hx.initial_frame().fits)}
	# V02: los tres objetivos a ≥ 10 % del borde siempre; la zona de partida según el preset activo de la cámara: si la lista entre sus puntos duros se exige su centro con el
	# margen que pide; si no (los presets «pueblo…», el compromiso que pidió el usuario), se informa el margen del centro y se exige el ancla del preset (los reconocedores)
	var margins := {}
	var worst_obj := 1000.0
	for id in V02_IDS:
		var p: Vector2 = hx.landmark_pos(id)
		var m := _margin_pct(_ground(p.x, p.y), size)
		margins[id] = snappedf(m, 0.1)
		if id != "zona_partida":
			worst_obj = minf(worst_obj, m)
	entry["margen_v02_pct"] = margins
	entry["peor_margen_objetivos_pct"] = snappedf(worst_obj, 0.1)
	entry["zona_partida_on_screen_5"] = float(margins.zona_partida) >= 5.0  # la regla de _initial_frame_report (on_screen a 5 %)
	suite.check(bool(entry.fits_vista), "%s: initial_frame().fits de la vista es verdadero" % label)
	suite.check(worst_obj >= V02_MARGIN_PCT, "%s: V02: los tres objetivos a ≥ %.0f %% del borde (peor %.1f %%: %s)" % [label, V02_MARGIN_PCT, worst_obj, str(margins)])
	var fit: Dictionary = hx.cam.last_fit.duplicate(true) if "last_fit" in hx.cam else {}
	var hard_ids: Array = []
	var zona_hard := false
	for h in hx.cam.preset(str(fit.get("preset", ""))).get("hard", []):
		if (h as Dictionary).has("landmark"):
			hard_ids.append(str(h.landmark))
			if str(h.landmark) == "zona_partida":
				zona_hard = true
				suite.check(float(margins.zona_partida) >= float(h.get("margin_pct", 5.0)), "%s: V02: el centro de la zona de partida a ≥ %.0f %% del borde (%.1f %%)" % [label, float(h.get("margin_pct", 5.0)), float(margins.zona_partida)])
	entry["zona_partida_exigida"] = zona_hard
	suite.check(bool(fit.get("hard_ok", false)), "%s: todos los puntos duros del preset «%s» (%s) entran con su margen (ajuste: %s)" % [label, str(fit.get("preset", "")), str(hard_ids), str(fit)])
	# las cinco partidas: cuántas se ven y a qué margen; ninguna de las visibles bajo el HUD (B-021)
	var units := {}
	var visible := 0
	var covered: Array = []
	var hud_rects: Dictionary = hx.hud.rects()
	for id in V.GROUPS:
		var u := _unit_pos(id)
		var w := _ground(u.x, u.y)
		var m := _margin_pct(w, size)
		units[id] = snappedf(m, 0.1)
		if m >= 0.0:
			visible += 1
			var logical := _cam().unproject_position(w)
			for key in ["header", "fronts", "dock"]:
				if hud_rects.has(key) and (hud_rects[key] as Rect2).has_point(logical):
					covered.append("%s bajo %s" % [id, key])
	entry["margen_partidas_pct"] = units
	entry["partidas_a_la_vista"] = visible
	suite.check(covered.is_empty(), "%s: ninguna ficha a la vista queda bajo el HUD (%s)" % [label, str(covered)])
	var soft_in: Array = fit.get("soft_in", [])
	var soft_short: Array = []
	for id in soft_in:
		if float(units.get(str(id), -1.0)) < 2.0:
			soft_short.append(str(id))
	suite.check(soft_short.is_empty(), "%s: las partidas que el encuadre da por incluidas (%s) quedan a ≥ 2 %% del borde (%s)" % [label, str(soft_in), str(soft_short)])
	if size.x >= 1280:
		suite.check(soft_in.has("reconocedores") or zona_hard, "%s: los reconocedores (la partida que se usa primero) o la zona de partida entera quedan a la vista (incluidas: %s)" % [label, str(soft_in)])
	# el templo y la plaza, a la vista
	var town_pts := {}
	for id in ["templo", "plaza"]:
		var p: Vector2 = hx.landmark_pos(id)
		town_pts[id] = snappedf(_margin_pct(_ground(p.x, p.y), size), 0.1)
	entry["margen_pueblo_pct"] = town_pts
	suite.check(float(town_pts.templo) >= 5.0 and float(town_pts.plaza) >= 5.0, "%s: el templo y la plaza quedan a la vista (≥ 5 %% del borde: templo %.1f %%, plaza %.1f %%)" % [label, float(town_pts.templo), float(town_pts.plaza)])
	# fichas (V03) y edificios
	var tokens := _token_px()
	entry["ficha_px"] = tokens
	var lowest := 1.0e9
	for id in tokens:
		lowest = minf(lowest, float(tokens[id]))
	entry["ficha_min_px"] = snappedf(lowest, 0.1) if tokens.size() > 0 else 0.0
	entry["ficha_objetivo_64px_cumplido"] = tokens.size() == V.GROUPS.size() and lowest >= TOKEN_GOAL_PX
	if size == Vector2i(1280, 720):
		suite.check(tokens.size() == V.GROUPS.size() and lowest >= TOKEN_MIN_PX, "%s: V03: las cinco fichas de pie miden ≥ %.0f px reales de alto con el zoom inicial (la más baja %.1f px)" % [label, TOKEN_MIN_PX, lowest])
	entry["edificio_px"] = _building_px()
	# metros por píxel en la plaza (vertical, con la profundidad de ese punto) y la fracción del cuadro que ocupan el pueblo y los tres objetivos
	var plaza: Vector2 = hx.landmark_pos("plaza")
	var plaza_logical := _cam().unproject_position(_ground(plaza.x, plaza.y))
	var mpp_logical := float(hx.view.meters_per_pixel(_cam(), plaza_logical))
	entry["m_por_px_real_en_plaza"] = snappedf(mpp_logical / maxf(_scale().y, 0.001), 0.0001)
	entry["px_por_10_m_en_plaza"] = snappedf(10.0 * _scale().y / maxf(mpp_logical, 0.0001), 0.1)
	entry["pueblo"] = _hull_pct(_town_corners(), size)
	entry["tres_objetivos"] = _hull_pct(_objective_corners(), size)
	var frame_pts: Array = []
	for id in V02_IDS + SPAWN_IDS:
		frame_pts.append(hx.landmark_pos(id))
	entry["objetivos_y_partidas"] = _hull_pct(frame_pts, size)
	entry["ajuste"] = hx.cam.last_fit.duplicate(true) if "last_fit" in hx.cam else {}
	suite.check(float(entry.pueblo.area_pct) > 1.0, "%s: el pueblo ocupa una fracción medible del cuadro (%.1f %%; caja %.0f %% × %.0f %%)" % [label, float(entry.pueblo.area_pct), float(entry.pueblo.ancho_pct), float(entry.pueblo.alto_pct)])
	entry["presets"] = await _measure_presets(size)
	by_size[label] = entry


func _objective_corners() -> Array:
	var out: Array = []
	for id in V.OBJECTIVES:
		var lm: Dictionary = hx.view.buildings.lm_by_id[id]
		for c in hx.view.buildings.footprint_corners(hx.view.buildings.footprint(lm)):
			out.append(c)
	return out


## Lo que taparían la cabecera y el dock, como lo pasa el controlador a la cámara (initial_pose).
func _hud_band() -> Dictionary:
	var m := float(hx.margin())
	return {"top_px": (m + hx.layout_num(["header_h"], 46.0)) * hx.ui_scale, "bottom_px": (m + hx.layout_num(["dock_h"], 136.0)) * hx.ui_scale, "ui_scale": hx.ui_scale}


## Cada preset del encuadre inicial (data/humahuaca_camera.json) a este tamaño: distancia, márgenes y tamaños, para compararlos en CAMARA.md. Deja la cámara en el cuadro inicial.
func _measure_presets(size: Vector2i) -> Dictionary:
	var out := {}
	if not ("fit_with" in hx.cam) or not hx.cam.has_method("preset_names"):
		return out
	for name in hx.cam.preset_names():
		var f: Dictionary = hx.cam.fit_with(_cam(), hx.initial_frame(), _hud_band(), str(name))
		await _frames(1)
		var margins := {}
		for id in V02_IDS:
			var p: Vector2 = hx.landmark_pos(id)
			margins[id] = snappedf(_margin_pct(_ground(p.x, p.y), size), 0.1)
		var units := {}
		for id in V.GROUPS:
			var u := _unit_pos(id)
			units[id] = snappedf(_margin_pct(_ground(u.x, u.y), size), 0.1)
		var plaza: Vector2 = hx.landmark_pos("plaza")
		var mpp := float(hx.view.meters_per_pixel(_cam(), _cam().unproject_position(_ground(plaza.x, plaza.y))))
		out[str(name)] = {"camara": {"objetivo": [snappedf((f.target as Vector2).x, 0.1), snappedf((f.target as Vector2).y, 0.1)], "distancia_m": snappedf(float(f.dist), 0.1), "inclinacion_deg": snappedf(float(f.pitch_deg), 0.1), "rumbo_deg": snappedf(float(f.yaw_deg), 0.1)},
			"margen_v02_pct": margins, "margen_partidas_pct": units, "ajuste": hx.cam.last_fit.duplicate(true), "edificio_px": _building_px(), "px_por_10_m_en_plaza": snappedf(10.0 * _scale().y / maxf(mpp, 0.0001), 0.1),
			"pueblo": _hull_pct(_town_corners(), size), "tres_objetivos": _hull_pct(_objective_corners(), size)}
	hx.reset_camera()
	await _frames(2)
	return out


## La rueda: límites del zoom, pasos hasta el mínimo y el punto del suelo bajo el cursor (zoom_at mantiene ese punto).
func _test_zoom(size: Vector2i) -> void:
	var label := "%dx%d" % [size.x, size.y]
	hx.reset_camera()
	await _frames(2)
	var f: Dictionary = hx.initial_pose()
	var min_m := float(hx.cam.min_dist())
	var max_m := float(hx.cam.max_dist())
	hx.qa_set_camera(f.target, 1.0, float(f.pitch_deg), float(f.yaw_deg))
	suite.check(is_equal_approx(float(hx.qa_state().camera.dist), min_m), "%s: el zoom no baja del mínimo (%.0f m)" % [label, min_m])
	hx.qa_set_camera(f.target, 99999.0, float(f.pitch_deg), float(f.yaw_deg))
	suite.check(is_equal_approx(float(hx.qa_state().camera.dist), max_m), "%s: el zoom no pasa del máximo (%.0f m)" % [label, max_m])
	hx.reset_camera()
	await _frames(2)
	var start := float(hx.qa_state().camera.dist)
	var notches := 0
	var d := start
	while d > min_m + 0.01 and notches < 200:
		d = maxf(d * ZOOM_NOTCH, min_m)
		notches += 1
	var zoom := {"inicial_m": snappedf(start, 0.1), "minimo_m": snappedf(min_m, 0.1), "maximo_m": snappedf(max_m, 0.1), "pasos_de_rueda_hasta_el_minimo": notches}
	# el punto del suelo bajo el cursor no se mueve al acercar: cinco pasos de rueda sobre la plaza
	var plaza: Vector2 = hx.landmark_pos("plaza")
	var cursor := _cam().unproject_position(_ground(plaza.x, plaza.y))
	var before: Variant = hx.ground_from_screen(cursor)
	var worst := 0.0
	for i in range(5):
		hx.cam.zoom_at(_cam(), cursor, ZOOM_NOTCH)
		var after: Variant = hx.ground_from_screen(cursor)
		if before is Vector2 and after is Vector2:
			worst = maxf(worst, (before as Vector2).distance_to(after as Vector2))
	zoom["desvio_bajo_el_cursor_m"] = snappedf(worst, 0.01)
	zoom["distancia_tras_5_pasos_m"] = snappedf(float(hx.qa_state().camera.dist), 0.1)
	suite.check(before is Vector2 and worst <= 2.0, "%s: al acercar con la rueda el punto del suelo bajo el cursor se queda (desvío máximo %.2f m en 5 pasos)" % [label, worst])
	# al mínimo: cuánto miden el templo y las fichas (lo más cerca que puede mirar el jugador)
	hx.qa_set_camera(hx.landmark_pos("templo"), min_m, float(f.pitch_deg), float(f.yaw_deg))
	await _frames(2)
	zoom["templo_px_al_minimo"] = _building_px().get("templo", [0.0, 0.0])
	var centroid := Vector2.ZERO
	for id in V.GROUPS:
		centroid += _unit_pos(id) / float(V.GROUPS.size())
	hx.qa_set_camera(centroid, min_m, float(f.pitch_deg), float(f.yaw_deg))
	await _frames(2)
	zoom["fichas_px_al_minimo"] = _token_px()
	suite.extra["zoom_%s" % label] = zoom
	hx.reset_camera()
	await _frames(2)


## Las teclas 4 y 5 (dos veces) centran la cámara en la ficha; se mide si después la cámara la sigue cuando marcha.
func _test_centering() -> void:
	hx.reset_camera()
	await _frames(2)
	var recon := _unit_pos("reconocedores")
	hx.select_group(3)
	hx.select_group(3)  # la segunda vez centra
	await _frames(2)
	var t: Array = hx.qa_state().camera.target
	var centered := Vector2(float(t[0]), float(t[1])).distance_to(recon)
	suite.check(hx.qa_state().selected == ["reconocedores"] and centered <= 0.5, "centrar: la tecla 4 dos veces elige a los reconocedores y centra la cámara en ellos (a %.2f m)" % centered)
	var dist_before := float(hx.qa_state().camera.dist)
	var r: Dictionary = hx.orders.issue("reconocedores", "move", recon + Vector2(0.0, -60.0), {})
	hx.qa_step(40.0)
	await _frames(3)
	var moved := _unit_pos("reconocedores").distance_to(recon)
	t = hx.qa_state().camera.target
	var gap := Vector2(float(t[0]), float(t[1])).distance_to(_unit_pos("reconocedores"))
	var follows := moved > 5.0 and gap <= 1.0
	var following_id := str(hx.cam.follow_id) if "follow_id" in hx.cam else ""
	suite.extra["seguimiento"] = {"orden_ok": bool(r.get("ok", false)), "ficha_se_movio_m": snappedf(moved, 0.1), "distancia_camara_ficha_m": snappedf(gap, 0.1), "sigue_a_la_ficha": follows, "siguiendo": following_id, "zoom_se_mantiene": is_equal_approx(dist_before, float(hx.qa_state().camera.dist))}
	suite.check(bool(r.get("ok", false)) and moved > 5.0, "centrar: la orden de marcha mueve a los reconocedores (%.1f m en 40 s)" % moved)
	suite.check(is_equal_approx(dist_before, float(hx.qa_state().camera.dist)), "centrar: centrar en una ficha no cambia el zoom")
	suite.check(follows and following_id == "reconocedores", "seguir: tras centrar en los reconocedores la cámara los sigue mientras marchan (a %.1f m de la ficha tras %.0f m de marcha)" % [gap, moved])
	# la rueda no suelta a la ficha; mover la cámara a mano (teclas, arrastre, minimapa) o volver al cuadro inicial sí
	hx.cam.zoom_at(_cam(), root.get_visible_rect().size * 0.5, ZOOM_NOTCH)
	suite.check(str(hx.cam.follow_id) == "reconocedores" and float(hx.qa_state().camera.dist) < dist_before, "seguir: la rueda acerca sin soltar a la ficha")
	hx.cam.pan(Vector2(1.0, 0.0), 0.1)
	suite.check(str(hx.cam.follow_id) == "", "seguir: mover la cámara con las teclas la suelta")
	hx.select_group(4)
	hx.select_group(4)
	suite.check(str(hx.cam.follow_id) == "arreo", "seguir: la tecla 5 dos veces pasa a seguir al arreo")
	hx.center_on_front("bateria")
	suite.check(str(hx.cam.follow_id) == "" and Vector2(float(hx.qa_state().camera.target[0]), float(hx.qa_state().camera.target[1])).distance_to(hx.landmark_pos("bateria")) <= 0.5, "seguir: centrar en un frente suelta a la ficha y centra en el frente")
	hx.select_group(3)
	hx.select_group(3)
	hx.reset_camera()
	suite.check(str(hx.cam.follow_id) == "", "seguir: volver al cuadro inicial (Inicio) suelta a la ficha")
	await _frames(2)


func _write_report() -> void:
	if report_path == "":
		return
	var f := FileAccess.open(report_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(suite.report(), "\t"))
		f.close()
