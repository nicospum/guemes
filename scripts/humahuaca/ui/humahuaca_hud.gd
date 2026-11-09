extends RefCounted
## HUD de una mirada del nivel «humahuaca» (CONTRATO 3.5). SOLO PINTA: todo lo que dice sale de hud_state() (lo que le pasa el controlador) y de
## los textos de humahuaca_ui.json; no recalcula reglas. Qué dibuja:
##   · arriba: título, indicador permanente «TIEMPO REAL · ▶ ×1» / «‖ EN PAUSA» con pausa y velocidades, fase, reloj y barra del alba, ayuda y menú;
##     debajo, a la derecha, las tres tarjetas de frente (batería, cuartel y pólvora);
##   · abajo, UNA columna (HxBottom) que crece hacia arriba y en la que nada se pisa (H-R1-7): los avisos de pie (un aviso a la vez y la línea roja de las capas que
##     corren en su versión mínima), la barra de órdenes y el dock. La barra (HxBar) solo existe mientras hay algo que decir o hacer con la selección: las acciones
##     (fluyen a una segunda línea si no entran), los ritmos al apuntar, la línea de motivo de alto fijo (para que los botones no se muevan bajo el cursor) y el estado
##     de la señal y la torre. El dock tiene tres filas de alto fijo: el objetivo (una línea) con los chips, UN «siguiente paso» con su botón (en su propia fila y de
##     dos líneas como máximo) y las cinco fichas de agrupación (teclas 1 a 5);
##   · una alerta a la vez, debajo de la cabecera y los frentes.
## Los paneles NO van sobre los laterales: las fichas de la zona de partida quedan contra el borde izquierdo del cuadro inicial (BACKLOG B-021).
## Los controles que no son botones (fichas y tarjetas) se eligen con el mouse pero no cuentan como «controles accionables» del primer cuadro.

const Kit = preload("res://scripts/humahuaca/ui/humahuaca_ui_kit.gd")
const U = preload("res://scripts/humahuaca/ui/vocab_ui.gd")
const V = preload("res://scripts/humahuaca/humahuaca_vocab.gd")
## Los lugares del aviso, en el orden en que se prueban: debajo de los frentes al centro, a la derecha o a la izquierda. Queda en el primero que no tape una ficha.
const ALERT_SLOTS := ["centro", "derecha", "izquierda"]

var root: Control
var texts: Dictionary = {}
var layout: Dictionary = {}
var tags: Dictionary = {}
var emit: Callable = Callable()
var title_font: Font = null

var header: PanelContainer
var title_l: Label
var clock_l: Label
var btn_pause: Button
var btn_speed: Array = []
var phase_l: Label
var reloj_l: Label
var dawn_bar: ProgressBar
var btn_help: Button
var btn_menu: Button

var fronts_box: HBoxContainer
var front_cards: Dictionary = {}

var bottom: VBoxContainer
var notice_row: HBoxContainer
var bar: PanelContainer
var motive_row: HBoxContainer
var dock: PanelContainer
var objective_l: Label
var objective_row: HBoxContainer
var chips_box: HBoxContainer
var chip_labels: Dictionary = {}
var next_title_l: Label
var next_text_l: Label
var next_btn: Button
var suggest_btn: Button
var fast4_btn: Button
var look_btn: Button
var actions_box: HFlowContainer
var pace_box: HBoxContainer
var pace_btns: Dictionary = {}
var motive_l: Label
var status_l: Label
var cards_box: HBoxContainer
var group_cards: Dictionary = {}

var alert_panel: PanelContainer
var alert_title_l: Label
var alert_text_l: Label
var alert_btn: Button
var alert_count_l: Label
var toast_panel: PanelContainer
var toast_l: Label
var warn_panel: PanelContainer
var warn_l: Label

var _minimap_w := 260.0
var vignette: ColorRect  # la viñeta común (0,32 en juego): debajo de todo el HUD, no toma clics
var _action_sig := ""
var _action_buttons: Dictionary = {}
var _alert_data: Dictionary = {}
var _alert_outer: Control = null  ## Q-206: la tarjeta de aviso pone el botón a la derecha del texto si es ancha (≥ layout.alert_inline_min_w, 480 px) o debajo si es angosta
var _alert_col: Control = null
var _alert_btn_box: Control = null
var _alert_slot := "centro"


# ---------------------------------------------------------------------------------------------------------------------
# Construcción

func _num(path: Array, fallback: float) -> float:
	var cur: Variant = layout
	for part in path:
		if cur is Dictionary and (cur as Dictionary).has(part):
			cur = cur[part]
		else:
			return fallback
	return float(cur) if (typeof(cur) == TYPE_INT or typeof(cur) == TYPE_FLOAT) else fallback


func _vec(key: String, fallback: Vector2) -> Vector2:
	var v: Variant = layout.get(key, null)
	if v is Array and (v as Array).size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	return fallback


func _t(path: String, fallback: String = "") -> String:
	var cur: Variant = texts
	for part in path.split("."):
		if cur is Dictionary and (cur as Dictionary).has(part):
			cur = cur[part]
		else:
			return fallback
	return str(cur) if typeof(cur) == TYPE_STRING else fallback


func _anchor(c: Control, a_left: float, a_top: float, a_right: float, a_bottom: float, o_left: float, o_top: float, o_right: float, o_bottom: float) -> void:
	c.anchor_left = a_left
	c.anchor_top = a_top
	c.anchor_right = a_right
	c.anchor_bottom = a_bottom
	c.offset_left = o_left
	c.offset_top = o_top
	c.offset_right = o_right
	c.offset_bottom = o_bottom


func build(parent: Control, texts_in: Dictionary, layout_in: Dictionary, tags_in: Dictionary, emit_in: Callable, font_in: Font, minimap_w: float) -> void:
	texts = texts_in
	layout = layout_in
	tags = tags_in
	emit = emit_in
	title_font = font_in
	_minimap_w = minimap_w
	root = Control.new()
	root.name = "HumahuacaHud"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(root)
	vignette = Kit.vignette(_num(["vignette", "play"], 0.32))
	root.add_child(vignette)
	_build_header()
	_build_fronts()
	_build_bottom(minimap_w)
	_build_alert()


func _build_header() -> void:
	var m := _num(["margin"], 12.0)
	var fs := int(_num(["font", "body"], 15.0))
	header = Kit.panel(root, Kit.PANEL_BG, Kit.PANEL_BORDER, 12.0, 4.0)
	header.name = "HxHeader"
	# franja translúcida con un filete de oro abajo, sin caja (dirección de arte §2.5: «cabecera de franja, sin caja»)
	var hs := Kit.style(Color(Kit.INK_PANEL, 0.90), Kit.FILET, 0, Kit.RADIUS, 12.0, 4.0)
	hs.border_width_bottom = 1
	hs.border_color = Kit.FILET
	header.add_theme_stylebox_override("panel", hs)
	# Q-206 (QA ronda 2): la cabecera era una franja de punta a punta (≈ 6 % del cuadro a 1280 × 720 con mapa vacío en el medio); ahora mide lo que su contenido
	# (ancho 0 con anclas a la izquierda: el contenedor crece hasta su mínimo), con los mismos datos y botones
	_anchor(header, 0.0, 0.0, 0.0, 0.0, m, m, m, m + _num(["header_h"], 46.0))
	header.custom_minimum_size.y = _num(["header_h"], 46.0)
	var row := Kit.hbox(header, 14)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	title_l = Kit.label(row, "", int(_num(["font", "title"], 17.0)), Kit.GOLD)
	title_l.name = "HxTitle"
	title_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if title_font != null:
		title_l.add_theme_font_override("font", Kit.spaced(title_font, 2))
	var time_box := Kit.hbox(row, 6)
	time_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	clock_l = Kit.label(time_box, "", fs, Kit.GOLD)
	clock_l.name = "HxClock"
	clock_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	clock_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn_pause = Kit.button(time_box, _t("time.pause", "‖"), fs, "normal", "tiempo")
	btn_pause.name = "HxPause"
	btn_pause.custom_minimum_size = Vector2(34.0, 30.0)
	btn_pause.tooltip_text = _t("time.pause_tip")
	btn_pause.pressed.connect(func(): _fire("pause"))
	var names: Array = texts.get("time", {}).get("speeds", ["×1", "×2", "×4"])
	for i in range(names.size()):
		var b := Kit.button(time_box, str(names[i]), fs - 1, "normal", "tiempo")
		b.name = "HxSpeed%d" % i
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(34.0, 30.0)
		b.tooltip_text = _t("time.speed_tip")
		b.pressed.connect(func(): _fire("speed", i))
		btn_speed.append(b)
	Kit.spacer(row, false, _num(["header_gap"], 22.0))
	var phase_box := Kit.vbox(row, 0)
	phase_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	phase_l = Kit.label(phase_box, "", fs, Kit.PAPER)
	phase_l.name = "HxPhase"
	phase_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	reloj_l = Kit.label(phase_box, "", int(_num(["font", "small"], 13.0)), Kit.MUTED)
	reloj_l.name = "HxReloj"
	reloj_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	dawn_bar = Kit.bar(row, Kit.GOLD, 8.0, 0.0)
	dawn_bar.name = "HxAlba"
	dawn_bar.custom_minimum_size = Vector2(120.0, 8.0)
	dawn_bar.size_flags_horizontal = Control.SIZE_SHRINK_END
	dawn_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dawn_bar.tooltip_text = _t("hud.dawn_tip")
	dawn_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	Kit.spacer(row, false, _num(["header_gap"], 22.0))
	var sys := Kit.hbox(row, 6)
	sys.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn_help = Kit.button(sys, _t("hud.help", "?"), fs, "normal", "sistema")
	btn_help.name = "HxHelp"
	btn_help.custom_minimum_size = Vector2(34.0, 30.0)
	btn_help.tooltip_text = _t("hud.help_tip")
	btn_help.pressed.connect(func(): _fire("help"))
	btn_menu = Kit.button(sys, _t("hud.menu", "Menú"), fs, "normal", "sistema")
	btn_menu.name = "HxMenu"
	btn_menu.custom_minimum_size = Vector2(0.0, 30.0)
	btn_menu.tooltip_text = _t("hud.menu_tip")
	btn_menu.pressed.connect(func(): _fire("menu"))


func _build_fronts() -> void:
	var m := _num(["margin"], 12.0)
	var gap := _num(["gap"], 8.0)
	var card := _vec("fronts_card", Vector2(212.0, 56.0))
	fronts_box = Kit.hbox(root, int(gap))
	fronts_box.name = "HxFronts"
	var total_w := card.x * 3.0 + gap * 2.0
	_anchor(fronts_box, 1.0, 0.0, 1.0, 0.0, -(m + total_w), m + _num(["header_h"], 46.0) + gap, -m, m + _num(["header_h"], 46.0) + gap + card.y)
	fronts_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	for id in V.OBJECTIVES:
		var p := Kit.panel(fronts_box, Kit.PANEL_BG, Kit.PANEL_BORDER, 8.0, 4.0, 6)
		p.name = "HxFront_%s" % id
		p.custom_minimum_size = card
		p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		p.gui_input.connect(func(ev: InputEvent): _card_input(ev, "front", str(id)))
		var row := Kit.hbox(p, 6)
		var accent := ColorRect.new()
		accent.color = Kit.ROYAL
		accent.custom_minimum_size = Vector2(4.0, 0.0)
		accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(accent)
		var col := Kit.vbox(row, 1)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var line1 := Kit.hbox(col, 6)
		var name_l := Kit.trimmed(Kit.label(line1, "", int(_num(["font", "body"], 15.0)), Kit.PAPER))
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var guard_l := Kit.label(line1, "", int(_num(["font", "tiny"], 12.0)), Kit.MUTED, false, HORIZONTAL_ALIGNMENT_RIGHT)
		guard_l.clip_text = false
		var take_bar := Kit.bar(col, Kit.GOLD, 7.0, 0.0)  # cuánto del objetivo se tomó: oro (el objetivo); el filete rojo de la izquierda es la guardia enemiga
		var alert_bar := Kit.bar(col, Kit.AMBER, 3.0, 0.0)
		var info_l := Kit.trimmed(Kit.label(col, "", int(_num(["font", "tiny"], 12.0)), Kit.GOLD))  # no ensancha la tarjeta: si no entra se sacan partes (_fit_parts)
		info_l.visible = false
		front_cards[id] = {"panel": p, "accent": accent, "name": name_l, "guard": guard_l, "take": take_bar, "alert": alert_bar, "info": info_l}


## La columna de abajo: los avisos de pie arriba, la barra de órdenes en el medio y el dock debajo. Crece hacia arriba y no deja que nada se pise: ni la barra ni el dock
## quedan debajo de un aviso (H-R1-7). Lo que cambia de alto (aviso y barra) está siempre encima de lo que no: el dock no se mueve.
func _build_bottom(minimap_w: float) -> void:
	var m := _num(["margin"], 12.0)
	bottom = Kit.vbox(root, int(_num(["notice_gap"], 4.0)))
	bottom.name = "HxBottom"
	_anchor(bottom, 0.0, 1.0, 1.0, 1.0, m, -(m + 1.0), -(minimap_w + 2.0 * m), -m)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	notice_row = Kit.hbox(bottom, 8)
	notice_row.name = "HxNotices"
	notice_row.visible = false
	_build_toast(notice_row)
	_build_warn(notice_row)
	_build_bar(bottom)
	_build_dock(bottom)
	root.resized.connect(_fit_bottom)
	_fit_bottom.call_deferred()  # si la raíz ya nace con su tamaño final (ventanas de 1440 × 900 o más) no llega ningún «resized»


## En ventanas anchas el dock no se estira de punta a punta (V-06: «el mapa es el protagonista»): mide a lo sumo `layout.dock_max_w` píxeles lógicos y queda en la
## esquina de abajo a la izquierda; el resto del borde inferior es mapa. A 1280 × 720 y menos no cambia nada (el dock ya es más angosto que el tope).
func _fit_bottom() -> void:
	if bottom == null or root == null:
		return
	var m := _num(["margin"], 12.0)
	var full := -(_minimap_w + 2.0 * m)
	var cap := _num(["dock_max_w"], 0.0)
	var right := full
	if cap > 0.0 and root.size.x > 0.0:
		right = minf(full, -(root.size.x - m - cap))
	bottom.offset_right = right


## Ancho que ocupa la columna de abajo (dock, barra y avisos), en píxeles lógicos del HUD.
func bottom_width() -> float:
	var m := _num(["margin"], 12.0)
	var full := root.size.x - _minimap_w - 3.0 * m
	var cap := _num(["dock_max_w"], 0.0)
	return minf(full, cap) if cap > 0.0 else full


## La barra de órdenes: la línea de motivo con el estado de la señal (arriba, solo mientras hay algo que decir) y, debajo, las acciones de la selección con los ritmos de
## marcha al apuntar. Como la columna crece hacia arriba, lo que aparece o desaparece arriba no mueve los botones: no se mueven bajo el cursor.
func _build_bar(parent: Control) -> void:
	var small := int(_num(["font", "small"], 13.0))
	bar = Kit.panel(parent, Kit.PANEL_BG, Kit.PANEL_BORDER, 12.0, 4.0)
	bar.name = "HxBar"
	bar.visible = false
	var col := Kit.vbox(bar, 2)
	motive_row = Kit.hbox(col, 10)
	motive_row.name = "HxMotiveRow"
	motive_row.custom_minimum_size.y = 18.0
	motive_row.visible = false
	motive_l = Kit.label(motive_row, "", small, Kit.GOLD, true)  # si el motivo y el estado de la señal no entran juntos, el motivo sigue en otra línea (hacia arriba): nunca ensancha la columna
	motive_l.name = "HxMotive"
	motive_l.custom_minimum_size = Vector2(280.0, 18.0)  # con menos ancho el primer cuadro de una frase larga saldría muy alto
	motive_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_l = Kit.label(motive_row, "", int(_num(["font", "tiny"], 12.0)), Kit.MUTED, false, HORIZONTAL_ALIGNMENT_RIGHT)
	status_l.name = "HxStatus"
	status_l.size_flags_horizontal = Control.SIZE_SHRINK_END
	status_l.clip_text = false
	status_l.mouse_filter = Control.MOUSE_FILTER_PASS
	status_l.tooltip_text = _t("hud.status_tip")  # B-052: nadie entendía «Desvelo»
	actions_box = HFlowContainer.new()
	actions_box.name = "HxActions"
	actions_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions_box.add_theme_constant_override("h_separation", 6)
	actions_box.add_theme_constant_override("v_separation", 3)
	actions_box.custom_minimum_size.y = _num(["actions_h"], 32.0)
	col.add_child(actions_box)
	pace_box = Kit.hbox(actions_box, 4)
	pace_box.name = "HxPace"
	pace_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pace_box.visible = false
	var pace_names: Dictionary = texts.get("actions", {}).get("pace", {})
	for pid in U.PACE_ORDER:
		var pb := Kit.button(pace_box, str(pace_names.get(pid, pid)), small, "normal", "ritmo")
		pb.name = "HxPace_%s" % pid
		pb.toggle_mode = true
		pb.custom_minimum_size = Vector2(0.0, 28.0)
		pb.pressed.connect(func(): _fire("pace", pid))
		pace_btns[pid] = pb


func _build_dock(parent: Control) -> void:
	var fs := int(_num(["font", "body"], 15.0))
	var small := int(_num(["font", "small"], 13.0))
	dock = Kit.panel(parent, Kit.PANEL_BG, Kit.PANEL_BORDER, 12.0, 5.0)
	dock.name = "HxDock"
	dock.custom_minimum_size.y = _num(["dock_h"], 136.0)
	var col := Kit.vbox(dock, 3)
	# fila A: objetivo y chips
	var row_a := Kit.hbox(col, 10)
	row_a.name = "HxGoalRow"
	objective_row = row_a
	objective_l = Kit.trimmed(Kit.label(row_a, "", small, Kit.MUTED))  # una sola línea siempre: si los chips de la extracción le quitan lugar se recorta con «…» (la frase entera, en el cartel) y el panel no cambia de alto según la fase
	objective_l.name = "HxObjective"
	objective_l.custom_minimum_size = Vector2(80.0, 18.0)
	objective_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	objective_l.mouse_filter = Control.MOUSE_FILTER_PASS
	chips_box = Kit.hbox(row_a, 6)
	chips_box.size_flags_horizontal = Control.SIZE_SHRINK_END
	for id in ["golpe", "carga", "refuerzo"]:
		var chip := Kit.panel(chips_box, Kit.CHIP_BG, Kit.PANEL_BORDER, 6.0, 1.0)
		var l := Kit.label(chip, "", int(_num(["font", "tiny"], 12.0)), Kit.PAPER)
		l.clip_text = false
		chip.tooltip_text = _t("hud.chip_tips." + str(id))  # B-052: nadie entendía «Golpe»
		chip.visible = false
		chip_labels[id] = {"panel": chip, "label": l}
	# fila B: el «siguiente paso» en su propia fila, a todo el ancho del dock y de dos líneas como máximo (H-R1-7: antes compartía la fila con las acciones y quedaba en
	# una columna de 60 px)
	var row_b := Kit.hbox(col, 10)
	row_b.name = "HxNextRow"
	row_b.custom_minimum_size.y = _num(["next_h"], 40.0)
	next_title_l = Kit.label(row_b, _t("hud.next_title", "Siguiente paso"), small, Kit.GOLD)
	next_title_l.name = "HxNextTitle"
	next_title_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	next_title_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	next_text_l = Kit.label(row_b, "", fs, Kit.PAPER, true)
	next_text_l.name = "HxNextText"
	next_text_l.custom_minimum_size = Vector2(_num(["next_min_w"], 300.0), _num(["next_h"], 40.0) - 2.0)  # 300 px alcanzan para 72 caracteres en dos líneas
	next_text_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	next_text_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	next_btn = Kit.button(row_b, "", fs, "primary", "accion:siguiente")
	next_btn.name = "HxNextButton"
	next_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	next_btn.pressed.connect(func(): _fire("next"))
	next_btn.visible = false
	suggest_btn = Kit.button(row_b, _t("time.suggest_button", "Acelerar ×2"), small, "normal", "tiempo")
	suggest_btn.name = "HxSuggest"
	suggest_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	suggest_btn.pressed.connect(func(): _fire("speed", 1))
	suggest_btn.visible = false
	fast4_btn = Kit.button(row_b, _t("time.wait_x4", "×4"), small, "normal", "tiempo")
	fast4_btn.name = "HxFast4"
	fast4_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fast4_btn.tooltip_text = _t("time.speed_tip")
	fast4_btn.pressed.connect(func(): _fire("speed", 2))
	fast4_btn.visible = false
	look_btn = Kit.button(row_b, _t("hud.wait.look", "Mirar"), small, "normal", "mirar")
	look_btn.name = "HxLook"
	look_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	look_btn.tooltip_text = _t("hud.wait.look_tip")
	look_btn.pressed.connect(func(): _fire("look"))
	look_btn.visible = false
	row_b.move_child(look_btn, suggest_btn.get_index())
	# fila C: las cinco agrupaciones
	cards_box = Kit.hbox(col, 6)
	cards_box.name = "HxCards"
	var gc := _vec("group_card", Vector2(142.0, 58.0))
	for id in V.GROUPS:
		_make_group_card(str(id), gc)


func _make_group_card(id: String, size: Vector2) -> void:
	var p := Kit.panel(cards_box, Kit.CARD_BG, Kit.PANEL_BORDER, 5.0, 3.0)
	p.name = "HxCard_%s" % id
	p.custom_minimum_size = Vector2(minf(size.x, 96.0), size.y)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	p.tooltip_text = _t("hud.group_tip")
	p.gui_input.connect(func(ev: InputEvent): _card_input(ev, "card", id))
	var row := Kit.hbox(p, 4)
	var accent := ColorRect.new()
	accent.color = Kit.NEUTRAL if id == "arreo" else Kit.PATRIOT
	accent.custom_minimum_size = Vector2(3.0, 0.0)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(accent)
	var col := Kit.vbox(row, 1)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# H-R1-10: a 1024 × 640 la ficha mide ≈ 136 px. El nombre («Reconocedores» pide 97) tiene la fila entera para él: la etiqueta de fuente y el ruido van abajo, junto a las barras
	var line1 := Kit.hbox(col, 4)
	var key_l := Kit.label(line1, str(V.GROUPS.find(id) + 1), int(_num(["font", "body"], 15.0)), Kit.GOLD)
	key_l.clip_text = false
	var name_l := Kit.trimmed(Kit.label(line1, "", int(_num(["font", "small"], 13.0)), Kit.PAPER))
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var stage_l := Kit.trimmed(Kit.label(col, "", int(_num(["font", "tiny"], 12.0)), Kit.MUTED))
	stage_l.custom_minimum_size.y = 15.0
	var foot := Kit.hbox(col, 4)
	foot.custom_minimum_size.y = 15.0  # alto fijo: las barras no suben ni bajan cuando aparecen o se van la etiqueta y el ruido
	var bars := Kit.vbox(foot, 2)
	bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bar_force := Kit.bar(bars, Kit.PATRIOT if id != "arreo" else Kit.NEUTRAL, 5.0, 100.0)
	var bar_tired := Kit.bar(bars, Kit.AMBER, 3.0, 0.0)
	var tag_l := Kit.label(foot, "", int(_num(["font", "tiny"], 12.0)), Kit.PAPER)
	tag_l.clip_text = false
	tag_l.visible = false
	tag_l.mouse_filter = Control.MOUSE_FILTER_PASS  # B-052: nadie entendía el triángulo ni los puntos; cada uno explica qué es al pasar el mouse
	var noise_l := Kit.label(foot, "", int(_num(["font", "tiny"], 12.0)), Kit.MUTED)
	noise_l.clip_text = false
	noise_l.visible = false
	noise_l.mouse_filter = Control.MOUSE_FILTER_PASS
	group_cards[id] = {"panel": p, "name": name_l, "tag": tag_l, "noise": noise_l, "stage": stage_l, "force": bar_force, "tired": bar_tired, "key": key_l}


func _build_alert() -> void:
	var m := _num(["margin"], 12.0)
	var gap := _num(["gap"], 8.0)
	var w := _num(["alert_w"], 520.0)
	alert_panel = Kit.panel(root, Kit.WARN_BG, Kit.WARN_BORDER, 14.0, 8.0, 8)
	alert_panel.name = "HxAlert"
	var top := m + _num(["header_h"], 46.0) + gap + _vec("fronts_card", Vector2(212.0, 56.0)).y + gap
	_anchor(alert_panel, 0.0, 0.0, 0.0, 0.0, 0.0, top, w, top + 1.0)  # el lugar lo elige place_alert; la altura la da el contenido
	alert_panel.grow_vertical = Control.GROW_DIRECTION_END
	# Q-206 (QA ronda 2): el botón y la cuenta van a la derecha del texto, no debajo: la tarjeta es más ancha y bastante más baja (a 1280 × 720 tapaba 6 % del
	# cuadro en el ataque); el texto es el mismo
	var outer := Kit.hbox(alert_panel, 12)
	var col := Kit.vbox(outer, 3)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	alert_title_l = Kit.label(col, "", int(_num(["font", "body"], 15.0)) + 1, Kit.WARN_TEXT, true)
	alert_text_l = Kit.label(col, "", int(_num(["font", "small"], 13.0)), Kit.WARN_TEXT, true)
	var row := Kit.vbox(outer, 4)
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_alert_outer = outer
	_alert_col = col
	_alert_btn_box = row
	alert_btn = Kit.button(row, "", int(_num(["font", "body"], 15.0)), "primary", "accion:alerta")
	alert_btn.name = "HxAlertButton"
	alert_btn.pressed.connect(func(): _fire("alert"))
	alert_count_l = Kit.label(row, "", int(_num(["font", "small"], 13.0)), Kit.WARN_TEXT, false, HORIZONTAL_ALIGNMENT_CENTER)
	alert_count_l.clip_text = false
	alert_panel.visible = false


func _build_toast(parent: Control) -> void:
	toast_panel = Kit.panel(parent, Kit.PANEL_BG, Kit.GOLD, 12.0, 5.0, 6)
	toast_panel.name = "HxToast"
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.custom_minimum_size.x = _num(["toast_w"], 440.0)
	toast_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	toast_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	toast_l = Kit.label(toast_panel, "", int(_num(["font", "body"], 15.0)), Kit.PAPER, true)
	toast_panel.visible = false


func _build_warn(parent: Control) -> void:
	warn_panel = Kit.panel(parent, Kit.WARN_BG, Kit.WARN_BORDER, 12.0, 4.0, 6)
	warn_panel.name = "HxWarn"
	warn_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	warn_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	warn_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	warn_l = Kit.label(warn_panel, "", int(_num(["font", "small"], 13.0)), Kit.WARN_TEXT, true)
	warn_panel.visible = false


func _fire(kind: String, arg: Variant = null) -> void:
	if emit.is_valid():
		emit.call(kind, arg)


func _card_input(ev: InputEvent, kind: String, id: String) -> void:
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_fire(kind, {"id": id, "shift": Input.is_key_pressed(KEY_SHIFT), "ctrl": Input.is_key_pressed(KEY_CTRL)})


# ---------------------------------------------------------------------------------------------------------------------
# Pintado (solo hud_state y el contexto del controlador)

func refresh(hs: Dictionary, ctx: Dictionary) -> void:
	if root == null:
		return
	_refresh_header(hs, ctx)
	_refresh_fronts(hs)
	_refresh_dock(hs, ctx)
	_refresh_groups(hs, ctx)
	_refresh_alert(ctx)
	_refresh_toast(ctx)
	_refresh_warn(ctx)
	_fit_bar()


func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


func _refresh_header(hs: Dictionary, ctx: Dictionary) -> void:
	title_l.text = _t("title", "Humahuaca")
	var paused := bool(ctx.get("paused", true))
	var speed := int(ctx.get("speed", 1.0))
	var pattern := _t("clock_running", "Tiempo real · ▶ ×%d")
	var shown := _t("clock_paused", "‖ En pausa") if paused else (pattern % speed if pattern.find("%d") >= 0 else pattern)
	clock_l.text = shown.to_upper()  # el contrato fija «TIEMPO REAL · ▶ ×1» y «‖ EN PAUSA»; en el JSON van en minúsculas para que ninguna cadena quede entera en mayúsculas
	btn_pause.text = _t("time.play", "▶") if paused else _t("time.pause", "‖")
	for i in range(btn_speed.size()):
		(btn_speed[i] as Button).set_pressed_no_signal(not paused and absi(speed - [1, 2, 4][i]) == 0)
	var fase := _dict(hs.get("fase"))
	var phase_name := str(fase.get("nombre", ""))
	if phase_name == "":
		phase_name = _t("phase_names." + str(ctx.get("phase", "briefing")), "")
	phase_l.text = phase_name
	reloj_l.text = str(fase.get("reloj", ""))
	dawn_bar.value = 100.0 * clampf(float(_dict(hs.get("alba")).get("progreso", 0.0)), 0.0, 1.0)


func _refresh_fronts(hs: Dictionary) -> void:
	var list: Variant = hs.get("frentes", [])
	if not (list is Array):
		return
	for f in list:
		var d := _dict(f)
		var id := str(d.get("id", ""))
		if not front_cards.has(id):
			continue
		var c: Dictionary = front_cards[id]
		(c.name as Label).text = str(d.get("nombre", id))
		var guard := _dict(d.get("guardia"))
		if bool(guard.get("conocida", false)):
			(c.guard as Label).text = _t("hud.guard_known", "Guardia %d") % int(guard.get("min", 0))
		else:
			(c.guard as Label).text = _t("hud.guard_unknown", "Guardia ?")
		var taken := str(d.get("estado", "")) == "tomado"
		(c.take as ProgressBar).value = float(d.get("toma_pct", 0.0))
		Kit.recolor_bar(c.take as ProgressBar, Kit.GOOD if taken else Kit.GOLD)
		(c.alert as ProgressBar).value = 100.0 * clampf(float(d.get("alerta", 0.0)), 0.0, 1.0)
		(c.accent as ColorRect).color = Kit.GOOD if taken else Kit.ROYAL
		var parts: Array = []  # en orden de importancia: si no entran todas se sacan del final (la toma ya la dice la barra de arriba; la sorpresa, no)
		var state := str(d.get("estado", "guardado"))
		if state != "guardado":
			parts.append(str(d.get("estado_txt", state)))
		if float(d.get("sorpresa_s", 0.0)) > 0.0:
			parts.append(_t("hud.surprise", "Sorpresa %s") % Kit.mmss(float(d.get("sorpresa_s", 0.0))))
		if float(d.get("toma_pct", 0.0)) > 0.0 and not taken:
			parts.append(_t("hud.take", "Toma %d %%") % int(round(float(d.get("toma_pct", 0.0)))))
		var support: Variant = d.get("apoyo", [])
		if support is Array and not (support as Array).is_empty():
			var names: Array = []
			for sid in support:
				names.append(_short_name(str(sid)))
			parts.append(_t("hud.support", "Apoyo de %s") % ", ".join(PackedStringArray(names)))
		(c.info as Label).text = _fit_parts(c.info as Label, parts, _vec("fronts_card", Vector2(212.0, 56.0)).x - 24.0)
		(c.info as Label).visible = not parts.is_empty()
		var tag_id := str(d.get("tag", "diseno"))
		var tip := "%s %s" % [Kit.tag_glyph(tags, tag_id), str(Kit.tag_info(tags, tag_id).get("etiqueta", ""))]
		if (c.info as Label).text != " · ".join(PackedStringArray(parts)):
			tip = " · ".join(PackedStringArray(parts)) + "
" + tip  # lo que no entró en la tarjeta queda en el cartel
		tip += "\n" + _t("hud.front_tip")
		(c.panel as Control).tooltip_text = tip


## El nombre corto de una agrupación («Rodríguez»): sale de las tarjetas ya pintadas (que lo tomaron de hud_state).
func _short_name(id: String) -> String:
	if group_cards.has(id):
		return str((group_cards[id].name as Label).text)
	return id


func short_names() -> Dictionary:
	var out := {}
	for id in group_cards:
		out[id] = str((group_cards[id].name as Label).text)
	return out


func _refresh_dock(hs: Dictionary, ctx: Dictionary) -> void:
	var guide := _dict(ctx.get("guide"))
	next_title_l.visible = not guide.is_empty() and str(guide.get("text", "")) != ""
	var next_text := str(guide.get("text", ""))
	var why := str(guide.get("why", ""))
	if why != "" and not bool(guide.get("enabled", true)):
		next_text += " " + why  # B-052: el botón apagado no decía por qué; ahora la causa va junto al paso
	var wait_extra := str(guide.get("wait_extra", ""))
	if wait_extra != "":
		next_text += " (" + wait_extra + ")"
	next_text_l.text = next_text
	var urgency := int(guide.get("urgencia", 0))
	next_text_l.add_theme_color_override("font_color", Kit.WARN_TEXT if urgency >= 2 else Kit.PAPER)
	var button_text := str(guide.get("button", ""))
	next_btn.visible = button_text != ""
	next_btn.text = button_text
	next_btn.disabled = not bool(guide.get("enabled", true))
	var wait_fast := bool(ctx.get("wait_fast", false))
	var spd := float(ctx.get("speed", 1.0))
	suggest_btn.visible = (bool(ctx.get("suggest_x2", false)) or wait_fast) and spd < 2.0
	suggest_btn.text = _t("time.wait_x2", "×2") if wait_fast else _t("time.suggest_button", "Acelerar ×2")
	fast4_btn.visible = wait_fast
	var focus: Variant = guide.get("wait_focus", Vector2.ZERO)
	look_btn.visible = bool(guide.get("wait", false)) and focus is Vector2 and focus != Vector2.ZERO
	# chips: solo cuando ya importan (el golpe desde el ataque; la carga y el refuerzo en la extracción)
	var phase := str(_dict(hs.get("fase")).get("id", ctx.get("phase", "briefing")))
	var chips: Dictionary = {}
	for c in hs.get("chips", []):
		chips[str(_dict(c).get("id", ""))] = _dict(c)
	var refuerzo := _dict(hs.get("refuerzo"))
	for id in chip_labels:
		var info: Dictionary = chip_labels[id]
		var visible_now := false
		match id:
			"golpe":
				visible_now = phase == "ataque" or phase == "extraccion"
			"carga":
				visible_now = phase == "extraccion" or (phase == "ataque" and float(_dict(chips.get("carga")).get("valor", 0.0)) > 0.0)  # el arreo carga desde el ataque (B-053)
			"refuerzo":
				visible_now = phase == "extraccion" or str(refuerzo.get("estado", "desconocido")) in ["visible", "llego"]
		(info.panel as Control).visible = visible_now and chips.has(id)
		if chips.has(id):
			(info.label as Label).text = str(chips[id].get("txt", ""))
	_refresh_objective(hs, phase)  # después de los chips: lo que le queda a la frase depende de cuáles se ven
	_refresh_actions(ctx)
	motive_l.text = str(ctx.get("motive", ""))
	status_l.text = str(ctx.get("status", ""))
	var pace_on := bool(ctx.get("pace_visible", false))
	pace_box.visible = pace_on
	actions_box.visible = pace_on or not _action_buttons.is_empty()
	motive_row.visible = motive_l.text != "" or status_l.text != ""
	bar.visible = actions_box.visible or motive_row.visible  # sin nada que decir ni hacer no ocupa lugar: el primer cuadro queda limpio
	if pace_on:
		var cur := str(ctx.get("pace", "march"))
		for pid in pace_btns:
			(pace_btns[pid] as Button).set_pressed_no_signal(str(pid) == cur)


## Las frases del objetivo de la fase, de la más completa a la más corta. Las reglas dicen una sola frase para todo el nivel (hud_state().objetivo; BACKLOG B-048) y en la
## extracción seguía pidiendo tomar los tres frentes ya tomados (H-R1-10): mientras `texts.objective.source` sea «ui», cada fase usa su propia lista de humahuaca_ui.json;
## con «rules» (cuando las reglas den la frase de cada fase) manda lo que digan ellas. Una fase sin lista usa la frase de las reglas.
func objective_variants(hs: Dictionary, phase: String) -> Array:
	var rules_goal := str(hs.get("objetivo", ""))
	var cfg: Variant = texts.get("objective", {})
	if cfg is Dictionary and str((cfg as Dictionary).get("source", "ui")) == "ui":
		var by_phase: Variant = (cfg as Dictionary).get("by_phase", {})
		if by_phase is Dictionary:
			var own: Variant = (by_phase as Dictionary).get(phase, null)
			var list: Array = []
			if own is Array:
				for v in own:
					if str(v) != "":
						list.append(str(v))
			elif own is String and str(own) != "":
				list.append(str(own))
			if not list.is_empty():
				return list
	return [rules_goal] if rules_goal != "" else []


## Lo que le queda de ancho a la frase del objetivo en su fila: el ancho del dock menos los chips que se ven (golpe, carga y refuerzo). Sale de números del diseño y de
## lo ya medido, no del último reparto de la fila: así vale también en el primer cuadro y apenas cambia la ventana.
func objective_room() -> float:
	var by_design := bottom_width() - 2.0 * 12.0  # el dock va de la izquierda al minimapa (o hasta su tope en ventanas anchas), con 12 px de relleno a cada lado
	var row_w := objective_row.size.x
	var width := minf(by_design, row_w) if row_w >= 160.0 else by_design
	var chips_w := chips_box.get_combined_minimum_size().x
	return maxf(width - chips_w - 10.0, 80.0)


## Pone la frase más completa de la fase que entra entera en lo que le queda a la fila (si ninguna entra, la más corta; el «…» queda de último recurso) y deja la frase
## completa en el cartel que aparece al pasar el mouse.
func _refresh_objective(hs: Dictionary, phase: String) -> void:
	var variants := objective_variants(hs, phase)
	if variants.is_empty():
		objective_l.text = ""
		objective_l.tooltip_text = ""
		return
	var room := objective_room()
	var fnt: Font = objective_l.get_theme_font("font")
	var px: int = objective_l.get_theme_font_size("font_size")
	var pick := str(variants[variants.size() - 1])
	for v in variants:
		if fnt.get_string_size(str(v), HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x <= room - 2.0:
			pick = str(v)
			break
	objective_l.text = pick
	objective_l.tooltip_text = str(variants[0])


func _refresh_actions(ctx: Dictionary) -> void:
	var items: Array = ctx.get("bar_items", [])
	var sig := ""
	for it in items:
		sig += "%s|%s|%s;" % [str(it.action), str(it.ok), str(it.label)]
	if sig == _action_sig:
		return
	_action_sig = sig
	for child in actions_box.get_children():
		if child == pace_box:
			continue  # los ritmos son fijos: solo se muestran u ocultan al apuntar
		actions_box.remove_child(child)
		child.queue_free()
	_action_buttons = {}
	var small := int(_num(["font", "small"], 13.0))
	for it in items:
		var key := str(it.get("key", ""))
		var text := "%s  [%s]" % [str(it.label), key] if key != "" else str(it.label)
		var b := Kit.button(actions_box, text, small + 1, "primary" if bool(it.get("recommended", false)) else "normal", "accion:%s" % str(it.action))
		b.name = "HxAction_%s" % str(it.action)
		b.disabled = not bool(it.ok)
		var act := str(it.action)
		b.pressed.connect(func(): _fire("action", act))
		b.mouse_entered.connect(func(): _fire("hover_action", act))
		b.mouse_exited.connect(func(): _fire("hover_action", ""))
		_action_buttons[act] = b
	actions_box.move_child(pace_box, actions_box.get_child_count() - 1)


## Q-206: la barra de órdenes ocupaba todo el ancho de la columna aunque sus botones llenaran la mitad; ahora mide lo que sus botones (y los ritmos, al apuntar), con
## un mínimo para que el motivo no quede en una columna angosta, y nunca más que la columna. Los botones no cambian de lugar: la barra crece a la derecha.
func _fit_bar() -> void:
	if bar == null or actions_box == null:
		return
	var w := 0.0
	var n := 0
	for child in actions_box.get_children():
		var c := child as Control
		if c != null and c.visible:
			w += c.get_combined_minimum_size().x
			n += 1
	var sep := float(actions_box.get_theme_constant("h_separation"))
	var pad := 26.0
	var want := clampf(w + sep * float(maxi(n - 1, 0)) + pad, _num(["bar_min_w"], 420.0), maxf(bottom_width(), 200.0))
	bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if absf(bar.custom_minimum_size.x - want) > 0.5:
		bar.custom_minimum_size.x = want


func _refresh_groups(hs: Dictionary, ctx: Dictionary) -> void:
	var list: Variant = hs.get("grupos", [])
	if not (list is Array):
		return
	var selected: Array = ctx.get("selected", [])
	for g in list:
		var d := _dict(g)
		var id := str(d.get("id", ""))
		if not group_cards.has(id):
			continue
		var c: Dictionary = group_cards[id]
		var is_sel := selected.has(id)
		(c.name as Label).text = _group_short(id, str(d.get("nombre", id)))
		(c.force as ProgressBar).value = float(d.get("fuerza_pct", 100.0))
		(c.tired as ProgressBar).value = float(d.get("fatiga_pct", 0.0))
		var stage_txt := str(d.get("etapa_txt", ""))
		var idle := stage_txt == "" or (ctx.get("idle_groups", []) as Array).has(id)
		_fit_stage(c.stage as Label, "" if idle else stage_txt, str(_dict(ctx.get("stages")).get(id, "")))
		var noise := str(d.get("ruido", "silencio"))
		(c.noise as Label).text = str(texts.get("hud", {}).get("noise_dots", {}).get(noise, ""))
		(c.noise as Label).visible = noise != "silencio" or is_sel
		(c.noise as Control).tooltip_text = str(texts.get("hud", {}).get("noise", {}).get(noise, ""))
		var tag_id := str(d.get("tag", "diseno"))
		(c.tag as Label).text = Kit.tag_glyph(tags, tag_id)
		(c.tag as Control).tooltip_text = "%s %s: %s" % [Kit.tag_glyph(tags, tag_id), str(Kit.tag_info(tags, tag_id).get("etiqueta", "")), str(Kit.tag_info(tags, tag_id).get("descripcion", ""))]
		(c.tag as Label).add_theme_color_override("font_color", Kit.tag_color(tags, tag_id))
		(c.tag as Label).visible = is_sel
		var alive := bool(d.get("vivo", true))
		var border := Kit.GOLD if is_sel else Kit.PANEL_BORDER
		var bg := Kit.INK_RAISED if is_sel else Kit.CARD_BG
		var card_style := Kit.style(bg, border, 2 if is_sel else 1, Kit.RADIUS, 6.0, 3.0)
		if is_sel:  # elegida = filete de oro con halo violeta (regla de color 2)
			card_style.shadow_color = Color(Kit.VIOLET, 0.55)
			card_style.shadow_size = 6
		(c.panel as PanelContainer).add_theme_stylebox_override("panel", card_style)
		(c.panel as Control).modulate = Color(1, 1, 1, 1) if alive else Color(1, 1, 1, 0.55)
		var tip_parts: Array = ["%s (%d)" % [str(d.get("nombre", id)), V.GROUPS.find(id) + 1]]
		tip_parts.append("%s %d %%" % [_t("hud.strength", "Fuerza"), int(round(float(d.get("fuerza_pct", 0.0))))])
		tip_parts.append("%s %d %%" % [_t("hud.fatigue", "Fatiga"), int(round(float(d.get("fatiga_pct", 0.0))))])
		if int(d.get("custodia", 0)) > 0:
			tip_parts.append(_t("hud.custody", "Custodia %d") % int(d.get("custodia", 0)))
		if stage_txt != "" and not idle:
			tip_parts.insert(1, stage_txt)
		tip_parts.append("%s %s" % [Kit.tag_glyph(tags, tag_id), str(Kit.tag_info(tags, tag_id).get("etiqueta", ""))])
		(c.panel as Control).tooltip_text = "\n".join(PackedStringArray(tip_parts))


## Une las partes de una línea corta (estado, toma, sorpresa, apoyo) y, si no entra entera en la etiqueta, saca partes del final hasta que entre: nada queda cortado con «…»
## (H-R1-10) y lo que se saca sigue en el cartel de la tarjeta. Antes de que la fila se acomode (ancho 0) usa `fallback_room`.
func _fit_parts(l: Label, parts: Array, fallback_room: float) -> String:
	var fnt: Font = l.get_theme_font("font")
	var px: int = l.get_theme_font_size("font_size")
	var room := l.size.x if l.size.x >= 24.0 else fallback_room
	var shown := parts.duplicate()
	while shown.size() > 1 and fnt.get_string_size(" · ".join(PackedStringArray(shown)), HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x > room - 2.0:
		shown.pop_back()
	return " · ".join(PackedStringArray(shown))


## La etapa de una ficha en palabras: la de las reglas («Sosteniendo lo tomado») si entra en la ficha y, si no (a 1024 × 640 la ficha mide ≈ 136 px), la compacta de
## humahuaca_ui.json (texts.stage_compact, por id de etapa). La frase completa queda en el cartel de la ficha.
func _fit_stage(l: Label, rules_text: String, stage: String) -> void:
	var shown := rules_text
	if rules_text != "" and l.size.x >= 24.0:
		var fnt: Font = l.get_theme_font("font")
		var px: int = l.get_theme_font_size("font_size")
		if fnt.get_string_size(rules_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x > l.size.x - 2.0:
			var compact := _t("stage_compact." + stage, "")
			if compact != "":
				shown = compact
	l.text = shown


## Nombre corto de la ficha: el de reglas (`short`) llega por el controlador en ctx; si no, se recorta «Partida de» y «División de».
var short_by_id: Dictionary = {}

func _group_short(id: String, full: String) -> String:
	if short_by_id.has(id):
		return str(short_by_id[id])
	for prefix in ["Partida de ", "División de "]:
		if full.begins_with(prefix):
			return full.trim_prefix(prefix)
	return full


func _refresh_alert(ctx: Dictionary) -> void:
	var a := _dict(ctx.get("alert"))
	_alert_data = a
	alert_panel.visible = not a.is_empty()
	if a.is_empty():
		return
	var critical := str(a.get("nivel", "aviso")) == "critica"
	alert_panel.add_theme_stylebox_override("panel", Kit.style(Kit.WARN_BG if critical else Kit.PANEL_SOLID, Kit.WARN_BORDER if critical else Kit.GOLD, 2 if critical else 1, Kit.RADIUS, 14.0, 8.0))
	alert_title_l.text = str(a.get("corto", ""))
	alert_text_l.text = str(a.get("largo", ""))
	alert_text_l.visible = alert_text_l.text != ""
	var button := str(a.get("boton", ""))
	alert_btn.visible = button != ""
	alert_btn.text = button
	var left := float(a.get("vence_s", 0.0))
	alert_count_l.text = Kit.mmss(left) if left > 0.0 else ""
	place_alert(ctx.get("avoid", []) as Array if ctx.get("avoid", []) is Array else [])


## El rectángulo del aviso en un lugar, en coordenadas locales del HUD. `w` y `h` son su ancho y su alto.
func _alert_slot_rect(slot: String, w: float, h: float) -> Rect2:
	var m := _num(["margin"], 12.0)
	var gap := _num(["gap"], 8.0)
	var top := m + _num(["header_h"], 46.0) + gap + _vec("fronts_card", Vector2(212.0, 56.0)).y + gap
	var rs := root.size
	match slot:
		"derecha":
			return Rect2(Vector2(rs.x - m - w, top), Vector2(w, h))
		"izquierda":
			return Rect2(Vector2(m, top), Vector2(w, h))
	return Rect2(Vector2((rs.x - w) * 0.5, top), Vector2(w, h))


## El aviso no tapa fichas ni rótulos: queda en el primer lugar libre (`avoid` trae lo que no se debe tapar) y, mientras ese lugar siga libre, no se mueve (así no salta de un
## lado al otro cuando las fichas se mueven). Si todos los lugares tapan algo, toma el que menos tapa. Devuelve el rectángulo elegido (coordenadas locales del HUD).
func place_alert(avoid: Array) -> Rect2:
	var w := minf(_num(["alert_w"], 520.0), maxf(root.size.x - 2.0 * _num(["margin"], 12.0), 200.0))
	w = minf(w, maxf(root.size.x * _num(["alert_w_max_pct"], 0.4), 360.0))  # en ventanas chicas el aviso es más angosto: así entra entre las fichas sin taparlas
	_alert_layout(w)
	# visual/r1 F4 (BACKLOG B-062 b): el aviso se dibuja con el ancho mínimo de su contenido si es mayor que `w` (a 1280 × 720 medía 640 de 576): se busca el
	# lugar con el rectángulo que de verdad ocupa, si no el lugar «libre» quedaba encima de la marca y el rótulo de la agrupación de al lado
	var min_size := alert_panel.get_combined_minimum_size()
	w = maxf(w, min_size.x)
	var h := maxf(alert_panel.size.y if alert_panel.size.y > 24.0 else 96.0, min_size.y)
	var order: Array = [_alert_slot]
	for slot in ALERT_SLOTS:
		if slot != _alert_slot:
			order.append(slot)
	var best: String = _alert_slot
	var least := INF
	for slot in order:
		var r := _alert_slot_rect(str(slot), w, h)
		var covered := 0.0
		for a in avoid:
			var inter := r.intersection(a as Rect2)
			covered += inter.size.x * inter.size.y
		if covered < least - 0.5:
			least = covered
			best = str(slot)
		if covered <= 0.0:
			break
	_alert_slot = best
	var rect := _alert_slot_rect(best, w, h)
	if least > 0.0:
		# visual/r1 F4 (BACKLOG B-062 b): los tres lugares tapan algo (las marcas a escala real quedan repartidas por arriba del cuadro): se prueba correr el aviso de a
		# octavos a lo ancho y un poco más abajo (sin bajar de la mitad del cuadro); gana el primero libre, si no el que menos tapa
		var m := _num(["margin"], 12.0)
		var span := maxf(root.size.x - 2.0 * m - w, 0.0)
		for row in range(4):
			for col in range(9):
				var r2 := Rect2(Vector2(m + span * float(col) / 8.0, rect.position.y + float(row) * (h * 0.5 + 8.0)), Vector2(w, h))
				if r2.end.y > root.size.y * 0.55:
					continue
				var c2 := 0.0
				for a in avoid:
					var inter2 := r2.intersection(a as Rect2)
					c2 += inter2.size.x * inter2.size.y
				if c2 < least - 0.5:
					least = c2
					rect = r2
				if least <= 0.0:
					break
			if least <= 0.0:
				break
	alert_panel.offset_left = rect.position.x
	alert_panel.offset_right = rect.position.x + w
	alert_panel.offset_top = rect.position.y
	alert_panel.offset_bottom = rect.position.y + 1.0
	return rect


func _alert_layout(w: float) -> void:
	if _alert_btn_box == null:
		return
	var inline := w >= _num(["alert_inline_min_w"], 480.0)
	var want: Control = _alert_outer if inline else _alert_col
	if _alert_btn_box.get_parent() != want:
		_alert_btn_box.get_parent().remove_child(_alert_btn_box)
		want.add_child(_alert_btn_box)
		(_alert_btn_box as BoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER if inline else BoxContainer.ALIGNMENT_BEGIN
		alert_panel.reset_size()


func _refresh_toast(ctx: Dictionary) -> void:
	var t := _dict(ctx.get("toast"))
	toast_panel.visible = not t.is_empty() and str(t.get("text", "")) != ""
	if toast_panel.visible:
		toast_l.text = str(t.get("text", ""))
		# Q-206: el aviso de pie mide lo que su frase en una línea (entre toast_w y el ancho de la columna): «¡Fuego! La descarga…» ya no ocupa dos líneas de 440 px
		var font: Font = toast_l.get_theme_font("font")
		var fsz := toast_l.get_theme_font_size("font_size")
		var text_w := font.get_string_size(toast_l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x if font != null else 0.0
		toast_panel.custom_minimum_size.x = clampf(text_w + 30.0, _num(["toast_w"], 440.0), maxf(bottom_width() - 8.0, _num(["toast_w"], 440.0)))
		var level := str(t.get("level", "info"))
		toast_panel.add_theme_stylebox_override("panel", Kit.style(Kit.PANEL_SOLID, Kit.AMBER if level != "info" else Kit.PANEL_BORDER, 1, Kit.RADIUS, 12.0, 5.0))
	_sync_notices()


## La fila de avisos de pie solo existe mientras hay un aviso o la línea roja: así no deja un hueco entre el mapa y el dock.
func _sync_notices() -> void:
	notice_row.visible = toast_panel.visible or warn_panel.visible


func _refresh_warn(ctx: Dictionary) -> void:
	var text := str(ctx.get("warn", ""))
	warn_l.text = text
	warn_panel.visible = text != ""
	_sync_notices()


# ---------------------------------------------------------------------------------------------------------------------
# Consultas para las pruebas y la herramienta de interfaz

func visible_root(on: bool) -> void:
	if root != null:
		root.visible = on


## Controles accionables visibles (la medida del primer cuadro) y botones sueltos.
func controls_report() -> Dictionary:
	return Kit.controls_report(root)


## Caracteres de texto visibles; con `with_warn` false no cuenta la línea roja de las capas en su versión mínima (aviso de desarrollo).
func text_chars(with_warn: bool = true) -> int:
	var n := Kit.text_chars(root)
	if not with_warn and is_instance_valid(warn_panel) and warn_panel.is_visible_in_tree():
		n -= warn_l.text.length()
	return n


func rects() -> Dictionary:
	var out := {}
	out["titulo"] = Kit.rect_of(title_l)
	out["objetivo"] = Kit.rect_of(objective_l)
	out["siguiente"] = Kit.rect_of(next_text_l)
	out["frente_bateria"] = Kit.rect_of(front_cards["bateria"].panel as Control)
	out["alerta"] = Kit.rect_of(alert_panel) if alert_panel.is_visible_in_tree() else Rect2()
	var first_action := Kit.rect_of(next_btn) if next_btn.is_visible_in_tree() else Rect2()
	for act in _action_buttons:
		first_action = Kit.rect_of(_action_buttons[act] as Control)
		break
	out["accion_1"] = first_action
	out["dock"] = Kit.rect_of(dock)
	out["barra"] = Kit.rect_of(bar) if bar.is_visible_in_tree() else Rect2()
	out["header"] = Kit.rect_of(header)
	out["fronts"] = Kit.rect_of(fronts_box)
	out["cards"] = Kit.rect_of(cards_box)
	return out


## Todos los paneles grandes del HUD (para comprobar que ninguno sale del cuadro y que no se pisan).
func panels() -> Dictionary:
	var out := {"header": header, "fronts": fronts_box, "dock": dock}
	if bar.is_visible_in_tree():
		out["bar"] = bar
	if alert_panel.is_visible_in_tree():
		out["alert"] = alert_panel
	if toast_panel.is_visible_in_tree():
		out["toast"] = toast_panel
	if warn_panel.is_visible_in_tree():
		out["warn"] = warn_panel
	return out


func button_by_name(button_name: String) -> Button:
	if root == null:
		return null
	var found := root.find_child(button_name, true, false)
	return found as Button


func action_button(action: String) -> Button:
	return _action_buttons.get(action, null)


func card_rect(id: String) -> Rect2:
	if group_cards.has(id):
		return Kit.rect_of(group_cards[id].panel as Control)
	return Rect2()
