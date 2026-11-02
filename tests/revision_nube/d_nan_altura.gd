extends SceneTree
## Revisión nube, lente D (navegación y terreno). Prueba que FALLA hoy (gravedad baja: robustez ante una entrada que el juego normal no produce).
## height_at / height_dem_only / slope_deg_at / normal_at / los con una coordenada NaN producen un error de script «Out of bounds get index»
## en humahuaca_terrain.gd:251 (_ctx_at) y terrain_relief.gd:96 (bilerp): NaN no entra en la ventana (NaN >= 0 es falso), va a _outside,
## clampf(NaN) sigue siendo NaN, int(NaN) da −9223372036854775808 y el índice negativo lee fuera del arreglo. is_blocked, surface_at y
## speed_factor_at con NaN no fallan (devuelven bloqueado / suelo_seco / 0). Como GDScript no atrapa errores de script, la prueba corre un
## proceso hijo con el mismo binario (--hijo) y busca «Out of bounds» en su salida. Sale con 1 si falla, 0 si pasa.


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--hijo"):
		var T = load("res://scripts/humahuaca/terrain/humahuaca_terrain.gd")
		var t = T.load_default()
		print("hijo: height_at(NaN,100)=%s height_at(100,NaN)=%s los(NaN)=%s" % [str(t.height_at(NAN, 100.0)), str(t.height_at(100.0, NAN)), str(t.los(Vector2(NAN, 300.0), Vector2(300.0, 300.0)))])
		quit(0)
		return
	var out := []
	var script_path := ProjectSettings.globalize_path("res://tests/revision_nube/d_nan_altura.gd")
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", script_path, "--", "--hijo"], out, true)
	var text := "\n".join(out)
	var oob := text.count("Out of bounds")
	print("proceso hijo: codigo %d, errores «Out of bounds»: %d (esperaba 0)" % [code, oob])
	for line in text.split("\n"):
		if line.contains("Out of bounds") or line.begins_with("hijo:"):
			print("  ", line.strip_edges())
	quit(1 if oob > 0 or code != 0 else 0)
