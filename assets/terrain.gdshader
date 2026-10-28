shader_type spatial;
render_mode cull_disabled;
varying vec3 world_pos;
uniform bool northern = false;
float hash(vec2 p){ return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){ world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment(){
 float n=noise(world_pos.xz*0.8)*0.65+noise(world_pos.xz*3.0)*0.35;
 vec3 c=COLOR.rgb;
 ALBEDO=pow(c,vec3(1.9))*(0.88+n*0.20);
 ROUGHNESS=0.91;
}
