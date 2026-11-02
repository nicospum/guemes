extends RefCounted
## Stub de HumahuacaProgress (CONTRATO 3.3 y 7). Lo escribe reglas_historia en R1.0 y queda CONGELADO desde el merge (se corrige solo por addendum).
## Guarda progreso, no partida, en user://humahuaca_progress.json con escritura atómica: intentos, racha de derrotas, mejor medalla, victoria, mejor golpe,
## y el mundo (una lista fija de semillas: no cambia hasta ganar). Sin diario, sin puntos de control, sin ayudas y sin tutorial: lo que el contrato pide
## que exista pero que llega con la clase real (R1 y R2b) devuelve valores válidos y vacíos.
## Un archivo dañado o de otra versión se descarta con `load_note` y se empieza de cero: nunca bloquea. No toca campaign.json ni los guardados de partida.
## Independencia (V19): solo importa vocabularios. Recibe `rules` por parámetro (stub o clase real) y usa su `campaign_report()`.

const V = preload("res://scripts/humahuaca/humahuaca_vocab.gd")
const R = preload("res://scripts/humahuaca/rules/vocab_rules.gd")

const PROGRESS_VERSION := 1

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
var _campaign: Dictionary = {}

func _init(path: String = V.PROGRESS_PATH, checkpoint_path: String = V.CHECKPOINT_PATH) -> void:
	_path = path
	_checkpoint_path = checkpoint_path
	_campaign = V.load_json(V.RULES_PATH).get("campaign", {})

func _line(key: String, vars: Dictionary = {}) -> String:
	var out := str((_campaign.get("lines", {}) as Dictionary).get(key, ""))
	for k in vars:
		out = out.replace("{" + str(k) + "}", str(vars[k]))
	return out

func _reset_fields() -> void:
	attempts = 0
	defeats_in_row = 0
	best_medal = ""
	won = false
	best_golpe = 0.0
	_world_index = 0
	_tutorial_seen = false

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
	return d.best_medal is String and R.MEDALS.has(d.best_medal) and d.won is bool and d.tutorial_seen is bool

func save_progress() -> bool:
	var data := {"version": PROGRESS_VERSION, "attempts": attempts, "defeats_in_row": defeats_in_row, "best_medal": best_medal, "won": won, "best_golpe": best_golpe,
		"world_index": _world_index, "tutorial_seen": _tutorial_seen}
	var file := FileAccess.open(_path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t", true, true))
	file.flush()
	file.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(_path + ".tmp"), ProjectSettings.globalize_path(_path)) == OK

# ---------------------------------------------------------------------------------------------------------------------
# Mundo e intentos

func world_seed() -> int:
	var seeds: Array = _campaign.get("world_seeds", [1817])
	return int(seeds[_world_index % maxi(seeds.size(), 1)])

## Mundo nuevo: pasa a la semilla siguiente de la lista fija.
func new_world() -> void:
	_world_index += 1

## Cuenta el intento. El stub no tiene diario ni ventaja de la experiencia, así que no le da nada a `rules`.
func begin_attempt(_rules: RefCounted) -> Dictionary:
	attempts += 1
	save_progress()
	return {"attempt": attempts, "seed": world_seed(), "defeats_in_row": defeats_in_row, "marks": [], "mercy_level": 0}

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
	if victory:
		won = true
		defeats_in_row = 0
		best_golpe = maxf(best_golpe, golpe)
		if _medal_rank(medal) > _medal_rank(best_medal):
			best_medal = medal
	elif defeat:
		defeats_in_row += 1
	var label := str(rep.get("medal_label", ""))
	var record_line := _line("victoria", {"medalla": label, "golpe": roundi(golpe), "bajas": roundi(float(rep.get("loss_pct", 0.0)))}) if victory else _line("derrota", {"n": attempts, "racha": defeats_in_row})
	if best_medal != "":
		record_line += " · " + _line("mejor", {"medalla": best_medal})
	var lines: Array = [str(rep.get("cause", ""))]
	if str(rep.get("advice", "")) != "":
		lines.append(str(rep.get("advice", "")))
	var out := {"won": victory, "medal": medal, "medal_label": label, "record_line": record_line, "cause_id": str(rep.get("cause_id", "")), "cause": str(rep.get("cause", "")),
		"advice": str(rep.get("advice", "")), "hint": str(rep.get("advice", "")), "defeats_in_row": defeats_in_row, "offered_assists": offered_assists(rules), "lines": lines, "new_diary": [],
		"facts": {"frentes": taken, "golpe": golpe, "bajas": float(rep.get("loss_pct", 0.0)), "tiempo": float(rep.get("elapsed", 0.0))},
		"next_available": victory, "next_label": str(_campaign.get("next_label", ""))}
	if victory:
		new_world()
	save_progress()
	return out

# ---------------------------------------------------------------------------------------------------------------------
# Ayudas, diario y puntos de control (llegan con la clase real; el stub devuelve vacíos válidos)

func offered_assists(_rules: RefCounted) -> Array:
	return []

func apply_assists(_rules: RefCounted, _ids: Array) -> Array:
	return []

func diary_entries() -> Array:
	return []

func diary_marks() -> Array:
	return []

func checkpoint_tick(_rules: RefCounted) -> void:
	pass

func has_checkpoint(_kind: String) -> bool:
	return false

func checkpoint_time(_kind: String) -> float:
	return -1.0

func restore_checkpoint(_rules: RefCounted, _kind: String) -> Dictionary:
	return {"ok": false, "reason": _line("sin_control")}

func retry_options() -> Array:
	var labels: Dictionary = _campaign.get("retry", {})
	var out: Array = []
	for id in R.RETRY:
		out.append({"id": id, "label": str(labels.get(id, id)), "available": id == "mismo_mundo" or id == "mundo_nuevo", "at_s": 0.0})
	return out

func tutorial_pending() -> bool:
	return not _tutorial_seen

func mark_tutorial_seen() -> void:
	_tutorial_seen = true
	save_progress()

func reset_all() -> void:
	_reset_fields()
	load_note = ""
	save_progress()
	if FileAccess.file_exists(_checkpoint_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_checkpoint_path))

## Solo la nota «Recomendado tras la Justina» del menú (el botón de Humahuaca ya no tiene candado).
func recommended_by_profile(main_progress: Dictionary) -> bool:
	return bool(main_progress.get("justina_ganada", false))
