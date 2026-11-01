# Trazabilidad contrato → prueba (V20)

Ronda vigente: r0

Cada exigencia de las secciones 3 a 5 de `docs/CONTRATO_HUMAHUACA.md` tiene acá **una fila** con la prueba que la verifica. La prueba que cuenta es una función nombrada que existe: `test_hx_data::_test_v20_traceability` (regla V20 del contrato, 2.4) lee este archivo y falla si una fila apunta a una función que no existe, si el id de una fila se repite o si alguna subsección 3.x, 4.x o 5.x del contrato queda sin ninguna fila. Contar comprobaciones no es progreso: lo que cuenta es esta tabla.

**Cómo se lee.**

- **Ronda vigente** (la línea de arriba) es la ronda en la que está el bucle. La leen `tools/qa_gate.sh` y las pruebas (`--ronda=<id>` la pisa). La cambia el **integrador**, en el commit que abre cada ronda (`r0`, `r1.0`, `r1`, `r2a`, `r2b`, `r3`, `r4`).
- **Prueba** es `archivo::función`. El archivo se escribe sin ruta ni extensión si es `tests/test_hx_*.gd` o `tools/*.gd` (por ejemplo `test_hx_rules`, `humahuaca_playthrough`), `qa_gate` es `tools/qa_gate.sh` y una ruta con extensión vale tal cual. `QA:<ítem>` apunta a un ítem de la rúbrica de `docs/QA_NIVEL2.md` (por ejemplo `QA:T06`) cuando lo mide el procedimiento del QA y no una función del repositorio.
- **Desde** es la ronda a partir de la cual la prueba **tiene que existir**. Antes, la fila figura como pendiente en el informe de `test_hx_data` (sin fallar); si la función ya existe, queda como adelantada. Desde esa ronda, una función inexistente es una falla («no evaluable = falla»).
- Los nombres de función de las pruebas de las pistas (`test_hx_terrain`, `test_hx_rules`, `test_hx_view`, `test_hx_flow`) son **la propuesta de compuertas y documentos**: la pista dueña escribe esas funciones o pide por escrito el cambio de una fila (id, nombre nuevo y motivo). Nadie edita este archivo salvo compuertas y documentos.
- No se usa el carácter de barra vertical dentro de una celda.

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
| TR-060 | 3.2.1 | state trae los campos mínimos y obligatorios, cada uno con su tipo y su rango | test_hx_rules::_test_state_fields | r1 |
| TR-062 | 3.2.2 | Todo evento trae un kind del vocabulario; un kind fuera de EVENT_KINDS es un error de contrato | test_hx_rules::_test_event_kinds | r1 |
| TR-064 | 3.2.3 | hud_state funciona en todas las fases y tiene la forma del ejemplo | test_hx_rules::_test_hud_state_all_phases | r1 |
| TR-065 | 3.2.3 | render_state no muestra lo que el jugador no sabe (guardia y postura no reconocidas) | test_hx_rules::_test_render_state_blindness | r1 |
| TR-066 | 3.2.3 | campaign_report es válido siempre y tiene la forma del ejemplo | test_hx_rules::_test_campaign_report_shape | r1 |
| TR-067 | 3.2.3 | La salida de cada implementación (stub y real) tiene las claves y los tipos de los ejemplos de forma | test_hx_smoke::_test_shapes | r1.0 |
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
