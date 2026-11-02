# Visual del nivel «Humahuaca»: vista real, arte procedural y estado (pista `visual`)

Documento de la pista `visual` (CONTRATO 1.2). Dice **qué hay en R1** (la vista real, el generador de arte, los shaders, los datos y las herramientas), **qué supone la vista** de las otras capas, **cómo se midió** y **qué falta**. La dirección de arte completa está en `docs/DISENO_HUMAHUACA.md` (sección 11) y la rúbrica que la mide, en `docs/QA_NIVEL2.md` (V01 a V06); este archivo no las repite. Los créditos y la procedencia del arte, en `docs/humahuaca/CREDITOS_VISUAL.md`.

**Canal de arte (A-01):** generador procedural en GDScript (`humahuaca_gen.gd`) y shaders propios. Blender no está autorizado, no hay modelos ni texturas importados y nada de lo que entrega la pista descarga o instala algo.

**Pase 3 de R1.** Cierra los dos hallazgos P2 del QA que quedaban en la pista (**H-R1-9**: las figuras no seguían a sus agrupaciones mientras marchaban, hasta 123 m de desfase; **H-R1-11**: la cinta del río se cortaba en seco, quedaba enterrada y la malla saltaba hasta 0,67 m en la costura de la ventana), más tres filas del backlog que tocaban lo mismo (B-026, B-034 y B-047). Qué se hizo y cómo se mide, en la sección 11.

**Qué cambió en R1.** El stub congelado (`stub_view.gd`) sigue intacto y es la degradación (CONTRATO 7). `view/humahuaca_view.gd` es la **vista real**: el controlador de `ui_feel` la toma sola (la línea roja de la escena real ya no nombra a la vista entre las capas mínimas). Resuelve el hallazgo I-R1.0-3 (sección 9): el alba no lava de naranja, los anillos de visibilidad no se cruzan y las fichas miden ≥ 48 px **por la escena real**.

## 1. Qué entrega R1

| Archivo | Líneas | Qué es |
|---|---|---|
| `scripts/humahuaca/view/humahuaca_view.gd` | 786 | La vista (`Node3D`): las **25 funciones** de CONTRATO 3.4 más `pool_alpha` y `frame_transform`, `selected_ids`, `unit_nodes`, `unit_labels` y la señal `minimap_changed`. Arma luz, cielo y niebla; el cuadro a cuadro; el picking; las cámaras (`initial_frame`, `canonical_view`) y las sondas de QA. Orquesta a los módulos |
| `scripts/humahuaca/view/humahuaca_gfx.gd` | 1 083 | Paleta, materiales, mallas básicas y el **terreno continuo**: ventana, contexto y horizonte con **un solo material** |
| `scripts/humahuaca/view/humahuaca_buildings.gd` | 546 | Hitos (templo, batería, casa del cura, posta, torre), tapias, zanjas y caminos de `terrain.features(...)`, núcleo de casas y anillo de contenido (churqui, cardón, sauce, rocas) |
| `scripts/humahuaca/view/humahuaca_units.gd` | 328 | Las cinco fichas, los defensores y el botín: tamaño fijo en pantalla |
| `scripts/humahuaca/view/humahuaca_fx.gd` | 487 | Luces de la guardia, lluvia, anillos de estado y de visibilidad, efectos |
| `scripts/humahuaca/view/humahuaca_gen.gd` | 862 | El generador procedural de arte: el **templo**, los **tres arquetipos** de figura y el realista de 1817, la torre, la batería, las casas, los cañones, el caballo y la mula, la vegetación |
| `scripts/humahuaca/view/vocab_view.gd` | 28 | Vocabulario de la capa. Solo se **agregó**: `ARCHETYPES`, `BUILDERS`, `TERRAIN_PARTS` |
| `shaders/humahuaca_terrain.gdshader` | 150 | **Un solo shader de suelo** para ventana, costuras, contexto y horizonte |
| `shaders/humahuaca_props.gdshader`, `humahuaca_water.gdshader`, `humahuaca_rain.gdshader` | 48 · 37 · 42 | Edificios y figuras (color de vértice y desgaste), agua y lluvia |
| `shaders/humahuaca_noise.gdshaderinc` | 67 | **Copia** del ruido de la Justina con su procedencia declarada y funciones propias del nivel (nunca se incluye `justina_noise`: CONTRATO 1.3) |
| `data/humahuaca_visual.json` | 268 | Paleta de 24 HEX, 7 vistas, `initial_frame`, luces, lluvia, niebla, materiales, `props`, `tokens`, `units`, calidades, `fx` y `content_ring` |
| `tests/test_hx_view.gd` | 1 349 | **284 comprobaciones** sobre la vista real y el stub (sección 6) |
| `tools/vis_humahuaca.gd` y `.sh` | 1 304 | Capturas reales con ventana, métricas, banco de rendimiento, escena real (`--flow`), render héroe (`--hero`) y relieve de prueba (`--relief`) |

Ningún archivo pasa de 1 500 líneas (el mayor, `humahuaca_gfx.gd`, 1 083), sin `class_name`, con tabuladores y LF. La dependencia va solo hacia abajo (`view` → `gfx`, `buildings`, `units`, `fx` → `gen`); los módulos reciben a los otros por parámetro y no hay ciclos.

## 2. Qué dibuja la vista real

**Terreno continuo.** La ventana jugable sale de `terrain.heightfield()` (226 × 164 nodos a 4 m, con una falda de 3 m); el contexto, de `height_at` sobre cuatro trozos de ≈ 30 m (oeste, este, norte y sur), y **entre la ventana y cada trozo hay una costura de una fila de celdas** (`terreno_costura_*`) cuyos vértices del lado de la ventana son **los mismos nodos de su borde, con la altura exacta de la grilla**, y cuyo lado de afuera se apoya sobre el borde del trozo grueso por interpolación (los vértices de afuera son nodos de la ventana, así que calzan sin quiebre). El horizonte es un anillo de 11 filas que arranca en el perímetro del contexto, **comparte sus vértices** y sigue hasta ±8 km con cerros erosionados cerca y cordillera lejos. Un solo `ShaderMaterial` para todo: sin grietas (se midió 0,0 m entre los vértices del borde) y sin discos. La altura es siempre la del terreno (`height_at` o su grilla), nunca una propia. Si falta el terreno, un plano de +17 m de la misma forma. **Lo que se apoya sobre el suelo** (río, caminos, zanjas) lee la altura de la malla **dibujada** (`gfx.rendered_h`: la interpolación por triángulos de la misma grilla que se dibuja) y no `height_at`, que difiere hasta unos decímetros de la malla lineal.

**Shader del suelo.** Dos texturas de pesos RGBA8 (un texel por nodo, salen de `surface_at` y de la pendiente: suelo seco, sedimento, piedra, churqui, irrigada, agua, camino, zanja) y una de proximidad al río del contexto. Sobre eso: tres escalas de ruido, grava y piedritas, grietas de barro seco, estratos claros en los cerros, matas de arbusto agrupadas, surcos en las parcelas regadas, charcos chicos cerca de la cámara cuando llueve (el suelo se oscurece ×0,75) y curvas de nivel finas (`materials.terreno.contour_m`). El detalle cercano se desvanece entre 30 y 320 m y el micro-relieve de normales entre 12 y 130 m. Las manchas de grava del suelo son blandas y de poca amplitud: con bordes netos y mucha amplitud se leían como camuflaje (se corrigió en esta ronda). Con `set_albedo_mode(true)` el suelo pasa a color plano de la paleta (calibración V04).

**El río.** Dos cintas sobre la malla dibujada: el lecho claro (`rio_lecho`, 9 vértices a lo ancho, ≈ 4 m entre uno y otro, como la grilla de la ventana) y el agua (`rio_agua`, 5 a lo ancho). Las dos van **recortadas al contexto**: la traza llega hasta 3 m del borde, donde termina la malla de suelo (más allá el anillo del horizonte sube y la cinta quedaba enterrada y cortada en seco), y **se apagan en los últimos 450 m** de cada punta recortada (opacidad por color de vértice: el río se pierde en la bruma y no termina en un corte). Dentro de la ventana el agua es plana de orilla a orilla a un nivel apenas sobre el centro del cauce y la orilla la corta donde el suelo sube; lejos de la ventana (el contexto no tiene cauce tallado) la cinta se apoya sobre el suelo en cada vértice. La prolongación de aspecto de la traza al norte ahora **pasa** el borde del contexto (antes terminaba 117 m antes, adentro). Cada vértice y cada punto interior de los triángulos queda **sobre el suelo dibujado** (sección 11). Los caminos y las zanjas usan el mismo método: tramos de 4 m y altura de la malla dibujada.

**Edificios y generador.** Cada hito con huella tiene su nodo. El **templo** es una nave simple de adobe encalado a dos aguas, con contrafuertes, portada lateral y atrio, **sin torres ni fachada de 1880 y con caballete en 7,00 m** (318 triángulos; la prueba mira la altura de sus vértices y los nombres de los nodos). La **batería** es una losa con parapeto, tres piezas bajas y un tinglado de 1,8 m (≤ 3 m sobre el suelo, ≥ 26 m de ancho: nunca un fuste, B-023). La **posta** no tiene muros propios: sus tapias y sus dos entradas salen de `terrain.features("tapia")`. La torre provisional es de madera con plataforma, de 10 m. El núcleo de casas sigue las manzanas del diseño de nivel.

**Anillo de contenido** (0 a 400 m fuera del núcleo): churqui, cardón, sauces de ribera y rocas repartidos según pendiente y cercanía al río (con el terreno de respaldo de la prueba: ≈ 1 370 arbustos, 330 rocas y 59 sauces; cambia con el relieve real porque se reparten por pendiente y cercanía al río). Faltan las parcelas con tapias, las ruinas de la capilla de Santa Bárbara y las huellas de carreta (R2a, sección 10).

**Fichas, defensores y botín.** Cada agrupación tiene **su silueta**, armada en partes con contorno oscuro: jinete (Rodríguez), infante con fusil (Portal), infante con el banderín de mando (Arias; es un marcador de interfaz, nunca una bandera), dos figuras agachadas (reconocedores) y mula cargada (arreo). Cada ficha tiene ≥ 8 nodos hijos (partes y tres anillos: bando, borde y selección). **Cada figura sigue a su agrupación cuadro a cuadro** (a ×1, ×2 y ×4, desfase 0,0 m; sección 11). El bando lo dan el anillo y el contorno, no el color de la ropa. Los defensores usan el arquetipo del enemigo (realista de 1817, artillero, poncho y sombrero), con tope de 48.

**Luces.** Las tres de los objetivos (brasero en la batería, ventana en la casa del cura, candil en la posta) y las fogatas de la guardia: una esfera cálida, un resplandor aditivo de ≥ 30 px y una mancha cálida en el suelo se ven **de lejos** a 470 m (son información, no decorado); en `media` y `alta` suma una `OmniLight3D` sin sombra (hasta 4 y 8).

**Lluvia, anillos y efectos.** La lluvia son rayas en el espacio de la cámara (`humahuaca_rain.gdshader`; 0, 700 y 1 400 según la calidad). Los anillos de objetivo miden 4 px y el de visibilidad es el contorno de la **unión** de los círculos (2 px, tenue, se apaga con luz plena). Efectos: fogonazo, humo, impacto, captura, pisadas, explosión y señal, con tope por calidad.

**Luz, cielo y niebla.** Salen de `environment().time_of_day` (0 = noche plena, 0,5 = alba, 1 = día) y de las tres claves de `humahuaca_visual.json: lights`; un solo `Environment` por escena, sin `shader_globals` ni ajustes de render en `project.godot`. El alba es cálido sin saturar (lino mezclado 40 % con oro) y las sombras del sol se encienden a mitad de camino entre la noche y el alba.

**Calidad.** `baja` (ventana a 8 m, sin sombras, sin luces reales ni lluvia, menos casas y vegetación), `media` y `alta` (más casas y vegetación, 8 luces reales). Una calidad desconocida se trata como `media`.

## 3. Convenciones que la vista supone

1. **Ejes:** los del CONTRATO 0 (+x este, +z sur, norte = −z). `yaw_deg` de unidades, hitos y cámaras es un **rumbo**: grados horarios desde el norte, vistos en el mapa.
2. **Huella de un hito:** `{w, d}` es un rectángulo con `w` sobre +x y `d` sobre +z antes de girar `yaw_deg`; `{r}` un círculo; `{poly}` se reduce a su caja envolvente.
3. **`environment().time_of_day`** es continuo y creciente: 0 = noche plena, 0,5 = alba (4:45), 1 = día pleno.
4. **`render_state().version`** sube con cada cambio de reglas, pero **no cuando una agrupación se mueve**: las reglas mueven a las agrupaciones en cada paso sin subirla (H-R1-9). Por eso la vista lee la **pose** (posición y rumbo) de las cinco fichas **en cada cuadro** (cuesta cinco nodos) y mueve los círculos de visibilidad que las siguen cuando alguna se corrió 1,5 m o cambió 1 m de radio, a lo sumo cada 0,06 s (rearmarlos cuesta ≈ 1 ms). Lo caro (defensores, botín, luces, anillos de los objetivos) se reconstruye solo si cambia la versión.
5. **Tamaños en píxeles** (`tokens.*.min_px`, `quality.*.enemy_min_px`) son **píxeles reales de la pantalla**: la vista divide por la escala de la ventana. El picking, `landmark_labels` y `probes` hablan en píxeles **lógicos**. El área lógica sigue el aspecto de la ventana: **16:9 a 1280 × 720 (1 600 × 900) y 16:10 a 1024 × 640**; por eso `initial_frame` da 470 m en 16:9 y 528,7 m en 16:10 (sección 4.1).
6. **Escala de las fichas.** Una ficha parada se ve más baja cuanto más empinado se la mira. La vista la estima por el seno del ángulo del rayo (estirando solo el alto, hasta 4,6 veces) y **la corrige con una medición de verdad**: proyecta el pie y la cabeza con la cámara que se dibuja y ajusta el alto, con un 3 % de más (el pedido es un mínimo). Así miden ≥ 48 px con cualquier rumbo y en las esquinas del cuadro (en la escena real la estimación sola dejaba al jinete en 44 px). Casi desde arriba la altura no se puede sostener (de arriba no se ve la altura de una figura) y estirarla más la vuelve un trazo largo hacia el nadir: pasados los 58° el tope del estirón baja de 6,9 a 2,2 veces (a los 76°) y, entre los 60° y los 80°, el alto pedido baja a los dos tercios; la ficha queda legible por su anillo y su silueta vista desde arriba. El controlador de R1 deja inclinar la cámara hasta 80°.
7. **Orden de un cuadro.** `main` deja la cámara donde la quería el menú, el controlador llama a `update_state(delta)` con **esa** cámara y recién al final de su `_process` la ubica. Lo que depende de la cámara (escala de fichas, luces y etiquetas, ancho de los anillos) lo recalcula también el `_process` de la vista, que corre después del de su padre. Lo mejor sigue siendo que el controlador ubique la cámara antes (VP-08). **Las dos llamadas llegan a la misma función y miden una sola vez por cada cámara distinta** (firma: pose, fov, tamaño y escala de la ventana, y una serie que sube cuando cambia lo dibujado): con la cámara quieta y nada movido no se vuelve a medir ni en ese cuadro ni en los siguientes (BACKLOG B-047; `view.scale_updates` lo cuenta y `test_hx_view` lo fija). Las dos entradas siguen existiendo por lo de A-11: `update_state` puede llegar antes de que el controlador ubique la cámara.
8. **`yaw_deg` de la cámara es el rumbo de la mirada** (A-11): `initial_frame`, `canonical_view` y `qa_set_camera` dicen hacia dónde **mira**; la posición es `target + (−sin yaw · cos pitch, sin pitch, cos yaw · cos pitch) · distancia`. La primera versión del controlador usa `+sin(yaw)`, que es el espejo (VP-07).
9. **Colores:** solo ids de la paleta; los `markers` de bando (celeste con borde blanco, borgoña con borde negro, dorado) llevan también el HEX exacto porque son marcadores de **interfaz**.
10. **Vistas canónicas:** `canonical_views` es un arreglo de objetos con `id` (en el orden de `VIEW_IDS`), `target {x, z}`, `distance`, `pitch_deg`, `yaw_deg`, `time_of_day`, `rain` y `must_show` (5 rasgos). `juego_noche` y `juego_alba` repiten la cámara de `initial_frame`.

## 4. Cámara inicial, vistas canónicas y medidas

### 4.1 `initial_frame(camera)` y las cinco partidas

Parte de `data/humahuaca_visual.json: initial_frame` (objetivo (350, 470), 470 m, 52°, **rumbo 325°**) y solo se **ensancha** (pasos de 4 %, hasta 900 m) si no entran, con 5 % de borde libre, los hitos de `must_include`: `bateria`, `cuartel`, `posta`, el centro de `zona_partida` y **las cinco partidas** (`spawn_*`). La proyección se calcula a mano y no mueve la cámara real. La decisión de poner las cinco partidas en el cuadro es de A-11 (con el rumbo 325° entran con 5 % de borde libre).

| Ventana (área lógica) | Distancia | Peor margen al borde (partida) | Tres objetivos y zona |
|---|---|---|---|
| 1024 × 640 (16:10) | **528,7 m** (tres pasos del 4 %) | 6,6 % (arreo) | a ≥ 10,3 % (la posta, la más cercana al borde) |
| 1280 × 720, 1920 × 1080 y 2560 × 1440 (16:9) | 470 m | 6,3 % (arreo) | a ≥ 9,9 % (la posta) |

Esto **se aparta de la estimación del pase 2** de R1.0 (a 1024 × 640, «de 470 a 488,8 m, arreo a 3,2 %»): con 5 % de margen exigido a las cinco hacen falta tres pasos y no uno. El cuadro de 528,7 m es un 12 % más lejos que el de 470 m. `ui_feel` tiene que **usar la distancia que devuelve `initial_frame`** como zoom inicial y dejar un zoom máximo ≥ 530 m (VP-12).

**Rumbo, en una línea.** Con el dato en 325° y la cámara corregida (VP-07, ya entró con el merge de `ui_feel`) el jugador ve lo mismo que midió `fits`: el cuadro de la escena real (evidencia 01 a 03) mira al noroeste y entran las cinco partidas. Con el dato en 325° y la cámara espejada de R1.0 el cuadro salía al revés (mira al noreste y el arreo caía fuera de pantalla a 1280 × 720). El cambio de dato y el de cámara entraron **en el mismo paso de integración** (A-11).

### 4.2 Las 7 vistas y sus 5 rasgos

Escritas antes de pintar (CONTRATO 11, regla 7) a partir del anexo B del QA; cada lista es el `must_show` del JSON. Las siete vistas canónicas las captura el QA (`hx_qa_tour.gd`); en la evidencia de este pase están `desde_bateria` y `panorama_alto` (09 y 10) y el cuadro de juego de noche y de alba por la escena real (01 a 03).

| Vista | Cámara (objetivo · distancia · inclinación · rumbo) | Luz | Rasgos |
|---|---|---|---|
| `acceso_so` | (300, 520) · 150 m · 22° · 45° | noche con lluvia | ladera, núcleo (≥ 3 edificios) y templo al fondo · templo a dos aguas sin torres · lluvia y escena legible con ≥ 2 fichas · sin monumento, escalinata, postes, tendidos ni álamos · la interfaz no tapa el núcleo |
| `desde_bateria` | (318, 350) · 60 m · 18° · 90° | alba | el pueblo por debajo, al este · río o lecho claro al fondo · parapeto y ≥ 1 pieza en primer plano · luz cálida con sombras largas · sin torres de 1880 |
| `patio_posta` | (590, 300) · 45 m · 40° · 315° | mañana | muros del patio con sus dos entradas · ≥ 3 clases de objeto · solo adobe, madera y cuero · polvorín al noreste · se ve cuánto se carga |
| `panorama_alto` | (450, 330) · 330 m · 28° · 90° | alba | ladera, núcleo, monte ribereño, lecho claro, llanura, cerros y horizonte · sin torres ni monumento · luz cálida y sombras largas · sin huecos ni borde del mundo · techos claros entre arbolado oscuro |
| `grupos_en_accion` | (418, 335) · 90 m · 45° · 0° | alba, lluvia floja | torre con plataforma · fuego o humo desde la torre · ≥ 3 fichas · líneas de fuego o impactos · bajas o estado a la vista |
| `juego_noche` | `initial_frame` · 470 m (528,7 m en 16:10) · 52° · **325°** | noche con lluvia, t = 0 | ≥ 3 puntos de luz · los tres objetivos sin leer texto · relieve y núcleo visibles · ≥ 3 fichas distinguibles · la interfaz no tapa los objetivos |
| `juego_alba` | la misma cámara | alba (≈ 4:45) | sombras largas y luz cálida · fichas en sus puestos y fogatas · los tres objetivos · el núcleo se distingue por luz y trazo · sin torres ni monumento |

### 4.3 Medidas (esta máquina, pase 3 de R1)

GPU NVIDIA GeForce RTX 3080 Ti, Forward+, Godot 4.7.2, ventana de 1440 × 900, sin vsync y sin otra corrida en paralelo.

**Presupuesto oficial** (`python -I tools/benchmark.py --binary $G --project . --output <carpeta> --profiles baja,media,alta --scenarios humahuaca --repeat 3 --renderer forward_plus --max-frame-ms 4`, escena real con el controlador, partida en pleno ataque con lluvia, fichas y fogonazos). El cuadro medio es la media de las tres repeticiones y «peor» la mayor de las tres:

| Calidad | Cuadro medio (tope) | Peor repetición | p95 (tope 8,3) | `start()` completo (tope 1 500) |
|---|---|---|---|---|
| baja | **1,419 ms** (2,5) | 1,615 ms | 4,211 ms | 839 ms |
| media | **1,427 ms** (4,0) | 1,639 ms | 2,248 ms | 1 018 ms |
| alta | **1,420 ms** (6,0) | 1,567 ms | 1,964 ms | 1 157 ms |

Con `main` sin estos cambios, el mismo comando en `media` dio 1,525 ms (peor 1,662, p95 3,910 y `start()` 979 ms): el cuadro baja un poco (la escala por cámara ya no se mide dos veces por cuadro, B-047) y la construcción sube ≈ 40 ms (las costuras, la cinta del río y las cintas del suelo leen la malla dibujada). La construcción de la vista sola (`vis_humahuaca --bench`, sin reglas ni controlador) es de 414 ms en `baja`, 549 ms en `media` y 638 ms en `alta`, bajo el presupuesto propuesto de ≈ 800 ms.

**En la herramienta** (`tools/vis_humahuaca.sh <carpeta> 1440x900 --no-views --bench --bench-tod=0.5 --bench-rain=0.42 --quality=<calidad>`: la vista sola sobre las reglas del stub «vestidas», 180 cuadros tras 30 de calentamiento, alba con lluvia 0,42; informativa):

| Calidad | Construir la vista | Cuadro medio | p95 | Llamadas de dibujo | Primitivas |
|---|---|---|---|---|---|
| baja | 414 ms | 1,34 ms | 1,62 ms | 170 | 139 254 |
| media | 549 ms | 1,79 ms | 2,31 ms | 233 | 392 914 |
| alta | 638 ms | 1,92 ms | 2,47 ms | 233 | 486 048 |

La construcción por etapa (prueba sin ventana, `media`): terreno ≈ 140 a 200 ms (incluye costuras, cinta del río y cintas del suelo), núcleo y vegetación ≈ 125 a 170 ms, hitos y rasgos ≈ 15 a 22 ms y fichas y lluvia ≈ 10 ms. En una GPU más débil habrá que volver a medir.

**Alto de las fichas** (de la base a la cima de sus piezas, píxeles reales):

| Cuadro | Arias | Arreo | Portal | Reconocedores | Rodríguez |
|---|---|---|---|---|---|
| Cuadro inicial (herramienta, 1152 × 720) | 70,4 | 57,6 | 57,4 | 49,3 | 59,4 |
| Escena real a 1280 × 720: aproximación (`--flow`, lo que ve el jugador) | 70,9 | 57,3 | 57,4 | 49,3 | 59,2 |
| Escena real: ataque a 300 s y extracción a 321 s | 70,5 | 57,8 | 57,4 | 49,3 | 59,4 |
| `token_px` del recorrido de QA (`probes()` × la escala de la ventana; B-026) | 57,7 | 57,4 | 57,4 | 49,3 | 59,2 |

Pedido de 58 px en una grilla de 5 × 5 posiciones del cuadro: **58,5 a 60,4 px** con la corrección (53,8 a 71,1 px con la estimación sola; `test_hx_view`).

**I-R1.0-3 en píxeles** (escena real y capturas de juego): naranja saturado **0,0 a 0,3 %** en `juego_alba`, ataque y extracción (tope 5 %); saturación media 0,267 en `juego_alba`, 0,317 en el ataque y 0,345 en la extracción (tope 0,42); **0,0 m** de trazo de un anillo de visibilidad dentro de otro círculo en las tres fases (tope 5 m).

**Picking:** las cinco fichas, los tres frentes y la ida y vuelta del rayo al suelo a 0,00 m en los tres hitos (tope 3 m). `meters_per_pixel` en la cámara inicial: 0,674 m/px.

### 4.4 Lo que no cumple todavía (V06, informativo en R1)

La rúbrica V06 no se exige en R1 (`QA_NIVEL2.md`, tabla de rondas). La riqueza de bordes con la grilla de 8 × 6 (gradiente > 12) sobre las capturas finales: la baldosa con menos bordes es el **27 %** de la mediana en `juego_noche` y el **25 %** en `juego_alba` (piso 40 %); es siempre la fila de abajo del cuadro, el suelo a 300 a 450 m, donde ya no hay detalle cercano. En `panorama_alto` y en `desde_bateria` es el 9 %. La correlación del perfil de luminosidad de `panorama_alto` con la foto de 1923 (24 franjas horizontales, medición de apoyo) es negativa (−0,17 y −0,77 sin la tendencia lineal): la foto tiene cielo, cerros claros, llanura oscura y techos claros, y la vista de diseño (28°) no muestra el cielo. Ninguna de las dos se va a arreglar sin tocar la cámara del diseño o sumar capas de detalle a media distancia: lista de R2a (sección 10). La cuenta oficial la hace QA con su propio script.

## 5. Render héroe y arquetipos

`tools/vis_humahuaca.sh <carpeta> 1280x720 --no-views --hero` arma un estudio (suelo y cielo lisos, sol bajo y cálido) y guarda tres imágenes y las métricas:

- **El templo** (captura 11): nave de adobe encalado a dos aguas, contrafuertes, portada lateral y atrio; ningún vértice pasa del caballete de 7,00 m.
- **Los arquetipos** (captura 12): poncho y sombrero, camisa y gorra, artillero y realista de 1817, más el jinete y la mula.
- **Escala de grises a 48 px** (captura 13): los arquetipos y las cinco siluetas de ficha rellenas, con su luminosidad L* media. El piso de la rúbrica (V03) es **ΔL\* ≥ 15 entre cada par de arquetipos**:

| Par | ΔL\* | Par | ΔL\* |
|---|---|---|---|
| poncho y camisa | 48,2 | camisa y artillero | 32,1 |
| poncho y artillero | 16,1 | camisa y realista | 16,5 |
| poncho y realista | 31,7 | artillero y realista | **15,6** (el mínimo) |

**Quién aprueba el render héroe sin personas** queda como pedido (VP-14). La propuesta de `visual`: lo miran los tres certificadores con `Read` y responden por escrito la lista de la rúbrica (V01) más estas dos cifras, el integrador lo registra en `ADDENDA.md`, y la aprobación humana del usuario queda para antes de publicar.

## 6. Pruebas

`tests/test_hx_view.gd`: **284 comprobaciones, 0 fallas, ≈ 10 s** sin ventana (en R1.0 eran 105; la compuerta pide ≥ 25). Corre dos veces la misma batería, con la vista real y con el stub (cada comprobación lleva su etiqueta `[real]` o `[stub]`), y suma las propias de la vista real:

- archivos ≤ 1 500 líneas, con tabuladores y LF y sin `class_name`; los cinco shaders existen, el del suelo incluye la copia del ruido y ningún shader incluye `justina_`; nada de `shader_globals`;
- **un solo material** de suelo, las seis partes del terreno más las **cuatro costuras**, malla hasta ±8 km, presupuesto de triángulos, y los vértices del borde de la ventana y de las costuras coinciden (0,000 m);
- batería ≤ 3 m y ≥ 26 m de ancho, sin columnas; las tapias de la posta salen del terreno y la posta no tiene muros propios; tapias con sus rasgos; las luces tienen resplandor y mancha; la lluvia es un `MultiMesh`;
- calidad: `baja` arma menos terreno que `media` y no dibuja lluvia; modo albedo;
- **A-11:** los tres datos de rumbo, el cuadro inicial con las cinco partidas a ≥ 5 % en cuatro resoluciones (528,7 m a 1024 × 640 y 470 m en las otras tres, con 6,5 % y 6,2 % de peor margen);
- ΔL\* del color de los arquetipos de a pares ≥ 8 (el render a 48 px se mide con `--hero`);
- **V03 con cualquier cámara** (8 poses y una grilla de 25 posiciones por rumbo): las fichas miden ≥ 47 px; y a 78° el estirón queda en ≤ 2,3 veces;
- **H-R1-11 sobre la malla dibujada** (`_test_terrain_rendered`, con el terreno y las reglas reales y rayos contra los triángulos de `Terreno`, como lo mide el QA): salto de la malla en las cuatro costuras de la ventana y en el perímetro del contexto ≤ 0,10 m (se midió ≤ 0,004 m); ningún vértice de `rio_agua` ni de `rio_lecho` bajo el suelo y ninguno a más de 2,5 m (1 530 y 2 754 vértices; el más bajo a 0,17 y 0,20 m sobre el suelo); **tampoco ningún punto interior** de sus triángulos (7 320 y 14 640 puntos medidos, 0 tapados); las dos puntas de la cinta a ≤ 8 m del borde del contexto y apagadas (opacidad 0); caminos y zanjas (1 438 vértices) sobre el suelo;
- **H-R1-9** (`_test_units_follow_rules`, con las reglas y la vista reales, avanzando las reglas como el controlador: `tick(dt × velocidad)` y `update_state` en cada cuadro, cinco órdenes de marcha): a ×1, ×2 y ×4 la figura de cada agrupación queda a ≤ 1 m de su posición en las reglas en los 360 cuadros (se midió 0,000 m), se mueve en cada cuadro en que se mueve la agrupación y los círculos de visibilidad la siguen a ≤ 4 m (0,77 m);
- **B-026 y B-034** (`_test_probes_and_scales`): el rectángulo de la ficha en `probes()` mide el alto dibujado (a ≤ 1 px) y por la escala de la ventana da ≥ 48 px; toda sonda trae `on_screen` y coincide con que su rectángulo caiga entero dentro del cuadro; **B-047**: la escala se mide una vez por cámara distinta.

Se probó que las pruebas **ven** lo que cuidan: sin la corrección con la proyección la grilla mide de 53,8 a 71,1 px y falla en los dos rumbos; con el signo de la inclinación invertido (un error que se cometió y que esta prueba vio) el estirón a 78° da 6,90; sin el `_process` de la vista la ficha queda a escala 4,60 en vez de 12,87 (pase 2); con el alba de oro puro el suelo da 0,54 y 0,66 de saturación contra los topes de 0,40 y 0,46. **Pase 3:** corridas contra `main` sin estos cambios (en un worktree aparte, con las pruebas nuevas): las costuras dan 0,674 m en x = 900 y 0,32 m en z = 0, 9 de 78 vértices de `rio_agua` quedan bajo el suelo (hasta −4,77 m), las puntas quedan a 116,7 m del borde del contexto y las figuras quedan a 18,5, 37,0 y 74,0 m de su agrupación a ×1, ×2 y ×4 (6 s a 60 cuadros por segundo, cinco órdenes de marcha); la sonda propia del Jefe de QA (`jefe_desfase_probe.gd`, escena real y tiempo real) da 30,8, 92,5 y 123,4 m antes y **0,0 m** después en los tres.

`tools/vis_humahuaca.gd` con ventana: 44 comprobaciones en las capturas de juego (7 vistas, albedo, minimapa y efectos), 29 a 1024 × 640, 30 por la escena real (`--flow`: tres fases y **la marcha de las cinco agrupaciones a ×1 y ×4 durante 2,5 s reales cada una: desfase 0,000 m**; contra `main` sin cambios esa comprobación falla con 7,7 y 38,6 m) y 10 del render héroe; **0 fallas** en todas. El paso `vis_flow` de la compuerta completa (B-024) corre `--flow`, así que ahora también vigila H-R1-9.

**Compuerta rápida** (`bash tools/qa_gate.sh quick visual`, ≈ 2 min, rama rebaseada sobre `main`): importación, protegidos (40 intactos), compartidos, propiedad (todos los archivos cambiados son de `visual`), `rules` 818/0, `integracion` 283/0, `hx_data` 420/0, `hx_smoke` 158/0, `hx_view` 284/0 y `salida_limpia` (ningún `SCRIPT ERROR`, `SHADER ERROR`, `Parse Error` ni fuga). **Falla solo `higiene`**: las etiquetas `v0.2.0-alpha` y `v0.3.0-alpha` que no son de esta rama (B-017, H-R1-3: la decisión es del usuario).

## 7. Pedidos a las otras pistas (id, firma, motivo y prueba de aceptación)

Los VP-01 a VP-09 de R1.0 siguen escritos en la historia de este archivo. Estado de los que la vista real vuelve a tocar, al cierre del pase 3 de R1 (ADDENDA A-13 y A-14):

| Id | A quién | Pedido | Estado |
|---|---|---|---|
| VP-07 | `ui_feel` (por el integrador) | La cámara del controlador usa `yaw_deg` como rumbo de la mirada: `offset = (−sin yaw · cos pitch, sin pitch, cos yaw · cos pitch) · distancia`, junto con el dato `initial_frame.yaw_deg = 325` | **Hecho** (entró con el merge de `ui_feel`; `test_hx_flow` fija la mirada a (1, 0) ± 0,02) |
| VP-10 | integrador | Registrar en `ADDENDA.md` el cambio de `initial_frame.yaw_deg` (35° → 325°, con `juego_noche` y `juego_alba`) y que `must_include` suma las cinco partidas (A-07 pasa a «se ensancha solo en 16:10») | **Hecho** (A-13, punto 4) |
| VP-11 | compuertas y documentos | Encender V15 y V22 de `test_hx_data` | **Hecho** (corren desde `r1`) |
| VP-12 | `ui_feel` | Usar `initial_frame(camera).distance` como zoom inicial y dejar el zoom máximo en ≥ 530 m | **Hecho** (`ui.camera.max_distance_m` es 900 m; el cuadro inicial se mide en `test_hx_flow` y en el recorrido) |
| VP-13 | compuertas y documentos | Sumar `vis_humahuaca.sh --flow` a la compuerta completa (B-024) | **Hecho** (paso `vis_flow`; desde el pase 3 también mide la marcha de las cinco agrupaciones: H-R1-9) |
| VP-14 | integrador y QA | **Quién aprueba el render héroe sin personas** | **Regla adoptada** (A-13: lo miran los certificadores del QA con `Read` y responden por escrito la lista de V01 más las dos cifras; el integrador lo registra). **Falta la respuesta del QA**: el render héroe de este pase está en `evidence/humahuaca/r1/visual/11_` a `13_` |
| VP-15 (nuevo) | compuertas y documentos | Filas de trazabilidad para lo que cierra el pase 3: H-R1-9 (`test_hx_view::_test_units_follow_rules` y `tools/vis_humahuaca.gd --flow`, clave `marcha`), H-R1-11 (`test_hx_view::_test_terrain_rendered`) y B-026, B-034 y B-047 (`test_hx_view::_test_probes_and_scales`) | **Pedido**: `TRAZA.md` es de compuertas y documentos y V20 exige una fila por exigencia |
| VP-16 (nuevo) | compuertas y documentos | Estado de las filas del backlog que toca el pase 3: B-026 (probes en píxeles lógicos con el alto dibujado: `token_px` del recorrido da 49,3 a 59,2 px), B-029 (el río ya no termina en seco en `limite_n` ni `limite_s`), B-034 (las sondas traen `on_screen`; los rasgos del contenido y las hojas de portón siguen para R2a), B-047 (una medición por cámara distinta) y B-051 (las dos cadenas con snake_case de `humahuaca_visual.json` están reescritas; los ids `juego_noche` y `royalist_1817` no se muestran en ninguna pantalla) | **Pedido**: el backlog es de compuertas y documentos |

## 8. Cómo se corre

```sh
G="C:/Users/User/Desktop/spum/IA/Proyectos/MaravillaArgentina/guemes/patria-guemes/.tools/godot/Godot_v4.7.2-stable_win64_console.exe"
export APPDATA="$TEMP/ap_iso_visual"; rm -rf "$APPDATA"; mkdir -p "$APPDATA"
"$G" --headless --path <worktree> --script tests/test_hx_view.gd -- --ronda=r1
bash tools/vis_humahuaca.sh <carpeta> 1280x720 --extras --tag=visual_r1                                              # las 7 vistas + albedo, minimapa y efectos (con el terreno real)
bash tools/vis_humahuaca.sh <carpeta> 1280x720 --no-views --hero --tag=visual_r1                                     # el render héroe
bash tools/vis_humahuaca.sh <carpeta> 1280x720 --no-views --tag=visual_r1 --flow=aproximacion,ataque@300,extraccion@321   # la escena real con el controlador y la marcha de las cinco agrupaciones (H-R1-9)
bash tools/vis_humahuaca.sh <carpeta> 1440x900 --no-views --bench --bench-tod=0.5 --bench-rain=0.42 --quality=media      # el banco (baja, media, alta)
python -I tools/benchmark.py --binary "$G" --project . --output <carpeta> --profiles baja,media,alta --scenarios humahuaca --repeat 3 --renderer forward_plus --max-frame-ms 4   # el presupuesto oficial (a solas)
```

Opciones de `tools/vis_humahuaca.gd` (están en su encabezado): `--view=stub|real` (por defecto la real), `--relief=<carpeta>`, `--quality=`, `--views=a,b`, `--extras`, `--hero`, `--bench`, `--scenes=`, `--flow=`, `--cam=ui`, `--no-dress`, `--fakes`, `--hide=`.

**Relieve.** Con la clase real de `relieve_mapa` en `main` las capturas de este pase usan **el terreno real del juego** (lámina 03 reconstruida, ±10 m): ya no hace falta el relieve de prueba. `--relief=<carpeta>` sigue existiendo para quien quiera ver el suelo con el DEM de Copernicus GLO-30 que preparó el explorador (**fuera del repositorio**) sobre el terreno de respaldo; el juego no incluye ningún dato de Copernicus (créditos y aviso de la licencia en `CREDITOS_VISUAL.md`).

Evidencia del pase 3 (`evidence/humahuaca/r1/visual/`: 14 JPEG de ≤ 300 KB y un `metrics_visual.json`; **no entra a Git**): 01 a 03 la escena real con el controlador (aproximación, ataque y extracción), 04 y 05 los límites norte y sur con la cámara del recorrido de QA (el río continuo y apagándose), 06 y 07 la costura este de la ventana antes y después (H-R1-11), 08 el río dentro de la ventana, 09 `desde_bateria`, 10 `panorama_alto`, 11 a 13 el render héroe (templo, arquetipos, grises a 48 px) y 14 las cinco fichas de cerca. La evidencia de los pases anteriores está en `respaldos/evidencia_humahuaca_r1_visual_pase2/` (fuera del repositorio).

## 9. Hallazgo I-R1.0-3 (P0 del integrador): el alba lavaba todo de naranja y los anillos ensuciaban el mapa

**Qué decía.** En la captura de extracción el alba del stub lavaba todo de naranja saturado y los anillos de radio de las fichas se superponían y ensuciaban el mapa; a 1024 × 640 el arreo tocaba el borde del cuadro inicial. Aceptación: la compuerta rápida pasa.

**Qué se encontró al reproducirlo por la escena real** (`--flow`, 1280 × 720): (1) el sol del alba era `oro_laton` sobre un suelo ya cálido y el 62,8 % de los píxeles de la extracción (81,7 % del ataque) quedaban en «naranja saturado» (saturación ≥ 0,55, brillo ≥ 0,30, matiz de 15° a 50°); (2) `visibility_pools` trae un círculo por ficha con el radio de `environment().visibility_m` y dibujados enteros se cruzaban (2 311,5 m de trazo dentro de otro círculo); (3) las fichas medían de 11,4 a 33,1 px porque la vista calculaba su tamaño con la cámara del menú; (4) la cámara del controlador es el espejo de la de `initial_frame` (VP-07).

**Qué conserva la vista real** (a) el alba no pasa de «naranja saturado» (≤ 5 % de los píxeles) ni de saturación media 0,42 (medido: 0,0 % y 0,253 a 0,362); (b) los anillos de visibilidad son el contorno de la unión (sin cruces), de 2 px, tenues, y se apagan con luz plena (medido: 0,0 m de trazo dentro de otro círculo); (c) lo que depende de la cámara se calcula con la cámara que se dibuja, aunque el controlador llame a `update_state` antes de ubicarla (el `_process` de la vista y la corrección con la proyección de la sección 3.6); (d) las fichas miden ≥ 48 px **por la escena real** (medido: 49,3 a 69,7 px). Las pruebas de la vista real repiten las cuatro (sección 6), y `--flow` las mide sobre los píxeles de cada captura.

**Cómo se prueba.** `test_hx_view`: `_test_dawn_wash`, `_test_visibility_rings`, `_test_camera_order`, `_test_token_px_any_camera` y `_test_upright_scale_grid`. `tools/vis_humahuaca.gd` aplica los mismos umbrales sobre los píxeles de cada captura de juego.

## 10. Límites y lista para R2a

- **Integración:** la vista corre dentro del controlador real y de `main.tscn` con las cuatro capas reales (`qa_state().layers`): `--flow`, el recorrido de QA, `ui_qa_humahuaca` (136 comprobaciones, 0 fallas), el banco de la herramienta y `benchmark.py` (sección 4.3).
- **V06** no cumple (sección 4.4): detalle a 300 a 450 m, capas de media distancia y cielo en `panorama_alto`.
- **Anillo de contenido:** faltan las parcelas con tapias, las ruinas de la capilla de Santa Bárbara y las huellas de carreta.
- **Portillos y hojas de las tapias de la posta:** las entradas salen de `terrain.features`; no hay hojas de portón.
- **Líneas de fuego:** `render_state().fire_lines` (la volea de la torre) no se dibuja todavía; M05 las pide (V01, desde R2b). También para R2b, el encuadre canónico de `grupos_en_accion` (90 m) no alcanza a las tres partidas que disparan desde 82 a 100 m (B-053, a).
- **Fichas:** la de los reconocedores (dos figuras agachadas) sigue siendo la más ambigua desde la cámara de juego y las que comparten objetivo se superponen (B-049, R2a y R3).
- **El río de noche** se lee como una banda clara (lecho de piedra clara y agua con brillo de luna): es información (la foto de 1923 muestra el lecho claro) pero llama más que las luces de la guardia; queda para el pulido de R3 con las métricas de V06.
- **Sonido:** no es de esta pista en R1.
- **Render héroe:** sin aprobación (VP-14). Las figuras son de baja poligonación (≈ 230 a 550 triángulos por ficha) y sin rostro: la lectura es por silueta, no por detalle.
- **Rendimiento:** medido en una RTX 3080 Ti; falta una GPU débil.

## 11. Pase 3 de R1: H-R1-9 y H-R1-11

**H-R1-9 (P2) · las figuras no seguían a sus agrupaciones.** *Síntoma:* con las cinco partidas en marcha las figuras quedaban quietas hasta un evento y saltaban hasta 123 m (30,8 m a ×1, 92,5 m a ×2, 123,4 m a ×4 en la sonda del Jefe de QA). *Causa:* `update_state` solo llamaba a `_sync_dynamic` (y con él a la pose de las fichas) cuando cambiaba `render_state().version`, y `HumahuacaRules._move_unit` mueve las posiciones sin subir esa versión. *Arreglo (solo de `visual`):* la pose (posición y rumbo) de las cinco fichas se lee **en cada cuadro** (`units.sync_poses`) y los círculos de visibilidad, que también cuelgan de esas posiciones, se rearman cuando alguna se corre 1,5 m (o cambia 1 m de radio), a lo sumo cada 0,06 s (`fxm.follow_pools`). *Medida:* sonda del Jefe de QA sobre la escena real, 10 s reales por velocidad: **0,0 m** a ×1, ×2 y ×4 (40, 80 y 160 cuadros con la agrupación movida y exactamente los mismos con la figura movida; antes 0, 0 y 2) y sin resincronizaciones. *Pruebas:* `test_hx_view::_test_units_follow_rules` (reglas y vista reales; desfase máximo 0,000 m y círculos a 0,77 m) y la comprobación `marcha` de `tools/vis_humahuaca.gd --flow` (escena real con ventana; la corre `vis_flow` de la compuerta completa). Ninguna de las dos pasa con la vista de `main`.

**H-R1-11 (P2) · el río y la malla.** *Síntoma:* la cinta del río se cortaba en seco en los límites norte y sur, quedaba enterrada en 9 de 78 vértices (hasta −4,77 m) y la malla dibujada saltaba hasta 0,674 m en la costura este de la ventana y 0,32 m en la norte. *Causas:* (1) el contexto tenía un vértice cada ≈ 30 m sobre el borde de la ventana, que tiene uno cada 4 m, y donde el borde tiene un cauce tallado la cuerda de 30 m se aparta hasta 0,67 m; (2) las cintas leían `height_at` y no la malla lineal que se dibuja, y la cinta del río era plana a la altura de su eje con dos vértices a lo ancho, así que el suelo asomaba entre ellos y se enterraba donde el terreno sube; (3) la prolongación de aspecto de la traza hacia el norte terminaba 117 m antes del borde del contexto, adentro del paisaje, y la del sur seguía más allá de la malla, donde el anillo del horizonte sube y la tapaba. *Arreglo (solo de `visual`):* costuras de una fila de celdas con los nodos exactos del borde de la ventana; `gfx.rendered_h` (altura de la malla dibujada, por triángulos) para todo lo que se apoya en el suelo; cintas del río con 9 y 5 vértices a lo ancho, muestras cada 5 m cerca de la ventana y cada ≈ 16 m lejos, **recortadas al contexto y apagadas en los últimos 450 m** de cada punta recortada; la traza del norte pasa el borde; caminos y zanjas en tramos de 4 m sobre la malla dibujada (el revisor había medido 82 de 336 vértices de «cintas del suelo» bajo el suelo, hasta −0,98 m). *Medida* con los rayos contra los triángulos de `Terreno`: salto de la malla **≤ 0,004 m** en las cuatro costuras de la ventana y las cuatro del perímetro del contexto (antes 0,674 y 0,32 m); **0 de 1 530 y 0 de 2 754** vértices del agua y del lecho bajo el suelo (el más bajo a 0,17 y 0,20 m) y 0 de 7 320 y 0 de 14 640 puntos interiores de sus triángulos; las puntas a 5,3 y 7,6 m del borde del contexto, con opacidad 0; 0 de 1 438 vértices de caminos y zanjas bajo el suelo. Capturas `limite_n` y `limite_s` del recorrido de QA con el río continuo hasta el borde y apagándose en la bruma (evidencia 04 y 05), y `costura_este` antes y después (06 y 07: antes el agua desaparecía por completo en la ventana y el lecho se cortaba; ahora el río cruza la costura entero). *Prueba:* `test_hx_view::_test_terrain_rendered` y `_terrain_has_no_cracks`; contra `main` fallan con las cifras de arriba.

**Lo que el pase 3 cambió además** (todo de `visual`): `probes()` mide la ficha con el alto **dibujado** y trae `on_screen` (B-026 y B-034); la escala por cámara se mide una vez por cámara distinta (B-047; el cuadro medio de `media` pasa de 1,525 a 1,427 ms y el p95, de 3,91 a 2,25 ms con el benchmark oficial); el monte ribereño tiene su propio generador y alterna de orilla (dejó de depender de cuánto se prolongue la traza); las dos cadenas con identificadores de `humahuaca_visual.json` están reescritas (B-051). **Lo que no se tocó:** la paleta, el aspecto del suelo y del agua (regla 4 del diseño 11), las siluetas de las fichas y el generador del templo y de los arquetipos.
