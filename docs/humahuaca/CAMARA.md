# Cámara del nivel «Humahuaca»: el encuadre inicial, medido

Dueña: `ui_feel`. Rama `hx-camara-nube` (2 de noviembre de 2026), a partir de `humahuaca-r1` (`333a657`). Pedido del usuario, prioridad uno de R2a: miró las capturas y dijo que **la cámara está demasiado lejos: se ve todo muy chico (fichas, edificios, el pueblo)**.

Este documento junta lo que se midió **sin pantalla ni GPU**: `tests/test_hx_camera.gd` arranca la escena real sin ventana, fija el tamaño de la ventana a 1024 × 640, 1280 × 720, 1920 × 1080 y 2560 × 1440 y proyecta con `Camera3D.unproject_position` (no hace falta dibujar). Todas las cifras en píxeles son **píxeles reales de la ventana**; el margen al borde es el menor de los cuatro bordes, en % del lado. Nadie pudo mirar el resultado con una ventana real: la sección 7 dice qué tiene que mirar quien sí pueda.

Archivos: `scripts/humahuaca/ui/humahuaca_camera.gd` (la política), `data/humahuaca_camera.json` (los parámetros), `tests/test_hx_camera.gd` (la medida) y, fuera de los tres pedidos, un cambio en `scripts/humahuaca/ui/humahuaca_ui_base.gd` (sección 8).

## 1. Qué decidía el encuadre antes (y por qué no alcanzaba con tocar la cámara)

El cuadro inicial salía de una cadena de tres piezas, ninguna en `humahuaca_camera.gd`:

1. `data/humahuaca_visual.json: initial_frame` (pista visual): objetivo (350, 470), **470 m**, 52°, rumbo 325°, y una lista `must_include` de nueve puntos (los tres objetivos, la zona de partida y las cinco partidas) con 5 % de margen. `humahuaca_view.initial_frame()` ensancha de a 4 % hasta que entran: 470 m en 16:9, 528,7 m en 16:10.
2. `humahuaca_ui_base.initial_pose()` (controlador) tomaba esa sugerencia y volvía a ensanchar de a 4 % hasta que **las cinco partidas y los tres objetivos** quedaran a 6 % del costado y dentro de la banda libre entre la cabecera y el dock (`humahuaca_ui.json: camera.initial_fit`, B-015 y B-021). Resultado: **488,8 m** en 16:9 y **549,8 m** a 1024 × 640.
3. `humahuaca_camera.gd` solo guardaba el cuadro, lo aplicaba y recortaba el zoom entre 40 y 900 m.

La geometría es la que manda: con el rumbo 325° el eje largo del contenido (del arreo, en (60, 625), a la posta, en (590, 300)) mide **621 m** y cae casi exactamente sobre el eje horizontal de la pantalla. Con 46° de campo vertical (74° horizontal en 16:9) el cuadro abarca 1,51 × la distancia de ancho: para que entren esos dos extremos con 6 % de margen hacen falta ≈ 467 m. Ningún parámetro de la cámara (campo, inclinación, rumbo) cambia eso: si los mismos puntos tienen que entrar con los mismos márgenes, el tamaño de lo que se ve queda fijo. **Acercar la cámara exige dejar algo fuera del cuadro inicial.**

Las **fichas** no dependen de la cámara: son de tamaño fijo en píxeles (`humahuaca_visual.json: tokens.*.min_px`, 48 a 58 px; `humahuaca_units.upright_scale` las estira hasta ese alto a cualquier zoom). Por eso miden 49 a 59 px antes y después de acercar la cámara, y por eso el objetivo del pedido («una ficha ≥ 64 px a 1280 × 720») **no se puede cumplir desde la cámara**: hay que subir `min_px` en el JSON de la pista visual (sección 6).

## 2. Qué hace la cámara ahora

`humahuaca_camera.gd` decide el encuadre inicial (`fit_initial`), con los parámetros de `data/humahuaca_camera.json`:

- Un **preset** dice qué puntos tienen que entrar y con qué margen al borde (en % del lado): los **duros** siempre; los **blandos** (las cinco partidas), solo si eso no aleja la cámara más allá de `soft.max_distance_m`; si no entran todos, entran los que se pueda sin sacar a los duros de su lugar.
- La distancia se busca por **bisección** entre el zoom mínimo y el máximo: la más corta en la que todos los duros entran con su margen y dentro de la banda libre entre la cabecera y el dock (con la holgura de 78 px arriba, para la ficha y su rótulo, y 46 px abajo). El objetivo se corre por el suelo hasta que el conjunto queda **centrado por holguras** (la misma holgura sobrante a cada lado, contado el margen de cada punto).
- Una última pasada evita que una partida quede **a medio tapar** por la cabecera o el dock: si la holgura de los duros lo permite, se la mete en la banda o se la saca del cuadro.
- Cada medida se hace con la cámara real (`unproject_position`), así que sirve sin ventana; `cam.last_fit` deja escrito qué preset se usó, a qué distancia, qué partidas entraron y cuáles quedaron fuera.
- La sección `camera` del JSON **pisa** la sección `camera` de `humahuaca_ui.json` en el mismo diccionario que recibe `setup()` (así `zoom_step`, `edge_speed` y los límites tienen un solo lugar). Hoy solo cambia `min_distance_m`: **30 m** (antes 40).
- **Seguimiento**: al centrar la cámara en una ficha (teclas 4 y 5 dos veces) la cámara la sigue mientras marcha; mover la cámara a mano (teclas, borde de la pantalla, arrastre, minimapa, Inicio) la suelta; la rueda acerca y aleja sin soltarla. Antes el centrado era un salto único y la ficha se iba del cuadro.

El controlador (`initial_pose()` en `humahuaca_ui_base.gd`) pasa a la cámara la sugerencia de la vista (`initial_frame`, que sigue dando `fits` para V02) y lo que tapan la cabecera y el dock, y usa el cuadro que la cámara devuelve. La vista, el `initial_frame` de la pista visual y las siete vistas canónicas no se tocaron.

## 3. Los presets, medidos

Lo que da cada preset de `data/humahuaca_camera.json` a 1280 × 720 (16:9; a 1920 × 1080 y 2560 × 1440 la geometría es la misma y solo cambia la escala) y a 1024 × 640 (16:10). Distancia, objetivo de la cámara (x, z), margen al borde de los tres objetivos y del centro de la zona de partida, partidas que el encuadre da por incluidas, partidas que quedan a medio tapar por el HUD, templo en píxeles (ancho × alto), píxeles por 10 m de suelo en la plaza y área del casco del pueblo (manzanas, templo, plaza y los tres objetivos) en % del cuadro.

### 1280 × 720

| Preset | Distancia (m) | Objetivo (x, z) | Batería / Cuartel / Posta (%) | Centro de la zona (%) | Partidas incluidas | A medio tapar | Templo (px) | px por 10 m | Pueblo (% área) |
|---|---|---|---|---|---|---|---|---|---|
| `completo` (el de R1) | 482 | (347, 462) | 30 / 34 / 10 | 23 | las cinco (la peor, el arreo, a 6 %) | — | 66 × 53 | 17,5 | 12,2 |
| `v02_estricto` | 421 | (383, 435) | 27 / 38 / 11 | 12 | Rodríguez, Portal, Arias, reconocedores | — | 75 × 60 | 20,2 | 16,2 |
| `zona_al_borde` | 398 | (381, 399) | 31 / 39 / 10 | 5 | Rodríguez, reconocedores | Arias (bajo el dock) | 83 × 68 | 22,4 | 20,9 |
| **`pueblo_zona_al_borde`** (activo) | **316** | (421, 366) | 27 / 42 / 10 | −19 (fuera) | reconocedores | — | **103 × 86** | **29,0** | **35,8** |
| `pueblo` | 219 | (474, 326) | 12 / 36 / 12 | −73 (fuera) | ninguna | — | 149 × 124 | 44,0 | 89,2 |

### 1024 × 640

| Preset | Distancia (m) | Objetivo (x, z) | Batería / Cuartel / Posta (%) | Centro de la zona (%) | Partidas incluidas | A medio tapar | Templo (px) | px por 10 m | Pueblo (% área) |
|---|---|---|---|---|---|---|---|---|---|
| `completo` (el de R1) | 534 | (349, 465) | 31 / 33 / 10 | 23 | las cinco | — | 53 × 43 | 14,0 | 11,0 |
| `v02_estricto` | 464 | (387, 435) | 28 / 38 / 11 | 11 | Rodríguez, Portal, Arias, reconocedores | — | 60 × 49 | 16,2 | 14,7 |
| `zona_al_borde` | 438 | (383, 402) | 32 / 39 / 10 | 5 | Rodríguez, reconocedores | Arias | 66 × 54 | 17,9 | 18,6 |
| **`pueblo_zona_al_borde`** (activo) | **347** | (422, 369) | 29 / 42 / 10 | −18 (fuera) | reconocedores | — | **83 × 69** | **23,1** | **31,6** |
| `pueblo` | 243 | (473, 328) | 12 / 36 / 12 | −71 (fuera) | ninguna | — | 118 × 99 | 34,5 | 74,9 |

Lectura: respetando V02 al pie de la letra (`v02_estricto`: los tres objetivos y el centro de la zona a ≥ 10 %) la cámara solo se acerca un 13 % (421 m contra 482 u 489), y deja al arreo fuera y a Portal al borde. Con el centro de la zona a 5 % (`zona_al_borde`) se gana otro poco y Arias queda bajo el dock a 720p. El salto grande llega cuando la zona de partida pasa a estar **al borde** y no entera: `pueblo_zona_al_borde` acerca la cámara **un 35 %** (×1,55 en tamaño: el templo pasa de 65 × 52 a 103 × 86 px) y `pueblo`, un 55 % (×2,2), pero deja la zona de partida 237 m fuera del cuadro.

## 4. Antes y después (preset activo `pueblo_zona_al_borde`)

«Antes» es la rama `humahuaca-r1` tal como estaba (`initial_pose()` de B-015 sobre el `initial_frame` de la vista); «después», esta rama. Mismo mundo (semilla 1817), misma inclinación (52°) y el mismo rumbo (325°, A-11).

| Medida | 1024 × 640 | 1280 × 720 | 1920 × 1080 | 2560 × 1440 |
|---|---|---|---|---|
| Distancia de la cámara (m) | 550 → **347** | 489 → **316** | 489 → **317** | 489 → **317** |
| Objetivo de la cámara (x, z) | (348, 466) → (422, 369) | (345, 463) → (421, 366) | (343, 460) → (420, 364) | (343, 460) → (420, 364) |
| Templo (ancho × alto, px) | 52 × 41 → **83 × 69** | 65 × 52 → **103 × 86** | 99 × 79 → **155 × 129** | 132 × 105 → **207 × 172** |
| Posta (ancho × alto, px) | 52 × 42 → 89 × 76 | 67 × 54 → 112 × 97 | 101 × 82 → 168 × 146 | 134 × 109 → 224 × 195 |
| Cuartel (ancho × alto, px) | 34 × 26 → 54 × 42 | 43 × 32 → 67 × 53 | 65 × 49 → 101 × 79 | 86 × 65 → 134 × 106 |
| Batería (ancho × alto, px) | 41 × 28 → 66 × 44 | 52 × 35 → 82 × 54 | 78 × 53 → 122 × 81 | 104 × 70 → 163 × 108 |
| Píxeles por 10 m de suelo en la plaza | 13,6 → **23,1** | 17,3 → **29,0** | 26,1 → **43,5** | 34,7 → **58,0** |
| Pueblo: área del casco (% del cuadro) | 10,4 → **31,6** | 11,9 → **35,8** | 12,1 → **36,1** | 12,1 → **36,1** |
| Pueblo: caja (ancho × alto, % del cuadro) | 43 × 41 → 73 × 74 | 44 × 46 → 74 × 84 | 44 × 47 → 74 × 85 | 44 × 47 → 74 × 85 |
| Tres objetivos: caja (ancho × alto, %) | 38 × 25 → 62 × 43 | 39 × 28 → 62 × 47 | 39 × 29 → 62 × 48 | 39 × 29 → 62 × 48 |
| Margen de la batería (%) | 31,3 → 28,7 | 29,8 → 27,4 | 30,5 → 28,1 | 30,5 → 28,1 |
| Margen del cuartel (%) | 33,5 → 42,4 | 33,4 → 42,4 | 33,3 → 43,2 | 33,3 → 43,2 |
| Margen de la posta (%) | 10,9 → 10,0 | 10,3 → 10,1 | 10,0 → 10,0 | 10,0 → 10,0 |
| Margen del centro de la zona de partida (%) | 24,0 → **−18,5** | 23,6 → **−18,6** | 23,5 → **−18,7** | 23,5 → **−18,7** |
| Margen de los reconocedores (%) | 36,8 → 4,0 | 36,7 → 4,1 | 36,6 → 4,0 | 36,6 → 4,0 |
| Partidas dentro del cuadro | 5 → **1** | 5 → **1** | 5 → **1** | 5 → **1** |
| Ficha más baja, de pie (px) | 49,2 → 49,2 | 49,3 → 49,2 | 49,4 → 49,4 | 49,4 → 49,4 |

Las fichas a 1280 × 720, de pie (base a cima, sin anillos): Rodríguez 59, Portal 57, Arias 71 a 76 (el banderín), reconocedores 49, arreo 56 a 57 px, antes y después (sección 1: tamaño fijo). El `initial_frame().fits` de la vista sigue verdadero a los cuatro tamaños (la sugerencia de la vista no cambió).

Zoom por rueda (1280 × 720): del cuadro inicial al mínimo se baja en 16 pasos (antes 17); el mínimo pasa de 40 a **30 m**, el máximo sigue en 900 m; al acercar, el punto del suelo bajo el cursor se queda (desvío máximo 0,27 m en cinco pasos). Al mínimo, el templo ocupa 1 396 × 1 263 px (antes 978 × 824) y las fichas ya miden más que su mínimo: arreo 94, Rodríguez 74, reconocedores 65, Portal 54 px (antes 54 a 70).

Centrado y seguimiento: la tecla 4 dos veces centra en los reconocedores (a 0,0 m) y, tras 60 m de marcha, la cámara sigue a 0,0 m de la ficha (antes quedaba a 60 m); la rueda no la suelta; mover con las teclas, centrar en un frente o volver al cuadro inicial sí.

## 5. El compromiso, dicho claro

- **V02** (QA_NIVEL2 v1.5): «los 3 objetivos y la zona de partida con `on_screen` verdadero y a ≥ 5 % del borde» (el encargo lo leyó como 10 %). Con el preset activo los **tres objetivos** quedan a ≥ 10 % a los cuatro tamaños, pero el **centro de la zona de partida queda fuera del cuadro** (−19 %): el informe de QA dirá `on_screen: false` para `zona_partida` y **V02 falla** mientras la rúbrica diga eso. La zona está «al borde» como lo pidió el usuario: su punta noreste, con los reconocedores (la partida que se usa primero), a 4 % del borde izquierdo; el resto de la zona y las otras cuatro partidas quedan al oeste, fuera del cuadro, y entran solas al marchar hacia el pueblo (o con la tecla de cada una, que ahora las sigue). Si el Jefe de QA mantiene la letra de V02, el preset `v02_estricto` la cumple con un 13 % de acercamiento; cambiar de preset es una clave en `data/humahuaca_camera.json`.
- **B-015 y B-021** (las cinco partidas a ≥ 5,5 % del borde y ninguna bajo el HUD) quedan superadas en parte: las partidas que el encuadre **incluye** siguen a ≥ 2 % y ninguna ficha dentro del cuadro queda bajo el HUD (la pasada «a medio tapar» lo cuida); las que quedan fuera del cuadro ya no cuentan. `tests/test_hx_flow.gd` mide eso mismo desde esta rama (antes exigía las cinco).
- **El zoom mínimo** pasa de 40 a 30 m: CONTRATO 3.5 dice «entre 40 y 900 m» y habría que anotarlo (sección 8). A 30 m y 52° la cámara queda a 24 m del suelo; el piso de 3 m sobre `height_at` sigue, pero nadie midió si a esa distancia la torre (10 m) o el templo (7 m) se le meten delante en algún encuadre.
- **Las fichas** siguen en 49 a 59 px (sección 6).
- **`tools/ui_qa_humahuaca.gd`** (ventana real) sigue con las comprobaciones viejas: «ninguna ficha bajo el HUD» y «todas a ≥ 5,5 % del borde» sobre las cinco partidas (`_cycle_overflow` y `_token_margins`), que ahora fallan por diseño; hay que pasarlas al mismo criterio que `test_hx_flow` (las partidas que `hx.cam.last_fit.soft_in` incluye). No se tocó por el alcance de esta rama.

## 6. Lo que la cámara no puede: las fichas a ≥ 64 px

Las fichas son de tamaño fijo en píxeles reales (`humahuaca_visual.json: tokens`, pista visual): `min_px` 58 (Rodríguez), 56 (Portal, Arias, arreo) y 48 (reconocedores), más el 3 % que suma `upright_scale`. Con la cámara a 316 m una figura de 1,8 m mediría 5 px por sí sola; a cualquier zoom de juego lo que se ve es `min_px`. Para que la más baja mida ≥ 64 px a 1280 × 720 hay que subir `min_px` (por ejemplo a 70, 68, 68, 62 y 68: así ninguna baja de 64 y las proporciones entre fichas se mantienen) y revisar lo que el HUD da por sentado sobre ese alto: `avoid_rects()` usa 62 px por figura, `_check_alert_free` 60 px, el radio de selección 55 px y la hoja de fichas de V03. A 1920 × 1080 y 2560 × 1440 el mismo `min_px` ocupa una fracción menor de la pantalla (56 px son el 7,8 % del alto a 720p y el 3,9 % a 1440p): si lo que se quiere es que la ficha se vea igual de grande en cualquier monitor, `min_px` tendría que ser una fracción del alto de la ventana, no un número fijo. Es trabajo de la pista visual con la de interfaz; la prueba de esta rama informa `ficha_objetivo_64px_cumplido` (hoy falso) sin exigirlo.

## 7. Qué tiene que mirar un humano con ventana real

Nadie vio esto dibujado. Con `godot --path . --resolution 1280x720` (y después a 1920 × 1080 y a 1024 × 640), menú → Humahuaca → «Empezar» (o saltar la apertura con cualquier tecla):

1. **El primer cuadro**: el pueblo centrado y grande (el templo de unos 100 px de ancho a 720p), la batería a la izquierda, la posta a la derecha a un 10 % del borde; los reconocedores (ficha 4) asomando por el borde izquierdo, con su anillo entero; **ninguna otra ficha** a la vista. ¿Se entiende de dónde vienen las partidas? La apertura (12 a 15 s) las recorre y el minimapa las muestra: juzgar si alcanza o si conviene `v02_estricto`.
2. **El HUD**: que ninguna ficha ni rótulo quede bajo la cabecera o el dock en el primer cuadro y cuando las partidas entran marchando desde la izquierda (B-021).
3. **El zoom**: rueda hasta el mínimo (30 m) sobre el templo y sobre la torre: que la cámara no se meta en un techo ni atraviese la torre; que el punto bajo el cursor se quede.
4. **Seguir una ficha**: elegir los reconocedores (4), darles un reconocimiento a la batería y apretar 4 otra vez: la cámara tiene que acompañarlos sin sacudidas y soltarse al tocar W A S D, el borde, el botón del medio, el minimapa o Inicio. Juzgar si el seguimiento ayuda o molesta; se apaga con `follow.enabled: false`.
5. **Las otras resoluciones**: a 1024 × 640 la cámara queda a 347 m (16:10 es más angosto); comprobar que la posta no toque el borde derecho.
6. **El resto de presets**, cambiando `initial_frame.preset` en `data/humahuaca_camera.json` y reiniciando: `pueblo` es la versión «bien cerca» (×2,2) sin ninguna partida a la vista; `v02_estricto`, la que respeta la rúbrica tal cual.
7. **Las fichas**: si siguen «chicas», es `min_px` (sección 6), no la cámara.

## 8. Alcance y lo que queda para otras pistas

- Pedido: tocar solo `humahuaca_camera.gd`, `data/humahuaca_camera.json` (nuevo) y `tests/test_hx_camera.gd` (nuevo). **Además** se tocaron dos archivos de la propia pista `ui_feel`, en commits separados para poder revertirlos solos: `humahuaca_ui_base.gd` (`initial_pose()` delega en la cámara: sin eso el encuadre no cambia, porque el ajuste viejo vivía ahí; se quitó `_measure_points`, que solo usaba ese ajuste) y `tests/test_hx_flow.gd` (las dos comprobaciones que codificaban el encuadre viejo, autorizado por el encargo). Ninguna otra sesión en paralelo edita esos archivos.
- Para la pista visual: `min_px` (sección 6); las vistas canónicas `juego_noche` y `juego_alba` y el `initial_frame` del JSON visual siguen diciendo 470 m: ya no son la cámara inicial real (hoy 316 m en 16:9); conviene alinearlos o aclararlo en VISUAL.md.
- Para compuertas y documentos: CONTRATO 3.5 («zoom entre 40 y 900 m»; «el zoom inicial sale de `initial_frame()`») y V02 de QA_NIVEL2 (la zona de partida a la vista), `tools/ui_qa_humahuaca.gd` (sección 5) y la lista de propiedad de `tools/qa_gate.sh` (`owner_allows`, pista `ui`: sumar `data/humahuaca_camera.json`, `tests/test_hx_camera.gd` y `docs/humahuaca/CAMARA.md`). CONTROLES.md podría anotar que la tecla 4 o 5 repetida **sigue** a la ficha.
- Cómo se corre la medida: `XDG_DATA_HOME=<carpeta con «ap_iso»> godot --headless --path . --audio-driver Dummy --script tests/test_hx_camera.gd -- --informe=<ruta.json>` (en Windows, `APPDATA`). Las tres suites pedidas (`test_hx_flow`, `test_hx_view`, `test_hx_smoke`) corren igual y quedaron verdes con Godot 4.7.2 en Linux.
