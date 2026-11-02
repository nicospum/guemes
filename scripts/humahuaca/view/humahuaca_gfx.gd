extends RefCounted
## Recursos gráficos compartidos de la vista del nivel «humahuaca» (pista visual): la paleta, los materiales (de shader y estándar), las mallas básicas y el
## TERRENO CONTINUO: ventana jugable de 4 m (la grilla de `terrain.heightfield()`), contexto de 30 m (cuatro bandas pegadas a la ventana) y horizonte procedural
## hasta ±8 km que comparte los vértices del borde del contexto. Los tres usan UN solo material (shaders/humahuaca_terrain.gdshader): sin grietas y sin discos.
## Reglas: colores solo por id de paleta; la altura es SIEMPRE la del terreno (`height_at` o su grilla), nunca una propia; sin `shader_globals`.
## Convenciones del mundo: +x este, +z sur, y = metros sobre el cero local. Las mallas se arman en coordenadas del mundo (el padre va en el origen).

const V = preload("res://scripts/humahuaca/humahuaca_vocab.gd")
const VV = preload("res://scripts/humahuaca/view/vocab_view.gd")

const TERRAIN_SHADER := "res://shaders/humahuaca_terrain.gdshader"
const PROPS_SHADER := "res://shaders/humahuaca_props.gdshader"
const WATER_SHADER := "res://shaders/humahuaca_water.gdshader"
const FLAT_H := 17.0
const SKIRT_M := 3.0
const RING_ROWS := [0.0, 30.0, 85.0, 180.0, 340.0, 620.0, 1050.0, 1750.0, 2900.0, 4500.0, 6800.0]
const WORLD_RADIUS_M := 8000.0
## Canal de cada clase de superficie en las dos texturas de pesos: [textura (0 = splat_a, 1 = splat_b), canal r, g, b, a]. `muro` y `patio` se leen como suelo y como tierra apisonada.
const SURFACE_CHANNEL := {"suelo_seco": [0, 0], "sedimento_humedo": [0, 1], "piedra": [0, 2], "churqui": [0, 3], "irrigado": [1, 0], "agua": [1, 1],
	"camino": [1, 2], "patio": [1, 2], "zanja": [1, 3], "muro": [0, 0]}
## Color (id de paleta) con que se pinta cada superficie donde no hay shader (minimapa de respaldo, anillos).
const SURFACE_COLOR := {"suelo_seco": "suelo_seco", "sedimento_humedo": "sedimento_humedo", "piedra": "piedra_gris", "churqui": "churqui",
	"irrigado": "vegetacion_irrigada", "agua": "agua_turbia", "camino": "suelo_seco", "patio": "suelo_seco", "zanja": "sedimento_humedo", "muro": "adobe"}

var data: Dictionary = {}
var palette: Dictionary = {}
var quality := "media"
var qcfg: Dictionary = {}
var terrain: RefCounted = null
var world := Vector2(900.0, 650.0)
var albedo := false
var terrain_mat: ShaderMaterial
var props_mat: ShaderMaterial
var water_mat: ShaderMaterial
var win := Rect2(0.0, 0.0, 900.0, 652.0)  ## la ventana de 4 m: de la primera a la última fila de la grilla
var ctx := Rect2(-1350.0, -1025.0, 3600.0, 2700.0)  ## el contexto de 30 m
var build_stats: Dictionary = {}  ## triángulos y milisegundos de cada etapa del terreno (los informa el recorrido de QA)

var _mats: Dictionary = {}
var _flat: Dictionary = {}
var _meshes: Dictionary = {}
var _std_mats: Array = []  ## materiales estándar con sombreado: el modo albedo los pasa a «sin sombreado»
var _noise_big: FastNoiseLite
var _noise_gully: FastNoiseLite
var _noise_eco: FastNoiseLite


func setup(visual: Dictionary, quality_id: String, terrain_ref: RefCounted, world_size: Vector2) -> void:
	data = visual
	quality = quality_id if VV.QUALITY.has(quality_id) else "media"
	qcfg = (data.get("quality", {}) as Dictionary).get(quality, {})
	terrain = terrain_ref
	world = world_size
	palette.clear()
	for entry in data.get("palette", []):
		if entry is Dictionary:
			palette[str(entry.get("id", ""))] = Color(str(entry.get("hex", "#808080")))
	_noise_big = FastNoiseLite.new()
	_noise_big.seed = 1817
	_noise_big.frequency = 0.00055
	_noise_big.fractal_octaves = 4
	_noise_gully = FastNoiseLite.new()
	_noise_gully.seed = 1823
	_noise_gully.frequency = 0.0035
	_noise_gully.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_noise_gully.fractal_octaves = 3
	_noise_eco = FastNoiseLite.new()
	_noise_eco.seed = 77
	_noise_eco.frequency = 0.011
	_noise_eco.fractal_octaves = 3
	_make_shader_materials()


## Cuánto de un punto es monte bajo de churqui (0..1): la pendiente lo cubre, y el oeste de la ventana (la «ladera clara con arbustos oscuros» de la foto de 1923)
## tiene franjas diagonales de monte aunque el relieve sea suave. Es el mismo número para el suelo y para los arbustos que se dibujan encima.
func churqui_k(x: float, z: float, slope: float) -> float:
	var by_slope := clampf((slope - 0.03) / 0.07, 0.0, 1.0) * 0.92
	var west_k := clampf((560.0 - x) / 440.0, 0.0, 1.0)
	var band := _noise_eco.get_noise_2d(x * 0.8 + z * 0.35, z * 0.9 - x * 0.2) * 0.5 + 0.5  # franjas en diagonal
	var by_zone := smoothstep(0.50, 0.68, band) * west_k * 0.85
	return maxf(by_slope, by_zone)


## Color de la paleta por id (con ganancia opcional; nunca un HEX suelto).
func pc(id: String, gain: float = 1.0) -> Color:
	var c: Color = palette.get(id, Color(0.5, 0.5, 0.5))
	return Color(minf(c.r * gain, 1.0), minf(c.g * gain, 1.0), minf(c.b * gain, 1.0), 1.0)


func h(x: float, z: float) -> float:
	return float(terrain.call("height_at", x, z)) if terrain != null else FLAT_H


## Pendiente (adimensional: metros de subida por metro) alrededor de un punto, con dos muestras a 3 m.
func slope_at(x: float, z: float) -> float:
	var dx := (h(x + 3.0, z) - h(x - 3.0, z)) / 6.0
	var dz := (h(x, z + 3.0) - h(x, z - 3.0)) / 6.0
	return sqrt(dx * dx + dz * dz)


func surface_at(x: float, z: float) -> String:
	return str(terrain.call("surface_at", x, z)) if terrain != null and terrain.has_method("surface_at") else "suelo_seco"


# ---------------------------------------------------------------------------------------------------------------------
# Materiales

func _shader_material(path: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path) as Shader
	return m


func _make_shader_materials() -> void:
	var terrain_spec: Dictionary = (data.get("materials", {}) as Dictionary).get("terreno", {})
	terrain_mat = _shader_material(TERRAIN_SHADER)
	for entry in [["pal_suelo", "suelo_seco"], ["pal_sedimento", "sedimento_humedo"], ["pal_piedra", "piedra_gris"], ["pal_churqui", "churqui"],
			["pal_irrigada", "vegetacion_irrigada"], ["pal_agua", "agua_turbia"], ["pal_adobe", "adobe"], ["pal_lana", "lana_natural"]]:
		terrain_mat.set_shader_parameter(entry[0], pc(str(entry[1])))
	terrain_mat.set_shader_parameter("wet_darken", float((data.get("rain", {}) as Dictionary).get("wet_darken", 0.75)))
	terrain_mat.set_shader_parameter("wet_rough", float((data.get("rain", {}) as Dictionary).get("wet_roughness", 0.5)))
	terrain_mat.set_shader_parameter("contour_m", float(terrain_spec.get("contour_m", 5.0)))
	terrain_mat.set_shader_parameter("contour_alpha", float(terrain_spec.get("contour_alpha", 0.09)))
	terrain_mat.set_shader_parameter("detail", float(qcfg.get("shader_detail", 1.0)))
	terrain_mat.set_shader_parameter("datum_m", float(terrain.get("datum_asl_m")) if terrain != null and terrain.get("datum_asl_m") != null else 2940.0)
	props_mat = _shader_material(PROPS_SHADER)
	props_mat.set_shader_parameter("wet_darken", float((data.get("rain", {}) as Dictionary).get("wet_darken", 0.75)))
	props_mat.set_shader_parameter("detail", float(qcfg.get("shader_detail", 1.0)))
	water_mat = _shader_material(WATER_SHADER)
	water_mat.set_shader_parameter("pal_agua", pc("agua_turbia"))
	water_mat.set_shader_parameter("pal_orilla", pc("lana_natural"))


## Lluvia 0..1: oscurece y alisa el suelo, los edificios y el agua (CONTRATO 11.2: suelo ×0,75).
func set_rain(value: float) -> void:
	var r := clampf(value, 0.0, 1.0)
	for m in [terrain_mat, props_mat, water_mat]:
		if m != null:
			(m as ShaderMaterial).set_shader_parameter("rain", r)


func set_albedo(on: bool) -> void:
	albedo = on
	for m in [terrain_mat, props_mat, water_mat]:
		if m != null:
			(m as ShaderMaterial).set_shader_parameter("albedo_mode", 1.0 if on else 0.0)
	for m in _std_mats:
		(m as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if on else BaseMaterial3D.SHADING_MODE_PER_PIXEL


## Material estándar con sombreado por id de paleta (el modo albedo lo vuelve plano).
func mat(color_id: String, rough: float = 0.9, gain: float = 1.0, metallic: float = 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%.2f" % [color_id, rough, gain, metallic]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = pc(color_id, gain)
		m.roughness = rough
		m.metallic = metallic
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if albedo else BaseMaterial3D.SHADING_MODE_PER_PIXEL
		_mats[key] = m
		_std_mats.append(m)
	return _mats[key]


## Material de color de vértice (las figuras y los bultos del generador): sRGB de la paleta, sin brillo.
func vertex_mat(rough: float = 0.88) -> StandardMaterial3D:
	var key := "vertice|%.2f" % rough
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.roughness = rough
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if albedo else BaseMaterial3D.SHADING_MODE_PER_PIXEL
		_mats[key] = m
		_std_mats.append(m)
	return _mats[key]


## El contorno de las figuras (negro textil): se dibuja el casco inflado con las caras de adelante cortadas, queda solo el borde.
func outline_mat() -> StandardMaterial3D:
	if not _mats.has("contorno"):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = pc("negro_textil")
		m.cull_mode = BaseMaterial3D.CULL_FRONT
		_mats["contorno"] = m
	return _mats["contorno"]


## Material sin sombreado (anillos, luces, efectos): `alpha` < 1 lo vuelve translúcido y `additive` suma luz.
func flat_mat(color_id: String, alpha: float = 1.0, additive: bool = false, gain: float = 1.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%s|%.2f" % [color_id, alpha, str(additive), gain]
	if not _flat.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var c := pc(color_id, gain)
		m.albedo_color = Color(c.r, c.g, c.b, alpha)
		if alpha < 1.0 or additive:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if additive:
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			m.disable_fog = true
		_flat[key] = m
	return _flat[key]


# ---------------------------------------------------------------------------------------------------------------------
# Mallas básicas e instancias

func box_mesh(size: Vector3) -> BoxMesh:
	var key := "b%.2f,%.2f,%.2f" % [size.x, size.y, size.z]
	if not _meshes.has(key):
		var m := BoxMesh.new()
		m.size = size
		_meshes[key] = m
	return _meshes[key]


func cyl_mesh(top: float, bottom: float, height: float, segments: int = 12) -> CylinderMesh:
	var key := "c%.2f,%.2f,%.2f,%d" % [top, bottom, height, segments]
	if not _meshes.has(key):
		var m := CylinderMesh.new()
		m.top_radius = top
		m.bottom_radius = bottom
		m.height = height
		m.radial_segments = segments
		m.rings = 1
		_meshes[key] = m
	return _meshes[key]


func sphere_mesh(radius: float, segments: int = 12, rings: int = 6) -> SphereMesh:
	var key := "s%.2f,%d,%d" % [radius, segments, rings]
	if not _meshes.has(key):
		var m := SphereMesh.new()
		m.radius = radius
		m.height = radius * 2.0
		m.radial_segments = segments
		m.rings = rings
		_meshes[key] = m
	return _meshes[key]


func cached_mesh(key: String, maker: Callable) -> Mesh:
	if not _meshes.has(key):
		_meshes[key] = maker.call()
	return _meshes[key]


func inst(parent: Node, mesh: Mesh, pos: Vector3, material: Material, rot_deg: Vector3 = Vector3.ZERO, shadow: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = rot_deg
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Anillo plano sobre el suelo (un toro aplastado): marca de bando, estado de un objetivo, selección.
func flat_ring(parent: Node, radius: float, thickness: float, color_id: String, alpha: float = 1.0) -> MeshInstance3D:
	var key := "r%.2f,%.2f" % [radius, thickness]
	if not _meshes.has(key):
		var m := TorusMesh.new()
		m.outer_radius = radius
		m.inner_radius = maxf(radius - thickness, 0.01)
		m.rings = 36
		m.ring_segments = 6
		_meshes[key] = m
	var mi := inst(parent, _meshes[key], Vector3(0.0, 0.12, 0.0), flat_mat(color_id, alpha), Vector3.ZERO, false)
	mi.scale = Vector3(1.0, 0.12, 1.0)
	return mi


## Una malla del generador en un nodo: la superficie 0 con el material dado y, si la malla trae casco (superficie 1), esa con el material del contorno.
func part_node(parent: Node, name_: String, mesh: ArrayMesh, material: Material, shadow: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name_
	mi.mesh = mesh
	if mesh.get_surface_count() > 0:
		mi.set_surface_override_material(0, material)
	if mesh.get_surface_count() > 1:
		mi.set_surface_override_material(1, outline_mat())
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


# ---------------------------------------------------------------------------------------------------------------------
# Terreno: ventana, contexto y horizonte en un solo material

func _lin(a: float, b: float, steps: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for k in range(maxi(steps, 1) + 1):
		out.append(lerpf(a, b, float(k) / float(maxi(steps, 1))))
	return out


func _concat(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out := a.duplicate()
	for k in range(1 if not a.is_empty() else 0, b.size()):
		out.append(b[k])
	return out


## Malla de una grilla (xs × zs) de alturas `hs` (fila a fila sobre z): normales por diferencias centrales, falda opcional alrededor para tapar grietas.
func _tensor_mesh(xs: PackedFloat32Array, zs: PackedFloat32Array, hs: PackedFloat32Array, skirt_m: float) -> ArrayMesh:
	var nx := xs.size()
	var nz := zs.size()
	var count := nx * nz
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	verts.resize(count)
	normals.resize(count)
	for j in range(nz):
		var jm := maxi(j - 1, 0)
		var jp := mini(j + 1, nz - 1)
		var dz := maxf(zs[jp] - zs[jm], 0.001)
		for i in range(nx):
			var im := maxi(i - 1, 0)
			var ip := mini(i + 1, nx - 1)
			var k := j * nx + i
			verts[k] = Vector3(xs[i], hs[k], zs[j])
			var dhx := (hs[j * nx + ip] - hs[j * nx + im]) / maxf(xs[ip] - xs[im], 0.001)
			var dhz := (hs[jp * nx + i] - hs[jm * nx + i]) / dz
			normals[k] = Vector3(-dhx, 1.0, -dhz).normalized()
	var indices := PackedInt32Array()
	indices.resize((nx - 1) * (nz - 1) * 6)
	var n := 0
	for j in range(nz - 1):
		for i in range(nx - 1):
			var a := j * nx + i
			indices[n] = a
			indices[n + 1] = a + 1
			indices[n + 2] = a + nx
			indices[n + 3] = a + 1
			indices[n + 4] = a + nx + 1
			indices[n + 5] = a + nx
			n += 6
	if skirt_m > 0.0:
		var edge: Array = []
		for i in range(nx):
			edge.append(i)
		for j in range(1, nz):
			edge.append(j * nx + nx - 1)
		for i in range(nx - 2, -1, -1):
			edge.append((nz - 1) * nx + i)
		for j in range(nz - 2, 0, -1):
			edge.append(j * nx)
		var base := verts.size()
		for src in edge:
			verts.append(verts[int(src)] - Vector3(0.0, skirt_m, 0.0))
			normals.append(Vector3.UP)
		for k in range(edge.size()):
			var k2 := (k + 1) % edge.size()
			indices.append_array(PackedInt32Array([int(edge[k]), int(edge[k2]), base + k, int(edge[k2]), base + k2, base + k]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _sampled(xs: PackedFloat32Array, zs: PackedFloat32Array) -> PackedFloat32Array:
	var hs := PackedFloat32Array()
	hs.resize(xs.size() * zs.size())
	for j in range(zs.size()):
		for i in range(xs.size()):
			hs[j * xs.size() + i] = h(xs[i], zs[j])
	return hs


func _terrain_node(root: Node3D, name_: String, mesh: ArrayMesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name_
	mi.mesh = mesh
	mi.material_override = terrain_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi


func _field(kind: String) -> Dictionary:
	var f: Variant = null
	if terrain != null and terrain.has_method(kind):
		f = terrain.call(kind)
	if f is Dictionary and int((f as Dictionary).get("nx", 0)) >= 2 and int((f as Dictionary).get("nz", 0)) >= 2 and ((f as Dictionary).get("h", null) is PackedFloat32Array):
		return f
	if kind == "heightfield":  # sin terreno: un plano de respaldo de la misma forma
		var flat := PackedFloat32Array()
		flat.resize(226 * 164)
		flat.fill(FLAT_H)
		return {"nx": 226, "nz": 164, "cell": 4.0, "origin_x": 0.0, "origin_z": 0.0, "h": flat}
	var flat_c := PackedFloat32Array()
	flat_c.resize(121 * 91)
	flat_c.fill(FLAT_H)
	return {"nx": 121, "nz": 91, "cell": 30.0, "origin_x": -1350.0, "origin_z": -1025.0, "h": flat_c}


## Construye ventana, contexto y horizonte bajo `root` y las dos texturas de pesos. La calidad `baja` usa la mitad de resolución en la ventana.
func build_terrain(root: Node3D) -> void:
	var t0 := Time.get_ticks_usec()
	var hf := _field("heightfield")
	var cf := _field("context_field")
	var nx := int(hf.nx)
	var nz := int(hf.nz)
	var cell := float(hf.cell)
	win = Rect2(float(hf.origin_x), float(hf.origin_z), float(nx - 1) * cell, float(nz - 1) * cell)
	ctx = Rect2(float(cf.origin_x), float(cf.origin_z), float(int(cf.nx) - 1) * float(cf.cell), float(int(cf.nz) - 1) * float(cf.cell))
	var step := maxi(int(qcfg.get("window_step", 1)), 1)
	var xs := PackedFloat32Array()
	var zs := PackedFloat32Array()
	for i in range(0, nx, step):
		xs.append(win.position.x + float(i) * cell)
	if int((nx - 1) % step) != 0:
		xs.append(win.end.x)
	for j in range(0, nz, step):
		zs.append(win.position.y + float(j) * cell)
	if int((nz - 1) % step) != 0:
		zs.append(win.end.y)
	var hs := PackedFloat32Array()
	hs.resize(xs.size() * zs.size())
	var src: PackedFloat32Array = hf.h
	for j in range(zs.size()):
		var gj := mini(int(round((zs[j] - win.position.y) / cell)), nz - 1)
		for i in range(xs.size()):
			var gi := mini(int(round((xs[i] - win.position.x) / cell)), nx - 1)
			hs[j * xs.size() + i] = src[gj * nx + gi]
	_terrain_node(root, "terreno_ventana", _tensor_mesh(xs, zs, hs, SKIRT_M))
	var t_window := Time.get_ticks_usec()
	var triangles := (xs.size() - 1) * (zs.size() - 1) * 2
	# contexto: cuatro bandas de ~30 m pegadas a los bordes de la ventana (los vértices del borde de afuera son los de la fila 0 del horizonte)
	var ctx_step := float(cf.cell) * float(maxi(int(qcfg.get("context_step", 1)), 1))
	var xl_w := _lin(ctx.position.x, win.position.x, roundi((win.position.x - ctx.position.x) / ctx_step))
	var xl_e := _lin(win.end.x, ctx.end.x, roundi((ctx.end.x - win.end.x) / ctx_step))
	var xl_c := _lin(win.position.x, win.end.x, roundi(win.size.x / ctx_step))
	var zl_n := _lin(ctx.position.y, win.position.y, roundi((win.position.y - ctx.position.y) / ctx_step))
	var zl_s := _lin(win.end.y, ctx.end.y, roundi((ctx.end.y - win.end.y) / ctx_step))
	var zl_c := _lin(win.position.y, win.end.y, roundi(win.size.y / ctx_step))
	var zl_all := _concat(_concat(zl_n, zl_c), zl_s)
	for band in [["terreno_contexto_oeste", xl_w, zl_all], ["terreno_contexto_este", xl_e, zl_all], ["terreno_contexto_norte", xl_c, zl_n], ["terreno_contexto_sur", xl_c, zl_s]]:
		var bxs: PackedFloat32Array = band[1]
		var bzs: PackedFloat32Array = band[2]
		_terrain_node(root, str(band[0]), _tensor_mesh(bxs, bzs, _sampled(bxs, bzs), 0.0))
		triangles += (bxs.size() - 1) * (bzs.size() - 1) * 2
	var t_context := Time.get_ticks_usec()
	# horizonte: un anillo que arranca en el perímetro del contexto y sigue hasta ±8 km con crestas y estratos
	var top_x := _concat(_concat(xl_w, xl_c), xl_e)
	var left_z := zl_all
	var ring_pts := PackedVector2Array()
	var ring_dir := PackedVector2Array()
	for i in range(top_x.size() - 1):  # borde norte, de oeste a este
		ring_pts.append(Vector2(top_x[i], ctx.position.y))
		ring_dir.append(Vector2(-1.0 if i == 0 else 0.0, -1.0))
	for j in range(left_z.size() - 1):  # borde este, de norte a sur
		ring_pts.append(Vector2(ctx.end.x, left_z[j]))
		ring_dir.append(Vector2(1.0, -1.0 if j == 0 else 0.0))
	for i in range(top_x.size() - 1, 0, -1):  # borde sur, de este a oeste
		ring_pts.append(Vector2(top_x[i], ctx.end.y))
		ring_dir.append(Vector2(1.0 if i == top_x.size() - 1 else 0.0, 1.0))
	for j in range(left_z.size() - 1, 0, -1):  # borde oeste, de sur a norte
		ring_pts.append(Vector2(ctx.position.x, left_z[j]))
		ring_dir.append(Vector2(-1.0, 1.0 if j == left_z.size() - 1 else 0.0))
	_terrain_node(root, "terreno_horizonte", _ring_mesh(ring_pts, ring_dir))
	triangles += ring_pts.size() * (RING_ROWS.size() - 1) * 2
	build_stats = {"triangulos": triangles, "ventana_ms": snappedf(float(t_window - t0) / 1000.0, 0.1), "contexto_ms": snappedf(float(t_context - t_window) / 1000.0, 0.1),
		"horizonte_ms": snappedf(float(Time.get_ticks_usec() - t_context) / 1000.0, 0.1), "vertices_ventana": xs.size() * zs.size()}


## Altura del horizonte más allá del contexto: el valle sigue y sus paredes suben con la distancia (cerros erosionados cerca, cordillera suave lejos).
func ring_height(x: float, z: float, base: float, ox: float, oz: float) -> float:
	var far_k := smoothstep(0.0, 3200.0, ox)
	var z_k := smoothstep(0.0, 5200.0, oz)
	var edge_k := smoothstep(0.0, 260.0, maxf(ox, oz))
	var gullies := (_noise_gully.get_noise_2d(x, z) * 0.5 + 0.5)
	var swell := _noise_big.get_noise_2d(x, z) * 0.5 + 0.5
	var rise := 360.0 * far_k * (0.55 + 0.9 * swell) + 190.0 * z_k * (0.7 + 0.6 * swell) + 95.0 * smoothstep(0.0, 1800.0, ox + oz) * gullies
	return base + rise * edge_k


func _ring_mesh(pts: PackedVector2Array, dirs: PackedVector2Array) -> ArrayMesh:
	var count := pts.size()
	var rows := RING_ROWS.size()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	verts.resize(count * rows)
	normals.resize(count * rows)
	var base_h := PackedFloat32Array()
	base_h.resize(count)
	for k in range(count):
		base_h[k] = h(pts[k].x, pts[k].y)
	for j in range(rows):
		var r := float(RING_ROWS[j])
		for k in range(count):
			var p := pts[k] + dirs[k] * r
			var ox := maxf(maxf(ctx.position.x - p.x, p.x - ctx.end.x), 0.0)
			var oz := maxf(maxf(ctx.position.y - p.y, p.y - ctx.end.y), 0.0)
			verts[j * count + k] = Vector3(p.x, base_h[k] if j == 0 else ring_height(p.x, p.y, base_h[k], ox, oz), p.y)
	for j in range(rows):
		for k in range(count):
			var jm := maxi(j - 1, 0)
			var jp := mini(j + 1, rows - 1)
			var km := (k - 1 + count) % count
			var kp := (k + 1) % count
			var along := verts[j * count + kp] - verts[j * count + km]
			var across := verts[jp * count + k] - verts[jm * count + k]
			var n := along.cross(across)
			if n.y < 0.0:
				n = -n
			normals[j * count + k] = n.normalized() if n.length_squared() > 1.0e-9 else Vector3.UP
	var indices := PackedInt32Array()
	for j in range(rows - 1):
		for k in range(count):
			var k2 := (k + 1) % count
			var a := j * count + k
			var b := j * count + k2
			var c := (j + 1) * count + k
			var d := (j + 1) * count + k2
			indices.append_array(PackedInt32Array([a, b, c, b, d, c]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# ---------------------------------------------------------------------------------------------------------------------
# Texturas de pesos del suelo

## Dos texturas RGBA8 de un texel por nodo de la ventana: los pesos de las ocho capas del shader. Sale de `surface_at` (lo que dice el terreno: camino, patio, zanja,
## agua, regadío…) y, donde el terreno dice suelo seco, de la pendiente: arriba de ≈ 2° la ladera se cubre de churqui. Devuelve [splat_a, splat_b].
func build_splats() -> Array:
	var hf := _field("heightfield")
	var nx := int(hf.nx)
	var nz := int(hf.nz)
	var cell := float(hf.cell)
	var src: PackedFloat32Array = hf.h
	var a := PackedByteArray()
	var b := PackedByteArray()
	a.resize(nx * nz * 4)
	b.resize(nx * nz * 4)
	var ox := float(hf.origin_x)
	var oz := float(hf.origin_z)
	var has_surface := terrain != null and terrain.has_method("surface_at")
	for j in range(nz):
		var jm := maxi(j - 1, 0)
		var jp := mini(j + 1, nz - 1)
		for i in range(nx):
			var cls := str(terrain.call("surface_at", ox + float(i) * cell, oz + float(j) * cell)) if has_surface else "suelo_seco"
			var spec: Array = SURFACE_CHANNEL.get(cls, [0, 0])
			var k := (j * nx + i) * 4
			var weights_a := [0.0, 0.0, 0.0, 0.0]
			var weights_b := [0.0, 0.0, 0.0, 0.0]
			if int(spec[0]) == 0:
				weights_a[int(spec[1])] = 1.0
			else:
				weights_b[int(spec[1])] = 1.0
			if weights_a[0] > 0.5:  # suelo seco: la ladera se cubre de churqui y lo escarpado se vuelve piedra
				var im := maxi(i - 1, 0)
				var ip := mini(i + 1, nx - 1)
				var dx := (src[j * nx + ip] - src[j * nx + im]) / (cell * float(ip - im))
				var dz := (src[jp * nx + i] - src[jm * nx + i]) / (cell * float(jp - jm))
				var slope := sqrt(dx * dx + dz * dz)
				var chu := churqui_k(ox + float(i) * cell, oz + float(j) * cell, slope)
				var rock := clampf((slope - 0.16) / 0.12, 0.0, 1.0)
				weights_a[3] = chu * (1.0 - rock)
				weights_a[2] = rock
				weights_a[0] = 1.0 - weights_a[3] - weights_a[2]
			for c in range(4):
				a[k + c] = int(round(clampf(weights_a[c], 0.0, 1.0) * 255.0))
				b[k + c] = int(round(clampf(weights_b[c], 0.0, 1.0) * 255.0))
	var img_a := Image.create_from_data(nx, nz, false, Image.FORMAT_RGBA8, a)
	var img_b := Image.create_from_data(nx, nz, false, Image.FORMAT_RGBA8, b)
	var tex_a := ImageTexture.create_from_image(img_a)
	var tex_b := ImageTexture.create_from_image(img_b)
	terrain_mat.set_shader_parameter("splat_a", tex_a)
	terrain_mat.set_shader_parameter("splat_b", tex_b)
	terrain_mat.set_shader_parameter("win_rect", Vector4(win.position.x, win.position.y, win.size.x, win.size.y))
	return [tex_a, tex_b]


## Cercanía al río (0..1) en una grilla de ~60 m sobre todo el contexto: el shader la usa fuera de la ventana para el lecho claro, el barro de las orillas y los
## campos regados de la llanura (la foto de 1923: monte oscuro y lecho claro, después la llanura de cultivo).
func build_context_texture(river_pts: PackedVector2Array) -> ImageTexture:
	var w := 61
	var hgt := 46
	var data_px := PackedByteArray()
	data_px.resize(w * hgt * 4)
	var table := [[0.0, 1.0], [18.0, 0.9], [45.0, 0.72], [90.0, 0.5], [200.0, 0.26], [340.0, 0.06], [520.0, 0.0]]
	for j in range(hgt):
		for i in range(w):
			var p := Vector2(ctx.position.x + (float(i) + 0.5) / float(w) * ctx.size.x, ctx.position.y + (float(j) + 0.5) / float(hgt) * ctx.size.y)
			var best := 1.0e9
			for k in range(river_pts.size() - 1):
				best = minf(best, Geometry2D.get_closest_point_to_segment(p, river_pts[k], river_pts[k + 1]).distance_to(p))
			var value := 0.0
			for t in range(table.size() - 1):
				if best >= float(table[t][0]) and best < float(table[t + 1][0]):
					value = lerpf(float(table[t][1]), float(table[t + 1][1]), (best - float(table[t][0])) / (float(table[t + 1][0]) - float(table[t][0])))
					break
			var o := (j * w + i) * 4
			data_px[o] = int(round(clampf(value, 0.0, 1.0) * 255.0))
			data_px[o + 3] = 255
	var tex := ImageTexture.create_from_image(Image.create_from_data(w, hgt, false, Image.FORMAT_RGBA8, data_px))
	terrain_mat.set_shader_parameter("ctx_tex", tex)
	terrain_mat.set_shader_parameter("ctx_rect", Vector4(ctx.position.x, ctx.position.y, ctx.size.x, ctx.size.y))
	return tex


# ---------------------------------------------------------------------------------------------------------------------
# Río y cintas sobre el relieve

static func pt(p: Variant) -> Vector2:
	if p is Dictionary:
		return Vector2(float(p.get("x", 0.0)), float(p.get("z", 0.0)))
	if p is Array and p.size() >= 2:
		return Vector2(float(p[0]), float(p[1]))
	return p if p is Vector2 else Vector2.ZERO


func pts(list: Variant) -> PackedVector2Array:
	var out := PackedVector2Array()
	if list is Array:
		for p in list:
			out.append(pt(p))
	return out


## La traza del río con dos prolongaciones solo de aspecto: al norte sigue derecho hasta el borde del contexto y al sur-este vuelve hacia el sur como en la lámina 03.
func river_polyline() -> PackedVector2Array:
	var river: Variant = terrain.call("river") if terrain != null and terrain.has_method("river") else null
	var line := pts((river as Dictionary).get("pts", [])) if river is Dictionary else PackedVector2Array()
	if line.size() < 2:
		return line
	var out := PackedVector2Array()
	var head: Vector2 = line[0]
	var dir_n := (line[0] - line[1]).normalized()
	var reach := 1500.0
	for k in range(6, 0, -1):  # hacia el norte, con un poco de curva para no ser una raya
		var t := float(k) / 6.0
		out.append(head + dir_n.rotated(0.18 * t) * reach * t)
	out.append_array(line)
	var tail: Vector2 = line[line.size() - 1]
	var dir_s := (line[line.size() - 1] - line[line.size() - 2]).normalized()
	var cursor := tail
	var heading := dir_s
	for k in range(14):  # al salir por el este el cauce dobla hacia el sur (la lámina 03 lo muestra así)
		heading = heading.lerp(Vector2(-0.12, 1.0).normalized(), 0.28).normalized()
		cursor += heading * 110.0
		out.append(cursor)
	return out


## Cinta que sigue el relieve a lo largo de `line` (ancho `width` m, `raise` m sobre el suelo). Con `water`, la altura es plana de orilla a orilla (el nivel del agua) y
## lleva UV = (metros a lo largo, −1..1 a lo ancho) para el shader del agua.
func strip(parent: Node, line: PackedVector2Array, width: float, raise: float, material: Material, closed: bool = false, water: bool = false, name_: String = "") -> MeshInstance3D:
	var count := line.size()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var along := 0.0
	for k in range(count):
		var prev := line[(k - 1 + count) % count] if closed else line[maxi(k - 1, 0)]
		var next := line[(k + 1) % count] if closed else line[mini(k + 1, count - 1)]
		var tangent := (next - prev).normalized()
		var side := Vector2(-tangent.y, tangent.x) * width * 0.5
		if k > 0:
			along += line[k].distance_to(line[k - 1])
		var level := h(line[k].x, line[k].y) + raise
		for sign_ in [1.0, -1.0]:
			var q: Vector2 = line[k] + side * sign_
			verts.append(Vector3(q.x, level if water else h(q.x, q.y) + raise, q.y))
			normals.append(Vector3.UP)
			uvs.append(Vector2(along, sign_))
	for k in range(count if closed else count - 1):
		var a := k * 2
		var b := ((k + 1) % count) * 2
		indices.append_array(PackedInt32Array([a, a + 1, b, a + 1, b + 1, b]))  # sentido horario visto desde arriba: la cara de arriba es la frontal
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if material is StandardMaterial3D:
		(material as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := inst(parent, mesh, Vector3.ZERO, material, Vector3.ZERO, false)
	if name_ != "":
		mi.name = name_
	return mi


## El río: lecho claro de grava y, encima, el agua turbia con su shader. Devuelve la traza usada (para la textura del contexto).
func build_river(parent: Node3D) -> PackedVector2Array:
	var line := river_polyline()
	if line.size() < 2:
		return line
	var river: Dictionary = terrain.call("river")
	var width: Dictionary = river.get("bed_width_m", {})
	var bed_w := (float(width.get("min", 25.0)) + float(width.get("max", 40.0))) * 0.5
	var spec: Dictionary = (data.get("props", {}) as Dictionary).get("rio", {})
	var raise := float(spec.get("raise_m", 0.2))
	var bed_mat := mat(str(spec.get("bed_color", "piedra_gris")), 0.95, 1.18)
	strip(parent, line, bed_w * 1.15, raise - 0.1, bed_mat, false, false, "rio_lecho")
	strip(parent, line, bed_w * 0.62, raise + 0.05, water_mat, false, true, "rio_agua")
	return line


func circle(center: Vector2, radius: float, segments: int = 40) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in range(segments):
		var a := TAU * float(k) / float(segments)
		out.append(center + Vector2(cos(a), sin(a)) * radius)
	return out


## Un parche que sigue el relieve bajo el hito `node` (rectángulo `w × d` o, con `r` > 0, círculo), a `raise` m del suelo.
func patch(node: Node3D, w: float, d: float, r: float, raise: float, material: Material) -> MeshInstance3D:
	var cell := clampf(maxf(w, d) / 10.0, 2.0, 8.0)
	var nx := maxi(int(ceil(w / cell)), 1)
	var nz := maxi(int(ceil(d / cell)), 1)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for j in range(nz + 1):
		for i in range(nx + 1):
			var lx := -w * 0.5 + w * float(i) / float(nx)
			var lz := -d * 0.5 + d * float(j) / float(nz)
			var at := node.position + node.transform.basis * Vector3(lx, 0.0, lz)
			verts.append(Vector3(lx, h(at.x, at.z) - node.position.y + raise, lz))
			normals.append(Vector3.UP)
	for j in range(nz):
		for i in range(nx):
			if r > 0.0 and Vector2(-w * 0.5 + w * (float(i) + 0.5) / float(nx), -d * 0.5 + d * (float(j) + 0.5) / float(nz)).length() > r:
				continue
			var a := j * (nx + 1) + i
			indices.append_array(PackedInt32Array([a, a + 1, a + nx + 1, a + 1, a + nx + 2, a + nx + 1]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	if indices.size() >= 3:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if material is StandardMaterial3D:
		(material as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	return inst(node, mesh, Vector3.ZERO, material, Vector3.ZERO, false)


# ---------------------------------------------------------------------------------------------------------------------
# Escala en pantalla (las fichas y las luces se leen a cualquier distancia)

func screen_scale(host: Node) -> float:
	if host == null or not host.is_inside_tree():
		return 1.0
	var scale_y: float = host.get_viewport().get_screen_transform().get_scale().y
	return scale_y if scale_y >= 0.2 else 1.0


static func aspect(cam: Camera3D) -> float:
	if cam != null and cam.is_inside_tree():
		var size := cam.get_viewport().get_visible_rect().size
		if size.y > 0.0:
			return size.x / size.y
	return 16.0 / 9.0


static func vfov(cam: Camera3D) -> float:
	if cam == null:
		return 46.0
	if cam.keep_aspect == Camera3D.KEEP_HEIGHT:
		return cam.fov
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(cam.fov) * 0.5) / aspect(cam)))


## Metros por píxel (vertical) de un punto del mundo: 2·profundidad·tan(fov/2) / alto del cuadro.
func meters_per_px_at(cam: Camera3D, pos: Vector3) -> float:
	if cam == null or not cam.is_inside_tree():
		return 0.1
	var depth := maxf((pos - cam.global_position).dot(-cam.global_transform.basis.z), 1.0)
	return 2.0 * depth * tan(deg_to_rad(vfov(cam)) * 0.5) / maxf(cam.get_viewport().get_visible_rect().size.y, 1.0)
