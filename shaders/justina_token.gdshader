shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_test_disabled, shadows_disabled, skip_vertex_transform;
// Ficha de lectura de un grupo o del buque (ronda visual 2): tamaño FIJO en pantalla (px) sin importar la distancia,
// disco del color del bando con borde oscuro y un glifo blanco por rol. Aparece al alejar la camara (fade_a..fade_b m)
// para que las unidades se lean sin depender de carteles. Es un simbolo del juego, no un estandarte historico.
uniform vec4 tint : source_color = vec4(0.9, 0.75, 0.4, 1.0);
uniform float size_px = 34.0;
uniform int shape = 0;            // 0 caballeria (rombo + lanza), 1 voluntarios (triangulo), 2 reserva (rombo hueco), 3 explorador (punto), 4 buque
uniform float fade_a = 55.0;
uniform float fade_b = 120.0;
uniform float pulse = 0.0;
uniform float drop_px = 0.0;     // desplazamiento hacia abajo en pantalla (px): la ficha queda debajo de los carteles del grupo        // 1 = aro que late (objetivo)
varying float v_d;

void vertex(){
	vec4 c = MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0);
	vec3 cv = (VIEW_MATRIX * c).xyz;
	float d = max(-cv.z, 0.5);
	float wpp = 2.0 / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);   // por unidad de profundidad
	cv.xy += VERTEX.xy * size_px * wpp * d;
	cv.y -= drop_px * wpp * d;
	v_d = d;
	POSITION = PROJECTION_MATRIX * vec4(cv, 1.0);
}

float sd_tri(vec2 p){   // triangulo apuntando arriba
	p.y += 0.05;
	float h = clamp((0.46 - p.y) / 0.88, 0.0, 1.0);
	float inside = step(abs(p.x), 0.52 * h) * step(-0.42, p.y) * step(p.y, 0.46);
	return inside;
}

float seg(vec2 p, vec2 a, vec2 b, float w){
	vec2 pa = p - a; vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return 1.0 - smoothstep(w - 0.02, w + 0.02, length(pa - ba * h));
}
float blob(vec2 p, vec2 c, vec2 r){
	return 1.0 - smoothstep(0.92, 1.06, length((p - c) / r));
}
// D4: siluetas legibles. Jinete (caballo + jinete con lanza) e infante (figura con fusil y chambergo), mirando a la derecha.
float rider_sil(vec2 q){
	float g = blob(q, vec2(-0.02, -0.12), vec2(0.40, 0.17));
	g = max(g, seg(q, vec2(0.28, -0.06), vec2(0.42, 0.16), 0.075));
	g = max(g, seg(q, vec2(0.42, 0.16), vec2(0.56, 0.06), 0.06));
	g = max(g, seg(q, vec2(-0.26, -0.20), vec2(-0.30, -0.52), 0.045));
	g = max(g, seg(q, vec2(-0.12, -0.22), vec2(-0.10, -0.52), 0.045));
	g = max(g, seg(q, vec2(0.14, -0.22), vec2(0.18, -0.52), 0.045));
	g = max(g, seg(q, vec2(0.27, -0.20), vec2(0.34, -0.50), 0.045));
	g = max(g, seg(q, vec2(-0.38, -0.06), vec2(-0.50, -0.30), 0.04));
	g = max(g, seg(q, vec2(0.0, 0.02), vec2(0.03, 0.30), 0.095));
	g = max(g, blob(q, vec2(0.04, 0.43), vec2(0.085, 0.085)));
	g = max(g, seg(q, vec2(0.10, -0.02), vec2(0.24, 0.70), 0.028));
	return g;
}
float foot_sil(vec2 q){
	float g = seg(q, vec2(-0.07, -0.16), vec2(-0.13, -0.58), 0.06);
	g = max(g, seg(q, vec2(0.07, -0.16), vec2(0.13, -0.58), 0.06));
	g = max(g, seg(q, vec2(0.0, -0.20), vec2(0.0, 0.20), 0.13));
	g = max(g, blob(q, vec2(0.0, 0.31), vec2(0.095, 0.095)));
	g = max(g, seg(q, vec2(0.0, 0.40), vec2(0.0, 0.50), 0.10));
	g = max(g, seg(q, vec2(0.10, -0.12), vec2(0.26, 0.62), 0.03));
	return g;
}

void fragment(){
	vec2 p = (UV - 0.5) * vec2(2.0, 2.0);   // D4: UV.y crece hacia arriba en pantalla con este quad (antes los glifos salian invertidos)
	float r = length(p);
	float fade = smoothstep(fade_a, fade_b, v_d);
	float tshape = shape == 3 ? 0.78 : 1.0;
	float disc = 1.0 - smoothstep(0.90, 0.97, r / tshape);
	float inner = 1.0 - smoothstep(0.74, 0.80, r / tshape);
	vec3 col = mix(vec3(0.07, 0.08, 0.07), tint.rgb, inner);
	float g = 0.0;
	vec2 q = p / tshape;
	float sil = 0.0;
	if (shape == 0) {
		g = rider_sil(q * 1.18);
		sil = 1.0;
	} else if (shape == 1) {
		g = foot_sil(q * 1.18);
		sil = 1.0;
	} else if (shape == 2) {
		g = max(foot_sil((q - vec2(-0.30, -0.06)) * 1.9), foot_sil((q - vec2(0.30, -0.06)) * 1.9));
		sil = 1.0;
	} else if (shape == 3) {
		g = step(length(q), 0.40);
	} else {
		// buque: casco (cuenco), mastil y dos velas
		float hull = step(q.y, -0.22) * step(-0.52, q.y) * step(abs(q.x), 0.62 + (q.y + 0.22) * 0.8);
		float mast = step(abs(q.x), 0.05) * step(-0.25, q.y) * step(q.y, 0.66);
		float s1 = step(q.x, 0.50) * step(0.06, q.x) * step(q.y, 0.52 - q.x * 0.9) * step(-0.18, q.y);
		float s2 = step(q.x, -0.06) * step(-0.50, q.x) * step(q.y, 0.40 + q.x * 0.8) * step(-0.18, q.y);
		g = max(max(hull, mast), max(s1, s2));
	}
	col = mix(col, mix(vec3(0.97, 0.94, 0.84), vec3(0.08, 0.06, 0.05), sil), g * inner);
	float a = disc;
	if (pulse > 0.5) {
		float ph = fract(TIME * 0.8);
		float ring = (1.0 - smoothstep(0.0, 0.05, abs(r - (1.0 + ph * 0.55)))) * (1.0 - ph);
		col = mix(col, tint.rgb, ring);
		a = max(a, ring * 0.0 + 0.0);
	}
	ALBEDO = col;
	ALPHA = a * fade * 0.97;
}
