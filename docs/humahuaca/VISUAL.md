# Visual del nivel «Humahuaca»: dirección de arte, datos y estado (pista `visual`)

Documento de la pista `visual` (CONTRATO 1.2). Dice **qué hay hoy** (R1.0: stub, datos y herramientas), **qué supone la vista** de las otras capas y **qué falta**. La dirección de arte completa está en `docs/DISENO_HUMAHUACA.md` (sección 11) y la rúbrica que la mide, en `docs/QA_NIVEL2.md` (V01 a V06); este archivo no la repite.

**Canal de arte (A-01):** generador procedural en GDScript (`BoxMesh`, `PrismMesh`, `CylinderMesh`, `SurfaceTool`, `MultiMeshInstance3D`). Blender no está autorizado. Nada de este archivo ni del código de la pista descarga o instala nada.

## 1. Qué entrega R1.0

| Archivo | Qué es |
|---|---|
| `scripts/humahuaca/stubs/stub_view.gd` | El **stub de la vista** (CONTRATO 3.4 y 7). `Node3D` con la firma completa. Congelado desde el merge: se corrige solo por addendum. No depende del código real de la pista (solo importa `humahuaca_vocab.gd` y `view/vocab_view.gd`) |
| `scripts/humahuaca/view/vocab_view.gd` | Vocabulario de la capa. Conserva los ids de 3.0 y **suma** (solo-agregar): `LIGHT_KINDS`, `ENEMY_KINDS`, `TOKEN_SHAPES`, `PROBE_KINDS`, `BANDS`, `TIME_OF_DAY` y `FRAME_MARGIN_PCT` |
| `data/humahuaca_visual.json` | La paleta de **24 HEX** de la lámina 06, las **7 vistas** con su `must_show` (borrador de 5 rasgos cada una), `initial_frame`, las tres luces, lluvia, niebla, materiales, `props`, `tokens`, `markers`, `units`, `quality`, `fx` y `content_ring` (estos dos últimos, borradores) |
| `tests/test_hx_view.gd` | 84 comprobaciones sobre el stub y los datos (TR-091 a TR-099 de `TRAZA.md`, más capas, efectos y degradación). La compuerta la exige recién desde R1, pero ya corre |
| `tools/vis_humahuaca.gd` | Recorrido de capturas **reales** (con ventana) y `metrics_visual.json`; incluye unas copias mínimas del terreno y de las reglas (`FakeTerrain`, `FakeRules`) para correr sin las otras pistas |

No hay shaders propios, ni modelos, ni audio todavía: el stub dibuja con `StandardMaterial3D` y primitivas para que arranque aunque falle el arte real (CONTRATO 7).

## 2. Qué dibuja el stub

- **Terreno** continuo: ventana de 900 × 650 m (malla de 5 m en `media` y `alta`, de 10 m en `baja`) más el contexto de 3 600 × 2 750 m (malla de 50 m), los dos con la altura de `rules.terrain().height_at` y el color de `surface_at` (paleta). Una falda de 3 m alrededor de la ventana tapa las grietas contra el contexto. Un solo material para todo el suelo; con lluvia se oscurece a ×0,75 (diseño 11.2).
- **Río** (`terrain.river()`): lecho claro y agua turbia, en cintas que siguen el relieve. **Tapias**, **zanjas** y **caminos** (`terrain.features(...)`): las tapias son cajas con remate de paja; zanjas y caminos, cintas a ras de suelo.
- **Hitos:** una caja con la huella de cada uno (`terrain.landmarks({})`), con una mancha oscura de tierra debajo que los separa del suelo (la huella). El templo es una nave de dos aguas **sin torres** (≤ 7 m); la batería, una losa con tres piezas; la posta, un patio de muros de 2,4 m con dos entradas; las torres, fuste con plataforma. De las dos torres posibles se dibuja solo la que `render_state().tower` ubica.
- **Fichas:** una silueta propia por agrupación, de varias piezas con contorno oscuro y de **tamaño fijo en pantalla** (60 px reales de alto; ver 3.5 y 4.3): jinete (Rodríguez), infante con fusil (Portal), infante con banderín de mando (Arias), dos figuras agachadas (reconocedores) y mula cargada (arreo). Anillo de bando (celeste con borde blanco; dorado para el arreo), anillo de selección y número de tecla encima.
- **Luces** (`render_state().lights`): esfera cálida, resplandor aditivo que no baja de 30 px (se ve de lejos) y una `OmniLight3D` (hasta 4 en `media`, 8 en `alta`, ninguna en `baja`).
- **Objetivos:** anillo del color del estado (`blanco` guardado, `oro` alertado, `rojo` en alarma, `borgoña` asaltado, `celeste` tomado). **Visibilidad:** anillos celestes. **Defensores** y **botín:** figuras chicas que crecen hasta 14 px y 10 px. **Efectos** (`fx`): esferas que crecen y se desvanecen, con tope por calidad.
- **Luz, niebla y lluvia:** salen de `environment().time_of_day` y `rain` y de las tres claves de `humahuaca_visual.json: lights`. Un `Environment` por escena (sin `shader_globals` ni ajustes de render en `project.godot`).

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

## 4. Cámara inicial, vistas canónicas y medidas

### 4.1 `initial_frame(camera)`

Parte de `data/humahuaca_visual.json: initial_frame` (objetivo (350, 470), 470 m, 52°, rumbo 35°) y **solo se ensancha** (en pasos de 4 %, hasta 900 m) si no entran, con 5 % de borde libre, los tres objetivos, el centro de la zona de partida y las cinco partidas. La proyección se calcula a mano, así que no mueve la cámara real. Con las copias mínimas de terreno de `tools/vis_humahuaca.gd` (la zona y las partidas quedan más al sur que lo que parece prever el diseño) `fits` es verdadero a 1024 × 640, 1024 × 768, 1280 × 720, 1920 × 1080 y 2560 × 1440, y la distancia sale de **550 m**, no de 470: el cuadro real lo decide la posición de los hitos `spawn_*` y `zona_partida` que escriba `relieve_mapa`. Con la fórmula del diseño y la zona de (160, 550), el borde inferior queda justo en el 5 % libre.

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

Con `tools/vis_humahuaca.gd` y las copias mínimas de terreno y reglas; GPU NVIDIA GeForce RTX 3080 Ti, Forward+, ventana de 1440 × 900, sin vsync, 180 cuadros medidos tras 30 de calentamiento. **Son informativas: no reemplazan a `benchmark.py`** (que mide la escena real y desde R1).

| Calidad | Luz | Construir | Cuadro medio | p95 | Llamadas de dibujo | Primitivas | Nodos |
|---|---|---|---|---|---|---|---|
| baja | noche · alba | 152 · 152 ms | 0,80 · 0,71 ms | 1,19 · 1,04 ms | 134 · 134 | 36 446 · 36 446 | 330 |
| media | noche · alba | 292 · 286 ms | 0,79 · 0,90 ms | 1,02 · 1,16 ms | 166 · 218 | 76 038 · 126 210 | 333 |
| alta | noche · alba | 288 · 287 ms | 0,79 · 0,91 ms | 1,09 · 1,18 ms | 166 · 218 | 76 038 · 126 210 | 333 |

Presupuestos del contrato: construir ≤ 1 500 ms; cuadro medio baja ≤ 2,5, media ≤ 4,0, alta ≤ 6,0 ms y p95 ≤ 8,3 ms. El stub los cumple con holgura (el alba suma las sombras del sol); lo que importa es lo que mida la vista real.

**Alto de las fichas con el zoom inicial** (de la base a la cima de sus piezas, en píxeles reales; `metrics_visual.json: token_px`): a 1280 × 720, Rodríguez 58, Portal 60, Arias 63, reconocedores 62 y arreo 50; a 1920 × 1080, entre 48 y 61. El pedido es ≥ 48 (V03). El arreo es el que menos margen tiene.

### 4.4 Pruebas (R1.0)

`tests/test_hx_view.gd`: 84 comprobaciones, 0 fallas, 2,3 s (sin ventana). Incluye: API completa de 3.4 contra `hx_fixtures`; construir ≤ 1 500 ms y sin nodos huérfanos al construir dos veces; `initial_frame().fits` a cinco resoluciones y con la cámara real; picking de las 5 fichas, de los 3 frentes y de un hito, e ida y vuelta del rayo al suelo a menos de 2 m; templo ≤ 8 m por la altura de sus vértices y sin nombres de la lista A; paleta (24 ids, ningún color suelto); las 7 vistas con sus 5 rasgos; luces, niebla y albedo; siluetas distintas; capas, selección y efectos; degradación sin reglas ni terreno. Se probó que **ve** un picking roto, un HEX suelto, una vista de menos y un templo de 12,9 m. `test_hx_data --pista=visual`: 278/0 en 0,4 s. `test_hx_smoke`: 111/0 en 19 s (12 pendientes de otras pistas). `tools/vis_humahuaca.gd` con ventana: 44 comprobaciones a 1280 × 720 (incluye el alto de las fichas en píxeles reales) y 31 a 1920 × 1080, 0 fallas.

## 5. Pedidos escritos a las otras pistas (id, firma, motivo y prueba de aceptación)

| Id | A quién | Pedido | Motivo | Prueba de aceptación |
|---|---|---|---|---|
| VP-01 | `reglas_historia` | `environment().time_of_day` continuo, **0 hasta ≈ 240 s, 0,5 a los 285 s (4:45) y 1,0 a `day_full_s`**, creciente entre esos puntos | La vista interpola la luz entre noche (0), alba (0,5) y día (1) | `test_hx_rules`: muestras a 0, 240, 285, 330 y 420 s dentro de ±0,05 de 0, 0, 0,5, 0,67 y 1 |
| VP-02 | `reglas_historia` | `render_state().version` sube en cada cambio visible; `render_state().tower` es `{}` si no hay torre y, si hay, trae las coordenadas de **la** torre del mundo | La vista elige entre `torre_casa_cura` y `torre_templo` por la distancia a `tower.{x,z}` (< 40 m) | `test_hx_rules`: con cada valor de `torre_en`, `tower` cae a < 40 m del hito de esa variante |
| VP-03 | `relieve_mapa` | Confirmar (o corregir por addendum) la convención de la huella y del `yaw_deg` del apartado 3.1 y 3.2 | La vista dibuja los hitos con ella; si el terreno rasteriza otra, caja y muro no coincidirían | `test_hx_terrain`: la esquina de la huella de un hito con `yaw_deg` ≠ 0 es `centro + R(yaw)·(±w/2, ±d/2)` con la rotación horaria del mapa |
| VP-04 | `relieve_mapa` | `height_at` continua en `x ∈ [−1350, 2250]`, `z ∈ [−1050, 1700]` (un poco más que el contexto); `landmarks({})` devuelve todos los hitos con `footprint` y `height_m`; `features(kind)` devuelve arreglos de objetos con `pts` como `{x, z}`; `river().bed_width_m` y `river().pts`; `minimap_image(px, {})` devuelve un `Image` de **exactamente** `px` | Lo que la vista consume | `test_hx_terrain`: esos cinco contratos sobre el terreno real y el stub |
| VP-05 | `ui_feel` / integrador | El controlador pasa a `initial_frame(camera)` la cámara **ya dentro del árbol** (si no, supone 16:9 y 46°); llama `update_state(delta)` cada cuadro; ajusta `camera.far ≥ 9000` | La proyección y las escalas en pantalla salen de la cámara y del `Viewport` | `test_hx_flow`: `initial_frame().fits` con la cámara real a 1280 × 720 y a 1024 × 640 |

## 6. Cómo se corre

```sh
G="C:/Users/User/Desktop/spum/IA/Proyectos/MaravillaArgentina/guemes/patria-guemes/.tools/godot/Godot_v4.7.2-stable_win64_console.exe"
export APPDATA="$TEMP/ap_iso_visual"; rm -rf "$APPDATA"; mkdir -p "$APPDATA"
"$G" --headless --path <worktree> --script tests/test_hx_view.gd -- --ronda=r1.0
"$G" --path <worktree> --resolution 1280x720 --audio-driver Dummy --script tools/vis_humahuaca.gd -- --out=<carpeta> --tag=visual_r1 --extras
#   opciones: --fakes (copias mínimas aunque existan los stubs de las otras pistas) · --view=real · --quality=baja|media|alta · --views=a,b
#             --bench [--bench-tod=0.5 --bench-rain=0.42] · --index-base=N · --hide=Grupo1,Grupo2 (depuración)
```

Evidencia de la ronda: `evidence/humahuaca/r1/visual/` (12 JPEG de ≤ 70 KB y `metrics_visual.json`; las rondas intermedias no entran a Git).
