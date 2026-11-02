shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;
#include "res://shaders/humahuaca_noise.gdshaderinc"
// Agua del Río Grande (pista visual): turbia y opaca, sin degradé de profundidad (CONTRATO 11.1: «agua turbia», un solo color de la paleta), con hebras largas
// que siguen la corriente (UV.x = metros a lo largo del cauce, UV.y = −1 a 1 de orilla a orilla), una orilla más clara donde el agua es poco profunda y
// anillitos de lluvia. Aspecto reconstruido: el cauce de 1817 y el caudal son sin datos.
uniform vec3 pal_agua : source_color = vec3(0.549, 0.608, 0.569);
uniform vec3 pal_orilla : source_color = vec3(0.808, 0.761, 0.655);
uniform float rain : hint_range(0.0, 1.0) = 0.0;
uniform float albedo_mode = 0.0;
uniform float flow_speed = 1.1;

void fragment(){
	float across = abs(UV.y);
	vec2 q = vec2(UV.x * 0.22 - TIME * flow_speed * 0.22, UV.y * 2.6);
	float strands = hx_fbm2(q * vec2(1.0, 2.2));
	float ripples = hx_noise(vec2(UV.x * 0.9 - TIME * flow_speed * 0.8, UV.y * 7.0));
	vec3 c = pal_agua * (0.86 + 0.24 * strands) * (0.96 + 0.08 * ripples);
	float shore = smoothstep(0.62, 0.98, across + (hx_noise(vec2(UV.x * 0.35, 4.0)) - 0.5) * 0.25);
	c = mix(c, pal_orilla, shore * 0.5);
	vec2 cell_p = vec2(UV.x * 0.8, UV.y * 4.0) + vec2(TIME * 0.4, 0.0);
	float ring = smoothstep(0.34, 0.28, abs(hx_cells(cell_p * 1.7) - 0.3)) * rain * 0.18;
	c += vec3(ring);
	if (albedo_mode > 0.5) {
		ALBEDO = vec3(0.0);
		EMISSION = pal_agua;
		ROUGHNESS = 1.0;
		SPECULAR = 0.0;
	} else {
		ALBEDO = c;
		ROUGHNESS = mix(0.32, 0.22, rain);
		SPECULAR = 0.5;
		METALLIC = 0.0;
	}
}
