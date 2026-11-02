extends SceneTree
## Revisión nube, lente A (reglas): _step_reinforcement emite «Polvareda al sur» (reinforcement_warning) solo si el paso CRUZA reinforcement_at − 60.
## Si quemar pólvora adelanta el refuerzo de modo que ese instante queda en el pasado (quema que termina entre at−80 y at−60), el evento no sale nunca:
## el jugador recibe la alerta del HUD pero no el aviso del registro ni su sonido. Falla hoy: sale con 1.

const RULES := "res://scripts/humahuaca/rules/humahuaca_rules.gd"

func warnings(r) -> int:
	var n := 0
	for e in r.state.log:
		if str(e.kind) == "reinforcement_warning":
			n += 1
	return n

func _initialize() -> void:
	var Rs = load(RULES)
	var r = Rs.new()
	r.call("new_game", 1817, 1, {"phase": "extraccion"})
	var at := float(r.state.alarm.reinforcement_at)
	var pw: Dictionary = {}
	for it in r.state.loot.items:
		if str(it.kind) == "polvora":
			pw = it
			break
	var pos := Vector2(float(pw.x), float(pw.z))
	r.call("issue_order", "arreo", "move", pos)
	var guard := 0
	while guard < 300 and str(r.call("get_unit", "arreo").stage) != "idle":
		r.call("tick", 1.0)
		guard += 1
	r.call("advance_to", at - 92.0)
	var d: Dictionary = r.call("issue_order", "arreo", "destroy", pos, {"item": str(pw.id)})
	r.call("advance_to", float(r.state.alarm.reinforcement_at) + 1.0)
	var ok := bool(d.ok) and warnings(r) >= 1
	print("esperado: antes de que llegue el refuerzo hubo al menos un evento reinforcement_warning («Polvareda al sur»)")
	print("obtenido: quema ordenada a los %.0f s (ok=%s), el refuerzo pasó de %.0f a %.0f s y llegó (%s/%s) con %d avisos en el registro" % [at - 92.0, str(d.ok), at, float(r.state.alarm.reinforcement_at), str(r.state.status), str(r.state.reason), warnings(r)])
	print("RESULTADO: %s" % ("PASA" if ok else "FALLA"))
	quit(0 if ok else 1)
