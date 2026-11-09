# Güemes — Juegos de la Patria

**Versión 0.5.0-preview2 — 9 de noviembre de 2026.** Tres capítulos jugables de punta a punta y encadenados: **I · La Justina (1806)**, **II · Humahuaca: el depósito de la retaguardia (1817)** y **III · Sostener el norte (1816–1817)**, con pantalla final de campaña. Esta versión suma el rediseño visual integral (`visual/r1`, fases F1–F6) sobre la entrega `0.5.0-preview1`: marcas sutiles en el suelo y rótulos de una línea, cámara más cercana con paneo inicial desde el buque en la Justina, formaciones a escala real según la dotación de cada grupo, caballos criollos animados por velocidad real (zaino, alazán, tordillo, overo), jinetes de 1806 y 1817 y figuras de a pie animadas (gauchos con tacuara o carabina, voluntarios de 1806, arrieros y realistas), kit propio de 26 edificios del territorio (adobe, torta, cal, pirca y teja apagada), texturas fotográficas CC0 de terreno (Poly Haven), relieve real de Copernicus GLO-30/90 en el horizonte de Humahuaca y en el Norte, y prueba en vivo de Jev/TypeSafe verificada (`jev-1.14.0`). Qué cambió, cómo se probó y qué falta: `docs/equipo/ENTREGA.md` y `docs/equipo/DICTAMEN_QA.md`.

Proyecto independiente en Godot 4.7.2 (GDScript, Forward+), exportado para Windows x64. **Nadie jugó a mano esta versión:** la probaron scripts que juegan por la entrada real (teclado y clics) y revisores automáticos; la diversión para personas reales queda para una prueba humana.

## Abrir en Windows

1. Extraé el ZIP de Windows en una carpeta propia.
2. Abrí **PatriaGuemes.exe**. El paquete del juego está embebido en el ejecutable.
3. Elegí **I · La Justina** (empezá acá), **II · Humahuaca** (siempre abierto; recomendado tras la Justina) o **III · Sostener el norte** (se abre al ganar la Justina o Humahuaca). Al ganar un capítulo, el botón principal del parte lleva al siguiente.

No hace falta instalar el editor de Godot, Blender, REA, Python ni un MCP para jugar. No hace falta una clave de Jev para completar los escenarios. Los guardados y ajustes se escriben en `%APPDATA%\Godot\app_userdata\Güemes — Juegos de la Patria`, fuera de la carpeta del ejecutable. La instalación de Civilization VII no forma parte del proyecto.

El destino es Windows x64. El EXE de **0.1.0** completó ambos escenarios de entonces (I y III) bajo Wine 11.0 en Linux (`docs/VERIFICACION.md`); esa evidencia y la cifra de 16–20 FPS en un servidor sin GPU **son de 0.1.0 y no cubren** los modelos PBR, la interfaz ni el audio de 0.2.0.

Para **0.2.0-alfa** se midió, en una PC con Windows 11, Ryzen 9 7950X y RTX 3080 Ti a 1440×900, la escena real ejecutada desde el editor con Forward+ (hasta 800–1200 FPS sin V-Sync) y con Compatibilidad, y se recorrieron los escenarios I y III (los únicos de entonces) hasta su desenlace por script. **No se probó una partida humana en Windows nativo, ni audio audible, ni Jev vivo**; el EXE de 0.2.0 solo pasó una prueba de arranque automática. Detalle y límites en `docs/VERIFICACION_FASE2.md`. El juego permite cambiar el detalle en Ajustes.

## Los tres escenarios

### I. Tomar la Justina · 1806

> Ronda de diversión R1: tarjeta de objetivo de 30 s, guía de 4 pasos, parte de derrota que enseña con «Reintentar · mismo río», diario del Bañado, medallas, Norte con candado hasta ganar y feedback (cuenta regresiva del buque, destellos, pausa automática). Ver `docs/CONTROLES.md`.

**Tiempo real con pausa** (no por turnos): el reloj corre solo y la cabecera lo dice siempre («TIEMPO REAL · ▶ ×1» o «‖ EN PAUSA»). Con el tiempo detenido podés seguir dando órdenes. Cinco agrupaciones parten de la ribera: Güemes y jinetes (tradición), Voluntarios, Caballería de reserva y dos exploradores a pie. La bajante cambia la profundidad y el tránsito. Podés elegir el banco central, más corto y expuesto, o el rodeo sur, más largo y protegido. Las órdenes de aproximación preparan el movimiento, esperan en la ribera si hace falta y reanudan el cruce al habilitarse.

**Cómo se juega, en una frase:** tomá el buque Justina antes de que suba el río: medí el agua con un explorador, esperá a que el vado ceda, pedí carga a Liniers y abordá; si perdés, reintentás con el mismo mapa y lo que anotaste.

**Primeros 60 segundos:** Espacio inicia/pausa; 4 o 5 + Z sondea el agua; 1 + K señala a Liniers; N o clic derecho ordena el abordaje; coma rechaza el contraataque (14 s); F1 o ? es la ayuda. El detalle está en `docs/CONTROLES.md`.

Al llegar al buque se representa un desmontaje de 12 segundos y la resolución de la captura; los caballos quedan fuera de la cubierta. La fuerza conservada afecta el progreso. Perdés si las agrupaciones se dispersan o se cierra la oportunidad sin capturar. No se simula combate individual en cubierta.

**Para empezar:** mirá a la izquierda tus cinco agrupaciones (tres grupos y dos exploradores; clic o teclas 1-5 para elegirlas) y el **Despliegue previo**. El panel inferior dice siempre el siguiente paso: reconocer el fondo con un explorador (4 o 5, tecla Z), señalar a Liniers (K) para obtener la orden de avance y después cargar y abordar (N) o trazar la ruta con clic derecho. Espacio pausa y reanuda; X cancela una orden y Ctrl+Z la deshace. F1 o ? abren la ayuda.

Los tiempos y tasas de victoria de los recorridos automatizados están en `docs/DISENO_JUSTINA.md` y en `evidence/`; son resultados del balance actual, no mediciones de jugadores.

### II. Humahuaca: el depósito de la retaguardia · 1817

Hacia el 1 de marzo de 1817, unas 150 personas al mando de Manuel Eduardo Arias atacaron los depósitos que el ejército de La Serna tenía en Humahuaca, en su retaguardia: una batería, un cuartel y la posta con la pólvora. Güemes conducía desde Salta y no estuvo en el asalto. El nivel recrea esa noche en **tiempo real con pausa**: preparación, aproximación con lluvia, señal, ataque a los tres frentes a la vez y extracción al alba por el vado del este, antes de que llegue un refuerzo que es recurso del juego (en la realidad no hubo refuerzo inmediato). Cinco agrupaciones (las partidas de Rodríguez, Portal y Arias, los reconocedores y el arreo de mulas), un parte de victoria o derrota que enseña, reintento con el mismo mundo, diario, guardado y carga. Cada dato lleva su etiqueta de fuente (● documentado, ◇ razonado, ◆ discutido, ○ sin datos, ▲ diseño) y el epílogo fechado separa «en la realidad» de «en tu partida».

**Estado:** se juega entero desde el menú y desde el EXE de 0.5.0-preview1; la apertura muestra la quebrada y se salta con cualquier tecla; al elegir una partida fuera de la vista la cámara se acerca a ella (segunda pulsación: acercar a 240 m). Límite de diseño conocido: quien sigue la guía gana con bronce; la exigencia está en la plata y el oro (`docs/equipo/REFERENTES_Y_DECISIONES.md`).

**Para empezar:** mirá el **siguiente paso** (abajo): una sola cosa por vez, con su botón y su tecla. Elegí una agrupación con **1 a 5**, mandá a los reconocedores (4) a mirar los frentes (**R**), llevá cada partida a su puesto (**P**), da la señal (**F**) cuando estén en posición y atacá (**T**). Tomados los tres frentes, cargá el arreo (**L**), destruí lo que no entra (**X**) y salí por el vado (**V**). **Espacio** pausa; **F1** explica todo. Teclas completas en `docs/CONTROLES.md` y `docs/humahuaca/CONTROLES.md`.

### III. Sostener el norte · 1816–1817

Campaña de hasta catorce rondas, sobre ocho sectores simplificados. Cada agrupación prepara una orden: mover, reconocer, proteger víveres, hostigar, reponer fuerzas, replegarse o, en el caso de Arias, operar en Humahuaca desde marzo.

El objetivo es volver insostenible la invasión afectando abastecimiento, cohesión y comunicaciones. La ocupación temporal de Salta no termina la campaña. La protección de recursos sostiene a la población y limita lo que puede recuperar el adversario; la pasividad pierde.

**Para empezar:** seleccioná Arias, elegí Quebrada y reconocé el sector. Organizá también la protección de víveres con la partida del valle. Podés cambiar o cancelar todas las órdenes antes de resolver. Cada ronda se guarda automáticamente.

Las pruebas comprobaron dos estrategias ganadoras distintas, en rondas 10 y 11, y derrota por pasividad en la ronda 12. Una retirada anterior a mayo se identifica como desenlace alternativo. La duración humana objetivo de 20–35 minutos sigue sin validación con jugadores.

## Cómo ganar en 3 minutos (Justina)

1. Objetivo: tomar el buque Justina, varado en el río, antes de que suba la marea. Si perdés, volvés a jugar con el mismo río y con lo que anotaste.
2. Elegí al explorador (tecla 4, aro dorado), apretá **Z** y hacé clic en el agua para medirla. Mientras el vado cede, abastecé munición (**J**).
3. Cuando cede el vado: elegí un grupo (1 a 3), **K** para pedir carga a Liniers y **N** (o clic derecho en el buque) para cargar. Sin permiso existe «Cargar sin orden»: captura 20 % más lenta y sin oro.
4. Rechazá los contraataques (**,**). Mirá la barra de tiempo: la marca roja «sin retorno» es el último momento para cargar.
5. Si perdés: «Reintentar desde el cruce» te devuelve antes del vado en segundos, con lo ya sondeado; «Reintentar (mismo mapa)» empieza de cero.

Resoluciones con QA de interfaz real (ventana): 1280x720, 1440x900, 1920x1080 y 2560x1440 (renderer Forward+, calidad media). Compatibility y calidad alta no se probaron en esta ronda.

## Controles principales

| Acción | Control |
|---|---|
| Desplazar cámara | WASD o flechas |
| Acercar / alejar | Rueda |
| Girar | Q / E; arrastrar con botón central |
| Seleccionar grupo | Clic o teclas 1, 2, 3 |
| Seleccionar las tres agrupaciones, Justina | Mayús+clic suma, Ctrl+clic alterna, o arrastrar una caja |
| Seleccionar los tres grupos, Justina | Ctrl+A o tecla ` |
| Seleccionar explorador, Justina | 4 y 5 (Explorador 1 y 2), o su ficha a la izquierda |
| Mover | Clic derecho |
| Pausa o reanudar (Justina, tiempo real) / resolver ronda (norte) | Espacio |
| Velocidad de la Justina (×1, ×2, ×4) | Botones ×1 ×2 ×4, F2 / F3 / F4 o + / − |
| Ciclar la selección (Justina; en el Norte Tab recorre la interfaz) | Tab |
| Deshacer la última orden (Justina) | Ctrl+Z |
| Rechazar contraataque / evacuar heridos (Justina) | Coma (,) / punto (.) |
| Cancelar orden | X |
| Guardar / cargar | F5 / F9 |
| Reiniciar escenario | R |
| Enfocar objetivo (solo Norte; en la Justina, O es «Distraer con fuego» y 0 «Ver todo») | O |
| Ayuda (Justina: F1 o ?) / fuentes (Norte; en la Justina H es «Marcar vado») | F1 / H |
| Pantalla completa | F11 |

El detalle, la ayuda contextual y el sonido se cambian en Ajustes. El perfil bajo reduce resolución 3D, cantidad de figuras decorativas, sombras y antialiasing; la interfaz mantiene su resolución. Las cifras de las agrupaciones representan fuerzas agregadas, no el número literal de figuras visibles.

El nivel II tiene su propia tabla (todo se puede hacer con el mouse; las teclas son atajos): Espacio pausa o sigue el tiempo; F2, F3 y F4 (o + y −) fijan la velocidad ×1, ×2 o ×4; 1 a 5 eligen las agrupaciones (otra vez: centran la cámara); Tab pasa a la siguiente; Ctrl+Z deshace; W A S D, Q y E, RePág y AvPág, Inicio y la rueda mueven la cámara; M agranda el minimapa; G mover, P a su puesto, T atacar, C socorrer, R reconocer, L cargar, X destruir, V salir por el vado, F dar la señal, H sostener, Supr cancelar; Mayús, Ctrl y Alt con el clic suman una parada o cambian el ritmo; el clic derecho da la orden más lógica. Esc cancela o abre el menú de pausa; F1 abre la ayuda; F5 y F9 guardan y cargan. Detalle en `docs/CONTROLES.md` y `docs/humahuaca/CONTROLES.md`.

## Historia y límites

La participación personal de Güemes en la toma de la Justina es una atribución tradicional no probada, explicitada en el juego. Se usa Justina como denominación consistente y se explica la variante Justine (presente en las fuentes). El buque es un mercante armado reconstruido, no el HMS Leander. No se trasladan banderas argentinas ni Infernales a 1806.

Humahuaca corresponde a Manuel Eduardo Arias, el 1 de marzo de 1817 (otras fuentes dicen el 2). La salida histórica de Salta se sitúa en los primeros días de mayo, distinguiendo movimientos del 4 y el parte del 5. San Martín aparece como contexto de la campaña continental; no llega como refuerzo a Salta.

En el nivel II, Güemes conduce desde Salta y recibe el parte: no está en el asalto, no se lo llama «coronel mayor» ni «general», y el golpe no fue consecuencia de Chacabuco. La planta del pueblo, la posición del cuartel, la posta y la torre, el vestuario de ambos bandos y las cotas son diseño o no tienen datos; el relieve es dato actual, no restitución del suelo de 1817; el refuerzo realista inmediato no ocurrió. La recuperación de las seis piezas entre el 9 y el 16 de marzo es versión realista del Diario del Estado Mayor y de las Memorias de García Camba, no del oficio de La Serna. Detalle en `docs/humahuaca/HISTORIA.md` y `docs/historia/MATRIZ_HISTORICA.md` (sección J).

La matriz histórica separa documento, interpretación, tradición y ficción jugable. Rutas, costas, escalas, cantidades, métricas, tiempos y uniformes son simplificaciones o reconstrucciones. Los originales históricos y las imágenes conceptuales no se redistribuyen dentro del ejecutable.

## Jev y REA

Jev elige intenciones del adversario entre opciones legales. Las reglas locales controlan movimiento, azar, combate, recursos y victoria. El cliente asíncrono limita la espera a dos segundos, valida estado y respuesta, descarta decisiones viejas y registra la alternativa local de forma explícita.

Para habilitar una clave existente, consultá `docs/CONFIGURAR_JEV_WINDOWS.md` y `tools/configurar_jev.ps1`, incluidos en ambos paquetes. No pegues credenciales en el código ni en el chat. La validación viva sigue pendiente.

REA 6.8.0 se utilizó realmente para inspección PE del runtime y del ejecutable final. La ruta de Civilization aportada no era accesible desde el entorno Linux remoto. Las conclusiones de interacción se apoyan en documentación pública oficial; no se presentan como observación de esa instalación.

## Documentación

- `docs/CONTROLES.md`: primera partida y controles.
- `docs/DISENO_REGLAS.md`: sistemas, balance y persistencia.
- `docs/historia/MATRIZ_HISTORICA.md` y `FUENTES.md`: evidencia y decisiones históricas.
- `docs/ASSETS.md`: geometría, animación, audio y licencias.
- `docs/REA.md`, `docs/JEV.md`, `docs/HERRAMIENTAS.md`: integraciones y límites.
- `docs/VERIFICACION.md`: pruebas, rendimiento, hardware y aceptación de 0.1.0.
- `docs/VERIFICACION_FASE2.md`: mediciones, recorridos, hallazgos y pendientes de 0.2.0-alfa.
- `docs/WINE_QA.md`: ejecución del EXE final y diagnóstico de compatibilidad de Wine.
- `docs/RECONSTRUIR.md`: reconstruir con Godot 4.7.2.
- `docs/CREDITOS.md`: créditos y licencias de los materiales de referencia y del nivel II (SRTM, OpenStreetMap, Copernicus).
- Nivel II: `docs/DISENO_HUMAHUACA.md` (diseño), `docs/CONTRATO_HUMAHUACA.md` (contrato entre pistas), `docs/QA_NIVEL2.md` (control de calidad), `docs/humahuaca/` (reglas, historia, procedencia, relieve, visual, controles, créditos, backlog, traza, `RETOMAR.md` con el estado y el plan).
- `evidence/`: registros, resultados y capturas de ejecución real.

## Reconstruir

Con Godot 4.7.2 y sus plantillas de exportación instalados:

```sh
python tools/build_release.py --godot /ruta/a/godot --target windows
```

La exportación reproduce el juego con los GLB y WAV incluidos; no requiere Blender ni regenerar los recursos. El código de generación se entrega aparte para editarlos. El repositorio está en GitHub (`nicospum/guemes`): `main` conserva la alfa 0.3.0 con la etiqueta `v0.1.0` intacta, y el nivel II se desarrolla en la rama `humahuaca-r1`. Para el nivel II, las pruebas de datos corren sin ventana: `godot --headless --path . --script tests/test_hx_data.gd`.
