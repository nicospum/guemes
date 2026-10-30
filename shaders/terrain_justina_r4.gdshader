shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/justina_noise.gdshaderinc"
// Terreno de Justina (ronda 4): una sola superficie continua (mapa + horizonte) con color por zona (vertex COLOR) y
// detalle procedural en coordenadas de mundo: parches de pasto de invierno, matorral, tierra pelada, huellas,
// estratos de tosca en la barranca, arena con rizado, juncal en la orilla y barro humedo cerca del agua.
// COLOR.rgb = color base de la zona; COLOR.a = cuanto es pasto/campo (1 meseta y campo, 0 playa).
// Es aspecto reconstruido (Vidal 1820 y Boneo 1801 dan la paleta y la forma de la costa, no el detalle).
varying vec3 world_pos;
varying vec3 world_normal;
varying float view_dist;
uniform float color_gamma = 1.9;
uniform float water_level = 1.65;
uniform float level_high = 1.65;

float track(vec2 p, float cx, float amp, float freq, float ph, float w){
	float x = cx + amp * sin(p.y * freq + ph) + 0.35 * amp * sin(p.y * freq * 2.7 + ph * 1.9);
	float d = abs(p.x - x);
	float edge = j_noise(p * 0.9) * 0.9;
	return 1.0 - smoothstep(w * 0.4, w + edge, d);
}

void vertex(){
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = NORMAL;
	view_dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

void fragment(){
	vec2 p = world_pos.xz;
	float h = world_pos.y;
	float fade = 1.0 - smoothstep(70.0, 450.0, view_dist);
	float big = j_fbm3(p * 0.0035);
	float mid = j_fbm2(p * 0.028 + 3.0);
	float fine = mix(0.5, j_noise(p * 1.6), fade);
	float micro = mix(0.5, j_noise(p * 6.5), fade * fade);
	vec3 c = COLOR.rgb;
	float veg = COLOR.a;
	float slope = 1.0 - clamp(normalize(world_normal).y, 0.0, 1.0);

	// Pasto de invierno: del verde oliva a la paja segun parches grandes; tierra pelada y matorral.
	vec3 green = vec3(0.42, 0.40, 0.23);
	vec3 straw = vec3(0.66, 0.57, 0.37);
	float dry = smoothstep(0.30, 0.72, big * 0.8 + (mid - 0.5) * 0.7 + 0.12);
	vec3 pasture = mix(green, straw, dry);
	pasture *= 0.88 + (fine - 0.5) * 0.30 + (micro - 0.5) * 0.14;
	c = mix(c, pasture, veg * 0.85);
	float bare = smoothstep(0.64, 0.74, j_fbm2(p * 0.022 + 5.0)) * veg;
	c = mix(c, vec3(0.55, 0.45, 0.30) * (0.9 + fine * 0.2), bare * 0.75);
	float shrub = smoothstep(0.60, 0.68, j_fbm2(p * 0.075 + 11.0)) * smoothstep(0.38, 0.58, j_noise(p * 0.55 + 2.0)) * veg;
	c = mix(c, vec3(0.34, 0.34, 0.19) * (0.88 + micro * 0.3), shrub * 0.62);
	// Huellas de carreta y senderos (reconstruccion estetica; las rutas de juego las marca la interfaz).
	float tr = max(track(p, 20.0, 34.0, 0.0105, 1.0, 1.7), max(track(p, -140.0, 60.0, 0.0072, 3.0, 2.1), track(p, 90.0, 28.0, 0.0140, 5.2, 1.5)));
	tr = max(tr, track(vec2(p.y, p.x), 330.0, 70.0, 0.0090, 0.4, 1.8) * smoothstep(-40.0, 40.0, -p.x + 120.0));
	c = mix(c, vec3(0.56, 0.48, 0.34) * (0.92 + fine * 0.14), tr * veg * 0.78);

	// Barranca: tosca y tierra con estratos horizontales, mas clara a media altura.
	float strata = j_noise(vec2(p.y * 0.30 + p.x * 0.05, h * 2.2));
	float cliff = smoothstep(0.05, 0.40, slope);
	vec3 tosca = mix(vec3(0.56, 0.45, 0.30), vec3(0.68, 0.58, 0.42), strata);
	c = mix(c, tosca, cliff * 0.80);

	// Playa: arena con rizado alargado, grava y juncal arriba de la linea de agua alta.
	float beach = 1.0 - veg;
	float above = h - water_level + (j_fbm2(p * 0.05 + 40.0) - 0.5) * 0.9;
	float ripple = j_noise(vec2(p.x * 0.9, p.y * 0.11)) * 0.6 + j_noise(vec2(p.x * 3.1, p.y * 0.4)) * 0.4;
	vec3 sand = mix(vec3(0.56, 0.49, 0.34), vec3(0.65, 0.58, 0.42), ripple);
	vec3 mud = vec3(0.34, 0.29, 0.20);
	vec3 beach_c = mix(mud, sand, smoothstep(-0.2, 0.9, h - 0.0));
	beach_c *= 0.94 + (micro - 0.5) * 0.12;
	float reed = smoothstep(level_high - 0.5, level_high + 0.2, h) * (1.0 - smoothstep(level_high + 0.9, level_high + 1.7, h)) * smoothstep(0.48, 0.66, j_fbm2(p * vec2(0.16, 0.05) + 31.0));
	beach_c = mix(beach_c, vec3(0.40, 0.42, 0.20), reed * 0.65);
	c = mix(c, beach_c, beach * (1.0 - cliff * 0.7));

	// Barro humedo y brillo bajo/cerca del agua (bajante).
	float wet = 1.0 - smoothstep(-0.1, 0.9 + 0.7 * (j_fbm2(p * 0.09 + 3.0) - 0.4), above);
	c = mix(c, c * vec3(0.62, 0.58, 0.52), wet * 0.8);

	float blot = smoothstep(0.45, 0.75, j_fbm2(p * 0.07 + 77.0)) * smoothstep(1.2, 0.2, h - water_level + 0.6) * beach;
	c = mix(c, c * vec3(0.72, 0.68, 0.60), blot * 0.55);
	ALBEDO = pow(c, vec3(color_gamma)) * (0.94 + fine * 0.10);
	ROUGHNESS = mix(0.93, 0.35, wet * beach);
	SPECULAR = mix(0.2, 0.5, wet);
}
