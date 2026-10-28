extends SceneTree
const Rules = preload("res://scripts/game_rules.gd")
func p(s): print(s)
func _initialize():
	var rng = RandomNumberGenerator.new(); rng.seed = 5
	var stuck = 0; var tried = 0; var examples: Array = []; var rejected_walkable = 0
	for g in range(400):
		var r = Rules.new(); r.new_game("justine", 3)
		# jump to low tide with idle units, keep them alive
		for i in range(300): r.tick(1.0)
		for u in r.state.units: u.strength = 100.0
		var id = ["guemes","arias","zavala"][rng.randi()%3]
		var u = r.get_unit(id)
		var t = Vector2(rng.randf_range(-37, 37), rng.randf_range(-27, 27))
		if not r.is_walkable(t.x, t.y): continue
		var res = r.issue_order(id, "move", t)
		tried += 1
		if not res.ok: rejected_walkable += 1; if examples.size()<5: examples.append("REJECT start=(%.1f,%.1f) target=(%.1f,%.1f) %s" % [u.x,u.z,t.x,t.y,res.reason]); continue
		for i in range(900):
			r.tick(1.0); u.strength = 100.0
			if u.stage != "moving": break
			if r.state.elapsed > 650: break
		if u.stage == "blocked" or (u.stage == "moving" and r.state.elapsed <= 650):
			stuck += 1
			if examples.size() < 10: examples.append("STUCK stage=%s at=(%.1f,%.1f) target=(%.1f,%.1f) t=%d" % [u.stage, u.x, u.z, t.x, t.y, r.state.elapsed])
	p("tried=%d rejected_though_target_walkable=%d stuck=%d" % [tried, rejected_walkable, stuck])
	for e in examples: p(e)
	quit(0)
