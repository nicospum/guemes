extends SceneTree
## Revisión nube (hallazgo R-02): los puntos de control de un mundo sobreviven a la victoria. Tras ganar, new_world() pasa a la semilla siguiente,
## pero humahuaca_checkpoint.json y el índice _cp de HumahuacaProgress quedan con los controles «posiciones» y «salida» de la partida ganada;
## en la primera derrota del mundo nuevo el parte los ofrece y restore_checkpoint los acepta: el jugador vuelve a la partida del mundo anterior
## (otra semilla), incluso a la extracción con los tres frentes ya tomados. Sale con 1 si el defecto sigue; con 0 si está arreglado.
## Correr con perfil aislado:  godot --headless --path . --script tests/revision_nube/r_control_de_otro_mundo.gd
const Pol = preload("res://scripts/humahuaca/rules/humahuaca_policies.gd")

func _initialize() -> void:
	if OS.get_user_data_dir().to_lower().find("ap_iso") < 0:
		push_error("perfil NO aislado: exportá APPDATA=\"$TEMP/ap_iso_revision\" antes de correr")
		quit(2)
		return
	var R = load("res://scripts/humahuaca/rules/humahuaca_rules.gd")
	var P = load("res://scripts/humahuaca/rules/humahuaca_progress.gd")
	var base := "user://revnube_cpv"
	var prog = P.new(base + "_progress.json", base + "_checkpoint.json")
	prog.reset_all()
	var failures: Array = []
	var seed1: int = prog.world_seed()
	var rules = R.new()
	rules.new_game(seed1, 1, {})
	prog.begin_attempt(rules)
	var mem := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var guard := 0
	while str(rules.state.status) == "playing" and guard < 2000:
		guard += 1
		Pol.step(rules, "experto", mem, rng)
		prog.checkpoint_tick(rules)
	if str(rules.state.status) != "victory":
		failures.append("el experto no ganó la primera partida (semilla %d): %s" % [seed1, str(rules.state.status)])
	prog.record_result(rules)
	var seed2: int = prog.world_seed()
	if seed2 == seed1:
		failures.append("tras la victoria el mundo no cambió de semilla")
	var rules2 = R.new()
	rules2.new_game(seed2, 1, {})
	prog.begin_attempt(rules2)
	for i in range(30):
		rules2.tick(1.0)
		prog.checkpoint_tick(rules2)
	rules2.retreat_all()
	prog.record_result(rules2)
	var offered: Array = []
	for o in prog.retry_options():
		if (str(o.id) == "posiciones" or str(o.id) == "salida") and bool(o.available):
			offered.append("%s (%.0f s)" % [str(o.id), float(o.at_s)])
	var res: Dictionary = prog.restore_checkpoint(rules2, "salida")
	var restored_seed := int(rules2.state.get("seed", -1))
	print("mundo viejo=%d · mundo nuevo=%d · ofrecidos en el mundo nuevo: %s · restore salida=%s → seed=%d fase=%s" % [seed1, seed2, str(offered), str(res), restored_seed, str(rules2.state.get("phase", ""))])
	if not offered.is_empty():
		failures.append("en la primera derrota del mundo nuevo se ofrecen controles de la partida ganada en el mundo anterior: %s" % str(offered))
	if bool(res.get("ok", false)) and restored_seed == seed1:
		failures.append("restore_checkpoint(\"salida\") devolvió al jugador a la partida del mundo anterior (semilla %d, fase %s)" % [restored_seed, str(rules2.state.get("phase", ""))])
	prog.reset_all()
	for f in failures:
		printerr("FALLA: " + f)
	print("revision_nube r_control_de_otro_mundo: %s" % ("FALLA" if not failures.is_empty() else "PASA"))
	quit(1 if not failures.is_empty() else 0)
