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
const TOKEN_SHADER := "res://shaders/humahuaca_token.gdshader"
const FLAT_H := 17.0
const SKIRT_M := 3.0
const RING_ROWS := [0.0, 30.0, 85.0, 180.0, 340.0, 620.0, 1050.0, 1750.0, 2900.0, 4500.0, 6800.0]
const WORLD_RADIUS_M := 8000.0
## La cinta del río: paso de las muestras cerca de la ventana y lejos de ella, metros en que se apaga en cada punta recortada y metros de la ventana en que pasa del agua plana
## de un cauce tallado a la cinta apoyada sobre el suelo.
const RIVER_STEP_WIN_M := 5.0
const RIVER_STEP_CTX_M := 16.0
const RIVER_FADE_M := 450.0
const RIVER_WIN_BLEND_M := 80.0
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
var token_mats: Dictionary = {}  ## «aliado» y «enemigo»: el material de las figuras (shaders/humahuaca_token.gdshader)
var _models: Dictionary = {}  ## modelos GLB ya cargados por clave (model())
static var _model_cache: Dictionary = {}  ## ruta → {mesh, aabb}: la malla unida sobrevive entre construcciones del nivel
var _glow_mat: StandardMaterial3D = null  ## la lumbre de las casas (night_glow_mat)
var win := Rect2(0.0, 0.0, 900.0, 652.0)  ## la ventana de 4 m: de la primera a la última fila de la grilla
var ctx := Rect2(-1350.0, -1025.0, 3600.0, 2700.0)  ## el contexto de 30 m
var build_stats: Dictionary = {}  ## triángulos y milisegundos de cada etapa del terreno (los informa el recorrido de QA)
var river_stats: Dictionary = {}  ## muestras y largo de la cinta del río

var _mats: Dictionary = {}
var _flat: Dictionary = {}
var _meshes: Dictionary = {}
var _std_mats: Array = []  ## materiales estándar con sombreado: el modo albedo los pasa a «sin sombreado»
var _patches: Array = []  ## las mallas de suelo dibujadas ({x0, x1, z0, z1, xs, zs, hs}): `rendered_h` lee de ahí la altura que se ve
var _win_src := PackedFloat32Array()  ## la grilla de la ventana (los nodos exactos que dibuja su malla y que usan las costuras)
var _win_nx := 0
var _win_nz := 0
var _win_cell := 4.0
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
	# fichas y defensores: color de vértice con luz propia y un borde del color del bando (celeste aliado, rojo enemigo: la regla de color de DIRECCION_DE_ARTE 2.1)
	var tokens_look: Dictionary = (data.get("look", {}) as Dictionary).get("tokens", {}) if (data.get("look", {}) as Dictionary).get("tokens", null) is Dictionary else {}
	for side in [["aliado", "celeste_produccion", 1.1], ["enemigo", "rojo_reservado", 1.2]]:
		var tm := _shader_material(TOKEN_SHADER)
		var spec: Dictionary = tokens_look.get(side[0], {}) if tokens_look.get(side[0], null) is Dictionary else {}
		tm.set_shader_parameter("rim_color", pc(str(spec.get("rim_color", side[1])), float(spec.get("rim_gain", side[2]))))
		tm.set_shader_parameter("rim_amount", float(spec.get("rim_amount", 0.55)))
		tm.set_shader_parameter("self_light", float(spec.get("self_light", 0.22)))
		token_mats[side[0]] = tm


## Lluvia 0..1: oscurece y alisa el suelo, los edificios y el agua (CONTRATO 11.2: suelo ×0,75).
func set_rain(value: float) -> void:
	var r := clampf(value, 0.0, 1.0)
	for m in [terrain_mat, props_mat, water_mat]:
		if m != null:
			(m as ShaderMaterial).set_shader_parameter("rain", r)


## Un modelo GLB de `humahuaca_visual.json: models` (casas de adobe, capilla, tapia, corral, pirca, brasero, fogón… de la pista de modelos P6) como UNA malla lista para
## MultiMesh: {mesh, aabb} con todas sus piezas unidas en el sistema del archivo (escala 1, origen en el suelo, frente hacia −Z). Devuelve {} si la clave no está, está
## apagada o el archivo no existe: quien lo pide sigue con su generador procedural (el respaldo). Reemplazar un modelo es cambiar la ruta en el JSON.
func model(key: String) -> Dictionary:
	if _models.has(key):
		return _models[key]
	var out := {}
	var cfg: Dictionary = data.get("models", {}) if data.get("models", null) is Dictionary else {}
	var path := str(cfg.get(key, ""))
	if path != "" and not path.begins_with("res://"):  # el JSON guarda el nombre y la carpeta («dir»), así la validación de rutas no exige archivos que todavía no llegaron
		path = "res://" + str(cfg.get("dir", "assets/models")).trim_suffix("/") + "/" + path
	if bool(cfg.get("enabled", true)) and _model_cache.has(path):  # ya unido en una construcción anterior (reintento, otra partida): no se vuelve a armar
		out = _model_cache[path]
	elif bool(cfg.get("enabled", true)) and path != "" and ResourceLoader.exists(path):
		var scene: Variant = load(path)
		if scene is PackedScene:
			var inst_root: Node = (scene as PackedScene).instantiate()
			var merged := ArrayMesh.new()
			for mi in inst_root.find_children("*", "MeshInstance3D", true, false):
				var m: Mesh = (mi as MeshInstance3D).mesh
				if m == null:
					continue
				var xf := _rel_xf(inst_root, mi as Node3D)
				for s in range(m.get_surface_count()):
					var arrays: Array = m.surface_get_arrays(s)
					var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					var ns: Variant = arrays[Mesh.ARRAY_NORMAL]
					for i in range(vs.size()):
						vs[i] = xf * vs[i]
					arrays[Mesh.ARRAY_VERTEX] = vs
					if ns is PackedVector3Array:
						var nn: PackedVector3Array = ns
						for i in range(nn.size()):
							nn[i] = (xf.basis * nn[i]).normalized()
						arrays[Mesh.ARRAY_NORMAL] = nn
					arrays[Mesh.ARRAY_TANGENT] = null  # el material de props no las usa y no siempre vienen
					if arrays[Mesh.ARRAY_COLOR] == null:  # sin color de vértice: adobe parejo (el shader de props colorea por vértice)
						var cols := PackedColorArray()
						cols.resize(vs.size())
						cols.fill(Color(pc("adobe"), 1.0))
						arrays[Mesh.ARRAY_COLOR] = cols
					merged.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
					# se conserva el material de cada superficie del GLB: el ancla activa el color por vértice y las brasas traen su emisión (P6_MODELOS 1 y 3)
					var smat: Material = (mi as MeshInstance3D).get_active_material(s)
					if smat != null:
						merged.surface_set_material(merged.get_surface_count() - 1, smat)
			inst_root.free()
			if merged.get_surface_count() > 0:
				out = {"mesh": merged, "aabb": merged.get_aabb(), "path": path}
				_model_cache[path] = out
	_models[key] = out
	return out


static func _rel_xf(top: Node, n: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != top:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


## La transformación que lleva el modelo `key` a una huella de `w` × `d` m (x por z, antes de girar) y `h` m de alto, centrado en el origen y apoyado en y = 0. Si el lado
## largo del modelo no coincide con el de la huella, se lo gira 90°. `h` ≤ 0 conserva la proporción del modelo según el ancho.
func model_fit(key: String, w: float, d: float, h: float = -1.0, uniform: bool = false) -> Transform3D:
	var m := model(key)
	if m.is_empty():
		return Transform3D.IDENTITY
	var box: AABB = m.aabb
	var sx := maxf(box.size.x, 0.01)
	var sz := maxf(box.size.z, 0.01)
	var turn := (sx > sz) != (w > d) and absf(sx - sz) > 0.15 * maxf(sx, sz) and absf(w - d) > 0.15 * maxf(w, d)
	if turn:
		var t := sx
		sx = sz
		sz = t
	var kx := w / sx
	var kz := d / sz
	if uniform:  # sin deformar (la capilla): la escala que entra en la huella, y el alto con la misma
		kx = minf(minf(kx, kz), 1.0)
		kz = kx
	var ky := kx if uniform else (h / maxf(box.size.y, 0.01) if h > 0.0 else clampf((kx + kz) * 0.5, 0.6, 1.6))
	var center := box.get_center()
	var rot := Basis(Vector3.UP, PI * 0.5) if turn else Basis.IDENTITY
	var pre := Transform3D(Basis.IDENTITY, Vector3(-center.x, -box.position.y, -center.z))  # centrado y apoyado en el suelo
	return Transform3D(Basis.from_scale(Vector3(kx, ky, kz)) * rot, Vector3.ZERO) * pre


## La lumbre de puertas y ventanas: sin sombreado, emisiva (el resplandor la abre en un punto cálido) y con la intensidad que da set_night_glow según la hora.
func night_glow_mat() -> StandardMaterial3D:
	if _glow_mat == null:
		_glow_mat = StandardMaterial3D.new()
		_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var c := pc("oro_laton", 1.2).lerp(pc("rojo_reservado", 1.2), 0.25)
		_glow_mat.albedo_color = c
		_glow_mat.emission_enabled = true
		_glow_mat.emission = c
		_glow_mat.emission_energy_multiplier = 9.0
		_glow_mat.disable_fog = true
	return _glow_mat


func set_night_glow(k: float) -> void:
	if _glow_mat != null:
		_glow_mat.emission_energy_multiplier = 9.0 * clampf(k, 0.0, 1.5)
		_glow_mat.albedo_color.a = 1.0
		_glow_mat.albedo_color = (pc("oro_laton", 1.2).lerp(pc("rojo_reservado", 1.2), 0.25)).darkened(clampf(1.0 - k, 0.0, 0.85))


## El material de las figuras de un bando («aliado» o «enemigo»).
func token_mat(side: String) -> ShaderMaterial:
	return token_mats.get(side, token_mats.get("aliado"))


func set_albedo(on: bool) -> void:
	albedo = on
	if _glow_mat != null:  # la lumbre no es color de paleta: fuera del render de albedo
		_glow_mat.emission_enabled = not on
	for m in [terrain_mat, props_mat, water_mat] + token_mats.values():
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


## Índices de `values` cada `stride` posiciones, siempre con la primera y la última (el último tramo no queda a menos de media zancada).
func _subset(values: PackedFloat32Array, stride: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var n := values.size()
	if n == 0:
		return out
	var step := maxi(stride, 1)
	var idx: Array = []
	var k := 0
	while k < n - 1:
		idx.append(k)
		k += step
	if idx.size() > 1 and (n - 1) - int(idx[idx.size() - 1]) < step / 2:
		idx.pop_back()
	idx.append(n - 1)
	for i in idx:
		out.append(values[int(i)])
	return out


## Interpolación lineal sobre una polilínea ordenada `cx` → `ch` (queda en los extremos fuera de ella).
func _lerp_poly(cx: PackedFloat32Array, ch: PackedFloat32Array, x: float) -> float:
	var n := cx.size()
	if n == 1 or x <= cx[0]:
		return ch[0]
	if x >= cx[n - 1]:
		return ch[n - 1]
	var i := clampi(cx.bsearch(x) - 1, 0, n - 2)
	return lerpf(ch[i], ch[i + 1], (x - cx[i]) / maxf(cx[i + 1] - cx[i], 0.0001))


## El valor de la grilla de la ventana en el nodo más cercano a (x, z): el mismo que dibuja la malla de la ventana (en `baja` la malla usa un nodo de cada dos).
func _win_node(x: float, z: float) -> float:
	var gi := clampi(int(round((x - win.position.x) / _win_cell)), 0, _win_nx - 1)
	var gj := clampi(int(round((z - win.position.y) / _win_cell)), 0, _win_nz - 1)
	return _win_src[gj * _win_nx + gi]


## La altura de un vértice de las costuras de la ventana: sobre la ventana (y su borde), el nodo exacto de la grilla; afuera, `height_at`.
func _seam_h(x: float, z: float) -> float:
	if x >= win.position.x - 0.01 and x <= win.end.x + 0.01 and z >= win.position.y - 0.01 and z <= win.end.y + 0.01:
		return _win_node(x, z)
	return h(x, z)


## Un trozo de suelo (un nodo de malla) que además se anota con su grilla: `rendered_h` lee de ahí la altura DIBUJADA.
func _add_patch(root: Node3D, name_: String, xs: PackedFloat32Array, zs: PackedFloat32Array, hs: PackedFloat32Array, skirt_m: float) -> int:
	_terrain_node(root, name_, _tensor_mesh(xs, zs, hs, skirt_m))
	_patches.append({"x0": xs[0], "x1": xs[xs.size() - 1], "z0": zs[0], "z1": zs[zs.size() - 1], "xs": xs, "zs": zs, "hs": hs})
	return (xs.size() - 1) * (zs.size() - 1) * 2


## La altura de la malla de suelo que se DIBUJA en (x, z): la interpolación por triángulos de la grilla donde cae el punto (la misma diagonal que arma `_tensor_mesh`).
## Difiere de `height_at` hasta unos decímetros (la malla es lineal entre nodos), y lo que va sobre el suelo (ríos, caminos, zanjas) tiene que ir sobre ESTA superficie
## para no quedar enterrado. Fuera de las mallas (solo el horizonte), `height_at`.
func rendered_h(x: float, z: float) -> float:
	for p in _patches:
		if x >= float(p.x0) and x <= float(p.x1) and z >= float(p.z0) and z <= float(p.z1):
			var xs: PackedFloat32Array = p.xs
			var zs: PackedFloat32Array = p.zs
			var hs: PackedFloat32Array = p.hs
			var nxp := xs.size()
			var i := clampi(xs.bsearch(x) - 1, 0, nxp - 2)
			var j := clampi(zs.bsearch(z) - 1, 0, zs.size() - 2)
			var tx := clampf((x - xs[i]) / maxf(xs[i + 1] - xs[i], 0.0001), 0.0, 1.0)
			var tz := clampf((z - zs[j]) / maxf(zs[j + 1] - zs[j], 0.0001), 0.0, 1.0)
			var ha := hs[j * nxp + i]
			var hb := hs[j * nxp + i + 1]
			var hc := hs[(j + 1) * nxp + i]
			var hd := hs[(j + 1) * nxp + i + 1]
			if tx + tz <= 1.0:  # triángulo (a, b, c): la diagonal va de b (arriba a la derecha) a c (abajo a la izquierda)
				return ha + (hb - ha) * tx + (hc - ha) * tz
			return hd + (hc - hd) * (1.0 - tx) + (hb - hd) * (1.0 - tz)
	return h(x, z)


## Construye ventana, contexto y horizonte bajo `root` y las dos texturas de pesos. La calidad `baja` usa la mitad de resolución en la ventana.
## Ventana y contexto se pegan SIN escalón: entre la ventana (nodos de 4 m) y el contexto (nodos de ≈ 30 m) hay una costura de una fila de celdas con los mismos nodos que el
## borde de la ventana (altura exacta de la grilla) que se apoya sobre el borde del contexto por interpolación; antes el contexto tenía un vértice cada 30 m sobre el borde y la
## malla dibujada saltaba hasta 0,67 m en la costura este (H-R1-11).
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
	_win_src = src
	_win_nx = nx
	_win_nz = nz
	_win_cell = cell
	_patches = []
	for j in range(zs.size()):
		var gj := mini(int(round((zs[j] - win.position.y) / cell)), nz - 1)
		for i in range(xs.size()):
			var gi := mini(int(round((xs[i] - win.position.x) / cell)), nx - 1)
			hs[j * xs.size() + i] = src[gj * nx + gi]
	var triangles := _add_patch(root, "terreno_ventana", xs, zs, hs, SKIRT_M)
	var t_window := Time.get_ticks_usec()
	# contexto: cuatro trozos gruesos (nodos de ≈ 30 m que salen de `height_at`) y, entre ellos y la ventana, cuatro costuras de una fila de celdas con los nodos de la ventana
	var ctx_step := float(cf.cell) * float(maxi(int(qcfg.get("context_step", 1)), 1))
	var xl_w := _lin(ctx.position.x, win.position.x, roundi((win.position.x - ctx.position.x) / ctx_step))
	var xl_e := _lin(win.end.x, ctx.end.x, roundi((ctx.end.x - win.end.x) / ctx_step))
	var zl_n := _lin(ctx.position.y, win.position.y, roundi((win.position.y - ctx.position.y) / ctx_step))
	var zl_s := _lin(win.end.y, ctx.end.y, roundi((ctx.end.y - win.end.y) / ctx_step))
	var cxs := _subset(xs, roundi(ctx_step / maxf(xs[1] - xs[0], 0.5)))  # columnas gruesas sobre el ancho de la ventana: son nodos de la ventana, para que la costura calce
	var czs := _subset(zs, roundi(ctx_step / maxf(zs[1] - zs[0], 0.5)))
	var z_coarse := _concat(_concat(zl_n, czs), zl_s)  # las filas gruesas de los costados (y del perímetro del contexto)
	var z_fine := _concat(_concat(zl_n, zs), zl_s)  # las mismas, con las filas de la ventana a su paso
	var n_out := PackedFloat32Array(zl_n.slice(0, zl_n.size() - 1))  # filas del norte sin la que toca la ventana
	var s_out := PackedFloat32Array(zl_s.slice(1))
	var w_out := PackedFloat32Array(xl_w.slice(0, xl_w.size() - 1))
	var e_out := PackedFloat32Array(xl_e.slice(1))
	var ncx := cxs.size()
	var ncz := z_coarse.size()
	# norte y sur: trozo grueso (columnas de la ventana a ≈ 30 m) más su costura
	var hs_n := _sampled(cxs, n_out)
	triangles += _add_patch(root, "terreno_contexto_norte", cxs, n_out, hs_n, 0.0)
	var edge_n := hs_n.slice((n_out.size() - 1) * ncx)
	var seam_ns := PackedFloat32Array()
	seam_ns.resize(xs.size() * 2)
	for i in range(xs.size()):
		seam_ns[i] = _lerp_poly(cxs, edge_n, xs[i])
		seam_ns[xs.size() + i] = _win_node(xs[i], win.position.y)
	triangles += _add_patch(root, "terreno_costura_norte", xs, PackedFloat32Array([n_out[n_out.size() - 1], win.position.y]), seam_ns, 1.0)
	var hs_s := _sampled(cxs, s_out)
	triangles += _add_patch(root, "terreno_contexto_sur", cxs, s_out, hs_s, 0.0)
	var edge_s := hs_s.slice(0, ncx)
	var seam_sn := PackedFloat32Array()
	seam_sn.resize(xs.size() * 2)
	for i in range(xs.size()):
		seam_sn[i] = _win_node(xs[i], win.end.y)
		seam_sn[xs.size() + i] = _lerp_poly(cxs, edge_s, xs[i])
	triangles += _add_patch(root, "terreno_costura_sur", xs, PackedFloat32Array([win.end.y, s_out[0]]), seam_sn, 1.0)
	# oeste y este: trozo grueso sobre todo el alto del contexto más su costura (que lleva las filas de la ventana a su paso)
	var hs_w := _sampled(w_out, z_coarse)
	triangles += _add_patch(root, "terreno_contexto_oeste", w_out, z_coarse, hs_w, 0.0)
	var edge_w := PackedFloat32Array()
	for j in range(ncz):
		edge_w.append(hs_w[j * w_out.size() + w_out.size() - 1])
	var seam_w := PackedFloat32Array()
	seam_w.resize(z_fine.size() * 2)
	for j in range(z_fine.size()):
		seam_w[j * 2] = _lerp_poly(z_coarse, edge_w, z_fine[j])
		seam_w[j * 2 + 1] = _seam_h(win.position.x, z_fine[j])
	triangles += _add_patch(root, "terreno_costura_oeste", PackedFloat32Array([w_out[w_out.size() - 1], win.position.x]), z_fine, seam_w, 1.0)
	var hs_e := _sampled(e_out, z_coarse)
	triangles += _add_patch(root, "terreno_contexto_este", e_out, z_coarse, hs_e, 0.0)
	var edge_e := PackedFloat32Array()
	for j in range(ncz):
		edge_e.append(hs_e[j * e_out.size()])
	var seam_e := PackedFloat32Array()
	seam_e.resize(z_fine.size() * 2)
	for j in range(z_fine.size()):
		seam_e[j * 2] = _seam_h(win.end.x, z_fine[j])
		seam_e[j * 2 + 1] = _lerp_poly(z_coarse, edge_e, z_fine[j])
	triangles += _add_patch(root, "terreno_costura_este", PackedFloat32Array([win.end.x, e_out[0]]), z_fine, seam_e, 1.0)
	var t_context := Time.get_ticks_usec()
	# horizonte: un anillo que arranca en el perímetro del contexto y sigue hasta ±8 km con crestas y estratos
	var top_x := _concat(_concat(xl_w, cxs), xl_e)
	var left_z := z_coarse
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
## Las paredes de la quebrada (pista de arte P2): al oeste y al este del contexto suben de 500 a 900 m en unos 2,5 km, con cárcavas y crestas dentadas, como los
## cerros que cierran el valle del río Grande a la altura del pueblo; hacia el norte y el sur el valle sigue y sube menos. Aspecto razonado (la forma de cada cerro es
## diseño): el relieve real de Copernicus llega solo hasta el borde del contexto y acá se lo continúa para que haya horizonte, no se lo reemplaza.
func ring_height(x: float, z: float, base: float, ox: float, oz: float) -> float:
	var edge_k := smoothstep(0.0, 260.0, maxf(ox, oz))
	var gullies := (_noise_gully.get_noise_2d(x, z) * 0.5 + 0.5)
	var swell := _noise_big.get_noise_2d(x, z) * 0.5 + 0.5
	var wall := 720.0 * smoothstep(0.0, 2600.0, ox) * (0.55 + 0.9 * swell) + 170.0 * smoothstep(150.0, 2000.0, ox) * gullies
	var valley := 230.0 * smoothstep(0.0, 5200.0, oz) * (0.6 + 0.8 * swell) + 90.0 * smoothstep(0.0, 2400.0, oz) * gullies
	return base + maxf(wall, valley) * edge_k


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


## La traza del río con dos prolongaciones solo de aspecto: al norte sigue con un poco de curva hasta PASAR el borde del contexto (antes terminaba 117 m antes, adentro del
## contexto, y la cinta se cortaba en seco en mitad del paisaje, H-R1-11) y al sur-este vuelve hacia el sur como en la lámina 03.
func river_polyline() -> PackedVector2Array:
	var river: Variant = terrain.call("river") if terrain != null and terrain.has_method("river") else null
	var line := pts((river as Dictionary).get("pts", [])) if river is Dictionary else PackedVector2Array()
	if line.size() < 2:
		return line
	var out := PackedVector2Array()
	var head: Vector2 = line[0]
	var dir_n := (line[0] - line[1]).normalized()
	var north: Array = []
	for k in range(1, 40):  # hacia el norte, de a 250 m y con un poco de curva para no ser una raya, hasta 100 m más allá del borde del contexto
		var far_pt := head + dir_n.rotated(0.03 * float(k)) * 250.0 * float(k)
		north.append(far_pt)
		if not ctx.grow(100.0).has_point(far_pt):
			break
	for k in range(north.size() - 1, -1, -1):
		out.append(north[k])
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


## La polilínea `line` con puntos de más para que ningún tramo pase de `max_seg_m` (una cinta con pocos puntos largos cortaba por debajo del suelo entre un punto y otro).
## Una línea cerrada sale sin repetir el punto de cierre.
func densify(line: PackedVector2Array, max_seg_m: float, closed: bool = false) -> PackedVector2Array:
	var count := line.size()
	if count < 2 or max_seg_m <= 0.0:
		return line
	var out := PackedVector2Array()
	for k in range(count if closed else count - 1):
		var a := line[k]
		var b := line[(k + 1) % count]
		var pieces := maxi(int(ceil(a.distance_to(b) / max_seg_m)), 1)
		for s in range(pieces):
			out.append(a.lerp(b, float(s) / float(pieces)))
	if not closed:
		out.append(line[count - 1])
	return out


## Cinta que sigue el relieve a lo largo de `line` (ancho `width` m, `raise` m sobre el suelo). Con `water`, la altura es plana de orilla a orilla (el nivel del agua) y
## lleva UV = (metros a lo largo, −1..1 a lo ancho) para el shader del agua. Con `max_seg_m` > 0 la línea se parte en tramos de ese largo como máximo y con `on_rendered` las
## alturas salen de la malla DIBUJADA (`rendered_h`) y no de `height_at`: así la cinta no queda enterrada entre un punto y otro (caminos y zanjas, H-R1-11).
func strip(parent: Node, line: PackedVector2Array, width: float, raise: float, material: Material, closed: bool = false, water: bool = false, name_: String = "",
		max_seg_m: float = 0.0, on_rendered: bool = false) -> MeshInstance3D:
	if max_seg_m > 0.0:
		line = densify(line, max_seg_m, closed)
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
		var level := (rendered_h(line[k].x, line[k].y) if on_rendered else h(line[k].x, line[k].y)) + raise
		for sign_ in [1.0, -1.0]:
			var q: Vector2 = line[k] + side * sign_
			var ground := rendered_h(q.x, q.y) if on_rendered else h(q.x, q.y)
			verts.append(Vector3(q.x, level if water else ground + raise, q.y))
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


## Distancia en metros de (x, z) al rectángulo de la ventana (0 dentro).
func _dist_to_window(p: Vector2) -> float:
	return Vector2(maxf(maxf(win.position.x - p.x, p.x - win.end.x), 0.0), maxf(maxf(win.position.y - p.y, p.y - win.end.y), 0.0)).length()


## Las muestras de la cinta del río: la traza recortada al contexto (la parte que cae afuera no tiene malla de suelo debajo: el anillo del horizonte sube y la cinta quedaba
## enterrada y cortada en seco, H-R1-11), a pasos de 4 m cerca de la ventana y de ≈ 16 m lejos, y con la opacidad que baja a 0 en los últimos metros de cada punta recortada
## (el río se pierde en la bruma en vez de terminar en un corte). Devuelve {pts, alpha, along}.
func river_samples(line: PackedVector2Array) -> Dictionary:
	var out := {"pts": PackedVector2Array(), "alpha": PackedFloat32Array(), "along": PackedFloat32Array()}
	if line.size() < 2:
		return out
	var inner := ctx.grow(-3.0)
	var fine := densify(line, RIVER_STEP_WIN_M, false)
	var first := -1
	var last := -1
	for i in range(fine.size()):
		if inner.has_point(fine[i]):
			if first < 0:
				first = i
			last = i
	if first < 0 or last <= first:
		return out
	var pts := PackedVector2Array()
	var carry := 0.0
	for i in range(first, last + 1):
		var near_window := _dist_to_window(fine[i]) <= 40.0
		carry += RIVER_STEP_WIN_M if i > first else 0.0
		if i == first or i == last or near_window or carry >= RIVER_STEP_CTX_M:
			pts.append(fine[i])
			carry = 0.0
	var along := PackedFloat32Array()
	var total := 0.0
	for k in range(pts.size()):
		if k > 0:
			total += pts[k].distance_to(pts[k - 1])
		along.append(total)
	var alpha := PackedFloat32Array()
	for k in range(pts.size()):
		var a := 1.0
		if first > 0:  # la punta de arriba se recortó: se apaga
			a = minf(a, smoothstep(0.0, RIVER_FADE_M, along[k]))
		if last < fine.size() - 1:  # la de abajo también
			a = minf(a, smoothstep(0.0, RIVER_FADE_M, total - along[k]))
		alpha.append(a)
	out.pts = pts
	out.alpha = alpha
	out.along = along
	return out


## Una cinta del río sobre la malla DIBUJADA: cada vértice queda por encima del suelo que se ve. Tiene `lateral` vértices a lo ancho (no solo los dos bordes: una cinta de
## 30 m con dos vértices cortaba el suelo por el medio donde el cauce tiene un montículo). Con `flat`, dentro de la ventana el agua es plana de orilla a orilla (el cauce está
## tallado y la orilla corta el agua donde el suelo sube: nunca hace falta subir un borde más de unos centímetros) y, lejos de la ventana (el contexto no tiene cauce), la cinta se
## apoya sobre el suelo en cada vértice; el paso entre las dos es gradual. `clear_win` y `clear_ctx` son los metros que la cinta flota sobre el suelo en cada zona.
func _river_ribbon(parent: Node3D, samples: Dictionary, width: float, clear_win: float, clear_ctx: float, material: Material, flat: bool, name_: String, lateral: int = 5) -> MeshInstance3D:
	var pts: PackedVector2Array = samples.pts
	var alpha: PackedFloat32Array = samples.alpha
	var along: PackedFloat32Array = samples.along
	var count := pts.size()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for k in range(count):
		var tangent := (pts[mini(k + 1, count - 1)] - pts[maxi(k - 1, 0)]).normalized()
		var side := Vector2(-tangent.y, tangent.x) * width * 0.5
		var win_k := 1.0 - smoothstep(0.0, RIVER_WIN_BLEND_M, _dist_to_window(pts[k]))  # 1 dentro de la ventana, 0 lejos de ella
		var clear := lerpf(clear_ctx, clear_win, win_k)
		var level := rendered_h(pts[k].x, pts[k].y) + clear
		for c in range(lateral):
			var u := lerpf(1.0, -1.0, float(c) / float(lateral - 1))  # de +1 a −1: el sentido de los índices deja la cara de arriba como la frontal (con el otro, la luz ve el reverso)
			var q: Vector2 = pts[k] + side * u
			var ground := rendered_h(q.x, q.y)
			var y := ground + clear
			if flat:
				y = lerpf(y, maxf(level, ground + 0.5 * clear_win), win_k)
			verts.append(Vector3(q.x, y, q.y))
			normals.append(Vector3.UP)
			uvs.append(Vector2(along[k], u))
			colors.append(Color(1.0, 1.0, 1.0, alpha[k]))
	for k in range(count - 1):
		for c in range(lateral - 1):
			var a := k * lateral + c
			var d := a + lateral
			indices.append_array(PackedInt32Array([a, a + 1, d, a + 1, d + 1, d]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := inst(parent, mesh, Vector3.ZERO, material, Vector3.ZERO, false)
	mi.name = name_
	return mi


## Material del lecho del río: de color de la paleta y con la opacidad que traen los vértices (la cinta se apaga en sus puntas).
func river_bed_mat(color_id: String, gain: float) -> StandardMaterial3D:
	if not _mats.has("lecho_rio"):
		var m := StandardMaterial3D.new()
		m.albedo_color = pc(color_id, gain)
		m.vertex_color_use_as_albedo = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.95
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.render_priority = 0
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if albedo else BaseMaterial3D.SHADING_MODE_PER_PIXEL
		_mats["lecho_rio"] = m
		_std_mats.append(m)
	return _mats["lecho_rio"]


## El río: lecho claro de grava y, encima, el agua turbia con su shader, las dos sobre la malla dibujada y terminadas donde termina el contexto. Devuelve la traza COMPLETA
## (con sus prolongaciones de aspecto: la usan la textura del contexto y los sauces).
func build_river(parent: Node3D) -> PackedVector2Array:
	var line := river_polyline()
	if line.size() < 2:
		return line
	var river: Dictionary = terrain.call("river")
	var width: Dictionary = river.get("bed_width_m", {})
	var bed_w := (float(width.get("min", 25.0)) + float(width.get("max", 40.0))) * 0.5
	var spec: Dictionary = (data.get("props", {}) as Dictionary).get("rio", {})
	var raise := float(spec.get("raise_m", 0.2))
	var samples := river_samples(line)
	if (samples.pts as PackedVector2Array).size() >= 2:
		var bed := river_bed_mat(str(spec.get("bed_color", "piedra_gris")), 1.18)
		_river_ribbon(parent, samples, bed_w * 1.15, raise, raise + 0.1, bed, false, "rio_lecho", 9)  # 9 vértices a lo ancho: ≈ 4 m entre uno y otro, como la grilla de la ventana
		water_mat.render_priority = 1
		_river_ribbon(parent, samples, bed_w * 0.62, raise + 0.15, raise + 0.25, water_mat, true, "rio_agua", 5)
		river_stats = {"muestras": (samples.pts as PackedVector2Array).size(), "largo_m": snappedf(float((samples.along as PackedFloat32Array)[(samples.along as PackedFloat32Array).size() - 1]), 1.0)}
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
