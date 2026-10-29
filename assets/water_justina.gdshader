shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, shadows_disabled, specular_schlick_ggx;
// Agua turbia del Plata (Justina). El color NO depende de la profundidad: solo se ve el suelo a menos de
// visible_depth_m (0,3 m) de la superficie, que es lo que Reglas llama "visible". Mas abajo es opaca y uniforme.
// UV.x trae la altura REAL del suelo (m sobre el cero de bajante) solo para calcular ese halo y la espuma de contacto.
uniform float water_level = 1.65;
uniform float visible_depth_m = 0.3;
uniform vec3 water_color : source_color = vec3(0.34, 0.35, 0.26);
uniform vec3 sky_tint : source_color = vec3(0.72, 0.70, 0.60);
uniform vec3 shallow_color : source_color = vec3(0.60, 0.52, 0.36);
varying vec3 world_pos;
varying float ground;
void vertex(){
 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
 ground = UV.x;
 VERTEX.y += sin(world_pos.x * 0.9 + TIME * 0.9) * 0.012 + sin(world_pos.z * 1.3 + TIME * 1.3) * 0.010;
}
void fragment(){
 float depth = water_level - ground;
 float wave = sin(world_pos.x * 0.22 + sin(world_pos.z * 0.07) * 1.6 + world_pos.z * 0.05 + TIME * 0.8);
 float ripple = sin(world_pos.z * 0.31 + sin(world_pos.x * 0.12) - world_pos.x * 0.06 + TIME * 0.6);
 float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
 vec3 col = water_color + vec3((wave + ripple) * 0.012) + sky_tint * fres * 0.22;
 float halo = 1.0 - smoothstep(0.0, visible_depth_m, depth);
 col = mix(col, shallow_color, halo * 0.75);
 float streak = 0.5 + 0.5 * sin(world_pos.x * 1.1 + world_pos.z * 0.9 + TIME * 1.2 + wave * 1.5);
 float foam = (1.0 - smoothstep(0.0, 0.14, depth)) * (0.55 + 0.45 * streak);
 col = mix(col, vec3(0.86, 0.85, 0.78), clamp(foam, 0.0, 1.0));
 ALBEDO = col;
 METALLIC = 0.0;
 ROUGHNESS = mix(0.22, 0.7, foam);
 SPECULAR = 0.4;
 float a = mix(0.99, 0.55, halo);
 a = mix(a, 0.9, foam * 0.6);
 ALPHA = depth < -0.06 ? 0.0 : a;
}
