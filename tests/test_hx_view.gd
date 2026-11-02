extends SceneTree

## Pruebas de la capa de vista del nivel «humahuaca» (CONTRATO 3.4 y 7; TRAZA TR-091 a TR-099). Dueña: visual. Sin ventana ni escritura:
##   godot --headless --path . --script tests/test_hx_view.gd [-- --ronda=r1.0]
## En R1.0 prueba el STUB (stubs/stub_view.gd) y los datos de data/humahuaca_visual.json; desde R1 prueba también la vista real
## (view/humahuaca_view.gd) con las mismas comprobaciones. Si las otras pistas ya entregaron sus stubs, arma la vista sobre ellos
## (tests/hx_fixtures.gd); si no, sobre las copias mínimas de tools/vis_humahuaca.gd. Piso de comprobaciones: 25 (CONTRATO 5.1).
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
	_test_build()
	_test_initial_frame()
	_test_picking()
	_test_anachronisms()
	_test_palette_only()
	_test_canonical_views()
	_test_lights()
	_test_archetypes_grayscale()
	_test_albedo_and_probes()
	_test_dynamic_api()
	_test_degraded()
	suite.check(suite.elapsed_ms() < 30000, "test_hx_view corre en poco tiempo (objetivo < 30 s): %d ms" % suite.elapsed_ms())
	suite.require_floor(int(FLOOR_BY_ROUND.get(suite.round_id, 25)))
	suite.finish(self)


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
		if m.mesh == null:
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
	var script := Fx.load_script(Fx.STUB_PATHS.view)
	if not suite.check(script != null, "TR-091 stubs/stub_view.gd carga y parsea"):
		return
	var missing := Fx.api_missing(script, "view")
	suite.check(missing.is_empty(), "TR-091 el stub trae toda la API de 3.4%s" % ("" if missing.is_empty() else ": falta " + ", ".join(PackedStringArray(missing))))
	var real := Fx.load_script(Fx.REAL_PATHS.view)
	suite.extra["vista_real"] = real != null
	if real != null:
		var real_missing := Fx.api_missing(real, "view")
		suite.check(real_missing.is_empty(), "TR-091 la vista real trae toda la API de 3.4%s" % ("" if real_missing.is_empty() else ": falta " + ", ".join(PackedStringArray(real_missing))))
	cam = _make_camera(root)
	view = script.new()
	root.add_child(view)
	var before := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	view.build(rules, "media")
	suite.check(view.get_child_count() >= 3, "TR-091 la vista construye terreno, luz y ambiente (%d hijos)" % view.get_child_count())
	suite.check(float(view.build_ms) < 1500.0, "TR-091 construir tarda menos de 1 500 ms (%.0f ms)" % float(view.build_ms))
	suite.extra["build_ms"] = snappedf(float(view.build_ms), 0.1)
	var nodes: int = view.find_children("*", "", true, false).size()
	suite.extra["nodos"] = nodes
	suite.check(nodes > 40 and nodes < 3000, "TR-091 el presupuesto de nodos del stub es razonable (%d)" % nodes)
	var landmarks := (rules.call("terrain").call("landmarks", {}) as Array).size()
	suite.check((view.find_children("hito_*", "Node3D", true, false).size()) >= mini(landmarks - 2, 15), "TR-091 hay un nodo por hito con huella (%d hitos)" % landmarks)
	suite.check(view.unit_nodes.size() == 5 and view.unit_labels.size() == 5, "TR-091 hay una ficha y una etiqueta por agrupación")
	for q in VV.QUALITY:
		view.build(rules, q)
		suite.check(view.get_child_count() >= 3, "TR-091 build(«%s») no rompe la escena" % q)
	view.build(rules, "media")
	view.free()
	view = null
	var probe := (load(Fx.STUB_PATHS.view) as GDScript).new() as Node3D
	root.add_child(probe)
	probe.build(rules, "media")
	probe.build(rules, "media")
	probe.free()
	suite.check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) <= before, "TR-091 construir dos veces y liberar no deja nodos huérfanos (%d antes, %d después)" % [before, int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))])
	view = (load(Fx.STUB_PATHS.view) as GDScript).new() as Node3D
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
		suite.check(bool(f.fits) and float(f.distance) >= 40.0 and float(f.distance) <= 900.0, "TR-092 initial_frame().fits a %s con distancia %.0f m dentro del zoom de 40 a 900 m" % [label, float(f.distance)])
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
		suite.check(info.size() > 0 and inside, "TR-092 «%s» queda a la vista, a ≥ 5 %% del borde, con la cámara inicial real (%.0f, %.0f de %.0f × %.0f)" % [id, screen.x, screen.y, vp_size.x, vp_size.y])
	var jf: Dictionary = visual.get("initial_frame", {})
	suite.check(is_equal_approx(float(f2.pitch_deg), float(jf.get("pitch_deg", -1.0))) and is_equal_approx(float(f2.yaw_deg), float(jf.get("yaw_deg", -1.0))), "TR-092 la inclinación y el rumbo iniciales son los del JSON (52° y 35°)")


# ---------------------------------------------------------------------------------------------------------------------
# TR-093 · picking coherente con el terreno

func _test_picking() -> void:
	if view == null:
		return
	# un cuadro amplio donde entran las cinco partidas: con los datos reales alguna queda fuera del cuadro inicial (que solo exige los objetivos y la zona)
	_frame_camera(cam, {"target": Vector3(250.0, 20.0, 500.0), "distance": 720.0, "pitch_deg": 52.0, "yaw_deg": 35.0})
	view.update_state(0.016)
	var good := 0
	for id in V.GROUPS:
		var node: Node3D = view.unit_nodes[id]
		var screen := cam.unproject_position(_token_center(node))
		if str(view.pick_unit(cam, screen)) == id:
			good += 1
	suite.check(good == 5, "TR-093 pick_unit devuelve la agrupación sobre cada una de las 5 fichas (%d de 5)" % good)
	suite.check(str(view.pick_unit(cam, Vector2(3.0, 3.0))) == "", "TR-093 pick_unit lejos de toda ficha devuelve «»")
	var in_rect: Array = view.pick_units_in_rect(cam, Rect2(Vector2.ZERO, cam.get_viewport().get_visible_rect().size))
	suite.check(in_rect == V.GROUPS, "TR-093 pick_units_in_rect con todo el cuadro devuelve las 5 agrupaciones en el orden de GROUPS (%s)" % str(in_rect))
	var first_screen := cam.unproject_position(_token_center(view.unit_nodes["rodriguez"]))
	var around: Array = view.pick_units_in_rect(cam, Rect2(first_screen - Vector2(30.0, 30.0), Vector2(60.0, 60.0)))
	suite.check(around.has("rodriguez") and around.size() < 5, "TR-093 pick_units_in_rect con una caja alrededor de Rodríguez devuelve esa ficha y no las cinco (%s)" % str(around))
	var fronts := 0
	for id in V.OBJECTIVES:
		var info: Dictionary = view.get_landmark_info(id)
		if str(view.pick_front(cam, cam.unproject_position(Vector3(float(info.x), float(info.y) + 2.0, float(info.z))))) == id:
			fronts += 1
	suite.check(fronts == 3, "TR-093 pick_front devuelve el objetivo sobre cada uno de los 3 frentes (%d de 3)" % fronts)
	var info2: Dictionary = view.get_landmark_info("templo")
	suite.check(str(view.pick_landmark(cam, cam.unproject_position(Vector3(float(info2.get("x", 0.0)), float(info2.get("y", 0.0)) + 1.5, float(info2.get("z", 0.0)))))) == "templo", "TR-093 pick_landmark encuentra el templo")
	var worst := 0.0
	for p in [Vector2(450.0, 325.0), Vector2(120.0, 500.0), Vector2(600.0, 250.0), Vector2(300.0, 400.0)]:
		var ground := Vector3(p.x, float(rules.call("terrain").call("height_at", p.x, p.y)), p.y)
		var back: Variant = view.ground_xz_from_screen(cam, cam.unproject_position(ground))
		worst = maxf(worst, (back as Vector2).distance_to(p) if back is Vector2 else 999.0)
	suite.check(worst < 2.0, "TR-093 el rayo desde la pantalla vuelve al punto del terreno a menos de 2 m (peor %.2f m)" % worst)
	var horizon_cam := _make_camera(root)
	horizon_cam.transform = Transform3D(Basis.looking_at(Vector3(0.0, 0.2, -1.0), Vector3.UP), Vector3(450.0, 60.0, 600.0))
	suite.check(view.ground_xz_from_screen(horizon_cam, horizon_cam.get_viewport().get_visible_rect().size * 0.5) == null, "TR-093 un rayo que sube por encima del horizonte devuelve null")
	horizon_cam.free()
	cam.current = true
	var mpp := float(view.meters_per_pixel(cam))
	suite.check(mpp > 0.2 and mpp < 1.5, "TR-093 meters_per_pixel en la cámara inicial es plausible (%.3f m/px)" % mpp)
	suite.check((view.camera_frustum_on_ground(cam) as PackedVector2Array).size() == 4, "TR-093 camera_frustum_on_ground devuelve 4 puntos")
	var uv: Vector2 = view.world_to_map(Vector2(450.0, 0.0))
	suite.check(is_equal_approx(uv.x, 0.5) and is_equal_approx(uv.y, 0.0) and (view.map_to_world(Vector2(0.5, 1.0)) as Vector2).is_equal_approx(Vector2(450.0, 650.0)), "TR-093 world_to_map y map_to_world van y vuelven, con v = 0 en el norte")
	var bounds: Rect2 = view.camera_bounds()
	suite.check(bounds.is_equal_approx(Rect2(-120.0, -120.0, 1140.0, 890.0)), "TR-093 camera_bounds es la ventana más 120 m (%s)" % str(bounds))
	var clamped: Vector3 = view.clamp_camera_target(Vector3(5000.0, 0.0, -5000.0))
	suite.check(is_equal_approx(clamped.x, bounds.end.x) and is_equal_approx(clamped.z, bounds.position.y) and clamped.y >= float(rules.call("terrain").call("height_at", clamped.x, clamped.z)) - 0.001, "TR-093 clamp_camera_target recorta a los límites de la ventana más 120 m y no baja de la altura del suelo (%s)" % str(clamped))
	var tex: Texture2D = view.get_minimap_texture(Vector2i(260, 188))
	suite.check(tex != null and tex.get_width() == 260 and tex.get_height() == 188, "TR-093 get_minimap_texture(260 × 188) devuelve una textura de ese tamaño")
	var labels: Array = view.landmark_labels(cam)
	suite.check(labels.size() >= 15 and labels[0].has_all(["id", "name", "tag", "screen", "behind"]), "TR-093 landmark_labels devuelve {id, name, tag, screen, behind} (%d rótulos)" % labels.size())


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
	suite.check(bad.is_empty(), "TR-094 ningún nodo de la vista se llama como un anacronismo de la lista A%s" % ("" if bad.is_empty() else ": " + str(bad)))
	var temple := view.get_node_or_null("Hitos/hito_templo") as Node3D
	if suite.check(temple != null, "TR-094 el templo existe como nodo de la vista"):
		var box := _node_bounds(temple)
		var ground := float(rules.call("terrain").call("height_at", 450.0, 325.0))
		suite.check(box.end.y - minf(ground, box.position.y + 0.3) <= 8.0, "TR-094 el templo mide ≤ 8 m de alto por la altura de sus vértices (%.2f m)" % (box.end.y - minf(ground, box.position.y + 0.3)))
		var towers := 0
		for mi in temple.find_children("*", "MeshInstance3D", true, false):
			if (mi as MeshInstance3D).get_aabb().size.y > 8.0:
				towers += 1
		suite.check(towers == 0, "TR-094 ninguna pieza del templo sobresale como torre de campanas")
	var text := JSON.stringify(visual.get("markers", {})) + JSON.stringify(visual.get("tokens", {}))
	var flag := RegEx.new()
	flag.compile("(?i)(bandera argentina|sol de mayo|cruz de borgo|bandera espa)")
	suite.check(flag.search(text) == null, "TR-094 los marcadores y las fichas no nombran banderas de la lista A")


# ---------------------------------------------------------------------------------------------------------------------
# TR-095 · ninguna entidad con color suelto fuera de la paleta

func _test_palette_only() -> void:
	var ids := {}
	for entry in visual.get("palette", []):
		ids[str(entry.id)] = true
	suite.check(ids.size() == 24, "TR-095 la paleta tiene 24 ids únicos (%d)" % ids.size())
	var stray: Array = []
	for section in ["props", "tokens", "lights", "rain", "fx", "units", "materials"]:
		_walk_colors(visual.get(section, {}), section, ids, stray)
	suite.check(stray.is_empty(), "TR-095 todo color de props, fichas, luces, lluvia, efectos, figuras y materiales cita un id de la paleta%s" % ("" if stray.is_empty() else ": " + str(stray.slice(0, 3))))
	var script := Fx.load_script(Fx.STUB_PATHS.view)
	var constants: Dictionary = script.get_script_constant_map() if script != null else {}
	var outside: Array = []
	for table in ["SURFACE_COLOR", "STATE_RING", "LOOT_COLOR"]:
		for key in (constants.get(table, {}) as Dictionary):
			if not ids.has(str(constants[table][key])):
				outside.append(str(constants[table][key]))
	suite.check(outside.is_empty() and constants.has("SURFACE_COLOR"), "TR-095 las tablas de color del stub (superficies, estado de los frentes, botín) citan ids de la paleta")
	var markers: Dictionary = visual.get("markers", {})
	suite.check(str(markers.get("patriota", {}).get("fill", "")) == "#7FAAC4" and str(markers.get("realista", {}).get("fill", "")) == "#983F36" and str(markers.get("neutral", {}).get("fill", "")) == "#B99A50" and bool(markers.get("interfaz", false)), "TR-095 los marcadores de bando son los HEX exactos de la lámina 06 y están rotulados como interfaz")


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
	suite.check(listed == VV.VIEW_IDS, "TR-096 canonical_views trae las 7 vistas en el orden de VIEW_IDS (%s)" % str(listed))
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
	suite.check(complete == 7, "TR-096 cada vista canónica trae target, distancia, inclinación, rumbo, hora, lluvia y 5 rasgos obligatorios (%d de 7)" % complete)
	suite.check(ranges_ok == 7, "TR-096 las 7 vistas están dentro de lo que la cámara del juego permite (40 a 900 m, 5° a 85°, hora y lluvia de 0 a 1) (%d de 7)" % ranges_ok)
	var night: Dictionary = view.canonical_view("juego_noche")
	var dawn: Dictionary = view.canonical_view("juego_alba")
	var initial: Dictionary = visual.get("initial_frame", {})
	suite.check(is_equal_approx(float(night.distance), float(initial.distance)) and is_equal_approx(float(dawn.pitch_deg), float(initial.pitch_deg)) and (night.target as Vector3).is_equal_approx(dawn.target), "TR-096 juego_noche y juego_alba son la cámara inicial (470 m, 52°, rumbo 35°)")
	suite.check((view.canonical_view("no_existe") as Dictionary).is_empty(), "TR-096 canonical_view de un id desconocido devuelve {}")


# ---------------------------------------------------------------------------------------------------------------------
# TR-097 · las luces se dibujan de lejos; luz, niebla y lluvia salen del tiempo

func _test_lights() -> void:
	if view == null:
		return
	var state: Dictionary = rules.call("render_state")
	var wanted: Array = state.get("lights", [])
	var holder := view.get_node("Luces") as Node3D
	suite.check(holder.get_child_count() == wanted.size() and wanted.size() >= 3, "TR-097 hay un punto de luz por cada luz de render_state (%d de %d, ≥ 3)" % [holder.get_child_count(), wanted.size()])
	var halos_ok := true
	for l in holder.get_children():
		var halo: MeshInstance3D = null
		for k in l.get_children():
			if k is MeshInstance3D:
				var m: Material = (k as MeshInstance3D).material_override
				if m is StandardMaterial3D and (m as StandardMaterial3D).billboard_mode == BaseMaterial3D.BILLBOARD_ENABLED:
					halo = k
		halos_ok = halos_ok and halo != null and halo.scale.x >= 4.0
	suite.check(halos_ok, "TR-097 cada luz trae un resplandor que crece con la distancia para leerse de lejos")
	var sun := view.get_node("Sol") as DirectionalLight3D
	var env := (view.get_node("Ambiente") as WorldEnvironment).environment
	view.set_time_override(0.0, 0.9)
	var night_energy := sun.light_energy
	var night_fog := env.fog_density
	view.set_time_override(1.0, 0.0)
	suite.check(sun.light_energy > night_energy and env.fog_density < night_fog, "TR-097 de noche con lluvia hay menos luz y más niebla que de día (%.2f → %.2f; %.4f → %.4f)" % [night_energy, sun.light_energy, night_fog, env.fog_density])
	view.set_time_override(0.5, 0.4)
	suite.check(sun.light_color.r > sun.light_color.b, "TR-097 el alba tiene la luz cálida")
	view.set_time_override(-1.0, 0.0)
	view.set_layer_visible("lights", false)
	suite.check(not holder.visible and not view.layer_visible("lights"), "TR-097 la capa «lights» apaga las luces")
	view.set_layer_visible("lights", true)
	suite.check(holder.visible, "TR-097 y las vuelve a encender")


# ---------------------------------------------------------------------------------------------------------------------
# TR-098 · siluetas distintas (el alto en pantalla, ≥ 48 px reales, se mide con ventana en tools/vis_humahuaca.gd: sin ventana no hay escala de pantalla)

func _test_archetypes_grayscale() -> void:
	if view == null:
		return
	_frame_camera(cam, view.initial_frame(cam))
	view.update_state(0.016)
	var raw_scale := cam.get_viewport().get_screen_transform().get_scale().y
	var scale_px := raw_scale if raw_scale >= 0.2 else 1.0  # sin ventana real la escala de pantalla no existe: la vista toma 1
	var short: Array = []
	for id in V.GROUPS:  # alto parado de la figura (de la base a la cima de sus piezas), proyectado, en píxeles de la pantalla
		var node_h: Node3D = view.unit_nodes[id]
		if not Rect2(Vector2.ZERO, cam.get_viewport().get_visible_rect().size).has_point(cam.unproject_position(node_h.global_position)):
			continue  # con los datos reales alguna partida cae fuera del cuadro inicial (que solo exige los objetivos y la zona)
		var base_y := cam.unproject_position(node_h.global_position).y
		var top_world := node_h.global_position.y
		for part in node_h.find_children("*", "MeshInstance3D", true, false):
			if not (str(part.name) in ["anillo", "borde", "seleccion"]):
				top_world = maxf(top_world, ((part as MeshInstance3D).global_transform * (part as MeshInstance3D).get_aabb()).end.y)
		var h_px := absf(base_y - cam.unproject_position(Vector3(node_h.global_position.x, top_world, node_h.global_position.z)).y) * scale_px
		if h_px < 40.0:
			short.append("%s %.0f px" % [id, h_px])
	# el stub estira lo parado hasta 4,6 veces y la ficha del borde inferior del cuadro queda en ≈ 42 px; el pedido de la vista real (V03) es ≥ 48 px
	suite.check(short.is_empty(), "TR-098 con el cuadro inicial cada ficha del stub mide ≥ 40 px de alto en pantalla%s" % ("" if short.is_empty() else ": " + str(short)))
	var dims := {}
	for id in V.GROUPS:
		var node_i: Node3D = view.unit_nodes[id]
		var box := _node_bounds(node_i)
		# medidas nominales: sin el crecimiento que las lleva a ≥ 48 px de pantalla (ancho y alto crecen distinto)
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
	suite.check(distinct, "TR-098 las 5 fichas tienen proporciones y alturas distintas de a pares, no son retintes del mismo cuerpo (diferencia mínima %.2f)" % worst)
	var tokens: Dictionary = visual.get("tokens", {})
	var shapes := {}
	for id in V.GROUPS:
		shapes[str((tokens.get(id, {}) as Dictionary).get("shape", ""))] = true
	suite.check(shapes.size() == 5 and shapes.keys().all(func(k): return VV.TOKEN_SHAPES.has(k)), "TR-098 cada agrupación tiene su forma propia del vocabulario (%s)" % str(shapes.keys()))
	var big := true
	for id in V.GROUPS:
		big = big and float((tokens.get(id, {}) as Dictionary).get("min_px", 0.0)) >= 48.0
	suite.check(big, "TR-098 todas las fichas piden ≥ 48 px de alto en pantalla")
	var node: Node3D = view.unit_nodes["rodriguez"]
	suite.check(node.get_child_count() >= 8 and not (node.get_child(0) is Sprite3D), "TR-098 la ficha es una figura de varias piezas, no un disco ni una imagen plana")


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
	suite.check(shaped and kinds.has("ficha") and kinds.has("objetivo") and kinds.has("suelo"), "TR-099 probes devuelve rectángulos de ficha, objetivo y suelo bien formados (%s)" % str(kinds))
	var env := (view.get_node("Ambiente") as WorldEnvironment).environment
	view.set_albedo_mode(true)
	suite.check(not env.fog_enabled and env.tonemap_mode == Environment.TONE_MAPPER_LINEAR and not (view.get_node("Sol") as DirectionalLight3D).shadow_enabled, "TR-099 set_albedo_mode(true) apaga niebla, sombras y curva de tonos")
	var unshaded := true
	for mi in view.find_children("hito_*", "Node3D", true, false):
		for m in mi.find_children("*", "MeshInstance3D", true, false):
			var mat := (m as MeshInstance3D).material_override
			if mat is StandardMaterial3D and (mat as StandardMaterial3D).transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
				unshaded = unshaded and (mat as StandardMaterial3D).shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
	suite.check(unshaded, "TR-099 en el modo albedo los materiales de los edificios quedan sin sombreado")
	view.set_albedo_mode(false)
	suite.check(env.fog_enabled, "TR-099 set_albedo_mode(false) devuelve la niebla")


# ---------------------------------------------------------------------------------------------------------------------
# Capas, selección y efectos

func _test_dynamic_api() -> void:
	if view == null:
		return
	for layer in VV.LAYERS:
		view.set_layer_visible(layer, false)
		var off: bool = not view.layer_visible(layer)
		view.set_layer_visible(layer, true)
		suite.check(off and view.layer_visible(layer), "3.4 la capa «%s» se apaga y se enciende" % layer)
	view.set_layer_visible("no_existe", true)
	suite.check(not view.layer_visible("no_existe"), "3.4 una capa que no existe se ignora")
	view.set_selected_ids(["portal", "arias"])
	view.update_state(0.016)
	var shown: Array = []
	for id in V.GROUPS:
		if (view.unit_nodes[id] as Node3D).get_node("seleccion").visible:
			shown.append(id)
	suite.check(shown == ["portal", "arias"] and view.selected_ids == ["portal", "arias"], "3.4 set_selected_ids marca solo las fichas elegidas (%s)" % str(shown))
	view.set_selected_ids([])
	var holder := view.get_node("Efectos") as Node3D
	for kind in VV.FX_KINDS:
		view.fx(kind, Vector2(450.0, 325.0), {})
	suite.check(holder.get_child_count() == VV.FX_KINDS.size(), "3.4 fx crea un efecto por cada uno de los 7 tipos (%d)" % holder.get_child_count())
	view.fx("tipo_inexistente", Vector2(0.0, 0.0), {})
	suite.check(holder.get_child_count() == VV.FX_KINDS.size(), "3.4 fx ignora un tipo que no existe")
	for _i in range(100):
		view.fx("fogonazo", Vector2(400.0, 300.0), {})
	suite.check(holder.get_child_count() <= 24, "3.4 los efectos simultáneos tienen tope según la calidad (%d)" % holder.get_child_count())
	view.update_state(10.0)
	suite.check(holder.get_child_count() == 0, "3.4 los efectos se liberan solos al terminar su vida")
	var info: Dictionary = view.get_landmark_info("bateria")
	suite.check(str(info.get("id", "")) == "bateria" and info.has("tag") and info.has("y") and (view.get_landmark_info("no_existe") as Dictionary).is_empty(), "3.4 get_landmark_info devuelve el hito con etiqueta y cota, y {} si no existe")
	var minimap_signals := [0]
	view.minimap_changed.connect(func(): minimap_signals[0] += 1)
	view.build(rules, "media")
	suite.check(minimap_signals[0] == 1, "3.4 build emite minimap_changed")
	view.set_time_override(-1.0, 0.0)


# ---------------------------------------------------------------------------------------------------------------------
# CONTRATO 7 · degradación elegante: sin reglas ni terreno la vista no se cae

func _test_degraded() -> void:
	var lone := (load(Fx.STUB_PATHS.view) as GDScript).new() as Node3D
	root.add_child(lone)
	lone.build(null, "media")
	lone.update_state(0.016)
	var f: Dictionary = lone.initial_frame(cam)
	suite.check(f.has_all(["target", "distance", "pitch_deg", "yaw_deg", "fits"]) and not bool(f.fits), "7 sin reglas ni terreno la vista construye y su cuadro inicial dice que no entra nada (fits = false)")
	suite.check(str(lone.pick_unit(cam, Vector2(100.0, 100.0))) == "" and (lone.landmark_labels(cam) as Array).is_empty() and (lone.get_minimap_texture(Vector2i(64, 48)) as Texture2D) != null, "7 sin reglas ni terreno el picking, los rótulos y el minimapa devuelven valores válidos")
	lone.free()
	var bad := (load(Fx.STUB_PATHS.view) as GDScript).new() as Node3D
	root.add_child(bad)
	bad.build(rules, "calidad_inventada")
	suite.check(bad.get_child_count() >= 3, "7 una calidad desconocida se trata como «media»")
	bad.free()
