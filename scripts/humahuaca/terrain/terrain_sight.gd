extends RefCounted
## Línea de visión de HumahuacaTerrain (CONTRATO 3.1: `los`). Dueña: relieve_mapa. Sobre RELIEVE, tapias y edificios: la recta de visión va de la
## altura de los ojos de A (suelo + eye_a) a la de B (suelo + eye_b) y la tapa lo que se le cruza por encima de esa recta:
##   1. el terreno (se lee height_at cada `STEP_M` metros: el cerro tapa, la plataforma ve sobre el llano). Quien está parado en una PLATAFORMA de
##      diseño (la de la batería: llana, con parapeto y troneras) ve por encima de su propio borde: no se cuenta el tramo de la recta que pasa sobre la
##      plataforma y su talud (si no, desde el centro de una losa de 28 × 18 m no se vería nada a menos de 140 m; el desnivel de 12 m es justamente
##      lo que el diseño pide que dé la ventaja de vista);
##   2. las tapias y barricadas (cota del suelo en el cruce + alto del muro; un portillo abierto deja pasar);
##   3. los edificios de los hitos (cota del suelo en su centro + alto; quien está adentro de uno lo ignora: la torre ve hacia afuera).
## Es la única implementación de la visión del nivel. Una prueba compara el resultado con y sin cada rasgo (rasgos verticales con consecuencia).

const STEP_M := 3.0  # paso de muestreo del terreno sobre la recta; la quebradita más angosta mide 8 m
const MARGIN_M := 0.05  # el suelo tiene que pasar de la recta por este margen para taparla (sin parpadeos por redondeo)


static func los(t, a: Vector2, b: Vector2, eye_a: float, eye_b: float, open_gaps: Array, heights: PackedFloat32Array = PackedFloat32Array()) -> bool:
	var dist := a.distance_to(b)
	if dist < 0.001:
		return true
	var ha: float = _ground(t, a.x, a.y, heights) + eye_a
	var hb: float = _ground(t, b.x, b.y, heights) + eye_b
	var n := maxi(2, ceili(dist / STEP_M))
	var plat_a: Variant = _platform_at(t, a)
	var plat_b: Variant = _platform_at(t, b)
	for k in range(1, n):
		var s := float(k) / float(n)
		var gx := a.x + (b.x - a.x) * s
		var gz := a.y + (b.y - a.y) * s
		if plat_a != null and _on_platform(plat_a, gx, gz, true):
			continue
		if plat_b != null and _on_platform(plat_b, gx, gz, true):
			continue
		if _ground(t, gx, gz, heights) > ha + (hb - ha) * s + MARGIN_M:
			return false
	var open_ids: Array = t._open_ids(open_gaps) if not open_gaps.is_empty() else []
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y))
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y))
	for w in t._walls:
		var wa: Vector2 = w[0]
		var wb: Vector2 = w[1]
		if maxf(wa.x, wb.x) < lo.x or minf(wa.x, wb.x) > hi.x or maxf(wa.y, wb.y) < lo.y or minf(wa.y, wb.y) > hi.y:
			continue
		var hit := _seg_hit(a, b, wa, wb)
		if hit.x < 0.0:
			continue
		var hx := a.x + (b.x - a.x) * hit.x
		var hz := a.y + (b.y - a.y) * hit.x
		var top := _ground(t, hx, hz, heights) + float(w[2])
		if ha + (hb - ha) * hit.x >= top:
			continue
		if t._gate_open_at(int(w[3]), float(w[4]) + hit.y * float(w[5]), open_ids):
			continue
		return false
	for bx in t._boxes:
		var poly: PackedVector2Array = bx["poly"]
		if Geometry2D.is_point_in_polygon(a, poly) or Geometry2D.is_point_in_polygon(b, poly):
			continue
		var t_in := 2.0
		var t_out := -1.0
		for k in range(poly.size()):
			var edge_hit := _seg_hit(a, b, poly[k], poly[(k + 1) % poly.size()])
			if edge_hit.x >= 0.0:
				t_in = minf(t_in, edge_hit.x)
				t_out = maxf(t_out, edge_hit.x)
		if t_out < 0.0:
			continue
		var top_abs: float = float(bx["ground"]) + float(bx["h"])
		if ha + (hb - ha) * t_in < top_abs or ha + (hb - ha) * t_out < top_abs:
			return false
	return true


## La plataforma de diseño (de `t._platforms`) sobre la que está el punto, o null.
static func _platform_at(t, p: Vector2) -> Variant:
	for pl in t._platforms:
		if _on_platform(pl, p.x, p.y, false):
			return pl
	return null


## ¿El punto cae sobre la plataforma (con su talud si `with_slope`)? La plataforma es un rectángulo girado: {center, ca, sa, half_l, half_w, falloff}.
static func _on_platform(pl: Dictionary, x: float, z: float, with_slope: bool) -> bool:
	var dx := x - float(pl["cx"])
	var dz := z - float(pl["cz"])
	var u := dx * float(pl["ca"]) + dz * float(pl["sa"])
	var v := -dx * float(pl["sa"]) + dz * float(pl["ca"])
	var extra := float(pl["falloff"]) if with_slope else 0.5
	return absf(u) <= float(pl["half_l"]) + extra and absf(v) <= float(pl["half_w"]) + extra


## La cota del suelo: height_at de la clase o, si se pasa una malla (`heights`, de 4 m con el origen en (0, 0)), la lectura bilineal de esa malla.
static func _ground(t, x: float, z: float, heights: PackedFloat32Array) -> float:
	if heights.is_empty():
		return t.height_at(x, z)
	return t._hf_lookup(heights, x, z)


## Cruce de dos segmentos: (t sobre a→b, u sobre c→d) o (−1, −1).
static func _seg_hit(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> Vector2:
	var r := b - a
	var s := d - c
	var den := r.cross(s)
	if absf(den) < 0.000001:
		return Vector2(-1.0, -1.0)
	var ca := c - a
	var tt := ca.cross(s) / den
	var u := ca.cross(r) / den
	if tt < 0.0 or tt > 1.0 or u < 0.0 or u > 1.0:
		return Vector2(-1.0, -1.0)
	return Vector2(tt, u)
