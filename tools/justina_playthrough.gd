extends SceneTree
## Recorrido automatico de Justina sobre la escena real (main.tscn): inicia la partida, aplica una estrategia
## scripteada con las mismas ordenes publicas de Reglas, avanza con game._process y registra el desenlace
## (parte de campana, estado, tiempo). NO es una partida humana. Uso (APPDATA aislado):
##   godot --path . --script tools/justina_playthrough.gd [-- --out=res://evidence/justina-ui/recorrido.json]
## Las cinco politicas clasicas usan las ordenes publicas de Reglas. La politica "ui_real" juega la partida con CLICS Y TECLAS
## REALES inyectados por el Viewport (botones del panel, roster, minimapa, clic derecho en el terreno) hasta la victoria.
const SOUTH_WAYPOINTS := [Vector2(305, 403), Vector2(450, 455), Vector2(520, 440), Vector2(565, 390)]
var game: Node
var out_path := "user://justina-playthrough.json"
var mem := {}
var only_ui := false

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_path = a.trim_prefix("--out=")
		elif a == "--only=ui":
			only_ui = true
	call_deferred("_run")

func _run() -> void:
	var results: Array = []
	for policy in ([] if only_ui else ["rush_central", "north_edge_central", "recon_south", "mixed", "late"]):
		results.append(await _play(policy))
	results.append(await _play_ui())
	var wins := results.filter(func(r): return r.status == "victory")
	var ui_win: bool = results.any(func(r): return r.policy == "ui_real" and r.status == "victory")
	var routes := {}
	for r in wins:
		routes[r.route] = true
	var doc := {"kind": "scene_automation_not_human", "engine": Engine.get_version_info().string, "results": results,
		"victories": wins.size(), "victory_routes": routes.keys(), "defeats": results.filter(func(r): return r.status == "defeat").size(), "ui_real_victory": ui_win}
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "\t"))
	f.close()
	print("PLAYTHROUGH ", JSON.stringify(doc))
	quit(0 if (wins.size() >= 2 and routes.size() >= 2 and doc.defeats >= 1 and ui_win) else 1)

func _play(policy: String) -> Dictionary:
	var scene := load("res://scenes/main.tscn") as PackedScene
	game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.jev.force_local = true
	game._start_game("justine")
	await process_frame
	if is_instance_valid(game.modal):
		game._close_modal()
	game.paused = false
	game.speed = 1
	mem = {}
	var r = game.rules
	var guard := 0
	while r.state.status == "playing" and guard < 5000:
		call("_policy_" + policy, r)
		for k in range(4):
			r.tick(0.25)
			guard += 1
		game._update_hud()
		if guard % 80 == 0:
			await process_frame
	game._process(0.1)
	await process_frame
	await process_frame
	var rep: Dictionary = r.campaign_report()
	var res := {"policy": policy, "status": str(r.state.status), "t_s": snappedf(float(r.state.elapsed), 0.01), "route": str(rep.get("route", "")),
		"capture_pct": snappedf(float(r.state.capture), 0.1), "outcome_title": str(rep.get("outcome_title", "")), "report_modal_open": is_instance_valid(game.modal),
		"outcome_shown": game.outcome_shown, "stumbles": int(r.state.stats.stumbles)}
	game.queue_free()
	await process_frame
	return res

func _signal_and_resupply(r) -> void:
	if not mem.has("signal"):
		mem.signal = r.issue_order("guemes", "signal_liniers").ok
	if r.state.advance_authorized and r.get_unit("guemes").stage == "ready" and not mem.has("resupply") and int(r.state.ammo) < 36:
		mem.resupply = r.issue_order("guemes", "resupply").ok

func _muster_both(r) -> void:
	var t := float(r.state.elapsed)
	for round_i in range(2):
		var key: String = "muster%d" % round_i
		if mem.has(key):
			continue
		var ready := true
		for id in ["arias", "zavala"]:
			ready = ready and r.get_unit(id).stage == "ready"
		if round_i == 1 and not mem.has("muster0"):
			continue
		if ready and (round_i == 0 or t >= 100.0):
			mem[key] = r.issue_order("arias", "muster").ok and r.issue_order("zavala", "muster").ok
			break

func _greedy_fire(r) -> void:
	for u in r.state.units:
		if r.exposure_at(float(u.x), float(u.z)) > 0.0 and u.stage == "moving":
			if r.call_fire_support().ok:
				return

func _stage(r, point: Vector2, from_t: float, spacing: float) -> void:
	if float(r.state.elapsed) < from_t:
		return
	var i := 0
	for id in ["guemes", "arias", "zavala"]:
		var key: String = "stage_" + id
		if not mem.has(key) and r.get_unit(id).stage == "ready":
			mem[key] = r.issue_order(id, "move", point + Vector2(0, (i - 1) * spacing), {"pace": "trot"}).ok
		i += 1

func _board(r, id: String, wps: Array = []) -> void:
	var key: String = "board_" + id
	if mem.has(key) or not r.state.advance_authorized or r.get_unit(id).stage != "ready":
		return
	if r.issue_order(id, "board", Vector2.ZERO, {"pace": "trot", "waypoints": wps}).ok:
		mem[key] = true

func _policy_rush_central(r) -> void:
	_signal_and_resupply(r)
	for id in ["arias", "zavala", "guemes"]:
		_board(r, id)

func _policy_north_edge_central(r) -> void:
	_signal_and_resupply(r)
	_muster_both(r)
	_stage(r, Vector2(255, 244), 180.0, 14.0)
	for id in ["guemes", "arias", "zavala"]:
		_board(r, id, [Vector2(330, 240), Vector2(480, 240)])
	_greedy_fire(r)

func _policy_recon_south(r) -> void:
	_signal_and_resupply(r)
	_muster_both(r)
	var t := float(r.state.elapsed)
	if t >= 150.0 and not mem.has("scout"):
		mem.scout = r.issue_scout("scout_1", "probe", [Vector2(205, 400), Vector2(268, 402)]).ok
	if t >= 270.0 and not mem.has("mark"):
		mem.mark = r.issue_scout("scout_2", "mark_ford", [Vector2(230, 401), Vector2(255, 402)]).ok
	_stage(r, Vector2(255, 402), 150.0, 1.0)
	if "vado_sur" in r.state.fords_found:
		for id in ["guemes", "arias", "zavala"]:
			_board(r, id, SOUTH_WAYPOINTS)
	_greedy_fire(r)

func _policy_mixed(r) -> void:
	_signal_and_resupply(r)
	_muster_both(r)
	var t := float(r.state.elapsed)
	if t >= 150.0 and not mem.has("scout"):
		mem.scout = r.issue_scout("scout_1", "probe", [Vector2(205, 400), Vector2(268, 402)]).ok
	if t >= 150.0 and not mem.has("stage"):
		var g: bool = r.issue_order("guemes", "move", Vector2(255, 244), {"pace": "trot"}).ok
		var a: bool = r.issue_order("arias", "move", Vector2(255, 400), {"pace": "trot"}).ok
		var z: bool = r.issue_order("zavala", "move", Vector2(255, 403), {"pace": "trot"}).ok
		mem.stage = g and a and z
	_board(r, "guemes", [Vector2(330, 240), Vector2(480, 240)])
	if "vado_sur" in r.state.fords_found:
		for id in ["arias", "zavala"]:
			_board(r, id, SOUTH_WAYPOINTS)
	_greedy_fire(r)

func _policy_late(r) -> void:
	_signal_and_resupply(r)
	if float(r.state.elapsed) >= 690.0:
		for id in ["arias", "zavala", "guemes"]:
			_board(r, id)


# ----------------------------------------------------------------------------- entrada real de interfaz
var ui_log: Array = []
var clicks := 0

func _to_win(pos: Vector2) -> Vector2:
	return root.get_final_transform() * pos

func _mouse_event(pos: Vector2, button: int, pressed: bool, shift := false) -> void:
	var e := InputEventMouseButton.new()
	e.position = _to_win(pos)
	e.global_position = e.position
	e.button_index = button
	e.pressed = pressed
	e.shift_pressed = shift
	e.button_mask = (1 << (button - 1)) if pressed else 0
	root.push_input(e)

func _click_at(pos: Vector2, button := MOUSE_BUTTON_LEFT, shift := false) -> void:
	var m := InputEventMouseMotion.new()
	m.position = _to_win(pos)
	m.global_position = m.position
	root.push_input(m)
	await process_frame
	_mouse_event(pos, button, true, shift)
	await process_frame
	_mouse_event(pos, button, false, shift)
	await process_frame
	clicks += 1

func _key(code: Key, shift := false) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		e.shift_pressed = shift
		root.push_input(e)
		await process_frame
	clicks += 1

func _find_btn(part: String) -> Button:
	for b in game.find_children("*", "Button", true, false):
		if b is Button and part in b.text and b.is_visible_in_tree():
			return b
	return null

func _press(part: String, why: String) -> bool:
	var b := _find_btn(part)
	if b == null or b.disabled:
		return false
	await _click_at(b.get_global_rect().get_center())
	ui_log.append("%d s: clic en «%s» (%s)" % [int(game.rules.state.elapsed), part, why])
	return true

func _minimap_click(world_pt: Vector2) -> void:
	var mr: Rect2 = game.minimap_rect()
	var sz: Vector2 = game.rules.map_size()
	await _click_at(mr.position + Vector2(world_pt.x / sz.x * mr.size.x, world_pt.y / sz.y * mr.size.y))

func _screen_of(p: Vector2) -> Vector2:
	return game.camera.unproject_position(Vector3(p.x, game._ground_y(p.x, p.y), p.y))

func _right_click_world(p: Vector2, shift := false) -> bool:
	await _minimap_click(p)
	for i in range(4):
		await process_frame
	var sp := _screen_of(p)
	var view: Rect2 = Rect2(Vector2(20, 70), root.get_visible_rect().size - Vector2(40, 260))
	if not view.has_point(sp):
		return false
	await _click_at(sp, MOUSE_BUTTON_RIGHT, shift)
	return true

func _select_groups(ids: Array) -> void:
	var first := true
	for id in ids:
		var code: Key = KEY_1 + ["guemes", "arias", "zavala"].find(id)
		await _key(code, not first)
		first = false

func _advance(seconds: float) -> void:
	# Avanza el tiempo del juego por su propio _process (a la velocidad elegida con el boton), sin saltarse la interfaz.
	var left := seconds
	var n := 0
	while left > 0.0 and game.rules.state.status == "playing":
		var dt := 0.25
		game._process(dt)
		left -= dt * float(game.speed)
		n += 1
		if n % 6 == 0:
			await process_frame

func _play_ui() -> Dictionary:
	var scene := load("res://scenes/main.tscn") as PackedScene
	game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.jev.force_local = true
	ui_log = []
	clicks = 0
	await _click_at(_find_btn("EL RÍO").get_global_rect().get_center())
	for i in range(30):
		await process_frame
	var r = game.rules
	if is_instance_valid(game.modal):
		await _press("Entendido", "cerrar el briefing")
	mem = {}
	# Tiempo: Iniciar y velocidad x4 con los botones de la cabecera.
	await _press("Iniciar", "arrancar el tiempo")
	await _press("1×", "velocidad x2")
	await _press("2×", "velocidad x4")
	var guard := 0
	while r.state.status == "playing" and guard < 1500:
		guard += 1
		var t := float(r.state.elapsed)
		await _ui_step(r, t)
		await _advance(1.0)
	game._process(0.1)
	for i in range(3):
		await process_frame
	var rep: Dictionary = r.campaign_report()
	var res := {"policy": "ui_real", "status": str(r.state.status), "t_s": snappedf(float(r.state.elapsed), 0.01), "route": str(rep.get("route", "")),
		"capture_pct": snappedf(float(r.state.capture), 0.1), "outcome_title": str(rep.get("outcome_title", "")), "report_modal_open": is_instance_valid(game.modal),
		"outcome_shown": game.outcome_shown, "stumbles": int(r.state.stats.stumbles), "ui_inputs": clicks, "ui_log": ui_log.slice(0, 40)}
	game.queue_free()
	await process_frame
	return res

func _ready_all(r, ids: Array) -> bool:
	for id in ids:
		if r.get_unit(id).stage != "ready":
			return false
	return true

func _ui_step(r, t: float) -> void:
	if is_instance_valid(game.modal):
		await _press("Cerrar", "cerrar un panel")
		return
	# 1) Guemes: señalar a Liniers y abastecer
	if not mem.has("signal") and r.get_unit("guemes").stage == "ready":
		await _select_groups(["guemes"])
		if await _press("Señalar a Liniers", "dar la orden de avance"):
			mem.signal = true
		return
	if mem.has("signal") and not mem.has("resupply") and r.state.advance_authorized and r.get_unit("guemes").stage == "ready" and int(r.state.ammo) < 36:
		await _select_groups(["guemes"])
		if await _press("Abastecer", "reponer munición"):
			mem.resupply = true
		return
	# 2) Arias y Zavala: reunir voluntarios dos veces
	for round_i in range(2):
		var key := "muster%d" % round_i
		if mem.has(key) or (round_i == 1 and not mem.has("muster0")):
			continue
		if _ready_all(r, ["arias", "zavala"]) and (round_i == 0 or t >= 100.0):
			await _select_groups(["arias", "zavala"])
			if await _press("Reunir", "reunir jinetes"):
				mem[key] = true
			return
	# 3) Tras 180 s: concentrar en la barranca norte con clic derecho en el terreno
	if t >= 180.0 and not mem.has("stage") and _ready_all(r, ["guemes", "arias", "zavala"]):
		await _select_groups(["guemes", "arias", "zavala"])
		if await _right_click_world(Vector2(255, 244)):
			mem.stage = true
			ui_log.append("%d s: clic derecho en el terreno (255, 244)" % int(t))
		return
	# 4) Ruta por el borde norte: dos puntos con Mayús, Enter confirma; luego Cargar y abordar
	if mem.has("stage") and not mem.has("route") and _ready_all(r, ["guemes", "arias", "zavala"]) and r.state.advance_authorized:
		await _select_groups(["guemes", "arias", "zavala"])
		if await _right_click_world(Vector2(330, 240), true) and await _right_click_world(Vector2(480, 240), true):
			await _key(KEY_ENTER)
			mem.route = true
			ui_log.append("%d s: ruta con dos waypoints y Enter" % int(t))
		return
	if mem.has("route") and not mem.has("board") and _ready_all(r, ["guemes", "arias", "zavala"]):
		await _select_groups(["guemes", "arias", "zavala"])
		await _press("Cargar y abordar", "abordar")
		await _press("Cargar y abordar", "confirmar el tramo sin reconocer")
		if r.get_unit("guemes").order.get("action", "") == "board":
			mem.board = true
		return
	# 5) Fuego de distracción cuando alguien avanza bajo fuego
	if mem.has("route") and not mem.has("fire_" + str(int(t / 60.0))):
		for u in r.state.units:
			if u.stage == "moving" and r.exposure_at(float(u.x), float(u.z)) > 0.0:
				if await _press("Distraer", "fuego de distracción"):
					mem["fire_" + str(int(t / 60.0))] = true
				return
