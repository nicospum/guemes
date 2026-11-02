shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform;
#include "res://shaders/humahuaca_noise.gdshaderinc"
// Lluvia del nivel «Humahuaca» (pista visual): rayas dibujadas en el espacio de la cámara, así que cubren la pantalla desde cualquier distancia (a 470 m
// una raya de 1,8 m no se vería; acá cada raya mide de 12 a 26 píxeles de alto) y respetan la profundidad del terreno y la niebla. Es un MultiMesh de cuadritos
// y no tiene costo de CPU por cuadro: la posición de cada raya sale de su número de instancia y del tiempo. Cuantas más rayas se ven, más llueve (`rain` 0..1).
uniform vec3 streak_color : source_color = vec3(0.549, 0.608, 0.569);
uniform float rain : hint_range(0.0, 1.0) = 0.0;
uniform float streak_alpha = 0.34;
uniform float near_m = 14.0;
uniform float far_m = 700.0;
uniform float fall_speed = 20.0;     // m/s en el mundo; en pantalla se achica con la distancia
uniform float slant = 0.18;          // viento: inclinación de las rayas (radianes)
uniform float len_px = 22.0;
uniform float width_px = 1.4;

varying float v_alpha;

void vertex(){
	float id = float(INSTANCE_ID);
	vec3 h = vec3(hx_hash(vec2(id, 1.7)), hx_hash(vec2(id, 4.1)), hx_hash(vec2(id, 9.3)));
	float keep = step(hx_hash(vec2(id, 21.9)), rain);                     // solo llueven las rayas de abajo del umbral
	float depth = mix(near_m, far_m, h.z * h.z * h.z);                    // más rayas cerca que lejos
	float fall = fract(h.y - TIME * fall_speed / (depth * 0.9 + 6.0) * 0.5);
	float half_h = 1.0 / PROJECTION_MATRIX[1][1];
	float half_w = 1.0 / PROJECTION_MATRIX[0][0];
	vec3 center = vec3((h.x * 2.0 - 1.0) * half_w * depth, (fall * 2.0 - 1.0) * half_h * depth, -depth);
	float unit_per_px = 2.0 * half_h * depth / max(VIEWPORT_SIZE.y, 1.0);
	float s = sin(slant);
	float c = cos(slant);
	vec2 q = vec2(VERTEX.x * width_px, VERTEX.y * len_px * (0.7 + 0.6 * h.x)) * unit_per_px;
	vec2 rot = vec2(c * q.x - s * q.y, s * q.x + c * q.y);
	vec4 view_pos = vec4(center + vec3(rot, 0.0), 1.0);
	VERTEX = view_pos.xyz;
	POSITION = PROJECTION_MATRIX * view_pos;
	v_alpha = keep * streak_alpha * (0.45 + 0.55 * h.x) * (1.0 - smoothstep(0.55, 1.0, depth / far_m) * 0.6);
}

void fragment(){
	ALBEDO = streak_color;
	ALPHA = v_alpha * (1.0 - abs(UV.x - 0.5) * 1.6) * (0.35 + 0.65 * smoothstep(0.0, 0.5, 0.5 - abs(UV.y - 0.5)) * 2.0);
}
