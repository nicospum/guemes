extends RefCounted
## Cámara propia del nivel «humahuaca» (CONTRATO 3.5 y ADDENDA A-11). Guarda el cuadro (objetivo, distancia, inclinación y rumbo) y lo aplica a
## main.camera. `yaw_deg` es el RUMBO DE LA MIRADA: grados horarios desde el norte (0 mira al norte, −z; 90 mira al este, +x), como en initial_frame,
## canonical_view y qa_set_camera. La cámara se ubica en
##   centro + (−sin(yaw)·cos(pitch), sin(pitch), cos(yaw)·cos(pitch)) · distancia
## (VP-07) y el controlador la aplica ANTES de llamar a view.update_state (VP-08). Piso a 3 m sobre height_at, recorte con camera_bounds(),
## zoom hacia el cursor entre min_distance_m y max_distance_m, arrastre del mapa, giro, inclinación y la apertura automática por los tres objetivos.
## No depende de ningún otro archivo del nivel: lo que necesita de las capas llega por parámetro (reglas y vista) o por Callable.
##
## Parámetros (desde el pedido del usuario del 2-11-2026, «la cámara está demasiado lejos»): data/humahuaca_camera.json. Su sección `camera` PISA las claves de la
## sección `camera` de humahuaca_ui.json en el mismo diccionario que recibe setup() (así lo que el controlador lee de ui_data.camera, como zoom_step o edge_speed,
## ve los mismos valores que esta clase). Su sección `initial_frame` decide el ENCUADRE INICIAL (fit_initial): el cuadro más cercano en el que los puntos «duros» del
## preset activo entran con su margen al borde y dentro de la banda libre entre la cabecera y el dock; los «blandos» (las cinco partidas) entran si cuesta poco. Su
## sección `follow`: al centrar la cámara en una ficha, la sigue mientras marcha. Cifras y criterio: docs/humahuaca/CAMARA.md.

const CAMERA_PATH := "res://data/humahuaca_camera.json"
const GROUPS := ["rodriguez", "portal", "arias", "reconocedores", "arreo"]
const OBJECTIVES := ["bateria", "cuartel", "posta"]
## El preset de respaldo si el JSON falta o no trae el pedido: los tres objetivos a 10 % y la zona de partida a 5 % del borde; las partidas, si cuesta poco.
const DEFAULT_PRESET := {
	"hard": [{"landmark": "bateria", "margin_pct": 10.0}, {"landmark": "cuartel", "margin_pct": 10.0}, {"landmark": "posta", "margin_pct": 10.0}, {"landmark": "zona_partida", "margin_pct": 5.0}],
	"soft": {"units": true, "margin_pct": 2.5, "max_distance_m": 440.0}}
const FIT_PRECISION_M := 0.5
const CENTER_PASSES := 5

var target := Vector2(450.0, 325.0)
var dist := 470.0
var pitch_deg := 52.0
var yaw_deg := 325.0
var cfg: Dictionary = {}
var data: Dictionary = {}  ## data/humahuaca_camera.json
var rules: Variant = null
var view: Variant = null
## Callable(camera: Camera3D, pos: Vector2) -> Variant (Vector2 del suelo, o null): lo pone el controlador (usa la vista o un plano de respaldo).
var ground_from_screen: Callable = Callable()
## Lo que decidió el último fit_initial: {preset, dist, target, hard_ok, soft_in, soft_out, size, band}. Lo leen las pruebas y el informe de QA.
var last_fit: Dictionary = {}
## La agrupación que la cámara sigue («» si ninguna): center_on con la posición de una ficha la elige; mover la cámara a mano la suelta.
var follow_id := ""
var _base_pitch := -1.0  ## la inclinación «de juego» a la que vuelve la cámara al alejarse (zoom_tilt)
var _glide: Dictionary = {}  ## el acercamiento en curso a una partida recién elegida ({} si ninguno)
var _last_approach_s := -100.0
## El último acercamiento: {id, como («eleccion» o «ir»), desde_m, hasta_m, inclinacion, t, previa, previa_s}. Lo leen las pruebas y la herramienta de capturas.
var last_approach: Dictionary = {}

var opening_active := false
var _op_frames: Array = []  # [{target: Vector2, dist, pitch_deg, yaw_deg, at: float}]
var _op_t := 0.0
var _op_total := 13.5
var _drag_grab: Variant = null


func setup(config: Dictionary, rules_ref: Variant, view_ref: Variant) -> void:
	cfg = config
	rules = rules_ref
	view = view_ref
	data = _load_data()
	var over: Variant = data.get("camera", {})
	if over is Dictionary:
		cfg.merge(over, true)  # el mismo diccionario que tiene el controlador: zoom_step, edge_speed, min_distance_m… quedan en un solo lugar
	follow_id = ""
	forget_approach()


static func _load_data() -> Dictionary:
	if not FileAccess.file_exists(CAMERA_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CAMERA_PATH))
	if not (parsed is Dictionary) or int((parsed as Dictionary).get("contract", 0)) != 1:
		push_error("Humahuaca: " + CAMERA_PATH + " no se pudo leer como un objeto JSON con \"contract\": 1")
		return {}
	return parsed


func num(key: String, fallback: float) -> float:
	var v: Variant = cfg.get(key, fallback)
	return float(v) if (typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT) else fallback


func min_dist() -> float:
	return num("min_distance_m", 40.0)


func max_dist() -> float:
	return num("max_distance_m", 900.0)


func ground_h(x: float, z: float) -> float:
	if rules != null and rules.has_method("terrain_height_at"):
		return float(rules.call("terrain_height_at", x, z))
	return 17.0  # el plano del terreno mínimo


func bounds() -> Rect2:
	if view != null and view.has_method("camera_bounds"):
		var r: Variant = view.call("camera_bounds")
		if r is Rect2:
			return r
	var m := num("bounds_margin_m", 120.0)
	return Rect2(-m, -m, 900.0 + 2.0 * m, 650.0 + 2.0 * m)


func clamp_target(p: Vector2) -> Vector2:
	var r := bounds()
	return Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))


## Fija el cuadro entero (con los límites de la cámara) y suelta la ficha que se seguía. El rumbo se guarda en [0, 360).
func set_frame(t: Vector2, d: float, pitch: float, yaw: float) -> void:
	follow_id = ""
	_glide = {}
	target = clamp_target(t)
	dist = clampf(d, min_dist(), max_dist())
	pitch_deg = clampf(pitch, num("min_pitch_deg", 10.0), num("max_pitch_deg", 80.0))
	yaw_deg = fposmod(yaw, 360.0)


func frame() -> Dictionary:
	return {"target": target, "dist": dist, "pitch_deg": pitch_deg, "yaw_deg": yaw_deg}


## Dónde queda la cámara y a qué punto mira. `floor_m` (piso) sube la cámara si el suelo la taparía.
func pose() -> Dictionary:
	var ground := ground_h(target.x, target.y)
	var center := Vector3(target.x, ground, target.y)
	var yaw := deg_to_rad(yaw_deg)
	var pitch := deg_to_rad(pitch_deg)
	var offset := Vector3(-sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
	var pos := center + offset
	var floor_y := ground_h(pos.x, pos.z) + num("ground_clearance_m", 3.0)
	if pos.y < floor_y:
		pos.y = floor_y
	return {"position": pos, "look_at": center}


## Ubica la cámara. Si se sigue a una ficha, el objetivo es su posición de este cuadro.
func apply(cam: Camera3D) -> void:
	if cam == null or not cam.is_inside_tree():
		return
	if not _glide.is_empty():
		_glide_step()
	if follow_id != "":
		var p: Variant = _unit_pos(follow_id)
		if p is Vector2:
			target = clamp_target(p)
		else:
			follow_id = ""
	var p := pose()
	cam.global_position = p.position
	cam.look_at(p.look_at, Vector3.UP)


## Acercamiento a la acción (ronda 2 de P2, pedido del usuario: «ver todo más cerca»; corregido por QA ronda 2, Q-201). El encuadre inicial amplio sirve para orientarse.
## La cámara NO mira la selección: antes se disparaba con cualquier cambio de view.selected_ids, y como la guía («Siguiente paso», los botones de orden y los avisos)
## elige al actor antes de dar la orden, cada orden de la guía la hacía deslizarse (32 deslizamientos en 5,8 min, ping-pong Rodríguez ↔ arreo en la extracción).
## Ahora solo la mueve el controlador, y solo ante una elección EXPLÍCITA del jugador:
##   · request_approach(cam, id): primera elección de una partida (tecla 1 a 5, clic en su ficha o en su tarjeta). Se desliza SOLO si la ficha no está a la vista con
##     margen (`visible_margin_pct` del lado y dentro de la banda libre entre la cabecera y el dock), como mucho una vez cada `cooldown_s` y sin volver a la partida del
##     acercamiento anterior antes de `no_return_s`. Si la cámara está abierta (más de `wide_dist_m`) llega a `dist_m`; si ya está cerca, recentra sin alejarse.
##   · focus_on(p, id): segunda pulsación de la misma tecla o tarjeta (o doble clic en la ficha): el jugador pide ir ahí. Se desliza hasta el punto (la ficha o su frente),
##     se acerca a `dist_m` si está más lejos (nunca aleja) y, si es una ficha, la sigue después.
## Nunca durante la apertura, mientras se arrastra el mapa o con el botón derecho apretado (trazando una ruta). Cualquier movimiento manual (teclas, borde, arrastre,
## rueda, giro, minimapa, Inicio, centrar) corta el deslizamiento. La cámara no se aleja sola en ningún caso.
func _approach_cfg() -> Dictionary:
	return data.get("approach", {}) if data.get("approach", null) is Dictionary else {}


## ¿La ficha (o el punto) está a la vista con margen? `margin_pct` en % del lado; además tiene que caer en la banda libre del HUD (la del último encuadre).
func on_screen(cam3: Camera3D, p: Vector2, margin_pct: float) -> bool:
	if cam3 == null or not cam3.is_inside_tree():
		return false
	var w := Vector3(p.x, ground_h(p.x, p.y), p.y)
	if cam3.is_position_behind(w):
		return false
	var size := cam3.get_viewport().get_visible_rect().size
	var s := cam3.unproject_position(w)
	var band := {"top": 0.0, "bottom": size.y}
	var b: Variant = last_fit.get("hud_band", null)  # lo que de verdad tapan la cabecera y el dock (sin el aire extra que deja el encuadre inicial)
	if b is Array and (b as Array).size() == 2:
		band = {"top": float(b[0]), "bottom": float(b[1])}
	return _inside(s, margin_pct / 100.0, band, size)


func _now_s() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


func _blocked() -> bool:
	return opening_active or dragging() or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)


## Primera elección explícita de una partida. Devuelve {moved: bool, motivo: String}; el motivo lo leen las pruebas.
func request_approach(cam3: Camera3D, id: String) -> Dictionary:
	var a := _approach_cfg()
	if not bool(a.get("enabled", false)):
		return {"moved": false, "motivo": "apagado"}
	if cam3 == null or not cam3.is_inside_tree() or _blocked():
		return {"moved": false, "motivo": "bloqueado"}
	var p: Variant = _unit_pos(id)
	if not (p is Vector2):
		return {"moved": false, "motivo": "sin_ficha"}
	if on_screen(cam3, p, float(a.get("visible_margin_pct", 4.0))):
		return {"moved": false, "motivo": "a_la_vista"}
	var now := _now_s()
	if now - _last_approach_s < float(a.get("cooldown_s", 7.0)):
		return {"moved": false, "motivo": "pausa"}
	if id == str(last_approach.get("previa", "")) and now - float(last_approach.get("previa_s", -100.0)) < float(a.get("no_return_s", 12.0)):
		return {"moved": false, "motivo": "vuelta"}
	var wide := dist > float(a.get("wide_dist_m", 300.0))
	var to_d := float(a.get("dist_m", 240.0)) if wide else dist  # si ya está cerca no se aleja: solo se recentra
	_start_glide(id, p, to_d, "")
	var prev_id := str(last_approach.get("id", ""))
	var prev_s := float(last_approach.get("t", -100.0))
	last_approach = {"id": id, "como": "eleccion", "desde_m": snappedf(dist, 0.1), "hasta_m": snappedf(to_d, 0.1), "inclinacion": snappedf(float(_glide.to_p), 0.1),
		"t": now, "previa": prev_id, "previa_s": prev_s}
	_last_approach_s = now
	return {"moved": true, "motivo": ""}


## Segunda pulsación: ir al punto (la ficha `id` o su frente si `id` es «») acercándose a dist_m si la cámara está más lejos, y seguir a la ficha después.
func focus_on(p: Vector2, id: String = "") -> void:
	var a := _approach_cfg()
	if _blocked() or not bool(a.get("enabled", false)):
		center_on(p)
		return
	var to_d := minf(dist, float(a.get("dist_m", 240.0)))
	follow_id = ""
	_start_glide(id, p, to_d, id if follow_enabled() else "")
	last_approach = {"id": id, "como": "ir", "desde_m": snappedf(dist, 0.1), "hasta_m": snappedf(to_d, 0.1), "inclinacion": snappedf(float(_glide.to_p), 0.1),
		"t": _now_s(), "previa": str(last_approach.get("id", "")), "previa_s": float(last_approach.get("t", -100.0))}


func _start_glide(id: String, p: Vector2, to_d: float, then_follow: String) -> void:
	var a := _approach_cfg()
	if _base_pitch <= 0.0:
		_base_pitch = pitch_deg if dist >= _tilt_far() else 42.0
	var to_p := tilt_pitch(to_d) if to_d < dist - 0.5 or dist <= _tilt_far() else pitch_deg
	_glide = {"id": id, "at": p, "t0": _now_s(), "dur": maxf(float(a.get("duration_s", 0.9)), 0.05), "from_t": target, "from_d": dist, "from_p": pitch_deg,
		"to_d": to_d, "to_p": to_p, "follow": then_follow}
	follow_id = ""


## Un paso del deslizamiento (con el reloj real, suave al empezar y al terminar). El destino sigue a la ficha si marcha mientras tanto.
func _glide_step() -> void:
	var k := clampf((float(Time.get_ticks_msec()) / 1000.0 - float(_glide.t0)) / float(_glide.dur), 0.0, 1.0)
	var e := k * k * (3.0 - 2.0 * k)
	var to_t: Vector2 = _glide.get("at", _glide.from_t)
	var p: Variant = _unit_pos(str(_glide.id)) if str(_glide.id) != "" else null
	if p is Vector2:
		to_t = p
	target = clamp_target((_glide.from_t as Vector2).lerp(to_t, e))
	dist = clampf(lerpf(float(_glide.from_d), float(_glide.to_d), e), min_dist(), max_dist())
	pitch_deg = lerpf(float(_glide.from_p), float(_glide.to_p), e)
	if k >= 1.0:
		var then_follow := str(_glide.get("follow", ""))
		_glide = {}
		if then_follow != "" and _unit_pos(then_follow) is Vector2:
			follow_id = then_follow


## Olvida la pausa y el último acercamiento (un intento nuevo o un reintento).
func forget_approach() -> void:
	_glide = {}
	_last_approach_s = -100.0
	last_approach = {}


func approaching() -> bool:
	return not _glide.is_empty()


func cancel_approach() -> void:
	_glide = {}


func _tilt_cfg() -> Dictionary:
	return data.get("zoom_tilt", {}) if data.get("zoom_tilt", null) is Dictionary else {}


func _tilt_far() -> float:
	return float(_tilt_cfg().get("far_m", 220.0))


## La inclinación de zoom_tilt para una distancia: de near_pitch_deg a near_m hasta la inclinación de juego (_base_pitch) a far_m, con curva cuadrática (casi
## acostada de cerca y que se endereza rápido al alejarse).
func tilt_pitch(d: float) -> float:
	var t := _tilt_cfg()
	var base := _base_pitch if _base_pitch > 0.0 else pitch_deg
	var k := clampf((d - float(t.get("near_m", 50.0))) / maxf(_tilt_far() - float(t.get("near_m", 50.0)), 1.0), 0.0, 1.0)
	return clampf(lerpf(float(t.get("near_pitch_deg", 24.0)), base, k * k), num("min_pitch_deg", 10.0), num("max_pitch_deg", 80.0))


## Rumbo horizontal de la mirada (para las pruebas): el vector (x, z) unitario hacia donde mira.
func gaze() -> Vector2:
	var yaw := deg_to_rad(yaw_deg)
	return Vector2(sin(yaw), -cos(yaw))


# ---------------------------------------------------------------------------------------------------------------------
# Movimiento

## `move`: x a la derecha y y hacia adelante (−1 a 1), relativos al rumbo de la cámara. La velocidad crece con la distancia. Suelta la ficha seguida.
func pan(move: Vector2, delta: float, fast: bool = false, factor: float = 1.0) -> void:
	if move == Vector2.ZERO:
		return
	follow_id = ""
	_glide = {}
	var yaw := deg_to_rad(yaw_deg)
	var forward := Vector2(sin(yaw), -cos(yaw))
	var right := Vector2(cos(yaw), sin(yaw))
	var speed := dist * num("pan_speed", 0.9) * factor * (num("pan_fast_mult", 3.0) if fast else 1.0)
	target = clamp_target(target + (right * move.x + forward * move.y) * speed * delta)


func rotate_view(yaw_dir: float, pitch_dir: float, delta: float) -> void:
	if yaw_dir != 0.0 or pitch_dir != 0.0:
		_glide = {}
	if yaw_dir != 0.0:
		yaw_deg = fposmod(yaw_deg + yaw_dir * num("yaw_deg_s", 70.0) * delta, 360.0)
	if pitch_dir != 0.0:
		pitch_deg = clampf(pitch_deg + pitch_dir * num("pitch_deg_s", 40.0) * delta, num("min_pitch_deg", 10.0), num("max_pitch_deg", 80.0))
		_base_pitch = -1.0  # el jugador inclinó a mano: la rueda deja de acostar la cámara hasta que vuelva a estar lejos


func _ground(cam: Camera3D, pos: Vector2) -> Variant:
	if ground_from_screen.is_valid():
		return ground_from_screen.call(cam, pos)
	return null


## Rueda del mouse: acerca (factor < 1) o aleja (factor > 1) manteniendo bajo el cursor el mismo punto del suelo. Si se sigue a una ficha, acerca o aleja sobre ella.
func zoom_at(cam: Camera3D, mouse: Vector2, factor: float) -> void:
	_glide = {}
	var before: Variant = _ground(cam, mouse) if follow_id == "" else null
	var tilt := _tilt_cfg()
	var far_m := _tilt_far()
	if dist >= far_m:
		_base_pitch = pitch_deg  # la inclinación que eligió el jugador (o la inicial) mientras está lejos
	dist = clampf(dist * factor, min_dist(), max_dist())
	if bool(tilt.get("enabled", false)) and _base_pitch > 0.0 and (dist < far_m or pitch_deg != _base_pitch):
		# P2: al acercarse, la cámara se va acostando hacia el horizonte (los cerros de la quebrada y el cielo); al alejarse vuelve a la inclinación de juego
		pitch_deg = tilt_pitch(dist)
	apply(cam)
	if follow_id != "":
		return
	# el punto del suelo bajo el cursor se queda: con relieve y la cámara baja una sola corrección dejaba hasta 8 m de error, así que se corrige hasta tres veces
	for _pass in range(3):
		var after: Variant = _ground(cam, mouse)
		if not (before is Vector2 and after is Vector2) or (before as Vector2).distance_to(after as Vector2) < 0.05:
			break
		target = clamp_target(target + ((before as Vector2) - (after as Vector2)))
		apply(cam)


func drag_begin(cam: Camera3D, mouse: Vector2) -> void:
	follow_id = ""
	_glide = {}
	_drag_grab = _ground(cam, mouse)


func drag_move(cam: Camera3D, mouse: Vector2) -> void:
	if not (_drag_grab is Vector2):
		return
	var now: Variant = _ground(cam, mouse)
	if now is Vector2:
		target = clamp_target(target + ((_drag_grab as Vector2) - (now as Vector2)))
		apply(cam)


func drag_end() -> void:
	_drag_grab = null


func dragging() -> bool:
	return _drag_grab is Vector2


## Centra la cámara en un punto del mundo. Si el punto es la posición de una agrupación (el controlador centra en la ficha con las teclas 4 y 5) y `follow.enabled`,
## la cámara la sigue desde ahí; cualquier otro punto (un frente, un clic en el minimapa) la suelta.
func center_on(p: Vector2) -> void:
	follow_id = ""
	_glide = {}
	target = clamp_target(p)
	if not follow_enabled():
		return
	for id in GROUPS:
		var u: Variant = _unit_pos(str(id))
		if u is Vector2 and (u as Vector2).distance_to(p) <= 0.05:
			follow_id = str(id)
			return


## Sigue a una agrupación por su id (la suelta cualquier movimiento manual de la cámara).
func follow_unit(id: String) -> void:
	var p: Variant = _unit_pos(id)
	if p is Vector2 and follow_enabled():
		target = clamp_target(p)
		follow_id = id
	else:
		follow_id = ""


func stop_follow() -> void:
	follow_id = ""


func follow_enabled() -> bool:
	var f: Variant = data.get("follow", {})
	return bool((f as Dictionary).get("enabled", true)) if f is Dictionary else true


## La posición (x, z) de una agrupación según las reglas, o null si no está o ya salió del mapa.
func _unit_pos(id: String) -> Variant:
	if rules == null or not rules.has_method("get_unit"):
		return null
	var u: Variant = rules.call("get_unit", id)
	if not (u is Dictionary) or (u as Dictionary).is_empty() or str((u as Dictionary).get("stage", "")) == "exited":
		return null
	return Vector2(float((u as Dictionary).get("x", 0.0)), float((u as Dictionary).get("z", 0.0)))


# ---------------------------------------------------------------------------------------------------------------------
# Encuadre inicial (pedido del usuario del 2-11-2026: la cámara más cerca sin perder los tres objetivos ni la zona de partida)

func preset_names() -> Array:
	var presets: Variant = (data.get("initial_frame", {}) as Dictionary).get("presets", {}) if data.get("initial_frame", null) is Dictionary else {}
	return (presets as Dictionary).keys() if presets is Dictionary else []


func active_preset() -> String:
	var frame_cfg: Variant = data.get("initial_frame", {})
	return str((frame_cfg as Dictionary).get("preset", "")) if frame_cfg is Dictionary else ""


func preset(name_: String) -> Dictionary:
	var frame_cfg: Variant = data.get("initial_frame", {})
	if frame_cfg is Dictionary:
		var presets: Variant = (frame_cfg as Dictionary).get("presets", {})
		if presets is Dictionary and (presets as Dictionary).has(name_) and (presets as Dictionary)[name_] is Dictionary:
			return (presets as Dictionary)[name_]
	return DEFAULT_PRESET


## El encuadre inicial con el preset activo. `start`: lo que sugiere la vista ({target: Vector2, dist, pitch_deg, yaw_deg, …}); `hud`: {top_px, bottom_px, ui_scale}, los
## píxeles LÓGICOS que tapan la cabecera y el dock y la escala de la interfaz (los márgenes above_head_px y below_px del JSON van en unidades de la interfaz).
## Devuelve el cuadro ({target, dist, pitch_deg, yaw_deg} más lo que traía `start`) y deja la cámara real ubicada en él.
func fit_initial(cam3: Camera3D, start: Dictionary, hud: Dictionary) -> Dictionary:
	return fit_with(cam3, start, hud, active_preset())


## El cuadro MÁS CERCANO (entre min_distance_m y max_distance_m) en el que todos los puntos «duros» del preset entran con su margen al borde (en % del lado) y dentro de la banda
## libre entre la cabecera y el dock, con el conjunto centrado por holguras (la misma holgura sobrante a cada lado, contado el margen de cada punto: así un margen distinto por
## punto se aprovecha); después, si todos los «blandos» entran sin pasar de soft.max_distance_m, se abre hasta ahí y se centra con ellos; si no, el conjunto se corre por el
## suelo (dentro de lo que permiten los duros) para que entren los blandos que se pueda, y una última pasada evita que un blando quede a medio tapar por la cabecera o el dock
## (se lo mete en la banda o se lo saca del cuadro, si la holgura de los duros lo permite). Bisección por la distancia; cada medida se hace con la cámara real
## (unproject_position: no hace falta dibujar).
func fit_with(cam3: Camera3D, start: Dictionary, hud: Dictionary, preset_name: String) -> Dictionary:
	var out := start.duplicate()
	if cam3 == null or not cam3.is_inside_tree() or cam3.get_viewport() == null:
		return out
	var spec := preset(preset_name)
	var hard := _resolve(spec.get("hard", []))
	var soft_spec: Variant = spec.get("soft", {})
	var soft := _resolve([soft_spec]) if soft_spec is Dictionary and not (soft_spec as Dictionary).is_empty() else []
	var pitch := float(spec.get("pitch_deg", start.get("pitch_deg", 52.0)))
	var yaw := float(spec.get("yaw_deg", start.get("yaw_deg", 325.0)))
	var size: Vector2 = cam3.get_viewport().get_visible_rect().size
	var frame_cfg: Variant = data.get("initial_frame", {})
	var ui_scale := maxf(float(hud.get("ui_scale", 1.0)), 0.01)
	var above := float((frame_cfg as Dictionary).get("above_head_px", 78.0)) if frame_cfg is Dictionary else 78.0
	var below := float((frame_cfg as Dictionary).get("below_px", 46.0)) if frame_cfg is Dictionary else 46.0
	var band := {"top": float(hud.get("top_px", 0.0)) + above * ui_scale, "bottom": size.y - float(hud.get("bottom_px", 0.0)) - below * ui_scale}
	if hard.is_empty() or float(band.bottom) - float(band.top) < 40.0:
		last_fit = {"preset": preset_name, "hard_ok": false, "motivo": "sin puntos duros o sin banda libre"}
		return out
	var t0: Vector2 = start.get("target", Vector2(350.0, 470.0))
	# 1) los duros: la distancia mínima en la que entran, por bisección
	var lo := min_dist()
	var hi := max_dist()
	var hard_ok := _fits_at(cam3, hi, pitch, yaw, hard, hard, band, size, t0)
	if hard_ok:
		while hi - lo > FIT_PRECISION_M:
			var mid := (lo + hi) * 0.5
			if _fits_at(cam3, mid, pitch, yaw, hard, hard, band, size, t0):
				hi = mid
			else:
				lo = mid
	# visual/r1 F2: un preset puede poner un TOPE a la distancia (`max_distance_m`): si los duros no entran más cerca, la cámara se queda en el tope centrada sobre ellos
	# (los que no entran quedan fuera; `capped` lo dice). Así el primer cuadro queda a 150–180 m aunque las cinco partidas pidan más.
	# Y un PISO (`min_distance_m`): si los duros entran más cerca, la cámara no baja de ahí (el primer cuadro muestra algo de contexto alrededor).
	var capped := false
	var cap_m := float(spec.get("max_distance_m", 0.0))
	if cap_m > 0.0 and (not hard_ok or hi > cap_m):
		hi = clampf(cap_m, min_dist(), max_dist())
		capped = true
	var floor_m := float(spec.get("min_distance_m", 0.0))
	if hard_ok and floor_m > hi:
		hi = clampf(floor_m, min_dist(), max_dist())
	var found := _place(cam3, hi, pitch, yaw, hard, hard, band, size, t0)
	if capped:
		hard_ok = bool(found.ok)
	var d_hard := float(found.dist)
	var result := found
	# 2) los blandos: todos, si cuesta poco…
	var soft_in: Array = []
	var soft_out: Array = []
	var shifted := 0.0
	if not soft.is_empty() and hard_ok:
		var cap := minf(max_dist(), float((soft_spec as Dictionary).get("max_distance_m", max_dist())))
		var all_pts := hard + soft
		if cap > d_hard and _fits_at(cam3, cap, pitch, yaw, all_pts, all_pts, band, size, found.target):
			var lo2 := d_hard
			var hi2 := cap
			while hi2 - lo2 > FIT_PRECISION_M:
				var mid2 := (lo2 + hi2) * 0.5
				if _fits_at(cam3, mid2, pitch, yaw, all_pts, all_pts, band, size, found.target):
					hi2 = mid2
				else:
					lo2 = mid2
			result = _place(cam3, hi2, pitch, yaw, all_pts, all_pts, band, size, found.target)
		else:
			# …o los que se pueda: se centra sobre los duros más los blandos que ya entran de costado, mientras los duros sigan entrando; si no entran todos esos, se va
			# soltando el más lejano del centro de la banda
			var want_y := (float(band.top) + float(band.bottom)) * 0.5
			var candidates: Array = []
			for p in soft:
				var s: Variant = _project(cam3, p.pos)
				if s is Vector2 and _inside_x(s as Vector2, float(p.margin), size):
					candidates.append({"id": p.id, "pos": p.pos, "margin": p.margin, "off": absf((s as Vector2).y - want_y)})
			candidates.sort_custom(func(a, b): return float(a.off) < float(b.off))
			while not candidates.is_empty():
				var trial := _place(cam3, d_hard, pitch, yaw, hard + candidates, hard, band, size, found.target)
				if bool(trial.ok) and _all_inside(cam3, candidates, band, size):
					result = trial
					break
				candidates.pop_back()
			_place(cam3, float(result.dist), pitch, yaw, result.centered_on, hard, band, size, result.target)
			shifted = _avoid_half_hidden(cam3, float(result.dist), pitch, yaw, result, hard, soft, band, size)
			if shifted != 0.0:
				result = _place(cam3, float(result.dist), pitch, yaw, result.centered_on, hard, band, size, result.target, Vector2(0.0, shifted))
		for p in soft:
			var s: Variant = _project(cam3, p.pos)
			if s is Vector2 and _inside(s as Vector2, float(p.margin), band, size):
				soft_in.append(str(p.id))
			else:
				soft_out.append(str(p.id))
	out["target"] = result.target
	out["dist"] = float(result.dist)
	out["pitch_deg"] = pitch
	out["yaw_deg"] = yaw
	last_fit = {"preset": preset_name, "capped": capped, "dist": snappedf(float(result.dist), 0.1), "target": [snappedf((result.target as Vector2).x, 0.1), snappedf((result.target as Vector2).y, 0.1)], "hard_ok": hard_ok,
		"soft_in": soft_in, "soft_out": soft_out, "a_medio_tapar": _half_hidden(cam3, soft, band, size), "corrimiento_px": snappedf(shifted, 0.1), "size": [size.x, size.y],
		"band": [snappedf(float(band.top), 0.1), snappedf(float(band.bottom), 0.1)], "duros": hard.size(), "blandos": soft.size(),
		"hud_band": [snappedf(float(hud.get("top_px", 0.0)), 0.1), snappedf(size.y - float(hud.get("bottom_px", 0.0)), 0.1)]}
	set_frame(result.target, float(result.dist), pitch, yaw)
	apply(cam3)
	return out


## Los puntos de un preset como [{id, pos: Vector2, margin}] (margen como fracción). `landmark`/`landmarks`: hitos por las reglas (terreno); `unit`/`units`: agrupaciones;
## `point`: {x, z} suelto (por ejemplo, una esquina de la zona de partida).
func _resolve(entries: Array) -> Array:
	var out: Array = []
	for e in entries:
		if not (e is Dictionary):
			continue
		var d := e as Dictionary
		var m := float(d.get("margin_pct", 5.0)) * 0.01
		if d.has("landmark"):
			var p: Variant = _landmark_pos(str(d.landmark))
			if p is Vector2:
				out.append({"id": str(d.landmark), "pos": p, "margin": m})
		for lid in d.get("landmarks", []):
			var lp: Variant = _landmark_pos(str(lid))
			if lp is Vector2:
				out.append({"id": str(lid), "pos": lp, "margin": m})
		if d.get("point", null) is Dictionary:
			var q: Dictionary = d.point
			out.append({"id": str(d.get("id", "punto")), "pos": Vector2(float(q.get("x", 0.0)), float(q.get("z", 0.0))), "margin": m})
		if d.has("unit"):
			var u: Variant = _unit_pos(str(d.unit))
			if u is Vector2:
				out.append({"id": str(d.unit), "pos": u, "margin": m})
		if bool(d.get("units", false)):
			for gid in GROUPS:
				var up: Variant = _unit_pos(str(gid))
				if up is Vector2:
					out.append({"id": str(gid), "pos": up, "margin": m})
	return out


func _landmark_pos(id: String) -> Variant:
	if rules == null or not rules.has_method("terrain"):
		return null
	var t: Variant = rules.call("terrain")
	if t == null or not (t as Object).has_method("landmark"):
		return null
	var lm: Variant = t.call("landmark", id)
	if lm is Dictionary and not (lm as Dictionary).is_empty():
		return Vector2(float((lm as Dictionary).get("x", 0.0)), float((lm as Dictionary).get("z", 0.0)))
	return null


## Un punto del suelo (x, z) en píxeles lógicos del cuadro, o null si queda detrás de la cámara.
func _project(cam3: Camera3D, p: Vector2) -> Variant:
	var w := Vector3(p.x, ground_h(p.x, p.y), p.y)
	if cam3.is_position_behind(w):
		return null
	return cam3.unproject_position(w)


func _inside_x(s: Vector2, m: float, size: Vector2) -> bool:
	return s.x >= m * size.x and s.x <= (1.0 - m) * size.x


## Dentro del cuadro con margen `m` (fracción del lado) y dentro de la banda libre.
func _inside(s: Vector2, m: float, band: Dictionary, size: Vector2) -> bool:
	return _inside_x(s, m, size) and s.y >= maxf(float(band.top), m * size.y) and s.y <= minf(float(band.bottom), (1.0 - m) * size.y)


func _all_inside(cam3: Camera3D, pts: Array, band: Dictionary, size: Vector2) -> bool:
	for p in pts:
		var s: Variant = _project(cam3, p.pos)
		if not (s is Vector2) or not _inside(s as Vector2, float(p.margin), band, size):
			return false
	return true


## Las holguras de un conjunto de puntos proyectados: cuánto puede moverse lo dibujado a la izquierda, la derecha, arriba y abajo sin que ningún punto pierda su margen ni
## salga de la banda ({left, right, up, down} en píxeles; negativas si alguno ya está afuera), o null si alguno queda detrás de la cámara.
func _slacks(cam3: Camera3D, pts: Array, band: Dictionary, size: Vector2) -> Variant:
	var out := {"left": 1.0e9, "right": 1.0e9, "up": 1.0e9, "down": 1.0e9}
	for p in pts:
		var s: Variant = _project(cam3, p.pos)
		if not (s is Vector2):
			return null
		var m := float(p.margin)
		var v := s as Vector2
		out.left = minf(out.left, v.x - m * size.x)
		out.right = minf(out.right, (1.0 - m) * size.x - v.x)
		out.up = minf(out.up, v.y - maxf(float(band.top), m * size.y))
		out.down = minf(out.down, minf(float(band.bottom), (1.0 - m) * size.y) - v.y)
	return out


## Ubica la cámara a `d` m con `center_pts` centrados por holguras en la banda (más `extra`, un corrimiento en píxeles de lo dibujado) y dice si `check_pts` entran.
## Devuelve {ok, dist, target, centered_on}.
func _place(cam3: Camera3D, d: float, pitch: float, yaw: float, center_pts: Array, check_pts: Array, band: Dictionary, size: Vector2, from: Vector2, extra: Vector2 = Vector2.ZERO) -> Dictionary:
	var screen_center := size * 0.5
	var t := from
	for pass_i in range(CENTER_PASSES):
		set_frame(t, d, pitch, yaw)
		apply(cam3)
		t = target
		var sl: Variant = _slacks(cam3, center_pts, band, size)
		if sl == null:
			break
		var shift := Vector2((float(sl.right) - float(sl.left)) * 0.5, (float(sl.down) - float(sl.up)) * 0.5) + extra  # cuánto tiene que moverse lo dibujado en la pantalla
		if shift.length() <= 0.5:
			break
		var g: Variant = _ground(cam3, screen_center - shift)  # el punto del suelo que hoy se ve ahí pasa a ser el centro de la mirada
		if g is Vector2:
			t = g as Vector2
		else:  # el rayo se va por encima del horizonte: estimación lineal con la escala de la pantalla en el objetivo
			var yaw_r := deg_to_rad(yaw)
			var forward := Vector2(sin(yaw_r), -cos(yaw_r))
			var right := Vector2(cos(yaw_r), sin(yaw_r))
			var mpp := 2.0 * d * tan(deg_to_rad(_vfov(cam3)) * 0.5) / maxf(size.y, 1.0)
			t = t + right * (-shift.x * mpp) + forward * (shift.y * mpp / maxf(sin(deg_to_rad(pitch)), 0.2))
	set_frame(t, d, pitch, yaw)
	apply(cam3)
	return {"ok": _all_inside(cam3, check_pts, band, size), "dist": dist, "target": target, "centered_on": center_pts}


func _fits_at(cam3: Camera3D, d: float, pitch: float, yaw: float, center_pts: Array, check_pts: Array, band: Dictionary, size: Vector2, from: Vector2) -> bool:
	return bool(_place(cam3, d, pitch, yaw, center_pts, check_pts, band, size, from).ok)


## Los blandos que quedan dentro del cuadro pero tapados por la cabecera o el dock (fuera de la banda), con la cámara como está.
func _half_hidden(cam3: Camera3D, soft: Array, band: Dictionary, size: Vector2) -> Array:
	var out: Array = []
	for p in soft:
		var s: Variant = _project(cam3, p.pos)
		if s is Vector2 and Rect2(Vector2.ZERO, size).has_point(s as Vector2) and ((s as Vector2).y < float(band.top) or (s as Vector2).y > float(band.bottom)):
			out.append(str(p.id))
	return out


## Cuánto correr lo dibujado hacia abajo (negativo: arriba), en píxeles, para que la menor cantidad de blandos quede a medio tapar por el HUD sin que los duros pierdan su margen;
## entre los corrimientos empatados, el que deja más blandos adentro y, después, el más chico. 0 si no hace falta o no se puede.
func _avoid_half_hidden(cam3: Camera3D, d: float, pitch: float, yaw: float, placed: Dictionary, hard: Array, soft: Array, band: Dictionary, size: Vector2) -> float:
	if _half_hidden(cam3, soft, band, size).is_empty():
		return 0.0
	var sl: Variant = _slacks(cam3, hard, band, size)
	if sl == null or float(sl.up) < 0.0 or float(sl.down) < 0.0:
		return 0.0
	var screens: Array = []
	for p in soft:
		var s: Variant = _project(cam3, p.pos)
		if s is Vector2:
			screens.append({"s": s, "margin": float(p.margin)})
	var best_shift := 0.0
	var best := [1.0e9, 0.0, 0.0]  # [a medio tapar, −adentro, |corrimiento|]
	var step := 8.0
	var s_px := -floorf(float(sl.up) / step) * step
	while s_px <= float(sl.down):
		var hidden := 0
		var inside := 0
		for e in screens:
			var v: Vector2 = (e.s as Vector2) + Vector2(0.0, s_px)
			if Rect2(Vector2.ZERO, size).has_point(v) and (v.y < float(band.top) or v.y > float(band.bottom)):
				hidden += 1
			elif _inside(v, float(e.margin), band, size):
				inside += 1
		var score := [float(hidden), -float(inside), absf(s_px)]
		if score[0] < best[0] or (score[0] == best[0] and (score[1] < best[1] or (score[1] == best[1] and score[2] < best[2]))):
			best = score
			best_shift = s_px
		s_px += step
	if best_shift == 0.0:
		return 0.0
	var trial := _place(cam3, d, pitch, yaw, placed.centered_on, hard, band, size, placed.target, Vector2(0.0, best_shift))
	if not bool(trial.ok):
		_place(cam3, d, pitch, yaw, placed.centered_on, hard, band, size, placed.target)
		return 0.0
	return best_shift


static func _vfov(cam3: Camera3D) -> float:
	if cam3.keep_aspect == Camera3D.KEEP_HEIGHT:
		return cam3.fov
	var size := cam3.get_viewport().get_visible_rect().size
	var aspect := size.x / maxf(size.y, 1.0)
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(cam3.fov) * 0.5) / aspect))


# ---------------------------------------------------------------------------------------------------------------------
# Apertura: desde lo alto de la quebrada baja en un solo movimiento hasta el cuadro inicial (5 a 7 s, camera.opening_s; clic, Espacio, Enter o cualquier tecla la saltan)

## `frames`: [{target: Vector2, dist, pitch_deg, yaw_deg, hold: bool}] — el primero es la partida; el último, el cuadro inicial. Los que llevan
## `hold` se miran `hold_s` segundos. El tiempo total sale de `total_s`.
func start_opening(frames: Array, total_s: float, hold_s: float) -> void:
	follow_id = ""
	_op_frames = []
	var holds := 0
	for f in frames:
		if bool((f as Dictionary).get("hold", false)):
			holds += 1
	var travels := maxi(frames.size() - 1, 1)
	var travel_s := maxf((total_s - hold_s * float(holds)) / float(travels), 0.2)
	var t := 0.0
	for i in range(frames.size()):
		var f: Dictionary = frames[i]
		if i > 0:
			t += travel_s
		_op_frames.append({"target": f.target, "dist": f.dist, "pitch_deg": f.pitch_deg, "yaw_deg": f.yaw_deg, "at": t})
		if bool(f.get("hold", false)):
			t += hold_s
			_op_frames.append({"target": f.target, "dist": f.dist, "pitch_deg": f.pitch_deg, "yaw_deg": f.yaw_deg, "at": t})
	_op_total = maxf(t, 0.1)
	_op_t = 0.0
	opening_active = _op_frames.size() >= 2
	if opening_active:
		_apply_opening_pose(0.0)


func opening_seconds() -> float:
	return _op_total


func opening_progress() -> float:
	return clampf(_op_t / _op_total, 0.0, 1.0) if opening_active else 1.0


## Avanza la apertura. Devuelve true mientras sigue corriendo.
func update_opening(delta: float) -> bool:
	if not opening_active:
		return false
	_op_t += delta
	if _op_t >= _op_total:
		finish_opening()
		return false
	_apply_opening_pose(_op_t)
	return true


func finish_opening() -> void:
	if not _op_frames.is_empty():
		var last: Dictionary = _op_frames[_op_frames.size() - 1]
		set_frame(last.target, last.dist, last.pitch_deg, last.yaw_deg)
	opening_active = false
	_op_frames = []
	if view != null and is_instance_valid(view) and view.has_method("set_opening_look"):
		view.call("set_opening_look", 0.0)


func _apply_opening_pose(t: float) -> void:
	var a: Dictionary = _op_frames[0]
	var b: Dictionary = _op_frames[_op_frames.size() - 1]
	for i in range(_op_frames.size() - 1):
		if t <= float(_op_frames[i + 1].at):
			a = _op_frames[i]
			b = _op_frames[i + 1]
			break
	var span := maxf(float(b.at) - float(a.at), 0.0001)
	var u := smoothstep(0.0, 1.0, clampf((t - float(a.at)) / span, 0.0, 1.0))
	target = (a.target as Vector2).lerp(b.target, u)
	dist = exp(lerpf(log(maxf(float(a.dist), 1.0)), log(maxf(float(b.dist), 1.0)), u))  # en escala logarítmica: el descenso se siente parejo de punta a punta
	pitch_deg = lerpf(float(a.pitch_deg), float(b.pitch_deg), u)
	yaw_deg = fposmod(rad_to_deg(lerp_angle(deg_to_rad(float(a.yaw_deg)), deg_to_rad(float(b.yaw_deg)), u)), 360.0)
	if view != null and is_instance_valid(view) and view.has_method("set_opening_look"):  # luna rasante y bruma lejana al principio; la luz de juego al llegar
		view.call("set_opening_look", 1.0 - smoothstep(0.0, 1.0, clampf(t / maxf(_op_total, 0.001), 0.0, 1.0)))
