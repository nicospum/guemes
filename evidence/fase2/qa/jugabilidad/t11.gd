extends SceneTree
const Rules = preload("res://scripts/game_rules.gd")
func p(s): print(s)
func roundtrip(r, tag, mutate: Callable):
	var s = JSON.parse_string(JSON.stringify(r.state))
	mutate.call(s)
	var f = FileAccess.open("user://tamper.json", FileAccess.WRITE); f.store_string(JSON.stringify(s)); f.close()
	var q = Rules.new()
	var res = q.load_game("user://tamper.json")
	p("%s -> load ok=%s %s" % [tag, str(res.ok), res.reason])
	return q if res.ok else null
func _initialize():
	var r = Rules.new(); r.new_game("justine", 1)
	var q = roundtrip(r, "blocked w/o order", func(s): s.units[0].stage = "blocked"; s.units[0].order = {})
	if q:
		for i in range(400): q.tick(1.0)
		p("   unit0 stage after 400s: %s status=%s" % [q.get_unit("guemes").stage, q.state.status])
	q = roundtrip(r, "waiting_tide w/ empty order", func(s): s.units[1].stage = "waiting_tide"; s.units[1].order = {})
	if q:
		for i in range(400): q.tick(1.0)
		p("   unit1 stage: %s x=%.1f" % [q.get_unit("arias").stage, q.get_unit("arias").x])
	q = roundtrip(r, "dismounting in justine at wrong place", func(s): s.units[2].stage = "boarding"; s.units[2].x = -28; s.capture = 99.9)
	if q:
		for i in range(10): q.tick(1.0)
		p("   status after boarding far from ship (x=-28): %s capture=%.1f" % [q.state.status, q.state.capture])
	q = roundtrip(r, "justine unit sector_id empty ok", func(s): pass)
	var n = Rules.new(); n.new_game("norte", 1)
	q = roundtrip(n, "norte stage boarding", func(s): s.units[0].stage = "boarding")
	if q:
		q.resolve_round("forage"); p("   norte resolved ok round=%d" % q.state.round)
	q = roundtrip(n, "norte capture field missing ok / state.status victory but round1", func(s): s.status = "victory")
	q = roundtrip(n, "norte units all strength 0 and playing", func(s): for u in s.units: u.strength = 0)
	if q:
		var res = q.resolve_round("forage"); p("   all-dead resolve: status=%s" % q.state.status)
	q = roundtrip(n, "norte population 0 playing", func(s): s.population = 0)
	if q:
		q.resolve_round("forage"); p("   pop0 resolve: status=%s" % q.state.status)
	quit(0)
