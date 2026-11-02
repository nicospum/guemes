extends SceneTree
## Revisión nube, lente D (navegación y terreno). Prueba que FALLA hoy. Dueña del dato: reglas_historia.
## humahuaca_rules.json pone el único centinela de la posta en dx=-14, dz=4 desde el hito (590,300): (576,304). Ese punto cae en el nodo de
## tapia_posta_w1 (x=575, z 302–312): is_blocked = true, superficie «muro». Como la línea de visión (terrain_sight.gd) corta en cualquier
## segmento de tapia que cruce, el centinela «en la entrada» (reveal_text) no ve ninguno de los dos puestos de ataque de su frente
## ((516,340) «directa» y (560,372) «distraccion») ni el oeste ni el sur: a 40 m ve 4 de 36 direcciones, todas hacia adentro del recinto.
## _sentinel_sees() nunca detecta una aproximación a la posta por el lado que el nivel diseña.
## Sale con 1 si falla, 0 si pasa.


func _initialize() -> void:
	var T = load("res://scripts/humahuaca/terrain/humahuaca_terrain.gd")
	var R = load("res://scripts/humahuaca/rules/humahuaca_rules.gd")
	var t = T.load_default()
	var r = R.new()
	r.new_game(3, 1, {})
	var failures := 0
	var posts: Array = r._level.access.attack_posts.posta
	for s in r._sentinel_points("posta"):
		var sv: Vector2 = s
		var blocked: bool = t.is_blocked(sv.x, sv.y)
		print("centinela de la posta en %s: esperaba fuera de un muro, obtuve is_blocked=%s (superficie %s)" % [str(sv), str(blocked), t.surface_at(sv.x, sv.y)])
		if blocked:
			print("  (dato: el nodo del centinela es sólido; es síntoma de D-1 y no cuenta como falla propia)")
		var sees_any := false
		for p in posts:
			var q := Vector2(float(p.x), float(p.z))
			var seen: bool = t.los(sv, q, 1.8, 1.6)
			print("  ve el puesto %s %s a %.0f m: %s" % [str(p.get("approach", "")), str(q), sv.distance_to(q), str(seen)])
			sees_any = sees_any or seen
		if not sees_any:
			print("  esperaba que viera al menos un puesto de ataque de su frente; no ve ninguno")
			failures += 1
	print("FALLAS: %d" % failures)
	quit(1 if failures > 0 else 0)
