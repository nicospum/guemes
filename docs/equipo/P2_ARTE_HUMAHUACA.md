# P2 · Arte 3D y cámara del nivel II «Humahuaca»

Pista P2 del equipo, tanda 2. Fecha: 2026-11-08. Rama `equipo/p2-arte-humahuaca`, que sale de `equipo/integracion` (70b2341) y tiene mezclado `equipo/integracion` (72da483, los modelos de P6). Tickets: V-03, P-006, T-007 (la mitad de la vista) y T-010. Las capturas están fuera del repo, en `qa-equipo/p2/`.

## 1. Qué cambió

**Noche con contraste (objetivo 1).** Todo sale de `data/humahuaca_visual.json`, sin HEX nuevos: la paleta sigue con sus 24 ids y lo nuevo se arma con ganancias y mezclas.
- La luna es fría (celeste con un 15 % de blanco) y tiene energía 0,62, viene del ESE con 36° de elevación y proyecta sombras. Ilumina las caras que ve la cámara, que mira con rumbo 325°.
- El ambiente es azul y violáceo, con energía 0,38 (antes 1,35). El cielo nocturno tiene la franja del horizonte violácea.
- Hay una hora nueva, **madrugada** (`time_of_day` 0,3, a los ≈ 267 s): la tierra sigue oscura y los fuegos encendidos, pero el horizonte ya se pone rosado. Después llegan el alba (0,5) y el día. La vista mezcla las horas que estén en `lights`, ordenadas por su hora.
- La curva de color va por hora (`lights.<hora>.grade`): fría de noche (contraste 1,15 y saturación 0,92) y más cálida al alba. El resplandor es aditivo con umbral 1 en media y alta, y la oclusión SSAO solo se activa en alta (`look` del JSON).
- La niebla va por distancia (`fog.mode = profundidad`, de 120 a 7 000 m, curva 0,6, niebla máxima `depth_max` por hora): deja limpio el cuadro de juego y pone los cerros en capas. La `density` exponencial queda igual para el stub.
- Los **fuegos iluminan de verdad**: OmniLight sin sombra con energía 14 en media y 16 en alta, alcance de 2,4 × el radio de la luz, atenuación 1, parpadeo de ±12 % y color de fuego (oro con 22 % de rojo). La mancha y el resplandor toman el mismo color. Pesan según la hora: 1 de noche, 0,35 al alba y 0,12 de día.
- Casi la mitad de las casas tienen **lumbre en la puerta**: puntos emisivos que el resplandor abre y que se apagan con el día. Es aspecto de diseño, sin datos.
- La lluvia es más tenue (alfa 0,18, antes 0,35).

**Legibilidad (objetivo 2).**
- Las fichas propias miden 72, 68, 68, 64 y 68 px (`min_px`). Medido a 1280 × 720: **65 a 85 px** en las cinco tomas (antes 49 a 75).
- Los enemigos tienen un piso de 28 px en media y alta (antes 14) y de 24 en baja. Medido en el ataque: **37 px** (antes 18).
- Regla de color común:
  - aliado: celeste ×1,1 ≈ #8DB8D6;
  - objetivo: **oro que late** (alertado también; en alarma o asaltado pasa a rojo, y tomado, a celeste), con un filete de tinta debajo;
  - enemigo: anillo rojo ×1,2 ≈ #B8433A con borde de tinta y contorno 1,8 veces más grueso;
  - arreo: anillo hueso.
- Las fichas usan el shader nuevo `shaders/humahuaca_token.gdshader`: luz propia (22 %) y un borde de luz del color del bando. Llevan debajo un disco de tinta al 50 %, y los anillos son más finos.
- Reconocedores: un baqueano de pie con tacuara y otro agachado. Antes eran dos figuras agachadas que, al estirarlas hasta el alto pedido, se volvían una mancha ancha.
- **P-006: las cinco partidas y los tres objetivos entran en el primer cuadro** con el preset nuevo `partidas_y_objetivos` de `data/humahuaca_camera.json`: objetivos a ≥ 10 % del borde y partidas a ≥ 3 %. `test_hx_camera` lo exige a 1280 × 720, 1920 × 1080 y 2560 × 1440. El peor margen de partida es 3,0 % (el arreo).

**Escenario (objetivo 3).**
- **Paredes de la quebrada**: el anillo del horizonte sube de 500 a 900 m en unos 2,5 km al oeste y al este, con cárcavas y crestas dentadas. Hacia el norte y el sur el valle sigue y sube menos (`gfx.ring_height`). Es aspecto razonado: el relieve real de Copernicus llega solo hasta el borde del contexto y acá se lo continúa.
- Suelo: manchones de tierra húmeda y de pasto seco de decenas a cientos de metros, más variación a gran escala y laderas más oscuras. La piedra de ladera pasa a parda, porque con la luna el gris se leía como charcos azules. El brillo especular es más bajo.
- La plaza usa el mismo material del suelo (`material: suelo`), en lugar de un parche liso y claro.
- Casas procedurales (las que quedan de respaldo): adobe con cal en una de cada cuatro y techos de torta de barro pardos. Churqui más claro.
- **Modelos de P6 enchufados** (sección 4): casas del núcleo, capilla, casa de posta, corral, tapias en módulos de 4 m, piezas de artillería reales en la batería, brasero y fogón.
- **T-010**: `height_at`, `_hf_lookup`, `_ctx_at` y `Relief.bilerp` leen una coordenada NaN como 0, y `Sight.los` con un punto NaN da false. `tests/revision_nube/d_nan_altura.gd` pasa con 0 errores.
- **T-007, la mitad de la vista**: cada hueco entre dos tapias (extremos de tapias distintas a 2,5–10 m) se dibuja según lo que dice `terrain.is_blocked` en su centro. Si se puede cruzar, lleva jambas y un umbral; si no, una tranquera de tres palos. Hoy salen 2 abiertas y 7 cerradas: los dos huecos de 4 m de la posta se ven cerrados porque la navegación los da por muro. Cuando P3 los abra, la vista los mostrará abiertos sin tocar nada.

**Cámara (objetivo 4).**
- La inclinación inicial pasa a **42°** (antes 52°) en `initial_frame` y en las vistas `juego_noche` y `juego_alba`. El rumbo sigue en 325° (A-11).
- Nuevo **`zoom_tilt`**: al acercar con la rueda por debajo de 220 m, la cámara se va acostando hasta 24° a 50 m. Ahí aparecen el horizonte y los cerros (`qa-equipo/p2/despues_6_cerca/`). Al alejarse vuelve a 42°; inclinar a mano lo desactiva hasta volver a estar lejos.
- La rueda corrige hasta tres veces el punto que queda bajo el cursor: desvío 0,13 m en 5 pasos (antes 0,65 m; con la cámara baja y sin la corrección llegaba a 8,5 m).

## 2. El compromiso, dicho claro

**Con 40–44° no se ve el cielo en el cuadro inicial.** Con 46° de campo vertical, el borde de arriba mira 19° por debajo del horizonte y pega en el suelo a unos 600 m del centro, todavía dentro de la ventana. Medí hasta 32° y tampoco alcanza. El horizonte y los cerros aparecen al acercar (`zoom_tilt`), en la apertura y en las vistas bajas.

**«Más cerca» contra «las cinco partidas en el cuadro».** El contenido mide 621 m de punta a punta (del arreo a la posta). Con los objetivos a 10 % y las partidas a 3 %, la cámara queda a **455 m**, contra 321 m del preset de la nube, que dejaba cuatro partidas fuera, y 489 m de R1. El pueblo ocupa el 11,5 % del cuadro (antes 35 %). Los rumbos de 35°, 55°, 235° y 255° dan entre 661 y 814 m, y el de 340° unos 401 m (rompe A-11). Las fichas no pierden tamaño (64–85 px a cualquier zoom) y los objetivos se leen por los fuegos y el oro. Si el lead prefiere el pueblo grande, cambiar el preset por `pueblo_zona_al_borde` es una sola clave en el JSON.

## 3. Pruebas (headless, Godot 4.7.2, APPDATA aislado)

| Suite | Antes (70b2341) | Después |
|---|---|---|
| `test_hx_view` | 284 / 0 fallas | 284 / 0 |
| `test_hx_camera` | 47 / 0 | 51 / 0 (4 nuevas: P-006 a tres tamaños y el criterio de los reconocedores) |
| `test_hx_terrain` | 167 / 0 | 167 / 0 |
| `test_hx_smoke` | 158 / 0 | 158 / 0 |
| `test_hx_data` | 0 fallas | 426 / 0 |
| `revision_nube/d_nan_altura` | falla (11 SCRIPT ERROR) | pasa |

El único cambio a una prueba de mi área: `tests/test_hx_camera.gd`. Si el preset tiene las partidas como puntos duros, ahora exige que las cinco entren a ≥ 2 % (es más estricto) y el criterio «reconocedores o zona» acepta ese preset. No se debilitó ningún criterio de legibilidad.

`revision_nube/d_borde_sur` sigue fallando. Lo probé: con la fila de z = 652 transitable pasa, pero rompe en `test_hx_terrain` la comprobación de que el borde del mapa está cerrado. Lo revertí y queda como pedido a P3 (sección 6).

## 4. Integración de los modelos de P6

Están en `models` de `humahuaca_visual.json`: `dir` más el nombre de cada archivo, sin `res://`, para que la validación V12 no exija archivos ausentes, y `enabled`. Si un archivo falta, se usa el generador de siempre. Reemplazar un modelo es cambiar su nombre o su carpeta en el JSON.

`gfx.model(clave)` une las piezas del GLB en una sola malla, conserva el material de cada superficie (el ancla del color por vértice y las brasas emisivas) y la guarda en una caché estática. `gfx.model_fit` estira el modelo a la huella, y lo gira si el lado largo no coincide.

| Modelo | Dónde | Cómo |
|---|---|---|
| `hx_casa_adobe`, `hx_casa_adobe_grande` (frente ≥ 9,5 m) | 85 casas del núcleo (56 + 29) | Una MultiMesh por modelo, con un tono por casa (0,74–0,90) por color de instancia |
| `hx_capilla` | templo (`props.por_id.templo.model`) | Sin deformar (`model_fit: uniforme`) y con la huella ajustada; 7,9 m pasa TR-094 (≤ 8 m) |
| `hx_casa_adobe_grande` | casa de posta | Frente hacia el patio |
| `hx_corral` | `corral_posta` | Al alto del hito (1,2 m) |
| `hx_tapia` | tapias de `terrain.features("tapia")` | Un módulo por tramo de ≈ 4 m, en MultiMesh |
| `hx_pieza_artilleria` | batería | Una por cañonera (`gen.battery_piece_spots`), con la boca al oeste |
| `hx_brasero`, `hx_fogon` | luces de la guardia | La llama del fogón a 0,6 m |

`hx_pirca` queda listado, sin uso: no hay rasgos «pirca» en el nivel. El cuartel (casa del cura) sigue procedural, porque es la única casa encalada con aspilleras y patio, y es la que identifica al objetivo.

## 5. Rendimiento (benchmark oficial, 1440 × 900, 3 repeticiones)

| | Cuadro medio | Peor repetición | p95 | Construcción (`scene_build_ms`) |
|---|---|---|---|---|
| media antes | 1,472 ms | 1,704 | 3,454 | 1 176 ms |
| **media después** | **1,586 ms** | 1,649 | 1,771 | **1 392 ms** (otra corrida: 1 316) |
| alta antes | 1,271 ms | 1,345 | 1,699 | 1 266 ms |
| **alta después** | **1,850 ms** | 1,859 | 1,984 | 1 295 ms |

Todo entra en los topes (4,0 ms de cuadro y 1 500 ms de construcción). La construcción en media queda ajustada, y lo que más suma es el terreno (≈ 220 ms por etapa en la prueba). En alta la SSAO cuesta unos 0,5 ms.

## 6. Pedidos a otras pistas

1. **P3 (navegación), T-007 y `d_borde_sur`.**
   - `scripts/humahuaca/terrain/terrain_raster.gd::_stroke_nodes`: el redondeo de los extremos (`roundi`) cierra los huecos de 4 m de la posta. Propuesta: que el extremo de una tapia que termina en un hueco se redondee hacia adentro de la tapia (`floor`/`ceil` según el sentido). Cuando estén abiertos, la vista dibujará las jambas sola.
   - `scripts/humahuaca/rules/humahuaca_nav.gd:90` (`cell_of`): sujeta la fila a `nz − 1` (z = 652, sólida). Propuesta: sujetarla a `floori(size_m.y / cell)`, como `_node_index` del terreno.
   - El centinela de la posta (`d_centinela_posta`) es dato de reglas.
2. **QA (`tests/hx_validators.gd`, `OWNER_KEYS.visual`)**: agregar `look` y `models` como claves de la pista visual. Hoy salen como «sin dueño conocido», que no es falla.
3. **P5 (`data/humahuaca_ui.json: camera.opening`)**: bajar las paradas de la apertura a 22–28° de inclinación para que se vean el cielo y la quebrada (dirección de arte, B4). El cuadro final sale del preset y ya está a 42°.
4. **P5 (`tools/ui_qa_humahuaca.gd`)**: `_token_margins` y `_cycle_overflow` ya pueden volver a exigir las cinco partidas en el cuadro. `avoid_rects` supone 62 px por figura, y las fichas ahora miden hasta 85 px.
5. **P4/P5 (viñeta común)**: la viñeta de 0,3 de la dirección de arte (D1) le haría bien al II. No la puse en la vista porque es una capa de interfaz.
6. **P6**: el color por vértice de los GLB se ve bien con su propio material. Si algún día pasan por el material de props de la vista, hay que tener en cuenta que ese shader supone sRGB.

## 7. Evidencia (`qa-equipo/p2/`)

- **Hojas comparativas, antes a la izquierda y después a la derecha, mismo procedimiento:**
  - `cmp_1_inicio.png`: tras «Empezar»; cada versión con su cámara inicial.
  - `cmp_2_noche_ataque.png`: juego guiado hasta la señal, a 266 s.
  - `cmp_3_alba_extraccion.png`: a 321 s.
  - `cmp_4_fichas_cerca.png`: la misma cámara en las dos.
  - `cmp_5_camara_r1_ataque.png`: arte contra arte con la cámara de R1.
- **Secuencias**: `secuencia_despues/00–19.png`, 20 cuadros, uno por segundo, jugando a ×2 con el botón del siguiente paso. Hojas de contacto `secuencia_despues_hoja.png` y `secuencia_antes_hoja.png`.
- **De cerca, con la cámara acostada**: `despues_6_cerca/pano_0..2.png`.
- **Métricas** en `metricas_antes.json` y `metricas_despues.json`: alto de fichas y enemigos, objetivos en cuadro y luminancia. La luminancia media nocturna bajó de 0,34 a 0,26 en el inicio y de 0,40 a 0,15 en la madrugada del ataque.
- **Banco**: `bench_antes/`, `bench_despues/` y `bench_despues2/`.
- **Scripts**: `scripts/captura_p2.gd` (tomas y secuencia), `exp_pano.gd` (vistas libres) y `sheets.py` (hojas).

**Crítica honesta.**
- La noche ahora es noche: fuegos cálidos que iluminan, pueblo con lumbre, objetivos en oro, enemigos en rojo y la quebrada recortada al acercar.
- La madrugada del ataque es la toma más lograda, aunque quizás un poco oscura para leer las casas: subir 0,05 el ambiente de `madrugada` es un ajuste fino posible.
- El cuadro inicial ganó atmósfera y las cinco partidas, pero el pueblo es más chico que en el preset de la nube (sección 2).
- Las figuras procedurales siguen siendo toscas de cerca. Tienen el tamaño y el color que piden los criterios; el modelado de las figuras queda para otra tanda.


---

## Ronda 2 (2026-11-08)

Base: `equipo/integracion` (3a695b4, con 78fc37c y el arreglo de teclado del integrador). Las capturas de «antes» se tomaron sobre esa base, cuya vista es la de 78fc37c. Decisión del lead: el encuadre inicial amplio queda solo para orientar; en el juego, la cámara se acerca sola a la acción.

### 1. La cámara se acerca a la partida elegida

Está en `humahuaca_camera.gd` (`_watch_selection`, `_maybe_approach`, `_glide_step`) y en `data/humahuaca_camera.json: approach`.

- **Cuándo se activa.** Cuando se elige **una sola** partida nueva. Da igual cómo: tecla 1–5, clic en la ficha o clic en la tarjeta, porque todo pasa por `view.selected_ids`. Así no hubo que tocar `humahuaca_ui_play.gd`.
- **Qué hace.** La cámara se desliza en 0,9 s (suave al arrancar y al frenar) hasta **240 m**, centrada en la ficha, y se acuesta a **24,5°**. Si la ficha marcha mientras tanto, la sigue.
- **Para que no maree:**
  - solo se mueve si la ficha está a más del 22 % del centro (en % del lado menor) o si la cámara está a más de 300 m; si ya está más cerca, solo recentra sin alejarse;
  - nunca se mueve durante la apertura, mientras se arrastra el mapa o con el botón derecho apretado;
  - entre dos acercamientos pasa al menos 1 s;
  - cualquier movimiento manual lo corta: teclas, borde de la pantalla, arrastre, rueda, giro, minimapa, Inicio o centrar.
- **Segunda pulsación de la misma tecla.** En las teclas 4 y 5 activa el seguimiento, que ya existía (`center_on` → `follow_id`). En 1–3 centra en el frente, como diseñó P5; si se quiere seguimiento también ahí, hay que cambiar una línea de `humahuaca_ui_play.gd::select_group` (pedido abajo). Centrar no suma un acercamiento encima.
- **`zoom_tilt` ahora usa una curva cuadrática.** Va de 20° a 60 m hasta la inclinación de juego (42°) a 460 m, y da 24,5° a 240 m. La rueda y el acercamiento usan la misma curva.
- **Distancias finales:**
  - inicio: **470 m** en 16:9 y **520 m** en 16:10. Las partidas pasan a 5,5 % del borde, para que el chequeo de ui_qa quede igual que antes;
  - al elegir una partida: **240 m a 24,5°**, centrada a 0,0 m. Lo midió ui_qa en tres tamaños: de 470,5 m a 240 m a 1920 × 1080 y a 2560 × 1440, y de 519,8 m a 240 m a 1024 × 640;
  - mínimo: 30 m a 20°;
  - apertura: paradas a 24°, 24° y 22° (`humahuaca_ui.json: camera.opening`, a 150, 130 y 140 m).

### 2. El pueblo de noche

- La luna está a 52° de elevación y con energía 0,75 (antes 36° y 0,62): los techos de torta reciben luz.
- Casi la mitad de las casas tienen lumbre en la puerta y, si miden 6 m o más de frente, también en una ventanita.
- La capilla tiene la portada con lumbre.
- El tono por casa de los modelos de P6 sube de 0,74–0,90 a 0,86–1,0.
- La madrugada tiene ambiente y sol de 0,7 (antes 0,4 y 0,35), exposición 1,32 y medios de la curva en 0,5. Luminancia media a 240 m en la madrugada: 0,141 → **0,176**.
- Cuartel, batería y posta se distinguen por el fuego, el anillo de oro que late y su volumen. La capilla se distingue por la cal, la espadaña y la lumbre.

### 3. Figuras

No usé los GLB de figuras del proyecto. `rider_1817` tiene poncho rojo, y la regla de color reserva el rojo al enemigo. `infantry` es un casaca roja británico de 1806. `royalist_1817` lleva casaca cerrada, contra `units.realista_1817`. Además vienen con texturas, así que perderían la luz propia y el borde de bando del shader de fichas. Mejoré la geometría procedural (`humahuaca_gen.gd`):

- **Jinete:** caballo de cuerpo redondeado, con patas de caña y muslo con la rodilla marcada, y lanza **terciada** hacia adelante. Antes la lanza era un palo vertical que estiraba la figura hacia arriba.
- **Infante propio:** torso de hombros anchos.
- **Realista:** **chacó** con visera, chapa y borla, **correajes blancos cruzados** y faja de acento. El texto de `units.realista_1817.silueta` se actualizó; es diseño, porque el modelo de cada cuerpo en 1817 es sin datos.
- **Mula:** cuerpo redondeado.
- **Reconocedores:** la tacuara es más corta (2,58 m), para que las cinco siluetas sigan siendo distintas (TR-098, diferencia mínima 0,23).
- **Tamaño en pantalla, sin cambios:** 65–85 px a 1280 × 720.

### 4. Viñeta y HUD

- **Viñeta:** ya estaba en el II (`Kit.vignette`, el mismo sombreador y la misma tinta que `main.gd`); solo cambió la fuerza de juego, de 0,32 a **0,30** (`humahuaca_ui.json: layout.vignette.play`), como la de P1/P4.
- `avoid_rects` (`humahuaca_ui_base.gd`) y el rótulo de las fichas (`humahuaca_overlay.gd`) suponen **85 px**, antes 62.
- **Quebrada:** las paredes suben antes y más: 820 m en 1,9 km.

### 5. Pruebas

Todo con Godot 4.7.2 y APPDATA aislado: las suites `test_hx_*` en headless y ui_qa con ventana real.

| Suite | Resultado |
|---|---|
| `test_hx_view` | 284 / 0 fallas |
| `test_hx_camera` | 51 / 0 |
| `test_hx_terrain` | 167 / 0 |
| `test_hx_smoke` | 158 / 0 |
| `test_hx_flow` | 303 / 0 (antes de la ronda fallaban 2: el preset de partidas duras dejaba vacía la lista de incluidas; ahora las partidas duras cuentan como incluidas) |
| `test_hx_data` | 426 / 0 |
| `ui_qa_humahuaca` 1280 × 720 | 174 / 0 |
| `ui_qa_humahuaca` 1920 × 1080 | 89 / 0 |
| `ui_qa_humahuaca` 2560 × 1440 | 89 / 0 |
| `ui_qa_humahuaca` 1024 × 640 | 89 / 0 (antes 1 falla en cada uno de los tres tamaños menores: el arreo quedaba a 3 % del borde) |

Cambios en `tools/ui_qa_humahuaca.gd`:
- el recorrido completo exige las cinco partidas a ≥ 5,5 % del borde y fichas de 64 px o más;
- el chequeo de desborde mide el acercamiento: entre 220 y 260 m, a 32° o menos y a 6 m o menos de la ficha. Saca la captura `hx-acercamiento` y verifica que nada se desborde.

### 6. Rendimiento (benchmark oficial, 1440 × 900)

| Calidad | Cuadro medio | p95 | Construcción |
|---|---|---|---|
| media, 5 repeticiones | **1,70 ms** | 3,46 | media **1 245 ms**; 1 550 en la primera repetición y 1 144–1 193 en las otras cuatro |
| alta, 3 repeticiones | 1,94 ms | 2,21 | 1 317 ms |

La primera repetición de cada corrida arranca con la caché de sombreadores vacía (el APPDATA del benchmark es nuevo). Ya pasaba en la ronda 1 (1 481 y 1 776 ms) y viene de los sombreadores y variantes nuevas.

Medido por partes en un proceso caliente:
- construcción completa: 1 103 ms la primera vez y 315 ms la segunda;
- la vista: 533 ms (terreno 146, hitos 69, núcleo y vegetación 122);
- cargar y unir los nueve GLB: unos 17 ms en total.

Hubo otros agentes con Godot en paralelo, que meten ruido en las cifras. En el estado estable queda bajo los 1 500 ms. **Una primera partida en una instalación nueva puede pasarse ≈ 50–270 ms del tope**, por la compilación de sombreadores. Si hace falta, el arreglo es precalentar los materiales en el menú (P4).

### 7. Evidencia (`qa-equipo/p2/r2/`)

- **Hojas antes/después:**
  - `cmp_1_inicio.png`: inicio, encuadre amplio;
  - `cmp_2_noche_ataque.png`: madrugada en el ataque;
  - `cmp_3_alba_extraccion.png`: alba con la extracción;
  - `cmp_6_pueblo_240m.png`: el pueblo de noche a 240 m;
  - `cmp_8_pueblo_madrugada_240m.png`: el pueblo en la madrugada a 240 m;
  - `cmp_7_partidas_240m.png`: las figuras a 240 m;
  - `cmp_4_fichas_cerca.png`: primer plano de fichas.
- **Secuencia de 20 cuadros jugando a ×2:** `secuencia_sel_despues/00–19.png`, con hoja `secuencia_sel_despues_hoja.png` y la de antes. Se eligen partidas con las teclas 1 (1 s), 4 (5 s), 4 otra vez para seguirla (9 s), 3 (13 s) y 5 (17 s). La cámara de cada cuadro está en `metricas_despues.json: secuencia_sel_camara`.
- **Banco:** `bench_despues/` y `bench_despues2/`.
- **Scripts:** `qa-equipo/p2/scripts/captura_p2.gd` (`--seqsel` y las tomas «cerca»), `sheets2.py` y `prof.gd`.

### 8. Crítica honesta

- **Lo más logrado es el acercamiento al elegir.** De orientarse a 470 m se pasa a 240 m acostado, con profundidad, el pueblo con lumbre al fondo y las fichas grandes.
- **La madrugada ya se lee.** Antes era casi negra; ahora es violácea y cálida.
- **El pueblo de noche a 240 m mejoró, pero sin salto.** Hay más lumbre y techos más claros, pero los techos de torta de P6 siguen grises verdosos con la luna.
- **Las figuras mejoraron en silueta, pero siguen siendo low-poly.** A 240 m la diferencia es chica. Un salto de verdad pide figuras modeladas (P6) con la paleta y el borde de bando.
- **Acercarse a Rodríguez, en el borde oeste, muestra llano vacío.** La quebrada aparece cuando la partida está cerca del pueblo o del río.

### 9. Pedidos

1. **Si se quiere seguimiento con la segunda pulsación de 1–3** (hoy centra en el frente, diseño de P5): en `scripts/humahuaca/ui/humahuaca_ui_play.gd::select_group` cambiar `center_on_front(...)` por `center_on_unit(id)` cuando `index < 3`, y dejar el frente para el clic en su panel. Afecta a `test_hx_camera` (centrar) y a CONTROLES.md.
2. **P4:** precalentar en el menú los materiales del II (token, terreno, agua, lumbre y GLB de P6), para que la primera construcción en frío no pase de 1 500 ms.
3. **P6:** techos de torta un poco más cálidos o claros en el color por vértice. Con la luna fría se leen gris verdoso. Y, si hay tiempo, figuras propias (jinete con poncho pardo, infante, realista con chacó, baqueano, mula) con color por vértice, para reemplazar las procedurales por ruta como las casas.
4. **QA:** `look` y `models` en `OWNER_KEYS.visual` (de la ronda 1, sigue pendiente).

### 10. Después de mezclar P3 (`equipo/integracion` 35de1ea)

- **`test_hx_flow`: 303 / 0 fallas.** Las 2 fallas del encuadre inicial a 1280 × 720 y 1024 × 640 (`soft_in` vacío) las arregla esta rama: cuando el preset exige las partidas como puntos duros, cuentan como incluidas (`tests/test_hx_flow.gd`).
- **Puertas de la posta (T-007 completo).** Con la rasterización nueva de P3, la vista dibuja **4 huecos abiertos**, con jambas y umbral, y 5 cerrados, con tranquera. Antes eran 2 y 7.
- **Revisión nube.** Pasan `revision_nube/d_puertas_posta`, `d_borde_sur` (el lado de la navegación lo arregló P3) y `d_nan_altura`.
- **Aviso de detección, pedido de P3.**
  - Nuevo `shaders/humahuaca_alert_ring.gdshader`. Con `render_state().units[].spotted_s` > 0, la vista dibuja alrededor de la ficha descubierta un **aro ámbar** (oro con 38 % de rojo) con filete de tinta. El aro se vacía en sentido horario mientras corre la cuenta: el máximo visto en el aviso es el total, y las reglas usan 5 s. El tramo vencido queda tenue y el aro late a 9 rad/s.
  - Va al lado de la ficha, no dentro: no cambia su silueta ni sus medidas (TR-098). Usa un material por ficha y queda levantado del suelo para que el relieve no lo tape; la figura queda delante.
  - Capturas en `qa-equipo/p2/r2/aviso_deteccion/aviso_0.0.png`, `aviso_1.8.png` y `aviso_3.6.png`: 100 %, 64 % y 28 % de la cuenta, con la cámara a 240 m. Las armó `qa-equipo/p2/scripts/exp_alert.gd`, que marca a los reconocedores como vistos.
- **Pruebas tras la mezcla:**

| Suite | Resultado |
|---|---|
| `test_hx_view` | 284 / 0 |
| `test_hx_camera` | 51 / 0 |
| `test_hx_terrain` | 167 / 0 |
| `test_hx_smoke` | 158 / 0 |
| `test_hx_flow` | 303 / 0 |
| `test_hx_data` | 426 / 0 |
| `ui_qa_humahuaca` | 174 / 89 / 89 / 89 checks, 0 fallas a 1280 × 720, 1920 × 1080, 2560 × 1440 y 1024 × 640 |

  En ninguna corrida apareció un SCRIPT ERROR.
- **Las hojas de `qa-equipo/p2/r2/` son de antes de mezclar P3.** La vista no cambió con esa mezcla salvo las puertas y el aviso.


---

## Ronda 3 (2026-11-08): color de la quebrada, vegetación legible y bruma

Base: `equipo/integracion` 63b336a. Las capturas de «antes» se tomaron sobre esa base. Todas las tomas son a 1280 × 720 y están en `qa-equipo/p2/r3/`.

### 1. Color

- **Suelo con calidez por hora.** Uniforme nuevo `warmth` en `humahuaca_terrain.gdshader`, que pone `gfx.set_warmth` desde `lights.<hora>.ground_warmth`: 1 de noche, 0,9 en la madrugada, 0,35 al alba y 0,1 de día. Con calidez llena, el suelo seco ×(1,07; 0,95; 0,80), el sedimento ×(1,06; 0,95; 0,84) y la piedra ×(1,08; 0,94; 0,80).
  - La ladera lleva menos verde de churqui y el regadío ya no queda verde loro de noche.
  - De día la luz ya da el ocre, así que no se suma: el alba no se lava de naranja.
  - El render de albedo no cambia, porque la calidez va a 0 en ese modo.
- **Curva de noche partida:** sombras frías [0,025; 0,03; 0,10], medios cálidos [0,5; 0,47; 0,45] y luces ámbar [1,0; 0,9; 0,74], con saturación 1,0. La luna sigue fría (celeste); la tierra y los adobes conservan el ocre.
- **Techos de torta y adobe más cálidos.** `tools/hx_models_sin_blender.py` tiene una tabla nueva `WARMTH` por prefijo de material:

  | Material | Factor lineal |
  |---|---|
  | Techo \| torta | (1,10; 0,84; 0,62) |
  | Adobe | (1,07; 0,92; 0,76) |
  | Tapial | (1,06; 0,90; 0,74) |
  | Ramada \| cañizo | (1,04; 0,92; 0,74) |

  Regeneré los nueve modelos. Solo cambian los cuatro que tienen esos materiales (`hx_casa_adobe`, `hx_casa_adobe_grande`, `hx_capilla` y `hx_tapia`) y el manifiesto. La geometría y los nombres son los mismos.
- **Ámbar contra azul:** el fuego tiene 34 % de rojo (antes 22 %) y la lumbre de puertas y ventanas, 36 %.
- **Color medio del mundo** (sin cabecera ni dock; `r3/color_medio.json`):

  | Toma | Antes (RGB) | Después (RGB) |
  |---|---|---|
  | Pueblo de noche a 240 m | 80, 88, 87 (gris verdoso) | 90, 87, 71 (ocre) |
  | Inicio | 80, 89, 89 | 91, 89, 79 |
  | Madrugada a 240 m | 55, 47, 52 | 59, 48, 50 |
  | Alba | 143, 118, 79 | 148, 120, 81 |

### 2. Vegetación

- **Matas:** 1 000 candidatas, antes 3 000. Son más chicas (0,9–1,8, antes 1,3–2,6) y de tonos de churqui seco y paja.
- **Rocas:** la mitad y pardas.
- **Nada a menos de 60 m de los objetivos.**
- **Cardones:** son `tree_cardon.glb` en MultiMesh, solo en laderas y a más de 45 m de los objetivos. Si falta el archivo, el procedural.
- **Algarrobos nuevos:** `tree_algarrobo.glb` en MultiMesh, dispersos en el llano, lejos de objetivos (75 m), caminos y río.
- Los dos GLB del proyecto se nombran en `models` (`cardon` y `algarrobo`); cambiarlos es cambiar esa ruta.

### 3. Profundidad

- La niebla por distancia empieza antes y es más clara: de 60 a 3 000 m (antes 120 a 7 000), curva 0,7 y niebla máxima 0,8 de noche. El color es azul elegido ×1,45, más claro que el suelo.
- A 240 m acostado, el tercio de arriba ya es una banda de bruma azulada con la silueta de la pared de la quebrada, más clara que el primer plano. Se ve en la secuencia de acercamiento, por ejemplo `r3/secuencia_acercamiento/14.png`.

### 4. Pruebas y rendimiento

| Suite | Resultado |
|---|---|
| `test_hx_view` | 284 / 0 fallas |
| `test_hx_camera` | 51 / 0 |
| `test_hx_terrain` | 167 / 0 |
| `test_hx_smoke` | 158 / 0 |
| `test_hx_flow` | 303 / 0 |
| `test_hx_data` | 426 / 0 |
| `ui_qa_humahuaca` 1280 × 720 / 1920 × 1080 / 2560 × 1440 / 1024 × 640 | 174 / 89 / 89 / 89, 0 fallas |

No hubo SCRIPT ERROR. Las fichas siguen midiendo 65–85 px y el aro de detección no cambió.

Benchmark oficial, 1440 × 900, 4 repeticiones:

| Calidad | Cuadro medio | p95 | Construcción |
|---|---|---|---|
| media | 2,05 ms (antes 1,70) | 5,5 (tope 8,3) | 1 175–1 233 ms en caliente; 1 465 en la primera repetición, con la caché de sombreadores vacía |
| alta | 2,25 ms | 3,5 | 1 186–1 228 ms |

El cuadro sube por los cardones y algarrobos del proyecto, que tienen muchos triángulos y proyectan sombra. Sigue con mucho margen bajo el tope de 4 ms.

### 5. Evidencia (`qa-equipo/p2/r3/`)

- **Hojas antes/después:**
  - `cmp_1_inicio.png`: inicio;
  - `cmp_6_pueblo_240m.png`: el pueblo de noche a 240 m;
  - `cmp_8_pueblo_madrugada_240m.png`: el pueblo en la madrugada;
  - `cmp_7_partidas_240m.png`: las partidas a 240 m;
  - `cmp_2_noche_ataque.png`: el ataque;
  - `cmp_3_alba_extraccion.png`: el alba.
- **Contra las referencias del usuario:** `cmp_referencias.png`, con los mockups 06 y 02 arriba y el pueblo de noche y de madrugada abajo.
- **Color medio:** `color_medio.json`.
- **Banco:** `bench_despues/`.

### 6. Cuánto se acerca a los mockups (honesto)

**Se acerca en paleta y en jerarquía:**
- tierra ocre y parda en lugar de gris verdoso;
- puntos cálidos de lumbre y fuego contra una noche azul;
- objetivos en oro;
- fondo con bruma que separa los planos;
- menos ruido de manchas.

**No se acerca en dramatismo del relieve.** Los mockups son vistas aéreas de cordillera con crestas iluminadas, sombras profundas y mucho contraste de valores. Nuestro valle de juego es casi llano: Copernicus da ±20 m en la ventana. Las paredes de la quebrada solo se leen de reojo en la banda de bruma, y a 240 m el cuadro sigue siendo sobre todo llano ocre con casas.

**Mi estimación:** en color, atmósfera y legibilidad, un 60 %. En «épico» de composición, un 35–40 %. Para llegar falta:
1. un relieve cercano con más carácter dentro del contexto (las laderas oeste y este, a 1–2 km);
2. luz rasante de luna o alba que dibuje crestas;
3. figuras modeladas;
4. una cámara de presentación (apertura o partes) que muestre la quebrada entera con el pueblo pequeño abajo, como el mockup 06.

**Pedido (P5/lead):** la apertura podría arrancar desde una vista de 1–2 km sobre la quebrada a 20°. La cámara y la luz ya lo permiten.

## Corrección QA ronda 2 (2026-11-09)

Rama `equipo/fix-qa-nivel2`, que sale de `equipo/integracion` (dee5755). Responde al dictamen `qa-equipo/qa_ronda2/nivel2/DICTAMEN_NIVEL2.md` (RECHAZA por Q-201). La evidencia está fuera del repo, en `qa-equipo/fix_nivel2/` (logs, capturas, ui_qa, balance y perfiles). Todas las corridas usan `APPDATA` aislado (`%TEMP%/ap_iso_fx2_*`). Las capturas de «antes» salen de una copia exportada de dee5755 (`git archive`, sin `evidence/` ni `docs/`) en `%TEMP%/ap_iso_fx2_base`, con la misma herramienta (`tools/hx_fix_shots.gd`), la misma semilla y los mismos encuadres. Sello: **presentable, no certificado por humanos**.

| Ticket | Causa | Arreglo | Prueba | Resultado |
|---|---|---|---|---|
| **Q-201** ALTO | `humahuaca_camera.gd::_watch_selection` miraba `view.selected_ids` en cada cuadro y se deslizaba con **cualquier** cambio de selección. La guía («Siguiente paso»), los botones de orden y los avisos eligen al actor antes de dar la orden, así que cada orden de la guía movía la cámara. | La cámara ya no mira la selección. El controlador llama a `request_approach` solo en la primera elección **explícita** (tecla 1–5, clic en la ficha, clic en la tarjeta). La cámara se mueve solo si la ficha no está a la vista con 10 % de margen (fuera de la cabecera y del dock), como mucho cada 7 s y sin volver a la partida anterior antes de 12 s. Nunca aleja. La segunda pulsación (o el clic en la ficha ya elegida) va a la ficha o a su frente y se acerca a 240 m (`focus_on`): el acercamiento a voluntad sigue. Tab, el recuadro, la guía y los avisos no la mueven. Datos: `humahuaca_camera.json: approach`. | `pt2.gd --plan=cam` (el del revisor, sin cambios); plan nuevo `camsel` (la guía más una tecla 1–5 cada 9 s); `test_hx_camera` con tres casos nuevos: la orden por la guía no mueve la cámara, una ficha a la vista no la mueve, una fuera de cuadro da un solo deslizamiento. | **cam: 0 deslizamientos en 347 s (antes 32), victoria, en las dos corridas** (`logs/pt_cam_{despues,final}_1280x720.log`). camsel: 38 elecciones explícitas → 9 deslizamientos (8 en la corrida anterior al ajuste del margen a 4 %), todos tras una elección; **0 sin elección y 0 alternancias A↔B↔A en menos de 10 s**. test_hx_camera 56/0 (37 pasos de la guía con las 5 partidas elegidas por ella: 0 movimientos). |
| Q-202 MEDIO | `humahuaca_progress.checkpoint_tick` escribía «posiciones» también «a los 210 s sin señal», aunque nadie hubiera llegado. `retry()` restauraba con `paused = false` y la velocidad anterior (×4). | El control solo se escribe con las **tres** partidas de combate en su puesto y al menos 30 s antes de que el alba las descubra (la victoria exige los tres frentes). Restaurar deja el juego **en pausa y a ×1**, con un aviso de pie. | `test_hx_flow`: prueba nueva «reintento_pasivo» (derrota sin órdenes) y dos comprobaciones nuevas en «reintento». | Tras perder sin órdenes no se guarda ni se ofrece. Al volver: pausa, ×1 y 3/3 partidas en su puesto. |
| Q-203 MEDIO | Cada lote destruido terminaba la orden (`_work_unit` → «idle»), así que la guía pedía «Destruir» una vez por lote y por partida. | `_continue_destroy` (en `humahuaca_rules_field.gd`): al terminar un lote, la partida pasa al siguiente a su alcance; si no queda, camina al de más golpe por segundo a menos de 160 m (el alcance de la guía) y lo destruye al llegar. Mientras el arreo no se fue, no toca lo que el arreo todavía puede llevar ni lo que otra partida ya destruye. El arreo sigue solo si la guía le pediría destruir otra vez. No agrega campos al estado (`validate_snapshot` pasa). `transport.destroy_chain = false` vuelve a lo de antes. Los textos de la guía y de la ayuda dicen que la orden sigue sola. | `tools/hx_balance_destroy.gd` (semillas 2001–2020, cadena apagada contra prendida) y `tests/hx_rules_qa2.gd::_test_destroy_chain`. | Obediente: 20/20 victorias en los dos modos; destruir **36,8 → 5,5 órdenes (máx. 6)**; órdenes totales 61,5 → 27,2; golpe 62,86 → 62,86; 20 bronces. Experto: 20/20; destruir 14,8 → 9,3; golpe 69,24 → 69,40; 12 oros y 8 bronces en los dos. Pasivo: 0/20 en los dos. |
| Q-204 MEDIO | Las parcelas (`parcela`, diseño) solo existían como el canal «regadío» del sombreador del suelo: un plano verde liso, la mancha más oscura de noche. En el minimapa tenían el mismo color oscuro y la forma cuadrada de los marcadores de objetivo. | `humahuaca_buildings.gd::build_parcels`: una malla por parcela con:<br>• tierra removida de fondo;<br>• camellones en hileras, en tres tablones (maíz, alfalfa y rastrojo con claros), con tono propio por tramo;<br>• la acequia (agua entre bordos) por la cabecera y un costado;<br>• un bordo alrededor que tapa el borde irregular del sombreador.<br>Minimapa: sembrados verdes translúcidos con rayas y la acequia punteada; los frentes pasan a **rombos con borde de oro**. La ayuda (F1) dice que los sembrados frenan la marcha. | Pares antes/después con `tools/hx_fix_shots.gd` (mismos encuadres y semilla) a los 2, 330 y 450 s, más el minimapa. | `capturas/fijas_{antes,despues}_1280x720/`: `t002_parcela_oeste.png`, `t002_parcela_este.png`, `t450_general.png` y `t002_minimapa.png`. |
| Q-205 MEDIO | La construcción al entrar desde el menú hacía todo en un solo cuadro:<br>• ≈ 700 ms de compilar GDScript la primera vez: reglas 155, terreno 73, vista 203 y la interfaz 264 (esta la carga `main.gd`);<br>• 450–620 ms de armar la vista. | La vista 3D se arma **detrás del briefing**, que tapa el cuadro: después de que el briefing se dibujó (`ensure_view`, que también corre al apretar «Empezar» si el jugador fue más rápido). Su script se compila **en un hilo** (`ResourceLoader.load_threaded_request`) mientras se lee. Con la apertura salteada, una partida recuperada o la QA, la vista se arma como antes. `start()` anota sus pasos en `start_stages_ms`. | `tools/hx_build_profile.gd`: 6 entradas desde el menú, cada una en un proceso nuevo, con ventana 1280×720, antes (dee5755) y después, en la misma tanda (con otros Godot abiertos en la PC). | `scene_build_ms`: **antes 1 341–1 640 ms** (5 de 6; la sexta colgó y se cortó a los 150 s); **después 605–752 ms**. La vista diferida tarda 523–596 ms, con el briefing en pantalla. |
| Q-206 MEDIO | A 1280×720:<br>• la cabecera era una franja de punta a punta;<br>• la barra de órdenes ocupaba todo el ancho de la columna;<br>• el dock medía 920 px;<br>• la tarjeta de aviso ponía el botón debajo del texto. | • La cabecera mide lo que su contenido.<br>• La barra de órdenes mide lo que sus botones.<br>• `dock_max_w` 920 → 760.<br>• Minimapa 260×188 → 216×156.<br>• Frentes 212 → 198 px.<br>• La tarjeta de aviso, si mide 480 px o más, lleva el botón a la derecha del texto (600 px de ancho como máximo).<br>• El aviso de pie mide su frase en una línea.<br>No se quitó ningún texto ni botón. | `ui_qa_humahuaca` a 1280×720 (recorrido completo). | **Tapa 29,9 → 23,9 % al inicio y 45,2 → 33,9 % en el ataque con aviso**, con 174/0. |
| Q-207 BAJO | El parte de «descubiertos» usaba el **último** frente de `alarm.pre_signal`. Con la guardia atenta la voz corre y el último suele ser la posta. | Usa el primer frente. Si esa alarma salió de ver a los reconocedores (aviso o detección en el diario de la partida), el consejo es `consejo_reconocedores` («…retiralos enseguida con «Retirarlos»…»). | `tests/hx_rules_qa2.gd::_test_discovered_blame`. | Semilla 13: «A los 1:19 la guardia de la batería dio la alarma…»; la primera en alarma fue la batería; el consejo habla del aviso. |
| Q-208 BAJO | Sin órdenes y en los primeros 20 s, Esc salía al menú; como Esc también salta la apertura, dos Esc sacaban del nivel. El intento se contaba al entrar. | En el recorrido del jugador (con briefing), Esc siempre abre la pausa. La salida rápida queda solo con la bandera de pruebas `skip_intro` (PoC-11). El intento de una entrada desde el menú se prepara al entrar (el diario llega a las reglas) pero se cuenta con la primera orden o al terminar la partida (`begin_attempt(rules, false)` y `commit_attempt()`). | `pt2.gd --plan=s4`, con el intento anotado en el log. | Esc ×3 tras Espacio en el briefing: pausa, sin pausa, pausa (el nivel sigue vivo). Esc tras saltar la apertura: pausa. Intento 1 en las tres entradas y 0 intentos guardados sin órdenes. |
| Q-209 BAJO | `_draw_scale` dibujaba en el minimapa los metros por píxel de la cámara 3D. | La escala sale de `world_to_map` (el mapa entero en el recuadro): un tramo redondo de 90 px o menos. | `hx_fix_shots` anota `scale_bar()`. | «200 m» sobre 48 px a 4,17 m/px: la barra mide lo que dice. |
| Q-210 BAJO | • La mañana (alba y día) tenía sol y exposición altos y poco contraste.<br>• El minimapa siempre pasaba el relieve a tinta nocturna.<br>• El rótulo del frente iba siempre debajo del hito, sobre las fichas paradas ahí. | • Alba: sol 1,7 → 1,35, ambiente 0,55 → 0,46, exposición 0,95 → 0,84, contraste 1,14 → 1,22.<br>• Día: sol 1,4 → 1,15, ambiente 0,6 → 0,48, exposición 1 → 0,86, contraste 1,06 → 1,18, saturación 0,92.<br>• La tinta del minimapa sigue la hora: entera de noche y 25 % de día.<br>• El rótulo prueba cinco lugares y usa el primero que no pisa una ficha, su número ni otro rótulo. | Pares antes/después a los 330 y 450 s. | `capturas/fijas_{antes,despues}_1280x720/t330_*.png` y `t450_*.png`. |

**Lo que queda abierto u honesto:**
- **Q-205.** La construcción que mide `main.gd` bajó sobre todo porque la vista ya no se arma en ese cuadro. El trabajo sigue existiendo: es un tirón de ≈ 0,5–0,6 s mientras el jugador lee el briefing. La compilación de la interfaz (≈ 260 ms) la carga `main.gd`, fuera de esta pista; se podría precalentar desde el menú, junto con los sombreadores (pedido a P4). No corrí `benchmark.py`.
- **Q-206.** El 33,9 % del ataque se midió en el momento de `ui_qa` (aviso de la torre, aviso de pie y barra). Con dos avisos largos a la vez puede pasar el 35 %.
- **Q-210.** La mañana tiene más contraste, pero el llano sigue siendo ocre claro: es el color de la tierra de la paleta. Q-204 y Q-210 piden una revisión visual de QA.

**Pruebas obligatorias (headless salvo ui_qa y el agente; 0 SCRIPT ERROR y 0 SHADER ERROR en todos los logs; `qa-equipo/fix_nivel2/logs/tests_r3/resumen.txt`):**

| Suite | Comprobaciones / fallas |
|---|---|
| test_hx_data | 426 / 0 |
| test_hx_smoke | 158 / 0 |
| test_hx_terrain | 167 / 0 |
| test_hx_view | 284 / 0 |
| test_hx_flow | 308 / 0 (antes 303; «reintento_pasivo» nueva y dos comprobaciones en «reintento») |
| test_hx_camera | 56 / 0 (antes 51) |
| test_hx_rules | 701 / 0 (antes 693; las de Q-203 y Q-207 viven en `tests/hx_rules_qa2.gd`) |
| revision_nube | 32 / 32 (`f_hermeticidad_qa` ajustada a Q-202) |
| ui_qa_humahuaca 1280×720 (completo) | 174 / 0: tapa 23,9 % al inicio y 33,9 % en el ataque |
| ui_qa_humahuaca 1920×1080 | 90 / 0 (15,2 % y 21,6 %). Una corrida anterior marcó un globo de ayuda encima de la cabecera; al repetirla, 90/0. Es intermitente y depende de cuánto tiempo queda quieto el mouse |
| ui_qa_humahuaca 2560×1440 | 90 / 0 (15,2 % y 21,6 %) |
| ui_qa_humahuaca 1024×640 | 90 / 0 (32,4 % y 48,7 %: la meta de Q-206 es para 1280×720) |
| hx_agent_play --selftest (semilla 11) | **victoria** a los 688,8 s de juego, 81 turnos, primera orden en el turno 4 |
