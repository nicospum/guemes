extends SceneTree
## Revisión nube, lente B (guardado y carga). Falla hoy.
## Hallazgo: los dos validadores no se ponen de acuerdo. `HumahuacaProgress._valid_entry` (humahuaca_progress.gd l. 105-118) acepta una entrada del diario con
## x >= 0 y z = -1 (cada coordenada se valida por separado contra [-1, tamaño]); `diary_marks()` (l. 250-257) solo descarta las entradas con x < 0, así que arma una
## marca con z = -1; `begin_attempt` se la da a las reglas (`set_diary_marks`) y el estado nuevo deja de pasar `validate_snapshot` (el esquema pide z en [0, 650]:
## humahuaca_rules_schema.gd l. 118). Desde ahí `save_game` devuelve ERR_INVALID_DATA en cada intento de ese perfil («No se pudo guardar la partida»).
## Uso: godot --headless --path . --script tests/revision_nube/b_diario_marca_z_negativa.gd   (perfil user:// aislado: escribe user://rn_b_progress.json)
## Sale con 1 si falla (el estado nuevo no valida / no se puede guardar) y 0 si pasa.

func _initialize() -> void:
	if OS.get_user_data_dir().to_lower().find("ap_iso") < 0:
		push_error("perfil NO aislado: exportá APPDATA=\"$TEMP/ap_iso_revision\" antes de correr (la prueba escribe o borra archivos de user://)")
		quit(2)
		return
	var ppath := "user://rn_b_progress.json"
	var cpath := "user://rn_b_checkpoint.json"
	var spath := "user://rn_b_save.json"
	var progress_json := {"version": 1, "attempts": 1, "defeats_in_row": 1, "best_medal": "", "won": false, "best_golpe": 0.0, "world_index": 0, "tutorial_seen": true,
		"diary": [{"attempt": 1, "kind": "amanecio", "text": "Amaneció sin la señal.", "x": 100.0, "z": -1.0, "tag": "diseno"}]}
	var f := FileAccess.open(ppath, FileAccess.WRITE)
	f.store_string(JSON.stringify(progress_json))
	f.close()
	var P = load("res://scripts/humahuaca/rules/humahuaca_progress.gd")
	var R = load("res://scripts/humahuaca/rules/humahuaca_rules.gd")
	var progress = P.new(ppath, cpath)
	var loaded: bool = progress.load_progress()
	print("load_progress acepta el archivo: %s (nota «%s»)" % [str(loaded), str(progress.load_note)])
	var rules = R.new()
	rules.new_game(1817, 2, {})
	progress.begin_attempt(rules)
	var marks: Array = rules.state.diary_marks
	var check: Dictionary = rules.validate_snapshot(rules.snapshot())
	var err: int = rules.save_game(spath)
	print("marcas del diario que recibió la partida: %s" % str(marks))
	print("esperaba: o bien load_progress rechaza la entrada (x >= 0 con z = -1), o bien la marca no se arma; y save_game == OK")
	print("obtuve:   load_progress=%s, validate_snapshot.ok=%s («%s»), save_game=%d" % [str(loaded), str(check.ok), str(check.get("reason", "")), err])
	var failed := loaded and (not bool(check.ok) or err != OK)
	print("RESULTADO: ", "FALLA" if failed else "PASA")
	for p in [ppath, cpath, spath]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	quit(1 if failed else 0)
