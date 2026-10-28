# QA del ejecutable Windows mediante Wine

El ejecutable final completó los dos escenarios bajo **Wine 11.0**, con victoria y salida 0 en ambos casos. La prueba se realizó el 28 de octubre de 2026 entre las 14:14:22 y las 14:15:26 UTC, en Linux con pantalla Xvfb, OpenGL Compatibility y renderizado por CPU llvmpipe. **Windows nativo sigue pendiente de prueba.**

## Archivo comprobado y alcance

| Dato | Valor |
| --- | --- |
| Ejecutable | `builds/windows/PatriaGuemes.exe` |
| Tamaño | 111.740.368 bytes |
| SHA-256 | `c2608e42b9e752231515b97fce20bdb8f8ec08ae8dc878e17a01f34aa710c462` |
| Motor exportado | Godot 4.7.2 stable official, `ed1daf0bf` |
| Wine usado para el recorrido | WineHQ 11.0, paquetes `11.0.0.0~noble-1` |
| Resolución / detalle | 1440 × 900 / baja |
| Renderer observado | llvmpipe, LLVM 20.1.2, 256 bits; Mesa 25.2.8 |
| Audio / Jev | Driver Dummy; alternativa local forzada, sin llamadas a TypeSafe |
| Automatización | Métodos de la escena real; no emulación de clics del sistema operativo |

La prueba arrancó el PE de Windows, leyó su PCK incluido y produjo capturas e informes desde ese mismo proceso. No se reemplazó por una ejecución del proyecto Linux. El motor informó `os: Windows`. Esa identificación es la plataforma del binario; no convierte Wine en una prueba sobre Windows nativo. La entrada física del sistema se comprobó por separado en Linux, según `VERIFICACION.md`.

## Resultados

| Comprobación | Justine | Campaña del norte |
| --- | --- | --- |
| Estado final | `victory` | `victory` |
| Código de salida | 0 | 0 |
| Tiempo de proceso medido por el runner | 13,123 s | 45,321 s |
| Progreso de simulación | 473,75 s; captura 100 % | Ronda 11; retirada anticipada |
| Construcción de escena | 73 ms | 166 ms |
| Primer cuadro tras crear la escena | 201 ms | 183 ms |
| Guardado/carga inspeccionado | Correcto: 280,0 s antes y después | Se conservaron los guardados de las rondas |
| Decisiones del adversario aplicadas | No utiliza Jev | 11 decisiones `local_fallback` |

Los tiempos de proceso corresponden al recorrido automatizado, que adelanta la simulación. No representan la duración de una partida humana ni un benchmark comparable a las mediciones sostenidas de `VERIFICACION.md`.

En Justine, la prueba ordenó la ruta directa a las tres agrupaciones, avanzó hasta la bajante, guardó y volvió a cargar en 280 s. Después alcanzó la victoria. La captura final muestra 250 de 300 de fuerza conservada y los caballos fuera de cubierta.

En el norte, las once decisiones aplicadas fueron dos `guard`, una `advance` y ocho `forage`, todas de la alternativa local. El informe conserva por decisión la observación enviada al cliente, opciones legales, contexto de partida/ronda/versión, fuente, identificador y latencia. El desenlace corresponde a la ronda 11, 22 de abril de 1817: la pantalla lo identifica expresamente como retirada anticipada alternativa y distingue la retirada histórica de comienzos de mayo. Humahuaca figura recuperada por Arias. Esta ejecución no valida el servicio Jev vivo.

Evidencia principal:

- `evidence/windows-wine11/windows-wine-summary.json`: identidad del EXE, versión, tiempos y salidas.
- `evidence/windows-wine11/justine/justine-render-report.json`: guardado/carga, progreso y resultado.
- `evidence/windows-wine11/norte/norte-render-report.json`: estado y once decisiones locales aplicadas.
- `evidence/windows-wine11/justine/execution.log` y `norte/execution.log`: salida completa del motor.
- `evidence/windows-wine11/userdata/`: copias de los dos guardados de QA, configuración sin clave y log de decisiones.
- `evidence/windows-wine11/evidence-manifest.json`: hashes de estas copias y de las ocho capturas.

## Revisión de capturas y avisos

Se revisaron visualmente el menú, los dos inicios, la bajante del Justine, Humahuaca y ambos desenlaces. La interfaz, botones, indicadores y textos de resultado se dibujan y se leen. La escena 3D de detalle bajo conserva pixelado visible y menor legibilidad de algunas etiquetas del terreno; las etiquetas próximas a las agrupaciones quedan densas en los puntos de reunión. Las capturas documentan ese aspecto real de la calidad baja, sin atribuirle la nitidez de perfiles superiores.

| Imagen | Ruta |
| --- | --- |
| Menú | `evidence/windows-wine11/justine/menu.png` |
| Justine al inicio | `evidence/windows-wine11/justine/justine-inicio.png` |
| Bajante y aproximación | `evidence/windows-wine11/justine/justine-bajante.png` |
| Victoria del Justine | `evidence/windows-wine11/justine/justine-victoria.png` |
| Norte al inicio | `evidence/windows-wine11/norte/norte-inicio.png` |
| Humahuaca recuperada | `evidence/windows-wine11/norte/norte-humahuaca.png` |
| Desenlace del norte | `evidence/windows-wine11/norte/norte-desenlace.png` |

Los dos logs contienen avisos de EGL/DRI3 y de imposibilidad de obtener el nivel blanco SDR del monitor virtual. El log de Justine también registra el cierre de la conexión X. Ambos procesos devolvieron 0 y generaron informes y capturas. No aparecen errores de GDScript, errores `ERROR:`, avisos de `ObjectDB` ni fugas de texturas en estos dos logs Windows/Wine. Esta observación es específica de esta ejecución; no borra los avisos de cierre registrados en otras pruebas Linux. El audio se silenció mediante Dummy y no se evaluó su reproducción audible aquí.

## Diagnóstico del intento inicial con Wine 9

El intento inicial quedó detenido antes de mostrar el encabezado de Godot, con una lectura de la dirección nula en `0x00006fffff4b0608`. Se conservaron el log inicial y los datos de limpieza de los procesos de esa prueba. Para separar el runtime del contenido del juego, se ejecutó **la plantilla oficial de Godot sin el PCK del proyecto**, con `--headless --version`. Wine 9 reprodujo el mismo fallo y devolvió 5.

Una ejecución adicional de esa plantilla bajo el depurador de Wine capturó el backtrace simbólico:

```text
VirtualProtect+0x50(..., old_prot=0x00000000000000000)
[/usr/src/wine-9.0~repack-4build3/dlls/kernelbase/memory.c:485]
in kernelbase, address 0x006fffff4b0608
```

El registro completo está en `evidence/windows-wine/diagnostic/wine9-template-backtrace.log`. El código 0 de la herramienta de depuración significa que terminó su script de comandos; **no** significa que la plantilla funcionó. El log contiene la excepción y el backtrace.

El mismo punto de fallo está documentado en [Godot issue 119140](https://github.com/godotengine/godot/issues/119140). Allí se vincula una [corrección de Wine del control de puntero nulo en VirtualProtect](https://github.com/wine-staging/wine-staging/commit/b98458cad). La reproducción local con la plantilla y el backtrace identifican el bloqueo en Wine 9, antes del contenido de esta entrega. La relación con esa corrección concreta está respaldada por la coincidencia de función, instrucción y parámetro nulo; no se reconstruyó Wine para probar cada commit intermedio.

La solución aplicada fue extraer WineHQ 11.0 en una carpeta de herramientas del proyecto y crear un prefijo nuevo. No se modificó el Wine del sistema ni el ejecutable del juego. Con Wine 11, tanto la plantilla oficial como el EXE final devolvieron 0 y mostraron la versión correcta en la prueba headless; después se completaron los dos recorridos gráficos descritos arriba.

El nuevo prefijo emitió al crearse un aviso de `syswow64/rundll32.exe` ausente y avisos de `XDG_RUNTIME_DIR`; se conservaron en el control inicial. Solo se descargaron paquetes amd64. Esos avisos no impidieron los controles ni los recorridos del ejecutable x64.

## Procedencia y reproducción

Los paquetes se descargaron del [repositorio oficial WineHQ para Ubuntu noble](https://dl.winehq.org/wine-builds/ubuntu/dists/noble/main/binary-amd64/Packages.gz), se verificaron contra los hashes y tamaños de su índice y se extrajeron con `dpkg-deb -x`, sin ejecutar scripts de instalación. URLs, tamaños y hashes exactos constan en `evidence/windows-wine/diagnostic/wine11-provenance.json`.

El runner utilizado es `tools/test_windows_wine.py`. Para esta ejecución se le pasaron `--wine` con el loader aislado, `--prefix` con el prefijo nuevo y `--output evidence/windows-wine11`; `WINELOADER` y `WINESERVER` apuntaron a los binarios de la misma instalación Wine 11. El runner fuerza detalle bajo, silencio y mando local, elimina `TYPESAFE_API_KEY` del entorno y conserva el hash del EXE antes de lanzarlo. Las pruebas se ejecutaron bajo `xvfb-run -a -s '-screen 0 1440x900x24'`.

Se preserva el intento fallido bajo `evidence/windows-wine/`, con sus controles y diagnóstico en `diagnostic/`. El éxito bajo Wine 11 queda separado en `evidence/windows-wine11/`. No se requieren Wine, Xvfb ni estas herramientas para jugar al EXE en Windows.
