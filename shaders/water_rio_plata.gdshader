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
uniform vec3 near_color : source_color = vec3(0.46, 0.42, 0.28);
uniform vec3 far_color : source_color = vec3(0.25, 0.29, 0.22);
uniform vec3 sky_horizon : source_color = vec3(0.78, 0.76, 0.68);
uniform vec3 sky_zenith : source_color = vec3(0.45, 0.52, 0.58);
uniform vec3 sun_dir = vec3(0.42, 0.62, 0.66);
uniform float wave_amp = 1.0;
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
	float fres = 0.03 + 0.97 * pow(1.0 - ndv, 5.0);

	// Color del cuerpo: arenoso y claro cerca de la orilla, pardo-verdoso oscuro lejos; manchas de sedimento a gran escala.
	float shallow = 1.0 - smoothstep(0.1, 1.5, est);
	float patch_n = j_fbm2(p * 0.012 + vec2(t * 0.003, 0.0));
	float plume = j_fbm2(p * 0.0042 + vec2(5.0, t * 0.0015));        // plumas de sedimento a escala de cientos de metros
	vec3 body = mix(far_color, near_color, shallow);
	vec3 silt = vec3(0.50, 0.42, 0.27);                               // limo en suspension: ocre
	vec3 algae = vec3(0.24, 0.31, 0.24);                              // agua mas clara y verdosa
	body = mix(body, mix(algae, silt, smoothstep(0.30, 0.70, plume)), 0.55 * (1.0 - shallow * 0.6));
	body = mix(body, body * vec3(1.14, 1.08, 0.88), (patch_n - 0.5) * 0.8);
	body *= 0.90 + 0.22 * h0;
	// Halo de contacto: el suelo real se insinua a menos de visible_depth_m de la superficie.
	float halo = 1.0 - smoothstep(0.0, visible_depth_m, depth);
	body = mix(body, near_color * vec3(1.12, 1.05, 0.88), halo * 0.7);

	// Espuma de orilla: gradiente continuo por profundidad real (sin ruido binario), modulada suavemente por el lavado de las olas.
	float foam = 0.0;
	if (depth < 0.5) {
		float wash = 0.5 + 0.5 * sin(depth * 9.0 - t * 1.2 + j_noise(p * 0.35) * 4.0);
		float foam_n = 0.65 + 0.35 * j_noise(p * 0.8 + vec2(t * 0.1, 0.0));
		foam = (1.0 - smoothstep(0.0, 0.14, depth)) * (0.55 + 0.45 * wash) * foam_n;
		foam += (1.0 - smoothstep(0.08, 0.5, depth)) * 0.16 * wash;
		foam = clamp(foam, 0.0, 0.8);
	}

	vec3 sky = mix(sky_horizon, sky_zenith, clamp(r.y * 1.4, 0.0, 1.0));
	float glint = pow(max(dot(r, normalize(sun_dir)), 0.0), 90.0) * 0.07 + pow(max(dot(r, normalize(sun_dir)), 0.0), 600.0) * 0.12;

	ALBEDO = mix(body, vec3(0.78, 0.78, 0.70), foam * 0.7);
	EMISSION = sky * fres * 0.6 + vec3(1.0, 0.93, 0.8) * glint;
	METALLIC = 0.0;
	ROUGHNESS = mix(0.16, 0.7, foam);
	SPECULAR = 0.5;

	// Transparencia: cerca de la orilla (fondo base < ~0,5 m) deja ver el suelo; el resto es opaco-turbio.
	float a = mix(0.62, 0.96, smoothstep(0.0, 0.55, est));
	a = mix(a, 0.55, halo * 0.5);
	a = max(a, foam * 0.9);
	ALPHA = ground > water_level + 0.06 ? 0.0 : a;
}
