# Addenda al contrato «Humahuaca»

Registro de los cambios al contrato (`docs/CONTRATO_HUMAHUACA.md`, revisión 1.1) y al diseño (`docs/DISENO_HUMAHUACA.md`, 1.1) que se decidieron **después** de escribirlos. Lo lleva el **integrador**: es el único que aplica una addenda al texto vigente y sube la revisión (1.2, 1.3…). Nadie más edita el contrato ni el diseño: se pide por escrito acá, con id, firma, motivo y prueba de aceptación (CONTRATO 6.1).

**Cómo se lee.** Una addenda **vigente** manda sobre el texto del contrato y del diseño en lo que lo contradiga, hasta que el integrador la aplique al texto (la fila «Aplicada» de la tabla pasa de «no» a la revisión que la incorporó). Las decisiones del usuario no se discuten acá: se registran con su fecha. Las correcciones del integrador no cambian ninguna firma de la sección 3.

| Id | Fecha | Origen | Resumen | Vigente | Aplicada al texto |
|---|---|---|---|---|---|
| A-01 | 1-nov-2026 | decisión del usuario | Canal de arte: generador procedural en GDScript; Blender **no** autorizado | sí | no |
| A-02 | 1-nov-2026 | decisión del usuario | Tesela Copernicus GLO-30 S24_00_W066_00 autorizada (ya descargada) | sí | no |
| A-03 | 1-nov-2026 | decisiones del usuario | Alcance aprobado; sin playtesters humanos; no hay más material del usuario | sí | no |
| A-04 | 1-nov-2026 | integrador (T0) | Correcciones a los ganchos de `main.gd` del 4.1 y notas de integración para `ui_feel` | sí | no |
| A-05 | 1-nov-2026 | integrador (T0) | Valores provisionales de los JSON mínimos de R0 | sí | no |
| A-06 | 1-nov-2026 | integrador (R1.0) | Apertura de R1.0, sanidad de V5 sin depender de un mapa vacío, propiedad de `stub_rules_*.gd` y etiquetas ajenas en el repositorio | sí | no |
| A-07 | 1-nov-2026 | integrador (R1.0) | Respuesta a los pedidos entre pistas de R1.0 y decisión sobre el cuadro inicial (VP-06): no se ensancha para incluir las cinco partidas | sí | no |

---

## A-01 · Canal de arte: generador procedural; Blender no autorizado

- **Origen:** decisión del usuario, 1 de noviembre de 2026. Blender **no está autorizado**: no se descarga, no se instala y `tools/create_models.py` no corre.
- **Qué cambia en el texto:** CONTRATO 6.3 punto 6 y el anexo (decisión D11) dicen «generador procedural por defecto, Blender opcional»; DISENO 11.2 («Modelos y canal de arte») dice que Blender 4.4.3 portable (385 412 148 B) es una «mejora opcional», y su anexo B lo lista como pregunta pendiente. Pasa a ser: **el generador procedural es el único canal de arte** y Blender deja de ser una pregunta pendiente.
- **Qué implica:**
  1. Todo el arte nuevo sale del generador de `visual` (`humahuaca_gen.gd` y los constructores de `view/**`, con primitivas de Godot: `BoxMesh`, `PrismMesh`, `CylinderMesh`, `SurfaceTool`, `MultiMeshInstance3D`) y de los `.glb` existentes retintados que el diseño lista como útiles (`horse_only`, `royalist_1817`, `rider_1817`, `house_colonial`, `tree_cardon`, `rock_cluster`).
  2. `assets/models/humahuaca/**` queda vacío salvo que el generador exporte algo; no entra ningún `.blend`.
  3. El render «héroe» del templo y de los tres arquetipos al cierre de R1 sigue en pie con su aceptación medible (AABB del templo ≤ 8 m; los tres arquetipos se distinguen en escala de grises a 48 px).
  4. Si el generador no alcanza, es un hallazgo de `visual` y se baja el alcance en el **orden de descarte** del diseño (sección 14); nadie vuelve a pedir Blender como solución.
- **Prueba de aceptación:** `git ls-files` no suma ningún `.blend` ni `.glb` nuevo de origen externo; los ítems V01 a V06 de la rúbrica del QA se miden sobre lo que produce el generador.

## A-02 · Tesela Copernicus GLO-30 S24_00_W066_00 autorizada

- **Origen:** decisión del usuario, 1 de noviembre de 2026. Reemplaza la pregunta (1) del anexo B del diseño («permiso para bajar la tesela»): el permiso está concedido y la tesela **ya está descargada**.
- **Archivo (verificado el 1-nov-2026):**
  - Ruta: `C:/Users/User/Desktop/spum/IA/Proyectos/MaravillaArgentina/guemes/investigacion-nivel2/descargas/Copernicus_DSM_COG_10_S24_00_W066_00_DEM.tif` (fuera de Git).
  - Tamaño: **39 438 103 bytes**.
  - SHA-256: `1b38c9054683f2ea927915ffc9f81e664f919cf13a6cbb4e93a1bd637301f97f`.
  - MD5: `8c0aef1d66f4d1e918a25ff7864ecab3` (el que esperaba `04_herramientas.md`).
  - En la misma carpeta están las teselas S25 y S26 (descargadas antes). La de Humahuaca (ancla a 23,2041° S, 65,3492° O) es la S24, según `04_herramientas.md`: las otras dos no hacen falta para la ventana.
- **Uso (condicional):**
  - **R1** sigue con la **lámina 03 reconstruida** como fuente del relieve (`meta.source = lamina03_reconstruida`): es el plan B y, además, la **referencia de verificación** de la prueba A/B de CONTRATO 2.1.
  - **Desde R2a** la tesela pasa a ser la **fuente principal** (`meta.source = copernicus_glo30`) **si los ítems R02 a R06 de la rúbrica pasan con ella** (los 41 puntos de la lámina, las curvas de 20 m, el Río Grande, la prominencia de la batería y la continuidad del terreno). Si alguno falla, el relieve se queda con la lámina y se anota en `docs/humahuaca/RELIEVE.md`.
- **Condiciones:**
  1. El relieve del juego sigue siendo `data/humahuaca_height.json` (decímetros enteros): **la tesela no se exporta ni entra a Git** (el `.gitignore` suma `*.tif`) y nadie la copia dentro del repo.
  2. **Atribución obligatoria** en `docs/humahuaca/CREDITOS_RELIEVE.md` (y, en [final], en `docs/CREDITOS.md`): el aviso de la licencia con el prefijo «produced using Copernicus WorldDEM-30» (el dato se remuestrea, se suaviza y se recorta: `meta.modified = true`) y la frase de no responsabilidad del Artículo 6. El texto exacto se copia del Artículo 6 de la licencia, no de un resumen. Lo verifica V18.
  3. Con Copernicus el relieve es un **modelo de superficie** (techos y árboles de hoy): el suavizado va de 30 a 45 m (`meta.smooth_m`) y la incertidumbre es ±5 m (`meta.uncertainty_m`). Sigue siendo dato actual, **no restitución del suelo de 1817**.
- **Prueba de aceptación:** `test_hx_terrain` (prueba A/B de la fuente) y los ítems R02–R06; `git status` sin ningún `.tif`; V18 verde si `meta.source` es `copernicus_glo30`.

## A-03 · Decisiones del usuario de esta sesión

Registradas el 1 de noviembre de 2026, tal como las dio el usuario:

1. **Alcance aprobado.** Humahuaca es el **nivel 2** y «Sostener el norte» pasa a ser el **nivel III**, sin cambios de reglas. Esto responde con un **sí** a la pregunta (3) del anexo B del diseño («¿es lo que querías?»): **no hace falta** mandar la captura de la cámara inicial al cierre de R1 para confirmar el reemplazo (la captura se sigue guardando como evidencia). La decisión D1 sigue como estaba: el Norte conserva su candado y Humahuaca está siempre habilitado.
2. **Nadie jugará a mano.** El **agente-jugador** (arnés `tools/hx_agent_play.gd`) reemplaza al humano: los mini-playtests de 10 minutos al cierre de R1 y R2b y la sesión humana de 20 minutos **no se hacen**. El veredicto máximo del QA es **«PRESENTABLE, no certificado por humanos»**; nunca «certificado». `docs/humahuaca/PLAYTEST.md` registra «sin playtesters humanos».
3. **No hay más material del usuario.** Ni el paquete editable de 39 archivos, ni las láminas 01, 04 y 05, ni la tabla de 23 elementos, ni las 16 fichas. Se trabaja con lo que hay (el `.md`, las láminas 02, 03 y 06, la foto de 1923 y los informes de preparación); **lo que falta se rotula como diseño** y no se espera ninguna corrección por addendum «cuando llegue» (anexo A del diseño: queda como está).
4. **Directriz vigente (sin cambios):** la diversión y la claridad mandan; la fidelidad histórica es una guía, con etiquetas honestas y cero anacronismos graves.

## A-04 · Correcciones a los ganchos de `main.gd` (4.1) y notas de integración

**Corrección, sin cambio de firma.** El código de ejemplo del 4.1 queda así en `main.gd` (commit de T0). Cada diferencia con el ejemplo tiene su motivo:

| Dónde | Diferencia con el ejemplo del 4.1 | Motivo |
|---|---|---|
| `_start_humahuaca` | Empieza con `_stop_humahuaca()` | Si el nivel se arranca dos veces seguidas (por ejemplo `--scenario=humahuaca` más el botón), el controlador anterior quedaba vivo y huérfano |
| `_start_humahuaca` | Fija `scene_build_ms` cuando vuelve `hx.start(...)` | `_start_game` desvía antes de medir y el benchmark informaría una construcción de 0 ms: el tope de 1 500 ms no se estaría midiendo. Es el tiempo que tarda `start()` en construir terreno, reglas y vista |
| `_on_hx_exited` | Llama `_stop_humahuaca()` **antes** de `_start_game("norte")` | Con `"norte"` no se pasaba por `_menu()`, que es quien detenía el controlador: el Norte arrancaba con el controlador de Humahuaca todavía vivo |
| `_finish_automation` (H7) | Llama `_stop_humahuaca()` | El QA y el benchmark liberan `layer` y `ui` antes de salir: el controlador no puede seguir vivo sobre una interfaz liberada |
| `_qa_run("humahuaca")` (H7) | Ramifica **antes** de `_start_game`: arranca con `{"qa": true, "skip_intro": true}`, espera 30 cuadros, hace `await hx.qa_run()` y sale con 0 (o 2 si el controlador no arrancó) | El nivel no pasa por `main.rules`: el resto de `_qa_run` (métricas, `_qa_justina`, informe) lee `rules.state` de la Justina del menú |
| `_benchmark_run("humahuaca")` (H7) | `hx.benchmark_prepare()` justo antes de los 30 cuadros de calentamiento | El resto del benchmark ya sirve tal cual (`_start_game` desvía por H3) |
| Menú (H2d) | El botón de Humahuaca lleva un `tooltip_text` | Los otros dos botones lo tienen; el texto evita «EL RÍO OFRECE», «SOSTENER EL NORTE» y «Ganá la Justina para abrirlo», que buscan las pruebas |

**Medición de T0 del menú de tres botones** (cierra la duda del 4.1: «a 1920 × 1080, 2560 × 1440 y Compatibility no se midió»). Con ventana real, el último elemento del menú termina en y = 856 de 900 píxeles lógicos (el alto de la base de diseño) en 1024 × 640, 1280 × 720, 1920 × 1080 y 2560 × 1440 con Forward+, y en 1280 × 720 con Compatibility. Los tres botones miden 82 px de alto por 510 de ancho (y = 425 a 695). `ui_qa` da 254/0 en las tres resoluciones con el menú nuevo y `--qa=humahuaca` corre igual con Compatibility.

**Notas de integración para `ui_feel`** (el controlador real reemplaza la cáscara en R1.0 y tiene que respetar lo que `main.gd` ya hace; ninguna es un cambio de contrato):

1. Con `mode == "hx"`, `main._process` sigue llamando a `_apply_camera()` y mueve `main.camera` con las variables de cámara del menú. El controlador fija la transformación de `main.camera` en **su propio** `_process` (corre después de `main`, porque es su hijo; con `process_priority` mayor queda asegurado) o usa su propia `Camera3D`.
2. `main._unhandled_input` atiende **F11** y **Tab** (`_focus_hud`) en cualquier modo. El controlador marca `get_viewport().set_input_as_handled()` en las teclas que usa (Tab para ciclar agrupaciones, Esc, las de velocidad); como es hijo de `main`, recibe el evento antes.
3. `exited` se emite desde callbacks de nodos del propio controlador (botones del parte, tecla Esc): `stop()` libera con `queue_free()`, **nunca** con `free()`.
4. `stop()` es **idempotente**: `main` lo llama desde `_menu()`, `_return_menu()`, `_on_hx_exited()` y `_finish_automation()`, y puede llamarlo más de una vez sobre el mismo controlador.
5. «Continuar» (con `settings.last_save == "humahuaca"`) y `F9` llegan como `start(main, {"load": true})`, antes de `rules.load_game`, que solo conoce `justine` y `norte`. El controlador lee su propio guardado (`main._save_path("humahuaca")`); si lo rechaza (otro `map_version`, archivo dañado) tiene que terminar en un mensaje claro y en el briefing, no en un error ni en un cuelgue.

## A-05 · Valores provisionales de los JSON mínimos de R0

Los seis `data/humahuaca_*.json` de T0 traen `contract: 1` y `map_version: 1`, más lo que cada rúbrica exige desde R0. Lo siguiente es **provisional** y su dueño lo reemplaza en R1:

- **`humahuaca_height.json`** es un **plano a +17,0 m** (170 dm en las 6 006 celdas de la ventana y en las 11 011 del contexto; la cota del templo sobre el cero local de 2 940 m). Se rotula con honestidad: `meta.source = lamina03_reconstruida` (el plan de R1), pero `meta.tag = "diseno"` y `meta.uncertainty_m = 25,0` (el plano se aparta hasta ≈ 22 m del relieve de la ventana: de 2 941 a 2 979 m con SRTM de 30 m, según `03_arquitectura_actual.md`), y `meta.source_detail` dice que es un plano de andamiaje. `tools/build_humahuaca_terrain.py` lo regenera en R1 con `razonado` y ±10 m. `meta.credits_ref` apunta a `docs/humahuaca/CREDITOS_RELIEVE.md`, que escribe `relieve_mapa`.
- **`humahuaca_map.json`** trae solo las claves obligatorias desde R0 (identidad, `size_m`, `axes`, `anchor`, `lamina`, `datum_asl_m`); los hitos, las capas de diseño, las superficies y el río los agrega `relieve_mapa` en R1.0 y R1.
- **`humahuaca_visual.json`** ya trae la **paleta de 24 HEX** de la lámina 06 (V9 corre desde R0), en el orden de la lámina y con ids propuestos (`suelo_seco`, `sedimento_humedo`, …, `grana_analogia`) y grupos `paisaje`, `construcciones`, `personajes` y `simbolos`. `visual` puede cambiar los ids; **no** los HEX ni su cantidad.
- **`humahuaca_level.json`, `humahuaca_rules.json` y `humahuaca_ui.json`** traen solo la identidad (`level_version` y `rules_version` en los dos primeros); el contenido llega en R1.0.
- **`scenarios.humahuaca` en `data/history.json`** es un esqueleto: título, fecha, lugar, contexto, aviso, nota de arte y desenlace de referencia, con `facts` vacío. Los textos salen de la matriz de afirmaciones del diseño (12.2) con su fecha rotulada como discutida; `reglas_historia` los completa (hechos, fuentes desde **S46**). Lo existente en `history.json` no cambió ni un byte (el hecho «Humahuaca: Arias al mando» del Norte, las 47 fuentes y `scenarios.justine/norte`).

## A-06 · Integración de R1.0: ronda vigente, sanidad de V5, propiedad de `stub_rules_*.gd` y etiquetas ajenas

Registrado el 1 de noviembre de 2026 por el integrador al fusionar las cuatro ramas de R1.0. **Ninguna firma de la sección 3 cambia.**

1. **Ronda vigente.** `docs/humahuaca/TRAZA.md` pasa de `r0` a `r1.0` en el primer commit de la integración: es la ronda que abre el tren de merges (los stubs de las cuatro pistas se exigen desde esta ronda). La próxima ronda (`r1`) la abre el integrador en su propio commit.
2. **Corrección de la compuerta de datos (pedido de `relieve_mapa`, confirmado por `visual`).** La mutación de sanidad de V5 «access que cita hitos sin mapa» (`tests/test_hx_data.gd`) solo plantaba un `access` y daba por hecho que el mapa real no tenía hitos: apenas `relieve_mapa` entrega los 21 hitos, `zona_partida` resuelve y el error plantado desaparece, de modo que **toda rama que trajera hitos fallaba la compuerta rápida por una sanidad y no por un defecto de su código**. La mutación ahora vacía `map.landmarks` en la copia antes de plantar el `access` (`_plant_access_without_map_landmarks`). No relaja ninguna regla: V5 sigue viendo exactamente el mismo error.
3. **Propiedad (pedido PD-R-01 de `reglas_historia`).** El stub de reglas se partió en tres archivos para respetar las ~1 500 líneas por archivo del CONTRATO 0: `scripts/humahuaca/stubs/stub_rules.gd` (núcleo), `stub_rules_info.gd` (consultas de solo lectura y «siguiente paso») y `stub_rules_save.gd` (guardado, carga y validación). Los tres, con sus `.uid`, son de `reglas_historia`; el patrón de `owner_allows` de `tools/qa_gate.sh` pasa a `stub_rules*.gd`. Queda congelado como cualquier stub (se corrige solo por addendum).
4. **Observación abierta, sin decisión del integrador: dos etiquetas que no son de este equipo.** `git tag --list` muestra `v0.2.0-alpha` (commit `d988562`) y `v0.3.0-alpha` (commit `72077c8`) además de `v0.1.0`. Son referencias livianas escritas el 1-nov-2026 a las 21:59:33 con un milisegundo de diferencia, sobre dos commits del 28-oct que son ancestros de `main` (`72077c8` es la punta de `origin/main`); `FETCH_HEAD` es del 29-oct, así que no vinieron de un `fetch`, y ninguna herramienta del repositorio crea etiquetas. Ni las pistas ni el integrador las crearon (y el contrato prohíbe etiquetas nuevas), por eso **no se borran**: el paso `higiene` de `tools/qa_gate.sh` falla mientras existan y lo decide el usuario (borrarlas, o aceptarlas y que la compuerta las admita por addendum).

## A-07 · Pedidos entre pistas de R1.0 y decisión sobre el cuadro inicial

Registrado el 1 de noviembre de 2026 por el integrador, con las ramas de R1.0 ya fusionadas. **Ninguna firma de la sección 3 cambia y no hace falta ningún gancho nuevo en `main.gd`: ninguna pista pidió uno, así que no hay commits `hook-N` en esta ronda.**

| Pedido | De → a | Respuesta |
|---|---|---|
| P1 (sanidad de V5 en `test_hx_data`) | `relieve_mapa` → compuertas y documentos | Hecho: A-06, punto 2. Confirmado por `visual`, que midió la misma falla juntando las cuatro ramas |
| PD-R-01 (`stub_rules_info.gd` y `stub_rules_save.gd`) | `reglas_historia` → integrador | Hecho: A-06, punto 3 |
| VP-01 (`environment().time_of_day` continuo: 0 hasta ≈ 240 s, 0,5 a los 285 s, 1,0 a `day_full_s`) | `visual` → `reglas_historia` | Aceptado. **El stub todavía no cumple las cinco muestras**: medido con el stub fusionado da 0,00, 0,15, 0,35, 0,65 y 0,88 a los 0, 240, 285, 330 y 420 s, contra 0, 0, 0,5, 0,67 y 1,0 pedidos. La curva es continua y creciente, pero el alba llega tarde y el día pleno no llega a 1,0 en `day_full_s`. El stub queda como está (congelado); la clase real lo cumple desde R1 y `test_hx_rules` lo fija con esas cinco muestras, dentro de ± 0,05 |
| VP-02 (`render_state().version` sube con cada cambio visible; `tower` es `{}` o trae las coordenadas de **la** torre del mundo) | `visual` → `reglas_historia` | Aceptado: ya es la forma de 3.2.3. Prueba de aceptación en `test_hx_rules` (R1): con cada valor de `torre_en`, `tower` cae a menos de 40 m del hito de esa variante |
| VP-03 (convención de la huella y del `yaw_deg`) | `visual` → `relieve_mapa` | Aceptado como convención vigente, la de `docs/humahuaca/VISUAL.md` 3.1 y 3.2: rumbo horario desde el norte; `w` sobre +x y `d` sobre +z **antes** de girar. `relieve_mapa` la confirma o la corrige por addendum en R1 y `test_hx_terrain` fija la esquina de un hito con `yaw_deg` ≠ 0 |
| VP-04 (`height_at` continua un poco más allá del contexto, `landmarks({})` con `footprint` y `height_m`, `features(kind)` con `pts` como `{x, z}`, `river().bed_width_m` y `pts`, `minimap_image(px, {})` de exactamente `px`) | `visual` → `relieve_mapa` | Aceptado: es la API vigente de 3.1 y la que consume la vista desde el stub. Los cinco contratos van a `test_hx_terrain` (R1) sobre el terreno real y sobre el stub |
| VP-05 (el controlador pasa la cámara ya dentro del árbol a `initial_frame`, llama `update_state(delta)` cada cuadro y sube `camera.far` a 9 000 o más) | `visual` → `ui_feel` / integrador | Ya lo hace el controlador fusionado (`start()` fija `far = 9000` y `fov = 46`; `initial_frame(main.camera)` va después de construir la vista; `_process` llama `update_state`). Las capturas de integración a 1280 × 720, 1024 × 640 y 1920 × 1080 lo muestran. `test_hx_flow` (R1) lo fija con la cámara real a 1280 × 720 y a 1024 × 640 |
| VP-06 (¿entran las cinco partidas en el cuadro inicial?) | `visual` → integrador / compuertas y documentos | **Decisión: no.** Se mantiene lo que dicen el contrato (3.4: «DEBE incluir los 3 objetivos y la zona de partida») y la rúbrica V02, que exige los tres objetivos y la zona a ≥ 5 % del borde y no pide las cinco fichas. Agregar los `spawn_*` al `must_include` abre el cuadro hasta unos 810 m: todo queda ≈ 40 % más chico y de noche se lee peor. Evidencia de integración con las clases fusionadas: a 1280 × 720 y a 1920 × 1080 entran las cinco fichas; a 1024 × 640 (16:10, el mínimo del proyecto) el arreo toca el borde izquierdo. Las cinco partidas se encuentran con el panel de agrupaciones y las teclas 1 a 5 (R1) y con la apertura de 12 a 15 s. **Prueba de aceptación:** `test_hx_flow` (R1) comprueba que el primer cuadro jugable lista las cinco agrupaciones; la revisión del encuadre a 16:10 queda para R2a, cuando haya minimapa y rótulos (BACKLOG B-015) |

**Comprobación a mano del integrador** (script descartable, sin valor de prueba: lo que cuenta es `test_hx_data` cuando se encienda cada regla, BACKLOG B-013) sobre los datos fusionados de las cuatro pistas: V6 (los 21 hitos dentro de la ventana; objetivos separados 101,1, 175,5 y 276,6 m), V11 (las 8 causas de derrota miden entre 61 y 106 caracteres), V12 (ningún JSON cita `res://`), V15 (7 vistas con sus 5 rasgos), V16 (reloj ordenado 270 < 330 < 420 < 840 y 270 < 390; botín de 5 clases que suma 100) y V21 (los 6 puestos de ataque a entre 64 y 87 m de su objetivo y a menos de 150 m) sin hallazgos. V10, V13 completo, V14, V18 y V22 no se comprobaron a mano.
