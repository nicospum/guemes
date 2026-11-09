extends SceneTree
## Revisión nube · lente F (enganches) · hermeticidad de las herramientas de QA del nivel «humahuaca».
##
## tools/hx_qa_tour.gd (l. 166 y 170) y tools/hx_agent_play.gd (l. 204) corren el nivel con `main.qa_mode = true` (y el recorrido además con
## opts.qa = true). Con eso el controlador escribe en el perfil `user://qa_humahuaca_progress.json` y `user://qa_humahuaca_checkpoint.json`
## (scripts/humahuaca/ui/humahuaca_ui_base.gd l. 418-420) y, si se guarda, `user://qa_save_humahuaca.json` (main._save_path con qa_mode, main.gd l. 908).
## La lista de archivos viejos que borran esas dos herramientas (hx_qa_tour.gd l. 77; hx_agent_play.gd l. 93) incluye `qa_humahuaca_progress.json`
## pero NO `qa_humahuaca_checkpoint.json` ni `qa_save_humahuaca.json`: un punto de control y un guardado de la corrida anterior sobreviven y la
## corrida siguiente los ve (HumahuacaProgress._read_checkpoint_index los carga al instanciarse y retry_options() ofrece «posiciones» desde el segundo 0;
## el menú de pausa ofrece «Cargar» porque el guardado existe).
##
## Esta prueba produce esos archivos jugando el nivel en modo QA, aplica EXACTAMENTE la lista de borrado leída de cada herramienta y falla (salida 1)
## si algún archivo qa_* del nivel sobrevive. Borra archivos de perfil: exige un perfil aislado (la ruta de user:// contiene «ap_iso»).
##   godot --headless --path . --script tests/revision_nube/f_hermeticidad_qa.gd

const TOOLS := ["res://tools/hx_qa_tour.gd", "res://tools/hx_agent_play.gd"]
const LEVEL_QA_FILES := ["qa_humahuaca_progress.json", "qa_humahuaca_checkpoint.json", "qa_save_humahuaca.json"]
const CLEAN := ["campaign.json", "justina_progress.json", "humahuaca_progress.json", "humahuaca_checkpoint.json", "settings.cfg", "save_humahuaca.json",
	"save_justine.json", "save_norte.json", "qa_humahuaca_progress.json", "qa_humahuaca_checkpoint.json", "qa_save_humahuaca.json"]

var game: Node
var checks := 0
var failures: Array = []


func _initialize() -> void:
	if OS.get_user_data_dir().to_lower().find("ap_iso") < 0:
		print("perfil NO aislado (%s): esta prueba borra archivos de perfil; salida 2" % OS.get_user_data_dir())
		quit(2)
		return
	_remove(CLEAN)
	call_deferred("_run")


func check(c: bool, what: String) -> bool:
	checks += 1
	if not c:
		failures.append(what)
	print(("ok: " if c else "FALLA: ") + what)
	return c


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _remove(names: Array) -> void:
	for n in names:
		if FileAccess.file_exists("user://" + str(n)):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + str(n)))


## La lista `for stale in [...]` tal como está escrita en la herramienta (si la herramienta cambia, la prueba la sigue).
static func _stale_list_of(tool_path: String) -> Array:
	var src := FileAccess.get_file_as_string(tool_path)
	var rx := RegEx.new()
	rx.compile("for stale in \\[([^\\]]*)\\]")
	var m := rx.search(src)
	if m == null:
		return []
	var out: Array = []
	var item := RegEx.new()
	item.compile("\"([^\"]+)\"")
	for it in item.search_all(m.get_string(1)):
		out.append(it.get_string(1))
	return out


func _survivors() -> Array:
	var out: Array = []
	for f in LEVEL_QA_FILES:
		if FileAccess.file_exists("user://" + f):
			out.append(f)
	return out


func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	if not check(scene != null, "la escena principal carga"):
		_finish()
		return
	game = scene.instantiate()
	root.add_child(game)
	await _frames(4)
	game.jev.force_local = true
	game.settings.auto_pause = false
	if is_instance_valid(game.audio_manager):
		game.audio_manager.set_muted(true)
	# 1. Una corrida "anterior" de la herramienta: el nivel en modo QA, con las tres partidas en su puesto (punto de control «posiciones»), pasa el segundo 215 y guarda una vez.
	game.qa_mode = true
	game._start_humahuaca({"qa": true, "skip_intro": true})
	await _frames(4)
	var hx: Node = game.hx
	if not check(game.mode == "hx" and is_instance_valid(hx), "el nivel arranca en modo QA"):
		_finish()
		return
	# QA ronda 2 (Q-202): «posiciones» ya no se escribe a los 210 s sin nadie en su puesto; se mandan las tres partidas a su puesto para que el control exista
	for id in ["rodriguez", "portal", "arias"]:
		hx.orders.issue(id, "position")
	var guard := 0
	while float(hx.qa_state().elapsed) < 215.0 and str(hx.qa_state().status) == "playing" and guard < 60:
		hx.qa_step(10.0)
		guard += 1
	await _frames(2)
	check(float(hx.qa_state().elapsed) >= 215.0, "el reloj del nivel pasó los 215 s (%.0f s)" % float(hx.qa_state().elapsed))
	check(hx.save_game(), "F5 en modo QA guarda la partida")
	var cp_at := float(hx.progress.checkpoint_time("posiciones")) if hx.progress != null else -1.0
	game._stop_humahuaca()
	await _frames(3)
	for f in LEVEL_QA_FILES:
		check(FileAccess.file_exists("user://" + f), "la corrida en modo QA dejó user://%s" % f)
	check(cp_at >= 0.0, "la corrida escribió el punto de control «posiciones» (a los %.0f s)" % cp_at)
	# 2. Lo que borra cada herramienta al arrancar, aplicado tal cual, y lo que sobrevive.
	var survivors_by_tool := {}
	for tool_path in TOOLS:
		var stale := _stale_list_of(tool_path)
		check(not stale.is_empty(), "%s declara su lista de archivos viejos (%d nombres)" % [tool_path, stale.size()])
		_remove(stale)
		var left := _survivors()
		survivors_by_tool[tool_path] = left
		check(left.is_empty(), "tras la limpieza de %s no sobrevive ningún archivo qa_* del nivel (sobreviven: %s)" % [tool_path.get_file(), str(left)])
	# 3. Efecto sobre la corrida siguiente (misma sesión: el controlador nuevo instancia HumahuacaProgress, que lee el índice de controles del archivo).
	var left_all := _survivors()
	if not left_all.is_empty():
		game._start_humahuaca({"qa": true, "skip_intro": true})
		await _frames(4)
		hx = game.hx
		var offered := false
		var at_s := 0.0
		if is_instance_valid(hx) and hx.progress != null and hx.progress.has_method("retry_options"):
			for o in hx.progress.retry_options():
				if str(o.get("id", "")) == "posiciones" and bool(o.get("available", false)):
					offered = true
					at_s = float(o.get("at_s", 0.0))
		print("NOTA: en la corrida siguiente, al segundo %.0f, retry_options() %s «posiciones»%s; guardado qa_save_humahuaca.json presente: %s" % [float(hx.qa_state().elapsed) if is_instance_valid(hx) else -1.0, "OFRECE" if offered else "no ofrece", (" (del segundo %.0f de la corrida anterior)" % at_s) if offered else "", str(FileAccess.file_exists("user://qa_save_humahuaca.json"))])
		game._stop_humahuaca()
		await _frames(3)
	_remove(CLEAN)
	_finish()


func _finish() -> void:
	print(JSON.stringify({"suite": "revision_nube/f_hermeticidad_qa", "checks": checks, "failures": failures}))
	if is_instance_valid(game):
		game.queue_free()
	await process_frame
	quit(1 if not failures.is_empty() else 0)
