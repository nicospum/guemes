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
