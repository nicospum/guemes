extends RefCounted
## Consultas de solo lectura de las reglas del nivel «humahuaca» (CONTRATO 3.2.3): hud_state, render_state, campaign_report, epílogo, plan_route, plan_recon,
## route_atlas y el «siguiente paso». Dueña: reglas_historia. Existe aparte para que cada archivo del nivel quede por debajo de las ~1 500 líneas del contrato
## (se parte por responsabilidad); humahuaca_rules.gd la crea al primer uso y le delega.
## No guarda estado: lee el del dueño por una referencia DÉBIL (una fuerte formaría un ciclo y se perdería memoria al salir). Nada de lo que devuelve muta `state`.
## render_state() solo dice lo que el jugador conoce o ve: la guardia y la postura de un frente no reconocido no aparecen; las luces de la guardia sí (se ven de lejos).
## Independencia (V19): solo importa vocabularios y datos; al dueño lo recibe por parámetro.

const V = preload("res://scripts/humahuaca/humahuaca_vocab.gd")
const R = preload("res://scripts/humahuaca/rules/vocab_rules.gd")
const D = preload("res://scripts/humahuaca/rules/humahuaca_data.gd")

const GROUP_DESTROY_REACH_M := 160.0  # hasta dónde se manda a una partida a destruir lo que quedó mientras la columna marcha (su propio frente, no cruzar el pueblo)

var _owner: WeakRef

func _init(owner: RefCounted) -> void:
	_owner = weakref(owner)

func _o() -> Object:
	return _owner.get_ref()

var state: Dictionary:
	get:
		return _o().state

var _rules: Dictionary:
	get:
		return _o()._rules

var _level: Dictionary:
	get:
		return _o()._level

# Lo que la capa de consulta necesita del dueño (reenvíos tipados)
func _tx(path: String) -> Variant:
	return D.tx(path)

func _ts(path: String, vars: Dictionary = {}) -> String:
	return D.ts(path, vars)

func _hito_pos(id: String) -> Vector2:
	return D.hito(id)

func _unit(id: String) -> Dictionary:
	return _o()._unit(id)

func _attack_post(front: String, opts: Dictionary) -> Vector2:
	return _o()._attack_post(front, opts)

func _item_kg(it: Dictionary) -> float:
	return _o()._item_kg(it)

func _item_value(it: Dictionary) -> float:
	return _o()._item_value(it)

func _best_item(room_kg: float, near: Variant = null, radius: float = -1.0, destroying: bool = false) -> Dictionary:
	return _o()._best_item(room_kg, near, radius, destroying)

func _noise_state(u: Dictionary) -> String:
	return _o()._noise_state(u)

func _tower_pos() -> Vector2:
	return _o()._tower_pos()

func _loss_pct() -> float:
	return _o()._loss_pct()

func _in_map(p: Vector2) -> bool:
	return _o()._in_map(p)

func _waypoints(opts: Dictionary) -> Array:
	return _o()._waypoints(opts)

func _recon_radius_for(fid: String) -> float:
	return _o()._recon_radius_for(fid)

func environment() -> Dictionary:
	return _o().environment()

func loot_state() -> Dictionary:
	return _o().loot_state()

func signal_info() -> Dictionary:
	return _o().signal_info()

static func _pt(x: float, z: float) -> Dictionary:
	return {"x": x, "z": z}

static func _clock(seconds: float) -> String:
	return D.clock(seconds)

static func _fmt(template: String, vars: Dictionary) -> String:
	return D.fmt(template, vars)

# ---------------------------------------------------------------------------------------------------------------------
# El «siguiente paso»

func _step_dict(key: String, vars: Dictionary, actor: String, action: String, target: Vector2, urgency: int) -> Dictionary:
	var out := {"texto": _ts("siguiente." + key, vars), "actor": actor, "action": action, "urgencia": urgency, "id": key, "eta_s": _step_eta(key, actor)}
	if target != Vector2.ZERO:
		out["target"] = _pt(target.x, target.y)
	else:
		out["target"] = {}
	return out

## Cuánto falta (segundos de juego) para que cambie un paso de espera: la carga en curso, la marcha que falta por la ruta o la primera luz. -1 si no se sabe (la
## toma de un frente depende del combate) o si el paso no es de espera. Lo usa la interfaz para decir «faltan N s» en vez de solo «Esperá».
func _step_eta(key: String, actor: String) -> float:
	var u := _unit(actor)
	match key:
		"wait_load":
			return maxf(0.0, float((u.get("work", {}) as Dictionary).get("remaining_s", -1.0))) if not (u.get("work", {}) as Dictionary).is_empty() else -1.0
		"wait_group", "wait_exit":
			if u.is_empty() or (u.path as Array).is_empty():
				return -1.0
			var pos := Vector2(float(u.x), float(u.z))
			var left := 0.0
			for p in u.path:
				var q := Vector2(float(p.x), float(p.z))
				left += pos.distance_to(q)
				pos = q
			return left / maxf(float(_o()._unit_speed(u)), 0.1)
		"wait_light":
			return maxf(0.0, float(_rules.time.alba_start_s) - float(state.elapsed))
	return -1.0

const HINT_LOAD_TRAVEL_S := 45.0  # hasta cuántos segundos de viaje manda la pista al arreo por un lote (lo que queda lejos lo destruyen las partidas)
const PLAN_DETOUR := 1.1  # la ruta real del arreo (A*, barro, vado) es más larga que la recta: el plan de carga cuenta con ese margen

func _mule_speed() -> float:
	return maxf(float(_rules.stealth.pace[str(_rules.transport.mule_pace)].speed) * float(_rules.transport.mule_speed_mult), 0.1)

func _exit_eta_from(x: float, z: float) -> float:
	var v := _hito_pos("vado_este")
	var sal := _hito_pos("salida_este")
	return (D.dist(x, z, v.x, v.y) * PLAN_DETOUR + v.distance_to(sal)) / _mule_speed()

func _exit_eta(u: Dictionary) -> float:
	return _exit_eta_from(float(u.x), float(u.z))

## El próximo lote a cargar con el sobrante de reloj `slack` (segundos que quedan antes de tener que salir desde donde está el arreo): entre los que entran en las
## mulas y en el tiempo (viaje, carga y lo que alarga la salida ir hasta ahí), el que más puntos da por recurso gastado. Con tiempo de sobra manda el peso; con el
## reloj encima, la cercanía. {} si ninguno entra.
func _next_load_target(u: Dictionary, slack: float) -> Dictionary:
	var best: Dictionary = {}
	var best_score := -1.0e9
	var room := float(state.loot.capacity_kg) - float(state.loot.load_kg)
	var rate := float(_rules.transport.load_kg_per_s_per_team) * float(_rules.transport.teams_max)
	var exit_here := _exit_eta(u)
	for it in state.loot.items:
		if str(it.state) != "en_sitio" or str(state.objectives[str(it.front)].state) != "tomado" or _item_kg(it) > room + 1e-6:
			continue
		var travel := D.dist(float(u.x), float(u.z), float(it.x), float(it.z)) * PLAN_DETOUR / _mule_speed()
		if travel > HINT_LOAD_TRAVEL_S:
			continue  # la pista no manda el arreo a cruzar el pueblo por un lote: carga lo del depósito; lo lejano lo destruyen las partidas
		var cost_time := travel + _item_kg(it) / rate + maxf(_exit_eta_from(float(it.x), float(it.z)) - exit_here, 0.0)
		if cost_time > slack:
			continue
		var score := _item_value(it) / (cost_time / maxf(slack, 1.0) + _item_kg(it) / maxf(room, 1.0))
		if score > best_score:
			best_score = score
			best = it
	return best

## ¿El diario de este mundo ya anotó esa causa? (las marcas «anotado» que HumahuacaProgress le da a la partida: lo único que el jugador aprendió entre intentos).
func _diary_has(kind: String) -> bool:
	for m in state.get("diary_marks", []):
		if str(m.get("kind", "")) == kind:
			return true
	return false

## Lo que el jugador puede saber del reloj del refuerzo (el «siguiente paso» NO lee state.alarm.reinforcement_at salvo cuando la polvareda ya se ve): mientras no se
## lo ve, cuenta con la demora que dice reinforcement.hint_plan (la normal; la temprana si el diario ya anotó una intercepción) descontada desde la señal y del humo
## quemado, que el jugador también vio. 1e9 si todavía no hubo señal.
func _reinforcement_left_estimate(t: float) -> float:
	var al: Dictionary = state.alarm
	if float(al.reinforcement_at) < 0.0:
		return 1.0e9
	var real_left := float(al.reinforcement_at) - t
	var rf: Dictionary = _rules.reinforcement
	if real_left <= float(rf.warning_lead_s):
		return real_left
	var plan: Dictionary = rf.get("hint_plan", {})
	var assume := str(plan.get("tras_interceptados", "temprano")) if _diary_has("interceptados") else str(plan.get("default", "normal"))
	var delay := float((rf.delay_s as Dictionary).get(assume, rf.delay_s.normal))
	return delay - _known_advance_s() - (t - float(al.signal_at))

## Lo que el jugador vio que adelanta el refuerzo: el humo de la pólvora quemada y el jinete que escapó al sur.
func _known_advance_s() -> float:
	var adv := float(state.get("smoke_adv", 0.0))
	if str(state.alarm.messenger) == "escaped":
		adv += float(_rules.reinforcement.get("messenger_advance_s", 0.0))
	return adv

## Lo que le conviene hacer al arreo ahora: cargar lo mejor que entre, destruir lo que no entra hasta asegurar el golpe, o salir. {} si no hay nada que decir.
func _arreo_step(t: float, allow_leave: bool) -> Dictionary:
	var u := _unit("arreo")
	var st := str(u.stage)
	if st == "exited":
		return {}
	if st == "loading":
		return _step_dict("wait_load", {}, "arreo", "hold", Vector2.ZERO, 0)
	if st != "idle":
		return _step_dict("wait_exit", {}, "arreo", "hold", Vector2.ZERO, 0) if allow_leave else {}
	var left := _reinforcement_left_estimate(t)
	## lo que sobra del reloj estimado después de la marcha al vado (con su margen): cada lote que se carga o se quema tiene que entrar en ese sobrante
	var slack := left - (_exit_eta(u) + float(_rules.transport.exit_margin_s))
	var urgent := slack <= 0.0
	var carry_value := 0.0
	for it in state.loot.items:
		if str(it.state) == "cargado":
			carry_value += _item_value(it)
	var l: Dictionary = state.loot
	var potential := carry_value + float(l.delivered_value) + float(l.destroyed_value) + float(l.hidden_value)
	var gmin := float(_rules.outcome.victory.golpe_min)
	if not urgent:
		var best := _next_load_target(u, slack)
		if not best.is_empty():
			var spot := Vector2(float(best.x), float(best.z))
			if D.dist(float(u.x), float(u.z), spot.x, spot.y) > float(_rules.transport.load_radius_m):
				return _step_dict("bring_load", {"donde": str(best.where).to_lower()}, "arreo", "move", spot, 1)
			return _step_dict("load", {"carga": str(_rules.loot.classes[str(best.kind)].name).to_lower()}, "arreo", "load", spot, 1)
		## lo que no entra en las mulas se destruye mientras el reloj estimado lo permita: suma destruir × valor al golpe (y, si el golpe no alcanza, es la única salida)
		var victim := _best_item(-1.0, Vector2(float(u.x), float(u.z)), float(_rules.transport.destroy_radius_m), true)
		if not victim.is_empty() and float(_rules.loot.classes[str(victim.kind)].destroy_s) <= slack:
			return _step_dict("destroy", {"carga": str(_rules.loot.classes[str(victim.kind)].name).to_lower()}, "arreo", "destroy", Vector2(float(victim.x), float(victim.z)), 1 if potential >= gmin + 1.0 else 2)
	if not allow_leave:
		return {}
	return _step_dict("leave", {}, "arreo", "leave", _hito_pos("salida_este"), 2 if urgent else 1)

## El enfoque que la pista recomienda para un frente: para el cuartel, el que la torre que el jugador cree (lo que le creyó al informante) no barre: patios si cree
## que está en la casa del cura, calle si cree que está en el templo. "" si no decidió nada o el frente no tiene enfoques que cambien algo.
func _hint_approach(fid: String) -> String:
	if fid != "cuartel" or str(state.world.guardia) == "atenta":  # con la guardia atenta (lo dice el briefing) los patios pasan a la vista de la altura: siempre la calle
		return ""
	var believed := str(_o()._field().believed_tower())
	if believed == "casa_cura":
		return "patios"
	if believed == "templo":
		return "calle"
	return ""

## La partida que podría cargar sobre el cuartel en el hueco de recarga de la torre: la que lo ataca (vuelve a cargar) o una libre a su alcance. "" si no hay hueco o nadie.
func _tower_gap_charger() -> String:
	if str(state.objectives.cuartel.state) == "tomado" or not _o()._tower_in_gap():
		return ""
	var c := _hito_pos(str(_rules.objectives.cuartel.hito))
	for g in V.COMBAT_GROUPS:
		var u := _unit(g)
		var st := str(u.stage)
		if st == "routed" or st == "exited" or st == "moving":
			continue
		if float(u.get("tower_cover_until", -1.0)) > float(state.elapsed):
			continue  # ya está cruzando en este hueco
		if D.dist(float(u.x), float(u.z), c.x, c.y) <= float(_rules.combat.attack_range_m):
			return g
	return ""

## Quien terminó su frente puede socorrer al que más cuesta (es el «Arias acude a Portal» del diseño). {} si nadie puede o nada hace falta.
func _support_step() -> Dictionary:
	var hardest := ""
	var lowest := 101.0
	for fid in V.OBJECTIVES:
		var o: Dictionary = state.objectives[fid]
		if str(o.state) == "tomado" or str(o.state) != "asaltado":
			continue
		if float(o.toma) < lowest:
			lowest = float(o.toma)
			hardest = fid
	if hardest == "":
		return {}
	for g in V.COMBAT_GROUPS:
		var u := _unit(g)
		var own := str(_rules.groups[g].front)
		if own != hardest and str(state.objectives[own].state) == "tomado" and (str(u.stage) == "holding" or str(u.stage) == "idle"):
			return _step_dict("support", {"grupo": str(_rules.groups[g].short), "socorrido": str(_rules.groups[str(_rules.objectives[hardest].group)].short)}, g, "support", _hito_pos(str(_rules.objectives[hardest].hito)), 1)
	return {}

func next_step() -> Dictionary:
	var t := float(state.elapsed)
	var tm: Dictionary = _rules.time
	if str(state.status) != "playing":
		return _step_dict("fin", {}, "reconocedores", "cancel", Vector2.ZERO, 0)
	if not bool(state.alarm.signaled):
		var recon_u := _unit("reconocedores")
		var escape := spotted_escape(recon_u)
		if not escape.is_empty():  # un centinela los vio: lo primero es sacarlos de ahí antes de que se venza el aviso (D-01)
			return _step_dict("retirar_reconocedores", {"frente": str(_rules.objectives[str(escape.front)].place)}, "reconocedores", "move", escape.target, 2)
		var scouts_busy := str(recon_u.stage) == "moving" or str(recon_u.stage) == "scouting"
		## lo que el diario enseñó (si ya los vieron una vez en este mundo, no se manda a nadie a mirar de cerca) y lo que dice el briefing: con la guardia atenta, a
		## quien se para a mirar de cerca lo ven; la pista no lo pide (la guía nunca lleva a perder, D-01). Quien quiera arriesgarse igual tiene el aviso para retirarse.
		var recon_safe := not _diary_has("descubiertos") and str(state.world.guardia) != "atenta"
		if float(state.objectives.bateria.reconocido) < 1.0 and not scouts_busy and recon_safe:
			return _step_dict("recon", {"frente": str(_rules.objectives.bateria.place)}, "reconocedores", "recon", _hito_pos("bateria"), 1)
		for g in V.COMBAT_GROUPS:
			var u := _unit(g)
			var st := str(u.stage)
			var fid_g := str(_rules.groups[g].front)
			var approach := _hint_approach(fid_g)
			## ya en camino o en su puesto, pero por el otro enfoque: después del informante la pista pide cambiar de entrada (una orden nueva de puesto la cambia)
			var wrong_entry := approach != "" and (st == "waiting_signal" or (st == "moving" and str(u.order.get("action", "")) == "position")) and str(u.order.get("approach", "")) != approach
			if st == "idle" or st == "holding" or (st == "moving" and str(u.order.get("action", "")) != "position") or wrong_entry:
				if approach != "":
					var enfoque := "los patios" if approach == "patios" else "la calle"
					return _step_dict("position_enfoque", {"grupo": str(_rules.groups[g].short), "enfoque": enfoque}, g, "position", _attack_post(fid_g, {"approach": approach}), 1)
				return _step_dict("position", {"grupo": str(_rules.groups[g].short)}, g, "position", _attack_post(fid_g, {}), 1)
		var arreo := _unit("arreo")
		var posta := _hito_pos("posta")
		if str(arreo.stage) == "idle" and D.dist(float(arreo.x), float(arreo.z), posta.x, posta.y) > float(_rules.transport.bring_radius_m):
			return _step_dict("bring", {}, "arreo", "move", posta, 1)
		## (el cuartel y la posta no se mandan a mirar de cerca: para llegar hay que pasar por delante de la batería y la guardia los ve; lo que importa ya se sabe)
		var waiting: Array = []
		var coming: Array = []
		for g in V.COMBAT_GROUPS:
			if str(_unit(g).stage) == "waiting_signal":
				waiting.append(g)
			elif str(_unit(g).stage) == "moving":
				coming.append(g)
		var late := t >= float(tm.alba_start_s) - 60.0
		if not waiting.is_empty() and t >= float(tm.signal_hint_s) and (coming.is_empty() or late):
			return _step_dict("signal", {}, str(waiting[0]), "give_signal", Vector2.ZERO, 2 if t >= float(tm.alba_start_s) else 1)
		if not waiting.is_empty() and coming.is_empty():
			return _step_dict("wait_light", {}, str(waiting[0]), "hold", Vector2.ZERO, 0)
		var who: String = str(coming[0]) if not coming.is_empty() else "arias"
		return _step_dict("wait_group", {"grupo": str(_rules.groups[who].short)}, who, "hold", Vector2.ZERO, 0)
	if str(state.phase) != "extraccion":
		for g in V.COMBAT_GROUPS:
			var u2 := _unit(g)
			var fid := str(_rules.groups[g].front)
			if str(state.objectives[fid].state) != "tomado" and (str(u2.stage) == "idle" or str(u2.stage) == "holding"):
				var c := _hito_pos(str(_rules.objectives[fid].hito))
				if D.dist(float(u2.x), float(u2.z), c.x, c.y) <= float(_rules.combat.attack_range_m):
					return _step_dict("attack", {"grupo": str(_rules.groups[g].short), "frente": str(_rules.objectives[fid].place)}, g, "attack", c, 1)
				return _step_dict("position", {"grupo": str(_rules.groups[g].short)}, g, "position", _attack_post(fid, {}), 1)
		var help := _support_step()
		if not help.is_empty():
			return help
		var pre := _arreo_step(t, false)
		if not pre.is_empty():
			return pre
		var pending := "bateria"
		for fid in V.OBJECTIVES:
			if str(state.objectives[fid].state) != "tomado":
				pending = fid
				break
		var holder := "arias"
		for g in V.COMBAT_GROUPS:
			if str(_rules.groups[g].front) == pending:
				holder = g
		return _step_dict("wait_attack", {"frente": str(_rules.objectives[pending].place)}, holder, "hold", Vector2.ZERO, 0)
	var post := _arreo_step(t, true)
	if not post.is_empty() and str(post.action) != "hold":
		return post
	var leftovers := _group_destroy_step()
	if not leftovers.is_empty():
		return leftovers
	var withdraw := _group_withdraw_step()
	if not withdraw.is_empty():
		return withdraw
	return post if not post.is_empty() else _step_dict("fin", {}, "arreo", "cancel", Vector2.ZERO, 0)

const WITHDRAW_AT_M := {"rodriguez": 1.0e9, "portal": 170.0, "arias": 60.0, "reconocedores": 15.0}  # a qué distancia del vado tiene que estar ya la columna para replegar a cada agrupación

## Con la columna en marcha y nada más que destruir, las partidas se repliegan por el vado de a una, a medida que la columna pasa su altura (los jinetes de
## Rodríguez primero; Arias, que cubre la posta, al final). {} si el arreo no salió o nadie queda por replegar.
func _group_withdraw_step() -> Dictionary:
	var arreo := _unit("arreo")
	if not _arreo_leaving(arreo):
		return {}
	var vado := _hito_pos("vado_este")
	var d_col := D.dist(float(arreo.x), float(arreo.z), vado.x, vado.y) if str(arreo.stage) == "moving" else 0.0
	for g in V.COMBAT_GROUPS:
		var u := _unit(g)
		var st := str(u.stage)
		if st != "holding" and st != "idle":
			continue
		if d_col <= float(WITHDRAW_AT_M.get(g, 0.0)):
			return _step_dict("repliegue", {"grupo": str(_rules.groups[g].short)}, g, "leave", _hito_pos("salida_este"), 1)
	var scouts := _unit("reconocedores")
	if str(scouts.stage) == "idle" and d_col <= float(WITHDRAW_AT_M.reconocedores) and D.dist(float(scouts.x), float(scouts.z), vado.x, vado.y) > 60.0:
		return _step_dict("repliegue_scouts", {}, "reconocedores", "move", _hito_pos("salida_este"), 1)
	return {}

## ¿La columna ya va camino al vado (o salió)? Un arreo que camina hacia un lote todavía no se fue: lo que va a buscar no se destruye.
func _arreo_leaving(arreo: Dictionary) -> bool:
	return str(arreo.stage) == "exited" or (str(arreo.stage) == "moving" and str(arreo.order.get("action", "")) == "leave")

## Mientras la columna marcha al vado, las partidas que sostienen un frente destruyen lo que quedó en el sitio (suma destruir × valor al golpe). {} si el arreo sigue
## cargando, si nadie está libre o si no queda nada a mano.
func _group_destroy_step() -> Dictionary:
	var arreo := _unit("arreo")
	var arreo_gone := _arreo_leaving(arreo)
	var room := float(state.loot.capacity_kg) - float(state.loot.load_kg)
	var radius := float(_rules.transport.destroy_radius_m)
	for g in V.COMBAT_GROUPS:
		var u := _unit(g)
		var st := str(u.stage)
		if st != "holding" and st != "idle":
			continue
		var best: Dictionary = {}
		var best_d := GROUP_DESTROY_REACH_M
		for it in state.loot.items:
			if str(it.state) != "en_sitio" or str(state.objectives[str(it.front)].state) != "tomado":
				continue
			## mientras el arreo todavía carga, las partidas solo destruyen lo que el arreo no va a llevar (lo que no entra en las mulas o las piezas de la batería, lejos de la posta)
			if not arreo_gone and _item_kg(it) <= room and str(it.front) != "bateria":
				continue
			var d := D.dist(float(u.x), float(u.z), float(it.x), float(it.z))
			if d < best_d:
				best_d = d
				best = it
		if best.is_empty():
			continue
		var spot := Vector2(float(best.x), float(best.z))
		var carga := str(_rules.loot.classes[str(best.kind)].name).to_lower()
		if best_d > radius:
			return _step_dict("ir_destruir", {"grupo": str(_rules.groups[g].short), "carga": carga}, g, "move", spot, 1)
		return _step_dict("destruir_grupo", {"grupo": str(_rules.groups[g].short), "carga": carga}, g, "destroy", spot, 1)
	return {}

## ¿Hay algo para decidir ahora? Un «siguiente paso» con algo para hacer, una alerta con botón o una decisión pendiente (la oferta que mide stats.pacing).
func offer_now() -> bool:
	if not _o().pending_choice().is_empty():
		return true
	var nxt := next_step()
	if str(nxt.action) != "hold" and str(nxt.action) != "cancel":
		return true
	for a in _hud_alerts(float(state.elapsed)):
		if str(a.boton) != "":
			return true
	return false

func _clock_text() -> String:
	var t := float(state.elapsed)
	var tm: Dictionary = _rules.time
	if str(state.status) != "playing":
		return str(_tx("reloj.fin"))
	if not bool(state.alarm.signaled):
		if t < float(tm.alba_start_s):
			return _ts("reloj.falta_alba", {"t": _clock(float(tm.alba_start_s) - t)})
		return _ts("reloj.amanece", {"t": _clock(float(tm.dawn_discovery_s) - t)})
	if str(state.phase) == "extraccion":
		return _ts("reloj.extraccion", {"t": _clock(float(tm.deadline_s) - t)})
	return _ts("reloj.ataque", {"t": _clock(t - float(state.alarm.signal_at))})

func _reinforcement_hud() -> Dictionary:
	var al: Dictionary = state.alarm
	var t := float(state.elapsed)
	var band: Array = _rules.reinforcement.band_initial_s
	var lo := float(band[0])
	var hi := float(band[1])
	var estado := "desconocido"
	var rest := 0.0
	if bool(al.reinforcement_arrived):
		estado = "llego"
	elif float(al.reinforcement_at) >= 0.0:
		var left := float(al.reinforcement_at) - t
		var since := t - float(al.signal_at) + _known_advance_s()  # la banda corre desde la señal y se acorta con el humo quemado y el jinete que escapó (lo que el jugador ve)
		lo = maxf(0.0, lo - since)
		hi = maxf(0.0, hi - since)
		if left <= float(_rules.reinforcement.warning_lead_s):
			estado = "visible"
			rest = maxf(0.0, left)
		elif str(state.phase) == "extraccion":
			estado = "en_camino"
	return {"estado": estado, "restante_s": rest, "banda": [lo, hi]}

## Si un centinela vio a la agrupación `u` (la ventana del aviso): {front, until, target} con un punto de retirada que se aleja del frente lo suficiente para salvarse;
## {} si nadie la vio.
func spotted_escape(u: Dictionary) -> Dictionary:
	var sp: Dictionary = u.get("spotted", {})
	if sp.is_empty():
		return {}
	var c := _hito_pos(str(_rules.objectives[str(sp.front)].hito))
	var p := Vector2(float(u.x), float(u.z))
	var away := (p - c).normalized() if p.distance_to(c) > 0.5 else Vector2(0.0, 1.0)
	var back := p + away * maxf(30.0, 3.0 * float(_o()._guard_cfg().get("recon_warn_escape_m", 8.0)))
	var sz := _o().map_size() as Vector2
	return {"front": str(sp.front), "until": float(sp.until), "target": Vector2(clampf(back.x, 0.0, sz.x), clampf(back.y, 0.0, sz.y))}

func _hud_alerts(t: float) -> Array:
	var out: Array = []
	var tm: Dictionary = _rules.time
	var signaled := bool(state.alarm.signaled)
	var playing := str(state.status) == "playing"
	var esc := spotted_escape(_unit("reconocedores")) if playing else {}
	if not esc.is_empty() and _rules.texts.alertas.has("reconocedores_vistos"):
		## el aviso de la detección (D-01): crítico, con pausa corta y la cuenta; el botón los retira (lo mismo que pide el «siguiente paso»)
		var rv0: Dictionary = _rules.texts.alertas.reconocedores_vistos
		var left_sp := maxf(0.0, float(esc.until) - t)
		var place := D.with_contractions({"frente": str(_rules.objectives[str(esc.front)].place), "s": int(ceil(left_sp))})
		out.append({"id": "reconocedores_vistos", "nivel": "critica", "corto": _fmt(str(rv0.corto), place), "largo": _fmt(str(rv0.largo), place), "boton": str(rv0.boton),
			"accion": {"action": "move", "actor": "reconocedores"}, "pausa": true, "vence_s": left_sp})
	if playing and not signaled:
		var info := signal_info()
		if not (info.in_position as Array).is_empty() and not (info.waiting as Array).is_empty() and t < float(tm.alba_start_s):
			var who := str(_rules.groups[str(info.in_position[0])].short)
			var faltan: Array = []
			for g in info.waiting:
				faltan.append(str(_rules.groups[g].short))
			var a: Dictionary = _rules.texts.alertas.en_puesto
			out.append({"id": "en_puesto", "nivel": "aviso", "corto": _fmt(str(a.corto), {"grupo": who}), "largo": _fmt(str(a.largo), {"grupo": who, "faltan": ", ".join(PackedStringArray(faltan))}),
				"boton": str(a.boton), "accion": {"action": "give_signal"}, "pausa": false, "vence_s": 0.0})
		elif bool(info.can_give) and (info.waiting as Array).is_empty() and t < float(tm.alba_start_s) - 60.0 and _rules.texts.alertas.has("todos_en_puesto"):
			## las tres en su puesto y todavía de noche: dar la señal ya es una decisión posible (de noche se tira peor, pero la guardia duerme)
			var ap: Dictionary = _rules.texts.alertas.todos_en_puesto
			out.append({"id": "todos_en_puesto", "nivel": "aviso", "corto": str(ap.corto), "largo": str(ap.largo), "boton": str(ap.boton), "accion": {"action": "give_signal"}, "pausa": false, "vence_s": 0.0})
		if t >= float(tm.alba_start_s) - 60.0 and t < float(tm.alba_start_s):
			var b: Dictionary = _rules.texts.alertas.aviso_alba
			out.append({"id": "aviso_alba", "nivel": "aviso", "corto": str(b.corto), "largo": str(b.largo), "boton": str(b.boton), "accion": {"action": "give_signal"}, "pausa": false, "vence_s": 0.0})
		if t >= float(tm.alba_start_s):
			var d: Dictionary = _rules.texts.alertas.amanece
			var left := maxf(0.0, float(tm.dawn_discovery_s) - t)
			out.append({"id": "amanece", "nivel": "critica", "corto": str(d.corto), "largo": _fmt(str(d.largo), {"t": _clock(float(tm.dawn_discovery_s))}), "boton": str(d.boton),
				"accion": {"action": "give_signal"}, "pausa": false, "vence_s": left})
	var dec: Dictionary = _o()._field().pending_decision()
	if playing and not dec.is_empty() and (dec.opciones as Array).size() >= 2:
		## la decisión de campo como aviso con botón: el botón cree la segunda versión; sin tocar nada, al vencer se toma la primera (lo dice el texto)
		var ops: Array = dec.opciones
		var left_dec := maxf(0.0, float(dec.get("at", t)) + float(dec.get("vence_s", 25.0)) - t)
		var largo := "%s %s. Si no decidís, se toma la primera." % [str(dec.texto), str(ops[0].label).to_lower().replace("creer que", "La primera dice que")]
		out.append({"id": "informante", "nivel": "aviso", "corto": str(dec.titulo), "largo": largo, "boton": str(ops[1].label), "accion": {"action": "decide", "actor": str(ops[1].id)},
			"pausa": true, "vence_s": left_dec, "opciones": ops.duplicate(true)})
	if playing and bool(state.objectives.cuartel.tower.active):
		var tw: Dictionary = _rules.texts.alertas.torre
		var tc: Dictionary = _rules.tower
		out.append({"id": "torre", "nivel": "aviso", "corto": str(tw.corto), "largo": _fmt(str(tw.largo), {"periodo": tc.volley_period_s, "radio": tc.radius_m, "angulo": tc.dead_angle_m}),
			"boton": "", "accion": {}, "pausa": false, "vence_s": 0.0})
		## el hueco de recarga: quien cargue ahora llega al pie de la torre antes de la próxima descarga (la ventana de cruce del diseño). Es una decisión con costo
		## (una carga más cuesta fatiga) y solo se ofrece a una partida que pueda atacar el cuartel ya.
		var charger := _tower_gap_charger()
		if charger != "" and _rules.texts.alertas.has("torre_hueco"):
			var th: Dictionary = _rules.texts.alertas.torre_hueco
			var left := maxf(0.0, float(state.objectives.cuartel.tower.next_volley_at) - t)
			out.append({"id": "torre_hueco", "nivel": "aviso", "corto": str(th.corto), "largo": str(th.largo), "boton": str(th.boton), "accion": {"action": "attack", "actor": charger}, "pausa": false, "vence_s": left})
	if playing and str(state.phase) == "extraccion":
		var hud_r := _reinforcement_hud()
		if str(hud_r.estado) == "visible":
			var rv: Dictionary = _rules.texts.alertas.refuerzo_visto
			out.append({"id": "refuerzo_visto", "nivel": "critica", "corto": str(rv.corto), "largo": str(rv.largo), "boton": str(rv.boton),
				"accion": {"action": "leave", "actor": "arreo"}, "pausa": false, "vence_s": float(hud_r.restante_s)})
		elif float(state.loot.load_kg) <= 0.0:
			var dt: Dictionary = _rules.texts.alertas.deposito_tomado
			out.append({"id": "deposito_tomado", "nivel": "info", "corto": str(dt.corto), "largo": str(dt.largo), "boton": str(dt.boton), "accion": {"action": "load", "actor": "arreo"}, "pausa": false, "vence_s": 0.0})
	return out

# ---------------------------------------------------------------------------------------------------------------------
# hud_state, render_state y campaign_report

func hud_state() -> Dictionary:
	if state.is_empty():
		return {}
	var env := environment()
	var t := float(state.elapsed)
	var frentes: Array = []
	for fid in V.OBJECTIVES:
		var cfg: Dictionary = _rules.objectives[fid]
		var o: Dictionary = state.objectives[fid]
		var rr: Array = cfg.report_range
		var guard := {"min": int(rr[0]), "max": int(rr[1]), "conocida": false}
		if float(o.reconocido) >= 1.0:
			var g := ceili(float(o.garrison))
			guard = {"min": g, "max": g, "conocida": true}
		frentes.append({"id": fid, "nombre": str(cfg.name), "estado": str(o.state), "estado_txt": str(_tx("estados_frente." + str(o.state) + "." + str(cfg.gender))),
			"toma_pct": float(o.toma), "guardia": guard, "alerta": float(o.alert), "sorpresa_s": maxf(0.0, float(o.surprise_until) - t), "apoyo": (o.supporters as Array).duplicate(), "tag": str(cfg.tag)})
	var grupos: Array = []
	for u in state.units:
		var gc: Dictionary = _rules.groups[str(u.id)]
		grupos.append({"id": str(u.id), "nombre": str(gc.name), "glifo": str(gc.glyph), "fuerza_pct": float(u.strength), "fatiga_pct": float(u.fatigue), "etapa_txt": str(_tx("etapas." + str(u.stage))),
			"ruido": _noise_state(u), "tag": str(u.tag), "custodia": int(u.custody), "vivo": str(u.stage) != "routed"})
	var sig := signal_info()
	var faltan: Array = []
	for g in sig.waiting:
		faltan.append(g)
	var l := loot_state()
	var gp: Dictionary = l.golpe
	var rf := _reinforcement_hud()
	var rf_text: String
	match str(rf.estado):
		"en_camino":
			rf_text = _ts("chips.refuerzo.en_camino", {"a": _clock(float(rf.banda[0])), "b": _clock(float(rf.banda[1]))})
		"visible":
			rf_text = _ts("chips.refuerzo.visible", {"t": _clock(float(rf.restante_s))})
		"llego":
			rf_text = _ts("chips.refuerzo.llego")
		_:
			rf_text = _ts("chips.refuerzo.desconocido")
	var golpe_now := float(gp.entregado) + float(gp.destruido) + float(gp.oculto)
	var tower: Dictionary = {}
	var tw: Dictionary = state.objectives.cuartel.tower
	if bool(tw.armed):
		tower = {"activa": bool(tw.active), "municion_pct": 100.0 * float(int(tw.volleys_left)) / float(_rules.tower.volleys),
			"proxima_en_s": maxf(0.0, float(tw.next_volley_at) - t) if bool(tw.active) else 0.0, "periodo_s": float(_rules.tower.volley_period_s), "angulo_muerto_m": float(_rules.tower.dead_angle_m)}
	var horses_text := "asegurados" if int(_unit("rodriguez").horses) > 0 else "sin_asegurar"
	var vars := {}
	for dim in ["lluvia", "guardia", "refuerzo"]:
		vars[dim] = str(state.world[dim])
	return {"objetivo": str(_tx("objetivo")), "siguiente": next_step(),
		"fase": {"id": str(state.phase), "nombre": "%s · %s" % [str(_tx("momentos." + str(env.phase))), str(_tx("fases." + str(state.phase)))], "reloj": _clock_text()},
		"alba": {"progreso": clampf(t / float(_rules.time.alba_start_s), 0.0, 1.0), "restante_s": maxf(0.0, float(_rules.time.alba_start_s) - t)},
		"frentes": frentes, "grupos": grupos, "alertas": _hud_alerts(t),
		"chips": [{"id": "carga", "txt": _ts("chips.carga", {"kg": roundi(float(l.load_kg)), "cap": roundi(float(l.capacity_kg))}), "valor": float(l.load_kg) / maxf(float(l.capacity_kg), 1.0)},
			{"id": "golpe", "txt": _ts("chips.golpe", {"n": roundi(golpe_now)}), "valor": golpe_now},
			{"id": "refuerzo", "txt": rf_text, "valor": float(rf.restante_s)},
			{"id": "caballos", "txt": _ts("chips.caballos." + horses_text), "valor": 1.0 if horses_text == "asegurados" else 0.0}],
		"senal": {"puede": bool(sig.can_give), "faltan": faltan, "oscuridad_pct": float(sig.dark_pct), "desvelo_pct": float(sig.drift_pct)},
		"torre": tower,
		"golpe": {"entregado": float(gp.entregado), "destruido": float(gp.destruido), "oculto": float(gp.oculto), "pendiente": maxf(0.0, 100.0 - golpe_now), "total": 100.0},
		"refuerzo": rf, "decision": {}, "ayudas": [], "mundo": {"linea": _ts("mundo_linea", vars)}}

func render_state() -> Dictionary:
	if state.is_empty():
		return {}
	var env := environment()
	var t := float(state.elapsed)
	var us: Array = []
	var pools: Array = []
	var horses: Array = []
	for u in state.units:
		us.append({"id": str(u.id), "x": float(u.x), "z": float(u.z), "yaw_deg": float(u.yaw_deg), "kind": str(u.kind), "mounted": bool(u.mounted), "stage": str(u.stage),
			"strength_pct": float(u.strength), "men_visible": clampi(roundi(float(u.men) / 4.0), 2, 14), "noise_state": _noise_state(u), "detected": bool(u.detected),
			"carry_ratio": float(u.carry_kg) / maxf(float(u.capacity_kg), 1.0) if float(u.capacity_kg) > 0.0 else 0.0,
			"spotted_s": maxf(0.0, float((u.get("spotted", {}) as Dictionary).get("until", t)) - t)})  # la cuenta del aviso de detección (0 si nadie la vio): la vista dibuja el anillo
		if str(u.stage) != "exited":
			pools.append({"x": float(u.x), "z": float(u.z), "r": float(env.visibility_m)})
		if int(u.horses) > 0:
			horses.append({"x": float(u.x), "z": float(u.z), "state": "asegurado"})
	var objs: Array = []
	var enemies: Array = []
	for fid in V.OBJECTIVES:
		var o: Dictionary = state.objectives[fid]
		var cfg: Dictionary = _rules.objectives[fid]
		var c := _hito_pos(str(cfg.hito))
		var known := float(o.reconocido) >= 1.0
		objs.append({"id": fid, "x": c.x, "z": c.y, "state": str(o.state), "toma": float(o.toma), "alert": float(o.alert),
			"garrison_pct": 100.0 * float(o.garrison) / float(o.garrison_max) if known else -1.0, "under_fire": str(o.state) == "asaltado"})
		if known and str(o.state) != "tomado":
			var i := 0
			for s in cfg.sentinels:
				i += 1
				enemies.append({"id": "%s_centinela_%d" % [fid, i], "kind": "centinela", "x": c.x + float(s.dx), "z": c.y + float(s.dz), "alert": float(o.alert), "firing": str(o.state) == "asaltado"})
	var tw: Dictionary = state.objectives.cuartel.tower
	var tower: Dictionary = {}
	if bool(tw.armed):
		var tp := _tower_pos()
		enemies.append({"id": "torre", "kind": "torre", "x": tp.x, "z": tp.y, "alert": 1.0, "firing": bool(tw.active)})
		tower = {"x": tp.x, "z": tp.y, "next_volley_in_s": maxf(0.0, float(tw.next_volley_at) - t) if bool(tw.active) else 0.0, "period_s": float(_rules.tower.volley_period_s),
			"dead_angle_m": float(_rules.tower.dead_angle_m), "firing": bool(tw.active)}
	var loot: Array = []
	for it in state.loot.items:
		if str(it.state) == "entregado":
			continue
		loot.append({"id": str(it.id), "kind": str(it.kind), "state": str(it.state), "x": float(it.x), "z": float(it.z), "qty": int(it.qty)})
	var lines: Array = []
	for l in state.fire_lines:
		lines.append({"from": l.from, "to": l.to, "kind": str(l.kind)})
	var marks: Array = []
	for m in state.diary_marks:
		marks.append(m)
	var lights: Array = []
	for lg in _level.lights:
		lights.append({"id": str(lg.id), "kind": str(lg.kind), "x": float(lg.x), "z": float(lg.z), "r_m": float(lg.r_m), "objective": str(lg.objective)})
	return {"version": int(state.render_version), "t": t, "phase": str(state.phase), "env": env, "units": us, "objectives": objs, "enemies": enemies, "loot": loot,
		"fire_lines": lines, "visibility_pools": pools, "marks": marks, "horses": horses, "lights": lights, "tower": tower}

func _piece_treatment(it: Dictionary) -> String:
	match str(it.state):
		"entregado":
			return "entregar"
		"destruido":
			return "destruir"
		"oculto":
			return "ocultar"
	return "abandonar"

func _tu_partida() -> String:
	var n := {"entregar": 0, "destruir": 0, "ocultar": 0, "abandonar": 0}
	for it in state.loot.items:
		if str(it.kind) == "canones":
			n[_piece_treatment(it)] = int(n[_piece_treatment(it)]) + 1
	var words: Dictionary = _rules.epilogue.piezas
	var vars := {"total": int(n.entregar) + int(n.destruir) + int(n.ocultar) + int(n.abandonar)}
	for pair in [["entregar", "llevadas"], ["destruir", "clavadas"], ["ocultar", "ocultas"], ["abandonar", "abandonadas"]]:
		var form: Array = words[pair[0]]
		vars[pair[1]] = "%d %s" % [int(n[pair[0]]), str(form[0]) if int(n[pair[0]]) == 1 else str(form[1])]
	return _fmt(str(_rules.epilogue.en_tu_partida), vars)

func epilogue() -> Array:
	var out: Array = []
	for line in _rules.epilogue.lines:
		var texto := str(line.texto)
		if str(line.fecha).begins_with("9 al 16") and not state.is_empty() and str(state.status) != "playing":
			texto += " " + _tu_partida()
		out.append({"fecha": str(line.fecha), "texto": texto, "tag": str(line.tag)})
	return out

func campaign_report() -> Dictionary:
	if state.is_empty():
		return {}
	var oc: Dictionary = _rules.outcome
	var out: Dictionary = state.outcome
	var playing := str(state.status) == "playing"
	var l := loot_state()
	var gp: Dictionary = l.golpe
	var golpe := float(gp.entregado) + float(gp.destruido) + float(gp.oculto)
	var loss := _loss_pct()
	var medal := ""
	var medal_label := str(oc.no_medal_label)
	if str(state.status) == "victory":
		medal = "bronce"
		var md: Dictionary = oc.medals
		if golpe >= float(md.plata.golpe_min) and loss <= float(md.plata.loss_max_pct):
			medal = "plata"
		if golpe >= float(md.oro.golpe_min) and loss <= float(md.oro.loss_max_pct) and (state.assists as Array).is_empty() and not bool(state.alarm.reinforcement_arrived):
			medal = "oro"
		medal_label = str(md[medal].label)
	var pieces: Array = []
	for it in state.loot.items:
		if str(it.kind) == "canones":
			pieces.append({"id": str(it.id), "tratamiento": _piece_treatment(it), "estado": str(it.state)})
	var objs: Array = []
	for fid in V.OBJECTIVES:
		objs.append({"id": fid, "nombre": str(_rules.objectives[fid].name), "estado": str(state.objectives[fid].state), "taken_at": float(state.objectives[fid].taken_at)})
	var groups: Array = []
	for u in state.units:
		var s0 := float(state.stats.start_strength[u.id])
		groups.append({"id": str(u.id), "nombre": str(u.name), "tag": str(u.tag), "start_strength": s0, "end_strength": float(u.strength), "loss_pct": clampf(100.0 * (1.0 - float(u.strength) / maxf(s0, 1.0)), 0.0, 100.0)})
	var history: Array = []
	for h in _rules.epilogue.history:
		history.append({"text": str(h.texto), "tag": str(h.tag)})
	var variant := {}
	for dim in R.VARIANTS:
		variant[dim] = state.world[dim]
	var salvados := int(_unit("rodriguez").horses) - int(state.stats.horses_lost)
	var pacing: Dictionary = (state.stats.pacing as Dictionary).duplicate(true)
	return {"status": str(state.status), "reason": str(state.reason), "elapsed": float(state.elapsed), "outcome_title": str(out.get("title", "")), "cause_id": str(out.get("cause_id", "")),
		"cause": str(out.get("cause", "")), "advice": str(out.get("advice", "")), "medal": medal, "medal_label": medal_label,
		"golpe": {"entregado": float(gp.entregado), "destruido": float(gp.destruido), "oculto": float(gp.oculto), "perdido": float(gp.perdido), "total": 100.0},
		"pieces": pieces, "loot_traits": (state.world.loot_traits as Dictionary).duplicate(true), "objectives": objs, "groups": groups, "loss_pct": loss,
		"detections": int(state.stats.detections), "support_events": int(state.stats.support_events), "horses": {"salvados": salvados, "perdidos": int(state.stats.horses_lost)},
		"powder_wet": int(state.stats.powder_wet) > 0, "variant": variant, "route_notes": [], "pacing": pacing, "history": history,
		"epilogue": [] if playing else epilogue(), "assists_used": (state.assists as Array).duplicate(), "mercy_label": str(_tx("mercy.sin_ayudas" if int(state.mercy_level) == 0 else "mercy.con_ayudas"))}

# ---------------------------------------------------------------------------------------------------------------------
# Rutas y reconocimiento (sin efectos)

## Cuánto ve a una agrupación que va con `noise` el centinela más próximo de un frente que sigue en pie: 0 si no lo alcanza y 1 si está encima. Cuenta la visión entre
## los dos (un muro la tapa) y la altura de la batería y de la torre.
func _seen_by(fid: String, p: Vector2, noise: float, vis: float) -> float:
	var reach: float = vis * (1.0 + float(_rules.stealth.detection.noise_mult) * noise) * _o()._vis_mult_at(fid) * _o()._detect_mult()
	var best := 0.0
	var t = _o().terrain()
	for s in _o()._sentinel_points(fid):
		var d := p.distance_to(s)
		if d >= reach:
			continue
		if t != null and t.has_method("los") and not bool(t.call("los", s, p, 1.8, 1.6)):
			continue
		best = maxf(best, 1.0 - d / reach)
	return best

func plan_route(actor_id: String, target: Vector2, opts: Dictionary = {}) -> Dictionary:
	var out := {"ok": false, "reason": "", "path": [], "length_m": 0.0, "time_s": 0.0, "noise": 0.0, "seen_risk": 0.0, "mud_m": 0.0, "unknown_m": 0.0,
		"risk": "bajo", "arrives_before_dawn": true, "warnings": []}
	var u := _unit(actor_id)
	if state.is_empty() or u.is_empty():
		out.reason = _ts("errores.sin_actor")
		return out
	if not _in_map(target):
		out.reason = _ts("errores.fuera_del_mapa")
		return out
	var stops: Array = _waypoints(opts)
	if stops.size() > 4:  # la vista previa promete lo mismo que la orden: hasta 4 paradas y todas dentro del mapa
		out.reason = _ts("errores.paradas")
		return out
	for stop in stops:
		if not _in_map(stop):
			out.reason = _ts("errores.parada_fuera")
			return out
	var pace := str(opts.get("pace", u.pace))
	if not R.PACES.has(pace):
		pace = str(u.pace)
	var from := Vector2(float(u.x), float(u.z))
	var route: Dictionary = _o()._route(from, stops, target)
	if not bool(route.ok):
		out.reason = _ts("avisos_ruta.sin_paso")
		return out
	var pts: Array = [from]
	pts.append_array(route.pts)
	var env := environment()
	var vis := float(env.visibility_m)
	var noise := float(_rules.stealth.pace[pace].noise)
	if float(env.rain) >= 0.5:
		noise *= float(_rules.stealth.rain_noise_mult)
	var mounted := bool(u.mounted)
	var length := 0.0
	var time_s := 0.0
	var mud_m := 0.0
	var risk := 0.0
	var warn_front := ""
	var warn_m := 0
	var step := float(_rules.stealth.plan_sample_m)
	var mud_below := float(_rules.stealth.mud_speed_below)
	for i in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var seg := a.distance_to(b)
		length += seg
		var n := maxi(1, ceili(seg / step))
		var ds := seg / float(n)
		for k in range(n):
			var p := a.lerp(b, (float(k) + 0.5) / float(n))
			time_s += ds / _o()._speed_at(p.x, p.y, pace, mounted)
			if _o()._ground_factor(p.x, p.y, mounted) < mud_below:
				mud_m += ds
			for fid in V.OBJECTIVES:
				if str(state.objectives[fid].state) == "tomado":
					continue
				var seen := _seen_by(fid, p, noise, vis)
				if seen > risk:
					risk = seen
					warn_front = str(_rules.objectives[fid].place)
					warn_m = roundi(vis * (1.0 + float(_rules.stealth.detection.noise_mult) * noise) * _o()._vis_mult_at(fid) * _o()._detect_mult())
	out.ok = true
	var path: Array = []
	for p in pts:
		path.append(_pt((p as Vector2).x, (p as Vector2).y))
	out.path = path
	out.length_m = length
	out.time_s = time_s
	out.noise = noise
	out.seen_risk = risk
	out.mud_m = mud_m
	out.risk = "bajo" if risk < float(_rules.stealth.risk_medium_from) else ("medio" if risk < float(_rules.stealth.risk_high_from) else "alto")
	out.arrives_before_dawn = float(state.elapsed) + time_s < float(_rules.time.alba_start_s)
	var warnings: Array = []
	if not bool(out.arrives_before_dawn):
		warnings.append(_ts("avisos_ruta.alba"))
	if risk >= float(_rules.stealth.risk_medium_from):
		warnings.append(_ts("avisos_ruta.cerca", {"frente": warn_front, "m": warn_m}))
	out.warnings = warnings
	return out

func plan_recon(actor_id: String, points: Array, opts: Dictionary = {}) -> Dictionary:
	var out := {"ok": false, "reason": "", "risk_pct": 0.0, "time_s": 0.0, "reveals": []}
	var u := _unit(actor_id)
	if state.is_empty() or u.is_empty():
		out.reason = _ts("errores.sin_actor")
		return out
	if points.is_empty():
		out.reason = _ts("errores.sin_destino")
		return out
	var rc: Dictionary = _rules.stealth.recon
	var cursor := Vector2(float(u.x), float(u.z))
	var length := 0.0
	var reveals: Array = []
	var alert_sum := 0.0
	for p in points.slice(0, 3):
		if not (p is Vector2) or not _in_map(p):
			out.reason = _ts("errores.fuera_del_mapa")
			return out
		length += cursor.distance_to(p)
		cursor = p
		for fid in V.OBJECTIVES:
			var c := _hito_pos(str(_rules.objectives[fid].hito))
			if (p as Vector2).distance_to(c) <= _recon_radius_for(fid) and not reveals.has(str(_rules.objectives[fid].name)):
				reveals.append(str(_rules.objectives[fid].name))
				alert_sum += float(state.objectives[fid].alert)
	var pace := str(opts.get("pace", u.pace))
	var speed := maxf(float((_rules.stealth.pace[pace] if R.PACES.has(pace) else _rules.stealth.pace.march).speed), 0.1)
	var risk := float(rc.risk_base) + float(rc.risk_per_noise) * float(_rules.stealth.pace.march.noise)
	if not reveals.is_empty():
		risk += float(rc.risk_per_alert) * alert_sum / float(reveals.size())
	out.ok = true
	out.risk_pct = 100.0 * clampf(risk, 0.0, 0.95)
	out.time_s = length / speed + float(rc.duration_s) * float(mini(points.size(), 3))
	out.reveals = reveals
	return out

## Las aproximaciones de cada frente desde la zona de partida: la ruta de A* al puesto de ataque de cada enfoque que tiene el suyo (level.access.attack_posts).
## Solo lectura; `cost_est` = minutos de marcha más el riesgo de que los vean, para comparar enfoques.
func route_atlas(front: String = "") -> Array:
	var out: Array = []
	var from := _hito_pos("zona_partida")
	var env: Dictionary = _o()._env_at(0.0)
	var vis := float(env.visibility_m)
	var pace := "march"
	var noise := float(_rules.stealth.pace[pace].noise) * float(_rules.stealth.rain_noise_mult)
	for fid in V.OBJECTIVES:
		if front != "" and fid != front:
			continue
		var posts: Array = _level.access.attack_posts[fid]
		for p in posts:
			var approach := str(p.get("approach", ""))
			if not (R.APPROACHES[fid] as Array).has(approach):
				continue
			var post := Vector2(float(p.x), float(p.z))
			var route: Dictionary = _o()._route(from, [], post)
			if not bool(route.ok):
				continue
			var pts: Array = [from]
			pts.append_array(route.pts)
			var length := 0.0
			var time_s := 0.0
			var risk := 0.0
			for i in range(pts.size() - 1):
				var a: Vector2 = pts[i]
				var b: Vector2 = pts[i + 1]
				var seg := a.distance_to(b)
				length += seg
				var n := maxi(1, ceili(seg / float(_rules.stealth.plan_sample_m)))
				for k in range(n):
					var q := a.lerp(b, (float(k) + 0.5) / float(n))
					time_s += (seg / float(n)) / _o()._speed_at(q.x, q.y, pace, false)
					for other in V.OBJECTIVES:
						risk = maxf(risk, _seen_by(other, q, noise, vis))
			out.append({"front": fid, "approach": approach, "length_m": length, "time_s": time_s, "seen_risk": risk, "unknown_m": 0.0,
				"cost_est": time_s / float(_rules.combat.cost_minutes_div) + 100.0 * risk})
	return out
