extends SceneTree
## Prueba de interfaz y flujo del nivel «humahuaca» sobre la escena real, sin ventana (CONTRATO 5.1; dueña: ui_feel). Piso: 50 comprobaciones en R1, 80 desde R2a.
## godot --headless --path . --script tests/test_hx_flow.gd [-- --ronda=r1]   (con APPDATA aislado: borra archivos de perfil)
## Corre main.tscn con el controlador real, mueve la entrada como lo haría una persona (teclas y mouse por Viewport.push_input) y lee solo lo que el
## controlador ofrece (qa_state, los nodos de su interfaz y la API de QA): ninguna prueba toca atributos privados de main.
##   _test_reserved_keys · _test_first_frame · _test_full_cycle · _test_expert_wins_passive_loses · _test_first_decision · _test_save_load · _test_cli_flags
## más la cámara (A-11), las acciones y su vista previa, las ventanas, el desborde a tres tamaños y la jerga; en el pase 3 de R1, el objetivo por fase y los textos cortados
## (H-R1-10), los avisos de orden y de rechazo (B-046, B-052), el chip de carga (B-053), la confirmación de destruir, el conteo de intentos y el paso apagado con su causa. `--only=<id>` corre una sola (ids: primer_cuadro, camara, teclas,
## vista_previa, acciones, aviso, ventanas, hud_guiado, recortes, objetivo, avisos_orden, carga, avisos_pie, reintento, primera_decision, ciclo, experto_pasivo, guardado, banderas, desborde,
## textos, key_table). El «experto» de R1 es el que sigue el
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
	OS.set_low_processor_usage_mode_sleep_usec(300)  # sin ventana el motor dormía 6,9 ms en cada cuadro (más de la mitad de esta prueba era esperar cuadros): la prueba espera su propio trabajo
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


## Una pulsación entera (apretar y soltar) en un solo cuadro.
## Espera en tiempo real a que termine el deslizamiento de la cámara (Q-201), con tope.
func _wait_glide(max_s: float = 3.0) -> void:
	var t0 := Time.get_ticks_msec()
	await _frames(1)
	while hx.cam.approaching() and float(Time.get_ticks_msec() - t0) / 1000.0 < max_s:
		await process_frame
	await _frames(1)


func _tap(code: int) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		root.push_input(e)
	await process_frame


## Mantiene apretada una tecla lo que durarían `frames` cuadros a 60 por segundo (≈ 16,7 ms cada uno): por tiempo y no por cantidad de cuadros, porque la prueba corre los cuadros
## mucho más rápido que 60 por segundo y la cámara se mueve con el tiempo real.
func _hold(code: int, frames: int) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	root.push_input(e)
	var until := Time.get_ticks_msec() + int(float(frames) * 16.7)
	while Time.get_ticks_msec() < until:
		await process_frame
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


## Deja el nivel sin pasar por el menú, que arma el fondo de la Justina (≈ 0,5 s cada vez, la mitad de lo que tardaba esta prueba): el próximo `_start_level` detiene el controlador anterior.
## Solo las pruebas que necesitan el menú (el botón de Humahuaca) usan `_to_menu`.
func _leave_level() -> void:
	game._stop_humahuaca()
	await _frames(2)
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


func _want(only: String, id: String) -> bool:
	return only == "" or only == id


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
	await _set_window(Vector2i(1280, 720))  # el tamaño de partida de todas las pruebas: así `--only=<id>` no depende de lo que dejó la anterior
	# `--only=<id>` corre una sola prueba (para reproducir un hallazgo); sin él corren todas y valen el piso y el tiempo
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--only="):
			only = str(arg).trim_prefix("--only=")
	var plan: Array = [["primer_cuadro", _test_first_frame], ["camara", _test_camera], ["teclas", _test_reserved_keys], ["vista_previa", _test_preview_catches_up], ["acciones", _test_actions_and_preview],
		["aviso", _test_alert_placement], ["ventanas", _test_dialogs], ["hud_guiado", _test_hud_guided_selection], ["recortes", _test_cut_probe_sanity],
		["objetivo", _test_objective_by_phase], ["avisos_orden", _test_order_feedback], ["carga", _test_load_chip], ["avisos_pie", _test_alert_dedupe_and_tips],
		["reintento", _test_retry_counts], ["reintento_pasivo", _test_retry_passive], ["reintento_sin_control", _test_retry_refusal], ["deshacer", _test_undo], ["sugerir_x2", _test_suggest_x2], ["primera_decision", _test_first_decision],
		["ciclo", _test_full_cycle], ["experto_pasivo", _test_expert_wins_passive_loses], ["guardado", _test_save_load], ["banderas", _test_cli_flags],
		["desborde", _test_overflow_sizes], ["textos", _test_texts], ["key_table", _test_key_table]]
	var ms_by_test := {}
	for entry in plan:
		if _want(only, str(entry[0])):
			var t0 := Time.get_ticks_msec()
			await (entry[1] as Callable).call()
			ms_by_test[str(entry[0])] = Time.get_ticks_msec() - t0
	suite.extra["ms_por_prueba"] = ms_by_test  # dónde se va el tiempo de la suite (tope: 60 s)
	if only != "":
		if is_instance_valid(game):
			game.queue_free()
		await process_frame
		suite.finish(self)
		return
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
	# el encuadre inicial lo decide la cámara (data/humahuaca_camera.json, preset activo; docs/humahuaca/CAMARA.md): los tres objetivos a ≥ 10 % del borde (V02), las partidas que
	# el encuadre da por incluidas a ≥ 2 % y con su anillo a la vista, y ninguna ficha dentro del cuadro bajo el HUD (B-021). Las que quedan fuera del cuadro no cuentan: es el
	# compromiso del 2-11-2026 («centrado en el pueblo con la zona de partida al borde»). Antes (B-015) se exigían las cinco a ≥ 5,5 %: eso dejaba la cámara a 489 m, lo que el
	# usuario vio «muy chico». Con el rumbo de la mirada que fija el contrato (325°, A-11), en 1280 × 720 y a 1024 × 640.
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
		var fit: Dictionary = hx.cam.last_fit
		var included: Array = (fit.get("soft_in", []) as Array).duplicate()
		for h in hx.cam.preset(str(fit.get("preset", ""))).get("hard", []):  # el preset de la pista de arte exige las cinco partidas como puntos duros (P-006)
			if bool((h as Dictionary).get("units", false)):
				for gid in V.GROUPS:
					if not included.has(str(gid)):
						included.append(str(gid))
			if str((h as Dictionary).get("unit", "")) != "" and not included.has(str(h.unit)):  # visual/r1 F2: el preset cercano exige una partida suelta (los reconocedores)
				included.append(str(h.unit))
		var hard_objs: Array = []  # visual/r1 F2: los objetivos que el preset exige como duros, con su margen
		for h in hx.cam.preset(str(fit.get("preset", ""))).get("hard", []):
			if V.OBJECTIVES.has(str((h as Dictionary).get("landmark", ""))):
				hard_objs.append(h)
		var covered: Array = []
		var edge_in := 100.0
		var visible := 0
		for id in V.GROUPS:
			var u: Dictionary = hx.rules.get_unit(str(id))
			var s: Vector2 = _world_to_screen(float(u.x), float(u.z))
			var edge := 100.0 * minf(minf(s.x, view_rect.size.x - s.x) / view_rect.size.x, minf(s.y, view_rect.size.y - s.y) / view_rect.size.y)
			if edge >= 0.0:
				visible += 1
				for key in ["header", "fronts", "dock"]:
					if (hx.hud.rects()[key] as Rect2).has_point(s):
						covered.append("%s bajo %s" % [str(id), key])
			if included.has(str(id)):
				edge_in = minf(edge_in, edge)
		var obj_min := 100.0
		for fid in V.OBJECTIVES:
			var p: Vector2 = hx.landmark_pos(str(fid))
			var sp: Vector2 = _world_to_screen(p.x, p.y)
			obj_min = minf(obj_min, 100.0 * minf(minf(sp.x, view_rect.size.x - sp.x) / view_rect.size.x, minf(sp.y, view_rect.size.y - sp.y) / view_rect.size.y))
		suite.check(covered.is_empty(), "%dx%d: ninguna ficha dentro del cuadro queda bajo el HUD%s: %s" % [size.x, size.y, note, str(covered)])
		# visual/r1 F2 (revierte V02 de R1 a propósito): con la cámara a 150–180 m solo se exigen los objetivos que el preset pide como duros; los tres a 10 % se informan
		var hard_min := 100.0
		for h in hard_objs:
			var hp: Vector2 = hx.landmark_pos(str(h.landmark))
			var hs: Vector2 = _world_to_screen(hp.x, hp.y)
			hard_min = minf(hard_min, 100.0 * minf(minf(hs.x, view_rect.size.x - hs.x) / view_rect.size.x, minf(hs.y, view_rect.size.y - hs.y) / view_rect.size.y) - float(h.get("margin_pct", 0.0)))
		suite.check(not hard_objs.is_empty() and hard_min >= -0.5, "%dx%d: visual/r1 F2: los objetivos que exige el encuadre inicial (%d) quedan a la vista con su margen (holgura mínima %.1f %%)" % [size.x, size.y, hard_objs.size(), hard_min])
		suite.extra["v02_tres_objetivos_min_pct_%dx%d" % [size.x, size.y]] = snappedf(obj_min, 0.1)
		suite.check(included.has("reconocedores") and edge_in >= 2.0, "%dx%d: las partidas que el encuadre incluye (%s) quedan a ≥ 2 %% del borde con su anillo a la vista (mínimo %.1f %%), y los reconocedores, la primera que se usa, están entre ellas" % [size.x, size.y, str(included), edge_in])
		suite.extra["borde_min_%dx%d" % [size.x, size.y]] = snappedf(edge_in, 0.1)
		suite.extra["encuadre_%dx%d" % [size.x, size.y]] = {"preset": str(fit.get("preset", "")), "distancia_m": fit.get("dist", 0.0), "partidas_dentro_del_cuadro": visible, "incluidas": included}
		suite.check(not hx.hud.bar.visible and not hx.hud.notice_row.visible, "%dx%d: en el primer cuadro no hay barra de órdenes ni avisos de pie vacíos que ocupen lugar" % [size.x, size.y])
	await _set_window(Vector2i(1280, 720))
	await _leave_level()


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
	var min_m: float = hx.cam.min_dist()  # 30 m desde data/humahuaca_camera.json (antes 40: el usuario pidió poder acercar más con la rueda)
	suite.check(is_equal_approx(float(hx.qa_state().camera.dist), min_m) and min_m >= 15.0 and min_m <= 20.0, "cámara: el zoom no baja del mínimo de la cámara, entre 15 y 20 m (visual/r1 F2; %.0f m: %s)" % [min_m, str(hx.qa_state().camera.dist)])
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
	await _leave_level()


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
	await _wait_glide()  # Q-201: la segunda pulsación desliza la cámara (0,9 s) en vez de saltar
	var cuartel: Vector2 = hx.landmark_pos("cuartel")
	var tgt: Array = hx.qa_state().camera.target
	suite.check(Vector2(float(tgt[0]), float(tgt[1])).distance_to(cuartel) < 1.5, "teclas: pulsar 2 otra vez centra la cámara en el cuartel (%s vs %s)" % [str(tgt), str(cuartel)])
	await _key(KEY_5)
	suite.check(hx.qa_state().selected == ["arreo"], "teclas: 5 elige el arreo")
	await _key(KEY_5)
	await _wait_glide()
	var arreo_u: Dictionary = hx.rules.get_unit("arreo")
	var arreo_t: Array = hx.qa_state().camera.target
	suite.check(Vector2(float(arreo_t[0]), float(arreo_t[1])).distance_to(Vector2(float(arreo_u.x), float(arreo_u.z))) < 1.5, "teclas: pulsar 5 otra vez centra la cámara en el arreo (%s vs %.0f, %.0f)" % [str(arreo_t), float(arreo_u.x), float(arreo_u.z)])
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
	await _leave_level()
	# sin ninguna orden, Esc vuelve al menú
	if await _start_level():
		await _key(KEY_ESCAPE)
		await _frames(3)
		suite.check(game.mode == "menu" and game.hx == null, "teclas: sin órdenes dadas, Esc vuelve al menú y libera el controlador")
	await _leave_level()


# ---------------------------------------------------------------------------------------------------------------------
# La vista previa alcanza al cursor: si el último movimiento llegó dentro de los 80 ms del anterior, se rehace apenas pasa la espera (con el puntero real del SO moviéndose, la
# vista previa de ui_qa se quedaba con un punto de afuera del mapa: «Ese punto queda fuera del mapa.» sobre un punto válido)

func _test_preview_catches_up() -> void:
	if not suite.check(await _start_level(), "vista previa: el nivel arranca"):
		return
	await _key(KEY_4)
	await _key(KEY_R)
	hx.cam.cancel_approach()
	hx.qa_set_camera(Vector2(350.0, 470.0), 470.0, 52.0, 325.0)  # visual/r1 F2: el cuadro de antes (470 m), para que un punto fuera del mapa caiga en la pantalla
	await _frames(1)
	hx.orders.aim_move(_world_to_screen(-80.0, 300.0))
	suite.check(str(hx.orders.plan.get("reason", "")).find("fuera del mapa") >= 0, "vista previa: un punto de afuera del mapa dice que queda afuera (%s)" % str(hx.orders.plan.get("reason", "")))
	hx.orders.aim_move(_world_to_screen(318.0, 350.0))
	suite.check(str(hx.orders.plan.get("reason", "")).find("fuera del mapa") >= 0, "vista previa: un movimiento dentro de los 80 ms no rehace el plan en el momento")
	hx.orders.tick(0.2)
	suite.check(bool(hx.orders.plan.get("ok", false)) and hx.orders.preview_text("recon").find("riesgo") >= 0, "vista previa: pasada la espera el plan es el del punto donde quedó el cursor («%s»)" % hx.orders.preview_text("recon"))
	await _leave_level()


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
	# visual/r1 F2: con la cámara cerca los puntos de la ruta pueden quedar fuera del cuadro; se los encuadra (la cámara no es lo que se prueba acá)
	hx.cam.cancel_approach()
	hx.qa_set_camera(Vector2(190.0, 440.0), 300.0, 45.0, 325.0)
	await _frames(2)
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
	await _leave_level()


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
	hx.qa_set_camera(Vector2(330.0, 470.0), 470.0, 45.0, 325.0)  # visual/r1 F2: de lejos, para que las cinco fichas y los tres frentes estén delante de la cámara
	await _frames(2)
	var avoid: Array = hx.avoid_rects()
	suite.check(avoid.size() >= 8, "aviso: el controlador entrega un rectángulo por ficha y por frente (%d)" % avoid.size())
	await _leave_level()
	# la alerta más alta (título, texto largo y botón) con la barra de órdenes en su peor caso (todas las acciones y los ritmos) y un aviso de pie: nada se pisa
	for size in [Vector2i(1280, 720), Vector2i(1024, 640)]:
		await _set_window(size)
		if not suite.check(await _start_level({"skip_intro": true, "seed": 7}), "alerta y barra %dx%d: el nivel arranca" % [size.x, size.y]):
			continue
		for id in ["rodriguez", "portal", "arias"]:
			hx.orders.issue(id, "position")
		for wait in range(40):
			hx.qa_step(5.0)
			if bool(hx.rules.signal_info().can_give):
				break
		await _key(KEY_2)
		await _key(KEY_G)  # apuntando: la barra muestra las acciones y los tres ritmos
		hx.set_process(false)  # sin refresco: lo que sigue se arma a mano y no lo pisa el HUD
		var hh: Variant = hx.hud
		hh.alert_panel.visible = true
		hh.alert_title_l.text = "La torre del cuartel tiene la partida de Portal en la mira"
		hh.alert_text_l.text = "Si seguís avanzando por la calle abierta, la descarga llega en 7 segundos. Podés rodear por los patios o esperar la señal."
		hh.alert_btn.visible = true
		hh.alert_btn.text = "Rodear por los patios [P]"
		hh.toast_panel.visible = true
		hh.toast_l.text = "Cuartel de la casa del cura: la guardia dio la alarma."
		hh.place_alert([])
		await _frames(3)
		var crossing := _hud_crossings()
		var vp2 := Rect2(Vector2.ZERO, root.get_visible_rect().size)
		var inside := _inside(Kit.rect_of(hh.alert_panel), vp2) and _inside(Kit.rect_of(hh.bar), vp2) and _inside(Kit.rect_of(hh.dock), vp2)
		var alert_w: float = float(hh.alert_panel.offset_right) - float(hh.alert_panel.offset_left)
		suite.check(alert_w <= maxf(float(hh.root.size.x) * 0.4, 360.0) + 1.0, "alerta y barra %dx%d: en ventanas chicas la alerta es más angosta (%d px de %d)" % [size.x, size.y, int(alert_w), int(hh.root.size.x)])
		suite.check(hh.bar.visible and hh.alert_panel.is_visible_in_tree() and crossing.is_empty() and inside, "alerta y barra %dx%d: con la alerta más alta, la barra en su peor caso y un aviso de pie, ningún panel pisa a otro (%s)" % [size.x, size.y, str(crossing)])
		hx.set_process(true)
		await _leave_level()
	await _set_window(Vector2i(1280, 720))


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
	var span: Array = (hx.ui_data.get("camera", {}) as Dictionary).get("opening_s", [12.0, 15.0])  # ronda 4 de P2: apertura épica, 5 a 7 s
	suite.check(seconds >= float(span[0]) and seconds <= float(span[1]), "ventanas: la presentación dura lo que fija camera.opening_s (%.1f s, entre %.0f y %.0f) con el reloj de juego en 0:00" % [seconds, float(span[0]), float(span[1])])
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
	(game.find_child("HxPause_retreat", true, false) as Button).pressed.emit()
	await _frames(2)
	await _key(KEY_ESCAPE)
	suite.check(str(hx.qa_state().dialog) == "pausa" and str(hx.qa_state().status) == "playing" and bool(hx.qa_state().paused), "ventanas: Esc sobre la pregunta de la retirada es «No»: vuelve al menú de pausa y el reloj sigue frenado")
	(game.find_child("HxPause_help", true, false) as Button).pressed.emit()
	await _frames(2)
	suite.check(str(hx.qa_state().dialog) == "ayuda", "ventanas: «Cómo se juega» abre la ayuda")
	var help_text := " ".join(PackedStringArray(_visible_texts()))
	suite.check(help_text.find("Teclas") >= 0 and help_text.find("Documentado") >= 0 and help_text.find("Sin datos suficientes") >= 0, "ventanas: la ayuda trae las teclas y las cinco etiquetas")
	await _key(KEY_ESCAPE)
	# H-R1-2: la ayuda y el diario abiertos desde el menú de pausa vuelven a ese menú (el reloj sigue frenado), no al juego
	suite.check(str(hx.qa_state().dialog) == "pausa" and bool(hx.qa_state().paused), "ventanas: Esc en la ayuda vuelve al menú de pausa y el reloj sigue frenado (%s)" % str(hx.qa_state().dialog))
	(game.find_child("HxPause_diary", true, false) as Button).pressed.emit()
	await _frames(2)
	suite.check(str(hx.qa_state().dialog) == "diario" and _find_button("Cerrar", game) != null, "ventanas: el menú de pausa abre el diario con su botón «Cerrar»")
	_find_button("Cerrar", game).pressed.emit()
	await _frames(2)
	suite.check(str(hx.qa_state().dialog) == "pausa" and bool(hx.qa_state().paused), "ventanas: «Cerrar» en el diario vuelve al menú de pausa (%s)" % str(hx.qa_state().dialog))
	await _key(KEY_ESCAPE)
	suite.check(str(hx.qa_state().dialog) == "", "ventanas: Esc en el menú de pausa lo cierra")
	# decisión con reloj: se arma desde lo que devuelvan las reglas y se resuelve sola a los 25 s
	var dec := {"id": "informante", "titulo": "Un informante quiere hablar", "texto": "Un vecino dice que la guardia se duerme.", "opciones": [{"id": "creer", "label": "Creerle", "costo_txt": "Pierde la ruta"}, {"id": "ignorar", "label": "Seguir con el plan", "costo_txt": "Sin costo"}], "vence_s": 25.0}
	hx.open_decision(dec)
	await _frames(2)
	suite.check(str(hx.qa_state().dialog) == "decision" and game.find_child("HxOption_creer", true, false) != null and game.find_child("HxOption_ignorar", true, false) != null, "ventanas: la decisión muestra sus opciones con su costo")
	hx.dialogs.update_decision(7.2)
	suite.check(hx.dialogs._decision_count.text.find("8") >= 0, "ventanas: la decisión muestra el reloj («%s»)" % hx.dialogs._decision_count.text)
	hx.dialogs.close()
	await _leave_level()


# ---------------------------------------------------------------------------------------------------------------------
# H-R1-2: del parte se abre el Diario y se vuelve al parte; con la partida terminada nunca queda una pantalla sin controles ni salida

func _enabled_buttons() -> Array:
	var out: Array = []
	for b in game.find_children("*", "Button", true, false):
		if (b as Button).is_visible_in_tree() and not (b as Button).disabled:
			out.append(str((b as Button).text).replace("\n", " / "))
	return out


## El parte está en pantalla con su botón principal («Reintentar» o «Jugar de nuevo») a la vista y entero dentro del cuadro.
func _report_intact(label: String) -> void:
	var retry := game.find_child("HxRetry", true, false) as Button
	var vp := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	var seen: bool = retry != null and retry.is_visible_in_tree() and not retry.disabled and _inside(Kit.rect_of(retry), vp)
	suite.check(str(hx.qa_state().dialog) == "parte" and seen, "%s: vuelve el parte con «%s» a la vista (ventana «%s»)" % [label, retry.text if retry != null else "—", str(hx.qa_state().dialog)])


## Con el parte a la vista (derrota o victoria): abre el Diario y vuelve por clic, por Esc, por Enter y por Espacio; Esc, F1 y F9 no lo sacan de ahí; y si algo cierra la
## ventana por fuera, la partida terminada recupera su parte. Deja el parte a la vista.
func _navigate_report(kind: String) -> void:
	suite.check(_find_button("Diario", game) != null, "parte (%s): ofrece el botón «Diario»" % kind)
	await _click_at(Kit.rect_of(_find_button("Diario", game)).get_center())
	await _frames(3)
	suite.check(str(hx.qa_state().dialog) == "diario" and _find_button("Cerrar", game) != null, "parte (%s): el clic en «Diario» abre el diario con su botón «Cerrar»" % kind)
	await _click_at(Kit.rect_of(_find_button("Cerrar", game)).get_center())
	await _frames(3)
	_report_intact("parte (%s): clic en Diario y en Cerrar" % kind)
	await _click_at(Kit.rect_of(_find_button("Diario", game)).get_center())
	await _frames(2)
	await _key(KEY_ESCAPE)
	await _frames(2)
	_report_intact("parte (%s): Diario y Esc" % kind)
	for code in [KEY_ENTER, KEY_SPACE]:  # en el diario, Enter y Espacio son «Cerrar» (el botón principal)
		await _click_at(Kit.rect_of(_find_button("Diario", game)).get_center())
		await _frames(2)
		await _key(code)
		await _frames(2)
		_report_intact("parte (%s): Diario y %s" % [kind, "Enter" if code == KEY_ENTER else "Espacio"])
	for code in [KEY_ESCAPE, KEY_F1, KEY_F9]:
		await _key(code)
		await _frames(2)
	_report_intact("parte (%s): tras Esc, F1 y F9" % kind)
	suite.check(_enabled_buttons().size() >= 3, "parte (%s): siempre hay botones con los que seguir (%s)" % [kind, str(_enabled_buttons())])
	if _find_button("Mundo nuevo", game) != null:  # solo el parte de derrota: pide confirmación y «Esc» vuelve al parte
		await _click_at(Kit.rect_of(_find_button("Mundo nuevo", game)).get_center())
		await _frames(2)
		suite.check(str(hx.qa_state().dialog) == "confirmar", "parte (%s): «Mundo nuevo» pide confirmación" % kind)
		await _key(KEY_ESCAPE)
		await _frames(2)
		_report_intact("parte (%s): Mundo nuevo y Esc" % kind)
	hx.dialogs.close()
	await _frames(3)
	_report_intact("parte (%s): si la ventana se cierra por fuera" % kind)


# ---------------------------------------------------------------------------------------------------------------------
# H-R1-7: con fichas elegidas y avisos en pantalla, ningún panel del HUD pisa a otro y el «siguiente paso» entra en dos líneas

func _hud_crossings() -> Array:
	var out: Array = []
	var rects := {}
	var panels: Dictionary = hx.hud.panels()
	for key in panels:
		rects[key] = Kit.rect_of(panels[key] as Control)
	rects["minimapa"] = Kit.rect_of(hx.minimap)
	var keys := rects.keys()
	for i in range(keys.size()):
		for j in range(i + 1, keys.size()):
			var inter := (rects[keys[i]] as Rect2).intersection(rects[keys[j]] as Rect2)
			if inter.size.x > 1.0 and inter.size.y > 1.0 and inter.size.x * inter.size.y > 4.0:
				out.append("%s/%s %d px²" % [str(keys[i]), str(keys[j]), int(inter.size.x * inter.size.y)])
	return out


func _test_hud_guided_selection() -> void:
	for size in [Vector2i(1280, 720), Vector2i(1024, 640)]:
		await _set_window(size)
		if not suite.check(await _start_level({"skip_intro": true, "seed": 7}), "HUD guiado %dx%d: el nivel arranca" % [size.x, size.y]):
			continue
		var vp := Rect2(Vector2.ZERO, root.get_visible_rect().size)
		var crossings: Dictionary = {}
		var outside := 0
		var lines_max := 0
		var width_min := 1.0e9
		var toasts := 0
		var bars := 0
		var steps := 0
		var cuts: Dictionary = {}
		var overlaps: Dictionary = {}
		while steps < 90 and str(hx.qa_state().status) == "playing" and str(hx.qa_state().dialog) == "":
			hx.qa_press_next()
			await _tap(KEY_1 + (steps % 5))  # el jugador va eligiendo fichas con las teclas 1 a 5: cada elección cambia la barra de órdenes
			hx.qa_step(5.0)
			await _frames(1)
			steps += 1
			for c in _hud_crossings():
				var k := str(c).split(" ")[0]
				crossings[k] = int(crossings.get(k, 0)) + 1
			var panels: Dictionary = hx.hud.panels()
			for key in panels:
				if not _inside(Kit.rect_of(panels[key] as Control), vp):
					outside += 1
			if hx.hud.next_text_l.is_visible_in_tree():
				lines_max = maxi(lines_max, hx.hud.next_text_l.get_line_count())
				width_min = minf(width_min, hx.hud.next_text_l.size.x * hx.ui_scale)
			if hx.hud.toast_panel.visible:
				toasts += 1
			for cut in Kit.cut_labels(game.ui):
				cuts[str(cut.text)] = cut
			if steps % 3 == 0:  # la cuenta de solapes mira todas las parejas de textos: cada tres pasos alcanza para ver cualquier arreglo que se repita
				for ov in Kit.text_overlaps(game.ui):
					overlaps["%s/%s" % [str(ov.a), str(ov.b)]] = ov
			var bar_node: Variant = hx.hud.get("bar")
			if bar_node != null and (bar_node as Control).visible:
				bars += 1
		suite.check(steps >= 80, "HUD guiado %dx%d: la partida guiada corrió %d pasos con fichas elegidas" % [size.x, size.y, steps])
		suite.check(toasts > 0 and bars > 0, "HUD guiado %dx%d: hubo avisos de pie (%d pasos) y barra de órdenes (%d pasos) a la vista" % [size.x, size.y, toasts, bars])
		suite.check(crossings.is_empty(), "HUD guiado %dx%d: 0 pares de paneles del HUD con intersección (%s)" % [size.x, size.y, str(crossings)])
		suite.check(outside == 0, "HUD guiado %dx%d: ningún panel del HUD sale del cuadro (%d veces)" % [size.x, size.y, outside])
		suite.check(lines_max <= 2, "HUD guiado %dx%d: el texto del «siguiente paso» ocupa %d líneas como máximo (límite: 2)" % [size.x, size.y, lines_max])
		suite.check(width_min >= 250.0, "HUD guiado %dx%d: el «siguiente paso» nunca queda en una columna angosta (mínimo %d px)" % [size.x, size.y, int(width_min)])
		suite.check(cuts.is_empty(), "HUD guiado %dx%d: ningún texto queda cortado en %d pasos (H-R1-10; %d distintos: %s)" % [size.x, size.y, steps, cuts.size(), str(cuts.values().slice(0, 2))])
		suite.check(overlaps.is_empty(), "HUD guiado %dx%d: ningún texto pisa a otro en %d pasos (C01; %d distintos: %s)" % [size.x, size.y, steps, overlaps.size(), str(overlaps.values().slice(0, 2))])
		suite.extra["hud_guiado_%dx%d" % [size.x, size.y]] = {"pasos": steps, "cruces": crossings, "lineas_siguiente_max": lines_max, "ancho_siguiente_min_px": int(width_min), "pasos_con_aviso": toasts, "pasos_con_barra": bars}
		await _leave_level()
	await _set_window(Vector2i(1280, 720))


# ---------------------------------------------------------------------------------------------------------------------
# H-R1-10: el objetivo dice algo vigente en cada fase y ningún texto queda cortado (1280 × 720, 1024 × 640 y 1920 × 1080)

## La medida de recortes sabe contar: una etiqueta angosta con un texto largo da un recorte y una que entra, no.
func _test_cut_probe_sanity() -> void:
	var holder := Control.new()
	holder.size = Vector2(400.0, 100.0)
	root.add_child(holder)
	var narrow := Kit.trimmed(Kit.label(holder, "Reconocedores de la retaguardia", 13))
	narrow.size = Vector2(60.0, 20.0)
	var wide := Kit.trimmed(Kit.label(holder, "Rodríguez", 13))
	wide.position = Vector2(0.0, 30.0)
	wide.size = Vector2(300.0, 20.0)
	await _frames(2)
	var cuts: Array = Kit.cut_labels(holder)
	suite.check(cuts.size() == 1 and str(cuts[0].text).begins_with("Reconocedores"), "recortes: la medida marca la etiqueta angosta y deja pasar la que entra (%s)" % str(cuts))
	wide.size = Vector2(20.0, 20.0)
	await _frames(2)
	suite.check(Kit.cut_labels(holder).size() == 2, "recortes: y si la otra también se angosta, marca las dos")
	holder.queue_free()


func _test_objective_by_phase() -> void:
	var cfg: Dictionary = ui_json.get("texts", {}).get("objective", {})
	var by_phase: Dictionary = cfg.get("by_phase", {})
	suite.check(str(cfg.get("source", "")) == "ui" and ["aproximacion", "ataque", "extraccion", "epilogo"].all(func(p): return by_phase.get(p, []) is Array and not (by_phase.get(p, []) as Array).is_empty()), "objetivo: humahuaca_ui.json trae una lista de frases por fase (aproximación, ataque, extracción y epílogo)")
	var longest := 0
	for p in by_phase:
		for v in by_phase[p]:
			longest = maxi(longest, str(v).length())
	suite.check(longest <= 80, "objetivo: ninguna frase pasa de 80 caracteres (la más larga mide %d)" % longest)
	var sizes := [Vector2i(1280, 720), Vector2i(1024, 640), Vector2i(1920, 1080)]
	var seen: Dictionary = {}  # tamaño → fase → frase
	var cut_texts: Dictionary = {}  # tamaño → los textos cortados que se vieron
	for size in sizes:
		seen["%dx%d" % [size.x, size.y]] = {}
		cut_texts["%dx%d" % [size.x, size.y]] = []
	await _set_window(sizes[0])
	for phase in ["briefing", "aproximacion", "ataque", "extraccion"]:
		var opts := {"skip_intro": true, "seed": 7}
		if phase == "briefing":
			opts = {}  # la fase «Preparación» es la de antes de la primera orden: se llega por el briefing, como el jugador
		else:
			opts["phase"] = phase
		if not suite.check(await _start_level(opts), "objetivo · %s: el nivel arranca" % phase):
			continue
		if phase == "briefing":
			_find_button("Empezar", game).pressed.emit()
			await _frames(2)
			await _key(KEY_X)  # cualquier tecla salta la presentación
		suite.check(str(hx.qa_state().phase) == phase, "objetivo · %s: la fase es la pedida (%s)" % [phase, str(hx.qa_state().phase)])
		for size in sizes:  # el mismo nivel a tres tamaños de ventana: lo que cambia es el ancho de la fila del objetivo
			await _set_window(size)
			hx.refresh_hud_now()
			await _frames(2)
			hx.refresh_hud_now()
			var key := "%dx%d" % [size.x, size.y]
			seen[key][phase] = str(hx.hud.objective_l.text)
			for cut in Kit.cut_labels(game.ui):
				(cut_texts[key] as Array).append("%s: %s (%s)" % [phase, str(cut.text), str(cut.why)])
			for ov in Kit.text_overlaps(game.ui):
				(cut_texts[key] as Array).append("%s: se pisan «%s» y «%s»" % [phase, str(ov.a), str(ov.b)])
		if phase == "extraccion":
			await _set_window(sizes[0])
			hx.hud.texts["objective"]["source"] = "rules"  # con «rules» manda lo que digan las reglas (cuando den la frase de cada fase, BACKLOG B-048)
			hx.refresh_hud_now()
			suite.check(hx.hud.objective_l.text == str(hx.rules.hud_state().objetivo), "objetivo: con la fuente «rules» el HUD pinta lo que dice hud_state().objetivo (%s)" % hx.hud.objective_l.text)
		await _leave_level()
	for size in sizes:
		var key := "%dx%d" % [size.x, size.y]
		suite.check((cut_texts[key] as Array).is_empty(), "objetivo %s: en las cuatro fases ningún texto del HUD queda cortado ni pisado (%s)" % [key, str(cut_texts[key])])
		var distinct := {}
		for k in seen[key]:
			distinct[str(seen[key][k])] = true
		suite.check(seen[key].size() == 4 and distinct.size() == 4 and seen[key].values().all(func(t): return str(t) != "" and not str(t).ends_with("…")), "objetivo %s: cada fase dice una frase propia, entera y sin «…» (%s)" % [key, str(seen[key])])
		suite.check(str(seen[key].get("extraccion", "")).to_lower().find("refuerzo") >= 0 and str(seen[key].get("extraccion", "")).find("Tomá") < 0, "objetivo %s: en la extracción habla de salir antes del refuerzo y ya no pide tomar los frentes (%s)" % [key, str(seen[key].get("extraccion", ""))])
		suite.extra["objetivo_por_fase_" + key] = seen[key]
	await _set_window(Vector2i(1280, 720))


# ---------------------------------------------------------------------------------------------------------------------
# B-046 y B-052: la orden dada se nombra, el rechazo dice quién sí puede y las paradas fuera del mapa no se suman

func _test_order_feedback() -> void:
	if not suite.check(await _start_level(), "avisos de orden: el nivel arranca"):
		return
	hx.hud.next_btn.pressed.emit()
	await _frames(2)
	suite.check(str(hx.qa_state().toast).begins_with("Orden dada a Reconocedores"), "avisos de orden: al dar una orden el aviso de pie dice cuál (%s)" % str(hx.qa_state().toast))
	# una acción que la agrupación elegida no puede hacer: el motivo dice quién sí
	await _key(KEY_4)
	hx.orders.press("attack")
	var m := str(hx.qa_state().motive)
	suite.check(m.find("Rodríguez") >= 0 and m.find("Portal") >= 0 and m.find("Arias") >= 0 and m.find("teclas 1 a 3") >= 0, "avisos de orden: «Atacar» con los reconocedores dice que lo hacen Rodríguez, Portal y Arias (%s)" % m)
	await _key(KEY_1)
	hx.orders.press("load")
	m = str(hx.qa_state().motive)
	suite.check(m.find("el arreo") >= 0 and m.find("tecla 5") >= 0, "avisos de orden: «Cargar» con Rodríguez dice que lo hace el arreo, con su tecla (%s)" % m)
	# las paradas fuera del mapa no se suman a la ruta; las de adentro, sí
	hx.cam.cancel_approach()
	hx.qa_set_camera(Vector2(350.0, 470.0), 470.0, 52.0, 325.0)  # visual/r1 F2: el cuadro de antes (470 m), para que un punto fuera del mapa caiga en la pantalla
	await _frames(1)
	var before: int = hx.orders.waypoints.size()
	suite.check(not hx.orders.context_order(_world_to_screen(-80.0, 300.0), true, false, false) and hx.orders.waypoints.size() == before, "avisos de orden: Mayús + clic derecho fuera del mapa no suma una parada")
	suite.check(str(hx.qa_state().motive).find("fuera del mapa") >= 0, "avisos de orden: y dice por qué (%s)" % str(hx.qa_state().motive))
	suite.check(hx.orders.context_order(_world_to_screen(200.0, 420.0), true, false, false) and hx.orders.waypoints.size() == before + 1, "avisos de orden: Mayús + clic derecho adentro del mapa sí suma la parada")
	# empezar un intento limpia lo pasajero: el motivo viejo, la orden en la mano y las paradas
	hx.retry("mismo_mundo")
	await _frames(2)
	suite.check(str(hx.qa_state().motive) == "" and hx.orders.waypoints.is_empty() and not bool(hx.qa_state().aiming), "avisos de orden: reintentar no deja el motivo viejo ni paradas sueltas (%s)" % str(hx.qa_state().motive))
	# la ayuda explica lo que se ve, y el cartel de los chips también
	hx.open_help()
	await _frames(2)
	var glossary := ""
	for t in _visible_texts():
		if str(t).begins_with("Golpe: cuánto valor") or str(t).begins_with("Desvelo:"):
			glossary += str(t) + " "
	suite.check(glossary.find("Golpe: cuánto valor") >= 0 and glossary.find("Desvelo:") >= 0, "ayuda: explica «Golpe» y «Desvelo», que nadie entendía (B-052)")
	hx.dialogs.close()
	suite.check(["golpe", "carga", "refuerzo"].all(func(id): return str(hx.hud.chip_labels[id].panel.tooltip_text) != "") and hx.hud.status_l.tooltip_text != "", "ayuda: los chips y la línea de la señal traen su cartel explicativo")
	await _leave_level()


# ---------------------------------------------------------------------------------------------------------------------
# B-053 (b): el arreo carga desde el ataque y el chip de carga se ve apenas empieza; y mientras carga, destruir a mano se pregunta

func _test_load_chip() -> void:
	if not suite.check(await _start_level({"skip_intro": true, "seed": 7, "phase": "ataque"}), "chip de carga: el nivel arranca en el ataque"):
		return
	var seen_in_attack := false
	var steps := 0
	while steps < 140 and not seen_in_attack and str(hx.qa_state().status) == "playing" and str(hx.qa_state().phase) == "ataque":
		_follow_guide(1.0)
		steps += 1
		hx.refresh_hud_now()
		if str(hx.qa_state().phase) != "ataque":
			break
		for c in hx.rules.hud_state().chips:
			if str(c.id) == "carga" and float(c.valor) > 0.0:
				seen_in_attack = true
	suite.check(seen_in_attack, "chip de carga: el arreo empieza a cargar mientras todavía es el ataque (a los %d s)" % steps)
	await _frames(3)
	hx.refresh_hud_now()
	suite.check(seen_in_attack and bool(hx.hud.chip_labels.carga.panel.visible), "chip de carga: apenas el arreo carga, el chip «Carga» se ve en el ataque (no recién en la extracción): %s" % str(hx.hud.chip_labels.carga.label.text))
	await _destroy_confirm_checks()
	await _leave_level()


# ---------------------------------------------------------------------------------------------------------------------
# Destruir a mano se pregunta (lo vio el agente-jugador: un X por costumbre quemó la carga sin avisar); si lo pide el siguiente paso, no

## Corre con el arreo junto a la carga y el siguiente paso pidiendo otra cosa (esperar a que cargue).
func _destroy_confirm_checks() -> void:
	if not suite.check(bool(hx.orders.availability("arreo", "destroy").get("ok", false)) and str(hx.qa_state().guide.action) != "destroy", "destruir: con el arreo junto a la carga se puede destruir y el siguiente paso no lo pide (%s)" % str(hx.qa_state().guide.action)):
		return
	await _key(KEY_5)
	var before := _issued_actions().size()
	await _key(KEY_X)
	suite.check(str(hx.qa_state().dialog) == "confirmar" and _find_button("Sí, destruir", game) != null and _find_button("No, esperar", game) != null, "destruir: apretar X sin que el siguiente paso lo pida abre la pregunta (%s)" % str(hx.qa_state().dialog))
	suite.check(_issued_actions().size() == before, "destruir: mientras se pregunta no se da ninguna orden")
	await _key(KEY_ESCAPE)
	suite.check(str(hx.qa_state().dialog) == "" and game.mode == "hx" and _issued_actions().size() == before, "destruir: Esc es «No»: cierra la pregunta, no abre el menú de pausa y no destruye nada")
	await _key(KEY_X)
	_find_button("No, esperar", game).pressed.emit()
	await _frames(2)
	suite.check(str(hx.qa_state().dialog) == "" and _issued_actions().size() == before and not _issued_actions().has("destroy"), "destruir: «No, esperar» vuelve al juego sin destruir")
	await _key(KEY_X)
	_find_button("Sí, destruir", game).pressed.emit()
	await _frames(2)
	suite.check(str(hx.qa_state().dialog) == "" and _issued_actions().has("destroy"), "destruir: «Sí, destruir» da la orden")


# ---------------------------------------------------------------------------------------------------------------------
# La extracción sin carga: el paso «salir» queda apagado y dice por qué; el aviso de pie no repite el título de la alerta que ya está a la vista (el refuerzo salía dos veces)

func _test_alert_dedupe_and_tips() -> void:
	if not suite.check(await _start_level({"skip_intro": true, "seed": 7, "phase": "extraccion"}), "avisos de pie: el nivel arranca en la extracción"):
		return
	hx.qa_step(40.0)  # nadie cargó: el siguiente paso pide salir, pero el arreo no lleva carga
	hx.refresh_hud_now()
	await _frames(3)  # las filas se acomodan un cuadro después de cambiar un texto: antes de medir cortes hay que dejarlas
	var g: Dictionary = hx.guide
	suite.check(str(g.get("action", "")) == "leave" and hx.hud.next_btn.visible and hx.hud.next_btn.disabled, "paso apagado: sin carga el paso «salir» queda con su botón apagado (%s)" % str(g.get("action", "")))
	suite.check(str(g.get("why", "")) != "" and hx.hud.next_text_l.text.find(str(g.get("why", ""))) >= 0, "paso apagado: el paso dice por qué («%s»)" % hx.hud.next_text_l.text)
	suite.check(hx.hud.next_text_l.get_line_count() <= 2 and Kit.cut_labels(game.ui).is_empty(), "paso apagado: la causa entra en las dos líneas del paso y no corta nada (%d líneas; %s)" % [hx.hud.next_text_l.get_line_count(), str(Kit.cut_labels(game.ui))])
	var steps := 0
	while steps < 600 and str(hx.rules.hud_state().refuerzo.estado) != "visible" and str(hx.qa_state().status) == "playing":
		hx.qa_step(1.0)
		steps += 1
	hx.refresh_hud_now()
	await _frames(2)
	hx.refresh_hud_now()
	var alert_title: String = hx.hud.alert_title_l.text
	suite.check(hx.hud.alert_panel.visible and alert_title.find("refuerzo") >= 0, "avisos de pie: llega la alerta del refuerzo (%s, a los %d s)" % [alert_title, steps])
	suite.check(str(hx.qa_state().toast) == alert_title and not hx.hud.toast_panel.visible, "avisos de pie: la nota de pie con el mismo título no se dibuja mientras la alerta está a la vista (nota: «%s»)" % str(hx.qa_state().toast))
	# la etiqueta de fuente y el ruido se explican solos
	await _key(KEY_4)
	hx.refresh_hud_now()
	var card: Dictionary = hx.hud.group_cards.reconocedores
	suite.check((card.tag as Label).visible and str((card.tag as Label).tooltip_text).find("Diseño") >= 0 and (card.tag as Label).mouse_filter == Control.MOUSE_FILTER_PASS, "etiquetas: el triángulo de la ficha elegida explica qué es al pasar el mouse (%s)" % str((card.tag as Label).tooltip_text).left(60))
	suite.check(str((card.noise as Label).tooltip_text) != "" and (card.noise as Label).mouse_filter == Control.MOUSE_FILTER_PASS, "etiquetas: los puntos del ruido también (%s)" % str((card.noise as Label).tooltip_text))
	suite.check(str(hx.hud.front_cards.bateria.panel.tooltip_text).find("Barra naranja") >= 0, "etiquetas: la tarjeta del frente explica la barra naranja de la alerta de la guardia")
	await _leave_level()


# ---------------------------------------------------------------------------------------------------------------------
# Un reintento desde un punto de control cuenta un solo intento (el agente-jugador vio «Intento 3» tras reintentar una vez)

func _test_retry_counts() -> void:
	if not suite.check(await _start_level({"skip_intro": true, "seed": 7}), "reintento: el nivel arranca"):
		return
	for id in ["rodriguez", "portal", "arias"]:
		hx.orders.issue(id, "position")
	var steps := 0
	while steps < 60 and not hx.progress.has_checkpoint("posiciones"):
		hx.qa_step(5.0)
		steps += 1
	suite.check(hx.progress.has_checkpoint("posiciones"), "reintento: con las tres partidas en su puesto queda el punto de control «posiciones» (a los %d s)" % (steps * 5))
	hx.qa_step(600.0)  # sin dar la señal amanece y se pierde: el parte ofrece reintentar desde las posiciones
	suite.check(str(hx.qa_state().status) == "defeat", "reintento: sin la señal se pierde (%s)" % str(hx.qa_state().status))
	var before := int(hx.progress.attempts)
	hx.speed = 4.0  # el intento anterior iba a ×4
	hx.retry("posiciones")
	await _frames(2)
	suite.check(int(hx.progress.attempts) == before + 1, "reintento: «Reintentar desde las posiciones» cuenta un solo intento (de %d a %d)" % [before, int(hx.progress.attempts)])
	suite.check(bool(hx.paused) and is_equal_approx(float(hx.speed), 1.0), "Q-202: volver a las posiciones deja el juego en pausa y a velocidad normal (pausa %s, ×%.0f)" % [str(hx.paused), float(hx.speed)])
	var u_ready := 0
	for id in ["rodriguez", "portal", "arias"]:
		if str((hx.rules.get_unit(id) as Dictionary).get("stage", "")) == "waiting_signal":
			u_ready += 1
	suite.check(u_ready == 3, "Q-202: y las tres partidas están en su puesto esperando la señal (%d de 3)" % u_ready)
	suite.check(str(hx.qa_state().mode) == "play" and float(hx.qa_state().elapsed) > 60.0 and str(hx.qa_state().status) == "playing", "reintento: y deja la partida jugable en el instante guardado (%.0f s)" % float(hx.qa_state().elapsed))
	var mid := int(hx.progress.attempts)
	hx.retry("mismo_mundo")
	await _frames(2)
	suite.check(int(hx.progress.attempts) == mid + 1, "reintento: «Reintentar» (mismo mundo) también cuenta uno solo (de %d a %d)" % [mid, int(hx.progress.attempts)])
	await _leave_level()


## Q-202 (QA ronda 2): perder sin dar órdenes (derrota pasiva) no deja un punto de control «posiciones»: antes se escribía a los 210 s aunque nadie hubiera llegado
## y el parte ofrecía una derrota segura.
func _test_retry_passive() -> void:
	if not suite.check(await _start_level({"skip_intro": true, "seed": 23}), "reintento pasivo: el nivel arranca"):
		return
	var wrote_at := -1.0
	for i in range(90):
		hx.qa_step(5.0)
		var st: Variant = hx._checkpoint_state("posiciones")
		if st is Dictionary and int((st as Dictionary).get("seed", -1)) == int(hx.qa_state().seed) and wrote_at < 0.0:
			wrote_at = float(hx.qa_state().elapsed)
		if str(hx.qa_state().status) != "playing":
			break
	suite.check(str(hx.qa_state().status) == "defeat", "reintento pasivo: sin órdenes se pierde (%s)" % str(hx.qa_state().status))
	var offered := false
	for o in hx.usable_retry_options():
		if str(o.id) == "posiciones" and bool(o.available):
			offered = true
	await _frames(3)
	suite.check(wrote_at < 0.0 and not offered and game.find_child("HxRetry_posiciones", true, false) == null, "Q-202: tras una derrota sin órdenes no se guarda ni se ofrece «Reintentar desde las posiciones» (guardado a los %.0f s)" % wrote_at)
	await _leave_level()


## T-005 (mitad interfaz): el parte no ofrece un punto de control que no se puede restaurar (aquí, uno de otro mundo: la semilla del archivo no es la de la partida) y,
## si igual se lo pide, se queda en el parte diciendo por qué en vez de empezar de cero en silencio.
func _test_retry_refusal() -> void:
	if not suite.check(await _start_level({"skip_intro": true, "seed": 7}), "reintento sin control: el nivel arranca"):
		return
	for id in ["rodriguez", "portal", "arias"]:
		hx.orders.issue(id, "position")
	var steps := 0
	while steps < 60 and not hx.progress.has_checkpoint("posiciones"):
		hx.qa_step(5.0)
		steps += 1
	var path := str(hx._checkpoint_path)
	var parser := JSON.new()
	var ok_cp: bool = hx.progress.has_checkpoint("posiciones") and FileAccess.file_exists(path) and parser.parse(FileAccess.get_file_as_string(path)) == OK
	suite.check(ok_cp, "reintento sin control: queda el punto de control «posiciones» en %s" % path)
	if ok_cp:
		var d: Dictionary = parser.data
		((d.points as Dictionary).posiciones.state as Dictionary)["seed"] = 999  # un control de otro mundo (revisión R-02)
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(JSON.stringify(d))
		f.close()
	hx.qa_step(600.0)
	await _frames(3)
	suite.check(str(hx.qa_state().dialog) == "parte", "reintento sin control: se pierde y aparece el parte")
	var offered := false
	for o in hx.usable_retry_options():
		if str(o.id) == "posiciones" and bool(o.available):
			offered = true
	suite.check(not offered and game.find_child("HxRetry_posiciones", true, false) == null, "reintento sin control: el parte no ofrece «Reintentar desde las posiciones» con un control de otro mundo")
	hx.retry("posiciones")
	await _frames(2)
	var note := game.find_child("HxReportNotice", true, false) as Label
	suite.check(str(hx.qa_state().dialog) == "parte" and str(hx.qa_state().mode) == "ended" and note != null and note.text.find("punto de control") >= 0, "reintento sin control: pedirlo igual deja el parte a la vista y dice por qué («%s»)" % (note.text if note != null else "—"))
	await _leave_level()


## T-008: Ctrl+Z deshace solo la última orden propia y solo si deja a la agrupación como estaba. Tras la señal no deshace la orden de otra agrupación; una orden que
## pisó otra etapa (sostener tras atacar) no se deshace a «esperando órdenes».
func _test_undo() -> void:
	if not suite.check(await _start_level({"skip_intro": true, "seed": 7}), "deshacer: el nivel arranca"):
		return
	hx.orders.issue("rodriguez", "position")
	var steps := 0
	while steps < 80 and str(hx.rules.call("get_unit", "rodriguez").stage) != "waiting_signal":
		hx.qa_step(5.0)
		steps += 1
	suite.check(str(hx.rules.call("get_unit", "rodriguez").stage) == "waiting_signal", "deshacer: Rodríguez llega a su puesto y espera la señal")
	hx.orders.issue("portal", "move", Vector2(300.0, 450.0))
	var portal_before := str(hx.rules.call("get_unit", "portal").stage)
	await _key(KEY_Z, true)
	suite.check(portal_before == "moving" and str(hx.rules.call("get_unit", "portal").stage) == "idle" and str(hx.rules.call("get_unit", "rodriguez").stage) == "waiting_signal", "deshacer: Ctrl+Z deshace la última orden (Portal deja de marchar) y no toca a Rodríguez (%s → %s)" % [portal_before, str(hx.rules.call("get_unit", "portal").stage)])
	var sig: Dictionary = hx.orders.issue("", "give_signal")
	if bool(sig.get("ok", false)):
		var rod_after := str(hx.rules.call("get_unit", "rodriguez").stage)
		await _key(KEY_Z, true)
		suite.check(str(hx.rules.call("get_unit", "rodriguez").stage) == rod_after and hx._motive_text == hx.tx("actions.undo_signal"), "deshacer: tras la señal, Ctrl+Z no deshace la orden de otra agrupación y dice por qué («%s»)" % hx._motive_text)
		var hold: Dictionary = hx.orders.issue("rodriguez", "hold")
		if bool(hold.get("ok", false)):
			await _key(KEY_Z, true)
			suite.check(str(hx.rules.call("get_unit", "rodriguez").stage) != "idle" and hx._motive_text == hx.tx("actions.undo_lost"), "deshacer: una orden que pisó otra etapa no se deshace a «esperando órdenes» («%s»)" % hx._motive_text)
		else:
			suite.extra["deshacer_sostener"] = "las reglas no aceptaron «sostener»: %s" % str(hold.get("reason", ""))
	else:
		suite.extra["deshacer_senal"] = "no se pudo dar la señal: %s" % str(sig.get("reason", ""))
	await _leave_level()


## D-11: en una marcha sin novedades (×1, sin alerta, sin ventana, sin una orden pedida y con alguien en marcha) se sugiere ×2 con un aviso discreto; cualquier
## novedad, una orden pedida o cambiar la velocidad lo apaga. La velocidad nunca cambia sola.
func _test_suggest_x2() -> void:
	if not suite.check(await _start_level({"skip_intro": true, "seed": 7}), "sugerir ×2: el nivel arranca"):
		return
	hx.orders.issue("reconocedores", "recon", Vector2(450.0, 325.0))
	hx.qa_step(2.0)
	# lo que sigue corre sin cuadros de por medio: el reloj del controlador no se mete
	hx.mode = "play"
	hx.paused = false
	hx.speed = 1.0
	hx.guide = {"action": "hold", "text": "Esperá.", "button_visible": false}
	hx.hud._alert_data = {}
	hx._last_alarm_real = -999.0
	hx._suggest_toast_real = -999.0
	hx._calm_s = 0.0
	hx._calm_tick(9.0)
	suite.check(bool(hx._suggest_x2) and str(hx._toast_cur.get("text", "")) == hx.tx("time.suggest_x2") and hx.speed == 1.0, "sugerir ×2: en una marcha sin novedades aparece la sugerencia, como aviso de pie y sin cambiar la velocidad (%s)" % str(hx._toast_cur.get("text", "")))
	hx.guide = {"action": "position", "text": "Mandá a Rodríguez a su puesto.", "button_visible": true, "enabled": true}
	hx._calm_tick(0.1)
	suite.check(not bool(hx._suggest_x2), "sugerir ×2: si el siguiente paso pide una orden, no se sugiere")
	hx.guide = {"action": "hold", "text": "Esperá.", "button_visible": false}
	hx._calm_tick(9.0)
	hx._last_alarm_real = hx._clock_real()
	hx._calm_tick(0.1)
	suite.check(not bool(hx._suggest_x2), "sugerir ×2: una novedad importante apaga la sugerencia")
	hx._last_alarm_real = -999.0
	hx._calm_tick(9.0)
	hx.set_speed_index(1)
	hx._calm_tick(0.1)
	suite.check(not bool(hx._suggest_x2) and hx.speed == 2.0, "sugerir ×2: al acelerar la sugerencia se va")
	hx.paused = true
	await _leave_level()


# ---------------------------------------------------------------------------------------------------------------------
# Primera decisión en menos de 60 s de juego (TR-117)

func _test_first_decision() -> void:
	# quien no sabe qué apretar: a los 12 s sin ninguna orden un aviso dice cómo arranca el reloj (onboarding.first_order_hint_s); con una orden dada no aparece
	if not suite.check(await _start_level(), "primera decisión: el nivel arranca para probar el aviso de la espera"):
		return
	hx._process(5.0)
	suite.check(str(hx.qa_state().toast) == "", "primera decisión: a los 5 s sin orden todavía no avisa nada («%s»)" % str(hx.qa_state().toast))
	hx._process(8.0)
	suite.check(str(hx.qa_state().toast).find("El reloj arranca con tu primera orden") >= 0, "primera decisión: a los 12 s sin orden el aviso dice cómo arranca el reloj («%s»)" % str(hx.qa_state().toast))
	await _leave_level()
	if not suite.check(await _start_level(), "primera decisión: el nivel arranca para probar que con una orden no avisa"):
		return
	hx.hud.next_btn.pressed.emit()
	hx._process(20.0)
	suite.check(str(hx.qa_state().toast).find("El reloj arranca") < 0, "primera decisión: con la primera orden dada el aviso de la espera no sale («%s»)" % str(hx.qa_state().toast))
	await _leave_level()
	if not suite.check(await _start_level(), "primera decisión: el nivel arranca"):
		return
	hx.hud.next_btn.pressed.emit()
	await _frames(2)
	var q: Dictionary = hx.qa_state()
	var first := float(hx.rules.state.stats.pacing.first_decision_s)
	suite.check(int(q.orders) == 1 and first >= 0.0 and first < 60.0, "primera decisión: la primera orden sale al apretar el botón del siguiente paso, a los %.1f s de juego (< 60 s)" % first)
	suite.check(float(q.first_order_s) >= 0.0 and float(q.first_order_s) < float(ui_json.get("hud_limits", {}).get("first_decision_max_s", 60.0)), "primera decisión: el controlador la registra (first_order_s = %.1f)" % float(q.first_order_s))
	suite.check(not bool(q.paused), "primera decisión: el reloj arranca con esa orden")
	await _leave_level()


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
		# D-08: plegada, la línea de tiempo muestra la primera fecha y la que contrasta tu partida con la realidad; el resto se despliega con un botón
		suite.check(all_text.find("Medalla") >= 0 and all_text.find("3 de marzo") >= 0 and all_text.find("9 al 16 de marzo") >= 0 and all_text.find("6 de julio") < 0, "ciclo: el parte de victoria trae la medalla y la línea de tiempo plegada (primera fecha y «9 al 16 de marzo»)")
		suite.check(all_text.find("En la realidad") >= 0 and all_text.find("En tu partida") >= 0 and all_text.find("26 horas") >= 0, "ciclo: el parte contrasta «en la realidad» con «en tu partida» y aclara el tiempo comprimido")
		var next_b := game.find_child("HxNext", true, false) as Button
		suite.check(next_b != null and next_b == hx.dialogs.primary and next_b.text.find("Sostener el norte") >= 0 and _find_button("Jugar de nuevo", game) != null, "ciclo: el botón principal del parte de victoria es seguir al capítulo III («%s») y también ofrece «Jugar de nuevo»" % (next_b.text if next_b != null else "—"))
		var tl := game.find_child("HxTimelineToggle", true, false) as Button
		suite.check(tl != null, "ciclo: el parte de victoria ofrece desplegar la línea de tiempo")
		if tl != null:
			tl.pressed.emit()
			await _frames(2)
			var open_text := " ".join(PackedStringArray(_visible_texts()))
			suite.check(open_text.find("6 de julio") >= 0 and open_text.find("Güemes lo recibe") >= 0 and open_text.find("expulsión definitiva") < 0, "ciclo: desplegada, la línea de tiempo trae todas las fechas; Güemes recibe el parte y no se habla de expulsión definitiva")
			(game.find_child("HxTimelineToggle", true, false) as Button).pressed.emit()
			await _frames(2)
	else:
		suite.check(_find_button("Reintentar", game) != null, "ciclo: el parte de derrota ofrece reintentar")
	var retry_button := game.find_child("HxRetry", true, false) as Button
	var vp := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	suite.check(retry_button != null and _inside(Kit.rect_of(retry_button), vp) and not hx.dialogs.scroll_used, "ciclo: el botón principal del parte está a la vista, sin scroll (%s)" % str(Kit.rect_of(retry_button) if retry_button != null else "no existe"))
	suite.check(_inside(Kit.rect_of(hx.dialogs.panel), vp), "ciclo: el parte entra entero en el cuadro (%s en %s)" % [str(Kit.rect_of(hx.dialogs.panel)), str(vp.size)])
	await _navigate_report("victoria" if victory else "derrota")  # H-R1-2
	retry_button = game.find_child("HxRetry", true, false) as Button
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
	await _navigate_report("derrota por pasividad")  # H-R1-2
	retry2 = game.find_child("HxRetry", true, false) as Button
	var defeat_text := " ".join(PackedStringArray(_visible_texts()))
	suite.check(defeat_text.find("campaña") < 0 and _jargon_hits(defeat_text).is_empty(), "ciclo: la derrota no ofrece ir al Norte y no usa jerga (%s)" % str(_jargon_hits(defeat_text)))
	var seed_before := int(hx.qa_state().seed)
	retry2.pressed.emit()
	await _frames(2)
	suite.check(int(hx.qa_state().seed) == seed_before and str(hx.qa_state().mode) == "play" and float(hx.qa_state().elapsed) == 0.0, "ciclo: reintentar tras la derrota mantiene el mismo mundo y vuelve a 0:00")
	suite.check(float(hx.retry_ms) >= 0.0 and float(hx.retry_ms) <= 3000.0, "ciclo: reintento medido por el controlador ≤ 3 s (%d ms)" % int(hx.retry_ms))
	await _leave_level()


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
	await _leave_level()
	if not suite.check(await _start_level(), "experto y pasivo: el nivel vuelve a arrancar"):
		return
	hx.qa_step(500.0)
	var rep: Dictionary = hx.rules.campaign_report()
	suite.check(str(hx.qa_state().status) == "defeat" and str(rep.cause_id) == "amanecio", "pasivo: el que no ordena nada pierde por «amanecio» por la escena real (%s)" % str(rep.get("cause_id", "")))
	suite.extra["pasivo"] = {"estado": str(hx.qa_state().status), "causa": str(rep.get("cause_id", "")), "segundos": snappedf(float(hx.qa_state().elapsed), 0.1)}
	await _leave_level()


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
	hx.set_motive("Una de las paradas queda fuera del mapa.", true)  # un rechazo viejo no debe quedar en pantalla después de recuperar una partida (B-046 b)
	await _key(KEY_F9)
	suite.check(is_equal_approx(float(hx.qa_state().elapsed), elapsed_saved), "guardado: F9 recupera la partida guardada (%.1f s)" % float(hx.qa_state().elapsed))
	suite.check(str(hx.qa_state().motive) == "", "guardado: F9 no deja en pantalla el motivo de una orden rechazada antes («%s»)" % str(hx.qa_state().motive))
	suite.check(str(hx.qa_state().toast).find("recuperada") >= 0, "guardado: F9 avisa que la partida se recuperó («%s»)" % str(hx.qa_state().toast))
	# «Continuar» desde el menú abre Humahuaca con lo guardado
	await _leave_level()
	game._load_game("humahuaca")
	await _frames(4)
	hx = game.hx
	suite.check(game.mode == "hx" and is_instance_valid(hx) and is_equal_approx(float(hx.qa_state().elapsed), elapsed_saved), "guardado: «Continuar» abre el nivel con la partida guardada (%.1f s)" % float(hx.qa_state().elapsed))
	suite.check(str(hx.qa_state().mode) == "play" and bool(hx.qa_state().paused), "guardado: al continuar se juega, en pausa, sin repetir el briefing")
	# un guardado dañado termina en un mensaje claro y en el briefing, sin error ni cuelgue
	await _leave_level()
	var f := FileAccess.open(str(game._save_path("humahuaca")), FileAccess.WRITE)
	f.store_string("esto no es json {")
	f.close()
	game._load_game("humahuaca")
	await _frames(4)
	hx = game.hx
	suite.check(game.mode == "hx" and is_instance_valid(hx) and str(hx.qa_state().dialog) == "briefing", "guardado: un guardado dañado termina en el briefing, no en un error")
	suite.check(hx.hud.warn_l.text.find("guardada") >= 0, "guardado: y dice por qué («%s»)" % hx.hud.warn_l.text)
	# un guardado de otro escenario se rechaza con motivo
	await _leave_level()
	var g2 := FileAccess.open(str(game._save_path("humahuaca")), FileAccess.WRITE)
	g2.store_string(JSON.stringify({"scenario": "justine", "schema_version": 1}))
	g2.close()
	game._load_game("humahuaca")
	await _frames(4)
	hx = game.hx
	suite.check(str(hx.qa_state().dialog) == "briefing" and hx.hud.warn_l.text.find("Empezás de nuevo") >= 0, "guardado: un guardado de otro escenario se rechaza y empieza de nuevo («%s»)" % hx.hud.warn_l.text)
	suite.check(hx.hud.warn_l.text.find("otro escenario") >= 0 and hx.hud.warn_l.text.find(".)") < 0 and hx.hud.warn_l.text.find("..") < 0 and hx.hud.warn_l.text.find("(") < 0, "guardado: el aviso dice el motivo sin punto doble ni paréntesis (B-046 a): «%s»" % hx.hud.warn_l.text)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(str(game._save_path("humahuaca"))))
	game.settings.last_save = last_before
	await _leave_level()


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
	await _leave_level()


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
		await _leave_level()
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
