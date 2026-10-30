extends SceneTree
## Pruebas del nucleo (escenario Norte sin cambios; Justina rediseñada: docs/CONTRATO_JUSTINA.md 1.10).

const Rules = preload("res://scripts/game_rules.gd")
const CampaignProgress = preload("res://scripts/campaign.gd")
const REPORT_PATH := "user://rules-test-results.json"
## Ruta sur siguiendo el eje del vado y del banco sur (docs/DISENO_JUSTINA.md 1.2): salida del vado, codo, banco, subida al buque.
const SOUTH_WAYPOINTS := [Vector2(305, 403), Vector2(450, 455), Vector2(520, 440), Vector2(565, 390)]
var failures: Array = []
var checks := 0
var report: Dictionary = {"suite": "authoritative_rules", "engine": Engine.get_version_info().string, "results": []}

func _initialize() -> void:
	if "--matrix" in OS.get_cmdline_user_args():
		_print_matrix()
		return
	if "--human" in OS.get_cmdline_user_args():
		_print_human()
		return
	_test_map_and_terrain()
	_test_speed_table()
	_test_tide_and_windows()
	_test_knowledge()
	_test_group_actions()
	_test_plan_risk()
	_test_scout_and_global_actions()
	_test_board_gate()
	_test_fire_and_exposure()
	_test_boarding_costs()
	_test_geography_and_texts()
	_test_package_data()
	_test_round5_data()
	_test_hidden_layout()
	_test_tide_variants()
	_test_scarce_resources()
	_test_capture_decisions()
	_test_scout_risk()
	_test_round9_telegraph()
	_test_round9_counter_and_morale()
	_test_round9_flow()
	_test_round9_campaign()
	_test_labels_and_save_trim()
	if "--skip-strategies" not in OS.get_cmdline_user_args():  ## solo para iterar: la matriz tarda varios minutos
		_test_strategies()
	_test_speed_never_exceeded()
	_test_not_stranded()
	_test_justine_persistence()
	_test_justine_snapshot_coherence()
	_test_save_size()
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

## Las pruebas de reglas fijan la condición del río en "normal" (los valores base de time) salvo que se pida la sorteada con la semilla.
func _new_j(seed_value: int = 7, keep_variant: bool = false) -> RefCounted:
	var r := Rules.new()
	r.new_game("justine", seed_value)
	if not keep_variant:
		## Pruebas de unidad: sin variante de misión (ronda 9) ni condición de río sorteada, con los recursos base del JSON.
		var res: Dictionary = r.map_data().resources
		r.state.hidden.tide = "normal"
		r.state.hidden.mission = ""
		r.state.no_return_s = 1.0e9  ## las pruebas de unidad dejan correr el reloj sin cargar: el punto sin retorno se prueba aparte
		r.state.ammo = int(res.ammo_start)
		r.state.volunteers_pool = float(res.volunteers_pool)
		r.state.crew_morale = float(r.map_data().ship.crew.morale)
		r.state.next_volley = float(r.map_data().ship.fire.volley_interval_s)
	return r

## Ronda 9: el río se comprimió (0:30-4:10 baja, mínimo hasta 10:40, plazo 13:00). Convierte un instante del cronograma viejo (60/450/960/1080) a su equivalente de fase.
func _tt(old: float) -> float:
	var xs := [0.0, 60.0, 450.0, 960.0, 1080.0]
	var ys := [0.0, 30.0, 250.0, 700.0, 830.0]
	for i in range(1, xs.size()):
		if old <= xs[i]:
			return ys[i - 1] + (old - xs[i - 1]) / (xs[i] - xs[i - 1]) * (ys[i] - ys[i - 1])
	return ys[ys.size() - 1] + (old - xs[xs.size() - 1])

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
	check(r.state.schema_version == Rules.JUSTINE_SAVE_VERSION and r.state.map_id == "justina" and int(r.state.map_version) == int(m.map_version), "Estado inicial con schema 3 y versión de mapa")
	check(r.state.units.size() == 3 and r.state.scouts.size() == 2 and int(r.state.ammo) == 12 and int(r.state.balizas) == 16 and _near(float(r.state.volunteers_pool), 60.0, 0.001), "Recursos y actores iniciales del JSON")
	check(float(r.state.units[0].x) == 199.0 and str(r.state.units[0].tag) == "tradicion" and str(r.state.units[2].tag) == "tradicion", "Los grupos conservan su etiqueta de fuente (Güemes y la caballería de Pueyrredón = tradición, la afirmación más débil)")
	check(r.state.log[0].kind == "objective", "El primer evento es el objetivo")
	var refs := [[548, 262, -1.0], [580, 262, -1.5], [345, 264, -1.9], [415, 290, -0.34], [330, 264, -0.25], [450, 376, -0.83], [314, 400, -0.9], [304, 350, -2.0]]
	for ref in refs:
		var h: float = r.terrain_height_at(ref[0], ref[1])
		check(_near(h, ref[2], 0.02), "Altura de referencia (%d,%d) = %.2f (obtenida %.3f)" % [ref[0], ref[1], ref[2], h])
	check(_near(r.terrain_height_at(130, 100), 12.0 + (13.0 - 12.0) * 0.0, 3.0) and r.terrain_height_at(130, 100) > 8.0, "La meseta está a 8-15 m")
	check(r.terrain_height_at(199, 240) > 2.3 and r.terrain_height_at(199, 240) < r.terrain_height_at(170, 240) and float(r.state.units[0].x) - float(r.map_data().barranca.toe[5][0]) < 10.0, "La costa inicial está al pie de la barranca: los grupos parten a pocos metros del pie, sobre la playa alta")
	check(_near(r.water_depth_at(199, 240), r.water_level_m() - r.terrain_height_at(199, 240), 1e-9), "water_depth_at = nivel - altura")
	# tipos de suelo con el río en 1,65 m
	var kinds := {"meseta": [130, 100], "barranca": [175, 100], "bajada": [178, 190], "obstaculo": [229, 120], "casco": [580, 262], "firme": [199, 240], "barro": [206, 240], "somera": [215, 240], "agua": [242, 240], "honda": [415, 264]}
	for k in kinds:
		check(r.terrain_kind_at(kinds[k][0], kinds[k][1]) == k, "terrain_kind_at devuelve %s (obtenido %s)" % [k, r.terrain_kind_at(kinds[k][0], kinds[k][1])])
	check(r.terrain_kind_at(-4, 10) == "obstaculo" and r.speed_at(-4, 10, "walk", true) == 0.0 and r.speed_at(901, 10, "walk", true) == 0.0, "Fuera del mapa no se transita")
	# la bajada y el acceso a los hitos de la meseta son transitables; el resto de la meseta no
	check(r.speed_at(178, 190, "trot", true) > 0.0 and r.speed_at(150, 180, "trot", true) > 0.0 and r.speed_at(148, 345, "trot", true) > 0.0, "Las bajadas y el acceso a la batería/puesto de Liniers son transitables")
	check(r.speed_at(130, 100, "trot", true) == 0.0 and r.speed_at(175, 100, "trot", true) == 0.0, "El resto de la meseta y la barranca no se pisan")
	check(not r.is_walkable(345, 264) and r.is_walkable(199, 240) and not r.is_walkable(229, 120), "is_walkable compatible con la firma vieja")

# ---------------------------------------------------------------------------
# 2. Tabla de velocidades (contrato 1.3.3)

func _test_speed_table() -> void:
	var r := _new_j()
	# firme
	check(_near(r.speed_at(199, 240, "gallop", true), 7.0, 1e-6) and _near(r.speed_at(199, 240, "trot", true), 3.0, 1e-6) and _near(r.speed_at(199, 240, "walk", true), 1.3, 1e-6), "Firme: galope 7, trote 3, paso 1,3 m/s")
	check(_near(r.speed_at(199, 240, "gallop", false), 1.3, 1e-6), "A pie nunca pasa de 1,3 m/s")
	# barro: altura 0,3 sobre el agua -> 1,25 m/s
	var h: float = r.terrain_height_at(199, 240)
	r.state.water_level_m = h - 0.3
	check(r.terrain_kind_at(199, 240) == "barro" and _near(r.speed_at(199, 240, "gallop", true), 1.25, 1e-6) and _near(r.speed_at(199, 240, "trot", true), 1.25, 1e-6), "Barro: el galope se limita y la velocidad interpola 1,0-1,5 m/s")
	r.state.water_level_m = h
	check(_near(r.speed_at(199, 240, "trot", true), 1.0, 1e-6), "Barro en la línea de agua: 1,0 m/s")
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
	check(_near(r.speed_at(178, 190, "trot", true), 2.1, 1e-6) and _near(r.speed_at(178, 190, "gallop", true), 2.1, 1e-6) and _near(r.speed_at(178, 190, "walk", true), 0.91, 1e-6), "Bajada: x0,7 y sin galope")
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
	var expected := {0: [1.65, "alta"], 30: [1.65, "bajando"], 140: [0.825, "bajando"], 250: [0.0, "baja"], 500: [0.0, "baja"], 700: [0.0, "subiendo"], 765: [0.825, "subiendo"], 830: [1.65, "subiendo"]}
	for t in expected:
		var td: Dictionary = r.tide_at(float(t))
		check(_near(td.level_m, expected[t][0], 1e-6) and td.phase == expected[t][1], "tide_at(%d) = %.3f m, %s" % [t, expected[t][0], expected[t][1]])
		check(_near(td.level_norm, 0.05 + 0.9 * td.level_m / 1.65, 1e-6), "level_norm derivado a t=%d" % t)
	var marks: Dictionary = r.tide_marks()
	check(marks.drop_start == 30.0 and marks.drop_end == 250.0 and marks.low_hold_end == 700.0 and marks.rise_end == 830.0 and marks.deadline == 840.0, "tide_marks")
	# antes de sondear: sin certeza (la ventana es la percibida, optimista)
	var bp: Vector2 = r.board_point()
	var before: Dictionary = r.ford_window(bp.x, bp.y)
	check(not before.certain and not before.known, "ford_window del buque: sin certeza antes de sondear")
	var before_south: Dictionary = r.ford_window(305, 403)
	check(not before_south.certain, "ford_window del vado sur: sin certeza antes de sondear")
	check(float(before.opens_at) < 210.0 and float(before_south.opens_at) < 196.0, "La ventana percibida de un fondo desconocido es más optimista que la real")
	# tras sondear los dos puntos, la ventana es la real
	r.state.probes.append({"id": "t1", "kind": "lane", "pts": [{"x": 540.0, "z": 262.0}, {"x": 556.0, "z": 262.0}], "width": 6.0, "t": 0.0, "scout": "scout_1"})
	r.state.probes.append({"id": "t2", "kind": "lane", "pts": [{"x": 300.0, "z": 403.0}, {"x": 310.0, "z": 403.0}], "width": 6.0, "t": 0.0, "scout": "scout_1"})
	var w: Dictionary = r.ford_window(548, 262)
	check(w.certain and _near(w.opens_at, 210.0, 5.0) and _near(w.closes_at, 722.0, 5.0), "ford_window del vado del buque ≈ 210..722 s (abre antes de 3:30) (obtenido %.1f..%.1f)" % [w.opens_at, w.closes_at])
	var ws: Dictionary = r.ford_window(305, 403)
	check(ws.certain and _near(ws.opens_at, 197.0, 5.0) and _near(ws.closes_at, 730.0, 5.0), "ford_window del vado sur ≈ 197..730 s (obtenido %.1f..%.1f)" % [ws.opens_at, ws.closes_at])
	check(_near(w.depth_at_low_m, 1.0, 0.02), "Profundidad del vado del buque con el río en mínimo ≈ 1,0 m")
	r.state.probes.append({"id": "t3", "kind": "lane", "pts": [{"x": 335.0, "z": 264.0}, {"x": 350.0, "z": 264.0}], "width": 6.0, "t": 0.0, "scout": "scout_1"})
	var never: Dictionary = r.ford_window(345, 264)
	check(never.has_all(["known", "certain", "opens_at", "closes_at", "depth_at_low_m"]) and never.certain and float(never.opens_at) < 0.0 and float(never.closes_at) < 0.0, "ford_window del pozo ya sondeado: nunca abre para el caballo (opens_at = closes_at = -1)")
	# el estado sigue la marea paso a paso
	var q := _new_j()
	_advance(q, 140.0)
	check(_near(q.state.water_level_m, 0.825, 1e-6) and q.state.tide_phase == "bajando" and _near(q.state.water_level, 0.5, 1e-6), "El estado sigue la bajante (t=140)")
	_advance(q, 400.0)
	check(q.state.tide_phase == "baja" and q.state.bajante_announced and not q.state.rising_announced, "Aviso de bajante emitido y aún sin aviso de subida")
	_advance(q, 760.0)
	check(q.state.tide_phase == "subiendo" and q.state.rising_announced, "Aviso de subida emitido")

# ---------------------------------------------------------------------------
# 4. Conocimiento

func _test_knowledge() -> void:
	var r := _at(_tt(500.0))  # río en mínimo
	check(r.knowledge_at(199, 240) == "visible" and r.knowledge_at(520, 264) == "unknown" and r.knowledge_at(330, 264) == "visible", "Tierra firme y la cresta del banco emergido, visibles; el fondo turbio, desconocido")
	var base_plus: float = -0.35 - 0.35 * (15.0 / 90.0) + 0.5
	var pr: float = r.perceived_height_at(345, 264)
	check(_near(pr, base_plus, 0.03) and pr > -0.5, "Antes de sondear, perceived_height(345,264) ≈ perfil base + 0,5 (obtenido %.3f), no el pozo real" % pr)
	check(_near(r.perceived_depth_at(345, 264), r.water_level_m() - pr, 1e-9), "perceived_depth = nivel - altura percibida")
	check(r.terrain_height_at(345, 264) < -1.8, "El pozo real está a -1,9 m")
	# una sonda sobre el pozo: el explorador se detiene en el borde, lo descubre y la franja llega al centro
	r.state.next_volley = 1500.0  # se silencia el buque para aislar el sondeo (el fuego se prueba aparte)
	var o: Dictionary = r.issue_scout("scout_1", "probe", [Vector2(345, 264)])
	check(o.ok, "Orden de sondeo sobre el pozo aceptada")
	_advance(r, float(r.state.elapsed) + 260.0)
	check(r.knowledge_at(345, 264) == "probed", "Tras el sondeo, knowledge_at(pozo) = probed")
	check(_near(r.perceived_height_at(345, 264), r.terrain_height_at(345, 264), 1e-9), "Tras sondear, lo percibido es lo real")
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
		var closest := Geometry2D.get_closest_point_to_segment(Vector2(345, 264), prev, b)
		skirts = skirts and closest.distance_to(Vector2(345, 264)) >= 10.0
		prev = b
	check(plan.ok and skirts, "La ruta planificada rodea el pozo ya descubierto")

# ---------------------------------------------------------------------------
# 5. Acciones: exito, rechazo con motivo, costo y efecto

func _test_group_actions() -> void:
	var r := _new_j()
	# list_actions / action_info
	check(r.list_actions("group") == ["move", "board", "muster", "resupply", "signal_liniers", "withdraw", "repel", "evacuate", "rally", "cancel"], "list_actions(group) en el orden de la UI")
	check(r.list_actions("scout") == ["probe", "probe_careful", "mark_ford", "recall"] and r.list_actions("global") == ["distract_fire", "retreat_all"], "list_actions(scout/global)")
	check(r.action_info("muster").id == "muster" and r.action_info("nope").is_empty(), "action_info lee el JSON")
	# move
	var bad: Dictionary = r.issue_order("guemes", "move", Vector2(130, 100))
	check(not bad.ok and "barranca" in str(bad.reason), "Mover a la meseta se rechaza con causa (barranca/bajadas)")
	bad = r.issue_order("guemes", "move", Vector2(2000, 100))
	check(not bad.ok and "fuera del mapa" in str(bad.reason), "Mover fuera del mapa se rechaza")
	bad = r.issue_order("guemes", "move", Vector2(229, 120))
	check(not bad.ok and "obstáculo" in str(bad.reason), "Mover sobre el cañaveral se rechaza")
	bad = r.issue_order("guemes", "move", Vector2(345, 264))
	check(not bad.ok, "Mover al centro del banco con el río alto se rechaza (fondo estimado)")
	bad = r.issue_order("guemes", "dance")
	check(not bad.ok and "desconocida" in str(bad.reason), "Orden desconocida: Orden táctica desconocida.")
	check(not r.issue_order("guemes", "direct").ok and not r.issue_order("guemes", "flank").ok, "Las órdenes viejas direct/flank ya no existen")
	var ok: Dictionary = r.issue_order("guemes", "move", Vector2(200, 300), {"pace": "gallop"})
	check(ok.ok and ok.plan.ok and r.get_unit("guemes").stage == "moving" and r.get_unit("guemes").pace == "gallop", "Mover: acepta, planifica y guarda el ritmo")
	check(ok.plan.risk == "bajo" and float(ok.plan.length_m) > 50.0 and float(ok.plan.eta_s) > 0.0 and ok.plan.has("warnings"), "plan_route completo en tierra firme: riesgo bajo")
	_advance(r, 40.0)
	var gu: Dictionary = r.get_unit("guemes")
	check(gu.stage == "ready" and Vector2(gu.x, gu.z).distance_to(Vector2(200, 300)) < 0.5, "El grupo llega y queda libre")
	# plan_route no tiene efectos
	var ver_before := int(r.state.state_version)
	var plan: Dictionary = r.plan_route("zavala", Vector2(205, 330), "trot")
	check(plan.ok and int(r.state.state_version) == ver_before and r.get_unit("zavala").stage == "ready", "plan_route no cambia el estado")
	var wp: Dictionary = r.plan_route("zavala", Vector2(205, 330), "trot", {"waypoints": [Vector2(200, 380)]})
	check(wp.ok and float(wp.length_m) > float(plan.length_m), "plan_route admite waypoints")
	check(not r.plan_route("zavala", Vector2(205, 330), "trot", {"waypoints": [Vector2(1, 1), Vector2(2, 2), Vector2(3, 3), Vector2(4, 4), Vector2(5, 5)]}).ok, "Máximo 4 waypoints")
	# cancel
	r.issue_order("arias", "move", Vector2(201, 280))
	check(r.issue_order("arias", "cancel").ok and r.get_unit("arias").stage == "ready" and r.get_unit("arias").path.is_empty() and r.get_unit("arias").order.is_empty(), "Cancelar detiene y limpia")
	# rally: en la playa sí; en el agua no
	check(r.issue_order("zavala", "rally").ok and r.get_unit("zavala").stage == "rally", "Reagrupar en la playa seca")
	var rr := _at(500.0)
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
	var working := false
	for i in range(160):
		s.tick(1.0)
		if s.get_unit("guemes").stage == "working":
			working = s.get_unit("guemes").work.kind == "signal" and float(s.get_unit("guemes").work.remaining) > 8.0
			break
	check(working, "Señalar: trabaja 10 s en el puesto")
	_advance(s, float(s.state.elapsed) + 12.0)
	check(s.state.advance_authorized and int(s.state.ammo) == ammo0 + 8 and s.get_unit("guemes").stage == "ready", "Señalar concede el avance y +8 de munición")
	check(float(s.state.advance_until) - float(s.state.elapsed) >= 406.0 and float(s.state.advance_until) - float(s.state.elapsed) <= 420.1, "La orden de avance tiene un plazo de validez (420 s)")
	_advance(s, float(s.state.advance_until) + 1.0)
	check(not s.state.advance_authorized and not s.issue_order("zavala", "board").ok and s.issue_order("guemes", "signal_liniers").ok, "Vencida la orden de avance no se puede cargar y hay que volver a señalar")
	var s2 := _new_j()
	s2.issue_order("guemes", "signal_liniers")
	_advance(s2, 100.0)
	var again: Dictionary = s2.issue_order("guemes", "signal_liniers")
	check(not again.ok and "ya fue concedida" in str(again.reason), "Señalar dos veces mientras vale se rechaza")
	# abastecer
	var ra := _new_j()
	check(ra.issue_order("zavala", "resupply").ok, "Abastecer acepta")
	var t_start := float(ra.state.elapsed)
	var reached := -1.0
	for i in range(200):
		ra.tick(1.0)
		if reached < 0.0 and ra.get_unit("zavala").stage == "working":
			reached = float(ra.state.elapsed)
		if int(ra.state.ammo) > 12:
			break
	check(int(ra.state.ammo) == 28 and reached > 0.0 and float(ra.state.elapsed) - reached >= 24.0 and float(ra.state.elapsed) - reached <= 27.0, "Abastecer: +16 de munición tras 25 s de trabajo en la batería")
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
	check(_near(rm.get_unit("arias").strength, st0 + 20.0, 0.001) and _near(rm.state.volunteers_pool, 40.0, 0.001) and _near(rm.state.stats.muster_gain, 20.0, 0.001), "Reunir: +20 de fuerza tomados del reservorio (60 → 40)")
	check(int(rm.state.ammo) == 12 - 4 and float(rm.get_unit("arias").fatigue) >= 19.0, "Reunir cuesta 4 de munición y suma 20 de fatiga: los reclutas llegan sin entrenar")
	var dry := _new_j()
	dry.state.ammo = 3
	check(not dry.issue_order("arias", "muster").ok and "municiones" in str(dry.issue_order("arias", "muster").reason), "Reunir sin munición para armar a los reclutas se rechaza")
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
	check(av2.ok and av2.tag == "diseno" and "10 s" in av2.cost_text and "munición" in av2.cost_text, "Disponibilidad de señalar: tag tradición y costo")
	var av3: Dictionary = _new_j().action_availability("scout_1", "mark_ford")
	check(av3.ok and "baliza" in av3.cost_text, "Disponibilidad de marcar vado: costo en balizas")
	var av4: Dictionary = _new_j().action_availability("global", "distract_fire")
	check(av4.ok and av4.cost_text == "8 munición · 45 s", "Disponibilidad de distraer: costo '8 munición · 45 s'")
	var routed := _new_j()
	routed.state.units[2].strength = 3.0
	check(not routed.issue_order("zavala", "move", Vector2(201, 300)).ok, "Un grupo disperso no recibe órdenes")

func _test_plan_risk() -> void:
	var r := _at(_tt(370.0))
	r.state.advance_authorized = true
	r.state.orders.append({"time": 0.0, "round": 1, "unit": "guemes", "action": "signal_liniers", "target": {}})
	r.state.first_order_at = 0.0
	var far: Dictionary = r.plan_route("arias", r.board_point(), "trot")
	check(far.ok and far.risk == "alto" and float(far.unknown_m) > 80.0 and float(far.exposed_s) > 0.0 and float(far.max_depth_m) > 0.0, "Cruce largo sin reconocer: riesgo alto, metros sin reconocer y exposición (%.0f m sin reconocer)" % float(far.unknown_m))
	check(far.has_all(["path", "length_m", "eta_s", "unknown_m", "exposed_s", "max_depth_m", "arrives_in_window", "risk", "warnings"]) and far.path[far.path.size() - 1].x == 548.0, "plan_route devuelve todos los campos del contrato y termina en el destino")
	var beach: Dictionary = r.plan_route("arias", Vector2(203, 250), "gallop")
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
	r.state.probes.append({"id": "t1", "kind": "lane", "pts": [{"x": 300.0, "z": 264.0}, {"x": 325.0, "z": 264.0}], "width": 6.0, "t": 0.0, "scout": "scout_1"})
	var known: Dictionary = r.plan_route("arias", Vector2(322, 264), "trot")
	check(known.ok and float(known.unknown_m) < float(short.unknown_m) and known.risk != "alto", "Con el tramo sondeado bajan los metros sin reconocer (%.0f -> %.0f m)" % [float(short.unknown_m), float(known.unknown_m)])

func _test_scout_and_global_actions() -> void:
	var r := _at(260.0)
	check(not r.issue_scout("scout_1", "probe", []).ok, "Sondear sin puntos se rechaza")
	var many: Array = [Vector2(250, 250), Vector2(260, 250), Vector2(270, 250), Vector2(280, 250)]
	var m4: Dictionary = r.issue_scout("scout_1", "probe", many)
	check(not m4.ok and "Máximo 3" in str(m4.reason), "Más de 3 puntos se rechaza")
	check(not r.issue_scout("scout_1", "probe", [Vector2(-5, 10)]).ok and not r.issue_scout("scout_1", "probe", [Vector2(229, 120)]).ok, "Puntos fuera del mapa o sobre un obstáculo se rechazan")
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
	f.state.ammo = 30
	var a0 := int(f.state.ammo)
	var cf: Dictionary = f.call_fire_support()
	check(cf.ok and int(f.state.ammo) == a0 - 8 and _near(f.state.fire_support.until, 45.0, 1e-6) and _near(f.state.fire_support.ready_at, 90.0, 1e-6) and _near(f.state.crew_morale, 97.0, 1e-6), "Distraer: -8 munición, 45 s de duración, recarga 90 s, moral -3")
	check(f.state.log[f.state.log.size() - 1].kind == "fire_support" and f.ship_state().fire_support_active, "Distraer deja evento fire_support y activa el apoyo")
	var again: Dictionary = f.call_fire_support()
	check(not again.ok and "recarga" in str(again.reason), "Distraer durante la recarga se rechaza")
	_advance(f, 95.0)
	f.state.ammo = 20
	check(not f.ship_state().fire_support_active and f.call_fire_support().ok and int(f.state.ammo) == 12, "Tras la recarga se puede repetir (cada uso cuesta 8)")
	_advance(f, 200.0)
	f.state.ammo = 4
	var none: Dictionary = f.call_fire_support()
	check(not none.ok and "municiones" in str(none.reason), "Sin munición no hay fuego de distracción")
	# retirada general
	var rt := _at(100.0)
	check(rt.retreat_all().ok and rt.state.status == "defeat" and "Retirada general" in str(rt.state.reason), "Retirada general termina la partida como derrota")
	check(not rt.issue_order("guemes", "move", Vector2(150, 240)).ok and not rt.retreat_all().ok and not rt.issue_scout("scout_1", "recall").ok, "Terminada la partida no se aceptan órdenes")
	check(rt.campaign_report().outcome_title == "Retirada general", "El parte nombra la retirada")

func _test_board_gate() -> void:
	var r := _at(380.0)
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
	check(_near(r.exposure_at(560, 380), 0.15, 1e-9), "Exposición 0,15 por proa/popa")
	check(_near(r.exposure_at(480, 360), 0.4, 1e-9), "Exposición 0,4 por el cuartel")
	check(r.exposure_at(200, 262) == 0.0 and r.exposure_at(314, 262) == 0.0 and r.exposure_at(316, 262) > 0.0, "Fuera de 265 m no hay fuego; dentro sí")
	check(r.exposure_at(100, 240) == 0.0, "En la playa no hay fuego")
	r.state.fire_support = {"until": 45.0, "ready_at": 90.0}
	check(_near(r.exposure_at(500, 262), 0.5, 1e-9), "El fuego de distracción reduce la exposición a la mitad")
	# la dotación pierde moral y dispara mas lento
	var d := _at(500.0)
	d.state.units[0].x = 450.0
	d.state.units[0].z = 262.0
	var hp0 := float(d.state.units[0].strength)
	var nv := float(d.state.elapsed) + 0.5
	d.state.next_volley = nv
	_advance(d, float(d.state.elapsed) + 2.0)
	var dmg := hp0 - float(d.state.units[0].strength)
	var fmin: float = float(d.map_data().ship.fire.damage_min)
	var fmax: float = float(d.map_data().ship.fire.damage_max)
	check(dmg >= fmin - 0.001 and dmg <= fmax + 0.001, "Una descarga causa %.1f-%.1f de daño en exposición 1 (obtenido %.2f)" % [fmin, fmax, dmg])
	check(d.state.stats.shots_taken == 1 and _near(d.state.next_volley, nv + 7.5, 1e-9), "La siguiente descarga llega a los 7,5 s")
	var ex := _at(500.0)
	ex.state.units[0].x = 450.0
	ex.state.units[0].z = 262.0
	var nv2 := float(ex.state.elapsed) + 0.5
	ex.state.next_volley = nv2
	ex.state.fire_support = {"until": float(ex.state.elapsed) + 45.0, "ready_at": float(ex.state.elapsed) + 90.0}
	_advance(ex, float(ex.state.elapsed) + 2.0)
	check(_near(ex.state.next_volley, nv2 + 7.5 + 2.0, 1e-9) and float(ex.state.units[0].strength) > 100.0 - float(ex.map_data().ship.fire.damage_max) * 0.5 - 0.001, "Con apoyo de fuego: +2 s entre descargas y daño a la mitad")
	# explorador alcanzado
	var s := _at(500.0)
	s.state.scouts[0].x = 450.0
	s.state.scouts[0].z = 262.0
	for u in s.state.units:
		u.x = 199.0
	s.state.scouts[1].x = 204.0
	var volleys := 0
	while int(s.state.scouts[0].hp) > 0 and volleys < 200:
		s.state.next_volley = float(s.state.elapsed) + 1.0
		_advance(s, float(s.state.elapsed) + 2.0)
		volleys += 1
	check(int(s.state.scouts[0].hp) == 0 and s.state.scouts[0].stage == "lost" and int(s.state.stats.scouts_lost) == 1, "Un explorador sin cobertura cae y cuenta como perdido")
	check(volleys >= 6 and volleys <= 40, "Cae tras 4 impactos que aciertan con probabilidad 0,4 x exposición: no en 22 s sino en %d descargas (≈ %d s)" % [volleys, int(float(volleys) * 7.5)])
	var covered := _at(500.0)
	covered.state.scouts[0].x = 450.0
	covered.state.scouts[0].z = 262.0
	for u in covered.state.units:
		u.x = 199.0
	covered.state.scouts[1].x = 204.0
	covered.state.fire_support = {"until": 100000.0, "ready_at": 100000.0}
	var cv := 0
	while int(covered.state.scouts[0].hp) > 0 and cv < 400:
		covered.state.next_volley = float(covered.state.elapsed) + 1.0
		_advance(covered, float(covered.state.elapsed) + 2.0)
		cv += 1
	check(cv > volleys, "El fuego de distracción alarga la vida del explorador (%d descargas contra %d)" % [cv, volleys])

# ---------------------------------------------------------------------------
# 5b. Abordaje: fuego, cuerpo a cuerpo, agua que sube y retirada

func _boarding_game(t: float) -> RefCounted:
	var b := _at(t, 5)
	b.state.next_volley = 1500.0
	b.state.counter.next_at = 90000.0  ## sin contraataques: estas pruebas aíslan el cuerpo a cuerpo y el fuego
	var g: Dictionary = b.get_unit("guemes")
	g.x = 524.0
	g.z = 262.0
	g.mounted = false
	g.stage = "boarding"
	g.order = {"action": "board", "x": 548.0, "z": 262.0}
	g.pace = "walk"
	return b

func _test_boarding_costs() -> void:
	# cuerpo a cuerpo: con la dotación entera el grupo que aborda pierde fuerza sin que nadie dispare
	var b := _boarding_game(500.0)
	var s0 := float(b.get_unit("guemes").strength)
	_advance(b, 560.0)
	var lost := s0 - float(b.get_unit("guemes").strength)
	var melee_rate := float(Rules.new().map_data().ship.capture.melee_loss_per_s)
	check(lost >= 60.0 * melee_rate * 0.9 and lost <= 60.0 * melee_rate * 1.05 + 0.01, "Abordar cuesta fuerza en el cuerpo a cuerpo: %.3f/s con la dotación entera (60 s: %.2f)" % [melee_rate, lost])
	check(float(b.state.stats.melee_loss) > 0.0 and b.state.capture > 0.0, "El parte registra la pérdida en el cuerpo a cuerpo y la captura avanza")
	# con la moral de la dotación baja el cuerpo a cuerpo pierde fuerza
	var weak := _boarding_game(500.0)
	weak.state.crew_morale = 20.0
	var w0 := float(weak.get_unit("guemes").strength)
	_advance(weak, 560.0)
	check(w0 - float(weak.get_unit("guemes").strength) < lost * 0.5, "Con la dotación quebrada el cuerpo a cuerpo cuesta mucho menos")
	# el fuego del buque alcanza a los que abordan (x0,5)
	check(_near(b.exposure_for(b.get_unit("guemes")), b.exposure_at(524.0, 262.0) * float(b.map_data().ship.capture.boarding_exposure_mult), 1e-9), "Abordando se recibe el fuego del buque con la exposición reducida (x0,3, reducida desde x0,5)")
	# agua que sube: quien esta a pie en el vado se ahoga
	var up := _boarding_game(_tt(1000.0))
	var u0 := float(up.get_unit("guemes").strength)
	check(up.water_depth_at(524.0, 262.0) - 1.2 > 0.0, "Con el río subiendo (t=1000) el vado supera el límite de un hombre a pie (%.2f m)" % up.water_depth_at(524.0, 262.0))
	_advance(up, _tt(1020.0))
	var down := u0 - float(up.get_unit("guemes").strength)
	check(down > 20.0 and float(up.state.stats.drowned) > 10.0, "Los grupos que abordan sufren el agua que sube: −%.0f de fuerza en 20 s" % down)
	var calm := _boarding_game(_tt(500.0))
	_advance(calm, _tt(500.0) + 20.0)
	check(float(calm.state.stats.drowned) == 0.0, "Con el río en mínimo nadie se ahoga")
	# desmontando tambien esta sujeto al agua
	var dis := _at(_tt(1000.0), 5)
	dis.state.next_volley = 1500.0
	var dg: Dictionary = dis.get_unit("zavala")
	dg.x = 524.0
	dg.z = 262.0
	dg.stage = "dismounting"
	dg.dismount_remaining = 12.0
	dg.order = {"action": "board", "x": 548.0, "z": 262.0}
	var dz0 := float(dg.strength)
	_advance(dis, _tt(1000.0) + 6.0)
	check(float(dis.get_unit("zavala").strength) < dz0, "Desmontando en el vado con el río subiendo también se pierde fuerza")
	# retirada desde el abordaje: se puede, vuelven a montar y a la playa
	var wd := _boarding_game(500.0)
	var res: Dictionary = wd.issue_order("guemes", "withdraw")
	check(res.ok and wd.get_unit("guemes").stage == "moving" and wd.get_unit("guemes").mounted, "Un grupo que aborda puede retirarse: monta y vuelve a la playa")
	check(not _boarding_game(500.0).issue_order("guemes", "move", Vector2(300, 264)).ok, "Abordando no se aceptan otras órdenes salvo retirarse")
	check(wd.validate_snapshot(wd.snapshot()).ok, "El estado tras retirar a un grupo del abordaje es un guardado coherente")

func _test_geography_and_texts() -> void:
	var r := _new_j()
	var m: Dictionary = r.map_data()
	# la costa inicial esta al pie de la barranca, no 120 m al este
	var worst := 0.0
	for z in [0.0, 100.0, 200.0, 262.0, 330.0, 420.0, 520.0]:
		var gap: float = r._shore_x(z) - r._toe_x(z)
		worst = maxf(worst, gap)
		check(gap >= 0.0, "La línea de agua inicial está al este del pie de la barranca (z=%d)" % int(z))
	check(worst <= 40.0, "La línea de agua inicial queda a menos de 40 m del pie de la barranca (peor %.0f m)" % worst)
	check(_near(float(m.ship.x) - r._toe_x(262.0), float(m.ship.distance_from_shore_high_m), 6.0), "Los ~390 m al buque se miden desde el pie de la barranca (%.0f m)" % (float(m.ship.x) - r._toe_x(262.0)))
	check(r.water_depth_at(float(m.groups[0].x), float(m.groups[0].z)) < 0.0 and r.terrain_kind_at(float(m.groups[1].x), float(m.groups[1].z)) == "firme", "Los grupos parten en la playa alta seca, junto al pie de la barranca")
	# etiquetas: lo que no tiene fuente primaria o solida no se rotula Documentado
	var by_id := {}
	for lm in m.landmarks:
		by_id[str(lm.id)] = lm
	check(by_id.bateria_abascal.tag != "documentado" and by_id.campamento_pueyrredon.tag != "documentado", "La batería y el campamento no se rotulan Documentado")
	check(str(m.groups[2].tag) != "documentado" and str(m.groups[0].tag) == "tradicion", "La reserva de Pueyrredón no es Documentado y Güemes sigue siendo tradición")
	check(str(m.actions.signal_liniers.tag) != "tradicion" and "tradición no probada" in str(m.actions.signal_liniers.effect), "Señalar a Liniers es una regla de diseño y no afirma la tradición")
	check("tradición" in str(m.groups[0].name).to_lower(), "El nombre del grupo de Güemes lleva la marca de tradición")
	var all_text := str(m.texts.briefing) + " " + str(m.texts.historical_note) + " " + str(by_id.justina.source)
	var low := all_text.to_lower()
	check("británico" in low and "combat" in low and "súbita bajada" in low and "26 cañones" in low, "Los textos dicen que era un mercante británico de 26 cañones que combatió, tomado por una súbita bajada del río")
	check("edisalta" in low and "no viene de gillespie" in low, "El lugar del varado se atribuye a fuentes divulgativas y no a Gillespie")
	check(not ("fragata" in low) and not ("goleta" in low) and not ("bandera argentina" in low and "con bandera" in low) and not ("infernales" in low and "con infernales" in low), "Los textos no inventan tipo de buque, bandera ni Infernales")
	var lines := ""
	for e in r.state.log:
		lines += str(e.text) + " "
	check(not ("la lleva la vanguardia" in lines.to_lower()), "El objetivo inicial no afirma que la vanguardia de Güemes lleve la orden")
	# data/history.json
	var f := FileAccess.open("res://data/history.json", FileAccess.READ)
	var hist: Variant = JSON.parse_string(f.get_as_text()) if f != null else null
	check(hist is Dictionary and hist.scenarios.has("justine"), "data/history.json se carga")
	if hist is Dictionary:
		var j: Dictionary = hist.scenarios.justine
		var jt := JSON.stringify(j).to_lower()
		check("justina" in str(j.title).to_lower() and "retiro" in str(j.place).to_lower() and not ("ribera de buenos aires" in str(j.place).to_lower()), "history.json: Justina, frente al Retiro (no 'Ribera de Buenos Aires')")
		check("británic" in jt and "combat" in jt and "26 cañones" in jt, "history.json: buque británico de 26 cañones que combatió")
		check("edisalta" in jt or "divulgativ" in jt, "history.json: el lugar del varado se atribuye a fuentes divulgativas")
		check(not ("el juego utiliza justine" in jt) and not ("la toma del justine" in jt), "history.json ya no usa 'Justine' como nombre del juego")

func _test_boarding_costs_placeholder() -> void:
	pass

## Ronda 1 (paquete Justina_Retiro_1806): datos de mapa e historia nuevos y coherentes con las advertencias del paquete.
## Ronda 5 (mapa e historia): textos del jugador sin notas de producción, dos piezas de a 18, etiquetas Diseño en el decorado, banderas con colocación, paleta, adopción del paquete.
func _test_round5_data() -> void:
	var r := _new_j(5)
	var m: Dictionary = r.map_data()
	var by_id := {}
	for lm in m.landmarks:
		by_id[str(lm.id)] = lm
	var player_txt := (str(m.texts.briefing) + " " + str(m.texts.briefing_long) + " " + str(m.texts.dry_note) + " " + str(m.tide_gillespie.on_screen_note) + " " + str(m.texts.sources_detail) + " " + str(m.texts.result_contrast)).to_lower()
	check(not ("tuya" in player_txt) and not ("del usuario" in player_txt) and not ("decisión pendiente" in player_txt), "Los textos del jugador no llevan notas de producción («decisión pendiente tuya»)")
	check(str(m.texts.briefing).length() <= 700 and "británico" in str(m.texts.briefing) and "«Fuentes»" in str(m.texts.briefing), "El briefing es un párrafo corto que remite a «Fuentes»")
	check("gillespie" in str(m.texts.result_contrast).to_lower() and "tradición" in str(m.texts.result_contrast).to_lower() and m.texts.has("tradition_context"), "Hay una línea de resultado que contrasta a Gillespie con la tradición de Güemes")
	var bat: Dictionary = by_id.bateria_abascal
	check(int(bat.guns) == 2 and str(bat.tag) == "diseno" and str(bat.tag_parts.emplazamiento) == "diseno" and int(bat.gabions.max_drawn) <= 4, "Las piezas de a 18 son dos (parte de Liniers) y su emplazamiento es Diseño")
	check("hipótesis" not in str(bat.marker_suffix) and str(by_id.campamento_pueyrredon.tag) == "tradicion" and str(by_id.campamento_pueyrredon.tag_parts.posicion_exacta) == "diseno", "El campamento de Pueyrredón es Tradición con posición de Diseño y las piezas ya no dicen «hipótesis»")
	var scen_ok := true
	for it in m.scenery.items:
		if str(it.id).begins_with("cuartel_") or str(it.id).begins_with("casa_") or str(it.id).begins_with("tapia_"):
			scen_ok = scen_ok and str(it.tag) == "diseno" and str(it.tag_parts.values()[0]) == "reconstruccion"
	for b in m.scenery.blocks:
		scen_ok = scen_ok and str(b.tag) == "diseno"
	check(scen_ok and str(m.shore_high.tag) == "diseno", "Volúmenes, lotes y costa irregular del decorado son Diseño (solo la existencia y el área general son Reconstrucción)")
	var pt: Dictionary = by_id.plaza_toros
	check("c. 1801" in str(pt.in_use_since) and "una sola vez" in str(pt.source) and "inaugurada en 1801" not in str(pt.source) and str(pt.tag_parts.existencia) == "documentado", "La Plaza de Toros: en uso desde c. 1801 y la cita de Gillespie p. 121 con su matiz")
	var fire: Dictionary = m.ship.fire
	check(float(fire.range_m) == 265.0 and fire.has("p94_tension") and str(fire.p94_tension.page) == "94" and not bool(fire.cover_zone.implemented) and float(fire.cover_zone.range_m) > float(fire.range_m), "La tensión con Gillespie p. 94 (batía playa y calles) está declarada y el anillo de cobertura no se simula")
	var sp: Vector2 = r.ship_position()
	check(r.exposure_at(sp.x - 300.0, sp.y) == 0.0 and r.exposure_at(sp.x - 200.0, sp.y) > 0.0, "El fuego sigue limitado a range_m (la cobertura de 420 m es solo un dato visual)")
	var bn: Dictionary = m.banners
	var red_layers := JSON.stringify(_banner_by_id(bn, "red_ensign_mercante").design.canton_layers)
	check("aspa_san_andres" in red_layers and "aspa_san_patricio" in red_layers and "cruz_san_jorge" in red_layers, "El cantón del Red Ensign lleva las aspas de San Andrés y San Patricio y la cruz de San Jorge")
	check(bn.placements.cuartel == null and str(bn.placements.buque_popa) == "red_ensign_mercante" and str(bn.placements.plaza_toros) == "bandera_circo" and not bool(_banner_by_id(bn, "bandera_cuartel").draw_default), "Colocación de banderas: buque y circo; el cuartel no lleva bandera por defecto")
	check("japonesa" in str(_banner_by_id(bn, "bandera_cuartel").design.forbidden_look) and bn.forbidden.size() >= 9, "Se prohíbe la bandera blanca con círculo o cuadrado rojo central")
	var gm_ok: bool = str(bn.group_markers.pole.color).to_upper() != "#FFFFFF" and float(bn.group_markers.pole.height_m) <= 4.0 and bn.group_markers.colors.size() == 3
	check(gm_ok, "Los marcadores de grupo usan colores de la paleta y un asta de 3-4 m, no blanca")
	check(m.palette.mounts.keys().size() >= 8 and m.palette.riders.has("jinetes") and m.palette.water.has("turbid_near"), "La paleta tiene pelajes de caballos, ropa de jinetes y agua turbia cercana")
	var ids := {}
	for it in m.package_adoption.items:
		ids[str(it.id)] = it
	check(ids.size() >= 15 and str(ids.bajada.state) == "adaptado" and str(ids.agua_corredor.state) == "no adoptado" and str(ids.banco_expuesto.state) == "no implementado" and str(ids.piezas_18.state) == "adoptado", "package_adoption registra qué se adopta, adapta o descarta del paquete")
	var vp_ok := true
	for rp in m.barranca.ramps:
		vp_ok = vp_ok and rp.visual_path.polyline.size() >= 5 and float(rp.slope_game_pct[0]) >= 25.0
	check(vp_ok, "Las bajadas llevan camino visual largo sin cambiar la pendiente de juego")
	var lenta: Dictionary = {}
	for v in m.time.variants:
		if str(v.id) == "lenta":
			lenta = v
	check(float(lenta.drop_start_s) == 33.0 and float(lenta.drop_end_s) == 245.0 and float(lenta.low_hold_end_s) == 700.0, "La condición «lenta» corre la bajante ~15 s")
	var f := FileAccess.open("res://data/history.json", FileAccess.READ)
	var hist: Dictionary = JSON.parse_string(f.get_as_text())
	var htxt := JSON.stringify(hist.scenarios.justine).to_lower()
	var src := {}
	for sr in hist.sources:
		src[str(sr.id)] = sr
	check(not ("tuya" in htxt) and not ("del usuario" in htxt) and "inaugurada en 1801" not in htxt and "una sola vez" in htxt and "perros" in htxt and "acantilados" in htxt, "history.json: sin notas de producción, sin «inaugurada en 1801», con p. 121, p. 95 y p. 274 de Gillespie")
	check(src.has("S41") and src.has("S42") and "28 (26 cañones)" in str(src.S9.pages) and "29 (armadores" in str(src.S9.pages), "history.json: fuentes nuevas S41-S42 y páginas de Gillespie corregidas (26 cañones p. 28, armadores p. 29)")
	var chars := {}
	for c in m.characters:
		chars[str(c.id)] = c
	check(chars.has("concha") and not bool(chars.concha.in_play) and chars.has("obligado") and str(chars.obligado.tag) == "tradicion", "Concha y Obligado figuran como fuentes, no como personajes jugables")
	var old2: Dictionary = r.snapshot()
	old2.schema_version = 2
	var chk2: Dictionary = r.validate_snapshot(old2)
	check(not chk2.ok and "versión anterior del escenario Justina" in str(chk2.reason), "Un guardado de Justina v2 (preview 3) muestra el aviso claro de versión anterior")

func _banner_by_id(bn: Dictionary, id: String) -> Dictionary:
	for it in bn.items:
		if str(it.id) == id:
			return it
	return {}

func _test_package_data() -> void:
	var r := _new_j()
	var m: Dictionary = r.map_data()
	check(int(m.map_version) >= 4 and m.has("context") and m.has("scenery") and m.has("palette") and m.has("forces") and m.has("characters") and m.has("banners") and m.has("bed_warp"), "El mapa v4 trae context, scenery, palette, forces, characters, banners y bed_warp")
	var ext: Dictionary = m.context.extent
	check(r.map_size() == Vector2(900, 520) and _near(float(ext.z_max) - float(ext.z_min), 750.0, 0.01) and _near(float(ext.x_max) - float(ext.x_min), 900.0, 0.01), "Zona simulada 900 x 520 y contexto de 900 x 750 (decisión documentada)")
	# costa irregular: la línea de agua, la cresta y el pie no son rectas
	var sx: Array = []
	for pt in m.shore_high.polyline:
		sx.append(float(pt[0]))
	var tx: Array = []
	for pt in m.barranca.toe:
		tx.append(float(pt[0]))
	check(sx.max() - sx.min() >= 20.0 and tx.max() - tx.min() >= 20.0, "La costa y el pie de la barranca son irregulares (rango %.0f y %.0f m)" % [sx.max() - sx.min(), tx.max() - tx.min()])
	# los meandros del fondo: a igual x, la altura cambia con z; y es continua en el pie y mar adentro
	var h1: float = r.terrain_height_at(265.0, 120.0)
	var h2: float = r.terrain_height_at(265.0, 230.0)
	check(absf(h1 - h2) > 0.2, "bed_warp: la curva de nivel de la playa baja serpentea (x=265: %.2f m en z=120 y %.2f m en z=230)" % [h1, h2])
	check(absf(r.terrain_height_at(600.0, 120.0) - r._base_height(600.0)) < 0.01, "bed_warp no toca el fondo mar adentro")
	var toe_x: float = r._toe_x(120.0)
	check(absf(r.terrain_height_at(toe_x + 0.5, 120.0) - r.terrain_height_at(toe_x - 0.5, 120.0)) < 0.35, "El terreno es continuo en el pie de la barranca")
	# circo, casco y buque
	var by_id := {}
	for lm in m.landmarks:
		by_id[str(lm.id)] = lm
	check(_near(float(by_id.plaza_toros.radius_m) * 2.0, float(by_id.plaza_toros.vertex_span_m), 0.01) and str(by_id.plaza_toros.shape) == "octagon" and float(by_id.plaza_toros.vertex_span_m) == 90.0, "La Plaza de Toros es un octógono de 90 m entre vértices (diseño)")
	var pt: Vector2 = Vector2(float(by_id.plaza_toros.x), float(by_id.plaza_toros.z))
	check(pt.x + float(by_id.plaza_toros.radius_m) <= r._interp_crest(pt.y) + 1.0, "El circo no se sale de la cresta de la barranca")
	check(float(m.hull.length_m) == 40.0 and float(m.hull.beam_m) == 9.0 and float(m.hull.radius_m) == 16.0 and str(m.hull.tag) == "diseno", "Casco visual 40 x 9 m (diseño); el círculo de 16 m es la zona de contacto")
	check(str(m.ship.get("distance_tag", "")) == "diseno" and "400" in str(m.ship.distance_note) and "tradición discutida" in str(m.ship.distance_note).to_lower(), "Los ~400 m son tradición discutida y los 390 m, diseño, con una sola explicación")
	# fuentes, personajes y banderas
	var bn := {}
	for b in m.banners.items:
		bn[str(b.id)] = b
	check(str(bn.red_ensign_mercante.status) == "reconstruccion" and "hipótesis" in str(bn.red_ensign_mercante.status_detail), "El pabellón mercante es una hipótesis etiquetada, no una bandera identificada")
	check(str(bn.bandera_circo.status) == "reconstruccion" and not bool(bn.union_retiro.draw_default) and not bool(bn.guion_71.draw_default), "La bandera del circo es inferencia; la Union del Retiro y el guion del 71.º no se dibujan por defecto")
	var forbidden := JSON.stringify(m.banners.forbidden).to_lower()
	check("celeste y blanca" in forbidden and "infernales" in forbidden and "escarapela" in forbidden, "Se prohíben bandera celeste y blanca, escarapela e Infernales")
	var gem := {}
	for c in m.characters:
		gem[str(c.id)] = c
	check(str(gem.guemes.tag) == "tradicion" and "Infantería" in str(gem.guemes.role) and int(gem.guemes.age) == 21, "Güemes: tradición, 21 años, cadete del Regimiento de Infantería de Buenos Aires")
	check(not ("morris" in str(gem.capitan_mercante.name).to_lower()) and not ("robert morris" in JSON.stringify(m.forces).to_lower()) and "no verificad" in str(gem.capitan_mercante.notes).to_lower(), "El capitán no lleva nombre: Morris y Dunn son una pista no verificada")
	var pal: Dictionary = m.palette.package
	check(str(pal.azul_fijo) == "#253B53" and str(pal.encarnado) == "#983C3C" and str(pal.buff_ante) == "#BEAA78" and str(pal.rojo_71) == "#B6453E", "La paleta del paquete está volcada (azul del Fijo, encarnado, buff, rojo del 71.º)")
	for id in ["guemes", "arias", "zavala"]:
		var kit: Dictionary = m.forces.kits[str(m.forces.groups[id].kit_ref)]
		check(kit.has("token_color") and kit.has("colors"), "El grupo %s tiene kit de colores y color de ficha" % id)
	var f := FileAccess.open("res://data/history.json", FileAccess.READ)
	var hist: Dictionary = JSON.parse_string(f.get_as_text())
	var ids := {}
	for sr in hist.sources:
		ids[str(sr.id)] = sr
	var missing := 0
	for fact in hist.scenarios.justine.facts:
		for sid in fact.source_ids:
			if not ids.has(str(sid)):
				missing += 1
	check(missing == 0 and ids.has("S13") and ids.has("S28") and "fijo de caballería" in str(ids.S2.kind).to_lower(), "history.json: todas las fuentes citadas existen (S13-S28) y S2 advierte del «Fijo de Caballería»")
	var facts_txt := JSON.stringify(hist.scenarios.justine.facts).to_lower()
	check("infantería de buenos aires" in facts_txt and "sin datos suficientes" in facts_txt and not ("40 a 60" in facts_txt) and "sin cotejo" in facts_txt, "history.json: Güemes cadete de Infantería, presencia sin datos; la caballería de Pueyrredón es relato posterior sin cotejo y no muestra la cifra «40 a 60»")
	var pue: Dictionary = {}
	for fact in hist.scenarios.justine.facts:
		if str(fact.title).begins_with("La caballería de Pueyrredón"):
			pue = fact
	check(("tradición" in str(pue.kind).to_lower() or str(pue.kind).begins_with("reconstrucción")) and not ("documental" in str(pue.kind).to_lower()), "La caballería de Pueyrredón ya no se rotula documental")

# ---------------------------------------------------------------------------
# 5b. Resultado oculto por partida, recursos limitados, decisiones en la captura, riesgo del explorador, etiquetas y tope de guardado

func _hz(m: Dictionary, id: String) -> Dictionary:
	for hz in m.hazards:
		if str(hz.id) == id:
			return hz
	return {}

## Ronda 3: la condición del río (viento) cambia con la semilla, es visible en tide_marks y se guarda y valida.
func _test_tide_variants() -> void:
	var m: Dictionary = _new_j().map_data()
	var vs: Array = m.time.variants
	check(vs.size() >= 3 and str(vs[0].id) == "normal", "Hay al menos 3 condiciones del río y la primera es la base (%d)" % vs.size())
	var base: Dictionary = m.time
	var nv: Dictionary = vs[0]
	check(float(nv.drop_start_s) == float(base.drop_start_s) and float(nv.drop_end_s) == float(base.drop_end_s) and float(nv.low_hold_end_s) == float(base.low_hold_end_s) and float(nv.rise_end_s) == float(base.rise_end_s), "La variante normal repite los valores base de time")
	for v in vs:
		var ok: bool = float(v.drop_start_s) >= 0.0 and float(v.drop_start_s) < float(v.drop_end_s) and float(v.drop_end_s) < float(v.low_hold_end_s) and float(v.low_hold_end_s) < float(v.rise_end_s) and float(v.rise_end_s) <= float(base.deadline_s)
		check(ok and str(v.get("tag", "")) == "diseno" and str(v.get("label", "")) != "", "Condición %s: hitos ordenados, dentro del plazo, rotulada y de diseño" % str(v.id))
	var seen := {}
	var seen_m := {}
	for sd in SEEDS:
		var sj := _new_j(int(sd), true)
		seen[sj.tide_variant_id()] = true
		seen_m[str(sj.mission().get("id", ""))] = true
	check(seen.size() >= 2 and seen_m.size() >= 3, "Ronda 9: las semillas de calibración sortean ≥ 3 variantes de misión y ≥ 2 condiciones del río (%s / %s)" % [str(seen.keys()), str(seen_m.keys())])
	var a := _new_j(5, true)
	check(a.tide_variant_id() == _new_j(5, true).tide_variant_id(), "La condición del río es fija para una misma semilla")
	var other := ""
	for sd in SEEDS:
		var c := _new_j(int(sd), true)
		if c.tide_variant_id() != "normal":
			other = c.tide_variant_id()
			a = c
			break
	check(other != "", "Alguna semilla tiene una condición distinta de la normal")
	var marks: Dictionary = a.tide_marks()
	var vv: Dictionary = {}
	for v in vs:
		if str(v.id) == other:
			vv = v
	check(marks.drop_start == float(vv.drop_start_s) and marks.low_hold_end == float(vv.low_hold_end_s) and marks.rise_end == float(vv.rise_end_s) and marks.deadline == float(base.deadline_s), "tide_marks refleja la condición sorteada (%s)" % other)
	check(_near(a.tide_at(float(vv.drop_end_s) + 1.0).level_m, 0.0, 1e-6) and _near(a.tide_at(float(vv.rise_end_s)).level_m, 1.65, 1e-6), "tide_at sigue la condición sorteada")
	var path := "user://test-rules-tide.json"
	_advance(a, 400.0)
	check(a.save_game(path) == OK, "Se guarda una partida con condición del río")
	var back := Rules.new()
	check(back.load_game(path).ok and back.tide_variant_id() == other and back.tide_marks().low_hold_end == float(vv.low_hold_end_s), "Al cargar se restaura la condición del río y sus hitos")
	var snap: Dictionary = a.snapshot()
	var bad: Dictionary = snap.duplicate(true)
	bad.hidden.tide = "tormenta_inventada"
	_rejects(a, bad, "Una condición del río inventada se rechaza")
	var old: Dictionary = _new_j(7).snapshot()
	old.hidden.erase("tide")
	check(Rules.new().validate_snapshot(old).ok, "Un guardado anterior sin condición del río es válido (se lee como normal)")

func _test_hidden_layout() -> void:
	var m: Dictionary = _new_j().map_data()
	var a := _new_j(5)
	var b := _new_j(5)
	check(a.state.hidden.picks == b.state.hidden.picks, "El resultado oculto es fijo para una misma semilla")
	var variety := {}
	for sd in SEEDS:
		variety[str(_new_j(int(sd)).state.hidden.picks)] = true
	check(variety.size() >= 3, "Las semillas producen al menos 3 fondos ocultos distintos (%d)" % variety.size())
	for grp in m.hidden_layout.groups:
		var seen := {}
		for sd in SEEDS:
			seen[str(_new_j(int(sd)).state.hidden.picks[str(grp.id)])] = true
		check(seen.size() == (grp.variants as Array).size(), "El grupo %s sortea todas sus variantes entre las semillas" % str(grp.id))
	# solo UNA variante por grupo existe en el fondo de la partida: la otra es fondo normal
	for sd in [3, 5, 7, 11]:
		var g := _new_j(sd)
		for grp in m.hidden_layout.groups:
			var actives := 0
			for vid in grp.variants:
				var c := Vector2(float(_hz(m, str(vid)).center[0]), float(_hz(m, str(vid)).center[1]))
				var deep: bool = g.terrain_height_at(c.x, c.y) < -1.8
				var is_pick: bool = str(g.state.hidden.picks[str(grp.id)]) == str(vid)
				check(deep == is_pick and g.hazard_active(str(vid)) == is_pick, "Semilla %d: %s %s en el fondo de la partida" % [sd, str(vid), "existe" if is_pick else "no existe"])
				actives += 1 if deep else 0
			check(actives == 1, "Semilla %d: exactamente un hoyo por grupo (%s)" % [sd, str(grp.id)])
	# el pozo central y los falsos vados no dependen de la semilla
	check(_new_j(3).terrain_height_at(345, 264) < -1.8 and _new_j(5).terrain_height_at(345, 264) < -1.8 and _new_j(3).hazard_active("pozo_central"), "El pozo central existe en todas las partidas")
	# la malla de rutas usa el fondo de ESTA partida: el planificador cree conocer la variante activa descubierta y no la inactiva
	var r := _at(_tt(500.0), 5)
	r.state.next_volley = 1500.0
	r.state.deadline = 3000.0
	var picked: String = str(r.state.hidden.picks.flanco_central)
	var other: String = "pozo_flanco_norte" if picked == "pozo_flanco_sur" else "pozo_flanco_sur"
	var lane_pick: Array = PROBE_FLANK_S if picked == "pozo_flanco_sur" else PROBE_FLANK_N
	var lane_other: Array = PROBE_FLANK_N if picked == "pozo_flanco_sur" else PROBE_FLANK_S
	check(r.issue_scout("scout_1", "probe", lane_pick).ok and r.issue_scout("scout_2", "probe", lane_other).ok, "Los dos exploradores sondean un carril por flanco")
	_advance(r, float(r.state.elapsed) + 330.0)
	check(picked in r.state.hazards_found and other not in r.state.hazards_found, "Solo el hoyo que existe en esta partida se descubre (%s sí, %s no)" % [picked, other])
	var sc_pick: Dictionary = r.get_scout("scout_1")
	var sc_other: Dictionary = r.get_scout("scout_2")
	var pc := Vector2(float(_hz(m, picked).center[0]), float(_hz(m, picked).center[1]))
	check(Vector2(sc_pick.x, sc_pick.z).distance_to(pc) < 25.0, "El carril con hoyo termina frente a él")
	check(float(sc_other.x) >= 360.0, "El carril del flanco libre se recorre entero (x = %.0f)" % float(sc_other.x))
	# guardado y carga conservan el resultado oculto y el fondo
	var path := "user://test-rules-hidden.json"
	check(r.save_game(path) == OK, "Se guarda la partida con resultado oculto")
	var back := Rules.new()
	check(back.load_game(path).ok and back.state.hidden.picks == r.state.hidden.picks and back.hazard_active(picked) and not back.hazard_active(other), "Al cargar se restaura el mismo fondo oculto")
	check(back.terrain_height_at(pc.x, pc.y) < -1.8, "El terreno cargado tiene el hoyo de la variante elegida")
	# validacion: una variante inventada o un hallazgo de un hoyo inexistente se rechazan
	var snap: Dictionary = r.snapshot()
	var bad: Dictionary = snap.duplicate(true)
	bad.hidden.picks.flanco_central = "pozo_sur_a"
	_rejects(r, bad, "Una variante que no pertenece al grupo se rechaza")
	bad = snap.duplicate(true)
	bad.hazards_found.append(other)
	_rejects(r, bad, "Un hallazgo de un hoyo que no existe en esta partida se rechaza")
	bad = snap.duplicate(true)
	bad.erase("hidden")
	_rejects(r, bad, "Un guardado sin resultado oculto se rechaza")

func _test_scarce_resources() -> void:
	# señales de Liniers: solo 2
	var r := _new_j()
	check(int(r.resources().signals_left) == 2 and int(r.resources().ammo_reserve) == 16, "Arranque: 2 señales y 16 de pólvora de reserva")
	r.state.signals_left = 0
	var no_sig: Dictionary = r.issue_order("guemes", "signal_liniers")
	check(not no_sig.ok and "más órdenes de avance" in str(no_sig.reason), "Sin señales no se obtiene la orden de avance (motivo concreto)")
	var s := _new_j()
	s.issue_order("guemes", "signal_liniers")
	_advance(s, 200.0)
	check(int(s.state.signals_left) == 1 and s.state.advance_authorized, "Señalar consume una de las 2 señales")
	# pólvora de reserva: se agota
	var q := _new_j()
	q.state.events_done.append("mensajero")  ## el mensajero (+6 de pólvora a los 90 s) no es de este test
	q.issue_order("zavala", "resupply")
	_advance(q, 160.0)
	check(int(q.state.ammo) == 28 and int(q.state.ammo_reserve) == 0, "Abastecer retira 16 de la reserva (munición %d, reserva %d)" % [int(q.state.ammo), int(q.state.ammo_reserve)])
	q.state.ammo = 5
	var dry: Dictionary = q.issue_order("arias", "resupply")
	check(not dry.ok and "reserva" in str(dry.reason), "Agotada la reserva no se puede abastecer más (aunque falte munición)")
	# la orden de avance vale hasta llegar: si vence con un grupo en marcha, se detiene
	var e := _at(500.0, 5)
	e.state.next_volley = 1500.0
	e.state.advance_authorized = true
	e.state.advance_until = float(e.state.elapsed) + 6.0
	e.state.orders.append({"time": 0.0, "round": 1, "unit": "guemes", "action": "signal_liniers", "target": {}})
	e.state.first_order_at = 0.0
	var plan: Dictionary = e.plan_route("zavala", e.board_point(), "trot")
	var warned := false
	for w in plan.warnings:
		warned = warned or ("vence" in str(w))
	check(plan.ok and warned, "plan_route avisa si la orden de avance vence antes de llegar al buque")
	check(e.issue_order("zavala", "board", Vector2.ZERO, {"pace": "trot"}).ok, "Con la orden vigente se acepta cargar")
	_advance(e, float(e.state.elapsed) + 10.0)
	check(not e.state.advance_authorized and e.get_unit("zavala").stage == "ready" and e.get_unit("zavala").order.is_empty() and int(e.state.stats.halted_by_expiry) >= 1, "Al vencer la orden de avance el grupo en marcha se detiene")

func _counter_game() -> RefCounted:
	var b := _boarding_game(500.0)
	b.state.ammo = 12
	b.state.counter.next_at = float(b.state.elapsed) + 1.0
	return b

func _test_capture_decisions() -> void:
	var cfg: Dictionary = _new_j().map_data().ship.capture.counter
	# sin respuesta: la dotación golpea y la captura retrocede
	var b := _counter_game()
	b.state.capture = 40.0
	var hp0 := float(b.get_unit("guemes").strength)
	var rj: Dictionary = b.issue_order("guemes", "repel")
	check(not rj.ok and "contraataque" in str(rj.reason), "Rechazar sin contraataque en curso se rechaza con motivo")
	_advance(b, float(b.state.elapsed) + 3.0)
	check(bool(b.state.counter.active) and not bool(b.state.counter.answered), "La dotación contraataca y abre una ventana de decisión")
	var av: Dictionary = b.action_availability("guemes", "repel")
	check(av.ok and "ventana" in str(av.reason) and "munición" in str(av.cost_text), "La acción Rechazar está disponible durante la ventana, con costo")
	_advance(b, float(b.state.counter.until) - 0.5)
	var cap_before := float(b.state.capture)
	_advance(b, float(b.state.counter.until) + 0.5)
	var lost_unanswered := hp0 - float(b.get_unit("guemes").strength)
	check(int(b.state.stats.counter_hits) == 1 and lost_unanswered >= float(cfg.damage) * 0.9 and float(b.state.capture) < cap_before - float(cfg.capture_loss_pct) * 0.8, "Contraataque sin contestar: −%.0f de fuerza (obtenido %.1f) y la captura retrocede %.0f %%" % [float(cfg.damage), lost_unanswered, cap_before - float(b.state.capture)])
	# con respuesta: cuesta munición pero el daño baja a la cuarta parte
	var c := _counter_game()
	c.state.capture = 40.0
	var hp1 := float(c.get_unit("guemes").strength)
	var ammo0 := int(c.state.ammo)
	_advance(c, float(c.state.elapsed) + 3.0)
	var ok_r: Dictionary = c.issue_order("guemes", "repel")
	check(ok_r.ok and int(c.state.ammo) == ammo0 - int(cfg.repel_ammo) and bool(c.state.counter.answered), "Rechazar el contraataque cuesta %d de munición" % int(cfg.repel_ammo))
	check(not c.issue_order("guemes", "repel").ok, "No se puede rechazar dos veces el mismo contraataque")
	_advance(c, float(c.state.elapsed) + float(cfg.window_s) + 1.0)
	var lost_answered := hp1 - float(c.get_unit("guemes").strength)
	check(int(c.state.stats.counter_repelled) == 1 and lost_answered < lost_unanswered * 0.5 and lost_answered >= float(cfg.damage) * float(cfg.repelled_mult) * 0.9, "Contraataque rechazado: pierde solo %.1f (frente a %.1f sin contestar)" % [lost_answered, lost_unanswered])
	# sin munición no se puede rechazar
	var d := _counter_game()
	d.state.ammo = 1
	_advance(d, float(d.state.elapsed) + 3.0)
	var no_ammo: Dictionary = d.issue_order("guemes", "repel")
	check(not no_ammo.ok and "municiones" in str(no_ammo.reason), "Sin munición no se puede rechazar el contraataque")
	# heridos: el cuerpo a cuerpo los produce y evacuarlos devuelve fuerza a costa de poder de captura
	var e := _boarding_game(500.0)
	e.get_unit("guemes").strength = 60.0
	e.state.counter.next_at = 90000.0
	var no_w: Dictionary = e.issue_order("guemes", "evacuate")
	check(not no_w.ok and "heridos" in str(no_w.reason), "Sin heridos no hay nada que evacuar")
	_advance(e, 560.0)
	var wounded := float(e.get_unit("guemes").wounded)
	check(wounded > 0.0 and _near(wounded, float(e.state.stats.melee_loss) * float(e.map_data().ship.capture.wounded_share), 0.01), "El cuerpo a cuerpo deja heridos (%.2f)" % wounded)
	e.get_unit("guemes").wounded = 12.0
	var hp2 := float(e.get_unit("guemes").strength)
	var cap0 := float(e.state.capture)
	check(e.issue_order("guemes", "evacuate").ok, "Evacuar heridos se acepta con heridos suficientes")
	_advance(e, float(e.state.elapsed) + float(e.map_data().ship.capture.evacuate_s) + 1.0)
	var gained := float(e.get_unit("guemes").strength) - hp2
	check(gained > 12.0 * 0.6 - 2.0 and float(e.get_unit("guemes").wounded) < 12.0 and int(e.state.stats.evacuations) == 1, "Evacuar recupera el 60 %% de los heridos (+%.1f de fuerza)" % gained)
	check(float(e.state.capture) - cap0 < 1.0, "Mientras evacúa, el grupo no suma poder de captura (+%.2f %%)" % (float(e.state.capture) - cap0))
	# solo se puede desde el abordaje
	var f := _new_j()
	check(not f.issue_order("guemes", "evacuate").ok and not f.issue_order("guemes", "repel").ok, "Rechazar y evacuar solo valen para grupos que ya abordan")
	# retirar un grupo del abordaje se lleva a los heridos (mitad de lo que recupera evacuar)
	var w := _boarding_game(500.0)
	w.get_unit("guemes").strength = 60.0
	w.state.counter.next_at = 90000.0
	w.get_unit("guemes").wounded = 10.0
	var hp3 := float(w.get_unit("guemes").strength)
	check(w.issue_order("guemes", "withdraw").ok and float(w.get_unit("guemes").strength) > hp3 + 2.0, "Retirar del abordaje se lleva a los heridos (+%.1f de fuerza)" % (float(w.get_unit("guemes").strength) - hp3))
	# el guardado en pleno abordaje con un contraataque abierto es valido y se recarga
	var h := _counter_game()
	_advance(h, float(h.state.elapsed) + 3.0)
	check(h.validate_snapshot(h.snapshot()).ok, "El estado con un contraataque abierto es un guardado válido")
	var bad: Dictionary = h.snapshot()
	bad.counter.until = "x"
	_rejects(h, bad, "Un contraataque con datos inválidos se rechaza")
	# aviso del agua que sube en el vado (gestion de la marea)
	var t := _boarding_game(_tt(930.0))
	t.state.counter.next_at = 90000.0
	_advance(t, _tt(975.0))
	var tide_warned := false
	for ev in t.state.log:
		tide_warned = tide_warned or ("el agua sube en el vado" in str(ev.text))
	check(tide_warned, "Se avisa que el agua sube en el vado antes de que ahogue a los de a pie")

## Ronda 9 (C7): la descarga se anuncia antes, se puede esquivar y cada 6.ª es una andanada fuerte con aviso más largo.
func _test_round9_telegraph() -> void:
	var tg: Dictionary = _new_j().map_data().ship.fire.telegraph
	var r := _at(_tt(400.0), 5)
	var g: Dictionary = r.get_unit("guemes")
	g.x = 420.0
	g.z = 262.0
	g.stage = "ready"
	var t0 := float(r.state.elapsed)
	r.state.next_volley = t0 + 6.0
	var warn: Dictionary = {}
	var impact_t := -1.0
	var hp0 := float(g.strength)
	while float(r.state.elapsed) < t0 + 8.0:
		for ev in r.tick(0.25):
			if str(ev.kind) == "shot_warning" and warn.is_empty():
				warn = ev
			if str(ev.kind) == "shot" and impact_t < 0.0:
				impact_t = float(ev.time)
	check(not warn.is_empty() and float(warn.eta) >= 2.5 and not bool(warn.strong), "Toda descarga se anuncia con ≥ 2,5 s de antelación (eta %.2f s)" % float(warn.get("eta", 0.0)))
	check(impact_t >= t0 + 6.0 - 0.001 and impact_t - float(warn.get("time", 0.0)) >= 2.5, "El impacto llega después del aviso (aviso t=%.2f, impacto t=%.2f)" % [float(warn.get("time", 0.0)), impact_t])
	var dmg := hp0 - float(r.get_unit("guemes").strength)
	check(dmg > 0.0 and dmg <= float(tg.get("strong_mult", 1.5)) * 0.0 + 9.001, "Un grupo parado recibe la descarga avisada (−%.1f)" % dmg)
	# esquivar: el grupo se aleja más que el radio durante el aviso y la descarga cae al agua
	var d := _at(_tt(400.0), 5)
	var gd: Dictionary = d.get_unit("guemes")
	gd.x = 420.0
	gd.z = 262.0
	gd.stage = "ready"
	var td := float(d.state.elapsed)
	d.state.next_volley = td + 6.0
	var moved := false
	while float(d.state.elapsed) < td + 8.0:
		d.tick(0.25)
		if not moved and not d.state.pending_shot.is_empty():
			gd.x = 380.0
			moved = true
	check(moved and is_equal_approx(float(d.get_unit("guemes").strength), 100.0) and int(d.state.stats.shots_dodged) == 1, "Si el grupo se aleja durante el aviso la descarga no lo toca (esquivadas: %d)" % int(d.state.stats.shots_dodged))
	# andanada fuerte: cada 6.ª, aviso de 4 s y más daño
	var f := _at(_tt(400.0), 5)
	var gf: Dictionary = f.get_unit("guemes")
	gf.x = 420.0
	gf.z = 262.0
	gf.stage = "ready"
	f.state.volley_n = int(tg.strong_every_n) - 1
	var tf := float(f.state.elapsed)
	f.state.next_volley = tf + 6.0
	var sw: Dictionary = {}
	while float(f.state.elapsed) < tf + 8.0:
		for ev in f.tick(0.25):
			if str(ev.kind) == "shot_warning" and sw.is_empty():
				sw = ev
	var sdmg := 100.0 - float(f.get_unit("guemes").strength)
	check(not sw.is_empty() and bool(sw.strong) and float(sw.eta) >= 3.5 and int(f.state.stats.strong_volleys) == 1, "La 6.ª descarga es una andanada fuerte con aviso de ≥ 3,5 s (eta %.2f)" % float(sw.get("eta", 0.0)))
	check(sdmg > 9.0 * 0.99 and sdmg <= 13.5 + 0.01, "La andanada fuerte pega más que una normal (−%.1f)" % sdmg)
	# reaccionar al aviso reduce el daño por andanada a la mitad o menos
	var no_react := 0.0
	var react := 0.0
	for sd in [3, 5, 7, 11]:
		for mode in [0, 1]:
			var q := _at(_tt(400.0), sd)
			var gq: Dictionary = q.get_unit("guemes")
			gq.x = 430.0
			gq.z = 262.0
			gq.stage = "ready"
			var tq := float(q.state.elapsed)
			q.state.next_volley = tq + 6.0
			var did := false
			var side := 1.0
			while float(q.state.elapsed) < tq + 90.0:
				q.tick(0.25)
				if mode == 1 and not q.state.pending_shot.is_empty() and not did:
					did = true
					gq.x = float(gq.x) + 30.0 * side
					side = -side
				if q.state.pending_shot.is_empty():
					did = false
			if mode == 0:
				no_react += 100.0 - float(gq.strength)
			else:
				react += 100.0 - float(gq.strength)
	check(no_react > 0.0 and react <= no_react * 0.5, "Un jugador que reacciona al aviso recibe ≤ 50 %% del daño (%.0f vs %.0f en 90 s)" % [react, no_react])

## Ronda 9 (C8, C11, C12): contraataque con aviso y consecuencias, quiebre gradual, último esfuerzo y medallas.
func _test_round9_counter_and_morale() -> void:
	var cfg: Dictionary = _new_j().map_data().ship.capture.counter
	var b := _counter_game()
	b.state.capture = 50.0
	b.state.counter.next_at = float(b.state.elapsed) + 8.0
	var warn_t := -1.0
	var act_t := -1.0
	var tb := float(b.state.elapsed)
	while float(b.state.elapsed) < tb + 20.0:
		for ev in b.tick(0.25):
			if str(ev.kind) == "counter_warning" and warn_t < 0.0:
				warn_t = float(ev.time)
		if bool(b.state.counter.active) and act_t < 0.0:
			act_t = float(b.state.elapsed)
	check(warn_t >= 0.0 and act_t - warn_t >= float(cfg.warn_s) - 0.5, "El contraataque se avisa %.0f s antes (aviso t=%.1f, ventana t=%.1f)" % [float(cfg.warn_s), warn_t, act_t])
	var ign := _counter_game()
	ign.state.capture = 60.0
	var rep_g := _counter_game()
	rep_g.state.capture = 60.0
	_advance(ign, float(ign.state.elapsed) + 3.0)
	_advance(rep_g, float(rep_g.state.elapsed) + 3.0)
	rep_g.issue_order("guemes", "repel")
	_advance(ign, float(ign.state.counter.until) + 0.5)
	_advance(rep_g, float(rep_g.state.counter.until) + 0.5)
	check(float(rep_g.state.capture) - float(ign.state.capture) >= float(cfg.capture_loss_pct) * (1.0 - float(cfg.repelled_mult)) - 4.0, "No contestar baja la captura ~%.0f; rechazar solo ~%.0f (%.1f vs %.1f)" % [float(cfg.capture_loss_pct), float(cfg.capture_loss_pct) * float(cfg.repelled_mult), float(ign.state.capture), float(rep_g.state.capture)])
	# quiebre gradual
	var q := _boarding_game(_tt(500.0))
	q.state.counter.next_at = 90000.0
	var gq: Dictionary = q.get_unit("guemes")
	gq.strength = 60.0
	q.tick(0.25)
	var cap_a := float(q.state.capture)
	_advance(q, float(q.state.elapsed) + 4.0)
	var gain_ok := float(q.state.capture) > cap_a
	gq.strength = 20.0
	q.tick(0.25)
	check(gain_ok and bool(gq.shaken), "Un grupo con ≤ 25 de fuerza queda quebrado")
	var cap_b := float(q.state.capture)
	_advance(q, float(q.state.elapsed) + 4.0)
	check(float(q.state.capture) <= cap_b + 0.0001, "El grupo quebrado no suma captura")
	gq.strength = 40.0
	q.tick(0.25)
	check(not bool(gq.shaken), "Al pasar de 38 de fuerza el grupo se rehace")
	# último esfuerzo
	var m := _boarding_game(_tt(500.0))
	m.state.counter.next_at = 90000.0
	m.state.capture = 86.7
	for u in m.state.units:
		u.strength = 18.0
		u.stage = "ready"
		u.order = {}
	m.tick(0.25)
	check(m.state.status == "playing" and float(m.state.last_effort.until) > 0.0, "Con todos quebrados y 86,7 %% de captura se abre la ventana del último esfuerzo (no hay derrota instantánea)")
	check(m.last_effort_available().ok, "El último esfuerzo está disponible")
	var use: Dictionary = m.last_effort()
	check(use.ok and bool(m.state.last_effort.used) and float(m.get_unit("guemes").strength) >= 45.0 and not bool(m.get_unit("guemes").shaken), "Usar el último esfuerzo suma fuerza y saca del quiebre")
	check(not m.last_effort().ok, "El último esfuerzo es de una sola vez")
	var w := _boarding_game(_tt(500.0))
	w.state.counter.next_at = 90000.0
	w.state.capture = 86.7
	for u2 in w.state.units:
		u2.strength = 18.0
		u2.stage = "ready"
		u2.order = {}
	_advance(w, float(w.state.elapsed) + 20.0)
	var rw: Dictionary = w.campaign_report()
	check(w.state.status == "defeat" and str(w.state.defeat_cause) == "dispersos" and "último esfuerzo" in str(w.state.reason), "Si la ventana vence sin usarlo, la derrota nombra el último esfuerzo")
	check(rw.capture_pct > 80.0 and not bool(rw.last_effort_used), "El parte registra la captura alta y que no se usó")
	# medallas
	var med := _new_j()
	med.state.stats.marked_m = 40.0
	med.state.elapsed = 520.0
	check(med._medal(true, 30.0, []) == "oro" and med._medal(true, 30.0, ["baqueano"]) == "plata", "Oro con bajas < 32 %%, < 9:00 y sin ayudas; con baqueano baja a plata")
	check(med._medal(true, 50.0, []) == "plata" and med._medal(true, 70.0, []) == "bronce" and med._medal(false, 10.0, []) == "", "Plata con bajas < 55 %% y vado marcado; bronce al ganar; sin victoria no hay medalla")
	med.state.stats.marked_m = 0.0
	check(med._medal(true, 50.0, []) == "bronce", "Sin vado marcado no hay plata")
	med.state.stats.marked_m = 40.0
	med.state.elapsed = 700.0
	check(med._medal(true, 30.0, []) == "plata", "Tarde (> 10:00) no hay oro")

## Ronda 9 (C5, C10, C18, C19, ayudas): variantes de misión, eventos de campo, elección del mensajero, baqueano y bajante generosa.
func _test_round9_flow() -> void:
	var mv: Array = _new_j().map_data().mission_variants.list
	check(mv.size() >= 3, "Hay al menos 3 variantes de misión (%d)" % mv.size())
	var seen := {}
	for sd in SEEDS:
		var id1 := str(_new_j(int(sd), true).mission().get("id", ""))
		seen[id1] = true
		check(id1 == str(_new_j(int(sd), true).mission().get("id", "")), "La variante de misión es fija para la semilla %d" % int(sd))
	check(seen.size() >= 3, "Las semillas de calibración sortean ≥ 3 variantes distintas (%s)" % str(seen.keys()))
	for v in mv:
		var jr: RefCounted = null
		for sd2 in range(1, 300):
			var cand := Rules.new()
			cand.new_game("justine", sd2)
			if str(cand.mission().id) == str(v.id):
				jr = cand
				break
		check(jr != null, "Existe una semilla para la variante %s" % str(v.id))
		if jr == null:
			continue
		if v.has("ammo_start_delta"):
			check(int(jr.state.ammo) == 12 + int(v.ammo_start_delta) and float(jr.state.volunteers_pool) == 60.0 + float(v.get("volunteers_delta", 0.0)), "Variante %s: munición y voluntarios iniciales" % str(v.id))
		if v.has("volley_mult"):
			check(_near(float(jr.state.next_volley), 7.5 * float(v.volley_mult), 1e-6) and _near(float(jr.state.crew_morale), float(v.crew_morale), 1e-6), "Variante %s: descargas más seguidas y dotación con menos moral" % str(v.id))
		if v.has("tide"):
			check(jr.tide_variant_id() == str(v.tide), "Variante %s: fija la condición del río" % str(v.id))
		if v.has("fire_mult"):
			var base := _new_j(3)
			check(_near(jr.exposure_at(500.0, 380.0) / maxf(0.001, base.exposure_at(500.0, 380.0)), float(v.fire_mult.get("sur", 1.0)), 0.01) and _near(jr.exposure_at(480.0, 262.0) / maxf(0.001, base.exposure_at(480.0, 262.0)), float(v.fire_mult.get("central", 1.0)), 0.01), "Variante %s: el fuego se modula por zona (sur ×%.1f, centro ×%.1f)" % [str(v.id), float(v.fire_mult.get("sur", 1.0)), float(v.fire_mult.get("central", 1.0))])
	# eventos de campo: ≥ 6 y nunca más de 90 s sin un evento en los primeros 5 min
	var ev_game := _new_j(7, true)
	ev_game.state.next_volley = 5000.0
	var times: Array = [0.0]
	while float(ev_game.state.elapsed) < 600.0 and ev_game.state.status == "playing":
		for ev in ev_game.tick(1.0):
			if str(ev.kind) in ["mission", "liniers", "choice", "hint", "tide", "reinforce", "counter_warning", "shot_warning"]:
				times.append(float(ev.time))
	var field_n := 0
	for ev2 in ev_game.state.log:
		if str(ev2.get("field_event", "")) != "" and not str(ev2.field_event).begins_with("sin_retorno"):
			field_n += 1
	var gap := 0.0
	for i in range(1, times.size()):
		if times[i] <= 300.0:
			gap = maxf(gap, float(times[i]) - float(times[i - 1]))
	check(field_n >= 6, "Hay ≥ 6 eventos de campo por partida (%d)" % field_n)
	check(gap <= 90.0, "En los primeros 5 min nunca pasan más de 90 s sin un evento (máx. %.0f s)" % gap)
	var mm: Dictionary = ev_game.mission()
	var first_text := ""
	var first_t := 999.0
	for ev3 in ev_game.state.log:
		if str(ev3.get("field_event", "")) == "aviso_mision":
			first_text = str(ev3.text)
			first_t = float(ev3.time)
	check(first_t <= 30.0 and str(mm.label) in first_text, "El aviso de la variante sale antes de 0:30 y nombra la variante")
	# elección del mensajero
	var ch := _new_j(7)
	ch.state.next_volley = 5000.0
	_advance(ch, 95.0)
	check(not ch.state.pending_choice.is_empty(), "El mensajero abre una elección")
	var vol0 := float(ch.state.volunteers_pool)
	check(ch.resolve_choice("voluntarios").ok and float(ch.state.volunteers_pool) == vol0 + 30.0 and ch.state.pending_choice.is_empty(), "Elegir voluntarios suma 30 a la reserva")
	var ch2 := _new_j(7)
	ch2.state.next_volley = 5000.0
	var am0 := int(ch2.state.ammo)
	_advance(ch2, 125.0)
	check(ch2.state.pending_choice.is_empty() and int(ch2.state.ammo) == am0 + 6 and not ch2.resolve_choice("polvora").ok, "Sin respuesta se toma la pólvora (+6) a los 25 s")
	# el vecino dice la verdad sobre el flanco (pista, no hallazgo)
	var hint_game := _new_j(7)
	hint_game.state.next_volley = 5000.0
	_advance(hint_game, 155.0)
	var hint_txt := ""
	for ev4 in hint_game.state.log:
		if str(ev4.get("field_event", "")) == "vecino":
			hint_txt = str(ev4.text)
	var bad_side := "norte" if str(hint_game.state.hidden.picks.flanco_central) == "pozo_flanco_norte" else "sur"
	check(("lado " + bad_side) in hint_txt and hint_game.state.hazards_found.is_empty(), "El vecino avisa el flanco con el hoyo (%s) sin marcarlo como confirmado" % bad_side)
	# baqueano y bajante generosa
	var bq := _new_j(7)
	var am1 := int(bq.state.ammo)
	check(bq.apply_assist("baqueano").ok and str(bq.state.hidden.picks.flanco_central) in bq.state.hazards_found and int(bq.state.ammo) == am1 + 8, "Baqueano: revela el hoyo del flanco y suma 8 de munición")
	check(not bq.apply_assist("baqueano").ok and bq.campaign_report().assists_used == ["baqueano"], "El baqueano se usa una vez y queda marcado en el parte")
	var bj := _new_j(7)
	var dl0 := float(bj.state.deadline)
	var close0: float = bj.ford_window(548, 262).closes_at
	check(bj.apply_assist("bajante_generosa").ok and _near(float(bj.state.deadline), dl0 + 60.0, 1e-6) and _near(float(bj.tide_marks().deadline), dl0 + 60.0, 1e-6), "Bajante generosa: +60 s de ventana y de plazo")
	check(float(bj.ford_window(548, 262).closes_at) > close0 + 50.0, "...y el vado cierra más tarde")
	check(not _new_j(7).apply_assist("inventada").ok, "Una ayuda desconocida se rechaza")
	# prima de ruta
	var rc := _boarding_game(_tt(500.0))
	var rs := _boarding_game(_tt(500.0))
	rc.get_unit("guemes").route_s = {"central": 30.0, "sur": 0.0}
	rs.get_unit("guemes").route_s = {"central": 0.0, "sur": 30.0}
	for x in [rc, rs]:
		x.state.counter.next_at = 90000.0
		_advance(x, float(x.state.elapsed) + 6.0)
	var prem: Dictionary = rc.map_data().ship.capture.route_premium
	check(float(rc.state.capture) > float(rs.state.capture) * (float(prem.central) / float(prem.sur)) * 0.9, "La ruta central premia el abordaje (×%.2f frente a ×%.2f): %.2f vs %.2f" % [float(prem.central), float(prem.sur), float(rc.state.capture), float(rs.state.capture)])
	var tv: Array = rc.map_data().time.variants
	var ids: Array = []
	for v2 in tv:
		ids.append(str(v2.id))
	check("breve" not in ids, "No queda la variante de río «breve» (injusta)")
	for v3 in tv:
		var jr2 := _new_j(3)
		jr2.state.hidden.tide = str(v3.id)
		var bp: Vector2 = jr2.board_point()
		jr2.state.probes.append({"id": "t1", "kind": "lane", "pts": [{"x": bp.x - 8.0, "z": bp.y}, {"x": bp.x + 8.0, "z": bp.y}], "width": 6.0, "t": 0.0, "scout": "scout_1"})
		check(float(jr2.ford_window(bp.x, bp.y).opens_at) <= 3.5 * 60.0, "La ventana del vado abre ≤ 3:30 con la condición %s (%.0f s)" % [str(v3.id), float(jr2.ford_window(bp.x, bp.y).opens_at)])

## Ronda 9 (C1-C3, C17): mundo fijo hasta ganar, diario, ayudas, parte de derrota, desbloqueo del Norte. Usa archivos temporales propios.
func _test_round9_campaign() -> void:
	var path := "user://test-campaign.json"
	DirAccess.remove_absolute(path)
	var cp := CampaignProgress.new(path)
	check(not cp.load_progress() and cp.data.attempts == 0 and not cp.north_unlocked(), "Perfil nuevo: sin progreso y Norte bloqueado")
	var first := cp.world_seed(4242)
	var same := 0
	var ref := Rules.new()
	ref.new_game("justine", first)
	for i in range(50):
		var again := CampaignProgress.new(path)
		again.load_progress()
		var rg := Rules.new()
		rg.new_game("justine", again.world_seed())
		if again.world_seed() == first and rg.state.hidden == ref.state.hidden:
			same += 1
	check(same == 50, "En 50 reinicios el mundo (pozos, vado, variante) es idéntico (%d/50)" % same)
	var changed := 0
	var prev_seed := first
	for j in range(20):
		var wn := CampaignProgress.new(path)
		wn.load_progress()
		var ns := wn.new_world(1000 + j * 31)
		var a := Rules.new()
		a.new_game("justine", prev_seed)
		var b := Rules.new()
		b.new_game("justine", ns)
		if ns != prev_seed and (a.state.hidden.picks != b.state.hidden.picks or a.mission().id != b.mission().id):
			changed += 1
		prev_seed = ns
	check(changed >= 18, "«Río nuevo» cambia el fondo o la variante en 18 de 20 casos (%d/20)" % changed)
	var persisted := CampaignProgress.new(path)
	check(persisted.load_progress() and persisted.world_seed() == prev_seed, "La semilla sobrevive a cerrar y abrir el juego")
	# diario
	var cp2 := CampaignProgress.new("user://test-campaign2.json")
	cp2.reset_all()
	var r: RefCounted = _run_expert_rules(21)
	var r_pits: Array = r.state.hazards_found.duplicate()
	var learned: Array = cp2._learn(r, r.campaign_report())
	var marks: Array = cp2.diary_marks()
	var pits := 0
	var fords := 0
	for mk in marks:
		check(not bool(mk.confirmed), "Una marca del diario no es conocimiento confirmado")
		if mk.kind == "pozo":
			pits += 1
		if mk.kind == "vado":
			fords += 1
	check(pits == r_pits.size() and fords == r.state.fords_found.size(), "El diario guarda exactamente lo descubierto: %d pozos y %d vados (marcas: %d pozos, %d vados)" % [r_pits.size(), r.state.fords_found.size(), pits, fords])
	check(learned.size() >= 1, "Hay entradas nuevas para el globo «anotamos lo que descubriste»")
	var nxt := Rules.new()
	nxt.new_game("justine", int(r.state.seed))
	cp2.begin_attempt(nxt)
	check(nxt.diary_marks.size() == marks.size() and nxt.state.hazards_found.is_empty() and nxt.state.fords_found.is_empty(), "Las marcas llegan al reglamento sin contar como conocimiento (hazards_found sigue vacío)")
	# resultado, ayudas escalonadas y parte de derrota
	var cp3 := CampaignProgress.new("user://test-campaign3.json")
	cp3.reset_all()
	var lose := Rules.new()
	lose.new_game("justine", 5)
	cp3.begin_attempt(lose)
	lose.retreat_all()
	var res1: Dictionary = cp3.record_result(lose)
	check(not res1.won and str(res1.cause) != "" and str(res1.advice) != "" and res1.offered_assists.is_empty() and int(res1.defeats_in_row) == 1, "Derrota 1: parte con causa y consejo, sin ayudas")
	for n in range(2):
		var l2 := Rules.new()
		l2.new_game("justine", 5)
		cp3.begin_attempt(l2)
		l2.retreat_all()
		var rr: Dictionary = cp3.record_result(l2)
		if n == 0:
			check(int(rr.defeats_in_row) == 2 and rr.offered_assists.is_empty(), "Derrota 2: todavía sin ayudas (solo pista)")
		else:
			check(int(rr.defeats_in_row) == 3 and rr.offered_assists.size() == 1 and str(rr.offered_assists[0].id) == "baqueano", "Derrota 3: se ofrece el baqueano (opcional)")
	var pr := Rules.new()
	pr.new_game("justine", 5)
	check(cp3.apply_assists(pr, ["bajante_generosa"]).is_empty() and cp3.apply_assists(pr, ["baqueano"]) == ["baqueano"], "Solo se aplican las ayudas ofrecidas")
	for n2 in range(2):
		var l3 := Rules.new()
		l3.new_game("justine", 5)
		cp3.begin_attempt(l3)
		l3.retreat_all()
		cp3.record_result(l3)
	var l4 := Rules.new()
	l4.new_game("justine", 5)
	var ids5: Array = []
	for o in cp3.offered_assists(l4):
		ids5.append(str(o.id))
	check(ids5 == ["baqueano", "bajante_generosa"], "Derrota 5: también se ofrece la bajante generosa (%s)" % str(ids5))
	check(not cp3.north_unlocked() and not bool(cp3.data.justina_won), "Sin ganar, el Norte sigue bloqueado")
	# causas de derrota: todas con texto breve y sin jerga
	var causes: Dictionary = _new_j().map_data().campaign.defeat_causes
	var jerga := ["zoc", "tag", "halted_by_expiry", "stage", "json", "bug"]
	for cid in ["plazo", "dispersos", "retirada", "inaccion"]:
		check(causes.has(cid) and str(causes[cid].cause).length() <= 140 and str(causes[cid].advice).length() > 10, "La causa «%s» tiene texto de ≤ 140 caracteres y consejo" % cid)
		var words: PackedStringArray = (str(causes[cid].cause) + " " + str(causes[cid].advice)).to_lower().split(" ")
		var clean := true
		for j2 in jerga:
			clean = clean and (j2 not in words)
		check(clean, "La causa «%s» no usa jerga" % cid)
	# victoria: medalla, desbloqueo y persistencia
	var cp4 := CampaignProgress.new("user://test-campaign4.json")
	cp4.reset_all()
	var wr: RefCounted = _run_expert_rules(21)
	var rwin: Dictionary = cp4.record_result(wr)
	check(rwin.won and str(rwin.medal) in ["bronce", "plata", "oro"] and rwin.unlocked_north and cp4.north_unlocked() and (rwin.lines as Array).size() >= 3, "Victoria: medalla (%s), tres líneas y Norte desbloqueado" % str(rwin.medal))
	var back := CampaignProgress.new("user://test-campaign4.json")
	check(back.load_progress() and back.north_unlocked() and str(back.data.best_medal) == str(rwin.medal) and int(back.data.world_seed) == 0, "Tras ganar el Norte queda habilitado y persiste; el mundo se vuelve a sortear")
	var f := FileAccess.open("user://test-campaign5.json", FileAccess.WRITE)
	f.store_string("{ esto no es json")
	f.close()
	var bad := CampaignProgress.new("user://test-campaign5.json")
	check(not bad.load_progress() and bad.load_note != "" and bad.data.attempts == 0, "Un progreso dañado se descarta con aviso y no bloquea")
	for pth in ["user://test-campaign.json", "user://test-campaign2.json", "user://test-campaign3.json", "user://test-campaign4.json", "user://test-campaign5.json"]:
		DirAccess.remove_absolute(pth)

## Partida completa de la línea experta central (victoria) para pruebas de campaña; devuelve el reglamento terminado.
func _run_expert_rules(seed_value: int) -> RefCounted:
	var res := _run_cfg(_strategy_cfg("central_flank_pair"), "central_flank_pair", seed_value, {})
	var k := 1
	while res.status != "victory" and k < 12:
		res = _run_cfg(_strategy_cfg("central_flank_pair"), "central_flank_pair", seed_value + k, {})
		k += 1
	return res.rules

func _test_scout_risk() -> void:
	var r := _at(500.0, 5)
	r.state.next_volley = 1500.0
	var pts: Array = [Vector2(300, 264), Vector2(362, 264)]
	var plain: Dictionary = r.scout_risk("scout_1", pts, false)
	var safe: Dictionary = r.scout_risk("scout_1", pts, true)
	check(float(plain.exposed_s) > 0.0 and float(plain.expected_hits) > 0.0 and int(plain.hp) == 4, "scout_risk estima segundos expuestos e impactos esperados")
	check(float(safe.death_pct) < float(plain.death_pct) and float(safe.expected_hits) < float(plain.expected_hits), "El sondeo cauteloso baja el riesgo de baja (%.0f %% vs %.0f %%)" % [float(safe.death_pct), float(plain.death_pct)])
	var av: Dictionary = r.action_availability("scout_1", "probe", Vector2(362, 264))
	var av2: Dictionary = r.action_availability("scout_1", "probe_careful", Vector2(362, 264))
	check(av.ok and "baja" in str(av.reason) and av2.ok and "cauteloso" in str(av2.reason), "La disponibilidad del sondeo informa el riesgo estimado de baja")
	check(r.get_scout("scout_1").has("cautious") and not bool(r.get_scout("scout_1").cautious), "El explorador guarda si sondea cauteloso")
	# velocidad: solo donde el buque alcanza se avanza agachado
	var fast := _at(500.0, 5)
	fast.state.next_volley = 1500.0
	var slow := _at(500.0, 5)
	slow.state.next_volley = 1500.0
	for g in [fast, slow]:
		g.get_scout("scout_1").x = 330.0
		g.get_scout("scout_1").z = 240.0
	var o1: Dictionary = fast.issue_scout("scout_1", "probe", [Vector2(362, 240)])
	var o2: Dictionary = slow.issue_scout("scout_1", "probe", [Vector2(362, 240)], {"cautious": true})
	check(o1.ok and o2.ok and "Riesgo" in str(o2.reason) and bool(slow.get_scout("scout_1").cautious), "issue_scout informa el riesgo y recuerda que es cauteloso")
	_advance(fast, 510.0)
	_advance(slow, 510.0)
	var dx_fast := float(fast.get_scout("scout_1").x) - 330.0
	var dx_slow := float(slow.get_scout("scout_1").x) - 330.0
	check(dx_slow > 0.0 and _near(dx_slow / maxf(0.01, dx_fast), 0.7, 0.1), "Bajo el fuego el sondeo cauteloso avanza a 0,7 de la velocidad (%.1f vs %.1f m)" % [dx_slow, dx_fast])
	# expuesto, el explorador cauteloso recibe menos impactos (esperanza)
	var hits_plain := 0
	var hits_safe := 0
	for sd in range(1, 41):
		var a := _at(400.0, sd)
		var b := _at(400.0, sd)
		for g in [a, b]:
			g.get_scout("scout_1").x = 450.0
			g.get_scout("scout_1").z = 262.0
			g.get_scout("scout_1").stage = "probing"
			g.get_scout("scout_1").order = {"action": "probe", "points": [{"x": 520.0, "z": 262.0}]}
			g.get_scout("scout_1").path = [{"x": 520.0, "z": 262.0}]
			g.get_scout("scout_1").hp = 4
			g.state.next_volley = float(g.state.elapsed) + 0.5
		b.get_scout("scout_1").cautious = true
		a.tick(40.0)
		b.tick(40.0)
		hits_plain += 4 - int(a.get_scout("scout_1").hp)
		hits_safe += 4 - int(b.get_scout("scout_1").hp)
	check(hits_safe < hits_plain, "En 40 partidas el explorador cauteloso recibe menos impactos (%d vs %d)" % [hits_safe, hits_plain])

func _test_labels_and_save_trim() -> void:
	var m: Dictionary = _new_j().map_data()
	var by_id := {}
	for lm in m.landmarks:
		by_id[str(lm.id)] = lm
	check(str(by_id.justina.tag) == "reconstruccion" and str(by_id.justina.tag_parts.descripcion) == "documentado" and str(by_id.justina.tag_parts.lugar) == "reconstruccion", "El hito del buque separa la descripción (Documentado) del lugar (Reconstrucción)")
	check(str(m.ship.tag) == "reconstruccion" and str(m.ship.tag_parts.descripcion) == "documentado" and str(m.ship.tag_parts.lugar) == "reconstruccion", "La entidad 'ship' separa la descripción documentada del lugar reconstruido")
	check(str(by_id.alameda.tag) == "diseno" and not bool(by_id.alameda.trees) and by_id.alameda.polyline.size() <= 5, "La Alameda es un tramo corto de camino sin arboleda regular y de Diseño (paquete C: no extender una avenida ribereña a todo Retiro)")
	check(str(by_id.plaza_toros.tag_parts.existencia) == "documentado" and str(by_id.plaza_toros.tag) == "reconstruccion" and str(by_id.plaza_toros.tag_parts.medidas) == "diseno", "La Plaza de Toros: existencia Documentada (plano de 1801); posición Reconstrucción; medidas Diseño")
	# R6: política de rotulado (todo hito lleva tag válido; los de diseño llevan el sufijo en el nombre; sin 'Alameda' como nombre visible)
	var all_tags_ok := true
	var suffix_ok := true
	for lm in m.landmarks:
		all_tags_ok = all_tags_ok and lm.has("tag") and m.source_tags.has(str(lm.tag))
		if str(lm.tag) == "diseno":
			suffix_ok = suffix_ok and str(lm.name).ends_with("(diseño)")
	for e in m.labels_extra:
		all_tags_ok = all_tags_ok and e.has("tag") and m.source_tags.has(str(e.tag))
	for g in m.groups:
		all_tags_ok = all_tags_ok and g.has("tag") and m.source_tags.has(str(g.tag))
	check(all_tags_ok and str(m.label_policy.default_tag) == "diseno", "Todo hito, rótulo extra y grupo lleva una etiqueta de fuente válida; el valor por defecto es 'diseno'")
	check(suffix_ok and not ("Alameda" in str(by_id.alameda.name)), "Los hitos de diseño llevan '(diseño)' en el nombre y el camino de la barranca no se llama 'Alameda'")
	# Ronda 7: coherencia de etiquetas y de textos visibles
	var zv := {}
	for g7 in m.groups:
		if str(g7.id) == "zavala":
			zv = g7
	check(str(zv.tag) == str(m.forces.groups.zavala.tag) and str(zv.tag) == "tradicion", "La Reserva de Pueyrredón lleva la misma etiqueta (tradición) en groups y en forces")
	check(not ("Abascal" in str(m.actions.distract_fire.effect)) and not ("batería" in str(m.actions.distract_fire.effect).to_lower()), "El texto visible de 'Distraer con fuego' no nombra la batería Abascal")
	var ok_ms := true
	for it7 in m.milestones.items:
		if str(it7.tag) == "documentado":
			ok_ms = ok_ms and str(it7.get("verification", "")) in ["", "lectura_ocr_gillespie", "segunda_mano"]
		else:
			ok_ms = ok_ms and true
	check(ok_ms and str(m.milestones.items[1].get("verification", "")) == "lectura_gillespie" and str(m.milestones.items[1].tag) != "documentado", "La cronología reserva 'documentado' a lo verificado; 10-ago es lectura de Gillespie")
	var ring_ok: bool = m.ship.fire.cover_zone.has("rings") and m.ship.fire.cover_zone.rings.size() == 2 and bool(m.landmarks[0].has("name"))
	check(ring_ok and str(by_id.justina.name).find("hipotética") >= 0 and m.has("ui_policy") and m.camera.has("initial_framing"), "Buque rotulado como ubicación hipotética, dos anillos rotulados, política de glifos y encuadre inicial")
	var grp := {}
	for g in m.groups:
		grp[str(g.id)] = g
	check(str(grp.zavala.tag) == "tradicion", "La reserva de caballería de Pueyrredón se rotula con la afirmación más débil (tradición)")
	check("diseño" in str(m.tide.hud_label).to_lower() and str(m.gillespie_context_p93.quote_short).find("Herrick") >= 0, "El nivel del río del HUD se rotula 'nivel de juego (diseño)' y consta la goleta de Herrick (Gillespie p. 93)")
	var hf := FileAccess.open("res://data/history.json", FileAccess.READ)
	var htxt := hf.get_as_text() if hf != null else ""
	check(htxt.find("Herrick") >= 0 and htxt.find("Ronda ") < 0 and htxt.find("DISENO_JUSTINA") < 0, "history.json: consta Herrick y no filtra notas de producción (rondas, rutas de docs) al jugador")
	var meaning := str(m.source_tags.documentado.meaning).to_lower()
	check("transcripción" in meaning and "divulgativas no bastan" in meaning and "manuscrito" in meaning, "La definición de 'Documentado' que ve el jugador es la del proyecto (transcripción; las divulgativas no bastan)")
	var note := str(m.time.note).to_lower()
	check("siete u ocho pies" in note and "left dry" in note and "sí liga la bajada al viento" in note and not ("no atribuye la causa al viento" in note), "La nota del tiempo cita a Gillespie (pp. 35-36): sí liga la bajada al viento y habla de buque 'left dry'; el banco parcialmente inundado es diseño")
	var camp := str(by_id.campamento_pueyrredon.source).to_lower() + " " + str(m.groups[2].note).to_lower()
	check("sin cotejo" in camp and "gillespie" in camp, "La caballería de Pueyrredón figura como relato posterior sin cotejo (no se cita a Concha ni a Liniers como verificados)")
	check("s1-s8" in str(by_id.justina.source).to_lower(), "El hito deja constancia de que las fuentes divulgativas no están en la bibliografía S1-S8")
	# tope de guardado en BYTES con texto acentuado, y recorte de ordenes y sondas
	var path := "user://test-rules-trim.json"
	var big := _busy_game()
	for i in range(45000):
		big.state.orders.append({"time": 100.0, "round": 1, "unit": "guemes", "action": "move", "target": {"x": 250.5 + float(i % 7), "z": 260.123456789}})
	var rc: int = big.save_game(path)
	var f := FileAccess.open(path, FileAccess.READ)
	var bytes: int = f.get_length() if f != null else -1
	if f != null:
		f.close()
	check(rc == OK and bytes > 0 and bytes < Rules.SAVE_MAX_BYTES, "Con 45 000 órdenes el guardado recorta las órdenes y cabe bajo el tope (%d bytes)" % bytes)
	check(big.state.orders.size() >= 45000, "La partida en curso conserva todas sus órdenes (solo se recorta la copia guardada)")
	var back := Rules.new()
	var lr: Dictionary = back.load_game(path)
	check(lr.ok and back.state.orders.size() <= Rules.SAVE_ORDERS_FALLBACK + 1 and absf(float(back.state.orders[0].time) - float(back.state.first_order_at)) < 0.001, "El guardado recortado se recarga y conserva la primera orden (%s)" % str(lr.get("reason", "")))
	var acc := _busy_game()
	for i in range(400):
		acc.state.log.append({"time": 0.0, "round": 1, "text": "ñandú ".repeat(1100), "kind": "info"})
	acc.state.log = (acc.state.log as Array).slice(acc.state.log.size() - 400)
	var chars: int = JSON.stringify(acc.state, "", true, true).length()
	var utf8_bytes: int = JSON.stringify(acc.state, "", true, true).to_utf8_buffer().size()
	rc = acc.save_game(path)
	f = FileAccess.open(path, FileAccess.READ)
	var saved: int = f.get_length() if f != null else -1
	if f != null:
		f.close()
	check(chars < Rules.SAVE_MAX_BYTES and utf8_bytes > Rules.SAVE_MAX_BYTES, "Prueba válida: %d caracteres pero %d bytes (el tope se mide en bytes)" % [chars, utf8_bytes])
	check(rc == OK and saved < Rules.SAVE_MAX_BYTES and Rules.new().load_game(path).ok, "Un guardado con acentos que pasa el tope en bytes se aligera y se recarga (%d bytes)" % saved)
	# sondas: la copia de emergencia las adelgaza sin perder los extremos
	var pr := _busy_game()
	for i in range(400):
		var pts: Array = []
		for k in range(200):
			pts.append({"x": 210.0 + float(k) * 1.123456789, "z": 100.0 + float(i) * 0.5})
		pr.state.probes.append({"id": "q%d" % i, "kind": "lane", "pts": pts, "width": 6.0, "t": 10.0, "scout": "scout_1"})
	while pr.state.probes.size() > Rules.MAX_PROBES:
		pr.state.probes.pop_back()
	for i in range(3 * Rules.LOG_MAX):
		pr._event("Relleno %d %s" % [i, "ñ".repeat(900)], "info")
	rc = pr.save_game(path)
	f = FileAccess.open(path, FileAccess.READ)
	var psz: int = f.get_length() if f != null else -1
	if f != null:
		f.close()
	check(rc == OK and psz < Rules.SAVE_MAX_BYTES, "El peor caso con sondas al tope y registro lleno se guarda bajo el tope en bytes (%d)" % psz)
	var pb := Rules.new()
	check(pb.load_game(path).ok and pb.state.probes.size() >= 1, "...y se recarga")

# ---------------------------------------------------------------------------
# 6. Estrategias scripteadas (simulacion completa, varias semillas)

class Sim:
	var r: RefCounted
	var mem: Dictionary = {}
	var t := 0.0
	var cfg: Dictionary = {}
	var rng: RandomNumberGenerator = null  ## solo los perfiles «humanos» de la ronda 9 lo usan

const GROUP_IDS := ["guemes", "arias", "zavala"]
const SEEDS := [3, 5, 7, 11, 13, 17, 19, 23]
## Carriles de reconocimiento (docs/DISENO_JUSTINA.md 1.2 y 10): el eje del banco central y un carril por cada flanco.
const PROBE_CENTER := [Vector2(250, 264), Vector2(334, 264)]
const PROBE_FLANK_N := [Vector2(250, 240), Vector2(362, 240)]
const PROBE_FLANK_S := [Vector2(250, 288), Vector2(362, 288)]
const LANE_N_WP := [Vector2(300, 240), Vector2(375, 240)]
const LANE_S_WP := [Vector2(300, 288), Vector2(375, 288)]
const PROBE_SOUTH_VADO := [Vector2(205, 400), Vector2(268, 402)]
const PROBE_SOUTH_BANK := [Vector2(268, 402), Vector2(342, 406), Vector2(392, 435)]
const MARK_SOUTH := [Vector2(230, 401), Vector2(255, 402)]
const NORTH_EDGE := [Vector2(330, 222), Vector2(480, 222)]
const STAGE_CENTRAL := Vector2(255, 264)
const STAGE_SOUTH := Vector2(255, 402)
const STAGE_SOUTH_EXIT := Vector2(318, 405)
const SOUTH_BOARD_WP := [Vector2(450, 455), Vector2(520, 440), Vector2(565, 390)]
const STRATEGY_NAMES := ["rush_central", "rush_gallop", "blind_north_edge", "central_center_lane", "central_flank_lane", "central_flank_pair", "central_hasty", "central_bare", "central_flank_stagger", "central_flank_noreply", "south_full", "south_vado_only", "south_bare", "south_wrong_crossing", "south_noreply", "mixed_split", "late_all_in", "passive"]

func _central_common() -> Dictionary:
	return {"signal_t": 100.0, "resupply": true, "muster": 1, "stage": STAGE_CENTRAL, "stage_t": 120.0, "board_t": 170.0, "wait_probes": true, "wait_max": 120.0, "signal_on_go": true, "cover": true, "fire": true, "repel": true, "evac": true}

func _south_common() -> Dictionary:
	return {"signal_t": 200.0, "resupply": true, "muster": 1, "stage": STAGE_SOUTH, "stage_t": 200.0, "stage2": STAGE_SOUTH_EXIT, "stage2_t": 270.0, "stage2_wp": [Vector2(300, 403)], "board_t": 270.0, "wp": SOUTH_BOARD_WP, "wait_probes": true, "wait_max": 170.0, "signal_on_go": true, "fire": true, "cover": true, "repel": true, "evac": true,
		"mark_t": 170.0, "probes": [{"who": "scout_1", "t": 150.0, "pts": PROBE_SOUTH_VADO, "careful": false}]}

func _with(base: Dictionary, extra: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for k in extra:
		out[k] = extra[k]
	return out

func _strategy_cfg(name: String) -> Dictionary:
	var south_bank := {"who": "scout_1", "t": 200.0, "pts": PROBE_SOUTH_BANK, "careful": true, "after_found": "vado_sur"}
	match name:
		"rush_central":
			return {"signal_t": 0.0, "board_t": 0.0}
		"rush_gallop":
			return {"signal_t": 0.0, "board_t": 0.0, "pace": "gallop"}
		"blind_north_edge":
			return {"signal_t": 100.0, "resupply": true, "muster": 1, "stage": Vector2(255, 226), "stage_t": 110.0, "board_t": 180.0, "wp": NORTH_EDGE, "fire": true, "repel": true}
		"central_center_lane":
			return _with(_central_common(), {"probes": [{"who": "scout_1", "t": 90.0, "pts": PROBE_CENTER, "careful": true}]})
		"central_flank_lane":
			return _with(_central_common(), {"flank": true, "probes": [{"who": "scout_1", "t": 90.0, "pts": PROBE_FLANK_N, "careful": true}]})
		"central_flank_pair":
			return _with(_central_common(), {"flank": true, "probes": [{"who": "scout_1", "t": 90.0, "pts": PROBE_FLANK_N, "careful": true}, {"who": "scout_2", "t": 90.0, "pts": PROBE_FLANK_S, "careful": true}]})
		"central_hasty":
			return _with(_central_common(), {"flank": true, "cover": false, "probes": [{"who": "scout_1", "t": 90.0, "pts": PROBE_FLANK_N, "careful": false}], "wait_max": 60.0})
		"central_bare":
			return {"signal_on_go": true, "stage": STAGE_CENTRAL, "stage_t": 120.0, "board_t": 170.0, "flank": true, "wait_probes": true, "wait_max": 120.0, "probes": [{"who": "scout_1", "t": 90.0, "pts": PROBE_FLANK_N, "careful": true}]}
		"central_flank_stagger":
			return _with(_central_common(), {"flank": true, "stagger": 45.0, "probes": [{"who": "scout_1", "t": 90.0, "pts": PROBE_FLANK_N, "careful": true}]})
		"central_flank_noreply":
			return _with(_central_common(), {"flank": true, "repel": false, "evac": false, "probes": [{"who": "scout_1", "t": 90.0, "pts": PROBE_FLANK_N, "careful": true}]})
		"south_full":
			var c := _south_common()
			c.probes = [c.probes[0], south_bank]
			return c
		"south_vado_only":
			return _south_common()
		"south_bare":
			return {"signal_t": 200.0, "signal_on_go": true, "stage": STAGE_SOUTH, "stage_t": 130.0, "stage2": STAGE_SOUTH_EXIT, "stage2_t": 230.0, "stage2_wp": [Vector2(300, 403)], "board_t": 270.0, "wp": SOUTH_BOARD_WP, "wait_probes": true, "wait_max": 170.0, "mark_t": 170.0, "probes": [{"who": "scout_1", "t": 150.0, "pts": PROBE_SOUTH_VADO, "careful": false}]}
		"south_wrong_crossing":
			return {"signal_t": 90.0, "resupply": true, "muster": 1, "stage": Vector2(255, 360), "stage_t": 130.0, "board_t": 190.0, "wp": [Vector2(300, 360), Vector2(450, 455), Vector2(520, 440), Vector2(565, 390)], "fire": true, "repel": true}
		"south_noreply":
			var c2 := _south_common()
			c2.probes = [c2.probes[0], south_bank]
			c2.repel = false
			c2.evac = false
			return c2
		"mixed_split":
			var c3 := _south_common()
			c3.probes = [c3.probes[0], south_bank, {"who": "scout_2", "t": 90.0, "pts": PROBE_FLANK_N, "careful": true}]
			c3.split = true
			c3.cover = true
			return c3
		"late_all_in":
			return {"signal_t": 200.0, "resupply": true, "muster": 1, "board_t": 1000.0, "fire": true}
		"passive":
			return {}
	return {}

## Carril de los flancos del banco central segun lo que se descubrio: si el hoyo norte apareció, el sur es el firme (hay exactamente uno).
func _flank_wps(st: Dictionary, c: Dictionary = {}) -> Array:
	if c.has("flank_known"):  ## el diario ya anotó cuál flanco tiene el hoyo
		return LANE_S_WP if str(c.flank_known) == "pozo_flanco_norte" else LANE_N_WP
	return LANE_S_WP if "pozo_flanco_norte" in st.hazards_found else LANE_N_WP

func _probes_done(s: Sim) -> bool:
	var jobs: Array = s.cfg.get("probes", [])
	for ji in range(jobs.size()):
		if not s.mem.has("job_%d" % ji):
			return false
		var sc: Dictionary = s.r.get_scout(str(jobs[ji].who))
		if sc.stage in ["probing", "marking"]:
			return false
	return true

func _policy_cfg(s: Sim) -> void:
	var c: Dictionary = s.cfg
	var r: RefCounted = s.r
	var st: Dictionary = r.state
	var gu: Dictionary = r.get_unit("guemes")
	# reconocimiento: trabajos de sondeo (cada explorador toma el siguiente cuando queda libre)
	var jobs: Array = c.get("probes", [])
	for ji in range(jobs.size()):
		var job: Dictionary = jobs[ji]
		var key := "job_%d" % ji
		if s.mem.has(key) or s.t < float(job.t):
			continue
		var sc: Dictionary = r.get_scout(str(job.who))
		if sc.stage == "lost":
			s.mem[key] = -1.0
		elif sc.stage == "idle":
			if job.has("after_found") and not (str(job.after_found) in st.fords_found):
				continue
			var o: Dictionary = r.issue_scout(str(job.who), "probe", job.pts, {"cautious": bool(job.get("careful", false))})
			if o.ok:
				s.mem[key] = s.t
	## un explorador libre y al alcance del buque se repliega a la playa (no se queda esperando bajo el fuego)
	for sc3 in st.scouts:
		if sc3.stage == "idle" and r.exposure_at(float(sc3.x), float(sc3.z)) > 0.0:
			var pending := false
			for ji2 in range(jobs.size()):
				if str(jobs[ji2].who) == str(sc3.id) and not s.mem.has("job_%d" % ji2):
					pending = true
			if not pending:
				r.issue_scout(str(sc3.id), "recall", [])
	if c.has("mark_t") and s.t >= float(c.mark_t) and not s.mem.has("mark_south") and "vado_sur" in st.fords_found and r.get_scout("scout_2").stage == "idle":
		s.mem.mark_south = r.issue_scout("scout_2", "mark_ford", MARK_SOUTH).ok
	## Un jugador que lee la variante de misión cuida la pólvora: no gasta fuego de distracción por debajo del piso que reserva para rechazar contraataques.
	var ammo_floor: int = int(c.get("ammo_floor", 6))
	if c.get("cover", false) and int(st.ammo) >= 8 + ammo_floor:
		for sc2 in st.scouts:
			if sc2.stage == "probing" and r.exposure_at(float(sc2.x), float(sc2.z)) > 0.0:
				if r.call_fire_support().ok:
					s.mem.fire_uses = int(s.mem.get("fire_uses", 0)) + 1
	# condicion de salida
	var ready_go: bool = s.t >= float(c.get("board_t", 1.0e9))
	if ready_go and c.get("wait_probes", false):
		ready_go = _probes_done(s) or s.t >= float(c.board_t) + float(c.get("wait_max", 200.0))
	# Liniers: se señala una vez; se repite si venció y todavía no se cargó.
	var want_signal: bool = false
	var sig_n := int(s.mem.get("sig_n", 0))
	if c.has("signal_t"):
		want_signal = s.t >= float(c.signal_t) and (sig_n == 0 or not c.get("signal_on_go", false))
	if c.get("signal_on_go", false) and ready_go and (sig_n == 0 or s.t > float(c.get("board_t", 0.0))):
		want_signal = true
	if want_signal and gu.stage == "ready" and not bool(st.advance_authorized) and (not s.mem.has("board_guemes") or sig_n < 2) and int(st.signals_left) > 0 and (sig_n == 0 or s.t > float(c.get("board_t", 0.0))):
		if not s.mem.has("signal_wait") or s.t >= float(s.mem.signal_wait):
			if r.issue_order("guemes", "signal_liniers").ok:
				s.mem.signal_wait = s.t + 20.0
				s.mem.sig_n = sig_n + 1
	var zv: Dictionary = r.get_unit("zavala")
	if c.get("resupply", false) and s.t >= float(c.get("resupply_t", 150.0)) and zv.stage == "ready" and int(s.mem.get("muster_zavala", 0)) >= int(c.get("muster", 0)) and not s.mem.has("resupply") and int(st.ammo) < 30 and int(st.ammo_reserve) > 0 and not s.mem.has("boarded_any"):
		if r.issue_order("zavala", "resupply").ok:
			s.mem.resupply = true
	# reunir jinetes
	var rounds := int(c.get("muster", 0))
	if rounds > 0:
		for id in ["arias", "zavala"]:
			var u: Dictionary = r.get_unit(id)
			var k: String = "muster_" + id
			if u.stage == "ready" and int(s.mem.get(k, 0)) < rounds and float(u.strength) < 99.0 and float(st.volunteers_pool) > 0.0 and int(st.ammo) >= 4 and not s.mem.has("boarded_any"):
				if r.issue_order(id, "muster").ok:
					s.mem[k] = int(s.mem.get(k, 0)) + 1
	# puesta en posicion
	if c.has("stage") and s.t >= float(c.stage_t) and not s.mem.has("boarded_any"):
		var i := 0
		for id in GROUP_IDS:
			var key2: String = "stage_" + id
			var ug: Dictionary = r.get_unit(id)
			var p: Vector2 = c.stage
			if c.get("split", false) and id == "guemes":
				p = Vector2(255, 250)
			if not s.mem.has(key2) and ug.stage == "ready":
				if r.issue_order(id, "move", p + Vector2(0, (i - 1) * 8.0), {"pace": "trot"}).ok:
					s.mem[key2] = true
			i += 1
	# segunda posicion (cruzar el vado ya descubierto hasta su salida mientras se sondea el banco)
	if c.has("stage2") and s.t >= float(c.stage2_t) and not s.mem.has("boarded_any") and "vado_sur" in st.fords_found:
		var j := 0
		for id in GROUP_IDS:
			var key4: String = "stage2_" + id
			var ug2: Dictionary = r.get_unit(id)
			if c.get("split", false) and id == "guemes":
				j += 1
				continue
			if not s.mem.has(key4) and ug2.stage == "ready":
				if r.issue_order(id, "move", (c.stage2 as Vector2) + Vector2(0, (j - 1) * 6.0), {"pace": "trot", "waypoints": c.get("stage2_wp", [])}).ok:
					s.mem[key4] = true
			j += 1
	# abordaje
	var go: bool = ready_go and bool(st.advance_authorized)
	if go:
		if not s.mem.has("go_t"):
			s.mem.go_t = s.t
		var i2 := 0
		for id in (["arias", "zavala", "guemes"] if c.has("stagger") else GROUP_IDS):
			var u2: Dictionary = r.get_unit(id)
			var key3: String = "board_" + id
			var ready_t := float(s.mem.go_t) + float(c.get("stagger", 0.0)) * float(i2)
			i2 += 1
			if s.mem.has(key3) and u2.stage == "ready" and float(u2.strength) > 5.0 and s.t > float(s.mem[key3]) + 5.0 and u2.mounted:
				s.mem.erase(key3)  ## la orden venció y el grupo se detuvo: se vuelve a dar con la nueva señal
			if s.mem.has(key3) or u2.stage != "ready" or s.t < ready_t:
				continue
			var wps: Array = []
			if c.has("wp"):
				wps = c.wp
			elif c.get("flank", false):
				wps = _flank_wps(st, c)
			if c.get("split", false):
				wps = _flank_wps(st, c) if id == "guemes" else SOUTH_BOARD_WP
				if id != "guemes" and not ("vado_sur" in st.fords_found):
					continue
			var o2: Dictionary = r.issue_order(id, "board", Vector2.ZERO, {"pace": str(c.get("pace", "trot")), "waypoints": wps})
			if o2.ok:
				s.mem[key3] = s.t
				s.mem.boarded_any = true
	# fuego
	if c.get("fire", false):
		var exposed := false
		for u3 in st.units:
			if r.exposure_at(float(u3.x), float(u3.z)) > 0.0 and u3.stage in ["moving", "dismounting", "boarding"]:
				exposed = true
		if exposed and int(st.ammo) >= 8 + ammo_floor and r.call_fire_support().ok:
			s.mem.fire_uses = int(s.mem.get("fire_uses", 0)) + 1
	# cubierta: rechazar el contraataque y evacuar heridos
	var repel_roll := true
	if bool(st.counter.active) and s.rng != null:
		var rk := "rp_%d" % int(st.counter.count)
		if not s.mem.has(rk):
			s.mem[rk] = s.rng.randf() < float(c.get("repel_p", 1.0))  ## un humano distraído deja pasar el aviso
		repel_roll = bool(s.mem[rk])
	if c.get("repel", false) and repel_roll and bool(st.counter.active) and not bool(st.counter.answered):
		var best: Dictionary = {}
		for u4 in st.units:
			if u4.stage == "boarding" and (best.is_empty() or float(u4.strength) > float(best.strength)):
				best = u4
		if not best.is_empty() and r.issue_order(str(best.id), "repel").ok:
			s.mem.repels = int(s.mem.get("repels", 0)) + 1
	if float(st.last_effort.until) >= 0.0 and not bool(st.last_effort.used) and not s.mem.has("le_roll"):
		s.mem.le_roll = s.rng == null or s.rng.randf() < float(c.get("last_effort_p", 1.0))
		if bool(s.mem.le_roll) and r.last_effort().ok:
			s.mem.last_effort = true
	if c.get("evac", false):
		var boarding_n := 0
		for u5 in st.units:
			if u5.stage == "boarding":
				boarding_n += 1
		for u5 in st.units:
			if u5.stage == "boarding" and boarding_n >= 2 and float(u5.wounded) >= 8.0 and float(u5.evac_remaining) <= 0.0 and not bool(st.counter.active):
				if r.issue_order(str(u5.id), "evacuate").ok:
					s.mem.evacs = int(s.mem.get("evacs", 0)) + 1
					break

func _run_strategy(policy: String, seed_value: int = 7) -> Dictionary:
	return _run_cfg(_strategy_cfg(policy), policy, seed_value, {})

## Corre una configuración de política completa. opts: rng (perfiles humanos), assists (ayudas elegidas), dodge_p (probabilidad de esquivar una descarga avisada).
func _run_cfg(cfg: Dictionary, policy: String, seed_value: int, opts: Dictionary) -> Dictionary:
	var s := Sim.new()
	s.r = _new_j(seed_value, true)
	s.cfg = cfg
	s.rng = opts.get("rng", null)
	for a in opts.get("assists", []):
		s.r.apply_assist(str(a))
	var dodge_p := float(opts.get("dodge_p", 0.0))
	var dodge_seen := -1.0
	var guard := 0
	var stranded := 0
	var prev_zero := {}
	var trace: bool = ("--trace=" + policy) in OS.get_cmdline_user_args()
	while s.r.state.status == "playing" and guard < 6000:
		_policy_cfg(s)
		if trace and guard % 120 == 0:
			var line := ""
			for u in s.r.state.units:
				line += " %s[%s %.0f,%.0f s=%.0f f=%.0f w=%.0f]" % [u.id, u.stage, u.x, u.z, u.strength, u.fatigue, u.wounded]
			for sc in s.r.state.scouts:
				line += " %s[%s %.0f,%.0f hp%d]" % [sc.id, sc.stage, sc.x, sc.z, sc.hp]
			print("  t=%d cap=%.1f ammo=%d lvl=%.2f morale=%.0f sig=%d auth=%s%s" % [int(s.r.state.elapsed), s.r.state.capture, s.r.state.ammo, s.r.water_level_m(), s.r.state.crew_morale, int(s.r.state.signals_left), str(s.r.state.advance_authorized), line])
		for k in range(4):
			s.r.tick(0.25)
			guard += 1
			var ps: Dictionary = s.r.state.pending_shot
			if dodge_p > 0.0 and s.rng != null and not ps.is_empty() and float(ps.at) != dodge_seen:
				## Reacción humana al aviso: con probabilidad dodge_p la descarga cae lejos (la andanada fuerte se esquiva mejor); cuesta un poco de fatiga al grupo apuntado.
				dodge_seen = float(ps.at)
				if s.rng.randf() < dodge_p * (1.0 if bool(ps.strong) else 0.4):
					ps.ax = float(ps.ax) + 80.0
					var tu: Dictionary = s.r.get_unit(str(ps.tid))
					if not tu.is_empty():
						tu.fatigue = minf(100.0, float(tu.fatigue) + 2.0)
			for u in s.r.state.units:
				if u.stage in ["boarding", "dismounting", "routed"]:
					continue
				var zero: bool = s.r.speed_at(float(u.x), float(u.z), "walk", u.mounted) <= 0.0
				if zero and prev_zero.get(u.id, false):
					stranded += 1
				prev_zero[u.id] = zero
		s.t = float(s.r.state.elapsed)
	var rep: Dictionary = s.r.campaign_report()
	if "--events" in OS.get_cmdline_user_args():
		for ev in s.r.state.log:
			if str(ev.kind) in ["warning", "stumble", "recon", "boarding", "counter", "signal", "last_effort"]:
				print("      [%d] %s: %s" % [int(ev.time), ev.kind, str(ev.text).substr(0, 110)])
	return {"policy": policy, "seed": seed_value, "status": s.r.state.status, "t": float(s.r.state.elapsed), "loss_pct": float(rep.loss_total_pct), "stumbles": int(s.r.state.stats.stumbles),
		"exposure": s.r.state.stats.exposure_s.duplicate(true), "route": rep.route, "ammo_used": int(s.r.state.stats.ammo_used), "probe_m": float(s.r.state.stats.probe_m),
		"stranded": stranded, "report": rep, "fire_uses": int(s.mem.get("fire_uses", 0)), "capture": float(s.r.state.capture), "boarded_at": float(s.r.state.stats.boarded_at),
		"scouts_lost": int(s.r.state.stats.scouts_lost), "horses_lost": float(s.r.state.stats.horses_lost), "melee_loss": float(s.r.state.stats.melee_loss), "drowned": float(s.r.state.stats.drowned),
		"counter_hits": int(rep.counter_hits), "counter_repelled": int(rep.counter_repelled), "evacuations": int(rep.evacuations), "halted": int(rep.halted_by_expiry), "picks": rep.hidden_picks,
		"rules": s.r, "found": s.r.state.hazards_found.duplicate(), "cause": str(s.r.state.get("defeat_cause", "")), "medal": str(rep.medal)}

## Matriz estrategias x semillas (--matrix): imprime una linea por estrategia y sale. Sirve para calibrar.
func _print_matrix() -> void:
	var seeds: Array = SEEDS.duplicate()
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
		if a.begins_with("--seed="):
			seeds = [int(a.substr(7))]
		if a.begins_with("--seeds="):
			seeds = []
			for tok in a.substr(8).split(","):
				seeds.append(int(tok))
	if "--picks" in OS.get_cmdline_user_args():
		for sd in seeds:
			var rr := _new_j(int(sd))
			print("seed %d -> %s" % [sd, str(rr.state.hidden.picks)])
		quit(0)
		return
	for p in STRATEGY_NAMES:
		if only != "" and not (p in only.split(",")):
			continue
		var wins := 0
		var line := ""
		var tsum := 0.0
		var lsum := 0.0
		var esum := 0.0
		var routes := {}
		var ba := 0.0
		var hl := 0.0
		var ml := 0.0
		var dg := 0.0
		var sl := 0
		var wl := 0.0
		var we := 0.0
		var st_sum := 0
		var ch := 0
		var cr := 0
		var bym := {}
		for sd in seeds:
			var res := _run_strategy(p, sd)
			var mk := str(res.report.mission_id)
			if not bym.has(mk):
				bym[mk] = [0, 0]
			bym[mk][1] += 1
			if res.status == "victory":
				bym[mk][0] += 1
			if res.status == "victory":
				wins += 1
				tsum += res.t
				wl += res.loss_pct
				we += float(res.exposure.central) + float(res.exposure.sur)
			lsum += res.loss_pct
			esum += float(res.exposure.central) + float(res.exposure.sur)
			routes[res.route] = true
			ba += float(res.boarded_at)
			hl += float(res.horses_lost)
			ml += float(res.melee_loss)
			dg += float(res.report.damage_taken)
			sl += int(res.scouts_lost)
			st_sum += int(res.stumbles)
			ch += int(res.counter_hits)
			cr += int(res.counter_repelled)
			line += " %s%d" % ["V" if res.status == "victory" else "d", int(res.t)]
			if "--notes" in OS.get_cmdline_user_args():
				print("   ", p, sd, res.status, int(res.t), str(res.report.route_notes), str(res.report.hidden_picks), "mission", str(res.report.mission_id))
			if "--expo" in OS.get_cmdline_user_args():
				print("   ", p, sd, JSON.stringify(res.exposure), "boarded", int(res.boarded_at), "t", int(res.t), "dmg", int(res.report.damage_taken))
		if "--bymission" in OS.get_cmdline_user_args():
			print("   por variante:", str(bym))
		print("%-22s WIN: loss %3.0f%% expo %3.0f | wins %d/%d t_avg %4.0f loss %3.0f%% expo %4.0f board %4.0f horses %3.0f melee %3.0f fire %3.0f scoutsL %d stumbles %d cnt %d/%d %s |%s" % [p, wl / maxf(1.0, wins), we / maxf(1.0, wins), wins, seeds.size(), tsum / maxf(1.0, wins), lsum / seeds.size(), esum / seeds.size(), ba / seeds.size(), hl / seeds.size(), ml / seeds.size(), dg / seeds.size(), sl, st_sum, cr, ch + cr, str(routes.keys()), line])
	quit(0)

func _test_strategies() -> void:
	var seeds: Array = SEEDS.duplicate()
	var all: Dictionary = {}
	var wins_by: Dictionary = {}
	var total_wins := 0
	for p in STRATEGY_NAMES:
		all[p] = []
		wins_by[p] = 0
		for sd in seeds:
			var res := _run_strategy(p, sd)
			all[p].append(res)
			if res.status == "victory":
				wins_by[p] = int(wins_by[p]) + 1
				total_wins += 1
			var slim: Dictionary = res.duplicate()
			slim.erase("report")
			report.results.append({"scenario": "justine", "strategy": p, "seed": sd, "result": slim})
	var dom: Dictionary = Rules.new().map_data().play_targets.dominance
	var s_cnt: int = STRATEGY_NAMES.size()
	check(s_cnt >= int(dom.strategies_min) and seeds.size() >= int(dom.seeds_min), "Se simulan al menos %d estrategias x %d semillas (%d x %d)" % [int(dom.strategies_min), int(dom.seeds_min), s_cnt, seeds.size()])
	# ninguna estrategia concentra mas del 60 % de las victorias de la matriz y varios estilos ganan de forma sostenida
	var winners := 0
	var max_share := 0.0
	for p in STRATEGY_NAMES:
		if int(wins_by[p]) * 2 >= seeds.size():
			winners += 1
		if total_wins > 0:
			max_share = maxf(max_share, float(wins_by[p]) / float(total_wins))
	check(total_wins > 0 and max_share <= float(dom.max_win_share) + 0.0001, "Ninguna estrategia concentra más del %d %% de las victorias de la matriz (máx. %.0f %%)" % [int(float(dom.max_win_share) * 100.0), max_share * 100.0])
	var fam_central := 0
	var fam_south := 0
	for p in ["central_center_lane", "central_flank_lane", "central_flank_pair", "central_hasty", "central_bare", "central_flank_stagger", "central_flank_noreply"]:
		fam_central += int(wins_by[p])
	for p in ["south_full", "south_vado_only", "south_bare", "south_noreply"]:
		fam_south += int(wins_by[p])
	check(float(fam_central) / float(7 * seeds.size()) <= 0.75 and float(fam_south) / float(4 * seeds.size()) <= 0.75, "Ninguna familia de estrategias (centro con sus variantes, sur con sus variantes) gana más del 75 %% de sus partidas (centro %d/%d, sur %d/%d)" % [fam_central, 7 * seeds.size(), fam_south, 4 * seeds.size()])
	check(winners >= int(dom.min_winning_strategies), "Al menos %d estrategias distintas ganan en la mitad o más de las semillas (%d)" % [int(dom.min_winning_strategies), winners])
	var routes_won := {}
	for p in STRATEGY_NAMES:
		for res in all[p]:
			if res.status == "victory":
				routes_won[res.route] = int(routes_won.get(res.route, 0)) + 1
	check(routes_won.has("central") and routes_won.has("sur"), "Hay victorias por la ruta central y por la sur (%s)" % str(routes_won))
	var central_wins := int(routes_won.get("central", 0))
	var south_wins := int(routes_won.get("sur", 0)) + int(routes_won.get("mixta", 0))
	## Ronda 9 (C9): el reparto de victorias entre rutas depende de cuántos guiones hay por ruta; lo que importa es que la MEJOR línea de cada ruta rinda parecido (se mide en la calidad de victorias, con 20 semillas).
	check(central_wins > 0 and south_wins > 0, "Hay victorias por ambas rutas (central %d, sur/mixta %d de %d)" % [central_wins, south_wins, total_wins])
	# duraciones
	var tmin := 1e9
	var tmax := 0.0
	for p in STRATEGY_NAMES:
		for res in all[p]:
			if res.status == "victory":
				tmin = minf(tmin, res.t)
				tmax = maxf(tmax, res.t)
	check(total_wins > 0 and tmin >= 7.5 * 60.0 and tmax <= 14.0 * 60.0 + 0.001, "Ronda 9: las victorias duran entre ~7,5 y 14 min (%.1f a %.1f min)" % [tmin / 60.0, tmax / 60.0])
	var vts: Array = []
	for p in STRATEGY_NAMES:
		for res in all[p]:
			if res.status == "victory":
				vts.append(float(res.t))
	vts.sort()
	check(vts.size() > 0 and float(vts[vts.size() / 2]) >= 9.0 * 60.0 and float(vts[vts.size() / 2]) <= 12.0 * 60.0, "Ronda 9 (plan de diversión): la victoria típica (mediana) dura entre 9 y 12 min (%.1f min)" % [float(vts[vts.size() / 2]) / 60.0])
	# reconocer pesa: a ciegas se pierde (y por mecanismos deterministas); reconociendo mejora la tasa de exito
	var blind_names := ["rush_central", "rush_gallop", "blind_north_edge", "south_wrong_crossing"]
	var blind_wins := 0
	var blind_runs := 0
	var blind_stumbles := 0
	var blind_loss := 0.0
	for p in blind_names:
		for res in all[p]:
			blind_runs += 1
			blind_stumbles += int(res.stumbles)
			blind_loss += float(res.loss_pct)
			if res.status == "victory":
				blind_wins += 1
	var recon_names := ["central_flank_lane", "central_flank_pair", "central_flank_stagger", "south_full", "mixed_split"]
	var recon_wins := 0
	var recon_runs := 0
	for p in recon_names:
		for res in all[p]:
			recon_runs += 1
			if res.status == "victory":
				recon_wins += 1
	var blind_rate := float(blind_wins) / float(blind_runs)
	var recon_rate := float(recon_wins) / float(recon_runs)
	check(blind_rate <= 0.1, "A ciegas (sin reconocer el fondo) casi nunca se gana: %d de %d partidas (%.0f %%)" % [blind_wins, blind_runs, blind_rate * 100.0])
	check(recon_rate >= 0.4 and recon_rate >= blind_rate + 0.3, "Reconocer mejora la tasa de éxito: %.0f %% reconociendo frente a %.0f %% a ciegas" % [recon_rate * 100.0, blind_rate * 100.0])
	for p in ["rush_central", "rush_gallop"]:
		var stumbled := 0
		for res in all[p]:
			if int(res.stumbles) > 0:
				stumbled += 1
		check(stumbled >= seeds.size() - 1, "%s: la ruta central a ciegas tropieza en casi todas las semillas (%d/%d)" % [p, stumbled, seeds.size()])
		var loss := 0.0
		for res in all[p]:
			loss += float(res.loss_pct)
		check(loss / seeds.size() >= float(Rules.new().map_data().play_targets.rush_central_no_recon.min_strength_loss_pct), "%s: bajas medias ≥ %d %% (%.0f %%)" % [p, int(Rules.new().map_data().play_targets.rush_central_no_recon.min_strength_loss_pct), loss / seeds.size()])
	# el flanco oculto: reconocer solo el eje del centro NO basta (la mitad de las semillas cae en el hoyo del flanco)
	var one_stumbles := 0
	var lane_stumbles := 0
	for res in all.central_center_lane:
		one_stumbles += int(res.stumbles)
	for res in all.central_flank_lane:
		lane_stumbles += int(res.stumbles)
	check(one_stumbles > lane_stumbles, "Sondear solo el eje central deja caer en el hoyo del flanco: más tropiezos que sondeando el carril del flanco (%d vs %d)" % [one_stumbles, lane_stumbles])
	var nw: Array = all.blind_north_edge
	var north_stumbles := 0
	for res in nw:
		north_stumbles += int(res.stumbles)
	check(north_stumbles >= 1, "Rodear por el borde norte sin sondear cae en un falso vado (tropiezos: %d)" % north_stumbles)
	var wrong: Array = all.south_wrong_crossing
	var wrong_stumbles := 0
	for res in wrong:
		wrong_stumbles += int(res.stumbles)
	check(wrong_stumbles >= 1, "Cruzar el canal sin conocer el vado sur tropieza (tropiezos: %d)" % wrong_stumbles)
	# el hoyo del banco sur tambien se paga si solo se sondea el vado
	var vado_only_st := 0
	for res in all.south_vado_only:
		vado_only_st += int(res.stumbles)
	var full_st := 0
	for res in all.south_full:
		full_st += int(res.stumbles)
	check(vado_only_st > full_st, "Sondear solo el vado deja caer en el hoyo del banco sur: más tropiezos que sondeando también el banco (%d vs %d)" % [vado_only_st, full_st])
	# decisiones durante la captura: responder a los contraataques y evacuar mejora el resultado
	var rep_loss := 0.0
	var norep_loss := 0.0
	var rep_n := 0
	var norep_n := 0
	var rep_wins := 0
	var norep_wins := 0
	for res in all.central_flank_lane:
		if res.boarded_at >= 0.0:
			rep_loss += float(res.report.counter_loss)
			rep_n += 1
		if res.status == "victory":
			rep_wins += 1
	for res in all.central_flank_noreply:
		if res.boarded_at >= 0.0:
			norep_loss += float(res.report.counter_loss)
			norep_n += 1
		if res.status == "victory":
			norep_wins += 1
	check(rep_n > 0 and norep_n > 0 and rep_loss / rep_n < norep_loss / norep_n and rep_wins >= norep_wins, "Rechazar los contraataques y evacuar heridos paga: menos pérdida por contraataque (%.1f vs %.1f) y no menos victorias (%d vs %d)" % [rep_loss / maxf(1.0, rep_n), norep_loss / maxf(1.0, norep_n), rep_wins, norep_wins])
	var counters_seen := 0
	for p in STRATEGY_NAMES:
		for res in all[p]:
			counters_seen += int(res.counter_hits) + int(res.counter_repelled)
	check(counters_seen >= seeds.size(), "La captura exige decisiones: hubo contraataques de la dotación (%d) en la matriz" % counters_seen)
	# la captura no es espera pasiva: tiempo entre la primera orden de cubierta posible y la rendicion acotado por ventanas de decision
	var longest_quiet := 0.0
	var wins_checked := 0
	for p in ["central_flank_lane", "central_flank_pair", "south_full", "mixed_split"]:
		for res in all[p]:
			if res.status == "victory" and res.boarded_at >= 0.0:
				wins_checked += 1
				longest_quiet = maxf(longest_quiet, (float(res.t) - float(res.boarded_at)) / maxf(1.0, float(res.counter_hits + res.counter_repelled + 1)))
	check(wins_checked > 0 and longest_quiet <= 90.0, "Durante la captura hay una ventana de decisión (contraataque) como mucho cada ≈ 90 s en todas las victorias (espera media máxima %.0f s)" % longest_quiet)
	# pasividad y salida tardia
	var late_w := int(wins_by.late_all_in)
	check(late_w == 0, "Salir tarde pierde: con el río subiendo no se puede abordar (victorias: %d)" % late_w)
	var passive := Rules.new()
	passive.new_game("justine", 7)
	var warns := 0
	for i in range(60):
		passive.tick(15)
		if passive.state.status != "playing":
			break
	for ev in passive.state.log:
		if str(ev.kind) == "liniers" and str(ev.get("field_event", "")).begins_with("sin_retorno"):
			warns += 1
	check(passive.state.status == "defeat" and str(passive.state.defeat_cause) == "inaccion" and _near(passive.state.elapsed, float(passive.map_data().time.no_return_s), 1.0) and passive.state.elapsed <= 11.0 * 60.0 + 1.0, "Pasividad: derrota por inacción en el punto sin retorno (t = %.0f s ≤ 11:00)" % float(passive.state.elapsed))
	check(warns >= 2, "Ninguna derrota por inacción sin al menos 2 avisos de Liniers (%d)" % warns)
	check(passive.campaign_report().outcome_title == "Sin retorno: nadie cargó", "El parte nombra la inacción")
	var timeout := Rules.new()
	timeout.new_game("justine", 7)
	timeout.state.units[0].order = {"action": "board", "x": 548.0, "z": 262.0}  ## «ya avanzó»: el reloj duro sigue valiendo
	for i2 in range(70):
		timeout.tick(15)
		if timeout.state.status != "playing":
			break
	check(timeout.state.status == "defeat" and str(timeout.state.defeat_cause) == "plazo" and _near(timeout.state.elapsed, 840.0, 1.0), "Plazo duro: derrota por plazo a los 14:00 si alguien ya avanzó (t = %.0f)" % float(timeout.state.elapsed))
	check(timeout.campaign_report().outcome_title == "Plazo agotado", "El parte nombra el plazo agotado")
	var casualties := _new_j()
	for u in casualties.state.units:
		u.strength = 0.0
	casualties.tick(1)
	check(casualties.state.status == "defeat" and casualties.campaign_report().outcome_title == "Grupos dispersos", "La dispersión de todos los grupos es derrota")
	# la metrica de bajas nunca es negativa (reunir jinetes no la compensa)
	var neg := 0
	for p in STRATEGY_NAMES:
		for res in all[p]:
			if float(res.loss_pct) < 0.0 or float(res.loss_pct) > 100.0:
				neg += 1
	check(neg == 0, "La métrica de bajas queda entre 0 y 100 en todas las partidas (fuera de rango: %d)" % neg)
	# trade-off real entre rutas: la sur expone menos que la central y tarda mas
	var sf: Array = all.south_full
	var cf: Array = all.central_flank_lane
	var s_cross := 0.0
	var c_cross := 0.0
	var s_exp := 0.0
	var c_exp := 0.0
	var s_t := 0.0
	var c_t := 0.0
	var s_loss := 0.0
	var c_loss := 0.0
	var sn := 0
	var cn := 0
	for res in sf:
		s_cross += float(res.exposure.central) + float(res.exposure.sur)
		s_exp += float(res.exposure.central) + float(res.exposure.sur) + float(res.exposure.otra)
		if res.status == "victory":
			s_t += res.t
			s_loss += float(res.loss_pct)
			sn += 1
	for res in cf:
		c_cross += float(res.exposure.central) + float(res.exposure.sur)
		c_exp += float(res.exposure.central) + float(res.exposure.sur) + float(res.exposure.otra)
		if res.status == "victory":
			c_t += res.t
			c_loss += float(res.loss_pct)
			cn += 1
	check(sn >= 1, "La ruta sur con reconocimiento completo gana alguna partida (%d/%d)" % [sn, seeds.size()])
	check(cn >= 1, "La ruta central con reconocimiento del flanco gana alguna partida (%d/%d)" % [cn, seeds.size()])
	var best_south := 1e9
	for res in sf:
		if res.status == "victory":
			best_south = minf(best_south, float(res.t))
	var south_target := float(Rules.new().map_data().play_targets.recon_then_south.victory_before_s)
	check(sn > 0 and best_south < south_target, "Mejor caso de la ruta sur: victoria antes del objetivo de diseño (%.0f s < %.0f s)" % [best_south, south_target])
	if sn > 0 and cn > 0:
		var ratio_min := float(Rules.new().map_data().play_targets.recon_then_south.central_vs_south_exposure_ratio_min)
		check(c_cross / seeds.size() >= ratio_min * (s_cross / seeds.size()), "Exposición centro/sur en el cruce ≥ %.1f (%.0f vs %.0f s por partida)" % [ratio_min, c_cross / seeds.size(), s_cross / seeds.size()])
		check(c_t / cn < s_t / sn, "El intercambio es real: la central gana antes (%.0f s) y la sur después (%.0f s)" % [c_t / cn, s_t / sn])
		check(s_loss / sn < c_loss / cn, "...y la sur cuesta menos bajas (%.0f %% vs %.0f %%)" % [s_loss / sn, c_loss / cn])
		report.results.append({"scenario": "justine", "strategy": "sur_vs_centro", "sur_victoria_media_s": s_t / sn, "centro_victoria_media_s": c_t / cn, "exposicion_sur": s_exp / seeds.size(), "exposicion_centro": c_exp / seeds.size(), "sur_mejor_s": best_south})
		var tgt_c := float(Rules.new().map_data().play_targets.recon_then_central.victory_before_s)
		check(c_t / cn < tgt_c, "La victoria central media llega antes del objetivo de diseño (%.0f s < %.0f s)" % [c_t / cn, tgt_c])
	# parte de campaña de una victoria
	var rep: Dictionary = {}
	for res in cf:
		if res.status == "victory":
			rep = res.report
			break
	check(not rep.is_empty() and rep.status == "victory" and rep.outcome_title == "Buque capturado" and rep.groups.size() == 3 and rep.history.size() >= 6, "campaign_report: victoria, tres grupos y 'Qué fue historia'")
	var tags: Array = []
	var joined := ""
	for h in rep.get("history", []):
		tags.append(h.tag)
		joined += str(h.text).to_lower() + " "
	check("documentado" in tags and "tradicion" in tags and "diseno" in tags and "reconstruccion" in tags, "La historia fija usa las etiquetas documentado, reconstrucción, tradición y diseño")
	check("26 cañones" in joined and "británico" in joined and "combatió" in joined and "pueyrredón" in joined and "tradición no probada" in joined and "divulgativa" in joined, "La historia menciona el mercante británico de 26 cañones que combatió, Pueyrredón, la tradición de Güemes y la cifra divulgativa")
	check("gillespie no da el lugar" in joined and "edisalta" in joined, "El lugar del varado se atribuye a fuentes divulgativas y no a Gillespie")
	check("concha" in joined and "archivo pueyrredón" in joined, "La caballería de Pueyrredón se atribuye a Concha y a Liniers (Archivo Pueyrredón), no solo a Obligado")
	check(not ("fragata" in joined) and not ("goleta" in joined) and not ("bandera argentina" in joined and "con bandera" in joined), "La historia no inventa tipo de buque")
	check(not rep.is_empty() and rep.boarded_at > 0.0 and rep.level_at_boarding >= 0.0 and rep.ammo_used >= 0 and rep.groups[0].tag == "tradicion" and rep.has("horses_lost"), "El parte registra el abordaje, los caballos perdidos y las etiquetas")
	_test_victory_quality(all)
	print("ESTRATEGIAS: ", JSON.stringify(wins_by))

## Estrategias "razonables" (reconocen y se comprometen, con o sin defensa del abordaje): el proxy de una partida humana. Excluye las ciegas, la pasiva y la tardía.
const COHORT := ["central_center_lane", "central_flank_lane", "central_flank_pair", "central_hasty", "central_bare", "central_flank_stagger", "central_flank_noreply", "south_full", "south_vado_only", "south_bare", "south_noreply", "mixed_split"]
## Semillas de VALIDACIÓN (no se usaron para calibrar los números del mapa; SEEDS sí).
const VALIDATION_SEEDS := [29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73]

## Calidad de las victorias (Ronda 1): una partida razonable gana ~40-60 % de las veces, también en semillas de validación, y las victorias no son pírricas.
func _test_victory_quality(all: Dictionary) -> void:
	var tg: Dictionary = Rules.new().map_data().play_targets
	var vl: Dictionary = tg.victory_loss
	var lo: float = float(tg.cohort_win_rate[0])
	var hi: float = float(tg.cohort_win_rate[1])
	var cal_w := 0
	var cal_n := 0
	var wins_loss: Array = []
	var defended_max := 0.0
	var marginal_max := 0.0
	var undefended_max := 0.0
	var wins_p := {}
	var games_p := {}
	var loss_max_p := {}
	for p in COHORT:
		wins_p[p] = 0
		games_p[p] = 0
		loss_max_p[p] = 0.0
		for res in all[p]:
			cal_n += 1
			games_p[p] = int(games_p[p]) + 1
			if res.status == "victory":
				cal_w += 1
				wins_p[p] = int(wins_p[p]) + 1
				wins_loss.append(float(res.loss_pct))
				loss_max_p[p] = maxf(float(loss_max_p[p]), float(res.loss_pct))
				if "noreply" in p:
					undefended_max = maxf(undefended_max, float(res.loss_pct))
	var val_w := 0
	var val_n := 0
	var val_by := {}
	for p in COHORT:
		val_by[p] = 0
		for sd in VALIDATION_SEEDS:
			var res := _run_strategy(p, sd)
			val_n += 1
			games_p[p] = int(games_p[p]) + 1
			if res.status == "victory":
				val_w += 1
				val_by[p] = int(val_by[p]) + 1
				wins_p[p] = int(wins_p[p]) + 1
				wins_loss.append(float(res.loss_pct))
				loss_max_p[p] = maxf(float(loss_max_p[p]), float(res.loss_pct))
				if "noreply" in p:
					undefended_max = maxf(undefended_max, float(res.loss_pct))
			if p in ["central_flank_pair", "south_full"]:
				report.results.append({"scenario": "justine", "strategy": p, "seed": sd, "validation": true, "result": {"status": res.status, "t": res.t, "loss_pct": res.loss_pct}})
	# Ronda 2: el tope de bajas con defensa vale para las LINEAS CONFIABLES (ganan la mitad o mas de sus partidas);
	# una linea marginal que apenas gana (p. ej. llegada escalonada) puede ganar caro: es la pendiente de dificultad.
	for p in COHORT:
		if "noreply" in p:
			continue
		if int(wins_p[p]) * 2 >= int(games_p[p]):
			defended_max = maxf(defended_max, float(loss_max_p[p]))
		else:
			marginal_max = maxf(marginal_max, float(loss_max_p[p]))
	var cal_rate := float(cal_w) / float(cal_n)
	var val_rate := float(val_w) / float(val_n)
	check(cal_rate >= lo and cal_rate <= hi, "Estrategias razonables: tasa de victoria en las semillas de calibración %.0f %% dentro de %.0f-%.0f %% (%d/%d)" % [cal_rate * 100.0, lo * 100.0, hi * 100.0, cal_w, cal_n])
	check(val_rate >= lo and val_rate <= hi, "...y en las %d semillas de VALIDACIÓN %.0f %% (%d/%d): no hay sobreajuste a las semillas de calibración" % [VALIDATION_SEEDS.size(), val_rate * 100.0, val_w, val_n])
	check(absf(cal_rate - val_rate) <= 0.15, "La tasa de calibración y la de validación difieren a lo sumo 15 puntos (%.0f vs %.0f %%)" % [cal_rate * 100.0, val_rate * 100.0])
	wins_loss.sort()
	var median: float = float(wins_loss[wins_loss.size() / 2]) if not wins_loss.is_empty() else 100.0
	var over80 := 0
	for l in wins_loss:
		if float(l) > 80.0:
			over80 += 1
	check(wins_loss.size() >= 20 and median <= float(vl.median_max_pct), "Victorias no pírricas: bajas medianas %.0f %% <= %d %% (%d victorias)" % [median, int(vl.median_max_pct), wins_loss.size()])
	check(defended_max <= float(tg.max_victory_loss_pct), "Ninguna victoria con defensa del abordaje, en las líneas confiables, cuesta más del %d %% de la fuerza (máx. %.0f %%)" % [int(tg.max_victory_loss_pct), defended_max])
	check(marginal_max <= float(vl.marginal_line_max_pct), "...y las líneas marginales (ganan menos de la mitad) no pasan del %d %% (máx. %.0f %%): ganar mal es posible pero caro, no un guion" % [int(vl.marginal_line_max_pct), marginal_max])
	check(undefended_max <= float(vl.undefended_max_pct), "Ni siquiera sin defender el abordaje una victoria pasa del %d %% (máx. %.0f %%)" % [int(vl.undefended_max_pct), undefended_max])
	check(float(over80) / float(maxi(1, wins_loss.size())) <= float(vl.share_over_80_max), "Pocas victorias al borde (>80 %% de bajas): %d de %d (máx. %.0f %%)" % [over80, wins_loss.size(), float(vl.share_over_80_max) * 100.0])
	var cf_w := int(val_by.central_flank_pair)
	var sf_w := int(val_by.south_full)
	for res in all.central_flank_pair:
		cf_w += 1 if res.status == "victory" else 0
	for res in all.south_full:
		sf_w += 1 if res.status == "victory" else 0
	var tot_seeds := SEEDS.size() + VALIDATION_SEEDS.size()
	check(absf(float(cf_w - sf_w)) / float(tot_seeds) <= 0.25, "Ronda 9 (C9): la mejor línea de cada ruta rinde parecido (centro %d/%d, sur %d/%d: diferencia ≤ 25 puntos)" % [cf_w, tot_seeds, sf_w, tot_seeds])
	var winners_val := 0
	for p in COHORT:
		if int(val_by[p]) * 2 >= VALIDATION_SEEDS.size():
			winners_val += 1
	check(winners_val >= 4, "En validación al menos 4 estrategias distintas ganan la mitad o más de las semillas (%d): no depende de un guion único" % winners_val)
	report.results.append({"scenario": "justine", "strategy": "calidad_victorias", "cal_rate": cal_rate, "val_rate": val_rate, "median_loss_pct": median, "defended_max_loss_pct": defended_max, "undefended_max_loss_pct": undefended_max, "over80": over80, "wins": wins_loss.size(), "val_by_strategy": val_by})
	print("COHORTE: calibración %d/%d (%.0f %%), validación %d/%d (%.0f %%), bajas medianas %.0f %%, máx. con defensa %.0f %%, sin defensa %.0f %%, >80 %%: %d/%d | validación por estrategia %s" % [cal_w, cal_n, cal_rate * 100.0, val_w, val_n, val_rate * 100.0, median, defended_max, undefended_max, over80, wins_loss.size(), JSON.stringify(val_by)])

func _test_speed_never_exceeded() -> void:
	# Muestreo de 200+ pasos: el desplazamiento por paso nunca supera speed_at del punto de partida.
	var r := _new_j(3)
	var signaled := false
	var samples := 0
	var violations := 0
	var worst := 0.0
	var t_end := 800.0
	var board_done := false
	while r.state.status == "playing" and float(r.state.elapsed) < t_end:
		if float(r.state.elapsed) >= 250.0 and not signaled:
			signaled = r.issue_order("guemes", "signal_liniers").ok
		if float(r.state.elapsed) >= 360.0 and not board_done and bool(r.state.advance_authorized):
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
	for start in range(0, 1080, 90):
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
	var rescue := _at(_tt(700.0))
	var g: Dictionary = rescue.get_unit("guemes")
	g.x = 345.0
	g.z = 264.0
	g.stage = "ready"
	g.order = {}
	check(rescue.speed_at(345, 264, "walk", true) == 0.0, "El grupo de prueba queda en el pozo, bajo el agua honda")
	rescue.state.accumulator = 0.0
	rescue.tick(0.25)
	g = rescue.get_unit("guemes")
	check(rescue.speed_at(float(g.x), float(g.z), "walk", true) > 0.0 and g.stage == "ready" and g.order.is_empty() and g.path.is_empty() and float(g.x) < 256.0, "Rescate: vuelve a la playa con estado limpio")
	check(float(g.fatigue) >= 10.0, "El rescate suma +10 de fatiga")
	var warned := false
	for e in rescue.state.log:
		warned = warned or e.kind == "warning"
	check(warned, "El rescate queda en el registro")
	check(rescue.validate_snapshot(rescue.snapshot()).ok, "El estado tras el rescate es un guardado coherente")
	# Un grupo que entra a un punto no reconocido y hondo tropieza y no se mete en el agujero
	var st := _at(420.0)
	var h: Dictionary = st.get_unit("arias")
	h.x = 305.0
	h.z = 264.0
	h.path = [{"x": 395.0, "z": 264.0}]
	h.order = {"action": "move", "x": 395.0, "z": 264.0}
	h.stage = "moving"
	h.pace = "trot"
	var hit := false
	for i in range(400):
		st.tick(0.25)
		var a: Dictionary = st.get_unit("arias")
		if a.stage == "stumbling":
			hit = true
			check(st.speed_at(float(a.x), float(a.z), "walk", true) > 0.0, "El grupo que tropieza queda en un punto transitable")
			check(float(a.stumble_remaining) > 0.0 and float(a.stumble_remaining) <= 45.0, "El tropiezo detiene hasta 45 s")
			break
	check(hit and st.state.stats.stumbles == 1 and "pozo_central" in st.state.hazards_found, "El tropiezo se registra y el pozo pasa a hazards_found")
	check(float(st.get_unit("arias").strength) <= 70.0 - 30.0 and float(st.state.stats.horses_lost) >= 45.0, "El pozo cuesta caballos y jinetes: −45 de fuerza, no −3")
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
	_advance(r, 300.0)
	r.issue_scout("scout_1", "probe", [Vector2(250, 246), Vector2(296, 246)])
	_advance(r, 400.0)
	r.issue_scout("scout_2", "mark_ford", [Vector2(270, 246), Vector2(290, 246)])
	r.issue_order("zavala", "move", Vector2(250, 300), {"pace": "gallop"})
	_advance(r, 440.0)
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
	var done := _at(1080.0)
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
	s = r.snapshot(); s.volunteers_pool = 301.0; _rejects(r, s, "Voluntarios sobre el reservorio")
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
	_advance(q, 100.0)
	check(q.state.advance_authorized and q.validate_snapshot(q.snapshot()).ok, "advance_authorized con la orden registrada es coherente")

# ---------------------------------------------------------------------------
# 7b. Tamaño del guardado: compacto y con tope

func _test_save_size() -> void:
	var r := _busy_game()
	var path := "user://test-rules-size.json"
	check(r.save_game(path) == OK, "Guardar Justina compacto")
	var text := FileAccess.get_file_as_string(path)
	check(not ("\t" in text) and not ("\n" in text), "El guardado es compacto: sin tabulaciones ni saltos de línea")
	check(text.length() < 200000, "Una partida normal ocupa poco (%d bytes)" % text.length())
	# el registro tiene tope
	for i in range(3 * Rules.LOG_MAX):
		r._event("Evento de prueba %d" % i, "info")
	check(r.state.log.size() <= Rules.LOG_MAX and str(r.state.log[r.state.log.size() - 1].text) == "Evento de prueba %d" % (3 * Rules.LOG_MAX - 1), "El registro conserva solo los últimos %d acontecimientos" % Rules.LOG_MAX)
	check(r.validate_snapshot(r.snapshot()).ok, "El estado con el registro recortado sigue siendo válido")
	# peor caso realista: 400 sondas de 150 puntos
	var big := _busy_game()
	for i in range(400):
		var pts: Array = []
		for k in range(150):
			pts.append({"x": 210.0 + float(k) * 2.123456789, "z": 100.0 + float(i) * 0.987654321})
		big.state.probes.append({"id": "p%d" % (i + 100), "kind": "lane", "pts": pts, "width": 6.0, "t": 10.0, "scout": "scout_1"})
	while big.state.probes.size() > Rules.MAX_PROBES:
		big.state.probes.pop_back()
	for i in range(3 * Rules.LOG_MAX):
		big._event("Evento de relleno %d con texto largo para ocupar espacio en el guardado, %s" % [i, "x".repeat(200)], "info")
	var rc: int = big.save_game(path)
	var size := FileAccess.get_file_as_string(path).length() if rc == OK else -1
	check(rc == OK and size > 0 and size < Rules.SAVE_MAX_BYTES, "Guardar el peor caso (sondas al tope y registro lleno) cabe bajo el tope de guardado (%d bytes < %d)" % [size, Rules.SAVE_MAX_BYTES])
	var back := Rules.new()
	check(rc == OK and back.load_game(path).ok, "El guardado del peor caso se vuelve a cargar (load_game rechaza > 4 MB)")
	check(Rules.SAVE_MAX_BYTES < 4000000, "El tope de guardado queda por debajo del límite de carga")

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
			q.issue_order("guemes", "move", Vector2(200, 300))
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


# ---------------------------------------------------------------------------
# Ronda 9: «jugador humano» simulado con políticas imperfectas (MODELO INVENTADO, no personas; ver docs/DISENO_REGLAS.md)

## Probabilidades de HACER BIEN cada cosa en el primer intento. Con cada derrota el error baja ×0,72 (el diario enseña); el experto lee la variante de misión.
const HUMAN_PROFILES := {
	"experto": {"p_probe": 1.0, "repel_p": 1.0, "cover_p": 1.0, "resup_p": 1.0, "muster_p": 1.0, "evac_p": 1.0, "floor_p": 1.0, "last_p": 1.0, "dodge_p": 0.7, "delay_max": 0.0, "p_south": -1.0, "p_rush": 0.0},
	"promedio": {"p_probe": 0.6, "repel_p": 0.7, "cover_p": 0.6, "resup_p": 0.6, "muster_p": 0.7, "evac_p": 0.5, "floor_p": 0.5, "last_p": 0.6, "dodge_p": 0.35, "delay_max": 70.0, "p_south": 0.3, "p_rush": 0.05},
	"novato": {"p_probe": 0.3, "repel_p": 0.4, "cover_p": 0.4, "resup_p": 0.35, "muster_p": 0.4, "evac_p": 0.25, "floor_p": 0.2, "last_p": 0.3, "dodge_p": 0.1, "delay_max": 140.0, "p_south": 0.3, "p_rush": 0.15},
}

func _human_cfg(prof: Dictionary, rng: RandomNumberGenerator, attempt: int, mission: Dictionary, known_flank: String) -> Dictionary:
	var k := pow(0.72, float(attempt - 1))
	var good := func(p: float) -> float: return 1.0 - (1.0 - p) * k
	var delay := rng.randf() * float(prof.delay_max) * k
	var south: bool
	if float(prof.p_south) < 0.0:
		south = str(mission.get("favors", "central")) == "sur"
	else:
		south = rng.randf() < float(prof.p_south)
	var cfg: Dictionary
	if rng.randf() < float(prof.p_rush) * k:
		cfg = _strategy_cfg("rush_central")
	elif south:
		cfg = _strategy_cfg("south_full" if rng.randf() < float(good.call(prof.p_probe)) else "south_vado_only")
	elif known_flank != "" or rng.randf() < float(good.call(prof.p_probe)):
		cfg = _strategy_cfg("central_flank_pair")
	else:
		cfg = _strategy_cfg("central_bare")
	for key in ["signal_t", "stage_t", "stage2_t", "board_t"]:
		if cfg.has(key) and float(cfg[key]) > 0.0:
			cfg[key] = float(cfg[key]) + delay
	if cfg.has("probes"):
		for job in cfg.probes:
			job.t = float(job.t) + delay * 0.5
	var cov: bool = rng.randf() < float(good.call(prof.cover_p))
	cfg.cover = cov
	cfg.fire = cov
	cfg.resupply = rng.randf() < float(good.call(prof.resup_p))
	cfg.muster = 1 if rng.randf() < float(good.call(prof.muster_p)) else 0
	cfg.evac = rng.randf() < float(good.call(prof.evac_p))
	cfg.repel = true
	cfg.repel_p = float(good.call(prof.repel_p))
	cfg.last_effort_p = float(good.call(prof.last_p))
	cfg.ammo_floor = 6 if rng.randf() < float(good.call(prof.floor_p)) else 0
	if known_flank != "":
		cfg.flank_known = known_flank
	return cfg

func _print_human() -> void:
	var n := 40
	var max_att := 6
	var base := 500
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--n="):
			n = int(a.substr(4))
		elif a.begins_with("--attempts="):
			max_att = int(a.substr(11))
		elif a.begins_with("--base="):
			base = int(a.substr(7))
		elif a.begins_with("--only="):
			only = a.substr(7)
	for pname in HUMAN_PROFILES:
		if only != "" and pname != only:
			continue
		var prof: Dictionary = HUMAN_PROFILES[pname]
		var first_win := 0
		var cum := {}
		var medals := {"bronce": 0, "plata": 0, "oro": 0}
		var win_t: Array = []
		var lose_t: Array = []
		var attempts_needed: Array = []
		var assisted := 0
		var causes := {}
		var by_mission := {}
		var runs := 0
		for w in range(n):
			var world_seed := base + w * 7 + 1
			var rng := RandomNumberGenerator.new()
			rng.seed = hash("%s-%d" % [pname, world_seed])
			var known := ""
			var won_at := -1
			var assists_now: Array = []
			var mission_id := ""
			for att in range(1, max_att + 1):
				var probe_world := _new_j(world_seed, true)
				var mission: Dictionary = probe_world.mission()
				mission_id = str(mission.get("id", ""))
				if att >= 3 and rng.randf() < 0.7:
					assists_now = ["baqueano"]
				if att >= 5 and rng.randf() < 0.7:
					assists_now = ["baqueano", "bajante_generosa"]
				var cfg := _human_cfg(prof, rng, att, mission, known)
				var res := _run_cfg(cfg, pname, world_seed, {"rng": rng, "assists": assists_now, "dodge_p": float(prof.dodge_p) + (1.0 - float(prof.dodge_p)) * (1.0 - pow(0.72, float(att - 1))) * 0.5})
				runs += 1
				if res.status == "victory":
					won_at = att
					win_t.append(float(res.t))
					medals[str(res.medal)] = int(medals[str(res.medal)]) + 1
					if not assists_now.is_empty():
						assisted += 1
					break
				lose_t.append(float(res.t))
				causes[str(res.cause)] = int(causes.get(str(res.cause), 0)) + 1
				var pk := str(res.picks.get("flanco_central", ""))
				if pk in res.found or int(res.stumbles) > 0:
					known = pk
			if won_at > 0:
				attempts_needed.append(won_at)
				for a2 in range(won_at, max_att + 1):
					cum[a2] = int(cum.get(a2, 0)) + 1
			if won_at == 1:
				first_win += 1
			var bm: Array = by_mission.get(mission_id, [0, 0])
			bm[1] += 1
			if won_at == 1:
				bm[0] += 1
			by_mission[mission_id] = bm
		win_t.sort()
		lose_t.sort()
		var line := "%-9s mundos %d | gana al 1.º %2d%% | acum. al 3.º %2d%% | al 5.º %2d%% | al %d.º %2d%% | intentos medios p/ganar %.1f | victoria mediana %s s | derrota mediana %s s (media %s) | medallas %s | con ayuda %d | causas %s | 1.º por variante %s" % [
			pname, n, roundi(100.0 * first_win / n), roundi(100.0 * int(cum.get(3, 0)) / n), roundi(100.0 * int(cum.get(5, 0)) / n), max_att, roundi(100.0 * int(cum.get(max_att, 0)) / n),
			(float(attempts_needed.reduce(func(a, b): return a + b, 0)) / maxf(1.0, attempts_needed.size())),
			str(int(win_t[win_t.size() / 2])) if not win_t.is_empty() else "-", str(int(lose_t[lose_t.size() / 2])) if not lose_t.is_empty() else "-",
			str(int(lose_t.reduce(func(a, b): return a + b, 0.0) / maxf(1.0, lose_t.size()))), str(medals), assisted, str(causes), str(by_mission)]
		print(line)
	quit(0)
