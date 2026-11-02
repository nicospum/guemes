extends RefCounted
## Fichas, defensores y botín de la vista del nivel «humahuaca» (pista visual). Cada agrupación tiene SU silueta (no un disco ni un retinte del mismo cuerpo):
##   rodriguez = jinete de poncho y sombrero de ala ancha sobre su caballo · portal = infante de camisa y gorra con fusil · arias = infante con el banderín de mando
##   (marcador de interfaz, nunca una bandera) · reconocedores = dos figuras agachadas con poncho · arreo = mula con aparejo y bultos.
## Las figuras salen del generador procedural (humahuaca_gen.gd, ADDENDA A-01), con contorno oscuro (`negro_textil`) y sin uniformar: la ropa de cada una es una
## variante de las de `humahuaca_visual.json: units`. Las fichas son de TAMAÑO FIJO EN PANTALLA (≥ 48 px de alto a cualquier zoom: se las estira hasta ese alto).
## El bando lo dan el anillo del suelo y el contorno, no el color de la ropa.

const V = preload("res://scripts/humahuaca/humahuaca_vocab.gd")
const Gen = preload("res://scripts/humahuaca/view/humahuaca_gen.gd")

const MAX_THINGS := 48
const MAX_STRETCH := 4.6
const LOOT_COLOR := {"polvora": "madera_oscura", "canones": "hierro", "fusiles": "madera_oscura", "viveres": "lana_natural", "plata": "oro_laton"}
const ENEMY_ARCHETYPE := {"centinela": "realista_1817", "guardia": "realista_1817", "artillero": "artillero", "fusilero": "realista_1817", "mensajero": "poncho_sombrero", "refuerzo": "realista_1817"}

var gfx
var gen
var tokens: Dictionary = {}
var unit_nodes: Dictionary = {}
var unit_labels: Dictionary = {}
var scaled: Array = []  ## [{node, cat, base, px, min}]: lo que crece hasta ocupar `px` píxeles de pantalla (fichas aparte)
var part_counts: Dictionary = {}  ## partes y triángulos de cada ficha (informe de QA)

var _enemy_meshes: Dictionary = {}
var _loot_meshes: Dictionary = {}


func setup(gfx_ref) -> void:
	gfx = gfx_ref
	gen = Gen.new(gfx.palette)


func hull_w() -> float:
	return 0.022 if bool(gfx.qcfg.get("outlines", true)) else 0.0


# ---------------------------------------------------------------------------------------------------------------------
# Fichas

func build_tokens(root_tokens: Node3D, root_labels: Node3D) -> void:
	var cfg: Dictionary = gfx.data.get("tokens", {})
	var variants: Array = (gfx.data.get("units", {}) as Dictionary).get("variants", [])
	for index in range(V.GROUPS.size()):
		var id: String = V.GROUPS[index]
		var spec: Dictionary = cfg.get(id, {})
		var root := Node3D.new()
		root.name = "ficha_" + id
		root.visible = false
		root_tokens.add_child(root)
		var dims := _token_parts(root, str(spec.get("shape", "infante_fusil")), spec, variants, index)
		var base_h: float = dims.x
		var ring_color := str(spec.get("ring_color", "celeste_produccion"))
		var ring_r: float = clampf(dims.y, 0.3 * base_h, 0.62 * base_h)  # el anillo del bando no pasa de la mitad del alto de la ficha: así no domina la pantalla una figura ancha y baja
		var ring: MeshInstance3D = gfx.flat_ring(root, ring_r, 0.55, ring_color)
		ring.name = "anillo"
		gfx.flat_ring(root, ring_r + 0.45, 0.22, str(spec.get("ring_border_color", "blanco_textil"))).name = "borde"
		var selection: MeshInstance3D = gfx.flat_ring(root, ring_r + 1.1, 0.4, "oro_laton")
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
		label.modulate = gfx.pc("blanco_textil")
		label.outline_modulate = gfx.pc("negro_textil")
		label.outline_size = 10
		label.visible = false
		root_labels.add_child(label)
		unit_labels[id] = label
		tokens[id] = {"root": root, "base_h": base_h, "px": float(spec.get("min_px", 60)), "ring": ring, "ring_color": ring_color, "selection": selection}


func _variant_of(spec: Dictionary, variants: Array, index: int, fallback_shirt: String) -> Dictionary:
	var base: Dictionary = gen.variant_for(index, variants).duplicate()
	base["camisa"] = fallback_shirt if fallback_shirt != "" else base.get("camisa", "lino_crudo")
	if str(spec.get("accent_color", "")) != "":
		base["sombrero"] = str(spec.accent_color)
	return base


## Arma las partes de la silueta `shape` bajo `root` (un nodo de malla por parte) y devuelve (alto nominal, radio del anillo) en metros.
func _token_parts(root: Node3D, shape: String, spec: Dictionary, variants: Array, index: int) -> Vector2:
	var parts: Dictionary = {}
	var body := str(spec.get("body_color", "lana_parda"))
	var hw := hull_w() * 1.4
	var vmat: Material = gfx.vertex_mat()
	match shape:
		"jinete":
			var v := {"camisa": "lino_crudo", "abrigo": body, "sombrero": "madera_oscura", "acento": ""}
			parts = gen.rider(v, hw)
		"infante_fusil":
			parts = gen.figure("camisa_gorra", _variant_of(spec, variants, index, body if body in ["lino_crudo", "lana_natural"] else "lino_crudo"), "de_pie", hw)
		"infante_banderin":
			parts = gen.figure("camisa_gorra", _variant_of(spec, variants, index, "lana_natural"), "de_pie", hw)
			_add_pennant(root, str(spec.get("accent_color", "celeste_produccion")), vmat)
		"agachados":
			parts = _crouched_pair(body, spec, variants, index, hw)
		"mula_cargada":
			parts = gen.mule(hw)
		_:
			parts = gen.figure("poncho_sombrero", _variant_of(spec, variants, index, ""), "de_pie", hw)
	var lo := Vector3(1.0e9, 1.0e9, 1.0e9)
	var hi := Vector3(-1.0e9, -1.0e9, -1.0e9)
	var triangles := 0
	for key in parts:
		var mesh: ArrayMesh = parts[key]
		var box := mesh.get_aabb()
		lo = Vector3(minf(lo.x, box.position.x), minf(lo.y, box.position.y), minf(lo.z, box.position.z))
		hi = Vector3(maxf(hi.x, box.end.x), maxf(hi.y, box.end.y), maxf(hi.z, box.end.z))
		triangles += (mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		gfx.part_node(root, str(key), mesh, vmat)
	part_counts[str(root.name)] = {"partes": parts.size(), "triangulos": triangles}
	var radius := maxf(maxf(absf(lo.x), absf(hi.x)), maxf(absf(lo.z), absf(hi.z)))
	return Vector2(hi.y, radius + 0.35)


## El banderín de mando de Arias: un triángulo chico en el extremo de un asta, de color de marcador (celeste de producción): NO es una bandera.
func _add_pennant(root: Node3D, color_id: String, vmat: Material) -> void:
	var mb = gen.builder()
	var wood: Color = gfx.pc("madera_oscura")
	mb.beam(Vector3(0.45, 0.2, -0.1), Vector3(0.45, 2.9, -0.1), 0.05, wood)
	mb.tri(Vector3(0.45, 2.85, -0.1), Vector3(1.15, 2.6, -0.1), Vector3(0.45, 2.35, -0.1), gfx.pc(color_id))
	mb.tri(Vector3(0.45, 2.85, -0.12), Vector3(0.45, 2.35, -0.12), Vector3(1.15, 2.6, -0.12), gfx.pc(color_id).darkened(0.1))
	gfx.part_node(root, "banderin", mb.build(hull_w() * 1.4), vmat)


## Dos figuras agachadas con poncho (los reconocedores), una a cada lado y mirando un poco para afuera; de ropa distinta (una de lana natural: se lee sobre el suelo oscuro).
func _crouched_pair(body: String, spec: Dictionary, variants: Array, index: int, hw: float) -> Dictionary:
	var out := {}
	var merged := {}
	for k in range(2):
		var v: Dictionary = _variant_of(spec, variants, index + k + 1, "")
		v["abrigo"] = "lana_natural" if k == 0 else body
		v["sombrero"] = "madera_oscura"
		var parts: Dictionary = gen.figure_parts("poncho_sombrero", v, "agachado")
		for key in parts:
			if not merged.has(key):
				merged[key] = gen.builder()
			var mb = merged[key]
			mb.push()
			mb.xf = Transform3D(Basis(Vector3.UP, deg_to_rad(-25.0 + 50.0 * float(k))), Vector3(-0.5 + 1.0 * float(k), 0.0, 0.12 * float(k)))
			mb.absorb(parts[key])
			mb.pop()
	for key in merged:
		out[key] = (merged[key] as Object).call("build", hw)
	return out


# ---------------------------------------------------------------------------------------------------------------------
# Defensores y botín: figuras chicas que crecen hasta un mínimo de píxeles

func clear_category(root: Node, category: String) -> void:
	for child in root.get_children():
		root.remove_child(child)
		child.free()
	var keep: Array = []
	for entry in scaled:
		if str(entry.cat) != category:
			keep.append(entry)
	scaled = keep


func register_scaled(node: Node3D, category: String, base: float, px: float, min_scale: float = 1.0) -> void:
	scaled.append({"node": node, "cat": category, "base": maxf(base, 0.1), "px": px, "min": min_scale})


func _enemy_mesh(kind: String) -> ArrayMesh:
	if not _enemy_meshes.has(kind):
		var arch := str(ENEMY_ARCHETYPE.get(kind, "realista_1817"))
		var v := {"camisa": "lana_natural", "abrigo": "lana_parda", "sombrero": "lana_parda", "acento": "borgona_hipotetica"}
		_enemy_meshes[kind] = gen.figure_single(arch, v, hull_w())
	return _enemy_meshes[kind]


func _loot_mesh(kind: String) -> ArrayMesh:
	if not _loot_meshes.has(kind):
		var mesh_kind := {"polvora": "barril", "fusiles": "cajon", "viveres": "saco", "plata": "bulto"}
		if kind == "canones":
			var mb = gen.builder()
			gen.add_cannon(mb, 1.6, 0.8)
			_loot_meshes[kind] = mb.build()
		else:
			_loot_meshes[kind] = gen.prop(str(mesh_kind.get(kind, "bulto")), 3)
	return _loot_meshes[kind]


## Defensores (`enemies`) y botín (`loot`) de render_state. `root_name` y `category` separan los dos grupos; devuelve cuántos dibujó.
func sync_things(root: Node3D, category: String, list: Array) -> int:
	clear_category(root, category)
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
		holder.position = Vector3(x, gfx.rendered_h(x, z), z)
		root.add_child(holder)
		if category == "enemy":
			var mi := MeshInstance3D.new()
			mi.mesh = _enemy_mesh(kind)
			mi.set_surface_override_material(0, gfx.vertex_mat())
			if mi.mesh.get_surface_count() > 1:
				mi.set_surface_override_material(1, gfx.outline_mat())
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(mi)
			gfx.flat_ring(holder, 1.5, 0.45, "borgona_hipotetica" if float(e.get("alert", 0.0)) > 0.5 else "grana_analogia", 0.95)
			if bool(e.get("firing", false)):
				gfx.inst(holder, gfx.sphere_mesh(0.5), Vector3(0.0, 1.6, -0.9), gfx.flat_mat("oro_laton", 1.0, true, 1.4), Vector3.ZERO, false)
			register_scaled(holder, category, 1.9, float(gfx.qcfg.get("enemy_min_px", 14)))
		else:
			holder.position += Vector3(float(count % 3) * 1.5, 0.0, float(count % 2) * 1.5)
			var li := MeshInstance3D.new()
			li.mesh = _loot_mesh(kind)
			li.material_override = gfx.props_mat
			li.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(li)
			register_scaled(holder, category, 0.8, 10.0)
	return count


## La pose de cada ficha (posición y rumbo) tal como la dice `render_state().units`. Se la lee EN CADA CUADRO: las agrupaciones se mueven en cada paso de las reglas sin
## subir `version`, así que si la pose solo se leyera cuando la versión cambia las figuras se quedaban quietas hasta el próximo evento y después saltaban decenas de metros
## (hallazgo H-R1-9: 30,8 m a ×1, 92,5 m a ×2 y 123,4 m a ×4). Cuesta lo que cinco nodos. Devuelve verdadero si alguna ficha se movió.
func sync_poses(state: Dictionary) -> bool:
	var moved := false
	for u in state.get("units", []):
		if not (u is Dictionary) or not unit_nodes.has(str(u.get("id", ""))):
			continue
		var node: Node3D = unit_nodes[str(u.id)]
		var x := float(u.get("x", 0.0))
		var z := float(u.get("z", 0.0))
		var yaw := -deg_to_rad(float(u.get("yaw_deg", 0.0)))
		if absf(node.position.x - x) > 0.0005 or absf(node.position.z - z) > 0.0005 or absf(node.rotation.y - yaw) > 0.0005:
			node.position = Vector3(x, gfx.rendered_h(x, z), z)  # el pie apoya en la malla que se dibuja (en `baja` la ventana tiene un vértice cada 8 m y se aparta hasta ≈ 0,25 m de `height_at`)
			node.rotation.y = yaw
			moved = true
	return moved


## Pose, visibilidad, rótulo y color del anillo de cada ficha (lo que cambia con la versión del estado).
func sync_units(state: Dictionary, labels_on: bool) -> void:
	sync_poses(state)
	for u in state.get("units", []):
		if not (u is Dictionary) or not unit_nodes.has(str(u.get("id", ""))):
			continue
		var id := str(u.id)
		var node: Node3D = unit_nodes[id]
		var gone := str(u.get("stage", "")) == "exited"
		node.visible = not gone
		(unit_labels[id] as Label3D).visible = not gone and labels_on
		var info: Dictionary = tokens[id]
		(info.ring as MeshInstance3D).material_override = gfx.flat_mat("rojo_reservado" if bool(u.get("detected", false)) else str(info.ring_color))


# ---------------------------------------------------------------------------------------------------------------------
# Escala por cuadro

## Píxeles reales por píxel lógico (la ventana escala el área de 1 440 × 900): los tamaños en píxeles del JSON son los de la pantalla.
func update_scales(host: Node, cam: Camera3D) -> void:
	for id in tokens:
		var info: Dictionary = tokens[id]
		var root: Node3D = info.root
		var factor := upright_scale(host, cam, root.global_position if root.is_inside_tree() else root.position, float(info.px), float(info.base_h), 1.0)
		root.scale = factor
		(unit_labels[id] as Label3D).position = root.position + Vector3(0.0, (float(info.base_h) + 1.5) * factor.y, 0.0)
	var alive: Array = []
	for entry in scaled:
		if not is_instance_valid(entry.node):
			continue
		alive.append(entry)
		var node: Node3D = entry.node
		var pos: Vector3 = node.global_position if node.is_inside_tree() else node.position
		if str(entry.cat) == "light":
			var s := maxf(float(entry.min), float(entry.px) / gfx.screen_scale(host) * gfx.meters_per_px_at(cam, pos))
			node.scale = Vector3(s, s, s)
		else:
			node.scale = upright_scale(host, cam, pos, float(entry.px), float(entry.base), float(entry.min))
	scaled = alive


## Escala (x, y, z) para que algo parado de `base_h` m mida `px` píxeles reales de alto en pantalla. Lo vertical se achata por el seno del ángulo entre el rayo y la
## vertical (más cuanto más empinado se lo mira: las fichas de abajo del cuadro se ven más bajas que las de arriba) y por el coseno del descentrado; se lo compensa
## estirando solo el alto, hasta 4,6 veces, para que el ancho no se dispare. Esa cuenta es una estimación: se la corrige con una medición de verdad (se proyectan el pie
## y la cabeza con la cámara que se dibuja) para que el alto en pantalla sea el pedido aunque la cámara sea otra (hallazgo I-R1.0-3: escala medida con la cámara dibujada).
## Con la cámara muy empinada (más de ≈ 70°) de arriba no se ve la altura de una figura: estirarla más la vuelve un trazo largo hacia el nadir, así que el estirón tiene
## un tope que baja de 6,9 a 2,2 veces entre los 58° y los 76°, y el alto pedido baja a los dos tercios entre los 60° y los 80°: la ficha mide menos de lo pedido (queda legible por su
## anillo y por su silueta vista desde arriba) en vez de crecer sin límite.
func upright_scale(host: Node, cam: Camera3D, pos: Vector3, px: float, base_h: float, min_scale: float) -> Vector3:
	if cam == null:
		return Vector3.ONE * min_scale
	var looking_down := rad_to_deg(asin(clampf(cam.global_transform.basis.z.y, 0.0, 1.0)))  # inclinación de la mirada bajo el horizonte (la mirada es −Z: mirar abajo es +Z hacia arriba)
	px *= lerpf(1.0, 0.65, smoothstep(60.0, 80.0, looking_down))  # muy empinada: la ficha se ve desde arriba, así que se achica en vez de crecer sin límite
	var flat := clampf(px / gfx.screen_scale(host) * gfx.meters_per_px_at(cam, pos) / base_h, min_scale, 60.0)
	var ray := pos - cam.global_position
	var dist := maxf(ray.length(), 0.001)
	var tilt := clampf(sqrt(maxf(1.0 - pow(ray.y / dist, 2.0), 0.0)) * (ray.dot(-cam.global_transform.basis.z) / dist), 0.2, 1.0)
	var cap := lerpf(MAX_STRETCH * 1.5, 2.2, smoothstep(58.0, 76.0, looking_down))
	var tall := clampf(flat / tilt, flat, flat * minf(MAX_STRETCH, cap))
	if cam.is_inside_tree() and not cam.is_position_behind(pos):
		var foot := cam.unproject_position(pos)
		var head := cam.unproject_position(pos + Vector3(0.0, base_h * tall, 0.0))
		var got: float = absf(foot.y - head.y) * float(gfx.screen_scale(host))
		if got > 1.0:
			tall = clampf(tall * clampf(px * 1.03 / got, 0.5, 2.0), flat * 0.9, flat * cap)  # el 3 % de más cubre la no linealidad de la perspectiva: el pedido es un mínimo
	return Vector3(flat, tall, flat)


func update_selection(selected: Array, time_s: float) -> void:
	var pulse := 1.0 + 0.07 * sin(time_s * 5.0)
	for id in tokens:
		var sel: MeshInstance3D = tokens[id].selection
		sel.visible = selected.has(id)
		if sel.visible:
			sel.scale = Vector3(pulse, 0.12, pulse)
