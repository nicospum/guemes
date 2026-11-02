extends RefCounted
## Kit de interfaz propio del nivel «humahuaca» (CONTRATO 3.5): paneles, etiquetas, botones y barras. No llama a main._panel/_button/_label, porque
## si ui_feel ajusta el kit no debe cruzarse con los ajustes de la Justina. Todo es estático y sin estado; los colores son los de la interfaz del
## proyecto (main.gd) más los tres marcadores de bando de humahuaca_visual.json (markers, «interfaz»: no son banderas).

const PAPER := Color("e9e3d4")
const GOLD := Color("d9b576")
const MUTED := Color("aab7b5")
const INK := Color("14180f")
const GOOD := Color("9ac4ab")
const AMBER := Color("e0b25a")
const RED := Color("d48f79")
const PANEL_BG := Color(0.075, 0.095, 0.062, 0.965)
const PANEL_BORDER := Color("50543a")
const DIM := Color(0.02, 0.03, 0.03, 0.62)
const WARN_BG := Color("7a2e26")
const WARN_BORDER := Color("b8584b")
const WARN_TEXT := Color("fff1e6")
## Marcadores de bando de la vista (humahuaca_visual.json: markers): celeste con borde blanco, borgoña con borde negro y oro.
const PATRIOT := Color("7faac4")
const PATRIOT_BORDER := Color("efe8d7")
const ROYAL := Color("983f36")
const ROYAL_BORDER := Color("383831")
const NEUTRAL := Color("b99a50")

const BTN_NORMAL := Color("232b1c")
const BTN_HOVER := Color("34402a")
const BTN_PRESSED := Color("4f5f3a")
const BTN_DISABLED := Color("1c2218")
const BTN_PRIMARY := Color("3b4a27")


static func style(bg: Color, border: Color = Color.TRANSPARENT, border_w: int = 1, radius: int = 6, pad_h: float = 10.0, pad_v: float = 6.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w if border.a > 0.0 else 0)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad_h
	s.content_margin_right = pad_h
	s.content_margin_top = pad_v
	s.content_margin_bottom = pad_v
	return s


static func panel(parent: Node, bg: Color = PANEL_BG, border: Color = PANEL_BORDER, pad_h: float = 12.0, pad_v: float = 8.0, radius: int = 7) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.add_theme_stylebox_override("panel", style(bg, border, 1, radius, pad_h, pad_v))
	if parent != null:
		parent.add_child(p)
	return p


static func vbox(parent: Node, sep: int = 4) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_theme_constant_override("separation", sep)
	if parent != null:
		parent.add_child(b)
	return b


static func hbox(parent: Node, sep: int = 8) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_theme_constant_override("separation", sep)
	if parent != null:
		parent.add_child(b)
	return b


static func spacer(parent: Node, expand: bool = true, width: float = 0.0) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.custom_minimum_size = Vector2(width, 0.0)
	if parent != null:
		parent.add_child(c)
	return c


static func label(parent: Node, text: String, size: int = 15, color: Color = PAPER, wrap: bool = false, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align as HorizontalAlignment
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.clip_text = false
		l.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	if parent != null:
		parent.add_child(l)
	return l


## Un texto que se recorta con «…» si no entra (nombres en tarjetas angostas): su ancho mínimo no obliga al contenedor.
static func trimmed(l: Label) -> Label:
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return l


## El rectángulo de un control en píxeles del cuadro (Control.get_global_rect no cuenta la escala de los padres, y la interfaz del nivel va escalada en ventanas chicas).
static func rect_of(c: Control) -> Rect2:
	return c.get_global_transform() * Rect2(Vector2.ZERO, c.size)


## Un botón del juego. `kind`: "normal", "primary" (el que se espera que se toque) o "danger". Sin foco de teclado: Espacio, las teclas 1 a 5 y
## las demás son atajos del juego y un botón con foco las robaría. `group` es el grupo de control para la medida del primer cuadro.
static func button(parent: Node, text: String, size: int = 15, kind: String = "normal", group: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size = Vector2(0.0, 32.0)
	b.add_theme_font_size_override("font_size", size)
	var base := BTN_NORMAL
	var border := Color("5a6044")
	var width := 1
	match kind:
		"primary":
			base = BTN_PRIMARY
			border = GOLD
			width = 2
		"danger":
			base = Color("4a231f")
			border = WARN_BORDER
	for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		var c := base
		var bc := border
		if state_name == "hover":
			c = base.lightened(0.14)
			bc = GOLD
		elif state_name == "pressed":
			c = base.lightened(0.26)
		elif state_name == "disabled":
			c = BTN_DISABLED
			bc = Color("3a3f30")
		b.add_theme_stylebox_override(state_name, style(c, bc, width, 5, 12.0, 4.0))
	b.add_theme_color_override("font_color", PAPER)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color("8a9896"))
	if group != "":
		b.set_meta("hx_group", group)
	if parent != null:
		parent.add_child(b)
	return b


## Barra fina (toma, fuerza, fatiga, alba). No muestra el porcentaje: el texto lo dice la etiqueta de al lado.
static func bar(parent: Node, color: Color, height: float = 6.0, value: float = 0.0, back: Color = Color(0.2, 0.23, 0.17, 1.0)) -> ProgressBar:
	var p := ProgressBar.new()
	p.min_value = 0.0
	p.max_value = 100.0
	p.value = value
	p.show_percentage = false
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.custom_minimum_size = Vector2(20.0, height)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("background", style(back, Color.TRANSPARENT, 0, 3, 0.0, 0.0))
	p.add_theme_stylebox_override("fill", style(color, Color.TRANSPARENT, 0, 3, 0.0, 0.0))
	if parent != null:
		parent.add_child(p)
	return p


static func recolor_bar(p: ProgressBar, color: Color) -> void:
	p.add_theme_stylebox_override("fill", style(color, Color.TRANSPARENT, 0, 3, 0.0, 0.0))


## «m:ss» de unos segundos de juego.
static func mmss(seconds: float) -> String:
	var s := maxi(0, int(floor(seconds)))
	return "%d:%02d" % [floori(float(s) / 60.0), s % 60]


## Convierte un color en texto «#RRGGBB» (para los rótulos con BBCode).
static func hex(c: Color) -> String:
	return "#" + c.to_html(false)


## El glifo y el color de una etiqueta de fuente (source_tags). Si el id no existe, devuelve el de «diseno».
static func tag_info(source_tags: Dictionary, tag_id: String) -> Dictionary:
	var info: Variant = source_tags.get(tag_id, source_tags.get("diseno", {}))
	return info if info is Dictionary else {}


static func tag_glyph(source_tags: Dictionary, tag_id: String) -> String:
	return str(tag_info(source_tags, tag_id).get("glifo", "▲"))


static func tag_color(source_tags: Dictionary, tag_id: String) -> Color:
	return Color(str(tag_info(source_tags, tag_id).get("color", "#d8d2c0")))


## Cuántos caracteres de texto hay visibles bajo `node` (etiquetas, botones y textos con formato).
static func text_chars(node: Node) -> int:
	var n := 0
	if node == null:
		return 0
	for c in node.find_children("*", "Control", true, false):
		var ctl := c as Control
		if not ctl.is_visible_in_tree():
			continue
		if ctl is Label:
			n += (ctl as Label).text.length()
		elif ctl is Button:
			n += (ctl as Button).text.length()
		elif ctl is RichTextLabel:
			n += (ctl as RichTextLabel).get_parsed_text().length()
	return n


## Los textos que no entran en su control (H-R1-10): una etiqueta de una línea más angosta que su texto (se recorta con «…» o se pasa de su caja), una etiqueta con líneas
## escondidas o un botón más chico que su mínimo. Es la misma medida que usa la sonda de recortes del QA (ancho del texto contra el ancho del control, con 1,5 px de
## tolerancia), así que lo que acá da vacío no se le va a marcar. Devuelve [{name, text, need, have, why}], sin repetir un control.
static func cut_labels(node: Node) -> Array:
	var out: Array = []
	if node == null:
		return out
	for n in node.find_children("*", "Control", true, false):
		var c := n as Control
		if not c.is_visible_in_tree():
			continue
		if c is Label:
			var l := c as Label
			if l.text.strip_edges() == "" or l.size.x < 1.0:
				continue
			if l.get_line_count() > l.get_visible_line_count() and l.get_visible_line_count() > 0:
				out.append({"name": str(l.name), "text": l.text.left(60), "need": float(l.get_line_count()), "have": float(l.get_visible_line_count()), "why": "líneas"})
			elif l.autowrap_mode == TextServer.AUTOWRAP_OFF:
				var fnt: Font = l.get_theme_font("font")
				var fs: int = l.get_theme_font_size("font_size")
				var need := fnt.get_string_size(l.text.get_slice("\n", 0), HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x
				if need > l.size.x + 1.5:
					out.append({"name": str(l.name), "text": l.text.left(60), "need": snappedf(need, 0.1), "have": snappedf(l.size.x, 0.1), "why": "recortado" if l.clip_text else "se pasa"})
		elif c is Button:
			var b := c as Button
			if b.text.strip_edges() == "":
				continue
			var ms := b.get_minimum_size()
			if b.size.x + 1.0 < ms.x:
				out.append({"name": str(b.name), "text": b.text.left(60), "need": snappedf(ms.x, 0.1), "have": snappedf(b.size.x, 0.1), "why": "botón"})
	return out


## La caja que ocupa el texto de una hoja (etiqueta, botón o texto con formato), en píxeles del cuadro: el ancho del texto y no el del control, que puede ser más ancho.
static func _text_box(c: Control, text: String) -> Rect2:
	var r := rect_of(c)
	if c is RichTextLabel:
		return r
	var fnt: Font = c.get_theme_font("font")
	var fs: int = c.get_theme_font_size("font_size")
	var wrap := c is Label and (c as Label).autowrap_mode != TextServer.AUTOWRAP_OFF
	var sz: Vector2 = fnt.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, c.size.x if wrap else -1.0, fs)
	var w_use := minf(sz.x, c.size.x)
	var h_use := minf(sz.y, c.size.y)
	var ha: int = HORIZONTAL_ALIGNMENT_LEFT
	var va: int = VERTICAL_ALIGNMENT_TOP
	if c is Label:
		ha = (c as Label).horizontal_alignment
		va = (c as Label).vertical_alignment
	elif c is Button:
		ha = (c as Button).alignment
		va = VERTICAL_ALIGNMENT_CENTER
	var off := Vector2.ZERO
	if ha == HORIZONTAL_ALIGNMENT_CENTER:
		off.x = (c.size.x - w_use) * 0.5
	elif ha == HORIZONTAL_ALIGNMENT_RIGHT:
		off.x = c.size.x - w_use
	if va == VERTICAL_ALIGNMENT_CENTER:
		off.y = (c.size.y - h_use) * 0.5
	elif va == VERTICAL_ALIGNMENT_BOTTOM:
		off.y = c.size.y - h_use
	var sc := c.get_global_transform().get_scale()
	return Rect2(r.position + off * sc, Vector2(w_use, h_use) * sc)


## Textos que se pisan (C01): dos hojas de texto distintas, que no son una dentro de la otra, cuyas cajas de texto se cruzan en al menos el 10 % de la más chica. Es la medida de
## solapes de la sonda del QA. Devuelve [{a, b, frac}].
static func text_overlaps(node: Node) -> Array:
	var out: Array = []
	if node == null:
		return out
	var leaves: Array = []
	for n in node.find_children("*", "Control", true, false):
		var c := n as Control
		if not c.is_visible_in_tree() or c.size.x < 1.0 or c.size.y < 1.0:
			continue
		var text := ""
		if c is Label:
			text = (c as Label).text
		elif c is Button:
			text = (c as Button).text
		elif c is RichTextLabel:
			text = (c as RichTextLabel).get_parsed_text()
		if text.strip_edges() == "":
			continue
		var box := _text_box(c, text).grow(-0.5)
		if box.size.x > 0.0 and box.size.y > 0.0:
			leaves.append({"c": c, "t": text, "box": box})
	for i in range(leaves.size()):
		for j in range(i + 1, leaves.size()):
			var a: Dictionary = leaves[i]
			var b: Dictionary = leaves[j]
			if (a.c as Control).is_ancestor_of(b.c as Control) or (b.c as Control).is_ancestor_of(a.c as Control):
				continue
			var inter: Rect2 = (a.box as Rect2).intersection(b.box as Rect2)
			if inter.size.x > 1.0 and inter.size.y > 1.0:
				var frac := (inter.size.x * inter.size.y) / minf((a.box as Rect2).size.x * (a.box as Rect2).size.y, (b.box as Rect2).size.x * (b.box as Rect2).size.y)
				if frac >= 0.1:
					out.append({"a": str(a.t).left(30), "b": str(b.t).left(30), "frac": snappedf(frac, 0.01)})
	return out


## Los botones visibles bajo `node` y cuántos controles distintos son: los de un mismo grupo (meta «hx_group») cuentan como uno.
static func controls_report(node: Node) -> Dictionary:
	var groups := {}
	var raw := 0
	var ids: Array = []
	if node != null:
		for c in node.find_children("*", "BaseButton", true, false):
			var b := c as BaseButton
			if not b.is_visible_in_tree():
				continue
			raw += 1
			var g := str(b.get_meta("hx_group")) if b.has_meta("hx_group") else str(b.name)
			groups[g] = true
			ids.append(str(b.name))
	return {"controls": groups.size(), "buttons": raw, "groups": groups.keys(), "names": ids}
