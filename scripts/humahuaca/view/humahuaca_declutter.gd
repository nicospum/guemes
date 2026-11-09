extends RefCounted
## visual/r1 F6 (BACKLOG B-049). Dueña: visual. Las agrupaciones que las reglas ponen en el mismo lugar (la columna, el patio de la posta, el pie de un frente) se
## dibujaban una dentro de la otra. SOLO EN LA VISTA, cada par cuyas huellas se pisan se separa a lo largo de la recta que los une (si están encima, en un rumbo fijo por
## par) hasta que los anillos quedan casi tangentes, sin correr ninguna más de `units.declutter.max_m` (humahuaca_visual.json). Es continuo con la posición de las
## reglas (sin saltos) y vale cero si no se pisan: las reglas, el picking por regla y el guardado no cambian. La marca de la interfaz sigue a la figura.

const V = preload("res://scripts/humahuaca/humahuaca_vocab.gd")


## {id: corrimiento en el plano (x, z)} de las agrupaciones de `list` (render_state().units) que tienen nodo en `nodes`; `radius` da el radio del anillo de cada una.
static func spread(list: Array, nodes: Dictionary, radius: Callable, cfg: Dictionary) -> Dictionary:
	var out := {}
	if not bool(cfg.get("enabled", true)):
		return out
	var k_touch := float(cfg.get("touch_k", 0.9))
	var max_m := float(cfg.get("max_m", 14.0))
	var ids: Array = []
	var base: Array = []
	var radii: Array = []
	for u in list:
		if u is Dictionary and nodes.has(str(u.get("id", ""))) and str(u.get("stage", "")) != "exited":
			ids.append(str(u.id))
			base.append(Vector2(float(u.get("x", 0.0)), float(u.get("z", 0.0))))
			radii.append(float(radius.call(str(u.id))))
	var off: Array = []
	off.resize(ids.size())
	off.fill(Vector2.ZERO)
	for _pass in range(int(cfg.get("passes", 4))):
		for i in range(ids.size()):
			for j in range(i + 1, ids.size()):
				var need := (float(radii[i]) + float(radii[j])) * k_touch
				var delta: Vector2 = ((base[j] as Vector2) + (off[j] as Vector2)) - ((base[i] as Vector2) + (off[i] as Vector2))
				var d := delta.length()
				if d >= need:
					continue
				var fixed := Vector2.RIGHT.rotated(TAU * float(V.GROUPS.find(ids[i]) * 5 + V.GROUPS.find(ids[j])) / 7.0)
				var dir := (delta + fixed * need * 0.25).normalized()  # cerca de cero manda el rumbo fijo del par; lejos, la recta que los une
				var push := dir * (need - d) * 0.5
				off[i] = ((off[i] as Vector2) - push).limit_length(max_m)
				off[j] = ((off[j] as Vector2) + push).limit_length(max_m)
	for i in range(ids.size()):
		if (off[i] as Vector2).length() > 0.01:
			out[ids[i]] = off[i]
	return out
