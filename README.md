# Güemes — Juegos de la Patria

**Versión 0.1.0 — alfa jugable, 28 de octubre de 2026.**

Dos escenarios completos en sus reglas, con selección, objetivos, victoria, derrota, reinicio y persistencia. Proyecto independiente en Godot 4.7.2. La entrega incluye código y exportación Windows x64. El acabado es 3D estilizado de detalle medio: la fidelidad cinematográfica solicitada sigue pendiente. Jev está integrado por contrato y alternativa local, pero no se validó una decisión viva por falta de credencial.

## Abrir en Windows

1. Extraé el ZIP de Windows en una carpeta propia.
2. Abrí **PatriaGuemes.exe**. El paquete del juego está embebido en el ejecutable.
3. Elegí **I · El río ofrece una oportunidad** o **II · Sostener el norte**.

No hace falta instalar el editor de Godot, Blender, REA, Python ni un MCP para jugar. No hace falta una clave de Jev para completar los escenarios. Los guardados y ajustes se escriben en `%APPDATA%\Godot\app_userdata\Güemes — Juegos de la Patria`, fuera de la carpeta del ejecutable. La instalación de Civilization VII no forma parte del proyecto.

El destino es Windows x64. El EXE final completó ambos escenarios hasta la victoria bajo Wine 11.0 en Linux; la exportación y las evidencias se detallan en `docs/VERIFICACION.md`. Todavía no se validó su ejecución en una PC Windows nativa.

En el servidor remoto sin GPU acelerada, el perfil bajo midió aproximadamente 16–20 FPS; no alcanzó la meta de 30 FPS. El rendimiento y el audio en tu PC Windows requieren una prueba en ese equipo. El juego permite cambiar el detalle en Ajustes.

## Los dos escenarios

### I. Tomar el Justine · 1806

Tiempo real con pausa. Tres agrupaciones de caballería parten de la ribera. La bajante cambia la profundidad y el tránsito. Podés elegir el banco central, más corto y expuesto, o el rodeo sur, más largo y protegido. Las órdenes de aproximación preparan el movimiento, esperan en la ribera si hace falta y reanudan el cruce al habilitarse.

Al llegar al buque se representa un desmontaje de 12 segundos y la resolución de la captura; los caballos quedan fuera de la cubierta. La fuerza conservada afecta el progreso. Perdés si las agrupaciones se dispersan o se cierra la oportunidad sin capturar. No se simula combate individual en cubierta.

**Para empezar:** tecla 4, elegí una aproximación y pulsá Espacio. Podés cambiar órdenes por grupo con 1/2/3, cancelar con X, reagruparte o mover con clic derecho. Tab alterna 1× y 3×.

En recorridos automatizados, la vía directa ganó en 7 min 53,75 s simulados y el rodeo sur en 9 min 7 s. Son resultados del balance actual, no mediciones de jugadores.

### II. Sostener el norte · 1816–1817

Campaña de hasta catorce rondas, sobre ocho sectores simplificados. Cada agrupación prepara una orden: mover, reconocer, proteger víveres, hostigar, reponer fuerzas, replegarse o, en el caso de Arias, operar en Humahuaca desde marzo.

El objetivo es volver insostenible la invasión afectando abastecimiento, cohesión y comunicaciones. La ocupación temporal de Salta no termina la campaña. La protección de recursos sostiene a la población y limita lo que puede recuperar el adversario; la pasividad pierde.

**Para empezar:** seleccioná Arias, elegí Quebrada y reconocé el sector. Organizá también la protección de víveres con la partida del valle. Podés cambiar o cancelar todas las órdenes antes de resolver. Cada ronda se guarda automáticamente.

Las pruebas comprobaron dos estrategias ganadoras distintas, en rondas 10 y 11, y derrota por pasividad en la ronda 12. Una retirada anterior a mayo se identifica como desenlace alternativo. La duración humana objetivo de 20–35 minutos sigue sin validación con jugadores.

## Controles principales

| Acción | Control |
|---|---|
| Desplazar cámara | WASD o flechas |
| Acercar / alejar | Rueda |
| Girar | Q / E; arrastrar con botón central |
| Seleccionar grupo | Clic o teclas 1, 2, 3 |
| Seleccionar todos, Justine | 4 |
| Mover | Clic derecho |
| Pausa / resolver ronda | Espacio |
| Velocidad 1× / 3× | Tab |
| Cancelar orden | X |
| Guardar / cargar | F5 / F9 |
| Reiniciar escenario | R |
| Enfocar objetivo | O |
| Controles / fuentes | F1 / H |
| Pantalla completa | F11 |

El detalle, la ayuda contextual y el sonido se cambian en Ajustes. El perfil bajo reduce resolución 3D, cantidad de figuras decorativas, sombras y antialiasing; la interfaz mantiene su resolución. Las cifras de las agrupaciones representan fuerzas agregadas, no el número literal de figuras visibles.

## Historia y límites

La participación personal de Güemes en la toma del Justine es una atribución tradicional no probada, explicitada en el juego. Se usa Justine como denominación consistente y se explica la variante Justina. El buque es un mercante armado reconstruido, no el HMS Leander. No se trasladan banderas argentinas ni Infernales a 1806.

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
- `docs/VERIFICACION.md`: pruebas, rendimiento, hardware y aceptación.
- `docs/WINE_QA.md`: ejecución del EXE final y diagnóstico de compatibilidad de Wine.
- `docs/RECONSTRUIR.md`: reconstruir con Godot 4.7.2.
- `evidence/`: registros, resultados y capturas de ejecución real.

## Reconstruir

Con Godot 4.7.2 y sus plantillas de exportación instalados:

```sh
python tools/build_release.py --godot /ruta/a/godot --target windows
```

La exportación reproduce el juego con los GLB y WAV incluidos; no requiere Blender ni regenerar los recursos. El código de generación se entrega aparte para editarlos. No hay un remoto Git configurado para este proyecto ni se publicó en un servicio externo.
