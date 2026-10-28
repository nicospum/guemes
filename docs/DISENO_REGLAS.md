# Reglas y contrato del núcleo jugable

Versión de guardado: **1**. Motor comprobado: **Godot 4.7.2 estable**. El código autorizado de las reglas está en `scripts/game_rules.gd`; no depende de la cámara, de los modelos ni de una respuesta externa. Los tiempos, agrupaciones, porcentajes, rutas y fórmulas de este documento son diseño del juego, no datos históricos.

## Recorridos completos

### Justine: preparar, cruzar, desmontar y capturar

Hay tres agrupaciones controlables. La primera representa a Güemes dentro de la recreación de una atribución tradicional. Las otras dos se muestran como voluntarios de la ribera y reserva; sus identificadores internos no atribuyen a Arias ni a otro comandante una presencia en 1806.

Las órdenes **Banco directo** y **Rodeo sur** se pueden dar desde el inicio. Las agrupaciones avanzan a una posición de preparación y esperan allí si el agua todavía impide cruzar. Cuando su recorrido resulta transitable, continúan automáticamente. Así se permite una decisión inmediata sin exigir que el jugador espere la bajante para empezar a ordenar.

La ruta central reduce distancia y tiempo, pero expone más a la artillería. El recorrido del sur pasa por puntos intermedios propios y no se acorta automáticamente hacia el centro. La menor exposición conserva fuerzas a cambio de llegar después. También hay movimiento libre a un destino válido, reagrupación, abordaje y cancelación.

El río comienza en `0,95`, baja desde el segundo 40 hasta `0,05` en el segundo 210 y vuelve a subir desde el segundo 780. El plazo termina en el segundo 900. La profundidad transitable máxima es `0,55`. La misma función de altura del terreno alimenta la presentación y la navegación: el banco central tiene una cota aproximada de `−0,13`, el sur de `−0,24`, y el canal profundo de `−1,8`. El canal permanece bloqueado incluso durante la bajante. Es una abstracción ambiental del diseño; no representa una previsión de marea documentada.

La navegación usa una cuadrícula A* de dos unidades, con obstáculos de edificios y prohibición de cortar esquinas cerradas. Una orden sobre agua profunda se rechaza con su causa. Cuando una ruta deja de servir, el grupo se detiene y revisa si vuelve a ser transitable; la orden puede cancelarse. El cierre de la oportunidad tiene una derrota explícita, de modo que una espera no deja una partida indefinida.

Al llegar al punto de acceso al buque se realiza una transición de **12 segundos de desmontaje**. Solo después se suma fuerza al progreso de captura. Los caballos no se trasladan a la cubierta. La fuerza restante y la fatiga modifican la capacidad de captura; las descargas del buque pierden eficacia al deteriorarse la moral de su dotación. Se gana al asegurar el 100 % de captura; se pierde por dispersión de todos los grupos o por cierre de la oportunidad.

La pausa y la velocidad se aplican desde la presentación mediante el tiempo que se entrega a `tick()`. El núcleo resuelve pasos fijos de `0,25 s`, conserva el acumulador en el guardado y no consulta el reloj real para decidir combate.

### Norte: decisiones por rondas y sostén de la resistencia

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

| Método o campo | Uso |
| --- | --- |
| `new_game(scenario, seed)` | Inicializa `justine` o `norte` y devuelve el estado. |
| `tick(delta)` | Avanza Justine; devuelve eventos nuevos. No corre por detrás de una pausa. |
| `issue_order(id, action, Vector2)` | Movimiento y aproximaciones tácticas; devuelve `{ok, reason, path?}`. |
| `issue_campaign_order(id, action, sector_id)` | Prepara una orden de campaña. |
| `legal_campaign_actions(id, sector_id)` | Lista las órdenes válidas para la selección. |
| `campaign_order_reason(id, action, sector_id)` | Explicación de disponibilidad o bloqueo. |
| `cancel_order(id)` | Elimina una orden pendiente o detiene un trayecto táctico. |
| `resolve_round(intent)` | Ejecuta órdenes y mando realista; devuelve consecuencias. |
| `get_unit(id)`, `get_sector(id)` | Acceso al estado de presentación; el consumidor no debería modificarlo. |
| `terrain_height_at(x,z)`, `is_walkable(x,z)` | Terreno y tránsito sincronizados con la bajante. |
| `save_game(path)`, `load_game(path)` | Guardado versionado y validado. |
| `state.last_results` | Comparación de indicadores antes/después de la ronda. |
| `state.log` | Eventos con `time`, `round`, `text` y `kind`. |
| `unit.stage` | `ready`, `moving`, `waiting_tide`, `blocked`, `rally`, `dismounting`, `boarding`, `ordered` o `routed`. |

La selección no forma parte de las reglas. Los identificadores de las tres agrupaciones son `guemes`, `arias`, `zavala`; los nombres visibles dependen del episodio. El tiempo `elapsed` mide tiempo simulado de Justine, no tiempo humano de deliberación en la campaña. La interfaz debe medir aparte su duración real de uso.

## Verificación efectuada

Las pruebas en `tests/test_rules.gd` corren el núcleo real en Godot, sin ventana y sin sustituirlo por fórmulas de otro lenguaje. El resultado detallado está en `evidence/rules-test-results.json`.

| Recorrido automatizado | Resultado observado en la semilla del test |
| --- | --- |
| Justine, tres grupos por banco directo | Victoria a 473,75 segundos simulados; 249,59 de 300 efectivos agregados restantes. |
| Justine, tres grupos por banco sur | Victoria a 547 segundos simulados; 262,49 efectivos restantes. |
| Norte, exploración + hostigamiento + protección + Humahuaca | Victoria en ronda 11; apoyo de población 89. |
| Norte, rotación de dos partidas hostigando Jujuy | Victoria en ronda 10; apoyo de población 70; no obliga a realizar Humahuaca. |
| Norte, pasividad | Derrota en ronda 12; la ocupación de Salta no había terminado por sí sola la partida. |

También se comprueban derrota táctica por inacción y por dispersión, recorridos sobre terreno transitable, obstáculos, cancelación, límites de órdenes, exclusividad y fecha de Humahuaca, consecuencias distintas de la intención enemiga, información oculta, guardado repetido, continuación, versiones incompatibles, archivos corruptos y rechazo de respuestas externas antiguas.

Estos tiempos son **tiempo de simulación con órdenes automatizadas**, no mediciones de duración de jugadores humanos ni rendimiento gráfico. Las pruebas del núcleo tampoco demuestran por sí solas que cámara, interfaz o modelos resulten utilizables: esa verificación corresponde a la ejecución visual integrada.
