# Reglas y contrato del núcleo jugable

Versión de guardado: **Justina 2** y **Norte 1**. Motor comprobado: **Godot 4.7.2 estable**. El código autorizado de las reglas está en `scripts/game_rules.gd`; no depende de la cámara, de los modelos ni de una respuesta externa. Los tiempos, agrupaciones, porcentajes, rutas y fórmulas de este documento son diseño del juego, no datos históricos. Las etiquetas de fuente (documentado, tradición, reconstrucción, diseño) viven en `data/justina_map.json`; el diseño y la API entre pistas están en `docs/DISENO_JUSTINA.md` y `docs/CONTRATO_JUSTINA.md`.

## Justina (rediseño de octubre de 2026)

**Única fuente de números: `data/justina_map.json`**, leído una sola vez por `map_data()`. Las constantes que quedan en el código son de implementación (resolución de la malla de 4 m, cuantización del nivel a 0,05 m, límites de 400 sondas y 200 puntos por sonda, y los dos valores que el contrato fija en texto: `blend = 4` para pozos y casco, y la playa seca = `shore_high + 40`).

### Escala y estado

Unidad = 1 m; mapa de 900 x 520 m; el norte es `-z` y el río está al este. El estado nuevo (ver contrato 1.2) agrega al de 0.3.0: nivel real del río (`water_level_m`, con `water_level` derivado para la UI vieja), munición, balizas, reservorio de voluntarios, orden de avance, apoyo de fuego, sondas, dos exploradores, hallazgos y estadísticas del parte. Cada grupo suma `pace`, `work`, `stumble_remaining` y `tag`.

Campos que **el contrato no listaba** y se agregaron (la UI y la Vista no deben depender de ellos): `state.defeat_cause` (`plazo|dispersos|retirada`, alimenta el título del parte), `stats.bank_s` (segundos sobre cada banco, para la ruta del parte), `stats.stumble_at` (tropiezos por pozo, para las notas del parte) y, en los exploradores, `probe_id`, `mark_done`, `mark_charged` mientras trabajan.

### Terreno, conocimiento y velocidad

- `terrain_height_at` es la única implementación del fondo (contrato 1.3.1). Meseta y barranca se interpolan por `z`; desde el pie de la barranca se parte del perfil base y se aplican, en orden, bancos (máx.), canal (fija), vados, pozo y casco. Las ocho alturas de referencia del contrato se verifican en los tests (±0,02 m).
- El agua es turbia: `knowledge_at` devuelve `visible` en tierra y donde la profundidad real es ≤ 0,3 m (la cresta del banco central, por ejemplo, se ve con el río en mínimo), `probed`/`marked` dentro de una franja sondeada y `unknown` en el resto. Lo desconocido se **percibe** con el perfil base +0,5 m (`perceived_height_at`); el planificador usa esa percepción y la simulación usa el fondo real.
- `speed_at` es la tabla del contrato 1.3.3: firme (galope 7 / trote 3 / paso 1,3 m/s), barro 1,0 → 1,5 m/s, somera 2,0 (a pie 1,0), agua de 0,6 a 1,3 m a 0,8 m/s, más de 1,3 m (a pie 1,2 m) intransitable, bajadas ×0,7 y carril sondeado sin marcar ×0,75. El galope solo vale en firme. Un grupo avanza como mucho `min(speed_at(inicio), speed_at(fin))`; el cansancio **no** frena la marcha (solo resta poder de abordaje, como dice el contrato).
- Aclaración sobre la **meseta**: el contrato fija `speed 0` en la meseta y, a la vez, pide reunir jinetes en la Plaza de Toros, abastecerse en la batería y señalar en el puesto de Liniers, que están sobre ella. Se resolvió con **accesos**: cápsulas de 24 m de ancho (el ancho de la bajada) que van del borde superior de cada bajada al hito de trabajo más cercano; son tipo `bajada` (×0,7). El resto de la meseta sigue sin pisarse.

### Mareas, ventanas y planificación

`tide_at` / `tide_marks` salen del bloque `time` del JSON (baja de 1,65 a 0 entre 45 y 375 s, mínimo hasta 645 s, sube hasta 825 s, plazo 900 s). `ford_window` da cuándo el vado es transitable; **si el punto no está reconocido, la ventana es la que el jugador cree** (perfil base +0,5 m), siempre con `certain = false`. Con el vado reconocido da ≈ 315..677 s (buque) y ≈ 295..688 s (sur).

`plan_route` no tiene efectos. Usa A* de `AStarGrid2D` sobre celdas de 4 m (226 x 131 nodos) con peso `trote / velocidad percibida` (×0,8 si la celda es agua reconocida), suaviza la ruta con visibilidad directa y solo acepta un atajo si no sale más caro que la ruta cruda, para que no abandone los carriles reconocidos. Devuelve los puntos de giro, longitud, ETA (integrada con la velocidad percibida en el nivel de cada instante), metros sin reconocer, segundos expuestos, profundidad máxima, si llega dentro de la ventana del vado del buque, el riesgo y advertencias. La malla se reconstruye al cambiar el nivel (cuantizado a 0,05 m) o las sondas; un pozo o vado descubierto se estampa como conocido **solo para el planificador** (`knowledge_at` sigue dependiendo únicamente de las sondas).

Riesgo: `bajo` (sin metros sin reconocer y profundidad ≤ 0,6 del límite), `alto` (más de 80 m sin reconocer), `desconocido` (destino en agua sin reconocer y ruta corta) y `medio` (el resto). Se aplica `alto` antes que `desconocido`: así un cruce largo hacia un destino sin reconocer se ve como `alto`, que es lo que la UI espera mostrar.

### Acciones

Grupo: `move`, `board`, `muster`, `resupply`, `signal_liniers`, `withdraw`, `rally`, `cancel`. Explorador: `probe`, `mark_ford`, `recall`. Globales: `distract_fire`, `retreat_all`. Todas rechazan con un motivo concreto (`action_availability` lo da sin efectos, junto con `cost_text` y `tag`).

| Acción | Costo | Efecto y rechazos principales |
| --- | --- | --- |
| `move` | marcha a `pace` | Ruta con el conocimiento actual (hasta 4 waypoints). Rechaza destino fuera del mapa, obstáculo, casco, barranca/meseta, agua conocida más honda que el límite, fondo estimado que supera el límite y ruta imposible. |
| `board` | marcha + 12 s de desmonte | Exige `advance_authorized` ("Falta la orden de avance de Liniers: señalá primero."). Al llegar al borde de la zona de abordaje (`boarding_radius_m`, 24 m) empieza a desmontar. |
| `muster` | 40 s en la Plaza de Toros | +25 de fuerza (tope 100) del reservorio de 60. Rechaza con fuerza completa o reservorio vacío. |
| `resupply` | 25 s en la batería | +16 de munición (tope 40). Rechaza con el depósito lleno. |
| `signal_liniers` | 10 s en el puesto | Concede el avance y +8 de munición. Rechaza si ya fue concedida. Etiqueta **tradición**. |
| `withdraw` / `rally` | marcha / tiempo | Vuelven a la playa seca (x ≤ `shore_high` + 40 y fuera del alcance); `rally` descansa (−0,18 fatiga/s, +0,025 fuerza/s). `rally` se rechaza fuera de la playa seca. |
| `probe` | explorador ocupado | Sondea una franja de 6 m a 3 m/s en seco y 1 m/s en agua; no entra en fondo real > 1,1 m: se detiene, revela esa franja y, si lo frena un pozo, la sonda llega a su centro y el pozo pasa a `hazards_found`. |
| `mark_ford` | 1 baliza por 10 m | Exige puntos a ≤ 3 m del eje de un carril sondeado. Trabaja a 1 m/s y convierte el tramo en corredor de 16 m. "Faltan balizas (quedan N)." |
| `distract_fire` | 8 de munición | 45 s con la exposición a la mitad y +2 s entre descargas; recarga 90 s; moral de la dotación −2. |
| `retreat_all` | — | Termina la partida: derrota ordenada. |

Trabajo (`muster`, `resupply`, `signal_liniers`): el grupo marcha hasta estar a ≤ el radio del hito y entonces trabaja (`stage = working`); cambiar de orden lo interrumpe y no cobra nada.

### Tropiezo, fuego y captura

Si un grupo avanza hacia un punto **no reconocido** cuyo fondo real supera su límite, se detiene en el borde (`stumbling`, 20 s), sufre +12 de fatiga y −3 de fuerza, se agrega una sonda corta, el pozo pasa a `hazards_found` y el grupo replanifica. Si el punto era conocido nunca tropieza: se detiene (`blocked`) y replanifica cada 5 s. Una agrupación cuyo punto pasa a ser intransitable por la subida del río es llevada al punto firme de la playa más cercano (+10 de fatiga).

El buque dispara cada 7,5 s (9,5 s con apoyo de fuego) contra un objetivo de los expuestos, con peso 1 para un grupo y 0,15 para un explorador. Daño `uniform(3,2; 5,0) x exposición x max(0,2; moral/100)`. La exposición es 1,0 / 0,5 / 0,25 según el ángulo respecto del eje este-oeste del buque, dentro de 280 m. Un explorador alcanzado pierde 1 de salud **con probabilidad igual a la exposición** (decisión de Reglas: así el fuego de distracción también protege a los exploradores). Captura y moral de la dotación siguen las fórmulas del contrato (`0,19` y `0,12` por poder de abordaje).

Victoria: captura 100 %. Derrota: todos los grupos con fuerza ≤ 5, plazo de 900 s o retirada general. `campaign_report()` entrega el parte (grupos, ruta usada, metros sondeados, tropiezos, munición, abordaje y la historia fija con sus etiquetas).

### Guardado

`snapshot()` es `state.duplicate(true)`. `load_game` rechaza un guardado de Justina con versión 1 ("Este guardado es de una versión anterior del escenario Justina y no es compatible.") y uno con otra `map_version`. `validate_snapshot` comprueba tipos y rangos de todos los campos nuevos y su coherencia con el tiempo y entre sí (ver `tests/test_rules.gd`). Una diferencia con el contrato: la regla "`advance_authorized` verdadero si existe una orden `signal_liniers` en `orders`" se implementó en sentido inverso, **`advance_authorized` ⇒ existe una orden `signal_liniers` registrada**, porque la orden se registra al darla y la autorización llega después de marchar y trabajar; la regla literal rechazaría guardados legítimos tomados en ese intervalo.

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

`tests/test_rules.gd` corre el núcleo real en Godot, sin ventana, con 323 comprobaciones. Los resultados se escriben en `user://rules-test-results.json` (perfil aislado): **no tocan `evidence/`**. Cubren: alturas de referencia, tabla de velocidades, mareas y ventanas, conocimiento antes y después de sondear, cada acción (éxito, rechazo, costo, efecto), `board` con y sin orden de avance, fuego y exposición, siete estrategias completas, velocidad nunca superada (más de 2 700 pasos muestreados), ausencia de grupos varados, rescate, guardado y continuación, más de 40 mutaciones de guardado que deben rechazarse (Justina y Norte), rendimiento medido y todo lo del Norte.

### Estrategias simuladas (semilla 7, tres grupos, sin intervención humana)

| Estrategia | Resultado | Tiempo | Bajas | Tropiezos | Exposición centro / sur (s) |
| --- | --- | --- | --- | --- | --- |
| Central a ciegas (`board` apenas el planificador lo acepta, sin reunir ni distraer) | derrota (captura 73 %) | 900 s | 58,8 % | 2 | 404 / 0 |
| Central por el borde norte del banco, con reunir x2, abastecer y fuego de distracción | victoria | 678 s (11,3 min) | 2,0 % | 0 | 242 / 0 |
| Sur: sondear el borde del vado, marcar el acceso, esperar la apertura (≈ 300 s) y cruzar | victoria | 863 s (14,4 min) | −2,3 % (reunió más de lo que perdió) | 0 | 0 / 182 |
| Mixta (vanguardia al centro, dos grupos al sur) | victoria | 846 s | 9,5 % | 0 | 81 / 116 |
| Salir tarde (a los 690 s) | derrota por plazo | 900 s | 2,6 % | 2 | — |
| Pasividad | derrota | exactamente 900 s | — | — | — |
| Mismos grupos, sin reunir ni fuego de distracción: centro / sur | victoria 852 s con 48 % de bajas / derrota (captura 77 %) | — | — | — | 348 / 245 (cociente 1,42) |

### Lo que cumple y lo que no cumple el balance objetivo (`play_targets`)

- **Cumple**: la ruta a ciegas tropieza y pierde ≥ 30 %; la pasividad pierde en 900 s; salir tarde pierde; la exposición del centro es ≥ 1,4 x la del sur con los mismos grupos sin apoyo (1,42); no hay unidades varadas; centro y sur son un intercambio (el centro llega antes y se expone más; el sur llega después y casi no recibe fuego); el centro con refuerzos y apoyo gana en 678 s (< 760 s).
- **No cumple**: la ruta sur gana en **863 s, no antes de 800 s**. Con las cifras del JSON el vado se cruza a 0,8 m/s (74 m, ≈ 90 s) y abre recién a los ≈ 295 s; la llegada al buque no puede ser anterior a ≈ 600 s y la captura necesita ≈ 240-270 s más: el mejor caso que se logró fue 863 s, con muy poco margen frente al plazo de 900 s (la misma ruta sin reunir ni apoyo de fuego pierde). No se tocaron las cifras: el ajuste corresponde al arquitecto (por ejemplo, subir `rate_per_power_per_s`, bajar el costo del vado o mover el plazo).
- **Duración**: las victorias duran 11,3-14,4 min y las derrotas 15 min (el plazo acota la partida en 15); el objetivo "12-18 min" del encargo solo se alcanza en la banda baja con la ruta sur. Con refuerzos y fuego de distracción el centro termina antes de los 12 min.
- **Con información perfecta el centro domina**: al saber dónde está el pozo (borde norte) y con apoyo de fuego, el centro es más rápido y apenas pierde fuerza. El costo de saber del pozo es real (un tropiezo o un explorador: sondear el pozo desde el oeste obliga a entrar en el alcance, donde el explorador cae en ≈ 22 s si es el único blanco). Esto debe jugarse con personas.
- **Explorar bajo el fuego del buque es muy caro**: un explorador solo en el alcance es el único blanco posible; con 3 de salud no llega a sondear 100 m. Solo la zona de x < 300 m (y el borde del vado sur) se reconoce sin riesgo.

### Desvíos respecto del contrato (a confirmar por el arquitecto)

1. **Vados en modo `set`**, no `max` (contrato 1.3.1). Con `max`, la cola del banco sur eleva el vado del buque a −0,935 m y contradice la altura de referencia (−1,0 m) y la ventana 315..677 s; con `set` las ocho alturas de referencia coinciden y las dos ventanas dan 315/677 y 295/688.
2. **`ford_window` de un punto sin reconocer devuelve la ventana percibida** (279..697 s para el buque, 56..819 s para el vado sur), no 315..677: el contrato 1.10 pide a la vez "≈ 315..677" y "certeza falsa antes de sondear", y se interpretó que la ventana real se conoce al sondear.
3. **`advance_authorized` ⇒ existe la orden registrada** (ver Guardado).
4. **Accesos a la meseta** para poder reunir, abastecer y señalar (ver Terreno).
5. **El pozo se revela entero al frenar a un explorador** (la franja llega a su centro) para cumplir "tras `probe` sobre ese punto, `knowledge_at == probed`", porque el explorador no puede entrar en un fondo de 1,9 m.
6. **Un vado o pozo descubierto se estampa como conocido para el planificador**; `knowledge_at` sigue dependiendo solo de las sondas.
7. **Daño a exploradores con probabilidad = exposición** (el contrato solo da el peso 0,15).
8. **Riesgo `alto` antes que `desconocido`** (ver Planificación).
9. **El abordaje empieza al llegar al radio de abordaje (24 m) del punto**, no exactamente en él: el contrato dice "al llegar" y el JSON define `boarding_radius_m`.

### Rendimiento (medido, equipo de desarrollo, modo headless)

| Operación | Medido | Presupuesto del contrato |
| --- | --- | --- |
| Reconstrucción de la malla de rutas | ≈ 6 ms | 80 ms |
| `plan_route` | ≈ 3,8 ms | 30 ms |
| `tick` (paso de 0,25 s) | ≈ 0,056 ms | 2 ms |
| Precálculo estático de alturas (una vez por proceso, la primera vez que hace falta una ruta) | ≈ 106 ms | — |

### No verificado

Ninguna cifra se jugó con personas; la UI y la Vista no se probaron con estas reglas (`scripts/main.gd` y `tests/test_integration.gd` todavía usan la API anterior); las estrategias están scripteadas con conocimiento del mapa que un jugador no tiene al principio, y los tiempos de victoria dependen de ese guion. El Norte no cambió, y sus pruebas (campañas, ritmo, ocupación de Salta, coherencia de guardado) pasan como antes.

Estos tiempos son **tiempo de simulación con órdenes automatizadas**, no mediciones de duración de jugadores humanos ni rendimiento gráfico.
