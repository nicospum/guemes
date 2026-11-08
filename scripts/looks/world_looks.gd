extends RefCounted
## Looks de luz y color del mundo 3D de los niveles I y III y del fondo del menú (pista P1, dirección de arte
## «Crónica en oro y noche», qa-equipo/arte/DIRECCION_DE_ARTE.md §2.3–2.4 y paquetes A1, A2, C1, C2).
## Solo cambia el Environment (copia nueva por look), el sol, el cielo y el material del relieve del Norte.
## world_view.gd lo llama desde set_look(); restaurar = volver a copiar el Environment base y el sol base.
## Las horas de luz son DISEÑO (no hay registro del cielo de esos días).

# ---- Paleta común (§2.1). Los HEX los comparten P1, P4 y P5.
const TINTA := Color("0e0c12")
const ORO_VIEJO := Color("c9a25e")
const ORO_LUZ := Color("e8cc8a")
const VIOLETA := Color("7a5bb5")
const PERGAMINO := Color("ece3cf")
const ROJO_REALISTA := Color("b8433a")
const ROJO_BORDE := Color("2a1414")
const AMBAR := Color("d9903a")
const CELESTE := Color("8db8d6")
const HUESO := Color("bfb6a3")

const LOOKS := ["menu", "justina", "norte"]

static var _grade_cache: Dictionary = {}

## Curva por canal (split-toning barato): sombras hacia violeta noche, medios neutros, luces hacia oro viejo.
## soft = curva cálida suave (juego del I): calienta las luces pero casi no toca los medios, para no comerse el verde del agua.
static func grade_texture(warm: bool, soft: bool = false) -> GradientTexture1D:
	var key := ("calida_suave" if soft else "calida") if warm else "fria"
	if _grade_cache.has(key):
		return _grade_cache[key]
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	if warm and soft:
		g.colors = PackedColorArray([Color(0.03, 0.022, 0.055), Color(0.50, 0.49, 0.475), Color(1.0, 0.965, 0.88)])
	elif warm:
		g.colors = PackedColorArray([Color(0.035, 0.025, 0.07), Color(0.50, 0.47, 0.45), Color(1.0, 0.95, 0.84)])
	else:
		g.colors = PackedColorArray([Color(0.03, 0.03, 0.08), Color(0.47, 0.48, 0.55), Color(0.98, 0.94, 0.86)])
	var t := GradientTexture1D.new()
	t.gradient = g
	t.width = 256
	_grade_cache[key] = t
	return t

## Copia del Environment base con cielo y material del cielo propios: cada look modifica su copia y nunca el original.
static func env_copy(base: Environment) -> Environment:
	var env: Environment = base.duplicate()
	if base.sky != null:
		var sky: Sky = base.sky.duplicate()
		if base.sky.sky_material != null:
			sky.sky_material = base.sky.sky_material.duplicate()
		env.sky = sky
	return env

static func _grade(env: Environment, contrast: float, sat: float, warm: bool = true, soft: bool = false) -> void:
	env.adjustment_enabled = true
	env.adjustment_contrast = contrast
	env.adjustment_saturation = sat
	env.adjustment_brightness = 1.0
	env.adjustment_color_correction = grade_texture(warm, soft)

static func _sky_params(env: Environment, p: Dictionary) -> void:
	if env.sky == null or not (env.sky.sky_material is ShaderMaterial):
		return
	var s := env.sky.sky_material as ShaderMaterial
	for k in p:
		s.set_shader_parameter(k, p[k])

## Viñeta (§2.4): un quad a pantalla completa en tinta, en una CanvasLayer de capa 0 (debajo de la interfaz). Costo despreciable.
static func make_vignette(strength: float) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = "VinetaLook"
	layer.layer = 0
	var rect := ColorRect.new()
	rect.name = "Vineta"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform float strength = 0.5;
uniform vec4 tint : source_color = vec4(0.03, 0.02, 0.05, 1.0);
void fragment(){
	vec2 uv = UV - 0.5;
	uv.x *= 1.25;
	COLOR = vec4(tint.rgb, smoothstep(0.38, 0.85, length(uv)) * strength);
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("strength", strength)
	rect.material = m
	layer.add_child(rect)
	return layer

## Fuerza de la viñeta por look (0 = sin viñeta): 0,5 en menú y Norte, 0,3 en juego del I.
static func vignette_strength(nombre: String) -> float:
	return {"menu": 0.5, "justina": 0.3, "norte": 0.45}.get(nombre, 0.0)

## El agua del I (shaders/water_rio_plata.gdshader) refleja un cielo propio: se iguala al cielo del look para que el río no
## quede con la bruma cremosa del mediodía bajo un atardecer. sun_dir lo pone world_view desde el sol del look.
static func water_params(nombre: String) -> Dictionary:
	match nombre:
		"menu": return {"sky_horizon": Color(0.98, 0.70, 0.42), "sky_zenith": Color(0.20, 0.21, 0.33)}
		# En juego la cámara mira casi cenital: el agua refleja sobre todo el cénit, que queda como el original (verde agrisado del
		# río) para no perder el contraste agua/orilla; solo el horizonte toma el oro de la tarde.
		"justina": return {"sky_horizon": Color(0.95, 0.82, 0.64), "sky_zenith": Color(0.50, 0.58, 0.62)}
	return {}

## fx = efectos de posproceso permitidos (Forward+/Mobile y calidad distinta de «baja», como hoy).
static func apply(nombre: String, env: Environment, sun: DirectionalLight3D, fx: bool) -> void:
	match nombre:
		"menu": _menu(env, sun, fx)
		"justina": _justina(env, sun, fx)
		"norte": _norte(env, sun, fx)

## A2 · Menú «heroico»: el buque a contraluz con el sol bajo del atardecer (11° de elevación).
static func _menu(env: Environment, sun: DirectionalLight3D, fx: bool) -> void:
	_sky_params(env, {"horizon_color": Color(0.98, 0.70, 0.42), "zenith_color": Color(0.14, 0.16, 0.28),
		"cloud_light": Color(1.0, 0.76, 0.52), "cloud_dark": Color(0.26, 0.20, 0.30), "below_color": Color(0.40, 0.30, 0.25)})
	if env.sky != null and env.sky.sky_material is ProceduralSkyMaterial:
		var ps := env.sky.sky_material as ProceduralSkyMaterial
		ps.sky_horizon_color = Color(0.98, 0.70, 0.42); ps.sky_top_color = Color(0.14, 0.16, 0.28); ps.ground_horizon_color = ps.sky_horizon_color
	env.fog_light_color = Color("d9925a")
	env.ambient_light_color = Color("8f86a6")
	env.ambient_light_energy = 0.42
	sun.light_color = Color("ffb36b")
	sun.light_energy = 1.6
	sun.rotation_degrees = Vector3(-11, 75, 0)
	if fx:
		env.glow_enabled = true
		env.glow_intensity = 0.7
		env.glow_bloom = 0.08
		env.glow_hdr_threshold = 0.95
		_grade(env, 1.12, 1.02)

## A1 · Tarde de invierno dorada en juego (26° de elevación). Sin bloom: el agua y las franjas del vado tienen que seguir leyéndose.
static func _justina(env: Environment, sun: DirectionalLight3D, fx: bool) -> void:
	_sky_params(env, {"horizon_color": Color(0.95, 0.80, 0.60), "zenith_color": Color(0.30, 0.36, 0.48),
		"cloud_light": Color(0.98, 0.86, 0.70), "cloud_dark": Color(0.40, 0.38, 0.46)})
	env.fog_light_color = Color("d8b48a")
	env.ambient_light_color = Color("bab3ba")
	env.ambient_light_energy = 0.6
	sun.light_color = Color("ffdab0")
	sun.light_energy = 1.1
	sun.rotation_degrees = Vector3(-26, -60, 0)
	if fx:
		env.glow_enabled = true
		env.glow_intensity = 0.6
		env.glow_bloom = 0.0
		env.glow_hdr_threshold = 0.95
		_grade(env, 1.08, 0.95, true, true)   # ronda 2: saturación 0,95 (la meseta ocre se iba a naranja en el oblicuo)

## C1 · Norte: relieve dorado sobre tinta. Sin cielo, niebla de profundidad oscura (world_view la ajusta a la distancia de cámara),
## sol rasante dorado (24°, rumbo -118°) y ambiente violáceo alto (0,8; la dirección pedía 0,6 y subirlo si una ficha se pierde en sombra: con 0,62 las figuras en ladera quedaban negras) para que ninguna ficha se pierda en una ladera en sombra.
static func _norte(env: Environment, sun: DirectionalLight3D, fx: bool) -> void:
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0c0a10")
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_density = 1.0
	env.fog_light_color = Color("15111a")
	env.fog_light_energy = 1.0
	env.fog_sky_affect = 1.0
	env.fog_depth_begin = 105.0
	env.fog_depth_end = 195.0
	env.fog_depth_curve = 1.6
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("6a6288")
	env.ambient_light_energy = 0.8
	env.volumetric_fog_enabled = false
	sun.light_color = Color("ffc282")
	sun.light_energy = 1.55
	sun.rotation_degrees = Vector3(-24, -118, 0)
	if fx:
		env.ssao_enabled = true
		env.ssao_intensity = 1.7
		env.glow_enabled = true
		env.glow_bloom = 0.0
		env.glow_hdr_threshold = 1.0
		_grade(env, 1.12, 1.0)
