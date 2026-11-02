shader_type spatial;
render_mode cull_back;
#include "res://shaders/humahuaca_noise.gdshaderinc"
// Edificios, tapias, vegetación y bultos del nivel «Humahuaca» (pista visual). El color sale del color de vértice (sRGB de la paleta; el generador
// procedural lo escribe por rol), con tres retoques por encima:
//   · desgaste y suciedad: COLOR.a vale 0 al pie y 1 arriba, así que lo bajo se ve más oscuro y manchado (la lluvia salpica y el adobe chupa humedad);
//   · en las paredes, franjas horizontales de 40 a 60 cm como el tapial (tierra compactada por tongadas) y manchas anchas de cal gastada;
//   · la lluvia oscurece ×0,75 y lo deja más liso, igual que el suelo.
// `albedo_mode` = 1 da el color plano de la paleta sin luz (la métrica de paleta del QA mira ese render).
uniform float rain : hint_range(0.0, 1.0) = 0.0;
uniform float wet_darken = 0.75;
uniform float albedo_mode = 0.0;
uniform float grime = 0.42;        // cuánto oscurece el pie de las paredes
uniform float band_amount = 0.07;  // intensidad de las franjas del tapial
uniform float detail = 1.0;

varying vec3 wpos;
varying vec3 wnrm;
varying float vdist;

void vertex(){
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vdist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

void fragment(){
	vec3 base = hx_lin(COLOR.rgb);
	float wall = 1.0 - smoothstep(0.55, 0.9, abs(wnrm.y));            // 1 en paredes verticales, 0 en techos y suelos
	float near_k = (1.0 - smoothstep(25.0, 260.0, vdist)) * detail;
	float stain = hx_fbm2(vec2(wpos.x + wpos.z, wpos.y * 1.7) * 0.45);
	float strata = 0.5 + 0.5 * sin(wpos.y * 11.0 + hx_noise(vec2(wpos.x + wpos.z, wpos.y) * 0.8) * 3.0);   // tongadas del tapial
	vec3 c = base * (0.90 + 0.20 * stain);
	c *= 1.0 - band_amount * (strata - 0.5) * 2.0 * wall * near_k;
	float low = 1.0 - smoothstep(0.0, 0.5, COLOR.a);
	c *= 1.0 - grime * low * (0.6 + 0.4 * stain);
	c *= mix(1.0, wet_darken, rain * 0.85);
	if (albedo_mode > 0.5) {
		ALBEDO = vec3(0.0);
		EMISSION = base;
		ROUGHNESS = 1.0;
		SPECULAR = 0.0;
	} else {
		ALBEDO = c;
		ROUGHNESS = mix(0.95, 0.62, rain * 0.8);
		SPECULAR = mix(0.2, 0.42, rain);
	}
}
