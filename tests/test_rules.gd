extends SceneTree
## Pruebas del nucleo (escenario Norte sin cambios; Justina rediseñada: docs/CONTRATO_JUSTINA.md 1.10).

const Rules = preload("res://scripts/game_rules.gd")
const REPORT_PATH := "user://rules-test-results.json"
## Ruta sur siguiendo el eje del vado y del banco sur (docs/DISENO_JUSTINA.md 1.2): salida del vado, codo, banco, subida al buque.
const SOUTH_WAYPOINTS := [Vector2(305, 403), Vector2(450, 455), Vector2(520, 440), Vector2(565, 390)]
var failures: Array = []
var checks := 0
var report: Dictionary = {"suite": "authoritative_rules", "engine": Engine.get_version_info().string, "results": []}

func _initialize() -> void:
	_test_map_and_terrain()
	_test_speed_table()
	_test_tide_and_windows()
	_test_knowledge()
	_test_group_actions()
	_test_plan_risk()
	_test_scout_and_global_actions()
	_test_board_gate()
	_test_fire_and_exposure()
	_test_strategies()
	_test_speed_never_exceeded()
	_test_not_stranded()
	_test_justine_persistence()
	_test_justine_snapshot_coherence()
	_test_performance()
	_test_campaign()
	_test_norte_persistence()
	_test_external_stale()
	_test_north_pacing()
	_test_norte_snapshot_coherence()
	_test_salta_occupation_date()
	_test_history_humahuaca_marked()
	report.checks = checks
	report.failures = failures
	report.ok = failures.is_empty()
	# Los resultados van a user:// (perfil aislado): evidence/ de 0.1.0 no se toca.
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)

func _near(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol

# ---------------------------------------------------------------------------
# Ayudas de simulacion

func _new_j(seed_value: int = 7) -> RefCounted:
	var r := Rules.new()
	r.new_game("justine", seed_value)
	return r

func _advance(r: RefCounted, t: float) -> void:
	while float(r.state.elapsed) < t - 0.001 and r.state.status == "playing":
		r.tick(minf(1.0, t - float(r.state.elapsed)))

func _at(seconds: float, seed_value: int = 5) -> RefCounted:
	var r := _new_j(seed_value)
	_advance(r, seconds)
	return r

func _total_strength(r: RefCounted) -> float:
	var s := 0.0
	for u in r.state.units:
		s += float(u.strength)
	return s

# ---------------------------------------------------------------------------
# 1. Mapa, alturas de referencia y tipos de suelo

func _test_map_and_terrain() -> void:
	var r := _new_j()
	var m: Dictionary = r.map_data()
	check(not m.is_empty() and str(m.id) == "justina", "El mapa de Justina se carga una vez desde el JSON")
	check(r.map_size() == Vector2(900, 520), "map_size = 900 x 520 m")
	check(r.board_point() == Vector2(548, 262) and r.ship_position() == Vector2(580, 262), "board_point y ship_position salen del JSON")
	check(r.state.schema_version == Rules.JUSTINE_SAVE_VERSION and r.state.map_id == "justina" and int(r.state.map_version) == int(m.map_version), "Estado inicial con schema 2 y versión de mapa")
	check(r.state.units.size() == 3 and r.state.scouts.size() == 2 and int(r.state.ammo) == 16 and int(r.state.balizas) == 16 and _near(float(r.state.volunteers_pool), 60.0, 0.001), "Recursos y actores iniciales del JSON")
	check(float(r.state.units[0].x) == 105.0 and str(r.state.units[0].tag) == "tradicion" and str(r.state.units[2].tag) == "documentado", "Los grupos conservan su etiqueta de fuente (Güemes = tradición)")
	check(r.state.log[0].kind == "objective", "El primer evento es el objetivo")
	var refs := [[548, 262, -1.0], [580, 262, -1.5], [415, 264, -1.9], [415, 290, -0.34], [330, 264, -0.25], [450, 376, -0.83], [314, 400, -0.9], [304, 350, -2.0]]
	for ref in refs:
		var h: float = r.terrain_height_at(ref[0], ref[1])
		check(_near(h, ref[2], 0.02), "Altura de referencia (%d,%d) = %.2f (obtenida %.3f)" % [ref[0], ref[1], ref[2], h])
	check(_near(r.terrain_height_at(10, 100), 12.0 + (13.0 - 12.0) * 0.0, 3.0) and r.terrain_height_at(10, 100) > 8.0, "La meseta está a 8-15 m")
	check(_near(r.water_depth_at(100, 240), r.water_level_m() - r.terrain_height_at(100, 240), 1e-9), "water_depth_at = nivel - altura")
	# tipos de suelo con el río en 1,65 m
	var kinds := {"meseta": [10, 100], "barranca": [55, 100], "bajada": [58, 190], "obstaculo": [130, 120], "casco": [580, 262], "firme": [100, 240], "barro": [185, 240], "somera": [215, 240], "agua": [245, 240], "honda": [415, 264]}
	for k in kinds:
		check(r.terrain_kind_at(kinds[k][0], kinds[k][1]) == k, "terrain_kind_at devuelve %s (obtenido %s)" % [k, r.terrain_kind_at(kinds[k][0], kinds[k][1])])
	check(r.terrain_kind_at(-4, 10) == "obstaculo" and r.speed_at(-4, 10, "walk", true) == 0.0 and r.speed_at(901, 10, "walk", true) == 0.0, "Fuera del mapa no se transita")
	# la bajada y el acceso a los hitos de la meseta son transitables; el resto de la meseta no
	check(r.speed_at(58, 190, "trot", true) > 0.0 and r.speed_at(30, 205, "trot", true) > 0.0 and r.speed_at(28, 345, "trot", true) > 0.0, "Las bajadas y el acceso a la batería/puesto de Liniers son transitables")
	check(r.speed_at(10, 100, "trot", true) == 0.0 and r.speed_at(55, 100, "trot", true) == 0.0, "El resto de la meseta y la barranca no se pisan")
	check(not r.is_walkable(415, 264) and r.is_walkable(100, 240) and not r.is_walkable(130, 120), "is_walkable compatible con la firma vieja")

# ---------------------------------------------------------------------------
# 2. Tabla de velocidades (contrato 1.3.3)

func _test_speed_table() -> void:
	var r := _new_j()
	# firme
	check(_near(r.speed_at(100, 240, "gallop", true), 7.0, 1e-6) and _near(r.speed_at(100, 240, "trot", true), 3.0, 1e-6) and _near(r.speed_at(100, 240, "walk", true), 1.3, 1e-6), "Firme: galope 7, trote 3, paso 1,3 m/s")
	check(_near(r.speed_at(100, 240, "gallop", false), 1.3, 1e-6), "A pie nunca pasa de 1,3 m/s")
	# barro: altura 0,3 sobre el agua -> 1,25 m/s
	var h: float = r.terrain_height_at(100, 240)
	r.state.water_level_m = h - 0.3
	check(r.terrain_kind_at(100, 240) == "barro" and _near(r.speed_at(100, 240, "gallop", true), 1.25, 1e-6) and _near(r.speed_at(100, 240, "trot", true), 1.25, 1e-6), "Barro: el galope se limita y la velocidad interpola 1,0-1,5 m/s")
	r.state.water_level_m = h
	check(_near(r.speed_at(100, 240, "trot", true), 1.0, 1e-6), "Barro en la línea de agua: 1,0 m/s")
	# agua somera (banco central, 0,25 m de profundidad con el río en 0)
	r.state.water_level_m = 0.0
	check(r.terrain_kind_at(330, 264) == "somera" and _near(r.speed_at(330, 264, "gallop", true), 2.0, 1e-6) and _near(r.speed_at(330, 264, "walk", true), 1.3, 1e-6), "Somera a caballo: 2,0 m/s (el galope no vale)")
	check(_near(r.speed_at(330, 264, "trot", false), 1.0, 1e-6), "Somera a pie: 1,0 m/s")
	# agua 0,6-1,3
	r.state.water_level_m = 0.45
	check(r.terrain_kind_at(330, 264) == "agua" and _near(r.speed_at(330, 264, "trot", true), 0.8, 1e-6), "Agua de 0,6 a 1,3 m: 0,8 m/s")
	# limites: 1,25 m de profundidad -> a caballo pasa, a pie no (limite 1,2)
	r.state.water_level_m = 1.0
	check(_near(r.speed_at(330, 264, "trot", true), 0.8, 1e-6) and r.speed_at(330, 264, "walk", false) == 0.0, "A 1,25 m el caballo pasa y el infante no")
	r.state.water_level_m = 1.2
	check(r.speed_at(330, 264, "trot", true) == 0.0 and r.terrain_kind_at(330, 264) == "honda", "Más de 1,3 m es intransitable para el caballo")
	# bajada
	r.state.water_level_m = 1.65
	check(_near(r.speed_at(58, 190, "trot", true), 2.1, 1e-6) and _near(r.speed_at(58, 190, "gallop", true), 2.1, 1e-6) and _near(r.speed_at(58, 190, "walk", true), 0.91, 1e-6), "Bajada: x0,7 y sin galope")
	# carril sondeado: x0,75; marcado: velocidad plena
	r.state.water_level_m = 0.2
	r.state.probes.append({"id": "t1", "kind": "lane", "pts": [{"x": 300.0, "z": 264.0}, {"x": 360.0, "z": 264.0}], "width": 6.0, "t": 0.0, "scout": "scout_1"})
	check(_near(r.speed_at(330, 264, "trot", true), 1.5, 1e-6), "Carril sondeado sin marcar: x0,75 (1,5 m/s)")
	r.state.probes.append({"id": "t2", "kind": "marked", "pts": [{"x": 300.0, "z": 264.0}, {"x": 360.0, "z": 264.0}], "width": 16.0, "t": 0.0, "scout": "scout_1"})
	check(_near(r.speed_at(330, 264, "trot", true), 2.0, 1e-6), "Carril marcado: velocidad plena")

# ---------------------------------------------------------------------------
# 3. Rio: mareas y ventanas de vado

func _test_tide_and_windows() -> void:
	var r := _new_j()
	var expected := {0: [1.65, "alta"], 45: [1.65, "bajando"], 210: [0.825, "bajando"], 375: [0.0, "baja"], 500: [0.0, "baja"], 645: [0.0, "subiendo"], 735: [0.825, "subiendo"], 825: [1.65, "subiendo"], 900: [1.65, "subiendo"]}
	for t in expected:
		var td: Dictionary = r.tide_at(float(t))
		check(_near(td.level_m, expected[t][0], 1e-6) and td.phase == expected[t][1], "tide_at(%d) = %.3f m, %s" % [t, expected[t][0], expected[t][1]])
		check(_near(td.level_norm, 0.05 + 0.9 * td.level_m / 1.65, 1e-6), "level_norm derivado a t=%d" % t)
	var marks: Dictionary = r.tide_marks()
	check(marks.drop_start == 45.0 and marks.drop_end == 375.0 and marks.low_hold_end == 645.0 and marks.rise_end == 825.0 and marks.deadline == 900.0, "tide_marks")
	# antes de sondear: sin certeza (la ventana es la percibida, optimista)
	var bp: Vector2 = r.board_point()
	var before: Dictionary = r.ford_window(bp.x, bp.y)
	check(not before.certain and not before.known, "ford_window del buque: sin certeza antes de sondear")
	var before_south: Dictionary = r.ford_window(305, 403)
	check(not before_south.certain, "ford_window del vado sur: sin certeza antes de sondear")
	check(float(before.opens_at) < 315.0 and float(before_south.opens_at) < 295.0, "La ventana percibida de un fondo desconocido es más optimista que la real")
	# tras sondear los dos puntos, la ventana es la real
	r.state.probes.append({"id": "t1", "kind": "lane", "pts": [{"x": 540.0, "z": 262.0}, {"x": 556.0, "z": 262.0}], "width": 6.0, "t": 0.0, "scout": "scout_1"})
	r.state.probes.append({"id": "t2", "kind": "lane", "pts": [{"x": 300.0, "z": 403.0}, {"x": 310.0, "z": 403.0}], "width": 6.0, "t": 0.0, "scout": "scout_1"})
	var w: Dictionary = r.ford_window(548, 262)
	check(w.certain and _near(w.opens_at, 315.0, 5.0) and _near(w.closes_at, 677.0, 5.0), "ford_window del vado del buque ≈ 315..677 s (obtenido %.1f..%.1f)" % [w.opens_at, w.closes_at])
	var ws: Dictionary = r.ford_window(305, 403)
	check(ws.certain and _near(ws.opens_at, 295.0, 5.0) and _near(ws.closes_at, 688.0, 5.0), "ford_window del vado sur ≈ 295..688 s (obtenido %.1f..%.1f)" % [ws.opens_at, ws.closes_at])
	check(_near(w.depth_at_low_m, 1.0, 0.02), "Profundidad del vado del buque con el río en mínimo ≈ 1,0 m")
	r.state.probes.append({"id": "t3", "kind": "lane", "pts": [{"x": 410.0, "z": 264.0}, {"x": 420.0, "z": 264.0}], "width": 6.0, "t": 0.0, "scout": "scout_1"})
	var never: Dictionary = r.ford_window(415, 264)
	check(never.has_all(["known", "certain", "opens_at", "closes_at", "depth_at_low_m"]) and never.certain and float(never.opens_at) < 0.0 and float(never.closes_at) < 0.0, "ford_window del pozo ya sondeado: nunca abre para el caballo (opens_at = closes_at = -1)")
	# el estado sigue la marea paso a paso
	var q := _new_j()
	_advance(q, 210.0)
	check(_near(q.state.water_level_m, 0.825, 1e-6) and q.state.tide_phase == "bajando" and _near(q.state.water_level, 0.5, 1e-6), "El estado sigue la bajante (t=210)")
	_advance(q, 400.0)
	check(q.state.tide_phase == "baja" and q.state.bajante_announced and not q.state.rising_announced, "Aviso de bajante emitido y aún sin aviso de subida")
	_advance(q, 700.0)
	check(q.state.tide_phase == "subiendo" and q.state.rising_announced, "Aviso de subida emitido")

# ---------------------------------------------------------------------------
# 4. Conocimiento

func _test_knowledge() -> void:
	var r := _at(400.0)  # río en mínimo
	check(r.knowledge_at(100, 240) == "visible" and r.knowledge_at(520, 264) == "unknown" and r.knowledge_at(330, 264) == "visible", "Tierra firme y la cresta del banco emergido, visibles; el fondo turbio, desconocido")
	var base_plus: float = -0.35 - 0.35 * (85.0 / 90.0) + 0.5
	var pr: float = r.perceived_height_at(415, 264)
	check(_near(pr, base_plus, 0.03) and pr > -0.5, "Antes de sondear, perceived_height(415,264) ≈ perfil base + 0,5 (obtenido %.3f), no el pozo real" % pr)
	check(_near(r.perceived_depth_at(415, 264), r.water_level_m() - pr, 1e-9), "perceived_depth = nivel - altura percibida")
	check(r.terrain_height_at(415, 264) < -1.8, "El pozo real está a -1,9 m")
	# una sonda sobre el pozo: el explorador se detiene en el borde, lo descubre y la franja llega al centro
	r.state.next_volley = 1500.0  # se silencia el buque para aislar el sondeo (el fuego se prueba aparte)
	var o: Dictionary = r.issue_scout("scout_1", "probe", [Vector2(415, 264)])
	check(o.ok, "Orden de sondeo sobre el pozo aceptada")
	_advance(r, float(r.state.elapsed) + 260.0)
	check(r.knowledge_at(415, 264) == "probed", "Tras el sondeo, knowledge_at(pozo) = probed")
	check(_near(r.perceived_height_at(415, 264), r.terrain_height_at(415, 264), 1e-9), "Tras sondear, lo percibido es lo real")
	check("pozo_central" in r.state.hazards_found, "El pozo pasa a hazards_found")
	check(r.get_scout("scout_1").stage == "idle", "El explorador se detiene en el borde y queda libre")
	var found := false
	for e in r.state.log:
		found = found or (e.kind == "recon" and "Pozo" in str(e.text))
	check(found, "El hallazgo del pozo queda en el registro")
	# el planificador conoce el pozo y lo evita
	var plan: Dictionary = r.plan_route("arias", Vector2(470, 264), "trot")
	var skirts := true
	var prev := Vector2(r.get_unit("arias").x, r.get_unit("arias").z)
	for p in plan.path:
		var b := Vector2(p.x, p.z)
		var closest := Geometry2D.get_closest_point_to_segment(Vector2(415, 264), prev, b)
		skirts = skirts and closest.distance_to(Vector2(415, 264)) >= 10.0
		prev = b
	check(plan.ok and skirts, "La ruta planificada rodea el pozo ya descubierto")

# ---------------------------------------------------------------------------
# 5. Acciones: exito, rechazo con motivo, costo y efecto

func _test_group_actions() -> void:
	var r := _new_j()
	# list_actions / action_info
	check(r.list_actions("group") == ["move", "board", "muster", "resupply", "signal_liniers", "withdraw", "rally", "cancel"], "list_actions(group) en el orden de la UI")
	check(r.list_actions("scout") == ["probe", "mark_ford", "recall"] and r.list_actions("global") == ["distract_fire", "retreat_all"], "list_actions(scout/global)")
	check(r.action_info("muster").id == "muster" and r.action_info("nope").is_empty(), "action_info lee el JSON")
	# move
	var bad: Dictionary = r.issue_order("guemes", "move", Vector2(10, 100))
	check(not bad.ok and "barranca" in str(bad.reason), "Mover a la meseta se rechaza con causa (barranca/bajadas)")
	bad = r.issue_order("guemes", "move", Vector2(2000, 100))
	check(not bad.ok and "fuera del mapa" in str(bad.reason), "Mover fuera del mapa se rechaza")
	bad = r.issue_order("guemes", "move", Vector2(130, 120))
	check(not bad.ok and "obstáculo" in str(bad.reason), "Mover sobre el cañaveral se rechaza")
	bad = r.issue_order("guemes", "move", Vector2(415, 264))
	check(not bad.ok, "Mover al centro del banco con el río alto se rechaza (fondo estimado)")
	bad = r.issue_order("guemes", "dance")
	check(not bad.ok and "desconocida" in str(bad.reason), "Orden desconocida: Orden táctica desconocida.")
	check(not r.issue_order("guemes", "direct").ok and not r.issue_order("guemes", "flank").ok, "Las órdenes viejas direct/flank ya no existen")
	var ok: Dictionary = r.issue_order("guemes", "move", Vector2(160, 240), {"pace": "gallop"})
	check(ok.ok and ok.plan.ok and r.get_unit("guemes").stage == "moving" and r.get_unit("guemes").pace == "gallop", "Mover: acepta, planifica y guarda el ritmo")
	check(ok.plan.risk == "bajo" and float(ok.plan.length_m) > 50.0 and float(ok.plan.eta_s) > 0.0 and ok.plan.has("warnings"), "plan_route completo en tierra firme: riesgo bajo")
	_advance(r, 40.0)
	var gu: Dictionary = r.get_unit("guemes")
	check(gu.stage == "ready" and Vector2(gu.x, gu.z).distance_to(Vector2(160, 240)) < 0.5, "El grupo llega y queda libre")
	# plan_route no tiene efectos
	var ver_before := int(r.state.state_version)
	var plan: Dictionary = r.plan_route("zavala", Vector2(150, 300), "trot")
	check(plan.ok and int(r.state.state_version) == ver_before and r.get_unit("zavala").stage == "ready", "plan_route no cambia el estado")
	var wp: Dictionary = r.plan_route("zavala", Vector2(150, 300), "trot", {"waypoints": [Vector2(130, 330)]})
	check(wp.ok and float(wp.length_m) > float(plan.length_m), "plan_route admite waypoints")
	check(not r.plan_route("zavala", Vector2(150, 300), "trot", {"waypoints": [Vector2(1, 1), Vector2(2, 2), Vector2(3, 3), Vector2(4, 4), Vector2(5, 5)]}).ok, "Máximo 4 waypoints")
	# cancel
	r.issue_order("arias", "move", Vector2(170, 280))
	check(r.issue_order("arias", "cancel").ok and r.get_unit("arias").stage == "ready" and r.get_unit("arias").path.is_empty() and r.get_unit("arias").order.is_empty(), "Cancelar detiene y limpia")
	# rally: en la playa sí; en el agua no
	check(r.issue_order("zavala", "rally").ok and r.get_unit("zavala").stage == "rally", "Reagrupar en la playa seca")
	var rr := _at(400.0)
	rr.state.units[1].x = 330.0
	rr.state.units[1].z = 264.0
	var rej: Dictionary = rr.issue_order("arias", "rally")
	check(not rej.ok and "playa seca" in str(rej.reason), "Reagrupar dentro del agua se rechaza con causa")
	# withdraw
	var wd: Dictionary = rr.issue_order("arias", "withdraw")
	check(wd.ok and rr.get_unit("arias").stage == "moving", "Retirar a la playa seca desde el banco")
	check(not r.issue_order("guemes", "withdraw").ok and "playa seca" in str(r.issue_order("guemes", "withdraw").reason), "Retirar desde la playa se rechaza (ya está a salvo)")
	# señalar a Liniers
	var s := _new_j()
	var ammo0 := int(s.state.ammo)
	var sig: Dictionary = s.issue_order("guemes", "signal_liniers")
	check(sig.ok and s.get_unit("guemes").stage == "moving" and not s.state.advance_authorized, "Señalar: marcha primero al puesto de mando")
	_advance(s, 50.0)
	check(s.get_unit("guemes").stage == "working" and s.get_unit("guemes").work.kind == "signal", "Señalar: trabaja 10 s en el puesto")
	_advance(s, 70.0)
	check(s.state.advance_authorized and int(s.state.ammo) == ammo0 + 8 and s.get_unit("guemes").stage == "ready", "Señalar concede el avance y +8 de munición")
	var again: Dictionary = s.issue_order("guemes", "signal_liniers")
	check(not again.ok and "ya fue concedida" in str(again.reason), "Señalar dos veces se rechaza")
	# abastecer
	var ra := _new_j()
	check(ra.issue_order("zavala", "resupply").ok, "Abastecer acepta")
	var t_start := float(ra.state.elapsed)
	var reached := -1.0
	for i in range(200):
		ra.tick(1.0)
		if reached < 0.0 and ra.get_unit("zavala").stage == "working":
			reached = float(ra.state.elapsed)
		if int(ra.state.ammo) > 16:
			break
	check(int(ra.state.ammo) == 32 and reached > 0.0 and float(ra.state.elapsed) - reached >= 24.0 and float(ra.state.elapsed) - reached <= 27.0, "Abastecer: +16 de munición tras 25 s de trabajo en la batería")
	ra.state.ammo = int(ra.state.ammo_max)
	var full: Dictionary = ra.issue_order("arias", "resupply")
	check(not full.ok and "lleno" in str(full.reason), "Abastecer con el depósito lleno se rechaza")
	# reunir
	var rm := _new_j()
	var st0 := float(rm.get_unit("arias").strength)
	check(rm.issue_order("arias", "muster").ok, "Reunir acepta")
	for i in range(200):
		rm.tick(1.0)
		if rm.get_unit("arias").stage == "ready" and float(rm.get_unit("arias").strength) > st0:
			break
	check(_near(rm.get_unit("arias").strength, st0 + 25.0, 0.001) and _near(rm.state.volunteers_pool, 35.0, 0.001) and _near(rm.state.stats.muster_gain, 25.0, 0.001), "Reunir: +25 de fuerza tomados del reservorio (60 → 35)")
	var full_strength: Dictionary = rm.issue_order("guemes", "muster")
	check(not full_strength.ok and "100" in str(full_strength.reason), "Reunir con fuerza completa se rechaza")
	rm.state.volunteers_pool = 0.0
	var empty: Dictionary = rm.issue_order("zavala", "muster")
	check(not empty.ok and "voluntarios" in str(empty.reason), "Reunir sin voluntarios se rechaza")
	# disponibilidad (sin efectos)
	var av_ok: Dictionary = _new_j().action_availability("guemes", "muster")
	check(av_ok.ok == false and "100" in str(av_ok.reason), "action_availability: reunir con fuerza completa queda bloqueado con motivo")
	var av: Dictionary = _new_j().action_availability("zavala", "board")
	check(not av.ok and "Liniers" in str(av.reason) and av.tag == "diseno" and av.cost_text != "", "Disponibilidad de board: bloqueada por la orden de avance, con tag y costo")
	var av2: Dictionary = _new_j().action_availability("zavala", "signal_liniers")
	check(av2.ok and av2.tag == "tradicion" and "10 s" in av2.cost_text and "munición" in av2.cost_text, "Disponibilidad de señalar: tag tradición y costo")
	var av3: Dictionary = _new_j().action_availability("scout_1", "mark_ford")
	check(av3.ok and "baliza" in av3.cost_text, "Disponibilidad de marcar vado: costo en balizas")
	var av4: Dictionary = _new_j().action_availability("global", "distract_fire")
	check(av4.ok and av4.cost_text == "8 munición · 45 s", "Disponibilidad de distraer: costo '8 munición · 45 s'")
	var routed := _new_j()
	routed.state.units[2].strength = 3.0
	check(not routed.issue_order("zavala", "move", Vector2(150, 300)).ok, "Un grupo disperso no recibe órdenes")

func _test_plan_risk() -> void:
	var r := _at(300.0)
	r.state.advance_authorized = true
	r.state.orders.append({"time": 0.0, "round": 1, "unit": "guemes", "action": "signal_liniers", "target": {}})
	r.state.first_order_at = 0.0
	var far: Dictionary = r.plan_route("arias", r.board_point(), "trot")
	check(far.ok and far.risk == "alto" and float(far.unknown_m) > 80.0 and float(far.exposed_s) > 0.0 and float(far.max_depth_m) > 0.0, "Cruce largo sin reconocer: riesgo alto, metros sin reconocer y exposición (%.0f m sin reconocer)" % float(far.unknown_m))
	check(far.has_all(["path", "length_m", "eta_s", "unknown_m", "exposed_s", "max_depth_m", "arrives_in_window", "risk", "warnings"]) and far.path[far.path.size() - 1].x == 548.0, "plan_route devuelve todos los campos del contrato y termina en el destino")
	var beach: Dictionary = r.plan_route("arias", Vector2(160, 250), "gallop")
	check(beach.ok and beach.risk == "bajo" and float(beach.unknown_m) == 0.0 and float(beach.exposed_s) == 0.0, "Marcha por la playa: riesgo bajo, sin exposición")
	r.get_unit("arias").x = 300.0
	r.get_unit("arias").z = 264.0
	var short: Dictionary = r.plan_route("arias", Vector2(330, 264), "trot")
	check(short.ok and short.risk == "desconocido", "Tramo corto hacia un destino en agua sin reconocer: riesgo desconocido")
	var gallop: Dictionary = r.plan_route("arias", Vector2(340, 264), "gallop")
	var trot: Dictionary = r.plan_route("arias", Vector2(340, 264), "trot")
	check(absf(float(gallop.eta_s) - float(trot.eta_s)) < 0.5, "En agua el galope no acorta la ETA (se limita al trote)")
	var win: Dictionary = r.plan_route("arias", r.board_point(), "trot")
	check(win.ok and win.arrives_in_window == (float(r.state.elapsed) + float(win.eta_s) <= r.ford_window(548, 262).closes_at), "arrives_in_window sigue a ford_window del vado del buque")
	# tras sondear el trayecto el riesgo baja
	r.state.probes.append({"id": "t1", "kind": "lane", "pts": [{"x": 300.0, "z": 264.0}, {"x": 345.0, "z": 264.0}], "width": 6.0, "t": 0.0, "scout": "scout_1"})
	var known: Dictionary = r.plan_route("arias", Vector2(340, 264), "trot")
	check(known.ok and float(known.unknown_m) < float(short.unknown_m) and known.risk != "alto", "Con el tramo sondeado bajan los metros sin reconocer (%.0f -> %.0f m)" % [float(short.unknown_m), float(known.unknown_m)])

func _test_scout_and_global_actions() -> void:
	var r := _at(260.0)
	check(not r.issue_scout("scout_1", "probe", []).ok, "Sondear sin puntos se rechaza")
	var many: Array = [Vector2(250, 250), Vector2(260, 250), Vector2(270, 250), Vector2(280, 250)]
	var m4: Dictionary = r.issue_scout("scout_1", "probe", many)
	check(not m4.ok and "Máximo 3" in str(m4.reason), "Más de 3 puntos se rechaza")
	check(not r.issue_scout("scout_1", "probe", [Vector2(-5, 10)]).ok and not r.issue_scout("scout_1", "probe", [Vector2(130, 120)]).ok, "Puntos fuera del mapa o sobre un obstáculo se rechazan")
	var probes0: int = r.state.probes.size()
	var pm0 := float(r.state.stats.probe_m)
	check(r.issue_scout("scout_1", "probe", [Vector2(250, 246), Vector2(296, 246)]).ok, "Sondear acepta hasta 3 puntos")
	var grew := false
	var lens: Array = []
	for i in range(12):
		_advance(r, float(r.state.elapsed) + 10.0)
		var n := 0
		for p in r.state.probes:
			n += p.pts.size()
		lens.append(n)
	grew = lens[lens.size() - 1] > lens[2] and lens[2] > 1
	check(r.state.probes.size() > probes0 and grew, "La franja sondeada crece mientras el explorador avanza")
	check(float(r.state.stats.probe_m) > pm0 + 20.0, "stats.probe_m acumula los metros sondeados en el agua")
	check(r._probe_kind_at(275, 246) == 1, "El carril sondeado figura como probed (capa de sondas)")
	# marcar: fuera de carril, sin balizas, ok y costo
	var off: Dictionary = r.issue_scout("scout_2", "mark_ford", [Vector2(400, 300)])
	check(not off.ok and "sondeado" in str(off.reason), "Marcar fuera de un carril sondeado se rechaza")
	var bal0 := int(r.state.balizas)
	var mk: Dictionary = r.issue_scout("scout_2", "mark_ford", [Vector2(270, 246), Vector2(290, 246)])
	check(mk.ok, "Marcar sobre el carril acepta")
	_advance(r, float(r.state.elapsed) + 120.0)
	check(int(r.state.balizas) == bal0 - 2 and int(r.state.stats.balizas_used) == 2 and _near(r.state.stats.marked_m, 20.0, 0.6), "Marcar 20 m gasta 2 balizas (1 cada 10 m)")
	check(r._probe_kind_at(280, 246) == 2, "El tramo trabajado queda marcado (capa de sondas)")
	var low := int(r.state.balizas)
	r.state.balizas = 1
	var short: Dictionary = r.issue_scout("scout_2", "mark_ford", [Vector2(270, 246), Vector2(290, 246)])
	check(not short.ok and "Faltan balizas (quedan 1)." == str(short.reason), "Faltan balizas: motivo con el saldo")
	r.state.balizas = low
	# recall
	check(r.issue_scout("scout_1", "recall").ok, "Replegar al explorador acepta")
	# explorador perdido
	r.state.scouts[1].hp = 0
	r.state.scouts[1].stage = "lost"
	var lost: Dictionary = r.issue_scout("scout_2", "probe", [Vector2(260, 250)])
	check(not lost.ok and "abatido" in str(lost.reason), "Un explorador perdido no recibe órdenes")
	# apoyo de fuego
	var f := _new_j()
	var a0 := int(f.state.ammo)
	var cf: Dictionary = f.call_fire_support()
	check(cf.ok and int(f.state.ammo) == a0 - 8 and _near(f.state.fire_support.until, 45.0, 1e-6) and _near(f.state.fire_support.ready_at, 90.0, 1e-6) and _near(f.state.crew_morale, 98.0, 1e-6), "Distraer: -8 munición, 45 s de duración, recarga 90 s, moral -2")
	check(f.state.log[f.state.log.size() - 1].kind == "fire_support" and f.ship_state().fire_support_active, "Distraer deja evento fire_support y activa el apoyo")
	var again: Dictionary = f.call_fire_support()
	check(not again.ok and "recarga" in str(again.reason), "Distraer durante la recarga se rechaza")
	_advance(f, 95.0)
	check(not f.ship_state().fire_support_active and f.call_fire_support().ok and int(f.state.ammo) == a0 - 16, "Tras la recarga se puede repetir (2 usos agotan 16)")
	_advance(f, 200.0)
	var none: Dictionary = f.call_fire_support()
	check(not none.ok and "municiones" in str(none.reason), "Sin munición no hay fuego de distracción")
	# retirada general
	var rt := _at(100.0)
	check(rt.retreat_all().ok and rt.state.status == "defeat" and "Retirada general" in str(rt.state.reason), "Retirada general termina la partida como derrota")
	check(not rt.issue_order("guemes", "move", Vector2(150, 240)).ok and not rt.retreat_all().ok and not rt.issue_scout("scout_1", "recall").ok, "Terminada la partida no se aceptan órdenes")
	check(rt.campaign_report().outcome_title == "Retirada general", "El parte nombra la retirada")

func _test_board_gate() -> void:
	var r := _at(300.0)
	var no: Dictionary = r.issue_order("zavala", "board")
	check(not no.ok and str(no.reason) == "Falta la orden de avance de Liniers: señalá primero.", "board sin orden de avance rechaza con el motivo exacto")
	r.state.advance_authorized = true
	r.state.orders.append({"time": 0.0, "round": 1, "unit": "guemes", "action": "signal_liniers", "target": {}})
	r.state.first_order_at = 0.0
	var yes: Dictionary = r.issue_order("zavala", "board")
	check(yes.ok and r.get_unit("zavala").order.action == "board", "board con la orden de avance acepta")
	# antes de que la ruta sea creible el plan lo rechaza con causa
	var early := _new_j()
	early.state.advance_authorized = true
	early.state.orders.append({"time": 0.0, "round": 1, "unit": "guemes", "action": "signal_liniers", "target": {}})
	early.state.first_order_at = 0.0
	var rej: Dictionary = early.issue_order("zavala", "board")
	check(not rej.ok and "estimado" in str(rej.reason), "Con el río alto, board se rechaza por el fondo estimado")

func _test_fire_and_exposure() -> void:
	var r := _new_j()
	check(_near(r.exposure_at(500, 262), 1.0, 1e-9), "Exposición 1,0 por la banda (este-oeste)")
	check(_near(r.exposure_at(560, 380), 0.25, 1e-9), "Exposición 0,25 por proa/popa")
	check(_near(r.exposure_at(480, 360), 0.5, 1e-9), "Exposición 0,5 por el cuartel")
	check(r.exposure_at(200, 262) == 0.0 and r.exposure_at(299, 262) == 0.0 and r.exposure_at(301, 262) > 0.0, "Fuera de 280 m no hay fuego; dentro sí")
	check(r.exposure_at(100, 240) == 0.0, "En la playa no hay fuego")
	r.state.fire_support = {"until": 45.0, "ready_at": 90.0}
	check(_near(r.exposure_at(500, 262), 0.5, 1e-9), "El fuego de distracción reduce la exposición a la mitad")
	# la dotación pierde moral y dispara mas lento
	var d := _at(400.0)
	d.state.units[0].x = 450.0
	d.state.units[0].z = 262.0
	var hp0 := float(d.state.units[0].strength)
	var nv := float(d.state.elapsed) + 0.5
	d.state.next_volley = nv
	_advance(d, float(d.state.elapsed) + 2.0)
	var dmg := hp0 - float(d.state.units[0].strength)
	check(dmg >= 3.2 - 0.001 and dmg <= 5.0 + 0.001, "Una descarga causa 3,2-5,0 de daño en exposición 1 (obtenido %.2f)" % dmg)
	check(d.state.stats.shots_taken == 1 and _near(d.state.next_volley, nv + 7.5, 1e-9), "La siguiente descarga llega a los 7,5 s")
	var ex := _at(400.0)
	ex.state.units[0].x = 450.0
	ex.state.units[0].z = 262.0
	var nv2 := float(ex.state.elapsed) + 0.5
	ex.state.next_volley = nv2
	ex.state.fire_support = {"until": float(ex.state.elapsed) + 45.0, "ready_at": float(ex.state.elapsed) + 90.0}
	_advance(ex, float(ex.state.elapsed) + 2.0)
	check(_near(ex.state.next_volley, nv2 + 7.5 + 2.0, 1e-9) and float(ex.state.units[0].strength) > 100.0 - 5.0 * 0.5 - 0.001, "Con apoyo de fuego: +2 s entre descargas y daño a la mitad")
	# explorador alcanzado
	var s := _at(400.0)
	s.state.units[0].x = 100.0
	s.state.scouts[0].x = 450.0
	s.state.scouts[0].z = 262.0
	for u in s.state.units:
		u.x = 100.0
	s.state.scouts[1].x = 120.0
	for i in range(4):
		s.state.next_volley = float(s.state.elapsed) + 1.0
		_advance(s, float(s.state.elapsed) + 2.0)
	check(int(s.state.scouts[0].hp) == 0 and s.state.scouts[0].stage == "lost" and int(s.state.stats.scouts_lost) == 1, "Un explorador sin cobertura cae tras 3 impactos y cuenta como perdido")

# ---------------------------------------------------------------------------
# 6. Estrategias scripteadas (simulacion completa)

class Sim:
	var r: RefCounted
	var mem: Dictionary = {}
	var t := 0.0

func _signal_and_resupply(s: Sim) -> void:
	if not s.mem.has("signal"):
		s.mem.signal = s.r.issue_order("guemes", "signal_liniers").ok
	if s.r.state.advance_authorized and s.r.get_unit("guemes").stage == "ready" and not s.mem.has("resupply") and int(s.r.state.ammo) < 36:
		s.mem.resupply = s.r.issue_order("guemes", "resupply").ok

func _muster_both(s: Sim) -> void:
	## Reúne jinetes dos veces cada grupo hasta agotar el reservorio de 60.
	for round_i in range(2):
		var key: String = "muster%d" % round_i
		if s.mem.has(key):
			continue
		var ready := true
		for id in ["arias", "zavala"]:
			ready = ready and s.r.get_unit(id).stage == "ready"
		if round_i == 1 and not s.mem.has("muster0"):
			continue
		if ready and (round_i == 0 or s.t >= 100.0):
			s.mem[key] = s.r.issue_order("arias", "muster").ok and s.r.issue_order("zavala", "muster").ok
			break

func _greedy_fire(s: Sim) -> void:
	## Pide fuego de distracción cuando hay algun grupo bajo el alcance del buque.
	var exposed := false
	for u in s.r.state.units:
		if s.r.exposure_at(float(u.x), float(u.z)) > 0.0 and u.stage == "moving":
			exposed = true
	if exposed and s.r.call_fire_support().ok:
		s.mem.fire_uses = int(s.mem.get("fire_uses", 0)) + 1

func _stage_groups(s: Sim, point: Vector2, from_t: float, spacing: float = 14.0) -> void:
	if s.t < from_t:
		return
	var i := 0
	for id in ["guemes", "arias", "zavala"]:
		var key: String = "stage_" + id
		var u: Dictionary = s.r.get_unit(id)
		if not s.mem.has(key) and u.stage == "ready":
			s.mem[key] = s.r.issue_order(id, "move", point + Vector2(0, (i - 1) * spacing), {"pace": "trot"}).ok
		i += 1

func _try_board(s: Sim, id: String, waypoints: Array = []) -> void:
	var key: String = "board_" + id
	if s.mem.has(key) or not s.r.state.advance_authorized:
		return
	var u: Dictionary = s.r.get_unit(id)
	if u.stage != "ready":
		return
	var o: Dictionary = s.r.issue_order(id, "board", Vector2.ZERO, {"pace": "trot", "waypoints": waypoints})
	if o.ok:
		s.mem[key] = s.t

func _policy_rush_central(s: Sim) -> void:
	_signal_and_resupply(s)
	for id in ["arias", "zavala", "guemes"]:
		_try_board(s, id)

func _policy_north_edge_central(s: Sim) -> void:
	## Centro por el borde norte del banco, a 20 m del pozo (el jugador sabe del pozo por un tropiezo anterior o por la sonda):
	## reunir jinetes, abastecer, esperar en la playa y cruzar juntos con fuego de distracción.
	_signal_and_resupply(s)
	_muster_both(s)
	_stage_groups(s, Vector2(255, 244), 180.0)
	for id in ["guemes", "arias", "zavala"]:
		_try_board(s, id, [Vector2(330, 240), Vector2(480, 240)])
	_greedy_fire(s)

func _policy_recon_south(s: Sim) -> void:
	## Sondear el borde del vado (fuera del alcance del buque), marcar el carril de acceso, esperar a que abra y cruzar juntos.
	_signal_and_resupply(s)
	_muster_both(s)
	if s.t >= 150.0 and not s.mem.has("scout"):
		s.mem.scout = s.r.issue_scout("scout_1", "probe", [Vector2(205, 400), Vector2(268, 402)]).ok
	if s.t >= 270.0 and not s.mem.has("mark"):
		s.mem.mark = s.r.issue_scout("scout_2", "mark_ford", [Vector2(230, 401), Vector2(255, 402)]).ok
	_stage_groups(s, Vector2(255, 402), 150.0, 1.0)
	if "vado_sur" in s.r.state.fords_found:
		for id in ["guemes", "arias", "zavala"]:
			_try_board(s, id, SOUTH_WAYPOINTS)
	_greedy_fire(s)

func _policy_expo_central(s: Sim) -> void:
	## Comparación de exposición: los mismos tres grupos, sin fuego de distracción ni refuerzos, por el borde norte del banco central.
	_signal_and_resupply(s)
	_stage_groups(s, Vector2(255, 244), 180.0)
	for id in ["guemes", "arias", "zavala"]:
		_try_board(s, id, [Vector2(330, 240), Vector2(480, 240)])

func _policy_expo_south(s: Sim) -> void:
	_signal_and_resupply(s)
	if s.t >= 150.0 and not s.mem.has("scout"):
		s.mem.scout = s.r.issue_scout("scout_1", "probe", [Vector2(205, 400), Vector2(268, 402)]).ok
	_stage_groups(s, Vector2(255, 402), 150.0, 1.0)
	if "vado_sur" in s.r.state.fords_found:
		for id in ["guemes", "arias", "zavala"]:
			_try_board(s, id, SOUTH_WAYPOINTS)
func _policy_late(s: Sim) -> void:
	_signal_and_resupply(s)
	if s.t >= 690.0:
		for id in ["arias", "zavala", "guemes"]:
			_try_board(s, id)

func _policy_mixed(s: Sim) -> void:
	## La vanguardia por el centro (borde norte) y los otros dos por el sur.
	_signal_and_resupply(s)
	_muster_both(s)
	if s.t >= 150.0 and not s.mem.has("scout"):
		s.mem.scout = s.r.issue_scout("scout_1", "probe", [Vector2(205, 400), Vector2(268, 402)]).ok
	if s.t >= 150.0 and not s.mem.has("stage"):
		var g: bool = s.r.issue_order("guemes", "move", Vector2(255, 244), {"pace": "trot"}).ok
		var a: bool = s.r.issue_order("arias", "move", Vector2(255, 400), {"pace": "trot"}).ok
		var z: bool = s.r.issue_order("zavala", "move", Vector2(255, 403), {"pace": "trot"}).ok
		s.mem.stage = g and a and z
	_try_board(s, "guemes", [Vector2(330, 240), Vector2(480, 240)])
	if "vado_sur" in s.r.state.fords_found:
		for id in ["arias", "zavala"]:
			_try_board(s, id, SOUTH_WAYPOINTS)
	_greedy_fire(s)
func _run_strategy(policy: String, seed_value: int = 7) -> Dictionary:
	var s := Sim.new()
	s.r = _new_j(seed_value)
	var guard := 0
	var stranded := 0
	var prev_zero := {}
	var trace: bool = ("--trace=" + policy) in OS.get_cmdline_user_args()
	while s.r.state.status == "playing" and guard < 4000:
		call("_policy_" + policy, s)
		if trace and guard % 120 == 0:
			var line := ""
			for u in s.r.state.units:
				line += " %s[%s %.0f,%.0f s=%.0f f=%.0f]" % [u.id, u.stage, u.x, u.z, u.strength, u.fatigue]
			print("  t=%d cap=%.1f ammo=%d lvl=%.2f%s" % [int(s.r.state.elapsed), s.r.state.capture, s.r.state.ammo, s.r.water_level_m(), line])
		for k in range(4):
			s.r.tick(0.25)
			guard += 1
			for u in s.r.state.units:
				if u.stage in ["boarding", "dismounting", "routed"]:
					continue
				var zero: bool = s.r.speed_at(float(u.x), float(u.z), "walk", u.mounted) <= 0.0
				if zero and prev_zero.get(u.id, false):
					stranded += 1
				prev_zero[u.id] = zero
		s.t = float(s.r.state.elapsed)
	var rep: Dictionary = s.r.campaign_report()
	var loss := 0.0
	var start := 0.0
	for g in rep.groups:
		loss += float(g.start_strength) - float(g.end_strength)
		start += float(g.start_strength)
	return {"policy": policy, "status": s.r.state.status, "t": float(s.r.state.elapsed), "loss_pct": loss / start * 100.0, "stumbles": int(s.r.state.stats.stumbles),
		"exposure": s.r.state.stats.exposure_s.duplicate(true), "route": rep.route, "ammo_used": int(s.r.state.stats.ammo_used), "probe_m": float(s.r.state.stats.probe_m),
		"stranded": stranded, "report": rep, "fire_uses": int(s.mem.get("fire_uses", 0)), "capture": float(s.r.state.capture), "boarded_at": float(s.r.state.stats.boarded_at), "sim": s}

func _test_strategies() -> void:
	var results := {}
	for p in ["rush_central", "north_edge_central", "recon_south", "mixed", "late", "expo_central", "expo_south"]:
		results[p] = _run_strategy(p)
		var slim: Dictionary = results[p].duplicate()
		slim.erase("report")
		slim.erase("sim")
		report.results.append({"scenario": "justine", "strategy": p, "result": slim})
	var rush: Dictionary = results.rush_central
	check(rush.stumbles >= 1, "Ruta central a ciegas: algún grupo tropieza en el pozo (tropiezos: %d)" % rush.stumbles)
	check(rush.loss_pct >= 30.0, "Ruta central a ciegas: bajas ≥ 30 %% de la fuerza (obtenido %.1f %%)" % rush.loss_pct)
	check(rush.status == "defeat", "Ruta central a ciegas, sin reunir ni distraer, no basta para ganar")
	var cen: Dictionary = results.north_edge_central
	var sur: Dictionary = results.recon_south
	var mix: Dictionary = results.mixed
	check(cen.status == "victory" and cen.stumbles == 0, "Reconocer + central gana sin tropezar (estado %s, t=%.0f)" % [cen.status, cen.t])
	check(sur.status == "victory" and sur.stumbles == 0, "Reconocer el vado + sur gana sin tropezar (estado %s, t=%.0f)" % [sur.status, sur.t])
	var target: Dictionary = Rules.new().map_data().play_targets
	report.results.append({"scenario": "justine", "strategy": "play_targets_vs_measured", "recon_central_victory_s": cen.t, "target_central_s": target.recon_then_central.victory_before_s,
		"recon_south_victory_s": sur.t, "target_south_s": target.recon_then_south.victory_before_s,
		"note": "Los objetivos 760/800 s del JSON no se alcanzan con estas cifras; ver docs/DISENO_REGLAS.md (balance)."})
	# duracion de partida: 12-18 min
	for res in [cen, sur]:
		if res.status == "victory":
			check(float(res.t) >= 10.0 * 60.0 and float(res.t) <= 15.0 * 60.0, "%s: la victoria llega entre los 10 y los 15 min (%.1f min; el plazo la acota en 15)" % [res.policy, float(res.t) / 60.0])
	# ningun camino unico domina: el centro llega antes pero se expone mas; el sur llega despues y casi no recibe fuego.
	if cen.status == "victory" and sur.status == "victory":
		check(float(cen.t) < float(sur.t) and float(cen.exposure.central) > float(sur.exposure.sur), "Centro y sur son un intercambio: el centro es más rápido (%.0f s vs %.0f s) y más expuesto (%.0f vs %.0f s)" % [cen.t, sur.t, cen.exposure.central, sur.exposure.sur])
		check(cen.route == "central" and sur.route == "sur", "El parte identifica la ruta usada")
	var ec0: Dictionary = results.expo_central
	var es0: Dictionary = results.expo_south
	check(ec0.status == "victory" and float(ec0.t) > float(cen.t) and es0.status == "defeat", "Sin refuerzos ni apoyo de fuego el centro gana tarde y el sur ya no alcanza el plazo: los recursos importan")
	check(float(ec0.loss_pct) > 30.0 and float(es0.loss_pct) > 30.0, "Sin refuerzos ni apoyo, cualquiera de las dos rutas cuesta más del 30 %% de la fuerza")
	var ec: Dictionary = results.expo_central
	var es: Dictionary = results.expo_south
	check(float(ec.exposure.central) >= 1.4 * float(es.exposure.sur), "Exposición acumulada del centro ≥ 1,4 × la del sur con los mismos tres grupos y sin apoyo (%.0f vs %.0f)" % [ec.exposure.central, es.exposure.sur])
	check(mix.status in ["victory", "defeat"] and (mix.route in ["mixta", "central", "sur"]), "La estrategia mixta termina con parte coherente (%s, %s)" % [mix.status, mix.route])
	var late: Dictionary = results.late
	check(late.status == "defeat" and float(late.capture) < 100.0, "Salir tarde pierde: con el río subiendo no se puede abordar")
	var passive := _new_j()
	for i in range(16):
		passive.tick(60)
	check(passive.state.status == "defeat" and _near(passive.state.elapsed, 900.0, 1e-6), "Pasividad: derrota exactamente en t = 900 s")
	check(passive.campaign_report().outcome_title == "Plazo agotado", "El parte nombra el plazo agotado")
	var casualties := _new_j()
	for u in casualties.state.units:
		u.strength = 0.0
	casualties.tick(1)
	check(casualties.state.status == "defeat" and casualties.campaign_report().outcome_title == "Grupos dispersos", "La dispersión de todos los grupos es derrota")
	# parte de campaña
	var rep: Dictionary = cen.report
	check(rep.status == "victory" and rep.outcome_title == "Buque capturado" and rep.groups.size() == 3 and rep.history.size() >= 5, "campaign_report: victoria, tres grupos y 'Qué fue historia'")
	var tags: Array = []
	var joined := ""
	for h in rep.history:
		tags.append(h.tag)
		joined += str(h.text).to_lower() + " "
	check("documentado" in tags and "tradicion" in tags and "diseno" in tags, "La historia fija usa las etiquetas documentado, tradición y diseño")
	check("26 cañones" in joined and "pueyrredón" in joined and "tradición no probada" in joined and "divulgativa" in joined, "La historia fija menciona el mercante de 26 cañones, Pueyrredón, la tradición de Güemes y la cifra divulgativa")
	check(not ("fragata" in joined) and not ("goleta" in joined) and not ("bandera argentina" in joined and "con bandera" in joined), "La historia no inventa tipo de buque")
	check(rep.boarded_at > 0.0 and rep.level_at_boarding >= 0.0 and rep.ammo_used >= 0 and rep.groups[0].tag == "tradicion", "El parte registra el abordaje y las etiquetas")
	print("ESTRATEGIAS: ", JSON.stringify(report.results.slice(report.results.size() - 8)))

func _test_speed_never_exceeded() -> void:
	# Muestreo de 200+ pasos: el desplazamiento por paso nunca supera speed_at del punto de partida.
	var r := _new_j(3)
	r.issue_order("guemes", "signal_liniers")
	var samples := 0
	var violations := 0
	var worst := 0.0
	var t_end := 700.0
	var board_done := false
	while r.state.status == "playing" and float(r.state.elapsed) < t_end:
		if float(r.state.elapsed) >= 285.0 and not board_done:
			for id in ["guemes", "arias", "zavala"]:
				r.issue_order(id, "board", Vector2.ZERO, {"pace": "gallop"})
			board_done = true
		var before: Array = []
		for u in r.state.units:
			before.append({"p": Vector2(u.x, u.z), "stage": u.stage, "pace": u.pace, "mounted": u.mounted})
		r.tick(0.25)
		for i in range(r.state.units.size()):
			var u: Dictionary = r.state.units[i]
			if before[i].stage == "moving" and u.stage == "moving":
				var d: float = (Vector2(u.x, u.z) - before[i].p).length() / 0.25
				var cap: float = r.speed_at(before[i].p.x, before[i].p.y, before[i].pace, before[i].mounted)
				samples += 1
				if d > cap + 1e-3:
					violations += 1
					worst = maxf(worst, d - cap)
	check(samples >= 200 and violations == 0, "Ningún grupo supera speed_at en %d pasos muestreados (violaciones: %d, peor exceso %.4f)" % [samples, violations, worst])

func _test_not_stranded() -> void:
	# Barrido: ordenes aceptadas a distintas horas no dejan grupos varados ni dentro del agua honda.
	var stranded := 0
	var accepted := 0
	for start in range(0, 880, 90):
		for action in ["board", "move_bank"]:
			var r := _at(float(start), 9)
			r.state.advance_authorized = true
			r.state.orders.append({"time": 0.0, "round": 1, "unit": "guemes", "action": "signal_liniers", "target": {}})
			r.state.first_order_at = 0.0
			var o: Dictionary
			if action == "board":
				o = r.issue_order("zavala", "board", Vector2.ZERO, {"pace": "gallop"})
			else:
				o = r.issue_order("zavala", "move", Vector2(330, 264), {"pace": "gallop"})
			if not o.ok:
				continue
			accepted += 1
			var zero_ticks := 0
			var guard := 0
			while r.state.status == "playing" and guard < 4000:
				r.tick(0.25)
				guard += 1
				var z: Dictionary = r.get_unit("zavala")
				if z.stage not in ["boarding", "dismounting", "routed"] and r.speed_at(float(z.x), float(z.z), "walk", z.mounted) <= 0.0:
					zero_ticks += 1
				else:
					zero_ticks = 0
				if zero_ticks >= 2:
					stranded += 1
					break
	check(accepted >= 4 and stranded == 0, "Ninguna orden aceptada deja un grupo varado en el agua (%d aceptadas, %d varadas)" % [accepted, stranded])
	# Rescate: un grupo atrapado por la subida vuelve a un punto firme de la playa.
	var rescue := _at(700.0)
	var g: Dictionary = rescue.get_unit("guemes")
	g.x = 415.0
	g.z = 264.0
	g.stage = "ready"
	g.order = {}
	check(rescue.speed_at(415, 264, "walk", true) == 0.0, "El grupo de prueba queda en el pozo, bajo el agua honda")
	rescue.state.accumulator = 0.0
	rescue.tick(0.25)
	g = rescue.get_unit("guemes")
	check(rescue.speed_at(float(g.x), float(g.z), "walk", true) > 0.0 and g.stage == "ready" and g.order.is_empty() and g.path.is_empty() and float(g.x) < 240.0, "Rescate: vuelve a la playa con estado limpio")
	check(float(g.fatigue) >= 10.0, "El rescate suma +10 de fatiga")
	var warned := false
	for e in rescue.state.log:
		warned = warned or e.kind == "warning"
	check(warned, "El rescate queda en el registro")
	check(rescue.validate_snapshot(rescue.snapshot()).ok, "El estado tras el rescate es un guardado coherente")
	# Un grupo que entra a un punto no reconocido y hondo tropieza y no se mete en el agujero
	var st := _at(380.0)
	var h: Dictionary = st.get_unit("arias")
	h.x = 380.0
	h.z = 264.0
	h.path = [{"x": 440.0, "z": 264.0}]
	h.order = {"action": "move", "x": 440.0, "z": 264.0}
	h.stage = "moving"
	h.pace = "trot"
	var hit := false
	for i in range(400):
		st.tick(0.25)
		var a: Dictionary = st.get_unit("arias")
		if a.stage == "stumbling":
			hit = true
			check(st.speed_at(float(a.x), float(a.z), "walk", true) > 0.0, "El grupo que tropieza queda en un punto transitable")
			check(float(a.stumble_remaining) > 0.0 and float(a.stumble_remaining) <= 20.0, "El tropiezo detiene hasta 20 s")
			break
	check(hit and st.state.stats.stumbles == 1 and "pozo_central" in st.state.hazards_found, "El tropiezo se registra y el pozo pasa a hazards_found")
	check(_near(st.get_unit("arias").strength, 70.0 - 3.0, 0.5) or st.get_unit("arias").strength < 70.0, "El tropiezo cuesta fuerza")
	var passes := 0
	for i in range(1200):
		st.tick(0.25)
		var a2: Dictionary = st.get_unit("arias")
		if st.speed_at(float(a2.x), float(a2.z), "walk", true) <= 0.0 and a2.stage not in ["routed"]:
			passes += 1
	check(passes == 0, "Tras tropezar, el grupo nunca queda dentro del pozo")

# ---------------------------------------------------------------------------
# 7. Guardado de Justina

func _busy_game() -> RefCounted:
	## Partida con sondas, balizas, trabajo en curso, exploradores y un grupo en marcha.
	var r := _new_j(11)
	r.issue_order("guemes", "signal_liniers")
	r.issue_order("arias", "muster")
	_advance(r, 200.0)
	r.issue_scout("scout_1", "probe", [Vector2(250, 246), Vector2(296, 246)])
	_advance(r, 300.0)
	r.issue_scout("scout_2", "mark_ford", [Vector2(270, 246), Vector2(290, 246)])
	r.issue_order("zavala", "move", Vector2(250, 300), {"pace": "gallop"})
	_advance(r, 345.0)
	return r

func _test_justine_persistence() -> void:
	var r := _busy_game()
	check(r.state.probes.size() >= 1 and r.validate_snapshot(r.snapshot()).ok, "Partida con sondas y exploradores produce un guardado válido")
	var path := "user://test-rules-justine.json"
	check(r.save_game(path) == OK and r.save_game(path) == OK, "Guardar y reemplazar Justina")
	var loaded := Rules.new()
	check(loaded.load_game(path).ok, "Cargar Justina")
	var a: Dictionary = r.snapshot()
	var b: Dictionary = loaded.snapshot()
	for key in ["game_id", "previous_game_id", "state_version"]:
		a.erase(key)
		b.erase(key)
	var al: Array = a.log
	var bl: Array = b.log
	b.log = bl.slice(0, bl.size() - 1)
	check(bl[bl.size() - 1].kind == "load" and bl.size() == al.size() + 1, "Cargar agrega el evento load")
	check(_equivalent(a, b), "Guardar y cargar no cambia el estado (tolerancia 1e-6)")
	check(int(r.state.rng_state) == int(loaded.state.rng_state), "El estado del RNG se conserva exacto")
	check(loaded.state.game_id != r.state.game_id and loaded.state.previous_game_id == r.state.game_id, "Cargar crea una nueva época de partida")
	for i in range(6):
		_advance(r, float(r.state.elapsed) + 40.0)
		_advance(loaded, float(loaded.state.elapsed) + 40.0)
	check(_equivalent(r.state.units, loaded.state.units) and _equivalent(r.state.scouts, loaded.state.scouts) and _equivalent(r.state.probes, loaded.state.probes), "La continuación tras cargar reproduce la partida (grupos, exploradores y sondas)")
	check(_equivalent(r.state.stats, loaded.state.stats) and int(r.state.rng_state) == int(loaded.state.rng_state), "Las estadísticas y el RNG siguen iguales tras la continuación")
	check(r._probe_kind_at(280, 246) == loaded._probe_kind_at(280, 246) and r._probe_kind_at(280, 246) == 2, "El conocimiento se reconstruye al cargar")
	# guardado de otra version
	var old: Dictionary = r.snapshot()
	old.schema_version = 1
	var chk: Dictionary = r.validate_snapshot(old)
	check(not chk.ok and str(chk.reason) == "Este guardado es de una versión anterior del escenario Justina y no es compatible.", "Un guardado de Justina con versión 1 se rechaza con el mensaje del contrato")
	var fut: Dictionary = r.snapshot()
	fut.schema_version = 999
	check(not r.validate_snapshot(fut).ok, "Versiones futuras rechazadas")
	var ver: Dictionary = r.snapshot()
	ver.map_version = 99
	check(not r.validate_snapshot(ver).ok, "Un guardado con otra versión del mapa se rechaza")
	var broken := FileAccess.open(path, FileAccess.WRITE)
	broken.store_string("not JSON")
	broken.close()
	var before_invalid: Dictionary = r.snapshot()
	check(not r.load_game(path).ok and _equivalent(before_invalid, r.state), "Un archivo corrupto se rechaza y deja la partida intacta")
	# la partida terminada tambien se guarda
	var done := _at(900.0)
	check(done.state.status == "defeat" and done.validate_snapshot(done.snapshot()).ok, "Una partida terminada produce un guardado válido")

func _test_justine_snapshot_coherence() -> void:
	var r := _busy_game()
	var s: Dictionary = r.snapshot()
	check(r.validate_snapshot(s).ok, "Estado coherente aceptado")
	s = r.snapshot(); s.water_level_m = 1.0; _rejects(r, s, "Nivel del río inconsistente con el tiempo")
	s = r.snapshot(); s.water_level = 0.95; _rejects(r, s, "water_level no derivado de water_level_m")
	s = r.snapshot(); s.tide_phase = "alta"; _rejects(r, s, "Fase del río inconsistente")
	s = r.snapshot(); s.bajante_announced = false; _rejects(r, s, "Aviso de bajante inconsistente")
	s = r.snapshot(); s.status = "victory"; _rejects(r, s, "Victoria sin motivo ni captura completa")
	s = r.snapshot(); s.reason = "Fin"; _rejects(r, s, "Motivo de cierre con la partida en curso")
	s = r.snapshot(); s.capture = 100.0; _rejects(r, s, "Captura completa sin victoria")
	s = r.snapshot(); s.next_volley = 1.0; _rejects(r, s, "Descarga vencida")
	s = r.snapshot(); s.map_id = "norte"; _rejects(r, s, "Otro mapa")
	s = r.snapshot(); s.ammo = 999; _rejects(r, s, "Munición sobre el máximo")
	s = r.snapshot(); s.ammo = -1; _rejects(r, s, "Munición negativa")
	s = r.snapshot(); s.balizas = 99; _rejects(r, s, "Balizas sobre las iniciales")
	s = r.snapshot(); s.volunteers_pool = 61.0; _rejects(r, s, "Voluntarios sobre el reservorio")
	s = r.snapshot(); s.erase("scouts"); _rejects(r, s, "Falta scouts")
	s = r.snapshot(); s.erase("stats"); _rejects(r, s, "Falta stats")
	s = r.snapshot(); s.units[0].x = 5000.0; _rejects(r, s, "Grupo fuera del mapa")
	s = r.snapshot(); s.units[0].pace = "volar"; _rejects(r, s, "Ritmo inválido")
	s = r.snapshot(); s.units[0].stage = "waiting_tide"; _rejects(r, s, "Etapa waiting_tide ya no existe")
	s = r.snapshot(); s.units[1].stage = "working"; s.units[1].work = {}; _rejects(r, s, "working sin trabajo")
	s = r.snapshot(); s.units[2].work = {"kind": "muster", "remaining": 5.0}; s.units[2].stage = "ready"; _rejects(r, s, "Trabajo en un grupo que no trabaja")
	s = r.snapshot(); s.units[2].stumble_remaining = 5.0; _rejects(r, s, "Tropiezo sin etapa stumbling")
	s = r.snapshot(); s.units[2].stage = "stumbling"; _rejects(r, s, "stumbling sin tiempo restante")
	s = r.snapshot(); s.units[2].stage = "moving"; s.units[2].path = []; s.units[2].order = {"action": "move", "x": 1.0, "z": 1.0}; _rejects(r, s, "moving sin trayecto")
	s = r.snapshot(); s.units[2].stage = "moving"; s.units[2].path = [{"x": 100.0, "z": 100.0}]; s.units[2].order = {}; _rejects(r, s, "moving sin orden")
	s = r.snapshot(); s.units[2].order = {"action": "direct", "x": 1.0, "z": 1.0}; _rejects(r, s, "Orden direct ya no existe")
	s = r.snapshot(); s.units[0].stage = "ordered"; _rejects(r, s, "Etapa de campaña en Justina")
	s = r.snapshot(); s.scouts[0].hp = 9; _rejects(r, s, "Salud de explorador fuera de rango")
	s = r.snapshot(); s.scouts[0].stage = "lost"; _rejects(r, s, "Explorador lost con salud")
	s = r.snapshot(); s.scouts[1].stage = "moving"; s.scouts[1].path = []; _rejects(r, s, "Explorador en marcha sin trayecto")
	s = r.snapshot(); s.scouts[1].x = -3.0; _rejects(r, s, "Explorador fuera del mapa")
	s = r.snapshot(); s.probes.append({"id": "x", "kind": "otra", "pts": [{"x": 1.0, "z": 1.0}], "width": 6.0, "t": 0.0, "scout": ""}); _rejects(r, s, "Tipo de sonda inválido")
	s = r.snapshot(); s.probes.append({"id": "x", "kind": "lane", "pts": [{"x": 1.0, "z": 1.0}], "width": 7.0, "t": 0.0, "scout": ""}); _rejects(r, s, "Ancho de sonda inválido")
	s = r.snapshot(); s.probes.append({"id": "x", "kind": "lane", "pts": [{"x": 9999.0, "z": 1.0}], "width": 6.0, "t": 0.0, "scout": ""}); _rejects(r, s, "Sonda fuera del mapa")
	s = r.snapshot(); s.probes.append({"id": "x", "kind": "lane", "pts": [{"x": 1.0, "z": 1.0}], "width": 6.0, "t": 99999.0, "scout": ""}); _rejects(r, s, "Sonda del futuro")
	s = r.snapshot(); s.hazards_found = ["pozo_inexistente"]; _rejects(r, s, "Hallazgo de pozo inexistente")
	s = r.snapshot(); s.fords_found = ["vado_x"]; _rejects(r, s, "Hallazgo de vado inexistente")
	s = _new_j(4).snapshot(); s.advance_authorized = true; _rejects(r, s, "Orden de avance sin haber señalado")
	s = r.snapshot(); s.fire_support = {"until": 99.0, "ready_at": 50.0}; _rejects(r, s, "Apoyo de fuego que termina después de poder repetirse")
	s = r.snapshot(); s.stats.erase("start_strength"); _rejects(r, s, "Estadísticas sin fuerza inicial")
	s = r.snapshot(); s.stats.exposure_s.central = -1.0; _rejects(r, s, "Exposición negativa")
	s = r.snapshot(); s.orders.clear(); _rejects(r, s, "Órdenes borradas con first_order_at fijado")
	s = r.snapshot(); s.log[0].time = 99999.0; _rejects(r, s, "Evento del futuro")
	# con la orden de señalar registrada, advance_authorized es coherente
	var q := _new_j(2)
	q.issue_order("guemes", "signal_liniers")
	_advance(q, 90.0)
	check(q.state.advance_authorized and q.validate_snapshot(q.snapshot()).ok, "advance_authorized con la orden registrada es coherente")

# ---------------------------------------------------------------------------
# 8. Rendimiento medido

func _test_performance() -> void:
	var r := _new_j(21)
	_advance(r, 300.0)
	r.issue_scout("scout_1", "probe", [Vector2(250, 246), Vector2(296, 246)])
	_advance(r, 360.0)
	var builds: Array = []
	for lvl in [0.30, 0.25, 0.20, 0.15, 0.10]:
		r.state.water_level_m = lvl
		var t0 := Time.get_ticks_usec()
		r.rebuild_navigation()
		builds.append(float(Time.get_ticks_usec() - t0) / 1000.0)
	var plans := 0.0
	var n_plans := 20
	for i in range(n_plans):
		var t1 := Time.get_ticks_usec()
		r.plan_route("arias", Vector2(548, 262), "trot")
		plans += float(Time.get_ticks_usec() - t1) / 1000.0
	var q := _new_j(22)
	var t2 := Time.get_ticks_usec()
	var steps := 2400
	for i in range(steps):
		q.tick(0.25)
		if int(i) == 400:
			q.issue_order("guemes", "move", Vector2(160, 240))
	var tick_ms := float(Time.get_ticks_usec() - t2) / 1000.0 / float(steps)
	var ns: Dictionary = r.nav_stats()
	var avg_build := 0.0
	for b in builds:
		avg_build += b / builds.size()
	report.performance = {"nav_build_ms_avg": avg_build, "nav_build_ms_first": ns.build_ms, "static_precompute_ms_once": ns.static_ms, "plan_route_ms_avg": plans / n_plans, "tick_ms_avg": tick_ms,
		"budget": {"nav_build_ms": 80, "plan_route_ms": 30, "tick_ms": 2}, "note": "Medido en este equipo, modo headless; sin umbral duro."}
	print("RENDIMIENTO: ", JSON.stringify(report.performance))
	check(avg_build >= 0.0 and plans >= 0.0 and tick_ms >= 0.0, "Rendimiento medido e informado")
	check(avg_build < 80.0 * 5.0 and plans / n_plans < 30.0 * 5.0 and tick_ms < 2.0 * 5.0, "El rendimiento medido no se aleja un orden de magnitud del presupuesto")

# ---------------------------------------------------------------------------
# Norte (sin cambios de reglas ni de balance)

func _test_norte_persistence() -> void:
	var r := Rules.new()
	r.new_game("norte", 11)
	_campaign_strategy(r)
	r.resolve_round("guard")
	var path: String = "user://test-rules-norte.json"
	check(r.save_game(path) == OK, "Save succeeds for norte")
	check(r.save_game(path) == OK, "Replacing save succeeds for norte")
	var loaded := Rules.new()
	check(loaded.load_game(path).ok, "Load succeeds for norte")
	check(loaded.state.game_id != r.state.game_id, "Load creates a new request epoch")
	check(_equivalent(loaded.state.units, r.state.units), "Save/load preserves units and unresolved orders")
	for i in range(4):
		_campaign_strategy(r)
		_campaign_strategy(loaded)
		r.resolve_round("forage")
		loaded.resolve_round("forage")
	check(_equivalent(r.state.units, loaded.state.units), "Save/load continuation reproduces gameplay for norte")
	check(int(r.state.rng_state) == int(loaded.state.rng_state), "RNG survives JSON round-trip for norte")
	var invalid: Dictionary = r.snapshot()
	invalid.schema_version = 999
	check(not r.validate_snapshot(invalid).ok, "Future save versions rejected")
	invalid = r.snapshot()
	invalid.units[0].strength = -10
	check(not r.validate_snapshot(invalid).ok, "Negative resources in save rejected")
	invalid = r.snapshot()
	invalid.schema_version = {}
	check(not r.validate_snapshot(invalid).ok, "Wrong JSON types rejected without conversion errors")
	invalid = r.snapshot()
	invalid.units[0].order = {"action": "move", "sector_id": "nonexistent", "x": "oops", "z": 0}
	check(not r.validate_snapshot(invalid).ok, "Corrupt pending order rejected")
	invalid = r.snapshot()
	invalid.log = ["corrupt"]
	check(not r.validate_snapshot(invalid).ok, "Corrupt event log rejected")
	var before_invalid: Dictionary = r.snapshot()
	var broken := FileAccess.open(path, FileAccess.WRITE)
	broken.store_string("not JSON")
	broken.close()
	check(not r.load_game(path).ok, "Malformed save rejected")
	check(_equivalent(before_invalid, r.state), "Rejected save leaves active game untouched")
	check(int(r.state.schema_version) == Rules.SAVE_VERSION, "El Norte sigue en la versión de guardado 1")

func _rejects(r: RefCounted, snap: Dictionary, description: String) -> void:
	check(not r.validate_snapshot(snap).ok, description)

func _test_norte_snapshot_coherence() -> void:
	var s: Dictionary
	var n := Rules.new()
	n.new_game("norte", 3)
	_campaign_strategy(n)
	check(n.validate_snapshot(n.snapshot()).ok, "Coherent campaign snapshot with pending orders is accepted")
	n.resolve_round("guard")
	check(n.validate_snapshot(n.snapshot()).ok, "Coherent campaign snapshot after a round is accepted")
	s = n.snapshot()
	s.units[0].x = 20.0
	_rejects(n, s, "Unit away from its sector coordinates rejected")
	s = n.snapshot()
	s.units[0].stage = "ordered"
	s.units[0].order = {}
	_rejects(n, s, "Ordered stage without order rejected")
	s = n.snapshot()
	s.units[0].order = {"action": "scout", "sector_id": "jujuy"}
	s.units[0].stage = "ready"
	_rejects(n, s, "Pending order on a ready unit rejected")
	s = n.snapshot()
	s.enemy.occupied_salta = true
	_rejects(n, s, "Salta occupied but invader elsewhere rejected")
	s = n.snapshot()
	s.sectors[0].neighbors = ["jujuy"]
	_rejects(n, s, "Non-reciprocal route rejected")
	s = n.snapshot()
	s.humahuaca = true
	_rejects(n, s, "Humahuaca recovered before round 7 rejected")
	s = n.snapshot()
	s.sectors[0].enemy = false
	_rejects(n, s, "Humahuaca sector freed without recovery rejected")
	s = n.snapshot()
	s.last_results = []
	_rejects(n, s, "Missing round summary after a resolved round rejected")
	s = n.snapshot()
	s.pressure_actions = 500
	_rejects(n, s, "Impossible pressure count rejected")
	s = n.snapshot()
	s.round = Rules.SALTA_OCCUPATION_ROUND + 1
	s.date = Rules.DATES[int(s.round) - 1]
	_rejects(n, s, "Salta unoccupied after the occupation round rejected")
	s = n.snapshot()
	s.population = 5.0
	_rejects(n, s, "Playing with exhausted population rejected")
	s = n.snapshot()
	for sector in s.sectors:
		if sector.id == s.enemy.position:
			sector.enemy = false
	_rejects(n, s, "Invader sector not marked as occupied rejected")
	# el Norte conserva el limite de coordenadas viejo
	s = n.snapshot()
	s.units[0].x = 500.0
	_rejects(n, s, "El Norte conserva su límite de coordenadas")
func _campaign_strategy(r: RefCounted) -> void:
	var arias: Dictionary = r.get_unit("arias")
	var guemes: Dictionary = r.get_unit("guemes")
	var support: Dictionary = r.get_unit("zavala")
	if int(r.state.round) == 1:
		r.issue_campaign_order("arias", "scout", "quebrada")
	elif int(r.state.round) == 2:
		r.issue_campaign_order("arias", "move", "quebrada")
	elif int(r.state.round) >= 7 and not r.state.humahuaca and float(arias.supply) >= 18 and float(arias.strength) >= 45 and float(arias.fatigue) <= 78:
		r.issue_campaign_order("arias", "assault", "humahuaca")
	elif int(r.state.round) <= 6:
		r.issue_campaign_order("arias", "scout", "humahuaca")
	else:
		if float(arias.fatigue) <= 65 and float(arias.supply) > 20:
			r.issue_campaign_order("arias", "raid", "quebrada")
	if float(guemes.fatigue) > 55 or float(guemes.supply) < 25:
		if guemes.sector_id != "lerma":
			r.issue_campaign_order("guemes", "withdraw", "lerma")
		else:
			r.issue_campaign_order("guemes", "rest", "lerma")
	elif int(r.state.round) == 1 or (int(r.state.round) % 3) == 0:
		r.issue_campaign_order("guemes", "scout", "jujuy")
	else:
		r.issue_campaign_order("guemes", "raid", "jujuy")
	var sector: Dictionary = r.get_sector(support.sector_id)
	if int(sector.crates) > 0:
		r.issue_campaign_order("zavala", "protect", support.sector_id)
	else:
		var destination := "rosario" if support.sector_id == "chicoana" else "lerma"
		if destination != support.sector_id:
			r.issue_campaign_order("zavala", "move", destination)
		else:
			r.issue_campaign_order("zavala", "rest", support.sector_id)

func _test_campaign() -> void:
	var r := Rules.new()
	r.new_game("norte", 1817)
	check(not r.issue_campaign_order("guemes", "assault", "humahuaca").ok, "Only Arias can lead Humahuaca")
	check(not r.issue_campaign_order("arias", "assault", "humahuaca").ok, "Humahuaca unavailable before March")
	check(not r.issue_campaign_order("guemes", "move", "humahuaca").ok, "Cannot teleport across campaign map")
	check(r.enemy_observation().visible_enemies.is_empty(), "Enemy initially sees no undiscovered partisan groups")
	var guard := 0
	while r.state.status == "playing" and guard < 15:
		_campaign_strategy(r)
		r.resolve_round(r.enemy_fallback())
		guard += 1
	check(r.state.humahuaca, "Arias can complete the Humahuaca operation")
	check(r.state.status == "victory", "Sustained scouting, raids and protection can force withdrawal")
	report.results.append({"scenario": "norte", "strategy": "scout_raid_protect_humahuaca", "status": r.state.status, "round": r.state.round, "enemy": r.state.enemy, "population": r.state.population})
	var alternative := Rules.new()
	alternative.new_game("norte", 1818)
	guard = 0
	while alternative.state.status == "playing" and guard < 15:
		_campaign_alternative(alternative)
		alternative.resolve_round(alternative.enemy_fallback())
		guard += 1
	check(alternative.state.status == "victory", "Alternative rotating raids can win without mandatory Humahuaca")
	check(not alternative.state.humahuaca, "Alternative campaign has distinct operational decisions")
	report.results.append({"scenario": "norte", "strategy": "rotating_jujuy_raids", "status": alternative.state.status, "round": alternative.state.round, "enemy": alternative.state.enemy, "population": alternative.state.population})
	var wait := Rules.new()
	wait.new_game("norte", 1817)
	for i in range(14):
		wait.resolve_round(wait.enemy_fallback())
	check(wait.state.status == "defeat", "Passive campaign strategy loses")
	check(wait.state.enemy.occupied_salta, "Temporary occupation happens without awarding victory")
	report.results.append({"scenario": "norte", "strategy": "passive", "status": wait.state.status, "round": wait.state.round, "enemy": wait.state.enemy})
	var cancelled := Rules.new()
	cancelled.new_game("norte")
	check(cancelled.issue_campaign_order("guemes", "move", "salta").ok, "Legal campaign move queues")
	cancelled.cancel_order("guemes")
	cancelled.resolve_round("guard")
	check(cancelled.get_unit("guemes").sector_id == "lerma", "Canceled campaign order is not executed")
	var guarded := Rules.new()
	var foraged := Rules.new()
	guarded.new_game("norte", 99)
	foraged.new_game("norte", 99)
	for current in [guarded, foraged]:
		current.issue_campaign_order("guemes", "scout", "jujuy")
		current.issue_campaign_order("arias", "raid", "jujuy")
	guarded.resolve_round("guard")
	foraged.resolve_round("forage")
	check(float(guarded.get_unit("arias").strength) < float(foraged.get_unit("arias").strength), "Enemy intent changes combat losses through local authority")
	check(guarded.enemy_observation().visible_enemies.size() == 1, "Enemy only sees group revealed by raid")

func _campaign_alternative(r: RefCounted) -> void:
	for id in ["guemes", "arias"]:
		var u: Dictionary = r.get_unit(id)
		if float(u.fatigue) > 45 or float(u.supply) < 30:
			if u.sector_id == "lerma":
				r.issue_campaign_order(id, "rest", "lerma")
			else:
				r.issue_campaign_order(id, "withdraw", "lerma")
		elif id == "guemes" and int(r.state.round) % 4 == 1:
			r.issue_campaign_order(id, "scout", "jujuy")
		else:
			r.issue_campaign_order(id, "raid", "jujuy")
	var support: Dictionary = r.get_unit("zavala")
	var sector: Dictionary = r.get_sector(support.sector_id)
	if int(sector.crates) > 0:
		r.issue_campaign_order("zavala", "protect", support.sector_id)
	else:
		var destination := "rosario" if support.sector_id == "chicoana" else "lerma"
		if destination != support.sector_id:
			r.issue_campaign_order("zavala", "move", destination)
		else:
			r.issue_campaign_order("zavala", "rest", support.sector_id)



func _test_external_stale() -> void:
	var r := Rules.new()
	r.new_game("norte")
	var decision := {"choice": "guard", "source": "local_fallback", "context": {"game_id": r.state.game_id, "round": r.state.round, "state_version": r.state.state_version}}
	check(r.record_external_decision(decision), "Current legal external intent accepted")
	r.issue_campaign_order("guemes", "scout", "jujuy")
	check(not r.record_external_decision(decision), "State changes invalidate stale decisions")
	r.new_game("norte")
	check(not r.record_external_decision(decision), "Restart invalidates previous match decision")
	decision.context = {"game_id": r.state.game_id, "round": r.state.round, "state_version": r.state.state_version}
	decision.choice = "invent_an_army"
	check(not r.record_external_decision(decision), "Invented external actions rejected")


# ---------------------------------------------------------------------------
# Ritmo del norte (docs/BALANCE_NORTE.md)

func _north_biased_game(seed_value: int, rng: RandomNumberGenerator) -> RefCounted:
	## Politica de estres: las tres agrupaciones hostigan en las rondas 3-4; el resto es azar.
	var r := Rules.new()
	r.new_game("norte", seed_value)
	var acts := ["raid", "raid", "raid", "scout", "protect", "rest", "move", "withdraw"]
	var secs := ["jujuy", "salta", "lerma", "quebrada", "chicoana", "rosario", "humahuaca"]
	var guard := 0
	while r.state.status == "playing" and guard < 20:
		guard += 1
		for id in ["guemes", "arias", "zavala"]:
			var u: Dictionary = r.get_unit(id)
			if int(r.state.round) in [3, 4]:
				for t in ["jujuy", "salta"]:
					if r.issue_campaign_order(id, "raid", t).ok:
						break
			else:
				for tries in range(6):
					var a: String = acts[rng.randi() % acts.size()]
					var s: String = secs[rng.randi() % secs.size()]
					if a in ["rest", "protect"]:
						s = u.sector_id
					if r.issue_campaign_order(id, a, s).ok:
						break
		var intents: Array = r.enemy_choices().keys()
		r.resolve_round(intents[rng.randi() % intents.size()])
	return r

func _test_north_pacing() -> void:
	var n := Rules.new()
	n.new_game("norte", 5)
	n.state.enemy.supply = 0.0
	n.state.enemy.cohesion = 0.0
	n.state.enemy.communications = 0.0
	n.state.pressure_actions = 40
	n.state.round = Rules.RETREAT_MIN_ROUND - 1
	check(not n.enemy_choices().has("retreat"), "Retreat is not offered before the minimum round even when the enemy is exhausted")
	n.state.round = Rules.RETREAT_MIN_ROUND
	check(n.enemy_choices().has("retreat"), "Retreat becomes available at the minimum round when the enemy is exhausted")
	n.state.pressure_actions = Rules.RETREAT_MIN_PRESSURE - 1
	check(not n.enemy_choices().has("retreat"), "Retreat needs the accumulated pressure")
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var earliest := 99
	var wins := 0
	var games := 250
	for g in range(games):
		var r := _north_biased_game(1000 + g, rng)
		if r.state.status == "victory":
			wins += 1
			earliest = mini(earliest, int(r.state.round))
	check(wins > 0, "Stress policy still wins some campaigns (not unwinnable)")
	check(earliest >= Rules.RETREAT_MIN_ROUND, "Three groups raiding in rounds 3-4 cannot win before round %d (earliest: %d)" % [Rules.RETREAT_MIN_ROUND, earliest])
	report.results.append({"scenario": "norte", "strategy": "stress_raids_rounds_3_4", "games": games, "wins": wins, "earliest_victory_round": earliest})


# ---------------------------------------------------------------------------
# Ocupacion de Salta: el 15/4/1817 cae en la ronda 10 (12-22 abr)

func _test_salta_occupation_date() -> void:
	check(Rules.DATES[Rules.SALTA_OCCUPATION_ROUND - 1] == "12 abr 1817" and Rules.DATES[Rules.SALTA_OCCUPATION_ROUND] == "22 abr 1817", "Occupation round spans 12-22 April 1817, which contains 15 April")
	var r := Rules.new()
	r.new_game("norte", 1817)
	var occupied_early := false
	var advance_early := false
	for i in range(Rules.SALTA_OCCUPATION_ROUND - 1):
		advance_early = advance_early or (r.enemy_choices().has("advance") and r.state.enemy.position != "quebrada")
		r.resolve_round(r.enemy_fallback())
		occupied_early = occupied_early or r.state.enemy.occupied_salta
	check(not occupied_early, "Salta stays unoccupied before round %d" % Rules.SALTA_OCCUPATION_ROUND)
	check(not advance_early, "The invader cannot advance into Salta before the occupation round")
	check(int(r.state.round) == Rules.SALTA_OCCUPATION_ROUND, "Passive campaign reaches the occupation round")
	check(r.enemy_choices().has("advance"), "Advance on Salta is offered from the occupation round")
	r.resolve_round("guard")
	check(r.state.enemy.occupied_salta and r.get_sector("salta").enemy, "Salta is occupied in the round containing 15 April even if the invader does not choose to advance")
	var said := false
	for e in r.state.log:
		said = said or (e.kind == "occupation" and "15 de abril" in str(e.text))
	check(said, "Occupation event cites the documented date")
	var a := Rules.new()
	a.new_game("norte", 8)
	a.resolve_round("advance")
	a.resolve_round("advance")
	check(a.state.enemy.position == "jujuy" and not a.state.enemy.occupied_salta, "Repeated early advance stops at Jujuy")

func _test_history_humahuaca_marked() -> void:
	var f := FileAccess.open("res://data/history.json", FileAccess.READ)
	check(f != null, "history.json readable")
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	var found := false
	for fact in data.scenarios.norte.facts:
		if "Humahuaca" in str(fact.title):
			found = true
			check(str(fact.get("verification", "")) == "parcial", "Humahuaca fact declares partial verification")
			check("no verificad" in str(fact.kind).to_lower() and "no verificad" in str(fact.text).to_lower(), "Humahuaca March/May discrepancy is explicitly marked as unverified")
			check(str(fact.text).find("1 de marzo de 1817") >= 0, "Humahuaca fact keeps the adopted date")
	check(found, "Humahuaca fact present")

func _equivalent(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		return absf(float(a) - float(b)) < 0.000001
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in range(a.size()):
			if not _equivalent(a[i], b[i]):
				return false
		return true
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for key in a:
			if not b.has(key) or not _equivalent(a[key], b[key]):
				return false
		return true
	return a == b
