extends SceneTree
## Revisión nube, lente A (reglas): con opts.loot_traits.plata = false (rasgo legal de WORLD_TRAITS) make_loot omite los tres lotes de plata pero deja
## total_value = 100: los lotes suman 88, loot_state().golpe.pendiente nunca baja de 12 aunque todos los lotes estén cerrados, y al cierre
## entregado + destruido + oculto + perdido suma 88 (el comentario de _complete_destroy promete 100). Falla hoy: sale con 1.

const RULES := "res://scripts/humahuaca/rules/humahuaca_rules.gd"
const POL := "res://scripts/humahuaca/rules/humahuaca_policies.gd"

func _initialize() -> void:
	var Rs = load(RULES)
	var Pol = load(POL)
	var r = Rs.new()
	r.call("new_game", 1817, 1, {"skip_intro": true, "loot_traits": {"plata": false}})
	var sum := 0.0
	for it in r.state.loot.items:
		sum += float(it.qty) * float(it.unit_value)
	var total := float(r.state.loot.total_value)
	Pol.call("play", r, "experto", {})
	var g: Dictionary = (r.call("loot_state") as Dictionary).golpe
	var open := 0
	for it in r.state.loot.items:
		if str(it.state) == "en_sitio" or str(it.state) == "cargado":
			open += 1
	var accounted := float(g.entregado) + float(g.destruido) + float(g.oculto) + float(g.perdido)
	var ok := absf(sum - total) < 1e-6 and (open > 0 or float(g.pendiente) < 1e-6)
	print("esperado: los lotes suman total_value y, con todos los lotes cerrados, pendiente = 0 y entregado + destruido + oculto + perdido = total")
	print("obtenido: lotes suman %.2f, total_value=%.2f; al cierre (%s, %d lotes abiertos): pendiente=%.2f, contabilizado=%.2f" % [sum, total, str(r.state.status), open, float(g.pendiente), accounted])
	print("RESULTADO: %s" % ("PASA" if ok else "FALLA"))
	quit(0 if ok else 1)
