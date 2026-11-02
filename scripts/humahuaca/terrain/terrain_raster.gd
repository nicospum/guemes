extends RefCounted
## Rasterizado de HumahuacaTerrain (CONTRATO 2.2, 2.2b y 3.1): superficies, muros, portillos y edificios sobre la malla de 4 m. Dueña: relieve_mapa.
## Todo se rasteriza UNA vez al hornear; las consultas leen arreglos empaquetados. Son funciones estáticas que reciben la instancia `t` de la clase
## (`humahuaca_terrain.gd`) y escriben en sus arreglos (_surf, _solid, _walls, ...). Una vez horneado, esta clase no se vuelve a llamar.
##
## Orden de las superficies (gana la prioridad más alta; las capas del mapa traen la suya y las de los rasgos del nivel son fijas):
## reglas del relieve 20–24 < irrigado 50 < patio 55 < camino 60 < sedimento 62 < zanja 65 < agua 70 < muro 90 (las tapias son siempre `muro`).
## Los portillos cerrados dejan un hueco de suelo («camino») que el paso cruza solo si el portillo está abierto (is_blocked / open_gaps).
##
## Convenciones del paso (nav_grid): el nodo (i, j) está en x = i·4, z = j·4 y manda en ±2 m; las paredes se rasterizan como línea fina (sin saltos en
## diagonal: una pared no se cruza por una esquina). `weight` es el multiplicador de costo de cruzar el nodo (1 / velocidad en seco); los sólidos valen 1.
## Simplificaciones declaradas: las manzanas, el camino cubierto (solo su suelo) y los edificios de los hitos no son sólidos para el paso (sí tapan la vista).

const VT = preload("res://scripts/humahuaca/terrain/vocab_terrain.gd")
const Relief = preload("res://scripts/humahuaca/terrain/terrain_relief.gd")

const WALL_H_M := 2.0  # alto de una tapia sin `height_m`
const BARRICADE_H_M := 1.6
const GATE_ALONG_MIN_M := 3.0  # el hueco de un portillo mide al menos esto a lo largo de la tapia (un nodo si es chico)
const GATE_ACROSS_M := 3.2  # y esto a lo ancho: libera el nodo de la tapia en cualquier orientación
const BOX_TYPES := ["hito", "objetivo", "edificio", "torre"]  # los hitos de estos tipos con altura tapan la vista
const PRIO_IRRIGADO := 50
const PRIO_PATIO := 55
const PRIO_CAMINO := 60
const PRIO_ZANJA := 65


# ---------------------------------------------------------------------------------------------------------------------
# Superficies

static func bake_surfaces(t) -> void:
	var ops: Array = []  # [prioridad, orden, id de superficie, nodos]
	var sid: Dictionary = t._sid
	for layer in t._map_layers:
		var cls := str((layer as Dictionary).get("class", ""))
		if not sid.has(cls):
			continue
		var nodes := _layer_nodes(t, layer)
		if nodes.size() > 0:
			ops.append([int(layer.get("priority", 10)), ops.size(), int(sid[cls]), nodes])
	ops.append([PRIO_IRRIGADO, ops.size(), int(sid["irrigado"]), _polys_nodes(t, t._raw_features("parcela", "A"))])
	ops.append([PRIO_PATIO, ops.size(), int(sid["patio"]), _polys_nodes(t, t._raw_features("patio", "A"))])
	ops.append([PRIO_PATIO, ops.size(), int(sid["patio"]), _zones_nodes(t)])
	ops.append([PRIO_CAMINO, ops.size(), int(sid["camino"]), _strokes_nodes(t, t._raw_features("calle", "A"), 4.0)])
	ops.append([PRIO_CAMINO, ops.size(), int(sid["camino"]), _strokes_nodes(t, t._raw_features("camino", "A"), 2.5)])
	ops.append([PRIO_CAMINO, ops.size(), int(sid["camino"]), _strokes_nodes(t, t._raw_features("camino_cubierto", "A"), 2.5)])
	ops.append([PRIO_ZANJA, ops.size(), int(sid["zanja"]), _strokes_nodes(t, t._raw_features("zanja", "A"), 0.0)])
	ops.append([PRIO_ZANJA, ops.size(), int(sid["zanja"]), _strokes_nodes(t, t._raw_features("acequia", "A"), 0.0)])
	ops.sort_custom(func(a, b): return int(a[0]) < int(b[0]) or (int(a[0]) == int(b[0]) and int(a[1]) < int(b[1])))
	var surf: PackedByteArray = t._surf
	var solid: PackedByteArray = t._solid
	for op in ops:
		var id := int(op[2])
		for idx in (op[3] as PackedInt32Array):
			if solid[idx] == 0:
				surf[idx] = id


## Los nodos que pinta una capa de superficie del mapa (`surfaces.layers[]`): `poly`, `line` (propia o la traza del río) o `rule` del relieve.
static func _layer_nodes(t, layer: Dictionary) -> PackedInt32Array:
	var kind := str(layer.get("kind", ""))
	match kind:
		"poly":
			return _poly_nodes(t, t._pts(layer.get("pts", [])))
		"line":
			if str(layer.get("from", "")) == "river":
				return _river_nodes(t, float(layer.get("width_factor", 1.0)))
			var width := float(layer.get("width_m", 2.0))
			return _stroke_nodes(t, t._pts(layer.get("pts", [])), width * 0.5)
		"rule":
			return _rule_nodes(t, layer.get("rule", {}))
	return PackedInt32Array()


## Nodos del lecho (factor 1,0: sedimento) o del agua (0,5): a menos del semiancho × factor del eje del río (la distancia sale de la talla del cauce).
static func _river_nodes(t, factor: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	var dist: PackedFloat32Array = t._rd
	var half: PackedFloat32Array = t._rhw
	if dist.is_empty():
		return out
	for idx in range(dist.size()):
		if dist[idx] <= half[idx] * factor and half[idx] > 0.0:
			out.append(idx)
	return out


static func _rule_nodes(t, rule: Variant) -> PackedInt32Array:
	var out := PackedInt32Array()
	if not (rule is Dictionary):
		return out
	var r: Dictionary = rule
	var nx: int = t.nx
	var nz: int = t.nz
	var cell: float = t.cell_m
	match str(r.get("type", "")):
		"slope_deg":
			var thr := tan(deg_to_rad(float(r.get("min_deg", 8.0))))
			var grad: PackedFloat32Array = t._grad
			var solid: PackedByteArray = t._solid
			for idx in range(nx * nz):
				if grad[idx] >= thr and solid[idx] == 0:
					out.append(idx)
		"ring":
			var info: Dictionary = t._layer_info(str(r.get("layer", "")))
			if info.is_empty():
				return out
			var c: Vector2 = info["center"]
			var r_min := float(r.get("r_min_m", 0.0))
			var r_max := float(r.get("r_max_m", 50.0))
			var patch := float(r.get("patch_cell_m", 0.0))
			var thr_p := float(r.get("patch_threshold", 0.0))
			var seed_p := int(r.get("patch_seed", 1))
			for j in range(maxi(0, floori((c.y - r_max) / cell)), mini(nz - 1, ceili((c.y + r_max) / cell)) + 1):
				for i in range(maxi(0, floori((c.x - r_max) / cell)), mini(nx - 1, ceili((c.x + r_max) / cell)) + 1):
					var x := float(i) * cell
					var z := float(j) * cell
					var d := Vector2(x - c.x, z - c.y).length()
					if d < r_min or d > r_max:
						continue
					if patch > 0.0 and value_noise(x, z, patch, seed_p) < thr_p:
						continue
					out.append(j * nx + i)
		"layer_area":
			var info2: Dictionary = t._layer_info(str(r.get("layer", "")))
			if info2.is_empty():
				return out
			var c2: Vector2 = info2["center"]
			var length := float(info2.get("length_m", 10.0))
			var width := float(info2.get("width_m", 8.0))
			var ang := deg_to_rad(float(info2.get("yaw_deg", 0.0)))
			var ca := cos(ang)
			var sa := sin(ang)
			var reach := 0.5 * length + width
			for j in range(maxi(0, floori((c2.y - reach) / cell)), mini(nz - 1, ceili((c2.y + reach) / cell)) + 1):
				for i in range(maxi(0, floori((c2.x - reach) / cell)), mini(nx - 1, ceili((c2.x + reach) / cell)) + 1):
					var dx := float(i) * cell - c2.x
					var dz := float(j) * cell - c2.y
					var u := dx * ca + dz * sa
					var v := -dx * sa + dz * ca
					if absf(u) <= length * 0.5 and absf(v) <= width * 0.5 + cell * 0.5:
						out.append(j * nx + i)
	return out


## Ruido de valor determinista en [0, 1): esquinas de una grilla de `cell` m con hash entero, interpoladas con suavidad (manchas de arbustos).
static func value_noise(x: float, z: float, cell: float, seed_value: int) -> float:
	var fx := x / cell
	var fz := z / cell
	var ix := floori(fx)
	var iz := floori(fz)
	var tx := fx - float(ix)
	var tz := fz - float(iz)
	tx = tx * tx * (3.0 - 2.0 * tx)
	tz = tz * tz * (3.0 - 2.0 * tz)
	var a := _hash01(ix, iz, seed_value)
	var b := _hash01(ix + 1, iz, seed_value)
	var c := _hash01(ix, iz + 1, seed_value)
	var d := _hash01(ix + 1, iz + 1, seed_value)
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)


static func _hash01(ix: int, iz: int, seed_value: int) -> float:
	var n := (ix * 73856093) ^ (iz * 19349663) ^ (seed_value * 83492791)
	n = (n ^ (n >> 13)) & 0x7FFFFFFF
	n = (n * 1274126177) & 0x7FFFFFFF
	n = (n ^ (n >> 16)) & 0x7FFFFFFF
	return float(n & 0xFFFF) / 65536.0


static func _polys_nodes(t, feats: Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for f in feats:
		out.append_array(_poly_nodes(t, t._pts((f as Dictionary).get("poly", []))))
	return out


static func _zones_nodes(t) -> PackedInt32Array:
	var out := PackedInt32Array()
	var zones: Variant = t._level.get("zones", [])
	if not (zones is Array):
		return out
	for z in zones:  # corrales, polvorines y parques son suelo apisonado; las demás zonas son de reglas y no cambian el suelo
		if z is Dictionary and ["corral", "polvorin", "parque"].has(str((z as Dictionary).get("kind", ""))):
			out.append_array(_poly_nodes(t, t._pts((z as Dictionary).get("poly", []))))
	return out


static func _strokes_nodes(t, feats: Array, default_width_m: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	for f in feats:
		var width := float((f as Dictionary).get("width_m", default_width_m))
		out.append_array(_stroke_nodes(t, t._pts((f as Dictionary).get("pts", [])), width * 0.5))
	return out


## Nodos que toca un trazo: la línea fina (sin saltos en diagonal, para que una pared no se pueda cruzar por una esquina) y, si es ancho,
## todos los nodos a menos de `half_w` del eje.
static func _stroke_nodes(t, pts: PackedVector2Array, half_w: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	var cell: float = t.cell_m
	var nx: int = t.nx
	var imax: int = t._imax
	var jmax: int = t._jmax
	if pts.size() == 1:
		out.append(t._node_index(pts[0].x, pts[0].y))
	for k in range(pts.size() - 1):
		var a := pts[k]
		var b := pts[k + 1]
		var steps := maxi(1, ceili(a.distance_to(b) / (cell * 0.25)))
		var pi := -1
		var pj := -1
		for s in range(steps + 1):
			var p := a.lerp(b, float(s) / float(steps))
			var i := clampi(roundi(p.x / cell), 0, imax)
			var j := clampi(roundi(p.y / cell), 0, jmax)
			if pi >= 0 and i != pi and j != pj:
				out.append(pj * nx + i)
				out.append(j * nx + pi)
			out.append(j * nx + i)
			pi = i
			pj = j
		if half_w > cell * 0.5:
			for j in range(maxi(0, ceili((minf(a.y, b.y) - half_w) / cell)), mini(jmax, floori((maxf(a.y, b.y) + half_w) / cell)) + 1):
				for i in range(maxi(0, ceili((minf(a.x, b.x) - half_w) / cell)), mini(imax, floori((maxf(a.x, b.x) + half_w) / cell)) + 1):
					var q := Vector2(float(i) * cell, float(j) * cell)
					if q.distance_to(Geometry2D.get_closest_point_to_segment(q, a, b)) <= half_w:
						out.append(j * nx + i)
	return out


## Nodos cuyo centro cae dentro del polígono.
static func _poly_nodes(t, poly: PackedVector2Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	if poly.size() < 3:
		return out
	var cell: float = t.cell_m
	var nx: int = t.nx
	var lo := poly[0]
	var hi := poly[0]
	for p in poly:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	for j in range(maxi(0, ceili(lo.y / cell)), mini(int(t._jmax), floori(hi.y / cell)) + 1):
		for i in range(maxi(0, ceili(lo.x / cell)), mini(int(t._imax), floori(hi.x / cell)) + 1):
			if Geometry2D.is_point_in_polygon(Vector2(float(i) * cell, float(j) * cell), poly):
				out.append(j * nx + i)
	return out


# ---------------------------------------------------------------------------------------------------------------------
# Muros, portillos y edificios

static func bake_walls(t) -> void:
	var walls_by_id := {}
	for f in t._raw_features("tapia", "A"):
		var pts: PackedVector2Array = t._pts(f.get("pts", []))
		if pts.size() >= 2:
			walls_by_id[str(f.get("id", "tapia_%d" % walls_by_id.size()))] = _add_wall(t, pts, float(f.get("height_m", WALL_H_M)))
	for f in t._raw_features("barricada", "A"):
		var pts2: PackedVector2Array = t._pts(f.get("pts", []))
		if pts2.size() >= 2:
			_add_wall(t, pts2, BARRICADE_H_M)
	var n_gates := 0
	for f in t._raw_features("portillo", "A"):
		if _carve_gate(t, f, walls_by_id, n_gates):
			n_gates += 1
	t._counts["tapias"] = walls_by_id.size()
	t._counts["portillos"] = n_gates


## Registra una pared opaca y sólida: sus segmentos para la visión y sus nodos para el paso. Devuelve su índice.
static func _add_wall(t, pts: PackedVector2Array, height_m: float) -> int:
	var wi: int = t._wall_gates.size()
	t._wall_gates.append([])
	var arc := 0.0
	for k in range(pts.size() - 1):
		var seg_len := pts[k].distance_to(pts[k + 1])
		t._walls.append([pts[k], pts[k + 1], height_m, wi, arc, seg_len])
		arc += seg_len
	var s_muro: int = t._sid["muro"]
	var solid: PackedByteArray = t._solid
	var surf: PackedByteArray = t._surf
	for idx in _stroke_nodes(t, pts, 0.0):
		solid[idx] = 1
		surf[idx] = s_muro
	return wi


## Abre un hueco en la tapia que cita `f.tapia` en `f.at` (fracción de 0 a 1 o metros desde el inicio; también acepta x/z propios).
static func _carve_gate(t, f: Dictionary, walls_by_id: Dictionary, n: int) -> bool:
	var wall_id := str(f.get("tapia", ""))
	if not walls_by_id.has(wall_id):
		return false
	var wi: int = walls_by_id[wall_id]
	var width := float(f.get("width_m", 2.5))
	var is_open := str(f.get("state", "cerrado")) == "abierto"
	var at_arc := 0.0
	var total := 0.0
	var center := Vector2.ZERO
	var dir := Vector2.RIGHT
	var found := false
	for w in t._walls:
		if int(w[3]) == wi:
			total = float(w[4]) + float(w[5])
	var at: Variant = f.get("at", 0.5)
	var has_pos := f.has("x") and f.has("z")
	var pos := Vector2(float(f["x"]), float(f["z"])) if has_pos else Vector2.ZERO
	if not has_pos and (at is Dictionary or at is Array):
		pos = t._pt(at)
		has_pos = true
	if has_pos:  # una posición propia: se proyecta sobre la tapia
		var best := INF
		for w in t._walls:
			if int(w[3]) != wi:
				continue
			var q := Geometry2D.get_closest_point_to_segment(pos, w[0], w[1])
			if pos.distance_to(q) < best:
				best = pos.distance_to(q)
				center = q
				at_arc = float(w[4]) + (w[0] as Vector2).distance_to(q)
				dir = ((w[1] as Vector2) - (w[0] as Vector2)).normalized()
				found = true
	else:  # una distancia a lo largo de la tapia: fracción de 0 a 1, o metros desde el inicio
		var s := clampf(float(at) * total if float(at) <= 1.0 else float(at), 0.0, total)
		at_arc = s
		for w in t._walls:
			if int(w[3]) == wi and s >= float(w[4]) - 0.0001 and s <= float(w[4]) + float(w[5]) + 0.0001:
				dir = ((w[1] as Vector2) - (w[0] as Vector2)).normalized()
				center = (w[0] as Vector2) + dir * (s - float(w[4]))
				found = true
				break
	if not found:
		return false
	var id := str(f.get("id", "portillo_%d" % n))
	t._gates[id] = center
	(t._wall_gates[wi] as Array).append([id, at_arc - width * 0.5, at_arc + width * 0.5, is_open])
	var cell: float = t.cell_m
	var nx: int = t.nx
	var along_lim := maxf(width * 0.5, GATE_ALONG_MIN_M)
	var s_camino: int = t._sid["camino"]
	var solid: PackedByteArray = t._solid
	var surf: PackedByteArray = t._surf
	for j in range(maxi(0, floori((center.y - along_lim - GATE_ACROSS_M) / cell)), mini(int(t._jmax), ceili((center.y + along_lim + GATE_ACROSS_M) / cell)) + 1):
		for i in range(maxi(0, floori((center.x - along_lim - GATE_ACROSS_M) / cell)), mini(int(t._imax), ceili((center.x + along_lim + GATE_ACROSS_M) / cell)) + 1):
			var rel := Vector2(float(i) * cell, float(j) * cell) - center
			if absf(rel.dot(dir)) > along_lim or absf(rel.cross(dir)) > GATE_ACROSS_M:
				continue
			var idx := j * nx + i
			if solid[idx] == 0:
				continue
			surf[idx] = s_camino
			if is_open:
				solid[idx] = 0
			else:
				t._gate_of_node[idx] = id
	return true


## Edificios de los hitos que tapan la vista: polígono de la huella (VP-03: `w` sobre +x y `d` sobre +z ANTES de girar `yaw_deg`, giro horario visto
## en el mapa) y su alto. Se guarda también la cota del suelo en el centro: el techo de un edificio es esa cota más su alto.
static func bake_boxes(t) -> void:
	for lm in t._landmarks:
		var d: Dictionary = lm
		if not BOX_TYPES.has(str(d.get("type", ""))) or float(d.get("height_m", 0.0)) <= 0.0:
			continue
		var poly := footprint_poly(d)
		if poly.size() >= 3:
			t._boxes.append({"id": str(d["id"]), "poly": poly, "h": float(d["height_m"]),
				"ground": t.height_at(float(d["x"]), float(d["z"]))})


## Polígono de la huella de un hito: `{w, d}` rectángulo, `{r}` octógono, `{poly}` tal cual. Esquinas = centro + R(yaw)·(±w/2, ±d/2).
static func footprint_poly(lm: Dictionary) -> PackedVector2Array:
	var fp: Variant = lm.get("footprint", {})
	var c := Vector2(float(lm.get("x", 0.0)), float(lm.get("z", 0.0)))
	var yaw := deg_to_rad(float(lm.get("yaw_deg", 0.0)))
	var poly := PackedVector2Array()
	if not (fp is Dictionary):
		return poly
	var f: Dictionary = fp
	if f.get("poly", null) is Array:
		var pts := PackedVector2Array()
		for p in f["poly"]:
			pts.append(Vector2(float((p as Dictionary).get("x", 0.0)), float((p as Dictionary).get("z", 0.0))))
		return pts
	if f.has("w") and f.has("d"):
		var hw := float(f["w"]) * 0.5
		var hd := float(f["d"]) * 0.5
		for corner in [Vector2(-hw, -hd), Vector2(hw, -hd), Vector2(hw, hd), Vector2(-hw, hd)]:
			poly.append(c + (corner as Vector2).rotated(yaw))
	elif f.has("r"):
		for k in range(8):
			poly.append(c + Vector2(float(f["r"]), 0.0).rotated(TAU * float(k) / 8.0))
	return poly


# ---------------------------------------------------------------------------------------------------------------------
# Pendiente, velocidad y malla de rutas

## Gradiente por nodo (diferencias centrales de un nodo a cada lado) y factor de velocidad por pendiente: 1 hasta `start_deg`, después
## 1 − per_deg·(grados − start_deg), con piso `floor` (surfaces.slope_penalty). Cuenta las celdas con pendiente ≥ 8°.
static func bake_slopes(t) -> void:
	var nx: int = t.nx
	var nz: int = t.nz
	var h: PackedFloat32Array = t._h
	var grad: PackedFloat32Array = t._grad
	var slopef: PackedFloat32Array = t._slopef
	var cell: float = t.cell_m
	var start_deg: float = t._slope_start_deg
	var start_tan: float = tan(deg_to_rad(start_deg))
	var per_deg: float = t._slope_per_deg
	var floor_f: float = t._slope_floor
	var tan8: float = tan(deg_to_rad(8.0))
	var steep := 0
	var cells := 0
	var jmax: int = t._jmax
	var imax: int = t._imax
	for j in range(nz):
		var jm: int = maxi(j - 1, 0) * nx
		var jp: int = mini(j + 1, nz - 1) * nx
		var base: int = j * nx
		var span_z: float = float(mini(j + 1, nz - 1) - maxi(j - 1, 0)) * cell
		for i in range(nx):
			var im: int = maxi(i - 1, 0)
			var ip: int = mini(i + 1, nx - 1)
			var gx: float = (h[base + ip] - h[base + im]) / (float(ip - im) * cell)
			var gz: float = (h[jp + i] - h[jm + i]) / span_z
			var g: float = sqrt(gx * gx + gz * gz)
			grad[base + i] = g
			if i <= imax and j <= jmax:
				cells += 1
				if g >= tan8:
					steep += 1
			if g > start_tan:
				var deg := rad_to_deg(atan(g))
				slopef[base + i] = maxf(floor_f, 1.0 - per_deg * (deg - start_deg))
			else:
				slopef[base + i] = 1.0
	t._counts["celdas_ventana"] = cells
	t._counts["celdas_pendiente_8"] = steep
	t._slope_pct_ge8 = 100.0 * float(steep) / maxf(float(cells), 1.0)


## Multiplicador de costo por nodo: 1 / (velocidad en seco de la superficie × factor de pendiente); los sólidos valen 1,0 (no se cruzan).
static func bake_nav(t) -> void:
	var by_surface := PackedFloat32Array()
	for sidx in range(VT.SURFACES.size()):
		by_surface.append(1.0 / maxf(t._speed_for(sidx, 0.0), 0.05))
	var weight: PackedFloat32Array = t._weight
	var solid: PackedByteArray = t._solid
	var surf: PackedByteArray = t._surf
	var slopef: PackedFloat32Array = t._slopef
	for idx in range(weight.size()):
		weight[idx] = 1.0 if solid[idx] == 1 else by_surface[surf[idx]] / maxf(slopef[idx], 0.05)
