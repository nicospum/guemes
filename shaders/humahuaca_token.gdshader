shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;
// visual/r1 F5: dos caras (antes cull_back). El poncho de las figuras de a pie de 1817 es una tela colgada de una sola capa: con cull_back, mirado por detrás o por
// debajo se veía a través de él la camisa y el contorno de tinta. Las figuras cerradas del generador no cambian (su cara de atrás queda tapada por la de adelante).
// Fichas y defensores del nivel «Humahuaca» (pista visual, P2): el color sale del color de vértice (sRGB de la paleta, como en el generador) con dos ayudas de
// lectura que no dependen de la luz de la escena, porque una figura de poncho oscuro sobre el suelo mojado de noche se perdía (DIRECCION_DE_ARTE B3):
//   · `self_light`: una parte del color se ve siempre (la ficha es información, no decorado), sin llegar a parecer pintada encima;
//   · `rim`: un borde de color de bando (celeste el propio, rojo el enemigo) que crece en las caras de canto, como un contorno de luz.
// `albedo_mode` = 1 da el color plano sin luz (la métrica de paleta del QA).
uniform float self_light : hint_range(0.0, 1.0) = 0.22;
uniform vec3 rim_color : source_color = vec3(0.55, 0.72, 0.84);
uniform float rim_amount : hint_range(0.0, 2.0) = 0.55;
uniform float rim_power = 2.6;
uniform float albedo_mode = 0.0;
// visual/r1 F4: los GLB del caballo criollo y del jinete traen el color de vértice LINEAL (COLOR_0 de glTF); el generador lo pone en sRGB. 1 = ya es lineal.
uniform float vertex_linear = 0.0;

void fragment(){
	vec3 base = COLOR.rgb;
	if (vertex_linear < 0.5) {
		base = mix(base / 12.92, pow((base + 0.055) / 1.055, vec3(2.4)), step(0.04045, base));  // sRGB → lineal
	}
	if (albedo_mode > 0.5) {
		ALBEDO = vec3(0.0);
		EMISSION = base;
		ROUGHNESS = 1.0;
		SPECULAR = 0.0;
	} else {
		float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
		float rim = pow(1.0 - facing, rim_power) * rim_amount;
		ALBEDO = base;
		ROUGHNESS = 0.85;
		SPECULAR = 0.25;
		EMISSION = base * self_light + rim_color * rim;
	}
}
