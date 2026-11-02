extends Control
## Minimapa del nivel «humahuaca» (CONTRATO 3.5): el relieve que arma la vista (norte arriba, sin unidades) con las agrupaciones, los tres frentes,
## el cuadro de la cámara, la brújula (la N gira con la guiñada) y la escala gráfica de la vista. Un clic o un arrastre mueve la cámara. M lo agranda.
## Cada agrupación se distingue por la forma y no solo por el color: las partidas y la reserva son círculos, los reconocedores triángulos y el arreo
## un cuadrado. No decide nada: lee el controlador (`ui`).

const Kit = preload("res://scripts/humahuaca/ui/humahuaca_ui_kit.gd")
const V = preload("res://scripts/humahuaca/humahuaca_vocab.gd")

var ui: Node = null
var cfg: Dictionary = {}
var large := false
var drawn_text_chars := 0

var _tex: Texture2D = null
var _tex_key := ""
var _tex_age := 99.0
var _dragging := false
var _font: Font = null
var _redraw_wait := 0.0
var _frustum: PackedVector2Array = PackedVector2Array()


func _init() -> void:
	name = "HxMinimap"
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_CROSS


func setup(controller: Node, config: Dictionary, font_in: Font) -> void:
	ui = controller
	cfg = config
	_font = font_in
	apply_size()


func box_size() -> Vector2:
	var key := "large_size_px" if large else "default_size_px"
	var v: Variant = cfg.get(key, [260, 188])
	if v is Array and (v as Array).size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	return Vector2(260.0, 188.0)


func apply_size() -> void:
	var m := float(ui.call("margin")) if ui != null else 12.0
	var s := box_size()
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -(m + s.x)
	offset_right = -m
	offset_top = -(m + s.y)
	offset_bottom = -m
	custom_minimum_size = s
	_tex_key = ""
	queue_redraw()


func set_large(on: bool) -> void:
	large = on
	apply_size()


func _color(key: String, fallback: Color) -> Color:
	var colors: Variant = cfg.get("colors", {})
	if colors is Dictionary and (colors as Dictionary).has(key):
		return Color(str((colors as Dictionary)[key]))
	return fallback


func _process(delta: float) -> void:
	_tex_age += delta
	_redraw_wait -= delta
	if visible and ui != null and ui.get("rules") != null and _redraw_wait <= 0.0:
		_redraw_wait = 0.1  # el minimapa se redibuja a 10 Hz: no hace falta más y el cuadro del tablero no lo paga
		queue_redraw()


func _to_map(p: Vector2) -> Vector2:
	var s := size
	var view: Variant = ui.get("view")
	if view != null and view.has_method("world_to_map"):
		var uv: Vector2 = view.call("world_to_map", p)
		return Vector2(uv.x * s.x, uv.y * s.y)
	return Vector2(p.x / 900.0 * s.x, p.y / 650.0 * s.y)


func _to_world(pos: Vector2) -> Vector2:
	var s := size
	var uv := Vector2(clampf(pos.x / maxf(s.x, 1.0), 0.0, 1.0), clampf(pos.y / maxf(s.y, 1.0), 0.0, 1.0))
	var view: Variant = ui.get("view")
	if view != null and view.has_method("map_to_world"):
		return view.call("map_to_world", uv)
	return Vector2(uv.x * 900.0, uv.y * 650.0)


func _texture() -> Texture2D:
	var view: Variant = ui.get("view")
	if view == null or not view.has_method("get_minimap_texture"):
		return null
	var key := "%dx%d" % [int(size.x), int(size.y)]
	if _tex == null or key != _tex_key or _tex_age >= float(cfg.get("refresh_s", 2)):
		var t: Variant = view.call("get_minimap_texture", Vector2i(int(size.x), int(size.y)))
		if t is Texture2D:
			_tex = t
		_tex_key = key
		_tex_age = 0.0
	return _tex


func _draw() -> void:
	drawn_text_chars = 0
	if ui == null or ui.get("rules") == null:
		return
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, _color("back", Kit.INK), true)
	var tex := _texture()
	if tex != null:
		draw_texture_rect(tex, rect, false)
	draw_rect(rect, _color("border", Kit.PANEL_BORDER), false, 2.0)
	_draw_fronts()
	_draw_frustum()
	_draw_units()
	_draw_compass()
	_draw_scale()


func _draw_fronts() -> void:
	var rules: Variant = ui.get("rules")
	var rs: Variant = rules.call("render_state")
	if not (rs is Dictionary):
		return
	for o in (rs as Dictionary).get("objectives", []):
		var d := o as Dictionary
		var p := _to_map(Vector2(float(d.get("x", 0.0)), float(d.get("z", 0.0))))
		var taken := str(d.get("state", "")) == "tomado"
		var col := _color("front_taken", Kit.GOOD) if taken else _color("front", Kit.ROYAL)
		draw_rect(Rect2(p - Vector2(4.0, 4.0), Vector2(8.0, 8.0)), col, true)
		draw_rect(Rect2(p - Vector2(4.0, 4.0), Vector2(8.0, 8.0)), Kit.ROYAL_BORDER, false, 1.5)


func _draw_frustum() -> void:
	var view: Variant = ui.get("view")
	var cam: Camera3D = ui.call("camera3d")
	if view == null or cam == null or not view.has_method("camera_frustum_on_ground"):
		return
	var poly: Variant = view.call("camera_frustum_on_ground", cam)
	if not (poly is PackedVector2Array) or (poly as PackedVector2Array).size() < 3:
		return
	var pts := PackedVector2Array()
	for q in poly:
		var m := _to_map(q as Vector2)
		pts.append(Vector2(clampf(m.x, 0.0, size.x), clampf(m.y, 0.0, size.y)))
	pts.append(pts[0])
	draw_polyline(pts, _color("frame", Kit.PAPER), 1.5, true)


func _draw_units() -> void:
	var rules: Variant = ui.get("rules")
	var rs: Variant = rules.call("render_state")
	if not (rs is Dictionary):
		return
	var selected: Array = ui.get("selected")
	for u in (rs as Dictionary).get("units", []):
		var d := u as Dictionary
		var id := str(d.get("id", ""))
		if str(d.get("stage", "")) == "exited":
			continue
		var p := _to_map(Vector2(float(d.get("x", 0.0)), float(d.get("z", 0.0))))
		var is_sel := selected.has(id)
		var fill := _color("arreo", Kit.NEUTRAL) if id == "arreo" else _color("unit", Kit.PATRIOT)
		var border := _color("selected", Kit.GOLD) if is_sel else _color("unit_border", Kit.PATRIOT_BORDER)
		match str(d.get("kind", "")):
			"arreo":
				draw_rect(Rect2(p - Vector2(4.5, 4.5), Vector2(9.0, 9.0)), fill, true)
				draw_rect(Rect2(p - Vector2(4.5, 4.5), Vector2(9.0, 9.0)), border, false, 2.0 if is_sel else 1.2)
			"reconocedores":
				var tri := PackedVector2Array([p + Vector2(0.0, -5.5), p + Vector2(5.0, 4.0), p + Vector2(-5.0, 4.0)])
				draw_colored_polygon(tri, fill)
				draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), border, 2.0 if is_sel else 1.2, true)
			_:
				draw_circle(p, 5.0, fill)
				draw_arc(p, 5.0, 0.0, TAU, 16, border, 2.0 if is_sel else 1.2, true)


func _draw_compass() -> void:
	var cam_yaw := float(ui.call("camera_yaw_deg"))
	var center := Vector2(size.x - 22.0, 24.0)
	draw_circle(center, 15.0, Color(0.075, 0.095, 0.062, 0.85))
	draw_arc(center, 15.0, 0.0, TAU, 24, _color("border", Kit.PANEL_BORDER), 1.2, true)
	var a := deg_to_rad(-cam_yaw)  # el norte queda a −guiñada respecto de «arriba» de la pantalla
	var dir := Vector2(sin(a), -cos(a))
	draw_line(center - dir * 6.0, center + dir * 9.0, Kit.ROYAL, 2.0, true)
	var font := _font if _font != null else ThemeDB.fallback_font
	var tp := center + dir * 8.0 - Vector2(4.0, -4.0)
	draw_string_outline(font, tp, "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color(0.05, 0.07, 0.04, 0.95))
	draw_string(font, tp, "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Kit.PAPER)
	drawn_text_chars += 1


func _draw_scale() -> void:
	var view: Variant = ui.get("view")
	var cam: Camera3D = ui.call("camera3d")
	if view == null or cam == null or not view.has_method("meters_per_pixel"):
		return
	var mpp := float(view.call("meters_per_pixel", cam))
	if mpp <= 0.0:
		return
	var steps: Variant = cfg.get("scale_steps_m", [50, 100, 200, 500])
	var chosen := float((steps as Array)[0]) if steps is Array and not (steps as Array).is_empty() else 50.0
	for s in steps:
		if float(s) / mpp / maxf(float(ui.get("ui_scale")), 0.01) <= 100.0:
			chosen = float(s)
	var px := minf(chosen / mpp / maxf(float(ui.get("ui_scale")), 0.01), 120.0)  # la escala es la de la vista 3D, en píxeles lógicos del lienzo (los mismos que usa meters_per_pixel)
	var y := size.y - 16.0
	var x0 := 10.0
	draw_line(Vector2(x0, y), Vector2(x0 + px, y), Color(0.05, 0.07, 0.04, 0.95), 5.0)
	draw_line(Vector2(x0, y), Vector2(x0 + px, y), Kit.PAPER, 2.5)
	draw_line(Vector2(x0, y - 4.0), Vector2(x0, y + 4.0), Kit.PAPER, 2.0)
	draw_line(Vector2(x0 + px, y - 4.0), Vector2(x0 + px, y + 4.0), Kit.PAPER, 2.0)
	var font := _font if _font != null else ThemeDB.fallback_font
	var label := "%d m" % int(chosen)
	draw_string_outline(font, Vector2(x0 + px + 6.0, y + 4.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color(0.05, 0.07, 0.04, 0.95))
	draw_string(font, Vector2(x0 + px + 6.0, y + 4.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Kit.PAPER)
	drawn_text_chars += label.length()


func _gui_input(event: InputEvent) -> void:
	if ui == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
			if mb.pressed:
				ui.call("minimap_click", _to_world(mb.position))
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		ui.call("minimap_click", _to_world((event as InputEventMouseMotion).position))
		accept_event()
