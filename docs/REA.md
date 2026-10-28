# REA y Civilization VII: evidencia y límites

## Acceso real

La ruta indicada es `C:\Program Files (x86)\Steam\steamapps\common\Sid Meier's Civilization VII`. El entorno de desarrollo es Linux remoto. No tiene montaje `/mnt/c`, PowerShell de Windows ni acceso a la instalación de Steam. No se pudo identificar la versión instalada, ejecutar el juego, inspeccionar sus archivos ni observar su interfaz. No se modificó esa instalación.

La investigación aplicada combina documentación pública de Firaxis/2K y una prueba real de REA sobre el ejecutable Windows exportado de este proyecto. Son evidencias de alcances diferentes. La inspección del ejecutable propio no equivale a reverse engineering de Civilization VII.

## REA operativo y procedencia

Se instaló `rea-agents@6.8.0` en una carpeta temporal independiente, con Node 24.22.1, sin registro MCP global ni cambios de configuración de otros proyectos. El paquete npm y `main` declaraban ambos 6.8.0. El paquete es MIT; el skill incorporado `reverse-engineer-anything`, versión 49, se leyó antes de aplicar sus operaciones. La CLI está operativa; no se afirma que haya quedado un MCP conectado al cliente.

Integridad npm declarada y validada durante instalación:

```text
sha512-9QDeRnGqEDzABZyr04eLnBXBv/c6I9/TWu/6M0MD4pEfkySI/BIgwTODIbAReX3C1x6hjw9+Jlx4A2yUSPZ9ww==
```

La guía Windows Ghidra P0 consultada describe un ámbito experimental de lectura en Windows x64, con Ghidra instalado por el operador. No establece paridad con todas las funciones de REA ni aporta por sí sola acceso al juego. No se instaló Ghidra para fingir esa comprobación. Las operaciones portables de imports y recursos PE usadas aquí no requieren descompilador ni ejecución del binario.

## Prueba real sobre el ejecutable final

Objeto: `builds/windows/PatriaGuemes.exe`, exportación congelada de Godot 4.7.2 del 28 de octubre de 2026, código de juego `a246cdd`, registro `builds/logs/20261028T140621216473Z`. Se ejecutaron nuevamente ambas operaciones de REA sobre este EXE completo, que incluye su paquete de juego. Los resultados siguientes corresponden a esos bytes, no solo a la plantilla del motor ni a una exportación anterior.

| Campo | Resultado observado |
| --- | --- |
| Formato | PE32+, arquitectura x86_64 / AMD64 |
| Tamaño | 111.740.368 bytes |
| SHA-256 | `c2608e42b9e752231515b97fce20bdb8f8ec08ae8dc878e17a01f34aa710c462` |
| Operación imports | `inspect_pe_imports` |
| Evidence ID imports | `ev_2d4de0fb18dc04fd2a51478628aac66f624ed910c31777bb7c5ba0f17cec9220` |
| Inventario imports | 35 descriptores DLL y 693 funciones declaradas; algunos nombres DLL aparecen repetidos |
| Operación recursos | `inspect_pe_resources` |
| Evidence ID recursos | `ev_99b6a4f80d6630d178ca65441054941d5934b1ff45e4796747461d3fb47e1824` |
| Inventario recursos | 9 recursos PE |

Evidencia completa, conservada sin resumir las limitaciones del proveedor:

- `evidence/rea/PatriaGuemes-pe-imports.json`.
- `evidence/rea/PatriaGuemes-pe-resources.json`.
- `evidence/rea/PatriaGuemes-file-identity.json`: comprobación independiente de bytes, cabeceras y paquete embebido.

Pregunta concreta: ¿el ejecutable distribuible es realmente Windows x64, y qué dependencias y recursos declara? La observación confirma su formato y tablas. Entre los imports aparecen bibliotecas de Windows para ventana, dibujo, sonido y red. Esa lista **no demuestra** que cada función se use durante una partida ni que el programa abra correctamente en una PC determinada. REA conserva expresamente esos límites.

Aplicación: separar el ejecutable Windows del entorno de desarrollo y conservar su identidad exacta en la entrega; verificarlo como archivo PE antes de afirmar que existe un artefacto para Windows. Las dependencias de desarrollo REA/Node/Ghidra no se requieren para jugar.

Comandos reproducibles, con el tamaño permitido explícito porque el archivo supera 64 MiB:

```text
npx -y rea-agents@6.8.0 inspect-pe-imports builds/windows/PatriaGuemes.exe --max-file-bytes 200000000 --format json
npx -y rea-agents@6.8.0 inspect-pe-resources builds/windows/PatriaGuemes.exe --max-file-bytes 200000000 --format json
```

### Paquete de juego embebido

Se verificó además el paquete PCK mediante lectura estática de sus bytes, usando la estructura definida en el código oficial de Godot 4.7.2. Esta comprobación independiente se hizo con Python; **no se atribuye a REA un parser PCK que no se utilizó**.

| Campo observado | Valor |
| --- | --- |
| Firma de cabecera y final | `GDPC` |
| Inicio del PCK dentro del EXE | Byte 109.268.480 |
| Tamaño del PCK antes del pie | 2.471.876 bytes |
| Pie de cierre | 12 bytes: tamaño de 64 bits y firma |
| Formato PCK declarado | 4 |
| Motor declarado en cabecera | 4.7.2 |
| Flags | 2, base de archivos relativa y directorio sin cifrar |
| Entradas declaradas y leídas | 54 |
| Verificación de datos de entradas | 54 de 54 hashes MD5 coinciden con su directorio |
| SHA-256 del PCK sin pie | `1cb9aa78b23a623e70ce83209ffd9725d29a64c1e4404c34ac13818f4c1ab6d6` |

El inventario contiene escena principal, scripts compilados de reglas/presentación/audio/Jev, modelos importados, siete sonidos, fuentes, shaders e historia. Esto confirma la presencia e integridad interna del contenido empacado; la jugabilidad y la ejecución de Windows se verifican mediante pruebas separadas.

La revisión visual corrigió el contorno de los bancos, la superposición de etiquetas y la escala de renderizado del perfil bajo. La repetición de las 80 comprobaciones de reglas mantuvo cero fallos y los mismos resultados y tiempos simulados; el registro se conserva en `evidence/final-test_rules.log`. La exportación definitiva también incorpora el ajuste del cierre de audio de `a246cdd`. Tras esa última exportación se renovaron los hashes y todas las evidencias de este apartado.

Las posiciones y formatos se contrastaron con [`file_access_pack.cpp`](https://github.com/godotengine/godot/blob/4.7.2-stable/core/io/file_access_pack.cpp), [`file_access_pack.h`](https://github.com/godotengine/godot/blob/4.7.2-stable/core/io/file_access_pack.h) y [`editor_export_platform.cpp`](https://github.com/godotengine/godot/blob/4.7.2-stable/editor/export/editor_export_platform.cpp). La identidad JSON registra las fuentes, todas las entradas y sus hashes. La inspección preliminar de la plantilla había comprobado el mismo runtime de 109.268.480 bytes; la evidencia vigente para distribuir corresponde al EXE completo indicado arriba.

## Cinco preguntas sobre Civilization aplicadas al diseño

Las siguientes son conclusiones de diseño derivadas de documentos oficiales, no inferencias de código privado ni observaciones de la instalación del usuario. Las fuentes son publicaciones fechadas; no identifican su versión local actual.

| Pregunta | Evidencia pública observada | Conclusión y adaptación propia |
| --- | --- | --- |
| ¿Cómo reconocer selección y acciones? | 2K documentó en marzo de 2025 mejoras de visibilidad de banderas/salud y la expansión de la bandeja para mostrar las acciones disponibles [C1]. | Mantener nombre, estado y órdenes del grupo seleccionado en un panel persistente; reforzar selección con un aro visible. Es una decisión propia. |
| ¿Cómo leer cámara, relieve y capas? | 2K documentó controles de paneo por borde, teclado y arrastre en agosto de 2025 [C2]; la lente comercial expone rutas sin seleccionar una unidad [C1]. | Cámara inclinada con zoom; señalización de rutas y sectores independiente de detalles decorativos. El relieve no debe tapar la información esencial. |
| ¿Cómo comunicar movimiento, órdenes y resultados? | El diario de combate explica agrupación/despliegue por comandante y órdenes que afectan a varias unidades; también distingue resolución lógica y animación [C3]. | Una orden por grupo, trayectoria visible, causa textual del bloqueo y resultado explícito al resolver. No se deducen distancias o fórmulas internas de Civ. |
| ¿Qué esperas simplificar? | Firaxis explicó que el traslado individual de ejércitos generaba congestión y microgestión, y que comandantes y refuerzos la reducen [C3]. | Pocos grupos controlables, transiciones breves, resolución acelerable y cancelación antes de confirmar una ronda. No simular cada jinete como una unidad que exige orden. |
| ¿Qué mostrar ahora y qué dejar a un clic? | Las notas de marzo separan acciones visibles, indicadores de estado, lentes y ventanas informativas [C1]. | Objetivo, fuerza, fatiga, suministros y riesgo junto a la decisión. Fuentes, biografía y contexto en un panel consultable. La jerarquía exacta es diseño propio. |

## Fuentes oficiales consultadas

- **C1:** [2K, notas del parche del 25 de marzo de 2025](https://support.civilization.com/hc/es/articles/39719857984531-Civilization-VII-Notas-del-parche-25-de-marzo-de-2025), secciones IU / General / Notificaciones.
- **C2:** [2K, notas del 19 de agosto de 2025](https://support.civilization.com/hc/fr/articles/43845922146451-Civilization-VII-Notes-de-mise-%C3%A0-jour-19-ao%C3%BBt-2025), sección Améliorations de la caméra.
- **C3:** Firaxis, Brian Feldges, *Dev Diary #5: Combat*, 18 de diciembre de 2024, [publicación oficial en Steam](https://store.steampowered.com/news/posts/?enddate=1734541886&feed=steam_community_announcements), secciones Commanders / Improved Visual Battlefields. El enlace directo de civilization.2k.com devolvió 403 en esta sesión; se leyó la publicación del desarrollador en Steam.
- [REA, repositorio oficial](https://github.com/morluto/rea), [sitio oficial](https://rea.tools) y [Windows Ghidra P0](https://github.com/morluto/rea/blob/main/docs/windows-ghidra-p0.md).

## Pendiente específico

La investigación de los binarios y la observación del Civilization instalado siguen pendientes por falta de acceso al equipo. Para continuarlas, deben ejecutarse localmente con una copia de trabajo de los resultados fuera de Steam y un proveedor compatible. Ninguna conclusión de esta entrega depende de haber extraído assets o código de Civilization.
