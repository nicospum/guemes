extends SceneTree
## QA de interfaz del nivel «humahuaca» con ventana real y entrada inyectada por el Viewport (dueña: ui_feel; CONTRATO 5.1 y QA_NIVEL2 anexo D, Q3).
## Uso: godot --path . --resolution 1280x720 --audio-driver Dummy --script tools/ui_qa_humahuaca.gd -- --out=<carpeta> --size=1280x720 [--allow-clip] [--full]
## --size=WxH fija el tamaño real de la ventana (sin bordes, tras el arranque) y se verifica el tamaño de la captura (captura_px y resolucion_real).
## A 1280 × 720 corre el recorrido COMPLETO (menú, briefing, apertura, primer cuadro, órdenes con vista previa, aproximación, ataque, extracción, derrota,
## reintento, victoria, pausa y ayuda); a otros tamaños corre el chequeo de DESBORDE (_check_overflow: ningún panel fuera del cuadro ni pisado, el último
## elemento del menú dentro, las ventanas enteras) salvo que se pida --full (desde R2a se exige completo a las tres resoluciones).
## Imprime «UI_QA {json}» y escribe ui_qa_report.json en --out junto con las capturas. No es una partida humana ni una prueba con teclado físico.
## Pase 2 de R1: el parte vuelve del Diario (H-R1-2) y una partida guiada eligiendo fichas con las teclas 1 a 5 mide que ningún panel del HUD pise a otro y que el
## «siguiente paso» entre en dos líneas (H-R1-7), en el recorrido completo y en el de desborde (1024 × 640, 1920 × 1080 y 2560 × 1440).

const V = preload("res://scripts/humahuaca/humahuaca_vocab.gd")
const Kit = preload("res://scripts/humahuaca/ui/humahuaca_ui_kit.gd")

var game: Node
var hx: Node
var out_dir := ""
var checks := 0
var failures: Array = []
var notes: Dictionary = {}
var want_size := Vector2i.ZERO
var allow_clip := false
var force_full := false
var last_shot_size := Vector2i.ZERO
var ui_json: Dictionary = {}
var shots: Array = []
var contrast_min := 99.0
var cuts_seen: Dictionary = {}  # momento → textos cortados (H-R1-10); vacío si ninguno se cortó
var cuts_checked := 0


func _initialize() -> void:
	if DisplayServer.get_name() == "headless" or OS.get_cmdline_args().has("--headless"):
		print("UI_QA_HUMAHUACA requiere ventana real (sin --headless): el motor headless no dibuja y las capturas saldrían vacías. Salida 2.")
		quit(2)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			if parts.size() == 2:
				want_size = Vector2i(int(parts[0]), int(parts[1]))
		elif arg == "--allow-clip":
			allow_clip = true
		elif arg == "--full":
			force_full = true
	if out_dir == "":
		push_error("ui_qa_humahuaca: falta --out=<carpeta> (sin eso no se escribe en evidence/)")
		quit(2)
		return
	for stale in ["settings.cfg", "campaign.json", "justina_progress.json", "humahuaca_progress.json", "humahuaca_checkpoint.json", "save_humahuaca.json", "qa_humahuaca_progress.json"]:
		if FileAccess.file_exists("user://" + stale):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + stale))
	call_deferred("_run")


# ---------------------------------------------------------------------------------------------------------------------
# Ayudas

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func check(cond: bool, what: String) -> bool:
	checks += 1
	if not cond:
		failures.append(what)
		push_error(what)
	return cond


func _shot(shot_name: String) -> Image:
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	last_shot_size = img.get_size()
	img.save_png(ProjectSettings.globalize_path(out_dir).path_join(shot_name + ".png"))
	shots.append(shot_name)
	return img


func _key(code: int, ctrl: bool = false, shift: bool = false) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		e.ctrl_pressed = ctrl
		e.shift_pressed = shift
		root.push_input(e)
		await process_frame


func _to_window(pos: Vector2) -> Vector2:
	return root.get_final_transform() * pos


func _move(pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = _to_window(pos)
	e.global_position = e.position
	root.push_input(e)
	await process_frame


func _click(pos: Vector2, button: int = MOUSE_BUTTON_LEFT, shift: bool = false) -> void:
	await _move(pos)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.position = _to_window(pos)
		e.global_position = e.position
		e.button_index = button
		e.pressed = pressed
		e.shift_pressed = shift
		e.button_mask = (1 << (button - 1)) if pressed else 0
		root.push_input(e)
		await process_frame


func _click_control(c: Control) -> void:
	await _click(Kit.rect_of(c).get_center())


func _button(part: String) -> Button:
	for b in game.find_children("*", "Button", true, false):
		if b is Button and part in b.text and b.is_visible_in_tree():
			return b
	return null


func _viewport_rect() -> Rect2:
	return Rect2(Vector2.ZERO, root.get_visible_rect().size)


func _inside(r: Rect2) -> bool:
	var v := _viewport_rect()
	return r.position.x >= v.position.x - 0.5 and r.position.y >= v.position.y - 0.5 and r.end.x <= v.end.x + 0.5 and r.end.y <= v.end.y + 0.5


func _screen_of(x: float, z: float) -> Vector2:
	return game.camera.unproject_position(Vector3(x, float(hx.ground_height(x, z)), z))


func _apply_size() -> void:
	## Un monitor de 1920 × 1080 no admite una ventana de SO decorada de 2560 × 1440: el SO la recorta. Una ventana sin bordes cuyo tamaño se fija después
	## del arranque sí llega, y la captura (textura del viewport) tiene entonces el tamaño pedido. Se verifica y se registra; si no se logra, falla.
	if want_size == Vector2i.ZERO:
		return
	root.mode = Window.MODE_WINDOWED
	root.borderless = true
	root.size = want_size
	root.position = Vector2i.ZERO
	await _frames(12)
	notes["tamano_pedido"] = [want_size.x, want_size.y]
	notes["ventana_px_tras_ajuste"] = [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y]
	notes["monitor_px"] = [DisplayServer.screen_get_size().x, DisplayServer.screen_get_size().y]


func _check_real_size() -> void:
	if want_size == Vector2i.ZERO:
		return
	var real := last_shot_size == want_size
	notes["captura_px"] = [last_shot_size.x, last_shot_size.y]
	notes["resolucion_real"] = real
	if not real:
		notes["limitacion"] = "El monitor o el SO no permitió una captura de %dx%d (se obtuvo %dx%d)." % [want_size.x, want_size.y, last_shot_size.x, last_shot_size.y]
	check(real or allow_clip, "Captura a la resolución pedida %s (obtenida %s)" % [str(want_size), str(last_shot_size)])


func _fold(text: String) -> String:
	var out := text.to_lower()
	var from := "áéíóúüñ"
	var to := "aeiouun"
	for i in range(from.length()):
		out = out.replace(from[i], to[i])
	return out


func _jargon_hits(text: String) -> Array:
	var hits: Array = []
	var folded := _fold(text)
	for term in ui_json.get("jargon_blacklist", []):
		var t := str(term)
		var is_sigla := t.length() >= 2 and t == t.to_upper()
		var rx := RegEx.new()
		rx.compile("(?<![A-Za-z0-9_])" + (t if is_sigla else _fold(t)) + "(?![A-Za-z0-9_])")
		if rx.search(text if is_sigla else folded) != null:
			hits.append(t)
	var snake := RegEx.new()
	snake.compile("\\b[a-z]+(?:_[a-z0-9]+)+\\b")
	if snake.search(text) != null:
		hits.append("snake_case")
	return hits


func _visible_texts() -> Array:
	var out: Array = []
	for c in game.ui.find_children("*", "Control", true, false):
		var ctl := c as Control
		if not ctl.is_visible_in_tree():
			continue
		if ctl is Label and (ctl as Label).text != "":
			out.append((ctl as Label).text)
		elif ctl is Button and (ctl as Button).text != "":
			out.append((ctl as Button).text)
		elif ctl is RichTextLabel and (ctl as RichTextLabel).get_parsed_text() != "":
			out.append((ctl as RichTextLabel).get_parsed_text())
	return out


func _lum(c: Color) -> float:
	var f := func(v: float) -> float: return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * float(f.call(c.r)) + 0.7152 * float(f.call(c.g)) + 0.0722 * float(f.call(c.b))


## Contraste de un texto medido sobre los PÍXELES reales de la captura: el fondo es la luminancia mediana del borde del rectángulo y el texto, el píxel más
## lejano de ese fondo. Devuelve 0 si el rectángulo no tiene área.
func _contrast_of(img: Image, logical_rect: Rect2) -> float:
	var win := Rect2(_to_window(logical_rect.position), logical_rect.size * root.get_final_transform().get_scale())
	var r := Rect2i(int(win.position.x), int(win.position.y), int(win.size.x), int(win.size.y)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if r.size.x < 4 or r.size.y < 4:
		return 0.0
	var edge: Array = []
	for x in range(r.position.x, r.end.x):
		edge.append(_lum(img.get_pixel(x, r.position.y)))
		edge.append(_lum(img.get_pixel(x, r.end.y - 1)))
	edge.sort()
	var bg: float = edge[edge.size() / 2]
	var far := bg
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var l := _lum(img.get_pixel(x, y))
			if absf(l - bg) > absf(far - bg):
				far = l
	return (maxf(far, bg) + 0.05) / (minf(far, bg) + 0.05)


func _measure_contrast(img: Image, label: String) -> void:
	var list: Array = []
	var h: Variant = hx.hud
	var candidates: Array = [h.title_l, h.reloj_l, h.phase_l, h.objective_l, h.next_text_l, h.next_btn, h.motive_l]
	for id in h.front_cards:
		candidates.append(h.front_cards[id].name)
	for id in h.group_cards:
		candidates.append(h.group_cards[id].name)
	for c in candidates:
		if (c as Control).is_visible_in_tree() and str((c as Control).get("text")) != "":
			list.append(c)
	if list.is_empty():
		notes["contraste_" + label] = {"minimo": 0.0, "en": "", "textos": 0, "nota": "sin HUD a la vista en esta captura"}
		return
	var worst := 99.0
	var worst_name := ""
	for c in list:
		var ratio := _contrast_of(img, Kit.rect_of(c as Control))
		if ratio > 0.0 and ratio < worst:
			worst = ratio
			worst_name = str((c as Control).name)
	if worst < contrast_min:
		contrast_min = worst
	notes["contraste_" + label] = {"minimo": snappedf(worst, 0.01), "en": worst_name, "textos": list.size()}
	check(worst >= 4.5, "%s: el texto del HUD tiene contraste ≥ 4,5:1 medido sobre los píxeles (mínimo %.2f en %s)" % [label, worst, worst_name])


## Sigue el «siguiente paso» (aprieta su botón) de a un segundo de juego, como la política «interfaz» de la herramienta de recorrido de reglas, hasta que termine la
## partida, se acaben `max_s` segundos o llegue la fase `until_phase` (si se pide). Devuelve los segundos de juego usados.
func _follow_guide(max_s: float, until_phase: String = "") -> float:
	var used := 0.0
	while used < max_s and str(hx.rules.state.status) == "playing":
		if until_phase != "" and str(hx.rules.state.phase) == until_phase:
			break
		hx.qa_press_next()
		hx.qa_step(1.0)
		used += 1.0
	return used


# ---------------------------------------------------------------------------------------------------------------------
# Desborde: lo que hace falta a cualquier resolución

func _check_overflow(label: String) -> void:
	var vp := _viewport_rect()
	var visible_rects: Dictionary = {}
	var panels: Dictionary = hx.hud.panels()  # cabecera, frentes, dock y, si están a la vista, la barra de órdenes, la alerta, el aviso de pie y la línea roja
	for key in panels:
		var r: Rect2 = Kit.rect_of(panels[key] as Control)
		visible_rects[key] = r
		check(_inside(r), "%s: %s dentro del cuadro %s (%s)" % [label, key, str(vp.size), str(r)])
	var mm: Rect2 = Kit.rect_of(hx.minimap)
	visible_rects["minimapa"] = mm
	check(_inside(mm), "%s: el minimapa dentro del cuadro (%s)" % [label, str(mm)])
	var keys: Array = visible_rects.keys()
	var overlaps: Array = []
	for i in range(keys.size()):
		for j in range(i + 1, keys.size()):
			if (visible_rects[keys[i]] as Rect2).grow(-1.0).intersects((visible_rects[keys[j]] as Rect2).grow(-1.0)):
				overlaps.append("%s/%s" % [str(keys[i]), str(keys[j])])
	check(overlaps.is_empty(), "%s: los paneles del HUD y el minimapa no se pisan (%d cruces: %s)" % [label, overlaps.size(), str(overlaps)])
	if hx.hud.next_text_l.is_visible_in_tree():
		check(hx.hud.next_text_l.get_line_count() <= 2, "%s: el texto del «siguiente paso» ocupa 2 líneas como máximo (%d)" % [label, hx.hud.next_text_l.get_line_count()])
	for id in V.GROUPS:
		var card: Rect2 = hx.hud.card_rect(str(id))
		check(_inside(card) and card.size.x >= 60.0, "%s: la ficha de %s entra en el dock (%s)" % [label, str(id), str(card)])
	_check_text_cuts(label)


## H-R1-10: ningún texto de la interfaz queda cortado (una línea recortada con «…», líneas escondidas o un botón más chico que su texto). Es la misma medida que usa la sonda
## de recortes del QA y mira todo lo que hay a la vista (el HUD, las ventanas y el aviso de pie), no solo la línea del objetivo.
func _check_text_cuts(label: String) -> void:
	var cuts: Array = Kit.cut_labels(game.ui)
	cuts_checked += 1
	if not cuts.is_empty():
		cuts_seen[label] = cuts
	check(cuts.is_empty(), "%s: ningún texto queda cortado (%d: %s)" % [label, cuts.size(), str(cuts.slice(0, 3))])


## H-R1-10: el objetivo dice algo vigente en cada fase y entra entero. Arranca el nivel directo en cada fase (opts.phase) y mide la línea del objetivo y todos los textos.
func _phase_sweep(tag: String) -> void:
	var seen: Dictionary = {}
	for phase in ["aproximacion", "ataque", "extraccion"]:
		game._start_humahuaca({"skip_intro": true, "phase": phase, "seed": 7})
		await _frames(8)
		hx = game.hx
		if not check(is_instance_valid(hx) and str(hx.qa_state().phase) == phase, "%s: el nivel arranca en la fase «%s»" % [tag, phase]):
			continue
		hx.refresh_hud_now()
		await _frames(2)
		var text: String = hx.hud.objective_l.text
		seen[phase] = text
		check(text != "" and not text.ends_with("…"), "%s · %s: el objetivo dice algo y no termina en «…» («%s»)" % [tag, phase, text])
		_check_text_cuts("%s · %s" % [tag, phase])
	var distinct := {}
	for k in seen:
		distinct[str(seen[k])] = true
	check(distinct.size() == seen.size() and seen.size() == 3, "%s: el objetivo cambia con la fase (%d frases distintas en %d fases)" % [tag, distinct.size(), seen.size()])
	notes["objetivo_por_fase_" + tag] = seen
	game._start_humahuaca({"skip_intro": true})  # el resto del recorrido sigue con un nivel normal, no con el último del barrido
	await _frames(6)
	hx = game.hx


## El alto de cada ficha parada (de la base a la cima de sus piezas, sin los anillos), proyectado y en píxeles REALES de la captura: lo que mide V03. Antes salía de `probes()`,
## cuyo rectángulo de ficha trae el tamaño pedido y no el dibujado, y se multiplicaba otra vez por la escala de la ventana (B-026).
func _token_px() -> Array:
	var out: Array = []
	if not is_instance_valid(hx.view) or not "unit_nodes" in hx.view:
		return out
	var cam3: Camera3D = game.camera
	var real := root.get_final_transform().get_scale().y
	for id in V.GROUPS:
		if not hx.view.unit_nodes.has(id):
			continue
		var node: Node3D = hx.view.unit_nodes[id]
		var top := node.global_position.y
		var lo_x := 1.0e9
		var hi_x := -1.0e9
		for mi in node.find_children("*", "MeshInstance3D", true, false):
			if str(mi.name) in ["anillo", "borde", "seleccion"]:
				continue
			var mesh_node := mi as MeshInstance3D
			var box: AABB = mesh_node.global_transform * mesh_node.get_aabb()
			top = maxf(top, box.end.y)
			for corner in range(8):
				var q := cam3.unproject_position(box.get_endpoint(corner))
				lo_x = minf(lo_x, q.x)
				hi_x = maxf(hi_x, q.x)
		var base_px := cam3.unproject_position(node.global_position)
		var top_px := cam3.unproject_position(Vector3(node.global_position.x, top, node.global_position.z))
		out.append({"id": str(id), "w": snappedf(maxf(hi_x - lo_x, 0.0) * real, 0.1), "h": snappedf(absf(base_px.y - top_px.y) * real, 0.1)})
	return out


## Un control como [x, y, ancho, alto] en PÍXELES DE LA CAPTURA (no del cuadro lógico del HUD, que una ventana de 1280 × 720 escala ×0,8): es lo que lee qa_imagen.py
## (B-032). En los textos se ajusta el ancho al del texto, para que el rectángulo mida el texto y no el panel vacío que lo rodea.
func _px_rect(c: Control) -> Array:
	var r := Kit.rect_of(c)
	var scale := root.get_final_transform().get_scale()
	var win := Rect2(_to_window(r.position), r.size * scale)
	if c is Label and (c as Label).text != "":
		var l := c as Label
		var fnt: Font = l.get_theme_font("font")
		var fs: int = l.get_theme_font_size("font_size")
		win.size.x = minf(win.size.x, (fnt.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x + 4.0) * scale.x)
	elif c is Button:
		win = win.grow(-6.0 * scale.x)
	return [int(win.position.x), int(win.position.y), maxi(int(win.size.x), 1), maxi(int(win.size.y), 1)]


## Las seis posiciones de Q3 (titulo, objetivo, siguiente, frente_bateria, alerta, accion_1), todas con área: si no hay alerta a la vista se usa el aviso de pie, la línea de
## motivo o la fase, y `alerta_es` dice cuál. La tarjeta del frente se mide por su nombre (texto), no por la tarjeta entera con sus barras.
func _capture_rects() -> Dictionary:
	var h: Variant = hx.hud
	var alert_src: Control = h.phase_l
	var alert_is := "fase"
	if h.alert_panel.is_visible_in_tree():
		alert_src = h.alert_title_l
		alert_is = "alerta"
	elif h.toast_panel.is_visible_in_tree():
		alert_src = h.toast_l
		alert_is = "aviso_de_pie"
	elif h.bar.is_visible_in_tree() and h.motive_l.text != "":
		alert_src = h.motive_l
		alert_is = "motivo"
	var action_src: Control = h.next_btn
	for act in h._action_buttons:
		action_src = h._action_buttons[act]
		break
	notes["alerta_es"] = alert_is
	return {"titulo": _px_rect(h.title_l), "objetivo": _px_rect(h.objective_l), "siguiente": _px_rect(h.next_text_l), "frente_bateria": _px_rect(h.front_cards["bateria"].name),
		"alerta": _px_rect(alert_src), "accion_1": _px_rect(action_src)}


## Lleva la partida guiada hasta la primera descarga (la señal) y 20 s más, como pide Q3 para «hx-hud». Devuelve false si la señal nunca estuvo lista.
func _reach_first_volley() -> bool:
	var waited := 0.0
	while waited < 400.0 and str(hx.rules.state.status) == "playing" and str(hx.qa_state().guide.action) != "give_signal":
		hx.qa_press_next()
		hx.qa_step(1.0)
		waited += 1.0
	hx.refresh_hud_now()
	return str(hx.qa_state().guide.action) == "give_signal"


## H-R1-7: una partida guiada por el «siguiente paso» en la que el jugador va eligiendo fichas con las teclas 1 a 5 (cada elección cambia la barra de órdenes) y a la que
## llegan avisos: en cada paso se mide que ningún panel del HUD pise a otro ni salga del cuadro y que el «siguiente paso» no quede en una columna angosta ni pase de 2 líneas.
func _probe_guided(label: String, steps: int) -> void:
	var vp := _viewport_rect()
	var crossings: Dictionary = {}
	var outside := 0
	var lines_max := 0
	var width_min := 1.0e9
	var toast_steps := 0
	var bar_steps := 0
	var done := 0
	var cut_set: Dictionary = {}
	for i in range(steps):
		if str(hx.qa_state().status) != "playing" or str(hx.qa_state().dialog) != "":
			break
		hx.qa_press_next()
		await _key(KEY_1 + (i % 5))
		hx.qa_step(3.0)
		await _frames(2)
		done += 1
		var rects: Dictionary = {}
		var panels: Dictionary = hx.hud.panels()
		for key in panels:
			rects[key] = Kit.rect_of(panels[key] as Control)
			if not _inside(rects[key]):
				outside += 1
		rects["minimapa"] = Kit.rect_of(hx.minimap)
		var keys: Array = rects.keys()
		for a in range(keys.size()):
			for b in range(a + 1, keys.size()):
				if (rects[keys[a]] as Rect2).grow(-1.0).intersects((rects[keys[b]] as Rect2).grow(-1.0)):
					var k := "%s/%s" % [str(keys[a]), str(keys[b])]
					crossings[k] = int(crossings.get(k, 0)) + 1
		if hx.hud.next_text_l.is_visible_in_tree():
			lines_max = maxi(lines_max, hx.hud.next_text_l.get_line_count())
			width_min = minf(width_min, hx.hud.next_text_l.size.x * hx.ui_scale)
		for cut in Kit.cut_labels(game.ui):
			cut_set[str(cut.text)] = cut
		if hx.hud.toast_panel.is_visible_in_tree():
			toast_steps += 1
		if hx.hud.bar.is_visible_in_tree():
			bar_steps += 1
	notes["hud_guiado_" + label] = {"pasos": done, "cruces": crossings, "paneles_fuera": outside, "lineas_siguiente_max": lines_max, "ancho_siguiente_min_px": int(width_min), "pasos_con_aviso": toast_steps, "pasos_con_barra": bar_steps}
	check(done >= 40 and toast_steps > 0 and bar_steps > 0, "Partida guiada %s: %d pasos con fichas elegidas, con avisos (%d pasos) y barra de órdenes (%d pasos) a la vista" % [label, done, toast_steps, bar_steps])
	check(crossings.is_empty(), "Partida guiada %s: ningún panel del HUD pisa a otro en %d pasos (%s)" % [label, done, str(crossings)])
	check(outside == 0, "Partida guiada %s: ningún panel del HUD sale del cuadro (%d veces)" % [label, outside])
	cuts_checked += 1
	if not cut_set.is_empty():
		cuts_seen["guiada " + label] = cut_set.values()
	check(cut_set.is_empty(), "Partida guiada %s: ningún texto queda cortado en %d pasos (%d distintos: %s)" % [label, done, cut_set.size(), str(cut_set.values().slice(0, 3))])
	check(lines_max <= 2 and width_min >= 250.0, "Partida guiada %s: el «siguiente paso» ocupa %d líneas como máximo y nunca queda en una columna menor de 250 px (mínimo %d px)" % [label, lines_max, int(width_min)])
	hx.reset_camera()  # tocar dos veces la misma tecla centra la cámara en un frente: el resto del recorrido sigue con el cuadro inicial


## H-R1-2: del parte se abre el Diario y «Cerrar» (o Esc) vuelve al parte con su botón principal a la vista: la pantalla nunca queda sin salida.
func _diary_roundtrip(label: String, shot_name: String = "") -> void:
	var diary := _button("Diario")
	if not check(diary != null, "%s: el parte ofrece el botón «Diario»" % label):
		return
	await _click_control(diary)
	await _frames(4)
	if str(hx.qa_state().dialog) == "parte":  # a veces la entrada inyectada no llega (B-044: la ventana pierde la entrada real): se repite una vez y se anota, no se esconde
		notes["clics_repetidos"] = int(notes.get("clics_repetidos", 0)) + 1
		await _click_control(diary)
		await _frames(4)
	check(str(hx.qa_state().dialog) == "diario" and _button("Cerrar") != null, "%s: el clic en «Diario» abre el diario con su botón «Cerrar»" % label)
	if shot_name != "":
		await _shot(shot_name)
	if _button("Cerrar") == null:
		return
	await _click_control(_button("Cerrar"))
	await _frames(4)
	if shot_name != "":
		await _shot("hx-parte-tras-diario")  # la prueba de H-R1-2: tras cerrar el diario el parte está de nuevo, con su botón principal
	var again := game.find_child("HxRetry", true, false) as Button
	var back_by_click: bool = str(hx.qa_state().dialog) == "parte" and again != null and again.is_visible_in_tree() and _inside(Kit.rect_of(again))
	check(back_by_click, "%s: «Cerrar» vuelve al parte con «%s» a la vista" % [label, again.text if again != null else "—"])
	if _button("Diario") != null:
		await _click_control(_button("Diario"))
		await _frames(3)
		await _key(KEY_ESCAPE)
		await _frames(3)
	again = game.find_child("HxRetry", true, false) as Button
	var back_by_esc: bool = str(hx.qa_state().dialog) == "parte" and again != null and again.is_visible_in_tree() and _inside(Kit.rect_of(again))
	check(back_by_esc, "%s: Esc en el diario también vuelve al parte con su botón principal a la vista" % label)
	notes["parte_diario_vuelve_" + label.to_lower().replace(" ", "_")] = back_by_click and back_by_esc


## Qué tan cerca del borde del cuadro queda la ficha más pegada (porcentaje del ancho o del alto, el menor) y si alguna queda bajo el HUD.
func _token_margins(rects: Dictionary) -> Dictionary:
	var vp := _viewport_rect().size
	var edge_min := 100.0
	var covered: Array = []
	for id in V.GROUPS:
		var u: Dictionary = hx.rules.get_unit(str(id))
		var s := _screen_of(float(u.x), float(u.z))
		edge_min = minf(edge_min, 100.0 * minf(minf(s.x, vp.x - s.x) / vp.x, minf(s.y, vp.y - s.y) / vp.y))
		for key in ["header", "fronts", "dock"]:
			if (rects[key] as Rect2).has_point(s):
				covered.append("%s bajo %s" % [str(id), key])
	return {"borde_min_pct": snappedf(edge_min, 0.1), "tapadas": covered}


## Si hay un aviso a la vista, queda dentro del cuadro y no tapa ninguna ficha (el cuerpo de cada una: unos 48 px de ancho y 60 px sobre su base).
func _check_alert_free(label: String) -> void:
	var a: Rect2 = hx.hud.rects().get("alerta", Rect2())
	if a.size.x <= 0.0:
		notes["aviso_" + label] = "sin aviso en esta captura"
		return
	var covered: Array = []
	for id in V.GROUPS:
		var u: Dictionary = hx.rules.get_unit(str(id))
		if str(u.get("stage", "")) == "exited":
			continue
		var base := _screen_of(float(u.x), float(u.z))
		if Rect2(base - Vector2(24.0, 60.0), Vector2(48.0, 70.0)).intersects(a):
			covered.append(str(id))
	notes["aviso_" + label] = {"rect": [snappedf(a.position.x, 0.1), snappedf(a.position.y, 0.1), snappedf(a.size.x, 0.1), snappedf(a.size.y, 0.1)], "tapa": covered}
	check(_inside(a) and covered.is_empty(), "%s: el aviso queda dentro del cuadro y no tapa ninguna ficha (%s)" % [label, str(covered)])


func _check_dialog_fit(label: String) -> void:
	var panel: Control = hx.dialogs.panel
	if not check(panel != null, "%s: la ventana está armada" % label):
		return
	var r := Kit.rect_of(panel)
	check(_inside(r), "%s: la ventana entra entera en el cuadro (%s en %s)" % [label, str(r), str(_viewport_rect().size)])


# ---------------------------------------------------------------------------------------------------------------------

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	ui_json = V.load_json(V.UI_PATH)
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await _frames(20)
	await _apply_size()
	game.jev.force_local = true
	game.settings.auto_pause = false
	if is_instance_valid(game.audio_manager):
		game.audio_manager.set_muted(true)
	var full := force_full or want_size == Vector2i(1280, 720) or want_size == Vector2i.ZERO
	notes["viewport_logico"] = [root.get_visible_rect().size.x, root.get_visible_rect().size.y]
	notes["recorrido"] = "completo" if full else "desborde"
	await _menu_checks()
	if full:
		await _cycle_full()
	else:
		await _cycle_overflow()
	await _finish()


# ---------------------------------------------------------------------------------------------------------------------
# El menú de tres botones (C04): Humahuaca siempre habilitado, el Norte con su candado

func _menu_checks() -> void:
	var img := await _shot("hx-menu-nuevo")
	_check_real_size()
	var salir := _button("Salir")
	check(salir != null and _inside(Kit.rect_of(salir)), "Menú: «Salir» visible dentro del cuadro")
	var hxb := _button("HUMAHUACA")
	var norte := _button("SOSTENER EL NORTE")
	var justina := _button("EL RÍO OFRECE")
	if not check(hxb != null and norte != null and justina != null, "Menú: los tres botones (I, II y III) existen"):
		return
	check(justina.global_position.y < hxb.global_position.y and hxb.global_position.y < norte.global_position.y, "Menú: el orden es I, II, III")
	check(not hxb.disabled and hxb.text.find("Recomendado tras la Justina") >= 0, "Menú: con un perfil nuevo «II» está habilitado y dice «Recomendado tras la Justina»")
	check(norte.disabled and norte.text.find("Ganá la Justina para abrirlo") >= 0, "Menú: con un perfil nuevo «III» (el Norte) sigue con su candado")
	check(hxb.text.find("Ganá la Justina para abrirlo") < 0 and hxb.text.find("EL RÍO OFRECE") < 0 and hxb.text.find("SOSTENER EL NORTE") < 0, "Menú: el botón de Humahuaca no contiene los textos que buscan las pruebas de la Justina y del Norte")
	notes["menu_candado_nuevo"] = norte.disabled
	notes["menu_nota_humahuaca"] = hxb.text.find("Recomendado tras la Justina") >= 0
	var last_y := 0.0
	for c in game.find_children("*", "Control", true, false):
		if (c as Control).is_visible_in_tree() and not (c is ColorRect):
			last_y = maxf(last_y, Kit.rect_of(c as Control).end.y)
	notes["menu_ultimo_y"] = snappedf(last_y, 0.1)
	check(last_y <= _viewport_rect().size.y + 0.5, "Menú: el último elemento termina dentro del cuadro (y = %.0f de %.0f)" % [last_y, _viewport_rect().size.y])
	game.progress.justina_ganada = true
	game._menu()
	await _frames(4)
	await _shot("hx-menu-desbloqueado")
	hxb = _button("HUMAHUACA")
	norte = _button("SOSTENER EL NORTE")
	check(hxb != null and hxb.text.find("Recomendado tras la Justina") < 0 and norte != null and not norte.disabled, "Menú: con la Justina ganada «II» pierde la nota y «III» se habilita")
	notes["menu_desbloqueado"] = norte != null and not norte.disabled
	game.progress.justina_ganada = false
	game._menu()
	await _frames(4)
	img = null


# ---------------------------------------------------------------------------------------------------------------------
# El recorrido completo a 1280 × 720

func _cycle_full() -> void:
	var button := _button("HUMAHUACA")
	await _click_control(button)
	await _frames(6)
	hx = game.hx
	if not check(game.mode == "hx" and is_instance_valid(hx), "Nivel: el clic en el botón abre Humahuaca"):
		return
	hx.qa_set_initial_yaw(325.0)  # el rumbo que fija el contrato (A-11); visual cambia el dato de 35° a 325° en el mismo merge
	check(str(hx.qa_state().dialog) == "briefing", "Briefing: el nivel abre con la tarjeta de arranque")
	await _shot("hx-briefing-1")
	_check_dialog_fit("Briefing 1")
	var texts1 := " ".join(PackedStringArray(_visible_texts()))
	check(texts1.find("Perder no es grave") >= 0 and texts1.find("Hoy:") >= 0, "Briefing 1: dice el objetivo, que perder no es grave y la variante del mundo")
	check(_jargon_hits(texts1).is_empty(), "Briefing 1: sin jerga (%s)" % str(_jargon_hits(texts1)))
	check(texts1.length() < 700, "Briefing 1: es corto (%d caracteres)" % texts1.length())
	await _click_control(_button("Seguir leyendo"))
	await _frames(3)
	await _shot("hx-briefing-2")
	_check_dialog_fit("Briefing 2")
	var texts2 := " ".join(PackedStringArray(_visible_texts()))
	check(texts2.find("Dramatización") >= 0 and texts2.find("restitución") >= 0 and texts2.find("no hubo refuerzo") >= 0, "Briefing 2: la carta es una dramatización y dice qué es real y qué es diseño")
	check(_jargon_hits(texts2).is_empty(), "Briefing 2: sin jerga (%s)" % str(_jargon_hits(texts2)))
	await _click_control(_button("Empezar"))
	await _frames(40)
	check(str(hx.qa_state().mode) == "opening", "Apertura: «Empezar» abre la presentación de cámara")
	await _shot("hx-apertura")
	check(not hx.hud.root.visible and hx._subtitle.visible and hx._subtitle.text.find("palos") >= 0, "Apertura: sin HUD y con la frase de Arias («%s»)" % hx._subtitle.text.left(60))
	var seconds: float = hx.cam.opening_seconds()
	notes["apertura_s"] = snappedf(seconds, 0.1)
	check(seconds >= 12.0 and seconds <= 15.0, "Apertura: dura de 12 a 15 s (%.1f s)" % seconds)
	await _key(KEY_X)
	await _frames(6)
	check(str(hx.qa_state().mode) == "play" and hx.hud.root.visible, "Apertura: cualquier tecla la salta y deja el nivel jugable")
	# --- el primer cuadro jugable ---
	await _frames(10)
	var img := await _shot("hx-inicio")
	var q: Dictionary = hx.qa_state()
	notes["controles_t0"] = int(q.visible_controls)
	notes["botones_t0"] = int(q.visible_buttons)
	notes["caracteres_t0"] = int(q.text_chars)
	notes["caracteres_juego_t0"] = int(q.text_chars_juego)
	var hits: Array = []
	for t in _visible_texts():
		for h in _jargon_hits(str(t)):
			hits.append("%s en «%s»" % [str(h), str(t).left(30)])
	notes["jerga_hits_t0"] = hits.size()
	var rects: Dictionary = hx.hud.rects()
	notes["rects_inicio"] = _capture_rects()  # en píxeles de la captura; las de «hx-hud» (las que usa V05) quedan en notes.rects
	check(int(q.visible_controls) <= 5, "Primer cuadro: ≤ 5 controles accionables (%d)" % int(q.visible_controls))
	check(int(q.text_chars_juego) <= 400, "Primer cuadro: ≤ 400 caracteres de texto de juego (%d; con el aviso de capas en su versión mínima, %d)" % [int(q.text_chars_juego), int(q.text_chars)])
	check(hits.is_empty(), "Primer cuadro: 0 términos de la lista negra (%s)" % str(hits))
	check(bool(q.paused) and hx.hud.clock_l.text == "‖ EN PAUSA", "Primer cuadro: el indicador dice «‖ EN PAUSA»")
	check(hx.hud.next_text_l.text != "" and hx.hud.next_btn.visible and hx.hud.objective_l.text != "", "Primer cuadro: una línea de objetivo y un solo «siguiente paso» con su botón")
	_check_overflow("Primer cuadro")
	_measure_contrast(img, "inicio")
	var token_px := _token_px()
	notes["token_px"] = token_px
	if root.size.y == 720:  # V03: cada ficha de pie mide 48 px reales o más con el zoom por defecto a 1280 × 720
		var low: Array = token_px.filter(func(t): return float(t.h) < 48.0)
		check(token_px.size() == V.GROUPS.size() and low.is_empty(), "Primer cuadro: las cinco fichas miden 48 px reales de alto o más (%s)" % str(token_px.map(func(t): return "%s %.1f" % [str(t.id), float(t.h)])))
	# ninguna ficha queda bajo el HUD y todas a ≥ 5 % del borde (con el rumbo que fija el contrato)
	var covered: Array = []
	var edge_min := 100.0
	for id in V.GROUPS:
		var u: Dictionary = hx.rules.get_unit(str(id))
		var s := _screen_of(float(u.x), float(u.z))
		var vp := _viewport_rect().size
		edge_min = minf(edge_min, 100.0 * minf(minf(s.x, vp.x - s.x) / vp.x, minf(s.y, vp.y - s.y) / vp.y))
		for key in ["header", "fronts", "dock"]:
			if (rects[key] as Rect2).has_point(s):
				covered.append("%s bajo %s" % [str(id), key])
	check(covered.is_empty(), "Primer cuadro: ninguna ficha queda bajo el HUD (%s)" % str(covered))
	notes["borde_min_pct"] = snappedf(edge_min, 0.1)
	# --- seleccionar, apuntar con vista previa y dar la orden con el mouse ---
	await _key(KEY_4)
	await _frames(3)
	check(hx.qa_state().selected == ["reconocedores"], "Órdenes: la tecla 4 elige a los reconocedores")
	await _key(KEY_R)
	var bat := _screen_of(318.0, 350.0)
	await _move(bat)
	await _frames(6)
	await _shot("hx-apuntar")
	_check_overflow("Apuntando")  # la barra de órdenes con los ritmos de marcha y la línea de motivo: la columna de abajo no pisa nada
	check(bool(hx.qa_state().aiming) and hx.orders.preview_text("recon").find("riesgo") >= 0, "Órdenes: al apuntar «Reconocer» se ve la vista previa con su riesgo («%s»)" % hx.orders.preview_text("recon"))
	var pill: Array = []
	for lab in hx.overlay.drawn_labels:
		pill.append(str((lab as Dictionary).text))
	check(not pill.is_empty(), "Órdenes: el texto de la ruta se dibuja junto al cursor (%s)" % str(pill.slice(0, 3)))
	await _click(bat)
	await _frames(4)
	check(int(hx.qa_state().orders) == 1 and not bool(hx.qa_state().paused), "Órdenes: el clic confirma y la primera orden pone en marcha el reloj")
	await _key(KEY_1)
	await _click(_screen_of(200.0, 430.0), MOUSE_BUTTON_RIGHT)
	await _frames(3)
	check(int(hx.qa_state().orders) == 2, "Órdenes: el clic derecho manda a la partida elegida al punto del mapa")
	# --- lo manual quedó probado: un intento limpio del mismo mundo y el resto lo lleva el «siguiente paso», como lo haría quien lo sigue ---
	hx.retry("mismo_mundo")
	await _frames(4)
	# --- H-R1-7: una partida guiada eligiendo fichas con las teclas 1 a 5, con avisos y barra de órdenes a la vista: ningún panel pisa a otro ---
	await _probe_guided("%dx%d" % [root.size.x, root.size.y], 60)
	hx.retry("mismo_mundo")
	await _frames(4)
	# --- la aproximación con lluvia (≈ 1:30) ---
	_follow_guide(90.0, "ataque")
	await _key(KEY_2)
	await _frames(8)
	var img2 := await _shot("hx-aproximacion-lluvia")
	check(str(hx.qa_state().phase) == "aproximacion" and hx.hud.phase_l.text.find("Aproximación") >= 0, "Aproximación: la cabecera dice «Noche · Aproximación» (%s)" % hx.hud.phase_l.text)
	check(float(hx.hud.dawn_bar.value) > 5.0, "Aproximación: la barra del alba avanzó (%.0f %%)" % float(hx.hud.dawn_bar.value))
	_measure_contrast(img2, "aproximacion")
	_check_alert_free("Aproximación")
	# --- ataque: señal, tres frentes y la torre ---
	_reach_first_volley()
	check(hx.hud.status_l.text.find("Señal") >= 0, "Señal: el HUD dice cómo está la señal («%s»)" % hx.hud.status_l.text)
	await _key(KEY_F)
	check(bool(hx.rules.state.alarm.signaled), "Señal: la tecla F da la señal")
	_follow_guide(20.0)
	await _frames(8)
	var img3 := await _shot("hx-hud")
	notes["rects"] = _capture_rects()  # V05 las aplica a «hx-hud.png»: en píxeles de esa captura y todas con área
	check(str(hx.qa_state().phase) == "ataque" and hx.hud.chip_labels.golpe.panel.visible, "Ataque: la fase cambia y aparece el golpe en el dock (%s)" % hx.hud.chip_labels.golpe.label.text)
	_check_overflow("Ataque")
	_measure_contrast(img3, "ataque")
	_check_alert_free("Ataque")
	# --- extracción: el arreo carga y el reloj del refuerzo ---
	_follow_guide(400.0, "extraccion")
	_follow_guide(8.0)
	await _frames(8)
	var img4 := await _shot("hx-extraccion")
	check(str(hx.qa_state().phase) == "extraccion" and str(hx.qa_state().status) == "playing", "Extracción: seguir el siguiente paso llega a la fase de extracción sin perder (%s, %s)" % [str(hx.qa_state().phase), str(hx.qa_state().status)])
	check(hx.hud.chip_labels.carga.panel.visible and hx.hud.chip_labels.golpe.panel.visible and hx.hud.chip_labels.refuerzo.panel.visible, "Extracción: aparecen la carga, el golpe y el reloj del refuerzo en el dock")
	_check_overflow("Extracción")
	_measure_contrast(img4, "extraccion")
	# --- destruir a mano se pregunta (un X por costumbre quemó la carga de un agente-jugador sin avisar); si cabe, se ve la pregunta ---
	await _key(KEY_5)
	if hx.orders.needs_destroy_confirmation():
		var destroyed_before: int = hx.qa_state().issued.filter(func(i): return str(i.action) == "destroy").size()
		await _key(KEY_X)
		await _frames(3)
		check(str(hx.qa_state().dialog) == "confirmar" and _button("Sí, destruir") != null and _button("No, esperar") != null, "Destruir: apretar X a mano pregunta antes de quemar la carga (%s)" % str(hx.qa_state().dialog))
		await _shot("hx-destruir")
		_check_dialog_fit("Destruir")
		_check_text_cuts("Destruir")
		await _key(KEY_ESCAPE)
		await _frames(3)
		check(str(hx.qa_state().dialog) == "" and hx.qa_state().issued.filter(func(i): return str(i.action) == "destroy").size() == destroyed_before, "Destruir: Esc es «No»: no se destruyó nada")
	else:
		notes["destruir"] = "no se pudo armar: el arreo no estaba junto a la carga en este cuadro"
	await _phase_sweep("%dx%d" % [root.size.x, root.size.y])  # H-R1-10: las fases, el objetivo y los recortes
	# --- derrota por pasividad: parte, consejo, tres datos, reintento ≤ 3 s con el mismo mundo ---
	await _cycle_defeat_and_victory()


func _cycle_defeat_and_victory() -> void:
	# La partida de arriba ya está avanzada: se reinicia para recorrer el ciclo de J02 en el orden que pide la rúbrica (derrota, reintento, victoria).
	hx.retry("mismo_mundo")
	await _frames(4)
	var seed0 := int(hx.qa_state().seed)
	hx.qa_step(500.0)
	await _frames(10)
	var d: Dictionary = hx.qa_state()
	check(str(d.status) == "defeat" and str(d.dialog) == "parte", "Derrota: sin órdenes se pierde y aparece el parte (%s)" % str(d.status))
	await _shot("hx-derrota")
	_check_dialog_fit("Parte de derrota")
	await _diary_roundtrip("Derrota", "hx-diario")  # H-R1-2
	var cause := game.find_child("HxCause", true, false) as Label
	check(cause != null and cause.text.length() > 0 and cause.text.length() <= 140, "Derrota: la causa tiene ≤ 140 caracteres (%d)" % (cause.text.length() if cause != null else -1))
	check(cause != null and cause.text.find(":") >= 0 and cause.text.to_lower().find("a los") >= 0, "Derrota: la causa trae momento («a los m:ss») y lugar o grupo («%s»)" % (cause.text if cause != null else ""))
	check(game.find_child("HxAdvice", true, false) != null and game.find_child("HxFacts", true, false) != null, "Derrota: trae el consejo y los datos de la partida")
	var retry_button := game.find_child("HxRetry", true, false) as Button
	check(retry_button != null and _inside(Kit.rect_of(retry_button)) and not hx.dialogs.scroll_used, "Derrota: «Reintentar» queda a la vista sin scroll")
	var defeat_text := " ".join(PackedStringArray(_visible_texts()))
	check(_jargon_hits(defeat_text).is_empty(), "Derrota: el parte no usa jerga (%s)" % str(_jargon_hits(defeat_text)))
	var t0 := Time.get_ticks_msec()
	await _click_control(retry_button)
	await _frames(2)
	var retry_s := float(Time.get_ticks_msec() - t0) / 1000.0
	notes["reintento_s"] = snappedf(retry_s, 0.01)
	check(retry_s <= 3.0 and str(hx.qa_state().mode) == "play", "Derrota: del clic en «Reintentar» al primer cuadro jugable pasan ≤ 3 s (%.2f s)" % retry_s)
	check(int(hx.qa_state().seed) == seed0 and float(hx.qa_state().elapsed) == 0.0, "Derrota: reintentar mantiene el mismo mundo (semilla %d)" % seed0)
	# --- victoria: el que sigue el siguiente paso ---
	_follow_guide(1400.0)
	await _frames(10)
	var w: Dictionary = hx.qa_state()
	check(str(w.status) == "victory" and str(w.dialog) == "parte", "Victoria: seguir el siguiente paso llega al parte de victoria (%s a los %.0f s)" % [str(w.status), float(w.elapsed)])
	await _shot("hx-victoria")
	_check_dialog_fit("Parte de victoria")
	await _diary_roundtrip("Victoria")  # H-R1-2
	var vt := " ".join(PackedStringArray(_visible_texts()))
	check(vt.find("Medalla") >= 0, "Victoria: el parte muestra la medalla con su motivo")
	check(vt.find("3 de marzo") >= 0 and vt.find("9 al 16 de marzo") >= 0 and vt.find("6 de julio") >= 0, "Victoria: el epílogo está fechado")
	check(vt.find("En la realidad") >= 0 and vt.find("En tu partida") >= 0, "Victoria: contrasta «en la realidad» con «en tu partida»")
	check(vt.find("26 horas") >= 0, "Victoria: aclara el tiempo comprimido")
	check(vt.find("Güemes lo recibe") >= 0 and vt.find("expulsión") < 0, "Victoria: Güemes recibe el parte y no hay «expulsión definitiva»")
	check(_button("Ver la campaña completa: Sostener el norte") != null and _button("Jugar de nuevo") != null, "Victoria: ofrece «Ver la campaña completa: Sostener el norte» y «Jugar de nuevo»")
	check(_jargon_hits(vt).is_empty(), "Victoria: el parte no usa jerga (%s)" % str(_jargon_hits(vt)))
	var again := game.find_child("HxRetry", true, false) as Button
	check(again != null and _inside(Kit.rect_of(again)) and not hx.dialogs.scroll_used, "Victoria: «Jugar de nuevo» queda a la vista sin scroll")
	notes["ciclo_completo"] = true
	# --- pausa y ayuda ---
	await _click_control(again)
	await _frames(4)
	hx.orders.issue("reconocedores", "recon", hx.landmark_pos("bateria"), {})
	await _key(KEY_ESCAPE)
	await _frames(4)
	await _shot("hx-pausa")
	check(str(hx.qa_state().dialog) == "pausa", "Pausa: Esc abre el menú de pausa")
	_check_dialog_fit("Pausa")
	await _key(KEY_F1)
	await _key(KEY_ESCAPE)
	hx.open_help()
	await _frames(4)
	await _shot("hx-ayuda")
	_check_dialog_fit("Ayuda")
	check(" ".join(PackedStringArray(_visible_texts())).find("Cómo se rotula lo que se cuenta") >= 0, "Ayuda: explica las cinco etiquetas de fuente")
	await _key(KEY_ESCAPE)


# ---------------------------------------------------------------------------------------------------------------------
# A otras resoluciones: el chequeo de desborde

func _cycle_overflow() -> void:
	var button := _button("HUMAHUACA")
	await _click_control(button)
	await _frames(6)
	hx = game.hx
	if not check(game.mode == "hx" and is_instance_valid(hx), "Desborde: el nivel arranca"):
		return
	hx.qa_set_initial_yaw(325.0)
	await _shot("hx-briefing-1")
	_check_dialog_fit("Briefing 1")
	hx.skip_opening()
	_button("Empezar").pressed.emit()
	await _frames(4)
	hx.skip_opening()
	await _frames(10)
	var img := await _shot("hx-inicio")
	_check_overflow("Primer cuadro")
	var margins := _token_margins(hx.hud.rects())
	notes["borde_min_pct"] = margins.borde_min_pct
	notes["fichas_bajo_hud"] = margins.tapadas
	check((margins.tapadas as Array).is_empty() and float(margins.borde_min_pct) >= 5.5, "Primer cuadro: ninguna ficha bajo el HUD y todas a ≥ 5,5 %% del borde, con su anillo entero a la vista (mínimo %.1f %%; bajo el HUD: %s)" % [float(margins.borde_min_pct), str(margins.tapadas)])
	notes["controles_t0"] = int(hx.qa_state().visible_controls)
	notes["caracteres_t0"] = int(hx.qa_state().text_chars)
	notes["rects_inicio"] = _capture_rects()
	_measure_contrast(img, "inicio")
	# H-R1-7: una partida guiada eligiendo fichas con las teclas 1 a 5, con avisos y barra de órdenes a la vista
	await _probe_guided("%dx%d" % [root.size.x, root.size.y], 60)
	hx.retry("mismo_mundo")
	await _frames(4)
	# «hx-hud» como en el recorrido completo (la primera descarga y 20 s más), para que V05 tenga captura y posiciones a cualquier resolución
	_follow_guide(90.0, "ataque")
	if _reach_first_volley():
		await _key(KEY_F)
	_follow_guide(20.0)
	await _frames(8)
	var img_hud := await _shot("hx-hud")
	notes["rects"] = _capture_rects()
	_check_overflow("Ataque")
	_measure_contrast(img_hud, "ataque")
	await _phase_sweep("%dx%d" % [root.size.x, root.size.y])  # H-R1-10
	# lo que sigue es lo de siempre: una partida nueva, orden, pausa, ayuda y derrota
	hx.retry("mismo_mundo")
	await _frames(4)
	hx.orders.issue("reconocedores", "recon", hx.landmark_pos("bateria"), {})
	hx.qa_step(40.0)
	await _key(KEY_ESCAPE)
	await _frames(3)
	_check_dialog_fit("Pausa")
	await _key(KEY_ESCAPE)
	hx.open_help()
	await _frames(3)
	_check_dialog_fit("Ayuda")
	await _key(KEY_ESCAPE)
	hx.qa_step(500.0)
	await _frames(8)
	await _shot("hx-derrota")
	_check_dialog_fit("Parte de derrota")
	await _diary_roundtrip("Derrota")  # H-R1-2
	var retry_button := game.find_child("HxRetry", true, false) as Button
	check(retry_button != null and _inside(Kit.rect_of(retry_button)) and not hx.dialogs.scroll_used, "Desborde: «Reintentar» a la vista sin scroll")


func _finish() -> void:
	notes["recortes"] = {"revisiones": cuts_checked, "con_recortes": cuts_seen}
	var out := {"suite": "ui_qa_humahuaca", "checks": checks, "failures": failures, "ok": failures.is_empty(), "notes": notes, "capturas": shots}
	notes["contraste_texto_min"] = snappedf(contrast_min, 0.01) if contrast_min < 99.0 else 0.0
	var file := FileAccess.open(ProjectSettings.globalize_path(out_dir).path_join("ui_qa_report.json"), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(out, "\t"))
		file.close()
	print("UI_QA ", JSON.stringify(out))
	if is_instance_valid(game) and game.has_method("_finish_automation"):
		await game._finish_automation(0 if failures.is_empty() else 1)
	else:
		quit(0 if failures.is_empty() else 1)
