# Render y rendimiento (fase 2, pista render)

## Decisión de renderer
- `project.godot` pasa de Compatibility a **Forward+** (Vulkan). `rendering_device/fallback_to_opengl3=true` y `rendering_method.mobile/web=gl_compatibility` dejan el camino de máquinas modestas.
- Forzar Compatibility (OpenGL): `godot --rendering-method gl_compatibility` (o `--rendering-driver opengl3`). Verificado en esta PC con ese flag; el fallback automático cuando no hay Vulkan **no se probó** (la PC tiene Vulkan 1.4).
- Los shaders y `world_view.gd` funcionan en ambos. Los efectos extra (SSAO, glow, niebla volumétrica, sombras en 4 cortes) solo se activan si el renderer no es Compatibility (`advanced_renderer`) y el perfil no es `baja`.
- Exportar para Linux/xvfb (QA de 0.1.0) requiere ajustar el preset o usar `--rendering-method gl_compatibility`; no se probó aquí.

## Perfiles
| Perfil | Forward+ | Compatibility |
|---|---|---|
| baja | escala 3D 0,5, sin sombras ni MSAA, 2 figuras/grupo, sin efectos | igual |
| media | sombras 2 cortes, MSAA 2x, SSAO, glow, ajuste de color | sombras, MSAA 2x |
| alta | media + MSAA 4x, sombras 4 cortes, niebla volumétrica leve | MSAA 4x (igual que media en costo) |
(MSAA y escala 3D los fija `main.gd`; no se tocó.)

## Cambios en `world_view.gd`
- Casas, árboles, chimenea y caminos de Norte pasan a 5 `MultiMeshInstance3D` (lotes `Lote_box`, `Lote_prism`, `Lote_cyl8`, `Lote_cyl12`, `Lote_sphere`) con color por instancia y un solo material. Antes: 516 `MeshInstance3D` en Norte.
- Rutas: un único `MultiMesh` persistente (`refresh_paths` ya no destruye y crea nodos).
- Terreno indexado (`SurfaceTool.index()`): normales suaves en lugar de facetas.
- Etiquetas 3D `fixed_size` (`LABEL_PIXEL_SIZE`), tamaño constante en pantalla; el texto solo se reasigna si cambió.
- Animaciones de figuras en pausa real (`pause()`) cuando no se mueven.
- API pública y nombres de nodos consumidos por `main.gd` sin cambios (`build`, `update_state`, `refresh_paths`, `pick_*`, `selected*`, `show_paths`, `cannon_effect`). Cambia internamente: casas y árboles ya no son nodos individuales; las etiquetas de Label3D siguen existiendo (`find_children("*","Label3D")` funciona).

## Agua y terreno
- `water.gdshader`: la profundidad sigue saliendo de la misma función `riverbed()` y el umbral de vado `wade_depth = 0.55` es el de `GameRules.is_walkable` (nivel - terreno <= 0,55). Vadeable = más claro y transparente; espuma en la orilla y en el borde del vado; fresnel leve. Cambia el nivel (bajante) y todo se mueve con él.
- `terrain.gdshader`: pendiente fuerte aclara a roca, ruido fino, `color_gamma` (1,9 en Compatibility; 2,6 en Forward+, ajustado a ojo para que el brillo se parezca).

## Método de medición
Equipo: Ryzen 9 7950X, RTX 3080 Ti, Windows 11, Godot 4.7.2 desde el proyecto fuente (no EXE exportado), ventana 1440x900, `--disable-vsync`, audio Dummy, APPDATA aislado.
1. `tools/benchmark.py` (usa `--benchmark=` de main.gd: 30 cuadros de calentamiento + 180 medidos, 3 repeticiones). Los 180 cuadros duran 0,2-0,7 s: es una muestra corta.
2. `tools/bench_gpu.gd` + `tools/bench_gpu_matrix.py`: 60 cuadros de calentamiento + 600 medidos, 2 repeticiones, con tiempo de GPU del motor, draw calls y primitivas.
Datos crudos en `evidence/fase2/render/`.

## Resultados (FPS medios, `benchmark.py`, 3 repeticiones)
| Escenario / perfil | Antes (Compat, código 0.1.0) | Después Compat | Después Forward+ |
|---|---|---|---|
| Justina baja | 478 | 489 | 1544 |
| Justina media | 245 | 248 | 966 |
| Justina alta | 243 | 245 | 921 |
| Norte baja | 450 | 461 | 1628 |
| Norte media | 235 | 286 | 1035 |
| Norte alta | 233 | 283 | 978 |

Con `bench_gpu` (600 cuadros): Forward+ tiempo de GPU mediano 0,16-0,89 ms; en Compatibility Justina media/alta 3,96 ms (las figuras con piel dominan, como en la auditoría). Draw calls contados por el motor (incluye pasadas de sombra): 244-246 en baja, ~600 en media/alta; primitivas 81k-303k.

Metas: 60 FPS en alta y 30+ en baja se cumplen con amplio margen en esta GPU. No se midió GPU integrada ni hardware modesto: no hay evidencia para ese caso.

## Límites conocidos
- Ganancia grande de Forward+ sobre Compat en Justina: viene del renderer, no de los lotes (con Compat Justina no mejora; Norte sí, por menos draw calls).
- No se reemplazaron las figuras con piel (12 jinetes ~12.900 triángulos cada uno): sigue siendo el costo dominante en Compatibility. LOD o modelos más livianos requieren cambiar los GLB.
- El fallo de fuga de texturas GL al cerrar en Compatibility ya existía; no se investigó.
- El ajuste de brillo entre renderers y los colores del agua son criterio visual, comparado sobre capturas, no medido colorimétricamente. Las etiquetas pueden seguir solapándose cuando hay unidades juntas.

## Justina ronda 4: aspecto (terreno continuo, agua del Plata, proporciones)
Retroalimentacion de la preview 3: una zona "definida" y el resto generico y plano, proporciones dudosas, rio feo (marron plano con ondas repetidas). Pista: solo aspecto; no cambia geometria ni reglas (`data/justina_map.json` sin tocar, `game_rules.gd`/`main.gd`/`tests/` sin tocar).

### Que cambio
- **Terreno continuo hasta el horizonte.** `shaders/terrain_justina_r4.gdshader` (mapa y horizonte comparten material). Una malla de horizonte con vertices cada 4 m en el borde del mapa (sin grietas), costa que serpentea suavemente fuera del mapa y lomadas bajas en la meseta (`_far_h`, identico a Reglas dentro de 0..900 x 0..520). Color: pasto de invierno oliva-paja en parches de ~250 m, tierra pelada, matorral, huellas de carreta, estratos de tosca en la barranca, playa con rizado de arena, juncal sobre la linea de agua alta y barro humedo cerca del agua (sigue el nivel de la bajante).
- **Paisaje.** Toscas al pie de la barranca (`rock_cluster`), juncales (tallos pajizos), ~620 matorrales dentro del mapa y ~700 fuera, algarrobos/talas lejanos, quintas al norte y la ciudad al sur (cuadras de ~117 m como en Boneo 1801, dos iglesias). Alameda con arboles de 8-12 m.
- **Rio.** `shaders/water_rio_plata.gdshader`: pardo-verdoso turbio (no azul), mas claro y arenoso cerca de la orilla, mas oscuro lejos; dos octavas de ruido (olas de ~25 m y ~7 m, direcciones distintas) mas rizado fino de ~1,6 m solo cerca, sin textura => sin mosaico; reflejo del cielo por Fresnel, brillo suave, espuma sutil en la orilla con ruido y lavado. Una sola malla del pie de la barranca al horizonte. **No filtra el fondo oculto:** el degradado de color usa el perfil base `bed_profile` por x (UV2) y el suelo real solo aparece en el halo de `visible_depth_m` (0,3 m) y la espuma de contacto, como antes. Los bancos y vados se ven al bajar el nivel porque el suelo real emerge (arena clara con rizado) y el barro humedo sigue la linea de agua.
- **Cielo y niebla.** `shaders/justina_sky.gdshader`: capa de nubes (invierno, nublado, viento), horizonte igual a la niebla. Niebla de profundidad desde 350 m hasta 3700 m (curva 1,9): el horizonte se funde sin linea. Sol mas bajo y frio (12 de agosto).
- **Proporciones.** Buque: casco estirado a 40 m de eslora x ~10,5 m de manga (antes 37 x 14,5; el GLB mide 16,8 x 6,6 a escala 1) con constantes `SHIP_SX/SY/SZ`; los 13 canones por banda siguen el nuevo ancho. Jinetes `RIDER_SCALE` 0,9 -> 0,82 (caballo ~2,8 m de largo, jinete con lanza ~2,5 m; infanteria a pie 1,75 m sin cambio). Carpas del campamento 4x2,8x5 -> 3,2x2,2x4,2 m. Balizas lejanas: poste fino y rombo chico (antes pelotas blancas que tapaban el paisaje). Arboles de la Alameda 4-7 m -> 8-12 m.
- **Escala y referencias.** Barra de 100 m (tramos de 10 m alternados, mastiles en 0/50/100) sobre la playa en x=197, z=312-412, con rotulo "Escala · 100 m"; rotulos "Linea de agua" (sigue el nivel) y "Pie de la barranca". Las demas referencias (orilla, barranca, Alameda, fuerte=Bateria Abascal, buque, banco central) son los rotulos de hito ya existentes; el banco central no se rotula en 3D para no delatar el fondo.

### Fiel a fuentes vs reconstruccion estetica
- Documentado/tradicion (sin cambio): buque mercante britanico de 26 canones (Gillespie 1818), Plaza de Toros del Retiro (Boneo 1801, Vidal 1820 lamina 05), batería, barranca sobre el rio. Sin bandera argentina ni Infernales; Guemes sigue como tradicion no probada.
- Reconstruccion estetica (no hay registro): color y textura del pasto, matorral, huellas, juncales, toscas, nubes, la ciudad al sur y las quintas del norte (la trama de Boneo da solo el tamaño de cuadra), la costa que serpentea fuera del mapa, la forma de las olas, las proporciones exactas del casco (eslora/manga ~4 es tipica de un mercante de la epoca, no un dato del buque), y los colores del agua (paleta de las laminas de Vidal; criterio visual comparado sobre capturas, no medido).
- El fondo del agua (bancos, pozo oculto) sigue siendo diseño de Reglas y no se pinta hasta que lo reconoce el jugador o baja el rio.

### Evidencia y medicion
- Capturas en `evidence/justina-ui/ronda4/`: `antes_*` (preview 3), `r1_*` (primera iteracion: agua demasiado oscura, balizas gruesas, rotulos pisados) y `final_*` (17 vistas: inicial, cenital, ver todo, costa, barranca, orilla baja, rio y buque, buque cerca, Alameda y fuerte, grupos, bajante, y extremos de camara hacia costa, norte, sur y yaw 180). Generadas con `tools/vis_run.sh` (ventana real 1440x900, Forward+, RTX 3080 Ti); no hay capturas de Compatibility (no se probo ese renderer en esta ronda).
- Se compararon 3 iteraciones sobre las capturas (antes, r1, final); sin costuras ni z-fighting visibles en las vistas extremas listadas, pero no hay una prueba automatica de eso.
- `tools/benchmark.py --scenarios justine --repeat 3 --renderer forward_plus --max-frame-ms 3`: cuadro medio (max de 3 repeticiones) media 2,30 ms, alta 2,80 ms (baja 1,87 ms medido en la primera pasada de shaders, mas pesada). Antes de esta ronda: media 1,61 ms, alta 1,45 ms. Cumple 3 ms pero con menos margen: el costo viene del sombreado de agua y terreno a pantalla completa.
- Tests: `tests/test_rules.gd` y `tests/test_integration.gd` con APPDATA aislado: 0 fallos (181 checks de integracion), 0 errores de shader.

### Pendiente / limites
- Los GLB de arboles son claros: se oscurecen con `GLB_TINT` en `world_view.gd`, no en el archivo.
- Compatibility no verificado visualmente (los shaders usan solo funciones comunes).
- La barra de 100 m es de mundo; la barra de escala de la interfaz (esquina del minimapa) es de `main.gd`.
- El circulo de alcance del buque (rojo/amarillo) es de `main.gd`/Reglas y domina visualmente el rio; no se toco.
- Las pistas de interfaz y turnos (claridad del manejo de tropas, por turnos o en tiempo continuo) son de otra pista.

## Justina ronda 1 (visual): paquete Retiro 1806, agua, circo, guiones, pabellón
Pista visual sola; no cambia geometría ni reglas (`data/justina_map.json`, `game_rules.gd`, `main.gd` sin tocar). Parte del commit 82f7135 (ronda 4), evaluado con capturas `base_*` y mejorado.

### Qué cambió
- **Agua** (`shaders/water_rio_plata.gdshader`): pardo-ocre turbio con plumas de sedimento a escala de cientos de metros (zonas ocre y zonas verdosas), más oscuro y frío mar adentro; reflejo del cielo por Fresnel y destello solar amplio. **Espuma de orilla continua**: gradiente por profundidad real, sin umbral de ruido binario (se acabó el "granulado" blanco sobre los bancos). Un solo tono de agua; solo cambia la transparencia con el nivel.
- **Orilla** (`shaders/terrain_justina_r4.gdshader`): la línea de humedad serpentea (ruido de ~20 m) y pasa arena seca, arena húmeda y barro con degradado suave; independiente de la forma de la costa (geometría de la pista de mapa).
- **Plaza de Toros**: exterior **octogonal** de lado a lado según `radius_m` del JSON (radio de vértices), muro encalado (Lino crudo #D8CFB8), teja (paleta), 4 portales, gradas de madera, ruedo circular independiente (la mitad del radio). Bandera blanca con escudo pintado: **inferencia** (cuenta de 1803, paquete H4), sin escudo argentino. Si la pista de mapa sube el radio (el paquete propone 90 m entre vértices), el dibujo lo sigue.
- **Alameda**: arboleda **irregular** (separación 14-38 m, un solo lado al azar, desfase lateral; paquete C: no extender una avenida uniforme). Es Diseño.
- **Guiones de grupo** (`GROUP_PAL`): asta + banderín con paleta del paquete (Güemes: Azul del Fijo #253B53 + Encarnado #983C3C; Voluntarios: Lino #D8CFB8 + Ropa civil #7B6953; Reserva: Arena #A38D6B + Azul marinero #33475B). Son marcadores de DISEÑO para distinguir grupos, no estandartes históricos. Crecen con la distancia de cámara (legibles al alejar, 1 u = 1 m de cerca) junto a un anillo de ancla.
- **Pabellón del buque**: Red Ensign (campo rojo #B6453E, cantón con Union posterior a 1801) en la popa. **Hipótesis/Reconstrucción** (H1): la bandera concreta del Justina no está identificada. Sin White Ensign, sin bandera argentina.
- **Barra de escala**: rótulo con contorno oscuro grueso (legible sobre el pasto).
- Verificado que `enemy_marker`/"REALISTAS"/`royalist_1817` solo se crean en `_north()` (Norte), nunca en Justina.

### Fiel a fuente vs estética reconstruida
- Fiel (según paquete): octógono del circo, contraste barranca/ribera, mercante armado con 26 piezas, casco ~40 x 9-10 m (diseño por comparables RMG), Red Ensign como hipótesis, bandera blanca del circo como inferencia, sin Torre/estaciones/jardines modernos.
- Estética reconstruida: color del agua (referencia Vidal 1820, no medido), plumas de sedimento, olas, colores de pasto/tosca, guiones de grupo, forma exacta de las puertas del circo, tejas. Colores = paleta de diseño del paquete (no tintes medidos).

### Evidencia y medición
- Capturas con ventana real (1440x900, Forward+, RTX 3080 Ti) en `evidence/justina-ui/calidad_r1/`: `base_*` (antes) y `final_*` (21 vistas, incl. grupo cerca, circo desde el norte, buque, panorama alto). Generadas con `tools/vis_run.sh`.
- Benchmark `benchmark.py` justine, 3 repeticiones, forward_plus: baja 1,45 ms, media 2,27 ms (máx 2,28) de cuadro medio < 3 ms.
- `test_rules` 474/0, `test_integration` 181/0, `ui_qa` 1280x720 sin fallos (60 checks reportados).

### Pendiente
- Costa casi recta, ciudad alta/Santa Catalina/Fuerte y área 900x750: geometría, de la pista de mapa. El cono de fuego rojo y las etiquetas (`main.gd`) dominan el río: de la pista de interfaz.
- Marineros/jinetes con ropa del paquete (G2/G4): los GLB `rider_1806` no se rehicieron; sin carros, botes ni ciudad a escala de fondo.
- Compatibility no verificado visualmente.

## Justina ronda 2: aspecto (rio, abanico de fuego, paleta, buque, rotulos)
Pista visual de la ronda 2. No cambia geometria ni reglas (`main.gd`, `game_rules.gd` y el JSON sin tocar).

### Que cambio
- **Rio** (`shaders/water_rio_plata.gdshader`): tres tonos (limo claro sobre bajos, verde-pardo turbio, canal oscuro y frio; antes beige-rosado), reflejo del cielo por Fresnel mas contenido (el borde ya no se lava a crema), mas relieve de ola (rizado cruzado de 3 escalas + brillo solar), linea de agua nitida con espuma fina modulada por ruido y segunda franja de lavado tenue (adios al "peine" regular), arena mojada translucida en el primer centimetro.
- **Buque sobre un bajo**: ovalo de agua mas clara alrededor del casco y espuma de contorno (el casco se lee apoyado, no flotando); es DISEÑO coherente con "banco parcialmente inundado", no una cota medida. Anillo punteado de 120 m = zona de incertidumbre de la posicion (`ship.uncertainty_radius_m`, diseno), sin relleno.
- **Abanico de fuego** (`_exposure_j`): relleno <= 0,075 (limite del JSON: 0,12) con degradado desde el buque; el contorno rojo (#B6453E aprox.) lleva la lectura. Ya no es un disco que domine el agua.
- **Paleta**: pasto/paja/tierra hacia el ocre-oliva de Vidal (`suelo_alto`, `vegetacion_baja`), cielo y niebla con bruma crema amarillenta, casas con variacion de color por instancia (lino crudo a arena, `_glb_variation`) y techos mas apagados, circo con lino y teja apagada.
- **Buque**: pabellon de 3,2 x 1,8 m (antes 4,6 x 2,6; ~1/12 de la eslora). Comentario de las portas corregido: 13 por banda es DISEÑO (Gillespie da 26 canones en total, no el reparto).
- **Unidades y rotulos**: aro de seleccion 7,5 m y mas fino y translucido (antes 9 m); guion con silueta por grupo (rectangular, banderin largo, cuadrado), no solo color; rotulo compacto "marca + numero + fuerza" a mas de 230 m (la marca de tradicion se ve siempre); "Escala" pasa a "100 m" al final de la barra, con alcance de 260 m; "Pie de la barranca" anclado al pie real con un poste; ya no cruza la ruta.

### Fiel a fuente vs estetica reconstruida
- Fiel/tomado de fuente: paleta del paquete (laminas 04 y Vidal) para uniformes, guiones y colores base; Red Ensign como hipotesis rotulada; sin bandera argentina ni Infernales; 26 canones totales (Gillespie 1818); circo octogonal (Boneo 1801 / Vidal).
- Reconstruccion estetica (sin registro): color y relieve del agua, bajo claro bajo el casco, espuma, nubes, bruma, tinte de casas, silueta de guiones (colores de diseno, no estandartes historicos).

### Medicion
- `tools/benchmark.py --scenarios justine --repeat 3 --renderer forward_plus --max-frame-ms 3`: media 2,09 ms, baja 2,06 ms (maximo de repeticiones 3,0 ms por la primera pasada de shaders). Presupuesto OK.
- test_rules 504/0, test_integration 232/0, jev_contract 15/0, ui_qa 125/0 en 1280x720 y 1920x1080.
- Capturas: `evidence/justina-ui/calidad_r2/` (21 vistas finales JPG q82 con ventana real, mas 3 `antes_*`). `tools/vis_run.sh <tag> <filtro> <carpeta>`.

### Pendiente
- La escalera del GLB del buque sigue (no hay Blender ejecutable en esta maquina; `tools/create_models.py` la genera: borrar el bloque "Boarding ladder" y regenerar con `--only justine`).
- Popa del casco (transom plano), sombras de contacto en rocas/matas, trama de manzanas y quintas (casas aun dispersas), capturas de combate/victoria y marea baja comparable no se hicieron en esta pista.
- Compatibility no se verifico visualmente. Texto de history.json/time.note sobre Gillespie y el viento: es de otra pista (datos).

## Justina ronda 3: aspecto (pista visual)
Pista: solo aspecto (`world_view.gd`, `shaders/`, `tools/create_models.py`). Sin cambios de geometria, reglas ni JSON. Fuente principal: paquete de investigacion del usuario (paleta `04_paleta_diseno`, referencia Vidal c. 1817-20, informe D3/D5/G7/H); detalle de que se tomo de donde en `docs/historia/VISUAL_R3.md`.

### Que cambio
- **Rio** (`water_rio_plata.gdshader`): del beis lechoso a un gradiente turbio verde-botella (canal) a verde-limo (bajos) con plumas de sedimento de 200-400 m en dos escalas (verde alga a pardo limo), vetas de viento alargadas, ondas con mas contraste de normal, opacidad minima 0,86 (la arena del fondo ya no lava el color), bruma de horizonte desde 1300 m hacia el crema de Vidal y espuma de contacto reforzada alrededor del casco con oscurecimiento (sombra) justo en la flotacion.
- **Terreno** (`terrain_justina_r4.gdshader`, colores de vertice): pasto menos saturado y mas ocre-pardo (verde 0,42/0,40/0,23; paja 0,66/0,57/0,37), matorral pardo, franja de barro humedo con borde irregular por ruido, manchas de barro con borde difuso sobre la playa (ya no ovalos duros).
- **Props** (`justina_props.gdshader`, un solo material para todos los lotes de cajas, cilindros y esferas): revoque envejecido con manchas y vetas de lluvia, juntas de ladrillo/adobe en desconchados, hileras de teja en techos rojizos. Muros del circo, bateria, casas de azotea y matas lo usan.
- **Matas y casas**: matas de tamaño y tono muy variados (achatadas/altas, mas ocre) con sombra de contacto; casas lejanas con ~38 % de azotea con parapeto (Vidal), alturas variables y 4 iglesias (antes 2).
- **Buque**: la escalera rigida del costado se quita en carga (`_strip_ladder`, filtra los triangulos de madera de la caja de la escalera; `tools/create_models.py` ya NO se regenero porque Blender no esta instalado en esta PC: queda el GLB original, ver pendientes). Se mantiene bandera Red Ensign post-1801.
- **Rotulos de los anillos**: "Alcance del fuego del buque (diseño)" y "Zona de incertidumbre del encallamiento (±120 m, diseño)" (el anillo rosa y el punteado no tenian leyenda).

### Fiel a fuente vs estetica reconstruida
- Fiel/derivado de fuente: paleta (paquete G7: Lino crudo, Arena/tierra, teja apagada, Buff), bandera del buque = Red Ensign posterior a 1801 como HIPOTESIS (H1), sin bandera argentina ni Infernales, bandera blanca del circo (H4, inferencia de 1803), horizonte bajo crema de Vidal, casas de azotea y torres de iglesia como en Vidal.
- Reconstruccion estetica (sin registro): todas las texturas y manchas, color y turbidez del agua, plumas de sedimento, forma de las matas, reparto de azoteas, ubicacion de las iglesias.

### Medicion
Ver `evidence/justina-ui/calidad_r3/benchmark.json` y la seccion de resultados en el informe de la ronda.

## Justina ronda 4 (segunda pasada): bancos, rio, buque a la bajante
Solo aspecto. Sin cambios de geometria, `game_rules.gd`, `main.gd` ni `data/justina_map.json`.

### Que cambio
- **Agua** (`shaders/water_rio_plata.gdshader`): colores tomados de la paleta del paquete (`water.shallow #8F9B84`, `mid #6F8281`, `deep #52696E`; lamina 04, "aproximaciones digitales, no valores historicos"); se baja la veta direccional y se agregan dos escalas de variacion de 400-900 m (pluma parda y agua mas limpia) para que no sea una lamina uniforme; menos emision de cielo (menos lechoso). El borde del halo/espuma usa ruido de dominio, por lo que los bancos dejan de verse como capsulas (el alfa sigue usando la profundidad real: no se filtra fondo oculto nuevo).
- **Terreno** (`shaders/terrain_justina_r4.gdshader`): transicion barro-arena y manchas humedas con ruido estirado y torcido (meandros, no circulos).
- **Buque a la bajante** (`world_view.gd`): con el rio bajo el casco escora (0,13 rad) y se asienta 0,30 m; sin estela ni espuma de casco; aclarado arenoso bajo el casco. Con el rio alto vuelve a flotar. La regla del vado no cambia (el calado sigue siendo de diseno).
- **Retiro**: casas en manzanas de dos con tapia; dependencias bajas (reconstruccion de volumen) junto al circo; teja con el tono apagado del paquete (`#8E5A47`), no rojo saturado. Matorral de transicion fuera del tablero para que el detalle del pasto no se corte en el borde.
- `tools/vis_shots.gd`: vistas 22-24 (buque al minimo, banco, circo); `_tide(660)` es la bajante sostenida.

### Fiel a fuente / reconstruido
- Paleta (paquete lam. 04; Vidal 1820): criterio visual, no medida. Casas de azotea y tapias: reconstruccion (Vidal). Dependencias del circo y escora del casco: reconstruccion/diseno. Pabellon rojo del buque: hipotesis (Red Ensign), sin bandera argentina.

### Medicion
`tools/benchmark.py` Forward+ justine (3 rep.): baja 1,56 ms, media 2,40 ms de cuadro medio (< 3 ms). `tests/test_rules.gd` (520 checks), `test_integration.gd` (245), `jev_contract_test.gd` (15): 0 fallos, APPDATA aislado. Capturas: `evidence/justina-ui/calidad_r4/` (`base_*` = antes, `final_*` = despues, 1440x900 Forward+).

### Pendiente
- El casco GLB sigue con popa plana y no se regenero (sin Blender usado); el banco sigue sumergido 0,25 m (diseno de reglas): no emerge arena en la bajante, solo aclara el agua.
- No se agrego indicio de vado a simple vista: contradice la regla de no filtrar fondo oculto (decision de reglas).
- Chips de grupos solapados, camara inicial y carteles del anillo: son de `main.gd` (otra pista).
- `tools/ui_qa.gd` a 1440x900 reporta 56,5 % libre (<60 %); se corre en 1280/1920/2560 segun el protocolo, no medido aqui.
- Costa recta y pendiente 8-12 % del paquete: geometria, de la pista de mapa.

## Justina ronda 5: aspecto (pista visual)
Solo aspecto: no cambia geometria, reglas, `main.gd` ni `game_rules.gd`. Capturas `antes_*` y `final_*` (24 vistas cada una, ventana real 1440x900, Forward+) en `evidence/justina-ui/calidad_r5/`; benchmark en `calidad_r5/bench.json`.

### Cambios
- **Rio.** Causa de la lamina pálida casi blanca: no era el color base sino el reflejo especular del cielo (Forward+) y la emision Fresnel. Se bajo `SPECULAR` 0,5 -> 0,12, rugosidad 0,10 -> 0,22, emision Fresnel x0,5 (exponente 5), brillo solar y bruma de horizonte; colores base a limo ocre-oliva (cerca), pardo-oliva (medio) y verde botella turbio (canal), tomados de la paleta "Arena/tierra" apagada. Sigue sin textura (sin mosaico) y no delata el fondo oculto.
- **Fuerte/circo (H4 del paquete).** La bandera era un cuadrado rojo sobre blanco (se leia como otra bandera). Ahora pano blanco con escudo pintado (borde laton, cuarteles rojo/crudo, corona esquematica). Inferencia (cuenta de 1803, Pillado): escudo exacto, tamaño y estado el 12-ago **sin datos** (Diseño). Sin escudo argentino.
- **Red Ensign (H1).** El canton ahora lleva Union de 1801 esquematica: aspa blanca de San Andres, aspa roja fina de San Patricio, cruz blanca y roja de San Jorge. Sigue siendo hipotesis (la bandera del Justina no esta identificada).
- **Guiones de grupo.** Eran postes de 6 m escalados hasta x7 de lejos (antenas de 40 m). Ahora asta de 3,8 m y guion chico (1,5 x 0,9 m), x3 maximo de lejos. Colores de paleta neutros (latón/cuero, lino/cuero, azul marinero/lino): son marcas de lectura de **Diseño**, no estandartes historicos ni colores de bando (el paquete lo advierte); se quita el azul del Fijo y el encarnado que sugerian un regimiento.
- **Bateria de las piezas de a 18.** Dos piezas (unica cifra con fuente, parte de Liniers del 11-ago via L. Guemes), 5 gaviones; emplazamiento y parapeto = Diseño. Corregido el comentario que llamaba "documentada" a la bateria.
- **Buque apoyado (`ship.grounded_visual`).** Ahora se consume: escora de 4-7 grados, asiento de 0,6 m y anillo de fango/arena humeda (22-34 m) con interpolacion entre `floating_above_m` 0,9 y `grounded_below_m` 0,35. Diseño (Gillespie: "left dry"; calado desconocido).
- **Ciudad alta.** Tres franjas de casas de azotea y hasta 7 torres de iglesia al oeste de la meseta (x -110 a -480), mas densas hacia el sur. Reconstruccion estetica: de Boneo 1801 solo se toma el tamaño de cuadra y que la traza sube al oeste/sur; lotes y torres son Diseño.
- **Aro de alcance de fuego.** Mas fino (1 m, antes 2 m) y mas tenue (alfa 0,26, antes 0,55).

### Fiel a fuente vs estetica
Fiel/documentado: buque mercante britanico armado (Gillespie), Plaza de Toros (Boneo 1801, Vidal 1820), existencia de dos piezas de a 18 por cita. Tradicion: Guemes. Reconstruccion/Diseño: color del rio y del terreno, bandera del fuerte (escudo), Union del Red Ensign, ciudad lejana, bateria, guiones, anillo de fango.

### Medicion
`benchmark.py --scenarios justine --repeat 3 --renderer forward_plus --max-frame-ms 3`: baja 1,60 ms, media 2,35 ms de cuadro medio (OK < 3 ms). `tests/test_rules.gd` 520 checks 0 fallos; `tests/test_integration.gd` 248 checks 0 fallos (APPDATA aislado).

### Pendiente
- Jinetes/caballos: siguen con la piel del GLB (no se retintaron con la paleta; requiere regenerar `rider_1806.glb`). Popa plana del casco: corresponde a `tools/create_models.py`/Blender, no se toco el GLB.
- Camino de la barranca rojiblanco, rotulos superpuestos, camara inicial y textos de briefing: son de `main.gd`/mapa/UI (otras pistas).
- Compatibility y 2560x1440 reales sin verificar visualmente. Bancos que emergen: se ven al bajar el nivel (comportamiento previo), sin cambio.
- Hallazgos de historia (etiquetas Reconstruccion->Diseño, p. 94 de Gillespie vs alcance de 265 m, citas de pagina, acantilados 1807) pertenecen a la pista de mapa/historia.

## Justina ronda 6: aspecto (pista visual)
Solo aspecto: no cambia geometria, reglas, `main.gd` ni `game_rules.gd`. Capturas `antes_*` y `final_*` (27 vistas, ventana real 1440x900, Forward+) en `evidence/justina-ui/calidad_r6/`; UI en `calidad_r6_ui/`; benchmark en `calidad_r6/bench.json`.

### Cambios
- **Rio.** `water_rio_plata.gdshader` consume ahora `palette.water.turbid_near/mid/far` (antes ignoradas). Mas contraste: crestas claras y senos oscuros, manchas de viento de 20-50 m, borreguitos alargados de espuma lejos de la orilla, menos reflejo del cielo (Fresnel x0,4) y menos bruma. Niebla del entorno de 350-3700 m a 650-4200 m (curva 2,2): el terreno medio ya no se lava a crema. Sigue sin textura (sin mosaico) y sin delatar el fondo oculto.
- **Banco bajo el buque.** El disco de borde circular era un cilindro (`ship_mud`). Ahora es un plano con `shaders/justina_mud.gdshader`: borde erosionado por ruido, arena a fango humedo, sin circulo.
- **Buque.** Se quita la pala del timon (placa vertical que parecia suelta en la popa) con el mismo filtro de triangulos que la escalera. Crece hasta x2,3 con la distancia de camara (tamaño minimo en pantalla; simbolico, nunca mas de 2,3 veces), junto con el pabellon. La popa plana del GLB sigue sin regenerar (ver pendientes).
- **Jinetes y caballos.** La piel del GLB se leia plateada (rugosidad/metal del mapa `rm`) y el color de vertice del GLB no mostraba bando. `_tinted_mesh` reclasifica los colores de vertice a `palette.riders` (casaca, vueltas, calzon, sombrero, camisa) y `palette.mounts` (pelaje por grupo: tostado, alazan, o uno al azar de 6 para exploradores) y pasa telas y pelaje a mate. Son colores de DISEÑO (el JSON lo declara), no uniformes documentados.
- **Lectura de unidades.** Las figuras de un grupo crecen con la distancia de camara (x1 hasta ~160 m, hasta x3,4), con mayor separacion; guion hasta x3,4 y aro de ancla hasta x6. Colores y asta del guion salen de `banners.group_markers` del JSON: Reserva ya no es azul-blanco-azul (se leia como bandera argentina) sino arena y cuero.
- **Rotulos de hito.** Todo hito de diseño o tradicion lleva `(diseño)` / `(tradición)` (usa `marker_suffix` del JSON; sin ese campo, segun la etiqueta). Un hito sin `tag` pasa a `diseno` (antes `documentado`); idem `labels_extra`. El nombre con sufijo tambien llega a `landmark_info` (lo muestra la interfaz).
- **Zona de Gillespie.** Segundo anillo punteado y muy tenue a `ship.fire.cover_zone.range_m` (420 m) con rotulo "no simulado, diseño"; solo se ve con la capa de fuego.
- **Retiro.** Las tapias eran tablones rectos que salian de las casas; ahora cierran un patio de cuatro lados cortos (con porton), asentados en el terreno. Matorral: mata baja, mata angulosa (prisma inclinado) y mechones de paja, tonos de `palette.terrain` (vegetacion_baja, arena_tierra, suelo_alto) en lugar de "huevos" oscuros iguales; 620 -> 520 matas.

### Fiel a fuente vs estetica
- Fiel/tomado de fuente: buque mercante armado de 26 piezas, posicion, circo octogonal, batería de las dos piezas de a 18 (Gillespie 1818; Boneo 1801; Vidal c.1820). Tradicion: Guemes. Hipotesis: Red Ensign. Inferencia: bandera blanca del circo.
- Reconstruccion estetica / Diseño: color y olas del rio, borreguitos, tinte de uniformes y pelaje, guiones, escalado simbolico con la distancia, patios y tapias, matas y paja, anillo de 420 m, banco de arena irregular. Vidal 1820 se uso solo para el tono de campo pardo-dorado y el horizonte bajo (criterio visual, no colorimetria).

### Medicion
`benchmark.py --scenarios justine --repeat 3 --renderer forward_plus --max-frame-ms 3` (RTX 3080 Ti): baja 1,44 ms, media 2,54 ms de cuadro medio (p95 2,89 ms); presupuesto OK. `test_rules` 542/0, `test_integration` 252/0, `jev_contract` 15/0 (APPDATA aislado). `ui_qa` 1280x720 144/0 y 1920x1080 137/0 (con `--allow-clip`).

### Pendiente
- Popa plana del casco GLB (`tools/create_models.py`, no regenerado). Velas desplegadas con el casco apoyado: sin fuente, no se toco.
- Rotulos de grupos que se pisan, texto "Centro de la vista", leyenda del minimapa, modales, avisos y tutorial: son de `main.gd` (otra pista). Renombrar "Camino de la barranca (Alameda)" es dato del JSON/`main.gd` (el paquete pide no extender la Alameda a Retiro); aqui solo se agrego el sufijo (diseño).
- Muros del fuerte sin sillería ni garitas; guardias de escala junto al fuerte; pasto aun por vertice (sin textura propia).
- Compatibility y 2560x1440 reales sin capturas.
