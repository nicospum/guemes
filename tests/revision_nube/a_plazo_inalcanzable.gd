extends SceneTree
## Revisión nube, lente A (reglas): la causa «plazo» (time.deadline_s = 840) no se puede alcanzar por la API pública.
## _check_end termina por «amanecio» a los 390 s si no hubo señal, y la señal arma el refuerzo a señal + delay_s (240/300/360): el refuerzo llega
## a lo sumo a 389,75 + 360 = 749,75 s y «interceptados» siempre gana antes de los 840 s. Mientras tanto el HUD muestra «Plazo: m:ss» en la extracción.
## Falla hoy: sale con 1 (espera que el plazo sea alcanzable: máximo reinforcement_at >= deadline_s, o una partida que termine en «plazo»).

const RULES := "res://scripts/humahuaca/rules/humahuaca_rules.gd"

func _initialize() -> void:
	var Rs = load(RULES)
	var r = Rs.new()
	var cfg: Dictionary = r._rules
	var deadline := float(cfg.time.deadline_s)
	var dawn := float(cfg.time.dawn_discovery_s)
	var step := float(Rs.get_script_constant_map().get("STEP", 0.25))
	var max_delay := 0.0
	for v in cfg.reinforcement.delay_s:
		max_delay = maxf(max_delay, float(cfg.reinforcement.delay_s[v]))
	var max_at := (dawn - step) + max_delay
	# la partida real: señal lo más tarde posible, refuerzo tardío, nadie sale
	r.call("new_game", 1817, 1, {"skip_intro": true, "variant": {"refuerzo": "tardio"}})
	for g in ["rodriguez", "portal", "arias"]:
		r.call("issue_order", g, "position")
	r.call("advance_to", dawn - step)
	var sig: Dictionary = r.call("give_signal")
	r.call("advance_to", deadline + 10.0)
	var reached_plazo := str(r.state.status) == "defeat" and str(r.state.reason) == "plazo"
	var ok := max_at >= deadline or reached_plazo
	print("esperado: la causa «plazo» (deadline_s = %.0f) alcanzable: el refuerzo tiene que poder llegar después del plazo o la partida terminar en «plazo»" % deadline)
	print("obtenido: señal a lo sumo a %.2f s + demora máxima %.0f s = refuerzo a lo sumo a %.2f s (< %.0f); partida con señal a los %.2f s (ok=%s) y refuerzo tardío termina en %s/%s a los %.2f s" % [dawn - step, max_delay, max_at, deadline, dawn - step, str(sig.ok), str(r.state.status), str(r.state.reason), float(r.state.elapsed)])
	var h = Rs.new()
	h.call("new_game", 1817, 1, {"phase": "extraccion"})
	print("el HUD en la extracción dice «%s» mientras el refuerzo llega a los %.0f s (en %.0f s)" % [str((h.call("hud_state") as Dictionary).fase.reloj), float(h.state.alarm.reinforcement_at), float(h.state.alarm.reinforcement_at) - float(h.state.elapsed)])
	print("RESULTADO: %s" % ("PASA" if ok else "FALLA"))
	quit(0 if ok else 1)
