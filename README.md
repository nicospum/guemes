# Güemes — Juegos de la Patria

**Versión 0.3.0-alfa (preview 5 en curso: ronda de diversión R2, interfaz y sensación de juego; base preview 4) — alfa jugable, 30 de octubre de 2026.** Preview 4 aclara los controles de la Justina: tiempo real con pausa y velocidades ×1/×2/×4 siempre indicado, panel lateral con las cinco agrupaciones, acciones contextuales con motivo, rutas con destino y ETA, deshacer (Ctrl+Z), avisos con pausa automática, despliegue previo y tutorial de seis pasos. Ronda 5 de interfaz: un solo mensaje guía a la vez, «Cargar y abordar» guía al sondeo previo en lugar de fallar, Señalar a Liniers se rotula como marcha, interfaz legible a 720p, diálogos que entran en pantalla y briefing con «Jugar». Respecto de 0.2.0: casas, iglesias, árboles y rocas 3D ya usados en escena; balance del norte (victoria no antes de la ronda 10); órdenes que no ahogan unidades; validación de coherencia de guardados; interfaz adaptable; sin fugas de recursos al salir. (La entrega 0.1.0 conserva su verificación en `docs/VERIFICACION.md`; la de 0.2.0 está en `docs/VERIFICACION_FASE2.md`.)

Dos escenarios completos en sus reglas, con selección, objetivos, victoria, derrota, reinicio y persistencia. Proyecto independiente en Godot 4.7.2. La entrega incluye código y exportación Windows x64. El acabado es 3D estilizado de detalle medio: la fidelidad cinematográfica solicitada sigue pendiente. Jev está integrado por contrato y alternativa local, pero no se validó una decisión viva por falta de credencial.

## Abrir en Windows

1. Extraé el ZIP de Windows en una carpeta propia.
2. Abrí **PatriaGuemes.exe**. El paquete del juego está embebido en el ejecutable.
3. Elegí **I · El río ofrece una oportunidad** o **II · Sostener el norte**.

No hace falta instalar el editor de Godot, Blender, REA, Python ni un MCP para jugar. No hace falta una clave de Jev para completar los escenarios. Los guardados y ajustes se escriben en `%APPDATA%\Godot\app_userdata\Güemes — Juegos de la Patria`, fuera de la carpeta del ejecutable. La instalación de Civilization VII no forma parte del proyecto.

El destino es Windows x64. El EXE de **0.1.0** completó ambos escenarios bajo Wine 11.0 en Linux (`docs/VERIFICACION.md`); esa evidencia y la cifra de 16–20 FPS en un servidor sin GPU **son de 0.1.0 y no cubren** los modelos PBR, la interfaz ni el audio de 0.2.0.

Para **0.2.0-alfa** se midió, en una PC con Windows 11, Ryzen 9 7950X y RTX 3080 Ti a 1440×900, la escena real ejecutada desde el editor con Forward+ (hasta 800–1200 FPS sin V-Sync) y con Compatibilidad, y se recorrieron los dos escenarios hasta su desenlace por script. **No se probó una partida humana en Windows nativo, ni audio audible, ni Jev vivo**; el EXE de 0.2.0 solo pasó una prueba de arranque automática. Detalle y límites en `docs/VERIFICACION_FASE2.md`. El juego permite cambiar el detalle en Ajustes.

## Los dos escenarios

### I. Tomar la Justina · 1806

> Ronda de diversión R1: tarjeta de objetivo de 30 s, guía de 4 pasos, parte de derrota que enseña con «Reintentar · mismo río», diario del Bañado, medallas, Norte con candado hasta ganar y feedback (cuenta regresiva del buque, destellos, pausa automática). Ver `docs/CONTROLES.md`.

**Tiempo real con pausa** (no por turnos): el reloj corre solo y la cabecera lo dice siempre («TIEMPO REAL · ▶ ×1» o «‖ EN PAUSA»). Con el tiempo detenido podés seguir dando órdenes. Cinco agrupaciones parten de la ribera: Güemes y jinetes (tradición), Voluntarios, Caballería de reserva y dos exploradores a pie. La bajante cambia la profundidad y el tránsito. Podés elegir el banco central, más corto y expuesto, o el rodeo sur, más largo y protegido. Las órdenes de aproximación preparan el movimiento, esperan en la ribera si hace falta y reanudan el cruce al habilitarse.

**Cómo se juega, en una frase:** tomá el buque Justina antes de que suba el río: medí el agua con un explorador, esperá a que el vado ceda, pedí carga a Liniers y abordá; si perdés, reintentás con el mismo mapa y lo que anotaste.

**Primeros 60 segundos:** Espacio inicia/pausa; 4 o 5 + Z sondea el agua; 1 + K señala a Liniers; N o clic derecho ordena el abordaje; coma rechaza el contraataque (14 s); F1 o ? es la ayuda. El detalle está en `docs/CONTROLES.md`.

Al llegar al buque se representa un desmontaje de 12 segundos y la resolución de la captura; los caballos quedan fuera de la cubierta. La fuerza conservada afecta el progreso. Perdés si las agrupaciones se dispersan o se cierra la oportunidad sin capturar. No se simula combate individual en cubierta.

**Para empezar:** mirá a la izquierda tus cinco agrupaciones (tres grupos y dos exploradores; clic o teclas 1-5 para elegirlas) y el **Despliegue previo**. El panel inferior dice siempre el siguiente paso: reconocer el fondo con un explorador (4 o 5, tecla Z), señalar a Liniers (K) para obtener la orden de avance y después cargar y abordar (N) o trazar la ruta con clic derecho. Espacio pausa y reanuda; X cancela una orden y Ctrl+Z la deshace. F1 o ? abren la ayuda.

Los tiempos y tasas de victoria de los recorridos automatizados están en `docs/DISENO_JUSTINA.md` y en `evidence/`; son resultados del balance actual, no mediciones de jugadores.

### II. Sostener el norte · 1816–1817

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

## Historia y límites

La participación personal de Güemes en la toma de la Justina es una atribución tradicional no probada, explicitada en el juego. Se usa Justina como denominación consistente y se explica la variante Justine (presente en las fuentes). El buque es un mercante armado reconstruido, no el HMS Leander. No se trasladan banderas argentinas ni Infernales a 1806.

Humahuaca corresponde a Manuel Eduardo Arias, el 1 de marzo de 1817. La salida histórica de Salta se sitúa en los primeros días de mayo, distinguiendo movimientos del 4 y el parte del 5. San Martín aparece como contexto de la campaña continental; no llega como refuerzo a Salta.

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
- `evidence/`: registros, resultados y capturas de ejecución real.

## Reconstruir

Con Godot 4.7.2 y sus plantillas de exportación instalados:

```sh
python tools/build_release.py --godot /ruta/a/godot --target windows
```

La exportación reproduce el juego con los GLB y WAV incluidos; no requiere Blender ni regenerar los recursos. El código de generación se entrega aparte para editarlos. No hay un remoto Git configurado para este proyecto ni se publicó en un servicio externo.
