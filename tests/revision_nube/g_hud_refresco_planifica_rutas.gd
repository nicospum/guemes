extends SceneTree
## Revisión en la nube, lente G (rendimiento en tiempo real). Hallazgo: cada refresco del HUD (hud_period_s = 0,2 s; humahuaca_ui_play._refresh_hud l. 765-794)
## con una agrupación elegida vuelve a planificar rutas A*: orders.bar_items (humahuaca_orders.gd l. 71-100) pregunta action_availability por cada acción de la
## selección con un destino de prueba (450, 325), y _check (humahuaca_rules.gd l. 1270-1282) arma la ruta entera (nav.find_path + alisado) para move, position,
## support, recon y leave. Medido sin ventana (CPU, Godot 4.7.2 headless): un refresco cuesta 1,0-2,0 ms sin selección y 2,4-11,6 ms con una partida elegida
## (hasta 3 rutas por refresco, 5 veces por segundo); en la escena real los cuadros con refresco del HUD pasan de 2,9 ms a 4,5 ms de media (máximo 15 ms).
## DISENO_HUMAHUACA.md l. 206: «la interfaz solo pinta»; el HUD no debería calcular rutas para saber si un botón está habilitado.
## Esperado: pintar el HUD (un _refresh_hud) con una agrupación elegida no llama a nav.find_path (0 rutas). Hoy: 3 (move, position y support).
## godot --headless --path . --script tests/revision_nube/g_hud_refresco_planifica_rutas.gd   (perfil user:// aislado). Sale con 1 si el defecto sigue.

const Fx = preload("res://tests/hx_fixtures.gd")

var game: Node
var hx: Node
var failures := 0


## Envoltorio de la grilla de navegación que cuenta las rutas pedidas (las reglas solo usan find_path sobre nav()).
class CountingNav extends RefCounted:
	var inner: RefCounted = null
	var calls := 0
	var last: Array = []

	func find_path(a: Vector2, b: Vector2) -> Array:
		calls += 1
		last.append([a, b])
		return inner.find_path(a, b)


func _initialize() -> void:
	if not Fx.profile_isolated():
		print("perfil NO aislado: exportá un user:// con «ap_iso» en el nombre")
		quit(2)
		return
	OS.set_low_processor_usage_mode_sleep_usec(300)
	call_deferred("_run")


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _check(ok: bool, text: String) -> void:
	print(("OK: " if ok else "FALLA: ") + text)
	if not ok:
		failures += 1


func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	game = scene.instantiate()
	root.add_child(game)
	await _frames(4)
	game.jev.force_local = true
	game.settings.auto_pause = false
	if is_instance_valid(game.audio_manager):
		game.audio_manager.set_muted(true)
	game._start_humahuaca({"skip_intro": true, "seed": 3, "qa": true})
	await _frames(4)
	hx = game.hx
	if hx == null or hx.rules == null or str(hx.layers.get("rules", "")) != "real":
		print("FALLA: el nivel no arrancó con las reglas reales (%s)" % str(hx.layers if hx != null else {}))
		quit(1)
		return
	hx.paused = true
	var real_nav: RefCounted = hx.rules.call("nav")
	_check(real_nav != null, "las reglas tienen grilla de navegación")
	var counter := CountingNav.new()
	counter.inner = real_nav
	hx.rules._nav = counter
	for id in ["rodriguez", "arreo", "reconocedores"]:
		hx.call("select", [id], "replace")  # select() ya refresca el HUD: lo que sigue es un refresco más, el periódico
		counter.calls = 0
		counter.last = []
		var t0 := Time.get_ticks_usec()
		hx.call("_refresh_hud", true)
		var us := Time.get_ticks_usec() - t0
		var n_refresh := counter.calls
		var rutas: Array = counter.last.duplicate()
		counter.calls = 0
		var acciones: Array = hx.orders.bar_items(hx._hs).map(func(it): return str(it.action))  # la barra sola, para separar su parte
		var n_bar := counter.calls
		var pares: Array = rutas.map(func(p): return "%s→%s" % [str(Vector2i(p[0])), str(Vector2i(p[1]))])
		_check(n_refresh == 0, "un refresco del HUD con «%s» elegida no planifica rutas: esperaba 0 find_path, hubo %d (%d µs; %d de la barra %s, el resto del «siguiente paso» %s): %s" % [id, n_refresh, us, n_bar, str(acciones), str(hx.guide.get("action", "")), ", ".join(PackedStringArray(pares))])
	hx.call("select", [], "replace")
	counter.calls = 0
	hx.call("_refresh_hud", true)
	print("info: sin selección, un refresco pide %d rutas (el «siguiente paso» %s también pasa por action_availability)" % [counter.calls, str(hx.guide.get("action", ""))])
	hx.rules._nav = real_nav
	game._stop_humahuaca()
	await _frames(2)
	game.queue_free()
	await process_frame
	print("resultado: %d fallas" % failures)
	quit(1 if failures > 0 else 0)
