extends SceneTree
## Recorrido automatico de Justina sobre la escena real (main.tscn): inicia la partida, aplica una estrategia
## scripteada con las mismas ordenes publicas de Reglas, avanza con game._process y registra el desenlace
## (parte de campana, estado, tiempo). NO es una partida humana. Uso (APPDATA aislado):
##   godot --path . --script tools/justina_playthrough.gd [-- --out=res://evidence/justina-ui/recorrido.json]
const SOUTH_WAYPOINTS := [Vector2(305, 403), Vector2(450, 455), Vector2(520, 440), Vector2(565, 390)]
var game: Node
var out_path := "user://justina-playthrough.json"
var mem := {}

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_path = a.trim_prefix("--out=")
	call_deferred("_run")

func _run() -> void:
	var results: Array = []
	for policy in ["rush_central", "north_edge_central", "recon_south", "mixed", "late"]:
		results.append(await _play(policy))
	var wins := results.filter(func(r): return r.status == "victory")
	var routes := {}
	for r in wins:
		routes[r.route] = true
	var doc := {"kind": "scene_automation_not_human", "engine": Engine.get_version_info().string, "results": results,
		"victories": wins.size(), "victory_routes": routes.keys(), "defeats": results.filter(func(r): return r.status == "defeat").size()}
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "\t"))
	f.close()
	print("PLAYTHROUGH ", JSON.stringify(doc))
	quit(0 if (wins.size() >= 2 and routes.size() >= 2 and doc.defeats >= 1) else 1)

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
