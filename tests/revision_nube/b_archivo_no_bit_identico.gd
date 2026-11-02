extends SceneTree
## Revisión nube, lente B (guardado y carga). Falla hoy (dentro de la tolerancia 1e-6 del CONTRATO 3.2.4: es un hallazgo BAJO, documentado).
## Hallazgo: save_game + load_game no devuelve el mismo estado bit a bit: los flotantes vuelven corridos en el último dígito (yaw_deg, fatigue, strength,
## events_per_min). La causa es del motor: en Godot 4.7.2 `JSON.parse` no redondea bien lo que `JSON.stringify(…, full_precision = true)` escribió (1 524 de 20 000
## doubles al azar no vuelven iguales; ver la sonda jsonprec2.gd de la revisión). restore_snapshot (en memoria) sí es idéntico. Hoy no cambia la partida (200 s
## después las dos siguen iguales salvo esos dígitos), pero el guardado no es «el mismo estado» y cualquier comparación exacta entre original y cargada falla.
## Uso: godot --headless --path . --script tests/revision_nube/b_archivo_no_bit_identico.gd   (perfil user:// aislado: escribe user://rn_b_rt.json)
## Sale con 1 si falla (difieren bits) y 0 si pasa.

func J(d: Variant) -> String:
	return JSON.stringify(d, "", true, true)

func strip(s: Dictionary) -> Dictionary:
	var d: Dictionary = s.duplicate(true)
	for k in ["game_id", "previous_game_id", "state_version", "log"]:
		d.erase(k)
	return d

func diff(a: Variant, b: Variant, path: String, out: Array) -> void:
	if a is Dictionary and b is Dictionary:
		for k in a:
			if b.has(k):
				diff(a[k], b[k], path + "." + str(k), out)
	elif a is Array and b is Array:
		for i in range(mini(a.size(), b.size())):
			diff(a[i], b[i], "%s[%d]" % [path, i], out)
	elif (a is float or a is int) and (b is float or b is int):
		if a != b:
			out.append("%s: %s vs %s" % [path, String.num(float(a), 17), String.num(float(b), 17)])
	elif a != b:
		out.append("%s: %s vs %s" % [path, str(a).left(40), str(b).left(40)])

func _initialize() -> void:
	var path := "user://rn_b_rt.json"
	var R = load("res://scripts/humahuaca/rules/humahuaca_rules.gd")
	var Pol = load("res://scripts/humahuaca/rules/humahuaca_policies.gd")
	var r = R.new()
	r.new_game(1817, 1, {})
	var mem := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var guard := 0
	while str(r.state.status) == "playing" and guard < 5000 and not (str(r.state.phase) == "extraccion" and float(r.state.elapsed) >= float(r.state.objectives.posta.taken_at) + 10.0):
		Pol.step(r, "experto", mem, rng)
		guard += 1
	var A: Dictionary = r.snapshot()
	var r2 = R.new()
	r2.restore_snapshot(A)
	var mem_ok := J(A) == J(r2.snapshot())
	r.save_game(path)
	var r3 = R.new()
	var lg: Dictionary = r3.load_game(path)
	var out: Array = []
	diff(strip(A), strip(r3.snapshot()), "", out)
	print("momento: t=%.2f fase=%s · restore_snapshot idéntico en memoria: %s · load_game ok: %s" % [float(A.elapsed), str(A.phase), str(mem_ok), str(lg.get("ok"))])
	print("esperaba: el estado cargado del archivo idéntico bit a bit al guardado (salvo game_id/previous_game_id/state_version/log)")
	print("obtuve:   %d rutas distintas: %s" % [out.size(), str(out)])
	var failed := not out.is_empty() or not mem_ok or not bool(lg.get("ok", false))
	print("RESULTADO: ", "FALLA" if failed else "PASA")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	quit(1 if failed else 0)
