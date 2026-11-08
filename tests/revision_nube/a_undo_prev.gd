extends SceneTree
## Revisión nube, lente A (reglas): _apply_order guarda en la orden anotada `prev = {stage, order}` (humahuaca_rules.gd l. 1323-1327) para deshacerla,
## pero undo_last (l. 1387-1404) no lo lee: deja a la agrupación en `idle` con orden vacía. Deshacer un «Sostener» (Ctrl+Z en la interfaz) sobre una
## partida que esperaba la señal la saca de la señal en vez de devolverla a `waiting_signal`.
## Falla hoy: sale con 1.

const RULES := "res://scripts/humahuaca/rules/humahuaca_rules.gd"

func _initialize() -> void:
	var Rs = load(RULES)
	var r = Rs.new()
	r.call("new_game", 1817, 1, {"skip_intro": true})
	r.call("issue_order", "rodriguez", "position")
	var guard := 0
	while guard < 400 and str(r.call("get_unit", "rodriguez").stage) != "waiting_signal":
		r.call("tick", 1.0)
		guard += 1
	var before := str(r.call("get_unit", "rodriguez").stage)
	r.call("issue_order", "rodriguez", "hold")
	var prev: Dictionary = ((r.state.orders as Array)[(r.state.orders as Array).size() - 1] as Dictionary).get("prev", {})
	var res: Dictionary = r.call("undo_last")
	var after := str(r.call("get_unit", "rodriguez").stage)
	var ok := bool(res.ok) and after == before
	print("esperado: tras «hold» y undo_last, Rodríguez vuelve a «%s» (lo que la orden anotó en prev: %s)" % [before, str(prev)])
	print("obtenido: undo_last -> %s; stage=«%s»; signal_info.can_give=%s" % [str(res), after, str((r.call("signal_info") as Dictionary).can_give)])
	print("RESULTADO: %s" % ("PASA" if ok else "FALLA"))
	quit(0 if ok else 1)
