# Trazabilidad contrato → prueba (V20)

Ronda vigente: r1

Cada exigencia de las secciones 3 a 5 de `docs/CONTRATO_HUMAHUACA.md` tiene acá **una fila** con la prueba que la verifica. La prueba que cuenta es una función nombrada que existe: `test_hx_data::_test_v20_traceability` (regla V20 del contrato, 2.4) lee este archivo y falla si una fila apunta a una función que no existe, si el id de una fila se repite o si alguna subsección 3.x, 4.x o 5.x del contrato queda sin ninguna fila. Contar comprobaciones no es progreso: lo que cuenta es esta tabla.

**Cómo se lee.**

- **Ronda vigente** (la línea de arriba) es la ronda en la que está el bucle. La leen `tools/qa_gate.sh` y las pruebas (`--ronda=<id>` la pisa). La cambia el **integrador**, en el commit que abre cada ronda (`r0`, `r1.0`, `r1`, `r2a`, `r2b`, `r3`, `r4`).
- **Prueba** es `archivo::función`. El archivo se escribe sin ruta ni extensión si es `tests/test_hx_*.gd` o `tools/*.gd` (por ejemplo `test_hx_rules`, `humahuaca_playthrough`), `qa_gate` es `tools/qa_gate.sh` y una ruta con extensión vale tal cual. `QA:<ítem>` apunta a un ítem de la rúbrica de `docs/QA_NIVEL2.md` (por ejemplo `QA:T06`) cuando lo mide el procedimiento del QA y no una función del repositorio.
- **Desde** es la ronda a partir de la cual la prueba **tiene que existir**. Antes, la fila figura como pendiente en el informe de `test_hx_data` (sin fallar); si la función ya existe, queda como adelantada. Desde esa ronda, una función inexistente es una falla («no evaluable = falla»).
- Los nombres de función de las pruebas de las pistas (`test_hx_terrain`, `test_hx_rules`, `test_hx_view`, `test_hx_flow`) son **la propuesta de compuertas y documentos**: la pista dueña escribe esas funciones o pide por escrito el cambio de una fila (id, nombre nuevo y motivo). Nadie edita las filas salvo compuertas y documentos; la línea «Ronda vigente» la cambia el integrador.
- No se usa el carácter de barra vertical dentro de una celda.
- **Registro de verificación** (al final del archivo): lo que corrió de verdad en cada ronda, sobre qué commit y con qué cifras. Una fila de esta tabla queda verificada en una ronda cuando figura ahí con su resultado; lo que no corrió también se dice.

| ID | Sección | Exigencia | Prueba | Desde |
|---|---|---|---|---|
| TR-001 | 3.0 | Cada vocabulario (el compartido y los cuatro por dueño) es solo-agregar: todos los ids iniciales siguen presentes | test_hx_data::_test_v13_vocab_add_only | r0 |
| TR-002 | 3.0 | Las claves de rules.groups, objectives, actions, loot y variants equivalen a la unión de los cinco vocabularios (V13) | test_hx_data::_test_v13_rules_vs_vocab | r1.0 |
| TR-003 | 3.0 | Una capa solo importa vocabularios de su capa o de capas inferiores; la dependencia va hacia abajo y sin ciclos (V19) | test_hx_data::_test_v19_dependency_graph | r0 |
| TR-010 | 3.1 | HumahuacaTerrain trae toda la API de 3.1 con los nombres del contrato, en el stub y en la clase real | test_hx_smoke::_test_api_conformance | r1.0 |
| TR-011 | 3.1 | height_at es la única altura: la vista, el picking y las rutas la leen y ninguna otra clase interpola la grilla | test_hx_terrain::_test_single_height_source | r1 |
| TR-012 | 3.1 | Los 41 puntos de la lámina 03: al menos 37 a 12 m o menos y ninguno a más de 20 m | test_hx_terrain::_test_lamina03_points | r1 |
| TR-013 | 3.1 | Alturas de referencia: templo +17 m, cauce +12 m y zona de partida +27 m (tolerancia de la fuente) | test_hx_terrain::_test_reference_heights | r1 |
| TR-014 | 3.1 | Prominencia de la batería 12,0 ± 0,5 m sobre la media del anillo de 120 a 150 m, con cualquier fuente | test_hx_terrain::_test_battery_prominence | r1 |
| TR-015 | 3.1 | Continuidad ventana-contexto de la altura (0,1 m o menos) | test_hx_terrain::_test_window_context_continuity | r1 |
| TR-016 | 3.1 | Conectividad: desde cada acceso se llega a cada objetivo por nav_grid | test_hx_terrain::_test_connectivity | r1 |
| TR-017 | 3.1 | los: la plataforma ve sobre tapias de 2,4 m y la torre tiene ángulo muerto de 12 m | test_hx_terrain::_test_los | r1 |
| TR-018 | 3.1 | Cauce más bajo que el núcleo, signo del gradiente oeste a este y curva de 2 960 m en z = 0, 325 y 650 | test_hx_terrain::_test_gradient_and_contour | r1 |
| TR-019 | 3.1 | Horneado completo en menos de 300 ms (por etapas) y al menos un millón de consultas de height_at por segundo | test_hx_terrain::_test_bake_budget | r1 |
| TR-020 | 3.1 | report() rotula qué es dato actual y qué es diseño | test_hx_terrain::_test_report_labels | r1 |
| TR-021 | 3.1 | Al menos 2,5 % de celdas con pendiente de 8° o más y al menos 3 rasgos verticales que cambian la visión o la velocidad | test_hx_terrain::_test_relief_consequences | r2a |
| TR-022 | 3.1 | Prueba A/B de fuente: diferencia de cota entre objetivos 1 m o menos, curva de 2 960 m a 15 m o menos, signo y prominencia | test_hx_terrain::_test_source_ab | r2a |
| TR-030 | 3.2 | HumahuacaRules trae toda la API de 3.2 con los nombres del contrato, en el stub y en la clase real | test_hx_smoke::_test_api_conformance | r1.0 |
| TR-031 | 3.2 | Determinismo por semilla con RNG propio: la misma semilla da el mismo estado | test_hx_rules::_test_determinism | r1 |
| TR-032 | 3.2 | Las 9 acciones de R1 con éxito, rechazo concreto y costo descontado | test_hx_rules::_test_actions_r1 | r1 |
| TR-033 | 3.2 | Las 20 acciones desde R2a con éxito, rechazo concreto y costo descontado | test_hx_rules::_test_actions_r2a | r2a |
| TR-034 | 3.2 | Fases y transiciones del reloj (briefing, aproximación, ataque, extracción, epílogo) | test_hx_rules::_test_phases | r1 |
| TR-035 | 3.2 | Los errores de órdenes son ok falso más una causa concreta en español, sin jerga | test_hx_rules::_test_order_errors | r1 |
| TR-036 | 3.2 | plan_route y plan_recon no tienen efectos y devuelven la forma del contrato | test_hx_rules::_test_plan_route_shape | r1 |
| TR-037 | 3.2 | world_from_seed es determinista; en R1 el mundo es fijo y desde R2b solo se sortean las dimensiones activas | test_hx_rules::_test_world_from_seed | r1 |
| TR-038 | 3.2 | Sorpresa, alarma, oscuridad, desvelo y señal | test_hx_rules::_test_stealth_and_signal | r1 |
| TR-039 | 3.2 | Torre: temporizador en R1; cadencia, anillo de recarga y cuatro respuestas desde R2a | test_hx_rules::_test_tower | r1 |
| TR-040 | 3.2 | Refuerzo con reloj, banda y efecto del mensajero | test_hx_rules::_test_reinforcement | r1 |
| TR-041 | 3.2 | Carga, capacidad y tratamientos del botín (entregar, destruir, ocultar) con el puntaje que suma 100 | test_hx_rules::_test_loot_and_treatments | r1 |
| TR-042 | 3.2 | Victoria y las 8 causas de derrota, cada una con su texto de 140 caracteres o menos | test_hx_rules::_test_outcomes | r1 |
| TR-043 | 3.2 | Rendimiento: nav_build_ms 80 o menos, plan_route_ms 30 o menos y tick_ms 2 o menos | test_hx_rules::_test_performance | r1 |
| TR-044 | 3.2 | route_atlas: al menos 2 aproximaciones por objetivo que difieren 25 % o más (compuerta 10) | test_hx_rules::_test_route_atlas | r2a |
| TR-045 | 3.2 | Cadencia jugable: 60 % o más de las cargas sobre el cuartel salen en el hueco de recarga (compuerta 11) | test_hx_rules::_test_tower_cadence | r2a |
| TR-046 | 3.2 | Cobertura de variantes: cada valor de cada dimensión activa aparece en las semillas de calibración y de la compuerta | test_hx_rules::_test_variant_coverage | r2b |
| TR-047 | 3.2 | Matriz de contrapesos: cada celda se mueve en el sentido previsto (compuerta 5) | test_hx_rules::_test_counterweight_matrix | r2b |
| TR-048 | 3.2 | Estrategias de frente por 24 semillas: ninguna domina y cada enfoque es el mejor en algún mundo (compuerta 6) | test_hx_rules::_test_strategies | r2b |
| TR-049 | 3.2 | Barrido de la señal: máximo único entre 4:15 y 5:45 con meseta de 30 s (compuerta 7) | test_hx_rules::_test_signal_sweep | r2b |
| TR-050 | 3.2 | Recetas de extracción: ninguna gana en más del 60 % y ocultar es la mejor en algún mundo (compuerta 8) | test_hx_rules::_test_extraction_recipes | r2b |
| TR-051 | 3.2 | Decisiones significativas por ramificación de snapshots (compuerta 9) | test_hx_rules::_test_meaningful_decisions | r2b |
| TR-052 | 3.2 | environment().time_of_day es continuo, nunca baja y pasa por las cinco muestras de VP-01 (0,00, 0,00, 0,50, 0,67 y 1,00 a los 0, 240, 285, 330 y 420 s, con una tolerancia de 0,05); una partida pasiva termina antes de los 420 s, así que esa muestra se toma con el reloj fijado o con la señal dada (ADDENDA A-07 y A-08) | test_hx_rules::_test_environment_curve | r1.0 |
| TR-060 | 3.2.1 | state trae los campos mínimos y obligatorios, cada uno con su tipo y su rango | test_hx_rules::_test_state_fields | r1 |
| TR-062 | 3.2.2 | Todo evento trae un kind del vocabulario; un kind fuera de EVENT_KINDS es un error de contrato | test_hx_rules::_test_event_kinds | r1 |
| TR-064 | 3.2.3 | hud_state funciona en todas las fases y tiene la forma del ejemplo | test_hx_rules::_test_hud_state_all_phases | r1 |
| TR-065 | 3.2.3 | render_state no muestra lo que el jugador no sabe (guardia y postura no reconocidas) | test_hx_rules::_test_render_state_blindness | r1 |
| TR-066 | 3.2.3 | campaign_report es válido siempre y tiene la forma del ejemplo | test_hx_rules::_test_campaign_report_shape | r1 |
| TR-067 | 3.2.3 | La salida de cada implementación (stub y real) tiene las claves y los tipos de los ejemplos de forma | test_hx_smoke::_test_shapes | r1.0 |
| TR-068 | 3.2.3 | render_state().version sube con cada cambio visible (una orden, la señal, los hechos del ataque) y nunca baja; trae solo ids del vocabulario y las tres luces de objetivo (VP-02) | test_hx_rules::_test_render_state | r1.0 |
| TR-069 | 3.2.3 | render_state().tower es vacío hasta que la torre abre fuego y desde ahí cae a menos de 40 m del hito de su variante (torre_casa_cura o torre_templo), con anillo de recarga, ángulo muerto y estado de fuego (VP-02) | test_hx_rules::_test_render_state_tower | r1.0 |
| TR-070 | 3.2.4 | validate_snapshot rechaza al menos 30 mutaciones con motivo y sin tocar el estado | test_hx_rules::_test_save_mutations | r1 |
| TR-071 | 3.2.4 | Guardar y cargar no cambia snapshot() (tolerancia 1e-6, RNG exacto) | test_hx_rules::_test_save_roundtrip | r1 |
| TR-072 | 3.2.4 | Un guardado de la Justina o del Norte se rechaza con un motivo claro | test_hx_rules::_test_foreign_saves | r1 |
| TR-075 | 3.2.5 | Biblioteca de políticas única: el experto gana y el pasivo pierde | test_hx_rules::_test_policies_extremes | r1 |
| TR-076 | 3.2.5 | Las políticas sin ventaja (obediente, torpe, ciegas, pasivo, pausa y reanuda, aleatorio, interfaz) no leen estado oculto | test_hx_rules::_test_policies_blindness | r2b |
| TR-080 | 3.3 | HumahuacaProgress trae toda la API de 3.3 con los nombres del contrato, en el stub y en la clase real | test_hx_smoke::_test_api_conformance | r1.0 |
| TR-081 | 3.3 | Intentos, racha y mundo fijo hasta ganar; un archivo dañado o de otra versión se descarta con aviso y no bloquea | test_hx_rules::_test_progress | r1 |
| TR-082 | 3.3 | campaign.json no cambia ni un byte al correr el nivel | test_hx_smoke::_test_campaign_json_unchanged | r0 |
| TR-083 | 3.3 | Diario con marcas, puntos de control, ayudas, medallas y opciones de reintento | test_hx_rules::_test_progress_full | r2b |
| TR-090 | 3.4 | HumahuacaView trae toda la API de 3.4 con los nombres del contrato, en el stub y en la clase real | test_hx_smoke::_test_api_conformance | r1.0 |
| TR-091 | 3.4 | build() no produce errores de shader ni de parseo y respeta el presupuesto de nodos y triángulos | test_hx_view::_test_build | r1 |
| TR-092 | 3.4 | initial_frame().fits incluye los 3 objetivos y la zona de partida | test_hx_view::_test_initial_frame | r1 |
| TR-093 | 3.4 | El picking es coherente con el terreno | test_hx_view::_test_picking | r1 |
| TR-094 | 3.4 | Sin bandera argentina ni torres de 1880-81, por nombre y por altura de vértices (templo de 8 m o menos) | test_hx_view::_test_anachronisms | r1 |
| TR-095 | 3.4 | Ninguna entidad con color suelto fuera de la paleta | test_hx_view::_test_palette_only | r1 |
| TR-096 | 3.4 | Las 7 vistas canónicas y sus must_show | test_hx_view::_test_canonical_views | r1 |
| TR-097 | 3.4 | Las luces de render_state().lights se dibujan de lejos | test_hx_view::_test_lights | r1 |
| TR-098 | 3.4 | Los 3 arquetipos de figura se distinguen en escala de grises a 48 px | test_hx_view::_test_archetypes_grayscale | r1 |
| TR-099 | 3.4 | set_albedo_mode y probes para las métricas del QA | test_hx_view::_test_albedo_and_probes | r2a |
| TR-100 | 3.4 | Presupuesto de cuadro por perfil (baja 2,5 ms, media 4,0 ms, alta 6,0 ms, p95 8,3 ms) y construcción en 1 500 ms o menos | QA:T06 | r1 |
| TR-101 | 3.4 | Anillos de visibilidad: contorno de la unión de los círculos, de 2 px en pantalla, sin cruces entre anillos y apagados con luz plena (ADDENDA A-08) | test_hx_view::_test_visibility_rings | r1.0 |
| TR-102 | 3.4 | El alba no lava el cuadro de naranja saturado: la saturación del suelo bajo la luz del alba queda dentro de los topes y el sol sigue cálido (ADDENDA A-08) | test_hx_view::_test_dawn_wash | r1.0 |
| TR-103 | 3.4 | La escala en pantalla (fichas, luces, etiquetas y anillos) se mide con la cámara del cuadro que se dibuja, aunque el controlador llame a update_state antes de ubicarla (ADDENDA A-08) | test_hx_view::_test_camera_order | r1.0 |
| TR-104 | 3.4 | Capas, selección y efectos de la vista: las 8 capas se apagan y se encienden, set_selected_ids marca solo las fichas elegidas, fx crea los 7 tipos con tope y se libera solo, get_landmark_info trae etiqueta y cota y build emite minimap_changed | test_hx_view::_test_dynamic_api | r1.0 |
| TR-105 | 3.4 | Degradación de la vista (CONTRATO 7): sin reglas ni terreno construye y devuelve valores válidos (fits falso, picking y rótulos vacíos, minimapa), y una calidad desconocida se trata como media | test_hx_view::_test_degraded | r1.0 |
| TR-110 | 3.5 | El controlador (la cáscara de T0 y el real) tiene la API de QA estable: start, stop, qa_state, qa_set_camera, qa_set_time, qa_run, qa_step y benchmark_prepare | test_hx_smoke::_test_api_conformance | r0 |
| TR-111 | 3.5 | stop() es idempotente y restaura camera.far y fov, escala 3D, MSAA, ambiente del audio, content_scale y settings.last_save | test_hx_smoke::_test_roundtrip_x3 | r0 |
| TR-112 | 3.5 | El controlador recibe la entrada antes que main y nada queda huérfano al volver al menú | test_hx_smoke::_test_input_order | r0 |
| TR-113 | 3.5 | Teclas reservadas (Espacio, F2, F3, F4, más y menos, Esc) y velocidad siempre indicada | test_hx_flow::_test_reserved_keys | r1 |
| TR-114 | 3.5 | Primer cuadro jugable con 5 controles o menos, 400 caracteres o menos y cero jerga | test_hx_flow::_test_first_frame | r1 |
| TR-115 | 3.5 | Ciclo menú, briefing, apertura, bot que sigue el siguiente paso, desenlace, parte y reintento | test_hx_flow::_test_full_cycle | r1 |
| TR-116 | 3.5 | El experto gana y el pasivo pierde por la escena real | test_hx_flow::_test_expert_wins_passive_loses | r1 |
| TR-117 | 3.5 | Primera decisión en menos de 60 s | test_hx_flow::_test_first_decision | r1 |
| TR-118 | 3.5 | Guardar y cargar por la interfaz | test_hx_flow::_test_save_load | r1 |
| TR-119 | 3.5 | Pantallas legibles desde 1024 por 640 y sin desbordes a 1280 por 720, 1920 por 1080 y 2560 por 1440 | ui_qa_humahuaca::_check_overflow | r1 |
| TR-120 | 3.5 | Barra de acciones contextual con las 20 acciones, vista previa de ruta y una sola alerta crítica a la vez | test_hx_flow::_test_action_bar | r2a |
| TR-121 | 3.5 | Contraste de texto de 4,5 a 1 o más medido sobre los píxeles | ui_qa_humahuaca::_check_contrast | r2a |
| TR-122 | 3.5 | key_table: cada fila figura en CONTROLES.md | test_hx_flow::_test_key_table | r2b |
| TR-130 | 3.6 | Los cinco ejemplos de forma existen, parsean, traen todas las claves y sus ids son del vocabulario | test_hx_data::_test_forma_examples | r0 |
| TR-131 | 3.6 | El comparador de formas ve una clave que falta o un tipo distinto y compara los arreglos por su primer elemento | test_hx_smoke::_test_shapes | r0 |
| TR-132 | 3.6 | qa_state() del controlador tiene la forma del ejemplo | test_hx_smoke::_test_shapes | r0 |
| TR-140 | 4.1 | H1 y H2: el menú ofrece tres botones en orden I, II y III; Humahuaca siempre habilitado con la nota y el Norte con su candado | test_hx_smoke::_test_menu_and_buttons | r0 |
| TR-141 | 4.1 | El botón de Humahuaca no contiene EL RÍO OFRECE, SOSTENER EL NORTE ni Ganá la Justina para abrirlo | test_hx_smoke::_test_menu_and_buttons | r0 |
| TR-142 | 4.1 | El último elemento del menú entra en el alto del viewport | test_hx_smoke::_test_menu_fits_viewport | r0 |
| TR-143 | 4.1 | H3 y H4: arrancar el nivel libera el mundo del menú, no toca main.rules y deja un solo controlador vivo | test_hx_smoke::_test_poc_flow | r0 |
| TR-144 | 4.1 | H4: exited con norte arranca el Norte y libera el controlador | test_hx_smoke::_test_exit_to_norte | r0 |
| TR-145 | 4.1 | La Justina arranca después de volver y GameRules.new_game con humahuaca sigue devolviendo justine | test_hx_smoke::_test_justina_after_return | r0 |
| TR-146 | 4.1 | H4: la cáscara de respaldo, instanciada sola, arranca, avanza y vuelve al menú | test_hx_smoke::_test_degraded_runs | r0 |
| TR-147 | 4.1 | H5: Continuar abre el escenario guardado (Humahuaca y Justina) | test_hx_smoke::_test_continue_routes | r0 |
| TR-148 | 4.1 | H6: Historia muestra I, II y III en orden | test_hx_smoke::_test_history_dialog | r0 |
| TR-149 | 4.1 | H7: qa y benchmark delegan en el controlador | qa_gate::step_qa_humahuaca | r0 |
| TR-150 | 4.1 | H9: volver al menú libera el controlador y _stop_humahuaca es idempotente | test_hx_smoke::_test_return_menu_hook | r0 |
| TR-151 | 4.1 | main.gd queda con pocas líneas agregadas y ninguna de lógica ajena (80 agregadas y 10 borradas como tope) | qa_gate::step_shared | r0 |
| TR-152 | 4.2 | El Norte conserva su candado y Humahuaca está siempre habilitado con la nota Recomendado tras la Justina | test_hx_smoke::_test_menu_and_buttons | r0 |
| TR-153 | 4.2 | Ganar Humahuaca registra won en humahuaca_progress.json y habilita Ver la campaña completa: Sostener el norte | test_hx_rules::_test_progress_win_next | r1 |
| TR-155 | 4.3 | --scenario=humahuaca abre el nivel directo, sin mirar el candado | qa_gate::step_scenario_flag | r0 |
| TR-156 | 4.3 | --qa=humahuaca escribe capturas y qa_report.json en qa_path | qa_gate::step_qa_humahuaca | r0 |
| TR-157 | 4.3 | --benchmark=humahuaca deja el nivel en pleno ataque y respeta el presupuesto de cuadro | qa_gate::step_benchmark | r1 |
| TR-158 | 4.3 | --hx-seed, --hx-phase y --hx-skip-intro los lee el controlador | test_hx_flow::_test_cli_flags | r1 |
| TR-160 | 4.4 | Hermeticidad de perfil: test_integration y ui_qa limpian humahuaca_progress.json y humahuaca_checkpoint.json, y run_qa.py acepta humahuaca | test_hx_data::_test_tooling_hooks | r0 |
| TR-161 | 4.4 | .gitignore y .gitattributes tienen las reglas del nivel (evidencia por ronda, teselas, fin de línea LF) | test_hx_data::_test_tooling_hooks | r0 |
| TR-162 | 4.4 | Nada que el juego lea queda fuera de data/*.json: data/ solo tiene archivos .json | test_hx_data::_test_v8_sizes | r0 |
| TR-163 | 4.4 | El EXE incluye data/humahuaca_*.json, shaders/humahuaca_* y assets/models/humahuaca | QA:E01 | r4 |
| TR-170 | 5.1 | Cada suite llega a su piso de comprobaciones de la ronda (data 40 o 60, smoke 25 y las demás de la tabla 5.1) | qa_gate::step_hx_suites | r0 |
| TR-171 | 5.1 | test_hx_data corre en menos de 5 s | test_hx_data::_test_v1_files_and_identity | r0 |
| TR-172 | 5.1 | humahuaca_playthrough sale con 0 si el experto gana y el pasivo pierde, y desde R2b si se cumplen las compuertas | QA:J01 | r1 |
| TR-173 | 5.1 | hx_qa_tour y hx_agent_play producen el paquete del QA (vistas, albedo, límites, fichas, bitácora del agente) | QA:J08 | r1 |
| TR-174 | 5.1 | Las semillas de calibración, de la compuerta, del informe y las reservadas al QA no se mezclan | QA:J04 | r1 |
| TR-175 | 5.1 | Cinco corridas degradadas (terreno, reglas, vista, interfaz y progreso reemplazados de a uno por su stub): el nivel arranca, avanza y vuelve al menú, y solo la capa forzada corre en su versión mínima según qa_state().layers | test_hx_smoke::_test_degraded_runs | r1.0 |
| TR-176 | 5.1 | El comparador de capas efectivas ve una capa forzada que siguió siendo la real, otra que cambió sin pedirlo y una que no arrancó | test_hx_smoke::_test_forced_layer_comparator | r1.0 |
| TR-180 | 5.2 | test_rules completo da 871 o más con 0 fallas y el rápido 818 o más | qa_gate::step_rules | r0 |
| TR-181 | 5.2 | test_integration da 283 o más con 0 fallas | qa_gate::step_integration | r0 |
| TR-182 | 5.2 | Jev da 15 o más con 0 fallas y el audio 17 comprobaciones con 1 falla aceptada | qa_gate::step_jev_audio | r0 |
| TR-183 | 5.2 | ui_qa da 254 o más con 0 fallas en 1280 por 720, 1920 por 1080 y 2560 por 1440 | qa_gate::step_ui_qa | r0 |
| TR-184 | 5.2 | Benchmark: la Justina y el Norte en 3,0 ms o menos y Humahuaca dentro de su presupuesto por perfil | qa_gate::step_benchmark | r0 |
| TR-185 | 5.2 | justina_playthrough: 3 estilos ganadores o más, 2 rutas o más, una derrota o más y el bot de interfaz gana | qa_gate::step_justina_playthrough | r0 |
| TR-186 | 5.2 | Los archivos protegidos de la Justina y del Norte no cambian contra el hash fijo 5ebbd28 | qa_gate::step_protected | r0 |
| TR-190 | 5.3 | Cada corrida usa un APPDATA aislado propio y un timeout, y termina con una línea PASA o FALLA con cifras | qa_gate::setup_isolation | r0 |
| TR-191 | 5.3 | Las pruebas que borran archivos de perfil se niegan a correr con el perfil real | test_hx_smoke::_require_isolated_profile | r0 |
| TR-192 | 5.3 | Ningún comando de la compuerta abre ni imprime .env ni jev.cfg, y no hay etiquetas nuevas | qa_gate::step_hygiene | r0 |
| TR-193 | 5.3 | Se buscan SCRIPT ERROR, SHADER ERROR, Parse Error y WARNING en la salida de cada prueba | qa_gate::scan_logs | r0 |
| TR-194 | 2.4 | V6, V10 a V12, V14 a V16, V18, V21 y V22 corren desde r1 sobre los datos de las cuatro pistas (V13 suma las dimensiones de variante) | test_hx_data::_test_r1_rules | r1 |
| TR-195 | 2.4 | Sanidad por mutación de esas reglas: cada una ve el error plantado y deja pasar lo legal (una sigla se busca respetando mayúsculas; una excepción fechada vence en su ronda) | test_hx_data::_mut_r1_rules | r1 |
| TR-196 | 5.1 | El recorrido de QA por la escena real escribe las 7 vistas con y sin interfaz, la calibración de albedo, los límites de cámara, la hoja de fichas, scene_names.txt y qa_report.json (Q2) | qa_gate::step_level_tools | r1 |
| TR-197 | 5.1 | El arnés del agente-jugador escribe turno_NN.png y arnes.json (hx_agente_v1) y la primera orden entra por clic en 8 turnos o menos y 40 s de juego (Q8, J08; con el arnés contestando solo) | qa_gate::step_level_tools | r1 |
| TR-198 | 5.1 | Lo que solo se ve por la escena real (fichas de 48 px o más, alba sin naranja saturado, anillos sin cruces) pasa por tools/vis_humahuaca.sh --flow en la compuerta completa (VP-13) | qa_gate::step_level_tools | r1 |

| TR-199 | 5.1 | El arnés del agente-jugador atiende el protocolo por archivos con un agente de guion: una acción escrita a medias se lee de nuevo, el JSON roto, el clic fuera de la ventana y el tipo desconocido no se aplican y no frenan el turno, las respuestas cierran la corrida y el registro del motor queda sin errores | qa_gate::step_level_tools | r1 |
| TR-200 | 5.1 | El arnés mide objetivos_identificados_en_turnos con la bitácora del agente (lo escrito desde el primer cuadro con mapa; J08 pide menos de 3 turnos): por clics sería imposible, porque tres frentes necesitan tres clics | hx_agent_play::_check_bitacora | r1 |
| TR-201 | 5.1 | El arnés borra de la carpeta de turnos las acciones, las respuestas y las capturas de una corrida anterior, no toca la bitácora del agente y, sin acciones nuevas, abandona a los --wait-s | hx_agent_play::_clear_stale | r1 |
| TR-202 | 5.1 | El recorrido de QA da las posiciones de qa_report.json (rect de los probes, horizon_y, objetivos del cuadro inicial y límites) en píxeles de la captura y deja la escala usada, porque qa_imagen.py las lee como píxeles de la imagen (V06) | hx_qa_tour::_pixelize | r1 |
| TR-203 | 5.1 | El recorrido de QA mide sobre el arco del bot la jerga, los desbordes de texto, la brecha de decisión y las contracciones sin hacer, y deja todo el texto visible en textos_visibles.txt | hx_qa_tour::_bot_arc | r1 |
| TR-204 | 2.4 | V10 (contracciones): ninguna cadena visible de reglas trae «de el» ni «a el» sin contraer ni antepone «de» o «a» a un marcador de lugar masculino; sin excepciones desde el pase 2 de R1 (B-036: reglas_historia pasó las cinco plantillas a {deFrente} y {aFrente}) | tests/hx_validators.gd::v10_contractions | r1 |
| TR-205 | 3.5 | qa_state() del controlador real trae, con su tipo, las claves que leen el arnés del agente y el recorrido de QA (mode, dialog, status, attempt, orders, first_order_s, visible_buttons, text_chars_juego): si la interfaz las renombra, falla la compuerta rápida de quien las toca y no recién la completa | test_hx_smoke::_test_shapes | r1 |
| TR-206 | 4.1 | H8 y hook-10: mientras corre el nivel main.gd no ubica la cámara (la ubica el controlador al final de su cuadro); si main la pisa con la pose de la Justina, la vista mide dos cámaras por cuadro y el cuadro medio de media se triplica (H-R1-1) | test_hx_smoke::_test_camera_owner | r1 |

## Registro de verificación por ronda

Lo escribe «compuertas y documentos» al cerrar cada ronda y dice **qué corrió de verdad, sobre qué commit y con qué cifras**. Las cifras salen de los registros de `tools/qa_gate.sh` y de los informes JSON de las pruebas, no de lo que cuente cada pista; lo que no corrió, también se dice. La evidencia chica de cada ronda está en `evidence/humahuaca/<ronda>/compuertas/` (R1.0 usa `r1`, como las demás pistas; las rondas intermedias no entran a Git). Cuando una ronda tiene un segundo pase, la evidencia del primero queda en la subcarpeta `pase1/` y la del segundo lleva el sufijo `_r1p2`.

### R1.0 pase 1 · las cuatro pistas fusionadas en `main` (1 de noviembre de 2026)

**Cómo se corrió.** Compuerta completa sobre `d038bcc` (el commit con que el integrador cerró la fusión): `SKIP=benchmark KEEP=1 bash tools/qa_gate.sh full`, ronda `r1.0`, `APPDATA` aislado propio de la corrida, ventana real (sin `--headless`) para `ui_qa`, `--qa=humahuaca` y `justina_playthrough`, `--audio-driver Dummy`, Godot 4.7.2 con Forward+ en una RTX 3080 Ti. Duró 11 min 34 s. Las cifras son **idénticas** a las que el integrador midió sobre el mismo commit (mismas comprobaciones en cada prueba; cambian solo los tiempos). El perfil real del usuario quedó intacto (ningún archivo de juego modificado durante la corrida). Después, `test_hx_smoke` y `test_hx_data` con las comprobaciones y filas que agrega esta ronda (146 y 296, 0 fallas) y la compuerta rápida sobre el árbol del commit de documentos y pruebas.

| Paso de la compuerta | Resultado real | Filas que ejercita |
|---|---|---|
| `import` | PASA, 3 s | ninguna |
| `protegidos` | PASA: 40 archivos protegidos intactos contra `5ebbd28` | TR-186 |
| `compartidos` | PASA: `main.gd` +47/−4, `test_integration` +1/−1, `ui_qa` +1/−1, `run_qa` +1/−1 | TR-151 |
| `rules` (completo) | PASA: 871 comprobaciones, 0 fallas, 3 min 27 s | TR-180 |
| `integracion` | PASA: 283/0, 11 s | TR-181 |
| `jev` y `audio` | PASA: Jev 15/0; audio 17 comprobaciones con 1 falla aceptada (driver Dummy) | TR-182 |
| `hx_data` | PASA: 296/0, 2 s; V20 lee 118 filas (46 activas, 15 adelantadas y 57 pendientes de rondas futuras; con TR-175 y TR-176 son 120, 48 activas) | TR-001 a TR-003, TR-130, TR-160 a TR-162, TR-171 |
| `hx_smoke` | PASA: 134/0, 21 s, con 4 pendientes (las clases reales, vencen en `r1`) | TR-067, TR-082, TR-110 a TR-112, TR-131, TR-132, TR-140 a TR-148, TR-150, TR-152 y TR-191; TR-010, TR-030, TR-080 y TR-090 solo para los stubs |
| `hx_view` | PASA: 86/0, 2 s (la pista visual la entregó antes de tiempo: su piso de R1 es 25) | TR-091 a TR-099, adelantadas |
| `hx_terrain`, `hx_rules`, `hx_flow` | N/A: los archivos todavía no existen (obligatorios desde `r1`); **no evaluadas** | las 55 filas pendientes de esos tres archivos |
| `etapa` | PASA: los 4 stubs y un controlador que ya no es la copia de la cáscara | CONTRATO 8.1 |
| `higiene` | **FALLA**: `git tag --list` trae `v0.2.0-alpha` y `v0.3.0-alpha`, que no son de este equipo (BACKLOG B-017) | TR-192 |
| `scenario` | PASA: `--scenario=humahuaca` sale con 0, 3 s | TR-155 |
| `qa_humahuaca` | PASA: `--qa=humahuaca` sale con 0 y escribe `qa_report.json` y 2 capturas (el menú y el primer cuadro), 5 s | TR-156 |
| `ui_qa` ×3 | PASA: 254/0 a 1280 × 720 (25 s), 1920 × 1080 (34 s) y 2560 × 1440 (45 s), con `captura_px` igual a la pedida | TR-183 |
| `justina_playthrough` | PASA: 18 victorias, 6 estilos, 3 rutas, 6 derrotas y el bot de interfaz gana, 5 min 28 s | TR-185 |
| `benchmark` | **OMITIDO por orden** (lo mide el jefe de QA a solas): no se verificó | TR-157 y TR-184, sin verificar |
| `herramientas_hx` | N/A: `ui_qa_humahuaca`, `humahuaca_playthrough` y `hx_qa_tour` se exigen desde `r1` | TR-119, TR-172 y TR-173, sin verificar |
| `salida_limpia` | PASA: ningún `SCRIPT ERROR`, `SHADER ERROR`, `Parse Error`, `ERROR:` ni fuga en los registros; 0 `WARNING` | TR-193 |

La línea final de la compuerta dice `FALLA (1 pasos)` y el único paso que falla es `higiene`, por las dos etiquetas ajenas: ningún paso atribuible a una pista o al integrador falló. La compuerta rápida sobre el commit con los cambios de esta ronda (`quick integrador`, corrida dos veces, la última de 1 min 40 s) da lo mismo: rules 818/0, integración 283/0, `hx_data` 296/0, `hx_smoke` 146/0 y solo `higiene` en FALLA.

**Capturas reales de la compuerta.** Las dos que escribe `--qa=humahuaca` (el menú de tres botones y el primer cuadro del nivel, ambas a 1280 × 720) se miraron una por una; las 123 de `ui_qa` (41 por resolución) tienen el tamaño pedido y ninguna es negra ni uniforme (se midió el desvío de la luminancia), y se miró la de la Justina a 1280 × 720.

**Las cinco corridas degradadas** (`test_hx_smoke::_test_degraded_runs`, TR-146 y TR-175). Cada una reemplaza **una** capa por su versión mínima, deja correr el nivel y vuelve al menú con Esc. La corrida normal (sin reemplazos) es la referencia: el controlador informa sus capas efectivas en `qa_state().layers`.

| Capa reemplazada | Cómo se reemplaza | Arranca | Avanza | Vuelve al menú | Capas efectivas |
|---|---|---|---|---|---|
| terreno | `start` con `force_stub` de `terrain` | sí | sí | sí | terreno, reglas, progreso y vista en `minimo` |
| reglas | `start` con `force_stub` de `rules` | sí | sí | sí | las cuatro en `minimo` |
| progreso | `start` con `force_stub` de `progress` | sí | sí | sí | las cuatro en `minimo` |
| vista | `start` con `force_stub` de `view` | sí | sí | sí | las cuatro en `minimo` |
| interfaz | se instancia `stubs/stub_ui.gd` en lugar del controlador (`qa_state().shell` verdadero) | sí | sí | sí | la cáscara no informa capas |

**Límite honesto de R1.0.** Todavía no existe ninguna de las cuatro clases reales (`terrain/humahuaca_terrain.gd`, `rules/humahuaca_rules.gd`, `rules/humahuaca_progress.gd` ni `view/humahuaca_view.gd`): el controlador ya arma esas cuatro capas con su versión mínima y forzar un stub no cambia nada, así que las cuatro corridas por capa son **iguales a la normal** (`degradadas.con_efecto` queda vacío en el informe). Lo que prueban hoy es que el camino de reemplazo corre y que el nivel vuelve al menú. Con la primera clase real (R1) la prueba exige que la corrida normal la use y que forzar su stub sí cambie la corrida: se probó en una copia descartable con un terreno «real» simulado (pasa, con `con_efecto` igual a terreno) y con un controlador que ignora `force_stub` (falla con dos mensajes que nombran la capa). Las cuatro clases reales figuran como pendientes `api-real-*` y se vuelven falla en `r1`. La comprobación usa `qa_state().layers`, que hoy trae el controlador de `ui_feel` y no figura en el contrato (BACKLOG B-020).

**Ida y vuelta ×3** (`test_hx_smoke::_test_roundtrip_x3`, TR-111): Humahuaca → menú → Justina → menú, tres veces. Las 9 claves de estado global (`camera.far` y `fov`, escala 3D y MSAA del viewport, ambiente del audio, `settings.last_save`, `content_scale`, cámara actual y modo) quedan iguales tras salir del nivel y tras el ciclo completo con la Justina en las tres vueltas (18 comprobaciones); `OBJECT_ORPHAN_NODE_COUNT` vale 0 en las 7 mediciones; el árbol tiene 222 nodos antes y 222 tras cada vuelta.

**No se verificó en R1.0** (y por qué): el benchmark (omitido por orden); `hx_terrain`, `hx_rules` y `hx_flow`, `ui_qa_humahuaca`, `humahuaca_playthrough`, `hx_qa_tour` y `hx_agent_play` (los entregan las pistas y compuertas y documentos en R1); las reglas V6, V10 a V16, V18, V21 y V22 de `test_hx_data` (BACKLOG B-013, las enciende compuertas y documentos al abrirse R1); las cuatro clases reales de las capas; la curva de `time_of_day` de las reglas contra VP-01 (BACKLOG B-016). Las 57 filas pendientes de la tabla de arriba son 34 de `test_hx_rules`, 12 de `test_hx_terrain`, 9 de `test_hx_flow` y 2 de `ui_qa_humahuaca`: 41 vencen en `r1`, 7 en `r2a` y 9 en `r2b`.

### R1.0 pase 2 · las correcciones de reglas y de vista, fusionadas en `main` (2 de noviembre de 2026)

**Cómo se corrió.** Compuerta completa sobre `503c516` (el commit con que el integrador cerró el pase 2: `reglas_historia` en `b70be6e`, `visual` en `950f8e3` y las ADDENDA A-08 a A-11), con el árbol limpio: `SKIP=benchmark KEEP=1 bash tools/qa_gate.sh full`, ronda `r1.0`, `APPDATA` aislado propio de la corrida, ventana real (sin `--headless`) para `ui_qa`, `--qa=humahuaca` y `justina_playthrough`, `--audio-driver Dummy`, Godot 4.7.2 con Forward+ en una NVIDIA GeForce RTX 3080 Ti. Duró 11 min 10 s. Las cifras son **idénticas** a las que el integrador midió sobre el mismo commit (mismas comprobaciones en cada prueba; cambian solo los tiempos). El benchmark se omitió por orden: lo mide el jefe de QA a solas. El perfil real del usuario quedó intacto (ninguno de sus archivos de partida ni de ajustes tiene una fecha posterior al comienzo de la corrida; se miraron nombres y fechas, no contenidos). Después, `test_hx_smoke` solo, con su propio perfil aislado, y la verificación por la escena real de `visual` (más abajo).

| Paso de la compuerta | Resultado real | Filas que ejercita |
|---|---|---|
| `import` | PASA, 3 s | ninguna |
| `protegidos` | PASA: 40 archivos protegidos intactos contra `5ebbd28` | TR-186 |
| `compartidos` | PASA: `main.gd` +47/−4, `test_integration` +1/−1, `ui_qa` +1/−1, `run_qa` +1/−1 | TR-151 |
| `rules` (completo) | PASA: 871 comprobaciones, 0 fallas, 3 min 21 s | TR-180 |
| `integracion` | PASA: 283/0, 11 s | TR-181 |
| `jev` y `audio` | PASA: Jev 15/0; audio 17 comprobaciones con 1 falla aceptada (driver Dummy) | TR-182 |
| `hx_data` | PASA: 296/0, 0,6 s; V20 lee 123 filas (51 activas, 37 adelantadas y 35 pendientes de rondas futuras) | TR-001 a TR-003, TR-130, TR-160 a TR-162, TR-171 |
| `hx_smoke` | PASA: 146/0, 23 s, con 4 pendientes (las clases reales, vencen en `r1`) | TR-067, TR-082, TR-110 a TR-112, TR-131, TR-132, TR-140 a TR-148, TR-150, TR-152, TR-175, TR-176 y TR-191; TR-010, TR-030, TR-080 y TR-090 solo para los stubs |
| `hx_rules` | PASA: 558/0, 2 s, con 5 pendientes de `r1` (`causa-descubiertos`, `nav_build_ms`, `api-real-rules`, `api-real-progress` y `politicas`); prueba el stub (`impl: stub`) en modo completo | TR-031, TR-032, TR-034 a TR-043, TR-052, TR-060, TR-062, TR-064 a TR-066, TR-068 a TR-072, TR-081 y TR-153: 22 adelantadas (vencen en `r1`) y 3 nuevas (TR-052, TR-068 y TR-069) |
| `hx_view` | PASA: 105/0, 2 s (86 en el pase 1) | TR-091 a TR-099 y TR-101 a TR-105 |
| `hx_terrain`, `hx_flow` | N/A: los archivos todavía no existen (obligatorios desde `r1`); **no evaluadas** | las 21 filas pendientes de esos dos archivos |
| `etapa` | PASA: los 4 stubs y un controlador que ya no es la copia de la cáscara | CONTRATO 8.1 |
| `higiene` | **FALLA**: `git tag --list` sigue trayendo `v0.2.0-alpha` y `v0.3.0-alpha`, que no son de este equipo (BACKLOG B-017); `origin/main` sigue en `72077c8` | TR-192 |
| `scenario` | PASA: `--scenario=humahuaca` sale con 0, 3 s | TR-155 |
| `qa_humahuaca` | PASA: `--qa=humahuaca` sale con 0 y escribe `qa_report.json` y 2 capturas (el menú y el primer cuadro), 5 s | TR-156 |
| `ui_qa` ×3 | PASA: 254/0 a 1280 × 720 (25 s), 1920 × 1080 (33 s) y 2560 × 1440 (43 s), con `captura_px` igual a la pedida | TR-183 |
| `justina_playthrough` | PASA: 18 victorias, 6 estilos, 3 rutas, 6 derrotas y el bot de interfaz gana, 5 min 10 s | TR-185 |
| `benchmark` | **OMITIDO por orden** (lo mide el jefe de QA a solas): no se verificó | TR-157 y TR-184, sin verificar |
| `herramientas_hx` | N/A: `ui_qa_humahuaca`, `humahuaca_playthrough` y `hx_qa_tour` se exigen desde `r1` | TR-119, TR-172 y TR-173, sin verificar |
| `salida_limpia` | PASA: ningún `SCRIPT ERROR`, `SHADER ERROR`, `Parse Error`, `ERROR:` ni fuga en los registros; 0 `WARNING` | TR-193 |

La línea final de la compuerta dice `FALLA (1 pasos)` y el único paso que falla es `higiene`, por las dos etiquetas ajenas (BACKLOG B-017): ningún paso atribuible a una pista o al integrador falló. No hay etiquetas nuevas de este equipo, ni `push`, ni archivos de secretos versionados.

**Compuerta rápida sobre el commit de documentos** (`496762c`, `KEEP=1 bash tools/qa_gate.sh quick integrador`, 1 min 31 s): protegidos 40, `rules` 818/0 (50 s), integración 283/0, `hx_data` 296/0 con las 128 filas, `hx_smoke` 146/0 (24 s, 4 pendientes), `etapa` y `salida_limpia` en PASA y, otra vez, solo `higiene` en FALLA por las dos etiquetas ajenas. Es la rápida del integrador: no corre `hx_rules` ni `hx_view` (son de las pistas y corrieron en la completa).

**Qué cambió desde el pase 1.**

- `hx_rules` existe y corre: 558/0 sobre el stub de reglas. Fija VP-01 (la curva de `time_of_day` pasa por las cinco muestras) y VP-02 (la versión y la torre de `render_state`) y mide el rendimiento del stub: `tick` 0,031 ms, `plan_route` 0,016 ms y `hud_state` más `render_state` 0,268 ms.
- `hx_view` pasa de 86 a 105 comprobaciones (anillos de visibilidad, alba y orden de la cámara; 313 nodos y 91 ms de construcción), 0 fallas.
- `hx_smoke` (146/0) y `hx_data` (296/0) dan lo mismo que al cierre del pase 1: `test_hx_smoke.gd`, `test_hx_data.gd`, `hx_fixtures.gd`, `hx_validators.gd`, `qa_gate.sh`, el controlador y `main.gd` son idénticos entre `0a10e27` y `503c516`.
- Filas de esta tabla: V20 pasa de 120 filas al cierre del pase 1 a 123 con TR-101 a TR-103 (las sumó el integrador) y a **128** con las cinco de este pase: TR-052 (curva de `time_of_day`), TR-068 y TR-069 (`render_state`: versión y torre, VP-02), TR-104 y TR-105 (capas, selección, efectos y degradación de la vista). Las pendientes de rondas futuras bajan de 57 a **35**, porque ya existen `test_hx_rules` y `test_hx_view`: 12 de `test_hx_rules`, 12 de `test_hx_terrain`, 9 de `test_hx_flow` y 2 de `ui_qa_humahuaca`; 19 vencen en `r1`, 7 en `r2a` y 9 en `r2b`.

**Las cinco corridas degradadas** (`test_hx_smoke::_test_degraded_runs`, TR-146 y TR-175), con la compuerta de `503c516` y otra vez solo, con su propio perfil (146/0 en 21,7 s, salida 0, sin `SCRIPT ERROR` ni `WARNING`). Cada una reemplaza **una** capa por su versión mínima, deja correr el nivel y vuelve al menú con Esc. La corrida normal (sin reemplazos) es la referencia: el controlador informa sus capas efectivas en `qa_state().layers`.

| Capa reemplazada | Cómo se reemplaza | Arranca | Avanza | Vuelve al menú | Capas efectivas |
|---|---|---|---|---|---|
| terreno | `start` con `force_stub` de `terrain` | sí | sí | sí | terreno, reglas, progreso y vista en `minimo` |
| reglas | `start` con `force_stub` de `rules` | sí | sí | sí | las cuatro en `minimo` |
| progreso | `start` con `force_stub` de `progress` | sí | sí | sí | las cuatro en `minimo` |
| vista | `start` con `force_stub` de `view` | sí | sí | sí | las cuatro en `minimo` |
| interfaz | se instancia `stubs/stub_ui.gd` en lugar del controlador (`qa_state().shell` verdadero) | sí | sí | sí | la cáscara no informa capas |

**Límite honesto de R1.0, que no cambió en el pase 2.** Todavía no existe ninguna de las cuatro clases reales (`terrain/humahuaca_terrain.gd`, `rules/humahuaca_rules.gd`, `rules/humahuaca_progress.gd` ni `view/humahuaca_view.gd`): el pase 2 solo corrigió los stubs de reglas y de vista, y `relieve_mapa` y `ui_feel` no entregaron (sin rama). El controlador arma las cuatro capas con su versión mínima y forzar un stub no cambia nada, así que las cuatro corridas por capa son **iguales a la normal** (`degradadas.con_efecto` y `degradadas.clases_reales_presentes` quedan vacíos en el informe). Lo que prueban hoy es que el camino de reemplazo corre y que el nivel arranca, avanza y vuelve al menú con cada combinación, cáscara incluida. La sanidad de la prueba (que una corrida que no reemplaza lo que dice se vea) se hizo en el pase 1 sobre copias descartables, con un terreno «real» simulado y con un controlador que ignora `force_stub` (`pase1/sanidad_*.json`), y sigue valiendo porque ni la prueba ni sus ayudas ni el controlador cambiaron. Con la primera clase real (R1) la prueba exige que la corrida normal la use y que forzar su stub sí cambie la corrida; las cuatro clases figuran como pendientes `api-real-*` y se vuelven falla en `r1`.

**Ida y vuelta ×3** (`test_hx_smoke::_test_roundtrip_x3`, TR-111): Humahuaca → menú → Justina → menú, tres veces. Las 9 claves de estado global (`camera.far` y `fov`, escala 3D y MSAA del viewport, ambiente del audio, `settings.last_save`, `content_scale`, cámara actual y modo) quedan iguales tras salir del nivel y tras el ciclo completo con la Justina en las tres vueltas (18 comprobaciones); `OBJECT_ORPHAN_NODE_COUNT` vale 0 en todas las mediciones (`huerfanos_max` 0); el árbol tiene 222 nodos antes y 222 tras cada una de las tres vueltas, tanto al salir del nivel como al volver de la Justina.

**Verificación por la escena real** (extra, a mano: la compuerta completa todavía no la corre, BACKLOG B-024). `bash tools/vis_humahuaca.sh <carpeta> 1280x720 --no-views --flow=aproximacion,ataque@300,extraccion@321`, la herramienta de `visual` por `main.tscn` con el controlador: 28 comprobaciones, 0 fallas, 5 s. Naranja saturado **0,0 %** en el ataque (300 s) y en la extracción (321 s) contra 81,7 % y 62,8 % antes del pase 2, saturación media 0,322 y 0,357 (tope 0,42), **0,0 m** de trazo de anillos dentro de otro círculo en las tres fases y fichas de 60,9 a 70,1 px (piso 48). Es la medida independiente del hallazgo I-R1.0-3 y coincide con la del integrador.

**Capturas reales** (todas con ventana, nunca `--headless`; se miraron **una por una** con `Read`). De la compuerta: el menú de tres botones a 1280 × 720, a 1920 × 1080 y a 2560 × 1440 (los botones I, II y III en ese orden; Humahuaca habilitado con «Recomendado tras la Justina»; el Norte con su candado y «Ganá la Justina para abrirlo»; «Continuar» apagado; el último texto del menú termina dentro del cuadro en las tres), el primer cuadro del nivel a 1280 × 720 y la Justina a 1280 × 720 (su interfaz completa y sin cortes). De la escena real: aproximación de noche, ataque a los 300 s y extracción a los 321 s. Las 123 de `ui_qa` (41 por resolución) y las 2 de `--qa=humahuaca` tienen el tamaño pedido y ninguna es negra ni uniforme (se midió el desvío de la luminancia). Lo que se ve es la caja gris de stubs, con el alba ya en tonos de arena y no en naranja saturado, los anillos como un solo contorno, las fichas con silueta y las luces de los tres objetivos. Defectos que se ven y no son de esta pista: el HUD y la línea roja «Se usa la versión mínima de: terreno, reglas, progreso y vista» tapan la ficha 1 y su rótulo en el primer cuadro (`ui_feel`, BACKLOG B-021) y las dos piezas de la batería parecen dos torres (`visual`, BACKLOG B-023).

**No se verificó en R1.0 pase 2** (y por qué): el benchmark (omitido por orden); `hx_terrain` y `hx_flow` (no existen; obligatorios desde `r1`), `ui_qa_humahuaca`, `humahuaca_playthrough`, `hx_qa_tour` y `hx_agent_play` (los entregan las pistas y compuertas y documentos en R1); las reglas V6, V10 a V16, V18, V21 y V22 de `test_hx_data` (BACKLOG B-013, las enciende compuertas y documentos al abrirse R1); las cuatro clases reales de las capas; que la cámara del controlador use `yaw_deg` como rumbo de la mirada y que el mapa traiga `ancla_iglesia` (ADDENDA A-11 y A-10: las aplican `ui_feel` y `relieve_mapa` en R1; el mapa sigue con `anchor.id = templo`, BACKLOG B-018). Nadie jugó a mano: las capturas y los bots salen de la escena real con entrada inyectada.

### R1 · las cuatro pistas fusionadas en `main` (2 de noviembre de 2026)

Lo que corrió de verdad al cerrar R1, escrito por el integrador (que lleva también la propiedad de «compuertas y documentos»). Commits: los merges `fa9eb90` (relieve), `70efda5` (reglas), `f97e819` (visual) y `5a2c627` (ui); `792d7ab` (A-12); `cf1dc97` (abre la ronda `r1`); `15627bb` (herramientas del recorrido y del agente, y las reglas V6 a V22); `57ceafb` y `87f4214` (umbral de capturas, límites de cámara y hoja de fichas). Sin `push`, sin etiquetas nuevas, sin tocar `origin/main` (`72077c8`).

**Compuerta rápida de cada pista sobre su rama rebasada** (ronda vigente `r1.0`; todas con `higiene` en FALLA por las etiquetas ajenas, ver B-017):

| Pista | Rama | Resultado | Tiempo |
|---|---|---|---|
| `relieve_mapa` | `642019a` | protegidos 40; `rules` 818/0; integración 283/0; `hx_data` 289/0; `hx_smoke` 148/0; `hx_terrain` 158/0 | 1 min 22 s |
| `reglas_historia` | `74ff500` (rebasada sobre `fa9eb90`, después `792d7ab`) | la primera corrida falló `hx_data` 304/1 («sanidad: agregar la fuente S46 es legal», defecto de la prueba, A-12); la segunda: `hx_data` 304/0; `hx_smoke` 152/0; `hx_rules` 621/0; propiedad en PASA | 1 min 46 s y 1 min 54 s |
| `visual` | `d18a70d` (rebasada sobre `70efda5`) | `hx_data` 303/0; `hx_smoke` 154/0; `hx_view` 258/0 | 1 min 38 s |
| `ui_feel` | `acce3bd` (rebasada sobre `f97e819`) | `hx_data` 312/0; `hx_smoke` 154/0; `hx_flow` 166/0 | 1 min 50 s |
| integrador, `main` fusionada con `RONDA=r1` | `5a2c627` | `hx_data` 358/0; `hx_smoke` 154/0; solo `higiene` falla | 1 min 39 s |

**Compuerta completa** (`SKIP=benchmark KEEP=1 bash tools/qa_gate.sh full`, ronda vigente `r1`, 13 min 53 s, sobre `15627bb`):

| Paso de la compuerta | Resultado real | Filas que ejercita |
|---|---|---|
| `import` | PASA, 3 s | ninguna |
| `protegidos` | PASA: 40 archivos protegidos intactos contra `5ebbd28` | TR-186 |
| `compartidos` | PASA: `main.gd` +47/−4, `test_integration` +1/−1, `ui_qa` +1/−1, `run_qa` +1/−1 | TR-151 |
| `rules` (completo) | PASA: 871 comprobaciones, 0 fallas, 3 min 33 s | TR-180 |
| `integracion` | PASA: 283/0, 11 s | TR-181 |
| `jev` y `audio` | PASA: Jev 15/0; audio 17 comprobaciones con 1 falla aceptada (driver Dummy) | TR-182 |
| `hx_data` | PASA: 411/0, 2 s, con V6, V10 a V16, V18, V21 y V22 encendidas y sanidad por mutación; V20 lee 133 filas (115 activas, 6 adelantadas y 12 pendientes de rondas futuras) | TR-001 a TR-003, TR-130, TR-160 a TR-162, TR-171, TR-194 y TR-195 |
| `hx_smoke` | PASA: 154/0, 28 s, sin pendientes: las cuatro clases reales cargadas, las cinco corridas degradadas y la ida y vuelta ×3 | TR-010, TR-030, TR-067, TR-080, TR-082, TR-090, TR-110 a TR-112, TR-131, TR-132, TR-140 a TR-148, TR-150, TR-152, TR-175, TR-176, TR-191 |
| `hx_terrain` | PASA: 158/0, 1 s, con 2 pendientes de `r2a` (TR-021 y TR-022) | TR-011 a TR-020 |
| `hx_rules` | PASA: 621/0, 21 s, en modo completo y con la clase real de reglas y de progreso (`impl: real`); rendimiento medido: `nav_build_ms` 4,4 (tope 80), `plan_route_ms` 2,9 (tope 30) y `tick_ms` 0,11 (tope 2); 1 pendiente de `r2b` (el barrido de la señal) | TR-031 a TR-043, TR-052, TR-060, TR-062, TR-064 a TR-072, TR-081, TR-153 |
| `hx_view` | PASA: 258/0, 7 s | TR-091 a TR-105 |
| `hx_flow` | PASA: 166/0, 33 s | las filas de `ui_feel` de `r1` |
| `etapa` | PASA: los 4 stubs y el controlador real | CONTRATO 8.1 |
| `higiene` | **FALLA**: `git tag --list` trae `v0.2.0-alpha` y `v0.3.0-alpha`, que no son de este equipo (B-017); `origin/main` sigue en `72077c8` | TR-192 |
| `scenario` | PASA: `--scenario=humahuaca` sale con 0, 4 s | TR-155 |
| `qa_humahuaca` | PASA: `--qa=humahuaca` sale con 0 y escribe `qa_report.json` y 16 capturas, 8 s | TR-156 |
| `ui_qa` ×3 | PASA: 254/0 a 1280 × 720 (27 s), 1920 × 1080 (35 s) y 2560 × 1440 (44 s), con `captura_px` igual a la pedida | TR-183 |
| `justina_playthrough` | PASA: 18 victorias, 6 estilos, 3 rutas, 6 derrotas y el bot de interfaz gana, 5 min 22 s | TR-185 |
| `benchmark` | **OMITIDO por orden** (lo mide el Jefe de QA a solas): no se verificó | TR-157 y TR-184, sin verificar |
| `ui_qa_humahuaca` | PASA: 104/0 a 1280 × 720 (piso 60) y chequeo de desborde 31/0 a 1920 × 1080 y a 2560 × 1440; primer cuadro con 3 controles accionables, 366 caracteres, 0 términos de jerga, apertura de 13,5 s, ficha más cercana al borde a 6,8 %, reintento en 0,32 s y contraste mínimo del HUD 7,49:1 | TR-119 y las filas de `ui_feel` |
| `humahuaca_playthrough` | PASA: sale con 0; sobre las 8 semillas de calibración el experto gana 8 de 8 (551 s en promedio, golpe medio 46,8) y el pasivo pierde 8 de 8 por `amanecio` | TR-172 |
| `hx_qa_tour` | **FALLA en esa corrida**: pedía 24 capturas y el recorrido escribe 23 (umbral mal contado, no defecto del recorrido); corregido en `57ceafb` y vuelto a correr: PASA (23 capturas, 7 vistas, cuadro inicial con los tres objetivos y la partida, templo de 7,3 m, el bot gana) | TR-173 y TR-196 |
| `hx_agent_play` | PASA: arnés `hx_agente_v1`, 30 turnos con capturas de 1280 × 720, la primera orden entra por clic en el turno 4 a los 3,0 s de juego (con el arnés contestando solo) | TR-197 |
| `vis_flow` | PASA: `tools/vis_humahuaca.sh --flow` con 0 fallas: fichas de 49,3 a 70,9 px, naranja saturado 0,2 % (tope 5 %) y saturación media de 0,315 y 0,343 (tope 0,42) | TR-198 |
| `salida_limpia` | PASA: ningún `SCRIPT ERROR`, `SHADER ERROR`, `Parse Error`, `ERROR:` ni fuga en los registros; 0 `WARNING` | TR-193 |

La línea final de la corrida completa dice `FALLA (2 pasos)`: `higiene` (las dos etiquetas ajenas) y `hx_qa_tour` (el umbral de 24 capturas, un error del paso nuevo). **Segunda corrida de los pasos del nivel** con el umbral corregido (`SKIP=` de todo lo demás, 2 min 05 s, sobre `57ceafb`): `hx_terrain` 158/0, `hx_rules` 621/0, `hx_view` 258/0, `hx_flow` 166/0, `ui_qa_humahuaca` 104/0 y 31/0 y 31/0, `humahuaca_playthrough`, `hx_qa_tour` (23 capturas), `hx_agent_play` y `vis_flow` en PASA. Ningún paso atribuible a una pista falló.

**Por la escena real** (criterio de cierre de R1: «el experto gana y el pasivo pierde por la escena real»). `tools/humahuaca_playthrough.gd --level=scene --policies=experto,pasivo,interfaz --seeds=3,5,7` con ventana real a 1280 × 720 (40 s, sobre `48e60ac`): el experto gana 3 de 3 (mediana de 551 s), la política `interfaz` —que hace clic en el botón del «siguiente paso»— gana 3 de 3 (mediana de 496 s) y el pasivo pierde 0 de 3, los tres por `amanecio` a los 390 s. Salida 0.

**Qué cambió desde R1.0.**

- Las cuatro clases reales entraron: `HumahuacaTerrain` (relieve de la lámina 03, malla de 4 m, `nav_grid` y `los` del nivel; A/B contra Copernicus: la lámina sigue, A-02 y A-13), `HumahuacaRules` y `HumahuacaProgress` (el bucle completo con mundo fijo, las 8 causas, guardado con `validate_snapshot`), la vista real partida por responsabilidad y el controlador completo de `ui_feel`. `qa_state().layers` informa las cuatro capas como `real`.
- `test_hx_data` pasa de 296 a 411 comprobaciones: V6, V10, V11, V12, V13 completa, V14, V15, V16, V18, V21 y V22 corren desde `r1` y se prueban con copias rotas (B-013). Las reglas dieron un hallazgo real: una pista de reintento de 123 caracteres (B-025, excepción fechada hasta `r2a`).
- Aparecen `tools/hx_qa_tour.gd`, `tools/hx_agent_play.gd` y tres pasos nuevos de la compuerta completa (`hx_qa_tour`, `hx_agent_play`, `vis_flow`); las pistas entregaron `humahuaca_playthrough.gd`, `ui_qa_humahuaca.gd`, `test_hx_terrain.gd` y `test_hx_flow.gd`.

**Capturas reales de integración** (todas con ventana, nunca `--headless`; se miraron **una por una** con `Read`), en `evidence/humahuaca/r1/integrador/cierre_r1/` (14 JPEG de 300 KB o menos): el menú de tres botones (I Justina, II Humahuaca con «Recomendado tras la Justina», III el Norte con su candado); el briefing de una página con «Perder no es grave»; el primer cuadro en pausa (`inicial_caja_gris.jpg`, también en `evidence/humahuaca/r1/`, con su versión de albedo sin interfaz) con las cinco fichas numeradas, los tres objetivos encendidos y un solo «siguiente paso»; la aproximación bajo lluvia con el aviso «Dar la señal»; el ataque a los 300 s («Desde la señal: 0:15», «Atacando», «Golpe 0 de 100»); la extracción con el arreo cargando («Carga 2200 de 2200 kg», «Refuerzo: entre 1:30 y 4:00»); el parte de derrota por `amanecio` con causa, momento y lugar, consejo, tres datos y los botones de reintento; el parte de victoria con medalla de bronce y el epílogo con etiquetas; el primer cuadro a 1024 × 640; `juego_alba`; la batería vista desde arriba (una losa con parapeto y piezas bajas, sin torres); el patio de la posta con cañones, barriles y carros; la hoja de las cinco fichas (siluetas distintas sobre fondo liso, 71 a 96 px) y el límite norte con el horizonte. Las cifras y el dibujo están en `metrics_integrador_r1.json`.

**Límites honestos de R1.**

- **El benchmark no se corrió** (orden del encargo). La única señal es indicativa: el recorrido mide un cuadro medio de 4,0 a 5,0 ms en `media` con la escena real y el HUD (sin sincronía vertical, RTX 3080 Ti), contra el tope de 4,0 ms (B-030).
- **No hubo una corrida del agente-jugador de verdad** (B-027): el arnés se probó con `--selftest` (el arnés contesta solo, con información que el agente no tiene) y con `--selftest=pasivo` (derrota por `amanecio` y reintento). No es una partida humana ni de un agente ciego.
- Nadie jugó a mano (A-03): los bots leen `hud_state()` o aprietan el botón del «siguiente paso». El veredicto máximo sigue siendo «PRESENTABLE, no certificado por humanos».
- `token_px` de `ui_qa_humahuaca` (38,4 a 46,4 px) no coincide con lo que se ve (hoja de fichas 71 a 96 px; proyección 49,3 a 70,9 px): B-026. El río termina en seco en el borde norte del mapa (B-029).
- El render héroe no está aprobado: falta la respuesta del QA a VP-14 (A-13).
- Las etiquetas ajenas siguen: `higiene` falla en toda compuerta y E05 no puede dar verde (B-017).

### R1 · compuerta completa de compuertas y documentos (2 de noviembre de 2026)

Lo que corrió de verdad después del cierre del integrador (`70124a0`), escrito por «compuertas y documentos». Commits: `81b6c8c` (el arnés del agente-jugador, el recorrido de QA, la compuerta y V10), `c193166` (las claves de `qa_state()`, el guion de protocolo más robusto y los registros de pasos fallidos) y el de este registro. Sin `push`, sin etiquetas nuevas, sin tocar `origin/main` (`72077c8`).

**Cómo se corrió.** Tres compuertas completas con `SKIP=benchmark KEEP=1 bash tools/qa_gate.sh full`, ronda `r1`, `APPDATA` aislado propio de cada corrida, ventana real (sin `--headless`) para `ui_qa`, `--qa=humahuaca`, `justina_playthrough`, `ui_qa_humahuaca`, el recorrido, el arnés y `vis_flow`, `--audio-driver Dummy`, Godot 4.7.2 con Forward+ en una NVIDIA GeForce RTX 3080 Ti y un monitor de 1920 × 1080, con el árbol limpio y sin que quien las corrió hiciera nada más con ventana en paralelo:

- sobre `70124a0` (el cierre del integrador, sin tocar nada): **13 min 48 s**; la línea final dice `FALLA (1 pasos)` y el único paso que falla es `higiene` (BACKLOG B-017);
- sobre `81b6c8c`: **15 min 04 s**; la línea final dice `FALLA (3 pasos)`: `higiene` y dos pasos de **un tropiezo del entorno** (`ui_qa` a 2560 × 1440 perdió la entrada real: 8 comprobaciones fallaron, el proceso salió con 0 después de 18 de sus 41 capturas y sin escribir su informe; `salida_limpia` solo contó las líneas `ERROR:` de ese registro). Repetido solo, a los pocos minutos y con el mismo comando, dio 254/0 en 42 s con la captura real de 2560 × 1440 y sin errores (BACKLOG B-044);
- sobre `c193166` (el commit del código de esta pasada): **16 min 05 s**; la línea final dice `FALLA (1 pasos)` y el único paso que falla es `higiene`, por las dos etiquetas ajenas (B-017). **Es la corrida que vale**: todas las cifras de la tabla de abajo son de ella.

El benchmark **no se corrió** (orden del encargo: lo corre el Jefe de QA a solas). Las cifras de las tres corridas son idénticas salvo lo que sumó `81b6c8c` y `c193166` (`hx_data` pasa de 411 a 419 comprobaciones y `hx_smoke` de 154 a 155; el recorrido suma las cifras de texto; la compuerta suma `hx_agent_protocolo` y `hx_agent_viejos`).

| Paso de la compuerta | Resultado real | Filas que ejercita |
|---|---|---|
| `import` | PASA: proyecto importado en 0 min 04 s | ninguna |
| `protegidos` | PASA: 40 archivos protegidos intactos contra 5ebbd28 | TR-186 |
| `compartidos` | PASA: main.gd +47/-4, test_integration +1/-1, ui_qa +1/-1, run_qa +1/-1 (topes de la rúbrica T01) | TR-151 |
| `rules` | PASA: 871 comprobaciones, 0 fallas, piso 871, 3 min 57 s | TR-180 |
| `integracion` | PASA: 283 comprobaciones, 0 fallas, piso 283, 0 min 12 s | TR-181 |
| `hx_data` | PASA: 419 comprobaciones, 0 fallas, piso 40, 0 min 03 s | TR-001 a TR-003, TR-160 a TR-162, TR-171, TR-194, TR-195 y TR-204 |
| `hx_smoke` | PASA: 155 comprobaciones, 0 fallas, piso 25, 0 min 28 s | TR-010, TR-067, TR-082, TR-110 a TR-112, TR-131, TR-132, TR-140 a TR-148, TR-150, TR-152, TR-175, TR-176 y TR-191 |
| `hx_terrain` | PASA: 158 comprobaciones, 0 fallas, piso 60, 0 min 01 s, 2 pendientes de rondas futuras | TR-011 a TR-019 |
| `hx_rules` | PASA: 621 comprobaciones, 0 fallas, piso 150, 0 min 22 s, 1 pendientes de rondas futuras | TR-031 a TR-072 |
| `hx_view` | PASA: 258 comprobaciones, 0 fallas, piso 25, 0 min 08 s | TR-091 a TR-105 |
| `hx_flow` | PASA: 166 comprobaciones, 0 fallas, piso 50, 0 min 32 s | TR-119 y las filas de la interfaz |
| `etapa` | PASA: entregables de R1.0 presentes (4 stubs y el controlador) | CONTRATO 8.1 |
| `higiene` | **FALLA**: etiquetas={v0.1.0 v0.2.0-alpha v0.3.0-alpha} (debe quedar solo v0.1.0); | TR-192 |
| `jev` | PASA: 15 comprobaciones, 0 fallas, piso 15, 0 min 01 s | TR-182 |
| `audio` | PASA: 17 comprobaciones y 1 falla aceptada (driver de audio real, no Dummy), 0 min 06 s | TR-182 |
| `scenario` | PASA: --scenario=humahuaca abre el nivel directo y sale con 0 (0 min 04 s) | TR-155 |
| `qa_humahuaca` | PASA: --qa=humahuaca salió con 0, escribió qa_report.json y 16 capturas (mínimo 8), 0 min 10 s | TR-156 |
| `ui_qa_1280x720` | PASA: 254 comprobaciones, 0 fallas, captura 1280x720 real, 0 min 27 s | TR-183 |
| `ui_qa_1920x1080` | PASA: 254 comprobaciones, 0 fallas, captura 1920x1080 real, 0 min 37 s | TR-183 |
| `ui_qa_2560x1440` | PASA: 254 comprobaciones, 0 fallas, captura 2560x1440 real, 0 min 46 s | TR-183 |
| `justina_playthrough` | PASA: 18 victorias, 6 estilos, 3 rutas, 6 derrotas, el bot de interfaz gana (6 min 17 s) | TR-185 |
| `benchmark` | **OMITIDO por orden**: pedido en SKIP; la compuerta queda PARCIAL | TR-157 y TR-184, sin verificar |
| `ui_qa_hx_1280x720` | PASA: 104 comprobaciones, 0 fallas (piso 60) | TR-119 |
| `ui_qa_hx_1920x1080` | PASA: 31 comprobaciones, 0 fallas (piso 1) | TR-119 |
| `ui_qa_hx_2560x1440` | PASA: 31 comprobaciones, 0 fallas (piso 1) | TR-119 |
| `humahuaca_playthrough` | PASA: sale con 0: el experto gana y el pasivo pierde | TR-172 |
| `hx_qa_tour` | PASA: 23 capturas, 7 vistas, cuadro inicial con los tres objetivos y la partida, templo 7.3 m, cuadro medio 6.29 ms (indicativo), el bot victory; texto del bot: jerga 0, desbordes 0, brecha sin siguiente paso 153.0 s (ataque 17.0 s), contracciones sin hacer 0 (informativo); posiciones en píxeles de la captura (x0.8) | TR-173, TR-196, TR-202 y TR-203 |
| `hx_agent_play` | PASA: arnés hx_agente_v1: 30 turnos con capturas de 1280x720, primera orden aceptada en el turno 4 (3.0 s de juego), cierre max_turnos (selftest, no es el agente) | TR-173 y TR-197 |
| `hx_agent_protocolo` | PASA: el arnés atendió un agente de guion por archivos: 8 turnos, 9 comprobaciones sin fallas (acción a medias, JSON roto, clic fuera de la ventana, tipo desconocido, respuestas.json y bitácora), 17.0 s | TR-199 y TR-200 |
| `hx_agent_viejos` | PASA: con una acción, unas respuestas y una captura viejas en la carpeta: las borró (3), no tocó la bitácora y abandonó a los 4 s sin contestar con lo viejo | TR-201 |
| `vis_flow` | PASA: escena real por tools/vis_humahuaca.sh --flow: 0 fallas (fichas, alba y anillos) | TR-198 |
| `salida_limpia` | PASA: ningún SCRIPT ERROR, SHADER ERROR, Parse Error, ERROR: ni fuga en los registros (0 WARNING contados) | TR-193 |

La línea final de la corrida que vale: `GATE full (r1): FALLA (1 pasos) | protegidos 40 | rules 871/0 | integracion 283/0 | jev 15/0 | audio 17/1 | hx_data 419/0 | hx_smoke 155/0 | hx_terrain 158/0 | hx_rules 621/0 | hx_view 258/0 | hx_flow 166/0 | ui_qa_1280x720 254/0 | ui_qa_1920x1080 254/0 | ui_qa_2560x1440 254/0 | falla: higiene | 16 min 05 s`. El recorrido midió **un cuadro medio indicativo de 5,07 a 6,29 ms** (5,23, 5,81 y 6,29 ms en las tres compuertas; p95 de 6,9 a 8,0 ms; construcción de 907 a 1 171 ms; a 1920 × 1080, 8,41 ms), sin vsync, en la RTX 3080 Ti y con la máquina compartida: no es la medida oficial (el benchmark no se corrió), pero está por encima del tope de `media` (4,0 ms) en las cinco corridas (BACKLOG B-030).

**Qué cambió desde `70124a0`.**

- `tools/hx_agent_play.gd`: `objetivos_identificados_en_turnos` sale de la bitácora del agente (con la definición por clics J08 no podía aprobar nunca: tres frentes necesitan tres clics y la rúbrica pide menos de 3 turnos); el arnés borra los `turno_NN.png`, `accion_NN.json` y `respuestas.json` de una corrida anterior (demostrado antes del arreglo: con una acción y unas respuestas viejas, el arnés aplicaba la acción vieja en el turno 1 y cerraba con `respuestas` tras 1 turno; ahora los borra, no toca la bitácora y abandona a los 4 s con `--wait-s=4`); un archivo a medias ya no llena el registro de `ERROR: Parse JSON failed`; el informe suma `t_despues_s`, `mapa_desde_turno`, `objetivos_tocados_en_turnos` y `archivos_viejos_borrados`.
- `tools/hx_agent_guion.py` (nuevo): un agente de guion que recorre el protocolo por archivos con un oráculo propio (TR-199, TR-200 y TR-201).
- `tools/hx_qa_tour.gd`: las posiciones de `qa_report.json` salen en píxeles de la captura (venían en píxeles lógicos: ×0,8 a 1280 × 720 y ×1,2 a 1920 × 1080; `qa_imagen.py legible` no veía ningún edificio porque los rectángulos de la posta caían fuera de la imagen); suma la jerga, los desbordes de texto, la brecha de decisión y las contracciones sin hacer medidos sobre el arco del bot, y `textos_visibles.txt` (TR-202 y TR-203).
- `tests/hx_validators.gd` y `tests/test_hx_data.gd`: V10 suma las contracciones y deja cinco plantillas de `reglas_historia` como excepción fechada hasta `r2a` (TR-204; BACKLOG B-036).
- `tests/test_hx_smoke.gd`: el controlador real trae, con su tipo, las claves de `qa_state()` que leen el arnés y el recorrido (TR-205); `tools/qa_gate.sh`: el registro de un `ui_qa` que falla se renombra `.falla` y `salida_limpia` no cuenta la misma falla dos veces.

**Un tropiezo más, ajeno al nivel.** La compuerta rápida sobre `46e6027` (`quick integrador`, 1 min 45 s) dio `integracion 283/5`: cinco comprobaciones seguidas de `_justina` en `tests/test_integration.gd` (marcar un vado, señal a Liniers y abordaje). Repetida sola 17 veces (14 de ellas seguidas) y en las tres compuertas completas dio 283/0: es una prueba de la Justina que arranca sin fijar la semilla (`main.gd:376`: el fondo del río cambia en cada partida), así que falla de vez en cuando (1 de 21 corridas de hoy). No se tocó (BACKLOG B-045; arreglo de una línea para el integrador).

**Ensayo de las herramientas del QA (anexo A de la rúbrica), sobre el paquete de esta corrida.** No es un veredicto: el Jefe de QA las corre sobre el commit que certifica. `qa_imagen.py tokens` (V03: 5 siluetas distintas, peor IoU 0,53) y `calib` (V04: mediana 0,4, p90 3,1, 0,00 % de píxeles sobre 22) dan PASA; `paleta` (V04) encuentra los 24 HEX exactos; `markers` (V05) encuentra celeste, oro y borgoña; `qa_etiquetas.py` (H01) da 186 entidades con etiqueta y 0 violaciones; `qa_agente.py` (J08) lee el `arnes.json` de la prueba por archivos sin errores (8 de 8 con el reintento, 7 de 8 sin él) y `qa_balance.py` lee el `hx_playthrough_v1` del recorrido de reglas (los ítems J dan FALLA por falta de datos: 8 semillas, solo experto y pasivo, y las victorias duran 9:11 contra 11:00 a 13:00). V06 da FALLA con las posiciones ya en píxeles (`legible`, `bordes` y `panorama`; BACKLOG B-033) y `contraste` (V05) no puede correr con los `notes.rects` de `ui_qa_humahuaca` (píxeles lógicos y un rectángulo de `alerta` vacío; BACKLOG B-032).

**Capturas reales** (todas con ventana, nunca `--headless`; se miraron **una por una** con `Read`). Del recorrido: las 7 vistas con interfaz y las 7 sin ella, el primer cuadro, las 3 de albedo, las 4 de límite de cámara (más dos ampliaciones del horizonte para descartar una costura del terreno: la línea fina que cruza `limite_e` y `limite_o` es una curva de nivel del shader del terreno, cada 5 m), la hoja de fichas y `inicial_caja_gris.jpg`. Del arnés: los turnos 1 a 3 (las dos páginas del briefing y la apertura), 26, 28, 30 y 31 (el ataque y el parte de derrota) de la repetición por archivos. Lo que se ve: el cuadro inicial lee bien (cinco fichas con su anillo, tres luces amarillas con su rótulo, un solo «siguiente paso» con su botón y el minimapa); `grupos_en_accion` se saca con el juego en t = 0 y no muestra la torre ni las fichas (B-041); `panorama_alto` no muestra el cielo (B-033); la cinta de agua de `limite_n` termina en punta (B-029); el parte de derrota de 3:54 se lee bien (causa con momento y lugar, consejo, tres datos y «Reintentar»); y en el ataque el «siguiente paso» dice «Esperá la toma de el cuartel.» mientras la partida de Portal se rompe bajo la torre, sin aviso crítico a la vista (B-036 y B-037).

**No se verificó en esta pasada** (y por qué): el benchmark (omitido por orden); la corrida del agente-jugador de verdad (J08, B-027: hace falta un subagente nuevo sin acceso al código); nadie jugó a mano (las capturas del arnés son de las acciones de un bot repetidas por archivos); el render héroe (sin aprobación del QA, VP-14); la tesela Copernicus como fuente del relieve (la rúbrica R05 se sigue midiendo contra la lámina, B-028); los tres escenarios de resolución del recorrido de QA (la compuerta corre uno a 1280 × 720; a mano corrió también a 1920 × 1080 con las posiciones en ×1,2, y el integrador lo había corrido a 1024 × 640; a 2560 × 1440 no se corrió).
