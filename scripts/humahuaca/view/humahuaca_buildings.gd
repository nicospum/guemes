extends RefCounted
## Edificios, rasgos y vegetación de la vista del nivel «humahuaca» (pista visual): un nodo por hito con su huella, el templo, la batería, la casa del cura, la posta
## y la torre que arma el generador procedural (humahuaca_gen.gd); las tapias, zanjas, caminos y barricadas que salen de `terrain.features(...)` (el nivel no inventa
## entradas propias: la posta se dibuja con sus tapias reales); el núcleo de casas sobre las manzanas del diseño de nivel; y el anillo de contenido (churqui,
## cardón, sauce y rocas) repartido según pendiente y cercanía al río. Todo con el material de props (color de vértice de la paleta) y en pocas mallas fusionadas.
## No toca el estado de las reglas: solo lee el terreno.

const V = preload("res://scripts/humahuaca/humahuaca_vocab.gd")
const Gen = preload("res://scripts/humahuaca/view/humahuaca_gen.gd")

const BURY_M := 0.3

var gfx
var gen
var landmarks: Array = []
var lm_by_id: Dictionary = {}
var lm_nodes: Dictionary = {}
var house_count := 0
var triangle_count := 0
var content_counts: Dictionary = {}
var extra_trees: Array = []  ## árboles de patio (sauces chicos) que deja el núcleo; los planta build_vegetation
var _model_xf: Dictionary = {}  ## clave de modelo → [Transform3D] de las casas que se dibujan con un GLB
var _lit: Array = []  ## [Transform3D] de las puertas con lumbre

var _terrain: RefCounted = null


func setup(gfx_ref, terrain_ref: RefCounted) -> void:
	gfx = gfx_ref
	_terrain = terrain_ref
	gen = Gen.new(gfx.palette)


func prop_spec(id: String, type_name: String) -> Dictionary:
	var props: Dictionary = gfx.data.get("props", {})
	var by_id: Dictionary = props.get("por_id", {})
	if by_id.has(id):
		return by_id[id]
	return (props.get("por_tipo", {}) as Dictionary).get(type_name, {"builder": "caja_con_techo", "color": "adobe", "default_height_m": 2.0})


## {center, w, d, r, yaw}: la huella de un hito en el plano (un polígono se reduce a su caja envolvente, sin giro).
func footprint(lm: Dictionary) -> Dictionary:
	var fp: Variant = lm.get("footprint", {})
	var out := {"center": Vector2(float(lm.get("x", 0.0)), float(lm.get("z", 0.0))), "w": 6.0, "d": 6.0, "r": 0.0, "yaw": float(lm.get("yaw_deg", 0.0))}
	if not (fp is Dictionary):
		return out
	if fp.has("poly"):
		var poly: PackedVector2Array = gfx.pts(fp.poly)
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
func footprint_corners(fp: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array()
	var c: Vector2 = fp.center
	var yaw := deg_to_rad(float(fp.yaw))
	for k in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var lx: float = k.x * float(fp.w) * 0.5
		var lz: float = k.y * float(fp.d) * 0.5
		out.append(c + Vector2(lx * cos(yaw) - lz * sin(yaw), lx * sin(yaw) + lz * cos(yaw)))
	return out


func _mesh_node(parent: Node, name_: String, mesh: ArrayMesh, shadow: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name_
	mi.mesh = mesh
	mi.material_override = gfx.props_mat
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	var n := 0
	for s in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(s)
		n += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	triangle_count += n
	return mi


# ---------------------------------------------------------------------------------------------------------------------
# Hitos

func build_landmarks(root: Node3D) -> void:
	var list: Variant = _terrain.call("landmarks", {}) if _terrain != null and _terrain.has_method("landmarks") else []
	if not (list is Array):
		return
	for lm in list:
		if lm is Dictionary and lm.has("id") and lm.has("x") and lm.has("z"):
			landmarks.append(lm)
			lm_by_id[str(lm.id)] = lm
			_build_landmark(root, lm)


func _build_landmark(root: Node3D, lm: Dictionary) -> void:
	var id := str(lm.id)
	var spec := prop_spec(id, str(lm.get("type", "hito")))
	var builder := str(spec.get("builder", "caja_con_techo"))
	if builder == "ninguno":
		return
	var fp := footprint(lm)
	var ground: float = gfx.h(float(fp.center.x), float(fp.center.y))
	for p in footprint_corners(fp):
		ground = minf(ground, gfx.h(p.x, p.y))
	var node := Node3D.new()
	node.name = "hito_" + id
	node.position = Vector3(fp.center.x, ground, fp.center.y)
	node.rotation.y = -deg_to_rad(float(fp.yaw))
	root.add_child(node)
	lm_nodes[id] = node
	var hgt := float(lm.get("height_m", 0.0))
	if hgt <= 0.0:
		hgt = float(spec.get("default_height_m", 2.0))
	var w := float(fp.w)
	var d := float(fp.d)
	var color_id := str(spec.get("color", "adobe"))
	if builder in ["caja_con_techo", "templo_nave", "casa_cura", "torre", "plataforma", "patio_posta", "patio_muros", "polvorin"]:  # la huella: una mancha oscura de tierra bajo el edificio
		var pad := 9.0 if builder == "templo_nave" else 4.0  # el templo, más grande: es el hito que tiene que leerse a 470 m
		var hw := w
		var hd := d
		var mk := str(spec.get("model", ""))
		if mk != "" and not gfx.model(mk).is_empty() and str(spec.get("model_fit", "")) == "uniforme":  # la huella sigue al modelo sin deformar (la capilla es más corta que la nave de diseño)
			var mbox: AABB = gfx.model_fit(mk, w, d, -1.0, true) * (gfx.model(mk).aabb as AABB)
			hw = mbox.size.x
			hd = mbox.size.z
			pad = 4.0
		gfx.patch(node, hw + pad, hd + pad, 0.0, 0.07, gfx.mat("sedimento_humedo", 0.95, 0.78)).name = "huella"
	var model_key := str(spec.get("model", ""))
	if model_key != "" and not gfx.model(model_key).is_empty():  # un modelo GLB de la pista P6 (props.por_id.<id>.model): se lo estira a la huella y al alto del hito
		var mi := MeshInstance3D.new()
		mi.name = "modelo_" + model_key
		mi.mesh = gfx.model(model_key).mesh
		mi.transform = gfx.model_fit(model_key, w, d, hgt if bool(spec.get("model_fit_height", true)) else -1.0, str(spec.get("model_fit", "")) == "uniforme")
		node.add_child(mi)
		if builder == "corral":  # visual/r1 F5: el piso pisoteado del corral, como el del corral procedural (con el modelo se había perdido): la pirca sola no se lee desde lejos
			gfx.patch(node, w * 0.94, d * 0.94, 0.0, 0.1, gfx.mat(str(spec.get("floor_color", "sedimento_humedo")), 0.95, float(spec.get("floor_gain", 0.85))), true).name = "piso"
		if model_key == "capilla":  # la portada de la capilla con lumbre (velas): la capilla se reconoce de noche desde la distancia de juego
			var box: AABB = gfx.model(model_key).aabb
			var door := MeshInstance3D.new()
			door.name = "portada_con_lumbre"
			var dm := BoxMesh.new()
			dm.size = Vector3(1.5, 2.3, 0.1)
			door.mesh = dm
			door.material_override = gfx.night_glow_mat()
			# visual/r1 F5: la portada real de la capilla del kit (manifiesto de casas); la caja de casa_capilla_a incluye contrafuertes y escalón por delante de la puerta
			var at: Variant = door_of(model_key)
			var door_at: Vector3 = (at as Vector3) + Vector3(0.0, 0.0, -0.06) if at is Vector3 else Vector3(box.get_center().x, box.position.y + 1.3, box.position.z - 0.06)
			door.transform = mi.transform * Transform3D(Basis.IDENTITY, door_at)
			door.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.add_child(door)
		return
	var mb = gen.builder()
	match builder:
		"templo_nave":  # nave simple encalada a dos aguas: sin torres, sin fachada de 1880, caballete en 7 m
			gen.add_temple(mb, {"w": w, "d": d, "ridge_m": minf(hgt, 7.0), "eave_ratio": float(spec.get("eave_ratio", 0.78)), "color": color_id,
				"roof_color": str(spec.get("roof_color", "paja")), "trim_color": str(spec.get("trim_color", "madera_oscura"))})
			_mesh_node(node, "templo", mb.build())
		"casa_cura":
			gen.add_cura_house(mb, w, d, maxf(hgt, 3.0))
			_mesh_node(node, "casa", mb.build())
		"plataforma":  # la batería: losa de tierra con parapeto y piezas bajas (nunca un fuste)
			var piece_model: bool = not gfx.model("pieza_artilleria").is_empty()
			gen.add_battery(mb, w, d, clampf(hgt, 1.0, 2.0), int(spec.get("pieces", 3)), float(spec.get("slab_m", 0.9)), not piece_model)
			_mesh_node(node, "bateria", mb.build())
			if piece_model:  # las piezas reales de la pista P6 (cañón de campaña con cureña), cada una en su cañonera y con la boca al oeste
				var k := 0
				for at in gen.battery_piece_spots(w, d, int(spec.get("pieces", 3)), float(spec.get("slab_m", 0.9))):
					var piece := MeshInstance3D.new()
					piece.name = "pieza_%d" % k
					piece.mesh = gfx.model("pieza_artilleria").mesh
					piece.transform = Transform3D(Basis(Vector3.UP, PI * 0.5), at)  # el frente del modelo (−Z) pasa a −X, el oeste del hito
					node.add_child(piece)
					k += 1
		"torre":
			gen.add_tower(mb, w, d, hgt)
			_mesh_node(node, "torre", mb.build())
		"patio_posta", "patio_muros":  # el patio por dentro; los muros son las tapias del terreno (terrain.features("tapia")), no una entrada inventada acá
			_build_posta(node, mb, w, d)
		"polvorin":
			gen.add_house(mb, w, d, hgt, 1, 1.0, 0.0, "madera_oscura")
			_mesh_node(node, "polvorin", mb.build())
		"parque":
			gen.add_parque(mb, w, d)
			_mesh_node(node, "parque", mb.build())
		"corral":
			gen.add_fence_ring(mb, w, d, hgt)
			_mesh_node(node, "corral", mb.build(), false)
			gfx.patch(node, w, d, 0.0, 0.1, gfx.mat("sedimento_humedo", 0.95, 0.85))
		"plano":
			var alpha := float(spec.get("alpha", 1.0))
			var ground_mat: Material = gfx.mat(color_id, 0.95, float(spec.get("gain", 1.0)))
			if str(spec.get("material", "")) == "suelo":  # la plaza: el mismo suelo que la rodea (tierra apisonada, lluvia y charcos), no un parche liso más claro que todo
				ground_mat = gfx.terrain_mat
			gfx.patch(node, w, d, float(fp.r), float(spec.get("raise_m", 0.12)), gfx.flat_mat(color_id, alpha) if alpha < 1.0 else ground_mat)
			if bool(spec.get("outline", false)) and str(lm.get("type", "")) == "partida" and float(fp.r) <= 0.0:  # el contorno de la zona de partida (un borde fino y tenue)
				var rect := PackedVector2Array([Vector2(-w * 0.5, -d * 0.5), Vector2(w * 0.5, -d * 0.5), Vector2(w * 0.5, d * 0.5), Vector2(-w * 0.5, d * 0.5)])
				var world_pts := PackedVector2Array()
				for q in rect:
					world_pts.append(Vector2(node.position.x, node.position.z) + q)
				# visual/r1 F3: el borde era de 1,6 m y opacidad 0,55, la línea más fuerte del cuadro a ~167 m; ahora más fino y tenue (sigue marcando la zona)
				gfx.strip(root, world_pts, float(spec.get("outline_width_m", 1.6)), 0.3, gfx.flat_mat(color_id, float(spec.get("outline_alpha", 0.55))), true, false, "borde_" + id)
		"mojon":  # un mojón de piedra con un anillo de color que sigue el relieve (acceso, salida, entrada)
			gfx.inst(node, gfx.cyl_mesh(0.4, 1.2, 2.0, 8), Vector3(0.0, 0.8, 0.0), gfx.mat(color_id), Vector3.ZERO, true)
			gfx.strip(root, gfx.circle(Vector2(node.position.x, node.position.z), maxf(float(fp.r), 4.0)), 1.6, 0.25, gfx.flat_mat(str(spec.get("ring_color", "oro_laton")), 0.9), true)
		_:  # un edificio genérico de adobe con su techo
			gen.add_house(mb, w, d, maxf(hgt, 1.2), 1 if str(lm.get("type", "")) != "objetivo" else 0, 1.0, 0.25)
			_mesh_node(node, "casa", mb.build())


## El patio de la posta: tierra apisonada, la casa de posta contra el muro norte, carretas y bultos. Sin muros propios.
func _build_posta(node: Node3D, mb, w: float, d: float) -> void:
	# visual/r1 F5: el piso de tierra apisonada y barrida del patio, un poco más claro que el campo de afuera (ganancia 1,07 → 1,15, diseño): con las tapias y la casa de
	# posta del kit, más oscuras, el patio y el parque de artillería se recortan del suelo a la distancia de juego (B-062 c, V06)
	gfx.patch(node, w - 1.0, d - 1.0, 0.0, 0.1, gfx.mat("suelo_seco", 0.95, 1.15)).name = "patio"
	var house_w := w * 0.62
	# visual/r1 F5: la casa de posta del kit (cuerpo largo de cuatro cuartos con galería de horcones y palenque, `models.casa_posta`). Su caja mide 15,2 × 9,2 m con la
	# galería y el palenque: estirarla a 6 m de fondo la aplastaba a dos tercios (CASAS_F5, riesgo 1). Va sin deformar, a la escala que le da el largo de la huella
	# (entre 0,9 y 1,15), con el fondo contra el muro norte del patio. Si falta, la casa grande de antes con model_fit; si falta también, la procedural.
	var posta_key := "casa_posta" if not gfx.model("casa_posta").is_empty() else "casa_adobe_grande"
	var house_d := 6.0
	var k_posta := 1.0
	if posta_key == "casa_posta":
		var pbox: AABB = gfx.model(posta_key).aabb
		k_posta = clampf(house_w / maxf(pbox.size.x, 0.01), 0.9, 1.15)
		house_d = pbox.size.z * k_posta
	mb.push()
	mb.move(Vector3(-w * 0.5 + house_w * 0.5 + 1.8, 0.0, -d * 0.5 + (0.6 + house_d * 0.5 if posta_key == "casa_posta" else 3.4)))
	if gfx.model(posta_key).is_empty():
		gen.add_house(mb, house_w, 4.6, 3.0, 1, 1.0, 0.2)
	else:  # la casa de posta con su galería (o la ramada del modelo de P6), con el frente hacia el patio (+Z)
		var house := MeshInstance3D.new()
		house.name = "casa_de_posta"
		house.mesh = gfx.model(posta_key).mesh
		var fit: Transform3D = gfx.model_fit(posta_key, house_w, 6.0)
		if posta_key == "casa_posta":
			var box: AABB = gfx.model(posta_key).aabb
			fit = Transform3D(Basis.from_scale(Vector3.ONE * k_posta), Vector3.ZERO) * Transform3D(Basis.IDENTITY, Vector3(-box.get_center().x, -box.position.y, -box.get_center().z))
		house.transform = mb.xf * Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO) * fit
		node.add_child(house)
		var door: Variant = door_of(posta_key)
		if door is Vector3:  # visual/r1 F5: una puerta de la posta con lumbre, hacia el patio
			var glow := MeshInstance3D.new()
			glow.name = "puerta_con_lumbre"
			var gm := BoxMesh.new()
			gm.size = Vector3(0.84, 1.7, 0.1)
			glow.mesh = gm
			glow.material_override = gfx.night_glow_mat()
			glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			glow.transform = house.transform * Transform3D(Basis.IDENTITY, (door as Vector3) + Vector3(0.0, 0.0, -0.05))
			node.add_child(glow)
	mb.pop()
	mb.push()
	mb.move(Vector3(w * 0.5 - 7.0, 0.0, d * 0.5 - 6.5))
	mb.turn_y(20.0)
	gen.add_cart(mb, true)
	mb.pop()
	mb.push()
	mb.move(Vector3(-2.0, 0.0, d * 0.5 - 4.0))
	mb.turn_y(-35.0)
	gen.add_cart(mb, false)
	mb.pop()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1817
	var kinds := ["barril", "cajon", "saco", "bulto"]
	for k in range(14):  # las cargas apiladas junto al muro este y al sur de la casa
		var kind: String = kinds[k % 4]
		var mesh: ArrayMesh = gen.prop(kind, k)
		var at := Vector3(w * 0.5 - 2.6 + rng.randf() * 1.5, 0.0, -d * 0.5 + 5.5 + float(k) * 0.9 + rng.randf() * 0.4)
		if at.z > d * 0.5 - 4.0:
			at = Vector3(-w * 0.5 + 3.0 + rng.randf() * 4.0, 0.0, d * 0.5 - 3.0 - rng.randf() * 2.0)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = gfx.props_mat
		mi.position = at
		mi.rotation.y = rng.randf() * TAU
		node.add_child(mi)
	_mesh_node(node, "posta", mb.build())


# ---------------------------------------------------------------------------------------------------------------------
# Rasgos del nivel: tapias, barricadas, zanjas, acequias, caminos y calles (salen de terrain.features)

## Un muro entre `a` y `b` en tramos de ≤ 8 m que siguen el relieve: dos caras, el remate de paja y, si se pide, las cabeceras.
func _wall_run(mb, a: Vector2, b: Vector2, height: float, thick: float, color: Color, cap: Color, cap_h: float, ends: bool) -> void:
	var parts := maxi(1, int(ceil(a.distance_to(b) / 8.0)))
	var dir := (b - a).normalized()
	var n := Vector2(-dir.y, dir.x) * thick * 0.5
	for k in range(parts):
		var p0 := a.lerp(b, float(k) / float(parts))
		var p1 := a.lerp(b, float(k + 1) / float(parts))
		var y0: float = gfx.h(p0.x, p0.y)
		var y1: float = gfx.h(p1.x, p1.y)
		var low := color.darkened(0.2)
		var base0 := y0 - 0.35
		var base1 := y1 - 0.35
		var top0 := y0 + height
		var top1 := y1 + height
		var q00 := Vector3(p0.x + n.x, base0, p0.y + n.y)
		var q01 := Vector3(p1.x + n.x, base1, p1.y + n.y)
		var r00 := Vector3(p0.x - n.x, base0, p0.y - n.y)
		var r01 := Vector3(p1.x - n.x, base1, p1.y - n.y)
		mb.quad_g(q01, q00, q00 + Vector3(0.0, top0 - base0, 0.0), q01 + Vector3(0.0, top1 - base1, 0.0), low, color)
		mb.quad_g(r00, r01, r01 + Vector3(0.0, top1 - base1, 0.0), r00 + Vector3(0.0, top0 - base0, 0.0), low, color)
		var cn := Vector2(-dir.y, dir.x) * (thick * 0.5 + 0.1)
		var t0a := Vector3(p0.x + cn.x, top0, p0.y + cn.y)
		var t0b := Vector3(p0.x - cn.x, top0, p0.y - cn.y)
		var t1a := Vector3(p1.x + cn.x, top1, p1.y + cn.y)
		var t1b := Vector3(p1.x - cn.x, top1, p1.y - cn.y)
		mb.quad(t0b, t1b, t1a, t0a, cap)  # remate de paja
		mb.quad_g(t1a, t0a, t0a + Vector3(0.0, cap_h, 0.0), t1a + Vector3(0.0, cap_h, 0.0), cap.darkened(0.2), cap)
		mb.quad_g(t0b, t1b, t1b + Vector3(0.0, cap_h, 0.0), t0b + Vector3(0.0, cap_h, 0.0), cap.darkened(0.2), cap)
		mb.quad(t0a + Vector3(0.0, cap_h, 0.0), t1a + Vector3(0.0, cap_h, 0.0), t1b + Vector3(0.0, cap_h, 0.0), t0b + Vector3(0.0, cap_h, 0.0), cap.lightened(0.05))
		if ends and k == 0:
			mb.quad_g(q00, r00, r00 + Vector3(0.0, top0 - base0, 0.0), q00 + Vector3(0.0, top0 - base0, 0.0), low, color)
		if ends and k == parts - 1:
			mb.quad_g(r01, q01, q01 + Vector3(0.0, top1 - base1, 0.0), r01 + Vector3(0.0, top1 - base1, 0.0), low, color)


func build_features(root: Node3D) -> void:
	if _terrain == null or not _terrain.has_method("features"):
		return
	var props: Dictionary = gfx.data.get("props", {})
	var tapia: Dictionary = props.get("tapia", {})
	var wall = gen.builder()
	var wall_color: Color = gfx.pc(str(tapia.get("color", "adobe")))
	var cap_color: Color = gfx.pc(str(tapia.get("cap_color", "paja")))
	var cap_h := float(tapia.get("cap_m", 0.2))
	var walls := 0
	var modules: Array = []  # con el modelo «tapia» (módulo de 4 m de la pista P6): un módulo estirado por cada tramo de ≈ 4 m, siguiendo el suelo
	var use_module: bool = not gfx.model("tapia").is_empty()
	for f in _terrain.call("features", "tapia"):
		if f is Dictionary:
			var line: PackedVector2Array = gfx.pts(f.get("pts", []))
			for k in range(line.size() - 1):
				if use_module:
					var seg := line[k + 1] - line[k]
					var n := maxi(1, roundi(seg.length() / 4.0))
					var dir := seg / maxf(seg.length(), 0.001)
					for i in range(n):
						var c := line[k] + seg * ((float(i) + 0.5) / float(n))
						modules.append(Transform3D(Basis(Vector3.UP, -atan2(dir.y, dir.x)), Vector3(c.x, gfx.h(c.x, c.y), c.y))
							* gfx.model_fit("tapia", seg.length() / float(n), float(f.get("thickness_m", 0.5)), float(f.get("height_m", 2.0))))
				else:
					_wall_run(wall, line[k], line[k + 1], float(f.get("height_m", 2.0)), float(f.get("thickness_m", 0.5)), wall_color, cap_color, cap_h, k == 0 or k == line.size() - 2)
				walls += 1
	if not modules.is_empty():
		_multimesh(root, "tapias_modelo", gfx.model("tapia").mesh, modules, true, true)
	for f in _terrain.call("features", "barricada"):
		if f is Dictionary:
			var line: PackedVector2Array = gfx.pts(f.get("pts", []))
			for k in range(line.size() - 1):
				_wall_run(wall, line[k], line[k + 1], 1.4, 0.9, gfx.pc("madera_oscura"), gfx.pc("madera_oscura", 1.2), 0.12, true)
				walls += 1
	var cubierto: Variant = _terrain.call("features", "camino_cubierto")
	if cubierto is Array:
		for f in cubierto:
			if f is Dictionary:
				var line: PackedVector2Array = gfx.pts(f.get("pts", []))
				var half := float(f.get("width_m", 6.0)) * 0.5
				for k in range(line.size() - 1):
					var dir := (line[k + 1] - line[k]).normalized()
					var off := Vector2(-dir.y, dir.x) * half
					_wall_run(wall, line[k] + off, line[k + 1] + off, float(f.get("wall_height_m", 1.8)), 0.5, wall_color, cap_color, cap_h, true)
					_wall_run(wall, line[k] - off, line[k + 1] - off, float(f.get("wall_height_m", 1.8)), 0.5, wall_color, cap_color, cap_h, true)
					walls += 2
	content_counts["tapias"] = walls
	if walls > 0:
		_mesh_node(root, "tapias", wall.build())
	_build_gaps(root)
	var spec_z: Dictionary = props.get("zanja", {})
	var ditches := 0
	for kind in ["zanja", "acequia"]:
		for f in _terrain.call("features", kind):
			if not (f is Dictionary):
				continue
			var line: PackedVector2Array = gfx.pts(f.get("pts", []))
			var width := maxf(float(f.get("width_m", 1.6)), 1.0)
			gfx.strip(root, line, width + 1.8, float(spec_z.get("raise_m", 0.08)) - 0.02, gfx.mat("suelo_seco", 0.95, 1.12), false, false, "zanja_borde_%d" % ditches, 4.0, true)  # cintas del suelo: tramos de 4 m y sobre la malla dibujada
			gfx.strip(root, line, width, float(spec_z.get("raise_m", 0.08)) + 0.04, gfx.mat(str(spec_z.get("color", "sedimento_humedo")), 0.8, 0.62), false, false, "zanja_%d" % ditches, 4.0, true)
			ditches += 1
	content_counts["zanjas"] = ditches
	var roads := 0
	var spec_c: Dictionary = props.get("camino", {})
	for kind in ["camino", "calle"]:
		for f in _terrain.call("features", kind):
			if f is Dictionary:
				var line: PackedVector2Array = gfx.pts(f.get("pts", []))
				gfx.strip(root, line, maxf(float(f.get("width_m", 5.0)), 2.0), float(spec_c.get("raise_m", 0.09)), gfx.mat(str(spec_c.get("color", "suelo_seco")), 0.95, float(spec_c.get("gain", 1.12))), false, false, "camino_%d" % roads, 4.0, true)
				roads += 1
	content_counts["caminos"] = roads
	build_parcels(root)


## T-007 (mitad de la vista): los huecos entre dos tapias (extremos de tapias distintas a 2,5 a 10 m) se dibujan según lo que dice la navegación en su centro, así que
## lo que se ve abierto es lo que se puede atravesar. Un hueco transitable lleva sus dos jambas de adobe con umbral oscuro; uno que el terreno da por cerrado, una
## tranquera de palos cruzada (aspecto de diseño): antes los dos huecos de 4 m de la posta se veían abiertos y eran muro para las rutas. La otra mitad (que esos huecos
## sean transitables) es de la rasterización de las tapias en el terreno y la coordina la pista de reglas.
func _build_gaps(root: Node3D) -> void:
	var ends: Array = []  # [punto, id de la tapia, altura]
	for f in _terrain.call("features", "tapia"):
		if f is Dictionary:
			var line: PackedVector2Array = gfx.pts(f.get("pts", []))
			if line.size() >= 2:
				ends.append([line[0], str(f.get("id", "")), float(f.get("height_m", 2.0))])
				ends.append([line[line.size() - 1], str(f.get("id", "")), float(f.get("height_m", 2.0))])
	var mb = gen.builder()
	var wood: Color = gfx.pc("madera_oscura")
	var adobe: Color = gfx.pc("adobe", 0.95)
	var open_n := 0
	var closed_n := 0
	var seen := {}
	for a in range(ends.size()):
		for b in range(a + 1, ends.size()):
			if str(ends[a][1]) == str(ends[b][1]):
				continue
			var pa: Vector2 = ends[a][0]
			var pb: Vector2 = ends[b][0]
			var gap := pa.distance_to(pb)
			if gap < 2.5 or gap > 10.0:
				continue
			var key := "%d,%d" % [roundi((pa.x + pb.x) * 2.0), roundi((pa.y + pb.y) * 2.0)]
			if seen.has(key):
				continue
			seen[key] = true
			var mid := (pa + pb) * 0.5
			var h := minf(float(ends[a][2]), float(ends[b][2]))
			var dir := (pb - pa) / gap
			var yaw := atan2(dir.y, dir.x)
			var blocked := bool(_terrain.call("is_blocked", mid.x, mid.y))
			mb.push()
			mb.xf = Transform3D(Basis(Vector3.UP, -yaw), Vector3(mid.x, gfx.h(mid.x, mid.y), mid.y))
			for s in [-1.0, 1.0]:  # jambas: dos pilares de adobe un poco más altos que la tapia
				mb.box(Vector3(s * (gap * 0.5 - 0.15), (h + 0.35) * 0.5, 0.0), Vector3(0.6, h + 0.35, 0.7), adobe, adobe.darkened(0.3))
			if blocked:
				for y in [0.45, 0.95, 1.45]:  # tranquera cerrada: tres palos de lado a lado
					mb.box(Vector3(0.0, y, 0.0), Vector3(gap - 0.5, 0.12, 0.12), wood, wood.darkened(0.25))
				mb.beam(Vector3(-gap * 0.5 + 0.3, 0.3, 0.05), Vector3(gap * 0.5 - 0.3, 1.5, 0.05), 0.07, wood.darkened(0.1))
				closed_n += 1
			else:
				mb.box(Vector3(0.0, 0.03, 0.0), Vector3(gap - 0.6, 0.06, 0.9), gfx.pc("sedimento_humedo", 0.8))  # umbral de tierra pisada
				open_n += 1
			mb.pop()
	content_counts["puertas_abiertas"] = open_n
	content_counts["puertas_cerradas"] = closed_n
	if open_n + closed_n > 0:
		_mesh_node(root, "puertas", mb.build())


# ---------------------------------------------------------------------------------------------------------------------
# Núcleo de casas sobre las manzanas del diseño de nivel (planta ▲: diseño, no hay plano de 1817)

func _in_landmark(p: Vector2, margin: float) -> bool:
	for lm in landmarks:
		var type_name := str(lm.get("type", ""))
		if not (type_name in ["objetivo", "edificio", "torre", "hito"]):
			continue
		var fp := footprint(lm)
		var corners := footprint_corners(fp)
		var lo := corners[0]
		var hi := corners[0]
		for c in corners:
			lo = Vector2(minf(lo.x, c.x), minf(lo.y, c.y))
			hi = Vector2(maxf(hi.x, c.x), maxf(hi.y, c.y))
		if p.x > lo.x - margin and p.x < hi.x + margin and p.y > lo.y - margin and p.y < hi.y + margin:
			return true
	return false


func _signed_area(poly: PackedVector2Array) -> float:
	var s := 0.0
	for k in range(poly.size()):
		var a := poly[k]
		var b := poly[(k + 1) % poly.size()]
		s += a.x * b.y - b.x * a.y
	return s * 0.5


func build_nucleo(root: Node3D) -> void:
	if _terrain == null or not _terrain.has_method("features"):
		return
	var blocks: Variant = _terrain.call("features", "manzana")
	if not (blocks is Array):
		return
	var mb = gen.builder()
	var count := 0
	var max_houses := int(gfx.qcfg.get("houses_max", 120))
	for block in blocks:
		if not (block is Dictionary):
			continue
		var poly: PackedVector2Array = gfx.pts(block.get("poly", []))
		if poly.size() < 3:
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(str(block.get("id", "manzana"))) & 0x7fffffff
		var orient := 1.0 if _signed_area(poly) > 0.0 else -1.0
		for e in range(poly.size()):
			var a := poly[e]
			var b := poly[(e + 1) % poly.size()]
			var length := a.distance_to(b)
			if length < 10.0:
				continue
			var dir := (b - a) / length
			var inward := Vector2(-dir.y, dir.x) * orient * -1.0
			var t := 1.2 + rng.randf() * 1.6
			while t < length - 7.0 and count < max_houses:
				var hw := rng.randf_range(6.5, 12.5)
				var hd := rng.randf_range(5.0, 8.5)
				var hh := rng.randf_range(2.7, 3.6)
				if t + hw > length - 1.0:
					break
				if rng.randf() < 0.14:  # un zaguán o un patio sin casa
					t += rng.randf_range(4.0, 7.0)
					continue
				var center := a + dir * (t + hw * 0.5) + inward * (hd * 0.5 + 1.3)
				t += hw + rng.randf_range(0.2, 1.1)
				if _in_landmark(center, 4.0):
					continue
				var yaw := atan2(inward.x, inward.y)
				mb.push()
				mb.xf = Transform3D(Basis(Vector3.UP, yaw), Vector3(center.x, gfx.h(center.x, center.y), center.y))
				_add_house(mb, hw, hd, hh, rng.randi() % 3, -1.0, rng.randf())
				mb.pop()
				count += 1
		count = _inner_fill(mb, poly, rng, count, max_houses)
	house_count = count
	content_counts["casas"] = count
	if count > 0:
		_mesh_node(root, "casas_del_nucleo", mb.build())
	if not _lit.is_empty():  # puertas y ventanas con lumbre: puntos cálidos que dicen «pueblo habitado» de noche (se apagan con el día, ver fx.set_fire)
		var glow := BoxMesh.new()
		glow.size = Vector3(2.0, 2.0, 0.1)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = glow
		mm.instance_count = _lit.size()
		for i in range(_lit.size()):
			mm.set_instance_transform(i, _lit[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "lumbre_de_las_casas"
		mmi.multimesh = mm
		mmi.material_override = gfx.night_glow_mat()
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi)
		content_counts["casas_con_lumbre"] = _lit.size()
	_lit = []
	for key in _model_xf:  # las casas que vienen de un modelo GLB (pista P6): una MultiMesh por modelo
		_multimesh(root, "casas_modelo_" + str(key), gfx.model(str(key)).mesh, _model_xf[key], true, true)
		content_counts["casas_de_modelo_" + str(key)] = (_model_xf[key] as Array).size()
	_model_xf = {}


## Una casa del núcleo en `mb.xf`: con el modelo GLB de `models.casa_adobe` (o `casa_adobe_grande` si mide 9,5 m o más de frente) si existe; si no, el generador
## procedural (el respaldo de siempre). El modelo mira a −Z, igual que la puerta de la casa procedural, y se lo estira a la huella conservando su proporción de alto.
## visual/r1 F5: con el kit de edificios del territorio cada lote elige entre varias casas (`models.nucleo`: torta, rancho de torta, galería de horcones, dos cuerpos,
## patio) y se ajusta con house_fit (sin aplastar la galería ni el patio). Tipos razonados (PVR: adobe, torta, patios), medidas y detalles de diseño (CASAS_F5.md).
func _add_house(mb, w: float, d: float, h: float, style: int, door_z: float, tone: float) -> void:
	var o: Vector3 = mb.xf.origin
	var lit := posmod(int(o.x * 7.0 + o.z * 13.0), 20) < 9 and w >= 4.0  # casi la mitad de las casas tiene lumbre en la puerta (aspecto de diseño, sin datos)
	var key := _house_variant(w, d, o)  # visual/r1 F5: la variante del kit que menos se deforma en este lote
	if key == "":  # sin modelos: la casa procedural de siempre (el respaldo), con su puerta y su ventanita
		if lit:
			_lit.append(mb.xf * Transform3D(Basis.IDENTITY, Vector3(w * 0.18, 1.0, signf(door_z) * (d * 0.5 + 0.12))))
			if w >= 6.0:  # y una ventanita con lumbre al otro lado de la puerta
				_lit.append(mb.xf * Transform3D(Basis.from_scale(Vector3(0.4, 0.36, 1.0)), Vector3(-w * 0.26, 1.55, signf(door_z) * (d * 0.5 + 0.12))))
		gen.add_house(mb, w, d, h, style, door_z, tone)
		return
	var flip := Basis(Vector3.UP, PI) if door_z > 0.0 else Basis.IDENTITY  # la puerta procedural de door_z > 0 mira a +Z
	if not _model_xf.has(key):
		_model_xf[key] = []
	var xf: Transform3D = mb.xf * Transform3D(flip, Vector3.ZERO) * house_fit(key, w, d, door_z < 0.0)
	(_model_xf[key] as Array).append(xf)
	if lit:  # visual/r1 F5: la lumbre va en la puerta real del modelo (manifiesto de casas), no en la de la casa procedural
		var door: Variant = door_of(key)
		if door is Vector3:
			_lit.append(xf * Transform3D(Basis.from_scale(Vector3(0.42, 0.85, 1.0)), (door as Vector3) + Vector3(0.0, 0.0, -0.05)))


## visual/r1 F5: `models.nucleo` de humahuaca_visual.json (variantes del núcleo, estirón máximo y puertas con lumbre).
func _nucleo_cfg() -> Dictionary:
	var models: Variant = gfx.data.get("models", {})
	var cfg: Variant = (models as Dictionary).get("nucleo", {}) if models is Dictionary else {}
	return cfg if cfg is Dictionary else {}


## visual/r1 F5: la puerta (centro, en coordenadas del modelo sin escalar) del modelo `key` según `models.nucleo.puertas`, o null.
func door_of(key: String) -> Variant:
	var doors: Variant = _nucleo_cfg().get("puertas", {})
	var door: Variant = (doors as Dictionary).get(key, null) if doors is Dictionary else null
	if door is Array and (door as Array).size() == 3:
		return Vector3(float(door[0]), float(door[1]), float(door[2]))
	return null


## visual/r1 F5: la clave del modelo de una casa del núcleo de `w` × `d` m en `o`: entre las variantes del kit que existen (`models.nucleo.chicas`, o `grandes` desde
## `corte_m` de frente, como antes casa_adobe y casa_adobe_grande), las que menos se deforman en el lote (dentro de `holgura` de la mejor) y, entre ellas, una por la
## posición (regla fija: el pueblo sale siempre igual). "" si no hay ningún modelo (vuelve la casa procedural).
func _house_variant(w: float, d: float, o: Vector3) -> String:
	var cfg := _nucleo_cfg()
	var group := "grandes" if w >= float(cfg.get("corte_m", 9.5)) else "chicas"
	var keys: Array = cfg.get(group, []) if cfg.get(group, null) is Array else []
	if keys.is_empty():
		keys = ["casa_adobe_grande", "casa_adobe"] if group == "grandes" else ["casa_adobe"]
	var scored: Array = []
	var best := INF
	for k in keys:
		var m: Dictionary = gfx.model(str(k))
		if m.is_empty():
			continue
		var box: AABB = m.aabb
		var kx := w / maxf(box.size.x, 0.01)
		var kz := d / maxf(box.size.z, 0.01)
		var s := absf(log(kx)) + absf(log(kz)) + 0.6 * absf(log(kx / kz))  # cuánto hay que estirarla (o achicarla) y cuánto se deformaría
		scored.append([str(k), s])
		best = minf(best, s)
	var near: Array = []
	for entry in scored:
		if float(entry[1]) <= best + float(cfg.get("holgura", 0.35)):
			near.append(entry[0])
	if near.is_empty():
		return "casa_adobe" if not gfx.model("casa_adobe").is_empty() else ""
	return str(near[posmod(int(o.x * 3.0) * 31 + int(o.z * 3.0) * 17, near.size())])


## visual/r1 F5: la transformación que lleva la casa `key` a un lote de `w` × `d` m sin girarla (el frente sigue a −Z) y, a diferencia de model_fit, sin deformarla de más:
## la caja del kit incluye galerías, aleros, cántaros y tapias de patio (CASAS_F5, riesgo 1) y estirarla a la huella dejaba el cuerpo aplastado o angosto. Ningún sentido
## se estira más de `max_estiron` veces el otro (el que sobra queda más corto que el lote, nunca más largo: no pisa a la vecina) y el alto va entre `alto_min` y `alto_max`
## de su tamaño real. Con `front` el frente del modelo se apoya en el frente del lote (sobre la calle) en vez de quedar centrado.
func house_fit(key: String, w: float, d: float, front: bool) -> Transform3D:
	var m: Dictionary = gfx.model(key)
	if m.is_empty():
		return Transform3D.IDENTITY
	var cfg := _nucleo_cfg()
	var box: AABB = m.aabb
	var kx := w / maxf(box.size.x, 0.01)
	var kz := d / maxf(box.size.z, 0.01)
	var lim := maxf(float(cfg.get("max_estiron", 1.2)), 1.0)
	var kmin := minf(kx, kz)
	kx = minf(kx, kmin * lim)
	kz = minf(kz, kmin * lim)
	var ky := clampf((kx + kz) * 0.5, float(cfg.get("alto_min", 0.85)), float(cfg.get("alto_max", 1.2)))
	var shift_z := -(d - box.size.z * kz) * 0.5 if front else 0.0
	var center := box.get_center()
	var pre := Transform3D(Basis.IDENTITY, Vector3(-center.x, -box.position.y, -center.z))  # centrado y apoyado en el suelo
	return Transform3D(Basis.from_scale(Vector3(kx, ky, kz)), Vector3(0.0, 0.0, shift_z)) * pre



## La distancia de un punto al borde de un polígono.
func _edge_distance(q: Vector2, poly: PackedVector2Array) -> float:
	var best := 1.0e9
	for k in range(poly.size()):
		best = minf(best, Geometry2D.get_closest_point_to_segment(q, poly[k], poly[(k + 1) % poly.size()]).distance_to(q))
	return best


## El interior de una manzana: galpones y corrales chicos de adobe y un árbol de patio acá y allá, sobre una grilla de 9 m (el diseño de nivel solo da el borde de la manzana).
func _inner_fill(mb, poly: PackedVector2Array, rng: RandomNumberGenerator, count: int, max_houses: int) -> int:
	var lo := poly[0]
	var hi := poly[0]
	for q in poly:
		lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
		hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
	var gx := lo.x + 5.0
	while gx < hi.x:
		var gz := lo.y + 5.0
		while gz < hi.y:
			var q := Vector2(gx + rng.randf_range(-2.0, 2.0), gz + rng.randf_range(-2.0, 2.0))
			if Geometry2D.is_point_in_polygon(q, poly) and _edge_distance(q, poly) > 12.5 and count < max_houses:
				var roll := rng.randf()
				if roll < 0.4:
					mb.push()
					mb.xf = Transform3D(Basis(Vector3.UP, rng.randf_range(-0.2, 0.2)), Vector3(q.x, gfx.h(q.x, q.y), q.y))
					_add_house(mb, rng.randf_range(3.6, 6.0), rng.randf_range(3.2, 4.8), rng.randf_range(2.1, 2.7), 1 + rng.randi() % 2, 1.0, rng.randf())
					mb.pop()
					count += 1
				elif roll < 0.62:
					extra_trees.append(q)
			gz += 9.0
		gx += 9.0
	return count

# ---------------------------------------------------------------------------------------------------------------------
# Anillo de contenido: churqui, cardón, sauce y rocas repartidos según la pendiente y el río (semilla fija)

func _multimesh(parent: Node3D, name_: String, mesh: Mesh, xforms: Array, shadow: bool, own_material: bool = false) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = own_material  # los GLB usan el color por vértice: el color de instancia lo multiplica (un tono por casa)
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in range(xforms.size()):
		mm.set_instance_transform(i, xforms[i])
		if own_material:
			var o: Vector3 = (xforms[i] as Transform3D).origin
			var k := 0.86 + 0.14 * float(posmod(int(o.x * 3.0 + o.z * 5.0), 7)) / 6.0
			mm.set_instance_color(i, Color(k, k * 0.97, k * 0.93, 1.0))
	var mi := MultiMeshInstance3D.new()
	mi.name = name_
	mi.multimesh = mm
	if not own_material:  # los GLB de la pista P6 traen sus materiales (color por vértice y emisión): no se pisan
		mi.material_override = gfx.props_mat
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	for s in range(mesh.get_surface_count()):
		triangle_count += ((mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3) * xforms.size()


func _free_spot(p: Vector2, allow_slope: bool) -> bool:
	var cls: String = gfx.surface_at(p.x, p.y)
	if cls in ["camino", "patio", "zanja", "agua", "muro"]:
		return false
	return not _in_landmark(p, 6.0)


func build_vegetation(root: Node3D, river_line: PackedVector2Array) -> void:
	var ring: Dictionary = gfx.data.get("content_ring", {})
	var rng := RandomNumberGenerator.new()
	rng.seed = int(ring.get("seed", 1817))
	var factor := float(gfx.qcfg.get("vegetation_factor", 1.0))
	var bushes: Array = []
	var cacti: Array = []
	var rocks: Array = []
	var willows: Array = []
	var win: Rect2 = gfx.win
	var reach := 260.0  # el anillo sigue unos metros fuera de la ventana: el contexto cercano no queda pelado
	var area := Rect2(win.position - Vector2(reach, reach), win.size + Vector2(reach, reach) * 2.0)
	var clear := _objective_spots()
	for k in range(int(1000.0 * factor)):  # churqui: matas bajas (ronda 3: menos y más chicas; antes 3 000 manchas oscuras que se leían como ruido), más densas en las laderas
		var p := area.position + Vector2(rng.randf() * area.size.x, rng.randf() * area.size.y)
		var slope: float = gfx.slope_at(p.x, p.y)
		if rng.randf() > 0.3 + 0.7 * gfx.churqui_k(p.x, p.y, slope) or not _free_spot(p, true) or _near_any(p, clear, 60.0):
			continue
		var s := 0.9 + rng.randf() * 0.9
		bushes.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * (0.7 + rng.randf() * 0.5), s)), Vector3(p.x, gfx.h(p.x, p.y) - 0.1, p.y)))
	for k in range(int(260.0 * factor)):  # cardones: solo en las laderas más altas del oeste
		var p := area.position + Vector2(rng.randf() * area.size.x * 0.55, rng.randf() * area.size.y)
		if gfx.slope_at(p.x, p.y) < 0.045 or rng.randf() > 0.5 or not _free_spot(p, true) or _near_any(p, clear, 45.0):
			continue
		var s := 0.8 + rng.randf() * 0.5
		cacti.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(p.x, gfx.h(p.x, p.y) - 0.1, p.y)))
	for k in range(int(550.0 * factor)):  # rocas: tendidas por el campo y juntas en las pendientes (ronda 3: la mitad, eran puntos oscuros que ensuciaban el suelo)
		var p := area.position + Vector2(rng.randf() * area.size.x, rng.randf() * area.size.y)
		var slope: float = gfx.slope_at(p.x, p.y)
		if rng.randf() > clampf(slope * 6.0 + 0.3, 0.0, 0.8) or not _free_spot(p, true):
			continue
		var s := 1.2 + rng.randf() * 1.4
		rocks.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * (0.6 + rng.randf() * 0.5), s)), Vector3(p.x, gfx.h(p.x, p.y) - 0.15, p.y)))
	# sauces: el monte ribereño, a 26 – 64 m del eje del río (la foto de 1923: línea continua de arbolado oscuro delante del lecho claro)
	# el monte ribereño tiene su propio generador y solo sortea lo que cae cerca de la ventana: así no depende de cuánto se prolongue la traza fuera del contexto, y se alterna de
	# orilla en orilla (3 de cada 4 veces) para que las dos orillas tengan su línea de arbolado
	var wrng := RandomNumberGenerator.new()
	wrng.seed = int(ring.get("seed", 1817)) + 99
	var samples := line_samples(river_line, 22.0 / maxf(factor, 0.3))
	var side := 1.0
	for k in range(samples.size()):
		var at: Vector2 = samples[k]
		if not win.grow(reach + 70.0).has_point(at):
			continue
		if wrng.randf() < 0.18:
			continue
		var nrm := Vector2(1.0, 0.0)
		if k + 1 < samples.size():
			var tan_v: Vector2 = ((samples[k + 1] as Vector2) - at).normalized()
			nrm = Vector2(-tan_v.y, tan_v.x)
		side = -side if wrng.randf() < 0.75 else side
		var p := at + nrm * side * (26.0 + wrng.randf() * 38.0)
		if win.grow(reach).has_point(p) and _free_spot(p, false):
			var s := 0.85 + wrng.randf() * 0.45
			willows.append(Transform3D(Basis(Vector3.UP, wrng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(p.x, gfx.h(p.x, p.y) - 0.1, p.y)))
	for q in extra_trees:  # sauces chicos de los patios de las manzanas
		var p2: Vector2 = q
		var s2 := 0.45 + rng.randf() * 0.3
		willows.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s2, s2, s2)), Vector3(p2.x, gfx.h(p2.x, p2.y) - 0.1, p2.y)))
	var variants := 3
	for v in range(variants):  # tres variantes de cada especie para que no se repita la silueta
		_multimesh(root, "arbustos_%d" % v, gen.bush(100 + v), bushes.filter(func(t): return int(abs(t.origin.x * 7.0 + t.origin.z * 3.0)) % variants == v), false)
		_multimesh(root, "rocas_%d" % v, gen.rock(200 + v), rocks.filter(func(t): return int(abs(t.origin.x * 5.0 + t.origin.z * 11.0)) % variants == v), false)
	var cardon: Dictionary = gfx.model("cardon")  # el cardón del proyecto (tree_cardon.glb, MultiMesh); si falta, el procedural
	if cardon.is_empty():
		_multimesh(root, "cardones", gen.cactus(300), cacti, true)
	else:
		var fixed: Array = []
		for t in cacti:
			fixed.append((t as Transform3D) * Transform3D(Basis.IDENTITY, Vector3(0.0, -(cardon.aabb as AABB).position.y, 0.0)))
		_multimesh(root, "cardones", cardon.mesh, fixed, true, true)
	# algarrobos dispersos en el llano (tree_algarrobo.glb): siluetas de copa ancha que se leen de lejos; lejos de los objetivos, los caminos y el río
	var trees: Array = []
	var algarrobo: Dictionary = gfx.model("algarrobo")
	if not algarrobo.is_empty():
		var arng := RandomNumberGenerator.new()
		arng.seed = int(ring.get("seed", 1817)) + 7
		for k in range(int(220.0 * factor)):
			var p := area.position + Vector2(arng.randf() * area.size.x, arng.randf() * area.size.y)
			if gfx.slope_at(p.x, p.y) > 0.06 or arng.randf() > 0.35 or not _free_spot(p, false) or _near_any(p, clear, 75.0):
				continue
			var s := 0.6 + arng.randf() * 0.45
			trees.append(Transform3D(Basis(Vector3.UP, arng.randf() * TAU).scaled(Vector3(s, s * (0.85 + arng.randf() * 0.3), s)), Vector3(p.x, gfx.h(p.x, p.y) - 0.1, p.y)))
		_multimesh(root, "algarrobos", algarrobo.mesh, trees, true, true)
	content_counts["algarrobos"] = trees.size()
	_multimesh(root, "sauces", gen.willow(400), willows, true)
	content_counts["arbustos"] = bushes.size()
	content_counts["cardones"] = cacti.size()
	content_counts["rocas"] = rocks.size()
	content_counts["sauces"] = willows.size()


## Los objetivos (y sus luces): ahí la vegetación se aparta para no competir con las fichas ni con el anillo de oro.
func _objective_spots() -> Array:
	var out: Array = []
	for id in ["bateria", "cuartel", "posta"]:
		if lm_by_id.has(id):
			out.append(Vector2(float(lm_by_id[id].x), float(lm_by_id[id].z)))
	return out


func _near_any(p: Vector2, spots: Array, r: float) -> bool:
	for q in spots:
		if p.distance_to(q as Vector2) < r:
			return true
	return false


func line_samples(line: PackedVector2Array, step: float) -> Array:
	var out: Array = []
	if line.size() < 2:
		return out
	var carry := 0.0
	out.append(line[0])
	for k in range(line.size() - 1):
		var a := line[k]
		var b := line[k + 1]
		var length := a.distance_to(b)
		var t := step - carry
		while t <= length:
			out.append(a.lerp(b, t / length))
			t += step
		carry = length - (t - step)
	return out


## Q-204 (QA ronda 2): las parcelas regadas (`parcela`, diseño) se dibujaban solo con el color liso del regadío en el suelo: rectángulos verde oscuro, la mancha más
## oscura del cuadro de noche, que se leían como un marcador sin terminar. Ahora cada parcela es un cultivo: tierra húmeda de fondo, camellones en hileras a lo largo
## del lado mayor, agrupados en tres tablones de cultivos distintos (maíz, alfalfa y rastrojo, con tono propio y un poco de variación por hilera), la acequia que la
## riega por la cabecera y un costado (agua entre dos bordos claros) y un bordo de tierra alrededor. Todo sale de la paleta (sin HEX) y va en UNA malla por parcela
## con el material de los objetos (colores por vértice), sobre la malla dibujada del suelo. Parámetros: humahuaca_visual.json → props.parcela.
func build_parcels(root: Node3D) -> void:
	if _terrain == null or not _terrain.has_method("features"):
		return
	var spec: Dictionary = (gfx.data.get("props", {}) as Dictionary).get("parcela", {})
	var row_w := float(spec.get("row_width_m", 1.5))
	var row_gap := float(spec.get("row_spacing_m", 3.2))
	var seg_m := float(spec.get("segment_m", 5.0))
	var raise := float(spec.get("raise_m", 0.12))
	# cada tablón: [color, ganancia, mezcla, cuánto de la mezcla, cuántos tramos faltan (0 a 1)]: maíz, alfalfa y rastrojo con matas sueltas
	var crops: Array = spec.get("crops", [["vegetacion_irrigada", 1.38, "paja", 0.2, 0.04], ["vegetacion_irrigada", 1.15, "churqui", 0.4, 0.0], ["paja", 0.95, "suelo_seco", 0.3, 0.22]])
	var count := 0
	for f in _terrain.call("features", "parcela"):
		if not (f is Dictionary):
			continue
		var poly: PackedVector2Array = gfx.pts(f.get("poly", f.get("pts", [])))
		if poly.size() < 3:
			continue
		var mb = gen.builder()
		var bb := Rect2(poly[0], Vector2.ZERO)
		for q in poly:
			bb = bb.expand(q)
		# el borde del regadío en el sombreador del suelo es irregular (± 4,5 m): la tierra de la parcela y sus bordos se dibujan 3,5 m más afuera para taparlo
		var grow := float(spec.get("grow_m", 3.5))
		var grown: Array = Geometry2D.offset_polygon(poly, grow)
		var outer: PackedVector2Array = grown[0] if not grown.is_empty() else poly
		var obb := bb.grow(grow)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(str(f.get("id", count)))
		var along_x := bb.size.x >= bb.size.y  # las hileras corren a lo largo del lado mayor
		var length := bb.size.x if along_x else bb.size.y
		var depth := bb.size.y if along_x else bb.size.x
		# fondo: tierra húmeda entre los surcos (más clara y parda que el verde liso de antes)
		var soil: Color = gfx.pc(str(spec.get("soil", "sedimento_humedo"))).lerp(gfx.pc("suelo_seco"), float(spec.get("soil_mix", 0.45)))  # tierra húmeda y removida, no una mancha negra
		_ground_patch(mb, obb, outer, seg_m, raise * 0.4, soil)
		# camellones en tres tablones
		var rows := maxi(1, int(floor((depth - 4.0) / row_gap)))
		var per_crop := maxi(1, int(ceil(float(rows) / float(maxi(crops.size(), 1)))))
		for r in range(rows):
			var crop: Array = crops[mini(r / per_crop, crops.size() - 1)]
			var tone: Color = gfx.pc(str(crop[0]), float(crop[1])).lerp(gfx.pc(str(crop[2])), float(crop[3]))
			tone = tone.darkened(rng.randf() * 0.08) if rng.randf() < 0.5 else tone.lightened(rng.randf() * 0.06)
			var off := 2.0 + row_gap * (float(r) + 0.5)
			var a := (Vector2(bb.position.x + 1.5, bb.position.y + off) if along_x else Vector2(bb.position.x + off, bb.position.y + 1.5))
			var b := (Vector2(bb.end.x - 1.5, bb.position.y + off) if along_x else Vector2(bb.position.x + off, bb.end.y - 1.5))
			_ribbon(mb, a, b, row_w, seg_m, raise, tone, poly, rng, float(crop[4]) if crop.size() > 4 else 0.0)
		# la acequia por la cabecera (oeste o norte) y el costado norte (u oeste), con sus bordos; un bordo de tierra por los otros dos lados
		var water: Color = gfx.pc(str(spec.get("water", "agua_turbia")), float(spec.get("water_gain", 1.12)))
		var bank: Color = gfx.pc(str(spec.get("bank", "suelo_seco")), float(spec.get("bank_gain", 0.95)))
		var c00 := obb.position
		var c10 := Vector2(obb.end.x, obb.position.y)
		var c01 := Vector2(obb.position.x, obb.end.y)
		var c11 := obb.end
		for side in [[c00, c10], [c00, c01]]:
			_ribbon(mb, side[0], side[1], 2.4, seg_m, raise * 0.6, bank, PackedVector2Array())
			_ribbon(mb, side[0], side[1], 1.0, seg_m, raise * 0.9, water, PackedVector2Array())
		for side in [[c10, c11], [c01, c11]]:
			_ribbon(mb, side[0], side[1], 1.2, seg_m, raise * 0.8, bank.darkened(0.12), PackedVector2Array())
		var mi := _mesh_node(root, "parcela_%s" % str(f.get("id", count)), mb.build(), false)
		mi.set_meta("parcela", true)
		count += 1
	content_counts["parcelas"] = count


## Una cinta recta de `a` a `b` (ancho `width`) en tramos de `seg_m` sobre la malla dibujada del suelo, más `raise`. Si `inside` trae un polígono, solo los tramos con
## el centro adentro.
func _ribbon(mb, a: Vector2, b: Vector2, width: float, seg_m: float, raise: float, col: Color, inside: PackedVector2Array, rng: RandomNumberGenerator = null, skip: float = 0.0) -> void:
	var dir := (b - a)
	var n := maxi(1, int(ceil(dir.length() / maxf(seg_m, 0.5))))
	var side := Vector2(-dir.y, dir.x).normalized() * width * 0.5
	for k in range(n):
		var p0 := a.lerp(b, float(k) / float(n))
		var p1 := a.lerp(b, float(k + 1) / float(n))
		if not inside.is_empty() and not Geometry2D.is_point_in_polygon((p0 + p1) * 0.5, inside):
			continue
		var c := col
		if rng != null:
			if skip > 0.0 and rng.randf() < skip:
				continue  # el rastrojo tiene claros
			c = col.darkened(rng.randf() * 0.1) if rng.randf() < 0.5 else col.lightened(rng.randf() * 0.07)  # cada tramo con su tono: no es una franja impresa
		var q0 := p0 + side
		var q1 := p1 + side
		var q2 := p1 - side
		var q3 := p0 - side
		var v0 := Vector3(q0.x, gfx.rendered_h(q0.x, q0.y) + raise, q0.y)
		var v1 := Vector3(q1.x, gfx.rendered_h(q1.x, q1.y) + raise, q1.y)
		var v2 := Vector3(q2.x, gfx.rendered_h(q2.x, q2.y) + raise, q2.y)
		var v3 := Vector3(q3.x, gfx.rendered_h(q3.x, q3.y) + raise, q3.y)
		_up_quad(mb, v0, v1, v2, v3, c)


## Un cuadrilátero con la cara hacia arriba sea cual sea el orden en que llegan los vértices.
func _up_quad(mb, v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3, col: Color) -> void:
	var up := (v1 - v0).cross(v2 - v0).y
	if up > 0.0:
		mb.quad(v0, v1, v2, v3, col)
	else:
		mb.quad(v0, v3, v2, v1, col)


## El fondo de la parcela: una grilla de `seg_m` sobre el suelo dibujado, solo las celdas con el centro dentro del polígono.
func _ground_patch(mb, bb: Rect2, poly: PackedVector2Array, seg_m: float, raise: float, col: Color) -> void:
	var nx := maxi(1, int(ceil(bb.size.x / seg_m)))
	var nz := maxi(1, int(ceil(bb.size.y / seg_m)))
	for i in range(nx):
		for j in range(nz):
			var x0 := bb.position.x + bb.size.x * float(i) / float(nx)
			var x1 := bb.position.x + bb.size.x * float(i + 1) / float(nx)
			var z0 := bb.position.y + bb.size.y * float(j) / float(nz)
			var z1 := bb.position.y + bb.size.y * float(j + 1) / float(nz)
			if not Geometry2D.is_point_in_polygon(Vector2((x0 + x1) * 0.5, (z0 + z1) * 0.5), poly):
				continue
			_up_quad(mb, Vector3(x0, gfx.rendered_h(x0, z0) + raise, z0), Vector3(x1, gfx.rendered_h(x1, z0) + raise, z0),
				Vector3(x1, gfx.rendered_h(x1, z1) + raise, z1), Vector3(x0, gfx.rendered_h(x0, z1) + raise, z1), col)
