extends RefCounted
## Comprobaciones de la capa de reglas del nivel «humahuaca» que viven aparte de tests/test_hx_rules.gd para que cada archivo del nivel quede por debajo de las ~1 500 líneas
## del contrato (se parte por responsabilidad): rutas de A*, visión de los centinelas y fuego de la torre, ritmo, puntos de control y diario, y la biblioteca de políticas
## (el experto gana, el pasivo pierde, las políticas sin ventaja no leen lo oculto). Dueña: reglas_historia. test_hx_rules.gd la instancia con `Checks.new(self)` y le presta sus
## ayudas (ck, new_rules, order…); las funciones `_test_*` de acá se llaman desde allá y cuentan en la misma suite.

const V = preload("res://scripts/humahuaca/humahuaca_vocab.gd")
const R = preload("res://scripts/humahuaca/rules/vocab_rules.gd")
const D = preload("res://scripts/humahuaca/rules/humahuaca_data.gd")
const Schema = preload("res://scripts/humahuaca/rules/humahuaca_rules_schema.gd")
const CHECKPOINT_PATH := "user://hx_rules_test_checkpoint.json"
const PROGRESS_FILE := "user://hx_rules_test_hostile_progress.json"
const FUZZ_KINDS := ["null", "str", "arr", "dict", "neg", "huge", "bool", "del"]  # las ocho clases de mutación del revisor técnico de R1 (fuzz_guardado_simple)

var t: Object
var _lcg_state := 1  # el azar de las pruebas es propio (un congruencial): la misma corrida da lo mismo

func _init(test: Object) -> void:
	t = test

## Cuenta lo que el motor imprime mientras corre una comprobación. Un SCRIPT ERROR no tira la prueba que lo causó: la función se corta, el programa sigue y solo queda en el
## registro, donde lo lee el QA (T05). Con este contador la prueba lo ve ella misma, en proceso. `script_errors` son los de tipo script; `errors`, los de cualquier otro tipo de error.
class ErrorCounter extends Logger:
	var script_errors := 0
	var errors := 0
	var last := ""

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array) -> void:
		if error_type == 2 or error_type == 3:
			script_errors += 1
		elif error_type == 0:
			errors += 1
		last = "%s %s:%d %s %s" % [function, file.get_file(), line, code, rationale]

	func _log_message(_message: String, _error: bool) -> void:
		pass

func _counter_start() -> ErrorCounter:
	var c := ErrorCounter.new()
	OS.add_logger(c)
	return c

func _counter_stop(c: ErrorCounter) -> void:
	OS.remove_logger(c)

func _lcg_seed(seed_value: int) -> void:
	_lcg_state = maxi(1, absi(seed_value) % 2147483646)

func _lcg() -> float:
	_lcg_state = (_lcg_state * 48271) % 2147483647
	return float(_lcg_state) / 2147483647.0

func _lcg_range(low: float, high: float) -> float:
	return low + (high - low) * _lcg()

func _lcg_pick(options: Array) -> Variant:
	return options[int(_lcg() * float(options.size())) % options.size()]

func _heavy() -> bool:
	return str(t.suite.extra.get("modo", "rapido")) == "completo"

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
	# el control de la salida se guarda al tomar el tercer frente (balance R2b: el cuartel ya no cae solo; lo juega el experto, con apoyo)
	var ext = t.new_rules(int(p.call("world_seed")), {"phase": "ataque"})
	p.call("begin_attempt", ext)
	var ext_mem := {}
	var ext_rng := RandomNumberGenerator.new()
	ext_rng.seed = 7
	var g2 := 0
	while str(ext.state.phase) != "extraccion" and str(ext.state.status) == "playing" and g2 < 400:
		g2 += 1
		t.pol.call("step", ext, "experto", ext_mem, ext_rng)
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
# El mundo de cada semilla (balance R2b: las dimensiones activas se sortean; la 1817 da el mundo fijo)

func _test_world_from_seed() -> void:
	var r = t.new_rules()
	var first: Dictionary = t._dict(r.call("world_from_seed", 1817))
	var dims_ok := true
	for dim in R.VARIANTS:
		if not first.has(dim) or not (R.VARIANTS[dim] as Array).has(first[dim]):
			dims_ok = false
	t.ck(dims_ok, "world_from_seed trae las seis dimensiones con valores legales: %s" % str(first))
	var traits: Dictionary = t._dict(first.get("loot", {}))
	var traits_ok := true
	for k in R.WORLD_TRAITS:
		if not traits.has(k) or not (R.WORLD_TRAITS[k] as Array).has(traits[k]):
			traits_ok = false
	t.ck(traits_ok, "...y los rasgos del botín del mundo (corral, plata, pólvora) legales: %s" % str(traits))
	t.ck(t.same(first, t._dict(r.call("world_from_seed", 1817))), "world_from_seed es determinista")
	## Balance R2b (rama hx-balance-nube): las dimensiones activas se sortean con la semilla desde ya (antes: «en R1 el mundo es fijo»); la 1817 (el mundo guiado
	## de la campaña) sigue dando el mundo fijo, las inactivas no cambian y las ocho semillas de calibración cubren cada valor activo al menos dos veces.
	var fixed: Dictionary = t._dict(t._dict(t.cfg.get("variants", {})).get("fixed", {}))
	var fixed_1817 := true
	for dim in R.VARIANTS:
		if fixed.has(dim) and str(first[dim]) != str(fixed[dim]):
			fixed_1817 = false
	t.ck(fixed_1817, "la semilla 1817 da el mundo fijo de variants.fixed: %s" % str(first))
	var seen := {}
	var inactive_same := true
	for sd in [3, 5, 7, 11, 13, 17, 19, 23]:
		var w: Dictionary = t._dict(r.call("world_from_seed", sd))
		for dim in R.VARIANTS:
			if R.ACTIVE_DIMS.has(dim):
				seen[str(dim) + "=" + str(w[dim])] = int(seen.get(str(dim) + "=" + str(w[dim]), 0)) + 1
			elif str(w[dim]) != str(first[dim]):
				inactive_same = false
	t.ck(inactive_same, "las dimensiones inactivas valen lo mismo en todas las semillas")
	var scarce: Array = []
	for dim in R.ACTIVE_DIMS:
		for val in R.VARIANTS[dim]:
			if int(seen.get(str(dim) + "=" + str(val), 0)) < 2:
				scarce.append(str(dim) + "=" + str(val))
	t.ck(scarce.is_empty(), "las ocho semillas de calibración cubren cada valor de cada dimensión activa ≥ 2 veces (faltan %s)" % str(scarce))
	var s: Dictionary = r.state
	var from_state := true
	for dim in R.VARIANTS:
		if str(s.world[dim]) != str(first[dim]):
			from_state = false
	t.ck(from_state, "el mundo de la partida es el de world_from_seed")
	var forced = t.new_rules(1817, {"variant": {"torre_en": "templo", "guardia": "atenta"}})
	t.ck(str(forced.state.world.torre_en) == "templo" and str(forced.state.world.guardia) == "atenta", "opts.variant fuerza una dimensión legal")
	var bad_variant = t.new_rules(1817, {"variant": {"torre_en": "marte"}})
	t.ck(str(bad_variant.state.world.torre_en) != "marte", "opts.variant ignora un valor ilegal")
	var traited = t.new_rules(1817, {"loot_traits": {"polvora": "humeda", "corral": "desbandado"}})
	t.ck(str(traited.state.world.loot_traits.polvora) == "humeda" and str(traited.state.world.loot_traits.corral) == "desbandado", "opts.loot_traits fuerza rasgos legales del botín")

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
		var spot: Vector2 = Vector2(568.0, 275.0) if fid == "posta" else t.hito(fid) + Vector2(-18.0, 6.0)  # a la vista de los centinelas (el patio de la posta tapa el resto; balance R2b: la guardia ve menos lejos)
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

# ---------------------------------------------------------------------------------------------------------------------
# H-R1-5: una parada fuera del mapa no deja una ruta fuera del mapa ni un guardado que no se pueda volver a abrir

func _map_size() -> Vector2:
	return Vector2(float(t.map.size_m.x), float(t.map.size_m.z))

func _units_path_inside_map(r: RefCounted, sz: Vector2) -> bool:
	for u in r.state.units:
		for p in u.path:
			if float(p.x) < 0.0 or float(p.x) > sz.x or float(p.z) < 0.0 or float(p.z) > sz.y:
				return false
	return true

func _test_waypoints_outside_map() -> void:
	if not t.real_only():
		return
	var sz := _map_size()
	var want := str(t.cfg.texts.errores.parada_fuera)
	var outside: Array = [Vector2(-60.0, 300.0), Vector2(sz.x + 60.0, 300.0), Vector2(450.0, -60.0), Vector2(450.0, sz.y + 60.0), Vector2(5000.0, 5000.0), Vector2(-0.5, 325.0),
		Vector2(sz.x + 0.5, 325.0), Vector2(300.0, sz.y + 0.01)]
	var counter := _counter_start()
	var wrong: Array = []
	var preview_wrong: Array = []
	var touched: Array = []
	var invalid: Array = []
	var cases := 0
	for pair in [["rodriguez", "move"], ["portal", "move"], ["arias", "move"], ["reconocedores", "move"], ["arreo", "move"], ["reconocedores", "recon"], ["portal", "position"], ["arias", "support"]]:
		var r = t.new_rules(1817, {"skip_intro": true})
		var u: Dictionary = t.unit_of(r, pair[0])
		var dest := Vector2(float(u.x) + 30.0, float(u.z) - 30.0)
		var before: String = t.snap_hash(r)
		for stop in outside:
			for stops in [[stop], [Vector2(300.0, 500.0), stop], [stop, Vector2(300.0, 500.0), Vector2(310.0, 510.0)]]:
				cases += 1
				var res: Dictionary = t.order(r, pair[0], pair[1], dest, {"waypoints": stops})
				if bool(res.get("ok", true)) or str(res.get("reason", "")) != want:
					wrong.append("%s %s %s: «%s»" % [pair[0], pair[1], str(stops), str(res.get("reason", ""))])
				var pre: Dictionary = t._dict(r.call("plan_route", pair[0], dest, {"waypoints": stops}))
				if bool(pre.get("ok", true)) or str(pre.get("reason", "")) != want:
					preview_wrong.append("%s %s: «%s»" % [pair[0], str(stops), str(pre.get("reason", ""))])
		if t.snap_hash(r) != before:
			touched.append(str(pair))
		if not bool(t._dict(r.call("validate_snapshot", r.call("snapshot"))).ok):
			invalid.append(str(pair))
	t.ck(wrong.is_empty(), "H-R1-5: %d órdenes con una parada fuera del mapa (cuatro lados, lejos y a medio metro del borde) se rechazan con «%s»; mal: %s" % [cases, want, str(wrong.slice(0, 3))])
	t.ck(preview_wrong.is_empty(), "...y la vista previa (plan_route) dice lo mismo: mal %s" % str(preview_wrong.slice(0, 3)))
	t.ck(touched.is_empty() and invalid.is_empty(), "...sin tocar el estado y con el estado siempre válido (tocaron: %s; inválidos: %s)" % [str(touched), str(invalid)])
	# las paradas sobre el borde y adentro se aceptan, el trayecto queda dentro del mapa y el guardado se puede volver a abrir
	var good = t.new_rules(1817, {"skip_intro": true})
	var gu: Dictionary = t.unit_of(good, "portal")
	var inside_stops: Array = [Vector2(0.0, 560.0), Vector2(120.0, sz.y), Vector2(300.0, 500.0)]
	var accepted: Dictionary = t.order(good, "portal", "move", Vector2(float(gu.x) + 40.0, float(gu.z) - 20.0), {"waypoints": inside_stops})
	t.ck(bool(accepted.get("ok", false)), "tres paradas, una sobre el borde oeste y otra sobre el sur, se aceptan: %s" % str(accepted.get("reason", "")))
	var pts_ok := _units_path_inside_map(good, sz)
	t.ck(pts_ok and bool(t._dict(good.call("validate_snapshot", good.call("snapshot"))).ok), "...el trayecto queda dentro del mapa y el estado es válido")
	t.ck(good.call("save_game", t.SAVE_PATH) == OK and bool(t._dict(t.new_rules(1817, {"skip_intro": true}).call("load_game", t.SAVE_PATH)).get("ok", false)), "...y F5 y F9 funcionan: el guardado se vuelve a abrir")
	good.call("tick", 30.0)
	t.ck(bool(t._dict(good.call("validate_snapshot", good.call("snapshot"))).ok), "...y sigue válido 30 s después")
	# las órdenes que no recorren paradas (sostener, cancelar) no se rechazan por una parada que no usan
	var hold: Dictionary = t.order(good, "arias", "hold", Vector2.ZERO, {"waypoints": [Vector2(-60.0, 300.0)]})
	t.ck(bool(hold.get("ok", false)), "«sostener» con una parada afuera del mapa no se rechaza: no usa paradas (%s)" % str(hold.get("reason", "")))
	# más de cuatro paradas: la orden y la vista previa dicen lo mismo
	var five: Array = [Vector2(100.0, 500.0), Vector2(110.0, 500.0), Vector2(120.0, 500.0), Vector2(130.0, 500.0), Vector2(140.0, 500.0)]
	var many: Dictionary = t.order(good, "arias", "move", Vector2(300.0, 560.0), {"waypoints": five})
	var many_preview: Dictionary = t._dict(good.call("plan_route", "arias", Vector2(300.0, 560.0), {"waypoints": five}))
	var many_text := str(t.cfg.texts.errores.paradas)
	t.ck(not bool(many.get("ok", true)) and str(many.get("reason", "")) == many_text and not bool(many_preview.get("ok", true)) and str(many_preview.get("reason", "")) == many_text, "cinco paradas se rechazan igual en la orden y en la vista previa: «%s»" % str(many.get("reason", "")))
	# la red de seguridad: aunque alguien le pida a la ruta un punto de afuera, la ruta no sale del mapa
	var net = t.new_rules(1817, {"skip_intro": true})
	var route: Dictionary = net.call("_route", Vector2(70.0, 470.0), [Vector2(-60.0, 300.0), Vector2(sz.x + 60.0, 700.0)], Vector2(500.0, 400.0))
	var net_ok := bool(route.ok)
	for p in route.pts:
		if (p as Vector2).x < 0.0 or (p as Vector2).x > sz.x or (p as Vector2).y < 0.0 or (p as Vector2).y > sz.y:
			net_ok = false
	t.ck(net_ok, "la ruta recorta cualquier punto que pida afuera del mapa: ningún punto de la ruta sale de %s" % str(sz))
	# y si un defecto dejara el estado en un punto que no se puede volver a abrir, F5 no escribe nada: ni «Partida guardada» ni un archivo que F9 rechace
	var broken = t.new_rules(1817, {"skip_intro": true})
	broken.call("save_game", t.SAVE_PATH)
	var kept := FileAccess.get_file_as_string(t.SAVE_PATH)
	broken.state.units[0].path = [{"x": -60.0, "z": 300.0}]
	var refused: Variant = broken.call("save_game", t.SAVE_PATH)
	t.ck(refused != OK and FileAccess.get_file_as_string(t.SAVE_PATH) == kept and not FileAccess.file_exists(t.SAVE_PATH + ".tmp"), "save_game se niega a guardar un estado que validate_snapshot rechazaría (devuelve un error y no toca el archivo anterior)")
	_counter_stop(counter)
	t.ck(counter.script_errors == 0 and counter.errors == 0, "...sin errores de script (%d) ni de otro tipo (%d) del motor: %s" % [counter.script_errors, counter.errors, counter.last])

# ---------------------------------------------------------------------------------------------------------------------
# H-R1-6: un guardado con un dato de otro tipo se rechaza con motivo; nunca revienta al cargar ni al jugar

func _json_kind(v: Variant) -> String:
	if v == null:
		return "null"
	if v is bool:
		return "bool"
	if v is int or v is float:
		return "num"
	if v is String:
		return "str"
	if v is Array:
		return "arr"
	if v is Dictionary:
		return "dict"
	return "otro"

## Todos los nodos (hojas y contenedores) de un guardado. Con `sample` de cada arreglo se miran solo los tres primeros elementos y el último: los arreglos del guardado son
## homogéneos (el esquema les pide a todos los elementos lo mismo), así que el cuarto registro del diario de a bordo no enseña nada que no enseñe el primero.
func _nodes(v: Variant, path: Array, out: Array, sample: bool = false) -> void:
	out.append(path)
	if v is Dictionary:
		for k in v:
			_nodes(v[k], path + [k], out, sample)
	elif v is Array:
		var n := (v as Array).size()
		for i in range(n):
			if sample and i >= 3 and i != n - 1:
				continue
			_nodes(v[i], path + [i], out, sample)

func _node_at(d: Variant, path: Array) -> Variant:
	var cur: Variant = d
	for k in path:
		cur = cur[k]
	return cur

func _node_put(d: Variant, path: Array, val: Variant) -> void:
	var cur: Variant = d
	for i in range(path.size() - 1):
		cur = cur[path[i]]
	cur[path[path.size() - 1]] = val

func _node_drop(d: Variant, path: Array) -> void:
	var cur: Variant = d
	for i in range(path.size() - 1):
		cur = cur[path[i]]
	var last: Variant = path[path.size() - 1]
	if cur is Dictionary:
		(cur as Dictionary).erase(last)
	else:
		(cur as Array).remove_at(int(last))

## Devuelve al nodo lo que _node_drop le sacó (un arreglo vuelve a su lugar; una clave de objeto, al final).
func _node_restore(d: Variant, path: Array, old: Variant) -> void:
	var cur: Variant = d
	for i in range(path.size() - 1):
		cur = cur[path[i]]
	var last: Variant = path[path.size() - 1]
	if cur is Dictionary:
		(cur as Dictionary)[last] = old
	else:
		(cur as Array).insert(int(last), old)

func _node_pattern(path: Array) -> String:
	var parts: Array = []
	for k in path:
		parts.append("*" if k is int else str(k))
	return ".".join(PackedStringArray(parts))

func _fuzz_value(kind: String, old: Variant) -> Variant:
	match kind:
		"null":
			return null
		"str":
			return "texto"
		"arr":
			return [1, 2, 3]
		"dict":
			return {}
		"neg":
			return -1
		"huge":
			return 1e300
		"bool":
			return (not old) if old is bool else true
	return null

## Los estados de partida sobre los que se muta: cada uno tiene contenido distinto (órdenes en marcha, trabajo, torre disparando, carga, un final).
func _fuzz_bases() -> Array:
	var out: Array = []
	var attack = t.new_rules(1817, {"skip_intro": true, "phase": "ataque"})
	attack.call("advance_to", float(attack.state.elapsed) + 45.0)
	out.append(["ataque_45s", attack.call("snapshot")])
	var loading = t.new_rules(1817, {"skip_intro": true})
	var mem := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var found := false
	var guard := 0
	while str(loading.state.status) == "playing" and guard < 900 and not found:
		guard += 1
		t.pol.call("step", loading, "experto", mem, rng)
		if str(loading.state.phase) == "extraccion":
			for u in loading.state.units:
				if str(u.stage) == "loading" and not (u.work as Dictionary).is_empty():
					found = true
	out.append(["extraccion_cargando", loading.call("snapshot")])
	if _heavy():
		var approach = t.new_rules(1817, {"skip_intro": true})
		var mem_a := {}
		for i in range(70):
			t.pol.call("step", approach, "experto", mem_a, rng)
		out.append(["aproximacion_70s", approach.call("snapshot")])
		var won = t.new_rules(1817, {"skip_intro": true})
		t.pol.call("play", won, "experto", {})
		out.append(["fin_victoria", won.call("snapshot")])
		var lost = t.new_rules(1817, {"skip_intro": true})
		t.pol.call("play", lost, "pasivo", {})
		out.append(["fin_derrota", lost.call("snapshot")])
		var late = t.new_rules(1817, {"skip_intro": true, "phase": "extraccion"})
		late.call("advance_to", float(late.state.elapsed) + 20.0)
		out.append(["extraccion_20s", late.call("snapshot")])
	return out

## La mutación de tipo sobre CADA nodo (hoja o contenedor) de varios guardados, con las ocho clases del revisor técnico. Exige: (1) todo rechazo trae motivo; (2) ninguna mutación que
## cambia el tipo de un dato se acepta; (3) nada revienta (SCRIPT ERROR) al validar, ni al jugar lo aceptado, ni al consultar el estado; (4) lo aceptado sigue siendo válido al jugarlo.
func _test_save_type_fuzz() -> void:
	if not t.real_only() or t.pol == null:
		return
	var play_s := 120 if _heavy() else 20
	var counter := _counter_start()
	var judge = t.new_rules(1817, {"skip_intro": true})
	var tally := {"bases": 0, "nodos": 0, "intentos": 0, "rechazadas": 0, "aceptadas": 0, "aceptadas_jugadas": 0, "cambio_de_tipo_aceptado": 0, "sin_motivo": 0}
	var type_slips: Array = []
	var breaks: Array = []
	var invalid_after: Array = []
	var played := {}
	for pair in _fuzz_bases():
		var snap: Dictionary = pair[1]
		var base: Dictionary = JSON.parse_string(JSON.stringify(snap, "", true, true))  # como llega de un archivo: los números son decimales
		if not bool(t._dict(judge.call("validate_snapshot", base)).ok):
			breaks.append("la base %s no pasa validate_snapshot: %s" % [pair[0], str(judge.call("validate_snapshot", base))])
			continue
		tally.bases += 1
		var nodes: Array = []
		_nodes(base, [], nodes, not _heavy())
		tally.nodos += nodes.size()
		for path in nodes:
			if (path as Array).is_empty():
				continue
			var old: Variant = _node_at(base, path)
			var pat := _node_pattern(path)
			for kind in FUZZ_KINDS:
				var d: Dictionary = base  # se muta en el lugar y se restaura: copiar el guardado entero 12 000 veces costaba la mitad del tiempo
				var new_value: Variant = _fuzz_value(str(kind), old)
				if kind == "del":
					_node_drop(d, path)
				else:
					_node_put(d, path, new_value)
				tally.intentos += 1
				var res: Dictionary = t._dict(judge.call("validate_snapshot", d))
				var accepted_copy: Dictionary = {}
				if bool(res.get("ok", false)):
					accepted_copy = d.duplicate(true)
				if kind == "del":
					_node_restore(d, path, old)
				else:
					_node_put(d, path, old)
				if accepted_copy.is_empty():
					tally.rechazadas += 1
					if str(res.get("reason", "")).strip_edges() == "":
						tally.sin_motivo += 1
					continue
				tally.aceptadas += 1
				if kind != "del" and _json_kind(old) != _json_kind(new_value):
					tally.cambio_de_tipo_aceptado += 1
					type_slips.append("%s: %s <- %s" % [pair[0], pat, kind])
				var tag := "%s: %s <- %s" % [pair[0], pat, kind]
				var once := tag if _heavy() else "%s <- %s" % [pat, kind]  # en la compuerta rápida alcanza con jugar cada clase de mutación aceptada una vez
				if played.has(once):
					continue
				played[once] = true
				var rl = t.rules_script.new()
				var back: Dictionary = t._dict(rl.call("restore_snapshot", accepted_copy))
				if not bool(back.get("ok", false)):
					breaks.append("restore_snapshot rechaza lo que validate_snapshot aceptó: " + tag)
					continue
				tally.aceptadas_jugadas += 1
				var mem := {}
				var rng := RandomNumberGenerator.new()
				rng.seed = 12345
				var before_errors := counter.script_errors
				for s in range(play_s):
					if str(rl.state.status) != "playing":
						break
					t.pol.call("step", rl, "experto", mem, rng)
				rl.call("hud_state")
				rl.call("render_state")
				rl.call("campaign_report")
				if counter.script_errors != before_errors:
					breaks.append("%s revienta al jugarlo: %s" % [tag, counter.last])
				if not bool(t._dict(rl.call("validate_snapshot", rl.call("snapshot"))).ok):
					invalid_after.append(tag)
	_counter_stop(counter)
	t.suite.extra["guardado_fuzz"] = {"bases": tally.bases, "nodos": tally.nodos, "mutaciones": tally.intentos, "rechazadas": tally.rechazadas, "aceptadas": tally.aceptadas,
		"aceptadas_jugadas": tally.aceptadas_jugadas, "segundos_jugados_cada_una": play_s, "script_errors": counter.script_errors}
	t.ck(tally.bases >= (6 if _heavy() else 2) and tally.intentos >= (30000 if _heavy() else 5000), "H-R1-6: el fuzz de tipos prueba %d mutaciones sobre %d nodos de %d guardados (ocho clases por nodo)" % [tally.intentos, tally.nodos, tally.bases])
	t.ck(tally.sin_motivo == 0, "...todo rechazo trae un motivo escrito (%d sin motivo de %d rechazos)" % [tally.sin_motivo, tally.rechazadas])
	t.ck(tally.cambio_de_tipo_aceptado == 0, "...ninguna mutación que cambia el tipo de un dato se acepta (se colaron %d: %s)" % [tally.cambio_de_tipo_aceptado, str(type_slips.slice(0, 4))])
	t.ck(float(tally.rechazadas) / maxf(float(tally.intentos), 1.0) >= 0.9, "...el esquema rechaza al menos el 90 %% de las mutaciones (rechazó %.1f %%)" % (100.0 * float(tally.rechazadas) / maxf(float(tally.intentos), 1.0)))
	t.ck(breaks.is_empty() and counter.script_errors == 0, "...0 errores de script al validar, y al jugar %d s lo aceptado (%d guardados): %s" % [play_s, tally.aceptadas_jugadas, str(breaks.slice(0, 3))])
	t.ck(invalid_after.is_empty(), "...y lo aceptado sigue siendo un estado válido después de jugarlo (inválidos: %s)" % str(invalid_after.slice(0, 3)))
	t.ck(counter.errors == 0, "...y el motor no imprimió ningún otro error durante el fuzz (%d)" % counter.errors)

## Los casos concretos de H-R1-6 (los del QA y los de su revisión técnica) y sus parientes: cada uno se rechaza con motivo, con la ruta técnica del dato, sin errores de
## script y sin tocar la partida en curso; además, load_game devuelve un resultado (antes devolvía nada y reventaba).
func _schema_cases() -> Array:
	return [
		["escenario: lista", func(d): d.scenario = [1, 2, 3]], ["escenario: número", func(d): d.scenario = 7], ["escenario: nulo", func(d): d.scenario = null],
		["escenario: objeto", func(d): d.scenario = {}], ["map_id de otro mapa", func(d): d.map_id = "norte"], ["game_id numérico", func(d): d.game_id = 5],
		["reason nulo", func(d): d.reason = null], ["resistencia texto", func(d): d.resistencia = "si"], ["previous_game_id numérico", func(d): d.previous_game_id = 5],
		["rumbo nulo", func(d): d.units[0].yaw_deg = null], ["rumbo texto", func(d): d.units[0].yaw_deg = "norte"], ["rumbo lista", func(d): d.units[0].yaw_deg = []],
		["postura numérica", func(d): d.units[0].order = {"action": "attack", "front": "bateria", "posture": 7}],
		["postura inventada", func(d): d.units[0].order = {"action": "attack", "front": "bateria", "posture": "texto"}],
		["orden con un frente inventado", func(d): d.units[0].order = {"action": "attack", "front": "luna"}],
		["torre activa como texto", func(d): d.objectives.cuartel.tower.active = "x"], ["torre armada como lista", func(d): d.objectives.cuartel.tower.armed = []],
		["descargas nulas", func(d): d.objectives.cuartel.tower.volleys_left = null], ["próxima descarga texto", func(d): d.objectives.cuartel.tower.next_volley_at = "x"],
		["lote sin frente", func(d): d.loot.items[0].front = null], ["lote de un frente inventado", func(d): d.loot.items[0].front = "luna"],
		["lote de una clase sin reglas (ganado)", func(d): d.loot.items[0].kind = "ganado"], ["lote con clase numérica", func(d): d.loot.items[0].kind = 3],
		["lote con cantidad texto", func(d): d.loot.items[0].qty = "x"], ["lote con x nula", func(d): d.loot.items[0].x = null], ["lote con estado inventado", func(d): d.loot.items[0].state = "roto"],
		["lote sin su frente (falta la clave)", func(d): d.loot.items[0].erase("front")],
		["detecciones nulas", func(d): d.stats.detections = null], ["bajas como lista", func(d): d.stats.losses = []], ["ritmo como lista", func(d): d.stats.pacing = []],
		["primera decisión nula", func(d): d.stats.pacing.first_decision_s = null], ["fuerzas iniciales como lista", func(d): d.stats.start_strength = []],
		["fuerza inicial de Arias como texto", func(d): d.stats.start_strength.arias = "x"], ["falta la fuerza inicial de Arias", func(d): d.stats.start_strength.erase("arias")],
		["trabajo como lista", func(d): d.units[2].work = []], ["trabajo sin tiempo", func(d): d.units[2].work = {"kind": "load"}],
		["carga sin decir cuál", func(d): d.units[2].work = {"kind": "load", "remaining_s": 5.0}], ["trabajo de una clase inventada", func(d): d.units[2].work = {"kind": "volar", "remaining_s": 5.0}],
		["trayecto con x texto", func(d): d.units[0].path = [{"x": "a", "z": 1.0}]], ["trayecto como texto", func(d): d.units[0].path = "x"], ["falta el trabajo de una agrupación", func(d): d.units[0].erase("work")],
		["mensajero inventado", func(d): d.alarm.messenger = "paloma"], ["señal numérica", func(d): d.alarm.signaled = 1], ["alarma previa a un frente inventado", func(d): d.alarm.pre_signal = ["luna"]],
		["lo conocido como texto", func(d): d.world.known = "x"], ["rumores numéricos", func(d): d.world.rumors = 5], ["plata como texto", func(d): d.world.loot_traits.plata = "si"],
		["registro con texto numérico", func(d): d.log = [{"text": 5}]], ["registro de una clase inventada", func(d): d.log[0].kind = "inventado"], ["órdenes numéricas", func(d): d.orders = [1]],
		["líneas de fuego vacías", func(d): d.fire_lines = [{}]], ["desenlace como lista", func(d): d.outcome = []], ["lo reconocido como texto", func(d): d.recon.fronts = "x"],
		["ayudas numéricas", func(d): d.assists = [1]], ["marcas con x texto", func(d): d.diary_marks = [{"key": "a", "kind": "b", "text": "c", "x": "a", "z": 1.0, "confirmed": false}]],
		["ritmo previo nulo", func(d): d.pacing_last = null], ["reloj enorme", func(d): d.elapsed = 1e300], ["x de una agrupación texto", func(d): d.units[0].x = "a"], ["rng en cero", func(d): d.rng_state = 0],
		["semilla con decimales", func(d): d.seed = 1.5], ["intento cero", func(d): d.attempt = 0], ["guarnición mayor que su máximo", func(d): d.objectives.bateria.garrison = float(d.objectives.bateria.garrison_max) + 5.0],
		["torre que dispara sin estar armada", func(d): d.objectives.cuartel.tower.armed = false; d.objectives.cuartel.tower.active = true],
		["desenlace vacío con la partida terminada", func(d): d.status = "defeat"; d.reason = "plazo"; d.phase = "epilogo"]]

func _test_save_schema_cases() -> void:
	if not t.real_only():
		return
	var counter := _counter_start()
	var r = t.new_rules(1817, {"phase": "ataque"})
	r.call("advance_to", float(r.state.elapsed) + 45.0)
	var good: Dictionary = r.call("snapshot")
	var cases := _schema_cases()
	var before: String = t.snap_hash(r)
	var accepted: Array = []
	var no_reason: Array = []
	var no_path: Array = []
	var jargon: Array = []
	var snake := RegEx.new()
	snake.compile("[a-z]+_[a-z]+")
	var semantic_only := ["carga sin decir cuál", "guarnición mayor que su máximo", "torre que dispara sin estar armada", "desenlace vacío con la partida terminada"]
	for c in cases:
		var d: Dictionary = good.duplicate(true)
		c[1].call(d)
		var res: Dictionary = t._dict(r.call("validate_snapshot", d))
		if bool(res.get("ok", true)):
			accepted.append(c[0])
			continue
		var why := str(res.get("reason", ""))
		if why.strip_edges() == "":
			no_reason.append(c[0])
		if snake.search(why) != null:
			jargon.append("%s: «%s»" % [c[0], why])
		if str(res.get("path", "")) == "" and not semantic_only.has(c[0]) and str(c[0]).find("escenario") < 0:
			no_path.append(c[0])
	t.ck(accepted.is_empty(), "H-R1-6: ninguno de los %d guardados con un dato de otro tipo o de otra forma se acepta (se coló: %s)" % [cases.size(), str(accepted)])
	t.ck(no_reason.is_empty() and jargon.is_empty(), "...todos con un motivo escrito y sin nombres de campo en el texto (sin motivo: %s; con jerga: %s)" % [str(no_reason), str(jargon.slice(0, 2))])
	t.ck(no_path.is_empty(), "...y los de tipo o de forma traen la ruta técnica del dato (sin ruta: %s)" % str(no_path))
	t.ck(counter.script_errors == 0, "...sin ningún SCRIPT ERROR al validarlos (%d): %s" % [counter.script_errors, counter.last])
	t.ck(t.snap_hash(r) == before, "...y la partida en curso queda intacta")
	# el motivo nombra la sección con palabras comunes
	var d_units: Dictionary = good.duplicate(true)
	d_units.units[0].yaw_deg = null
	var d_loot: Dictionary = good.duplicate(true)
	d_loot.loot.items[0].front = null
	var d_gone: Dictionary = good.duplicate(true)
	d_gone.alarm.erase("level")
	var why_units := str(t._dict(r.call("validate_snapshot", d_units)).get("reason", ""))
	var why_loot := str(t._dict(r.call("validate_snapshot", d_loot)).get("reason", ""))
	var why_gone := str(t._dict(r.call("validate_snapshot", d_gone)).get("reason", ""))
	t.ck(why_units.find("las agrupaciones") >= 0 and why_loot.find("el botín") >= 0 and why_gone.find("la alarma") >= 0 and why_gone.find("incompleto") >= 0, "...el motivo nombra la sección dañada con palabras comunes: «%s», «%s» y «%s»" % [why_units, why_loot, why_gone])
	# load_game: el resultado existe y es un rechazo (antes la validación reventaba y load_game no devolvía nada)
	var file_names: Array = ["escenario: lista", "escenario: número", "escenario: nulo", "escenario: objeto", "rumbo nulo", "torre activa como texto", "postura numérica",
		"lote sin frente", "lote de una clase sin reglas (ganado)", "trayecto con x texto"]
	var file_cases: Array = []
	for i in range(cases.size()):
		if file_names.has(cases[i][0]):
			file_cases.append(i)
	t.ck(file_cases.size() == file_names.size(), "los %d casos que se prueban por archivo existen en la lista" % file_names.size())
	var load_bad: Array = []
	for i in file_cases:
		var dd: Dictionary = good.duplicate(true)
		cases[i][1].call(dd)
		t._cleanup_files()
		var f := FileAccess.open(t.SAVE_PATH, FileAccess.WRITE)
		f.store_string(JSON.stringify(dd))
		f.close()
		var loaded: Variant = r.call("load_game", t.SAVE_PATH)
		if not (loaded is Dictionary) or not (loaded as Dictionary).has("ok") or bool((loaded as Dictionary).ok) or str((loaded as Dictionary).get("reason", "")) == "" or t.snap_hash(r) != before:
			load_bad.append(str(cases[i][0]))
	t.ck(load_bad.is_empty(), "load_game de un guardado con datos de otro tipo (%d archivos) devuelve {ok: false, motivo} y no toca la partida: mal %s" % [file_cases.size(), str(load_bad)])
	_counter_stop(counter)
	t.ck(counter.script_errors == 0 and counter.errors == 0, "...en total 0 errores del motor (script %d, otros %d): %s" % [counter.script_errors, counter.errors, counter.last])
	# un guardado de la Justina o del Norte sigue diciendo de qué escenario es, aunque no tenga la forma de este nivel
	var foreign: Dictionary = {"scenario": "justine", "state": {}}
	t.ck(String(t._dict(r.call("validate_snapshot", foreign)).get("reason", "")).find("otro escenario") >= 0, "un guardado de la Justina sin la forma de este nivel dice «otro escenario» y no «dañado»")

# ---------------------------------------------------------------------------------------------------------------------
# Lo válido nunca se rechaza: partidas enteras con todas las políticas, validadas cada pocos segundos, y la cobertura de claves del esquema

func _collect_paths(v: Variant, path: String, seen: Dictionary) -> void:
	if v is Dictionary:
		for k in v:
			var p: String = str(k) if path == "" else path + "." + str(k)
			seen[p] = true
			_collect_paths(v[k], p, seen)
	elif v is Array:
		for it in v:
			_collect_paths(it, path, seen)

func _test_valid_states_everywhere() -> void:
	if not t.real_only() or t.pol == null:
		return
	var counter := _counter_start()
	var seeds: Array = [3, 7, 13]
	var policies: Array = ["experto", "obediente", "aleatorio", "pasivo"]
	if _heavy():  # las ocho semillas de calibración y ocho de la compuerta, con las siete políticas que juegan
		seeds = [3, 5, 7, 11, 13, 17, 19, 23, 29, 37, 47, 61, 73, 107, 131, 157]
		policies = ["experto", "obediente", "torpe", "aleatorio", "pasivo", "pausa_reanuda", "barrido_senal"]
	var seen := {}
	var checks := 0
	var failures: Array = []
	var games := 0
	for sd in seeds:
		for policy in policies:
			var r = t.new_rules(int(sd), {"skip_intro": true})
			var mem := {}
			var rng := RandomNumberGenerator.new()
			rng.seed = int(sd) * 31 + 7
			var guard := 0
			var next_check := 0.0
			while str(r.state.status) == "playing" and float(r.state.elapsed) < 845.0 and guard < 4000:
				guard += 1
				t.pol.call("step", r, policy, mem, rng)
				if float(r.state.elapsed) >= next_check:
					next_check += 5.0
					checks += 1
					var res: Dictionary = t._dict(r.call("validate_snapshot", r.state))
					if not bool(res.get("ok", false)):
						failures.append("semilla %d %s a los %.0f s: %s (%s)" % [int(sd), policy, float(r.state.elapsed), str(res.get("reason", "")), str(res.get("path", ""))])
					if checks % 12 == 0:
						_collect_paths(r.state, "", seen)
			checks += 1
			if not bool(t._dict(r.call("validate_snapshot", r.call("snapshot"))).ok):
				failures.append("semilla %d %s al final" % [int(sd), policy])
			_collect_paths(r.state, "", seen)
			games += 1
	_counter_stop(counter)
	var known := {}
	for p in Schema.known_paths(_map_size()):
		known[p] = true
	var uncovered: Array = []
	for p in seen:
		if not known.has(p):
			uncovered.append(p)
	uncovered.sort()
	var never: Array = []
	for p in known:
		if not seen.has(p):
			never.append(p)
	never.sort()
	t.suite.extra["esquema"] = {"claves_del_esquema": known.size(), "claves_vistas_en_partidas": seen.size(), "claves_sin_esquema": uncovered, "claves_opcionales_no_vistas": never, "estados_validados": checks}
	t.ck(failures.is_empty(), "el esquema aprueba los %d estados de %d partidas jugadas por %d políticas, uno cada 5 s y el final (falsos rechazos: %s)" % [checks, games, policies.size(), str(failures.slice(0, 3))])
	t.ck(uncovered.is_empty(), "toda clave que el estado llega a tener figura en el esquema (sin esquema: %s)" % str(uncovered))
	t.ck(known.size() > 100 and float(never.size()) < 0.25 * float(known.size()), "...y las partidas pasan por la gran mayoría de las claves del esquema (%d de %d; sin ver: %s)" % [known.size() - never.size(), known.size(), str(never.slice(0, 6))])
	t.ck(counter.script_errors == 0, "...sin errores de script jugando esas partidas (%d)" % counter.script_errors)

# ---------------------------------------------------------------------------------------------------------------------
# Órdenes con basura: ninguna deja el estado inválido ni rompe nada (el pariente de H-R1-5)

func _rand_point(sz: Vector2) -> Vector2:
	match int(_lcg() * 5.0):
		0:
			return Vector2(_lcg_range(0.0, sz.x), _lcg_range(0.0, sz.y))
		1:
			return Vector2(float(_lcg_pick([0.0, sz.x])), _lcg_range(0.0, sz.y)) if _lcg() < 0.5 else Vector2(_lcg_range(0.0, sz.x), float(_lcg_pick([0.0, sz.y])))
		2:
			return Vector2(_lcg_range(-200.0, sz.x + 200.0), _lcg_range(-200.0, sz.y + 200.0))
		3:
			return Vector2.ZERO
	return t.hito(str(_lcg_pick(["posta", "vado_este", "salida_este", "bateria", "cuartel", "polvorin", "corral_posta", "entrada_sur"])))

func _test_order_fuzz() -> void:
	if not t.real_only():
		return
	var sz := _map_size()
	var counter := _counter_start()
	var actors: Array = V.GROUPS.duplicate()
	actors.append("nadie")
	var actions: Array = ["move", "position", "attack", "support", "recon", "load", "destroy", "leave", "hold", "cancel", "give_signal", "hackear", "retreat", "bring", "move", "move", "recon"]
	var phases: Array = ["aproximacion", "ataque", "extraccion"]
	var games := 9 if _heavy() else 3
	var per_game := 140 if _heavy() else 70
	var orders := 0
	var accepted_orders := 0
	var malformed: Array = []
	var invalid: Array = []
	var outside_paths := 0
	for g in range(games):
		_lcg_seed(101 + 2 * g)
		var r = t.new_rules(101 + 2 * g, {"skip_intro": true, "phase": phases[g % phases.size()]})
		for i in range(per_game):
			if str(r.state.status) != "playing":
				break
			var actor := str(_lcg_pick(actors))
			var action := str(_lcg_pick(actions))
			var opts := {}
			if _lcg() < 0.5:
				var stops: Array = []
				for k in range(int(_lcg() * 7.0)):
					stops.append(_rand_point(sz))
				opts["waypoints"] = stops
			if _lcg() < 0.2:
				opts["waypoints"] = _lcg_pick(["basura", 5, null, [{"x": 1, "z": 2}, "x", null], {}])
			if _lcg() < 0.3:
				opts["pace"] = _lcg_pick(R.PACES + ["volando", "", 3])
			if _lcg() < 0.3:
				opts["posture"] = _lcg_pick(R.POSTURES + ["x", 7, null])
			if _lcg() < 0.3:
				opts["front"] = _lcg_pick(V.OBJECTIVES + ["x", "", 4])
			if _lcg() < 0.3:
				var ids: Array = ["x", "", 5]
				for it in r.state.loot.items:
					ids.append(str(it.id))
				opts["item"] = _lcg_pick(ids)
			if _lcg() < 0.2:
				opts["approach"] = _lcg_pick(["frontal", "gola", "calle", "x", 3])
			if _lcg() < 0.1:
				opts["qty"] = _lcg_pick([-1, 0, 5, 1000000000, "x"])
			var res: Variant = r.call("issue_order", actor, action, _rand_point(sz), opts)
			orders += 1
			if not (res is Dictionary) or not (res as Dictionary).has("ok") or not ((res as Dictionary).ok is bool) or (not bool((res as Dictionary).ok) and str((res as Dictionary).get("reason", "")) == ""):
				malformed.append("%s %s %s -> %s" % [actor, action, str(opts).left(60), str(res).left(60)])
			elif bool((res as Dictionary).ok):
				accepted_orders += 1
			if _lcg() < 0.15:
				r.call("plan_route", actor, _rand_point(sz), opts)
				r.call("plan_recon", actor, [_rand_point(sz), _rand_point(sz)], opts)
			if _lcg() < 0.07:
				r.call("undo_last")
			var check: Dictionary = t._dict(r.call("validate_snapshot", r.call("snapshot")))
			if not bool(check.get("ok", false)):
				invalid.append("%s %s %s -> %s (%s)" % [actor, action, str(opts).left(80), str(check.get("reason", "")), str(check.get("path", ""))])
			if not _units_path_inside_map(r, sz):
				outside_paths += 1
			if _lcg() < 0.5:
				r.call("tick", _lcg_range(0.5, 6.0))
				r.call("hud_state")
				r.call("render_state")
	_counter_stop(counter)
	t.suite.extra["fuzz_de_ordenes"] = {"partidas": games, "ordenes": orders, "aceptadas": accepted_orders, "estados_invalidos": invalid.size()}
	t.ck(orders >= (600 if _heavy() else 150), "H-R1-5: %d órdenes con basura (paradas dentro y fuera del mapa, opciones de otro tipo, acciones inexistentes) sobre %d partidas, %d aceptadas" % [orders, games, accepted_orders])
	t.ck(malformed.is_empty(), "...cada orden devuelve {ok, motivo} (mal: %s)" % str(malformed.slice(0, 3)))
	t.ck(invalid.is_empty() and outside_paths == 0, "...y después de cada una validate_snapshot(snapshot()) da ok y ningún trayecto sale del mapa (inválidos: %s; fuera: %d)" % [str(invalid.slice(0, 2)), outside_paths])
	t.ck(counter.script_errors == 0 and counter.errors == 0, "...sin errores del motor (script %d, otros %d): %s" % [counter.script_errors, counter.errors, counter.last])

# ---------------------------------------------------------------------------------------------------------------------
# Los archivos de progreso y de puntos de control dañados nunca bloquean ni revientan

func _write_text(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()

func _test_progress_files_hostile() -> void:
	if not t.real_only():
		return
	var counter := _counter_start()
	var entry := {"attempt": 1, "kind": "amanecio", "text": "Amaneció.", "x": 318.0, "z": 350.0, "tag": "diseno"}
	var base := {"version": 1, "attempts": 2, "defeats_in_row": 1, "best_medal": "", "won": false, "best_golpe": 0.0, "world_index": 0, "tutorial_seen": false, "diary": [entry]}
	var variants: Array = [
		["diario con x nula", func(d): d.diary[0].x = null], ["diario con x texto", func(d): d.diary[0].x = "abc"], ["diario con z lista", func(d): d.diary[0].z = []],
		["diario con x fuera del mapa", func(d): d.diary[0].x = 1e9], ["diario sin texto", func(d): d.diary[0].erase("text")], ["diario con texto numérico", func(d): d.diary[0].text = 5],
		["diario con intento lista", func(d): d.diary[0].attempt = [1]], ["diario con etiqueta numérica", func(d): d.diary[0].tag = 5], ["diario como texto", func(d): d.diary = "x"],
		["diario con un elemento nulo", func(d): d.diary = [null]], ["intentos nulos", func(d): d.attempts = null], ["mejor golpe lista", func(d): d.best_golpe = []],
		["medalla inventada", func(d): d.best_medal = "platino"], ["ganó como texto", func(d): d.won = "si"]]
	var bad: Array = []
	for v in variants:
		var d: Dictionary = base.duplicate(true)
		v[1].call(d)
		_write_text(PROGRESS_FILE, JSON.stringify(d))
		var p = t.progress_script.new(PROGRESS_FILE, CHECKPOINT_PATH)
		var ok: bool = p.call("load_progress")
		if ok or str(p.load_note) == "" or int(p.attempts) != 0 or not (p.call("diary_marks") is Array):
			bad.append(str(v[0]))
	t.ck(bad.is_empty(), "un progreso con un dato de otro tipo (%d variantes) se descarta con una nota y se empieza de cero, sin bloquear: mal %s" % [variants.size(), str(bad)])
	_write_text(PROGRESS_FILE, JSON.stringify(base))
	var sane = t.progress_script.new(PROGRESS_FILE, CHECKPOINT_PATH)
	var loaded: bool = sane.call("load_progress")
	var marks: Array = sane.call("diary_marks")
	t.ck(loaded and int(sane.attempts) == 2 and marks.size() == 1 and float(marks[0].x) == 318.0, "...y el mismo progreso sano se lee y arma su marca del diario")
	# puntos de control
	var snap_ok: Dictionary = t.new_rules(1817, {"skip_intro": true}).call("snapshot")
	var cp_variants: Array = [
		["tiempo nulo", {"version": 1, "points": {"posiciones": {"time": null, "state": snap_ok}}}], ["tiempo lista", {"version": 1, "points": {"posiciones": {"time": [1], "state": snap_ok}}}],
		["punto como texto", {"version": 1, "points": {"posiciones": "x"}}], ["puntos como lista", {"version": 1, "points": []}], ["versión lista", {"version": [1], "points": {}}],
		["versión nula", {"version": null, "points": {"posiciones": {"time": 5.0, "state": snap_ok}}}], ["estado lista", {"version": 1, "points": {"posiciones": {"time": 5.0, "state": []}}}],
		["estado de otro tipo de datos", {"version": 1, "points": {"posiciones": {"time": 5.0, "state": {"scenario": [1, 2]}}}}], ["raíz lista", [1, 2, 3]]]
	var cp_bad: Array = []
	for c in cp_variants:
		_write_text(CHECKPOINT_PATH, JSON.stringify(c[1]))
		var q = t.progress_script.new(PROGRESS_FILE, CHECKPOINT_PATH)
		var rr = t.new_rules(1817, {"skip_intro": true})
		var before: String = t.snap_hash(rr)
		var back: Dictionary = t._dict(q.call("restore_checkpoint", rr, "posiciones"))
		if bool(back.get("ok", false)) or str(back.get("reason", "")) == "" or t.snap_hash(rr) != before:
			cp_bad.append(str(c[0]))
	t.ck(cp_bad.is_empty(), "un archivo de puntos de control dañado (%d variantes) no revienta al abrirlo ni al restaurar: se rechaza con motivo y deja la partida como estaba; mal %s" % [cp_variants.size(), str(cp_bad)])
	for p in [PROGRESS_FILE, PROGRESS_FILE + ".tmp", CHECKPOINT_PATH]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	_counter_stop(counter)
	t.ck(counter.script_errors == 0 and counter.errors == 0, "...sin errores del motor (script %d, otros %d): %s" % [counter.script_errors, counter.errors, counter.last])

# ---------------------------------------------------------------------------------------------------------------------
# B-036: nunca «de el» ni «a el» en lo que el jugador lee

func _test_contractions() -> void:
	if not t.real_only():
		return
	var rx := RegEx.new()
	rx.compile("(?i)(?<![\\p{L}])(de|a) el(?![\\p{L}])")
	var bad: Array = []
	var texts := 0
	for path in ["siguiente.attack", "siguiente.wait_attack", "siguiente.recon", "eventos.apoyo", "eventos.detectado", "avisos_ruta.cerca"]:
		for fid in V.OBJECTIVES:
			var place := str(t.cfg.objectives[fid].place)
			var out := D.ts(path, {"frente": place, "grupo": "Portal", "socorrido": "Arias", "m": 60})
			texts += 1
			if rx.search(out) != null or out.find("{") >= 0:
				bad.append("%s con «%s»: «%s»" % [path, place, out])
	t.ck(bad.is_empty(), "%d textos de las plantillas con preposición, para los tres lugares, no traen «de el», «a el» ni marcas sin llenar: %s" % [texts, str(bad.slice(0, 2))])
	t.ck(D.ts("siguiente.wait_attack", {"frente": "el cuartel"}) == "Esperá la toma del cuartel." and D.ts("eventos.detectado", {"frente": "la batería"}) == "Los reconocedores se acercaron demasiado a la batería.", "«el cuartel» sale contraído («del cuartel») y «la batería» queda con su «a la»")
	# los textos de una partida entera
	var seen_texts: Array = []
	var r = t.new_rules(1817, {"skip_intro": true})
	var mem := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var guard := 0
	while str(r.state.status) == "playing" and guard < 900:
		guard += 1
		t.pol.call("step", r, "obediente", mem, rng)
		seen_texts.append(str(t._dict(t._dict(r.call("hud_state")).get("siguiente", {})).get("texto", "")))
	for e in r.state.log:
		seen_texts.append(str(e.text))
	var dirty: Array = []
	for text in seen_texts:
		if rx.search(String(text)) != null:
			dirty.append(String(text))
	t.ck(dirty.is_empty() and seen_texts.size() > 100, "ninguno de los %d «siguiente paso» y avisos de una partida entera trae «de el» ni «a el»: %s" % [seen_texts.size(), str(dirty.slice(0, 2))])
