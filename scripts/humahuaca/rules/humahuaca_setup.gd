extends RefCounted
## Armado del estado inicial de una partida de «humahuaca» (CONTRATO 3.2.1): el mundo, las cinco agrupaciones, los tres frentes y el botín. Dueña: reglas_historia.
## Funciones estáticas y puras: leen los JSON por humahuaca_data.gd y no tocan ninguna partida; humahuaca_rules.gd las llama desde new_game. Vive aparte para que cada
## archivo del nivel quede por debajo de las ~1 500 líneas del contrato. Independencia (V19): solo importa vocabularios y datos.

const V = preload("res://scripts/humahuaca/humahuaca_vocab.gd")
const R = preload("res://scripts/humahuaca/rules/vocab_rules.gd")
const D = preload("res://scripts/humahuaca/rules/humahuaca_data.gd")

static func make_world(base: Dictionary, opts: Dictionary) -> Dictionary:
	var world := {}
	for dim in R.VARIANTS:
		world[dim] = base[dim]
	var override: Variant = opts.get("variant", {})
	if override is Dictionary:
		for dim in override:
			if R.VARIANTS.has(dim) and (R.VARIANTS[dim] as Array).has(override[dim]):
				world[dim] = override[dim]
	var traits: Dictionary = (base.get("loot", {}) as Dictionary).duplicate(true)
	var ot: Variant = opts.get("loot_traits", {})
	if ot is Dictionary:
		for k in ot:
			if R.WORLD_TRAITS.has(k) and (R.WORLD_TRAITS[k] as Array).has(ot[k]):
				traits[k] = ot[k]
	world["loot_traits"] = traits
	world["known"] = []
	world["rumors"] = []
	return world

static func make_units() -> Array:
	var out: Array = []
	for id in V.GROUPS:
		var g: Dictionary = D.rules().groups[id]
		var p := D.hito("spawn_" + id)
		out.append({"id": id, "name": str(g.name), "kind": str(g.kind), "x": p.x, "z": p.y, "yaw_deg": 0.0, "strength": float(g.strength), "fatigue": 0.0,
			"morale": 100.0, "armed": float(g.armed), "men": int(g.men), "mounted": bool(g.mounted), "pace": str(g.pace), "stage": "idle", "order": {}, "path": [],
			"noise": 0.0, "detected": false, "custody": 0, "horses": int(g.horses), "carry_kg": 0.0, "capacity_kg": float(g.capacity_kg), "tag": str(g.tag), "work": {}})
	return out

static func make_objectives() -> Dictionary:
	var out := {}
	for id in V.OBJECTIVES:
		var g := float((D.rules().objectives[id] as Dictionary).garrison)
		out[id] = {"state": "guardado", "toma": 0.0, "garrison": g, "garrison_max": g, "alert": 0.0, "surprise_until": -1.0, "reconocido": 0.0,
			"held_by": "", "custody": 0, "taken_at": -1.0, "supporters": []}
	out.cuartel["tower"] = {"active": false, "armed": false, "volleys_left": int(D.rules().tower.volleys), "next_volley_at": -1.0}
	out.bateria["battery"] = {"facing": str(D.level().features.gola_bateria.lado), "pieces": 3}
	return out

static func make_loot(world: Dictionary) -> Dictionary:
	var items: Array = []
	var traits: Dictionary = world.loot_traits
	for kind in R.LOOT_KINDS_R1:
		if kind == "plata" and not bool(traits.get("plata", true)):
			continue
		var cls: Dictionary = D.rules().loot.classes[kind]
		var total_lots := 0
		for lot in cls.lots:
			total_lots += int(lot.count)
		var n := 0
		for lot in cls.lots:
			for i in range(int(lot.count)):
				n += 1
				var site := D.hito(str(lot.site))
				var qty := int(lot.qty)
				var prefix: String = "pieza" if str(kind) == "canones" else str(kind)
				items.append({"id": "%s_%d" % [prefix, n], "kind": str(kind), "qty": qty, "unit_kg": float(lot.get("unit_kg", cls.unit_kg)),
					"unit_value": float(cls.points) / float(total_lots) / float(qty), "state": "en_sitio", "x": site.x + 3.0 * float(n % 3),
					"z": site.y + 3.0 * float(floori(float(n) / 3.0)), "where": str(cls.where), "front": str(lot.front), "carried_by": "", "spot": "", "safe": false,
					"wet": kind == "polvora" and str(traits.get("polvora", "seca")) == "humeda"})
	var cap: Dictionary = D.rules().loot.capacity
	return {"items": items, "capacity_kg": float(cap.own_mules) * float(cap.kg_per_mule), "load_kg": 0.0, "delivered_value": 0.0, "destroyed_value": 0.0,
		"hidden_value": 0.0, "lost_value": 0.0, "total_value": 100.0}
