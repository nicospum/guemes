# Juegos de la Patria: Güemes en 3D

Actuá como responsable de desarrollo, diseño de juego e integración técnica de la primera entrega de una serie de juegos sobre la historia argentina. Empezamos con **Güemes**, con dos escenarios: la toma del **Justine/Justina en 1806** y la resistencia a la invasión de **La Serna en 1816–1817**.

Quiero un juego 3D con presencia visual, épica, controles intuitivos y decisiones interesantes, que se pueda empezar a jugar rápido y completar en sesiones acotadas. El realismo debe verse en terreno, personajes, caballos, agua, iluminación, movimiento y sonido, con rendimiento comprobado.

Este encargo incluye investigar, preparar herramientas, diseñar, implementar, probar y entregar una versión jugable. Continuá después del diagnóstico inicial. Conservá el trabajo existente si encontrás un proyecto empezado y resolvé las decisiones técnicas rutinarias con criterio.

**REA (Reverse Engineer Anything) y Jev de TypeSafe son requisitos del flujo de trabajo.** Necesito uso real y verificable. Las imágenes adjuntas son referencias de atmósfera; las fuentes históricas y las reglas del juego deben revisarse por separado.

## 1. Resultado, alcance y ritmo

Entregá una aplicación con dos escenarios jugables, selección de escenario, tutorial contextual, objetivos, consecuencias, victoria, derrota, reinicio y guardado/continuación donde corresponda. La primera misión será el primer hito completo; después cerrá la campaña del norte sobre la misma base.

La plataforma inicial de referencia es **Windows local**, salvo que encuentres un proyecto existente con otro destino ya acordado. Si verificás esa excepción, explicala en el informe inicial y adaptá la exportación y sus pruebas a ese destino. Necesito poder abrir y jugar la entrega exportada, además de disponer del código. No conviertas el trabajo en una colección de pantallas o un documento de diseño pendiente de ejecución.

Usá estas metas iniciales, que deberán ajustarse con pruebas:

- Primera decisión significativa dentro del primer minuto.
- Justine: aproximadamente **8–15 minutos** por partida.
- Campaña de La Serna: aproximadamente **20–35 minutos**, con posibilidad de continuar después.
- Pocas esperas, transiciones breves y resolución acelerable cuando aporte comodidad.

Son objetivos de diseño, no resultados garantizados. Medí duración y tiempos muertos. Quiero estrategia accesible y profundidad suficiente para volver a jugar; evitá añadir gestión repetitiva para alargar las partidas.

**Puesto del Marqués queda como ampliación posterior.** Humahuaca pertenece al escenario de La Serna y puede resolverse con las reglas compartidas, sin exigir un tercer juego. Prepará contenido reutilizable para la serie sin construir primero una plataforma general.

## 2. Identificar el proyecto y preparar el entorno

Comprobá workspace, instrucciones como `AGENTS.md`, stack, Git, rama, remoto, cambios locales, herramientas instaladas y recursos del equipo. Si ya hay un juego comenzado, revisá documentación, commits, escenas y recorridos existentes antes de modificarlo.

Si no existe proyecto, creá uno independiente en el workspace apropiado, con un nombre provisional como `patria-guemes`. No reutilices por suposición el repositorio de GobernArg o Nico Agent OS. La etiqueta “NICOOS” de algunos mockups no define una integración obligatoria.

La instalación de Civilization VII indicada más abajo es una referencia y debe permanecer separada del nuevo proyecto. Confirmá qué rutas y procesos podés acceder realmente desde Windows, WSL o el entorno disponible.

Detectá CPU, GPU, RAM, resolución y capacidades de ejecución cuando tengas acceso al equipo objetivo. Distinguí esos datos de los de una máquina remota. No afirmes haber comprobado rendimiento en mi computadora si solo ejecutaste pruebas en otro entorno.

Preservá cambios locales y configuraciones existentes. Podés crear una rama de trabajo desde el estado comprobado. No hagas limpiezas destructivas ni sustituyas trabajo útil para facilitar el arranque.

## 3. Skills, MCPs y repositorios que hay que preparar

Inventariá primero lo disponible. Prepará un conjunto concreto para ingeniería de juegos, motor elegido, modelado y animación 3D, navegación, IA táctica, interfaz, audio, rendimiento, pruebas, historia, REA y Jev. Leé los skills antes de utilizarlos y verificá procedencia, compatibilidad y versión.

Separá **herramientas de Codex para desarrollar** de **dependencias del juego para ejecutarse**. Los jugadores no necesitan todos los MCPs del entorno de desarrollo.

| Capacidad | Fuentes y candidatos |
| --- | --- |
| REA | [morluto/rea](https://github.com/morluto/rea), [rea.tools](https://rea.tools) y [alcance de Ghidra en Windows](https://github.com/morluto/rea/blob/main/docs/windows-ghidra-p0.md). |
| Jev / TypeSafe | [Skills oficiales](https://github.com/typesafe-ai/skills), [System One](https://docs.typesafe.ai/api/system-one) y [Choice](https://docs.typesafe.ai/primitives/choice). |
| Skills complementarios | [Catálogo de OpenAI](https://github.com/openai/skills) y recursos pertinentes cuya fuente y contenido compruebes. |
| Godot, si se elige | [CLI oficial](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html) y MCP comunitario [Coding-Solo/godot-mcp](https://github.com/Coding-Solo/godot-mcp). |
| Unity, si se elige | Documentación oficial de la versión instalada y MCP comunitario [CoplayDev/unity-mcp](https://github.com/CoplayDev/unity-mcp). |
| Unreal, si se elige | [Automatización oficial del editor](https://dev.epicgames.com/documentation/unreal-engine/scripting-the-unreal-editor-using-python). Separá scripts de editor del código que ejecuta el juego. |
| Producción 3D | Blender y MCP comunitario [ahujasid/mcp-for-blender](https://github.com/ahujasid/mcp-for-blender), o su automatización local pertinente. |
| Git y verificación | CLI e integraciones existentes; [MCP de GitHub](https://github.com/github/github-mcp-server). Playwright solo si hay una superficie web que probar. |

Los MCPs comunitarios de motores y Blender deben evaluarse como integraciones de terceros. No presupongas herramientas que sus versiones no exponen. Un complemento se considera operativo cuando completa una operación pertinente, no solo cuando aparece en configuración.

Instalá únicamente lo necesario para el motor y el flujo elegidos, preservando la configuración de otros proyectos. Registrá fuentes, versiones, propósito y prueba. Las compras, nuevas suscripciones o servicios pagos adicionales requieren una decisión concreta; completá primero lo que puedas con recursos disponibles.

Podés delegar historia, reglas, arte, integraciones y QA entre subagentes. Delimitá archivos y mantené un responsable de integrar escenas, contratos y builds.

## 4. REA y Civilization VII: investigación aplicada al juego

La referencia está instalada en:

```text
C:\Program Files (x86)\Steam\steamapps\common\Sid Meier's Civilization VII
```

Comprobá la ruta, versión del juego y capacidades reales de REA en este equipo. Su soporte depende del proveedor de análisis y de la versión instalada; no supongas que una guía de `main` coincide con el paquete publicado.

Investigá preguntas concretas:

1. Cómo se entiende qué unidad está seleccionada y qué puede hacer.
2. Cómo cámara, relieve y superposiciones ayudan a leer el territorio.
3. Cómo se comunican alcance, movimiento, órdenes y resultados.
4. Qué esperas o pasos conviene simplificar para nuestra escala.
5. Qué información debe aparecer durante una decisión y cuál puede quedar a un clic.

Usá REA sobre las superficies que realmente soporte y contrastá con observación y documentación. Registrá la pregunta, evidencia, conclusión y adaptación propuesta. No deduzcas reglas internas solo por ver una animación o una etiqueta.

Conservá la instalación de Steam, sus archivos y partidas. Guardá los resultados del análisis fuera de esa carpeta. El nuevo juego tendrá código y recursos propios o con licencia adecuada; Civilization sirve para estudiar principios de interacción y presentación.

La investigación debe ayudar a implementar pronto. No hace falta reconstruir todo Civilization ni su escala de campaña. Si una operación no está soportada o la ruta es inaccesible, indicá el límite, usá las evidencias disponibles y seguí construyendo. No declares completada una prueba de REA que no ocurrió.

## 5. Incorporar los materiales y construir una base histórica verificable

Si recibís el paquete de materiales, leé `LEEME.md`, `MANIFIESTO_MATERIALES.json` y `docs/historia/guemes/00_DOSSIER_Y_FUENTES.md`. El manifiesto relaciona nombres originales, copias organizadas e imágenes repetidas.

Las fuentes originales están en `docs/historia/guemes/originales/`:

| Archivo del paquete | Uso |
| --- | --- |
| `IdearioGuemes.pdf` | Susana Leonilda Martorell de Laconi, *Ideario de Güemes*, 2018: biografía, cronología y transcripciones documentales. |
| `Historia_de_Salta.md` | Texto de Jorge Virgilio Núñez sobre el Justina y la atribución tradicional a Güemes. |
| `Guemes_y_Plan_Continental.md` | Artículo del Instituto Argentino de Historia Militar sobre la función de Güemes en el plan continental. |
| `Episodios_propuestos.txt` | Síntesis previa y propuestas de adaptación; es un antecedente editorial, no una fuente histórica independiente. |

Hay copias de lectura sin imágenes base64 en `lectura/`. Conservá los originales y las referencias de página. Si recibís los adjuntos sueltos, organizalos de manera equivalente sin alterar su contenido. Las imágenes están en `docs/referencias-visuales/`.

Convertí la investigación en una matriz con hecho, fuente, página o URL, grado de certeza, discrepancias y adaptación al juego. Diferenciá documento de época, interpretación posterior, tradición y ficción jugable. Los textos de las imágenes generadas no prueban fechas, citas o acontecimientos.

### Precisiones ya identificadas

- **Justine/Justina:** el episodio corresponde a la Reconquista de Buenos Aires, el 12 de agosto de 1806. La captura por caballería y la bajante aparecen en el relato de Gillespie reproducido en el *Ideario*, p. 390. Ese testimonio no identifica al comandante. La p. 33 señala que la intervención personal de Güemes no está probada; las pp. 391–392 recogen la tradición posterior de Pastor Obligado. Podemos protagonizar esa tradición con Güemes, explicándolo como recreación histórica.
- **Buque:** utilizá Justine o Justina, manteniendo una denominación consistente y explicando la variante. No adoptes “HMS Leander” de un mockup. El testimonio lo describe como mercante armado; verificá su representación antes de reproducir el enorme navío de algunas ilustraciones.
- **1806:** contexto virreinal anterior a Mayo. La bandera argentina fue creada en 1812 y la División Infernal se organizó en 1815. No traslades esas banderas o esa unidad al episodio de 1806 por aparecer en una imagen. Ajustá también edad, grado, vestimenta y armas.
- **La Serna:** campaña de 1816–1817, con ocupación temporal de Salta y posterior retirada. El *Ideario*, p. 223, reproduce el parte del 5 de mayo de 1817 sobre la evacuación al amanecer. Registrá la diferencia entre fuentes que resumen la salida el 4 y las que distinguen movimientos del 4 y del 5.
- **San Martín:** la conexión es estratégica con su campaña hacia Chile; no llega con un ejército para rescatar a Güemes en Salta. Una noticia de Chacabuco puede ser un hito dramatizado, con esa condición explícita en el dossier.
- **Humahuaca:** fecha de referencia 1 de marzo de 1817, con Manuel Eduardo Arias como jefe de la operación. El *Ideario* contiene una discrepancia entre entradas de marzo y mayo: contrastala con fuentes específicas antes de construir la cronología.

Fuentes de consulta: [Justine, Argentina.gob.ar](https://www.argentina.gob.ar/noticias/216-anos-de-la-toma-de-la-fragata-justine), [Plan Continental](https://www.argentina.gob.ar/node/261243), [biografía del Gobierno de Salta](https://www.salta.gob.ar/contenidos/biografia-de-martin-miguel-deguemes-8), [Humahuaca, Cultura de Jujuy](https://cultura.jujuy.gob.ar/2017/03/01/bicentenario-de-la-batalla-de-humahuaca/), [bandera nacional](https://www.argentina.gob.ar/pais/simbolos/bandera) y [PDF del Ideario](https://acaedu.edu.ar/LibrosBD/pdf/IdearioGuemes.pdf).

Las citas textuales necesitan fuente localizable. Los diálogos inventados se identifican como dramatización. Las cifras de toda una campaña no se convierten automáticamente en unidades presentes en cada combate. Los resultados alternativos del jugador deben distinguirse del desenlace histórico de referencia.

## 6. Escenario A: la toma del Justine

Construí una misión táctica 3D breve alrededor de una oportunidad del entorno. Mi punto de partida es tiempo real con pausa para dar órdenes, o rondas cortas con resolución animada si ofrecen mejor control y ritmo en el prototipo.

El escenario necesita una ribera colonial reconocible, terreno transitable, sectores de agua con distinta profundidad, un buque y un número reducido de grupos controlables. Reconstruí el entorno de época; la costa actual no es el plano automático de 1806.

El recorrido debe permitir:

1. Reconocer el buque y comprender la amenaza de su artillería.
2. Seleccionar, reunir y mover grupos, preservándolos mientras se prepara la oportunidad.
3. Observar un cambio del río que modifica realmente la transitabilidad o la exposición.
4. Elegir una aproximación y asumir sus consecuencias.
5. Llegar al buque, representar el desmontaje y resolver la captura o rendición.

La bajante debe afectar reglas y movimiento. No hace falta una simulación hidrodinámica compleja, pero el agua visible y el terreno habilitado deben coincidir. No presentes un cálculo anticipado de marea como hecho documentado.

El objetivo de referencia es capturar el buque o lograr la rendición de su dotación. El abordaje puede ser una secuencia acotada con resolución táctica, sin construir otro juego completo de combate individual. Evitá trasladar una formación montada a la cubierta sin una transición coherente.

Diseñá al menos dos aproximaciones viables con diferencias de exposición, tiempo o conservación de fuerzas. Las rutas, tiempos, cantidades de grupos y reglas de combate son adaptación jugable. Dejá clara la causa de victoria o derrota y permití reiniciar rápido.

El episodio debe funcionar desde la primera orden hasta su desenlace. La calidad visual se desarrollará sobre ese recorrido completo.

## 7. Escenario B: sostener el norte frente a La Serna

Construí una campaña corta sobre un mapa 3D de sectores relevantes, con órdenes por rondas y resolución breve como punto de partida. Reutilizá el sistema de órdenes, unidades, objetivos y guardado de la primera misión donde sea adecuado.

La capacidad del invasor para continuar depende de recursos, cohesión y comunicaciones, además del territorio ocupado. Las decisiones del jugador deben modificar esas condiciones.

Incluí un conjunto contenido de acciones:

- Reconocer rutas y movimientos con exploradores.
- Proteger y trasladar víveres, animales y recursos propios.
- Conservar tropas y caballos, y atender las necesidades de las poblaciones que sostienen la defensa.
- Hostigar destacamentos y abastecimientos.
- Elegir enfrentamientos favorables y retirarse de otros.
- Presionar una retirada sin comprometer innecesariamente las fuerzas propias.

Mostrá de forma comprensible por qué una decisión mejora o empeora la situación. El jugador no necesita ver todas las fórmulas internas, pero sí entender riesgos, restricciones y consecuencias.

Ocupar Salta temporalmente no equivale por sí solo a ganar la campaña para los realistas. La victoria de referencia del jugador consiste en volver insostenible la invasión y lograr su retirada. Definí también derrotas coherentes y evitá una estrategia trivial de esperar sin actuar hasta que termine un cronómetro.

Representá la escala mediante agrupaciones y valores agregados, sin simular miles de soldados individualmente. Cuidá la relación entre sectores, topografía y nombres históricos; las rutas operativas exactas pueden simplificarse si lo documentás.

**Humahuaca** debe aparecer como operación con mando de campo de Arias. Los objetivos de artillería, cuartel y arsenal son candidatos a una resolución coordinada, sujetos a la revisión del parte y sus estudios. Puede utilizar el mapa y las reglas existentes; una escena adicional solo se incorpora si permite cerrar el conjunto sin dispersar el desarrollo.

Una noticia del frente de Chile puede dar contexto al esfuerzo del jugador. No conviertas a San Martín en un refuerzo que aparece físicamente ni cierres toda la campaña en febrero si estás representando su continuación hasta mayo.

## 8. Controles, decisiones e interfaz

La cámara debe permitir leer el escenario y acercarse a la acción sin perder orientación. Implementá selección clara, órdenes contextuales, vista de rutas, pausa o fin de ronda según el modo, velocidad de resolución y acceso rápido al objetivo.

Usá tutorial contextual, ayudas breves, controles documentados y una interfaz en español consistente. Explicá por qué una orden está bloqueada. Evitá confirmaciones para cada acción rutinaria y mantené una forma clara de cancelar órdenes todavía no resueltas.

La imagen de una carga de caballería y los mapas de campaña orientan la atmósfera. Diseñá la pantalla alrededor del espacio jugable y de la decisión actual. Los paneles de fuentes, biografía y cronología pueden abrirse cuando el jugador quiera consultarlos.

El estado visual debe coincidir con el de las reglas: unidades seleccionadas, posiciones, daños, fatiga, suministros, objetivos y resultado. La información de bandos y estados debe ser comprensible también mediante formas, iconos o texto, sin depender solo del color.

El dramatismo puede surgir de sonido, cámara, animación y consecuencias. Mantené esas secuencias breves y permití acelerarlas cuando se repitan. No bloquees la interacción con una animación que ya terminó o con una respuesta externa pendiente.

## 9. Elegir un motor y comprobar el flujo de desarrollo

Elegí **un motor** según el proyecto existente, hardware, calidad visual, herramientas disponibles, automatización y capacidad de terminar y exportar el juego.

Si partimos de cero, evaluá Godot como opción de desarrollo reproducible por código y CLI. Considerá Unreal si el equipo y el flujo de trabajo permiten aprovechar su producción visual y completar la entrega. Unity tiene sentido si existe una base útil o una integración comprobada que simplifique el trabajo. Fundamentá la elección; no instales los tres para decidir.

Comprobá pronto una escena pequeña ejecutable y exportable con terreno, cámara, una unidad animada y agua cuando corresponda. Esa prueba debe resolver la elección, no convertirse en una comparación interminable entre motores.

Verificá importación de assets, depuración, medición y exportación. Si utilizás Python para automatizar un editor, diferenciá ese trabajo del código de gameplay que debe funcionar en la entrega final.

No cambies silenciosamente el objetivo a una experiencia 2D por comodidad técnica. Si una limitación exige ajustar detalle o plataforma, explicá el compromiso concreto y preservá el juego 3D y la experiencia acordada.

## 10. Arte, assets, animación y sonido

Buscá una dirección realista y cinematográfica coherente: escala, iluminación, materiales, vegetación, ropa, caballos, armas, barco y ambiente. Concentrá detalle donde la cámara y el jugador lo perciban.

Blender y sus herramientas sí son pertinentes para este proyecto. Producí o ajustá modelos, materiales, rigging y animaciones, y verificá su importación en el motor. Una imagen generada puede orientar un diseño o servir como ilustración; las unidades y escenarios interactivos necesitan geometría, colisiones y comportamiento reales.

Los modelos provisionales son válidos para probar reglas. Para la entrega, reemplazá los elementos centrales por assets coherentes, con escala, texturas y animaciones que permitan reconocer jinetes, caballos, soldados y entorno. Informá cualquier recurso central que siga provisional.

Mantené una ficha de procedencia, licencia, autor y modificaciones de cada recurso incorporado. Usá recursos propios, disponibles o con autorización de uso. No extraigas los assets de Civilization para incluirlos en el juego ni publiques automáticamente los documentos de consulta dentro del ejecutable.

Revisá las referencias por episodio: el Güemes de 1806, sus compañeros y su equipamiento no deben aparecer automáticamente como el ejército de 1817. Elegí banderas e insignias compatibles con la fecha. La forma exacta del Justine y detalles no documentados deben identificarse como reconstrucción artística.

Integrá sonidos con función: órdenes recibidas, movimiento, agua, disparos, alerta y objetivos. Ajustá volúmenes y repetición; respetá la licencia de música y audio. Evitá que el efecto cinematográfico oculte información importante para jugar.

## 11. Jev integrado con un papel real y sin frenar la partida

Leé los skills de TypeSafe y el contrato vigente de System One. Implementá una función concreta de Jev en el juego y comprobala en vivo.

La propuesta inicial es un **selector de intención táctica o estratégica** entre opciones legales generadas por las reglas: sostener posición, proteger un abastecimiento, explorar, reagruparse, presionar un sector o replegarse. Elegí el caso que aporte a estos escenarios y documentá la decisión.

Jev recibe un resumen del estado relevante y el conjunto de opciones válidas. Debe usar únicamente la información disponible para ese actor; no le des conocimiento de unidades ocultas que su bando no descubrió.

Las reglas locales conservan autoridad sobre movimiento, navegación, combate, recursos, azar y victoria. Validá la respuesta antes de aplicarla: Jev no inventa acciones, unidades ni ventajas fuera de las reglas.

Hacé solicitudes asíncronas en momentos acotados, como preparación de una ronda o cambio relevante de situación. Definí presupuesto de tiempo y frecuencia medido. No llames por frame ni por cada paso de cada unidad.

Relacioná cada solicitud con partida, ronda y versión de estado. Descartá respuestas tardías o correspondientes a una partida reiniciada. Ante timeout, falta de conexión o respuesta inválida, usá una alternativa local por el mismo contrato y permití completar la partida.

Guardá las decisiones efectivamente aplicadas para depuración y reproducción. Distinguí vivo, caché, simulación y alternativa local. Una prueba con respuestas precargadas no demuestra integración real.

Conservá las credenciales fuera del código, repositorio y ejecutable distribuido. Reutilizá la configuración autorizada cuando exista; si hace falta una clave, dejá un mecanismo claro para incorporarla sin pegarla en el chat. No construyas infraestructura remota innecesaria para una primera entrega local.

La aceptación exige al menos una decisión real de Jev que influya en una partida. Si falta acceso, terminá el juego y las pruebas disponibles, e identificá esa validación como pendiente. No lo declares “Jev funcionando” por haber instalado su skill.

## 12. Reglas, datos, persistencia y reutilización

Separá contenido histórico, definición de escenarios, estado/reglas, presentación 3D e integración con Jev. Elegí estructuras simples que permitan añadir otra misión sin duplicar el juego entero.

Las órdenes deben tener una validación y resolución consistentes. Definí límites y estados terminales para evitar unidades bloqueadas, recursos negativos, objetivos imposibles o partidas que no terminan.

La navegación debe respetar terreno, agua, obstáculos y cambios de fase. Los grupos necesitan mantenerse controlables aunque una unidad individual encuentre un obstáculo. Comprobá la recuperación de esos casos.

Conservá semilla, órdenes y decisiones externas necesarias para reproducir las reglas principales. No hace falta prometer determinismo de cada efecto de partículas o de toda la física visual.

Implementá guardado versionado con escenario, fase, unidades, recursos y progreso relevantes. Cargar o reiniciar no debe duplicar efectos, repetir órdenes completadas ni aplicar una respuesta vieja de Jev.

Mantené configuraciones de gráficos, sonido, controles y ayudas separadas de la partida. Prepará perfiles de calidad y recursos escalables. Evitá añadir cuentas, multiplayer, economías permanentes o servicios de la serie que no sean necesarios para estos dos escenarios.

## 13. Secuencia de implementación

Entregá primero un informe breve: estado del proyecto, materiales revisados, decisiones históricas, motor propuesto, herramientas disponibles y plan. Después continuá sin esperar una confirmación genérica.

1. **Base técnica y reglas:** proyecto ejecutable, escena 3D, cámara, selección, movimiento, una orden y exportación comprobada.
2. **Justine completo:** desde iniciar la misión hasta ganar, perder y reiniciar, con la bajante y la captura afectando reglas reales.
3. **Campaña de La Serna completa:** mapa, rondas, abastecimiento, hostigamiento, retirada, Humahuaca y guardado, reutilizando componentes.
4. **Jev y herramientas verificadas:** decisión real usada, alternativa local probada y evidencia de investigación aplicada con REA. Esta integración debe desarrollarse junto con las reglas pertinentes, no quedar como un adorno final.
5. **Arte, sonido, ritmo y rendimiento:** reemplazo de recursos provisionales centrales, pruebas integradas, ajustes y exportación de entrega.

Mostrá avances mediante capturas o video de gameplay real cuando la herramienta lo permita. Conservá un registro breve de decisiones y pendientes. Priorizá cerrar cada recorrido antes de añadir variantes o más batallas.

Los bloqueos externos deben describirse con precisión. Avanzá con las partes independientes y evitá convertir una limitación puntual en una pausa de todo el proyecto.

## 14. Verificación y criterios de aceptación

Usá las pruebas del motor y automatización pertinente para reglas, persistencia y errores. Complementalas con ejecución visual: compilar o correr sin ventana no demuestra que la cámara, selección o escena se puedan usar.

| Prueba | Resultado requerido |
| --- | --- |
| Abrir la entrega | Se inicia sin necesitar el editor y permite elegir ambos escenarios. |
| Primeros pasos | Objetivo comprensible, controles visibles y primera orden con respuesta clara. |
| Espacio 3D | Terreno, unidades, cámara, navegación y acciones interactúan de forma consistente. |
| Justine | La bajante cambia la situación; aproximación y captura pueden completarse; victoria y derrota funcionan. |
| Campaña del norte | Recursos, exploración y hostigamiento afectan la capacidad de invasión; ocupación y victoria son estados distintos. |
| Alternativas | Decisiones diferentes producen consecuencias observables y hay estrategias razonables que se puedan aprender. |
| Humahuaca e historia | Atribución a Arias, contexto y fechas respaldados; ficciones del diseño identificadas en documentación. |
| Pausa y resolución | Órdenes, velocidad y transiciones funcionan sin bloqueos ni duplicaciones. |
| Navegación | Obstáculos y cambios de agua no dejan una partida imposible de completar por errores de movimiento. |
| Guardar/cargar/reiniciar | Se conserva el progreso pertinente y no se aplican acciones o respuestas antiguas. |
| Jev disponible | Una selección real se valida y modifica el comportamiento del juego. |
| Jev caído o lento | La alternativa local mantiene la partida operativa; el diagnóstico informa el estado correcto. |
| Calidad visual | Las capturas y la ejecución muestran assets centrales coherentes y legibles en su contexto histórico. |
| Entrega completa | Código, recursos, ejecutable, instrucciones, pruebas y limitaciones corresponden a la misma versión. |

Probá partidas ganadas y perdidas y un recorrido de continuación. Medí duración, carga, memoria y tiempos de cuadro en escenas representativas. Definí el objetivo de rendimiento para el equipo comprobado; como orientación, buscá 60 FPS y un perfil reducido de 30 FPS cuando esté justificado. Informá configuración y mediciones, sin presentar metas como resultados obtenidos.

Revisá input, textos, escalado de interfaz y legibilidad. Diferenciá tests simulados, ejecución real, pruebas automatizadas y observaciones de jugabilidad. Si no podés acceder a la GPU o a la interfaz, explicitá qué parte de QA sigue pendiente.

## 15. Entrega y continuidad

Entregá el proyecto fuente y la versión lista para jugar en el destino verificado: Windows local por defecto, o el destino previamente acordado que hayas confirmado. Incluí sus archivos necesarios, en una carpeta propia y con instrucciones breves para abrir, jugar, configurar y reconstruir la entrega.

La documentación debe incluir diseño del ciclo de juego, controles, escenarios, matriz histórica, fuentes, licencias de assets, investigación con REA, estado de Jev, versiones de herramientas y resultados de pruebas. Conservá las referencias originales como material de consulta, distinguiéndolas de los recursos que se distribuyen con el juego.

Hacé commits claros y coherentes. Usá el remoto solo si está verificado y corresponde a este proyecto, dentro del acceso autorizado. No publiques material privado, credenciales ni recursos de terceros sin permiso de distribución. No uses la carpeta de Civilization como destino de código o build.

En la entrega final explicá:

- Qué puedo jugar y cómo iniciar cada escenario.
- Qué decisiones y mecánicas se implementaron y qué resultados producen.
- Qué precisión histórica se comprobó y qué elementos son reconstrucción o dramatización.
- Qué aprendiste de la referencia y dónde lo aplicaste.
- Qué función cumple Jev y cuál fue su prueba real.
- Qué herramientas y assets quedaron efectivamente integrados.
- Qué rendimiento y duración mediste, en qué equipo y con qué configuración.
- Qué falta, si existe un bloqueo, sin presentar una escena parcial como ambos escenarios terminados.

**Empezá identificando el proyecto, leyendo los materiales y preparando las capacidades. Mostrame ese primer estado y continuá hasta entregar los dos escenarios jugables, con una identidad visual 3D propia, ritmo ágil y funcionamiento comprobado.**