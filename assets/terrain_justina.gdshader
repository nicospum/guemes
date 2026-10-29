shader_type spatial;
render_mode cull_disabled;
// Terreno de Justina: como terrain.gdshader, mas barro humedo cerca de la linea de agua (efecto de bajante).
varying vec3 world_pos;
varying vec3 world_normal;
uniform float color_gamma = 1.9;
uniform float water_level = 1.65;
float hash(vec2 p){ return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){ world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; world_normal=NORMAL; }
void fragment(){
 float n=noise(world_pos.xz*0.35)*0.65+noise(world_pos.xz*1.7)*0.35;
 float fine=noise(world_pos.xz*7.0);
 vec3 c=COLOR.rgb;
 float slope=1.0-clamp(normalize(world_normal).y,0.0,1.0);
 c=mix(c,vec3(0.56,0.47,0.33),smoothstep(0.25,0.6,slope)*0.35);
 vec3 albedo=pow(c,vec3(color_gamma))*(0.84+n*0.24+(fine-0.5)*0.06);
 float above=world_pos.y-water_level;
 float wet=above<0.0?1.0:1.0-smoothstep(0.0,0.5,above);
 albedo=mix(albedo,albedo*vec3(0.58,0.55,0.50),wet*0.75);
 ALBEDO=albedo;
 ROUGHNESS=mix(0.92,0.38,wet);
 SPECULAR=mix(0.3,0.55,wet);
}
