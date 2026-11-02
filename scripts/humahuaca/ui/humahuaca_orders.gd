extends RefCounted
## Órdenes del jugador (CONTRATO 3.5): la barra de acciones contextual, el modo apuntado, la vista previa de la ruta y el clic derecho. No decide
## nada de juego: pregunta a las reglas (list_actions, action_availability, plan_route, plan_recon) y manda issue_order. Los textos salen de
## humahuaca_ui.json y de los motivos que devuelven las reglas.
##   · Las acciones sin objetivo (A su puesto, Atacar, Cargar, Destruir, Salir, Dar la señal) se ejecutan con un clic o una tecla.
##   · Las que piden un punto (Mover, Reconocer) o un frente (Socorrer) entran en modo apuntado: se muestra la vista previa sin efectos y el
##     siguiente clic izquierdo confirma (Mayús suma una parada, hasta 4). Esc cancela.
##   · El clic derecho da la orden más lógica a lo que está bajo el cursor.

const U = preload("res://scripts/humahuaca/ui/vocab_ui.gd")
const V = preload("res://scripts/humahuaca/humahuaca_vocab.gd")
const Kit = preload("res://scripts/humahuaca/ui/humahuaca_ui_kit.gd")

const MAX_STOPS := 4
const PREVIEW_PERIOD := 0.08

## El controlador (Node): dueño de la selección, las reglas, la vista y los textos. Se usa por nombre, sin tipar.
var ui: Node = null

var aim: Dictionary = {}
var pace := "march"
var waypoints: Array = []
var plan: Dictionary = {}
var target_now := Vector2.ZERO
var has_target := false
var front_hover := ""
var motive := ""
var last_error := ""
var last_result: Dictionary = {}
var _preview_wait := 0.0
var _preview_pending := false  # el último movimiento del cursor llegó dentro de los 80 ms de la vista previa anterior: se rehace apenas pasa la espera
var _preview_pos := Vector2.ZERO
## Las órdenes que la interfaz dio con éxito, en orden: {actor, action}. Para las pruebas (qa_state().issued).
var issued: Array = []


func setup(controller: Node) -> void:
	ui = controller


func _t(path: String, fallback: String = "") -> String:
	return str(ui.call("tx", path, fallback))


func actor_kind(id: String) -> String:
	var u: Variant = ui.rules.call("get_unit", id) if ui.rules != null else {}
	if u is Dictionary and not (u as Dictionary).is_empty():
		return str(U.ACTOR_OF_KIND.get(str((u as Dictionary).get("kind", "")), ""))
	return ""


func primary_actor() -> String:
	for id in V.GROUPS:
		if (ui.selected as Array).has(id):
			return str(id)
	return ""


func front_of(id: String) -> String:
	return str((ui.group_fronts as Dictionary).get(id, ""))


func aiming() -> bool:
	return not aim.is_empty()


# ---------------------------------------------------------------------------------------------------------------------
# Barra de acciones

## Las acciones que se ofrecen a la selección: las usables y la recomendada; sin la que ya ofrece el botón del «siguiente paso».
func bar_items(hs: Dictionary) -> Array:
	var out: Array = []
	if ui.rules == null:
		return out
	var guide := _guide_action(hs)
	var actor := primary_actor()
	var actions: Array = []
	if actor != "":
		actions = ui.rules.call("list_actions", actor_kind(actor))
	for a in U.ACTION_ORDER:
		var act := str(a)
		if act == "hold":
			continue  # sostener es automática al tomar un frente
		if act == "give_signal":
			if not bool((hs.get("senal", {}) as Dictionary).get("puede", false)):
				continue
		elif act == "cancel":
			if actor == "" or not _has_order(actor):
				continue
		elif not actions.has(act):
			continue
		if act == guide:
			continue
		var av := availability(actor, act)
		if not bool(av.ok) and act != "cancel":
			continue
		var info: Dictionary = ui.rules.call("action_info", act)
		out.append({"action": act, "label": str(info.get("name", act)), "key": ui.key_label_for(act), "ok": bool(av.ok), "reason": str(av.reason),
			"cost": str(av.cost_text), "tag": str(av.tag), "recommended": false})
	return out


func _guide_action(hs: Dictionary) -> String:
	var g: Variant = ui.guide
	if g is Dictionary and str((g as Dictionary).get("action", "")) != "" and bool((g as Dictionary).get("button_visible", false)):
		return str((g as Dictionary).get("action", ""))
	return ""


func _has_order(id: String) -> bool:
	var u: Variant = ui.rules.call("get_unit", id)
	if not (u is Dictionary):
		return false
	var st := str((u as Dictionary).get("stage", "idle"))
	return st in ["moving", "loading", "scouting", "waiting_signal", "retreating", "attacking"]


## ¿Puede `actor` hacer `action` ahora? (action_availability con un destino de prueba para las que piden uno).
func availability(actor: String, action: String) -> Dictionary:
	if ui.rules == null:
		return {"ok": false, "reason": "", "cost_text": "", "tag": "diseno"}
	var probe := Vector2.ZERO
	if U.AIM_ACTIONS.has(action):
		probe = Vector2(450.0, 325.0)
	var av: Variant = ui.rules.call("action_availability", actor, action, probe, {})
	return av if av is Dictionary else {"ok": false, "reason": "", "cost_text": "", "tag": "diseno"}


## ¿El punto (x, z) está dentro del mapa jugable? Las reglas rechazan las paradas de afuera («Una de las paradas queda fuera del mapa.»); la interfaz avisa antes de
## sumarlas a la ruta (B-046 b), no después de armar una orden que va a fallar.
func inside_map(p: Vector2) -> bool:
	if ui.rules == null or not ui.rules.has_method("map_size"):
		return true
	var size: Variant = ui.rules.call("map_size")
	return not (size is Vector2) or (p.x >= 0.0 and p.y >= 0.0 and p.x <= (size as Vector2).x and p.y <= (size as Vector2).y)


## Un rechazo de las reglas dicho con más ayuda (B-052 e): «Esa agrupación no puede hacer eso.» no decía quién sí. Se suma quién la hace y con qué tecla; el resto de los
## motivos queda tal cual.
func explain(reason: String, action: String) -> String:
	var generic := str(ui.call("rules_error", "no_corresponde"))
	if ui.rules == null or action == "" or generic == "" or reason != generic:
		return reason
	var names: Array = []
	var keys: Array = []
	var shorts: Dictionary = ui.hud.short_names() if ui.hud != null else {}
	for i in range(V.GROUPS.size()):
		var id := str(V.GROUPS[i])
		var kind := actor_kind(id)
		if kind != "" and (ui.rules.call("list_actions", kind) as Array).has(action):
			names.append(_t("actions.who." + id, str(shorts.get(id, id))))
			keys.append(i + 1)
	if names.is_empty():
		return reason
	var key_text := str(keys[0])
	if keys.size() > 1:
		key_text = "%d a %d" % [keys[0], keys[keys.size() - 1]] if int(keys[keys.size() - 1]) - int(keys[0]) == keys.size() - 1 else ", ".join(PackedStringArray(keys.map(func(k): return str(k))))
	var who: String = str(names[0]) if names.size() == 1 else ", ".join(PackedStringArray(names.slice(0, names.size() - 1))) + " y " + str(names[names.size() - 1])
	return (_t("actions.only_one") if names.size() == 1 else _t("actions.only_many")) % [who, key_text]


# ---------------------------------------------------------------------------------------------------------------------
# Ejecutar

## Da una orden por las reglas y devuelve su resultado (con `ok` y `reason`). Cuida el sonido, el reloj que arranca con la primera orden y el aviso de error.
func issue(actor: String, action: String, target: Vector2 = Vector2.ZERO, opts: Dictionary = {}) -> Dictionary:
	if ui.rules == null:
		return {"ok": false, "reason": ""}
	var r: Variant
	if action == "give_signal":
		r = ui.rules.call("give_signal")
	else:
		r = ui.rules.call("issue_order", actor, action, target, opts)
	var res: Dictionary = r if r is Dictionary else {"ok": false, "reason": ""}
	last_result = res
	if bool(res.get("ok", false)):
		last_error = ""
		plan = res.get("plan", {}) if res.get("plan", {}) is Dictionary else {}
		issued.append({"actor": actor, "action": action})
		ui.call("on_order_ok", actor, action)
	else:
		last_error = explain(str(res.get("reason", "")), action)
		ui.call("on_order_failed", last_error)
	return res


## Una tecla o un botón de la barra. Devuelve true si hizo algo.
func press(action: String) -> bool:
	if ui.rules == null:
		return false
	if action == "give_signal":
		return bool(issue("", "give_signal").get("ok", false))
	if action == "cancel":
		return cancel_selected()
	if (ui.selected as Array).is_empty():
		ui.call("set_motive", _t("actions.no_selection"), true)
		ui.call("play_sound", "error")
		return false
	if U.AIM_ACTIONS.has(action):
		begin_aim(action)
		return true
	if action == "destroy" and needs_destroy_confirmation():
		ui.call("ask_destroy")
		return true
	return issue_selected(action, Vector2.ZERO, {})


## ¿Hay que preguntar antes de destruir? Sí cuando alguna de las agrupaciones elegidas puede destruir ahora y el siguiente paso no lo está pidiendo. Si no puede (no hay
## carga a mano) no se pregunta: se dice por qué como con cualquier otra acción.
func needs_destroy_confirmation() -> bool:
	var g: Variant = ui.guide
	if g is Dictionary and str((g as Dictionary).get("action", "")) == "destroy":
		return false
	for id in V.GROUPS:
		if (ui.selected as Array).has(id) and bool(availability(str(id), "destroy").get("ok", false)):
			return true
	return false


## La misma orden a cada agrupación elegida a la que le corresponde. Si ninguna puede, se muestra el motivo de la primera.
func issue_selected(action: String, target: Vector2, opts: Dictionary) -> bool:
	var done := 0
	var first_reason := ""
	for id in V.GROUPS:
		if not (ui.selected as Array).has(id):
			continue
		var av: Variant = ui.rules.call("action_availability", id, action, target if target != Vector2.ZERO else (Vector2(450.0, 325.0) if U.AIM_ACTIONS.has(action) else Vector2.ZERO), opts)
		if av is Dictionary and not bool((av as Dictionary).get("ok", false)):
			if first_reason == "":
				first_reason = str((av as Dictionary).get("reason", ""))
			continue
		var res := issue(str(id), action, target, opts)
		if bool(res.get("ok", false)):
			done += 1
		elif first_reason == "":
			first_reason = str(res.get("reason", ""))
	if done == 0 and first_reason != "":
		last_error = explain(first_reason, action)
		ui.call("on_order_failed", last_error)
	return done > 0


func cancel_selected() -> bool:
	var any := false
	for id in V.GROUPS:
		if (ui.selected as Array).has(id) and _has_order(str(id)):
			var res: Variant = ui.rules.call("cancel_order", str(id))
			if res is Dictionary and bool((res as Dictionary).get("ok", false)):
				any = true
	if any:
		ui.call("on_order_ok", "", "cancel")
	return any


# ---------------------------------------------------------------------------------------------------------------------
# Modo apuntado y vista previa

func begin_aim(action: String) -> void:
	var actors: Array = []
	for id in V.GROUPS:
		if (ui.selected as Array).has(id):
			var av := availability(str(id), action)
			if bool(av.ok):
				actors.append(str(id))
	if actors.is_empty():
		var first := primary_actor()
		var av2 := availability(first, action)
		ui.call("set_motive", explain(str(av2.get("reason", _t("actions.no_selection"))), action), true)
		ui.call("play_sound", "error")
		return
	aim = {"action": action, "actors": actors}
	waypoints = []
	plan = {}
	has_target = false
	var hint_key := "actions.aim_hint_front" if action == "support" else "actions.aim_hint"
	motive = _t(hint_key)
	ui.call("set_motive", motive, false)
	ui.call("play_sound", "select")
	ui.call("refresh_hud_now")


func cancel_aim() -> void:
	_preview_pending = false
	if aim.is_empty() and waypoints.is_empty():
		return
	aim = {}
	waypoints = []
	plan = {}
	has_target = false
	front_hover = ""
	ui.call("set_motive", "", false)
	ui.call("refresh_hud_now")


func tick(delta: float) -> void:
	_preview_wait = maxf(0.0, _preview_wait - delta)
	if _preview_pending and _preview_wait <= 0.0:
		_preview_pending = false
		if not aim.is_empty():
			aim_move(_preview_pos)


## El cursor se movió con una orden en la mano: arma la vista previa (sin efectos) a lo sumo cada 80 ms.
func aim_move(pos: Vector2) -> void:
	if aim.is_empty():
		return
	var action := str(aim.action)
	if action == "support":
		front_hover = str(ui.call("pick_front_at", pos))
		has_target = front_hover != ""
		if has_target:
			target_now = ui.call("landmark_pos", front_hover)
		return
	var g: Variant = ui.call("ground_from_screen", pos)
	if not (g is Vector2):
		has_target = false
		plan = {}
		return
	target_now = g
	has_target = true
	if _preview_wait > 0.0 and not plan.is_empty():
		_preview_pending = true  # sin esto el cursor se quedaba quieto con la vista previa del movimiento anterior (a veces de un punto de afuera del mapa)
		_preview_pos = pos
		return
	_preview_pending = false
	_preview_wait = PREVIEW_PERIOD
	var actor := str((aim.actors as Array)[0])
	if action == "recon":
		var pts: Array = waypoints.duplicate()
		pts.append(target_now)
		plan = ui.rules.call("plan_recon", actor, pts.slice(0, 3), {})
	else:
		plan = ui.rules.call("plan_route", actor, target_now, {"pace": pace, "waypoints": waypoints})
	var shown := preview_text(action)
	if shown != motive:
		motive = shown
		ui.call("set_motive", motive, false)
		ui.call("refresh_hud_now")


## Clic izquierdo con una orden en la mano. `shift` suma una parada y sigue apuntando.
func aim_confirm(pos: Vector2, shift: bool) -> bool:
	if aim.is_empty():
		return false
	var action := str(aim.action)
	if action == "support":
		var front: String = str(ui.call("pick_front_at", pos))
		if front == "":
			ui.call("set_motive", _t("actions.aim_hint_front"), true)
			ui.call("play_sound", "error")
			return false
		var ok := issue_selected("support", ui.call("landmark_pos", front), {"front": front, "pace": pace})
		if ok:
			cancel_aim()
		return ok
	var g: Variant = ui.call("ground_from_screen", pos)
	if not (g is Vector2):
		return false
	target_now = g
	var limit_stops := 2 if action == "recon" else MAX_STOPS  # reconocer admite 3 puntos (dos paradas y el último); mover, 4 paradas
	if shift and waypoints.size() < limit_stops:
		if not inside_map(target_now):
			ui.call("set_motive", _t("actions.stop_outside"), true)
			ui.call("play_sound", "error")
			return false
		waypoints.append(target_now)
		_preview_wait = 0.0
		return true
	var ok2 := false
	if action == "recon":
		var pts: Array = waypoints.duplicate()
		pts.append(target_now)
		ok2 = issue_selected("recon", pts[pts.size() - 1], {"pace": pace, "waypoints": waypoints})
	else:
		ok2 = issue_selected(action, target_now, {"pace": pace, "waypoints": waypoints})
	if ok2:
		cancel_aim()
	return ok2


func set_pace(p: String) -> void:
	if U.PACE_ORDER.has(p):
		pace = p
		_preview_wait = 0.0


func preview_text(action: String) -> String:
	if plan.is_empty():
		return ""
	if not bool(plan.get("ok", false)):
		return str(plan.get("reason", ""))
	if action == "recon":
		var text := _t("actions.preview_recon") % [int(round(float(plan.get("risk_pct", 0.0)))), Kit.mmss(float(plan.get("time_s", 0.0)))]
		var reveals: Variant = plan.get("reveals", [])
		if reveals is Array and not (reveals as Array).is_empty():
			text += " · " + _t("actions.preview_reveals") % ", ".join(PackedStringArray(reveals))
		return text
	var risk_names: Dictionary = ui.texts.get("actions", {}).get("risk", {})
	var text2 := _t("actions.preview") % [int(round(float(plan.get("length_m", 0.0)))), Kit.mmss(float(plan.get("time_s", 0.0))), str(risk_names.get(str(plan.get("risk", "bajo")), plan.get("risk", "")))]
	var warnings: Variant = plan.get("warnings", [])
	if warnings is Array and not (warnings as Array).is_empty():
		text2 += " · " + str((warnings as Array)[0])
	return text2


## Los puntos del mundo de la ruta que se está armando (para dibujarla): la del plan si la hay, o la recta de la ficha al cursor.
func preview_points() -> Array:
	var pts: Array = []
	if aim.is_empty():
		return pts
	var actor := str((aim.actors as Array)[0])
	var p: Variant = plan.get("path", [])
	if p is Array and (p as Array).size() >= 2 and bool(plan.get("ok", false)):
		for q in p:
			pts.append(Vector2(float((q as Dictionary).get("x", 0.0)), float((q as Dictionary).get("z", 0.0))))
		return pts
	var u: Dictionary = ui.rules.call("get_unit", actor)
	pts.append(Vector2(float(u.get("x", 0.0)), float(u.get("z", 0.0))))
	for w in waypoints:
		pts.append(w)
	if has_target:
		pts.append(target_now)
	return pts


# ---------------------------------------------------------------------------------------------------------------------
# Clic derecho: la orden más lógica a lo que está bajo el cursor

func context_order(pos: Vector2, shift: bool, ctrl: bool, alt: bool) -> bool:
	if ui.rules == null:
		return false
	if not aim.is_empty():
		cancel_aim()
		return false
	if (ui.selected as Array).is_empty():
		ui.call("set_motive", _t("actions.no_selection"), true)
		ui.call("play_sound", "error")
		return false
	var use_pace := "run" if ctrl else ("sneak" if alt else pace)
	var front: String = str(ui.call("pick_front_at", pos))
	var g: Variant = ui.call("ground_from_screen", pos)
	if shift and g is Vector2 and front == "":
		if not inside_map(g):
			ui.call("set_motive", _t("actions.stop_outside"), true)
			ui.call("play_sound", "error")
			return false
		if waypoints.size() < MAX_STOPS - 1:
			waypoints.append(g)
			ui.call("set_motive", "", false)
			return true
		return false
	var done := 0
	var first_reason := ""
	var first_action := ""
	for id in V.GROUPS:
		if not (ui.selected as Array).has(id):
			continue
		var kind := actor_kind(str(id))
		var action := ""
		var target := Vector2.ZERO
		var opts: Dictionary = {"pace": use_pace, "waypoints": waypoints}
		if front != "" and kind == "group":
			if front == front_of(str(id)):
				action = "attack"
				opts = {"front": front, "posture": "a_fondo" if ctrl else "con_cautela"}
			else:
				action = "support"
				opts = {"front": front, "pace": use_pace}
			target = ui.call("landmark_pos", front)
		elif kind == "scout":
			action = "recon"
			target = ui.call("landmark_pos", front) if front != "" else (g if g is Vector2 else Vector2.ZERO)
		elif g is Vector2 or front != "":
			action = "move"
			target = g if g is Vector2 else ui.call("landmark_pos", front)
		if action == "" or target == Vector2.ZERO and action in U.AIM_ACTIONS:
			continue
		var av: Variant = ui.rules.call("action_availability", str(id), action, target, opts)
		if av is Dictionary and not bool((av as Dictionary).get("ok", false)):
			if first_reason == "":
				first_reason = str((av as Dictionary).get("reason", ""))
				first_action = action
			continue
		var res := issue(str(id), action, target, opts)
		if bool(res.get("ok", false)):
			done += 1
		elif first_reason == "":
			first_reason = str(res.get("reason", ""))
	if done > 0:
		waypoints = []
		return true
	if first_reason != "":
		last_error = explain(first_reason, first_action)
		ui.call("on_order_failed", last_error)
	return false
