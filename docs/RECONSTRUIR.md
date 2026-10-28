# Reconstruir la entrega

El proyecto se exporta con **Godot 4.7.2 estable**. El script `tools/build_release.py` importa los recursos, exporta Windows y/o Linux y conserva un registro de cada ejecución. Usa solamente la biblioteca estándar de Python; no descarga ni instala herramientas.

Para jugar una versión ya exportada no hacen falta Python, Blender ni el editor de Godot.

## Requisitos de desarrollo

- El **editor** Godot 4.7.2 estable para el sistema desde el que vas a construir. Una plantilla de exportación o el ejecutable del juego no reemplazan al editor.
- Plantillas oficiales de exportación **4.7.2.stable**, instaladas desde el gestor de plantillas de Godot o extraídas en una carpeta propia.
- Python **3.10 o posterior**.
- La carpeta completa del proyecto, con `project.godot`, `export_presets.cfg`, `scripts/`, `scenes/`, `assets/` y `data/`. No hace falta regenerar los modelos o sonidos para exportar: sus archivos ya están incluidos.

El script comprueba la versión del ejecutable y que exponga las opciones de importación y exportación del editor. Una versión distinta se rechaza antes de cambiar los presets. El comando puede invocarse desde otra carpeta: localiza el proyecto por su propia ubicación.

## Windows: exportar la versión lista para jugar

Abrí PowerShell en la carpeta del proyecto. Reemplazá la ruta del ejemplo por la del editor que tengas instalado:

```powershell
py -3 .\tools\build_release.py --godot "C:\Herramientas\Godot\Godot_v4.7.2-stable_win64_console.exe"
```

Windows es el destino predeterminado. Si las plantillas están instaladas en la ubicación estándar de Godot y los campos `custom_template` del preset están vacíos, no hace falta otro argumento.

Si preferís mantenerlas en una carpeta externa:

```powershell
py -3 .\tools\build_release.py --godot "C:\Herramientas\Godot\Godot_v4.7.2-stable_win64_console.exe" --templates "C:\Herramientas\Godot\plantillas\4.7.2.stable" --target windows
```

También podés configurar el ejecutable solo para esa sesión de PowerShell:

```powershell
$env:GODOT_BIN = "C:\Herramientas\Godot\Godot_v4.7.2-stable_win64_console.exe"
py -3 .\tools\build_release.py --target windows
```

La salida es `builds/windows/PatriaGuemes.exe`. El preset incluye los recursos dentro del ejecutable. Abrilo desde el Explorador después de que la exportación termine correctamente.

## Linux: exportar Linux, Windows o ambos

Con las plantillas instaladas en la ubicación estándar:

```sh
python3 tools/build_release.py --godot /opt/godot/Godot_v4.7.2-stable_linux.x86_64 --target linux
```

Con plantillas extraídas en una carpeta externa, para producir ambos destinos:

```sh
python3 tools/build_release.py --godot /opt/godot/Godot_v4.7.2-stable_linux.x86_64 --templates /opt/godot/plantillas/4.7.2.stable --target all
```

Alternativa con variable de entorno:

```sh
export GODOT_BIN=/opt/godot/Godot_v4.7.2-stable_linux.x86_64
python3 tools/build_release.py --target linux
```

La salida Linux es `builds/linux/PatriaGuemes.x86_64`. Al construir desde Linux se le concede permiso de ejecución. Podés abrirla así:

```sh
./builds/linux/PatriaGuemes.x86_64
```

La exportación usa modo headless y no necesita una ventana. Jugar o hacer QA visual sí requiere una superficie gráfica compatible. Exportar Windows desde Linux produce un binario para Windows; **no demuestra que se haya ejecutado en Windows nativo**.

## Qué recibe `--templates`

Este argumento recibe una **carpeta extraída**, no el archivo `.tpz`. Debe contener `version.txt` con `4.7.2.stable` y la plantilla release de cada destino solicitado:

| Destino | Archivo necesario |
| --- | --- |
| Windows | `windows_release_x86_64.exe` |
| Linux | `linux_release.x86_64` |

El script también acepta la carpeta inmediatamente superior si dentro existe `templates/` o `4.7.2.stable/` con esos archivos. Si están las variantes debug, también configura temporalmente sus rutas; la entrega se exporta siempre en modo release.

Sin `--templates`, se respetan los presets existentes y la búsqueda estándar de Godot. La entrega fuente debe mantener vacíos los campos `custom_template` cuando no contiene rutas portables propias. No hace falta copiar las plantillas al repositorio ni al directorio de Civilization.

## Preservación de la configuración y resultados

Si pasás plantillas externas, el script guarda una copia de los bytes originales de `export_presets.cfg`, establece las rutas durante la construcción y restaura el archivo al finalizar, también ante un error o una interrupción normal. No cambia permanentemente las rutas de otro equipo. Los comandos se ejecutan mediante listas de argumentos y sin shell.

Cada ejecución guarda sus logs en:

```text
builds/logs/<fecha-hora-UTC>/
    import.log
    export-windows.log       (si se solicitó Windows)
    export-linux.log         (si se solicitó Linux)
    build-report.json
```

El informe registra versión del motor, destino, bytes, SHA-256 del binario y restauración de los presets. Su campo `native_execution_tested` permanece en `false`: el script no abre los juegos exportados ni mide su rendimiento. El informe de QA de la entrega debe registrar por separado esas pruebas.

El proceso se detiene si el motor informa errores de scripts/importación, si falla una exportación o si no aparece el ejecutable esperado. No borra otras carpetas de builds. Una exportación correcta actualiza el archivo de su destino; un intento fallido puede dejar un archivo de una ejecución anterior, por lo que debe consultarse el resultado del comando y su informe.

Si el proceso es terminado de forma abrupta por el sistema, puede quedar `export_presets.cfg.build_release.bak`. El script no lo pisa: conservá ambos archivos, comparalos y recuperá la configuración original antes de reintentar. Si detecta una edición concurrente durante una construcción, guarda también esa edición en una copia identificada por fecha antes de restaurar el original.

## Ayuda y apertura en el editor

```sh
python3 tools/build_release.py --help
```

También podés abrir `project.godot` con el editor 4.7.2 y ejecutar la escena principal. Esto es ejecución desde el editor, distinta de abrir el binario exportado.

Para rehacer modelos o audio consultá `ASSETS.md`. Esos pasos necesitan herramientas de producción adicionales y no forman parte de la exportación cotidiana.

## Qué comprobar en el equipo de destino

La construcción y la prueba de uso son comprobaciones diferentes. Después de exportar, abrí el binario, iniciá ambos escenarios, comprobá selección y cámara y realizá un guardado y continuación. El manual de juego está en `CONTROLES.md`. Las mediciones de FPS, memoria y duración deben indicar equipo, resolución y perfil gráfico; no se deducen de un build exitoso.

Referencia técnica: [documentación oficial de la línea de comandos de Godot](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html), consultada para `--version`, `--import`, `--path`, `--headless` y `--export-release`.
