shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/humahuaca_noise.gdshaderinc"
// Suelo del nivel «Humahuaca» (pista visual): UN solo shader para la ventana jugable, el contexto y el horizonte, así que no hay una «parte definida y después
// todo genérico»: el mismo suelo sigue hasta los cerros. Color por capa de superficie (grava, sedimento húmedo, piedra, churqui, regadío, agua, camino, zanja)
// con ruido a tres escalas y piedritas, curvas de nivel sutiles (cada 5 m, más marcadas cada 20), estratos claros en las pendientes fuertes de los cerros,
// y el efecto de la lluvia (suelo ×0,75 más oscuro, más liso y con charcos). Todos los colores llegan por uniformes de la paleta (ids del JSON), sin HEX sueltos.
// Pesos de capa dentro de la ventana: splat_a = (suelo seco, sedimento húmedo, piedra, churqui) y splat_b = (regadío, agua, camino o patio, zanja), un texel por nodo
// de 4 m; fuera de la ventana salen de la pendiente, la altura y la cercanía al río (ctx_tex.r). Los colores son aspecto reconstruido, no medición de 1817.
uniform sampler2D splat_a : filter_linear, repeat_disable, hint_default_black;
uniform sampler2D splat_b : filter_linear, repeat_disable, hint_default_black;
uniform sampler2D ctx_tex : filter_linear, repeat_disable, hint_default_black;
uniform vec4 win_rect = vec4(0.0, 0.0, 900.0, 652.0);     // x0, z0, ancho, alto de la ventana (m)
uniform vec4 ctx_rect = vec4(-1350.0, -1025.0, 3600.0, 2700.0);

uniform vec3 pal_suelo : source_color = vec3(0.725, 0.604, 0.447);
uniform vec3 pal_sedimento : source_color = vec3(0.467, 0.384, 0.282);
uniform vec3 pal_piedra : source_color = vec3(0.557, 0.545, 0.506);
uniform vec3 pal_churqui : source_color = vec3(0.427, 0.463, 0.325);
uniform vec3 pal_irrigada : source_color = vec3(0.412, 0.475, 0.294);
uniform vec3 pal_agua : source_color = vec3(0.549, 0.608, 0.569);
uniform vec3 pal_adobe : source_color = vec3(0.769, 0.667, 0.510);
uniform vec3 pal_lana : source_color = vec3(0.808, 0.761, 0.655);

uniform float rain : hint_range(0.0, 1.0) = 0.0;
uniform float warmth : hint_range(0.0, 1.0) = 0.0;  // ronda 3: cuánto se corre la tierra hacia ocre y siena (1 de noche, poco de día: lights.<hora>.ground_warmth)
uniform float wet_darken = 0.75;
uniform float wet_rough = 0.5;
uniform float albedo_mode = 0.0;     // 1 = render de albedo para la métrica de paleta (QA): el color plano de la paleta, sin luz
uniform float detail = 1.0;          // 1 = calidad media y alta; 0,6 = baja (menos ruido por píxel)
uniform float contour_m = 5.0;
uniform float contour_alpha = 0.09;
uniform float datum_m = 2940.0;
// visual/r1 F5: texturas fotográficas CC0 (Poly Haven, assets/terrain/humahuaca) en dos arreglos de seis capas, en el orden de TERRAIN_TEXTURES (humahuaca_gfx.gd):
// 0 grava del suelo, 1 ladera pedregosa, 2 cantos del cauce, 3 roca de barranca, 4 pasto seco, 5 tierra de andenes. tex_data lleva la normal (0-5, OpenGL),
// el ORM (6-11) y la altura (12-17). La textura NO pone el color: aporta el grano (luminancia relativa a su media) sobre el color de la paleta de siempre,
// con un poco de su croma; de 110 a 200 m de la cámara se apaga y queda el suelo de solo paleta. En el render de albedo no participa.
uniform sampler2DArray tex_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray tex_data : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tex_on = 0.0;            // 1 en media y alta con los archivos cargados; 0 en baja (sin muestras)
uniform float tex_near_m = 110.0;
uniform float tex_far_m = 200.0;
uniform float tex_chroma = 0.28;       // cuánto del color propio de la foto pasa (el resto es la paleta)
uniform float tex_normal = 1.0;
const float TEX_TILE[6] = {2.6, 3.0, 2.8, 6.0, 2.4, 2.8};   // metros por repetición de cada material

varying vec3 wpos;
varying vec3 wnrm;
varying float vdist;

void vertex(){
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vdist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

// visual/r1 F5: una capa con variación anti-repetición (dos desfases por celda de un ruido lento, mezclados según el contraste: técnica de Quilez). Los mismos
// desfases y la misma mezcla para los cuatro mapas; gradientes explícitos para que el salto de desfase no marque costuras en los mipmaps.
void tex_layer(float layer, vec2 uv, vec2 dx, vec2 dy, float kn, out vec3 alb, out vec3 nrm, out vec2 orm, out float hgt){
	float k = kn * 8.0;
	float i = floor(k);
	float f = fract(k);
	vec2 oa = fract(sin(vec2(3.1, 7.7) * i + layer) * 43.7);
	vec2 ob = fract(sin(vec2(3.1, 7.7) * (i + 1.0) + layer) * 43.7);
	vec3 a = textureGrad(tex_albedo, vec3(uv + oa, layer), dx, dy).rgb;
	vec3 b = textureGrad(tex_albedo, vec3(uv + ob, layer), dx, dy).rgb;
	float t = smoothstep(0.2, 0.8, f - 0.1 * dot(a - b, vec3(1.0)));
	alb = mix(a, b, t);
	nrm = mix(textureGrad(tex_data, vec3(uv + oa, layer), dx, dy).rgb, textureGrad(tex_data, vec3(uv + ob, layer), dx, dy).rgb, t) * 2.0 - 1.0;
	orm = mix(textureGrad(tex_data, vec3(uv + oa, layer + 6.0), dx, dy).rg, textureGrad(tex_data, vec3(uv + ob, layer + 6.0), dx, dy).rg, t);
	hgt = mix(textureGrad(tex_data, vec3(uv + oa, layer + 12.0), dx, dy).r, textureGrad(tex_data, vec3(uv + ob, layer + 12.0), dx, dy).r, t);
}

// visual/r1 F5: la roca de barranca va triplanar (sin estirarse en las paredes); una muestra por proyección y normales por «whiteout».
void tex_rock(vec3 wp, vec3 wn, float kn, vec3 dpx, vec3 dpy, out vec3 alb, out vec3 nrm, out vec2 orm, out float hgt){
	vec3 bw = pow(abs(wn), vec3(4.0));
	bw /= max(bw.x + bw.y + bw.z, 0.0001);
	float tile = 1.0 / TEX_TILE[3];
	vec2 ux = wp.zy * tile; vec2 uy = wp.xz * tile; vec2 uz = wp.xy * tile;
	vec3 ax = textureGrad(tex_albedo, vec3(ux, 3.0), dpx.zy * tile, dpy.zy * tile).rgb;
	vec3 ay = textureGrad(tex_albedo, vec3(uy, 3.0), dpx.xz * tile, dpy.xz * tile).rgb;
	vec3 az = textureGrad(tex_albedo, vec3(uz, 3.0), dpx.xy * tile, dpy.xy * tile).rgb;
	alb = ax * bw.x + ay * bw.y + az * bw.z;
	vec3 nx = textureGrad(tex_data, vec3(ux, 3.0), dpx.zy * tile, dpy.zy * tile).rgb * 2.0 - 1.0;
	vec3 ny = textureGrad(tex_data, vec3(uy, 3.0), dpx.xz * tile, dpy.xz * tile).rgb * 2.0 - 1.0;
	vec3 nz = textureGrad(tex_data, vec3(uz, 3.0), dpx.xy * tile, dpy.xy * tile).rgb * 2.0 - 1.0;
	nx = vec3(nx.xy * tex_normal + wn.zy, abs(nx.z) * wn.x);
	ny = vec3(vec2(ny.x, -ny.y) * tex_normal + wn.xz, abs(ny.z) * wn.y);
	nz = vec3(nz.xy * tex_normal + wn.xy, abs(nz.z) * wn.z);
	nrm = normalize(nx.zyx * bw.x + ny.xzy * bw.y + nz.xyz * bw.z);
	vec4 o = textureGrad(tex_data, vec3(ux, 9.0), dpx.zy * tile, dpy.zy * tile) * bw.x + textureGrad(tex_data, vec3(uy, 9.0), dpx.xz * tile, dpy.xz * tile) * bw.y
		+ textureGrad(tex_data, vec3(uz, 9.0), dpx.xy * tile, dpy.xy * tile) * bw.z;
	orm = o.rg;
	hgt = textureGrad(tex_data, vec3(uy, 15.0), dpx.xz * tile, dpy.xz * tile).r;
}

void fragment(){
	vec2 p = wpos.xz;
	float near_k = (1.0 - smoothstep(30.0, 320.0, vdist)) * detail;
	float bump_k = (1.0 - smoothstep(12.0, 130.0, vdist)) * detail;
	float mid_k = 1.0 - smoothstep(200.0, 1600.0, vdist);
	float slope = 1.0 - clamp(wnrm.y, 0.0, 1.0);        // 0 llano; ≈ 0,03 a 14°; ≈ 0,3 a 45°
	float asl = wpos.y;

	// --- pesos de capa -------------------------------------------------------------------------------------------------------------------------
	vec2 warp = (vec2(hx_noise(p * 0.07), hx_noise(p * 0.07 + 7.3)) - 0.5) * 9.0;       // el borde de cada capa es irregular, no cuadriculado
	vec2 wuv = (p + warp - win_rect.xy) / win_rect.zw;
	float edge = min(min(wuv.x, 1.0 - wuv.x) * win_rect.z, min(wuv.y, 1.0 - wuv.y) * win_rect.w);
	float in_w = smoothstep(0.0, 26.0, edge);
	vec4 sa = texture(splat_a, clamp(wuv, vec2(0.0), vec2(1.0)));
	vec4 sb = texture(splat_b, clamp(wuv, vec2(0.0), vec2(1.0)));
	vec2 cuv = (p - ctx_rect.xy) / ctx_rect.zw;
	float in_ctx = step(0.0, cuv.x) * step(cuv.x, 1.0) * step(0.0, cuv.y) * step(cuv.y, 1.0);
	float river = texture(ctx_tex, clamp(cuv, vec2(0.0), vec2(1.0))).r * in_ctx;
	float steep = smoothstep(0.10, 0.30, slope);                                          // cerros: roca y estratos
	float hill = smoothstep(0.025, 0.10, slope) * (1.0 - steep);                          // laderas medias: churcal
	float w_piedra_c = steep + smoothstep(0.86, 0.97, river) * 0.9;
	float w_sed_c = smoothstep(0.62, 0.86, river) * (1.0 - w_piedra_c);
	float w_irr_c = smoothstep(0.18, 0.45, river) * (1.0 - smoothstep(0.55, 0.8, river)) * (1.0 - steep);
	float w_chu_c = hill * (1.0 - w_irr_c) * 0.85;
	float ctx_sum = w_sed_c + w_piedra_c + w_chu_c + w_irr_c;
	float w_suelo = mix(clamp(1.0 - ctx_sum, 0.0, 1.0), sa.x, in_w);
	float w_sed = mix(w_sed_c, sa.y + sb.w * 0.7, in_w);
	float w_piedra = mix(w_piedra_c, sa.z, in_w);
	float w_chu = mix(w_chu_c, sa.w, in_w);
	float w_irr = mix(w_irr_c, sb.x, in_w);
	float w_agua = sb.y * in_w;
	float w_cam = sb.z * in_w;
	float w_zanja = sb.w * in_w;

	// --- ruido: tres escalas y grano --------------------------------------------------------------------------------------------------------------
	float big = hx_fbm3(p * 0.0035 + 2.0);
	float mid = hx_fbm2(p * 0.034 + 11.0);
	float fine = mix(0.5, hx_noise(p * 1.9), near_k);
	float micro = mix(0.5, hx_noise(p * 8.3), near_k * near_k);
	float cell = hx_cells(p * 2.3);
	float stones = (1.0 - smoothstep(0.06, 0.24, cell)) * near_k;
	float stone_tone = hx_hash(floor(p * 2.3 + 0.5));

	// --- color base por capa ----------------------------------------------------------------------------------------------------------------------
	// manchas de grava de borde neto (de ≈ 20 a 80 m, estiradas como terrazas de erosión): ningún tramo de suelo queda liso a ninguna distancia de juego
	vec2 tq = hx_rot(p, 0.35) * vec2(0.014, 0.026);
	float terrace = smoothstep(0.43, 0.55, hx_fbm2(tq + 4.0)) - smoothstep(0.60, 0.72, hx_fbm2(tq * 1.9 + 21.0));
	float speck = smoothstep(0.46, 0.56, hx_fbm2(p * 0.085 + 13.0));
	vec3 c_suelo = pal_suelo * (0.74 + 0.34 * big + 0.22 * mid) * (0.95 + 0.10 * fine) * (0.90 + 0.18 * terrace) * (0.94 + 0.10 * speck);
	// manchones de tierra húmeda y pastos secos de decenas a cientos de metros (P2): el suelo deja de ser un plano lavado de un solo tono a la distancia de juego
	float damp = smoothstep(0.52, 0.74, hx_fbm2(p * 0.0062 + 17.0));
	float straw = smoothstep(0.58, 0.78, hx_fbm2(hx_rot(p, 0.8) * vec2(0.011, 0.02) + 41.0));
	c_suelo = mix(c_suelo, pal_sedimento * (0.85 + 0.2 * mid), damp * 0.5);
	c_suelo = mix(c_suelo, mix(pal_churqui, pal_lana, 0.35) * (0.8 + 0.25 * mid), straw * 0.32 * (1.0 - damp));
	vec3 warm_k = mix(vec3(1.0), vec3(1.07, 0.95, 0.80), warmth);  // la tierra de la quebrada es ocre y rojiza; con la luna fría el beige se leía gris verdoso
	c_suelo *= warm_k;
	c_suelo = mix(c_suelo, pal_piedra * (0.95 + 0.25 * stone_tone), stones * 0.3);                   // piedritas sueltas sobre la grava
	vec3 c_sed = pal_sedimento * mix(vec3(1.0), vec3(1.06, 0.95, 0.84), warmth) * (0.84 + 0.3 * mid) * (0.96 + 0.08 * fine);
	float crack = smoothstep(0.10, 0.04, abs(hx_cells(p * 0.55) - 0.5)) * near_k;
	c_sed *= 1.0 - 0.18 * crack;                                                                     // grietas de barro seco
	// la piedra de las laderas de la quebrada es parda y rojiza, no gris neutro (con la luna fría el gris se leía como charcos azules): se la mezcla con el adobe y el sedimento
	vec3 rock_tint = mix(pal_piedra, mix(pal_adobe, pal_sedimento, 0.5), 0.6 + 0.2 * big);
	vec3 c_piedra = rock_tint * mix(vec3(1.0), vec3(1.08, 0.94, 0.8), warmth) * (0.78 + 0.3 * mid + 0.18 * fine) * (0.9 + 0.2 * hx_noise(p * 0.7));
	float strata = hx_noise(vec2(p.x * 0.006 + p.y * 0.004, asl * 0.22));                           // estratos claros y horizontales de los cerros erosionados
	float band = smoothstep(0.38, 0.62, fract(asl / 7.0 + strata * 0.9 + big * 0.5));
	c_piedra = mix(c_piedra, mix(pal_adobe, pal_lana, 0.35) * (0.86 + 0.2 * mid), band * steep * 0.82);
	vec3 c_churqui = mix(pal_suelo * mix(vec3(1.0), vec3(1.05, 0.94, 0.8), warmth) * (0.78 + 0.2 * big), pal_churqui, mix(0.4, 0.28, warmth));  // menos verde: la ladera es pardo ocre con matas
	vec2 sp = p * 0.26 + 3.0;
	float shrub_r = 0.14 + 0.34 * hx_hash(floor(sp) + 5.0);                                            // cada mata tiene su tamaño: no es un patrón de lunares
	float shrub = smoothstep(shrub_r, shrub_r * 0.3, hx_cells(sp)) * (0.7 + 0.3 * hx_noise(p * 0.9)) * (1.0 - 0.65 * smoothstep(150.0, 900.0, vdist)) * smoothstep(0.30, 0.62, hx_fbm2(p * 0.018 + 9.0));
	c_churqui = mix(c_churqui, pal_churqui * (0.66 + 0.16 * micro), shrub * (0.30 + 0.30 * mid));     // matas de arbusto sobre la ladera (más tenues cuanto más lejos)
	vec3 c_irr = mix(pal_irrigada, pal_sedimento, 0.25 * warmth) * (0.80 + 0.28 * mid) * (0.94 + 0.12 * fine);  // el regadío no queda verde loro de noche
	float furrow = smoothstep(0.30, 0.5, abs(fract(hx_rot(p, 0.42).x * 0.42) - 0.5));
	c_irr *= 1.0 - 0.16 * furrow * near_k;                                                           // surcos de las parcelas regadas
	vec3 c_agua = pal_agua * (0.92 + 0.12 * fine);
	vec3 c_cam = pal_suelo * 1.10 * (0.92 + 0.10 * mid) * (0.97 + 0.05 * fine);                      // tierra apisonada: más clara y menos pedregosa
	vec3 c_zanja = pal_sedimento * 0.78 * (0.94 + 0.12 * fine);
	float total = max(w_suelo + w_sed + w_piedra + w_chu + w_irr + w_agua + w_cam + w_zanja, 0.0001);
	vec3 c = (c_suelo * w_suelo + c_sed * w_sed + c_piedra * w_piedra + c_churqui * w_chu + c_irr * w_irr + c_agua * w_agua + c_cam * w_cam + c_zanja * w_zanja) / total;
	vec3 flat_c = (pal_suelo * w_suelo + pal_sedimento * w_sed + pal_piedra * w_piedra + pal_churqui * w_chu + pal_irrigada * w_irr + pal_agua * w_agua + pal_suelo * w_cam + pal_sedimento * w_zanja) / total;

	// --- visual/r1 F5: texturas de cerca. Los pesos de capa de siempre eligen el material (los dos de más peso, mezclados por altura) ---------------------------
	float tex_k = tex_on * (1.0 - smoothstep(tex_near_m, tex_far_m, vdist)) * (1.0 - albedo_mode);
	vec3 tex_n = wnrm;
	float tex_ao = 1.0;
	float tex_rough = 0.95;
	vec3 dpx = dFdx(wpos);
	vec3 dpy = dFdy(wpos);
	if (tex_k > 0.002) {
		float cliff = smoothstep(0.22, 0.42, slope);
		float mw[6] = {w_suelo + w_cam, w_piedra * (1.0 - cliff), w_sed + w_agua + w_zanja, w_piedra * cliff, w_chu, w_irr};
		int i1 = 0;
		for (int m = 1; m < 6; m++) { if (mw[m] > mw[i1]) { i1 = m; } }
		int i2 = (i1 == 0) ? 1 : 0;
		for (int m = 0; m < 6; m++) { if (m != i1 && mw[m] > mw[i2]) { i2 = m; } }
		float wsum = max(mw[i1] + mw[i2], 0.0001);
		float w1 = mw[i1] / wsum;
		float w2 = mw[i2] / wsum;
		float kn = hx_noise(p * 0.11 + 5.0);
		vec3 a1; vec3 n1; vec2 o1; float h1;
		vec3 a2 = vec3(0.5); vec3 n2 = vec3(0.0, 0.0, 1.0); vec2 o2 = vec2(1.0); float h2 = 0.5;
		if (i1 == 3) {
			tex_rock(wpos, wnrm, kn, dpx, dpy, a1, n1, o1, h1);
		} else {
			float t1 = 1.0 / TEX_TILE[i1];
			tex_layer(float(i1), p * t1, dpx.xz * t1, dpy.xz * t1, kn, a1, n1, o1, h1);
			n1 = normalize(vec3(n1.x * tex_normal + wnrm.x, abs(n1.z) * wnrm.y, -n1.y * tex_normal + wnrm.z));
		}
		if (w2 > 0.03) {
			if (i2 == 3) {
				tex_rock(wpos, wnrm, kn, dpx, dpy, a2, n2, o2, h2);
			} else {
				float t2 = 1.0 / TEX_TILE[i2];
				tex_layer(float(i2), p * t2, dpx.xz * t2, dpy.xz * t2, kn, a2, n2, o2, h2);
				n2 = normalize(vec3(n2.x * tex_normal + wnrm.x, abs(n2.z) * wnrm.y, -n2.y * tex_normal + wnrm.z));
			}
		} else {
			w2 = 0.0;
		}
		// mezcla por altura: en el borde entre dos materiales asoma el que está más alto (piedras sobre la tierra, matas sobre la grava)
		float depth = 0.25;
		float ma = max(h1 + w1, h2 + w2) - depth;
		float b1 = max(h1 + w1 - ma, 0.0);
		float b2 = (w2 > 0.0) ? max(h2 + w2 - ma, 0.0) : 0.0;
		float bs = max(b1 + b2, 0.0001);
		b1 /= bs;
		b2 /= bs;
		// grano: la foto dividida por su propio color medio (el último mipmap), así el promedio sigue siendo el de la paleta
		vec3 m1 = textureLod(tex_albedo, vec3(0.5, 0.5, float(i1)), 10.0).rgb;
		vec3 m2 = textureLod(tex_albedo, vec3(0.5, 0.5, float(i2)), 10.0).rgb;
		vec3 d1 = a1 / max(m1, vec3(0.02));
		vec3 d2 = a2 / max(m2, vec3(0.02));
		vec3 dd = d1 * b1 + d2 * b2;
		float dl = dot(dd, vec3(0.299, 0.587, 0.114));
		vec3 grain = clamp(mix(vec3(dl), dd, tex_chroma), vec3(0.25), vec3(2.2));
		c *= mix(vec3(1.0), grain, tex_k);
		tex_n = normalize(mix(wnrm, normalize(n1 * b1 + n2 * b2), tex_k));
		vec2 oo = o1 * b1 + o2 * b2;
		tex_ao = mix(1.0, oo.r, tex_k);
		tex_rough = mix(0.95, clamp(oo.g, 0.45, 1.0), tex_k);
	}

	// --- relieve leído: sombreado de laderas y curvas de nivel sutiles -----------------------------------------------------------------------------------
	float hh = asl / max(contour_m, 0.5);
	float dist_line = abs(fract(hh + 0.5) - 0.5) * contour_m;
	float line_w = max(fwidth(asl) * 1.1, 0.02);
	float line = 1.0 - smoothstep(0.0, line_w, dist_line);
	float major = 1.0 - smoothstep(0.0, line_w, abs(fract(asl / 20.0 + 0.5) - 0.5) * 20.0);
	c *= 1.0 - (line * contour_alpha + major * contour_alpha * 1.3) * mid_k * (1.0 - steep * 0.6);
	c *= 1.0 - 0.22 * smoothstep(0.03, 0.30, slope);                                                 // la ladera se ve más oscura que el llano

	// --- lluvia: el suelo se oscurece, se alisa y junta charcos chicos (solo de cerca: de lejos serían manchas de camuflaje) --------------------------------------
	float puddle_n = hx_fbm2(p * 0.13 + 31.0);
	float puddle = smoothstep(0.63, 0.72, puddle_n) * (1.0 - smoothstep(0.01, 0.05, slope)) * rain * (1.0 - w_piedra) * (1.0 - smoothstep(60.0, 330.0, vdist));
	float wet = clamp(rain * (1.0 - 0.35 * w_cam), 0.0, 1.0);
	c *= mix(1.0, wet_darken, wet);
	c = mix(c, c * vec3(0.68, 0.68, 0.72), puddle * 0.7);

	// --- normal con relieve fino (terrones y piedras) para que el sol bajo del alba arme sombras sobre la grava; se apaga con la distancia -------------------------------
	float e = 0.35;
	float h0 = hx_noise(p * 1.1) * 0.6 + hx_noise(p * 3.7) * 0.4;
	float hxp = hx_noise((p + vec2(e, 0.0)) * 1.1) * 0.6 + hx_noise((p + vec2(e, 0.0)) * 3.7) * 0.4;
	float hzp = hx_noise((p + vec2(0.0, e)) * 1.1) * 0.6 + hx_noise((p + vec2(0.0, e)) * 3.7) * 0.4;
	vec3 nw = normalize(tex_n + vec3(-(hxp - h0), 0.0, -(hzp - h0)) * (0.55 + 0.5 * stones) * bump_k * (1.0 - puddle) * (1.0 - 0.75 * tex_k));  // F5: la textura trae su relieve
	nw = normalize(mix(nw, wnrm, puddle));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);

	if (albedo_mode > 0.5) {
		ALBEDO = vec3(0.0);
		EMISSION = flat_c;
		ROUGHNESS = 1.0;
		SPECULAR = 0.0;
	} else {
		ALBEDO = c;
		ROUGHNESS = mix(tex_rough, wet_rough + 0.12, wet) * mix(1.0, 0.45, puddle) * mix(1.0, 0.6, w_agua);
		AO = tex_ao;
		AO_LIGHT_AFFECT = 0.35;
		SPECULAR = mix(0.12, 0.2, wet) + 0.2 * puddle;
	}
}
