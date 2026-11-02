# Visual del nivel «Humahuaca»: dirección de arte, datos y estado (pista `visual`)

Documento de la pista `visual` (CONTRATO 1.2). Dice **qué hay hoy** (R1.0: stub, datos y herramientas), **qué supone la vista** de las otras capas y **qué falta**. La dirección de arte completa está en `docs/DISENO_HUMAHUACA.md` (sección 11) y la rúbrica que la mide, en `docs/QA_NIVEL2.md` (V01 a V06); este archivo no la repite.

**Canal de arte (A-01):** generador procedural en GDScript (`BoxMesh`, `PrismMesh`, `CylinderMesh`, `SurfaceTool`, `MultiMeshInstance3D`). Blender no está autorizado. Nada de este archivo ni del código de la pista descarga o instala nada.

**Pase 2 de R1.0 (hallazgo I-R1.0-3, P0 del integrador).** El stub se corrigió una sola vez, por ese hallazgo y sin cambiar ninguna firma de 3.4: el alba dejaba el cuadro de naranja saturado y los anillos de visibilidad de las fichas se cruzaban y ensuciaban el mapa. Qué se encontró, qué cambió, las cifras de antes y después y lo que tiene que conservar la vista real están en la sección 7; los pedidos que salen de ahí (VP-07 a VP-09), en la 5.

## 1. Qué entrega R1.0

| Archivo | Qué es |
|---|---|
| `scripts/humahuaca/stubs/stub_view.gd` | El **stub de la vista** (CONTRATO 3.4 y 7). `Node3D` con la firma completa. Congelado desde el merge: se corrige solo por addendum (el pase 2 de R1.0 lo corrigió por I-R1.0-3, sección 7; el addendum se pide en VP-09). No depende del código real de la pista (solo importa `humahuaca_vocab.gd` y `view/vocab_view.gd`) |
| `scripts/humahuaca/view/vocab_view.gd` | Vocabulario de la capa. Conserva los ids de 3.0 y **suma** (solo-agregar): `LIGHT_KINDS`, `ENEMY_KINDS`, `TOKEN_SHAPES`, `PROBE_KINDS`, `BANDS`, `TIME_OF_DAY` y `FRAME_MARGIN_PCT` |
| `data/humahuaca_visual.json` | La paleta de **24 HEX** de la lámina 06, las **7 vistas** con su `must_show` (borrador de 5 rasgos cada una), `initial_frame`, las tres luces, lluvia, niebla, materiales, `props`, `tokens`, `markers`, `units`, `quality`, `fx` y `content_ring` (estos dos últimos, borradores) |
| `tests/test_hx_view.gd` | 105 comprobaciones sobre el stub y los datos (TR-091 a TR-099 de `TRAZA.md`, más capas, efectos y degradación, y las 19 de I-R1.0-3: alba, anillos de visibilidad y orden de un cuadro). La compuerta la exige recién desde R1, pero ya corre |
| `tools/vis_humahuaca.gd` | Recorrido de capturas **reales** (con ventana) y `metrics_visual.json`; incluye unas copias mínimas del terreno y de las reglas (`FakeTerrain`, `FakeRules`) para correr sin las otras pistas. Desde el pase 2 también arma las fases por las reglas (`--scenes`) o por la **escena real** con el controlador de `ui_feel` (`--flow`), y mide sobre píxeles lo que pide I-R1.0-3 (sección 7) |
| `tools/vis_humahuaca.sh` | Envoltorio: APPDATA propio, tope de tiempo y salida acotada para correr el anterior desde Git Bash |

No hay shaders propios, ni modelos, ni audio todavía: el stub dibuja con `StandardMaterial3D` y primitivas para que arranque aunque falle el arte real (CONTRATO 7).

## 2. Qué dibuja el stub

- **Terreno** continuo: ventana de 900 × 650 m (malla de 5 m en `media` y `alta`, de 10 m en `baja`) más el contexto de 3 600 × 2 750 m (malla de 50 m), los dos con la altura de `rules.terrain().height_at` y el color de `surface_at` (paleta). Una falda de 3 m alrededor de la ventana tapa las grietas contra el contexto. Un solo material para todo el suelo; con lluvia se oscurece a ×0,75 (diseño 11.2).
- **Río** (`terrain.river()`): lecho claro y agua turbia, en cintas que siguen el relieve. **Tapias**, **zanjas** y **caminos** (`terrain.features(...)`): las tapias son cajas con remate de paja; zanjas y caminos, cintas a ras de suelo.
- **Hitos:** una caja con la huella de cada uno (`terrain.landmarks({})`), con una mancha oscura de tierra debajo que los separa del suelo (la huella). El templo es una nave de dos aguas **sin torres** (≤ 7 m); la batería, una losa con tres piezas; la posta, un patio de muros de 2,4 m con dos entradas; las torres, fuste con plataforma. De las dos torres posibles se dibuja solo la que `render_state().tower` ubica.
- **Fichas:** una silueta propia por agrupación, de varias piezas con contorno oscuro y de **tamaño fijo en pantalla** (60 px reales de alto; ver 3.5 y 4.3): jinete (Rodríguez), infante con fusil (Portal), infante con banderín de mando (Arias), dos figuras agachadas (reconocedores) y mula cargada (arreo). Anillo de bando (celeste con borde blanco; dorado para el arreo), anillo de selección y número de tecla encima.
- **Luces** (`render_state().lights`): esfera cálida, resplandor aditivo que no baja de 30 px (se ve de lejos) y una `OmniLight3D` (hasta 4 en `media`, 8 en `alta`, ninguna en `baja`).
- **Objetivos:** anillo del color del estado (`blanco` guardado, `oro` alertado, `rojo` en alarma, `borgoña` asaltado, `celeste` tomado). **Visibilidad:** el contorno de la unión de los círculos de visibilidad de las fichas (sin los cruces entre anillos), de 2 px de ancho en pantalla y tenue (opacidad 0,55 de noche, 0,25 a los 128 m del alba y ninguna con luz plena). **Defensores** y **botín:** figuras chicas que crecen hasta 14 px y 10 px. **Efectos** (`fx`): esferas que crecen y se desvanecen, con tope por calidad.
- **Luz, niebla y lluvia:** salen de `environment().time_of_day` y `rain` y de las tres claves de `humahuaca_visual.json: lights`. Un `Environment` por escena (sin `shader_globals` ni ajustes de render en `project.godot`). El alba es cálido sin ser un oro puro: sol de `lino_crudo` mezclado 40 % con `oro_laton`, ambiente frío y niebla de cal con un toque de celeste (dos ids de paleta mezclados con `tint` y `tint_mix`, nunca un HEX suelto).

Lo que **no** hace (llega en R1 y R2a): terreno con shader y micro-relieve, anillo de contenido de 0 a 400 m, vegetación, lluvia en partículas, generador procedural del templo y de los arquetipos con render héroe, edificios de adobe con aleros, tablas de materiales por rol, sonido, métricas de albedo con calibración real, hoja de fichas, presupuesto por perfil medido con `benchmark.py`.

## 3. Convenciones que la vista supone

Las dejo escritas para que las otras pistas las confirmen o pidan un addendum (ver 5).

1. **Ejes:** los del CONTRATO 0. `yaw_deg` es un **rumbo**: grados horarios desde el norte, vistos en el mapa (0 = norte = −z, 90 = este = +x). Vale para las unidades de `render_state()`, para los hitos y para las cámaras canónicas.
2. **Huella de un hito:** `{w, d}` es un rectángulo con `w` sobre +x y `d` sobre +z **antes** de girar `yaw_deg` (giro horario visto en el mapa); `{r}` es un círculo; `{poly}` se reduce a su caja envolvente, sin giro (el stub no extruye polígonos).
3. **`environment().time_of_day`** (0 a 1) es continuo y creciente: **0 = noche plena, 0,5 = alba** (sol en el horizonte, las 4:45 del juego) **y 1 = día pleno**. La luz se interpola entre las claves `noche_lluvia` (0,0), `alba` (0,5) y `dia` (1,0) (`vocab_view.TIME_OF_DAY`).
4. **`render_state().version`** sube con cada cambio. Lo caro (figuras, luces, anillos) se reconstruye solo si cambia; cada cuadro se actualizan las escalas en pantalla, los efectos y la selección.
5. **Tamaños en píxeles** (`tokens.*.min_px`, `quality.*.enemy_min_px`) son **píxeles reales de la pantalla**: la vista los divide por la escala de la ventana (`get_viewport().get_screen_transform()`, acotada a ≥ 0,2), porque el proyecto estira un área lógica de 1 440 × 900 (`canvas_items`, aspecto `keep`). Por eso una captura a 1280 × 720 mide 1152 × 720 (16:10) y una a 1920 × 1080, 1699 × 1062 (la ventana de esta máquina no entra entera en 1080). El picking, `landmark_labels` y `probes` hablan en píxeles **lógicos**, los mismos de `Camera3D.unproject_position` y del ratón. Una ficha parada se ve más baja cuanto más empinado se la mira (las de abajo del cuadro, más que las de arriba), así que la vista la estira **solo a lo alto** (hasta 4,6 veces) para que mida lo pedido sin ensanchar su anillo.
6. **Colores:** solo ids de la paleta. Los `markers` de bando (celeste con borde blanco, borgoña con borde negro, dorado) llevan además el HEX exacto porque son marcadores de **interfaz** (V9 los exime); no son banderas.
7. **Vistas canónicas:** `canonical_views` es un **arreglo** de objetos con `id` (en el orden de `VIEW_IDS`), cada uno con `target {x, z}`, `distance`, `pitch_deg`, `yaw_deg`, `time_of_day`, `rain` y `must_show` (5 rasgos). `juego_noche` y `juego_alba` repiten la cámara de `initial_frame`.
8. **Orden de un cuadro (se midió con la escena real en el pase 2):** `main` deja la cámara donde la quería el menú, el controlador llama a `update_state(delta)` con **esa** cámara y recién al final de su `_process` la ubica (`_apply_camera`). Lo que depende de la cámara (la escala en pantalla de fichas, luces y etiquetas, y el ancho de los anillos del suelo) lo recalcula también el `_process` de la vista, que corre después del de su padre con la cámara ya puesta; sin eso las fichas medían de 11 a 33 px en vez de ≥ 48 px. Lo mejor sigue siendo que el controlador ubique la cámara **antes** de llamar a `update_state` (VP-08): la vista real también tiene que sobrevivir al orden actual.
9. **`yaw_deg` de la cámara es un rumbo:** `initial_frame`, `canonical_view` y `qa_set_camera` dicen hacia dónde **mira** la cámara (0 = norte, 90 = este), que es lo que escribe el diseño 11.3 (`desde_bateria` a 90° mira al este desde la plataforma; `acceso_so` a 45° mira al noreste desde el sudoeste). La primera versión del controlador (`humahuaca_ui._apply_camera`) lo usa como el ángulo al que **está** la cámara respecto del objetivo, que es el espejo: lo que se ve no es lo que midió `initial_frame().fits` (4.1 y VP-07).

## 4. Cámara inicial, vistas canónicas y medidas

### 4.1 `initial_frame(camera)`

Parte de `data/humahuaca_visual.json: initial_frame` (objetivo (350, 470), 470 m, 52°, rumbo 35°) y **solo se ensancha** (en pasos de 4 %, hasta 900 m) si no entran, con 5 % de borde libre, los hitos de `initial_frame.must_include`: `bateria`, `cuartel`, `posta` y `zona_partida` (su centro). La proyección se calcula a mano, así que no mueve la cámara real. Con los datos reales de `relieve_mapa` (rama `hx-relieve-r1-0`) `fits` es verdadero **a 470 m** a 1024 × 640, 1280 × 720, 1920 × 1080 y 2560 × 1440; con las copias mínimas de `tools/vis_humahuaca.gd`, también.

**Pregunta abierta para `ui_feel` y el integrador:** el cuadro de 470 m **no** incluye las cinco partidas, solo el centro de la zona. Con los `spawn_*` que escribió `relieve_mapa`, `spawn_arias` (260, 625) y `spawn_arreo` (60, 625) quedan **fuera del cuadro inicial** (con 5 % de borde libre entran hasta z ≈ 550). Si se las quiere a la vista al empezar, se agregan al `must_include` del JSON y el cuadro se abre hasta unos 810 m (todo queda ≈ 40 % más chico, peor lectura de noche); si no, la apertura de 12 a 15 s las muestra. No lo decide la vista.

**Decidido (A-07, VP-06): no se ensancha.** Lo que sí quedó medido en el pase 2 (`metrics_visual.json: initial_frame.*.puntos`, margen al borde más cercano en % del lado; negativo = fuera del cuadro) es que esa observación del integrador vale para la cámara **espejada** del controlador y no para la del diseño:

| Resolución | Cámara del diseño (`yaw_deg` = rumbo de la mirada) | Cámara de hoy del controlador (el espejo) |
|---|---|---|
| 1024 × 640 | fuera: arreo −44,1 %, Portal −14,1 %; adentro: Rodríguez 4,5 %, Arias 4,0 % | adentro las cinco: arreo **1,4 %** (toca el borde), Portal 11,7 %, Arias 21,7 %, Rodríguez 20,3 %, reconocedores 34,9 % |
| 1280 × 720 y más | fuera: arreo −44,1 %, Portal −14,1 %; adentro: Rodríguez 9,1 %, Arias 4,0 % | adentro las cinco: arreo 6,2 %, Portal 15,5 %, Arias 24,6 %, Rodríguez 23,3 %, reconocedores 36,4 % |

Con la cámara del diseño `fits` sigue siendo verdadero (solo exige los tres objetivos y el **centro** de la zona) pero la zona queda cortada: el arreo y Portal arrancarían fuera de pantalla. El espejo de `yaw = 35°` es el rumbo 325°: con `initial_frame.yaw_deg = 325` y la cámara corregida, las cinco entran con los mismos márgenes (arreo 6,2 % a 1280 × 720 y a 1920 × 1080; a 1024 × 640 el cuadro se abre un paso del 4 %, de 470 a 488,8 m, y el arreo queda a 3,2 %). No se cambió el dato en este pase: con el controlador espejado el cambio dejaría el cuadro cortado (VP-07).

### 4.2 Las 7 vistas y sus 5 rasgos (borrador de R1.0)

Escritas **antes de pintar** (CONTRATO 11, regla 7) a partir del anexo B del QA. Cada lista es el `must_show` del JSON.

| Vista | Cámara (objetivo · distancia · inclinación · rumbo) | Luz | Rasgos |
|---|---|---|---|
| `acceso_so` | (300, 520) · 150 m · 22° · 45° | noche con lluvia | ladera, núcleo (≥ 3 edificios) y templo al fondo · templo a dos aguas sin torres · lluvia y escena legible con ≥ 2 fichas · sin monumento, escalinata, postes, tendidos ni álamos · la interfaz no tapa el núcleo |
| `desde_bateria` | (318, 350) · 60 m · 18° · 90° | alba | el pueblo por debajo, al este · río o lecho claro al fondo · parapeto y ≥ 1 pieza en primer plano · luz cálida con sombras largas · sin torres de 1880 |
| `patio_posta` | (590, 300) · 45 m · 40° · 315° | mañana | muros del patio con sus dos entradas · ≥ 3 clases de objeto · solo adobe, madera y cuero · polvorín al noreste · se ve cuánto se carga |
| `panorama_alto` | (450, 330) · 330 m · 28° · 90° | alba | ladera, núcleo, monte ribereño, lecho claro, llanura, cerros y horizonte · sin torres ni monumento · luz cálida y sombras largas · sin huecos ni borde del mundo · techos claros entre arbolado oscuro (foto de 1923) |
| `grupos_en_accion` | (418, 335) · 90 m · 45° · 0° | alba, lluvia floja | torre con plataforma · fuego o humo desde la torre · ≥ 3 fichas · líneas de fuego o impactos · bajas o estado a la vista |
| `juego_noche` | `initial_frame` · 470 m · 52° · 35° | noche con lluvia, t = 0 | ≥ 3 puntos de luz · los tres objetivos sin leer texto · relieve y núcleo visibles · ≥ 3 fichas distinguibles · la interfaz no tapa los objetivos |
| `juego_alba` | la misma cámara | alba (≈ 4:45) | sombras largas y luz cálida · fichas en sus puestos y fogatas · los tres objetivos · el núcleo se distingue por luz y trazo · sin torres ni monumento |

### 4.3 Medidas reales de R1.0 (stub, esta máquina)

Con `tools/vis_humahuaca.gd` sobre los **stubs reales** de relieve y reglas (ramas `hx-relieve-r1-0` 505e06a y `hx-reglas-r1-0` 6424dfe, probadas en un worktree temporal aparte); GPU NVIDIA GeForce RTX 3080 Ti, Forward+, ventana de 1440 × 900, sin vsync, 180 cuadros medidos tras 30 de calentamiento. **Son informativas: no reemplazan a `benchmark.py`** (que mide la escena real y desde R1).

| Calidad | Luz | Construir | Cuadro medio | p95 | Llamadas de dibujo | Primitivas | Nodos |
|---|---|---|---|---|---|---|---|
| baja | noche · alba | 129 · 120 ms | 0,81 · 0,84 ms | 1,46 · 1,67 ms | 118 · 118 | 29 570 · 29 570 | 310 |
| media | noche · alba | 157 · 186 ms | 0,99 · 1,04 ms | 1,65 · 1,63 ms | 139 · 182 | 67 218 · 116 718 | 313 |
| alta | noche · alba | 162 · 171 ms | 0,92 · 1,05 ms | 1,43 · 1,57 ms | 139 · 182 | 67 218 · 116 718 | 313 |

Presupuestos del contrato: construir ≤ 1 500 ms; cuadro medio baja ≤ 2,5, media ≤ 4,0, alta ≤ 6,0 ms y p95 ≤ 8,3 ms. El stub los cumple con holgura (el alba suma las sombras del sol); lo que importa es lo que mida la vista real.

**Alto de las fichas con el cuadro inicial** (de la base a la cima de sus piezas, en píxeles reales; `metrics_visual.json: token_px`). Una ficha parada se ve más baja cuanto más empinado se la mira, y el stub la estira solo a lo alto hasta 4,6 veces: las que entran en el cuadro miden entre 50 y 85 px a 1280 × 720 (Rodríguez 50, reconocedores 61, Arias 85, que está en el borde inferior); con las copias mínimas, entre 42 y 67. El pedido de la vista real es **≥ 48 px** (V03); el stub no lo garantiza en el borde inferior del cuadro (llega a ≈ 42), y por eso su umbral propio es 40. Las partidas que caen fuera del cuadro (ver 4.1) no se miden.

**Alto de las fichas por la escena real** (`tools/vis_humahuaca.sh ... --flow`, `main.tscn` con el controlador de `ui_feel`, 1280 × 720): antes del pase 2 medían **11,4 a 33,1 px** (la vista calculaba la escala con la cámara del menú, ver 3.8); ahora **60,9 a 70,1 px** (aproximación), 61,1 a 66,9 px (ataque y extracción) y 61,7 a 70,9 px a 1024 × 640. Rendimiento después del pase 2 (la misma herramienta con `--bench`, 1440 × 900, 180 cuadros): baja 0,73 a 0,82 ms, media 0,84 a 0,90 ms (p95 1,24 a 1,26 ms) y alta 0,80 a 0,90 ms de cuadro medio; construir 111 a 170 ms.

### 4.4 Pruebas (R1.0)

`tests/test_hx_view.gd`: **105 comprobaciones, 0 fallas, ≈ 1 s** (sin ventana; en R1.0 eran 86). Incluye: API completa de 3.4 contra `hx_fixtures`; construir ≤ 1 500 ms y sin nodos huérfanos al construir dos veces; `initial_frame().fits` a cinco resoluciones y con la cámara real; picking de las 5 fichas (por la figura, no por un punto), de los 3 frentes y de un hito, e ida y vuelta del rayo al suelo a menos de 2 m; templo ≤ 8 m por la altura de sus vértices y sin nombres de la lista A; paleta (24 ids, ningún color suelto); las 7 vistas con sus 5 rasgos; luces, niebla y albedo; siluetas distintas y alto en pantalla; capas, selección y efectos; degradación sin reglas ni terreno. Se probó que **ve** un picking roto, un HEX suelto, una vista de menos y un templo de 12,9 m. Las 19 del pase 2 (sección 7) se probaron por mutación: sin el `_process` de la vista la ficha queda a escala 4,60 en vez de 12,87; con el alba de oro puro el suelo da 0,54 y 0,66 de saturación contra los topes de 0,40 y 0,46; con los círculos enteros un vértice entra 5,22 m en otro círculo con 35 m de visibilidad (121,42 m con 128 m); si los anillos de visibilidad se dibujaran siempre, con 600 m habría 4 trazos.

- Pase 2, sobre `main` en 4908b1b con los cuatro stubs: `test_hx_view` 105/0 · `test_hx_data` 296/0 (con `--pista=visual`, 283/0) · `test_hx_smoke` 146/0 en ≈ 22 s (4 pendientes: las clases reales que no existen) · `tools/vis_humahuaca.gd` por la escena real, 0 fallas a 1280 × 720 y a 1024 × 640.
- Sola esta rama en R1.0 (copias mínimas): `test_hx_view` 86/0 · `test_hx_data --pista=visual` 278/0 en 0,4 s · `test_hx_smoke` 111/0 en 21 s (12 pendientes de otras pistas).
- Sobre los stubs de las otras tres ramas (worktree temporal aparte, sin tocar las ramas): `test_hx_view` 86/0 con `stub_rules` y `stub_terrain` de las otras pistas; `test_hx_smoke` **134/0**, con la corrida degradada de la vista dentro del controlador real de `ui_feel` y 4 pendientes (las clases reales que no existen todavía). `test_hx_data` sin `--pista` da 296 y **1 falla que no es de esta pista**: «sanidad: el validador ve “access que cita hitos sin mapa”» (una mutación de V5 sobre los datos de `reglas_historia` y `relieve_mapa`; se la paso a compuertas y documentos).
- `tools/vis_humahuaca.gd` con ventana: 44 comprobaciones a 1280 × 720 y 31 a 1920 × 1080, 0 fallas.

## 5. Pedidos escritos a las otras pistas (id, firma, motivo y prueba de aceptación)

| Id | A quién | Pedido | Motivo | Prueba de aceptación |
|---|---|---|---|---|
| VP-01 | `reglas_historia` | `environment().time_of_day` continuo, **0 hasta ≈ 240 s, 0,5 a los 285 s (4:45) y 1,0 a `day_full_s`**, creciente entre esos puntos | La vista interpola la luz entre noche (0), alba (0,5) y día (1) | `test_hx_rules`: muestras a 0, 240, 285, 330 y 420 s dentro de ±0,05 de 0, 0, 0,5, 0,67 y 1 |
| VP-02 | `reglas_historia` | `render_state().version` sube en cada cambio visible; `render_state().tower` es `{}` si no hay torre y, si hay, trae las coordenadas de **la** torre del mundo | La vista elige entre `torre_casa_cura` y `torre_templo` por la distancia a `tower.{x,z}` (< 40 m) | `test_hx_rules`: con cada valor de `torre_en`, `tower` cae a < 40 m del hito de esa variante |
| VP-03 | `relieve_mapa` | Confirmar (o corregir por addendum) la convención de la huella y del `yaw_deg` del apartado 3.1 y 3.2 | La vista dibuja los hitos con ella; si el terreno rasteriza otra, caja y muro no coincidirían | `test_hx_terrain`: la esquina de la huella de un hito con `yaw_deg` ≠ 0 es `centro + R(yaw)·(±w/2, ±d/2)` con la rotación horaria del mapa |
| VP-04 | `relieve_mapa` | `height_at` continua en `x ∈ [−1350, 2250]`, `z ∈ [−1050, 1700]` (un poco más que el contexto); `landmarks({})` devuelve todos los hitos con `footprint` y `height_m`; `features(kind)` devuelve arreglos de objetos con `pts` como `{x, z}`; `river().bed_width_m` y `river().pts`; `minimap_image(px, {})` devuelve un `Image` de **exactamente** `px` | Lo que la vista consume | `test_hx_terrain`: esos cinco contratos sobre el terreno real y el stub |
| VP-05 | `ui_feel` / integrador | El controlador pasa a `initial_frame(camera)` la cámara **ya dentro del árbol** (si no, supone 16:9 y 46°); llama `update_state(delta)` cada cuadro; ajusta `camera.far ≥ 9000` | La proyección y las escalas en pantalla salen de la cámara y del `Viewport` | `test_hx_flow`: `initial_frame().fits` con la cámara real a 1280 × 720 y a 1024 × 640 |
| VP-06 | integrador / compuertas y documentos | Decidir si las cinco partidas entran en el cuadro inicial (ver la pregunta abierta de 4.1). Hoy no: solo la zona. Y revisar la mutación «access que cita hitos sin mapa» de `test_hx_data`, que falla con los datos de las otras dos pistas | Sin esa decisión, `spawn_arias` y `spawn_arreo` empiezan fuera de pantalla | `test_hx_flow`: en el primer cuadro jugable las cinco fichas (o las que se decida) están en pantalla; `test_hx_data` sin `--pista`: 0 fallas. **Resuelto por A-07: no se ensancha; B-015 en R2a** |
| VP-07 | `ui_feel` (por el integrador) | La cámara del controlador (`humahuaca_ui._apply_camera` y la `humahuaca_camera.gd` de R1) tiene que usar `yaw_deg` como rumbo de la mirada: `offset = (−sin(yaw)·cos(pitch), sin(pitch), cos(yaw)·cos(pitch)) · distancia` (hoy usa `+sin(yaw)`). En el mismo merge `visual` cambia el dato `initial_frame.yaw_deg` de 35° a 325° (ver 4.1) para que las cinco partidas sigan entrando. Si se prefiere no tocar la cámara, el addendum redefine `yaw_deg` como ángulo de la posición y `visual` reescribe los `yaw_deg` de las 7 vistas | Con la cámara de hoy 6 de las 7 vistas canónicas salen espejadas (todas menos `grupos_en_accion`, que mira al norte; `desde_bateria` mira desde el este hacia la batería, no desde la batería hacia el pueblo) y el cuadro inicial no es el que midió `fits` | `test_hx_flow`: tras `qa_set_camera(Vector2(318, 350), 60, 18, 90)` la dirección horizontal de la mirada de la cámara es (1, 0) ± 0,02 (mira al este); con `initial_frame` a 1280 × 720 las cinco partidas quedan a ≥ 5 % del borde (`tools/vis_humahuaca.gd` informa `initial_frame.*.puntos`) |
| VP-08 | `ui_feel` | En `_process`, ubicar la cámara (`_apply_camera`) **antes** de llamar a `view.update_state(delta)` | La vista ya no depende del orden (3.8), pero el resto de lo que lee la cámara (minimapa, picking, rótulos) sí | `test_hx_flow`: la cámara de `update_state` es la del cuadro que se dibuja (la escala de las fichas no cambia al llamar a `update_state` otra vez) |
| VP-09 | integrador / compuertas y documentos | Registrar el addendum **A-08** (el stub de la vista, congelado, se corrigió por I-R1.0-3: sin cambios de firma; 3.4 pasa a decir que la vista recalcula lo que depende de la cámara en su `_process`) y agregar a `TRAZA.md` las filas TR-101 (anillos de visibilidad: contorno de la unión, 2 px, se apagan con luz plena; `test_hx_view::_test_visibility_rings`), TR-102 (el alba no satura de naranja; `test_hx_view::_test_dawn_wash`) y TR-103 (la escala en pantalla se mide con la cámara del cuadro; `test_hx_view::_test_camera_order`), todas desde r1.0 | Sin la fila, V20 no cubre las tres pruebas nuevas | `test_hx_data::_test_v20_traceability` verde con las tres filas |

## 6. Cómo se corre

```sh
G="C:/Users/User/Desktop/spum/IA/Proyectos/MaravillaArgentina/guemes/patria-guemes/.tools/godot/Godot_v4.7.2-stable_win64_console.exe"
export APPDATA="$TEMP/ap_iso_visual"; rm -rf "$APPDATA"; mkdir -p "$APPDATA"
"$G" --headless --path <worktree> --script tests/test_hx_view.gd -- --ronda=r1.0
"$G" --path <worktree> --resolution 1280x720 --audio-driver Dummy --script tools/vis_humahuaca.gd -- --out=<carpeta> --tag=visual_r1 --extras
#   opciones: --fakes (copias mínimas aunque existan los stubs de las otras pistas) · --view=real · --quality=baja|media|alta · --views=a,b
#             --bench [--bench-tod=0.5 --bench-rain=0.42] · --index-base=N · --hide=Grupo1,Grupo2 (depuración)
#             --no-views · --scenes=aproximacion,ataque,extraccion (las reglas en esa fase, 3D solo) · --cam=ui (la cámara como la arma hoy el controlador)
#             --flow=aproximacion,ataque@300,extraccion@321,ataque@300/cam=418;335;110;45;35   (por la escena real; @segundos pisa el reloj del stub de reglas)
bash tools/vis_humahuaca.sh <carpeta> 1280x720 --no-views --tag=visual_r1 --flow=aproximacion,extraccion@321   # lo mismo con APPDATA propio y tope de tiempo
```

Evidencia de la ronda: `evidence/humahuaca/r1/visual/` (14 JPEG de ≤ 80 KB y `metrics_visual.json`; las rondas intermedias no entran a Git): las 7 vistas canónicas (01 a 07, con la cámara del diseño), las fases por la escena real (08 a 11), el antes del alba (12 y 13) y el cuadro inicial a 1024 × 640 (14). El minimapa y el albedo de pase 1 no cambiaron y no se repiten; el minimapa es de un solo color porque así lo devuelve `stub_terrain.minimap_image` (CONTRATO 7).

## 7. Hallazgo I-R1.0-3 (pase 2 de R1.0): el alba lavaba todo de naranja y los anillos ensuciaban el mapa

**Qué decía (P0, informe del integrador).** En la captura de extracción el alba del stub lavaba todo de naranja saturado y los anillos de radio de las fichas se superponían y ensuciaban el mapa; a 1024 × 640 el arreo tocaba el borde izquierdo del cuadro inicial. Esto último lo decidió A-07 (VP-06): no se ensancha y se revisa en R2a (B-015); lo que hay en 4.1 es solo el dato para esa revisión. Aceptación: la compuerta rápida pasa.

**Qué se encontró al reproducirlo por la escena real** (`--flow`, 1280 × 720):

1. **La luz.** El sol del alba era `oro_laton` (ganancia 1,2, energía 1,6) sobre un suelo que ya es cálido (`suelo_seco`, saturación 0,38): el 62,8 % de los píxeles de la extracción (321 s) y el 81,7 % del ataque (300 s) quedaban en «naranja saturado» (saturación ≥ 0,55, brillo ≥ 0,30 y matiz de 15° a 50°).
2. **Los anillos.** `visibility_pools` trae un círculo por ficha con el radio de `environment().visibility_m`: 35 m de noche, de 60 a 140 m al alba y hasta 600 m de día. Dibujados enteros se cruzaban (6 pares con las cinco fichas) y 2 311,5 m de trazo caían dentro de otro círculo; al acercar la cámara a 110 m la línea de 1,4 m engordaba a ≈ 10 px.
3. **Las fichas.** No lo decía el hallazgo, pero en la escena real medían 11,4 a 33,1 px y no ≥ 48: la vista calculaba su tamaño con la cámara del menú (3.8). Con los anillos grandes y las fichas minúsculas el mapa se leía todavía peor.
4. **La cámara** (no es de la vista; va como VP-07): la del controlador es el espejo de la de `initial_frame` (3.9 y 4.1).

**Qué cambió** (ninguna firma de 3.4; el stub sigue importando solo vocabularios):

| Cambio | Dónde |
|---|---|
| El alba: sol de `lino_crudo` mezclado 40 % con `oro_laton` (energía 1,7), ambiente de `celeste_produccion` mezclado 30 % con `agua_turbia` (0,55) y niebla de `cal_envejecida` con 25 % de `celeste_produccion`. Cálido, con sombras largas y sombras frías; nada de HEX sueltos. La clave nueva `tint` y `tint_mix` es de `lights.*.sun/ambient/fog` | `data/humahuaca_visual.json: lights.alba`; `stub_view._tinted` |
| El anillo de visibilidad es el contorno de la **unión** de los círculos (de cada uno quedan solo los arcos que no están dentro de otro, con los extremos en los cruces exactos), de 2 px de ancho en pantalla (se rearma al acercar o alejar la cámara) y con opacidad 0,55 que baja a 0 entre 70 y 180 m de visibilidad. Los anillos de objetivo miden 4 px. Se rearma solo si cambia algo | `data/humahuaca_visual.json: fog.anillos`; `stub_view._pool_arcs`, `pool_alpha`, `_rebuild_rings`, `_ring_width_m` |
| Lo que depende de la cámara se recalcula también en el `_process` de la vista (después del controlador) | `stub_view._process` |
| Herramientas: `--scenes`, `--flow` y `--cam=ui`; saturación, «naranja saturado», trazo dentro de otro círculo, alto de ficha y dónde caen las cinco partidas con cada lectura de `yaw_deg`; envoltorio `.sh` | `tools/vis_humahuaca.gd`, `tools/vis_humahuaca.sh` |

**Antes y después** (escena real, 1280 × 720, la misma captura; `metrics_visual.json`):

| Cuadro | Naranja saturado | Saturación media | Trazo dentro de otro círculo | Alto de las fichas |
|---|---|---|---|---|
| ataque a 300 s, antes | 81,7 % | 0,535 | 1 561,6 m (5 pares) | 11,9 a 33,1 px |
| ataque a 300 s, después | **0,0 %** | 0,261 | **0,0 m** | 61,1 a 66,9 px |
| extracción a 321 s, antes | 62,8 % | 0,517 | 2 311,5 m (6 pares) | 11,9 a 33,1 px |
| extracción a 321 s, después | **0,0 %** | 0,350 | **0,0 m** | 61,1 a 66,9 px |
| aproximación (noche), antes → después | 0,0 % → 0,1 % | 0,340 → 0,336 | 30,5 m (1 par) → 0,0 m | 11,4 a 19,1 → 60,9 a 70,1 px |

Las siete vistas canónicas quedan en 0,0 % de naranja saturado, salvo `patio_posta` (mañana, casi día pleno: 4,2 %). Las capturas «antes» son `12_` y `13_`.

**Cómo se prueba.** `test_hx_view` suma `_test_dawn_wash` (indicador numérico de la saturación del suelo bajo la luz que arma la vista: 0,54 y 0,66 antes, 0,29 y 0,40 ahora, topes 0,40 y 0,46; el sol sigue cálido), `_test_visibility_rings` (la geometría de la unión contra un muestreo fino en 40 casos al azar, ≤ 2 % de diferencia; lo que la vista **arma** no cruza anillos; la opacidad se apaga con luz plena) y `_test_camera_order` (un cuadro con el orden real: `update_state` con la cámara del menú y la del juego después). `tools/vis_humahuaca.gd` aplica los mismos umbrales sobre los **píxeles** de cada captura de juego (≤ 5 % de naranja saturado, saturación media ≤ 0,42, ≤ 5 m de trazo dentro de otro círculo y ficha ≥ 48 px en la escena real).

**Lo que tiene que conservar la vista real (R1).** (a) El alba no pasa de «naranja saturado» (≤ 5 % de los píxeles) ni de saturación media 0,42 en `juego_alba` y en la extracción; (b) los anillos de visibilidad no se cruzan, son de 2 px, tenues y se apagan con luz plena; (c) lo que depende de la cámara se calcula con la cámara que se dibuja, aunque el controlador llame a `update_state` antes de ubicarla; (d) las fichas miden ≥ 48 px por la escena real y no solo en la herramienta de captura.

