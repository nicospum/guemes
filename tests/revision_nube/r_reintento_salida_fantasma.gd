extends SceneTree
## Revisión nube (hallazgo R-01): tras volver al control «posiciones», HumahuacaProgress sigue ofreciendo «Reintentar la salida» (retry_options
## lo da como disponible) aunque el archivo de controles ya no lo tiene: restore_checkpoint("salida") falla y la interfaz, en vez de avisar,
## arranca una partida nueva desde cero (humahuaca_ui_play.gd, _on_retry → _new_attempt). Sale con 1 si el defecto sigue; con 0 si está arreglado.
## Correr con perfil aislado:  godot --headless --path . --script tests/revision_nube/r_reintento_salida_fantasma.gd
const Pol = preload("res://scripts/humahuaca/rules/humahuaca_policies.gd")

func _initialize() -> void:
	if OS.get_user_data_dir().to_lower().find("ap_iso") < 0:
		push_error("perfil NO aislado: exportá APPDATA=\"$TEMP/ap_iso_revision\" antes de correr")
		quit(2)
		return
	var R = load("res://scripts/humahuaca/rules/humahuaca_rules.gd")
	var P = load("res://scripts/humahuaca/rules/humahuaca_progress.gd")
	var base := "user://revnube_cp"
	var prog = P.new(base + "_progress.json", base + "_checkpoint.json")
	prog.reset_all()
	var rules = R.new()
	rules.new_game(3, 1, {})
	prog.begin_attempt(rules)
	var mem := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var guard := 0
	while str(rules.state.status) == "playing" and str(rules.state.phase) != "extraccion" and guard < 2000:
		guard += 1
		Pol.step(rules, "experto", mem, rng)
		prog.checkpoint_tick(rules)
	var failures: Array = []
	if str(rules.state.phase) != "extraccion":
		failures.append("el experto no llegó a la extracción con la semilla 3 (fase %s)" % str(rules.state.phase))
	if not bool(prog.has_checkpoint("salida")):
		failures.append("no se escribió el control «salida» al entrar en la extracción")
	rules.retreat_all()  # una derrota cualquiera
	prog.record_result(rules)
	var res: Dictionary = prog.restore_checkpoint(rules, "posiciones")
	if not bool(res.get("ok", false)):
		failures.append("no se pudo volver a «posiciones»: " + str(res))
	for i in range(8):  # el jugador sigue jugando: checkpoint_tick corre cada cuadro
		rules.tick(1.0)
		prog.checkpoint_tick(rules)
	var offered := false
	for o in prog.retry_options():
		if str(o.id) == "salida" and bool(o.available):
			offered = true
	var res2: Dictionary = prog.restore_checkpoint(rules, "salida")
	var in_file := false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(base + "_checkpoint.json"))
	if parsed is Dictionary and (parsed as Dictionary).get("points", null) is Dictionary:
		in_file = (parsed.points as Dictionary).has("salida")
	print("ofrecida=%s · en_archivo=%s · restore_salida=%s" % [offered, in_file, str(res2)])
	if offered and not bool(res2.get("ok", false)):
		failures.append("retry_options ofrece «salida» (available=true) pero restore_checkpoint(\"salida\") falla: %s" % str(res2.get("reason", "")))
	prog.reset_all()
	for f in failures:
		printerr("FALLA: " + f)
	print("revision_nube r_reintento_salida_fantasma: %s" % ("FALLA" if not failures.is_empty() else "PASA"))
	quit(1 if not failures.is_empty() else 0)
