extends SceneTree
const Rules = preload("res://scripts/game_rules.gd")
func p(s): print(s)
func _initialize():
	var rng = RandomNumberGenerator.new(); rng.seed = 11
	var stats = {}
	for g in range(1500):
		var r = Rules.new(); r.new_game("norte", rng.randi_range(1,99999))
		var bias = rng.randf_range(0.5, 1.0)
		var actions_used = {}
		while r.state.status=="playing":
			for id in ["guemes","arias","zavala"]:
				var here = str(r.get_unit(id).sector_id)
				var opts: Array = []
				for s in [here] + r.get_sector(here).neighbors:
					for a in r.legal_campaign_actions(id, s): opts.append([a, s])
				if opts.is_empty(): continue
				var raids = opts.filter(func(o): return o[0] in ["raid"])
				var pick = raids[rng.randi()%raids.size()] if (not raids.is_empty() and rng.randf() < bias) else opts[rng.randi()%opts.size()]
				if r.issue_campaign_order(id, pick[0], pick[1]).ok: actions_used[pick[0]] = int(actions_used.get(pick[0],0))+1
			r.resolve_round(r.enemy_fallback())
		var key = r.state.status + ("@"+str(r.state.round))
		var e = stats.get(key, {"n":0,"assault":0,"raids":0,"pop":0.0})
		e.n += 1; e.assault += (1 if r.state.humahuaca else 0); e.raids += int(actions_used.get("raid",0)); e.pop += r.state.population
		stats[key] = e
	for k in stats: p("%s n=%d assaultDone=%d avgRaidOrders=%.1f avgPop=%.0f" % [k, stats[k].n, stats[k].assault, float(stats[k].raids)/stats[k].n, stats[k].pop/stats[k].n])
	quit(0)
