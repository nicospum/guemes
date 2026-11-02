extends SceneTree
## Revisión nube, lente D (navegación y terreno). Prueba que FALLA hoy.
## humahuaca_level.json deja tres puertas en la casa de posta como huecos de 4 m entre tapias: oeste (x=575, z 298–302, entre
## tapia_posta_w2 y w1), sur (z=312, x 588–592, entre s2 y s1) y este (x=605, z 296–304, entre e1 y e2, de 8 m). El rasterizado de
## terrain_raster.gd::_stroke_nodes redondea cada extremo al nodo más cercano (roundi, cada nodo manda en ±2 m): 298/4 = 74,5 → 75 y
## 302/4 = 75,5 → 76 son nodos contiguos, y 588/4 = 147 y 592/4 = 148 también. Las dos puertas de 4 m quedan como «muro» y solo la de
## 8 m del este queda abierta: una ruta desde el oeste a la posta recorre 90 m por 30 m directos.
## Sale con 1 si falla, 0 si pasa. Corrida: godot --headless --path . --script tests/revision_nube/d_puertas_posta.gd


func _initialize() -> void:
	var T = load("res://scripts/humahuaca/terrain/humahuaca_terrain.gd")
	var Nav = load("res://scripts/humahuaca/rules/humahuaca_nav.gd")
	var t = T.load_default()
	var nav = Nav.build(t)
	var failures := 0
	var doors := {"oeste (575,300)": Vector2(575.0, 300.0), "sur (590,312)": Vector2(590.0, 312.0), "este (605,300)": Vector2(605.0, 300.0)}
	for name in doors:
		var p: Vector2 = doors[name]
		var blocked: bool = t.is_blocked(p.x, p.y)
		print("puerta %s: esperaba is_blocked=false (hueco del JSON), obtuve %s (superficie %s, nav solido %s)" % [name, str(blocked), t.surface_at(p.x, p.y), str(nav.blocked_at(p))])
		if blocked:
			failures += 1
	var west: Array = nav.find_path(Vector2(560.0, 300.0), Vector2(590.0, 300.0))
	var south: Array = nav.find_path(Vector2(590.0, 330.0), Vector2(590.0, 300.0))
	var lw: float = Nav.length_of(west)
	var ls: float = Nav.length_of(south)
	print("ruta desde el oeste (560,300) a la posta (590,300): esperaba <= 45 m (30 m directos por la puerta), obtuve %.1f m %s" % [lw, str(west)])
	print("ruta desde el sur (590,330) a la posta (590,300): esperaba <= 45 m (30 m directos por la puerta), obtuve %.1f m %s" % [ls, str(south)])
	if lw > 45.0:
		failures += 1
	if ls > 45.0:
		failures += 1
	# Diagnóstico: en un terreno plano, dos tapias colineales con un hueco de 4 m en cuatro alineaciones distintas: ninguna deja paso.
	var V = load("res://scripts/humahuaca/humahuaca_vocab.gd")
	var wh := []
	wh.resize(91 * 66)
	wh.fill(170)
	var ch := []
	ch.resize(121 * 91)
	ch.fill(170)
	var flat_h := {"meta": {"source": "plano"}, "window": {"nx": 91, "nz": 66, "cell_m": 10.0, "origin_x": 0.0, "origin_z": 0.0, "h": wh}, "context": {"nx": 121, "nz": 91, "cell_m": 30.0, "origin_x": -1350.0, "origin_z": -1025.0, "h": ch}}
	var map: Dictionary = V.load_json(V.MAP_PATH).duplicate(true)
	map.erase("relief")
	for off in [0.0, 1.0, 2.0, 3.0]:
		var z0 := 300.0 + off
		var level := {"features": {"tapias": [
			{"id": "a", "pts": [{"x": 400.0, "z": z0 - 30.0}, {"x": 400.0, "z": z0 - 2.0}], "height_m": 2.0, "layout": "AB"},
			{"id": "b", "pts": [{"x": 400.0, "z": z0 + 2.0}, {"x": 400.0, "z": z0 + 30.0}], "height_m": 2.0, "layout": "AB"}]}}
		var ft = T.from_data(map, flat_h, level)
		var fn = Nav.build(ft)
		var path: Array = fn.find_path(Vector2(390.0, z0), Vector2(410.0, z0))
		print("  plano, hueco de 4 m centrado en z=%.0f: is_blocked(400,z)=%s, ruta de 20 m directos = %.1f m" % [z0, str(ft.is_blocked(400.0, z0)), Nav.length_of(path)])
	print("FALLAS: %d" % failures)
	quit(1 if failures > 0 else 0)
