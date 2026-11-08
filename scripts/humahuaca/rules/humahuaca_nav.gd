extends RefCounted
## Navegación de las reglas del nivel «humahuaca» (CONTRATO 3.1 y 3.2: rutas, velocidad, plan_route). Dueña: reglas_historia.
## Arma una grilla A* (AStarGrid2D, que corre en C++) con lo que el terreno entrega en nav_grid(): celdas sólidas (muros, tapias sin portillo, agua honda) y el
## costo de cruzar cada celda (1 / velocidad: el barro, el riego y las zanjas cuestan). Es estática (portillos cerrados): la comparten todas las partidas que
## usan el mismo terreno. Presupuestos del contrato 5.1: armado (`nav_build_ms`) ≤ 80 ms y una ruta (plan_route) ≤ 30 ms; los mide test_hx_rules desde afuera
## (esta capa no lee el reloj del sistema: las reglas son deterministas).
## La ruta que devuelve find_path() es la de A* con los tramos rectos fusionados: una polilínea corta de puntos de mundo (x, z), no una celda por paso.
## Independencia (V19): no importa nada; el terreno lo recibe por parámetro.

const SAMPLE_STEP := 0.35  # fracción de celda entre dos muestras al comprobar que un tramo recto es transitable
const FREE_SEARCH_RADIUS := 4  # celdas: hasta dónde se busca una celda libre si el punto pedido cae en un muro

static var _by_terrain: Dictionary = {}  # id de instancia del terreno → Nav

var nx := 0
var nz := 0
var cell := 4.0
var origin := Vector2.ZERO
var solid_cells := 0

var _astar: AStarGrid2D = null
var _solid := PackedByteArray()
var _weight := PackedFloat32Array()
var _variants: Dictionary = {}  # clave → grilla con rodeo (avoiding)
var _imax := 0  # la última columna y fila de la región del mapa (las del terreno); cell_of no sale de ahí
var _jmax := 0
const VARIANTS_MAX := 16

## La grilla del terreno `t` (con caché por terreno). null si el terreno no entrega nav_grid().
static func for_terrain(t: RefCounted) -> RefCounted:
	if t == null:
		return null
	var key := t.get_instance_id()
	if not _by_terrain.has(key) or not is_instance_valid(_by_terrain[key]):
		var made: RefCounted = build(t)
		if made == null:
			return null
		_by_terrain[key] = made
	return _by_terrain[key]

## Arma una grilla nueva sin pasar por la caché (lo que mide `nav_build_ms` de las pruebas). null si el terreno no tiene nav_grid().
static func build(t: RefCounted) -> RefCounted:
	if t == null or not t.has_method("nav_grid"):
		return null
	var grid: Dictionary = (t.call("nav_grid") as Dictionary).duplicate()
	var size: Variant = t.get("size_m")
	if size is Vector2 and float(grid.get("cell", 0.0)) > 0.0:
		## la última fila y columna que el terreno usa (su `_node_index` sujeta a floori(tamaño / celda)): la grilla puede traer una más, sólida por estar
		## fuera de la ventana, y un punto del borde (z = 650) caía ahí (D-5)
		grid["imax"] = floori((size as Vector2).x / float(grid.cell))
		grid["jmax"] = floori((size as Vector2).y / float(grid.cell))
	var made: RefCounted = new()
	if not made.call("_load", grid):
		return null
	return made

func _load(grid: Dictionary) -> bool:
	nx = int(grid.get("nx", 0))
	nz = int(grid.get("nz", 0))
	_imax = clampi(int(grid.get("imax", nx - 1)), 0, maxi(nx - 1, 0))
	_jmax = clampi(int(grid.get("jmax", nz - 1)), 0, maxi(nz - 1, 0))
	cell = float(grid.get("cell", 4.0))
	origin = Vector2(float(grid.get("origin_x", 0.0)), float(grid.get("origin_z", 0.0)))
	var solid: Variant = grid.get("solid", null)
	var weight: Variant = grid.get("weight", null)
	if nx <= 1 or nz <= 1 or cell <= 0.0 or not (solid is PackedByteArray) or not (weight is PackedFloat32Array):
		return false
	_solid = solid
	_weight = weight
	if _solid.size() != nx * nz or _weight.size() != nx * nz:
		return false
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(0, 0, nx, nz)
	_astar.cell_size = Vector2(cell, cell)
	_astar.offset = origin
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	_astar.update()
	solid_cells = 0
	for idx in range(nx * nz):
		if _solid[idx] != 0:
			solid_cells += 1
			_astar.set_point_solid(Vector2i(idx % nx, idx / nx), true)
	## Los pesos se cargan por tramos de una fila con el mismo valor: son miles de celdas iguales y una llamada por celda sería lo más caro del armado.
	for j in range(nz):
		var i := 0
		while i < nx:
			var w := _weight[j * nx + i]
			var k := i + 1
			while k < nx and absf(_weight[j * nx + k] - w) < 0.001:
				k += 1
			if absf(w - 1.0) > 0.001 and w > 0.0:
				_astar.fill_weight_scale_region(Rect2i(i, j, k - i, 1), w)
			i = k
	return true

## La misma grilla con un costo extra (×`weight_mult`) en las celdas que caen dentro de algún círculo de `circles` ([{c: Vector2, r: float}]): la usan las rutas de
## antes de la señal para rodear lo que vigilan los centinelas (no cambia la velocidad de nadie, solo por dónde va la ruta). Caché por `key` (lo arma quien pide: los
## frentes y radios en juego), con un tope; sin círculos devuelve esta misma grilla. Determinista: depende solo de la grilla y de los círculos.
func avoiding(key: String, circles: Array, weight_mult: float) -> RefCounted:
	if circles.is_empty() or weight_mult <= 1.0 or _astar == null:
		return self
	if _variants.has(key):
		return _variants[key]
	if _variants.size() >= VARIANTS_MAX:
		_variants.clear()
	var w := _weight.duplicate()
	var marked := PackedByteArray()
	marked.resize(nx * nz)
	for c in circles:
		var ctr: Vector2 = c.c
		var r := float(c.r)
		var i0 := clampi(floori((ctr.x - r - origin.x) / cell), 0, nx - 1)
		var i1 := clampi(ceili((ctr.x + r - origin.x) / cell), 0, nx - 1)
		var j0 := clampi(floori((ctr.y - r - origin.y) / cell), 0, nz - 1)
		var j1 := clampi(ceili((ctr.y + r - origin.y) / cell), 0, nz - 1)
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				var idx := j * nx + i
				if marked[idx] != 0 or _solid[idx] != 0 or pos_of(Vector2i(i, j)).distance_to(ctr) > r:
					continue
				marked[idx] = 1
				w[idx] = maxf(w[idx], 1.0) * weight_mult
	var made: RefCounted = new()
	if not made.call("_load", {"nx": nx, "nz": nz, "cell": cell, "origin_x": origin.x, "origin_z": origin.y, "solid": _solid, "weight": w, "imax": _imax, "jmax": _jmax}):
		return self
	_variants[key] = made
	return made

# ---------------------------------------------------------------------------------------------------------------------
# Celdas y puntos

func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(clampi(roundi((p.x - origin.x) / cell), 0, _imax), clampi(roundi((p.y - origin.y) / cell), 0, _jmax))

func pos_of(c: Vector2i) -> Vector2:
	return Vector2(origin.x + float(c.x) * cell, origin.y + float(c.y) * cell)

func is_solid(c: Vector2i) -> bool:
	return c.x < 0 or c.y < 0 or c.x >= nx or c.y >= nz or _solid[c.y * nx + c.x] != 0

## ¿El punto cae en un muro?
func blocked_at(p: Vector2) -> bool:
	return is_solid(cell_of(p))

## Costo relativo de cruzar la celda (1 = suelo firme y seco).
func weight_at(p: Vector2) -> float:
	var c := cell_of(p)
	return _weight[c.y * nx + c.x]

## La celda libre más cercana a `c` (en anillos de hasta FREE_SEARCH_RADIUS); la misma si ya es libre. (-1, -1) si no hay ninguna.
func nearest_free(c: Vector2i) -> Vector2i:
	if not is_solid(c):
		return c
	for r in range(1, FREE_SEARCH_RADIUS + 1):
		var best := Vector2i(-1, -1)
		var best_d := 1.0e9
		for dj in range(-r, r + 1):
			for di in range(-r, r + 1):
				if maxi(absi(di), absi(dj)) != r:
					continue
				var cand := Vector2i(c.x + di, c.y + dj)
				if is_solid(cand):
					continue
				var d := float(di * di + dj * dj)
				if d < best_d:
					best_d = d
					best = cand
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)

# ---------------------------------------------------------------------------------------------------------------------
# Rutas

## La ruta de `a` a `b` como puntos de mundo, empezando en `a` y terminando en `b`. Vacía si no hay camino. Un destino sobre un muro (un lote dentro de un edificio) termina
## en la celda libre más cercana: nadie entra en un muro.
func find_path(a: Vector2, b: Vector2) -> Array:
	if _astar == null:
		return []
	var ca := nearest_free(cell_of(a))
	var cb := nearest_free(cell_of(b))
	if ca.x < 0 or cb.x < 0:
		return []
	var end := b if not is_solid(cell_of(b)) else pos_of(cb)  # nadie entra en un muro: un destino dentro de un edificio queda en la celda libre más cercana
	if ca == cb:
		return [a, end]
	var ids: Array[Vector2i] = _astar.get_id_path(ca, cb)
	if ids.size() < 2:
		return []
	var out: Array = [a]
	for p in _smooth(ids):
		out.append(p)
	out.append(end)
	return out

## ¿Hay camino entre dos puntos?
func reachable(a: Vector2, b: Vector2) -> bool:
	return not find_path(a, b).is_empty()

## Fusiona los tramos rectos de la ruta de A*: de cada vértice salta al más lejano al que se llega en línea recta sin cruzar un muro ni nada más caro de lo que la ruta
## ya cruzaba. Búsqueda binaria sobre los vértices (no hace falta el óptimo, solo una polilínea corta y sin zigzag).
func _smooth(ids: Array[Vector2i]) -> Array:
	var out: Array = []
	var n := ids.size()
	var i := 0
	while i < n - 1:
		var best := i + 1
		var hi := n - 1
		if _segment_ok(ids, i, hi):
			best = hi
		else:
			var lo := i + 2
			var top := hi - 1
			while lo <= top:
				var mid := (lo + top) / 2
				if _segment_ok(ids, i, mid):
					best = mid
					lo = mid + 1
				else:
					top = mid - 1
		out.append(pos_of(ids[best]))
		i = best
	return out

func _segment_ok(ids: Array[Vector2i], from_idx: int, to_idx: int) -> bool:
	var wmax := 0.0
	for k in range(from_idx, to_idx + 1):
		wmax = maxf(wmax, _weight[ids[k].y * nx + ids[k].x])
	return line_clear(pos_of(ids[from_idx]), pos_of(ids[to_idx]), wmax + 0.001)

## ¿Se puede ir en línea recta de `a` a `b` sin rozar un muro ni cruzar una celda de costo mayor que `max_weight`? Ninguno de los cuatro nodos que rodean a cada punto del
## tramo puede ser sólido (así una ruta alisada nunca pasa por la esquina de una celda de muro) y el nodo más cercano no puede costar más que `max_weight`.
func line_clear(a: Vector2, b: Vector2, max_weight: float = 1.0e9) -> bool:
	var d := a.distance_to(b)
	var steps := maxi(1, ceili(d / (cell * SAMPLE_STEP)))
	for s in range(steps + 1):
		var p := a.lerp(b, float(s) / float(steps))
		var fx := (p.x - origin.x) / cell
		var fz := (p.y - origin.y) / cell
		var i0 := clampi(floori(fx), 0, nx - 1)
		var i1 := clampi(ceili(fx), 0, nx - 1)
		var j0 := clampi(floori(fz), 0, nz - 1)
		var j1 := clampi(ceili(fz), 0, nz - 1)
		if _solid[j0 * nx + i0] != 0 or _solid[j0 * nx + i1] != 0 or _solid[j1 * nx + i0] != 0 or _solid[j1 * nx + i1] != 0:
			return false
		var near := clampi(roundi(fz), 0, nz - 1) * nx + clampi(roundi(fx), 0, nx - 1)
		if _weight[near] > max_weight:
			return false
	return true

## Largo de una polilínea de puntos de mundo.
static func length_of(pts: Array) -> float:
	var total := 0.0
	for k in range(pts.size() - 1):
		total += (pts[k] as Vector2).distance_to(pts[k + 1])
	return total

func stats() -> Dictionary:
	return {"nx": nx, "nz": nz, "cell_m": cell, "solid_cells": solid_cells}
