extends RefCounted
## Guardado, carga y validación de las reglas del nivel «humahuaca» (CONTRATO 3.2.4). Dueña: reglas_historia.
## Funciones estáticas, sin estado propio: humahuaca_rules.gd las llama y sigue siendo el único dueño de `state`. Vive aparte para que cada archivo del nivel quede
## por debajo de las ~1 500 líneas del contrato (se parte por responsabilidad). Independencia (V19): solo importa vocabularios.
##
## validate() rechaza, con un motivo escrito y sin tocar nada, todo guardado que no sea de este escenario, esta versión de esquema y este mapa, o que traiga tipos, rangos
## o coherencias imposibles: 5 agrupaciones con sus ids sin repetir, coordenadas dentro del mapa, etapas, ritmos y órdenes del vocabulario, variantes y rasgos legales,
## un botín que suma 100 y no supera su capacidad, «en marcha» con camino y orden, una victoria con los tres frentes tomados, un primer disparo que no está en el futuro.
## Un guardado de la Justina o del Norte se rechaza con «Este guardado es de otro escenario» (el nivel nunca le pasa su nombre a GameRules).

const V = preload("res://scripts/humahuaca/humahuaca_vocab.gd")
const R = preload("res://scripts/humahuaca/rules/vocab_rules.gd")

const SCENARIO := "humahuaca"
const SAVE_VERSION := 1
const SAVE_MAX_BYTES := 3000000
const LOAD_MAX_BYTES := 4000000

static func _num_in(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high

static func _bad(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}

## Escritura atómica (.tmp y renombre). Si el estado pasa de 3 000 000 B se recortan el registro y las órdenes; si aun así no entra, ERR_FILE_CORRUPT.
static func write(path: String, state: Dictionary) -> Error:
	if state.is_empty():
		return ERR_UNCONFIGURED
	var text := JSON.stringify(state, "", true, true)
	if text.to_utf8_buffer().size() > SAVE_MAX_BYTES:
		var slim := state.duplicate(true)
		slim.log = (slim.log as Array).slice(maxi(0, (slim.log as Array).size() - 60))
		slim.orders = (slim.orders as Array).slice(maxi(0, (slim.orders as Array).size() - 20))
		text = JSON.stringify(slim, "", true, true)
		if text.to_utf8_buffer().size() > SAVE_MAX_BYTES:
			return ERR_FILE_CORRUPT
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.flush()
	file.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path))

## Lee y parsea un guardado sin validarlo: {"ok", "reason", "data"}.
static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "reason": "No hay una partida guardada."}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > LOAD_MAX_BYTES:
		return {"ok": false, "reason": "El archivo guardado no es válido."}
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return {"ok": false, "reason": "El archivo guardado está dañado o no contiene JSON válido."}
	return {"ok": true, "reason": "", "data": parser.data}

## JSON devuelve todos los números como float: los enteros del estado vuelven a ser enteros. Se llama solo con un estado ya validado.
static func fix_ints(d: Dictionary) -> void:
	for k in ["schema_version", "state_version", "map_version", "contract", "seed", "rng_state", "attempt", "render_version", "smoke_used", "mercy_level"]:
		if d.has(k) and d[k] is float:
			d[k] = int(d[k])
	for u in d.get("units", []):
		for k in ["men", "custody", "horses"]:
			if u.has(k) and u[k] is float:
				u[k] = int(u[k])
	for k in ["detections", "support_events", "horses_lost", "powder_wet", "charges_total", "charges_in_gap"]:
		if d.stats.has(k) and d.stats[k] is float:
			d.stats[k] = int(d.stats[k])
	var last: Variant = d.get("pacing_last", null)
	if last is Dictionary and (last as Dictionary).get("events", null) is float:
		last.events = int(last.events)
	for fid in d.get("objectives", {}):
		var o: Dictionary = d.objectives[fid]
		if o.get("custody", null) is float:
			o.custody = int(o.custody)
		var tw: Variant = o.get("tower", null)
		if tw is Dictionary and (tw as Dictionary).get("volleys_left", null) is float:
			tw.volleys_left = int(tw.volleys_left)
		var bt: Variant = o.get("battery", null)
		if bt is Dictionary and (bt as Dictionary).get("pieces", null) is float:
			bt.pieces = int(bt.pieces)
	for it in d.loot.items:
		if it.get("qty", null) is float:
			it.qty = int(it.qty)
	for e in d.log:
		if e.get("round", null) is float:
			e.round = int(e.round)

## Valida un estado completo. `map_version` es el del JSON de reglas y `size` el tamaño del mapa (900 × 650). Devuelve {"ok", "reason"}.
static func validate(v: Variant, map_version: float, size: Vector2) -> Dictionary:
	if not (v is Dictionary):
		return _bad("El guardado no contiene un estado válido.")
	var d: Dictionary = v
	if d.has("scenario") and d.scenario != SCENARIO:
		return _bad("Este guardado es de otro escenario.")
	for key in ["schema_version", "game_id", "state_version", "scenario", "map_id", "map_version", "contract", "seed", "rng_state", "attempt", "elapsed", "accumulator",
			"status", "reason", "phase", "world", "alarm", "objectives", "units", "loot", "stats", "log", "orders", "fire_lines", "outcome", "pacing_last", "recon",
			"render_version", "smoke_used", "smoke_adv", "mercy_level", "assists", "diary_marks"]:
		if not d.has(key):
			return _bad("Guardado incompleto: falta %s." % key)
	if not _num_in(d.schema_version, SAVE_VERSION, SAVE_VERSION):
		return _bad("Versión de guardado incompatible; se necesita la versión %d." % SAVE_VERSION)
	if not _num_in(d.contract, V.CONTRACT, V.CONTRACT):
		return _bad("El guardado es de otro contrato de datos.")
	if not _num_in(d.map_version, map_version, map_version):
		return _bad("El guardado es de otra versión del mapa y no se puede cargar.")
	if not (d.status is String) or not R.STATUS.has(d.status) or not (d.phase is String) or not R.PHASES.has(d.phase) or not (d.game_id is String) or not (d.reason is String):
		return _bad("Resultado o fase inválidos en el guardado.")
	if not _num_in(d.state_version, 1, 1000000000) or not _num_in(d.seed, -2147483647, 2147483647) or not _num_in(d.attempt, 1, 1000000):
		return _bad("Identidad o versión de estado inválidas.")
	if not _num_in(d.elapsed, 0, 86400) or not _num_in(d.accumulator, 0, 60) or not _num_in(d.rng_state, 1, 2147483646):
		return _bad("Los tiempos o la semilla del guardado son inválidos.")
	if not (d.world is Dictionary) or not (d.alarm is Dictionary) or not (d.objectives is Dictionary) or not (d.units is Array) or not (d.loot is Dictionary) or not (d.stats is Dictionary) or not (d.log is Array):
		return _bad("Faltan secciones del guardado o tienen un formato inválido.")
	for e in d.log:
		if not (e is Dictionary) or not (e.get("text") is String) or not (e.get("kind") is String) or not _num_in(e.get("time"), 0, 86400):
			return _bad("Registro de acontecimientos corrupto.")
	if not (d.orders is Array) or not (d.fire_lines is Array) or not (d.outcome is Dictionary) or not (d.recon is Dictionary) or not (d.assists is Array) or not (d.diary_marks is Array):
		return _bad("Faltan secciones internas del guardado o tienen un formato inválido.")
	if not _num_in(d.render_version, 1, 1000000000) or not _num_in(d.smoke_used, 0, 1000) or not _num_in(d.smoke_adv, 0, 1000) or not _num_in(d.mercy_level, 0, 3):
		return _bad("Contadores internos del guardado inválidos.")
	var last: Variant = d.pacing_last
	if not (last is Dictionary) or not _num_in(last.get("events"), 0, 100000000) or not _num_in(last.get("gap_start"), 0, 86400) or not _num_in(last.get("attack_gap_start"), -1, 86400) or not _num_in(last.get("offer"), -1, 86400):
		return _bad("El ritmo de la partida guardada es inválido.")
	if not (d.stats.get("pacing") is Dictionary):
		return _bad("Las estadísticas del guardado están incompletas.")
	var check_world := _validate_world(d)
	if not bool(check_world.ok):
		return check_world
	var check_units := _validate_units(d, size)
	if not bool(check_units.ok):
		return check_units
	var check_state := _validate_world_state(d)
	if not bool(check_state.ok):
		return check_state
	return {"ok": true, "reason": "Guardado válido."}

static func _validate_world(d: Dictionary) -> Dictionary:
	for dim in R.VARIANTS:
		if not d.world.has(dim) or not (R.VARIANTS[dim] as Array).has(d.world[dim]):
			return _bad("La variante «%s» del mundo es inválida." % dim)
	var traits: Variant = d.world.get("loot_traits", null)
	if not (traits is Dictionary):
		return _bad("Los rasgos del botín son inválidos.")
	for k in R.WORLD_TRAITS:
		if not traits.has(k) or not (R.WORLD_TRAITS[k] as Array).has(traits[k]):
			return _bad("El rasgo del botín «%s» es inválido." % k)
	if not (d.world.get("known", []) is Array) or not (d.world.get("rumors", []) is Array):
		return _bad("Lo que el mundo ya reveló está corrupto.")
	return {"ok": true, "reason": ""}

static func _validate_units(d: Dictionary, size: Vector2) -> Dictionary:
	if d.units.size() != V.GROUPS.size():
		return _bad("El guardado debe traer las %d agrupaciones." % V.GROUPS.size())
	var seen: Array = []
	var all_actions: Array = []
	for kind in R.ACTIONS:
		for a in R.ACTIONS[kind]:
			all_actions.append(a)
	for u in d.units:
		if not (u is Dictionary):
			return _bad("Agrupación corrupta.")
		for key in ["id", "name", "kind", "x", "z", "strength", "fatigue", "morale", "armed", "men", "mounted", "pace", "stage", "order", "path", "noise", "detected", "custody", "horses", "carry_kg", "capacity_kg", "tag"]:
			if not u.has(key):
				return _bad("Agrupación incompleta: falta %s." % key)
		if not (u.id is String) or not V.GROUPS.has(u.id) or seen.has(u.id):
			return _bad("Identificadores de agrupación inválidos.")
		seen.append(u.id)
		if not _num_in(u.x, 0, size.x) or not _num_in(u.z, 0, size.y):
			return _bad("Agrupación fuera del mapa.")
		for key in ["strength", "fatigue", "morale"]:
			if not _num_in(u[key], 0, 100):
				return _bad("Recursos de agrupación inválidos.")
		if not _num_in(u.armed, 0, 1) or not _num_in(u.noise, 0, 1) or not _num_in(u.men, 0, 1000) or not _num_in(u.custody, 0, 1000) or not _num_in(u.horses, 0, 1000) or not _num_in(u.carry_kg, 0, 100000) or not _num_in(u.capacity_kg, 0, 100000):
			return _bad("Cifras de agrupación inválidas.")
		if not (u.stage is String) or not R.STAGES.has(u.stage) or not (u.pace is String) or not R.PACES.has(u.pace) or not (u.mounted is bool) or not (u.detected is bool):
			return _bad("Etapa o ritmo inválidos.")
		if not (u.kind is String) or not R.UNIT_KINDS.has(u.kind) or not (u.tag is String) or not V.TAGS.has(u.tag):
			return _bad("Tipo o etiqueta de agrupación inválidos.")
		if not (u.order is Dictionary) or not (u.path is Array):
			return _bad("Orden o trayecto corrupto.")
		if not (u.order as Dictionary).is_empty() and (not ((u.order as Dictionary).get("action") is String) or not all_actions.has((u.order as Dictionary).get("action"))):
			return _bad("Orden inválida.")
		for p in u.path:
			if not (p is Dictionary) or not _num_in(p.get("x"), 0, size.x) or not _num_in(p.get("z"), 0, size.y):
				return _bad("Trayecto fuera del mapa.")
		if u.stage == "moving" and ((u.path as Array).is_empty() or (u.order as Dictionary).is_empty()):
			return _bad("Una agrupación en marcha necesita trayecto y orden.")
	return {"ok": true, "reason": ""}

static func _validate_world_state(d: Dictionary) -> Dictionary:
	var taken := 0
	for fid in V.OBJECTIVES:
		var o: Variant = d.objectives.get(fid, null)
		if not (o is Dictionary):
			return _bad("Falta el frente «%s» en el guardado." % fid)
		if not (o.get("state") is String) or not R.FRONT_STATES.has(o.state) or not _num_in(o.get("toma"), 0, 100) or not _num_in(o.get("alert"), 0, 1) or not _num_in(o.get("garrison"), 0, 100000) or not _num_in(o.get("garrison_max"), 0, 100000):
			return _bad("Estado del frente «%s» inválido." % fid)
		if not _num_in(o.get("reconocido"), 0, 1) or not _num_in(o.get("surprise_until"), -1, 86400) or not _num_in(o.get("taken_at"), -1, 86400) or not (o.get("supporters") is Array):
			return _bad("Datos del frente «%s» inválidos." % fid)
		if o.state == "tomado":
			taken += 1
	var tw: Variant = d.objectives.cuartel.get("tower", null)
	if not (tw is Dictionary) or not _num_in(tw.get("volleys_left"), 0, 1000) or not _num_in(tw.get("next_volley_at"), -1, 86400):
		return _bad("La torre del guardado es inválida.")
	var al: Dictionary = d.alarm
	if not _num_in(al.get("level"), 0, 1) or not _num_in(al.get("first_shot_at"), -1, 86400) or not _num_in(al.get("signal_at"), -1, 86400) or not _num_in(al.get("reinforcement_at"), -1, 86400):
		return _bad("La alarma del guardado es inválida.")
	if not (al.get("signaled") is bool) or not (al.get("reinforcement_arrived") is bool) or not (al.get("pre_signal", []) is Array):
		return _bad("La alarma del guardado tiene campos inválidos.")
	for fid in al.get("pre_signal", []):
		if not V.OBJECTIVES.has(fid):
			return _bad("La alarma del guardado nombra un frente que no existe.")
	if float(al.first_shot_at) > float(d.elapsed):
		return _bad("La primera descarga no puede ser posterior al reloj.")
	if bool(al.signaled) != (float(al.signal_at) >= 0.0):
		return _bad("La señal y su hora no coinciden.")
	var l: Dictionary = d.loot
	for key in ["items", "capacity_kg", "load_kg", "delivered_value", "destroyed_value", "hidden_value", "lost_value", "total_value"]:
		if not l.has(key):
			return _bad("El botín del guardado está incompleto.")
	for key in ["capacity_kg", "load_kg", "delivered_value", "destroyed_value", "hidden_value", "lost_value", "total_value"]:
		if not _num_in(l[key], 0, 1000000):
			return _bad("Las cifras del botín son inválidas.")
	if not (l.items is Array):
		return _bad("El botín del guardado es inválido.")
	for it in l.items:
		if not (it is Dictionary) or not (it.get("kind") is String) or not R.LOOT_KINDS.has(it.kind) or not (it.get("state") is String) or not R.LOOT_STATES.has(it.state) or not _num_in(it.get("qty"), 0, 100000):
			return _bad("Un lote del botín es inválido.")
		if not (it.get("id") is String) or not _num_in(it.get("x"), 0, 100000) or not _num_in(it.get("z"), 0, 100000) or not _num_in(it.get("unit_kg"), 0, 100000) or not _num_in(it.get("unit_value"), 0, 1000):
			return _bad("Un lote del botín tiene cifras inválidas.")
	if absf(float(l.total_value) - 100.0) > 1e-6:
		return _bad("El valor total del botín debe ser 100.")
	if float(l.delivered_value) + float(l.destroyed_value) + float(l.hidden_value) + float(l.lost_value) > 100.0 + 1e-6:
		return _bad("Lo entregado, destruido, oculto y perdido supera el total del botín.")
	if float(l.load_kg) > float(l.capacity_kg) + 1e-6:
		return _bad("La carga supera la capacidad.")
	if d.status == "victory" and taken != V.OBJECTIVES.size():
		return _bad("Una victoria necesita los tres frentes tomados.")
	if d.phase == "extraccion" and taken != V.OBJECTIVES.size():
		return _bad("La extracción necesita los tres frentes tomados.")
	if (d.phase == "epilogo") != (d.status != "playing"):
		return _bad("La fase y el resultado no coinciden.")
	if d.status == "defeat" and not R.CAUSES.has(d.reason):
		return _bad("La causa de la derrota es inválida.")
	if d.status == "playing" and d.reason != "":
		return _bad("Una partida en juego no tiene causa de cierre.")
	if (d.phase == "briefing") and float(d.elapsed) > 0.0:
		return _bad("La preparación no puede tener reloj corrido.")
	if d.phase == "ataque" and not bool(al.signaled):
		return _bad("El ataque necesita la señal dada.")
	return {"ok": true, "reason": ""}
