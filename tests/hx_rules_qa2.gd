extends RefCounted
## Pruebas de reglas de la ronda de corrección del QA (ronda 2) del nivel II, aparte de tests/test_hx_rules.gd para que ese archivo no pase de las ~1 600 líneas de
## V19. test_hx_rules.gd la crea con `QA2.new(self).run()` y le presta sus ayudas (ck, new_rules, order, hito, run_until, pol, cfg, suite).

var t: Object

func _init(test: Object) -> void:
	t = test

func run() -> void:
	_test_destroy_chain()
	_test_discovered_blame()


## Q-203 (QA ronda 2): una orden de destruir sigue sola lote por lote (transport.destroy_chain). El obediente gana con ≤ 8 órdenes de destruir (antes 36–37) y el
## golpe no baja más de 2 puntos contra la cadena apagada, en las mismas semillas.
func _test_destroy_chain() -> void:
	if not t.real_only():
		return
	var probe = t.new_rules(1817, {})
	var tr: Dictionary = probe.get("_rules").transport if probe.get("_rules") is Dictionary else {}
	if not t.ck(not tr.is_empty(), "Q-203: las reglas exponen transport"):
		return
	var rows: Array = []
	var worst_orders := 0
	var worst_drop := 0.0
	var all_won := true
	for sd in [1817, 3, 13, 2005]:
		var res := {}
		for chain in [false, true]:
			tr["destroy_chain"] = chain
			var r = t.new_rules(sd, {})
			var rec: Dictionary = t._dict(t.pol.call("play", r, "obediente", {}))
			var n := 0
			for o in r.state.orders:
				if str(o.action) == "destroy":
					n += 1
			res[chain] = {"estado": str(rec.status), "golpe": float(rec.golpe), "destruir": n}
		tr.erase("destroy_chain")
		rows.append({"semilla": sd, "sin_cadena": res[false], "cadena": res[true]})
		worst_orders = maxi(worst_orders, int(res[true].destruir))
		worst_drop = maxf(worst_drop, float(res[false].golpe) - float(res[true].golpe))
		all_won = all_won and (str(res[true].estado) == "victory" or str(res[false].estado) != "victory")
	t.suite.extra["cadena_destruir"] = rows
	t.ck(worst_orders <= 8, "Q-203: el obediente da como mucho 8 órdenes de destruir con la cadena (peor: %d)" % worst_orders)
	t.ck(worst_drop <= 2.0, "Q-203: la cadena no baja el golpe del obediente más de 2 puntos (peor baja: %.2f)" % worst_drop)
	t.ck(all_won, "Q-203: donde el obediente ganaba sin la cadena, gana con la cadena (%s)" % str(rows))


## Q-207 (QA ronda 2): con la guardia atenta, reconocer la batería y no retirar a los reconocedores con el aviso pierde por «descubiertos»; el parte tiene que nombrar
## al frente que dio la voz (la batería, aunque la voz corra después a los otros) y el consejo tiene que hablar de retirarlos con el aviso.
func _test_discovered_blame() -> void:
	if not t.real_only():
		return
	var sd := -1
	for cand in [13, 3, 5, 17]:
		var probe = t.new_rules(cand, {})
		if str(probe.state.world.guardia) == "atenta":
			sd = cand
			break
	if not t.ck(sd > 0, "Q-207: hay una semilla con guardia atenta"):
		return
	var r = t.new_rules(sd, {})
	t.order(r, "reconocedores", "recon", t.hito("bateria"))
	t.run_until(r, func(): return str(r.state.status) != "playing", 400.0, 0.5)
	var out: Dictionary = r.state.outcome
	var place := str(t.cfg.objectives.bateria.place)
	var first := str((r.state.alarm.pre_signal as Array)[0]) if not (r.state.alarm.pre_signal as Array).is_empty() else ""
	t.suite.extra["descubiertos_q207"] = {"semilla": sd, "estado": str(r.state.status), "causa": str(out.get("cause_id", "")), "texto": str(out.get("cause", "")), "consejo": str(out.get("advice", "")), "primero_en_alarma": first}
	t.ck(str(r.state.status) == "defeat" and str(out.get("cause_id", "")) == "descubiertos" and first == "bateria", "Q-207: quedarse tras el aviso pierde por «descubiertos» y la batería fue la primera en dar la voz (%s, %s)" % [str(out.get("cause_id", "")), first])
	t.ck(place.to_lower() in str(out.get("cause", "")).to_lower(), "Q-207: el «Qué pasó» nombra al frente que dio la voz (%s): «%s»" % [place, str(out.get("cause", ""))])
	t.ck("aviso" in str(out.get("advice", "")).to_lower() and "reconocedores" in str(out.get("advice", "")).to_lower(), "Q-207: el consejo habla de retirar a los reconocedores con el aviso: «%s»" % str(out.get("advice", "")))
