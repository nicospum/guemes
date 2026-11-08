extends RefCounted
## Lo que pasa en el campo del nivel «humahuaca» aparte de la marcha y el combate (CONTRATO 3.2): la alarma que corre, la guardia que sale, el jinete al sur, la torre
## del cuartel, el reconocimiento, el botín (cargar, destruir, salir) y las decisiones de campo (pending_choice / resolve_choice: el informante). Dueña: reglas_historia.
## Existe aparte para que cada archivo del nivel quede por debajo de las ~1 500 líneas del contrato (se parte por responsabilidad); humahuaca_rules.gd lo crea al primer
## uso y le delega. No guarda estado propio: lee y escribe el `state` del dueño por una referencia DÉBIL (una fuerte formaría un ciclo). Determinismo: solo el RNG
## congruencial del dueño (`_random`). Independencia (V19): solo importa vocabularios y datos; al dueño lo recibe por parámetro.

const V = preload("res://scripts/humahuaca/humahuaca_vocab.gd")
const R = preload("res://scripts/humahuaca/rules/vocab_rules.gd")
const D = preload("res://scripts/humahuaca/rules/humahuaca_data.gd")

const INFORMANT_DIM := "torre_en"  # de qué habla el informante: dónde está la torre con tiradores (la dimensión del mundo que el briefing no dice)

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

# Lo que esta parte necesita del dueño (reenvíos tipados)
func _tx(path: String) -> Variant:
	return D.tx(path)

func _ts(path: String, vars: Dictionary = {}) -> String:
	return D.ts(path, vars)

func _no(key: String, vars: Dictionary = {}) -> Dictionary:
	return _o()._no(key, vars)

func _hito_pos(id: String) -> Vector2:
	return D.hito(id)

func _unit(id: String) -> Dictionary:
	return _o()._unit(id)

func _event(kind: String, text: String, extra: Dictionary = {}) -> void:
	_o()._event(kind, text, extra)

func _bump() -> void:
	_o()._bump()

func _random() -> float:
	return _o()._random()

func terrain() -> RefCounted:
	return _o().terrain()

func environment() -> Dictionary:
	return _o().environment()

func _guard_cfg() -> Dictionary:
	return _o()._guard_cfg()

func _detect_mult() -> float:
	return _o()._detect_mult()

func _sentinel_sees(fid: String, u: Dictionary, vis: float) -> bool:
	return _o()._sentinel_sees(fid, u, vis)

func _record_offer(t: float, offered: bool) -> void:
	_o()._record_offer(t, offered)

static func _pt(x: float, z: float) -> Dictionary:
	return {"x": x, "z": z}

# ---------------------------------------------------------------------------------------------------------------------
# Rutas que rodean a los centinelas

## La grilla con la que se arma una ruta ahora: antes de la señal, la que rodea a cada centinela de un frente en pie (stealth.route_avoid: un costo extra dentro de
## su radio, ×1,25 en la altura de la batería y en la torre armada, y con el `detect_mult` de la guardia del mundo). Una ruta de aproximación no pasa por delante de
## la guardia si hay otro camino; si el destino está adentro (reconocer, un puesto pegado), entra igual. Después de la señal, la grilla de siempre.
func route_nav(n: RefCounted) -> RefCounted:
	var cfg: Dictionary = (_rules.stealth as Dictionary).get("route_avoid", {})
	if cfg.is_empty() or state.is_empty() or bool(state.alarm.signaled):
		return n
	var circles: Array = []
	var key := ""
	for fid in V.OBJECTIVES:
		if str(state.objectives[fid].state) == "tomado":
			continue
		var r := snappedf(float(cfg.radius_m) * float(_o()._vis_mult_at(fid)) * _detect_mult(), 1.0)
		key += "%s:%d|" % [fid, int(r)]
		for p in _o()._sentinel_points(fid):
			circles.append({"c": p, "r": r})
	return n.call("avoiding", key, circles, float(cfg.weight_mult))

# ---------------------------------------------------------------------------------------------------------------------
# Alarma antes de la señal: la guardia que sale, el jinete y la voz que corre

## El frente pasa a «en alarma». Solo cuenta como alarma por haberlos visto (`seen`) la que saltó con una agrupación a la vista: el desvelo del alba también la
## levanta (a las 6:00 «está en alarma aunque nadie haya disparado») y esa es del reloj. Si los vieron antes de la señal, la guardia sale entera y manda un jinete al sur.
func _raise_alarm(fid: String, o: Dictionary, seen: bool, t: float) -> void:
	var al: Dictionary = state.alarm
	o.state = "en_alarma"
	_event("alarm", _ts("eventos.alarma", {"frente": str(_rules.objectives[fid].full_name)}), {"objective": fid, "strong": true})
	_bump()
	if seen and not bool(al.signaled) and not (al.pre_signal as Array).has(fid):
		(al.pre_signal as Array).append(fid)
		_turnout(fid, o)
		if str(al.messenger) == "none":
			al.messenger = "sent"
			al.messenger_at = t
		## la guardia atenta («lo había esperado noches antes») corre la voz a los otros frentes en enemy.guard.atenta.spread_alarm_s; la descuidada no
		if _guard_cfg().has("spread_alarm_s") and float(al.get("spread_at", -1.0)) < 0.0:
			al.spread_at = t + float(_guard_cfg().spread_alarm_s)

## La voz que corre: pasado alarm.spread_at sin señal, los frentes que faltaban entran en alarma como si los hubieran visto (la guardia entera los espera).

## La voz que corre: pasado alarm.spread_at sin señal, los frentes que faltaban entran en alarma como si los hubieran visto (la guardia entera los espera).
func _step_spread(t: float) -> void:
	var al: Dictionary = state.alarm
	if float(al.get("spread_at", -1.0)) < 0.0 or t < float(al.spread_at) or bool(al.signaled):
		return
	al.spread_at = -1.0
	_event("alarm", _ts("eventos.alarma_corre"), {"strong": true})
	for fid in V.OBJECTIVES:
		var o: Dictionary = state.objectives[fid]
		if str(o.state) == "tomado" or (al.pre_signal as Array).has(fid):
			continue
		o.alert = 1.0
		if str(o.state) == "guardado" or str(o.state) == "alertado":
			_raise_alarm(fid, o, true, t)

## La guardia que dio la alarma antes de la señal sale entera a los puestos (enemy.alert.turnout_garrison_mult): ese frente se defiende con más gente y atrincherado.

## La guardia que dio la alarma antes de la señal sale entera a los puestos (enemy.alert.turnout_garrison_mult): ese frente se defiende con más gente y atrincherado.
func _turnout(fid: String, o: Dictionary) -> void:
	var mult := float(_rules.enemy.alert.get("turnout_garrison_mult", 1.0))
	if mult <= 1.0 or bool(o.get("turned_out", false)):
		return
	o.turned_out = true
	o.garrison_max = float(o.garrison_max) * mult
	o.garrison = float(o.garrison_max) * (1.0 - float(o.toma) / 100.0)
	_event("alarm", _ts("eventos.guardia_sale", {"frente": str(_rules.objectives[fid].place)}), {"objective": fid})

## El jinete que la guardia manda al sur cuando los ve antes de la señal: si nadie lo corta en messenger.leaves_after_alarm_s, escapa y el refuerzo se adelanta
## reinforcement.messenger_advance_s (ya mismo si la señal ya se dio; si no, al armar el reloj). El jugador lo ve: hay evento y la banda del HUD se acorta.

## El jinete que la guardia manda al sur cuando los ve antes de la señal: si nadie lo corta en messenger.leaves_after_alarm_s, escapa y el refuerzo se adelanta
## reinforcement.messenger_advance_s (ya mismo si la señal ya se dio; si no, al armar el reloj). El jugador lo ve: hay evento y la banda del HUD se acorta.
func _step_messenger(t: float) -> void:
	var al: Dictionary = state.alarm
	if str(al.messenger) != "sent":
		return
	if t < float(al.get("messenger_at", t)) + float(_rules.enemy.messenger.leaves_after_alarm_s):
		return
	al.messenger = "escaped"
	if float(al.reinforcement_at) >= 0.0:
		al.reinforcement_at = float(al.reinforcement_at) - float(_rules.reinforcement.get("messenger_advance_s", 0.0))
	_event("messenger", _ts("eventos.mensajero"), {"strong": true})
	_bump()

# ---------------------------------------------------------------------------------------------------------------------
# Torre del cuartel (12 descargas de 7,5 s; el hueco de recarga es la ventana de cruce)

## ¿La carga sobre el cuartel sale en el hueco de recarga de la torre (o con la torre callada)? Es la medida de la compuerta 11: el tiempo hasta la próxima descarga
## alcanza para cruzar de la calle al pie de la torre antes de que dispare.
func _tower_in_gap() -> bool:
	var tw: Dictionary = state.objectives.cuartel.tower
	if not bool(tw.active):
		return true
	return float(tw.next_volley_at) - float(state.elapsed) >= float(_rules.tower.cross_gap_s)

func _tower_pos() -> Vector2:
	return _hito_pos(str(_rules.tower.hito[str(state.world.torre_en)]))

## Cuánto daño le toca a una agrupación en una descarga: 0 si está fuera del radio, a salvo en el ángulo muerto o tapada por la vista; ×2 en la calle abierta,
## ×0,5 detrás de una tapia y ×0,3 si cruza corriendo. Quien asalta el cuartel baja por la calle bajo la torre aunque su puesto quede un poco más lejos.

## Cuánto daño le toca a una agrupación en una descarga: 0 si está fuera del radio, a salvo en el ángulo muerto o tapada por la vista; ×2 en la calle abierta,
## ×0,5 detrás de una tapia y ×0,3 si cruza corriendo. Quien asalta el cuartel baja por la calle bajo la torre aunque su puesto quede un poco más lejos.
func _tower_hit_mult(u: Dictionary, tp: Vector2) -> float:
	var tcfg: Dictionary = _rules.tower
	var dm: Dictionary = tcfg.damage_mult
	var up := Vector2(float(u.x), float(u.z))
	var d := up.distance_to(tp)
	var st := str(u.stage)
	var storming := st == "attacking" and str(u.order.get("front", "")) == "cuartel"
	if d <= float(tcfg.dead_angle_m) or (d > float(tcfg.radius_m) and not storming):
		return 0.0
	var t := terrain()
	var seen := t == null or not t.has_method("los") or bool(t.call("los", tp, up, float(tcfg.eye_m), 1.6))
	if not seen and not storming:
		return 0.0
	if storming:
		## por dónde entra importa: la calle queda a la vista de la torre de la casa del cura y tapada para la del templo; los patios, al revés (tower.approach_mult)
		var am: Dictionary = tcfg.get("approach_mult", {})
		var by_approach: Dictionary = am.get(str(u.order.get("approach", "")), {})
		var exposure := float(by_approach.get(str(state.world.torre_en), 1.0))
		return (float(dm.calle_abierta) if str(u.order.get("posture", "")) == "a_fondo" else float(dm.tapia)) * exposure
	if st == "moving" and (str(u.pace) == "run" or str(u.pace) == "gallop" or str(u.pace) == "trot"):
		return float(dm.corriendo)
	if t != null and t.has_method("surface_at") and str(t.call("surface_at", up.x, up.y)) == "camino":
		return float(dm.calle_abierta)
	return 1.0

func _step_tower(t: float) -> void:
	var tw: Dictionary = state.objectives.cuartel.tower
	var tcfg: Dictionary = _rules.tower
	if not bool(tw.armed) and bool(state.alarm.signaled) and str(state.objectives.cuartel.state) != "tomado":
		if t >= float(state.alarm.first_shot_at) + float(tcfg.arm_delay_s[str(state.world.guardia)]):
			tw.armed = true
			tw.active = true
			tw.next_volley_at = t + float(tcfg.volley_period_s)
			_event("tower", _ts("eventos.torre"), {"objective": "cuartel", "pos": _pt(_tower_pos().x, _tower_pos().y)})
			_bump()
	if not bool(tw.active):
		return
	if int(tw.volleys_left) <= 0:  # sin munición no hay descarga (un guardado editado puede traer la torre «activa» y vacía)
		tw.active = false
		return
	if t + 1e-9 < float(tw.next_volley_at):
		return
	var tp := _tower_pos()
	for u in state.units:
		var st := str(u.stage)
		if st == "exited" or st == "routed":
			continue
		if float(u.get("tower_cover_until", -1.0)) > t:
			continue  # cruzó en el hueco de recarga: esta descarga lo encuentra al pie de la torre
		var mult := _tower_hit_mult(u, tp)
		if mult <= 0.0:
			continue
		var jitter := 1.0 + float(tcfg.jitter) * (_random() - 0.5)
		u.strength = maxf(0.0, float(u.strength) - float(tcfg.damage_per_volley_pct) * mult * jitter)
		(state.fire_lines as Array).append({"from": _pt(tp.x, tp.y), "to": _pt(float(u.x), float(u.z)), "kind": "torre", "until": t + 1.5})
	tw.volleys_left = int(tw.volleys_left) - 1
	tw.next_volley_at = t + float(tcfg.volley_period_s)
	if int(tw.volleys_left) <= 0:
		tw.active = false
		_event("tower", _ts("eventos.torre_calla"), {"objective": "cuartel"})
		_bump()

# ---------------------------------------------------------------------------------------------------------------------
# Reconocimiento y botín

func _recon_radius_for(fid: String) -> float:
	var rc: Dictionary = _rules.stealth.recon
	var base := float(rc.radius_m)
	if float(environment().visibility_m) < float(rc.dark_below_m):
		base = float(rc.radius_dark_m)
	for lg in _level.lights:
		if str(lg.get("objective", "")) == fid:
			return maxf(base, float(rc.lit_radius_m))
	return base

func _complete_recon(u: Dictionary) -> void:
	var rc: Dictionary = _rules.stealth.recon
	for fid in V.OBJECTIVES:
		var c := _hito_pos(str(_rules.objectives[fid].hito))
		if D.dist(float(u.x), float(u.z), c.x, c.y) > _recon_radius_for(fid):
			continue
		var o: Dictionary = state.objectives[fid]
		var first := float(o.reconocido) < 1.0
		o.reconocido = 1.0
		if not (state.recon.fronts as Array).has(fid):
			(state.recon.fronts as Array).append(fid)
		if first:
			_event("recon", _ts("eventos.reconocido", {"texto": str(_rules.objectives[fid].reveal_text)}), {"objective": fid, "unit": str(u.id), "pos": _pt(c.x, c.y), "strong": true})
		## el riesgo de que los vean crece con la guardia atenta (detect_mult) y con la alerta del frente; si los ven, la guardia descuidada apenas se inquieta
		## (alert_when_seen) y la atenta sale a buscarlos (enemy.guard.<guardia>.recon_seen_alert = 1: alarma, con todo lo que trae antes de la señal).
		## Y si el reconocedor se paró a mirar dentro del alcance de un centinela que lo tiene a la vista (la guardia atenta ve más lejos de lo que él mira), lo ven seguro.
		var risk := (float(rc.risk_base) + float(rc.risk_per_noise) * float(_rules.stealth.pace[str(u.pace)].noise)) * _detect_mult() + float(rc.risk_per_alert) * float(o.alert)
		var probe := {"x": float(u.x), "z": float(u.z), "noise": float(_rules.stealth.pace[str(u.pace)].noise)}
		risk = maxf(risk, float(_guard_cfg().get("recon_seen_prob", 0.0)))  # la guardia atenta tiene centinelas adelantados: a quien se para a mirar lo ve siempre
		if _sentinel_sees(fid, probe, float(environment().visibility_m)) or _random() < risk:
			## la guardia que da la alarma cuando los ve (recon_seen_alert ≥ lo que falta) no la da de golpe: el centinela los vio y tarda `recon_warn_s` en estar
			## seguro. Es la ventana del aviso (estilo Shadow Tactics / Desperados): si los reconocedores se retiran a tiempo, no hay alarma (_step_spotted).
			var warn_s := float(_guard_cfg().get("recon_warn_s", 0.0))
			var gain := float(_guard_cfg().get("recon_seen_alert", rc.alert_when_seen))
			if warn_s > 0.0 and float(o.alert) + gain >= float(_rules.enemy.alert.alarma_at) and (u.get("spotted", {}) as Dictionary).is_empty():
				u["spotted"] = {"front": fid, "until": float(state.elapsed) + warn_s, "x": float(u.x), "z": float(u.z)}
				_event("warning", _ts("eventos.reconocedores_vistos", {"frente": str(_rules.objectives[fid].place), "s": roundi(warn_s)}), {"objective": fid, "unit": str(u.id), "strong": true})
			else:
				_spotted_detection(u, fid, gain)
	_bump()

## Los vieron de verdad: la alerta del frente sube (`gain`) y, si llega a la alarma, la guardia sale (con lo que trae antes de la señal: jinete, voz que corre).
func _spotted_detection(u: Dictionary, fid: String, gain: float) -> void:
	var o: Dictionary = state.objectives[fid]
	u.detected = true
	state.stats.detections = int(state.stats.detections) + 1
	o.alert = minf(1.0, float(o.alert) + gain)
	_event("detected", _ts("eventos.detectado", {"frente": str(_rules.objectives[fid].place)}), {"objective": fid, "unit": str(u.id)})
	if float(o.alert) >= float(_rules.enemy.alert.alarma_at) and (str(o.state) == "guardado" or str(o.state) == "alertado"):
		_raise_alarm(fid, o, true, float(state.elapsed))

## La ventana del aviso de los reconocedores vistos: si se alejaron `recon_warn_escape_m` del lugar donde los vieron, se salvan (la alerta queda como estaba más
## lo que sumó verlos irse); si se vence el plazo y siguen ahí, el centinela da la voz. El frente tomado o la señal dada terminan la ventana sin alarma.
func _step_spotted(t: float) -> void:
	for u in state.units:
		var sp: Dictionary = u.get("spotted", {})
		if sp.is_empty():
			continue
		var fid := str(sp.front)
		var gone := D.dist(float(u.x), float(u.z), float(sp.x), float(sp.z)) >= float(_guard_cfg().get("recon_warn_escape_m", 8.0)) or str(u.stage) == "exited"
		if gone or bool(state.alarm.signaled) or str(state.objectives[fid].state) == "tomado":
			u.erase("spotted")
			if gone:
				_event("info", _ts("eventos.reconocedores_a_salvo", {"frente": str(_rules.objectives[fid].place)}), {"objective": fid, "unit": str(u.id)})
			_bump()
		elif t + 1e-9 >= float(sp.until):
			u.erase("spotted")
			_spotted_detection(u, fid, float(_guard_cfg().get("recon_seen_alert", _rules.stealth.recon.alert_when_seen)))
			_bump()

func _item(id: String) -> Dictionary:
	for it in state.loot.items:
		if str(it.id) == id:
			return it
	return {}

func _item_kg(it: Dictionary) -> float:
	return float(it.qty) * float(it.unit_kg)

func _item_value(it: Dictionary) -> float:
	return float(it.qty) * float(it.unit_value)

## El lote en sitio de un frente ya tomado que más puntos da por kilo, que entre en `room_kg` (o -1 para cualquiera), cerca de `near` si se pide.

## El lote en sitio de un frente ya tomado que más puntos da por kilo, que entre en `room_kg` (o -1 para cualquiera), cerca de `near` si se pide.
func _best_item(room_kg: float, near: Variant = null, radius: float = -1.0, destroying: bool = false) -> Dictionary:
	var best: Dictionary = {}
	var best_density := -1.0
	for it in state.loot.items:
		if str(it.state) != "en_sitio" or str(state.objectives[str(it.front)].state) != "tomado":
			continue
		if room_kg >= 0.0 and _item_kg(it) > room_kg + 1e-6:
			continue
		if near is Vector2 and radius >= 0.0 and D.dist(float(it.x), float(it.z), (near as Vector2).x, (near as Vector2).y) > radius:
			continue
		var density := _item_value(it) / _item_kg(it)
		if destroying:
			density = _item_value(it) / float(_rules.loot.classes[str(it.kind)].destroy_s)  # lo que más valor quita por segundo
		if density > best_density:
			best_density = density
			best = it
	return best

func _complete_load(u: Dictionary, item_id: String) -> void:
	var it := _item(item_id)
	if it.is_empty() or str(it.state) != "en_sitio":
		return
	it.state = "cargado"
	it.carried_by = str(u.id)
	u.carry_kg = float(u.carry_kg) + _item_kg(it)
	state.loot.load_kg = float(state.loot.load_kg) + _item_kg(it)
	_event("load", _ts("eventos.carga", {"carga": "%s (%d kg)" % [str(_rules.loot.classes[str(it.kind)].name).to_lower(), roundi(_item_kg(it))]}), {"unit": str(u.id)})

func _complete_destroy(u: Dictionary, item_id: String) -> void:
	var it := _item(item_id)
	if it.is_empty() or str(it.state) != "en_sitio":
		return
	it.state = "destruido"
	var kept := _item_value(it) * float(_rules.loot.treatments.destruir)
	state.loot.destroyed_value = float(state.loot.destroyed_value) + kept
	state.loot.lost_value = float(state.loot.lost_value) + _item_value(it) - kept  # lo que destruir no puntúa se pierde: al cierre entregado + destruido + oculto + perdido suman 100
	_event("destroy", _ts("eventos.destruido", {"carga": str(_rules.loot.classes[str(it.kind)].name).to_lower()}), {"unit": str(u.id)})
	if str(it.kind) == "polvora":
		var sm: Dictionary = _rules.reinforcement.smoke_advance_s
		var per := float(sm.first) if int(state.smoke_used) == 0 else float(sm.next)
		var adv := minf(per, float(sm.cap) - float(state.smoke_adv))
		if float(state.alarm.reinforcement_at) >= 0.0 and adv > 0.0:
			var lead := float(_rules.reinforcement.warning_lead_s)
			var t := float(state.elapsed)
			var warned_before := t >= float(state.alarm.reinforcement_at) - lead  # el aviso «Polvareda al sur» ya salió con el reloj viejo
			state.alarm.reinforcement_at = float(state.alarm.reinforcement_at) - adv
			state.smoke_adv = float(state.smoke_adv) + adv
			if not warned_before and t >= float(state.alarm.reinforcement_at) - lead and not bool(state.alarm.reinforcement_arrived):
				## el humo adelantó el refuerzo por encima del cruce del aviso: el aviso sale ahora, no se saltea (A-11)
				_event("reinforcement_warning", _ts("eventos.refuerzo_visto"), {"strong": true})
		state.smoke_used = int(state.smoke_used) + 1

func _exit_unit(u: Dictionary) -> void:
	var l: Dictionary = state.loot
	var delivered := 0.0
	var kg := 0.0
	for it in l.items:
		if str(it.state) == "cargado" and str(it.carried_by) == str(u.id):
			var mult := float(_rules.loot.treatments.entregar)
			if bool(it.get("wet", false)):
				mult *= float(_rules.loot.powder_wet_mult)
				state.stats.powder_wet = 1
			delivered += _item_value(it) * mult
			kg += _item_kg(it)
			it.state = "entregado"
			it.carried_by = ""
	l.delivered_value = float(l.delivered_value) + delivered
	l.load_kg = maxf(0.0, float(l.load_kg) - kg)
	u.carry_kg = 0.0
	u.stage = "exited"
	u.order = {}
	u.path = []
	_event("exit", _ts("eventos.salio", {"kg": roundi(kg)}), {"unit": str(u.id), "strong": true})
	_bump()

# ---------------------------------------------------------------------------------------------------------------------
# Decisiones de campo (CONTRATO 3.2: pending_choice / resolve_choice). Hoy, una: el informante de los 0:45 (rules.field_events.informante), que trae dos versiones
# sobre dónde está la torre con tiradores; una es cierta con la fiabilidad del JSON. Lo que se cree queda en state.world.rumors (shown: true) y el «siguiente paso»
# manda a Portal por el enfoque que esa torre no barre. Sin respuesta en vence_s, se toma la primera versión (el reloj no se bloquea: pausa corta de la interfaz).

## La decisión pendiente, si la hay. La API `pending_choice()` del contrato devuelve {} en esta versión: la interfaz detiene el reloj de QA mientras hay una
## decisión sin resolver y la resuelve con su propio reloj de pared, que sin ventana no corre; por eso la decisión se ofrece como un aviso con botón (hud_state().alertas,
## id «informante»): el botón cree la segunda versión y, pasado vence_s de juego, se toma la primera. resolve_choice() sigue siendo la forma de contestar.
func pending_choice() -> Dictionary:
	return {}

func pending_decision() -> Dictionary:
	var d: Variant = state.get("decision", {})
	return (d as Dictionary).duplicate(true) if d is Dictionary else {}

## Abre el informante a su hora y resuelve sola la decisión vencida.
func _step_decisions(t: float) -> void:
	var fe: Dictionary = _rules.get("field_events", {})
	var pending: Dictionary = state.get("decision", {})
	if not pending.is_empty():
		if t >= float(pending.get("at", 0.0)) + float(pending.get("vence_s", 25.0)):
			resolve_choice(str(pending.get("default", "")), true)
		return
	if not fe.has("informante") or bool(state.alarm.signaled) or (state.get("decisions_done", []) as Array).has("informante"):
		return
	var inf: Dictionary = fe.informante
	if t < float(inf.at_s):
		return
	var dim := INFORMANT_DIM
	var values: Array = (R.VARIANTS[dim] as Array).duplicate()
	var truth := str(state.world[dim])
	var other := ""
	for v in values:
		if str(v) != truth:
			other = str(v)
	var first_is_true := _random() < float(inf.get("reliability", 0.75))
	var first := truth if first_is_true else other
	var second := other if first_is_true else truth
	var opciones: Array = []
	for val in [first, second]:
		var lugar := _tower_place(val)
		opciones.append({"id": "creer_" + val, "label": D.fmt(str(inf.label), {"lugar": lugar}), "costo_txt": str(inf.get("costo_txt", "")), "val": val})
	state.decision = {"id": "informante", "titulo": str(inf.titulo), "texto": str(inf.texto), "opciones": opciones, "vence_s": float(inf.get("vence_s", 25.0)),
		"default": str(opciones[0].id), "at": t, "dim": dim}
	(state.get("decisions_done", []) as Array).append("informante")
	if not state.has("decisions_done"):
		state.decisions_done = ["informante"]
	_event("decision", _ts("eventos.informante"), {"strong": true, "options": opciones.duplicate(true), "until": t + float(inf.get("vence_s", 25.0))})
	_bump()

## Resuelve la decisión pendiente con una de sus opciones legales. {"ok", "reason"}.
func resolve_choice(option_id: String, by_timeout: bool = false) -> Dictionary:
	var pending: Dictionary = state.get("decision", {})
	if pending.is_empty():
		return _no("sin_decision")
	var chosen: Dictionary = {}
	for op in pending.opciones:
		if str(op.id) == option_id:
			chosen = op
	if chosen.is_empty():
		return _no("opcion_ilegal")
	var t := float(state.elapsed)
	if str(pending.id) == "informante":
		var dim := str(pending.get("dim", INFORMANT_DIM))
		var val := str(chosen.val)
		(state.world.rumors as Array).append({"id": "informante", "dim": dim, "val": val, "reliability": float(_rules.field_events.informante.get("reliability", 0.75)), "shown": true})
		var lugar := _tower_place(val)
		var enfoque := "los patios" if val == "casa_cura" else "la calle"
		_event("decision", _ts("eventos.decision_vencida" if by_timeout else "eventos.decision_tomada", {"lugar": lugar, "enfoque": enfoque}))
	state.decision = {}
	if not by_timeout:
		_record_offer(t, true)
	_bump()
	return {"ok": true, "reason": ""}

## «el templo» / «la casa del cura» (rules.texts.torre_lugar); el id si no hay texto.
func _tower_place(val: String) -> String:
	var names: Variant = _tx("torre_lugar")
	if names is Dictionary and (names as Dictionary).has(val):
		return str((names as Dictionary)[val])
	return val

## Dónde cree el jugador que está la torre (lo que le creyó al informante); "" si no decidió nada.
func believed_tower() -> String:
	for r in state.world.get("rumors", []):
		if str(r.get("dim", "")) == "torre_en" and bool(r.get("shown", false)):
			return str(r.get("val", ""))
	return ""
