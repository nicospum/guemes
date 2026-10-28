extends SceneTree
const Rules = preload("res://scripts/game_rules.gd")
func p(s): print(s)
func qa(r):
	var a=r.get_unit("arias");var g=r.get_unit("guemes");var support=r.get_unit("zavala")
	var rd=int(r.state.round)
	if rd==1:r.issue_campaign_order("arias","scout","quebrada")
	elif rd==2:r.issue_campaign_order("arias","move","quebrada")
	elif rd>=7 and not r.state.humahuaca and float(a.supply)>=18 and float(a.strength)>=45 and float(a.fatigue)<=78:r.issue_campaign_order("arias","assault","humahuaca")
	elif rd<=6:r.issue_campaign_order("arias","scout","humahuaca")
	elif float(a.fatigue)<=65 and float(a.supply)>20:r.issue_campaign_order("arias","raid","quebrada")
	if float(g.fatigue)>55 or float(g.supply)<25:
		r.issue_campaign_order("guemes","withdraw" if g.sector_id!="lerma" else "rest","lerma")
	elif rd==1 or rd%3==0:r.issue_campaign_order("guemes","scout","jujuy")
	else:r.issue_campaign_order("guemes","raid","jujuy")
	var s=r.get_sector(str(support.sector_id))
	if int(s.crates)>0:r.issue_campaign_order("zavala","protect",str(support.sector_id))
	else:
		var d="rosario" if support.sector_id=="chicoana" else "lerma"
		r.issue_campaign_order("zavala","move" if d!=support.sector_id else "rest",d)
func _initialize():
	var res = {}; var stores_min = 999.0
	for sd in range(1, 101):
		var r = Rules.new(); r.new_game("norte", sd)
		while r.state.status=="playing":
			qa(r)
			r.resolve_round(r.enemy_fallback())
			stores_min = minf(stores_min, r.state.stores)
		var k = r.state.status+"@"+str(r.state.round)
		res[k]=int(res.get(k,0))+1
	p("QA-policy x100 seeds (fallback enemy): %s  min stores=%.0f" % [JSON.stringify(res), stores_min])
	# Aggressive enemy choices: always guard / always forage
	for mode in ["guard","forage"]:
		res = {}
		for sd in range(1, 51):
			var r = Rules.new(); r.new_game("norte", sd)
			while r.state.status=="playing":
				qa(r)
				r.resolve_round(mode)
			var k = r.state.status+"@"+str(r.state.round)
			res[k]=int(res.get(k,0))+1
		p("enemy always %s: %s" % [mode, JSON.stringify(res)])
	quit(0)
