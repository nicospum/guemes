extends RefCounted
## Fichas, defensores y botín de la vista del nivel «humahuaca» (pista visual). Cada agrupación tiene SU silueta (no un disco ni un retinte del mismo cuerpo):
##   rodriguez = jinete de poncho y sombrero de ala ancha sobre su caballo · portal = infante de camisa y gorra con fusil · arias = infante con el banderín de mando
##   (marcador de interfaz, nunca una bandera) · reconocedores = dos figuras agachadas con poncho · arreo = mula con aparejo y bultos.
## Las figuras salen del generador procedural (humahuaca_gen.gd, ADDENDA A-01), con contorno oscuro (`negro_textil`) y sin uniformar: la ropa de cada una es una
## variante de las de `humahuaca_visual.json: units`.
## visual/r1 F1: las fichas van a ESCALA REAL (sin crecer con la distancia, `units.marks.figure_scale`); el bando lo da un anillo fino sobre el suelo, de radio real
## (`units.marks.ring_radius_m`), que copia el relieve y respeta la profundidad (los edificios lo tapan). Para encontrarlas lejos está la marca chica en pantalla
## (12 a 16 px) y el rótulo de una línea que dibuja la interfaz (humahuaca_overlay.gd). Antes (R1 y P2) se las estiraba hasta 48 a 72 px y el anillo llegaba a
## decenas de metros: se revirtió a propósito (plan visual/r1, aprobado por el usuario).
## visual/r1 F3: cada agrupación es una FORMACIÓN según su cantidad de hombres: una figura cada 3 o 4 hombres, entre 6 y 24 y nunca más figuras que hombres
## (`units.formation` de humahuaca_visual.json). La figura «jefe» (la silueta de siempre, con sus piezas de malla) queda en el centro de la ficha; el resto va en
## MultiMesh (un MultiMeshInstance3D por tipo y variante de ropa), en filas y columnas que miran hacia donde marcha, con un desorden chico. La vista solo puede leer
## render_state y su propio JSON (CONTRATO 3.4), así que `men` es una COPIA de groups.<id>.men de las reglas, etiquetada diseño (una prueba de test_hx_view la compara
## con las reglas). Si algún día render_state trae `men`, manda ese. Rodríguez: jinetes en la proporción caballos / hombres (16 de 48) y el resto a pie; el arreo:
## arrieros adelante y una mula cada `mule_load_kg` de carga propia. Con menos fuerza (`strength_pct`) se ven menos figuras (las de atrás); lejos (> `far_m`) se ve la
## mitad y no hay paso. El anillo del suelo encierra la huella real de la formación.
## visual/r1 F4: los jinetes de Rodríguez montan el CABALLO CRIOLLO de los modelos propios (assets/models/caballo_criollo_<pelaje>.glb, 1,45 m de cruz) con el jinete de
## 1817 (jinete_criollo_1817.glb). La jefa: caballo con esqueleto y andares (idle, walk, trot, gallop) elegidos por la velocidad real sobre el suelo, con la cadencia
## ajustada para que los cascos casi no patinen, y el jinete en un BoneAttachment3D del hueso «silla». La tropa: el caballo de tropa (sin esqueleto) y el jinete de
## tropa unidos en una malla, en MultiMesh por pelaje y ropa (pelajes mezclados por regla fija, sobre todo zainos y alazanes). El color de vértice de los GLB es
## lineal: lo dibuja el mismo material de ficha (luz propia, borde de bando, modo albedo y curva de la hora) con `vertex_linear`. El jinete se recolorea a la
## paleta como la figura del generador (poncho = abrigo de la variante oscurecido, sombrero, pañuelo de acento): el granate del modelo no se lee como enemigo.
## Si los GLB faltan (o `units.horse.enabled` es falso), vuelve el jinete del generador. Mula y arrieros siguen siendo del generador (no hay mula nueva).
## visual/r1 F5: las figuras de a pie dejan de ser los conos del generador y pasan a los modelos propios de 1817 (assets/models/persona_*.glb, tools/f5_personas.py:
## 18 huesos, reposo, paso y carrera en el lugar; `units.a_pie` de humahuaca_visual.json): infantería propia (Portal, Arias y los de a pie de Rodríguez) y reconocedores
## como paisanos de las milicias con carabina o tacuara, los conductores del arreo como arrieros y los defensores como infantes realistas. La jefa de cada formación es
## el modelo con esqueleto, que anda por su velocidad real (como el caballo de F4); la tropa y los defensores, la versión liviana quieta en MultiMesh. Se retiñen por
## pieza (cada pieza es una superficie con su rol: poncho, camisa, sombrero, pañuelo, chaqueta…) a la ropa de la variante, conservando la oclusión horneada, y se
## dibujan con el material de ficha de color lineal (luz propia, borde de bando, modo albedo y curva de la hora). El jinete usa la tacuara suelta (arma_tacuara.glb)
## en la mano. Si faltan los GLB (o `units.a_pie.enabled` es falso), vuelven las figuras del generador, que queda como respaldo. La mula sigue siendo del generador.

const V = preload("res://scripts/humahuaca/humahuaca_vocab.gd")
const Declutter = preload("res://scripts/humahuaca/view/humahuaca_declutter.gd")  # visual/r1 F6 (B-049)
const Gen = preload("res://scripts/humahuaca/view/humahuaca_gen.gd")

const MAX_THINGS := 48
const ALERT_SHADER := "res://shaders/humahuaca_alert_ring.gdshader"
const MAX_STRETCH := 4.6
## visual/r1 F1: medidas del anillo de bando y de la selección si humahuaca_visual.json no trae `units.marks`.
const MARK_DEFAULTS := {"figure_scale": 1.0, "ring_radius_m": 2.4, "ring_width_m": 0.3, "ring_edge_m": 0.18, "ring_lift_m": 0.22, "selection_gap_m": 0.9,
	"selection_width_m": 0.5, "segments": 40, "rebuild_m": 0.75, "label_font_px": 13}
const LOOT_COLOR := {"polvora": "madera_oscura", "canones": "hierro", "fusiles": "madera_oscura", "viveres": "lana_natural", "plata": "oro_laton"}
## Ganancia de los anillos de bando para llegar a la regla de color común (DIRECCION_DE_ARTE 2.1) sin sumar HEX a la paleta de 24: celeste aliado ≈ #8DB8D6,
## rojo enemigo ≈ #B8433A, hueso neutral ≈ #BFB6A3.
const RING_GAIN := {"celeste_produccion": 1.1, "rojo_reservado": 1.2, "lana_natural": 0.93}
## visual/r1 F3: valores de la formación si humahuaca_visual.json no trae `units.formation` (todos de diseño).
const FORMATION_DEFAULTS := {"men_per_figure": 3.5, "min_figures": 6, "max_figures": 24, "foot_gap_m": 1.3, "foot_depth_m": 1.6, "foot_cols": 4, "horse_gap_m": 2.4,
	"horse_depth_m": 3.6, "horse_cols": 3, "mule_gap_m": 1.9, "mule_depth_m": 2.9, "mule_cols": 2, "block_gap_m": 1.4, "jitter_m": 0.22, "jitter_deg": 9.0, "variants": 3,
	"far_m": 300.0, "far_keep": 0.5, "mule_load_kg": 100.0, "step_bob_m": 0.05, "step_hz": 1.8}
## visual/r1 F3: hombres de cada agrupación si el JSON no los trae: valor de DISEÑO de la vista (los mismos números que las reglas a la fecha), se informa como tal.
const FORMATION_MEN_FALLBACK := {"rodriguez": {"men": 48, "horses": 16}, "portal": {"men": 52}, "arias": {"men": 50}, "reconocedores": {"men": 2}, "arreo": {"men": 6, "capacity_kg": 600}}
## visual/r1 F3: radio en planta (m) de cada tipo de figura, para que el anillo encierre la huella (el jinete incluye la lanza terciada).
const FIGURE_RADIUS := {"jinete": 2.3, "a_pie": 0.55, "infante": 0.85, "mula": 1.35, "arriero": 0.55}
## visual/r1 F4: radio en planta del caballo criollo con su jinete (sin lanza): 1,46 m de la nariz al centro, 0,51 m de estribo, con el giro del desorden (≤ 9°).
const HORSE_FIGURE_RADIUS := 1.6
## visual/r1 F4: `units.horse` de humahuaca_visual.json si falta (diseño). Velocidades naturales de cada andar medidas sobre las animaciones del GLB (barrido del
## casco apoyado / tiempo de apoyo). visual/r1 F4b: con el tranco corregido en tools/f4_caballos.py, paso 1,6 m/s, trote 3,3 m/s, galope 7 m/s (antes 0,9, 2 y 4);
## los cortes van entre medio y con histéresis para que no titile; el trote llega a 6 m/s para que el trote montado de las reglas (5,5) no se vea al galope.
const HORSE_DEFAULTS := {"enabled": true, "dir": "assets/models", "horse": "caballo_criollo_%s.glb", "horse_lod": "caballo_criollo_%s_lod.glb", "rider": "jinete_criollo_1817.glb",
	"rider_lod": "jinete_criollo_1817_lod.glb", "seat_bone": "silla", "seat_y_m": 1.5, "leader_coat": "zaino", "troop_coats": ["zaino", "alazan", "zaino", "alazan", "tordillo", "zaino", "alazan", "overo"],
	"idle_below_mps": 0.25, "gaits": [{"anim": "walk", "natural_mps": 1.6, "up_to_mps": 2.4}, {"anim": "trot", "natural_mps": 3.3, "up_to_mps": 6.0}, {"anim": "gallop", "natural_mps": 7.0, "up_to_mps": 1000.0}],
	"hysteresis_mps": 0.2, "speed_scale_min": 0.6, "speed_scale_max": 2.4, "blend_s": 0.3, "sample_s": 0.25}
## visual/r1 F4: tonos de referencia (lineales) del jinete de 1817 que se recolorean: el granate del poncho (lana) y del pañuelo (lino), y el sombrero gris oscuro.
## visual/r1 F5: el sombrero del jinete nuevo va de 0,75 a 0,88 m sobre el asiento (manifiesto de personas): el corte baja de 0,95 a 0,72; además se lo reconoce por su
## pieza («sombrero»), y el corte por altura queda solo para un GLB sin roles.
const RIDER_REF := {"poncho_r": 0.31, "panuelo_r": 0.3373, "sombrero_l": 0.019, "sombrero_y_m": 0.72}
## visual/r1 F5: `units.a_pie` de humahuaca_visual.json si falta (diseño). El paso natural y la carrera salen del manifiesto de las figuras (design_mps).
const FOOT_DEFAULTS := {"enabled": true, "dir": "assets/models", "full": "%s.glb", "lod": "%s_lod.glb",
	"modelos": {"tacuara": "persona_gaucho_1817", "carabina": "persona_gaucho_1817_carabina", "arriero": "persona_arriero_1817", "realista": "persona_realista_1817"},
	"por_figura": {"infante": "carabina", "a_pie": "tacuara", "arriero": "arriero", "infante_fusil": "carabina", "infante_banderin": "carabina", "reconocedor_de_pie": "tacuara", "reconocedor_2": "carabina"},
	"defensores": {"centinela": "realista", "guardia": "realista", "fusilero": "realista", "refuerzo": "realista", "artillero": "realista", "mensajero": "arriero"},
	"ropa_realista": {"chaqueta": "lana_natural", "pantalon": "lana_parda", "vueltas": "borgona_hipotetica", "manta": "lana_parda", "sombrero": "negro_textil"},
	"ropa_mensajero": {"chaqueta": "lana_parda", "poncho": "lana_parda", "sombrero": "lana_parda", "panuelo": "borgona_hipotetica"},
	"idle_below_mps": 0.25, "gaits": [{"anim": "walk", "natural_mps": 1.15, "up_to_mps": 2.2}, {"anim": "run", "natural_mps": 3.2, "up_to_mps": 1000.0}],
	"hysteresis_mps": 0.2, "speed_scale_min": 0.6, "speed_scale_max": 1.8, "blend_s": 0.25, "sample_s": 0.25,
	"lanza": "arma_tacuara.glb", "lanza_agarre_m": [0.405, 0.22, -0.02], "lanza_inclinacion_deg": 8.0}
const ENEMY_ARCHETYPE :={"centinela": "realista_1817", "guardia": "realista_1817", "artillero": "artillero", "fusilero": "realista_1817", "mensajero": "poncho_sombrero", "refuerzo": "realista_1817"}

var gfx
var gen
var tokens: Dictionary = {}
var unit_nodes: Dictionary = {}
var unit_labels: Dictionary = {}
var scaled: Array = []  ## [{node, cat, base, px, min}]: lo que crece hasta ocupar `px` píxeles de pantalla (fichas aparte)
var part_counts: Dictionary = {}  ## partes y triángulos de cada ficha (informe de QA)

var display_offsets: Dictionary = {}  ## visual/r1 F6 (B-049): {id: corrimiento de dibujo para no pisarse} (humahuaca_declutter.gd)
var formation_report: Dictionary = {}  ## visual/r1 F3: {id: {hombres, figuras, jinetes, a_pie, mulas, arrieros, etiqueta, fuente, radio_m}} (informe de QA)
var _enemy_meshes: Dictionary = {}
var _ring_mats: Dictionary = {}
var _loot_meshes: Dictionary = {}
var _glb: Dictionary = {}  ## visual/r1 F4: escenas y mallas de los GLB del caballo y del jinete (ruta → recurso; null si falta)
var _troop_meshes: Dictionary = {}  ## visual/r1 F4: «pelaje|variante» → malla unida caballo + jinete de tropa
var _rider_meshes: Dictionary = {}  ## visual/r1 F4: jinete recoloreado por variante
var _pending_horse: Dictionary = {}  ## visual/r1 F4: el caballo de la jefa recién armado (build_tokens lo guarda en su ficha)
var _pending_foot: Dictionary = {}  ## visual/r1 F5: las figuras de a pie con esqueleto de la jefa recién armadas (build_tokens las guarda en su ficha)
var _persona_meshes: Dictionary = {}  ## visual/r1 F5: figura de a pie liviana retinteada (modelo|papel|ropa|material) → malla unida
var _skinned_copies: Dictionary = {}  ## visual/r1 F5: malla con esqueleto retinteada (malla|ropa) → copia


func setup(gfx_ref) -> void:
	gfx = gfx_ref
	gen = Gen.new(gfx.palette)


func hull_w() -> float:
	return 0.022 if bool(gfx.qcfg.get("outlines", true)) else 0.0


# ---------------------------------------------------------------------------------------------------------------------
# Fichas

func build_tokens(root_tokens: Node3D, root_labels: Node3D) -> void:
	var cfg: Dictionary = gfx.data.get("tokens", {})
	var variants: Array = (gfx.data.get("units", {}) as Dictionary).get("variants", [])
	for index in range(V.GROUPS.size()):
		var id: String = V.GROUPS[index]
		var spec: Dictionary = cfg.get(id, {})
		var root := Node3D.new()
		root.name = "ficha_" + id
		root.visible = false
		root_tokens.add_child(root)
		_pending_horse = {}
		_pending_foot = {}
		var dims := _token_parts(root, str(spec.get("shape", "infante_fusil")), spec, variants, index)
		var base_h: float = dims.x
		var form := _build_formation(root, id, spec, variants, index, dims.y)  # visual/r1 F3
		var ring_color := str(spec.get("ring_color", "celeste_produccion"))
		# visual/r1 F1: sin disco de tinta ni anillos que crecen con la distancia. Un anillo fino de radio real sobre el suelo (con filete oscuro por fuera, para el
		# suelo claro del alba) y la selección en oro, un poco más afuera. Son `top_level`: no giran con la ficha y copian el relieve (se rearman al moverse).
		var ring_r := maxf(_ring_radius(id), float(form.radius_m))  # visual/r1 F3: el anillo encierra la huella de la formación
		var edge := _ground_ring_node(root, "borde", ring_r, mark("ring_width_m") + 2.0 * mark("ring_edge_m"), mark("ring_lift_m") - 0.03,
			_ring_mat("negro_textil", 1.0, 0.75, 1))
		var ring := _ground_ring_node(root, "anillo", ring_r, mark("ring_width_m"), mark("ring_lift_m"), _ring_mat(ring_color, RING_GAIN.get(ring_color, 1.0), 1.0, 2))
		var selection := _ground_ring_node(root, "seleccion", ring_r + mark("selection_gap_m"), mark("selection_width_m"), mark("ring_lift_m") + 0.02, _ring_mat("oro_laton", 1.25, 1.0, 3))
		selection.visible = false
		var alert := MeshInstance3D.new()  # el aviso de detección (pedido de P3): un aro ámbar que se vacía mientras corre la cuenta del centinela
		alert.name = "aviso"
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * (ring_r + 1.6) * 2.0  # visual/r1 F1: a escala real, apenas más afuera que la selección
		alert.mesh = quad
		alert.material_override = _alert_material()
		alert.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		alert.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		alert.visible = false
		root_tokens.add_child(alert)  # al lado de la ficha, no dentro: no cuenta en su silueta ni en sus medidas
		unit_nodes[id] = root
		var label := Label3D.new()  # visual/r1 F1: rótulo de una línea («1 Rodríguez»), chico; en el juego lo reemplaza el de la interfaz (capa «labels» apagada)
		label.name = "etiqueta_" + id
		var short := str(spec.get("label", ""))
		label.text = str(spec.get("glyph", str(index + 1))) + ("  " + short if short != "" else "")
		label.font_size = int(mark("label_font_px")) * 2
		label.pixel_size = 0.0006
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.fixed_size = true
		label.no_depth_test = true  # el rótulo es de pantalla: se lee aunque la figura quede detrás de una casa
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.offset = Vector2(14.0, 0.0)
		label.modulate = gfx.pc("blanco_textil")
		label.outline_modulate = gfx.pc("negro_textil")
		label.outline_size = 6
		label.visible = false
		root_labels.add_child(label)
		unit_labels[id] = label
		tokens[id] = {"root": root, "base_h": base_h, "ring": ring, "edge": edge, "ring_color": ring_color, "selection": selection, "alert": alert, "alert_max": 0.0,
			"ring_at": Vector3(INF, INF, INF), "ring_r": ring_r, "formation": form.batches, "strength_f": 1.0, "far": false, "moved_ms": -100000, "stepping": false}
		formation_report[id]["radio_anillo_m"] = snappedf(ring_r, 0.01)
		if not _pending_foot.is_empty():  # visual/r1 F5: la jefa de a pie es el modelo con esqueleto y andares
			tokens[id]["foot"] = _pending_foot
			formation_report[id]["figura_a_pie"] = str(_pending_foot.get("modelos", ""))
		if not _pending_horse.is_empty():  # visual/r1 F4: la jefa va en el caballo criollo con andares
			tokens[id]["horse"] = _pending_horse
			formation_report[id]["caballo"] = "criollo, pelaje %s; tropa: %s" % [str(hcfg("leader_coat")), ", ".join(PackedStringArray(_troop_coats_of(id)))]


func _variant_of(spec: Dictionary, variants: Array, index: int, fallback_shirt: String) -> Dictionary:
	var base: Dictionary = gen.variant_for(index, variants).duplicate()
	base["camisa"] = fallback_shirt if fallback_shirt != "" else base.get("camisa", "lino_crudo")
	if str(spec.get("accent_color", "")) != "":
		base["sombrero"] = str(spec.accent_color)
	return base


## Arma las partes de la silueta `shape` bajo `root` (un nodo de malla por parte) y devuelve (alto nominal, radio del anillo) en metros.
func _token_parts(root: Node3D, shape: String, spec: Dictionary, variants: Array, index: int) -> Vector2:
	var parts: Dictionary = {}
	var body := str(spec.get("body_color", "lana_parda"))
	var hw := hull_w() * 1.4
	var vmat: Material = gfx.token_mat("aliado")
	match shape:
		"jinete":
			var v := {"camisa": "lino_crudo", "abrigo": body, "sombrero": "madera_oscura", "acento": ""}
			if horses_on():  # visual/r1 F4: el caballo criollo con esqueleto y el jinete de 1817
				return _leader_horse(root, v)
			parts = gen.rider(v, hw)
		"infante_fusil":
			var shirt := body if body in ["lino_crudo", "lana_natural"] else "lino_crudo"
			if _foot_model(shape) != "":  # visual/r1 F5: el paisano de 1817 con carabina, con esqueleto y andares
				return _foot_token(root, [[_foot_model(shape), "paisano", _variant_of(spec, variants, index, shirt), Transform3D.IDENTITY]])
			parts = gen.figure("camisa_gorra", _variant_of(spec, variants, index, shirt), "de_pie", hw)
		"infante_banderin":
			if _foot_model(shape) != "":  # visual/r1 F5: ídem, con el banderín de mando (marcador de interfaz) al lado
				_add_pennant(root, str(spec.get("accent_color", "celeste_produccion")), vmat)
				return _foot_token(root, [[_foot_model(shape), "paisano", _variant_of(spec, variants, index, "lana_natural"), Transform3D.IDENTITY]])
			parts = gen.figure("camisa_gorra", _variant_of(spec, variants, index, "lana_natural"), "de_pie", hw)
			_add_pennant(root, str(spec.get("accent_color", "celeste_produccion")), vmat)
		"agachados":
			if _foot_model("reconocedor_de_pie") != "" and _foot_model("reconocedor_2") != "":  # visual/r1 F5: los dos baqueanos, de pie (no hay pose agachada en el modelo)
				var pair: Array = []
				for k in range(2):
					var v: Dictionary = _variant_of(spec, variants, index + k + 1, "")
					v["abrigo"] = "lana_natural" if k == 0 else body
					v["sombrero"] = "madera_oscura"
					pair.append([_foot_model("reconocedor_de_pie" if k == 0 else "reconocedor_2"), "paisano", v,
						Transform3D(Basis(Vector3.UP, deg_to_rad(-12.0 + 30.0 * float(k))), Vector3(-0.75 + 1.5 * float(k), 0.0, -0.6 * float(k))), "idle" if k == 0 else "crouch"])  # F6: el 2.º, agachado
				return _foot_token(root, pair)
			parts = _crouched_pair(body, spec, variants, index, hw)
		"mula_cargada":
			parts = gen.mule(hw)
		_:
			if _foot_model("a_pie") != "":
				return _foot_token(root, [[_foot_model("a_pie"), "paisano", _variant_of(spec, variants, index, ""), Transform3D.IDENTITY]])
			parts = gen.figure("poncho_sombrero", _variant_of(spec, variants, index, ""), "de_pie", hw)
	var lo := Vector3(1.0e9, 1.0e9, 1.0e9)
	var hi := Vector3(-1.0e9, -1.0e9, -1.0e9)
	var triangles := 0
	for key in parts:
		var mesh: ArrayMesh = parts[key]
		var box := mesh.get_aabb()
		lo = Vector3(minf(lo.x, box.position.x), minf(lo.y, box.position.y), minf(lo.z, box.position.z))
		hi = Vector3(maxf(hi.x, box.end.x), maxf(hi.y, box.end.y), maxf(hi.z, box.end.z))
		triangles += (mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		gfx.part_node(root, str(key), mesh, vmat)
	part_counts[str(root.name)] = {"partes": parts.size(), "triangulos": triangles}
	var radius := maxf(maxf(absf(lo.x), absf(hi.x)), maxf(absf(lo.z), absf(hi.z)))
	return Vector2(hi.y, radius + 0.35)


## El banderín de mando de Arias: un triángulo chico en el extremo de un asta, de color de marcador (celeste de producción): NO es una bandera.
func _add_pennant(root: Node3D, color_id: String, vmat: Material) -> void:
	var mb = gen.builder()
	var wood: Color = gfx.pc("madera_oscura")
	mb.beam(Vector3(0.45, 0.2, -0.1), Vector3(0.45, 2.9, -0.1), 0.05, wood)
	mb.tri(Vector3(0.45, 2.85, -0.1), Vector3(1.15, 2.6, -0.1), Vector3(0.45, 2.35, -0.1), gfx.pc(color_id))
	mb.tri(Vector3(0.45, 2.85, -0.12), Vector3(0.45, 2.35, -0.12), Vector3(1.15, 2.6, -0.12), gfx.pc(color_id).darkened(0.1))
	gfx.part_node(root, "banderin", mb.build(hull_w() * 1.4), vmat)


## Los reconocedores: un baqueano de pie con su lanza y otro agachado delante, que mira (de ropa distinta: uno de lana natural, que se lee sobre el suelo oscuro).
## Antes eran dos figuras agachadas: bajas y anchas, al estirarlas hasta el alto pedido en pantalla se volvían una mancha ancha del doble de las otras fichas.
func _crouched_pair(body: String, spec: Dictionary, variants: Array, index: int, hw: float) -> Dictionary:
	var out := {}
	var merged := {}
	for k in range(2):
		var v: Dictionary = _variant_of(spec, variants, index + k + 1, "")
		v["abrigo"] = "lana_natural" if k == 0 else body
		v["sombrero"] = "madera_oscura"
		var parts: Dictionary = gen.figure_parts("poncho_sombrero", v, "de_pie" if k == 0 else "agachado")
		for key in parts:
			if not merged.has(key):
				merged[key] = gen.builder()
			var mb = merged[key]
			mb.push()
			mb.xf = Transform3D(Basis(Vector3.UP, deg_to_rad(-12.0 + 30.0 * float(k))), Vector3(-0.55 + 1.15 * float(k), 0.0, -0.45 * float(k)))
			mb.absorb(parts[key])
			if k == 0 and str(key) == "equipo":  # el baqueano de pie lleva una tacuara larga (caña con punta): lo distingue de la mula del arreo, que mide lo mismo
				mb.beam(Vector3(0.43, 1.9, -0.1), Vector3(0.46, 2.4, -0.1), 0.04, gfx.pc("madera_oscura", 1.15))
				mb.cyl_between(Vector3(0.46, 2.4, -0.1), Vector3(0.47, 2.58, -0.1), 0.045, 0.0, 6, gfx.pc("hierro"))
			mb.pop()
	for key in merged:
		out[key] = (merged[key] as Object).call("build", hw)
	return out


# ---------------------------------------------------------------------------------------------------------------------
# visual/r1 F3: formación según la cantidad de hombres

## Una medida de `units.formation` (humahuaca_visual.json) o su valor por defecto.
func fcfg(key: String) -> float:
	var cfg: Variant = (gfx.data.get("units", {}) as Dictionary).get("formation", {}) if gfx != null else {}
	var v: Variant = (cfg as Dictionary).get(key, FORMATION_DEFAULTS.get(key, 0.0)) if cfg is Dictionary else FORMATION_DEFAULTS.get(key, 0.0)
	return float(v) if (typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT) else float(FORMATION_DEFAULTS.get(key, 0.0))


## Hombres (y caballos o carga propia) de una agrupación, con su etiqueta y su fuente: lo de `units.formation.groups` o, si falta, el valor de diseño de la vista.
func group_men(id: String) -> Dictionary:
	var cfg: Variant = (gfx.data.get("units", {}) as Dictionary).get("formation", {}) if gfx != null else {}
	var groups: Variant = (cfg as Dictionary).get("groups", {}) if cfg is Dictionary else {}
	if groups is Dictionary and (groups as Dictionary).get(id, null) is Dictionary and ((groups as Dictionary)[id] as Dictionary).has("men"):
		var g: Dictionary = (groups as Dictionary)[id]
		return {"men": int(g.men), "horses": int(g.get("horses", 0)), "capacity_kg": float(g.get("capacity_kg", 0.0)), "tag": str(g.get("tag", "diseno")),
			"source": str(g.get("source", ""))}
	var f: Dictionary = FORMATION_MEN_FALLBACK.get(id, {"men": 0})
	return {"men": int(f.get("men", 0)), "horses": int(f.get("horses", 0)), "capacity_kg": float(f.get("capacity_kg", 0.0)), "tag": "diseno",
		"source": "valor de diseño de la vista: faltaba en los datos"}


## Cuántas figuras de cada tipo lleva la formación de una agrupación de silueta `shape` con los hombres de `g`. Regla: round(hombres / men_per_figure) entre
## min_figures y max_figures, sin pasar nunca de los hombres (los dos reconocedores son dos figuras, no seis). El arreo: un arriero cada 3 o 4 hombres y una mula
## cada `mule_load_kg` de su carga propia. `leader` = las figuras que ya dibuja la ficha con sus piezas (la pareja de reconocedores cuenta dos).
func formation_counts(shape: String, g: Dictionary) -> Dictionary:
	var men := maxi(int(g.get("men", 0)), 0)
	var per := maxf(fcfg("men_per_figure"), 1.0)
	var lo := mini(int(fcfg("min_figures")), men)
	var hi := maxi(mini(int(fcfg("max_figures")), men), lo)
	var out := {"figures": 1, "leader": 1, "jinetes": 0, "a_pie": 0, "infantes": 0, "mulas": 0, "arrieros": 0}
	if shape == "mula_cargada":
		var drivers := clampi(roundi(float(men) / per), mini(1, men), men)
		var mules := clampi(roundi(float(g.get("capacity_kg", 0.0)) / maxf(fcfg("mule_load_kg"), 1.0)), 1, int(fcfg("max_figures")))
		out.mulas = mules
		out.arrieros = drivers
		out.figures = mules + drivers
		return out
	var figures := maxi(clampi(roundi(float(men) / per), lo, hi), 1)
	out.figures = figures
	match shape:
		"jinete":
			var horses := int(g.get("horses", 0))
			var riders := clampi(roundi(float(figures) * float(horses) / float(maxi(men, 1))), 1, figures) if horses > 0 else figures
			out.jinetes = riders
			out.a_pie = figures - riders
		"agachados":
			out.leader = mini(2, figures)
			out.a_pie = figures - int(out.leader)
		_:
			out.infantes = figures
	return out


## Posiciones en el plano de la ficha (frente hacia −Z) de bloques puestos uno detrás de otro, cada uno en filas de `cols` con separación lateral `gap` y de fondo
## `depth`; la última fila de un bloque va centrada. `blocks` = [{type, n, cols, gap, depth}] de adelante hacia atrás. Devuelve [{type, at: Vector2(x, z)}] centrado.
func formation_layout(blocks: Array) -> Array:
	var out: Array = []
	var z := 0.0
	var prev_depth := 0.0
	for b in blocks:
		var n := int(b.n)
		if n <= 0:
			continue
		var cols := maxi(int(b.cols), 1)
		var depth := float(b.depth)
		if not out.is_empty():
			z += maxf(prev_depth, depth) * 0.5 + fcfg("block_gap_m")
		var rows := int(ceil(float(n) / float(cols)))
		for r in range(rows):
			var in_row := mini(cols, n - r * cols)
			for c in range(in_row):
				out.append({"type": str(b.type), "at": Vector2((float(c) - float(in_row - 1) * 0.5) * float(b.gap), z + float(r) * depth)})
		z += float(rows - 1) * depth
		prev_depth = depth
	if out.is_empty():
		return out
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for slot in out:
		lo = Vector2(minf(lo.x, slot.at.x), minf(lo.y, slot.at.y))
		hi = Vector2(maxf(hi.x, slot.at.x), maxf(hi.y, slot.at.y))
	var mid := (lo + hi) * 0.5
	for slot in out:
		slot.at = (slot.at as Vector2) - mid
	return out


## Arma bajo `root` las figuras de la formación que no son la ficha jefe: un MultiMeshInstance3D por tipo y variante de ropa. La jefa queda en el origen (se
## quita de la grilla el lugar de su tipo más cercano al centro y se corre todo para que caiga ahí). Devuelve {batches: [{mmi, base: [Transform3D], bob}], radius_m}:
## cada lote de adelante hacia atrás, así los primeros que se ocultan con menos fuerza o de lejos son los de atrás. `leader_r` = radio de la ficha jefe.
func _build_formation(root: Node3D, id: String, spec: Dictionary, variants: Array, index: int, leader_r: float) -> Dictionary:
	var shape := str(spec.get("shape", "infante_fusil"))
	var g := group_men(id)
	var n := formation_counts(shape, g)
	formation_report[id] = {"hombres": int(g.men), "figuras": int(n.figures), "jinetes": int(n.jinetes), "a_pie": int(n.a_pie), "infantes": int(n.infantes),
		"mulas": int(n.mulas), "arrieros": int(n.arrieros), "etiqueta": str(g.tag), "fuente": str(g.source)}
	var foot_gap := fcfg("foot_gap_m")
	var foot_depth := fcfg("foot_depth_m")
	var foot_cols := int(fcfg("foot_cols"))
	var blocks: Array = []
	var leader_type := ""
	match shape:
		"jinete":  # los jinetes adelante, más abiertos; los de a pie detrás
			blocks = [{"type": "jinete", "n": n.jinetes, "cols": int(fcfg("horse_cols")), "gap": fcfg("horse_gap_m"), "depth": fcfg("horse_depth_m")},
				{"type": "a_pie", "n": n.a_pie, "cols": foot_cols, "gap": foot_gap, "depth": foot_depth}]
			leader_type = "jinete"
		"mula_cargada":  # los arrieros adelante y la recua de dos en fondo
			blocks = [{"type": "arriero", "n": n.arrieros, "cols": mini(2, maxi(int(n.arrieros), 1)), "gap": foot_gap * 1.4, "depth": foot_depth},
				{"type": "mula", "n": n.mulas, "cols": int(fcfg("mule_cols")), "gap": fcfg("mule_gap_m"), "depth": fcfg("mule_depth_m")}]
			leader_type = "mula"
		"agachados":  # la pareja de la ficha ya son los dos hombres; si hubiera más, van detrás
			blocks = [{"type": "a_pie", "n": n.a_pie, "cols": foot_cols, "gap": foot_gap, "depth": foot_depth}]
		_:
			blocks = [{"type": "infante", "n": n.infantes, "cols": foot_cols, "gap": foot_gap, "depth": foot_depth}]
			leader_type = "infante"
	var slots := formation_layout(blocks)
	var shift := Vector2(0.0, 2.6) if leader_type == "" else Vector2.ZERO
	if leader_type != "":
		var best := -1
		var best_d := INF
		for i in range(slots.size()):
			if str(slots[i].type) == leader_type and (slots[i].at as Vector2).length() < best_d:
				best_d = (slots[i].at as Vector2).length()
				best = i
		if best >= 0:
			shift = -(slots[best].at as Vector2)
			slots.remove_at(best)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("formacion_" + id)
	var jit := fcfg("jitter_m")
	var jit_deg := fcfg("jitter_deg")
	var radius := leader_r
	var by_type: Dictionary = {}
	for slot in slots:
		var at: Vector2 = (slot.at as Vector2) + shift + Vector2(rng.randf_range(-jit, jit), rng.randf_range(-jit, jit))
		radius = maxf(radius, at.length() + _figure_radius(str(slot.type)))
		if not by_type.has(str(slot.type)):
			by_type[str(slot.type)] = []
		(by_type[str(slot.type)] as Array).append(Transform3D(Basis(Vector3.UP, deg_to_rad(rng.randf_range(-jit_deg, jit_deg))), Vector3(at.x, 0.0, at.y)))
	var batches: Array = []
	var triangles := 0
	for type in by_type:
		var list: Array = by_type[type]
		list.sort_custom(func(a, b): return (a as Transform3D).origin.z < (b as Transform3D).origin.z)  # de adelante (−Z) hacia atrás
		var kinds := 1 if str(type) == "mula" else maxi(int(fcfg("variants")), 1)
		# visual/r1 F4: un lote por variante de ropa (como en F3) y, si van a caballo, también por pelaje: la figura k lleva la ropa k % variantes y el pelaje
		# troop_coats[(k + 1) % n] (regla fija: la misma formación sale siempre igual)
		var coats: Array = hcfg("troop_coats") if str(type) == "jinete" and horses_on() else []
		var groups: Dictionary = {}
		var order: Array = []
		for k in range(list.size()):
			var coat := str(coats[(k + 1) % coats.size()]) if not coats.is_empty() else ""
			var key := "%s|%d" % [coat, k % kinds]
			if not groups.has(key):
				groups[key] = {"v": k % kinds, "coat": coat, "base": []}
				order.append(key)
			(groups[key].base as Array).append(list[k])
		for key in order:
			var v := int(groups[key].v)
			var coat_k := str(groups[key].coat)
			var base: Array = groups[key].base
			var mesh := _troop_horse_mesh(coat_k, gen.variant_for(index + v + 1, variants)) if coat_k != "" else _formation_mesh(str(type), spec, variants, index + v + 1)
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mesh
			mm.instance_count = base.size()
			for k in range(base.size()):
				mm.set_instance_transform(k, base[k])
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "formacion_%s_%d" % [str(type), v] + ("_" + coat_k if coat_k != "" else "")
			mmi.multimesh = mm
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(mmi)
			triangles += base.size() * (mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
			batches.append({"mmi": mmi, "base": base, "ground": base.duplicate(), "bob": fcfg("step_bob_m") * (1.6 if str(type) in ["jinete", "mula"] else 1.0), "coat": coat_k})
	formation_report[id]["triangulos_formacion"] = triangles
	formation_report[id]["lotes"] = batches.size()
	return {"batches": batches, "radius_m": radius + 0.3}


## La malla de UNA figura de la formación (las partes unidas: el MultiMesh dibuja una sola malla), con la ropa de la variante `vi`.
func _formation_mesh(type: String, spec: Dictionary, variants: Array, vi: int) -> ArrayMesh:
	var hw := hull_w() * 1.4
	var parts: Dictionary = {}
	match type:
		"jinete":
			var v: Dictionary = gen.variant_for(vi, variants).duplicate()
			v["sombrero"] = "madera_oscura"
			v["acento"] = ""
			parts = gen.rider(v, hw)
		"mula":
			parts = gen.mule(hw)
		"infante":
			if _foot_model(type) != "":  # visual/r1 F5: el paisano con carabina, versión liviana quieta
				return _persona_mesh(_foot_model(type), "paisano", _variant_of(spec, variants, vi, ""), true, gfx.token_mat("aliado_glb"))
			parts = gen.figure("camisa_gorra", _variant_of(spec, variants, vi, ""), "de_pie", hw)
		_:  # a pie y arrieros: poncho y sombrero
			var v2: Dictionary = gen.variant_for(vi, variants).duplicate()
			v2["acento"] = ""
			if _foot_model(type) != "":  # visual/r1 F5: el paisano con tacuara (a pie) o el arriero (arreo)
				return _persona_mesh(_foot_model(type), "arriero" if type == "arriero" else "paisano", v2, true, gfx.token_mat("aliado_glb"))
			parts = gen.figure("poncho_sombrero", v2, "de_pie", hw)
	return _merged(parts, gfx.token_mat("aliado"))


## Une las partes {nombre: ArrayMesh} de una figura en una malla de dos superficies (la figura y su casco de contorno) con sus materiales puestos.
func _merged(parts: Dictionary, material: Material) -> ArrayMesh:
	var bv := PackedVector3Array()
	var bn := PackedVector3Array()
	var bc := PackedColorArray()
	var bi := PackedInt32Array()
	var hv := PackedVector3Array()
	var hn := PackedVector3Array()
	var hi := PackedInt32Array()
	for key in parts:
		var m: ArrayMesh = parts[key]
		if m.get_surface_count() > 0:
			var a := m.surface_get_arrays(0)
			var base := bv.size()
			bv.append_array(a[Mesh.ARRAY_VERTEX])
			bn.append_array(a[Mesh.ARRAY_NORMAL])
			bc.append_array(a[Mesh.ARRAY_COLOR])
			for i in (a[Mesh.ARRAY_INDEX] as PackedInt32Array):
				bi.append(base + i)
		if m.get_surface_count() > 1:
			var h := m.surface_get_arrays(1)
			var hbase := hv.size()
			hv.append_array(h[Mesh.ARRAY_VERTEX])
			hn.append_array(h[Mesh.ARRAY_NORMAL])
			for i in (h[Mesh.ARRAY_INDEX] as PackedInt32Array):
				hi.append(hbase + i)
	var mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = bv
	arrays[Mesh.ARRAY_NORMAL] = bn
	arrays[Mesh.ARRAY_COLOR] = bc
	arrays[Mesh.ARRAY_INDEX] = bi
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	if not hv.is_empty():
		var hull: Array = []
		hull.resize(Mesh.ARRAY_MAX)
		hull[Mesh.ARRAY_VERTEX] = hv
		hull[Mesh.ARRAY_NORMAL] = hn
		hull[Mesh.ARRAY_INDEX] = hi
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, hull)
		mesh.surface_set_material(1, gfx.outline_mat())
	return mesh


# ---------------------------------------------------------------------------------------------------------------------
# visual/r1 F4: caballo criollo y jinete de 1817 (GLB de assets/models, manifiesto f4_caballos_manifest.json)

## Una medida de `units.horse` (humahuaca_visual.json) o su valor por defecto.
func hcfg(key: String) -> Variant:
	var cfg: Variant = (gfx.data.get("units", {}) as Dictionary).get("horse", {}) if gfx != null else {}
	if cfg is Dictionary and (cfg as Dictionary).has(key):
		return (cfg as Dictionary)[key]
	return HORSE_DEFAULTS.get(key)


## Verdadero si los jinetes van en el caballo criollo: `units.horse.enabled` y los cuatro GLB que hacen falta (jefa y tropa) están.
func horses_on() -> bool:
	if not bool(hcfg("enabled")):
		return false
	var coat := str(hcfg("leader_coat"))
	return _glb_mesh(str(hcfg("horse")) % coat) != null and _glb_mesh(str(hcfg("horse_lod")) % coat) != null and _glb_mesh(str(hcfg("rider"))) != null \
		and _glb_mesh(str(hcfg("rider_lod"))) != null


## Radio en planta de una figura de la formación de tipo `type` (para que el anillo encierre la huella).
func _figure_radius(type: String) -> float:
	if type == "jinete" and horses_on():
		return HORSE_FIGURE_RADIUS
	return float(FIGURE_RADIUS.get(type, 0.6))


## La escena de un GLB de `units.horse.dir` (cargada una vez; null si no está).
func _glb_scene(file: String) -> PackedScene:
	var path := "res://%s/%s" % [str(hcfg("dir")), file]
	if not _glb.has(path):
		_glb[path] = load(path) as PackedScene if ResourceLoader.exists(path) else null
	return _glb[path]


## La malla (la primera) de un GLB: la del caballo de tropa o la del jinete. null si falta.
func _glb_mesh(file: String) -> Mesh:
	var key := "malla|" + file
	if not _glb.has(key):
		var scene := _glb_scene(file)
		var mesh: Mesh = null
		if scene != null:
			var n := scene.instantiate()
			for mi in n.find_children("*", "MeshInstance3D", true, false):
				mesh = (mi as MeshInstance3D).mesh
				break
			n.free()
		_glb[key] = mesh
	return _glb[key]


## Los colores (lineales) a los que va el jinete con la ropa `v`, como la figura de poncho y sombrero del generador: poncho = abrigo oscurecido 0,46, sombrero =
## sombrero oscurecido 0,2, pañuelo = acento (azul elegido si la variante no trae). Lo demás del jinete (piel, botas, correas, botones) queda como en el modelo.
func _rider_targets(v: Dictionary) -> Dictionary:
	var accent := str(v.get("acento", ""))
	return {"poncho": gfx.pc(str(v.get("abrigo", "lana_parda"))).darkened(0.46).srgb_to_linear(),
		"sombrero": gfx.pc(str(v.get("sombrero", "madera_oscura"))).darkened(0.2).srgb_to_linear(),
		"panuelo": gfx.pc(accent if accent != "" else "azul_elegido").srgb_to_linear()}


## Agrega a `into` ({v, n, c, i}) las superficies de `mesh` (sin el «ancla» de 2 mm que el exportador pone primera) con `xf` aplicado. Si `targets` no está vacío
## es el jinete: el granate de la lana (poncho) y del lino (pañuelo) y el gris del sombrero se llevan a la paleta conservando el sombreado de cada vértice.
func _append_glb(mesh: Mesh, xf: Transform3D, targets: Dictionary, into: Dictionary) -> void:
	for si in range(mesh.get_surface_count()):
		var mat := mesh.surface_get_material(si)
		var mname := str(mat.resource_name) if mat != null else ""
		if mname.ends_with("ancla"):
			continue
		var a := mesh.surface_get_arrays(si)
		var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var cols: PackedColorArray = a[Mesh.ARRAY_COLOR] if a[Mesh.ARRAY_COLOR] is PackedColorArray else PackedColorArray()
		var base: int = (into.v as PackedVector3Array).size()
		for k in range(verts.size()):
			var c: Color = cols[k] if k < cols.size() else Color(0.5, 0.5, 0.5)
			if not targets.is_empty():
				c = _rider_color(c, verts[k], mname, targets)
			into.v.append(xf * verts[k])
			into.n.append((xf.basis * normals[k]).normalized() if k < normals.size() else Vector3.UP)
			into.c.append(c)
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] is PackedInt32Array else PackedInt32Array()
		if idx.is_empty():
			for k in range(verts.size()):
				into.i.append(base + k)
		else:
			for k in idx:
				into.i.append(base + k)


## El color de un vértice del jinete con la ropa de la variante (ver _rider_targets). `at` = posición relativa al asiento.
func _rider_color(c: Color, at: Vector3, mname: String, targets: Dictionary) -> Color:
	var garnet := c.r > 0.03 and c.r > c.g * 2.5 and c.r > c.b * 2.5
	var t: Color
	var f := 1.0
	var role := _role_of(mname)  # visual/r1 F5: el jinete nuevo trae una pieza por rol («F4 | sombrero | wool»)
	if role == "sombrero" or (role == "" and mname.ends_with("wool") and not garnet and at.y > float(RIDER_REF.sombrero_y_m)):
		t = targets.sombrero
		f = clampf((c.r + c.g + c.b) / 3.0 / float(RIDER_REF.sombrero_l), 0.3, 1.3)
	elif mname.ends_with("wool") and garnet:
		t = targets.poncho
		f = clampf(c.r / float(RIDER_REF.poncho_r), 0.2, 1.15)
	elif mname.ends_with("linen") and garnet:
		t = targets.panuelo
		f = clampf(c.r / float(RIDER_REF.panuelo_r), 0.2, 1.15)
	elif mname.ends_with("wool") and at.y > float(RIDER_REF.sombrero_y_m):
		t = targets.sombrero
		f = clampf((c.r + c.g + c.b) / 3.0 / float(RIDER_REF.sombrero_l), 0.3, 1.3)
	else:
		return c
	return Color(t.r * f, t.g * f, t.b * f, c.a)


## La tacuara (caña con punta de hierro) que lleva el jinete, parada junto al estribo derecho y apenas inclinada hacia adelante, como la del baqueano de los
## reconocedores y la del jinete del generador (que la llevaba terciada): diseño. Sube la silueta a ≈ 3,5 m sin ensanchar la huella, y la distingue de la pareja de
## reconocedores, que medía casi lo mismo en planta y en alto (TR-098). El generador da color sRGB: se lo pasa a lineal como el de los GLB.
func _append_lance(xf: Transform3D, into: Dictionary) -> void:
	# visual/r1 F5: la tacuara del modelo (arma_tacuara.glb: origen en el agarre, la punta hacia +Y) en la mano derecha del jinete nuevo, que está a (0,405; 0,22;
	# −0,02) m del asiento (manifiesto de personas, hand_R_seat_godot), con la punta un poco hacia adelante. Si falta el GLB, la caña del generador de antes.
	var lance: Mesh = _scene_mesh("res://%s/%s" % [str(pcfg("dir")), str(pcfg("lanza"))])
	if lance != null:
		var g: Variant = pcfg("lanza_agarre_m")
		var grip := Vector3(float(g[0]), float(g[1]), float(g[2])) if g is Array and (g as Array).size() == 3 else Vector3(0.405, 0.22, -0.02)
		_append_glb(lance, xf * Transform3D(Basis(Vector3.RIGHT, -deg_to_rad(float(pcfg("lanza_inclinacion_deg")))), grip), {}, into)
		return
	var mb = gen.builder()
	mb.beam(Vector3(0.47, -0.62, 0.16), Vector3(0.5, 1.78, -0.2), 0.045, gfx.pc("madera_oscura", 1.15))
	mb.cyl_between(Vector3(0.5, 1.78, -0.2), Vector3(0.505, 2.0, -0.235), 0.055, 0.0, 6, gfx.pc("hierro", 1.3))
	var m: ArrayMesh = mb.build(0.0)
	var a := m.surface_get_arrays(0)
	var cols: PackedColorArray = a[Mesh.ARRAY_COLOR]
	for k in range(cols.size()):
		cols[k] = cols[k].srgb_to_linear()
	var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var base: int = (into.v as PackedVector3Array).size()
	for k in range(verts.size()):
		into.v.append(xf * verts[k])
		into.n.append((xf.basis * normals[k]).normalized())
		into.c.append(cols[k])
	for k in (a[Mesh.ARRAY_INDEX] as PackedInt32Array):
		into.i.append(base + k)


func _arrays_mesh(into: Dictionary, material: Material) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = into.v
	arrays[Mesh.ARRAY_NORMAL] = into.n
	arrays[Mesh.ARRAY_COLOR] = into.c
	arrays[Mesh.ARRAY_INDEX] = into.i
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	return mesh


func _new_arrays() -> Dictionary:
	return {"v": PackedVector3Array(), "n": PackedVector3Array(), "c": PackedColorArray(), "i": PackedInt32Array()}


## El jinete de 1817 (`lod` = el de tropa) con la ropa `v`, en una sola superficie con el material de ficha de los GLB. Origen = asiento.
func _rider_mesh(v: Dictionary, lod: bool) -> ArrayMesh:
	var key := "%s|%s|%s|%s" % [str(v.get("abrigo", "")), str(v.get("sombrero", "")), str(v.get("acento", "")), str(lod)]
	if not _rider_meshes.has(key):
		var into := _new_arrays()
		_append_glb(_glb_mesh(str(hcfg("rider_lod" if lod else "rider"))), Transform3D.IDENTITY, _rider_targets(v), into)
		_append_lance(Transform3D.IDENTITY, into)
		_rider_meshes[key] = _arrays_mesh(into, gfx.token_mat("aliado_glb"))
	return _rider_meshes[key]


## Una figura de la tropa montada: el caballo de tropa de pelaje `coat` y el jinete de tropa con la ropa `variant` a la altura del asiento, en UNA malla (el MultiMesh
## dibuja una sola). Es lo mismo que el caballo × Transform3D(Basis(), (0, asiento, 0)) del jinete, sin un segundo MultiMesh que haya que mantener a la par.
func _troop_horse_mesh(coat: String, variant: Dictionary) -> ArrayMesh:
	var v := variant.duplicate()
	v["sombrero"] = "madera_oscura"  # como la tropa montada del generador
	v["acento"] = ""
	var key := "%s|%s|%s" % [coat, str(v.get("abrigo", "")), str(v.get("sombrero", ""))]
	if not _troop_meshes.has(key):
		var into := _new_arrays()
		_append_glb(_glb_mesh(str(hcfg("horse_lod")) % coat), Transform3D.IDENTITY, {}, into)
		var seat := Transform3D(Basis(), Vector3(0.0, float(hcfg("seat_y_m")), 0.0))
		_append_glb(_glb_mesh(str(hcfg("rider_lod"))), seat, _rider_targets(v), into)
		_append_lance(seat, into)
		_troop_meshes[key] = _arrays_mesh(into, gfx.token_mat("aliado_glb"))
	return _troop_meshes[key]


## La figura jefa de Rodríguez: el caballo criollo con esqueleto (pelaje `units.horse.leader_coat`) y el jinete de 1817 con la ropa `v` en un BoneAttachment3D del
## hueso «silla» (transformación identidad: el origen del jinete es el asiento). Arranca en reposo (idle). Devuelve (alto nominal, radio del anillo) como _token_parts.
func _leader_horse(root: Node3D, v: Dictionary) -> Vector2:
	var mat: Material = gfx.token_mat("aliado_glb")
	var horse := _glb_scene(str(hcfg("horse")) % str(hcfg("leader_coat"))).instantiate() as Node3D
	horse.name = "caballo"
	root.add_child(horse)
	var lo := Vector3(1.0e9, 1.0e9, 1.0e9)
	var hi := Vector3(-1.0e9, -1.0e9, -1.0e9)
	var triangles := 0
	for mi in horse.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var box := m.mesh.get_aabb()
		lo = Vector3(minf(lo.x, box.position.x), minf(lo.y, box.position.y), minf(lo.z, box.position.z))
		hi = Vector3(maxf(hi.x, box.end.x), maxf(hi.y, box.end.y), maxf(hi.z, box.end.z))
		for si in range(m.mesh.get_surface_count()):
			triangles += m.mesh.surface_get_array_index_len(si) / 3
	var skeletons := horse.find_children("*", "Skeleton3D", true, false)
	var rider := MeshInstance3D.new()
	rider.name = "jinete"
	rider.mesh = _rider_mesh(v, false)
	rider.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not skeletons.is_empty():
		var seat := BoneAttachment3D.new()
		seat.name = "silla"
		seat.bone_name = str(hcfg("seat_bone"))
		(skeletons[0] as Skeleton3D).add_child(seat)
		seat.add_child(rider)
	else:
		rider.position = Vector3(0.0, float(hcfg("seat_y_m")), 0.0)
		horse.add_child(rider)
	var rbox := rider.mesh.get_aabb()
	hi.y = maxf(hi.y, float(hcfg("seat_y_m")) + rbox.end.y)
	triangles += rider.mesh.surface_get_array_index_len(0) / 3
	var players := horse.find_children("*", "AnimationPlayer", true, false)
	var player: AnimationPlayer = players[0] if not players.is_empty() else null
	if player != null and player.has_animation("idle"):
		player.play("idle")
	_pending_horse = {"player": player, "gait": "idle", "speed": 0.0, "at": Vector3(INF, INF, INF), "t": -1.0, "scale": 1.0}
	part_counts[str(root.name)] = {"partes": 2, "triangulos": triangles}
	var radius := maxf(maxf(absf(lo.x), absf(hi.x)), maxf(absf(lo.z), absf(hi.z)))
	return Vector2(hi.y, radius + 0.35)


## El andar de la jefa a caballo de la agrupación `id` según su velocidad real sobre el suelo, medida cada `sample_s` segundos (`now_s` = reloj real, en segundos;
## pasarlo permite probarlo sin esperar). Debajo de `idle_below_mps`, reposo; si no, el primer andar cuyo `up_to_mps` alcanza la velocidad, con histéresis, y la
## cadencia = velocidad / velocidad natural del andar (entre speed_scale_min y speed_scale_max: más allá los cascos patinan un poco). Un salto de más de 40 m/s (la
## ficha se reubicó) no cuenta. De lejos (> far_m) o con la ficha oculta la animación se detiene (no se ve y cuesta).
func update_gait(id: String, now_s: float) -> void:
	var info: Dictionary = tokens.get(id, {})
	var h: Dictionary = info.get("horse", {})
	if h.is_empty() or h.player == null:
		return
	_drive_gait(info, h, [h.player], now_s, hcfg)


## visual/r1 F5: lo mismo para la jefa de a pie (las figuras con esqueleto de la ficha): reposo, paso (natural 1,15 m/s) o carrera (3,2 m/s) con `units.a_pie`.
func update_foot_gait(id: String, now_s: float) -> void:
	var info: Dictionary = tokens.get(id, {})
	var h: Dictionary = info.get("foot", {})
	if h.is_empty() or (h.get("players", []) as Array).is_empty():
		return
	_drive_gait(info, h, h.players, now_s, pcfg)


## El andar de las animaciones `players` de una ficha (caballo o figuras de a pie) según su velocidad sobre el suelo, con los cortes y cadencias de `cfg` (hcfg o pcfg).
func _drive_gait(info: Dictionary, h: Dictionary, players: Array, now_s: float, cfg: Callable) -> void:
	var root: Node3D = info.root
	var live := root.visible and not bool(info.far)
	for p in players:
		if (p as AnimationPlayer).active != live:
			(p as AnimationPlayer).active = live
	if float(h.t) < 0.0 or (h.at as Vector3).x == INF:
		h["t"] = now_s
		h["at"] = root.position
		return
	var dt := now_s - float(h.t)
	if dt < float(cfg.call("sample_s")):
		return
	var d := Vector2(root.position.x - (h.at as Vector3).x, root.position.z - (h.at as Vector3).z).length()
	h["t"] = now_s
	h["at"] = root.position
	var v := d / maxf(dt, 0.001)
	if v > 40.0:
		return
	h["speed"] = lerpf(float(h.speed), v, 0.6)  # suavizado: las reglas mueven la ficha a saltos chicos y desparejos entre cuadros
	var speed := float(h.speed)
	if speed < 0.08:
		speed = 0.0
		h["speed"] = 0.0
	var gaits: Array = cfg.call("gaits")
	var hyst := float(cfg.call("hysteresis_mps"))
	var cur := str(h.gait)
	var cur_i := -1
	var want_i := -1  # -1 = reposo
	if speed >= float(cfg.call("idle_below_mps")):
		want_i = gaits.size() - 1
		for i in range(gaits.size()):
			if str((gaits[i] as Dictionary).anim) == cur:
				cur_i = i
			if speed <= float((gaits[i] as Dictionary).up_to_mps) and want_i == gaits.size() - 1 and i < gaits.size() - 1:
				want_i = i
	else:
		for i in range(gaits.size()):
			if str((gaits[i] as Dictionary).anim) == cur:
				cur_i = i
	if want_i != cur_i:  # histéresis: cerca del corte entre los dos andares se queda el que ya corre
		var lo_i := mini(want_i, cur_i)
		var cut := float(cfg.call("idle_below_mps")) if lo_i < 0 else float((gaits[lo_i] as Dictionary).up_to_mps)
		if absf(speed - cut) < hyst * 0.5 and absi(want_i - cur_i) == 1:
			want_i = cur_i
	var want := "idle" if want_i < 0 else str((gaits[want_i] as Dictionary).anim)
	var natural := 1.0 if want_i < 0 else float((gaits[want_i] as Dictionary).natural_mps)
	var sc := 1.0 if want == "idle" else clampf(speed / maxf(natural, 0.01), float(cfg.call("speed_scale_min")), float(cfg.call("speed_scale_max")))
	h["scale"] = sc
	if want != cur:
		for p in players:
			if (p as AnimationPlayer).has_animation(want):
				(p as AnimationPlayer).play(str((p as Node).get_meta("idle_anim", "idle")) if want == "idle" else want, float(cfg.call("blend_s")))
		h["gait"] = want
	for p in players:
		(p as AnimationPlayer).speed_scale = sc


## Los pelajes de la tropa montada de `id`, uno por figura (para el informe).
func _troop_coats_of(id: String) -> Array:
	var out: Array = []
	for batch in (tokens.get(id, {}) as Dictionary).get("formation", []):
		if str(batch.get("coat", "")) != "":
			for k in range((batch.base as Array).size()):
				out.append(str(batch.coat))
	return out


## {andar, velocidad m/s, cadencia} de la jefa a caballo de `id` (vacío si no va a caballo): para las pruebas y el informe.
func horse_gait(id: String) -> Dictionary:
	var h: Dictionary = (tokens.get(id, {}) as Dictionary).get("horse", {})
	if h.is_empty():
		return {}
	return {"andar": str(h.gait), "velocidad_mps": snappedf(float(h.speed), 0.01), "cadencia": snappedf(float(h.scale), 0.01), "activo": h.player != null and (h.player as AnimationPlayer).active}


# ---------------------------------------------------------------------------------------------------------------------
# visual/r1 F5: figuras de a pie de los modelos propios (assets/models/persona_*.glb, manifiesto f5_personas_manifest.json)

## Una medida de `units.a_pie` (humahuaca_visual.json) o su valor por defecto.
func pcfg(key: String) -> Variant:
	var cfg: Variant = (gfx.data.get("units", {}) as Dictionary).get("a_pie", {}) if gfx != null else {}
	if cfg is Dictionary and (cfg as Dictionary).has(key):
		return (cfg as Dictionary)[key]
	return FOOT_DEFAULTS.get(key)


## El nombre base del modelo de a pie (sin «.glb») que usa el papel `role` de la tabla `table` (`por_figura` o `defensores`), o "" si la figura de a pie está apagada
## o falta su GLB completo o su LOD: quien lo pide vuelve a la figura del generador.
func _foot_model(role: String, table: String = "por_figura") -> String:
	if not bool(pcfg("enabled")):
		return ""
	var t: Variant = pcfg(table)
	var models: Variant = pcfg("modelos")
	var kind := str((t as Dictionary).get(role, "")) if t is Dictionary else ""
	var base := str((models as Dictionary).get(kind, "")) if models is Dictionary and kind != "" else ""
	if base == "":
		return ""
	if _scene_mesh(_foot_path(base, false)) == null or _scene_mesh(_foot_path(base, true)) == null:
		return ""
	return base


func _foot_path(base: String, lod: bool) -> String:
	return "res://%s/%s" % [str(pcfg("dir")), str(pcfg("lod" if lod else "full")) % base]


## La escena de un GLB por ruta completa (cargada una vez; null si no está).
func _scene_at(path: String) -> PackedScene:
	if not _glb.has(path):
		_glb[path] = load(path) as PackedScene if ResourceLoader.exists(path) else null
	return _glb[path]


## La malla (la primera) de un GLB por ruta completa, o null.
func _scene_mesh(path: String) -> Mesh:
	var key := "malla|" + path
	if not _glb.has(key):
		var scene := _scene_at(path)
		var mesh: Mesh = null
		if scene != null:
			var n := scene.instantiate()
			for mi in n.find_children("*", "MeshInstance3D", true, false):
				mesh = (mi as MeshInstance3D).mesh
				break
			n.free()
		_glb[key] = mesh
	return _glb[key]


## El rol de una superficie de los modelos F4/F5 por el nombre de su material («F5 | poncho | wool» → «poncho»); "" si el nombre no trae roles.
func _role_of(mname: String) -> String:
	var bits := mname.split("|")
	return bits[1].strip_edges() if bits.size() >= 3 else ""


## Los colores (lineales) por pieza de una figura de a pie de papel `kind` con la ropa `v` (la de las variantes de `units.variants`): el paisano lleva el poncho del
## abrigo, la camisa, el sombrero oscurecido y, si la variante trae acento, el pañuelo; el arriero, la chaqueta del abrigo y el poncho arrollado más oscuro; el realista y
## el mensajero, la ropa fija de `units.a_pie` (las vueltas borgoña son el código de color del enemigo). Lo que no figura queda como en el modelo.
func _foot_targets(kind: String, v: Dictionary) -> Dictionary:
	var out := {}
	if kind == "realista" or kind == "mensajero":
		var ropa: Variant = pcfg("ropa_realista" if kind == "realista" else "ropa_mensajero")
		if ropa is Dictionary:
			for role in ropa:
				out[str(role)] = gfx.pc(str(ropa[role])).srgb_to_linear()
		return out
	var coat: Color = gfx.pc(str(v.get("abrigo", "lana_parda")))
	if kind == "arriero":
		out["chaqueta"] = coat.srgb_to_linear()
		out["poncho"] = coat.darkened(0.3).srgb_to_linear()
	else:
		out["poncho"] = coat.srgb_to_linear()
		out["camisa"] = gfx.pc(str(v.get("camisa", "lino_crudo"))).srgb_to_linear()
	out["sombrero"] = gfx.pc(str(v.get("sombrero", "madera_oscura"))).darkened(0.2).srgb_to_linear()
	if str(v.get("acento", "")) != "":
		out["panuelo"] = gfx.pc(str(v.acento)).srgb_to_linear()
	return out


## Los colores de una superficie de rol con el tinte `t`: color nuevo = tinte × (color / color base del rol), canal por canal (la convención del manifiesto de personas;
## conserva la oclusión horneada y las guardas y franjas del poncho). El color base es la mediana de la superficie (la guarda y la franja son minoría).
func _retint(cols: PackedColorArray, t: Color) -> PackedColorArray:
	if cols.is_empty():
		return cols
	var rs := PackedFloat32Array()
	var gs := PackedFloat32Array()
	var bs := PackedFloat32Array()
	for c in cols:
		rs.append(c.r)
		gs.append(c.g)
		bs.append(c.b)
	rs.sort()
	gs.sort()
	bs.sort()
	var mid := cols.size() / 2
	var base := Color(maxf(rs[mid], 0.004), maxf(gs[mid], 0.004), maxf(bs[mid], 0.004))
	var out := PackedColorArray()
	out.resize(cols.size())
	for k in range(cols.size()):
		var c: Color = cols[k]
		out[k] = Color(t.r * clampf(c.r / base.r, 0.25, 1.6), t.g * clampf(c.g / base.g, 0.25, 1.6), t.b * clampf(c.b / base.b, 0.25, 1.6), c.a)
	return out


## Una figura de a pie liviana (el LOD quieto si `lod`) del modelo `base`, retinteada para el papel `kind` con la ropa `v`, en UNA superficie con el material `mat`
## (lo que dibuja el MultiMesh de la tropa o el defensor): sin el ancla de 2 mm del exportador.
func _persona_mesh(base: String, kind: String, v: Dictionary, lod: bool, mat: Material) -> ArrayMesh:
	var key := "%s|%s|%s|%s|%s|%s|%s|%d" % [base, kind, str(v.get("abrigo", "")), str(v.get("camisa", "")), str(v.get("sombrero", "")), str(v.get("acento", "")), str(lod), mat.get_instance_id()]
	if _persona_meshes.has(key):
		return _persona_meshes[key]
	var targets := _foot_targets(kind, v)
	var into := _new_arrays()
	var scene := _scene_at(_foot_path(base, lod))
	var n := scene.instantiate()
	for mi_node in n.find_children("*", "MeshInstance3D", true, false):
		var mi := mi_node as MeshInstance3D
		var xf := Transform3D.IDENTITY
		var cur: Node = mi
		while cur != null and cur != n:
			if cur is Node3D:
				xf = (cur as Node3D).transform * xf
			cur = cur.get_parent()
		var mesh := mi.mesh
		for si in range(mesh.get_surface_count()):
			var smat := mesh.surface_get_material(si)
			var mname := str(smat.resource_name) if smat != null else ""
			if mname.ends_with("ancla"):
				continue
			var a := mesh.surface_get_arrays(si)
			var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = a[Mesh.ARRAY_NORMAL] if a[Mesh.ARRAY_NORMAL] is PackedVector3Array else PackedVector3Array()
			var cols: PackedColorArray = a[Mesh.ARRAY_COLOR] if a[Mesh.ARRAY_COLOR] is PackedColorArray else PackedColorArray()
			var role := _role_of(mname)
			if targets.has(role):
				cols = _retint(cols, targets[role])
			var first: int = (into.v as PackedVector3Array).size()
			for k in range(verts.size()):
				into.v.append(xf * verts[k])
				into.n.append((xf.basis * normals[k]).normalized() if k < normals.size() else Vector3.UP)
				into.c.append(cols[k] if k < cols.size() else Color(0.2, 0.2, 0.2))
			var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] is PackedInt32Array else PackedInt32Array()
			if idx.is_empty():
				for k in range(verts.size()):
					into.i.append(first + k)
			else:
				for k in idx:
					into.i.append(first + k)
	n.free()
	var out := _arrays_mesh(into, mat)
	_persona_meshes[key] = out
	return out


## Una copia de la malla con esqueleto `mesh` con los colores de cada pieza retinteados a `targets` (mismos huesos y pesos: la sigue moviendo el esqueleto del GLB).
func _skinned_copy(mesh: Mesh, targets: Dictionary, key: String) -> Mesh:
	if targets.is_empty():
		return mesh
	var ck := "%d|%s" % [mesh.get_instance_id(), key]
	if _skinned_copies.has(ck):
		return _skinned_copies[ck]
	var out := ArrayMesh.new()
	for si in range(mesh.get_surface_count()):
		var a := mesh.surface_get_arrays(si)
		var smat := mesh.surface_get_material(si)
		var role := _role_of(str(smat.resource_name) if smat != null else "")
		if targets.has(role) and a[Mesh.ARRAY_COLOR] is PackedColorArray:
			a[Mesh.ARRAY_COLOR] = _retint(a[Mesh.ARRAY_COLOR], targets[role])
		out.add_surface_from_arrays(mesh.surface_get_primitive_type(si), a, [], {}, mesh.surface_get_format(si) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		out.surface_set_material(si, smat)
	_skinned_copies[ck] = out
	return out


## La figura jefa de a pie de una ficha: cada entrada de `list` = [modelo base, papel, ropa, transformación] es una figura con esqueleto (el GLB completo) retinteada,
## con el material de ficha de color lineal y en reposo (cada una con la animación corrida, así la pareja de reconocedores no respira a la par). Guarda en
## `_pending_foot` sus AnimationPlayer (build_tokens los pasa a la ficha y animate los mueve por la velocidad). Devuelve (alto nominal, radio del anillo) como _token_parts.
func _foot_token(root: Node3D, list: Array) -> Vector2:
	var mat: Material = gfx.token_mat("aliado_glb")
	var lo := Vector3(1.0e9, 1.0e9, 1.0e9)
	var hi := Vector3(-1.0e9, -1.0e9, -1.0e9)
	var triangles := 0
	var players: Array = []
	var names: Array = []
	for k in range(list.size()):
		var entry: Array = list[k]
		var v: Dictionary = entry[2]
		var targets := _foot_targets(str(entry[1]), v)
		var fig := _scene_at(_foot_path(str(entry[0]), false)).instantiate() as Node3D
		fig.name = "figura" if list.size() == 1 else "figura_%d" % k
		fig.transform = entry[3]
		root.add_child(fig)
		names.append(str(entry[0]))
		var tkey := "%s|%s|%s|%s|%s" % [str(entry[1]), str(v.get("abrigo", "")), str(v.get("camisa", "")), str(v.get("sombrero", "")), str(v.get("acento", ""))]
		for mi in fig.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			m.mesh = _skinned_copy(m.mesh, targets, tkey)
			m.material_override = mat
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var box: AABB = (entry[3] as Transform3D) * m.mesh.get_aabb()
			lo = Vector3(minf(lo.x, box.position.x), minf(lo.y, box.position.y), minf(lo.z, box.position.z))
			hi = Vector3(maxf(hi.x, box.end.x), maxf(hi.y, box.end.y), maxf(hi.z, box.end.z))
			for si in range(m.mesh.get_surface_count()):
				triangles += m.mesh.surface_get_array_index_len(si) / 3
		var found := fig.find_children("*", "AnimationPlayer", true, false)
		if not found.is_empty():
			var player := found[0] as AnimationPlayer
			player.set_meta("idle_anim", str(entry[4]) if entry.size() > 4 and player.has_animation(str(entry[4])) else "idle")  # visual/r1 F6 (B-049): quieto, agachado
			if player.has_animation("idle"):
				player.play(str(player.get_meta("idle_anim")))
				player.seek(1.3 * float(k + 1), true)
			players.append(player)
	_pending_foot = {"players": players, "gait": "idle", "speed": 0.0, "at": Vector3(INF, INF, INF), "t": -1.0, "scale": 1.0, "modelos": ", ".join(PackedStringArray(names))}
	part_counts[str(root.name)] = {"partes": list.size(), "triangulos": triangles}
	var radius := maxf(maxf(absf(lo.x), absf(hi.x)), maxf(absf(lo.z), absf(hi.z)))
	return Vector2(hi.y, radius + 0.35)


## {andar, velocidad m/s, cadencia} de la jefa de a pie de `id` (vacío si no tiene): para las pruebas y el informe.
func foot_gait(id: String) -> Dictionary:
	var h: Dictionary = (tokens.get(id, {}) as Dictionary).get("foot", {})
	if h.is_empty():
		return {}
	var players: Array = h.get("players", [])
	return {"andar": str(h.gait), "velocidad_mps": snappedf(float(h.speed), 0.01), "cadencia": snappedf(float(h.scale), 0.01), "figuras": players.size(),
		"activo": not players.is_empty() and (players[0] as AnimationPlayer).active}


## El radio del anillo de una agrupación (encierra su formación), en metros: lo usa el picking de la vista.
func ring_radius(id: String) -> float:
	return float((tokens.get(id, {}) as Dictionary).get("ring_r", _ring_radius(id)))


## Cuántas figuras de la formación se ven: todas con fuerza plena y cerca; con menos fuerza, en proporción (se van las de atrás); lejos (> far_m), `far_keep` de ellas.
func _apply_formation_count(id: String) -> void:
	var info: Dictionary = tokens[id]
	var f := clampf(float(info.strength_f), 0.0, 1.0) * (fcfg("far_keep") if bool(info.far) else 1.0)
	for batch in info.formation:
		var mm: MultiMesh = (batch.mmi as MultiMeshInstance3D).multimesh
		var total: int = (batch.base as Array).size()
		mm.visible_instance_count = -1 if f >= 0.999 else clampi(int(ceil(float(total) * f)), 0, total)


## Apoya cada figura de la formación en el suelo dibujado de su lugar (la ficha está a la altura del pie de la jefa: en una ladera las de los costados quedaban
## flotando o enterradas hasta ≈ 0,7 m). Se rehace solo si la ficha se corrió más de `units.marks.rebuild_m` o giró más de ≈ 2°, como los anillos.
func _ground_formation(id: String) -> void:
	var info: Dictionary = tokens[id]
	var root: Node3D = info.root
	var at := root.position
	var yaw := root.rotation.y
	if (info.get("ground_at", Vector3(INF, INF, INF)) as Vector3).distance_to(at) < mark("rebuild_m") and absf(yaw - float(info.get("ground_yaw", 0.0))) < 0.035:
		return
	info["ground_at"] = at
	info["ground_yaw"] = yaw
	var basis := Basis(Vector3.UP, yaw)
	var k_scale := maxf(root.scale.x, 0.01)
	for batch in info.formation:
		var mm: MultiMesh = (batch.mmi as MultiMeshInstance3D).multimesh
		var ground: Array = []
		for xf in (batch.base as Array):
			var t: Transform3D = xf
			var w: Vector3 = at + basis * (t.origin * k_scale)
			t.origin.y = (float(gfx.rendered_h(w.x, w.z)) - at.y) / k_scale
			ground.append(t)
		batch["ground"] = ground
		if not bool(info.get("stepping", false)):
			for k in range(ground.size()):
				mm.set_instance_transform(k, ground[k])


## Cuántas figuras de la formación se ven ahora (para las pruebas y el informe).
func formation_visible(id: String) -> int:
	var count := 0
	for batch in (tokens.get(id, {}) as Dictionary).get("formation", []):
		var mm: MultiMesh = (batch.mmi as MultiMeshInstance3D).multimesh
		count += mm.instance_count if mm.visible_instance_count < 0 else mm.visible_instance_count
	return count


## El paso de marcha: mientras la agrupación se movió hace poco y está cerca (≤ far_m), cada figura sube y baja un poco, desfasada. Al pararse vuelve a su lugar.
func animate(time_s: float) -> void:
	var now := Time.get_ticks_msec()
	var hz := fcfg("step_hz")
	for id in tokens:
		var info: Dictionary = tokens[id]
		if info.has("horse"):
			update_gait(str(id), float(Time.get_ticks_usec()) / 1.0e6)  # visual/r1 F4: el andar de la jefa por su velocidad real
		if info.has("foot"):
			update_foot_gait(str(id), float(Time.get_ticks_usec()) / 1.0e6)  # visual/r1 F5: ídem, la jefa de a pie
		var stepping := now - int(info.moved_ms) < 300 and not bool(info.far) and (info.root as Node3D).visible
		if not stepping and not bool(info.stepping):
			continue
		info["stepping"] = stepping
		var lift_max := 0.0
		for batch in info.formation:
			var mm: MultiMesh = (batch.mmi as MultiMeshInstance3D).multimesh
			var base: Array = batch.base
			var shown := base.size() if mm.visible_instance_count < 0 else mm.visible_instance_count
			var ground: Array = batch.ground
			for k in range(shown):
				var xf: Transform3D = ground[k] if k < ground.size() else base[k]
				if stepping:
					var lift := float(batch.bob) * absf(sin(time_s * hz * PI + float(k) * 1.7))
					xf.origin.y += lift
					lift_max = maxf(lift_max, lift)
				mm.set_instance_transform(k, xf)
		info["step_lift_m"] = lift_max  # lo último que subió alguna figura (las pruebas sin ventana no pueden leer el MultiMesh de vuelta)


# ---------------------------------------------------------------------------------------------------------------------
# visual/r1 F1: anillo de bando a escala real, pegado al relieve

## Una medida de `units.marks` (humahuaca_visual.json) o su valor por defecto.
func mark(key: String) -> float:
	var cfg: Variant = (gfx.data.get("units", {}) as Dictionary).get("marks", {}) if gfx != null else {}
	var v: Variant = (cfg as Dictionary).get(key, MARK_DEFAULTS.get(key, 0.0)) if cfg is Dictionary else MARK_DEFAULTS.get(key, 0.0)
	return float(v) if (typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT) else float(MARK_DEFAULTS.get(key, 0.0))


## El radio del anillo de una agrupación en metros. F3 lo hará depender de la huella de la formación (groups.<id>.men de humahuaca_rules.json).
func _ring_radius(id: String) -> float:
	var spec: Dictionary = (gfx.data.get("tokens", {}) as Dictionary).get(id, {})
	return float(spec.get("ring_radius_m", mark("ring_radius_m")))


## Material del anillo: plano, sin sombra, con prueba de profundidad (lo tapan los edificios) y sin descarte de caras (el relieve lo puede dar vuelta).
func _ring_mat(color_id: String, gain: float, alpha: float, priority: int) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%d" % [color_id, gain, alpha, priority]
	if not _ring_mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		var c: Color = gfx.pc(color_id, gain)
		m.albedo_color = Color(c.r, c.g, c.b, alpha)
		if alpha < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.render_priority = priority
		_ring_mats[key] = m
	return _ring_mats[key]


## Un anillo hijo de la ficha pero `top_level` (no gira con ella); guarda su radio, ancho y alzada para rearmarlo al moverse.
func _ground_ring_node(root: Node3D, node_name: String, radius: float, width: float, lift: float, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.top_level = true
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("ring", Vector3(radius, width, lift))
	root.add_child(mi)
	return mi


## La malla de un anillo plano de `radius` m y `width` m de ancho centrado en `center`, con cada vértice a `lift` m sobre la malla dibujada del suelo (relativa a center.y).
func _ground_ring_mesh(center: Vector3, radius: float, width: float, lift: float) -> ArrayMesh:
	var segs := maxi(int(mark("segments")), 12)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var idx := PackedInt32Array()
	for i in range(segs + 1):
		var a := TAU * float(i) / float(segs)
		var d := Vector2(cos(a), sin(a))
		for r in [maxf(radius - width * 0.5, 0.02), radius + width * 0.5]:
			var x := center.x + d.x * float(r)
			var z := center.z + d.y * float(r)
			verts.append(Vector3(d.x * float(r), gfx.rendered_h(x, z) + lift - center.y, d.y * float(r)))
			normals.append(Vector3.UP)
	for i in range(segs):
		var k := i * 2
		idx.append_array(PackedInt32Array([k, k + 2, k + 1, k + 1, k + 2, k + 3]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Ubica los anillos de una ficha en su pie y, si se corrió más de `rebuild_m` desde la última vez, los rearma con el relieve de su lugar nuevo.
func _place_rings(id: String) -> void:
	var info: Dictionary = tokens[id]
	var root: Node3D = info.root
	var at := root.position
	var rebuild := (info.ring_at as Vector3).distance_to(at) > mark("rebuild_m")
	for key in ["edge", "ring", "selection"]:
		var mi: MeshInstance3D = info[key]
		var spec: Vector3 = mi.get_meta("ring", Vector3(2.0, 0.3, 0.2))
		if rebuild:
			mi.mesh = _ground_ring_mesh(at, spec.x, spec.y, spec.z)
		# `top_level`: su posición ya es la del mundo. Entre dos rearmados se lo corre solo en el plano, a la altura con la que se armó la malla
		mi.position = at if rebuild else Vector3(at.x, (info.ring_at as Vector3).y, at.z)
	if rebuild:
		info["ring_at"] = at


# ---------------------------------------------------------------------------------------------------------------------
# Defensores y botín (visual/r1 F3: a escala real, como las fichas; las luces siguen creciendo hasta su mínimo de píxeles)

func clear_category(root: Node, category: String) -> void:
	for child in root.get_children():
		root.remove_child(child)
		child.free()
	var keep: Array = []
	for entry in scaled:
		if str(entry.cat) != category:
			keep.append(entry)
	scaled = keep


func register_scaled(node: Node3D, category: String, base: float, px: float, min_scale: float = 1.0) -> void:
	scaled.append({"node": node, "cat": category, "base": maxf(base, 0.1), "px": px, "min": min_scale})


func _enemy_mesh(kind: String) -> ArrayMesh:
	if not _enemy_meshes.has(kind) and _foot_model(kind, "defensores") != "":
		# visual/r1 F5: el infante realista de 1817 (o el arriero para el mensajero), versión liviana quieta, retinteado con `units.a_pie.ropa_realista` (o
		# `ropa_mensajero`) y con el material de ficha enemiga de color lineal (lleva su contorno como pasada extra: la malla sale marcada con «glb»)
		var mesh := _persona_mesh(_foot_model(kind, "defensores"), "mensajero" if kind == "mensajero" else "realista", {}, true, gfx.token_mat("enemigo_glb"))
		mesh.set_meta("glb", true)
		_enemy_meshes[kind] = mesh
	if not _enemy_meshes.has(kind):
		var arch := str(ENEMY_ARCHETYPE.get(kind, "realista_1817"))
		var v := {"camisa": "lana_natural", "abrigo": "lana_parda", "sombrero": "lana_parda", "acento": "borgona_hipotetica"}
		_enemy_meshes[kind] = gen.figure_single(arch, v, hull_w() * 1.8)  # contorno más grueso: a 28 px la figura tiene que recortarse del suelo
	return _enemy_meshes[kind]


func _loot_mesh(kind: String) -> ArrayMesh:
	if not _loot_meshes.has(kind):
		var mesh_kind := {"polvora": "barril", "fusiles": "cajon", "viveres": "saco", "plata": "bulto"}
		if kind == "canones":
			var mb = gen.builder()
			gen.add_cannon(mb, 1.6, 0.8)
			_loot_meshes[kind] = mb.build()
		else:
			_loot_meshes[kind] = gen.prop(str(mesh_kind.get(kind, "bulto")), 3)
	return _loot_meshes[kind]


## Defensores (`enemies`) y botín (`loot`) de render_state. `root_name` y `category` separan los dos grupos; devuelve cuántos dibujó.
func sync_things(root: Node3D, category: String, list: Array) -> int:
	clear_category(root, category)
	var count := 0
	for e in list:
		if not (e is Dictionary) or count >= MAX_THINGS:
			continue
		var kind := str(e.get("kind", ""))
		if category == "enemy" and kind == "torre":
			continue
		if category == "loot" and not (str(e.get("state", "")) in ["en_sitio", "abandonado"]):
			continue
		count += 1
		var x := float(e.get("x", 0.0))
		var z := float(e.get("z", 0.0))
		var holder := Node3D.new()
		holder.name = "%s_%s" % [category, str(e.get("id", count))]
		holder.position = Vector3(x, gfx.rendered_h(x, z), z)
		root.add_child(holder)
		if category == "enemy":
			var mi := MeshInstance3D.new()
			mi.mesh = _enemy_mesh(kind)
			if not mi.mesh.has_meta("glb"):  # visual/r1 F5: la figura del modelo ya trae su material (enemigo_glb, con el contorno)
				mi.set_surface_override_material(0, gfx.token_mat("enemigo"))
				if mi.mesh.get_surface_count() > 1:
					mi.set_surface_override_material(1, gfx.outline_mat())
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(mi)
			# regla de color: el enemigo es ROJO (anillo rojo con filete de tinta y disco oscuro debajo), más vivo si está alertado.
			# visual/r1 F3: a ESCALA REAL como las fichas propias (antes crecía hasta 28 px con la distancia): anillo fino de 1,1 m; de lejos lo encuentra la marca roja
			# chica que dibuja la interfaz (humahuaca_overlay.gd)
			gfx.inst(holder, gfx.cyl_mesh(1.0, 1.0, 0.04, 16), Vector3(0.0, 0.05, 0.0), gfx.flat_mat("negro_textil", 0.4), Vector3.ZERO, false).name = "base"
			var alert := float(e.get("alert", 0.0)) > 0.5
			gfx.flat_ring(holder, 1.1, 0.24, "rojo_reservado", 1.0).material_override = gfx.flat_mat("rojo_reservado", 1.0, false, 1.35 if alert else 1.1)
			gfx.flat_ring(holder, 1.26, 0.1, "negro_textil", 0.9).name = "borde"
			if bool(e.get("firing", false)):
				gfx.inst(holder, gfx.sphere_mesh(0.35), Vector3(0.0, 1.5, -0.6), gfx.flat_mat("oro_laton", 1.0, true, 1.4), Vector3.ZERO, false)
		else:
			holder.position += Vector3(float(count % 3) * 1.5, 0.0, float(count % 2) * 1.5)
			var li := MeshInstance3D.new()
			li.mesh = _loot_mesh(kind)
			li.material_override = gfx.props_mat
			li.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(li)  # visual/r1 F3: a escala real (antes crecía hasta 10 px); la interfaz le pone una marca chica
	return count


## La pose de cada ficha (posición y rumbo) tal como la dice `render_state().units`. Se la lee EN CADA CUADRO: las agrupaciones se mueven en cada paso de las reglas sin
## subir `version`, así que si la pose solo se leyera cuando la versión cambia las figuras se quedaban quietas hasta el próximo evento y después saltaban decenas de metros
## (hallazgo H-R1-9: 30,8 m a ×1, 92,5 m a ×2 y 123,4 m a ×4). Cuesta lo que cinco nodos. Devuelve verdadero si alguna ficha se movió.
func sync_poses(state: Dictionary) -> bool:
	var moved := false
	display_offsets = Declutter.spread(state.get("units", []), unit_nodes, ring_radius, (gfx.data.get("units", {}) as Dictionary).get("declutter", {}))  # visual/r1 F6 (B-049)
	for u in state.get("units", []):
		if not (u is Dictionary) or not unit_nodes.has(str(u.get("id", ""))):
			continue
		var node: Node3D = unit_nodes[str(u.id)]
		var off: Vector2 = display_offsets.get(str(u.id), Vector2.ZERO)
		var x := float(u.get("x", 0.0)) + off.x
		var z := float(u.get("z", 0.0)) + off.y
		var yaw := -deg_to_rad(float(u.get("yaw_deg", 0.0)))
		_sync_alert(str(u.id), float(u.get("spotted_s", 0.0)))
		if absf(node.position.x - x) > 0.0005 or absf(node.position.z - z) > 0.0005 or absf(node.rotation.y - yaw) > 0.0005:
			node.position = Vector3(x, gfx.rendered_h(x, z), z)  # el pie apoya en la malla que se dibuja (en `baja` la ventana tiene un vértice cada 8 m y se aparta hasta ≈ 0,25 m de `height_at`)
			node.rotation.y = yaw
			_place_rings(str(u.id))  # visual/r1 F1
			if tokens.has(str(u.id)):
				tokens[str(u.id)]["moved_ms"] = Time.get_ticks_msec()  # visual/r1 F3: el paso de la formación (animate)
				_ground_formation(str(u.id))  # visual/r1 F3: cada figura apoya en el relieve de su lugar
			moved = true
	return moved


## El aro de detección de una ficha: visible mientras `spotted_s` > 0 (los segundos que faltan para que el centinela dé la voz) y lleno en la proporción que queda de la
## cuenta (el máximo visto en este aviso es el total; las reglas usan 5 s). Ámbar y por encima de todo: es el telegrafiado del peligro (Shadow Tactics, pedido de diseño).
func _sync_alert(id: String, spotted_s: float) -> void:
	if not tokens.has(id):
		return
	var info: Dictionary = tokens[id]
	var alert: MeshInstance3D = info.alert
	if spotted_s <= 0.01:
		if alert.visible:
			alert.visible = false
		info["alert_max"] = 0.0
		return
	info["alert_max"] = maxf(float(info.alert_max), maxf(spotted_s, 0.5))
	alert.visible = true
	alert.position = (info.root as Node3D).position + Vector3(0.0, 0.35 * (info.root as Node3D).scale.x, 0.0)
	alert.scale = Vector3.ONE * (info.root as Node3D).scale.x
	(alert.material_override as ShaderMaterial).set_shader_parameter("fill", clampf(spotted_s / float(info.alert_max), 0.0, 1.0))


func _alert_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()  # uno por ficha: cada aro tiene su propia cuenta
	m.shader = load(ALERT_SHADER) as Shader
	m.set_shader_parameter("tint", gfx.pc("oro_laton", 1.05).lerp(gfx.pc("rojo_reservado", 1.05), 0.38))
	m.render_priority = 9
	return m


## Pose, visibilidad, rótulo y color del anillo de cada ficha (lo que cambia con la versión del estado).
func sync_units(state: Dictionary, labels_on: bool) -> void:
	sync_poses(state)
	for u in state.get("units", []):
		if not (u is Dictionary) or not unit_nodes.has(str(u.get("id", ""))):
			continue
		var id := str(u.id)
		var node: Node3D = unit_nodes[id]
		var gone := str(u.get("stage", "")) == "exited"
		node.visible = not gone
		(unit_labels[id] as Label3D).visible = not gone and labels_on
		var info: Dictionary = tokens[id]
		var ring_id := "rojo_reservado" if bool(u.get("detected", false)) else str(info.ring_color)
		(info.ring as MeshInstance3D).material_override = _ring_mat(ring_id, float(RING_GAIN.get(ring_id, 1.0)), 1.0, 2)  # visual/r1 F1: descubierta = rojo, como antes
		# visual/r1 F3: con menos fuerza se ven menos figuras; si render_state trae `men` (hoy no), también cuenta la proporción contra los hombres del armado
		var strength_f := clampf(float(u.get("strength_pct", 100.0)) / 100.0, 0.0, 1.0)
		var built := int((formation_report.get(id, {}) as Dictionary).get("hombres", 0))
		if u.has("men") and built > 0:
			strength_f = minf(strength_f, clampf(float(u.men) / float(built), 0.0, 1.0))
		if absf(strength_f - float(info.strength_f)) > 0.001:
			info["strength_f"] = strength_f
			_apply_formation_count(id)


# ---------------------------------------------------------------------------------------------------------------------
# Escala por cuadro

## Píxeles reales por píxel lógico (la ventana escala el área de 1 440 × 900): los tamaños en píxeles del JSON son los de la pantalla.
func update_scales(host: Node, cam: Camera3D) -> void:
	# visual/r1 F1: las fichas ya no crecen con la distancia: escala fija (`units.marks.figure_scale`, 1 = tamaño real). El rótulo va sobre la cabeza.
	var fig := maxf(mark("figure_scale"), 0.1)
	for id in tokens:
		var info: Dictionary = tokens[id]
		var root: Node3D = info.root
		root.scale = Vector3.ONE * fig
		(unit_labels[id] as Label3D).position = root.position + Vector3(0.0, float(info.base_h) * fig + 0.6, 0.0)
		if (info.ring_at as Vector3).x == INF:
			_place_rings(str(id))
		# visual/r1 F3: de lejos (> far_m de la cámara) se ve parte de la formación y no hay paso
		var far := cam != null and cam.is_inside_tree() and cam.global_position.distance_to(root.global_position if root.is_inside_tree() else root.position) > fcfg("far_m")
		if far != bool(info.far):
			info["far"] = far
			_apply_formation_count(str(id))
	var alive: Array = []
	for entry in scaled:
		if not is_instance_valid(entry.node):
			continue
		alive.append(entry)
		var node: Node3D = entry.node
		var pos: Vector3 = node.global_position if node.is_inside_tree() else node.position
		if str(entry.cat) == "light":
			var s := maxf(float(entry.min), float(entry.px) / gfx.screen_scale(host) * gfx.meters_per_px_at(cam, pos))
			node.scale = Vector3(s, s, s)
		else:
			node.scale = upright_scale(host, cam, pos, float(entry.px), float(entry.base), float(entry.min))
	scaled = alive


## Escala (x, y, z) para que algo parado de `base_h` m mida `px` píxeles reales de alto en pantalla. Lo vertical se achata por el seno del ángulo entre el rayo y la
## vertical (más cuanto más empinado se lo mira: las fichas de abajo del cuadro se ven más bajas que las de arriba) y por el coseno del descentrado; se lo compensa
## estirando solo el alto, hasta 4,6 veces, para que el ancho no se dispare. Esa cuenta es una estimación: se la corrige con una medición de verdad (se proyectan el pie
## y la cabeza con la cámara que se dibuja) para que el alto en pantalla sea el pedido aunque la cámara sea otra (hallazgo I-R1.0-3: escala medida con la cámara dibujada).
## Con la cámara muy empinada (más de ≈ 70°) de arriba no se ve la altura de una figura: estirarla más la vuelve un trazo largo hacia el nadir, así que el estirón tiene
## un tope que baja de 6,9 a 2,2 veces entre los 58° y los 76°, y el alto pedido baja a los dos tercios entre los 60° y los 80°: la ficha mide menos de lo pedido (queda legible por su
## anillo y por su silueta vista desde arriba) en vez de crecer sin límite.
func upright_scale(host: Node, cam: Camera3D, pos: Vector3, px: float, base_h: float, min_scale: float) -> Vector3:
	if cam == null:
		return Vector3.ONE * min_scale
	var looking_down := rad_to_deg(asin(clampf(cam.global_transform.basis.z.y, 0.0, 1.0)))  # inclinación de la mirada bajo el horizonte (la mirada es −Z: mirar abajo es +Z hacia arriba)
	px *= lerpf(1.0, 0.65, smoothstep(60.0, 80.0, looking_down))  # muy empinada: la ficha se ve desde arriba, así que se achica en vez de crecer sin límite
	var flat := clampf(px / gfx.screen_scale(host) * gfx.meters_per_px_at(cam, pos) / base_h, min_scale, 60.0)
	var ray := pos - cam.global_position
	var dist := maxf(ray.length(), 0.001)
	var tilt := clampf(sqrt(maxf(1.0 - pow(ray.y / dist, 2.0), 0.0)) * (ray.dot(-cam.global_transform.basis.z) / dist), 0.2, 1.0)
	var cap := lerpf(MAX_STRETCH * 1.5, 2.2, smoothstep(58.0, 76.0, looking_down))
	var tall := clampf(flat / tilt, flat, flat * minf(MAX_STRETCH, cap))
	if cam.is_inside_tree() and not cam.is_position_behind(pos):
		var foot := cam.unproject_position(pos)
		var head := cam.unproject_position(pos + Vector3(0.0, base_h * tall, 0.0))
		var got: float = absf(foot.y - head.y) * float(gfx.screen_scale(host))
		if got > 1.0:
			tall = clampf(tall * clampf(px * 1.03 / got, 0.5, 2.0), flat * 0.9, flat * cap)  # el 3 % de más cubre la no linealidad de la perspectiva: el pedido es un mínimo
	return Vector3(flat, tall, flat)


func update_selection(selected: Array, time_s: float) -> void:
	var pulse := 1.0 + 0.07 * sin(time_s * 5.0)
	for id in tokens:
		var sel: MeshInstance3D = tokens[id].selection
		sel.visible = selected.has(id)
		if sel.visible:
			sel.scale = Vector3(pulse, 1.0, pulse)  # visual/r1 F1: el anillo ya es plano y pegado al suelo (antes un toro aplastado)
