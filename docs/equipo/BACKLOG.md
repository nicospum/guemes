# Backlog y registro de iteraciones — entrega «equipo 2026-11-08»

Fuentes de la tanda 1 (informes completos fuera de Git, en `../qa-equipo/`): auditoría técnica (`auditoria/INFORME_AUDITORIA.md`), diseño y referentes (`diseno/REFERENTES_Y_DECISIONES.md`), dirección de arte (`arte/DIRECCION_DE_ARTE.md`), playtest de línea de base (`playtest/LINEA_BASE.md`).
Gravedad: BLOQUEANTE / ALTO / MEDIO / BAJO. Un ticket se cierra solo con la prueba indicada en «Cierre» ejecutada sobre la rama integrada.

## Pistas de implementación (tanda 2)

| Pista | Dueña de | Rama |
|---|---|---|
| P1 · 3D Justina y Norte | `scripts/world_view.gd`, `assets/*.gdshader`, `shaders/` (salvo los del II), archivos nuevos `scripts/looks/*` | worktree propio |
| P2 · 3D Humahuaca | `scripts/humahuaca/view/*`, `scripts/humahuaca/terrain/*` (aspecto), `scripts/humahuaca/ui/humahuaca_camera.gd`, `data/humahuaca_visual.json`, `tests/test_hx_view.gd`, `tests/test_hx_camera.gd` | worktree propio |
| P3 · Reglas Humahuaca | `scripts/humahuaca/rules/*`, `data/humahuaca_rules.json`, `data/humahuaca_level.json`, `data/humahuaca_map.json`, `tests/test_hx_rules.gd`, `tests/revision_nube/a_*,c_*,d_*,r_*` | worktree propio |
| P4 · Interfaz y flujo I/III | `scripts/main.gd`, `scripts/game_rules.gd`, `scripts/campaign.gd`, `tests/test_integration.gd`, `tests/test_rules.gd`, `tools/ui_qa.gd` | worktree propio |
| P5 · Interfaz Humahuaca | `scripts/humahuaca/ui/*` (salvo cámara), `data/humahuaca_ui.json`, `tests/test_hx_flow.gd`, `tests/revision_nube/b_*,e_*,f_*,g_*` | worktree propio |
| P6 · Modelos 3D (Blender headless) | `tools/create_models.py` (solo funciones nuevas), `assets/models/hx_*` nuevos | worktree propio |

Contratos entre pistas: P1 expone `world_view.set_look(nombre)` con `"menu"`, `"justina"`, `"norte"`; P4 lo llama si existe (`has_method`). P6 entrega GLB nuevos que integra P2. Paleta común («Crónica en oro y noche», ver `arte/DIRECCION_DE_ARTE.md`): P4 y P5 usan los mismos HEX.

## Tickets

| ID | Nivel/sistema | Grav. | Observado (pasos) | Esperado | Resp. | Cierre (prueba) | Estado |
|---|---|---|---|---|---|---|---|
| T-001 | flujo II→I/III | ALTO | `_start_game("norte"|"justine")` o `_load_game` con el II vivo: queda el ambiente, la cámara y la lluvia del II (III casi negro). Causa: `main.gd:436` y `:922` no llaman a `_stop_humahuaca()`. Por la UI normal no se llega, pero sí por cargar partida y por herramientas. | Cambiar de nivel siempre libera el II. | P4 | Prueba de integración: II vivo → `_start_game("norte")` → 1 solo WorldEnvironment, sin lluvia, cámara del Norte; captura. | abierto |
| T-002 | II reglas | ALTO | Tras mezclar el relieve Copernicus, el experto pierde por «sin_carga» (golpe 44,36 < 45) en 4/40 semillas; `test_hx_rules` 682/1 falla (experto 7/8 en compuerta 1). En la rama de balance sola: 40/40. | El experto vuelve a ≥ 80 % y `test_hx_rules` sin fallas, con el relieve real. | P3 | `test_hx_rules` 0 fallas + 40 semillas del experto. | abierto |
| T-003 | II interfaz | MEDIO | Viniendo de la Justina, la interfaz del II sale 25 % más grande (`content_scale_factor` no se repone, `main.gd:391`). | Misma escala que entrando desde el menú. | P4 | `tests/revision_nube/e_escala_doble_tras_justina.gd` pasa. | abierto |
| T-004 | menú | MEDIO | Tras jugar el III, el fondo del menú queda recortado (`camera.far` 400). | El menú siempre igual. | P4 | Captura del menú tras III idéntica a la del arranque. | abierto |
| T-005 | II flujo | MEDIO | Se ofrece «Reintentar la salida» sin control válido; los controles sobreviven al cambio de mundo. | Solo se ofrecen reintentos que existen. | P3+P5 | `revision_nube/a_control_salida_fantasma`, `b_control_de_otro_mundo`, `r_*` pasan. | abierto |
| T-006 | II interfaz | MEDIO | Arrastre del mapa que cruza una ventana queda pegado al mouse. | Soltar siempre termina el arrastre. | P5 | `revision_nube/e_arrastre_dialogo` pasa. | abierto |
| T-007 | II mapa | MEDIO | En la posta, dos puertas que se ven abiertas son muro para la navegación; el centinela queda detrás de la tapia. | Lo que se ve abierto se puede atravesar. | P3 (nav) + P2 (vista) | `revision_nube/d_puertas_posta`, `d_centinela_posta` pasan. | abierto |
| T-008 | II órdenes | MEDIO | Ctrl+Z deshace mal; tras la señal deshace la orden de otra partida. | Deshacer solo la última orden propia válida. | P5 | `revision_nube/a_undo_prev` y prueba propia. | abierto |
| T-009 | II varios | BAJO | 21 fallas más documentadas en `tests/revision_nube/` (31 de 32 fallan hoy). | Cada una resuelta o justificada. | P3/P5 según prefijo | La prueba correspondiente. | abierto |
| T-010 | II relieve | BAJO | `height_at(NaN)` produce 11 SCRIPT ERROR. | Sin errores. | P2 | `revision_nube/d_nan_altura`. | abierto |
| T-011 | pruebas | BAJO | `audio_runtime_test` 16/17 en headless (driver de mentira); 17/0 con ventana. | Falso negativo documentado. | lead | Corrida con ventana. | aceptado |
| D-01 | II guía | ALTO | Con guardia atenta, el «siguiente paso» manda a reconocer de cerca y eso pierde la partida a los 70 s (8/8). | La guía nunca lleva a perder; la detección avisa ~5 s antes. | P3 (+P5 texto) | 0 derrotas «descubiertos» del obediente en semillas 3, 5, 13, 17 y 60 semillas re-medidas. | abierto |
| D-02 | II historia | ALTO | El epílogo dice «según La Serna» (H03). | Atribuir al Diario del Estado Mayor y Camba (texto en `TEXTOS_REVISION.md`). | P3/P5 (donde viva el texto) | `grep` sin «según La Serna» en `data/` + `test_hx_data` verde. | abierto |
| D-03 | progresión | ALTO | Al ganar la Justina el botón lleva al «escenario 2: Sostener el Norte» y se saltea Humahuaca. | I → II → III encadenados por el botón principal. | P4 (+P5 en el parte del II) | Recorrido completo menú → final por botones. | abierto |
| D-04 | cierre | ALTO | El final del juego es un cuadro sin cierre. | Pantalla final «En tu partida» (I, II, III) frente a «En la historia», con etiquetas. | P4 | Captura sin scroll + revisión de historia. | abierto |
| D-05 | III claridad | MEDIO | La condición de victoria no se ve. | Metas y presión «x de 7» visibles; no se gana antes de la ronda 10. | P4 | La barra se llena en la ronda de victoria. | abierto |
| D-06 | II medallas | MEDIO | El experto saca menos puntaje que el que sigue la guía (47 vs 61); nadie llega a plata. | La medalla premia decidir. | P3 | Obediente bronce; experto ≥ obediente; alguna política llega a plata y oro. | abierto |
| D-07 | I arranque | MEDIO | Primer cuadro con 4 instrucciones a la vez; «marea» por «río». | Un solo mensaje; texto/botones visibles ≤ 60 % de hoy. | P4 | Captura del primer cuadro + `ui_qa`. | abierto |
| D-08 | II parte | MEDIO | Parte de victoria con scroll a 1280×720. | Legible sin scroll, línea de tiempo plegada. | P5 | Captura a 1280×720. | abierto |
| D-09 | III arranque | MEDIO | «Siguiente paso» genérico; «Jev: sin consultar» sin sentido para el jugador. | Paso concreto en rondas 1–2; Jev oculto si no está configurado. | P4 | Captura. | abierto |
| D-10 | III amenaza | BAJO | La intención del invasor es azar sin aviso. | Mostrarla con reconocimiento reciente. | P4 | Coincide 100 % con la resuelta. | abierto |
| D-11 | II ritmo | BAJO | Marchas sin eventos. | Sugerir ×2. | P5 | Agente-jugador sin rachas de 4 turnos esperando. | abierto |
| D-12 | II→III | BAJO | Sin conexión narrativa. | Guiño de texto en el III si se ganó el II. | P4 | Aparece según el perfil. | abierto |
| V-01 | menú | ALTO | Panel sobre agua plana: «no dice mucho». | Menú heroico (buque a contraluz, atardecer) y niveles como capítulos. | P1 (look) + P4 (menú) | Par antes/después. | abierto |
| V-02 | III 3D | ALTO | Relieve beige uniforme, fondo gris; el poncho patriota se lee rojo (regla de color invertida). | Fondo negro, sol rasante dorado, rampa por altura; rojo solo realista. | P1 | Par antes/después + muestreo de color. | abierto |
| V-03 | II 3D | ALTO | Noche plana y lavada, cajas, árboles como manchas negras, fichas de 14–58 px, sin horizonte. | Noche con contraste, braseros que iluminan, fichas ≥ 64 px, enemigos ≥ 28 px con contorno, cerros de la quebrada, vegetación y casas reconocibles. | P2 (+P6 modelos) | Pares antes/después + `test_hx_view`. | abierto |
| V-04 | I 3D | MEDIO | Luz plana de mediodía; colores de fichas sin regla. | Tarde dorada; colores de la regla. | P1 | Par antes/después. | abierto |
| V-05 | HUD I/III | MEDIO | HUD ocupa ~40 % de la pantalla en el I; aspecto de tablero. | Paleta común, esquinas, viñeta; ≤ 25 % tapado; briefing a pantalla completa. | P4 | `ui_qa` ×3 + capturas. | abierto |
| V-06 | HUD II | MEDIO | Interfaz del II con otra paleta; briefing en ventanita. | Paleta común; briefing a pantalla completa (mockup 05); minimapa nocturno. | P5 | `ui_qa_humahuaca` ×3 + capturas. | abierto |

### Tickets del playtest de línea de base (`playtest/LINEA_BASE.md`)

Línea de base: los tres niveles se ganan y se pierden por el recorrido normal; menú → I → II → III → final en una sesión (370 s reales a ×4). 0 BLOQUEANTES.

| ID | Nivel | Grav. | Observado | Esperado | Resp. | Cierre | Estado |
|---|---|---|---|---|---|---|---|
| P-001 | III | ALTO | La barra de órdenes salta 18–36 px al pasar el mouse; el clic cae en otro botón (una ronda pareció resolverse sin la orden de Arias). | Layout estable; el clic da la orden pedida. | P4 | Playtest del III por clics + `ui_qa`. | abierto |
| P-002 | II | ALTO | = D-02 (`data/humahuaca_rules.json:421`). | — | P3 | ver D-02 | abierto |
| P-003 | I | MEDIO | Esc cierra una decisión pendiente; queda oculta con el reloj corriendo. | La decisión no se pierde de vista. | P4 | Prueba de interfaz. | abierto |
| P-004 | I | MEDIO | ×4 vuelve solo a ×1 ~12 veces por partida. | Se conserva la velocidad elegida. | P4 | Playtest a ×4. | abierto |
| P-005 | I | MEDIO | Contraataque: tres mensajes contradictorios y botón Rechazar deshabilitado. | Mensaje coherente con el estado. | P4 | Captura del contraataque. | abierto |
| P-006 | II | MEDIO | El cuadro inicial deja 4 de 5 agrupaciones fuera de pantalla. | Partidas y objetivos en el primer cuadro. | P2 | Captura inicial + `test_hx_camera`. | abierto |
| P-007 | II→III | MEDIO | El parte del II abre el III aunque el menú lo tenga bloqueado. | Decisión del lead: el III se abre al ganar I **o** II; todo coherente. | P4 (+P5) | Recorrido con perfil nuevo. | abierto |
| P-008 | II | MEDIO | 69 % del tiempo el «siguiente paso» dice «Esperá» sin botón. | La espera dice qué se espera y ofrece algo útil (×2, otro frente). | P5 (+P3) | Agente-jugador: proporción de «Esperá» sin acción. | abierto |
| P-009 | III | MEDIO | La derrota pasiva dice «perdió sus agrupaciones» con 300/300 de fuerza. | La causa real. | P4 | Captura de la derrota pasiva. | abierto |
| P-010 | III | MEDIO | Motivo de bloqueo de «Operar en Humahuaca» engañoso. | Motivo real. | P4 | Captura/tooltip. | abierto |
| P-011 | I | MEDIO | Misma semilla y estrategia: 4/5 victorias (varianza). | Dato de balance; se informa. | lead | — | informado |
| P-012…022 | varios | BAJO | «Escenario 2» para el III, bajas 53 %/52 % en el mismo parte, «LO APRENDIDO» vacío, contador de intentos inflado, etiquetas superpuestas, cámara que se pierde. | — | P4/P5 | Capturas. | abierto |

P6 (modelos): no hay Blender ejecutable en esta PC (la carpeta de Blender 4.4 no tiene `blender.exe`). No se pidió descargar; P6 genera los GLB con un exportador propio sin Blender (color por vértice) y deja listo `create_models.py --only hx_*` para regenerar con Blender cuando esté.

### Estado verificado por QA independiente (ronda 2, sobre `bdc9e71`)

Los estados «abierto» de las tablas de arriba son los de la tanda 1. Verificados como **cerrados** por los revisores independientes (no por las pistas): T-001, T-002, T-003, T-004, T-005, T-006, T-007, T-008, T-009, T-010, D-01, D-02, D-03, D-04, D-05, D-07, D-08, D-09, D-10, D-11, D-12, P-001, P-002, P-005, P-006, P-007, P-008, P-009, P-010, P-012, P-014, P-016, P-017, V-01, V-02, V-03, V-05, V-06. Parciales: D-06 (experto ≥ obediente en 49/60), P-003 → Q-102, P-004 → Q-101. Dictámenes en `../qa-equipo/qa_ronda2/` (fuera de Git): nivel II **RECHAZA** por Q-201; niveles I/III y recorrido **ACEPTA CON OBSERVACIONES** (recorrido completo menú → I → II → III → final dos veces seguidas, perfil limpio, 432 s y 423 s, 79 comprobaciones sin fallas).

### Tickets de QA ronda 2

| ID | Nivel | Grav. | Observado | Resp. | Estado |
|---|---|---|---|---|---|
| Q-201 | II cámara | ALTO | El acercamiento automático se dispara con cada orden de la guía (32 deslizamientos en 5,8 min). | fix II | abierto |
| Q-202 | II | MEDIO | «Reintentar desde las posiciones» sin órdenes restaura a 56 s del alba con el reloj a ×4. | fix II | abierto |
| Q-203 | II | MEDIO | 36 de 62 órdenes de una victoria son «Destruir» repetido. | fix II | abierto |
| Q-204 | II | MEDIO | Parcelas regadas como rectángulos lisos (placeholder); en el minimapa se confunden con objetivos. | fix II | abierto |
| Q-205 | II | MEDIO | Construcción del nivel 1,57–2,06 s con ventana desde el menú (tope 1,5 s). | fix II | abierto |
| Q-206 | II | MEDIO | HUD a 1280×720 tapa 29,9 % al inicio y 45,2 % en ataque. | fix II | abierto |
| Q-207…210 | II | BAJO | Parte culpa la guardia equivocada; dos Esc salen sin confirmar; escala del minimapa; mañana sobreexpuesta. | fix II | abierto |
| Q-101 | I | MEDIO | ×4 cae solo a ×1 doce veces por partida. | fix I/III | abierto |
| Q-102…107 | I/III | BAJO | Espacio corre el reloj con decisión pendiente; parte de victoria no reabrible; HUD 1280; tarjeta recortada; aviso de fuga intermitente; autoguardado pisa F5. | fix I/III | abierto |
| Q-108 | evidencia | BAJO | Carpetas de evidencia fuera de Git borradas (ver incidente). | lead | mitigado: documentos clave versionados en `docs/equipo/` |

### Incidente 2026-11-08, 19:10–19:21

Fuera de cualquier acción registrada de los agentes de esta entrega se borraron `../respaldos/`, casi todo `../qa-equipo/` y `patria-guemes/evidence/` (archivos versionados). El usuario confirmó que no fue él. Restaurado: `evidence/` desde Git; `../respaldos/pre-equipo-2026-11-08.bundle` (de nuevo, `--all`), `../respaldos/historial.bundle` (regenerado desde `v0.1.0`, 32 372 265 B contra 32 372 353 B del original), `../respaldos/patria-guemes-0.1.0-sin-git` (`git archive v0.1.0`); capturas «antes» regeneradas desde `respaldo/pre-equipo-2026-11-08`. **No recuperable:** las carpetas `evidencia_humahuaca_r1_*` que solo vivían en `respaldos/`, y los informes y hojas de las pistas en `../qa-equipo/` (los documentos esenciales se reescribieron en `docs/equipo/`). Desde entonces todos los agentes trabajan con la regla de no borrar fuera de su carpeta.

## Registro de iteraciones

| Fecha | Iteración | Qué pasó |
|---|---|---|
| 2026-11-08 | 0 | Punto de recuperación (`respaldo/pre-equipo-2026-11-08`, bundle). Rama `equipo/integracion` = main + 6 ramas de la nube (cámara, relieve, docs, balance, sonido, revisión), sin conflictos. Línea de base de capturas. |
| 2026-11-08 | 1 | Tanda 1 de agentes (auditoría, playtest, diseño, arte), solo lectura. Backlog inicial (este archivo). |
| 2026-11-08 | 2 | Tanda 2: seis pistas en worktrees (P1 arte I/III y menú, P2 arte y cámara del II, P3 reglas del II, P4 interfaz y flujo I/III, P5 interfaz del II, P6 modelos) + rondas extra de P1 (2), P2 (3 y 4) y P4b. Integración sin conflictos en `equipo/integracion`. |
| 2026-11-08 | 3 | Suites completas en verde salvo una falla intermitente real de `test_integration` (HUD encendido detrás de la pantalla de misión), corregida en `bdc9e71`. Build EXE de prueba: los tres niveles arrancan con 0 errores. |
| 2026-11-08 | 4 | Incidente de borrado (ver arriba) y restauración. QA independiente ronda 2: II rechaza (Q-201), I/III aceptan con observaciones. Ronda de corrección lanzada (dos agentes en paralelo, II e I/III). |
