shader_type spatial;
render_mode cull_disabled;
varying vec3 world_pos;
varying vec3 world_normal;
uniform bool northern = false;
uniform float color_gamma = 1.9;
// C2 (pista P1, «Crónica en oro y noche»): en el Norte el color sale de una rampa por altura (valle → ladera → cresta),
// (valores en sRGB antes de la luz: el sol rasante #FFC282 y el grading cálido ponen el oro; con la rampa más saturada el relieve se veía naranja)
// se oscurece con la pendiente, lleva curvas de nivel suaves y se funde a tinta en el borde del mapa. Color de DISEÑO, no geología medida.
uniform vec3 valley_color : source_color = vec3(0.341, 0.294, 0.243);
uniform vec3 slope_color : source_color = vec3(0.580, 0.522, 0.420);
uniform vec3 crest_color : source_color = vec3(0.812, 0.761, 0.659);
uniform vec3 ink_color : source_color = vec3(0.055, 0.047, 0.071);
uniform float h_low = 0.4;
uniform float h_high = 15.0;
uniform float contour_m = 1.5;
uniform float contour_alpha = 0.16;
uniform float edge_m = 6.0;
uniform vec2 map_min = vec2(-55.0, -45.0);
uniform vec2 map_max = vec2(54.2, 45.0);
float hash(vec2 p){ return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){ world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; world_normal=NORMAL; }
void fragment(){
 float n=noise(world_pos.xz*0.8)*0.65+noise(world_pos.xz*3.0)*0.35;
 float fine=noise(world_pos.xz*9.0);
 vec3 c=COLOR.rgb;
 // Las pendientes fuertes se aclaran y ensucian un poco (roca); la normal viene suavizada del mallado indexado.
 float slope=1.0-clamp(normalize(world_normal).y,0.0,1.0);
 if (northern) {
  float h=world_pos.y;
  float t=clamp((h-h_low)/(h_high-h_low),0.0,1.0);
  vec3 r=mix(valley_color,slope_color,smoothstep(0.0,0.5,t));
  r=mix(r,crest_color,smoothstep(0.5,1.0,t));
  // Un resto del color de vértice (verde de los valles cerca de los pueblos) para que el relieve no sea un solo tono.
  vec3 v=pow(c,vec3(color_gamma));
  r=mix(r,v*1.15,0.22*(1.0-t));
  // ×0,7 a 45° (slope 0,29): las laderas fuertes se leen como sombra propia aunque el sol las toque.
  r*=mix(1.0,0.7,smoothstep(0.06,0.29,slope));
  r*=(0.90+n*0.16+(fine-0.5)*0.05);
  // Curvas de nivel cada contour_m, finas y antialiasadas; se apagan donde la pendiente las amontona.
  float hc=h/contour_m;
  float fw=max(fwidth(hc),1e-4);
  float d=abs(fract(hc+0.5)-0.5);
  float line=(1.0-smoothstep(0.0,fw*1.25,d))*(1.0-smoothstep(0.35,0.7,fw));
  r*=1.0-line*contour_alpha;
  // Borde del mapa: se funde a tinta en edge_m (el mapa no es una baldosa que flota).
  vec2 e2=min(world_pos.xz-map_min,map_max-world_pos.xz);
  float e=smoothstep(0.0,edge_m,min(e2.x,e2.y));
  ALBEDO=mix(ink_color,r,e);
  ROUGHNESS=0.93;
  SPECULAR=0.3;
 } else {
  c=mix(c,vec3(0.50,0.46,0.38),smoothstep(0.18,0.5,slope)*0.55);
  ALBEDO=pow(c,vec3(color_gamma))*(0.86+n*0.20+(fine-0.5)*0.05);
  ROUGHNESS=0.91;
 }
}
