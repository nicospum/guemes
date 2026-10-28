extends SceneTree
const Rules = preload("res://scripts/game_rules.gd")
func p(s): print(s)
func _initialize():
	var rng = RandomNumberGenerator.new(); rng.seed = 11
	var shown = 0
	for g in range(300):
		var r = Rules.new(); r.new_game("norte", 1817)
		var bias = rng.randf_range(0.5, 1.0)
		var lines: Array = []
		while r.state.status=="playing":
			var line = "R%d: " % r.state.round
			for id in ["guemes","arias","zavala"]:
				var here = str(r.get_unit(id).sector_id)
				var opts: Array = []
				for s in [here] + r.get_sector(here).neighbors:
					for a in r.legal_campaign_actions(id, s): opts.append([a, s])
				if opts.is_empty(): continue
				var raids = opts.filter(func(o): return o[0] in ["raid"])
				var pick = raids[rng.randi()%raids.size()] if (not raids.is_empty() and rng.randf() < bias) else opts[rng.randi()%opts.size()]
				if r.issue_campaign_order(id, pick[0], pick[1]).ok: line += "%s %s@%s; " % [id, pick[0], pick[1]]
			r.resolve_round(r.enemy_fallback())
			lines.append(line + " pop=%.0f" % r.state.population)
		if r.state.status=="victory" and r.state.round==7 and shown < 1:
			shown += 1
			for l in lines: p(l)
			p("victory round %d pop=%.0f stores=%.0f : %s" % [r.state.round, r.state.population, r.state.stores, r.state.reason])
	quit(0)
