extends "res://scripts/humahuaca/ui/humahuaca_ui_base.gd"
## Controlador de «humahuaca», parte 2 de 3 (CONTRATO 3.5): la entrada (teclas y mouse), la selección, las órdenes del jugador, los avisos, las
## decisiones, el «siguiente paso», las alertas, el HUD, las pantallas (briefing, apertura, pausa, ayuda, parte) y el reintento. Extiende a
## humahuaca_ui_base.gd (estado, capas, cámara, textos) y es extendida por humahuaca_ui.gd (arranque, reloj y API de QA). Se parte en tres archivos
## solo para que ninguno pase de ~1 500 líneas (CONTRATO 0); es UN controlador. Una función de esta capa no llama a otra de humahuaca_ui.gd.


func save_game() -> bool:
	if rules == null or not _playing() or mode != "play":
		return false
	var err: Variant = rules.call("save_game", str(main._save_path(V.SCENARIO)))
	if int(err) == OK:
		main.settings.last_save = V.SCENARIO
		main._save_settings()
		_saved_by_player = true
		_toast(tx("toast.saved", ""), "info", true)
		return true
	_toast(tx("toast.save_failed", ""), "aviso", true)
	return false


func load_game() -> bool:
	if rules == null:
		return false
	_notice = ""
	if not _try_load_save():
		_toast(_notice, "aviso", true)
		return false
	if dialogs != null:
		dialogs.close()
	clear_transients()
	selected = []
	_auto_start = false
	paused = true
	mode = "play"
	_ended = false
	if is_instance_valid(view):
		view.call("update_state", 0.0)
	_toast(tx("toast.loaded", ""), "info", true)
	_refresh_hud(true)
	return true


# ---------------------------------------------------------------------------------------------------------------------
# Cámara

## Solo anota qué teclas están apretadas (sirve también con entrada inyectada). Las teclas del juego se atienden en _unhandled_input: así un nodo
## hijo de main agregado después (o un control con foco) las ve antes, y el controlador las marca como manejadas recién cuando las usa.
func _input(event: InputEvent) -> void:
	if main == null or not (event is InputEventKey):
		return
	var k := event as InputEventKey
	var code := int(k.keycode) if int(k.keycode) != 0 else int(k.physical_keycode)
	_keys_down[code] = k.pressed


func _handle_key(k: InputEventKey, code: int) -> bool:
	if mode == "opening":
		skip_opening()
		return true
	if mode == "briefing":  # Esc vuelve al menú, Enter es «Empezar» y Espacio (seguir el tiempo) empieza ya y con el reloj corriendo; el resto no se toca
		if code == KEY_ESCAPE:
			exited.emit("menu")
			return true
		if code == KEY_SPACE:
			_start_play_after_briefing(true)
			paused = false
			_auto_start = false
			_refresh_hud(true)
			return true
		if code == KEY_ENTER or code == KEY_KP_ENTER:
			return dialogs.press_primary()
		return false
	if dialogs != null and dialogs.is_open():
		if code == KEY_F11:
			return false
		if code == KEY_ESCAPE:
			if dialogs.closable:
				_close_dialog()
			return true
		if code == KEY_ENTER or code == KEY_KP_ENTER or code == KEY_SPACE:
			dialogs.press_primary()
			return true
		if code == KEY_F1 and dialogs.current == "ayuda":
			_close_dialog()
			return true
		return true
	var rows: Variant = _key_map.get(code, null)
	if not (rows is Array):
		return false
	for row in rows:
		var d := row as Dictionary
		if bool(d.ctrl) != k.ctrl_pressed and not (str(d.action) == "attack" and k.ctrl_pressed):
			continue
		if _do_key(str(d.id), str(d.action), k):
			return true
	return false


func _do_key(id: String, action: String, k: InputEventKey) -> bool:
	match id:
		"pause":
			toggle_pause()
		"speed_1":
			set_speed_index(0)
		"speed_2":
			set_speed_index(1)
		"speed_4":
			set_speed_index(2)
		"speed_up":
			shift_speed(1)
		"speed_down":
			shift_speed(-1)
		"help":
			open_help()
		"menu":
			_escape()
		"save":
			save_game()
		"load":
			load_game()
		"cycle":
			cycle_selection(k.shift_pressed)
		"undo":
			undo_last()
		"cam_reset":
			reset_camera()
		"minimap_size":
			if minimap != null:
				minimap.set_large(not minimap.large)
				hud.root.move_child(minimap, hud.root.get_child_count() - 1)
		"fullscreen":
			return false
		_:
			if id.begins_with("group_"):
				select_group(int(id.trim_prefix("group_")) - 1)
			elif action != "":
				if action == "attack" and k.ctrl_pressed:
					orders.issue_selected("attack", Vector2.ZERO, {"posture": "a_fondo"})
				else:
					orders.press(action)
				_refresh_hud(true)
			else:
				return false
	return true


func _unhandled_input(event: InputEvent) -> void:
	if main == null:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo:
			var code := int(k.keycode) if int(k.keycode) != 0 else int(k.physical_keycode)
			if _handle_key(k, code):
				get_viewport().set_input_as_handled()
		return
	if mode == "briefing":
		return
	if mode == "opening":
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			skip_opening()
			get_viewport().set_input_as_handled()
		return
	if dialogs != null and dialogs.is_open():
		return
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		_mouse_pos = mm.position
		_mouse_seen = true
		if _middle_drag and cam != null and camera3d() != null:
			cam.drag_move(camera3d(), mm.position)
		elif _pressing:
			box_rect = Rect2(_press_pos, mm.position - _press_pos).abs()
		if orders != null and orders.aiming():
			orders.aim_move(mm.position)
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		_mouse_pos = mb.position
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				_left_button(mb)
			MOUSE_BUTTON_RIGHT:
				if mb.pressed:
					orders.context_order(mb.position, mb.shift_pressed, mb.ctrl_pressed, mb.alt_pressed)
					_refresh_hud(true)
			MOUSE_BUTTON_MIDDLE:
				_middle_drag = mb.pressed
				if mb.pressed and cam != null and camera3d() != null:
					cam.drag_begin(camera3d(), mb.position)
				elif not mb.pressed and cam != null:
					cam.drag_end()
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed and cam != null and camera3d() != null:
					cam.zoom_at(camera3d(), mb.position, _ui_num("camera", "zoom_step", 0.86))
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed and cam != null and camera3d() != null:
					cam.zoom_at(camera3d(), mb.position, 1.0 / _ui_num("camera", "zoom_step", 0.86))
		get_viewport().set_input_as_handled()


func _left_button(mb: InputEventMouseButton) -> void:
	if mb.pressed:
		if orders != null and orders.aiming():
			orders.aim_confirm(mb.position, mb.shift_pressed)
			_refresh_hud(true)
			return
		_pressing = true
		_press_pos = mb.position
		_press_unit = pick_unit_at(mb.position)
		box_rect = Rect2(mb.position, Vector2.ZERO)
		return
	if not _pressing:
		return
	_pressing = false
	var moved := mb.position.distance_to(_press_pos)
	var how := "add" if mb.shift_pressed else ("toggle" if mb.ctrl_pressed else "replace")
	if moved <= CLICK_PX:
		if _press_unit != "":
			select([_press_unit], how)
		elif how == "replace":
			select([], "replace")
	else:
		var camera := camera3d()
		var inside: Variant = []
		if camera != null and is_instance_valid(view) and view.has_method("pick_units_in_rect"):
			inside = view.call("pick_units_in_rect", camera, Rect2(_press_pos, mb.position - _press_pos).abs())
		select(inside if inside is Array else [], how)
	box_rect = Rect2()


func toggle_pause() -> void:
	if mode != "play" or not _playing():
		return
	if dialogs != null and dialogs.is_open():
		return
	_auto_resume = 0.0
	paused = not paused
	if not paused:
		_auto_start = false
	_refresh_hud(true)


func set_speed_index(i: int) -> void:
	if mode != "play":
		return
	speed = U.SPEEDS[clampi(i, 0, U.SPEEDS.size() - 1)]
	if paused and _playing() and not (dialogs != null and dialogs.is_open()):
		paused = false
		_auto_start = false
	_suggest_x2 = false
	_calm_s = 0.0
	_refresh_hud(true)


func shift_speed(direction: int) -> void:
	set_speed_index(clampi(U.SPEEDS.find(speed) + direction, 0, U.SPEEDS.size() - 1))


## Esc cancela lo que se está haciendo. Si no hay nada que cancelar y todavía no se dio ninguna orden (ni corrieron 20 s), no hay nada que perder y vuelve al
## menú; después abre el menú de pausa (CONTROLES.md).
func _escape() -> void:
	if orders != null and (orders.aiming() or not orders.waypoints.is_empty()):
		orders.cancel_aim()
		return
	if order_count == 0 and _elapsed() < _ui_num("hud_limits", "esc_menu_free_s", 20.0) and _playing():
		exited.emit("menu")
		return
	open_pause_menu()


# ---------------------------------------------------------------------------------------------------------------------
# Selección

func select(ids: Array, how: String = "replace") -> void:
	var next: Array = selected.duplicate() if how != "replace" else []
	for id in ids:
		var sid := str(id)
		if not V.GROUPS.has(sid):
			continue
		if how == "toggle" and next.has(sid):
			next.erase(sid)
		elif not next.has(sid):
			next.append(sid)
	var ordered: Array = []
	for id in V.GROUPS:
		if next.has(id):
			ordered.append(id)
	var changed := ordered != selected
	selected = ordered
	if changed:
		if orders != null:
			orders.cancel_aim()
		play_sound("select")
	if is_instance_valid(view) and view.has_method("set_selected_ids"):
		view.call("set_selected_ids", selected)
	_refresh_hud(true)


func select_group(index: int) -> void:
	if index < 0 or index >= V.GROUPS.size():
		return
	var id := str(V.GROUPS[index])
	if selected == [id] and index < 3:
		center_on_front(str(group_fronts.get(id, "")))
		return
	select([id], "replace")


func cycle_selection(backwards: bool) -> void:
	var idx := -1
	if not selected.is_empty():
		idx = V.GROUPS.find(selected[0])
	idx = (idx + (-1 if backwards else 1) + V.GROUPS.size()) % V.GROUPS.size()
	select([V.GROUPS[idx]], "replace")


func undo_last() -> void:
	if rules == null or not _playing():
		return
	var res: Variant = rules.call("undo_last")
	if res is Dictionary and bool((res as Dictionary).get("ok", false)):
		play_sound("order")
		_refresh_hud(true)
	else:
		set_motive(str((res as Dictionary).get("reason", tx("actions.nothing_to_undo", ""))) if res is Dictionary else "", true)


# ---------------------------------------------------------------------------------------------------------------------
# Lo que usan los módulos hermanos: sonido, motivo, avisos y órdenes

func play_sound(name_text: String) -> void:
	if main != null and is_instance_valid(main.audio_manager):
		main.audio_manager.play(name_text)


func set_motive(text: String, is_error: bool) -> void:
	_motive_text = text
	_motive_until = _clock_real() + (4.5 if is_error else 3600.0 if text != "" else 0.0)
	if is_error and text != "":
		_hud_timer = 0.0


func refresh_hud_now() -> void:
	_refresh_hud(true)


func on_order_ok(actor: String, action: String) -> void:
	order_count += 1
	if first_order_s < 0.0:
		first_order_s = _elapsed()
	if _auto_start:
		_auto_start = false
		paused = false
	_motive_text = ""
	_motive_until = 0.0
	if action != "cancel":
		play_sound("order")
	_order_feedback(actor, action)
	_refresh_hud(true)


## Dice qué orden se dio (B-052 b): antes un clic derecho sobre la posta solo dibujaba la línea y nadie sabía qué había pasado.
func _order_feedback(actor: String, action: String) -> void:
	if action == "cancel":
		_toast(tx("hud.cancel_done", ""), "info")
		return
	if actor == "" or action == "give_signal" or rules == null or hud == null:
		return  # la señal ya tiene su propio aviso: el disparo
	var info: Variant = rules.call("action_info", action)
	var name_text := str((info as Dictionary).get("name", "")) if info is Dictionary else ""
	if name_text == "":
		return
	_toast(tx("toast.order_given", "") % [str(hud.short_names().get(actor, actor)), name_text], "info")


func on_order_failed(reason: String) -> void:
	set_motive(reason, true)
	play_sound("error")
	_refresh_hud(true)


func _toast(text: String, level: String, force: bool = false) -> void:
	if text.strip_edges() == "":
		return
	var levels: Dictionary = ui_data.get("toasts", {}).get("levels", {})
	var cfg: Dictionary = levels.get(level, {"priority": 1, "seconds": 4.5})
	var item := {"text": text, "level": level, "left": float(cfg.get("seconds", 4.5)), "priority": int(cfg.get("priority", 1))}
	if force:
		_toast_cur = item
		return
	if _toast_cur.is_empty() or int(item.priority) >= int(_toast_cur.priority):
		if not _toast_cur.is_empty() and int(item.priority) > int(_toast_cur.priority):
			_toast_queue.push_front(_toast_cur)  # el aviso que pasa por delante no se pierde; el de igual prioridad sí se reemplaza
		_toast_cur = item
	else:
		_toast_queue.append(item)
	var max_queue := int(ui_data.get("toasts", {}).get("max_queue", 3))
	while _toast_queue.size() > max_queue:
		_toast_queue.pop_front()


func _toast_tick(delta: float) -> void:
	if _toast_cur.is_empty():
		return
	_toast_cur.left = float(_toast_cur.left) - delta
	if float(_toast_cur.left) <= 0.0:
		_toast_cur = {}
		if not _toast_queue.is_empty():
			_toast_cur = _toast_queue.pop_front()


# ---------------------------------------------------------------------------------------------------------------------
# Eventos del reloj → avisos, efectos y sonido

func _handle_events(events: Array) -> void:
	var kinds: Dictionary = ui_data.get("toasts", {}).get("kinds", {})
	for e in events:
		if not (e is Dictionary):
			continue
		var ev := e as Dictionary
		var kind := str(ev.get("kind", "info"))
		var cfg: Dictionary = kinds.get(kind, {"level": "info"})
		var level := str(cfg.get("level", "info"))
		if bool(ev.get("strong", false)) and level == "info":
			level = "aviso"
		var text := str(ev.get("text", ""))
		if text != "":
			if level != "info" or _toast_queue.size() < 2:
				_toast(text, level)
		if cfg.has("sound"):
			play_sound(str(cfg.sound))
		if cfg.has("shake"):
			_shake = maxf(_shake, float(cfg.shake))
		if cfg.has("fx") and is_instance_valid(view) and view.has_method("fx"):
			var at := _event_pos(ev)
			if at != Vector2.ZERO:
				view.call("fx", str(cfg.fx), at, {})
		if kind == "decision" or ev.has("options"):
			_check_decision()


func _event_pos(ev: Dictionary) -> Vector2:
	var p: Variant = ev.get("pos", null)
	if p is Dictionary:
		return Vector2(float((p as Dictionary).get("x", 0.0)), float((p as Dictionary).get("z", 0.0)))
	var unit_id := str(ev.get("unit", ""))
	if unit_id != "" and rules != null:
		var u: Variant = rules.call("get_unit", unit_id)
		if u is Dictionary and not (u as Dictionary).is_empty():
			return Vector2(float((u as Dictionary).get("x", 0.0)), float((u as Dictionary).get("z", 0.0)))
	var objective := str(ev.get("objective", ""))
	if objective != "":
		return landmark_pos(objective)
	if str(ev.get("kind", "")) == "signal":
		return landmark_pos("cuartel")
	return Vector2.ZERO


# ---------------------------------------------------------------------------------------------------------------------
# Decisiones (pausa automática con reloj; se resuelven solas a los 25 s)

func _decision_pending() -> bool:
	if rules == null:
		return false
	var pending: Variant = rules.call("pending_choice")
	return pending is Dictionary and not (pending as Dictionary).is_empty()


func _check_decision() -> void:
	if rules == null or dialogs == null or not _decision_pending():
		return
	if dialogs.current == "decision":
		return
	open_decision(rules.call("pending_choice"))


## Abre una decisión con reloj: pausa el tiempo, vuelve a ×1 (lo avisa la ventana) y la deja resolverse sola a los 25 s con la opción de reglas.
func open_decision(dec: Dictionary) -> void:
	if dialogs == null:
		return
	var cap := _ui_num("hud_limits", "decision_max_s", 25.0)
	var left := minf(float(dec.get("vence_s", cap)) if float(dec.get("vence_s", 0.0)) > 0.0 else cap, cap)
	_decision_left = left
	_decision_id = str(dec.get("id", ""))
	paused = true
	speed = 1.0
	_auto_resume = 0.0
	dialogs.show_decision(dec, left)


func _decision_tick(delta: float) -> void:
	if dialogs == null or dialogs.current != "decision":
		return
	_decision_left -= delta
	dialogs.update_decision(_decision_left)
	if _decision_left <= 0.0:
		var dec: Dictionary = rules.call("pending_choice") if rules != null else {}
		var options: Array = dec.get("opciones", [])
		var pick := str(dec.get("default", ""))
		if pick == "" and not options.is_empty():
			pick = str((options[options.size() - 1] as Dictionary).get("id", ""))
		_resolve_decision(pick, true)


func _resolve_decision(option_id: String, by_timeout: bool) -> void:
	if rules != null:
		rules.call("resolve_choice", option_id, by_timeout)
	dialogs.close()
	paused = false
	_hud_timer = 0.0
	_check_decision()


# ---------------------------------------------------------------------------------------------------------------------
# HUD: arma el contexto y pinta

func _compute_guide() -> void:
	guide = {}
	if rules == null:
		return
	var sig: Variant = _hs.get("siguiente", {})
	if not (sig is Dictionary) or (sig as Dictionary).is_empty():
		return
	var s := sig as Dictionary
	var action := str(s.get("action", ""))
	var actor := str(s.get("actor", ""))
	var t: Variant = s.get("target", {})
	var target := Vector2.ZERO
	if t is Dictionary and not (t as Dictionary).is_empty():
		target = Vector2(float((t as Dictionary).get("x", 0.0)), float((t as Dictionary).get("z", 0.0)))
	var info: Dictionary = rules.call("action_info", action) if action != "" else {}
	var actionable := not info.is_empty() and action != "hold" and action != "cancel"
	var button := str(info.get("name", "")) if actionable else ""
	var key_hint := key_label_for(action)
	if button != "" and key_hint != "":
		button = "%s  [%s]" % [button, key_hint]
	var enabled := true
	if actionable:
		var av: Variant = rules.call("action_availability", actor, action, target, _guide_opts(action, target))
		enabled = av is Dictionary and bool((av as Dictionary).get("ok", false))
	guide = {"text": str(s.get("texto", "")), "action": action, "actor": actor, "target": target, "urgencia": int(s.get("urgencia", 0)), "button": button,
		"button_visible": button != "", "enabled": enabled, "arrow": actionable and bool(ui_data.get("onboarding", {}).get("arrow", true)) and mode == "play" and _playing()}
	if mode != "play" or not _playing():
		guide = {}


func _guide_opts(action: String, target: Vector2) -> Dictionary:
	var opts := {"pace": orders.pace if orders != null else "march"}
	if action == "attack" or action == "support":
		var f := _front_near(target)
		if f != "":
			opts["front"] = f
		opts["posture"] = "con_cautela"
	return opts


func _front_near(p: Vector2) -> String:
	var best := ""
	var best_d := 60.0
	for fid in V.OBJECTIVES:
		var d := landmark_pos(str(fid)).distance_to(p)
		if d < best_d:
			best_d = d
			best = str(fid)
	return best


func _do_guide() -> void:
	if guide.is_empty() or str(guide.get("action", "")) == "" or rules == null:
		return
	var action := str(guide.action)
	var actor := str(guide.actor)
	var target: Vector2 = guide.target
	if actor != "" and V.GROUPS.has(actor) and not selected.has(actor):
		select([actor], "replace")
	var res: Dictionary = orders.issue(actor, action, target, _guide_opts(action, target))
	if not bool(res.get("ok", false)):
		_refresh_hud(true)


func _pick_alert() -> Dictionary:
	var list: Variant = _hs.get("alertas", [])
	if not (list is Array):
		return {}
	var chosen: Dictionary = {}
	for a in list:
		var d := a as Dictionary
		var level := str(d.get("nivel", "info"))
		var has_button := str(d.get("boton", "")) != ""
		if level == "critica":
			return d
		if level == "info" or not has_button:
			# lo que solo informa (sin botón) va como aviso de pie, una sola vez: no tapa el mapa
			var id := str(d.get("id", ""))
			if not _info_alert_seen.has(id):
				_info_alert_seen[id] = true
				_toast(str(d.get("corto", "")), "aviso" if level != "info" else "info")
			continue
		if chosen.is_empty():
			chosen = d
	# un aviso con botón no repite lo que ya ofrece el «siguiente paso»
	if not chosen.is_empty() and not guide.is_empty():
		var act: Variant = (chosen.get("accion", {}) as Dictionary).get("action", "") if chosen.get("accion", {}) is Dictionary else ""
		if str(act) != "" and str(act) == str(guide.get("action", "")):
			return {}
	return chosen


func _handle_alert_pause(alert: Dictionary) -> void:
	if alert.is_empty():
		return
	var id := str(alert.get("id", ""))
	if not _alert_seen.has(id):
		_alert_seen[id] = true
		if bool(alert.get("pausa", false)) and mode == "play" and not paused:
			paused = true
			_auto_resume = minf(1.5, _ui_num("hud_limits", "auto_pause_max_s", 2.0))
		if str(alert.get("nivel", "")) == "critica":
			play_sound("alert")


func _do_alert() -> void:
	var a: Dictionary = hud._alert_data if hud != null else {}
	if a.is_empty() or rules == null:
		return
	var acc: Variant = a.get("accion", {})
	var action := ""
	var actor := ""
	if acc is Dictionary:
		action = str((acc as Dictionary).get("action", ""))
		actor = str((acc as Dictionary).get("actor", ""))
	if action == "":
		return
	if actor == "":
		actor = str(guide.get("actor", ""))
	var target: Vector2 = guide.get("target", Vector2.ZERO) if str(guide.get("action", "")) == action else Vector2.ZERO
	var res: Dictionary = orders.issue(actor, action, target, _guide_opts(action, target))
	if not bool(res.get("ok", false)):
		_refresh_hud(true)


func _status_line() -> String:
	var tower: Variant = _hs.get("torre", {})
	if tower is Dictionary and not (tower as Dictionary).is_empty() and bool((tower as Dictionary).get("activa", false)):
		if float((tower as Dictionary).get("municion_pct", 100.0)) <= 0.0:
			return tx("hud.tower_empty", "")
		return tx("hud.tower_next", "") % int(ceil(float((tower as Dictionary).get("proxima_en_s", 0.0))))
	var sg: Variant = _hs.get("senal", {})
	if sg is Dictionary and bool((sg as Dictionary).get("puede", false)) and str(_hs.get("fase", {}).get("id", "")) != "extraccion":
		var names: Array = []
		var shorts: Dictionary = hud.short_names() if hud != null else {}
		for id in (sg as Dictionary).get("faltan", []):
			names.append(str(shorts.get(str(id), str(id))))
		var head := tx("hud.signal_ready", "") if names.is_empty() else tx("hud.signal_wait", "") % _join_y(names)
		return "%s · %s · %s" % [head, tx("hud.signal_dark", "") % int(round(float((sg as Dictionary).get("oscuridad_pct", 0.0)))), tx("hud.signal_drift", "") % int(round(float((sg as Dictionary).get("desvelo_pct", 0.0))))]
	return ""


static func _join_y(names: Array) -> String:
	if names.size() <= 1:
		return "".join(PackedStringArray(names))
	return ", ".join(PackedStringArray(names.slice(0, names.size() - 1))) + " y " + str(names[names.size() - 1])


func _warn_text() -> String:
	var minimal: Array = []
	var absent: Array = []
	for id in U.LAYER_IDS:
		var kind := str(layers.get(id, "real"))
		if kind == "minimo":
			minimal.append(str(id))
		elif kind == "falta":
			absent.append(str(id))
	var lines: Array = []
	if not absent.is_empty():
		lines.append(tx("layers.missing", "%s") % _layer_names(absent))
	if minimal.size() == 1:
		lines.append(tx("layers.one." + str(minimal[0]), ""))
	elif minimal.size() > 1:
		lines.append(tx("layers.many", "%s") % _layer_names(minimal))
	if _notice != "":
		lines.append(_notice)
	return "\n".join(PackedStringArray(lines))


func _layer_names(ids: Array) -> String:
	var names: Array = []
	for id in ids:
		names.append(tx("layers.labels." + str(id), str(id)))
	return _join_y(names)


func _calm_tick(delta: float) -> void:
	var cfg: Dictionary = ui_data.get("onboarding", {}).get("speed_suggestion", {})
	var waiting := not guide.is_empty() and str(guide.get("action", "")) == "hold"
	if mode == "play" and not paused and speed == 1.0 and waiting and _playing():
		_calm_s += delta
		if _calm_s >= float(cfg.get("after_calm_s", 20)):
			_suggest_x2 = true
	else:
		_calm_s = 0.0
		if speed != 1.0 or paused or not waiting:
			_suggest_x2 = false


func _idle_groups() -> Array:
	var out: Array = []
	if rules == null:
		return out
	for id in V.GROUPS:
		var u: Variant = rules.call("get_unit", str(id))
		if u is Dictionary and str((u as Dictionary).get("stage", "idle")) == "idle":
			out.append(str(id))
	return out


## La etapa de cada agrupación (id → «moving», «holding»…): el HUD la usa para elegir el texto compacto cuando el de las reglas no entra en la ficha.
func _stages_by_group() -> Dictionary:
	var out := {}
	if rules == null:
		return out
	for id in V.GROUPS:
		var u: Variant = rules.call("get_unit", str(id))
		if u is Dictionary:
			out[str(id)] = str((u as Dictionary).get("stage", "idle"))
	return out


func _refresh_hud(_force_now: bool = false) -> void:
	_hud_timer = float(ui_data.get("hud_limits", {}).get("hud_period_s", 0.2))
	if main == null or hud == null or not is_instance_valid(hud.root):
		return
	var hs: Variant = rules.call("hud_state") if rules != null else {}
	_hs = hs if hs is Dictionary else {}
	_compute_guide()
	var alert := _pick_alert()
	_handle_alert_pause(alert)
	if not alert.is_empty() and not guide.is_empty() and str((alert.get("accion", {}) as Dictionary).get("action", "") if alert.get("accion", {}) is Dictionary else "") == str(guide.get("action", "")):
		guide["button_visible"] = false
		guide["button"] = ""
	_check_decision()
	var motive := ""
	if orders != null and orders.aiming() and orders.motive != "":
		motive = orders.motive
	elif _motive_text != "" and _clock_real() < _motive_until:
		motive = _motive_text
	elif _hover_motive != "":
		motive = _hover_motive
	var phase_id := str(_hs.get("fase", {}).get("id", _phase())) if _hs.get("fase", {}) is Dictionary else _phase()
	var ctx := {"paused": paused or mode != "play", "speed": speed, "phase": phase_id, "selected": selected, "guide": guide, "alert": alert,
		"toast": _toast_cur, "warn": _warn_text(), "motive": motive, "status": _status_line(), "suggest_x2": _suggest_x2,
		"bar_items": orders.bar_items(_hs) if orders != null and mode == "play" else [], "idle_groups": _idle_groups(), "stages": _stages_by_group(),
		"pace": orders.pace if orders != null else "march", "pace_visible": orders != null and orders.aiming() and str(orders.aim.get("action", "")) != "support"}
	if mode == "play" and selected.is_empty() and _playing() and order_count >= 1:
		ctx["motive"] = motive if motive != "" else tx("hud.pick_hint", "")
	if not alert.is_empty():
		ctx["avoid"] = avoid_rects()  # el aviso se corre para no tapar fichas ni rótulos
	hud.refresh(_hs, ctx)


func _on_hud(kind: String, arg: Variant) -> void:
	match kind:
		"pause":
			toggle_pause()
		"speed":
			set_speed_index(int(arg))
		"help":
			open_help()
		"menu":
			open_pause_menu()
		"next":
			if guide.is_empty():
				_refresh_hud(true)
			_do_guide()
		"alert":
			_do_alert()
		"card":
			var d := arg as Dictionary
			var id := str(d.id)
			if selected == [id] and not bool(d.shift) and not bool(d.ctrl):
				center_on_front(str(group_fronts.get(id, "")))
				if str(group_fronts.get(id, "")) == "":
					var u: Variant = rules.call("get_unit", id) if rules != null else {}
					if u is Dictionary:
						cam.center_on(Vector2(float((u as Dictionary).get("x", 0.0)), float((u as Dictionary).get("z", 0.0))))
						apply_camera()
			else:
				select([id], "add" if bool(d.shift) else ("toggle" if bool(d.ctrl) else "replace"))
		"front":
			center_on_front(str((arg as Dictionary).id))
		"action":
			orders.press(str(arg))
			_refresh_hud(true)
		"hover_action":
			_hover_motive = ""
			if str(arg) != "" and rules != null:
				var actor := orders.primary_actor()
				var av := orders.availability(actor, str(arg))
				_hover_motive = (tx("actions.cost_prefix", "") + str(av.get("cost_text", ""))) if bool(av.get("ok", false)) else str(av.get("reason", ""))
			_hud_timer = 0.0
		"pace":
			orders.set_pace(str(arg))
			_refresh_hud(true)


# ---------------------------------------------------------------------------------------------------------------------
# Pantallas: la primera, la apertura y los diálogos

func _open_first_screen() -> void:
	if rules == null or dialogs == null:
		mode = "play"
		return
	var loaded := bool(_opts.get("load", false)) and _notice == ""
	if loaded:
		mode = "play"
		paused = true
		_auto_start = false
		_toast(tx("toast.loaded", ""), "info", true)
		return
	if _skip_intro or _start_phase != "" or bool(_opts.get("qa", false)):
		mode = "play"
		paused = true
		return
	mode = "briefing"
	paused = true
	hud.visible_root(false)
	dialogs.show_briefing(1)


func _start_play_after_briefing(skip_opening_now: bool) -> void:
	dialogs.close()
	if skip_opening_now or cam == null:
		mode = "play"
		paused = true
		hud.visible_root(true)
		_refresh_hud(true)
		return
	_start_opening()


func _start_opening() -> void:
	mode = "opening"
	paused = true
	var cfg: Dictionary = ui_data.get("camera", {}).get("opening", {})
	var frames: Array = []
	var s: Variant = cfg.get("start", {})
	if s is Dictionary:
		frames.append({"target": Vector2(float((s as Dictionary).get("x", 450.0)), float((s as Dictionary).get("z", 330.0))), "dist": float((s as Dictionary).get("dist", 760.0)),
			"pitch_deg": float((s as Dictionary).get("pitch_deg", 60.0)), "yaw_deg": float((s as Dictionary).get("yaw_deg", 325.0)), "hold": false})
	for stop in cfg.get("stops", []):
		var d := stop as Dictionary
		frames.append({"target": landmark_pos(str(d.get("focus", "bateria"))), "dist": float(d.get("dist", 140.0)), "pitch_deg": float(d.get("pitch_deg", 28.0)),
			"yaw_deg": float(d.get("yaw_deg", 90.0)), "hold": true})
	var fin := initial_pose()
	frames.append({"target": fin.target, "dist": fin.dist, "pitch_deg": fin.pitch_deg, "yaw_deg": fin.yaw_deg, "hold": false})
	var total := clampf(float(cfg.get("seconds", 13.5)), 12.0, 15.0)
	cam.start_opening(frames, total, float(cfg.get("hold_s", 1.1)))
	hud.visible_root(false)
	_subtitle.text = "%s  %s" % [tx("briefing.opening.subtitle", ""), Kit.tag_glyph(source_tags, str(ui_data.get("texts", {}).get("briefing", {}).get("opening", {}).get("tag", "documentado")))]
	_subtitle.visible = true
	_skip_hint.text = tx("briefing.opening.skip_hint", "")
	_skip_hint.visible = true


func skip_opening() -> void:
	if mode != "opening":
		return
	if cam != null:
		cam.finish_opening()
	_finish_opening()


func _finish_opening() -> void:
	mode = "play"
	paused = true
	_subtitle.visible = false
	_skip_hint.visible = false
	hud.visible_root(true)
	apply_camera()
	_refresh_hud(true)


func open_pause_menu() -> void:
	if dialogs == null or mode == "briefing" or mode == "opening":
		return
	if dialogs.is_open():
		return
	if mode == "ended":
		return
	_paused_before_dialog = paused
	paused = true
	_auto_resume = 0.0
	_dialog_back = ""
	_show_pause_window()
	_refresh_hud(true)


## El menú de pausa, sin tocar si el reloj corría antes de abrirlo (_paused_before_dialog): lo usan «Cerrar» del diario y de la ayuda y «No, seguir».
func _show_pause_window() -> void:
	dialogs.show_pause(_playing() and rules != null, FileAccess.file_exists(str(main._save_path(V.SCENARIO))))


func open_help() -> void:
	if dialogs == null or mode == "briefing" or mode == "opening":
		return
	if dialogs.current == "ayuda":
		_close_dialog()
		return
	if dialogs.is_open():
		return
	_paused_before_dialog = paused
	paused = true
	_dialog_back = ""
	dialogs.show_help()
	_refresh_hud(true)


## Cierra la ventana abierta y vuelve a donde estaba el jugador (H-R1-2): con la partida terminada, al parte (nunca queda una pantalla sin controles); si el diario o la
## ayuda se abrieron desde el menú de pausa, a ese menú (el reloj sigue frenado); si no, al juego con el reloj como estaba antes de abrir la ventana.
func _close_dialog() -> void:
	if dialogs == null or not dialogs.is_open():
		return
	var id := dialogs.current
	var back := _dialog_back
	_dialog_back = ""
	dialogs.close()
	if mode == "ended":
		_show_report()
		return
	if mode == "play" and ((back == "pausa" and id in ["ayuda", "diario"]) or id == "confirmar"):  # la retirada se confirma desde el menú de pausa: Esc es «No»
		_show_pause_window()
		_refresh_hud(true)
		return
	if id in ["pausa", "ayuda", "diario", "confirmar"] and mode == "play":
		paused = _paused_before_dialog
	_refresh_hud(true)


func _on_dialog(kind: String, arg: Variant) -> void:
	match kind:
		"briefing_page":
			dialogs.show_briefing(int(arg))
		"briefing_start":
			_start_play_after_briefing(bool(arg))
		"dialog_close":
			_close_dialog()
		"pause_resume":
			_close_dialog()
		"pause_save":
			save_game()
			_show_pause_window()
		"pause_load":
			load_game()
		"pause_help":
			_dialog_back = "pausa" if mode == "play" else ""
			dialogs.close()
			dialogs.show_help()
		"pause_diary":  # lo disparan el menú de pausa y los dos partes: «Cerrar» vuelve a donde se abrió (H-R1-2)
			var entries: Array = progress.call("diary_entries") if progress != null and progress.has_method("diary_entries") else []
			_dialog_back = "pausa" if mode == "play" else ""
			dialogs.show_diary(entries)
		"pause_retreat":
			dialogs.show_confirm(tx("pause.retreat_ask", ""), tx("pause.retreat_yes", ""), tx("pause.retreat_no", ""), "retreat_yes", true)
		"confirm_no":
			dialogs.close()
			if mode == "ended":
				_show_report()
			else:
				_show_pause_window()  # sigue en pausa: el reloj no cambia por cancelar la retirada
				_refresh_hud(true)
		"retreat_yes":
			dialogs.close()
			paused = false
			if rules != null:
				rules.call("retreat_all")
			_check_end(false)
		"pause_menu":
			exited.emit("menu")
		"go_norte":
			exited.emit("norte")
		"retry":
			retry(str(arg))
		"ask_new_world":
			dialogs.show_confirm(tx("report.new_world_ask", ""), tx("report.new_world_yes", ""), tx("report.new_world_no", ""), "new_world_yes", false)
		"new_world_yes":
			retry("mundo_nuevo")
		"history_toggle":
			dialogs.history_open = not dialogs.history_open
			_show_report()
		"decide":
			_resolve_decision(str(arg), false)


# ---------------------------------------------------------------------------------------------------------------------
# Final de la partida, parte y reintento

## Al terminar la partida se frena el reloj y, a los ~1,2 s, aparece el parte. `delayed` false lo muestra ya (QA y retirada).
func _check_end(delayed: bool) -> void:
	if rules == null or _ended:
		return
	var status := str(_rules_state().get("status", "playing"))
	if status == "playing":
		return
	_ended = true
	mode = "ended"
	paused = true
	_auto_resume = 0.0
	if orders != null:
		orders.cancel_aim()
	if progress != null and progress.has_method("record_result"):
		var rec: Variant = progress.call("record_result", rules)
		_rec = rec if rec is Dictionary else {}
	play_sound("victory" if status == "victory" else "defeat")
	_end_delay = END_DELAY_S if delayed else 0.0
	if not delayed:
		_show_report()


func _show_report() -> void:
	if dialogs == null or rules == null:
		return
	var rep: Variant = rules.call("campaign_report")
	var options: Array = progress.call("retry_options") if progress != null and progress.has_method("retry_options") else []
	if hud != null:
		hud.visible_root(false)  # el parte se lee solo, sin el HUD de la partida que terminó debajo
	dialogs.show_report(rep if rep is Dictionary else {}, _rec, options)


## Reintenta: `kind` es una de RETRY (posiciones, salida, mismo_mundo, mundo_nuevo). Sin briefing ni apertura: se juega enseguida (≤ 3 s).
func retry(kind: String) -> void:
	if rules == null:
		return
	var t0 := Time.get_ticks_msec()
	if dialogs != null:
		dialogs.close()
	if kind == "mundo_nuevo" and progress != null and progress.has_method("new_world"):
		progress.call("new_world")
	_attempt += 1
	_seed = _pick_seed()
	var restored := false
	if (kind == "posiciones" or kind == "salida") and progress != null and progress.has_method("restore_checkpoint"):
		_new_attempt({}, true)
		var res: Variant = progress.call("restore_checkpoint", rules, kind)
		restored = res is Dictionary and bool((res as Dictionary).get("ok", false))
	if not restored:
		_new_attempt({}, kind != "posiciones" and kind != "salida")
	mode = "play"
	paused = true
	_auto_start = not restored
	if hud != null:
		hud.visible_root(true)
	if restored:
		paused = false
	if is_instance_valid(view) and view.has_method("update_state"):
		view.call("update_state", 0.0)
	reset_camera()
	_refresh_hud(true)
	retry_ms = Time.get_ticks_msec() - t0


# ---------------------------------------------------------------------------------------------------------------------
# API de QA estable (contrato 3.5): ninguna prueba toca atributos privados de main ni del controlador
