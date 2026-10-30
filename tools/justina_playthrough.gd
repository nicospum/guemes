extends SceneTree
## Recorrido automatico de Justina sobre la escena real (main.tscn): inicia la partida, aplica una estrategia
## scripteada con las mismas ordenes publicas de Reglas, avanza con game._process y registra el desenlace
## (parte de campana, estado, tiempo). NO es una partida humana. Uso (APPDATA aislado):
##   godot --path . --script tools/justina_playthrough.gd [-- --out=res://evidence/justina-ui/recorrido.json]
## Las politicas clasicas son las estrategias de tests/test_rules.gd (mismas ordenes publicas de Reglas) sobre la escena real, con 3 semillas. La politica "ui_real" juega la partida con CLICS Y TECLAS
## REALES inyectados por el Viewport (botones del panel, roster, minimapa, clic derecho en el terreno) hasta la victoria.
var game: Node
var out_path := "user://justina-playthrough.json"
var mem := {}
var only_ui := false
var trace := false
var ui_seed := 1806

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_path = a.trim_prefix("--out=")
		elif a == "--only=ui":
			only_ui = true
		elif a == "--trace":
			trace = true
		elif a.begins_with("--ui-seed="):
			ui_seed = int(a.trim_prefix("--ui-seed="))
	call_deferred("_run")

const PLAY_POLICIES := ["rush_central", "central_flank_pair", "central_flank_lane", "central_hasty", "south_full", "mixed_split", "late_all_in"]
const PLAY_SEEDS := [1806, 7, 11]
const UI_SEEDS := [1806, 5, 11]

func _run() -> void:
	var results: Array = []
	for policy in ([] if only_ui else PLAY_POLICIES):
		for sd in PLAY_SEEDS:
			results.append(await _play(policy, sd))
	for sd in UI_SEEDS:
		ui_seed = sd
		results.append(await _play_ui())
	var wins := results.filter(func(r): return r.status == "victory")
	var ui_win: bool = results.any(func(r): return r.policy == "ui_real" and r.status == "victory")
	var routes := {}
	var styles := {}
	for r in wins:
		routes[r.route] = true
		styles[r.policy] = true
	var doc := {"kind": "scene_automation_not_human", "engine": Engine.get_version_info().string, "results": results,
		"victories": wins.size(), "victory_routes": routes.keys(), "victory_styles": styles.keys(), "defeats": results.filter(func(r): return r.status == "defeat").size(), "ui_real_victory": ui_win}
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "	"))
	f.close()
	print("PLAYTHROUGH ", JSON.stringify(doc))
	quit(0 if (styles.size() >= 3 and routes.size() >= 2 and doc.defeats >= 1 and ui_win) else 1)

func _play(policy: String, seed_value: int = 1806) -> Dictionary:
	var scene := load("res://scenes/main.tscn") as PackedScene
	game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.settings.auto_pause = false  # el guion avanza el tiempo por su cuenta y no espera la reanudacion manual
	game.jev.force_local = true
	game.forced_seed=1806
	game._start_game("justine")
	await process_frame
	if is_instance_valid(game.modal):
		game._close_modal()
	if seed_value != 1806:
		game.rules.new_game("justine", seed_value)
		game._rebuild_world()
	## El reloj lo lleva la politica (4 ticks de 0,25 s por paso, igual que en tests/test_rules.gd): con la escena en pausa los cuadros
	## intermedios no suman ticks extra que desalinearian las ordenes con el tiempo de juego (la matriz es sensible a eso).
	game.paused = true
	game.speed = 1
	mem = {}
	var r = game.rules
	var s := Sim.new()
	s.r = r
	s.cfg = _strategy_cfg(policy)
	var guard := 0
	while r.state.status == "playing" and guard < 6000:
		_policy_cfg(s)
		for k in range(4):
			r.tick(0.25)
			guard += 1
		s.t = float(r.state.elapsed)
		game._update_hud()
		if guard % 80 == 0:
			await process_frame
	game._process(0.1)
	await process_frame
	await process_frame
	var rep: Dictionary = r.campaign_report()
	var res := {"policy": policy, "seed": seed_value, "status": str(r.state.status), "t_s": snappedf(float(r.state.elapsed), 0.01), "route": str(rep.get("route", "")),
		"capture_pct": snappedf(float(r.state.capture), 0.1), "loss_pct": snappedf(float(rep.get("loss_total_pct", 0.0)), 0.1), "outcome_title": str(rep.get("outcome_title", "")),
		"report_modal_open": is_instance_valid(game.modal), "outcome_shown": game.outcome_shown, "stumbles": int(r.state.stats.stumbles)}
	game.queue_free()
	await process_frame
	return res

## Politicas copiadas de tests/test_rules.gd (seccion 6): mismas ordenes publicas de Reglas, ahora aplicadas sobre la escena real.

class Sim:
	var r: RefCounted
	var mem: Dictionary = {}
	var t := 0.0
	var cfg: Dictionary = {}

const GROUP_IDS := ["guemes", "arias", "zavala"]
const SEEDS := [3, 5, 7, 11, 13, 17, 19, 23]
## Carriles de reconocimiento (docs/DISENO_JUSTINA.md 1.2 y 10): el eje del banco central y un carril por cada flanco.
const PROBE_CENTER := [Vector2(250, 264), Vector2(334, 264)]
const PROBE_FLANK_N := [Vector2(250, 240), Vector2(362, 240)]
const PROBE_FLANK_S := [Vector2(250, 288), Vector2(362, 288)]
const LANE_N_WP := [Vector2(300, 240), Vector2(375, 240)]
const LANE_S_WP := [Vector2(300, 288), Vector2(375, 288)]
const PROBE_SOUTH_VADO := [Vector2(205, 400), Vector2(268, 402)]
const PROBE_SOUTH_BANK := [Vector2(268, 402), Vector2(342, 406), Vector2(392, 435)]
const MARK_SOUTH := [Vector2(230, 401), Vector2(255, 402)]
const NORTH_EDGE := [Vector2(330, 222), Vector2(480, 222)]
const STAGE_CENTRAL := Vector2(255, 264)
const STAGE_SOUTH := Vector2(255, 402)
const STAGE_SOUTH_EXIT := Vector2(318, 405)
const SOUTH_BOARD_WP := [Vector2(450, 455), Vector2(520, 440), Vector2(565, 390)]

func _central_common() -> Dictionary:
	return {"signal_t": 180.0, "resupply": true, "muster": 1, "stage": STAGE_CENTRAL, "stage_t": 260.0, "board_t": 330.0, "wait_probes": true, "wait_max": 330.0, "signal_on_go": true, "cover": true, "fire": true, "repel": true, "evac": true}

func _south_common() -> Dictionary:
	return {"signal_t": 290.0, "resupply": true, "muster": 1, "stage": STAGE_SOUTH, "stage_t": 220.0, "stage2": STAGE_SOUTH_EXIT, "stage2_t": 390.0, "stage2_wp": [Vector2(300, 403)], "board_t": 390.0, "wp": SOUTH_BOARD_WP, "wait_probes": true, "wait_max": 420.0, "signal_on_go": true, "fire": true, "cover": true, "repel": true, "evac": true,
		"mark_t": 150.0, "probes": [{"who": "scout_1", "t": 100.0, "pts": PROBE_SOUTH_VADO, "careful": false}]}

func _with(base: Dictionary, extra: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for k in extra:
		out[k] = extra[k]
	return out

func _strategy_cfg(name: String) -> Dictionary:
	var south_bank := {"who": "scout_1", "t": 355.0, "pts": PROBE_SOUTH_BANK, "careful": true, "after_found": "vado_sur"}
	match name:
		"rush_central":
			return {"signal_t": 0.0, "board_t": 0.0}
		"rush_gallop":
			return {"signal_t": 0.0, "board_t": 0.0, "pace": "gallop"}
		"blind_north_edge":
			return {"signal_t": 180.0, "resupply": true, "muster": 1, "stage": Vector2(255, 226), "stage_t": 200.0, "board_t": 340.0, "wp": NORTH_EDGE, "fire": true, "repel": true}
		"central_center_lane":
			return _with(_central_common(), {"probes": [{"who": "scout_1", "t": 250.0, "pts": PROBE_CENTER, "careful": true}]})
		"central_flank_lane":
			return _with(_central_common(), {"flank": true, "probes": [{"who": "scout_1", "t": 255.0, "pts": PROBE_FLANK_N, "careful": true}]})
		"central_flank_pair":
			return _with(_central_common(), {"flank": true, "probes": [{"who": "scout_1", "t": 255.0, "pts": PROBE_FLANK_N, "careful": true}, {"who": "scout_2", "t": 255.0, "pts": PROBE_FLANK_S, "careful": true}]})
		"central_hasty":
			return _with(_central_common(), {"flank": true, "cover": false, "probes": [{"who": "scout_1", "t": 250.0, "pts": PROBE_FLANK_N, "careful": false}], "wait_max": 120.0})
		"central_bare":
			return {"signal_on_go": true, "stage": STAGE_CENTRAL, "stage_t": 260.0, "board_t": 330.0, "flank": true, "wait_probes": true, "wait_max": 330.0, "probes": [{"who": "scout_1", "t": 250.0, "pts": PROBE_FLANK_N, "careful": true}]}
		"central_flank_stagger":
			return _with(_central_common(), {"flank": true, "stagger": 45.0, "probes": [{"who": "scout_1", "t": 255.0, "pts": PROBE_FLANK_N, "careful": true}]})
		"central_flank_noreply":
			return _with(_central_common(), {"flank": true, "repel": false, "evac": false, "probes": [{"who": "scout_1", "t": 255.0, "pts": PROBE_FLANK_N, "careful": true}]})
		"south_full":
			var c := _south_common()
			c.probes = [c.probes[0], south_bank]
			return c
		"south_vado_only":
			return _south_common()
		"south_bare":
			return {"signal_t": 290.0, "signal_on_go": true, "stage": STAGE_SOUTH, "stage_t": 220.0, "stage2": STAGE_SOUTH_EXIT, "stage2_t": 390.0, "stage2_wp": [Vector2(300, 403)], "board_t": 390.0, "wp": SOUTH_BOARD_WP, "wait_probes": true, "wait_max": 420.0, "mark_t": 150.0, "probes": [{"who": "scout_1", "t": 100.0, "pts": PROBE_SOUTH_VADO, "careful": false}]}
		"south_wrong_crossing":
			return {"signal_t": 150.0, "resupply": true, "muster": 1, "stage": Vector2(255, 360), "stage_t": 220.0, "board_t": 340.0, "wp": [Vector2(300, 360), Vector2(450, 455), Vector2(520, 440), Vector2(565, 390)], "fire": true, "repel": true}
		"south_noreply":
			var c2 := _south_common()
			c2.probes = [c2.probes[0], south_bank]
			c2.repel = false
			c2.evac = false
			return c2
		"mixed_split":
			var c3 := _south_common()
			c3.probes = [c3.probes[0], south_bank, {"who": "scout_2", "t": 255.0, "pts": PROBE_FLANK_N, "careful": true}]
			c3.split = true
			c3.cover = true
			return c3
		"late_all_in":
			return {"signal_t": 360.0, "resupply": true, "muster": 1, "board_t": 1000.0, "fire": true}
		"passive":
			return {}
	return {}

## Carril de los flancos del banco central segun lo que se descubrio: si el hoyo norte apareció, el sur es el firme (hay exactamente uno).
func _flank_wps(st: Dictionary) -> Array:
	return LANE_S_WP if "pozo_flanco_norte" in st.hazards_found else LANE_N_WP

func _probes_done(s: Sim) -> bool:
	var jobs: Array = s.cfg.get("probes", [])
	for ji in range(jobs.size()):
		if not s.mem.has("job_%d" % ji):
			return false
		var sc: Dictionary = s.r.get_scout(str(jobs[ji].who))
		if sc.stage in ["probing", "marking"]:
			return false
	return true

func _policy_cfg(s: Sim) -> void:
	var c: Dictionary = s.cfg
	var r: RefCounted = s.r
	var st: Dictionary = r.state
	var gu: Dictionary = r.get_unit("guemes")
	# reconocimiento: trabajos de sondeo (cada explorador toma el siguiente cuando queda libre)
	var jobs: Array = c.get("probes", [])
	for ji in range(jobs.size()):
		var job: Dictionary = jobs[ji]
		var key := "job_%d" % ji
		if s.mem.has(key) or s.t < float(job.t):
			continue
		var sc: Dictionary = r.get_scout(str(job.who))
		if sc.stage == "lost":
			s.mem[key] = -1.0
		elif sc.stage == "idle":
			if job.has("after_found") and not (str(job.after_found) in st.fords_found):
				continue
			var o: Dictionary = r.issue_scout(str(job.who), "probe", job.pts, {"cautious": bool(job.get("careful", false))})
			if o.ok:
				s.mem[key] = s.t
	## un explorador libre y al alcance del buque se repliega a la playa (no se queda esperando bajo el fuego)
	for sc3 in st.scouts:
		if sc3.stage == "idle" and r.exposure_at(float(sc3.x), float(sc3.z)) > 0.0:
			var pending := false
			for ji2 in range(jobs.size()):
				if str(jobs[ji2].who) == str(sc3.id) and not s.mem.has("job_%d" % ji2):
					pending = true
			if not pending:
				r.issue_scout(str(sc3.id), "recall", [])
	if c.has("mark_t") and s.t >= float(c.mark_t) and not s.mem.has("mark_south") and "vado_sur" in st.fords_found and r.get_scout("scout_2").stage == "idle":
		s.mem.mark_south = r.issue_scout("scout_2", "mark_ford", MARK_SOUTH).ok
	if c.get("cover", false):
		for sc2 in st.scouts:
			if sc2.stage == "probing" and r.exposure_at(float(sc2.x), float(sc2.z)) > 0.0:
				if r.call_fire_support().ok:
					s.mem.fire_uses = int(s.mem.get("fire_uses", 0)) + 1
	# condicion de salida
	var ready_go: bool = s.t >= float(c.get("board_t", 1.0e9))
	if ready_go and c.get("wait_probes", false):
		ready_go = _probes_done(s) or s.t >= float(c.board_t) + float(c.get("wait_max", 200.0))
	# Liniers: se señala una vez; se repite si venció y todavía no se cargó.
	var want_signal: bool = false
	var sig_n := int(s.mem.get("sig_n", 0))
	if c.has("signal_t"):
		want_signal = s.t >= float(c.signal_t) and (sig_n == 0 or not c.get("signal_on_go", false))
	if c.get("signal_on_go", false) and ready_go and (sig_n == 0 or s.t > float(c.get("board_t", 0.0))):
		want_signal = true
	if want_signal and gu.stage == "ready" and not bool(st.advance_authorized) and (not s.mem.has("board_guemes") or sig_n < 2) and int(st.signals_left) > 0 and (sig_n == 0 or s.t > float(c.get("board_t", 0.0))):
		if not s.mem.has("signal_wait") or s.t >= float(s.mem.signal_wait):
			if r.issue_order("guemes", "signal_liniers").ok:
				s.mem.signal_wait = s.t + 20.0
				s.mem.sig_n = sig_n + 1
	var zv: Dictionary = r.get_unit("zavala")
	if c.get("resupply", false) and s.t >= float(c.get("resupply_t", 150.0)) and zv.stage == "ready" and int(s.mem.get("muster_zavala", 0)) >= int(c.get("muster", 0)) and not s.mem.has("resupply") and int(st.ammo) < 30 and int(st.ammo_reserve) > 0 and not s.mem.has("boarded_any"):
		if r.issue_order("zavala", "resupply").ok:
			s.mem.resupply = true
	# reunir jinetes
	var rounds := int(c.get("muster", 0))
	if rounds > 0:
		for id in ["arias", "zavala"]:
			var u: Dictionary = r.get_unit(id)
			var k: String = "muster_" + id
			if u.stage == "ready" and int(s.mem.get(k, 0)) < rounds and float(u.strength) < 99.0 and float(st.volunteers_pool) > 0.0 and int(st.ammo) >= 4 and not s.mem.has("boarded_any"):
				if r.issue_order(id, "muster").ok:
					s.mem[k] = int(s.mem.get(k, 0)) + 1
	# puesta en posicion
	if c.has("stage") and s.t >= float(c.stage_t) and not s.mem.has("boarded_any"):
		var i := 0
		for id in GROUP_IDS:
			var key2: String = "stage_" + id
			var ug: Dictionary = r.get_unit(id)
			var p: Vector2 = c.stage
			if c.get("split", false) and id == "guemes":
				p = Vector2(255, 250)
			if not s.mem.has(key2) and ug.stage == "ready":
				if r.issue_order(id, "move", p + Vector2(0, (i - 1) * 8.0), {"pace": "trot"}).ok:
					s.mem[key2] = true
			i += 1
	# segunda posicion (cruzar el vado ya descubierto hasta su salida mientras se sondea el banco)
	if c.has("stage2") and s.t >= float(c.stage2_t) and not s.mem.has("boarded_any") and "vado_sur" in st.fords_found:
		var j := 0
		for id in GROUP_IDS:
			var key4: String = "stage2_" + id
			var ug2: Dictionary = r.get_unit(id)
			if c.get("split", false) and id == "guemes":
				j += 1
				continue
			if not s.mem.has(key4) and ug2.stage == "ready":
				if r.issue_order(id, "move", (c.stage2 as Vector2) + Vector2(0, (j - 1) * 6.0), {"pace": "trot", "waypoints": c.get("stage2_wp", [])}).ok:
					s.mem[key4] = true
			j += 1
	# abordaje
	var go: bool = ready_go and bool(st.advance_authorized)
	if go:
		if not s.mem.has("go_t"):
			s.mem.go_t = s.t
		var i2 := 0
		for id in (["arias", "zavala", "guemes"] if c.has("stagger") else GROUP_IDS):
			var u2: Dictionary = r.get_unit(id)
			var key3: String = "board_" + id
			var ready_t := float(s.mem.go_t) + float(c.get("stagger", 0.0)) * float(i2)
			i2 += 1
			if s.mem.has(key3) and u2.stage == "ready" and float(u2.strength) > 5.0 and s.t > float(s.mem[key3]) + 5.0 and u2.mounted:
				s.mem.erase(key3)  ## la orden venció y el grupo se detuvo: se vuelve a dar con la nueva señal
			if s.mem.has(key3) or u2.stage != "ready" or s.t < ready_t:
				continue
			var wps: Array = []
			if c.has("wp"):
				wps = c.wp
			elif c.get("flank", false):
				wps = _flank_wps(st)
			if c.get("split", false):
				wps = _flank_wps(st) if id == "guemes" else SOUTH_BOARD_WP
				if id != "guemes" and not ("vado_sur" in st.fords_found):
					continue
			var o2: Dictionary = r.issue_order(id, "board", Vector2.ZERO, {"pace": str(c.get("pace", "trot")), "waypoints": wps})
			if o2.ok:
				s.mem[key3] = s.t
				s.mem.boarded_any = true
	# fuego
	if c.get("fire", false):
		var exposed := false
		for u3 in st.units:
			if r.exposure_at(float(u3.x), float(u3.z)) > 0.0 and u3.stage in ["moving", "dismounting", "boarding"]:
				exposed = true
		if exposed and r.call_fire_support().ok:
			s.mem.fire_uses = int(s.mem.get("fire_uses", 0)) + 1
	# cubierta: rechazar el contraataque y evacuar heridos
	if c.get("repel", false) and bool(st.counter.active) and not bool(st.counter.answered):
		var best: Dictionary = {}
		for u4 in st.units:
			if u4.stage == "boarding" and (best.is_empty() or float(u4.strength) > float(best.strength)):
				best = u4
		if not best.is_empty() and r.issue_order(str(best.id), "repel").ok:
			s.mem.repels = int(s.mem.get("repels", 0)) + 1
	if c.get("evac", false):
		var boarding_n := 0
		for u5 in st.units:
			if u5.stage == "boarding":
				boarding_n += 1
		for u5 in st.units:
			if u5.stage == "boarding" and boarding_n >= 2 and float(u5.wounded) >= 8.0 and float(u5.evac_remaining) <= 0.0 and not bool(st.counter.active):
				if r.issue_order(str(u5.id), "evacuate").ok:
					s.mem.evacs = int(s.mem.get("evacs", 0)) + 1
					break


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
	if trace:
		print("    [ui] ", part, " -> sel=", game.sel_ids, " toast=", game.toast_label.text.replace("
", " "))
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
	## Avanza el tiempo del juego por su propio _process a la velocidad elegida con el boton. Entre pasos la escena queda en pausa: los
	## cuadros que consumen los clics y las teclas no suman ticks, asi la partida es reproducible (no hay reflejos humanos que simular).
	var left := seconds
	game.paused = false
	while left > 0.0 and game.rules.state.status == "playing":
		var dt := 0.25
		game._process(dt)
		left -= dt * float(game.speed)
	game.paused = true

func _play_ui() -> Dictionary:
	var scene := load("res://scenes/main.tscn") as PackedScene
	game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.settings.auto_pause = false  # el guion avanza el tiempo por su cuenta y no espera la reanudacion manual
	game.jev.force_local = true
	ui_log = []
	clicks = 0
	await _click_at(_find_btn("EL RÍO").get_global_rect().get_center())
	for i in range(30):
		await process_frame
	var r = game.rules
	if is_instance_valid(game.modal):
		await _press("Entendido", "leer la ayuda y abrir el despliegue previo")
		await _press("Empezar a ordenar", "cerrar el despliegue previo (sigue en pausa)")
	mem = {}
	if ui_seed != 1806:
		# Otra semilla (fondo oculto distinto) con la escena ya armada; toda la partida sigue siendo por clics y teclas.
		r.new_game("justine", ui_seed)
		game._rebuild_world()
		game._refresh_minimap()
	# Tiempo: Iniciar y velocidad x4 con los botones de la cabecera.
	await _press("Iniciar", "arrancar el tiempo")
	await _press("×2", "velocidad x2")
	game.paused = true
	var guard := 0
	while r.state.status == "playing" and guard < 1500:
		guard += 1
		var t := float(r.state.elapsed)
		await _ui_step(r, t)
		if trace and int(t) % 30 == 0 and int(t) != int(mem.get("trace_t", -1)):
			mem.trace_t = int(t)
			var line := ""
			for u in r.state.units:
				line += " %s[%s %.0f,%.0f s=%.0f f=%.0f w=%.0f]" % [u.id, u.stage, u.x, u.z, u.strength, u.fatigue, u.wounded]
			for sc in r.state.scouts:
				line += " %s[%s %.0f,%.0f hp%d]" % [sc.id, sc.stage, sc.x, sc.z, sc.hp]
			print("  t=%d cap=%.1f ammo=%d sig=%d auth=%s%s" % [int(t), r.state.capture, r.state.ammo, int(r.state.signals_left), str(r.state.advance_authorized), line])
		await _advance(1.0)
	game._process(0.1)
	for i in range(3):
		await process_frame
	var rep: Dictionary = r.campaign_report()
	var res := {"policy": "ui_real", "seed": ui_seed, "status": str(r.state.status), "t_s": snappedf(float(r.state.elapsed), 0.01), "route": str(rep.get("route", "")),
		"capture_pct": snappedf(float(r.state.capture), 0.1), "outcome_title": str(rep.get("outcome_title", "")), "report_modal_open": is_instance_valid(game.modal),
		"outcome_shown": game.outcome_shown, "stumbles": int(r.state.stats.stumbles), "loss_pct": snappedf(float(rep.get("loss_total_pct", 0.0)), 0.1), "boarded_at": snappedf(float(r.state.stats.boarded_at), 0.1), "defeat_cause": str(r.state.defeat_cause), "ui_inputs": clicks, "ui_log": ui_log.slice(0, 40)}
	game.queue_free()
	await process_frame
	return res

func _ready_all(r, ids: Array) -> bool:
	for id in ids:
		if r.get_unit(id).stage != "ready":
			return false
	return true

func _ui_probe(key: Key, pts: Array) -> bool:
	## Explorador (tecla 4 o 5) + boton "Sondeo cauteloso" + clics en el terreno (Mayus para sumar punto, el ultimo confirma).
	await _key(key)
	if not await _press("Sondeo cauteloso", "reconocer el fondo con cautela"):
		return false
	for i in range(pts.size()):
		if not await _right_click_world(pts[i], i < pts.size() - 1):
			await _key(KEY_ESCAPE)
			return false
	return true

func _ui_move(id: String, pts: Array) -> bool:
	## Un solo grupo (tecla 1-3), waypoints con Mayus + clic derecho en el terreno y Enter: cada grupo sigue su propio carril
	## (con varios grupos seleccionados la formacion los abre y se salen del carril sondeado).
	await _select_groups([id])
	for p in pts:
		if not await _right_click_world(p, true):
			await _key(KEY_ESCAPE)
			return false
	await _key(KEY_ENTER)
	return true

func _ui_step(r, t: float) -> void:
	## Misma estrategia que central_flank_pair de tests/test_rules.gd, pero con teclas, botones y clics reales:
	## reunir, abastecer, señalar a Liniers, dos sondeos cautelosos por los carriles de los flancos, fuego de distraccion,
	## puesta en posicion, ruta por el carril firme, abordaje, rechazar el contraataque y evacuar heridos.
	if is_instance_valid(game.modal):
		await _press("Cerrar · Esc", "cerrar un panel")
		return
	var st: Dictionary = r.state
	var boarded: bool = mem.has("boarded_any")
	# fuego de distraccion: un explorador sondeando o un grupo avanzando bajo el alcance del buque
	var exposed := false
	for sc in st.scouts:
		if sc.stage == "probing" and r.exposure_at(float(sc.x), float(sc.z)) > 0.0:
			exposed = true
	for u in st.units:
		if r.exposure_at(float(u.x), float(u.z)) > 0.0 and u.stage in ["moving", "dismounting", "boarding"]:
			exposed = true
	if exposed and float((st.get("fire_support", {}) as Dictionary).get("ready_at", 0.0)) <= t and t >= float(mem.get("fire_wait", 0.0)):
		mem.fire_wait = t + 12.0
		if await _press("Distraer con fuego", "fuego de distraccion"):
			return
	# cubierta: rechazar el contraataque y evacuar heridos
	if bool(st.counter.active) and not bool(st.counter.answered):
		var best: Dictionary = {}
		for u in st.units:
			if u.stage == "boarding" and (best.is_empty() or float(u.strength) > float(best.strength)):
				best = u
		if not best.is_empty():
			await _select_groups([str(best.id)])
			if await _press("Rechazar", "rechazar el contraataque"):
				return
	var boarding_n := 0
	for u in st.units:
		if u.stage == "boarding":
			boarding_n += 1
	for u in st.units:
		if u.stage == "boarding" and boarding_n >= 2 and float(u.wounded) >= 8.0 and float(u.evac_remaining) <= 0.0 and not bool(st.counter.active):
			await _select_groups([str(u.id)])
			if await _press("Evacuar heridos", "evacuar heridos"):
				return
	if boarded:
		return
	# reunir jinetes (una ronda) y abastecer
	if not mem.has("muster0") and _ready_all(r, ["arias", "zavala"]) and int(st.ammo) >= 4 and float(st.volunteers_pool) > 0.0:
		await _select_groups(["arias", "zavala"])
		if await _press("Reunir", "reunir jinetes"):
			mem.muster0 = true
		return
	if t >= 150.0 and not mem.has("resupply") and mem.has("muster0") and r.get_unit("zavala").stage == "ready" and int(st.ammo) < 30 and int(st.ammo_reserve) > 0:
		await _select_groups(["zavala"])
		if await _press("Abastecer", "reponer munición"):
			mem.resupply = true
		return
	# señalar a Liniers (a los 180 s y de nuevo al partir si la orden venció)
	var want_signal: bool = (t >= 180.0 and int(mem.get("sig_n", 0)) == 0) or (t >= 330.0 and mem.has("probes_done") and not bool(st.advance_authorized))
	if want_signal and not bool(st.advance_authorized) and r.get_unit("guemes").stage == "ready" and int(st.signals_left) > 0 and t >= float(mem.get("sig_wait", 0.0)):
		await _select_groups(["guemes"])
		if await _press("Señalar a Liniers", "dar la orden de avance"):
			mem.sig_n = int(mem.get("sig_n", 0)) + 1
			mem.sig_wait = t + 20.0
		return
	# dos sondeos cautelosos por los carriles de los flancos del banco central
	if t >= 255.0 and not mem.has("probe_n") and r.get_scout("scout_1").stage == "idle":
		mem.probe_n = await _ui_probe(KEY_4, [Vector2(250, 240), Vector2(362, 240)])
		ui_log.append("%d s: sondeo cauteloso del carril norte con el explorador 1" % int(t))
		return
	if t >= 255.0 and not mem.has("probe_s") and r.get_scout("scout_2").stage == "idle":
		mem.probe_s = await _ui_probe(KEY_5, [Vector2(250, 288), Vector2(362, 288)])
		ui_log.append("%d s: sondeo cauteloso del carril sur con el explorador 2" % int(t))
		return
	if mem.has("probe_n") and mem.has("probe_s") and not mem.has("probes_done"):
		var busy := false
		for sc in st.scouts:
			if sc.stage in ["probing", "marking"]:
				busy = true
		if not busy:
			mem.probes_done = true
	# puesta en posicion en el eje del banco central (cada grupo a su fila, como en la matriz de Reglas)
	if t >= 260.0:
		var gi := 0
		for id in ["guemes", "arias", "zavala"]:
			if not mem.has("stage_" + id) and r.get_unit(id).stage == "ready":
				var pos := Vector2(255, 264 + (gi - 1) * 8)
				mem["stage_" + id] = await _ui_move(id, [pos])
				ui_log.append("%d s: %s a la posicion (%d, %d)" % [int(t), id, int(pos.x), int(pos.y)])
				return
			gi += 1
	# salida: con los sondeos terminados (o vencido el plazo) y la orden de avance vigente
	var go: bool = t >= 330.0 and (mem.has("probes_done") or t >= 660.0) and bool(st.advance_authorized)
	if go and not mem.has("route"):
		var lane: Array = [Vector2(300, 288), Vector2(375, 288)] if "pozo_flanco_norte" in st.hazards_found else [Vector2(300, 240), Vector2(375, 240)]
		for id in ["guemes", "arias", "zavala"]:
			if not mem.has("lane_" + id) and r.get_unit(id).stage == "ready":
				mem["lane_" + id] = await _ui_move(id, lane)
				ui_log.append("%d s: %s por el carril firme (dos waypoints y Enter)" % [int(t), id])
				return
		if mem.has("lane_guemes") and mem.has("lane_arias") and mem.has("lane_zavala"):
			mem.route = true
		return
	if go and mem.has("route") and not boarded and _ready_all(r, ["guemes", "arias", "zavala"]):
		await _select_groups(["guemes", "arias", "zavala"])
		await _press("Cargar y abordar", "abordar")
		await _press("Cargar y abordar", "confirmar el tramo sin reconocer")
		if r.get_unit("guemes").order.get("action", "") == "board":
			mem.boarded_any = true
		return
