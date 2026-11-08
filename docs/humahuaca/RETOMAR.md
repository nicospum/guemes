# Retomar el nivel 2 (Humahuaca)

Estado al 2026-11-02, el trabajo llega hasta `d3a6882` en `main`. El bucle de agentes (Workflow `wf_962eddfe-336`, unas 20 h) se detuvo a pedido del usuario durante R1, pase 3: después de la compuerta completa y antes de los revisores y del jefe de QA. Todo es local: sin push, sin etiquetas nuevas, sin EXE y sin certificación. Según `docs/QA_NIVEL2.md` el nivel todavía **no** está presentable.

## Lo primero al retomar: la cámara (pedido del usuario, 2026-11-02)

El usuario miró las capturas y dijo que la cámara debería estar **más cerca**: todo se ve muy chico (fichas, edificios, texto del mapa). Es la prioridad uno de R2a, antes que el resto. Dónde tocar: `scripts/humahuaca/ui/humahuaca_camera.gd` y la sección de cámara de `data/humahuaca_ui.json`; la pista dueña es `ui_feel`. Criterios que lo miden: V02 (el encuadre inicial entra completo) y V03 (fichas ≥ 48 px a 1280×720), que hay que cumplir acercando la cámara. Ojo: acercar no puede romper que los tres objetivos entren en el primer cuadro.

## Dos reglas que fallan por motivos ajenos al nivel (en palabras simples)

El control de calidad marca como bloqueantes dos cosas que no dependen del trabajo de las pistas. El usuario todavía no respondió; la propuesta del lead, para decidir cuando retomen:
1. **Etiquetas Git viejas.** `v0.2.0-alpha` y `v0.3.0-alpha` son versiones anteriores del propio usuario. La regla E05 esperaba que existiera solo `v0.1.0`. Propuesta: no borrar nada y cambiar la regla a «no se agregó ni se movió ninguna etiqueta».
2. **Velocidad de la Justina.** La regla T06 pide 3,0 ms por cuadro. Hoy la PC del usuario da 3,1 a 5,1 ms, incluso con el juego original sin tocar. Propuesta: comparar contra el juego original medido en el mismo momento (tolerancia 1,15 ×).
**Aprobadas por el usuario el 2026-11-02 y aplicadas (QA_NIVEL2.md v1.5, enmienda 5). Se puede relanzar el bucle.**

## Plan de la próxima ronda de trabajo (pedido del usuario, 2026-11-02)

**Dirección de arte (pedido del usuario, 2026-11-02):** «retomá esta estética más épica y linda; la de ahora no dice mucho». Seis mockups de referencia y su lectura en `docs/referencias/humahuaca/estetica/` (LEEME.md). Resumen: oscuro y dramático, relieve dorado con cielos de atardecer, acentos dorado + violeta, rojo solo enemigo, títulos con serifa, mapa protagonista, retratos y escenas pintadas, paneles con citas y documentos, pantalla de misión a pantalla completa con tres decisiones. Aplica al menú, al briefing, al HUD y a los partes de los tres niveles.

**Nube (2026-11-02):** la rama `humahuaca-r1` (333a657) está subida a GitHub; `main` de GitHub sigue en 72077c8. Se pidió una sesión en la nube «Humahuaca: balance del nivel 2» que trabaja en la rama `hx-balance-nube` (balance J03/J05/J07) y la sube a GitHub al terminar. Al retomar: `git fetch origin` y revisar esa rama antes de mezclarla.

**DECIDIDO por el usuario el 2026-11-02: Blender para modelar y exportar a Godot.** Se queda el motor Godot; no se pasa a Unity ni a Unreal. Falta solo pedir permiso para lo que haya que descargar (modelos, plugins), con nombre, origen y tamaño.

El usuario quiere que la próxima ronda sea un salto de calidad, no solo corrección de hallazgos. Lo dijo así, en sus palabras: usar Blender, Unreal, Unity, «no sé cuál pero vamos a mejorar»; mejorar soldados, caballos, árboles, todo; mejorar el mapa; hacer conexiones MCP; buscar skills; mejorar la dinámica de juego; «y lo vamos a terminar»; imágenes épicas; dibujos de Güemes «cuando lo elijas»; «volverlo cheto cheto».

Cómo se traduce (el lead lo ordena al retomar):

1. **Arte de personajes y escenario.** Mejorar soldados, caballos, árboles, edificios y el mapa. **Cambia una regla anterior:** hasta ahora Blender NO estaba autorizado y el arte salía de un generador por código. Con este pedido, Blender (hay un MCP de Blender conectado en el entorno) pasa a ser una opción válida; falta que el usuario confirme cuál herramienta usar (Blender, Unity o Unreal). Recomendación del lead: Blender para modelar y exportar a Godot (menor costo y sin cambiar de motor); Unity o Unreal solo si el usuario quiere cambiar de motor, lo que implica rehacer el juego y debe decidirse antes de empezar. Descargar modelos o plugins sigue necesitando permiso explícito (nombre, origen, tamaño).
2. **Conexiones MCP y skills.** Que el explorador de herramientas inventaríe los MCP disponibles (Blender, Figma, Canva, navegador, etc.) y las skills útiles (diseño, Unity, game-development) y proponga cuáles conectar. Las conexiones nuevas las autoriza el usuario.
3. **Mapa y relieve.** Pasar al relieve real de Copernicus (ya bajado) y mejorar el aspecto del mapa. Antes que nada, la cámara más cerca.
4. **Dinámica de juego.** Balance (hoy hasta el jugador torpe gana), ritmo, decisiones y claridad de las órdenes (R2b).
5. **Imágenes épicas y dibujos de Güemes.** Capturas y piezas de arte para el menú, las pantallas de victoria y la presentación. Los retratos o dibujos de Güemes los elige el lead cuando llegue ese punto: tienen que ser ilustraciones propias hechas para el juego, sin copiar obras con derechos, y con etiqueta honesta de que son interpretaciones.
6. **Terminarlo.** Cerrar R3 y R4 (EXE, README con tres escenarios, certificación). La diversión y la claridad mandan sobre la fidelidad histórica.

Orden sugerido: cámara, decisión de herramientas, arte y mapa, dinámica, imágenes, cierre. El plan de rondas R2a a R4 del bucle sigue valiendo; este plan se suma a las pistas visual y ui_feel y puede requerir actualizar `docs/CONTRATO_HUMAHUACA.md` (nuevos formatos de modelos, créditos) antes de relanzar.

## Qué hay en main

- El nivel II «Humahuaca: el depósito de la retaguardia» se juega de punta a punta desde el botón II del menú: noche de preparación, señal, ataque a la batería, el cuartel y la posta, extracción al alba, parte de victoria o de derrota, reintento, guardado y carga.
- Código en `scripts/humahuaca/` (terreno, reglas, vista, interfaz), seis JSON en `data/humahuaca_*.json`, pruebas `tests/test_hx_*.gd`, herramientas `tools/hx_*`, `tools/qa_gate.sh`, `tools/ui_qa_humahuaca.gd`, `tools/vis_humahuaca.*`.
- Relieve: plan B reconstruido de la lámina 03 (475 nodos, ±10 m). La tesela Copernicus S24 está bajada en `investigacion-nivel2/descargas/` (fuera de Git) y se adopta desde R2a.
- La Justina y «Sostener el norte» siguen intactos: 40 archivos protegidos sin cambios contra la base 5ebbd28; `scripts/main.gd` solo suma ganchos (+48/−4).
- Última compuerta completa terminada (pase 3, sobre 8c97b4e; el benchmark oficial quedó omitido): reglas 871/0, integración 283/0, Jev 15/0, hx_data 420/0, hx_smoke 158/0, hx_terrain 158/0, hx_rules 679/0, hx_view 284/0, hx_flow 285/0, ui_qa 254/0 a 1280×720, 1920×1080 y 2560×1440, Justina 18 victorias. Único paso en FALLA: `higiene` (etiquetas Git ajenas, ver abajo). Después, sobre `d3a6882`, solo cambiaron el arnés del agente-jugador, `tools/qa_gate.sh` y documentos (sin tocar `scripts/`, `data/` ni `tests/`); esa segunda compuerta completa pasó hasta `ui_qa` a 2560×1440 y se cortó a mano antes de Justina, benchmark y herramientas del nivel: esos tres pasos no se volvieron a correr sobre `d3a6882`.
- Rendimiento medido por la pista visual: Humahuaca 1,43 ms de media (tope 4,0).

## Historia del control de calidad

| Pase | Resultado del jefe de QA |
|---|---|
| R1 pase 1 | 4 P0, 2 P1, 1 MEDIA. No cierra. |
| R1 pase 2 | 2 P0, 0 P1, 3 MEDIA. No cierra. Los 2 P0 no los arregla ninguna pista. |
| R1 pase 3 | Visual cerró H-R1-9 y H-R1-11, ui_feel cerró H-R1-10 (con prueba propia). Sin revisores ni jefe de QA: **sin verificar por QA**. |

## Decisiones del usuario que bloquean cerrar R1

1. **E05, etiquetas Git.** El repo tiene `v0.2.0-alpha` y `v0.3.0-alpha` además de `v0.1.0`; la rúbrica pide solo `v0.1.0`. Nadie las tocó. Propuesta: enmienda 5 que fije E05 como «no se crearon ni movieron etiquetas respecto de la base 5ebbd28».
2. **T06, tiempo de cuadro de la Justina.** En esta PC la Justina mide 3,1 a 5,1 ms contra el tope ≤ 3,0, pero la base 5ebbd28 sin tocar mide igual o peor (A/B alternado: base 3,36–3,57 contra commit 3,21–3,45). Propuesta: fijar T06 de Justina y Norte contra la base medida en la misma sesión (≤ 1,15 ×).
3. **Render héroe VP-14 (A-13) y cámara inicial en caja gris:** falta el sí o el no del usuario (la captura está en `evidence/humahuaca/r1/inicial_caja_gris.jpg`).
4. **Licencia Copernicus.** Para adoptar el DEM en R2a hay que copiar el Artículo 6 de `License-COPDEM-30.pdf` (sin descargar todavía, tamaño sin verificar): pedir permiso.

El jefe de QA no mueve postes solo: si el usuario acepta 1 y 2, el lead edita `docs/QA_NIVEL2.md` (v1.5) y lo commitea antes de relanzar. Si no, cada pase vuelve a marcar las dos P0 y gasta unas 6 h sin cerrar.

## Qué falta

- **R2a** (hasta 3 pases): relieve real con Copernicus, verificar H-R1-9/10/11, ficha 4 (reconocedores) ambigua, anillo de contenido (parcelas con tapias, capilla, huellas de carreta), bordes y panorama contra la foto de 1923 (V06). **Avanzado en la nube el 2-11-2026 (rama `hx-docs-nube`, a integrar):** C03 cerrado (las dos cadenas ya estaban en castellano desde `9d733b4`; escáner en 0 y guardia nuevo en `test_hx_data`); H03 corregido en `data/history.json`, la matriz, `docs/humahuaca/HISTORIA.md` y el diseño, y queda **solo** la línea `epilogue.lines[4]` de `data/humahuaca_rules.json` para `reglas_historia` (texto listo en `docs/humahuaca/TEXTOS_REVISION.md`); E03 adelantado (README, `project.godot`, `CLAUDE.md`, `docs/CONTROLES.md` y `docs/CREDITOS.md` con los tres escenarios y las teclas del nivel II).
- **R2b** (hasta 3 pases): balance. El obediente y el torpe ganan 100 % y 98 % al primer intento (diseño: 20–45 % y 5–30 %), la victoria llega en 8:44 de mediana (diseño: 11:00–13:00), hay brechas de 90–102 s sin decisión (J03), faltan variantes y matriz (J06).
- **R3** (hasta 2 pases): pulido, sonido, prueba en una GPU más débil, río de noche.
- **R4** (hasta 3 intentos): EXE `entregas/0.5.0-preview1/PatriaGuemes_preview6.exe` con SHA-256, README con tres escenarios (hoy dice dos), `evidence/humahuaca` ≤ 60 MB (hoy 133 MB), triple certificación.
- Material del usuario que no estaba en la carpeta: zip de 39 archivos, láminas 01/04/05 y tabla de 23 elementos.

## Cómo relanzar

1. Aplicar las decisiones de arriba (enmienda 5 si el usuario la aprueba).
2. Cargar el script `docs/humahuaca/bucle_workflow.js` con el tool Workflow, pasándolo inline o por `scriptPath`, y como `args`:
   `{ "etapas": ["R2a", "R2b"], "estado": <contenido de docs/humahuaca/retomar_estado.json> }`.
   Después, `["R3", "R4"]` con el `estado` que devuelva el tramo anterior.
3. Cada pase tarda unas 5 a 6 h (pistas en paralelo, integración, compuerta, cinco revisores, jefe de QA). Las rondas R2a y R2b pueden usar hasta 3 pases cada una.
4. No tocar el repo mientras corre: los agentes escriben en `main` y en worktrees `.claude/worktrees/hx-*`.
5. Antes de cualquier push o release, pedirle el OK al usuario.
