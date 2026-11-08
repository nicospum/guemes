extends SceneTree
## Revisión nube, lente A (reglas): dos incoherencias de estado sin crash.
## (1) «hold» y «attack» sobre una agrupación que está destruyendo (stage loading, work {destroy…}) cambian la etapa pero no vacían `work`:
##     queda un trabajo colgado con stage holding/attacking (humahuaca_rules.gd l. 1338-1340 y 1360-1363; _go sí lo limpia para las marchas).
## (2) _finish (l. 933-941 y _finalize_loot) pasa los lotes cargados a «abandonado» pero deja loot.load_kg y units[].carry_kg con los kilos, y deja
##     `stage = attacking` con `order = {}`: después del cierre el chip «Carga» sigue diciendo cuánto llevaba el arreo y la ficha «Atacando».
## Falla hoy: sale con 1.

const RULES := "res://scripts/humahuaca/rules/humahuaca_rules.gd"

func _initialize() -> void:
	var Rs = load(RULES)
	var failures: Array = []
	var b = Rs.new()
	b.call("new_game", 1817, 1, {"phase": "extraccion"})
	var item: Dictionary = {}
	for it in b.state.loot.items:
		if str(it.kind) == "viveres":
			item = it
			break
	var pos := Vector2(float(item.x), float(item.z))
	b.call("issue_order", "arias", "move", pos)
	var guard := 0
	while guard < 400 and str(b.call("get_unit", "arias").stage) != "idle":
		b.call("tick", 1.0)
		guard += 1
	b.call("issue_order", "arias", "destroy", pos, {"item": str(item.id)})
	b.call("issue_order", "arias", "hold")
	var u: Dictionary = b.call("get_unit", "arias")
	if str(u.stage) == "holding" and not (u.work as Dictionary).is_empty():
		failures.append("tras destroy + hold: stage=%s con work=%s" % [str(u.stage), str(u.work)])
	# (2) cierre con carga a bordo
	var c = Rs.new()
	c.call("new_game", 1817, 1, {"phase": "extraccion"})
	var pw: Dictionary = {}
	for it in c.state.loot.items:
		if str(it.kind) == "polvora":
			pw = it
			break
	var ppos := Vector2(float(pw.x), float(pw.z))
	c.call("issue_order", "arreo", "move", ppos)
	guard = 0
	while guard < 400 and str(c.call("get_unit", "arreo").stage) != "idle":
		c.call("tick", 1.0)
		guard += 1
	c.call("issue_order", "arreo", "load", ppos, {"item": str(pw.id)})
	guard = 0
	while guard < 100 and str(c.call("get_unit", "arreo").stage) == "loading":
		c.call("tick", 1.0)
		guard += 1
	c.call("retreat_all")
	var loaded := 0
	for it in c.state.loot.items:
		if str(it.state) == "cargado":
			loaded += 1
	var load_kg := float(c.state.loot.load_kg)
	var carry := float(c.call("get_unit", "arreo").carry_kg)
	if loaded == 0 and (load_kg > 0.0 or carry > 0.0):
		failures.append("tras el cierre: 0 lotes cargados pero load_kg=%.0f y arreo.carry_kg=%.0f (chip «%s»)" % [load_kg, carry, str((c.call("hud_state") as Dictionary).chips[0].txt)])
	var a = Rs.new()
	a.call("new_game", 1817, 1, {"phase": "ataque"})
	a.call("tick", 5.0)
	a.call("retreat_all")
	for uu in a.state.units:
		if str(uu.stage) == "attacking" and (uu.order as Dictionary).is_empty():
			failures.append("tras el cierre %s sigue «attacking» con orden vacía" % str(uu.id))
	print("esperado: ninguna agrupación con trabajo colgado tras hold; tras el cierre la carga abandonada no sigue contada ni hay «attacking» sin orden")
	print("obtenido: %s" % ("correcto" if failures.is_empty() else str(failures)))
	print("RESULTADO: %s" % ("PASA" if failures.is_empty() else "FALLA"))
	quit(0 if failures.is_empty() else 1)
