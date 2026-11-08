extends RefCounted
## Ventanas del nivel «humahuaca» (CONTRATO 3.5): el briefing en dos pantallas, el menú de pausa, la ayuda, el diario, la decisión con reloj, las
## confirmaciones y el parte de derrota y de victoria. Una sola ventana abierta a la vez, sobre un velo que no deja pasar los clics.
## Los textos salen de humahuaca_ui.json y de lo que devuelven las reglas (briefing, campaign_report, epilogue); la interfaz no inventa datos: reordena los que hay.
## Paleta común «Crónica en oro y noche» (V-06). Dos tamaños de ventana:
##   · pantallas completas (`_screen`): el briefing (modelo 05 de las referencias: objetivo arriba a la izquierda, tus fuerzas, enemigo y cronología a los costados,
##     una cita con fuente y «Empezar» en oro) y los partes (D-08: legibles sin scroll a 1280 × 720 y a 1024 × 640, con la línea de tiempo plegada; la derrota enseña
##     qué pasó, cuándo y qué probar, y «Reintentar» queda a mano). Marco «de documento»: doble filete y esquinas;
##   · ventanas chicas centradas (`_frame`): pausa, confirmaciones, ayuda, diario y decisión.
## Lo que se hace con cada botón lo resuelve el controlador (`act`). Al ganar, el botón principal del parte es «Seguir al capítulo III»: emite `go_norte` y el
## controlador sale con `exited.emit("norte")` (main.gd → _on_hx_exited → _start_game("norte")).

const Kit = preload("res://scripts/humahuaca/ui/humahuaca_ui_kit.gd")
const V = preload("res://scripts/humahuaca/humahuaca_vocab.gd")
const U = preload("res://scripts/humahuaca/ui/vocab_ui.gd")

const MEDAL_COLORS := {"oro": Color("c9a25e"), "plata": Color("c4c2bc"), "bronce": Color("a8743f")}

var ui: Node = null
var layer: Control = null
var act: Callable = Callable()
var current := ""
var primary: Button = null
var closable := true
var panel: PanelContainer = null
var scroll_used := false
var history_open := false
var timeline_open := false  # la línea de tiempo del parte de victoria: plegada al abrir (D-08)
var notice := ""  # un aviso para el próximo parte (por ejemplo, por qué no se pudo volver a un punto de control); se muestra una vez
var _dim: ColorRect = null
var _center: Control = null
var _decision_count: Label = null
var _decision_left := 0.0


func setup(controller: Node, layer_node: Control, act_in: Callable) -> void:
	ui = controller
	layer = layer_node
	act = act_in


func is_open() -> bool:
	return current != ""


func _t(path: String, fallback: String = "") -> String:
	return str(ui.call("tx", path, fallback))


func _font() -> Font:
	return ui.call("font") if ui != null and ui.has_method("font") else ThemeDB.fallback_font


func close() -> void:
	if _dim != null and is_instance_valid(_dim):
		_dim.queue_free()
	if _center != null and is_instance_valid(_center):
		_center.queue_free()
	_dim = null
	_center = null
	panel = null
	primary = null
	current = ""
	scroll_used = false
	_decision_count = null


func _fire(kind: String, arg: Variant = null) -> void:
	if act.is_valid():
		act.call(kind, arg)


func _begin(id: String, can_close: bool, dim: Color) -> void:
	close()
	current = id
	closable = can_close
	history_open = false if id != "parte" else history_open
	if id != "parte":
		timeline_open = false
	if ui != null and ui.has_method("end_gestures"):
		ui.call("end_gestures")  # lo que empezó antes de la ventana (arrastre, caja) no sigue después (revisión E-1)
	_dim = ColorRect.new()
	_dim.name = "HxDim"
	_dim.color = dim
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_dim)


## Arma el marco de una ventana chica y devuelve la caja de contenido. `width` es el ancho máximo en píxeles lógicos.
func _frame(id: String, width: float, can_close: bool) -> VBoxContainer:
	_begin(id, can_close, Kit.DIM)
	var center := CenterContainer.new()
	center.name = "HxModal"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	_center = center
	var view_w := layer.size.x
	var pad := float(ui.call("layout_num", ["modal", "pad"], 22.0))
	panel = Kit.panel(center, Color(Kit.INK_PANEL, 0.97), Kit.FILET, pad, pad * 0.8)
	panel.custom_minimum_size.x = minf(width, view_w - 24.0)
	panel.draw.connect(_draw_doc_frame.bind(panel, false))
	var box := Kit.vbox(panel, 10)
	return box


## Una pantalla completa: velo de tinta sobre la escena, viñeta fuerte y el marco de documento a todo el cuadro. Devuelve la caja de contenido (de arriba abajo).
func _screen(id: String, can_close: bool) -> VBoxContainer:
	_begin(id, can_close, Color(Kit.INK_NIGHT, 0.72))
	_dim.add_child(Kit.vignette(float(ui.call("layout_num", ["vignette", "screens"], 0.55))))
	var sz := layer.size
	var m := clampf(minf(sz.x, sz.y) * 0.025, 12.0, 32.0)
	var margin := MarginContainer.new()
	margin.name = "HxScreen"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, int(m))
	layer.add_child(margin)
	_center = margin
	var pad_h := clampf(sz.x * 0.022, 16.0, 36.0)
	var pad_v := clampf(sz.y * 0.026, 12.0, 28.0)
	panel = PanelContainer.new()
	panel.name = "HxScreenPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := Kit.style(Color(Kit.INK_NIGHT, 0.18), Color.TRANSPARENT, 0, Kit.RADIUS, pad_h, pad_v)
	panel.add_theme_stylebox_override("panel", sb)
	margin.add_child(panel)
	panel.draw.connect(_draw_doc_frame.bind(panel, true))
	var box := Kit.vbox(panel, int(clampf(sz.y * 0.014, 6.0, 14.0)))
	return box


## Marco «de documento» (dirección de arte §2.5): doble filete (oro apagado y oro viejo, 3 px de separación) y en cada esquina un adorno de 12 px.
func _draw_doc_frame(c: Control, big: bool) -> void:
	var r := Rect2(Vector2(1.0, 1.0), c.size - Vector2(2.0, 2.0))
	c.draw_rect(r, Kit.FILET, false, 1.0)
	var inner := r.grow(-4.0)
	c.draw_rect(inner, Color(Kit.GOLD, 0.75), false, 1.0)
	var k := 14.0 if big else 10.0
	for corner in [inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y)]:
		var p: Vector2 = corner
		var sx := 1.0 if p.x <= inner.position.x + 0.5 else -1.0
		var sy := 1.0 if p.y <= inner.position.y + 0.5 else -1.0
		c.draw_line(p + Vector2(sx * 4.0, sy * 4.0), p + Vector2(sx * k, sy * 4.0), Kit.GOLD, 1.0, true)
		c.draw_line(p + Vector2(sx * 4.0, sy * 4.0), p + Vector2(sx * 4.0, sy * k), Kit.GOLD, 1.0, true)
		var d := p + Vector2(sx * 4.0, sy * 4.0)
		c.draw_colored_polygon(PackedVector2Array([d + Vector2(0, -2.5), d + Vector2(2.5, 0), d + Vector2(0, 2.5), d + Vector2(-2.5, 0)]), Kit.GOLD_LIGHT)


func _title(box: Control, text: String, size: int = 26) -> Label:
	var l := Kit.label(box, text, size, Kit.GOLD_LIGHT, true)
	var font: Variant = ui.get("title_font")
	if font != null:
		l.add_theme_font_override("font", Kit.spaced(font as Font, maxi(1, int(round(size * 0.06)))))
	return l


## Un título grande de pantalla completa (Cinzel, mayúsculas con espaciado).
func _big_title(box: Control, text: String, size: int, color: Color = Kit.GOLD_LIGHT) -> Label:
	var l := Kit.label(box, text.to_upper(), size, color, true)
	var font: Variant = ui.get("title_font")
	if font != null:
		l.add_theme_font_override("font", Kit.spaced(font as Font, maxi(1, int(round(size * 0.08)))))
	return l


func _buttons(box: Control) -> HBoxContainer:
	var row := Kit.hbox(box, 10)
	row.alignment = BoxContainer.ALIGNMENT_END
	return row


func _btn(row: Control, text: String, kind: String, fn: Callable, group: String = "dialogo") -> Button:
	var b := Kit.button(row, text, 16, kind, group)
	b.custom_minimum_size = Vector2(0.0, 38.0)
	b.pressed.connect(fn)
	if kind == "primary" and primary == null:
		primary = b
	return b


func press_primary() -> bool:
	if primary != null and is_instance_valid(primary) and not primary.disabled:
		primary.pressed.emit()
		return true
	return false


## Una tarjeta de pantalla completa: tinta al 86 %, filete de oro apagado, rótulo en mayúsculas oro. Devuelve la caja de contenido.
func _card(parent: Control, caption: String, name_text: String = "") -> VBoxContainer:
	var p := Kit.panel(parent, Kit.PANEL_BG, Kit.FILET, 14.0, 10.0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if name_text != "":
		p.name = name_text
	var col := Kit.vbox(p, 5)
	if caption != "":
		Kit.caption(col, caption, _font(), 12)
	return col


## Texto en cursiva (Inter inclinada, peso 300: la «serif cursiva» de las citas sin descargar otra fuente, dirección de arte §2.2).
func _italic(l: Label) -> Label:
	var base := _font()
	if base != null:
		var fv := FontVariation.new()
		fv.base_font = base
		fv.variation_opentype = {"wght": 340}
		fv.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(0.2, 1.0), Vector2.ZERO)
		l.add_theme_font_override("font", fv)
	return l


func _rich(parent: Control, text: String, size: int, color: Color = Kit.PAPER) -> RichTextLabel:
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.add_theme_font_size_override("normal_font_size", size)
	rt.add_theme_font_size_override("bold_font_size", size)
	rt.add_theme_color_override("default_color", color)
	rt.text = text
	parent.add_child(rt)
	return rt


# ---------------------------------------------------------------------------------------------------------------------
# Briefing a pantalla completa (modelo 05). Los textos son los de siempre (briefing_data, fuente única en las reglas) y la interfaz los ordena:
# la situación arriba a la izquierda, el objetivo debajo, tus fuerzas a la izquierda, el enemigo, esta noche y la cronología a la derecha y abajo una cita con
# fuente (parte de Arias, documentado) y «Empezar» en oro. La segunda pantalla es la carta y lo que es real y lo que es diseño.

func show_briefing(page: int) -> void:
	var data: Dictionary = ui.call("briefing_data")
	var b := _screen("briefing", false)
	var sz := layer.size
	var lines: Array = data.get("lines", [])
	if page <= 1:
		_briefing_page1(b, data, lines, sz)
	else:
		_briefing_page2(b, data, sz)


func _briefing_page1(b: VBoxContainer, data: Dictionary, lines: Array, sz: Vector2) -> void:
	var big := sz.x >= 1400.0
	# arriba a la izquierda: capítulo, título y la situación
	var head := Kit.vbox(b, 2)
	head.name = "HxBriefHead"
	Kit.caption(head, _t("briefing.page1.kicker", "Capítulo II"), _font(), 13)
	_big_title(head, _t("briefing.page1.title", "Humahuaca, 1817"), 46 if big else 38)
	var sub := Kit.label(head, _t("briefing.page1.subtitle", ""), 17 if big else 15, Kit.MUTED, true)
	sub.visible = sub.text != ""
	# el medio: dos columnas a los costados y la escena en el centro
	var mid := Kit.hbox(b, int(clampf(sz.x * 0.02, 12.0, 28.0)))
	mid.name = "HxBriefMid"
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var col_w := clampf(sz.x * 0.31, 280.0, 440.0)
	var left := Kit.vbox(mid, 10)
	left.custom_minimum_size.x = col_w
	var situation := str(lines[0]) if lines.size() >= 1 else ""
	if situation != "":
		Kit.label(left, situation, 17 if big else 16, Kit.PAPER, true).name = "HxBriefSituation"
	var obj := _card(left, _t("briefing.page1.objective", "Objetivo"), "HxBriefObjective")
	Kit.label(obj, str(lines[1]) if lines.size() >= 2 else "", 17 if big else 16, Kit.PAPER, true)
	var forces := _card(left, _t("briefing.page1.forces", "Tus fuerzas"), "HxBriefForces")
	_forces_rows(forces)
	Kit.spacer(mid, true)
	var right := Kit.vbox(mid, 10)
	right.custom_minimum_size.x = col_w
	var enemy := _card(right, _t("briefing.page1.enemy", "Enemigo"), "HxBriefEnemy")
	_enemy_rows(enemy)
	var today := str(data.get("mundo", ""))
	var tonight := _card(right, _t("briefing.page1.tonight", "Esta noche"), "HxBriefTonight")
	var reloj := _dawn_text()
	if reloj != "":
		Kit.label(tonight, reloj, 15, Kit.GOLD_LIGHT, true)
	if today != "":
		Kit.label(tonight, _t("briefing.page1.today", "Hoy: %s") % today, 14, Kit.PAPER, true)
	var chrono: Variant = ui.texts.get("briefing", {}).get("page1", {}).get("chrono", [])
	if chrono is Array and not (chrono as Array).is_empty():
		var cr := _card(right, _t("briefing.page1.chrono_title", "Cronología"), "HxBriefChrono")
		for item in chrono:
			var d := item as Dictionary
			var tag := str(d.get("tag", "diseno"))
			_rich(cr, "[color=%s]●[/color] [color=%s]%s[/color]  %s [color=%s]%s[/color]" % [Kit.hex(Kit.VIOLET), Kit.hex(Kit.GOLD), str(d.get("fecha", "")), str(d.get("texto", "")).replace("[", "[lb]"),
				Kit.hex(Kit.tag_color(ui.source_tags, tag)), Kit.tag_glyph(ui.source_tags, tag)], 14)
	# abajo: la cita con fuente a la izquierda; «perder no es grave» y los botones a la derecha
	var foot := Kit.hbox(b, 18)
	foot.name = "HxBriefFoot"
	var quote := Kit.vbox(foot, 0)
	quote.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var q_text := _t("briefing.page1.quote", "")
	if q_text != "":
		var qrow := Kit.hbox(quote, 8)
		var mark := Kit.label(qrow, "«", 40, Kit.GOLD)
		mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var qcol := Kit.vbox(qrow, 0)
		qcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ql := _italic(Kit.label(qcol, q_text + "»", 19 if big else 17, Kit.PAPER, true))
		ql.name = "HxBriefQuote"
		var tag := str(ui.texts.get("briefing", {}).get("opening", {}).get("tag", "documentado"))
		Kit.label(qcol, "— %s  %s" % [_t("briefing.page1.quote_source", ""), Kit.tag_glyph(ui.source_tags, tag)], 12, Kit.MUTED, true)
	var act_col := Kit.vbox(foot, 6)
	act_col.size_flags_horizontal = Control.SIZE_SHRINK_END
	act_col.size_flags_vertical = Control.SIZE_SHRINK_END
	if lines.size() >= 3:
		var lose := Kit.label(act_col, str(lines[2]), 14, Kit.MUTED, false, HORIZONTAL_ALIGNMENT_RIGHT)
		lose.name = "HxBriefLose"
	for extra in lines.slice(3):
		Kit.label(act_col, str(extra), 14, Kit.MUTED, true)
	var row := _buttons(act_col)
	_btn(row, _t("briefing.buttons.next", "Seguir leyendo"), "normal", func(): _fire("briefing_page", 2))
	var start := _btn(row, _t("briefing.buttons.start", "Empezar"), "primary", func(): _fire("briefing_start", false))
	start.name = "HxStart"
	start.custom_minimum_size = Vector2(160.0, 44.0)
	start.add_theme_font_size_override("font_size", 18)


## Las cinco agrupaciones con su tecla y adónde van (los nombres cortos y los frentes salen de las reglas, map_data().groups).
func _forces_rows(col: Control) -> void:
	var md: Variant = ui.get("rules").call("map_data") if ui.get("rules") != null else {}
	var groups: Variant = (md as Dictionary).get("groups", {}) if md is Dictionary else {}
	var roles: Variant = ui.texts.get("briefing", {}).get("page1", {}).get("roles", {})
	for i in range(V.GROUPS.size()):
		var id := str(V.GROUPS[i])
		var g: Dictionary = (groups as Dictionary).get(id, {}) if groups is Dictionary else {}
		var name_text := str(g.get("short", g.get("name", id)))
		var front := str(g.get("front", ""))
		var where := ""
		if front != "":
			where = str((ui.call("front_label", front) as Dictionary).get("text", front))
		elif roles is Dictionary:
			where = str((roles as Dictionary).get(id, ""))
		var row := Kit.hbox(col, 8)
		var k := Kit.label(row, str(i + 1), 15, Kit.GOLD)
		k.custom_minimum_size.x = 14.0
		var n := Kit.trimmed(Kit.label(row, name_text, 15, Kit.PAPER))
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var w := Kit.label(row, where, 13, Kit.MUTED, false, HORIZONTAL_ALIGNMENT_RIGHT)
		w.clip_text = false


## Los tres frentes con lo que se sabe de su guardia (hud_state: al empezar, nada: «Guardia ?»).
func _enemy_rows(col: Control) -> void:
	var hs: Variant = ui.get("rules").call("hud_state") if ui.get("rules") != null else {}
	var list: Variant = (hs as Dictionary).get("frentes", []) if hs is Dictionary else []
	for f in list:
		var d := f as Dictionary
		var row := Kit.hbox(col, 8)
		var dot := ColorRect.new()
		dot.color = Kit.ENEMY
		dot.custom_minimum_size = Vector2(3.0, 16.0)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(dot)
		var n := Kit.trimmed(Kit.label(row, str(d.get("nombre", "")), 15, Kit.PAPER))
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var gv: Variant = d.get("guardia", {})
		var guard: Dictionary = gv if gv is Dictionary else {}
		var gtxt := _t("hud.guard_known", "Guardia %d") % int(guard.get("min", 0)) if bool(guard.get("conocida", false)) else _t("hud.guard_unknown", "Guardia ?")
		Kit.label(row, gtxt, 13, Kit.MUTED, false, HORIZONTAL_ALIGNMENT_RIGHT).clip_text = false


func _dawn_text() -> String:
	var hs: Variant = ui.get("rules").call("hud_state") if ui.get("rules") != null else {}
	var fase: Variant = (hs as Dictionary).get("fase", {}) if hs is Dictionary else {}
	return str((fase as Dictionary).get("reloj", "")) if fase is Dictionary else ""


func _briefing_page2(b: VBoxContainer, data: Dictionary, sz: Vector2) -> void:
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.add_child(holder)
	var col := Kit.vbox(holder, 10)
	col.custom_minimum_size.x = minf(820.0, sz.x - 120.0)
	Kit.caption(col, _t("briefing.page2.kicker", "Antes de empezar"), _font(), 13)
	_big_title(col, _t("briefing.page2.title", "La carta del 26 de febrero"), 32 if sz.x >= 1400.0 else 28)
	var lab := Kit.label(col, "%s %s" % [Kit.tag_glyph(ui.source_tags, "diseno"), _t("briefing.page2.label", "Dramatización")], 14, Kit.tag_color(ui.source_tags, "diseno"))
	lab.clip_text = false
	var doc := _card(col, "", "HxBriefLetter")
	var carta: Variant = data.get("carta", {})
	if carta is Dictionary and str((carta as Dictionary).get("texto", "")) != "":
		_italic(Kit.label(doc, str((carta as Dictionary).get("texto", "")), 18, Kit.PAPER, true))
	_note(col, data.get("nota_fecha", {}), 15)
	Kit.divider(col)
	Kit.caption(col, _t("briefing.notes_title", "Qué es real y qué es diseño"), _font(), 12)
	_note(col, data.get("nota_relieve", {}), 14)
	_note(col, data.get("nota_refuerzo", {}), 14)
	var row2 := _buttons(b)
	_btn(row2, _t("briefing.buttons.back", "Volver"), "normal", func(): _fire("briefing_page", 1))
	_btn(row2, _t("briefing.buttons.skip", "Saltar"), "normal", func(): _fire("briefing_start", true))
	var start := _btn(row2, _t("briefing.buttons.start", "Empezar"), "primary", func(): _fire("briefing_start", false))
	start.name = "HxStart"
	start.custom_minimum_size = Vector2(160.0, 44.0)
	start.add_theme_font_size_override("font_size", 18)


## Un texto con el glifo de su etiqueta al principio (el glifo lleva el color de la etiqueta).
func _note(box: Control, d: Variant, size: int) -> void:
	if not (d is Dictionary) or str((d as Dictionary).get("texto", "")) == "":
		return
	var tag := str((d as Dictionary).get("tag", "diseno"))
	_rich(box, "[color=%s]%s[/color]  %s" % [Kit.hex(Kit.tag_color(ui.source_tags, tag)), Kit.tag_glyph(ui.source_tags, tag), str((d as Dictionary).get("texto", "")).replace("[", "[lb]")], size)


# ---------------------------------------------------------------------------------------------------------------------
# Menú de pausa, confirmaciones, ayuda y diario

func show_pause(can_save: bool, can_load: bool) -> void:
	var b := _frame("pausa", 460.0, true)
	_title(b, _t("pause.title", "Pausa"), 28)
	var col := Kit.vbox(b, 8)
	var items := [
		["resume", _t("pause.resume", "Seguir jugando"), "primary", true],
		["save", _t("pause.save", "Guardar (F5)"), "normal", can_save],
		["load", _t("pause.load", "Cargar (F9)"), "normal", can_load],
		["help", _t("pause.help", "Cómo se juega (F1)"), "normal", true],
		["diary", _t("pause.diary", "Diario"), "normal", true],
		["retreat", _t("pause.retreat", "Retirada general"), "danger", can_save],
		["menu", _t("pause.menu", "Volver al menú"), "normal", true]]
	for it in items:
		var id := str(it[0])
		var btn := _btn(col, str(it[1]), str(it[2]), func(): _fire("pause_" + id), "dialogo")
		btn.disabled = not bool(it[3])
		btn.name = "HxPause_%s" % id


func show_confirm(text: String, yes_label: String, no_label: String, yes_id: String, danger: bool) -> void:
	var b := _frame("confirmar", 520.0, true)
	Kit.label(b, text, 18, Kit.PAPER, true)
	var row := _buttons(b)
	_btn(row, no_label, "normal", func(): _fire("confirm_no"))
	_btn(row, yes_label, "danger" if danger else "primary", func(): _fire(yes_id))


func show_help() -> void:
	var b := _frame("ayuda", 940.0, true)
	_title(b, _t("help.title", "Cómo se juega"))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0.0, minf(layer.size.y - 190.0, 520.0))
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_child(scroll)
	scroll_used = true
	var body := Kit.vbox(scroll, 6)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lines: Variant = ui.texts.get("help", {}).get("lines", [])
	var n := 0
	for line in lines:
		n += 1
		Kit.label(body, "%d. %s" % [n, str(line)], 16, Kit.PAPER, true)
	var glossary: Variant = ui.texts.get("help", {}).get("glossary", [])
	if glossary is Array and not (glossary as Array).is_empty():
		Kit.label(body, _t("help.glossary_title", "Qué significa lo que ves"), 15, Kit.GOLD)
		for line in glossary:
			Kit.label(body, str(line), 14, Kit.PAPER, true)
	Kit.label(body, _t("help.keys_title", "Teclas"), 15, Kit.GOLD)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 2)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(grid)
	for row in ui.key_rows():
		var kl := Kit.label(grid, str(row.get("show", "")), 13, Kit.GOLD)
		kl.clip_text = false
		Kit.label(grid, str(row.get("label", "")), 13, Kit.PAPER, true)
	Kit.label(body, _t("help.tags_title", "Cómo se rotula lo que se cuenta"), 15, Kit.GOLD)
	for tag_id in V.TAGS:
		var info: Dictionary = ui.source_tags.get(tag_id, {})
		_rich(body, "[color=%s]%s %s[/color]: %s" % [Kit.hex(Kit.tag_color(ui.source_tags, str(tag_id))), str(info.get("glifo", "")), str(info.get("etiqueta", "")), str(info.get("descripcion", ""))], 13)
	var data: Dictionary = ui.call("briefing_data")
	Kit.label(body, _t("briefing.notes_title", "Qué es real y qué es diseño"), 15, Kit.GOLD)
	for key in ["nota_fecha", "nota_relieve", "nota_refuerzo"]:
		_note(body, data.get(key, {}), 13)
	var row2 := _buttons(b)
	_btn(row2, _t("help.close", "Entendido"), "primary", func(): _fire("dialog_close"))


func show_diary(entries: Array) -> void:
	var b := _frame("diario", 640.0, true)
	_title(b, _t("diary.title", "Diario de Humahuaca"))
	if entries.is_empty():
		Kit.label(b, _t("diary.empty", ""), 16, Kit.MUTED, true)
	else:
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var want_h := 12.0  # el alto sigue al contenido (≈ 20 px por línea de 68 caracteres) hasta un tope: con pocas entradas no queda un cuadro vacío
		for e in entries:
			want_h += 6.0 + 20.0 * ceilf(float(str((e as Dictionary).get("text", e)).length() + 2) / 68.0) if e is Dictionary else 6.0 + 20.0 * ceilf(float(str(e).length() + 2) / 68.0)
		scroll.custom_minimum_size = Vector2(0.0, clampf(want_h, 48.0, minf(layer.size.y - 240.0, 360.0)))
		b.add_child(scroll)
		scroll_used = true
		var body := Kit.vbox(scroll, 6)
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for e in entries:
			var text := str((e as Dictionary).get("text", e)) if e is Dictionary else str(e)
			Kit.label(body, "• " + text, 15, Kit.PAPER, true)
	var row := _buttons(b)
	_btn(row, _t("diary.close", "Cerrar"), "primary", func(): _fire("dialog_close"))


# ---------------------------------------------------------------------------------------------------------------------
# Decisión con reloj

func show_decision(dec: Dictionary, left_s: float) -> void:
	var b := _frame("decision", 640.0, false)
	_decision_left = left_s
	_title(b, str(dec.get("titulo", "")), 24)
	Kit.label(b, str(dec.get("texto", "")), 18, Kit.PAPER, true)
	var col := Kit.vbox(b, 8)
	for o in dec.get("opciones", []):
		var opt := o as Dictionary
		var id := str(opt.get("id", ""))
		var cost := str(opt.get("costo_txt", ""))
		var label := str(opt.get("label", id))
		var btn := _btn(col, label if cost == "" else "%s  ·  %s" % [label, cost], "normal", func(): _fire("decide", id), "decision")
		btn.name = "HxOption_%s" % id
	_decision_count = Kit.label(b, "", 14, Kit.AMBER)
	update_decision(left_s)


func update_decision(left_s: float) -> void:
	_decision_left = left_s
	if _decision_count != null and is_instance_valid(_decision_count):
		_decision_count.text = _t("decision.countdown", "Se decide sola en %d s") % int(ceil(maxf(left_s, 0.0)))


# ---------------------------------------------------------------------------------------------------------------------
# Parte de derrota y de victoria (pantalla completa, D-08)

## `rep` es campaign_report() y `rec` lo que devolvió HumahuacaProgress.record_result(); los dos pueden venir incompletos.
func show_report(rep: Dictionary, rec: Dictionary, retry_options: Array) -> void:
	var victory := str(rep.get("status", "")) == "victory"
	var b := _screen("parte", false)
	var sz := layer.size
	var big := sz.x >= 1400.0
	var head := Kit.vbox(b, 2)
	head.name = "HxReportHead"
	# la derrota no va en rojo (el rojo es del enemigo): «Repliegue» en pergamino; la victoria, «Parte de victoria» en oro
	Kit.caption(head, _t("report.kicker_victory", "Parte de victoria") if victory else _t("report.kicker_defeat", "Repliegue"), _font(), 13, Kit.GOLD if victory else Kit.PAPER)
	var title_text := str(rep.get("outcome_title", ""))
	if title_text == "":
		title_text = _t("report.title_victory", "Se cumplió el golpe") if victory else _t("report.title_defeat", "No se logró el golpe")
	_big_title(head, title_text, (44 if big else 34) if victory else (40 if big else 30), Kit.GOLD_LIGHT if victory else Kit.PAPER)
	var record := str(rec.get("record_line", ""))
	if record != "":
		Kit.label(head, record, 14, Kit.GOLD if victory else Kit.MUTED, true).name = "HxRecord"
	if notice != "":
		var nl := Kit.label(head, notice, 15, Kit.AMBER, true)
		nl.name = "HxReportNotice"
		notice = ""
	var cause := str(rep.get("cause", rec.get("cause", "")))
	if victory:
		_victory_body(b, rep, rec, cause, sz)
	else:
		_defeat_body(b, rep, rec, cause, sz)
	var row := Kit.hbox(b, 10)
	row.name = "HxReportButtons"
	if victory:
		_btn(row, _t("report.menu", "Menú"), "normal", func(): _fire("pause_menu"))
		_btn(row, _t("report.diary", "Diario"), "normal", func(): _fire("pause_diary"))
		Kit.spacer(row, true)
		var next_on := bool(rec.get("next_available", false))
		var again := _btn(row, _t("report.play_again", "Jugar de nuevo"), "normal" if next_on else "primary", func(): _fire("retry", "mismo_mundo"))
		again.name = "HxRetry"
		if next_on:  # D-08 y D-03: ganar lleva al capítulo III por el botón principal (Enter); main.gd lo recibe por exited("norte")
			var nb := _btn(row, _t("report.next_primary", "Seguir al capítulo III: Sostener el norte"), "primary", func(): _fire("go_norte"))
			nb.name = "HxNext"
			nb.custom_minimum_size = Vector2(0.0, 44.0)
			nb.add_theme_font_size_override("font_size", 17)
			primary = nb
	else:
		_btn(row, _t("report.menu", "Menú"), "normal", func(): _fire("pause_menu"))
		_btn(row, _t("report.diary", "Diario"), "normal", func(): _fire("pause_diary"))
		_btn(row, _t("report.new_world", "Mundo nuevo"), "normal", func(): _fire("ask_new_world"))
		Kit.spacer(row, true)
		for o in retry_options:
			var od := o as Dictionary
			var oid := str(od.get("id", ""))
			if oid in ["posiciones", "salida"] and bool(od.get("available", false)):
				var cb := _btn(row, str(od.get("label", oid)), "normal", func(): _fire("retry", oid))
				cb.name = "HxRetry_%s" % oid
		var retry := _btn(row, _t("report.retry", "Reintentar"), "primary", func(): _fire("retry", "mismo_mundo"))
		retry.name = "HxRetry"
		retry.custom_minimum_size = Vector2(150.0, 44.0)
		retry.add_theme_font_size_override("font_size", 18)


## Los datos de la partida como cifras grandes con su rótulo (HxFacts: una celda por dato).
func _facts_grid(parent: Control, rep: Dictionary, rec: Dictionary, columns: int) -> GridContainer:
	var facts: Variant = rec.get("facts", null)
	var taken := 0
	var golpe := 0.0
	var losses := float(rep.get("loss_pct", 0.0))
	var elapsed := float(rep.get("elapsed", 0.0))
	if facts is Dictionary:
		taken = int((facts as Dictionary).get("frentes", 0))
		golpe = float((facts as Dictionary).get("golpe", 0.0))
		losses = float((facts as Dictionary).get("bajas", losses))
		elapsed = float((facts as Dictionary).get("tiempo", elapsed))
	else:
		for o in rep.get("objectives", []):
			if str((o as Dictionary).get("estado", "")) == "tomado":
				taken += 1
		var g: Dictionary = rep.get("golpe", {})
		golpe = float(g.get("entregado", 0.0)) + float(g.get("destruido", 0.0)) + float(g.get("oculto", 0.0))
	var grid := GridContainer.new()
	grid.name = "HxFacts"
	grid.columns = columns
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(grid)
	var cells := [
		[_t("report.facts_big.fronts", "%d de 3") % taken, _t("report.facts_big.fronts_label", "Frentes tomados")],
		[_t("report.facts_big.golpe", "%d de 100") % int(round(golpe)), _t("report.facts_big.golpe_label", "Golpe")],
		[_t("report.facts_big.losses", "%d %%") % int(round(losses)), _t("report.facts_big.losses_label", "Bajas")],
		[Kit.mmss(elapsed), _t("report.facts_big.time_label", "Tiempo de juego")]]
	for c in cells:
		var cell := Kit.panel(grid, Kit.PANEL_BG, Kit.FILET, 10.0, 5.0)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := Kit.vbox(cell, 0)
		var big := Kit.label(v, str(c[0]), 22, Kit.GOLD_LIGHT)
		big.clip_text = false
		Kit.label(v, str(c[1]), 12, Kit.MUTED).clip_text = false
	return grid


func _defeat_body(b: Control, rep: Dictionary, rec: Dictionary, cause: String, sz: Vector2) -> void:
	var mid := Kit.hbox(b, int(clampf(sz.x * 0.022, 14.0, 30.0)))
	mid.name = "HxReportMid"
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := Kit.vbox(mid, 10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.15
	var what := _card(left, _t("report.what_title", "Qué pasó"), "HxWhat")
	Kit.label(what, cause, 19 if sz.x >= 1400.0 else 17, Kit.PAPER, true).name = "HxCause"
	var at := Kit.mmss(float(rep.get("elapsed", 0.0)))
	if cause.find(at) < 0:  # el momento: si la causa ya lo dice («A los 6:30 amaneció…») no se repite
		Kit.label(what, _t("report.when", "A los %s de juego") % at, 14, Kit.MUTED, true).name = "HxWhen"
	var diary: Variant = rec.get("new_diary", [])
	if diary is Array and not (diary as Array).is_empty():
		var first: Variant = (diary as Array)[0]
		var dtext := str((first as Dictionary).get("text", "")) if first is Dictionary else str(first)
		if dtext != "":
			Kit.label(what, _t("report.diary_line", "En el diario: %s") % dtext, 13, Kit.MUTED, true).name = "HxDiaryLine"
	_facts_grid(left, rep, rec, 4)
	var right := Kit.vbox(mid, 10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var advice := str(rep.get("advice", rec.get("advice", "")))
	if advice != "":
		var tip := _card(right, _t("report.advice_title", "Para el próximo intento"), "HxAdviceCard")
		var al := Kit.label(tip, advice, 17 if sz.x >= 1400.0 else 16, Kit.GOLD_LIGHT, true)
		al.name = "HxAdvice"
		var hint := str(rec.get("hint", ""))
		if hint != "" and hint != advice:
			Kit.label(tip, hint, 14, Kit.PAPER, true).name = "HxHint"
	# la historia del combate queda plegada; abierta, va en su propia caja con desplazamiento para no empujar los botones fuera del cuadro
	var history: Variant = rep.get("history", [])
	if history is Array and not (history as Array).is_empty():
		var toggle := Kit.button(right, _t("report.less", "Ocultar la historia") if history_open else _t("report.more", "Ver la historia del combate"), 13, "normal", "dialogo")
		toggle.name = "HxHistoryToggle"
		toggle.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		toggle.pressed.connect(func(): _fire("history_toggle"))
		if history_open:
			var scroll := ScrollContainer.new()
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
			scroll.custom_minimum_size.y = 60.0
			right.add_child(scroll)
			scroll_used = true
			var body := Kit.vbox(scroll, 4)
			body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for h in history:
				_note(body, {"texto": str((h as Dictionary).get("text", "")), "tag": str((h as Dictionary).get("tag", "diseno"))}, 13)


## Una medalla dibujada (círculo de oro, plata o bronce con un filete y una estrella): sin imágenes.
func _medal_emblem(parent: Control, medal: String) -> void:
	var c := Control.new()
	c.name = "HxMedalEmblem"
	c.custom_minimum_size = Vector2(52.0, 52.0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col: Color = MEDAL_COLORS.get(medal, Kit.GOLD)
	c.draw.connect(func():
		var ctr := c.size * 0.5
		c.draw_circle(ctr, 24.0, Kit.INK_PANEL)
		c.draw_circle(ctr, 21.0, col)
		c.draw_arc(ctr, 24.0, 0.0, TAU, 40, Kit.GOLD_LIGHT, 1.5, true)
		c.draw_arc(ctr, 17.0, 0.0, TAU, 40, Color(Kit.INK_NIGHT, 0.45), 1.2, true)
		var star := PackedVector2Array()
		for i in range(10):
			var rr := 10.0 if i % 2 == 0 else 4.2
			var a := -PI * 0.5 + float(i) * PI / 5.0
			star.append(ctr + Vector2(cos(a), sin(a)) * rr)
		c.draw_colored_polygon(star, Color(Kit.INK_NIGHT, 0.75)))
	parent.add_child(c)


func _victory_body(b: Control, rep: Dictionary, rec: Dictionary, cause: String, sz: Vector2) -> void:
	var mid := Kit.hbox(b, int(clampf(sz.x * 0.022, 14.0, 30.0)))
	mid.name = "HxReportMid"
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := Kit.vbox(mid, 10)
	left.custom_minimum_size.x = clampf(sz.x * 0.36, 300.0, 560.0)
	var medal := str(rep.get("medal_label", rec.get("medal_label", "")))
	var medal_id := str(rep.get("medal", rec.get("medal", "")))
	var mrow := Kit.hbox(left, 12)
	if medal_id != "":
		_medal_emblem(mrow, medal_id)
	var mcol := Kit.vbox(mrow, 2)
	mcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mcol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if medal != "":
		var ml := Kit.label(mcol, medal, 22, Kit.GOLD_LIGHT, true)
		ml.name = "HxMedal"
	var best := str(rec.get("record_line", ""))
	if best == "":
		var bm := str(rec.get("medal", rep.get("medal", "")))
		Kit.label(mcol, _t("report.best_medal", "Mejor medalla: %s") % (bm if bm != "" else _t("report.no_medal", "todavía sin medalla")), 14, Kit.MUTED, true)
	Kit.label(left, cause, 17 if sz.x >= 1400.0 else 16, Kit.PAPER, true).name = "HxCause"
	_facts_grid(left, rep, rec, 2)
	var assists: Variant = rep.get("assists_used", [])
	if assists is Array and not (assists as Array).is_empty():
		Kit.label(left, _t("report.assists", "Ayudas usadas: %s") % ", ".join(PackedStringArray(assists)), 13, Kit.MUTED, true)
	# a la derecha, «Qué pasó después»: plegado muestra la fecha que contrasta tu partida con la realidad y la primera; desplegado, todas
	var right := Kit.vbox(mid, 6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lines: Array = rep.get("epilogue", [])
	var head := Kit.hbox(right, 10)
	Kit.caption(head, _t("report.epilogue_title", "Qué pasó después"), _font(), 12)
	Kit.spacer(head, true)
	var shown: Array = []
	if timeline_open:
		shown = lines
	else:
		for i in range(lines.size()):
			var t := str((lines[i] as Dictionary).get("texto", ""))
			if i == 0 or t.find("En tu partida") >= 0:
				shown.append(lines[i])
	var holder: Control = right
	if timeline_open:
		var scroll := ScrollContainer.new()
		scroll.name = "HxTimelineScroll"
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.custom_minimum_size.y = 80.0
		right.add_child(scroll)
		scroll_used = true
		var inner := Kit.vbox(scroll, 6)
		inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		holder = inner
	for line in shown:
		_epilogue_line(holder, line as Dictionary, 15 if sz.x >= 1400.0 else 14)
	var note: Variant = ui.call("time_note")
	if note is Dictionary:
		_note(holder, note, 13)
	if lines.size() > shown.size() or timeline_open:
		var tg := Kit.button(right, (_t("report.timeline_less", "Plegar la línea de tiempo") if timeline_open else _t("report.timeline_more", "Ver toda la línea de tiempo (%d fechas)") % lines.size()), 13, "normal", "dialogo")
		tg.name = "HxTimelineToggle"
		tg.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		tg.pressed.connect(func(): _fire("timeline_toggle"))


func _epilogue_line(parent: Control, d: Dictionary, size: int = 14) -> void:
	var tag := str(d.get("tag", "documentado"))
	var text := str(d.get("texto", ""))
	var marker := "En tu partida:"
	var cut := text.find(marker)
	var body_text := text.replace("[", "[lb]")
	if cut >= 0:
		body_text = text.substr(0, cut).strip_edges().replace("[", "[lb]") + "\n[color=%s]%s[/color]" % [Kit.hex(Kit.GOLD_LIGHT), text.substr(cut).replace("[", "[lb]")]
	_rich(parent, "[color=%s]%s[/color] [color=%s]%s[/color]  %s" % [Kit.hex(Kit.GOLD), str(d.get("fecha", "")), Kit.hex(Kit.tag_color(ui.source_tags, tag)), Kit.tag_glyph(ui.source_tags, tag), body_text], size)
