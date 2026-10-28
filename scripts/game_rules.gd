extends RefCounted
class_name GameRules
## Authoritative, presentation-independent, JSON-serializable rules.

const SAVE_VERSION := 1
const MAX_ROUNDS := 14
const SHIP := Vector2(16.0, 0.0)
const BOARD_POINT := Vector2(12.0, 0.0)
const STEP := 0.25
const RISE_START := 780.0
const RISE_DURATION := 120.0
## Ritmo del norte: la retirada realista solo es posible desde esta ronda y con esta presion acumulada (ver docs/BALANCE_NORTE.md).
const RETREAT_MIN_ROUND := 10
const RETREAT_MIN_PRESSURE := 7
## Ocupacion de Salta: fuente S4 y Ideario p. 40 la ubican el 15/4/1817, dentro de la ronda 10 (12-22 abr).
const SALTA_OCCUPATION_ROUND := 10
const DATES := ["15 dic 1816", "29 dic 1816", "12 ene 1817", "26 ene 1817", "9 feb 1817", "23 feb 1817", "1 mar 1817", "15 mar 1817", "29 mar 1817", "12 abr 1817", "22 abr 1817", "30 abr 1817", "4 may 1817", "5 may 1817"]
const CAMPAIGN_ACTIONS := ["move", "scout", "protect", "raid", "rest", "withdraw", "assault"]

var state: Dictionary = {}
var _events: Array = []
var _grid: AStarGrid2D
var _navigation_revision := -999

func new_game(scenario: String, seed_value: int = 1806) -> Dictionary:
	if scenario not in ["justine", "norte"]:
		scenario = "justine"
	state = {
		"schema_version": SAVE_VERSION, "game_id": _new_id(scenario), "state_version": 1,
		"scenario": scenario, "seed": seed_value, "rng_state": maxi(1, absi(seed_value) % 2147483647),
		"elapsed": 0.0, "accumulator": 0.0, "status": "playing", "reason": "", "round": 1,
		"units": [], "log": [], "orders": [], "external_decisions": [], "first_order_at": -1.0
	}
	_events = []
	_navigation_revision = -999
	if scenario == "justine":
		_setup_justine()
	else:
		_setup_norte()
	return state

func _new_id(scenario: String) -> String:
	return "%s-%d" % [scenario, Time.get_ticks_usec()]

func _unit(id: String, title: String, x: float, z: float, sector_id: String = "") -> Dictionary:
	return {"id": id, "name": title, "x": x, "z": z, "strength": 100.0, "fatigue": 0.0,
		"supply": 100.0, "mounted": true, "stage": "ready", "order": {}, "path": [],
		"sector_id": sector_id, "dismount_remaining": 0.0, "revealed_until": 0, "blocked_until": 0.0}

func _setup_justine() -> void:
	state.units = [_unit("guemes", "Güemes · vanguardia", -28, -3), _unit("arias", "Voluntarios de la ribera", -31, 3), _unit("zavala", "Reserva de caballería", -28, 10)]
	state.merge({"water_level": 0.95, "tide_phase": "alta", "capture": 0.0, "crew_morale": 100.0,
		"next_volley": 7.5, "deadline": 900.0, "bajante_announced": false, "rising_announced": false,
		"obstacles": [{"x": -32.0, "z": -16.0, "w": 6.0, "d": 7.0}, {"x": -23.0, "z": 21.0, "w": 5.0, "d": 6.0}, {"x": -15.0, "z": -19.0, "w": 5.0, "d": 5.0}],
		"historical_note": "Reconquista, 12 de agosto de 1806. La participación personal de Güemes es una atribución tradicional: esta misión la recrea. Rutas, efectivos y tiempos son adaptación jugable."})
	_event("Reconocé la ribera. La ruta central es corta y expuesta; el banco sur conserva mejor tus fuerzas.", "objective")

func _sector(id: String, title: String, x: float, z: float, neighbors: Array, known: bool, crates: int = 2) -> Dictionary:
	return {"id": id, "name": title, "x": x, "z": z, "neighbors": neighbors, "known": known,
		"intel_until": 0, "protected_until": 0, "crates": crates, "enemy": id in ["humahuaca", "quebrada", "oran"]}

func _setup_norte() -> void:
	state.sectors = [
		_sector("humahuaca", "Humahuaca", 5, -27, ["quebrada"], false, 1),
		_sector("quebrada", "Quebrada", -1, -21, ["humahuaca", "jujuy"], false, 1),
		_sector("jujuy", "Jujuy", 1, -13, ["quebrada", "salta", "oran", "lerma"], true, 2),
		_sector("salta", "Salta", 0, 8, ["jujuy", "lerma", "rosario"], true, 3),
		_sector("lerma", "Valle de Lerma", -7, 6, ["jujuy", "salta", "chicoana", "rosario"], true, 3),
		_sector("chicoana", "Chicoana", -9, 18, ["lerma", "rosario"], true, 3),
		_sector("oran", "Orán", 23, -12, ["jujuy"], false, 2),
		_sector("rosario", "Rosario de la Frontera", 8, 22, ["salta", "lerma", "chicoana"], true, 3)
	]
	state.units = [_unit("guemes", "Güemes", -7, 6, "lerma"), _unit("arias", "Manuel Eduardo Arias", 1, -13, "jujuy"), _unit("zavala", "Partida del valle", -9, 18, "chicoana")]
	state.merge({"enemy": {"supply": 88.0, "cohesion": 88.0, "communications": 90.0,
		"position": "quebrada", "occupied_salta": false, "intent": "forage"}, "population": 82.0,
		"stores": 65.0, "humahuaca": false, "pressure_actions": 0, "date": DATES[0], "last_results": [],
		"historical_note": "Campaña de 1816–1817. Las agrupaciones, rutas y cifras son una abstracción. Humahuaca se atribuye a Arias. El desenlace histórico fue la retirada realista a comienzos de mayo; tus resultados pueden producir otra cronología."})
	_event("Sostené a la población y cortá los abastecimientos. Ocupar Salta no decide por sí solo la campaña.", "objective")

func get_unit(id: String) -> Dictionary:
	for u in state.get("units", []):
		if u.id == id:
			return u
	return {}

func get_sector(id: String) -> Dictionary:
	for s in state.get("sectors", []):
		if s.id == id:
			return s
	return {}

func terrain_height_at(x: float, z: float) -> float:
	## Used directly by the renderer: exposed shoals and legal movement agree.
	## Rounded, slightly meandering banks replace rectangular terrain thresholds.
	## Full bank weights retain the original bed heights and the same route centers.
	var coast_x := -8.0 + sin(z * 0.20) * 0.60
	var land_height := 0.75 + clampf((coast_x - x) / 24.0, 0.0, 1.0) * 0.75 + sin(x * 0.15) * sin(z * 0.12) * 0.12
	var land_weight := 1.0 - smoothstep(coast_x - 0.8, coast_x + 0.8, x)
	var center_z := sin(x * 0.21) * 0.30
	var center_width := 4.8 + sin(x * 0.27) * 0.40 + cos(x * 0.63) * 0.10
	var center_distance := Vector2(maxf(0.0, x - 14.0), z - center_z).length()
	var center_weight := 1.0 - smoothstep(center_width - 0.8, center_width + 0.8, center_distance)
	var south_z := 14.5 + sin(x * 0.24) * 0.35
	var south_width := 3.8 + sin(x * 0.31 + 0.4) * 0.45
	var south_distance := Vector2(maxf(0.0, x - 12.5), z - south_z).length()
	var south_weight := 1.0 - smoothstep(south_width - 0.8, south_width + 0.8, south_distance)
	var bridge_x := 14.0 + sin(z * 0.40) * 0.25
	var bridge_width := 4.0 + sin(z * 0.30) * 0.30
	var bridge_distance := Vector2(x - bridge_x, z - clampf(z, 0.0, 14.5)).length()
	var bridge_weight := 1.0 - smoothstep(bridge_width - 0.8, bridge_width + 0.8, bridge_distance)
	var bed := lerpf(-1.8, -0.17, bridge_weight)
	bed = lerpf(bed, -0.24 + sin(x * 0.3) * 0.025, south_weight)
	bed = lerpf(bed, -0.13 + cos(x * 0.35) * 0.035, center_weight)
	return lerpf(bed, land_height, land_weight)

func is_walkable(x: float, z: float) -> bool:
	if not is_finite(x) or not is_finite(z) or x < -38 or x > 38 or z < -28 or z > 28:
		return false
	for r in state.get("obstacles", []):
		if absf(x - float(r.x)) <= float(r.w) / 2.0 + 0.65 and absf(z - float(r.z)) <= float(r.d) / 2.0 + 0.65:
			return false
	return float(state.get("water_level", 0.95)) - terrain_height_at(x, z) <= 0.55

func _nav() -> AStarGrid2D:
	var revision := int(float(state.water_level) * 1000.0)
	if _grid != null and revision == _navigation_revision:
		return _grid
	_grid = AStarGrid2D.new()
	_grid.region = Rect2i(-19, -14, 39, 29)
	_grid.cell_size = Vector2(2, 2)
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.update()
	for x in range(-19, 20):
		for z in range(-14, 15):
			_grid.set_point_solid(Vector2i(x, z), not is_walkable(x * 2.0, z * 2.0))
	_navigation_revision = revision
	return _grid

func _route(origin: Vector2, target: Vector2) -> Array:
	var grid := _nav()
	var start := Vector2i(roundi(origin.x / 2.0), roundi(origin.y / 2.0))
	var goal := Vector2i(roundi(target.x / 2.0), roundi(target.y / 2.0))
	if not grid.is_in_boundsv(start) or not grid.is_in_boundsv(goal):
		return []
	var end := target
	if grid.is_point_solid(goal):
		# La celda de 2 unidades puede ser solida aunque el punto exacto sea transitable
		# (junto a obstaculos u orillas): se usa la celda libre vecina mas cercana.
		var best := Vector2i(-99999, -99999)
		var best_d := INF
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var c := goal + Vector2i(dx, dy)
				if (dx == 0 and dy == 0) or not grid.is_in_boundsv(c) or grid.is_point_solid(c):
					continue
				var d := Vector2(c.x * 2.0, c.y * 2.0).distance_to(target)
				if d < best_d:
					best_d = d
					best = c
		if best_d == INF:
			return []
		goal = best
		if not is_walkable(target.x, target.y):
			end = Vector2(goal.x * 2.0, goal.y * 2.0)
	if grid.is_point_solid(start):
		return []
	var ids := grid.get_id_path(start, goal)
	var path: Array = []
	for i in range(1, ids.size()):
		path.append({"x": float(ids[i].x * 2), "z": float(ids[i].y * 2)})
	if not ids.is_empty() and (path.is_empty() or Vector2(path[-1].x, path[-1].z).distance_to(end) > 0.1):
		path.append({"x": end.x, "z": end.y})
	return path

func issue_order(group_id: String, action: String, target: Vector2 = Vector2.ZERO) -> Dictionary:
	if state.get("status", "") != "playing":
		return _no("La partida ya terminó.")
	var u := get_unit(group_id)
	if u.is_empty() or float(u.strength) <= 5.0:
		return _no("Esa agrupación ya no puede recibir órdenes.")
	if state.scenario == "norte":
		var sid := str(u.sector_id)
		var nearest := INF
		for s in state.sectors:
			var distance := target.distance_to(Vector2(s.x, s.z))
			if distance < nearest:
				nearest = distance
				sid = s.id
		return issue_campaign_order(group_id, action, sid)
	if action == "cancel":
		return cancel_order(group_id)
	if action not in ["move", "rally", "board", "direct", "flank"]:
		return _no("Orden táctica desconocida.")
	if action in ["direct", "flank"]:
		target = BOARD_POINT
		var here := Vector2(u.x, u.z)
		var at_ship := here.distance_to(BOARD_POINT) <= 0.5
		var crossing := _approach_path(u, action)
		var approach := crossing
		if crossing.is_empty() and not at_ship:
			# El cruce aun no es posible: esperar en la orilla solo tiene sentido si el agua todavia puede bajar.
			if str(state.tide_phase) == "subiendo":
				return _no("El río ya está creciendo y no volverá a bajar: no hay aproximación posible. Mantené la posición en la orilla.")
			var staging := Vector2(-10.0, 14.0 if action == "flank" else 0.0)
			approach = _route(here, staging)
			if approach.is_empty() and here.distance_to(staging) > 0.5:
				return _no("No hay una ruta transitable hasta la orilla de espera.")
		elif not crossing.is_empty() and not _crossing_in_time(u, crossing):
			return _no("La crecida cerraría el cruce antes de llegar al buque. No se emite la orden.")
		u.order = {"action": action, "x": target.x, "z": target.y}
		u.path = approach
		u.stage = "moving"
		if approach.is_empty():
			_arrived(u)
		_record_order(group_id, action, {"x": target.x, "z": target.y})
		var msg := "Aproximación preparada: el cruce es posible con el nivel actual del río."
		if crossing.is_empty() and not at_ship:
			msg = "Aproximación preparada: la agrupación espera en la orilla hasta que la bajante permita cruzar."
		return {"ok": true, "reason": msg, "path": u.path.duplicate(true)}
	if action == "rally":
		u.path = []
		u.stage = "rally"
		u.order = {"action": action}
		if float(u.x) <= -8.0:
			u.mounted = true
	else:
		if action == "board":
			target = BOARD_POINT
		if not is_walkable(target.x, target.y):
			return _no("El agua aún es demasiado profunda o hay un obstáculo. Esperá la bajante y usá los bancos señalados.")
		var path := _route(Vector2(u.x, u.z), target)
		if path.is_empty() and Vector2(u.x, u.z).distance_to(target) > 0.5:
			return _no("No hay una ruta transitable hasta ese punto con el nivel actual del río.")
		u.path = path
		u.order = {"action": action, "x": target.x, "z": target.y}
		u.stage = "moving"
		if path.is_empty():
			_arrived(u)
	_record_order(group_id, action, {"x": target.x, "z": target.y})
	return {"ok": true, "reason": "Orden recibida.", "path": u.path.duplicate(true)}

func _approach_path(u: Dictionary, action: String) -> Array:
	var points: Array = [BOARD_POINT]
	if action == "flank":
		points = [Vector2(-10, 14), Vector2(12, 14), BOARD_POINT]
		if float(u.x) > 8.0:
			points = [Vector2(12, 14), BOARD_POINT] if float(u.z) > 6.0 else [BOARD_POINT]
	var origin := Vector2(u.x, u.z)
	var complete: Array = []
	for point in points:
		if not is_walkable(point.x, point.y):
			return []
		var section := _route(origin, point)
		if section.is_empty() and origin.distance_to(point) > 0.5:
			return []
		complete.append_array(section)
		origin = point
	return complete

## Segundo en que el agua cubre `h + 0.55` durante la subida (inicio RISE_START, 120 s de 0,05 a 0,95).
func _flood_time(bed_height: float) -> float:
	var limit := bed_height + 0.55
	if limit >= 0.95:
		return INF
	return RISE_START + RISE_DURATION * (maxf(limit, 0.05) - 0.05) / 0.9

## Estima si la agrupación llega a cada punto del trayecto antes de que la crecida lo cubra.
func _crossing_in_time(u: Dictionary, path: Array) -> bool:
	var speed := (0.24 if u.mounted else 0.18) * maxf(0.55, 1.0 - float(u.fatigue) * 0.004) * 0.97
	var distance := 0.0
	var prev := Vector2(u.x, u.z)
	for p in path:
		var point := Vector2(p.x, p.z)
		distance += prev.distance_to(point)
		prev = point
		var arrival := float(state.elapsed) + distance / speed
		if arrival > _flood_time(terrain_height_at(point.x, point.y)):
			return false
	return true

## Punto transitable mas cercano (prefiere la orilla oeste); Vector2(INF, INF) si no hay ninguno.
func _nearest_dry_point(from: Vector2) -> Vector2:
	var best := Vector2(INF, INF)
	var best_d := INF
	for dx in range(-14, 15):
		for dz in range(-14, 15):
			var c := Vector2(from.x + dx, from.y + dz)
			if not is_walkable(c.x, c.y):
				continue
			var d := from.distance_to(c) + (0.0 if c.x <= -8.0 else 6.0)
			if d < best_d:
				best_d = d
				best = c
	return best

## Una agrupación que queda dentro del agua al subir el río no puede quedar varada: vuelve a la orilla.
func _rescue_submerged(u: Dictionary) -> bool:
	if is_walkable(float(u.x), float(u.z)):
		return false
	var dry := _nearest_dry_point(Vector2(u.x, u.z))
	if not is_finite(dry.x):
		return false
	u.x = dry.x
	u.z = dry.y
	u.path = []
	u.order = {}
	u.stage = "ready"
	u.fatigue = minf(100.0, float(u.fatigue) + 10.0)
	_event("%s no alcanzó a cruzar antes de la crecida y es llevada de vuelta a un punto seco de la orilla (+10 fatiga). Deberá dar otra orden." % u.name, "warning")
	return true

func _cancel_closed_crossing(u: Dictionary) -> void:
	u.order = {}
	u.path = []
	u.stage = "ready"
	_event("%s: la crecida cerró el cruce; la orden de aproximación queda sin efecto y la agrupación espera en seco." % u.name, "warning")

func cancel_order(group_id: String) -> Dictionary:
	var u := get_unit(group_id)
	if u.is_empty() or state.get("status", "") != "playing":
		return _no("No hay una orden que cancelar.")
	u.order = {}
	u.path = []
	u.stage = "ready"
	u.dismount_remaining = 0.0
	_record_order(group_id, "cancel", {})
	return {"ok": true, "reason": "Orden cancelada."}

func _record_order(id: String, action: String, target: Dictionary) -> void:
	if float(state.first_order_at) < 0:
		state.first_order_at = float(state.elapsed)
	state.orders.append({"time": state.elapsed, "round": state.round, "unit": id, "action": action, "target": target.duplicate(true)})
	state.state_version = int(state.state_version) + 1

func tick(dt: float) -> Array:
	_events = []
	if state.get("status", "") != "playing" or state.get("scenario", "") != "justine" or not is_finite(dt) or dt <= 0:
		return _events
	state.accumulator = float(state.accumulator) + minf(dt, 60.0)
	while float(state.accumulator) + 0.000001 >= STEP and state.status == "playing":
		state.accumulator = maxf(0.0, float(state.accumulator) - STEP)
		_justine_step(STEP)
	return _events

func _justine_step(dt: float) -> void:
	state.elapsed = float(state.elapsed) + dt
	var elapsed := float(state.elapsed)
	if elapsed < 40.0:
		state.water_level = 0.95
		state.tide_phase = "alta"
	elif elapsed < 210.0:
		state.water_level = lerpf(0.95, 0.05, (elapsed - 40.0) / 170.0)
		state.tide_phase = "bajando"
	elif elapsed < 780.0:
		state.water_level = 0.05
		state.tide_phase = "baja"
	else:
		state.water_level = lerpf(0.05, 0.95, clampf((elapsed - 780.0) / 120.0, 0.0, 1.0))
		state.tide_phase = "subiendo"
	if not state.bajante_announced and is_walkable(0, 0):
		state.bajante_announced = true
		_event("¡El banco central ya es transitable! El sur abrirá poco después. La oportunidad del río es una regla del juego, no una predicción histórica.", "tide")
	if elapsed >= 780.0 and not state.rising_announced:
		state.rising_announced = true
		_event("El agua vuelve a subir: quedan dos minutos para asegurar la captura.", "warning")
	var board_power := 0.0
	var alive := 0
	for u in state.units:
		if float(u.strength) <= 5.0:
			u.stage = "routed"
			u.path = []
			continue
		alive += 1
		if u.stage == "moving":
			_move_unit(u, dt)
		elif u.stage == "waiting_tide":
			if str(state.tide_phase) == "subiendo":
				_cancel_closed_crossing(u)
			elif float(state.water_level) <= (0.28 if u.order.get("action", "direct") == "flank" else 0.39):
				var crossing := _approach_path(u, str(u.order.get("action", "direct")))
				if not crossing.is_empty():
					if _crossing_in_time(u, crossing):
						u.path = crossing
						u.stage = "moving"
						_event("%s aprovecha la bajante y comienza el cruce." % u.name, "tide")
					else:
						_cancel_closed_crossing(u)
		elif u.stage == "blocked" and elapsed >= float(u.blocked_until):
			if _rescue_submerged(u):
				continue
			if str(state.tide_phase) == "subiendo" and u.order.get("action", "") in ["direct", "flank", "board"] and not is_walkable(BOARD_POINT.x, BOARD_POINT.y):
				_cancel_closed_crossing(u)
				continue
			var destination := Vector2(float(u.order.get("x", u.x)), float(u.order.get("z", u.z)))
			u.path = _route(Vector2(u.x, u.z), destination)
			if not u.path.is_empty():
				u.stage = "moving"
			else:
				u.blocked_until = elapsed + 5.0
		elif u.stage == "dismounting":
			u.dismount_remaining = maxf(0.0, float(u.dismount_remaining) - dt)
			if float(u.dismount_remaining) <= 0.0:
				u.mounted = false
				u.stage = "boarding"
				_event("%s desmontó. Los caballos quedan en el banco mientras la partida exige la rendición." % u.name, "boarding")
		elif u.stage == "boarding":
			board_power += (float(u.strength) / 100.0) * maxf(0.35, 1.0 - float(u.fatigue) * 0.004)
			u.fatigue = minf(100.0, float(u.fatigue) + dt * 0.025)
		elif u.stage == "rally":
			u.fatigue = maxf(0.0, float(u.fatigue) - dt * 0.18)
			if float(u.x) <= -8.0:
				u.strength = minf(100.0, float(u.strength) + dt * 0.025)
				u.supply = minf(100.0, float(u.supply) + dt * 0.04)
	if board_power > 0.0:
		state.capture = minf(100.0, float(state.capture) + board_power * 0.19 * dt)
		state.crew_morale = maxf(0.0, float(state.crew_morale) - board_power * 0.12 * dt)
	if elapsed >= float(state.next_volley):
		state.next_volley = float(state.next_volley) + 7.5
		_artillery()
	if alive == 0:
		_finish("defeat", "Las agrupaciones se dispersaron antes de asegurar la captura.")
	elif float(state.capture) >= 100.0:
		_finish("victory", "La dotación se rinde. El Justine queda capturado; los caballos permanecen fuera de la cubierta.")
	elif elapsed >= float(state.deadline):
		_finish("defeat", "La oportunidad de la bajante se cerró sin asegurar el buque.")
	state.state_version = int(state.state_version) + 1

func _move_unit(u: Dictionary, dt: float) -> void:
	if u.path.is_empty():
		_arrived(u)
		return
	var p: Dictionary = u.path[0]
	if not is_walkable(float(p.x), float(p.z)):
		u.stage = "blocked"
		u.blocked_until = float(state.elapsed) + 5.0
		_event("%s detiene el avance: el agua cubre la ruta. Podés cancelar y dar otra orden." % u.name, "warning")
		return
	var current := Vector2(u.x, u.z)
	var destination := Vector2(p.x, p.z)
	var speed := (0.24 if u.mounted else 0.18) * maxf(0.55, 1.0 - float(u.fatigue) * 0.004)
	var next := current.move_toward(destination, speed * dt)
	if not is_walkable(next.x, next.y):
		u.stage = "blocked"
		u.blocked_until = float(state.elapsed) + 5.0
		return
	u.x = next.x
	u.z = next.y
	u.fatigue = minf(100.0, float(u.fatigue) + dt * 0.04)
	u.supply = maxf(0.0, float(u.supply) - dt * 0.018)
	if next.distance_to(destination) < 0.01:
		u.path.pop_front()
		if u.path.is_empty():
			_arrived(u)

func _arrived(u: Dictionary) -> void:
	if u.order.get("action", "") in ["board", "direct", "flank"] and Vector2(u.x, u.z).distance_to(BOARD_POINT) <= 2.0:
		if u.mounted:
			u.stage = "dismounting"
			u.dismount_remaining = 12.0
			_event("%s llegó al buque y prepara el desmontaje (12 s)." % u.name, "boarding")
		else:
			u.stage = "boarding"
	elif u.order.get("action", "") in ["direct", "flank"]:
		u.stage = "waiting_tide"
		_event("%s aguarda en la ribera hasta que su aproximación sea transitable." % u.name, "tide")
	else:
		u.stage = "ready"
		u.order = {}

func exposure_for(u: Dictionary) -> float:
	var p := Vector2(float(u.x), float(u.z))
	if p.x <= -7.0 or p.distance_to(SHIP) > 34.0 or float(u.strength) <= 5.0:
		return 0.0
	if u.stage in ["boarding", "dismounting"]:
		return 0.08
	return 0.22 if p.y >= 6.0 else 1.0

func _artillery() -> void:
	var targets: Array = []
	for u in state.units:
		if exposure_for(u) > 0:
			targets.append(u)
	if targets.is_empty():
		return
	var u: Dictionary = targets[mini(targets.size() - 1, int(_random() * targets.size()))]
	var damage := (3.2 + _random() * 1.8) * exposure_for(u) * maxf(0.20, float(state.crew_morale) / 100.0)
	u.strength = maxf(0.0, float(u.strength) - damage)
	u.fatigue = minf(100.0, float(u.fatigue) + damage * 0.2)
	_event("Artillería sobre %s: −%.1f efectivos. Exposición %s." % [u.name, damage, "baja" if exposure_for(u) < 0.5 else "alta"], "shot")

func issue_campaign_order(group_id: String, action: String, sector_id: String = "") -> Dictionary:
	if state.get("scenario", "") != "norte" or state.get("status", "") != "playing":
		return _no("La campaña no está activa.")
	if action == "cancel":
		return cancel_order(group_id)
	var u := get_unit(group_id)
	if u.is_empty():
		return _no("Agrupación desconocida.")
	if sector_id.is_empty():
		sector_id = str(u.sector_id)
	var check := _validate_campaign_order(u, action, sector_id)
	if not check.ok:
		return check
	u.order = {"action": action, "sector_id": sector_id}
	u.stage = "ordered"
	_record_order(group_id, action, {"sector_id": sector_id})
	return {"ok": true, "reason": "Orden preparada. Podés cambiarla o cancelarla antes de resolver la ronda."}

func legal_campaign_actions(group_id: String, sector_id: String) -> Array:
	var u := get_unit(group_id)
	var actions: Array = []
	if u.is_empty() or state.get("scenario", "") != "norte" or state.get("status", "") != "playing":
		return actions
	for action in CAMPAIGN_ACTIONS:
		if _validate_campaign_order(u, action, sector_id).ok:
			actions.append(action)
	return actions

func campaign_order_reason(group_id: String, action: String, sector_id: String) -> String:
	var u := get_unit(group_id)
	if u.is_empty():
		return "Agrupación desconocida."
	return str(_validate_campaign_order(u, action, sector_id).reason)

func _validate_campaign_order(u: Dictionary, action: String, sector_id: String) -> Dictionary:
	if float(u.strength) <= 5.0:
		return _no("La agrupación está dispersa.")
	if action not in CAMPAIGN_ACTIONS:
		return _no("Orden de campaña desconocida.")
	var s := get_sector(sector_id)
	var origin := get_sector(str(u.sector_id))
	if s.is_empty() or origin.is_empty():
		return _no("Sector desconocido.")
	var same := sector_id == str(u.sector_id)
	if not same and sector_id not in origin.neighbors:
		return _no("El sector no es vecino: desplazate por las rutas del mapa.")
	if action == "rest":
		if not same:
			return _no("El descanso se realiza en el sector actual.")
		if s.enemy:
			return _no("No se puede descansar en un sector ocupado. Replegate primero.")
		if float(state.stores) < 8:
			return _no("Faltan 8 reservas para reponer esta agrupación. Protegé víveres.")
	if action == "move" and same:
		return _no("La agrupación ya se encuentra en ese sector.")
	if action == "withdraw" and (same or s.enemy):
		return _no("Elegí un sector vecino sin ocupación enemiga para replegarte.")
	if action in ["raid", "assault"]:
		if not s.known:
			return _no("Primero reconocé ese sector con exploradores.")
		if float(u.supply) < (18.0 if action == "assault" else 11.0):
			return _no("Faltan suministros en la agrupación. Descansá en un sector seguro.")
		if float(u.fatigue) > 78.0:
			return _no("La fatiga impide otro combate. Replegate o descansá.")
		if float(u.strength) < (45.0 if action == "assault" else 25.0):
			return _no("No quedan fuerzas suficientes para esa operación.")
	if action == "raid" and sector_id not in ["humahuaca", "quebrada", "jujuy", "salta", "oran"]:
		return _no("No pasa un abastecimiento realista por ese sector.")
	if action == "protect":
		if not same:
			return _no("La protección de víveres se organiza en el sector actual.")
		if s.enemy:
			return _no("El sector está ocupado; trasladá la partida a una zona propia.")
		if int(s.crates) <= 0:
			return _no("Ya se retiraron los víveres de este sector. Elegí otro lugar.")
	if action == "assault":
		if u.id != "arias" or sector_id != "humahuaca":
			return _no("La operación de Humahuaca corresponde a Manuel Eduardo Arias.")
		if int(state.round) < 7:
			return _no("Humahuaca estará disponible desde la ronda del 1 de marzo de 1817.")
		if state.humahuaca:
			return _no("Humahuaca ya fue recuperada.")
	return {"ok": true, "reason": "Disponible."}

func enemy_choices() -> Dictionary:
	if state.get("scenario", "") != "norte":
		return {}
	var choices := {"forage": "Buscar víveres en sectores conocidos para sostener al ejército invasor.",
		"guard": "Proteger comunicaciones y convoyes; reduce el efecto de los hostigamientos de esta ronda."}
	if _enemy_can_advance():
		choices["advance"] = "Avanzar hacia Salta: gana presencia, pero consume abastecimientos."
	if _enemy_can_retreat():
		choices["retreat"] = "Ordenar una retirada: la combinación de pérdidas, suministros y comunicaciones vuelve inviable la campaña."
	return choices

func enemy_fallback() -> String:
	if _enemy_can_retreat():
		return "retreat"
	if float(state.enemy.supply) < 58.0:
		return "forage"
	if _enemy_can_advance() and int(state.round) >= 3:
		return "advance"
	return "guard"

func enemy_observation() -> Dictionary:
	if state.get("scenario", "") != "norte":
		return {}
	var visible: Array = []
	for u in state.units:
		if int(u.revealed_until) >= int(state.round):
			visible.append({"sector": u.sector_id, "force_estimate": int(round(float(u.strength) / 20.0) * 20), "last_observed_round": state.round})
	var known: Array = []
	var resources: Array = []
	for s in state.sectors:
		if s.enemy or s.id == state.enemy.position:
			known.append({"id": s.id, "occupied": s.enemy})
			resources.append({"sector": s.id, "foraging_blocked": int(s.protected_until) >= int(state.round)})
	return {"actor": "ejercito_realista", "scenario": "norte", "round": state.round,
		"self_forces": "agrupaciones agregadas", "self_supplies": state.enemy.supply,
		"self_cohesion": state.enemy.cohesion, "known_sectors": known, "visible_enemies": visible,
		"visible_resources": resources, "public_events": {"humahuaca_lost": state.humahuaca, "salta_occupied": state.enemy.occupied_salta},
		"goal": "Sostener la invasión; conservar tropas si continuar resulta inviable.",
		"situation": {"own_communications": state.enemy.communications, "position": state.enemy.position}}

## Avanzar de la Quebrada a Jujuy es libre; entrar en Salta solo desde la ronda de la ocupacion documentada.
func _enemy_can_advance() -> bool:
	if state.get("scenario", "") != "norte" or state.enemy.occupied_salta:
		return false
	return str(state.enemy.position) == "quebrada" or int(state.round) >= SALTA_OCCUPATION_ROUND

func _enemy_can_retreat() -> bool:
	if state.get("scenario", "") != "norte" or int(state.round) < RETREAT_MIN_ROUND or int(state.pressure_actions) < RETREAT_MIN_PRESSURE:
		return false
	return (float(state.enemy.supply) <= 22.0 and float(state.enemy.cohesion) <= 42.0 and float(state.enemy.communications) <= 45.0) or (float(state.enemy.cohesion) <= 22.0 and float(state.enemy.supply) <= 38.0)

func resolve_round(enemy_intent: String = "forage") -> Array:
	_events = []
	if state.get("scenario", "") != "norte" or state.get("status", "") != "playing":
		return _events
	var choices := enemy_choices()
	if not choices.has(enemy_intent):
		enemy_intent = enemy_fallback()
	state.enemy.intent = enemy_intent
	var before: Dictionary = {"enemy_supply": state.enemy.supply, "enemy_cohesion": state.enemy.cohesion,
		"enemy_communications": state.enemy.communications, "population": state.population, "stores": state.stores}
	var protected_this_round := 0
	for u in state.units:
		var order: Dictionary = u.order.duplicate(true)
		u.order = {}
		u.stage = "ready"
		if order.is_empty() or float(u.strength) <= 5.0:
			u.fatigue = maxf(0.0, float(u.fatigue) - 3.0)
			continue
		var action := str(order.get("action", ""))
		var sector_id := str(order.get("sector_id", ""))
		var check := _validate_campaign_order(u, action, sector_id)
		if not check.ok:
			_event("%s no ejecutó la orden: %s" % [u.name, check.reason], "blocked")
			continue
		var s := get_sector(sector_id)
		if action in ["move", "withdraw", "raid", "assault"]:
			u.sector_id = sector_id
			u.x = float(s.x)
			u.z = float(s.z)
		if action == "move":
			u.fatigue = minf(100.0, float(u.fatigue) + 7.0)
			u.supply = maxf(0.0, float(u.supply) - 4.0)
			s.known = true
			_event("%s se desplaza a %s." % [u.name, s.name], "move")
		elif action == "withdraw":
			u.fatigue = maxf(0.0, float(u.fatigue) - 16.0)
			u.supply = maxf(0.0, float(u.supply) - 3.0)
			u.revealed_until = 0
			_event("%s se repliega a %s y conserva sus fuerzas." % [u.name, s.name], "withdraw")
		elif action == "scout":
			s.known = true
			s.intel_until = int(state.round) + 3
			for adjacent in s.neighbors:
				get_sector(adjacent).known = true
			u.fatigue = minf(100.0, float(u.fatigue) + 5.0)
			u.supply = maxf(0.0, float(u.supply) - 3.0)
			_event("Exploradores de %s reconocen %s. Inteligencia útil durante tres rondas." % [u.name, s.name], "scout")
		elif action == "protect":
			s.crates = maxi(0, int(s.crates) - 1)
			s.protected_until = int(state.round) + 2
			state.stores = minf(150.0, float(state.stores) + 18.0)
			state.population = minf(100.0, float(state.population) + 9.0)
			u.fatigue = minf(100.0, float(u.fatigue) + 5.0)
			protected_this_round += 1
			_event("Víveres y animales de %s a resguardo: +18 reservas y +9 apoyo. El enemigo encontrará menos recursos." % s.name, "protect")
		elif action == "rest":
			state.stores = maxf(0.0, float(state.stores) - 8.0)
			u.strength = minf(100.0, float(u.strength) + 9.0)
			u.supply = minf(100.0, float(u.supply) + 27.0)
			u.fatigue = maxf(0.0, float(u.fatigue) - 34.0)
			u.revealed_until = 0
			_event("%s repone caballos y fuerzas: +27 suministros, −34 fatiga; cuesta 8 reservas." % u.name, "rest")
		elif action == "raid":
			_resolve_raid(u, s, enemy_intent)
		elif action == "assault":
			state.humahuaca = true
			s.enemy = false
			state.enemy.supply = maxf(0.0, float(state.enemy.supply) - 12.0)
			state.enemy.cohesion = maxf(0.0, float(state.enemy.cohesion) - 8.0)
			state.enemy.communications = maxf(0.0, float(state.enemy.communications) - 20.0)
			state.pressure_actions = int(state.pressure_actions) + 2
			u.strength = maxf(0.0, float(u.strength) - 10.0)
			u.supply = maxf(0.0, float(u.supply) - 18.0)
			u.fatigue = minf(100.0, float(u.fatigue) + 22.0)
			u.revealed_until = int(state.round) + 1
			_event("Arias recupera Humahuaca: la operación coordinada neutraliza artillería, cuartel y depósito de pólvora. −20 comunicaciones realistas.", "humahuaca")
	_apply_enemy(enemy_intent, protected_this_round)
	state.population = maxf(0.0, float(state.population) - (6.0 if state.enemy.occupied_salta else 3.5))
	state.stores = maxf(0.0, float(state.stores) - 5.0)
	var surviving := 0
	for u in state.units:
		u.supply = maxf(0.0, float(u.supply) - 3.0)
		if float(u.supply) <= 0.0:
			u.strength = maxf(0.0, float(u.strength) - 9.0)
		if float(state.stores) <= 0.0:
			u.fatigue = minf(100.0, float(u.fatigue) + 5.0)
		if float(u.strength) > 5.0:
			surviving += 1
		else:
			u.stage = "routed"
	if int(state.round) == 8:
		_event("Llega una noticia del frente de Chile: Chacabuco (12 de febrero) da sentido estratégico a sostener el norte. Mensaje dramatizado; San Martín no aparece como refuerzo en Salta.", "history")
	if surviving == 0 or float(state.population) <= 10.0:
		_finish("defeat", "La defensa perdió sus agrupaciones o el sostén de las poblaciones. La invasión conserva capacidad de continuar.")
	elif _enemy_can_retreat():
		var chronology := "La presión volvió insostenible la invasión y forzó su retirada."
		if int(state.round) < 13:
			chronology += " Desenlace alternativo anticipado: la retirada histórica ocurrió a comienzos de mayo."
		_finish("victory", chronology)
	elif int(state.round) >= MAX_ROUNDS:
		_finish("defeat", "Llegó mayo y el ejército invasor todavía mantiene recursos y cohesión. Esperar sin cortarle el abastecimiento no alcanza.")
	state.last_results = [{"label": "Abastecimiento realista", "before": before.enemy_supply, "after": state.enemy.supply},
		{"label": "Cohesión realista", "before": before.enemy_cohesion, "after": state.enemy.cohesion},
		{"label": "Comunicaciones realistas", "before": before.enemy_communications, "after": state.enemy.communications},
		{"label": "Apoyo de la población", "before": before.population, "after": state.population},
		{"label": "Reservas propias", "before": before.stores, "after": state.stores}]
	if state.status == "playing":
		state.round = int(state.round) + 1
		state.date = DATES[mini(MAX_ROUNDS - 1, int(state.round) - 1)]
	state.state_version = int(state.state_version) + 1
	return _events

func _resolve_raid(u: Dictionary, s: Dictionary, intent: String) -> void:
	var informed := int(s.intel_until) >= int(state.round)
	var guard_factor := 0.68 if intent == "guard" else 1.0
	var effectiveness := maxf(0.45, (float(u.strength) / 100.0) * (1.0 - float(u.fatigue) * 0.003))
	var supply_loss := (20.0 if informed else 14.0) * effectiveness * guard_factor
	var casualties := (4.0 if informed else 8.0) + _random() * 4.0
	if s.id == state.enemy.position:
		casualties += 3.0
	if intent == "guard":
		casualties += 3.0
	u.strength = maxf(0.0, float(u.strength) - casualties)
	u.supply = maxf(0.0, float(u.supply) - 11.0)
	u.fatigue = minf(100.0, float(u.fatigue) + (16.0 if informed else 21.0))
	u.revealed_until = int(state.round) + 1
	state.enemy.supply = maxf(0.0, float(state.enemy.supply) - supply_loss)
	state.enemy.cohesion = maxf(0.0, float(state.enemy.cohesion) - 4.0 * effectiveness)
	state.enemy.communications = maxf(0.0, float(state.enemy.communications) - 6.0 * effectiveness)
	state.pressure_actions = int(state.pressure_actions) + 1
	_event("%s hostiga %s: −%.1f abastecimiento enemigo; pierde %.1f efectivos. %s" % [u.name, s.name, supply_loss, casualties, "La exploración redujo el riesgo." if informed else "Sin reconocimiento reciente, el riesgo fue mayor."], "raid")

func _apply_enemy(intent: String, protected_this_round: int) -> void:
	state.enemy.supply = maxf(0.0, float(state.enemy.supply) - 6.0)
	state.enemy.communications = maxf(0.0, float(state.enemy.communications) - (2.0 if state.humahuaca else 0.5))
	if float(state.enemy.supply) < 30.0:
		state.enemy.cohesion = maxf(0.0, float(state.enemy.cohesion) - 3.0)
	else:
		state.enemy.cohesion = minf(100.0, float(state.enemy.cohesion) + 1.0)
	var guarded_sectors := protected_this_round
	for s in state.sectors:
		if int(s.protected_until) >= int(state.round):
			guarded_sectors += 1
	if intent == "forage":
		var recovered := maxf(0.0, 16.0 - guarded_sectors * 2.5 - (4.0 if state.humahuaca else 0.0))
		state.enemy.supply = minf(100.0, float(state.enemy.supply) + recovered)
		state.population = maxf(0.0, float(state.population) - (4.0 if recovered > 7.0 else 0.0))
		_event("Los realistas buscan víveres: recuperan %.0f abastecimiento. La protección de recursos limita esa recuperación." % recovered, "enemy")
	elif intent == "guard":
		state.enemy.communications = minf(100.0, float(state.enemy.communications) + 3.0)
		_event("El invasor escolta sus convoyes. Los hostigamientos causaron menos daño y mayor riesgo.", "enemy")
	elif intent == "advance":
		state.enemy.supply = maxf(0.0, float(state.enemy.supply) - 7.0)
		if state.enemy.position == "quebrada":
			_enemy_moves_to("jujuy")
		else:
			_enemy_moves_to("salta")
			state.enemy.occupied_salta = true
		_event("Avance realista hacia %s: consume 7 abastecimiento adicional." % get_sector(state.enemy.position).name, "enemy")
	elif intent == "retreat":
		_event("El mando realista ordena preparar su retirada ante la situación insostenible.", "enemy")
	if int(state.round) >= SALTA_OCCUPATION_ROUND and not state.enemy.occupied_salta:
		state.enemy.occupied_salta = true
		_enemy_moves_to("salta")
		_event("Salta queda ocupada por los realistas (en esta ronda, del 12 al 22 de abril de 1817, se sitúa la ocupación documentada del 15 de abril). La campaña sigue: el invasor necesita abastecimientos y comunicaciones para sostenerse.", "occupation")

func _enemy_moves_to(sector_id: String) -> void:
	# Marca solo el sector donde esta el invasor. Humahuaca se conserva como foco hasta que Arias lo recupere.
	var old := str(state.enemy.position)
	if old != sector_id and old != "humahuaca":
		get_sector(old).enemy = false
	state.enemy.position = sector_id
	get_sector(sector_id).enemy = true

func record_external_decision(decision: Dictionary) -> bool:
	var context: Dictionary = decision.get("context", {})
	if state.is_empty() or state.status != "playing" or str(context.get("game_id", "")) != str(state.game_id) or int(context.get("round", -1)) != int(state.round) or int(context.get("state_version", -1)) != int(state.state_version):
		return false
	if not enemy_choices().has(str(decision.get("choice", ""))):
		return false
	state.external_decisions.append(decision.duplicate(true))
	return true

func _random() -> float:
	state.rng_state = (int(state.rng_state) * 48271) % 2147483647
	return float(state.rng_state) / 2147483647.0

func _finish(status: String, reason: String) -> void:
	if state.status != "playing":
		return
	state.status = status
	state.reason = reason
	for u in state.units:
		u.order = {}
		u.path = []
	_event(reason, status)

func _event(message: String, kind: String = "info") -> void:
	var event := {"time": state.get("elapsed", 0.0), "round": state.get("round", 1), "text": message, "kind": kind}
	state.log.append(event)
	_events.append(event)

func _no(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}

func snapshot() -> Dictionary:
	return state.duplicate(true)

func save_game(path: String) -> Error:
	if state.is_empty():
		return ERR_UNCONFIGURED
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(state, "\t", true, true))
	file.flush()
	file.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path))

func load_game(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _no("No hay una partida guardada.")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 4000000:
		return _no("El archivo guardado no es válido.")
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return _no("El archivo guardado está dañado o no contiene JSON válido.")
	var parsed: Variant = parser.data
	var check := validate_snapshot(parsed)
	if not check.ok:
		return check
	state = parsed.duplicate(true)
	state.previous_game_id = state.game_id
	state.game_id = _new_id(str(state.scenario))
	state.state_version = int(state.state_version) + 1
	_navigation_revision = -999
	_events = []
	_event("Partida recuperada. Las respuestas externas de la sesión anterior quedan invalidadas.", "load")
	return {"ok": true, "reason": "Partida recuperada.", "state": state}

func validate_snapshot(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return _no("El guardado no contiene un estado válido.")
	var d: Dictionary = value
	for key in ["schema_version", "game_id", "state_version", "scenario", "seed", "rng_state", "elapsed", "accumulator", "status", "reason", "round", "units", "log", "orders", "external_decisions", "first_order_at"]:
		if not d.has(key):
			return _no("Guardado incompleto: falta %s." % key)
	if not _number_in(d.schema_version, SAVE_VERSION, SAVE_VERSION):
		return _no("Versión de guardado incompatible; se necesita la versión %d." % SAVE_VERSION)
	if not d.game_id is String or not d.reason is String or not _number_in(d.state_version, 1, 1000000000) or not _number_in(d.seed, -2147483647, 2147483647) or not _number_in(d.first_order_at, -1, 86400):
		return _no("Identidad o versión de estado inválidas.")
	if d.scenario not in ["justine", "norte"] or d.status not in ["playing", "victory", "defeat"]:
		return _no("Escenario o resultado inválido en el guardado.")
	if not _number_in(d.elapsed, 0, 86400) or not _number_in(d.round, 1, MAX_ROUNDS) or not _number_in(d.rng_state, 1, 2147483646) or not _number_in(d.accumulator, 0, 60):
		return _no("Los tiempos o la semilla del guardado son inválidos.")
	if not d.units is Array or d.units.size() != 3 or not d.log is Array or not d.orders is Array or not d.external_decisions is Array:
		return _no("Las agrupaciones o el registro del guardado son inválidos.")
	for event in d.log:
		if not event is Dictionary or not event.get("text") is String or not event.get("kind") is String or not _number_in(event.get("time"), 0, 86400) or not _number_in(event.get("round"), 1, MAX_ROUNDS):
			return _no("Registro de acontecimientos corrupto.")
	for order in d.orders:
		if not order is Dictionary or not order.has_all(["time", "round", "unit", "action", "target"]) or not order.target is Dictionary:
			return _no("Historial de órdenes corrupto.")
	for decision in d.external_decisions:
		if not decision is Dictionary or not decision.get("context") is Dictionary or not decision.get("choice") is String:
			return _no("Registro de decisiones externas corrupto.")
	var ids: Array = []
	for u in d.units:
		if not u is Dictionary:
			return _no("Agrupación corrupta.")
		for key in ["id", "name", "x", "z", "strength", "fatigue", "supply", "mounted", "stage", "order", "path", "sector_id", "dismount_remaining", "revealed_until", "blocked_until"]:
			if not u.has(key):
				return _no("Agrupación incompleta.")
		if u.id not in ["guemes", "arias", "zavala"] or u.id in ids:
			return _no("Identificadores de agrupación inválidos.")
		ids.append(u.id)
		if not _number_in(u.x, -38, 38) or not _number_in(u.z, -28, 28):
			return _no("Agrupación fuera del mapa.")
		for key in ["strength", "fatigue", "supply"]:
			if not _number_in(u[key], 0, 100):
				return _no("Recursos de agrupación inválidos.")
		if not u.order is Dictionary or not u.path is Array or not u.mounted is bool:
			return _no("Orden o trayecto corrupto.")
		if not u.name is String or not u.sector_id is String or u.stage not in ["ready", "moving", "rally", "waiting_tide", "blocked", "dismounting", "boarding", "routed", "ordered"] or not _number_in(u.dismount_remaining, 0, 12) or not _number_in(u.blocked_until, 0, 86400) or not _number_in(u.revealed_until, 0, MAX_ROUNDS + 1):
			return _no("Estado de agrupación inválido.")
		if not u.order.is_empty():
			if d.scenario == "justine":
				if u.order.get("action", "") not in ["move", "rally", "board", "direct", "flank"]:
					return _no("Orden táctica inválida.")
				if u.order.action != "rally" and (not _number_in(u.order.get("x"), -38, 38) or not _number_in(u.order.get("z"), -28, 28)):
					return _no("Destino táctico inválido.")
			elif u.order.get("action", "") not in CAMPAIGN_ACTIONS or not u.order.get("sector_id") is String:
				return _no("Orden de campaña inválida.")
		for point in u.path:
			if not point is Dictionary or not _number_in(point.get("x"), -38, 38) or not _number_in(point.get("z"), -28, 28):
				return _no("Trayecto fuera del mapa.")
	if d.scenario == "justine":
		for key in ["water_level", "tide_phase", "capture", "crew_morale", "next_volley", "deadline", "bajante_announced", "rising_announced", "obstacles", "historical_note"]:
			if not d.has(key):
				return _no("Estado de la ribera incompleto.")
		if not _number_in(d.water_level, 0.0, 1.0) or not _number_in(d.capture, 0, 100) or not _number_in(d.crew_morale, 0, 100) or not d.obstacles is Array:
			return _no("Estado del río o captura inválido.")
		if not _number_in(d.next_volley, 0, 1000) or not _number_in(d.deadline, 1, 3600) or not d.bajante_announced is bool or not d.rising_announced is bool or d.tide_phase not in ["alta", "bajando", "baja", "subiendo"]:
			return _no("Fase o tiempos del río inválidos.")
		for obstacle in d.obstacles:
			if not obstacle is Dictionary or not _number_in(obstacle.get("x"), -38, 38) or not _number_in(obstacle.get("z"), -28, 28) or not _number_in(obstacle.get("w"), 0.1, 15) or not _number_in(obstacle.get("d"), 0.1, 15):
				return _no("Obstáculo inválido.")
	else:
		for key in ["sectors", "enemy", "population", "stores", "humahuaca", "pressure_actions", "date", "last_results", "historical_note"]:
			if not d.has(key):
				return _no("Estado de campaña incompleto.")
		if not d.sectors is Array or d.sectors.size() != 8 or not d.enemy is Dictionary or not _number_in(d.population, 0, 100) or not _number_in(d.stores, 0, 150):
			return _no("Recursos o sectores de campaña inválidos.")
		if not d.humahuaca is bool or not _number_in(d.pressure_actions, 0, 1000) or not d.last_results is Array or d.date != DATES[int(d.round) - 1]:
			return _no("Progreso o fecha de campaña inválidos.")
		for key in ["supply", "cohesion", "communications"]:
			if not _number_in(d.enemy.get(key), 0, 100):
				return _no("Recursos realistas inválidos.")
		if not d.enemy.has_all(["position", "occupied_salta", "intent"]):
			return _no("Estado realista incompleto.")
		if not d.enemy.occupied_salta is bool or d.enemy.intent not in ["forage", "guard", "advance", "retreat"]:
			return _no("Intención realista inválida.")
		var sector_ids: Array = []
		for sector in d.sectors:
			if not sector is Dictionary or not sector.has_all(["id", "name", "x", "z", "neighbors", "known", "intel_until", "protected_until", "crates", "enemy"]):
				return _no("Sector incompleto.")
			if sector.id not in ["humahuaca", "quebrada", "jujuy", "salta", "lerma", "chicoana", "oran", "rosario"] or sector.id in sector_ids or not sector.neighbors is Array:
				return _no("Sector o conexión inválidos.")
			if not sector.name is String or not _number_in(sector.x, -38, 38) or not _number_in(sector.z, -28, 28) or not sector.known is bool or not sector.enemy is bool or not _number_in(sector.crates, 0, 3) or not _number_in(sector.intel_until, 0, MAX_ROUNDS + 3) or not _number_in(sector.protected_until, 0, MAX_ROUNDS + 2):
				return _no("Recursos o estado de sector inválidos.")
			sector_ids.append(sector.id)
		if d.enemy.position not in sector_ids:
			return _no("Posición realista inexistente.")
		for sector in d.sectors:
			for neighbor in sector.neighbors:
				if neighbor not in sector_ids:
					return _no("La ruta enlaza con un sector inexistente.")
		for u in d.units:
			if u.sector_id not in sector_ids:
				return _no("Agrupación en un sector inexistente.")
			if not u.order.is_empty() and u.order.sector_id not in sector_ids:
				return _no("Orden hacia un sector inexistente.")
		for result in d.last_results:
			if not result is Dictionary or not result.get("label") is String or not _number_in(result.get("before"), 0, 150) or not _number_in(result.get("after"), 0, 150):
				return _no("Resumen de ronda corrupto.")
	return _validate_coherence(d)

## Coherencia entre campos: cada campo puede ser valido por separado y aun asi contradecir a otro.
func _validate_coherence(d: Dictionary) -> Dictionary:
	var playing: bool = d.status == "playing"
	if playing != (d.reason == ""):
		return _no("Incoherencia: el motivo de cierre no corresponde al estado de la partida.")
	for event in d.log:
		if int(event.round) > int(d.round) or float(event.time) > float(d.elapsed) + 0.001:
			return _no("Incoherencia: el registro contiene acontecimientos posteriores al estado actual.")
	if d.orders.is_empty() != (float(d.first_order_at) < 0.0):
		return _no("Incoherencia: la primera orden no concuerda con el historial de órdenes.")
	if not d.orders.is_empty() and absf(float(d.orders[0].time) - float(d.first_order_at)) > 0.001:
		return _no("Incoherencia: el momento de la primera orden no coincide con el historial.")
	for order in d.orders:
		if int(order.round) > int(d.round) or float(order.time) > float(d.elapsed) + 0.001:
			return _no("Incoherencia: hay órdenes posteriores al estado actual.")
	for u in d.units:
		if u.stage == "routed" and float(u.strength) > 5.0:
			return _no("Incoherencia: agrupación dispersa con efectivos suficientes.")
		if u.stage == "dismounting" and not u.mounted:
			return _no("Incoherencia: agrupación desmontando que ya está desmontada.")
		if u.stage == "boarding" and u.mounted:
			return _no("Incoherencia: agrupación abordando que sigue montada.")
		if float(u.dismount_remaining) > 0.0 and u.stage not in ["dismounting", "routed"]:
			return _no("Incoherencia: tiempo de desmontaje en una agrupación que no desmonta.")
		if not playing and (not u.order.is_empty() or not u.path.is_empty()):
			return _no("Incoherencia: partida terminada con órdenes o trayectos pendientes.")
	if d.scenario == "justine":
		return _validate_justine_coherence(d, playing)
	return _validate_norte_coherence(d, playing)

func _tide_at(elapsed: float) -> Dictionary:
	if elapsed < 40.0:
		return {"level": 0.95, "phase": "alta"}
	if elapsed < 210.0:
		return {"level": lerpf(0.95, 0.05, (elapsed - 40.0) / 170.0), "phase": "bajando"}
	if elapsed < RISE_START:
		return {"level": 0.05, "phase": "baja"}
	return {"level": lerpf(0.05, 0.95, clampf((elapsed - RISE_START) / RISE_DURATION, 0.0, 1.0)), "phase": "subiendo"}

func _validate_justine_coherence(d: Dictionary, playing: bool) -> Dictionary:
	var tide := _tide_at(float(d.elapsed))
	if d.tide_phase != tide.phase or absf(float(d.water_level) - float(tide.level)) > 0.002:
		return _no("Incoherencia: el nivel y la fase del río no corresponden al tiempo transcurrido.")
	if d.rising_announced != (float(d.elapsed) >= RISE_START) and playing:
		return _no("Incoherencia: el aviso de crecida no corresponde al tiempo transcurrido.")
	if playing:
		if float(d.capture) >= 100.0 or float(d.elapsed) > float(d.deadline) + 0.001:
			return _no("Incoherencia: partida en curso con captura completa o plazo vencido.")
		if float(d.accumulator) >= STEP + 0.001:
			return _no("Incoherencia: acumulador de tiempo mayor que un paso.")
		if float(d.next_volley) <= float(d.elapsed):
			return _no("Incoherencia: la próxima descarga ya debería haber ocurrido.")
	elif d.status == "victory" and float(d.capture) < 100.0:
		return _no("Incoherencia: victoria sin captura completa.")
	for u in d.units:
		if u.stage == "ordered":
			return _no("Incoherencia: estado de campaña en el escenario táctico.")
		if u.stage in ["moving", "waiting_tide", "blocked", "rally"] and u.order.is_empty():
			return _no("Incoherencia: agrupación en marcha sin orden.")
		if u.stage == "moving" and u.path.is_empty():
			return _no("Incoherencia: agrupación en marcha sin trayecto.")
		if not u.path.is_empty() and u.stage not in ["moving", "blocked"]:
			return _no("Incoherencia: trayecto pendiente en una agrupación que no avanza.")
	return {"ok": true, "reason": "Guardado válido."}

func _validate_norte_coherence(d: Dictionary, playing: bool) -> Dictionary:
	var by_id := {}
	for sector in d.sectors:
		by_id[sector.id] = sector
	for sector in d.sectors:
		for neighbor in sector.neighbors:
			if neighbor == sector.id or sector.id not in by_id[neighbor].neighbors:
				return _no("Incoherencia: la ruta entre sectores no es recíproca.")
	for u in d.units:
		var here: Dictionary = by_id[u.sector_id]
		if absf(float(u.x) - float(here.x)) > 0.001 or absf(float(u.z) - float(here.z)) > 0.001:
			return _no("Incoherencia: la agrupación no está en las coordenadas de su sector.")
		if (u.stage == "ordered") == u.order.is_empty() and u.stage != "routed":
			return _no("Incoherencia: la orden pendiente no concuerda con el estado de la agrupación.")
		if not u.order.is_empty() and u.order.sector_id != u.sector_id and u.order.sector_id not in here.neighbors:
			return _no("Incoherencia: orden hacia un sector inalcanzable.")
		if not u.path.is_empty():
			return _no("Incoherencia: trayecto táctico en la campaña.")
	var enemy: Dictionary = d.enemy
	if not by_id[enemy.position].enemy:
		return _no("Incoherencia: el sector del invasor no está marcado como ocupado.")
	if (enemy.position == "salta") != enemy.occupied_salta:
		return _no("Incoherencia: la ocupación de Salta no concuerda con la posición del invasor.")
	if playing and int(d.round) > SALTA_OCCUPATION_ROUND and not enemy.occupied_salta:
		return _no("Incoherencia: Salta debería estar ocupada en esta ronda.")
	if by_id["humahuaca"].enemy == d.humahuaca:
		return _no("Incoherencia: la recuperación de Humahuaca no concuerda con el sector.")
	if d.humahuaca and (int(d.round) < 7 or int(d.pressure_actions) < 2):
		return _no("Incoherencia: Humahuaca figura recuperada antes de la ronda posible.")
	if int(d.pressure_actions) > 3 * int(d.round) + 2:
		return _no("Incoherencia: más acciones de presión que las posibles hasta esta ronda.")
	if playing:
		if float(d.population) <= 10.0:
			return _no("Incoherencia: partida en curso con la población agotada.")
		var alive := false
		for u in d.units:
			alive = alive or float(u.strength) > 5.0
		if not alive:
			return _no("Incoherencia: partida en curso sin agrupaciones activas.")
		if d.last_results.size() != (0 if int(d.round) == 1 else 5):
			return _no("Incoherencia: el resumen de ronda no concuerda con la ronda actual.")
	return {"ok": true, "reason": "Guardado válido."}

func _number_in(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high
