extends RefCounted
## Cámara propia del nivel «humahuaca» (CONTRATO 3.5 y ADDENDA A-11). Guarda el cuadro (objetivo, distancia, inclinación y rumbo) y lo aplica a
## main.camera. `yaw_deg` es el RUMBO DE LA MIRADA: grados horarios desde el norte (0 mira al norte, −z; 90 mira al este, +x), como en initial_frame,
## canonical_view y qa_set_camera. La cámara se ubica en
##   centro + (−sin(yaw)·cos(pitch), sin(pitch), cos(yaw)·cos(pitch)) · distancia
## (VP-07) y el controlador la aplica ANTES de llamar a view.update_state (VP-08). Piso a 3 m sobre height_at, recorte con camera_bounds(),
## zoom hacia el cursor entre 40 y 900 m, arrastre del mapa, giro, inclinación y la apertura automática por los tres objetivos.
## No depende de ningún otro archivo del nivel: lo que necesita de las capas llega por parámetro (reglas y vista) o por Callable.

var target := Vector2(450.0, 325.0)
var dist := 470.0
var pitch_deg := 52.0
var yaw_deg := 325.0
var cfg: Dictionary = {}
var rules: Variant = null
var view: Variant = null
## Callable(camera: Camera3D, pos: Vector2) -> Variant (Vector2 del suelo, o null): lo pone el controlador (usa la vista o un plano de respaldo).
var ground_from_screen: Callable = Callable()

var opening_active := false
var _op_frames: Array = []  # [{target: Vector2, dist, pitch_deg, yaw_deg, at: float}]
var _op_t := 0.0
var _op_total := 13.5
var _drag_grab: Variant = null


func setup(config: Dictionary, rules_ref: Variant, view_ref: Variant) -> void:
	cfg = config
	rules = rules_ref
	view = view_ref


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


## Fija el cuadro entero (con los límites de la cámara). El rumbo se guarda en [0, 360).
func set_frame(t: Vector2, d: float, pitch: float, yaw: float) -> void:
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


func apply(cam: Camera3D) -> void:
	if cam == null or not cam.is_inside_tree():
		return
	var p := pose()
	cam.global_position = p.position
	cam.look_at(p.look_at, Vector3.UP)


## Rumbo horizontal de la mirada (para las pruebas): el vector (x, z) unitario hacia donde mira.
func gaze() -> Vector2:
	var yaw := deg_to_rad(yaw_deg)
	return Vector2(sin(yaw), -cos(yaw))


# ---------------------------------------------------------------------------------------------------------------------
# Movimiento

## `move`: x a la derecha y y hacia adelante (−1 a 1), relativos al rumbo de la cámara. La velocidad crece con la distancia.
func pan(move: Vector2, delta: float, fast: bool = false, factor: float = 1.0) -> void:
	if move == Vector2.ZERO:
		return
	var yaw := deg_to_rad(yaw_deg)
	var forward := Vector2(sin(yaw), -cos(yaw))
	var right := Vector2(cos(yaw), sin(yaw))
	var speed := dist * num("pan_speed", 0.9) * factor * (num("pan_fast_mult", 3.0) if fast else 1.0)
	target = clamp_target(target + (right * move.x + forward * move.y) * speed * delta)


func rotate_view(yaw_dir: float, pitch_dir: float, delta: float) -> void:
	if yaw_dir != 0.0:
		yaw_deg = fposmod(yaw_deg + yaw_dir * num("yaw_deg_s", 70.0) * delta, 360.0)
	if pitch_dir != 0.0:
		pitch_deg = clampf(pitch_deg + pitch_dir * num("pitch_deg_s", 40.0) * delta, num("min_pitch_deg", 10.0), num("max_pitch_deg", 80.0))


func _ground(cam: Camera3D, pos: Vector2) -> Variant:
	if ground_from_screen.is_valid():
		return ground_from_screen.call(cam, pos)
	return null


## Rueda del mouse: acerca (factor < 1) o aleja (factor > 1) manteniendo bajo el cursor el mismo punto del suelo.
func zoom_at(cam: Camera3D, mouse: Vector2, factor: float) -> void:
	var before: Variant = _ground(cam, mouse)
	dist = clampf(dist * factor, min_dist(), max_dist())
	apply(cam)
	var after: Variant = _ground(cam, mouse)
	if before is Vector2 and after is Vector2:
		target = clamp_target(target + ((before as Vector2) - (after as Vector2)))
		apply(cam)


func drag_begin(cam: Camera3D, mouse: Vector2) -> void:
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


func center_on(p: Vector2) -> void:
	target = clamp_target(p)


# ---------------------------------------------------------------------------------------------------------------------
# Apertura: la cámara recorre los tres objetivos y termina en el cuadro inicial (12 a 15 s; cualquier tecla la salta)

## `frames`: [{target: Vector2, dist, pitch_deg, yaw_deg, hold: bool}] — el primero es la partida; el último, el cuadro inicial. Los que llevan
## `hold` se miran `hold_s` segundos. El tiempo total sale de `total_s`.
func start_opening(frames: Array, total_s: float, hold_s: float) -> void:
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
	dist = lerpf(float(a.dist), float(b.dist), u)
	pitch_deg = lerpf(float(a.pitch_deg), float(b.pitch_deg), u)
	yaw_deg = fposmod(rad_to_deg(lerp_angle(deg_to_rad(float(a.yaw_deg)), deg_to_rad(float(b.yaw_deg)), u)), 360.0)
