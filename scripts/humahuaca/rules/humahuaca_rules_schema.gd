extends RefCounted
## El esquema estricto del estado guardado del nivel «humahuaca» (CONTRATO 3.2.1 y 3.2.4). Dueña: reglas_historia.
## Un guardado es un archivo que cualquiera puede editar o que se puede dañar: antes de reemplazar la partida hay que saber que CADA dato que el juego lee tiene el tipo y el
## rango que espera, porque un valor de otro tipo no se rechaza solo: revienta más tarde, en medio de la partida (`float(null)`, `bool("x")`, una clave que no existe).
## El esquema describe todo `state` hoja por hoja y lo recorre una sola vez. Las reglas: (1) un dato que el juego lee tiene que existir y ser del tipo pedido (número finito
## dentro de su rango, entero, verdadero o falso, texto, elección de una lista cerrada, lista, objeto); (2) lo que apunta a otra cosa (un frente, una agrupación, una clase
## de botín) tiene que apuntar a algo que existe; (3) una clave que el juego no lee NO se mira (un guardado de una versión más nueva con claves de sobra no se rompe: para
## eso están `schema_version` y `map_version`). La prueba de cobertura de test_hx_rules juega partidas enteras y exige que ninguna clave que el estado tenga quede sin esquema.
## Funciones estáticas y puras, sin tocar ninguna partida. Independencia (V19): solo importa vocabularios y datos de su propia carpeta.
##
## Los nodos son diccionarios con `k` (el tipo): num {lo, hi}, int {lo, hi}, bool, str {n}, enum {values}, arr {of, n}, obj {req, opt}, map {keys, of}, alt {of}
## (alt: `{}` o el objeto `of`: una orden o un trabajo que no hay). Los rangos son de sensatez (un porcentaje va de 0 a 100), no cifras de juego: esas viven en el JSON de reglas.

const V = preload("res://scripts/humahuaca/humahuaca_vocab.gd")
const R = preload("res://scripts/humahuaca/rules/vocab_rules.gd")
const D = preload("res://scripts/humahuaca/rules/humahuaca_data.gd")

const T_MAX := 3600.0  # segundos de juego: el plazo es 840 s; el tope deja margen y rechaza lo absurdo
const KG_MAX := 100000.0
const COUNT_MAX := 1000000.0
const TEXT_MAX := 600
const NAME_MAX := 80

static var _cached: Dictionary = {}
static var _cached_key := ""

# ---------------------------------------------------------------------------------------------------------------------
# Constructores de nodos

static func _num(lo: float, hi: float) -> Dictionary:
	return {"k": "num", "lo": lo, "hi": hi}

static func _int(lo: float, hi: float) -> Dictionary:
	return {"k": "int", "lo": lo, "hi": hi}

static func _bool() -> Dictionary:
	return {"k": "bool"}

static func _str(n: int = NAME_MAX) -> Dictionary:
	return {"k": "str", "n": n}

static func _enum(values: Array) -> Dictionary:
	return {"k": "enum", "values": values}

static func _arr(of: Dictionary, n: int) -> Dictionary:
	return {"k": "arr", "of": of, "n": n}

static func _obj(req: Dictionary, opt: Dictionary = {}) -> Dictionary:
	return {"k": "obj", "req": req, "opt": opt}

static func _map(keys: Array, of: Dictionary) -> Dictionary:
	return {"k": "map", "keys": keys, "of": of}

static func _alt(of: Dictionary) -> Dictionary:
	return {"k": "alt", "of": of}

# ---------------------------------------------------------------------------------------------------------------------
# El esquema

## Las clases de botín que las reglas saben tratar (las del JSON): un lote de otra clase reventaría al buscar su peso o su tiempo de destrucción.
static func loot_kinds() -> Array:
	var out: Array = []
	var classes: Variant = D.rules().get("loot", {}).get("classes", {})
	if classes is Dictionary:
		for k in classes:
			out.append(str(k))
	return out

## El esquema de `state` para un mapa del tamaño `size`. Se arma una vez por tamaño y por conjunto de clases de botín.
static func schema(size: Vector2) -> Dictionary:
	var kinds := loot_kinds()
	var key := "%s|%s|%s" % [size.x, size.y, ",".join(PackedStringArray(kinds))]
	if key != _cached_key:
		_cached = _build(size, kinds)
		_cached_key = key
	return _cached

static func _build(size: Vector2, kinds: Array) -> Dictionary:
	var groups: Array = V.GROUPS.duplicate()
	var groups_or_none: Array = [""]
	groups_or_none.append_array(groups)
	var fronts: Array = V.OBJECTIVES.duplicate()
	var all_actions: Array = []
	for kind in R.ACTIONS:
		for a in R.ACTIONS[kind]:
			if not all_actions.has(a):
				all_actions.append(a)
	var x_m := _num(0.0, size.x)
	var z_m := _num(0.0, size.y)
	var pt := _obj({"x": x_m, "z": z_m})
	var secs := _num(0.0, T_MAX)  # un instante de la partida
	var secs_or_none := _num(-1.0, T_MAX)  # un instante o -1 (todavía no pasó)
	var pct := _num(0.0, 100.0)
	var unit_interval := _num(0.0, 1.0)
	var order := _alt(_obj({"action": _enum(all_actions)}, {"front": _enum(fronts), "posture": _enum(R.POSTURES), "x": x_m, "z": z_m, "item": _str(NAME_MAX), "approach": _str(20)}))
	var option := _obj({"id": _str(40), "label": _str(TEXT_MAX), "costo_txt": _str(TEXT_MAX)}, {"val": _str(40)})
	var decision := _alt(_obj({"id": _str(40), "titulo": _str(TEXT_MAX), "texto": _str(TEXT_MAX), "opciones": _arr(option, 6), "vence_s": _num(0.0, 600.0), "default": _str(40), "at": _num(0.0, T_MAX)}, {"dim": _str(40)}))
	var work := _alt(_obj({"kind": _enum(R.WORK_KINDS), "remaining_s": _num(-1.0, T_MAX)}, {"item": _str(NAME_MAX)}))
	var unit := _obj({"id": _enum(groups), "name": _str(), "kind": _enum(R.UNIT_KINDS), "x": x_m, "z": z_m, "yaw_deg": _num(-720.0, 720.0), "strength": pct, "fatigue": pct,
		"morale": pct, "armed": unit_interval, "men": _int(0.0, 1000.0), "mounted": _bool(), "pace": _enum(R.PACES), "stage": _enum(R.STAGES), "order": order,
		"path": _arr(pt, 400), "noise": unit_interval, "detected": _bool(), "custody": _int(0.0, 1000.0), "horses": _int(0.0, 1000.0), "carry_kg": _num(0.0, KG_MAX),
		"capacity_kg": _num(0.0, KG_MAX), "tag": _enum(V.TAGS), "work": work}, {"tower_cover_until": secs_or_none})
	var front_req := {"state": _enum(R.FRONT_STATES), "toma": pct, "garrison": _num(0.0, KG_MAX), "garrison_max": _num(1.0, KG_MAX), "alert": unit_interval,
		"surprise_until": secs_or_none, "reconocido": unit_interval, "held_by": _enum(groups_or_none), "custody": _int(0.0, 1000.0), "taken_at": secs_or_none,
		"supporters": _arr(_enum(groups), 5)}
	var objectives_req := {}
	for fid in fronts:
		var req := front_req.duplicate()
		if fid == "cuartel":
			req["tower"] = _obj({"active": _bool(), "armed": _bool(), "volleys_left": _int(0.0, 1000.0), "next_volley_at": secs_or_none})
		var opt := {"turned_out": _bool()}
		if fid == "bateria":
			opt["battery"] = _obj({"facing": _str(20), "pieces": _int(0.0, 100.0)})
		objectives_req[fid] = _obj(req, opt)
	var item := _obj({"id": _str(), "kind": _enum(kinds), "qty": _int(0.0, 100000.0), "unit_kg": _num(0.0, KG_MAX), "unit_value": _num(0.0, 1000.0), "state": _enum(R.LOOT_STATES),
		"x": x_m, "z": z_m, "where": _str(), "front": _enum(fronts), "carried_by": _enum(groups_or_none), "spot": _str(), "safe": _bool()}, {"wet": _bool()})
	var money := _num(0.0, 1000000.0)
	var event := _obj({"time": secs, "round": _int(0.0, 100.0), "text": _str(TEXT_MAX), "kind": _enum(R.EVENT_KINDS)},
		{"tag": _enum(V.TAGS), "pos": pt, "unit": _enum(groups_or_none), "objective": _enum(fronts), "field_event": _str(), "strong": _bool(), "options": _arr(option, 10), "until": secs})
	var past_order := _obj({"time": secs, "round": _int(0.0, 100.0), "unit": _enum(groups_or_none), "action": _enum(all_actions), "target": pt},
		{"prev": _obj({"stage": _enum(R.STAGES), "order": order})})
	var fire_line := _obj({"from": pt, "to": pt, "kind": _str(40), "until": secs})
	var mark := _obj({"key": _str(), "kind": _str(), "text": _str(TEXT_MAX), "x": x_m, "z": z_m, "confirmed": _bool()})
	var top := {
		"schema_version": _int(0.0, 1000000000.0), "game_id": _str(120), "state_version": _int(1.0, 1000000000.0), "scenario": _str(40), "map_id": _enum([V.SCENARIO]),
		"map_version": _int(0.0, 1000000000.0), "contract": _int(0.0, 1000000000.0), "seed": _int(-2147483647.0, 2147483647.0), "rng_state": _int(1.0, 2147483646.0),
		"attempt": _int(1.0, COUNT_MAX), "elapsed": secs, "accumulator": _num(0.0, 60.0), "status": _enum(R.STATUS), "reason": _str(40), "phase": _enum(R.PHASES), "resistencia": _bool(),
		"world": _obj({"guardia": _enum(R.VARIANTS["guardia"]), "torre_en": _enum(R.VARIANTS["torre_en"]), "refugio": _enum(R.VARIANTS["refugio"]), "lluvia": _enum(R.VARIANTS["lluvia"]),
			"refuerzo": _enum(R.VARIANTS["refuerzo"]), "layout": _enum(R.VARIANTS["layout"]),
			"loot_traits": _obj({"corral": _enum(R.WORLD_TRAITS["corral"]), "plata": _bool(), "polvora": _enum(R.WORLD_TRAITS["polvora"])}),
			"known": _arr(_str(40), 40), "rumors": _arr(_obj({"id": _str(40), "dim": _enum(R.VARIANTS.keys()), "val": _str(40), "reliability": unit_interval, "shown": _bool()}), 40)}),
		"alarm": _obj({"level": unit_interval, "first_shot_at": secs_or_none, "signaled": _bool(), "signal_at": secs_or_none, "messenger": _enum(R.MESSENGER_STATES),
			"reinforcement_at": secs_or_none, "reinforcement_arrived": _bool(), "pre_signal": _arr(_enum(fronts), 3)}, {"messenger_at": secs_or_none, "spread_at": secs_or_none}),
		"objectives": _obj(objectives_req),
		"units": _arr(unit, 5),
		"loot": _obj({"items": _arr(item, 200), "capacity_kg": _num(0.0, KG_MAX), "load_kg": _num(0.0, KG_MAX), "delivered_value": money, "destroyed_value": money,
			"hidden_value": money, "lost_value": money, "total_value": money}),
		"recon": _obj({"geometry": _bool(), "fronts": _arr(_enum(fronts), 3)}),
		"stats": _obj({"start_strength": _map(groups, pct), "detections": _int(0.0, COUNT_MAX), "losses": _num(0.0, COUNT_MAX), "support_events": _int(0.0, COUNT_MAX),
			"horses_lost": _int(0.0, 1000.0), "powder_wet": _int(0.0, 1000.0), "charges_total": _int(0.0, COUNT_MAX), "charges_in_gap": _int(0.0, COUNT_MAX),
			"pacing": _obj({"decision_gap_max_s": secs, "decision_gap_attack_max_s": secs, "first_decision_s": secs_or_none, "events_per_min": _num(0.0, COUNT_MAX),
				"visible_actions_t0": _int(0.0, 1000.0)})}),
		"log": _arr(event, R.LOG_MAX),
		"orders": _arr(past_order, 200),
		"pacing_last": _obj({"offer": secs_or_none, "gap_start": secs, "attack_gap_start": secs_or_none, "events": _int(0.0, 100000000.0)}),
		"fire_lines": _arr(fire_line, 400),
		"outcome": _alt(_obj({"cause_id": _str(40), "title": _str(TEXT_MAX), "cause": _str(TEXT_MAX), "advice": _str(TEXT_MAX)})),
		"render_version": _int(1.0, 1000000000.0), "smoke_used": _int(0.0, 1000.0), "smoke_adv": _num(0.0, 1000.0), "mercy_level": _int(0.0, 3.0),
		"assists": _arr(_str(40), 20), "diary_marks": _arr(mark, 100)}
	return _obj(top, {"previous_game_id": _str(120), "decision": decision, "decisions_done": _arr(_str(40), 20)})

# ---------------------------------------------------------------------------------------------------------------------
# El recorrido

static func _fail(path: String, why: String) -> Dictionary:
	return {"path": path, "why": why}

static func _join(path: String, key: Variant) -> String:
	return str(key) if path == "" else path + "." + str(key)

static func _is_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

## Recorre `value` contra `node`. {} si cumple; si no, {"path": ruta técnica, "why": "falta" | "tipo" | "rango"} de la primera falla.
static func _walk(node: Dictionary, value: Variant, path: String) -> Dictionary:
	match str(node.k):
		"num":
			if not _is_number(value):
				return _fail(path, "tipo")
			if float(value) < float(node.lo) or float(value) > float(node.hi):
				return _fail(path, "rango")
		"int":
			if not _is_number(value) or float(value) != floorf(float(value)):
				return _fail(path, "tipo")
			if float(value) < float(node.lo) or float(value) > float(node.hi):
				return _fail(path, "rango")
		"bool":
			if not (value is bool):
				return _fail(path, "tipo")
		"str":
			if not (value is String):
				return _fail(path, "tipo")
			if (value as String).length() > int(node.n):
				return _fail(path, "rango")
		"enum":
			if not (value is String) or not (node.values as Array).has(value):
				return _fail(path, "tipo")
		"arr":
			if not (value is Array):
				return _fail(path, "tipo")
			var list: Array = value
			if list.size() > int(node.n):
				return _fail(path, "rango")
			for i in range(list.size()):
				var bad := _walk(node.of, list[i], "%s[%d]" % [path, i])
				if not bad.is_empty():
					return bad
		"obj":
			if not (value is Dictionary):
				return _fail(path, "tipo")
			var dict: Dictionary = value
			for key in node.req:
				if not dict.has(key):
					return _fail(_join(path, key), "falta")
				var bad_req := _walk(node.req[key], dict[key], _join(path, key))
				if not bad_req.is_empty():
					return bad_req
			for key in node.opt:
				if dict.has(key):
					var bad_opt := _walk(node.opt[key], dict[key], _join(path, key))
					if not bad_opt.is_empty():
						return bad_opt
		"map":
			if not (value is Dictionary):
				return _fail(path, "tipo")
			var table: Dictionary = value
			for key in node.keys:
				if not table.has(key):
					return _fail(_join(path, key), "falta")
				var bad_map := _walk(node.of, table[key], _join(path, key))
				if not bad_map.is_empty():
					return bad_map
		"alt":
			if not (value is Dictionary):
				return _fail(path, "tipo")
			if not (value as Dictionary).is_empty():
				return _walk(node.of, value, path)
	return {}

## El motivo que se le muestra al jugador: sale de rules.texts.guardado (`falta` o `danado`) y nombra la sección con palabras comunes, sin rutas ni nombres de campos.
static func reason(why: String, section: String = "") -> String:
	var names: Variant = D.tx("guardado.secciones")
	var label := "los datos generales"
	if names is Dictionary:
		label = str((names as Dictionary).get(section, (names as Dictionary).get("", label)))
	var text := D.ts("guardado.falta" if why == "falta" else "guardado.danado", {"seccion": label})
	return text if text != "" else "El guardado está dañado."

## Valida `d` (un Dictionary) contra el esquema. {"ok", "reason", "path", "why"}: `reason` es el motivo para el jugador; `path` y `why` son la ruta técnica y la clase de falla
## («falta», «tipo» o «rango») para quien depura (las pruebas las leen).
static func check(d: Dictionary, size: Vector2) -> Dictionary:
	var bad := _walk(schema(size), d, "")
	if bad.is_empty():
		return {"ok": true, "reason": "", "path": "", "why": ""}
	var path := str(bad.path)
	return {"ok": false, "reason": reason(str(bad.why), path.split(".")[0].split("[")[0]), "path": path, "why": str(bad.why)}

## Cada ruta de clave (sin los índices de los arreglos) que el esquema conoce, para la prueba de cobertura: «units.x», «objectives.cuartel.tower.active»…
static func known_paths(size: Vector2) -> Array:
	var out: Array = []
	_collect(schema(size), "", out)
	return out

static func _collect(node: Dictionary, path: String, out: Array) -> void:
	match str(node.k):
		"arr":
			_collect(node.of, path, out)
		"alt":
			_collect(node.of, path, out)
		"obj":
			for key in node.req:
				out.append(_join(path, key))
				_collect(node.req[key], _join(path, key), out)
			for key in node.opt:
				out.append(_join(path, key))
				_collect(node.opt[key], _join(path, key), out)
		"map":
			for key in node.keys:
				out.append(_join(path, key))
				_collect(node.of, _join(path, key), out)
