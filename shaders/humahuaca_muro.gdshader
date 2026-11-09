shader_type spatial;
render_mode cull_back;
#include "res://shaders/humahuaca_noise.gdshaderinc"
// visual/r1 F6 (BACKLOG B-064): las paredes («F5 | muro») de las casas del kit (tools/f5_casas.py). El color de vértice del GLB (LINEAL, por el color de instancia de la
// MultiMesh: un tono por casa) se veía parejo de cerca, como cal recién dada. Encima, solo de cerca y sin cambiar el valor medio de la pared (V06, ΔL* edificio–suelo):
//   · manchas anchas de cal gastada y de revoque, y un grano fino de tierra (ruido en el espacio del mundo: cada pared distinta);
//   · chorreaduras verticales suaves (la lluvia que baja del pretil);
//   · un zócalo de barro salpicado al pie, de borde irregular (unos 35–60 cm), y una oclusión suave en el primer metro (el suelo tapa la luz del cielo);
//   · la lluvia oscurece y alisa, como el suelo y los objetos.
// Diseño: aspecto plausible del adobe revocado y encalado de la quebrada, no un relevamiento de casas de 1817.
uniform float rain : hint_range(0.0, 1.0) = 0.0;
uniform float wet_darken = 0.75;
uniform float albedo_mode = 0.0;
uniform float detail = 1.0;
uniform float stain_amount = 0.10;   // manchas de cal gastada (±)
uniform float grain_amount = 0.05;   // grano fino (±)
uniform float streak_amount = 0.06;  // chorreaduras (±)
uniform float plinth_h = 0.45;       // alto medio del zócalo salpicado (m)
uniform float plinth_dark = 0.30;    // cuánto oscurece el zócalo
uniform vec3 plinth_tint = vec3(0.62, 0.50, 0.38);  // el barro de la quebrada (lineal, relativo)
uniform float ao_amount = 0.16;      // oclusión del primer metro
uniform float lift = 0.07;            // compensa el oscurecimiento de abajo: la pared entera conserva su valor medio
uniform float roughness = 0.92;

varying vec3 wpos;
varying vec3 wnrm;
varying float vdist;
varying float hbase;

void vertex(){
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vdist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	hbase = wpos.y - MODEL_MATRIX[3].y;  // alto sobre el pie de la casa (el origen del modelo está en el suelo)
}

void fragment(){
	vec3 base = COLOR.rgb;
	float wall = 1.0 - smoothstep(0.55, 0.9, abs(wnrm.y));
	float near_k = (1.0 - smoothstep(30.0, 240.0, vdist)) * detail;
	vec2 q = vec2(wpos.x + wpos.z, wpos.y);  // sobre la pared: a lo largo y a lo alto
	float stain = hx_fbm2(q * vec2(0.55, 0.8) + 3.1) - 0.5;
	float grain = hx_noise(q * 6.5) - 0.5;
	float streak = (hx_noise(vec2(q.x * 2.2, q.y * 0.18) + 7.7) - 0.5) * smoothstep(0.4, 1.6, hbase);
	float edge = plinth_h * (0.75 + 0.6 * hx_noise(vec2(q.x * 1.7, 2.0)));
	float plinth = (1.0 - smoothstep(edge - 0.08, edge + 0.08, hbase)) * wall;
	float ao = (1.0 - smoothstep(0.0, 1.1, hbase)) * wall;
	vec3 c = base * (1.0 + (stain * 2.0 * stain_amount + grain * 2.0 * grain_amount + streak * 2.0 * streak_amount) * wall * near_k);
	c = mix(c, c * plinth_tint * (1.0 - plinth_dark) / max(dot(plinth_tint, vec3(0.333)), 0.01), plinth * (0.55 + 0.45 * near_k));
	c *= (1.0 - ao_amount * ao) * (1.0 + lift * wall);
	c *= mix(1.0, wet_darken, rain * 0.85);
	if (albedo_mode > 0.5) {
		ALBEDO = vec3(0.0);
		EMISSION = base;
		ROUGHNESS = 1.0;
		SPECULAR = 0.0;
	} else {
		ALBEDO = c;
		ROUGHNESS = mix(roughness, 0.62, rain * 0.8);
		SPECULAR = mix(0.2, 0.42, rain);
	}
}
