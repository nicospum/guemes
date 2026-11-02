extends Node3D
## Vista real del nivel «humahuaca» (CONTRATO 3.4; pista visual). Lee SOLO `rules.render_state()`, `rules.environment()`, `rules.terrain()` y su propio JSON
## (data/humahuaca_visual.json): no calcula daño, tiempo ni órdenes y no dibuja información que el jugador no tiene. La cámara es de la UI: la vista solo ofrece funciones.
## Está partida por responsabilidad (cada archivo ≤ 1 500 líneas):
##   · humahuaca_gfx.gd        paleta, materiales, mallas básicas y el TERRENO CONTINUO (ventana de 4 m, contexto de 30 m y horizonte hasta ±8 km con un solo shader);
##   · humahuaca_buildings.gd  hitos (templo, batería, casa del cura, posta, torre), tapias, zanjas, caminos, núcleo de casas y anillo de contenido;
##   · humahuaca_units.gd      las cinco fichas, los defensores y el botín (tamaño fijo en pantalla);
##   · humahuaca_fx.gd         luces de la guardia, lluvia, anillos de estado y de visibilidad y efectos;
##   · humahuaca_gen.gd        el generador procedural de arte (templo y arquetipos de figura): el único canal de arte, sin Blender (ADDENDA A-01).
## Este archivo arma el ambiente (luz, cielo, niebla), el cuadro a cuadro, el picking y las cámaras (cuadro inicial y vistas canónicas) y la API de QA.
## Convenciones: +x este, +z sur (norte = −z), y en metros sobre el cero local; `yaw_deg` es un RUMBO (horario desde el norte, visto en el mapa; ADDENDA A-11: es hacia
## dónde MIRA la cámara); `environment().time_of_day` es 0 = noche plena, 0,5 = alba y 1 = día pleno (vocab_view.TIME_OF_DAY).

const V = preload("res://scripts/humahuaca/humahuaca_vocab.gd")
const VV = preload("res://scripts/humahuaca/view/vocab_view.gd")
const Gfx = preload("res://scripts/humahuaca/view/humahuaca_gfx.gd")
const Buildings = preload("res://scripts/humahuaca/view/humahuaca_buildings.gd")
const Units = preload("res://scripts/humahuaca/view/humahuaca_units.gd")
const Fxm = preload("res://scripts/humahuaca/view/humahuaca_fx.gd")

signal minimap_changed

const WORLD_DEFAULT := Vector2(900.0, 650.0)
const CAMERA_MARGIN_M := 120.0
const PICK_UNIT_PX := 55.0
const PICK_FRONT_PX := 60.0
const PICK_LANDMARK_PX := 40.0
const MAX_RAY_M := 6000.0
const ROOTS := ["Terreno", "Rasgos", "Hitos", "Nucleo", "Vegetacion", "Fichas", "Etiquetas", "Defensores", "Botin", "Luces", "Anillos", "Efectos", "Lluvia"]

var selected_ids: Array = []
var unit_nodes: Dictionary = {}
var unit_labels: Dictionary = {}
var build_ms := 0.0  ## lo que tardó el último build() (lo informa el recorrido de QA)
var build_stages_ms: Dictionary = {}  ## y por etapa (terreno, texturas, edificios, vegetación, fichas)
var content_report: Dictionary = {}  ## cuánto contenido armó: triángulos, casas, tapias, vegetación

var gfx = null
var buildings = null
var units = null
var fxm = null

var _rules = null
var _terrain = null
var _data: Dictionary = {}
var _quality := "media"
var _qcfg: Dictionary = {}
var _world := WORLD_DEFAULT
var _roots: Dictionary = {}
var _env: Environment
var _sky_mat: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _albedo := false
var _override_tod := -1.0
var _override_rain := 0.0
var _tod := 0.0
var _rain := 0.0
var _env_dirty := true
var _layers: Dictionary = {}
var _minimap_cache: Dictionary = {}
var _version := -2
var _time := 0.0
var _splats: Array = []
var _ctx_tex: Texture2D = null


# ---------------------------------------------------------------------------------------------------------------------
# Construcción

func build(rules: RefCounted, quality: String = "media") -> void:
	var started := Time.get_ticks_usec()
	_clear_scene()
	_rules = rules
	_data = V.load_json(V.VISUAL_PATH)
	_terrain = rules.call("terrain") if rules != null and rules.has_method("terrain") else null
	_world = WORLD_DEFAULT
	if rules != null and rules.has_method("map_size"):
		var size: Variant = rules.call("map_size")
		if size is Vector2 and size.x > 100.0 and size.y > 100.0:
			_world = size
	gfx = Gfx.new()
	gfx.setup(_data, quality, _terrain, _world)
	_quality = gfx.quality
	_qcfg = gfx.qcfg
	buildings = Buildings.new()
	buildings.setup(gfx, _terrain)
	units = Units.new()
	units.setup(gfx)
	fxm = Fxm.new()
	fxm.setup(gfx, units, self)
	for layer in VV.LAYERS:
		_layers[layer] = layer != "exposure"
	for root_name in ROOTS:
		var node := Node3D.new()
		node.name = root_name
		add_child(node)
		_roots[root_name] = node
	_make_environment()
	var stage := Time.get_ticks_usec()
	gfx.build_terrain(_roots.Terreno)
	_splats = gfx.build_splats()
	var river_line: PackedVector2Array = gfx.build_river(_roots.Rasgos)
	_ctx_tex = gfx.build_context_texture(river_line)
	build_stages_ms["terreno"] = _lap(stage)
	stage = Time.get_ticks_usec()
	buildings.build_features(_roots.Rasgos)
	buildings.build_landmarks(_roots.Hitos)
	build_stages_ms["hitos_y_rasgos"] = _lap(stage)
	stage = Time.get_ticks_usec()
	buildings.build_nucleo(_roots.Nucleo)
	buildings.build_vegetation(_roots.Vegetacion, river_line)
	build_stages_ms["nucleo_y_vegetacion"] = _lap(stage)
	stage = Time.get_ticks_usec()
	units.build_tokens(_roots.Fichas, _roots.Etiquetas)
	unit_nodes = units.unit_nodes
	unit_labels = units.unit_labels
	fxm.build_rain(_roots.Lluvia)
	build_stages_ms["fichas_y_lluvia"] = _lap(stage)
	_apply_layers()
	_env_dirty = true
	_version = -2
	update_state(0.0)
	build_ms = float(Time.get_ticks_usec() - started) / 1000.0
	content_report = {"terreno": gfx.build_stats, "triangulos_edificios_y_vegetacion": buildings.triangle_count, "contenido": buildings.content_counts.duplicate(),
		"casas": buildings.house_count, "fichas": units.part_counts.duplicate(), "luces_reales": fxm.omni_count}
	minimap_changed.emit()


func _lap(since_usec: int) -> float:
	return snappedf(float(Time.get_ticks_usec() - since_usec) / 1000.0, 0.1)


func _clear_scene() -> void:
	if fxm != null:
		fxm.reset()
	for child in get_children():
		remove_child(child)
		child.free()
	_roots.clear()
	_minimap_cache.clear()
	_splats = []
	_ctx_tex = null
	unit_nodes = {}
	unit_labels = {}
	gfx = null
	buildings = null
	units = null
	fxm = null


func _make_environment() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	_sky_mat = ProceduralSkyMaterial.new()
	_sky_mat.sky_curve = 0.22
	_sky_mat.ground_curve = 0.06
	_sky_mat.use_debanding = true
	sky.sky_material = _sky_mat
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.tonemap_mode = Environment.TONE_MAPPER_ACES
	_env.fog_enabled = true
	_env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	_env.fog_sky_affect = float((_data.get("fog", {}) as Dictionary).get("sky_affect", 0.55))
	var world_env := WorldEnvironment.new()
	world_env.name = "Ambiente"
	world_env.environment = _env
	add_child(world_env)
	_sun = DirectionalLight3D.new()
	_sun.name = "Sol"
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_sun.directional_shadow_max_distance = 1100.0
	_sun.directional_shadow_blend_splits = true
	_sun.shadow_bias = 0.25
	_sun.shadow_normal_bias = 3.5
	add_child(_sun)


# ---------------------------------------------------------------------------------------------------------------------
# Estado dinámico (render_state)

func update_state(delta: float) -> void:
	_time += delta
	if _rules != null and _rules.has_method("render_state") and gfx != null:
		var rs: Variant = _rules.render_state()
		if rs is Dictionary:
			var state: Dictionary = rs
			_sync_environment(state)
			var version := int(state.get("version", -1))
			if version != _version or version < 0:
				_version = version
				_sync_dynamic(state)
	if gfx == null:
		return
	if _env_dirty:
		_apply_environment()
	_update_scales()
	_check_rings()
	fxm.update_fx(delta)
	fxm.animate_lights(delta)
	units.update_selection(selected_ids, _time)


## Lo que depende de la cámara se recalcula también acá: el controlador llama a `update_state` ANTES de ubicar la cámara de ese cuadro (main la deja donde la quería el
## menú y el controlador la reubica al final de su `_process`), así que las fichas, las luces y los anillos se medían con la cámara del cuadro anterior o con la del
## menú y salían de 12 a 30 px en vez de ≥ 48 px (se midió con la escena real, hallazgo I-R1.0-3). Este `_process` corre después del de su padre, con la cámara puesta.
func _process(_delta: float) -> void:
	if _rules == null or _roots.is_empty() or gfx == null:
		return
	_update_scales()
	_check_rings()


func _update_scales() -> void:
	units.update_scales(self, get_viewport().get_camera_3d() if is_inside_tree() else null)


func _check_rings() -> void:
	fxm.check_rings(_roots.Anillos)


func _sync_environment(state: Dictionary) -> void:
	var env: Dictionary = state.get("env", {}) if state.get("env", null) is Dictionary else {}
	if env.is_empty() and _rules != null and _rules.has_method("environment"):
		env = _rules.environment()
	var tod := float(env.get("time_of_day", 0.0))
	var rain := float(env.get("rain", 0.0))
	if _override_tod >= 0.0:
		tod = _override_tod
		rain = _override_rain
	if _env_dirty or absf(tod - _tod) > 0.001 or absf(rain - _rain) > 0.002:
		_tod = tod
		_rain = rain
		_apply_environment()


func _sync_dynamic(state: Dictionary) -> void:
	units.sync_units(state, bool(_layers.get("labels", true)))
	_sync_objectives(state)
	units.sync_things(_roots.Defensores, "enemy", state.get("enemies", []))
	units.sync_things(_roots.Botin, "loot", state.get("loot", []))
	fxm.sync_lights(_roots.Luces, state, bool(_layers.get("lights", true)))
	_update_scales()


## Anillos de estado de los objetivos y de visibilidad; y cuál de las dos torres del diseño es la del mundo (la que `tower` ubica).
func _sync_objectives(state: Dictionary) -> void:
	fxm.sync_objectives(_roots.Anillos, state, buildings.lm_by_id, Callable(buildings, "footprint"))
	var tower: Variant = state.get("tower", {})
	var at := Vector2(-9999.0, -9999.0)
	if tower is Dictionary and not (tower as Dictionary).is_empty():
		at = Vector2(float(tower.get("x", -9999.0)), float(tower.get("z", -9999.0)))
		if bool(tower.get("firing", false)):
			fx("fogonazo", at, {"height": 9.5})
	var best := 40.0
	var chosen := ""
	for lid in buildings.lm_nodes:
		if str(buildings.lm_by_id[lid].get("type", "")) == "torre":
			(buildings.lm_nodes[lid] as Node3D).visible = false
			var dist := Vector2(float(buildings.lm_by_id[lid].x), float(buildings.lm_by_id[lid].z)).distance_to(at)
			if dist < best:
				best = dist
				chosen = str(lid)
	if chosen != "":
		(buildings.lm_nodes[chosen] as Node3D).visible = true


func pool_alpha(visibility_m: float) -> float:
	return fxm.pool_alpha(visibility_m)


func _pool_arcs(pools: Array) -> Array:
	return fxm.pool_arcs(pools)


# ---------------------------------------------------------------------------------------------------------------------
# Luz, niebla y lluvia

## Un color de luz: el id de paleta de `color` (con `gain`) y, si trae `tint`, mezclado hacia ese otro id de paleta en `tint_mix` (0 a 1). Así un sol del alba puede ser un
## blanco apenas cálido sin escribir un HEX suelto: el oro puro (sin mezcla) lavaba todo el cuadro de naranja saturado (hallazgo I-R1.0-3).
func _tinted(spec: Dictionary, default_id: String) -> Color:
	var base: Color = gfx.pc(str(spec.get("color", default_id)), float(spec.get("gain", 1.0)))
	var tint_id := str(spec.get("tint", ""))
	if tint_id == "":
		return base
	return base.lerp(gfx.pc(tint_id, float(spec.get("tint_gain", 1.0))), clampf(float(spec.get("tint_mix", 0.0)), 0.0, 1.0))


func _light_params(key: String) -> Dictionary:
	var l: Dictionary = (_data.get("lights", {}) as Dictionary).get(key, {})
	var sun: Dictionary = l.get("sun", {})
	var amb: Dictionary = l.get("ambient", {})
	var sky: Dictionary = l.get("sky", {})
	var fog: Dictionary = l.get("fog", {})
	return {
		"t": float(l.get("time_of_day", VV.TIME_OF_DAY.get(key, 0.0))),
		"sun_el": float(sun.get("elevation_deg", 30.0)), "sun_az": float(sun.get("azimuth_deg", 90.0)),
		"sun_col": _tinted(sun, "blanco_textil"), "sun_energy": float(sun.get("energy", 1.0)),
		"sun_shadow": 1.0 if bool(sun.get("shadows", false)) else 0.0,
		"amb_col": _tinted(amb, "cal_envejecida"), "amb_energy": float(amb.get("energy", 0.8)),
		"sky_top": gfx.pc(str(sky.get("top", "azul_elegido")), float(sky.get("top_gain", 1.0))),
		"sky_hor": gfx.pc(str(sky.get("horizon", "cal_envejecida")), float(sky.get("horizon_gain", 1.0))),
		"sky_gnd": gfx.pc(str(sky.get("ground", "suelo_seco")), float(sky.get("ground_gain", 1.0))),
		"fog_col": _tinted(fog, "cal_envejecida"), "fog_density": float(fog.get("density", 0.001)),
		"exposure": float(l.get("exposure", 1.0))}


func _blend_params(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	var out := {}
	for key in a:
		if key == "sun_az":
			out[key] = rad_to_deg(lerp_angle(deg_to_rad(float(a[key])), deg_to_rad(float(b[key])), k))
		elif a[key] is Color:
			out[key] = (a[key] as Color).lerp(b[key] as Color, k)
		else:
			out[key] = lerpf(float(a[key]), float(b[key]), k)
	return out


func _apply_environment() -> void:
	_env_dirty = false
	if _env == null or gfx == null:
		return
	var noche := _light_params("noche_lluvia")
	var alba := _light_params("alba")
	var dia := _light_params("dia")
	var p: Dictionary
	if _tod <= float(alba.t):
		p = _blend_params(noche, alba, clampf((_tod - float(noche.t)) / maxf(float(alba.t) - float(noche.t), 0.001), 0.0, 1.0))
	else:
		p = _blend_params(alba, dia, clampf((_tod - float(alba.t)) / maxf(float(dia.t) - float(alba.t), 0.001), 0.0, 1.0))
	var rain_cfg: Dictionary = _data.get("rain", {})
	var fog_cfg: Dictionary = _data.get("fog", {})
	var elevation := deg_to_rad(float(p.sun_el))
	var azimuth := deg_to_rad(float(p.sun_az))
	var to_sun := Vector3(sin(azimuth) * cos(elevation), sin(elevation), -cos(azimuth) * cos(elevation))
	_sun.transform = Transform3D(Basis.looking_at(-to_sun, Vector3.UP), Vector3.ZERO)
	_sun.light_color = p.sun_col
	_sun.light_energy = float(p.sun_energy)
	_sun.shadow_enabled = bool(_qcfg.get("shadows", true)) and float(p.sun_shadow) > 0.5 and not _albedo
	_sky_mat.sky_top_color = p.sky_top
	_sky_mat.sky_horizon_color = p.sky_hor
	_sky_mat.ground_horizon_color = p.sky_hor
	_sky_mat.ground_bottom_color = p.sky_gnd
	if _albedo:  # render de albedo para la métrica de paleta: sin sombreado, niebla, exposición ni sombras
		_env.background_mode = Environment.BG_COLOR
		_env.background_color = Color(0.6, 0.6, 0.6)
		_env.ambient_light_color = Color.WHITE
		_env.ambient_light_energy = 1.0
		_env.fog_enabled = false
		_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		_env.tonemap_exposure = 1.0
		_sun.light_energy = 0.0
	else:
		_env.background_mode = Environment.BG_SKY
		_env.ambient_light_color = p.amb_col
		_env.ambient_light_energy = float(p.amb_energy)
		_env.fog_enabled = true
		_env.fog_density = clampf(float(p.fog_density) + _rain * float(rain_cfg.get("fog_density_per_rain", 0.0006)), float(fog_cfg.get("density_min", 0.0003)), float(fog_cfg.get("density_max", 0.0045)))
		_env.fog_light_color = p.fog_col
		_env.tonemap_mode = Environment.TONE_MAPPER_ACES
		_env.tonemap_exposure = float(p.exposure)
	gfx.set_rain(_rain)
	fxm.set_rain(_rain, _albedo)


func set_time_override(time_of_day: float, rain: float) -> void:
	_override_tod = time_of_day if time_of_day >= 0.0 else -1.0
	_override_rain = clampf(rain, 0.0, 1.0)
	_env_dirty = true
	if _override_tod >= 0.0:
		_tod = _override_tod
		_rain = _override_rain
		_apply_environment()


func set_albedo_mode(on: bool) -> void:
	if on == _albedo or gfx == null:
		return
	_albedo = on
	gfx.set_albedo(on)
	for omni in find_children("*", "OmniLight3D", true, false):
		(omni as Node3D).visible = not on
	_apply_layers()
	_env_dirty = true
	_apply_environment()


# ---------------------------------------------------------------------------------------------------------------------
# Capas, selección y efectos

func set_layer_visible(layer: String, on: bool) -> void:
	if VV.LAYERS.has(layer):
		_layers[layer] = on
		_apply_layers()


func layer_visible(layer: String) -> bool:
	return bool(_layers.get(layer, false))


func _apply_layers() -> void:
	if _roots.is_empty():
		return
	(_roots.Hitos as Node3D).visible = bool(_layers.get("landmarks", true))
	(_roots.Nucleo as Node3D).visible = bool(_layers.get("landmarks", true))
	(_roots.Luces as Node3D).visible = bool(_layers.get("lights", true)) and not _albedo
	(_roots.Defensores as Node3D).visible = bool(_layers.get("enemy", true))
	(_roots.Anillos as Node3D).visible = bool(_layers.get("visibility", true))
	(_roots.Etiquetas as Node3D).visible = bool(_layers.get("labels", true))
	(_roots.Efectos as Node3D).visible = not _albedo


func set_selected_ids(ids: Array) -> void:
	selected_ids = ids.duplicate()
	if units != null:
		units.update_selection(selected_ids, _time)


func fx(kind: String, pos: Vector2, opts: Dictionary = {}) -> void:
	if fxm != null and not _roots.is_empty():
		fxm.fx(_roots.Efectos, kind, pos, opts)


# ---------------------------------------------------------------------------------------------------------------------
# Cámara, proyección y picking

func camera_bounds() -> Rect2:
	return Rect2(-CAMERA_MARGIN_M, -CAMERA_MARGIN_M, _world.x + 2.0 * CAMERA_MARGIN_M, _world.y + 2.0 * CAMERA_MARGIN_M)


func clamp_camera_target(p: Vector3) -> Vector3:
	var r := camera_bounds()
	var x := clampf(p.x, r.position.x, r.end.x)
	var z := clampf(p.z, r.position.y, r.end.y)
	return Vector3(x, maxf(_h(x, z), p.y), z)


func _h(x: float, z: float) -> float:
	return float(_terrain.height_at(x, z)) if _terrain != null else Gfx.FLAT_H


func world_to_map(p: Vector2) -> Vector2:
	return Vector2(p.x / _world.x, p.y / _world.y)  # v = 0 es el NORTE (z = 0)


func map_to_world(uv: Vector2) -> Vector2:
	return Vector2(uv.x * _world.x, uv.y * _world.y)


func _cam_ok(camera: Camera3D) -> bool:
	return camera != null and camera.is_inside_tree() and camera.get_viewport() != null


## Marcha un rayo sobre `height_at`: Vector2 (x, z) del punto donde pega, o null si no toca el suelo.
func _ray_ground(origin: Vector3, dir: Vector3) -> Variant:
	if origin.y <= _h(origin.x, origin.z):
		return Vector2(origin.x, origin.z)
	if dir.y >= 0.0:
		return null
	var prev_t := 0.0
	var t := 4.0
	while t < MAX_RAY_M:
		var p := origin + dir * t
		if p.y <= _h(p.x, p.z):
			var lo := prev_t
			var hi := t
			for _i in range(14):
				var mid := (lo + hi) * 0.5
				var q := origin + dir * mid
				if q.y <= _h(q.x, q.z):
					hi = mid
				else:
					lo = mid
			var hit := origin + dir * hi
			return Vector2(hit.x, hit.z)
		prev_t = t
		t += clampf(t * 0.012, 3.0, 20.0)
	return null


func ground_xz_from_screen(camera: Camera3D, pos: Vector2) -> Variant:
	if not _cam_ok(camera):
		return null
	return _ray_ground(camera.project_ray_origin(pos), camera.project_ray_normal(pos))


func camera_frustum_on_ground(camera: Camera3D) -> PackedVector2Array:
	var out := PackedVector2Array()
	if not _cam_ok(camera):
		return out
	var size := camera.get_viewport().get_visible_rect().size
	for corner in [Vector2(0.0, 0.0), Vector2(size.x, 0.0), Vector2(size.x, size.y), Vector2(0.0, size.y)]:
		var origin := camera.project_ray_origin(corner)
		var dir := camera.project_ray_normal(corner)
		var hit: Variant = _ray_ground(origin, dir)
		if hit is Vector2:
			out.append(hit)
		else:  # el rayo se va por encima del horizonte: se lo corta a 4 km para que el cuadro siga siendo un polígono
			var flat := Vector2(dir.x, dir.z)
			out.append(Vector2(origin.x, origin.z) + (flat.normalized() if flat.length() > 0.0001 else Vector2(0.0, -1.0)) * 4000.0)
	return out


func meters_per_pixel(camera: Camera3D, pos: Vector2 = Vector2(-1, -1)) -> float:
	if not _cam_ok(camera) or gfx == null:
		return 1.0
	var screen := camera.get_viewport().get_visible_rect().size * 0.5 if pos.x < 0.0 or pos.y < 0.0 else pos
	var hit: Variant = ground_xz_from_screen(camera, screen)
	var point := camera.project_ray_origin(screen) + camera.project_ray_normal(screen) * 500.0
	if hit is Vector2:
		point = Vector3(hit.x, _h(hit.x, hit.y), hit.y)
	return gfx.meters_per_px_at(camera, point)


func _screen_of(camera: Camera3D, p: Vector3) -> Dictionary:
	return {"screen": camera.unproject_position(p), "behind": camera.is_position_behind(p)}


func _unit_top(id: String) -> Vector3:
	var info: Dictionary = units.tokens[id]
	var root: Node3D = info.root
	return root.position + Vector3(0.0, float(info.base_h) * root.scale.y, 0.0)


## [[id, base en pantalla, cima en pantalla], …] de las agrupaciones visibles y delante de la cámara, en el orden de GROUPS.
func _unit_ids_on_screen(camera: Camera3D) -> Array:
	var out: Array = []
	if not _cam_ok(camera) or units == null:
		return out
	for id in V.GROUPS:
		if units.tokens.has(id) and (units.tokens[id].root as Node3D).visible:
			var base := _screen_of(camera, (units.tokens[id].root as Node3D).position)
			if not bool(base.behind):
				out.append([id, base.screen, camera.unproject_position(_unit_top(id))])
	return out


## La agrupación cuya figura (el segmento de la base a la cima en pantalla) queda a ≤ 55 px de `pos`; si hay varias, la más cercana.
func pick_unit(camera: Camera3D, pos: Vector2) -> String:
	var best := ""
	var best_d := PICK_UNIT_PX
	for trio in _unit_ids_on_screen(camera):
		var d := Geometry2D.get_closest_point_to_segment(pos, trio[1], trio[2]).distance_to(pos)
		if d <= best_d:
			best_d = d
			best = str(trio[0])
	return best


func pick_units_in_rect(camera: Camera3D, rect: Rect2) -> Array:
	var out: Array = []
	for trio in _unit_ids_on_screen(camera):
		if rect.abs().has_point(((trio[1] as Vector2) + (trio[2] as Vector2)) * 0.5):
			out.append(trio[0])
	return out


## El hito más cercano a `pos` dentro de `radius_px` entre los de `ids` (anclado a `lift` m sobre el suelo).
func _nearest_landmark(camera: Camera3D, pos: Vector2, ids: Array, radius_px: float, lift: float) -> String:
	var best := ""
	var best_d := radius_px
	if not _cam_ok(camera) or buildings == null:
		return best
	for id in ids:
		if not buildings.lm_by_id.has(id) or (buildings.lm_nodes.has(id) and not (buildings.lm_nodes[id] as Node3D).visible):
			continue
		var lm: Dictionary = buildings.lm_by_id[id]
		var s := _screen_of(camera, Vector3(float(lm.x), _h(float(lm.x), float(lm.z)) + lift, float(lm.z)))
		var d := (s.screen as Vector2).distance_to(pos)
		if not bool(s.behind) and d < best_d:
			best_d = d
			best = str(id)
	return best


func pick_front(camera: Camera3D, pos: Vector2) -> String:
	return _nearest_landmark(camera, pos, V.OBJECTIVES, PICK_FRONT_PX, 2.0)


func pick_landmark(camera: Camera3D, pos: Vector2) -> String:
	return _nearest_landmark(camera, pos, buildings.lm_by_id.keys() if buildings != null else [], PICK_LANDMARK_PX, 1.5)


func get_landmark_info(id: String) -> Dictionary:
	if buildings == null or not buildings.lm_by_id.has(id):
		return {}
	var info: Dictionary = (buildings.lm_by_id[id] as Dictionary).duplicate(true)
	info["y"] = _h(float(info.get("x", 0.0)), float(info.get("z", 0.0)))
	return info


func landmark_labels(camera: Camera3D) -> Array:
	var out: Array = []
	if not _cam_ok(camera) or buildings == null:
		return out
	for lm in buildings.landmarks:
		var id := str(lm.id)
		if buildings.lm_nodes.has(id) and not (buildings.lm_nodes[id] as Node3D).visible:
			continue
		var s := _screen_of(camera, Vector3(float(lm.x), _h(float(lm.x), float(lm.z)) + float(lm.get("height_m", 3.0)) + 2.0, float(lm.z)))
		out.append({"id": id, "name": str(lm.get("short", lm.get("name", id))), "tag": str(lm.get("tag", "diseno")), "screen": s.screen, "behind": s.behind})
	return out


# ---------------------------------------------------------------------------------------------------------------------
# Cuadros canónicos y cámara inicial

func canonical_view(id: String) -> Dictionary:
	for view in _data.get("canonical_views", []):
		if view is Dictionary and str(view.get("id", "")) == id:
			var t: Vector2 = Gfx.pt(view.get("target", {}))
			return {"target": Vector3(t.x, _h(t.x, t.y), t.y), "distance": float(view.get("distance", 100.0)), "pitch_deg": float(view.get("pitch_deg", 45.0)),
				"yaw_deg": float(view.get("yaw_deg", 0.0)), "time_of_day": float(view.get("time_of_day", 0.0)), "rain": float(view.get("rain", 0.0)),
				"must_show": (view.get("must_show", []) as Array).duplicate()}
	return {}


## La transformación de una cámara que mira a `target` desde `distance` m con `pitch_deg` de inclinación y rumbo `yaw_deg` (hacia dónde MIRA; ADDENDA A-11).
func frame_transform(target: Vector3, distance: float, pitch_deg: float, yaw_deg: float) -> Transform3D:
	var yaw := deg_to_rad(yaw_deg)
	var pitch := deg_to_rad(pitch_deg)
	var look := Vector3(sin(yaw) * cos(pitch), -sin(pitch), -cos(yaw) * cos(pitch))
	return Transform3D(Basis.looking_at(look, Vector3.UP), target - look * distance)


## Los puntos que el cuadro inicial debe incluir: los hitos de `initial_frame.must_include` (los tres objetivos, el centro de la zona de partida y, desde R1, las cinco partidas).
func _frame_points() -> Array:
	var pts: Array = []
	var ids: Array = (_data.get("initial_frame", {}) as Dictionary).get("must_include", V.OBJECTIVES + ["zona_partida"])
	for id in ids:
		if buildings != null and buildings.lm_by_id.has(str(id)):
			var lm: Dictionary = buildings.lm_by_id[str(id)]
			pts.append(Vector3(float(lm.x), _h(float(lm.x), float(lm.z)), float(lm.z)))
	return pts


## ¿Entran todos los puntos con `margin_pct` % de borde libre? La proyección se calcula a mano para no mover la cámara real.
func _frame_fits(target: Vector3, distance: float, pitch: float, yaw: float, vfov: float, aspect: float, pts: Array, margin_pct: float) -> bool:
	var inverse := frame_transform(target, distance, pitch, yaw).affine_inverse()
	var th := tan(deg_to_rad(vfov) * 0.5)
	var limit := 1.0 - margin_pct * 0.02
	for p in pts:
		var local: Vector3 = inverse * (p as Vector3)
		if local.z > -0.5 or absf(local.x / (-local.z * th * aspect)) > limit or absf(local.y / (-local.z * th)) > limit:
			return false
	return true


## El cuadro inicial: el del JSON, ensanchado en pasos de 4 % (hasta 900 m) solo lo necesario para que entren los hitos de `must_include` con 5 % de borde libre; si no
## entran, `fits` es falso.
func initial_frame(camera: Camera3D) -> Dictionary:
	var frame: Dictionary = _data.get("initial_frame", {})
	var t: Vector2 = Gfx.pt(frame.get("target", {"x": 350.0, "z": 470.0}))
	var target := Vector3(t.x, _h(t.x, t.y), t.y)
	var distance := float(frame.get("distance", 470.0))
	var pitch := float(frame.get("pitch_deg", 52.0))
	var yaw := float(frame.get("yaw_deg", 325.0))
	var margin := float(frame.get("margin_pct", VV.FRAME_MARGIN_PCT))
	var vfov := Gfx.vfov(camera)
	var aspect := Gfx.aspect(camera)
	var pts := _frame_points()
	var fits := false
	for attempt in range(2):
		if pts.is_empty():
			break
		fits = _frame_fits(target, distance, pitch, yaw, vfov, aspect, pts, margin)
		while not fits and distance < 900.0:
			distance = minf(distance * 1.04, 900.0)
			fits = _frame_fits(target, distance, pitch, yaw, vfov, aspect, pts, margin)
		if fits or attempt == 1:
			break
		var center := Vector3.ZERO  # no entra con el objetivo del JSON: se recentra en el promedio de los puntos y se vuelve a ensanchar
		for p in pts:
			center += p as Vector3
		center /= float(pts.size())
		target = Vector3(center.x, _h(center.x, center.z), center.z)
		distance = float(frame.get("distance", 470.0))
	return {"target": target, "distance": distance, "pitch_deg": pitch, "yaw_deg": yaw, "fits": fits}


# ---------------------------------------------------------------------------------------------------------------------
# Minimapa y sondas de QA

func get_minimap_texture(size: Vector2i) -> Texture2D:
	var key := "%dx%d" % [size.x, size.y]
	if not _minimap_cache.has(key):
		var img: Image = null
		if _terrain != null and _terrain.has_method("minimap_image"):
			var made: Variant = _terrain.minimap_image(size, {})
			if made is Image and not (made as Image).is_empty():
				img = made
				if img.get_width() != size.x or img.get_height() != size.y:
					img.resize(size.x, size.y)
		if img == null:
			img = Image.create(maxi(size.x, 1), maxi(size.y, 1), false, Image.FORMAT_RGBA8)
			img.fill(gfx.pc("suelo_seco") if gfx != null else Color("B99A72"))
		_minimap_cache[key] = ImageTexture.create_from_image(img)
	return _minimap_cache[key]


func _screen_rect(camera: Camera3D, pts: Array) -> Rect2:
	var lo := Vector2(1.0e9, 1.0e9)
	var hi := Vector2(-1.0e9, -1.0e9)
	var any := false
	for p in pts:
		if not camera.is_position_behind(p as Vector3):
			var s := camera.unproject_position(p as Vector3)
			lo = Vector2(minf(lo.x, s.x), minf(lo.y, s.y))
			hi = Vector2(maxf(hi.x, s.x), maxf(hi.y, s.y))
			any = true
	return Rect2(lo, hi - lo) if any else Rect2()


func _rect_array(r: Rect2) -> Array:
	return [snappedf(r.position.x, 0.1), snappedf(r.position.y, 0.1), snappedf(r.size.x, 0.1), snappedf(r.size.y, 0.1)]


## Rectángulos en píxeles para medir ΔL*: la huella proyectada de cada edificio u objetivo, la ficha de cada agrupación y el suelo que los rodea.
func probes(camera: Camera3D) -> Array:
	var out: Array = []
	if not _cam_ok(camera) or buildings == null:
		return out
	for lm in buildings.landmarks:
		var id := str(lm.id)
		var type_name := str(lm.get("type", ""))
		if not (type_name in ["objetivo", "edificio", "torre"]) or (buildings.lm_nodes.has(id) and not (buildings.lm_nodes[id] as Node3D).visible):
			continue
		var top := float(lm.get("height_m", 0.0))
		if top <= 0.0:
			top = float(buildings.prop_spec(id, type_name).get("default_height_m", 3.0))
		var pts: Array = []
		for c in buildings.footprint_corners(buildings.footprint(lm)):
			pts.append(Vector3(c.x, _h(c.x, c.y), c.y))
			pts.append(Vector3(c.x, _h(c.x, c.y) + top, c.y))
		var building := _screen_rect(camera, pts)
		if building.size != Vector2.ZERO:
			out.append({"kind": "objetivo" if V.OBJECTIVES.has(id) else "edificio", "id": id, "rect": _rect_array(building)})
			out.append({"kind": "suelo", "id": id, "rect": _rect_array(building.grow(maxf(building.size.x, building.size.y) * 0.35))})
	for trio in _unit_ids_on_screen(camera):
		var h_px := float((units.tokens[trio[0]] as Dictionary).px)
		var token := Rect2((trio[1] as Vector2) - Vector2(h_px * 0.4, h_px), Vector2(h_px * 0.8, h_px))
		out.append({"kind": "ficha", "id": str(trio[0]), "rect": _rect_array(token)})
		out.append({"kind": "suelo", "id": str(trio[0]), "rect": _rect_array(token.grow(h_px * 0.6))})
	return out
