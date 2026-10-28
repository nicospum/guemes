extends SceneTree

const Rules = preload("res://scripts/game_rules.gd")
var failures: Array = []
var checks := 0
var report: Dictionary = {"suite": "authoritative_rules", "engine": Engine.get_version_info().string, "results": []}

func _initialize() -> void:
	_test_tide_and_routes()
	_test_justine_win_loss()
	_test_campaign()
	_test_persistence()
	_test_external_stale()
	_test_north_pacing()
	_test_river_rise_and_honest_orders()
	_test_snapshot_coherence()
	_test_salta_occupation_date()
	_test_history_humahuaca_marked()
	report.checks = checks
	report.failures = failures
	report.ok = failures.is_empty()
	var file := FileAccess.open("res://evidence/rules-test-results.json", FileAccess.WRITE)
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

func _test_tide_and_routes() -> void:
	var r := Rules.new()
	r.new_game("justine", 7)
	check(not r.is_walkable(0, 0), "High water blocks central bank")
	check(not r.is_walkable(0, 22), "Deep water blocks all phases")
	check(not r.issue_order("guemes", "move", Vector2(0, 0)).ok, "Invalid deep-water move rejected")
	check(r.issue_order("guemes", "direct").ok, "Approach can be chosen before tide; first decision is immediate")
	check(r.issue_order("arias", "flank").ok, "Flanking approach is available before tide")
	for i in range(15):
		r.tick(15)
	check(r.is_walkable(0, 0), "Low tide opens central bank")
	check(r.is_walkable(0, 14), "Low tide opens southern bank")
	check(not r.is_walkable(0, 22), "Deep channel remains blocked at low tide")
	check(not r.is_walkable(-32, -16), "Building obstacle is blocked")
	check(r.state.units[0].stage in ["moving", "dismounting", "boarding"], "Prepared direct route resumes automatically")
	check(r.state.units[1].stage in ["moving", "dismounting", "boarding"], "Prepared flank route resumes automatically")
	for u in r.state.units:
		check(r.is_walkable(u.x, u.z), "Group stays on traversable terrain")
	check(r.cancel_order("guemes").ok and r.get_unit("guemes").path.is_empty(), "Cancel clears unresolved route")
	r.state.units[2].stage = "idle"
	check(r.is_walkable(-11.3, -19.5) and r.issue_order("zavala", "move", Vector2(-11.3, -19.5)).ok, "Walkable point next to an obstacle cell is routable")
	var n := Rules.new()
	n.new_game("norte", 7)
	n._enemy_moves_to("jujuy")
	check(not n.get_sector("quebrada").enemy and n.get_sector("jujuy").enemy and n.get_sector("humahuaca").enemy, "Enemy advance clears the sector it left but keeps Humahuaca")

func _test_justine_win_loss() -> void:
	for approach in ["direct", "flank"]:
		var r := Rules.new()
		r.new_game("justine", 1806)
		for u in r.state.units:
			check(r.issue_order(u.id, approach).ok, "Valid complete approach " + approach)
		var guard := 0
		var stayed_walkable := true
		while r.state.status == "playing" and guard < 1000:
			r.tick(1.0)
			guard += 1
			for u in r.state.units:
				stayed_walkable = stayed_walkable and r.is_walkable(u.x, u.z)
		check(r.state.status == "victory", "Justine can be won using " + approach)
		check(stayed_walkable, "All approach positions respect banks and obstacles: " + approach)
		var remaining := 0.0
		for u in r.state.units:
			remaining += float(u.strength)
			if u.stage == "boarding":
				check(not u.mounted, "Boarders have dismounted before capturing")
		report.results.append({"scenario": "justine", "strategy": approach, "status": r.state.status, "simulated_seconds": r.state.elapsed, "remaining_strength": remaining, "capture": r.state.capture})
	var wait := Rules.new()
	wait.new_game("justine")
	for i in range(16):
		wait.tick(60)
	check(wait.state.status == "defeat", "Doing nothing loses when tidal opportunity closes")
	check(not wait.issue_order("guemes", "direct").ok, "Terminal game rejects orders")
	var casualties := Rules.new()
	casualties.new_game("justine")
	for u in casualties.state.units:
		u.strength = 0.0
	casualties.tick(1)
	check(casualties.state.status == "defeat", "Loss of all groups produces defeat")

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

func _test_persistence() -> void:
	for scenario in ["justine", "norte"]:
		var r := Rules.new()
		r.new_game(scenario, 11)
		if scenario == "justine":
			r.issue_order("guemes", "direct")
			r.tick(31.125)
		else:
			_campaign_strategy(r)
			r.resolve_round("guard")
		var path: String = "user://test-rules-" + str(scenario) + ".json"
		check(r.save_game(path) == OK, "Save succeeds for " + scenario)
		check(r.save_game(path) == OK, "Replacing save succeeds for " + scenario)
		var loaded := Rules.new()
		check(loaded.load_game(path).ok, "Load succeeds for " + scenario)
		check(loaded.state.game_id != r.state.game_id, "Load creates a new request epoch")
		check(_equivalent(loaded.state.units, r.state.units), "Save/load preserves units and unresolved orders")
		if scenario == "justine":
			for i in range(8):
				r.tick(60)
				loaded.tick(60)
		else:
			for i in range(4):
				_campaign_strategy(r)
				_campaign_strategy(loaded)
				r.resolve_round("forage")
				loaded.resolve_round("forage")
		check(_equivalent(r.state.units, loaded.state.units), "Save/load continuation reproduces gameplay for " + scenario)
		check(int(r.state.rng_state) == int(loaded.state.rng_state), "RNG survives JSON round-trip for " + scenario)
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
# Crecida del rio: ordenes honestas y unidades no varadas

func _justine_at(seconds: float) -> RefCounted:
	var r := Rules.new()
	r.new_game("justine", 5)
	while float(r.state.elapsed) < seconds:
		r.tick(1.0)
	return r

func _test_river_rise_and_honest_orders() -> void:
	var early := _justine_at(0.0)
	var res: Dictionary = early.issue_order("guemes", "direct")
	check(res.ok and "espera en la orilla" in str(res.reason), "Before the low tide the approach is honestly described as waiting on the bank")
	var low := _justine_at(250.0)
	res = low.issue_order("guemes", "direct")
	check(res.ok and "cruce es posible" in str(res.reason), "At low tide the approach message says the crossing is possible")
	for t in [700.0, 760.0, 790.0]:
		var late := _justine_at(t)
		var before_x: float = late.get_unit("guemes").x
		res = late.issue_order("guemes", "direct")
		check(not res.ok, "Order at t=%d that cannot cross before the flood is rejected" % int(t))
		check(late.get_unit("guemes").stage == "ready" and late.get_unit("guemes").order.is_empty() and late.get_unit("guemes").x == before_x, "Rejected late order leaves the unit untouched at t=%d" % int(t))
		check(late.state.orders.is_empty(), "Rejected late order is not recorded at t=%d" % int(t))
	var rising := _justine_at(835.0)
	res = rising.issue_order("guemes", "flank")
	check(not res.ok and not ("preparada" in str(res.reason).to_lower()), "At t=835 no false 'Aproximación preparada' is returned")
	# Barrido: toda orden aceptada termina con la unidad en seco o a bordo, nunca varada en el agua.
	var stranded := 0
	var accepted := 0
	for start in range(0, 880, 60):
		for action in ["direct", "flank"]:
			var r := _justine_at(float(start))
			var o: Dictionary = r.issue_order("zavala", action)
			if not o.ok:
				continue
			accepted += 1
			for i in range(900):
				r.tick(1.0)
				if r.state.status != "playing":
					break
			var z: Dictionary = r.get_unit("zavala")
			if not r.is_walkable(z.x, z.z) and z.stage not in ["boarding", "dismounting"]:
				stranded += 1
	check(accepted > 0 and stranded == 0, "No accepted approach leaves a unit stranded in the river (%d accepted, %d stranded)" % [accepted, stranded])
	# Rescate: una unidad atrapada por el agua vuelve a un punto seco.
	var rescue := Rules.new()
	rescue.new_game("justine", 5)
	rescue.state.elapsed = 850.0
	rescue.state.next_volley = 855.0
	var g: Dictionary = rescue.get_unit("guemes")
	g.x = 2.0
	g.z = 0.0
	g.stage = "blocked"
	g.blocked_until = 0.0
	g.order = {"action": "direct", "x": 12.0, "z": 0.0}
	g.path = [{"x": 12.0, "z": 0.0}]
	check(not rescue.is_walkable(g.x, g.z), "Rescue scenario starts underwater")
	rescue.tick(1.0)
	g = rescue.get_unit("guemes")
	check(rescue.is_walkable(g.x, g.z) and g.stage == "ready" and g.order.is_empty() and g.path.is_empty(), "A unit caught mid-river is brought back to dry ground with a clean state")
	check(rescue.validate_snapshot(rescue.snapshot()).ok, "Rescued state is a coherent snapshot")
	var logged := false
	for e in rescue.state.log:
		logged = logged or e.kind == "warning"
	check(logged, "The rescue is reported in the log")

# ---------------------------------------------------------------------------
# validate_snapshot: coherencia entre campos

func _rejects(r: RefCounted, snap: Dictionary, description: String) -> void:
	check(not r.validate_snapshot(snap).ok, description)

func _test_snapshot_coherence() -> void:
	var j := Rules.new()
	j.new_game("justine", 3)
	j.issue_order("guemes", "direct")
	j.tick(100.0)
	check(j.validate_snapshot(j.snapshot()).ok, "Coherent tactical snapshot is accepted")
	var s: Dictionary = j.snapshot()
	s.water_level = 0.95
	_rejects(j, s, "Water level inconsistent with elapsed time rejected")
	s = j.snapshot()
	s.tide_phase = "alta"
	_rejects(j, s, "Tide phase inconsistent with elapsed time rejected")
	s = j.snapshot()
	s.status = "victory"
	_rejects(j, s, "Victory with no closing reason and incomplete capture rejected")
	s = j.snapshot()
	s.reason = "Fin"
	_rejects(j, s, "Closing reason while still playing rejected")
	s = j.snapshot()
	s.first_order_at = -1.0
	_rejects(j, s, "Orders recorded but first_order_at unset rejected")
	s = j.snapshot()
	s.orders[0].time = 9999.0
	_rejects(j, s, "Order from the future rejected")
	s = j.snapshot()
	s.log[0].time = 9999.0
	_rejects(j, s, "Log event from the future rejected")
	s = j.snapshot()
	s.units[1].stage = "moving"
	s.units[1].order = {}
	_rejects(j, s, "Moving unit without order rejected")
	s = j.snapshot()
	s.units[2].stage = "ready"
	s.units[2].path = [{"x": 0.0, "z": 0.0}]
	_rejects(j, s, "Pending path on an idle unit rejected")
	s = j.snapshot()
	s.units[2].stage = "ordered"
	_rejects(j, s, "Campaign stage in the tactical scenario rejected")
	s = j.snapshot()
	s.units[2].dismount_remaining = 5.0
	_rejects(j, s, "Dismount timer on a unit that is not dismounting rejected")
	s = j.snapshot()
	s.units[2].stage = "boarding"
	s.units[2].mounted = true
	_rejects(j, s, "Boarding unit still mounted rejected")
	s = j.snapshot()
	s.units[2].stage = "routed"
	_rejects(j, s, "Routed unit with full strength rejected")
	s = j.snapshot()
	s.next_volley = 1.0
	_rejects(j, s, "Overdue artillery volley rejected")
	s = j.snapshot()
	s.capture = 100.0
	_rejects(j, s, "Playing with complete capture rejected")

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
