shader_type spatial;
render_mode cull_disabled;
varying vec3 world_pos;
varying vec3 world_normal;
uniform bool northern = false;
uniform float color_gamma = 1.9;
float hash(vec2 p){ return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){ world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; world_normal=NORMAL; }
void fragment(){
 float n=noise(world_pos.xz*0.8)*0.65+noise(world_pos.xz*3.0)*0.35;
 float fine=noise(world_pos.xz*9.0);
 vec3 c=COLOR.rgb;
 // Las pendientes fuertes se aclaran y ensucian un poco (roca); la normal viene suavizada del mallado indexado.
 float slope=1.0-clamp(normalize(world_normal).y,0.0,1.0);
 c=mix(c,vec3(0.50,0.46,0.38),smoothstep(0.18,0.5,slope)*0.55);
 ALBEDO=pow(c,vec3(color_gamma))*(0.86+n*0.20+(fine-0.5)*0.05);
 ROUGHNESS=0.91;
}
