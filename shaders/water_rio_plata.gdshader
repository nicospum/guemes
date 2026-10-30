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
uniform vec3 near_color : source_color = vec3(0.50, 0.47, 0.32);     // limo claro de bajo (khaki)
uniform vec3 mid_color : source_color = vec3(0.30, 0.34, 0.27);      // verde-pardo turbio
uniform vec3 far_color : source_color = vec3(0.19, 0.25, 0.22);      // canal: mas oscuro y frio
uniform vec3 sky_horizon : source_color = vec3(0.80, 0.76, 0.64);    // bruma cremosa de Vidal
uniform vec3 sky_zenith : source_color = vec3(0.42, 0.50, 0.56);
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
	float k = 2.4 * wave_amp * lod;
	vec3 n_w = normalize(vec3(-(hx - h0) / e * k, 1.0, -(hz - h0) / e * k));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_w, 0.0)).xyz);

	float depth = water_level - ground;               // real: solo halo y espuma
	float est = max(water_level - base_bed, 0.0);     // base publica: color
	vec3 view_w = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	vec3 r = reflect(-view_w, n_w);
	float ndv = clamp(dot(n_w, view_w), 0.0, 1.0);
	float fres = 0.02 + 0.98 * pow(1.0 - ndv, 4.0);

	// Color del cuerpo: limo claro y verdoso sobre los bajos, verde-pardo turbio medio y canal oscuro; plumas de sedimento.
	float shallow = 1.0 - smoothstep(0.1, 1.4, est);
	float deepk = smoothstep(1.2, 3.2, est);
	float patch_n = j_fbm2(p * 0.012 + vec2(t * 0.003, 0.0));
	float plume = j_fbm2(p * 0.0042 + vec2(5.0, t * 0.0015));
	vec3 body = mix(mix(mid_color, near_color, shallow), far_color, deepk);
	vec3 silt = vec3(0.44, 0.38, 0.24);
	vec3 algae = vec3(0.26, 0.33, 0.26);
	body = mix(body, mix(algae, silt, smoothstep(0.30, 0.70, plume)), 0.40 * (1.0 - shallow * 0.7));
	body = mix(body, body * vec3(1.10, 1.06, 0.92), (patch_n - 0.5) * 0.7);
	body *= 0.80 + 0.40 * h0;
	// Bajo bajo el casco (diseno: el buque esta apoyado): agua mas clara y verdosa en un ovalo suave alrededor.
	vec2 sd = p - ship_xz;
	vec2 fw = normalize(ship_fwd);
	vec2 loc = vec2(dot(sd, vec2(-fw.y, fw.x)), dot(sd, fw));
	float hull_d = length(loc / (ship_half + vec2(13.0, 21.0)));       // ~1 en el borde del bajo (casco + ~13 m / 21 m)
	float shoal = (1.0 - smoothstep(0.55, 1.0, hull_d)) * 0.8;
	body = mix(body, vec3(0.52, 0.55, 0.40), shoal * 0.8);
	// Halo de contacto: el suelo real se insinua a menos de visible_depth_m de la superficie.
	float halo = 1.0 - smoothstep(0.0, visible_depth_m, depth);
	body = mix(body, near_color * vec3(1.10, 1.04, 0.90), halo * 0.6);

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
	float rim = smoothstep(0.75, 1.0, hull_edge) * (1.0 - smoothstep(1.0, 1.35, hull_edge));
	float rim_n = 0.55 + 0.45 * j_noise(p * 1.1 + vec2(t * 0.3, 0.0));
	foam = max(foam, rim * rim_n * 0.75);
	// Zona de incertidumbre (120 m, Informe sec. D): anillo punteado muy tenue, no relleno.
	float ur = length(sd);
	float ring = (1.0 - smoothstep(0.0, 0.9, abs(ur - unc_radius))) * step(0.5, fract(atan(sd.y, sd.x) * 9.5493 + 0.5));
	body = mix(body, vec3(0.80, 0.74, 0.55), ring * 0.20 * unc_strength);

	vec3 sky = mix(sky_horizon, sky_zenith, clamp(r.y * 1.6, 0.0, 1.0));
	float sd_dot = max(dot(r, normalize(sun_dir)), 0.0);
	float glint = pow(sd_dot, 60.0) * 0.05 + pow(sd_dot, 400.0) * 0.14 * (0.5 + h0);

	ALBEDO = mix(body, vec3(0.84, 0.83, 0.74), foam * 0.8);
	EMISSION = sky * (fres * 0.38 + 0.015) * mix(vec3(0.82, 0.88, 0.84), vec3(1.0), fres) + vec3(1.0, 0.93, 0.8) * glint;
	METALLIC = 0.0;
	ROUGHNESS = mix(0.10, 0.7, foam);
	SPECULAR = 0.5;

	// Transparencia: arena mojada visible en el primer centimetro, luego agua translucida sobre bajos, opaca-turbia en el canal.
	float a = mix(0.70, 0.97, smoothstep(0.0, 0.7, est));
	a = mix(a, 0.80, halo * 0.35);
	a = mix(0.0, a, smoothstep(0.0, 0.16, depth));
	a = max(a, foam * 0.9);
	ALPHA = ground > water_level + 0.06 ? 0.0 : a;
}
