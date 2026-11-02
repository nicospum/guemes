extends SceneTree
## Revisión nube, lente A (reglas): tick(NAN) pasa el clampf (NaN no se recorta) y deja `accumulator = NaN`: desde ahí ningún tick avanza el reloj
## (NaN >= STEP es falso), la partida queda en «playing» para siempre, validate_snapshot falla y save_game se niega. Robustez: el juego normal no lo
## produce, pero la API pública lo acepta sin rechazarlo. Falla hoy: sale con 1.

const RULES := "res://scripts/humahuaca/rules/humahuaca_rules.gd"

func _initialize() -> void:
	var Rs = load(RULES)
	var r = Rs.new()
	r.call("new_game", 1817, 1, {"phase": "ataque"})
	var e0 := float(r.state.elapsed)
	r.call("tick", NAN)
	for i in range(8):
		r.call("tick", 1.0)
	var advanced := float(r.state.elapsed) - e0
	var chk: Dictionary = r.call("validate_snapshot", r.call("snapshot"))
	var ok := absf(advanced - 8.0) < 1e-6 and bool(chk.ok)
	print("esperado: tick(NAN) se ignora (o se rechaza) y ocho ticks de 1 s avanzan 8 s con el estado válido")
	print("obtenido: avanzó %.2f s, accumulator=%s, validate=%s (%s), status=%s" % [advanced, str(r.state.accumulator), str(chk.ok), str(chk.get("path", "")), str(r.state.status)])
	print("RESULTADO: %s" % ("PASA" if ok else "FALLA"))
	quit(0 if ok else 1)
