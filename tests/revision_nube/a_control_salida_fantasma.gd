extends SceneTree
## Revisión nube, lente A (progreso): HumahuacaProgress._write_checkpoint("posiciones") borra «salida» del archivo (l. 294-295) pero no de `_cp`,
## así que has_checkpoint("salida") y retry_options() siguen ofreciendo «Reintentar la salida» y restore_checkpoint(rules, "salida") falla con
## «Todavía no hay un punto de control para esa opción». Flujo normal: el intento 1 llega a la extracción (se guardan los dos controles), el intento 2
## llega a sus posiciones (se reescribe «posiciones» y se borra «salida») y se pierde; el parte ofrece «Reintentar la salida» y la opción no anda.
## Escribe en user:// (perfil aislado). Falla hoy: sale con 1.

const RULES := "res://scripts/humahuaca/rules/humahuaca_rules.gd"
const PROG := "res://scripts/humahuaca/rules/humahuaca_progress.gd"
const POL := "res://scripts/humahuaca/rules/humahuaca_policies.gd"
const P_PATH := "user://revision_a_progress.json"
const C_PATH := "user://revision_a_checkpoint.json"

func rm(p: String) -> void:
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func _initialize() -> void:
	var Rs = load(RULES)
	var Pr = load(PROG)
	var Pol = load(POL)
	rm(P_PATH)
	rm(C_PATH)
	var p = Pr.new(P_PATH, C_PATH)
	p.call("reset_all")
	var g = Rs.new()
	g.call("new_game", int(p.call("world_seed")), 1, {"skip_intro": true})
	p.call("begin_attempt", g)
	var mem := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var guard := 0
	while str(g.state.status) == "playing" and str(g.state.phase) != "extraccion" and guard < 900:
		guard += 1
		Pol.call("step", g, "experto", mem, rng)
		p.call("checkpoint_tick", g)
	p.call("checkpoint_tick", g)
	g.call("advance_to", 900.0)
	p.call("record_result", g)
	var h = Rs.new()
	h.call("new_game", int(p.call("world_seed")), 2, {"skip_intro": true})
	p.call("begin_attempt", h)
	for grp in ["rodriguez", "portal", "arias"]:
		h.call("issue_order", grp, "position")
	guard = 0
	while str(h.state.status) == "playing" and guard < 900:
		guard += 1
		h.call("tick", 1.0)
		p.call("checkpoint_tick", h)
	p.call("record_result", h)
	var offered := false
	for o in p.call("retry_options"):
		if str(o.id) == "salida":
			offered = bool(o.available)
	var k = Rs.new()
	k.call("new_game", int(p.call("world_seed")), 3, {"skip_intro": true})
	var res: Dictionary = p.call("restore_checkpoint", k, "salida")
	var consistent: bool = offered == bool(res.get("ok", false))
	print("esperado: «Reintentar la salida» se ofrece solo si restore_checkpoint(«salida») funciona")
	print("obtenido: intento 1 terminó en %s/%s con «salida» guardada; intento 2 (%s/%s) reescribió «posiciones»; retry_options ofrece salida=%s y restore_checkpoint(salida) -> %s" % [str(g.state.status), str(g.state.reason), str(h.state.status), str(h.state.reason), str(offered), str(res)])
	rm(P_PATH)
	rm(C_PATH)
	rm(P_PATH + ".tmp")
	print("RESULTADO: %s" % ("PASA" if consistent else "FALLA"))
	quit(0 if consistent else 1)
