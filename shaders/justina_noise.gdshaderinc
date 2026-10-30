// Ruido compartido de Justina (ronda 4). Hash sin seno: estable con coordenadas de mundo grandes (hasta ~5000 m).
float j_hash(vec2 p){
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float j_noise(vec2 p){
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(j_hash(i), j_hash(i + vec2(1.0, 0.0)), f.x), mix(j_hash(i + vec2(0.0, 1.0)), j_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
vec2 j_rot(vec2 p, float a){
	float c = cos(a);
	float s = sin(a);
	return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}
float j_fbm(vec2 p){
	float a = 0.5;
	float t = 0.0;
	for (int i = 0; i < 4; i++) {
		t += a * j_noise(p);
		p = j_rot(p, 0.55) * 2.03 + vec2(17.3, 9.1);
		a *= 0.5;
	}
	return t / 0.9375;
}
float j_fbm2(vec2 p){
	return (0.6 * j_noise(p) + 0.4 * j_noise(j_rot(p, 0.55) * 2.03 + vec2(17.3, 9.1)));
}
float j_fbm3(vec2 p){
	float a = 0.57 * j_noise(p);
	p = j_rot(p, 0.55) * 2.03 + vec2(17.3, 9.1);
	a += 0.29 * j_noise(p);
	p = j_rot(p, 0.55) * 2.03 + vec2(17.3, 9.1);
	return a + 0.14 * j_noise(p);
}
