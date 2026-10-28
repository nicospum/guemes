# Prueba de entrada real del sistema operativo

## Alcance y entorno

Se ejecutó el juego Godot en una ventana X11 real, controlada con `xdotool`, dentro de una pantalla virtual Xvfb aislada (`:105`). No se utilizó `--qa`, no se ejecutó en modo headless y no se llamaron métodos de `main.gd` para provocar las acciones. Los clics, teclas y movimientos de rueda llegaron a la ventana por el sistema operativo. Las capturas se obtuvieron de esa pantalla con `PIL.ImageGrab`.

- Motor: Godot **4.7.2**, renderer Compatibility / OpenGL 4.5.
- Equipo de prueba: entorno remoto Linux; Mesa **llvmpipe**, render por software.
- Resolución de ventana y pantalla: **1280 × 800**.
- Perfil: **baja**, sonido silenciado, mando local seleccionado.
- Límite configurado: **30 FPS**. Es un límite de ejecución, no una medición de rendimiento.
- Partidas y preferencias aisladas en `.runtime/inputqa`; no se utilizaron las de la ejecución principal.
- Intervalo de ejecución gráfica: **28 de octubre de 2026, 13:35:14–13:39:39 UTC** (**10:35:14–10:39:39 de Buenos Aires**). Este intervalo debe excluirse de cualquier benchmark concurrente.

La sesión cerró mediante el botón **Salir** del juego con código **0**. El servidor Xvfb de prueba también terminó. No aparecieron errores de scripts ni del motor durante el recorrido; hubo una advertencia del backend porque no permite configurar V-Sync.

## Resultados corroborados

Las acciones se contrastaron con capturas y con los archivos JSON que el propio juego escribió al pulsar **F5**. El resumen verificable está en `evidence/input-os/input-os-report.json`: **17 de 17 comprobaciones pasan**. La comparación de posiciones tras cargar usa tolerancia `10⁻⁶`; la diferencia máxima observada fue aproximadamente `1,8 × 10⁻¹⁵`, propia del recorrido de números decimales por JSON.

| Recorrido | Acción real | Evidencia observada |
| --- | --- | --- |
| Abrir Justine | Clic en el botón del menú | Se muestra la misión pausada con tres agrupaciones, objetivo y controles. |
| Seleccionar y ordenar a todos | Tecla **4** y clic en **Banco directo** | Las tres órdenes guardadas tienen `action: direct`. |
| Cambiar una sola agrupación | Tecla **1** y clic en **Rodeo sur** | Güemes cambia a `flank`; los otros dos grupos conservan `direct`. |
| Avanzar y pausar | **Espacio**, espera breve, **Espacio** | El tiempo real de la simulación guardada alcanza **2,25 s**, con desplazamiento de las agrupaciones. |
| Guardar, cancelar y recuperar | **F5**, **X**, **F9**, **F5** | Se recuperan posiciones y órdenes previas; la identidad de sesión cambia. |
| Cámara | Rueda, **Q**, **E**, **O** | Cambian el encuadre y el acercamiento; O vuelve a enfocar el objetivo. Capturas antes/después disponibles. |
| Abrir el norte | Clic en **Menú**, clic en el segundo escenario | Se inicia la campaña en la ronda 1. |
| Preparar reconocimiento | Tecla **2**, clic en selector, clic en **Quebrada**, clic en **Reconocer** | El guardado registra `arias → scout → quebrada`. |
| Resolver reconocimiento | Clic en **Resolver ronda**, **F5** | Avanza de ronda 2 a 3; Quebrada pasa a conocida, con inteligencia hasta la ronda 5. Arias gana 5 de fatiga y consume 6 suministros entre reconocimiento y mantenimiento. |
| Decisión del mando contrario | Resolución normal, sin conexión | Se registra exactamente una intención adicional, identificada como `local_fallback`. No constituye una prueba en vivo de Jev. |
| Continuar campaña | **F9**, **F5** | Se conservan ronda, unidades, recursos, inteligencia e intenciones aplicadas; cambia la identidad de sesión y no se duplica la resolución. |
| Terminar | Clic en **Menú**, clic en **Salir** | Salida normal con código 0; proceso y pantalla de prueba cerrados. |

## Observaciones de la interacción

El primer intento de seleccionar Quebrada con flecha y Enter dentro del desplegable de Xvfb terminó seleccionando Rosario de la Frontera. El reconocimiento quedó bloqueado por las reglas y no se registró una orden inválida; esa primera ronda se resolvió sin acciones. Se repitió el recorrido mediante **clic directo sobre Quebrada**, se corroboró la orden en el guardado y se verificaron sus consecuencias en la ronda siguiente. Por eso la prueba confirmada de reconocimiento corresponde a la ronda 2 → 3. No se presenta la navegación por teclado del desplegable como validada.

Las capturas de esta sesión muestran superposición entre algunas etiquetas de unidades y sectores en el encuadre inicial del norte. También muestran un río de apariencia muy terrosa y poco contrastada con el terreno en el perfil bajo utilizado. Ambas observaciones se comunicaron al responsable de integración para la revisión visual; los registros de esta carpeta corresponden a esta sesión concreta y no deben sustituirse por afirmaciones sobre una revisión visual posterior.

## Archivos de evidencia

La carpeta `evidence/input-os/` contiene 21 capturas PNG, el registro de acciones con horas UTC, el log del motor y copias de los guardados producidos por F5. Los nombres conservan también los intentos intermedios para que la secuencia no oculte resultados adversos.

Capturas especialmente útiles:

- `01-menu.png`: selección de escenarios.
- `05-all-direct.png`: tres agrupaciones seleccionadas y aproximación directa.
- `06-mixed-routes.png`: orden distinta para Güemes.
- `08-camera-before.png` y `09-camera-zoom-turn.png`: efecto del zoom y giro.
- `12-norte-start.png`: campaña recién abierta.
- `18-scout-confirmed.png`: reconocimiento preparado correctamente.
- `19-scout-resolved.png`: consecuencias del reconocimiento.
- `20-norte-scout-loaded.png`: continuación del estado guardado.

Esta prueba demuestra entrada real, respuesta de interfaz y persistencia en el entorno Linux indicado. **No comprueba Windows nativo, el equipo del usuario, el rendimiento gráfico objetivo ni una decisión de Jev en vivo.** Las pruebas completas de victoria y derrota están documentadas por separado en las suites de reglas e integración; esta sesión de entrada no pretendió completar ambas campañas de punta a punta.
