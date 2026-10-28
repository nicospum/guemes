shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;
varying vec3 world_pos;
uniform vec3 water_color: source_color = vec3(0.18,0.28,0.29);
uniform float water_level = 0.95;
float riverbed(vec2 p){
 float x=p.x,z=p.y;
 float coast=-8.0+0.6*sin(z*0.20);
 float land_weight=1.0-smoothstep(coast-0.8,coast+0.8,x);
 float land=0.75+clamp((coast-x)/24.0,0.0,1.0)*0.75+sin(x*0.15)*sin(z*0.12)*0.12;
 float bridge_center=14.0+0.25*sin(z*0.40);
 float bridge_width=4.0+0.30*sin(z*0.30);
 float bridge_distance=length(vec2(x-bridge_center,z-clamp(z,0.0,14.5)));
 float bridge_weight=1.0-smoothstep(bridge_width-0.8,bridge_width+0.8,bridge_distance);
 float south_center=14.5+0.35*sin(x*0.24);
 float south_width=3.8+0.45*sin(x*0.31+0.4);
 float south_distance=length(vec2(max(0.0,x-12.5),z-south_center));
 float south_weight=1.0-smoothstep(south_width-0.8,south_width+0.8,south_distance);
 float central_center=0.30*sin(x*0.21);
 float central_width=4.8+0.40*sin(x*0.27)+0.10*cos(x*0.63);
 float central_distance=length(vec2(max(0.0,x-14.0),z-central_center));
 float central_weight=1.0-smoothstep(central_width-0.8,central_width+0.8,central_distance);
 float bed=mix(-1.8,-0.17,bridge_weight);
 bed=mix(bed,-0.24+0.025*sin(x*0.30),south_weight);
 bed=mix(bed,-0.13+0.035*cos(x*0.35),central_weight);
 return mix(bed,land,land_weight);
}
void vertex(){
 world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 VERTEX.y+=sin(VERTEX.x*1.0+TIME*0.9)*0.021+sin(VERTEX.z*1.6+TIME*1.4)*0.018;
}
void fragment(){
 float wave=sin(world_pos.x*1.1+sin(world_pos.z*0.35)*1.5+world_pos.z*0.19+TIME*0.9);
 float ripple=sin(world_pos.z*1.35+sin(world_pos.x*0.42)-world_pos.x*0.21+TIME*0.65);
 float ground=riverbed(world_pos.xz);
 float depth=max(0.0,water_level-ground);
 ALBEDO=mix(vec3(0.08,0.17,0.17),vec3(0.025,0.10,0.14),smoothstep(0.3,1.8,depth))+vec3((wave+ripple)*0.008);
 METALLIC=0.0;
 ROUGHNESS=0.34;
 SPECULAR=0.55;
 NORMAL_MAP=vec3(0.5+wave*0.035,0.5+ripple*0.035,1.0);
 NORMAL_MAP_DEPTH=0.55;
 ALPHA=clamp(0.52+depth*0.4,0.52,0.99);
}
