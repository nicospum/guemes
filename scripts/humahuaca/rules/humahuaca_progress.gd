extends RefCounted
## HumahuacaProgress: el progreso del nivel «humahuaca» entre intentos (CONTRATO 3.3). Dueña: reglas_historia. Guarda PROGRESO, no partida, en
## user://humahuaca_progress.json y user://humahuaca_checkpoint.json (escritura atómica: .tmp y renombre). No toca campaign.json (campaign.gd descarta lo que no conoce y
## se reinicia si `version != 1`), ni save_justine.json, ni save_norte.json. Un archivo dañado o de otra versión se descarta con `load_note` y se empieza de cero: nunca bloquea.
##
## Qué recuerda: intentos, racha de derrotas, mejor medalla, si ganó y el mejor golpe; el mundo (una lista fija de semillas, rules.campaign.world_seeds: no cambia hasta ganar y
## al ganar se re-sortea); el diario (hasta 40 entradas, cada una con una marca tenue «anotado» para el intento siguiente: las marcas NO cuentan como reconocimiento) y si ya vio
## el tutorial. Dos puntos de control (CONTRATO 8.4): `posiciones` (las tres partidas en su puesto y aún sin descarga; Q-202: ya no a los 210 s sin nadie en su puesto) y `deposito` (al tomar el tercer frente);
## restaurarlos cuesta un intento y tarda un instante.
## Recibe las reglas por parámetro (la clase real o el stub) y usa solo su API pública: campaign_report(), snapshot(), restore_snapshot() y el state de solo lectura.
## Independencia (V19): solo importa vocabularios y datos.

const V = preload("res://scripts/humahuaca/humahuaca_vocab.gd")
const R = preload("res://scripts/humahuaca/rules/vocab_rules.gd")
const D = preload("res://scripts/humahuaca/rules/humahuaca_data.gd")

const PROGRESS_VERSION := 1
const CHECKPOINT_VERSION := 1

var load_note: String = ""
var attempts: int = 0
var defeats_in_row: int = 0
var best_medal: String = ""
var won: bool = false
var best_golpe: float = 0.0

var _path: String
var _checkpoint_path: String
var _world_index: int = 0
var _tutorial_seen: bool = false
var _diary: Array = []
var _campaign: Dictionary = {}
var _cp: Dictionary = {}  # kind → {"time": float, "game_id": String} (el estado va en el archivo)
var _cp_seen: Dictionary = {}  # kind → game_id del intento en que ya se guardó
var _last_version := 0  # state_version de la última partida vista: si baja, empezó otra (o se restauró un control) y los controles se vuelven a guardar

func _init(path: String = V.PROGRESS_PATH, checkpoint_path: String = V.CHECKPOINT_PATH) -> void:
	_path = path
	_checkpoint_path = checkpoint_path
	_campaign = D.rules().get("campaign", {})
	_read_checkpoint_index()

func _line(key: String, vars: Dictionary = {}) -> String:
	return D.fmt(str((_campaign.get("lines", {}) as Dictionary).get(key, "")), vars)

func _reset_fields() -> void:
	attempts = 0
	defeats_in_row = 0
	best_medal = ""
	won = false
	best_golpe = 0.0
	_world_index = 0
	_tutorial_seen = false
	_diary = []

# ---------------------------------------------------------------------------------------------------------------------
# Archivo

## true si leyó un progreso válido; false si no había archivo o estaba dañado (en ese caso `load_note` lo explica y el progreso queda en cero).
func load_progress() -> bool:
	load_note = ""
	if not FileAccess.file_exists(_path):
		return false
	var parser := JSON.new()
	var parsed: Variant = parser.data if parser.parse(FileAccess.get_file_as_string(_path)) == OK else null
	if not _valid(parsed):
		_reset_fields()
		load_note = _line("progreso_danado")
		return false
	var d: Dictionary = parsed
	attempts = int(d.attempts)
	defeats_in_row = int(d.defeats_in_row)
	best_medal = str(d.best_medal)
	won = bool(d.won)
	best_golpe = float(d.best_golpe)
	_world_index = int(d.world_index)
	_tutorial_seen = bool(d.tutorial_seen)
	_diary = (d.get("diary", []) as Array).duplicate(true) if d.get("diary", []) is Array else []
	return true

func _valid(v: Variant) -> bool:
	if not (v is Dictionary):
		return false
	var d: Dictionary = v
	for key in ["version", "attempts", "defeats_in_row", "best_medal", "won", "best_golpe", "world_index", "tutorial_seen"]:
		if not d.has(key):
			return false
	if not (d.version is int or d.version is float) or int(d.version) != PROGRESS_VERSION:
		return false
	for key in ["attempts", "defeats_in_row", "world_index"]:
		if not ((d[key] is int or d[key] is float) and float(d[key]) >= 0.0 and float(d[key]) <= 1000000.0):
			return false
	if not (d.best_golpe is int or d.best_golpe is float) or float(d.best_golpe) < 0.0 or float(d.best_golpe) > 100.0:
		return false
	if d.has("diary"):
		if not (d.diary is Array) or (d.diary as Array).size() > int(_campaign.get("diary_max_entries", 40)):
			return false
		for e in d.diary:
			if not _valid_entry(e):
				return false
	return d.best_medal is String and R.MEDALS.has(d.best_medal) and d.won is bool and d.tutorial_seen is bool

## Una entrada del diario tal como la lee diary_marks(): intento, clase, texto y lugar (x y z en el mapa, o -1 si no tiene). Un tipo equivocado descarta el archivo entero
## (con nota): leerlo así reventaría en `float(null)` al armar las marcas del intento siguiente.
func _valid_entry(e: Variant) -> bool:
	if not (e is Dictionary):
		return false
	var entry: Dictionary = e
	if not (entry.get("text") is String) or not (entry.get("kind") is String) or (entry.text as String).length() > 400 or (entry.kind as String).length() > 40:
		return false
	var sz := D.map_size()
	for pair in [["x", sz.x], ["z", sz.y]]:
		var v: Variant = entry.get(pair[0])
		if not ((v is float or v is int) and is_finite(float(v)) and float(v) >= -1.0 and float(v) <= float(pair[1])):
			return false
	## sin lugar son las dos en -1; con lugar, las dos dentro del mapa (una sola negativa daba una marca fuera del esquema y cada intento nacía inválido, B-5)
	if (float(entry.x) < 0.0) != (float(entry.z) < 0.0) or (float(entry.x) < 0.0 and (float(entry.x) != -1.0 or float(entry.z) != -1.0)):
		return false
	if entry.has("attempt") and not ((entry.attempt is float or entry.attempt is int) and is_finite(float(entry.attempt)) and float(entry.attempt) >= 0.0 and float(entry.attempt) <= 1000000.0):
		return false
	return not entry.has("tag") or entry.tag is String

func save_progress() -> bool:
	var data := {"version": PROGRESS_VERSION, "attempts": attempts, "defeats_in_row": defeats_in_row, "best_medal": best_medal, "won": won, "best_golpe": best_golpe,
		"world_index": _world_index, "tutorial_seen": _tutorial_seen, "diary": _diary}
	return _write_atomic(_path, data)

static func _write_atomic(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t", true, true))
	file.flush()
	file.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path)) == OK

# ---------------------------------------------------------------------------------------------------------------------
# Mundo e intentos

func world_seed() -> int:
	var seeds: Array = _campaign.get("world_seeds", [1817])
	return int(seeds[_world_index % maxi(seeds.size(), 1)])

## Mundo nuevo: pasa a la semilla siguiente de la lista fija. Los puntos de control del mundo anterior dejan de valer (R-02): se borran del índice y del archivo.
func new_world() -> void:
	_world_index += 1
	_clear_checkpoints()

func _clear_checkpoints() -> void:
	_cp = {}
	_cp_seen = {}
	if FileAccess.file_exists(_checkpoint_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_checkpoint_path))

## Cuenta el intento y le da a `rules` las marcas del diario (con su etiqueta «anotado») y la ventaja de la experiencia (ninguna en R1: se muestra en el parte si la hubiera).
func begin_attempt(rules: RefCounted) -> Dictionary:
	attempts += 1
	_cp_seen = {}
	var marks := diary_marks()
	if rules != null and rules.has_method("set_diary_marks"):
		rules.call("set_diary_marks", marks)
	save_progress()
	return {"attempt": attempts, "seed": world_seed(), "defeats_in_row": defeats_in_row, "marks": marks, "mercy_level": 0}

func _medal_rank(medal: String) -> int:
	return maxi(0, R.MEDALS.find(medal))

func record_result(rules: RefCounted) -> Dictionary:
	var rep: Dictionary = rules.call("campaign_report")
	var victory := str(rep.get("status", "")) == "victory"
	var defeat := str(rep.get("status", "")) == "defeat"
	var gp: Dictionary = rep.get("golpe", {})
	var golpe := float(gp.get("entregado", 0.0)) + float(gp.get("destruido", 0.0)) + float(gp.get("oculto", 0.0))
	var taken := 0
	for o in rep.get("objectives", []):
		if str(o.get("estado", "")) == "tomado":
			taken += 1
	var medal := str(rep.get("medal", ""))
	var new_entries: Array = []
	if victory:
		won = true
		defeats_in_row = 0
		best_golpe = maxf(best_golpe, golpe)
		if _medal_rank(medal) > _medal_rank(best_medal):
			best_medal = medal
	elif defeat:
		defeats_in_row += 1
	if victory or defeat:
		new_entries = _note_diary(rules, rep, golpe)
	var label := str(rep.get("medal_label", ""))
	var record_line := _line("victoria", {"medalla": label, "golpe": roundi(golpe), "bajas": roundi(float(rep.get("loss_pct", 0.0)))}) if victory else _line("derrota", {"n": attempts, "racha": defeats_in_row})
	if best_medal != "":
		record_line += " · " + _line("mejor", {"medalla": best_medal})
	var lines: Array = [str(rep.get("cause", ""))]
	if str(rep.get("advice", "")) != "":
		lines.append(str(rep.get("advice", "")))
	var out := {"won": victory, "medal": medal, "medal_label": label, "record_line": record_line, "cause_id": str(rep.get("cause_id", "")), "cause": str(rep.get("cause", "")),
		"advice": str(rep.get("advice", "")), "hint": _hint_for(rep), "defeats_in_row": defeats_in_row, "offered_assists": offered_assists(rules), "lines": lines, "new_diary": new_entries,
		"facts": {"frentes": taken, "golpe": golpe, "bajas": float(rep.get("loss_pct", 0.0)), "tiempo": float(rep.get("elapsed", 0.0))},
		"next_available": victory, "next_label": str(_campaign.get("next_label", ""))}
	if victory:
		new_world()
	save_progress()
	return out

## El consejo del parte: el de la causa y, si es la segunda derrota seguida por la misma razón, la pista concreta del diario (un consejo que rota, sin repetir el de siempre).
func _hint_for(rep: Dictionary) -> String:
	var advice := str(rep.get("advice", ""))
	if str(rep.get("status", "")) != "defeat" or defeats_in_row < 2:
		return advice
	var tips: Array = (_campaign.get("tips", {}) as Dictionary).get(str(rep.get("cause_id", "")), [])
	if tips.is_empty():
		return advice
	return str(tips[(defeats_in_row - 2) % tips.size()])

# ---------------------------------------------------------------------------------------------------------------------
# Diario y marcas

## Anota lo aprendido en este intento (máximo `campaign.diary_max_entries`, las más viejas se van) y devuelve las entradas nuevas.
func _note_diary(rules: RefCounted, rep: Dictionary, golpe: float) -> Array:
	var fresh: Array = []
	var cause := str(rep.get("cause_id", ""))
	var key := cause if cause != "" else "victoria"
	var texts: Dictionary = _campaign.get("diary", {})
	if not texts.has(key):
		return fresh
	var at := Vector2(-1.0, -1.0)
	var place := ""
	var state: Variant = rules.get("state")
	if state is Dictionary:
		match cause:
			"descubiertos":
				var pre: Array = state.get("alarm", {}).get("pre_signal", [])
				if not pre.is_empty():
					at = D.hito(str(D.rules().objectives[str(pre[0])].hito))
					place = str(D.rules().objectives[str(pre[0])].place)
			"interceptados":
				at = D.hito("entrada_sur")
				place = str((D.rules().texts.lugares.hitos as Dictionary).get("entrada_sur", ""))
			"frente_roto":
				for u in state.get("units", []):
					if str(u.stage) == "routed":
						var fid := str(D.rules().groups[str(u.id)].front)
						if str(state.get("objectives", {}).get(fid, {}).get("state", "")) == "tomado":
							## su frente ya era suyo: se rompió frente a otro que seguía en pie (el más cercano), y ahí va la marca (A-04)
							var best_d := 1.0e9
							for other in V.OBJECTIVES:
								if str(state.objectives[other].state) == "tomado":
									continue
								var d := D.hito(str(D.rules().objectives[other].hito)).distance_to(Vector2(float(u.x), float(u.z)))
								if d < best_d:
									best_d = d
									fid = other
						at = D.hito(str(D.rules().objectives[fid].hito))
						place = str(D.rules().objectives[fid].place)
						break
	var entry := {"attempt": attempts, "kind": key, "text": D.fmt(str(texts[key]), {"t": D.clock(float(rep.get("elapsed", 0.0))), "lugar": place, "deLugar": D.de_place(place), "aLugar": D.a_place(place), "golpe": roundi(golpe)}),
		"x": at.x, "z": at.y, "tag": "diseno"}
	_diary.append(entry)
	var cap := int(_campaign.get("diary_max_entries", 40))
	while _diary.size() > cap:
		_diary.pop_front()
	fresh.append(entry)
	return fresh

func diary_entries() -> Array:
	return _diary.duplicate(true)

## Las marcas tenues «anotado» del próximo intento: una por entrada del diario que tenga lugar. No son reconocimiento (no revelan la guardia ni bajan el riesgo).
func diary_marks() -> Array:
	var out: Array = []
	for e in _diary:
		if float(e.get("x", -1.0)) < 0.0 or float(e.get("z", -1.0)) < 0.0:
			continue
		out.append({"key": "diario_%d_%s" % [int(e.get("attempt", 0)), str(e.kind)], "kind": str(e.kind), "text": str(_campaign.get("marks", {}).get("anotado", "anotado")) + ": " + str(e.text),
			"x": float(e.x), "z": float(e.z), "confirmed": false})
	return out

# ---------------------------------------------------------------------------------------------------------------------
# Ayudas (llegan con R2b; siempre visibles y marcadas, nunca se imponen)

func offered_assists(_rules: RefCounted) -> Array:
	return []

func apply_assists(_rules: RefCounted, _ids: Array) -> Array:
	return []

# ---------------------------------------------------------------------------------------------------------------------
# Puntos de control

func _read_checkpoint_index() -> void:
	_cp = {}
	if not FileAccess.file_exists(_checkpoint_path):
		return
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(_checkpoint_path)) != OK or not (parser.data is Dictionary):
		return
	var d: Dictionary = parser.data
	if not (d.get("version", null) is float or d.get("version", null) is int) or int(d.version) != CHECKPOINT_VERSION or not (d.get("points", null) is Dictionary):
		return
	for kind in d.points:
		var p: Variant = d.points[kind]
		if p is Dictionary and R.RETRY.has(str(kind)) and (p.get("time", null) is float or p.get("time", null) is int) and is_finite(float(p.time)) and p.get("state", null) is Dictionary:
			_cp[str(kind)] = {"time": float(p.time), "game_id": str((p.state as Dictionary).get("game_id", ""))}

func _write_checkpoint(kind: String, rules: RefCounted) -> void:
	var points := {}
	if FileAccess.file_exists(_checkpoint_path):
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string(_checkpoint_path)) == OK and parser.data is Dictionary and (parser.data as Dictionary).get("points", null) is Dictionary:
			points = (parser.data as Dictionary).points
	var snap: Dictionary = rules.call("snapshot")
	if rules.has_method("validate_snapshot") and not bool((rules.call("validate_snapshot", snap) as Dictionary).get("ok", false)):
		return  # un estado que no valida no se escribe: se lo rechazaría al restaurar (A-07)
	points[kind] = {"time": float(snap.elapsed), "state": snap}
	if kind == "posiciones":
		points.erase("salida")  # un control de la salida de un intento anterior ya no sirve
	if _write_atomic(_checkpoint_path, {"version": CHECKPOINT_VERSION, "points": points}):
		_read_checkpoint_index()  # el índice dice lo mismo que el archivo: lo que se borró de ahí (la «salida» vieja) deja de ofrecerse (R-01)

## Barato (se llama cada cuadro): guarda `posiciones` cuando las tres partidas esperan la señal con tiempo para el golpe (Q-202: ya no «a los 210 s sin señal») y
## `salida` al empezar la extracción.
func checkpoint_tick(rules: RefCounted) -> void:
	var state: Variant = rules.get("state")
	if not (state is Dictionary) or (state as Dictionary).is_empty() or str(state.get("status", "")) != "playing":
		return
	var gid := str(state.game_id)
	var t := float(state.elapsed)
	if int(state.state_version) < _last_version:
		_cp_seen = {}
	_last_version = int(state.state_version)
	if not _cp_seen.has("posiciones") or str(_cp_seen.posiciones) != gid:
		if not bool(state.alarm.signaled) and str(state.phase) == "aproximacion":
			var ready := 0
			for u in state.units:
				if V.COMBAT_GROUPS.has(str(u.id)) and str(u.stage) == "waiting_signal":
					ready += 1
			# Q-202 (QA ronda 2): antes también se escribía «a los 210 s sin señal» aunque nadie hubiera llegado (derrota pasiva: las cinco partidas en la zona de
			# partida a 56 s del alba, una derrota segura con la pista «te ahorrás la marcha» falsa). Ahora el control solo existe si deja una partida ganable: las tres
			# partidas de combate en su puesto esperando la señal y todavía con tiempo para el golpe (antes de que el alba las descubra). La victoria exige los tres frentes.
			if ready >= V.COMBAT_GROUPS.size() and t < float(D.rules().time.dawn_discovery_s) - float(D.rules().time.get("checkpoint_min_left_s", 30.0)):
				_cp_seen["posiciones"] = gid
				_write_checkpoint("posiciones", rules)
	if str(state.phase) == "extraccion" and (not _cp_seen.has("salida") or str(_cp_seen.salida) != gid):
		_cp_seen["salida"] = gid
		_write_checkpoint("salida", rules)

func has_checkpoint(kind: String) -> bool:
	return _cp.has(kind)

func checkpoint_time(kind: String) -> float:
	return float(_cp[kind].time) if _cp.has(kind) else -1.0

## Vuelve a un punto de control: reemplaza el estado de `rules` (restore_snapshot valida antes de tocar nada) y cuenta el intento.
func restore_checkpoint(rules: RefCounted, kind: String) -> Dictionary:
	if not _cp.has(kind) or not FileAccess.file_exists(_checkpoint_path):
		return {"ok": false, "reason": _line("sin_control")}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(_checkpoint_path)) != OK or not (parser.data is Dictionary):
		return {"ok": false, "reason": _line("sin_control")}
	var points: Variant = (parser.data as Dictionary).get("points", {})
	if not (points is Dictionary) or not (points as Dictionary).has(kind) or not (points[kind] is Dictionary) or not ((points[kind] as Dictionary).get("state", null) is Dictionary):
		return {"ok": false, "reason": _line("sin_control")}
	var cp_state: Dictionary = (points[kind] as Dictionary).state
	if str(cp_state.get("status", "")) != "playing":
		return {"ok": false, "reason": _line("sin_control")}  # un control de una partida terminada no se restaura (B-2); los de otro mundo ya no existen (new_world los borra)
	var res: Dictionary = rules.call("restore_snapshot", cp_state)
	if not bool(res.get("ok", false)):
		return {"ok": false, "reason": str(res.get("reason", _line("sin_control")))}
	attempts += 1
	_cp_seen.erase(kind)
	_cp_seen[kind] = str((rules.get("state") as Dictionary).get("game_id", ""))
	save_progress()
	return {"ok": true, "reason": ""}

func retry_options() -> Array:
	var labels: Dictionary = _campaign.get("retry", {})
	var out: Array = []
	for id in R.RETRY:
		var available: bool = id == "mismo_mundo" or id == "mundo_nuevo" or has_checkpoint(id)
		out.append({"id": id, "label": str(labels.get(id, id)), "available": available, "at_s": checkpoint_time(id) if has_checkpoint(id) else 0.0})
	return out

# ---------------------------------------------------------------------------------------------------------------------
# Perfil

func tutorial_pending() -> bool:
	return not _tutorial_seen

func mark_tutorial_seen() -> void:
	_tutorial_seen = true
	save_progress()

func reset_all() -> void:
	_reset_fields()
	load_note = ""
	_cp = {}
	_cp_seen = {}
	save_progress()
	if FileAccess.file_exists(_checkpoint_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_checkpoint_path))

## Solo la nota «Recomendado tras la Justina» del menú (el botón de Humahuaca ya no tiene candado).
func recommended_by_profile(main_progress: Dictionary) -> bool:
	return bool(main_progress.get("justina_ganada", false))
