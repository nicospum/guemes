# P4 · Interfaz, menú, flujo entre niveles y claridad de los niveles I y III

Pista P4 de la tanda 2 (entrega «equipo 2026-11-08»). Rama `equipo/p4-interfaz` desde `equipo/integracion` (70b2341), con `equipo/integracion` mezclada después de integrar P1 (3ea36d8). Archivos tocados: `scripts/main.gd`, `scripts/game_rules.gd`, `scripts/campaign.gd`, `tests/test_integration.gd`, `tests/test_rules.gd`, `tools/ui_qa.gd`, `tests/revision_nube/f_start_game_con_hx_vivo.gd`. No toqué `world_view.gd`, `scripts/humahuaca/**`, `data/humahuaca_*` ni shaders.

Evidencia fuera de Git, en `../qa-equipo/p4/` (capturas reales con ventana, perfil `APPDATA` aislado):
- `hojas/cmp_1440x900_*.png` y `hojas/cmp_1280x720_*.png`: nueve pares antes/después con el mismo encuadre (menú, tarjeta inicial, primer cuadro, briefing, victoria y derrota de la Justina, Norte, cierre del Norte y menú tras el Norte). «Antes» = 70b2341. «Después» = esta rama con P1 integrada: el fondo 3D del menú y del Norte es trabajo de P1, y la interfaz es de P4.
- `antes_despues*/…_metricas.json`: % de pantalla tapado por el HUD y texto y botones visibles en el primer cuadro.
- `recorrido/r00…r40*.png` + `recorrido_log.txt`: recorrido completo menú → I → II → III → final.
- `ui_qa_*`: capturas e informe de `tools/ui_qa.gd` en las tres resoluciones. `justina_playthrough.json`.
- `scripts/p4_capturas.gd`, `scripts/p4_recorrido.gd`, `scripts/hojas.py`: con ellos se repite todo (el uso está en el encabezado de cada uno).

## Tickets

| Ticket | Estado | Qué se hizo | Prueba |
|---|---|---|---|
| T-001 | **cerrado** | `_start_game` y `_load_game` llaman a `_stop_humahuaca()`. Además, `_stop_humahuaca` saca el controlador del árbol en el mismo cuadro, así su WorldEnvironment, su sol y la lluvia no conviven con los del nivel siguiente. | `f_start_game_con_hx_vivo` 12/0 (caso «norte» nuevo: un solo WorldEnvironment, sin `lluvia_rayas`, far 400). `test_integration::_transiciones`. En el recorrido, al entrar al III hay 1 ambiente, `hx` en null y far 400. |
| T-003 | **cerrado** | `_menu()` pasa a `mode="menu"` antes de reponer `content_scale_factor`. | `e_escala_doble_tras_justina`: 0 fallas (1,00 y 1,00; cabecera 57,5 y 57,5 px). Comprobación en `_transiciones`. |
| T-004 | **cerrado** | `_menu()` repone `camera.far = 4000` y fov 46. | `_transiciones`. Métrica `menu_cam_far_tras_norte`: 400 antes y 4000 después. Ver `hojas/cmp_*_99_menu_tras_norte.png`. |
| D-03 | **cerrado (parte P4)** | Al ganar la Justina, el botón principal dice «Seguir: Humahuaca (nivel II)»; el III queda en «Más opciones». `campaign.gd` muestra «Se abrió el nivel II: Humahuaca, 1817 (y el III…)». En el menú, el II aparece como «RECOMENDADO AHORA» tras la Justina y el III como «RECOMENDADO AHORA» tras Humahuaca. La salida `exited("norte")` del II arranca el III limpio. | `test_integration::_campana`; recorrido por botones (r12 → r20 → r21 → r30). |
| D-04 | **cerrado** | Al terminar el III, gane o pierda, se abre la pantalla final a pantalla completa: «En tu partida» (I, II y III, tomados del progreso) frente a «En la historia» (cinco renglones con etiqueta documentado/tradición/diseño). Incluye «Volver al menú», «Jugar el II» si el II no se jugó y «Ver fuentes». `campaign.record_north()` guarda el desenlace. | `_campana` (texto, etiquetas, sin frases vedadas, sin scroll). Capturas `cmp_1280x720_31_norte_cierre.png` y `recorrido/r33`. |
| D-05 | **cerrado** | `game_rules.north_victory_progress()`, de solo lectura, muestra cada indicador con su «meta ≤ 22/42/45», «Presión: x de 7» y «no antes del 12 de abril (ronda 10)». La barra mide lo que falta y llega a lleno solo en la ronda de victoria. | `test_rules::_test_north_victory_bar`: 120 campañas, barra llena en 65 de 65 victorias y nunca antes. |
| D-07 | **cerrado** | Hay un solo mensaje guía. Hasta la primera acción se pliegan ×2/×4, el diario, el ajuste de tropas, la barra del minimapa, la captura en 0 %, la ficha repetida de la selección y la ayuda de F1. La fila «con riesgo» aparece cuando el vado cede. Se quitó «Seguí la guía de arriba». «río» en vez de «marea». | Primer cuadro: **746 caracteres y 16 botones** (antes 1301 y 29, o sea 57 % y 55 %). `ui_qa` (comprobación nueva) e integración. |
| D-09 | **cerrado** | En las rondas 1 y 2, «Siguiente paso · Arias reconoce la Quebrada…» trae el botón «Preparar la orden sugerida» (`north_next_step()`, siempre legal). «Jev» solo aparece si hay una clave configurada. | `_campana`; `test_rules` (la sugerencia es legal y prepararla funciona). |
| D-12 | **cerrado** | Si el perfil ganó el II, el III empieza con «Ya viviste esa noche en Humahuaca: acá es una operación más de la campaña.» Es solo texto y no cambia reglas. | Por inspección: lee `humahuaca_progress.json`. No tiene prueba propia. |
| D-10 | **abierto** | Mostrar la intención del invasor cuando hay reconocimiento: no llegué. | — |
| V-01 (menú) | **cerrado (parte P4)** | Pose de cámara del prototipo, tomada de `world.menu_camera_pose()` de P1 si existe, con deriva lenta de ±0,04 rad en 30 s. Degradé de tinta en lugar del panel plano. Los niveles son tarjetas de capítulo con numeral romano en Cinzel, título, año y estado (empezá acá / en curso / recomendado / ganada / con candado). Se llama a `world.set_look("menu")`. | `hojas/cmp_*_00_menu.png`, `recorrido/r40`. |
| V-05 | **cerrado** | Paleta «Crónica en oro y noche» con los HEX de la dirección (tabla abajo), esquinas de 2 px, rótulos en Inter 600 y Cinzel espaciado. Los aliados van en celeste e identifican al grupo con el glifo; los avisos van en ámbar. Briefing, tarjeta inicial y partes de la Justina se muestran como documento a pantalla completa, con doble filete y esquinas; la derrota va en ámbar y pergamino. El HUD del I tapa **20,3 % a 1440×900** (antes 34,9 %) y 27,1 % a 1280×720 (antes 46,9 %). | `ui_qa` ×3; métricas. |

Del playtest de línea de base (`qa-equipo/playtest/LINEA_BASE.md`), pedidos por el lead:

| Ticket | Estado | Qué se hizo / prueba |
|---|---|---|
| P-001 ALTO (III) | **cerrado** | La ayuda bajo la bandeja tiene alto fijo (3 renglones, 58 px), así el panel ya no crece bajo el cursor. Prueba: en `_campana`, el botón «Reconocer» y «Resolver ronda» quedan en el mismo rectángulo antes y después de pasar el mouse. |
| P-003 (I) | **cerrado** | Si se cierra con Esc la ventana de una decisión, el reloj sigue detenido y queda el aviso permanente «Hay una decisión esperando» con el botón «Ver la decisión», que la reabre. Prueba en `_campana`. |
| P-004 (I) | **cerrado** | El aviso de campo sigue bajando a ×1 (diseño C19). La velocidad elegida vuelve sola 8 s después, si no hay avisos, y lo anuncia. Elegir otra velocidad cancela el regreso. No tiene prueba automática. |
| P-005 (I) | **parcial** | Si un grupo aborda y no puede rechazar el contraataque (por ejemplo, sin munición), el aviso lo dice y ya no muestra un botón apagado. No investigué el «El grupo rechaza…» simultáneo. |
| P-007 | **cerrado** | Decisión del lead: el III se abre al ganar la Justina o Humahuaca. `_sync_north_unlock()` lo fija en `campaign.json` al volver del II. La tarjeta I usa `justina_won`, así que ganar el II no da por ganada la Justina. Prueba `_norte_por_humahuaca`. |
| P-009 (III) | **cerrado** | La derrota distingue «perdió sus agrupaciones» de «las poblaciones ya no pueden sostener la defensa (apoyo x %)». Prueba en `test_rules`. |
| P-010 (III) | **cerrado** | «Operar en Humahuaca» dice si falta elegir a Arias o el sector. Prueba en `_campana`. |
| P-012 | **cerrado** | Lo cierra D-03: ya no aparece «escenario 2». |
| P-013, P-014, P-016 | **cerrados** | Las bajas usan el mismo redondeo; «LO APRENDIDO» nunca queda vacío; la ayuda del III ya no muestra rutas de archivo. |
| P-015, P-017, P-018, P-019 | abiertos | No llegué. P-018 y P-019 mejoran en parte con el HUD nuevo y los documentos a pantalla completa. |

## Paleta común (la misma que debe usar P5 en el II)

Tinta noche `#0E0C12` · tinta panel `#16131C` (alfa 0,86–0,88) · tinta violácea `#241D2C` · filete `#5C4A2E` · oro viejo `#C9A25E` · oro luz `#E8CC8A` · violeta `#7A5BB5` · violeta hondo `#3B2A5C` · pergamino `#ECE3CF` · pergamino apagado `#A79F92` · rojo realista `#B8433A` (solo el enemigo; en texto sobre tinta, `#D0604F`) · ámbar `#D9903A` (avisos, riesgo y derrota) · salvia `#8FB89A` · celeste patriota `#8DB8D6` (exploradores `#A9CBE2`) · hueso `#BFB6A3`. Esquinas de 2 px. Botones: normal `#1B1722`, hover `#2A2233` con borde oro, presionado `#3B2A5C` y deshabilitado `#141118`. Están como constantes al principio de `main.gd`.

## Pruebas (cifras de la última corrida, sobre `b91d933`)

| Suite | Resultado | Piso |
|---|---|---|
| `tests/test_rules.gd` | **877 / 0** | ≥ 871 |
| `tests/test_integration.gd` | **317 / 0** (+34: transiciones, campaña, playtest) | ≥ 283 |
| `tests/jev_contract_test.gd` | 15 / 0 (sin llamadas vivas) | — |
| `revision_nube/f_start_game_con_hx_vivo` | 12 / 0 | — |
| `revision_nube/e_escala_doble_tras_justina` | 0 fallas | — |
| `tools/ui_qa.gd` 1280×720 / 1920×1080 / 2560×1440 | **254 / 0** en las tres (capturas al tamaño pedido) | ≥ 254 |
| `tests/test_hx_smoke.gd`, `tests/test_hx_flow.gd` (de otras pistas; corridas para ver que el menú nuevo no las rompe) | 0 fallas (flow 287) | — |
| `tools/justina_playthrough.gd` (sobre `4eee952`; lo posterior es solo cosmético) | **sale con 0**: 18 victorias y 6 derrotas en las políticas clásicas × 3 semillas; la política `ui_real` (clics y teclas reales) **gana** | gana |

**Recorrido completo, una sola sesión y por botones** (`recorrido_log.txt`): I victoria → «Seguir: Humahuaca» → II victoria con la política experta (626 pasos) → «Ver la campaña completa: Sostener el norte» del parte del II → III en juego (1 ambiente, far 400, sin `hx`) → victoria en la ronda 11 con la estrategia `scout_raid_protect_humahuaca` de `test_rules` → pantalla final → «Volver al menú» (far 4000, escala 1,00, III «GANADA»). **Límite:** la victoria del I se fija en el estado, como en `ui_qa`. La victoria jugada sobre la escena real la prueba `justina_playthrough`.

**Textos de pruebas que cambié a propósito**, verificando lo mismo con el texto nuevo:
- «Ir a Sostener el Norte» / «Ir a la campaña del norte» pasan a «Seguir: Humahuaca» en `test_integration` y `ui_qa` (D-03).
- «Se desbloqueó el escenario 2» pasa a «Se abrió el nivel II» en `test_rules` y `ui_qa`.
- «Seguí la guía» pasa a «la línea queda vacía y oculta con el tutorial»: es el mismo «un solo mensaje», ahora más estricto. El motivo de bloqueo con el tutorial en pantalla se verifica en la ayuda emergente del botón (D-07).
- En `ui_qa`, al plegar la barra del minimapa el bucle de paneles visibles cuenta 2 comprobaciones menos. Agregué 2 comprobaciones del cambio (HUD ≤ 25 % y un solo mensaje): son 254.

## Crítica honesta de las capturas

- **Menú:** es el cambio más grande. Con el atardecer de P1 se ve como un cuadro (`recorrido/r40`). El rótulo «RÍO DE LA PLATA · 12 DE AGOSTO DE 1806» se lee poco sobre el agua brillante. El texto de la tarjeta, oculto para las pruebas, sigue siendo el viejo: lo exigen `test_hx_smoke` y `ui_qa_humahuaca`.
- **Juego I:** el mapa queda libre y hay un solo mensaje. Pendiente: la bandeja inferior conserva su ancho fijo aunque muestre 3 botones, y el título «JUSTINA · RETIRO» se recorta en la cabecera a 1280×720. Las insignias pastel sobre las fichas, que dibuja `main.gd`, ya usan el celeste; los anillos 3D son de P1.
- **Briefing a pantalla completa:** se usan los textos de hoy, pero la pestaña deja un tercio vacío abajo (P-019). No es todavía la composición del mockup 05 (escena, recursos, enemigo, cronología): hoy es un documento centrado sobre la escena entintada.
- **Partes:** se leen como documento y la derrota ya no va en rojo. Faltan el icono de medalla y la cita con fuente que pide D5.
- **III:** la bandeja inferior es unos 25 px más alta por la ayuda de alto fijo (P-001): es el precio de que no salte. El panel «Situación» quedó denso.
- **Pantalla final:** entra sin scroll a 1280×720. Los renglones históricos usan solo lo etiquetado en `data/history.json` y CLAUDE.md. Conviene que la revise el QA de historia.

## Pedidos a otras pistas

- **P5 (parte del II):** cuando el II termina en victoria, el botón principal tiene que ser el que dispara `exited("norte")` («Seguir: Sostener el norte»), y «Jugar de nuevo» el secundario. `main._on_hx_exited("norte")` ya libera el II, fija el desbloqueo del III (P-007) y arranca el III limpio. La paleta común está arriba. La tarjeta del menú lee de `humahuaca_progress.json` solo `won`, `best_medal`, `best_golpe` y `attempts`: si cambian esos nombres, avisen.
- **P1:** el celeste de los íconos de la interfaz ya coincide con el de las fichas (`#8DB8D6` / `#A9CBE2`). Con P1 integrada uso su viñeta por look y apago la mía (nunca hay dos). La pose del menú sale de `menu_camera_pose()`.
- **Lead / QA:** `tools/qa_gate.sh` (paso «compartidos», tope T01 del nivel II) limita `main.gd` a +80/−10 líneas y `test_integration.gd` a +6/−2. Esta pista los supera por encargo (menú, HUD, final). Hay que decidir si ese tope sigue rigiendo para la entrega de equipo.
- **Lead:** `tests/revision_nube/e_*` y `f_*` figuran en el backlog como de P5. Por encargo toqué solo `f_start_game_con_hx_vivo.gd` (caso «norte»).

## P4b · Pulido de interfaz y claridad de los niveles I y III

Pista P4b, continuación de P4. Rama `equipo/p4b-pulido` desde `equipo/integracion` (3a695b4), con `equipo/integracion` mezclada después de que entró P3 (35de1ea). Archivos tocados: `scripts/main.gd`, `scripts/game_rules.gd`, `data/history.json`, `tests/test_integration.gd` y `tests/test_rules.gd`. No toqué `world_view.gd`, `scripts/looks/*`, `scripts/humahuaca/**` ni `data/humahuaca_*`.

Evidencia fuera de Git, en `../qa-equipo/p4b/`:
- `hojas/cmp_1280x720_*.png` y `hojas/cmp_1440x900_*.png`: catorce pares antes/después con el mismo encuadre. «Antes» = 3a695b4, «después» = esta rama. Pantallas: menú, tarjeta inicial, primer cuadro, briefing, contraataque (aviso y ya rechazado), victoria y derrota de la Justina, Norte, Norte con reconocimiento, «Consecuencias de la ronda», derrota y cierre del Norte, menú tras el Norte.
- `antes_despues_<WxH>/<tag>_metricas.json`: textos recortados por pantalla (auditoría automática) y el estado de los carteles del contraataque.
- `ui_qa_<WxH>/`: capturas e informe de `tools/ui_qa.gd` en las tres resoluciones. `justina_playthrough.json`. `hx_primera_entrada.txt`: medida del precalentado del II.
- `scripts/p4b_capturas.gd`, `scripts/hojas.py`, `scripts/hx_primera.gd`: con ellos se repite todo (el uso está en el encabezado de cada uno).

### Qué se hizo

| Objetivo / ticket | Estado | Qué se hizo | Prueba |
|---|---|---|---|
| 1 · Recortes de texto | **cerrado** | Menú: la tarjeta del I pasa a título corto «La Justina» con el subtítulo «El río ofrece una oportunidad»; el II, «Tras la Justina · el golpe de Arias»; el III bloqueado, «Ganá el I o el II para abrirlo». El texto llano del botón no cambió. Cabecera del I: el título ya no se recorta (la cabecera crece hacia los dos lados). Ficha elegida del I: la fuerza baja al segundo renglón (se cortaba el «%»). Botón de orden: si el costo no entra («Sondeo cauteloso … ×0.7 de v»), queda la primera cifra y el resto va a la ayuda emergente. Parte del III plegado: el último renglón se lee entero. | Auditoría de recortes de `p4b_capturas.gd` (Label, Button y RichTextLabel visibles cuyo texto no entra en su caja) en 14 pantallas: **16 recortes antes, 0 después**, a 1280×720 y a 1440×900. |
| 2 · Briefing del I con la composición del mockup 05 | **cerrado** | La tarjeta inicial y el briefing usan una pantalla de misión, la misma composición que el briefing del II (P5): rótulo «CAPÍTULO I», título en Cinzel, la misión y «Tus fuerzas» (las cinco agrupaciones con tipo y fuerza) a la izquierda; enemigo (buque, 26 cañones, dotación, moral y peligro de fuego), reloj del río (bajante, vado, sin retorno y plazo, rotulado ▲ diseño) y cronología de 1806 (rotulada ● documentado, Gillespie) a la derecha; la cita al pie de la izquierda; los botones abajo a la derecha, con «Empezar» o «Jugar (empieza en pausa)» como botón principal. En el briefing, las cuatro pestañas de siempre ocupan la columna central (se fue el tercio vacío). El HUD se apaga detrás y queda la escena. | `test_integration` (los cinco bloques y la cita con fuente; el mensaje sigue corto); `ui_qa` ×3 (tarjeta, briefing y «Jugar» entran en pantalla). Hojas `cmp_*_10_justina_tarjeta` y `cmp_*_12_justina_briefing`. |
| Cita con fuente | **cerrado** | Tres fragmentos de Gillespie (1818) cotejados con el OCR local según `docs/historia/FUENTES.md` (S9) y la matriz: pp. 35-36 («un buque de fuerza quedó inesperadamente en seco…», briefing), p. 94 («un buque abordado y tomado por caballería», victoria) y pp. 35-36 («la profundidad del río a veces sube o baja siete u ocho pies…», derrota). Van como «traducción del juego». No hay citas inventadas. | Por inspección contra `FUENTES.md` y `MATRIZ_HISTORICA.md`; conviene que lo mire el QA de historia. |
| 3 · Partes de victoria y derrota del I | **cerrado** | Misma composición. Medalla dibujada en código (cinta oro y violeta, disco del color de la medalla y estrella); en la derrota, disco vacío en ámbar con el signo de la causa (olas para el río y el plazo, aspa para la cubierta, banderín para la retirada). La derrota enseña como la del II: «Qué pasó» (la causa) con «Cuándo: a los 18:00, en el cruce» (de `defeat_moment`), «Para el próximo intento» («Probá esto…»), cifras del intento, lo aprendido y «Reintentar» abajo a la derecha. «Más opciones» sigue plegado. | `ui_qa` (las mismas comprobaciones de R1/R2/R3 de los partes) y `test_integration`. Hojas `cmp_*_13` y `cmp_*_14`. |
| 4 · P-005 (I) | **cerrado** | La pausa automática recuerda qué aviso la pidió; si el aviso ya no está (el contraataque se rechazó o la ventana pasó), el cartel de pausa no lo sigue pidiendo. El cartel usa los segundos que quedan, no la ventana entera. El botón dice «✓ Contraataque rechazado» en vez de quedar gris con el rótulo de rechazar. El paso del tutorial «Abordaje: … rechazalo» se da por hecho con el primer rechazo. | `test_integration::_p4b`; hoja `cmp_*_16_justina_contraataque_rechazado` (a la vista quedan solo el aviso «El grupo rechaza el contraataque» y el botón). |
| 5 · D-10 (III) | **cerrado** | `game_rules.north_enemy_intel()`: con un «Reconocer» vigente en el sector donde está el invasor (la misma ventana de tres rondas que usa el hostigamiento informado), el panel «Situación» muestra «◈ INTENCIÓN DEL INVASOR · Escoltar convoyes esta ronda · lo sabés por el reconocimiento de Quebrada (vale hasta la ronda 4)». Sin él: «no se sabe; reconocé Quebrada, donde está». Con inteligencia, la ronda se resuelve con esa misma intención (`north_intent_for_round`) y no se consulta a Jev. | `test_rules::_test_north_intel`: 150 campañas al azar, coincide en el 100 % de las rondas con inteligencia y no cambia al dar órdenes. `test_integration::_p4b`: lo mismo por el camino real de la interfaz (`_resolve_round`). |
| 6 · P-015 (I) | **cerrado** | Un intento de la Justina que no se jugó (sin reloj, órdenes ni sondeos) se descuenta al volver al menú o al empezar otro. | `test_integration::_p4b`. |
| 6 · P-017 (III) | **cerrado** | Si una ronda se resuelve sin ninguna orden, el aviso lo dice («Esta ronda pasó sin órdenes: nadie hostigó ni protegió víveres…») y cuenta las seguidas. No traba la partida. | `test_integration::_p4b`. |
| 6 · P-018 (I) | **cerrado en lo que quedaba** | Con P4 las fichas ya no se pisaban entre sí. Ahora tampoco tapan el casco en el abordaje: se corren y quedan unidas por su línea. «Sondeo cauteloso» ya no se corta. Los tres carteles apilados de la pausa automática pasan a uno (P-005). | Hojas `cmp_*_11` y `cmp_*_15`; auditoría de recortes. |
| 6 · P-019 (I / III) | **cerrado** | La tarjeta, el briefing y los partes del I son pantallas de misión sin tercio vacío. Las ventanas chicas se ajustan al alto de su contenido («Consecuencias de la ronda» del III dejaba ~200 px vacíos). La pantalla final del III ya entraba sin hueco (P4). | `test_integration::_p4b`; hoja `cmp_*_34_norte_consecuencias`. |
| 7 · Cámara del I a 50° | **verificado** | La cámara de juego a 50° (cambio del lead en `data/justina_map.json`) no rompe nada: el primer cuadro muestra la barranca, los grupos y el buque, y `ui_qa` pasa en las tres resoluciones. No hizo falta tocar `justina_map.json`. | `ui_qa` ×3; hoja `cmp_*_11_justina_primer_cuadro`. |
| Pedido del lead: H03 en `data/history.json` | **cerrado** | La nota de la fecha de Humahuaca dice «el 2, en la versión de La Serna y en una inscripción del premio», con el mismo criterio que P3 en `humahuaca_rules.json`. No cambia lo que afirma. | `grep` sin «según La Serna» en `data/history.json`. |
| Pedido del lead: primera entrada al II | **cerrado** | Al abrir el juego se cargan en un hilo los seis sombreadores del II y se dibujan juntos tres cuadros en cuadritos de 2 cm pegados a la cámara, detrás de un velo de tinta de ~0,4 s que se desvanece. Solo cargarlos no servía: la compilación ocurre al dibujar. El benchmark del II espera el precalentado antes de abrir el nivel, como un jugador que pasa por el menú. | `hx_primera_entrada.txt`, caché vacía, 5 corridas cada uno: construcción **1 432 → 1 251 ms** de media; primer cuadro del nivel ~140 → ~90 ms; peor cuadro del menú después del velo 9 → 5 ms. |

### Pruebas (cifras de la última corrida, sobre e1efe4b, con `equipo/integracion` mezclada)

| Suite | Resultado | Piso |
|---|---|---|
| `tests/test_rules.gd` | **884 / 0** (+7: D-10) | ≥ 877 |
| `tests/test_integration.gd` | **330 / 0** (+13: `_p4b` y la composición de la tarjeta) | ≥ 317 |
| `tests/jev_contract_test.gd` | 15 / 0 (sin llamadas vivas) | — |
| `tools/ui_qa.gd` 1280×720 / 1920×1080 / 2560×1440 | **254 / 0** en las tres (capturas al tamaño pedido) | ≥ 254 |
| `tools/justina_playthrough.gd` (con ventana) | **sale con 0**: 18 victorias y 6 derrotas en las políticas clásicas × 3 semillas; la política `ui_real` (clics y teclas reales) **gana** en las tres semillas | gana |
| `tests/test_hx_smoke.gd` (158 / 0) y `tests/test_hx_flow.gd` (303 / 0), de otras pistas | corridas para ver que el menú, el velo y la pantalla de misión no las rompen | — |

Todas con perfil `APPDATA` aislado y borrado al terminar. Otros agentes corrían Godot en paralelo.

### Textos de pruebas que cambié a propósito

- `test_integration` («R1: la tarjeta inicial es corta»): la tarjeta pasó a ser la pantalla de misión y suma a los costados las fuerzas, el enemigo, el reloj del río, la cronología y una cita, que son datos de consulta. El tope sigue en 900 caracteres, pero se mide sobre el mensaje (los textos con formato y los botones) y no sobre los rótulos y ayudas emergentes de esos paneles. Además se agregó una comprobación de que están los cinco bloques del mockup. La comprobación paralela de `ui_qa` (texto con formato menor de 700) no cambió y sigue pasando.
- `test_integration` («R5: el panel de objetivo no se atenúa»): con la pantalla de misión abierta, el HUD se apaga a propósito (queda solo la escena detrás, como en el II). La comprobación acepta ese caso y sigue exigiendo que fuera de la pantalla de misión no se atenúe.
- Menú: cambian solo los rótulos visibles de las tarjetas. El texto llano del botón, que leen `test_integration`, `ui_qa`, `test_hx_smoke` y `ui_qa_humahuaca`, es el mismo.

### Crítica honesta de las hojas

- **Tarjeta y briefing:** ahora se parecen al briefing del II y al mockup 05: escena detrás, columnas a los costados, cita con fuente y la acción principal abajo a la derecha. Es un salto grande frente al documento centrado de P4. Límites: la escena detrás es el encuadre de juego (agua, aro de fuego y medio casco tapado por la columna derecha), no una escena compuesta como la del mockup; no hay brújula con minimapa ni las «tres decisiones» del mockup, porque la Justina no tiene esa elección al empezar. A 1280×720 la columna derecha queda justa (enemigo, río y cronología llegan a ~20 px del pie). En el briefing, el renglón «OBJETIVO» y el texto «Tomar el buque…» se repiten un poco con el título.
- **Partes:** se leen como el parte del II y la derrota enseña (qué pasó, cuándo y qué probar). La medalla dibujada es sobria y se lee bien. En la victoria el centro queda vacío a propósito para ver el buque, pero con la cámara del parte el buque queda medio tapado por la columna derecha. «Cuándo» repite la hora cuando la causa ya la dice («Se acabó el tiempo a los 18:00»).
- **Contraataque:** quedan un solo aviso y un botón coherentes. La línea «AHORA» de la bandeja sigue diciendo la consigna general del abordaje («rechazá los contraataques…»), que no contradice, pero es genérica.
- **Menú:** las tres tarjetas se leen enteras. «Tras la Justina · el golpe de Arias» es más corto que antes, pero dice lo mismo.
- **III:** la intención del invasor agrega cuatro renglones al panel «Situación», que ya era denso. El aviso de ronda sin órdenes es un cartel, no una confirmación: con Espacio sostenido se pueden seguir pasando rondas, pero ninguna pasa en silencio.
- **Primer cuadro del I:** con la cámara a 50° se leen la barranca, los grupos y el buque. Las fichas de los exploradores todavía rozan el aro dorado del grupo elegido, sin pisar texto.

### Pendiente y pedidos

- **Abiertos de esta lista:** ninguno. Del playtest, P-022 (cámara que se pierde lejos del pueblo) es del II (P2/P5), no de esta pista.
- **Lead / QA:** `tools/qa_gate.sh` sigue limitando `main.gd` a +80/−10 líneas y `test_integration.gd` a +6/−2. Esta pista los supera por encargo. Lo mismo que anotó P4.
- **QA de historia:** revisar las tres citas de Gillespie (traducción del juego) y la cronología de 1806 de la pantalla de misión.
- **Lead:** el precalentado del II agrega un velo de ~0,4 s al abrir el juego, solo la primera vez por sesión. `tools/benchmark.py` no cambia: el `--benchmark=humahuaca` de `main.gd` espera el precalentado antes de construir el nivel, igual que un jugador que pasa por el menú.
