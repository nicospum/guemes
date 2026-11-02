extends SceneTree

## Validadores puros de datos y documentos del nivel «humahuaca» (CONTRATO 2.4, reglas V1 a V22). Dueño: compuertas y documentos.
## Los usa tests/test_hx_data.gd (que extiende este archivo) contra los datos reales y contra copias rotas a propósito; cada validador recibe los
## datos y devuelve la lista de violaciones, sin tocar archivos. Se parte en dos para que ningún archivo pase de ≈ 1 500 líneas.
const Fx = preload("res://tests/hx_fixtures.gd")

const FILES := {
	"height": "res://data/humahuaca_height.json", "map": "res://data/humahuaca_map.json", "level": "res://data/humahuaca_level.json",
	"rules": "res://data/humahuaca_rules.json", "visual": "res://data/humahuaca_visual.json", "ui": "res://data/humahuaca_ui.json"}

const OWNER_NAMES := {"height": "relieve_mapa", "map": "relieve_mapa", "level": "reglas_historia", "rules": "reglas_historia", "visual": "visual", "ui": "ui_feel"}

## Pista dueña de cada archivo. En la ronda r1.0 (cada pista entrega su stub y su JSON mínimo en su worktree, sin los de las otras) la compuerta rápida
## corre con `--pista=<relieve|reglas|visual|ui>`: solo se exigen los archivos de esa pista y no se cruzan referencias entre archivos de distintas pistas.
const PISTA_OF_FILE := {"height": "relieve", "map": "relieve", "level": "reglas", "rules": "reglas", "visual": "visual", "ui": "ui"}
const SIZE_CAPS_KB := {"height": 450, "map": 150, "level": 150, "rules": 300, "visual": 120, "ui": 120}
const SCRIPTS_DIR := "res://scripts/humahuaca"
const MAX_SCRIPT_LINES := 1600

const TAGS := ["documentado", "razonado", "discutido", "sin_datos", "diseno"]  # de más fuerte a más débil (CONTRATO 0)

const GROUPS := ["rodriguez", "portal", "arias", "reconocedores", "arreo"]
const OBJECTIVES := ["bateria", "cuartel", "posta"]
const SOURCES_ENUM := ["lamina03_reconstruida", "copernicus_glo30", "opentopodata_srtm30", "paquete_usuario"]

## Los 24 HEX de la lámina 06 (V9), en el orden de la lámina.
const PALETTE_24 := ["#B99A72", "#776248", "#8E8B81", "#6D7653", "#69794B", "#8C9B91", "#C4AA82", "#E4DDCA", "#59432E", "#745034", "#B3A077", "#4B4B47",
	"#CEC2A7", "#705741", "#2E455A", "#9A443B", "#4F5E4C", "#E1D7BD", "#7FAAC4", "#EFE8D7", "#983F36", "#B99A50", "#383831", "#843D40"]

## Los 21 ids de hito que reglas, vista y UI usan por nombre (CONTRATO 2.2), obligatorios desde R1.0.
const MANDATORY_LANDMARKS := ["templo", "bateria", "cuartel", "posta", "torre_casa_cura", "torre_templo", "plaza", "polvorin", "parque", "corral_posta",
	"quebradita_norte", "quebradita_sur", "vado_este", "salida_este", "entrada_sur", "zona_partida", "spawn_rodriguez", "spawn_portal", "spawn_arias",
	"spawn_reconocedores", "spawn_arreo"]

## Claves de primer nivel de cada archivo y su dueño (CONTRATO 2.1 a 2.3 y 6.2). `contract` y `map_version` son identidad y van en todos;
## `lights` está en level (luces de objetivo) y en visual (luz de escena); `texts` está en rules (textos de juego) y en ui (textos de interfaz).
const OWNER_KEYS := {
	"height": ["contract", "map_version", "meta", "window", "context", "stats"],
	"map": ["contract", "map_version", "map_id", "size_m", "axes", "anchor", "lamina", "datum_asl_m", "relief", "surfaces", "landmarks", "river", "provenance"],
	"level": ["contract", "map_version", "level_version", "features", "access", "zones", "hide_spots", "lights", "layouts"],
	"rules": ["contract", "map_version", "rules_version", "time", "environment", "groups", "objectives", "enemy", "combat", "stealth", "tower", "actions",
		"loot", "transport", "reinforcement", "variants", "field_events", "enemy_decisions", "outcome", "campaign", "play_targets", "texts", "epilogue"],
	"visual": ["contract", "map_version", "palette", "lights", "rain", "fog", "materials", "props", "tokens", "markers", "units", "canonical_views",
		"initial_frame", "quality", "fx", "content_ring"],
	"ui": ["contract", "map_version", "texts", "tutorial_steps", "key_table", "jargon_blacklist", "source_tags", "camera", "minimap", "layout",
		"hud_limits", "toasts", "onboarding"]}

## V2: [archivo, ruta con puntos, tipo, ronda desde la que es obligatoria]. Tipos: int, number, string, bool, dict, array, any.
## Las columnas «Obligatoria desde» de 2.2 y 2.2b mandan; para 2.3 (sin columna) se usa el entregable de cada ronda (CONTRATO 8.1 a 8.3).
## Provisional para las rondas siguientes: compuertas y documentos lo ajusta con los datos reales de R1.0 (con aviso a la pista dueña).
const REQ := [
	["height", "contract", "int", "r0"], ["height", "map_version", "int", "r0"],
	["height", "meta", "dict", "r0"], ["height", "meta.source", "string", "r0"], ["height", "meta.source_detail", "string", "r0"],
	["height", "meta.datum_asl_m", "number", "r0"], ["height", "meta.unit", "string", "r0"], ["height", "meta.order", "string", "r0"],
	["height", "meta.tag", "string", "r0"], ["height", "meta.uncertainty_m", "number", "r0"], ["height", "meta.modified", "bool", "r0"],
	["height", "meta.smooth_m", "number", "r0"], ["height", "meta.credits_ref", "string", "r0"],
	["height", "window", "dict", "r0"], ["height", "window.nx", "int", "r0"], ["height", "window.nz", "int", "r0"], ["height", "window.cell_m", "number", "r0"],
	["height", "window.origin_x", "number", "r0"], ["height", "window.origin_z", "number", "r0"], ["height", "window.h", "array", "r0"],
	["height", "context", "dict", "r0"], ["height", "context.nx", "int", "r0"], ["height", "context.nz", "int", "r0"], ["height", "context.cell_m", "number", "r0"],
	["height", "context.origin_x", "number", "r0"], ["height", "context.origin_z", "number", "r0"], ["height", "context.h", "array", "r0"],
	["height", "stats", "dict", "r1"],
	["map", "contract", "int", "r0"], ["map", "map_id", "string", "r0"], ["map", "map_version", "int", "r0"],
	["map", "size_m", "dict", "r0"], ["map", "size_m.x", "number", "r0"], ["map", "size_m.z", "number", "r0"],
	["map", "axes", "dict", "r0"], ["map", "anchor", "dict", "r0"], ["map", "anchor.id", "string", "r0"], ["map", "anchor.x", "number", "r0"],
	["map", "anchor.z", "number", "r0"], ["map", "anchor.lat", "number", "r0"], ["map", "anchor.lon", "number", "r0"],
	["map", "anchor.uncertainty_m", "number", "r0"], ["map", "anchor.tag", "string", "r0"],
	["map", "lamina", "dict", "r0"], ["map", "lamina.offset_x", "number", "r0"], ["map", "lamina.offset_z", "number", "r0"],
	["map", "datum_asl_m", "number", "r0"],
	["map", "landmarks", "array", "r1.0"],
	["map", "relief", "dict", "r1"], ["map", "surfaces", "dict", "r1"], ["map", "river", "dict", "r1"], ["map", "provenance", "dict", "r1"],
	["level", "contract", "int", "r0"], ["level", "map_version", "int", "r0"], ["level", "level_version", "int", "r0"],
	["level", "features", "dict", "r1.0"], ["level", "access", "dict", "r1.0"], ["level", "zones", "array", "r1.0"], ["level", "lights", "array", "r1.0"],
	["level", "hide_spots", "array", "r2a"],
	["rules", "contract", "int", "r0"], ["rules", "map_version", "int", "r0"], ["rules", "rules_version", "int", "r0"],
	["rules", "time", "dict", "r1.0"], ["rules", "groups", "dict", "r1.0"], ["rules", "objectives", "dict", "r1.0"], ["rules", "actions", "dict", "r1.0"],
	["rules", "loot", "dict", "r1.0"],
	["rules", "environment", "dict", "r1"], ["rules", "enemy", "dict", "r1"], ["rules", "combat", "dict", "r1"], ["rules", "stealth", "dict", "r1"],
	["rules", "tower", "dict", "r1"], ["rules", "transport", "dict", "r1"], ["rules", "reinforcement", "dict", "r1"], ["rules", "outcome", "dict", "r1"],
	["rules", "campaign", "dict", "r1"], ["rules", "texts", "dict", "r1"], ["rules", "epilogue", "any", "r1"],
	["rules", "field_events", "any", "r2a"],
	["rules", "variants", "dict", "r2b"], ["rules", "play_targets", "dict", "r2b"],
	["visual", "contract", "int", "r0"], ["visual", "palette", "array", "r0"],
	["visual", "canonical_views", "any", "r1.0"], ["visual", "initial_frame", "dict", "r1.0"],
	["visual", "lights", "dict", "r1"], ["visual", "rain", "dict", "r1"], ["visual", "fog", "dict", "r1"], ["visual", "materials", "dict", "r1"],
	["visual", "props", "dict", "r1"], ["visual", "tokens", "dict", "r1"], ["visual", "markers", "dict", "r1"], ["visual", "units", "dict", "r1"],
	["visual", "quality", "dict", "r1"],
	["visual", "fx", "dict", "r2a"], ["visual", "content_ring", "dict", "r2a"],
	["ui", "contract", "int", "r0"],
	["ui", "jargon_blacklist", "array", "r1.0"], ["ui", "texts", "dict", "r1.0"],
	["ui", "key_table", "array", "r1"], ["ui", "source_tags", "dict", "r1"], ["ui", "camera", "dict", "r1"], ["ui", "minimap", "dict", "r1"],
	["ui", "layout", "dict", "r1"], ["ui", "hud_limits", "dict", "r1"], ["ui", "toasts", "dict", "r1"], ["ui", "onboarding", "dict", "r1"],
	["ui", "tutorial_steps", "array", "r3"]]

## V17: hashes canónicos (claves ordenadas, precisión completa) de los subárboles de data/history.json que NO se pueden tocar, tomados de la
## línea base 5ebbd28. Si una pista edita algo existente, el hash cambia y esta prueba lo dice. Sólo se puede AGREGAR (scenarios.humahuaca y fuentes desde S46).
const HISTORY_HASHES := {
	"scenarios.justine": "b07295a18268b2615a2c07d799acb36b5add8d36a389a6f9cf93f4571f7c0f81",
	"scenarios.norte": "250830fe7d4ef7ef818a426d1292bd9562b98018d1fdaa78ac19371f44e3ee91",
	"fact.humahuaca_arias_al_mando": "3f4c8802ffecac6cc9757496a401970441e55ff865ece84c972508c7157ce76b",
	"sources.primeras_47": "f1c5ca1f5d2a22acc1e2b9d464546a66890d4341c447454a156d31e6f5bc0ff5"}

const HISTORY_BASE_SOURCES := 47
const HISTORY_FACT_TITLE := "Humahuaca: Arias al mando"
const HISTORY_KEYS := ["title", "date", "place", "context", "notice", "facts", "reference_outcome"]

# ---------------------------------------------------------------------------------------------------------------------
# Utilidades de recorrido

## Resuelve «a.b.c» dentro de un Dictionary: {found, value}.
func _get_path(d: Variant, path: String) -> Dictionary:
	var cur: Variant = d
	for part in path.split("."):
		if not (cur is Dictionary) or not (cur as Dictionary).has(part):
			return {"found": false, "value": null}
		cur = cur[part]
	return {"found": true, "value": cur}

func _type_ok(value: Variant, type_name: String) -> bool:
	match type_name:
		"int":
			return (typeof(value) == TYPE_INT) or (typeof(value) == TYPE_FLOAT and is_equal_approx(value, roundf(value)))
		"number":
			return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT
		"string":
			return typeof(value) == TYPE_STRING
		"bool":
			return typeof(value) == TYPE_BOOL
		"dict":
			return value is Dictionary
		"array":
			return value is Array
		"any":
			return true
	return false

## Recorre todo el árbol llamando `visitor(node, path)` en cada Dictionary y en cada Array.
func _walk(node: Variant, path: String, visitor: Callable) -> void:
	if node is Dictionary:
		visitor.call(node, path)
		for key in node:
			_walk(node[key], path + "." + str(key), visitor)
	elif node is Array:
		visitor.call(node, path)
		var i := 0
		for item in node:
			_walk(item, path + "[%d]" % i, visitor)
			i += 1

# ---------------------------------------------------------------------------------------------------------------------
# V1: los seis archivos parsean, contract == 1, map_version igual; formato (UTF-8 sin BOM, LF, sin comas finales, sin NaN)

func v1_identity(files: Dictionary, errors: Dictionary) -> Array:
	var v: Array = []
	for key in FILES:
		if not (files.get(key) is Dictionary):
			v.append("V1 %s: no parsea como objeto JSON (%s)" % [FILES[key], errors.get(key, "?")])
			continue
		var contract: Variant = files[key].get("contract", null)
		if not (typeof(contract) == TYPE_FLOAT or typeof(contract) == TYPE_INT) or int(contract) != 1:
			v.append("V1 %s: \"contract\" debe ser 1 (vale %s)" % [FILES[key], str(contract)])
	var versions := {}
	for key in ["height", "map", "level", "rules"]:
		if files.get(key) is Dictionary:
			versions[key] = files[key].get("map_version", null)
	var reference: Variant = versions.get("map", null)
	for key in versions:
		if versions[key] == null:
			v.append("V1 %s: falta \"map_version\"" % FILES[key])
		elif str(versions[key]) != str(reference):
			v.append("V1 %s: map_version %s distinto del de humahuaca_map.json (%s); un cambio de mapa sube todos a la vez" % [FILES[key], str(versions[key]), str(reference)])
	for key in ["visual", "ui"]:
		if files.get(key) is Dictionary and (files[key] as Dictionary).has("map_version") and str(files[key].map_version) != str(reference):
			v.append("V1 %s: declara map_version %s y el mapa dice %s" % [FILES[key], str(files[key].map_version), str(reference)])
	return v

## Línea (1-based) de la primera coma final («,]» o «,}», ignorando espacios y cadenas), o 0. El parser de Godot las acepta en silencio.
func trailing_comma_line(text: String) -> int:
	var in_string := false
	var line := 1
	var i := 0
	var n := text.length()
	while i < n:
		var c := text[i]
		if c == "\n":
			line += 1
		elif in_string:
			if c == "\\":
				i += 1
			elif c == "\"":
				in_string = false
		elif c == "\"":
			in_string = true
		elif c == ",":
			var j := i + 1
			while j < n and (text[j] == " " or text[j] == "\t" or text[j] == "\n" or text[j] == "\r"):
				j += 1
			if j < n and (text[j] == "]" or text[j] == "}"):
				return line
		i += 1
	return 0

func v1_format(label: String, bytes: PackedByteArray, parsed: Variant) -> Array:
	var v: Array = []
	if bytes.size() >= 3 and bytes[0] == 0xEF and bytes[1] == 0xBB and bytes[2] == 0xBF:
		v.append("V1 %s: tiene BOM (debe ser UTF-8 sin BOM)" % label)
	if bytes.has(13):
		v.append("V1 %s: tiene fines de línea CRLF (deben ser LF; .gitattributes los fuerza al hacer checkout, pero el archivo en disco no)" % label)
	var comma := trailing_comma_line(bytes.get_string_from_utf8())
	if comma > 0:
		v.append("V1 %s: coma final antes de un cierre (línea %d)" % [label, comma])
	var bad: Array = []
	if parsed != null:
		_walk(parsed, "", func(node, path): _collect_nonfinite(node, path, bad))
	if not bad.is_empty():
		v.append("V1 %s: número no finito (NaN o infinito) en %s" % [label, str(bad[0])])
	return v

func _collect_nonfinite(node: Variant, path: String, bad: Array) -> void:
	if node is Dictionary:
		for key in node:
			if typeof(node[key]) == TYPE_FLOAT and not is_finite(node[key]):
				bad.append(path + "." + str(key))
	elif node is Array:
		var i := 0
		for item in node:
			if typeof(item) == TYPE_FLOAT and not is_finite(item):
				bad.append(path + "[%d]" % i)
			i += 1

# ---------------------------------------------------------------------------------------------------------------------
# V2: claves obligatorias con su tipo, según la ronda

func v2_required(files: Dictionary, round_now: String, only_pista: String = "") -> Array:
	var v: Array = []
	for req in REQ:
		var key: String = req[0]
		if not _required_now(req, round_now, only_pista):
			continue
		if not (files.get(key) is Dictionary):
			continue  # el archivo roto ya lo dice V1
		var found := _get_path(files[key], str(req[1]))
		if not found.found:
			v.append("V2 %s: falta la clave «%s» (obligatoria desde %s; dueño: %s)" % [FILES[key], req[1], req[3], OWNER_NAMES[key]])
		elif not _type_ok(found.value, str(req[2])):
			v.append("V2 %s: «%s» debe ser %s y es %s" % [FILES[key], req[1], req[2], Fx.kind_of(found.value)])
	return v

## ¿Esta clave se exige ahora? En r1.0 con `--pista` solo se exigen las claves de r1.0 de los archivos de esa pista (cada worktree trae solo lo suyo).
func _required_now(req: Array, round_now: String, only_pista: String) -> bool:
	if not Fx.round_ge(round_now, str(req[3])):
		return false
	return not (round_now == "r1.0" and only_pista != "" and str(req[3]) == "r1.0" and PISTA_OF_FILE[req[0]] != only_pista)

# ---------------------------------------------------------------------------------------------------------------------
# V3: propiedad de claves

func v3_ownership(files: Dictionary) -> Dictionary:
	var v: Array = []
	var unknown := {}
	for key in FILES:
		if not (files.get(key) is Dictionary):
			continue
		for top in files[key]:
			var k := str(top)
			if (OWNER_KEYS[key] as Array).has(k):
				continue
			var owner_key := ""
			for other in OWNER_KEYS:
				if other != key and (OWNER_KEYS[other] as Array).has(k):
					owner_key = other
					break
			if owner_key != "":
				v.append("V3 %s: la clave «%s» es de %s (dueño: %s); acá no puede aparecer" % [FILES[key], k, FILES[owner_key], OWNER_NAMES[owner_key]])
			else:
				if not unknown.has(key):
					unknown[key] = []
				unknown[key].append(k)
	return {"violations": v, "unknown": unknown}

# ---------------------------------------------------------------------------------------------------------------------
# V4: etiquetas honestas

func _weakest_tag(tags: Array) -> String:
	var weakest := -1
	for t in tags:
		weakest = maxi(weakest, TAGS.find(str(t)))
	return TAGS[weakest] if weakest >= 0 else ""

func v4_tags(files: Dictionary) -> Array:
	var v: Array = []
	for key in FILES:
		if not (files.get(key) is Dictionary):
			continue
		var label: String = FILES[key]
		_walk(files[key], "", func(node, path):
			if not (node is Dictionary):
				return
			var d: Dictionary = node
			if d.has("tag"):
				if typeof(d.tag) != TYPE_STRING or not TAGS.has(d.tag):
					v.append("V4 %s%s: tag «%s» no es uno de %s" % [label, path, str(d.tag), str(TAGS)])
				if d.has("source") and typeof(d.source) == TYPE_STRING and String(d.source).length() > 120:
					v.append("V4 %s%s: source de %d caracteres (máximo 120)" % [label, path, String(d.source).length()])
			if d.has("tag_parts"):
				if not (d.tag_parts is Dictionary) or (d.tag_parts as Dictionary).size() < 2:
					v.append("V4 %s%s: tag_parts necesita al menos 2 partes" % [label, path])
				else:
					var parts: Array = (d.tag_parts as Dictionary).values()
					var all_valid := true
					for p in parts:
						if typeof(p) != TYPE_STRING or not TAGS.has(p):
							all_valid = false
					if not all_valid:
						v.append("V4 %s%s: tag_parts con una etiqueta inválida" % [label, path])
					elif str(d.get("tag", "")) != _weakest_tag(parts):
						v.append("V4 %s%s: tag «%s» debe ser la parte más débil de tag_parts («%s»)" % [label, path, str(d.get("tag", "")), _weakest_tag(parts)]))
	# hitos: cada uno trae tag y source (≤ 120)
	var map_data: Variant = files.get("map")
	if map_data is Dictionary and (map_data as Dictionary).get("landmarks", null) is Array:
		var i := 0
		for lm in map_data.landmarks:
			if not (lm is Dictionary):
				v.append("V4 humahuaca_map.json landmarks[%d]: no es un objeto" % i)
			else:
				if not lm.has("tag"):
					v.append("V4 humahuaca_map.json landmarks[%d] (%s): falta tag" % [i, str(lm.get("id", "?"))])
				if typeof(lm.get("source", null)) != TYPE_STRING or String(lm.get("source", "")).strip_edges() == "" or String(lm.get("source", "")).length() > 120:
					v.append("V4 humahuaca_map.json landmarks[%d] (%s): source debe ser un texto de 1 a 120 caracteres" % [i, str(lm.get("id", "?"))])
			i += 1
	return v

# ---------------------------------------------------------------------------------------------------------------------
# V5: ids únicos y referencias que resuelven

func _landmark_ids(files: Dictionary) -> Array:
	var ids: Array = []
	var map_data: Variant = files.get("map")
	if map_data is Dictionary and (map_data as Dictionary).get("landmarks", null) is Array:
		for lm in map_data.landmarks:
			if lm is Dictionary and typeof(lm.get("id", null)) == TYPE_STRING:
				ids.append(lm.id)
	return ids

func v5_ids_and_refs(files: Dictionary, round_now: String, cross_files: bool = true) -> Array:
	var v: Array = []
	for key in FILES:
		if not (files.get(key) is Dictionary):
			continue
		var label: String = FILES[key]
		_walk(files[key], "", func(node, path):
			if not (node is Array):
				return
			var seen := {}
			for item in node:
				if item is Dictionary and typeof(item.get("id", null)) == TYPE_STRING:
					if seen.has(item.id):
						v.append("V5 %s%s: el id «%s» está repetido" % [label, path, item.id])
					seen[item.id] = true)
	var lm_ids := _landmark_ids(files)
	if Fx.round_ge(round_now, "r1.0") and files.get("map") is Dictionary and (files.map as Dictionary).get("landmarks", null) is Array:
		for mandatory in MANDATORY_LANDMARKS:
			if not lm_ids.has(mandatory):
				v.append("V5 humahuaca_map.json: falta el hito obligatorio «%s» (los usan reglas, vista y UI por nombre)" % mandatory)
	if not cross_files:
		return v  # r1.0 de una sola pista: las referencias entre archivos de distintas pistas se verifican cuando se integran las cuatro
	var level: Variant = files.get("level")
	if level is Dictionary:
		var access: Variant = level.get("access", null)
		if access is Dictionary:
			if lm_ids.is_empty():
				v.append("V5 humahuaca_level.json: access cita hitos pero humahuaca_map.json no tiene landmarks")
			else:
				var spawns: Variant = access.get("spawns", null)
				if spawns is Dictionary:
					for g in GROUPS:
						if not (spawns as Dictionary).has(g):
							v.append("V5 humahuaca_level.json access.spawns: falta la agrupación «%s»" % g)
					for g in spawns:
						var target := str(spawns[g])
						if not target.begins_with("spawn_") or not lm_ids.has(target):
							v.append("V5 humahuaca_level.json access.spawns.%s: «%s» no es un hito spawn_* existente" % [g, target])
				var single_refs := {"zona_partida": "access.zona_partida", "south_entry": "access.south_entry"}
				for ref_key in single_refs:
					if (access as Dictionary).has(ref_key) and not lm_ids.has(str(access[ref_key])):
						v.append("V5 humahuaca_level.json %s: «%s» no es un hito existente" % [single_refs[ref_key], str(access[ref_key])])
				var exit_data: Variant = access.get("exit", null)
				if exit_data is Dictionary:
					for e in exit_data:
						if not lm_ids.has(str(exit_data[e])):
							v.append("V5 humahuaca_level.json access.exit.%s: «%s» no es un hito existente" % [e, str(exit_data[e])])
				var posts: Variant = access.get("attack_posts", null)
				if posts is Dictionary:
					for o in OBJECTIVES:
						if not (posts as Dictionary).has(o):
							v.append("V5 humahuaca_level.json access.attack_posts: falta el frente «%s» (deben estar los 3)" % o)
		var zones: Variant = level.get("zones", null)
		if zones is Array:
			var zi := 0
			for z in zones:
				if z is Dictionary and z.has("objective") and str(z.objective) != "" and not OBJECTIVES.has(str(z.objective)):
					v.append("V5 humahuaca_level.json zones[%d]: objective «%s» no es uno de %s" % [zi, str(z.objective), str(OBJECTIVES)])
				zi += 1
	# convención de referencia: una cadena bajo «landmark», «landmark_id» o «hito» en reglas, nivel, vista o interfaz debe ser un hito existente
	if not lm_ids.is_empty():
		for key in ["level", "rules", "visual", "ui"]:
			if not (files.get(key) is Dictionary):
				continue
			_walk(files[key], "", func(node, path):
				if not (node is Dictionary):
					return
				for ref_key in ["landmark", "landmark_id", "hito"]:
					if node.has(ref_key) and typeof(node[ref_key]) == TYPE_STRING and not lm_ids.has(node[ref_key]):
						v.append("V5 %s%s.%s: «%s» no es un hito de humahuaca_map.json" % [FILES[key], path, ref_key, node[ref_key]]))
	return v

# ---------------------------------------------------------------------------------------------------------------------
# V7: grilla de relieve

func _bilinear(grid: Dictionary, x: float, z: float) -> float:
	var h: Array = grid.h
	var nx := int(grid.nx)
	var nz := int(grid.nz)
	var fx := (x - float(grid.origin_x)) / float(grid.cell_m)
	var fz := (z - float(grid.origin_z)) / float(grid.cell_m)
	var i0 := clampi(floori(fx), 0, nx - 2)
	var j0 := clampi(floori(fz), 0, nz - 2)
	var tx := fx - float(i0)
	var tz := fz - float(j0)
	var a := float(h[j0 * nx + i0])
	var b := float(h[j0 * nx + i0 + 1])
	var c := float(h[(j0 + 1) * nx + i0])
	var d := float(h[(j0 + 1) * nx + i0 + 1])
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)

func v7_grid(height: Variant, map_data: Variant) -> Array:
	var v: Array = []
	if not (height is Dictionary):
		return ["V7 humahuaca_height.json: no es un objeto"]
	var meta: Dictionary = height.get("meta", {}) if height.get("meta", null) is Dictionary else {}
	if not SOURCES_ENUM.has(str(meta.get("source", ""))):
		v.append("V7 height.meta.source «%s» no está en %s" % [str(meta.get("source", "")), str(SOURCES_ENUM)])
	if str(meta.get("unit", "")) != "dm":
		v.append("V7 height.meta.unit debe ser «dm» (decímetros enteros sobre el cero local)")
	if not is_equal_approx(float(meta.get("datum_asl_m", -1.0)), 2940.0):
		v.append("V7 height.meta.datum_asl_m debe ser 2940,0 (vale %s)" % str(meta.get("datum_asl_m", "?")))
	if map_data is Dictionary and not is_equal_approx(float((map_data as Dictionary).get("datum_asl_m", -1.0)), float(meta.get("datum_asl_m", -2.0))):
		v.append("V7 height.meta.datum_asl_m (%s) debe igualar map.datum_asl_m (%s)" % [str(meta.get("datum_asl_m", "?")), str((map_data as Dictionary).get("datum_asl_m", "?"))])
	if str(meta.get("order", "")).find("norte->sur") < 0:
		v.append("V7 height.meta.order debe describir «filas norte->sur, columnas oeste->este»")
	if float(meta.get("uncertainty_m", 0.0)) <= 0.0:
		v.append("V7 height.meta.uncertainty_m debe ser mayor que 0")
	var expected := {"window": {"nx": 91, "nz": 66, "cell_m": 10.0, "origin_x": 0.0, "origin_z": 0.0},
		"context": {"nx": 121, "nz": 91, "cell_m": 30.0, "origin_x": -1350.0, "origin_z": -1025.0}}
	for grid_name in expected:
		var grid: Variant = height.get(grid_name, null)
		if not (grid is Dictionary):
			v.append("V7 height.%s: falta la grilla" % grid_name)
			continue
		for k in expected[grid_name]:
			if not is_equal_approx(float(grid.get(k, -99999.0)), float(expected[grid_name][k])):
				v.append("V7 height.%s.%s debe ser %s y vale %s" % [grid_name, k, str(expected[grid_name][k]), str(grid.get(k, "?"))])
		var h: Variant = grid.get("h", null)
		if not (h is Array):
			v.append("V7 height.%s.h no es un arreglo" % grid_name)
			continue
		if (h as Array).size() != int(grid.get("nx", 0)) * int(grid.get("nz", 0)):
			v.append("V7 height.%s.h tiene %d valores y nx·nz es %d" % [grid_name, (h as Array).size(), int(grid.get("nx", 0)) * int(grid.get("nz", 0))])
			continue
		var bad_type := 0
		var out_of_range := 0
		var lo := 1.0e9
		var hi := -1.0e9
		for value in h:
			if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
				bad_type += 1
				continue
			var f := float(value)
			if not is_equal_approx(f, roundf(f)):
				bad_type += 1
			if f < -300.0 or f > 3000.0:
				out_of_range += 1
			lo = minf(lo, f)
			hi = maxf(hi, f)
		if bad_type > 0:
			v.append("V7 height.%s.h: %d valores no son decímetros enteros" % [grid_name, bad_type])
		if out_of_range > 0:
			v.append("V7 height.%s.h: %d valores fuera de [−300, 3 000] dm" % [grid_name, out_of_range])
		var stats: Variant = (height.get("stats", {}) as Dictionary).get(grid_name, null) if height.get("stats", null) is Dictionary else null
		if stats is Dictionary and stats.has("min") and stats.has("max"):
			if not is_equal_approx(float(stats.min), lo) or not is_equal_approx(float(stats.max), hi):
				v.append("V7 height.stats.%s dice min/max %s/%s y la grilla tiene %s/%s" % [grid_name, str(stats.min), str(stats.max), str(lo), str(hi)])
	# los nodos del borde de la ventana coinciden con el contexto (interpolación bilineal) a ≤ 1 dm
	if height.get("window", null) is Dictionary and height.get("context", null) is Dictionary and v.is_empty():
		var win: Dictionary = height.window
		var ctx: Dictionary = height.context
		var worst := 0.0
		var nx := int(win.nx)
		var nz := int(win.nz)
		for j in range(nz):
			for i in range(nx):
				if i != 0 and i != nx - 1 and j != 0 and j != nz - 1:
					continue
				var x := float(win.origin_x) + float(i) * float(win.cell_m)
				var z := float(win.origin_z) + float(j) * float(win.cell_m)
				worst = maxf(worst, absf(float(win.h[j * nx + i]) - _bilinear(ctx, x, z)))
		if worst > 1.0:
			v.append("V7 el borde de height.window difiere del contexto interpolado hasta %.2f dm (máximo 1 dm)" % worst)
	return v

func v8_sizes(sizes: Dictionary, data_files: Array) -> Array:
	var v: Array = []
	for key in SIZE_CAPS_KB:
		var kb: float = float(sizes.get(key, 0)) / 1024.0
		if kb > float(SIZE_CAPS_KB[key]):
			v.append("V8 %s pesa %.1f KB y el tope es %d KB (dueño: %s)" % [FILES[key], kb, SIZE_CAPS_KB[key], OWNER_NAMES[key]])
	for f in data_files:
		if not String(f).ends_with(".json"):
			v.append("V8 %s: data/ solo admite .json (export_presets.cfg solo exporta data/*.json; un binario no llegaría al EXE)" % f)
	return v

# ---------------------------------------------------------------------------------------------------------------------
# V9: paleta de 24 HEX

func _is_loose_hex(s: String) -> bool:
	var rx := RegEx.new()
	rx.compile("^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$")
	return rx.search(s) != null

func v9_palette(visual: Variant) -> Array:
	var v: Array = []
	if not (visual is Dictionary) or not ((visual as Dictionary).get("palette", null) is Array):
		return ["V9 humahuaca_visual.json: falta palette (arreglo de 24 entradas)"]
	var palette: Array = visual.palette
	if palette.size() != 24:
		v.append("V9 palette tiene %d entradas y deben ser exactamente 24" % palette.size())
	var ids := {}
	var hexes: Array = []
	var i := 0
	for entry in palette:
		if not (entry is Dictionary):
			v.append("V9 palette[%d] no es un objeto {id, name, group, hex}" % i)
		else:
			for k in ["id", "name", "group", "hex"]:
				if typeof(entry.get(k, null)) != TYPE_STRING or String(entry[k]) == "":
					v.append("V9 palette[%d] (%s): falta «%s»" % [i, str(entry.get("id", "?")), k])
			if ids.has(entry.get("id", "")):
				v.append("V9 palette[%d]: el id «%s» está repetido" % [i, str(entry.get("id", ""))])
			ids[entry.get("id", "")] = true
			if typeof(entry.get("hex", null)) == TYPE_STRING:
				hexes.append(String(entry.hex).to_upper())
		i += 1
	for expected_hex in PALETTE_24:
		if not hexes.has(expected_hex):
			v.append("V9 falta el HEX %s de la lámina 06" % expected_hex)
	for h in hexes:
		if not PALETTE_24.has(h):
			v.append("V9 el HEX %s no está en la lámina 06 (no se puede cambiar ni agregar un color)" % h)
	# colores sueltos en props y tokens (los markers de interfaz están exentos); los colores se citan por id de paleta
	for section in ["props", "tokens"]:
		if visual.get(section, null) == null:
			continue
		_walk(visual[section], "", func(node, path):
			if node is Dictionary:
				for key in node:
					var value: Variant = node[key]
					if typeof(value) == TYPE_STRING and _is_loose_hex(value):
						v.append("V9 visual.%s%s.%s: HEX suelto «%s»; hay que citar un id de paleta" % [section, path, key, value])
					elif typeof(value) == TYPE_STRING and String(key).to_lower().find("color") >= 0 and not ids.has(value):
						v.append("V9 visual.%s%s.%s: «%s» no es un id de la paleta" % [section, path, key, value])
			elif node is Array:
				for item in node:
					if typeof(item) == TYPE_STRING and _is_loose_hex(item):
						v.append("V9 visual.%s%s: HEX suelto «%s»" % [section, path, item]))
	return v

# ---------------------------------------------------------------------------------------------------------------------
# V13 (solo-agregar): los vocabularios no pierden ids

func v13_vocab_add_only(vocab_name: String, actual: Dictionary) -> Array:
	var v: Array = []
	var minimum: Dictionary = Fx.VOCAB_MIN[vocab_name]
	var ordered := ["GROUPS", "COMBAT_GROUPS", "OBJECTIVES", "TAGS"]  # el orden es parte del contrato (teclas 1 a 5; de más fuerte a más débil)
	for const_name in minimum:
		if not actual.has(const_name):
			v.append("%s: falta la constante %s (quitar o renombrar exige addendum)" % [vocab_name, const_name])
			continue
		var base: Variant = minimum[const_name]
		var now: Variant = actual[const_name]
		if base is Array:
			if not (now is Array):
				v.append("%s.%s debía ser una lista" % [vocab_name, const_name])
				continue
			for item in base:
				if not (now as Array).has(item):
					v.append("%s.%s: falta «%s» (quitar o renombrar un id exige addendum)" % [vocab_name, const_name, str(item)])
			if ordered.has(const_name) and (now as Array).slice(0, (base as Array).size()) != base:
				v.append("%s.%s: los primeros %d ids deben seguir en su orden (%s)" % [vocab_name, const_name, (base as Array).size(), str(base)])
		elif base is Dictionary:
			if not (now is Dictionary):
				v.append("%s.%s debía ser un diccionario" % [vocab_name, const_name])
				continue
			for sub_key in base:
				if not (now as Dictionary).has(sub_key):
					v.append("%s.%s: falta la clave «%s»" % [vocab_name, const_name, str(sub_key)])
				elif base[sub_key] is Array:
					for item in base[sub_key]:
						if not (now[sub_key] as Array).has(item):
							v.append("%s.%s.%s: falta «%s»" % [vocab_name, const_name, str(sub_key), str(item)])
		elif str(base) != str(now):
			v.append("%s.%s cambió de «%s» a «%s» (renombrar exige addendum)" % [vocab_name, const_name, str(base), str(now)])
	return v

## V13 (la otra mitad): las claves de rules.groups, objectives y actions son exactamente los ids de los vocabularios, y las clases de botín
## (rules.loot.kinds, .classes o .items, el primero que sea un objeto) son las 5 de LOOT_KINDS_R1 antes de r2a y las 9 de LOOT_KINDS desde r2a.
func v13_rules_vs_vocab(rules: Variant, round_now: String) -> Array:
	var v: Array = []
	if not (rules is Dictionary):
		return v
	var expected := {"groups": GROUPS, "objectives": OBJECTIVES, "actions": _all_actions()}
	for key in expected:
		var section: Variant = (rules as Dictionary).get(key, null)
		if not (section is Dictionary):
			continue  # que la sección exista lo exige V2
		for id in expected[key]:
			if not (section as Dictionary).has(id):
				v.append("V13 humahuaca_rules.json %s: falta el id «%s» del vocabulario" % [key, id])
		for id in section:
			if not (expected[key] as Array).has(str(id)):
				v.append("V13 humahuaca_rules.json %s: el id «%s» no está en el vocabulario (sumarlo al vocabulario de su dueño es legal; usarlo sin sumarlo, no)" % [key, id])
	var loot: Variant = (rules as Dictionary).get("loot", null)
	if loot is Dictionary:
		for container in ["kinds", "classes", "items"]:
			if not (loot.get(container, null) is Dictionary):
				continue
			var ids: Array = (loot[container] as Dictionary).keys()
			var all_kinds: Array = _vocab("vocab_rules.gd", "LOOT_KINDS")
			var r1_kinds: Array = _vocab("vocab_rules.gd", "LOOT_KINDS_R1")
			for id in ids:
				if not all_kinds.has(str(id)):
					v.append("V13 humahuaca_rules.json loot.%s: la clase «%s» no está en LOOT_KINDS" % [container, id])
			var needed: Array = all_kinds if Fx.round_ge(round_now, "r2a") else r1_kinds
			for id in needed:
				if not ids.has(id):
					v.append("V13 humahuaca_rules.json loot.%s: falta la clase «%s» (desde %s se exigen %d clases)" % [container, id, "r2a" if Fx.round_ge(round_now, "r2a") else "r1", needed.size()])
			break
	return v

# ---------------------------------------------------------------------------------------------------------------------
# V17: data/history.json

func v17_history(history: Variant) -> Array:
	var v: Array = []
	if not (history is Dictionary):
		return ["V17 data/history.json no parsea como objeto"]
	var scenarios: Dictionary = history.get("scenarios", {}) if history.get("scenarios", null) is Dictionary else {}
	var sources: Array = history.get("sources", []) if history.get("sources", null) is Array else []
	var hx: Variant = scenarios.get("humahuaca", null)
	if not (hx is Dictionary):
		v.append("V17 data/history.json: falta scenarios.humahuaca (title, date, place, context, notice, facts, reference_outcome)")
	else:
		for k in HISTORY_KEYS:
			if not (hx as Dictionary).has(k):
				v.append("V17 scenarios.humahuaca: falta «%s»" % k)
			elif k == "facts":
				if not (hx[k] is Array):
					v.append("V17 scenarios.humahuaca.facts debe ser un arreglo")
			elif typeof(hx[k]) != TYPE_STRING or String(hx[k]).strip_edges() == "":
				v.append("V17 scenarios.humahuaca.%s debe ser un texto no vacío" % k)
	for key in ["justine", "norte"]:
		if not scenarios.has(key):
			v.append("V17 falta scenarios.%s" % key)
		elif Fx.canon_hash(scenarios[key]) != HISTORY_HASHES["scenarios." + key]:
			v.append("V17 scenarios.%s cambió respecto de 5ebbd28 (el hash no coincide): solo se puede AGREGAR, no editar lo existente" % key)
	if scenarios.get("norte", null) is Dictionary:
		var fact: Variant = null
		for f in scenarios.norte.get("facts", []):
			if f is Dictionary and str(f.get("title", "")) == HISTORY_FACT_TITLE:
				fact = f
		if fact == null:
			v.append("V17 el hecho «%s» del Norte ya no está" % HISTORY_FACT_TITLE)
		elif Fx.canon_hash(fact) != HISTORY_HASHES["fact.humahuaca_arias_al_mando"]:
			v.append("V17 el hecho «%s» del Norte cambió (test_rules.gd:3547-3561 fija sus textos)" % HISTORY_FACT_TITLE)
	if sources.size() < HISTORY_BASE_SOURCES:
		v.append("V17 sources tiene %d fuentes y la base tiene %d (no se borran fuentes)" % [sources.size(), HISTORY_BASE_SOURCES])
	elif Fx.canon_hash(sources.slice(0, HISTORY_BASE_SOURCES)) != HISTORY_HASHES["sources.primeras_47"]:
		v.append("V17 las primeras %d fuentes de sources cambiaron respecto de 5ebbd28 (las nuevas se agregan al final desde S46)" % HISTORY_BASE_SOURCES)
	var ids := {}
	var rx := RegEx.new()
	rx.compile("^S(\\d+)[a-z]?$")
	var index := 0
	for src in sources:
		var sid := str(src.get("id", "")) if src is Dictionary else ""
		if ids.has(sid):
			v.append("V17 sources[%d]: el id «%s» está repetido" % [index, sid])
		ids[sid] = true
		if index >= HISTORY_BASE_SOURCES:
			var m := rx.search(sid)
			if m == null or int(m.get_string(1)) < 46:
				v.append("V17 sources[%d]: la fuente nueva «%s» debe llamarse S46 o más (las fuentes del nivel empiezan en S46)" % [index, sid])
		index += 1
	return v

# ---------------------------------------------------------------------------------------------------------------------
# V19: grafo de dependencias, convenciones del código y carga individual

func _scan_line(line: String, triple_in: String) -> Dictionary:
	var kept := ""
	var triple := triple_in
	var quote := ""
	var i := 0
	var n := line.length()
	while i < n:
		var c := line[i]
		if triple != "":
			if line.substr(i, 3) == triple:
				kept += triple
				triple = ""
				i += 3
			else:
				kept += c
				i += 1
			continue
		if quote != "":
			if c == "\\" and i + 1 < n:
				kept += line.substr(i, 2)
				i += 2
				continue
			kept += c
			if c == quote:
				quote = ""
			i += 1
			continue
		if c == "#":
			break
		if c == "\"" or c == "'":
			if line.substr(i, 3) == c + c + c:
				triple = c + c + c
				kept += triple
				i += 3
				continue
			quote = c
		kept += c
		i += 1
	return {"text": kept, "triple": triple}

## El código sin comentarios (conserva el contenido de las cadenas): lo que importa para leer `preload` y `load`.
func strip_comments(src: String) -> String:
	var out: Array = []
	var triple := ""
	for line in src.split("\n"):
		if triple == "" and line.find("#") < 0 and line.find("\"\"\"") < 0 and line.find("'''") < 0:
			out.append(line)
			continue
		var scanned := _scan_line(line, triple)
		out.append(scanned.text)
		triple = scanned.triple
	return "\n".join(out)

func imports_of(src: String) -> Array:
	var clean := strip_comments(src)
	var found: Array = []
	var rx := RegEx.new()
	rx.compile("(?:preload|load)\\(\\s*\"(res://scripts/humahuaca/[^\"]+)\"|extends\\s+\"(res://scripts/humahuaca/[^\"]+)\"")
	for m in rx.search_all(clean):
		var target := m.get_string(1) if m.get_string(1) != "" else m.get_string(2)
		if not found.has(target):
			found.append(target)
	return found

## Capa de un archivo de scripts/humahuaca/: -1 compartido, 0 terreno, 1 reglas, 2 vista, 3 interfaz; -9 desconocida.
func layer_of(path: String) -> int:
	var rel := path.trim_prefix(SCRIPTS_DIR + "/")
	if rel == "humahuaca_vocab.gd":
		return -1
	if rel.begins_with("terrain/"):
		return 0
	if rel.begins_with("rules/"):
		return 1
	if rel.begins_with("view/"):
		return 2
	if rel.begins_with("ui/"):
		return 3
	if rel.begins_with("stubs/"):
		var f := rel.get_file()
		if f.begins_with("stub_terrain"):
			return 0
		if f.begins_with("stub_rules") or f.begins_with("stub_progress"):
			return 1
		if f.begins_with("stub_view"):
			return 2
		if f.begins_with("stub_ui"):
			return 3
	return -9

func _find_cycle(graph: Dictionary) -> Array:
	var state := {}
	var stack: Array = []
	for start in graph:
		if state.get(start, 0) == 0:
			var cycle := _dfs_cycle(start, graph, state, stack)
			if not cycle.is_empty():
				return cycle
	return []

func _dfs_cycle(node: String, graph: Dictionary, state: Dictionary, stack: Array) -> Array:
	state[node] = 1
	stack.append(node)
	for dep in graph.get(node, []):
		if state.get(dep, 0) == 1:
			return stack.slice(stack.find(dep)) + [dep]
		if state.get(dep, 0) == 0 and graph.has(dep):
			var cycle := _dfs_cycle(dep, graph, state, stack)
			if not cycle.is_empty():
				return cycle
	stack.pop_back()
	state[node] = 2
	return []

## Regla de dependencia (CONTRATO 0 y 7): solo hacia abajo (UI → vista → reglas → terreno), sin ciclos, y un stub no depende del código real.
func v19_graph(sources: Dictionary) -> Dictionary:
	var v: Array = []
	var graph := {}
	var edges := 0
	for path in sources:
		var rank := layer_of(path)
		if rank == -9:
			v.append("V19 %s: no se sabe a qué capa pertenece (va en terrain/, rules/, view/, ui/, stubs/stub_<capa>*.gd o es humahuaca_vocab.gd)" % path)
			continue
		var deps: Array = imports_of(sources[path])
		graph[path] = deps
		var is_stub := String(path).begins_with(SCRIPTS_DIR + "/stubs/")
		for dep in deps:
			edges += 1
			var dep_rank := layer_of(dep)
			if dep_rank == -9:
				v.append("V19 %s importa %s, que no está en una carpeta de capa conocida" % [path, dep])
			elif dep_rank > rank:
				v.append("V19 %s (capa %d) importa %s (capa %d): la dependencia solo va hacia abajo (UI → vista → reglas → terreno)" % [path, rank, dep, dep_rank])
			if is_stub and not (String(dep).begins_with(SCRIPTS_DIR + "/stubs/") or dep == SCRIPTS_DIR + "/humahuaca_vocab.gd" or String(dep).get_file().begins_with("vocab_")):
				v.append("V19 el stub %s importa %s: un stub no depende del código real de la pista (CONTRATO 7)" % [path, dep])
			if not sources.has(dep) and layer_of(dep) != -9:
				v.append("V19 %s importa %s, que no existe" % [path, dep])
	var cycle := _find_cycle(graph)
	if not cycle.is_empty():
		v.append("V19 ciclo de dependencias: %s" % " → ".join(PackedStringArray(cycle)))
	return {"violations": v, "edges": edges, "files": sources.size()}

## Convenciones de código del nivel (CONTRATO 0): sin class_name, LF, tabs, ≤ ~1 500 líneas; las reglas no usan azar ni reloj globales.
func v19_conventions(sources: Dictionary) -> Dictionary:
	var v: Array = []
	var long_files: Array = []
	for path in sources:
		var text: String = sources[path]
		var clean := strip_comments(text)
		var rx_class := RegEx.new()
		rx_class.compile("(?m)^\\s*class_name\\s")
		if rx_class.search(clean) != null:
			v.append("%s: usa class_name (el contrato manda const X = preload(...): class_name falla en worktrees nuevos)" % path)
		if text.find("\r") >= 0:
			v.append("%s: tiene fines de línea CRLF (deben ser LF)" % path)
		var lines := text.split("\n")
		if lines.size() > MAX_SCRIPT_LINES:
			v.append("%s: tiene %d líneas (máximo ≈ 1 500; se parte por responsabilidad dentro de la carpeta de la pista)" % [path, lines.size()])
		elif lines.size() > 1500:
			long_files.append(path)
		var in_triple := false
		var line_no := 0
		for line in lines:
			line_no += 1
			if line.count("\"\"\"") % 2 == 1:
				in_triple = not in_triple
				continue
			if not in_triple and line.length() > 1 and line[0] == " " and line.strip_edges() != "" and not line.strip_edges().begins_with("#"):
				v.append("%s:%d: indentación con espacios (el código del nivel usa tabs)" % [path, line_no])
				break
		if String(path).ends_with("/rules/humahuaca_rules.gd") or String(path).ends_with("/stubs/stub_rules.gd"):
			var rx_rng := RegEx.new()
			rx_rng.compile("(?<![\\w.])(randf|randi|randf_range|randi_range|randomize)\\(|\\bTime\\.")
			var hit := rx_rng.search(clean)
			if hit != null:
				v.append("%s: usa «%s» (las reglas son deterministas: RNG propio, nunca randf/randi ni Time)" % [path, hit.get_string()])
	return {"violations": v, "long_files": long_files}

# ---------------------------------------------------------------------------------------------------------------------
# V20: trazabilidad exigencia → prueba (docs/humahuaca/TRAZA.md)

func _traza_rows(text: String) -> Array:
	var rows: Array = []
	var rx := RegEx.new()
	rx.compile("^TR-\\d+$")
	var line_no := 0
	for line in text.split("\n"):
		line_no += 1
		var l := line.strip_edges()
		if not l.begins_with("|"):
			continue
		var cells: Array = []
		for c in l.split("|"):
			cells.append(String(c).strip_edges())
		cells = cells.slice(1, cells.size() - 1) if cells.size() > 2 else cells
		if cells.size() < 5 or rx.search(cells[0]) == null:
			continue
		rows.append({"id": cells[0], "sec": cells[1], "req": cells[2], "test": String(cells[3]).trim_prefix("`").trim_suffix("`"), "due": cells[4], "line": line_no})
	return rows

func _func_exists(path: String, text: String, func_name: String) -> bool:
	var rx := RegEx.new()
	if path.ends_with(".sh"):
		rx.compile("(?m)^\\s*(function\\s+)?%s\\s*\\(\\)" % func_name)
	elif path.ends_with(".py"):
		rx.compile("(?m)^\\s*def\\s+%s\\s*\\(" % func_name)
	else:
		rx.compile("(?m)^\\s*(static\\s+)?func\\s+%s\\s*\\(" % func_name)
	return rx.search(text) != null

## Valida las filas de TRAZA.md. `read_fn(path) -> String` devuelve el texto de un archivo ("" si falta). Resultado: {violations, rows, active, pending, advanced}.
func v20_traza(traza_text: String, contract_text: String, qa_text: String, round_now: String, read_fn: Callable) -> Dictionary:
	var v: Array = []
	var rows := _traza_rows(traza_text)
	var seen_ids := {}
	var covered := {}
	var qa_ids := {}
	var rx_qa := RegEx.new()
	rx_qa.compile("(?m)^\\| ([A-Z]\\d{2}) \\|")
	for m in rx_qa.search_all(qa_text):
		qa_ids[m.get_string(1)] = true
	var rx_ident := RegEx.new()
	rx_ident.compile("^[A-Za-z_][A-Za-z0-9_]*$")
	var active := 0
	var pending := 0
	var advanced := 0
	for row in rows:
		if seen_ids.has(row.id):
			v.append("V20 TRAZA.md línea %d: el id %s está repetido" % [row.line, row.id])
		seen_ids[row.id] = true
		covered[row.sec] = true
		if not Fx.ROUNDS.has(row.due):
			v.append("V20 TRAZA.md %s: la ronda «%s» no existe (%s)" % [row.id, row.due, str(Fx.ROUNDS)])
			continue
		var due_now: bool = Fx.round_ge(round_now, row.due)
		var ref: String = row.test
		var resolved := false
		if ref.begins_with("QA:"):
			resolved = qa_ids.has(ref.trim_prefix("QA:"))
			if not resolved and due_now:
				v.append("V20 TRAZA.md %s: «%s» no es un ítem de la rúbrica de docs/QA_NIVEL2.md" % [row.id, ref])
		elif ref.find("::") > 0:
			var parts := ref.split("::")
			var path := traza_file_path(parts[0])
			var func_name: String = parts[1]
			if rx_ident.search(func_name) == null:
				v.append("V20 TRAZA.md %s: el nombre de función «%s» no es un identificador" % [row.id, func_name])
			else:
				var text: String = read_fn.call(path)
				resolved = text != "" and _func_exists(path, text, func_name)
				if not resolved and due_now:
					v.append("V20 TRAZA.md %s: la prueba %s no existe (archivo %s%s) y la ronda vigente %s ya la exige (desde %s)" % [row.id, ref, path.trim_prefix("res://"), "" if text != "" else ", que falta", round_now, row.due])
		else:
			v.append("V20 TRAZA.md %s: la prueba «%s» debe ser archivo::función o QA:<ítem>" % [row.id, ref])
		if due_now:
			active += 1
		elif resolved:
			advanced += 1
		else:
			pending += 1
	# ninguna exigencia de las secciones 3 a 5 del contrato queda sin fila
	var rx_head := RegEx.new()
	rx_head.compile("(?m)^#{3,4}\\s+(\\d+\\.\\d+(?:\\.\\d+)?)\\s")
	var sections: Array = []
	for m in rx_head.search_all(contract_text):
		var sec := m.get_string(1)
		if (sec.begins_with("3.") or sec.begins_with("4.") or sec.begins_with("5.")) and not sections.has(sec):
			sections.append(sec)
	for sec in sections:
		if not covered.has(sec):
			v.append("V20 la sección %s del contrato no tiene ninguna fila en TRAZA.md (ninguna exigencia de las secciones 3 a 5 queda sin fila)" % sec)
	return {"violations": v, "rows": rows.size(), "active": active, "pending": pending, "advanced": advanced, "sections": sections.size()}

# ---------------------------------------------------------------------------------------------------------------------
# Ejemplos de forma (CONTRATO 3.6): existen, parsean, traen todas las claves y sus ids son del vocabulario

func _path_exists_in_example(example: Variant, path: String) -> bool:
	var cur: Variant = example
	for part in path.split("."):
		var key := part
		var through_array := false
		if key.ends_with("[]"):
			key = key.trim_suffix("[]")
			through_array = true
		if not (cur is Dictionary) or not (cur as Dictionary).has(key):
			return false
		cur = cur[key]
		if through_array:
			if not (cur is Array) or (cur as Array).is_empty():
				return false
			cur = cur[0]
	return true

func _vocab(vocab_name: String, const_name: String) -> Variant:
	return (Fx.VOCAB_MIN[vocab_name] as Dictionary)[const_name]

func _all_actions() -> Array:
	var all: Array = []
	var groups: Dictionary = _vocab("vocab_rules.gd", "ACTIONS")
	for kind in groups:
		for a in groups[kind]:
			if not all.has(a):
				all.append(a)
	return all

func forma_vocab_violations(forma_name: String, ex: Dictionary) -> Array:
	var v: Array = []
	var phases: Array = _vocab("vocab_rules.gd", "PHASES")
	var front_states: Array = _vocab("vocab_rules.gd", "FRONT_STATES")
	match forma_name:
		"hud_state":
			if not phases.has(str(ex.fase.id)):
				v.append("fase.id «%s» no es una fase" % str(ex.fase.id))
			var front_ids: Array = []
			for f in ex.frentes:
				front_ids.append(f.id)
				if not front_states.has(str(f.estado)):
					v.append("frentes[%s].estado «%s» no es un estado de frente" % [f.id, str(f.estado)])
				if not TAGS.has(str(f.tag)):
					v.append("frentes[%s].tag «%s» no es una etiqueta" % [f.id, str(f.tag)])
			if front_ids != OBJECTIVES:
				v.append("frentes debe traer los 3 objetivos en orden %s" % str(OBJECTIVES))
			var group_ids: Array = []
			for g in ex.grupos:
				group_ids.append(g.id)
				if not ["silencio", "se_oye", "los_oyen"].has(str(g.ruido)):
					v.append("grupos[%s].ruido «%s» no es silencio, se_oye ni los_oyen" % [g.id, str(g.ruido)])
				if not TAGS.has(str(g.tag)):
					v.append("grupos[%s].tag «%s» no es una etiqueta" % [g.id, str(g.tag)])
			if group_ids != GROUPS:
				v.append("grupos debe traer las 5 agrupaciones en orden %s" % str(GROUPS))
			for a in ex.alertas:
				if not _vocab("vocab_ui.gd", "TOAST_LEVELS").has(str(a.nivel)):
					v.append("alertas[%s].nivel «%s» no es info, aviso ni critica" % [a.id, str(a.nivel)])
			for who in ex.senal.faltan:
				if not GROUPS.has(str(who)):
					v.append("senal.faltan cita «%s», que no es una agrupación" % str(who))
			if not ["desconocido", "en_camino", "visible", "llego"].has(str(ex.refuerzo.estado)):
				v.append("refuerzo.estado «%s» no es desconocido, en_camino, visible ni llego" % str(ex.refuerzo.estado))
			if not [0, 1, 2].has(int(ex.siguiente.urgencia)):
				v.append("siguiente.urgencia debe ser 0, 1 o 2")
			if not GROUPS.has(str(ex.siguiente.actor)) or not _all_actions().has(str(ex.siguiente.action)):
				v.append("siguiente.actor/action no son una agrupación y una acción del vocabulario")
			var g: Dictionary = ex.golpe
			if not is_equal_approx(float(g.entregado) + float(g.destruido) + float(g.oculto) + float(g.pendiente), float(g.total)) or not is_equal_approx(float(g.total), 100.0):
				v.append("golpe: entregado + destruido + oculto + pendiente debe sumar el total (100)")
		"render_state":
			if not phases.has(str(ex.phase)):
				v.append("phase «%s» no es una fase" % str(ex.phase))
			if not ["noche", "alba", "dia"].has(str(ex.env.phase)):
				v.append("env.phase «%s» no es noche, alba ni dia" % str(ex.env.phase))
			for u in ex.units:
				if not GROUPS.has(str(u.id)) or not _vocab("vocab_rules.gd", "STAGES").has(str(u.stage)):
					v.append("units[%s]: id o stage fuera del vocabulario" % str(u.id))
			for o in ex.objectives:
				if not OBJECTIVES.has(str(o.id)) or not front_states.has(str(o.state)):
					v.append("objectives[%s]: id o state fuera del vocabulario" % str(o.id))
			for e in ex.enemies:
				if not ["centinela", "guardia", "artillero", "fusilero", "torre", "mensajero", "refuerzo"].has(str(e.kind)):
					v.append("enemies[%s].kind «%s» fuera de la lista del contrato" % [str(e.id), str(e.kind)])
			for l in ex.loot:
				if not _vocab("vocab_rules.gd", "LOOT_KINDS").has(str(l.kind)) or not _vocab("vocab_rules.gd", "LOOT_STATES").has(str(l.state)):
					v.append("loot[%s]: kind o state fuera del vocabulario" % str(l.id))
			for l in ex.lights:
				if not ["brasero", "ventana", "candil", "fogata"].has(str(l.kind)) or (l.has("objective") and not OBJECTIVES.has(str(l.objective))):
					v.append("lights[%s]: kind u objective fuera del vocabulario" % str(l.id))
		"campaign_report":
			if not _vocab("vocab_rules.gd", "STATUS").has(str(ex.status)):
				v.append("status «%s» fuera de STATUS" % str(ex.status))
			if str(ex.cause_id) != "" and not _vocab("vocab_rules.gd", "CAUSES").has(str(ex.cause_id)):
				v.append("cause_id «%s» no es una causa de derrota" % str(ex.cause_id))
			if String(ex.cause).length() > 140:
				v.append("cause tiene %d caracteres (máximo 140)" % String(ex.cause).length())
			if not _vocab("vocab_rules.gd", "MEDALS").has(str(ex.medal)):
				v.append("medal «%s» fuera de MEDALS" % str(ex.medal))
			for p in ex.pieces:
				if not _vocab("vocab_rules.gd", "TREATMENTS").has(str(p.tratamiento)):
					v.append("pieces[%s].tratamiento fuera de TREATMENTS" % str(p.id))
			var traits: Dictionary = _vocab("vocab_rules.gd", "WORLD_TRAITS")
			for k in ex.loot_traits:
				if not (traits.has(k) and (traits[k] as Array).has(ex.loot_traits[k])):
					v.append("loot_traits.%s = «%s» es un valor ilegal" % [k, str(ex.loot_traits[k])])
			var dims: Dictionary = _vocab("vocab_rules.gd", "VARIANTS")
			for k in ex.variant:
				if not (dims.has(k) and (dims[k] as Array).has(ex.variant[k])):
					v.append("variant.%s = «%s» es un valor ilegal" % [k, str(ex.variant[k])])
			for gr in ex.groups:
				if not GROUPS.has(str(gr.id)) or not TAGS.has(str(gr.tag)):
					v.append("groups[%s]: id o tag fuera del vocabulario" % str(gr.id))
			for e in ex.epilogue:
				if not TAGS.has(str(e.tag)):
					v.append("epilogue: tag «%s» fuera de las 5 etiquetas" % str(e.tag))
		"plan_route":
			if not ["bajo", "medio", "alto", "desconocido"].has(str(ex.risk)):
				v.append("risk «%s» no es bajo, medio, alto ni desconocido" % str(ex.risk))
			if float(ex.seen_risk) < 0.0 or float(ex.seen_risk) > 1.0:
				v.append("seen_risk debe estar en 0..1")
			if ex.path.is_empty():
				v.append("path no puede estar vacío en el ejemplo")
		"qa_state":
			if not phases.has(str(ex.phase)):
				v.append("phase «%s» no es una fase" % str(ex.phase))
			for k in OBJECTIVES:
				if not ex.front_states.has(k) or not front_states.has(str(ex.front_states[k])):
					v.append("front_states.%s falta o no es un estado de frente" % k)
			for s in ex.selected:
				if not GROUPS.has(str(s)):
					v.append("selected cita «%s», que no es una agrupación" % str(s))
	return v

func traza_file_path(file_part: String) -> String:
	if file_part.ends_with(".gd") or file_part.ends_with(".sh") or file_part.ends_with(".py"):
		return "res://" + file_part if file_part.find("/") >= 0 else "res://tools/" + file_part
	if file_part.begins_with("test_hx_") or file_part == "hx_fixtures":
		return "res://tests/" + file_part + ".gd"
	if file_part == "qa_gate":
		return "res://tools/qa_gate.sh"
	return "res://tools/" + file_part + ".gd"

# ---------------------------------------------------------------------------------------------------------------------
# V6, V10 a V12, V14 a V16, V18, V21 y V22 (BACKLOG B-013: se encienden en R1; cada una se prueba contra los datos reales y contra copias rotas a propósito)

## Claves que no son texto de pantalla (ids, etiquetas, atajos, tipos): V10 no las revisa.
const NOT_VISIBLE_KEYS := ["tag", "tag_parts", "source", "id", "shortcut", "target", "round", "who", "kind", "layout", "state", "cause_id", "key", "keys"]
const VARIANT_LAYOUTS := ["A", "B", "AB"]
const GAME_NUMBER_KEYS := ["attack_range_m", "mirador_range_m", "sight_m", "vision_m", "detect_m", "hear_m", "noise_m", "speed_mps", "damage", "dps", "hp"]
const TEXT_LIMITS := {"causa": 140, "briefing_p1": 250, "pista": 120}
const QUALITY_BUDGETS := {"baja": 2.5, "media": 4.0, "alta": 6.0}

func _dict_of(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}

func _array_of(value: Variant) -> Array:
	return value as Array if value is Array else []

func _pt(p: Variant) -> Vector2:
	if p is Dictionary and (p as Dictionary).has("x") and (p as Dictionary).has("z"):
		return Vector2(float(p.x), float(p.z))
	return Vector2(-99999.0, -99999.0)

func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len2 := ab.length_squared()
	if len2 <= 0.000001:
		return p.distance_to(a)
	return p.distance_to(a + ab * clampf((p - a).dot(ab) / len2, 0.0, 1.0))

func _in_poly(p: Vector2, poly: Array) -> bool:
	var inside := false
	var n := poly.size()
	var j := n - 1
	for i in range(n):
		var a := _pt(poly[i])
		var b := _pt(poly[j])
		if (a.y > p.y) != (b.y > p.y) and p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x:
			inside = not inside
		j = i
	return inside

## V6: hitos y rasgos dentro de [0, x] × [0, z] (salvo outside: true); los tres objetivos separados 80 m o más; una tapia no atraviesa un objetivo sin portillo.
func v6_geometry(map_data: Variant, level: Variant) -> Array:
	var v: Array = []
	if not (map_data is Dictionary):
		return v
	var size := _dict_of((map_data as Dictionary).get("size_m", null))
	var w := float(size.get("x", 900.0))
	var d := float(size.get("z", 650.0))
	var centers := {}
	for lm in _array_of((map_data as Dictionary).get("landmarks", null)):
		if not (lm is Dictionary) or bool(lm.get("outside", false)):
			continue
		var p := Vector2(float(lm.get("x", -1.0)), float(lm.get("z", -1.0)))
		if p.x < 0.0 or p.x > w or p.y < 0.0 or p.y > d:
			v.append("V6 humahuaca_map.json: el hito «%s» (%.1f, %.1f) queda fuera de [0, %.0f] × [0, %.0f] y no dice outside: true" % [str(lm.get("id", "?")), p.x, p.y, w, d])
		centers[str(lm.get("id", ""))] = {"p": p, "w": float(_dict_of(lm.get("footprint", null)).get("w", 0.0)), "d": float(_dict_of(lm.get("footprint", null)).get("d", 0.0))}
	for i in range(OBJECTIVES.size()):
		for j in range(i + 1, OBJECTIVES.size()):
			if centers.has(OBJECTIVES[i]) and centers.has(OBJECTIVES[j]):
				var sep: float = (centers[OBJECTIVES[i]].p as Vector2).distance_to(centers[OBJECTIVES[j]].p)
				if sep < 80.0:
					v.append("V6 los objetivos «%s» y «%s» están a %.1f m (mínimo 80 m)" % [OBJECTIVES[i], OBJECTIVES[j], sep])
	if not (level is Dictionary):
		return v
	var features := _dict_of((level as Dictionary).get("features", null))
	for kind in ["tapias", "zanjas", "acequias", "barricadas", "calles", "caminos"]:
		for f in _array_of(features.get(kind, null)):
			if not (f is Dictionary) or bool(f.get("outside", false)):
				continue
			for pt in _array_of(f.get("pts", null)):
				var q := _pt(pt)
				if q.x < -1.0 or q.x > w + 1.0 or q.y < -1.0 or q.y > d + 1.0:
					v.append("V6 humahuaca_level.json features.%s «%s»: el punto (%.1f, %.1f) queda fuera del mapa" % [kind, str(f.get("id", "?")), q.x, q.y])
					break
	var with_gate := {}
	for g in _array_of(features.get("portillos", null)):
		if g is Dictionary:
			with_gate[str(g.get("tapia", ""))] = true
	for t in _array_of(features.get("tapias", null)):
		if not (t is Dictionary) or with_gate.has(str(t.get("id", ""))):
			continue
		var pts := _array_of(t.get("pts", null))
		for obj in OBJECTIVES:
			if not centers.has(obj):
				continue
			var half := minf(float(centers[obj].w), float(centers[obj].d)) * 0.5
			for k in range(pts.size() - 1):
				if _seg_dist(centers[obj].p, _pt(pts[k]), _pt(pts[k + 1])) < half:
					v.append("V6 la tapia «%s» atraviesa el objetivo «%s» y no tiene portillo" % [str(t.get("id", "?")), obj])
					break
	return v

func _fold(text: String) -> String:
	var out := text.to_lower()
	for pair in [["á", "a"], ["é", "e"], ["í", "i"], ["ó", "o"], ["ú", "u"], ["ü", "u"], ["ñ", "n"]]:
		out = out.replace(pair[0], pair[1])
	return out

## Las cadenas que ve el jugador dentro de un subárbol: todas salvo las de las claves de NOT_VISIBLE_KEYS (ids, etiquetas, atajos).
func _visible_strings(node: Variant, path: String, out: Array) -> void:
	if node is Dictionary:
		for key in node:
			if NOT_VISIBLE_KEYS.has(str(key)):
				continue
			_visible_strings(node[key], path + "." + str(key), out)
	elif node is Array:
		var i := 0
		for item in node:
			_visible_strings(item, path + "[%d]" % i, out)
			i += 1
	elif node is String and str(node).strip_edges() != "":
		out.append([path, str(node)])

## V10: la lista negra separa siglas de palabras y ninguna cadena visible de rules.texts, field_events, outcome, actions, ui.texts ni ui.tutorial_steps trae un término
## prohibido, un identificador en snake_case o un texto escrito entero en mayúsculas.
func v10_jargon(rules: Variant, ui: Variant) -> Array:
	var v: Array = []
	if not (ui is Dictionary):
		return v
	var list := _array_of((ui as Dictionary).get("jargon_blacklist", null))
	if list.is_empty():
		return ["V10 humahuaca_ui.json: jargon_blacklist está vacía o no es una lista"]
	var acronyms: Array = []
	var words: Array = []
	for entry in list:
		var s := str(entry).strip_edges()
		if s == "":
			v.append("V10 jargon_blacklist trae una entrada vacía")
		elif s == s.to_upper() and s != s.to_lower():
			acronyms.append(s)
		else:
			words.append(_fold(s))
	if acronyms.is_empty() or words.is_empty():
		v.append("V10 jargon_blacklist tiene que separar las siglas (en mayúsculas) de las palabras: %d siglas y %d palabras" % [acronyms.size(), words.size()])
	var strings: Array = []
	if rules is Dictionary:
		for key in ["texts", "field_events", "outcome", "actions"]:
			_visible_strings((rules as Dictionary).get(key, null), "humahuaca_rules.json " + key, strings)
	for key in ["texts", "tutorial_steps"]:
		_visible_strings((ui as Dictionary).get(key, null), "humahuaca_ui.json " + key, strings)
	var snake := RegEx.new()
	snake.compile("\\b[a-z]+(?:_[a-z0-9]+)+\\b")
	for item in strings:
		var where: String = item[0]
		var text: String = item[1]
		var folded := _fold(text)
		for a in acronyms:
			var rx := RegEx.new()
			rx.compile("\\b" + str(a) + "\\b")
			if rx.search(text) != null:
				v.append("V10 %s: la sigla «%s» está prohibida («%s»)" % [where, str(a), text.left(50)])
		for wd in words:
			var rw := RegEx.new()
			rw.compile("\\b" + str(wd) + "\\b")
			if rw.search(folded) != null:
				v.append("V10 %s: la palabra «%s» está prohibida («%s»)" % [where, str(wd), text.left(50)])
		if snake.search(text) != null:
			v.append("V10 %s: trae un identificador en snake_case («%s»)" % [where, text.left(50)])
		var letters := RegEx.new()
		letters.compile("[A-Za-zÁÉÍÓÚÑáéíóúñ]")
		if letters.search_all(text).size() >= 4 and text == text.to_upper():
			v.append("V10 %s: es un texto entero en mayúsculas («%s»)" % [where, text.left(50)])
	return v

## V11: las causas de derrota (con sus marcadores de lugar y momento expandidos) 140 caracteres o menos, la página 1 del briefing 250 y las pistas de reintento 120.
## `accepted`: {ruta: ronda de vencimiento}, excepciones fechadas que dejan de valer en esa ronda (ADDENDA A-13).
func v11_limits(rules: Variant, round_now: String = "r1", accepted: Dictionary = {}) -> Array:
	var v: Array = []
	if not (rules is Dictionary):
		return v
	var marker := RegEx.new()
	marker.compile("\\{[A-Za-z_]+\\}")
	var causes := _dict_of(_dict_of((rules as Dictionary).get("outcome", null)).get("causes", null))
	for id in causes:
		var text := str(_dict_of(causes[id]).get("texto", ""))
		var expanded := text.replace("{t}", "12:34")
		for m in marker.search_all(expanded):
			expanded = expanded.replace(m.get_string(), "x".repeat(18))
		if expanded.length() > int(TEXT_LIMITS.causa):
			v.append("V11 outcome.causes.%s.texto mide %d caracteres con sus marcadores (máximo %d)" % [str(id), expanded.length(), int(TEXT_LIMITS.causa)])
	var briefing := _dict_of(_dict_of((rules as Dictionary).get("texts", null)).get("briefing", null))
	if str(briefing.get("pagina_1", "")).length() > int(TEXT_LIMITS.briefing_p1):
		v.append("V11 texts.briefing.pagina_1 mide %d caracteres (máximo %d)" % [str(briefing.get("pagina_1", "")).length(), int(TEXT_LIMITS.briefing_p1)])
	var tips := _dict_of(_dict_of((rules as Dictionary).get("campaign", null)).get("tips", null))
	for id in tips:
		var i := 0
		for tip in _array_of(tips[id]):
			var path := "campaign.tips.%s[%d]" % [str(id), i]
			if str(tip).length() > int(TEXT_LIMITS.pista):
				if accepted.has(path) and not Fx.round_ge(round_now, str(accepted[path])):
					i += 1
					continue
				v.append("V11 %s mide %d caracteres (máximo %d)" % [path, str(tip).length(), int(TEXT_LIMITS.pista)])
			i += 1
	return v

## V12: todo `res://` que citan los JSON del nivel existe (y cada .glb de assets/models/humahuaca tiene su .import).
func v12_res_paths(files: Dictionary) -> Array:
	var v: Array = []
	for key in FILES:
		if not (files.get(key) is Dictionary) or key == "height":
			continue
		_walk(files[key], "", func(node, path):
			if not (node is Dictionary):
				return
			for k in node:
				var value: Variant = node[k]
				if value is String and str(value).begins_with("res://"):
					var p := str(value)
					if not (FileAccess.file_exists(p) or DirAccess.dir_exists_absolute(p) or FileAccess.file_exists(p + ".import")):
						v.append("V12 %s%s.%s: «%s» no existe" % [FILES[key], path, str(k), p])
					elif p.ends_with(".glb") and not FileAccess.file_exists(p + ".import"):
						v.append("V12 %s%s.%s: «%s» no tiene su .import (correr --import)" % [FILES[key], path, str(k), p]))
	return v

## V13 (variantes): las dimensiones de rules.variants son las del vocabulario (layout vive en el nivel y no se sortea en las reglas).
func v13_variants_vs_vocab(rules: Variant) -> Array:
	var v: Array = []
	var variants := _dict_of(_dict_of(rules).get("variants", null))
	var dims := _dict_of(variants.get("dimensions", null))
	if dims.is_empty():
		return v  # que la sección exista lo exige V2 (desde r2b)
	var vocab: Dictionary = _vocab("vocab_rules.gd", "VARIANTS")
	for dim in vocab:
		if str(dim) != "layout" and not dims.has(dim):
			v.append("V13 humahuaca_rules.json variants.dimensions: falta la dimensión «%s» del vocabulario" % str(dim))
	for dim in dims:
		if not vocab.has(dim):
			v.append("V13 humahuaca_rules.json variants.dimensions: «%s» no está en VARIANTS (sumarla al vocabulario es legal; usarla sin sumarla, no)" % str(dim))
	return v

## V14: variantes legales: valores del vocabulario, activas dentro de las seis dimensiones, inactivas con un valor fijo legal, layouts A, B o AB.
func v14_variants(rules: Variant, level: Variant, map_data: Variant) -> Array:
	var v: Array = []
	var vocab: Dictionary = _vocab("vocab_rules.gd", "VARIANTS")
	var variants := _dict_of(_dict_of(rules).get("variants", null))
	var dims := _dict_of(variants.get("dimensions", null))
	for dim in dims:
		if not vocab.has(dim):
			continue
		for val in _array_of(_dict_of(dims[dim]).get("values", null)):
			if not (vocab[dim] as Array).has(val):
				v.append("V14 variants.dimensions.%s: el valor «%s» no es legal (%s)" % [str(dim), str(val), str(vocab[dim])])
	var active := _array_of(variants.get("active", null))
	var fixed := _dict_of(variants.get("fixed", null))
	for dim in active:
		if not vocab.has(dim):
			v.append("V14 variants.active: «%s» no es una de las dimensiones %s" % [str(dim), str(vocab.keys())])
	for dim in vocab:
		if not active.has(dim):
			if not fixed.has(dim):
				v.append("V14 variants.fixed: la dimensión inactiva «%s» no tiene valor fijo" % str(dim))
			elif not (vocab[dim] as Array).has(fixed[dim]):
				v.append("V14 variants.fixed.%s = «%s» no es un valor legal (%s)" % [str(dim), str(fixed[dim]), str(vocab[dim])])
	if level is Dictionary:
		for l in _array_of((level as Dictionary).get("layouts", null)):
			if not VARIANT_LAYOUTS.has(str(l)):
				v.append("V14 humahuaca_level.json layouts: «%s» no es A, B ni AB" % str(l))
		var features := _dict_of((level as Dictionary).get("features", null))
		for kind in features:
			for f in _array_of(features[kind]):
				if f is Dictionary and f.has("layout") and not VARIANT_LAYOUTS.has(str(f.layout)):
					v.append("V14 humahuaca_level.json features.%s «%s»: layout «%s» no es A, B ni AB" % [str(kind), str(f.get("id", "?")), str(f.layout)])
	if map_data is Dictionary:
		for lm in _array_of((map_data as Dictionary).get("landmarks", null)):
			var var_of := _dict_of(_dict_of(lm).get("variant", null))
			for dim in var_of:
				if not vocab.has(dim):
					v.append("V14 humahuaca_map.json landmarks «%s»: variant usa «%s», que no es una dimensión" % [str(_dict_of(lm).get("id", "?")), str(dim)])
					continue
				var vals: Variant = var_of[dim]
				for one in (vals if vals is Array else [vals]):
					if not (vocab[dim] as Array).has(one):
						v.append("V14 humahuaca_map.json landmarks «%s»: variant.%s = «%s» no es legal" % [str(_dict_of(lm).get("id", "?")), str(dim), str(one)])
	return v

## V15: las 7 vistas canónicas del vocabulario con sus campos y 5 rasgos a mostrar, y el cuadro inicial.
func v15_views(visual: Variant) -> Array:
	var v: Array = []
	if not (visual is Dictionary):
		return v
	var views := _array_of((visual as Dictionary).get("canonical_views", null))
	var ids: Array = []
	for view in views:
		if not (view is Dictionary):
			v.append("V15 canonical_views trae un elemento que no es un objeto")
			continue
		var id := str(view.get("id", ""))
		ids.append(id)
		var t := _dict_of(view.get("target", null))
		if not (t.has("x") and t.has("z")):
			v.append("V15 canonical_views «%s»: target debe traer x y z" % id)
		for k in ["distance", "pitch_deg", "yaw_deg", "time_of_day", "rain"]:
			if not _type_ok(view.get(k, null), "number"):
				v.append("V15 canonical_views «%s»: falta el número «%s»" % [id, k])
		var show := _array_of(view.get("must_show", null))
		if show.size() != 5:
			v.append("V15 canonical_views «%s»: must_show trae %d rasgos y deben ser 5" % [id, show.size()])
	for want in _vocab("vocab_view.gd", "VIEW_IDS"):
		if not ids.has(want):
			v.append("V15 canonical_views: falta la vista «%s»" % str(want))
	if views.size() != 7:
		v.append("V15 canonical_views trae %d vistas y deben ser 7" % views.size())
	var frame := _dict_of((visual as Dictionary).get("initial_frame", null))
	if not (_dict_of(frame.get("target", null)).has("x") and _type_ok(frame.get("distance", null), "number") and _type_ok(frame.get("pitch_deg", null), "number") and _type_ok(frame.get("yaw_deg", null), "number")):
		v.append("V15 initial_frame: faltan target, distance, pitch_deg o yaw_deg")
	return v

## V16: el reloj ordenado (alba_start < alba_full < day_full < deadline y alba_start < dawn_discovery) y el botín que suma exactamente 100 puntos con clases del vocabulario.
func v16_clock_and_loot(rules: Variant, round_now: String) -> Array:
	var v: Array = []
	var time := _dict_of(_dict_of(rules).get("time", null))
	if not time.is_empty():
		var chain := ["alba_start_s", "alba_full_s", "day_full_s", "deadline_s"]
		for i in range(chain.size() - 1):
			if not (_type_ok(time.get(chain[i], null), "number") and _type_ok(time.get(chain[i + 1], null), "number") and float(time[chain[i]]) < float(time[chain[i + 1]])):
				v.append("V16 time: %s debe ser menor que %s (%s y %s)" % [chain[i], chain[i + 1], str(time.get(chain[i], "falta")), str(time.get(chain[i + 1], "falta"))])
		if not (_type_ok(time.get("dawn_discovery_s", null), "number") and float(time.get("alba_start_s", 0.0)) < float(time.dawn_discovery_s)):
			v.append("V16 time: alba_start_s debe ser menor que dawn_discovery_s")
	var classes := _dict_of(_dict_of(_dict_of(rules).get("loot", null)).get("classes", null))
	if not classes.is_empty():
		var kinds: Array = _vocab("vocab_rules.gd", "LOOT_KINDS")
		var total := 0.0
		for id in classes:
			if not kinds.has(str(id)):
				v.append("V16 loot.classes: «%s» no está en LOOT_KINDS" % str(id))
			total += float(_dict_of(classes[id]).get("points", 0.0))
		if not is_equal_approx(total, 100.0):
			v.append("V16 loot.classes: los puntos suman %s y deben sumar exactamente 100" % str(total))
		var need := 9 if Fx.round_ge(round_now, "r2a") else 5
		if classes.size() < need:
			v.append("V16 loot.classes: hay %d clases y desde %s se exigen %d" % [classes.size(), "r2a" if need == 9 else "r1", need])
	return v

## V18: los créditos del relieve: el aviso de Copernicus si esa es la fuente; «OpenStreetMap» y «ODbL» (y la ODbL en map.provenance) si el río sale de la lámina 03.
func v18_credits(height: Variant, map_data: Variant, credits_text: String) -> Array:
	var v: Array = []
	var meta := _dict_of(_dict_of(height).get("meta", null))
	if str(meta.get("source", "")) == "copernicus_glo30":
		for need in ["produced using Copernicus WorldDEM-30", "no se hace responsable"]:
			if credits_text.find(need) < 0:
				v.append("V18 CREDITOS_RELIEVE.md: con Copernicus como fuente falta «%s»" % need)
	var river := _dict_of(_dict_of(map_data).get("river", null))
	var from_lamina := str(river.get("source", "")).to_lower().find("lámina 03") >= 0 or str(river.get("source", "")).to_lower().find("lamina 03") >= 0
	if from_lamina:
		for need in ["OpenStreetMap", "ODbL"]:
			if credits_text.find(need) < 0:
				v.append("V18 CREDITOS_RELIEVE.md: el río sale de la lámina 03 y falta «%s»" % need)
		if json_text(_dict_of(map_data).get("provenance", null)).find("ODbL") < 0:
			v.append("V18 humahuaca_map.json provenance: el río sale de la lámina 03 y no declara la ODbL")
	return v

func json_text(value: Variant) -> String:
	return JSON.stringify(value)

## V21: una sola fuente por número: cada puesto de ataque a 60–120 m de su objetivo y a attack_range_m o menos, los spawn_* dentro de la zona de partida y ningún número
## de juego (alcances, velocidades, daño) en el mapa ni en el nivel.
func v21_single_source(map_data: Variant, level: Variant, rules: Variant) -> Array:
	var v: Array = []
	var centers := {}
	var zone: Array = []
	var spawns := {}
	for lm in _array_of(_dict_of(map_data).get("landmarks", null)):
		if not (lm is Dictionary):
			continue
		centers[str(lm.get("id", ""))] = Vector2(float(lm.get("x", 0.0)), float(lm.get("z", 0.0)))
		if str(lm.get("id", "")) == "zona_partida":
			zone = _array_of(_dict_of(lm.get("footprint", null)).get("poly", null))
		if str(lm.get("id", "")).begins_with("spawn_"):
			spawns[str(lm.id)] = centers[str(lm.id)]
	var range_m := float(_dict_of(_dict_of(rules).get("combat", null)).get("attack_range_m", 150.0))
	var posts := _dict_of(_dict_of(_dict_of(level).get("access", null)).get("attack_posts", null))
	for obj in posts:
		if not centers.has(obj):
			continue
		var i := 0
		for post in _array_of(posts[obj]):
			var dist: float = (centers[obj] as Vector2).distance_to(_pt(post))
			if dist < 60.0 or dist > 120.0:
				v.append("V21 access.attack_posts.%s[%d] está a %.1f m del objetivo (debe estar entre 60 y 120 m)" % [str(obj), i, dist])
			if dist > range_m:
				v.append("V21 access.attack_posts.%s[%d] está a %.1f m, más allá del alcance de combate (%.0f m)" % [str(obj), i, dist, range_m])
			i += 1
	if not zone.is_empty():
		for id in spawns:
			if not _in_poly(spawns[id], zone):
				v.append("V21 el hito «%s» (%.1f, %.1f) no está dentro de la zona de partida" % [str(id), (spawns[id] as Vector2).x, (spawns[id] as Vector2).y])
	for pair in [["humahuaca_map.json", map_data], ["humahuaca_level.json", level]]:
		_walk(pair[1], "", func(node, path):
			if node is Dictionary:
				for k in node:
					if GAME_NUMBER_KEYS.has(str(k)):
						v.append("V21 %s%s.%s: un número de juego vive en %s (su fuente es humahuaca_rules.json)" % [pair[0], path, str(k), pair[0]]))
	return v

## V22: las vistas canónicas y el cuadro inicial son coherentes con la cámara de la interfaz, juego_noche y juego_alba repiten el cuadro inicial y quality trae los
## tres perfiles con su presupuesto de cuadro (D14: 2,5, 4,0 y 6,0 ms de media y 8,3 ms de p95).
func v22_camera_and_quality(visual: Variant, ui: Variant) -> Array:
	var v: Array = []
	var frame := _dict_of(_dict_of(visual).get("initial_frame", null))
	var cam := _dict_of(_dict_of(ui).get("camera", null))
	if not frame.is_empty() and not cam.is_empty():
		if float(frame.get("distance", 0.0)) < float(cam.get("min_distance_m", 0.0)) or float(frame.get("distance", 0.0)) > float(cam.get("max_distance_m", 99999.0)):
			v.append("V22 initial_frame.distance %.0f m queda fuera de ui.camera [%s, %s]" % [float(frame.get("distance", 0.0)), str(cam.get("min_distance_m")), str(cam.get("max_distance_m"))])
		if float(frame.get("pitch_deg", 0.0)) < float(cam.get("min_pitch_deg", 0.0)) or float(frame.get("pitch_deg", 0.0)) > float(cam.get("max_pitch_deg", 90.0)):
			v.append("V22 initial_frame.pitch_deg %.0f° queda fuera de ui.camera [%s, %s]" % [float(frame.get("pitch_deg", 0.0)), str(cam.get("min_pitch_deg")), str(cam.get("max_pitch_deg"))])
	for view in _array_of(_dict_of(visual).get("canonical_views", null)):
		if not (view is Dictionary):
			continue
		var tod := float(view.get("time_of_day", -1.0))
		if tod < 0.0 or tod > 1.0:
			v.append("V22 canonical_views «%s»: time_of_day %s fuera de 0..1" % [str(view.get("id", "?")), str(view.get("time_of_day"))])
		if str(view.get("id", "")) in ["juego_noche", "juego_alba"]:
			for k in ["distance", "pitch_deg", "yaw_deg"]:
				if not is_equal_approx(float(view.get(k, -1.0)), float(frame.get(k, -2.0))):
					v.append("V22 canonical_views «%s»: %s (%s) no repite el del cuadro inicial (%s)" % [str(view.id), k, str(view.get(k)), str(frame.get(k))])
			if not (is_equal_approx(float(_dict_of(view.get("target", null)).get("x", -1.0)), float(_dict_of(frame.get("target", null)).get("x", -2.0))) and is_equal_approx(float(_dict_of(view.get("target", null)).get("z", -1.0)), float(_dict_of(frame.get("target", null)).get("z", -2.0)))):
				v.append("V22 canonical_views «%s»: target no repite el del cuadro inicial" % str(view.id))
	var quality := _dict_of(_dict_of(visual).get("quality", null))
	for profile in QUALITY_BUDGETS:
		var q := _dict_of(quality.get(profile, null))
		if q.is_empty():
			v.append("V22 visual.quality: falta el perfil «%s»" % str(profile))
			continue
		if not is_equal_approx(float(q.get("frame_ms_mean_max", -1.0)), float(QUALITY_BUDGETS[profile])):
			v.append("V22 visual.quality.%s: frame_ms_mean_max %s y D14 fija %s ms" % [str(profile), str(q.get("frame_ms_mean_max")), str(QUALITY_BUDGETS[profile])])
		if float(q.get("frame_ms_p95_max", 99.0)) > 8.3 + 0.0001:
			v.append("V22 visual.quality.%s: frame_ms_p95_max %s supera 8,3 ms" % [str(profile), str(q.get("frame_ms_p95_max"))])
	return v
