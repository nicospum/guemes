extends RefCounted
## HumahuacaPolicies: la biblioteca ÚNICA de políticas del nivel «humahuaca» (CONTRATO 3.2.5). Dueña: reglas_historia. Nadie escribe un segundo juego de bots: las
## pruebas de reglas, tools/humahuaca_playthrough.gd y la política de interfaz usan estas mismas funciones.
##
## Una política decide órdenes a partir de lo que el jugador puede ver (`view`): hud_state(), render_state() y consultas de solo lectura. Solo `experto` y las
## políticas de enfoque y de extracción (`est_*`, `ext_*`, `barrido_senal`) reciben además `omniscient: true` (conocen el mundo y el reloj del refuerzo); el obediente,
## el torpe, los ciegos, el pasivo, «pausa y reanuda» y el aleatorio NO leen estado oculto: el QA lo audita (P6-d de QA_NIVEL2.md) y esta biblioteca guarda lo oculto
## en una sola función (`_secret`), que solo llaman las políticas con ventaja.
##   - experto: conoce el mundo; ejecuta el mejor plan de su familia (reconoce la batería, lleva cada partida a su puesto, da la señal cuando conviene, socorre,
##     carga lo que más puntos da por kilo y sale antes del refuerzo).
##   - obediente: solo ejecuta lo que dice `hud_state().siguiente`. Torpe: el obediente con demoras de 2 a 8 s, que ignora el 30 % de los avisos no urgentes y falla
##     la sincronía de la señal ± 15 s. Ciegos: el experto sin su ventaja (sin reconocer, tarde, un solo frente, sin arreo). Pasivo y «pausa y reanuda»: no hacen nada.
##     Aleatorio: órdenes al azar (robustez, no juega a ganar).
##   - est_<frente>_<enfoque> y ext_<receta>: el experto con un enfoque de frente o una receta de extracción fijos. Las que piden acciones de R2a (distraer, voltear las
##     piezas, ocultar) todavía no existen: `is_implemented()` dice que no y las herramientas las anotan como omitidas, no como error.
## El azar de las políticas es propio (un congruencial en `view.mem`, nunca el de Godot): la misma semilla da la misma partida. Independencia (V19): solo importa vocabularios.

const V = preload("res://scripts/humahuaca/humahuaca_vocab.gd")
const R = preload("res://scripts/humahuaca/rules/vocab_rules.gd")
const D = preload("res://scripts/humahuaca/rules/humahuaca_data.gd")

const FIXED := ["experto", "obediente", "torpe", "ciego_sin_recon", "ciego_tarde", "ciego_un_frente", "ciego_sin_arreo", "pasivo", "pausa_reanuda", "aleatorio"]
const TAIL := ["barrido_senal", "interfaz"]
## Las políticas que ya juegan (el resto existe en la lista del contrato y se omite con motivo hasta su ronda). Los ciegos, las estrategias de frente y las recetas de
## extracción están armadas sobre el mismo plan del experto (`_plan_for`): desde el balance de R2b se miden (el mundo se sortea, la guardia atenta castiga el
## reconocimiento, el enfoque del cuartel cambia el fuego de la torre y el reloj del refuerzo hay que conocerlo). Las que piden distraer, voltear piezas u ocultar
## (acciones de R2a que todavía no existen) siguen omitidas con motivo.
const IMPLEMENTED := ["experto", "obediente", "torpe", "pasivo", "pausa_reanuda", "aleatorio", "barrido_senal", "ciego_sin_recon", "ciego_tarde", "ciego_un_frente",
	"ciego_sin_arreo", "est_bateria_frontal", "est_bateria_gola", "est_cuartel_calle", "est_cuartel_patios", "est_posta_directa", "ext_cargar_todo", "ext_destruir_todo",
	"ext_ligera", "ext_mixta"]
const WITH_ADVANTAGE := ["experto", "barrido_senal"]
const STEP_S := 1.0  # cada cuánto decide una política (segundos de juego)
const PATH_DETOUR := 1.2  # cuánto más larga que la recta es la ruta real del arreo (A*, barro, vado): margen del plan de carga del experto
const GROUP_DESTROY_REACH_M := 300.0  # hasta dónde va una partida libre a destruir lo que el plan de carga deja: de la batería o el cuartel a la posta, mientras la columna marcha al vado
const LEAVE_SPARE_S := 0.0  # el experto sale con este sobrante sobre la marcha al vado (que ya trae el margen de salida) mientras las partidas destruyen
const PLAN_UNTAKEN_WAIT_S := 60.0  # el plan de carga reserva mulas para un frente que todavía no cayó solo si sobra este tiempo (lo que suele tardar en caer)
const ATTACK_LOAD_TRAVEL_S := 40.0  # durante el ataque el arreo solo carga lotes a menos de este viaje (no cruza el pueblo bajo la torre por una pieza)
const LCG_MOD := 2147483647

# ---------------------------------------------------------------------------------------------------------------------
# Registro

## Todos los nombres del contrato, en su orden.
static func list() -> Array:
	var out: Array = FIXED.duplicate()
	for fid in V.OBJECTIVES:
		for ap in R.APPROACHES[fid]:
			out.append("est_%s_%s" % [fid, ap])
	for rc in R.EXTRACTIONS:
		out.append("ext_" + str(rc))
	out.append_array(TAIL)
	return out

static func is_implemented(policy: String) -> bool:
	return IMPLEMENTED.has(policy)

## Por qué no juega una política que todavía no existe (vacío si juega).
static func skip_reason(policy: String) -> String:
	if not list().has(policy):
		return "no está en la lista de políticas del contrato"
	if policy == "interfaz":
		return "juega con clics sobre la escena real: hace falta --level=scene"
	if policy == "est_bateria_distraccion" or policy == "est_cuartel_piezas" or policy == "est_posta_distraccion" or policy == "ext_ocultar":
		return "pide una acción de R2a (distraer, voltear las piezas u ocultar)"
	return "" if is_implemented(policy) else "todavía no existe"

## La familia de la política, como la agrupa qa_balance.py.
static func family(policy: String) -> String:
	if policy.begins_with("ciego_"):
		return "ciego"
	if policy.begins_with("est_"):
		return "estrategia"
	if policy.begins_with("ext_"):
		return "extraccion"
	return policy

static func has_advantage(policy: String) -> bool:
	return WITH_ADVANTAGE.has(policy) or policy.begins_with("est_") or policy.begins_with("ext_")

# ---------------------------------------------------------------------------------------------------------------------
# La vista: lo que el jugador puede ver

## La vista de una política. `rules` es la partida en curso; `mem` es la memoria de la política, que la acompaña toda la partida. Una política sin ventaja no recibe
## el estado de las reglas ni nada que no se vea en pantalla.
static func make_view(rules: RefCounted, policy: String, mem: Dictionary) -> Dictionary:
	var t := float(rules.state.elapsed)
	var view := {"t": t, "phase": str(rules.state.phase), "hud": rules.call("hud_state"), "render": rules.call("render_state"), "signal": rules.call("signal_info"),
		"loot": rules.call("loot_state"), "env": rules.call("environment"), "mem": mem, "omniscient": has_advantage(policy), "pending": rules.call("pending_choice")}
	if bool(view.omniscient):
		view["secret"] = rules.state
	return view

## Lo que solo sabe quien conoce el mundo (el reloj del refuerzo, la guardia real). Únicamente lo llaman las políticas con ventaja.
static func _secret(view: Dictionary) -> Dictionary:
	return view.get("secret", {}) if bool(view.get("omniscient", false)) else {}

static func _order(actor: String, action: String, target: Vector2 = Vector2.ZERO, opts: Dictionary = {}) -> Dictionary:
	return {"actor": actor, "action": action, "target": target, "opts": opts}

## Aplica las órdenes a las reglas por su API pública. Devuelve el resultado de cada una ({"ok", "reason", ...}).
static func apply_orders(rules: RefCounted, orders: Array) -> Array:
	var out: Array = []
	for o in orders:
		if str(o.action) == "give_signal":
			out.append(rules.call("give_signal"))
		elif str(o.action) == "choose":  # una decisión de campo (pending_choice) resuelta con una de sus opciones
			out.append(rules.call("resolve_choice", str((o.opts as Dictionary).get("option", "")), false))
		else:
			out.append(rules.call("issue_order", str(o.actor), str(o.action), o.target, o.opts))
	return out

# ---------------------------------------------------------------------------------------------------------------------
# El azar de las políticas

static func _rand(view: Dictionary, rng: RandomNumberGenerator) -> float:
	var mem: Dictionary = view.mem
	if not mem.has("lcg"):
		mem["lcg"] = int(absi(rng.seed) % (LCG_MOD - 1)) + 1
	mem["lcg"] = (int(mem.lcg) * 48271) % LCG_MOD
	return float(mem.lcg) / float(LCG_MOD)

static func _rand_range(view: Dictionary, rng: RandomNumberGenerator, low: float, high: float) -> float:
	return low + (high - low) * _rand(view, rng)

# ---------------------------------------------------------------------------------------------------------------------
# Decisión

## Las órdenes que una política da ahora: [{actor, action, target: Vector2, opts}]. [] si no hay nada que hacer o la política no existe.
static func decide(policy: String, view: Dictionary, rng: RandomNumberGenerator) -> Array:
	match policy:
		"pasivo", "pausa_reanuda":
			return []
		"obediente":
			return _obey(view)
		"torpe":
			return _clumsy(view, rng)
		"aleatorio":
			return _random_orders(view, rng)
	var cfg := _plan_for(policy)
	if cfg.is_empty():
		return []
	return _scripted(view, cfg)

## El plan de una política guionada (experto y sus variantes): {} si no es de las guionadas.
static func _plan_for(policy: String) -> Dictionary:
	var cfg := {"recon": ["bateria"], "approaches": {}, "signal_at_s": 285.0, "deadline_s": 372.0, "fronts": V.COMBAT_GROUPS.duplicate(), "arreo": true, "support": true,
		"postures": {"bateria": "a_fondo", "cuartel": "con_cautela", "posta": "con_cautela"}, "extraction": "mixta", "plan_load": true}
	match policy:
		"experto":
			return cfg
		"barrido_senal":
			cfg.signal_any = true  # el barrido da la señal en el segundo pedido aunque falte una partida (mide el instante, no la coordinación)
			return cfg
		"ciego_sin_recon":
			cfg.recon = []
			return cfg
		"ciego_tarde":
			cfg.signal_at_s = 372.0
			return cfg
		"ciego_un_frente":
			cfg.fronts = ["rodriguez"]
			return cfg
		"ciego_sin_arreo":
			cfg.arreo = false
			return cfg
	if policy.begins_with("est_"):
		var parts := policy.split("_", true, 2)
		if parts.size() == 3 and V.OBJECTIVES.has(parts[1]) and (R.APPROACHES[parts[1]] as Array).has(parts[2]):
			cfg.approaches = {parts[1]: parts[2]}
			return cfg
	if policy.begins_with("ext_") and R.EXTRACTIONS.has(policy.trim_prefix("ext_")):
		cfg.extraction = policy.trim_prefix("ext_")
		return cfg
	return {}

# ---------------------------------------------------------------------------------------------------------------------
# Obediente y torpe: solo hacen lo que dice «siguiente paso»

static func _next_orders(view: Dictionary) -> Array:
	var nxt: Dictionary = view.hud.get("siguiente", {})
	var action := str(nxt.get("action", ""))
	if action == "" or action == "hold" or action == "cancel":
		return []
	var target := Vector2.ZERO
	var raw: Variant = nxt.get("target", {})
	if raw is Dictionary and not (raw as Dictionary).is_empty():
		target = Vector2(float(raw.x), float(raw.z))
	if action == "give_signal":
		return [_order("", "give_signal")]
	return [_order(str(nxt.get("actor", "")), action, target)]

static func _obey(view: Dictionary) -> Array:
	return _next_orders(view)

## El torpe: demora cada orden de 2 a 8 s, ignora el 30 % de los avisos que no son urgentes y a la señal le erra por ± 15 s.
static func _clumsy(view: Dictionary, rng: RandomNumberGenerator) -> Array:
	var mem: Dictionary = view.mem
	var t := float(view.t)
	if t < float(mem.get("wait_until", 0.0)):
		return []
	var nxt: Dictionary = view.hud.get("siguiente", {})
	var orders := _next_orders(view)
	if orders.is_empty():
		return []
	if int(nxt.get("urgencia", 0)) < 2 and _rand(view, rng) < 0.3:
		mem["wait_until"] = t + _rand_range(view, rng, 2.0, 8.0)
		return []
	if str(nxt.get("action", "")) == "give_signal":
		if not mem.has("signal_seen_at"):
			mem["signal_seen_at"] = t
			mem["signal_slip"] = _rand_range(view, rng, -15.0, 15.0)
		if t < float(mem.signal_seen_at) + float(mem.signal_slip):  # solo atrasa: no puede dar la señal antes de que el aviso se la pida
			return []
	mem["wait_until"] = t + _rand_range(view, rng, 2.0, 8.0)
	return orders

# ---------------------------------------------------------------------------------------------------------------------
# Aleatorio: órdenes al azar para probar que ninguna deja el juego en un estado inválido

static func _random_orders(view: Dictionary, rng: RandomNumberGenerator) -> Array:
	var mem: Dictionary = view.mem
	if float(view.t) < float(mem.get("wait_until", 0.0)):
		return []
	mem["wait_until"] = float(view.t) + _rand_range(view, rng, 1.0, 6.0)
	var units: Array = view.render.get("units", [])
	if units.is_empty():
		return []
	var u: Dictionary = units[int(_rand(view, rng) * float(units.size())) % units.size()]
	var kind := "group"
	if str(u.kind) == "reconocedores":
		kind = "scout"
	elif str(u.kind) == "arreo":
		kind = "train"
	var pool: Array = []
	for a in R.ACTIONS[kind]:
		if R.ACTIONS_R1.has(a):
			pool.append(a)
	pool.append("give_signal")
	var action := str(pool[int(_rand(view, rng) * float(pool.size())) % pool.size()])
	var target := Vector2(_rand_range(view, rng, 0.0, 900.0), _rand_range(view, rng, 0.0, 650.0))
	var opts := {}
	if _rand(view, rng) < 0.3:
		opts["pace"] = R.PACES[int(_rand(view, rng) * float(R.PACES.size())) % R.PACES.size()]
	if _rand(view, rng) < 0.3:
		opts["posture"] = R.POSTURES[int(_rand(view, rng) * 2.0) % 2]
	if _rand(view, rng) < 0.3:
		opts["front"] = V.OBJECTIVES[int(_rand(view, rng) * 3.0) % 3]
	if action == "give_signal":
		return [_order("", "give_signal")]
	return [_order(str(u.id), action, target, opts)]

# ---------------------------------------------------------------------------------------------------------------------
# Políticas guionadas (el experto y sus variantes)

static func _unit_view(view: Dictionary, id: String) -> Dictionary:
	for u in view.render.get("units", []):
		if str(u.id) == id:
			return u
	return {}

static func _front_view(view: Dictionary, fid: String) -> Dictionary:
	for f in view.hud.get("frentes", []):
		if str(f.id) == fid:
			return f
	return {}

static func _obj_pos(view: Dictionary, fid: String) -> Vector2:
	for o in view.render.get("objectives", []):
		if str(o.id) == fid:
			return Vector2(float(o.x), float(o.z))
	return D.hito(fid)

static func _taken(view: Dictionary, fid: String) -> bool:
	return str(_front_view(view, fid).get("estado", "")) == "tomado"

static func _group_front(gid: String) -> String:
	for fid in V.OBJECTIVES:
		if str(D.rules().groups[gid].front) == fid:
			return fid
	return ""

static func _scripted(view: Dictionary, cfg: Dictionary) -> Array:
	var phase := str(view.phase)
	if phase == "extraccion":
		var out := _extract(view, cfg, true)
		out.append_array(_groups_destroy(view, cfg, out))
		return out
	if phase != "ataque":
		return _approach(view, cfg)
	var orders: Array = []
	var mem: Dictionary = view.mem
	## ataque: el que terminó socorre al frente que más cuesta
	if bool(cfg.support):
		for gid in V.COMBAT_GROUPS:
			var uv := _unit_view(view, gid)
			var mine := _group_front(gid)
			if str(uv.get("stage", "")) != "holding" or not _taken(view, mine) or mem.has("support_" + gid):
				continue
			var hardest := ""
			var lowest := 101.0
			for fid in V.OBJECTIVES:
				if _taken(view, fid):
					continue
				var tp := float(_front_view(view, fid).get("toma_pct", 0.0))
				if tp < lowest:
					lowest = tp
					hardest = fid
			if hardest != "":
				mem["support_" + gid] = true
				orders.append(_order(gid, "support", Vector2.ZERO, {"front": hardest, "posture": "con_cautela"}))
	## el arreo no espera al último frente: carga ya lo de los frentes que cayeron; las partidas libres destruyen lo que el plan de carga deja
	orders.append_array(_extract(view, cfg, false))
	orders.append_array(_groups_destroy(view, cfg, orders))
	return orders

## Antes de la señal: reconocer, llevar cada partida a su puesto, traer el arreo y dar la señal a su hora.
static func _approach(view: Dictionary, cfg: Dictionary) -> Array:
	var orders: Array = []
	var mem: Dictionary = view.mem
	var t := float(view.t)
	var scouts := _unit_view(view, "reconocedores")
	var scouts_idle := str(scouts.get("stage", "")) == "idle"
	var secret := _secret(view)
	## con la guardia atenta los centinelas de la altura ven al reconocedor a la distancia a la que mira: quien conoce el mundo no manda a nadie a mirar
	var guard_sees_scouts: bool = not secret.is_empty() and str((secret.get("world", {}) as Dictionary).get("guardia", "")) == "atenta"
	## una decisión de campo pendiente (el informante): quien conoce el mundo le cree a la versión cierta; las demás políticas guionadas también (son el experto con otro plan)
	if not secret.is_empty():
		for al in view.hud.get("alertas", []):
			if str(al.get("id", "")) != "informante" or mem.has("informante_done"):
				continue
			var truth := str((secret.get("world", {}) as Dictionary).get("torre_en", ""))
			for op in al.get("opciones", []):
				if str(op.get("val", "")) == truth:
					mem["informante_done"] = true
					orders.append(_order("", "choose", Vector2.ZERO, {"option": str(op.id)}))
					break
	if scouts_idle and not guard_sees_scouts:
		for fid in cfg.recon:
			if not mem.has("recon_" + str(fid)):
				mem["recon_" + str(fid)] = true
				orders.append(_order("reconocedores", "recon", _obj_pos(view, str(fid))))
				break
	for gid in cfg.fronts:
		if mem.has("pos_" + str(gid)):
			continue
		var fid := _group_front(str(gid))
		var opts: Dictionary = {"posture": str(cfg.postures.get(fid, "con_cautela"))}
		if guard_sees_scouts:
			opts["pace"] = "sneak"  # con la guardia atenta se llega al puesto en silencio: marchar a la vista de la altura levanta la alarma antes de la señal
		if cfg.approaches.has(fid):
			opts["approach"] = str(cfg.approaches[fid])
		elif fid == "cuartel" and not secret.is_empty():  # quien conoce el mundo entra por donde la torre no barre; con la guardia atenta, por la calle (los patios pasan a la vista de la altura)
			opts["approach"] = "patios" if str((secret.get("world", {}) as Dictionary).get("torre_en", "")) == "casa_cura" and not guard_sees_scouts else "calle"
		mem["pos_" + str(gid)] = true
		orders.append(_order(str(gid), "position", Vector2.ZERO, opts))
	if bool(cfg.arreo) and not mem.has("arreo_move"):
		mem["arreo_move"] = true
		orders.append(_order("arreo", "move", D.hito("posta") + Vector2(0.0, 30.0)))
	var sig: Dictionary = view.signal
	if bool(sig.can_give) and ((sig.waiting as Array).is_empty() or bool(cfg.get("signal_any", false))):
		var due: float = float(cfg.signal_at_s)
		if mem.has("signal_override"):
			due = float(mem.signal_override)
		if t >= due:
			orders.append(_order("", "give_signal"))
	elif bool(sig.can_give) and t >= float(cfg.deadline_s):
		orders.append(_order("", "give_signal"))
	return orders

# ---------------------------------------------------------------------------------------------------------------------
# Extracción: qué cargar, qué destruir y cuándo salir (la política conoce el reloj del refuerzo)

static func _item_kg(it: Dictionary) -> float:
	return float(it.qty) * float(it.unit_kg)

static func _item_value(it: Dictionary) -> float:
	return float(it.qty) * float(it.unit_value)

static func _extract(view: Dictionary, cfg: Dictionary, allow_leave: bool) -> Array:
	var arreo := _unit_view(view, "arreo")
	if arreo.is_empty() or str(arreo.stage) != "idle" or not bool(cfg.arreo):
		return []
	var secret := _secret(view)
	var rules_cfg := D.rules()
	var t := float(view.t)
	var here := Vector2(float(arreo.x), float(arreo.z))
	var left := 1.0e9
	if not secret.is_empty() and float(secret.alarm.reinforcement_at) >= 0.0:
		left = float(secret.alarm.reinforcement_at) - t
	var mule_speed := float(rules_cfg.stealth.pace[str(rules_cfg.transport.mule_pace)].speed) * float(rules_cfg.transport.mule_speed_mult)
	var vado := D.hito("vado_este")
	var exit_leg := vado.distance_to(D.hito("salida_este")) / mule_speed + float(rules_cfg.transport.exit_margin_s)
	var capacity := float(view.loot.capacity_kg)
	var load_kg := float(view.loot.load_kg)
	var recipe := str(cfg.extraction)
	var rate := float(rules_cfg.transport.load_kg_per_s_per_team) * float(rules_cfg.transport.teams_max)
	var detour := PATH_DETOUR  # la ruta real (A*, barro, tapias) es más larga que la recta: se planifica con ese margen
	var back_here := here.distance_to(vado) / mule_speed * detour + exit_leg
	## dos recursos escasos: el tiempo que queda hasta tener que salir desde acá y los kilos de mula que faltan llenar. Cada lote cuesta una parte de cada uno y vale
	## sus puntos: se carga primero el que más puntos da por recurso gastado (con tiempo de sobra manda el peso; con el reloj encima, la cercanía).
	var time_budget := maxf(left - back_here, 1.0)
	var kg_budget := maxf(capacity - load_kg, 1.0)
	var plan := _load_plan(view, cfg)
	var loads: Array = []
	var kills: Array = []
	for it in view.loot.items:
		if str(it.state) != "en_sitio" or not _taken(view, str(it.front)):
			continue
		## fuera del plan de carga no se carga (las mulas se guardan para lo que más vale por kilo): se destruye, con el arreo o con las partidas libres
		var off_plan := not plan.is_empty() and not plan.has(str(it.id))
		var pos := Vector2(float(it.x), float(it.z))
		var travel := here.distance_to(pos) / mule_speed * detour
		var back := pos.distance_to(vado) / mule_speed * detour + exit_leg
		if not allow_leave and travel > ATTACK_LOAD_TRAVEL_S:
			continue  # mientras se pelea, el arreo no cruza el pueblo por un lote: carga lo que tiene a mano y espera el depósito
		var kg := _item_kg(it)
		var value := _item_value(it)
		var load_s := kg / rate
		var time_cost := travel + load_s + maxf(back - back_here, 0.0)
		if recipe != "destruir_todo" and not off_plan and load_kg + kg <= capacity + 1e-6 and travel + load_s + back <= left:
			if not (recipe == "ligera" and kg > float(rules_cfg.loot.light_max_kg)):
				loads.append({"it": it, "score": value / (time_cost / time_budget + kg / kg_budget)})
		var dcost := travel + float(rules_cfg.loot.classes[str(it.kind)].destroy_s)
		if recipe != "cargar_todo" and recipe != "ligera" and dcost + back <= left and (plan.is_empty() or (off_plan and allow_leave)):
			kills.append({"it": it, "score": value * float(rules_cfg.loot.treatments.destruir) / maxf(dcost + maxf(back - back_here, 0.0), 1.0)})
	if loads.is_empty() and not plan.is_empty() and not bool(view.mem.get("plan_off", false)):
		for it in view.loot.items:
			if plan.has(str(it.id)) and str(it.state) == "en_sitio" and _taken(view, str(it.front)):
				view.mem["plan_off"] = true  # lo que el plan reservaba ya no da: se carga lo que hay a mano (el plan de siempre)
				return _extract(view, cfg, allow_leave)
	var pick: Dictionary = {}
	var action := ""
	if not loads.is_empty():
		loads.sort_custom(func(a, b): return float(a.score) > float(b.score))
		pick = loads[0].it
		action = "load"
	elif not kills.is_empty():
		kills.sort_custom(func(a, b): return float(a.score) > float(b.score))
		pick = kills[0].it
		action = "destroy"
	if not pick.is_empty():
		var spot := Vector2(float(pick.x), float(pick.z))
		if here.distance_to(spot) > float(rules_cfg.transport.load_radius_m) - 2.0:
			return [_order("arreo", "move", spot)]
		return [_order("arreo", action, spot, {"item": str(pick.id)})]
	if allow_leave:
		## la partida termina cuando la columna cruza el vado: con reloj de sobra, el arreo espera a que las partidas terminen de destruir lo que quedó
		if bool(cfg.get("plan_load", false)) and recipe == "mixta" and left - back_here > LEAVE_SPARE_S:
			for it in view.loot.items:
				if str(it.state) == "en_sitio" and _taken(view, str(it.front)):
					return []
		view.mem["arreo_left"] = true
		return [_order("arreo", "leave")]
	return []

## El plan de carga del experto (receta mixta con `plan_load`): lo que más puntos da por kilo, hasta llenar las mulas que habrá (las propias más las del corral de la
## posta, que el experto conoce). Lo ya cargado entra primero. Un lote entra si el reloj del refuerzo todavía da para ir a buscarlo desde la posta, cargarlo y
## llegar al vado con el margen de salida. {id: true}; {} si la política no planifica (otras recetas, sin ventaja).
static func _load_plan(view: Dictionary, cfg: Dictionary) -> Dictionary:
	var secret := _secret(view)
	if str(cfg.get("extraction", "")) != "mixta" or not bool(cfg.get("plan_load", false)) or secret.is_empty():
		return {}
	## el plan se decide dos veces y se sostiene (si cambiara con cada segundo, el arreo iría y vendría): cuando cae la posta y llegan las mulas, y cuando cae el
	## depósito entero, con el reloj que queda. Si en algún momento ningún lote del plan da para ir a buscarlo, se abandona y el arreo carga lo que tiene a mano.
	var mem: Dictionary = view.mem
	var fighting := str(view.phase) != "extraccion"
	var slot := "load_plan" if fighting else "load_plan_x"
	if bool(mem.get("plan_off", false)):
		return {}
	if mem.has(slot):
		var kept := {}
		for it in view.loot.items:
			if (mem[slot] as Dictionary).has(str(it.id)) and (str(it.state) == "en_sitio" or str(it.state) == "cargado"):
				kept[str(it.id)] = true
		return kept
	if fighting and not _taken(view, "posta"):
		return {}  # todavía no hay mulas del corral ni depósito: sin plan (el arreo espera en la posta)
	var rules_cfg := D.rules()
	var cap: Dictionary = rules_cfg.loot.capacity  # con la posta tomada llegan las mulas del corral (el experto sabe cuántas trae el mundo)
	var corral := str(((secret.get("world", {}) as Dictionary).get("loot_traits", {}) as Dictionary).get("corral", "completo"))
	var capacity := maxf(float(view.loot.capacity_kg), (float(cap.own_mules) + float((cap.corral_mules as Dictionary).get(corral, 0))) * float(cap.kg_per_mule))
	var left := 1.0e9
	if float(secret.alarm.reinforcement_at) >= 0.0:
		left = float(secret.alarm.reinforcement_at) - float(view.t)
	var mule_speed := float(rules_cfg.stealth.pace[str(rules_cfg.transport.mule_pace)].speed) * float(rules_cfg.transport.mule_speed_mult)
	var vado := D.hito("vado_este")
	var arreo := _unit_view(view, "arreo")
	var here := Vector2(float(arreo.get("x", 0.0)), float(arreo.get("z", 0.0))) if not _taken(view, "posta") or arreo.is_empty() else Vector2(float(arreo.x), float(arreo.z))
	if not _taken(view, "posta"):
		here = D.hito("posta")  # hasta que cae la posta, el arreo carga ahí: el plan cuenta desde el depósito
	var pending_kg := 0.0
	var rate := float(rules_cfg.transport.load_kg_per_s_per_team) * float(rules_cfg.transport.teams_max)
	var room := capacity
	var plan := {}
	var cands: Array = []
	for it in view.loot.items:
		if str(it.state) == "cargado":
			plan[str(it.id)] = true
			room -= _item_kg(it)
		elif str(it.state) == "en_sitio":
			cands.append(it)
	cands.sort_custom(func(a, b):
		var da := float(a.unit_value) / maxf(float(a.unit_kg), 0.001)
		var db := float(b.unit_value) / maxf(float(b.unit_kg), 0.001)
		return da > db + 1e-9 or (absf(da - db) <= 1e-9 and str(a.id) < str(b.id)))
	for it in cands:
		var kg := _item_kg(it)
		if kg > room + 1e-6:
			continue
		var spot := Vector2(float(it.x), float(it.z))
		## ir desde donde está el arreo, cargarlo (con lo que el plan ya tiene pendiente) y llegar al vado con el margen de salida
		var trip := (here.distance_to(spot) + spot.distance_to(vado)) / mule_speed * PATH_DETOUR + (kg + pending_kg) / rate + float(rules_cfg.transport.exit_margin_s)
		if not _taken(view, str(it.front)):
			trip += PLAN_UNTAKEN_WAIT_S  # el frente todavía pelea: cuenta lo que puede tardar en caer
		if trip > left:
			continue
		plan[str(it.id)] = true
		room -= kg
		pending_kg += kg
	mem[slot] = plan.duplicate()
	return plan

## Las partidas libres (en su frente tomado o sosteniendo, sin otra orden en este paso) destruyen lo que el plan de carga deja: el lote fuera del plan más cercano, a
## menos de GROUP_DESTROY_REACH_M (como la pista: su propio frente, no cruzar el pueblo). Lo que el plan lleva no lo tocan mientras el arreo no salió.
static func _groups_destroy(view: Dictionary, cfg: Dictionary, already: Array) -> Array:
	if str(cfg.get("extraction", "")) != "mixta" or not bool(cfg.get("plan_load", false)) or _secret(view).is_empty():
		return []
	var plan := _load_plan(view, cfg)
	if plan.is_empty():
		## sin plan (todavía no cayó la posta, o el plan se abandonó): se protege lo que el arreo puede cargar a mano (lo que entra en las mulas, cerca de él)
		var arreo := _unit_view(view, "arreo")
		var room := float(view.loot.capacity_kg) - float(view.loot.load_kg)
		var mule_speed := float(D.rules().stealth.pace[str(D.rules().transport.mule_pace)].speed) * float(D.rules().transport.mule_speed_mult)
		for it in view.loot.items:
			if str(it.state) != "en_sitio" or arreo.is_empty():
				continue
			var near := Vector2(float(arreo.x), float(arreo.z)).distance_to(Vector2(float(it.x), float(it.z))) / mule_speed * PATH_DETOUR <= ATTACK_LOAD_TRAVEL_S
			if near and _item_kg(it) <= room + 1e-6:
				plan[str(it.id)] = true
	var busy := {}
	for o in already:
		busy[str(o.actor)] = true
	var arreo_stage := str(_unit_view(view, "arreo").get("stage", ""))
	var arreo_gone := str(view.phase) == "extraccion" and (arreo_stage == "exited" or (arreo_stage == "moving" and float(view.loot.load_kg) > 0.0 and _arreo_leaving(view)))
	var radius := float(D.rules().transport.destroy_radius_m)
	var rules_cfg := D.rules()
	var march := float(rules_cfg.stealth.pace.march.speed)
	## cada partida reclama el lote que va a destruir: dos partidas no van al mismo (el lote sigue «en sitio» hasta que termina la primera)
	var claims: Dictionary = view.mem.get("destroy_claims", {})
	view.mem["destroy_claims"] = claims
	var out: Array = []
	for gid in V.COMBAT_GROUPS:
		var uv := _unit_view(view, gid)
		var st := str(uv.get("stage", ""))
		if st == "holding" or st == "idle" or st == "routed" or st == "exited":
			for k in claims.keys():
				if str(claims[k]) == gid:
					claims.erase(k)
	for gid in V.COMBAT_GROUPS:
		if busy.has(gid):
			continue
		var uv := _unit_view(view, gid)
		var st := str(uv.get("stage", ""))
		if st != "holding" and st != "idle":
			continue
		var here := Vector2(float(uv.x), float(uv.z))
		var best: Dictionary = {}
		var best_d := 0.0
		var best_score := -1.0
		for it in view.loot.items:
			if str(it.state) != "en_sitio" or not _taken(view, str(it.front)) or (claims.has(str(it.id)) and str(claims[str(it.id)]) != gid):
				continue
			if plan.has(str(it.id)) and not arreo_gone:
				continue
			var d := here.distance_to(Vector2(float(it.x), float(it.z)))
			if d > GROUP_DESTROY_REACH_M:
				continue
			## lo que más golpe suma por segundo de trabajo (ir y destruir), no solo lo más cercano
			var score := _item_value(it) / (d / march + float(rules_cfg.loot.classes[str(it.kind)].destroy_s))
			if score > best_score:
				best_score = score
				best_d = d
				best = it
		if best.is_empty():
			continue
		claims[str(best.id)] = gid
		var spot := Vector2(float(best.x), float(best.z))
		if best_d > radius - 2.0:
			out.append(_order(gid, "move", spot))
		else:
			out.append(_order(gid, "destroy", spot, {"item": str(best.id)}))
	return out

## ¿El arreo ya va hacia la salida? (su última orden fue «salir»)
static func _arreo_leaving(view: Dictionary) -> bool:
	return bool(view.mem.get("arreo_left", false))

# ---------------------------------------------------------------------------------------------------------------------
# Una partida entera por la API pública (la comparten las pruebas y las herramientas)

## Juega una partida completa con `policy` sobre `rules` (que ya tuvo new_game). Cada STEP_S de juego decide, aplica y avanza. Devuelve el registro de la partida (esquema
## hx_playthrough_v1, sin el hash). `opts`: {"max_s": tope de juego, "signal_s": señal forzada (barrido de la señal), "replicate": semilla propia del bot}.
static func play(rules: RefCounted, policy: String, opts: Dictionary = {}) -> Dictionary:
	var mem := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = int(rules.state.seed) * 1009 + int(opts.get("replicate", 1)) * 7919 + int(rules.state.attempt)
	if opts.has("signal_s"):
		mem["signal_override"] = float(opts.signal_s)
	var max_s := float(opts.get("max_s", float(D.rules().time.deadline_s) + 5.0))
	var guard := 0
	while str(rules.state.status) == "playing" and float(rules.state.elapsed) < max_s and guard < 4000:
		guard += 1
		step(rules, policy, mem, rng)
	return record_of(rules, policy, mem)

## Un paso de la partida: arma la vista, decide, aplica las órdenes y avanza STEP_S. Lo comparten play() y las herramientas que llevan el reloj por su cuenta (la escena
## real, la ramificación de decisiones). Devuelve las órdenes dadas. En `mem` quedan el enfoque elegido por frente y el máximo de alertas críticas a la vez.
static func step(rules: RefCounted, policy: String, mem: Dictionary, rng: RandomNumberGenerator, advance: bool = true) -> Array:
	var view := make_view(rules, policy, mem)
	var criticas := 0
	for a in view.hud.get("alertas", []):
		if str(a.nivel) == "critica":
			criticas += 1
	mem["max_critical"] = maxi(int(mem.get("max_critical", 0)), criticas)
	var orders := decide(policy, view, rng)
	var approaches: Dictionary = mem.get("approaches", {})
	for o in orders:
		if str(o.action) == "position":
			approaches[_group_front(str(o.actor))] = str((o.opts as Dictionary).get("approach", ""))
	mem["approaches"] = approaches
	for res in apply_orders(rules, orders):
		if not (res is Dictionary):
			mem["exceptions"] = int(mem.get("exceptions", 0)) + 1
	if advance:
		rules.call("tick", STEP_S)
	return orders

## El registro de una partida terminada (o cortada): los campos que lee qa_balance.py. `mem` es la memoria con que se jugó (de ahí salen el enfoque y las alertas críticas).
static func record_of(rules: RefCounted, policy: String, mem: Dictionary) -> Dictionary:
	var timed_out := str(rules.state.status) == "playing"
	var rep: Dictionary = rules.call("campaign_report")
	var taken := 0
	for o in rep.objectives:
		if str(o.estado) == "tomado":
			taken += 1
	var gp: Dictionary = rep.golpe
	var pacing: Dictionary = rules.state.stats.pacing
	var valid: bool = bool((rules.call("validate_snapshot", rules.call("snapshot")) as Dictionary).get("ok", false))
	var approaches: Dictionary = mem.get("approaches", {})
	var opening: Array = []
	for fid in V.OBJECTIVES:
		var ap := str(approaches.get(fid, ""))
		if ap == "" and approaches.has(fid):
			ap = str(D.level().access.attack_posts[fid][0].get("approach", "directo"))
		opening.append(ap if ap != "" else "no_fue")
	return {"policy": policy, "family": family(policy), "status": str(rep.status), "cause_id": str(rep.cause_id), "cause_text": str(rep.cause) if str(rep.status) == "defeat" else "",
		"elapsed_s": float(rep.elapsed), "golpe": float(gp.entregado) + float(gp.destruido) + float(gp.oculto), "loss_pct": float(rep.loss_pct), "medal": str(rep.get("medal", "")), "fronts_taken": taken,
		"opening": "|".join(PackedStringArray(opening)), "variant": rep.variant, "first_decision_s": float(pacing.first_decision_s),
		"decision_gap_max_s": float(pacing.decision_gap_max_s), "decision_gap_attack_max_s": float(pacing.decision_gap_attack_max_s), "decision_metric": "oferta",
		"max_critical_alerts": int(mem.get("max_critical", 0)), "exceptions": int(mem.get("exceptions", 0)) + (1 if timed_out else 0), "timeout": timed_out, "valid": valid}
