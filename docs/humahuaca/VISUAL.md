# Visual del nivel «Humahuaca»: vista real, arte procedural y estado (pista `visual`)

Documento de la pista `visual` (CONTRATO 1.2). Dice **qué hay en R1** (la vista real, el generador de arte, los shaders, los datos y las herramientas), **qué supone la vista** de las otras capas, **cómo se midió** y **qué falta**. La dirección de arte completa está en `docs/DISENO_HUMAHUACA.md` (sección 11) y la rúbrica que la mide, en `docs/QA_NIVEL2.md` (V01 a V06); este archivo no las repite. Los créditos y la procedencia del arte, en `docs/humahuaca/CREDITOS_VISUAL.md`.

**Canal de arte (A-01):** generador procedural en GDScript (`humahuaca_gen.gd`) y shaders propios. Blender no está autorizado, no hay modelos ni texturas importados y nada de lo que entrega la pista descarga o instala algo.

**Qué cambió en R1.** El stub congelado (`stub_view.gd`) sigue intacto y es la degradación (CONTRATO 7). `view/humahuaca_view.gd` es la **vista real**: el controlador de `ui_feel` la toma sola (la línea roja de la escena real ya no nombra a la vista entre las capas mínimas). Resuelve el hallazgo I-R1.0-3 (sección 9): el alba no lava de naranja, los anillos de visibilidad no se cruzan y las fichas miden ≥ 48 px **por la escena real**.

## 1. Qué entrega R1

| Archivo | Líneas | Qué es |
|---|---|---|
| `scripts/humahuaca/view/humahuaca_view.gd` | 746 | La vista (`Node3D`): las **25 funciones** de CONTRATO 3.4 más `pool_alpha` y `frame_transform`, `selected_ids`, `unit_nodes`, `unit_labels` y la señal `minimap_changed`. Arma luz, cielo y niebla; el cuadro a cuadro; el picking; las cámaras (`initial_frame`, `canonical_view`) y las sondas de QA. Orquesta a los módulos |
| `scripts/humahuaca/view/humahuaca_gfx.gd` | 794 | Paleta, materiales, mallas básicas y el **terreno continuo**: ventana, contexto y horizonte con **un solo material** |
| `scripts/humahuaca/view/humahuaca_buildings.gd` | 539 | Hitos (templo, batería, casa del cura, posta, torre), tapias, zanjas y caminos de `terrain.features(...)`, núcleo de casas y anillo de contenido (churqui, cardón, sauce, rocas) |
| `scripts/humahuaca/view/humahuaca_units.gd` | 305 | Las cinco fichas, los defensores y el botín: tamaño fijo en pantalla |
| `scripts/humahuaca/view/humahuaca_fx.gd` | 451 | Luces de la guardia, lluvia, anillos de estado y de visibilidad, efectos |
| `scripts/humahuaca/view/humahuaca_gen.gd` | 862 | El generador procedural de arte: el **templo**, los **tres arquetipos** de figura y el realista de 1817, la torre, la batería, las casas, los cañones, el caballo y la mula, la vegetación |
| `scripts/humahuaca/view/vocab_view.gd` | 28 | Vocabulario de la capa. Solo se **agregó**: `ARCHETYPES`, `BUILDERS`, `TERRAIN_PARTS` |
| `shaders/humahuaca_terrain.gdshader` | 150 | **Un solo shader de suelo** para ventana, contexto y horizonte |
| `shaders/humahuaca_props.gdshader`, `humahuaca_water.gdshader`, `humahuaca_rain.gdshader` | 48 · 35 · 42 | Edificios y figuras (color de vértice y desgaste), agua y lluvia |
| `shaders/humahuaca_noise.gdshaderinc` | 67 | **Copia** del ruido de la Justina con su procedencia declarada y funciones propias del nivel (nunca se incluye `justina_noise`: CONTRATO 1.3) |
| `data/humahuaca_visual.json` | 268 | Paleta de 24 HEX, 7 vistas, `initial_frame`, luces, lluvia, niebla, materiales, `props`, `tokens`, `units`, calidades, `fx` y `content_ring` |
| `tests/test_hx_view.gd` | 1 065 | **258 comprobaciones** sobre la vista real y el stub (sección 6) |
| `tools/vis_humahuaca.gd` y `.sh` | 1 239 | Capturas reales con ventana, métricas, banco de rendimiento, escena real (`--flow`), render héroe (`--hero`) y relieve de prueba (`--relief`) |

Ningún archivo pasa de 1 500 líneas (el mayor, 862), sin `class_name`, con tabuladores y LF. La dependencia va solo hacia abajo (`view` → `gfx`, `buildings`, `units`, `fx` → `gen`); los módulos reciben a los otros por parámetro y no hay ciclos.

## 2. Qué dibuja la vista real

**Terreno continuo.** La ventana jugable sale de `terrain.heightfield()` (226 × 164 nodos a 4 m, con una falda de 3 m); el contexto, de `terrain.context_field()` en cuatro bandas de 30 m pegadas a los cuatro bordes de la ventana, y el horizonte es un anillo de 11 filas que arranca en el perímetro del contexto, **comparte sus vértices** y sigue hasta ±8 km con cerros erosionados cerca y cordillera lejos. Un solo `ShaderMaterial` para todo: sin grietas (prueba: los bordes coinciden dentro de 0,2 m; se midió 0,0 m) y sin discos. La altura es siempre la del terreno (`height_at` o su grilla), nunca una propia. Si falta el terreno, un plano de +17 m de la misma forma.

**Shader del suelo.** Dos texturas de pesos RGBA8 (un texel por nodo, salen de `surface_at` y de la pendiente: suelo seco, sedimento, piedra, churqui, irrigada, agua, camino, zanja) y una de proximidad al río del contexto. Sobre eso: tres escalas de ruido, grava y piedritas, grietas de barro seco, estratos claros en los cerros, matas de arbusto agrupadas, surcos en las parcelas regadas, charcos chicos cerca de la cámara cuando llueve (el suelo se oscurece ×0,75) y curvas de nivel finas (`materials.terreno.contour_m`). El detalle cercano se desvanece entre 30 y 320 m y el micro-relieve de normales entre 12 y 130 m. Las manchas de grava del suelo son blandas y de poca amplitud: con bordes netos y mucha amplitud se leían como camuflaje (se corrigió en esta ronda). Con `set_albedo_mode(true)` el suelo pasa a color plano de la paleta (calibración V04).

**Edificios y generador.** Cada hito con huella tiene su nodo. El **templo** es una nave simple de adobe encalado a dos aguas, con contrafuertes, portada lateral y atrio, **sin torres ni fachada de 1880 y con caballete en 7,00 m** (318 triángulos; la prueba mira la altura de sus vértices y los nombres de los nodos). La **batería** es una losa con parapeto, tres piezas bajas y un tinglado de 1,8 m (≤ 3 m sobre el suelo, ≥ 26 m de ancho: nunca un fuste, B-023). La **posta** no tiene muros propios: sus tapias y sus dos entradas salen de `terrain.features("tapia")`. La torre provisional es de madera con plataforma, de 10 m. El núcleo de casas sigue las manzanas del diseño de nivel.

**Anillo de contenido** (0 a 400 m fuera del núcleo): churqui, cardón, sauces de ribera y rocas repartidos según pendiente y cercanía al río (con el terreno de respaldo de la prueba: ≈ 1 370 arbustos, 330 rocas y 59 sauces; cambia con el relieve real porque se reparten por pendiente y cercanía al río). Faltan las parcelas con tapias, las ruinas de la capilla de Santa Bárbara y las huellas de carreta (R2a, sección 10).

**Fichas, defensores y botín.** Cada agrupación tiene **su silueta**, armada en partes con contorno oscuro: jinete (Rodríguez), infante con fusil (Portal), infante con el banderín de mando (Arias; es un marcador de interfaz, nunca una bandera), dos figuras agachadas (reconocedores) y mula cargada (arreo). Cada ficha tiene ≥ 8 nodos hijos (partes y tres anillos: bando, borde y selección). El bando lo dan el anillo y el contorno, no el color de la ropa. Los defensores usan el arquetipo del enemigo (realista de 1817, artillero, poncho y sombrero), con tope de 48.

**Luces.** Las tres de los objetivos (brasero en la batería, ventana en la casa del cura, candil en la posta) y las fogatas de la guardia: una esfera cálida, un resplandor aditivo de ≥ 30 px y una mancha cálida en el suelo se ven **de lejos** a 470 m (son información, no decorado); en `media` y `alta` suma una `OmniLight3D` sin sombra (hasta 4 y 8).

**Lluvia, anillos y efectos.** La lluvia son rayas en el espacio de la cámara (`humahuaca_rain.gdshader`; 0, 700 y 1 400 según la calidad). Los anillos de objetivo miden 4 px y el de visibilidad es el contorno de la **unión** de los círculos (2 px, tenue, se apaga con luz plena). Efectos: fogonazo, humo, impacto, captura, pisadas, explosión y señal, con tope por calidad.

**Luz, cielo y niebla.** Salen de `environment().time_of_day` (0 = noche plena, 0,5 = alba, 1 = día) y de las tres claves de `humahuaca_visual.json: lights`; un solo `Environment` por escena, sin `shader_globals` ni ajustes de render en `project.godot`. El alba es cálido sin saturar (lino mezclado 40 % con oro) y las sombras del sol se encienden a mitad de camino entre la noche y el alba.

**Calidad.** `baja` (ventana a 8 m, sin sombras, sin luces reales ni lluvia, menos casas y vegetación), `media` y `alta` (más casas y vegetación, 8 luces reales). Una calidad desconocida se trata como `media`.

## 3. Convenciones que la vista supone

1. **Ejes:** los del CONTRATO 0 (+x este, +z sur, norte = −z). `yaw_deg` de unidades, hitos y cámaras es un **rumbo**: grados horarios desde el norte, vistos en el mapa.
2. **Huella de un hito:** `{w, d}` es un rectángulo con `w` sobre +x y `d` sobre +z antes de girar `yaw_deg`; `{r}` un círculo; `{poly}` se reduce a su caja envolvente.
3. **`environment().time_of_day`** es continuo y creciente: 0 = noche plena, 0,5 = alba (4:45), 1 = día pleno.
4. **`render_state().version`** sube con cada cambio; lo caro (figuras, luces, anillos) se reconstruye solo si cambia. Cada cuadro se recalculan escalas, efectos y selección.
5. **Tamaños en píxeles** (`tokens.*.min_px`, `quality.*.enemy_min_px`) son **píxeles reales de la pantalla**: la vista divide por la escala de la ventana. El picking, `landmark_labels` y `probes` hablan en píxeles **lógicos**. El área lógica sigue el aspecto de la ventana: **16:9 a 1280 × 720 (1 600 × 900) y 16:10 a 1024 × 640**; por eso `initial_frame` da 470 m en 16:9 y 528,7 m en 16:10 (sección 4.1).
6. **Escala de las fichas.** Una ficha parada se ve más baja cuanto más empinado se la mira. La vista la estima por el seno del ángulo del rayo (estirando solo el alto, hasta 4,6 veces) y **la corrige con una medición de verdad**: proyecta el pie y la cabeza con la cámara que se dibuja y ajusta el alto, con un 3 % de más (el pedido es un mínimo). Así miden ≥ 48 px con cualquier rumbo y en las esquinas del cuadro (en la escena real la estimación sola dejaba al jinete en 44 px). Casi desde arriba la altura no se puede sostener (de arriba no se ve la altura de una figura) y estirarla más la vuelve un trazo largo hacia el nadir: pasados los 58° el tope del estirón baja de 6,9 a 2,2 veces (a los 76°) y, entre los 60° y los 80°, el alto pedido baja a los dos tercios; la ficha queda legible por su anillo y su silueta vista desde arriba. El controlador de R1 deja inclinar la cámara hasta 80°.
7. **Orden de un cuadro.** `main` deja la cámara donde la quería el menú, el controlador llama a `update_state(delta)` con **esa** cámara y recién al final de su `_process` la ubica. Lo que depende de la cámara (escala de fichas, luces y etiquetas, ancho de los anillos) lo recalcula también el `_process` de la vista, que corre después del de su padre. Lo mejor sigue siendo que el controlador ubique la cámara antes (VP-08).
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

**Rumbo, en una línea.** Con el dato en 325° y la cámara corregida (VP-07) el jugador ve lo mismo que midió `fits`. Con el dato en 325° y el controlador **actual** (espejado) el cuadro sale al revés: mira al noreste y el arreo cae fuera de pantalla a 1280 × 720 (captura 12). El cambio de dato y el de cámara tienen que entrar **en el mismo paso de integración** (A-11).

### 4.2 Las 7 vistas y sus 5 rasgos

Escritas antes de pintar (CONTRATO 11, regla 7) a partir del anexo B del QA; cada lista es el `must_show` del JSON. Las capturas 01 a 07 de la evidencia son estas siete.

| Vista | Cámara (objetivo · distancia · inclinación · rumbo) | Luz | Rasgos |
|---|---|---|---|
| `acceso_so` | (300, 520) · 150 m · 22° · 45° | noche con lluvia | ladera, núcleo (≥ 3 edificios) y templo al fondo · templo a dos aguas sin torres · lluvia y escena legible con ≥ 2 fichas · sin monumento, escalinata, postes, tendidos ni álamos · la interfaz no tapa el núcleo |
| `desde_bateria` | (318, 350) · 60 m · 18° · 90° | alba | el pueblo por debajo, al este · río o lecho claro al fondo · parapeto y ≥ 1 pieza en primer plano · luz cálida con sombras largas · sin torres de 1880 |
| `patio_posta` | (590, 300) · 45 m · 40° · 315° | mañana | muros del patio con sus dos entradas · ≥ 3 clases de objeto · solo adobe, madera y cuero · polvorín al noreste · se ve cuánto se carga |
| `panorama_alto` | (450, 330) · 330 m · 28° · 90° | alba | ladera, núcleo, monte ribereño, lecho claro, llanura, cerros y horizonte · sin torres ni monumento · luz cálida y sombras largas · sin huecos ni borde del mundo · techos claros entre arbolado oscuro |
| `grupos_en_accion` | (418, 335) · 90 m · 45° · 0° | alba, lluvia floja | torre con plataforma · fuego o humo desde la torre · ≥ 3 fichas · líneas de fuego o impactos · bajas o estado a la vista |
| `juego_noche` | `initial_frame` · 470 m (528,7 m en 16:10) · 52° · **325°** | noche con lluvia, t = 0 | ≥ 3 puntos de luz · los tres objetivos sin leer texto · relieve y núcleo visibles · ≥ 3 fichas distinguibles · la interfaz no tapa los objetivos |
| `juego_alba` | la misma cámara | alba (≈ 4:45) | sombras largas y luz cálida · fichas en sus puestos y fogatas · los tres objetivos · el núcleo se distingue por luz y trazo · sin torres ni monumento |

### 4.3 Medidas de R1 (esta máquina)

GPU NVIDIA GeForce RTX 3080 Ti, Forward+, Godot 4.7.2, ventana de 1440 × 900, sin vsync, 180 cuadros medidos tras 30 de calentamiento, alba (`time_of_day` 0,5) con lluvia 0,42, relieve de prueba (sección 8) y las reglas del stub con defensores, torre y fogatas (`DressedRules`). Los números salen de `evidence/humahuaca/r1/visual/metrics_visual.json`. **Son informativos: los presupuestos oficiales los mide `benchmark.py` con la escena real.**

| Calidad | Construir la vista | Cuadro medio (tope) | p95 (tope 8,3) | Llamadas de dibujo | Primitivas |
|---|---|---|---|---|---|
| baja | 334 ms | **1,33 ms** (2,5) | **1,56 ms** | 163 | 146 510 |
| media | 492 ms | **1,75 ms** (4,0) | **2,18 ms** | 227 | 433 310 |
| alta | 577 ms | **1,78 ms** (6,0) | **2,13 ms** | 227 | 549 272 |

Construir con el terreno de respaldo (plano) en `media`: 344 ms; el tope es 1 500 ms y el presupuesto propuesto para la vista, ≈ 800 ms. En la prueba sin ventana la construcción por etapa fue: terreno ≈ 120 a 150 ms, núcleo y vegetación ≈ 80 a 115 ms, hitos y rasgos ≈ 10 ms y fichas y lluvia ≈ 8 ms. En una GPU más débil habrá que volver a medir.

**Con las clases reales de las otras pistas** (una copia de este código fuera del repositorio, con el terreno de `hx-relieve-r1` en 642019a y las reglas de `hx-reglas-r1` en adc08c9, leídos con `git archive`, sin tocar esas ramas ni sus carpetas; sin relieve de prueba ni `DressedRules`): `tools/vis_humahuaca.gd` da **44 comprobaciones, 0 fallas** (picking, ida y vuelta del rayo, sondas, vistas y fichas ≥ 48 px: 49,3 a 70,4 px), construir la vista tarda 488 ms en `media` y el banco da **1,51 ms (p95 2,20) en `baja`, 1,96 ms (p95 2,79) en `media` y 1,75 ms (p95 2,19) en `alta`** con 154 a 213 llamadas de dibujo. Las cinco partidas y los tres objetivos quedan a ≥ 5,8 % del borde en las cuatro resoluciones (el peor, el arreo: 5,8 % a 470 m y 6,1 % a 528,7 m). Falta la prueba con el controlador real de `ui_feel` (`hx-ui-r1`): solo se cruzaron a mano las llamadas a la vista de sus archivos (todas existen) y la fórmula de su cámara, que es la de A-11.

**Alto de las fichas** (de la base a la cima de sus piezas, píxeles reales):

| Cuadro | Arias | Arreo | Portal | Reconocedores | Rodríguez |
|---|---|---|---|---|---|
| Cuadro inicial (herramienta, 1152 × 720) | 70,4 | 57,7 | 57,4 | 49,3 | 59,4 |
| Escena real, ataque a 300 s y extracción a 321 s (controlador de hoy, 1280 × 720) | 69,7 | 57,1 | 57,4 | 49,3 | 59,5 |
| Escena real, aproximación (las que entran en el cuadro) | 67,3 | fuera | fuera | 49,3 | 61,7 |

Pedido de 58 px en una grilla de 5 × 5 posiciones del cuadro: **58,5 a 60,4 px** con la corrección (53,8 a 71,1 px con la estimación sola; `test_hx_view`).

**I-R1.0-3 en píxeles** (escena real y capturas de juego): naranja saturado **0,0 %** en `juego_alba`, ataque y extracción (tope 5 %); saturación media 0,253 en `juego_alba`, 0,318 en el ataque y 0,362 en la extracción (tope 0,42); **0,0 m** de trazo de un anillo de visibilidad dentro de otro círculo en las tres fases (tope 5 m).

**Picking:** las cinco fichas, los tres frentes y la ida y vuelta del rayo al suelo a 0,00 m en los tres hitos (tope 3 m). `meters_per_pixel` en la cámara inicial: 0,668 m/px.

### 4.4 Lo que no cumple todavía (V06, informativo en R1)

La rúbrica V06 no se exige en R1 (`QA_NIVEL2.md`, tabla de rondas). La riqueza de bordes con la grilla de 8 × 6 (gradiente > 12) sobre las capturas finales: la baldosa con menos bordes es el **27 %** de la mediana en `juego_noche` y el **25 %** en `juego_alba` (piso 40 %); es siempre la fila de abajo del cuadro, el suelo a 300 a 450 m, donde ya no hay detalle cercano. En `panorama_alto` y en `desde_bateria` es el 9 %. La correlación del perfil de luminosidad de `panorama_alto` con la foto de 1923 (24 franjas horizontales, medición de apoyo) es negativa (−0,17 y −0,77 sin la tendencia lineal): la foto tiene cielo, cerros claros, llanura oscura y techos claros, y la vista de diseño (28°) no muestra el cielo. Ninguna de las dos se va a arreglar sin tocar la cámara del diseño o sumar capas de detalle a media distancia: lista de R2a (sección 10). La cuenta oficial la hace QA con su propio script.

## 5. Render héroe y arquetipos

`tools/vis_humahuaca.sh <carpeta> 1280x720 --no-views --hero` arma un estudio (suelo y cielo lisos, sol bajo y cálido) y guarda tres imágenes y las métricas:

- **El templo** (captura 08): nave de adobe encalado a dos aguas, contrafuertes, portada lateral y atrio; ningún vértice pasa del caballete de 7,00 m.
- **Los arquetipos** (captura 09): poncho y sombrero, camisa y gorra, artillero y realista de 1817, más el jinete y la mula.
- **Escala de grises a 48 px** (captura 10): los arquetipos y las cinco siluetas de ficha rellenas, con su luminosidad L* media. El piso de la rúbrica (V03) es **ΔL\* ≥ 15 entre cada par de arquetipos**:

| Par | ΔL\* | Par | ΔL\* |
|---|---|---|---|
| poncho y camisa | 48,2 | camisa y artillero | 32,1 |
| poncho y artillero | 16,1 | camisa y realista | 16,5 |
| poncho y realista | 31,7 | artillero y realista | **15,6** (el mínimo) |

**Quién aprueba el render héroe sin personas** queda como pedido (VP-14). La propuesta de `visual`: lo miran los tres certificadores con `Read` y responden por escrito la lista de la rúbrica (V01) más estas dos cifras, el integrador lo registra en `ADDENDA.md`, y la aprobación humana del usuario queda para antes de publicar.

## 6. Pruebas

`tests/test_hx_view.gd`: **258 comprobaciones, 0 fallas, ≈ 6 s** sin ventana (en R1.0 eran 105; la compuerta pide ≥ 25). Corre dos veces la misma batería, con la vista real y con el stub (cada comprobación lleva su etiqueta `[real]` o `[stub]`), y suma las propias de la vista real:

- archivos ≤ 1 500 líneas, con tabuladores y LF y sin `class_name`; los cinco shaders existen, el del suelo incluye la copia del ruido y ningún shader incluye `justina_`; nada de `shader_globals`;
- **un solo material** de suelo, las seis partes del terreno, malla hasta ±8 km, presupuesto de triángulos, bordes sin grietas;
- batería ≤ 3 m y ≥ 26 m de ancho, sin columnas; las tapias de la posta salen del terreno y la posta no tiene muros propios; tapias con sus rasgos; las luces tienen resplandor y mancha; la lluvia es un `MultiMesh`;
- calidad: `baja` arma menos terreno que `media` y no dibuja lluvia; modo albedo;
- **A-11:** los tres datos de rumbo, el cuadro inicial con las cinco partidas a ≥ 5 % en cuatro resoluciones (528,7 m a 1024 × 640 y 470 m en las otras tres, con 6,5 % y 6,2 % de peor margen);
- ΔL\* del color de los arquetipos de a pares ≥ 8 (el render a 48 px se mide con `--hero`);
- **V03 con cualquier cámara** (8 poses y una grilla de 25 posiciones por rumbo): las fichas miden ≥ 47 px; y a 78° el estirón queda en ≤ 2,3 veces.

Se probó que las pruebas **ven** lo que cuidan: sin la corrección con la proyección la grilla mide de 53,8 a 71,1 px y falla en los dos rumbos; con el signo de la inclinación invertido (un error que se cometió y que esta prueba vio) el estirón a 78° da 6,90; sin el `_process` de la vista la ficha queda a escala 4,60 en vez de 12,87 (pase 2); con el alba de oro puro el suelo da 0,54 y 0,66 de saturación contra los topes de 0,40 y 0,46.

`tools/vis_humahuaca.gd` con ventana: 44 comprobaciones en las capturas de juego (7 vistas, albedo, minimapa y efectos), 29 a 1024 × 640, 26 por la escena real y 10 del render héroe; **0 fallas** en todas.

**Compuerta rápida** (`bash tools/qa_gate.sh quick visual`, 1 min 53 s, sobre `main` en 35ef6ff): importación, protegidos (40 intactos), compartidos, propiedad (todos los archivos cambiados son de `visual`), `rules` 818/0, `integracion` 283/0, `hx_data` 289/0, `hx_smoke` 148/0 (3 pendientes de rondas futuras), `hx_view` 258/0 y `salida_limpia` (ningún `SCRIPT ERROR`, `SHADER ERROR`, `Parse Error` ni fuga). **Falla solo `higiene`**: las etiquetas `v0.2.0-alpha` y `v0.3.0-alpha` que no son de esta rama (B-017: la decisión es del usuario).

## 7. Pedidos a las otras pistas (id, firma, motivo y prueba de aceptación)

Los VP-01 a VP-09 de R1.0 siguen escritos en la historia de este archivo; los que la vista real vuelve a tocar:

| Id | A quién | Pedido | Motivo | Prueba de aceptación |
|---|---|---|---|---|
| VP-07 | `ui_feel` (por el integrador) | La cámara del controlador usa `yaw_deg` como rumbo de la mirada: `offset = (−sin yaw · cos pitch, sin pitch, cos yaw · cos pitch) · distancia`. **Entra en el mismo paso que el dato `initial_frame.yaw_deg = 325`** (ya cambiado en esta rama, con `juego_noche` y `juego_alba`) | Con el dato nuevo y la cámara de hoy el cuadro inicial sale espejado (mira al noreste, el arreo queda fuera) | `test_hx_flow`: tras `qa_set_camera(Vector2(318, 350), 60, 18, 90)` la mirada es (1, 0) ± 0,02; con `initial_frame` a 1280 × 720 las cinco partidas quedan a ≥ 5 % del borde |
| VP-10 | integrador | Registrar en `ADDENDA.md` que (a) el dato `initial_frame.yaw_deg` ya pasó de 35° a 325° con `juego_noche` y `juego_alba` (A-11, punto 2) y (b) `initial_frame.must_include` suma las cinco partidas, con lo que **A-07 («no se ensancha») pasa a «se ensancha solo en 16:10»**: a 1024 × 640 de 470 a 528,7 m, sin cambio en 16:9. Si se prefiere A-07 a la letra, basta sacar los cinco `spawn_*` del `must_include` y ajustar `_test_five_starts` | La vista real y el stub congelado tienen que decir lo mismo, y el arreo a 1024 × 640 pasa de 3,2 % (con los 488,8 m que estimó el pase 2) a 6,6 % del borde | `ADDENDA.md` con la entrada; `test_hx_data` sin falla |
| VP-11 | compuertas y documentos | Encender **V15** (7 vistas canónicas con `must_show`) y **V22** (vistas canónicas coherentes con la cámara) de `test_hx_data` | Ya hay datos con qué verificarlas: las siete vistas traen sus cinco rasgos y `juego_noche` y `juego_alba` repiten `initial_frame` | `test_hx_data`: V15 y V22 fuera de `reglas_pendientes` y en verde |
| VP-12 | `ui_feel` | Usar `initial_frame(camera).distance` como zoom inicial y dejar el zoom máximo en ≥ 530 m | A 1024 × 640 el cuadro de las cinco partidas es de 528,7 m, no de 470 m | `test_hx_flow`: a 1024 × 640 las cinco partidas a ≥ 5 % del borde con el zoom por defecto |
| VP-13 | compuertas y documentos | Sumar `bash tools/vis_humahuaca.sh <carpeta> 1280x720 --no-views --flow=aproximacion,ataque@300,extraccion@321` a la compuerta completa (B-024) y exigir su `fallas` en 0 | Las fichas ≥ 48 px, el alba sin naranja saturado y los anillos sin cruces **solo se ven por la escena real**; la compuerta rápida no los mide | La compuerta completa lista el paso y falla si `fallas` > 0 |
| VP-14 | integrador | Decidir **quién aprueba el render héroe sin personas** (propuesta en la sección 5) | La rúbrica V01 pide que los certificadores miren las capturas; el render héroe no tiene dueño de aprobación | `ADDENDA.md`: la regla de aprobación escrita |

## 8. Cómo se corre

```sh
G="C:/Users/User/Desktop/spum/IA/Proyectos/MaravillaArgentina/guemes/patria-guemes/.tools/godot/Godot_v4.7.2-stable_win64_console.exe"
export APPDATA="$TEMP/ap_iso_visual"; rm -rf "$APPDATA"; mkdir -p "$APPDATA"
"$G" --headless --path <worktree> --script tests/test_hx_view.gd -- --ronda=r1
bash tools/vis_humahuaca.sh <carpeta> 1280x720 --relief=<carpeta del relieve de prueba> --extras --tag=visual_r1     # las 7 vistas + albedo, minimapa y efectos
bash tools/vis_humahuaca.sh <carpeta> 1280x720 --no-views --hero --tag=visual_r1                                     # el render héroe
bash tools/vis_humahuaca.sh <carpeta> 1280x720 --no-views --tag=visual_r1 --flow=aproximacion,ataque@300,extraccion@321   # la escena real con el controlador
bash tools/vis_humahuaca.sh <carpeta> 1440x900 --no-views --bench --bench-tod=0.5 --bench-rain=0.42 --quality=media      # el banco (baja, media, alta)
```

Opciones de `tools/vis_humahuaca.gd` (están en su encabezado): `--view=stub|real` (por defecto la real), `--relief=<carpeta>`, `--quality=`, `--views=a,b`, `--extras`, `--hero`, `--bench`, `--scenes=`, `--flow=`, `--cam=ui`, `--no-dress`, `--fakes`, `--hide=`.

**Relieve de prueba.** Mientras no llega la clase real de `relieve_mapa`, `--relief=<carpeta>` le da a la vista un relieve de verdad (`humahuaca_dem.json` de 91 × 66 a 10 m y `humahuaca_fondo.json` de 121 × 91 a 30 m, derivados del DEM de Copernicus GLO-30 por el explorador, **fuera del repositorio**): solo para ver el suelo con pendientes en las capturas. El juego no incluye ningún dato de Copernicus (créditos y aviso de la licencia en `CREDITOS_VISUAL.md`). Sin `--relief` el suelo es un plano de +17 m.

Evidencia de la ronda: `evidence/humahuaca/r1/visual/` (14 JPEG de ≤ 300 KB y un `metrics_visual.json`; **no entra a Git**): 01 a 07 las siete vistas canónicas, 08 a 10 el render héroe (templo, arquetipos, grises a 48 px), 11 el albedo del cuadro inicial, 12 la escena real con el controlador de hoy, 13 `juego_noche` a 1024 × 640 y 14 selección y efectos.

## 9. Hallazgo I-R1.0-3 (P0 del integrador): el alba lavaba todo de naranja y los anillos ensuciaban el mapa

**Qué decía.** En la captura de extracción el alba del stub lavaba todo de naranja saturado y los anillos de radio de las fichas se superponían y ensuciaban el mapa; a 1024 × 640 el arreo tocaba el borde del cuadro inicial. Aceptación: la compuerta rápida pasa.

**Qué se encontró al reproducirlo por la escena real** (`--flow`, 1280 × 720): (1) el sol del alba era `oro_laton` sobre un suelo ya cálido y el 62,8 % de los píxeles de la extracción (81,7 % del ataque) quedaban en «naranja saturado» (saturación ≥ 0,55, brillo ≥ 0,30, matiz de 15° a 50°); (2) `visibility_pools` trae un círculo por ficha con el radio de `environment().visibility_m` y dibujados enteros se cruzaban (2 311,5 m de trazo dentro de otro círculo); (3) las fichas medían de 11,4 a 33,1 px porque la vista calculaba su tamaño con la cámara del menú; (4) la cámara del controlador es el espejo de la de `initial_frame` (VP-07).

**Qué conserva la vista real** (a) el alba no pasa de «naranja saturado» (≤ 5 % de los píxeles) ni de saturación media 0,42 (medido: 0,0 % y 0,253 a 0,362); (b) los anillos de visibilidad son el contorno de la unión (sin cruces), de 2 px, tenues, y se apagan con luz plena (medido: 0,0 m de trazo dentro de otro círculo); (c) lo que depende de la cámara se calcula con la cámara que se dibuja, aunque el controlador llame a `update_state` antes de ubicarla (el `_process` de la vista y la corrección con la proyección de la sección 3.6); (d) las fichas miden ≥ 48 px **por la escena real** (medido: 49,3 a 69,7 px). Las pruebas de la vista real repiten las cuatro (sección 6), y `--flow` las mide sobre los píxeles de cada captura.

**Cómo se prueba.** `test_hx_view`: `_test_dawn_wash`, `_test_visibility_rings`, `_test_camera_order`, `_test_token_px_any_camera` y `_test_upright_scale_grid`. `tools/vis_humahuaca.gd` aplica los mismos umbrales sobre los píxeles de cada captura de juego.

## 10. Límites y lista para R2a

- **Integración a medias:** la vista se probó con el stub de reglas, el terreno de respaldo y el relieve de prueba, y una vez con el terreno y las reglas reales de las ramas hermanas (sección 4.3). Falta correrla dentro del controlador real y de `main.tscn` con las tres ramas fusionadas: `--flow`, `vis_humahuaca`, el banco y `benchmark.py`.
- **Rumbo:** el cuadro de la escena real sale espejado hasta que `ui_feel` aplique VP-07 (captura 12).
- **V06** no cumple (sección 4.4): detalle a 300 a 450 m, capas de media distancia y cielo en `panorama_alto`.
- **Anillo de contenido:** faltan las parcelas con tapias, las ruinas de la capilla de Santa Bárbara y las huellas de carreta.
- **Portillos y hojas de las tapias de la posta:** las entradas salen de `terrain.features`; no hay hojas de portón.
- **Sonido:** no es de esta pista en R1.
- **Render héroe:** sin aprobación (VP-14). Las figuras son de baja poligonación (≈ 230 a 550 triángulos por ficha) y sin rostro: la lectura es por silueta, no por detalle.
- **Rendimiento:** medido en una RTX 3080 Ti; falta una GPU débil y `benchmark.py` sobre la escena real.
