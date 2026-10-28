shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;
varying vec3 world_pos;
uniform vec3 water_color: source_color = vec3(0.18,0.28,0.29);
uniform float water_level = 0.95;
uniform float wade_depth = 0.55;
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
 // Mismas reglas que GameRules.is_walkable: vadeable si la profundidad es <= wade_depth.
 float wade=1.0-smoothstep(wade_depth-0.04,wade_depth+0.04,depth);
 float deep=smoothstep(0.3,1.8,depth);
 vec3 shallow_col=vec3(0.20,0.27,0.22);
 vec3 mid_col=vec3(0.08,0.17,0.17);
 vec3 deep_col=vec3(0.025,0.10,0.14);
 vec3 col=mix(mid_col,deep_col,deep);
 col=mix(col,shallow_col,wade*0.75);
 // Espuma en la orilla y en el borde de vado (aprox. +-0.07 de profundidad).
 float shore=1.0-smoothstep(0.0,0.10,depth);
 float edge=1.0-smoothstep(0.0,0.07,abs(depth-wade_depth));
 float streak=0.5+0.5*sin(world_pos.x*2.3+world_pos.z*1.7+TIME*1.2+wave*1.5);
 float foam=clamp((shore*0.9+edge*0.55)*(0.55+0.45*streak),0.0,1.0);
 float fres=pow(1.0-clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0),3.0);
 ALBEDO=col+vec3((wave+ripple)*0.008)+vec3(0.55,0.60,0.58)*foam+vec3(0.04,0.06,0.07)*fres;
 METALLIC=0.0;
 ROUGHNESS=mix(0.18,0.6,foam);
 SPECULAR=0.35;
 NORMAL_MAP=vec3(0.5+wave*0.035,0.5+ripple*0.035,1.0);
 NORMAL_MAP_DEPTH=0.55;
 ALPHA=clamp(mix(0.52+depth*0.4,0.40,wade)+foam*0.5,0.35,0.99);
}
