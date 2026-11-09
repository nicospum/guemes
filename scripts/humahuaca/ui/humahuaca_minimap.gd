extends Control
## Minimapa del nivel «humahuaca» (CONTRATO 3.5): el relieve que arma la vista (norte arriba, sin unidades) con las agrupaciones, los tres frentes,
## el cuadro de la cámara, la brújula (la N gira con la guiñada) y la escala gráfica DEL MINIMAPA (Q-209), las parcelas regadas como sembrados y los frentes como rombos (Q-204). Un clic o un arrastre mueve la cámara. M lo agranda.
## Cada agrupación se distingue por la forma y no solo por el color: las partidas y la reserva son círculos, los reconocedores triángulos y el arreo
## un cuadrado. No decide nada: lee el controlador (`ui`).
## Paleta nocturna (V-06): el relieve que entrega la vista es diurno (beige); acá se lo pasa por un sombreador que lo lleva a tinta violácea con los trazos claros
## (calles, casas) en oro, coherente con la noche de la escena. Tres capas: el fondo (este nodo), la textura con el sombreador y la tinta (fichas, frentes, cuadro de
## la cámara, brújula y escala), que se dibuja encima.
## Costo (revisión G-2): el polígono de la cámara sobre el relieve y los metros por píxel se guardan por pose de cámara, campo visual y tamaño del cuadro (con la cámara
## quieta un redibujo no vuelve a muestrear el relieve), y fichas y frentes salen de render_state_cached() del controlador (un solo pedido por redibujo).

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
var _cam_sig := ""  # pose de la cámara, campo visual y tamaño del cuadro con los que se calcularon _frustum y _mpp
var _mpp := -1.0
var _tex_rect: TextureRect = null
var _ink: Control = null
const NIGHT_SHADER := "shader_type canvas_item;
uniform vec4 low : source_color = vec4(0.07, 0.06, 0.09, 1.0);
uniform vec4 high : source_color = vec4(0.165, 0.141, 0.188, 1.0);
uniform vec4 line : source_color = vec4(0.788, 0.635, 0.369, 1.0);
uniform float strength = 1.0;
uniform float line_gain = 0.55;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 night = mix(low.rgb, high.rgb, smoothstep(0.12, 0.80, l));
	night += (c.rgb - vec3(l)) * 0.45;
	night = mix(night, line.rgb, smoothstep(0.70, 0.92, l) * line_gain);
	COLOR = vec4(mix(c.rgb, night, strength), c.a);
}
"


func _init() -> void:
	name = "HxMinimap"
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_CROSS


func setup(controller: Node, config: Dictionary, font_in: Font) -> void:
	ui = controller
	cfg = config
	_font = font_in
	_tex_rect = TextureRect.new()
	_tex_rect.name = "HxMinimapRelief"
	_tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sh := Shader.new()
	sh.code = NIGHT_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("low", _color("night_low", Color("120f17")))
	mat.set_shader_parameter("high", _color("night_high", Color("2a2430")))
	mat.set_shader_parameter("line", _color("night_line", Kit.GOLD))
	var night: Variant = cfg.get("night", {})
	mat.set_shader_parameter("strength", float((night as Dictionary).get("strength", 1.0)) if night is Dictionary else 1.0)
	mat.set_shader_parameter("line_gain", float((night as Dictionary).get("line_gain", 0.55)) if night is Dictionary else 0.55)
	_tex_rect.material = mat
	add_child(_tex_rect)
	var rules_json: Variant = V.load_json(V.RULES_PATH)
	if rules_json is Dictionary and (rules_json as Dictionary).get("time", null) is Dictionary:
		_times = (rules_json as Dictionary).time
	_ink = Control.new()
	_ink.name = "HxMinimapInk"
	_ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ink.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ink.draw.connect(_draw_ink)
	add_child(_ink)
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
	_cam_sig = ""
	queue_redraw()
	if _ink != null:
		_ink.queue_redraw()


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
		if _ink != null:
			_ink.queue_redraw()


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
	if ui == null or ui.get("rules") == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), _color("back", Kit.INK), true)
	var tex := _texture()
	if _tex_rect != null and _tex_rect.texture != tex:
		_tex_rect.texture = tex


## La tinta: todo lo que va encima del relieve. Un solo render_state por redibujo (el del controlador, que lo guarda 50 ms).
func _draw_ink() -> void:
	drawn_text_chars = 0
	if ui == null or ui.get("rules") == null:
		return
	_ink.draw_rect(Rect2(Vector2.ZERO, size), _color("border", Kit.PANEL_BORDER), false, 2.0)
	var rs: Variant = ui.call("render_state_cached") if ui.has_method("render_state_cached") else ui.get("rules").call("render_state")
	var rsd: Dictionary = rs if rs is Dictionary else {}
	_update_camera_cache()
	_update_night()
	_draw_parcels()
	_draw_fronts(rsd)
	_draw_frustum()
	_draw_units(rsd)
	_draw_compass()
	_draw_scale()


## Recalcula el polígono de la cámara y los metros por píxel solo si cambió la pose, el campo visual, el tamaño del cuadro o la escala de la interfaz.
func _update_camera_cache() -> void:
	var view: Variant = ui.get("view")
	var cam: Camera3D = ui.call("camera3d")
	if view == null or cam == null:
		_frustum = PackedVector2Array()
		_mpp = -1.0
		_cam_sig = ""
		return
	var sig := "%s|%s|%s|%s" % [str(cam.global_transform), str(cam.fov), str(cam.get_viewport().get_visible_rect().size), str(ui.get("ui_scale"))]
	if sig == _cam_sig:
		return
	_cam_sig = sig
	_frustum = PackedVector2Array()
	if view.has_method("camera_frustum_on_ground"):
		var poly: Variant = view.call("camera_frustum_on_ground", cam)
		if poly is PackedVector2Array:
			_frustum = poly
	_mpp = float(view.call("meters_per_pixel", cam)) if view.has_method("meters_per_pixel") else -1.0


func _draw_fronts(rs: Dictionary) -> void:
	for o in rs.get("objectives", []):
		var d := o as Dictionary
		var p := _to_map(Vector2(float(d.get("x", 0.0)), float(d.get("z", 0.0))))
		var taken := str(d.get("state", "")) == "tomado"
		var col := _color("front_taken", Kit.GOOD) if taken else _color("front", Kit.ROYAL)
		# Q-204: los frentes son rombos con borde de oro (antes cuadrados de 8 px, la misma forma que las parcelas regadas en el relieve)
		var dia := PackedVector2Array([p + Vector2(0.0, -6.5), p + Vector2(6.5, 0.0), p + Vector2(0.0, 6.5), p + Vector2(-6.5, 0.0)])
		_ink.draw_colored_polygon(dia, col)
		_ink.draw_polyline(PackedVector2Array([dia[0], dia[1], dia[2], dia[3], dia[0]]), _color("front_ring", Kit.GOLD), 1.6, true)


func _draw_frustum() -> void:
	if _frustum.size() < 3:
		return
	var pts := PackedVector2Array()
	for q in _frustum:
		var m := _to_map(q as Vector2)
		pts.append(Vector2(clampf(m.x, 0.0, size.x), clampf(m.y, 0.0, size.y)))
	pts.append(pts[0])
	_ink.draw_polyline(pts, _color("frame", Kit.PAPER), 1.5, true)


func _draw_units(rs: Dictionary) -> void:
	var selected: Array = ui.get("selected")
	for u in rs.get("units", []):
		var d := u as Dictionary
		var id := str(d.get("id", ""))
		if str(d.get("stage", "")) == "exited":
			continue
		var p := _to_map(Vector2(float(d.get("x", 0.0)), float(d.get("z", 0.0))))
		var is_sel := selected.has(id)
		var fill := _color("arreo", Kit.NEUTRAL) if id == "arreo" else _color("unit", Kit.PATRIOT)
		var border := _color("selected", Kit.GOLD) if is_sel else _color("unit_border", Kit.PATRIOT_BORDER)
		if id == "arreo" and not is_sel:
			border = Kit.NEUTRAL_BORDER
		match str(d.get("kind", "")):
			"arreo":
				_ink.draw_rect(Rect2(p - Vector2(4.5, 4.5), Vector2(9.0, 9.0)), fill, true)
				_ink.draw_rect(Rect2(p - Vector2(4.5, 4.5), Vector2(9.0, 9.0)), border, false, 2.0 if is_sel else 1.2)
			"reconocedores":
				var tri := PackedVector2Array([p + Vector2(0.0, -5.5), p + Vector2(5.0, 4.0), p + Vector2(-5.0, 4.0)])
				_ink.draw_colored_polygon(tri, fill)
				_ink.draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), border, 2.0 if is_sel else 1.2, true)
			_:
				_ink.draw_circle(p, 5.0, fill)
				_ink.draw_arc(p, 5.0, 0.0, TAU, 16, border, 2.0 if is_sel else 1.2, true)
		if is_sel:  # elegida: halo violeta (regla de color 2)
			_ink.draw_arc(p, 8.0, 0.0, TAU, 20, Color(Kit.VIOLET, 0.85), 1.5, true)


func _draw_compass() -> void:
	var cam_yaw := float(ui.call("camera_yaw_deg"))
	var center := Vector2(size.x - 22.0, 24.0)
	_ink.draw_circle(center, 15.0, Color(Kit.INK_PANEL, 0.9))
	_ink.draw_arc(center, 15.0, 0.0, TAU, 24, Kit.GOLD, 1.2, true)
	var a := deg_to_rad(-cam_yaw)  # el norte queda a −guiñada respecto de «arriba» de la pantalla
	var dir := Vector2(sin(a), -cos(a))
	_ink.draw_line(center - dir * 6.0, center + dir * 9.0, Kit.GOLD_LIGHT, 2.0, true)
	var font := _font if _font != null else ThemeDB.fallback_font
	var tp := center + dir * 8.0 - Vector2(4.0, -4.0)
	_ink.draw_string_outline(font, tp, "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color(Kit.INK_NIGHT, 0.95))
	_ink.draw_string(font, tp, "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Kit.PAPER)
	drawn_text_chars += 1


## Q-209 (QA ronda 2): la barra decía «50 m» con la escala de la VISTA 3D (metros por píxel de la cámara) dibujada sobre el minimapa, donde esa barra medía unos 300 m.
## Ahora mide el minimapa: los metros por píxel salen de world_to_map (lo que ocupa el mapa entero en el recuadro) y se elige el tramo redondo que entra en ≤ 90 px.
func minimap_m_per_px() -> float:
	var a := _to_map(Vector2(0.0, 0.0))
	var b := _to_map(Vector2(100.0, 0.0))
	var px := a.distance_to(b)
	return 100.0 / px if px > 0.001 else -1.0


func scale_bar() -> Dictionary:
	var mpp := minimap_m_per_px()
	if mpp <= 0.0:
		return {}
	var steps: Variant = cfg.get("scale_steps_m", [50, 100, 200, 500])
	var chosen := float((steps as Array)[0]) if steps is Array and not (steps as Array).is_empty() else 50.0
	for st in steps:
		if float(st) / mpp <= 90.0:
			chosen = float(st)
	return {"m": chosen, "px": chosen / mpp, "m_por_px": mpp}


func _draw_scale() -> void:
	var bar := scale_bar()
	if bar.is_empty():
		return
	var chosen := float(bar.m)
	var px := float(bar.px)
	var y := size.y - 16.0
	var x0 := 10.0
	var shade := Color(Kit.INK_NIGHT, 0.95)
	_ink.draw_line(Vector2(x0, y), Vector2(x0 + px, y), shade, 5.0)
	_ink.draw_line(Vector2(x0, y), Vector2(x0 + px, y), Kit.PAPER, 2.5)
	_ink.draw_line(Vector2(x0, y - 4.0), Vector2(x0, y + 4.0), Kit.PAPER, 2.0)
	_ink.draw_line(Vector2(x0 + px, y - 4.0), Vector2(x0 + px, y + 4.0), Kit.PAPER, 2.0)
	var font := _font if _font != null else ThemeDB.fallback_font
	var label := "%d m" % int(chosen)
	_ink.draw_string_outline(font, Vector2(x0 + px + 6.0, y + 4.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, shade)
	_ink.draw_string(font, Vector2(x0 + px + 6.0, y + 4.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Kit.PAPER)
	drawn_text_chars += label.length()


## Q-204: las parcelas regadas en el minimapa son sembrados (relleno verde claro translúcido con hileras y borde punteado), no cuadrados oscuros como los marcadores.
var _parcel_polys: Array = []
var _parcel_key := ""

func _draw_parcels() -> void:
	var view: Variant = ui.get("view")
	if view == null or not view.has_method("parcel_polys"):
		return
	var key := "%dx%d" % [int(size.x), int(size.y)]
	if key != _parcel_key:
		_parcel_key = key
		_parcel_polys = []
		for poly in view.call("parcel_polys"):
			var mp := PackedVector2Array()
			for q in poly:
				mp.append(_to_map(q as Vector2))
			_parcel_polys.append(mp)
	var fill := _color("parcel", Color("8FA35E"))
	var rows := _color("parcel_rows", Color("C9C27E"))
	for mp in _parcel_polys:
		var poly := mp as PackedVector2Array
		if poly.size() < 3:
			continue
		_ink.draw_colored_polygon(poly, Color(fill, 0.42))
		var bb := Rect2(poly[0], Vector2.ZERO)
		for q in poly:
			bb = bb.expand(q)
		var y := bb.position.y + 1.5
		while y < bb.end.y - 0.5:
			_ink.draw_line(Vector2(bb.position.x + 1.0, y), Vector2(bb.end.x - 1.0, y), Color(rows, 0.75), 1.0)
			y += 2.5
		_ink.draw_dashed_line(Vector2(bb.position.x, bb.position.y), Vector2(bb.end.x, bb.position.y), Color(_color("parcel_water", Color("9CC3C9")), 0.95), 1.2, 2.0)
		_ink.draw_dashed_line(Vector2(bb.position.x, bb.position.y), Vector2(bb.position.x, bb.end.y), Color(_color("parcel_water", Color("9CC3C9")), 0.95), 1.2, 2.0)


## Q-210: el relieve se pasaba siempre a la tinta nocturna, también de día (minimapa de noche sobre la escena de mañana). La fuerza de la tinta sigue a la hora:
## entera de noche, se aclara del alba al día (`night.day_strength` de día).
var night_k := 1.0

func _update_night() -> void:
	if _tex_rect == null or not (_tex_rect.material is ShaderMaterial):
		return
	var night: Variant = cfg.get("night", {})
	var full := float((night as Dictionary).get("strength", 1.0)) if night is Dictionary else 1.0
	var day := float((night as Dictionary).get("day_strength", 0.25)) if night is Dictionary else 0.25
	var k := 1.0
	var r: Variant = ui.get("rules")
	if r != null and r.has_method("light_k"):
		k = 1.0 - clampf(float(r.call("light_k")), 0.0, 1.0)
	elif r != null and (r.get("state") is Dictionary) and not (r.get("state") as Dictionary).is_empty():
		var t := float((r.get("state") as Dictionary).get("elapsed", 0.0))
		k = 1.0 - smoothstep(float(_times.get("alba_start_s", 270.0)), float(_times.get("day_full_s", 420.0)), t)
	night_k = k
	(_tex_rect.material as ShaderMaterial).set_shader_parameter("strength", lerpf(day, full, k))


var _times: Dictionary = {}


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
