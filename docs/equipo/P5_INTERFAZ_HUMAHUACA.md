# Pista P5 · Interfaz del nivel II «Humahuaca» — informe de la tanda 2

Rama `equipo/p5-interfaz-humahuaca`, desde `equipo/integracion` (`70b2341`). Archivos tocados: `scripts/humahuaca/ui/*` (salvo `humahuaca_camera.gd`), `data/humahuaca_ui.json`, `tests/test_hx_flow.gd`, `tools/ui_qa_humahuaca.gd`, `tools/hx_agent_play.gd` y una línea de `tools/hx_qa_tour.gd` (ver F-1). No se tocó `scripts/humahuaca/{rules,view,terrain}`, `data/humahuaca_{rules,level,map,visual}.json` ni `scripts/main.gd`.

Evidencia (fuera de Git): `../qa-equipo/p5/` — `antes/qa_<tamaño>/` y `despues/qa_<tamaño>/` (capturas y `ui_qa_report.json` de `tools/ui_qa_humahuaca.gd` con ventana real), `hojas/cmp_<pantalla>_<tamaño>.png` (antes a la izquierda, después a la derecha, mismo encuadre: la misma herramienta y el mismo recorrido), `agente_selftest/` (corrida de `hx_agent_play --selftest`).

## 1. Qué cambió

### V-06 · Paleta común, esquinas, viñeta, minimapa nocturno
- `humahuaca_ui_kit.gd` lleva la paleta «Crónica en oro y noche» con los HEX exactos de `arte/DIRECCION_DE_ARTE.md` §2.1 (tinta `#0E0C12`/`#16131C`, filete `#5C4A2E`, oro `#C9A25E`/`#E8CC8A`, violeta `#7A5BB5`/`#3B2A5C`, pergamino `#ECE3CF`/`#A79F92`, rojo realista `#B8433A` solo para el enemigo, ámbar `#D9903A` para avisos, salvia, celeste `#8DB8D6`, hueso `#BFB6A3`). Los nombres viejos (`PANEL_BG`, `ROYAL`, `RED`…) quedan como alias, así que el resto del código no cambió de forma. Esquinas de 2 px, sombra de 10 px, botón principal en oro lleno con letra de tinta, «peligro» con filete ámbar (nunca rojo). Ningún color suelto quedó en `hud`/`dialogs`/`minimap`.
- Cabecera como franja translúcida con filete inferior y el título en Cinzel con espaciado; ficha elegida con filete de oro y halo violeta; avisos críticos en tinta y ámbar (antes rojo).
- Viñeta común (0,32 en juego; 0,55 en pantallas completas): un `ColorRect` con sombreador, debajo de todo el HUD, sin tomar clics (`Kit.vignette`).
- HUD que no tapa el mapa: en ventanas anchas el dock deja de ir de punta a punta y mide a lo sumo `layout.dock_max_w` = 920 px lógicos (esquina inferior izquierda). Medido con la herramienta (nota nueva `hud_tapa_*`): a 1920 × 1080 y 2560 × 1440 el HUD tapa **20,0 %** del cuadro en el primer cuadro jugable (meta de arte ≤ 25 %) y 29,1 % en pleno ataque con aviso; a 1280 × 720, 29,9 % / 45,2 %; a 1024 × 640, 34,9 % / 52,1 %. A 1280 × 720 y menos la geometría del HUD no cambió (la cámara y sus pruebas dependen de `header_h` y `dock_h`): ahí no se llega al 25 %, queda dicho.
- Minimapa nocturno: el relieve que entrega la vista sigue siendo diurno (beige); el minimapa lo pasa por un sombreador que lo lleva a tinta violácea con los trazos claros en oro, y fichas, frentes, cuadro de cámara, brújula y escala van en la paleta. Tres capas (fondo, relieve con sombreador, tinta encima).

### V-06 · Briefing a pantalla completa (modelo 05)
Primera pantalla: arriba a la izquierda «Capítulo II», título «HUMAHUACA, 1817» en Cinzel, «El depósito de la retaguardia» y la situación; debajo, **Objetivo** y **Tus fuerzas** (las cinco agrupaciones con su tecla y su frente, de `map_data().groups`); a la derecha **Enemigo** (los tres frentes con «Guardia ?», de `hud_state`), **Esta noche** (el reloj del alba y la línea del mundo de hoy) y **Cronología** (26 de febrero, carta ▲ diseño; 1 de marzo, el golpe ◆ discutido); abajo la cita **«La mayor parte sin más armas que palos»** con su fuente (parte de Arias del 3-III-1817, ● documentado; S46 en `docs/humahuaca/HISTORIA.md`, la misma que ya usaba la presentación) y **Empezar** en oro. Los textos son los de siempre (fuente única `briefing_data()`); lo nuevo son rótulos de bloque y la cronología de dos líneas, ambas con su etiqueta. Segunda pantalla: la carta como documento (cursiva sintética), la nota de fecha y «Qué es real y qué es diseño». Enter, Espacio y Esc siguen igual.

### D-08 · Partes a pantalla completa
- **Victoria:** «PARTE DE VICTORIA» y el título en oro, la medalla dibujada (oro/plata/bronce), la causa, cuatro cifras grandes (frentes, golpe, bajas, tiempo) y «Qué pasó después» **plegado**: la primera fecha y la que contrasta «En la realidad / En tu partida» (9 al 16 de marzo), más la aclaración del tiempo; «Ver toda la línea de tiempo (8 fechas)» la despliega (con caja desplazable si no entra). Legible sin scroll a 1280 × 720 y 1024 × 640.
- **Botón principal al ganar = «Seguir al capítulo III: Sostener el norte»** (`HxNext`, también Enter). Emite `go_norte` → el controlador hace **`exited.emit("norte")`** → `main.gd::_on_hx_exited("norte")` libera el nivel y llama `_start_game("norte")`. Es la salida que ya existía; el valor para «seguir al III» es la cadena `"norte"` (cualquier otro valor vuelve al menú). El desbloqueo del III al ganar el II lo unifica P4 en el progreso de `main.gd` (decisión del lead, P-007). «Jugar de nuevo» (`HxRetry`) queda al lado.
- **Derrota:** «REPLIEGUE» en pergamino (no en rojo). «Qué pasó»: la causa (que ya trae el momento «A los m:ss» y el lugar; si no trajera el momento, se agrega «A los m:ss de juego»), lo que quedó anotado en el diario; las cuatro cifras; «Para el próximo intento» con el consejo y la pista rotativa; la historia del combate plegada. Botones: Menú, Diario y Mundo nuevo a la izquierda; los reintentos a la derecha, **«Reintentar»** en oro al final (Enter).

### P-008 (playtest de línea de base) y D-11 · Esperas con propósito y ×2
- Cuando el siguiente paso pide esperar (acción «hold»), la interfaz dice **qué se espera y cuánto falta** con datos que ya dan las reglas: metros de ruta que le quedan a la agrupación («faltan 120 m»), la toma del frente («Batería: toma 13 %»), la carga del arreo o el reloj del alba. Y ofrece algo útil sin inventar decisiones: **Mirar** (centra la cámara en lo que se espera), **×2** y **×4**.
- D-11: además, en una marcha sin novedades (×1, sin alerta ni ventana ni decisión, sin una orden pedida, con alguien en marcha y 8 s sin avisos importantes) aparece «Acelerar ×2» y una vez por minuto un aviso de pie. La velocidad nunca cambia sola.
- Pedido a P3 para cerrar P-008 del todo: ver §4.

### Arreglos de la revisión en la nube y tickets
| Prueba / ticket | Causa real | Arreglo |
|---|---|---|
| `e_arrastre_dialogo` (T-006, E-1) | con una ventana abierta el controlador descartaba también la soltada del botón | `end_gestures()`: toda ventana al abrirse y al cerrarse termina el arrastre y la caja; y un evento del mouse con ventana abierta también |
| `e_ctrl_t_sin_seleccion` (E-7) | Ctrl+T salteaba `orders.press` | sin selección, Ctrl+T avisa como T |
| `e_esc_tras_continuar` (E-8) | `order_count` en 0 tras cargar | tras una carga buena cuenta las órdenes del guardado |
| `e_f9_texto_empezas_de_nuevo`, `b_f9_aviso_empezas_de_nuevo` (E-5) | F9 reusaba el texto de «Continuar» y lo dejaba fijo en la línea roja | texto propio («La partida sigue como estaba.»), solo como aviso de pie |
| `e_socorrer_frente_tomado` (E-3) | la disponibilidad de «Socorrer» se probaba contra el punto fijo (450, 325) = el cuartel | se prueba contra cada frente en pie |
| `b_carga_partida_terminada` (B-2) | se aceptaba un guardado de una partida terminada | se rechaza con «esa partida ya había terminado» y, en F9, la partida en curso queda como estaba |
| `b_semilla_tras_cargar` (B-3) | la semilla del controlador no era la del guardado | tras cargar, la semilla es la del guardado; «mismo mundo» la repite; ganar o «Mundo nuevo» re-sortean |
| `b_control_de_otro_mundo` (T-005 mitad interfaz, R-02) y R-01 | el progreso ofrece controles que el archivo ya no tiene o de otro mundo, y al fallar se empezaba de cero en silencio | el parte solo ofrece «posiciones»/«salida» si el archivo lo trae y es de la misma semilla; si igual se pide, se queda en el parte y dice por qué; si las reglas lo rechazan, se avisa el motivo |
| `g_hud_refresco_planifica_rutas` (G-1) | cada refresco del HUD (5 Hz) planificaba hasta 4 rutas | `orders.cached_availability`: memoria por firma de estado (partida, `state_version`, cantidad de órdenes, etapas, decisión pendiente), borrada tras cada orden |
| `g_minimapa_rayos_por_redibujo` (G-2) | el minimapa remuestreaba el relieve y pedía dos `render_state` por redibujo | polígono de cámara y metros por píxel guardados por pose/campo visual/tamaño; un solo `render_state_cached()` |
| `f_hermeticidad_qa` (F-1) | las listas de limpieza no borraban `qa_humahuaca_checkpoint.json` ni `qa_save_humahuaca.json` | agregados en `hx_agent_play.gd`, `hx_qa_tour.gd` (herramienta sin dueño en la tabla de pistas; cambio de una línea) y `ui_qa_humahuaca.gd` |
| T-008 (Ctrl+Z) | `undo_last` de las reglas salta la señal y deshace la orden de otra agrupación, y deja «esperando órdenes» aunque la orden haya anotado otra etapa previa | la interfaz deshace solo la última orden propia y solo si deja a la agrupación como estaba; si no, se niega con motivo («La señal ya se dio…», «Esa orden no se puede deshacer…»). La restauración de `prev` es de P3 (`a_undo_prev`) |
| `b_diario_marca_z_negativa` (B-5) | `humahuaca_progress.gd::_valid_entry` acepta `x ≥ 0` con `z = −1` | **no es de la interfaz**: pedido a P3 (§4) |

Pruebas nuevas en `tests/test_hx_flow.gd`: `reintento_sin_control` (T-005), `deshacer` (T-008), `sugerir_x2` (D-11); y el ciclo comprueba que el botón principal del parte de victoria es «Seguir al capítulo III» y que la línea de tiempo se despliega.

## 2. Cifras

| Prueba | Antes (`70b2341`) | Después |
|---|---|---|
| `test_hx_flow` | 287 comprobaciones, 0 fallas | **303**, 0 fallas (primer cuadro: 3 controles, 343 caracteres; C03 ≤ 5 y ≤ 400) |
| `test_hx_data` | 426, 0 | 426, 0 |
| `test_hx_smoke` | 158, 0 | 158, 0 |
| `revision_nube` b_/e_/f_/g_ de P5 (13) | **0 de 13** pasan | **12 de 13** pasan (falta `b_diario_marca_z_negativa`, causa en P3) |
| `revision_nube` de P4 en esos prefijos (`e_escala_doble_tras_justina`, `f_start_game_con_hx_vivo`) | fallan | siguen fallando (son de `main.gd`) |
| `ui_qa_humahuaca` 1280 × 720 (recorrido completo) | 167, 0 fallas | **172, 0 fallas**; 0 recortes, 0 solapes; contraste mínimo 5,37:1 |
| `ui_qa_humahuaca` 1920 × 1080, 2560 × 1440, 1024 × 640 (desborde) | 74, 1 falla cada uno | 74, 1 falla cada uno — **la misma**: «Primer cuadro: ninguna ficha bajo el HUD y todas a ≥ 5,5 % del borde (mínimo −45,6 %)». Es el encuadre inicial de la cámara (P2, P-006), idéntico antes y después; 0 recortes y 0 solapes en los tres tamaños |
| `hx_agent_play --selftest` (semilla 11) | — | **victoria** a los 621,8 s de juego, 87 turnos, 0 `SCRIPT ERROR` |

Cambios en la herramienta de QA (dueña P5), con su motivo escrito en el código: el chequeo de largo del briefing pasa de < 700 caracteres (tarjeta de 760 px) a < 850 para la pantalla completa, y se suma uno más estricto, ≤ 300, para lo que hay que leer antes de jugar (hoy 784 y 247); el contraste de un botón lleno se mide adentro de su filete (el principal ahora es oro con letra de tinta y el borde de la medida caía afuera); la victoria se verifica plegada y desplegada; nota nueva `hud_tapa_*`.

## 3. Crítica honesta de las capturas (`hojas/`)
- Briefing: es la mejora más visible; se lee como una pantalla de capítulo y no como una ventanita. Le falta una imagen propia: el fondo es la escena del nivel oscurecida, que hoy es la noche plana que arregla P2. La cronología es corta (dos hitos) porque no hay más fechas previas con fuente en el proyecto.
- Partes: legibles sin scroll en 1024 × 640; en 1280 × 720 y más queda aire en la mitad inferior (la escena se ve). El parte de victoria dice «según La Serna» en el epílogo: ese texto vive en `humahuaca_rules.json` (P3), no en `humahuaca_ui.json`, así que no lo toqué (§4).
- HUD: la paleta y la cabecera dejan de ser «tablero verde»; el dock acotado libera el centro abajo en pantallas anchas. A 1280 × 720 y 1024 × 640 el HUD sigue tapando 30–35 % (50 % en ataque con aviso): bajar el dock pide mover la banda que usa la cámara (P2) y no se hizo.
- Minimapa: ahora es nocturno y coherente con la escena; queda oscuro y con poco detalle del relieve. Con un mapa nocturno de verdad desde la vista quedaría mejor.

## 4. Pedidos a otras pistas
- **P3 (reglas):** (1) `b_diario_marca_z_negativa`: en `_valid_entry` exigir «las dos −1 o las dos en [0, tamaño]». (2) `a_undo_prev`: que `undo_last` restaure `stage`/`order` desde `prev` y no salte la señal; con eso la interfaz puede dejar de negarse en el caso «undo_lost» (`humahuaca_ui_play.gd::undo_refusal`). (3) R-01/R-02: `new_world()` debe vaciar los controles y `_write_checkpoint` borrar «salida» también del índice; la interfaz ya se defiende, pero el progreso sigue ofreciéndolos. (4) **H03:** `epilogue.lines[4]` de `humahuaca_rules.json` dice «según La Serna»; el reemplazo está en `docs/humahuaca/TEXTOS_REVISION.md`. No vive en `humahuaca_ui.json`. (5) «Dá la señal» → «Da la señal» en `outcome.causes.amanecio.consejo` y `siguiente.signal`. (6) P-008: para decir «cuánto falta» en segundos (no en metros) y para no inferir el tipo de espera, que `next_step()` traiga un `id` (`wait_group`, `wait_attack`…) y un `eta_s`; y una acción secundaria real durante el ataque, si el diseño la tiene.
- **P2 (vista/cámara):** el encuadre inicial deja fichas a −45 % del borde en todos los tamaños (falla de `ui_qa_humahuaca` antes y después; P-006). Un mapa chico nocturno desde `get_minimap_texture` mejoraría el minimapa.
- **P4 (main.gd):** `e_escala_doble_tras_justina` y `f_start_game_con_hx_vivo`; el desbloqueo del III al ganar el II (P-007) escuchando `exited("norte")`; si se crea `scripts/ui/palette.gd`, usar los HEX de `humahuaca_ui_kit.gd` (los mismos de la dirección de arte). P-013 (bajas 53 % / 52 %) y P-014 («LO APRENDIDO» vacío) son del parte de la Justina, no del II: en el parte del II las bajas salen de una sola cifra (`loss_pct`) y no hay encabezado vacío.
- **Lead:** el disco C: está al 100 % (≈ 3 GB libres durante esta tanda); un `git archive` para la comparación falló por falta de espacio y la línea de base se tomó cambiando solo los archivos de la interfaz en el propio worktree (commit previo de resguardo).

## 5. Tickets
- Cerrados en esta rama (con su prueba): V-06, D-08, D-11 (prueba propia; la medida con el agente real queda para el QA), T-006, T-005 (mitad interfaz), T-009 en b_/e_/f_/g_ (12 de 13; la restante es de P3), P-008 (mitad interfaz).
- Abiertos: T-008 (la interfaz ya no deshace mal; falta `a_undo_prev` en P3), D-02/H03 (texto en reglas, P3), `b_diario_marca_z_negativa` (P3), encuadre inicial (P2).
