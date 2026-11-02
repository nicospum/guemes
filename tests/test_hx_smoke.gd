extends SceneTree
## Prueba de humo del nivel «humahuaca» sobre la escena real (CONTRATO 5.1 y 7). Dueño: compuertas y documentos.
## Con ventana nula: godot --headless --path . --script tests/test_hx_smoke.gd [-- --ronda=r1]. Piso: 25 comprobaciones. Tiempo objetivo: < 30 s (falla a los 90 s).
##
## Qué cubre en R0, con la cáscara del controlador (stubs/stub_ui.gd, copiada en ui/humahuaca_ui.gd):
##   - los 15 chequeos de la prueba de concepto (PoC-01 a PoC-15) sobre el menú real de tres botones y el ciclo menú → nivel → Esc → menú → Justina;
##   - los ganchos H1 a H9 de main.gd por su comportamiento (botones, «Continuar», Historia, volver al menú, salida al Norte, entrada antes que main);
##   - la ida y vuelta ×3 (Humahuaca → menú → Justina → menú) con igualdad del estado global que el nivel toca (camera.far y fov, escala 3D y MSAA
##     del viewport, ambiente del audio_manager, settings.last_save, content_scale, cámara actual) y cero nodos huérfanos;
##   - campaign.json, save_justine.json y save_norte.json no cambian ni un byte mientras corre el nivel;
##   - el chequeo «el último elemento del menú ≤ alto del viewport» (ui_qa lo corre en las tres resoluciones);
##   - la forma de qa_state() contra docs/humahuaca/forma/qa_state.json y el propio comparador de formas;
##   - los nombres de la API del contrato de cada capa que ya existe (la cáscara de la interfaz hoy).
## Desde R1.0 existen los cuatro stubs, así que corren las cinco corridas degradadas (una capa reemplazada por su stub, de a una, con la capa efectiva
## comprobada contra qa_state().layers), la salida de cada stub contra los ejemplos de forma y la API de cada stub. Lo que todavía NO se puede evaluar
## porque lo escribe cada pista en R1 (las cuatro clases reales) queda en `pending` del informe y pasa a ser falla desde la ronda r1 («no evaluable =
## falla»). Mientras no exista ninguna clase real, forzar un stub no cambia nada: el informe lo dice en `degradadas.clases_reales_presentes`.
## Interfaz que esta prueba espera de start(main, opts): opts.skip_intro y opts.force_stub, con los ids de capa «terrain», «rules», «progress» y «view»
## (la capa «ui» se reemplaza por la cáscara instanciándola directamente); y de qa_state() del controlador real: la clave `layers` (BACKLOG B-020).
##
## Borra archivos de perfil: se niega a correr sin APPDATA aislado (export APPDATA="$TEMP/ap_iso_<pista>").

const Fx = preload("res://tests/hx_fixtures.gd")

const QA_CAMPAIGN := "{\"version\":1,\"world_seed\":0,\"diary\":[],\"attempts\":1,\"wins\":1,\"defeats_in_row\":0,\"defeats_total\":0,\"best_medal\":\"bronce\",\"justina_won\":true,\"north_unlocked\":true,\"tutorial_seen\":true,\"last_cause\":\"\",\"worlds\":1,\"checkpoint\":{},\"best_score\":0,\"objectives_done\":[]}"
const SMOKE_FLOOR := 25
const HX_HEIGHT_PATH := "res://data/humahuaca_height.json"

var suite := Fx.new()
var game: Node
var ui_is_shell := true

func _initialize() -> void:
	suite.begin("hx_smoke", OS.get_cmdline_user_args())
	if not _require_isolated_profile():
		return
	Fx.clean_profile()
	call_deferred("_run")

## Las pruebas que borran archivos de perfil exigen APPDATA aislado: con el perfil real borrarían el campaign.json del usuario.
func _require_isolated_profile() -> bool:
	if Fx.profile_isolated():
		return true
	suite.check(false, "perfil NO aislado (%s): exportá APPDATA=\"$TEMP/ap_iso_<pista>\" antes de correr; esta prueba borra campaign.json y otros archivos de perfil" % OS.get_user_data_dir())
	print(JSON.stringify(suite.report()))
	quit(2)
	return false

# ---------------------------------------------------------------------------------------------------------------------
# Ayudas

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame

func _find_button(part: String) -> Button:
	for b in game.find_children("*", "Button", true, false):
		if str(b.text).find(part) >= 0:
			return b
	return null

func _all_text(node_class: String) -> String:
	var text := ""
	for c in game.find_children("*", node_class, true, false):
		text += str(c.text) + "\n"
	return text

func _key(code: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	root.push_input(ev)

func _hx_children() -> int:
	var n := 0
	for c in game.get_children():
		var s: Script = c.get_script()
		if s != null and str(s.resource_path).find("humahuaca") >= 0:
			n += 1
	return n

func _audio_environment() -> String:
	if not is_instance_valid(game.audio_manager):
		return "(sin audio_manager)"
	return str(game.audio_manager.get("_scenario"))

## El estado global que el nivel puede tocar y tiene que restaurar (CONTRATO 3.5 y 5.1).
func _snapshot() -> Dictionary:
	var vp: Viewport = game.get_viewport()
	return {"far": game.camera.far, "fov": game.camera.fov, "scale3d": vp.scaling_3d_scale, "msaa": vp.msaa_3d, "last_save": str(game.settings.last_save),
		"content_scale": game.get_window().content_scale_factor, "cam_current": game.camera.current, "mode": str(game.mode), "audio_env": _audio_environment(),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), "nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))}

func _to_menu() -> void:
	game._menu()
	await _frames(4)

func _start_level_by_button() -> bool:
	var button := _find_button("HUMAHUACA")
	if button == null:
		return false
	button.pressed.emit()
	await _frames(4)
	return game.mode == "hx" and is_instance_valid(game.hx)

# ---------------------------------------------------------------------------------------------------------------------

func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	if not suite.check(scene != null, "la escena principal carga"):
		suite.finish(self)
		return
	game = scene.instantiate()
	root.add_child(game)
	await _frames(4)
	game.jev.force_local = true  # el menú no consulta a Jev, pero nada de esta prueba debe tocar la red
	game.settings.auto_pause = false
	if is_instance_valid(game.audio_manager):
		game.audio_manager.set_muted(true)
	ui_is_shell = FileAccess.get_sha256(Fx.REAL_PATHS.ui) == FileAccess.get_sha256(Fx.STUB_PATHS.ui)
	suite.extra["ui"] = "cascara" if ui_is_shell else "real"
	await _test_menu_and_buttons()
	await _test_menu_fits_viewport()
	await _test_poc_flow()
	await _test_justina_after_return()
	_test_gamerules_unknown_name()
	await _test_roundtrip_x3()
	await _test_continue_routes()
	await _test_history_dialog()
	await _test_return_menu_hook()
	await _test_exit_to_norte()
	await _test_input_order()
	await _test_camera_owner()
	await _test_campaign_json_unchanged()
	await _test_shapes()
	_test_api_conformance()
	_test_forced_layer_comparator()
	await _test_degraded_runs()
	## El objetivo del contrato es < 30 s (hoy ≈ 15 s). Falla recién a los 90 s: con cuatro pistas corriendo su compuerta a la vez la PC va más lenta.
	suite.check(suite.elapsed_ms() < 90000, "test_hx_smoke corre en poco tiempo (objetivo < 30 s, CONTRATO 5.1; falla a los 90 s): %d ms" % suite.elapsed_ms())
	suite.require_floor(SMOKE_FLOOR)
	if is_instance_valid(game):
		game.queue_free()
	await process_frame
	suite.finish(self)

# ---------------------------------------------------------------------------------------------------------------------
# H1, H2 y PoC-01 a PoC-03: el menú de tres botones

func _test_menu_and_buttons() -> void:
	suite.check(game.mode == "menu" and game.hx == null, "PoC-01 la escena arranca en el menú, sin controlador del nivel (H1: existe «hx» y vale null)")
	var bj := _find_button("EL RÍO OFRECE")
	var bn := _find_button("SOSTENER EL NORTE")
	suite.check(bj != null and bn != null, "PoC-02 los dos botones originales siguen en el menú")
	var bh := _find_button("HUMAHUACA")
	suite.check(bh != null, "PoC-03 el menú ofrece el tercer escenario")
	if bj == null or bh == null or bn == null:
		return
	suite.check(bj != bh and bh != bn and bj != bn, "H2 los tres botones son distintos")
	suite.check(bj.global_position.y < bh.global_position.y and bh.global_position.y < bn.global_position.y, "H2 orden I, II, III de arriba hacia abajo")
	suite.check(str(bj.text).begins_with("I ") and str(bh.text).begins_with("II  ·   HUMAHUACA: EL DEPÓSITO DE LA RETAGUARDIA") and str(bn.text).begins_with("III  ·   SOSTENER EL NORTE"), "H2 los títulos son I, II (Humahuaca: el depósito de la retaguardia) y III (Sostener el norte)")
	suite.check(not bh.disabled, "D1c Humahuaca está siempre habilitado, aunque la Justina no esté ganada")
	suite.check(str(bh.text).find("Recomendado tras la Justina") >= 0, "D1c la nota «Recomendado tras la Justina» se ve mientras la Justina no está ganada")
	suite.check(bn.disabled and str(bn.text).find("Ganá la Justina para abrirlo") >= 0, "D1a el Norte conserva su candado y su subtítulo bloqueado")
	for forbidden in ["EL RÍO OFRECE", "SOSTENER EL NORTE", "Ganá la Justina para abrirlo"]:
		suite.check(str(bh.text).find(forbidden) < 0, "H2 el botón de Humahuaca no contiene «%s» (las pruebas buscan los botones por subcadena)" % forbidden)
	suite.check(str(bh.tooltip_text) != "", "H2 el botón de Humahuaca tiene su ayuda emergente, como los otros dos")
	var rich := _all_text("RichTextLabel")
	suite.check(rich.find("Tres momentos de una historia") >= 0 and rich.find("Dos momentos") < 0, "H2 el menú dice «Tres momentos de una historia»")
	# con la Justina ganada: sin la nota, y el Norte abierto con su subtítulo nuevo
	game.progress.justina_ganada = true
	await _to_menu()
	bh = _find_button("HUMAHUACA")
	bn = _find_button("SOSTENER EL NORTE")
	suite.check(bh != null and bn != null and not bh.disabled and str(bh.text).find("Recomendado tras la Justina") < 0, "C04 con la Justina ganada Humahuaca queda sin la nota")
	suite.check(bn != null and not bn.disabled and str(bn.text).find("La campaña entera, 1816–1817, vista desde Salta") >= 0, "C04 con la Justina ganada el Norte (III) se abre con «La campaña entera, 1816–1817, vista desde Salta»")
	game.progress.justina_ganada = false
	await _to_menu()

func _test_menu_fits_viewport() -> void:
	## El alto de referencia es el de diseño del proyecto (900): con el modo «expand» cualquier ventana (1024×640, 1280×720, 1920×1080, 2560×1440)
	## se reparte en coordenadas lógicas de 900 de alto; el viewport de la ventana nula de esta prueba mide otra cosa y no sirve de tope.
	var viewport_size := root.get_visible_rect().size
	var design_height := float(ProjectSettings.get_setting("display/window/size/viewport_height", 900))
	var lowest := 0.0
	var lowest_text := ""
	for c in game.find_children("*", "Control", true, false):
		if c.is_visible_in_tree() and (c is Button or c is Label or c is RichTextLabel):
			var r: Rect2 = c.get_global_rect()
			if r.position.x < 700.0 and r.end.y > lowest:
				lowest = r.end.y
				lowest_text = str(c.get("text")).substr(0, 30).replace("\n", " / ")
	suite.check(lowest <= minf(viewport_size.y, design_height), "4.1 el último elemento del menú (%s) termina en y = %.0f y el alto lógico de diseño es %.0f (viewport de la prueba: %.0f)" % [lowest_text, lowest, design_height, viewport_size.y])
	suite.extra["menu_ultimo_y"] = snappedf(lowest, 1.0)
	suite.extra["menu_viewport"] = [viewport_size.x, viewport_size.y]

# ---------------------------------------------------------------------------------------------------------------------
# H3, H4 y PoC-04 a PoC-12: arrancar el nivel por el botón, correr el reloj y volver con Esc

func _json_height_dm_at(x: float, z: float) -> float:
	var height: Variant = Fx.read_json(HX_HEIGHT_PATH)
	if not (height is Dictionary):
		return NAN
	var win: Dictionary = height.window
	var i := clampi(roundi(x / float(win.cell_m)), 0, int(win.nx) - 1)
	var j := clampi(roundi(z / float(win.cell_m)), 0, int(win.nz) - 1)
	return float(win.h[j * int(win.nx) + i])

func _test_poc_flow() -> void:
	var far_before: float = game.camera.far
	var fov_before: float = game.camera.fov
	var started := await _start_level_by_button()
	suite.check(started, "PoC-04 el botón arranca el nivel: modo hx y controlador vivo")
	if not started:
		return
	suite.check(game.world == null, "PoC-05 el mundo 3D del menú se liberó")
	suite.check(str(game.rules.state.scenario) == "justine", "PoC-06 main.rules no se tocó (sigue siendo el de la Justina del menú)")
	var qa: Dictionary = game.hx.qa_state()
	var rules_obj: Variant = game.hx.get("rules")
	if rules_obj != null:
		suite.check(str(rules_obj.state.scenario) == "humahuaca", "PoC-07 las reglas propias del nivel dicen humahuaca")
	else:
		suite.check(str(qa.get("phase", "")) == "briefing", "PoC-07 (cáscara) el controlador arranca en el «briefing» y no en una fase de la Justina")
	var view_obj: Variant = game.hx.get("view")
	if view_obj != null:
		suite.check(is_instance_valid(view_obj) and view_obj.get_child_count() >= 3, "PoC-08 la vista propia construyó malla, luz y cámara")
	else:
		var found_status := false
		for label in game.ui.find_children("*", "Label", true, false):
			if str(label.text).find("Humahuaca") >= 0:
				found_status = true
		suite.check(found_status, "PoC-08 (cáscara) el controlador montó su propia línea de estado en la interfaz de main")
	suite.check(game.camera.far >= 9000.0 and is_equal_approx(game.camera.fov, 46.0), "3.5 mientras dura el nivel camera.far ≥ 9000 y fov = 46 (far %.0f, fov %.0f)" % [game.camera.far, game.camera.fov])
	# PoC-09: el reloj propio avanza con el _process del controlador (con la cáscara hay que reanudar con Espacio)
	var t0: float = float(game.hx.qa_state().elapsed)
	if bool(qa.get("paused", false)):
		_key(KEY_SPACE)
	await _frames(40)
	var t1: float = float(game.hx.qa_state().elapsed)
	suite.check(t1 > t0, "PoC-09 el reloj propio avanza con el _process del controlador (%.3f s → %.3f s)" % [t0, t1])
	if not bool(game.hx.qa_state().get("paused", true)):
		_key(KEY_SPACE)  # vuelve a pausar para no dejar correr el reloj durante el resto
		await _frames(2)
	var height_dm := _json_height_dm_at(150.0, 300.0)
	suite.check(height_dm > 80.0, "PoC-10 la altura de la ladera oeste (150, 300) en el relieve de datos es plausible: %.1f m sobre el cero local" % (height_dm / 10.0))
	# H4: arrancar dos veces no deja un controlador huérfano
	var first: Node = game.hx
	game._start_game("humahuaca")
	await _frames(3)
	suite.check(is_instance_valid(game.hx) and game.hx != first, "H4 arrancar el nivel dos veces crea un controlador nuevo")
	await _frames(2)
	suite.check(not is_instance_valid(first) or first.is_queued_for_deletion(), "H4 el controlador anterior se libera")
	suite.check(_hx_children() == 1, "H4 queda un solo controlador hijo de main (%d)" % _hx_children())
	_key(KEY_ESCAPE)
	await _frames(4)
	suite.check(game.mode == "menu" and game.hx == null, "PoC-11 Esc devuelve al menú y libera el controlador")
	suite.check(is_equal_approx(game.camera.far, far_before) and is_equal_approx(game.camera.fov, fov_before) and game.camera.current, "3.5 al volver camera.far y fov quedan como estaban (%.0f / %.0f) y la cámara de main es la actual" % [game.camera.far, game.camera.fov])
	suite.check(_find_button("EL RÍO OFRECE") != null and _find_button("HUMAHUACA") != null and _find_button("SOSTENER EL NORTE") != null, "PoC-12 el menú vuelve a mostrar los tres escenarios")

func _test_justina_after_return() -> void:
	var button := _find_button("EL RÍO OFRECE")
	if not suite.check(button != null, "PoC-13 hay botón para la Justina"):
		return
	button.pressed.emit()
	await _frames(4)
	suite.check(game.mode == "play" and str(game.rules.state.scenario) == "justine", "PoC-13 la Justina arranca después de volver del nivel")
	suite.check(is_instance_valid(game.world) and game.world.unit_nodes.size() >= 5, "PoC-14 la Justina vuelve a tener su mundo 3D con sus unidades")
	await _to_menu()

func _test_gamerules_unknown_name() -> void:
	var rules_script: Script = load("res://scripts/game_rules.gd")
	var rules: RefCounted = rules_script.new()
	suite.check(str(rules.call("new_game", "humahuaca", 1).scenario) == "justine", "PoC-15 GameRules.new_game(\"humahuaca\") sigue devolviendo scenario = justine: por eso main nunca le pasa ese nombre")

# ---------------------------------------------------------------------------------------------------------------------
# 3.5 y 5.1: ida y vuelta ×3 con igualdad de estado global y cero nodos huérfanos

func _test_roundtrip_x3() -> void:
	await _to_menu()
	var base := _snapshot()
	suite.check(int(base.orphans) == 0, "5.1 punto de partida: cero nodos huérfanos (%d)" % int(base.orphans))
	var after_level: Array = []
	var after_justina: Array = []
	for round_i in range(3):
		var started := await _start_level_by_button()
		suite.check(started, "ida y vuelta %d: Humahuaca arranca por su botón" % (round_i + 1))
		if started:
			game.hx.qa_step(2.0)
			await _frames(2)
		_key(KEY_ESCAPE)
		await _frames(5)
		suite.check(game.mode == "menu" and game.hx == null, "ida y vuelta %d: Esc devuelve al menú y libera el controlador" % (round_i + 1))
		after_level.append(_snapshot())
		_find_button("EL RÍO OFRECE").pressed.emit()
		await _frames(4)
		suite.check(game.mode == "play" and str(game.rules.state.scenario) == "justine", "ida y vuelta %d: la Justina arranca" % (round_i + 1))
		await _to_menu()
		await _frames(2)
		after_justina.append(_snapshot())
	var keys := ["far", "fov", "scale3d", "msaa", "last_save", "content_scale", "cam_current", "mode", "audio_env"]
	for k in keys:
		var same_level := true
		var same_justina := true
		for snap in after_level:
			same_level = same_level and str(snap[k]) == str(base[k])
		for snap in after_justina:
			same_justina = same_justina and str(snap[k]) == str(base[k])
		suite.check(same_level, "estado global «%s» igual tras salir del nivel, 3 veces (%s)" % [k, str(base[k])])
		suite.check(same_justina, "estado global «%s» igual tras el ciclo completo con la Justina, 3 veces (%s)" % [k, str(base[k])])
	var orphans_ok := true
	for snap in after_level + after_justina:
		orphans_ok = orphans_ok and int(snap.orphans) == 0
	suite.check(orphans_ok, "Performance.OBJECT_ORPHAN_NODE_COUNT = 0 después de cada vuelta")
	suite.check(int(after_justina[2].nodes) <= int(after_justina[1].nodes) + 2, "la cantidad de nodos no crece entre la 2.ª y la 3.ª vuelta (%d → %d)" % [int(after_justina[1].nodes), int(after_justina[2].nodes)])
	suite.extra["roundtrip_nodos"] = [int(base.nodes), int(after_justina[2].nodes)]
	var level_nodes: Array = []
	var justina_nodes: Array = []
	var max_orphans := int(base.orphans)
	for snap in after_level:
		level_nodes.append(int(snap.nodes))
		max_orphans = maxi(max_orphans, int(snap.orphans))
	for snap in after_justina:
		justina_nodes.append(int(snap.nodes))
		max_orphans = maxi(max_orphans, int(snap.orphans))
	suite.extra["roundtrip"] = {"vueltas": 3, "claves_de_estado_global": keys, "nodos_base": int(base.nodes), "nodos_tras_nivel": level_nodes, "nodos_tras_justina": justina_nodes, "huerfanos_max": max_orphans}

# ---------------------------------------------------------------------------------------------------------------------
# H5: «Continuar» abre el escenario guardado

func _write_user_file(name_: String, text: String) -> void:
	var f := FileAccess.open("user://" + name_, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()

func _test_continue_routes() -> void:
	await _to_menu()
	game.settings.last_save = "humahuaca"
	_write_user_file("save_humahuaca.json", "{}")
	game._menu()
	await _frames(3)
	var cont := _find_button("Continuar")
	suite.check(cont != null and not cont.disabled, "H5 con settings.last_save = humahuaca y una partida guardada, «Continuar» está habilitado")
	if cont != null and not cont.disabled:
		cont.pressed.emit()
		await _frames(4)
		suite.check(game.mode == "hx" and is_instance_valid(game.hx), "H5 «Continuar» abre Humahuaca y no la Justina")
		suite.check(game.hx.qa_state().has("phase"), "H5 el controlador abierto con «Continuar» responde qa_state() (si rechaza el guardado, termina en el briefing y no en un error)")
		_key(KEY_ESCAPE)
		await _frames(4)
	_find_button("EL RÍO OFRECE").pressed.emit()
	await _frames(4)
	game._save_game(false)
	await _frames(2)
	suite.check(FileAccess.file_exists(game._save_path("justine")), "H5 guardar en la Justina escribe save_justine.json")
	suite.check(str(game.settings.last_save) == "justine", "H5 guardar en la Justina fija settings.last_save = justine")
	await _to_menu()
	cont = _find_button("Continuar")
	suite.check(cont != null and not cont.disabled, "H5 con la Justina guardada, «Continuar» está habilitado")
	if cont != null and not cont.disabled:
		cont.pressed.emit()
		await _frames(4)
		suite.check(game.mode == "play" and str(game.rules.state.scenario) == "justine", "H5 «Continuar» abre la Justina y no Humahuaca")
	await _to_menu()
	game.settings.last_save = "norte"
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save_humahuaca.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save_justine.json"))
	await _to_menu()

# ---------------------------------------------------------------------------------------------------------------------
# H6, H9 y salida al Norte

func _test_history_dialog() -> void:
	game._history_dialog()
	await _frames(2)
	var hist := _all_text("RichTextLabel")
	var i_j := hist.find("LA TOMA DE LA JUSTINA")
	var i_h := hist.find("HUMAHUACA: EL DEPÓSITO DE LA RETAGUARDIA")
	var i_n := hist.find("SOSTENER EL NORTE")
	suite.check(i_j >= 0 and i_h > i_j and i_n > i_h, "H6 Historia muestra I (Justina), II (Humahuaca) y III (Norte) en ese orden (%d, %d, %d)" % [i_j, i_h, i_n])
	suite.check(hist.find("Manuel Eduardo Arias") >= 0, "H6 Historia cuenta el contexto de Humahuaca (scenarios.humahuaca de history.json)")
	game._close_modal()
	await _frames(2)

func _test_return_menu_hook() -> void:
	game._start_game("humahuaca")
	await _frames(3)
	suite.check(game.mode == "hx" and is_instance_valid(game.hx), "H9 --scenario=humahuaca y _start_game arrancan el nivel")
	game._return_menu()
	await _frames(3)
	suite.check(game.mode == "menu" and game.hx == null, "H9 _return_menu desde el nivel vuelve al menú y libera el controlador")
	game._stop_humahuaca()
	game._stop_humahuaca()
	suite.check(game.hx == null and game.camera.current, "H9 _stop_humahuaca es idempotente y deja la cámara de main como actual")

func _test_exit_to_norte() -> void:
	game._start_game("humahuaca")
	await _frames(3)
	game.hx.exited.emit("norte")
	await _frames(4)
	suite.check(game.mode == "play" and str(game.rules.state.scenario) == "norte" and game.hx == null, "H4 exited(\"norte\") arranca el Norte y libera el controlador")
	suite.check(_hx_children() == 0, "H4 el Norte no arrastra un controlador vivo")
	await _to_menu()

## El controlador es hijo de main y recibe la entrada antes que main (nota 2 de ADDENDA A-04): si marca el evento como manejado, main no hace _focus_hud.
func _test_input_order() -> void:
	var probe_script := GDScript.new()
	probe_script.source_code = "extends Node\nvar got := 0\nfunc _unhandled_input(event):\n\tif event is InputEventKey and event.pressed and event.keycode == KEY_TAB:\n\t\tgot += 1\n\t\tget_viewport().set_input_as_handled()\n"
	suite.check(probe_script.reload() == OK, "3.5 el nodo de prueba de entrada compila")
	if not await _start_level_by_button():
		suite.check(false, "3.5 el nivel arranca para probar el orden de la entrada")
		return
	var probe := Node.new()
	probe.set_script(probe_script)
	game.add_child(probe)
	var focus_button := Button.new()
	focus_button.text = "foco"
	focus_button.focus_mode = Control.FOCUS_ALL
	game.ui.add_child(focus_button)
	await _frames(2)
	suite.check(not focus_button.has_focus(), "3.5 antes de Tab el botón de prueba no tiene foco")
	_key(KEY_TAB)
	await _frames(3)
	suite.check(int(probe.got) == 1 and not focus_button.has_focus(), "3.5 un hijo de main recibe Tab antes que main y, si lo marca como manejado, main no ejecuta _focus_hud")
	probe.queue_free()
	await _frames(2)
	_key(KEY_TAB)
	await _frames(3)
	suite.check(focus_button.has_focus(), "3.5 sin el hijo, main sí atiende Tab con _focus_hud (control de la prueba)")
	focus_button.queue_free()
	await _to_menu()

## hook-10 (H-R1-1): mientras corre el nivel, main.gd no ubica la cámara. La ubica el controlador al final de su `_process`; si main la pisaba antes con la pose de la Justina (`_apply_camera`),
## el `_process` de la vista y el `update_state` del controlador medían dos cámaras distintas por cuadro y el cuadro medio de `media` pasaba de 1,3 a 3,8 ms o más.
func _test_camera_owner() -> void:
	if not await _start_level_by_button():
		suite.check(false, "4.1 el nivel arranca para probar quién ubica la cámara")
		return
	await _frames(3)
	var sentinel := Vector3(123.0, 456.0, 789.0)
	game.camera.position = sentinel
	game._process(0.016)
	suite.check(game.camera.position.is_equal_approx(sentinel), "4.1 hook-10: main.gd no mueve la cámara mientras corre el nivel (la ubica el controlador)")
	if not ui_is_shell:
		await _frames(2)
		suite.check(not game.camera.position.is_equal_approx(sentinel), "4.1 el controlador sí ubica la cámara en su propio cuadro (control de la prueba)")
	await _to_menu()
	game.camera.position = sentinel
	game._process(0.016)
	suite.check(not game.camera.position.is_equal_approx(sentinel), "4.1 fuera del nivel main.gd sigue ubicando su cámara (control de la prueba)")

# ---------------------------------------------------------------------------------------------------------------------
# 3.3: campaign.json, save_justine.json y save_norte.json no cambian ni un byte

func _test_campaign_json_unchanged() -> void:
	var files := {"campaign.json": QA_CAMPAIGN, "save_justine.json": "{\"version\":0,\"nota\":\"prueba humo\"}", "save_norte.json": "{\"version\":0,\"nota\":\"prueba humo\"}"}
	var before := {}
	for f in files:
		_write_user_file(f, files[f])
		before[f] = FileAccess.get_sha256("user://" + f)
	if await _start_level_by_button():
		game.hx.qa_step(30.0)
		await _frames(10)
		game.hx.qa_set_camera(Vector2(300, 345), 240.0, 45.0, 10.0)
		await _frames(2)
		_key(KEY_ESCAPE)
		await _frames(4)
	else:
		suite.check(false, "3.3 el nivel arranca para probar que no toca los archivos de la Justina ni del Norte")
	for f in files:
		suite.check(FileAccess.get_sha256("user://" + f) == before[f], "3.3 %s no cambia ni un byte mientras corre el nivel" % f)
	suite.check(game.mode == "menu", "3.3 el nivel termina en el menú")
	for f in files:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + f))

# ---------------------------------------------------------------------------------------------------------------------
# 3.6: formas

func _test_shapes() -> void:
	# el comparador de formas ve lo que tiene que ver
	var example := {"a": 1.0, "b": {"c": "x", "d": [{"e": true}]}, "f": [1.0, 2.0], "g": {"h": 1.0}}
	suite.check(Fx.shape_diff(example, example).is_empty(), "3.6 una salida idéntica al ejemplo no tiene diferencias")
	suite.check(not Fx.shape_diff(example, {"a": 1.0, "b": {"c": "x", "d": [{"e": true}]}, "f": [1.0]}).is_empty(), "3.6 el comparador ve una clave que falta")
	suite.check(not Fx.shape_diff(example, {"a": "uno", "b": {"c": "x", "d": []}, "f": [], "g": {"h": 1.0}}).is_empty(), "3.6 el comparador ve un cambio de tipo (número → texto)")
	suite.check(Fx.shape_diff(example, {"a": 7, "b": {"c": "y", "d": [{"e": false}]}, "f": [], "g": {"h": 2}, "extra": 1}).is_empty(), "3.6 un entero vale como número, un arreglo vacío no se compara y las claves de más no molestan")
	suite.check(not Fx.shape_diff(example, {"a": 1.0, "b": {"c": "x", "d": [{"e": "no es bool"}]}, "f": [1.0], "g": {"h": 1.0}}).is_empty(), "3.6 los arreglos se comparan por su primer elemento")
	suite.check(Fx.shape_diff(example, {"a": 1.0, "b": {"c": "x", "d": []}, "f": [], "g": {}}, ["g"]).is_empty() and Fx.shape_diff(example, {"a": 1.0, "b": {"c": "x", "d": []}, "f": []}, ["g"]).is_empty(), "3.6 una ruta opcional puede venir vacía o faltar")
	suite.check(not Fx.shape_diff(example, {"a": 1.0, "b": {"c": "x", "d": []}, "f": [], "g": {"h": "texto"}}, ["g"]).is_empty(), "3.6 una ruta opcional que viene con contenido se compara igual (g.h cambió de número a texto)")
	suite.check(Fx.shape_diff({"x": null}, {"x": "lo que sea"}).is_empty(), "3.6 un null en el ejemplo significa cualquier valor")
	# la salida de la cáscara contra el ejemplo de qa_state
	var forma := Fx.load_forma("qa_state")
	if not suite.check(not forma.is_empty(), "3.6 el ejemplo qa_state.json se puede leer"):
		return
	if await _start_level_by_button():
		var qa: Dictionary = game.hx.qa_state()
		var diffs := Fx.shape_diff(forma.example, qa, forma.optional)
		suite.check(diffs.is_empty(), "3.6 qa_state() del controlador (%s) tiene la forma del ejemplo%s" % ["cáscara" if ui_is_shell else "real", "" if diffs.is_empty() else ": " + str(diffs)])
		suite.check(JSON.stringify(qa) != "", "3.5 qa_state() es serializable a JSON")
		suite.check(int(qa.get("visible_controls", 99)) <= 5 and int(qa.get("text_chars", 9999)) <= 400, "3.5 el primer cuadro respeta ≤ 5 controles y ≤ 400 caracteres (%s controles, %s caracteres)" % [str(qa.get("visible_controls")), str(qa.get("text_chars"))])
		if not ui_is_shell:
			# las claves que leen las herramientas del QA (tools/hx_agent_play.gd y tools/hx_qa_tour.gd) y que el ejemplo de forma no pide a la cáscara: si la interfaz las renombra o les
			# cambia el tipo, falla la compuerta rápida de quien las toca y no recién la completa
			var bad_keys: Array = []
			for k in ["mode", "dialog", "status"]:
				if typeof(qa.get(k, null)) != TYPE_STRING:
					bad_keys.append(k)
			for k in ["attempt", "orders", "first_order_s", "visible_buttons", "text_chars_juego"]:
				if not (typeof(qa.get(k, null)) in [TYPE_INT, TYPE_FLOAT]):
					bad_keys.append(k)
			suite.check(bad_keys.is_empty(), "3.5 qa_state() del controlador real trae, con su tipo, las claves que leen el arnés del agente y el recorrido de QA (mode, dialog, status, attempt, orders, first_order_s, visible_buttons, text_chars_juego)%s" % ["" if bad_keys.is_empty() else ": fallan " + str(bad_keys)])
		game.hx.qa_set_time(100.0)
		game.hx.qa_step(5.0)
		suite.check(is_equal_approx(float(game.hx.qa_state().elapsed), 105.0), "3.5 qa_set_time y qa_step avanzan el reloj del juego (100 s + 5 s)")
		game.hx.qa_set_camera(Vector2(300, 345), 240.0, 45.0, 10.0)
		suite.check(is_equal_approx(float(game.hx.qa_state().camera.dist), 240.0), "3.5 qa_set_camera fija la distancia de la cámara")
		game.hx.benchmark_prepare()
		_key(KEY_ESCAPE)
		await _frames(4)
	# las otras cuatro formas contra los stubs de las reglas (los escribe reglas_historia en R1.0)
	var rules := Fx.rules_stub()
	if rules == null:
		suite.pend("formas-reglas", "stubs/stub_rules.gd todavía no existe: hud_state, render_state, campaign_report y plan_route no se comparan contra su ejemplo", "r1")
	else:
		for pair in [["hud_state", "hud_state", []], ["render_state", "render_state", []], ["campaign_report", "campaign_report", []], ["plan_route", "plan_route", ["rodriguez", Vector2(300, 350)]]]:
			var shape := Fx.load_forma(pair[0])
			if not suite.check(rules.has_method(pair[1]), "3.6 el stub de reglas tiene %s()" % pair[1]):
				continue
			var out: Variant = rules.callv(pair[1], pair[2])
			var shape_diffs := Fx.shape_diff(shape.example, out, shape.optional) if out is Dictionary else ["no devuelve un Dictionary"]
			suite.check(shape_diffs.is_empty(), "3.6 %s() del stub de reglas tiene la forma del ejemplo%s" % [pair[0], "" if shape_diffs.is_empty() else ": " + str(shape_diffs)])

# ---------------------------------------------------------------------------------------------------------------------
# 3.1 a 3.5: los nombres de la API de cada capa que ya existe

func _test_api_conformance() -> void:
	for layer in Fx.LAYERS:
		for kind in ["stub", "real"]:
			var path: String = Fx.STUB_PATHS[layer] if kind == "stub" else Fx.REAL_PATHS[layer]
			var script := Fx.load_script(path)
			var label := "%s de %s (%s)" % ["el stub" if kind == "stub" else "la clase real", layer, path.trim_prefix("res://scripts/humahuaca/")]
			if script == null:
				suite.pend("api-%s-%s" % [kind, layer], label + " todavía no existe: lo escribe su dueño (stubs en R1.0, clases reales en R1)", "r1")
				continue
			var missing := Fx.api_missing(script, layer)
			suite.check(missing.is_empty(), "3.%d %s trae toda la API del contrato%s" % [Fx.LAYERS.find(layer) + 1, label, "" if missing.is_empty() else ": le falta " + ", ".join(PackedStringArray(missing))])

# ---------------------------------------------------------------------------------------------------------------------
# CONTRATO 7: corridas degradadas (una capa reemplazada por su stub, de a una)

## Mismo camino que main._start_humahuaca pero con el controlador que se le dé (la cáscara instanciada sola).
func _start_with_controller(controller: Node, opts: Dictionary) -> void:
	game._stop_humahuaca()
	game.jev.invalidate()
	if is_instance_valid(game.world):
		game.remove_child(game.world)
		game.world.queue_free()
	game.world = null
	game.mode = "hx"
	game.paused = true
	game._new_ui()
	game.hx = controller
	game.add_child(controller)
	controller.exited.connect(game._on_hx_exited)
	controller.start(game, opts)

func _test_degraded_runs() -> void:
	await _to_menu()
	# interfaz: siempre se puede evaluar, porque la cáscara existe desde T0
	var shell: Node = Fx.ui_shell()
	if suite.check(shell != null, "7 la cáscara de la interfaz (stubs/stub_ui.gd) existe y se instancia"):
		_start_with_controller(shell, {"skip_intro": true})
		await _frames(3)
		suite.check(game.mode == "hx" and game.hx == shell, "7 corrida degradada «ui»: el nivel arranca con la cáscara instanciada sola")
		suite.check(bool(shell.qa_state().get("shell", false)), "7 corrida degradada «ui»: lo que corre es la cáscara (qa_state().shell) y no el controlador real")
		var t0 := float(shell.qa_state().elapsed)
		shell.qa_step(4.0)
		suite.check(float(shell.qa_state().elapsed) >= t0 + 4.0 - 0.001, "7 corrida degradada «ui»: el reloj avanza con qa_step")
		_key(KEY_ESCAPE)
		await _frames(4)
		suite.check(game.mode == "menu" and game.hx == null, "7 corrida degradada «ui»: Esc vuelve al menú y libera la cáscara")
	# terreno, reglas, vista y progreso: hace falta el stub de la capa Y el controlador real (que sabe reemplazarla con opts.force_stub)
	var real_present: Array = []
	for layer in Fx.SWAPPABLE:
		if Fx.load_script(Fx.REAL_PATHS[layer]) != null:
			real_present.append(layer)
	# La corrida normal (sin reemplazos) es la referencia: las capas que el controlador dice haber armado cuando nadie fuerza nada.
	var baseline := {}
	var runs := {}
	if not ui_is_shell:
		game._start_humahuaca({"skip_intro": true})
		await _frames(4)
		if suite.check(game.mode == "hx" and is_instance_valid(game.hx), "7 corrida normal (sin reemplazos): el nivel arranca con lo que haya de cada capa"):
			baseline = _controller_layers()
		_key(KEY_ESCAPE)
		await _frames(4)
		suite.check(game.mode == "menu" and game.hx == null, "7 corrida normal: vuelve al menú")
		if baseline.is_empty():
			suite.pend("degradadas-capas", "qa_state() del controlador no informa las capas efectivas (clave layers): no se puede comprobar que cada corrida reemplace solo la suya (BACKLOG B-020)", "r1")
	for layer in Fx.SWAPPABLE:
		if not Fx.has_stub(layer):
			suite.pend("degradada-" + layer, "stubs/stub_%s.gd todavía no existe: no se puede correr el nivel con la capa «%s» reemplazada por su stub" % [layer, layer], "r1")
			continue
		if ui_is_shell:
			suite.pend("degradada-" + layer, "el controlador real todavía es la cáscara (no sabe reemplazar capas con opts.force_stub)", "r1")
			continue
		game._start_humahuaca({"force_stub": [layer], "skip_intro": true})
		await _frames(4)
		suite.check(game.mode == "hx" and is_instance_valid(game.hx), "7 corrida degradada «%s»: el nivel arranca con esa capa reemplazada por su stub" % layer)
		if game.mode == "hx" and is_instance_valid(game.hx):
			var e0 := float(game.hx.qa_state().elapsed)
			game.hx.qa_step(5.0)
			await _frames(2)
			suite.check(float(game.hx.qa_state().elapsed) > e0, "7 corrida degradada «%s»: el nivel avanza" % layer)
			var seen := _controller_layers()
			if not baseline.is_empty() and not seen.is_empty():
				var problems := Fx.forced_layer_problems(baseline, seen, layer)
				suite.check(problems.is_empty(), "7 corrida degradada «%s»: solo esa capa corre en su versión mínima (capas: %s)%s" % [layer, JSON.stringify(seen), "" if problems.is_empty() else "; " + "; ".join(PackedStringArray(problems))])
				runs[layer] = {"capas": seen, "difiere_de_la_corrida_normal": Fx.layers_differ(seen, baseline)}
				if real_present.has(layer):
					suite.check(str(baseline.get(layer, "")) == "real" and bool(runs[layer].difiere_de_la_corrida_normal), "7 corrida degradada «%s»: la clase real existe, la corrida normal la usa y forzar su stub sí cambia la corrida" % layer)
		_key(KEY_ESCAPE)
		await _frames(4)
		suite.check(game.mode == "menu" and game.hx == null, "7 corrida degradada «%s»: vuelve al menú" % layer)
	var with_effect: Array = []
	for layer in runs:
		if bool(runs[layer].difiere_de_la_corrida_normal):
			with_effect.append(layer)
	var note := "con clases reales, cada corrida por capa tiene que diferir de la normal en la capa forzada"
	if real_present.is_empty():
		note = "ninguna clase real existe todavía: forzar un stub no cambia nada y las corridas por capa son iguales a la normal (BACKLOG B-014)"
	suite.extra["degradadas"] = {"corrida_normal": baseline, "clases_reales_presentes": real_present, "corridas": runs, "con_efecto": with_effect, "nota": note}

## Las capas que el controlador real dice haber armado (qa_state().layers: id → «real» | «minimo» | «falta»); {} si no las informa (la cáscara no lo hace).
func _controller_layers() -> Dictionary:
	if not is_instance_valid(game.hx):
		return {}
	var layers: Variant = game.hx.qa_state().get("layers", null)
	return (layers as Dictionary).duplicate() if layers is Dictionary else {}

## Sanidad de las corridas degradadas (una prueba que nunca falla no protege nada): el comparador de capas efectivas ve lo que tiene que ver.
func _test_forced_layer_comparator() -> void:
	var real := {"terrain": "real", "rules": "real", "progress": "real", "view": "real"}
	var rules_swapped := {"terrain": "real", "rules": "minimo", "progress": "real", "view": "real"}
	suite.check(Fx.forced_layer_problems(real, rules_swapped, "rules").is_empty() and Fx.layers_differ(real, rules_swapped), "7 el comparador de capas acepta una corrida donde solo la capa forzada pasó a su versión mínima")
	suite.check(not Fx.forced_layer_problems(real, real, "rules").is_empty(), "7 el comparador de capas ve una capa forzada que siguió siendo la real")
	suite.check(not Fx.forced_layer_problems(real, {"terrain": "minimo", "rules": "minimo", "progress": "real", "view": "real"}, "rules").is_empty(), "7 el comparador de capas ve otra capa que pasó a su versión mínima sin que se la forzara")
	suite.check(not Fx.forced_layer_problems(real, {"terrain": "real", "rules": "falta", "progress": "real", "view": "real"}, "rules").is_empty(), "7 el comparador de capas ve una capa forzada que no arrancó (falta)")
	var minimal := {"terrain": "minimo", "rules": "minimo", "progress": "minimo", "view": "minimo"}
	suite.check(Fx.forced_layer_problems(minimal, minimal, "view").is_empty() and not Fx.layers_differ(minimal, minimal), "7 sin clases reales forzar un stub no cambia nada, y el comparador lo dice (la corrida no difiere de la normal)")
