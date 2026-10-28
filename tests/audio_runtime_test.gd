extends SceneTree
## Prueba de audio en tiempo de ejecucion. Ejecutar CON ventana y sin --audio-driver Dummy:
##   Godot_v4.7.2-stable_win64.exe --path . --script tests/audio_runtime_test.gd
## Comprueba el driver real, los buses, el tope de voces, que haya senal en los buses
## (picos medidos por AudioServer) y la limpieza al cerrar. No sustituye la escucha humana.

var checks := 0
var failures := 0


func _check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		print("FALLA: ", msg)
	else:
		print("ok: ", msg)


func _peak(bus: String) -> float:
	var i := AudioServer.get_bus_index(bus)
	return maxf(AudioServer.get_bus_peak_volume_left_db(i, 0), AudioServer.get_bus_peak_volume_right_db(i, 0))


func _wait(seconds: float, peaks: Dictionary) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
		for bus in peaks:
			peaks[bus] = maxf(float(peaks[bus]), _peak(bus))


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var driver := AudioServer.get_driver_name()
	print("Driver de audio: ", driver, " | mix_rate ", AudioServer.get_mix_rate(), " | latencia salida ", snappedf(AudioServer.get_output_latency() * 1000.0, 0.1), " ms")
	_check(driver != "Dummy", "driver de audio real (no Dummy)")
	var mgr: Node = load("res://scripts/audio_manager.gd").new()
	root.add_child(mgr)
	await process_frame
	for bus in ["Musica", "Ambiente", "Efectos", "UI"]:
		_check(AudioServer.get_bus_index(bus) >= 0, "bus " + bus + " existe")
	var master := AudioServer.get_bus_index("Master")
	var limiter := false
	for i in AudioServer.get_bus_effect_count(master):
		limiter = limiter or AudioServer.get_bus_effect(master, i) is AudioEffectHardLimiter
	_check(limiter, "limitador en Master")
	mgr.set_volume(1.0)
	var peaks := {"Ambiente": -80.0, "Efectos": -80.0, "UI": -80.0, "Master": -80.0}
	mgr.set_environment("justine")
	await _wait(1.0, peaks)
	_check(mgr._ambient_players.size() == 2, "justine arranca 2 capas ambientales")
	_check(float(peaks["Ambiente"]) > -60.0, "senal en bus Ambiente (pico %.1f dB)" % float(peaks["Ambiente"]))
	for s in ["order", "error", "alert", "bell", "cannon", "hoof", "dismount", "victory"]:
		mgr.play(s)
		await _wait(0.35, peaks)
	_check(float(peaks["Efectos"]) > -60.0, "senal en bus Efectos (pico %.1f dB)" % float(peaks["Efectos"]))
	_check(float(peaks["UI"]) > -60.0, "senal en bus UI (pico %.1f dB)" % float(peaks["UI"]))
	_check(float(peaks["Master"]) <= -0.5, "Master no supera el techo del limitador (pico %.2f dB)" % float(peaks["Master"]))
	# Tormenta de pedidos: el tope de voces y las polifonias se mantienen.
	var worst := 0
	for k in 120:
		for s in ["order", "cannon", "hoof", "dismount", "error"]:
			mgr.play(s)
		worst = maxi(worst, mgr._active_voices())
		await process_frame
	_check(worst <= mgr.MAX_VOICES + 3, "voces simultaneas acotadas (max visto %d)" % worst)
	_check((mgr._players["cannon"] as AudioStreamPlayer).max_polyphony == 2, "polifonia del canon = 2")
	mgr.set_environment("norte")
	await _wait(1.0, peaks)
	_check(mgr._ambient_players.size() == 2 and mgr._scenario == "norte", "norte arranca 2 capas")
	mgr.set_muted(true)
	await _wait(0.2, peaks)
	_check(mgr._active_voices() == 0, "silencio detiene efectos")
	mgr.set_muted(false)
	mgr.shutdown()
	mgr.queue_free()
	await process_frame
	await process_frame
	print("RESULTADO: %d comprobaciones, %d fallas" % [checks, failures])
	quit(1 if failures > 0 else 0)
