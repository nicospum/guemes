extends RefCounted
## Efectos, luces, lluvia y anillos de la vista del nivel «humahuaca» (pista visual).
##   · LUCES de la guardia (`render_state().lights`): brasero en la batería, ventana en la casa del cura, candil en la posta y fogatas junto a los centinelas. Se ven de
##     lejos (un resplandor de ≥ 30 px, una mancha cálida en el suelo y, en las calidades que lo permiten, una luz real): son información, no decorado.
##   · LLUVIA: rayas en el espacio de la cámara (shaders/humahuaca_rain.gdshader), cuyo número sube con la lluvia del ambiente.
##   · ANILLOS: el estado de cada objetivo (4 px) y el contorno de la UNIÓN de los círculos de visibilidad (2 px, tenue, sin cruces entre anillos: hallazgo I-R1.0-3);
##     se apagan con luz plena.
##   · EFECTOS (`fx`): fogonazo, humo, impacto, captura, pisadas, explosión y señal; con un tope según la calidad.

const V = preload("res://scripts/humahuaca/humahuaca_vocab.gd")
const VV = preload("res://scripts/humahuaca/view/vocab_view.gd")

## Anillo de cada frente según su estado, con la regla de color común (DIRECCION_DE_ARTE 2.1): objetivo oro que late (guardado y alertado, más rápido no: el estado lo
## dice el panel), rojo de enemigo cuando la guardia da la alarma o se pelea, celeste aliado cuando es nuestro.
const STATE_RING := {"guardado": "oro_laton", "alertado": "oro_laton", "en_alarma": "rojo_reservado", "asaltado": "rojo_reservado", "tomado": "celeste_produccion"}
const LIGHT_HEIGHT := {"brasero": 1.4, "ventana": 2.6, "candil": 2.0, "fogata": 0.9}
const RING_DEFAULTS := {"visibilidad": {"alpha": 0.3, "fade_from_m": 70.0, "fade_to_m": 180.0, "width_px": 1.25, "color": "celeste_produccion"},  # visual/r1 F3: más tenue
	"objetivo": {"alpha": 0.9, "width_px": 4.0}}
const RAIN_SHADER := "res://shaders/humahuaca_rain.gdshader"
## Cuánto se tiene que correr una agrupación (o cambiar su radio) y cada cuánto como mínimo se rearman los círculos de visibilidad que la siguen.
const RING_FOLLOW_M := 1.5
const RING_FOLLOW_R_M := 1.0
const RING_FOLLOW_MIN_S := 0.06

var gfx
var units
var host: Node = null
var ring_state: Dictionary = {"objs": [], "pools": []}
var rain_node: MultiMeshInstance3D = null
var rain_mat: ShaderMaterial = null
var omni_count := 0
var light_nodes: Dictionary = {}

var _fx: Array = []
var _ring_bucket := -999
var _ring_hash := 0
var _pool_age := 1.0  ## segundos reales desde el último rearmado de los círculos de visibilidad
var _ring_root: Node3D = null
var _flames: Array = []
var _pool_tex: GradientTexture2D = null
var _halo_tex: GradientTexture2D = null
var _time := 0.0
var _fire := 1.0  ## peso de los fuegos según la hora (set_fire)
var _pulse_mats: Array = []  ## [{mat, color, alpha, lo}]: los anillos de objetivo que laten (oro) o avisan (rojo)


func setup(gfx_ref, units_ref, host_ref: Node) -> void:
	gfx = gfx_ref
	units = units_ref
	host = host_ref


func reset() -> void:
	for entry in _fx:
		if is_instance_valid(entry.node):
			(entry.node as Node).free()
	_fx = []
	ring_state = {"objs": [], "pools": []}
	_ring_bucket = -999
	_ring_hash = 0
	_pool_age = 1.0
	_flames = []
	light_nodes = {}
	omni_count = 0
	rain_node = null
	_ring_root = null


# ---------------------------------------------------------------------------------------------------------------------
# Lluvia

## Las rayas de lluvia: un MultiMesh de cuadritos cuyo vértice se ubica en el espacio de la cámara. Con la calidad `baja` no hay (0 rayas).
func build_rain(root: Node3D) -> void:
	var rain_cfg: Dictionary = gfx.data.get("rain", {})
	var count := int((rain_cfg.get("streak_count", {}) as Dictionary).get(gfx.quality, 0))
	if count <= 0:
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	mm.mesh = quad
	mm.instance_count = count
	rain_mat = ShaderMaterial.new()
	rain_mat.shader = load(RAIN_SHADER) as Shader
	rain_mat.set_shader_parameter("streak_color", gfx.pc(str(rain_cfg.get("color", "agua_turbia")), 1.15))
	rain_mat.set_shader_parameter("streak_alpha", float(rain_cfg.get("streak_alpha", 0.35)))
	rain_mat.set_shader_parameter("len_px", float(rain_cfg.get("streak_px", 22.0)))
	rain_node = MultiMeshInstance3D.new()
	rain_node.name = "lluvia_rayas"
	rain_node.multimesh = mm
	rain_node.material_override = rain_mat
	rain_node.custom_aabb = AABB(Vector3(-20000.0, -20000.0, -20000.0), Vector3(40000.0, 40000.0, 40000.0))
	rain_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(rain_node)


func set_rain(value: float, albedo: bool) -> void:
	if rain_mat != null:
		rain_mat.set_shader_parameter("rain", clampf(value, 0.0, 1.0))
	if rain_node != null:
		rain_node.visible = not albedo and value > 0.02


# ---------------------------------------------------------------------------------------------------------------------
# Luces de la guardia

func _grad_tex(stops: PackedFloat32Array, colors: PackedColorArray, size: int) -> GradientTexture2D:
	var grad := Gradient.new()
	grad.offsets = stops
	grad.colors = colors
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = size
	tex.height = size
	return tex


## Resplandor de la llama que mira a la cámara (aditivo, sin niebla ni prueba de profundidad: se ve de lejos aunque el edificio lo tape).
func _halo_material(phase: float) -> StandardMaterial3D:
	if _halo_tex == null:
		_halo_tex = _grad_tex(PackedFloat32Array([0.0, 0.3, 1.0]), PackedColorArray([Color(1, 1, 1, 0.95), Color(1, 1, 1, 0.38), Color(1, 1, 1, 0.0)]), 64)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.albedo_texture = _halo_tex
	m.albedo_color = Color(fire_color(), 0.7)
	m.disable_fog = true
	m.no_depth_test = true
	m.render_priority = 8
	m.set_meta("phase", phase)
	return m


## Mancha cálida de luz sobre el suelo (un círculo aditivo que sigue el relieve al nivel de la llama): lo que la luz alcanza a iluminar a su alrededor.
func _pool_material() -> StandardMaterial3D:
	if _pool_tex == null:
		_pool_tex = _grad_tex(PackedFloat32Array([0.0, 0.55, 1.0]), PackedColorArray([Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.16), Color(1, 1, 1, 0.0)]), 64)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = _pool_tex
	m.albedo_color = fire_color()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_fog = true
	return m


func sync_lights(root: Node3D, state: Dictionary, layer_on: bool) -> void:
	units.clear_category(root, "light")
	_flames = []
	light_nodes = {}
	omni_count = 0
	var idx := 0
	for l in state.get("lights", []):
		if not (l is Dictionary):
			continue
		var x := float(l.get("x", 0.0))
		var z := float(l.get("z", 0.0))
		var kind := str(l.get("kind", "brasero"))
		var r_m := maxf(float(l.get("r_m", 20.0)), 6.0)
		var ground: float = gfx.h(x, z)
		var holder := Node3D.new()
		holder.name = "luz_" + str(l.get("id", kind))
		holder.position = Vector3(x, ground + light_height(kind), z)
		root.add_child(holder)
		light_nodes[str(l.get("id", kind))] = holder
		_fixture(holder, kind, ground)
		var flame: MeshInstance3D = gfx.inst(holder, gfx.cyl_mesh(0.0, 0.32, 0.9, 6), Vector3(0.0, 0.1, 0.0), gfx.flat_mat("oro_laton", 0.95, true, 1.6), Vector3.ZERO, false)
		flame.name = "llama"
		_flames.append({"node": flame, "phase": float(idx) * 1.7, "base": 1.0 if kind != "ventana" else 0.0})
		if kind == "ventana":
			flame.visible = false
			var glass: MeshInstance3D = gfx.inst(holder, gfx.box_mesh(Vector3(1.0, 1.5, 0.1)), Vector3(0.0, 0.0, 0.0), gfx.flat_mat("oro_laton", 1.0, false, 1.5), Vector3.ZERO, false)
			glass.name = "vidrio"
		var halo: MeshInstance3D = gfx.inst(holder, _halo_quad(), Vector3(0.0, 0.2, 0.0), _halo_material(float(idx) * 2.3), Vector3.ZERO, false)  # no baja de 30 px
		halo.name = "resplandor"
		units.register_scaled(halo, "light", 1.0, 30.0, r_m * 0.25)
		var pool: MeshInstance3D = gfx.inst(holder, _halo_quad(), Vector3(0.0, -(light_height(kind)) + 0.18, 0.0), _pool_material(), Vector3(-90.0, 0.0, 0.0), false)
		pool.name = "mancha"
		pool.scale = Vector3.ONE * r_m * 1.5
		var omni: OmniLight3D = null
		if omni_count < int(gfx.qcfg.get("omni_lights_max", 4)) and not gfx.albedo:
			# los fuegos ILUMINAN de verdad (DIRECCION_DE_ARTE B2): energía y alcance de `look.fires`, sin sombras (seis omnis sin sombra en Forward+ son baratos)
			var fires := fire_cfg()
			omni = OmniLight3D.new()
			omni.name = "luz_real"
			omni.omni_range = r_m * float(fires.get("range_k", 2.4))
			omni.omni_attenuation = float(fires.get("attenuation", 1.4))
			omni.light_energy = fire_energy() * _fire
			omni.light_color = fire_color()
			omni.shadow_enabled = false
			omni.light_specular = 0.35
			holder.add_child(omni)
			omni_count += 1
		_flames[_flames.size() - 1]["omni"] = omni
		_flames[_flames.size() - 1]["pool"] = pool
		_flames[_flames.size() - 1]["halo"] = halo
		idx += 1
	root.visible = layer_on and not gfx.albedo


## `humahuaca_visual.json: look.fires`: color (id de paleta con mezcla), energía por calidad, alcance (× el radio de la luz) y parpadeo de los fuegos.
## Altura de la llama sobre el suelo: la de la tabla, salvo el fogón de la pista P6 (brasas a 0,6 m; el brasero ya coincide en 1,4 m).
func light_height(kind: String) -> float:
	if kind == "fogata" and not gfx.model("fogon").is_empty():
		return 0.6
	return float(LIGHT_HEIGHT.get(kind, 1.4))


func fire_cfg() -> Dictionary:
	var look: Dictionary = gfx.data.get("look", {})
	return look.get("fires", {}) if look.get("fires", null) is Dictionary else {}


func fire_energy() -> float:
	var e: Variant = fire_cfg().get("energy", {})
	return float((e as Dictionary).get(gfx.quality, 6.0)) if e is Dictionary else 6.0


func fire_color() -> Color:
	var f := fire_cfg()
	var base: Color = gfx.pc(str(f.get("color", "oro_laton")), float(f.get("gain", 1.3)))
	if str(f.get("tint", "")) != "":
		base = base.lerp(gfx.pc(str(f.tint), float(f.get("gain", 1.3))), clampf(float(f.get("tint_mix", 0.0)), 0.0, 1.0))
	return base


## Cuánto pesan los fuegos según la hora (1 de noche, menos al alba y de día: `lights.<hora>.fire`, mezclado por la vista). La llama y su resplandor siguen
## marcando dónde está la guardia (son información), pero la luz que echan alrededor se apaga cuando el día la vuelve inútil.
func set_fire(k: float) -> void:
	_fire = clampf(k, 0.0, 1.5)
	gfx.set_night_glow(_fire)


func _make_quad() -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	return q


func _halo_quad() -> Mesh:
	return gfx.cached_mesh("halo", Callable(self, "_make_quad"))


## La pieza que sostiene cada llama: el cesto de hierro del brasero, el candil colgado, los troncos de la fogata o el marco de la ventana.
func _fixture(holder: Node3D, kind: String, ground: float) -> void:
	var y_down := -(light_height(kind))
	var model_key := str({"brasero": "brasero", "fogata": "fogon"}.get(kind, ""))
	if model_key != "" and not gfx.model(model_key).is_empty():  # el brasero y el fogón de la pista P6 (escala 1, origen en el suelo); la llama sigue a la altura de LIGHT_HEIGHT
		var mi := MeshInstance3D.new()
		mi.name = "modelo_" + model_key
		mi.mesh = gfx.model(model_key).mesh
		mi.position = Vector3(0.0, y_down, 0.0)
		holder.add_child(mi)
		return
	match kind:
		"brasero":
			gfx.inst(holder, gfx.cyl_mesh(0.42, 0.26, 0.3, 8), Vector3(0.0, -0.2, 0.0), gfx.mat("hierro", 0.55, 1.0, 0.6))
			for k in range(3):
				var a := TAU * float(k) / 3.0
				gfx.inst(holder, gfx.box_mesh(Vector3(0.08, 1.1, 0.08)), Vector3(cos(a) * 0.25, y_down * 0.5 - 0.2, sin(a) * 0.25), gfx.mat("hierro", 0.55, 1.0, 0.6))
			gfx.inst(holder, gfx.sphere_mesh(0.3, 8, 4), Vector3(0.0, -0.05, 0.0), gfx.flat_mat("rojo_reservado", 1.0, false, 1.3), Vector3.ZERO, false)
		"candil":
			gfx.inst(holder, gfx.box_mesh(Vector3(0.06, 0.8, 0.06)), Vector3(0.0, 0.7, 0.0), gfx.mat("madera_oscura"))
			gfx.inst(holder, gfx.cyl_mesh(0.18, 0.12, 0.28, 6), Vector3(0.0, -0.2, 0.0), gfx.mat("hierro", 0.5, 1.0, 0.6))
		"fogata":
			for k in range(4):
				var a2 := TAU * float(k) / 4.0 + 0.4
				gfx.inst(holder, gfx.box_mesh(Vector3(0.9, 0.12, 0.12)), Vector3(cos(a2) * 0.2, y_down + 0.12, sin(a2) * 0.2), gfx.mat("madera_oscura", 0.9, 1.1), Vector3(0.0, rad_to_deg(-a2), 12.0))
		"ventana":
			gfx.inst(holder, gfx.box_mesh(Vector3(1.3, 1.8, 0.08)), Vector3(0.0, 0.0, -0.06), gfx.mat("madera_oscura"))


func animate_lights(delta: float) -> void:
	_time += delta
	var amp := float(fire_cfg().get("flicker", 0.12))
	var energy := fire_energy() * _fire
	for f in _flames:
		if not is_instance_valid(f.node):
			continue
		var node: Node3D = f.node
		var wave := sin(_time * 9.0 + float(f.phase)) * 0.66 + sin(_time * 23.0 + float(f.phase) * 2.0) * 0.34
		var flick := 0.95 + 0.12 * wave
		node.scale = Vector3(flick, 0.9 + 0.3 * flick, flick)
		var omni: Variant = f.get("omni", null)
		if omni != null and is_instance_valid(omni):
			(omni as OmniLight3D).light_energy = energy * (1.0 + amp * wave)
			(omni as OmniLight3D).visible = energy > 0.05
		var pool: Variant = f.get("pool", null)
		if pool != null and is_instance_valid(pool):
			(pool as GeometryInstance3D).transparency = clampf(1.0 - _fire * (0.92 + 0.08 * wave), 0.0, 0.85)
	var pulse := 0.5 + 0.5 * sin(_time * 3.2)
	for p in _pulse_mats:
		var m: StandardMaterial3D = p.mat
		var c: Color = p.color
		var k := lerpf(float(p.lo), 1.0, pulse)
		m.albedo_color = Color(c.r * lerpf(0.8, 1.15, pulse), c.g * lerpf(0.8, 1.15, pulse), c.b * lerpf(0.8, 1.15, pulse), float(p.alpha) * k)


# ---------------------------------------------------------------------------------------------------------------------
# Anillos del suelo: estado de los objetivos y visibilidad de las partidas

func ring_cfg(kind: String) -> Dictionary:
	var cfg: Dictionary = (RING_DEFAULTS[kind] as Dictionary).duplicate()
	var rings: Variant = (gfx.data.get("fog", {}) as Dictionary).get("anillos", {})
	if rings is Dictionary and (rings as Dictionary).get(kind, null) is Dictionary:
		cfg.merge((rings as Dictionary)[kind], true)
	return cfg


## Opacidad de los anillos de visibilidad según cuánto se ve: plena de noche y casi nula con luz plena (la visibilidad que importa es la corta).
func pool_alpha(visibility_m: float) -> float:
	var cfg := ring_cfg("visibilidad")
	var t := clampf((visibility_m - float(cfg.fade_from_m)) / maxf(float(cfg.fade_to_m) - float(cfg.fade_from_m), 1.0), 0.0, 1.0)
	return float(cfg.alpha) * (1.0 - t * t * (3.0 - 2.0 * t))


## Ancho en metros de un trazo del suelo que debe medir `px` píxeles reales donde mira la cámara (sin cámara: lo que mide a la distancia del cuadro inicial).
func ring_width_m(px: float) -> float:
	var cam: Camera3D = host.get_viewport().get_camera_3d() if host != null and host.is_inside_tree() else null
	if cam == null or not cam.is_inside_tree():
		return px * 0.55
	var forward := -cam.global_transform.basis.z
	var reach := maxf((cam.global_position.y - gfx.FLAT_H) / maxf(-forward.y, 0.08), 5.0)
	# visual/r1 F3: el piso baja de 0,3 a 0,12 m: con la cámara a ~167 m el trazo de 1,25 px de los círculos de visibilidad quedaba clavado en 0,3 m (≈ 2 px)
	return clampf(px / gfx.screen_scale(host) * gfx.meters_per_px_at(cam, cam.global_position + forward * reach), 0.12, 8.0)


## Cubo (en pasos de ×1,3) del ancho que hoy piden los trazos: los anillos se rearman solo cuando cambia, no en cada cuadro.
func ring_bucket_now() -> int:
	return int(round(log(maxf(ring_width_m(1.0), 0.05)) / log(1.3)))


func check_rings(root: Node3D) -> void:
	if _ring_bucket != ring_bucket_now():
		rebuild_rings(root)


## Guarda lo que dijo render_state() sobre los objetivos y los círculos de visibilidad y rearma los anillos solo si algo cambió.
func sync_objectives(root: Node3D, state: Dictionary, lm_by_id: Dictionary, footprint_of: Callable) -> void:
	var objs: Array = []
	for o in state.get("objectives", []):
		if not (o is Dictionary):
			continue
		var id := str(o.get("id", ""))
		var radius := 14.0
		if lm_by_id.has(id):
			var fp: Dictionary = footprint_of.call(lm_by_id[id])
			radius = maxf(float(fp.w), float(fp.d)) * 0.5 + 4.0
		objs.append({"id": id, "c": Vector2(float(o.get("x", 0.0)), float(o.get("z", 0.0))), "r": radius, "color": str(STATE_RING.get(str(o.get("state", "guardado")), "piedra_gris"))})
	var pools: Array = []
	for p in state.get("visibility_pools", []):
		if p is Dictionary:
			pools.append({"x": float(p.get("x", 0.0)), "z": float(p.get("z", 0.0)), "r": maxf(float(p.get("r", 20.0)), 3.0)})
	var wanted := {"objs": objs, "pools": pools}
	if wanted.hash() != _ring_hash or _ring_bucket != ring_bucket_now():  # la versión sube en casi cada paso: se rearma solo si cambió algo de los anillos
		ring_state = wanted
		_ring_hash = wanted.hash()
		_pool_age = 0.0
		rebuild_rings(root)


## Los círculos de visibilidad siguen a las agrupaciones que marchan. Sus posiciones (y su radio, que sale del ambiente) cambian en cada paso de las reglas sin subir la
## `version` del estado (hallazgo H-R1-9), así que se los mira en cada cuadro; rearmarlos es lo caro (~1 ms), por eso solo se rearman cuando alguno se corrió `RING_FOLLOW_M`
## metros o cambió `RING_FOLLOW_R_M` de radio y a lo sumo cada `RING_FOLLOW_MIN_S` segundos: 1,5 m sobre un círculo de decenas de metros no se ve.
func follow_pools(root: Node3D, state: Dictionary, delta: float) -> void:
	_pool_age += delta
	var old: Array = ring_state.pools
	var listed: Array = state.get("visibility_pools", [])
	var changed := listed.size() != old.size()
	if not changed:
		for i in range(listed.size()):
			var p: Variant = listed[i]
			if not (p is Dictionary):
				continue
			var shift := absf(float(p.get("x", 0.0)) - float(old[i].x)) + absf(float(p.get("z", 0.0)) - float(old[i].z))
			if shift > RING_FOLLOW_M or absf(maxf(float(p.get("r", 20.0)), 3.0) - float(old[i].r)) > RING_FOLLOW_R_M:
				changed = true
				break
	if not changed or _pool_age < RING_FOLLOW_MIN_S:
		return
	var pools: Array = []
	for p in listed:
		if p is Dictionary:
			pools.append({"x": float(p.get("x", 0.0)), "z": float(p.get("z", 0.0)), "r": maxf(float(p.get("r", 20.0)), 3.0)})
	_pool_age = 0.0
	ring_state = {"objs": ring_state.objs, "pools": pools}
	_ring_hash = ring_state.hash()
	rebuild_rings(root)


func rebuild_rings(root: Node3D) -> void:
	if root == null:
		return
	for child in root.get_children():
		root.remove_child(child)
		child.free()
	var objective_cfg := ring_cfg("objetivo")
	var objective_w := ring_width_m(float(objective_cfg.width_px))
	_pulse_mats = []
	for o in ring_state.objs:
		# regla de color (DIRECCION_DE_ARTE 2.1): el objetivo es ORO y late; en alarma o asaltado, rojo de enemigo; tomado, celeste aliado. Un filete de tinta debajo
		# lo separa del suelo claro del alba y de la cal
		var under: MeshInstance3D = gfx.strip(root, gfx.circle(o.c, float(o.r)), objective_w * 2.1, 0.45, gfx.flat_mat("negro_textil", 0.45), true)
		under.name = "filete_" + str(o.id)
		var color_id := str(o.color)
		var gain := 1.1 if color_id == "oro_laton" else (1.2 if color_id == "rojo_reservado" else 1.1)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.disable_fog = true
		var col: Color = gfx.pc(color_id, gain)
		mat.albedo_color = Color(col.r, col.g, col.b, float(objective_cfg.alpha))
		var ring: MeshInstance3D = gfx.strip(root, gfx.circle(o.c, float(o.r)), objective_w, 0.5, mat, true)
		ring.name = "objetivo_" + str(o.id)
		if color_id in ["oro_laton", "rojo_reservado"]:
			_pulse_mats.append({"mat": mat, "color": col, "alpha": float(objective_cfg.alpha), "lo": 0.55 if color_id == "oro_laton" else 0.35})
	var pools: Array = ring_state.pools
	var seen_m := 0.0
	for p in pools:
		seen_m = maxf(seen_m, float(p.r))
	var pool_cfg := ring_cfg("visibilidad")
	var alpha := pool_alpha(seen_m)
	if alpha >= 0.03:
		var pool_w := ring_width_m(float(pool_cfg.width_px))
		var material: Material = gfx.flat_mat(str(pool_cfg.color), alpha)
		var index := 0
		for arc in pool_arcs(pools):
			var pool: MeshInstance3D = gfx.strip(root, arc.pts, pool_w, 0.5, material, bool(arc.closed))
			pool.name = "visibilidad_%d" % index
			index += 1
	_ring_bucket = ring_bucket_now()


## Contorno de la UNIÓN de los círculos de visibilidad `[{x, z, r}]`: de cada círculo se conservan solo los arcos que no caen dentro de otro. Dibujados enteros, los
## anillos de cinco fichas se cruzaban en diez puntos y ensuciaban el mapa (hallazgo I-R1.0-3). Devuelve `[{pts: PackedVector2Array, closed: bool}]`; los extremos de
## cada arco son los puntos exactos de cruce entre dos círculos.
func pool_arcs(pools: Array) -> Array:
	var circles: Array = []
	for p in pools:
		if p is Dictionary and float(p.get("r", 0.0)) > 1.0:
			circles.append({"c": Vector2(float(p.get("x", 0.0)), float(p.get("z", 0.0))), "r": float(p.r)})
	var out: Array = []
	for i in range(circles.size()):
		var ci: Vector2 = circles[i].c
		var ri: float = circles[i].r
		var covered: Array = []  # intervalos [a0, a1] de ángulo (dentro de 0..2π) que tapan los otros círculos
		var inside := false
		for j in range(circles.size()):
			if j == i:
				continue
			var cj: Vector2 = circles[j].c
			var rj: float = circles[j].r
			var d := ci.distance_to(cj)
			if d >= ri + rj - 0.01:  # separados o tangentes por fuera: no se tapan
				continue
			if d + ri <= rj + 0.01 and (ri < rj - 0.01 or j < i):  # i entera dentro de j (si son iguales, gana el de menor índice)
				inside = true
				break
			if d + rj <= ri + 0.01:  # j entera dentro de i: no tapa nada del borde de i
				continue
			var theta := atan2(cj.y - ci.y, cj.x - ci.x)
			var half := acos(clampf((ri * ri + d * d - rj * rj) / (2.0 * ri * d), -1.0, 1.0))
			var a0 := fposmod(theta - half, TAU)
			var a1 := a0 + 2.0 * half
			if a1 > TAU:
				covered.append([a0, TAU])
				covered.append([0.0, a1 - TAU])
			else:
				covered.append([a0, a1])
		if inside:
			continue
		covered.sort_custom(func(a, b): return a[0] < b[0])
		var free: Array = []
		var cursor := 0.0
		for span in covered:
			if span[0] > cursor + 1.0e-4:
				free.append([cursor, span[0]])
			cursor = maxf(cursor, span[1])
		if cursor < TAU - 1.0e-4:
			free.append([cursor, TAU])
		if free.size() > 1 and free[0][0] <= 1.0e-4 and free[free.size() - 1][1] >= TAU - 1.0e-4:  # un arco que cruza el ángulo 0 viene partido en dos
			var tail: Array = free.pop_back()
			free[0] = [tail[0] - TAU, free[0][1]]
		for arc in free:
			var length: float = arc[1] - arc[0]
			var steps := maxi(int(ceil(length / deg_to_rad(5.0))), 2)
			var closed := length >= TAU - 1.0e-3
			var pts := PackedVector2Array()
			for k in range(steps if closed else steps + 1):
				var a: float = arc[0] + length * float(k) / float(steps)
				pts.append(ci + Vector2(cos(a), sin(a)) * ri)
			out.append({"pts": pts, "closed": closed})
	return out


# ---------------------------------------------------------------------------------------------------------------------
# Efectos

func fx(root: Node3D, kind: String, pos: Vector2, opts: Dictionary = {}) -> void:
	if not VV.FX_KINDS.has(kind) or root == null:
		return
	var spec: Dictionary = (gfx.data.get("fx", {}) as Dictionary).get(kind, {})
	while _fx.size() >= int(gfx.qcfg.get("fx_max", 24)) and not _fx.is_empty():
		_free_fx(0)
	var radius := float(spec.get("radius_m", 3.0)) * float(opts.get("scale", 1.0))
	var y0: float = gfx.h(pos.x, pos.y) + float(opts.get("height", 1.2))
	var color := str(spec.get("color", "blanco_textil"))
	var additive := kind in ["fogonazo", "explosion", "senal"]
	var holder := Node3D.new()
	holder.name = "fx_" + kind
	holder.position = Vector3(pos.x, y0, pos.y)
	root.add_child(holder)
	var puffs := 1
	match kind:
		"humo":
			puffs = 4
		"explosion":
			puffs = 3
		"senal":
			puffs = 3
		"pisadas":
			puffs = 2
	var parts: Array = []
	for k in range(puffs):
		var puff: MeshInstance3D = gfx.inst(holder, gfx.sphere_mesh(1.0, 10, 5), Vector3(float(k) * 0.35 - float(puffs) * 0.17, float(k) * 0.4, float(k % 2) * 0.4), gfx.flat_mat(color, 0.9, additive, 1.3 if additive else 1.0), Vector3.ZERO, false)
		parts.append(puff)
	if kind == "captura":  # un anillo en el suelo que se abre
		var ring: MeshInstance3D = gfx.flat_ring(holder, 1.0, 0.18, color, 0.9)
		ring.position = Vector3(0.0, -y0 + gfx.h(pos.x, pos.y) + 0.25, 0.0)
		parts.append(ring)
	holder.scale = Vector3.ONE * radius * 0.3
	_fx.append({"node": holder, "parts": parts, "age": 0.0, "life": maxf(float(spec.get("life_s", 0.6)), 0.05), "r": radius, "rise": float(spec.get("rise_m", 1.0)), "y0": y0, "kind": kind})


func _free_fx(index: int) -> void:
	var entry: Dictionary = _fx[index]
	if is_instance_valid(entry.node):
		(entry.node as Node).free()
	_fx.remove_at(index)


func update_fx(delta: float) -> void:
	for k in range(_fx.size() - 1, -1, -1):
		var entry: Dictionary = _fx[k]
		entry.age = float(entry.age) + delta
		var t := clampf(float(entry.age) / float(entry.life), 0.0, 1.0)
		if t >= 1.0 or not is_instance_valid(entry.node):
			_free_fx(k)
		else:
			var node: Node3D = entry.node
			node.scale = Vector3.ONE * float(entry.r) * lerpf(0.3, 1.0, t)
			node.position.y = float(entry.y0) + float(entry.rise) * t
			for part in entry.parts:
				if is_instance_valid(part):
					(part as GeometryInstance3D).transparency = t


func clear_fx() -> void:
	for k in range(_fx.size() - 1, -1, -1):
		_free_fx(k)


func fx_count() -> int:
	return _fx.size()
