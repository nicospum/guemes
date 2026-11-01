# QA del nivel 2 «Humahuaca»: qué es «presentable» y cómo se verifica

Documento del **Jefe de Control de Calidad**. Versión **1.0** · 1 de noviembre de 2026 · base `main` en `5a84c50` (diseño y contrato) sobre la línea base `5ebbd28` (Justina y Norte). Está **congelado desde el commit que lo introduce**: los números de este texto son los postes del bucle y no se mueven entre rondas (sección 4, regla 5).

> **Para qué sirve.** En el nivel 1 el control de calidad dijo «no» cinco de cinco rondas porque cada ronda pedía algo nuevo (94 hallazgos sin priorizar) y porque lo que decidía el «sí» —personas jugando— no estaba al alcance del circuito. Acá el criterio se fija **antes** de empezar: 39 ítems con comando, umbral, severidad y evidencia; un presupuesto de hallazgos; tres certificadores que no pueden agregar ítems; y una lista de límites aceptados de antemano. Si todo lo exigible pasa, el QA dice «presentable» y el bucle termina.
>
> **Quién manda sobre qué.** Sobre *qué se juega* mandan `docs/DISENO_HUMAHUACA.md`, `docs/CONTRATO_HUMAHUACA.md` y los JSON. Sobre *cómo se certifica* manda **este documento**. Un valor de juego solo cambia por *addendum* del contrato (`docs/humahuaca/ADDENDA.md`) y, si toca un umbral de acá, por una *enmienda* de este documento (anexo F).
>
> **Diferencias deliberadas con el diseño** (no son errores):
>
> | Tema | Diseño / contrato | Este documento | Por qué |
> |---|---|---|---|
> | Salida del bucle | «0 P0 y ≤ 2 P1» (diseño, sección 14) | **0 ALTA** y todos los BLOQUEA (P0 = BLOQUEA, P1 = ALTA, P2 = MEDIA) | indicación del lead: «0 ALTA abiertas» |
> | Sesión humana | el diseño la exige para decir «presentable» | **límite aceptado** (sección 5): el veredicto máximo es «PRESENTABLE, no certificado por humanos»; la sesión es opcional (anexo E) | nadie juega a mano en este circuito; no se finge lo contrario |
> | Semillas de balance | 8 de calibración, 12 de validación, 14 de cierre | **60 semillas nuevas (9001–9060) × 3 réplicas**, reservadas al QA (sección 3, P6) | con 8–14 semillas el ruido de muestreo mueve las tasas ±15 puntos |
> | Relieve | «≥ 37 de 41 a ≤ 12 m» en `test_hx_terrain` | el QA lo **recalcula** con su propio script sobre un volcado del relieve y suma curvas, río y overlay (R01–R06) | una prueba que escribe la misma pista que la aprueba no basta |

---

## 1. Qué significa «presentable»

**Presentable = una demo del nivel 2 que se le puede mostrar a otra persona sin pedir disculpas.** En tres líneas:

1. **Funciona y no rompe nada.** Desde el EXE en Windows se juega de punta a punta —menú → briefing → noche con lluvia → ataque dividido → extracción → epílogo → reintento—, con victoria y con derrota, guarda y carga, sin errores de consola, a menos de 3 ms por cuadro, **sin romper la Justina ni el Norte**.
2. **Se entiende y se ve.** A los 30 segundos se sabe qué hacer (≤ 5 controles, ≤ 400 caracteres, sin jerga), siempre hay algo que decidir (≤ 45 s), perder enseña y reintentar es inmediato; el relieve de Humahuaca coincide con la lámina 03 y la paleta es la del dossier; nada se solapa ni se recorta en tres resoluciones.
3. **Es honesto y rejugable.** Nada inventado se presenta como documentado, no hay anacronismos graves, ninguna receta gana siempre y un jugador «obediente» simulado gana alrededor de un tercio de las veces al primer intento (objetivo del diseño 25–40 %, aceptado 20–45 %) y casi siempre dentro de cinco intentos — **con el sello «no certificado por humanos»** siempre a la vista.

**Presentable no significa:** perfecto, fiel a 1817 más allá de lo que el dossier documenta, divertido «para todos» (eso solo lo dice una persona) ni libre de cuestiones de gusto. Las cuestiones de gusto no bloquean (sección 4).

**Qué corrige respecto del nivel 1** (cada falla del último intento de certificación de la Justina tiene su ítem):

| Lo que pasó en el nivel 1 | Dónde se mide ahora |
|---|---|
| Lo visual quedó pobre: barranca, fuerte y casas de cajas; unidades como discos; cámara inicial casi solo agua; el río se repintó cinco veces sin referencia | V01 (12 capturas con lista de «qué debe verse»), V02 (cámara inicial), V03 (fichas por silueta), V04 (paleta de la lámina 06); el agua y el suelo no se repintan sin un hallazgo con evidencia |
| De 2 a 4 minutos sin decisiones | J03: primera decisión ≤ 60 s, brecha ≤ 45 s (≤ 20 s en el ataque), medida por las reglas en todas las partidas |
| Una receta fija ganaba siempre | J06: ninguna estrategia gana en más del 80 % de los mundos; ≥ 3 mejores aperturas distintas; cada variante cubierta |
| El arranque abrumaba: 8 botones y jerga («ETA», «sondeo») | C03: ≤ 5 controles, ≤ 400 caracteres, 0 términos de la lista negra |
| Balance malo para el novato; bots con información perfecta; modelo de humanos inventado | J04 y J05 con el bot **obediente** como proxy, 60 semillas nuevas y réplicas; auditoría de ceguera; el sello «no certificado por humanos» |
| 94 hallazgos sin priorizar y criterios que cambiaban cada ronda | sección 4: rúbrica congelada, ≤ 7 hallazgos por ronda, escalera de exigencia, enmiendas con reglas |
| Nadie jugó a mano | límite aceptado L1, dicho de frente, más el protocolo opcional del anexo E |

---

## 2. Rúbrica (39 criterios: 20 BLOQUEA, 18 ALTA, 1 MEDIA)

**Severidad.** **BLOQUEA** = si falla, no hay certificación y se corrige primero (regresión, seguridad, el núcleo del producto). **ALTA** = debe quedar en cero abiertas para certificar. **MEDIA** = cuenta contra el tope de 3 aceptables con razón escrita (sección 5). Cada ítem es **pasa / falla / N** (N = «no evaluable» y **cuenta como falla**: no se infiere nada de lo que no se midió).

**Cómo leer las columnas.** *Método*: `P#` es un procedimiento de la sección 3 (comandos exactos). *Umbral*: todas las condiciones se cumplen a la vez. *Evidencia*: ruta bajo `evidence/humahuaca/<ronda>/qa/<CERT>/` (el certificador es A, B o C).

| ID | Dim. | Criterio | Método | Umbral | Severidad | Evidencia |
|---|---|---|---|---|---|---|
| T01 | T | Archivos protegidos y compartidos intactos; la rúbrica no se movió | P1-a: `git diff --exit-code $BASE HEAD -- $PROT` (40 archivos de la lista 1.3 del contrato); `git diff --numstat` de `main.gd`, `test_integration.gd`, `ui_qa.gd`, `run_qa.py`; `git log -- docs/QA_NIVEL2.md` | protegidos: salida 0; `main.gd` ≤ 80 líneas agregadas y ≤ 10 borradas, ninguna de lógica de la Justina ni del Norte (se lee el diff); `test_integration.gd` y `ui_qa.gd` ≤ 6 agregadas y ≤ 2 borradas; `run_qa.py` ≤ 4 y ≤ 2; todo commit posterior al primero sobre `docs/QA_NIVEL2.md` se titula «QA enmienda N:» | BLOQUEA | `T01/protegidos.txt`, `T01/numstat.txt`, `T01/enmiendas.txt` |
| T02 | T | Regresión de reglas, integración, Jev y audio (Justina y Norte) | P1-b: `test_rules.gd`, `test_integration.gd`, `jev_contract_test.gd`, `audio_runtime_test.gd` | reglas ≥ **871** y 0 fallas; integración ≥ **283** y 0; Jev ≥ **15** y 0; audio «RESULTADO: N comprobaciones, 1 fallas» con N ≥ 17 y la única línea `FALLA:` es «driver de audio real (no Dummy)»; ningún comando se corta por `timeout` | BLOQUEA | `T02/*.log`, `T02/resumen.txt` |
| T03 | T | Suites nuevas del nivel, con sus mínimos | P1-c: `tests/test_hx_{data,terrain,rules,view,flow,smoke}.gd` | cada una imprime su JSON final con `failures: []` y llega a: data **60**, terrain **80**, rules **400** (**250** en R1 y R2, como fija el contrato), view **40**, flow **80**, smoke **25**; en `test_hx_rules`, `performance`: `nav_build_ms` ≤ 80, `plan_route_ms` ≤ 30, `tick_ms` ≤ 2 (promedios) | BLOQUEA | `T03/*.log`, `T03/resumen.txt` |
| T04 | T | Regresión de la Justina y el Norte por interfaz y escena real | P2: `tools/ui_qa.gd` ×3 y `tools/justina_playthrough.gd` | `ui_qa` ≥ **254** y 0 fallas en 1280×720, 1920×1080 y 2560×1440, con `captura_px` igual al tamaño pedido; `justina_playthrough` sale con 0, ≥ 3 estilos ganadores, ≥ 2 rutas, ≥ 1 derrota y `ui_real_victory` verdadero (base medida: 18 victorias, 3 rutas, 6 derrotas) | BLOQUEA | `T04/ui_<WxH>.json`, `T04/justina-playthrough.json` |
| T05 | T | Salida limpia: sin errores de script ni de shader, sin fugas de ObjectDB, sin cuelgues | P1-d: función `limpio` sobre todos los logs (suites, corridas con ventana y EXE); P5-c y P10-b con `--verbose` | `limpio` no imprime nada: 0 líneas que empiecen con `SCRIPT ERROR`, `SHADER ERROR`, `USER ERROR`, `Parse Error`, `ERROR:`, `FATAL`; 0 de «ObjectDB instances leaked», «resources still in use at exit»; 0 `exit=124` (timeout) en `exits.txt`. Única excepción: `T07_guardado.log` (corrompe archivos a propósito), donde solo cuentan `SCRIPT ERROR`, `SHADER ERROR` y `Parse Error` | BLOQUEA | `T05/limpio.txt` (vacío), `exits.txt` |
| T06 | T | Rendimiento y presupuestos | P3 (GPU exclusiva): `tools/benchmark.py ... --scenarios justine,norte,humahuaca --profiles media --repeat 3 --max-frame-ms 3` | `benchmark.py` sale con 0; cuadro medio de Humahuaca ≤ **3,0 ms** (peor de las 3 repeticiones); Justina y Norte ≤ 3,0 (base 2,71 y 0,97); `scene_build_ms` de Humahuaca ≤ **1500** | BLOQUEA | `T06/resumen.json`, `T06/bench.log` |
| T07 | T | Guardado y carga | P4-a: `qa_guardado.gd` (anexo A5); P4-b: `campaign.json` antes y después; `test_hx_smoke` | round-trip sin cambios (tolerancia 1e-6, RNG exacto); **24 de 24** mutaciones obligatorias rechazadas con motivo y sin tocar el estado, **≥ 8 de 13** deseables; guardados de la Justina y del Norte rechazados; `campaign.json` idéntico byte a byte tras correr el nivel; «Continuar» abre el escenario guardado | BLOQUEA | `T07/guardado.json`, `T07/campaign_sha.txt` |
| T08 | T | Robustez y determinismo | P4-c: 200 partidas con la política `aleatorio`; 2 corridas idénticas de 12 semillas | 200 partidas: 0 excepciones, `valid` verdadero al final de todas, ninguna por `timeout`; las 2 corridas dan el mismo `snapshot_sha256` en **≥ 100** partidas comparadas y 0 distintas; `git status --porcelain` del worktree vacío al terminar la certificación | ALTA | `T08/fuzz.json`, `T08/determinismo.txt` |
| C01 | C | Interfaz del nivel sin solapes ni recortes en tres resoluciones | P5-a: `tools/ui_qa_humahuaca.gd --size=WxH` en 1280×720, 1920×1080 y 2560×1440 | por resolución: ≥ **120** comprobaciones y 0 fallas; captura real al tamaño pedido (`notes.resolucion_real` verdadero y `captura_px` igual); 0 paneles fuera del viewport y 0 solapes | BLOQUEA | `C01/ui_<WxH>.json` |
| C02 | C | Tamaño mínimo del proyecto (1024×640) | P5-a con `--size=1024x640` | 0 fallas de recorte o solape; `captura_px` = 1024×640 | ALTA | `C02/ui_1024x640.json` |
| C03 | C | Arranque claro y sin jerga | P5-b: `notes` del primer cuadro jugable; P5-d: escaneo de todas las cadenas visibles contra `jargon_blacklist` | primer cuadro jugable: ≤ **5** controles accionables, ≤ **400** caracteres de texto de juego, una línea de objetivo, **un** «siguiente paso»; **0** términos de la lista negra (≥ 20 términos; incluye ETA, sondeo, ZOC, tag, LOS, HUD, FPS, seed) en cualquier cadena visible de los JSON, del código de la interfaz y de las capturas | BLOQUEA | `C03/arranque.txt`, `C03/jerga.txt` |
| C04 | C | Menú de tres botones y candado correcto | P5-a (capturas `hx-menu-nuevo` y `hx-menu-desbloqueado`) y P5-c (`--scenario=humahuaca`) | último elemento del menú ≤ alto del viewport en las 3 resoluciones; perfil nuevo: «II» deshabilitado con «Ganá la Justina para abrirlo»; con `justina_won`: habilitado; orden I, II, III; `--scenario=humahuaca` abre el briefing sin mirar el candado; el botón del Norte conserva «SOSTENER EL NORTE» y su título de HUD dice «III» | ALTA | `C04/menu.txt`, capturas X01 y X02 |
| C05 | C | Derrota que enseña y reintento rápido | P5-a (flujo de derrota) y P6 (campo `cause_text` de las derrotas simuladas) | `outcome.causes` con ≥ **8** entradas, todas con texto y consejo; todo `cause_text` observado ≤ **140** caracteres, con momento (`m:ss`) y lugar; la pantalla muestra causa, consejo, tres datos y el botón primario **sin scroll** a 1280×720; del clic en «Reintentar» al primer cuadro jugable ≤ **3 s** en las opciones ofrecidas (`notes.reintento_s`); la historia queda colapsada | ALTA | `C05/derrota.txt`, captura M08 |
| J01 | J | Recorrido automático con victoria y con derrota por la escena real | P6-a: `humahuaca_playthrough.gd --level=scene` (12 semillas QA) y política `interfaz` (clics sobre «siguiente paso», 3 semillas) | sale con 0; ≥ 1 victoria del experto y ≥ 1 derrota con parte (el pasivo cae por `amanecio`); ≥ 2 aperturas distintas entre las victorias; ≥ 3 causas de derrota distintas en todo el material de QA; 0 excepciones; la política `interfaz` gana ≥ 1 de las 3 semillas en ≤ 3 intentos | BLOQUEA | `J01/scene.json`, `J01/ui.json` |
| J02 | J | Ciclo completo por la interfaz real y control del tiempo | P5-a (flujo del ciclo) y `test_hx_flow` | perfil limpio: menú → briefing → «Empezar» → derrota (por pasividad) → parte → «Reintentar» con el **mismo mundo** (`world_seed` igual) → victoria → medalla → epílogo fechado → «Seguir: Sostener el norte» habilitado; indicador permanente «TIEMPO REAL · ▶ ×1» o «‖ EN PAUSA»; Espacio pausa; F2, F3 y F4 (y +/−) fijan ×1, ×2 y ×4; la velocidad **nunca** cambia sola; pausa automática ≤ 2 s salvo decisiones (≤ 25 s) | BLOQUEA | `J02/ciclo.json` |
| J03 | J | Ritmo: siempre hay algo que decidir | P6-c: `qa_balance.py` (J03) sobre `hx_playthrough_v1` | en **todas** las partidas: primera decisión ≤ **60 s**; mayor brecha sin decisión posible ≤ **45 s**; mayor brecha durante el ataque ≤ **20 s**; existe el bot «pausa y reanuda» y cumple lo mismo | BLOQUEA | `J03/J_result.json` |
| J04 | J | Balance grueso con políticas imperfectas y 60 semillas nuevas | P6-b y P6-c: `qa_balance.py` (J04); auditoría de ceguera (P6-d) | experto, 1.er intento ≥ **80 %**; obediente, 1.er intento entre **10 %** y **60 %**; obediente gana en ≤ 5 intentos ≥ **75 %**; torpe, 1.er intento ≤ **40 %**; cada bot ciego ≤ **10 %**; pasivo y «pausa y reanuda» **0 %** (todas `amanecio`); escena real: experto ≥ 70 % en 12 semillas y obediente a ≤ 0,30 de lo medido en reglas; 0 semillas fuera de 9000–9999 y 0 semillas de QA en archivos de las pistas; obediente y torpe no leen estado oculto | BLOQUEA | `J04/J_result.json`, `J04/auditoria_ceguera.txt` |
| J05 | J | Balance fino: rangos del diseño ± 5 puntos | P6-c: `qa_balance.py` (J05) | experto ≥ **85 %**; obediente 1.er intento **20–45 %**; obediente 3.er intento (con diario, n ≥ 20) **55–85 %**; obediente gana en ≤ 5 intentos ≥ **85 %**; torpe 1.er intento **5–30 %** | ALTA | `J05/J_result.json` |
| J06 | J | Rejugabilidad: ninguna receta gana siempre | P6-c: `qa_balance.py` (J06) sobre la matriz de estrategias | ≥ 12 estrategias; ninguna concentra > **60 %** de las victorias; ninguna gana en > **80 %** de las semillas; ≥ 3 ganan en ≥ 50 %; ≥ 3 estrategias distintas son la mejor en ≥ 3 semillas cada una; cada valor de las 6 variantes aparece en ≥ 3 semillas de QA | BLOQUEA | `J06/J_result.json` |
| J07 | J | Duración y desenlaces | P6-c: `qa_balance.py` (J07) | victorias: mediana entre **11:00** y **13:00** y ≥ 90 % entre 10:00 y 14:00; derrotas del 1.er intento: mediana ≤ **8:00** y ninguna > 14:00; bajas: mediana de las victorias ≤ **55 %** y ≤ 15 % de victorias con bajas > 80 % | ALTA | `J07/J_result.json` |
| V01 | V | Las 12 capturas obligatorias y las 5 vistas canónicas muestran lo exigido | P7: capturas reales con ventana; los **tres** certificadores las miran una por una con `Read` y responden la lista del anexo B | las 12 existen, son reales (Godot sin `--headless`) y miden lo pedido; **cada ítem** de su lista es «sí»; las 5 vistas canónicas cumplen su lista a 1280×720 y a 1920×1080; decide la mayoría de los tres | ALTA | `V01/capturas/M01..M12*.jpg`, `V01/listas.md` |
| V02 | V | Cámara inicial: los tres objetivos y la zona de partida a la vista | P7: `qa_report.json.initial_frame` en 1280×720, 1920×1080 y 2560×1440 | `fits` verdadero; los 3 objetivos y la zona de partida con `on_screen` verdadero y a ≥ 5 % del borde; la captura inicial muestra relieve, núcleo y ≥ 1 objetivo (no «casi solo agua o suelo») | ALTA | `V02/initial_frame.json` |
| V03 | V | Las cinco fichas se leen sin depender del color | P7: `hoja_fichas.png` con `qa_imagen.py tokens`; `notes.token_px` | cada ficha ≥ **48 px** de alto a 1280×720 con el zoom por defecto; las 5 siluetas se distinguen (proporción > 0,15, relleno > 0,10 o IoU ≤ 0,70 en todos los pares); ninguna es un disco | ALTA | `V03/tokens.txt`, `V03/hoja_fichas.png` |
| V04 | V | Paleta del dossier: datos y muestreo en capturas | P7: `qa_imagen.py paleta` y `qa_imagen.py calib` | `palette` del JSON = los **24 HEX** de la lámina 06 y la lámina 06 los contiene exactos; 0 HEX sueltos en `props` y `tokens`; en las 3 vistas de calibración de día sin interfaz: mediana de distancia cromática ≤ **8**, p90 ≤ **14** y ≤ **3 %** de píxeles a > 22 | ALTA | `V04/paleta.txt`, `V04/calib.txt` |
| V05 | V | Marcadores de interfaz exactos y texto legible | P7: `qa_imagen.py markers` y `qa_imagen.py contraste` sobre `hx-hud` 1920×1080 | ≥ 50 px exactos (±3) de `#7FAAC4`, `#B99A50` y `#983F36`; contraste de texto ≥ **4,5:1** en 6 textos del HUD (re-medido) y `notes.contraste_texto_min` ≥ 4,5; ningún marcador imita una bandera (sin sol, sin cruz) | ALTA | `V05/markers.txt`, `V05/contraste.txt` |
| R01 | R | Ancla, ventana e hitos | P8: `qa_relieve.py` (R01) | ancla en (450, 325) con conversión lámina↔juego exacta (±0,01 m); ventana 900 × 650 m, malla 4 m (226 × 164); ancla −23,2041° / −65,3492°, ±15 m, etiqueta `razonado`; los 21 hitos obligatorios existen y cumplen 7 relaciones espaciales (batería al oeste a 100–170 m del templo, cuartel a ≤ 60 m, posta al este a 100–220 m, objetivos separados ≥ 80 m, vado y salida al este, entrada al sur, partidas al sudoeste) | ALTA | `R/R_result.json` |
| R02 | R | Los 41 puntos de la lámina 03 | P8: `qa_relieve.py` (R02) sobre el DEM **sin capas de diseño** | ≥ **37 de 41** a ≤ 12 m de la estimación; ninguno a > **20 m**; los 41 dentro de su banda de color ±8 m | BLOQUEA | `R/R_result.json` |
| R03 | R | Curvas de nivel de 20 m del juego = las de la lámina 03 (overlay generado) | P8: acuerdo de bandas de color + `overlay_lamina03.jpg` revisado por los tres | acuerdo de bandas: ventana ≥ **97 %** y dominio ≥ **95 %** con relieve `lamina03_reconstruida`; ≥ **75 %** y ≥ **70 %** con otra fuente (Copernicus, SRTM o paquete del usuario); el overlay no muestra tramos de curva a > 25 m de la lámina | ALTA | `R/overlay_lamina03.jpg`, `R/R_result.json` |
| R04 | R | Río Grande | P8: `qa_relieve.py` (R04) contra la traza azul de la lámina | ≥ 15 filas medidas; error medio ≤ **6 m**; máximo ≤ **12 m**; entra por el borde norte (z ≈ 0) y sale por el este (x = 900, z = 406 ± 12) | ALTA | `R/R_result.json` |
| R05 | R | Desnivel de 12 m (diseño rotulado) y alturas de referencia | P8: `qa_relieve.py` (R05); leyenda en pantalla | domo de la batería **12,0 ± 0,3 m** sobre el DEM; batería 14–19 m sobre la plaza; templo +17, cauce +12 y partida +27 m (± 10 m con la lámina, ± 3 m con DEM real); `report()` rotula `cerro_bateria` como `diseno`; el juego dice «dato actual, no restitución del suelo de 1817» (texto obligatorio nº 4 de H03) | ALTA | `R/R_result.json` |
| R06 | R | Terreno continuo y transitable | P8: `qa_relieve.py` (R06) y 4 capturas de cámara en el límite | salto de altura en el borde de la ventana ≤ **0,10 m**; las 5 partidas llegan a los 3 objetivos y al vado por la grilla de navegación; en las 4 capturas de cámara en el límite (ventana + 120 m) no hay huecos ni se ve el borde del mundo (mayoría de los tres) | ALTA | `R/R_result.json`, `R/limites_*.jpg` |
| H01 | H | Etiquetas honestas: nada inventado figura como documentado | P9-a: `qa_etiquetas.py` (anexo C.3) | 0 entidades con una etiqueta **más fuerte** que su techo; todo `tag` ∈ {documentado, razonado, discutido, diseno, sin_datos}; toda entidad con `tag_parts` tiene ≥ 2 partes y su `tag` es la más débil; los 21 hitos, las 5 agrupaciones y `refuerzo` tienen etiqueta; la leyenda (F1) muestra las 5 etiquetas | BLOQUEA | `H01/etiquetas.json` |
| H02 | H | Cero anacronismos graves | P9-b: `grep` con la lista A (anexo C.1) sobre cadenas, ids, nodos y modelos; capturas | 0 aciertos **ilegítimos** (cada acierto se clasifica: es legítimo si la misma cadena lo niega o lo fecha como posterior, o si está en un comentario o identificador); templo con `templo_aabb_h_m` ≤ **8,5** y sin torres de campanas; 0 nodos o recursos con nombres excluidos (monumento, poste, álamo, eucalipto, tendido, farol) | BLOQUEA | `H02/aciertos_A*.txt`, `H02/clasificacion.md` |
| H03 | H | Textos obligatorios, prohibidos y hechos verificados | P9-c: `grep` con la lista B y los 13 textos obligatorios (anexo C.2); 12 afirmaciones muestreadas con semilla fija | los **13** textos obligatorios presentes (anexo C.2); 0 aciertos ilegítimos de la lista B; de las 12 afirmaciones muestreadas, **0** contradicen el banco de hechos de `02_fuentes_primarias.md` (§f y §e.3); el refuerzo realista figura rotulado ▲ en pantalla | ALTA | `H03/obligatorios.txt`, `H03/hechos.md` |
| E01 | E | EXE armado desde el commit certificado, con SHA-256 | P10-a: `build_release.py`, `verify_embedded_version.gd`, `sha256sum`, `git diff --name-only` | existe **un** EXE en `entregas/<versión>/` de 100–200 MB; `VERIFICACION_EMBEBIDA OK`; SHA-256 y bytes coinciden en `sha256sum`, `SHA256.txt` y `VERSION.json`; entre `runtime_source_commit` y el commit certificado solo cambian `VERSION.json`, `README.md`, `CLAUDE.md`, `docs/**`, `evidence/**`; `config/version` = `VERSION.json.version` = carpeta de entrega y ≠ `0.3.0-alpha`; una reconstrucción desde el worktree termina con 0 y mide ±1 % de la entrega; `git ls-files '*.exe'` vacío | BLOQUEA | `E01/sha256_*.txt`, `E01/build-report.json`, `E01/verify.log` |
| E02 | E | El EXE corre el nivel de forma nativa en Windows, desde una carpeta vacía y con perfil limpio | P10-b: `PatriaGuemes.exe ... --qa=humahuaca`, `--scenario=humahuaca` con `--verbose`, `benchmark.py --binary` | el recorrido sale con 0 y escribe ≥ **5** PNG del tamaño pedido y `qa_report.json`; `--scenario=humahuaca` llega al briefing y sale con 0; cuadro medio del EXE ≤ **3,0 ms** y construcción ≤ 1500 ms; 0 errores y 0 fugas en sus logs | BLOQUEA | `E02/*.log`, `E02/qa_report.json`, `E02/bench_exe.json` |
| E03 | E | Documentos, créditos y versión al día | P11-a: `grep` y comparaciones | README y `project.godot` hablan de **tres** escenarios; `docs/CONTROLES.md` lista todas las teclas de `humahuaca_ui.json.key_table`; `docs/CREDITOS.md` contiene «OpenStreetMap» y «ODbL» y, según `meta.source`, el aviso de Copernicus («produced using Copernicus WorldDEM-30») o la cita de SRTM de NASA/USGS; `docs/ASSETS.md` lista los assets nuevos; `CLAUDE.md` incluye el nivel II | ALTA | `E03/docs.txt` |
| E04 | E | Evidencia completa, chica y trazable | P11-b | `evidence/humahuaca/` < **60 MB**; cada JPEG ≤ 300 KB; las 12 capturas obligatorias con `INDEX.json` (SHA-256 de los originales); cada criterio con su carpeta; todo commit desde `5a84c50` lleva el trailer `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` | MEDIA | `E04/evidencia.txt` |
| E05 | E | Seguridad e higiene de Git | P11-c | 0 archivos `.env*` o `jev.cfg` en el diff; 0 coincidencias de claves en el diff y en `evidence/humahuaca/`; `git remote -v` vacío; `git tag --list` = solo `v0.1.0`; sin `forced-update` en el reflog; ningún archivo versionado > 100 MB | BLOQUEA | `E05/seguridad.txt` |

**Dueño de cada dimensión** (a quién se le pasa el hallazgo): **T** y **E** → integrador; **C** → `ui_feel`; **J** → `reglas_historia` (con `ui_feel` en J02); **V** → `visual`; **R** → `relieve_mapa`; **H** → `reglas_historia` (etiquetas y textos) y `visual` (nombres de nodos y modelos).

**Escalera de exigencia.** Los umbrales **no cambian nunca**; solo cambia desde qué ronda un fallo se reporta como hallazgo. Antes de esa ronda el ítem se mide y se informa en la tabla de estado, sin generar hallazgo.

| Ronda | Se exige (un fallo es hallazgo) | Solo se informa |
|---|---|---|
| R0 (andamiaje) | T01, T02, E05 | T03 |
| R1 (corte vertical) | + T03, T04, T05, T06, T07, J01, J02, C01, R01, R02, R06, H01 | C03, J03, J04 |
| R2 (legibilidad y profundidad) | + T08, C03, C04, C05, J03, V01, V02, V03, R03, R04, R05, H02, H03 | J04–J07, V04, V05, C02, E03 |
| R3 (pulido visual y ritmo) | + J04, J05, J06, J07, V04, V05, C02, E03 | E01, E02, E04 |
| R4 (cierre y certificación) | **todos los 39** | — |

**Cómo se usa en el bucle.** *Cada ronda*, el Jefe de QA corre los procedimientos de los ítems exigibles esa ronda (con un solo certificador, el A), publica la tabla de estado de los 39 y **≤ 7 hallazgos**; las pistas corrigen y la ronda siguiente mide de nuevo. *La certificación* (los tres certificadores, los 39 ítems, un único commit) se convoca **solo** cuando una ronda deja en verde todo lo exigible; si falla, se vuelve a las rondas con la lista cerrada de hallazgos. Una ronda que no mueve ningún ítem de la tabla de estado no cuenta (diseño, sección 14).

---

## 3. Procedimientos de prueba

**Regla de oro:** un comando por tarea, esperar su línea final antes de leer resultados, **siempre con `timeout`** (un script de Godot con un error en `_initialize` queda colgado para siempre; se vio en la preparación de este documento) y **siempre con `APPDATA` aislado**. Las corridas con ventana (`ui_qa*`, capturas, benchmark, EXE) **no pueden correr a la vez** que otra cosa con ventana (el benchmark queda inválido). Shell: Git Bash. Ninguna prueba abre ni imprime `.env*` ni `jev.cfg`.

**Tiempos aproximados por certificador** (RTX 3080 Ti): P0 2 min · P1 ≈ 9 · P2 ≈ 8 · P3 ≈ 3 · P4 ≈ 8 · P5 ≈ 6 · P6 25–40 · P7 ≈ 6 · P8 ≈ 1 · P9 ≈ 3 · P10 ≈ 8 · P11 ≈ 1. En total ≈ 90 min; con los turnos de GPU de los tres, ≈ 2,5 h de reloj.

### P0 · Preparación (una vez por certificador y ronda)

```sh
export REPO="C:/Users/User/Desktop/spum/IA/Proyectos/MaravillaArgentina/guemes/patria-guemes"
export G="$REPO/.tools/godot/Godot_v4.7.2-stable_win64_console.exe"      # ruta absoluta: los worktrees no tienen .tools
export LAM="C:/Users/User/Desktop/spum/Maravilla Argentina/Justina_Retiro_1806_Paquete_Editable/info/2"   # láminas del usuario: solo lectura, no se copian al repo
export BASE=5ebbd28                                                       # línea base de la Justina y del Norte
export RONDA=r4 CERT=A                                                    # ronda que se certifica y certificador (A, B o C)
export T="$(cygpath -m "$TEMP")"
export REAL_APPDATA="$APPDATA"                                            # solo para leer las plantillas de exportación (P10); nunca se escribe ahí
export COMMIT="${COMMIT:-$(git -C "$REPO" rev-parse HEAD)}"               # el commit que se certifica: lo fija el Jefe de QA y es el MISMO para los tres certificadores
export SRC="$T/hx_cert_${RONDA}_${CERT}"                                  # worktree limpio de ese commit
git -C "$REPO" worktree add --detach "$SRC" "$COMMIT"
export APPDATA="$T/ap_iso_hx_${RONDA}_${CERT}"; rm -rf "$APPDATA"; mkdir -p "$APPDATA"
export EV="$REPO/evidence/humahuaca/$RONDA/qa/$CERT"                      # evidencia chica (texto y JPEG)
export RAW="$T/hx_qa_crudo/$RONDA/$CERT"                                  # PNG originales y salidas pesadas: fuera del repo
export QT="$RAW/qa_tools"; mkdir -p "$EV" "$RAW" "$QT"
"$G" --headless --path "$SRC" --import                                    # ≈ 9 s
sha256sum "$SRC/docs/QA_NIVEL2.md" | tee "$EV/rubrica_sha256.txt"        # la rúbrica que se aplica (va en el veredicto)

# Herramientas de QA: se extraen del anexo A de ESTE documento (así no las puede cambiar nadie sin una enmienda)
python -I - "$SRC/docs/QA_NIVEL2.md" "$QT" <<'EOF'
import re, sys, pathlib
doc = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"); out = pathlib.Path(sys.argv[2]); out.mkdir(parents=True, exist_ok=True)
for m in re.finditer(r"```(?:python|gdscript)\n# FILE: (\S+)\n(.*?)```", doc, re.S):
    (out / m.group(1)).write_text("# FILE: %s\n%s" % (m.group(1), m.group(2)), encoding="utf-8", newline="\n"); print("extraído", m.group(1))
EOF

# Ayudas de shell
run() { local n="$1"; shift; mkdir -p "$EV/${n%%_*}"; timeout "${TMO:-900}" "$@" > "$EV/${n%%_*}/$n.log" 2>&1; local c=$?; echo "$n exit=$c" | tee -a "$EV/exits.txt"; return $c; }
lastjson() { grep -E '^([A-Z_]+ )?\{' "$1" | tail -n 1 | sed -E 's/^[A-Z_]+ //'; }
suite() { lastjson "$1" | python -I -c "import sys,json;d=json.load(sys.stdin);print('checks=%s fallas=%d ok=%s'%(d.get('checks'),len(d.get('failures',[])),d.get('ok')))"; }
limpio() {   # debe imprimir NADA (criterio T05)
  find "$EV" -name '*.log' ! -name 'T07_guardado.log' -print0 | xargs -0 -r grep -nE '^(SCRIPT ERROR|SHADER ERROR|USER ERROR|Parse Error|ERROR:|FATAL|Segmentation|Assertion failed)'
  find "$EV" -name 'T07_guardado.log' -print0 | xargs -0 -r grep -nE '^(SCRIPT ERROR|SHADER ERROR|Parse Error)'
  find "$EV" -name '*.log' -print0 | xargs -0 -r grep -niE 'ObjectDB instances leaked|resources still in use at exit|Leaked instance|leaked at exit'
  grep -n 'exit=124' "$EV/exits.txt"
}
```

Cierre de cada certificación: `git -C "$REPO" worktree remove --force "$SRC"`.

### P1 · Compuerta técnica (T01, T02, T03, T05)

```sh
cd "$SRC"; mkdir -p "$EV/T01" "$EV/T02" "$EV/T03" "$EV/T05"
# P1-a (T01) protegidos y compartidos
PROT=$( (printf '%s\n' scripts/game_rules.gd scripts/world_view.gd scripts/campaign.gd scripts/audio_manager.gd scripts/jev_client.gd data/justina_map.json \
  tests/test_rules.gd tools/create_models.py tools/justina_playthrough.gd tools/vis_shots.gd tools/vis_r5.gd tools/bench_gpu.gd \
  shaders/terrain_justina_r4.gdshader shaders/water_rio_plata.gdshader
  git ls-tree -r --name-only $BASE -- shaders assets | grep -E '^(shaders/justina_|assets/[^/]+\.gdshader$|assets/models/[^/]+\.glb$)') | sort -u )
git diff --exit-code --stat $BASE HEAD -- $PROT > "$EV/T01/protegidos.txt"; echo "protegidos exit=$?"           # debe ser 0
git diff --numstat $BASE HEAD -- scripts/main.gd tests/test_integration.gd tools/ui_qa.gd tools/run_qa.py | tee "$EV/T01/numstat.txt"
git diff $BASE HEAD -- scripts/main.gd > "$EV/T01/main_gd.diff"                                                  # se lee entero
git log --format='%h %s' -- docs/QA_NIVEL2.md | tee "$EV/T01/enmiendas.txt"
git log --format=%s -- docs/QA_NIVEL2.md | sed '$d' | grep -vc '^QA enmienda [0-9]\+:'                         # debe imprimir 0
# P1-b (T02) regresión
TMO=600 run T02_rules "$G" --headless --path "$SRC" --script tests/test_rules.gd
run T02_integ "$G" --headless --path "$SRC" --script tests/test_integration.gd
run T02_jev   "$G" --headless --path "$SRC" --script tests/jev_contract_test.gd
run T02_audio "$G" --headless --path "$SRC" --script tests/audio_runtime_test.gd                                 # sale con 1: es la línea base
{ for f in T02_rules T02_integ T02_jev; do echo -n "$f "; suite "$EV/T02/$f.log"; done; grep -E '^(RESULTADO|FALLA):' "$EV/T02/T02_audio.log"; } | tee "$EV/T02/resumen.txt"
# P1-c (T03) suites nuevas
for t in data terrain rules view flow smoke; do TMO=900 run T03_$t "$G" --headless --path "$SRC" --script tests/test_hx_$t.gd; echo -n "T03_$t "; suite "$EV/T03/T03_$t.log"; done | tee "$EV/T03/resumen.txt"
lastjson "$EV/T03/T03_rules.log" | python -I -c "import sys,json;print(json.load(sys.stdin).get('performance'))" | tee -a "$EV/T03/resumen.txt"
# P1-d (T05) se corre AL FINAL de toda la certificación, cuando ya existen todos los logs:
limpio | tee "$EV/T05/limpio.txt"; echo "(vacío = pasa)"
```
Línea base medida el 1-nov-2026 en `5a84c50`: reglas 871/0 en 3 min 02 s; integración 283/0 en 11 s; Jev 15/0; audio «17 comprobaciones, 1 fallas» (driver Dummy), salida 1; `justina_playthrough` salida 0 en 5 min.

### P2 · Regresión por interfaz (T04) — una sola ventana por vez

```sh
for S in 1280x720 1920x1080 2560x1440; do
  mkdir -p "$RAW/uiqa_legacy/$S" "$EV/T04"
  run T04_uiqa_$S "$G" --path "$SRC" --resolution $S --audio-driver Dummy --script tools/ui_qa.gd -- --out="$RAW/uiqa_legacy/$S" --size=$S
  cp "$RAW/uiqa_legacy/$S/ui_qa_report.json" "$EV/T04/ui_$S.json"
done
TMO=900 run T04_jpt "$G" --path "$SRC" --resolution 1440x900 --audio-driver Dummy --script tools/justina_playthrough.gd -- --out="$EV/T04/justina-playthrough.json"
python -I - "$EV" <<'EOF'
import json, glob, sys
for f in sorted(glob.glob(sys.argv[1] + "/T04/ui_*.json")):
    d = json.load(open(f, encoding="utf-8")); n = d.get("notes", {}); print(f.split("/")[-1], "checks", d["checks"], "fallas", len(d["failures"]), "captura", n.get("captura_px"), "real", n.get("resolucion_real"))
p = json.load(open(sys.argv[1] + "/T04/justina-playthrough.json", encoding="utf-8"))
print("jpt: victorias", p["victories"], "estilos", len(p["victory_styles"]), "rutas", len(p["victory_routes"]), "derrotas", p["defeats"], "ui_real", p["ui_real_victory"])
EOF
```
`ui_qa.gd` **escribe en `res://evidence/...` por defecto**: pasarle siempre `--out=`.

### P3 · Rendimiento (T06) — nada más corriendo en la PC

```sh
mkdir -p "$EV/T06"
python "$SRC/tools/benchmark.py" --binary "$G" --project "$SRC" --output "$RAW/bench" --profiles media --scenarios justine,norte,humahuaca \
  --repeat 3 --renderer forward_plus --max-frame-ms 3 > "$EV/T06/bench.log" 2>&1; echo "benchmark exit=$?"          # debe ser 0
cp "$RAW/bench/resumen.json" "$EV/T06/"
python -I -c "import json;[print(x['scenario'],'media_de_medias',x['frame_ms_mean_mean'],'peor_media',x['frame_ms_mean_max'],'build_ms',x['scene_build_ms_mean']) for x in json.load(open('$EV/T06/resumen.json'))]"
```
**Regla de ruido (fijada de antemano):** si `justine` o `norte` pasan de 3,0 ms pero `T01` pasa (no se tocó nada suyo) y su media de medias es ≤ 3,0, se repite **una** vez ese escenario solo y vale el reintento. Humahuaca no tiene reintento.

### P4 · Guardado, robustez y determinismo (T07, T08)

```sh
mkdir -p "$EV/T07" "$EV/T08"
# P4-a independiente de las pistas (anexo A5)
run T07_guardado "$G" --headless --path "$SRC" --script "$QT/qa_guardado.gd" -- --out="$EV/T07/guardado.json"
# P4-b campaign.json no cambia: perfil con la Justina ganada, se corre el nivel unos segundos y se compara
UD="$(find "$APPDATA/Godot/app_userdata" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
printf '%s' '{"version":1,"world_seed":0,"diary":[],"attempts":1,"wins":1,"defeats_in_row":0,"defeats_total":0,"best_medal":"bronce","justina_won":true,"north_unlocked":true,"tutorial_seen":true,"last_cause":"","worlds":1,"checkpoint":{},"best_score":0,"objectives_done":[]}' > "$UD/campaign.json"
sha256sum "$UD/campaign.json" | tee "$EV/T07/campaign_sha.txt"
run T07_nivel "$G" --path "$SRC" --resolution 1280x720 --audio-driver Dummy --quit-after 900 -- --scenario=humahuaca --hx-skip-intro
sha256sum "$UD/campaign.json" | tee -a "$EV/T07/campaign_sha.txt"                                                 # las dos líneas deben ser iguales
# P4-c (T08) 200 partidas al azar y determinismo
TMO=1800 run T08_fuzz "$G" --headless --path "$SRC" --script tools/humahuaca_playthrough.gd -- --level=rules --policies=aleatorio --seeds=9101-9300 --attempts=1 --replicas=1 --out="$EV/T08/fuzz.json"
for i in 1 2; do TMO=1800 run T08_det$i "$G" --headless --path "$SRC" --script tools/humahuaca_playthrough.gd -- --level=rules --policies=experto,obediente,torpe --seeds=9001-9012 --attempts=3 --replicas=3 --out="$EV/T08/det$i.json"; done
python -I "$QT/qa_balance.py" --compare "$EV/T08/det1.json" "$EV/T08/det2.json" | tee "$EV/T08/determinismo.txt"
python -I -c "import json;d=json.load(open('$EV/T08/fuzz.json'))['games'];print('partidas',len(d),'excepciones',sum(g['exceptions'] for g in d),'invalidas',sum(1 for g in d if not g.get('valid',False)))" | tee -a "$EV/T08/determinismo.txt"
git -C "$SRC" status --porcelain | tee -a "$EV/T08/determinismo.txt"                                                 # al final de todo: debe quedar vacío
```
**Espejo:** el segundo certificador corre P4-c con **sus** corridas y compara su `det.json` con el del primero (`--compare`), que debe dar las mismas partidas con el mismo `snapshot_sha256` aunque corra en otro proceso y otro `APPDATA`.

### P5 · Interfaz del nivel (C01–C05, J02, T05) — una ventana por vez

```sh
mkdir -p "$EV/C01" "$EV/C02" "$EV/C03" "$EV/C04" "$EV/C05" "$EV/J02"
for S in 1280x720 1920x1080 2560x1440 1024x640; do
  mkdir -p "$RAW/uiqa_hx/$S"; ID=C01; [ "$S" = 1024x640 ] && ID=C02
  run ${ID}_uiqa_$S "$G" --path "$SRC" --resolution $S --audio-driver Dummy --script tools/ui_qa_humahuaca.gd -- --out="$RAW/uiqa_hx/$S" --size=$S
  cp "$RAW/uiqa_hx/$S/ui_qa_report.json" "$EV/$ID/ui_$S.json"
done
# P5-b / P5-a: lo que informa cada resolución
python -I - "$EV" <<'EOF'
import json, glob, sys
for f in sorted(glob.glob(sys.argv[1] + "/C0[12]/ui_*.json")):
    d = json.load(open(f, encoding="utf-8")); n = d.get("notes", {})
    print(f.split("/")[-1], "checks", d["checks"], "fallas", len(d["failures"]), "captura", n.get("captura_px"), "real", n.get("resolucion_real"),
          "| t0: controles", n.get("controles_t0"), "caracteres", n.get("caracteres_t0"), "jerga", n.get("jerga_hits_t0"),
          "| menu_y", n.get("menu_ultimo_y"), "| contraste_min", n.get("contraste_texto_min"), "| reintento_s", n.get("reintento_s"), "| ciclo", n.get("ciclo_completo"))
EOF
# evidencia chica del menú (C04)
mkdir -p "$EV/C04"; python -I "$QT/qa_imagen.py" jpg "$RAW/uiqa_hx/1280x720/hx-menu-nuevo.png" "$EV/C04/X01_menu_nuevo.jpg"; python -I "$QT/qa_imagen.py" jpg "$RAW/uiqa_hx/1280x720/hx-menu-desbloqueado.png" "$EV/C04/X02_menu_desbloqueado.jpg"
# P5-c el nivel directo, con --verbose (fugas al salir) y --scenario
run T05_directo "$G" --path "$SRC" --resolution 1280x720 --audio-driver Dummy --verbose --quit-after 900 -- --scenario=humahuaca --hx-skip-intro
# P5-d jerga: todas las cadenas visibles (JSON y literales de la interfaz) contra jargon_blacklist
python -I - "$SRC" <<'EOF' | tee "$EV/C03/jerga.txt"
import json, re, sys, pathlib, unicodedata
src = pathlib.Path(sys.argv[1]); fold = lambda s: "".join(c for c in unicodedata.normalize("NFD", s.lower()) if unicodedata.category(c) != "Mn")
bl = [fold(t) for t in json.load(open(src / "data/humahuaca_ui.json", encoding="utf-8")).get("jargon_blacklist", [])]
print("términos en la lista negra:", len(bl), "(mínimo 20)")
hits = []
def chk(texto, donde):
    f = fold(texto)
    for t in bl:
        if re.search(r"(?<!\w)" + re.escape(t) + r"(?!\w)", f): hits.append((donde, t, texto[:70]))
def walk(o, p):
    if isinstance(o, dict):
        for k, v in o.items():
            if k != "jargon_blacklist": walk(v, p + "." + k)
    elif isinstance(o, list):
        for i, v in enumerate(o): walk(v, "%s[%d]" % (p, i))
    elif isinstance(o, str) and " " in o: chk(o, p)
for f in ("humahuaca_rules", "humahuaca_ui", "humahuaca_visual"): walk(json.load(open(src / ("data/%s.json" % f), encoding="utf-8")), f)
for g in (src / "scripts/humahuaca/ui").glob("*.gd"):
    for m in re.finditer(r'"((?:[^"\\\n]|\\.)*)"', g.read_text(encoding="utf-8")):
        if " " in m.group(1): chk(m.group(1), g.name)
for h in hits: print("JERGA", h)
print("aciertos:", len(hits), "(debe ser 0)")
EOF
# C05: las causas de derrota del JSON (≥ 8, con texto ≤ 140 caracteres y consejo)
python -I - "$SRC" <<'EOF' | tee "$EV/C05/causas.txt"
import json, sys, pathlib
c = json.load(open(pathlib.Path(sys.argv[1]) / "data/humahuaca_rules.json", encoding="utf-8")).get("outcome", {}).get("causes", [])
items = list(c.values()) if isinstance(c, dict) else list(c)
campo = lambda e, ks: next((str(e[k]) for k in ks if k in e and str(e[k]).strip()), "")
largas = [i for i, e in enumerate(items) if len(campo(e, ("text", "texto", "cause", "causa"))) > 140]
sin = [i for i, e in enumerate(items) if not campo(e, ("text", "texto", "cause", "causa")) or not campo(e, ("advice", "consejo", "tip"))]
print("causas:", len(items), "(≥ 8) | con más de 140 caracteres:", largas, "| sin texto o sin consejo:", sin)
EOF
```
**Qué debe hacer `ui_qa_humahuaca` y qué debe informar** está en el anexo D (Q3). **J02** se verifica con `notes.ciclo_completo` (verdadero solo si pasó por todos los pasos del criterio, en un perfil limpio) y con `test_hx_flow`; el certificador mira además `hx-derrota` y `hx-victoria`.

### P6 · Simulación de balance y recorridos (J01, J03–J07, C05)

**Semillas reservadas al QA: 9000–9999.** Ninguna pista las usa, las publica ni las ve: 9001–9060 balance, 9101–9300 aleatorio (T08), 9301–9399 espejo. Los resultados por semilla **no se entregan a las pistas**: solo se informan las tasas agregadas.

```sh
mkdir -p "$EV/J01" "$EV/J03" "$EV/J04" "$EV/J05" "$EV/J06" "$EV/J07"
cd "$SRC"
# P6-a escena real (ventana): 12 semillas, y la política de interfaz (clics sobre «siguiente paso»)
TMO=1800 run J01_scene "$G" --path "$SRC" --resolution 1440x900 --audio-driver Dummy --script tools/humahuaca_playthrough.gd -- --level=scene \
  --policies=experto,obediente,torpe,pasivo,ciego_sin_recon --seeds=9001-9012 --attempts=3 --replicas=1 --out="$EV/J01/scene.json"
TMO=1200 run J01_ui "$G" --path "$SRC" --resolution 1440x900 --audio-driver Dummy --script tools/humahuaca_playthrough.gd -- --level=scene \
  --policies=interfaz --seeds=9001-9003 --attempts=3 --replicas=1 --out="$EV/J01/ui.json"
# P6-b reglas sin escena (headless, rápido): 60 semillas × 3 réplicas × hasta 5 intentos; y la matriz de estrategias
TMO=2400 run J04_bots "$G" --headless --path "$SRC" --script tools/humahuaca_playthrough.gd -- --level=rules \
  --policies=experto,obediente,torpe,ciego_sin_recon,ciego_tarde,ciego_un_frente,ciego_sin_arreo,pasivo,pausa_reanuda --seeds=9001-9060 --attempts=5 --replicas=3 --out="$EV/J04/reglas_bots.json"
TMO=2400 run J06_matriz "$G" --headless --path "$SRC" --script tools/humahuaca_playthrough.gd -- --level=rules \
  --policies=estrategias --seeds=9001-9060 --attempts=1 --replicas=1 --out="$EV/J06/reglas_matriz.json"
# P6-c agregación con los umbrales congelados (anexo A3)
python -I "$QT/qa_balance.py" --in "$EV/J04/reglas_bots.json" "$EV/J06/reglas_matriz.json" "$EV/J01/scene.json" "$EV/J01/ui.json" --out "$EV/J04" | tee "$EV/J04/J_resumen.txt"
for k in J03 J05 J06 J07; do mkdir -p "$EV/$k"; cp "$EV/J04/J_result.json" "$EV/$k/"; done
python -I - "$EV" <<'EOF'      # J01 y C05: causas de derrota y textos
import json, sys, re
g = []
for f in ("J04/reglas_bots.json", "J06/reglas_matriz.json", "J01/scene.json", "J01/ui.json"): g += json.load(open(sys.argv[1] + "/" + f, encoding="utf-8"))["games"]
dv = [x for x in g if x["status"] == "defeat"]; causas = {x["cause_id"] for x in dv}
print("causas distintas:", sorted(causas), "(≥ 3)")
mal = [x for x in dv if x.get("cause_text") and (len(x["cause_text"]) > 140 or not re.search(r"\d+:\d\d", x["cause_text"]))]
print("cause_text sin momento o > 140 caracteres:", len(mal), "de", sum(1 for x in dv if x.get("cause_text")), "(debe ser 0)")
print("aperturas distintas entre victorias:", len({x["opening"] for x in g if x["status"] == "victory" and x["policy"] != "pasivo"}), "(≥ 2)")
ui = json.load(open(sys.argv[1] + "/J01/ui.json", encoding="utf-8"))["games"]
print("política interfaz: semillas con victoria:", len({x["seed"] for x in ui if x["status"] == "victory"}), "de", len({x["seed"] for x in ui}), "(≥ 1)")
EOF
# P6-d auditoría de ceguera y de integridad de semillas
git grep -nE 'true_value|state\.world|\.garrison|state\.recon|rumors' -- tools/humahuaca_playthrough.gd tests/test_hx_rules.gd | tee "$EV/J04/auditoria_ceguera.txt"
git grep -noEi '(seed|semilla)[^0-9]{0,16}9[0-9]{3}\b' -- 'tests/test_hx_*.gd' tools/humahuaca_playthrough.gd tools/hx_qa_tour.gd tools/ui_qa_humahuaca.gd tools/vis_humahuaca.gd 'data/humahuaca_*.json' scripts/humahuaca | tee "$EV/J04/semillas_en_pistas.txt"   # debe quedar vacío
```
**Auditoría de ceguera (a mano, 10 min):** el certificador lee cada acierto de `auditoria_ceguera.txt`. Un acierto dentro de las políticas `experto` es válido. Un acierto dentro de `obediente`, `torpe`, `ciego_*`, `pausa_reanuda`, `pasivo`, `aleatorio` o `interfaz` que lea esos datos **para decidir** (no para medir) es un **defecto objetivo ALTA** («bot con información perfecta»: la lección del nivel 1).

**Espejo:** el segundo certificador repite P6-b con `--seeds=9001-9012` y exige el mismo `snapshot_sha256` en las partidas comunes (`qa_balance.py --compare`) y tasas dentro de ±0,10 de las del primero en esas 12 semillas.

### P7 · Capturas reales (V01–V05, R06) — Godot **sin** `--headless`

```sh
mkdir -p "$EV/V01/capturas" "$EV/V02" "$EV/V03" "$EV/V04" "$EV/V05" "$EV/R"
for S in 1280x720 1920x1080 2560x1440; do
  mkdir -p "$RAW/tour/$S"
  run V01_tour_$S "$G" --path "$SRC" --resolution $S --audio-driver Dummy -- --qa=humahuaca --qa-path="$RAW/tour/$S" --qa-size=$S
done
python -I - "$RAW/tour" "$EV" <<'EOF'      # tamaño real de cada PNG y claves de qa_report.json
import sys, glob, json
from PIL import Image
for S in ("1280x720", "1920x1080", "2560x1440"):
    W, H = [int(v) for v in S.split("x")]; malos = [p for p in glob.glob("%s/%s/*.png" % (sys.argv[1], S)) if Image.open(p).size != (W, H) and "hoja_fichas" not in p]
    r = json.load(open("%s/%s/qa_report.json" % (sys.argv[1], S), encoding="utf-8"))
    print(S, "PNG:", len(glob.glob("%s/%s/*.png" % (sys.argv[1], S))), "de tamaño distinto:", len(malos), "| initial_frame.fits:", r.get("initial_frame", {}).get("fits"),
          "| objetivos en pantalla:", [t.get("on_screen") for t in r.get("initial_frame", {}).get("targets", [])], "| templo_aabb_h_m:", r.get("templo_aabb_h_m"))
    json.dump(r.get("initial_frame", {}), open("%s/V02/initial_frame_%s.json" % (sys.argv[2], S), "w"), indent=1)
EOF
# evidencia chica: las 12 obligatorias (anexo B), las 5 vistas a 1280×720 y las 4 de límite de cámara, a JPEG ≤ 300 KB, con el índice de SHA-256 de los originales
while read -r ORIG DST; do python -I "$QT/qa_imagen.py" jpg "$RAW/$ORIG" "$EV/V01/capturas/$DST"; done <<'EOF'
tour/1920x1080/vista_acceso_so.png M01_llegada_nocturna.jpg
uiqa_hx/1920x1080/hx-aproximacion-lluvia.png M02_aproximacion_lluvia.jpg
tour/1920x1080/vista_desde_bateria.png M03_desde_bateria.jpg
tour/1920x1080/vista_patio_posta.png M04_patio_posta.jpg
tour/1920x1080/vista_grupos_en_accion.png M05_torre.jpg
uiqa_hx/1920x1080/hx-extraccion.png M06_extraccion.jpg
tour/1920x1080/vista_panorama_alto.png M07_alba.jpg
uiqa_hx/1280x720/hx-derrota.png M08_derrota.jpg
uiqa_hx/1280x720/hx-victoria.png M09_victoria.jpg
uiqa_hx/1280x720/hx-hud.png M10_hud_1280x720.jpg
uiqa_hx/1920x1080/hx-hud.png M11_hud_1920x1080.jpg
uiqa_hx/2560x1440/hx-hud.png M12_hud_2560x1440.jpg
tour/1280x720/vista_acceso_so.png V1280_acceso_so.jpg
tour/1280x720/vista_desde_bateria.png V1280_desde_bateria.jpg
tour/1280x720/vista_patio_posta.png V1280_patio_posta.jpg
tour/1280x720/vista_grupos_en_accion.png V1280_grupos_en_accion.jpg
tour/1280x720/vista_panorama_alto.png V1280_panorama_alto.jpg
EOF
for L in n s e o; do python -I "$QT/qa_imagen.py" jpg "$RAW/tour/1920x1080/limite_$L.png" "$EV/R/limites_$L.jpg"; done
python -I - "$RAW" "$EV/V01/capturas/INDEX.json" <<'EOF'
import hashlib, json, glob, sys, os
idx = {os.path.relpath(p, sys.argv[1]).replace("\\", "/"): hashlib.sha256(open(p, "rb").read()).hexdigest() for p in glob.glob(sys.argv[1] + "/tour/*/*.png") + glob.glob(sys.argv[1] + "/uiqa_hx/*/hx-*.png")}
json.dump(idx, open(sys.argv[2], "w"), indent=1); print("índice:", len(idx), "originales")
EOF
# V03 fichas / V04 paleta / V05 marcadores y contraste
python -I "$QT/qa_imagen.py" tokens "$RAW/tour/1280x720/hoja_fichas.png" | tee "$EV/V03/tokens.txt"
python -I "$QT/qa_imagen.py" paleta --lamina06 "$LAM/06_paletas.png" --visual "$SRC/data/humahuaca_visual.json" | tee "$EV/V04/paleta.txt"
python -I "$QT/qa_imagen.py" calib "$RAW/tour/1920x1080/calib_inicial.png" "$RAW/tour/1920x1080/calib_patio_posta.png" "$RAW/tour/1920x1080/calib_grupos.png" | tee "$EV/V04/calib.txt"
python -I "$QT/qa_imagen.py" markers "$RAW/uiqa_hx/1920x1080/hx-hud.png" --need celeste,oro,borgona | tee "$EV/V05/markers.txt"
RECTS="$(python -I -c "import json;r=json.load(open('$RAW/uiqa_hx/1920x1080/ui_qa_report.json',encoding='utf-8'))['notes']['rects'];print(';'.join(','.join(str(int(v)) for v in r[k]) for k in ('titulo','objetivo','siguiente','frente_bateria','alerta','accion_1')))")"
python -I "$QT/qa_imagen.py" contraste "$RAW/uiqa_hx/1920x1080/hx-hud.png" --rects "$RECTS" | tee "$EV/V05/contraste.txt"
```
**Cómo se captura con ventana.** Siempre sin `--headless`, con `--resolution WxH --audio-driver Dummy` y, para 1920×1080 y 2560×1440 en monitores de 1080p, la ventana sin bordes que fijan `--qa-size` y `--size` (la captura es del viewport y se **verifica el tamaño del PNG**; una captura de otro tamaño es N). Los PNG originales se quedan en `$RAW` (fuera de Git); a `evidence/` solo van JPEG ≤ 300 KB con `qa_imagen.py jpg`. Cada certificador abre **cada** captura obligatoria con `Read` y deja constancia («visto») en `V01/listas.md`; «no la miré» es N.

### P8 · Relieve contra la lámina 03 (R01–R06)

```sh
mkdir -p "$EV/R"
timeout 300 "$G" --headless --path "$SRC" --script "$QT/qa_relieve.gd" -- --out="$EV/R/dump.json"
python -I "$QT/qa_relieve.py" --dump "$EV/R/dump.json" --lamina "$LAM/03_relieve_actual.png" --map "$SRC/data/humahuaca_map.json" --out "$EV/R" | tee "$EV/R/resumen.txt"
```
El volcado usa solo la API del contrato (`HumahuacaTerrain`, sección 3.1). El script compara con los píxeles de la lámina (curvas por color de banda, río por la traza azul, marco rojo de la ventana) y escribe `R_result.json` y el **overlay** `overlay_lamina03.jpg`: curvas de 20 m del juego en magenta, río del juego en naranja, ventana en cian, ancla y domo en verde y los 41 puntos coloreados por error. Los tres certificadores **miran el overlay** (R03) y las 4 capturas de cámara en el límite (R06). Calibración de la lámina verificada sobre sus píxeles: x = 0 ↔ píxel 1018,5; N = 0 ↔ píxel 1122,5; 0,4743 px/m (el marco rojo de la ventana cae a −452/+456 m en x y ±330 m en N con el grosor de su línea, y la traza del río cruza N = 0 a 406 m).

### P9 · Historia, etiquetas y anacronismos (H01–H03)

```sh
cd "$SRC"; mkdir -p "$EV/H01" "$EV/H02" "$EV/H03"
python -I "$QT/qa_etiquetas.py" --data "$SRC/data" --out "$EV/H01/etiquetas.json" | tee "$EV/H01/resumen.txt"
# P9-b anacronismos graves (lista A del anexo C.1: variable PAT_A) sobre cadenas, código, historia nueva y nombres de nodos y modelos
PAT_A='(monumento|escalinata|h(e|é)roes de la independencia)|(torres? de campanas?|campanarios?|dos torres|fachada (actual|neocl(a|á)sica|de 188[01]))|(bandera (argentina|nacional)|sol de mayo|sol en la bandera|bandera con sol|bandera del sol)|(cruz de borgo(ñ|n)a|bandera espa(ñ|n)ola)|(coronel mayor|general g(ü|u)emes|chaqueta azul|h(ú|u)sar)|((san mart(í|i)n|g(ü|u)emes) (dirig|lider|comand|encabez|orden(ó|o)|mand(ó|o)|asalt))|(orden t(á|a)ctica|consecuencia de chacabuco|chacabuco hizo retirar)|(infernales)|(expulsi(ó|o)n definitiva|expulsados? para siempre|victoria definitiva|fin de la invasi(ó|o)n)|((á|a)lamos? pir(a|á)mid|eucalipt|postes?\b|tendidos?\b|alumbrado|farol(es)?\b|asfalto|empedrad|adoqu(i|í)n)|(ruta (9|nacional)|ferrocarril|telegraf|alambrad|autom(ó|o)vil|tractor|luz el(é|e)ctrica)'
grep -rnEi "$PAT_A" data/humahuaca_map.json data/humahuaca_rules.json data/humahuaca_ui.json data/humahuaca_visual.json scripts/humahuaca > "$EV/H02/aciertos_A.txt"
git diff -U0 $BASE HEAD -- data/history.json | grep -E '^\+' | grep -Ei "$PAT_A" > "$EV/H02/aciertos_A_history.txt"
{ grep -Ei "$PAT_A" "$RAW/tour/1920x1080/scene_names.txt"; ls -R assets/models/humahuaca 2>/dev/null | grep -Ei "$PAT_A"; } > "$EV/H02/aciertos_A_nodos.txt"
wc -l "$EV"/H02/aciertos_A*.txt
# P9-c textos obligatorios y prohibidos (anexo C.2) y 12 hechos muestreados con semilla fija
PAT_B='(todos (los )?(infernales|de rojo|de blanco)|uniformes? (rojos?|blancos?|homog(é|e)neos?))|(tormenta (durante|todo|toda)|llov(í|i)a (todo|durante todo))|(ruta final de arias|paso de zenta|garc(í|i)a camba)|(cabildo|premio de humahuaca)'
grep -rnEi "$PAT_B" data/humahuaca_rules.json data/humahuaca_ui.json scripts/humahuaca/ui > "$EV/H03/aciertos_B.txt"
python -I - "$SRC" <<'EOF' | tee "$EV/H03/obligatorios.txt"
import re, sys, pathlib
t = " ".join((pathlib.Path(sys.argv[1]) / ("data/humahuaca_%s.json" % n)).read_text(encoding="utf-8") for n in ("rules", "ui"))
OBL = {"carta del 26-II como dramatización": r"dramatizaci(ó|o)n", "nota de fecha 1 o 2 de marzo": r"2 de marzo", "el refuerzo no ocurrió o es diseño": r"no hubo refuerzo|refuerzo[^\"]{0,80}dise(ñ|n)o|dise(ñ|n)o[^\"]{0,80}refuerzo",
       "el relieve es dato actual": r"dato actual|no restituci(ó|o)n", "epílogo 3 de marzo": r"3 de marzo", "epílogo 9 al 16 de marzo": r"9 al 16 de marzo", "epílogo 6 de julio": r"6 de julio",
       "botón Seguir: Sostener el norte": r"Sostener el norte", "etiqueta Documentado": r"Documentado", "etiqueta Inferencia razonada": r"Inferencia razonada", "etiqueta Versión discutida": r"Versi(ó|o)n discutida",
       "etiqueta Sin datos suficientes": r"Sin datos suficientes", "Güemes recibe el parte en Salta": r"g(ü|u)emes[^\"]{0,120}(recibe|recibi(ó|o))[^\"]{0,60}parte|parte[^\"]{0,120}g(ü|u)emes"}
falta = [k for k, p in OBL.items() if not re.search(p, t, re.I)]
print("obligatorios presentes: %d de %d" % (len(OBL) - len(falta), len(OBL)), "| faltan:", falta)
EOF
python -I - "$SRC" <<'EOF' | tee "$EV/H03/hechos.md"      # 12 afirmaciones muestreadas con semilla fija 9317: el certificador las coteja con 02_fuentes_primarias.md §f y §e.3
import json, random, sys, pathlib
src = pathlib.Path(sys.argv[1]); cand = []
def walk(o, p):
    if isinstance(o, dict):
        for k, v in o.items(): walk(v, p + "." + k)
    elif isinstance(o, list):
        for i, v in enumerate(o): walk(v, "%s[%d]" % (p, i))
    elif isinstance(o, str) and len(o) >= 60 and " " in o: cand.append((p, o))
for n in ("rules", "ui"): walk(json.load(open(src / ("data/humahuaca_%s.json" % n), encoding="utf-8")), n)
random.Random(9317).shuffle(cand)
for p, o in cand[:12]: print("- `%s`: «%s» → coincide / contradice / sin fuente" % (p, o[:200]))
EOF
```
**Clasificación de aciertos (a mano).** Cada línea de `aciertos_A*.txt` y `aciertos_B.txt` se anota en `clasificacion.md` como **legítimo** (la misma cadena lo niega, o lo fecha como posterior —por ejemplo «sin torres de 1880»—, o está en un comentario o identificador de código) o **anacronismo**. Un solo anacronismo hace fallar H02 (lista A) o H03 (lista B).

### P10 · Entrega (E01, E02)

```sh
cd "$SRC"; mkdir -p "$EV/E01" "$EV/E02"
VER="$(sed -n 's/^config\/version="\(.*\)"$/\1/p' project.godot)"; DEST="$REPO/../entregas/$VER"
# P10-a reconstrucción desde el worktree (no pisa la entrega) y verificación de la entrega
run E01_build python tools/build_release.py --godot "$G" --templates "$REAL_APPDATA/Godot/export_templates/4.7.2.stable"
cp "$SRC"/builds/logs/*/build-report.json "$EV/E01/"
EXE_NUEVO="$SRC/builds/windows/PatriaGuemes.exe"; EXE="$(ls "$DEST"/*.exe | head -n 1)"; ls "$DEST"/*.exe | wc -l                         # debe ser 1
sha256sum "$EXE" "$EXE_NUEVO" | tee "$EV/E01/sha256_exes.txt"; stat -c '%s %n' "$EXE" "$EXE_NUEVO" | tee "$EV/E01/bytes.txt"
cat "$DEST/SHA256.txt"; python -I -c "import json;d=json.load(open('VERSION.json'));print({k:d.get(k) for k in ('version','runtime_source_commit','windows_bytes','windows_sha256')})"
RC="$(python -I -c "import json;print(json.load(open('VERSION.json'))['runtime_source_commit'])")"
git diff --name-only $RC HEAD | grep -vE '^(VERSION.json|README.md|CLAUDE.md|docs/|evidence/)' | tee "$EV/E01/cambios_runtime.txt"             # debe quedar vacío
run E01_verify "$G" --headless --path "$SRC" --script tools/verify_embedded_version.gd -- --pack="$EXE" --commit="$(git rev-parse "$RC")"
git ls-files '*.exe'                                                                                                              # debe quedar vacío
# P10-b la entrega corre sola, nativa en Windows, desde una carpeta vacía y con perfil limpio
mkdir -p "$T/exe_vacia"; cp "$EXE" "$T/exe_vacia/PatriaGuemes.exe"; export APPDATA="$T/ap_iso_exe_${RONDA}_${CERT}"; rm -rf "$APPDATA"; mkdir -p "$APPDATA" "$RAW/exe_tour"
run E02_tour "$T/exe_vacia/PatriaGuemes.exe" --resolution 1920x1080 --audio-driver Dummy -- --qa=humahuaca --qa-path="$RAW/exe_tour" --qa-size=1920x1080
run E02_directo "$T/exe_vacia/PatriaGuemes.exe" --resolution 1280x720 --audio-driver Dummy --verbose --quit-after 900 -- --scenario=humahuaca --hx-skip-intro
python "$SRC/tools/benchmark.py" --binary "$T/exe_vacia/PatriaGuemes.exe" --output "$RAW/bench_exe" --profiles media --scenarios humahuaca --repeat 1 --renderer forward_plus --max-frame-ms 3 > "$EV/E02/bench_exe.log" 2>&1; echo "bench exe exit=$?"
cp "$RAW/bench_exe/resumen.json" "$EV/E02/bench_exe.json"; cp "$RAW/exe_tour/qa_report.json" "$EV/E02/"; ls "$RAW/exe_tour"/*.png | wc -l                         # ≥ 5
export APPDATA="$T/ap_iso_hx_${RONDA}_${CERT}"
```
El EXE **no se reconstruye para entregarlo**: se verifica el que dejó el integrador. La reconstrucción desde el worktree solo prueba que el commit se puede exportar. La exportación **no es reproducible bit a bit**: se compara el tamaño (±1 %), no el hash.

### P11 · Documentos, evidencia y seguridad (E03, E04, E05)

```sh
cd "$SRC"; mkdir -p "$EV/E03" "$EV/E04" "$EV/E05"
# E03
{ grep -c -i 'tres escenarios\|tres momentos' README.md; grep -c -i 'dos escenarios' README.md project.godot
  python -I - <<'EOF'
import json, re, pathlib
keys = json.load(open("data/humahuaca_ui.json", encoding="utf-8")).get("key_table", []); doc = pathlib.Path("docs/CONTROLES.md").read_text(encoding="utf-8")
falta = [k for k in keys if str(k.get("tecla", k.get("key", ""))).lower() not in doc.lower()]
print("teclas de key_table:", len(keys), "| sin documentar en CONTROLES.md:", [str(k)[:50] for k in falta])
EOF
  grep -c 'OpenStreetMap' docs/CREDITOS.md; grep -c 'ODbL' docs/CREDITOS.md; grep -ci 'Copernicus WorldDEM-30\|NASA/USGS' docs/CREDITOS.md; grep -ci 'humahuaca' docs/ASSETS.md CLAUDE.md; } | tee "$EV/E03/docs.txt"
# E04
{ du -sm "$REPO/evidence/humahuaca" | cut -f1; find "$REPO/evidence/humahuaca" -name '*.jpg' -size +300k; ls "$EV/V01/capturas" | wc -l
  git log --format='%H' 5a84c50..HEAD | while read c; do git show -s --format=%B "$c" | grep -q 'Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>' || echo "SIN TRAILER $c"; done; } | tee "$EV/E04/evidencia.txt"
# E05
{ git diff --name-only $BASE HEAD | grep -E '(^|/)(\.env|jev\.cfg)'
  git diff -U0 $BASE HEAD | grep -E '^\+' | grep -nE "sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|(api[_-]?key|secret|token|password)[\"']?[[:space:]]*[:=][[:space:]]*[\"'][^\"']{12,}"
  grep -rnE "sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|(api[_-]?key|secret|token|password)[\"']?[[:space:]]*[:=][[:space:]]*[\"'][^\"']{12,}" "$REPO/evidence/humahuaca" --include='*.txt' --include='*.json' --include='*.log' --include='*.md'
  git -C "$REPO" remote -v; git -C "$REPO" tag --list; git -C "$REPO" reflog | grep -i 'forced-update'
  git ls-files -z | xargs -0 -r ls -l 2>/dev/null | awk '$5 > 104857600 {print "GRANDE", $9}'; } | tee "$EV/E05/seguridad.txt"      # solo debe aparecer «v0.1.0» en la lista de tags
```

### P12 · Veredicto

Cada certificador escribe `VEREDICTO.md` y `veredicto.json` (sección 6) en su carpeta. El Jefe de QA fusiona los duplicados en `hallazgos_consolidados.json` (≤ 7, sin BAJA) y consolida:

```sh
Q="$REPO/evidence/humahuaca/$RONDA/qa"
python -I "$QT/qa_veredicto.py" --doc "$SRC/docs/QA_NIVEL2.md" --in "$Q/A/veredicto.json" "$Q/B/veredicto.json" "$Q/C/veredicto.json"   --hallazgos "$Q/hallazgos_consolidados.json" --out "$REPO/evidence/humahuaca/$RONDA/VEREDICTO_FINAL.md"
```

---

## 4. Reglas para los certificadores (no mover los postes)

1. **Solo cuenta lo que está escrito.** Un hallazgo es ALTA o BLOQUEA únicamente si es un **ítem de la rúbrica** que falla o un **defecto objetivo con evidencia**. *Defecto objetivo* = (a) crash o cuelgue; (b) error de consola (`SCRIPT ERROR`, `SHADER ERROR`, `Parse Error`, `ERROR:`) o fuga de ObjectDB; (c) solape o recorte **medido** (rectángulo fuera del viewport o intersección de paneles); (d) ilegible **medido** (texto < 4,5:1, ficha < 48 px, texto cortado); (e) anacronismo de la lista A o B; (f) bug de guardado o de carga (el round-trip cambia el estado, un guardado inválido se acepta); (g) regresión (cualquier línea base a la baja); (h) bot con información perfecta fuera del experto.
2. **El gusto no bloquea.** «Preferiría otro color», «podría ser más épico», «el río me parece feo» son MEDIA o BAJA como máximo. **BAJA** va al `docs/humahuaca/BACKLOG.md` y no cuenta para nada; **MEDIA** cuenta contra el tope de 3. Cada certificador puede registrar como máximo **3 MEDIA** por ronda.
3. **Sin evidencia no hay hallazgo.** Cada hallazgo trae: id `H-<ronda>-<n>`, ítem de la rúbrica o tipo de defecto objetivo, severidad, **ruta de la captura, del archivo o del comando con la línea o el valor medido**, cómo reproducirlo, pista dueña y una **prueba de aceptación** de una frase que se pueda correr. Lo que no cumple eso se descarta.
4. **No se reabre una limitación aceptada** (sección 5) **ni un hallazgo cerrado** con evidencia posterior. Solo se reabre por **regresión demostrada**: la misma prueba de aceptación vuelve a fallar.
5. **Postes fijos.** Nadie agrega ítems ni cambia umbrales. La rúbrica solo cambia por **enmienda** (anexo F), y solo si (i) hay un **error demostrable** en la rúbrica o en una herramienta de medición (con evidencia), o (ii) el integrador o el arquitecto cambiaron el diseño o el contrato por *addendum* fechado. Una enmienda **nunca endurece** un umbral por una observación nueva; la escribe y commitea el Jefe de QA con título «QA enmienda N: …», sube la versión (1.1, 1.2…) y se avisa a las tres pistas. Los certificadores no editan este documento ni las herramientas del anexo A.
6. **Presupuesto.** Por ronda, la lista de trabajo tiene **≤ 7 hallazgos**: primero BLOQUEA, después ALTA, después MEDIA, en orden de ID; los duplicados se fusionan; el resto de los ítems fallidos queda en la tabla de estado (los 39, con pasa / falla / N / no exigible aún). Un hallazgo se cierra con evidencia de una ronda posterior.
7. **Independencia.** Los tres certificadores corren con su **propio** `APPDATA`, worktree y carpeta de evidencia, y **no leen el veredicto de otro** hasta entregar el suyo.
8. **Honestidad.** No se declara una prueba que no se corrió; no se infiere del código lo que se puede medir; «no vi la captura» y «no corrió la herramienta» son **N**, y N falla.
9. **Mirar las capturas.** Cada certificador abre las 12 capturas obligatorias, el overlay y las 4 capturas de límite de cámara con `Read`, una por una, y lo declara.
10. **Seguridad.** No abrir ni imprimir `.env*` ni `jev.cfg`. Si una captura o un log muestra una clave, se informa como BLOQUEA (E05) y se borra el archivo antes de commitear.
11. **Solo lectura sobre el proyecto.** Los certificadores no editan nada del repo salvo `evidence/humahuaca/<ronda>/qa/<CERT>/`. Los textos van en español rioplatense, con títulos de hallazgo ≤ 140 caracteres.

---

## 5. Limitaciones aceptadas de antemano y regla de decisión

Estas limitaciones **no son hallazgos** y no se reabren. Cada una dice qué sí se sigue verificando para que no esconda un defecto.

| # | Limitación aceptada | Qué sí se verifica igual |
|---|---|---|
| L1 | **Sin prueba humana**: nadie juega a mano en este circuito. El balance y la claridad se miden con bots y con proxies (J04–J07, C03). | El veredicto lleva siempre el sello «PRESENTABLE, no certificado por humanos». La sesión de 20 minutos del anexo E es opcional y es lo único que puede quitar el sello. |
| L2 | **Sin Jev vivo** (no hay clave autorizada; el mando realista usa la alternativa local determinista, D4). | `jev_contract_test` 15/0 y que `enemy_*` conserve la forma del Norte (T02). Nadie abre `jev.cfg`. |
| L3 | **Audio**: el driver Dummy hace fallar 1 comprobación de `audio_runtime_test`; nadie escucha el audio. | Esa **única** falla y 17 o más comprobaciones (T02); que el audio del nivel no produzca errores (T05). La calidad audible no se evalúa. |
| L4 | **Geometría de edificios, torre, posta, casa del cura, tapias, zanjas, planta del pueblo, reparto de los 150 y vestuario = diseño** (▲ u ○): no existe planta ni documento de 1817. | Que estén **rotulados** como diseño (H01) y que no haya anacronismos (H02); no se discute su fidelidad. |
| L5 | **El relieve es dato actual** (lámina 03, SRTM o Copernicus), no restitución del suelo de 1817, con ±10 m (lámina) o ±5 m (DEM real). Los 12 m de la batería son diseño del prototipo. | Que coincida con la lámina dentro de los umbrales (R01–R06) y que el juego lo diga (R05). |
| L6 | **Hardware único**: RTX 3080 Ti, Windows 11, dos monitores de 1920×1080; 2560×1440 se captura en ventana sin bordes. No se prueba en equipos modestos, con otras GPU ni con V-Sync activo. | El tamaño real de cada captura (C01) y el presupuesto de 3 ms en esta PC (T06). |
| L7 | **Material del usuario ausente**: dossier de 52 páginas, paquete editable de 39 archivos, láminas 01, 04 y 05, tabla de 23 elementos y 16 fichas. La planta del prototipo es diseño rotulado; si llega material, se corrige por *addendum*. | Que nada inventado figure como documentado (H01). |
| L8 | **`treat_warnings_as_errors=false`**: los *warnings* de GDScript no rompen las pruebas y no cuentan salvo que el certificador demuestre un defecto objetivo asociado. | Los `SCRIPT ERROR`, `SHADER ERROR` y `Parse Error` sí cuentan (T05). |
| L9 | **Movie Maker** (`--write-movie`) deja 4 instancias de ObjectDB al salir. Si algún video se graba así, esas 4 no cuentan. | Ninguna corrida de las de la sección 3 usa Movie Maker. |
| L10 | **La exportación no es reproducible bit a bit** y no se prueba en Wine (se corre nativa en Windows). | Tamaño ±1 %, `verify_embedded_version.gd` y el SHA-256 de la entrega (E01). |
| L11 | **D1a**: Humahuaca se abre con la Justina ganada (el Norte, igual que hoy). Reencadenar Justina → Humahuaca → Norte (D1b) cuesta 6 comprobaciones fijadas y queda fuera de este ciclo. | El candado en las dos direcciones y `--scenario=humahuaca` (C04). |

**Regla de decisión.** El veredicto consolidado es:

- **PRESENTABLE (no certificado por humanos)** ⇔ **todos los BLOQUEA pasan** ∧ **0 ALTA abiertas** ∧ **≤ 3 MEDIA abiertas, cada una con su razón escrita** (campo `razon_aceptada` del hallazgo, firmado por el Jefe de QA) ∧ la rúbrica corrió **completa sobre un único commit** ∧ los tres certificadores usaron el mismo `rubrica_sha256` y el mismo `commit`.
- **NO PRESENTABLE** en cualquier otro caso, con una **lista cerrada de ≤ 7 hallazgos** y la tabla de estado de los 39 ítems.
- Una etapa **BLOQUEA** que falla corta la certificación: no se siguen corriendo las etapas siguientes hasta corregirla (ahorra una hora de corridas inútiles). Las etapas son: (1) P1 y P2, (2) P3 a P5, (3) P6 a P9, (4) P10 y P11.
- El sello «certificado por humanos» solo lo puede agregar quien haya corrido el anexo E, y lo escribe como línea aparte del veredicto; **no cambia** ningún ítem de la rúbrica.

---

## 6. Veredicto de cada certificador y triangulación

**Roles.** Tres certificadores independientes, cada uno con un **foco primario**: **A — técnica y entrega** (T, E), **B — jugabilidad y claridad** (C, J) y **C — visual, relieve e historia** (V, R, H). Cada criterio lo evalúan como **mínimo dos** (el primario y un espejo: T/E → B, C/J → C, V/R/H → A) y el tercero **desempata**. Los criterios de juicio visual o textual (V01, V02, R03, R06, H02, H03) los evalúan **los tres**. Los procedimientos caros tienen una versión espejo más barata (P4, P6) que además comprueba determinismo.

**Formato (`veredicto.json`, más `VEREDICTO.md` con lo mismo en tabla):**

```json
{"rubrica": "QA_NIVEL2 1.0", "rubrica_sha256": "<sha256 de docs/QA_NIVEL2.md>", "commit": "<hash completo certificado>", "ronda": "r4", "certificador": "A", "fecha": "2026-11-..",
 "entorno": {"os": "Windows 11", "gpu": "RTX 3080 Ti", "godot": "4.7.2", "python": "3.11"},
 "criterios": {"T01": {"v": "P", "medicion": "git diff exit 0; main.gd +21/-4", "evidencia": ["qa/A/T01/protegidos.txt"], "nota": ""},
               "V01": {"v": "F", "medicion": "M05 item (a): la torre no se identifica", "evidencia": ["qa/A/V01/capturas/M05_torre.jpg"], "nota": "..."}},
 "hallazgos": [{"id": "H-r4-1", "criterio": "V01", "severidad": "ALTA", "titulo": "...", "evidencia": ["..."], "repro": "...", "pista": "visual", "aceptacion": "...", "razon_aceptada": ""}],
 "no_ejecutado": [{"criterio": "E02", "motivo": "..."}]}
```

`v` es **P** (pasa), **F** (falla) o **N** (no evaluable: falla). Cada `P` o `F` cita **medición y evidencia**; un `P` sin evidencia se trata como N.

**Consolidación** (`qa_veredicto.py`, anexo A4): por criterio se cuentan los votos P y F de quienes lo evaluaron; hacen falta **≥ 2 votos**; gana la mayoría; un empate 1–1 sin tercero es N. Un `F` de un solo certificador contra dos `P` **no** hace fallar el ítem, pero queda registrado como **discrepancia** y, si trae evidencia objetiva, el Jefe de QA la convierte en hallazgo (regla 1) o la descarta (regla 3). Un criterio de comando (T, E, parte de C y J) debe dar **los mismos números** en dos certificadores (conteos exactos; milisegundos ± 15 %; tasas idénticas con las mismas semillas porque el motor es determinista): si no, es un hallazgo ALTA de **no reproducibilidad**, salvo causa explicada (por ejemplo, GPU ocupada en un benchmark).

**Qué firma cada uno.** «Corrí P#, miré las capturas M01–M12, el overlay y las de límite; lo que no figura en `criterios` con evidencia es N.»

---

## Anexo A · Herramientas de QA (se extraen de este documento; ver P0)

Todas son de **solo lectura**, usan Python 3.11 con `numpy`, `scipy`, `Pillow` y `scikit-image` (ya instalados; **no se instala nada**) y la API del contrato 1. Se probaron contra imágenes sintéticas, la lámina 03, la lámina 06 y un *mock* de `HumahuacaTerrain` y de `HumahuacaRules` armado con los 475 nodos de la lámina. **Si una firma real difiere, se corrige el script con una enmienda de herramienta (anexo F); el umbral no cambia.** Resultados de esas pruebas: un DEM fiel pasa R01–R06 (bandas 99,6 % en la ventana y 98,7 % en el dominio); el mismo DEM desplazado 9 m falla R02, R03 y R05 (bandas 46,7 % y 52,2 %); un colage de paleta con sombreado y tintes da mediana 2,4 y p90 4,8, y con 12 % de bloques verdes, azules, amarillos o magenta da p90 35,5 y 11,8 % a > 22.

<details>
<summary>A1 · Volcado del relieve (Godot, `qa_relieve.gd`)</summary>

```gdscript
# FILE: qa_relieve.gd
extends SceneTree
## Vuelca el relieve de HumahuacaTerrain a JSON para qa_relieve.py (docs/QA_NIVEL2.md, anexo A1). Solo usa la API del contrato 1 (3.1).
## Uso: godot --headless --path <SRC> --script <este archivo> -- --out=<dump.json> [--terrain=res://scripts/humahuaca/terrain/humahuaca_terrain.gd]
const PTS41 := [["P01",0,0],["P02",-111,-35],["P03",-143,3],["P04",-450,325],["P05",450,325],["P06",-450,-325],["P07",450,-325],
	["P08",-450,0],["P09",450,0],["P10",0,325],["P11",0,-325],["P12",-225,162],["P13",225,162],["P14",-225,-162],["P15",225,-162],
	["P16",122,325],["P17",297,200],["P18",409,0],["P19",450,-81],["P20",596,-271],["P21",460,-700],["P22",-279,1000],["P23",435,-1345],
	["P24",-180,325],["P25",-84,0],["P26",-70,-325],["P27",-1800,0],["P28",-1500,0],["P29",-1000,0],["P30",-750,0],["P31",750,0],
	["P32",1000,0],["P33",1250,0],["P34",1500,0],["P35",1800,0],["P36",-1800,1350],["P37",1800,1350],["P38",-1800,-1350],
	["P39",1800,-1350],["P40",350,-1250],["P41",1800,-750]]
const LM_IDS := ["templo","bateria","cuartel","posta","torre_casa_cura","torre_templo","plaza","polvorin","parque","corral_posta",
	"quebradita_norte","quebradita_sur","vado_este","salida_este","entrada_sur","zona_partida","spawn_rodriguez","spawn_portal",
	"spawn_arias","spawn_reconocedores","spawn_arreo"]

func _xz(p: Variant) -> Array:
	if p is Vector2:
		return [p.x, p.y]
	if p is Dictionary:
		return [float(p.get("x", 0.0)), float(p.get("z", 0.0))]
	if p is Array and p.size() >= 2:
		return [float(p[0]), float(p[1])]
	return [0.0, 0.0]

func _r2(v: float) -> float:
	return snappedf(v, 0.01)

func _initialize() -> void:
	var out := ""
	var path := "res://scripts/humahuaca/terrain/humahuaca_terrain.gd"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--terrain="):
			path = a.trim_prefix("--terrain=")
	var cls = load(path)
	var t = cls.load_default() if cls != null else null
	if t == null or out == "":
		print("QA_RELIEVE_ERROR terreno o --out ausentes")
		quit(2)
		return
	var datum: float = float(t.datum_asl_m)
	var d := {"schema": "qa_relieve_v1", "datum": datum, "report": t.report(), "size_m": _xz(t.size_m), "cell_m": float(t.cell_m),
		"nx": int(t.nx), "nz": int(t.nz), "anchor": _xz(t.anchor), "lam2game_00": _xz(t.lamina_to_game(0.0, 0.0)),
		"game2lam_anchor": _xz(t.game_to_lamina(Vector2(450.0, 325.0)))}
	var pts: Array = []
	for p in PTS41:
		var g: Array = _xz(t.lamina_to_game(float(p[1]), float(p[2])))
		pts.append({"id": p[0], "E": p[1], "N": p[2], "x": g[0], "z": g[1], "dem_m": _r2(float(t.height_dem_only(g[0], g[1])) + datum)})
	d["points41"] = pts
	var ctx: Array = []
	for j in range(91):
		for i in range(121):
			ctx.append(_r2(float(t.height_dem_only(-1350.0 + 30.0 * i, -1025.0 + 30.0 * j))))
	d["ctx"] = {"x0": -1350.0, "z0": -1025.0, "cell": 30.0, "nx": 121, "nz": 91, "dem": ctx}
	var wd: Array = []
	var wf: Array = []
	for j in range(66):
		for i in range(91):
			wd.append(_r2(float(t.height_dem_only(10.0 * i, 10.0 * j))))
			wf.append(_r2(float(t.height_at(10.0 * i, 10.0 * j))))
	d["win"] = {"x0": 0.0, "z0": 0.0, "cell": 10.0, "nx": 91, "nz": 66, "dem": wd, "final": wf}
	var rv: Dictionary = t.river()
	var rp: Array = []
	for p in rv.get("pts", []):
		rp.append(_xz(p))
	d["river"] = rp
	var lm := {}
	for id in LM_IDS:
		var l: Dictionary = t.landmark(id)
		if not l.is_empty():
			lm[id] = {"x": float(l.x), "z": float(l.z), "tag": str(l.get("tag", "")), "type": str(l.get("type", ""))}
	d["landmarks"] = lm
	var bx: float = lm["bateria"].x if lm.has("bateria") else 318.0
	var bz: float = lm["bateria"].z if lm.has("bateria") else 350.0
	d["refs"] = {"templo_final": _r2(float(t.height_at(450.0, 325.0))), "cauce_z325_final": _r2(float(t.height_at(859.0, 325.0))),
		"partida_final": _r2(float(t.height_at(70.0, 470.0))), "bateria_final": _r2(float(t.height_at(bx, bz))),
		"bateria_dem": _r2(float(t.height_dem_only(bx, bz))), "plaza_final": _r2(float(t.height_at(450.0, 392.0)))}
	var edges: Array = []
	for k in range(101):
		var u: float = k / 100.0
		var pairs := [[0.25, 650.0 * u, -0.25, 650.0 * u], [899.75, 650.0 * u, 900.25, 650.0 * u],
			[900.0 * u, 0.25, 900.0 * u, -0.25], [900.0 * u, 649.75, 900.0 * u, 650.25]]
		for q in pairs:
			edges.append(absf(float(t.height_at(q[0], q[1])) - float(t.height_at(q[2], q[3]))))
	d["edge_jump_max_m"] = _r2(edges.max())
	var ng: Dictionary = t.nav_grid()
	var solid: Array = []
	for v in ng.get("solid", PackedByteArray()):
		solid.append(int(v))
	d["nav"] = {"nx": int(ng.get("nx", 0)), "nz": int(ng.get("nz", 0)), "cell": float(ng.get("cell", 4.0)), "solid": solid}
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	print("QA_RELIEVE_OK ", out)
	quit(0)
```

</details>

<details>
<summary>A1 · Comparación con la lámina 03 y overlay (`qa_relieve.py`)</summary>

```python
# FILE: qa_relieve.py
"""Compara el relieve del juego con la lámina 03 (docs/QA_NIVEL2.md, anexo A1). Solo lectura. Python 3.11 + numpy, scipy, Pillow, scikit-image.
Uso: python -I qa_relieve.py --dump dump.json --lamina 03_relieve_actual.png --out <carpeta> [--map data/humahuaca_map.json]
Sale con 0 si R01..R06 pasan y con 1 si alguno falla. Escribe R_result.json y overlay_lamina03.jpg."""
import argparse, json, math, pathlib, sys
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import map_coordinates, label
from skimage.measure import find_contours

X0, Y0, S = 1018.5, 1122.5, 0.4743   # lámina 03 (2755x2223): píxel de E=0/N=0 y píxeles por metro (verificado con el marco rojo y la traza del río)
TINTS = ["#ECE3CE", "#E5D9C0", "#DED1B3", "#D7C8A6", "#D0BE9A", "#C9B590", "#C2AD86", "#BAA37C", "#B29A74", "#A9916F", "#9F886A"]  # bandas <2940, 2940-2960, ..., >=3120
# id: (cota mínima de la banda, cota máxima, estimación en m s. n. m.); None = banda abierta; punto sobre la curva: (2960, 2960, 2960)
T41 = {"P01": (2940, 2960, 2957), "P02": (2960, 2980, 2961), "P03": (2960, 2980, 2962), "P04": (2960, 2980, 2971), "P05": (2940, 2960, 2954),
       "P06": (2960, 2980, 2969), "P07": (2940, 2960, 2946), "P08": (2960, 2980, 2970), "P09": (2940, 2960, 2952), "P10": (2940, 2960, 2955),
       "P11": (2940, 2960, 2958), "P12": (2960, 2980, 2964), "P13": (2940, 2960, 2953), "P14": (2960, 2980, 2965), "P15": (2940, 2960, 2952),
       "P16": (2940, 2960, 2954), "P17": (2940, 2960, 2953), "P18": (2940, 2960, 2952), "P19": (2940, 2960, 2951), "P20": (2940, 2960, 2948),
       "P21": (None, 2940, 2939), "P22": (2940, 2960, 2958), "P23": (None, 2940, 2932), "P24": (2960, 2960, 2960), "P25": (2960, 2960, 2960),
       "P26": (2960, 2960, 2960), "P27": (3000, 3020, 3014), "P28": (3000, 3020, 3004), "P29": (2980, 3000, 2990), "P30": (2960, 2980, 2977),
       "P31": (2940, 2960, 2956), "P32": (2960, 2980, 2973), "P33": (2980, 3000, 2992), "P34": (3020, 3040, 3024), "P35": (3080, 3100, 3088),
       "P36": (3020, 3040, 3025), "P37": (3060, 3080, 3065), "P38": (3000, 3020, 3003), "P39": (3100, 3120, 3116), "P40": (None, 2940, 2932),
       "P41": (3120, None, 3137)}
NEED = ["templo", "bateria", "cuartel", "posta", "torre_casa_cura", "torre_templo", "plaza", "polvorin", "parque", "corral_posta", "quebradita_norte",
        "quebradita_sur", "vado_este", "salida_este", "entrada_sur", "zona_partida", "spawn_rodriguez", "spawn_portal", "spawn_arias", "spawn_reconocedores", "spawn_arreo"]
RES = {}


def chk(rid, name, ok, **det):
    RES.setdefault(rid, []).append({"check": name, "ok": bool(ok), **det})
    print("  %s %-52s %s %s" % (rid, name, "PASA " if ok else "FALLA", json.dumps(det, ensure_ascii=False, default=float)[:180]))


def main():
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser()
    ap.add_argument("--dump", required=True)
    ap.add_argument("--lamina", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--map", default="")
    a = ap.parse_args()
    out = pathlib.Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    d = json.load(open(a.dump, encoding="utf-8"))
    src = str(d["report"].get("source", "?"))
    b_plan = src == "lamina03_reconstruida"
    datum = float(d["datum"])
    print("fuente del relieve:", src)
    near = lambda p, q, t: abs(p[0] - q[0]) <= t and abs(p[1] - q[1]) <= t
    # ---- R01 ancla, ventana e hitos
    chk("R01", "ancla en (450,325) y conversión lámina<->juego", near(d["anchor"], (450, 325), .01) and near(d["lam2game_00"], (450, 325), .01) and near(d["game2lam_anchor"], (0, 0), .01),
        anchor=d["anchor"], lam2game=d["lam2game_00"], game2lam=d["game2lam_anchor"])
    chk("R01", "ventana 900x650, celda 4 m, 226x164", near(d["size_m"], (900, 650), .01) and d["cell_m"] == 4.0 and (d["nx"], d["nz"]) == (226, 164),
        size=d["size_m"], cell=d["cell_m"], nx=d["nx"], nz=d["nz"])
    if a.map:
        an = json.load(open(a.map, encoding="utf-8")).get("anchor", {})
        chk("R01", "ancla lat/lon, incertidumbre y etiqueta", abs(an.get("lat", 0) + 23.2041) <= 1e-4 and abs(an.get("lon", 0) + 65.3492) <= 1e-4
            and an.get("uncertainty_m") == 15 and an.get("tag") == "razonado", anchor=an)
    L = d["landmarks"]
    chk("R01", "los 21 hitos obligatorios existen", all(k in L for k in NEED), faltan=[k for k in NEED if k not in L])
    if all(k in L for k in NEED):
        P = lambda k: (L[k]["x"], L[k]["z"])
        dist = lambda p, q: math.hypot(p[0] - q[0], p[1] - q[1])
        T = P("templo")
        rel = {"templo en el ancla (±0,5 m)": near(T, (450, 325), .5),
               "batería al oeste, a 100-170 m del templo": P("bateria")[0] < T[0] - 100 and 100 <= dist(P("bateria"), T) <= 170,
               "cuartel a ≤ 60 m del templo": dist(P("cuartel"), T) <= 60,
               "posta al este, a 100-220 m del templo": P("posta")[0] > T[0] + 100 and 100 <= dist(P("posta"), T) <= 220,
               "tres objetivos separados ≥ 80 m": min(dist(P(p), P(q)) for p, q in (("bateria", "cuartel"), ("bateria", "posta"), ("cuartel", "posta"))) >= 80,
               "vado ≥ x840, salida ≥ x880, entrada sur ≥ z630": P("vado_este")[0] >= 840 and P("salida_este")[0] >= 880 and P("entrada_sur")[1] >= 630,
               "las 5 partidas en el sudoeste (x ≤ 300, z ≥ 440)": all(P(k)[0] <= 300 and P(k)[1] >= 440 for k in NEED if k.startswith("spawn_"))}
        for k, v in rel.items():
            chk("R01", k, v)
    # ---- R02 los 41 puntos de [01] §d.7
    errs, inb = [], []
    for p in d["points41"]:
        lo, hi, est = T41[p["id"]]
        v = p["dem_m"]
        errs.append(abs(v - est))
        inb.append((lo is None or v >= lo - 8) and (hi is None or v <= hi + 8))
    chk("R02", "≥ 37 de 41 a ≤ 12 m de la estimación", sum(e <= 12 for e in errs) >= 37, n_ok=int(sum(e <= 12 for e in errs)))
    chk("R02", "ninguno a más de 20 m", max(errs) <= 20, max_err_m=round(max(errs), 1))
    chk("R02", "los 41 dentro de su banda de color ±8 m", all(inb), fuera=[d["points41"][i]["id"] for i, v in enumerate(inb) if not v])
    # ---- R03 acuerdo de bandas (curvas de 20 m) contra los píxeles de la lámina
    im = np.asarray(Image.open(a.lamina).convert("RGB")).astype(np.int16)
    x_lo, x_hi = int(round(X0 - 1800 * S)) + 3, int(round(X0 + 1800 * S)) - 3
    y_lo, y_hi = int(round(Y0 - 1350 * S)) + 3, int(round(Y0 + 1350 * S)) - 3
    sub = im[y_lo:y_hi, x_lo:x_hi]
    best = np.full(sub.shape[:2], 999, np.int16)
    cls = np.zeros(sub.shape[:2], np.int8)
    for k, h in enumerate(TINTS):
        t = np.array([int(h[i:i + 2], 16) for i in (1, 3, 5)], np.int16)
        dd = np.abs(sub - t).sum(axis=2).astype(np.int16)
        m = dd < best
        best[m] = dd[m]
        cls[m] = k
    valid = best <= 6
    ys, xs = np.mgrid[y_lo:y_hi, x_lo:x_hi]
    E, N = (xs - X0) / S, (Y0 - ys) / S
    c, w = d["ctx"], d["win"]
    cg = np.array(c["dem"], float).reshape(c["nz"], c["nx"])
    wg = np.array(w["dem"], float).reshape(w["nz"], w["nx"])
    zc = map_coordinates(cg, [(325 - N - c["z0"]) / c["cell"], (E + 450 - c["x0"]) / c["cell"]], order=1, mode="nearest")
    zw = map_coordinates(wg, [(325 - N) / w["cell"], (E + 450) / w["cell"]], order=1, mode="nearest")
    inwin = (np.abs(E) <= 450) & (np.abs(N) <= 325)
    z = np.where(inwin, zw, zc) + datum
    band = np.where(z < 2940, 0, np.clip(np.floor((z - 2940) / 20) + 1, 0, 10)).astype(np.int8)
    ag_w = float(((band == cls) & valid & inwin).sum() / (valid & inwin).sum() * 100)
    ag_t = float(((band == cls) & valid).sum() / valid.sum() * 100)
    tw, tt = (97.0, 95.0) if b_plan else (75.0, 70.0)
    chk("R03", "acuerdo de bandas en la ventana ≥ %g %%" % tw, ag_w >= tw, pct=round(ag_w, 2))
    chk("R03", "acuerdo de bandas en todo el dominio ≥ %g %%" % tt, ag_t >= tt, pct=round(ag_t, 2))
    # ---- R04 río del juego contra la traza azul de la lámina, fila por fila (tramo dentro de la ventana)
    blue = np.abs(im - np.array([0x32, 0x6F, 0x8A], np.int16)).sum(axis=2) < 30
    rv = sorted(d["river"], key=lambda p: p[1])
    errs_r = []
    for Nm in range(325, -81, -20):
        py = int(round(Y0 - Nm * S))
        c0 = int(X0 - 450 * S)
        cols = np.nonzero(blue[py, c0:int(X0 + 800 * S)])[0] + c0
        if len(cols) == 0:
            continue
        run = [cols[0]]
        for cc in cols[1:]:
            if cc - run[-1] > 2:
                break
            run.append(cc)
        e_lam = (np.mean(run) - X0) / S
        xg = float(np.interp(325 - Nm, [p[1] for p in rv], [p[0] for p in rv]))
        errs_r.append(abs(xg - 450 - e_lam))
    chk("R04", "al menos 15 filas medidas sobre la lámina", len(errs_r) >= 15, filas=len(errs_r))
    chk("R04", "error medio ≤ 6 m", bool(errs_r) and float(np.mean(errs_r)) <= 6, medio_m=round(float(np.mean(errs_r)), 1) if errs_r else None)
    chk("R04", "error máximo ≤ 12 m", bool(errs_r) and max(errs_r) <= 12, max_m=round(float(max(errs_r)), 1) if errs_r else None)
    chk("R04", "entra por el borde norte y sale por el borde este", abs(rv[0][1]) <= 6 and abs(rv[-1][0] - 900) <= 6 and abs(rv[-1][1] - 406) <= 12, entra=rv[0], sale=rv[-1])
    # ---- R05 desnivel de 12 m y alturas de referencia
    r = d["refs"]
    dome = r["bateria_final"] - r["bateria_dem"]
    tol = 10.0 if b_plan else 3.0
    chk("R05", "domo de la batería = 12,0 ± 0,3 m sobre el DEM", abs(dome - 12.0) <= 0.3, domo_m=round(dome, 2))
    chk("R05", "batería entre 14 y 19 m sobre la plaza", 14 <= r["bateria_final"] - r["plaza_final"] <= 19, m=round(r["bateria_final"] - r["plaza_final"], 2))
    chk("R05", "alturas de referencia (templo +17, cauce +12, partida +27, ±%g m)" % tol,
        abs(r["templo_final"] - 17) <= tol and abs(r["cauce_z325_final"] - 12) <= tol and abs(r["partida_final"] - 27) <= tol,
        templo=r["templo_final"], cauce=r["cauce_z325_final"], partida=r["partida_final"])
    lay = [x for x in d["report"].get("design_layers", []) if x.get("id") == "cerro_bateria"]
    chk("R05", "el domo figura en report() como capa de diseño", bool(lay) and lay[0].get("tag") == "diseno" and abs(float(lay[0].get("delta_m", 0)) - 12) <= 0.3, capa=lay)
    # ---- R06 continuidad y conectividad
    chk("R06", "salto máximo en el borde de la ventana ≤ 0,10 m", d["edge_jump_max_m"] <= 0.10, salto_m=d["edge_jump_max_m"])
    nv = d["nav"]
    solid = np.array(nv["solid"], np.uint8).reshape(nv["nz"], nv["nx"])
    lab, _ = label(solid == 0, structure=np.ones((3, 3)))

    def comp(k):
        i, j = int(L[k]["x"] // nv["cell"]), int(L[k]["z"] // nv["cell"])
        for rad in range(0, 4):
            for dj in range(-rad, rad + 1):
                for di in range(-rad, rad + 1):
                    jj, ii = min(max(j + dj, 0), nv["nz"] - 1), min(max(i + di, 0), nv["nx"] - 1)
                    if lab[jj, ii] > 0:
                        return int(lab[jj, ii])
        return 0
    sp = [comp(k) for k in NEED if k.startswith("spawn_")]
    tg = [comp(k) for k in ("bateria", "cuartel", "posta", "vado_este")]
    chk("R06", "las 5 partidas llegan a los 3 objetivos y al vado", 0 not in sp + tg and len(set(sp + tg)) == 1, componentes=sp + tg)
    # ---- overlay sobre la lámina 03 (recorte E ±1000 m, N ±750 m, ampliado x2)
    cx0, cx1, cy0, cy1 = int(X0 - 1000 * S), int(X0 + 1000 * S), int(Y0 - 750 * S), int(Y0 + 750 * S)
    K = 2.0
    ov = Image.open(a.lamina).convert("RGB").crop((cx0, cy0, cx1, cy1))
    ov = ov.resize((int(ov.width * K), int(ov.height * K)), Image.LANCZOS)
    dr = ImageDraw.Draw(ov)
    px = lambda e, n: ((X0 + e * S - cx0) * K, (Y0 - n * S - cy0) * K)
    g2p = lambda x, zz: px(x - 450, 325 - zz)
    for lvl in range(2940, 3141, 20):
        for arr, o in ((cg, c), (wg, w)):
            for ln in find_contours(arr + datum, lvl):
                dr.line([g2p(o["x0"] + o["cell"] * p[1], o["z0"] + o["cell"] * p[0]) for p in ln], fill=(224, 0, 224), width=1)
    dr.line([g2p(p[0], p[1]) for p in rv], fill=(255, 136, 0), width=3)
    dr.rectangle([g2p(0, 0), g2p(900, 650)], outline=(0, 200, 220), width=3)
    ax, ay = g2p(450, 325)
    dr.line([(ax - 12, ay), (ax + 12, ay)], fill=(0, 160, 0), width=3)
    dr.line([(ax, ay - 12), (ax, ay + 12)], fill=(0, 160, 0), width=3)
    dr.ellipse([g2p(305 - 75, 345 - 75), g2p(305 + 75, 345 + 75)], outline=(90, 200, 0), width=2)
    for p, e in zip(d["points41"], errs):
        qx, qy = px(p["E"], p["N"])
        if 0 <= qx < ov.width and 0 <= qy < ov.height:
            col = (0, 170, 0) if e <= 12 else ((230, 180, 0) if e <= 20 else (220, 0, 0))
            dr.ellipse([qx - 5, qy - 5, qx + 5, qy + 5], fill=col, outline=(0, 0, 0))
            dr.text((qx + 7, qy - 6), p["id"], fill=(0, 0, 0))
    dr.rectangle([8, 8, 900, 78], fill=(255, 255, 255))
    dr.text((14, 12), "QA relieve. magenta = curvas de 20 m del juego (DEM sin capas de diseno); naranja = rio del juego; cian = ventana; verde = ancla y domo", fill=(0, 0, 0))
    dr.text((14, 30), "fuente: %s | bandas: ventana %.1f %%, dominio %.1f %% | 41 puntos: %d a <= 12 m (max %.1f m)" % (src, ag_w, ag_t, sum(e <= 12 for e in errs), max(errs)), fill=(0, 0, 0))
    dr.text((14, 48), "rio: error medio %.1f m (max %.1f m) | domo de la bateria %.2f m" % (float(np.mean(errs_r)) if errs_r else -1, max(errs_r) if errs_r else -1, dome), fill=(0, 0, 0))
    q = 85
    while True:
        ov.save(out / "overlay_lamina03.jpg", quality=q)
        if (out / "overlay_lamina03.jpg").stat().st_size <= 300 * 1024 or q <= 45:
            break
        q -= 8
    res = {"schema": "qa_relieve_result_v1", "source": src, "bandas_ventana_pct": round(ag_w, 2), "bandas_dominio_pct": round(ag_t, 2),
           "criterios": {k: {"pasa": all(x["ok"] for x in v), "checks": v} for k, v in sorted(RES.items())}}
    res["todo_pasa"] = all(v["pasa"] for v in res["criterios"].values())
    (out / "R_result.json").write_text(json.dumps(res, indent=1, ensure_ascii=False, default=float), encoding="utf-8")
    for k, v in sorted(res["criterios"].items()):
        print(k, "PASA" if v["pasa"] else "FALLA")
    sys.exit(0 if res["todo_pasa"] else 1)


if __name__ == "__main__":
    main()
```

</details>

<details>
<summary>A2 · Paleta, marcadores, fichas, contraste y JPEG (`qa_imagen.py`)</summary>

```python
# FILE: qa_imagen.py
"""Medidas de imagen y de paleta para el QA del nivel 2 (docs/QA_NIVEL2.md, anexo A2). Solo lectura. Python 3.11 + numpy y Pillow.
  python -I qa_imagen.py paleta  --lamina06 06_paletas.png [--visual data/humahuaca_visual.json]      # R: V04 (datos)
  python -I qa_imagen.py calib   a.png b.png ...                                                       # V04 (adherencia cromática, vistas de día sin interfaz)
  python -I qa_imagen.py markers hud.png --need celeste,oro[,borgona] [--min 50] [--tol 3]             # V05 (marcadores de interfaz exactos)
  python -I qa_imagen.py tokens  hoja_fichas.png                                                       # V03 (5 siluetas distintas, >= 48 px)
  python -I qa_imagen.py contraste captura.png --rects "x,y,w,h;x,y,w,h"                               # V05 (contraste WCAG >= 4,5:1)
  python -I qa_imagen.py jpg     entrada.png salida.jpg [--max-kb 300]                                 # evidencia chica
Sale con 0 si pasa y con 1 si falla (calib, markers, tokens, contraste, paleta); jpg sale con 0."""
import argparse, json, sys
import numpy as np
from PIL import Image

HEX = ("B99A72 776248 8E8B81 6D7653 69794B 8C9B91 C4AA82 E4DDCA 59432E 745034 B3A077 4B4B47 CEC2A7 705741 2E455A 9A443B 4F5E4C E1D7BD "
       "7FAAC4 EFE8D7 983F36 B99A50 383831 843D40").split()
PAL = np.array([[int(h[i:i + 2], 16) for i in (0, 2, 4)] for h in HEX], float)
MARK = {"celeste": "7FAAC4", "borgona": "983F36", "oro": "B99A50"}


def lin(c):
    c = np.asarray(c, float) / 255.0
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def lab(rgb):
    x = lin(rgb) @ np.array([[0.4124564, 0.3575761, 0.1804375], [0.2126729, 0.7151522, 0.0721750], [0.0193339, 0.1191920, 0.9503041]]).T
    x = x / np.array([0.95047, 1.0, 1.08883])
    f = np.where(x > 216 / 24389, np.cbrt(x), (24389 / 27 * x + 16) / 116)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], -1)


PL = lab(PAL)


def load(p):
    return np.asarray(Image.open(p).convert("RGB"))


def cmd_paleta(a):
    im = load(a.lamina06).reshape(-1, 3)
    key = (im[:, 0].astype(np.int64) << 16) | (im[:, 1].astype(np.int64) << 8) | im[:, 2]
    ok = True
    for h in HEX:
        n = int((key == int(h, 16)).sum())
        if n < 5000:
            ok = False
            print("FALLA lámina 06: #%s aparece %d px (< 5000)" % (h, n))
    print("lámina 06: los 24 HEX exactos presentes" if ok else "lámina 06: faltan HEX")
    if a.visual:
        v = json.load(open(a.visual, encoding="utf-8"))
        got = [str(e.get("hex", "")).upper().lstrip("#") for e in v.get("palette", [])]
        same = sorted(got) == sorted(HEX) and len(got) == 24
        print("palette del JSON == 24 HEX de la lámina:", same)
        ok = ok and same
        sueltos = []

        def walk(o, path):
            if isinstance(o, dict):
                for k, x in o.items():
                    walk(x, path + "." + k)
            elif isinstance(o, list):
                for i, x in enumerate(o):
                    walk(x, "%s[%d]" % (path, i))
            elif isinstance(o, str) and len(o) == 7 and o[0] == "#" and all(c in "0123456789abcdefABCDEF" for c in o[1:]):
                sueltos.append(path)
        for k in ("props", "tokens"):
            walk(v.get(k, {}), k)
        print("HEX sueltos en props/tokens (deben ser 0):", len(sueltos), sueltos[:5])
        ok = ok and not sueltos
    return ok


def cmd_calib(a):
    allv, ok = [], True
    for p in a.imgs:
        px = load(p)[::2, ::2].reshape(-1, 3)
        L = lab(px)
        m = (L[:, 0] >= 12) & (L[:, 0] <= 97)
        L = L[m]
        d = np.sqrt((L[:, None, 1] - PL[None, :, 1]) ** 2 + (L[:, None, 2] - PL[None, :, 2]) ** 2).min(axis=1)
        allv.append(d)
        print("%-40s px=%7d  mediana %.1f  p90 %.1f  >22: %.2f %%" % (p, len(d), np.median(d), np.percentile(d, 90), 100 * (d > 22).mean()))
    d = np.concatenate(allv)
    med, p90, sh = float(np.median(d)), float(np.percentile(d, 90)), float(100 * (d > 22).mean())
    ok = med <= 8 and p90 <= 14 and sh <= 3
    print("GLOBAL mediana %.1f (<= 8)  p90 %.1f (<= 14)  >22: %.2f %% (<= 3)  ->  %s" % (med, p90, sh, "PASA" if ok else "FALLA"))
    return ok


def cmd_markers(a):
    px = load(a.png).astype(int)
    ok = True
    for k in a.need.split(","):
        t = np.array([int(MARK[k][i:i + 2], 16) for i in (0, 2, 4)])
        n = int((np.abs(px - t).max(axis=2) <= a.tol).sum())
        print("marcador %-8s #%s: %6d px exactos (>= %d)  %s" % (k, MARK[k], n, a.min, "PASA" if n >= a.min else "FALLA"))
        ok = ok and n >= a.min
    return ok


def cmd_tokens(a):
    px = load(a.sheet).astype(int)
    h, w, _ = px.shape
    vals, cnt = np.unique(px.reshape(-1, 3), axis=0, return_counts=True)
    bg = vals[cnt.argmax()]
    mask = np.abs(px - bg).sum(axis=2) > 24
    cw = w // 5
    boxes, ok = [], True
    for i in range(5):
        ys, xs = np.nonzero(mask[:, i * cw:(i + 1) * cw])
        if len(ys) < 50:
            print("celda %d vacía" % (i + 1))
            return False
        box = mask[:, i * cw:(i + 1) * cw][ys.min():ys.max() + 1, xs.min():xs.max() + 1]
        if box.shape[0] < a.min_h:
            print("celda %d: ficha de %d px de alto (< %d)" % (i + 1, box.shape[0], a.min_h))
            ok = False
        boxes.append(box)

    def canvas(b):  # alineada por el centro de la base, a escala real (conserva la proporción)
        c = np.zeros((256, 256), bool)
        y0, x0 = 256 - b.shape[0], 128 - b.shape[1] // 2
        c[y0:y0 + b.shape[0], x0:x0 + b.shape[1]] = b[:256, :256]
        return c
    cv = [canvas(b) for b in boxes]
    peor = 0.0
    for i in range(5):
        for j in range(i + 1, 5):
            bi, bj = boxes[i], boxes[j]
            asp = abs(np.log((bi.shape[1] / bi.shape[0]) / (bj.shape[1] / bj.shape[0])))
            fill = abs(bi.mean() - bj.mean())
            iou = float((cv[i] & cv[j]).sum() / max(1, (cv[i] | cv[j]).sum()))
            peor = max(peor, iou)
            if not (asp > 0.15 or fill > 0.10 or iou <= 0.70):
                print("siluetas %d y %d no se distinguen (proporción %.2f, relleno %.2f, IoU %.2f)" % (i + 1, j + 1, asp, fill, iou))
                ok = False
    print("fichas: 5 siluetas, peor IoU %.2f; distintas por proporción (> 0,15), relleno (> 0,10) o IoU (<= 0,70)  ->  %s" % (peor, "PASA" if ok else "FALLA"))
    return ok


def luma(c):
    c = lin(c)
    return 0.2126 * c[..., 0] + 0.7152 * c[..., 1] + 0.0722 * c[..., 2]


def cmd_contraste(a):
    px = load(a.png)
    ok = True
    for r in a.rects.split(";"):
        x, y, w, h = [int(v) for v in r.split(",")]
        L = luma(px[y:y + h, x:x + w].reshape(-1, 3))
        bg = float(np.median(L))
        lo, hi = float(np.percentile(L, 1)), float(np.percentile(L, 99))
        fg = lo if abs(lo - bg) >= abs(hi - bg) else hi
        ratio = (max(bg, fg) + 0.05) / (min(bg, fg) + 0.05)
        print("rect %-16s contraste %.2f:1 (>= 4.5)  %s" % (r, ratio, "PASA" if ratio >= 4.5 else "FALLA"))
        ok = ok and ratio >= 4.5
    return ok


def cmd_jpg(a):
    im = Image.open(a.src).convert("RGB")
    q, scale = 88, 1.0
    while True:
        t = im if scale == 1.0 else im.resize((int(im.width * scale), int(im.height * scale)), Image.LANCZOS)
        t.save(a.dst, quality=q)
        import os
        kb = os.path.getsize(a.dst) / 1024
        if kb <= a.max_kb or (q <= 50 and scale <= 0.5):
            break
        if q > 60:
            q -= 8
        else:
            scale *= 0.9
    print("%s: %.0f KB (calidad %d, escala %.2f)" % (a.dst, kb, q, scale))
    return True


def main():
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser()
    sp = ap.add_subparsers(dest="cmd", required=True)
    p = sp.add_parser("paleta")
    p.add_argument("--lamina06", required=True)
    p.add_argument("--visual", default="")
    p = sp.add_parser("calib")
    p.add_argument("imgs", nargs="+")
    p = sp.add_parser("markers")
    p.add_argument("png")
    p.add_argument("--need", required=True)
    p.add_argument("--min", type=int, default=50)
    p.add_argument("--tol", type=int, default=3)
    p = sp.add_parser("tokens")
    p.add_argument("sheet")
    p.add_argument("--min-h", dest="min_h", type=int, default=48)
    p = sp.add_parser("contraste")
    p.add_argument("png")
    p.add_argument("--rects", required=True)
    p = sp.add_parser("jpg")
    p.add_argument("src")
    p.add_argument("dst")
    p.add_argument("--max-kb", dest="max_kb", type=int, default=300)
    a = ap.parse_args()
    ok = {"paleta": cmd_paleta, "calib": cmd_calib, "markers": cmd_markers, "tokens": cmd_tokens, "contraste": cmd_contraste, "jpg": cmd_jpg}[a.cmd](a)
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
```

</details>

<details>
<summary>A3 · Balance, ritmo, rejugabilidad y determinismo (`qa_balance.py`)</summary>

```python
# FILE: qa_balance.py
"""Agrega las partidas simuladas (esquema hx_playthrough_v1) y aplica los umbrales J03..J07 de docs/QA_NIVEL2.md (anexo A3). Solo lectura.
Uso: python -I qa_balance.py --in rules.json [scene.json ...] --out <carpeta> [--seeds 9001-9060] [--min-seeds 60] [--min-replicas 3]
Cada archivo: {"schema": "hx_playthrough_v1", "level": "rules" | "scene", "games": [ {policy, family, seed, replicate, attempt, status, cause_id, elapsed_s,
  golpe, loss_pct, fronts_taken, opening, variant{}, first_decision_s, decision_gap_max_s, decision_gap_attack_max_s, exceptions, snapshot_sha256} ]}
Intento k: solo juegan el intento k+1 los que perdieron el k (hasta 5). Tasa del intento k = victorias del intento k / partidas del intento k.
Determinismo: python -I qa_balance.py --compare A.json B.json  (mismas partidas = mismo snapshot_sha256; >= 100 comparadas; sale con 0 si coinciden todas)
Sale con 0 si J03, J04, J05, J06 y J07 pasan; con 1 si alguno falla. Escribe J_result.json."""
import argparse, json, math, pathlib, statistics, sys
from collections import Counter, defaultdict


def wilson(k, n, z=1.645):
    if n == 0:
        return (0.0, 0.0)
    p = k / n
    c = (p + z * z / (2 * n)) / (1 + z * z / n)
    h = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / (1 + z * z / n)
    return (round(max(0.0, c - h), 3), round(min(1.0, c + h), 3))


def main():
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="inp", nargs="+")
    ap.add_argument("--out")
    ap.add_argument("--compare", nargs=2)
    ap.add_argument("--seeds", default="9001-9060")
    ap.add_argument("--min-seeds", type=int, default=60)
    ap.add_argument("--min-replicas", type=int, default=3)
    a = ap.parse_args()
    if a.compare:
        k = lambda g: (g["policy"], g["seed"], g["replicate"], g["attempt"])
        A = {k(g): g.get("snapshot_sha256") for g in json.load(open(a.compare[0], encoding="utf-8"))["games"]}
        B = {k(g): g.get("snapshot_sha256") for g in json.load(open(a.compare[1], encoding="utf-8"))["games"]}
        comunes = [x for x in A if x in B]
        malas = [x for x in comunes if A[x] != B[x] or not A[x]]
        print("comparadas %d, distintas %d (mínimo 100 comparadas y 0 distintas)" % (len(comunes), len(malas)), malas[:5])
        sys.exit(0 if len(comunes) >= 100 and not malas else 1)
    assert a.inp and a.out, "faltan --in y --out"
    lo, hi = [int(v) for v in a.seeds.split("-")]
    games = {"rules": [], "scene": []}
    for f in a.inp:
        d = json.load(open(f, encoding="utf-8"))
        assert d.get("schema") == "hx_playthrough_v1", f + ": esquema distinto de hx_playthrough_v1"
        games[d.get("level", "rules")] += d["games"]
    R, Sc = games["rules"], games["scene"]
    out = {"schema": "qa_balance_result_v1", "criterios": {}}
    MSG = []

    def crit(cid, name, ok, **det):
        out["criterios"].setdefault(cid, {"pasa": True, "checks": []})
        out["criterios"][cid]["checks"].append({"check": name, "ok": bool(ok), **det})
        out["criterios"][cid]["pasa"] &= bool(ok)
        MSG.append("  %s %-70s %s %s" % (cid, name, "PASA " if ok else "FALLA", json.dumps(det, ensure_ascii=False, default=float)[:150]))

    # ---- integridad de la muestra: semillas reservadas de QA y réplicas
    bad = sorted({g["seed"] for g in R + Sc if not lo <= g["seed"] <= hi})
    crit("J00", "todas las semillas están en el rango reservado de QA %s" % a.seeds, not bad, fuera=bad[:10])
    crit("J00", "ninguna partida con excepciones", all(g.get("exceptions", 0) == 0 for g in R + Sc), con_excepcion=sum(1 for g in R + Sc if g.get("exceptions", 0)))
    by = defaultdict(list)
    for g in R:
        by[(g["family"], g["policy"], g["attempt"])].append(g)

    def rate(fam, att, pol=None):
        rows = [g for (f, p, k), v in by.items() if f == fam and k == att and (pol is None or p == pol) for g in v]
        w = sum(1 for g in rows if g["status"] == "victory")
        return (w / len(rows) if rows else float("nan")), len(rows), w

    for fam in ("experto", "obediente", "torpe"):
        seeds1 = {g["seed"] for (f, p, k), v in by.items() if f == fam and k == 1 for g in v}
        reps = {g["replicate"] for (f, p, k), v in by.items() if f == fam and k == 1 for g in v}
        need_rep = 1 if fam == "experto" else a.min_replicas
        crit("J00", "%s: ≥ %d semillas y ≥ %d réplicas" % (fam, a.min_seeds, need_rep), len(seeds1) >= a.min_seeds and len(reps) >= need_rep, semillas=len(seeds1), replicas=len(reps))
    # ---- J03 ritmo (decisiones posibles)
    rit = [g for g in R if g["family"] in ("experto", "obediente", "torpe", "pausa_reanuda", "estrategia", "parcial")]
    crit("J03", "primera decisión ≤ 60 s en todas las partidas", all(0 <= g["first_decision_s"] <= 60 for g in rit), peor_s=max([g["first_decision_s"] for g in rit] or [0]), n=len(rit))
    crit("J03", "mayor brecha sin decisión posible ≤ 45 s", all(0 <= g["decision_gap_max_s"] <= 45 for g in rit), peor_s=max([g["decision_gap_max_s"] for g in rit] or [0]))
    crit("J03", "mayor brecha durante el ataque ≤ 20 s", all(0 <= g["decision_gap_attack_max_s"] <= 20 for g in rit), peor_s=max([g["decision_gap_attack_max_s"] for g in rit] or [0]))
    crit("J03", "existe el bot «solo pausa y reanuda» y recibe una decisión cada ≤ 45 s", any(g["family"] == "pausa_reanuda" for g in R), n=sum(1 for g in R if g["family"] == "pausa_reanuda"))
    # ---- tasas por familia e intento (con Wilson 90 %)
    tabla = {}
    for fam in ("experto", "obediente", "torpe"):
        for att in (1, 2, 3, 4, 5):
            p, n, w = rate(fam, att)
            if n:
                tabla["%s/intento%d" % (fam, att)] = {"p": round(p, 3), "n": n, "wilson90": wilson(w, n)}
    out["tasas"] = tabla
    ex, ob1, ob3, to1 = rate("experto", 1), rate("obediente", 1), rate("obediente", 3), rate("torpe", 1)
    trials = {(g["seed"], g["replicate"]) for (f, p, k), v in by.items() if f == "obediente" and k == 1 for g in v}
    won = {(g["seed"], g["replicate"]) for (f, p, k), v in by.items() if f == "obediente" and k <= 5 for g in v if g["status"] == "victory"}
    cum5 = len(won) / len(trials) if trials else float("nan")
    ciegos = {}
    for (f, p, k), v in by.items():
        if f == "ciego" and k == 1:
            ciegos[p] = sum(1 for g in v if g["status"] == "victory") / len(v)
    pas = [g for g in R if g["family"] in ("pasivo", "pausa_reanuda")]
    # ---- J04 balance grueso (BLOQUEA)
    crit("J04", "experto, 1.er intento ≥ 80 %", ex[0] >= 0.80, p=round(ex[0], 3), n=ex[1], wilson90=wilson(ex[2], ex[1]))
    crit("J04", "obediente, 1.er intento entre 10 % y 60 %", 0.10 <= ob1[0] <= 0.60, p=round(ob1[0], 3), n=ob1[1], wilson90=wilson(ob1[2], ob1[1]))
    crit("J04", "obediente gana al menos una vez en ≤ 5 intentos: ≥ 75 %", cum5 >= 0.75, p=round(cum5, 3), n=len(trials))
    crit("J04", "torpe, 1.er intento ≤ 40 %", to1[0] <= 0.40, p=round(to1[0], 3), n=to1[1], wilson90=wilson(to1[2], to1[1]))
    crit("J04", "cada bot ciego gana ≤ 10 % (y existe al menos uno)", bool(ciegos) and all(v <= 0.10 for v in ciegos.values()), ciegos={k: round(v, 3) for k, v in ciegos.items()})
    crit("J04", "pasivo y «pausa y reanuda»: 0 victorias y todas por «amanecio»", bool(pas) and all(g["status"] == "defeat" and g["cause_id"] == "amanecio" for g in pas), n=len(pas))
    # ---- J05 balance fino (ALTA): rangos del diseño ± 5 puntos
    crit("J05", "experto, 1.er intento ≥ 85 %", ex[0] >= 0.85, p=round(ex[0], 3))
    crit("J05", "obediente, 1.er intento entre 20 % y 45 %", 0.20 <= ob1[0] <= 0.45, p=round(ob1[0], 3), wilson90=wilson(ob1[2], ob1[1]))
    crit("J05", "obediente, 3.er intento (con diario) entre 55 % y 85 % (n ≥ 20)", ob3[1] >= 20 and 0.55 <= ob3[0] <= 0.85, p=round(ob3[0], 3), n=ob3[1], wilson90=wilson(ob3[2], ob3[1]))
    crit("J05", "obediente gana al menos una vez en ≤ 5 intentos: ≥ 85 %", cum5 >= 0.85, p=round(cum5, 3))
    crit("J05", "torpe, 1.er intento entre 5 % y 30 %", 0.05 <= to1[0] <= 0.30, p=round(to1[0], 3), wilson90=wilson(to1[2], to1[1]))
    # ---- J06 rejugabilidad y no dominancia (BLOQUEA), familia «estrategia», 1.er intento, réplica 1
    est = [g for g in R if g["family"] == "estrategia" and g["attempt"] == 1 and g["replicate"] == 1]
    pols = sorted({g["policy"] for g in est})
    wr = {p: sum(1 for g in est if g["policy"] == p and g["status"] == "victory") / max(1, sum(1 for g in est if g["policy"] == p)) for p in pols}
    wins = Counter(g["policy"] for g in est if g["status"] == "victory")
    tot = sum(wins.values())
    crit("J06", "hay ≥ 12 estrategias distintas en la matriz", len(pols) >= 12, n=len(pols))
    crit("J06", "ninguna estrategia concentra > 60 % de las victorias", tot > 0 and max(wins.values()) / tot <= 0.60, max_pct=round(100 * max(wins.values()) / tot, 1) if tot else None)
    crit("J06", "ninguna estrategia gana en > 80 % de las semillas", bool(wr) and max(wr.values()) <= 0.80, max_pct=round(100 * max(wr.values()), 1) if wr else None, top=sorted(wr.items(), key=lambda x: -x[1])[:3])
    crit("J06", "≥ 3 estrategias ganan en ≥ 50 % de las semillas", sum(1 for v in wr.values() if v >= 0.50) >= 3, n=sum(1 for v in wr.values() if v >= 0.50))
    mejor = Counter()
    for s in {g["seed"] for g in est}:
        rows = sorted([g for g in est if g["seed"] == s], key=lambda g: (-g["golpe"], g["loss_pct"], g["policy"]))
        mejor[rows[0]["policy"]] += 1
    crit("J06", "≥ 3 estrategias distintas son la mejor en ≥ 3 semillas cada una", sum(1 for v in mejor.values() if v >= 3) >= 3, mejores=dict(mejor.most_common(6)))
    cov = defaultdict(set)
    for g in R:
        for dim, val in (g.get("variant") or {}).items():
            cov[(dim, str(val))].add(g["seed"])
    dims = {"guardia": ["descuidada", "atenta"], "torre_en": ["templo", "casa_cura"], "refugio": ["norte", "sur"], "lluvia": ["copiosa", "garua"],
            "refuerzo": ["temprano", "normal", "tardio"], "layout": ["A", "B"]}
    falta = [(d, v, len(cov[(d, v)])) for d, vs in dims.items() for v in vs if len(cov[(d, v)]) < 3]
    crit("J06", "cada valor de cada variante aparece en ≥ 3 semillas de QA", not falta, escasos=falta)
    # ---- J07 duración y bajas (ALTA)
    vic = [g for g in R if g["status"] == "victory" and g["family"] in ("experto", "obediente")]
    med = statistics.median([g["elapsed_s"] for g in vic]) if vic else float("nan")
    crit("J07", "victorias: mediana entre 11:00 y 13:00", 660 <= med <= 780, mediana_s=round(med, 1), n=len(vic))
    crit("J07", "victorias: ≥ 90 % entre 10:00 y 14:00", bool(vic) and sum(1 for g in vic if 600 <= g["elapsed_s"] <= 840) / len(vic) >= 0.90, pct=round(100 * sum(1 for g in vic if 600 <= g["elapsed_s"] <= 840) / max(1, len(vic)), 1))
    dfe = [g for g in R if g["status"] == "defeat" and g["family"] in ("obediente", "torpe") and g["attempt"] == 1]
    dm = statistics.median([g["elapsed_s"] for g in dfe]) if dfe else float("nan")
    crit("J07", "derrotas del 1.er intento: mediana ≤ 8:00 y ninguna pasa de 14:00", bool(dfe) and dm <= 480 and max(g["elapsed_s"] for g in dfe) <= 841, mediana_s=round(dm, 1), n=len(dfe))
    vb = [g for g in R if g["status"] == "victory" and g["family"] in ("experto", "obediente", "torpe")]
    crit("J07", "bajas: mediana de victorias ≤ 55 % y ≤ 15 % con bajas > 80 %", bool(vb) and statistics.median([g["loss_pct"] for g in vb]) <= 55 and sum(1 for g in vb if g["loss_pct"] > 80) / len(vb) <= 0.15,
         mediana=round(statistics.median([g["loss_pct"] for g in vb]), 1) if vb else None, pct_gt80=round(100 * sum(1 for g in vb if g["loss_pct"] > 80) / max(1, len(vb)), 1))
    # ---- escena real (J01/J04): la escena confirma lo que dicen las reglas
    if Sc:
        e1 = [g for g in Sc if g["family"] == "experto" and g["attempt"] == 1]
        o1 = [g for g in Sc if g["family"] == "obediente" and g["attempt"] == 1]
        crit("J04", "escena real: ≥ 12 semillas, experto gana ≥ 70 % en el 1.er intento", len({g["seed"] for g in e1}) >= 12 and sum(1 for g in e1 if g["status"] == "victory") / max(1, len(e1)) >= 0.70,
             n=len(e1), p=round(sum(1 for g in e1 if g["status"] == "victory") / max(1, len(e1)), 3))
        po = sum(1 for g in o1 if g["status"] == "victory") / max(1, len(o1))
        crit("J04", "escena real: obediente a ≤ 0,30 de lo medido en reglas", bool(o1) and abs(po - ob1[0]) <= 0.30, escena=round(po, 3), reglas=round(ob1[0], 3), n=len(o1))
    else:
        crit("J04", "escena real: hay partidas de la escena (nivel «scene»)", False, nota="faltan filas level=scene")
    print("\n".join(MSG))
    out["todo_pasa"] = all(out["criterios"][k]["pasa"] for k in ("J00", "J03", "J04", "J05", "J06", "J07"))
    p = pathlib.Path(a.out)
    p.mkdir(parents=True, exist_ok=True)
    (p / "J_result.json").write_text(json.dumps(out, indent=1, ensure_ascii=False, default=float), encoding="utf-8")
    for k in sorted(out["criterios"]):
        print(k, "PASA" if out["criterios"][k]["pasa"] else "FALLA")
    sys.exit(0 if out["todo_pasa"] else 1)


if __name__ == "__main__":
    main()
```

</details>

<details>
<summary>A4 · Consolidación de los tres veredictos (`qa_veredicto.py`)</summary>

```python
# FILE: qa_veredicto.py
"""Consolida los veredictos de los certificadores (docs/QA_NIVEL2.md, sección 6 y anexo A4). Solo lectura.
Uso: python -I qa_veredicto.py --doc docs/QA_NIVEL2.md --in A.json B.json C.json --out VEREDICTO_FINAL.md [--hallazgos consolidado.json]
--hallazgos: lista consolidada (duplicados fusionados por el Jefe de QA, como máximo 7); sin ella se usa la unión de los tres veredictos sin repetir (criterio, titulo).
Cada JSON: {"rubrica_sha256": "...", "commit": "...", "certificador": "A|B|C", "criterios": {"T01": {"v": "P|F|N", "evidencia": [...]}}, "hallazgos": [{"id", "criterio", "severidad", ...}]}
Regla por criterio: votos P/F de los certificadores que lo evaluaron; se necesitan >= 2 votos (N o ausente = sin voto); gana la mayoría; empate 1-1 = N (cuenta como falla).
Decisión: PRESENTABLE si todos los BLOQUEA pasan, 0 ALTA abiertas y como máximo 3 MEDIA abiertas (cada una con razón escrita en el hallazgo, campo «razon_aceptada»).
Sale con 0 si es PRESENTABLE y con 1 si no."""
import argparse, json, re, sys
from collections import Counter


def severidades(doc):
    sev = {}
    for linea in open(doc, encoding="utf-8"):
        c = [x.strip() for x in linea.split("|")]
        if len(c) > 8 and re.fullmatch(r"[TCJVRHE]\d\d", c[1]) and c[6] in ("BLOQUEA", "ALTA", "MEDIA"):
            sev[c[1]] = c[6]
    return sev


def main():
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser()
    ap.add_argument("--doc", required=True)
    ap.add_argument("--in", dest="inp", nargs="+", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--hallazgos", default="")
    a = ap.parse_args()
    sev = severidades(a.doc)
    V = [json.load(open(f, encoding="utf-8")) for f in a.inp]
    avisos = []
    for k in ("rubrica_sha256", "commit"):
        if len({v.get(k) for v in V}) != 1:
            avisos.append("los certificadores no usaron el mismo %s: %s" % (k, [v.get(k) for v in V]))
    estado, filas = {}, []
    for cid in sorted(sev):
        votos = {v["certificador"]: v["criterios"].get(cid, {}).get("v", "N") for v in V}
        pf = [x for x in votos.values() if x in ("P", "F")]
        c = Counter(pf)
        if len(pf) < 2 or c["P"] == c["F"]:
            fin = "N"
        else:
            fin = "P" if c["P"] > c["F"] else "F"
        estado[cid] = fin
        filas.append("| %s | %s | %s | %s | %s |" % (cid, sev[cid], fin, " ".join("%s=%s" % kv for kv in sorted(votos.items())), "" if len({*pf}) <= 1 else "DISCREPANCIA"))
    ab = {s: [c for c in sev if sev[c] == s and estado[c] != "P"] for s in ("BLOQUEA", "ALTA", "MEDIA")}
    if a.hallazgos:
        hall = json.load(open(a.hallazgos, encoding="utf-8"))
    else:
        vistos, hall = set(), []
        for v in V:
            for h in v.get("hallazgos", []):
                k = (h.get("criterio"), h.get("titulo", h.get("id")))
                if k not in vistos:
                    vistos.add(k)
                    hall.append(h)
    media_h = [h for h in hall if h.get("severidad") == "MEDIA" and not h.get("cerrado")]
    con_razon = lambda h: bool(str(h.get("razon_aceptada", "")).strip())
    ligados = {h["id"] for h in media_h if h.get("criterio") in ab["MEDIA"]}
    n_media = len(set(ab["MEDIA"])) + len({h["id"] for h in media_h} - ligados)
    sin_razon = [h["id"] for h in media_h if not con_razon(h)] + [c for c in ab["MEDIA"] if not any(h.get("criterio") == c and con_razon(h) for h in media_h)]
    if len([h for h in hall if h.get("severidad") != "BAJA"]) > 7:
        avisos.append("la lista de hallazgos tiene más de 7 (máximo 7 por ronda; las BAJA van al backlog)")
    ok = not ab["BLOQUEA"] and not ab["ALTA"] and n_media <= 3 and not sin_razon and not avisos
    txt = ["# Veredicto consolidado", "", "Rúbrica: %s | commit: %s" % (V[0].get("rubrica_sha256", "?")[:12], V[0].get("commit", "?")), "",
           "**%s**" % ("PRESENTABLE (sin prueba humana: no certificado por humanos)" if ok else "NO PRESENTABLE"), "",
           "BLOQUEA abiertos: %s" % (ab["BLOQUEA"] or "ninguno"), "ALTA abiertas: %s" % (ab["ALTA"] or "ninguna"),
           "MEDIA abiertas: %d (máximo 3, cada una con razón escrita; sin razón: %s)" % (n_media, sin_razon or "ninguna")]
    txt += ["Avisos: " + "; ".join(avisos)] if avisos else []
    txt += ["", "| ID | Severidad | Final | Votos | Nota |", "|---|---|---|---|---|"] + filas
    open(a.out, "w", encoding="utf-8").write("\n".join(txt) + "\n")
    print("\n".join(txt[:9]))
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
```

</details>

<details>
<summary>A5 · Guardado y carga independientes (Godot, `qa_guardado.gd`)</summary>

```gdscript
# FILE: qa_guardado.gd
extends SceneTree
## Guardado y carga independientes de las pruebas de las pistas (docs/QA_NIVEL2.md, anexo A5). Solo usa la API del contrato 1 (3.2) y GameRules.save_game.
## Uso: godot --headless --path <SRC> --script <este archivo> -- --out=<json>   (APPDATA aislado: escribe en user://)
## Pasa si: el round-trip no cambia el estado, las 24 mutaciones obligatorias se rechazan con motivo y sin tocar el estado, y se rechazan >= 8 de las 13 deseables.
var out := {"checks": 0, "failures": [], "obligatorias": 0, "obligatorias_rechazadas": 0, "deseables": 0, "deseables_rechazadas": 0, "motivos": []}
var rules: RefCounted
const P := "user://qa_guardado.json"
const OBL := 18   # las mutaciones 0..17 son obligatorias (están en el contrato 3.2.4); 18..30 son deseables

func ck(c: bool, w: String) -> void:
	out.checks += 1
	if not c:
		out.failures.append(w)

func same(a: Variant, b: Variant) -> bool:
	if (a is float or a is int) and (b is float or b is int):
		return absf(float(a) - float(b)) <= 1e-6
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for k in a:
			if not b.has(k) or not same(a[k], b[k]):
				return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not same(a[i], b[i]):
				return false
		return true
	return a == b

func strip(s: Dictionary) -> Dictionary:
	var d: Dictionary = s.duplicate(true)
	for k in ["game_id", "previous_game_id", "state_version", "log"]:
		d.erase(k)
	return d

func unit(d: Dictionary, i: int) -> Dictionary:
	if d.units is Array:
		return d.units[i]
	return d.units[d.units.keys()[i]]

func mut(d: Dictionary, i: int) -> void:
	match i:
		0: d.scenario = "justine"
		1: d.scenario = "norte"
		2: d.schema_version = 99
		3: d.map_version = int(d.map_version) + 1
		4: d.units.pop_back() if d.units is Array else d.units.erase(d.units.keys()[0])
		5: unit(d, 1).id = unit(d, 0).id
		6: unit(d, 0).x = -5.0
		7: unit(d, 0).z = 9999.0
		8: unit(d, 0).stage = "volando"
		9: unit(d, 0).pace = "teletransporte"
		10: unit(d, 0).order = {"action": "hackear"}
		11: d.world.guardia = "furiosa"
		12: d.loot.total_value = 99.0
		13:
			d.loot.delivered_value = 80.0
			d.loot.destroyed_value = 30.0
		14: d.loot.load_kg = float(d.loot.capacity_kg) + 100.0
		15: d.alarm.first_shot_at = float(d.elapsed) + 500.0
		16:
			d.status = "victory"
			d.objectives.bateria.state = "guardado"
		17:
			unit(d, 0).stage = "moving"
			unit(d, 0).path = []
			unit(d, 0).order = {}
		18: unit(d, 0).strength = 500.0
		19: unit(d, 0).strength = -10.0
		20: d.objectives.bateria.toma = 500.0
		21: d.elapsed = -5.0
		22: d.elapsed = "abc"
		23: d.rng_state = "x"
		24: d.contract = 2
		25: d.erase("objectives")
		26: d.phase = "luna"
		27: d.status = "triunfo"
		28: d.objectives.cuartel.state = "destruido"
		29: unit(d, 1).men = -3
		30: d.world = []

func reset(good: String) -> Dictionary:
	var f := FileAccess.open(P, FileAccess.WRITE)
	f.store_string(good)
	f.close()
	rules.load_game(P)
	return strip(rules.snapshot())

func try_text(txt: String, name: String, obligatoria: bool, good: String) -> void:
	var before: Dictionary = reset(good)
	var f := FileAccess.open(P, FileAccess.WRITE)
	f.store_string(txt)
	f.close()
	var r: Dictionary = rules.load_game(P)
	var rech: bool = not bool(r.get("ok", false)) and str(r.get("reason", "")).strip_edges() != ""
	if obligatoria:
		out.obligatorias += 1
		out.obligatorias_rechazadas += 1 if rech else 0
		ck(rech, "obligatoria no rechazada con motivo: " + name)
	else:
		out.deseables += 1
		out.deseables_rechazadas += 1 if rech else 0
	if rech:
		ck(same(strip(rules.snapshot()), before), "el estado en curso cambió tras rechazar: " + name)
		if out.motivos.size() < 6:
			out.motivos.append("%s: %s" % [name, str(r.reason).substr(0, 80)])

func _initialize() -> void:
	var outp := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			outp = a.trim_prefix("--out=")
	var R = load("res://scripts/humahuaca/rules/humahuaca_rules.gd")
	rules = R.new()
	rules.new_game(9001, 1, {"skip_intro": true, "phase": "ataque"})
	rules.advance_to(float(rules.state.elapsed) + 45.0)
	ck(rules.save_game(P) == OK, "save_game devolvió error")
	var base: Dictionary = strip(rules.snapshot())
	var good: String = FileAccess.get_file_as_string(P)
	var other = R.new()
	var rl: Dictionary = other.load_game(P)
	ck(bool(rl.get("ok", false)), "load_game rechazó un guardado propio: " + str(rl))
	ck(same(strip(other.snapshot()), base), "el round-trip cambió el estado")
	var parsed: Variant = JSON.parse_string(good)
	ck(parsed is Dictionary, "el guardado no es un objeto JSON")
	var d0: Dictionary = parsed
	for i in range(31):
		var d: Dictionary = d0.duplicate(true)
		mut(d, i)
		try_text(JSON.stringify(d), "mutacion_%d" % i, i < OBL, good)
	try_text(good.substr(0, good.length() / 2), "archivo_truncado", true, good)
	try_text("esto no es json", "basura", true, good)
	try_text("", "vacio", true, good)
	try_text("[]", "arreglo_vacio", true, good)
	for esc in ["justine", "norte"]:
		var G = load("res://scripts/game_rules.gd").new()
		G.new_game(esc, 1806)
		G.save_game(P + ".otro")
		try_text(FileAccess.get_file_as_string(P + ".otro"), "guardado_de_" + esc, true, good)
	ck(out.obligatorias_rechazadas == out.obligatorias, "obligatorias rechazadas %d de %d" % [out.obligatorias_rechazadas, out.obligatorias])
	ck(out.deseables_rechazadas >= 8, "deseables rechazadas %d de %d (mínimo 8)" % [out.deseables_rechazadas, out.deseables])
	var f := FileAccess.open(outp, FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	print("QA_GUARDADO ", JSON.stringify(out))
	quit(0 if out.failures.is_empty() else 1)
```

</details>

<details>
<summary>A6 · Techo de etiqueta (`qa_etiquetas.py`)</summary>

```python
# FILE: qa_etiquetas.py
"""Verifica el «techo de etiqueta» (H01 de docs/QA_NIVEL2.md, anexo C.3): nada inventado figura como documentado. Solo lectura.
Uso: python -I qa_etiquetas.py --data <carpeta con data/humahuaca_*.json> --out <archivo.json>
Fuerza de la evidencia: documentado 4 > razonado 3 > discutido 2 > sin_datos 1 > diseno 0. Una etiqueta viola el techo si es MÁS fuerte que él.
Sale con 0 si no hay violaciones ni ids obligatorios sin etiqueta; con 1 si no."""
import argparse, json, pathlib, sys

ORDEN = {"documentado": 4, "razonado": 3, "discutido": 2, "sin_datos": 1, "diseno": 0}
HITOS = ["templo", "bateria", "cuartel", "posta", "torre_casa_cura", "torre_templo", "plaza", "polvorin", "parque", "corral_posta", "quebradita_norte",
         "quebradita_sur", "vado_este", "salida_este", "entrada_sur", "zona_partida", "spawn_rodriguez", "spawn_portal", "spawn_arias",
         "spawn_reconocedores", "spawn_arreo"]
GRUPOS = ["rodriguez", "portal", "arias", "reconocedores", "arreo"]
TECHO = {h: "diseno" for h in HITOS}
TECHO.update({"templo": "sin_datos", "torre_casa_cura": "sin_datos", "torre_templo": "sin_datos", "rio_grande": "sin_datos",
              "cerro_bateria": "diseno", "plataforma_bateria": "diseno", "cauce_rio": "diseno"})
TECHO.update({g: "diseno" for g in GRUPOS})                                                            # el reparto de hombres, armas y mulas es diseño
TECHO.update({v: "diseno" for v in ("guardia", "torre_en", "refugio", "lluvia", "refuerzo", "layout")})  # las variantes del mundo son diseño
TECHO.update({e: "diseno" for e in ("refuerzo_visto", "mensajero", "informante", "aviso_alba", "alba")})  # eventos de guion = diseño
OBLIGATORIOS = HITOS + GRUPOS + ["refuerzo"]


def walk(o, path, acc):
    if isinstance(o, dict):
        if "tag" in o:
            acc.append((str(o.get("id", path.split(".")[-1])), o, path))
        for k, v in o.items():
            walk(v, path + "." + str(k), acc)
    elif isinstance(o, list):
        for i, v in enumerate(o):
            walk(v, "%s[%d]" % (path, i), acc)


def main():
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", required=True)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    acc, viol, vistos = [], [], set()
    for f in sorted(pathlib.Path(a.data).glob("humahuaca_*.json")):
        if f.name == "humahuaca_height.json":
            continue
        walk(json.load(open(f, encoding="utf-8")), f.name, acc)
    for i, o, path in acc:
        t = o.get("tag")
        if t not in ORDEN:
            viol.append({"path": path, "id": i, "problema": "tag ilegal: %r" % (t,)})
            continue
        vistos.add(i)
        if "tag_parts" in o:
            tp = o["tag_parts"]
            if not isinstance(tp, dict) or len(tp) < 2 or any(v not in ORDEN for v in tp.values()):
                viol.append({"path": path, "id": i, "problema": "tag_parts inválido (≥ 2 partes con etiquetas legales)"})
            elif min(tp.values(), key=lambda v: ORDEN[v]) != t:
                viol.append({"path": path, "id": i, "problema": "tag %s no es la parte más débil de %s" % (t, tp)})
        techo = TECHO.get(i)
        if "fecha" in o and "9 al 16" in str(o.get("fecha")):
            techo = "discutido"
        if "carta" in i.lower():
            techo = "diseno"
        if techo and ORDEN[t] > ORDEN[techo]:
            viol.append({"path": path, "id": i, "problema": "etiqueta %s más fuerte que el techo %s" % (t, techo)})
    faltan = [i for i in OBLIGATORIOS if i not in vistos]
    res = {"entidades_con_tag": len(acc), "violaciones": viol, "obligatorios_sin_etiqueta": faltan}
    pathlib.Path(a.out).parent.mkdir(parents=True, exist_ok=True)
    json.dump(res, open(a.out, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("entidades con etiqueta: %d | violaciones: %d | obligatorios sin etiqueta: %d" % (len(acc), len(viol), len(faltan)))
    for v in viol[:20]:
        print("  VIOLA", v)
    for i in faltan[:30]:
        print("  FALTA etiqueta en", i)
    sys.exit(0 if not viol and not faltan else 1)


if __name__ == "__main__":
    main()
```

</details>

---

## Anexo B · Capturas obligatorias (V01)

Mínimo **12**, todas reales (ventana, no `--headless`), a JPEG ≤ 300 KB en `V01/capturas/` con `INDEX.json` (SHA-256 del PNG original). **Cada ítem se responde sí / no**; un «no» en cualquiera hace fallar V01 si lo dicen ≥ 2 certificadores. El orden de `Read` es M01 → M12, luego las extras.

| ID | Archivo de evidencia | Origen (crudo) | Resolución · momento | Lo que debe verse |
|---|---|---|---|---|
| M01 | `M01_llegada_nocturna.jpg` | `vista_acceso_so.png` del recorrido | 1920×1080 y 1280×720 · noche con lluvia, t = 0 | (a) la ladera occidental a un lado, el núcleo (≥ 3 edificios) y el templo al fondo; (b) el templo de nave con techo a dos aguas, **sin torres de campanas ni fachada monumental**; (c) lluvia visible y escena legible (suelo, edificios y ≥ 2 fichas distinguibles pese a la noche); (d) ni monumento, escalinata, postes, tendidos ni álamos; (e) la interfaz no tapa el núcleo |
| M02 | `M02_aproximacion_lluvia.jpg` | `hx-aproximacion-lluvia.png` de `ui_qa_humahuaca` | 1920×1080 · t ≈ 1:30–3:00 | (a) ≥ 3 de las 5 fichas con su anillo de visibilidad; (b) «Noche · Aproximación» y la barra del alba; (c) ruta dibujada con color de riesgo y su texto («llega en…, riesgo…»); (d) un solo aviso o alerta; (e) un rasgo del relieve legible (ladera, tapia o zanja) |
| M03 | `M03_desde_bateria.jpg` | `vista_desde_bateria.png` | 1920×1080 y 1280×720 · alba | (a) el pueblo «por debajo» hacia el este; (b) el río o el lecho claro al fondo; (c) el parapeto de la batería y ≥ 1 pieza en primer plano; (d) sin torres de 1880 |
| M04 | `M04_patio_posta.jpg` | `vista_patio_posta.png` | ídem · mañana | (a) muros del patio y ≥ 3 clases de objeto distinguibles (cargas, animales, polvorín o barriles); (b) solo colores de la paleta (adobe, madera, cuero); (c) se ve cuánto se carga (chip o panel) |
| M05 | `M05_torre.jpg` | `vista_grupos_en_accion.png` | ídem · alba, lluvia floja, torre disparando | (a) la torre se identifica (volumen vertical con plataforma) y se ve fuego o humo desde ella; (b) ≥ 3 fichas distinguibles; (c) líneas de fuego o marcas de impacto; (d) bajas o estado visibles |
| M06 | `M06_extraccion.jpg` | `hx-extraccion.png` | 1920×1080 · extracción con refuerzo visible | (a) mulas con bultos rumbo al vado este; (b) chips de carga, golpe y refuerzo; (c) el aviso «Polvareda al sur» o su indicador; (d) el río o el vado a la vista |
| M07 | `M07_alba.jpg` | `vista_panorama_alto.png` | ídem · alba | (a) la secuencia ladera → núcleo → monte ribereño → lecho claro → llanura → cerros → horizonte; (b) sin torres de campanas ni monumento; (c) luz cálida y sombras largas; (d) sin huecos ni borde del mundo |
| M08 | `M08_derrota.jpg` | `hx-derrota.png` | 1280×720 (y 1920×1080) · parte de derrota | (a) causa ≤ 140 caracteres con momento y lugar; (b) un consejo; (c) tres datos (frentes, golpe, bajas); (d) botón primario visible sin scroll; (e) sin jerga |
| M09 | `M09_victoria.jpg` | `hx-victoria.png` | ídem · parte de victoria | (a) la medalla con su motivo; (b) el epílogo fechado con sus etiquetas; (c) «Seguir: Sostener el norte» y «Jugar de nuevo»; (d) dice que Güemes **recibe** el parte (no que asaltó); (e) sin «expulsión definitiva» |
| M10 · M11 · M12 | `M10_hud_1280x720.jpg`, `M11_hud_1920x1080.jpg`, `M12_hud_2560x1440.jpg` | `hx-hud.png` | las tres resoluciones · mismo momento: semilla 9001, primera descarga + 20 s | (a) cabecera con «TIEMPO REAL · ▶ ×1» o «‖ EN PAUSA», la fase y la barra del alba; (b) tres tarjetas de frente; (c) panel de las cinco agrupaciones; (d) barra de acciones con su motivo; (e) minimapa con brújula y escala; (f) nada fuera del viewport ni solapado; (g) texto legible |

**Extras de apoyo** (no cuentan para el mínimo): `X01_menu_nuevo`, `X02_menu_desbloqueado` (C04), `X03_briefing`, `X04_hoja_fichas` (V03), `X05_overlay_lamina03` (R03), 3 capturas de calibración de día (V04) y 4 de límite de cámara (R06).

---

## Anexo C · Patrones y techos (H01–H03)

**C.1 · Lista A, anacronismos graves (H02, BLOQUEA).** Se corre con `grep -Ei` (extendido; las tildes van como alternativas porque el `grep` de Git Bash no pliega acentos): monumento y escalinata; torres de campanas, campanarios y fachada de 1880–81; bandera argentina o nacional, sol de mayo y sol en la bandera; cruz de Borgoña y bandera española actual; «coronel mayor» y «general Güemes»; chaqueta azul de húsar; Güemes o San Martín que dirigen, lideran, comandan, ordenan o asaltan; «orden táctica», «consecuencia de Chacabuco» y «Chacabuco hizo retirar»; «Infernales»; expulsión o victoria definitiva y fin de la invasión; álamos piramidales, eucaliptos, postes, tendidos, alumbrado, faroles, asfalto, empedrado y adoquín; ruta 9 o nacional, ferrocarril, telégrafo, alambrado, automóvil, tractor y luz eléctrica.

```sh
PAT_A='(monumento|escalinata|h(e|é)roes de la independencia)|(torres? de campanas?|campanarios?|dos torres|fachada (actual|neocl(a|á)sica|de 188[01]))|(bandera (argentina|nacional)|sol de mayo|sol en la bandera|bandera con sol|bandera del sol)|(cruz de borgo(ñ|n)a|bandera espa(ñ|n)ola)|(coronel mayor|general g(ü|u)emes|chaqueta azul|h(ú|u)sar)|((san mart(í|i)n|g(ü|u)emes) (dirig|lider|comand|encabez|orden(ó|o)|mand(ó|o)|asalt))|(orden t(á|a)ctica|consecuencia de chacabuco|chacabuco hizo retirar)|(infernales)|(expulsi(ó|o)n definitiva|expulsados? para siempre|victoria definitiva|fin de la invasi(ó|o)n)|((á|a)lamos? pir(a|á)mid|eucalipt|postes?\b|tendidos?\b|alumbrado|farol(es)?\b|asfalto|empedrad|adoqu(i|í)n)|(ruta (9|nacional)|ferrocarril|telegraf|alambrad|autom(ó|o)vil|tractor|luz el(é|e)ctrica)'
```

**C.2 · Lista B y textos obligatorios (H03, ALTA).**

```sh
PAT_B='(todos (los )?(infernales|de rojo|de blanco)|uniformes? (rojos?|blancos?|homog(é|e)neos?))|(tormenta (durante|todo|toda)|llov(í|i)a (todo|durante todo))|(ruta final de arias|paso de zenta|garc(í|i)a camba)|(cabildo|premio de humahuaca)'
```

Los **13 textos obligatorios** que verifica P9-c: la carta del 26-II como «dramatización»; la nota de fecha (1 o 2 de marzo); que el refuerzo no ocurrió o es diseño; que el relieve es «dato actual, no restitución»; el epílogo con «3 de marzo», «9 al 16 de marzo» y «6 de julio»; el botón «Seguir: Sostener el norte»; las etiquetas «Documentado», «Inferencia razonada», «Versión discutida» y «Sin datos suficientes» (la quinta, «Diseño», se comprueba por `source_tags`); y que Güemes **recibe** el parte en Salta. **Afirmaciones que el juego no puede hacer** (banco de `02_fuentes_primarias.md` §e.3): que Güemes lidera el asalto; que San Martín ordenó atacar Humahuaca; que el golpe fue consecuencia de Chacabuco; que Güemes ordenó tomar la batería, el cuartel y la posta; que Chacabuco hizo retirarse a La Serna; «General Güemes».

**C.3 · Techos de etiqueta (H01, BLOQUEA).** Fuerza: `documentado` 4 > `razonado` 3 > `discutido` 2 > `sin_datos` 1 > `diseno` 0. Una etiqueta **viola** el techo si es **más fuerte** que él (puede ser más débil). Se aplica a cualquier objeto con `id` y `tag` de los JSON `data/humahuaca_*.json` (menos el relieve numérico).

| Entidad o afirmación | Techo | Razón (diseño, sección 12.2) |
|---|---|---|
| `templo`, `torre_casa_cura`, `torre_templo`, `rio_grande` | `sin_datos` | forma del templo ○; cuál torre y dónde ○; cauce de 1817 y vados ○ |
| los otros 18 hitos (`bateria`, `cuartel`, `posta`, `plaza`, `polvorin`, `parque`, `corral_posta`, `quebradita_*`, `vado_este`, `salida_este`, `entrada_sur`, `zona_partida`, `spawn_*`) y las capas `cerro_bateria`, `plataforma_bateria`, `cauce_rio` | `diseno` | posiciones y cotas ▲ (no hay planta de 1817) |
| las 5 agrupaciones (`rodriguez`, `portal`, `arias`, `reconocedores`, `arreo`) | `diseno` | el reparto 48/52/50, las armas y las mulas propias ▲ |
| las 6 variantes del mundo y los eventos `refuerzo`, `refuerzo_visto`, `mensajero`, `informante`, `aviso_alba`, `alba` | `diseno` | incertidumbres convertidas en variantes ▲; el refuerzo realista inmediato **no ocurrió** |
| línea del epílogo «9 al 16 de marzo» | `discutido` | versión realista (La Serna) ◆ |
| todo lo que se llame «carta» | `diseno` | dramatización del 26-II |
| toda entidad con `tag_parts` | su parte más débil | regla del contrato (sección 0): ≥ 2 partes |

---

## Anexo D · Lo que el QA necesita de las pistas (pedidos Q1–Q7)

El contrato no fija los nombres de varias salidas que este documento mide. Son **pedidos del QA al integrador** (se registran como *addenda* en `docs/humahuaca/ADDENDA.md`; si la herramienta entrega lo mismo con otro nombre, se documenta el alias y el criterio no cambia). Deben existir **antes de R2**; lo que falte en el momento de exigirlo es N.

| # | Quién | Pedido |
|---|---|---|
| Q1 | `reglas_historia` | `tools/humahuaca_playthrough.gd` con las banderas `--level=scene` o `rules`, `--policies=<lista>` (`experto`, `obediente`, `torpe`, `ciego_sin_recon`, `ciego_tarde`, `ciego_un_frente`, `ciego_sin_arreo`, `pasivo`, `pausa_reanuda`, `aleatorio`, `interfaz`, y los alias `estrategias` = la matriz de ≥ 12 `est_*` y `parciales`), `--seeds=a-b` o `a,b,c`, `--attempts=N` (≤ 5; solo repite el intento quien perdió), `--replicas=N` (semilla propia del bot), `--out=<json>`. Misma entrada ⇒ mismos `snapshot_sha256`. Salida `hx_playthrough_v1` (abajo). La política `interfaz` hace clic en el botón de «siguiente paso». Con `--level=rules` no abre escena y corre `--headless`. |
| Q2 | integrador | `--qa=humahuaca` (= `hx_qa_tour.gd`) escribe en `--qa-path`: `vista_<id>.png` de las 5 vistas canónicas con interfaz; `calib_inicial.png`, `calib_patio_posta.png` y `calib_grupos.png` (luz de día, lluvia 0, sin interfaz ni fogonazos, cámara a ≥ 40° de inclinación para que no entre el cielo); `hoja_fichas.png` (5 celdas iguales en una fila, fondo liso, fichas al tamaño real de pantalla a 1280×720); `scene_names.txt` (nombres de nodos y rutas de recursos); `qa_report.json` con `initial_frame{fits, targets[{id, x, y, on_screen}]}`, `token_px[{id, w, h}]`, `templo_aabb_h_m`, `scene_build_ms` y `frame_ms_mean`. Más 4 capturas de cámara en el límite (`limite_n/s/e/o.png`). |
| Q3 | `ui_feel` | `tools/ui_qa_humahuaca.gd` con `--out`, `--size`; imprime `UI_QA {json}`; `ui_qa_report.json` con `suite`, `checks`, `failures` y `notes{captura_px, resolucion_real, controles_t0, caracteres_t0, jerga_hits_t0, menu_ultimo_y, menu_candado_nuevo, menu_desbloqueado, contraste_texto_min, rects{titulo, objetivo, siguiente, frente_bateria, alerta, accion_1}, reintento_s, ciclo_completo, token_px}`; capturas `hx-menu-nuevo`, `hx-menu-desbloqueado`, `hx-briefing-1`, `hx-aproximacion-lluvia`, `hx-hud` (semilla 9001, primera descarga + 20 s), `hx-extraccion`, `hx-derrota`, `hx-victoria`. Debe poder correr con `--size=1024x640`. |
| Q4 | todas | Cada `tests/test_hx_*.gd` imprime como última línea JSON `{"checks", "failures", "ok"}` (como las suites existentes); `test_hx_rules` incluye `performance` con `nav_build_ms_avg`, `plan_route_ms_avg`, `tick_ms_avg`. Las pruebas que provocan un error a propósito lo hacen **sin** `push_error`. |
| Q5 | integrador | Las banderas `--hx-seed=N`, `--hx-phase=<fase>` y `--hx-skip-intro` del contrato 4.3 (las usa el QA para fijar semilla y momento). |
| Q6 | `relieve_mapa` | Nada nuevo: el QA usa solo la API del contrato 3.1 (`load_default`, `height_at`, `height_dem_only`, `lamina_to_game`, `game_to_lamina`, `landmark`, `river`, `nav_grid`, `report`). Si cambia una firma, se avisa por *addendum*. |
| Q7 | integrador | `.gitignore` de `evidence/humahuaca/` cubre toda ronda intermedia (no solo `r1`–`r3`) y deja entrar a Git únicamente la de certificación; `docs/QA_NIVEL2.md` figura como propiedad del Jefe de QA. |

**Esquema `hx_playthrough_v1`** (un archivo por corrida; `qa_balance.py` junta varios):

```json
{"schema": "hx_playthrough_v1", "level": "rules", "engine": "4.7.2-stable", "games": [
  {"policy": "obediente", "family": "obediente", "seed": 9001, "replicate": 1, "attempt": 1, "status": "defeat", "cause_id": "frente_roto",
   "cause_text": "A los 5:10 la partida de Portal quedó clavada frente a la torre del cuartel.", "elapsed_s": 412.5, "golpe": 31.0, "loss_pct": 52.0, "fronts_taken": 1,
   "opening": "gola", "variant": {"guardia": "atenta", "torre_en": "templo", "refugio": "sur", "lluvia": "copiosa", "refuerzo": "normal", "layout": "A"},
   "first_decision_s": 22.0, "decision_gap_max_s": 31.0, "decision_gap_attack_max_s": 14.0, "exceptions": 0, "valid": true, "snapshot_sha256": "<64 hex>"}]}
```

`family` ∈ `experto`, `obediente`, `torpe`, `ciego`, `pasivo`, `pausa_reanuda`, `estrategia`, `parcial`, `aleatorio`. El *obediente* solo ejecuta lo que dice `hud_state().siguiente` y el *torpe* es el obediente con demoras de 2–8 s, ignora el 30 % de los avisos no urgentes y falla la sincronía ± 15 s (diseño, sección 10); ninguno de los dos lee estado oculto.

---

## Anexo E · Sesión humana opcional (para quitar el sello «no certificado por humanos»)

La corre el usuario o quien designe, **fuera del circuito**; no es condición de «presentable» (L1). **Tres personas** que no conozcan el juego, 20 minutos cada una, sin ayuda, con el EXE de la entrega en `--scenario=humahuaca`. Se registra: (1) el segundo en que dieron la primera orden (≤ 30 s); (2) si pueden decir **el objetivo con sus palabras** sin leer la ayuda; (3) la pregunta «¿entendiste qué hacer?» y (4) «¿cuándo te aburriste?» (minuto y qué pasaba); (5) cuántas veces perdieron y si entendieron la causa. Se agrega el sello «certificado por humanos» solo si **≥ 2 de 3** dieron la primera orden en ≤ 30 s **y** pudieron decir el objetivo, y **ninguna** dejó de jugar antes del minuto 10. Si el modelo y las personas discrepan, **manda la sesión humana**: el resultado va a un hallazgo con evidencia y entra por la regla 1.

---

## Anexo F · Historial de enmiendas y estado de las herramientas

**Enmiendas:** ninguna. (Formato: `N · fecha · qué cambia · motivo y evidencia · quién la pidió`; el commit se titula «QA enmienda N: …».)

**Estado al congelar (1-nov-2026, `main` en `5a84c50`).**

- **Probado al escribir este documento** (con `APPDATA` aislado, el worktree sin cambios): `test_rules` 871/0 (3 min 02 s); `test_integration` 283/0 (11 s); `jev_contract_test` 15/0; `audio_runtime_test` «17 comprobaciones, 1 fallas» (Dummy) con salida 1; `justina_playthrough` salida 0 en 5 min (18 victorias, 3 rutas, 6 derrotas, `ui_real` gana); el EXE `0.4.0-preview5` con `--headless --verbose --quit-after 120` sin errores ni fugas (y su SHA-256 coincide con su `SHA256.txt`); la lista de 40 archivos protegidos contra `5ebbd28` (salida 0); las expresiones regulares de errores y de fugas dan 0 sobre todos esos logs; los 24 HEX de la lámina 06, **24 de 24 exactos** sobre sus píxeles; la calibración de la lámina 03; `qa_relieve.py`, `qa_imagen.py`, `qa_balance.py`, `qa_veredicto.py`, `qa_etiquetas.py` y `qa_guardado.gd` contra datos sintéticos, la lámina 03 y los *mocks* descritos arriba; los 15 bloques de shell de este documento pasan `bash -n`; las herramientas extraídas de este texto son idénticas, byte a byte, a las probadas.
- **No probado, porque todavía no existe** (lo crean el commit de andamiaje T0 y las rondas R1 y R2): `scripts/humahuaca/**`, los cinco JSON del nivel, `tests/test_hx_*.gd`, `tools/humahuaca_playthrough.gd`, `tools/ui_qa_humahuaca.gd`, `tools/hx_qa_tour.gd`, `tools/vis_humahuaca.gd`, `tools/qa_gate.sh` y los pedidos Q1–Q7. Los comandos que dependen de ellos están escritos contra el contrato 1 y contra las firmas de Q1–Q7; hasta que existan, esos ítems son «no exigibles aún» (escalera de la sección 2), no fallas. Si al correrlos una firma real difiere de la del contrato, se corrige **el script o el pedido**, no el umbral.
