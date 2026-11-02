extends SceneTree
## Pruebas de la capa de terreno del nivel «humahuaca» (CONTRATO 3.1 y 5.1; TRAZA TR-011 a TR-020, adelantos de TR-021 y TR-022). Dueña: relieve_mapa.
## Sin ventana ni escritura: godot --headless --path . --script tests/test_hx_terrain.gd [-- --ronda=r1 --impl=real|stub]
##
## Prueba la clase REAL (terrain/humahuaca_terrain.gd) y, para los contratos que consume la vista (VP-03 y VP-04), también el stub congelado
## (stubs/stub_terrain.gd). Lo que mide son las alturas y consecuencias del CONTRATO, no el contenido de los JSON: los hitos y los rasgos se leen del
## terreno; los 41 puntos de la lámina 03 se leen de `map.relief.lamina_points` (la misma tabla que usa el builder y el QA, anexo A1 de QA_NIVEL2.md).
## Cada función `_test_*` que cita una fila de docs/humahuaca/TRAZA.md lleva ese nombre exacto: V20 lo verifica.
## Piso de comprobaciones: 60 (r1) y 80 (r2a en adelante); lo aplica tools/qa_gate.sh. Tiempo objetivo: < 20 s.

const Fx = preload("res://tests/hx_fixtures.gd")
const V = preload("res://scripts/humahuaca/humahuaca_vocab.gd")
const VT = preload("res://scripts/humahuaca/terrain/vocab_terrain.gd")
const FLOOR_BY_ROUND := {"r0": 60, "r1.0": 60, "r1": 60, "r2a": 80, "r2b": 80, "r3": 80, "r4": 80}
const SOURCES := ["lamina03_reconstruida", "copernicus_glo30", "opentopodata_srtm30", "paquete_usuario"]
const DESIGN_R1 := ["cerro_bateria", "plataforma_bateria", "quebradita_norte", "quebradita_sur", "cauce_rio"]

var suite := Fx.new()
var real_script: Script = null
var stub_script: Script = null
var terrain: RefCounted = null  # la clase real (o el stub con --impl=stub)
var stub: RefCounted = null
var map: Dictionary = {}
var level: Dictionary = {}
var height: Dictionary = {}
var impl := "real"
var lamina_tol_m := 10.0  # ±10 m con la lámina (plan B), ±3 m con un DEM real (plan A)


func _initialize() -> void:
	suite.begin("hx_terrain", OS.get_cmdline_user_args())
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--impl="):
			impl = str(arg).trim_prefix("--impl=")
	map = V.load_json(V.MAP_PATH)
	level = V.load_json(V.LEVEL_PATH)
	height = V.load_json(V.HEIGHT_PATH)
	real_script = Fx.load_script(Fx.REAL_PATHS.terrain)
	stub_script = Fx.load_script(Fx.STUB_PATHS.terrain)
	stub = Fx.terrain_stub()
	suite.check(stub != null, "el stub del terreno carga (stubs/stub_terrain.gd)")
	if impl == "stub":
		terrain = stub
	elif real_script != null:
		terrain = real_script.call("load_default")
	if terrain == null:
		suite.check(false, "la clase real de terreno (terrain/humahuaca_terrain.gd) carga y load_default() la arma: sin ella no hay nada que probar")
		_finish()
		return
	if str(terrain.report().get("source", "")) != "lamina03_reconstruida":
		lamina_tol_m = 3.0
	_test_api_conformance()
	_test_data_files()
	_test_single_height_source()
	_test_lamina03_points()
	_test_reference_heights()
	_test_battery_prominence()
	_test_window_context_continuity()
	_test_connectivity()
	_test_los()
	_test_gradient_and_contour()
	_test_river_and_surfaces()
	_test_micro_and_layers()
	_test_footprint_convention()
	_test_vp04_contracts()
	_test_relief_consequences()
	_test_source_ab()
	_test_bake_budget()
	_test_report_labels()
	_finish()


func _finish() -> void:
	suite.extra["impl"] = impl
	suite.extra["fuente"] = str(terrain.report().get("source", "?")) if terrain != null else "?"
	if terrain != null:
		var rep: Dictionary = terrain.report()
		suite.extra["metricas"] = {"bake_ms": rep.get("bake_ms", 0.0), "bake_stages_ms": rep.get("bake_stages_ms", {}),
			"prominence_bateria_m": rep.get("prominence_bateria_m", 0.0), "slope_cells_pct_ge8": rep.get("slope_cells_pct_ge8", 0.0),
			"lamina_check": rep.get("lamina_check", {}), "h_min": rep.get("h_min", 0.0), "h_max": rep.get("h_max", 0.0)}
	suite.require_floor(int(FLOOR_BY_ROUND.get(suite.round_id, 60)))
	suite.finish(self)


# ---------------------------------------------------------------------------------------------------------------------
# Utilidades

func _h(x: float, z: float) -> float:
	return float(terrain.height_at(x, z))


func _lm_pos(id: String) -> Vector2:
	var lm: Dictionary = terrain.landmark(id)
	return Vector2(float(lm.get("x", 0.0)), float(lm.get("z", 0.0)))


## Las celdas libres de la malla de rutas conectadas entre sí (8 vecinos, como el QA): arreglo de etiquetas por nodo (0 = sólido).
func _components(nav: Dictionary) -> PackedInt32Array:
	var nx := int(nav["nx"])
	var nz := int(nav["nz"])
	var solid: PackedByteArray = nav["solid"]
	var label := PackedInt32Array()
	label.resize(nx * nz)
	var current := 0
	for start in range(nx * nz):
		if solid[start] == 1 or label[start] != 0:
			continue
		current += 1
		var stack := PackedInt32Array([start])
		label[start] = current
		while not stack.is_empty():
			var k: int = stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			var i := k % nx
			var j := k / nx
			for dj in [-1, 0, 1]:
				for di in [-1, 0, 1]:
					var ii: int = i + di
					var jj: int = j + dj
					if (di == 0 and dj == 0) or ii < 0 or jj < 0 or ii >= nx or jj >= nz:
						continue
					var q := jj * nx + ii
					if solid[q] == 0 and label[q] == 0:
						label[q] = current
						stack.append(q)
	return label


## El componente de la celda libre más cercana a ≤ 3 celdas del punto (la búsqueda del QA, R06); 0 si no hay.
func _component_near(labels: PackedInt32Array, nav: Dictionary, p: Vector2) -> int:
	var nx := int(nav["nx"])
	var nz := int(nav["nz"])
	var cell := float(nav["cell"])
	var i0 := int(p.x / cell)
	var j0 := int(p.y / cell)
	for rad in range(4):
		for dj in range(-rad, rad + 1):
			for di in range(-rad, rad + 1):
				var jj := clampi(j0 + dj, 0, nz - 1)
				var ii := clampi(i0 + di, 0, nx - 1)
				if labels[jj * nx + ii] > 0:
					return labels[jj * nx + ii]
	return 0


func _sha(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode()


func _flat_terrain(extra_level: Dictionary = {}, extra_landmarks: Array = []) -> RefCounted:
	var m: Dictionary = map.duplicate(true)
	var rel: Dictionary = m.get("relief", {})
	rel["design_layers"] = []
	rel["micro"] = {}
	m["relief"] = rel
	m["surfaces"] = {"classes": VT.SURFACES, "layers": [], "mud": {}, "slope_penalty": {"start_deg": 8.0, "per_deg": 0.03, "floor": 0.6}}
	m["river"] = {}
	var lms: Array = []
	for lm in extra_landmarks:
		lms.append(lm)
	m["landmarks"] = lms
	var flat := {"contract": 1, "map_version": 1, "meta": {"source": "lamina03_reconstruida", "tag": "diseno", "uncertainty_m": 10.0, "smooth_m": 0.0, "datum_asl_m": 2940.0},
		"window": {"nx": 91, "nz": 66, "cell_m": 10.0, "origin_x": 0.0, "origin_z": 0.0, "h": _filled(91 * 66, 170)},
		"context": {"nx": 121, "nz": 91, "cell_m": 30.0, "origin_x": -1350.0, "origin_z": -1025.0, "h": _filled(121 * 91, 170)}}
	return real_script.call("from_data", m, flat, extra_level)


func _filled(n: int, v: int) -> Array:
	var a: Array = []
	a.resize(n)
	a.fill(v)
	return a


# ---------------------------------------------------------------------------------------------------------------------
# API y datos

func _test_api_conformance() -> void:
	if real_script != null:
		var missing: Array = Fx.api_missing(real_script, "terrain")
		suite.check(missing.is_empty(), "la clase real trae los 25 métodos y las 6 propiedades de Fx.API.terrain (falta: %s)" % str(missing))
	if stub_script != null:
		suite.check(Fx.api_missing(stub_script, "terrain").is_empty(), "el stub del terreno trae toda la API (queda congelado desde R1.0)")
	suite.check(terrain.size_m == Vector2(900.0, 650.0) and is_equal_approx(float(terrain.cell_m), 4.0) and int(terrain.nx) == 226 and int(terrain.nz) == 164,
		"ventana de 900 × 650 m con malla de 4 m: 226 × 164 nodos")
	suite.check(is_equal_approx(float(terrain.datum_asl_m), 2940.0) and terrain.anchor == Vector2(450.0, 325.0), "cero local de 2 940 m y ancla en (450, 325)")
	var conv_ok := true
	for p: Vector2 in [Vector2(0, 0), Vector2(-450, 325), Vector2(450, -325), Vector2(1800, 1350)]:
		var g: Vector2 = terrain.lamina_to_game(p.x, p.y)
		var back: Vector2 = terrain.game_to_lamina(g)
		conv_ok = conv_ok and is_equal_approx(g.x, p.x + 450.0) and is_equal_approx(g.y, 325.0 - p.y) and back.is_equal_approx(p)
	suite.check(conv_ok, "x = E + 450 y z = 325 − N, con la inversa exacta")


func _test_data_files() -> void:
	var meta: Dictionary = height.get("meta", {})
	suite.check(SOURCES.has(str(meta.get("source", ""))), "meta.source está en la lista del contrato (%s)" % str(meta.get("source", "")))
	suite.check(str(meta.get("tag", "")) == "razonado" and float(meta.get("uncertainty_m", 0.0)) in [5.0, 10.0], "el relieve es dato actual rotulado «razonado», ±10 m (lámina) o ±5 m (DEM)")
	suite.check(is_equal_approx(float(meta.get("datum_asl_m", 0.0)), float(map.get("datum_asl_m", -1.0))), "el cero local del relieve es el del mapa")
	var win: Dictionary = height.get("window", {})
	var ctx: Dictionary = height.get("context", {})
	suite.check(int((win.get("h", []) as Array).size()) == 91 * 66 and int((ctx.get("h", []) as Array).size()) == 121 * 91, "ventana de 91 × 66 y contexto de 121 × 91 nodos")
	var stats: Dictionary = height.get("stats", {})
	var wh: Array = win.get("h", [])
	var lo := 1.0e9
	var hi := -1.0e9
	for v in wh:
		lo = minf(lo, float(v))
		hi = maxf(hi, float(v))
	suite.check(is_equal_approx(float((stats.get("window", {}) as Dictionary).get("min", 1.0e9)), lo) and is_equal_approx(float((stats.get("window", {}) as Dictionary).get("max", -1.0e9)), hi),
		"stats.window dice el mínimo y el máximo reales de la grilla (%d y %d dm)" % [int(lo), int(hi)])
	var ints_ok := true
	for v in wh:
		ints_ok = ints_ok and is_equal_approx(float(v), roundf(float(v)))
	suite.check(ints_ok, "los valores de la ventana son decímetros enteros")
	# el borde de la ventana vale el contexto interpolado (V7 pide ≤ 1 dm; el builder lo deja en ≤ 0,5 dm)
	var worst := 0.0
	var ch: Array = ctx.get("h", [])
	for j in range(66):
		for i in range(91):
			if i != 0 and i != 90 and j != 0 and j != 65:
				continue
			var fx := (float(i) * 10.0 + 1350.0) / 30.0
			var fz := (float(j) * 10.0 + 1025.0) / 30.0
			var i0 := mini(int(fx), 119)
			var j0 := mini(int(fz), 89)
			var tx := fx - float(i0)
			var tz := fz - float(j0)
			var a := float(ch[j0 * 121 + i0])
			var b := float(ch[j0 * 121 + i0 + 1])
			var c := float(ch[(j0 + 1) * 121 + i0])
			var d := float(ch[(j0 + 1) * 121 + i0 + 1])
			worst = maxf(worst, absf(float(wh[j * 91 + i]) - lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)))
	suite.check(worst <= 1.0, "los nodos del borde de la ventana igualan al contexto a 1 dm o menos (peor: %.2f dm)" % worst)
	var anchor_d: Dictionary = map.get("anchor", {})
	suite.check(str(anchor_d.get("id", "")) == "ancla_iglesia" and str(anchor_d.get("tag", "")) == "razonado", "A-10: el ancla del mapa se llama ancla_iglesia (el hito «templo» es otra cosa)")
	suite.check(str(terrain.landmark("templo").get("tag", "")) == "sin_datos", "el hito «templo» (el edificio de 1817) queda «sin_datos»")


# ---------------------------------------------------------------------------------------------------------------------
# TR-011 · una sola altura

func _test_single_height_source() -> void:
	var hf: Dictionary = terrain.heightfield()
	var gh: PackedFloat32Array = hf["h"]
	var nx := int(hf["nx"])
	var nz := int(hf["nz"])
	suite.check(nx == 226 and nz == 164 and gh.size() == nx * nz and is_equal_approx(float(hf["cell"]), 4.0), "heightfield(): 226 × 164 nodos de 4 m con su arreglo de alturas")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var worst_node := 0.0
	for _n in range(300):
		var i := rng.randi_range(0, 224)
		var j := rng.randi_range(0, 161)
		worst_node = maxf(worst_node, absf(float(gh[j * nx + i]) - _h(float(i) * 4.0, float(j) * 4.0)))
	suite.check(worst_node < 0.001, "height_at coincide con la malla que dibuja la vista en los nodos (peor: %.5f m)" % worst_node)
	var worst_bi := 0.0
	for _n in range(300):
		var x := rng.randf_range(0.0, 900.0)
		var z := rng.randf_range(0.0, 648.0)
		var fx := x / 4.0
		var fz := z / 4.0
		var i := mini(int(fx), nx - 2)
		var j := mini(int(fz), nz - 2)
		var tx := fx - float(i)
		var tz := fz - float(j)
		var by_hand := lerpf(lerpf(gh[j * nx + i], gh[j * nx + i + 1], tx), lerpf(gh[(j + 1) * nx + i], gh[(j + 1) * nx + i + 1], tx), tz)
		worst_bi = maxf(worst_bi, absf(by_hand - _h(x, z)))
	suite.check(worst_bi < 0.001, "entre nodos, height_at es la bilineal de esa misma malla (peor: %.5f m): el picking y las rutas leen lo mismo que se dibuja" % worst_bi)
	var cf: Dictionary = terrain.context_field()
	suite.check(int(cf["nx"]) == 121 and int(cf["nz"]) == 91 and is_equal_approx(float(cf["cell"]), 30.0) and is_equal_approx(float(cf["origin_x"]), -1350.0)
		and is_equal_approx(float(cf["origin_z"]), -1025.0), "context_field(): 121 × 91 nodos de 30 m con origen en (−1350, −1025)")
	var far_ok := true
	for p: Vector2 in [Vector2(-900, 100), Vector2(1700, 900), Vector2(300, -700), Vector2(1200, 1500)]:
		var fx := (p.x + 1350.0) / 30.0
		var fz := (p.y + 1025.0) / 30.0
		var i0 := mini(int(fx), 119)
		var j0 := mini(int(fz), 89)
		var cg: PackedFloat32Array = cf["h"]
		var tx := fx - float(i0)
		var tz := fz - float(j0)
		var by_hand := lerpf(lerpf(cg[j0 * 121 + i0], cg[j0 * 121 + i0 + 1], tx), lerpf(cg[(j0 + 1) * 121 + i0], cg[(j0 + 1) * 121 + i0 + 1], tx), tz)
		far_ok = far_ok and absf(by_hand - _h(p.x, p.y)) < 0.001
	suite.check(far_ok, "más allá de los 60 m exteriores height_at es la bilineal del contexto, sin otra interpolación")
	suite.check(absf(_h(700.0, 500.0) - float(terrain.height_dem_only(700.0, 500.0))) <= 0.5001, "height_dem_only difiere de height_at solo por las capas de diseño y el micro-relieve (≤ 0,5 m donde no hay capas)")
	suite.check(absf(_h(318.0, 350.0) - float(terrain.height_dem_only(318.0, 350.0))) > 5.0, "en la batería, height_at suma el domo y la plataforma a height_dem_only (diseño)")
	var other: RefCounted = real_script.new() if impl == "real" else terrain
	suite.check(_sha((other.heightfield()["h"] as PackedFloat32Array).to_byte_array()) == _sha(gh.to_byte_array()), "el horneado es determinista: dos terrenos dan la misma malla bit a bit")
	suite.check(real_script == null or real_script.call("load_default") == terrain, "load_default() devuelve siempre la misma instancia (caché por proceso)")
	# nadie más interpola la grilla: las capas de reglas, interfaz y los stubs ajenos no la leen
	var offenders: Array = []
	var viewers: Array = []
	for path in Fx.list_files("res://scripts/humahuaca", "gd"):
		var p := str(path)
		if p.contains("/terrain/") or p.ends_with("stub_terrain.gd"):
			continue
		var src: String = Fx.read_text(p)
		if src.contains(".heightfield(") or src.contains(".context_field("):
			if p.contains("/view/") or p.ends_with("stub_view.gd"):
				viewers.append(p)
			else:
				offenders.append(p)
	suite.check(offenders.is_empty(), "solo la vista lee las mallas crudas del terreno; reglas, interfaz y controlador usan height_at (%s)" % str(offenders))
	var view_ok := true
	for p in viewers:
		view_ok = view_ok and Fx.read_text(str(p)).contains("height_at")
	suite.check(view_ok, "la vista que lee la malla también consulta height_at (picking y anclaje)")
	# continuidad: dos puntos a 5 cm difieren muy poco, en todo el plano
	var cont_ok := true
	for _n in range(400):
		var x := rng.randf_range(-100.0, 1000.0)
		var z := rng.randf_range(-100.0, 750.0)
		cont_ok = cont_ok and absf(_h(x, z) - _h(x + 0.05, z + 0.05)) < 0.06
	suite.check(cont_ok, "height_at es continua: dos puntos a 7 cm difieren menos de 6 cm, adentro y afuera de la ventana")


# ---------------------------------------------------------------------------------------------------------------------
# TR-012 · los 41 puntos de la lámina 03

func _test_lamina03_points() -> void:
	var pts: Array = (map.get("relief", {}) as Dictionary).get("lamina_points", [])
	suite.check(pts.size() == 41, "el mapa trae los 41 puntos de la lámina 03 (tabla d.7 del dossier)")
	var ok12 := 0
	var worst := 0.0
	var all_in_band := true
	var datum := float(terrain.datum_asl_m)
	for p in pts:
		var g: Vector2 = terrain.lamina_to_game(float(p["E"]), float(p["N"]))
		var v := float(terrain.height_dem_only(g.x, g.y)) + datum
		var err := absf(v - float(p["est_m"]))
		worst = maxf(worst, err)
		if err <= 12.0:
			ok12 += 1
		var lo: Variant = p.get("banda_min_m", null)
		var hi: Variant = p.get("banda_max_m", null)
		if (lo != null and v < float(lo) - 8.0) or (hi != null and v > float(hi) + 8.0):
			all_in_band = false
	suite.check(ok12 >= 37, "al menos 37 de los 41 puntos a 12 m o menos de la estimación de la lámina (%d de 41)" % ok12)
	suite.check(worst <= 20.0, "ningún punto a más de 20 m de la estimación (peor: %.2f m)" % worst)
	suite.check(all_in_band, "los 41 puntos caen dentro de su banda de color ±8 m")
	var rep: Dictionary = terrain.report()
	var lc: Dictionary = rep.get("lamina_check", {})
	suite.check(int(lc.get("n", 0)) == 41 and int(lc.get("ok", 0)) == ok12 and absf(float(lc.get("max_err_m", -1.0)) - worst) < 0.02,
		"report().lamina_check cuenta lo mismo que esta prueba (n = 41, ok = %d)" % ok12)
	# curvas de 20 m: la banda del ancla y de las esquinas de la ventana (acuerdo con la lámina)
	var band_ok := true
	for q in [[0, 0, 2940, 2960], [-450, 325, 2960, 2980], [450, 325, 2940, 2960], [-450, -325, 2960, 2980], [450, -325, 2940, 2960]]:
		var g: Vector2 = terrain.lamina_to_game(float(q[0]), float(q[1]))
		var v := float(terrain.height_dem_only(g.x, g.y)) + datum
		band_ok = band_ok and v >= float(q[2]) and v < float(q[3])
	suite.check(band_ok, "el ancla y las cuatro esquinas de la ventana caen en la banda de color de la lámina (curvas de 20 m)")


# ---------------------------------------------------------------------------------------------------------------------
# TR-013 · alturas de referencia

func _test_reference_heights() -> void:
	var templo := _h(450.0, 325.0)
	var cauce := _h(859.0, 325.0)
	var partida := _h(70.0, 470.0)
	suite.check(absf(templo - 17.0) <= lamina_tol_m, "el templo está a +17 m (± %s m): %.2f m" % [lamina_tol_m, templo])
	suite.check(absf(cauce - 12.0) <= lamina_tol_m, "el cauce en z = 325 (x = 859) está a +12 m (± %s m): %.2f m" % [lamina_tol_m, cauce])
	suite.check(absf(partida - 27.0) <= lamina_tol_m, "la zona de partida (70, 470) está a +27 m (± %s m): %.2f m" % [lamina_tol_m, partida])
	suite.check(cauce < templo - 3.0, "el cauce queda más bajo que el núcleo (templo %.1f m, cauce %.1f m)" % [templo, cauce])
	var bat := _lm_pos("bateria")
	var plaza := _lm_pos("plaza")
	var over := _h(bat.x, bat.y) - _h(plaza.x, plaza.y)
	suite.check(over >= 14.0 and over <= 19.0, "la batería queda entre 14 y 19 m sobre la plaza: %.2f m" % over)
	suite.check(_h(bat.x, bat.y) > _h(_lm_pos("cuartel").x, _lm_pos("cuartel").y) + 6.0 and _h(bat.x, bat.y) > _h(_lm_pos("posta").x, _lm_pos("posta").y) + 6.0,
		"la batería domina al cuartel y a la posta por más de 6 m (ventaja de tiro del diseño)")
	suite.check(float(terrain.elevation_advantage(bat, plaza)) > 14.0 and is_equal_approx(float(terrain.elevation_advantage(plaza, bat)), -float(terrain.elevation_advantage(bat, plaza))),
		"elevation_advantage(a, b) = altura(a) − altura(b), antisimétrica")
	var asl := float(terrain.asl_at(450.0, 325.0))
	suite.check(absf(asl - (templo + 2940.0)) < 0.001, "asl_at = height_at + el cero local de 2 940 m (templo: %.1f m s. n. m.)" % asl)


# ---------------------------------------------------------------------------------------------------------------------
# TR-014 · prominencia de la batería

func _test_battery_prominence() -> void:
	var dome: Dictionary = {}
	for l in (map.get("relief", {}) as Dictionary).get("design_layers", []):
		if str((l as Dictionary).get("id", "")) == "cerro_bateria":
			dome = l
	var c := Vector2(float((dome.get("center", {}) as Dictionary).get("x", 305.0)), float((dome.get("center", {}) as Dictionary).get("z", 345.0)))
	var bat := _lm_pos("bateria")
	var ring := 0.0
	for k in range(16):  # los 16 puntos del QA (R05): anillo de 135 m alrededor de (305, 345)
		var a := TAU * float(k) / 16.0
		ring += _h(c.x + 135.0 * cos(a), c.y + 135.0 * sin(a))
	ring /= 16.0
	var prom := _h(bat.x, bat.y) - ring
	suite.check(absf(prom - 12.0) <= 0.5, "prominencia de la batería = 12,0 ± 0,5 m sobre la media de su anillo de 16 puntos (%.3f m)" % prom)
	var fine := 0.0
	var n := 0
	for k in range(72):
		for r in [120.0, 125.0, 130.0, 135.0, 140.0, 145.0, 150.0]:
			var a := TAU * float(k) / 72.0
			fine += _h(c.x + r * cos(a), c.y + r * sin(a))
			n += 1
	var prom_fine := _h(bat.x, bat.y) - fine / float(n)
	suite.check(absf(prom_fine - 12.0) <= 0.75, "la prominencia sobre el anillo completo de 120 a 150 m también ronda los 12 m (%.2f m)" % prom_fine)
	suite.check(absf(float(terrain.report().get("prominence_bateria_m", 0.0)) - prom) < 0.01, "report().prominence_bateria_m dice lo mismo que esta prueba")
	# el domo es un residuo y se apaga antes de los 120 m: ahí solo queda el micro-relieve
	var off_ok := true
	for k in range(24):
		var a := TAU * float(k) / 24.0
		var p := c + Vector2(cos(a), sin(a)) * 125.0
		off_ok = off_ok and absf(_h(p.x, p.y) - float(terrain.height_dem_only(p.x, p.y))) <= 0.51
	suite.check(off_ok, "a 125 m del centro del domo la altura final difiere del DEM solo por el micro-relieve (el domo está apagado)")
	var delta_run := float(terrain.report().get("dome_delta_m", 0.0)) if impl == "real" else 0.0
	suite.check(impl != "real" or absf(delta_run - float(dome.get("delta_m", -99.0))) <= 0.1,
		"el delta_m del mapa (%.2f m, lo calcula el builder) coincide con el que resuelve la clase al cargar (%.2f m)" % [float(dome.get("delta_m", 0.0)), delta_run])
	suite.check(str(dome.get("kind", "")) == "dome" and str(dome.get("tag", "")) == "diseno" and is_equal_approx(float(dome.get("prominence_target_m", 0.0)), 12.0),
		"cerro_bateria es una capa «dome» de diseño con prominence_target_m = 12")
	# la plataforma es llana: 28 × 18 m a una sola cota
	var level_ok := true
	var base := _h(bat.x, bat.y)
	for q: Vector2 in [Vector2(-10, -5), Vector2(10, 5), Vector2(-10, 5), Vector2(10, -5), Vector2(0, 0), Vector2(6, -3)]:
		level_ok = level_ok and absf(_h(bat.x + q.x, bat.y + q.y) - base) < 0.001
	suite.check(level_ok, "la plataforma de la batería (28 × 18 m) es llana: seis puntos a la misma cota (%.2f m)" % base)
	suite.check(_h(bat.x + 40.0, bat.y) < base - 4.0, "el domo baja hacia el este: a 40 m de la batería el terreno está más de 4 m más abajo")


# ---------------------------------------------------------------------------------------------------------------------
# TR-015 · continuidad ventana–contexto

func _test_window_context_continuity() -> void:
	var edges: Array = []
	for k in range(101):  # el mismo barrido que hace el QA (R06): los cuatro bordes, a ±0,25 m
		var u := float(k) / 100.0
		for q in [[0.25, 650.0 * u, -0.25, 650.0 * u], [899.75, 650.0 * u, 900.25, 650.0 * u], [900.0 * u, 0.25, 900.0 * u, -0.25], [900.0 * u, 649.75, 900.0 * u, 650.25]]:
			edges.append(absf(_h(q[0], q[1]) - _h(q[2], q[3])))
	var worst_jump := 0.0
	for e in edges:
		worst_jump = maxf(worst_jump, float(e))
	suite.check(worst_jump <= 0.10, "salto de altura en el borde de la ventana ≤ 0,10 m a ±0,25 m (peor: %.3f m)" % worst_jump)
	# sin acantilados en la franja de mezcla: a 1 m de paso la altura cambia menos de 0,5 m (≈ 27°)
	var smooth_ok := true
	var worst_step := 0.0
	for line in [[Vector2(-120.0, 200.0), Vector2(120.0, 200.0), 0], [Vector2(780.0, 300.0), Vector2(1020.0, 300.0), 0], [Vector2(450.0, -120.0), Vector2(450.0, 120.0), 1],
			[Vector2(300.0, 530.0), Vector2(300.0, 770.0), 1], [Vector2(690.0, -60.0), Vector2(690.0, 60.0), 1], [Vector2(840.0, 380.0), Vector2(960.0, 380.0), 0]]:
		var a: Vector2 = line[0]
		var b: Vector2 = line[1]
		var steps := int(a.distance_to(b))
		var prev := _h(a.x, a.y)
		for s in range(1, steps + 1):
			var p := a.lerp(b, float(s) / float(steps))
			var cur := _h(p.x, p.y)
			worst_step = maxf(worst_step, absf(cur - prev))
			prev = cur
	smooth_ok = worst_step < 0.5
	suite.check(smooth_ok, "cruzando el borde por seis líneas (con el río adentro) la altura cambia menos de 0,5 m por metro (peor: %.3f m)" % worst_step)
	# VP-04: continua y finita hasta las esquinas de lo que pide la vista
	var corners_ok := true
	for p: Vector2 in [Vector2(-1350, -1050), Vector2(2250, -1050), Vector2(-1350, 1700), Vector2(2250, 1700), Vector2(450, 325), Vector2(-3000, 3000)]:
		var v := _h(p.x, p.y)
		corners_ok = corners_ok and is_finite(v) and v > -30.0 and v < 400.0
	suite.check(corners_ok, "height_at responde con valores finitos y razonables hasta x ∈ [−1350, 2250], z ∈ [−1050, 1700] y más allá (VP-04)")
	var clamp_ok := absf(_h(2250.0, 1000.0) - _h(2600.0, 1000.0)) < 0.001 and absf(_h(100.0, 1700.0) - _h(100.0, 2300.0)) < 0.001
	suite.check(clamp_ok, "pasado el contexto la lectura se sujeta al borde (no hay un hueco ni un salto)")
	var mid_ok := true
	for p: Vector2 in [Vector2(910, 300), Vector2(930, 300), Vector2(960, 300), Vector2(450, -30), Vector2(450, 680)]:
		var inside_clamped := _h(clampf(p.x, 0.0, 900.0), clampf(p.y, 0.0, 650.0))
		mid_ok = mid_ok and absf(_h(p.x, p.y) - inside_clamped) < 3.0
	suite.check(mid_ok, "a 10–60 m de la ventana la altura sigue cerca de la del borde (la mezcla no inventa relieve)")


# ---------------------------------------------------------------------------------------------------------------------
# TR-016 · conectividad

func _test_connectivity() -> void:
	var nav: Dictionary = terrain.nav_grid()
	var nx := int(nav["nx"])
	var nz := int(nav["nz"])
	var solid: PackedByteArray = nav["solid"]
	var weight: PackedFloat32Array = nav["weight"]
	suite.check(nx == 226 and nz == 164 and solid.size() == nx * nz and weight.size() == nx * nz and is_equal_approx(float(nav["cell"]), 4.0), "nav_grid(): 226 × 164 nodos de 4 m con sólidos y pesos")
	var w_ok := true
	var solid_n := 0
	for k in range(nx * nz):
		solid_n += solid[k]
		if solid[k] == 0 and (weight[k] < 0.999 or weight[k] > 4.0):
			w_ok = false
	suite.check(w_ok, "el peso de cada nodo libre va de 1,0 a 4 (1 / velocidad en seco)")
	suite.check(solid_n > 300 and solid_n < 2000, "hay muros y borde sólidos, pero no se cierra el mapa (%d de %d nodos sólidos)" % [solid_n, nx * nz])
	var labels := _components(nav)
	var spawns: Dictionary = (level.get("access", {}) as Dictionary).get("spawns", {})
	var targets: Array = ["bateria", "cuartel", "posta", "vado_este", "salida_este", "entrada_sur"]
	var comps: Array = []
	var starts: Array = []
	for g in spawns:
		starts.append(str(spawns[g]))
	starts.append(str((level.get("access", {}) as Dictionary).get("zona_partida", "zona_partida")))
	for id in starts:
		comps.append(_component_near(labels, nav, _lm_pos(str(id))))
	for id in targets:
		comps.append(_component_near(labels, nav, _lm_pos(str(id))))
	var one := not comps.has(0)
	for c in comps:
		one = one and int(c) == int(comps[0])
	suite.check(one, "las 5 partidas y la zona de partida llegan a los 3 objetivos, al vado, a la salida y a la entrada sur por la malla de rutas (%s)" % str(comps))
	var posts_ok := true
	var posts: Dictionary = (level.get("access", {}) as Dictionary).get("attack_posts", {})
	for obj in posts:
		for post in posts[obj]:
			var q := Vector2(float(post["x"]), float(post["z"]))
			posts_ok = posts_ok and _component_near(labels, nav, q) == int(comps[0])
	suite.check(posts_ok, "los seis puestos de ataque están en el mismo componente que los objetivos")
	# las tapias sólidas son las del nivel y los portillos cerrados se abren con open_gaps
	suite.check(bool(terrain.is_blocked(374.0, 376.0)) and bool(terrain.is_blocked(196.0, 505.0)) and not bool(terrain.is_blocked(374.0, 381.0)) and not bool(terrain.is_blocked(450.0, 392.0)),
		"las tapias de la calle del cuartel y del acceso oeste son sólidas; la calle y la plaza, no")
	suite.check(terrain.features("tapia").size() >= 12, "el nivel trae al menos 12 tapias y el terreno las rasteriza (%d)" % terrain.features("tapia").size())
	var gate := Vector2.ZERO
	for g in terrain.features("portillo"):
		if str(g.get("state", "")) == "cerrado":
			var wall: Dictionary = {}
			for f in terrain.features("tapia"):
				if str(f.get("id", "")) == str(g.get("tapia", "")):
					wall = f
			if not wall.is_empty():
				var pts: Array = wall["pts"]
				gate = Vector2(float(pts[0]["x"]), float(pts[0]["z"])).lerp(Vector2(float(pts[1]["x"]), float(pts[1]["z"])), float(g.get("at", 0.5)))
				suite.check(bool(terrain.is_blocked(gate.x, gate.y)) and not bool(terrain.is_blocked(gate.x, gate.y, false, [str(g.get("id", ""))])),
					"el portillo cerrado %s bloquea y open_gaps lo abre (por id)" % str(g.get("id", "")))
				suite.check(not bool(terrain.is_blocked(gate.x, gate.y, false, [gate])), "open_gaps también acepta la posición del portillo")
	suite.check(bool(terrain.is_blocked(-1.0, 100.0)) and bool(terrain.is_blocked(100.0, 651.0)) and bool(terrain.is_blocked(901.0, 100.0)), "fuera de la ventana no se pasa")
	suite.check(is_equal_approx(float(terrain.speed_factor_at(-5.0, 10.0)), 0.0), "la velocidad fuera del mundo es 0")


# ---------------------------------------------------------------------------------------------------------------------
# TR-017 · visión

func _test_los() -> void:
	var plat := _lm_pos("bateria")
	var street := Vector2(374.0, 381.0)  # la calle del cuartel, entre tapias de 2,2 m (z = 376 y z = 386)
	suite.check(bool(terrain.los(plat, street, 1.6, 1.6)), "desde la plataforma de la batería se ve la calle del cuartel por encima de las tapias de 2,2 m")
	if impl == "real":
		var pre: PackedFloat32Array = terrain.heights_without_dome()
		suite.check(not bool(terrain.los_on(pre, plat, street, 1.6, 1.6)), "sin el domo y la plataforma (el DEM solo) esa misma calle no se ve: la ventaja es del relieve de diseño")
	suite.check(not bool(terrain.los(Vector2(590.0, 278.0), Vector2(590.0, 298.0), 1.6, 1.6)), "a ras de suelo, la tapia de 2,4 m de la posta tapa el patio")
	suite.check(bool(terrain.los(Vector2(590.0, 278.0), Vector2(590.0, 298.0), 9.0, 1.6)), "desde una torre (ojos a 9 m) se ve el patio por encima de esa tapia")
	var open_ok := false
	for g in terrain.features("portillo"):
		if str(g.get("id", "")) == "portillo_acceso_este":
			open_ok = true
	if open_ok:
		var wall: Dictionary = {}
		for f in terrain.features("tapia"):
			if str(f.get("id", "")) == "tapia_acceso_este_2":
				wall = f
		var pts: Array = wall["pts"]
		var a := Vector2(float(pts[0]["x"]), float(pts[0]["z"]))
		var b := Vector2(float(pts[1]["x"]), float(pts[1]["z"]))
		var mid := a.lerp(b, 0.5)
		var nrm := (b - a).orthogonal().normalized()
		suite.check(not bool(terrain.los(mid + nrm * 6.0, mid - nrm * 6.0, 1.6, 1.6)) and bool(terrain.los(mid + nrm * 6.0, mid - nrm * 6.0, 1.6, 1.6, ["portillo_acceso_este"])),
			"un portillo cerrado tapa la vista y open_gaps la devuelve")
	suite.check(not bool(terrain.los(Vector2(180.0, 345.0), Vector2(420.0, 345.0), 1.6, 1.6)), "el cerro tapa: desde el llano del oeste no se ve el este a ras de suelo")
	suite.check(bool(terrain.los(Vector2(430.0, 395.0), Vector2(480.0, 395.0), 1.6, 1.6)) and bool(terrain.los(Vector2(300.0, 470.0), Vector2(300.0, 470.0))), "en terreno abierto se ve, y un punto se ve a sí mismo")
	var sym := true
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for _n in range(60):
		var a := Vector2(rng.randf_range(150.0, 700.0), rng.randf_range(150.0, 560.0))
		var b := a + Vector2(rng.randf_range(-120.0, 120.0), rng.randf_range(-120.0, 120.0))
		sym = sym and bool(terrain.los(a, b, 1.6, 1.6)) == bool(terrain.los(b, a, 1.6, 1.6))
	suite.check(sym, "con ojos a la misma altura, la visión es simétrica (60 pares al azar)")
	# la torre: un muro de 2,4 m cerca de su pie solo deja un cono de sombra corto, siempre dentro de los 12 m del ángulo muerto del diseño
	var tower := Vector2(300.0, 300.0)
	var flat: RefCounted = _flat_terrain({"features": {"tapias": [{"id": "t_este", "pts": [{"x": 308.0, "z": 295.0}, {"x": 308.0, "z": 305.0}], "height_m": 2.4, "thickness_m": 0.5, "layout": "AB"}]}}) if impl == "real" else null
	if flat != null:
		var hidden_behind := not bool(flat.los(tower, Vector2(308.6, 300.0), 9.0, 1.6))
		var shadow_end := 0.0
		for r in range(81, 200):  # de 8,1 a 19,9 m del pie de la torre, cada 10 cm
			var d := float(r) * 0.1
			if not bool(flat.los(tower, tower + Vector2(d, 0.0), 9.0, 1.6)):
				shadow_end = d
		suite.check(hidden_behind and shadow_end > 8.5, "el muro de 2,4 m a 8 m de la torre tapa lo que está pegado detrás de él: hay un ángulo muerto (termina a %.1f m)" % shadow_end)
		suite.check(shadow_end < 12.0, "pasados los 12 m del pie de la torre ya no hay sombra de ese muro (la sombra termina a %.1f m)" % shadow_end)
		suite.check(bool(flat.los(tower, tower + Vector2(-30.0, 0.0), 9.0, 1.6)) and bool(flat.los(tower, tower + Vector2(0.0, 40.0), 9.0, 1.6)), "la torre ve en las otras direcciones, sin muro")
	var q := _lm_pos("quebradita_norte")
	suite.check(not bool(terrain.los(q + Vector2(55.0, 30.0), q, 1.6, 1.0)) and bool(terrain.los(q + Vector2(4.0, 0.0), q, 1.6, 1.0)),
		"la quebradita norte esconde lo que hay en su piso de quien mira desde el este y desde cerca se ve")
	if impl == "real":
		var edge_los := bool(terrain.los(plat + Vector2(10.0, 0.0), street, 1.6, 1.6)) and bool(terrain.los(plat, Vector2(520.0, 330.0), 1.6, 1.6)) and not bool(terrain.los(plat, Vector2(590.0, 300.0), 1.6, 1.6))
		suite.check(edge_los, "desde la losa se ve la calle de la posta (200 m al este), y el templo (7 m) sigue tapando el patio de la posta")


# ---------------------------------------------------------------------------------------------------------------------
# TR-018 · gradiente y curva de 2 960 m

func _test_gradient_and_contour() -> void:
	var west := _h(40.0, 325.0)
	var east := _h(860.0, 325.0)
	suite.check(west - east >= 10.0, "el gradiente va de oeste a este: en z = 325 el oeste está %.1f m más alto que el este (≥ 10 m)" % (west - east))
	var core := _h(450.0, 325.0)
	suite.check(_h(859.0, 325.0) < core and _h(900.0, 405.0) < core, "el cauce (en su entrada, en el vado y en la salida) está más bajo que el núcleo")
	var refs := {0.0: 270.0, 325.0: 366.0, 650.0: 380.0}  # curva de 2 960 m en los tres bordes (lámina: P24, P25 y P26)
	var datum := float(terrain.datum_asl_m)
	for z in refs:
		var found := -1.0
		var prev := float(terrain.height_dem_only(0.0, z)) + datum
		for xi in range(1, 901):
			var cur := float(terrain.height_dem_only(float(xi), z)) + datum
			if (prev - 2960.0) * (cur - 2960.0) <= 0.0:
				if found < 0.0 or absf(float(xi) - float(refs[z])) < absf(found - float(refs[z])):
					found = float(xi)
			prev = cur
		suite.check(found >= 0.0 and absf(found - float(refs[z])) <= 15.0, "la curva de 2 960 m cruza z = %d cerca de x = %d (a %.0f m; tolera 15 m)" % [int(z), int(refs[z]), found])


# ---------------------------------------------------------------------------------------------------------------------
# Río, superficies y velocidad

func _test_river_and_surfaces() -> void:
	var rv: Dictionary = terrain.river()
	var pts: Array = rv.get("pts", [])
	suite.check(pts.size() >= 14, "el río tiene al menos 14 puntos medidos de la lámina 03 (%d)" % pts.size())
	var sorted_ok := true
	for k in range(1, pts.size()):
		sorted_ok = sorted_ok and float(pts[k]["z"]) > float(pts[k - 1]["z"])
	suite.check(sorted_ok and absf(float(pts[0]["z"])) <= 6.0 and absf(float(pts[pts.size() - 1]["x"]) - 900.0) <= 6.0 and absf(float(pts[pts.size() - 1]["z"]) - 406.0) <= 12.0,
		"el río entra por el borde norte (z ≈ 0) y sale por el este (x = 900, z = 406 ± 12), de norte a sur")
	var bed: Dictionary = rv.get("bed_width_m", {})
	suite.check(is_equal_approx(float(bed.get("min", 0.0)), 25.0) and is_equal_approx(float(bed.get("max", 0.0)), 40.0), "el lecho mide de 25 a 40 m (river().bed_width_m)")
	var water_ok := true
	var carve_ok := true
	for k in range(1, pts.size() - 1):
		var x := float(pts[k]["x"])
		var z := float(pts[k]["z"])
		water_ok = water_ok and terrain.surface_at(x, z) == "agua"
		carve_ok = carve_ok and _h(x, z) - float(terrain.height_dem_only(x, z)) <= -0.9
	suite.check(water_ok, "sobre el eje del río la superficie es «agua» en todos los puntos interiores")
	suite.check(carve_ok, "el cauce está tallado: sobre el eje la altura final queda al menos 0,9 m bajo el DEM")
	suite.check(bool(terrain.is_ford(862.0, 340.0)) and bool(terrain.is_ford(766.0, 152.0)) and not bool(terrain.is_ford(450.0, 325.0)), "hay dos vados (el del este y el del norte) y el núcleo no es un vado")
	var rivers_fords: Array = rv.get("fords", [])
	suite.check(rivers_fords.size() == 2, "river().fords trae los dos vados")
	suite.check(terrain.surface_at(870.0, 337.0) in ["agua", "sedimento_humedo"] and terrain.surface_at(450.0, 392.0) in ["patio", "suelo_seco", "camino"], "el vado es agua o sedimento; la plaza es suelo apisonado")
	var classes_ok := true
	var n_by_class := {}
	for j in range(0, 164, 2):
		for i in range(0, 226, 2):
			var s: String = terrain.surface_at(float(i) * 4.0, float(j) * 4.0)
			classes_ok = classes_ok and VT.SURFACES.has(s)
			n_by_class[s] = int(n_by_class.get(s, 0)) + 1
	suite.check(classes_ok and n_by_class.has("agua") and n_by_class.has("sedimento_humedo") and n_by_class.has("camino") and n_by_class.has("irrigado") and n_by_class.has("piedra") and n_by_class.has("churqui"),
		"surface_at devuelve siempre una clase de SURFACES y el mapa trae agua, sedimento, camino, irrigado, piedra y churqui (%s)" % str(n_by_class.keys()))
	# velocidad: barro, pendiente, zanja y muro
	var dry_road := float(terrain.speed_factor_at(450.0, 380.0, 0.0))
	var wet_road := float(terrain.speed_factor_at(450.0, 380.0, 1.0))
	suite.check(dry_road > wet_road and wet_road >= 0.5 and dry_road <= 1.0, "la lluvia frena el camino de tierra (seco %.2f, mojado %.2f)" % [dry_road, wet_road])
	var ditch := Vector2(204.0, 505.0)
	suite.check(terrain.surface_at(ditch.x, ditch.y) == "zanja" and absf(float(terrain.speed_factor_at(ditch.x, ditch.y, 0.0)) - 0.5) < 0.01 and absf(float(terrain.speed_factor_at(ditch.x, ditch.y, 1.0)) - 0.5) < 0.01,
		"la zanja frena a la mitad con o sin lluvia")
	var flank := Vector2(330.0, 366.0)  # el flanco sur del cerro
	var steep_slope := float(terrain.slope_deg_at(flank.x, flank.y))
	suite.check(steep_slope > 8.0 and float(terrain.speed_factor_at(flank.x, flank.y, 0.0)) < float(terrain.speed_factor_at(600.0, 560.0, 0.0)) - 0.05,
		"subir el flanco del cerro (%.1f°) cuesta velocidad frente al llano" % steep_slope)
	suite.check(float(terrain.speed_factor_at(flank.x, flank.y, 0.0)) >= 0.6 - 0.001, "la pendiente no frena más allá del piso de 0,6 (surfaces.slope_penalty)")
	suite.check(float(terrain.wetness_at(450.0, 380.0, 0.0)) <= float(terrain.wetness_at(450.0, 380.0, 1.0)) and float(terrain.wetness_at(870.0, 337.0, 0.0)) >= 0.5,
		"wetness_at sube con la lluvia y el agua está siempre mojada")
	var nrm: Vector3 = terrain.normal_at(flank.x, flank.y)
	suite.check(absf(nrm.length() - 1.0) < 0.001 and nrm.y > 0.0 and nrm.y < 0.99, "normal_at es un vector unitario que se inclina en el flanco del cerro")


# ---------------------------------------------------------------------------------------------------------------------
# Micro-relieve y capas de diseño

func _test_micro_and_layers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var worst_micro := 0.0
	var worst_slope := 0.0
	var n := 0
	var micro: Dictionary = (map.get("relief", {}) as Dictionary).get("micro", {})
	var amp := float(micro.get("amp_m", 0.5))
	while n < 600:
		var x := rng.randf_range(30.0, 870.0)
		var z := rng.randf_range(30.0, 620.0)
		if Vector2(x, z).distance_to(Vector2(305.0, 345.0)) < 90.0 or Vector2(x, z).distance_to(Vector2(282.0, 298.0)) < 50.0 or Vector2(x, z).distance_to(Vector2(288.0, 402.0)) < 50.0:
			continue
		if _dist_to_river(Vector2(x, z)) < 70.0:
			continue  # el cauce y sus bancos
		worst_micro = maxf(worst_micro, absf(_h(x, z) - float(terrain.height_dem_only(x, z))))
		worst_slope = maxf(worst_slope, float(terrain.slope_deg_at(x, z)))
		n += 1
	suite.check(worst_micro <= amp + 0.001, "el micro-relieve no pasa de ±%.1f m (peor: %.3f m en 600 puntos)" % [amp, worst_micro])
	suite.check(worst_slope < 8.0, "el micro-relieve no activa la regla de subida: pendiente máxima %.2f° (< 8°)" % worst_slope)
	suite.check(worst_micro > 0.15, "hay micro-relieve (el suelo no es liso): se mueve hasta %.2f m" % worst_micro)
	var layers: Dictionary = {}
	for l in terrain.report().get("design_layers", []):
		layers[str(l["id"])] = l
	var all_there := true
	for id in DESIGN_R1:
		all_there = all_there and layers.has(id) and str((layers[id] as Dictionary).get("tag", "")) == "diseno"
	suite.check(all_there, "las cinco capas de diseño de R1 (cerro, plataforma, dos quebraditas y cauce) figuran en report() como «diseno»")
	for id in ["quebradita_norte", "quebradita_sur"]:
		var q := _lm_pos(id)
		var rim := 0.0
		for d: Vector2 in [Vector2(0, -14), Vector2(0, 14), Vector2(14, 0)]:
			rim += _h(q.x + d.x, q.y + d.y) - float(terrain.height_dem_only(q.x + d.x, q.y + d.y))
		rim /= 3.0
		var floor_delta := _h(q.x, q.y) - float(terrain.height_dem_only(q.x, q.y))
		suite.check(floor_delta < rim - 2.0, "%s: el piso queda más de 2 m bajo lo que la rodea (piso %.2f m, borde %.2f m respecto del DEM)" % [id, floor_delta, rim])
	var steep := float(terrain.report().get("slope_cells_pct_ge8", 0.0))
	suite.check(steep >= 1.5 and steep <= 15.0, "entre el 1,5 y el 15 %% de las celdas de la ventana tienen pendiente ≥ 8° (flanco del cerro, quebraditas y cauce): %.2f %%" % steep)


func _dist_to_river(p: Vector2) -> float:
	var pts: Array = terrain.river().get("pts", [])
	var best := 1.0e9
	for k in range(pts.size() - 1):
		var a := Vector2(float(pts[k]["x"]), float(pts[k]["z"]))
		var b := Vector2(float(pts[k + 1]["x"]), float(pts[k + 1]["z"]))
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)))
	return best


# ---------------------------------------------------------------------------------------------------------------------
# VP-03 · huella y yaw

func _test_footprint_convention() -> void:
	if impl != "real":
		return
	var probe := {"id": "x_prueba", "name": "Caja de prueba", "short": "Prueba", "type": "edificio", "x": 200.0, "z": 150.0, "yaw_deg": 30.0, "footprint": {"w": 22.0, "d": 8.0},
		"height_m": 3.0, "tag": "diseno", "source": "prueba", "priority": 6, "variant": {}}
	var t2: RefCounted = _flat_terrain({}, [probe])
	var poly: PackedVector2Array = t2.footprint_polygon("x_prueba")
	suite.check(poly.size() == 4, "la huella rectangular tiene cuatro esquinas")
	var yaw := deg_to_rad(30.0)
	var expected: Array = []
	for s in [[-1.0, -1.0], [1.0, -1.0], [1.0, 1.0], [-1.0, 1.0]]:
		var lx: float = float(s[0]) * 11.0
		var lz: float = float(s[1]) * 4.0
		# giro horario visto en el mapa (norte arriba, este a la derecha): x' = x·cos − z·sin ; z' = x·sin + z·cos
		expected.append(Vector2(200.0 + lx * cos(yaw) - lz * sin(yaw), 150.0 + lx * sin(yaw) + lz * cos(yaw)))
	var corners_ok := poly.size() == 4
	if corners_ok:
		for k in range(4):
			corners_ok = corners_ok and poly[k].distance_to(expected[k]) < 0.001
	suite.check(corners_ok, "VP-03: las esquinas de la huella son centro + R(yaw)·(±w/2, ±d/2) con el giro horario del mapa")
	# y la vista tapada por ese edificio sigue la misma huella: la esquina «noreste» girada queda afuera del polígono, su centro adentro
	suite.check(Geometry2D.is_point_in_polygon(Vector2(200.0, 150.0), poly) and not Geometry2D.is_point_in_polygon(Vector2(200.0 + 11.0, 150.0 - 4.0), poly),
		"el centro cae adentro de la huella y la esquina sin girar queda afuera (el giro se aplica)")
	suite.check(not bool(t2.los(Vector2(170.0, 138.0), Vector2(230.0, 162.0), 1.6, 1.6)) and bool(t2.los(Vector2(170.0, 138.0), Vector2(170.0, 110.0), 1.6, 1.6)),
		"un edificio de 3 m tapa la vista a ras de suelo a través de su huella girada y no tapa lo que está al costado")
	suite.check(t2.footprint_polygon("no_existe").is_empty(), "footprint_polygon de un hito que no existe devuelve un arreglo vacío")


# ---------------------------------------------------------------------------------------------------------------------
# VP-04 · lo que consume la vista (sobre el terreno real y el stub)

func _test_vp04_contracts() -> void:
	for pair in [["real", terrain], ["stub", stub]]:
		var label: String = pair[0]
		var t: RefCounted = pair[1]
		if t == null:
			continue
		var lms: Array = t.landmarks({})
		var lm_ok := lms.size() >= 21
		for lm in lms:
			lm_ok = lm_ok and (lm as Dictionary).has("footprint") and (lm as Dictionary).has("height_m") and (lm as Dictionary).has("yaw_deg") and (lm as Dictionary).has("tag")
		suite.check(lm_ok, "[%s] landmarks({}) devuelve los 21 hitos con footprint, height_m, yaw_deg y tag" % label)
		var feat_ok := true
		for kind in VT.FEATURE_KINDS:
			for f in t.features(kind):
				if (f as Dictionary).has("pts"):
					for p in f["pts"]:
						feat_ok = feat_ok and p is Dictionary and (p as Dictionary).has("x") and (p as Dictionary).has("z")
		suite.check(feat_ok, "[%s] features(kind) trae los puntos como {x, z}" % label)
		var rv: Dictionary = t.river()
		suite.check(rv.has("bed_width_m") and rv.has("pts") and (rv["pts"] as Array).size() >= 2 and (rv["pts"][0] as Dictionary).has("x"), "[%s] river() trae bed_width_m y los puntos como {x, z}" % label)
		var sizes_ok := true
		for sz in [Vector2i(260, 188), Vector2i(520, 376), Vector2i(97, 61), Vector2i(1, 1), Vector2i(333, 77)]:
			var img: Image = t.minimap_image(sz, {})
			sizes_ok = sizes_ok and img != null and img.get_width() == sz.x and img.get_height() == sz.y
		suite.check(sizes_ok, "[%s] minimap_image(px) devuelve una imagen de exactamente px (5 tamaños)" % label)
		var h_ok := true
		for p: Vector2 in [Vector2(-1350, -1050), Vector2(2250, 1700), Vector2(450, 325), Vector2(900, 650)]:
			h_ok = h_ok and is_finite(float(t.height_at(p.x, p.y)))
		suite.check(h_ok, "[%s] height_at responde con números finitos en x ∈ [−1350, 2250], z ∈ [−1050, 1700]" % label)
	var img: Image = terrain.minimap_image(Vector2i(260, 188), {})
	var distinct := {}
	for j in range(0, 188, 4):
		for i in range(0, 260, 4):
			distinct[img.get_pixel(i, j).to_html(false)] = true
	suite.check(distinct.size() >= 12, "el mapa chico del terreno real dibuja relieve, curvas y cauce (%d colores) y no un solo color" % distinct.size())
	suite.check(terrain.minimap_image(Vector2i(260, 188), {}).get_data() == img.get_data(), "el mapa chico es determinista (la misma imagen dos veces)")


# ---------------------------------------------------------------------------------------------------------------------
# TR-021 · consecuencias del relieve (se exige desde r2a; acá se mide)

func _test_relief_consequences() -> void:
	var rep: Dictionary = terrain.report()
	var feats: Array = rep.get("vertical_features", [])
	var with_effect := 0
	for f in feats:
		if int((f as Dictionary).get("los_pairs", 0)) > 0 or int((f as Dictionary).get("speed_pairs", 0)) > 0:
			with_effect += 1
	suite.check(feats.size() >= 3, "report().vertical_features lista los rasgos verticales de R1: el cerro y las dos quebraditas (%d)" % feats.size())
	suite.check(with_effect >= 3, "los tres rasgos verticales cambian la visión o la velocidad de algún par de puntos con y sin el rasgo (%d de %d)" % [with_effect, feats.size()])
	var pct := float(rep.get("slope_cells_pct_ge8", 0.0))
	suite.pend("TR-021", "≥ 2,5 %% de celdas con pendiente de 8° o más y ≥ 3 rasgos con consecuencia (hoy %.2f %%; la barranca, la terraza y el banco llegan en R2a)" % pct, "r2a")


# ---------------------------------------------------------------------------------------------------------------------
# TR-022 · prueba A/B de fuente (con una fuente sintética hasta que llegue la tesela)

func _test_source_ab() -> void:
	if impl != "real" or real_script == null:
		return
	var h2: Dictionary = height.duplicate(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	for grid_name in ["window", "context"]:
		var g: Dictionary = h2[grid_name]
		var arr: Array = g["h"]
		var nx := int(g["nx"])
		for k in range(arr.size()):
			var i := k % nx
			var j := k / nx
			arr[k] = int(arr[k]) + 40 + int(round(8.0 * sin(float(i) * 0.7 + float(j) * 0.3))) + (rng.randi_range(-2, 2) if grid_name == "window" else 0)
		g["h"] = arr
	h2["meta"]["source"] = "copernicus_glo30"
	var a: RefCounted = terrain
	var b: RefCounted = real_script.call("from_data", map, h2, level)
	var pb := float(b.report().get("prominence_bateria_m", 0.0))
	suite.check(absf(pb - 12.0) <= 0.5, "A/B: con otra fuente (+4 m y ondulación de ±0,8 m) la prominencia de la batería sigue en 12,0 ± 0,5 m (%.3f m)" % pb)
	suite.check(float(b.height_dem_only(40.0, 325.0)) - float(b.height_dem_only(860.0, 325.0)) >= 10.0, "A/B: el signo del gradiente oeste a este se conserva (≥ 10 m de caída en z = 325)")
	var d_a := float(a.height_dem_only(450.0, 325.0)) - float(a.height_dem_only(859.0, 325.0))
	var d_b := float(b.height_dem_only(450.0, 325.0)) - float(b.height_dem_only(859.0, 325.0))
	suite.check(absf(d_a - d_b) < 3.0, "A/B: el desnivel entre el núcleo y el cauce cambia %.2f m (la fuente sintética mueve todo junto)" % absf(d_a - d_b))
	suite.check(str(b.report().get("source", "")) == "copernicus_glo30", "A/B: report() dice de qué fuente sale el relieve")
	var near_ok := absf(float(b.height_at(700.0, 500.0)) - float(a.height_at(700.0, 500.0)) - 4.0) < 1.5
	suite.check(near_ok, "A/B: lejos de las capas de diseño la altura sigue a la fuente (+4 m)")
	suite.pend("TR-022", "diferencia de cota entre objetivos ≤ 1 m con otra fuente: las explanadas de diseño (cuartel, posta y plaza) llegan en R2a", "r2a")
	var empty: RefCounted = real_script.call("from_data", {}, {}, {})
	suite.check(empty != null and is_finite(float(empty.height_at(450.0, 325.0))) and str(empty.report().get("source", "")) == "ausente",
		"sin datos de relieve el terreno se arma plano y lo dice (source = ausente) en vez de caerse")


# ---------------------------------------------------------------------------------------------------------------------
# TR-019 · presupuestos

func _test_bake_budget() -> void:
	if impl != "real" or real_script == null:
		return
	var t0 := Time.get_ticks_usec()
	var fresh: RefCounted = real_script.new()
	var wall_ms := float(Time.get_ticks_usec() - t0) / 1000.0
	var rep: Dictionary = fresh.report()
	var stages: Dictionary = rep.get("bake_stages_ms", {})
	suite.check(float(rep.get("bake_ms", 999.0)) < 300.0, "horneado completo < 300 ms (%.1f ms)" % float(rep.get("bake_ms", 0.0)))
	suite.check(wall_ms < 300.0, "armar el terreno desde los JSON, incluida la lectura, < 300 ms (%.1f ms)" % wall_ms)
	var names_ok := true
	var total := 0.0
	for stage in ["lectura", "relieve", "capas", "pendiente", "superficies", "muros", "navegacion", "informe"]:
		names_ok = names_ok and stages.has(stage)
		total += float(stages.get(stage, 0.0))
	suite.check(names_ok and absf(total - float(rep.get("bake_ms", 0.0))) < 5.0, "el horneado se mide por ocho etapas que suman el total (%s)" % str(stages))
	var worst_stage := 0.0
	for stage in stages:
		worst_stage = maxf(worst_stage, float(stages[stage]))
	suite.check(worst_stage < 150.0, "ninguna etapa pasa de la mitad del presupuesto (la peor: %.1f ms)" % worst_stage)
	var best_rate := 0.0
	var acc := 0.0
	for _round in range(3):
		var t1 := Time.get_ticks_usec()
		var n := 120000
		for k in range(n):
			acc += float(terrain.height_at(float(k % 900), float((k * 7) % 650)))
		var secs := maxf(float(Time.get_ticks_usec() - t1) / 1.0e6, 0.000001)
		best_rate = maxf(best_rate, float(n) / secs)
	suite.check(best_rate >= 1.0e6 and acc != 0.0, "height_at resuelve al menos 1 millón de consultas por segundo (mejor de 3 corridas: %.2f millones)" % (best_rate / 1.0e6))
	suite.extra["height_at_Mconsultas_por_s"] = snappedf(best_rate / 1.0e6, 0.01)
	var t2 := Time.get_ticks_usec()
	for k in range(300):
		terrain.los(Vector2(300.0 + float(k % 100), 400.0), Vector2(450.0, 325.0), 1.6, 1.6)
	var los_us := float(Time.get_ticks_usec() - t2) / 300.0
	suite.check(los_us < 400.0, "los de 100 a 170 m cuesta menos de 0,4 ms (%.0f µs)" % los_us)
	suite.extra["los_us"] = snappedf(los_us, 1.0)


# ---------------------------------------------------------------------------------------------------------------------
# TR-020 · el informe rotula dato y diseño

func _test_report_labels() -> void:
	var rep: Dictionary = terrain.report()
	for key in ["source", "tag", "uncertainty_m", "smooth_m", "h_min", "h_max", "design_layers", "prominence_bateria_m", "slope_cells_pct_ge8", "vertical_features", "lamina_check", "bake_ms", "bake_stages_ms", "counts"]:
		suite.check(rep.has(key), "report() trae la clave «%s»" % key)
	suite.check(SOURCES.has(str(rep.get("source", ""))), "report().source es una de las fuentes del contrato (%s)" % str(rep.get("source", "")))
	suite.check(str(rep.get("tag", "")) == "razonado" and float(rep.get("uncertainty_m", 0.0)) in [5.0, 10.0], "el relieve base se rotula «razonado» con su incertidumbre (±%s m)" % float(rep.get("uncertainty_m", 0.0)))
	var layers: Array = rep.get("design_layers", [])
	var dome: Dictionary = {}
	var tagged := true
	for l in layers:
		tagged = tagged and str((l as Dictionary).get("tag", "")) == "diseno"
		if str((l as Dictionary).get("id", "")) == "cerro_bateria":
			dome = l
	suite.check(tagged and layers.size() >= 5, "todas las capas de diseño (%d) se rotulan «diseno»" % layers.size())
	suite.check(is_equal_approx(float(dome.get("prominence_target_m", 0.0)), 12.0) and absf(float(dome.get("delta_m", 99.0))) <= 30.0, "cerro_bateria figura con prominence_target_m = 12 y un delta_m razonable (%.2f m)" % float(dome.get("delta_m", 0.0)))
	if impl == "real":
		var labels: Dictionary = rep.get("labels", {})
		suite.check((labels.get("dato_actual", []) as Array).size() >= 1 and (labels.get("diseno", []) as Array).size() >= 5, "report().labels separa lo que es dato actual de lo que es diseño")
		suite.check(str(labels.get("texto", "")).to_lower().contains("dato actual, no restitución del suelo de 1817"), "el texto obligatorio dice «dato actual, no restitución del suelo de 1817» (H03, texto nº 4)")
		suite.check(int((rep.get("counts", {}) as Dictionary).get("capas_de_diseno", 0)) == layers.size(), "counts.capas_de_diseno cuenta las capas")
