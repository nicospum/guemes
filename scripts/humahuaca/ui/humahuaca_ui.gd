extends "res://scripts/humahuaca/ui/humahuaca_ui_play.gd"
## Controlador de «humahuaca», parte 3 de 3 y el archivo que carga main.gd (CONTRATO 3.5): start/stop, el reloj de cada cuadro (con el orden de
## ADDENDA A-11: cámara antes de view.update_state) y la API de QA estable. El resto del controlador está en humahuaca_ui_base.gd y humahuaca_ui_play.gd.


## opts: {load, qa, attempt, seed, phase, skip_intro, force_stub}. Las banderas --hx-seed, --hx-phase y --hx-skip-intro completan lo que opts no trae.
func start(m: Node, opts: Dictionary = {}) -> void:
	main = m
	_opts = opts.duplicate(true)
	_cli = _cli_flags()
	process_priority = 10  # después de main: la cámara de main.gd se pisa con la de este nivel en cada cuadro
	_read_json()
	_read_options()
	_remember_global_state()
	if is_instance_valid(main.camera):
		main.camera.far = 9000.0
		main.camera.fov = 46.0
	_build_ui()
	_fit_scale()
	_build_layers()
	_begin_game()
	_build_view()
	_setup_camera()
	_open_first_screen()
	_refresh_hud(true)
	if is_instance_valid(main.audio_manager):
		main.audio_manager.set_environment("norte")  # viento; la lluvia propia llega con los efectos (sin música)


## Libera lo propio y deja `main` como estaba; main.gd libera este nodo y vuelve al menú o al norte. Se puede llamar más de una vez.
func stop() -> void:
	if main != null and is_instance_valid(main):
		var vp: Viewport = main.get_viewport()
		if is_instance_valid(main.camera):
			if _saved.has("far"):
				main.camera.far = _saved.far
				main.camera.fov = _saved.fov
			main.camera.current = true
		if vp != null and _saved.has("scale3d"):
			vp.scaling_3d_scale = _saved.scale3d
			vp.msaa_3d = _saved.msaa
		var win: Window = main.get_window()
		if win != null:
			if _size_cb.is_valid() and win.size_changed.is_connected(_size_cb):
				win.size_changed.disconnect(_size_cb)
			if _saved.has("content_scale"):
				win.content_scale_factor = _saved.content_scale
		if is_instance_valid(main.audio_manager) and _saved.has("audio_env") and str(_saved.audio_env) != "":
			main.audio_manager.set_environment(str(_saved.audio_env))
		if not _saved_by_player and _saved.has("last_save"):
			main.settings.last_save = _saved.last_save
	_saved = {}
	if is_instance_valid(view):
		view.queue_free()
	view = null
	if dialogs != null:
		dialogs.close()
	for n in [_modal_layer, overlay, minimap, _subtitle, _skip_hint]:
		if n != null and is_instance_valid(n):
			(n as Node).queue_free()
	if hud != null and is_instance_valid(hud.root):
		hud.root.queue_free()
	hud = null
	overlay = null
	minimap = null
	dialogs = null
	_modal_layer = null
	_subtitle = null
	_skip_hint = null
	rules = null
	progress = null
	main = null
	set_process(false)
	set_process_input(false)
	set_process_unhandled_input(false)


func _process(delta: float) -> void:
	if main == null:
		return
	if orders != null:
		orders.tick(delta)
	_toast_tick(delta)
	_input_camera(delta)
	if mode == "opening" and cam != null:
		if not cam.update_opening(delta):
			_finish_opening()
	_decision_tick(delta)
	if _auto_resume > 0.0:
		_auto_resume -= delta
		if _auto_resume <= 0.0 and _playing() and mode == "play" and not (dialogs != null and dialogs.is_open()):
			paused = false
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 2.2)
	if mode == "play" and not paused and _playing() and not (dialogs != null and dialogs.is_open()):
		_advance(minf(delta, MAX_FRAME_DT) * speed)
	elif rules == null:
		pass
	if _ended and _end_delay > 0.0:
		_end_delay -= delta
		if _end_delay <= 0.0:
			_show_report()
	apply_camera()
	if is_instance_valid(view) and view.has_method("update_state"):
		view.call("update_state", delta)
	_calm_tick(delta)
	_hud_timer -= delta
	if _hud_timer <= 0.0:
		_refresh_hud()


func _advance(dt: float) -> void:
	if rules == null:
		_clock += dt
		return
	var ev: Variant = rules.call("tick", dt)
	if ev is Array:
		_handle_events(ev)
	if progress != null and progress.has_method("checkpoint_tick"):
		progress.call("checkpoint_tick", rules)
	_check_end(true)


## Cámara por teclado: WASD y flechas, Q y E, RePág y AvPág, y el borde de la pantalla. Lee las teclas que este nodo vio (sirve también con entrada inyectada).
func _input_camera(delta: float) -> void:
	if cam == null or mode == "opening" or (dialogs != null and dialogs.is_open()):
		return
	var mv := Vector2.ZERO
	if _held(KEY_W) or _held(KEY_UP):
		mv.y += 1.0
	if _held(KEY_S) or _held(KEY_DOWN):
		mv.y -= 1.0
	if _held(KEY_D) or _held(KEY_RIGHT):
		mv.x += 1.0
	if _held(KEY_A) or _held(KEY_LEFT):
		mv.x -= 1.0
	var fast := _held(KEY_SHIFT)
	if mv != Vector2.ZERO:
		cam.pan(mv.normalized(), delta, fast)
	elif edge_pan and _mouse_seen and not _middle_drag and not _pressing and main != null and not main.qa_mode and DisplayServer.window_is_focused():
		var edge := _edge_vector()
		if edge != Vector2.ZERO:
			cam.pan(edge, delta, false, _ui_num("camera", "edge_speed", 0.7))
	var yaw_dir := 0.0
	if _held(KEY_E):
		yaw_dir += 1.0
	if _held(KEY_Q):
		yaw_dir -= 1.0
	var pitch_dir := 0.0
	if _held(KEY_PAGEUP):
		pitch_dir += 1.0
	if _held(KEY_PAGEDOWN):
		pitch_dir -= 1.0
	cam.rotate_view(yaw_dir, pitch_dir, delta)


func _held(code: int) -> bool:
	return bool(_keys_down.get(code, false))


func _edge_vector() -> Vector2:
	var vp := main.get_viewport()
	var size := vp.get_visible_rect().size
	var p := _mouse_pos
	if p.x < 0.0 or p.y < 0.0 or p.x > size.x or p.y > size.y:
		return Vector2.ZERO
	var px := _ui_num("camera", "edge_px", 6.0)
	var v := Vector2.ZERO
	if p.x <= px:
		v.x = -1.0
	elif p.x >= size.x - px:
		v.x = 1.0
	if p.y <= px:
		v.y = 1.0
	elif p.y >= size.y - px:
		v.y = -1.0
	return v


# ---------------------------------------------------------------------------------------------------------------------
# Entrada

func _visible_controls() -> Dictionary:
	if hud == null:
		return {"controls": 0, "buttons": 0, "groups": [], "names": []}
	return hud.controls_report()


func _text_chars(with_warn: bool) -> int:
	var n := 0
	if hud != null:
		n += hud.text_chars(with_warn)
	if overlay != null:
		n += overlay.drawn_text_chars
	if minimap != null:
		n += minimap.drawn_text_chars
	return n


func qa_state() -> Dictionary:
	_refresh_hud(true)
	var alerts: Array = []
	var alert_list: Variant = _hs.get("alertas", [])
	if alert_list is Array:
		for entry in alert_list:
			if entry is Dictionary:
				alerts.append({"id": str(entry.get("id", "")), "nivel": str(entry.get("nivel", "info"))})
	var fronts := {"bateria": "guardado", "cuartel": "guardado", "posta": "guardado"}
	var front_list: Variant = _hs.get("frentes", [])
	if front_list is Array:
		for entry in front_list:
			if entry is Dictionary and fronts.has(str(entry.get("id", ""))):
				fronts[str(entry.id)] = str(entry.get("estado", "guardado"))
	var ctl := _visible_controls()
	var focus: Vector2 = cam.target if cam != null else Vector2(450.0, 325.0)
	return {"phase": _phase(), "elapsed": _elapsed(), "paused": paused or mode != "play", "speed": speed, "selected": selected.duplicate(),
		"camera": {"target": [focus.x, focus.y], "dist": cam.dist if cam != null else 0.0, "pitch_deg": cam.pitch_deg if cam != null else 0.0, "yaw_deg": cam.yaw_deg if cam != null else 0.0},
		"visible_controls": int(ctl.controls), "visible_buttons": int(ctl.buttons), "control_groups": ctl.groups, "text_chars": _text_chars(true), "text_chars_juego": _text_chars(false),
		"alerts": alerts, "front_states": fronts, "status": str(_rules_state().get("status", "playing")), "layers": layers.duplicate(),
		"mode": mode, "dialog": dialogs.current if dialogs != null else "", "guide": {"text": str(guide.get("text", "")), "action": str(guide.get("action", "")), "actor": str(guide.get("actor", ""))},
		"seed": _seed, "attempt": _attempt, "orders": order_count, "issued": orders.issued.duplicate(true) if orders != null else [], "first_order_s": first_order_s, "aiming": orders != null and orders.aiming(), "retry_ms": retry_ms,
		"toast": str(_toast_cur.get("text", "")), "motive": _motive_text, "auto_start": _auto_start}


## Solo QA: fija el rumbo de la mirada del cuadro inicial (A-11: la vista pasa de 35° a 325° en el mismo merge; con el dato nuevo esto no cambia nada) y lo aplica.
func qa_set_initial_yaw(yaw_deg: float) -> void:
	_yaw_override = yaw_deg
	reset_camera()


func qa_set_camera(target: Vector2, dist: float, pitch_deg: float, yaw_deg: float) -> void:
	if cam == null:
		return
	if mode == "opening":
		cam.finish_opening()
		_finish_opening()
	cam.set_frame(target, dist, pitch_deg, yaw_deg)
	apply_camera()


## Muestra u oculta la interfaz (para las vistas sin interfaz de la herramienta de recorrido).
func qa_set_ui_visible(on: bool) -> void:
	if hud != null:
		hud.visible_root(on)
	if overlay != null:
		overlay.visible = on
	if _modal_layer != null:
		_modal_layer.visible = on


## Fija el reloj de juego. Las reglas no retroceden: si piden un tiempo anterior, se empieza el intento de nuevo y se avanza hasta ahí.
func qa_set_time(t: float) -> void:
	var target_time := maxf(t, 0.0)
	if rules == null:
		_clock = target_time
		return
	if target_time < _elapsed() - 0.001:
		_new_attempt()
		mode = "play"
	if target_time > _elapsed() and rules.has_method("advance_to"):
		rules.call("advance_to", target_time)
	_auto_start = false
	_check_end(false)
	_refresh_hud(true)


## Avanza `seconds` de juego a ×1 y vuelve a pausar. Se detiene si termina la partida o si queda una decisión sin resolver.
func qa_step(seconds: float) -> void:
	if mode == "opening":
		skip_opening()
	var left := minf(maxf(seconds, 0.0), MAX_STEP_S)
	if rules == null:
		_clock += left
	else:
		if dialogs != null and dialogs.current in ["pausa", "ayuda", "diario", "confirmar"]:
			dialogs.close()
		while left > 0.0 and _playing() and not _decision_pending():
			var dt := minf(left, 1.0)
			var ev: Variant = rules.call("tick", dt)
			if ev is Array:
				_handle_events(ev)
			left -= dt
		if progress != null and progress.has_method("checkpoint_tick"):
			progress.call("checkpoint_tick", rules)
		_auto_start = false
		_check_end(false)
		_check_decision()
	paused = true
	if is_instance_valid(view) and view.has_method("update_state"):
		view.call("update_state", 0.0)
	_refresh_hud(true)


## Recorrido de las 7 vistas canónicas (con y sin interfaz) y qa_report.json en main.qa_path (--qa=humahuaca).
func qa_run() -> void:
	var dir := str(main.qa_path) if main != null else ""
	if dir.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(dir)
	if mode != "play":
		_start_play_after_briefing(true)
	_refresh_hud(true)
	await RenderingServer.frame_post_draw
	if main == null:
		return
	var report := {"controlador": "r1", "capas": layers, "views": {}, "initial_frame": _initial_frame_report()}
	_save_shot(dir.path_join("humahuaca-inicio.png"))
	var start_frame := cam.frame() if cam != null else {}
	for id in W.VIEW_IDS:
		if not is_instance_valid(view) or not view.has_method("canonical_view"):
			break
		var cv: Variant = view.call("canonical_view", str(id))
		if not (cv is Dictionary) or (cv as Dictionary).is_empty():
			continue
		var d := cv as Dictionary
		var t3: Vector3 = d.target
		qa_set_camera(Vector2(t3.x, t3.z), float(d.distance), float(d.pitch_deg), float(d.yaw_deg))
		view.call("set_time_override", float(d.time_of_day), float(d.rain))
		for i in range(4):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_save_shot(dir.path_join("vista_%s.png" % str(id)))
		qa_set_ui_visible(false)
		for i in range(2):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_save_shot(dir.path_join("vista_%s_sin_ui.png" % str(id)))
		qa_set_ui_visible(true)
		var probes: Variant = view.call("probes", main.camera) if view.has_method("probes") else []
		(report.views as Dictionary)[str(id)] = {"probes": probes, "must_show": d.get("must_show", [])}
	if is_instance_valid(view):
		view.call("set_time_override", -1.0, -1.0)
	if cam != null and not start_frame.is_empty():
		cam.set_frame(start_frame.target, start_frame.dist, start_frame.pitch_deg, start_frame.yaw_deg)
		apply_camera()
	report["state"] = qa_state()
	var file := FileAccess.open(dir.path_join("qa_report.json"), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()


func _save_shot(path: String) -> void:
	var image: Image = main.get_viewport().get_texture().get_image()
	if image != null and not image.is_empty():
		image.save_png(path)


## ¿Entran los tres objetivos y la zona de partida en el cuadro inicial, con su margen? (V02)
func _initial_frame_report() -> Dictionary:
	var out := {"fits": false, "targets": []}
	var camera := camera3d()
	if camera == null:
		return out
	var f := initial_frame()
	out["fits"] = bool(f.fits)
	var size := main.get_viewport().get_visible_rect().size
	for id in ["bateria", "cuartel", "posta", "zona_partida"]:
		var p := landmark_pos(str(id))
		var v := Vector3(p.x, ground_height(p.x, p.y), p.y)
		var s := camera.unproject_position(v)
		var on_screen := not camera.is_position_behind(v) and s.x >= size.x * 0.05 and s.x <= size.x * 0.95 and s.y >= size.y * 0.05 and s.y <= size.y * 0.95
		(out.targets as Array).append({"id": str(id), "x": snappedf(s.x, 0.1), "y": snappedf(s.y, 0.1), "on_screen": on_screen})
	return out


## Deja el nivel en pleno ataque (las reglas empiezan en esa fase) y corriendo, para medir el cuadro con lluvia, fichas y efectos.
func benchmark_prepare() -> void:
	if main == null:
		return
	_start_phase = "ataque"
	_skip_intro = true
	if dialogs != null:
		dialogs.close()
	_new_attempt()
	mode = "play"
	_auto_start = false
	paused = false
	speed = U.SPEEDS[0]
	_refresh_hud(true)
