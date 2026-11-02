extends SceneTree
## Arnés del agente-jugador del nivel «humahuaca» (CONTRATO 5.1; QA_NIVEL2 anexo D, pedido Q8, y criterio J08). Dueño: compuertas y documentos.
## Uso: godot --path . --resolution 1280x720 --audio-driver Dummy --script tools/hx_agent_play.gd -- --turns-dir=<carpeta> --out=<arnes.json> [--seed=N] [--step-s=3] [--max-turns=150] [--wait-s=120] [--selftest]
## El arnés es el lado del juego: arma la escena real (main.tscn con el controlador, desde el briefing, como la ve quien juega por primera vez) y juega por turnos.
## Cada turno escribe turno_NN.png (1280 × 720, lo que ve el jugador: sin qa_state() ni código), espera accion_NN.json con
##   {"tipo":"clic","x":..,"y":..,"boton":"izq"|"der"}  |  {"tipo":"tecla","tecla":"4"}  (también "Space", "Escape", "ctrl+z", "shift+r"...)  |  {"tipo":"esperar","s":3}
## inyecta esa entrada por el viewport (como ui_qa), avanza qa_step(step_s) de tiempo de juego (qa_step(s) en «esperar»; en el briefing no pasa tiempo y en la apertura pasa
## tiempo real) y vuelve a pausar. Termina cuando el agente escribe respuestas.json, en --max-turns, o con «abandono» si no contesta en --wait-s segundos.
## Escribe --out (arnes.json, esquema hx_agente_v1, anexo A7 del QA): turnos[], primera_orden_turno, primera_orden_t_s, intentos[], objetivos_identificados_en_turnos. Lo escribe el
## arnés y no el agente. lecturas_fuera_de_carpeta queda en 0: la auditoría de las herramientas del agente la hace el Jefe de QA. El arnés no lee ninguna carpeta del agente salvo
## accion_NN.json y respuestas.json.
## --selftest: no hay agente; el arnés contesta solo con el botón de «siguiente paso» (con información que el agente no tiene) para probar el lazo de punta a punta; con
## --selftest=pasivo el primer intento no hace nada y el segundo sigue el «siguiente paso» (prueba el reintento). No es una corrida del agente-jugador.
## No usa semillas reservadas al QA: la semilla viene por --seed.

const V = preload("res://scripts/humahuaca/humahuaca_vocab.gd")

var game: Node
var hx: Node
var turns_dir := ""
var turns_abs := ""
var out_path := ""
var seed_arg := -1
var step_s := 3.0
var max_turns := 150
var wait_s := 120.0
var selftest := false
var selftest_passive := false  # --selftest=pasivo: el primer intento no hace nada (pierde por el alba) y el segundo sigue el «siguiente paso»: prueba el reintento
var turns: Array = []
var attempts: Array = []
var cur_attempt := 0
var cur_attempt_start_turn := 0
var first_order_turn := -1
var first_order_t := -1.0
var touched := {}  # objetivo → primer turno en que el agente hizo clic sobre él (aproximación de «identificó los tres frentes»)
var touched_turn := -1
var closing := ""
var last_shot_size := Vector2i.ZERO
var mouse_pos := Vector2.ZERO


func _initialize() -> void:
	if DisplayServer.get_name() == "headless" or OS.get_cmdline_args().has("--headless"):
		print("HX_AGENT_PLAY requiere ventana real (sin --headless): el motor headless no dibuja y las capturas saldrían vacías. Salida 2.")
		quit(2)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--turns-dir="):
			turns_dir = arg.trim_prefix("--turns-dir=")
		elif arg.begins_with("--out="):
			out_path = arg.trim_prefix("--out=")
		elif arg.begins_with("--seed="):
			seed_arg = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--step-s="):
			step_s = maxf(0.25, float(arg.trim_prefix("--step-s=")))
		elif arg.begins_with("--max-turns="):
			max_turns = maxi(1, int(arg.trim_prefix("--max-turns=")))
		elif arg.begins_with("--wait-s="):
			wait_s = maxf(1.0, float(arg.trim_prefix("--wait-s=")))
		elif arg == "--selftest":
			selftest = true
		elif arg == "--selftest=pasivo":
			selftest = true
			selftest_passive = true
	if turns_dir == "" or out_path == "":
		push_error("hx_agent_play: faltan --turns-dir=<carpeta> y --out=<arnes.json>")
		quit(2)
		return
	for stale in ["settings.cfg", "campaign.json", "justina_progress.json", "humahuaca_progress.json", "humahuaca_checkpoint.json", "save_humahuaca.json", "qa_humahuaca_progress.json"]:
		if FileAccess.file_exists("user://" + stale):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + stale))
	call_deferred("_run")


# ---------------------------------------------------------------------------------------------------------------------
# Entrada inyectada por el viewport (como ui_qa_humahuaca; las posiciones del agente son píxeles de la captura = píxeles de la ventana)

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _real_wait(seconds: float) -> void:
	var t0 := Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t0) / 1000.0 < seconds:
		await process_frame


func _to_window(logical: Vector2) -> Vector2:
	return root.get_final_transform() * logical


func _move(pos: Vector2) -> void:
	mouse_pos = pos
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	root.push_input(e)
	await process_frame


func _click(pos: Vector2, button: int = MOUSE_BUTTON_LEFT) -> void:
	await _move(pos)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.position = pos
		e.global_position = pos
		e.button_index = button
		e.pressed = pressed
		e.button_mask = (1 << (button - 1)) if pressed else 0
		root.push_input(e)
		await process_frame
	await _frames(2)


const KEY_ALIASES := {"espacio": KEY_SPACE, "space": KEY_SPACE, "esc": KEY_ESCAPE, "escape": KEY_ESCAPE, "enter": KEY_ENTER, "intro": KEY_ENTER, "tab": KEY_TAB,
	"supr": KEY_DELETE, "delete": KEY_DELETE, "del": KEY_DELETE, "mas": KEY_PLUS, "menos": KEY_MINUS, "arriba": KEY_UP, "abajo": KEY_DOWN, "izquierda": KEY_LEFT, "derecha": KEY_RIGHT}


func _keycode(name: String) -> int:
	var low := name.strip_edges().to_lower()
	if KEY_ALIASES.has(low):
		return int(KEY_ALIASES[low])
	var code := OS.find_keycode_from_string(name.strip_edges())
	if code == KEY_NONE and low.length() == 1:
		code = OS.find_keycode_from_string(low.to_upper())
	return int(code)


func _key(spec: String) -> bool:
	var parts := spec.split("+")
	var ctrl := false
	var shift := false
	var alt := false
	var main_name := ""
	for p in parts:
		var low := p.strip_edges().to_lower()
		if low == "ctrl" or low == "control":
			ctrl = true
		elif low == "shift" or low == "mayus":
			shift = true
		elif low == "alt":
			alt = true
		else:
			main_name = p.strip_edges()
	var code := _keycode(main_name)
	if code == KEY_NONE:
		return false
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		e.ctrl_pressed = ctrl
		e.shift_pressed = shift
		e.alt_pressed = alt
		root.push_input(e)
		await process_frame
	await _frames(2)
	return true


# ---------------------------------------------------------------------------------------------------------------------

func _run() -> void:
	turns_abs = ProjectSettings.globalize_path(turns_dir)
	DirAccess.make_dir_recursive_absolute(turns_abs)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_path).get_base_dir())
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await _frames(20)
	root.mode = Window.MODE_WINDOWED
	root.borderless = true
	root.size = Vector2i(1280, 720)
	root.position = Vector2i.ZERO
	await _frames(12)
	game.jev.force_local = true
	game.settings.auto_pause = false
	game.qa_mode = true
	if is_instance_valid(game.audio_manager):
		game.audio_manager.set_muted(true)
	var opts := {}
	if seed_arg >= 0:
		opts["seed"] = seed_arg
	game._start_humahuaca(opts)
	await _frames(30)
	hx = game.hx
	if not is_instance_valid(hx) or not hx.has_method("qa_state") or bool(hx.qa_state().get("shell", false)):
		closing = "sin_controlador"
		_write_arnes()
		await _frames(3)
		quit(2)
		return
	cur_attempt = int(hx.qa_state().get("attempt", 1))
	var turn := 0
	while turn < max_turns:
		turn += 1
		await _frames(3)
		var q: Dictionary = hx.qa_state()
		var png_ok := await _write_turn_png(turn)
		if not png_ok:
			closing = "sin_captura"
			break
		var action: Dictionary
		if selftest:
			action = _selftest_action(q)
			_write_json(turns_abs.path_join("accion_%02d.json" % turn), action)
		else:
			action = await _wait_action(turn)
		if action.is_empty():
			closing = "abandono"
			break
		var orders_before := int(q.get("orders", 0))
		var elapsed_before := float(q.get("elapsed", 0.0))
		var applied := await _apply(action, turn)
		var after: Dictionary = hx.qa_state()
		var accepted := int(after.get("orders", 0)) > orders_before and int(after.get("attempt", cur_attempt)) == cur_attempt
		if accepted and first_order_turn < 0:
			first_order_turn = turn
			first_order_t = snappedf(float(after.get("first_order_s", elapsed_before)) if float(after.get("first_order_s", -1.0)) >= 0.0 else elapsed_before, 0.1)
		turns.append({"n": turn, "t_juego_s": snappedf(elapsed_before, 0.1), "accion": action, "orden_aceptada": accepted, "aplicada": applied, "modo": str(q.get("mode", "")), "dialogo": str(q.get("dialog", "")), "fase": str(q.get("phase", ""))})
		await _advance(action)
		_track_attempts(turn)
		if turn % 10 == 0:
			_write_arnes()
		if FileAccess.file_exists(turns_abs.path_join("respuestas.json")):
			closing = "respuestas"
			break
	if closing == "":
		closing = "max_turnos"
	_close_open_attempt(turn)
	_write_arnes()
	print("HX_AGENT_PLAY " + JSON.stringify({"cierre": closing, "turnos": turns.size(), "primera_orden_turno": first_order_turn, "intentos": attempts.size()}))
	await _frames(3)
	quit(0)


func _write_turn_png(n: int) -> bool:
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		return false
	last_shot_size = img.get_size()
	var tmp := turns_abs.path_join("turno_%02d.tmp" % n)
	var final_path := turns_abs.path_join("turno_%02d.png" % n)
	# se escribe con otro nombre y se renombra: el agente nunca lee una imagen a medias
	img.save_png(tmp)
	DirAccess.rename_absolute(tmp, final_path)
	return true


func _wait_action(n: int) -> Dictionary:
	var path := turns_abs.path_join("accion_%02d.json" % n)
	var t0 := Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t0) / 1000.0 < wait_s:
		if FileAccess.file_exists(path):
			for attempt in range(12):
				var f := FileAccess.open(path, FileAccess.READ)
				var text := f.get_as_text() if f != null else ""
				if f != null:
					f.close()
				var parsed: Variant = JSON.parse_string(text)
				if parsed is Dictionary and (parsed as Dictionary).has("tipo"):
					return parsed
				await _real_wait(0.25)  # la escritura del agente puede estar a medias
			return {"tipo": "invalida", "motivo": "accion_%02d.json no es un objeto con «tipo»" % n}
		if FileAccess.file_exists(turns_abs.path_join("respuestas.json")):
			return {"tipo": "esperar", "s": 0.25}
		await _real_wait(0.25)
	return {}


func _apply(action: Dictionary, turn: int) -> bool:
	var kind := str(action.get("tipo", ""))
	if kind == "clic":
		var pos := Vector2(float(action.get("x", -1)), float(action.get("y", -1)))
		var btn_name := str(action.get("boton", "izq")).to_lower()
		var btn := MOUSE_BUTTON_LEFT
		if btn_name in ["der", "derecho", "right"]:
			btn = MOUSE_BUTTON_RIGHT
		elif btn_name in ["medio", "middle"]:
			btn = MOUSE_BUTTON_MIDDLE
		if pos.x < 0 or pos.y < 0 or pos.x > 1280 or pos.y > 720:
			return false
		_note_touch(pos, turn)
		await _click(pos, btn)
		return true
	if kind == "tecla":
		return await _key(str(action.get("tecla", "")))
	return kind == "esperar"


## Cuántos segundos avanza el turno: el paso por defecto o los de «esperar». En el briefing no pasa tiempo; en la apertura pasa tiempo real.
func _advance(action: Dictionary) -> void:
	var seconds := step_s
	if str(action.get("tipo", "")) == "esperar":
		seconds = clampf(float(action.get("s", step_s)), 0.0, 60.0)
	var mode := str(hx.qa_state().get("mode", "play"))
	if mode == "play":
		var left := seconds
		while left > 0.0:
			var chunk := minf(left, 10.0)
			hx.qa_step(chunk)
			left -= chunk
			if str(hx.rules.state.status) != "playing" or str(hx.qa_state().get("dialog", "")) == "decision":
				break
		await _frames(2)
	elif mode == "opening":
		await _real_wait(seconds)
	else:
		await _frames(4)


func _note_touch(pos: Vector2, turn: int) -> void:
	var camera: Camera3D = game.camera
	if camera == null:
		return
	for id in V.OBJECTIVES:
		if touched.has(str(id)):
			continue
		var p: Vector2 = hx.landmark_pos(str(id))
		var v := Vector3(p.x, float(hx.ground_height(p.x, p.y)), p.y)
		if camera.is_position_behind(v):
			continue
		if _to_window(camera.unproject_position(v)).distance_to(pos) <= 70.0:
			touched[str(id)] = turn
	if touched.size() == V.OBJECTIVES.size() and touched_turn < 0:
		touched_turn = turn


func _track_attempts(turn: int) -> void:
	var st: Dictionary = hx.qa_state()
	var attempt := int(st.get("attempt", cur_attempt))
	var status := str(hx.rules.state.status) if hx.rules != null else "playing"
	if attempt != cur_attempt:
		_close_open_attempt(turn - 1)
		cur_attempt = attempt
		cur_attempt_start_turn = turn - 1
	if status != "playing" and not _attempt_recorded(cur_attempt):
		var oc: Variant = hx.rules.state.get("outcome", {})
		attempts.append({"n": cur_attempt, "resultado": status, "cause_id": str((oc as Dictionary).get("cause_id", "")) if oc is Dictionary else "", "turnos": turn - cur_attempt_start_turn,
			"turno_final": turn, "t_juego_s": snappedf(float(hx.rules.state.get("elapsed", 0.0)), 0.1)})


func _attempt_recorded(n: int) -> bool:
	for a in attempts:
		if int((a as Dictionary).n) == n:
			return true
	return false


func _close_open_attempt(turn: int) -> void:
	if not _attempt_recorded(cur_attempt) and is_instance_valid(hx):
		attempts.append({"n": cur_attempt, "resultado": "sin_terminar", "cause_id": "", "turnos": maxi(0, turn - cur_attempt_start_turn), "turno_final": turn,
			"t_juego_s": snappedf(float(hx.rules.state.get("elapsed", 0.0)), 0.1) if hx.rules != null else 0.0})


# ---------------------------------------------------------------------------------------------------------------------

func _write_json(path: String, data: Variant) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()


func _write_arnes() -> void:
	var commit := ""
	var git_out: Array = []
	if OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "rev-parse", "HEAD"], git_out) == 0 and git_out.size() > 0:
		commit = str(git_out[0]).strip_edges()
	var arnes := {"schema": "hx_agente_v1", "commit": commit, "seed": seed_arg, "step_s": step_s, "max_turns": max_turns, "turnos": turns, "primera_orden_turno": first_order_turn, "primera_orden_t_s": first_order_t,
		"intentos": attempts, "lecturas_fuera_de_carpeta": 0, "lecturas_nota": "el arnés no audita las herramientas del agente: el Jefe de QA anota ahí cuántas lecturas hizo fuera de su carpeta",
		"objetivos_identificados_en_turnos": touched_turn, "objetivos_identificados_criterio": "primer turno en que el agente hizo clic a menos de 70 px de cada uno de los tres frentes (aproximación del arnés; -1 si no los tocó todos)",
		"objetivos_tocados": touched, "cierre": closing, "captura_px": [last_shot_size.x, last_shot_size.y], "selftest": selftest, "wait_s": wait_s}
	_write_json(ProjectSettings.globalize_path(out_path), arnes)


# ---------------------------------------------------------------------------------------------------------------------
# --selftest: el arnés contesta solo, con el botón de «siguiente paso» y los botones de los partes (información que el agente no tiene)

func _visible_button(part: String) -> Button:
	for b in game.find_children("*", "Button", true, false):
		if b is Button and part in (b as Button).text and (b as Button).is_visible_in_tree() and not (b as Button).disabled:
			return b
	return null


func _center_of(c: Control) -> Vector2:
	return _to_window(c.get_global_rect().get_center())


func _selftest_action(q: Dictionary) -> Dictionary:
	var mode := str(q.get("mode", ""))
	var status := str(hx.rules.state.status) if hx.rules != null else "playing"
	if status == "victory" and mode == "ended":
		_write_json(turns_abs.path_join("respuestas.json"), {"objetivo": "selftest: no es el agente", "entendiste": "selftest sin agente", "aburrimiento": "selftest sin agente", "aprendido": "selftest sin agente"})
		return {"tipo": "esperar", "s": 0.25}
	if mode == "briefing":
		for label in ["Seguir leyendo", "Empezar"]:
			var b := _visible_button(label)
			if b != null:
				var c := _center_of(b)
				return {"tipo": "clic", "x": snappedf(c.x, 0.1), "y": snappedf(c.y, 0.1), "boton": "izq"}
	if mode == "opening":
		return {"tipo": "tecla", "tecla": "Space"}
	if mode == "ended":
		var rb := _visible_button("Reintentar")
		if rb != null:
			var c2 := _center_of(rb)
			return {"tipo": "clic", "x": snappedf(c2.x, 0.1), "y": snappedf(c2.y, 0.1), "boton": "izq"}
	if mode == "play" and selftest_passive and cur_attempt == 1:
		return {"tipo": "esperar", "s": 30.0}
	if mode == "play" and hx.hud != null and hx.hud.next_btn != null and hx.hud.next_btn.is_visible_in_tree() and not hx.hud.next_btn.disabled:
		var c3 := _center_of(hx.hud.next_btn)
		return {"tipo": "clic", "x": snappedf(c3.x, 0.1), "y": snappedf(c3.y, 0.1), "boton": "izq"}
	if mode == "play":  # con alguien elegido el dock muestra la barra de acciones en lugar del botón de «siguiente paso»: se busca el de la señal
		var sb := _visible_button("Dar la señal")
		if sb != null:
			var c4 := _center_of(sb)
			return {"tipo": "clic", "x": snappedf(c4.x, 0.1), "y": snappedf(c4.y, 0.1), "boton": "izq"}
	return {"tipo": "esperar", "s": 12.0}  # sin botón hay que esperar a que algo pase: un agente que espera dice cuánto
