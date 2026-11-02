// Ruido del nivel «Humahuaca» (pista visual). PROCEDENCIA: copia de shaders/justina_noise.gdshaderinc (Justina, ronda 4: hash sin seno, estable con
// coordenadas de mundo de hasta ~8000 m), con las funciones renombradas de j_ a hx_. Se copia y no se incluye a propósito (CONTRATO 1.3): si alguien arregla
// el ruido de la Justina, el aspecto del nivel 2 no debe cambiar en silencio. Lo que sigue a hx_fbm3 (celdas, conversión de color) es propio del nivel.
float hx_hash(vec2 p){
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float hx_noise(vec2 p){
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hx_hash(i), hx_hash(i + vec2(1.0, 0.0)), f.x), mix(hx_hash(i + vec2(0.0, 1.0)), hx_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
vec2 hx_rot(vec2 p, float a){
	float c = cos(a);
	float s = sin(a);
	return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}
float hx_fbm(vec2 p){
	float a = 0.5;
	float t = 0.0;
	for (int i = 0; i < 4; i++) {
		t += a * hx_noise(p);
		p = hx_rot(p, 0.55) * 2.03 + vec2(17.3, 9.1);
		a *= 0.5;
	}
	return t / 0.9375;
}
float hx_fbm2(vec2 p){
	return (0.6 * hx_noise(p) + 0.4 * hx_noise(hx_rot(p, 0.55) * 2.03 + vec2(17.3, 9.1)));
}
float hx_fbm3(vec2 p){
	float a = 0.57 * hx_noise(p);
	p = hx_rot(p, 0.55) * 2.03 + vec2(17.3, 9.1);
	a += 0.29 * hx_noise(p);
	p = hx_rot(p, 0.55) * 2.03 + vec2(17.3, 9.1);
	return a + 0.14 * hx_noise(p);
}

// --- Propio del nivel 2 -----------------------------------------------------------------------------------------------------------------------------------

// Distancia al punto más cercano de una grilla de puntos al azar (Worley, F1): piedras sueltas, arbustos y grietas del suelo.
float hx_cells(vec2 p){
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = vec2(hx_hash(i + g), hx_hash(i + g + vec2(31.7, 12.3)));
			d = min(d, length(g + o - f));
		}
	}
	return d;
}

// Ruido de crestas (0 en los pliegues, 1 en la cresta): barrancas, estratos y cárcavas de los cerros.
float hx_ridge(vec2 p){
	float n = hx_fbm2(p);
	return 1.0 - abs(n * 2.0 - 1.0);
}

// Conversión de sRGB (como están los colores de vértice de la paleta) a lineal, la que espera ALBEDO.
vec3 hx_lin(vec3 c){
	return mix(c / 12.92, pow((c + vec3(0.055)) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}
