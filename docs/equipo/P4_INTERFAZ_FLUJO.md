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
