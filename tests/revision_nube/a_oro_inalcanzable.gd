extends SceneTree
## Revisión nube, lente A (reglas): la medalla de oro (outcome.medals.oro.golpe_min = 80) es inalcanzable en R1. El golpe es entregado ×1 + destruido ×0,35
## (no hay «ocultar»); con la capacidad máxima (2 200 kg) lo más que se puede entregar es 60,29 puntos (mochila exacta sobre los lotes de make_loot) y
## destruir todo lo demás suma 0,35 × 39,71 = 13,9: cota 74,19 < 80, aun con tiempo infinito. campaign_report y HumahuacaProgress.best_medal nunca dan oro.
## Falla hoy: sale con 1.

const RULES := "res://scripts/humahuaca/rules/humahuaca_rules.gd"

func _initialize() -> void:
	var Rs = load(RULES)
	var r = Rs.new()
	r.call("new_game", 1817, 1, {"phase": "extraccion"})
	var cfg: Dictionary = r._rules
	var cap := float(r.state.loot.capacity_kg)
	var unit := 50.0  # granularidad de la mochila (todos los lotes pesan múltiplos de 100 kg)
	var slots := int(cap / unit)
	var best: Array = []
	for i in range(slots + 1):
		best.append(0.0)
	var total := 0.0
	for it in r.state.loot.items:
		var kg := float(it.qty) * float(it.unit_kg)
		var v := float(it.qty) * float(it.unit_value)
		total += v
		var w := int(ceilf(kg / unit - 1e-9))
		for c in range(slots, w - 1, -1):
			best[c] = maxf(best[c], best[c - w] + v)
	var delivered: float = best[slots]
	var bound := delivered + float(cfg.loot.treatments.destruir) * (total - delivered) + float(cfg.loot.treatments.ocultar) * 0.0
	var oro := float(cfg.outcome.medals.oro.golpe_min)
	var ok := bound >= oro
	print("esperado: la medalla de oro (golpe >= %.0f) es alcanzable con la capacidad y los tratamientos de R1" % oro)
	print("obtenido: capacidad %.0f kg; máximo entregable %.3f puntos; con todo lo demás destruido (×%.2f) la cota del golpe es %.3f" % [cap, delivered, float(cfg.loot.treatments.destruir), bound])
	print("RESULTADO: %s" % ("PASA" if ok else "FALLA"))
	quit(0 if ok else 1)
