extends SceneTree
## Revisión nube, lente A (reglas): tick() consume pasos mientras `accumulator >= STEP - 1e-9` (humahuaca_rules.gd l. 241): si la suma de dt queda
## apenas por debajo de un múltiplo de 0,25 (tick(7,3) + tick(0,1) + tick(0,1) = 7,4999999999999998), el acumulador termina en −1,7e-16 y el esquema
## del guardado exige accumulator en [0, 60]: validate_snapshot falla, save_game devuelve ERR_INVALID_DATA y un punto de control escrito en ese instante
## (HumahuacaProgress._write_checkpoint guarda snapshot() sin validar) no se puede restaurar. Con ticks de 1,0 s el acumulador sigue negativo.
## Falla hoy: sale con 1.

const RULES := "res://scripts/humahuaca/rules/humahuaca_rules.gd"
const SAVE := "user://revision_a_acumulador.json"

func _initialize() -> void:
	if OS.get_user_data_dir().to_lower().find("ap_iso") < 0:
		push_error("perfil NO aislado: exportá APPDATA=\"$TEMP/ap_iso_revision\" antes de correr (la prueba escribe o borra archivos de user://)")
		quit(2)
		return
	var Rs = load(RULES)
	var r = Rs.new()
	r.call("new_game", 1817, 1, {"phase": "ataque"})
	r.call("tick", 7.3)
	r.call("tick", 0.1)
	r.call("tick", 0.1)
	var acc := float(r.state.accumulator)
	var chk: Dictionary = r.call("validate_snapshot", r.call("snapshot"))
	var saved: int = r.call("save_game", SAVE)
	r.call("tick", 1.0)
	var acc2 := float(r.state.accumulator)
	var ok := acc >= 0.0 and bool(chk.ok) and saved == OK and acc2 >= 0.0
	print("esperado: tras tick(7,3), tick(0,1), tick(0,1) el acumulador queda en [0, 0,25), validate_snapshot da ok y save_game devuelve OK")
	print("obtenido: accumulator=%.20f validate=%s «%s» (%s) save_game=%d; tras un tick(1,0) más: accumulator=%.20f" % [acc, str(chk.ok), str(chk.reason), str(chk.get("path", "")), saved, acc2])
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("RESULTADO: %s" % ("PASA" if ok else "FALLA"))
	quit(0 if ok else 1)
