# Verificación de la entrega 0.1.0

Fecha de cierre: **28 de octubre de 2026**. Estado: **alfa 3D jugable con dos escenarios**. Las reglas y los recorridos funcionales se comprobaron; la calidad cinematográfica, la decisión viva de Jev y la validación en la PC Windows de destino no se declaran aceptadas.

## Identidad y alcance

El proyecto se creó en una carpeta independiente, sin un remoto Git ni publicación. La ruta de Steam suministrada por el usuario no está montada en el entorno disponible. No se leyó, modificó ni extrajo contenido de esa instalación. Los documentos originales del paquete histórico se consultaron y conservaron; no se incluyen como assets del ejecutable.

La entrega utiliza **Godot 4.7.2 estable, revisión ed1daf0bf**, renderer Compatibility. La identidad exacta del ejecutable, su contenido PCK y la inspección REA están en `evidence/rea/PatriaGuemes-file-identity.json`. El manifiesto de entrega registra el hash del código y de los paquetes. Una exportación cruzada no demuestra ejecución nativa en Windows.

## Pruebas y resultados

| Comprobación | Resultado observado | Evidencia y límite |
| --- | --- | --- |
| Reglas autoritativas | **80/80** comprobaciones correctas | `tests/test_rules.gd`, `evidence/rules-test-results.json`. Simulación sin render. |
| Integración de la escena real | **61/61** comprobaciones correctas | `tests/test_integration.gd`, `evidence/integration-test-results.json`. Escena y callbacks reales en modo headless. |
| Contrato Jev | **15/15** comprobaciones correctas | `tests/jev_contract_test.gd`, `evidence/final-jev_contract_test.log`. Alternativa local real y fallos de transporte simulados; **sin llamada viva**. |
| Teclado y ratón del sistema operativo | **17/17** comprobaciones correctas | X11/Xvfb, 1280×800, `evidence/input-os/`. Clics, teclas y rueda; no llamadas internas para provocar acciones. |
| Exportación Windows x64 | EXE con PCK embebido generado | `tools/build_release.py`, registro de exportación e inspección REA. No requiere el editor para jugar. |
| Ejecución del EXE bajo Wine 11.0 | **Ambos escenarios completan victoria, código 0** | `evidence/windows-wine11/`: EXE final, ocho capturas y reportes. Wine no es Windows nativo. |
| Render del binario Linux | Cuatro recorridos medidos en 1440×900 | `evidence/release-benchmarks/`; hardware remoto, renderer por software. |
| Historia, modelos y licencias | Matriz documental, siete GLB originales, siete WAV propios y licencias de fuentes incluidas | `docs/historia/`, `docs/ASSETS.md`, `assets/models/model_manifest.json`. Reconstrucción artística explícita. |

Las suites comprueban selección, órdenes permitidas y bloqueadas, obstáculos, profundidad variable, aproximación detenida y reanudada por el agua, captura y dispersión, recursos no negativos, victoria/derrota, pausa, cancelación, reinicio, guardado versionado y recuperación. Se rechazan guardados corruptos o de versión incompatible sin sustituir el estado válido. Cargar o reiniciar invalida las respuestas externas antiguas y no duplica efectos.

### Incidencia de cierre de recursos

El benchmark inicialmente dejaba instancias `AudioStreamWAV` y `AudioStreamPlaybackWAV` al salir. Se identificaron con `--verbose` y se añadió un cierre explícito e idempotente de audio, también desde `_exit_tree()`, más un drenaje del render al terminar la automatización. Esas advertencias ObjectDB/resources desaparecieron en la comparación.

Persisten **dos mensajes de textura GL retenida al salir, de 349.524 bytes cada una**. Las ejecuciones completan su recorrido y devuelven código 0, pero sus logs no están libres de errores. Un control vacío y otro con solamente cielo procedural no reprodujeron el problema; la escena completa sí lo hace incluso liberando UI y mundo antes del cierre. **El origen exacto no quedó aislado**; no se atribuye sin evidencia al driver, al cielo o a las fuentes. Los controles están en `evidence/teardown-diagnosis/`. No se hizo un ensayo prolongado que descarte crecimiento de memoria durante muchas transiciones.

La prueba de entrada del sistema operativo comprueba que las teclas y clics llegan a la aplicación y producen las órdenes esperadas. Un primer intento de elegir Quebrada mediante flechas en el desplegable de Xvfb seleccionó otro sector; la regla rechazó la orden incorrecta y la selección posterior con ratón sí pasó. No se presenta ese recorrido de teclado del desplegable como validado. La sesión completa, incluidos intentos intermedios, está en `docs/INPUT_QA.md`.

### Compatibilidad de la herramienta Wine

El Wine 9.0 disponible inicialmente falló con una lectura nula en `kernelbase!VirtualProtect`, antes de mostrar el menú. La plantilla oficial Windows de Godot 4.7.2, sin el PCK de este juego y ejecutada con `--headless --version`, reprodujo el mismo fallo. La dirección coincide con el [issue oficial Godot #119140](https://github.com/godotengine/godot/issues/119140); allí un miembro del proyecto informa de funcionamiento con Wine más reciente y relaciona el caso con una corrección de Wine. Esta correspondencia orientó el diagnóstico y no se usó por sí sola como prueba de ejecución.

Se descargó Wine **11.0** de su distribución oficial, se verificaron los hashes y se extrajo en una carpeta independiente, sin reemplazar los paquetes del sistema. Con esa versión, la plantilla sin PCK devolvió **código 0** y la versión correcta del motor en **3,276 segundos**. La evidencia inicial fallida se conserva en `evidence/windows-wine/`; el recorrido del juego con la versión nueva está en `evidence/windows-wine11/`. Los jugadores de Windows no necesitan instalar Wine.

El **EXE final de Windows**, SHA-256 `c2608e42b9e752231515b97fce20bdb8f8ec08ae8dc878e17a01f34aa710c462`, completó los dos recorridos renderizados bajo Wine 11.0:

| Recorrido automático del EXE | Resultado | Tiempo real de la automatización |
| --- | --- | ---: |
| Justine, guardar/cargar y completar captura | Victoria; 473,75 s simulados. Guardado recuperado en 280 → 280 s. Código de salida 0. | **13,123 s** |
| Norte, Humahuaca y retirada | Victoria en ronda 11. Once decisiones `local_fallback` aplicadas: dos de proteger, una de avanzar y ocho de buscar víveres. Código de salida 0. | **45,321 s** |

Se usaron 1440×900, perfil bajo, render por software y audio Dummy. Estos segundos miden el recorrido acelerado de QA, **no una partida humana ni el tiempo de arranque**. La primera imagen posterior a construir cada escena tardó 201 ms en Justine y 183 ms en el norte; tampoco incluye el inicio completo del proceso. Los logs de este EXE no mostraron errores de GDScript ni avisos de texturas/ObjectDB. Sí registraron advertencias EGL/DRI3 y de nivel blanco SDR del entorno virtual; Justine dejó además un mensaje de conexión X cerrada al terminar. Los avisos de texturas descritos en la sección anterior corresponden a las ejecuciones Linux, no se generalizan a este recorrido de Windows/Wine. Ver `docs/WINE_QA.md`.

## Resultados de decisiones distintas

Con la semilla fija de las pruebas, las aproximaciones del Justine producen resultados diferentes:

| Estrategia | Desenlace | Tiempo de simulación | Fuerza final agregada |
| --- | --- | --- | --- |
| Banco directo con las tres agrupaciones | Victoria | **473,75 s — 7 min 53,75 s** | **249,59 / 300** |
| Rodeo sur con las tres agrupaciones | Victoria | **547 s — 9 min 7 s** | **262,49 / 300** |
| No impartir órdenes | Derrota al cerrarse la oportunidad | **900 s — 15 min** | No se captura el barco |

El rodeo tarda 73,25 segundos adicionales y conserva aproximadamente 12,90 puntos más de fuerza en ese ensayo. La exposición de la ruta, la fatiga y la fuerza disponible tienen efectos en las reglas. El desmontaje dura 12 segundos; la captura se resuelve de forma agregada. No hay simulación de combate individual dentro del barco.

| Campaña del norte | Resultado observado |
| --- | --- |
| Reconocer, hostigar, proteger víveres y operar en Humahuaca | Victoria en **ronda 11**, apoyo de población **89/100** |
| Hostigamientos rotativos sobre Jujuy | Victoria en **ronda 10**, apoyo de población **70/100** |
| Pasividad | Derrota en **ronda 12** |

La retirada puede lograrse sin una obligación artificial de completar Humahuaca. La operación de Arias aporta una vía histórica con consecuencias propias. Ocupar Salta y sostener la invasión son estados diferentes: los casos ganadores hacen insostenibles recursos/cohesión/comunicaciones aun cuando los realistas habían ocupado Salta. Una retirada adelantada se identifica como resultado alternativo.

Los tiempos anteriores proceden de simulación acelerada. **No son duración de partidas humanas.** La meta de primera decisión antes de un minuto se facilita mostrando objetivos y órdenes desde el inicio, pero no se validó con un estudio de usuarios. Tampoco se validó todavía la duración humana objetivo de 20–35 minutos de la campaña. La velocidad 3× comprime el tiempo real del primer escenario.

## Equipo y método de rendimiento

Datos observados del servidor, **no del equipo del usuario** (`evidence/hardware.json`):

- Linux remoto x86_64, CPU reportada AMD EPYC 9V74; 9 CPU lógicas expuestas.
- RAM visible: 10.206.484 kB, aproximadamente 9,73 GiB.
- Mesa 25.2.8, **llvmpipe LLVM 20.1.2, 256 bits**: render por CPU, sin aceleración GPU.
- Xvfb, ventana 1440×900, audio Dummy durante QA; no se hizo evaluación auditiva del sonido.

Cada benchmark calienta 30 cuadros y mide 180 cuadros con el reloj real. Se ejecutan secuencialmente y sin otro render del proyecto en paralelo. La captura corresponde al binario exportado. El perfil bajo dibuja el 3D a 0,5 de resolución en cada eje, sin sombras ni MSAA; la interfaz conserva 1440×900. El perfil medio usa resolución 3D completa, sombras y MSAA 2×.

| Escenario | Perfil | FPS medios | Cuadro mediano | Percentil 95 | RSS máxima del proceso |
| --- | --- | ---: | ---: | ---: | ---: |
| Justine | Baja | **16,48** | 55,88 ms | 103,97 ms | 392,96 MiB |
| Justine | Media | **3,88** | 245,75 ms | 358,05 ms | 505,12 MiB |
| Norte | Baja | **19,38** | 49,64 ms | 67,26 ms | 381,89 MiB |
| Norte | Media | **5,21** | 175,54 ms | 308,67 ms | 489,86 MiB |

La RSS se obtiene con GNU `time -v`, no con el contador de memoria estática de Godot, que devuelve cero en esta exportación release. La muestra es corta y representa estas escenas; no establece un mínimo de hardware ni excluye picos en una partida larga. Las cifras exactas y la duración de cada muestra constan en sus JSON.

**No se alcanzó la meta de 30/60 FPS en este servidor.** La ausencia de GPU impide extrapolar estas cifras a una PC Windows con aceleración gráfica. El perfil medio resulta lento en este entorno. La entrega permite seleccionar baja, media o alta, pero no promete fluidez no medida.

La construcción de la escena con recursos ya cargados midió 56/101 ms para Justine y 85/168 ms para el norte, en baja/media respectivamente. Ese campo no incluye inicio del proceso, importación ni primera compilación de shaders: **no es tiempo total de arranque**. Las capturas y reportes de QA registran por separado el primer cuadro cuando está disponible. No se validó un arranque en frío del equipo destino.

## REA, Jev e integraciones

REA 6.8.0 ejecutó realmente `inspect-pe-imports` e `inspect-pe-resources` sobre el runtime y el EXE del proyecto. El PE final contiene 35 descriptores de DLL, 693 imports y 9 recursos inspeccionados. La comprobación independiente del PCK valida los 54 hashes de sus entradas; esa comprobación no se atribuye a REA. Los JSON y Evidence IDs están en `evidence/rea/` y `docs/REA.md`.

No se inspeccionó la instalación inaccesible de Civilization VII. La adaptación de selección persistente, órdenes agrupadas, cámara y contexto se fundamenta en documentación pública oficial, separando evidencia e inferencia de diseño. Los MCP comunitarios evaluados documentalmente no se presentan como instalados u operativos; el flujo usado es Godot CLI y Blender Python. Ver `docs/EVALUACION_CAPACIDADES.md`.

Jev elige una intención entre opciones legales; las reglas locales conservan autoridad sobre el resultado. Hay espera máxima de 2 segundos, separación mínima de 3 segundos entre solicitudes, una solicitud activa y validación por partida/ronda/versión. Se comprobaron rechazo de respuestas inválidas y antiguas y alternativa local. Las decisiones realmente aplicadas se registran con su procedencia.

**Falta una credencial autorizada para verificar al menos una decisión viva.** El juego sigue siendo completable con el mando local. El mecanismo de configuración segura se entrega en `tools/configurar_jev.ps1` y `docs/CONFIGURAR_JEV_WINDOWS.md`; no se ejecutó PowerShell nativo aquí. No se incluyeron credenciales, se crearon cuentas ni se contrataron servicios.

## Calidad, pendientes y aceptación

| Criterio | Estado al entregar |
| --- | --- |
| Dos ciclos jugables, objetivos, consecuencias y desenlaces | Implementados y probados mediante reglas y escena real |
| Navegación, agua, recursos, cancelación y persistencia | Implementados y probados |
| Controles en español y cámara 3D | Implementados; entrada OS comprobada en Linux |
| Modelos y animaciones centrales | Siete GLB originales coherentes; estilo medio estilizado, reconstrucción artística |
| Calidad visual realista/cinematográfica solicitada | **Pendiente**; no se afirma fotorealismo ni fidelidad arqueológica |
| Audio funcional | Integrado y sintetizado; validación auditiva pendiente porque QA usa Dummy |
| Ejecución nativa Windows y rendimiento en la PC destino | **Pendientes de acceso a ese equipo** |
| Jev vivo que influya en la partida | **Pendiente de credencial y prueba viva** |
| Ritmo y comprensión por jugadores nuevos | **Pendientes de sesiones humanas** |
| Código, recursos, evidencia y reconstrucción | Incluidos con historial Git local y licencias |

Las capturas son del juego realmente renderizado. El acabado incluye terreno, vegetación, caballos y jinetes articulados, mercante armado, agua, iluminación, selección y rutas, pero conserva una estilización visible. Algunas etiquetas pueden aproximarse en agrupaciones muy juntas; el panel inferior mantiene la identificación de cada fuerza. No se añade Puesto del Marqués ni una tercera batalla.

La aceptación global requiere cerrar los pendientes explícitos. Esta versión se entrega como base funcional jugable y verificable, no como un producto final con todos los objetivos visuales y de plataforma certificados.

## Reproducir las verificaciones

Desde la raíz del proyecto, con el editor Godot 4.7.2 disponible:

```sh
godot --headless --path . --script tests/test_rules.gd
godot --headless --path . --script tests/jev_contract_test.gd
godot --headless --path . --script tests/test_integration.gd
```

Para reconstruir, seguir `docs/RECONSTRUIR.md`. En Linux, las pruebas renderizadas y de rendimiento se ejecutan con `tools/run_qa.py` y `tools/benchmark.py`. `tools/test_windows_wine.py` prueba el EXE dentro de un prefijo Wine aislado y conserva expresamente `native_windows_tested: false`. Ninguno de esos scripts sustituye una sesión en Windows nativo.
