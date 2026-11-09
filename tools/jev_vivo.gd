extends SceneTree
## Prueba de aceptación de Jev en vivo (docs/JEV.md, «Evidencia y prueba que falta»):
## arranca una partida del norte, resuelve una ronda consultando a Jev y comprueba
## source «live», applied, el modelo que respondió y el cambio de estado de la partida.
## La clave sale SOLO del entorno (TYPESAFE_API_KEY) o de user://jev.cfg; este script
## nunca la imprime ni la escribe: informa únicamente si hay o no credencial.
## Uso (perfil aislado; ver docs/JEV.md):
##   godot --headless --path . --script tools/jev_vivo.gd -- [--out=<carpeta absoluta>] [--esperar=20]
## Sale con 0 si la decisión fue en vivo y se aplicó; 1 si cayó en la alternativa local; 2 si no se pudo probar.
var game: Node
var decisions: Array = []
var out_dir := ""
var wait_s := 20.0
var budget_s := -1.0   # --presupuesto=<s>: diagnóstico; el juego usa 2 s (jev_client.request_budget_sec)

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--esperar="): wait_s = float(arg.trim_prefix("--esperar="))
		elif arg.begins_with("--presupuesto="): budget_s = float(arg.trim_prefix("--presupuesto="))
	call_deferred("_run")

func _frames(n: int) -> void:
	for i in range(n): await process_frame

func _run() -> void:
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await _frames(10)
	var jev = game.jev
	jev.force_local = false
	if budget_s > 0.0: jev.request_budget_sec = budget_s
	var report := {"presupuesto_s": jev.request_budget_sec, "prueba": "jev_vivo", "fecha_utc": Time.get_datetime_string_from_system(true), "credencial_presente": bool(jev.has_credentials()), "modelo_pedido": jev._model()}
	if not report.credencial_presente:
		report["resultado"] = "sin credencial: no se puede probar en vivo"
		_finish(report, 2)
		return
	jev.decision_ready.connect(func(d: Dictionary): decisions.append(d.duplicate(true)))
	game._start_game("norte")
	await _frames(30)
	jev.force_local = false
	var rules = game.rules
	var before := {"round": int(rules.state.round), "state_version": int(rules.state.state_version), "enemy": JSON.stringify(rules.state.enemy)}
	var intel: Dictionary = rules.north_enemy_intel()
	report["intencion_conocida_antes"] = bool(intel.get("known", false))
	if report.intencion_conocida_antes:
		report["resultado"] = "la intención ya se conocía por reconocimiento: la ronda no consulta a Jev"
		_finish(report, 2)
		return
	game._resolve_round()
	var t0 := Time.get_ticks_msec()
	while decisions.is_empty() and Time.get_ticks_msec() - t0 < int(wait_s * 1000.0):
		await process_frame
	await _frames(20)
	report["espera_ms"] = Time.get_ticks_msec() - t0
	if decisions.is_empty():
		report["resultado"] = "sin respuesta en %d s" % int(wait_s)
		report["estado_jev"] = str(jev.status_text)
		_finish(report, 2)
		return
	var d: Dictionary = decisions[-1]
	var applied := false
	for row in jev.decision_log:
		if row is Dictionary and int(row.get("request_id", -1)) == int(d.get("request_id", -2)):
			applied = bool(row.get("applied", false))
	report["decision"] = {"source": str(d.get("source", "")), "choice": str(d.get("choice", "")), "model": str(d.get("model", "")), "latency_ms": d.get("latency_ms", null), "reason": str(d.get("reason", "")), "request_id": int(d.get("request_id", -1)), "confidence": d.get("confidence", null), "probabilities": d.get("probabilities", {}), "payload_sha256": str(d.get("payload_sha256", ""))}
	report["applied"] = applied
	report["estado_jev"] = str(jev.status_text)
	report["ronda_antes"] = before.round
	report["ronda_despues"] = int(rules.state.round)
	report["state_version_antes"] = before.state_version
	report["state_version_despues"] = int(rules.state.state_version)
	report["enemigo_cambio"] = JSON.stringify(rules.state.enemy) != before.enemy
	var log_path := "user://jev_decisions.jsonl"
	report["registro"] = ProjectSettings.globalize_path(log_path)
	report["registro_tiene_la_decision"] = FileAccess.file_exists(log_path) and FileAccess.get_file_as_string(log_path).contains(str(d.get("payload_sha256", "-")))
	var live: bool = report.decision.source == "live" and bool(report.applied) and int(report.ronda_despues) > int(report.ronda_antes)
	report["resultado"] = "VIVO: decisión de Jev aplicada a la partida" if live else "ALTERNATIVA LOCAL: " + str(d.get("reason", ""))
	_finish(report, 0 if live else 1)

func _finish(report: Dictionary, code: int) -> void:
	var text := JSON.stringify(report, "  ")
	print(text)
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)
		var f := FileAccess.open(out_dir.path_join("jev_vivo.json"), FileAccess.WRITE)
		if f:
			f.store_string(text)
			f.close()
	quit(code)
