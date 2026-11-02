extends RefCounted
## Generador procedural de arte del nivel «humahuaca» (pista visual; ADDENDA A-01: es el único canal de arte, sin Blender ni descargas).
## Arma mallas con primitivas propias (cajas, prismas a dos aguas, troncos de cono, cilindros, elipsoides) y color por vértice sacado de la PALETA
## (nunca un HEX suelto: se pide por id). Todo es determinista: la misma semilla da la misma malla. Convenciones de las mallas:
##   · +Y arriba, origen en el suelo bajo el centro de la huella, la figura mira a −Z (como el rumbo 0 de las unidades), el templo tiene su nave sobre +X;
##   · COLOR.rgb = color sRGB de la paleta; COLOR.a = 0 al pie y 1 arriba (suciedad y desgaste: el shader de props oscurece lo bajo);
##   · los cuadriláteros se dan en sentido antihorario visto desde afuera y se emiten en el sentido horario que usa Godot para la cara frontal.
## Qué arma: el TEMPLO (nave simple de adobe encalado a dos aguas, sin torres ni fachada de 1880-81; caballete en 7 m), los TRES ARQUETIPOS de figura
## (poncho_sombrero, camisa_gorra y artillero) más el realista de 1817 retintado, la torre provisional, la batería (losa con parapeto: nada de fustes),
## casas del núcleo, cañones, el caballo y la mula de las fichas, y la vegetación y los bultos del anillo de contenido.

const V = preload("res://scripts/humahuaca/humahuaca_vocab.gd")

## Una figura se arma en partes (ropa, piel, sombrero, equipo…): cada una es un nodo de malla de la ficha y lleva su propio casco de contorno.
const FIGURE_PARTS := ["ropa", "poncho", "brazos", "delantal", "piel", "sombrero", "equipo", "animal", "carga"]

var palette: Dictionary = {}  ## id de paleta → Color (sRGB)


func _init(pal: Dictionary = {}) -> void:
	palette = pal


## Color de la paleta por id (con ganancia opcional). Un id desconocido da un gris neutro y no rompe la construcción.
func pc(id: String, gain: float = 1.0) -> Color:
	var c: Color = palette.get(id, Color(0.5, 0.5, 0.5))
	return Color(minf(c.r * gain, 1.0), minf(c.g * gain, 1.0), minf(c.b * gain, 1.0), 1.0)


## Mezcla de dos ids de la paleta (para variantes de ropa sin salir de la paleta).
func pmix(a: String, b: String, k: float) -> Color:
	return pc(a).lerp(pc(b), clampf(k, 0.0, 1.0))


# ---------------------------------------------------------------------------------------------------------------------
# Constructor de mallas

class MB extends RefCounted:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var xf := Transform3D.IDENTITY
	var _stack: Array = []

	func push() -> void:
		_stack.append(xf)

	func pop() -> void:
		if not _stack.is_empty():
			xf = _stack.pop_back()

	func move(v: Vector3) -> void:
		xf = xf.translated_local(v)

	func turn_y(deg: float) -> void:
		xf = xf.rotated_local(Vector3.UP, deg_to_rad(deg))

	func turn_x(deg: float) -> void:
		xf = xf.rotated_local(Vector3.RIGHT, deg_to_rad(deg))

	func turn_z(deg: float) -> void:
		xf = xf.rotated_local(Vector3.BACK, deg_to_rad(deg))

	func tri_count() -> int:
		return idx.size() / 3

	## Cuadrilátero a, b, c, d en sentido antihorario visto desde afuera, con un color por vértice.
	func quad4(a: Vector3, b: Vector3, c: Vector3, d: Vector3, ca: Color, cb: Color, cc: Color, cd: Color) -> void:
		var pa := xf * a
		var pb := xf * b
		var pcc := xf * c
		var pd := xf * d
		var n := (pb - pa).cross(pcc - pa)
		if n.length_squared() < 1.0e-12:
			n = (pcc - pa).cross(pd - pa)
		n = n.normalized()
		var base := verts.size()
		verts.append_array(PackedVector3Array([pa, pb, pcc, pd]))
		norms.append_array(PackedVector3Array([n, n, n, n]))
		cols.append_array(PackedColorArray([ca, cb, cc, cd]))
		idx.append_array(PackedInt32Array([base, base + 2, base + 1, base, base + 3, base + 2]))

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
		quad4(a, b, c, d, col, col, col, col)

	## Lo mismo pero a y b son el borde de abajo (color `low`, desgaste 0) y c y d el de arriba (color `high`, desgaste 1).
	func quad_g(a: Vector3, b: Vector3, c: Vector3, d: Vector3, low: Color, high: Color) -> void:
		var l := Color(low.r, low.g, low.b, 0.0)
		var h := Color(high.r, high.g, high.b, 1.0)
		quad4(a, b, c, d, l, l, h, h)

	func tri(a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
		var pa := xf * a
		var pb := xf * b
		var pcc := xf * c
		var n := (pb - pa).cross(pcc - pa).normalized()
		var base := verts.size()
		verts.append_array(PackedVector3Array([pa, pb, pcc]))
		norms.append_array(PackedVector3Array([n, n, n]))
		cols.append_array(PackedColorArray([col, col, col]))
		idx.append_array(PackedInt32Array([base, base + 2, base + 1]))

	## Caja centrada en `c`; los lados degradan de `low` (pie, sucio) a `col` (arriba). Sin base salvo que se pida.
	func box(c: Vector3, s: Vector3, col: Color, low: Color = Color(0, 0, 0, -1.0), with_bottom: bool = false) -> void:
		if low.a < 0.0:
			low = col.darkened(0.18)
		var h := s * 0.5
		var x0 := c.x - h.x
		var x1 := c.x + h.x
		var y0 := c.y - h.y
		var y1 := c.y + h.y
		var z0 := c.z - h.z
		var z1 := c.z + h.z
		quad_g(Vector3(x1, y0, z1), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), low, col)  # +X
		quad_g(Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0), low, col)  # −X
		quad_g(Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1), low, col)  # +Z
		quad_g(Vector3(x1, y0, z0), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x1, y1, z0), low, col)  # −Z
		quad(Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3(x0, y1, z0), col.lightened(0.06))  # arriba
		if with_bottom:
			quad(Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x0, y0, z1), low)

	## Tronco de pirámide de base (w0 × d0) y cima (w1 × d1) a la altura h, apoyado en y = c.y (poncho, taludes, plataformas).
	func frustum(c: Vector3, w0: float, d0: float, w1: float, d1: float, h: float, col: Color, low: Color = Color(0, 0, 0, -1.0), top_col: Color = Color(0, 0, 0, -1.0)) -> void:
		if low.a < 0.0:
			low = col.darkened(0.18)
		if top_col.a < 0.0:
			top_col = col.lightened(0.06)
		var b0 := Vector3(c.x - w0 * 0.5, c.y, c.z - d0 * 0.5)
		var b1 := Vector3(c.x + w0 * 0.5, c.y, c.z - d0 * 0.5)
		var b2 := Vector3(c.x + w0 * 0.5, c.y, c.z + d0 * 0.5)
		var b3 := Vector3(c.x - w0 * 0.5, c.y, c.z + d0 * 0.5)
		var t0 := Vector3(c.x - w1 * 0.5, c.y + h, c.z - d1 * 0.5)
		var t1 := Vector3(c.x + w1 * 0.5, c.y + h, c.z - d1 * 0.5)
		var t2 := Vector3(c.x + w1 * 0.5, c.y + h, c.z + d1 * 0.5)
		var t3 := Vector3(c.x - w1 * 0.5, c.y + h, c.z + d1 * 0.5)
		quad_g(b2, b1, t1, t2, low, col)  # +X
		quad_g(b0, b3, t3, t0, low, col)  # −X
		quad_g(b3, b2, t2, t3, low, col)  # +Z
		quad_g(b1, b0, t0, t1, low, col)  # −Z
		quad(t3, t2, t1, t0, top_col)

	## Techo a dos aguas con el caballete sobre X: largo `l`, ancho `w`, `rise` m de altura sobre el alero (y = c.y). Con testeros y la cara de abajo.
	func gable(c: Vector3, l: float, w: float, rise: float, col: Color, end_col: Color, under: Color, shade: float = 0.12) -> void:
		var x0 := c.x - l * 0.5
		var x1 := c.x + l * 0.5
		var z0 := c.z - w * 0.5
		var z1 := c.z + w * 0.5
		var yr := c.y + rise
		quad_g(Vector3(x0, c.y, z1), Vector3(x1, c.y, z1), Vector3(x1, yr, c.z), Vector3(x0, yr, c.z), col.darkened(shade), col)  # agua sur
		quad_g(Vector3(x1, c.y, z0), Vector3(x0, c.y, z0), Vector3(x0, yr, c.z), Vector3(x1, yr, c.z), col.darkened(shade), col)  # agua norte
		tri(Vector3(x1, c.y, z1), Vector3(x1, c.y, z0), Vector3(x1, yr, c.z), end_col)
		tri(Vector3(x0, c.y, z0), Vector3(x0, c.y, z1), Vector3(x0, yr, c.z), end_col)
		quad(Vector3(x0, c.y, z0), Vector3(x1, c.y, z0), Vector3(x1, c.y, z1), Vector3(x0, c.y, z1), under)

	## Cilindro o tronco de cono vertical (radios r0 abajo y r1 arriba) de `h` m de alto; la tapa de arriba si r1 > 0. Los lados salen suaves de a un segmento.
	func cyl(c: Vector3, r0: float, r1: float, h: float, seg: int, col: Color, low: Color = Color(0, 0, 0, -1.0), top_col: Color = Color(0, 0, 0, -1.0)) -> void:
		if low.a < 0.0:
			low = col.darkened(0.15)
		if top_col.a < 0.0:
			top_col = col.lightened(0.05)
		for k in range(seg):
			var a0 := TAU * float(k) / float(seg)
			var a1 := TAU * float(k + 1) / float(seg)
			var p0 := Vector3(cos(a0), 0.0, sin(a0))
			var p1 := Vector3(cos(a1), 0.0, sin(a1))
			# de a1 a a0 para que la cara mire hacia afuera (los ángulos crecientes giran hacia +Z)
			quad_g(c + p1 * r0, c + p0 * r0, c + Vector3(0.0, h, 0.0) + p0 * r1, c + Vector3(0.0, h, 0.0) + p1 * r1, low, col)
			if r1 > 0.001:
				tri(c + Vector3(0.0, h, 0.0), c + Vector3(0.0, h, 0.0) + p1 * r1, c + Vector3(0.0, h, 0.0) + p0 * r1, top_col)

	## Cilindro entre dos puntos (cañones, mástiles, patas inclinadas).
	func cyl_between(a: Vector3, b: Vector3, r0: float, r1: float, seg: int, col: Color) -> void:
		var d := b - a
		var length := d.length()
		if length < 0.001:
			return
		var dir := d / length
		var q := Quaternion(Vector3.UP, dir) if dir.dot(Vector3.UP) > -0.999 else Quaternion(Vector3.RIGHT, PI)
		var saved := xf
		xf = xf * Transform3D(Basis(q), a)
		cyl(Vector3.ZERO, r0, r1, length, seg, col)
		xf = saved

	## Viga: caja de sección `t × t` entre dos puntos.
	func beam(a: Vector3, b: Vector3, t: float, col: Color, t2: float = -1.0) -> void:
		var d := b - a
		var length := d.length()
		if length < 0.001:
			return
		var dir := d / length
		var up := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
		var saved := xf
		xf = xf * Transform3D(Basis.looking_at(dir, up), (a + b) * 0.5)
		box(Vector3.ZERO, Vector3(t, t if t2 < 0.0 else t2, length), col)
		xf = saved

	## Elipsoide de pocos segmentos (cabezas, bultos, copas): de a `rings` anillos y `seg` lados.
	func ball(c: Vector3, rx: float, ry: float, rz: float, seg: int, rings: int, col: Color, low: Color = Color(0, 0, 0, -1.0)) -> void:
		if low.a < 0.0:
			low = col.darkened(0.2)
		for j in range(rings):
			var v0 := PI * float(j) / float(rings)
			var v1 := PI * float(j + 1) / float(rings)
			for k in range(seg):
				var a0 := TAU * float(k) / float(seg)
				var a1 := TAU * float(k + 1) / float(seg)
				var p00 := c + Vector3(rx * sin(v0) * cos(a0), ry * cos(v0), rz * sin(v0) * sin(a0))
				var p01 := c + Vector3(rx * sin(v0) * cos(a1), ry * cos(v0), rz * sin(v0) * sin(a1))
				var p10 := c + Vector3(rx * sin(v1) * cos(a0), ry * cos(v1), rz * sin(v1) * sin(a0))
				var p11 := c + Vector3(rx * sin(v1) * cos(a1), ry * cos(v1), rz * sin(v1) * sin(a1))
				var k0 := low.lerp(col, clampf(0.5 + 0.5 * cos(v0), 0.0, 1.0))
				var k1 := low.lerp(col, clampf(0.5 + 0.5 * cos(v1), 0.0, 1.0))
				if j == 0:
					tri(p00, p11, p10, k1)
				elif j == rings - 1:
					tri(p00, p01, p10, k0)
				else:
					quad4(p00, p01, p11, p10, k0, k0, k1, k1)

	## Vuelca otro constructor en este (con su transformación actual aplicada).
	func absorb(other: MB) -> void:
		var base := verts.size()
		for i in range(other.verts.size()):
			verts.append(xf * other.verts[i])
			norms.append((xf.basis * other.norms[i]).normalized())
			cols.append(other.cols[i])
		for i in other.idx:
			idx.append(base + i)

	## Normales suaves por posición (para el casco de contorno): las caras que comparten un vértice promedian su normal.
	func _smooth_normals() -> PackedVector3Array:
		var sums := {}
		for i in range(verts.size()):
			var key := Vector3i(roundi(verts[i].x * 500.0), roundi(verts[i].y * 500.0), roundi(verts[i].z * 500.0))
			sums[key] = ((sums[key] as Vector3) + norms[i]) if sums.has(key) else norms[i]
		var out := PackedVector3Array()
		out.resize(verts.size())
		for i in range(verts.size()):
			var key := Vector3i(roundi(verts[i].x * 500.0), roundi(verts[i].y * 500.0), roundi(verts[i].z * 500.0))
			out[i] = (sums[key] as Vector3).normalized()
		return out

	## La malla: superficie 0 = la geometría; con `hull_w` > 0, superficie 1 = el mismo casco inflado a lo largo de la normal suave (se dibuja con las
	## caras de adelante cortadas: queda solo el borde oscuro, el contorno de las figuras).
	func build(hull_w: float = 0.0) -> ArrayMesh:
		var mesh := ArrayMesh.new()
		if verts.is_empty():
			return mesh
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = norms
		arrays[Mesh.ARRAY_COLOR] = cols
		arrays[Mesh.ARRAY_INDEX] = idx
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		if hull_w > 0.0:
			var smooth := _smooth_normals()
			var inflated := PackedVector3Array()
			inflated.resize(verts.size())
			for i in range(verts.size()):
				inflated[i] = verts[i] + smooth[i] * hull_w
			var hull: Array = []
			hull.resize(Mesh.ARRAY_MAX)
			hull[Mesh.ARRAY_VERTEX] = inflated
			hull[Mesh.ARRAY_NORMAL] = smooth
			hull[Mesh.ARRAY_INDEX] = idx
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, hull)
		return mesh


func builder() -> MB:
	return MB.new()


# ---------------------------------------------------------------------------------------------------------------------
# El templo: nave simple de adobe encalado a dos aguas, sin torres ni fachada de 1880-81

## `spec`: {w, d, ridge_m, eave_ratio, color, roof_color, trim_color}. Origen en el suelo bajo el centro de la huella; la nave corre sobre X, la puerta mira al sur (+Z).
## Nada pasa del caballete (`ridge_m`, 7 m): ni cruz, ni espadaña, ni remate. Alero a `eave_ratio` del caballete.
func add_temple(mb: MB, spec: Dictionary) -> void:
	var w := float(spec.get("w", 22.0))
	var d := float(spec.get("d", 8.0))
	var ridge := float(spec.get("ridge_m", 7.0))
	var eave := ridge * float(spec.get("eave_ratio", 0.78))
	var wall := pc(str(spec.get("color", "cal_envejecida")))
	var adobe := pc("adobe")
	var roof := pmix(str(spec.get("roof_color", "paja")), "cal_envejecida", 0.55)  # techo claro y rugoso, como en la foto de 1923: se lo distingue del suelo desde arriba
	var wood := pc(str(spec.get("trim_color", "madera_oscura")))
	var stone := pc("piedra_gris")
	var plinth := 0.5
	mb.box(Vector3(0.0, plinth * 0.5 - 0.15, 0.0), Vector3(w + 0.6, plinth + 0.3, d + 0.6), stone, stone.darkened(0.25))
	mb.box(Vector3(0.0, plinth + (eave - plinth) * 0.5, 0.0), Vector3(w, eave - plinth, d), wall, adobe.darkened(0.12))
	for i in range(5):  # contrafuertes de adobe a los dos lados de la nave
		var x := -w * 0.5 + 2.2 + float(i) * (w - 4.4) / 4.0
		for side in [-1.0, 1.0]:
			mb.frustum(Vector3(x, plinth - 0.1, side * (d * 0.5 + 0.38)), 0.9, 1.0, 0.7, 0.6, eave * 0.62, adobe, adobe.darkened(0.25))
	mb.gable(Vector3(0.0, eave, 0.0), w + 1.6, d + 1.6, ridge - eave, roof, wall.darkened(0.08), wood.darkened(0.2), 0.0)
	mb.box(Vector3(0.0, ridge - 0.07, 0.0), Vector3(w + 1.5, 0.14, 0.5), roof.lightened(0.2), roof.lightened(0.1))  # la cumbrera: remata justo en el caballete (7 m)
	mb.tri(Vector3(w * 0.5, eave, d * 0.5), Vector3(w * 0.5, eave, -d * 0.5), Vector3(w * 0.5, ridge - 0.12, 0.0), wall)  # testeros de la nave bajo el alero
	mb.tri(Vector3(-w * 0.5, eave, -d * 0.5), Vector3(-w * 0.5, eave, d * 0.5), Vector3(-w * 0.5, ridge - 0.12, 0.0), wall)
	mb.box(Vector3(0.0, 1.85, d * 0.5 + 0.05), Vector3(2.3, 3.4, 0.3), wood, wood.darkened(0.25))  # portada lateral sobre el atrio
	mb.box(Vector3(0.0, 3.7, d * 0.5 + 0.08), Vector3(2.9, 0.35, 0.34), wood.darkened(0.1))  # dintel
	mb.box(Vector3(w * 0.5 + 0.05, 1.5, 0.0), Vector3(0.3, 2.8, 1.6), wood)  # puerta del testero este
	for wx in [-6.0, -2.0, 2.0, 6.0]:  # ventanas altas y chicas
		mb.box(Vector3(wx, eave - 1.3, d * 0.5 + 0.03), Vector3(0.55, 0.9, 0.14), wood.darkened(0.45))
		mb.box(Vector3(wx, eave - 1.3, -d * 0.5 - 0.03), Vector3(0.55, 0.9, 0.14), wood.darkened(0.45))
	# sacristía baja contra el lado norte, con su techo de una agua
	mb.box(Vector3(w * 0.5 - 3.2, 1.7, -d * 0.5 - 2.0), Vector3(5.6, 3.4, 4.2), wall, adobe.darkened(0.1))
	mb.gable(Vector3(w * 0.5 - 3.2, 3.4, -d * 0.5 - 2.0), 6.4, 5.0, 0.9, roof, wall.darkened(0.05), wood.darkened(0.2))
	# atrio: plataforma de tierra apisonada de 14 × 10 m delante de la portada, con un murete bajo y una abertura al centro
	var atrio := pc("suelo_seco", 1.06)
	mb.box(Vector3(0.0, 0.14, d * 0.5 + 5.4), Vector3(14.0, 0.3, 10.0), atrio, atrio.darkened(0.22))
	for side in [-1.0, 1.0]:
		mb.box(Vector3(side * 6.75, 0.65, d * 0.5 + 5.4), Vector3(0.5, 0.8, 9.6), adobe, adobe.darkened(0.2))
		mb.box(Vector3(side * 3.9, 0.65, d * 0.5 + 10.2), Vector3(5.2, 0.8, 0.5), adobe, adobe.darkened(0.2))


func build_temple(spec: Dictionary) -> ArrayMesh:
	var mb := MB.new()
	add_temple(mb, spec)
	return mb.build()


# ---------------------------------------------------------------------------------------------------------------------
# La torre provisional, la batería (losa con parapeto, sin fustes) y los cañones

## Cañón de campaña con su cureña de madera, apuntando a −Z (adelante), de largo `len` m.
func add_cannon(mb: MB, len_m: float = 2.0, scale_k: float = 1.0) -> void:
	var iron := pc("hierro")
	var wood := pc("madera_oscura")
	mb.push()
	mb.xf = mb.xf.scaled_local(Vector3.ONE * scale_k)
	mb.cyl_between(Vector3(0.0, 0.75, 0.55), Vector3(0.0, 0.8, 0.55 - len_m), 0.26, 0.19, 8, iron)  # el tubo, apenas levantado
	mb.ball(Vector3(0.0, 0.75, 0.6), 0.27, 0.27, 0.27, 8, 4, iron)
	mb.box(Vector3(-0.38, 0.55, 0.0), Vector3(0.12, 0.34, 1.6), wood)  # gualderas de la cureña
	mb.box(Vector3(0.38, 0.55, 0.0), Vector3(0.12, 0.34, 1.6), wood)
	mb.beam(Vector3(0.0, 0.45, 0.2), Vector3(0.0, 0.1, 1.5), 0.14, wood)  # la cola
	for sx in [-0.5, 0.5]:  # ruedas macizas
		mb.cyl_between(Vector3(sx - 0.05, 0.5, -0.1), Vector3(sx + 0.05, 0.5, -0.1), 0.5, 0.5, 10, wood.lightened(0.04))
	mb.pop()


## Torre provisional de la casa del cura o del templo: tronco de adobe de 3,5 m de lado y 10 m, plataforma de madera a 9 m con parapeto y ocho aspilleras.
## No es una torre de campanas: no tiene arcos, ni cubierta, ni remate; se lee como un puesto de tirador (vertical con plataforma).
func add_tower(mb: MB, w: float, d: float, h: float) -> void:
	var adobe := pc("adobe")
	var wood := pc("madera_oscura")
	var cal := pc("cal_envejecida")
	var top := maxf(h - 1.1, 3.0)  # la plataforma queda a 9 m de los 10
	mb.frustum(Vector3(0.0, -0.2, 0.0), w + 0.5, d + 0.5, w - 0.5, d - 0.5, top + 0.2, adobe, adobe.darkened(0.3), adobe.lightened(0.05))
	mb.box(Vector3(0.0, 1.0, d * 0.5 + 0.0), Vector3(1.0, 2.0, 0.2), wood)  # la puerta
	for k in range(3):  # tablones de andamio que salen del muro
		mb.beam(Vector3(-w * 0.5 - 0.05, top - 1.5 - float(k) * 2.0, 0.0), Vector3(-w * 0.5 - 0.5, top - 1.5 - float(k) * 2.0, 0.0), 0.16, wood)
	mb.box(Vector3(0.0, top + 0.15, 0.0), Vector3(w + 1.5, 0.3, d + 1.5), wood.lightened(0.04), wood.darkened(0.3))
	var half_w := (w + 1.5) * 0.5
	var half_d := (d + 1.5) * 0.5
	var ph := 0.9
	for side in range(4):  # tres tramos de parapeto por lado con una ranura (aspillera) entre cada par: ocho en total, dos por lado
		var along_x := side < 2
		var length := (w + 1.5) if along_x else (d + 1.5)
		var fixed := (half_d if along_x else half_w) * (1.0 if side % 2 == 0 else -1.0)
		for part in range(3):
			var center := (float(part) - 1.0) * length * 0.36
			var seg := length * 0.26
			var pos := Vector3(center, top + 0.3 + ph * 0.5, fixed * 0.94) if along_x else Vector3(fixed * 0.94, top + 0.3 + ph * 0.5, center)
			var dims := Vector3(seg, ph, 0.28) if along_x else Vector3(0.28, ph, seg)
			mb.box(pos, dims, cal, adobe.darkened(0.15))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			mb.box(Vector3(sx * half_w * 0.95, top + 0.3 + ph * 0.5 + 0.1, sz * half_d * 0.95), Vector3(0.34, ph + 0.2, 0.34), wood)


## La batería de Santa Bárbara: una losa de tierra con parapeto de gaviones y tres cañoneras al oeste, gola abierta al este, piezas bajas y un abrigo.
## Mide a lo sumo 2,4 m sobre la losa: nada de fustes ni cilindros altos (hallazgo B-023: dos fustes se leían como dos torres de iglesia).
func add_battery(mb: MB, w: float, d: float, parapet_m: float, pieces: int, slab: float) -> void:
	var earth := pc("suelo_seco", 0.9)
	var stone := pc("piedra_gris")
	var wood := pc("madera_oscura")
	var iron := pc("hierro")
	var cal := pc("adobe")
	mb.frustum(Vector3(0.0, -0.3, 0.0), w + 4.0, d + 4.0, w, d, slab + 0.3, earth, earth.darkened(0.3), earth.lightened(0.04))  # la losa con sus taludes
	var rx := w * 0.5  # rampa de la gola, al este: baja de la losa al suelo en 6 m
	var ramp := earth.lightened(0.05)
	mb.quad(Vector3(rx, slab, 3.0), Vector3(rx + 6.0, -0.3, 3.0), Vector3(rx + 6.0, -0.3, -3.0), Vector3(rx, slab, -3.0), ramp)
	mb.tri(Vector3(rx, slab, 3.0), Vector3(rx, -0.3, 3.0), Vector3(rx + 6.0, -0.3, 3.0), earth.darkened(0.2))
	mb.tri(Vector3(rx, slab, -3.0), Vector3(rx + 6.0, -0.3, -3.0), Vector3(rx, -0.3, -3.0), earth.darkened(0.2))
	var th := 1.7
	var h := parapet_m
	var gap := 2.0  # ancho de una cañonera
	var span := d - 2.0
	var west_x := -w * 0.5 + th * 0.5 + 0.4
	# parapeto oeste (con tantas cañoneras como piezas), norte y sur; de gaviones abajo y tierra arriba
	var piece_z: Array = []
	for k in range(pieces):
		piece_z.append(((float(k) + 0.5) / float(pieces) - 0.5) * span * 0.78)
	var cursor := -span * 0.5
	var cuts: Array = []
	for z in piece_z:
		cuts.append([z - gap * 0.5, z + gap * 0.5])
	cuts.append([span * 0.5, span * 0.5])
	for cut in cuts:
		var seg: float = cut[0] - cursor
		if seg > 0.1:
			mb.box(Vector3(west_x, slab + h * 0.5, cursor + seg * 0.5), Vector3(th, h, seg), earth.lightened(0.02), stone.darkened(0.1))
			mb.box(Vector3(west_x, slab + h * 0.34, cursor + seg * 0.5), Vector3(th + 0.12, h * 0.5, seg - 0.1), stone, stone.darkened(0.3))  # gaviones al pie
		cursor = cut[1]
	mb.box(Vector3(0.0, slab + h * 0.5, -d * 0.5 + th * 0.5 + 0.4), Vector3(w - 2.4, h, th), earth.lightened(0.02), stone.darkened(0.1))
	mb.box(Vector3(0.0, slab + h * 0.5, d * 0.5 - th * 0.5 - 0.4), Vector3(w - 2.4, h, th), earth.lightened(0.02), stone.darkened(0.1))
	mb.box(Vector3(0.0, slab + h * 0.3, -d * 0.5 + th * 0.5 + 0.4), Vector3(w - 2.3, h * 0.5, th + 0.12), stone, stone.darkened(0.3))
	mb.box(Vector3(0.0, slab + h * 0.3, d * 0.5 - th * 0.5 - 0.4), Vector3(w - 2.3, h * 0.5, th + 0.12), stone, stone.darkened(0.3))
	for k in range(pieces):  # una pieza por cañonera, apuntando al oeste (−X), el tubo apenas levantado
		mb.push()
		mb.move(Vector3(west_x + 1.0, slab, float(piece_z[k])))
		mb.turn_y(90.0)
		add_cannon(mb, 2.0, 1.0)
		mb.pop()
	mb.box(Vector3(w * 0.5 - 3.6, slab + 0.6, -d * 0.5 + 3.4), Vector3(2.4, 1.2, 1.8), wood, wood.darkened(0.3))  # cajones de munición
	mb.box(Vector3(w * 0.5 - 3.6, slab + 1.35, -d * 0.5 + 3.4), Vector3(2.0, 0.3, 1.6), wood.lightened(0.1))
	mb.box(Vector3(w * 0.5 - 6.2, slab + 0.45, -d * 0.5 + 3.0), Vector3(1.2, 0.9, 1.2), wood.lightened(0.06))
	for k in range(5):  # pila de balas
		mb.ball(Vector3(w * 0.5 - 4.0 + float(k % 3) * 0.34, slab + 0.2 + float(k / 3) * 0.3, d * 0.5 - 3.2), 0.17, 0.17, 0.17, 6, 3, iron)
	# abrigo de tropa contra el parapeto norte: un tinglado bajo de tablas con techo de una agua (1,8 m sobre la losa)
	mb.box(Vector3(-2.0, slab + 0.9, -d * 0.5 + 3.2), Vector3(5.0, 1.8, 0.2), wood, wood.darkened(0.2))
	for px in [-4.6, 0.6]:
		mb.beam(Vector3(px, slab, -d * 0.5 + 1.6), Vector3(px, slab + 1.7, -d * 0.5 + 1.6), 0.2, wood)
		mb.beam(Vector3(px, slab, -d * 0.5 + 4.6), Vector3(px, slab + 1.7, -d * 0.5 + 4.6), 0.2, wood)
	mb.box(Vector3(-2.0, slab + 1.82, -d * 0.5 + 3.0), Vector3(5.8, 0.16, 3.6), pc("paja"), pc("paja").darkened(0.2))


# ---------------------------------------------------------------------------------------------------------------------
# Casas del núcleo: azotea con pretil o dos aguas de paja

## Una casa de adobe de `w × d` m (w sobre X) y `h` m de pared. `style`: 0 azotea encalada con pretil, 1 dos aguas de paja, 2 azotea de barro.
## `door_z` = +1 o −1: de qué lado (sobre Z) da la puerta. `tone` (0..1) corre el color de la pared entre adobe y cal.
func add_house(mb: MB, w: float, d: float, h: float, style: int, door_z: float, tone: float, roof_id: String = "") -> void:
	var wall := pc("adobe").lerp(pc("cal_envejecida"), clampf(tone, 0.0, 1.0))
	var wood := pc("madera_oscura")
	var roof_flat := pc("cal_envejecida", 0.98) if style == 0 else pc("adobe", 1.05)
	var roof_gable := pc(roof_id if roof_id != "" else "paja")
	mb.box(Vector3(0.0, h * 0.5 - 0.1, 0.0), Vector3(w, h + 0.2, d), wall, pc("adobe").darkened(0.3).lerp(wall, 0.3))
	if style == 1:
		mb.gable(Vector3(0.0, h, 0.0), w + 0.9, d + 0.9, minf(d * 0.3, 1.5), roof_gable, wall.darkened(0.05), wood.darkened(0.3))
	else:
		mb.box(Vector3(0.0, h + 0.1, 0.0), Vector3(w + 0.3, 0.22, d + 0.3), roof_flat, roof_flat.darkened(0.15))
		var pet := 0.38
		mb.box(Vector3(0.0, h + 0.38, d * 0.5 + 0.1), Vector3(w + 0.3, pet, 0.22), wall.lightened(0.04), wall.darkened(0.1))
		mb.box(Vector3(0.0, h + 0.38, -d * 0.5 - 0.1), Vector3(w + 0.3, pet, 0.22), wall.lightened(0.04), wall.darkened(0.1))
		mb.box(Vector3(w * 0.5 + 0.1, h + 0.38, 0.0), Vector3(0.22, pet, d), wall.lightened(0.04), wall.darkened(0.1))
		mb.box(Vector3(-w * 0.5 - 0.1, h + 0.38, 0.0), Vector3(0.22, pet, d), wall.lightened(0.04), wall.darkened(0.1))
	var dz := door_z * (d * 0.5 + 0.03)
	mb.box(Vector3(0.0, 0.95, dz), Vector3(0.95, 1.9, 0.14), wood, wood.darkened(0.25))
	if w > 6.0:
		mb.box(Vector3(w * 0.28, h * 0.62, dz), Vector3(0.6, 0.55, 0.12), wood.darkened(0.35))
		mb.box(Vector3(-w * 0.28, h * 0.62, dz), Vector3(0.6, 0.55, 0.12), wood.darkened(0.35))


## La casa del cura (el cuartel): un cuerpo largo de cal con dos alas que cierran el patio de 8 × 8 m, aspilleras en el muro de la calle y techo de paja a dos aguas.
func add_cura_house(mb: MB, w: float, d: float, h: float) -> void:
	var wall := pc("cal_envejecida")
	var adobe := pc("adobe")
	var wood := pc("madera_oscura")
	var roof := pc("paja")
	var body_d := d * 0.46
	var back_z := -d * 0.5 + body_d * 0.5  # el cuerpo largo contra el fondo (norte)
	mb.box(Vector3(0.0, h * 0.5 - 0.1, back_z), Vector3(w, h + 0.2, body_d), wall, adobe.darkened(0.2))
	mb.gable(Vector3(0.0, h, back_z), w + 1.0, body_d + 1.0, 1.5, roof, wall.darkened(0.05), wood.darkened(0.3))
	for side in [-1.0, 1.0]:  # las dos alas sobre el patio
		var wing_w := 6.0
		mb.box(Vector3(side * (w * 0.5 - wing_w * 0.5), h * 0.5 - 0.1, d * 0.5 - (d - body_d) * 0.5), Vector3(wing_w, h + 0.2, d - body_d), wall, adobe.darkened(0.2))
		mb.gable(Vector3(side * (w * 0.5 - wing_w * 0.5), h, d * 0.5 - (d - body_d) * 0.5), wing_w + 1.0, d - body_d + 0.8, 1.3, roof, wall.darkened(0.05), wood.darkened(0.3))
	mb.box(Vector3(0.0, 1.1, d * 0.5 - 0.1), Vector3(w - 12.0, 2.2, 0.5), adobe, adobe.darkened(0.2))  # muro del patio sobre la calle
	mb.box(Vector3(0.0, 1.2, d * 0.5 - 0.05), Vector3(2.4, 2.4, 0.7), wood.darkened(0.1))  # portón
	for k in range(5):  # aspilleras: ranuras oscuras en el muro de la calle
		mb.box(Vector3(-w * 0.5 + 3.0 + float(k) * (w - 6.0) / 4.0, h * 0.55, back_z + body_d * 0.5 + 0.02), Vector3(0.18, 0.7, 0.12), wood.darkened(0.55))


# ---------------------------------------------------------------------------------------------------------------------
# Figuras: los tres arquetipos más el realista; cada parte sale en su propia malla con casco de contorno

## La variante de ropa por defecto de un arquetipo de `humahuaca_visual.json: units` (entrada de `archetypes` o `realista_1817`): camisa = inner_color, abrigo o pantalón = outer_color,
## sombrero = hat_color y acento = accent_color (ids de paleta).
func archetype_variant(spec: Dictionary) -> Dictionary:
	return {"camisa": str(spec.get("inner_color", "lino_crudo")), "abrigo": str(spec.get("outer_color", "lana_parda")), "sombrero": str(spec.get("hat_color", "madera_oscura")),
		"acento": str(spec.get("accent_color", "")) if str(spec.get("accent_color", "")) in ["azul_elegido", "rojo_reservado", "verde_elegido", "borgona_hipotetica"] else ""}


## Variante de ropa de la figura número `index` (sin uniformar; un acento rojo o verde cada seis, ≤ 15 % de la figura).
func variant_for(index: int, variants: Array) -> Dictionary:
	if variants.is_empty():
		return {"camisa": "lino_crudo", "abrigo": "lana_parda", "sombrero": "madera_oscura", "acento": ""}
	return (variants[index % variants.size()] as Dictionary)


## Las partes (constructores sin armar) de una figura: {parte: MB}. `id` ∈ poncho_sombrero, camisa_gorra, artillero, realista_1817. Altura ≈ 1,75 m, mira a −Z.
## `pose`: "de_pie" o "agachado". `variant`: {camisa, abrigo, sombrero, acento} (ids de paleta; ver humahuaca_visual.json: units.variants).
func figure_parts(id: String, variant: Dictionary, pose: String = "de_pie") -> Dictionary:
	match id:
		"camisa_gorra":
			return _fig_camisa_gorra(variant, false)
		"artillero":
			return _fig_artillero(variant)
		"realista_1817":
			return _fig_camisa_gorra(variant, true)
	if pose == "agachado":
		return _fig_agachado(variant)
	return _fig_poncho_sombrero(variant, false)


## Devuelve {parte: ArrayMesh}, cada parte con su casco de contorno de `hull_w` m (0 = sin contorno).
func figure(id: String, variant: Dictionary, pose: String = "de_pie", hull_w: float = 0.028) -> Dictionary:
	var parts := figure_parts(id, variant, pose)
	var out := {}
	for key in parts:
		out[key] = (parts[key] as MB).build(hull_w)
	return out


## La figura entera en UNA malla (los defensores y las figuras chicas: un nodo por cuerpo).
func figure_single(id: String, variant: Dictionary, hull_w: float = 0.028) -> ArrayMesh:
	var mb := MB.new()
	var parts := figure_parts(id, variant, "de_pie")
	for key in parts:
		mb.absorb(parts[key])
	return mb.build(hull_w)


func _skin() -> Color:
	return pc("cuero", 1.25)


func _fig_poncho_sombrero(v: Dictionary, crouched: bool) -> Dictionary:
	var poncho := MB.new()
	var skin := MB.new()
	var hat := MB.new()
	var gear := MB.new()
	var coat := pc(str(v.get("abrigo", "lana_parda"))).darkened(0.46)
	var hat_c := pc(str(v.get("sombrero", "madera_oscura"))).darkened(0.2)
	var accent := pc(str(v.get("acento", "")), 1.0) if str(v.get("acento", "")) != "" else pc("azul_elegido")
	var k := 0.62 if crouched else 1.0  # agachado: el cuerpo baja y se achata
	for sx in [-0.11, 0.11]:  # botas y pantalón, apenas se ven bajo el poncho
		gear.box(Vector3(sx, 0.4 * k, 0.0), Vector3(0.17, 0.8 * k, 0.2), pc("madera_oscura").lerp(coat, 0.3))
		gear.box(Vector3(sx, 0.07, -0.04), Vector3(0.18, 0.14, 0.3), pc("cuero"))
	poncho.frustum(Vector3(0.0, 0.62 * k, 0.0), 1.0, 0.78, 0.46, 0.34, 0.84 * k, coat, coat.darkened(0.22))  # el poncho: campana desde los hombros
	poncho.frustum(Vector3(0.0, 0.58 * k, 0.0), 1.04, 0.82, 1.0, 0.78, 0.08, accent)  # la guarda del borde, el acento de color
	poncho.frustum(Vector3(0.0, 1.3 * k, 0.0), 0.46, 0.34, 0.3, 0.24, 0.22, coat.lightened(0.1))  # el cuello
	skin.ball(Vector3(0.0, 1.62 * k, 0.0), 0.12, 0.14, 0.12, 8, 5, _skin())
	hat.cyl(Vector3(0.0, 1.72 * k, 0.0), 0.56 * (0.82 if crouched else 1.0), 0.52 * (0.82 if crouched else 1.0), 0.05, 12, hat_c, hat_c.darkened(0.2))  # ala ancha
	hat.cyl(Vector3(0.0, 1.74 * k, 0.0), 0.22, 0.17, 0.22, 10, hat_c.lightened(0.05), hat_c)  # copa
	hat.box(Vector3(0.0, 1.78 * k, 0.0), Vector3(0.36, 0.05, 0.36), accent)  # cinta
	if not crouched:  # una lanza corta en la mano de abajo del poncho
		gear.beam(Vector3(0.36, 0.1, -0.1), Vector3(0.42, 1.95, -0.1), 0.045, pc("madera_oscura"))
		gear.cyl_between(Vector3(0.42, 1.95, -0.1), Vector3(0.43, 2.2, -0.1), 0.05, 0.0, 6, pc("hierro"))
	return {"poncho": poncho, "piel": skin, "sombrero": hat, "equipo": gear}



## Una figura agachada de reconocedor (poncho, sombrero y carabina): el cuerpo se tira hacia adelante (−Z) y la cabeza asoma por delante, así que desde arriba se lee
## como una persona y no como una torre de cúpula (la campana con ala ancha de pie se parecía a una torre redonda).
func _fig_agachado(v: Dictionary) -> Dictionary:
	var poncho := MB.new()
	var skin := MB.new()
	var hat := MB.new()
	var gear := MB.new()
	var coat := pc(str(v.get("abrigo", "lana_parda")))
	var hat_c := pc(str(v.get("sombrero", "madera_oscura")))
	var accent := pc(str(v.get("acento", ""))) if str(v.get("acento", "")) != "" else pc("azul_elegido")
	poncho.frustum(Vector3(0.0, 0.0, 0.1), 0.95, 1.25, 0.6, 0.7, 0.62, coat, coat.darkened(0.22))  # el poncho tirado sobre la espalda
	poncho.frustum(Vector3(0.0, 0.0, 0.1), 0.99, 1.29, 0.95, 1.25, 0.07, accent)  # la guarda del borde
	poncho.ball(Vector3(0.0, 0.66, 0.2), 0.34, 0.26, 0.34, 8, 4, coat.lightened(0.05))  # la espalda encorvada
	for sx in [-1.0, 1.0]:  # las rodillas, hacia adelante
		gear.ball(Vector3(sx * 0.2, 0.3, -0.5), 0.17, 0.2, 0.2, 6, 3, pc("madera_oscura").lerp(coat, 0.3))
	skin.ball(Vector3(0.0, 0.78, -0.42), 0.12, 0.14, 0.12, 8, 5, _skin())
	hat.push()
	hat.xf = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-18.0)), Vector3(0.0, 0.0, 0.0))
	hat.cyl(Vector3(0.0, 0.92, -0.4), 0.46, 0.43, 0.05, 12, hat_c, hat_c.darkened(0.2))  # el ala, caída hacia adelante
	hat.cyl(Vector3(0.0, 0.94, -0.4), 0.2, 0.15, 0.2, 10, hat_c.lightened(0.05), hat_c)
	hat.pop()
	gear.beam(Vector3(0.25, 0.55, 0.15), Vector3(0.25, 0.62, -1.0), 0.06, pc("madera_oscura"))  # la carabina apuntando adelante
	gear.beam(Vector3(0.25, 0.62, -1.0), Vector3(0.25, 0.65, -1.4), 0.035, pc("hierro"))
	return {"poncho": poncho, "piel": skin, "sombrero": hat, "equipo": gear}

func _fig_camisa_gorra(v: Dictionary, royalist: bool) -> Dictionary:
	var cloth := MB.new()
	var skin := MB.new()
	var cap := MB.new()
	var gear := MB.new()
	var arms := MB.new()
	var shirt := pc(str(v.get("camisa", "lino_crudo")))
	var trousers := pc(str(v.get("abrigo", "lana_parda")))
	var cap_c := pc(str(v.get("sombrero", "azul_elegido")))
	var accent := pc(str(v.get("acento", ""))) if str(v.get("acento", "")) != "" else pc("cuero")
	if royalist and str(v.get("acento", "")) == "":
		accent = pc("borgona_hipotetica")
	for sx in [-0.11, 0.11]:
		cloth.box(Vector3(sx, 0.42, 0.0), Vector3(0.2, 0.84, 0.24), trousers, trousers.darkened(0.12))
		gear.box(Vector3(sx, 0.07, -0.05), Vector3(0.19, 0.14, 0.32), pc("cuero").lightened(0.1))
	cloth.box(Vector3(0.0, 1.12, 0.0), Vector3(0.58, 0.66, 0.32), shirt, shirt.darkened(0.08))  # camisa
	cloth.box(Vector3(0.0, 0.83, 0.0), Vector3(0.6, 0.1, 0.34), pc("lana_parda") if royalist else pc("cuero", 1.2))  # el cinto
	if royalist:  # el realista lleva una banda cruzada de acento (≤ 15 % de la figura)
		cloth.beam(Vector3(-0.22, 1.4, -0.15), Vector3(0.22, 0.92, -0.15), 0.07, accent, 0.03)
	skin.ball(Vector3(0.0, 1.6, 0.0), 0.12, 0.14, 0.12, 8, 5, _skin())
	cap.cyl(Vector3(0.0, 1.66, 0.0), 0.15, 0.16, 0.13, 10, cap_c, cap_c.darkened(0.1))  # gorra
	cap.box(Vector3(0.0, 1.69, -0.17), Vector3(0.22, 0.03, 0.14), cap_c.darkened(0.2))  # visera
	for sx in [-1.0, 1.0]:  # brazos: uno adelante y otro atrás del fusil
		arms.beam(Vector3(sx * 0.27, 1.38, 0.0), Vector3(sx * 0.2, 0.98, -0.3), 0.11, shirt.darkened(0.06))
	gear.box(Vector3(0.18, 0.86, 0.1), Vector3(0.2, 0.22, 0.12), pc("cuero"))  # cartuchera
	var stock := pc("madera_oscura")
	gear.beam(Vector3(0.2, 1.0, -0.05), Vector3(0.12, 1.75, -0.52), 0.07, stock)  # el fusil al hombro, de culata a cañón
	gear.beam(Vector3(0.12, 1.75, -0.52), Vector3(0.05, 2.15, -0.75), 0.04, pc("hierro"))
	gear.cyl_between(Vector3(0.05, 2.15, -0.75), Vector3(0.03, 2.4, -0.82), 0.025, 0.0, 6, pc("hierro"))  # la bayoneta
	return {"ropa": cloth, "piel": skin, "sombrero": cap, "equipo": gear, "brazos": arms}


func _fig_artillero(v: Dictionary) -> Dictionary:
	var cloth := MB.new()
	var skin := MB.new()
	var cap := MB.new()
	var gear := MB.new()
	var apron := MB.new()
	var shirt := pc(str(v.get("camisa", "lana_natural")))
	var trousers := pc("hierro", 1.15)
	var apron_c := pc(str(v.get("abrigo", "cuero")))
	for sx in [-0.11, 0.11]:
		cloth.box(Vector3(sx, 0.42, 0.0), Vector3(0.18, 0.84, 0.22), trousers, trousers.darkened(0.2))
		gear.box(Vector3(sx, 0.07, -0.05), Vector3(0.19, 0.14, 0.32), pc("cuero").darkened(0.35))
	cloth.box(Vector3(0.0, 1.12, 0.0), Vector3(0.52, 0.64, 0.32), shirt, shirt.darkened(0.15))
	apron.box(Vector3(0.0, 1.16, 0.0), Vector3(0.58, 0.5, 0.36), apron_c.lightened(0.3), apron_c.lightened(0.05))  # el chaleco de cuero que le tapa casi toda la camisa
	apron.box(Vector3(0.0, 0.98, -0.18), Vector3(0.44, 0.78, 0.06), apron_c, apron_c.darkened(0.35))  # el delantal de cuero
	apron.box(Vector3(0.0, 1.42, -0.17), Vector3(0.36, 0.1, 0.05), apron_c)
	skin.ball(Vector3(0.0, 1.6, 0.0), 0.12, 0.14, 0.12, 8, 5, _skin())
	cap.cyl(Vector3(0.0, 1.67, 0.0), 0.15, 0.13, 0.15, 10, pc(str(v.get("sombrero", "lana_parda"))), pc(str(v.get("sombrero", "lana_parda"))).darkened(0.15))
	for sx in [-1.0, 1.0]:
		cloth.beam(Vector3(sx * 0.28, 1.38, 0.0), Vector3(sx * 0.22, 1.0, -0.42), 0.12, shirt.darkened(0.08))
	# el atacador: asta larga con la esponja en la punta, cruzada por delante
	gear.beam(Vector3(-0.3, 0.55, 0.3), Vector3(0.28, 1.7, -0.62), 0.05, pc("madera_oscura"))
	gear.cyl_between(Vector3(0.28, 1.7, -0.62), Vector3(0.36, 1.9, -0.72), 0.13, 0.13, 8, pc("lana_parda"))
	gear.box(Vector3(0.0, 0.84, 0.0), Vector3(0.54, 0.1, 0.34), pc("cuero"))
	return {"ropa": cloth, "piel": skin, "sombrero": cap, "equipo": gear, "delantal": apron}


## El caballo de la ficha de Rodríguez con su jinete de poncho y sombrero. Devuelve {parte: ArrayMesh}.
func rider(variant: Dictionary, hull_w: float = 0.04) -> Dictionary:
	var animal := MB.new()
	var gear := MB.new()
	var coat := pc("lana_parda").lerp(pc("cuero"), 0.4)
	var dark := pc("madera_oscura")
	for lx in [-0.2, 0.2]:  # patas
		for lz in [-0.72, 0.7]:
			animal.cyl(Vector3(lx, 0.0, lz), 0.07, 0.1, 0.95, 6, dark.lerp(coat, 0.3))
			animal.box(Vector3(lx, 0.04, lz - 0.02), Vector3(0.14, 0.09, 0.18), dark.darkened(0.3))
	animal.box(Vector3(0.0, 1.2, 0.0), Vector3(0.62, 0.62, 1.7), coat, coat.darkened(0.2))  # el cuerpo
	animal.ball(Vector3(0.0, 1.2, -0.85), 0.31, 0.31, 0.26, 8, 4, coat)
	animal.ball(Vector3(0.0, 1.18, 0.85), 0.31, 0.31, 0.27, 8, 4, coat.darkened(0.04))
	animal.beam(Vector3(0.0, 1.4, -0.9), Vector3(0.0, 1.95, -1.25), 0.3, coat, 0.28)  # el cuello
	animal.box(Vector3(0.0, 2.04, -1.5), Vector3(0.2, 0.26, 0.5), coat.darkened(0.04))  # la cabeza
	animal.box(Vector3(0.0, 1.98, -1.78), Vector3(0.17, 0.17, 0.12), coat.darkened(0.25))  # el hocico
	animal.box(Vector3(0.0, 2.2, -1.33), Vector3(0.05, 0.12, 0.1), dark)  # las orejas, de a una
	animal.box(Vector3(0.0, 1.96, -1.12), Vector3(0.06, 0.4, 0.16), dark)  # la crin
	animal.beam(Vector3(0.0, 1.35, 0.95), Vector3(0.0, 0.75, 1.15), 0.09, dark, 0.14)  # la cola
	gear.box(Vector3(0.0, 1.55, 0.05), Vector3(0.7, 0.1, 0.62), pc("lana_natural"))  # la manta
	gear.box(Vector3(0.0, 1.62, 0.05), Vector3(0.5, 0.12, 0.46), pc("cuero"))  # la montura
	for sx in [-1.0, 1.0]:  # estribos
		gear.beam(Vector3(sx * 0.36, 1.5, 0.05), Vector3(sx * 0.36, 1.05, 0.05), 0.04, pc("cuero"))
	var man := _fig_poncho_sombrero(variant, false)
	var out := {}
	out["animal"] = animal.build(hull_w)
	out["equipo"] = gear.build(hull_w)
	for key in man:
		var part: MB = man[key]
		var seat := MB.new()
		seat.xf = Transform3D(Basis.IDENTITY, Vector3(0.0, 1.0, 0.05))
		seat.absorb(part)
		out["jinete_" + str(key)] = seat.build(hull_w)
	return out


## La mula cargada del arreo: aparejo de cuero, dos bultos y un rollo. Devuelve {parte: ArrayMesh}.
func mule(hull_w: float = 0.04) -> Dictionary:
	var animal := MB.new()
	var pack := MB.new()
	var load_a := MB.new()
	var load_b := MB.new()
	var roll := MB.new()
	var coat := pc("lana_parda")
	var dark := pc("madera_oscura")
	for lx in [-0.17, 0.17]:
		for lz in [-0.5, 0.5]:
			animal.cyl(Vector3(lx, 0.0, lz), 0.05, 0.075, 0.82, 6, dark.lerp(coat, 0.35))
	animal.box(Vector3(0.0, 1.0, 0.0), Vector3(0.52, 0.52, 1.4), coat, coat.darkened(0.2))
	animal.ball(Vector3(0.0, 1.0, -0.7), 0.26, 0.27, 0.22, 8, 4, coat)
	animal.ball(Vector3(0.0, 1.0, 0.7), 0.26, 0.27, 0.22, 8, 4, coat.darkened(0.05))
	animal.beam(Vector3(0.0, 1.15, -0.75), Vector3(0.0, 1.6, -1.05), 0.24, coat, 0.22)
	animal.box(Vector3(0.0, 1.68, -1.25), Vector3(0.17, 0.22, 0.44), coat.darkened(0.04))
	animal.box(Vector3(-0.07, 1.95, -1.1), Vector3(0.05, 0.38, 0.1), dark)  # las orejas largas de la mula
	animal.box(Vector3(0.07, 1.95, -1.1), Vector3(0.05, 0.38, 0.1), dark)
	animal.beam(Vector3(0.0, 1.15, 0.72), Vector3(0.0, 0.6, 0.85), 0.06, dark, 0.1)
	pack.box(Vector3(0.0, 1.32, 0.0), Vector3(0.7, 0.14, 0.95), pc("cuero"), pc("cuero").darkened(0.3))  # el aparejo
	pack.box(Vector3(0.0, 1.0, 0.0), Vector3(0.74, 0.06, 0.2), pc("cuero").lightened(0.1))  # la cincha
	load_a.box(Vector3(-0.5, 1.58, 0.0), Vector3(0.5, 0.62, 0.8), pc("lana_natural"), pc("lana_natural").darkened(0.25))
	load_a.box(Vector3(-0.5, 1.9, 0.0), Vector3(0.42, 0.06, 0.72), pc("cuero"))
	load_b.box(Vector3(0.5, 1.58, 0.0), Vector3(0.5, 0.62, 0.8), pc("cuero", 1.15), pc("cuero").darkened(0.25))
	load_b.box(Vector3(0.5, 1.9, 0.0), Vector3(0.42, 0.06, 0.72), pc("lana_natural"))
	roll.cyl_between(Vector3(0.0, 1.78, -0.45), Vector3(0.0, 1.78, 0.45), 0.2, 0.2, 8, pc("lino_crudo"))
	roll.box(Vector3(0.0, 1.78, -0.1), Vector3(0.44, 0.07, 0.06), pc("cuero"))
	return {"animal": animal.build(hull_w), "equipo": pack.build(hull_w), "carga_izq": load_a.build(hull_w), "carga_der": load_b.build(hull_w), "carga_rollo": roll.build(hull_w)}


# ---------------------------------------------------------------------------------------------------------------------
# Vegetación, rocas y bultos

## Churqui: un arbusto espinoso de 1,2 a 2,2 m, hecho de varias gotas de ramaje (para MultiMesh con escala y giro al azar).
func bush(seed_value: int = 1) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mb := MB.new()
	var green := pc("churqui")
	for k in range(4):
		var a := rng.randf() * TAU
		var r := 0.15 + rng.randf() * 0.5
		var tone := green.lerp(pc("sedimento_humedo"), rng.randf() * 0.25).darkened(0.1 + rng.randf() * 0.2)
		mb.ball(Vector3(cos(a) * r, 0.5 + rng.randf() * 0.5, sin(a) * r), 0.55 + rng.randf() * 0.35, 0.5 + rng.randf() * 0.45, 0.55 + rng.randf() * 0.35, 6, 3, tone, tone.darkened(0.35))
	for k in range(2):  # ramas secas que asoman
		var a2 := rng.randf() * TAU
		mb.beam(Vector3(0.0, 0.3, 0.0), Vector3(cos(a2) * 0.9, 0.9 + rng.randf() * 0.6, sin(a2) * 0.9), 0.06, pc("madera_oscura").lerp(green, 0.3))
	return mb.build()


## Cardón: columna de 3 a 5 m con costillas y uno o dos brazos que suben.
func cactus(seed_value: int = 1) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mb := MB.new()
	var green := pc("verde_elegido").lerp(pc("churqui"), 0.5)
	mb.cyl(Vector3.ZERO, 0.33, 0.27, 4.2, 8, green, green.darkened(0.25))
	mb.ball(Vector3(0.0, 4.2, 0.0), 0.27, 0.2, 0.27, 8, 3, green.lightened(0.05))
	for sign_ in [-1.0, 1.0]:
		if rng.randf() < 0.75:
			var y0 := 1.6 + rng.randf() * 1.0
			var tip := Vector3(sign_ * (0.9 + rng.randf() * 0.3), y0 + 0.9 + rng.randf() * 0.9, rng.randf() * 0.3)
			mb.cyl_between(Vector3(sign_ * 0.2, y0, 0.0), Vector3(sign_ * 0.8, y0, 0.0), 0.16, 0.15, 6, green)
			mb.cyl_between(Vector3(sign_ * 0.8, y0, 0.0), tip, 0.16, 0.13, 6, green)
	return mb.build()


## Sauce criollo de 6 a 8 m: tronco, copa ancha y cortinas de ramaje que cuelgan (el monte ribereño de la foto de 1923, sin álamos).
func willow(seed_value: int = 1) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mb := MB.new()
	var green := pc("vegetacion_irrigada").lerp(pc("churqui"), 0.3)
	mb.cyl(Vector3.ZERO, 0.4, 0.25, 4.0, 7, pc("madera_oscura"), pc("madera_oscura").darkened(0.3))
	mb.beam(Vector3(0.0, 3.0, 0.0), Vector3(1.4, 4.4, 0.4), 0.22, pc("madera_oscura"))
	mb.beam(Vector3(0.0, 3.2, 0.0), Vector3(-1.2, 4.6, -0.5), 0.2, pc("madera_oscura"))
	for k in range(5):
		var a := rng.randf() * TAU
		var r := 0.6 + rng.randf() * 1.6
		var tone := green.darkened(rng.randf() * 0.18)
		mb.ball(Vector3(cos(a) * r, 5.6 + rng.randf() * 1.3, sin(a) * r), 2.3 + rng.randf() * 0.8, 1.5 + rng.randf() * 0.5, 2.3 + rng.randf() * 0.8, 7, 4, tone, tone.darkened(0.35))
	for k in range(7):  # las ramas que cuelgan
		var a3 := TAU * float(k) / 7.0 + rng.randf() * 0.4
		mb.cyl(Vector3(cos(a3) * 2.6, 2.4 + rng.randf() * 0.5, sin(a3) * 2.6), 0.5, 0.0, 3.0, 5, green.darkened(0.12), green.darkened(0.3))
	return mb.build()


## Roca de pocas caras (octaedro subdividido y movido al azar), de 0,8 a 1,6 m.
func rock(seed_value: int = 1) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mb := MB.new()
	var stone := pc("piedra_gris").darkened(rng.randf() * 0.18)
	var pts: Array = []
	for j in range(1, 3):
		for k in range(6):
			var a := TAU * float(k) / 6.0 + float(j) * 0.4
			var radius := (0.55 if j == 1 else 0.7) * (0.8 + rng.randf() * 0.4)
			pts.append(Vector3(cos(a) * radius, 0.45 * float(j) - 0.1, sin(a) * radius))
	var top := Vector3(0.0, 1.0 + rng.randf() * 0.3, 0.0)
	var bottom := Vector3(0.0, -0.1, 0.0)
	for k in range(6):
		var k2 := (k + 1) % 6
		mb.tri(bottom, pts[k], pts[k2], stone.darkened(0.25))
		mb.quad(pts[k], pts[6 + k], pts[6 + k2], pts[k2], stone.darkened(0.08))
		mb.tri(pts[6 + k], top, pts[6 + k2], stone.lightened(0.1))
	return mb.build()


## Un barril de pólvora, un cajón, un bulto de cuero o un saco (las cargas de las posta y de las mulas). `kind` ∈ barril, cajon, bulto, saco.
func prop(kind: String, seed_value: int = 1) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mb := MB.new()
	match kind:
		"barril":
			mb.cyl(Vector3.ZERO, 0.28, 0.3, 0.85, 8, pc("madera_oscura").lightened(0.12), pc("madera_oscura"))
			for y in [0.18, 0.62]:
				mb.cyl(Vector3(0.0, y, 0.0), 0.31, 0.31, 0.06, 8, pc("hierro"))
		"cajon":
			mb.box(Vector3(0.0, 0.3, 0.0), Vector3(0.9, 0.6, 0.55), pc("madera_oscura").lightened(0.08))
			mb.box(Vector3(0.0, 0.62, 0.0), Vector3(0.92, 0.06, 0.58), pc("cuero"))
		"saco":
			mb.ball(Vector3(0.0, 0.3, 0.0), 0.34, 0.32, 0.26, 7, 4, pc("lana_natural"), pc("lana_natural").darkened(0.25))
		_:
			mb.box(Vector3(0.0, 0.25, 0.0), Vector3(0.9, 0.5, 0.4), pc("cuero", 1.1), pc("cuero").darkened(0.3))
			mb.box(Vector3(0.0, 0.28, 0.0), Vector3(0.94, 0.08, 0.44), pc("lana_natural"))
	return mb.build()


## La altura del vértice más alto de una malla (la prueba de anacronismos mira la geometría y no solo el nombre del nodo: el templo no pasa de 8 m).
func mesh_top(mesh: ArrayMesh) -> float:
	var top := -1.0e9
	for s in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(s)
		for p in (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			top = maxf(top, p.y)
	return top


# ---------------------------------------------------------------------------------------------------------------------
# Conjuntos de la posta y del parque de artillería

## Una carreta de dos ruedas con su caja de tablas (la posta carga y descarga; la foto de 1923 la sugiere solo como analogía tardía: se rotula diseño).
func add_cart(mb: MB, cargo: bool) -> void:
	var wood := pc("madera_oscura")
	mb.box(Vector3(0.0, 0.85, 0.0), Vector3(1.5, 0.12, 2.6), wood.lightened(0.06), wood.darkened(0.2))
	for sx in [-0.72, 0.72]:
		mb.box(Vector3(sx, 1.15, 0.0), Vector3(0.08, 0.5, 2.6), wood)
		mb.cyl_between(Vector3(sx + signf(sx) * 0.1, 0.62, 0.0), Vector3(sx + signf(sx) * 0.2, 0.62, 0.0), 0.62, 0.62, 10, wood.lightened(0.04))
	mb.beam(Vector3(0.0, 0.8, 1.2), Vector3(0.0, 0.55, 3.4), 0.1, wood)
	if cargo:
		mb.box(Vector3(0.0, 1.3, -0.1), Vector3(1.2, 0.7, 1.7), pc("cuero", 1.1), pc("cuero").darkened(0.3))
		mb.box(Vector3(0.0, 1.7, -0.1), Vector3(1.0, 0.12, 1.5), pc("lana_natural"))


## Un cerco bajo de palos y travesaños alrededor de un rectángulo `w × d` (corral): postes cada 2,4 m y dos travesaños.
func add_fence_ring(mb: MB, w: float, d: float, height: float) -> void:
	var wood := pc("madera_oscura").lightened(0.1)
	var corners := [Vector3(-w * 0.5, 0.0, -d * 0.5), Vector3(w * 0.5, 0.0, -d * 0.5), Vector3(w * 0.5, 0.0, d * 0.5), Vector3(-w * 0.5, 0.0, d * 0.5)]
	for k in range(4):
		var a: Vector3 = corners[k]
		var b: Vector3 = corners[(k + 1) % 4]
		var parts := maxi(int(round(a.distance_to(b) / 2.4)), 1)
		for i in range(parts):
			var p0 := a.lerp(b, float(i) / float(parts))
			mb.box(p0 + Vector3(0.0, height * 0.5, 0.0), Vector3(0.14, height, 0.14), wood, wood.darkened(0.3))
		mb.beam(a + Vector3(0.0, height * 0.82, 0.0), b + Vector3(0.0, height * 0.82, 0.0), 0.07, wood)
		mb.beam(a + Vector3(0.0, height * 0.45, 0.0), b + Vector3(0.0, height * 0.45, 0.0), 0.07, wood)


## El parque de artillería de la posta: cuatro piezas en fila con sus cajones y un montón de balas (los cañones de a 4 y de a 2 del parte).
func add_parque(mb: MB, w: float, d: float) -> void:
	var wood := pc("madera_oscura")
	for k in range(4):
		mb.push()
		mb.move(Vector3(-w * 0.5 + (float(k) + 0.5) * w / 4.0, 0.0, 0.0))
		mb.turn_y(180.0 if k % 2 == 0 else 160.0)
		add_cannon(mb, 1.8 if k < 2 else 1.5, 0.9)
		mb.pop()
	mb.box(Vector3(0.0, 0.4, d * 0.5 - 0.7), Vector3(1.4, 0.8, 0.8), wood.lightened(0.08), wood.darkened(0.2))
	mb.box(Vector3(2.0, 0.4, d * 0.5 - 0.7), Vector3(1.0, 0.8, 0.8), wood.lightened(0.04), wood.darkened(0.2))
	for k in range(6):
		mb.ball(Vector3(-2.6 + float(k % 3) * 0.34, 0.17 + float(k / 3) * 0.3, d * 0.5 - 0.8), 0.16, 0.16, 0.16, 6, 3, pc("hierro"))
