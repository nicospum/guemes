extends SceneTree
## Revisión nube, lente D (navegación y terreno). Prueba que FALLA hoy (gravedad baja).
## En el borde sur (z = 650, dentro del mapa según _in_world y _in_map) el terreno y la grilla de rutas no coinciden: _node_index
## (humahuaca_terrain.gd:829) sujeta la fila a _jmax = 162 (z = 648) y dice «libre», pero humahuaca_nav.gd::cell_of (línea 90) sujeta a
## nz − 1 = 163, la fila de z = 652 que _read_basics marca sólida por estar fuera de la ventana. Así nav.blocked_at((x, 650)) es true,
## find_path a (x, 650) termina en (x, 648) y la unidad para 2 m antes del destino pedido (p. ej. el hito entrada_sur (540, 650)).
## Sale con 1 si falla, 0 si pasa.


func _initialize() -> void:
	var T = load("res://scripts/humahuaca/terrain/humahuaca_terrain.gd")
	var Nav = load("res://scripts/humahuaca/rules/humahuaca_nav.gd")
	var t = T.load_default()
	var nav = Nav.build(t)
	var failures := 0
	for p in [Vector2(540.0, 650.0), Vector2(100.0, 650.0), Vector2(900.0, 650.0), Vector2(900.0, 300.0), Vector2(0.0, 0.0)]:
		var tb: bool = t.is_blocked(p.x, p.y)
		var nb: bool = nav.blocked_at(p)
		print("%s: terrain.is_blocked=%s nav.blocked_at=%s (celda %s)" % [str(p), str(tb), str(nb), str(nav.cell_of(p))])
		if tb != nb:
			failures += 1
	var path: Array = nav.find_path(Vector2(540.0, 600.0), Vector2(540.0, 650.0))
	var fin: Vector2 = path[path.size() - 1] if not path.is_empty() else Vector2(NAN, NAN)
	print("find_path (540,600) -> (540,650): esperaba terminar en (540, 650), obtuve %s" % str(fin))
	if fin.distance_to(Vector2(540.0, 650.0)) > 0.01:
		failures += 1
	print("FALLAS: %d" % failures)
	quit(1 if failures > 0 else 0)
