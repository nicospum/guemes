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
