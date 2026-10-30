# Reglas y contrato del núcleo jugable

Versión de guardado: **Justina 2** (mapa versión **3**, tercera pasada de octubre de 2026; un guardado de mapa 2 se rechaza) y **Norte 1**. Motor comprobado: **Godot 4.7.2 estable**. El código autorizado de las reglas está en `scripts/game_rules.gd`; no depende de la cámara, de los modelos ni de una respuesta externa. Los tiempos, agrupaciones, porcentajes, rutas y fórmulas de este documento son diseño del juego, no datos históricos. Las etiquetas de fuente (documentado, tradición, reconstrucción, diseño) viven en `data/justina_map.json`; el diseño y la API entre pistas están en `docs/DISENO_JUSTINA.md` y `docs/CONTRATO_JUSTINA.md`.

## Justina (rediseño de octubre de 2026)

**Única fuente de números: `data/justina_map.json`**, leído una sola vez por `map_data()`. Las constantes que quedan en el código son de implementación (resolución de la malla de 4 m, cuantización del nivel a 0,05 m, límites de 400 sondas y 200 puntos por sonda, y los dos valores que el contrato fija en texto: `blend = 4` para pozos y casco, y la playa seca = `shore_high + 40`).

### Escala y estado

Unidad = 1 m; mapa de 900 x 520 m; el norte es `-z` y el río está al este. **La costa inicial está al pie de la barranca**: cresta, pie, Alameda, Plaza de Toros, batería y puesto de Liniers están 120 m más al este que en la primera versión, y los ~390 m al buque se miden desde el pie de la barranca (ver `docs/DISENO_JUSTINA.md`). El estado nuevo (ver contrato 1.2) agrega al de 0.3.0: nivel real del río (`water_level_m`, con `water_level` derivado para la UI vieja), munición, balizas, reservorio de voluntarios, orden de avance, apoyo de fuego, sondas, dos exploradores, hallazgos y estadísticas del parte. Cada grupo suma `pace`, `work`, `stumble_remaining` y `tag`.

Campos que **el contrato no listaba** y se agregaron (la UI y la Vista no deben depender de ellos): `state.defeat_cause` (`plazo|dispersos|retirada`, alimenta el título del parte), `stats.bank_s` (segundos sobre cada banco, para la ruta del parte), `stats.stumble_at` (tropiezos por pozo, para las notas del parte) y, en los exploradores, `probe_id`, `mark_done`, `mark_charged` mientras trabajan.

### Tercera pasada: qué cambió y por qué (revisión independiente del 29 de octubre)

1. **Resultado oculto por partida.** `state.hidden.picks` (sorteado con la semilla por `_roll_hidden`, con un generador propio) elige una variante por grupo de `hidden_layout` del JSON. `_apply_hidden()` calcula los hoyos *inactivos* (`_inactive`): `terrain_height_at` los salta, la malla de alturas de la partida (`_real_heights()`) recalcula solo las celdas cercanas a ellos sobre la malla estática horneada con todos, y `_touch_hazards`, `_stumble` y `_scout_stop` los ignoran. `hazard_active(id)` lo consulta. `validate_snapshot` exige una variante válida por grupo y rechaza hallazgos de hoyos inexistentes. **Qué resuelve:** el desastre de ir a ciegas ya no depende de que A\* pase o no por el pozo (antes lo protegía el azar del trazado): el pozo central y los falsos vados cubren cualquier trazado recto, y el hoyo de flanco (50 % por semilla) castiga al que sondeó solo el eje central.
2. **Recursos limitados.** `signals_left` (2 señales, 420 s cada una), `ammo_reserve` (16 de pólvora en la batería) además de 60 voluntarios y 16 balizas. **La orden de avance vale hasta llegar:** si vence con un grupo en marcha hacia el buque (`moving`/`blocked`/`stumbling` con orden `board`), el grupo se detiene (`stats.halted_by_expiry`); los que ya desmontan siguen. `plan_route` agrega la advertencia «la orden vence en N s y la marcha lleva ≈ M s».
3. **Captura activa.** `_step_counter()`: contraataques de la dotación con ventana de decisión (`state.counter`), acciones `repel` (3 de munición) y `evacuate` (10 s sin captura, +60 % de los heridos), `wounded` por grupo, retirada que se lleva a los heridos (mitad), aviso del agua que sube al 85 % del límite a pie. Estadísticas: `counter_hits|counter_repelled|counter_loss|evacuations|wounded_recovered|halted_by_expiry`.
4. **Explorador viable con riesgo decidible.** `probe_careful` (o `issue_scout(id, "probe", pts, {"cautious": true})`): donde el buque alcanza avanza a 0,7 de la velocidad y recibe la mitad de impactos. `scout_risk(id, pts, careful)` estima segundos expuestos, impactos esperados y probabilidad de baja (Poisson, peor caso: único blanco); `issue_scout` y `action_availability` lo informan. El sondeo llega hasta 1,3 m (igual que los caballos) para poder abrir el vado sur y el centro antes.
5. **Métrica de bajas y tope de guardado.** `campaign_report().loss_total_pct` = (daño del fuego + cuerpo a cuerpo + agua + caballos perdidos + contraataques) / (fuerza inicial + reclutas), siempre entre 0 y 100 (la medida anterior daba −17 % en `late_all_in` porque reunir jinetes subía la fuerza por encima de la inicial). `save_game` mide el tope en **bytes UTF-8** (antes en caracteres, y los acentos ocupan 2) y la copia de emergencia recorta también `orders` (se conservan la primera y las últimas 119) y adelgaza las `probes` (1 de cada 3 puntos más los extremos; el conocimiento es el mismo porque se unen en línea recta).
6. **Etiquetas.** El buque (hito y entidad `ship`) pasa a Reconstrucción con `tag_parts` (descripción documentada, lugar reconstruido, posición del casco diseño); la Alameda pasa a Reconstrucción; la definición de «Documentado» que ve el jugador es la del proyecto (transcripción; las fuentes divulgativas no bastan); la caballería de Pueyrredón se atribuye a Concha (15-ago-1806) y a Liniers (Archivo Pueyrredón t. I, p. 54), no solo a Obligado, con la salvedad de que el repo no cotejó el original; la bajada del Plata no se atribuye al viento en Gillespie (siete u ocho pies, causa no dicha); La Nación y Recalada se declaran «no incorporadas aún a la bibliografía S1-S8».

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

Grupo: `move`, `board`, `muster`, `resupply`, `signal_liniers`, `withdraw`, `repel`, `evacuate`, `rally`, `cancel`. Explorador: `probe`, `probe_careful`, `mark_ford`, `recall`. Globales: `distract_fire`, `retreat_all`. Todas rechazan con un motivo concreto (`action_availability` lo da sin efectos, junto con `cost_text` y `tag`).

| Acción | Costo | Efecto y rechazos principales |
| --- | --- | --- |
| `move` | marcha a `pace` | Ruta con el conocimiento actual (hasta 4 waypoints). Rechaza destino fuera del mapa, obstáculo, casco, barranca/meseta, agua conocida más honda que el límite, fondo estimado que supera el límite y ruta imposible. |
| `board` | marcha + 12 s de desmonte; luego fuego x0,3, cuerpo a cuerpo, contraataques y agua que sube | Exige `advance_authorized` vigente ("Falta la orden de avance de Liniers: señalá primero."). Al llegar al borde de la zona de abordaje (`boarding_radius_m`, 24 m) empieza a desmontar. Si la orden vence antes de llegar, el grupo se detiene. |
| `muster` | 40 s en la Plaza de Toros, **4 de munición** y **+20 de fatiga** | +20 de fuerza (tope 100) del reservorio de 60. Rechaza con fuerza completa, reservorio vacío o sin munición para armar a los reclutas. |
| `resupply` | 25 s en la batería | +16 de munición (tope 40) **de la reserva de 16** (`state.ammo_reserve`). Rechaza con el depósito lleno o la reserva agotada. |
| `signal_liniers` | 10 s en el puesto; **2 señales por partida** (`state.signals_left`) | Concede el avance **durante 420 s** (`state.advance_until`; `resources().advance_remaining_s`) y +8 de munición. Rechaza si sigue vigente o si no quedan señales; vencida hay que volver a señalar. Etiqueta **diseño**: es una regla del juego, y el evento no afirma que Güemes lleve la orden (eso es tradición no probada). |
| `withdraw` / `rally` | marcha / tiempo | `withdraw` también vale **desde el abordaje**: el grupo vuelve a montar y marcha a la playa. Vuelven a la playa seca (x ≤ `shore_high` + 40 y fuera del alcance); `rally` descansa (−0,18 fatiga/s, +0,025 fuerza/s). `rally` se rechaza fuera de la playa seca. |
| `probe` | explorador ocupado (4 de salud) | Sondea una franja de 6 m a 3 m/s en seco y 1 m/s en agua; no entra en fondo real > 1,3 m: se detiene, revela esa franja y, si lo frena un pozo, la sonda llega a su centro y el pozo pasa a `hazards_found`. Dentro del alcance del buque cada descarga lo acierta con probabilidad `0,4 x exposición`. Al ordenarlo informa el riesgo estimado (`scout_risk`). |
| `probe_careful` | igual que `probe` | Donde el buque alcanza avanza a 0,7 de la velocidad y la probabilidad de impacto se multiplica por 0,5. |
| `repel` | 3 de munición, +3 de fatiga | Solo para un grupo que aborda y mientras dura la ventana de 14 s de un contraataque: el daño baja a un cuarto y la captura no retrocede. |
| `evacuate` | 10 s sin poder de captura | Solo para un grupo que aborda con ≥ 3 de heridos: recupera el 60 % de los heridos como fuerza. |
| `mark_ford` | 1 baliza por 10 m | Exige puntos a ≤ 3 m del eje de un carril sondeado. Trabaja a 1 m/s y convierte el tramo en corredor de 16 m. "Faltan balizas (quedan N)." |
| `distract_fire` | 8 de munición | 45 s con la exposición a la mitad y +2 s entre descargas; recarga 90 s; moral de la dotación −3. |
| `retreat_all` | — | Termina la partida: derrota ordenada. |

Trabajo (`muster`, `resupply`, `signal_liniers`): el grupo marcha hasta estar a ≤ el radio del hito y entonces trabaja (`stage = working`); cambiar de orden lo interrumpe y no cobra nada.

### Tropiezo, fuego y captura

**Tropiezo.** Si un grupo avanza hacia un punto **no reconocido** cuyo fondo real supera su límite, se detiene en el borde (`stumbling`), pierde fuerza (caballos y jinetes), suma fatiga, se agrega una sonda corta, el hoyo pasa a `hazards_found` y el grupo replanifica. El costo sale del hoyo más cercano (`stumble` en el JSON): **pozo central** 45 s / +35 fatiga / −45 de fuerza; **falsos vados** de los bordes norte y sur del banco central 30 s / +25 / −32; **hoyos variantes** (flanco central y banco sur) y **canal de la ribera** 40 s / +30 / −38. Antes costaba 20 s / +12 / −3 y luego 35 s / −28: reconocer no pesaba lo bastante. Se acumula en `stats.horses_lost` y se informa en el parte. Si el punto era conocido nunca tropieza: se detiene (`blocked`) y replanifica cada 5 s. Una agrupación cuyo punto pasa a ser intransitable por la subida del río es llevada al punto firme de la playa más cercano (+10 de fatiga).

**Fuego del buque.** Cada 7,5 s (9,5 s con apoyo de fuego) contra un objetivo de los expuestos, con peso 1 para un grupo y 0,15 para un explorador. Daño `uniform(7,8; 11,9) x exposición x max(0,2; moral/100)`. La exposición es 1,0 / 0,4 / 0,15 según el ángulo respecto del eje este-oeste del buque, dentro de **265 m**; quien desmonta o aborda la recibe **x0,3** (`ship.capture.boarding_exposure_mult`). Un explorador alcanzado pierde 1 de salud con probabilidad `0,4 x exposición` (`ship.fire.scout_hit_chance`, x0,5 si sondea cauteloso): con 4 de salud cae tras ≈ 12 descargas (≈ 90 s) si es el único blanco, y el fuego de distracción y un segundo explorador lo protegen. Los números de daño, alcance y arcos son de Diseño y se calibraron contra la matriz de estrategias (ver `docs/DISENO_JUSTINA.md` 10).

**Abordaje.** Cada grupo en `dismounting` o `boarding` (`_boarding_hazards`):
- *Cuerpo a cuerpo* (solo `boarding`): pierde `0,05 x moral/100` de fuerza por segundo (`melee_loss_per_s`); `stats.melee_loss` lo acumula; la mitad queda como heridos (`wounded`).
- *Agua que sube*: si la profundidad en su posición supera el límite de un hombre a pie (1,2 m) pierde `3,0 x (exceso + 0,1)` de fuerza por segundo (`drown_loss_per_m_s`); `stats.drowned` lo acumula y se avisa cada 20 s. Antes estos grupos estaban exentos del agua.
- *Poder de captura* = `fuerza/100 x max(0,4; 1 − 0,004 x fatiga)`; la fatiga de un grupo que aborda sube 0,05/s. La captura avanza `0,55 x poder` %/s y la moral de la dotación baja `0,12 x poder` /s.
- *Contraataque* (`_step_counter`, `ship.capture.counter`): a los 30 s del primer abordaje y luego cada 55 ± 12 s (con la moral de la dotación ≥ 15) se abre una ventana de 14 s; sin `repel` los grupos que abordan reparten 22 de daño (la mitad queda como heridos) y la captura retrocede 8 puntos; con `repel`, un cuarto. Sin nadie abordando el reloj se reinicia.
- *Evacuar heridos*: `evacuate` (10 s sin poder de captura) devuelve el 60 % de `wounded` como fuerza.
- *Retirada*: `withdraw` se acepta en `boarding`; el grupo monta de nuevo (los caballos esperan en el vado), se lleva a los heridos (la mitad de lo que recupera `evacuate`) y marcha a la playa.

**Orden de avance.** `signal_liniers` fija `state.advance_until = elapsed + 420`; al vencer `advance_authorized` vuelve a `false` con un aviso **y los grupos que aún marchan hacia el buque se detienen** (los que ya desmontaron siguen). Solo hay 2 señales por partida.

Victoria: captura 100 %. Derrota: todos los grupos con fuerza ≤ 5, plazo de 1080 s o retirada general. `campaign_report()` entrega el parte (grupos, ruta usada, metros sondeados, tropiezos, caballos perdidos, pérdidas por cuerpo a cuerpo y por agua, munición, abordaje y la historia fija con sus etiquetas).

### Guardado

`snapshot()` es `state.duplicate(true)`. **Tamaño**: `save_game` escribe JSON compacto (sin tabulaciones; precisión completa), el registro del estado se recorta a los últimos `LOG_MAX = 400` acontecimientos y, si el texto supera `SAVE_MAX_BYTES = 3 000 000` **bytes UTF-8** (antes se medían caracteres: con acentos el archivo podía pasar de 3 MB sin que se notara), se guarda una copia aligerada: solo los últimos 60 acontecimientos, las últimas 119 órdenes más la primera (`SAVE_ORDERS_FALLBACK = 120`) y las sondas con 1 de cada 3 puntos más los extremos (`SAVE_PROBE_STRIDE = 3`); la partida en curso no se toca; si aun así no cabe devuelve `ERR_FILE_CORRUPT` sin escribir. `load_game` rechaza archivos de más de `LOAD_MAX_BYTES = 4 000 000`. Peor caso medido en los tests (400 sondas de 150-200 puntos, registro lleno, 45 000 órdenes y textos acentuados): ver `_test_save_size` y `_test_labels_and_save_trim`. Campos nuevos del estado: `advance_until`, `stats.horses_lost`, `stats.melee_loss`, `stats.drowned`, y de la tercera pasada `hidden.picks`, `signals_left`, `ammo_reserve`, `counter`, `units[].wounded|evac_remaining`, `scouts[].cautious` y las estadísticas de contraataques. `load_game` rechaza un guardado de Justina con versión 1 ("Este guardado es de una versión anterior del escenario Justina y no es compatible.") y uno con otra `map_version`. `validate_snapshot` comprueba tipos y rangos de todos los campos nuevos y su coherencia con el tiempo y entre sí (ver `tests/test_rules.gd`). Una diferencia con el contrato: la regla "`advance_authorized` verdadero si existe una orden `signal_liniers` en `orders`" se implementó en sentido inverso, **`advance_authorized` ⇒ existe una orden `signal_liniers` registrada**, porque la orden se registra al darla y la autorización llega después de marchar y trabajar; la regla literal rechazaría guardados legítimos tomados en ese intervalo.

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

`tests/test_rules.gd` corre el núcleo real en Godot, sin ventana, con **520 comprobaciones** (Ronda 3; 504 antes) (474 antes de la Ronda 1; 373 antes de la tercera pasada). Los resultados se escriben en `user://rules-test-results.json` (perfil aislado): **no tocan `evidence/`**. Cubren: alturas de referencia, tabla de velocidades, mareas y ventanas, conocimiento antes y después de sondear, cada acción (éxito, rechazo, costo, efecto), vigencia y límite de la orden de avance, costos del abordaje (cuerpo a cuerpo, fuego x0,3, agua que sube, retirada), geografía (costa al pie de la barranca), etiquetas y textos históricos, `data/history.json`, resultado oculto (determinismo por semilla, un solo hoyo por grupo, hallazgos y guardado), recursos limitados, contraataques/heridos/marea, riesgo del explorador, tope de guardado en bytes con recorte de órdenes y sondas, **18 estrategias x 8 semillas** con criterios de no dominancia y de que reconocer mejora el éxito, velocidad nunca superada, ausencia de grupos varados, rescate, más de 40 mutaciones de guardado que deben rechazarse (Justina y Norte), rendimiento medido y todo lo del Norte (sin cambios). `godot --headless --path . --script res://tests/test_rules.gd -- --matrix [--only=A,B] [--seed=N | --seeds=a,b,c] [--trace=NOMBRE] [--expo] [--picks]` imprime la matriz de estrategias para calibrar; `-- --skip-strategies` salta la matriz (solo para iterar: tarda varios minutos con ella).

### Estrategias simuladas (8 semillas: 3, 5, 7, 11, 13, 17, 19, 23; tres grupos, sin intervención humana)

Cada guion decide sobre lo que descubrió (p. ej. elige el carril firme según el hoyo hallado) y responde a los contraataques si su configuración lo dice. «Bajas» = `loss_total_pct` medio de todas las partidas; «bajas (vict.)», solo de las victorias. Exposición = segundos·exposición de los tres grupos en el cruce (sin contar el sitio de abordaje).

| Estrategia | Victorias | Tiempo medio de victoria | Bajas / bajas (vict.) | Exposición cruce | Notas |
| --- | --- | --- | --- | --- | --- |
| `rush_central`: `board` apenas se puede, sin reunir ni reconocer | 0/8 | — (derrota ≈ 11-12 min) | 99 % | 116 | 21 tropiezos (≈ 3 por partida): cae en el pozo central de forma determinista |
| `rush_gallop`: igual, al galope | 0/8 | — | 99 % | 108 | el galope no ayuda en agua |
| `blind_north_edge`: reunir, abastecer, señalar, fuego, pero por el borde norte sin sondear | 0/8 | — | 98 % | 189 | falso vado del borde norte y el hoyo de flanco |
| `central_center_lane`: sondea **solo el eje central** (cauteloso, con cobertura) | 0/8 | — | 98 % | 291 | encuentra el pozo, rodea por el lado que cree libre y cae en el hoyo de flanco (13 tropiezos): reconocer a medias no basta |
| `central_flank_lane`: un carril por el flanco norte (cauteloso, cobertura), elige el carril firme | **5/8** | 792 s (13,2 min) | 88 % / 81 % | 238 | las 3 derrotas son grupos dispersos; en la semilla 3 la munición llegó a 1 y no hubo 3 para rechazar contraataques |
| `central_flank_pair`: un carril por cada flanco con los dos exploradores | **8/8** | 787 s | 80 % | 229 | los dos exploradores comparten una sola ventana de cobertura: gasta menos pólvora; ≈ 78 % en 18 semillas |
| `central_hasty`: un carril, sin cobertura y sin cautela | 3/8 | 753 s | 93 % / 82 % | 231 | el explorador cae 2 de 8 veces y se apuesta al flanco |
| `central_bare`: sin reunir, abastecer, cubrir ni rechazar | 0/8 | — | 75 % | 213 | |
| `central_flank_stagger`: igual que `lane`, con 45 s entre grupos | 0/8 | — | 99 % | 245 | hipótesis: cada grupo llega solo y recibe todo el fuego (no se midió por separado) |
| `central_flank_noreply`: igual que `lane`, **sin rechazar ni evacuar** | 0/8 | — | 98 % | 238 | demuestra que responder a la captura decide la partida |
| `south_full`: sondea y marca el vado, sondea el banco, cobertura, rechaza y evacúa | **4/8** | 935 s (15,6 min; mejor 912 s) | 87 % / 75 % | 151 | las derrotas llegan tarde: el agua sube sobre el vado de abordaje |
| `south_vado_only`: sondea y marca el vado pero no el banco | 0/8 | — | 91 % | 106 | cae en el hoyo oculto del banco sur (8 tropiezos) |
| `south_bare`: solo el vado, sin reunir ni cobertura | 0/8 | — | 93 % | 109 | |
| `south_wrong_crossing`: cruza el canal sin conocer el vado | 0/8 | — | 98 % | 22 | tropieza en el canal (48 tropiezos) |
| `south_noreply`: igual que `south_full` sin responder en la cubierta | 0/8 | — | 96 % | 151 | |
| `mixed_split`: Güemes por el flanco del centro, dos grupos por el sur | 4/8 | 909 s | 87 % / 74 % | 176 | |
| `late_all_in`: sale tarde | 0/8 | — | — | — | el río ya no deja abordar |
| `passive` | 0/8 | — (derrota exactamente a 1080 s) | — | — | |

Cinco estrategias ganan en alguna semilla y cuatro (`central_flank_lane`, `central_flank_pair`, `south_full`, `mixed_split`) en la mitad o más; la que más gana (`central_flank_pair`) concentra el **33 % de las victorias (8 de 24)**; hay victorias por la ruta central (16), la sur (4) y la mixta (4). Las victorias duran entre 12,4 y 16,2 min (el plazo es de 18). Los tests lo exigen (`play_targets.dominance`): máximo **60 %** de las victorias para una sola estrategia, ≥ 3 estrategias ganando en la mitad o más de las semillas, ninguna familia (centro, sur) por encima del 75 % de sus partidas, ninguna ruta por encima del 75 % de las victorias, y que reconocer mejore el éxito.

**Reconocer mejora el éxito:** las estrategias ciegas (`rush_central`, `rush_gallop`, `blind_north_edge`, `south_wrong_crossing`) ganan 0 de 32 partidas; las que reconocen (`central_flank_lane|pair|stagger`, `south_full`, `mixed_split`) ganan 21 de 40 (52 %).

### Ronda 1 (30-oct-2026): matriz re-medida con la geometría del paquete

Cambios de balance explicados en `docs/DISENO_JUSTINA.md` sección 12 (daño del buque 8,2-12,4; exposición del abordaje 0,12; cuerpo a cuerpo 0,03/s; contraataque 16 de daño y 9 % de retroceso; bajadas de 40 m). `tests/test_rules.gd`: **504 comprobaciones, 0 fallas** (474 antes; 8 nuevas en `_test_victory_quality` y 22 en `_test_package_data`). 18 estrategias x 8 semillas de calibración (3, 5, 7, 11, 13, 17, 19, 23):

| Estrategia | Victorias | Tiempo medio de victoria | Bajas / bajas (vict.) | Exposición cruce |
| --- | --- | --- | --- | --- |
| `rush_central` / `rush_gallop` / `blind_north_edge` / `south_wrong_crossing` | 0/8 cada una | — | 99 / 99 / 98 / 100 % | 111 / 106 / 188 / 47 |
| `central_center_lane` | 5/8 | 717 s | 76 % / 63 % | 312 |
| `central_flank_lane` | **8/8** | 738 s | 58 % | 238 |
| `central_flank_pair` | **8/8** | 742 s | 56 % | 228 |
| `central_hasty` | **8/8** | 717 s | 57 % | 231 |
| `central_bare` | 0/8 | — | 73 % | 210 |
| `central_flank_stagger` | 0/8 | — | 100 % | 246 |
| `central_flank_noreply` | 8/8 | 784 s | 68 % | 238 |
| `south_full` | **8/8** | 900 s (15,0 min) | 55 % | 151 |
| `south_vado_only` / `south_bare` | 0/8 | — | 99 / 97 % | 127 / 148 |
| `south_noreply` | 7/8 | 932 s | 67 % / 63 % | 151 |
| `mixed_split` | 3/8 | 887 s | 78 % / 58 % | 205 |
| `late_all_in` / `passive` | 0/8 | — | 0 % | 0 |

55 victorias en 144 partidas; la que más gana concentra el 14,5 % de las victorias (8 de 55). Tiempos de victoria: 11-13 min por el centro y 14,5-16 min por el sur (objetivo `recon_then_south` < 960 s: mejor caso 865 s). Cohorte de 12 estrategias razonables: **55/96 = 57 %** (calibración) y **79/144 = 55 %** (12 semillas de validación: 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73). Bajas de las 134 victorias de la cohorte: mediana 60 %, máxima 75 % con defensa y 81 % sin defensa, 2 por encima de 80 %. Antes de la Ronda 1: 74-86 % de bajas en las victorias.

**Cómo leer estas cifras.** Los guiones juegan con información perfecta del mapa y sin errores de ejecución: ganan casi siempre cuando el guion es completo. La cohorte incluye guiones recortados (sin cobertura, sin reunir, sin sondear el banco) que simulan a quien juega mal o a medias; su tasa es un proxy del 40-60 % de chance de una persona razonable, **no una medición con personas**. El balance sigue siendo un precipicio ante el daño del buque (se vio en las iteraciones: con 6,6-10,0 de daño las `noreply` ganan 8/8 y con 7,8-11,9 los pírricos vuelven).

### Lo que cumple y lo que no cumple el balance objetivo (`play_targets`)

- **Cumple**: (1) el desastre a ciegas es determinista (el pozo y los falsos vados cubren cualquier trazado recto) y el hoyo oculto de flanco y el del banco sur castigan al que reconoce a medias; (2) ninguna estrategia concentra más del 60 % de las victorias y hay trade-offs reales: el centro gana antes (media 792 s contra 935 s), pero se expone 1,58 veces más al fuego de cruce y pierde más fuerza; el sur es lento y exige vado marcado y banco sondeado; la mixta reparte; la señal a Liniers (2 × 420 s) y la pólvora (44 en total) obligan a elegir; (3) la ruta sur gana en 912 s en su mejor semilla (< 960 s) con exposición centro/sur 1,58 (≥ 1,4); (4) en la captura hay un contraataque cada ≈ 55 s con 14 s para responder, heridos que evacuar y el agua que sube al final: sin responder se pierde (`*_noreply`); (5) el explorador del centro ya no cae siempre (`scoutsL` 0-4 de 8 con sondeo cauteloso) y el riesgo de baja se muestra antes de ordenar; (6) `loss_pct` no es negativa y el guardado mide bytes y recorta órdenes y sondas.
- **Duración**: 12,4-16,2 min para las victorias. Las derrotas por plazo duran 18 min; las rápidas (≈ 9-14 min) son grupos dispersos.
- **Qué sigue sin ser ideal**: (a) con 8 semillas el ruido es grande, el balance es muy sensible al daño del buque (7,5 → 8,2 de daño mínimo lleva la ruta central de ~100 % a ~15 % de victorias) y `central_flank_pair` gana 8/8 (≈ 78 % en 18 semillas): **ninguna estrategia gana más del 60 % de las victorias de la matriz, pero esa estrategia gana más del 60 % de sus propias partidas**; (b) la ruta sur gana solo la mitad de las semillas porque tarda hasta 960-1000 s y el agua empieza a subir: su media (935 s) no cumple el objetivo, que solo se exige al mejor caso; (c) el sur no es más barato en bajas que el centro cuando gana (75 % contra 81 %): la diferencia de seguridad está en la exposición del cruce, no en el sitio de abordaje; (d) todo se calibró con guiones, no con personas.

### Cambios de la segunda pasada respecto del contrato (a confirmar por el arquitecto y las otras pistas)

1. **Geografía**: toda la tierra al este del río original se corrió +120 m (ver `docs/DISENO_JUSTINA.md` 1.1). Las coordenadas del río (bancos, vados, casco, punto de abordaje, buque) **no cambiaron**. Los scripts de recorrido y las pruebas de interfaz que usan coordenadas de playa (x < 200) o de hitos de la meseta hay que actualizarlos.
2. **Línea de tiempo**: `drop 60-450 s`, `hold hasta 960 s`, `rise hasta 1080 s`, plazo `1080 s`. Todo lo que cablee tiempos (barra del río, tests de la UI) debe leerlos de `tide_marks()`.
3. **Nuevos campos**: `state.advance_until`, `state.stats.horses_lost|melee_loss|drowned`, `resources().advance_remaining_s`, `campaign_report().horses_lost|melee_loss|drowned`, `ship.capture.melee_loss_per_s|boarding_exposure_mult|drown_loss_per_m_s`, `ship.fire.scout_hit_chance`, `actions.muster.fatigue_gain|ammo_cost`, `actions.signal_liniers.valid_s`, `stumble` en el canal. `map_version` = 2.
4. **Etiquetas**: `signal_liniers` pasa de `tradicion` a `diseno`; la batería Abascal, el campamento de Pueyrredón y la reserva de caballería de Pueyrredón pasan de `documentado` a `reconstruccion`; el grupo de Güemes se titula "Vanguardia · Güemes (tradición)". La UI que agrupa por etiqueta lo recoge sola.
5. **Orden de avance con vigencia** (420 s desde la Ronda 1; antes 300 s) y **retirada desde el abordaje**: la UI debe mostrar `advance_remaining_s` y permitir `withdraw` a un grupo que aborda.
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

Ninguna cifra se jugó con personas; las estrategias están scripteadas con conocimiento del mapa que un jugador no tiene al principio, y los tiempos de victoria dependen de ese guion. **Vista y UI tras la integración (2026-10-29):** `main.gd` ya apunta «Sondeo cauteloso» como el sondeo normal (antes el botón no hacía nada para exploradores); `repel` y `evacuate` se dan con los botones genéricos de grupo. Siguen sin mostrarse en el HUD `signals_left`, `ammo_reserve`, `state.counter` ni el riesgo estimado del sondeo. `tools/ui_qa.gd` pasa 61/61 en 1280×720, 1920×1080 y 2560×1440, y `tools/justina_playthrough.gd` se reescribió con las estrategias de `tests/test_rules.gd` sobre la escena real (5 estilos ganan en 3 semillas, la derrota aparece con `rush_central`, `late_all_in`, etc.) más una partida por clics y teclas reales (`ui_real`, `central_flank_pair`): gana 2 de 3 semillas (5 y 11) y pierde la semilla 1806 por poco (captura 90 %). Las fuentes de La Nación y Recalada, y las de Concha y Liniers (Archivo Pueyrredón), no se cotejaron con sus originales; Recalada ya figura como S10 en `docs/historia/FUENTES.md`. El Norte no cambió y sus pruebas pasan como antes.

Estos tiempos son **tiempo de simulación con órdenes automatizadas**, no mediciones de duración de jugadores humanos ni rendimiento gráfico.

## Ronda 1 (30-oct-2026): reglas tocadas

- `game_rules.gd::_bed_warp(x, z, toe_x)` y las claves `warp` / `warp_cfg` de `_S_geo`: desplazamiento del perfil base según `bed_warp` del JSON (si falta, cero). `terrain_height_at` usa `_interp(base, x - warp)`. La estimación del jugador (`_base_height`, perfil «suave» sin bancos) no usa el warp: el jugador estima un perfil liso y el fondo real tiene meandros.
- Textos de eventos: «piezas del Retiro» en lugar de «batería Abascal» (el id `bateria_abascal` no cambia); la historia fija marca Reconstrucción para la caballería de Pueyrredón.
- Sin cambios de estado guardado ni de `schema_version`; `map_version` pasa de 3 a 4 (partidas guardadas de la versión 3 siguen el mismo esquema).

## Ronda 2 (30-oct-2026): reglas tocadas

- **Único cambio de reglas:** `ship.fire.damage_min/max` 8,2 / 12,4 → 7,6 / 11,5 (-7 %), en `data/justina_map.json` (`map_version` 5). `game_rules.gd` no cambió: ningún código nuevo, solo datos.
- **Tests (`tests/test_rules.gd`):** el tope `max_victory_loss_pct` (75 %) se aplica a las líneas confiables (ganan la mitad o más de sus partidas, calibración + validación); las marginales se acotan con `play_targets.victory_loss.marginal_line_max_pct` (92 %). Se corrigió además el test de la nota del tiempo, que exigía la frase errónea «no atribuye el viento a Gillespie» (Gillespie pp. 35-36 sí lo liga). Resultado: 505 comprobaciones, 0 fallos.
- **Medición** (18 estrategias x 8 semillas + 12 de validación; detalle y comparación con -15 % en `DISENO_JUSTINA.md` 13): cohorte 59 % / 59 %, bajas medianas 54 % (antes 60 %), confiables ≤ 64 %, victorias en 11,2-16,3 min, ciegas / pasiva / tardía 0, ninguna estrategia por encima del 14 % de las victorias.
- No se tocó el escenario Norte.



## Ronda 3: condición del río por partida

`hidden.tide` (id de `time.variants`) se sortea con la semilla después de los hoyos y se guarda con la partida; `tide_at`, `tide_marks` y `ford_window` leen los hitos de la variante (`_time_cfg()`), así que el HUD, la barra de tiempo y los avisos la reflejan sin cambios. Un guardado sin la clave se lee como `normal`. Ver `docs/DISENO_JUSTINA.md` 14.

## Ronda 5 (30-oct-2026): ajustes de equilibrio de Justina

Solo datos: `ship.fire.damage_min/max` 7,6 / 11,5 → 8,06 / 12,19 y `time.variants[lenta]` con la bajante a 75-470 s. `game_rules.gd` solo cambia el aviso de guardados de versión anterior (v1 y v2). Matriz re-medida: 542 comprobaciones sin fallos, cohorte 50 % / 50 %, bajas medianas 53 %, máximo con defensa 68 %. Detalle y comparación en `docs/DISENO_JUSTINA.md` 16.3. Escenario Norte sin cambios.

## Ronda 9 (30-oct-2026, pista `mapa_reglas`): ciclo de campaña, partida comprimida y balance de «jugador humano»

Directriz del usuario que manda: la fidelidad histórica es solo una guía; hay que poder jugar y que sea entretenido; si perdés, volvés a jugar con lo que aprendiste; hay que ganar para pasar al segundo escenario. El Norte no se tocó. `map_version` 7 → **8** (un guardado de partida anterior se rechaza con aviso; el progreso de campaña es otro archivo).

### Qué se implementó (plan de diversión, `docs/PLAN_DIVERSION_JUSTINA.md`)

| Cambio | Estado | Dónde |
|---|---|---|
| **C1** Mundo fijo hasta ganar | Hecho (lógica y pruebas); la UI debe llamar `CampaignProgress.world_seed()` en lugar de sortear en `main.gd:432` | `scripts/campaign.gd` |
| **C2** Diario del Bañado | Hecho (datos, persistencia, marcas `confirmed:false`); falta dibujarlo (UI/visual) | `campaign.gd`, `rules.diary_marks` |
| **C3** Parte de derrota que enseña | Hecho el texto (causa ≤ 140 car., consejo, pista desde la 2.ª derrota); falta la pantalla | `campaign.record_result()`, JSON `campaign.defeat_causes` |
| **C4** «Desde el cruce» | **No hecho** (exige tocar el flujo de `main.gd`; el plan lo marcaba opcional) | — |
| **C5** Río y partida comprimidos | Hecho: bajante 0:30-4:10, mínimo hasta 11:40, plazo duro **14:00** (el plan pedía 13:00; con 13:00 la ruta sur no llegaba), vado abre ≈ 3:30 en todas las variantes, variante «breve» eliminada | JSON `time` |
| **C7** (reglas) Fuego telegrafado | Hecho: aviso con punto apuntado y cuenta regresiva (3 s; 4 s la andanada fuerte, cada 6.ª ≈ 45 s, ×1,5); el buque apunta a donde estará el grupo, así que quedarse quieto o seguir la marcha recibe el golpe y moverse más que el radio (9 m / 10 m) lo esquiva | `_volley_step`, `ship.fire.telegraph` |
| **C8** Contraataques con consecuencias | Hecho: aviso a 5 s, ventana de 12 s; rechazar cuesta 3 de munición y 6 de fatiga y deja la captura en −5; no contestar: −25 de captura, 24 de daño repartido y el grupo más débil se quiebra | `_step_counter`, `ship.capture.counter` |
| **C9** Rutas con identidad | Hecho: premio de captura central ×1,2 / sur ×1,05 / mixta ×1,1; la sur moja 4 de pólvora al cruzar el vado; las variantes de misión inclinan cuál conviene | `route_premium`, `south_powder` |
| **C10** Variantes de misión | Hecho: 4 (costado fuerte al sur, munición escasa con voluntarios, viento fuerte, buque nervioso) sorteadas con la semilla, con generador propio (no se correlaciona con el fondo); aviso en el segundo 4 | `mission_variants`, `rules.mission()` |
| **C11** Moral y quiebre gradual | Hecho: ≤ 25 de fuerza = «quebrado» (lento ×0,7, no suma captura), se rehace al pasar de 38; la derrota por dispersión llega cuando todos están quebrados o dispersos | `outcome.shaken` |
| **C12** Último esfuerzo y medallas | Hecho: una vez por partida, +30 de fuerza a cada grupo (cuesta 40 de voluntarios); con todos quebrados y captura ≥ 30 % se abre una ventana de 15 s en lugar de perder en el acto. **Decisión de diseño distinta de la del plan:** no convierte la derrota en victoria bronce (eso baja el valor de ganar); si la ventana vence, el parte dice «estuviste a un paso» | `last_effort()`, `outcome.last_effort`, `outcome.medals` |
| **C18** Presión de reloj | Hecho: punto sin retorno **11:00**; avisos de Liniers a los 7:00, 9:00 y 10:30; derrota por inacción si nadie salió a cargar | `time.no_return_s` |
| **C19** Eventos de campo | Hecho: 8 eventos programados (aviso de variante, tres mensajes de Liniers, mensajero con elección pólvora/voluntarios, pista del vecino sobre el flanco, mínimo del río, refuerzo de voluntarios); nunca más de 90 s sin evento en los primeros 5 min (prueba) | `field_events` |
| Ayudas en escalera | Hecho: derrota 2 → pista; derrota 3 → «Baqueano» (revela el hoyo del flanco, +8 de munición); derrota 5 → «Bajante generosa» (+60 s). Opcionales y marcadas en el parte; quitan el oro | `apply_assist` |

### Cómo se midió (y qué NO prueba)

- `tests/test_rules.gd`: **638 comprobaciones** (antes 520), todas verdes; las de balance se reescribieron para la partida comprimida (victorias de 7,5 a 14 min con mediana entre 9 y 12; pasividad = derrota por inacción a los 11:00 con ≥ 2 avisos; la mejor línea de cada ruta rinde parecido en 20 semillas; cohorte «razonable» 25-50 %).
- `tests/test_rules.gd -- --matrix --bymission [--seeds=...]`: matriz estrategia × semillas con desglose por variante de misión. `-- --human --n=N --attempts=K --base=S`: **simulación de jugador humano**.
- **El «jugador humano» es un modelo inventado.** Tres perfiles (experto, promedio, novato) cometen errores con probabilidades que yo elegí (no sondear el flanco, no rechazar un contraataque, gastar pólvora, salir tarde, no esquivar el aviso, no usar el último esfuerzo) y mejoran ×0,72 por derrota (el diario enseña; desde la 2.ª derrota saben qué flanco tiene el hoyo; aceptan baqueano y bajante con 70 %). Las tasas que salen **dependen de esas probabilidades inventadas**: son una guía de orden de magnitud, no un resultado. Si modelo y persona discrepan, manda el playtest del usuario (3 partidas), que **no se hizo**.
- Muestras: celdas por guion con 100 semillas; humano con 60 mundos × hasta 6 intentos por perfil. El intervalo de confianza (95 %, binomial) de un 25 % con n = 60 es ±11 puntos: ninguna meta de la tabla de abajo se afirma con más precisión que eso.

### Resultados medidos (APPDATA aislado; 100 semillas por celda, 1001-1100; 60 mundos × 6 intentos por perfil humano)

**Guiones (jugador que conoce el mapa).** Victoria por variante de misión (n por variante ≈ 24-26):

| Guion | Total | buque nervioso | viento fuerte | munición escasa | costado fuerte al sur | Victoria media | Bajas en victoria |
|---|---|---|---|---|---|---|---|
| `central_flank_pair` (centro, sondea los dos flancos) | **85 %** (85/100) | 100 % | 62 % | 77 % | 100 % | 10,3 min | ≈ 58 % de la fuerza |
| `south_full` (sur completo) | **66 %** (66/100) | 100 % | 100 % | 38 % | 31 % | 12,2 min | ≈ 38 % |
| `central_hasty` (centro apurado, sin cobertura) | 48 % | 100 % | 0 % | 15 % | 77 % | 10,0 min | ≈ 57 % |
| `mixed_split` | 28 % | 83 % | 21 % | 0 % | 12 % | 11,9 min | ≈ 46 % |
| `central_flank_noreply` (no rechaza contraataques) | **0 %** | 0 % | 0 % | 0 % | 0 % | — | derrota media ≈ 10 min |
| `rush_central` (a ciegas) | **0 %** | 0 % | 0 % | 0 % | 0 % | — | derrota a los 5:30-6:50 |
| `passive` / `late_all_in` | **0 %** | — | — | — | — | — | derrota por inacción a los 11:00 |

Lectura: (a) la diferencia entre las mejores líneas de cada ruta es de **19 puntos** (meta del plan: ≤ 20); (b) **cada ruta gana en alguna variante**: el centro en «costado fuerte al sur» (100 % contra 31 %), el sur en «viento fuerte» (100 % contra 62 %); (c) no defender el abordaje o ir a ciegas pierde siempre; (d) la victoria típica dura 9-12 min (meta del plan: 9-12). Antes de la ronda el mejor guion central ganaba 11 de 12 semillas y la familia central ≈ 62 % de todas las victorias de la matriz.

**Jugador humano simulado (modelo inventado, ver arriba).**

| Perfil | Gana al 1.er intento | Acumulado al 3.º | al 5.º | Intentos para ganar (media) | Victoria mediana | Derrota mediana | Medallas del primer triunfo |
|---|---|---|---|---|---|---|---|
| experto | 100 % | 100 % | 100 % | 1,0 | 11,7 min | — | bronce 20, plata 30, oro 10 (de 60) |
| promedio | **17 %** | **73 %** | **97 %** | 2,8 | 9,8 min | 12,6 min | bronce 49, plata 7, oro 4 |
| novato | **8 %** | **40 %** | **93 %** | 3,6 | 10,0 min | 11,1 min | bronce 53, plata 5, oro 0 |

Contra las metas del plan (sección 5): «ganar al 3.er intento 60-80 %» **sí** (promedio 73 %); «al menos una victoria en 5 intentos ≥ 90 %» **sí** (97 % y 93 %); «oro 10-20 % del guion fuerte» **sí** (17 %); «victoria al 1.er intento 25-40 % (humano promedio)» **no** (17 %, IC 95 % ≈ 8-28 %); «novato 10-25 %» **no** (8 %, IC ≈ 3-18 %). **No ajusté las probabilidades del modelo para acertar esas metas**: eso sería circular (el crítico del plan lo señaló). Las metas de primer intento quedan abiertas hasta el playtest del usuario; la dificultad de entrada se corrige con datos (`mission_variants`, `counter.damage`) sin tocar código.

Con baqueano/bajante (ofrecidos desde la 3.ª/5.ª derrota) terminaron ganando 27 de los 60 mundos del perfil promedio y 45 de los 60 del novato, y esas victorias no llevan oro: la escalera de ayuda sostiene a quien se estanca. Causas de derrota del modelo: dispersión 90-94 %, plazo 5-10 %, inacción ≈ 1 %.

**Qué cambió respecto de la ronda anterior (misma semilla y política):** plazo 18:00 → 14:00; vado 6:19 → 3:30; victoria central 12-13,5 → 8,7-12 min; el parte de derrota nombra una causa en lenguaje de jugador; el contraataque sin contestar pasó de −9 a −25 de captura (con rechazo, −5); la ruta sur gana 66 % de las veces (antes perdía por tiempo en la variante «breve»).


### Qué no se logró (a la vista)

- **Derrota típica ≤ 9 min (mediana ≤ 7): NO.** Las derrotas por dispersión llegan tarde (mediana 11-12,6 min en el modelo): la marcha ocupa los primeros ≈ 7 min y la caída posterior es gradual. Probé quiebre a 32 y cuerpo a cuerpo más duro: acortan ≈ 1 min y vuelven la victoria más cara. Queda abierto: la UI puede ofrecer «Retirarse y reintentar» (Esc → dos clics) apenas la captura se estanca.
- **C4 y todo lo visual/UI** (ver CONTRATO 13.6).
- Las cifras de bajas por ruta (central ≈ 55-60 %, sur ≈ 40-45 %) cumplen «no pírrica» (mediana ≤ 65 %), pero la central sigue siendo cara por diseño.
- No se midió con personas ni en la escena con ventana más allá del recorrido automático (`tools/justina_playthrough.gd`).

### JEV / TypeSafe

`has_credentials() = true` (hay `user://jev.cfg`; no se leyó ni se imprimió su contenido). Se intentó una consulta real (elegir ruta, observación sintética sin datos personales): **expiró a los 2 s** y el cliente devolvió la alternativa local (`source=local_fallback`, `reason=timeout`). **No hay una decisión en vivo verificada** y ninguna cifra de esta ronda depende de Jev (Justina no lo usa; es del Norte).

## Ronda 2 de diversión (30-oct-2026, pista `mapa_reglas`): primer intento ganable, aprendizaje que se nota y sin estrategia dominante

Directriz que manda (usuario): la fidelidad histórica es solo una guía; hay que poder jugar y que sea entretenido; si perdés, jugás de nuevo; el Justina es tiempo real con pausa; el Norte no se toca. Todo lo de abajo es **diseño de juego** (rótulo `diseno`), no historia. Interfaz para `ui_feel` en `docs/CONTRATO_JUSTINA.md` sección 15.

### Qué cambió
| Problema (QC / jugador) | Cambio | Dónde |
|---|---|---|
| Primer intento casi siempre perdido (promedio 31 % / 19 %, novato 0 %) | **Ventaja de la experiencia** por nivel de racha de derrotas (0 = primer intento): menos fuego del buque, tropiezos suaves, captura más rápida, contraataques más suaves; el sargento rechaza solo los primeros contraataques (1 en el nivel 0-1, 2 desde el 2). Sube de nivel con cada derrota, se avisa en el segundo 0 y en el parte, nunca es oculta | `campaign.mercy` (JSON), `rules.set_mercy()`, `CampaignProgress.begin_attempt()` |
| Derrotas aplastantes sin causa clara (93 % de bajas, 0 % de captura) | Mismo colchón + `ship.fire.route_mult` + contraataque sin responder ya no rompe al grupo más débil (`shake_on_unanswered` = false) y cuesta menos | JSON |
| Derrotas que se arrastran | `outcome.doomed`: poca fuerza total (< 70), captura < 60 % y sin último esfuerzo posible → derrota inmediata (causa `dispersos`) | `rules._is_doomed()` |
| Estrategia dominante (centro ganaba 100 %, sur 83 % con la ayuda de la ventaja base) | `ship.fire.route_mult` central ×1,12 / sur ×0,95 (centro rápido y caro, sur lento y barato) y la variante «viento fuerte» deja el centro +6 % más a la vista: el mejor guion de cada ruta pierde en una variante y gana en otra | JSON |
| Cargar exige señalar a Liniers (burocracia) | **Carga sin orden** (`issue_order(..., {"on_own": true})`): captura −20 %, sin oro, avisada. La señal queda como bonus | `rules.on_own_charge_check()` |
| «Desde el cruce» pendiente (C4) | Punto de control automático a los 200 s + `restore_checkpoint()` (cuenta el intento y fija la ventaja con la racha actual) | `scripts/campaign.gd` |
| Medalla incoherente, plural «pozo(s)», textos | `medal_label` de esta partida + `record_line`, qué FALTA para la próxima medalla, plurales correctos, «Esta vez:» en el diario, guardado que pisa archivo existente | `campaign.gd`, JSON |
| Oro inalcanzable / siempre alcanzado | Oro: bajas < 30 %, antes de 12:10, sin ayudas ni carga sin orden (hoy solo la ruta sur lo alcanza); plata < 55 % + vado marcado | `outcome.medals` |
| Victoria pírrica | Mediana de bajas de las victorias razonables 51 %; solo 2 de 122 victorias pasan del 80 %; máximo con defensa 78 % (antes 83 %; la prueba exige ≤ 80 %) | `melee_mult`, `route_mult` |

### Resultados medidos (APPDATA aislado; `tests/test_rules.gd -- --human --n=32 --base=9100|31000`, 6 intentos por mundo, 32 mundos × 2 bases = 64 mundos por perfil)
Modelo de jugador **inventado** (errores y ayudas descriptos en la ronda 9); no son personas. Intervalo aproximado ±12 puntos por base.

| Perfil | Gana al 1.º (antes → ahora) | Acumulado al 3.º (antes → ahora) | Al 5.º | Intentos medios para ganar |
|---|---|---|---|---|
| Experto | 100 → 100 % | 100 % | 100 % | 1,0 |
| Promedio | 31 / 19 % → **63 / 44 %** (media 54 %) | 88 → **100 / 100 %** | 100 % | 2,3 → **1,5-1,8** |
| Novato | 0 / 0 % → **25 / 13 %** (media 19 %) | 25 / 31 % → **91 / 97 %** | 100 % | 4,1 → **2,2** |

Matriz de estrategias (40 semillas, `--matrix --bymission`): `central_flank_pair` 38/40, `central_flank_lane` 36/40, `south_full` 35/40, `mixed_split` 19/40. Por variante: el centro gana más rápido pero es el que más flaquea con «viento fuerte» (7/9 y 6/9, el sur 9/9); el sur pierde con «costado fuerte al sur» (4/9, el centro 9/9). Ninguna ruta supera a otra en más de 20 puntos en el total y cada una es la mejor en al menos una variante; la línea del centro sigue siendo algo más fiable (95 % vs 88 %) pero paga 60 % de bajas contra 35 % del sur. Las estrategias sin reconocer o sin responder contraataques siguen siendo mucho peores (`central_bare` 0 %, `central_flank_noreply` ≈ 50 % de lo que gana el mismo guion respondiendo).

### Lo que NO se logró / límites honestos
- El promedio al primer intento (54 %) queda por encima de la meta del plan (25-40 %): la directriz del usuario («tiene que ser jugable y entretenido») pesó más; si una persona real lo siente fácil, bajar `campaign.mercy.levels[0].fire_mult` de 0,96 a 0,92 vuelve el primer intento ~15 puntos más difícil. El novato llega al 3.º intento en casi todos los mundos: el aprendizaje se nota, pero **la tasa real de personas no se midió** (no hubo playtest humano).
- La derrota mediana sigue en ~11-12 min a ×1 (≈ 3 min a ×4): el corte `doomed` solo actúa cuando la fuerza total ya es baja; una derrota por desgaste con 60-90 % de captura sigue llegando tarde. Mitigación de UI: ×4 y «Reintentar» en cualquier momento.
- «Mixta/reserva» sigue siendo la línea más floja (≈ 40 %): no es la mejor en ninguna variante.
- Las cifras de oro/plata/bronce son de este modelo; el oro hoy es casi exclusivo de la ruta sur con un guion limpio (el experto lo logra ~65-70 %).
- JEV/TypeSafe no se usó en esta pista (reglas puras): no hay prueba en vivo ni se declara ninguna.

### Verificación de esta ronda (APPDATA aislado, worktree `div2-mapa_reglas`)
- `tests/test_rules.gd` completo: 667 comprobaciones, 0 fallas (incluye la cohorte: victoria razonable 51 % en calibración y validación, bajas medianas 52 %, 2 de 122 victorias sobre 80 %).
- `tests/test_integration.gd` (perfil limpio): 265 comprobaciones, 0 fallas. Con un perfil sucio falla «tarjeta inicial corta» por el texto de ayudas/pistas acumuladas: aislar siempre el perfil.
- `tests/jev_contract_test.gd`: 15 comprobaciones, 0 fallas (`live_api_tested: false`: solo contrato offline; no se probó JEV en vivo).
- `tools/justina_playthrough.gd`: 15 victorias de 24; `ui_real` con clics reales gana las 3 semillas (1806, 5, 11) en esta corrida (antes 1806 perdía y 5 alternaba). Una corrida no prueba estabilidad.
- No se corrieron `ui_qa.gd`, `audio_runtime_test.gd` ni `benchmark.py` (no hay cambios de UI, audio ni render en esta pista).

## Ronda 3 (pista mapa_reglas, directriz de diversión): reintento, desafíos, balance humano

Rama `div3-mapa_reglas`. Modelo inventado (no personas): todas las tasas salen de `tests/test_rules.gd --human --n=120 --base=900` (perfiles experto, promedio y novato con errores que bajan ×0,72 por derrota) y de `--matrix` con 24 semillas. Si el modelo y una persona discrepan, manda la persona.

### Qué cambió
- **Ventaja del primer intento**: `campaign.mercy.levels[0]` fuego del buque 0,96 (se mantiene el colchón) y la variante `buque_nervioso` pasa de moral 55 a 80: con 55 la dotación pegaba tan flojo que la variante «difícil» era la más fácil (promedio 83 % vs ~29 % de las otras). Ahora las cuatro variantes dan al jugador promedio entre 29 % y 47 % al primer intento.
- **Mixta con pincel propio**: dos grupos abordando a la vez, uno por el centro y otro por el sur, multiplican el poder de captura (`ship.capture.pincer_mult` = 1,4) y avisan «¡Pinza!». El premio `route_premium.mixta` (1,15) solo cuenta si un mismo grupo cruzó ambos bancos. Dividir sigue siendo la ruta difícil (exige coordinar tiempos), pero ya no está muerta.
- **Victoria al borde viable**: `play_targets.max_victory_loss_pct` 80 → 90; apurarse (`central_hasty`) puede ganar, caro y raro (la cohorte exige que menos del `share_over_80_max` de victorias pasen de 80 % de bajas).
- **Oro coherente**: `outcome.medals.gold.max_mercy_level` = 1. Con 2 o más derrotas seguidas en el río la mejor medalla es plata y el parte lo dice («el oro queda para quien gana en los dos primeros intentos de un río»). Se acabó «Oro: sin ayudas… No se puede mejorar» junto a «ganaste con la ventaja de la experiencia».
- **Desafíos opcionales y puntaje** (`outcome.objectives`): 6 desafíos (menos de 35 % de bajas, antes de 9:30, sin pozos, vado marcado, sin ayudas ni ventaja, «atreverte»: cargar sin la orden de Liniers). `campaign_report()` devuelve `objectives` [{id,label,done}], `objectives_done` y `score` (1000 + segundos que sobran + 6 × % de tropa en pie + 250 por desafío − 200 por ayuda; 0 si no ganó). El perfil guarda `best_score` y `objectives_done` acumulados.
- **«Reintentar ya»** (`outcome.retry_suggest`, `Rules.retry_suggestion()`): sugerencia, NO corte. Con menos de 115 de fuerza total y menos de 55 % de captura pasado 4:00, la interfaz puede ofrecer reintentar. Un corte automático más agresivo (`doomed.heavy_*`, queda en 0 = apagado) mataba partidas recuperables, por eso se dejó como botón opcional.
- **Reintento ordenado**: `CampaignProgress.retry_options()` devuelve los botones listos (primero «Reintentar desde el cruce» si hay punto de control de este río), `attempt_in_world()` / `is_retry()` evitan el «Intento 2» falso de la tarjeta inicial.
- `tests/test_rules.gd` limpia sus archivos de `user://` al terminar (ya no ensucia el perfil de `test_integration`).

### Medición (APPDATA aislado)
| Perfil | Gana al 1.º | Acum. 3.º | Acum. 5.º | Derrota mediana | Meta |
|---|---|---|---|---|---|
| experto | 100 % | 100 % | 100 % | - | gana siempre |
| promedio | 38 % | 99 % | 100 % | 12:23 | 30-45 % al 1.º |
| novato | 8 % | 94 % | 100 % | 9:22 | gana antes del 5.º |

Por variante (promedio, 1.er intento): viento fuerte 11/30, buque nervioso 13/30, munición escasa 14/32, costado sur 8/28. «Reintentar ya»: avisa en 70 de 92 derrotas del promedio, ahorra una mediana de 121 s; 8 de 120 victorias lo habrían sugerido en algún momento (falso positivo aceptado: es una sugerencia).

Matriz de 24 semillas (victorias): `central_flank_lane` 21, `central_flank_pair` 21, `south_full` 21, `south_noreply` 16, `central_hasty` 8, `mixed_split` 10, `central_flank_noreply` 7, `south_vado_only` 7, `central_flank_stagger` 2, el resto (a ciegas, pasiva, tardía) 0. Por variante: el centro rinde mejor con costado sur (5/5) y el sur con viento fuerte (7/7) y sale mal con costado sur (2/5): cada ruta es la mejor en al menos una variante, ninguna domina.

### Límites honestos
- La derrota mediana sigue en 9 a 12 min a ×1: la mayoría de las derrotas son agonías largas (quiebre → dispersión) y recortarlas por regla mata partidas recuperables. El ciclo corto se logra con el **punto de control** («Reintentar desde el cruce», ~3:20 en adelante) y con la sugerencia «Reintentar ya»: **falta cablearlos en la interfaz** (ver `docs/CONTRATO_JUSTINA.md`, sección «Pendiente de ui_feel»).
- Sin sesión humana: los porcentajes son del modelo. JEV: sin clave en este entorno, solo `jev_contract_test` (contrato offline).
