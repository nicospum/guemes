extends RefCounted
## Fichas, defensores y botín de la vista del nivel «humahuaca» (pista visual). Cada agrupación tiene SU silueta (no un disco ni un retinte del mismo cuerpo):
##   rodriguez = jinete de poncho y sombrero de ala ancha sobre su caballo · portal = infante de camisa y gorra con fusil · arias = infante con el banderín de mando
##   (marcador de interfaz, nunca una bandera) · reconocedores = dos figuras agachadas con poncho · arreo = mula con aparejo y bultos.
## Las figuras salen del generador procedural (humahuaca_gen.gd, ADDENDA A-01), con contorno oscuro (`negro_textil`) y sin uniformar: la ropa de cada una es una
## variante de las de `humahuaca_visual.json: units`.
## visual/r1 F1: las fichas van a ESCALA REAL (sin crecer con la distancia, `units.marks.figure_scale`); el bando lo da un anillo fino sobre el suelo, de radio real
## (`units.marks.ring_radius_m`), que copia el relieve y respeta la profundidad (los edificios lo tapan). Para encontrarlas lejos está la marca chica en pantalla
## (12 a 16 px) y el rótulo de una línea que dibuja la interfaz (humahuaca_overlay.gd). Antes (R1 y P2) se las estiraba hasta 48 a 72 px y el anillo llegaba a
## decenas de metros: se revirtió a propósito (plan visual/r1, aprobado por el usuario).
## F3 (pendiente): la formación por cantidad de hombres. `men` de cada agrupación está en data/humahuaca_rules.json (groups.<id>.men: 48, 52, 50, 2 y 6); se
## enchufa en build_tokens/_token_parts (repetir la figura en una formación) y en `_ring_radius` (el radio del anillo según la huella de la formación).

const V = preload("res://scripts/humahuaca/humahuaca_vocab.gd")
const Gen = preload("res://scripts/humahuaca/view/humahuaca_gen.gd")

const MAX_THINGS := 48
const ALERT_SHADER := "res://shaders/humahuaca_alert_ring.gdshader"
const MAX_STRETCH := 4.6
## visual/r1 F1: medidas del anillo de bando y de la selección si humahuaca_visual.json no trae `units.marks`.
const MARK_DEFAULTS := {"figure_scale": 1.0, "ring_radius_m": 2.4, "ring_width_m": 0.3, "ring_edge_m": 0.18, "ring_lift_m": 0.22, "selection_gap_m": 0.9,
	"selection_width_m": 0.5, "segments": 40, "rebuild_m": 0.75, "label_font_px": 13}
const LOOT_COLOR := {"polvora": "madera_oscura", "canones": "hierro", "fusiles": "madera_oscura", "viveres": "lana_natural", "plata": "oro_laton"}
## Ganancia de los anillos de bando para llegar a la regla de color común (DIRECCION_DE_ARTE 2.1) sin sumar HEX a la paleta de 24: celeste aliado ≈ #8DB8D6,
## rojo enemigo ≈ #B8433A, hueso neutral ≈ #BFB6A3.
const RING_GAIN := {"celeste_produccion": 1.1, "rojo_reservado": 1.2, "lana_natural": 0.93}
const ENEMY_ARCHETYPE :={"centinela": "realista_1817", "guardia": "realista_1817", "artillero": "artillero", "fusilero": "realista_1817", "mensajero": "poncho_sombrero", "refuerzo": "realista_1817"}

var gfx
var gen
var tokens: Dictionary = {}
var unit_nodes: Dictionary = {}
var unit_labels: Dictionary = {}
var scaled: Array = []  ## [{node, cat, base, px, min}]: lo que crece hasta ocupar `px` píxeles de pantalla (fichas aparte)
var part_counts: Dictionary = {}  ## partes y triángulos de cada ficha (informe de QA)

var _enemy_meshes: Dictionary = {}
var _ring_mats: Dictionary = {}
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
		# visual/r1 F1: sin disco de tinta ni anillos que crecen con la distancia. Un anillo fino de radio real sobre el suelo (con filete oscuro por fuera, para el
		# suelo claro del alba) y la selección en oro, un poco más afuera. Son `top_level`: no giran con la ficha y copian el relieve (se rearman al moverse).
		var ring_r := _ring_radius(id)
		var edge := _ground_ring_node(root, "borde", ring_r, mark("ring_width_m") + 2.0 * mark("ring_edge_m"), mark("ring_lift_m") - 0.03,
			_ring_mat("negro_textil", 1.0, 0.75, 1))
		var ring := _ground_ring_node(root, "anillo", ring_r, mark("ring_width_m"), mark("ring_lift_m"), _ring_mat(ring_color, RING_GAIN.get(ring_color, 1.0), 1.0, 2))
		var selection := _ground_ring_node(root, "seleccion", ring_r + mark("selection_gap_m"), mark("selection_width_m"), mark("ring_lift_m") + 0.02, _ring_mat("oro_laton", 1.25, 1.0, 3))
		selection.visible = false
		var alert := MeshInstance3D.new()  # el aviso de detección (pedido de P3): un aro ámbar que se vacía mientras corre la cuenta del centinela
		alert.name = "aviso"
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * (ring_r + 1.6) * 2.0  # visual/r1 F1: a escala real, apenas más afuera que la selección
		alert.mesh = quad
		alert.material_override = _alert_material()
		alert.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		alert.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		alert.visible = false
		root_tokens.add_child(alert)  # al lado de la ficha, no dentro: no cuenta en su silueta ni en sus medidas
		unit_nodes[id] = root
		var label := Label3D.new()  # visual/r1 F1: rótulo de una línea («1 Rodríguez»), chico; en el juego lo reemplaza el de la interfaz (capa «labels» apagada)
		label.name = "etiqueta_" + id
		var short := str(spec.get("label", ""))
		label.text = str(spec.get("glyph", str(index + 1))) + ("  " + short if short != "" else "")
		label.font_size = int(mark("label_font_px")) * 2
		label.pixel_size = 0.0006
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.fixed_size = true
		label.no_depth_test = true  # el rótulo es de pantalla: se lee aunque la figura quede detrás de una casa
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.offset = Vector2(14.0, 0.0)
		label.modulate = gfx.pc("blanco_textil")
		label.outline_modulate = gfx.pc("negro_textil")
		label.outline_size = 6
		label.visible = false
		root_labels.add_child(label)
		unit_labels[id] = label
		tokens[id] = {"root": root, "base_h": base_h, "ring": ring, "edge": edge, "ring_color": ring_color, "selection": selection, "alert": alert, "alert_max": 0.0,
			"ring_at": Vector3(INF, INF, INF)}


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
	var vmat: Material = gfx.token_mat("aliado")
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


## Los reconocedores: un baqueano de pie con su lanza y otro agachado delante, que mira (de ropa distinta: uno de lana natural, que se lee sobre el suelo oscuro).
## Antes eran dos figuras agachadas: bajas y anchas, al estirarlas hasta el alto pedido en pantalla se volvían una mancha ancha del doble de las otras fichas.
func _crouched_pair(body: String, spec: Dictionary, variants: Array, index: int, hw: float) -> Dictionary:
	var out := {}
	var merged := {}
	for k in range(2):
		var v: Dictionary = _variant_of(spec, variants, index + k + 1, "")
		v["abrigo"] = "lana_natural" if k == 0 else body
		v["sombrero"] = "madera_oscura"
		var parts: Dictionary = gen.figure_parts("poncho_sombrero", v, "de_pie" if k == 0 else "agachado")
		for key in parts:
			if not merged.has(key):
				merged[key] = gen.builder()
			var mb = merged[key]
			mb.push()
			mb.xf = Transform3D(Basis(Vector3.UP, deg_to_rad(-12.0 + 30.0 * float(k))), Vector3(-0.55 + 1.15 * float(k), 0.0, -0.45 * float(k)))
			mb.absorb(parts[key])
			if k == 0 and str(key) == "equipo":  # el baqueano de pie lleva una tacuara larga (caña con punta): lo distingue de la mula del arreo, que mide lo mismo
				mb.beam(Vector3(0.43, 1.9, -0.1), Vector3(0.46, 2.4, -0.1), 0.04, gfx.pc("madera_oscura", 1.15))
				mb.cyl_between(Vector3(0.46, 2.4, -0.1), Vector3(0.47, 2.58, -0.1), 0.045, 0.0, 6, gfx.pc("hierro"))
			mb.pop()
	for key in merged:
		out[key] = (merged[key] as Object).call("build", hw)
	return out


# ---------------------------------------------------------------------------------------------------------------------
# visual/r1 F1: anillo de bando a escala real, pegado al relieve

## Una medida de `units.marks` (humahuaca_visual.json) o su valor por defecto.
func mark(key: String) -> float:
	var cfg: Variant = (gfx.data.get("units", {}) as Dictionary).get("marks", {}) if gfx != null else {}
	var v: Variant = (cfg as Dictionary).get(key, MARK_DEFAULTS.get(key, 0.0)) if cfg is Dictionary else MARK_DEFAULTS.get(key, 0.0)
	return float(v) if (typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT) else float(MARK_DEFAULTS.get(key, 0.0))


## El radio del anillo de una agrupación en metros. F3 lo hará depender de la huella de la formación (groups.<id>.men de humahuaca_rules.json).
func _ring_radius(id: String) -> float:
	var spec: Dictionary = (gfx.data.get("tokens", {}) as Dictionary).get(id, {})
	return float(spec.get("ring_radius_m", mark("ring_radius_m")))


## Material del anillo: plano, sin sombra, con prueba de profundidad (lo tapan los edificios) y sin descarte de caras (el relieve lo puede dar vuelta).
func _ring_mat(color_id: String, gain: float, alpha: float, priority: int) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%d" % [color_id, gain, alpha, priority]
	if not _ring_mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		var c: Color = gfx.pc(color_id, gain)
		m.albedo_color = Color(c.r, c.g, c.b, alpha)
		if alpha < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.render_priority = priority
		_ring_mats[key] = m
	return _ring_mats[key]


## Un anillo hijo de la ficha pero `top_level` (no gira con ella); guarda su radio, ancho y alzada para rearmarlo al moverse.
func _ground_ring_node(root: Node3D, node_name: String, radius: float, width: float, lift: float, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.top_level = true
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("ring", Vector3(radius, width, lift))
	root.add_child(mi)
	return mi


## La malla de un anillo plano de `radius` m y `width` m de ancho centrado en `center`, con cada vértice a `lift` m sobre la malla dibujada del suelo (relativa a center.y).
func _ground_ring_mesh(center: Vector3, radius: float, width: float, lift: float) -> ArrayMesh:
	var segs := maxi(int(mark("segments")), 12)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var idx := PackedInt32Array()
	for i in range(segs + 1):
		var a := TAU * float(i) / float(segs)
		var d := Vector2(cos(a), sin(a))
		for r in [maxf(radius - width * 0.5, 0.02), radius + width * 0.5]:
			var x := center.x + d.x * float(r)
			var z := center.z + d.y * float(r)
			verts.append(Vector3(d.x * float(r), gfx.rendered_h(x, z) + lift - center.y, d.y * float(r)))
			normals.append(Vector3.UP)
	for i in range(segs):
		var k := i * 2
		idx.append_array(PackedInt32Array([k, k + 2, k + 1, k + 1, k + 2, k + 3]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Ubica los anillos de una ficha en su pie y, si se corrió más de `rebuild_m` desde la última vez, los rearma con el relieve de su lugar nuevo.
func _place_rings(id: String) -> void:
	var info: Dictionary = tokens[id]
	var root: Node3D = info.root
	var at := root.position
	var rebuild := (info.ring_at as Vector3).distance_to(at) > mark("rebuild_m")
	for key in ["edge", "ring", "selection"]:
		var mi: MeshInstance3D = info[key]
		var spec: Vector3 = mi.get_meta("ring", Vector3(2.0, 0.3, 0.2))
		if rebuild:
			mi.mesh = _ground_ring_mesh(at, spec.x, spec.y, spec.z)
		# `top_level`: su posición ya es la del mundo. Entre dos rearmados se lo corre solo en el plano, a la altura con la que se armó la malla
		mi.position = at if rebuild else Vector3(at.x, (info.ring_at as Vector3).y, at.z)
	if rebuild:
		info["ring_at"] = at


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
		_enemy_meshes[kind] = gen.figure_single(arch, v, hull_w() * 1.8)  # contorno más grueso: a 28 px la figura tiene que recortarse del suelo
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
			mi.set_surface_override_material(0, gfx.token_mat("enemigo"))
			if mi.mesh.get_surface_count() > 1:
				mi.set_surface_override_material(1, gfx.outline_mat())
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(mi)
			# regla de color: el enemigo es ROJO (anillo rojo con filete de tinta y disco oscuro debajo), más vivo si está alertado
			gfx.inst(holder, gfx.cyl_mesh(1.75, 1.75, 0.04, 16), Vector3(0.0, 0.05, 0.0), gfx.flat_mat("negro_textil", 0.5), Vector3.ZERO, false).name = "base"
			var alert := float(e.get("alert", 0.0)) > 0.5
			gfx.flat_ring(holder, 1.5, 0.45, "rojo_reservado", 1.0).material_override = gfx.flat_mat("rojo_reservado", 1.0, false, 1.35 if alert else 1.1)
			gfx.flat_ring(holder, 1.72, 0.2, "negro_textil", 0.9).name = "borde"
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
		_sync_alert(str(u.id), float(u.get("spotted_s", 0.0)))
		if absf(node.position.x - x) > 0.0005 or absf(node.position.z - z) > 0.0005 or absf(node.rotation.y - yaw) > 0.0005:
			node.position = Vector3(x, gfx.rendered_h(x, z), z)  # el pie apoya en la malla que se dibuja (en `baja` la ventana tiene un vértice cada 8 m y se aparta hasta ≈ 0,25 m de `height_at`)
			node.rotation.y = yaw
			_place_rings(str(u.id))  # visual/r1 F1
			moved = true
	return moved


## El aro de detección de una ficha: visible mientras `spotted_s` > 0 (los segundos que faltan para que el centinela dé la voz) y lleno en la proporción que queda de la
## cuenta (el máximo visto en este aviso es el total; las reglas usan 5 s). Ámbar y por encima de todo: es el telegrafiado del peligro (Shadow Tactics, pedido de diseño).
func _sync_alert(id: String, spotted_s: float) -> void:
	if not tokens.has(id):
		return
	var info: Dictionary = tokens[id]
	var alert: MeshInstance3D = info.alert
	if spotted_s <= 0.01:
		if alert.visible:
			alert.visible = false
		info["alert_max"] = 0.0
		return
	info["alert_max"] = maxf(float(info.alert_max), maxf(spotted_s, 0.5))
	alert.visible = true
	alert.position = (info.root as Node3D).position + Vector3(0.0, 0.35 * (info.root as Node3D).scale.x, 0.0)
	alert.scale = Vector3.ONE * (info.root as Node3D).scale.x
	(alert.material_override as ShaderMaterial).set_shader_parameter("fill", clampf(spotted_s / float(info.alert_max), 0.0, 1.0))


func _alert_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()  # uno por ficha: cada aro tiene su propia cuenta
	m.shader = load(ALERT_SHADER) as Shader
	m.set_shader_parameter("tint", gfx.pc("oro_laton", 1.05).lerp(gfx.pc("rojo_reservado", 1.05), 0.38))
	m.render_priority = 9
	return m


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
		var ring_id := "rojo_reservado" if bool(u.get("detected", false)) else str(info.ring_color)
		(info.ring as MeshInstance3D).material_override = _ring_mat(ring_id, float(RING_GAIN.get(ring_id, 1.0)), 1.0, 2)  # visual/r1 F1: descubierta = rojo, como antes


# ---------------------------------------------------------------------------------------------------------------------
# Escala por cuadro

## Píxeles reales por píxel lógico (la ventana escala el área de 1 440 × 900): los tamaños en píxeles del JSON son los de la pantalla.
func update_scales(host: Node, cam: Camera3D) -> void:
	# visual/r1 F1: las fichas ya no crecen con la distancia: escala fija (`units.marks.figure_scale`, 1 = tamaño real). El rótulo va sobre la cabeza.
	var fig := maxf(mark("figure_scale"), 0.1)
	for id in tokens:
		var info: Dictionary = tokens[id]
		var root: Node3D = info.root
		root.scale = Vector3.ONE * fig
		(unit_labels[id] as Label3D).position = root.position + Vector3(0.0, float(info.base_h) * fig + 0.6, 0.0)
		if (info.ring_at as Vector3).x == INF:
			_place_rings(str(id))
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
			sel.scale = Vector3(pulse, 1.0, pulse)  # visual/r1 F1: el anillo ya es plano y pegado al suelo (antes un toro aplastado)
