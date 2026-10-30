shader_type spatial;
render_mode cull_back;
#include "res://shaders/justina_noise.gdshaderinc"
// Props de Justina (ronda 3): material comun de los lotes de cajas, cilindros y esferas (muros del circo, casas de azotea, bateria,
// matas, juncos). Color base = color por instancia (sRGB). Encima, en coordenadas de mundo: manchas de revoque envejecido, vetas de
// lluvia, juntas de ladrillo/adobe en los muros claros y hileras de teja en los techos rojizos, y oscurecido hacia el suelo.
// Es ASPECTO RECONSTRUIDO (Vidal 1820 y Boneo 1801 no dan textura); la paleta es la del paquete (Lino crudo, Arena, teja apagada).
varying vec3 w_pos;
varying vec3 w_nrm;
varying vec3 l_pos;

void vertex(){
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	l_pos = VERTEX;
}

vec3 s2l(vec3 c){
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, vec3(lessThan(c, vec3(0.04045))));
}

void fragment(){
	vec3 c = COLOR.rgb;
	float lum = dot(c, vec3(0.33, 0.34, 0.33));
	bool wall_c = lum > 0.62 && abs(c.r - c.b) < 0.28;
	bool roof_c = c.r > 0.5 && c.r > c.g * 1.35 && c.g < 0.42;
	float vert = 1.0 - smoothstep(0.35, 0.7, abs(w_nrm.y));
	vec2 p = w_pos.xz;
	float k = 1.0;
	vec3 tint = vec3(1.0);
	if (wall_c && vert > 0.5) {
		float along = abs(w_nrm.x) > abs(w_nrm.z) ? w_pos.z : w_pos.x;
		float mott = j_fbm2(vec2(along, w_pos.y) * 0.9 + vec2(p.x * 0.01, 7.0));
		k *= 0.86 + 0.26 * mott;
		float streak = j_noise(vec2(along * 1.6, w_pos.y * 0.12));
		k *= 1.0 - 0.18 * smoothstep(0.55, 0.9, streak);
		// zocalo humedo y sucio (primer metro y medio de muro)
		// adobe/ladrillo asomando en parches desconchados
		float patch_ = smoothstep(0.66, 0.74, j_fbm2(vec2(along, w_pos.y) * 0.55 + 21.0));
		tint = mix(tint, vec3(1.05, 0.78, 0.62), patch_ * 0.65);
		float course = fract(w_pos.y / 0.32);
		float joint = (1.0 - smoothstep(0.0, 0.07, course)) * patch_;
		k *= 1.0 - 0.28 * joint;
	} else if (roof_c) {
		float rib = abs(fract((abs(w_nrm.y) > 0.5 ? w_pos.x : w_pos.z) * 1.6) - 0.5);
		k *= 0.86 + 0.28 * smoothstep(0.1, 0.5, rib);
		k *= 0.88 + 0.24 * j_noise(p * 0.7);
	} else {
		k *= 0.90 + 0.20 * j_fbm2(p * 0.9 + w_pos.y * 0.6);
	}
	ALBEDO = s2l(c) * tint * k;
	ROUGHNESS = 0.9;
}
