# Referentes y decisiones de diseño — entrega «equipo 2026-11-08»

Versión versionada del informe de la pista de investigación y diseño (el original, en `../qa-equipo/diseno/`, se perdió en el borrado del 2026-11-08 a las 19:10–19:21; este documento lo reconstruye a partir de su resumen y agrega el estado verificado por QA). **Nadie jugó a mano los referentes ni se leyó su código:** lo que sigue se apoya en artículos, reseñas y documentación pública leídos por el agente; las adaptaciones son hipótesis verificadas en nuestro juego con bots y revisión de QA.

## Qué juego es (mapa de los tres niveles)

| | I · La Justina (1806) | II · Humahuaca (1817) | III · Sostener el norte (1816–17) |
|---|---|---|---|
| Qué intenta el jugador | Tomar un buque varado en el Río de la Plata antes de que vuelva a subir el río | Golpe nocturno de Arias: tomar batería, cuartel y posta/pólvora a la vez y sacar la carga antes del alba y del refuerzo | Volver insostenible la invasión realista cortando abastecimiento, cohesión y comunicaciones |
| Ritmo | Tiempo real con pausa (×1/×2/×4) | Tiempo real con pausa | Campaña por rondas (hasta 14) |
| Acciones | 5 agrupaciones (3 grupos + 2 exploradores): sondear el vado, pedir carga a Liniers, mover, abordar, rechazar contraataques | 3 partidas + reconocedores + arreo: reconocer, posicionar, señal, atacar, socorrer, cargar, extraer | 3 agrupaciones × 8 sectores: mover, reconocer, proteger víveres, hostigar, reponer, replegarse, operar en Humahuaca |
| Se gana | Captura del buque al 100 % | Tres frentes tomados y carga extraída por el vado (medalla bronce/plata/oro por golpe) | Presión 7 de 7 desde la ronda 10 (retirada realista) |
| Se pierde | El río sube sin captura, dispersión, munición agotada en cubierta | Amanece o llega el refuerzo, descubiertos, bajas | Ronda 14 sin volver insostenible la invasión (pasividad) |
| Qué enseña | Medir antes de actuar, el momento justo | Coordinación y sorpresa | Economía de la presión y lectura del mapa |
| Duración de prueba (bots, ×4) | 8:29–8:41 de reloj | ~10–12 min de reloj | victoria en la ronda 10–11 |
| Conexión | Al ganar → «Seguir: Humahuaca» | Al ganar → «Seguir al capítulo III» | Pantalla final de campaña |

Intención documentada vs. implementada vs. observada: ver `docs/DISENO_*.md` (intención), el código (`scripts/game_rules.gd`, `scripts/humahuaca/`) y los dictámenes de QA (observado).

## Referentes elegidos (4)

| Referente | Mecánica que interesa | Problema que resuelve | Cómo se observa que funciona (fuente: reseñas/artículos) | Adaptación aquí | Costo/riesgo | Cómo comprobarlo |
|---|---|---|---|---|---|---|
| **Into the Breach** | Telegrafiar la amenaza antes de que pegue | Derrotas que se sienten arbitrarias | La crítica destaca que cada derrota se siente culpa propia porque el ataque se anuncia | III: intención del invasor visible solo con reconocimiento reciente (D-10); II: aviso de 5 s antes de que el centinela dé la voz (D-01) | Bajo; riesgo de saturar el panel «Situación» | Intención mostrada = resuelta en 100 % de rondas (QA: 20/20); obediente sin derrotas «descubiertos» en semillas 3, 5, 13, 17 |
| **Shadow Tactics / Desperados III** | La detección avisa y da tiempo a corregir; un solo cono a la vista | Castigo instantáneo sin feedback en sigilo | Reseñas describen el indicador de detección que se llena como la base de la tensión justa | II: aro ámbar que se vacía con la cuenta del centinela; «siguiente paso» pide retirarlos | Medio (reglas + vista + interfaz) | Captura del aviso (P2 r2) + suites del II |
| **Unity of Command** | Objetivos con plazo a la vista y puntaje que premia la operación limpia | Objetivo difuso; la victoria mínima vale lo mismo que la brillante | Reseñas resaltan los objetivos con turnos límite y bonificaciones | III: metas y presión «x de 7» visibles, sin victoria antes de la ronda 10 (D-05); II: medallas que premian decidir (D-06) | Bajo/medio | La barra se llena en la ronda de victoria; experto ≥ obediente en golpe |
| **Frostpunk** | El final repasa lo que hizo el jugador | Final sin cierre | Reseñas destacan el epílogo que resume las decisiones | Pantalla final de campaña: «En tu partida» (I, II, III) frente a «En la historia» con etiquetas (D-04). Se descarta el juicio moral | Bajo | Captura sin scroll + revisión de historia |

## Decisiones aplicadas y estado verificado

| ID | Nivel | Decisión | Verificación | Estado (QA ronda 2) |
|---|---|---|---|---|
| D-01 | II | La guía nunca lleva a perder; detección telegrafiada (~5 s) | 0 derrotas «descubiertos» del obediente en 3/5/13/17 | Cerrado por P3; QA nivel II verifica |
| D-02 | II | H03: epílogo atribuido al Diario del Estado Mayor y a Camba | `grep` sin «según La Serna» como atribución del epílogo | Cerrado por P3/P4b |
| D-03 | I→II→III | El botón principal encadena los niveles | Recorrido completo por botones | **Verificado** (2 vueltas, QA I/III) |
| D-04 | cierre | Pantalla final «En tu partida» / «En la historia» | Captura + historia | **Verificado** |
| D-05 | III | Metas y presión visibles | La barra se llena en la ronda de victoria | **Verificado** |
| D-06 | II | Medalla que premia decidir | Obediente bronce, experto ≥ obediente, plata y oro alcanzables | Parcial: experto ≥ obediente en 49/60; plata y oro alcanzables |
| D-07 | I | Un solo mensaje en el primer cuadro | Texto/botones ≤ 60 % | **Verificado** (57 % / 55 %) |
| D-08 | II | Parte legible sin scroll | Captura 1280×720 | Cerrado por P5 |
| D-09 | III | Siguiente paso concreto; Jev oculto si no está configurado | Captura | **Verificado** |
| D-10 | III | Intención del invasor con reconocimiento | 100 % de coincidencia | **Verificado** (20/20) |
| D-11 | II | Sugerir ×2 en marchas sin eventos | Sin rachas de espera sin decisión | Cerrado por P5 |
| D-12 | II→III | Guiño de texto en el III si se ganó el II | Según perfil | **Verificado** |

Límite de diseño aceptado (informado, no corregido): en el II, quien sigue la guía gana siempre con bronce (obediente 100 %, torpe 61,7 % en 60 semillas); la exigencia está en la plata y el oro. Las metas de `QA_NIVEL2.md` J05 (obediente 20–45 %, torpe 5–30 %) no se cumplen; son informe, no compuerta.
