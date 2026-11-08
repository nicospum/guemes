shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
// Aviso de detección del nivel «Humahuaca» (pista visual, P2, pedido de P3): un aro ámbar sobre el suelo, alrededor de la ficha descubierta, que se vacía en sentido
// horario mientras corre la cuenta del centinela (render_state().units[].spotted_s, 5 s). El tramo que ya pasó queda tenue; el aro late para leerse de noche y
// va un poco levantado del suelo para que el relieve no lo tape (la figura sí queda delante). `fill` (0 a 1) lo pone la vista (un material por ficha).
uniform float fill = 1.0;
uniform vec4 tint : source_color = vec4(1.0, 0.68, 0.22, 1.0);

void fragment(){
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.x, -p.y) / 6.2831853 + 0.5;  // 0 arriba, crece en sentido horario
	float ring = smoothstep(0.74, 0.79, r) * (1.0 - smoothstep(0.95, 1.0, r));
	float edge = smoothstep(0.66, 0.72, r) * (1.0 - smoothstep(0.74, 0.76, r));  // filete de tinta por dentro: separa el aro del suelo claro
	float on = step(a, clamp(fill, 0.0, 1.0));
	float pulse = 0.82 + 0.18 * sin(TIME * 9.0);
	vec3 c = mix(vec3(0.03, 0.02, 0.04), tint.rgb, step(0.001, ring));
	ALBEDO = c;
	ALPHA = max(ring * mix(0.14, 1.0, on) * pulse, edge * 0.55) * tint.a;
}
