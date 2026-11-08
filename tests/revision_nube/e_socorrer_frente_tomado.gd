extends SceneTree
## Revisión en la nube, lente E (interfaz y flujo). Hallazgo: con el frente propio ya tomado, la tecla C y la barra de acciones niegan un socorro legítimo a otro frente.
## humahuaca_orders.availability (l. 119-126) pregunta a las reglas con el punto fijo (450, 325) para toda acción con destino; para «support» las reglas eligen el
## frente por ese punto (_front_from, humahuaca_rules.gd l. 1114-1129): está a 33,5 m del cuartel (front_pick_m = 60), así que la disponibilidad de «Socorrer» es siempre
## la del cuartel. Cuando el cuartel es el primer frente tomado y Portal lo sostiene, C (begin_aim l. 258-269) responde «Ese frente ya está tomado.» y bar_items (l. 71-100)
## esconde «Socorrer», aunque action_availability("portal", "support", posta, {front: posta}) devuelve ok. El clic derecho sobre el otro frente sí lo manda (context_order
## pasa el frente). Camino legítimo: fase ataque, Rodríguez cancela y Arias socorre al cuartel; el cuartel cae primero (semilla 7, ≈ 348 s).
## Esperado: C entra en modo apuntado (o la barra ofrece «Socorrer») cuando hay algún frente al que se puede socorrer.
## godot --headless --path . --script tests/revision_nube/e_socorrer_frente_tomado.gd   (perfil user:// aislado). Sale con 1 si el defecto sigue.

const Fx = preload("res://tests/hx_fixtures.gd")

var game: Node
var hx: Node
var failures := 0


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


func _key(code: int) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		root.push_input(e)
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
	root.size = Vector2i(1280, 720)
	await _frames(6)
	game._start_humahuaca({"skip_intro": true, "seed": 7, "phase": "ataque"})
	await _frames(4)
	hx = game.hx
	var r: Variant = hx.rules
	r.cancel_order("rodriguez")
	r.issue_order("arias", "support", hx.landmark_pos("cuartel"), {"front": "cuartel", "posture": "a_fondo"})
	var steps := 0
	var ready := false
	var other := ""
	while steps < 400 and str(hx.qa_state().status) == "playing" and not ready:
		hx.qa_step(1.0)
		steps += 1
		var fronts: Dictionary = hx.qa_state().front_states
		if str(fronts.get("cuartel", "")) == "tomado" and str(r.get_unit("portal").stage) in ["holding", "idle"]:
			for fid in ["posta", "bateria"]:
				if str(fronts.get(fid, "")) != "tomado" and bool(r.action_availability("portal", "support", hx.landmark_pos(fid), {"front": fid}).get("ok", false)):
					other = fid
			ready = other != ""
	_check(ready, "se llega al estado: cuartel tomado, Portal sosteniendo y otro frente al que las reglas dejan socorrer (a los %d s; frentes %s)" % [steps, str(hx.qa_state().front_states)])
	if ready:
		hx.select(["portal"], "replace")
		hx.set_motive("", false)
		hx.refresh_hud_now()
		var in_bar := hx.hud.action_button("support") != null
		await _key(KEY_C)
		await _frames(1)
		var aiming := bool(hx.qa_state().aiming)
		var motive := str(hx.qa_state().motive)
		_check(aiming or in_bar, "C con Portal (frente propio tomado) entra en modo apuntado de «Socorrer» hacia %s, o la barra lo ofrece (apuntando: %s; en la barra: %s; motivo: «%s»; las reglas al %s: ok)" % [other, str(aiming), str(in_bar), motive, other])
		hx.orders.cancel_aim()
		# dato: el clic derecho sobre ese frente sí manda el socorro (context_order pasa el frente)
		hx.qa_set_camera(hx.landmark_pos(other), 220.0, 50.0, 0.0)
		await _frames(2)
		var p: Vector2 = hx.landmark_pos(other)
		var screen: Vector2 = game.camera.unproject_position(Vector3(p.x, float(hx.ground_height(p.x, p.y)) + 2.0, p.y))
		var ok_rc: bool = hx.orders.context_order(screen, false, false, false)
		print("dato: clic derecho sobre %s con Portal elegido → orden dada: %s (frente bajo el cursor: «%s»)" % [other, str(ok_rc), str(hx.pick_front_at(screen))])
	game._stop_humahuaca()
	await _frames(2)
	game.queue_free()
	await process_frame
	print("resultado: %d fallas" % failures)
	quit(1 if failures > 0 else 0)
