extends SceneTree
## Revisión en la nube, lente G (rendimiento en tiempo real). Hallazgo: el minimapa se redibuja a 10 Hz (humahuaca_minimap.gd l. 73-79) y en CADA redibujo,
## aunque la cámara esté quieta, vuelve a marchar cinco rayos sobre el relieve en GDScript (humahuaca_view.camera_frustum_on_ground l. 521-535 y meters_per_pixel
## l. 538-546, ambos por _ray_ground l. 489-512: un height_at cada 3-20 m hasta tocar el suelo) y pide dos veces rules.render_state() sin pasar por
## render_state_cached (l. 132 y l. 162). Medido sin ventana: 1,3-1,7 ms el cuadro de la cámara, 0,3 ms la escala y 0,25 ms los dos render_state: un redibujo del
## minimapa cuesta 2,4 ms de CPU y es el mayor costo regular del nivel (≈ 24 ms por segundo de juego, un tercio de todo lo que gasta el nivel por segundo); cuando
## coincide con un refresco del HUD el cuadro pasa de 5,5 a 18 ms de CPU.
## Esperado: con la cámara quieta, un segundo redibujo no vuelve a muestrear el relieve (0 height_at) y un redibujo pide a lo sumo un render_state. Hoy: 1 100 y 2.
## godot --headless --path . --script tests/revision_nube/g_minimapa_rayos_por_redibujo.gd   (perfil user:// aislado). Sale con 1 si el defecto sigue.

const Fx = preload("res://tests/hx_fixtures.gd")

var game: Node
var hx: Node
var failures := 0


## Envoltorio del terreno de la vista: cuenta los height_at que piden sus rayos (la vista solo le pide height_at a _terrain en _h).
class CountingTerrain extends RefCounted:
	var inner: RefCounted = null
	var calls := 0

	func height_at(x: float, z: float) -> float:
		calls += 1
		return float(inner.height_at(x, z))


## Consultas de las reglas que cuentan los render_state (las reglas delegan en _info()).
class CountingInfo extends "res://scripts/humahuaca/rules/humahuaca_rules_info.gd":
	var renders := 0

	func render_state() -> Dictionary:
		renders += 1
		return super()


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


## Un cuadro con el HUD y el overlay callados; con `redraw` el minimapa se redibuja en ese cuadro (su temporizador vence).
func _quiet_frame(redraw: bool) -> void:
	hx._hud_timer = 10.0
	hx.overlay._wait = 10.0
	hx.minimap._redraw_wait = 0.0 if redraw else 10.0
	await process_frame


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
	if hx == null or hx.rules == null or not is_instance_valid(hx.view) or str(hx.layers.get("view", "")) != "real":
		print("FALLA: el nivel no arrancó con la vista real (%s)" % str(hx.layers if hx != null else {}))
		quit(1)
		return
	hx.paused = true
	await _quiet_frame(true)  # el primer redibujo arma la textura del relieve; no se cuenta
	var real_terrain: RefCounted = hx.view._terrain
	var terrain_counter := CountingTerrain.new()
	terrain_counter.inner = real_terrain
	hx.view._terrain = terrain_counter
	var info_counter := CountingInfo.new(hx.rules)
	hx.rules._info_inst = info_counter
	var cam: Camera3D = hx.call("camera3d")
	var pose_before: Transform3D = cam.global_transform
	# cuadro sin redibujo: lo que piden la vista y el resto por su cuenta
	terrain_counter.calls = 0
	info_counter.renders = 0
	await _quiet_frame(false)
	var base_h := terrain_counter.calls
	var base_r := info_counter.renders
	# dos redibujos seguidos con la cámara quieta
	var h_calls: Array = []
	var r_calls: Array = []
	for k in range(2):
		terrain_counter.calls = 0
		info_counter.renders = 0
		var t0 := Time.get_ticks_usec()
		await _quiet_frame(true)
		var us := Time.get_ticks_usec() - t0
		h_calls.append(terrain_counter.calls - base_h)
		r_calls.append(info_counter.renders - base_r)
		print("info: redibujo %d del minimapa: %d height_at y %d render_state más que un cuadro sin redibujo (%d µs el cuadro)" % [k + 1, terrain_counter.calls - base_h, info_counter.renders - base_r, us])
	_check(cam.global_transform == pose_before, "la cámara no se movió entre los dos redibujos")
	_check(int(h_calls[1]) == 0, "un redibujo del minimapa con la cámara quieta no vuelve a muestrear el relieve: esperaba 0 height_at, hubo %d" % int(h_calls[1]))
	_check(int(r_calls[1]) <= 1, "un redibujo del minimapa pide a lo sumo un render_state (o usa render_state_cached): esperaba ≤ 1, hubo %d" % int(r_calls[1]))
	hx.view._terrain = real_terrain
	hx.rules._info_inst = null
	game._stop_humahuaca()
	await _frames(2)
	game.queue_free()
	await process_frame
	for leftover in ["user://qa_humahuaca_progress.json", "user://qa_humahuaca_checkpoint.json"]:  # el nivel en modo QA los escribe: la prueba no deja nada en user://
		if FileAccess.file_exists(leftover):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(leftover))
	print("resultado: %d fallas" % failures)
	quit(1 if failures > 0 else 0)
