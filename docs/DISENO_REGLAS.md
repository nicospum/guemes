# Reglas y contrato del núcleo jugable

Versión de guardado: **Justina 2** (mapa versión 2, segunda pasada de octubre de 2026) y **Norte 1**. Motor comprobado: **Godot 4.7.2 estable**. El código autorizado de las reglas está en `scripts/game_rules.gd`; no depende de la cámara, de los modelos ni de una respuesta externa. Los tiempos, agrupaciones, porcentajes, rutas y fórmulas de este documento son diseño del juego, no datos históricos. Las etiquetas de fuente (documentado, tradición, reconstrucción, diseño) viven en `data/justina_map.json`; el diseño y la API entre pistas están en `docs/DISENO_JUSTINA.md` y `docs/CONTRATO_JUSTINA.md`.

## Justina (rediseño de octubre de 2026)

**Única fuente de números: `data/justina_map.json`**, leído una sola vez por `map_data()`. Las constantes que quedan en el código son de implementación (resolución de la malla de 4 m, cuantización del nivel a 0,05 m, límites de 400 sondas y 200 puntos por sonda, y los dos valores que el contrato fija en texto: `blend = 4` para pozos y casco, y la playa seca = `shore_high + 40`).

### Escala y estado

Unidad = 1 m; mapa de 900 x 520 m; el norte es `-z` y el río está al este. **La costa inicial está al pie de la barranca**: cresta, pie, Alameda, Plaza de Toros, batería y puesto de Liniers están 120 m más al este que en la primera versión, y los ~390 m al buque se miden desde el pie de la barranca (ver `docs/DISENO_JUSTINA.md`). El estado nuevo (ver contrato 1.2) agrega al de 0.3.0: nivel real del río (`water_level_m`, con `water_level` derivado para la UI vieja), munición, balizas, reservorio de voluntarios, orden de avance, apoyo de fuego, sondas, dos exploradores, hallazgos y estadísticas del parte. Cada grupo suma `pace`, `work`, `stumble_remaining` y `tag`.

Campos que **el contrato no listaba** y se agregaron (la UI y la Vista no deben depender de ellos): `state.defeat_cause` (`plazo|dispersos|retirada`, alimenta el título del parte), `stats.bank_s` (segundos sobre cada banco, para la ruta del parte), `stats.stumble_at` (tropiezos por pozo, para las notas del parte) y, en los exploradores, `probe_id`, `mark_done`, `mark_charged` mientras trabajan.

### Terreno, conocimiento y velocidad

- `terrain_height_at` es la única implementación del fondo (contrato 1.3.1). Meseta y barranca se interpolan por `z`; desde el pie de la barranca se parte del perfil base y se aplican, en orden, bancos (máx.), canal (fija), vados, pozo y casco. Las ocho alturas de referencia del contrato se verifican en los tests (±0,02 m).
- El agua es turbia: `knowledge_at` devuelve `visible` en tierra y donde la profundidad real es ≤ 0,3 m (la cresta del banco central, por ejemplo, se ve con el río en mínimo), `probed`/`marked` dentro de una franja sondeada y `unknown` en el resto. Lo desconocido se **percibe** con el perfil base +0,5 m (`perceived_height_at`); el planificador usa esa percepción y la simulación usa el fondo real.
- `speed_at` es la tabla del contrato 1.3.3: firme (galope 7 / trote 3 / paso 1,3 m/s), barro 1,0 → 1,5 m/s, somera 2,0 (a pie 1,0), agua de 0,6 a 1,3 m a 0,8 m/s, más de 1,3 m (a pie 1,2 m) intransitable, bajadas ×0,7 y carril sondeado sin marcar ×0,75. El galope solo vale en firme. Un grupo avanza como mucho `min(speed_at(inicio), speed_at(fin))`; el cansancio **no** frena la marcha (solo resta poder de abordaje, como dice el contrato).
- Aclaración sobre la **meseta**: el contrato fija `speed 0` en la meseta y, a la vez, pide reunir jinetes en la Plaza de Toros, abastecerse en la batería y señalar en el puesto de Liniers, que están sobre ella. Se resolvió con **accesos**: cápsulas de 24 m de ancho (el ancho de la bajada) que van del borde superior de cada bajada al hito de trabajo más cercano; son tipo `bajada` (×0,7). El resto de la meseta sigue sin pisarse.

### Mareas, ventanas y planificación

`tide_at` / `tide_marks` salen del bloque `time` del JSON (baja de 1,65 a 0 entre 60 y 450 s, mínimo hasta 960 s, sube hasta 1080 s, plazo 1080 s = 18 min). `ford_window` da cuándo el vado es transitable; **si el punto no está reconocido, la ventana es la que el jugador cree** (perfil base +0,5 m), siempre con `certain = false`. Con el vado reconocido da ≈ 379..982 s (buque) y ≈ 355..989 s (sur) para caballos; para gente a pie (límite 1,2 m) el vado del buque deja de ser vadeable hacia t ≈ 974 s.

`plan_route` no tiene efectos. Usa A* de `AStarGrid2D` sobre celdas de 4 m (226 x 131 nodos) con peso `trote / velocidad percibida` (×0,8 si la celda es agua reconocida), suaviza la ruta con visibilidad directa y solo acepta un atajo si no sale más caro que la ruta cruda, para que no abandone los carriles reconocidos. Devuelve los puntos de giro, longitud, ETA (integrada con la velocidad percibida en el nivel de cada instante), metros sin reconocer, segundos expuestos, profundidad máxima, si llega dentro de la ventana del vado del buque, el riesgo y advertencias. La malla se reconstruye al cambiar el nivel (cuantizado a 0,05 m) o las sondas; un pozo o vado descubierto se estampa como conocido **solo para el planificador** (`knowledge_at` sigue dependiendo únicamente de las sondas).

Riesgo: `bajo` (sin metros sin reconocer y profundidad ≤ 0,6 del límite), `alto` (más de 80 m sin reconocer), `desconocido` (destino en agua sin reconocer y ruta corta) y `medio` (el resto). Se aplica `alto` antes que `desconocido`: así un cruce largo hacia un destino sin reconocer se ve como `alto`, que es lo que la UI espera mostrar.

### Acciones

Grupo: `move`, `board`, `muster`, `resupply`, `signal_liniers`, `withdraw`, `rally`, `cancel`. Explorador: `probe`, `mark_ford`, `recall`. Globales: `distract_fire`, `retreat_all`. Todas rechazan con un motivo concreto (`action_availability` lo da sin efectos, junto con `cost_text` y `tag`).

| Acción | Costo | Efecto y rechazos principales |
| --- | --- | --- |
| `move` | marcha a `pace` | Ruta con el conocimiento actual (hasta 4 waypoints). Rechaza destino fuera del mapa, obstáculo, casco, barranca/meseta, agua conocida más honda que el límite, fondo estimado que supera el límite y ruta imposible. |
| `board` | marcha + 12 s de desmonte; luego fuego x0,5, cuerpo a cuerpo y agua que sube | Exige `advance_authorized` vigente ("Falta la orden de avance de Liniers: señalá primero."). Al llegar al borde de la zona de abordaje (`boarding_radius_m`, 24 m) empieza a desmontar. |
| `muster` | 40 s en la Plaza de Toros, **4 de munición** y **+20 de fatiga** | +20 de fuerza (tope 100) del reservorio de 60. Rechaza con fuerza completa, reservorio vacío o sin munición para armar a los reclutas. |
| `resupply` | 25 s en la batería | +16 de munición (tope 40). Rechaza con el depósito lleno. |
| `signal_liniers` | 10 s en el puesto | Concede el avance **durante 300 s** (`state.advance_until`; `resources().advance_remaining_s`) y +8 de munición. Rechaza si sigue vigente; vencida hay que volver a señalar. Etiqueta **diseño**: es una regla del juego, y el evento no afirma que Güemes lleve la orden (eso es tradición no probada). |
| `withdraw` / `rally` | marcha / tiempo | `withdraw` también vale **desde el abordaje**: el grupo vuelve a montar y marcha a la playa. Vuelven a la playa seca (x ≤ `shore_high` + 40 y fuera del alcance); `rally` descansa (−0,18 fatiga/s, +0,025 fuerza/s). `rally` se rechaza fuera de la playa seca. |
| `probe` | explorador ocupado (4 de salud) | Sondea una franja de 6 m a 3 m/s en seco y 1 m/s en agua; no entra en fondo real > 1,1 m: se detiene, revela esa franja y, si lo frena un pozo, la sonda llega a su centro y el pozo pasa a `hazards_found`. Dentro del alcance del buque cada descarga lo acierta con probabilidad `0,4 x exposición`. |
| `mark_ford` | 1 baliza por 10 m | Exige puntos a ≤ 3 m del eje de un carril sondeado. Trabaja a 1 m/s y convierte el tramo en corredor de 16 m. "Faltan balizas (quedan N)." |
| `distract_fire` | 8 de munición | 45 s con la exposición a la mitad y +2 s entre descargas; recarga 90 s; moral de la dotación −3. |
| `retreat_all` | — | Termina la partida: derrota ordenada. |

Trabajo (`muster`, `resupply`, `signal_liniers`): el grupo marcha hasta estar a ≤ el radio del hito y entonces trabaja (`stage = working`); cambiar de orden lo interrumpe y no cobra nada.

### Tropiezo, fuego y captura

**Tropiezo.** Si un grupo avanza hacia un punto **no reconocido** cuyo fondo real supera su límite, se detiene en el borde (`stumbling`), pierde fuerza (caballos y jinetes), suma fatiga, se agrega una sonda corta, el hoyo pasa a `hazards_found` y el grupo replanifica. El costo sale del hoyo más cercano (`stumble` en el JSON): **pozo central** 35 s / +30 fatiga / −28 de fuerza; **falsos vados** de los bordes norte y sur del banco central 25 s / +20 / −18; **canal de la ribera** 30 s / +25 / −22. Antes costaba 20 s / +12 / −3: reconocer no pesaba. Se acumula en `stats.horses_lost` y se informa en el parte. Si el punto era conocido nunca tropieza: se detiene (`blocked`) y replanifica cada 5 s. Una agrupación cuyo punto pasa a ser intransitable por la subida del río es llevada al punto firme de la playa más cercano (+10 de fatiga).

**Fuego del buque.** Cada 7,5 s (9,5 s con apoyo de fuego) contra un objetivo de los expuestos, con peso 1 para un grupo y 0,15 para un explorador. Daño `uniform(3,2; 5,0) x exposición x max(0,2; moral/100)`. La exposición es 1,0 / 0,5 / 0,25 según el ángulo respecto del eje este-oeste del buque, dentro de 280 m; quien desmonta o aborda la recibe **x0,5** (`ship.capture.boarding_exposure_mult`; antes x0,3). Un explorador alcanzado pierde 1 de salud con probabilidad `0,4 x exposición` (`ship.fire.scout_hit_chance`): con 4 de salud cae tras ≈ 12 descargas (≈ 90 s) si es el único blanco, no en 22 s, y el fuego de distracción lo protege.

**Abordaje.** Cada grupo en `dismounting` o `boarding` (`_boarding_hazards`):
- *Cuerpo a cuerpo* (solo `boarding`): pierde `0,06 x moral/100` de fuerza por segundo (`melee_loss_per_s`); `stats.melee_loss` lo acumula.
- *Agua que sube*: si la profundidad en su posición supera el límite de un hombre a pie (1,2 m) pierde `3,0 x (exceso + 0,1)` de fuerza por segundo (`drown_loss_per_m_s`); `stats.drowned` lo acumula y se avisa cada 20 s. Antes estos grupos estaban exentos del agua.
- *Poder de captura* = `fuerza/100 x max(0,4; 1 − 0,004 x fatiga)`; la fatiga de un grupo que aborda sube 0,05/s. La captura avanza `0,30 x poder` %/s y la moral de la dotación baja `0,12 x poder` /s.
- *Retirada*: `withdraw` se acepta en `boarding`; el grupo monta de nuevo (los caballos esperan en el vado) y marcha a la playa.

**Orden de avance.** `signal_liniers` fija `state.advance_until = elapsed + 300`; al vencer `advance_authorized` vuelve a `false` con un aviso. Una orden `board` ya dada no se cancela.

Victoria: captura 100 %. Derrota: todos los grupos con fuerza ≤ 5, plazo de 1080 s o retirada general. `campaign_report()` entrega el parte (grupos, ruta usada, metros sondeados, tropiezos, caballos perdidos, pérdidas por cuerpo a cuerpo y por agua, munición, abordaje y la historia fija con sus etiquetas).

### Guardado

`snapshot()` es `state.duplicate(true)`. **Tamaño**: `save_game` escribe JSON compacto (sin tabulaciones; precisión completa), el registro del estado se recorta a los últimos `LOG_MAX = 400` acontecimientos y, si el texto supera `SAVE_MAX_BYTES = 3 000 000`, se guarda una copia con solo los últimos 60 (la partida en curso no se toca); si aun así no cabe devuelve `ERR_FILE_CORRUPT` sin escribir. `load_game` sigue rechazando archivos de más de 4 MB. Peor caso medido en los tests (400 sondas de 150 puntos y el registro lleno): ver `_test_save_size`. Campos nuevos del estado: `advance_until`, `stats.horses_lost`, `stats.melee_loss`, `stats.drowned`. `load_game` rechaza un guardado de Justina con versión 1 ("Este guardado es de una versión anterior del escenario Justina y no es compatible.") y uno con otra `map_version`. `validate_snapshot` comprueba tipos y rangos de todos los campos nuevos y su coherencia con el tiempo y entre sí (ver `tests/test_rules.gd`). Una diferencia con el contrato: la regla "`advance_authorized` verdadero si existe una orden `signal_liniers` en `orders`" se implementó en sentido inverso, **`advance_authorized` ⇒ existe una orden `signal_liniers` registrada**, porque la orden se registra al darla y la autorización llega después de marchar y trabajar; la regla literal rechazaría guardados legítimos tomados en ese intervalo.

## Norte: decisiones por rondas y sostén de la resistencia (sin cambios)

La campaña tiene hasta 14 rondas, con referencias cronológicas del 15 de diciembre de 1816 al 5 de mayo de 1817. El mapa conecta Humahuaca, Quebrada, Jujuy, Salta, Valle de Lerma, Chicoana, Orán y Rosario de la Frontera. Su grafo es una simplificación operativa, no un levantamiento de rutas históricas exactas.

Cada agrupación prepara una orden por ronda. Puede cambiarla o cancelarla hasta resolver. Las órdenes se validan al prepararse y otra vez al ejecutarse, porque otro grupo puede haber consumido recursos o cambiado un sector.

| Orden | Condiciones y efecto principal |
| --- | --- |
| Desplazar | Un sector vecino; consume suministros y aumenta fatiga. |
| Explorar | Sector actual o vecino; descubre conexiones y proporciona información útil durante tres rondas. Reduce el riesgo y mejora el efecto de hostigar. |
| Proteger | Sector propio actual con víveres disponibles; suma 18 reservas y 9 apoyo. Retira una partida finita de recursos y reduce la recuperación de abastecimientos realistas. |
| Hostigar | Ruta realista reconocida, fuerza y suministros suficientes, fatiga tolerable; reduce abastecimientos, cohesión y comunicaciones, con pérdidas propias. |
| Descansar | Sector seguro actual y 8 reservas; repone 27 suministros, hasta 9 efectivos y reduce 34 fatiga. |
| Replegar | Sector vecino sin ocupación; reduce fatiga y deja de revelar a la agrupación al enemigo. |
| Humahuaca | Solo Arias, desde la ronda del 1 de marzo, con acceso, recursos y fuerza suficiente. Neutraliza objetivos agregados de artillería, cuartel y arsenal y afecta la comunicación realista. |

El invasor sostiene tres indicadores: abastecimientos, cohesión y comunicaciones. Su intención puede ser buscar víveres, escoltar convoyes, avanzar o retirarse cuando es legal. La defensa también debe conservar reservas, suministros por agrupación y apoyo de la población. Los recursos nunca se vuelven negativos y los indicadores agregados tienen límites.

La ocupación de Salta se produce durante la campaña y **no equivale a una victoria realista automática**. Se gana cuando la presión sostenida hace inviable continuar: abastecimiento ≤22, cohesión ≤42 y comunicaciones ≤45; o una crisis extrema de cohesión ≤22 y abastecimiento ≤38. También se exige actividad ofensiva real y que la campaña haya llegado a la etapa de marzo. Esta condición no entrega una victoria por esperar. La población puede dejar de sostener la defensa antes del límite, y llegar a mayo sin quebrar al invasor también produce derrota.

Un resultado anterior a los primeros días de mayo se identifica en el desenlace como **retirada alternativa anticipada**. La noticia de Chacabuco es un mensaje contextual dramatizado: no crea un ejército de San Martín ni termina automáticamente la campaña. Humahuaca es una operación relevante que puede resolver Arias; no es un requisito obligatorio para todas las estrategias ganadoras.

## Estado, aleatoriedad y guardado

`state` es un diccionario compuesto por datos JSON: escenario, versión, identificador de sesión, semilla y estado del generador, unidades, órdenes pendientes, posiciones, recursos, progreso, log e intenciones externas aplicadas. Los indicadores `strength` y `supply` son valores agregados del diseño; no equivalen a cifras históricas de soldados o víveres.

El generador usa un estado entero dentro de un rango representable sin pérdida en JSON. Guardar utiliza precisión completa de coma flotante, un archivo temporal y cambio de nombre. Cargar valida el esquema, tipos, rangos, unidades, trayectos, órdenes, sectores, conexiones y registros **antes** de reemplazar la partida activa. Un archivo corrupto deja la partida en curso intacta. La comparación de continuación usa tolerancia numérica `10⁻⁶`; el estado entero del generador se comprueba exactamente.

Al cargar se crea un nuevo `game_id`, conservando el anterior como antecedente. Reiniciar también produce una identidad nueva. Esto evita que una solicitud de la sesión anterior pueda aplicarse a la partida actual. Las configuraciones de gráficos y sonido pertenecen a la presentación y no se incluyen en el guardado de campaña.

## Jev y autoridad de las reglas

El caso de uso es la **intención del mando realista al resolver una ronda del norte**. `enemy_observation()` construye una observación limitada: recursos y comunicaciones propios, sectores ocupados, acontecimientos públicos y agrupaciones enemigas que se revelaron al hostigar. Las agrupaciones no descubiertas, las órdenes pendientes del jugador y su semilla no se transmiten.

`enemy_choices()` devuelve únicamente intenciones legales. `enemy_fallback()` ofrece una decisión local si no hay respuesta utilizable. `record_external_decision()` exige coincidencia de partida, ronda y versión de estado, además de una opción legal; las respuestas antiguas o inventadas se rechazan. Las fórmulas de combate, abastecimientos, movimiento y victoria permanecen en el núcleo local. El cliente asíncrono, los límites de tiempo y el estado de la validación en vivo se documentan por separado en `JEV.md`.

## Contrato para la presentación

La API completa de Justina está en `docs/CONTRATO_JUSTINA.md` (secciones 1.1 a 1.9). Resumen de lo implementado:

| Método o campo | Uso |
| --- | --- |
| `new_game(scenario, seed)` | Inicializa `justine` (schema 2) o `norte` (schema 1) y devuelve el estado. |
| `tick(delta)` | Avanza Justina en pasos de 0,25 s; devuelve eventos nuevos. |
| `map_data()`, `map_size()`, `board_point()`, `ship_position()` | Mapa cacheado (solo lectura) y puntos clave. |
| `terrain_height_at`, `water_level_m`, `water_depth_at`, `terrain_kind_at`, `speed_at`, `is_walkable(x,z,mounted)` | Terreno real, una sola implementación. |
| `knowledge_at`, `perceived_height_at`, `perceived_depth_at` | Lo que el jugador sabe del fondo. |
| `tide_at`, `tide_marks`, `ford_window` | Río y ventanas de vado. |
| `exposure_at`, `exposure_for`, `ship_state`, `resources`, `scouts`, `probes` | Fuego del buque, recursos y reconocimiento (copias). |
| `plan_route(group, target, pace, opts)` | Ruta, ETA, riesgo y advertencias, sin efectos. |
| `issue_order(group, action, target, opts)` | Órdenes de grupo; devuelve `{ok, reason, path, plan}`. |
| `issue_scout(id, action, points)`, `call_fire_support()`, `retreat_all()` | Exploradores y acciones globales. |
| `list_actions(kind)`, `action_info(id)`, `action_availability(actor, action, target)` | Datos para el panel de acciones. |
| `campaign_report()` | Parte de campaña. |
| `issue_campaign_order`, `legal_campaign_actions`, `campaign_order_reason`, `resolve_round`, `enemy_*` | Norte, sin cambios. |
| `save_game(path)`, `load_game(path)`, `validate_snapshot(v)` | Guardado versionado y validado. |
| `nav_stats()`, `rebuild_navigation()` | Medición de rendimiento (para las pruebas). |
| `unit.stage` | Justina: `ready`, `moving`, `working`, `stumbling`, `rally`, `blocked`, `dismounting`, `boarding`, `routed`. Norte: además `ordered`. |

Se eliminaron `SHIP`, `BOARD_POINT`, `RISE_START`, `RISE_DURATION`, `obstacles` del estado y las órdenes `direct` y `flank`, como dispone el contrato (`scripts/main.gd` todavía usa `Rules.BOARD_POINT`: es trabajo de la pista UI).

La selección no forma parte de las reglas. Los identificadores de las tres agrupaciones son `guemes`, `arias`, `zavala`; los nombres visibles salen del JSON (`arias` y `zavala` son identificadores heredados que **no** atribuyen presencia de Arias ni de Zavala en 1806). El tiempo `elapsed` mide tiempo simulado de Justina.

## Verificación efectuada

`tests/test_rules.gd` corre el núcleo real en Godot, sin ventana, con 373 comprobaciones. Los resultados se escriben en `user://rules-test-results.json` (perfil aislado): **no tocan `evidence/`**. Cubren: alturas de referencia, tabla de velocidades, mareas y ventanas, conocimiento antes y después de sondear, cada acción (éxito, rechazo, costo, efecto), vigencia de la orden de avance, costos del abordaje (cuerpo a cuerpo, fuego x0,5, agua que sube, retirada), geografía (costa al pie de la barranca), etiquetas y textos históricos, `data/history.json`, **11 estrategias x 6 semillas** con criterios de no dominancia, velocidad nunca superada, ausencia de grupos varados, rescate, guardado compacto y con tope, más de 40 mutaciones de guardado que deben rechazarse (Justina y Norte), rendimiento medido y todo lo del Norte (sin cambios). `godot --headless --path . --script res://tests/test_rules.gd -- --matrix [--only=NOMBRE] [--seed=N] [--trace=NOMBRE]` imprime la matriz de estrategias para calibrar.

### Estrategias simuladas (6 semillas: 3, 5, 7, 11, 13, 17; tres grupos, sin intervención humana)

| Estrategia | Victorias | Tiempo medio de victoria | Bajas | Exposición cruce (s) | Notas |
| --- | --- | --- | --- | --- | --- |
| `rush_central`: `board` apenas el planificador lo acepta, sin reunir, sin reconocer | 0/6 | — (derrota a los ≈ 600 s) | 96 % | 397 | tres tropiezos, ≈ 106 de fuerza perdida en hoyos |
| `blind_north_edge`: reunir, abastecer, señalar y fuego, pero por el borde norte sin sondear | 0/6 | — | 94 % | 367 | cae en el falso vado del borde norte |
| `probed_central_full`: sondea el centro con fuego de cobertura, reúne, abastece, señala a tiempo | 5/6 | 795 s (13,3 min) | 40 % | 303 | la derrota es la semilla en que el explorador cae antes de hallar el pozo |
| `probed_central_bare`: igual pero sin reunir, sin abastecer, sin fuego | 0/6 | — | 94 % | 388 | el explorador cae solo y el grupo entra a ciegas |
| `south_full`: sondea y marca el vado sur, reúne, abastece, señala, fuego | 6/6 | 882 s (14,7 min) | 23 % | 179 | menos fuego, más lenta |
| `south_bare`: solo sondea el vado | 1/6 | 995 s | 91 % | 245 | llega sin refuerzos ni cobertura y se desgasta |
| `south_wrong_crossing`: cruza el canal sin conocer el vado | 0/6 | — | 94 % | 313 | tropieza en el canal |
| `mixed_split`: vanguardia por el centro, dos grupos por el sur | 5/6 | 977 s (16,3 min) | 57 % | 239 | |
| `central_stagger`: tres grupos al centro con 45 s de diferencia | 5/6 | 957 s (16 min) | 57 % | 290 | cada grupo recibe el fuego solo |
| `late_all_in`: sale tarde | 0/6 | — | — | — | el río ya no deja abordar |
| `passive` | 0/6 | — (derrota exactamente a 1080 s) | — | — | |

Cinco estrategias ganan en alguna semilla y cuatro (`probed_central_full`, `south_full`, `mixed_split`, `central_stagger`) en la mitad o más; la que más gana concentra el 27 % de las victorias (6 de 22) y hay victorias por la ruta central, la sur y la mixta. Las victorias duran entre 13,1 y 16,6 min (el plazo es de 18). Los tests lo exigen (`play_targets.dominance`): máximo 70 % de las victorias para una sola estrategia, al menos 3 estrategias ganando en la mitad o más de las semillas, y que ninguna ruta acumule más del 75 %.

### Lo que cumple y lo que no cumple el balance objetivo (`play_targets`)

- **Cumple**: la ruta a ciegas tropieza en todas las semillas y pierde; reconocer el centro solo falla cuando el explorador cae; el centro cuesta más fuego (cociente de exposición de cruce central/sur 1,69 con los recursos completos, mínimo exigido 1,4) pero llega antes (795 s contra 882 s); la sur gana con margen (≥ 60 s antes de t = 960, que es cuando el agua empieza a subir sobre el vado; el plazo es 1080); la pasividad pierde en 1080 s; salir tarde pierde; no hay unidades varadas. Reunir, abastecer, señalar y fuego de distracción tienen costos en munición, fatiga, tiempo y vigencia: las versiones "desnudas" (`*_bare`) pierden.
- **Duración**: 12-18 min cumplido para las victorias (13,1-16,6 min). Las derrotas por plazo duran 18 min; las derrotas rápidas (por ejemplo `rush_central`, ≈ 10 min) son grupos dispersos.
- **Qué sigue sin ser ideal**: `south_full` gana 6/6 con 23 % de bajas, frente a 5/6 y 40 % del centro. El sur es más lento pero más seguro; lo que lo equilibra es el tiempo (88 s más) y la menor holgura frente al agua que sube. Sin pruebas con personas no se sabe si eso basta para que el centro tenga adeptos. Las semillas solo cambian el azar del fuego, por eso la mayoría de las estrategias da el mismo resultado en las seis.

### Cambios de la segunda pasada respecto del contrato (a confirmar por el arquitecto y las otras pistas)

1. **Geografía**: toda la tierra al este del río original se corrió +120 m (ver `docs/DISENO_JUSTINA.md` 1.1). Las coordenadas del río (bancos, vados, casco, punto de abordaje, buque) **no cambiaron**. Los scripts de recorrido y las pruebas de interfaz que usan coordenadas de playa (x < 200) o de hitos de la meseta hay que actualizarlos.
2. **Línea de tiempo**: `drop 60-450 s`, `hold hasta 960 s`, `rise hasta 1080 s`, plazo `1080 s`. Todo lo que cablee tiempos (barra del río, tests de la UI) debe leerlos de `tide_marks()`.
3. **Nuevos campos**: `state.advance_until`, `state.stats.horses_lost|melee_loss|drowned`, `resources().advance_remaining_s`, `campaign_report().horses_lost|melee_loss|drowned`, `ship.capture.melee_loss_per_s|boarding_exposure_mult|drown_loss_per_m_s`, `ship.fire.scout_hit_chance`, `actions.muster.fatigue_gain|ammo_cost`, `actions.signal_liniers.valid_s`, `stumble` en el canal. `map_version` = 2.
4. **Etiquetas**: `signal_liniers` pasa de `tradicion` a `diseno`; la batería Abascal, el campamento de Pueyrredón y la reserva de caballería de Pueyrredón pasan de `documentado` a `reconstruccion`; el grupo de Güemes se titula "Vanguardia · Güemes (tradición)". La UI que agrupa por etiqueta lo recoge sola.
5. **Orden de avance con vigencia** (300 s) y **retirada desde el abordaje**: la UI debe mostrar `advance_remaining_s` y permitir `withdraw` a un grupo que aborda.
6. **Vados en modo `set`** (desvío ya existente): el JSON ahora lo declara (`bed_layers_order`). `world_view.gd` debe tomar las alturas de `terrain_height_at` de Reglas y no reimplementar bancos y vados en modo `max`: la diferencia hace que el vado del buque se vea 6,5 cm más alto de lo que el juego usa para pisarlo.

### Desvíos respecto del contrato (de la primera pasada, siguen vigentes)

1. **`ford_window` de un punto sin reconocer devuelve la ventana percibida**, no la real: el contrato 1.10 pide a la vez "≈ la ventana real" y "certeza falsa antes de sondear", y se interpretó que la ventana real se conoce al sondear.
2. **`advance_authorized` ⇒ existe la orden registrada** (ver Guardado).
3. **Accesos a la meseta** para poder reunir, abastecer y señalar (ver Terreno).
4. **El pozo se revela entero al frenar a un explorador** (la franja llega a su centro) para cumplir "tras `probe` sobre ese punto, `knowledge_at == probed`", porque el explorador no puede entrar en un fondo de 1,9 m.
5. **Un vado o pozo descubierto se estampa como conocido para el planificador**; `knowledge_at` sigue dependiendo solo de las sondas.
6. **Daño a exploradores con probabilidad = `0,4 x exposición`** (el contrato solo da el peso 0,15).
7. **Riesgo `alto` antes que `desconocido`** (ver Planificación).
8. **El abordaje empieza al llegar al radio de abordaje (24 m) del punto**, no exactamente en él.

### Rendimiento (medido, equipo de desarrollo, modo headless)

Medido con `tests/test_rules.gd` (sección "Rendimiento"); el informe queda en `user://rules-test-results.json`. Última medición: reconstrucción de la malla ≈ 5,7 ms (presupuesto 80), `plan_route` ≈ 2,8 ms (30), `tick` ≈ 0,06 ms (2), precálculo estático ≈ 110 ms una vez por proceso. La segunda pasada no cambió esas rutinas; la reconstrucción de conocimiento por baliza que hace la Vista (mallas y materiales nuevos en cada cambio de nivel) es trabajo de esa pista.

### No verificado

Ninguna cifra se jugó con personas; las estrategias están scripteadas con conocimiento del mapa que un jugador no tiene al principio, y los tiempos de victoria dependen de ese guion. **La UI y la Vista no se probaron con esta pasada**: `tests/test_integration.gd` falla en ocho comprobaciones (selección por caja, nombre del lugar bajo la cámara, tiempos de la bajante y del sondeo, balizas) por la nueva geografía y la nueva línea de tiempo; no es un defecto de las reglas pero hay que ajustarlo en la pista UI. No se corrió `tools/justina_playthrough.gd` ni `ui_qa.gd`. El Norte no cambió y sus pruebas pasan como antes.

Estos tiempos son **tiempo de simulación con órdenes automatizadas**, no mediciones de duración de jugadores humanos ni rendimiento gráfico.
