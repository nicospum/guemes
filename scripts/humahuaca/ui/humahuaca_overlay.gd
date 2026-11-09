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


func _world_to_screen(_cam_unused: Camera3D, p: Vector2, lift: float = 0.0) -> Variant:
	return ui.call("ui_point", p, lift)  # del mundo a las coordenadas locales de la interfaz (que va escalada en ventanas chicas)


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
	_draw_thing_marks(cam)  # visual/r1 F3
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
	var tokens := _token_rects(cam)
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
		var color := Kit.GOOD if taken else Kit.PAPER
		# Q-210 (QA ronda 2): el rótulo del frente iba siempre debajo del hito y se encimaba con las fichas paradas ahí («Batería» sobre la 3 y la 4); ahora prueba
		# debajo, más abajo, a la izquierda y a la derecha, y usa el primer lugar que no pisa una ficha (ni su número) ni otro rótulo
		var w := _text_w(text, 14)
		var cands: Array = [Vector2(-20.0, 26.0), Vector2(-20.0, 54.0), Vector2(-w - 30.0, 6.0), Vector2(30.0, 6.0), Vector2(-w * 0.5, 80.0)]
		var pos: Vector2 = (s as Vector2) + (cands[0] as Vector2)
		for c in cands:
			var try_pos: Vector2 = (s as Vector2) + (c as Vector2)
			var r := Rect2(try_pos - Vector2(0.0, 14.0), Vector2(w, 18.0)).grow(2.0)
			var hit := false
			for o in tokens + placed:
				if r.intersects(o as Rect2):
					hit = true
					break
			if not hit:
				pos = try_pos
				break
		var rect := _text(pos, text, 14, color)
		placed.append(rect)
	if rules == null or tags.is_empty():
		return


func _text_w(text: String, font_px: int) -> float:
	if _font == null:
		_font = ui.call("font") if ui != null else ThemeDB.fallback_font
	return _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px).x


## visual/r1 F1: la marca de cada agrupación en pantalla. Las fichas van a escala real (de lejos miden pocos píxeles), así que se las encuentra por una marca CHICA
## (un punto de 14 px reales con filete oscuro, sobre la cabeza) y un rótulo de una línea al lado («1  Rodríguez»). Antes era un círculo de 26 px con el número,
## 85 px por encima del pie de una figura estirada. Marca: celeste propia, hueso el arreo, rojo si la descubrieron, ámbar mientras el centinela cuenta; elegida =
## aro de oro alrededor y rótulo en oro. Devuelve [{id, center, r, sel, color, text, label_pos, label_rect, body}] en coordenadas locales de la interfaz.
const MARK_REAL_PX := 14.0
const MARK_HEAD_M := 2.9  # la cabeza del jinete (la figura más alta) más un poco: la marca va justo encima de todas
const LABEL_FONT := 13


func token_marks() -> Array:
	var out: Array = []
	if ui == null:
		return out
	var rs: Variant = ui.call("render_state_cached")
	if not (rs is Dictionary):
		return out
	var total_scale := maxf(float(ui.call("screen_scale")), 0.05)
	var r := MARK_REAL_PX * 0.5 / total_scale
	var selected: Array = ui.get("selected")
	var local_rect := Rect2(Vector2.ZERO, size)
	var header_bottom := float(ui.call("layout_num", ["margin"], 12.0)) + float(ui.call("layout_num", ["header_h"], 46.0)) + 4.0
	var hud: Variant = ui.get("hud")
	var shorts: Dictionary = hud.get("short_by_id") if hud != null and hud.get("short_by_id") is Dictionary else {}
	var pinned: Array = []  # las marcas de fichas fuera de cuadro, pegadas al borde: si dos caen juntas, la segunda se corre hacia arriba
	for u in (rs as Dictionary).get("units", []):
		var d := u as Dictionary
		if str(d.get("stage", "")) == "exited":
			continue
		var id := str(d.get("id", ""))
		var xz := Vector2(float(d.get("x", 0.0)), float(d.get("z", 0.0)))
		var vw: Variant = ui.get("view")
		if vw != null and is_instance_valid(vw) and (vw as Object).has_method("unit_display_offset"):  # visual/r1 F6 (B-049): la marca va sobre la figura, que la vista separa si se pisa con otra
			xz += (vw as Object).call("unit_display_offset", id)
		var foot: Variant = _world_to_screen(null, xz, 0.0)
		var head: Variant = _world_to_screen(null, xz, MARK_HEAD_M)
		var behind := false
		if not (foot is Vector2 and head is Vector2):
			# visual/r1 F4 (BACKLOG B-062 a): detrás de la cámara ui_point no la proyecta; la marca va igual, pegada al borde en la dirección en que está
			var edge: Variant = _behind_edge(xz, Rect2(Vector2(r + 6.0, header_bottom + r), Vector2(size.x - 2.0 * r - 12.0, size.y - 180.0 - header_bottom - r)))
			if not (edge is Vector2):
				continue
			foot = edge
			head = edge
			behind = true
		var center: Vector2 = (head as Vector2) + (Vector2.ZERO if behind else Vector2(0.0, -r - 3.0))
		var clamped := false
		if behind or center.y < header_bottom + r or not local_rect.grow(-6.0).has_point(center):
			center = Vector2(clampf(center.x, r + 6.0, size.x - r - 6.0), clampf(center.y, header_bottom + r, size.y - 180.0))
			clamped = true
			# visual/r1 F6: pegada al borde no queda debajo de un panel de abajo (el aviso de pie, la barra de órdenes, el dock): sube hasta encima de él
			var blockers: Array = []
			if hud != null and (hud as Object).has_method("panels"):
				var pd: Dictionary = (hud as Object).call("panels")
				for key in pd:
					if not (str(key) in ["header", "fronts"]):
						blockers.append(get_global_transform().affine_inverse() * Kit.rect_of(pd[key] as Control))
			for _pass in range(3):
				for br in blockers:
					if (br as Rect2).grow(r + 4.0).has_point(center) and (br as Rect2).position.y - r - 6.0 > header_bottom + r:
						center.y = (br as Rect2).position.y - r - 6.0
			for other in pinned:
				if (other as Vector2).distance_to(center) < 2.0 * r + float(LABEL_FONT) + 4.0:
					center.y -= 2.0 * r + float(LABEL_FONT) + 6.0
			pinned.append(center)
		var color := Kit.NEUTRAL if id == "arreo" else Kit.PATRIOT
		if bool(d.get("detected", false)):
			color = Kit.ENEMY
		elif float(d.get("spotted_s", 0.0)) > 0.01:
			color = Kit.AMBER
		var key := str(V.GROUPS.find(id) + 1)
		var text := "%s  %s" % [key, str(shorts.get(id, ""))] if str(shorts.get(id, "")) != "" else key
		var w := _text_w(text, LABEL_FONT)
		var label_pos := center + Vector2(r + 5.0, float(LABEL_FONT) * 0.36)
		if label_pos.x + w > size.x - 6.0:  # pegada al borde derecho: el rótulo va a la izquierda de la marca
			label_pos.x = center.x - r - 5.0 - w
		var label_rect := Rect2(label_pos - Vector2(0.0, float(LABEL_FONT)), Vector2(w, float(LABEL_FONT) + 4.0))
		var body := Rect2(center - Vector2(r + 3.0, r + 3.0), Vector2(2.0 * r + 6.0, maxf((foot as Vector2).y - center.y, 0.0) + r + 6.0)) if not clamped else Rect2(center - Vector2(r + 3.0, r + 3.0), Vector2(2.0 * r + 6.0, 2.0 * r + 6.0))
		out.append({"id": id, "center": center, "r": r, "sel": selected.has(id), "color": color, "text": text, "label_pos": label_pos, "label_rect": label_rect, "body": body})
	return out


## visual/r1 F4 (BACKLOG B-062 a): para una agrupación que quedó detrás de la cámara, el punto del borde de `free` (coordenadas locales) en la dirección en que está,
## vista desde el centro de la pantalla: su posición en el espacio de la cámara (x a la derecha, y arriba) da esa dirección aunque no se la pueda proyectar.
func _behind_edge(xz: Vector2, free: Rect2) -> Variant:
	var cam_v: Variant = ui.call("camera3d")
	if not (cam_v is Camera3D) or not (cam_v as Camera3D).is_inside_tree() or free.size.x <= 0.0 or free.size.y <= 0.0:
		return null
	var cam3 := cam_v as Camera3D
	var local := cam3.global_transform.affine_inverse() * Vector3(xz.x, float(ui.call("ground_height", xz.x, xz.y)), xz.y)
	var dir := Vector2(local.x, -local.y)
	if dir.length() < 0.001:
		dir = Vector2(0.0, 1.0)
	dir = dir.normalized()
	var mid := free.get_center()
	var t := INF
	if absf(dir.x) > 0.0001:
		t = minf(t, (free.size.x * 0.5) / absf(dir.x))
	if absf(dir.y) > 0.0001:
		t = minf(t, (free.size.y * 0.5) / absf(dir.y))
	return mid + dir * t


## Lo que ocupa en pantalla cada ficha con su marca y su rótulo (para que los rótulos de los frentes y los avisos no la pisen).
func _token_rects(_cam: Camera3D) -> Array:
	var out: Array = []
	for m in token_marks():
		out.append((m.body as Rect2).merge(m.label_rect as Rect2))
	return out


## visual/r1 F1: la marca chica y el rótulo de una línea de cada agrupación (lo dibuja la interfaz para que quede pegado a la figura y fuera del HUD). Los rótulos no
## se pisan: van primero los de las elegidas y uno que caería sobre otro ya dibujado se omite (la marca siempre se dibuja).
func _draw_token_labels(_cam: Camera3D) -> void:
	var marks := token_marks()
	marks.sort_custom(func(a, b): return bool(a.sel) and not bool(b.sel))
	var placed: Array = []
	var dots: Array = []
	for m in marks:
		dots.append(Rect2((m.center as Vector2) - Vector2(float(m.r), float(m.r)), Vector2(2.0 * float(m.r), 2.0 * float(m.r))))
	for m in marks:
		var c: Vector2 = m.center
		var r := float(m.r)
		if bool(m.sel):
			draw_arc(c, r + 3.5, 0.0, TAU, 24, Kit.GOLD_LIGHT, 2.5, true)
		draw_circle(c, r + 1.5, Color(0.05, 0.07, 0.04, 0.92))
		draw_circle(c, r, m.color)
	for m in marks:
		var lr: Rect2 = m.label_rect
		var hit := false
		for o in placed + dots:  # ni sobre otro rótulo ni sobre la marca de otra ficha
			if lr.grow(2.0).intersects(o as Rect2):
				hit = true
				break
		if hit:
			continue
		_text(m.label_pos, str(m.text), LABEL_FONT, Kit.GOLD_LIGHT if bool(m.sel) else Kit.PAPER)
		placed.append(lr)


## visual/r1 F3: los defensores y el botín van a escala real (antes crecían hasta 28 y 10 px con la distancia), así que de lejos se los encuentra por una marca
## chica, como a las fichas: un rombo rojo de 9 px reales con filete oscuro sobre cada defensor (más grande si está alertado: el color nunca va solo) y un cuadradito
## hueso de 6 px sobre cada bulto de botín ABANDONADO en el camino (el que sigue en su depósito ya lo marca el anillo del objetivo: con marca propia ensuciaba los
## rótulos «Batería» y «Cuartel»). La torre tiene su propio anillo de recarga.
const ENEMY_MARK_PX := 9.0
const LOOT_MARK_PX := 6.0
const THING_MARK_LIFT_M := 2.4


func _draw_thing_marks(_cam: Camera3D) -> void:
	var rs: Variant = ui.call("render_state_cached")
	if not (rs is Dictionary):
		return
	var k := maxf(float(ui.call("screen_scale")), 0.05)
	var header_bottom := float(ui.call("layout_num", ["margin"], 12.0)) + float(ui.call("layout_num", ["header_h"], 46.0)) + 4.0
	var area := Rect2(Vector2(0.0, header_bottom), Vector2(size.x, maxf(size.y - header_bottom, 0.0)))
	var ink := Color(0.05, 0.07, 0.04, 0.92)
	for e in (rs as Dictionary).get("enemies", []):
		if not (e is Dictionary) or str((e as Dictionary).get("kind", "")) == "torre":
			continue
		var s: Variant = _world_to_screen(null, Vector2(float(e.get("x", 0.0)), float(e.get("z", 0.0))), THING_MARK_LIFT_M)
		if not (s is Vector2) or not area.has_point(s as Vector2):
			continue
		var r := ENEMY_MARK_PX * (1.3 if float(e.get("alert", 0.0)) > 0.5 else 1.0) * 0.5 / k
		var c: Vector2 = (s as Vector2) + Vector2(0.0, -r - 2.0)
		var rim := r + 1.5
		draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -rim), c + Vector2(rim, 0.0), c + Vector2(0.0, rim), c + Vector2(-rim, 0.0)]), ink)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -r), c + Vector2(r, 0.0), c + Vector2(0.0, r), c + Vector2(-r, 0.0)]), Kit.ENEMY)
	for l in (rs as Dictionary).get("loot", []):
		if not (l is Dictionary) or str((l as Dictionary).get("state", "")) != "abandonado":
			continue
		var s2: Variant = _world_to_screen(null, Vector2(float(l.get("x", 0.0)), float(l.get("z", 0.0))), 1.2)
		if not (s2 is Vector2) or not area.has_point(s2 as Vector2):
			continue
		var h := LOOT_MARK_PX * 0.5 / k
		draw_rect(Rect2((s2 as Vector2) - Vector2(h + 1.5, h + 1.5), Vector2(2.0 * h + 3.0, 2.0 * h + 3.0)), ink, true)
		draw_rect(Rect2((s2 as Vector2) - Vector2(h, h), Vector2(2.0 * h, 2.0 * h)), Kit.NEUTRAL, true)


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
