shader_type sky;
#include "res://shaders/justina_noise.gdshaderinc"
// Cielo de invierno nublado y ventoso (12 de agosto, Rio de la Plata), ronda 4. Reconstruccion estetica: no hay registro del cielo de ese dia.
// El horizonte iguala el color de la niebla del entorno para que el agua y la meseta lejanas se fundan sin linea dura.
uniform vec3 horizon_color : source_color = vec3(0.86, 0.81, 0.67);
uniform vec3 zenith_color : source_color = vec3(0.50, 0.57, 0.62);
uniform vec3 cloud_light : source_color = vec3(0.86, 0.85, 0.80);
uniform vec3 cloud_dark : source_color = vec3(0.45, 0.49, 0.53);
uniform vec3 below_color : source_color = vec3(0.62, 0.58, 0.48);
uniform float coverage = 0.58;
uniform float wind_speed = 0.006;

void sky(){
	vec3 d = EYEDIR;
	float up = clamp(d.y, 0.0, 1.0);
	vec3 col = mix(horizon_color, zenith_color, pow(up, 0.55));
	if (d.y > 0.0) {
		// Proyeccion plana de la capa de nubes: se achata hacia el horizonte (perspectiva) y corre con el viento del sudoeste.
		vec2 uv = d.xz / (d.y + 0.18);
		vec2 w = vec2(TIME * wind_speed, TIME * wind_speed * 0.45);
		float n = j_fbm3(uv * 0.9 + w);
		float n2 = j_fbm2(uv * 2.6 - w * 1.7 + 7.0);
		float dens = smoothstep(coverage - 0.18, coverage + 0.16, n * 0.75 + n2 * 0.25);
		float shade = clamp(j_fbm2(uv * 1.3 + w + 0.35) * 1.4 - 0.2, 0.0, 1.0);
		vec3 cc = mix(cloud_light, cloud_dark, shade);
		// Las nubes se desvanecen en el horizonte para no marcar una linea.
		float fade = smoothstep(0.0, 0.16, d.y);
		col = mix(col, cc, dens * fade * 0.92);
	} else {
		col = mix(horizon_color, below_color, clamp(-d.y * 3.0, 0.0, 1.0));
	}
	COLOR = col;
}
