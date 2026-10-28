# Civilization VII como referencia de interacción (REA, solo lectura)

Fecha: 28/10/2026. Alcance: cómo Civilization VII identifica la unidad seleccionada, enseña el territorio y comunica alcance, órdenes y resultados, para adaptarlo a la escala de Güemes. No se tomaron reglas de Civ VII: solo patrones de interfaz. No se modificó nada en la carpeta de Steam y no se extrajeron assets; las citas del código son de una línea o nombres de símbolo.

## 1. Instalación y qué soporta REA aquí

- Ruta verificada: `C:/Program Files (x86)/Steam/steamapps/common/Sid Meier's Civilization VII` (subcarpetas `Base`, `DLC`). El `appmanifest_1295660.acf` indica `buildid 25516395`. Esa es la única versión instalada que pude leer; el ejecutable no expone una versión legible con las herramientas que funcionaron.
- Ejecutables `Civ7_Win64_DX12_FinalRelease.exe` (924 200 216 bytes) y `..._Vulkan_...` (908 187 416 bytes): superan el tope de 512 MiB de `inspect_pe_resources`. Esa operación **falló** con `resource_constraint`. No intenté `open_binary` sobre ejecutables de ~900 MB ni abrir la sesión del juego.
- `inspect_pe_resources` **sí funcionó** sobre `FiraxisCrashReporter.exe` (1,29 MB, PE32+ x86_64, 30 recursos, icono de aplicación). Solo prueba que la herramienta anda; no aporta nada sobre la interfaz.
- `capture_native_ui_scenario` / `observe_native_ui`: **no usadas**. Requieren un proceso y una ventana en ejecución, y el juego no estaba corriendo; lanzarlo no formaba parte de una tarea de solo lectura. Por eso no hay capturas ni observación de comportamiento real.
- `analyze_javascript_application` **sí funcionó** (modo directorio) sobre `modules/base-standard/ui/unit-selection`: 2 archivos relevantes, 1 JS analizado, 0 fallos de análisis, cobertura semántica "unknown" y 193 incógnitas retenidas. Es análisis estático de sintaxis; no prueba ejecución.
- Hallazgo estructural: la interfaz de Civ VII es HTML/CSS/JS (cohtml, v8) en texto plano bajo `Base/modules/*/ui`. Eso permitió leer el código de la interfaz directamente (lectura de archivos) en lugar de desensamblar. Esa lectura **no es una operación REA**; está marcada así abajo.
- Documentación oficial pública como respaldo: **no se consultó** (no hizo falta para estas preguntas y no quise citar de memoria). Todo lo de la tabla es "código de interfaz leído localmente" u operación REA. Nada se apoya en documentación pública.

Regla de lectura que se respetó: lo que el código de interfaz muestra es qué se **dibuja** y qué se **consulta al motor**. Las reglas internas (costos de movimiento, fórmulas de combate, alcance real) viven en el motor y en datos que no analicé; no se deducen.

## 2. Tabla de investigación

Archivos referidos relativos a `Base/modules/base-standard/ui/` (salvo `core/`).

| Pregunta | Operación | Evidencia | Conclusión | Adaptación propuesta para Güemes |
| --- | --- | --- | --- | --- |
| 1. ¿Cómo se identifica la unidad seleccionada? | Lectura directa de `unit-selection/unit-selection.js`; REA `analyze_javascript_application` sobre esa carpeta (estructura, sin fallos) | Escucha `UnitSelectionChanged`; al seleccionar consulta `UI.Player.getHeadSelectedUnit()`, solo acepta unidades del jugador local y pasa a `INTERFACEMODE_UNIT_SELECTED`. Dibuja `VFX_UnitSelection_Ground_Burst_01` (destello inicial) y deja `VFX_3dUI_Unit_Selected_01` fijo sobre la casilla. Hotkeys `cycle-prev`/`cycle-next` | La selección tiene tres señales a la vez: anillo persistente en el mapa, destello breve al elegir y panel de acciones. Y es un **modo de interfaz** explícito, no un estado implícito | Anillo/halo persistente bajo la agrupación elegida más destello corto; el panel y el anillo usan el mismo color de la agrupación. Ciclar con Tab/teclas ya existentes (1-3) |
| 1b. ¿Cómo se muestran sus acciones? | Lectura de `unit-actions/unit-actions.js` | `getUnitActions` llama `Game.UnitOperations.canStart(..., true)` (¿existe la acción?) y `canStart(..., false)` (¿está habilitada?). Categorías `MAIN`, `COMMAND`, `HIDDEN` y orden por `priority`; botones con `data-tooltip-content`, `hotkeyId`; anotación en el botón de mover `movimientosRestantes/máximo` y en ataque a distancia `ataquesRestantes`; barra de vida con umbrales de color y texto `restante/máximo` | Separan "esta acción existe" de "ahora se puede", muestran un contador en el propio botón y relegan lo secundario a un estante plegable (`isShelfOpen`) | Un panel con 3-4 acciones principales, el resto plegado; cada botón con atajo y contador cuando aplique; botón deshabilitado con **causa** en tooltip (ya existe el rechazo con causa en el Justine) |
| 2. ¿Cómo ayudan cámara, relieve y superposiciones a leer el territorio? | Lectura de `core/ui/camera/camera-controller.js`, `core/ui/lenses/lens-manager.js`, `lenses/lens/default-lens.js`, `lenses/lens/settler-lens.js`, `lenses/layer/*` | Cámara: `Camera.panFocus`, `rotate`, `zoom`, `lookAtPlot`, `pickPlotFromPoint`; pan por teclado, borde y gamepad. Lentes: `registerLens`/`setActiveLens`; la lente por defecto activa capas `culture-borders` y `operation-target`, y **permite** (opt-in) `hexgrid`, `resource`, `yields`, `conquest`; al deseleccionar vuelve a `fxs-default-lens`; hay lentes por contexto (colonizador, comercio, construcción). Capas: ~19 archivos (apelación, fronteras, recursos, rendimientos, radio de comando…) | El mapa tiene una capa base mínima y capas **temáticas activables**; el contexto (unidad elegida) cambia de lente solo cuando hace falta. El relieve 3D se lee por la propia cámara; la información abstracta va en superposiciones | Lente "Lectura de terreno" única, con capas conmutables (agua transitable/no transitable, exposición a artillería, zonas del norte); lente de contexto automática al elegir agrupación; ninguna capa encendida por defecto salvo bordes y destino |
| 3a. ¿Cómo se comunican alcance y movimiento? | Lectura de `interface-modes/support-unit-map-decoration.js` y `interface-mode-unit-selected.js` | Al seleccionar: tres capas de borde sobre el mapa: `MovementRange` (casillas alcanzables, filtrando las que son objetivo de ataque), `ZocBorder` (zonas de control, con animación de alpha) y `CombatBorder` (casillas atacables **solo si quedan ataques y la casilla está visible**). Se recalculan con `UnitMovementPointsCleared`, `UnitKilledInCombat`, `UnitMoveComplete`. Con el cursor sobre un destino: `Units.getPathTo`, flechas de ruta, marcador final y **contador de turnos** por tramo. Orden en cola: ruta en otro color (`queuedPathColor`) | Alcance = área coloreada; destino = ruta con contador; orden pendiente = misma ruta en color atenuado. El área mostrada se consulta al motor, no se calcula en la interfaz | Mostrar el área transitable de la agrupación, la ruta con tiempo estimado al pasar el cursor y la orden en curso con color distinto. Bordes/relleno, no solo color (accesibilidad) |
| 3b. ¿Cómo se comunican órdenes y objetivos? | Lectura de `interface-mode-move-to.js`, `world-input/world-input.js`, `lenses/layer/operation-target-layer.js` | `INTERFACEMODE_MOVE_TO`: `canStart(MOVE_TO)` valida; `decorateHover` sustituye el cursor por icono de espada si el objetivo es atacable (espada simple si distancia, cruzada si cuerpo a cuerpo) y reproduce un sonido de combate al pasar; `commitPlot` → `WorldInput.requestMoveOperation`. `UpdateOperationTargetEvent(plots, canStart)` marca casillas válidas/inválidas para una acción | Una orden pasa por **modo → vista previa en hover → confirmación**. El mismo clic cambia de significado (mover/atacar) y la interfaz lo anuncia antes de confirmar | Tras elegir "Banco directo"/"Rodeo sur", resaltar el recorrido y el riesgo antes de confirmar; el clic derecho ya existente mostrar fantasma de destino y su causa si es inválido |
| 3c. ¿Cómo se comunican resultados? | Lectura de `unit-combat-preview/panel-unit-combat-preview.js` | `Game.Combat.simulateAttackAsync(...)` + `onSimulateCombatResult`: panel con fuerza y modificadores de ambos lados, vida actual y vida simulada, y una etiqueta de resultado (`LOC_COMBAT_PREVIEW_DECISIVE_VICTORY`, `MAJOR`, `MINOR`, `STALEMATE`, y derrota) elegida por umbrales de daño; los modificadores van en contenedores aparte | La **vista previa de resultado ocurre antes** del compromiso y usa categorías cualitativas, no solo números. Los umbrales de etiqueta son decisión de interfaz (visible en el código), pero no dicen cómo calcula el motor el daño | Para el choque del norte, etiqueta cualitativa previa ("favorable / parejo / desfavorable") con el desglose de modificadores a un clic; resultado posterior en un resumen de ronda |
| 3d. ¿Qué indica la unidad en el mapa sin abrir nada? | Lectura de `unit-flags/unit-flags.js` y `unit-flags/unit-info.js` | Bandera por unidad con barra de salud (`unit-flag__healthbar`) y puntos de movimiento (`setMovementPoints`); el tooltip se arma con `buildUnitInfoProps` y `UnitFlagTooltip` | Lo mínimo permanente es identidad, salud y movimiento restante; el detalle aparece al detenerse (tooltip) | Etiqueta flotante por agrupación: nombre corto, barra de fuerza, estado (en marcha / esperando / en transición) |
| 4. ¿Qué pasos conviene simplificar a nuestra escala? | Inferencia desde las filas 1-3 (no hay operación que lo mida) | Civ VII maneja decenas de tipos de operación (`interface-mode-*.js`: ~40 modos como ataque aéreo, tren, evacuación, lanzamiento de armas) y ciclo de unidades por turno | Güemes tiene 3 agrupaciones y órdenes de alto nivel; el despliegue de modos es innecesario | Un solo modo "elegir destino"; las órdenes preestablecidas son botones, no modos; sin ciclo de unidades obligatorio |
| 5. ¿Qué va visible y qué a un clic? | Lectura de `unit-actions.js` (estante plegable, `data-tooltip-*`), `plot-tooltip/helpers.js`, `combat-preview` | Visible: identidad, vida, movimiento restante, acciones principales. A un clic/hover: acciones `COMMAND`/`HIDDEN` (estante), tooltips de casilla (terreno, rasgo, río, apelación), desglose de modificadores del combate | Divide "lo que decide ahora" de "lo que explica por qué" | Ver sección 4 |

## 3. Qué no se puede afirmar

- No observé el juego en ejecución: no tengo capturas, tiempos, animaciones ni posiciones reales de la interfaz.
- Colores concretos, tamaños de botón y textos localizados no se inspeccionaron (los `LOC_*` son claves; no leí `l10n`).
- Que una capa exista no significa que esté activa en una partida típica; la configuración de usuario (`useUserConfig`) puede cambiarlo.
- El alcance de movimiento y los daños vienen del motor (`Units.getReachableMovement`, `Game.Combat.simulateAttackAsync`); su lógica no está en lo que leí.
- Las cantidades de archivos y modos son recuentos de listados de carpetas, no de funcionalidades distintas.

## 4. Adaptaciones concretas de interfaz para Güemes (priorizadas)

Prioridad 1: claridad inmediata de la decisión en el Justine y el norte, con bajo costo de implementación.

1. **Selección triple**: anillo persistente en el mapa bajo la agrupación elegida, destello al elegir y el mismo color en su botón del panel y en su etiqueta flotante (fila 1).
2. **Etiqueta flotante por agrupación**: nombre corto, barra de fuerza/vida y estado (en marcha, esperando, en transición); detalle en tooltip (fila 3d).
3. **Previsualización de ruta al pasar el cursor**: recorrido, tiempo estimado y marca de exposición a artillería en el trazado, con color distinto para la orden ya dada (fila 3a).
4. **Causa de rechazo inline**: destino inválido en agua profunda o fuera de plazo muestra icono y una frase, sin diálogo (fila 1b y 3b). Ya existe la causa en las reglas; falta mostrarla junto al cursor.

Prioridad 2: lectura del territorio.

5. **Lente "Lectura de terreno" conmutable**: agua transitable por nivel actual del río, canal bloqueado y banco central/sur; encendida automáticamente al elegir una agrupación en el Justine y apagada al deseleccionar (fila 2).
6. **Capa de exposición**: sombrear el área de riesgo de la artillería sobre la ruta central, de modo que el costo del atajo se vea en el mapa y no solo en un texto.
7. **Contador de espera**: cuando una agrupación espera la bajante, mostrar sobre la etiqueta el tiempo restante hasta que su recorrido sea transitable (se infiere de las reglas propias, no de Civ VII).

Prioridad 3: confirmación y resultados.

8. **Confirmación en dos pasos solo para órdenes irreversibles**: "Abordaje" o "Reagrupar" piden un segundo clic con vista previa; "Cancelar" y mover no (fila 3b).
9. **Etiqueta cualitativa de choque en el norte** (favorable / parejo / desfavorable) antes de resolver la ronda, con el desglose a un clic; después de resolver, resumen de la ronda con qué cambió (fila 3c). Los umbrales de la etiqueta salen de las reglas propias, no se copian.
10. **Panel de acciones con estante**: 3-4 acciones principales visibles con atajo; las secundarias (reagrupar, cancelar todo, ayudas) en un estante plegable recordado en la sesión (fila 1b).

Prioridad 4: pulido.

11. **Ayuda contextual a un clic** en cada casilla del tooltip (terreno, cota, estado del agua) en lugar de un panel fijo (fila 5).
12. **Accesibilidad de capas**: toda superposición distingue por patrón/borde además de color y respeta el atenuado de órdenes ya emitidas.

## 5. Estado de verificación

- No se modificó código del juego Güemes ni de sus reglas; no se ejecutaron los tests de Godot en esta tarea (no hubo cambios en código ni en `evidence/`). No hay commit.
- Todo lo citado de Civ VII es lectura del código de interfaz instalado (texto plano). Las únicas operaciones REA exitosas fueron `inspect_pe_resources` (sobre un ejecutable auxiliar pequeño) y `analyze_javascript_application` (sobre una carpeta de interfaz); la segunda fue estructural. Ninguna observó el juego corriendo.
