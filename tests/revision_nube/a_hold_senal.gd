extends SceneTree
## Revisión nube, lente A (reglas): «Sostener» (hold, acción de R1) sobre una partida que espera la señal en su puesto la deja en `holding`;
## signal_info().in_position la sigue contando como en su puesto (y waiting queda vacío), pero _check_signal solo acepta `waiting_signal`
## y _fire_signal solo lanza `waiting_signal`: con las tres sosteniendo, give_signal se rechaza con «Ninguna partida llegó a su puesto», y con una
## sosteniendo, la señal no la lanza aunque el HUD la daba por lista.
## Falla hoy: sale con 1.

const RULES := "res://scripts/humahuaca/rules/humahuaca_rules.gd"

func all_waiting(r) -> bool:
	for g in ["rodriguez", "portal", "arias"]:
		if str(r.call("get_unit", g).stage) != "waiting_signal":
			return false
	return true

func _initialize() -> void:
	var Rs = load(RULES)
	var r = Rs.new()
	r.call("new_game", 1817, 1, {"skip_intro": true})
	for g in ["rodriguez", "portal", "arias"]:
		r.call("issue_order", g, "position")
	var guard := 0
	while guard < 400 and not all_waiting(r) and str(r.state.status) == "playing":
		r.call("tick", 1.0)
		guard += 1
	var failures: Array = []
	if not all_waiting(r):
		failures.append("las tres partidas no llegaron a su puesto a los %.0f s" % float(r.state.elapsed))
	for g in ["rodriguez", "portal", "arias"]:
		r.call("issue_order", g, "hold")
	var si: Dictionary = r.call("signal_info")
	var consistent: bool = bool(si.can_give) == (not (si.in_position as Array).is_empty())
	if not consistent:
		failures.append("signal_info: in_position=%s waiting=%s pero can_give=%s («%s»)" % [str(si.in_position), str(si.waiting), str(si.can_give), str(si.reason)])
	# con una sola sosteniendo: la señal tiene que lanzar a quien el HUD daba por lista (o no listarla)
	var s = Rs.new()
	s.call("new_game", 1817, 1, {"skip_intro": true})
	for g in ["rodriguez", "portal", "arias"]:
		s.call("issue_order", g, "position")
	guard = 0
	while guard < 400 and not all_waiting(s) and str(s.state.status) == "playing":
		s.call("tick", 1.0)
		guard += 1
	s.call("issue_order", "portal", "hold")
	var listed: bool = (s.call("signal_info") as Dictionary).in_position.has("portal")
	s.call("give_signal")
	var launched := str(s.call("get_unit", "portal").stage) == "attacking"
	if listed and not launched:
		failures.append("Portal figuraba en in_position pero tras la señal quedó «%s», no atacando" % str(s.call("get_unit", "portal").stage))
	print("esperado: can_give coincide con in_position no vacío, y toda partida listada en in_position ataca al dar la señal")
	print("obtenido: %s" % ("correcto" if failures.is_empty() else str(failures)))
	print("RESULTADO: %s" % ("PASA" if failures.is_empty() else "FALLA"))
	quit(0 if failures.is_empty() else 1)
