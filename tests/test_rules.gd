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
