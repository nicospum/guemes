extends RefCounted
## Comprobaciones de la capa de reglas del nivel «humahuaca» que viven aparte de tests/test_hx_rules.gd para que cada archivo del nivel quede por debajo de las ~1 500 líneas
## del contrato (se parte por responsabilidad): rutas de A*, visión de los centinelas y fuego de la torre, ritmo, puntos de control y diario, y la biblioteca de políticas
## (el experto gana, el pasivo pierde, las políticas sin ventaja no leen lo oculto). Dueña: reglas_historia. test_hx_rules.gd la instancia con `Checks.new(self)` y le presta sus
## ayudas (ck, new_rules, order…); las funciones `_test_*` de acá se llaman desde allá y cuentan en la misma suite.

const V = preload("res://scripts/humahuaca/humahuaca_vocab.gd")
const R = preload("res://scripts/humahuaca/rules/vocab_rules.gd")
const CHECKPOINT_PATH := "user://hx_rules_test_checkpoint.json"

var t: Object

func _init(test: Object) -> void:
	t = test

## ¿Algún muestreo de la ruta cae en un muro? (cada 2 m)
func path_hits_wall(r: RefCounted, path: Array) -> bool:
	var terr: RefCounted = r.call("terrain")
	var pts: Array = []
	for p in path:
		pts.append(p if p is Vector2 else Vector2(float(p.x), float(p.z)))
	for i in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var n := maxi(1, ceili(a.distance_to(b) / 2.0))
		for k in range(n + 1):
			var q := a.lerp(b, float(k) / float(n))
			if terr.call("is_blocked", q.x, q.y):
				return true
	return false

func _test_nav_and_routes() -> void:
	if not t.real_only() or t.nav_script == null:
		return
	var r = t.new_rules(1817, {"skip_intro": true})
	var nav: RefCounted = t.nav_script.call("for_terrain", r.call("terrain"))
	t.ck(nav != null and int(nav.nx) > 100 and int(nav.nz) > 100 and int(nav.solid_cells) > 100, "la grilla de navegación sale del terreno (%s)" % str(nav.call("stats") if nav != null else {}))
	t.ck(t.nav_script.call("for_terrain", r.call("terrain")) == nav, "la grilla es una sola por terreno (caché)")
	# cada partida llega a cada puesto de ataque, a la salida y a los frentes, por camino libre de muros
	var unreachable: Array = []
	var through_walls: Array = []
	for g in V.GROUPS:
		var from = t.hito("spawn_" + g)
		var targets: Array = [t.hito("vado_este"), t.hito("posta"), t.hito("bateria"), t.hito("cuartel")]
		for fid in V.OBJECTIVES:
			for post in t.level.access.attack_posts[fid]:
				targets.append(Vector2(float(post.x), float(post.z)))
		for t in targets:
			var path: Array = nav.call("find_path", from, t)
			if path.is_empty():
				unreachable.append("%s → (%.0f, %.0f)" % [g, t.x, t.y])
			elif path_hits_wall(r, path):
				through_walls.append("%s → (%.0f, %.0f)" % [g, t.x, t.y])
	t.ck(unreachable.is_empty(), "cada partida llega a los puestos de ataque, a los frentes y al vado por la grilla: sin camino %s" % str(unreachable.slice(0, 4)))
	t.ck(through_walls.is_empty(), "ninguna ruta cruza un muro: %s" % str(through_walls.slice(0, 4)))
	# una tapia obliga a rodear
	var a := Vector2(370.0, 360.0)
	var b := Vector2(370.0, 400.0)
	var around: Array = nav.call("find_path", a, b)
	var detour := float(t.nav_script.call("length_of", around))
	t.ck(not around.is_empty() and detour > a.distance_to(b) * 1.3 and not path_hits_wall(r, around), "entre dos tapias de la calle del cuartel la ruta rodea en vez de atravesar (%.0f m contra %.0f m en línea recta)" % [detour, a.distance_to(b)])
	var portal = t.unit_of(r, "portal")
	var plan: Dictionary = t._dict(r.call("plan_route", "portal", b, {}))
	t.ck(bool(plan.ok) and float(plan.length_m) >= Vector2(float(portal.x), float(portal.z)).distance_to(b) - 1.0, "plan_route nunca es más corto que la línea recta")
	# un destino dentro de un edificio termina en la celda libre más cercana
	var inside = t.hito("polvorin")
	var p_in: Dictionary = t._dict(r.call("plan_route", "arreo", inside, {}))
	var last: Dictionary = (p_in.path as Array)[(p_in.path as Array).size() - 1] if bool(p_in.ok) else {"x": 0.0, "z": 0.0}
	t.ck(bool(p_in.ok) and not bool(r.call("terrain").call("is_blocked", float(last.x), float(last.z))), "un destino dentro del polvorín deja la ruta en la celda libre más cercana, no dentro del muro")
	# la velocidad la pone el terreno: el barro y el riego frenan, el vado frena más
	var firm: float = float(r.call("_speed_at", 450.0, 330.0, "march", false))
	t.ck(firm > 0.1 and firm <= float(t.cfg.stealth.pace.march.speed) + 1e-6, "la velocidad de marcha en terreno firme es la del ritmo, a lo sumo (%.2f m/s)" % firm)
	t.ck(float(r.call("_speed_at", 725.0, 230.0, "march", false)) < firm, "la parcela regada frena más que la calle")
	var ford_speed: float = float(r.call("_speed_at", t.hito("vado_este").x, t.hito("vado_este").y, "march", false))
	t.ck(ford_speed <= float(t.cfg.stealth.pace.march.speed) * float(t.cfg.transport.ford_mult) + 1e-6, "el vado se cruza a media velocidad o menos (%.2f m/s)" % ford_speed)
	# una orden con destino sobre el muro se acepta y la agrupación no se clava en él
	var wall_order = t.order(r, "portal", "move", Vector2(380.0, 376.0))
	t.ck(bool(wall_order.ok), "un destino sobre una tapia se acepta (la ruta termina a su lado): %s" % str(wall_order.get("reason", "")))
	var moved = t.run_until(r, func(): return str(t.unit_of(r, "portal").stage) == "idle", 300.0)
	t.ck(moved and not bool(r.call("terrain").call("is_blocked", float(t.unit_of(r, "portal").x), float(t.unit_of(r, "portal").z))), "...y la agrupación llega y queda fuera del muro")

func _test_sentinels_and_tower_sight() -> void:
	if not t.real_only():
		return
	var r = t.new_rules(1817, {"skip_intro": true})
	var vis := 45.0
	var behind_wall := {"x": 565.0, "z": 320.0, "noise": 0.5}
	var in_the_open := {"x": 560.0, "z": 256.0, "noise": 0.5}  # en línea con el hueco de la puerta del patio
	t.ck(not bool(r.call("_sentinel_sees", "posta", behind_wall, vis)), "el centinela de la posta no ve a quien está detrás de la tapia del patio (a %.0f m)" % Vector2(565.0, 320.0).distance_to(Vector2(576.0, 304.0)))
	t.ck(bool(r.call("_sentinel_sees", "posta", in_the_open, vis)), "...y sí ve a quien hace el mismo ruido a cielo abierto, frente a la puerta")
	t.ck(not bool(r.call("_sentinel_sees", "posta", {"x": 520.0, "z": 296.0, "noise": 0.1}, vis)), "en silencio y a más de 55 m no los ven")
	# torre: ángulo muerto, alcance y calle abierta
	var tp: Vector2 = r.call("_tower_pos")
	var u_dead := {"x": tp.x + 4.0, "z": tp.y, "stage": "idle", "pace": "march", "order": {}}
	var u_far := {"x": tp.x + 140.0, "z": tp.y, "stage": "idle", "pace": "march", "order": {}}
	var u_storm := {"x": tp.x - 70.0, "z": tp.y, "stage": "attacking", "pace": "march", "order": {"front": "cuartel", "posture": "a_fondo"}}
	var u_cautious := {"x": tp.x - 70.0, "z": tp.y, "stage": "attacking", "pace": "march", "order": {"front": "cuartel", "posture": "con_cautela"}}
	t.ck(float(r.call("_tower_hit_mult", u_dead, tp)) == 0.0, "al pie de la torre (ángulo muerto de %.0f m) no hay daño" % float(t.cfg.tower.dead_angle_m))
	t.ck(float(r.call("_tower_hit_mult", u_far, tp)) == 0.0, "más allá de los %.0f m de la torre no hay daño" % float(t.cfg.tower.radius_m))
	t.ck(float(r.call("_tower_hit_mult", u_storm, tp)) > float(r.call("_tower_hit_mult", u_cautious, tp)) and float(r.call("_tower_hit_mult", u_cautious, tp)) > 0.0, "quien asalta a fondo por la calle abierta recibe más que quien va con cautela")
	var runner := {"x": tp.x - 60.0, "z": tp.y + 40.0, "stage": "moving", "pace": "run", "order": {"action": "move"}}
	var walker := {"x": tp.x - 60.0, "z": tp.y + 40.0, "stage": "moving", "pace": "march", "order": {"action": "move"}}
	t.ck(float(r.call("_tower_hit_mult", runner, tp)) <= float(r.call("_tower_hit_mult", walker, tp)), "quien cruza corriendo es más difícil de acertar que quien marcha")

func _test_pacing_offers() -> void:
	var r = t.new_rules(1817, {"skip_intro": true})
	for i in range(4):
		r.call("tick", 1.0)
	var pacing: Dictionary = r.state.stats.pacing
	t.ck(float(pacing.first_decision_s) >= 0.0 and float(pacing.first_decision_s) <= 20.0, "la primera decisión se ofrece antes de los 20 s (a los %.1f s)" % float(pacing.first_decision_s))
	var walk = t.new_rules(1817, {"skip_intro": true})
	t.follow_next_step(walk, 900.0)
	var pc: Dictionary = walk.state.stats.pacing
	t.ck(float(pc.decision_gap_max_s) >= 0.0 and float(pc.decision_gap_max_s) < 840.0 and float(pc.decision_gap_attack_max_s) >= 0.0, "el ritmo mide la brecha mayor sin ofertas (%.0f s) y la del ataque (%.0f s)" % [float(pc.decision_gap_max_s), float(pc.decision_gap_attack_max_s)])
	t.ck(float(pc.events_per_min) > 0.0, "el ritmo cuenta los acontecimientos por minuto (%.2f)" % float(pc.events_per_min))
	var empty_gap = t.new_rules(1817, {"skip_intro": true})
	t.run_to(empty_gap, 100.0)
	t.ck(float(empty_gap.state.stats.pacing.decision_gap_max_s) >= 0.0, "una partida sin órdenes también mide su brecha (%.0f s)" % float(empty_gap.state.stats.pacing.decision_gap_max_s))

func _test_progress_checkpoints_and_diary() -> void:
	if not t.real_only() or t.pol == null:
		return
	var p = t.new_progress()
	p.call("reset_all")
	t.ck(not bool(p.call("has_checkpoint", "posiciones")) and float(p.call("checkpoint_time", "posiciones")) < 0.0, "sin intentos no hay puntos de control")
	var r = t.new_rules(int(p.call("world_seed")), {"skip_intro": true})
	p.call("begin_attempt", r)
	var guard := 0
	while not bool(p.call("has_checkpoint", "posiciones")) and str(r.state.status) == "playing" and guard < 400:
		guard += 1
		if guard == 1:
			for g in V.COMBAT_GROUPS:
				t.order(r, g, "position")
		r.call("tick", 1.0)
		p.call("checkpoint_tick", r)
	t.ck(bool(p.call("has_checkpoint", "posiciones")), "el control «posiciones» se guarda cuando las tres partidas esperan la señal (a los %.0f s)" % float(r.state.elapsed))
	t.ck(not bool(r.state.alarm.signaled) and float(p.call("checkpoint_time", "posiciones")) > 0.0, "...antes de la señal, y dice a qué segundo de juego volvería")
	var saved_t := float(p.call("checkpoint_time", "posiciones"))
	t.run_to(r, saved_t + 40.0)
	var before_attempts := int(p.attempts)
	var back: Dictionary = t._dict(p.call("restore_checkpoint", r, "posiciones"))
	t.ck(bool(back.get("ok", false)) and absf(float(r.state.elapsed) - saved_t) < 1e-6 and int(p.attempts) == before_attempts + 1, "restaurar «posiciones» devuelve el reloj a %.0f s y cuenta un intento: %s" % [saved_t, str(back.get("reason", ""))])
	t.ck(bool(t._dict(r.call("validate_snapshot", r.call("snapshot"))).ok), "...y el estado restaurado es válido")
	var posiciones_ok := false
	for o in p.call("retry_options"):
		if str(o.id) == "posiciones":
			posiciones_ok = bool(o.available) and float(o.at_s) > 0.0
	t.ck(posiciones_ok, "retry_options marca «posiciones» como disponible, con su segundo")
	# el control de la salida se guarda al tomar el tercer frente
	var ext = t.new_rules(int(p.call("world_seed")), {"phase": "ataque"})
	p.call("begin_attempt", ext)
	var g2 := 0
	while str(ext.state.phase) != "extraccion" and str(ext.state.status) == "playing" and g2 < 400:
		g2 += 1
		ext.call("tick", 1.0)
		p.call("checkpoint_tick", ext)
	p.call("checkpoint_tick", ext)
	t.ck(bool(p.call("has_checkpoint", "salida")), "el control de la salida se guarda al tomar el tercer frente")
	var again = t.new_progress()
	t.ck(bool(again.call("has_checkpoint", "salida")), "...y sobrevive a cerrar y abrir")
	t.ck(not bool(t._dict(again.call("restore_checkpoint", ext, "mundo_nuevo")).get("ok", true)), "no hay control para «mundo_nuevo»: se rechaza con motivo")
	# el diario: lo que pasó deja una entrada y una marca tenue para el intento siguiente
	var q = t.new_progress()
	q.call("reset_all")
	var lost = t.new_rules(1817, {"skip_intro": true})
	q.call("begin_attempt", lost)
	lure_alarm(lost, "rodriguez", "bateria")
	lost.state.units[0].strength = 5.0
	lost.call("tick", 1.0)
	var rr: Dictionary = t._dict(q.call("record_result", lost))
	t.ck(str(rr.cause_id) == "descubiertos" and (rr.new_diary as Array).size() == 1, "una derrota por «descubiertos» deja una entrada nueva en el diario")
	var entries: Array = q.call("diary_entries")
	var marks: Array = q.call("diary_marks")
	t.ck(entries.size() == 1 and marks.size() == 1 and String(entries[0].text).find("batería") >= 0 and not bool(marks[0].confirmed), "...con el lugar dicho en palabras y una marca sin confirmar: «%s»" % (String(entries[0].text) if entries.size() > 0 else ""))
	var next_try = t.new_rules(1817, {"skip_intro": true})
	q.call("begin_attempt", next_try)
	var shown: Array = t._dict(next_try.call("render_state")).marks
	t.ck(shown.size() == 1 and String(shown[0].text).begins_with("Anotado"), "el intento siguiente dibuja la marca «Anotado»")
	t.ck(float(next_try.state.objectives.bateria.reconocido) == 0.0 and float(next_try.state.objectives.bateria.alert) == 0.0, "las marcas del diario no cuentan como reconocimiento ni bajan la alerta")
	q.call("reset_all")
	t.ck((q.call("diary_entries") as Array).is_empty() and not FileAccess.file_exists(CHECKPOINT_PATH), "reset_all vacía el diario y borra los controles")

# ---------------------------------------------------------------------------------------------------------------------
# La biblioteca de políticas (CONTRATO 3.2.5): el experto gana, el pasivo pierde

func _test_policies_extremes() -> void:
	if t.pol == null:
		return
	var names: Array = t.pol.call("list")
	var must_have := ["experto", "obediente", "torpe", "ciego_sin_recon", "ciego_tarde", "ciego_un_frente", "ciego_sin_arreo", "pasivo", "pausa_reanuda", "aleatorio", "barrido_senal", "interfaz"]
	var missing: Array = []
	for n in must_have:
		if not names.has(n):
			missing.append(n)
	for fid in V.OBJECTIVES:
		for ap in R.APPROACHES[fid]:
			if not names.has("est_%s_%s" % [fid, ap]):
				missing.append("est_%s_%s" % [fid, ap])
	for rc in R.EXTRACTIONS:
		if not names.has("ext_" + str(rc)):
			missing.append("ext_" + str(rc))
	t.ck(missing.is_empty() and names.size() == 10 + 8 + 5 + 2, "la lista de políticas trae las %d del contrato 3.2.5 (faltan %s)" % [names.size(), str(missing)])
	t.ck(bool(t.pol.call("is_implemented", "experto")) and bool(t.pol.call("is_implemented", "pasivo")) and bool(t.pol.call("is_implemented", "obediente")), "el experto, el pasivo y el obediente están implementados")
	t.ck(not bool(t.pol.call("is_implemented", "interfaz")) and String(t.pol.call("skip_reason", "interfaz")).find("escena") >= 0, "la política de interfaz pide la escena y lo dice: «%s»" % String(t.pol.call("skip_reason", "interfaz")))
	t.ck(String(t.pol.call("skip_reason", "ext_ocultar")).find("R2a") >= 0 and String(t.pol.call("skip_reason", "no_existe")) != "", "una política que todavía no existe se omite con motivo, no es un error")
	# el experto gana y el pasivo pierde en las ocho semillas de calibración
	var wins := 0
	var passive_ok := 0
	var pause_ok := 0
	var obey_wins := 0
	var fields_ok := true
	var seeds := [3, 5, 7, 11, 13, 17, 19, 23]
	for sd in seeds:
		var rx = t.new_rules(sd, {})
		var rec: Dictionary = t._dict(t.pol.call("play", rx, "experto", {}))
		wins += 1 if str(rec.status) == "victory" else 0
		for k in ["policy", "family", "status", "cause_id", "cause_text", "elapsed_s", "golpe", "loss_pct", "fronts_taken", "opening", "variant", "first_decision_s", "decision_gap_max_s", "decision_gap_attack_max_s", "decision_metric", "max_critical_alerts", "exceptions", "valid"]:
			if not rec.has(k):
				fields_ok = false
		var rp = t.new_rules(sd, {})
		var pr: Dictionary = t._dict(t.pol.call("play", rp, "pasivo", {}))
		passive_ok += 1 if str(pr.status) == "defeat" and str(pr.cause_id) == "amanecio" else 0
		var rq = t.new_rules(sd, {})
		var qr: Dictionary = t._dict(t.pol.call("play", rq, "pausa_reanuda", {}))
		pause_ok += 1 if str(qr.status) == "defeat" and str(qr.cause_id) == "amanecio" else 0
		var ro = t.new_rules(sd, {})
		var orr: Dictionary = t._dict(t.pol.call("play", ro, "obediente", {}))
		obey_wins += 1 if str(orr.status) == "victory" else 0
	t.ck(fields_ok, "el registro de una partida trae los campos de hx_playthrough_v1 que lee qa_balance.py")
	t.ck(float(wins) / float(seeds.size()) >= 0.9, "compuerta 1: el experto gana %d de %d partidas (se pide ≥ 90 %%)" % [wins, seeds.size()])
	t.ck(passive_ok == seeds.size() and pause_ok == seeds.size(), "compuerta 2: el pasivo y «pausa y reanuda» pierden todas, por amanecio (%d y %d de %d)" % [passive_ok, pause_ok, seeds.size()])
	t.ck(obey_wins >= 1, "el obediente, que solo sigue el «siguiente paso», gana alguna vez (%d de %d); su tasa es un informe, no una compuerta" % [obey_wins, seeds.size()])
	# determinismo: la misma semilla da la misma partida, hasta el hash del estado
	var h1 = t.new_rules(41, {})
	var h2 = t.new_rules(41, {})
	t.pol.call("play", h1, "experto", {})
	t.pol.call("play", h2, "experto", {})
	t.ck(t.snap_hash(h1) == t.snap_hash(h2), "la misma semilla y la misma política dan el mismo estado final (snapshot_sha256)")
	t.ck(bool(t._dict(h1.call("validate_snapshot", h1.call("snapshot"))).ok), "el estado final de una partida jugada pasa validate_snapshot")
	# el aleatorio no rompe nada
	var weird_valid := true
	for sd in [101, 103, 107, 109]:
		var rz = t.new_rules(sd, {})
		var zr: Dictionary = t._dict(t.pol.call("play", rz, "aleatorio", {}))
		if not bool(zr.valid) or int(zr.exceptions) != 0:
			weird_valid = false
	t.ck(weird_valid, "cuatro partidas al azar terminan con el estado válido y sin excepciones")
	# la señal forzada (barrido): darla más tarde mueve la hora de la señal
	var early = t.new_rules(7, {})
	var late = t.new_rules(7, {})
	t.pol.call("play", early, "barrido_senal", {"signal_s": 200.0})
	t.pol.call("play", late, "barrido_senal", {"signal_s": 300.0})
	t.ck(absf(float(early.state.alarm.signal_at) - 200.0) <= 1.0 and absf(float(late.state.alarm.signal_at) - 300.0) <= 1.0, "el barrido de la señal da la señal en el segundo pedido (%.0f s y %.0f s)" % [float(early.state.alarm.signal_at), float(late.state.alarm.signal_at)])

func _test_policies_blindness() -> void:
	if t.pol == null:
		return
	## Las políticas sin ventaja deciden lo mismo aunque cambie lo que el jugador no ve (la guardia real, el reloj del refuerzo, el mundo): no leen estado oculto.
	var blind := ["obediente", "torpe", "pasivo", "pausa_reanuda", "aleatorio"]
	var all_same := true
	var no_secret := true
	for policy in blind:
		var a = t.new_rules(1817, {"phase": "ataque"})
		var b = t.new_rules(1817, {"phase": "ataque"})
		a.call("tick", 20.0)
		b.call("tick", 20.0)
		b.state.alarm.reinforcement_at = float(b.state.alarm.reinforcement_at) + 90.0
		for fid in V.OBJECTIVES:
			b.state.objectives[fid].garrison = float(b.state.objectives[fid].garrison) * 0.5
		b.state.world.rumors = [{"id": "x", "dim": "guardia", "val": "atenta", "reliability": 0.7, "true_value": "descuidada", "shown": false}]
		var mem_a := {}
		var mem_b := {}
		var rng_a := RandomNumberGenerator.new()
		var rng_b := RandomNumberGenerator.new()
		rng_a.seed = 9
		rng_b.seed = 9
		var va: Dictionary = t.pol.call("make_view", a, policy, mem_a)
		var vb: Dictionary = t.pol.call("make_view", b, policy, mem_b)
		if va.has("secret") or vb.has("secret") or bool(va.omniscient) or bool(t.pol.call("has_advantage", policy)):
			no_secret = false
		if JSON.stringify(t.pol.call("decide", policy, va, rng_a)) != JSON.stringify(t.pol.call("decide", policy, vb, rng_b)):
			all_same = false
	t.ck(no_secret, "las políticas sin ventaja (obediente, torpe, pasivo, pausa y reanuda, aleatorio) no reciben el estado oculto")
	t.ck(all_same, "...y deciden lo mismo aunque cambien la guardia real, el reloj del refuerzo y las pistas del mundo")
	var ex = t.new_rules(1817, {"phase": "ataque"})
	var vx: Dictionary = t.pol.call("make_view", ex, "experto", {})
	t.ck(bool(vx.omniscient) and vx.has("secret"), "solo el experto (y las políticas de enfoque y de extracción) recibe omniscient: true")

## Mide el tiempo medio de armar la grilla de navegación, de planificar una ruta y de avanzar un paso. Los topes son los del contrato: 80, 30 y 2 ms. La línea final de
## la t.suite trae `performance: {nav_build_ms_avg, plan_route_ms_avg, tick_ms_avg}` (QA_NIVEL2 T03 y anexo D, Q4).
func _test_performance() -> void:
	var rt = t.new_rules(1817, {"phase": "ataque"})
	var t0 := Time.get_ticks_usec()
	for i in range(400):
		rt.call("tick", 0.25)
	var tick_ms := float(Time.get_ticks_usec() - t0) / 1000.0 / 400.0
	var fresh = t.new_rules(1817, {"skip_intro": true})
	var targets := [Vector2(500, 400), Vector2(350, 381), Vector2(246, 398), Vector2(560, 372), Vector2(862, 340), Vector2(318, 350)]
	var actors := ["portal", "rodriguez", "arias", "arreo"]
	var t1 := Time.get_ticks_usec()
	var plans := 0
	for rep in range(5):
		for a in actors:
			for tg in targets:
				fresh.call("plan_route", a, tg)
				plans += 1
	var plan_ms := float(Time.get_ticks_usec() - t1) / 1000.0 / float(plans)
	var t2 := Time.get_ticks_usec()
	for i in range(100):
		rt.call("hud_state")
		rt.call("render_state")
	var hud_ms := float(Time.get_ticks_usec() - t2) / 1000.0 / 100.0
	var nav_ms := -1.0
	var terr: Variant = rt.call("terrain")
	if t.nav_script != null and terr != null:
		var total := 0.0
		var builds := 5
		var built_ok := true
		for i in range(builds):
			var tn := Time.get_ticks_usec()
			var made: Variant = t.nav_script.call("build", terr)
			total += float(Time.get_ticks_usec() - tn) / 1000.0
			if made == null:
				built_ok = false
		nav_ms = total / float(builds)
		t.ck(built_ok, "la grilla de navegación se arma desde el terreno (nav_grid)")
	t.suite.extra["performance"] = {"nav_build_ms_avg": snappedf(nav_ms, 0.001), "plan_route_ms_avg": snappedf(plan_ms, 0.001), "tick_ms_avg": snappedf(tick_ms, 0.001),
		"hud_y_render_ms_avg": snappedf(hud_ms, 0.001)}
	t.ck(nav_ms >= 0.0 and nav_ms <= 80.0, "rendimiento: armar la grilla de navegación promedia %.3f ms (tope 80 ms)" % nav_ms)
	t.ck(tick_ms <= 2.0, "rendimiento: tick promedia %.3f ms (tope 2 ms)" % tick_ms)
	t.ck(plan_ms <= 30.0, "rendimiento: plan_route promedia %.3f ms (tope 30 ms) en %d rutas" % [plan_ms, plans])
	t.ck(hud_ms <= 6.0, "rendimiento: hud_state y render_state juntos promedian %.3f ms (deben caber en un cuadro)" % hud_ms)

## Las situaciones que llevan a la causa «descubiertos» (la que enseña a andar en silencio). `reached` junta las causas alcanzadas por _test_outcomes.
func _test_discovered(reached: Dictionary) -> void:
	var dc = t.new_rules(1817, {"skip_intro": true})
	var seen = lure_alarm(dc, "rodriguez", "bateria")
	t.ck(seen and str(dc.state.status) == "playing" and str(dc.state.objectives.bateria.state) == "en_alarma", "correr a la vista de los centinelas de la batería levanta la alarma antes de la señal (a los %.0f s)" % float(dc.state.elapsed))
	dc.state.units[0].strength = float(t.cfg.combat.rout_strength) - 1.0
	dc.call("tick", 1.0)
	reached[str(dc.state.reason)] = t._dict(dc.call("campaign_report"))
	t.ck(str(dc.state.reason) == "descubiertos" and String(reached[str(dc.state.reason)].cause).find("batería") >= 0, "una partida rota en el frente que ya estaba en alarma es «descubiertos» y dice el lugar: «%s»" % String(reached[str(dc.state.reason)].get("cause", "")))
	# los tres frentes en alarma antes de la señal: la sorpresa se perdió del todo
	var blown = t.new_rules(1817, {"skip_intro": true})
	for g in V.COMBAT_GROUPS:
		var fid := str(t.cfg.groups[g].front)
		blown.state.objectives[fid].alert = 0.99
		blown.state.objectives[fid].state = "alertado"
		var u = t.unit_dict(blown, g)
		var spot: Vector2 = Vector2(562.0, 262.0) if fid == "posta" else t.hito(fid) + Vector2(-18.0, 6.0)  # a la vista de los centinelas (el patio de la posta tapa el resto)
		u.stage = "loading"  # una agrupación haciendo ruido junto a los centinelas
		u.work = {"kind": "load", "item": "", "remaining_s": 999.0}
		u.x = spot.x
		u.z = spot.y
	blown.call("tick", 20.0)
	t.ck(str(blown.state.status) == "defeat" and str(blown.state.reason) == "descubiertos", "con los tres frentes en alarma antes de la señal la partida se pierde por «descubiertos»: %s" % str(blown.state.reason))
	# el desvelo del alba solo no cuenta: sin que los vean, la partida pasiva sigue cayendo por «amanecio»
	var calm = t.new_rules(1817, {"skip_intro": true})
	t.run_to(calm, 900.0)
	t.ck(str(calm.state.reason) == "amanecio" and (calm.state.alarm.pre_signal as Array).is_empty(), "la alarma que levanta el desvelo del alba no es «descubiertos»: la partida pasiva cae por amanecio")

## Hace que `actor` corra de un lado a otro a la vista de los centinelas de `fid` hasta que la guardia dé la alarma (sin señal). Devuelve si lo logró.
func lure_alarm(r: RefCounted, actor: String, fid: String) -> bool:
	var a = t.hito(fid) + Vector2(-26.0, 6.0)
	var b = t.hito(fid) + Vector2(-30.0, -12.0)
	var flip := false
	var guard := 0
	while str(r.state.status) == "playing" and not (r.state.alarm.pre_signal as Array).has(fid) and guard < 400:
		guard += 1
		if str(t.unit_of(r, actor).stage) == "idle":
			t.order(r, actor, "move", b if flip else a, {"pace": "run"})
			flip = not flip
		r.call("tick", 1.0)
	return (r.state.alarm.pre_signal as Array).has(fid)
