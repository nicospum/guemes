extends SceneTree
const Rules = preload("res://scripts/game_rules.gd")
var bad := {}
func note(k:String, extra:String=""):
	if not bad.has(k): bad[k] = extra
func inv(r, tag):
	var s = r.state
	for u in s.units:
		for k in ["strength","fatigue","supply"]:
			var v = float(u[k])
			if not is_finite(v) or v < 0 or v > 100: note(tag+" unit_"+k, str(u))
		if s.scenario=="justine" and not r.is_walkable(u.x,u.z) and u.stage=="moving": note(tag+" moving_in_unwalkable", str(u))
	if s.scenario=="norte":
		for k in ["population"]:
			if s[k] < 0 or s[k] > 100: note(tag+" pop", str(s[k]))
		if s.stores < 0 or s.stores > 150: note(tag+" stores", str(s.stores))
	var v = r.validate_snapshot(JSON.parse_string(JSON.stringify(s)))
	if not v.ok: note(tag+" snapshot_invalid", v.reason)
func _initialize():
	var rng = RandomNumberGenerator.new(); rng.seed = 42
	var ends = {"justine":{}, "norte":{}}
	for game in range(300):
		var r = Rules.new()
		var sc = "justine" if game % 2 == 0 else "norte"
		r.new_game(sc, rng.randi_range(1, 99999))
		var steps = 0
		while r.state.status == "playing" and steps < 3000:
			steps += 1
			if sc == "justine":
				var id = ["guemes","arias","zavala"][rng.randi()%3]
				var a = ["move","rally","board","direct","flank","cancel"][rng.randi()%6]
				if rng.randf() < 0.15:
					r.issue_order(id, a, Vector2(rng.randf_range(-40,40), rng.randf_range(-30,30)))
				r.tick(rng.randf_range(0.1, 15.0))
				if steps % 10 == 0: inv(r, "J")
			else:
				for id in ["guemes","arias","zavala"]:
					if rng.randf() < 0.8:
						var acts = ["move","scout","protect","raid","rest","withdraw","assault","cancel"]
						var secs = ["humahuaca","quebrada","jujuy","salta","lerma","chicoana","oran","rosario","bogus",""]
						r.issue_campaign_order(id, acts[rng.randi()%acts.size()], secs[rng.randi()%secs.size()])
				var ch = r.enemy_choices().keys()
				var intent = ch[rng.randi()%ch.size()] if rng.randf()<0.7 else "garbage"
				r.resolve_round(intent)
				inv(r, "N")
		var key = r.state.status + ("@"+str(r.state.round) if sc=="norte" else "")
		ends[sc][key] = int(ends[sc].get(key,0))+1
		if r.state.status=="playing": note(sc+" never_ends", "steps="+str(steps))
	print("ENDS ", JSON.stringify(ends))
	print("BAD ", JSON.stringify(bad))
	quit(0)
