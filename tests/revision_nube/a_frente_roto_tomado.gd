extends SceneTree
## Revisión nube, lente A (reglas): una partida que ya tomó su frente y lo sostiene (holding) se quiebra (p. ej. bajo la torre) y _step_units
## (humahuaca_rules.gd l. 515-517) cierra con «frente_roto» nombrando el frente propio de la partida: «quedó clavada frente a la batería y se rompió
## bajo el fuego», con la batería ya tomada por ella. El texto que lee el jugador (y la marca del diario) apuntan a un frente que no está en pie.
## Falla hoy: sale con 1.

const RULES := "res://scripts/humahuaca/rules/humahuaca_rules.gd"

func _initialize() -> void:
	var Rs = load(RULES)
	var r = Rs.new()
	r.call("new_game", 1817, 1, {"phase": "ataque"})
	var guard := 0
	while guard < 600 and str(r.state.objectives.bateria.state) != "tomado" and str(r.state.status) == "playing":
		r.call("tick", 1.0)
		guard += 1
	if str(r.state.status) != "playing" or str(r.call("get_unit", "rodriguez").stage) != "holding":
		print("no se pudo armar la situación (status=%s, rodriguez=%s)" % [str(r.state.status), str(r.call("get_unit", "rodriguez").stage)])
		quit(1)
		return
	for u in r.state.units:
		if str(u.id) == "rodriguez":
			u.strength = 10.0
	r.call("tick", 1.0)
	var cause := str(r.state.outcome.get("cause", ""))
	var place := str(r._rules.objectives.bateria.place)
	var names_taken := cause.find(place) >= 0 and str(r.state.objectives.bateria.state) == "tomado"
	print("esperado: si Rodríguez se quiebra sosteniendo la batería YA tomada, la causa no dice que quedó clavada frente a la batería")
	print("obtenido: status=%s reason=%s bateria=%s held_by=%s; texto: «%s»" % [str(r.state.status), str(r.state.reason), str(r.state.objectives.bateria.state), str(r.state.objectives.bateria.held_by), cause])
	print("RESULTADO: %s" % ("FALLA" if names_taken else "PASA"))
	quit(1 if names_taken else 0)
