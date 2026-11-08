extends SceneTree
## Revisión en la nube, lente C (determinismo). Hallazgo: new_game acepta cualquier semilla de 64 bits, pero el esquema del guardado (humahuaca_rules_schema.gd)
## exige `seed` en [-2147483647, 2147483647]. Con --hx-seed=2147483648 (o cualquier semilla fuera de ese rango) las reglas arman una partida que su propio
## validate_snapshot rechaza: save_game devuelve ERR_INVALID_DATA («no se pudo guardar») y campaign_report/record_of la cuentan como inválida, aunque la partida
## se juega normal (rng_state queda en 1). Esperado: o new_game reduce la semilla al rango que acepta el esquema, o el esquema acepta lo que new_game acepta.
## Sale con 1 si el defecto sigue (falla hoy) y con 0 si se corrigió.

const RULES := "res://scripts/humahuaca/rules/humahuaca_rules.gd"

func _initialize() -> void:
	if OS.get_user_data_dir().to_lower().find("ap_iso") < 0:
		push_error("perfil NO aislado: exportá APPDATA=\"$TEMP/ap_iso_revision\" antes de correr (la prueba escribe o borra archivos de user://)")
		quit(2)
		return
	var R = load(RULES)
	var failures := 0
	for seed_value in [2147483648, -2147483648, 4294967294, 9223372036854775807]:
		var r: RefCounted = R.new()
		var st: Dictionary = r.call("new_game", seed_value, 1, {})
		if st.is_empty():
			print("FALLA: new_game(%d) devolvió un estado vacío (esperaba una partida jugable)" % seed_value)
			failures += 1
			continue
		var check: Dictionary = r.call("validate_snapshot", r.call("snapshot"))
		var err: Error = r.call("save_game", "user://revision_c_seed_%d.json" % (seed_value % 1000))
		var ok := bool(check.get("ok", false)) and err == OK
		print("%s: new_game(%d) -> rng_state=%d, status=%s; validate_snapshot.ok=%s (%s); save_game=%d (esperaba ok=true y save_game=0)" % [
			"OK" if ok else "FALLA", seed_value, int(r.state.rng_state), str(r.state.status), str(check.get("ok", false)), str(check.get("reason", "")) + " path=" + str(check.get("path", "")), err])
		if not ok:
			failures += 1
	for seed_value in [2147483648, -2147483648, 4294967294, 9223372036854775807]:  # si save_game llegara a escribir, no dejar nada en user://
		var leftover := "user://revision_c_seed_%d.json" % (seed_value % 1000)
		if FileAccess.file_exists(leftover):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(leftover))
	quit(1 if failures > 0 else 0)
