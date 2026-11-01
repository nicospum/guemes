# Backlog del nivel «Humahuaca»

Lo que **no entra** en una ronda, o se difiere a propósito, se anota acá con su ronda. Lo lleva «compuertas y documentos». Nada de lo que figura acá bloquea el bucle: lo que bloquea son los hallazgos P0 y P1 del QA (`docs/QA_NIVEL2.md`, sección 4), que no se estacionan en este archivo.

**Reglas de uso.**

1. Un hallazgo **BAJA** del QA va acá y no cuenta contra el presupuesto de la ronda (como máximo 7 hallazgos por ronda).
2. Cuando una ronda se atrasa, se descarta en el **orden de descarte** de abajo (de arriba hacia abajo) y cada descarte se registra en la tabla con su ronda.
3. **Nunca se descarta:** el ciclo completo jugable, el relieve (plan B), las siete vistas canónicas, las etiquetas honestas, la compuerta de regresión de la Justina y el Norte, y la corrida del agente-jugador.
4. Una fila no se borra: cambia su estado (`abierto`, `diferido a rN`, `descartado`, `hecho en rN`) y deja la razón por escrito.

## Orden de descarte (DISENO_HUMAHUACA.md, sección 14)

| Orden | Qué se descarta primero | Qué queda |
|---|---|---|
| 1 | Estrategias extra de la matriz y el informe de 120 mundos | Las 8 estrategias de frente y las 5 recetas de extracción |
| 2 | Sonido más allá de la lluvia, la descarga y los avisos | Lluvia, descarga y avisos |
| 3 | Tutorial de 6 pasos y ayuda F1 completa | El «siguiente paso» con la flecha y el botón «?» |
| 4 | Medallas plata y oro | Bronce |
| 5 | La segunda y la tercera dimensión de variante | `guardia`, más `refuerzo` |
| 6 | Marcas del diario | La lista de texto |
| 7 | El punto de control `deposito` | El punto de control `posiciones` |
| 8 | Rasgos verticales del relieve, salvo la barranca | Barranca del cauce |
| 9 | Pulido de textos finales | Textos de R2b |

## Registro

| ID | Qué | Origen | Estado | Ronda | Razón |
|---|---|---|---|---|---|
| B-001 | Dimensión de variante `layout` (planta B del pueblo) | CONTRATO 2.2b, `layouts`: «candidata» | diferido | R3 | Se activa solo si una prueba de inversión de una cuarta dimensión lo justifica; mientras tanto `layouts` es `["A"]` |
| B-002 | Dimensiones candidatas `refugio` y `lluvia` con valor fijo | DISEÑO sección 6; CONTRATO 3.0 (`ACTIVE_DIMS`) | diferido | R3 | Las dimensiones activas son `guardia`, `torre_en` y `refuerzo` (12 mundos de combate) |
| B-003 | Mando realista con Jev (`enemy_*`) | Decisión D4: Jev fuera del MVP | diferido | después de R4 | La forma `enemy_*` queda definida con alternativa local determinista; no se llama a ninguna API |
| B-004 | Fondo del menú con el mundo de la Justina | CONTRATO, anexo «Abiertos» | diferido | R3 | Decisión de `ui_feel`; no bloquea nada |
| B-005 | D1b: reencadenar Justina → Humahuaca → Norte | CONTRATO 4.2 | diferido | R4 | Cuesta seis comprobaciones fijadas literalmente y cinco textos; se decide al cierre, con el nivel certificado |
| B-006 | Modelos hechos con Blender | ADDENDA A-01 | descartado | — | Blender no está autorizado; el canal de arte es el generador procedural en GDScript |
| B-007 | Sonido por frente (paneo) | DISEÑO, objeción O15 | diferido | R3 | Va a R3, no a R2 |
| B-008 | Mini-playtests humanos de 10 min y sesión humana de 20 min | ADDENDA A-03 punto 2 | descartado | — | Nadie jugará a mano: lo reemplaza el agente-jugador; el veredicto máximo es «PRESENTABLE, no certificado por humanos» |
| B-009 | Material del usuario que falta (paquete de 39 archivos, láminas 01, 04 y 05, tabla de 23 elementos, 16 fichas) | ADDENDA A-03 punto 3 | descartado | — | Se trabaja con lo que hay y lo que falta se rotula como diseño; no se espera ninguna corrección por addendum |
| B-010 | Álamos y eucaliptos en el paisaje | DISEÑO sección 12.3 | descartado | — | Anacronismo posible; si el usuario los quisiera irían rotulados «diseño, no acreditado para 1817» |
| B-011 | La evidencia de Wine pasa de `{justine, norte}` a `{justine, humahuaca, norte}` | CONTRATO 4.4 (`package_release.py`, `test_windows_wine.py`) | diferido | final | Lo hace el integrador al armar la entrega |
| B-012 | Texto de la victoria de la Justina: «Se desbloqueó el nivel 2: Humahuaca» (opción menos riesgosa de D1b) | CONTRATO 4.2 | diferido | R4 | Se decide junto con D1b |
| B-013 | Validadores V6, V10 a V16, V18, V21 y V22 de `test_hx_data` | CONTRATO 2.4 | diferido | R1.0 y R1 | Se encienden cuando los archivos de las pistas tienen datos con qué verificarlas; el informe de `test_hx_data` los lista en `reglas_pendientes` |
| B-014 | Corridas degradadas de `test_hx_smoke` (terreno, reglas, vista y progreso reemplazados por su stub) y comparación de formas contra cada stub | CONTRATO 5.1 y 7 | diferido | R1.0 | Los cuatro stubs los escribe cada dueño en R1.0; hasta entonces la prueba lo informa como pendiente |
