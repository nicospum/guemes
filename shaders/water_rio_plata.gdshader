shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, shadows_disabled, specular_schlick_ggx;
#include "res://shaders/justina_noise.gdshaderinc"
// Agua del Rio de la Plata para Justina (ronda 4). Turbia, pardo-verdosa (no azul), mas clara y arenosa cerca de la orilla.
// Olas pequeñas de viento: dos octavas de ruido a distinta escala y direccion (sin textura => sin mosaico visible), mas una
// ondulacion larga. Reflejo del cielo por Fresnel, brillo especular suave, espuma sutil en la orilla.
// DATOS POR VERTICE (los pone world_view.gd):
//   UV.x  = altura REAL del suelo (m sobre el cero de bajante) -> solo halo de contacto y espuma (lo "visible" a menos de visible_depth_m).
//   UV2.x = fondo BASE publico (perfil de bed_profile, sin bancos ni pozo oculto) -> solo el degradado de color orilla-lejos.
// Asi el color no delata el fondo oculto: los bancos aparecen solo al bajar el nivel (el suelo real emerge) o dentro de 0,3 m.
uniform float water_level = 1.65;
uniform float visible_depth_m = 0.3;
// R6: los tres tonos vienen de palette.water.turbid_near/mid/far del JSON (world_view.gd los pasa); estos son solo valores por defecto.
uniform vec3 near_color : source_color = vec3(0.62, 0.50, 0.30);   // turbid_near #8A7C5C
uniform vec3 mid_color : source_color = vec3(0.50, 0.46, 0.27);   // turbid_mid #79806A
uniform vec3 far_color : source_color = vec3(0.33, 0.37, 0.28);   // turbid_far #5F7378
uniform vec3 sky_horizon : source_color = vec3(0.92, 0.82, 0.62);    // bruma cremosa de Vidal
uniform vec3 sky_zenith : source_color = vec3(0.50, 0.58, 0.62);
uniform vec3 sun_dir = vec3(0.42, 0.62, 0.66);
uniform float wave_amp = 1.0;
// Buque varado (ronda 2): pista de bajo bajo el casco (agua clara + espuma) y zona de incertidumbre de su ubicacion (120 m).
uniform vec2 ship_xz = vec2(580.0, 262.0);
uniform vec2 ship_fwd = vec2(0.0, -1.0);
uniform vec2 ship_half = vec2(5.5, 21.0);   // semiancho (m), semieslora (m)
uniform float unc_radius = 120.0;
uniform float unc_strength = 1.0;
varying vec3 world_pos;
varying float ground;
varying float base_bed;

void vertex(){
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	ground = UV.x;
	base_bed = UV2.x;
}

float swell(vec2 p, float t, float lod){
	// Alturas de olas: octava grande (viento del sudeste, ~25 m), octava media (~7 m) cruzada y rizado fino (~1,6 m, solo cerca).
	float a = j_noise(j_rot(p, 0.55) * 0.045 + vec2(t * 0.10, t * 0.04));
	float b = j_noise(j_rot(p, -0.35) * 0.16 + vec2(-t * 0.22, t * 0.09));
	float c = lod > 0.35 ? j_noise(j_rot(p, 1.15) * 0.62 + vec2(t * 0.45, -t * 0.30)) : 0.5;
	return a * 0.55 + b * 0.32 + c * 0.13;
}

void fragment(){
	vec2 p = world_pos.xz;
	float dist = length(VERTEX);
	float lod = 1.0 / (1.0 + dist * 0.0035);
	float e = 0.35;
	float t = TIME;
	float h0 = swell(p, t, lod);
	float hx = swell(p + vec2(e, 0.0), t, lod);
	float hz = swell(p + vec2(0.0, e), t, lod);
	float k = 4.6 * wave_amp * lod;
	vec3 n_w = normalize(vec3(-(hx - h0) / e * k, 1.0, -(hz - h0) / e * k));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_w, 0.0)).xyz);

	float lvl_k = smoothstep(0.15, 1.1, water_level);  // 0 con el rio en el minimo: el casco apoya y no hay estela
	// R4: borde del bajo irregular (ruido de dominio): el halo y la espuma siguen meandros en lugar de capsulas de bordes redondos.
	float edge_n = (j_fbm2(j_rot(p, 0.4) * vec2(0.075, 0.13) + 9.0) - 0.5) * 0.30 + (j_noise(p * 0.6) - 0.5) * 0.10;
	float depth_r = water_level - ground;
	float depth = depth_r + edge_n;
	float est = max(water_level - base_bed, 0.0);     // base publica: color
	vec3 view_w = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	vec3 r = reflect(-view_w, n_w);
	float ndv = clamp(dot(n_w, view_w), 0.0, 1.0);
	float fres = 0.03 + 0.55 * pow(1.0 - ndv, 4.0);

	// Color del cuerpo: limo claro y verdoso sobre los bajos, verde-pardo turbio medio y canal oscuro; plumas de sedimento.
	float shallow = 1.0 - smoothstep(0.1, 1.4, est);
	float deepk = smoothstep(1.2, 3.2, est);
	float patch_n = j_fbm2(p * 0.012 + vec2(t * 0.003, 0.0));
	float plume = j_fbm2(p * 0.0042 + vec2(5.0, t * 0.0015));
	vec3 body = mix(mix(mid_color, near_color, shallow * 0.6), far_color, deepk);
	vec3 silt = vec3(0.48, 0.45, 0.32);
	vec3 algae = vec3(0.30, 0.42, 0.37);
	// Plumas de sedimento grandes (200-400 m): del pardo limoso al verde turbio, con contraste marcado (ronda 3).
	float plume2 = j_fbm2(j_rot(p, 0.6) * vec2(0.0035, 0.0085) + vec2(2.0, t * 0.002));
	body = mix(body, mix(algae, silt, smoothstep(0.28, 0.66, plume * 0.6 + plume2 * 0.5)), 0.22 * (1.0 - shallow * 0.6));
	// Vetas de viento alargadas (lanes claros y oscuros paralelos al viento) que rompen la lamina plana.
	float lane = j_noise(j_rot(p, -0.5) * vec2(0.012, 0.11) + vec2(0.0, t * 0.05));
	body *= (0.90 + 0.20 * lane) * 0.66;
	// R4: variacion de gran escala (400-900 m, dos direcciones) sin direccion dominante: cuerpos de agua de distinto sedimento.
	float big1 = j_fbm2(j_rot(p, 0.9) * 0.0016 + vec2(11.0, t * 0.0004));
	float big2 = j_fbm2(j_rot(p, -0.4) * 0.0031 + vec2(3.0, 7.0));
	body = mix(body, vec3(0.50, 0.50, 0.38), smoothstep(0.50, 0.80, big1) * 0.30 * (1.0 - shallow));   // pluma parda del Parana
	body = mix(body, vec3(0.34, 0.40, 0.27), smoothstep(0.50, 0.78, big2) * 0.26 * (1.0 - shallow));  // R3-visual: agua mas limpia, verde oliva (no azulada)
	body *= 0.90 + 0.20 * big1;
	body = mix(body, body * vec3(1.10, 1.06, 0.92), (patch_n - 0.5) * 0.7);
	// R6: crestas claras y senos oscuros (contraste de ola real) y manchas de viento (catspaws) que rompen la lamina.
	float crest = smoothstep(0.50, 0.78, h0);
	float swl = j_noise(j_rot(p, 0.55) * 0.045 + vec2(t * 0.10, t * 0.04));   // ola larga: visible desde altura
	body *= (0.62 + 0.80 * h0) * (0.82 + 0.40 * swl);
	body = mix(body, body * vec3(1.35, 1.28, 1.05), crest * 0.35 * lod);
	float gust = j_fbm2(j_rot(p, 0.3) * vec2(0.020, 0.052) + vec2(t * 0.012, 0.0));
	body *= 0.93 + 0.14 * smoothstep(0.38, 0.70, gust);
	// Estrias de espuma de rompiente lejos de la orilla (borreguitos, viento fresco): escasas y alargadas.
	float wc = j_noise(j_rot(p, -0.5) * vec2(0.085, 0.42) + vec2(t * 0.20, 0.0));
	float wc_m = smoothstep(0.72, 0.86, wc) * smoothstep(0.55, 0.75, h0) * (0.35 + 0.65 * lod) * 0.16;
	// Bajo bajo el casco (diseno: el buque esta apoyado): agua mas clara y verdosa en un ovalo suave alrededor.
	vec2 sd = p - ship_xz;
	vec2 fw = normalize(ship_fwd);
	vec2 loc = vec2(dot(sd, vec2(-fw.y, fw.x)), dot(sd, fw));
	float hull_d = length(loc / (ship_half + vec2(13.0, 21.0)));       // ~1 en el borde del bajo (casco + ~13 m / 21 m)
	float shoal = (1.0 - smoothstep(0.55, 1.0, hull_d)) * 0.8;
	// con el rio bajo el casco apoya en un bajo: el agua alrededor se aclara a arena (sin estela); con el rio alto, solo un leve aclarado.
	body = mix(body, mix(vec3(0.56, 0.58, 0.46), vec3(0.66, 0.60, 0.44), 1.0 - lvl_k), shoal * mix(0.95, 0.5, lvl_k));
	// Bruma de horizonte: a lo lejos el agua se funde al crema del cielo de Vidal (sin linea de corte).
	float haze = smoothstep(2200.0, 4600.0, dist);
	// Halo de contacto: el suelo real se insinua a menos de visible_depth_m de la superficie.
	float halo = 1.0 - smoothstep(0.0, visible_depth_m, depth);
	body = mix(body, near_color * vec3(1.02, 1.0, 0.92), halo * 0.4);

	// Orilla: arena mojada translucida -> linea de agua nitida con espuma fina ruidosa -> segunda franja de lavado mas tenue.
	float foam = 0.0;
	if (depth < 0.9) {
		float nz = j_fbm2(p * vec2(0.9, 1.4) + vec2(t * 0.12, 0.0));
		float edge_w = 0.035 + 0.05 * nz;
		float line = smoothstep(0.0, edge_w, depth) * (1.0 - smoothstep(edge_w, edge_w + 0.10, depth));
		float wash = 0.5 + 0.5 * sin(depth * 7.0 - t * 0.9 + nz * 6.0);
		float band2 = smoothstep(0.12, 0.30, depth) * (1.0 - smoothstep(0.30, 0.8, depth)) * wash * (0.35 + 0.65 * nz);
		foam = clamp(line * (0.55 + 0.45 * nz) * 1.1 + band2 * 0.30, 0.0, 0.85);
	}
	// Espuma y estela en el casco del buque.
	float hull_edge = length(loc / ship_half);
	float rim = smoothstep(0.80, 1.0, hull_edge) * (1.0 - smoothstep(1.12, 1.7, hull_edge)) * lvl_k;
	float rim_n = 0.55 + 0.45 * j_noise(p * 1.1 + vec2(t * 0.3, 0.0));
	foam = max(foam, rim * rim_n * 0.95);
	foam = max(foam, wc_m * (1.0 - shallow * 0.8));
	body *= 1.0 - 0.35 * lvl_k * smoothstep(0.55, 0.95, hull_edge) * (1.0 - smoothstep(0.95, 1.1, hull_edge));
	// Zona de incertidumbre (120 m, Informe sec. D): anillo punteado muy tenue, no relleno.
	float ur = length(sd);
	float ring = (1.0 - smoothstep(0.0, 0.9, abs(ur - unc_radius))) * step(0.5, fract(atan(sd.y, sd.x) * 9.5493 + 0.5));
	body = mix(body, vec3(0.80, 0.74, 0.55), ring * 0.14 * unc_strength);

	// R-div1: tres bandas de profundidad legibles (somera arenosa / media limosa / canal verde oscuro) con borde suave.
	float band_s = 1.0 - smoothstep(0.25, 0.75, est);
	float band_d = smoothstep(1.7, 2.6, est);
	body = mix(body, vec3(0.66, 0.55, 0.34), band_s * 0.40 * (1.0 - halo));
	body = mix(body, vec3(0.25, 0.30, 0.17), band_d * 0.50);
	// Frentes de ola: lineas claras que viajan hacia la costa (oeste), deformadas por ruido; dan escala y direccion al agua.
	float wph = dot(p, vec2(0.62, 0.16)) * 0.55 + t * 0.55 + j_noise(p * 0.035) * 6.0;
	float wf = abs(fract(wph * 0.159) - 0.5) * 2.0;                       // diente de sierra -> cresta fina
	float wmask = smoothstep(0.52, 0.80, j_fbm2(j_rot(p, 0.8) * vec2(0.020, 0.045) + vec2(t * 0.01, 3.0)));  // solo en parches (rafagas)
	float front = smoothstep(0.90, 0.99, wf) * wmask * (0.2 + 0.8 * lod) * (1.0 - band_s * 0.7);
	body = mix(body, vec3(0.92, 0.88, 0.72), front * 0.22);
	// R2-visual: gradiente de profundidad marcado (ocre-limo cerca de la costa -> verde botella-pardo al canal), usa solo el perfil BASE publico.
	float off_k = smoothstep(0.2, 2.6, est);
	vec3 warm = vec3(0.62, 0.43, 0.20);   // R3-visual: ocre limoso mas luminoso cerca de la orilla
	vec3 cool = vec3(0.13, 0.20, 0.12);   // oliva turbio al canal (antes verde botella frio)
	body = mix(body, mix(warm, cool, smoothstep(0.0, 1.0, off_k)), 0.82 * (1.0 - halo));
	// R3-visual: luminosidad general (antes 0.66 apagaba todo a gris-verde oscuro)
	body *= 1.06;
	// Sombreado de facetas de ola con el sol: lados iluminados claros, lados en sombra oscuros (da relieve y corriente a toda la lamina).
	float lit = clamp(dot(n_w, normalize(sun_dir)), 0.0, 1.0);
	body *= clamp(1.0 + (lit - 0.62) * 2.4 * (0.35 + 0.65 * lod), 0.45, 1.7);
	// Crestas con espuma fina que se ven a altura de juego (borreguitos cortos orientados al viento).
	float cr2 = j_noise(j_rot(p, 0.25) * vec2(0.22, 0.55) + vec2(t * 0.32, t * 0.06));
	float cr_m = smoothstep(0.70, 0.84, cr2) * smoothstep(0.52, 0.72, h0) * lod * (1.0 - band_s * 0.8) * 0.5;
	foam = max(foam, cr_m);
	vec3 sky = mix(sky_horizon, sky_zenith, clamp(r.y * 1.6, 0.0, 1.0));
	float sd_dot = max(dot(r, normalize(sun_dir)), 0.0);
	float glint = pow(sd_dot, 40.0) * 0.10 + pow(sd_dot, 300.0) * 0.55 * (0.5 + h0);

	// R3-visual: reflejo del cielo calido (crema de Vidal arriba, azul palido al cenit) con base minima que se nota desde altura,
	// y destellos de sol anchos (no dependen del angulo especular exacto) para que el agua "brille" a escala de mapa.
	float sky_k = 0.10 + 0.50 * pow(1.0 - ndv, 3.0);
	vec3 sky_c = mix(sky_horizon, sky_zenith, clamp(r.y * 1.3, 0.0, 1.0));
	body = mix(body, sky_c * 0.8, sky_k * (0.35 + 0.35 * lod) * (1.0 - shallow * 0.5));
	float sp_n = j_noise(j_rot(p, 0.7) * mix(0.9, 0.35, 1.0 - lod) + vec2(t * 0.5, -t * 0.3));
	float sparkle = smoothstep(0.88, 0.99, sp_n) * smoothstep(0.35, 0.8, lit) * (0.30 + 0.70 * (1.0 - lod)) * (1.0 - shallow * 0.7);
	float shade_big = j_fbm2(j_rot(p, 0.3) * vec2(0.010, 0.026) + vec2(t * 0.008, 0.0));   // lomos largos de ola, visibles desde 500 m
	body *= 0.74 + 0.50 * smoothstep(0.25, 0.75, shade_big);
	// D4: oleaje en capas visible a escala de juego (200-500 m): trenes de olas de ~14 y ~31 m que viajan hacia la costa, deformados por ruido
	// (no dependen del lod: son estilizados). Crestas claras con cara iluminada y senos oscuros; mas marcados lejos de la orilla.
	float open_k = (1.0 - band_s) * (1.0 - halo);
	float nw = j_noise(p * 0.03 + vec2(t * 0.02, 0.0)) * 5.0;
	float tr1 = sin(dot(p, vec2(0.40, 0.12)) + t * 0.95 + nw);                   // ~15 m
	float tr2 = sin(dot(p, vec2(0.17, -0.07)) + t * 0.62 + nw * 1.7 + 1.3);       // ~35 m
	float tr3 = sin(dot(p, vec2(0.62, 0.30)) + t * 1.4 + nw * 0.6);               // ~9 m
	float tr = tr1 * 0.5 + tr2 * 0.38 + tr3 * 0.12;
	float ridge_mask = 0.55 + 0.45 * smoothstep(0.3, 0.7, j_fbm2(p * 0.011 + 4.0));
	body *= 1.0 + 0.50 * tr * ridge_mask * open_k;
	body = mix(body, vec3(0.80, 0.70, 0.46), smoothstep(0.80, 0.98, tr) * 0.22 * ridge_mask * open_k);   // cresta tostada
	// Reflejo del cielo calido que crece con la lejania (angulo rasante): agua que se funde al horizonte de Vidal en vez de verde plano.
	float graze = smoothstep(150.0, 1800.0, dist);
	body = mix(body, mix(vec3(0.50, 0.44, 0.28), sky_horizon * 0.70, graze), graze * 0.16 * (1.0 - halo));
	// Camino de brillo del sol: banda ancha y moteada hacia el azimut solar.
	vec2 sxz = normalize(sun_dir.xz);
	float along = dot(normalize(p - CAMERA_POSITION_WORLD.xz), sxz);
	float path_k = smoothstep(0.84, 1.0, along) * smoothstep(60.0, 500.0, dist);
	body += vec3(1.0, 0.88, 0.62) * path_k * (0.05 + 0.22 * smoothstep(0.35, 0.95, tr * 0.5 + 0.5 + (j_noise(p * 0.9 + t) - 0.5) * 0.6)) * (1.0 - shallow * 0.5);
	// Costa lejana y oleaje de rompiente: espuma fina y regular en la franja somera (se lee como agua viva, no como lamina).
	foam = max(foam, smoothstep(0.88, 1.0, tr1) * band_s * 0.30);
	body *= mix(1.0, 0.62, smoothstep(1.2, 3.4, est) * open_k);   // canal mas hondo y oscuro: profundidad legible
	ALBEDO = mix(mix(body, sky_horizon * 0.80, haze * 0.40), vec3(0.88, 0.86, 0.76), foam * 0.8) + vec3(1.0, 0.92, 0.72) * sparkle * 0.16;
	EMISSION = sky * (fres * 0.34 + 0.004) * vec3(1.0, 0.94, 0.80) + vec3(1.0, 0.90, 0.70) * glint;
	METALLIC = 0.0;
	ROUGHNESS = mix(0.22, 0.7, foam);
	SPECULAR = 0.12;

	// Transparencia: arena mojada visible en el primer centimetro, luego agua translucida sobre bajos, opaca-turbia en el canal.
	float a = mix(0.86, 0.98, smoothstep(0.0, 0.7, est));
	a = mix(a, 0.80, halo * 0.35);
	a = mix(0.0, a, smoothstep(0.0, 0.16, depth_r));
	a = max(a, foam * 0.9);
	ALPHA = ground > water_level + 0.06 ? 0.0 : a;
}
