# Civilization VII en ejecución: observación y datos de reglas (solo lectura)

Fecha: 29/10/2026. Complementa `CIV7_REA.md` (lectura del código de interfaz). Esta vez se abrió el juego (autorizado por el usuario) y se leyeron los datos de reglas XML. Alcance: patrones de interfaz y dinámica aplicables a Güemes. No se modificó nada en la carpeta de Steam ni en la configuración del juego, no se extrajeron assets, no se usaron cuentas, no se compró ni descargó nada. Capturas: `civ7_evidencia/` (5 JPG, 1,4 MB en total).

Convención: **[DATO]** = leído en archivos de la instalación (XML o texto de la Civilopedia del juego); **[OBS]** = visto en pantalla; **[INF]** = inferencia mía.

## 1. Qué se pudo y qué no (resumen honesto)

**Operaciones REA**

| Operación | Resultado |
| --- | --- |
| `open_binary` sobre `Civ7_Win64_DX12_FinalRelease.exe` | Éxito: PE x86_64, sha256 `19ab8b3e…ae423b`. No se desensambló nada. |
| `observe_native_ui` (pid 27464) | **Falló** `capability_unavailable`: "Native macOS utilities require macOS". El proveedor solo existe en macOS. |
| `trace_native_ui_action` | **Falló** `provider_unavailable`: no hay Ghidra/IDA/Kuna configurados y Hopper no soporta Windows; además el objetivo es PE, no Mach-O. |
| `capture_native_ui_scenario` | No usada: es de la misma familia macOS (pid + window_id + accesibilidad) y además pulsa elementos que cambian estado. |
| `capture_process_scenario` | No usada: ejecuta un comando bajo PTY (consola); no sirve para un juego gráfico y lanzaría una segunda instancia. |
| `close_binary` | Éxito. |

**Consecuencia**: la observación del juego en ejecución se hizo con las herramientas de control de pantalla (`computer-use`: capturas, clics), **no con REA**. Los árboles de accesibilidad de la UI no existen en esta evidencia. Los datos de reglas salen de lectura directa de archivos (no es una operación REA).

**Lanzamiento**: `steam://rungameid/1295660` no abrió el juego: Steam quedó esperando una respuesta en un diálogo de opciones de lanzamiento (log `console_log.txt`: "waiting for user response to ShowLaunchOption") dentro de `steamwebhelper.exe`, cuyo acceso el usuario denegó. Se ejecutó directamente `Base/Binaries/Win64/Civ7_Win64_DX12_FinalRelease.exe` (variable `SteamAppId` solo en el proceso hijo). El juego llegó al menú y cargó solo, sin tocar EULA, cuentas ni compras, el save local `AugustoAnt39.Civ7Save` (Roma, turno 39, guardado con la versión 1.3.1). El log muestra conexiones de red del propio juego (MQTT de 2K) iniciadas por el arranque; yo no inicié sesión en nada. No se creó partida nueva ni se guardó nada.

**Obstáculos reales**: (1) la sesión fue interrumpida varias veces por el usuario (`user interrupt`), que usaba la PC; (2) una ventana de Godot (`Güemes — Juegos de la Patria (DEBUG)`, ajena a esta tarea) y la barra de tareas robaban el foco, y la herramienta bloqueaba clics ("shell frontmost"); (3) al final el juego dejó de actualizar la imagen (clics y scroll sin efecto, reloj de la captura quieto), por lo que se cerró. Cierre: `CloseMainWindow` no lo cerró, se terminó el proceso que yo lancé (`Stop-Process` sobre `Civ7_Win64_DX12_FinalRelease` y `FiraxisCrashReporter`) sin guardar. Ningún proceso de Civ VII queda abierto.

**NO se pudo observar** (no hay evidencia, no inferir que "no existe"):
- rango de movimiento y zonas de control dibujadas al elegir una unidad con movimiento disponible (el Legatus elegido tenía 0/2 y no había otra unidad con movimiento; no se terminó el turno para no alterar el save del usuario);
- vista previa de combate, resultados, daño real;
- niebla de guerra (hay áreas claras/oscuras, pero no se examinó);
- lentes (el botón junto al minimapa no respondió), cambio de zoom/pan de cámara (el scroll no hizo zoom en la captura que recibí);
- tooltips de los botones del panel (el hover no se renderizó en las capturas);
- avisos y resumen de turno, qué muestra el botón "Siguiente turno" al terminar, ritmo medido de un turno (clics para mover y atacar): **no medido**. Tiempos sí: la carga del save llevó 46 s (`LOADSTATE_FINISHED(46.0s)` en `AppStateLoadGame.log`), menú inicial en ~1 s tras el arranque del proceso.
- Moral/suministro como reglas: no encontré tablas con esos nombres en `base-standard/data` (búsqueda por texto, **no exhaustiva**; no abrí los 70+ XML uno por uno).

## 2. Tabla: observación

Archivos relativos a `docs/investigacion/civ7_evidencia/`.

| Pregunta | Operación usada (nombre exacto) | Evidencia | Conclusión | Adaptación para Güemes |
| --- | --- | --- | --- | --- |
| ¿Cuál es el HUD base y cuánta información hay de entrada? | `computer-use: screenshot` (no REA; `observe_native_ui` falló) | `02_hud_general_turno39.jpg` [OBS]: recursos y rendimiento por turno arriba a la izquierda (oro 130 (+45), etc.), 6 medallones de progreso, "Diario" con 2 objetivos, retratos de líderes arriba a la derecha, "Turno: 39 \| 2100 a. C." y reloj arriba a la derecha, minimapa abajo a la izquierda, botón circular "SIGUIENTE TURNO" abajo a la derecha, 3 botones laterales a la derecha | El HUD pone **lo económico arriba, el objetivo a la izquierda, el mapa abajo-izquierda y la acción de avanzar abajo-derecha**; el centro queda libre. El fondo muestra además íconos de rendimiento sobre cada casilla (curva de información alta: casi todo visible a la vez) | Güemes tiene poco que mostrar: arriba tiempo/marea y objetivo; abajo-derecha el botón único "Avanzar ronda/tiempo". No poner íconos de rendimiento por casilla (no hay economía) |
| ¿Cómo se marca la unidad seleccionada y qué panel aparece? | `computer-use: left_click` sobre la unidad + `screenshot` | `03_unidad_seleccionada_panel.jpg`, `05_zoom_panel_acciones.jpg` [OBS]: la casilla seleccionada se perfila en amarillo; aparece un panel inferior con nombre ("Legatus"), nivel (2), vida 100/100, movimiento 0/2, fuerza 10, retrato a la derecha con barra de vida, una fila de 6 botones de acción y otra de 4 acciones secundarias, y una columna a la izquierda (alarma, dormir, descartar). Un tooltip junto a la unidad: nombre, civilización "(Tú)", y "EXAMINAR [K] / OCULTAR (MANTENER) [K]" | Coincide con la lectura de código de `CIV7_REA.md` (fila 1 y 1b), ahora confirmada en pantalla: **tres señales** (perfil de casilla, panel, tooltip) y contador `0/2` visible sin abrir nada | Panel de agrupación fijo abajo con: nombre, fuerza (vida), movimiento/tiempo disponible, y 3-4 órdenes principales con atajo; secundarias en una segunda fila. Perfil de casilla/anillo para la selección |
| ¿Cómo se muestran las órdenes pendientes? | `computer-use: screenshot` | `04_orden_en_cola_ruta.jpg` [OBS]: una línea blanca con flechas sale de la unidad hacia el este hasta un ícono de destino (≈6 casillas), y las casillas alrededor del recorrido/zona de influencia de la unidad se perfilan en blanco | Una orden multiturno se ve como **ruta persistente con marcador de destino**; no hace falta reabrir la unidad para saber a dónde va | Mostrar siempre la ruta de cada agrupación con orden en curso (banco directo/rodeo sur) y su destino; distinguir "orden dada" de "orden en ejecución" |
| ¿Qué hace el minimapa? | `computer-use: screenshot` | `02`, `03` [OBS]: minimapa hexagonal abajo a la izquierda con territorio propio en morado y zonas ajenas/inexploradas en otro color; tooltip "Interactúa con la pantalla para desplazarte por el mapa" (texto del juego) | El minimapa sirve para **mover la cámara**, y cada civilización se distingue por color | Minimapa de ~900×520 m con el río, la franja de bajante, las 3 agrupaciones y las zonas de artillería; clic para centrar |
| ¿Cómo carga una partida y qué muestra mientras tanto? | `computer-use: screenshot`; logs `AppStateLoadGame.log` | `01_pantalla_carga_partida.jpg` [OBS]: pantalla con la civilización (Imperio Romano), "Habilidad de civilización", una caja "Consejos y pistas" con paginación y botón "EMPEZAR PARTIDA" bajo una barra de progreso; 46 s de carga [DATO log] | La espera de carga se aprovecha con una pantalla de **contexto + consejo**, y el comienzo es explícito (botón) | Pantalla previa a cada escenario con 1 consejo del escenario (p. ej. "el Justine sube con la bajante") y botón explícito de comienzo |
| ¿Cómo se estructura un turno? | Lectura de `core/data/TurnPhases.xml` (no REA) | [DATO] `TURNPHASE_SINGLEPLAYER`: un solo segmento secuencial con órdenes estratégicas y tácticas permitidas; `TURNPHASE_TWOPHASE`: fase **táctica** (solo movimiento/acciones de unidades, orden secuencial) y fase **estratégica** (todo lo demás, simultánea); límites de tiempo por segmento (tácticas 10 s base + 5 por unidad; estratégicas 20 s + 10 por ciudad) | El juego ya separa "mover unidades" de "gestionar", y tiene el modo de dos fases pensado para multijugador; en un jugador es una sola fase | Una ronda de Güemes = fase táctica corta (órdenes a 3 agrupaciones) y resolución; no necesitamos fase estratégica |

## 3. Tabla: datos de reglas (solo lectura)

Archivos en `Base/modules/base-standard/data/` salvo indicación.

| Pregunta | Fuente | Dato | Marcado | Adaptación para Güemes |
| --- | --- | --- | --- | --- |
| Costo de movimiento por terreno | `terrain.xml` | `MovementCost="1"` en montaña, colina, llano, costa, océano y río navegable. La montaña es `Impassable="true"` | [DATO] | El costo base es uniforme; la diferenciación viene de los obstáculos (siguiente fila). Para Güemes: costo base 1 m/m y diferenciar con "termina el avance" en vez de multiplicadores |
| Obstáculos al movimiento | `unit-movement.xml` (`UnitMovementClassObstacles`) | Para clases a pie y montada: bosque, pantano, selva, estepa de artemisa, taiga y colina → `EndsTurn="true"` (entrar detiene el movimiento del turno); ríos menores y navegables → `EndsTurn`; montaña → `Prohibited`. Para unidades "recon": ignoran bosque y colina pero se detienen en pantano y ríos | [DATO] | Modelar el **banco de arena/pantano/tramo de río** como "entrar termina el avance" o "prohibido con el nivel actual", no como costo fraccionario. Encaja con la bajante: el banco se vuelve entrable |
| Movimiento base de unidades | `units.xml` y `age-*/data/units.xml` | `BaseMoves`: Guerrero 2, Explorador 2, Comandante 2, Caballería (Jinete, Corcel, Caballero, Lancero) 3. Vista de 2 casillas (`BaseSightRange="2"`) para casi todos | [DATO] | Jinetes más rápidos que infantería en proporción 3:2; sobre un mapa de ~900 m, 1 turno ≈ decenas de metros por ronda de decisión (a definir en pruebas) |
| Fuerzas base | `age-antiquity/data/units.xml` y `age-exploration/data/units.xml` (`Unit_Stats`) | Combate: Guerrero 20, Lancero/Espadero 25 a 35, Falange 30, Jinete 35, Caballero 45. A distancia: Honda 5/15 (rango 2), Arquero 10/20 (rango 2), Ballesta de asedio 15/10 y bombardeo 30 (rango 2). Vida 100 (texto de la Civilopedia) | [DATO] | Escala 20-45 de fuerza y 100 de vida; útil para calibrar jinete vs. infantería vs. artillería, sin copiar los números |
| Fórmula de combate | Texto de la Civilopedia (`text/en_us`, páginas COMBAT) | "Los ataques aplican daño igual al daño base de la unidad y modificadores de fuerza de combate". **La fórmula exacta de daño no está en los datos**: vive en el motor | [DATO] parcial; fórmula **no disponible** | No inventar: definir una fórmula propia y publicar la tabla de modificadores |
| Modificadores de terreno | Civilopedia | Defender en vegetación +2; en humedales −2; en terreno accidentado +3; ataque o defensa desde un río menor penalizada. Fortificar: +3 de defensa tras 2 turnos. Unidades dañadas pierden fuerza | [DATO] | Modificadores aditivos pequeños y visibles en el desglose (p. ej. banco +, agua −, atrincherado +) |
| Ataque a distancia | Civilopedia | Sin daño de respuesta; usa los bonos de la casilla del atacante; vulnerable a la caballería (que gana fuerza contra tiradores) | [DATO] | Artillería sin respuesta, vulnerable a los jinetes: ya presente en el diseño del Justine |
| Flanqueo | Civilopedia | Una vez trabado un frente, atacantes adicionales por los lados reciben +2 (frente-lateral), +3 (trasero-lateral) o +5 (retaguardia). Requiere una tecnología | [DATO] | Posible bono del jinete por rodear; opcional |
| Zona de control (ZOC) | Civilopedia, `units.xml` | Entrar a la ZOC de una unidad adyacente termina el movimiento, pero se puede atacar. Tiradores, apoyo y asedio no la ejercen. La habilidad "ágil/veloz" ignora la ZOC (`ABILITY_SWIFT`, `ZoneOfControl` por unidad) | [DATO] | La ZOC de la infantería en el norte justifica que el jinete sea el único que rodea sin detenerse |
| Embarcar | Civilopedia | Unidad terrestre sobre agua usa fuerza fija: 5 (antigüedad), 25, 50; movimiento embarcado 2 o 3 | [DATO] | Cruzar el río sin banco = estado vulnerable con fuerza fija baja: útil para costear el rodeo |
| Moral / suministro | búsqueda en `data/*.xml` | No hallé tablas con esos nombres | [DATO] ausente (búsqueda no exhaustiva) | No se toma nada; si Güemes los necesita, serán propios |
| Cómo se ordenan las acciones | `unit-operations.xml` | `CategoryInUI` (`ACTIVE_PRIMARY`, `PASSIVE_PRIMARY`, `COMMAND`), `PriorityInUI` (ataque a distancia 10, descansar 20, fortificar 25, ataque naval 5…) y `HotkeyId` | [DATO] | Las órdenes tienen categoría, prioridad y atajo: el panel es una consulta ordenada, no una lista fija |

## 4. Patrones que se pueden adoptar (ordenados)

1. **Selección triple + contador en el panel** (perfil de casilla, panel, tooltip; `0/2` visible): confirmada en pantalla.
2. **Ruta persistente con marcador de destino** para órdenes en curso: confirmada en pantalla.
3. **"Entrar termina el avance"** en lugar de costos fraccionarios para banco, pantano y río: confirmada en datos; encaja con la bajante.
4. **Modificadores aditivos pequeños y desglosados** (+2, −2, +3): confirmados en datos; la vista previa en pantalla **no se observó**.
5. **ZOC que detiene el avance pero permite atacar; los tiradores no la ejercen; la caballería la ignora**: confirmada en datos.
6. **Pantalla de contexto con consejo antes de empezar** y botón explícito de comienzo: confirmada en pantalla.
7. **Minimapa clicable** como control de cámara: confirmado en pantalla.

## 5. Estado

- Sin cambios en `scripts/`, `tests/` ni `evidence/`. Solo se agregan esta nota y `civ7_evidencia/`.
- Los números de Civ VII sirven para **calibrar órdenes de magnitud** y entender el modelo; Güemes no copia valores, fórmulas ni textos.
- Los textos de la Civilopedia se resumieron con mis palabras; las capturas son del HUD y se guardan solo como evidencia de investigación (no redistribuir).
