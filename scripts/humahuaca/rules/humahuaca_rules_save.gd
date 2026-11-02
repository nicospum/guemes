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
const Schema = preload("res://scripts/humahuaca/rules/humahuaca_rules_schema.gd")

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
	var pace_stats: Variant = d.stats.get("pacing", null)
	if pace_stats is Dictionary and (pace_stats as Dictionary).get("visible_actions_t0", null) is float:
		pace_stats.visible_actions_t0 = int(pace_stats.visible_actions_t0)
	for o in d.get("orders", []):
		if o.get("round", null) is float:
			o.round = int(o.round)
	var last: Variant = d.get("pacing_last", null)
	if last is Dictionary and (last as Dictionary).get("events", null) is float:
		last.events = int(last.events)
	for fid in V.OBJECTIVES:  # los tres frentes del vocabulario, no cualquier clave que el archivo traiga de más
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

## Valida un estado completo, sin tocar nada. `map_version` es el del JSON de reglas y `size` el tamaño del mapa (900 × 650). Devuelve {"ok", "reason"} (y, si falla el esquema,
## también "path": la ruta técnica del dato que no cumple). El orden importa: primero de qué escenario es (un guardado de la Justina o del Norte tiene otra forma y no tiene
## sentido mirarle el resto), después las versiones, después el esquema estricto (tipo y rango de CADA dato que el juego lee: humahuaca_rules_schema.gd) y al final las coherencias
## entre datos. Hasta que el esquema no aprueba, nada se asigna con tipo: un valor de otro tipo en una variable tipada es un error de script, no un rechazo.
static func validate(v: Variant, map_version: float, size: Vector2) -> Dictionary:
	if not (v is Dictionary):
		return _bad("El guardado no contiene un estado válido.")
	var d: Dictionary = v
	if d.has("scenario"):
		if not (d.scenario is String):
			return _bad("El guardado está dañado: no dice de qué escenario es.")
		if d.scenario != SCENARIO:
			return _bad("Este guardado es de otro escenario.")
	for key in ["schema_version", "contract", "map_version"]:
		if not d.has(key):
			return _bad(Schema.reason("falta"))
	if not _num_in(d.schema_version, SAVE_VERSION, SAVE_VERSION):
		return _bad("Versión de guardado incompatible; se necesita la versión %d." % SAVE_VERSION)
	if not _num_in(d.contract, V.CONTRACT, V.CONTRACT):
		return _bad("El guardado es de otro contrato de datos.")
	if not _num_in(d.map_version, map_version, map_version):
		return _bad("El guardado es de otra versión del mapa y no se puede cargar.")
	var shape := Schema.check(d, size)
	if not bool(shape.ok):
		return {"ok": false, "reason": str(shape.reason), "path": str(shape.path)}
	var check_units := _validate_units(d)
	if not bool(check_units.ok):
		return check_units
	var check_state := _validate_world_state(d)
	if not bool(check_state.ok):
		return check_state
	return {"ok": true, "reason": "Guardado válido."}

## Las coherencias de las agrupaciones (los tipos y rangos ya los aprobó el esquema): las cinco, sin repetir, y que lo que hacen tenga con qué hacerlo.
static func _validate_units(d: Dictionary) -> Dictionary:
	if d.units.size() != V.GROUPS.size():
		return _bad("El guardado debe traer las %d agrupaciones." % V.GROUPS.size())
	var seen: Array = []
	for u in d.units:
		if seen.has(u.id):
			return _bad("Identificadores de agrupación repetidos.")
		seen.append(u.id)
		if u.stage == "moving" and ((u.path as Array).is_empty() or (u.order as Dictionary).is_empty()):
			return _bad("Una agrupación en marcha necesita trayecto y orden.")
		var work: Dictionary = u.work
		if not work.is_empty() and work.kind != "recon" and not work.has("item"):
			return _bad("Una agrupación ocupada con la carga no dice con cuál.")
	return {"ok": true, "reason": ""}

## Las coherencias del mundo, los frentes, la alarma, el botín y el desenlace (los tipos y rangos ya los aprobó el esquema).
static func _validate_world_state(d: Dictionary) -> Dictionary:
	var taken := 0
	for fid in V.OBJECTIVES:
		var o: Dictionary = d.objectives[fid]
		if float(o.garrison) > float(o.garrison_max) + 1e-6:
			return _bad("La guarnición del frente «%s» supera su máximo." % fid)
		if o.state == "tomado":
			taken += 1
	var tw: Dictionary = d.objectives.cuartel.tower
	if bool(tw.active) and not bool(tw.armed):
		return _bad("La torre del guardado dispara sin estar armada.")
	var al: Dictionary = d.alarm
	if float(al.first_shot_at) > float(d.elapsed):
		return _bad("La primera descarga no puede ser posterior al reloj.")
	if bool(al.signaled) != (float(al.signal_at) >= 0.0):
		return _bad("La señal y su hora no coinciden.")
	var l: Dictionary = d.loot
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
	if d.status == "victory" and d.reason != "victoria":
		return _bad("La causa de la victoria es inválida.")
	if d.status == "playing" and d.reason != "":
		return _bad("Una partida en juego no tiene causa de cierre.")
	if (d.status == "playing") != (d.outcome as Dictionary).is_empty():
		return _bad("El desenlace del guardado no coincide con el resultado.")
	if (d.phase == "briefing") and float(d.elapsed) > 0.0:
		return _bad("La preparación no puede tener reloj corrido.")
	if d.phase == "ataque" and not bool(al.signaled):
		return _bad("El ataque necesita la señal dada.")
	return {"ok": true, "reason": ""}
