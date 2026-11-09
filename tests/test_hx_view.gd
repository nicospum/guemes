extends SceneTree

## Pruebas de la capa de vista del nivel «humahuaca» (CONTRATO 3.4 y 7; TRAZA TR-091 a TR-099). Dueña: visual. Sin ventana ni escritura:
##   godot --headless --path . --script tests/test_hx_view.gd [-- --ronda=r1.0]
## Prueba la vista REAL (view/humahuaca_view.gd, desde R1) y el STUB (stubs/stub_view.gd) con las mismas comprobaciones (cada descripción lleva «[real]» o «[stub]»),
## más las propias de la vista real (terreno continuo con un solo shader, templo y batería, arquetipos, luces, lluvia, calidad y presupuestos). Si las otras pistas ya entregaron sus stubs, arma la vista sobre ellos
## (tests/hx_fixtures.gd); si no, sobre las copias mínimas de tools/vis_humahuaca.gd. Piso de comprobaciones: 25 (CONTRATO 5.1).
## Desde el hallazgo I-R1.0-3 (pase 2 de R1.0) prueba también: el alba no lava el cuadro de naranja saturado, los anillos de visibilidad no se cruzan ni
## se dibujan con luz plena, y lo que depende de la cámara se mide con la cámara que el controlador deja DESPUÉS de llamar a update_state.
const Fx = preload("res://tests/hx_fixtures.gd")
const Vis = preload("res://tools/vis_humahuaca.gd")
const VV = preload("res://scripts/humahuaca/view/vocab_view.gd")
const V = preload("res://scripts/humahuaca/humahuaca_vocab.gd")

const FLOOR_BY_ROUND := {"r0": 25, "r1.0": 25, "r1": 25, "r2a": 40, "r2b": 40, "r3": 40, "r4": 40}
const FORBIDDEN_NAMES := "campanario|torre_de_campana|bandera|monumento|escalinata|poste|alamo|eucalipto|tendido|farol|sol_de_mayo"

var suite := Fx.new()
var rules: RefCounted
var view = null
var cam: Camera3D
var visual: Dictionary = {}
var view_path := ""  ## la vista que se prueba en este recorrido (real o stub)
var label := "stub"


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame  # los nodos agregados a root dentro de _initialize todavía no están «dentro del árbol»: se espera un cuadro
	suite.begin("hx_view", OS.get_cmdline_user_args())
	visual = V.load_json(V.VISUAL_PATH)
	rules = Fx.rules_stub()
	suite.extra["reglas"] = "stub_rules" if rules != null else "copia mínima de tools/vis_humahuaca.gd"
	if rules == null:
		rules = Vis.FakeRules.new()
	var targets: Array = []
	if Fx.load_script(Fx.REAL_PATHS.view) != null:
		targets.append(["real", Fx.REAL_PATHS.view])
	targets.append(["stub", "res://scripts/humahuaca/stubs/stub_view.gd"])
	for target in targets:
		label = str(target[0])
		view_path = str(target[1])
		_test_build()
		_test_initial_frame()
		_test_picking()
		_test_anachronisms()
		_test_palette_only()
		_test_canonical_views()
		_test_lights()
		_test_dawn_wash()
		_test_visibility_rings()
		await _test_camera_order()
		_test_archetypes_grayscale()
		_test_albedo_and_probes()
		_test_dynamic_api()
		_test_degraded()
		_teardown()
		await process_frame
	label = "real"
	if Fx.load_script(Fx.REAL_PATHS.view) != null:
		view_path = Fx.REAL_PATHS.view
		await _test_real_view()
		await _test_terrain_rendered()
		await _test_units_follow_rules()
		await _test_probes_and_scales()
		await _test_formations()
	_ck(suite.elapsed_ms() < 30000, "test_hx_view corre en poco tiempo (objetivo < 30 s): %d ms" % suite.elapsed_ms())
	suite.require_floor(int(FLOOR_BY_ROUND.get(suite.round_id, 25)))
	suite.finish(self)


## Una comprobación con la etiqueta de la vista que se está probando.
func _ck(condition: bool, description: String) -> bool:
	return suite.check(condition, "[%s] %s" % [label, description])


func _teardown() -> void:
	if view != null and is_instance_valid(view):
		view.free()
	view = null
	if cam != null and is_instance_valid(cam):
		cam.free()
	cam = null


func _make_camera(parent: Node, fov: float = 46.0) -> Camera3D:
	var c := Camera3D.new()
	c.fov = fov
	c.far = 9000.0
	parent.add_child(c)
	c.current = true
	return c


func _frame_camera(c: Camera3D, f: Dictionary) -> void:
	var yaw := deg_to_rad(float(f.yaw_deg))
	var pitch := deg_to_rad(float(f.pitch_deg))
	var look := Vector3(sin(yaw) * cos(pitch), -sin(pitch), -cos(yaw) * cos(pitch))
	c.transform = Transform3D(Basis.looking_at(look, Vector3.UP), (f.target as Vector3) - look * float(f.distance))


func _node_bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or str(m.name) in ["anillo", "borde", "seleccion"]:  # visual/r1 F1: los anillos del suelo (de radio real) no son parte de la silueta
			continue
		var b := m.global_transform * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## El punto medio de la figura de una ficha (de la base a la cima de sus piezas, sin los anillos).
func _token_center(node: Node3D) -> Vector3:
	var top := node.global_position.y
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		if not (str(mi.name) in ["anillo", "borde", "seleccion"]):
			top = maxf(top, ((mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()).end.y)
	return Vector3(node.global_position.x, (node.global_position.y + top) * 0.5, node.global_position.z)


# ---------------------------------------------------------------------------------------------------------------------
# TR-091 · construcción, presupuesto y firma completa

func _test_build() -> void:
	var script := Fx.load_script(view_path)
	if not _ck(script != null, "TR-091 stubs/stub_view.gd carga y parsea"):
		return
	var missing := Fx.api_missing(script, "view")
	_ck(missing.is_empty(), "TR-091 el stub trae toda la API de 3.4%s" % ("" if missing.is_empty() else ": falta " + ", ".join(PackedStringArray(missing))))
	var real := Fx.load_script(Fx.REAL_PATHS.view)
	suite.extra["vista_real"] = real != null
	if real != null:
		var real_missing := Fx.api_missing(real, "view")
		_ck(real_missing.is_empty(), "TR-091 la vista real trae toda la API de 3.4%s" % ("" if real_missing.is_empty() else ": falta " + ", ".join(PackedStringArray(real_missing))))
	cam = _make_camera(root)
	view = script.new()
	root.add_child(view)
	var before := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	view.build(rules, "media")
	_ck(view.get_child_count() >= 3, "TR-091 la vista construye terreno, luz y ambiente (%d hijos)" % view.get_child_count())
	_ck(float(view.build_ms) < 1500.0, "TR-091 construir tarda menos de 1 500 ms (%.0f ms)" % float(view.build_ms))
	suite.extra["build_ms"] = snappedf(float(view.build_ms), 0.1)
	var nodes: int = view.find_children("*", "", true, false).size()
	suite.extra["nodos"] = nodes
	_ck(nodes > 40 and nodes < 3000, "TR-091 el presupuesto de nodos es razonable (%d)" % nodes)
	var landmarks := (rules.call("terrain").call("landmarks", {}) as Array).size()
	_ck((view.find_children("hito_*", "Node3D", true, false).size()) >= mini(landmarks - 2, 15), "TR-091 hay un nodo por hito con huella (%d hitos)" % landmarks)
	_ck(view.unit_nodes.size() == 5 and view.unit_labels.size() == 5, "TR-091 hay una ficha y una etiqueta por agrupación")
	for q in VV.QUALITY:
		view.build(rules, q)
		_ck(view.get_child_count() >= 3, "TR-091 build(«%s») no rompe la escena" % q)
	view.build(rules, "media")
	view.free()
	view = null
	var probe := (load(view_path) as GDScript).new() as Node3D
	root.add_child(probe)
	probe.build(rules, "media")
	probe.build(rules, "media")
	probe.free()
	_ck(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) <= before, "TR-091 construir dos veces y liberar no deja nodos huérfanos (%d antes, %d después)" % [before, int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))])
	view = (load(view_path) as GDScript).new() as Node3D
	root.add_child(view)
	view.build(rules, "media")
	view.update_state(0.0)


# ---------------------------------------------------------------------------------------------------------------------
# TR-092 · el cuadro inicial incluye los tres objetivos y la zona de partida

func _test_initial_frame() -> void:
	if view == null:
		return
	var sizes := {"1024x640": Vector2i(1024, 640), "1280x720": Vector2i(1280, 720), "1920x1080": Vector2i(1920, 1080), "2560x1440": Vector2i(2560, 1440), "1024x768": Vector2i(1024, 768)}
	for label in sizes:
		var sub := SubViewport.new()
		sub.size = sizes[label]
		sub.render_target_update_mode = SubViewport.UPDATE_DISABLED
		root.add_child(sub)
		var c := Camera3D.new()
		c.fov = 46.0
		sub.add_child(c)
		var f: Dictionary = view.initial_frame(c)
		_ck(bool(f.fits) and float(f.distance) >= 40.0 and float(f.distance) <= 900.0, "TR-092 initial_frame().fits a %s con distancia %.0f m dentro del zoom de 40 a 900 m" % [label, float(f.distance)])
		sub.free()
	var f2: Dictionary = view.initial_frame(cam)
	_frame_camera(cam, f2)
	var vp_size := cam.get_viewport().get_visible_rect().size
	var points := {"bateria": null, "cuartel": null, "posta": null, "zona_partida": null}
	for id in points:
		var info: Dictionary = view.get_landmark_info(id)
		var p := Vector3(float(info.get("x", -1.0)), float(info.get("y", 0.0)), float(info.get("z", -1.0)))
		var screen := cam.unproject_position(p)
		var inside := not cam.is_position_behind(p) and screen.x >= vp_size.x * 0.05 and screen.x <= vp_size.x * 0.95 and screen.y >= vp_size.y * 0.05 and screen.y <= vp_size.y * 0.95
		_ck(info.size() > 0 and inside, "TR-092 «%s» queda a la vista, a ≥ 5 %% del borde, con la cámara inicial real (%.0f, %.0f de %.0f × %.0f)" % [id, screen.x, screen.y, vp_size.x, vp_size.y])
	var jf: Dictionary = visual.get("initial_frame", {})
	_ck(is_equal_approx(float(f2.pitch_deg), float(jf.get("pitch_deg", -1.0))) and is_equal_approx(float(f2.yaw_deg), float(jf.get("yaw_deg", -1.0))), "TR-092 la inclinación y el rumbo iniciales son los del JSON (52° y el rumbo de la mirada de A-11)")


# ---------------------------------------------------------------------------------------------------------------------
# TR-093 · picking coherente con el terreno

func _test_picking() -> void:
	if view == null:
		return
	# un cuadro amplio donde entran las cinco partidas: con los datos reales alguna queda fuera del cuadro inicial (que solo exige los objetivos y la zona)
	_frame_camera(cam, {"target": Vector3(250.0, 20.0, 500.0), "distance": 720.0, "pitch_deg": 52.0, "yaw_deg": float((visual.get("initial_frame", {}) as Dictionary).get("yaw_deg", 325.0))})
	view.update_state(0.016)
	var good := 0
	for id in V.GROUPS:
		var node: Node3D = view.unit_nodes[id]
		var screen := cam.unproject_position(_token_center(node))
		if str(view.pick_unit(cam, screen)) == id:
			good += 1
	_ck(good == 5, "TR-093 pick_unit devuelve la agrupación sobre cada una de las 5 fichas (%d de 5)" % good)
	_ck(str(view.pick_unit(cam, Vector2(3.0, 3.0))) == "", "TR-093 pick_unit lejos de toda ficha devuelve «»")
	var in_rect: Array = view.pick_units_in_rect(cam, Rect2(Vector2.ZERO, cam.get_viewport().get_visible_rect().size))
	_ck(in_rect == V.GROUPS, "TR-093 pick_units_in_rect con todo el cuadro devuelve las 5 agrupaciones en el orden de GROUPS (%s)" % str(in_rect))
	var first_screen := cam.unproject_position(_token_center(view.unit_nodes["rodriguez"]))
	var around: Array = view.pick_units_in_rect(cam, Rect2(first_screen - Vector2(30.0, 30.0), Vector2(60.0, 60.0)))
	_ck(around.has("rodriguez") and around.size() < 5, "TR-093 pick_units_in_rect con una caja alrededor de Rodríguez devuelve esa ficha y no las cinco (%s)" % str(around))
	var fronts := 0
	for id in V.OBJECTIVES:
		var info: Dictionary = view.get_landmark_info(id)
		if str(view.pick_front(cam, cam.unproject_position(Vector3(float(info.x), float(info.y) + 2.0, float(info.z))))) == id:
			fronts += 1
	_ck(fronts == 3, "TR-093 pick_front devuelve el objetivo sobre cada uno de los 3 frentes (%d de 3)" % fronts)
	var info2: Dictionary = view.get_landmark_info("templo")
	_ck(str(view.pick_landmark(cam, cam.unproject_position(Vector3(float(info2.get("x", 0.0)), float(info2.get("y", 0.0)) + 1.5, float(info2.get("z", 0.0)))))) == "templo", "TR-093 pick_landmark encuentra el templo")
	var worst := 0.0
	for p in [Vector2(450.0, 325.0), Vector2(120.0, 500.0), Vector2(600.0, 250.0), Vector2(300.0, 400.0)]:
		var ground := Vector3(p.x, float(rules.call("terrain").call("height_at", p.x, p.y)), p.y)
		var back: Variant = view.ground_xz_from_screen(cam, cam.unproject_position(ground))
		worst = maxf(worst, (back as Vector2).distance_to(p) if back is Vector2 else 999.0)
	_ck(worst < 2.0, "TR-093 el rayo desde la pantalla vuelve al punto del terreno a menos de 2 m (peor %.2f m)" % worst)
	var horizon_cam := _make_camera(root)
	horizon_cam.transform = Transform3D(Basis.looking_at(Vector3(0.0, 0.2, -1.0), Vector3.UP), Vector3(450.0, 60.0, 600.0))
	_ck(view.ground_xz_from_screen(horizon_cam, horizon_cam.get_viewport().get_visible_rect().size * 0.5) == null, "TR-093 un rayo que sube por encima del horizonte devuelve null")
	horizon_cam.free()
	cam.current = true
	var mpp := float(view.meters_per_pixel(cam))
	_ck(mpp > 0.2 and mpp < 1.5, "TR-093 meters_per_pixel en la cámara inicial es plausible (%.3f m/px)" % mpp)
	_ck((view.camera_frustum_on_ground(cam) as PackedVector2Array).size() == 4, "TR-093 camera_frustum_on_ground devuelve 4 puntos")
	var uv: Vector2 = view.world_to_map(Vector2(450.0, 0.0))
	_ck(is_equal_approx(uv.x, 0.5) and is_equal_approx(uv.y, 0.0) and (view.map_to_world(Vector2(0.5, 1.0)) as Vector2).is_equal_approx(Vector2(450.0, 650.0)), "TR-093 world_to_map y map_to_world van y vuelven, con v = 0 en el norte")
	var bounds: Rect2 = view.camera_bounds()
	_ck(bounds.is_equal_approx(Rect2(-120.0, -120.0, 1140.0, 890.0)), "TR-093 camera_bounds es la ventana más 120 m (%s)" % str(bounds))
	var clamped: Vector3 = view.clamp_camera_target(Vector3(5000.0, 0.0, -5000.0))
	_ck(is_equal_approx(clamped.x, bounds.end.x) and is_equal_approx(clamped.z, bounds.position.y) and clamped.y >= float(rules.call("terrain").call("height_at", clamped.x, clamped.z)) - 0.001, "TR-093 clamp_camera_target recorta a los límites de la ventana más 120 m y no baja de la altura del suelo (%s)" % str(clamped))
	var tex: Texture2D = view.get_minimap_texture(Vector2i(260, 188))
	_ck(tex != null and tex.get_width() == 260 and tex.get_height() == 188, "TR-093 get_minimap_texture(260 × 188) devuelve una textura de ese tamaño")
	var labels: Array = view.landmark_labels(cam)
	_ck(labels.size() >= 15 and labels[0].has_all(["id", "name", "tag", "screen", "behind"]), "TR-093 landmark_labels devuelve {id, name, tag, screen, behind} (%d rótulos)" % labels.size())


# ---------------------------------------------------------------------------------------------------------------------
# TR-094 · sin anacronismos graves: por nombre y por altura de vértices

func _test_anachronisms() -> void:
	if view == null:
		return
	var rx := RegEx.new()
	rx.compile("(?i)(" + FORBIDDEN_NAMES + ")")
	var bad: Array = []
	for n in view.find_children("*", "", true, false):
		if rx.search(str(n.name)) != null:
			bad.append(str(n.name))
	_ck(bad.is_empty(), "TR-094 ningún nodo de la vista se llama como un anacronismo de la lista A%s" % ("" if bad.is_empty() else ": " + str(bad)))
	var temple := view.get_node_or_null("Hitos/hito_templo") as Node3D
	if _ck(temple != null, "TR-094 el templo existe como nodo de la vista"):
		var box := _node_bounds(temple)
		var ground := float(rules.call("terrain").call("height_at", 450.0, 325.0))
		_ck(box.end.y - minf(ground, box.position.y + 0.3) <= 8.0, "TR-094 el templo mide ≤ 8 m de alto por la altura de sus vértices (%.2f m)" % (box.end.y - minf(ground, box.position.y + 0.3)))
		var towers := 0
		for mi in temple.find_children("*", "MeshInstance3D", true, false):
			if (mi as MeshInstance3D).get_aabb().size.y > 8.0:
				towers += 1
		_ck(towers == 0, "TR-094 ninguna pieza del templo sobresale como torre de campanas")
	var text := JSON.stringify(visual.get("markers", {})) + JSON.stringify(visual.get("tokens", {}))
	var flag := RegEx.new()
	flag.compile("(?i)(bandera argentina|sol de mayo|cruz de borgo|bandera espa)")
	_ck(flag.search(text) == null, "TR-094 los marcadores y las fichas no nombran banderas de la lista A")


# ---------------------------------------------------------------------------------------------------------------------
# TR-095 · ninguna entidad con color suelto fuera de la paleta

func _test_palette_only() -> void:
	var ids := {}
	for entry in visual.get("palette", []):
		ids[str(entry.id)] = true
	_ck(ids.size() == 24, "TR-095 la paleta tiene 24 ids únicos (%d)" % ids.size())
	var stray: Array = []
	for section in ["props", "tokens", "lights", "rain", "fx", "units", "materials"]:
		_walk_colors(visual.get(section, {}), section, ids, stray)
	_ck(stray.is_empty(), "TR-095 todo color de props, fichas, luces, lluvia, efectos, figuras y materiales cita un id de la paleta%s" % ("" if stray.is_empty() else ": " + str(stray.slice(0, 3))))
	var constants: Dictionary = {}
	var table_scripts: Array = [view_path]
	if label == "real":  # en la vista real las tablas viven en el terreno y materiales (gfx), los efectos (fx) y las fichas (units)
		table_scripts = ["res://scripts/humahuaca/view/humahuaca_gfx.gd", "res://scripts/humahuaca/view/humahuaca_fx.gd", "res://scripts/humahuaca/view/humahuaca_units.gd"]
	for path in table_scripts:
		var sc := Fx.load_script(str(path))
		if sc != null:
			constants.merge(sc.get_script_constant_map(), true)
	var outside: Array = []
	for table in ["SURFACE_COLOR", "STATE_RING", "LOOT_COLOR"]:
		for key in (constants.get(table, {}) as Dictionary):
			if not ids.has(str(constants[table][key])):
				outside.append(str(constants[table][key]))
	_ck(outside.is_empty() and constants.has("SURFACE_COLOR"), "TR-095 las tablas de color (superficies, estado de los frentes, botín) citan ids de la paleta")
	var markers: Dictionary = visual.get("markers", {})
	_ck(str(markers.get("patriota", {}).get("fill", "")) == "#7FAAC4" and str(markers.get("realista", {}).get("fill", "")) == "#983F36" and str(markers.get("neutral", {}).get("fill", "")) == "#B99A50" and bool(markers.get("interfaz", false)), "TR-095 los marcadores de bando son los HEX exactos de la lámina 06 y están rotulados como interfaz")


func _walk_colors(node: Variant, path: String, ids: Dictionary, stray: Array) -> void:
	if node is Dictionary:
		for key in node:
			var value: Variant = node[key]
			if typeof(value) == TYPE_STRING and str(key).to_lower().find("color") >= 0 and not ids.has(str(value)):
				stray.append("%s.%s = %s" % [path, key, value])
			elif typeof(value) == TYPE_STRING and str(value).begins_with("#"):
				stray.append("%s.%s = %s (HEX suelto)" % [path, key, value])
			_walk_colors(value, path + "." + str(key), ids, stray)
	elif node is Array:
		for item in node:
			_walk_colors(item, path + "[]", ids, stray)


# ---------------------------------------------------------------------------------------------------------------------
# TR-096 · las 7 vistas canónicas y sus must_show

func _test_canonical_views() -> void:
	if view == null:
		return
	var listed: Array = []
	for entry in visual.get("canonical_views", []):
		listed.append(str(entry.get("id", "")))
	_ck(listed == VV.VIEW_IDS, "TR-096 canonical_views trae las 7 vistas en el orden de VIEW_IDS (%s)" % str(listed))
	var complete := 0
	var ranges_ok := 0
	for id in VV.VIEW_IDS:
		var v: Dictionary = view.canonical_view(id)
		if v.has_all(["target", "distance", "pitch_deg", "yaw_deg", "time_of_day", "rain", "must_show"]) and (v.must_show as Array).size() == 5:
			var texts_ok := true
			for line in v.must_show:
				texts_ok = texts_ok and typeof(line) == TYPE_STRING and str(line).length() >= 10 and str(line).length() <= 120
			complete += 1 if texts_ok else 0
			if float(v.distance) >= 40.0 and float(v.distance) <= 900.0 and float(v.pitch_deg) >= 5.0 and float(v.pitch_deg) <= 85.0 and float(v.time_of_day) >= 0.0 and float(v.time_of_day) <= 1.0 and float(v.rain) >= 0.0 and float(v.rain) <= 1.0:
				ranges_ok += 1
	_ck(complete == 7, "TR-096 cada vista canónica trae target, distancia, inclinación, rumbo, hora, lluvia y 5 rasgos obligatorios (%d de 7)" % complete)
	_ck(ranges_ok == 7, "TR-096 las 7 vistas están dentro de lo que la cámara del juego permite (40 a 900 m, 5° a 85°, hora y lluvia de 0 a 1) (%d de 7)" % ranges_ok)
	var night: Dictionary = view.canonical_view("juego_noche")
	var dawn: Dictionary = view.canonical_view("juego_alba")
	var initial: Dictionary = visual.get("initial_frame", {})
	_ck(is_equal_approx(float(night.distance), float(initial.distance)) and is_equal_approx(float(dawn.pitch_deg), float(initial.pitch_deg)) and (night.target as Vector3).is_equal_approx(dawn.target) and is_equal_approx(float(night.yaw_deg), float(initial.yaw_deg)) and is_equal_approx(float(dawn.yaw_deg), float(initial.yaw_deg)), "TR-096 juego_noche y juego_alba son la cámara inicial (470 m, 52° y el mismo rumbo)")
	_ck((view.canonical_view("no_existe") as Dictionary).is_empty(), "TR-096 canonical_view de un id desconocido devuelve {}")


# ---------------------------------------------------------------------------------------------------------------------
# TR-097 · las luces se dibujan de lejos; luz, niebla y lluvia salen del tiempo

func _test_lights() -> void:
	if view == null:
		return
	var state: Dictionary = rules.call("render_state")
	var wanted: Array = state.get("lights", [])
	var holder := view.get_node("Luces") as Node3D
	_ck(holder.get_child_count() == wanted.size() and wanted.size() >= 3, "TR-097 hay un punto de luz por cada luz de render_state (%d de %d, ≥ 3)" % [holder.get_child_count(), wanted.size()])
	var halos_ok := true
	for l in holder.get_children():
		var halo: MeshInstance3D = null
		for k in l.get_children():
			if k is MeshInstance3D:
				var m: Material = (k as MeshInstance3D).material_override
				if m is StandardMaterial3D and (m as StandardMaterial3D).billboard_mode == BaseMaterial3D.BILLBOARD_ENABLED:
					halo = k
		halos_ok = halos_ok and halo != null and halo.scale.x >= 4.0
	_ck(halos_ok, "TR-097 cada luz trae un resplandor que crece con la distancia para leerse de lejos")
	var sun := view.get_node("Sol") as DirectionalLight3D
	var env := (view.get_node("Ambiente") as WorldEnvironment).environment
	view.set_time_override(0.0, 0.9)
	var night_energy := sun.light_energy
	var night_fog := env.fog_density
	view.set_time_override(1.0, 0.0)
	_ck(sun.light_energy > night_energy and env.fog_density < night_fog, "TR-097 de noche con lluvia hay menos luz y más niebla que de día (%.2f → %.2f; %.4f → %.4f)" % [night_energy, sun.light_energy, night_fog, env.fog_density])
	view.set_time_override(0.5, 0.4)
	_ck(sun.light_color.r > sun.light_color.b, "TR-097 el alba tiene la luz cálida")
	view.set_time_override(-1.0, 0.0)
	view.set_layer_visible("lights", false)
	_ck(not holder.visible and not view.layer_visible("lights"), "TR-097 la capa «lights» apaga las luces")
	view.set_layer_visible("lights", true)
	_ck(holder.visible, "TR-097 y las vuelve a encender")


# ---------------------------------------------------------------------------------------------------------------------
# Hallazgo I-R1.0-3 · el alba no lava el cuadro de naranja saturado

## Saturación (HSV, 0 a 1) de un suelo de color `albedo` bajo la luz que arma la vista: albedo × (sol × energía × N·L + ambiente × energía), con el brillo
## normalizado (la exposición lo compensa) y la curva de tonos ACES. Es un indicador numérico y barato; la medida real, sobre píxeles de una captura con
## ventana, la hace tools/vis_humahuaca.gd (`naranja_saturado_pct` y `sat_media` en metrics_visual.json).
func _ground_saturation(sun: DirectionalLight3D, env: Environment, albedo: Color, ndl: float) -> float:
	var sun_lin := sun.light_color.srgb_to_linear()
	var amb_lin := env.ambient_light_color.srgb_to_linear()
	var alb := albedo.srgb_to_linear()
	var lit := Color(alb.r * (sun_lin.r * sun.light_energy * ndl + amb_lin.r * env.ambient_light_energy),
		alb.g * (sun_lin.g * sun.light_energy * ndl + amb_lin.g * env.ambient_light_energy),
		alb.b * (sun_lin.b * sun.light_energy * ndl + amb_lin.b * env.ambient_light_energy))
	var scale := 0.5 / maxf(maxf(lit.r, maxf(lit.g, lit.b)), 0.0001)
	var channels: Array = []
	for c in [lit.r * scale, lit.g * scale, lit.b * scale]:
		channels.append(clampf((c * (2.51 * c + 0.03)) / (c * (2.43 * c + 0.59) + 0.14), 0.0, 1.0))
	return Color(channels[0], channels[1], channels[2]).linear_to_srgb().s


func _palette_color(id: String) -> Color:
	for entry in visual.get("palette", []):
		if str(entry.get("id", "")) == id:
			return Color(str(entry.get("hex", "#808080")))
	return Color(0.5, 0.5, 0.5)


func _test_dawn_wash() -> void:
	if view == null:
		return
	var sun := view.get_node("Sol") as DirectionalLight3D
	var env := (view.get_node("Ambiente") as WorldEnvironment).environment
	var ground := _palette_color("suelo_seco")
	var dawn_spec: Dictionary = (visual.get("lights", {}) as Dictionary).get("alba", {})
	view.set_time_override(0.5, 0.0)
	var elevation := deg_to_rad(float((dawn_spec.get("sun", {}) as Dictionary).get("elevation_deg", 8.0)))
	var flat := _ground_saturation(sun, env, ground, sin(elevation))
	var facing_east := _ground_saturation(sun, env, ground, 0.35)  # una ladera al este: la que más sol toma al alba
	var sun_lin := sun.light_color.srgb_to_linear()
	var warm_ratio := sun_lin.r / maxf(sun_lin.b, 0.0001)
	view.set_time_override(1.0, 0.0)
	var noon := _ground_saturation(sun, env, ground, 0.6)
	view.set_time_override(-1.0, 0.0)
	suite.extra["alba_saturacion_suelo"] = {"plano": snappedf(flat, 0.001), "ladera_este": snappedf(facing_east, 0.001), "dia": snappedf(noon, 0.001), "relacion_rojo_azul_del_sol": snappedf(warm_ratio, 0.01)}
	# El stub de R1.0 daba 0,54 y 0,66 (naranja saturado: sol de oro puro); con el sol de lino cálido y el ambiente frío da 0,29 y 0,40 (el suelo mismo tiene 0,38)
	_ck(flat <= 0.40 and facing_east <= 0.46, "I-R1.0-3 el suelo bajo la luz del alba no se satura de naranja (saturación %.2f en llano y %.2f en una ladera al este; topes 0,40 y 0,46)" % [flat, facing_east])
	_ck(warm_ratio >= 1.3 and warm_ratio <= 3.5, "I-R1.0-3 el alba sigue siendo cálida sin ser un oro puro (relación rojo/azul del sol %.2f, entre 1,3 y 3,5)" % warm_ratio)
	_ck(facing_east >= noon - 0.1, "I-R1.0-3 el alba no queda más apagada que el día pleno (%.2f contra %.2f)" % [facing_east, noon])
	var ids := []
	for entry in visual.palette:
		ids.append(str(entry.id))
	var tinted := 0
	var tint_ok := true
	for key in ["noche_lluvia", "alba", "dia"]:
		var l: Dictionary = (visual.lights as Dictionary).get(key, {})
		for part in ["sun", "ambient", "fog"]:
			var spec: Dictionary = l.get(part, {})
			if spec.has("tint"):
				tinted += 1
				tint_ok = tint_ok and ids.has(str(spec.tint)) and float(spec.get("tint_mix", 0.0)) >= 0.0 and float(spec.get("tint_mix", 0.0)) <= 1.0
	_ck(tinted >= 1 and tint_ok, "I-R1.0-3 el alba mezcla colores de la paleta (%d mezclas) en vez de un HEX suelto, con ids de paleta y una proporción de 0 a 1" % tinted)


# ---------------------------------------------------------------------------------------------------------------------
# Hallazgo I-R1.0-3 · anillos de visibilidad: contorno de la unión, sin cruces, que se apagan con luz plena

func _arc_length(arcs: Array) -> float:
	var total := 0.0
	for arc in arcs:
		var pts: PackedVector2Array = arc.pts
		for k in range(pts.size() - 1 + (1 if bool(arc.closed) else 0)):
			total += pts[k].distance_to(pts[(k + 1) % pts.size()])
	return total


## Perímetro de la unión de los círculos, por muestreo fino del borde de cada uno (la referencia contra la que se compara el trazo de la vista).
func _union_perimeter(pools: Array) -> float:
	var total := 0.0
	for i in range(pools.size()):
		var samples := 720
		var kept := 0
		var ci := Vector2(float(pools[i].x), float(pools[i].z))
		for k in range(samples):
			var a := TAU * (float(k) + 0.5) / float(samples)
			var point := ci + Vector2(cos(a), sin(a)) * float(pools[i].r)
			var covered := false
			for j in range(pools.size()):
				if j == i:
					continue
				var cj := Vector2(float(pools[j].x), float(pools[j].z))
				var d := point.distance_to(cj)
				var same := cj.is_equal_approx(ci) and is_equal_approx(float(pools[j].r), float(pools[i].r))
				if d < float(pools[j].r) - 1.0e-6 and not (same and j > i):
					covered = true
					break
			kept += 0 if covered else 1
		total += TAU * float(pools[i].r) * float(kept) / float(samples)
	return total


func _test_visibility_rings() -> void:
	if view == null:
		return
	# 1) geometría del contorno de la unión (círculos sintéticos)
	var separate: Array = view.call("_pool_arcs", [{"x": 0.0, "z": 0.0, "r": 30.0}, {"x": 200.0, "z": 0.0, "r": 30.0}])
	var closed_count := 0
	for arc in separate:
		closed_count += 1 if bool(arc.closed) else 0
	_ck(separate.size() == 2 and closed_count == 2, "I-R1.0-3 dos círculos separados dan dos anillos enteros (%d trazos, %d cerrados)" % [separate.size(), closed_count])
	var pair_pools := [{"x": 0.0, "z": 0.0, "r": 40.0}, {"x": 50.0, "z": 0.0, "r": 40.0}]
	var pair: Array = view.call("_pool_arcs", pair_pools)
	var pair_len := _arc_length(pair)
	var expected := 2.0 * (TAU - 2.0 * acos(50.0 / 80.0)) * 40.0  # perímetro de la unión de dos círculos de radio 40 a 50 m: de cada uno queda 2π − 2·acos(d / 2r) de arco, ≈ 359 m
	_ck(pair.size() == 2 and absf(pair_len - expected) < expected * 0.01, "I-R1.0-3 dos círculos que se cruzan dan solo los dos arcos de afuera (%.1f m de trazo; la unión mide %.1f m)" % [pair_len, expected])
	var nested: Array = view.call("_pool_arcs", [{"x": 0.0, "z": 0.0, "r": 50.0}, {"x": 5.0, "z": 0.0, "r": 20.0}])
	_ck(nested.size() == 1 and bool(nested[0].closed), "I-R1.0-3 un círculo entero dentro de otro no se dibuja")
	var same: Array = view.call("_pool_arcs", [{"x": 10.0, "z": 10.0, "r": 35.0}, {"x": 10.0, "z": 10.0, "r": 35.0}, {"x": 10.0, "z": 10.0, "r": 35.0}])
	_ck(same.size() == 1 and bool(same[0].closed), "I-R1.0-3 tres círculos iguales se dibujan una sola vez")
	_ck((view.call("_pool_arcs", []) as Array).is_empty() and (view.call("_pool_arcs", [{"x": 0.0, "z": 0.0, "r": 0.0}]) as Array).is_empty(), "I-R1.0-3 sin círculos (o de radio cero) no hay trazos")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1817
	var worst_inside := 0.0
	var worst_gap := 0.0
	for trial in range(40):
		var pools: Array = []
		for _i in range(rng.randi_range(2, 6)):
			pools.append({"x": rng.randf_range(0.0, 300.0), "z": rng.randf_range(0.0, 300.0), "r": rng.randf_range(15.0, 140.0)})
		var arcs: Array = view.call("_pool_arcs", pools)
		for arc in arcs:
			for p in (arc.pts as PackedVector2Array):
				for q in pools:
					worst_inside = maxf(worst_inside, float(q.r) - p.distance_to(Vector2(float(q.x), float(q.z))))
		var reference := _union_perimeter(pools)
		worst_gap = maxf(worst_gap, absf(_arc_length(arcs) - reference) / maxf(reference, 1.0))
	_ck(worst_inside < 0.05, "I-R1.0-3 ningún punto de un trazo cae dentro de otro círculo (40 casos al azar; el peor entra %.3f m)" % maxf(worst_inside, 0.0))
	_ck(worst_gap < 0.02, "I-R1.0-3 el trazo dibujado es el perímetro de la unión (diferencia máxima %.2f %% contra el muestreo fino, 40 casos al azar)" % (worst_gap * 100.0))
	# 2) la opacidad baja con la visibilidad y se apaga con luz plena
	var cfg: Dictionary = ((visual.get("fog", {}) as Dictionary).get("anillos", {}) as Dictionary).get("visibilidad", {})
	var a_night := float(view.call("pool_alpha", 35.0))
	var a_dawn := float(view.call("pool_alpha", 128.0))
	var a_day := float(view.call("pool_alpha", 600.0))
	_ck(is_equal_approx(a_night, float(cfg.get("alpha", 0.55))) and a_dawn < a_night and a_dawn > 0.0 and a_day == 0.0, "I-R1.0-3 el anillo de visibilidad es tenue de noche (%.2f), más tenue al alba (%.2f) y no se dibuja con luz plena (%.2f)" % [a_night, a_dawn, a_day])
	_ck(float(cfg.get("alpha", 1.0)) <= 0.6 and float(cfg.get("width_px", 9.0)) <= 3.0, "I-R1.0-3 el anillo de visibilidad es tenue y fino por datos (opacidad %.2f, %.1f px)" % [float(cfg.get("alpha", 1.0)), float(cfg.get("width_px", 9.0))])
	# 3) lo que la vista ARMA a partir de un render_state propio (no depende del ambiente que dé el stub de las reglas): con poca visibilidad hay trazos, con luz plena no,
	#    y los anillos de los objetivos siempre; los vértices de los trazos no entran en otro círculo más que el medio ancho de la cinta
	var starts := [Vector2(92.5, 455.0), Vector2(140.0, 500.0), Vector2(190.0, 545.0), Vector2(230.0, 480.0), Vector2(70.0, 520.0)]  # las cinco partidas: con 35 m se cruzan tres pares
	var objectives := [{"id": "bateria", "x": 318.0, "z": 350.0, "state": "guardado"}, {"id": "cuartel", "x": 418.0, "z": 335.0, "state": "alertado"}, {"id": "posta", "x": 590.0, "z": 300.0, "state": "guardado"}]
	var probe := (load(view_path) as GDScript).new() as Node3D
	root.add_child(probe)
	probe.build(rules, "media")
	var rings := probe.get_node("Anillos")
	for case in [[35.0, true], [128.0, true], [600.0, false]]:
		var pools_now: Array = []
		for at in starts:
			pools_now.append({"x": at.x, "z": at.y, "r": case[0]})
		probe.call("_sync_objectives", {"objectives": objectives, "visibility_pools": pools_now, "tower": {}})
		var pool_nodes := rings.find_children("visibilidad_*", "MeshInstance3D", false, false).size()
		var objective_nodes := rings.find_children("objetivo_*", "MeshInstance3D", false, false).size()
		_ck(objective_nodes == 3 and ((pool_nodes >= 1) == bool(case[1])), "I-R1.0-3 con %.0f m de visibilidad hay %d trazo(s) de visibilidad y %d anillo(s) de objetivo (con luz plena no se dibuja ninguno de visibilidad)" % [case[0], pool_nodes, objective_nodes])
		if bool(case[1]):
			var crossing := 0
			for i in range(pools_now.size()):
				for j in range(i + 1, pools_now.size()):
					var d := Vector2(float(pools_now[i].x), float(pools_now[i].z)).distance_to(Vector2(float(pools_now[j].x), float(pools_now[j].z)))
					crossing += 1 if d < float(pools_now[i].r) + float(pools_now[j].r) and d > absf(float(pools_now[i].r) - float(pools_now[j].r)) else 0
			var worst := 0.0
			for node in rings.find_children("visibilidad_*", "MeshInstance3D", false, false):
				var arrays := ((node as MeshInstance3D).mesh as ArrayMesh).surface_get_arrays(0)
				for vertex in (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array):
					for q in pools_now:
						worst = maxf(worst, float(q.r) - Vector2(vertex.x, vertex.z).distance_to(Vector2(float(q.x), float(q.z))))
			_ck(pool_nodes == (probe.call("_pool_arcs", pools_now) as Array).size() and worst <= 1.5, "I-R1.0-3 con %.0f m la vista arma los trazos del contorno de la unión (%d trazos, %d pares de círculos se cruzan, el vértice que más entra en otro círculo entra %.2f m)" % [case[0], pool_nodes, crossing, worst])
			suite.extra["anillos_%dm_pares_que_se_cruzan" % int(case[0])] = crossing
	probe.free()


# ---------------------------------------------------------------------------------------------------------------------
# Hallazgo I-R1.0-3 · lo que depende de la cámara se mide con la cámara que el controlador deja DESPUÉS de llamar a update_state

class OrderProbe extends Node:
	var target_view: Node3D
	var camera: Camera3D
	var menu_xf: Transform3D
	var game_xf: Transform3D

	## El orden real de un cuadro: main deja la cámara donde la quería el menú, el controlador llama a update_state con ESA cámara y recién al final la reubica.
	func _process(delta: float) -> void:
		camera.transform = menu_xf
		target_view.update_state(delta)
		camera.transform = game_xf


func _test_camera_order() -> void:
	if view == null:
		return
	var f: Dictionary = view.initial_frame(cam)
	_frame_camera(cam, f)
	var shell := OrderProbe.new()
	shell.target_view = view
	shell.camera = cam
	shell.game_xf = cam.transform
	shell.menu_xf = Transform3D(Basis.IDENTITY, Vector3(-5.0, 4.0, 0.0))  # la cámara del menú: a ras del suelo, lejos de las fichas
	root.remove_child(view)
	shell.add_child(view)  # como en el juego: la vista es hija del controlador, así que su _process corre después del de él
	root.add_child(shell)
	await process_frame
	await process_frame
	await process_frame
	var scale_after_frames: Vector3 = (view.unit_nodes["rodriguez"] as Node3D).scale
	cam.transform = shell.game_xf
	view.call("_update_scales")  # la escala que corresponde a la cámara del juego
	var wanted: Vector3 = (view.unit_nodes["rodriguez"] as Node3D).scale
	shell.remove_child(view)
	root.add_child(view)
	shell.queue_free()
	await process_frame
	# visual/r1 F1: las fichas ya no crecen con la distancia; con cualquier orden de cámaras su escala es la fija de units.marks.figure_scale
	var fig := float(((visual.get("units", {}) as Dictionary).get("marks", {}) as Dictionary).get("figure_scale", 1.0))
	_ck(scale_after_frames.is_equal_approx(wanted) and (label != "real" or is_equal_approx(wanted.y, fig)), "I-R1.0-3 / visual/r1 F1 tras un cuadro con el orden real (cámara del menú y la del juego después) la ficha tiene la escala fija %.2f (%.2f contra %.2f)" % [fig, scale_after_frames.y, wanted.y])
	_frame_camera(cam, f)


# ---------------------------------------------------------------------------------------------------------------------
# TR-098 · siluetas distintas (el alto en pantalla, ≥ 48 px reales, se mide con ventana en tools/vis_humahuaca.gd: sin ventana no hay escala de pantalla)

func _test_archetypes_grayscale() -> void:
	if view == null:
		return
	_frame_camera(cam, view.initial_frame(cam))
	view.update_state(0.016)
	# visual/r1 F1 (revierte V03 de R1 a propósito, plan aprobado por el usuario): las fichas van a escala real y no se estiran hasta ≥ 48 px; de lejos se las
	# encuentra por la marca chica y el rótulo de la interfaz. En la vista real: escala = units.marks.figure_scale y el anillo del suelo prueba profundidad.
	if label == "real":
		var fig := float(((visual.get("units", {}) as Dictionary).get("marks", {}) as Dictionary).get("figure_scale", 1.0))
		var off: Array = []
		var depth_ok := true
		for id in V.GROUPS:
			var node_s: Node3D = view.unit_nodes[id]
			if not node_s.scale.is_equal_approx(Vector3.ONE * fig):
				off.append("%s %.2f" % [id, node_s.scale.y])
			var ring_mi := node_s.get_node_or_null("anillo") as MeshInstance3D
			var mat := ring_mi.material_override as BaseMaterial3D if ring_mi != null else null
			depth_ok = depth_ok and mat != null and not mat.no_depth_test and ring_mi.mesh != null
		_ck(off.is_empty(), "visual/r1 F1 con el cuadro inicial cada ficha tiene la escala fija %.2f (no crece con la distancia)%s" % [fig, "" if off.is_empty() else ": " + str(off)])
		_ck(depth_ok, "visual/r1 F1 el anillo de bando de cada ficha está armado y respeta la profundidad (lo tapan los edificios)")
	var dims := {}
	for id in V.GROUPS:
		var node_i: Node3D = view.unit_nodes[id]
		var box := _node_bounds(node_i)
		# medidas nominales (dividido por la escala de la ficha)
		dims[id] = Vector2(maxf(box.size.x, box.size.z) / maxf(node_i.scale.x, 0.001), (box.end.y - node_i.global_position.y) / maxf(node_i.scale.y, 0.001))
	var distinct := true
	var worst := 9.0
	for a in range(V.GROUPS.size()):
		for b in range(a + 1, V.GROUPS.size()):
			var ra := (dims[V.GROUPS[a]] as Vector2)
			var rb := (dims[V.GROUPS[b]] as Vector2)
			var difference := absf(ra.x / ra.y - rb.x / rb.y) + absf(ra.y - rb.y) / maxf(ra.y, rb.y)
			worst = minf(worst, difference)
			distinct = distinct and difference > 0.12
	_ck(distinct, "TR-098 las 5 fichas tienen proporciones y alturas distintas de a pares, no son retintes del mismo cuerpo (diferencia mínima %.2f)" % worst)
	var tokens: Dictionary = visual.get("tokens", {})
	var shapes := {}
	for id in V.GROUPS:
		shapes[str((tokens.get(id, {}) as Dictionary).get("shape", ""))] = true
	_ck(shapes.size() == 5 and shapes.keys().all(func(k): return VV.TOKEN_SHAPES.has(k)), "TR-098 cada agrupación tiene su forma propia del vocabulario (%s)" % str(shapes.keys()))
	# visual/r1 F1: el anillo de bando es fino y de radio real (no el estirón a 48–72 px de R1 y P2)
	var marks: Dictionary = (visual.get("units", {}) as Dictionary).get("marks", {})
	var r_m := float(marks.get("ring_radius_m", 0.0))
	var w_m := float(marks.get("ring_width_m", 9.0))
	_ck(label != "real" or (r_m >= 1.0 and r_m <= 5.0 and w_m > 0.0 and w_m <= 0.6), "visual/r1 F1 units.marks: anillo de radio real (%.1f m, entre 1 y 5) y fino (%.2f m, ≤ 0,6)" % [r_m, w_m])
	var node: Node3D = view.unit_nodes["rodriguez"]
	_ck(node.get_child_count() >= 8 and not (node.get_child(0) is Sprite3D), "TR-098 la ficha es una figura de varias piezas, no un disco ni una imagen plana")


# ---------------------------------------------------------------------------------------------------------------------
# TR-099 · albedo y sondas para las métricas del QA

func _test_albedo_and_probes() -> void:
	if view == null:
		return
	var f: Dictionary = view.initial_frame(cam)
	_frame_camera(cam, f)
	view.update_state(0.016)
	var probes: Array = view.probes(cam)
	var kinds := {}
	var shaped := true
	for p in probes:
		kinds[str(p.kind)] = int(kinds.get(str(p.kind), 0)) + 1
		var r: Array = p.rect
		shaped = shaped and VV.PROBE_KINDS.has(str(p.kind)) and r.size() == 4 and float(r[2]) > 0.0 and float(r[3]) > 0.0
	_ck(shaped and kinds.has("ficha") and kinds.has("objetivo") and kinds.has("suelo"), "TR-099 probes devuelve rectángulos de ficha, objetivo y suelo bien formados (%s)" % str(kinds))
	var env := (view.get_node("Ambiente") as WorldEnvironment).environment
	view.set_albedo_mode(true)
	_ck(not env.fog_enabled and env.tonemap_mode == Environment.TONE_MAPPER_LINEAR and not (view.get_node("Sol") as DirectionalLight3D).shadow_enabled, "TR-099 set_albedo_mode(true) apaga niebla, sombras y curva de tonos")
	var unshaded := true
	for mi in view.find_children("hito_*", "Node3D", true, false):
		for m in mi.find_children("*", "MeshInstance3D", true, false):
			var mat := (m as MeshInstance3D).material_override
			if mat is StandardMaterial3D and (mat as StandardMaterial3D).transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
				unshaded = unshaded and (mat as StandardMaterial3D).shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
	_ck(unshaded, "TR-099 en el modo albedo los materiales de los edificios quedan sin sombreado")
	view.set_albedo_mode(false)
	_ck(env.fog_enabled, "TR-099 set_albedo_mode(false) devuelve la niebla")


# ---------------------------------------------------------------------------------------------------------------------
# Capas, selección y efectos

func _test_dynamic_api() -> void:
	if view == null:
		return
	for layer in VV.LAYERS:
		view.set_layer_visible(layer, false)
		var off: bool = not view.layer_visible(layer)
		view.set_layer_visible(layer, true)
		_ck(off and view.layer_visible(layer), "3.4 la capa «%s» se apaga y se enciende" % layer)
	view.set_layer_visible("no_existe", true)
	_ck(not view.layer_visible("no_existe"), "3.4 una capa que no existe se ignora")
	view.set_selected_ids(["portal", "arias"])
	view.update_state(0.016)
	var shown: Array = []
	for id in V.GROUPS:
		if (view.unit_nodes[id] as Node3D).get_node("seleccion").visible:
			shown.append(id)
	_ck(shown == ["portal", "arias"] and view.selected_ids == ["portal", "arias"], "3.4 set_selected_ids marca solo las fichas elegidas (%s)" % str(shown))
	view.set_selected_ids([])
	var holder := view.get_node("Efectos") as Node3D
	for kind in VV.FX_KINDS:
		view.fx(kind, Vector2(450.0, 325.0), {})
	_ck(holder.get_child_count() == VV.FX_KINDS.size(), "3.4 fx crea un efecto por cada uno de los 7 tipos (%d)" % holder.get_child_count())
	view.fx("tipo_inexistente", Vector2(0.0, 0.0), {})
	_ck(holder.get_child_count() == VV.FX_KINDS.size(), "3.4 fx ignora un tipo que no existe")
	for _i in range(100):
		view.fx("fogonazo", Vector2(400.0, 300.0), {})
	_ck(holder.get_child_count() <= 24, "3.4 los efectos simultáneos tienen tope según la calidad (%d)" % holder.get_child_count())
	view.update_state(10.0)
	_ck(holder.get_child_count() == 0, "3.4 los efectos se liberan solos al terminar su vida")
	var info: Dictionary = view.get_landmark_info("bateria")
	_ck(str(info.get("id", "")) == "bateria" and info.has("tag") and info.has("y") and (view.get_landmark_info("no_existe") as Dictionary).is_empty(), "3.4 get_landmark_info devuelve el hito con etiqueta y cota, y {} si no existe")
	var minimap_signals := [0]
	view.minimap_changed.connect(func(): minimap_signals[0] += 1)
	view.build(rules, "media")
	_ck(minimap_signals[0] == 1, "3.4 build emite minimap_changed")
	view.set_time_override(-1.0, 0.0)


# ---------------------------------------------------------------------------------------------------------------------
# CONTRATO 7 · degradación elegante: sin reglas ni terreno la vista no se cae

func _test_degraded() -> void:
	var lone := (load(view_path) as GDScript).new() as Node3D
	root.add_child(lone)
	lone.build(null, "media")
	lone.update_state(0.016)
	var f: Dictionary = lone.initial_frame(cam)
	_ck(f.has_all(["target", "distance", "pitch_deg", "yaw_deg", "fits"]) and not bool(f.fits), "7 sin reglas ni terreno la vista construye y su cuadro inicial dice que no entra nada (fits = false)")
	_ck(str(lone.pick_unit(cam, Vector2(100.0, 100.0))) == "" and (lone.landmark_labels(cam) as Array).is_empty() and (lone.get_minimap_texture(Vector2i(64, 48)) as Texture2D) != null, "7 sin reglas ni terreno el picking, los rótulos y el minimapa devuelven valores válidos")
	lone.free()
	var bad := (load(view_path) as GDScript).new() as Node3D
	root.add_child(bad)
	bad.build(rules, "calidad_inventada")
	_ck(bad.get_child_count() >= 3, "7 una calidad desconocida se trata como «media»")
	bad.free()


# ---------------------------------------------------------------------------------------------------------------------
# R1 · lo propio de la vista real: terreno continuo con un solo shader, templo, batería, arquetipos, luces, lluvia, calidad y presupuestos

const REAL_SCRIPTS := ["humahuaca_view", "humahuaca_gfx", "humahuaca_buildings", "humahuaca_units", "humahuaca_fx", "humahuaca_gen"]
const REAL_SHADERS := ["humahuaca_terrain", "humahuaca_props", "humahuaca_water", "humahuaca_rain"]


func _test_real_view() -> void:
	var script := Fx.load_script(view_path)
	if script == null:
		return
	# archivos: partidos por responsabilidad, ≤ 1 500 líneas cada uno (1 600 falla), con tabuladores y sin class_name
	for name_ in REAL_SCRIPTS:
		var text := Fx.read_text("res://scripts/humahuaca/view/%s.gd" % name_)
		var lines := text.split("\n").size()
		_ck(lines <= 1500 and text.find("class_name") < 0 and text.find("\r") < 0 and text.find("\n    ") < 0, "B-022 %s.gd tiene %d líneas (≤ 1 500), usa tabuladores y LF y no declara class_name" % [name_, lines])
	for name_ in REAL_SHADERS + ["humahuaca_noise"]:
		var ext := ".gdshaderinc" if name_ == "humahuaca_noise" else ".gdshader"
		var text := Fx.read_text("res://shaders/%s%s" % [name_, ext])
		_ck(text.length() > 200 and text.find("#include \"res://shaders/justina_") < 0 and text.find("\r") < 0, "TR-091 el shader %s existe, no incluye justina_noise y está en LF" % name_)
	var terrain_text := Fx.read_text("res://shaders/humahuaca_terrain.gdshader")
	_ck(terrain_text.find("humahuaca_noise.gdshaderinc") >= 0 and Fx.read_text("res://shaders/humahuaca_noise.gdshaderinc").find("PROCEDENCIA") >= 0, "TR-091 el shader del suelo incluye la copia del ruido, que declara su procedencia")
	var proj := Fx.read_text("res://project.godot")
	_ck(proj.find("shader_globals") < 0 and proj.find("global_shader_parameters") < 0, "TR-091 nada de shader_globals ni de ajustes de render para el nivel en project.godot")
	cam = _make_camera(root)
	view = script.new()
	root.add_child(view)
	view.build(rules, "media")
	view.update_state(0.016)
	# terreno: un solo material de suelo para ventana, contexto y horizonte, y una malla continua de punta a punta
	var ground := view.get_node("Terreno") as Node3D
	var materials := {}
	var union := AABB()
	var first := true
	var names: Array = []
	for child in ground.get_children():
		var mi := child as MeshInstance3D
		materials[mi.material_override] = true
		names.append(str(mi.name))
		var box := mi.mesh.get_aabb()
		union = box if first else union.merge(box)
		first = false
	var shared := materials.size() == 1 and materials.keys()[0] is ShaderMaterial
	_ck(shared and ((materials.keys()[0] as ShaderMaterial).shader.resource_path.ends_with("humahuaca_terrain.gdshader")), "TR-091 ventana, contexto y horizonte comparten UN solo material (el shader del suelo): %s" % str(names))
	_ck(names.has("terreno_ventana") and names.has("terreno_horizonte") and names.has("terreno_contexto_oeste") and names.has("terreno_contexto_este") and names.has("terreno_contexto_norte") and names.has("terreno_contexto_sur"), "TR-091 el terreno tiene ventana, cuatro bandas de contexto y horizonte")
	_ck(names.has("terreno_costura_oeste") and names.has("terreno_costura_este") and names.has("terreno_costura_norte") and names.has("terreno_costura_sur"), "TR-091 la ventana y el contexto se unen con cuatro costuras que comparten los vértices del borde de la ventana (H-R1-11)")
	_ck(union.position.x <= -7000.0 and union.end.x >= 8000.0 and union.position.z <= -7000.0 and union.end.z >= 7000.0, "TR-091 la malla llega hasta ≈ 8 km en los cuatro lados (de %s a %s)" % [str(union.position), str(union.end)])
	var stats: Dictionary = (view.content_report as Dictionary).get("terreno", {})
	_ck(int(stats.get("triangulos", 0)) > 60000 and int(stats.get("triangulos", 0)) < 400000, "TR-091 el terreno tiene un presupuesto de triángulos razonable (%d)" % int(stats.get("triangulos", 0)))
	_ck(_terrain_has_no_cracks(ground), "TR-091 los bordes de la ventana y de las bandas del contexto coinciden (sin grietas)")
	# el shader compila (en headless se detecta el identificador desconocido; el resto lo prueba la corrida con ventana)
	var mat := materials.keys()[0] as ShaderMaterial
	_ck(mat.shader != null and mat.shader.code.length() > 500 and (mat.get_shader_parameter("splat_a") is Texture2D) and (mat.get_shader_parameter("splat_b") is Texture2D) and (mat.get_shader_parameter("ctx_tex") is Texture2D), "TR-091 el material del suelo trae el shader y sus tres texturas de pesos")
	# batería: una losa con parapeto y piezas bajas, nunca un fuste (B-023)
	var bateria := view.get_node_or_null("Hitos/hito_bateria") as Node3D
	if _ck(bateria != null, "B-023 la batería existe como nodo"):
		var box_b := _node_bounds(bateria)
		var floor_y := float(rules.call("terrain").call("height_at", 318.0, 350.0))
		_ck(box_b.end.y - floor_y <= 3.0 and box_b.size.x >= 26.0, "B-023 la batería mide ≤ 3 m sobre el suelo y ≥ 26 m de ancho: losa, no fuste (%.2f m de alto, %.1f m de ancho)" % [box_b.end.y - floor_y, box_b.size.x])
		var tall := 0
		for mi in bateria.find_children("*", "MeshInstance3D", true, false):
			var local_box := (mi as MeshInstance3D).get_aabb()
			if local_box.size.y > 3.2 and local_box.size.y > 1.5 * maxf(local_box.size.x, local_box.size.z):
				tall += 1
		_ck(tall == 0, "B-023 ninguna pieza de la batería es una columna más alta que ancha")
	# tapias de la posta: salen de terrain.features("tapia"), no del edificio
	var features: Array = rules.call("terrain").call("features", "tapia")
	var tapias := view.get_node_or_null("Rasgos/tapias") as MeshInstance3D
	_ck(tapias != null and features.size() >= 12 and tapias.mesh.get_surface_count() == 1, "TR-091 las %d tapias del terreno se dibujan en una sola malla (la posta no inventa entradas propias)" % features.size())
	var posta := view.get_node_or_null("Hitos/hito_posta") as Node3D
	var posta_walls := 0
	if posta != null:
		for mi in posta.find_children("*", "MeshInstance3D", true, false):
			if str((mi as MeshInstance3D).name).begins_with("muro"):
				posta_walls += 1
	_ck(posta != null and posta_walls == 0, "TR-091 el nodo de la posta no trae muros propios")
	# luces: las de los tres objetivos, con resplandor, mancha de luz en el suelo y llama
	var lights := view.get_node("Luces") as Node3D
	var kinds := {}
	for l in lights.get_children():
		kinds[str(l.name)] = [l.get_node_or_null("resplandor") != null, l.get_node_or_null("mancha") != null]
	_ck(kinds.size() >= 3 and kinds.values().all(func(v): return v[0] and v[1]), "TR-097 cada luz de la guardia trae resplandor y mancha de luz en el suelo (%s)" % str(kinds.keys()))
	# lluvia: rayas en el espacio de la cámara con calidad media, ninguna con la baja
	var rain_holder := view.get_node("Lluvia") as Node3D
	_ck(rain_holder.get_child_count() == 1 and ((rain_holder.get_child(0) as MultiMeshInstance3D).multimesh.instance_count >= 500), "TR-097 con calidad media hay un MultiMesh de rayas de lluvia (%d)" % int((rain_holder.get_child(0) as MultiMeshInstance3D).multimesh.instance_count))
	# dibujo según el estado: defensores, torre, fogatas
	var dressed: RefCounted = Vis.DressedRules.new(Fx.rules_stub(1817, 1, {"skip_intro": true, "phase": "ataque"}), "ataque")
	view.build(dressed, "media")
	view.update_state(0.016)
	var enemies: int = view.get_node("Defensores").get_child_count()
	var tower := view.get_node_or_null("Hitos/hito_torre_casa_cura") as Node3D
	_ck(enemies >= 8 and tower != null and tower.visible and view.get_node("Luces").get_child_count() >= 5, "TR-097 con defensores, torre y fogatas en el estado la vista los dibuja (%d defensores, torre visible: %s, %d luces)" % [enemies, str(tower != null and tower.visible), view.get_node("Luces").get_child_count()])
	if tower != null:
		var tbox := _node_bounds(tower)
		_ck(tbox.size.y >= 9.0 and tbox.size.y <= 11.5, "TR-094 la torre provisional mide ≈ 10 m (%.1f m) y es la única pieza vertical del núcleo" % tbox.size.y)
	# calidad: baja < media ≤ alta en triángulos y nodos; sin lluvia en la baja
	var counts := {}
	for q in VV.QUALITY:
		view.build(rules, q)
		counts[q] = [int((view.content_report as Dictionary).get("terreno", {}).get("triangulos", 0)), view.find_children("*", "", true, false).size(), view.get_node("Lluvia").get_child_count()]
	_ck(int(counts.baja[0]) < int(counts.media[0]) and int(counts.baja[2]) == 0 and int(counts.alta[2]) == 1, "TR-091 la calidad baja arma menos terreno que la media y no dibuja lluvia (%s)" % str(counts))
	view.build(rules, "media")
	suite.extra["calidad"] = counts
	suite.extra["contenido"] = view.content_report
	suite.extra["construccion_por_etapa_ms"] = view.build_stages_ms
	# modo albedo: los shaders pasan a color plano y las luces y la lluvia se apagan
	view.set_albedo_mode(true)
	var ground_mat := (view.get_node("Terreno/terreno_ventana") as MeshInstance3D).material_override as ShaderMaterial
	var albedo_on := float(ground_mat.get_shader_parameter("albedo_mode")) > 0.5
	_ck(albedo_on and not (view.get_node("Luces") as Node3D).visible and not (view.get_node("Lluvia").get_child(0) as Node3D).visible, "TR-099 set_albedo_mode(true) pasa los shaders a color plano y apaga luces y lluvia")
	view.set_albedo_mode(false)
	_test_token_px_any_camera()
	_test_upright_scale_grid()
	view.free()
	view = null
	cam.free()
	cam = null
	await process_frame
	_test_five_starts()
	_test_archetype_luminance()
	_test_yaw_data()


## V03 con cualquier cámara: la vista corrige la escala de las fichas con la proyección de verdad (el pie y la cabeza con la cámara que se dibuja), así que las que entran
## en el cuadro miden ≥ 48 px de alto con el rumbo del diseño, con el espejo que arma hoy el controlador, más empinadas y rasantes, y también cerca del borde de abajo
## (la estimación sola, por el seno del ángulo, dejaba a la ficha del jinete en 44 px en el cuadro de la escena real).
func _test_token_px_any_camera() -> void:
	var poses := {
		"rumbo 325° a 52°": {"yaw_deg": 325.0, "pitch_deg": 52.0, "distance": 470.0},
		"rumbo 35° (el espejo del controlador)": {"yaw_deg": 35.0, "pitch_deg": 52.0, "distance": 470.0},
		"más empinada, a 62°": {"yaw_deg": 90.0, "pitch_deg": 62.0, "distance": 330.0},
		"rasante, a 20°": {"yaw_deg": 180.0, "pitch_deg": 20.0, "distance": 160.0},
	}
	var raw_scale := cam.get_viewport().get_screen_transform().get_scale().y
	var scale_px := raw_scale if raw_scale >= 0.2 else 1.0
	var frame := Rect2(Vector2.ZERO, cam.get_viewport().get_visible_rect().size).grow(-4.0)
	var centroid := Vector3.ZERO
	for id in V.GROUPS:
		centroid += (view.unit_nodes[id] as Node3D).global_position / float(V.GROUPS.size())
	for key in poses:
		for shifted in [false, true]:  # con el objetivo corrido 100 m hacia adelante las fichas bajan hacia el borde de abajo del cuadro
			var f: Dictionary = (poses[key] as Dictionary).duplicate()
			var yaw := deg_to_rad(float(f.yaw_deg))
			f["target"] = centroid + (Vector3(sin(yaw), 0.0, -cos(yaw)) * 100.0 if shifted else Vector3.ZERO)
			_frame_camera(cam, f)
			view.update_state(0.016)
			var seen := 0
			var short: Array = []
			for id in V.GROUPS:
				var node: Node3D = view.unit_nodes[id]
				var base := cam.unproject_position(node.global_position)
				if cam.is_position_behind(node.global_position) or not frame.has_point(base):
					continue
				seen += 1
				var top_world := node.global_position.y
				for part in node.find_children("*", "MeshInstance3D", true, false):
					if not (str(part.name) in ["anillo", "borde", "seleccion"]):
						top_world = maxf(top_world, ((part as MeshInstance3D).global_transform * (part as MeshInstance3D).get_aabb()).end.y)
				var h_px := absf(base.y - cam.unproject_position(Vector3(node.global_position.x, top_world, node.global_position.z)).y) * scale_px
				if h_px <= 0.5 or not node.scale.is_equal_approx(Vector3.ONE * float(((visual.get("units", {}) as Dictionary).get("marks", {}) as Dictionary).get("figure_scale", 1.0))):
					short.append("%s %.1f px (escala %.2f)" % [id, h_px, node.scale.y])
			# visual/r1 F1: con cualquier cámara la ficha conserva su escala fija (antes se exigían ≥ 47 px, el estirón que se revirtió a propósito)
			_ck(seen >= 1 and short.is_empty(), "visual/r1 F1 con la cámara «%s»%s las %d fichas que entran en el cuadro conservan su escala fija y se dibujan%s" % [key, " (objetivo corrido)" if shifted else "", seen, "" if short.is_empty() else ": " + str(short)])
	# casi cenital (78°): de arriba no se ve la altura de una figura, así que la ficha se achica y el estirón queda acotado (nada de trazos largos hacia el nadir)
	_frame_camera(cam, {"yaw_deg": 90.0, "pitch_deg": 78.0, "distance": 330.0, "target": centroid})
	view.update_state(0.016)
	var worst_stretch := 0.0
	for id in V.GROUPS:
		var sc := (view.unit_nodes[id] as Node3D).scale
		worst_stretch = maxf(worst_stretch, sc.y / maxf(sc.x, 0.001))
	_ck(worst_stretch <= 2.3, "V03 con la cámara a 78° el estirón de las fichas queda en ≤ 2,3 veces (%.2f): de arriba no se ve la altura y no se las estira hasta un trazo" % worst_stretch)


## `upright_scale` sobre una grilla de 5 × 5 posiciones del cuadro (con el rumbo espejado y el del diseño): lo que se proyecta de verdad (el pie y la cabeza con la cámara) mide el
## alto pedido más el 3 % de margen, también en las esquinas, donde la estimación por el seno del ángulo se queda corta (el jinete de la escena real medía 44 px de 58).
func _test_upright_scale_grid() -> void:
	var raw_scale := cam.get_viewport().get_screen_transform().get_scale().y
	var scale_px := raw_scale if raw_scale >= 0.2 else 1.0
	var size := cam.get_viewport().get_visible_rect().size
	for yaw in [35.0, 325.0]:
		var f := {"yaw_deg": yaw, "pitch_deg": 52.0, "distance": 492.0, "target": Vector3(357.5, 17.0, 459.0)}
		_frame_camera(cam, f)
		var worst := 1.0e9
		var best := 0.0
		var count := 0
		for iy in range(1, 6):
			for ix in range(1, 6):
				var screen := Vector2(size.x * float(ix) / 6.0, size.y * float(iy) / 6.0)
				var ray := cam.project_ray_normal(screen)
				if ray.y > -0.05:
					continue
				var pos := cam.project_ray_origin(screen) + ray * ((17.0 - cam.project_ray_origin(screen).y) / ray.y)
				var sc: Vector3 = view.units.upright_scale(view, cam, pos, 58.0, 2.4, 1.0)
				var h_px := absf(cam.unproject_position(pos).y - cam.unproject_position(pos + Vector3(0.0, 2.4 * sc.y, 0.0)).y) * scale_px
				worst = minf(worst, h_px)
				best = maxf(best, h_px)
				count += 1
		suite.extra["ficha_58px_rumbo_%d" % int(yaw)] = [snappedf(worst, 0.1), snappedf(best, 0.1)]
		_ck(count >= 20 and worst >= 57.5 and best <= 62.0, "V03 con el rumbo %.0f° una ficha de 58 px pedidos mide de %.1f a %.1f px en %d posiciones del cuadro (entre 57,5 y 62)" % [yaw, worst, best, count])


## Las uniones entre la ventana y el contexto: las cuatro costuras (una fila de celdas pegada a cada borde de la ventana) comparten con ella los mismos vértices del borde y con
## la misma altura. El contexto tiene un vértice cada ≈ 30 m, así que antes la malla dibujada saltaba hasta 0,67 m en la costura este (H-R1-11).
func _terrain_has_no_cracks(ground: Node3D) -> bool:
	var window := (ground.get_node("terreno_ventana") as MeshInstance3D).mesh as ArrayMesh
	var wv: PackedVector3Array = window.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var on_edge := func(v: Vector3) -> bool:
		return (absf(v.x) < 0.01 or absf(v.x - 900.0) < 0.01) and v.z > -0.01 and v.z < 652.01 or (absf(v.z) < 0.01 or absf(v.z - 652.0) < 0.01) and v.x > -0.01 and v.x < 900.01
	var edge_heights := {}
	for v in wv:
		if on_edge.call(v):
			var key := Vector2(snappedf(v.x, 1.0), snappedf(v.z, 1.0))
			edge_heights[key] = maxf(float(edge_heights.get(key, -1.0e9)), v.y)  # el vértice de la falda queda 3 m más abajo: vale el de la superficie
	var worst := 0.0
	var checked := 0
	for seam in ["terreno_costura_oeste", "terreno_costura_este", "terreno_costura_norte", "terreno_costura_sur"]:
		var node := ground.get_node_or_null(seam) as MeshInstance3D
		if node == null:
			return false
		var surface := {}
		for v in (node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			if on_edge.call(v):
				var key := Vector2(snappedf(v.x, 1.0), snappedf(v.z, 1.0))
				surface[key] = maxf(float(surface.get(key, -1.0e9)), v.y)  # la falda de la costura cuelga 1 m
		for key in surface:
			if edge_heights.has(key):
				worst = maxf(worst, absf(float(edge_heights[key]) - float(surface[key])))
				checked += 1
	suite.extra["grieta_maxima_m"] = snappedf(worst, 0.001)
	return checked > 600 and worst <= 0.01


## El suelo que se DIBUJA, medido con rayos contra las mallas de `Terreno` (como lo mide el QA, no contra `height_at`): la altura más alta que pega en alguna malla.
func _rendered_top(meshes: Array, x: float, z: float) -> float:
	var top := -1.0e9
	for tm in meshes:
		var hit: Dictionary = (tm as TriangleMesh).intersect_ray(Vector3(x, 4000.0, z), Vector3.DOWN)
		if not hit.is_empty():
			top = maxf(top, float((hit["position"] as Vector3).y))
	return top


## H-R1-11 sobre lo que se dibuja de verdad (con el terreno y las reglas reales): (1) la malla no salta en las cuatro costuras de la ventana ni en el perímetro del contexto (≤ 0,10 m,
## que es el tope de R06; antes 0,674 m en x = 900 y 0,32 m en z = 0); (2) ningún vértice de la cinta del río (agua y lecho) queda bajo el suelo dibujado (antes 9 de 78, hasta
## −4,77 m); (3) la cinta llega hasta el borde del contexto en las dos puntas y no más allá (antes se cortaba en seco dentro del terreno); (4) lo mismo para los caminos y las zanjas.
func _test_terrain_rendered() -> void:
	var rules_script := Fx.load_script(Fx.REAL_PATHS.rules)
	var view_script := Fx.load_script(Fx.REAL_PATHS.view)
	if rules_script == null or view_script == null or Fx.load_script(Fx.REAL_PATHS.terrain) == null:
		suite.pend("H-R1-11", "faltan las clases reales de reglas, terreno o vista", "r1")
		return
	var game_rules: RefCounted = rules_script.new()
	game_rules.call("new_game", 9001, 1, {"skip_intro": true})
	cam = _make_camera(root)
	view = view_script.new()
	root.add_child(view)
	view.build(game_rules, "media")
	view.update_state(0.016)
	var ground := view.get_node("Terreno") as Node3D
	var meshes: Array = []
	for c in ground.get_children():
		meshes.append((c as MeshInstance3D).mesh.generate_triangle_mesh())
	var eps := 0.02
	var edges := {
		"ventana_oeste": [Vector2(0, 0), Vector2(0, 652), Vector2(-eps, 0), Vector2(eps, 0)],
		"ventana_este": [Vector2(900, 0), Vector2(900, 652), Vector2(-eps, 0), Vector2(eps, 0)],
		"ventana_norte": [Vector2(0, 0), Vector2(900, 0), Vector2(0, -eps), Vector2(0, eps)],
		"ventana_sur": [Vector2(0, 652), Vector2(900, 652), Vector2(0, -eps), Vector2(0, eps)],
		"contexto_oeste": [Vector2(-1350, -1025), Vector2(-1350, 1675), Vector2(-eps, 0), Vector2(eps, 0)],
		"contexto_este": [Vector2(2250, -1025), Vector2(2250, 1675), Vector2(-eps, 0), Vector2(eps, 0)],
		"contexto_norte": [Vector2(-1350, -1025), Vector2(2250, -1025), Vector2(0, -eps), Vector2(0, eps)],
		"contexto_sur": [Vector2(-1350, 1675), Vector2(2250, 1675), Vector2(0, -eps), Vector2(0, eps)]}
	var jumps := {}
	var worst_jump := 0.0
	for k in edges:
		var e: Array = edges[k]
		var worst := 0.0
		for i in range(151):
			var p: Vector2 = (e[0] as Vector2).lerp(e[1] as Vector2, float(i) / 150.0)
			var a := _rendered_top(meshes, p.x + (e[2] as Vector2).x, p.y + (e[2] as Vector2).y)
			var b := _rendered_top(meshes, p.x + (e[3] as Vector2).x, p.y + (e[3] as Vector2).y)
			if a > -1.0e8 and b > -1.0e8:
				worst = maxf(worst, absf(a - b))
		jumps[k] = snappedf(worst, 0.001)
		worst_jump = maxf(worst_jump, worst)
	suite.extra["costuras_salto_max_m"] = jumps
	_ck(worst_jump <= 0.10, "H-R1-11 la malla dibujada no salta más de 0,10 m en las cuatro costuras de la ventana ni en el perímetro del contexto (peor %.3f m: %s)" % [worst_jump, str(jumps)])
	# la cinta del río: cada vértice sobre el suelo dibujado
	var ctx_rect := Rect2(-1350.0, -1025.0, 3600.0, 2700.0)
	var river_report := {}
	for node_name in ["rio_agua", "rio_lecho"]:
		var ribbon := view.get_node_or_null("Rasgos/" + node_name) as MeshInstance3D
		if not _ck(ribbon != null, "H-R1-11 la cinta %s existe" % node_name):
			continue
		var verts: PackedVector3Array = ribbon.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var buried := 0
		var lowest := 1.0e9
		var highest := -1.0e9
		for v in verts:
			var top := _rendered_top(meshes, v.x, v.z)
			if top < -1.0e8:
				continue
			buried += 1 if v.y <= top else 0
			lowest = minf(lowest, v.y - top)
			highest = maxf(highest, v.y - top)
		# y también adentro de cada triángulo (el centro y los puntos medios de sus lados): el suelo puede asomar entre dos vértices aunque los dos estén por encima de él
		var idx: PackedInt32Array = ribbon.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
		var inner_n := 0
		var inner_buried := 0
		var inner_low := 1.0e9
		for t in range(0, idx.size(), 3):
			var a: Vector3 = verts[idx[t]]
			var b: Vector3 = verts[idx[t + 1]]
			var c: Vector3 = verts[idx[t + 2]]
			for p in [(a + b + c) / 3.0, (a + b) * 0.5, (b + c) * 0.5]:
				var top_in := _rendered_top(meshes, p.x, p.z)
				if top_in > -1.0e8:
					inner_n += 1
					inner_buried += 1 if p.y <= top_in else 0
					inner_low = minf(inner_low, p.y - top_in)
		river_report[node_name] = {"vertices": verts.size(), "tapados": buried, "peor_dy_m": snappedf(lowest, 0.01), "mayor_dy_m": snappedf(highest, 0.01),
			"puntos_interiores": inner_n, "interiores_tapados": inner_buried, "peor_interior_dy_m": snappedf(inner_low, 0.02)}
		_ck(verts.size() >= 100 and buried == 0 and highest <= 2.5, "H-R1-11 ningún vértice de %s queda bajo el suelo dibujado y ninguno flota a más de 2,5 m (%d vértices, %d tapados, de %.2f a %.2f m sobre el suelo)" % [node_name, verts.size(), buried, lowest, highest])
		_ck(inner_n >= 1000 and inner_buried == 0, "H-R1-11 el suelo tampoco asoma dentro de los triángulos de %s (%d puntos interiores medidos, %d tapados, el más bajo a %.3f m sobre el suelo)" % [node_name, inner_n, inner_buried, inner_low])
		var uvs: PackedVector2Array = ribbon.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
		var row := 1  # vértices por fila a lo ancho (los que comparten el UV.x del primero)
		while row < uvs.size() and is_equal_approx(uvs[row].x, uvs[0].x):
			row += 1
		var first := Vector2(verts[row / 2].x, verts[row / 2].z)  # el centro de la primera fila y de la última
		var last := Vector2(verts[verts.size() - row + row / 2].x, verts[verts.size() - row + row / 2].z)
		var edge_gap := func(p: Vector2) -> float:
			return minf(minf(p.x - ctx_rect.position.x, ctx_rect.end.x - p.x), minf(p.y - ctx_rect.position.y, ctx_rect.end.y - p.y))
		var gaps := [float(edge_gap.call(first)), float(edge_gap.call(last))]
		river_report[node_name]["distancia_de_las_puntas_al_borde_m"] = [snappedf(gaps[0], 0.1), snappedf(gaps[1], 0.1)]
		_ck(gaps[0] >= 0.0 and gaps[0] <= 8.0 and gaps[1] >= 0.0 and gaps[1] <= 8.0, "H-R1-11 la cinta %s llega hasta el borde del contexto en las dos puntas y no pasa de él (a %.1f y %.1f m del borde)" % [node_name, gaps[0], gaps[1]])
	suite.extra["rio_cinta_vs_suelo"] = river_report
	# la punta recortada se apaga (no termina en un corte): la opacidad de los vértices de la punta es 0 y la de la parte de la ventana, 1
	var water := view.get_node_or_null("Rasgos/rio_agua") as MeshInstance3D
	if water != null:
		var colors: PackedColorArray = water.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		var verts_w: PackedVector3Array = water.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var end_alpha := minf(colors[0].a, colors[colors.size() - 1].a)
		var inside_alpha := 0.0
		for i in range(verts_w.size()):
			if verts_w[i].x >= 600.0 and verts_w[i].x <= 880.0 and verts_w[i].z >= 20.0 and verts_w[i].z <= 380.0:
				inside_alpha = maxf(inside_alpha, 1.0 - colors[i].a)
		_ck(end_alpha <= 0.02 and inside_alpha <= 0.001, "H-R1-11 el río se apaga en las puntas recortadas (opacidad %.2f) y es opaco dentro de la ventana (falta %.3f)" % [end_alpha, inside_alpha])
	# caminos y zanjas (las cintas del suelo): ningún vértice bajo el suelo dibujado
	var strips_n := 0
	var strips_buried := 0
	var strips_low := 1.0e9
	for c in (view.get_node("Rasgos") as Node3D).get_children():
		if str(c.name).begins_with("camino_") or str(c.name).begins_with("zanja"):
			for v in ((c as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				var top := _rendered_top(meshes, v.x, v.z)
				if top > -1.0e8:
					strips_n += 1
					strips_buried += 1 if v.y <= top else 0
					strips_low = minf(strips_low, v.y - top)
	suite.extra["cintas_del_suelo"] = {"vertices": strips_n, "tapados": strips_buried, "peor_dy_m": snappedf(strips_low, 0.01)}
	_ck(strips_n >= 200 and strips_buried == 0, "H-R1-11 los caminos y las zanjas no quedan bajo el suelo dibujado (%d vértices, %d tapados, el más bajo a %.2f m sobre el suelo)" % [strips_n, strips_buried, strips_low])
	view.free()
	view = null
	cam.free()
	cam = null
	await process_frame


## H-R1-9: cada figura de una agrupación sigue a su posición lógica CUADRO A CUADRO mientras marcha, a ×1, ×2 y ×4 (antes quedaba quieta hasta el próximo evento y saltaba hasta
## 123 m: la vista solo leía la pose cuando subía la `version` del estado y las reglas mueven a las agrupaciones sin subirla). Con las reglas y la vista reales, avanzando las
## reglas como lo hace el controlador (`tick(dt × velocidad)` y `update_state` en cada cuadro). Los círculos de visibilidad también siguen a las agrupaciones (a ≤ 4 m).
func _test_units_follow_rules() -> void:
	var rules_script := Fx.load_script(Fx.REAL_PATHS.rules)
	var view_script := Fx.load_script(Fx.REAL_PATHS.view)
	if rules_script == null or view_script == null:
		suite.pend("H-R1-9", "faltan las clases reales de reglas o de vista", "r1")
		return
	var out := {}
	for speed in [1.0, 2.0, 4.0]:
		var game_rules: RefCounted = rules_script.new()
		game_rules.call("new_game", 9001, 1, {"skip_intro": true})
		cam = _make_camera(root)
		view = view_script.new()
		root.add_child(view)
		view.build(game_rules, "media")
		view.update_state(0.0)
		var orders := 0
		for id in ["rodriguez", "portal", "arias"]:
			orders += 1 if bool((game_rules.call("issue_order", id, "position") as Dictionary).get("ok", false)) else 0
		for pair in [["reconocedores", Vector2(330.0, 520.0)], ["arreo", Vector2(300.0, 560.0)]]:
			orders += 1 if bool((game_rules.call("issue_order", pair[0], "move", pair[1]) as Dictionary).get("ok", false)) else 0
		var worst_m := 0.0
		var worst_ring := 0.0
		var moved_frames := 0  # cuadros en que se movió alguna figura
		var logic_frames := 0  # cuadros en que se movió alguna agrupación en las reglas
		var before := {}
		var before_logic := {}
		for id in V.GROUPS:
			before[id] = Vector2((view.unit_nodes[id] as Node3D).position.x, (view.unit_nodes[id] as Node3D).position.z)
			var u0: Dictionary = game_rules.call("get_unit", id)
			before_logic[id] = Vector2(float(u0.x), float(u0.z))
		for _frame in range(360):  # 6 s reales a 60 cuadros por segundo
			game_rules.call("tick", speed / 60.0)
			view.update_state(1.0 / 60.0)
			var any_moved := false
			var any_logic := false
			for id in V.GROUPS:
				var u: Dictionary = game_rules.call("get_unit", id)
				var node := view.unit_nodes[id] as Node3D
				worst_m = maxf(worst_m, Vector2(node.position.x - float(u.x), node.position.z - float(u.z)).length())
				var now := Vector2(node.position.x, node.position.z)
				if now.distance_to(before[id]) > 0.001:
					any_moved = true
				before[id] = now
				var now_logic := Vector2(float(u.x), float(u.z))
				if now_logic.distance_to(before_logic[id]) > 0.001:
					any_logic = true
				before_logic[id] = now_logic
			moved_frames += 1 if any_moved else 0
			logic_frames += 1 if any_logic else 0
			var pools: Array = (game_rules.call("render_state") as Dictionary).get("visibility_pools", [])
			var drawn: Array = (view.fxm.ring_state as Dictionary).pools
			if pools.size() == drawn.size():
				for i in range(pools.size()):
					worst_ring = maxf(worst_ring, Vector2(float(pools[i].x) - float(drawn[i].x), float(pools[i].z) - float(drawn[i].z)).length())
		out["x%d" % int(speed)] = {"ordenes": orders, "desfase_max_m": snappedf(worst_m, 0.001), "cuadros_con_figura_movida": moved_frames, "cuadros_con_posicion_logica_movida": logic_frames,
			"circulo_de_visibilidad_desfase_max_m": snappedf(worst_ring, 0.01)}
		_ck(orders >= 4 and logic_frames >= 20 and moved_frames >= logic_frames, "H-R1-9 a ×%d las agrupaciones marchan y la figura se mueve en cada cuadro en que se mueve su agrupación (%d órdenes dadas; agrupaciones movidas en %d de 360 cuadros, figuras movidas en %d; antes 0)" % [int(speed), orders, logic_frames, moved_frames])
		_ck(worst_m <= 1.0, "H-R1-9 a ×%d cada figura queda a ≤ 1 m de su agrupación en todos los cuadros (el peor desfase fue de %.3f m; antes 30,8, 92,5 y 123,4 m)" % [int(speed), worst_m])
		_ck(worst_ring <= 4.0, "H-R1-9 a ×%d los círculos de visibilidad siguen a las agrupaciones a ≤ 4 m (el peor desfase fue de %.2f m)" % [int(speed), worst_ring])
		view.free()
		view = null
		cam.free()
		cam = null
		await process_frame
	suite.extra["figuras_siguen_a_las_reglas"] = out


## El cuadro inicial (rumbo 325° desde A-11) deja las cinco partidas a ≥ 5 % del borde en las cuatro resoluciones, abriéndose solo un paso del 4 % si hace falta.
func _test_five_starts() -> void:
	var script := Fx.load_script(view_path)
	cam = _make_camera(root)
	view = script.new()
	root.add_child(view)
	view.build(rules, "media")
	var sizes := {"1024x640": Vector2i(1024, 640), "1280x720": Vector2i(1280, 720), "1920x1080": Vector2i(1920, 1080), "2560x1440": Vector2i(2560, 1440)}
	var summary := {}
	for key in sizes:
		var sub := SubViewport.new()
		sub.size = sizes[key]
		sub.render_target_update_mode = SubViewport.UPDATE_DISABLED
		root.add_child(sub)
		var c := Camera3D.new()
		c.fov = 46.0
		c.far = 9000.0
		sub.add_child(c)
		var f: Dictionary = view.initial_frame(c)
		_frame_camera(c, f)
		var worst := 1000.0
		for id in ["bateria", "cuartel", "posta", "zona_partida", "spawn_rodriguez", "spawn_portal", "spawn_arias", "spawn_reconocedores", "spawn_arreo"]:
			var info: Dictionary = view.get_landmark_info(id)
			var at := Vector3(float(info.x), float(info.y), float(info.z))
			var p := c.unproject_position(at)
			var margin := minf(minf(p.x, float(sizes[key].x) - p.x) / float(sizes[key].x), minf(p.y, float(sizes[key].y) - p.y) / float(sizes[key].y)) * 100.0
			worst = minf(worst, -1000.0 if c.is_position_behind(at) else margin)
		summary[key] = {"distancia_m": snappedf(float(f.distance), 0.1), "peor_margen_pct": snappedf(worst, 0.1)}
		_ck(bool(f.fits) and worst >= 4.9, "A-11 a %s el cuadro inicial (%.1f m) deja los tres objetivos, la zona y las cinco partidas a ≥ 5 %% del borde (el peor, %.1f %%)" % [key, float(f.distance), worst])
		sub.free()
	suite.extra["cuadro_inicial"] = summary
	view.free()
	view = null
	cam.free()
	cam = null


## La luminosidad L* (CIELAB) media del color de cada arquetipo, ponderada por el área de los triángulos y sin contar el contorno ni lo tapado: el contorno y la luz la
## corren, pero la separación entre pares tiene que existir en el color mismo. El render de verdad (a 48 px, con contorno) lo mide tools/vis_humahuaca.gd --hero.
func _test_archetype_luminance() -> void:
	var Gen = load("res://scripts/humahuaca/view/humahuaca_gen.gd")
	var palette := {}
	for entry in visual.get("palette", []):
		palette[str(entry.id)] = Color(str(entry.hex))
	var gen = Gen.new(palette)
	var means := {}
	var units: Dictionary = visual.get("units", {})
	var specs := {"realista_1817": units.get("realista_1817", {})}
	for a in units.get("archetypes", []):
		specs[str(a.id)] = a
	for id in ["poncho_sombrero", "camisa_gorra", "artillero", "realista_1817"]:
		var parts: Dictionary = gen.figure(id, gen.archetype_variant(specs[id]), "de_pie", 0.0)
		var sum := 0.0
		var area := 0.0
		for key in parts:
			var arrays: Array = (parts[key] as ArrayMesh).surface_get_arrays(0)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for t in range(0, idx.size(), 3):
				var tri_area := ((verts[idx[t + 1]] - verts[idx[t]]).cross(verts[idx[t + 2]] - verts[idx[t]])).length() * 0.5
				var c := (cols[idx[t]] + cols[idx[t + 1]] + cols[idx[t + 2]]) / 3.0
				var l := Color(c.r, c.g, c.b).srgb_to_linear()
				var y := 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b
				var f := pow(y, 1.0 / 3.0) if y > 0.008856 else 7.787 * y + 16.0 / 116.0
				sum += (116.0 * f - 16.0) * tri_area
				area += tri_area
		means[id] = sum / maxf(area, 0.0001)
	var ids: Array = means.keys()
	var worst := 1000.0
	for i in range(ids.size()):
		for j in range(i + 1, ids.size()):
			worst = minf(worst, absf(float(means[ids[i]]) - float(means[ids[j]])))
	suite.extra["luminosidad_arquetipos_L"] = {"poncho_sombrero": snappedf(float(means.poncho_sombrero), 0.1), "camisa_gorra": snappedf(float(means.camisa_gorra), 0.1), "artillero": snappedf(float(means.artillero), 0.1), "realista_1817": snappedf(float(means.realista_1817), 0.1)}
	_ck(worst >= 8.0, "V03 los arquetipos y el realista tienen colores de luminosidad distinta de a pares (ΔL* mínimo %.1f en el color; el render a 48 px se mide con --hero)" % worst)


## El rumbo es el de la mirada (A-11): initial_frame, juego_noche y juego_alba traen 325°; las demás vistas no cambian.
func _test_yaw_data() -> void:
	var yaw := float((visual.get("initial_frame", {}) as Dictionary).get("yaw_deg", -1.0))
	var same := true
	for entry in visual.get("canonical_views", []):
		if str(entry.id) in ["juego_noche", "juego_alba"]:
			same = same and is_equal_approx(float(entry.yaw_deg), yaw)
	_ck(is_equal_approx(yaw, 325.0) and same, "A-11 initial_frame, juego_noche y juego_alba traen el rumbo 325° (la mirada al noroeste); hoy initial_frame.yaw_deg = %.0f°" % yaw)
	var ids: Array = ((visual.get("initial_frame", {}) as Dictionary).get("must_include", []) as Array)
	_ck(ids.has("spawn_arreo") and ids.has("spawn_arias") and ids.has("spawn_portal") and ids.has("spawn_rodriguez") and ids.has("spawn_reconocedores"), "A-11 el cuadro inicial exige las cinco partidas además de los tres objetivos y la zona")


## B-026 y B-034: el rectángulo de cada ficha en `probes` mide el alto que se DIBUJA (en píxeles lógicos: por la escala de la ventana da el alto de la captura, ≥ 48 px) y cada
## sonda dice si cae entera dentro del cuadro (una ficha más allá del borde sale marcada, no como un rectángulo de miles de píxeles). B-047: la escala contra la cámara se mide
## una vez por cada cámara distinta y no dos por cuadro (el controlador llama a `update_state` y el `_process` de la vista llega con la misma cámara).
func _test_probes_and_scales() -> void:
	var script := Fx.load_script(view_path)
	if script == null:
		return
	cam = _make_camera(root)
	view = script.new()
	root.add_child(view)
	view.build(rules, "media")
	var f: Dictionary = view.initial_frame(cam)
	_frame_camera(cam, f)
	view.update_state(0.016)
	var frame := root.get_visible_rect()
	var scale_y := float(root.get_screen_transform().get_scale().y)
	if scale_y < 0.2:  # sin ventana de verdad la escala de la pantalla no significa nada (la vista hace lo mismo)
		scale_y = 1.0
	var fichas := 0
	var worst_diff := 0.0
	var lowest_px := 1.0e9
	var consistent := true
	for p in (view.probes(cam) as Array):
		var rect := Rect2(float(p.rect[0]), float(p.rect[1]), float(p.rect[2]), float(p.rect[3]))
		consistent = consistent and p.has("on_screen") and bool(p.on_screen) == Rect2(Vector2.ZERO, frame.size).encloses(rect)
		if str(p.kind) == "ficha":
			fichas += 1
			var node := view.unit_nodes[str(p.id)] as Node3D
			var base := cam.unproject_position(node.global_position)
			var top := cam.unproject_position(view.call("_unit_top", str(p.id)))
			worst_diff = maxf(worst_diff, absf(rect.size.y - absf(base.y - top.y)))
			lowest_px = minf(lowest_px, rect.size.y * scale_y)
	_ck(fichas == 5 and consistent, "B-034 cada sonda trae «on_screen» y coincide con que su rectángulo caiga entero dentro del cuadro (%d fichas)" % fichas)
	_ck(worst_diff <= 1.0 and lowest_px > 0.0, "B-026 el rectángulo de la ficha mide el alto dibujado (a ≤ 1 px; visual/r1 F1: ya no se exige ≥ 48 px, la más baja mide %.1f px)" % lowest_px)
	var looking_away := {"target": Vector3(350.0, 20.0, 470.0), "distance": 300.0, "pitch_deg": 35.0, "yaw_deg": 145.0}  # mira al sudeste: las partidas quedan detrás de la cámara
	_frame_camera(cam, looking_away)
	view.update_state(0.016)
	var behind_ok := true
	for p in (view.probes(cam) as Array):
		var rect := Rect2(float(p.rect[0]), float(p.rect[1]), float(p.rect[2]), float(p.rect[3]))
		behind_ok = behind_ok and bool(p.on_screen) == Rect2(Vector2.ZERO, frame.size).encloses(rect) and absf(rect.size.y) < 4000.0
	_ck(behind_ok, "B-034 con la cámara mirando para otro lado, lo que queda afuera sale marcado «on_screen: false» y ninguna sonda trae un rectángulo disparatado")
	# B-047: una medición por cámara distinta
	_frame_camera(cam, f)
	view.update_state(0.016)
	var n0: int = view.scale_updates
	view.update_state(0.016)
	view._process(0.016)
	view.update_state(0.016)
	_ck(view.scale_updates == n0, "B-047 con la cámara quieta y nada movido la escala no se vuelve a medir (%d mediciones)" % (view.scale_updates - n0))
	cam.position += Vector3(2.0, 0.0, 0.0)
	view.update_state(0.016)
	view._process(0.016)
	_ck(view.scale_updates == n0 + 1, "B-047 con la cámara movida la escala se mide una vez, aunque lleguen update_state y el _process de la vista (%d mediciones)" % (view.scale_updates - n0))
	view.free()
	view = null
	cam.free()
	cam = null
	await process_frame


# ---------------------------------------------------------------------------------------------------------------------
# visual/r1 F3 · formaciones según la cantidad de hombres (MultiMesh), anillo que encierra la huella, menos figuras con menos fuerza o de lejos, defensores a escala real

func _test_formations() -> void:
	var script := Fx.load_script(view_path)
	if script == null:
		return
	cam = _make_camera(root)
	view = script.new()
	root.add_child(view)
	view.build(rules, "media")
	_frame_camera(cam, view.initial_frame(cam))
	view.update_state(0.016)
	var u = view.units
	# 1) la copia de hombres de la vista (la vista solo lee su JSON y render_state) coincide con las reglas y va etiquetada diseño
	var groups: Dictionary = V.load_json(V.RULES_PATH).get("groups", {})
	var copy: Dictionary = ((visual.get("units", {}) as Dictionary).get("formation", {}) as Dictionary).get("groups", {})
	var off: Array = []
	for id in V.GROUPS:
		var g: Dictionary = groups.get(id, {})
		var c: Dictionary = copy.get(id, {})
		if int(c.get("men", -1)) != int(g.get("men", -2)) or int(c.get("horses", 0)) != int(g.get("horses", 0)) or not is_equal_approx(float(c.get("capacity_kg", 0.0)), float(g.get("capacity_kg", 0.0))) or str(c.get("tag", "")) != "diseno" or str(c.get("source", "")) == "":
			off.append(id)
	_ck(off.is_empty(), "visual/r1 F3 units.formation.groups copia hombres, caballos y carga de las reglas, con etiqueta diseño y fuente%s" % ("" if off.is_empty() else ": difiere " + str(off)))
	# 2) la regla: una figura cada 3 o 4 hombres, entre 6 y 24, nunca más figuras que hombres (el arreo cuenta mulas y arrieros); el MultiMesh trae las que no dibuja la jefa
	var bad: Array = []
	var report: Dictionary = u.formation_report
	for id in V.GROUPS:
		var r: Dictionary = report.get(id, {})
		var men := int(r.get("hombres", 0))
		var figures := int(r.get("figuras", 0))
		var people := figures - int(r.get("mulas", 0))
		var instances := 0
		for batch in (u.tokens[id].formation as Array):
			instances += ((batch.mmi as MultiMeshInstance3D).multimesh).instance_count
		var leader := 2 if id == "reconocedores" else 1
		var ok := people <= men and figures <= 24 and instances == figures - leader and (figures >= 6 or figures == men)
		if id != "arreo":
			ok = ok and (men < 6 or (float(men) / float(figures) >= 3.0 and float(men) / float(figures) <= 4.0))
		if not ok:
			bad.append("%s %d hombres → %d figuras, %d en MultiMesh" % [id, men, figures, instances])
	_ck(bad.is_empty(), "visual/r1 F3 cada agrupación es una formación de una figura cada 3 o 4 hombres (6 a 24, nunca más que los hombres)%s" % ("" if bad.is_empty() else ": " + str(bad)))
	_ck(int((report.get("rodriguez", {}) as Dictionary).get("jinetes", 0)) == 5 and int((report.get("rodriguez", {}) as Dictionary).get("a_pie", 0)) == 9, "visual/r1 F3 Rodríguez: jinetes en la proporción de caballos (16 de 48) y el resto a pie (%s)" % str(report.get("rodriguez", {})))
	# 3) el anillo encierra la huella de cada formación
	var outside: Array = []
	for id in V.GROUPS:
		var ring_r := float(u.ring_radius(id))
		for batch in (u.tokens[id].formation as Array):
			for xf in (batch.base as Array):
				if Vector2((xf as Transform3D).origin.x, (xf as Transform3D).origin.z).length() + 0.5 > ring_r:
					outside.append(id)
	_ck(outside.is_empty(), "visual/r1 F3 el anillo de bando de cada ficha encierra todas las figuras de su formación%s" % ("" if outside.is_empty() else ": se salen de " + str(outside)))
	# 3b) cada figura apoya en el suelo dibujado de su lugar (no a la altura del pie de la jefa)
	var worst_dy := 0.0
	for id in V.GROUPS:
		var node_g: Node3D = view.unit_nodes[id]
		for batch in (u.tokens[id].formation as Array):
			for xf in (batch.ground as Array):
				var w: Vector3 = node_g.position + Basis(Vector3.UP, node_g.rotation.y) * ((xf as Transform3D).origin * node_g.scale.x)
				worst_dy = maxf(worst_dy, absf(w.y - float(u.gfx.rendered_h(w.x, w.z))))
	_ck(worst_dy < 0.02, "visual/r1 F3 cada figura de la formación apoya en el relieve de su lugar (peor desvío %.3f m)" % worst_dy)
	# 4) de cerca se ven todas; de lejos (> far_m) parte; con la mitad de la fuerza, la mitad (se van las de atrás)
	var portal: Node3D = view.unit_nodes["portal"]
	var total := int(report.portal.figuras) - 1
	_frame_camera(cam, {"target": portal.global_position, "distance": 90.0, "pitch_deg": 45.0, "yaw_deg": 0.0})
	view.call("_update_scales")
	var near_n: int = u.formation_visible("portal")
	_frame_camera(cam, {"target": portal.global_position, "distance": 700.0, "pitch_deg": 45.0, "yaw_deg": 0.0})
	view.call("_update_scales")
	var far_n: int = u.formation_visible("portal")
	_ck(near_n == total and far_n > 0 and far_n < total, "visual/r1 F3 de cerca se ven las %d figuras de Portal y a 700 m menos (%d): el resto lo dice la marca de la interfaz" % [near_n, far_n])
	_frame_camera(cam, {"target": portal.global_position, "distance": 90.0, "pitch_deg": 45.0, "yaw_deg": 0.0})
	view.call("_update_scales")
	var st: Dictionary = rules.render_state().duplicate(true)
	for d in st.get("units", []):
		if str(d.get("id", "")) == "portal":
			d["strength_pct"] = 50.0
	u.sync_units(st, true)
	var half_n: int = u.formation_visible("portal")
	for d in st.get("units", []):
		d["strength_pct"] = 100.0
	u.sync_units(st, true)
	_ck(half_n >= int(floor(total * 0.4)) and half_n <= int(ceil(total * 0.6)) + 1 and u.formation_visible("portal") == total, "visual/r1 F3 con la mitad de la fuerza se ven %d de %d figuras y al recuperarla vuelven todas" % [half_n, total])
	# 5) el paso: con la ficha recién movida y cerca las figuras suben y bajan; quieta, vuelven a su lugar
	u.tokens["portal"]["moved_ms"] = Time.get_ticks_msec()
	u.animate(1.3)
	var lifted := float(u.tokens["portal"].get("step_lift_m", 0.0)) > 0.001
	u.tokens["portal"]["moved_ms"] = -100000
	u.animate(1.4)
	var back := float(u.tokens["portal"].get("step_lift_m", 1.0)) == 0.0 and not bool(u.tokens["portal"].stepping)
	_ck(lifted and back, "visual/r1 F3 la formación que marcha da el paso y al pararse vuelve a su lugar (sube: %s, vuelve: %s)" % [str(lifted), str(back)])
	# 6) picking: un clic sobre la figura del borde de la formación (más allá de los 55 px de la jefa) elige la agrupación
	_frame_camera(cam, {"target": portal.global_position, "distance": 40.0, "pitch_deg": 45.0, "yaw_deg": 0.0})
	view.call("_update_scales")
	var far_fig := Vector3.ZERO
	for batch in (u.tokens["portal"].formation as Array):
		for xf in (batch.base as Array):
			if (xf as Transform3D).origin.length() > far_fig.length():
				far_fig = (xf as Transform3D).origin
	var edge_screen := cam.unproject_position(portal.global_transform * (far_fig + Vector3(0.0, 0.9, 0.0)))
	var leader_screen := cam.unproject_position(portal.global_position)
	_ck(str(view.pick_unit(cam, edge_screen)) == "portal", "visual/r1 F3 un clic sobre la figura del borde de la formación (a %.0f px de la jefa) elige a Portal" % edge_screen.distance_to(leader_screen))
	# 6b) visual/r1 F4: Rodríguez monta el caballo criollo (jefa con esqueleto y andares, jinete en el hueso «silla») y la tropa montada va en MultiMesh por pelaje
	_test_horses(u)
	# 6c) visual/r1 F5: figuras de a pie de 1817 (jefa con esqueleto y andares, tropa liviana en MultiMesh) y casas del kit sin deformar
	_test_foot_and_houses(u)
	# 7) defensores a escala real (antes crecían hasta 28 px)
	var dressed: RefCounted = Vis.DressedRules.new(Fx.rules_stub(1817, 1, {"skip_intro": true, "phase": "ataque"}), "ataque")
	view.build(dressed, "media")
	_frame_camera(cam, view.initial_frame(cam))
	view.update_state(0.016)
	view.call("_update_scales")
	var grown := 0
	for e in view.get_node("Defensores").get_children():
		grown += 0 if (e as Node3D).scale.is_equal_approx(Vector3.ONE) else 1
	_ck(view.get_node("Defensores").get_child_count() >= 8 and grown == 0, "visual/r1 F3 los defensores van a escala real (%d de %d agrandados)" % [grown, view.get_node("Defensores").get_child_count()])
	var glb_enemies := 0
	for e in view.get_node("Defensores").get_children():
		for mi in (e as Node).get_children():
			if mi is MeshInstance3D and (mi as MeshInstance3D).mesh != null and (mi as MeshInstance3D).mesh.surface_get_material(0) == view.units.gfx.token_mat("enemigo_glb"):
				glb_enemies += 1
	_ck(glb_enemies >= 8, "visual/r1 F5 los defensores son el infante realista de 1817 con el material de ficha enemiga de color lineal (%d)" % glb_enemies)
	suite.extra["formaciones"] = report.duplicate(true)
	view.free()
	view = null
	cam.free()
	cam = null
	await process_frame

## visual/r1 F5: figuras de a pie de 1817 (jefa con esqueleto y andares, tropa liviana con material lineal), tacuara del jinete en la mano y casas del kit sin deformar.
func _test_foot_and_houses(u) -> void:
	var node: Node3D = view.unit_nodes["portal"]
	var fig := node.get_node_or_null("figura") as Node3D
	var players: Array = fig.find_children("*", "AnimationPlayer", true, false) if fig != null else []
	var anims_ok := not players.is_empty() and ["idle", "walk", "run"].all(func(a): return (players[0] as AnimationPlayer).has_animation(a))
	var glb_mat: ShaderMaterial = u.gfx.token_mat("aliado_glb")
	var mats_ok := fig != null and (fig.find_children("*", "MeshInstance3D", true, false) as Array).all(func(mi): return (mi as MeshInstance3D).material_override == glb_mat)
	_ck(fig != null and not fig.find_children("*", "Skeleton3D", true, false).is_empty() and anims_ok and mats_ok, "visual/r1 F5 la jefa de Portal es el paisano de 1817 con esqueleto, reposo, paso y carrera, y el material de ficha de color lineal")
	var troop_ok := true
	for id in ["portal", "arias", "rodriguez", "arreo"]:
		for batch in (u.tokens[id].formation as Array):
			var mmi := batch.mmi as MultiMeshInstance3D
			if str(mmi.name).begins_with("formacion_infante") or str(mmi.name).begins_with("formacion_a_pie") or str(mmi.name).begins_with("formacion_arriero"):
				troop_ok = troop_ok and mmi.multimesh.mesh.surface_get_material(0) == glb_mat
	_ck(troop_ok, "visual/r1 F5 la tropa de a pie y los arrieros son la versión liviana de los modelos de 1817, con el material de ficha de color lineal")
	var start := node.position; var gaits := {}; var t := 2000.0
	for case in [["quieto", 0.0], ["paso", 1.0], ["carrera", 3.2], ["parado", 0.0]]:
		for k in range(10):
			t += 0.3
			node.position += Vector3(float(case[1]) * 0.3, 0.0, 0.0)
			u.update_foot_gait("portal", t)
		gaits[case[0]] = u.foot_gait("portal")
	node.position = start
	var expect := {"quieto": "idle", "paso": "walk", "carrera": "run", "parado": "idle"}
	var gait_ok := expect.keys().all(func(k): return str((gaits[k] as Dictionary).get("andar", "")) == str(expect[k]))
	_ck(gait_ok and absf(float((gaits.paso as Dictionary).get("cadencia", 0.0)) - 1.0 / 1.15) < 0.1, "visual/r1 F5 la jefa de a pie anda según la velocidad: quieta reposo, 1 m/s paso (cadencia ≈ 0,87), 3,2 m/s carrera (%s)" % str(gaits))
	suite.extra["andares_a_pie"] = gaits
	var horse := view.unit_nodes["rodriguez"].get_node_or_null("caballo") as Node3D
	var rider: MeshInstance3D = null
	if horse != null:
		var seat := horse.find_children("silla", "BoneAttachment3D", true, false)
		rider = (seat[0] as Node).get_node_or_null("jinete") as MeshInstance3D if not seat.is_empty() else null
	_ck(rider != null and rider.mesh.get_aabb().end.y > 2.4, "visual/r1 F5 el jinete lleva la tacuara del modelo en la mano (punta a %.2f m sobre el asiento)" % (rider.mesh.get_aabb().end.y if rider != null else 0.0))
	var kinds := 0; var worst := 1.0
	for mmi in view.find_children("casas_modelo_*", "MultiMeshInstance3D", true, false):
		kinds += 1
		var mm := (mmi as MultiMeshInstance3D).multimesh
		for i in range(mm.instance_count):
			var b := mm.get_instance_transform(i).basis
			worst = maxf(worst, maxf(b.x.length(), b.z.length()) / maxf(minf(b.x.length(), b.z.length()), 0.001))
	_ck(kinds >= 3 and worst <= 1.2 + 0.001, "visual/r1 F5 el núcleo usa %d casas del kit y ninguna se estira más de 1,2 veces en un sentido que en el otro (peor %.3f)" % [kinds, worst])


## visual/r1 F4: el caballo criollo y el jinete de 1817 en la formación de Rodríguez: la jefa, su jinete, el material, los pelajes de la tropa y el andar por velocidad.
func _test_horses(u) -> void:
	var node: Node3D = view.unit_nodes["rodriguez"]
	var horse := node.get_node_or_null("caballo") as Node3D
	if not _ck(horse != null and u.horses_on(), "visual/r1 F4 la jefa de Rodríguez es el caballo criollo de los modelos propios"):
		return
	var sk := horse.find_children("*", "Skeleton3D", true, false)
	var players := horse.find_children("*", "AnimationPlayer", true, false)
	var anims_ok := not players.is_empty() and ["idle", "walk", "trot", "gallop"].all(func(a): return (players[0] as AnimationPlayer).has_animation(a))
	_ck(not sk.is_empty() and (sk[0] as Skeleton3D).find_bone("silla") >= 0 and anims_ok, "visual/r1 F4 la jefa trae esqueleto con el hueso «silla» y los cuatro andares (idle, walk, trot, gallop)")
	var seat := horse.find_children("silla", "BoneAttachment3D", true, false)
	var rider := (seat[0] as Node).get_node_or_null("jinete") as MeshInstance3D if not seat.is_empty() else null
	_ck(rider != null and str((seat[0] as BoneAttachment3D).bone_name) == "silla" and rider.transform.is_equal_approx(Transform3D.IDENTITY), "visual/r1 F4 el jinete va en un BoneAttachment3D del hueso «silla» con transformación identidad")
	# el material: el de ficha aliada con color de vértice lineal (luz propia, borde de bando, modo albedo) y el contorno de tinta como segunda pasada
	var glb_mat: ShaderMaterial = u.gfx.token_mat("aliado_glb")
	var mats_ok := glb_mat != null and float(glb_mat.get_shader_parameter("vertex_linear")) == 1.0 and glb_mat.shader == (u.gfx.token_mat("aliado") as ShaderMaterial).shader
	for mi in horse.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		mats_ok = mats_ok and (m.material_override == glb_mat or (m.material_override == null and m.mesh.surface_get_material(0) == glb_mat))
	_ck(mats_ok, "visual/r1 F4 caballo y jinete usan el material de ficha (color de vértice lineal) y no los materiales del GLB")
	view.set_albedo_mode(true)
	var albedo_on := float(glb_mat.get_shader_parameter("albedo_mode")) == 1.0
	view.set_albedo_mode(false)
	_ck(albedo_on and float(glb_mat.get_shader_parameter("albedo_mode")) == 0.0, "visual/r1 F4 el modo albedo del QA también aplana el caballo y el jinete")
	# el granate del modelo (poncho y pañuelo) se recoloreó a la paleta: ninguna parte del jinete se lee roja de enemigo
	var red := 0
	if rider != null:
		for c in (rider.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR] as PackedColorArray):
			if c.r > 0.1 and c.r > c.g * 2.5 and c.r > c.b * 2.5:
				red += 1
	_ck(rider != null and red == 0, "visual/r1 F4 el poncho y el pañuelo granates del jinete van a la ropa de la paleta (%d vértices rojos)" % red)
	# la tropa montada: MultiMesh por pelaje y ropa, sobre todo zainos y alazanes (la jefa es zaina)
	var coats: Array = u._troop_coats_of("rodriguez")
	var common := 1 + coats.filter(func(c): return str(c) in ["zaino", "alazan"]).size()
	var mounted := 0
	for batch in (u.tokens["rodriguez"].formation as Array):
		if str(batch.get("coat", "")) != "":
			mounted += (batch.base as Array).size()
	_ck(mounted == 4 and coats.size() == 4 and common * 2 > coats.size() + 1, "visual/r1 F4 los 4 jinetes de tropa van en caballos de pelajes mezclados, sobre todo zainos y alazanes (%s)" % str(coats))
	_ck(float(u.ring_radius("rodriguez")) < 7.6, "visual/r1 F4 con el caballo criollo (más corto y angosto, sin la lanza terciada) la huella de Rodríguez se achica (anillo de %.2f m; en F3, 7,6 m)" % float(u.ring_radius("rodriguez")))
	# el andar por la velocidad real sobre el suelo, con la cadencia ajustada (se le pasa el reloj para no esperar)
	var start := node.position
	var gaits := {}
	var t := 1000.0
	for case in [["quieto", 0.0], ["paso", 1.0], ["marcha", 3.2], ["galope", 8.5], ["parado", 0.0]]:
		for k in range(10):
			t += 0.3
			node.position += Vector3(float(case[1]) * 0.3, 0.0, 0.0)
			u.update_gait("rodriguez", t)
		gaits[case[0]] = u.horse_gait("rodriguez")
	node.position = start
	var expect := {"quieto": "idle", "paso": "walk", "marcha": "trot", "galope": "gallop", "parado": "idle"}
	var gait_ok := true
	for k in expect:
		gait_ok = gait_ok and str((gaits[k] as Dictionary).get("andar", "")) == str(expect[k])
	var trot_scale := float((gaits.marcha as Dictionary).get("cadencia", 0.0))
	# visual/r1 F4b: la cadencia esperada sale de la velocidad natural del trote en la configuración (3,3 m/s con el tranco corregido, antes 2)
	var trot_nat := 0.0
	for gd in u.hcfg("gaits"):
		if str((gd as Dictionary).anim) == "trot":
			trot_nat = float((gd as Dictionary).natural_mps)
	_ck(gait_ok and trot_nat > 0.0 and absf(trot_scale - 3.2 / trot_nat) < 0.1, "visual/r1 F4 el andar sigue la velocidad: quieto reposo, 1 m/s paso, 3,2 m/s trote (cadencia %.2f ≈ %.2f), 8,5 m/s galope (%s)" % [trot_scale, 3.2 / maxf(trot_nat, 0.01), str(gaits)])
	_ck(trot_scale <= 1.3, "visual/r1 F4b B-063: con el tranco corregido la marcha de las reglas (3,2 m/s) se ve al trote con cadencia ≤ 1,3 (%.2f)" % trot_scale)
	suite.extra["andares_caballo"] = gaits
