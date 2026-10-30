shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;
#include "res://shaders/justina_noise.gdshaderinc"
// R6: arena y fango alrededor del casco apoyado, con borde irregular (ruido) y transicion suave: ya no es un disco de borde circular.
uniform vec3 sand : source_color = vec3(0.50, 0.43, 0.30);
uniform vec3 wet : source_color = vec3(0.36, 0.32, 0.23);
uniform float strength = 0.0;
uniform vec2 half_size = vec2(34.0, 40.0);
varying vec3 wp;
varying vec2 loc;
void vertex(){
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	loc = VERTEX.xz / half_size;
}
void fragment(){
	float r = length(loc);
	float n = j_fbm2(wp.xz * 0.11) * 0.55 + j_noise(wp.xz * 0.45) * 0.2 + j_noise(wp.xz * 0.04) * 0.25;
	float edge = 0.86 - (n - 0.5) * 0.85;
	float m = 1.0 - smoothstep(edge - 0.30, edge + 0.04, r);
	float ripple = 0.5 + 0.5 * sin((wp.x * 0.7 + wp.z * 0.35) + n * 9.0);
	ALBEDO = mix(sand, wet, smoothstep(0.35, 0.95, r) * 0.7 + ripple * 0.06);
	ALPHA = m * strength * (0.82 - 0.2 * smoothstep(0.5, 1.0, r));
}
