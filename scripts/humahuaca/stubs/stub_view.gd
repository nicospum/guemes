extends Node3D
## Stub de la vista del nivel «humahuaca» (CONTRATO 3.4 y 7). Dueña: visual. Primer commit de la pista (R1.0): queda CONGELADO desde el merge
## (se corrige solo por addendum) y no depende del código real de la pista: solo importa los vocabularios (V19). Cumple la firma completa de 3.4.
## Dibuja con primitivas y StandardMaterial3D (sin shaders propios): terreno con la altura de `rules.terrain().height_at` (ventana y contexto, con falda
## para que no queden grietas), río, una caja con la huella de cada hito, tapias y zanjas, una ficha de silueta propia por agrupación (de tamaño fijo en
## pantalla), luces de la guardia que se ven de lejos, defensores, botín y efectos. Lee SOLO `rules.render_state()`, `rules.environment()`,
## `rules.terrain()` y su propio JSON; la cámara es de la UI. Convenciones: +x este, +z sur (norte = −z), y en metros sobre el cero local; `yaw_deg` es un
## rumbo (horario desde el norte, visto en el mapa); un rectángulo de hito tiene `w` sobre +x y `d` sobre +z antes de girar `yaw_deg`;
## `environment().time_of_day` es 0 = noche plena, 0,5 = alba y 1 = día pleno (vocab_view.TIME_OF_DAY).

const V = preload("res://scripts/humahuaca/humahuaca_vocab.gd")
const VV = preload("res://scripts/humahuaca/view/vocab_view.gd")

signal minimap_changed

const FLAT_H := 17.0
const WORLD_DEFAULT := Vector2(900.0, 650.0)
const CONTEXT_RECT := Rect2(-1350.0, -1050.0, 3600.0, 2750.0)
const CONTEXT_STEP := 50.0
const CAMERA_MARGIN_M := 120.0
const PICK_UNIT_PX := 55.0
const PICK_FRONT_PX := 60.0
const PICK_LANDMARK_PX := 40.0
const MAX_THINGS := 48
const MAX_RAY_M := 6000.0
const MAX_STRETCH := 2.3
const BURY_M := 0.3
const SURFACE_COLOR := {"suelo_seco": "suelo_seco", "sedimento_humedo": "sedimento_humedo", "piedra": "piedra_gris", "churqui": "churqui",
	"irrigado": "vegetacion_irrigada", "agua": "agua_turbia", "camino": "suelo_seco", "patio": "suelo_seco", "zanja": "sedimento_humedo", "muro": "adobe"}
const STATE_RING := {"guardado": "blanco_textil", "alertado": "oro_laton", "en_alarma": "rojo_reservado", "asaltado": "borgona_hipotetica", "tomado": "celeste_produccion"}
const LOOT_COLOR := {"polvora": "madera_oscura", "canones": "hierro", "fusiles": "madera_oscura", "viveres": "lana_natural", "plata": "oro_laton"}
const LIGHT_HEIGHT := {"brasero": 1.6, "ventana": 3.0, "candil": 2.0, "fogata": 1.1}

var selected_ids: Array = []
var unit_nodes: Dictionary = {}
var unit_labels: Dictionary = {}
var build_ms := 0.0  ## lo que tardó el último build() (lo informa el recorrido de QA)

var _rules = null
var _terrain = null
var _data: Dictionary = {}
var _quality := "media"
var _qcfg: Dictionary = {}
var _world := WORLD_DEFAULT
var _palette: Dictionary = {}
var _mats: Dictionary = {}
var _flat_mats: Dictionary = {}
var _meshes: Dictionary = {}
var _roots: Dictionary = {}
var _env: Environment
var _sky_mat: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _ground_mat: StandardMaterial3D
var _outline_mat: StandardMaterial3D
var _halo_mat: StandardMaterial3D
var _albedo := false
var _override_tod := -1.0
var _override_rain := 0.0
var _tod := 0.0
var _rain := 0.0
var _env_dirty := true
var _landmarks: Array = []
var _lm_by_id: Dictionary = {}
var _lm_nodes: Dictionary = {}
var _layers: Dictionary = {}
var _tokens: Dictionary = {}
var _scaled: Array = []
var _fx: Array = []
var _minimap_cache: Dictionary = {}
var _version := -2
var _time := 0.0
var _omni_count := 0

# ---------------------------------------------------------------------------------------------------------------------
# Construcción

func build(rules: RefCounted, quality: String = "media") -> void:
	var started := Time.get_ticks_usec()
	_clear_scene()
	_rules = rules
	_quality = quality if VV.QUALITY.has(quality) else "media"
	_data = V.load_json(V.VISUAL_PATH)
	_palette.clear()
	for entry in _data.get("palette", []):
		if entry is Dictionary:
			_palette[str(entry.get("id", ""))] = Color(str(entry.get("hex", "#808080")))
	_qcfg = (_data.get("quality", {}) as Dictionary).get(_quality, {})
	_terrain = rules.call("terrain") if rules != null and rules.has_method("terrain") else null
	_world = WORLD_DEFAULT
	if rules != null and rules.has_method("map_size"):
		var size: Variant = rules.call("map_size")
		if size is Vector2 and size.x > 100.0 and size.y > 100.0:
			_world = size
	for layer in VV.LAYERS:
		_layers[layer] = layer != "exposure"
	for root_name in ["Terreno", "Rasgos", "Hitos", "Fichas", "Etiquetas", "Defensores", "Botin", "Luces", "Anillos", "Efectos"]:
		var node := Node3D.new()
		node.name = root_name
		add_child(node)
		_roots[root_name] = node
	_make_environment()
	_build_ground()
	_build_river()
	_build_features()
	_build_landmarks()
	_build_tokens()
	_apply_layers()
	_env_dirty = true
	_version = -2
	update_state(0.0)
	build_ms = float(Time.get_ticks_usec() - started) / 1000.0
	minimap_changed.emit()

func _clear_scene() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	_roots.clear()
	_mats.clear()
	_flat_mats.clear()
	_meshes.clear()
	_halo_mat = null
	_landmarks = []
	_lm_by_id.clear()
	_lm_nodes.clear()
	_tokens.clear()
	_scaled = []
	_fx = []
	_minimap_cache.clear()
	unit_nodes = {}
	unit_labels = {}
	_omni_count = 0

## Color de la paleta por id (con ganancia opcional; nunca un HEX suelto).
func _pc(id: String, gain: float = 1.0) -> Color:
	var c: Color = _palette.get(id, Color(0.5, 0.5, 0.5))
	return Color(minf(c.r * gain, 1.0), minf(c.g * gain, 1.0), minf(c.b * gain, 1.0), 1.0)

func _make_environment() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	_sky_mat = ProceduralSkyMaterial.new()
	sky.sky_material = _sky_mat
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.tonemap_mode = Environment.TONE_MAPPER_ACES
	_env.fog_enabled = true
	_env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	_env.fog_sky_affect = float((_data.get("fog", {}) as Dictionary).get("sky_affect", 0.55))
	var world_env := WorldEnvironment.new()
	world_env.name = "Ambiente"
	world_env.environment = _env
	add_child(world_env)
	_sun = DirectionalLight3D.new()
	_sun.name = "Sol"
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_sun.directional_shadow_max_distance = 1100.0
	_sun.directional_shadow_blend_splits = true
	_sun.shadow_bias = 0.25
	_sun.shadow_normal_bias = 3.5
	add_child(_sun)
	_outline_mat = StandardMaterial3D.new()
	_outline_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_outline_mat.albedo_color = _pc("negro_textil")
	_outline_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	_outline_mat.grow = true
	_outline_mat.grow_amount = float(((_data.get("materials", {}) as Dictionary).get("contorno", {}) as Dictionary).get("grow_m", 0.1))

# ---------------------------------------------------------------------------------------------------------------------
# Materiales, mallas compartidas y ayudas

func _mat(color_id: String, rough: float = 0.9, gain: float = 1.0, metallic: float = 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%.2f" % [color_id, rough, gain, metallic]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = _pc(color_id, gain)
		m.roughness = rough
		m.metallic = metallic
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if _albedo else BaseMaterial3D.SHADING_MODE_PER_PIXEL
		_mats[key] = m
	return _mats[key]

## Material sin sombreado (anillos, luces, efectos): `alpha` < 1 lo vuelve translúcido y `additive` suma luz.
func _flat_mat(color_id: String, alpha: float = 1.0, additive: bool = false, gain: float = 1.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%s|%.2f" % [color_id, alpha, str(additive), gain]
	if not _flat_mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var c := _pc(color_id, gain)
		m.albedo_color = Color(c.r, c.g, c.b, alpha)
		if alpha < 1.0 or additive:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if additive:
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			m.disable_fog = true
		_flat_mats[key] = m
	return _flat_mats[key]

func _box_mesh(size: Vector3) -> BoxMesh:
	var key := "b%.2f,%.2f,%.2f" % [size.x, size.y, size.z]
	if not _meshes.has(key):
		var m := BoxMesh.new()
		m.size = size
		_meshes[key] = m
	return _meshes[key]

func _cyl_mesh(top: float, bottom: float, height: float) -> CylinderMesh:
	var key := "c%.2f,%.2f,%.2f" % [top, bottom, height]
	if not _meshes.has(key):
		var m := CylinderMesh.new()
		m.top_radius = top
		m.bottom_radius = bottom
		m.height = height
		m.radial_segments = 12
		m.rings = 1
		_meshes[key] = m
	return _meshes[key]

func _sphere_mesh(radius: float) -> SphereMesh:
	var key := "s%.2f" % radius
	if not _meshes.has(key):
		var m := SphereMesh.new()
		m.radius = radius
		m.height = radius * 2.0
		m.radial_segments = 12
		m.rings = 6
		_meshes[key] = m
	return _meshes[key]

func _inst(parent: Node, mesh: Mesh, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO, shadow: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

## Anillo plano sobre el suelo (un toro aplastado): marca de bando, estado de un objetivo, selección.
func _flat_ring(parent: Node, radius: float, thickness: float, color_id: String, alpha: float = 1.0) -> MeshInstance3D:
	var key := "r%.2f,%.2f" % [radius, thickness]
	if not _meshes.has(key):
		var m := TorusMesh.new()
		m.outer_radius = radius
		m.inner_radius = maxf(radius - thickness, 0.01)
		m.rings = 36
		m.ring_segments = 6
		_meshes[key] = m
	var mi := _inst(parent, _meshes[key], Vector3(0.0, 0.12, 0.0), _flat_mat(color_id, alpha), Vector3.ZERO, false)
	mi.scale = Vector3(1.0, 0.12, 1.0)
	return mi

## Una pieza de figura: con contorno oscuro (casco invertido) salvo en la calidad baja.
func _part(parent: Node, mesh: Mesh, pos: Vector3, color_id: String, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := _inst(parent, mesh, pos, _mat(color_id, 0.85), rot_deg, false)
	if bool(_qcfg.get("outlines", true)):
		var key := "contorno|" + color_id
		if not _mats.has(key):
			var copy: StandardMaterial3D = _mat(color_id, 0.85).duplicate()
			copy.next_pass = _outline_mat
			_mats[key] = copy
		mi.material_override = _mats[key]
	return mi

func _h(x: float, z: float) -> float:
	return float(_terrain.height_at(x, z)) if _terrain != null else FLAT_H

func _pt(p: Variant) -> Vector2:
	if p is Dictionary:
		return Vector2(float(p.get("x", 0.0)), float(p.get("z", 0.0)))
	if p is Array and p.size() >= 2:
		return Vector2(float(p[0]), float(p[1]))
	return p if p is Vector2 else Vector2.ZERO

func _pts(list: Variant) -> PackedVector2Array:
	var out := PackedVector2Array()
	if list is Array:
		for p in list:
			out.append(_pt(p))
	return out

# ---------------------------------------------------------------------------------------------------------------------
# Terreno, río y rasgos

func _ground_color(x: float, z: float) -> Color:
	var cls := str(_terrain.surface_at(x, z)) if _terrain != null and _terrain.has_method("surface_at") else "suelo_seco"
	var c := _pc(str(SURFACE_COLOR.get(cls, "suelo_seco")), 1.1 if cls == "camino" else (0.92 if cls == "patio" else 1.0))
	var f := 1.0 + 0.07 * (sin(x * 0.037 + 1.3) * sin(z * 0.043 + 0.7) * 0.5 + sin(x * 0.11 + z * 0.083) * 0.25)
	return Color(c.r * f, c.g * f, c.b * f, 1.0)

## Malla de una grilla regular de alturas (`height_at`): color por vértice, normales por diferencias centrales, falda opcional y un hueco opcional.
func _grid_mesh(origin: Vector2, step: float, nx: int, nz: int, skirt_m: float, hole: Rect2) -> ArrayMesh:
	var count := nx * nz
	var heights := PackedFloat32Array()
	heights.resize(count)
	for j in range(nz):
		for i in range(nx):
			heights[j * nx + i] = _h(origin.x + float(i) * step, origin.y + float(j) * step)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	verts.resize(count)
	normals.resize(count)
	colors.resize(count)
	for j in range(nz):
		for i in range(nx):
			var idx := j * nx + i
			var x := origin.x + float(i) * step
			var z := origin.y + float(j) * step
			verts[idx] = Vector3(x, heights[idx], z)
			normals[idx] = Vector3(heights[j * nx + maxi(i - 1, 0)] - heights[j * nx + mini(i + 1, nx - 1)], 2.0 * step,
				heights[maxi(j - 1, 0) * nx + i] - heights[mini(j + 1, nz - 1) * nx + i]).normalized()
			colors[idx] = _ground_color(x, z)
	var indices := PackedInt32Array()
	indices.resize((nx - 1) * (nz - 1) * 6)
	var n := 0
	for j in range(nz - 1):
		for i in range(nx - 1):
			if hole.size != Vector2.ZERO and hole.has_point(Vector2(origin.x + (float(i) + 0.5) * step, origin.y + (float(j) + 0.5) * step)):
				continue
			var a := j * nx + i
			indices[n] = a
			indices[n + 1] = a + 1
			indices[n + 2] = a + nx
			indices[n + 3] = a + 1
			indices[n + 4] = a + nx + 1
			indices[n + 5] = a + nx
			n += 6
	indices.resize(n)
	if skirt_m > 0.0:  # una falda vertical alrededor de la ventana tapa las grietas contra el contexto (el borde de 5 m contra el de 50 m)
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
			colors.append(colors[int(src)])
		for k in range(edge.size()):
			var k2 := (k + 1) % edge.size()
			indices.append_array(PackedInt32Array([int(edge[k]), int(edge[k2]), base + k, int(edge[k2]), base + k2, base + k]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _build_ground() -> void:
	_ground_mat = StandardMaterial3D.new()
	_ground_mat.vertex_color_use_as_albedo = true
	_ground_mat.vertex_color_is_srgb = true  # los colores de vértice salen de la paleta (sRGB): sin esto la tierra se vería más clara que su HEX
	_ground_mat.roughness = float(((_data.get("materials", {}) as Dictionary).get("terreno", {}) as Dictionary).get("roughness", 0.96))
	_ground_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ground_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if _albedo else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	var step := float(_qcfg.get("terrain_step_m", 5.0))
	var window := _inst(_roots.Terreno, _grid_mesh(Vector2.ZERO, step, int(round(_world.x / step)) + 1, int(round(_world.y / step)) + 1, 3.0, Rect2()), Vector3.ZERO, _ground_mat)
	window.name = "terreno_ventana"
	var cnx := int(round(CONTEXT_RECT.size.x / CONTEXT_STEP)) + 1
	var cnz := int(round(CONTEXT_RECT.size.y / CONTEXT_STEP)) + 1
	var context := _inst(_roots.Terreno, _grid_mesh(CONTEXT_RECT.position, CONTEXT_STEP, cnx, cnz, 0.0, Rect2(Vector2.ZERO, _world)), Vector3.ZERO, _ground_mat, Vector3.ZERO, false)
	context.name = "terreno_contexto"

func _build_river() -> void:
	var river: Variant = _terrain.river() if _terrain != null and _terrain.has_method("river") else null
	var pts := _pts((river as Dictionary).get("pts", [])) if river is Dictionary else PackedVector2Array()
	if pts.size() < 2:
		return
	var width: Dictionary = (river as Dictionary).get("bed_width_m", {})
	var bed_w := (float(width.get("min", 25.0)) + float(width.get("max", 40.0))) * 0.5
	var spec: Dictionary = (_data.get("props", {}) as Dictionary).get("rio", {})
	var raise := float(spec.get("raise_m", 0.2))
	var bed := _strip(_roots.Rasgos, pts, bed_w, raise - 0.08, _mat(str(spec.get("bed_color", "piedra_gris")), 0.95))
	bed.name = "rio_lecho"
	var water := _strip(_roots.Rasgos, pts, bed_w * 0.55, raise, _mat(str(spec.get("color", "agua_turbia")), 0.35))
	water.name = "rio_agua"

## Una cinta que sigue el relieve a lo largo de `pts` (río, caminos, zanjas, anillos): `width` m de ancho y `raise` m sobre el suelo. Sus vértices
## están en coordenadas del mundo: el padre tiene que estar en el origen.
func _strip(parent: Node, pts: PackedVector2Array, width: float, raise: float, material: Material, closed: bool = false) -> MeshInstance3D:
	var count := pts.size()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for k in range(count):
		var prev := pts[(k - 1 + count) % count] if closed else pts[maxi(k - 1, 0)]
		var next := pts[(k + 1) % count] if closed else pts[mini(k + 1, count - 1)]
		var side := Vector2(-(next - prev).normalized().y, (next - prev).normalized().x) * width * 0.5
		for sign_ in [1.0, -1.0]:
			var q: Vector2 = pts[k] + side * sign_
			verts.append(Vector3(q.x, _h(q.x, q.y) + raise, q.y))
			normals.append(Vector3.UP)
	for k in range(count if closed else count - 1):
		var a := k * 2
		var b := ((k + 1) % count) * 2
		indices.append_array(PackedInt32Array([a, b, a + 1, a + 1, b, b + 1]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if material is StandardMaterial3D:
		(material as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	return _inst(parent, mesh, Vector3.ZERO, material, Vector3.ZERO, false)

func _circle(center: Vector2, radius: float, segments: int = 40) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in range(segments):
		var a := TAU * float(k) / float(segments)
		out.append(center + Vector2(cos(a), sin(a)) * radius)
	return out

## Un parche que sigue el relieve bajo el hito `node` (rectángulo `w × d` o, con `r` > 0, círculo), a `raise` m del suelo.
func _patch(node: Node3D, w: float, d: float, r: float, raise: float, material: Material) -> MeshInstance3D:
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
			verts.append(Vector3(lx, _h(at.x, at.z) - node.position.y + raise, lz))
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
	return _inst(node, mesh, Vector3.ZERO, material, Vector3.ZERO, false)

## Un muro o franja recto entre `a` y `b` (en tramos de ≤ 20 m para seguir el relieve).
func _segment_box(a: Vector2, b: Vector2, height: float, thick: float, color_id: String, lift: float, gain: float = 1.0) -> void:
	var parts := maxi(1, int(ceil(a.distance_to(b) / 20.0)))
	for k in range(parts):
		var p0 := a.lerp(b, float(k) / float(parts))
		var p1 := a.lerp(b, float(k + 1) / float(parts))
		var mid := (p0 + p1) * 0.5
		var ground := (_h(p0.x, p0.y) + _h(p1.x, p1.y) + _h(mid.x, mid.y)) / 3.0
		var mi := _inst(_roots.Rasgos, _box_mesh(Vector3(p0.distance_to(p1) + 0.05, height, thick)), Vector3(mid.x, ground + lift + height * 0.5 - 0.15, mid.y), _mat(color_id, 0.95, gain))
		mi.rotation.y = -atan2(p1.y - p0.y, p1.x - p0.x)

func _build_features() -> void:
	if _terrain == null or not _terrain.has_method("features"):
		return
	var props: Dictionary = _data.get("props", {})
	var tapia: Dictionary = props.get("tapia", {})
	var strips := {"zanja": [1.6, "zanja", 0.8], "acequia": [1.2, "zanja", 0.8], "camino": [5.0, "camino", 1.12], "calle": [6.0, "camino", 1.12]}
	for kind in ["tapia", "barricada", "zanja", "acequia", "camino", "calle"]:
		for f in _terrain.features(kind):
			if not (f is Dictionary):
				continue
			var pts := _pts(f.get("pts", []))
			if kind in strips:
				var s: Array = strips[kind]
				var spec: Dictionary = props.get(str(s[1]), {})
				_strip(_roots.Rasgos, pts, maxf(float(f.get("width_m", s[0])), 1.2), float(spec.get("raise_m", 0.08)), _mat(str(spec.get("color", "suelo_seco")), 0.95, float(s[2])))
				continue
			for k in range(pts.size() - 1):
				if kind == "barricada":
					_segment_box(pts[k], pts[k + 1], 1.3, 1.0, "madera_oscura", 0.0)
				else:
					var height := float(f.get("height_m", 2.0))
					var thick := float(f.get("thickness_m", 0.5))
					_segment_box(pts[k], pts[k + 1], height, thick, str(tapia.get("color", "adobe")), 0.0)
					_segment_box(pts[k], pts[k + 1], float(tapia.get("cap_m", 0.2)), thick + 0.2, str(tapia.get("cap_color", "paja")), height - 0.1)

# ---------------------------------------------------------------------------------------------------------------------
# Hitos: una caja con la huella de cada uno

func _prop_spec(id: String, type_name: String) -> Dictionary:
	var props: Dictionary = _data.get("props", {})
	var by_id: Dictionary = props.get("por_id", {})
	if by_id.has(id):
		return by_id[id]
	return (props.get("por_tipo", {}) as Dictionary).get(type_name, {"builder": "caja", "color": "adobe", "default_height_m": 2.0})

## {center, w, d, r, yaw}: la huella de un hito en el plano (un polígono se reduce a su caja envolvente, sin giro).
func _footprint(lm: Dictionary) -> Dictionary:
	var fp: Variant = lm.get("footprint", {})
	var out := {"center": Vector2(float(lm.get("x", 0.0)), float(lm.get("z", 0.0))), "w": 6.0, "d": 6.0, "r": 0.0, "yaw": float(lm.get("yaw_deg", 0.0))}
	if not (fp is Dictionary):
		return out
	if fp.has("poly"):
		var poly := _pts(fp.poly)
		if poly.size() >= 3:
			var lo := poly[0]
			var hi := poly[0]
			for p in poly:
				lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
				hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
			out.center = (lo + hi) * 0.5
			out.w = maxf(hi.x - lo.x, 1.0)
			out.d = maxf(hi.y - lo.y, 1.0)
			out.yaw = 0.0
	elif fp.has("w"):
		out.w = maxf(float(fp.w), 0.5)
		out.d = maxf(float(fp.get("d", fp.w)), 0.5)
	elif fp.has("r"):
		out.r = maxf(float(fp.r), 0.5)
		out.w = float(out.r) * 2.0
		out.d = float(out.r) * 2.0
	return out

## Las cuatro esquinas de la huella en el mundo (x, z), con el giro aplicado.
func _footprint_corners(fp: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array()
	var c: Vector2 = fp.center
	var yaw := deg_to_rad(float(fp.yaw))
	for k in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var lx: float = k.x * float(fp.w) * 0.5
		var lz: float = k.y * float(fp.d) * 0.5
		out.append(c + Vector2(lx * cos(yaw) - lz * sin(yaw), lx * sin(yaw) + lz * cos(yaw)))
	return out

func _build_landmarks() -> void:
	var list: Variant = _terrain.landmarks({}) if _terrain != null and _terrain.has_method("landmarks") else []
	if not (list is Array):
		return
	for lm in list:
		if lm is Dictionary and lm.has("id") and lm.has("x") and lm.has("z"):
			_landmarks.append(lm)
			_lm_by_id[str(lm.id)] = lm
			_build_landmark(lm)

func _build_landmark(lm: Dictionary) -> void:
	var id := str(lm.id)
	var spec := _prop_spec(id, str(lm.get("type", "hito")))
	var builder := str(spec.get("builder", "caja"))
	if builder == "ninguno":
		return
	var fp := _footprint(lm)
	var ground := _h(float(fp.center.x), float(fp.center.y))
	for p in _footprint_corners(fp):
		ground = minf(ground, _h(p.x, p.y))
	var node := Node3D.new()
	node.name = "hito_" + id
	node.position = Vector3(fp.center.x, ground, fp.center.y)
	node.rotation.y = -deg_to_rad(float(fp.yaw))
	_roots.Hitos.add_child(node)
	_lm_nodes[id] = node
	var hgt := float(lm.get("height_m", 0.0))
	if hgt <= 0.0:
		hgt = float(spec.get("default_height_m", 2.0))
	var w := float(fp.w)
	var d := float(fp.d)
	var color_id := str(spec.get("color", "adobe"))
	var trim_id := str(spec.get("trim_color", "madera_oscura"))
	var roof_id := str(spec.get("roof_color", "paja"))
	if builder in ["caja_con_techo", "templo_nave", "torre", "plataforma", "patio_muros"]:  # la huella del edificio: una mancha oscura de tierra que lo separa del suelo
		_patch(node, w + 3.0, d + 3.0, 0.0, 0.07, _mat("sedimento_humedo", 0.95, 0.9)).name = "huella"
	match builder:
		"caja_con_techo":
			var body := maxf(hgt - 0.5, 0.8)
			_inst(node, _box_mesh(Vector3(w, body + BURY_M, d)), Vector3(0.0, (body - BURY_M) * 0.5, 0.0), _mat(color_id))
			_inst(node, _box_mesh(Vector3(w + 0.7, 0.5, d + 0.7)), Vector3(0.0, body + 0.25, 0.0), _mat(roof_id, 1.0))
		"templo_nave":  # nave simple encalada a dos aguas: sin torres, sin fachada de 1880
			var eave := hgt * float(spec.get("eave_ratio", 0.78))
			_inst(node, _box_mesh(Vector3(w, eave + BURY_M, d)), Vector3(0.0, (eave - BURY_M) * 0.5, 0.0), _mat(color_id, 0.9))
			var roof := PrismMesh.new()
			roof.size = Vector3(d + 1.2, hgt - eave, w + 1.2)
			_inst(node, roof, Vector3(0.0, eave + (hgt - eave) * 0.5, 0.0), _mat(roof_id, 1.0), Vector3(0.0, 90.0, 0.0))
			_inst(node, _box_mesh(Vector3(1.6, 2.4, 0.3)), Vector3(w * 0.5 + 0.1, 1.2, 0.0), _mat(trim_id), Vector3(0.0, 90.0, 0.0))
		"torre":  # fuste, plataforma a 0,9 de la altura y cuatro pilares de parapeto
			var shaft := hgt * 0.9
			_inst(node, _box_mesh(Vector3(w, shaft + BURY_M, d)), Vector3(0.0, (shaft - BURY_M) * 0.5, 0.0), _mat(color_id))
			_inst(node, _box_mesh(Vector3(w + 1.8, 0.5, d + 1.8)), Vector3(0.0, shaft + 0.25, 0.0), _mat(trim_id))
			for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				_inst(node, _box_mesh(Vector3(0.4, hgt - shaft, 0.4)), Vector3(corner.x * (w + 1.4) * 0.5, shaft + 0.5 + (hgt - shaft) * 0.5, corner.y * (d + 1.4) * 0.5), _mat(trim_id))
		"plataforma":  # la batería: losa de tierra con las piezas sobre cureñas
			var slab := float(spec.get("slab_m", 0.9))
			_inst(node, _box_mesh(Vector3(w, slab + BURY_M, d)), Vector3(0.0, (slab - BURY_M) * 0.5, 0.0), _mat(color_id, 0.95))
			var pieces := int(spec.get("pieces", 3))
			for k in range(pieces):
				var z := ((float(k) + 0.5) / float(pieces) - 0.5) * d * 0.8
				_inst(node, _cyl_mesh(0.3, 0.38, 1.9), Vector3(-w * 0.18, slab + 0.5, z), _mat(str(spec.get("iron_color", "hierro")), 0.55, 1.0, 0.6), Vector3(0.0, 0.0, 90.0)).name = "pieza_%d" % (k + 1)
				_inst(node, _box_mesh(Vector3(1.4, 0.5, 0.9)), Vector3(-w * 0.18 + 0.4, slab + 0.25, z), _mat(trim_id))
		"patio_muros":  # cuatro muros con una entrada de 4 m en cada lado largo
			var wall_h := float(spec.get("wall_height_m", 2.4))
			var th := float(spec.get("wall_thickness_m", 0.6))
			var seg := (d - 4.0) * 0.5
			for z in [-d * 0.5, d * 0.5]:
				_inst(node, _box_mesh(Vector3(w, wall_h, th)), Vector3(0.0, wall_h * 0.5 - 0.15, z), _mat(color_id))
			for side in [-1.0, 1.0]:
				for end in [-1.0, 1.0]:
					_inst(node, _box_mesh(Vector3(th, wall_h, seg)), Vector3(side * w * 0.5, wall_h * 0.5 - 0.15, end * (2.0 + seg * 0.5)), _mat(color_id))
		"plano":
			var alpha := float(spec.get("alpha", 1.0))
			_patch(node, w, d, float(fp.r), float(spec.get("raise_m", 0.12)), _flat_mat(color_id, alpha) if alpha < 1.0 else _mat(color_id, 0.95, float(spec.get("gain", 1.0))))
		"mojon":  # un mojón de piedra con un anillo de color que sigue el relieve (acceso, salida, entrada)
			_inst(node, _cyl_mesh(0.4, 1.2, 2.0), Vector3(0.0, 0.8, 0.0), _mat(color_id))
			_strip(_roots.Hitos, _circle(Vector2(node.position.x, node.position.z), maxf(float(fp.r), 4.0)), 1.6, 0.25, _flat_mat(str(spec.get("ring_color", "oro_laton")), 0.9), true)
		_:
			_inst(node, _box_mesh(Vector3(w, hgt + BURY_M, d)), Vector3(0.0, (hgt - BURY_M) * 0.5, 0.0), _mat(color_id))

# ---------------------------------------------------------------------------------------------------------------------
# Fichas: una silueta propia por agrupación, de tamaño fijo en pantalla

func _build_tokens() -> void:
	var cfg: Dictionary = _data.get("tokens", {})
	for index in range(V.GROUPS.size()):
		var id: String = V.GROUPS[index]
		var spec: Dictionary = cfg.get(id, {})
		var root := Node3D.new()
		root.name = "ficha_" + id
		root.visible = false
		_roots.Fichas.add_child(root)
		var shape := str(spec.get("shape", "infante_fusil"))
		var dims := _token_shape(root, shape, spec)
		var base_h := dims.x
		var ring_color := str(spec.get("ring_color", "celeste_produccion"))
		var ring_r := dims.y
		var ring := _flat_ring(root, ring_r, 0.55, ring_color)
		ring.name = "anillo"
		_flat_ring(root, ring_r + 0.45, 0.22, str(spec.get("ring_border_color", "blanco_textil"))).name = "borde"
		var selection := _flat_ring(root, ring_r + 1.1, 0.4, "oro_laton")
		selection.name = "seleccion"
		selection.visible = false
		unit_nodes[id] = root
		var label := Label3D.new()
		label.name = "etiqueta_" + id
		label.text = str(spec.get("glyph", str(index + 1)))
		label.font_size = 56
		label.pixel_size = 0.0006
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.fixed_size = true
		label.no_depth_test = true
		label.modulate = _pc("blanco_textil")
		label.outline_modulate = _pc("negro_textil")
		label.outline_size = 10
		label.visible = false
		_roots.Etiquetas.add_child(label)
		unit_labels[id] = label
		_tokens[id] = {"root": root, "base_h": base_h, "px": float(spec.get("min_px", 56)), "ring": ring, "ring_color": ring_color, "selection": selection}

## Arma la silueta de `shape` bajo `root` (+Y arriba, −Z hacia adelante) y devuelve (alto nominal, radio del anillo) en metros.
func _token_shape(root: Node3D, shape: String, spec: Dictionary) -> Vector2:
	var body := str(spec.get("body_color", "lana_parda"))
	var accent := str(spec.get("accent_color", "azul_elegido"))
	match shape:
		"jinete":  # caballo largo con el jinete de poncho y sombrero de ala ancha
			for lx in [-0.28, 0.28]:
				for lz in [-0.8, 0.8]:
					_part(root, _cyl_mesh(0.09, 0.07, 0.95), Vector3(lx, 0.47, lz), "cuero")
			_part(root, _box_mesh(Vector3(0.78, 0.85, 2.3)), Vector3(0.0, 1.3, 0.0), body)
			_part(root, _box_mesh(Vector3(0.3, 0.9, 0.4)), Vector3(0.0, 1.9, -1.2), body, Vector3(-28.0, 0.0, 0.0))
			_part(root, _box_mesh(Vector3(0.26, 0.28, 0.6)), Vector3(0.0, 2.25, -1.62), body)
			_part(root, _box_mesh(Vector3(0.95, 0.55, 0.7)), Vector3(0.0, 2.3, 0.1), accent)
			_part(root, _box_mesh(Vector3(0.46, 0.7, 0.32)), Vector3(0.0, 2.55, 0.05), "lino_crudo")
			_part(root, _sphere_mesh(0.19), Vector3(0.0, 3.05, 0.05), "cuero")
			_part(root, _cyl_mesh(0.6, 0.6, 0.07), Vector3(0.0, 3.22, 0.05), "madera_oscura")
			_part(root, _cyl_mesh(0.2, 0.22, 0.2), Vector3(0.0, 3.35, 0.05), "madera_oscura")
			return Vector2(3.45, 1.25)
		"infante_fusil", "infante_banderin":  # camisa y gorra; con fusil o con banderín de mando (marcador, no bandera)
			var jacket := accent if shape == "infante_banderin" else "lino_crudo"
			for lx in [-0.13, 0.13]:
				_part(root, _box_mesh(Vector3(0.17, 0.85, 0.22)), Vector3(lx, 0.43, 0.0), "lana_parda")
			_part(root, _box_mesh(Vector3(0.5, 0.82, 0.3)), Vector3(0.0, 1.25, 0.0), jacket)
			_part(root, _sphere_mesh(0.17), Vector3(0.0, 1.85, 0.0), "cuero")
			_part(root, _cyl_mesh(0.2, 0.21, 0.16), Vector3(0.0, 2.04, 0.0), accent if shape == "infante_fusil" else "negro_textil")
			if shape == "infante_fusil":
				_part(root, _box_mesh(Vector3(0.07, 0.07, 1.6)), Vector3(0.36, 1.35, -0.1), "madera_oscura", Vector3(24.0, 0.0, 0.0))
				_part(root, _box_mesh(Vector3(0.05, 0.05, 0.55)), Vector3(0.36, 1.78, -0.78), "hierro", Vector3(24.0, 0.0, 0.0))
				_part(root, _box_mesh(Vector3(0.34, 0.16, 0.1)), Vector3(0.0, 1.0, -0.2), "cuero")
				return Vector2(2.2, 0.6)
			_part(root, _cyl_mesh(0.045, 0.045, 2.6), Vector3(0.4, 1.4, 0.0), "madera_oscura")
			var pennant := PrismMesh.new()
			pennant.size = Vector3(0.55, 0.9, 0.05)
			pennant.left_to_right = 0.0
			_part(root, pennant, Vector3(0.85, 2.35, 0.0), accent, Vector3(0.0, 0.0, -90.0))
			return Vector2(2.75, 0.7)
		"agachados":  # dos figuras bajas y anchas, de poncho y sombrero
			for lx in [-0.6, 0.6]:
				_part(root, _cyl_mesh(0.16, 0.55, 1.0), Vector3(lx, 0.5, 0.0), body)
				_part(root, _sphere_mesh(0.18), Vector3(lx, 1.15, -0.1), "cuero")
				_part(root, _cyl_mesh(0.45, 0.45, 0.05), Vector3(lx, 1.33, -0.1), "madera_oscura")
			_part(root, _box_mesh(Vector3(0.5, 0.2, 0.3)), Vector3(0.0, 0.2, 0.25), accent)
			return Vector2(1.45, 0.95)
		"mula_cargada":  # mula con aparejo y dos bultos
			for lx in [-0.22, 0.22]:
				for lz in [-0.55, 0.55]:
					_part(root, _cyl_mesh(0.07, 0.06, 0.75), Vector3(lx, 0.37, lz), "cuero")
			_part(root, _box_mesh(Vector3(0.62, 0.7, 1.7)), Vector3(0.0, 1.05, 0.0), body)
			_part(root, _box_mesh(Vector3(0.24, 0.7, 0.3)), Vector3(0.0, 1.45, -0.95), body, Vector3(-25.0, 0.0, 0.0))
			_part(root, _box_mesh(Vector3(0.22, 0.24, 0.5)), Vector3(0.0, 1.72, -1.22), body)
			_part(root, _box_mesh(Vector3(0.9, 0.16, 1.1)), Vector3(0.0, 1.45, 0.05), accent)
			_part(root, _box_mesh(Vector3(0.4, 0.55, 0.7)), Vector3(-0.42, 1.78, 0.05), "lana_natural")
			_part(root, _box_mesh(Vector3(0.4, 0.55, 0.7)), Vector3(0.42, 1.78, 0.05), accent)
			_part(root, _cyl_mesh(0.2, 0.2, 1.0), Vector3(0.0, 2.2, 0.05), "lino_crudo", Vector3(90.0, 0.0, 0.0))
			return Vector2(2.45, 1.05)
	_part(root, _box_mesh(Vector3(0.6, 1.8, 0.4)), Vector3(0.0, 0.9, 0.0), body)
	return Vector2(1.8, 0.9)

# ---------------------------------------------------------------------------------------------------------------------
# Estado dinámico (render_state)

func update_state(delta: float) -> void:
	_time += delta
	if _rules != null and _rules.has_method("render_state"):
		var rs: Variant = _rules.render_state()
		if rs is Dictionary:
			var state: Dictionary = rs
			_sync_environment(state)
			var version := int(state.get("version", -1))
			if version != _version or version < 0:
				_version = version
				_sync_dynamic(state)
	if _env_dirty:
		_apply_environment()
	_update_scales()
	_update_fx(delta)
	_update_selection()

func _sync_environment(state: Dictionary) -> void:
	var env: Dictionary = state.get("env", {}) if state.get("env", null) is Dictionary else {}
	if env.is_empty() and _rules != null and _rules.has_method("environment"):
		env = _rules.environment()
	var tod := float(env.get("time_of_day", 0.0))
	var rain := float(env.get("rain", 0.0))
	if _override_tod >= 0.0:
		tod = _override_tod
		rain = _override_rain
	if _env_dirty or absf(tod - _tod) > 0.001 or absf(rain - _rain) > 0.002:
		_tod = tod
		_rain = rain
		_apply_environment()

func _sync_dynamic(state: Dictionary) -> void:
	_sync_units(state)
	_sync_objectives(state)
	_sync_things("Defensores", "enemy", state.get("enemies", []))
	_sync_things("Botin", "loot", state.get("loot", []))
	_sync_lights(state)

## Vacía los hijos de un grupo y los registros de escala de su categoría.
func _clear_category(root: Node, category: String) -> void:
	for child in root.get_children():
		root.remove_child(child)
		child.free()
	var keep: Array = []
	for entry in _scaled:
		if str(entry.cat) != category:
			keep.append(entry)
	_scaled = keep

func _register_scaled(node: Node3D, category: String, base: float, px: float, min_scale: float = 1.0) -> void:
	_scaled.append({"node": node, "cat": category, "base": maxf(base, 0.1), "px": px, "min": min_scale})

func _sync_units(state: Dictionary) -> void:
	for u in state.get("units", []):
		if not (u is Dictionary) or not unit_nodes.has(str(u.get("id", ""))):
			continue
		var id := str(u.id)
		var node: Node3D = unit_nodes[id]
		var x := float(u.get("x", 0.0))
		var z := float(u.get("z", 0.0))
		node.position = Vector3(x, _h(x, z), z)
		node.rotation.y = -deg_to_rad(float(u.get("yaw_deg", 0.0)))
		var gone := str(u.get("stage", "")) == "exited"
		node.visible = not gone
		(unit_labels[id] as Label3D).visible = not gone and bool(_layers.get("labels", true))
		var info: Dictionary = _tokens[id]
		(info.ring as MeshInstance3D).material_override = _flat_mat("rojo_reservado" if bool(u.get("detected", false)) else str(info.ring_color))
	_update_scales()

## Anillos de estado de los objetivos y de visibilidad; y cuál de las dos torres del diseño es la del mundo (la que `tower` ubica).
func _sync_objectives(state: Dictionary) -> void:
	var root: Node3D = _roots.Anillos
	for child in root.get_children():
		root.remove_child(child)
		child.free()
	for o in state.get("objectives", []):
		if not (o is Dictionary):
			continue
		var id := str(o.get("id", ""))
		var radius := 14.0
		if _lm_by_id.has(id):
			var fp := _footprint(_lm_by_id[id])
			radius = maxf(float(fp.w), float(fp.d)) * 0.5 + 4.0
		var ring := _strip(root, _circle(Vector2(float(o.get("x", 0.0)), float(o.get("z", 0.0))), radius), 2.4, 0.3, _flat_mat(str(STATE_RING.get(str(o.get("state", "guardado")), "piedra_gris")), 0.9), true)
		ring.name = "objetivo_" + id
	var pool_index := 0
	for p in state.get("visibility_pools", []):
		if not (p is Dictionary):
			continue
		var pool := _strip(root, _circle(Vector2(float(p.get("x", 0.0)), float(p.get("z", 0.0))), maxf(float(p.get("r", 20.0)), 3.0)), 1.4, 0.3, _flat_mat("celeste_produccion", 0.5), true)
		pool.name = "visibilidad_%d" % pool_index
		pool_index += 1
	var tower: Variant = state.get("tower", {})
	var at := Vector2(-9999.0, -9999.0)
	if tower is Dictionary and not (tower as Dictionary).is_empty():
		at = Vector2(float(tower.get("x", -9999.0)), float(tower.get("z", -9999.0)))
		if bool(tower.get("firing", false)):
			fx("fogonazo", at, {"height": 9.5})
	var best := 40.0
	var chosen := ""
	for lid in _lm_nodes:
		if str(_lm_by_id[lid].get("type", "")) == "torre":
			(_lm_nodes[lid] as Node3D).visible = false
			var dist := Vector2(float(_lm_by_id[lid].x), float(_lm_by_id[lid].z)).distance_to(at)
			if dist < best:
				best = dist
				chosen = str(lid)
	if chosen != "":
		(_lm_nodes[chosen] as Node3D).visible = true

## Defensores (`enemies`) y botín (`loot`): figuras chicas que crecen hasta un mínimo de píxeles para leerse desde lejos.
func _sync_things(root_name: String, category: String, list: Array) -> void:
	_clear_category(_roots[root_name], category)
	var count := 0
	for e in list:
		if not (e is Dictionary) or count >= MAX_THINGS:
			continue
		var kind := str(e.get("kind", ""))
		if category == "enemy" and kind == "torre":
			continue
		if category == "loot" and not (str(e.get("state", "")) in ["en_sitio", "abandonado"]):
			continue
		count += 1
		var x := float(e.get("x", 0.0))
		var z := float(e.get("z", 0.0))
		var holder := Node3D.new()
		holder.name = "%s_%s" % [category, str(e.get("id", count))]
		holder.position = Vector3(x, _h(x, z), z)
		_roots[root_name].add_child(holder)
		if category == "enemy":
			_part(holder, _cyl_mesh(0.28, 0.32, 1.5), Vector3(0.0, 0.75, 0.0), "hierro" if kind == "artillero" else ("lana_parda" if kind in ["mensajero", "refuerzo"] else "lino_crudo"))
			_part(holder, _sphere_mesh(0.2), Vector3(0.0, 1.7, 0.0), "cuero")
			_flat_ring(holder, 1.5, 0.45, "borgona_hipotetica" if float(e.get("alert", 0.0)) > 0.5 else "grana_analogia", 0.95)
			if bool(e.get("firing", false)):
				_inst(holder, _sphere_mesh(0.5), Vector3(0.0, 1.6, -0.9), _flat_mat("oro_laton", 1.0, true, 1.4), Vector3.ZERO, false)
			_register_scaled(holder, category, 1.9, float(_qcfg.get("enemy_min_px", 14)))
		else:
			holder.position += Vector3(float(count % 3) * 1.5, 0.0, float(count % 2) * 1.5)
			_part(holder, _box_mesh(Vector3(0.9, 0.6, 0.6)), Vector3(0.0, 0.3, 0.0), str(LOOT_COLOR.get(kind, "cuero")))
			_register_scaled(holder, category, 0.7, 10.0)

func _sync_lights(state: Dictionary) -> void:
	_clear_category(_roots.Luces, "light")
	_omni_count = 0
	for l in state.get("lights", []):
		if not (l is Dictionary):
			continue
		var x := float(l.get("x", 0.0))
		var z := float(l.get("z", 0.0))
		var kind := str(l.get("kind", "brasero"))
		var r_m := maxf(float(l.get("r_m", 20.0)), 6.0)
		var holder := Node3D.new()
		holder.name = "luz_" + str(l.get("id", kind))
		holder.position = Vector3(x, _h(x, z) + float(LIGHT_HEIGHT.get(kind, 1.6)), z)
		_roots.Luces.add_child(holder)
		_inst(holder, _sphere_mesh(0.35), Vector3.ZERO, _flat_mat("oro_laton", 1.0, false, 1.5), Vector3.ZERO, false)
		var halo := _inst(holder, _halo_quad(), Vector3.ZERO, _halo_material(), Vector3.ZERO, false)  # un resplandor aditivo que mira a la cámara y no baja de 30 px
		_register_scaled(halo, "light", 1.0, 30.0, r_m * 0.25)
		if _omni_count < int(_qcfg.get("omni_lights_max", 4)) and not _albedo:
			var omni := OmniLight3D.new()
			omni.omni_range = r_m
			omni.light_energy = 2.2
			omni.light_color = _pc("oro_laton", 1.4)
			holder.add_child(omni)
			_omni_count += 1
	_roots.Luces.visible = bool(_layers.get("lights", true)) and not _albedo

func _halo_quad() -> QuadMesh:
	if not _meshes.has("halo"):
		var q := QuadMesh.new()
		q.size = Vector2(1.0, 1.0)
		_meshes["halo"] = q
	return _meshes["halo"]

func _halo_material() -> StandardMaterial3D:
	if _halo_mat == null:
		var grad := Gradient.new()
		grad.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		grad.colors = PackedColorArray([Color(1, 1, 1, 0.95), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.0)])
		var tex := GradientTexture2D.new()
		tex.gradient = grad
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 64
		tex.height = 64
		_halo_mat = StandardMaterial3D.new()
		_halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_halo_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_halo_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_halo_mat.billboard_keep_scale = true
		_halo_mat.albedo_texture = tex
		_halo_mat.albedo_color = _pc("oro_laton", 1.6)
		_halo_mat.disable_fog = true
		_halo_mat.no_depth_test = true
		_halo_mat.render_priority = 8
	return _halo_mat

## Escala por cuadro: lo que debe leerse a cualquier distancia crece hasta ocupar `px` píxeles de alto; nunca baja de su tamaño real.
func _update_scales() -> void:
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	for id in _tokens:
		var info: Dictionary = _tokens[id]
		var root: Node3D = info.root
		var factor := _upright_scale(cam, root.global_position if root.is_inside_tree() else root.position, float(info.px), float(info.base_h), 1.0)
		root.scale = factor
		(unit_labels[id] as Label3D).position = root.position + Vector3(0.0, (float(info.base_h) + 1.5) * factor.y, 0.0)
	var alive: Array = []
	for entry in _scaled:
		if not is_instance_valid(entry.node):
			continue
		alive.append(entry)
		var node: Node3D = entry.node
		var pos: Vector3 = node.global_position if node.is_inside_tree() else node.position
		if str(entry.cat) == "light":
			var s := maxf(float(entry.min), float(entry.px) / _screen_scale() * _meters_per_px_at(cam, pos))
			node.scale = Vector3(s, s, s)
		else:
			node.scale = _upright_scale(cam, pos, float(entry.px), float(entry.base), float(entry.min))
	_scaled = alive

## Escala (x, y, z) para que algo parado de `base_h` m mida `px` píxeles reales de alto en pantalla. Lo vertical se achata por el seno del ángulo entre el
## rayo y la vertical (más cuanto más empinado se lo mira: las fichas de abajo del cuadro se ven más bajas que las de arriba) y por el coseno del
## descentrado; se lo compensa estirando solo el alto, hasta 2,3 veces, para que el ancho no se dispare.
func _upright_scale(cam: Camera3D, pos: Vector3, px: float, base_h: float, min_scale: float) -> Vector3:
	if cam == null:
		return Vector3.ONE * min_scale
	var flat := clampf(px / _screen_scale() * _meters_per_px_at(cam, pos) / base_h, min_scale, 60.0)
	var ray := pos - cam.global_position
	var dist := maxf(ray.length(), 0.001)
	var tilt := clampf(sqrt(maxf(1.0 - pow(ray.y / dist, 2.0), 0.0)) * (ray.dot(-cam.global_transform.basis.z) / dist), 0.3, 1.0)
	return Vector3(flat, clampf(flat / tilt, flat, flat * MAX_STRETCH), flat)


## Píxeles reales por píxel lógico (la ventana escala el área de 1 440 × 900): los tamaños en píxeles del JSON son los de la pantalla.
func _screen_scale() -> float:
	return maxf(get_viewport().get_screen_transform().get_scale().y, 0.2) if is_inside_tree() else 1.0

## Metros por píxel (vertical) de un punto del mundo: 2·profundidad·tan(fov/2) / alto del cuadro.
func _meters_per_px_at(cam: Camera3D, pos: Vector3) -> float:
	if cam == null or not cam.is_inside_tree():
		return 0.1
	var depth := maxf((pos - cam.global_position).dot(-cam.global_transform.basis.z), 1.0)
	return 2.0 * depth * tan(deg_to_rad(_vfov(cam)) * 0.5) / maxf(cam.get_viewport().get_visible_rect().size.y, 1.0)

func _vfov(cam: Camera3D) -> float:
	if cam == null:
		return 46.0
	if cam.keep_aspect == Camera3D.KEEP_HEIGHT:
		return cam.fov
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(cam.fov) * 0.5) / _aspect(cam)))

func _aspect(cam: Camera3D) -> float:
	if cam != null and cam.is_inside_tree():
		var size := cam.get_viewport().get_visible_rect().size
		if size.y > 0.0:
			return size.x / size.y
	return 16.0 / 9.0

func _update_selection() -> void:
	var pulse := 1.0 + 0.07 * sin(_time * 5.0)
	for id in _tokens:
		var sel: MeshInstance3D = _tokens[id].selection
		sel.visible = selected_ids.has(id)
		if sel.visible:
			sel.scale = Vector3(pulse, 0.12, pulse)

# ---------------------------------------------------------------------------------------------------------------------
# Luz, niebla y lluvia

func _light_params(key: String) -> Dictionary:
	var l: Dictionary = (_data.get("lights", {}) as Dictionary).get(key, {})
	var sun: Dictionary = l.get("sun", {})
	var amb: Dictionary = l.get("ambient", {})
	var sky: Dictionary = l.get("sky", {})
	var fog: Dictionary = l.get("fog", {})
	return {
		"t": float(l.get("time_of_day", VV.TIME_OF_DAY.get(key, 0.0))),
		"sun_el": float(sun.get("elevation_deg", 30.0)), "sun_az": float(sun.get("azimuth_deg", 90.0)),
		"sun_col": _pc(str(sun.get("color", "blanco_textil")), float(sun.get("gain", 1.0))), "sun_energy": float(sun.get("energy", 1.0)),
		"sun_shadow": 1.0 if bool(sun.get("shadows", false)) else 0.0,
		"amb_col": _pc(str(amb.get("color", "cal_envejecida")), float(amb.get("gain", 1.0))), "amb_energy": float(amb.get("energy", 0.8)),
		"sky_top": _pc(str(sky.get("top", "azul_elegido")), float(sky.get("top_gain", 1.0))),
		"sky_hor": _pc(str(sky.get("horizon", "cal_envejecida")), float(sky.get("horizon_gain", 1.0))),
		"sky_gnd": _pc(str(sky.get("ground", "suelo_seco")), float(sky.get("ground_gain", 1.0))),
		"fog_col": _pc(str(fog.get("color", "cal_envejecida")), float(fog.get("gain", 1.0))), "fog_density": float(fog.get("density", 0.001)),
		"exposure": float(l.get("exposure", 1.0))}

func _blend_params(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	var out := {}
	for key in a:
		if key == "sun_az":
			out[key] = rad_to_deg(lerp_angle(deg_to_rad(float(a[key])), deg_to_rad(float(b[key])), k))
		elif a[key] is Color:
			out[key] = (a[key] as Color).lerp(b[key] as Color, k)
		else:
			out[key] = lerpf(float(a[key]), float(b[key]), k)
	return out

func _apply_environment() -> void:
	_env_dirty = false
	if _env == null:
		return
	var noche := _light_params("noche_lluvia")
	var alba := _light_params("alba")
	var dia := _light_params("dia")
	var p: Dictionary
	if _tod <= float(alba.t):
		p = _blend_params(noche, alba, clampf((_tod - float(noche.t)) / maxf(float(alba.t) - float(noche.t), 0.001), 0.0, 1.0))
	else:
		p = _blend_params(alba, dia, clampf((_tod - float(alba.t)) / maxf(float(dia.t) - float(alba.t), 0.001), 0.0, 1.0))
	var rain_cfg: Dictionary = _data.get("rain", {})
	var fog_cfg: Dictionary = _data.get("fog", {})
	var elevation := deg_to_rad(float(p.sun_el))
	var azimuth := deg_to_rad(float(p.sun_az))
	var to_sun := Vector3(sin(azimuth) * cos(elevation), sin(elevation), -cos(azimuth) * cos(elevation))
	_sun.transform = Transform3D(Basis.looking_at(-to_sun, Vector3.UP), Vector3.ZERO)
	_sun.light_color = p.sun_col
	_sun.light_energy = float(p.sun_energy)
	_sun.shadow_enabled = bool(_qcfg.get("shadows", true)) and float(p.sun_shadow) > 0.5 and not _albedo
	_sky_mat.sky_top_color = p.sky_top
	_sky_mat.sky_horizon_color = p.sky_hor
	_sky_mat.ground_horizon_color = p.sky_hor
	_sky_mat.ground_bottom_color = p.sky_gnd
	if _albedo:  # render de albedo para la métrica de paleta: sin sombreado, niebla, exposición ni sombras
		_env.background_mode = Environment.BG_COLOR
		_env.background_color = Color(0.6, 0.6, 0.6)
		_env.ambient_light_color = Color.WHITE
		_env.ambient_light_energy = 1.0
		_env.fog_enabled = false
		_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		_env.tonemap_exposure = 1.0
		_sun.light_energy = 0.0
	else:
		_env.background_mode = Environment.BG_SKY
		_env.ambient_light_color = p.amb_col
		_env.ambient_light_energy = float(p.amb_energy)
		_env.fog_enabled = true
		_env.fog_density = clampf(float(p.fog_density) + _rain * float(rain_cfg.get("fog_density_per_rain", 0.0006)), float(fog_cfg.get("density_min", 0.0003)), float(fog_cfg.get("density_max", 0.0045)))
		_env.fog_light_color = p.fog_col
		_env.tonemap_mode = Environment.TONE_MAPPER_ACES
		_env.tonemap_exposure = float(p.exposure)
	if _ground_mat != null:  # el suelo se oscurece donde llueve
		var wet := 1.0 - (1.0 - float(rain_cfg.get("wet_darken", 0.75))) * clampf(_rain, 0.0, 1.0)
		_ground_mat.albedo_color = Color(wet, wet, wet, 1.0)
		_ground_mat.roughness = lerpf(0.96, float(rain_cfg.get("wet_roughness", 0.5)), clampf(_rain, 0.0, 1.0))

func set_time_override(time_of_day: float, rain: float) -> void:
	_override_tod = time_of_day if time_of_day >= 0.0 else -1.0
	_override_rain = clampf(rain, 0.0, 1.0)
	_env_dirty = true
	if _override_tod >= 0.0:
		_tod = _override_tod
		_rain = _override_rain
		_apply_environment()

func set_albedo_mode(on: bool) -> void:
	if on == _albedo:
		return
	_albedo = on
	for key in _mats:
		(_mats[key] as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if on else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	if _ground_mat != null:
		_ground_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if on else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	for omni in find_children("*", "OmniLight3D", true, false):
		(omni as Node3D).visible = not on
	_apply_layers()
	_env_dirty = true
	_apply_environment()

# ---------------------------------------------------------------------------------------------------------------------
# Capas, selección y efectos

func set_layer_visible(layer: String, on: bool) -> void:
	if VV.LAYERS.has(layer):
		_layers[layer] = on
		_apply_layers()

func layer_visible(layer: String) -> bool:
	return bool(_layers.get(layer, false))

func _apply_layers() -> void:
	if _roots.is_empty():
		return
	(_roots.Hitos as Node3D).visible = bool(_layers.get("landmarks", true))
	(_roots.Luces as Node3D).visible = bool(_layers.get("lights", true)) and not _albedo
	(_roots.Defensores as Node3D).visible = bool(_layers.get("enemy", true))
	(_roots.Anillos as Node3D).visible = bool(_layers.get("visibility", true))
	(_roots.Etiquetas as Node3D).visible = bool(_layers.get("labels", true))
	(_roots.Efectos as Node3D).visible = not _albedo

func set_selected_ids(ids: Array) -> void:
	selected_ids = ids.duplicate()
	_update_selection()

func fx(kind: String, pos: Vector2, opts: Dictionary = {}) -> void:
	if not VV.FX_KINDS.has(kind) or _roots.is_empty():
		return
	var spec: Dictionary = (_data.get("fx", {}) as Dictionary).get(kind, {})
	while _fx.size() >= int(_qcfg.get("fx_max", 24)) and not _fx.is_empty():
		_free_fx(0)
	var radius := float(spec.get("radius_m", 3.0)) * float(opts.get("scale", 1.0))
	var y0 := _h(pos.x, pos.y) + float(opts.get("height", 1.2))
	var mi := _inst(_roots.Efectos, _sphere_mesh(1.0), Vector3(pos.x, y0, pos.y), _flat_mat(str(spec.get("color", "blanco_textil")), 0.9, kind in ["fogonazo", "explosion", "senal"]), Vector3.ZERO, false)
	mi.scale = Vector3.ONE * radius * 0.3
	_fx.append({"node": mi, "age": 0.0, "life": maxf(float(spec.get("life_s", 0.6)), 0.05), "r": radius, "rise": float(spec.get("rise_m", 1.0)), "y0": y0})

func _free_fx(index: int) -> void:
	var entry: Dictionary = _fx[index]
	if is_instance_valid(entry.node):
		(entry.node as Node).free()
	_fx.remove_at(index)

func _update_fx(delta: float) -> void:
	for k in range(_fx.size() - 1, -1, -1):
		var entry: Dictionary = _fx[k]
		entry.age = float(entry.age) + delta
		var t := clampf(float(entry.age) / float(entry.life), 0.0, 1.0)
		if t >= 1.0 or not is_instance_valid(entry.node):
			_free_fx(k)
		else:
			var node: MeshInstance3D = entry.node
			node.scale = Vector3.ONE * float(entry.r) * lerpf(0.3, 1.0, t)
			node.position.y = float(entry.y0) + float(entry.rise) * t
			node.transparency = t

# ---------------------------------------------------------------------------------------------------------------------
# Cámara, proyección y picking

func camera_bounds() -> Rect2:
	return Rect2(-CAMERA_MARGIN_M, -CAMERA_MARGIN_M, _world.x + 2.0 * CAMERA_MARGIN_M, _world.y + 2.0 * CAMERA_MARGIN_M)

func clamp_camera_target(p: Vector3) -> Vector3:
	var r := camera_bounds()
	var x := clampf(p.x, r.position.x, r.end.x)
	var z := clampf(p.z, r.position.y, r.end.y)
	return Vector3(x, maxf(_h(x, z), p.y), z)

func world_to_map(p: Vector2) -> Vector2:
	return Vector2(p.x / _world.x, p.y / _world.y)  # v = 0 es el NORTE (z = 0)

func map_to_world(uv: Vector2) -> Vector2:
	return Vector2(uv.x * _world.x, uv.y * _world.y)

func _cam_ok(camera: Camera3D) -> bool:
	return camera != null and camera.is_inside_tree() and camera.get_viewport() != null

## Marcha un rayo sobre `height_at`: Vector2 (x, z) del punto donde pega, o null si no toca el suelo.
func _ray_ground(origin: Vector3, dir: Vector3) -> Variant:
	if origin.y <= _h(origin.x, origin.z):
		return Vector2(origin.x, origin.z)
	if dir.y >= 0.0:
		return null
	var prev_t := 0.0
	var t := 4.0
	while t < MAX_RAY_M:
		var p := origin + dir * t
		if p.y <= _h(p.x, p.z):
			var lo := prev_t
			var hi := t
			for _i in range(14):
				var mid := (lo + hi) * 0.5
				var q := origin + dir * mid
				if q.y <= _h(q.x, q.z):
					hi = mid
				else:
					lo = mid
			var hit := origin + dir * hi
			return Vector2(hit.x, hit.z)
		prev_t = t
		t += clampf(t * 0.012, 3.0, 20.0)
	return null

func ground_xz_from_screen(camera: Camera3D, pos: Vector2) -> Variant:
	if not _cam_ok(camera):
		return null
	return _ray_ground(camera.project_ray_origin(pos), camera.project_ray_normal(pos))

func camera_frustum_on_ground(camera: Camera3D) -> PackedVector2Array:
	var out := PackedVector2Array()
	if not _cam_ok(camera):
		return out
	var size := camera.get_viewport().get_visible_rect().size
	for corner in [Vector2(0.0, 0.0), Vector2(size.x, 0.0), Vector2(size.x, size.y), Vector2(0.0, size.y)]:
		var origin := camera.project_ray_origin(corner)
		var dir := camera.project_ray_normal(corner)
		var hit: Variant = _ray_ground(origin, dir)
		if hit is Vector2:
			out.append(hit)
		else:  # el rayo se va por encima del horizonte: se lo corta a 4 km para que el cuadro siga siendo un polígono
			var flat := Vector2(dir.x, dir.z)
			out.append(Vector2(origin.x, origin.z) + (flat.normalized() if flat.length() > 0.0001 else Vector2(0.0, -1.0)) * 4000.0)
	return out

func meters_per_pixel(camera: Camera3D, pos: Vector2 = Vector2(-1, -1)) -> float:
	if not _cam_ok(camera):
		return 1.0
	var screen := camera.get_viewport().get_visible_rect().size * 0.5 if pos.x < 0.0 or pos.y < 0.0 else pos
	var hit: Variant = ground_xz_from_screen(camera, screen)
	var point := camera.project_ray_origin(screen) + camera.project_ray_normal(screen) * 500.0
	if hit is Vector2:
		point = Vector3(hit.x, _h(hit.x, hit.y), hit.y)
	return _meters_per_px_at(camera, point)

func _screen_of(camera: Camera3D, p: Vector3) -> Dictionary:
	return {"screen": camera.unproject_position(p), "behind": camera.is_position_behind(p)}

func _unit_anchor(id: String) -> Vector3:
	var info: Dictionary = _tokens[id]
	var root: Node3D = info.root
	return root.position + Vector3(0.0, float(info.base_h) * root.scale.y * 0.5, 0.0)

## [[id, pantalla], …] de las agrupaciones visibles y delante de la cámara, en el orden de GROUPS.
func _unit_ids_on_screen(camera: Camera3D) -> Array:
	var out: Array = []
	if not _cam_ok(camera):
		return out
	for id in V.GROUPS:
		if _tokens.has(id) and (_tokens[id].root as Node3D).visible:
			var s := _screen_of(camera, _unit_anchor(id))
			if not bool(s.behind):
				out.append([id, s.screen])
	return out

func pick_unit(camera: Camera3D, pos: Vector2) -> String:
	var best := ""
	var best_d := PICK_UNIT_PX
	for pair in _unit_ids_on_screen(camera):
		var d := (pair[1] as Vector2).distance_to(pos)
		if d <= best_d:
			best_d = d
			best = str(pair[0])
	return best

func pick_units_in_rect(camera: Camera3D, rect: Rect2) -> Array:
	var out: Array = []
	for pair in _unit_ids_on_screen(camera):
		if rect.abs().has_point(pair[1]):
			out.append(pair[0])
	return out

## El hito más cercano a `pos` dentro de `radius_px` entre los de `ids` (anclado a `lift` m sobre el suelo).
func _nearest_landmark(camera: Camera3D, pos: Vector2, ids: Array, radius_px: float, lift: float) -> String:
	var best := ""
	var best_d := radius_px
	if not _cam_ok(camera):
		return best
	for id in ids:
		if not _lm_by_id.has(id) or (_lm_nodes.has(id) and not (_lm_nodes[id] as Node3D).visible):
			continue
		var lm: Dictionary = _lm_by_id[id]
		var s := _screen_of(camera, Vector3(float(lm.x), _h(float(lm.x), float(lm.z)) + lift, float(lm.z)))
		var d := (s.screen as Vector2).distance_to(pos)
		if not bool(s.behind) and d < best_d:
			best_d = d
			best = str(id)
	return best

func pick_front(camera: Camera3D, pos: Vector2) -> String:
	return _nearest_landmark(camera, pos, V.OBJECTIVES, PICK_FRONT_PX, 2.0)

func pick_landmark(camera: Camera3D, pos: Vector2) -> String:
	return _nearest_landmark(camera, pos, _lm_by_id.keys(), PICK_LANDMARK_PX, 1.5)

func get_landmark_info(id: String) -> Dictionary:
	if not _lm_by_id.has(id):
		return {}
	var info: Dictionary = (_lm_by_id[id] as Dictionary).duplicate(true)
	info["y"] = _h(float(info.get("x", 0.0)), float(info.get("z", 0.0)))
	return info

func landmark_labels(camera: Camera3D) -> Array:
	var out: Array = []
	if not _cam_ok(camera):
		return out
	for lm in _landmarks:
		var id := str(lm.id)
		if _lm_nodes.has(id) and not (_lm_nodes[id] as Node3D).visible:
			continue
		var s := _screen_of(camera, Vector3(float(lm.x), _h(float(lm.x), float(lm.z)) + float(lm.get("height_m", 3.0)) + 2.0, float(lm.z)))
		out.append({"id": id, "name": str(lm.get("short", lm.get("name", id))), "tag": str(lm.get("tag", "diseno")), "screen": s.screen, "behind": s.behind})
	return out

# ---------------------------------------------------------------------------------------------------------------------
# Cuadros canónicos y cámara inicial

func canonical_view(id: String) -> Dictionary:
	for view in _data.get("canonical_views", []):
		if view is Dictionary and str(view.get("id", "")) == id:
			var t := _pt(view.get("target", {}))
			return {"target": Vector3(t.x, _h(t.x, t.y), t.y), "distance": float(view.get("distance", 100.0)), "pitch_deg": float(view.get("pitch_deg", 45.0)),
				"yaw_deg": float(view.get("yaw_deg", 0.0)), "time_of_day": float(view.get("time_of_day", 0.0)), "rain": float(view.get("rain", 0.0)),
				"must_show": (view.get("must_show", []) as Array).duplicate()}
	return {}

## La transformación de una cámara que mira a `target` desde `distance` m con `pitch_deg` de inclinación y rumbo `yaw_deg`.
func frame_transform(target: Vector3, distance: float, pitch_deg: float, yaw_deg: float) -> Transform3D:
	var yaw := deg_to_rad(yaw_deg)
	var pitch := deg_to_rad(pitch_deg)
	var look := Vector3(sin(yaw) * cos(pitch), -sin(pitch), -cos(yaw) * cos(pitch))
	return Transform3D(Basis.looking_at(look, Vector3.UP), target - look * distance)

## Los puntos que el cuadro inicial debe incluir: los tres objetivos, el centro de la zona de partida y las cinco partidas (que están dentro de ella).
func _frame_points() -> Array:
	var pts: Array = []
	var ids: Array = (_data.get("initial_frame", {}) as Dictionary).get("must_include", V.OBJECTIVES + ["zona_partida"])
	for group in V.GROUPS:
		ids = ids + ["spawn_" + group]
	for id in ids:
		if _lm_by_id.has(str(id)):
			var lm: Dictionary = _lm_by_id[str(id)]
			pts.append(Vector3(float(lm.x), _h(float(lm.x), float(lm.z)), float(lm.z)))
	return pts

## ¿Entran todos los puntos con `margin_pct` % de borde libre? La proyección se calcula a mano para no mover la cámara real.
func _frame_fits(target: Vector3, distance: float, pitch: float, yaw: float, vfov: float, aspect: float, pts: Array, margin_pct: float) -> bool:
	var inverse := frame_transform(target, distance, pitch, yaw).affine_inverse()
	var th := tan(deg_to_rad(vfov) * 0.5)
	var limit := 1.0 - margin_pct * 0.02
	for p in pts:
		var local: Vector3 = inverse * (p as Vector3)
		if local.z > -0.5 or absf(local.x / (-local.z * th * aspect)) > limit or absf(local.y / (-local.z * th)) > limit:
			return false
	return true

## El cuadro inicial: el del JSON, ensanchado solo lo necesario (hasta 900 m) para que entren los objetivos y la zona de partida; si no entran, `fits` es falso.
func initial_frame(camera: Camera3D) -> Dictionary:
	var frame: Dictionary = _data.get("initial_frame", {})
	var t := _pt(frame.get("target", {"x": 350.0, "z": 470.0}))
	var target := Vector3(t.x, _h(t.x, t.y), t.y)
	var distance := float(frame.get("distance", 470.0))
	var pitch := float(frame.get("pitch_deg", 52.0))
	var yaw := float(frame.get("yaw_deg", 35.0))
	var margin := float(frame.get("margin_pct", VV.FRAME_MARGIN_PCT))
	var vfov := _vfov(camera)
	var aspect := _aspect(camera)
	var pts := _frame_points()
	var fits := false
	for attempt in range(2):
		if pts.is_empty():
			break
		fits = _frame_fits(target, distance, pitch, yaw, vfov, aspect, pts, margin)
		while not fits and distance < 900.0:
			distance = minf(distance * 1.04, 900.0)
			fits = _frame_fits(target, distance, pitch, yaw, vfov, aspect, pts, margin)
		if fits or attempt == 1:
			break
		var center := Vector3.ZERO  # no entra con el objetivo del JSON: se recentra en el promedio de los puntos y se vuelve a ensanchar
		for p in pts:
			center += p as Vector3
		center /= float(pts.size())
		target = Vector3(center.x, _h(center.x, center.z), center.z)
		distance = float(frame.get("distance", 470.0))
	return {"target": target, "distance": distance, "pitch_deg": pitch, "yaw_deg": yaw, "fits": fits}

# ---------------------------------------------------------------------------------------------------------------------
# Minimapa y sondas de QA

func get_minimap_texture(size: Vector2i) -> Texture2D:
	var key := "%dx%d" % [size.x, size.y]
	if not _minimap_cache.has(key):
		var img: Image = null
		if _terrain != null and _terrain.has_method("minimap_image"):
			var made: Variant = _terrain.minimap_image(size, {})
			if made is Image and not (made as Image).is_empty():
				img = made
				if img.get_width() != size.x or img.get_height() != size.y:
					img.resize(size.x, size.y)
		if img == null:
			img = Image.create(maxi(size.x, 1), maxi(size.y, 1), false, Image.FORMAT_RGBA8)
			img.fill(_pc("suelo_seco"))
		_minimap_cache[key] = ImageTexture.create_from_image(img)
	return _minimap_cache[key]

func _screen_rect(camera: Camera3D, pts: Array) -> Rect2:
	var lo := Vector2(1.0e9, 1.0e9)
	var hi := Vector2(-1.0e9, -1.0e9)
	var any := false
	for p in pts:
		if not camera.is_position_behind(p as Vector3):
			var s := camera.unproject_position(p as Vector3)
			lo = Vector2(minf(lo.x, s.x), minf(lo.y, s.y))
			hi = Vector2(maxf(hi.x, s.x), maxf(hi.y, s.y))
			any = true
	return Rect2(lo, hi - lo) if any else Rect2()

func _rect_array(r: Rect2) -> Array:
	return [snappedf(r.position.x, 0.1), snappedf(r.position.y, 0.1), snappedf(r.size.x, 0.1), snappedf(r.size.y, 0.1)]

## Rectángulos en píxeles para medir ΔL*: la huella proyectada de cada edificio u objetivo, la ficha de cada agrupación y el suelo que los rodea.
func probes(camera: Camera3D) -> Array:
	var out: Array = []
	if not _cam_ok(camera):
		return out
	for lm in _landmarks:
		var id := str(lm.id)
		var type_name := str(lm.get("type", ""))
		if not (type_name in ["objetivo", "edificio", "torre"]) or (_lm_nodes.has(id) and not (_lm_nodes[id] as Node3D).visible):
			continue
		var top := float(lm.get("height_m", 0.0))
		if top <= 0.0:
			top = float(_prop_spec(id, type_name).get("default_height_m", 3.0))
		var pts: Array = []
		for c in _footprint_corners(_footprint(lm)):
			pts.append(Vector3(c.x, _h(c.x, c.y), c.y))
			pts.append(Vector3(c.x, _h(c.x, c.y) + top, c.y))
		var building := _screen_rect(camera, pts)
		if building.size != Vector2.ZERO:
			out.append({"kind": "objetivo" if V.OBJECTIVES.has(id) else "edificio", "id": id, "rect": _rect_array(building)})
			out.append({"kind": "suelo", "id": id, "rect": _rect_array(building.grow(maxf(building.size.x, building.size.y) * 0.35))})
	for pair in _unit_ids_on_screen(camera):
		var h_px := float((_tokens[pair[0]] as Dictionary).px)
		var token := Rect2((pair[1] as Vector2) - Vector2(h_px * 0.4, h_px * 0.7), Vector2(h_px * 0.8, h_px))
		out.append({"kind": "ficha", "id": str(pair[0]), "rect": _rect_array(token)})
		out.append({"kind": "suelo", "id": str(pair[0]), "rect": _rect_array(token.grow(h_px * 0.6))})
	return out
