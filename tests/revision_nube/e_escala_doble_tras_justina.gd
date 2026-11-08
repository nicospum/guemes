extends SceneTree
## Revisión en la nube, lente E (interfaz y flujo). Hallazgo: la interfaz de Humahuaca sale un 25 % más grande (a 1280 × 720) si se viene de la Justina.
## main._menu() (l. 392-393) pone content_scale_factor = 1.0 ANTES de cambiar mode a "menu": ese cambio dispara size_changed → _fit_ui_scale (l. 379-388), que
## con mode == "play" y la Justina vigente vuelve a 1,25. El menú queda en 1,25; _start_humahuaca (l. 462-471) no lo normaliza y el controlador lo guarda y
## restaura tal cual (_remember_global_state, stop). humahuaca_ui_base._fit_scale (l. 548-565) supone que main lo deja en 1,0 (comentario l. 545-547) y suma su
## propio ui_scale = 1,25: la cabecera pasa de 57,5 a 71,9 px y el dock de 170 a 212 px reales. Esperado: la interfaz mide lo mismo por los dos caminos.
## godot --headless --path . --script tests/revision_nube/e_escala_doble_tras_justina.gd   (perfil user:// aislado). Sale con 1 si el defecto sigue.

const Fx = preload("res://tests/hx_fixtures.gd")
const Kit = preload("res://scripts/humahuaca/ui/humahuaca_ui_kit.gd")

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


func _check(ok: bool, text: String) -> void:
	print(("OK: " if ok else "FALLA: ") + text)
	if not ok:
		failures += 1


func _find_button(part: String) -> Button:
	for b in game.find_children("*", "Button", true, false):
		if str(b.text).find(part) >= 0 and (b as Button).is_visible_in_tree():
			return b
	return null


func _measure() -> Dictionary:
	var cs := game.get_window().content_scale_factor
	return {"content_scale": cs, "ui_scale": float(hx.ui_scale), "header_px": snappedf(Kit.rect_of(hx.hud.header).size.y * cs, 0.1), "dock_px": snappedf(Kit.rect_of(hx.hud.dock).size.y * cs, 0.1)}


func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	game = scene.instantiate()
	root.add_child(game)
	await _frames(4)
	game.jev.force_local = true
	game.settings.auto_pause = false
	game.forced_seed = 1806
	if is_instance_valid(game.audio_manager):
		game.audio_manager.set_muted(true)
	root.size = Vector2i(1280, 720)
	await _frames(6)
	game._menu()
	await _frames(4)
	game._start_humahuaca({"skip_intro": true})
	await _frames(6)
	hx = game.hx
	var direct := _measure()
	game._stop_humahuaca()
	await _frames(2)
	game._menu()
	await _frames(4)
	_find_button("EL RÍO OFRECE").pressed.emit()
	await _frames(6)
	game._menu()
	await _frames(6)
	var cs_menu := game.get_window().content_scale_factor
	game._start_humahuaca({"skip_intro": true})
	await _frames(6)
	hx = game.hx
	var after := _measure()
	print("directo: %s\ntras la Justina: %s (menú tras la Justina: content_scale %.2f)" % [str(direct), str(after), cs_menu])
	_check(is_equal_approx(float(after.content_scale), float(direct.content_scale)), "el nivel arranca con el mismo content_scale_factor por los dos caminos (%.2f directo, %.2f tras la Justina)" % [float(direct.content_scale), float(after.content_scale)])
	_check(absf(float(after.header_px) - float(direct.header_px)) <= 1.0, "la cabecera mide lo mismo en píxeles por los dos caminos (%.1f directo, %.1f tras la Justina)" % [float(direct.header_px), float(after.header_px)])
	_check(absf(float(after.dock_px) - float(direct.dock_px)) <= 1.0, "el dock mide lo mismo en píxeles por los dos caminos (%.1f directo, %.1f tras la Justina)" % [float(direct.dock_px), float(after.dock_px)])
	game._stop_humahuaca()
	await _frames(2)
	game.get_window().content_scale_factor = 1.0
	game.queue_free()
	await process_frame
	print("resultado: %d fallas" % failures)
	quit(1 if failures > 0 else 0)
