extends Control
## Capa de dibujo 2D sobre el mundo 3D del nivel «humahuaca» (CONTRATO 3.5). Va DEBAJO de los paneles del HUD y no atrapa el mouse. Dibuja, con la
## cámara que se está mostrando: la ruta que se arma (con el color y el trazo del riesgo, y su texto junto al cursor), las rutas en marcha de la
## selección, la flecha del «siguiente paso» y el anillo de quien debe obedecerlo, los rótulos de los tres frentes (junto a cada uno, con el glifo de
## su etiqueta), el anillo de recarga de la torre y la caja de selección. No decide nada: lee el controlador (`ui`) y las reglas.
## El color nunca va solo: el riesgo también cambia el trazo (continuo, largo o corto) y se dice con palabras en el texto de la ruta.

const Kit = preload("res://scripts/humahuaca/ui/humahuaca_ui_kit.gd")
const V = preload("res://scripts/humahuaca/humahuaca_vocab.gd")

## El controlador. Se usa por nombre y sin tipar (esta clase no puede importar al controlador: la dependencia va hacia abajo).
var ui: Node = null
var enabled := true
var clock := 0.0
var drawn_text_chars := 0
var drawn_labels: Array = []  # [{text, rect}] del último cuadro (para las pruebas: ningún rótulo se pisa ni se sale)

var _font: Font = null
var _wait := 0.0


func _init() -> void:
	name = "HxOverlay"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	clock += delta
	_wait -= delta
	if not (enabled and visible):
		return
	# 30 Hz alcanza para la flecha que rebota y los rótulos; a 60 Hz solo mientras se apunta una orden o se arrastra una caja (el dibujo de texto es lo caro)
	var orders: Variant = ui.get("orders") if ui != null else null
	var live: bool = (orders != null and bool(orders.call("aiming"))) or (ui != null and (ui.get("box_rect") as Rect2).size.length() > 3.0)
	if live or _wait <= 0.0:
		_wait = 1.0 / 30.0
		queue_redraw()


# ---------------------------------------------------------------------------------------------------------------------
# Proyección

func _cam() -> Camera3D:
	return ui.call("camera3d") if ui != null else null


func _world_to_screen(cam: Camera3D, p: Vector2, lift: float = 0.0) -> Variant:
	var h := float(ui.call("ground_height", p.x, p.y))
	var v := Vector3(p.x, h + lift, p.y)
	if cam.is_position_behind(v):
		return null
	return cam.unproject_position(v) / maxf(float(ui.get("ui_scale")), 0.01)  # del cuadro a las coordenadas locales de la interfaz (que va escalada en ventanas chicas)


func _risk_color(risk: String) -> Color:
	match risk:
		"bajo":
			return Kit.GOOD
		"medio":
			return Kit.AMBER
		"alto":
			return Kit.RED
	return Kit.MUTED


func _dash_for(risk: String) -> Array:
	match risk:
		"medio":
			return [14.0, 8.0]
		"alto":
			return [5.0, 7.0]
	return []  # continuo


func _line(a: Vector2, b: Vector2, color: Color, width: float, dash: Array) -> void:
	if dash.is_empty():
		draw_line(a, b, color, width, true)
		return
	var total := a.distance_to(b)
	if total < 1.0:
		return
	var dir := (b - a) / total
	var at := 0.0
	var on := true
	var i := 0
	while at < total:
		var seg := minf(float(dash[i % dash.size()]), total - at)
		if on:
			draw_line(a + dir * at, a + dir * (at + seg), color, width, true)
		at += seg
		on = not on
		i += 1


func _text(pos: Vector2, text: String, font_px: int, color: Color, outline: bool = true) -> Rect2:
	if _font == null:
		_font = ui.call("font") if ui != null else ThemeDB.fallback_font
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px).x
	var rect := Rect2(pos - Vector2(0.0, float(font_px)), Vector2(w, float(font_px) + 4.0))
	if outline:  # una sombra corrida (barata) en vez del contorno de glifos, que es lo que más cuesta del dibujo
		draw_string(_font, pos + Vector2(1.5, 1.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px, Color(0.05, 0.07, 0.04, 0.95))
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px, color)
	drawn_text_chars += text.length()
	drawn_labels.append({"text": text, "rect": rect})
	return rect


func _pill(pos: Vector2, text: String, font_px: int, color: Color, border: Color) -> Rect2:
	if _font == null:
		_font = ui.call("font") if ui != null else ThemeDB.fallback_font
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px).x
	var rect := Rect2(pos, Vector2(w + 18.0, float(font_px) + 12.0))
	var view_rect := Rect2(Vector2.ZERO, size)
	rect.position.x = clampf(rect.position.x, 6.0, maxf(view_rect.size.x - rect.size.x - 6.0, 6.0))
	rect.position.y = clampf(rect.position.y, 6.0, maxf(view_rect.size.y - rect.size.y - 6.0, 6.0))
	draw_style_box(Kit.style(Color(0.075, 0.095, 0.062, 0.97), border, 1, 6, 0.0, 0.0), rect)
	draw_string(_font, rect.position + Vector2(9.0, float(font_px) + 3.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px, color)
	drawn_text_chars += text.length()
	drawn_labels.append({"text": text, "rect": rect})
	return rect


# ---------------------------------------------------------------------------------------------------------------------
# Dibujo

func _draw() -> void:
	drawn_text_chars = 0
	drawn_labels = []
	if ui == null or not enabled or ui.get("rules") == null:
		return
	var cam := _cam()
	if cam == null or not cam.is_inside_tree():
		return
	if bool(ui.get("hide_world_overlay")):
		return
	_draw_front_labels(cam)
	_draw_token_labels(cam)
	_draw_tower(cam)
	_draw_orders(cam)
	_draw_guide_arrow(cam)
	_draw_preview(cam)
	_draw_box()


func _draw_front_labels(cam: Camera3D) -> void:
	var tags: Dictionary = ui.get("source_tags")
	var rules: Variant = ui.get("rules")
	var placed: Array = []
	for fid in V.OBJECTIVES:
		var p: Vector2 = ui.call("landmark_pos", str(fid))
		var s: Variant = _world_to_screen(cam, p, 9.0)
		if not (s is Vector2):
			continue
		var info: Variant = ui.call("front_label", str(fid))
		if not (info is Dictionary) or str((info as Dictionary).get("text", "")) == "":
			continue
		var text: String = str((info as Dictionary).get("text", ""))
		var taken := bool((info as Dictionary).get("taken", false))
		var pos: Vector2 = (s as Vector2) + Vector2(-20.0, 26.0)
		var color := Kit.GOOD if taken else Kit.PAPER
		var rect := _text(pos, text, 14, color)
		for other in placed:
			if rect.intersects(other):
				rect = _text(pos + Vector2(0.0, -18.0), text, 14, color)
		placed.append(rect)
	if rules == null or tags.is_empty():
		return


## El número de cada agrupación (su tecla) junto a su ficha, encima de ella: lo dibuja la interfaz para que quede pegado a la figura y fuera del HUD.
func _draw_token_labels(cam: Camera3D) -> void:
	var rules: Variant = ui.get("rules")
	var rs: Variant = ui.call("render_state_cached")
	if not (rs is Dictionary):
		return
	var total_scale := maxf(float(ui.call("screen_scale")), 0.05)
	var fig_h := 62.0 / total_scale  # las fichas miden ≥ 48 px reales: el número va un poco más arriba de su cabeza
	var selected: Array = ui.get("selected")
	var local_rect := Rect2(Vector2.ZERO, size)
	var header_bottom := float(ui.call("layout_num", ["margin"], 12.0)) + float(ui.call("layout_num", ["header_h"], 46.0)) + 4.0
	for u in (rs as Dictionary).get("units", []):
		var d := u as Dictionary
		if str(d.get("stage", "")) == "exited":
			continue
		var id := str(d.get("id", ""))
		var base: Variant = _world_to_screen(cam, Vector2(float(d.get("x", 0.0)), float(d.get("z", 0.0))), 0.0)
		if not (base is Vector2):
			continue
		var center: Vector2 = (base as Vector2) + Vector2(0.0, -fig_h)
		center.y = maxf(center.y, header_bottom + 12.0)
		if not local_rect.grow(-6.0).has_point(center):
			center = Vector2(clampf(center.x, 14.0, size.x - 14.0), clampf(center.y, header_bottom + 12.0, size.y - 180.0))
		var is_sel := selected.has(id)
		var fill := Kit.NEUTRAL if id == "arreo" else Kit.PATRIOT
		draw_circle(center, 13.0, Color(0.05, 0.07, 0.04, 0.92))
		draw_arc(center, 13.0, 0.0, TAU, 28, Kit.GOLD if is_sel else fill, 3.0 if is_sel else 2.0, true)
		var label := str(V.GROUPS.find(id) + 1)
		if _font == null:
			_font = ui.call("font")
		var w := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string(_font, center + Vector2(-w * 0.5, 6.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Kit.PAPER)
		drawn_text_chars += label.length()
		drawn_labels.append({"text": label, "rect": Rect2(center - Vector2(13.0, 13.0), Vector2(26.0, 26.0))})


func _draw_orders(cam: Camera3D) -> void:
	var rules: Variant = ui.get("rules")
	for id in ui.get("selected"):
		var u: Variant = rules.call("get_unit", str(id))
		if not (u is Dictionary):
			continue
		var path: Variant = (u as Dictionary).get("path", [])
		if not (path is Array) or (path as Array).is_empty():
			continue
		var prev: Variant = _world_to_screen(cam, Vector2(float((u as Dictionary).get("x", 0.0)), float((u as Dictionary).get("z", 0.0))), 1.0)
		for q in path:
			var cur: Variant = _world_to_screen(cam, Vector2(float((q as Dictionary).get("x", 0.0)), float((q as Dictionary).get("z", 0.0))), 1.0)
			if prev is Vector2 and cur is Vector2:
				_line(prev, cur, Color(Kit.PAPER.r, Kit.PAPER.g, Kit.PAPER.b, 0.75), 2.0, [10.0, 7.0])
			prev = cur
		if prev is Vector2:
			draw_circle(prev, 4.0, Kit.GOLD)


func _draw_guide_arrow(cam: Camera3D) -> void:
	var guide: Variant = ui.get("guide")
	if not (guide is Dictionary) or not bool((guide as Dictionary).get("arrow", false)):
		return
	var rules: Variant = ui.get("rules")
	var tp: Variant = (guide as Dictionary).get("target", null)
	var actor := str((guide as Dictionary).get("actor", ""))
	var world := Vector2.ZERO
	var have := false
	if tp is Vector2 and tp != Vector2.ZERO:
		world = tp
		have = true
	elif actor != "":
		var u: Variant = rules.call("get_unit", actor)
		if u is Dictionary:
			world = Vector2(float((u as Dictionary).get("x", 0.0)), float((u as Dictionary).get("z", 0.0)))
			have = true
	if not have:
		return
	var bob := sin(clock * 4.5) * 6.0
	var s: Variant = _world_to_screen(cam, world, 8.0)
	var view := Rect2(Vector2.ZERO, size)
	if s is Vector2 and view.grow(-30.0).has_point(s as Vector2):
		var tip: Vector2 = (s as Vector2) + Vector2(0.0, -16.0 + bob)
		_arrow(tip, Vector2(0.0, 1.0))
	else:
		var center := view.size * 0.5
		var dir := Vector2(0.0, -1.0)
		var to: Variant = _world_to_screen(cam, world, 8.0)
		if to is Vector2:
			dir = ((to as Vector2) - center).normalized()
		else:
			var anywhere := cam.unproject_position(Vector3(world.x, 17.0, world.y)) / maxf(float(ui.get("ui_scale")), 0.01)
			dir = (center - anywhere).normalized()
		var edge := center + dir * minf(view.size.x, view.size.y) * 0.42
		edge.x = clampf(edge.x, 40.0, view.size.x - 40.0)
		edge.y = clampf(edge.y, 150.0, view.size.y - 230.0)
		_arrow(edge, dir)
	# el anillo de quien debe obedecer
	if actor != "":
		var u2: Variant = rules.call("get_unit", actor)
		if u2 is Dictionary:
			var su: Variant = _world_to_screen(cam, Vector2(float((u2 as Dictionary).get("x", 0.0)), float((u2 as Dictionary).get("z", 0.0))), 1.5)
			if su is Vector2:
				var pulse := 22.0 + sin(clock * 5.0) * 3.0
				draw_arc(su as Vector2, pulse, 0.0, TAU, 32, Kit.GOLD, 3.0, true)


## Una flecha con la punta en `tip` apuntando hacia `dir`.
func _arrow(tip: Vector2, dir: Vector2) -> void:
	var back := -dir
	var side := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array([tip, tip + back * 20.0 + side * 12.0, tip + back * 14.0, tip + back * 20.0 - side * 12.0])
	draw_colored_polygon(pts, Kit.GOLD)
	var outline := PackedVector2Array([tip, tip + back * 20.0 + side * 12.0, tip + back * 14.0, tip + back * 20.0 - side * 12.0, tip])
	draw_polyline(outline, Color(0.05, 0.07, 0.04, 0.95), 2.0, true)


func _draw_preview(cam: Camera3D) -> void:
	var orders: Variant = ui.get("orders")
	if orders == null or not bool(orders.call("aiming")):
		return
	var pts: Array = orders.call("preview_points")
	var plan: Dictionary = orders.get("plan")
	var risk := str(plan.get("risk", "bajo")) if bool(plan.get("ok", false)) else "desconocido"
	var action := str((orders.get("aim") as Dictionary).get("action", ""))
	var color := _risk_color(risk) if action != "recon" else Kit.GOLD
	var dash: Array = _dash_for(risk) if action != "recon" else [8.0, 6.0]
	var prev: Variant = null
	var last: Variant = null
	for q in pts:
		var s: Variant = _world_to_screen(cam, q as Vector2, 1.0)
		if prev is Vector2 and s is Vector2:
			_line(prev, s, color, 3.0, dash)
		if s is Vector2:
			last = s
		prev = s
	for w in orders.get("waypoints"):
		var sw: Variant = _world_to_screen(cam, w as Vector2, 1.0)
		if sw is Vector2:
			draw_circle(sw as Vector2, 5.0, color)
			draw_arc(sw as Vector2, 8.0, 0.0, TAU, 20, Kit.PAPER, 1.5, true)
	if bool(orders.get("has_target")) and last is Vector2:
		draw_circle(last as Vector2, 6.0, color)
		draw_arc(last as Vector2, 10.0, 0.0, TAU, 24, Kit.PAPER, 2.0, true)
		var text := str(orders.call("preview_text", action))
		if text != "":
			_pill((last as Vector2) + Vector2(16.0, 14.0), text, 14, Kit.PAPER, color)
	elif action == "support" and str(orders.get("front_hover")) != "":
		var sf: Variant = _world_to_screen(cam, orders.get("target_now") as Vector2, 6.0)
		if sf is Vector2:
			draw_arc(sf as Vector2, 20.0, 0.0, TAU, 28, Kit.GOLD, 3.0, true)


func _draw_tower(cam: Camera3D) -> void:
	var tower: Variant = ui.call("tower_state")
	if not (tower is Dictionary) or (tower as Dictionary).is_empty():
		return
	var d: Dictionary = tower
	var s: Variant = _world_to_screen(cam, Vector2(float(d.get("x", 0.0)), float(d.get("z", 0.0))), 14.0)
	if not (s is Vector2):
		return
	var period := maxf(float(d.get("period_s", 7.5)), 0.1)
	var left := clampf(float(d.get("next_volley_in_s", 0.0)), 0.0, period)
	var firing := bool(d.get("firing", false))
	if not firing:
		return
	var frac := 1.0 - left / period
	draw_arc(s as Vector2, 20.0, 0.0, TAU, 32, Color(0.2, 0.23, 0.17, 0.9), 5.0, true)
	draw_arc(s as Vector2, 20.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 32, Kit.RED, 5.0, true)
	_text((s as Vector2) + Vector2(-8.0, 5.0), "%d" % int(ceil(left)), 14, Kit.PAPER)


func _draw_box() -> void:
	var r: Variant = ui.get("box_rect")
	if r is Rect2 and (r as Rect2).size.length() > 3.0:
		var k := maxf(float(ui.get("ui_scale")), 0.01)
		var local := Rect2((r as Rect2).position / k, (r as Rect2).size / k)
		draw_rect(local, Color(Kit.GOLD.r, Kit.GOLD.g, Kit.GOLD.b, 0.14), true)
		draw_rect(local, Kit.GOLD, false, 1.5)
