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
| TR-207 | 3.5 | Del parte de derrota o de victoria se abre el Diario o la ayuda y se vuelve al mismo parte (clic, Esc, Enter o Espacio): con la partida terminada nunca queda una pantalla sin controles ni salida (H-R1-2) | test_hx_flow::_test_full_cycle | r1 |
| TR-208 | 3.5 | Con fichas elegidas y avisos en pantalla ningún panel del HUD pisa a otro, el «siguiente paso» entra en dos líneas y nada queda fuera del viewport a 1280 × 720 y a 1024 × 640 (H-R1-7) | test_hx_flow::_test_hud_guided_selection | r1 |
| TR-209 | 3.2 | Una parada de ruta fuera del mapa se rechaza con motivo, en la orden y en la vista previa, y el estado sigue siendo válido y se puede guardar y volver a abrir (H-R1-5) | test_hx_rules::_test_waypoints_outside_map | r1 |
| TR-210 | 3.2.4 | Un guardado con un dato de otro tipo o de otra forma se rechaza con motivo y con la ruta del dato, sin errores de script (esquema estricto; H-R1-6) | test_hx_rules::_test_save_schema_cases | r1 |
| TR-211 | 3.2.4 | La mutación de tipo (ocho clases) sobre cada nodo de varios guardados no deja pasar uno que reviente al jugar (H-R1-6) | test_hx_rules::_test_save_type_fuzz | r1 |
| TR-212 | 3.2.4 | El esquema del guardado nunca rechaza un estado que el juego produce (partidas enteras de todas las políticas) y cubre todas las claves del estado | test_hx_rules::_test_valid_states_everywhere | r1 |
| TR-213 | 3.2 | Órdenes con basura (paradas fuera del mapa, opciones de otro tipo, acciones inexistentes) no dejan un estado inválido ni un error de script | test_hx_rules::_test_order_fuzz | r1 |
| TR-214 | 3.3 | Un humahuaca_progress.json o unos puntos de control dañados no bloquean ni revientan: se descartan con una nota | test_hx_rules::_test_progress_files_hostile | r1 |
| TR-215 | 3.2.3 | Ningún texto que lee el jugador trae «de el» ni «a el» sin contraer (B-036) | test_hx_rules::_test_contractions | r1 |
| TR-216 | 5.1 | El recorrido de QA saca también grupos_en_accion y patio_posta con el juego en el momento que pide el QA (la torre dispara con tres agrupaciones cerca o lleva 90 s de fuego; el primer paso de la extracción con el chip de carga a la vista), con y sin interfaz, y mide el cuadro en pleno ataque (B-041; M04 y M05) | hx_qa_tour::_shoot_action | r1 |
| TR-217 | 5.1 | La partida del --selftest repetida por el protocolo de archivos da lo mismo turno a turno (acción, aplicada, orden aceptada, modo, diálogo, fase y tiempo de juego, primera orden e intentos): el protocolo no cambia la partida | tools/hx_agent_guion.py::comparar | r1 |
| TR-218 | 5.1 | Por la escena real el experto gana y el pasivo pierde por amanecio (humahuaca_playthrough --level=scene, semillas 3, 5 y 7; el criterio de cierre de R1, CONTRATO 8.2) | qa_gate::step_level_tools | r1 |
| TR-219 | 5.1 | El arnés deja fin.json con el cierre en la carpeta de turnos, sea cual sea la razón (respuestas, max_turnos, abandono, sin_captura o sin_controlador), y borra el de una corrida anterior | hx_agent_play::_write_fin | r1 |
| TR-220 | 3.4 | Las figuras siguen a sus agrupaciones cuadro a cuadro: a ×1, ×2 y ×4 cada figura queda a 1 m o menos de su agrupación en todos los cuadros, se mueve en cada cuadro en que se mueve la agrupación y los círculos de visibilidad la siguen (H-R1-9; antes 30,8, 92,5 y 123,4 m) | test_hx_view::_test_units_follow_rules | r1 |
| TR-221 | 5.1 | Por la escena real (main.tscn con el controlador, ventana y tiempo reales) la marcha de las cinco agrupaciones a ×1 y a ×4 deja a cada figura a 1 m o menos de su agrupación en todos los cuadros; contra el main anterior la misma comprobación falla con 7,7 y 38,6 m (H-R1-9) | vis_humahuaca::_flow_march | r1 |
| TR-222 | 3.4 | El terreno que se dibuja es continuo en las cuatro costuras de la ventana y en el perímetro del contexto (salto de 0,10 m o menos), y el río, los caminos y las zanjas se apoyan en la malla dibujada: ningún vértice ni punto interior queda bajo el suelo y las puntas de la cinta del río se apagan cerca del borde del contexto (H-R1-11) | test_hx_view::_test_terrain_rendered | r1 |
| TR-223 | 3.4 | probes() mide la ficha con el alto dibujado en píxeles lógicos y marca on_screen, y la escala de las fichas y los anillos se mide una sola vez por cámara distinta (B-026, B-034 y B-047) | test_hx_view::_test_probes_and_scales | r1 |
| TR-224 | 3.5 | El objetivo del HUD dice una frase vigente en cada fase (la extracción no pide tomar frentes ya tomados) y ningún texto de la interfaz queda cortado ni se pisa con otro a 1280 × 720, 1024 × 640 y 1920 × 1080 (H-R1-10; B-048) | test_hx_flow::_test_objective_by_phase | r1 |
| TR-225 | 3.5 | La medida de recortes de texto que usan las pruebas es la misma de la sonda del QA y ve un texto cortado a propósito (sanidad de la medida) | test_hx_flow::_test_cut_probe_sanity | r1 |
| TR-226 | 3.5 | El chip de carga se ve apenas el arreo empieza a cargar, en el ataque, y destruir a mano pregunta una vez antes de quemar la carga (B-053 b y B-052) | test_hx_flow::_test_load_chip | r1 |
| TR-227 | 3.5 | Un reintento (desde un punto de control o con el mismo mundo) cuenta un solo intento | test_hx_flow::_test_retry_counts | r1 |
| TR-228 | 3.5 | Si pasan 12 s reales con el nivel jugable y ninguna orden dada, un aviso dice cómo arranca el reloj, una sola vez por intento (onboarding.first_order_hint_s) | test_hx_flow::_test_first_decision | r1 |
| TR-229 | 3.5 | La vista previa de la ruta alcanza al cursor: el último movimiento recibido dentro de la espera de 80 ms rehace el plan apenas pasa la espera | test_hx_flow::_test_preview_catches_up | r1 |
| TR-230 | 3.5 | Los avisos no repiten el título de la alerta a la vista, el siguiente paso con el botón apagado dice la causa y los términos que nadie entendía (Golpe, Desvelo, ▲ y puntos) traen su cartel (B-052) | test_hx_flow::_test_alert_dedupe_and_tips | r1 |
| TR-231 | 3.5 | La orden dada se nombra en un aviso, el rechazo dice quién sí puede hacerla y con qué tecla, y una parada fuera del mapa no se suma a la ruta (B-046 b y B-052 b y e) | test_hx_flow::_test_order_feedback | r1 |
| TR-232 | 5.1 | La partida que el --selftest del arnés juega obedeciendo la guía (el botón del «siguiente paso», o el de la acción que la guía pide cuando un aviso lo esconde) llega al parte de victoria y cierra con respuestas.json, y repetida entera por archivos da la misma partida turno a turno (antes se cortaba a los 30 turnos y perdía el primer ataque porque daba la señal apenas un aviso la ofrecía) | qa_gate::step_level_tools | r1 |
| TR-233 | 5.1 | Por el arnés, con el primer intento pasivo: el parte de derrota por amanecio trae «Reintentar», el arnés lo aprieta, el intento nuevo empieza de cero y gana, y la corrida cierra con respuestas.json (J08: «si perdés, podés reintentar») | qa_gate::step_level_tools | r1 |
| TR-234 | 5.1 | Si la ventana no dibuja, el arnés espera --draw-timeout, la trae al frente y, si sigue sin dibujar, cierra con sin_captura y fin.json en lugar de quedarse colgado | hx_agent_play::_wait_draw | r1 |

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

### R1 pase 2 · las ramas de `reglas_historia` y `ui_feel`, hook-10 y la compuerta completa (2 de noviembre de 2026)

Lo que corrió de verdad al cerrar el pase 2 de R1, escrito por el integrador (que lleva también la propiedad de «compuertas y documentos»). Commits sobre `f54ddc0`: los merges `e0ce410` (reglas) y `651476f` (ui), `a219ff5` (H-R1-4, B-045 y V10/V11 sin excepciones), `10d9ae0` (hook-10, H-R1-1) y el de este registro. Sin `push`, sin etiquetas nuevas, `origin/main` en `72077c8`.

**Compuerta rápida de cada pista sobre su rama rebasada** (ronda vigente `r1`; las dos con `higiene` en FALLA por las etiquetas ajenas `v0.2.0-alpha` y `v0.3.0-alpha`, que fallan igual en `main`, B-017):

| Pista | Rama | Resultado | Tiempo |
|---|---|---|---|
| `relieve_mapa` | sin rama (sin resultado en el pase 2) | no entra nada; sigue su clase real de R1 | — |
| `reglas_historia` | `hx-reglas-r1-p2` | protegidos 40, `test_rules` rápido 818/0, `test_integration` 283/0, `hx_data` 420/0, `hx_smoke` 155/0, `hx_rules` 679/0, salida limpia; falla solo `higiene` | 2 min 14 s |
| `visual` | sin rama (sin resultado en el pase 2) | no entra nada; sigue su vista real de R1 | — |
| `ui_feel` | `hx-ui-r1-p2`, rebaseada sobre el merge de reglas (los tres commits cambian de hash) | protegidos 40, `test_rules` rápido 818/0, `test_integration` 283/0, `hx_data` 420/0, `hx_smoke` 155/0, `hx_flow` 213/0, salida limpia; falla solo `higiene` | 2 min 23 s |

**H-R1-4 (reproducción y arreglo).** `tools/ui_qa.gd` a 2560 × 1440 con el puntero real del SO sobre la ventana, antes y después de las dos líneas de `a219ff5`:

| Condición | Corridas | Resultado |
|---|---|---|
| Código anterior, puntero quieto sobre la ventana | 2 | 254/1 (única falla: R5, «el rotulo 'Centro de la vista' no flota…») y 254/0 |
| Código anterior, puntero moviéndose sobre la ventana (un movimiento cada 120 ms) | 1 | 254/1 (R5) |
| **Código nuevo, puntero quieto sobre la ventana** | **5 seguidas** | **254/0 las cinco** (44, 45, 44, 46 y 47 s; captura real de 2560 × 1440) |
| Código nuevo, puntero moviéndose a propósito | 4 | 254/0 en 1; falla R1 «abandonar pide una segunda confirmación» en 1; 2 murieron con un error de script tras una falla de «Rechazar», sin informe (la quinta, ya con el puntero quieto, dio 254/0) |

La última fila no es el criterio de aceptación (el QA pide el puntero sobre la ventana, no agitándose): muestra que la prueba de la Justina no tolera que se mueva el mouse mientras inyecta su propia entrada, que es la causa de B-044.

**H-R1-1 (diagnóstico de cuadro, no es el benchmark oficial).** Script descartable del integrador (fuera del repositorio): arma `main.tscn`, entra al nivel con `_start_humahuaca`, lo deja en pleno ataque con `benchmark_prepare()` y mide 270 cuadros por configuración (30 de calentamiento), 1440 × 900, Forward+, sin sincronía vertical, RTX 3080 Ti, `--audio-driver Dummy`. Cuadro medio en `media`:

| Configuración (antes de hook-10) | Cuadro medio | Llamadas de dibujo |
|---|---|---|
| Todo encendido | 3,79 a 5,34 ms (cuatro mediciones) | 366 |
| `main.gd` sin su `_process` | **1,32 ms** | 366 |
| La vista sin su `_process` | **1,31 ms** | 366 |
| Sin la interfaz 2D (el HUD sigue calculándose) | 3,77 ms | 202 |
| Sin la vista 3D (se oculta; sus `_process` siguen) | 4,07 ms | 164 |
| Sin 3D ni 2D (solo los scripts de cuadro) | 3,73 ms | 0 |
| Sin 3D, sin 2D y sin el `_process` del controlador | 0,46 ms | 0 |

Lo que dice: el costo no estaba en dibujar (ni la vista ni el HUD cuestan: ocultarlos casi no cambia el cuadro) sino en los scripts de cada cuadro, y desaparecía igual quitando el `_process` de `main.gd` o el de la vista. Es la cámara: en modo `hx`, `main._process` seguía llamando a `_apply_camera()` y pisaba `main.camera` con la pose de la Justina antes de que el controlador (prioridad 10) la volviera a ubicar, así que el `_process` de la vista y el `update_state` del controlador medían dos cámaras distintas por cuadro (A-11) y `check_rings` rearmaba los anillos de visibilidad enteros dos veces por cuadro (compara el ancho que les toca a la distancia de la cámara y, si cambió, libera y crea las mallas). Con hook-10 (una línea) todo lo demás queda igual:

| Perfil (después de hook-10) | Cuadro medio, tres mediciones por corrida | p95 | Llamadas de dibujo |
|---|---|---|---|
| `media` | 1,18 a 1,78 ms | 1,3 a 3,1 ms | 363 a 367 |
| `alta` | 1,26 a 1,41 ms | 1,7 a 2,1 ms | 365 a 367 |
| `baja` | 1,16 a 1,41 ms | 1,8 a 2,1 ms | 302 a 308 |

(Una corrida de `baja` dio 7,4 ms con p95 de 16 ms mientras la máquina tenía otra carga; repetida sola dio 1,16 a 1,41 ms. Se informa porque pasó.) El tope de `media` es 4,0 ms y el p95 8,3 ms; el benchmark oficial lo corre el Jefe de QA a solas y **no se corrió acá** (orden del encargo).

**Compuerta completa** (`KEEP=1 SKIP=benchmark bash tools/qa_gate.sh full`, ronda `r1`, `APPDATA` aislado propio, ventana real —sin `--headless`— para `ui_qa`, `--qa=humahuaca`, `justina_playthrough`, `ui_qa_humahuaca`, el recorrido, el arnés y `vis_flow`, `--audio-driver Dummy`, Godot 4.7.2 con Forward+ en una NVIDIA GeForce RTX 3080 Ti, el árbol limpio en `10d9ae0` y con el puntero quieto; sin nada más con ventana en paralelo):

| Paso de la compuerta | Resultado real | Filas que ejercita |
|---|---|---|
| `import` | PASA: proyecto importado en 0 min 03 s | ninguna |
| `protegidos` | PASA: 40 archivos protegidos intactos contra 5ebbd28 | TR-186 |
| `compartidos` | PASA: main.gd +48/-4, test_integration +2/-1, ui_qa +3/-1, run_qa +1/-1 (topes de la rúbrica T01) | TR-151 |
| `rules` | PASA: 871 comprobaciones, 0 fallas, piso 871, 3 min 46 s | TR-180 |
| `integracion` | PASA: 283 comprobaciones, 0 fallas, piso 283, 0 min 13 s | TR-181 |
| `hx_data` | PASA: 420 comprobaciones, 0 fallas, piso 40, 0 min 02 s | TR-001 a TR-003, TR-160 a TR-162, TR-171, TR-194, TR-195 y TR-204 |
| `hx_smoke` | PASA: 158 comprobaciones, 0 fallas, piso 25, 0 min 32 s | TR-010, TR-067, TR-082, TR-110 a TR-112, TR-131, TR-132, TR-140 a TR-148, TR-150, TR-152, TR-175, TR-176, TR-191 y TR-206 |
| `hx_terrain` | PASA: 158 comprobaciones, 0 fallas, piso 60, 0 min 01 s, 2 pendientes de rondas futuras | TR-011 a TR-019 |
| `hx_rules` | PASA: 679 comprobaciones, 0 fallas, piso 150, 2 min 15 s, 1 pendientes de rondas futuras | TR-031 a TR-072 |
| `hx_view` | PASA: 258 comprobaciones, 0 fallas, piso 25, 0 min 09 s | TR-091 a TR-105 |
| `hx_flow` | PASA: 213 comprobaciones, 0 fallas, piso 50, 0 min 44 s | TR-119 y las filas de la interfaz |
| `etapa` | PASA: entregables de R1.0 presentes (4 stubs y el controlador) | CONTRATO 8.1 |
| `higiene` | **FALLA**: etiquetas={v0.1.0 v0.2.0-alpha v0.3.0-alpha} (debe quedar solo v0.1.0) | TR-192 |
| `jev` | PASA: 15 comprobaciones, 0 fallas, piso 15, 0 min 01 s | TR-182 |
| `audio` | PASA: 17 comprobaciones y 1 falla aceptada (driver de audio real, no Dummy), 0 min 06 s | TR-182 |
| `scenario` | PASA: --scenario=humahuaca abre el nivel directo y sale con 0 (0 min 04 s) | TR-155 |
| `qa_humahuaca` | PASA: --qa=humahuaca salió con 0, escribió qa_report.json y 16 capturas (mínimo 8), 0 min 10 s | TR-156 |
| `ui_qa_1280x720` | PASA: 254 comprobaciones, 0 fallas, captura 1280x720 real, 0 min 27 s | TR-183 |
| `ui_qa_1920x1080` | PASA: 254 comprobaciones, 0 fallas, captura 1920x1080 real, 0 min 35 s | TR-183 |
| `ui_qa_2560x1440` | PASA: 254 comprobaciones, 0 fallas, captura 2560x1440 real, 0 min 46 s | TR-183 |
| `justina_playthrough` | PASA: 18 victorias, 6 estilos, 3 rutas, 6 derrotas, el bot de interfaz gana (5 min 58 s) | TR-185 |
| `benchmark` | **OMITIDO por orden**: pedido en SKIP; la compuerta queda PARCIAL | TR-157 y TR-184, sin verificar |
| `ui_qa_hx_1280x720` | PASA: 136 comprobaciones, 0 fallas (piso 60) | TR-119 |
| `ui_qa_hx_1920x1080` | PASA: 54 comprobaciones, 0 fallas (piso 1) | TR-119 |
| `ui_qa_hx_2560x1440` | PASA: 54 comprobaciones, 0 fallas (piso 1) | TR-119 |
| `humahuaca_playthrough` | PASA: sale con 0: el experto gana y el pasivo pierde | TR-172 |
| `hx_qa_tour` | PASA: 23 capturas, 7 vistas, cuadro inicial con los tres objetivos y la partida, templo 7.3 m, cuadro medio 1.16 ms (indicativo), el bot victory; texto del bot: jerga 0, desbordes 0, brecha sin siguiente paso 153.0 s (ataque 17.0 s), contracciones sin hacer 0 (informativo); posiciones en píxeles de la captura (x0.8) | TR-173, TR-196, TR-202 y TR-203 |
| `hx_agent_play` | PASA: arnés hx_agente_v1: 30 turnos con capturas de 1280x720, primera orden aceptada en el turno 4 (3.0 s de juego), cierre max_turnos (selftest, no es el agente) | TR-173 y TR-197 |
| `hx_agent_protocolo` | PASA: el arnés atendió un agente de guion por archivos: 8 turnos, 9 comprobaciones sin fallas (acción a medias, JSON roto, clic fuera de la ventana, tipo desconocido, respuestas.json y bitácora), 15.6 s | TR-199 y TR-200 |
| `hx_agent_viejos` | PASA: con una acción, unas respuestas y una captura viejas en la carpeta: las borró (3), no tocó la bitácora y abandonó a los 4 s sin contestar con lo viejo | TR-201 |
| `vis_flow` | PASA: escena real por tools/vis_humahuaca.sh --flow: 0 fallas (fichas, alba y anillos) | TR-198 |
| `salida_limpia` | PASA: ningún SCRIPT ERROR, SHADER ERROR, Parse Error, ERROR: ni fuga en los registros (0 WARNING contados) | TR-193 |

La línea final de la corrida: `GATE full (r1): FALLA (1 pasos) | protegidos 40 | rules 871/0 | integracion 283/0 | jev 15/0 | audio 17/1 | hx_data 420/0 | hx_smoke 158/0 | hx_terrain 158/0 | hx_rules 679/0 | hx_view 258/0 | hx_flow 213/0 | ui_qa_1280x720 254/0 | ui_qa_1920x1080 254/0 | ui_qa_2560x1440 254/0 | falla: higiene | 17 min 44 s`. El único paso que falla es `higiene` (H-R1-3, B-017) y el que no corrió es `benchmark` (orden del encargo), así que la compuerta no puede decir PASA. Frente a la completa de R1 (`c193166`): `hx_data` 419 → 420, `hx_smoke` 155 → 158 (`_test_camera_owner`), `hx_rules` 621 → 679, `hx_flow` 166 → 213 y `ui_qa_humahuaca` a 1280 × 720 104 → 136 y 31 → 54 en las otras dos resoluciones; el recorrido de QA baja de 5,07–6,29 ms a 1,16 ms de cuadro medio indicativo (hook-10) y V10 ya no necesita sus cinco excepciones fechadas.

**Por la escena real** (criterio de cierre de R1: «el experto gana y el pasivo pierde por la escena real»), con ventana a 1280 × 720 sobre `10d9ae0` (`tools/humahuaca_playthrough.gd --level=scene --policies=experto,pasivo,interfaz --seeds=3,5,7`, 39 s): el experto gana 3 de 3 (mediana de 551 s), la política `interfaz` —que hace clic en el botón del «siguiente paso»— gana 3 de 3 (mediana de 496 s) y el pasivo pierde 0 de 3, los tres por `amanecio` a los 390 s; 0 excepciones y salida 0. Es lo mismo que en R1: el pase 2 no movió el balance.

**Otras corridas con ventana después de la compuerta** (el nivel con el código final): `ui_qa_humahuaca.gd --full` a 1024 × 640 y a 1920 × 1080, 135/0 las dos (el arreo queda a 7,5 % y a 6,7 % del borde y las fichas miden de 49,2 a 70,8 px por proyección: BACKLOG B-015 y la parte de `ui_qa_humahuaca` de B-026); `hx_qa_tour.gd` a 1920 × 1080 sin fallas, con un cuadro medio indicativo de 1,56 ms (p95 2,1; construcción de 1 141 ms). Ningún registro de estas corridas tiene `SCRIPT ERROR`, `SHADER ERROR` ni `Parse Error`.

**Qué cambió desde `f54ddc0`.**

- `reglas_historia` (`e0ce410`): H-R1-5 y H-R1-6 (una parada fuera del mapa se rechaza con motivo en la orden y en la vista previa; `save_game` no escribe lo que `F9` no puede abrir; esquema estricto del estado guardado con las 229 claves del estado; el progreso y los puntos de control dañados se descartan sin reventar), B-025 y B-036. `test_hx_rules` pasa de 621 a 679 comprobaciones.
- `ui_feel` (`651476f`): H-R1-2 (el parte nunca queda sin salida: el Diario y la ayuda vuelven adonde estabas), H-R1-7 (el HUD de abajo es una sola columna donde nada se pisa), el cuadro inicial con el arreo a 6,7 a 7,5 % del borde, el objetivo del briefing con una sola fuente y la alerta más angosta en ventanas chicas. `test_hx_flow` pasa de 166 a 213 comprobaciones y `ui_qa_humahuaca` de 104 a 136 a 1280 × 720.
- Integrador (`a219ff5` y `10d9ae0`): H-R1-4, B-045, V10 y V11 sin excepciones y **hook-10** (H-R1-1).

**Capturas reales** (todas con ventana, nunca `--headless`; se miraron **una por una** con `Read`), en `evidence/humahuaca/r1/integrador/cierre_r1_p2/` (13 JPEG de 300 KB o menos, con `indice_capturas.json`, `metrics_integrador_r1p2.json` y los registros chicos en `registros/`) y la cámara inicial en `evidence/humahuaca/r1/inicial_caja_gris.jpg` (con su versión de albedo sin interfaz). Lo que se ve:

1. El menú de tres botones en orden I, II y III: Humahuaca habilitado con «Recomendado tras la Justina · El golpe de Arias, 1817», el Norte apagado con «Ganá la Justina para abrirlo» y «Continuar» apagado.
2. El briefing de una página: «Esta noche, con lluvia, tenés unas 150 personas casi sin armas y un amanecer por delante…», «Perder no es grave» y «Empezar».
3. El primer cuadro en pausa (también `inicial_caja_gris.jpg`): las cinco fichas numeradas con su anillo, los tres objetivos encendidos con su rótulo, un solo «Siguiente paso» con su botón, el reloj «Falta el alba: 4:30», el minimapa con escala y brújula y un panel de abajo de una sola columna.
4. La aproximación bajo lluvia: una alerta con «Dar la señal», una nota de pie, la barra de órdenes con el estado de la señal y el panel de abajo, apilados y sin pisarse.
5. El ataque a los 20 s: las tres tarjetas de frente con su estado y la sorpresa, «Torre: próxima descarga en 7 s», «Golpe 0 de 100» y las fichas atacando.
6. La extracción de día: los tres frentes tomados, «Carga 2200 de 2200 kg», «Refuerzo: entre 1:30 y 4:00» y «Salir por el este [V]».
7. El parte de derrota por `amanecio`: causa con momento (6:30) y lugar, consejo, tres datos y seis botones con «Reintentar» como el principal, sin scroll.
8. El parte de victoria: medalla de bronce con su motivo, el epílogo fechado con sus etiquetas (● ◇ ▲), el contraste «en la realidad / en tu partida» con las piezas de la partida, el tiempo comprimido y «Ver la campaña completa: Sostener el norte».
9. El parte tras abrir y cerrar el Diario (H-R1-2): vuelve el mismo parte con sus botones.
10. `juego_alba`, la misma cámara al alba: más cálida, los tres objetivos y las fichas se distinguen del suelo.
11. La hoja de las cinco fichas: cinco siluetas distintas sobre fondo liso.
12. y 13. El primer cuadro y el ataque a 1024 × 640 (el mínimo del proyecto): el arreo entero dentro del cuadro y el panel de abajo sin tocar el minimapa.

Defectos vistos que **no son de la zona del integrador** y vuelven como hallazgos de su pista: el objetivo del HUD no cambia con la fase (en la extracción repite «Tomá la batería…», ya tomada, y se corta con «…»; B-048, `reglas_historia` y `ui_feel`); en el ataque las fichas 3, 4 y 5 se pisan sobre la posta y la silueta de la ficha 4 se lee como un bloque blanco con un sombrero (B-049, `visual`); el aviso de carga fallida sale con punto doble (B-046, `ui_feel`). Ninguno bloquea.

**Límites honestos de este pase.**

- **El benchmark oficial no se corrió** (orden del encargo: lo corre el Jefe de QA a solas, sin otras ventanas). Las cifras de cuadro de arriba son un diagnóstico del integrador con otra herramienta y las del recorrido de QA (indicativas, sin sincronía vertical), no la medida oficial; H-R1-1 se cierra cuando el Jefe de QA repita su comando (`benchmark.py … --scenarios humahuaca --profiles baja,media,alta --repeat 3`) y dé `media` en 4,0 ms o menos (peor de 3), p95 en 8,3 ms o menos y construcción en 1 500 ms o menos. La Justina y el Norte no cambian (hook-10 solo actúa con `mode == "hx"`).
- **`relieve_mapa` y `visual` no entregaron** en el pase 2 (sin resultado): sus clases de R1 siguen sin cambios y el CONTRATO 7 lo anota como P0 de cada una para la ronda siguiente.
- **No hubo una corrida del agente-jugador de verdad** (B-027): hace falta un subagente nuevo sin acceso al código; el arnés se probó con `--selftest`, con el agente de guion y con archivos viejos. Nadie jugó a mano (A-03): el veredicto máximo sigue siendo «PRESENTABLE, no certificado por humanos».
- **El render héroe** (VP-14) sigue sin la respuesta del QA, y la fuente del relieve sigue siendo la lámina 03 (C1, B-028).
- **Las etiquetas ajenas** `v0.2.0-alpha` y `v0.3.0-alpha` siguen (H-R1-3, B-017): `higiene` falla en toda compuerta y E05 no puede dar verde. Cada una apunta a un commit cuyo `VERSION.json` declara esa misma versión: lo decide el usuario.
- La prueba de interfaz de la Justina (`ui_qa`) no tolera que alguien mueva el mouse sobre la ventana mientras corre (B-044): estas corridas se hicieron con el puntero quieto.

### R1 pase 2 · compuerta completa de compuertas y documentos (2 de noviembre de 2026)

Lo que corrió de verdad después del cierre del integrador del pase 2 (`4d7164b`), escrito por «compuertas y documentos». Commits: `0758465` (las herramientas: las vistas en acción del recorrido, `fin.json` del arnés, la partida del `--selftest` repetida por archivos y la escena real en la compuerta; TR-207 a TR-219) y el de este registro. Sin `push`, sin etiquetas nuevas, `origin/main` en `72077c8`.

**Cómo se corrió.** Dos compuertas completas con `KEEP=1 SKIP=benchmark bash tools/qa_gate.sh full`, ronda `r1`, `APPDATA` aislado propio de cada corrida, ventana real (sin `--headless`) para `ui_qa`, `--qa=humahuaca`, `justina_playthrough`, `ui_qa_humahuaca`, la escena real, el recorrido, el arnés y `vis_flow`, `--audio-driver Dummy`, Godot 4.7.2 con Forward+ en una NVIDIA GeForce RTX 3080 Ti, con el árbol limpio y sin que compuertas y documentos hiciera nada más con ventana ni tocara el mouse mientras corrían (las corridas sueltas del recorrido, de la escena y del arnés se hicieron antes y una a la vez):

- sobre `4d7164b` (el cierre del integrador, sin tocar nada): **16 min 31 s**; `FALLA (1 pasos)` y el único paso que falla es `higiene`. Da las mismas cifras que la del integrador sobre `10d9ae0` (lo que cambió entre una y otra son documentos);
- sobre `0758465` (el código de esta pasada): **17 min 40 s**; `FALLA (1 pasos)` y el único paso que falla es `higiene` (las dos etiquetas ajenas, B-017). **Es la corrida que vale**: la tabla de abajo es de ella.

El benchmark **no se corrió** (orden del encargo: lo corre el Jefe de QA a solas), así que la compuerta no puede decir PASA aunque las etiquetas se resolvieran.

| Paso de la compuerta | Resultado real | Filas que ejercita |
|---|---|---|
| `import` | PASA: 0 min 02 s | ninguna |
| `protegidos` | PASA: 40 archivos protegidos intactos contra 5ebbd28 | TR-186 |
| `compartidos` | PASA: main.gd +48/-4, test_integration +2/-1, ui_qa +3/-1, run_qa +1/-1 (topes de la rúbrica T01) | TR-151 |
| `rules` | PASA: 871 comprobaciones, 0 fallas, piso 871, 3 min 41 s | TR-180 |
| `integracion` | PASA: 283/0, 0 min 11 s | TR-181 |
| `hx_data` | PASA: 420/0, 0 min 02 s; V20 lee 154 filas (136 activas, 6 adelantadas y 12 pendientes de rondas futuras) | TR-001 a TR-003, TR-130, TR-160 a TR-162, TR-171, TR-194, TR-195 y TR-204 |
| `hx_smoke` | PASA: 158/0, 0 min 29 s | TR-010, TR-067, TR-082, TR-110 a TR-112, TR-131, TR-132, TR-140 a TR-148, TR-150, TR-152, TR-175, TR-176, TR-191, TR-205 y TR-206 |
| `hx_terrain` | PASA: 158/0, 0 min 01 s, 2 pendientes de `r2a` (TR-021 y TR-022) | TR-011 a TR-020 |
| `hx_rules` | PASA: 679/0, 1 min 53 s, 1 pendiente de `r2b` | TR-031 a TR-072 y TR-209 a TR-215 |
| `hx_view` | PASA: 258/0, 0 min 07 s | TR-091 a TR-105 |
| `hx_flow` | PASA: 213/0, 0 min 37 s | TR-113 a TR-118, TR-207 y TR-208 |
| `etapa` | PASA: entregables de R1.0 presentes (4 stubs y el controlador) | CONTRATO 8.1 |
| `higiene` | **FALLA**: etiquetas={v0.1.0 v0.2.0-alpha v0.3.0-alpha} (debe quedar solo v0.1.0); `origin/main` sigue en `72077c8` | TR-192 |
| `jev` y `audio` | PASA: Jev 15/0; audio 17 comprobaciones y 1 falla aceptada (driver de audio real, no Dummy) | TR-182 |
| `scenario` | PASA: `--scenario=humahuaca` abre el nivel directo y sale con 0 (0 min 04 s) | TR-155 |
| `qa_humahuaca` | PASA: `--qa=humahuaca` salió con 0 y escribió `qa_report.json` y 16 capturas, 0 min 09 s | TR-156 |
| `ui_qa` ×3 | PASA: 254/0 a 1280 × 720 (25 s), 1920 × 1080 (34 s) y 2560 × 1440 (43 s), con la captura real del tamaño pedido | TR-183 |
| `justina_playthrough` | PASA: 18 victorias, 6 estilos, 3 rutas, 6 derrotas y el bot de interfaz gana, 5 min 22 s | TR-185 |
| `benchmark` | **OMITIDO por orden**: pedido en SKIP; la compuerta queda PARCIAL | TR-157 y TR-184, sin verificar |
| `ui_qa_humahuaca` | PASA: 136/0 a 1280 × 720 (piso 60) y desborde 54/0 a 1920 × 1080 y a 2560 × 1440 | TR-119 |
| `humahuaca_playthrough` | PASA: por reglas, sale con 0: en las 8 semillas de calibración el experto gana 8 de 8 (551 s de mediana) y el pasivo pierde 8 de 8 por `amanecio` (390 s) | TR-172 |
| `humahuaca_escena` (nuevo) | PASA: por la escena real con ventana, semillas 3, 5 y 7: el experto gana 3 de 3 (551,25 s), el pasivo pierde 3 de 3 por `amanecio` (390 s) y el bot de interfaz gana 3 de 3 (495,8 a 496,8 s), 0 excepciones, 0 min 36 s | TR-116 y TR-218 |
| `hx_qa_tour` | PASA: 28 capturas, 7 vistas, cuadro inicial con los tres objetivos y la partida, templo 7,3 m, cuadro medio 1,55 ms (indicativo) y 1,67 ms en pleno ataque, el bot gana (496,8 s, bronce, 21 órdenes), 2 de 2 vistas en acción; texto del bot: jerga 0, desbordes 0, brecha sin siguiente paso 153 s (ataque 17 s), contracciones sin hacer 0 | TR-173, TR-196, TR-202, TR-203 y TR-216 |
| `hx_agent_play` | PASA: arnés `hx_agente_v1`, 30 turnos con capturas de 1280 × 720, primera orden aceptada en el turno 4 a los 3,0 s de juego, cierre `max_turnos` (`--selftest`, no es el agente) | TR-173 y TR-197 |
| `hx_agent_partida` (nuevo) | PASA: las 30 acciones del `--selftest` repetidas por archivos dan la misma partida turno a turno (acción, aplicada, orden aceptada, modo, diálogo, fase, tiempo de juego antes y después, primera orden e intentos: derrota `frente_roto` a los 234,8 s), 3 comprobaciones, 30,8 s | TR-217 |
| `hx_agent_protocolo` | PASA: un agente de guion por archivos, 8 turnos y 9 comprobaciones sin fallas (acción a medias, JSON roto, clic fuera de la ventana, tipo desconocido, `respuestas.json` y bitácora), 15,5 s | TR-199 y TR-200 |
| `hx_agent_viejos` | PASA: con una acción, unas respuestas y una captura viejas en la carpeta: las borró (3), no tocó la bitácora, abandonó a los 4 s y dejó `fin.json` con `abandono` | TR-201 y TR-219 |
| `vis_flow` | PASA: `tools/vis_humahuaca.sh --flow` con 0 fallas (fichas, alba y anillos) | TR-198 |
| `salida_limpia` | PASA: ningún `SCRIPT ERROR`, `SHADER ERROR`, `Parse Error`, `ERROR:` ni fuga en los registros (0 `WARNING` contados) | TR-193 |

La línea final de la corrida que vale: `GATE full (r1): FALLA (1 pasos) | protegidos 40 | rules 871/0 | integracion 283/0 | jev 15/0 | audio 17/1 | hx_data 420/0 | hx_smoke 158/0 | hx_terrain 158/0 | hx_rules 679/0 | hx_view 258/0 | hx_flow 213/0 | ui_qa_1280x720 254/0 | ui_qa_1920x1080 254/0 | ui_qa_2560x1440 254/0 | falla: higiene | 17 min 40 s`.

**Qué cambió desde `4d7164b`** (todo en archivos de compuertas y documentos; ningún archivo de otra pista ni del integrador se tocó):

- `tools/hx_qa_tour.gd`: durante el arco del bot saca dos vistas más con el juego en el momento que el QA pide (B-041, M04 y M05), con interfaz y sin ella, como `accion_*.png` (no entran en los comodines `vista_*` de las herramientas del QA): `grupos_en_accion` cuando la torre dispara y hay tres agrupaciones a 100 m o menos del cuartel (o ya lleva 90 s de fuego) y `patio_posta` en el primer paso de la extracción (el chip de carga solo se muestra en esa fase y el arreo todavía está en el patio). Si el encuadre canónico no reúne las tres fichas que pide M05, abre la distancia de a 20 % hasta que entren y saca también esa (sin interfaz). `qa_report.json` suma `en_accion` y `frame_ms_ataque` (el cuadro medio en pleno ataque con la interfaz); la compuerta exige las dos vistas y 27 capturas como mínimo.
- `tools/hx_agent_play.gd`: deja `fin.json` con el cierre (`respuestas`, `max_turnos`, `abandono`, `sin_captura` o `sin_controlador`) y borra el de una corrida anterior; un agente que espera el turno siguiente se entera de que la corrida terminó.
- `tools/hx_agent_guion.py`: `--guion repetir:<arnes.json>` repite por archivos las acciones de un `--selftest` y `comparar()` ve cualquier diferencia de la partida (probado con copias alteradas: un tiempo de juego, una orden aceptada, un turno menos y otro desenlace).
- `tools/qa_gate.sh`: pasos nuevos `hx_agent_partida` y `humahuaca_escena` (el criterio de cierre de R1 pasa a ser automático: antes lo corría el integrador a mano), `fin.json` en `hx_agent_viejos` y las vistas en acción en `hx_qa_tour`.
- `docs/humahuaca/TRAZA.md`: TR-207 a TR-219 (las pruebas que las pistas escribieron en el pase 2 y las herramientas nuevas) y la tabla sin el renglón vacío que la partía.

**Capturas reales** (todas con ventana, nunca `--headless`; se miraron **una por una** con `Read`), en `evidence/humahuaca/r1/compuertas/cierre_r1_p2/` (14 JPEG de 300 KB o menos con `metrics_compuertas_r1p2.json`, que dice de qué prueba es cada una y trae el SHA-256 del original) y la cámara inicial en caja gris en `evidence/humahuaca/r1/inicial_caja_gris.jpg` (con su versión de albedo sin interfaz). Del resto del recorrido (16 capturas) se miró una hoja de contacto. Lo que se ve:

1. El cuadro inicial en caja gris con la interfaz de R1 (también `inicial_caja_gris.jpg`): las cinco fichas con su número y su anillo, las tres luces con su rótulo, un solo «Siguiente paso» con su botón «Reconocer [R]», «Falta el alba: 4:30», las tres tarjetas de frente con «Guardia ?» y el minimapa con escala y brújula.
2. y 3. `juego_noche` y `juego_alba`: la cámara de juego de noche con lluvia (fichas y luces legibles sobre un suelo oscuro) y al alba (luz cálida, suelo claro); las fichas se distinguen del suelo en las dos.
4. y 5. Sin interfaz: la llegada nocturna por el sudoeste (el pueblo a lo lejos, las tres luces y el río al fondo) y el pueblo desde la batería (una losa con parapeto y piezas bajas en primer plano, el caserío hacia el este y los cerros al fondo).
6. `patio_posta` en el primer paso de la extracción: «Mañana · Extracción», el patio con tapias, cañones, barriles y carros, el arreo con su anillo dorado y, en el dock, «Golpe 0 de 100», «Carga 2200 de 2200 kg» y «Refuerzo: entre 1:30 y 4:00».
7. y 8. `grupos_en_accion` con la torre disparando (a 324 s: fogonazo y humo en el cuartel, la torre con su anillo de recarga, «Asaltado · Toma 61 % · Apoyo de Arias»): con el encuadre canónico de 90 m no entra **ninguna** ficha (las tres agrupaciones disparan desde 82 a 100 m); la versión ampliada a 156 m las reúne en los bordes (B-053).
9. El panorama alto sin interfaz: el caserío, el río como una banda gris que cruza la llanura y la batería en primer plano; sin cielo en el cuadro (B-033).
10. El cuadro inicial en render de albedo, sin interfaz ni luz.
11. La hoja de las cinco fichas sobre fondo liso: cinco siluetas distintas (71 a 96 px); la 4 (reconocedores) sigue siendo la más ambigua (B-049).
12. El límite norte: sin huecos ni borde del mundo, y la cinta de agua del río que termina en punta (B-029).
13. y 14. Lo que ve el agente: el turno 4 del `--selftest` (el primer cuadro jugable, con «Empieza la noche de Humahuaca.») y el turno 30 de la partida repetida por archivos (el ataque a los 233 s: «Esperá la toma del cuartel.», con la contracción arreglada de B-036; las fichas 2, 3 y 4 apiladas sobre la batería, B-049).

**Lo que vieron las herramientas y se manda al backlog** (B-053 y B-054): el encuadre canónico de `grupos_en_accion` no reúne fichas (M05); el chip de carga no se ve mientras el arreo carga en el patio (M04, apartado c); el cuadro medio en pleno ataque del recorrido da de 1,67 a 2,76 ms (cinco corridas, p95 de 3,7 a 6,2 ms) contra 0,96 a 1,55 ms con el cuadro inicial quieto. El aviso «¡Fuego! La descarga que pareció cañonazo lanza el ataque.» sigue en pantalla en las capturas del ataque y de la extracción: los avisos corren en tiempo real y el recorrido salta el tiempo de juego, así que es un efecto de la herramienta y no se anota como defecto.

**Ensayo del arnés con un agente de verdad.** No lo hizo compuertas y documentos (quien escribió el arnés no puede ser el agente, B-027). Sí existe una corrida de un agente sin acceso al código hecha por el revisor de usabilidad del QA sobre `224140f` (`evidence/humahuaca/r1/rev/usabilidad/agente/`): el `arnes.json` guardado trae 60 turnos, la primera orden aceptada en el turno 3 a los 3,0 s, los tres frentes nombrados en la bitácora a 2 turnos del primer cuadro con mapa, dos derrotas por `interceptados` a los 434 s y un tercer intento sin terminar, y el agente respondió las cuatro preguntas con los tres conceptos del objetivo. El arnés funcionó con un agente de verdad; el informe del QA cita otras cifras de esa corrida (74 turnos y tres derrotas en 131) que no están en el archivo guardado y no se pudieron reconciliar. Detalle en `PLAYTEST.md`.

**No se verificó en esta pasada** (y por qué): el benchmark (omitido por orden); la corrida del agente-jugador del Jefe de QA (J08, B-027); nadie jugó a mano (A-03: el veredicto máximo sigue siendo «PRESENTABLE, no certificado por humanos»); H-R1-1 queda a la espera del benchmark oficial (el recorrido solo da cifras indicativas, sin sincronía vertical y con la máquina compartida); la tesela Copernicus como fuente del relieve (R05 se sigue midiendo contra la lámina, B-028); `--qa=humahuaca` sigue escribiendo solo el subconjunto de R1 del paquete (B-032, parte b); el recorrido de QA corre a 1280 × 720 en la compuerta (a mano corrió también a 1920 × 1080, con 1,61 ms de cuadro medio con el cuadro inicial quieto y 2,10 ms en pleno ataque, y a 2560 × 1440, con 2,58 y 3,24 ms, las dos sin fallas, con las mismas vistas en acción y 31 archivos; no es el benchmark, que mide a 1440 × 900).

**Evidencia.** `evidence/humahuaca/` pesa 57,6 MB (`du -sm` da 58; tope 60 al cierre, E04): para no pasarse, las 14 capturas del pase anterior (`compuertas/cierre_r1/`) y la evidencia de compuertas de R1.0 (`compuertas/pase1/` y los archivos sueltos de `_r1p2`) se **movieron**, sin borrar nada, a `respaldos/evidencia_humahuaca_r1_compuertas_cierre_r1/` y `respaldos/evidencia_humahuaca_r1_compuertas_r1.0/`, fuera del repositorio (como lo pide el CONTRATO 6.5 para lo que no es de `r4`). Las rutas bajo `evidence/humahuaca/r1/compuertas/` que nombran las secciones anteriores de este registro hablan de esos archivos.

### R1 pase 3 · las ramas de `visual` y `ui_feel` y la compuerta completa (2 de noviembre de 2026)

Lo que corrió de verdad al cerrar el pase 3 de R1, escrito por el integrador (que lleva también la propiedad de «compuertas y documentos»). Commits sobre `3c82ade`: los merges `ba45bef` (visual) y `8c97b4e` (ui) y los de este registro (TR-220 a TR-231, BACKLOG, ADDENDA A-15 y PLAYTEST). Sin `push`, sin etiquetas nuevas, `origin/main` en `72077c8`.

**Compuerta rápida de cada pista sobre su rama** (ronda vigente `r1`; las dos con `higiene` en FALLA por las etiquetas ajenas `v0.2.0-alpha` y `v0.3.0-alpha`, que fallan igual en `main`, B-017):

| Pista | Rama | Resultado | Tiempo |
|---|---|---|---|
| `relieve_mapa` | sin rama (sin resultado en el pase 3) | no entra nada; sigue su clase real de R1 | — |
| `reglas_historia` | sin rama (sin resultado en el pase 3) | no entra nada; sigue su entrega de R1 | — |
| `visual` | `hx-visual-r1-p3` (ya estaba sobre el `main` vigente, sin rebase) | protegidos 40, `test_rules` rápido 818/0, `test_integration` 283/0, `hx_data` 420/0, `hx_smoke` 158/0, `hx_view` 284/0, salida limpia; falla solo `higiene` | 1 min 58 s |
| `ui_feel` | `hx-ui-r1-p3`, rebaseada sobre el merge de `visual` (los siete commits cambian de hash) | protegidos 40, `test_rules` rápido 818/0, `test_integration` 283/0, `hx_data` 420/0, `hx_smoke` 158/0, `hx_flow` 285/0, salida limpia; falla solo `higiene` | 2 min 19 s |

**Compuerta completa de cierre.** `KEEP=1 SKIP=benchmark bash tools/qa_gate.sh full`, ronda `r1`, `APPDATA` aislado propio de la corrida, ventana real (sin `--headless`) para `ui_qa`, `--qa=humahuaca`, `justina_playthrough`, `ui_qa_humahuaca`, la escena real, el recorrido, el arnés y `vis_flow`, `--audio-driver Dummy`, Godot 4.7.2 con Forward+ en una NVIDIA GeForce RTX 3080 Ti, sobre `8c97b4e` con el árbol limpio y sin tocar el mouse ni abrir otra ventana mientras corría. Duró **19 min 13 s**. El único paso que falla es `higiene` y el que no corrió es `benchmark` (orden del encargo: lo corre el Jefe de QA a solas), así que la compuerta no puede decir PASA.

| Paso de la compuerta | Resultado real | Filas que ejercita |
|---|---|---|
| `import` | PASA: proyecto importado en 0 min 04 s | ninguna |
| `protegidos` | PASA: 40 archivos protegidos intactos contra 5ebbd28 | TR-186 |
| `compartidos` | PASA: main.gd +48/-4, test_integration +2/-1, ui_qa +3/-1, run_qa +1/-1 (topes de la rúbrica T01) | TR-151 |
| `rules` | PASA: 871 comprobaciones, 0 fallas, piso 871, 3 min 59 s | TR-180 |
| `integracion` | PASA: 283 comprobaciones, 0 fallas, piso 283, 0 min 15 s | TR-181 |
| `hx_data` | PASA: 420 comprobaciones, 0 fallas, piso 40, 0 min 03 s | TR-001 a TR-003, TR-130, TR-160 a TR-162, TR-171, TR-194, TR-195 y TR-204 |
| `hx_smoke` | PASA: 158 comprobaciones, 0 fallas, piso 25, 0 min 30 s | TR-010, TR-067, TR-082, TR-110 a TR-112, TR-131, TR-132, TR-140 a TR-148, TR-150, TR-152, TR-175, TR-176, TR-191, TR-205 y TR-206 |
| `hx_terrain` | PASA: 158 comprobaciones, 0 fallas, piso 60, 0 min 01 s, 2 pendientes de rondas futuras | TR-011 a TR-020 |
| `hx_rules` | PASA: 679 comprobaciones, 0 fallas, piso 150, 1 min 57 s, 1 pendientes de rondas futuras | TR-031 a TR-072 y TR-209 a TR-215 |
| `hx_view` | PASA: 284 comprobaciones, 0 fallas, piso 25, 0 min 10 s | TR-091 a TR-105, TR-220, TR-222 y TR-223 |
| `hx_flow` | PASA: 285 comprobaciones, 0 fallas, piso 50, 0 min 30 s | TR-113 a TR-118, TR-207, TR-208 y TR-224 a TR-231 |
| `etapa` | PASA: entregables de R1.0 presentes (4 stubs y el controlador) | CONTRATO 8.1 |
| `higiene` | **FALLA**: etiquetas={v0.1.0 v0.2.0-alpha v0.3.0-alpha} (debe quedar solo v0.1.0) | TR-192 |
| `jev` | PASA: 15 comprobaciones, 0 fallas, piso 15, 0 min 01 s | TR-182 |
| `audio` | PASA: 17 comprobaciones y 1 falla aceptada (driver de audio real, no Dummy), 0 min 06 s | TR-182 |
| `scenario` | PASA: --scenario=humahuaca abre el nivel directo y sale con 0 (0 min 04 s) | TR-155 |
| `qa_humahuaca` | PASA: --qa=humahuaca salió con 0, escribió qa_report.json y 16 capturas (mínimo 8), 0 min 10 s | TR-156 |
| `ui_qa_1280x720` | PASA: 254 comprobaciones, 0 fallas, captura 1280x720 real, 0 min 27 s | TR-183 |
| `ui_qa_1920x1080` | PASA: 254 comprobaciones, 0 fallas, captura 1920x1080 real, 0 min 36 s | TR-183 |
| `ui_qa_2560x1440` | PASA: 254 comprobaciones, 0 fallas, captura 2560x1440 real, 0 min 46 s | TR-183 |
| `justina_playthrough` | PASA: 18 victorias, 6 estilos, 3 rutas, 6 derrotas, el bot de interfaz gana (6 min 11 s) | TR-185 |
| `benchmark` | **OMITIDO por orden**: pedido en SKIP; la compuerta queda PARCIAL | TR-157 y TR-184, sin verificar |
| `ui_qa_hx_1280x720` | PASA: 165 comprobaciones, 0 fallas (piso 60) | TR-119 y TR-224 |
| `ui_qa_hx_1920x1080` | PASA: 73 comprobaciones, 0 fallas (piso 1) | TR-119 |
| `ui_qa_hx_2560x1440` | PASA: 73 comprobaciones, 0 fallas (piso 1) | TR-119 |
| `humahuaca_playthrough` | PASA: sale con 0: el experto gana y el pasivo pierde | TR-172 |
| `humahuaca_escena` | PASA: por la escena real el experto gana 3 de 3, el pasivo pierde 3 de 3 (todos por amanecio) y el bot de interfaz gana 3 de 3, sin excepciones, 0 min 39 s | TR-116 y TR-218 |
| `hx_qa_tour` | PASA: 28 capturas, 7 vistas, cuadro inicial con los tres objetivos y la partida, templo 7.3 m, cuadro medio 1.26 ms (indicativo) y 1.84 ms en pleno ataque, el bot victory, vistas en acción 2 de 2 (torre disparando y arreo cargando); texto del bot: jerga 0, desbordes 0, brecha sin siguiente paso 153.0 s (ataque 17.0 s), contracciones sin hacer 0 (informativo); posiciones en píxeles de la captura (x0.8) | TR-173, TR-196, TR-202, TR-203 y TR-216 |
| `hx_agent_play` | PASA: arnés hx_agente_v1: 30 turnos con capturas de 1280x720, primera orden aceptada en el turno 4 (3.0 s de juego), cierre max_turnos (selftest, no es el agente) | TR-173 y TR-197 |
| `hx_agent_partida` | PASA: la partida del --selftest repetida por archivos da lo mismo turno a turno: 30 turnos, 3 comprobaciones (acción, aplicada, orden aceptada, modo, diálogo, fase y tiempo de juego, primera orden e intentos), 31.6 s; 0 min 32 s | TR-217 |
| `hx_agent_protocolo` | PASA: el arnés atendió un agente de guion por archivos: 8 turnos, 9 comprobaciones sin fallas (acción a medias, JSON roto, clic fuera de la ventana, tipo desconocido, respuestas.json y bitácora), 15.8 s | TR-199 y TR-200 |
| `hx_agent_viejos` | PASA: con una acción, unas respuestas y una captura viejas en la carpeta: las borró (3), no tocó la bitácora, abandonó a los 4 s sin contestar con lo viejo y dejó fin.json con el cierre (abandono) | TR-201 y TR-219 |
| `vis_flow` | PASA: escena real por tools/vis_humahuaca.sh --flow: 0 fallas (fichas, alba y anillos) | TR-198 y TR-221 |
| `salida_limpia` | PASA: ningún SCRIPT ERROR, SHADER ERROR, Parse Error, ERROR: ni fuga en los registros (0 WARNING contados) | TR-193 |

La línea final de la corrida que vale: `GATE full (r1): FALLA (1 pasos) | protegidos 40 | rules 871/0 | integracion 283/0 | jev 15/0 | audio 17/1 | hx_data 420/0 | hx_smoke 158/0 | hx_terrain 158/0 | hx_rules 679/0 | hx_view 284/0 | hx_flow 285/0 | ui_qa_1280x720 254/0 | ui_qa_1920x1080 254/0 | ui_qa_2560x1440 254/0 | falla: higiene | 19 min 13 s`.

`test_hx_data` lee ahora 166 filas de esta tabla (148 activas, 6 adelantadas y 12 pendientes de rondas futuras; con las 12 filas nuevas de este pase, TR-220 a TR-231, que resuelven a funciones reales), y vuelve a dar 420/0 con los documentos de este pase ya escritos.

**Corridas con ventana después de la compuerta, sobre el mismo código** (una por vez; nadie tocó el mouse):

| Corrida | Resultado | Filas que ejercita |
|---|---|---|
| `ui_qa_humahuaca --full` a 1024 × 640 | 164 comprobaciones y 0 fallas; 0 recortes y 0 solapes de texto en 9 revisiones; ninguna ficha a menos de 7,5 % del borde; 21 s | TR-119, TR-224 |
| `ui_qa_humahuaca --full` a 1920 × 1080 | 164/0; 0 recortes y 0 solapes en 9 revisiones; 25 s | TR-119, TR-224 |
| `ui_qa_humahuaca --full` a 2560 × 1440 | 164/0; 0 recortes y 0 solapes en 9 revisiones; sin ningún clic repetido; 29 s | TR-119, TR-224 |
| Flujo de `main.gd` con ventana real (menú → botón II → Espacio, F3, F2 → Esc → menú → botón I → menú → botón II → Esc) | 24 comprobaciones y 0 fallas; las cuatro capas en `real`; 0 nodos huérfanos nuevos (de 0 a 0); 10 s | TR-206 y los ganchos H1 a H9 |

**Qué cambió desde `3c82ade`** (solo archivos de `visual` y de `ui_feel`; el integrador no tocó código en este pase):

- `visual` (3 commits): las cinco figuras leen su pose en cada cuadro (`units.sync_poses`) y los círculos de visibilidad las siguen (`fx.follow_pools`, a partir de 1,5 m de corrimiento y no más seguido que cada 0,06 s) (H-R1-9); cuatro costuras de una fila de celdas con los nodos exactos del borde de la ventana, y el río, los caminos y las zanjas se apoyan en la malla que se dibuja (`gfx.rendered_h`), con la cinta del río recortada al contexto y apagada en las puntas (H-R1-11); `probes()` mide con el alto dibujado y marca `on_screen`, la escala de las fichas se mide una vez por cámara distinta y las dos cadenas con snake_case de `humahuaca_visual.json` están reescritas (B-026, B-034, B-047 y B-051); `tools/vis_humahuaca.gd --flow` mide la marcha de las cinco agrupaciones por la escena real.
- `ui_feel` (7 commits): el objetivo del HUD se elige por fase (`texts.objective.by_phase`) y las fichas de agrupación y las tarjetas de frente se rehicieron para 1024 × 640 (H-R1-10, B-048); destruir a mano se pregunta, un reintento cuenta un solo intento, el paso con el botón apagado dice la causa y «Golpe», «Desvelo», el triángulo y los puntos se explican (B-052); el chip de carga se ve desde que el arreo empieza a cargar (B-053 b); el aviso de carga fallida sin punto doble y las paradas fuera del mapa que no se suman (B-046); a los 12 s sin ninguna orden un aviso dice cómo arranca el reloj; la vista previa de la ruta alcanza al cursor; y `ui_qa_humahuaca` aprieta y suelta el clic en el mismo cuadro y mide recortes y solapes con la misma cuenta que la sonda del QA (B-044).
- Documentos de las dos pistas: `VISUAL.md`, `CREDITOS_VISUAL.md` y `CONTROLES.md`. Los de compuertas y documentos (`TRAZA.md`, `BACKLOG.md`, `PLAYTEST.md`) y `ADDENDA.md` los actualizó el integrador en este pase.

**Capturas reales** (todas con ventana, nunca `--headless`; se miraron **una por una** con `Read`), en `evidence/humahuaca/r1/integrador/cierre_r1_p3/` (14 JPEG de 300 KB o menos con `indice_capturas.json`, que trae el SHA-256 de cada original y dice de qué prueba es cada una, y `metrics_integrador_r1p3.json`) y la cámara inicial en caja gris en `evidence/humahuaca/r1/inicial_caja_gris.jpg` (con su versión de albedo sin interfaz). Lo que se ve:

1. El menú de tres botones: «I · El río ofrece una oportunidad», «II · Humahuaca: el depósito de la retaguardia» con «Recomendado tras la Justina · El golpe de Arias, 1817» y habilitado, y «III · Sostener el norte» con su candado («Ganá la Justina para abrirlo»).
2. El cuadro inicial en caja gris con la interfaz de R1 (también `inicial_caja_gris.jpg`): las cinco fichas con su número y su anillo, las tres luces con su rótulo, un solo «Siguiente paso» con su botón «Reconocer [R]», «Falta el alba: 4:30», las tres tarjetas de frente con «Guardia ?» y el minimapa con escala y brújula.
3. La aproximación bajo lluvia: el objetivo de la fase («Poné a cada partida en su puesto y dá la señal antes de que aclare.»), un solo aviso arriba y una nota al pie, el estado de cada partida y «Esperá: Portal todavía no llegó a su puesto.»
4. El ataque: «Tomá los tres frentes a la vez y socorré a la partida que más sufra.», «Golpe 0 de 100» y «Torre: próxima descarga en 7 s»; las fichas 3, 4 y 5 se pisan sobre la posta (B-049).
5. La extracción, de día: «Cargá el arreo y salí por el vado antes del refuerzo.» (ya no pide tomar lo tomado) con los chips de golpe, carga y refuerzo enteros; el chip dice «Carga 2200 de 2200 kg» mientras el siguiente paso dice «El arreo está cargando: esperá.» (B-053 b).
6. y 7. Los partes: derrota por «Amaneció y nadie había atacado» (causa con momento, consejo, tres datos y seis botones) y victoria con medalla de bronce, el epílogo con sus etiquetas de fuente y «Ver la campaña completa: Sostener el norte».
8. a 10. A 1024 × 640 (la ventana mínima): el inicio, el ataque y la extracción con el HUD entero, sin textos cortados ni solapes.
11. `grupos_en_accion` con la torre disparando: con el encuadre canónico de 90 m no entra ninguna ficha (B-053 a).
12. y 13. Los límites norte y sur: el río cruza el cuadro de borde a borde en el norte y se apaga en la bruma en el sur; sin huecos ni borde del mundo (B-029 y H-R1-11).
14. La hoja de las cinco fichas: cinco siluetas distintas; la 4 sigue siendo la más ancha y ambigua (B-049).

**Defectos vistos que no son de la zona del integrador** y vuelven como hallazgos de su pista (ADDENDA A-15, punto 6): la ficha 4 mide 160 px de ancho contra 56 a 113 de las otras (B-049, `visual`); el chip de carga y el siguiente paso se contradicen en el primer paso de la extracción (B-053 b, `reglas_historia` con `ui_feel`); `grupos_en_accion` no reúne fichas con el encuadre canónico (B-053 a, `visual`); una línea fina y recta en la costura de la ventana, visible desde los límites oeste y este (B-058, `visual`); y un hueco de hasta 153 s sin un «siguiente paso» que apretar en la aproximación (B-037, `reglas_historia` y `ui_feel`). Ninguno bloquea.

**Límites honestos de este pase.**

- **El benchmark oficial no se corrió** (orden del encargo: lo corre el Jefe de QA a solas). El cuadro medio del recorrido de QA (1,26 ms de media con p95 de 2,0 ms, y 1,84 ms en pleno ataque con p95 de 2,88 ms, a 1280 × 720, sin sincronía vertical, con la máquina compartida con la compuerta) es indicativo, no la medida oficial; las cifras que cita `visual` con el comando del benchmark (1,427 ms de media y 2,25 ms de p95, contra 1,525 y 3,91 ms del `main` anterior) son de la pista y el integrador no las repitió. H-R1-1 se cierra con el benchmark del Jefe de QA y H-R1-8 (T06 de la Justina) sigue abierto (ADDENDA A-15, punto 4).
- **`relieve_mapa` y `reglas_historia` no entregaron** en el pase 3 (sin resultado): sus clases de R1 siguen sin cambios y el CONTRATO 7 lo anota como P0 de cada una para la ronda siguiente (B-057).
- **No hubo una corrida del agente-jugador de verdad** (B-027): el arnés se probó con `--selftest` (30 turnos, primera orden aceptada en el turno 4 a los 3,0 s de juego), con el agente de guion y con archivos viejos, y eso no es un agente. Nadie jugó a mano (A-03): el veredicto máximo sigue siendo «PRESENTABLE, no certificado por humanos».
- **El render héroe** (VP-14) sigue sin la respuesta del QA y la fuente del relieve sigue siendo la lámina 03 (B-028).
- **Las etiquetas ajenas** `v0.2.0-alpha` y `v0.3.0-alpha` siguen (H-R1-3, B-017): `higiene` falla en toda compuerta y E05 no puede dar verde. Lo decide el usuario.
- El recorrido de QA corrió a 1280 × 720 dentro de la compuerta; a 1024 × 640, 1920 × 1080 y 2560 × 1440 corrió `ui_qa_humahuaca --full`. La prueba de interfaz de la Justina (`ui_qa`) no tolera que alguien mueva el mouse sobre la ventana mientras corre (B-044): estas corridas se hicieron con el puntero quieto.
- La evidencia de R1 sigue sin podarse (B-043): `evidence/humahuaca/` pesa 133 MB, por encima del tope de 60 MB que E04 mira al cierre (R3 y R4); no entra a Git (`.gitignore`: solo `r4/`) y la poda de lo ajeno es del cierre.
