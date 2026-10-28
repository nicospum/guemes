extends SceneTree
const Rules = preload("res://scripts/game_rules.gd")
func p(s): print(s)
func _initialize():
	var r = Rules.new(); r.new_game("justine", 1)
	r.issue_order("guemes","direct")
	var cancelled := false
	while r.state.elapsed < 835:
		r.tick(1.0)
		var u = r.get_unit("guemes"); u.strength = 100.0  # artificial: isolate the movement rule
		if not cancelled and u.x > -2 and u.stage=="moving":
			cancelled = true; r.cancel_order("guemes"); p("cancelled at t=%d x=%.1f" % [r.state.elapsed,u.x])
	var u = r.get_unit("guemes")
	p("t=%d stage=%s x=%.1f walk=%s water=%.2f" % [r.state.elapsed,u.stage,u.x,str(r.is_walkable(u.x,u.z)),r.state.water_level])
	for a in ["move","direct","flank","board","rally"]:
		var res = r.issue_order("guemes",a,Vector2(-20,0))
		p("order %s -> ok=%s '%s' stage=%s pathlen=%d" % [a,str(res.ok),res.reason,u.stage,u.path.size()])
	for i in range(60): r.tick(1.0); u.strength=100.0
	p("after 60s stage=%s x=%.2f water=%.2f" % [u.stage,u.x,r.state.water_level])
	quit(0)
