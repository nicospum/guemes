extends SceneTree
## Prueba de interfaz y flujo del nivel «humahuaca» sobre la escena real, sin ventana (CONTRATO 5.1; dueña: ui_feel). Piso: 50 comprobaciones en R1, 80 desde R2a.
## godot --headless --path . --script tests/test_hx_flow.gd [-- --ronda=r1]   (con APPDATA aislado: borra archivos de perfil)
## Corre main.tscn con el controlador real, mueve la entrada como lo haría una persona (teclas y mouse por Viewport.push_input) y lee solo lo que el
## controlador ofrece (qa_state, los nodos de su interfaz y la API de QA): ninguna prueba toca atributos privados de main.
##   _test_reserved_keys · _test_first_frame · _test_full_cycle · _test_expert_wins_passive_loses · _test_first_decision · _test_save_load · _test_cli_flags
## más la cámara (A-11), las acciones y su vista previa, las ventanas, el desborde a tres tamaños y la jerga. El «experto» de R1 es el que sigue el
## «siguiente paso» de las reglas hasta el final; la biblioteca de políticas (reglas_historia) corre por la escena real en humahuaca_playthrough.gd.

const Fx = preload("res://tests/hx_fixtures.gd")
const V = preload("res://scripts/humahuaca/humahuaca_vocab.gd")
const U = preload("res://scripts/humahuaca/ui/vocab_ui.gd")
const Kit = preload("res://scripts/humahuaca/ui/humahuaca_ui_kit.gd")
const Ctl = preload("res://scripts/humahuaca/ui/humahuaca_ui.gd")

const FLOOR := 50
const FOLD_FROM := "áéíóúüñÁÉÍÓÚÜÑ"
const FOLD_TO := "aeiouunAEIOUUN"

var suite := Fx.new()
var game: Node
var hx: Node
var ui_json: Dictionary = {}


func _initialize() -> void:
	suite.begin("hx_flow", OS.get_cmdline_user_args())
	if not Fx.profile_isolated():
		suite.check(false, "perfil NO aislado (%s): exportá APPDATA=\"$TEMP/ap_iso_<pista>\" antes de correr; esta prueba borra archivos de perfil" % OS.get_user_data_dir())
		print(JSON.stringify(suite.report()))
		quit(2)
		return
	Fx.clean_profile()
	call_deferred("_run")


# ---------------------------------------------------------------------------------------------------------------------
# Ayudas

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _key(code: int, ctrl: bool = false, shift: bool = false) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		e.ctrl_pressed = ctrl
		e.shift_pressed = shift
		root.push_input(e)
		await process_frame


func _hold(code: int, frames: int) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	root.push_input(e)
	await _frames(frames)
	var r := InputEventKey.new()
	r.keycode = code
	r.physical_keycode = code
	r.pressed = false
	root.push_input(r)
	await process_frame


func _to_window(p: Vector2) -> Vector2:
	return root.get_final_transform() * p


func _mouse_move(p: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = _to_window(p)
	e.global_position = e.position
	root.push_input(e)
	await process_frame


func _click_at(p: Vector2, button: int = MOUSE_BUTTON_LEFT, shift: bool = false) -> void:
	await _mouse_move(p)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.position = _to_window(p)
		e.global_position = e.position
		e.button_index = button
		e.pressed = pressed
		e.shift_pressed = shift
		e.button_mask = (1 << (button - 1)) if pressed else 0
		root.push_input(e)
		await process_frame


func _world_to_screen(x: float, z: float) -> Vector2:
	return game.camera.unproject_position(Vector3(x, float(hx.ground_height(x, z)), z))


func _start_level(opts: Dictionary = {"skip_intro": true}) -> bool:
	game._start_humahuaca(opts)
	await _frames(4)
	hx = game.hx
	return game.mode == "hx" and is_instance_valid(hx)


func _to_menu() -> void:
	game._menu()
	await _frames(3)
	hx = null


func _find_button(part: String, scope: Node = null) -> Button:
	var base: Node = scope if scope != null else game
	for b in base.find_children("*", "Button", true, false):
		if str(b.text).find(part) >= 0 and (b as Button).is_visible_in_tree():
			return b
	return null


func _fold(text: String) -> String:
	var out := text.to_lower()
	for i in range(FOLD_FROM.length()):
		out = out.replace(FOLD_FROM[i].to_lower(), FOLD_TO[i].to_lower())
	return out


## Los términos de la lista negra que aparecen en `text`: siglas respetando mayúsculas y palabras sin tildes ni mayúsculas, siempre palabra entera;
## más los identificadores en snake_case y las cadenas escritas enteras en mayúsculas (CONTRATO 2.4, V10).
func _jargon_hits(text: String) -> Array:
	var hits: Array = []
	var folded := _fold(text)
	for term in ui_json.get("jargon_blacklist", []):
		var t := str(term)
		var is_sigla := t.length() >= 2 and t == t.to_upper()
		var rx := RegEx.new()
		rx.compile("(?<![A-Za-z0-9_])" + (t if is_sigla else _fold(t)) + "(?![A-Za-z0-9_])")
		if rx.search(text if is_sigla else folded) != null:
			hits.append(t)
	var snake := RegEx.new()
	snake.compile("\\b[a-z]+(?:_[a-z0-9]+)+\\b")
	if snake.search(text) != null:
		hits.append("snake_case")
	var letters := ""
	for c in text:
		if c.to_upper() != c.to_lower():
			letters += c
	if letters.length() >= 12 and letters == letters.to_upper():
		hits.append("todo en mayúsculas")
	return hits


## Todo el texto visible de la interfaz del nivel (etiquetas, botones y textos con formato), con su ruta.
func _visible_texts() -> Array:
	var out: Array = []
	for c in game.ui.find_children("*", "Control", true, false):
		var ctl := c as Control
		if not ctl.is_visible_in_tree():
			continue
		if ctl is Label and (ctl as Label).text != "":
			out.append((ctl as Label).text)
		elif ctl is Button and (ctl as Button).text != "":
			out.append((ctl as Button).text)
		elif ctl is RichTextLabel and (ctl as RichTextLabel).get_parsed_text() != "":
			out.append((ctl as RichTextLabel).get_parsed_text())
	return out


func _inside(r: Rect2, bounds: Rect2) -> bool:
	return r.position.x >= bounds.position.x - 0.5 and r.position.y >= bounds.position.y - 0.5 and r.end.x <= bounds.end.x + 0.5 and r.end.y <= bounds.end.y + 0.5


func _set_window(size: Vector2i) -> void:
	root.size = size
	await _frames(6)


# ---------------------------------------------------------------------------------------------------------------------

func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	if not suite.check(scene != null, "la escena principal carga"):
		suite.finish(self)
		return
	ui_json = V.load_json(V.UI_PATH)
	game = scene.instantiate()
	root.add_child(game)
	await _frames(4)
	game.jev.force_local = true
	game.settings.auto_pause = false
	if is_instance_valid(game.audio_manager):
		game.audio_manager.set_muted(true)
	await _test_first_frame()
	await _test_camera()
	await _test_reserved_keys()
	await _test_actions_and_preview()
	await _test_alert_placement()
	await _test_dialogs()
	await _test_first_decision()
	await _test_full_cycle()
	await _test_expert_wins_passive_loses()
	await _test_save_load()
	_test_cli_flags()
	await _test_overflow_sizes()
	await _test_texts()
	_test_key_table()
	suite.check(suite.elapsed_ms() < 60000, "test_hx_flow corre en menos de 60 s (CONTRATO 5.1): %d ms" % suite.elapsed_ms())
	suite.require_floor(FLOOR)
	if is_instance_valid(game):
		game.queue_free()
	await process_frame
	suite.finish(self)


# ---------------------------------------------------------------------------------------------------------------------
# El primer cuadro jugable (C03): ≤ 5 controles, ≤ 400 caracteres, 0 jerga, un objetivo y un solo «siguiente paso»

func _test_first_frame() -> void:
	if not suite.check(await _start_level(), "primer cuadro: el nivel arranca por la escena real"):
		return
	var qa: Dictionary = hx.qa_state()
	var lim: Dictionary = ui_json.get("hud_limits", {})
	suite.check(str(qa.mode) == "play" and bool(qa.paused) and float(qa.elapsed) == 0.0, "primer cuadro: se juega, en pausa y en 0:00 (modo %s)" % str(qa.mode))
	suite.check(int(qa.visible_controls) <= int(lim.get("max_controls", 5)), "primer cuadro: ≤ 5 controles accionables (%d: %s)" % [int(qa.visible_controls), str(qa.control_groups)])
	suite.check(int(qa.text_chars_juego) <= int(lim.get("max_chars", 400)), "primer cuadro: ≤ 400 caracteres de texto de juego (%d; con la línea roja de las capas en su versión mínima, %d)" % [int(qa.text_chars_juego), int(qa.text_chars)])
	var hits: Array = []
	for t in _visible_texts():
		for h in _jargon_hits(str(t)):
			hits.append("%s en «%s»" % [str(h), str(t).left(40)])
	suite.check(hits.is_empty(), "primer cuadro: 0 términos de la lista negra ni identificadores (%s)" % str(hits))
	suite.check(hx.hud.objective_l.text != "" and hx.hud.objective_l.get_line_count() <= 2, "primer cuadro: una línea de objetivo (%d líneas)" % hx.hud.objective_l.get_line_count())
	suite.check(hx.hud.next_text_l.text != "" and hx.hud.next_btn.visible, "primer cuadro: un solo «siguiente paso» con su botón: «%s» → «%s»" % [hx.hud.next_text_l.text, hx.hud.next_btn.text])
	suite.check(str(hx.hud.clock_l.text) == "‖ EN PAUSA", "primer cuadro: el indicador dice «‖ EN PAUSA» (%s)" % str(hx.hud.clock_l.text))
	suite.check(hx.hud.group_cards.size() == 5 and V.GROUPS.all(func(id): return hx.hud.group_cards.has(id)), "primer cuadro: las cinco agrupaciones figuran en el panel (VP-06)")
	suite.check(hx.hud.front_cards.size() == 3 and hx.hud.front_cards.bateria.guard.text.find("?") >= 0, "primer cuadro: tres tarjetas de frente con la guardia sin reconocer («?»)")
	var cards := hx.hud.card_rect("rodriguez") as Rect2
	suite.check(cards.size.x > 20.0 and cards.size.y > 20.0, "primer cuadro: las fichas del panel tienen tamaño")
	suite.extra["primer_cuadro"] = {"controles": int(qa.visible_controls), "botones": int(qa.visible_buttons), "caracteres": int(qa.text_chars), "caracteres_juego": int(qa.text_chars_juego), "grupos_de_controles": qa.control_groups}
	# ninguna ficha queda bajo el HUD (BACKLOG B-021): con el rumbo de la mirada que fija el contrato (325°, A-11) en 1280 × 720 y a 1024 × 640
	var data_yaw := float(hx.initial_frame().yaw_deg)
	var note := ""
	if absf(data_yaw - 325.0) > 0.5:
		note = " (los datos de la vista traen %.0f°: visual los pasa a 325° en el mismo merge, A-11; se mide con 325°)" % data_yaw
		suite.pend("cuadro-inicial-yaw", "initial_frame.yaw_deg sigue en %.0f° y no en 325° (ADDENDA A-11): visual lo cambia en el mismo merge" % data_yaw, "r1")
		hx.qa_set_initial_yaw(325.0)
	for size in [Vector2i(1280, 720), Vector2i(1024, 640)]:
		await _set_window(size)
		hx.reset_camera()
		await _frames(3)
		var view_rect := Rect2(Vector2.ZERO, root.get_visible_rect().size)
		var covered: Array = []
		var edge_min := 100.0
		for id in V.GROUPS:
			var u: Dictionary = hx.rules.get_unit(str(id))
			var s: Vector2 = _world_to_screen(float(u.x), float(u.z))
			edge_min = minf(edge_min, 100.0 * minf(minf(s.x, view_rect.size.x - s.x) / view_rect.size.x, minf(s.y, view_rect.size.y - s.y) / view_rect.size.y))
			for key in ["header", "fronts", "dock"]:
				if (hx.hud.rects()[key] as Rect2).has_point(s):
					covered.append("%s bajo %s" % [str(id), key])
		suite.check(covered.is_empty(), "%dx%d: ninguna ficha queda bajo el HUD%s: %s" % [size.x, size.y, note, str(covered)])
		suite.check(edge_min >= (5.0 if size.x >= 1280 else 0.5), "%dx%d: las cinco partidas quedan a ≥ %s %% del borde (mínimo %.1f %%)" % [size.x, size.y, "5" if size.x >= 1280 else "0,5", edge_min])
		suite.extra["borde_min_%dx%d" % [size.x, size.y]] = snappedf(edge_min, 0.1)
	await _set_window(Vector2i(1280, 720))
	await _to_menu()


# ---------------------------------------------------------------------------------------------------------------------
# Cámara (ADDENDA A-11): el rumbo es el de la mirada y se ubica antes de update_state

func _gaze() -> Vector2:
	var f: Vector3 = -game.camera.global_transform.basis.z
	return Vector2(f.x, f.z).normalized()


func _test_camera() -> void:
	if not suite.check(await _start_level(), "cámara: el nivel arranca"):
		return
	hx.qa_set_camera(Vector2(318, 350), 60.0, 18.0, 90.0)
	await _frames(2)
	var g := _gaze()
	suite.check(absf(g.x - 1.0) <= 0.02 and absf(g.y) <= 0.02, "cámara (VP-07): con rumbo 90° la mirada es (1, 0) ± 0,02 (%s)" % str(g))
	hx.qa_set_camera(Vector2(318, 350), 200.0, 40.0, 0.0)
	await _frames(2)
	g = _gaze()
	suite.check(absf(g.x) <= 0.02 and absf(g.y + 1.0) <= 0.02, "cámara: con rumbo 0° la mirada va al norte (0, −1) (%s)" % str(g))
	suite.check(game.camera.global_position.z > 350.0, "cámara: con rumbo 0° la cámara está al sur del objetivo")
	hx.qa_set_camera(Vector2(318, 350), 200.0, 40.0, 180.0)
	await _frames(2)
	g = _gaze()
	suite.check(absf(g.x) <= 0.02 and absf(g.y - 1.0) <= 0.02, "cámara: con rumbo 180° la mirada va al sur (0, 1) (%s)" % str(g))
	hx.qa_set_camera(Vector2(318, 350), 5.0, 40.0, 45.0)
	suite.check(float(hx.qa_state().camera.dist) >= 40.0, "cámara: el zoom no baja de 40 m (%s)" % str(hx.qa_state().camera.dist))
	hx.qa_set_camera(Vector2(318, 350), 5000.0, 40.0, 45.0)
	suite.check(float(hx.qa_state().camera.dist) <= 900.0, "cámara: el zoom no pasa de 900 m (%s)" % str(hx.qa_state().camera.dist))
	hx.qa_set_camera(Vector2(-5000, 9000), 300.0, 50.0, 0.0)
	var t: Array = hx.qa_state().camera.target
	suite.check(float(t[0]) >= -121.0 and float(t[1]) <= 771.0, "cámara: el objetivo queda dentro de la ventana más 120 m (%s)" % str(t))
	var floor_ok := true
	for dist in [40.0, 90.0, 300.0]:
		hx.qa_set_camera(Vector2(300, 345), dist, 12.0, 270.0)
		await _frames(2)
		floor_ok = floor_ok and game.camera.global_position.y >= float(hx.ground_height(game.camera.global_position.x, game.camera.global_position.z)) + 2.9
	suite.check(floor_ok, "cámara: nunca baja de 3 m sobre el suelo")
	# el orden de un cuadro: ubicar la cámara y recién ahí update_state; la escala de las fichas no cambia al llamarlo otra vez (VP-08)
	var frame: Dictionary = hx.initial_pose()
	hx.qa_set_camera(frame.target, float(frame.dist), float(frame.pitch_deg), 325.0)
	await _frames(3)
	var before := {}
	for id in hx.view.unit_nodes:
		before[id] = (hx.view.unit_nodes[id] as Node3D).scale
	hx.view.update_state(0.0)
	hx.view.update_state(0.0)
	var same := true
	for id in before:
		same = same and ((hx.view.unit_nodes[id] as Node3D).scale - (before[id] as Vector3)).length() < 0.02
	suite.check(same, "cámara (VP-08): la escala de las fichas no cambia al llamar a update_state otra vez")
	# teclas de la cámara: W avanza hacia donde mira, Q y E giran, RePág inclina
	hx.qa_set_camera(Vector2(450, 325), 300.0, 50.0, 90.0)
	var x0: float = hx.qa_state().camera.target[0]
	await _hold(KEY_W, 12)
	var x1: float = hx.qa_state().camera.target[0]
	suite.check(x1 > x0 + 1.0, "cámara: W mueve el objetivo hacia donde mira (rumbo 90° = este: %.1f → %.1f)" % [x0, x1])
	var yaw0: float = hx.qa_state().camera.yaw_deg
	await _hold(KEY_E, 10)
	suite.check(absf(float(hx.qa_state().camera.yaw_deg) - yaw0) > 0.5, "cámara: E gira la guiñada")
	await _to_menu()


# ---------------------------------------------------------------------------------------------------------------------
# Teclas reservadas (CONTRATO 3.5): Espacio, F1, F2 a F4, + y −, Esc, 1 a 5, Tab y Ctrl+Z; la velocidad nunca cambia sola

func _row_ids() -> Array:
	var ids: Array = []
	for row in ui_json.get("key_table", []):
		ids.append(str((row as Dictionary).get("id", "")))
	return ids


func _test_reserved_keys() -> void:
	var ids := _row_ids()
	var need := ["pause", "speed_1", "speed_2", "speed_4", "speed_up", "speed_down", "help", "menu", "save", "load", "fullscreen", "group_1", "group_2", "group_3", "group_4", "group_5", "cycle", "undo"]
	suite.check(need.all(func(i): return ids.has(i)), "teclas: la tabla key_table trae las reservadas (%s)" % str(need.filter(func(i): return not ids.has(i))))
	var lim: Dictionary = ui_json.get("hud_limits", {})
	suite.check(float(lim.get("auto_pause_max_s", 99.0)) <= 2.0 and float(lim.get("decision_max_s", 99.0)) <= 25.0, "teclas: la pausa automática es ≤ 2 s y las decisiones ≤ 25 s")
	if not suite.check(await _start_level(), "teclas: el nivel arranca"):
		return
	suite.check(bool(hx.qa_state().paused) and hx.hud.clock_l.text == "‖ EN PAUSA", "teclas: empieza en pausa y el indicador lo dice")
	await _key(KEY_SPACE)
	suite.check(not bool(hx.qa_state().paused) and hx.hud.clock_l.text == "TIEMPO REAL · ▶ ×1", "teclas: Espacio sigue el tiempo y el indicador dice «TIEMPO REAL · ▶ ×1» (%s)" % hx.hud.clock_l.text)
	await _key(KEY_SPACE)
	suite.check(bool(hx.qa_state().paused), "teclas: Espacio vuelve a pausar")
	await _key(KEY_F3)
	suite.check(float(hx.qa_state().speed) == 2.0 and hx.hud.clock_l.text == "TIEMPO REAL · ▶ ×2", "teclas: F3 fija ×2 (%s)" % hx.hud.clock_l.text)
	await _key(KEY_F4)
	suite.check(float(hx.qa_state().speed) == 4.0, "teclas: F4 fija ×4")
	await _key(KEY_F2)
	suite.check(float(hx.qa_state().speed) == 1.0, "teclas: F2 fija ×1")
	await _key(KEY_EQUAL)
	suite.check(float(hx.qa_state().speed) == 2.0, "teclas: + sube la velocidad")
	await _key(KEY_MINUS)
	suite.check(float(hx.qa_state().speed) == 1.0, "teclas: − baja la velocidad")
	await _key(KEY_F4)
	var before_clock := float(hx.qa_state().elapsed)
	await _frames(90)
	suite.check(float(hx.qa_state().speed) == 4.0 and float(hx.qa_state().elapsed) >= before_clock, "teclas: la velocidad nunca cambia sola (sigue en ×4 tras 90 cuadros)")
	await _key(KEY_F2)
	await _key(KEY_SPACE)
	suite.check(bool(hx.qa_state().paused), "teclas: el ajuste de velocidad no cambia la pausa que ya estaba")
	await _key(KEY_F1)
	suite.check(str(hx.qa_state().dialog) == "ayuda", "teclas: F1 abre la ayuda")
	await _key(KEY_F1)
	suite.check(str(hx.qa_state().dialog) == "", "teclas: F1 la cierra")
	# 1 a 5 eligen; otra vez la misma de 1 a 3 centra la cámara en el frente de esa partida
	await _key(KEY_2)
	suite.check(hx.qa_state().selected == ["portal"], "teclas: 2 elige la partida de Portal")
	await _key(KEY_2)
	var cuartel: Vector2 = hx.landmark_pos("cuartel")
	var tgt: Array = hx.qa_state().camera.target
	suite.check(Vector2(float(tgt[0]), float(tgt[1])).distance_to(cuartel) < 1.5, "teclas: pulsar 2 otra vez centra la cámara en el cuartel (%s vs %s)" % [str(tgt), str(cuartel)])
	await _key(KEY_5)
	suite.check(hx.qa_state().selected == ["arreo"], "teclas: 5 elige el arreo")
	await _key(KEY_TAB)
	suite.check(hx.qa_state().selected == ["rodriguez"], "teclas: Tab pasa a la agrupación siguiente (de la 5 a la 1)")
	await _key(KEY_TAB, false, true)
	suite.check(hx.qa_state().selected == ["arreo"], "teclas: Mayús + Tab pasa a la anterior")
	# Esc: sin órdenes dadas vuelve al menú; con una orden abre el menú de pausa; Esc cierra la ventana
	await _key(KEY_4)
	await _key(KEY_R)
	suite.check(bool(hx.qa_state().aiming), "teclas: R con los reconocedores entra en el modo apuntado")
	await _key(KEY_ESCAPE)
	suite.check(not bool(hx.qa_state().aiming) and game.mode == "hx", "teclas: Esc cancela lo que se estaba apuntando y no sale del nivel")
	var target := _world_to_screen(318.0, 350.0)
	await _click_at(target, MOUSE_BUTTON_RIGHT)
	await _frames(2)
	suite.check(int(hx.qa_state().orders) >= 1, "teclas: el clic derecho con los reconocedores elegidos da la orden de reconocer")
	await _key(KEY_ESCAPE)
	suite.check(str(hx.qa_state().dialog) == "pausa" and bool(hx.qa_state().paused), "teclas: con una orden dada, Esc abre el menú de pausa y detiene el reloj")
	await _key(KEY_ESCAPE)
	suite.check(str(hx.qa_state().dialog) == "" and game.mode == "hx", "teclas: Esc cierra el menú de pausa")
	# Ctrl+Z deshace la última orden
	var stage_before := str(hx.rules.get_unit("reconocedores").stage)
	await _key(KEY_Z, true)
	suite.check(str(hx.rules.get_unit("reconocedores").stage) == "idle" and stage_before != "idle", "teclas: Ctrl+Z deshace la última orden (%s → %s)" % [stage_before, str(hx.rules.get_unit("reconocedores").stage)])
	await _to_menu()
	# sin ninguna orden, Esc vuelve al menú
	if await _start_level():
		await _key(KEY_ESCAPE)
		await _frames(3)
		suite.check(game.mode == "menu" and game.hx == null, "teclas: sin órdenes dadas, Esc vuelve al menú y libera el controlador")
	await _to_menu()


# ---------------------------------------------------------------------------------------------------------------------
# Las acciones con su vista previa de ruta (las 9 de R1 por teclas y por clic derecho)

func _issued_actions() -> Array:
	var out: Array = []
	for i in hx.qa_state().issued:
		out.append(str(i.action))
	return out


func _test_actions_and_preview() -> void:
	if not suite.check(await _start_level(), "acciones: el nivel arranca"):
		return
	# reconocer: R y apuntar; la vista previa dice el riesgo y qué revela
	await _key(KEY_4)
	await _key(KEY_R)
	var bat := _world_to_screen(318.0, 350.0)
	await _mouse_move(bat)
	await _frames(8)
	var preview := str(hx.orders.preview_text("recon"))
	suite.check(preview.find("riesgo") >= 0 and preview.find("revela") >= 0, "acciones: la vista previa de reconocer dice el riesgo y qué revela («%s»)" % preview)
	suite.check(hx.hud.pace_box.visible and hx.hud.motive_l.text != "", "acciones: mientras se apunta se ven los ritmos y la línea de motivo")
	await _click_at(bat)
	await _frames(2)
	suite.check(_issued_actions().has("recon") and not bool(hx.qa_state().aiming), "acciones: el clic confirma «Reconocer» y deja de apuntar")
	# mover: G, una parada con Mayús y el destino; la vista previa de ruta dice metros, tiempo y riesgo
	await _key(KEY_1)
	await _key(KEY_G)
	await _mouse_move(_world_to_screen(200.0, 420.0))
	await _frames(8)
	var p2 := str(hx.orders.preview_text("move"))
	suite.check(p2.find(" m ·") >= 0 and p2.find("riesgo") >= 0, "acciones: la vista previa de mover dice metros, tiempo y riesgo («%s»)" % p2)
	await _click_at(_world_to_screen(200.0, 420.0), MOUSE_BUTTON_LEFT, true)
	suite.check(hx.orders.waypoints.size() == 1 and bool(hx.qa_state().aiming), "acciones: Mayús + clic suma una parada y sigue apuntando")
	await _click_at(_world_to_screen(180.0, 440.0))
	await _frames(2)
	suite.check(_issued_actions().has("move"), "acciones: confirmar manda a la partida con su ruta («Mover»)")
	# a su puesto (P)
	await _key(KEY_2)
	await _key(KEY_P)
	suite.check(_issued_actions().has("position"), "acciones: P manda a la partida a su puesto")
	await _key(KEY_3)
	await _key(KEY_P)
	await _key(KEY_4)
	# la barra de acciones: solo lo usable y lo recomendado, y el motivo de lo que no se puede
	await _key(KEY_1)
	hx.hud.refresh({}, {}) if false else null
	hx.refresh_hud_now()
	suite.check(hx.hud.action_button("attack") == null, "acciones: «Atacar» no se ofrece mientras la partida no está a 150 m del frente")
	await _key(KEY_T)
	suite.check(str(hx.qa_state().motive).find("150") >= 0 or str(hx.orders.last_error).find("150") >= 0, "acciones: pulsar T lejos del frente dice por qué no se puede («%s»)" % str(hx.orders.last_error))
	# avanzar hasta que las tres partidas estén en sus puestos y dar la señal con F
	var guard := 0
	while guard < 80 and not bool(hx.rules.signal_info().can_give):
		hx.qa_step(5.0)
		guard += 1
	var tres_listas := true
	for id in ["rodriguez", "portal", "arias"]:
		tres_listas = tres_listas and str(hx.rules.get_unit(id).stage) == "waiting_signal"
	if not tres_listas:
		for id in ["rodriguez", "portal", "arias"]:
			hx.orders.issue(id, "position")
		for k in range(60):
			hx.qa_step(5.0)
			if str(hx.rules.get_unit("rodriguez").stage) == "waiting_signal" and str(hx.rules.get_unit("portal").stage) == "waiting_signal" and str(hx.rules.get_unit("arias").stage) == "waiting_signal":
				break
	hx.refresh_hud_now()
	suite.check(bool(hx.hud.status_l.text.find("Señal") >= 0), "acciones: con partidas en su puesto el HUD dice cómo está la señal («%s»)" % hx.hud.status_l.text)
	await _key(KEY_F)
	suite.check(_issued_actions().has("give_signal") and bool(hx.rules.state.alarm.signaled), "acciones: F da la señal")
	# socorrer (C): elegir el frente con un clic
	hx.qa_step(2.0)
	await _key(KEY_3)
	await _key(KEY_C)
	suite.check(bool(hx.qa_state().aiming), "acciones: C con la reserva entra en el modo apuntado de «Socorrer»")
	await _click_at(_world_to_screen(318.0, 350.0))
	await _frames(2)
	suite.check(_issued_actions().has("support") or not str(hx.orders.last_error).is_empty(), "acciones: elegir el frente manda «Socorrer» (o dice por qué no)")
	hx.orders.cancel_aim()
	suite.check(not hx.orders.aiming(), "acciones: cancelar el modo apuntado lo deja sin orden en la mano")
	await _to_menu()


# ---------------------------------------------------------------------------------------------------------------------
# El aviso no tapa fichas ni rótulos: se corre al primer lugar libre (centro, derecha, izquierda)

func _blocker(r: Rect2) -> Rect2:
	return Rect2(r.get_center() - Vector2(30.0, 45.0), Vector2(60.0, 90.0))  # lo que ocupa una ficha con su número


func _test_alert_placement() -> void:
	if not suite.check(await _start_level(), "aviso: el nivel arranca"):
		return
	hx.qa_set_initial_yaw(325.0)  # el rumbo del contrato (A-11): con el de los datos de hoy alguna ficha puede quedar detrás de la cámara
	await _frames(3)
	var h: Variant = hx.hud
	var local := Rect2(Vector2.ZERO, h.root.size)  # el cuadro, en las coordenadas locales de la interfaz (las que usa place_alert)
	var k := 1.0 / float(hx.ui_scale)
	var fronts_global: Rect2 = h.rects().fronts
	var fronts := Rect2(fronts_global.position * k, fronts_global.size * k)
	var centro: Rect2 = h.place_alert([])
	suite.check(_inside(centro, local) and centro.position.y >= fronts.end.y, "aviso: sin nada que tapar queda al centro, debajo de la cabecera y los frentes (%s)" % str(centro))
	suite.check(absf(centro.get_center().x - local.size.x * 0.5) <= 1.0, "aviso: el lugar de siempre es el centro del cuadro")
	var derecha: Rect2 = h.place_alert([_blocker(centro)])
	suite.check(_inside(derecha, local) and not derecha.intersects(_blocker(centro)) and derecha.get_center().x > centro.get_center().x, "aviso: si el centro tapa una ficha pasa a la derecha sin salirse del cuadro (%s)" % str(derecha))
	var izquierda: Rect2 = h.place_alert([_blocker(centro), _blocker(derecha)])
	suite.check(_inside(izquierda, local) and not izquierda.intersects(_blocker(centro)) and not izquierda.intersects(_blocker(derecha)) and izquierda.get_center().x < centro.get_center().x, "aviso: si tampoco la derecha está libre pasa a la izquierda (%s)" % str(izquierda))
	var ninguno: Rect2 = h.place_alert([_blocker(centro), _blocker(derecha), _blocker(izquierda)])
	suite.check(_inside(ninguno, local), "aviso: aunque ningún lugar esté libre, el aviso queda dentro del cuadro")
	var sigue: Rect2 = h.place_alert([_blocker(derecha)])
	suite.check(not sigue.intersects(_blocker(derecha)), "aviso: sale del lugar tapado y no vuelve a uno ocupado")
	h.place_alert([])
	var avoid: Array = hx.avoid_rects()
	suite.check(avoid.size() >= 8, "aviso: el controlador entrega un rectángulo por ficha y por frente (%d)" % avoid.size())
	await _to_menu()


# ---------------------------------------------------------------------------------------------------------------------
# Ventanas: briefing, pausa, ayuda, diario, retirada con dos clics y decisión con reloj

func _test_dialogs() -> void:
	if not suite.check(await _start_level({}), "ventanas: el nivel arranca con el briefing"):
		return
	suite.check(str(hx.qa_state().mode) == "briefing" and str(hx.qa_state().dialog) == "briefing", "ventanas: arranca en el briefing y el reloj está en 0:00")
	suite.check(_find_button("Empezar", game) != null and _find_button("Seguir leyendo", game) != null, "ventanas: la tarjeta 1 ofrece «Empezar» y «Seguir leyendo»")
	_find_button("Seguir leyendo", game).pressed.emit()
	await _frames(2)
	suite.check(_find_button("Saltar", game) != null and _find_button("Empezar", game) != null and _find_button("Volver", game) != null, "ventanas: la tarjeta 2 (la carta) ofrece «Empezar», «Saltar» y «Volver»")
	var texts: Array = _visible_texts()
	var joined := " ".join(PackedStringArray(texts))
	suite.check(joined.find("Dramatización") >= 0 and joined.find("1 de marzo") >= 0 and joined.find("restitución") >= 0, "ventanas: la carta se rotula como dramatización, con la nota de fecha y la del relieve")
	_find_button("Empezar", game).pressed.emit()
	await _frames(2)
	suite.check(str(hx.qa_state().mode) == "opening" and not hx.hud.root.visible, "ventanas: «Empezar» abre la presentación de cámara y esconde el HUD")
	var seconds: float = hx.cam.opening_seconds()
	suite.check(seconds >= 12.0 and seconds <= 15.0, "ventanas: la presentación dura de 12 a 15 s (%.1f s) con el reloj de juego en 0:00" % seconds)
	suite.check(float(hx.qa_state().elapsed) == 0.0, "ventanas: durante la presentación el reloj de juego sigue en 0:00")
	await _key(KEY_X)
	suite.check(str(hx.qa_state().mode) == "play" and hx.hud.root.visible, "ventanas: cualquier tecla salta la presentación")
	# menú de pausa
	hx.orders.issue("reconocedores", "recon", hx.landmark_pos("bateria"), {})
	await _key(KEY_ESCAPE)
	suite.check(str(hx.qa_state().dialog) == "pausa", "ventanas: el menú de pausa se abre")
	var names := ["resume", "save", "load", "help", "diary", "retreat", "menu"]
	suite.check(names.all(func(n): return game.find_child("HxPause_%s" % n, true, false) != null), "ventanas: el menú de pausa trae seguir, guardar, cargar, ayuda, diario, retirada y menú")
	(game.find_child("HxPause_retreat", true, false) as Button).pressed.emit()
	await _frames(2)
	suite.check(str(hx.qa_state().dialog) == "confirmar" and str(hx.qa_state().status) == "playing", "ventanas: la retirada general pide un segundo clic (confirmar)")
	_find_button("No, seguir", game).pressed.emit()
	await _frames(2)
	suite.check(str(hx.qa_state().dialog) == "pausa" and str(hx.qa_state().status) == "playing", "ventanas: «No, seguir» vuelve al menú de pausa sin retirarse")
	(game.find_child("HxPause_help", true, false) as Button).pressed.emit()
	await _frames(2)
	suite.check(str(hx.qa_state().dialog) == "ayuda", "ventanas: «Cómo se juega» abre la ayuda")
	var help_text := " ".join(PackedStringArray(_visible_texts()))
	suite.check(help_text.find("Teclas") >= 0 and help_text.find("Documentado") >= 0 and help_text.find("Sin datos suficientes") >= 0, "ventanas: la ayuda trae las teclas y las cinco etiquetas")
	await _key(KEY_ESCAPE)
	(game.find_child("HxPause_diary", true, false) as Button).pressed.emit() if game.find_child("HxPause_diary", true, false) != null else null
	await _key(KEY_ESCAPE)
	# decisión con reloj: se arma desde lo que devuelvan las reglas y se resuelve sola a los 25 s
	var dec := {"id": "informante", "titulo": "Un informante quiere hablar", "texto": "Un vecino dice que la guardia se duerme.", "opciones": [{"id": "creer", "label": "Creerle", "costo_txt": "Pierde la ruta"}, {"id": "ignorar", "label": "Seguir con el plan", "costo_txt": "Sin costo"}], "vence_s": 25.0}
	hx.open_decision(dec)
	await _frames(2)
	suite.check(str(hx.qa_state().dialog) == "decision" and game.find_child("HxOption_creer", true, false) != null and game.find_child("HxOption_ignorar", true, false) != null, "ventanas: la decisión muestra sus opciones con su costo")
	hx.dialogs.update_decision(7.2)
	suite.check(hx.dialogs._decision_count.text.find("8") >= 0, "ventanas: la decisión muestra el reloj («%s»)" % hx.dialogs._decision_count.text)
	hx.dialogs.close()
	await _to_menu()


# ---------------------------------------------------------------------------------------------------------------------
# Primera decisión en menos de 60 s de juego (TR-117)

func _test_first_decision() -> void:
	if not suite.check(await _start_level(), "primera decisión: el nivel arranca"):
		return
	hx.hud.next_btn.pressed.emit()
	await _frames(2)
	var q: Dictionary = hx.qa_state()
	var first := float(hx.rules.state.stats.pacing.first_decision_s)
	suite.check(int(q.orders) == 1 and first >= 0.0 and first < 60.0, "primera decisión: la primera orden sale al apretar el botón del siguiente paso, a los %.1f s de juego (< 60 s)" % first)
	suite.check(float(q.first_order_s) >= 0.0 and float(q.first_order_s) < float(ui_json.get("hud_limits", {}).get("first_decision_max_s", 60.0)), "primera decisión: el controlador la registra (first_order_s = %.1f)" % float(q.first_order_s))
	suite.check(not bool(q.paused), "primera decisión: el reloj arranca con esa orden")
	await _to_menu()


# ---------------------------------------------------------------------------------------------------------------------
# Ciclo completo por la interfaz: menú → briefing → apertura → bot que sigue el «siguiente paso» → parte → reintento

## Sigue el «siguiente paso» (aprieta su botón) y deja correr el reloj de a un segundo (el paso con que deciden las políticas de reglas), hasta que termine la partida o se
## acabe `max_s`. Devuelve los segundos usados.
func _follow_guide(max_s: float, step: float = 1.0) -> float:
	var used := 0.0
	while used < max_s and str(hx.qa_state().status) == "playing":
		hx.refresh_hud_now()
		var b: Button = hx.hud.next_btn
		if b.visible and not b.disabled:
			b.pressed.emit()
		hx.qa_step(step)
		used += step
	return used


func _test_full_cycle() -> void:
	await _to_menu()
	var button := _find_button("HUMAHUACA")
	if not suite.check(button != null, "ciclo: el menú trae el botón de Humahuaca"):
		return
	button.pressed.emit()
	await _frames(4)
	hx = game.hx
	suite.check(game.mode == "hx" and is_instance_valid(hx) and str(hx.qa_state().dialog) == "briefing", "ciclo: el botón abre el nivel en su briefing")
	_find_button("Empezar", game).pressed.emit()
	await _frames(2)
	await _key(KEY_X)
	suite.check(str(hx.qa_state().mode) == "play", "ciclo: empezar, mirar la presentación y saltarla deja el nivel jugable")
	var seed0 := int(hx.qa_state().seed)
	# el bot que sigue solo el «siguiente paso» llega al desenlace (victoria o derrota) y aparece el parte
	var used := _follow_guide(1400.0)
	await _frames(3)
	var q: Dictionary = hx.qa_state()
	suite.check(str(q.status) != "playing", "ciclo: el bot que sigue el siguiente paso llega a un desenlace (%s en %.0f s de juego)" % [str(q.status), float(q.elapsed)])
	suite.check(str(q.mode) == "ended" and str(q.dialog) == "parte", "ciclo: al terminar se muestra el parte")
	var all_text := " ".join(PackedStringArray(_visible_texts()))
	var victory := str(q.status) == "victory"
	if victory:
		suite.check(all_text.find("Medalla") >= 0 and all_text.find("3 de marzo") >= 0 and all_text.find("9 al 16 de marzo") >= 0 and all_text.find("6 de julio") >= 0, "ciclo: el parte de victoria trae la medalla y el epílogo fechado")
		suite.check(all_text.find("En la realidad") >= 0 and all_text.find("En tu partida") >= 0 and all_text.find("26 horas") >= 0, "ciclo: el parte contrasta «en la realidad» con «en tu partida» y aclara el tiempo comprimido")
		suite.check(_find_button("Ver la campaña completa: Sostener el norte", game) != null and _find_button("Jugar de nuevo", game) != null, "ciclo: el parte ofrece «Ver la campaña completa: Sostener el norte» y «Jugar de nuevo»")
		suite.check(all_text.find("Güemes lo recibe") >= 0 and all_text.find("expulsión definitiva") < 0, "ciclo: Güemes recibe el parte y no se habla de expulsión definitiva")
	else:
		suite.check(_find_button("Reintentar", game) != null, "ciclo: el parte de derrota ofrece reintentar")
	var retry_button := game.find_child("HxRetry", true, false) as Button
	var vp := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	suite.check(retry_button != null and _inside(Kit.rect_of(retry_button), vp) and not hx.dialogs.scroll_used, "ciclo: el botón principal del parte está a la vista, sin scroll (%s)" % str(Kit.rect_of(retry_button) if retry_button != null else "no existe"))
	suite.check(_inside(Kit.rect_of(hx.dialogs.panel), vp), "ciclo: el parte entra entero en el cuadro (%s en %s)" % [str(Kit.rect_of(hx.dialogs.panel)), str(vp.size)])
	# reintentar: mismo mundo, y rápido
	var t0 := Time.get_ticks_msec()
	retry_button.pressed.emit()
	await _frames(2)
	var retry_s := float(Time.get_ticks_msec() - t0) / 1000.0
	suite.check(str(hx.qa_state().mode) == "play" and int(hx.qa_state().seed) == seed0 or victory, "ciclo: «%s» deja el nivel jugable (mismo mundo: semilla %d)" % ["Jugar de nuevo" if victory else "Reintentar", int(hx.qa_state().seed)])
	suite.check(retry_s <= float(ui_json.get("hud_limits", {}).get("retry_max_s", 3.0)), "ciclo: del clic en reintentar al primer cuadro jugable pasan ≤ 3 s (%.2f s)" % retry_s)
	suite.extra["reintento_s"] = snappedf(retry_s, 0.01)
	# la derrota por pasividad (nadie ordena nada) y su parte: causa, consejo, tres datos y el botón principal sin scroll
	hx.qa_step(500.0)
	await _frames(3)
	var d: Dictionary = hx.qa_state()
	suite.check(str(d.status) == "defeat" and str(d.dialog) == "parte", "ciclo: sin órdenes se pierde y aparece el parte de derrota (%s a los %.0f s)" % [str(d.status), float(d.elapsed)])
	var cause := game.find_child("HxCause", true, false) as Label
	suite.check(cause != null and cause.text.length() > 0 and cause.text.length() <= 140, "ciclo: la causa de la derrota tiene ≤ 140 caracteres (%d)" % (cause.text.length() if cause != null else -1))
	suite.check(game.find_child("HxAdvice", true, false) != null and game.find_child("HxFacts", true, false) != null, "ciclo: el parte de derrota trae el consejo y los datos de la partida")
	var facts := game.find_child("HxFacts", true, false) as Control
	suite.check(facts != null and facts.get_child_count() >= 3, "ciclo: el parte de derrota muestra al menos tres datos (%d)" % (facts.get_child_count() if facts != null else 0))
	var retry2 := game.find_child("HxRetry", true, false) as Button
	suite.check(retry2 != null and _inside(Kit.rect_of(retry2), vp) and not hx.dialogs.scroll_used and _inside(Kit.rect_of(hx.dialogs.panel), vp), "ciclo: «Reintentar» queda a la vista y sin scroll en el parte de derrota")
	var defeat_text := " ".join(PackedStringArray(_visible_texts()))
	suite.check(defeat_text.find("campaña") < 0 and _jargon_hits(defeat_text).is_empty(), "ciclo: la derrota no ofrece ir al Norte y no usa jerga (%s)" % str(_jargon_hits(defeat_text)))
	var seed_before := int(hx.qa_state().seed)
	retry2.pressed.emit()
	await _frames(2)
	suite.check(int(hx.qa_state().seed) == seed_before and str(hx.qa_state().mode) == "play" and float(hx.qa_state().elapsed) == 0.0, "ciclo: reintentar tras la derrota mantiene el mismo mundo y vuelve a 0:00")
	suite.check(float(hx.retry_ms) >= 0.0 and float(hx.retry_ms) <= 3000.0, "ciclo: reintento medido por el controlador ≤ 3 s (%d ms)" % int(hx.retry_ms))
	await _to_menu()


# ---------------------------------------------------------------------------------------------------------------------
# En R1 el experto gana y el pasivo pierde por la escena real

func _test_expert_wins_passive_loses() -> void:
	if not suite.check(await _start_level(), "experto y pasivo: el nivel arranca"):
		return
	var used := _follow_guide(1400.0)
	var won := str(hx.qa_state().status) == "victory"
	suite.check(won, "experto: el que sigue el siguiente paso gana por la escena real (%s a los %.0f s de juego)" % [str(hx.qa_state().status), float(hx.qa_state().elapsed)])
	suite.check(float(hx.qa_state().elapsed) >= 300.0 and float(hx.qa_state().elapsed) <= 840.0, "experto: la partida dura lo que debe (%.0f s, plazo 840 s)" % float(hx.qa_state().elapsed))
	suite.extra["experto"] = {"fuente": "siguiente_paso", "estado": str(hx.qa_state().status), "segundos": snappedf(float(hx.qa_state().elapsed), 0.1), "ordenes": int(hx.qa_state().orders)}
	await _to_menu()
	if not suite.check(await _start_level(), "experto y pasivo: el nivel vuelve a arrancar"):
		return
	hx.qa_step(500.0)
	var rep: Dictionary = hx.rules.campaign_report()
	suite.check(str(hx.qa_state().status) == "defeat" and str(rep.cause_id) == "amanecio", "pasivo: el que no ordena nada pierde por «amanecio» por la escena real (%s)" % str(rep.get("cause_id", "")))
	suite.extra["pasivo"] = {"estado": str(hx.qa_state().status), "causa": str(rep.get("cause_id", "")), "segundos": snappedf(float(hx.qa_state().elapsed), 0.1)}
	await _to_menu()


# ---------------------------------------------------------------------------------------------------------------------
# Guardar y cargar por la interfaz (F5 y F9; «Continuar» llega con opts.load)

func _test_save_load() -> void:
	if FileAccess.file_exists("user://save_humahuaca.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save_humahuaca.json"))
	if not suite.check(await _start_level(), "guardado: el nivel arranca"):
		return
	var last_before := str(game.settings.last_save)
	hx.hud.next_btn.pressed.emit()
	hx.qa_step(40.0)
	var elapsed_saved := float(hx.qa_state().elapsed)
	await _key(KEY_F5)
	suite.check(FileAccess.file_exists(str(game._save_path("humahuaca"))), "guardado: F5 escribe save_humahuaca.json")
	suite.check(str(game.settings.last_save) == "humahuaca", "guardado: F5 fija settings.last_save = humahuaca (era «%s»)" % last_before)
	hx.qa_step(30.0)
	suite.check(float(hx.qa_state().elapsed) > elapsed_saved + 20.0, "guardado: después de guardar la partida siguió avanzando")
	await _key(KEY_F9)
	suite.check(is_equal_approx(float(hx.qa_state().elapsed), elapsed_saved), "guardado: F9 recupera la partida guardada (%.1f s)" % float(hx.qa_state().elapsed))
	suite.check(str(hx.qa_state().toast).find("recuperada") >= 0, "guardado: F9 avisa que la partida se recuperó («%s»)" % str(hx.qa_state().toast))
	# «Continuar» desde el menú abre Humahuaca con lo guardado
	await _to_menu()
	game._load_game("humahuaca")
	await _frames(4)
	hx = game.hx
	suite.check(game.mode == "hx" and is_instance_valid(hx) and is_equal_approx(float(hx.qa_state().elapsed), elapsed_saved), "guardado: «Continuar» abre el nivel con la partida guardada (%.1f s)" % float(hx.qa_state().elapsed))
	suite.check(str(hx.qa_state().mode) == "play" and bool(hx.qa_state().paused), "guardado: al continuar se juega, en pausa, sin repetir el briefing")
	# un guardado dañado termina en un mensaje claro y en el briefing, sin error ni cuelgue
	await _to_menu()
	var f := FileAccess.open(str(game._save_path("humahuaca")), FileAccess.WRITE)
	f.store_string("esto no es json {")
	f.close()
	game._load_game("humahuaca")
	await _frames(4)
	hx = game.hx
	suite.check(game.mode == "hx" and is_instance_valid(hx) and str(hx.qa_state().dialog) == "briefing", "guardado: un guardado dañado termina en el briefing, no en un error")
	suite.check(hx.hud.warn_l.text.find("guardada") >= 0, "guardado: y dice por qué («%s»)" % hx.hud.warn_l.text)
	# un guardado de otro escenario se rechaza con motivo
	await _to_menu()
	var g2 := FileAccess.open(str(game._save_path("humahuaca")), FileAccess.WRITE)
	g2.store_string(JSON.stringify({"scenario": "justine", "schema_version": 1}))
	g2.close()
	game._load_game("humahuaca")
	await _frames(4)
	hx = game.hx
	suite.check(str(hx.qa_state().dialog) == "briefing" and hx.hud.warn_l.text.find("Empezás de nuevo") >= 0, "guardado: un guardado de otro escenario se rechaza y empieza de nuevo («%s»)" % hx.hud.warn_l.text)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(str(game._save_path("humahuaca"))))
	game.settings.last_save = last_before
	await _to_menu()


# ---------------------------------------------------------------------------------------------------------------------
# Banderas de línea de comandos (CONTRATO 4.3): --hx-seed, --hx-phase y --hx-skip-intro las lee el controlador

func _test_cli_flags() -> void:
	var f: Dictionary = Ctl.parse_flags(["--scenario=humahuaca", "--hx-seed=3", "--hx-phase=ataque", "--hx-skip-intro", "--otra"])
	suite.check(int(f.get("seed", -1)) == 3 and str(f.get("phase", "")) == "ataque" and bool(f.get("skip_intro", false)), "banderas: --hx-seed, --hx-phase y --hx-skip-intro se leen (%s)" % str(f))
	suite.check(Ctl.parse_flags([]).is_empty() and Ctl.parse_flags(["--qa=humahuaca"]).is_empty(), "banderas: sin banderas del nivel no se inventa ninguna")
	suite.check(Ctl.parse_flags(["--hx-seed=abc"]).get("seed", -1) == 0, "banderas: una semilla que no es número vale 0 y no rompe")


## Con opts el controlador fija semilla, fase y presentación (las banderas completan lo que opts no trae).
func _test_opts_flags() -> void:
	if not await _start_level({"seed": 29, "phase": "ataque", "skip_intro": true}):
		suite.check(false, "banderas: el nivel arranca con semilla, fase y presentación por opts")
		return
	suite.check(int(hx.qa_state().seed) == 29 and str(hx.qa_state().phase) == "ataque" and str(hx.qa_state().mode) == "play", "banderas: opts fija la semilla 29, la fase «ataque» y salta el briefing")
	await _to_menu()


# ---------------------------------------------------------------------------------------------------------------------
# Desborde: ningún panel fuera del cuadro y las ventanas enteras a 1024 × 640, 1280 × 720 y 1920 × 1080

func _test_overflow_sizes() -> void:
	await _test_opts_flags()
	for size in [Vector2i(1024, 640), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		await _set_window(size)
		if not await _start_level():
			suite.check(false, "desborde %dx%d: el nivel arranca" % [size.x, size.y])
			continue
		var vp := Rect2(Vector2.ZERO, root.get_visible_rect().size)
		var out: Array = []
		for key in hx.hud.rects():
			var r: Rect2 = hx.hud.rects()[key]
			if r.size != Vector2.ZERO and not _inside(r, vp):
				out.append("%s %s" % [str(key), str(r)])
		var mm: Rect2 = Kit.rect_of(hx.minimap)
		if not _inside(mm, vp):
			out.append("minimapa %s" % str(mm))
		suite.check(out.is_empty(), "desborde %dx%d: ningún panel del HUD ni el minimapa sale del cuadro (%s)" % [size.x, size.y, str(out)])
		var dock: Rect2 = hx.hud.rects().dock
		suite.check(not dock.intersects(mm.grow(-1.0)), "desborde %dx%d: el dock no pisa el minimapa" % [size.x, size.y])
		var header: Rect2 = hx.hud.rects().header
		var fronts: Rect2 = hx.hud.rects().fronts
		suite.check(not header.intersects(fronts.grow(-1.0)), "desborde %dx%d: la cabecera no pisa las tarjetas de frente" % [size.x, size.y])
		# las ventanas
		var checks_ok := true
		for opener in ["pausa", "ayuda", "diario"]:
			match opener:
				"pausa":
					hx.orders.issue("reconocedores", "recon", hx.landmark_pos("bateria"), {})
					hx.open_pause_menu()
				"ayuda":
					hx.dialogs.close()
					hx.open_help()
				"diario":
					hx.dialogs.show_diary([])
			await _frames(2)
			if hx.dialogs.panel == null or not _inside(Kit.rect_of(hx.dialogs.panel), vp):
				checks_ok = false
		hx.dialogs.close()
		suite.check(checks_ok, "desborde %dx%d: la pausa, la ayuda y el diario entran enteros en el cuadro" % [size.x, size.y])
		hx.qa_step(500.0)
		await _frames(3)
		var panel: Control = hx.dialogs.panel
		suite.check(panel != null and _inside(Kit.rect_of(panel), vp) and not hx.dialogs.scroll_used, "desborde %dx%d: el parte de derrota entra entero y sin scroll (%s)" % [size.x, size.y, str(Kit.rect_of(panel)) if panel != null else "sin parte"])
		await _to_menu()
	await _set_window(Vector2i(1280, 720))


# ---------------------------------------------------------------------------------------------------------------------
# Textos: ninguna cadena visible de la interfaz tiene jerga (JSON de interfaz y briefing de las reglas)

func _walk_strings(node: Variant, path: String, out: Array) -> void:
	if node is Dictionary:
		for k in node:
			if str(k) == "jargon_blacklist":
				continue
			_walk_strings(node[k], path + "." + str(k), out)
	elif node is Array:
		for i in range((node as Array).size()):
			_walk_strings(node[i], "%s[%d]" % [path, i], out)
	elif node is String and " " in str(node):
		out.append([path, str(node)])


func _test_texts() -> void:
	var strings: Array = []
	_walk_strings(ui_json, "ui", strings)
	var hits: Array = []
	for pair in strings:
		for h in _jargon_hits(str(pair[1])):
			hits.append("%s: %s" % [str(pair[0]), str(h)])
	suite.check(hits.is_empty(), "textos: ninguna cadena de humahuaca_ui.json con espacios usa jerga ni identificadores (%d cadenas; %s)" % [strings.size(), str(hits)])
	suite.check(ui_json.get("jargon_blacklist", []).size() >= 20, "textos: la lista negra trae al menos 20 términos (%d)" % ui_json.get("jargon_blacklist", []).size())
	var tags: Dictionary = ui_json.get("source_tags", {})
	suite.check(V.TAGS.all(func(t): return tags.has(t) and str(tags[t].get("glifo", "")) != "" and str(tags[t].get("color", "")) != ""), "textos: las cinco etiquetas de fuente traen glifo y color")
	var rules_json := V.load_json(V.RULES_PATH)
	var brief: Dictionary = rules_json.get("texts", {}).get("briefing", {})
	var brief_text := str(brief.get("pagina_1", "")) + " " + str(brief.get("carta", {}).get("texto", "")) + " " + str(brief.get("nota_fecha", {}).get("texto", ""))
	suite.check(_jargon_hits(brief_text).is_empty(), "textos: el briefing de las reglas (fuente única) pasa sin jerga (%s)" % str(_jargon_hits(brief_text)))
	suite.check(str(ui_json.get("key_table", [])[0].get("id", "")) != "" and ui_json.get("key_table", []).size() >= 30, "textos: la tabla de teclas trae sus filas (%d)" % ui_json.get("key_table", []).size())


# ---------------------------------------------------------------------------------------------------------------------
# key_table: cada fila figura en docs/humahuaca/CONTROLES.md y sus teclas existen; las de las acciones no chocan con la cámara

func _test_key_table() -> void:
	var doc := FileAccess.get_file_as_string("res://docs/humahuaca/CONTROLES.md")
	var missing_show: Array = []
	var missing_label: Array = []
	var bad_keys: Array = []
	var conflicts: Array = []
	var camera_keys := ["W", "A", "S", "D", "Q", "E", "Up", "Down", "Left", "Right", "PageUp", "PageDown", "Home", "M"]
	for row in ui_json.get("key_table", []):
		var r := row as Dictionary
		if str(r.get("show", "")).replace("|", "/") != "" and doc.find(str(r.get("show", "")).replace("|", "/")) < 0:
			missing_show.append(str(r.get("id", "")))
		if doc.find(str(r.get("label", ""))) < 0:
			missing_label.append(str(r.get("id", "")))
		if str(r.get("group", "")) == "ordenes":
			continue
		for key_name in r.get("keys", []):
			var parts := str(key_name).split("+")
			var name_only := parts[parts.size() - 1]
			if Ctl._keycode(name_only) == 0:
				bad_keys.append("%s:%s" % [str(r.get("id", "")), str(key_name)])
			if str(r.get("group", "")) == "acciones" and camera_keys.has(name_only):
				conflicts.append("%s usa %s, que es de la cámara" % [str(r.get("id", "")), name_only])
	suite.check(missing_show.is_empty(), "key_table: cada tecla de la tabla figura en CONTROLES.md (%s)" % str(missing_show))
	suite.check(missing_label.is_empty(), "key_table: cada descripción de la tabla figura en CONTROLES.md (%s)" % str(missing_label))
	suite.check(bad_keys.is_empty(), "key_table: todas las teclas de la tabla son teclas reales (%s)" % str(bad_keys))
	suite.check(conflicts.is_empty(), "key_table: las teclas de las acciones no chocan con la cámara ni con el minimapa (%s)" % str(conflicts))
