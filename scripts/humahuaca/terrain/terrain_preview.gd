extends SceneTree
## Vista previa del relieve de Humahuaca: herramienta de la pista relieve_mapa para MIRAR el terreno sin las otras tres capas (la vista real es de `visual`).
## Arma una malla con `heightfield()` y `height_at`, la tiñe con `surface_at` (colores de la paleta), le pone el río, las tapias y la huella de cada hito como
## cajas, y saca capturas reales (con ventana) desde las cámaras que se pidan. No es parte del juego: nadie la carga.
##
## godot --path <proyecto> --resolution 1280x720 --audio-driver Dummy --script res://scripts/humahuaca/terrain/terrain_preview.gd -- --out=<carpeta>
##       [--views=acceso_so,desde_bateria,...] [--height=<ruta de otro humahuaca_height.json>] [--sun=alba|dia]
## Las cámaras usan la convención de ADDENDA A-11: `yaw` es el rumbo de la mirada (0 = mira al norte, 90 = al este) y la cámara se ubica en
## centro + (−sin(yaw)·cos(pitch), sin(pitch), cos(yaw)·cos(pitch)) · distancia.

const V = preload("res://scripts/humahuaca/humahuaca_vocab.gd")
const T = preload("res://scripts/humahuaca/terrain/humahuaca_terrain.gd")
const Minimap = preload("res://scripts/humahuaca/terrain/terrain_minimap.gd")

# nombre → [objetivo x, z, distancia, inclinación, rumbo de la mirada]
const VIEWS := {
	"acceso_so": [300.0, 520.0, 150.0, 22.0, 45.0],
	"desde_bateria": [318.0, 350.0, 60.0, 18.0, 90.0],
	"panorama_alto": [450.0, 330.0, 330.0, 28.0, 90.0],
	"general": [450.0, 325.0, 1050.0, 52.0, 10.0],
	"cuadro_inicial": [350.0, 470.0, 470.0, 52.0, 325.0],
	"cauce": [800.0, 240.0, 220.0, 24.0, 290.0],
	"cerro_oeste": [305.0, 345.0, 260.0, 20.0, 80.0],
	"limite_ne": [900.0, 0.0, 120.0, 20.0, 225.0],
}

var _terrain: RefCounted
var _cam: Camera3D
var _sun: DirectionalLight3D


func _initialize() -> void:
	var out := ""
	var views: Array = ["acceso_so", "desde_bateria", "panorama_alto", "general"]
	var height_path := ""
	var sun_mode := "alba"
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--out="):
			out = str(a).trim_prefix("--out=")
		elif str(a).begins_with("--views="):
			views = str(a).trim_prefix("--views=").split(",")
		elif str(a).begins_with("--height="):
			height_path = str(a).trim_prefix("--height=")
		elif str(a).begins_with("--sun="):
			sun_mode = str(a).trim_prefix("--sun=")
	if out == "":
		print("terrain_preview: falta --out=<carpeta>")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	_terrain = T.from_paths(V.MAP_PATH, height_path if height_path != "" else V.HEIGHT_PATH) if height_path != "" else T.load_default()
	if _terrain == null:
		print("terrain_preview: no hay terreno")
		quit(2)
		return
	_build_scene(sun_mode)
	await process_frame
	await process_frame
	for name in views:
		if not VIEWS.has(str(name)):
			continue
		_place_camera(VIEWS[str(name)])
		await process_frame
		await process_frame
		await create_timer(0.15).timeout
		var img := root.get_texture().get_image()
		img.save_png(out + "/" + str(name) + ".png")
		print("terrain_preview: ", name, " ", img.get_size())
	quit(0)


func _place_camera(v: Array) -> void:
	var tx := float(v[0])
	var tz := float(v[1])
	var dist := float(v[2])
	var pitch := deg_to_rad(float(v[3]))
	var yaw := deg_to_rad(float(v[4]))
	var target := Vector3(tx, _terrain.height_at(tx, tz), tz)
	var off := Vector3(-sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
	_cam.global_position = target + off
	_cam.look_at(target, Vector3.UP)


func _build_scene(sun_mode: String) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("A9BCC4") if sun_mode == "alba" else Color("9DBBD0")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("C9C2B4")
	env.ambient_light_energy = 0.55
	env.fog_enabled = true
	env.fog_light_color = Color("B9C4C4")
	env.fog_density = 0.00035
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 1800.0
	_sun.light_energy = 1.25
	_sun.light_color = Color("F2DDB8") if sun_mode == "alba" else Color("FFF4E0")
	root.add_child(_sun)
	var sun_dir := Vector3(0.78, 0.30, -0.35) if sun_mode == "alba" else Vector3(0.45, 0.78, -0.25)
	_sun.look_at_from_position(sun_dir.normalized() * 400.0, Vector3.ZERO, Vector3.UP)
	_cam = Camera3D.new()
	_cam.fov = 46.0
	_cam.far = 9000.0
	_cam.near = 0.5
	root.add_child(_cam)
	_cam.make_current()
	_add_terrain_mesh()
	_add_context_mesh()
	_add_river()
	_add_walls()
	_add_landmarks()


func _terrain_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _add_terrain_mesh() -> void:
	var hf: Dictionary = _terrain.heightfield()
	var nx := int(hf["nx"])
	var nz := int(hf["nz"])
	var cell := float(hf["cell"])
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for j in range(nz):
		for i in range(nx):
			var x := float(i) * cell
			var z := float(j) * cell
			verts.append(Vector3(x, _terrain.height_at(x, z), z))
			norms.append(_terrain.normal_at(x, z))
			var sname: String = _terrain.surface_at(x, z)
			var c := Color(str(Minimap.COLORS.get(sname, "B99A72")))
			cols.append(c)
	for j in range(nz - 1):
		for i in range(nx - 1):
			var k := j * nx + i
			idx.append_array([k, k + 1, k + nx, k + 1, k + nx + 1, k + nx])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _terrain_material()
	root.add_child(mi)


## El contexto de 30 m alrededor de la ventana (sin los triángulos que caen adentro de ella).
func _add_context_mesh() -> void:
	var cf: Dictionary = _terrain.context_field()
	var nx := int(cf["nx"])
	var nz := int(cf["nz"])
	var cell := float(cf["cell"])
	var ox := float(cf["origin_x"])
	var oz := float(cf["origin_z"])
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var dry := Color(str(Minimap.COLORS["suelo_seco"]))
	for j in range(nz):
		for i in range(nx):
			var x := ox + float(i) * cell
			var z := oz + float(j) * cell
			var h: float = _terrain.height_at(x, z)
			verts.append(Vector3(x, h - 0.6, z))
			norms.append(_terrain.normal_at(x, z))
			cols.append(dry.darkened(clampf((h - 17.0) / 260.0, 0.0, 0.45)))
	for j in range(nz - 1):
		for i in range(nx - 1):
			var cx := ox + (float(i) + 0.5) * cell
			var cz := oz + (float(j) + 0.5) * cell
			if cx > 0.0 and cx < 900.0 and cz > 0.0 and cz < 650.0:
				continue
			var k := j * nx + i
			idx.append_array([k, k + 1, k + nx, k + 1, k + nx + 1, k + nx])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _terrain_material()
	root.add_child(mi)


func _add_river() -> void:
	var rv: Dictionary = _terrain.river()
	var pts: Array = rv.get("pts", [])
	if pts.size() < 2:
		return
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	for n in range(pts.size()):
		var p := Vector2(float(pts[n]["x"]), float(pts[n]["z"]))
		var q := Vector2(float(pts[mini(n + 1, pts.size() - 1)]["x"]), float(pts[mini(n + 1, pts.size() - 1)]["z"]))
		var r := Vector2(float(pts[maxi(n - 1, 0)]["x"]), float(pts[maxi(n - 1, 0)]["z"]))
		var dir := (q - r).normalized()
		var side := Vector2(-dir.y, dir.x)
		var half := 0.25 * float(pts[n].get("w", 32.0))
		var a := p + side * half
		var b := p - side * half
		verts.append(Vector3(a.x, _terrain.height_at(a.x, a.y) + 0.12, a.y))
		verts.append(Vector3(b.x, _terrain.height_at(b.x, b.y) + 0.12, b.y))
	for n in range(pts.size() - 1):
		var k := n * 2
		idx.append_array([k, k + 1, k + 2, k + 1, k + 3, k + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(str(Minimap.COLORS["agua"]))
	m.roughness = 0.25
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	root.add_child(mi)


func _box(center: Vector3, size: Vector3, yaw_map_deg: float, color: Color) -> void:
	var bm := BoxMesh.new()
	bm.size = size
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.95
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = m
	mi.position = center
	mi.rotation.y = -deg_to_rad(yaw_map_deg)  # el rumbo del mapa es horario visto desde arriba; en Godot, +y gira al revés
	root.add_child(mi)


func _add_walls() -> void:
	var adobe := Color(str(Minimap.COLORS["camino"])).darkened(0.1)
	for kind in ["tapia", "barricada"]:
		for f in _terrain.features(kind):
			var pts: Array = f.get("pts", [])
			var hgt := float(f.get("height_m", 1.6))
			var thick := float(f.get("thickness_m", 0.6))
			for n in range(pts.size() - 1):
				var a := Vector2(float(pts[n]["x"]), float(pts[n]["z"]))
				var b := Vector2(float(pts[n + 1]["x"]), float(pts[n + 1]["z"]))
				var mid := (a + b) * 0.5
				var ang := rad_to_deg(atan2(b.y - a.y, b.x - a.x))
				_box(Vector3(mid.x, _terrain.height_at(mid.x, mid.y) + hgt * 0.5, mid.y), Vector3(a.distance_to(b), hgt, thick), ang, adobe)


func _add_landmarks() -> void:
	for lm in _terrain.landmarks({}):
		var fp: Dictionary = lm.get("footprint", {})
		var hgt := float(lm.get("height_m", 0.0))
		var typ := str(lm.get("type", ""))
		if hgt <= 0.0 or typ == "plaza":
			continue
		var col := Color("C4AA82")
		if typ == "objetivo":
			col = Color("983F36")
		elif typ == "torre":
			col = Color("B99A50")
		elif str(lm.get("id", "")) == "templo":
			col = Color("E4DDCA")
		var sx := float(fp.get("w", fp.get("r", 4.0) * 2.0))
		var sz := float(fp.get("d", fp.get("r", 4.0) * 2.0))
		var x := float(lm["x"])
		var z := float(lm["z"])
		_box(Vector3(x, _terrain.height_at(x, z) + hgt * 0.5, z), Vector3(sx, hgt, sz), float(lm.get("yaw_deg", 0.0)), col)
