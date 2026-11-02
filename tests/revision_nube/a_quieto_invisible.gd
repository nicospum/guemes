extends SceneTree
## Revisión nube, lente A (reglas): DISENO 5.2 y REGLAS.md («Ver y ser visto») dicen que un centinela con línea de visión ve a una agrupación si
## distancia < visibilidad × (1 + 2 × ruido): con ruido 0, a menos de `visibilidad` metros. _step_alert (humahuaca_rules.gd l. 424) salta a toda unidad
## con noise <= 0, así que una partida quieta (esperando la señal, sosteniendo, idle) a 51 m de un centinela y a cielo abierto no se ve nunca, ni con
## 100 m ni con 500 m de visibilidad: la alerta del frente sube exactamente igual que en una partida sin nadie cerca (solo el desvelo del reloj).
## Falla hoy: sale con 1.

const RULES := "res://scripts/humahuaca/rules/humahuaca_rules.gd"

func _initialize() -> void:
	var Rs = load(RULES)
	var r = Rs.new()
	r.call("new_game", 1817, 1, {"skip_intro": true})
	var spot := Vector2(560.0, 256.0)  # frente a la puerta del patio de la posta: la prueba de centinelas del repo lo usa como «a cielo abierto» (los ven con ruido 0,5)
	var sentinel := Vector2(576.0, 304.0)
	for u in r.state.units:
		if str(u.id) == "portal":
			u.x = spot.x
			u.z = spot.y
			u.stage = "waiting_signal"
			u.order = {"action": "position", "front": "cuartel"}
	var calm = Rs.new()
	calm.call("new_game", 1817, 1, {"skip_intro": true})
	var t := 330.0  # visibilidad 300 m: el centinela ve a 300 m a quien no hace ruido, según la fórmula
	r.call("advance_to", t)
	calm.call("advance_to", t)
	var vis := float((r.call("environment") as Dictionary).visibility_m)
	var with_unit := float(r.state.objectives.posta.alert)
	var without := float(calm.state.objectives.posta.alert)
	var seen := with_unit > without + 1e-6 or bool(r.call("get_unit", "portal").detected) or int(r.state.stats.detections) > 0
	print("esperado: con Portal quieto a %.0f m del centinela de la posta y visibilidad %.0f m (> %.0f m), la guardia lo ve: la alerta sube más que sin nadie o `detected` se marca" % [spot.distance_to(sentinel), vis, spot.distance_to(sentinel)])
	print("obtenido: a los %.0f s alerta de la posta con Portal pegado=%.3f, sin nadie=%.3f, detected=%s, detections=%d" % [t, with_unit, without, str(r.call("get_unit", "portal").detected), int(r.state.stats.detections)])
	print("RESULTADO: %s" % ("PASA" if seen else "FALLA"))
	quit(0 if seen else 1)
