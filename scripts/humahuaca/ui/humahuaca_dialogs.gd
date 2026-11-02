extends RefCounted
## Ventanas del nivel «humahuaca» (CONTRATO 3.5): el briefing en dos tarjetas, el menú de pausa, la ayuda, el diario, la decisión con reloj, las
## confirmaciones y el parte de derrota y de victoria. Una sola ventana abierta a la vez, centrada sobre un velo que no deja pasar los clics.
## Los textos salen de humahuaca_ui.json y de lo que devuelven las reglas (briefing, campaign_report, epilogue); el parte de derrota entra entero en
## 1280 × 720 y su botón principal queda siempre a la vista. Lo que se hace con cada botón lo resuelve el controlador (`act`).

const Kit = preload("res://scripts/humahuaca/ui/humahuaca_ui_kit.gd")
const V = preload("res://scripts/humahuaca/humahuaca_vocab.gd")
const U = preload("res://scripts/humahuaca/ui/vocab_ui.gd")

var ui: Node = null
var layer: Control = null
var act: Callable = Callable()
var current := ""
var primary: Button = null
var closable := true
var panel: PanelContainer = null
var scroll_used := false
var history_open := false
var _dim: ColorRect = null
var _center: CenterContainer = null
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


## Arma el marco de una ventana y devuelve la caja de contenido. `width` es el ancho máximo en píxeles lógicos.
func _frame(id: String, width: float, can_close: bool) -> VBoxContainer:
	close()
	current = id
	closable = can_close
	history_open = false if id != "parte" else history_open
	_dim = ColorRect.new()
	_dim.name = "HxDim"
	_dim.color = Kit.DIM
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_dim)
	_center = CenterContainer.new()
	_center.name = "HxModal"
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_center)
	var view_w := layer.size.x
	var pad := float(ui.call("layout_num", ["modal", "pad"], 22.0))
	panel = Kit.panel(_center, Color(0.075, 0.095, 0.062, 0.985), Kit.GOLD, pad, pad * 0.8, 10)
	panel.add_theme_stylebox_override("panel", Kit.style(Color(0.075, 0.095, 0.062, 0.985), Kit.GOLD, 2, 10, pad, pad * 0.8))
	panel.custom_minimum_size.x = minf(width, view_w - 24.0)
	var box := Kit.vbox(panel, 10)
	return box


func _title(box: Control, text: String, size: int = 26) -> Label:
	var l := Kit.label(box, text, size, Kit.PAPER, true)
	var font: Variant = ui.get("title_font")
	if font != null:
		l.add_theme_font_override("font", font)
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


# ---------------------------------------------------------------------------------------------------------------------
# Briefing en dos tarjetas

func show_briefing(page: int) -> void:
	var data: Dictionary = ui.call("briefing_data")
	var b := _frame("briefing", 780.0, false)
	if page <= 1:
		_title(b, _t("briefing.page1.title", "Humahuaca, 1817"))
		for line in data.get("lines", []):
			Kit.label(b, str(line), 18, Kit.PAPER, true)
		var today := str(data.get("mundo", ""))
		if today != "":
			Kit.label(b, _t("briefing.page1.today", "Hoy: %s") % today, 14, Kit.MUTED, true)
		var row := _buttons(b)
		_btn(row, _t("briefing.buttons.next", "Seguir leyendo"), "normal", func(): _fire("briefing_page", 2))
		_btn(row, _t("briefing.buttons.start", "Empezar"), "primary", func(): _fire("briefing_start", false))
	else:
		_title(b, _t("briefing.page2.title", "La carta del 26 de febrero"))
		var lab := Kit.label(b, "%s %s" % [Kit.tag_glyph(ui.source_tags, "diseno"), _t("briefing.page2.label", "Dramatización")], 14, Kit.tag_color(ui.source_tags, "diseno"))
		lab.clip_text = false
		_note(b, data.get("carta", {}), 17)
		_note(b, data.get("nota_fecha", {}), 14)
		Kit.label(b, _t("briefing.notes_title", "Qué es real y qué es diseño"), 13, Kit.GOLD)
		_note(b, data.get("nota_relieve", {}), 13)
		_note(b, data.get("nota_refuerzo", {}), 13)
		var row2 := _buttons(b)
		_btn(row2, _t("briefing.buttons.back", "Volver"), "normal", func(): _fire("briefing_page", 1))
		_btn(row2, _t("briefing.buttons.skip", "Saltar"), "normal", func(): _fire("briefing_start", true))
		_btn(row2, _t("briefing.buttons.start", "Empezar"), "primary", func(): _fire("briefing_start", false))


## Un texto con el glifo de su etiqueta al principio (el glifo lleva el color de la etiqueta).
func _note(box: Control, d: Variant, size: int) -> void:
	if not (d is Dictionary) or str((d as Dictionary).get("texto", "")) == "":
		return
	var tag := str((d as Dictionary).get("tag", "diseno"))
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.add_theme_font_size_override("normal_font_size", size)
	rt.add_theme_color_override("default_color", Kit.PAPER)
	rt.text = "[color=%s]%s[/color]  %s" % [Kit.hex(Kit.tag_color(ui.source_tags, tag)), Kit.tag_glyph(ui.source_tags, tag), str((d as Dictionary).get("texto", "")).replace("[", "[lb]")]
	box.add_child(rt)


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
		var rt := RichTextLabel.new()
		rt.bbcode_enabled = true
		rt.fit_content = true
		rt.scroll_active = false
		rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rt.add_theme_font_size_override("normal_font_size", 13)
		rt.add_theme_color_override("default_color", Kit.PAPER)
		rt.text = "[color=%s]%s %s[/color]: %s" % [Kit.hex(Kit.tag_color(ui.source_tags, str(tag_id))), str(info.get("glifo", "")), str(info.get("etiqueta", "")), str(info.get("descripcion", ""))]
		body.add_child(rt)
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
	_decision_count = Kit.label(b, "", 14, Kit.GOLD)
	update_decision(left_s)


func update_decision(left_s: float) -> void:
	_decision_left = left_s
	if _decision_count != null and is_instance_valid(_decision_count):
		_decision_count.text = _t("decision.countdown", "Se decide sola en %d s") % int(ceil(maxf(left_s, 0.0)))


# ---------------------------------------------------------------------------------------------------------------------
# Parte de derrota y de victoria

## `rep` es campaign_report() y `rec` lo que devolvió HumahuacaProgress.record_result(); los dos pueden venir incompletos.
func show_report(rep: Dictionary, rec: Dictionary, retry_options: Array) -> void:
	var victory := str(rep.get("status", "")) == "victory"
	var b := _frame("parte", 1040.0 if victory else 720.0, false)
	var title_text := str(rep.get("outcome_title", ""))
	if title_text == "":
		title_text = _t("report.title_victory", "Se cumplió el golpe") if victory else _t("report.title_defeat", "No se logró el golpe")
	_title(b, title_text, 26)
	var record := str(rec.get("record_line", ""))
	if record != "":
		Kit.label(b, record, 14, Kit.GOLD, true)
	var cause := str(rep.get("cause", rec.get("cause", "")))
	if victory:
		_victory_body(b, rep, rec, cause)
	else:
		_defeat_body(b, rep, rec, cause)
	var facts := _facts_row(b, rep, rec)
	if facts != null:
		pass
	var row := _buttons(b)
	row.name = "HxReportButtons"
	if victory:
		_btn(row, _t("report.diary", "Diario"), "normal", func(): _fire("pause_diary"))
		_btn(row, _t("report.menu", "Menú"), "normal", func(): _fire("pause_menu"))
		if bool(rec.get("next_available", false)):
			var nb := _btn(row, str(rec.get("next_label", _t("report.next_label", "Ver la campaña completa: Sostener el norte"))), "normal", func(): _fire("go_norte"))
			nb.name = "HxNext"
		var again := _btn(row, _t("report.play_again", "Jugar de nuevo"), "primary", func(): _fire("retry", "mismo_mundo"))
		again.name = "HxRetry"
	else:
		_btn(row, _t("report.menu", "Menú"), "normal", func(): _fire("pause_menu"))
		_btn(row, _t("report.diary", "Diario"), "normal", func(): _fire("pause_diary"))
		_btn(row, _t("report.new_world", "Mundo nuevo"), "normal", func(): _fire("ask_new_world"))
		for o in retry_options:
			var od := o as Dictionary
			var oid := str(od.get("id", ""))
			if oid in ["posiciones", "salida"] and bool(od.get("available", false)):
				_btn(row, str(od.get("label", oid)), "normal", func(): _fire("retry", oid))
		var retry := _btn(row, _t("report.retry", "Reintentar"), "primary", func(): _fire("retry", "mismo_mundo"))
		retry.name = "HxRetry"


func _facts_row(b: Control, rep: Dictionary, rec: Dictionary) -> Control:
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
	var row := Kit.hbox(b, 12)
	row.name = "HxFacts"
	var parts := [_t("report.fact_fronts", "Frentes tomados: %d de 3") % taken, _t("report.fact_golpe", "Golpe: %d de 100") % int(round(golpe)),
		_t("report.fact_losses", "Bajas: %d %%") % int(round(losses)), _t("report.fact_time", "Tiempo: %s") % Kit.mmss(elapsed)]
	for p in parts:
		var chip := Kit.panel(row, Color(0.13, 0.16, 0.1, 1.0), Kit.PANEL_BORDER, 10.0, 4.0, 5)
		var l := Kit.label(chip, str(p), 14, Kit.PAPER)
		l.clip_text = false
	return row


func _defeat_body(b: Control, rep: Dictionary, rec: Dictionary, cause: String) -> void:
	Kit.label(b, cause, 18, Kit.PAPER, true).name = "HxCause"
	var advice := str(rep.get("advice", rec.get("advice", "")))
	if advice != "":
		var al := Kit.label(b, "%s: %s" % [_t("report.advice", "Consejo"), advice], 16, Kit.GOLD, true)
		al.name = "HxAdvice"
	var hint := str(rec.get("hint", ""))
	if hint != "" and hint != advice:
		Kit.label(b, hint, 14, Kit.MUTED, true)
	# la historia queda colapsada
	var history: Variant = rep.get("history", [])
	if history is Array and not (history as Array).is_empty():
		var holder := Kit.vbox(b, 4)
		var toggle := Kit.button(holder, _t("report.less", "Ocultar la historia") if history_open else _t("report.more", "Ver la historia del combate"), 13, "normal", "dialogo")
		toggle.name = "HxHistoryToggle"
		toggle.pressed.connect(func(): _fire("history_toggle"))
		if history_open:
			for h in history:
				_note(holder, {"texto": str((h as Dictionary).get("text", "")), "tag": str((h as Dictionary).get("tag", "diseno"))}, 13)


func _victory_body(b: Control, rep: Dictionary, rec: Dictionary, cause: String) -> void:
	var cols := Kit.hbox(b, 22)
	var left := Kit.vbox(cols, 6)
	left.custom_minimum_size.x = 300.0
	var medal := str(rep.get("medal_label", rec.get("medal_label", "")))
	if medal != "":
		var ml := Kit.label(left, medal, 22, Kit.GOLD, true)
		ml.name = "HxMedal"
	Kit.label(left, cause, 16, Kit.PAPER, true).name = "HxCause"
	var best := str(rec.get("record_line", ""))
	if best == "":
		var bm := str(rec.get("medal", rep.get("medal", "")))
		Kit.label(left, _t("report.best_medal", "Mejor medalla: %s") % (bm if bm != "" else _t("report.no_medal", "todavía sin medalla")), 14, Kit.MUTED, true)
	var assists: Variant = rep.get("assists_used", [])
	if assists is Array and not (assists as Array).is_empty():
		Kit.label(left, _t("report.assists", "Ayudas usadas: %s") % ", ".join(PackedStringArray(assists)), 13, Kit.MUTED, true)
	var right := Kit.vbox(cols, 4)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Kit.label(right, _t("report.epilogue_title", "Qué pasó después"), 15, Kit.GOLD)
	for line in rep.get("epilogue", []):
		var d := line as Dictionary
		var tag := str(d.get("tag", "documentado"))
		var text := str(d.get("texto", ""))
		var rt := RichTextLabel.new()
		rt.bbcode_enabled = true
		rt.fit_content = true
		rt.scroll_active = false
		rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rt.add_theme_font_size_override("normal_font_size", 13)
		rt.add_theme_font_size_override("bold_font_size", 13)
		rt.add_theme_color_override("default_color", Kit.PAPER)
		var marker := "En tu partida:"
		var cut := text.find(marker)
		var body_text := text.replace("[", "[lb]")
		if cut >= 0:
			body_text = text.substr(0, cut).strip_edges().replace("[", "[lb]") + "\n[color=%s]%s[/color]" % [Kit.hex(Kit.GOOD), text.substr(cut).replace("[", "[lb]")]
		rt.text = "[color=%s]%s[/color] [color=%s]%s[/color]  %s" % [Kit.hex(Kit.GOLD), str(d.get("fecha", "")), Kit.hex(Kit.tag_color(ui.source_tags, tag)), Kit.tag_glyph(ui.source_tags, tag), body_text]
		right.add_child(rt)
	var note: Variant = ui.call("time_note")
	if note is Dictionary:
		_note(right, note, 13)
