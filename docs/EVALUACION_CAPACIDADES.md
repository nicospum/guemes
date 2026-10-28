# Evaluación de capacidades y candidatos

Revisión documental: **28 de octubre de 2026**. Se consultaron los repositorios indicados en el encargo, sus README y los manifiestos/licencias disponibles. Esta revisión no instaló servidores MCP, no cambió configuraciones de otros proyectos y no ejecutó sus instaladores.

## Qué quedó disponible y qué se usó

| Capacidad | Estado en esta entrega | Operación o evidencia | Decisión |
| --- | --- | --- | --- |
| Godot **4.7.2 estable**, CLI y GDScript | **Disponible y usado** | Importación del proyecto, ejecución del núcleo de reglas y pruebas del motor. Código de pruebas en `tests/`; resultados en `evidence/`. El flujo de exportación reproducible está en `tools/build_release.py`. | Mantener la CLI como automatización del motor. El registro de QA determina qué builds y recorridos se ejecutaron realmente. |
| Blender **4.0.2**, API Python y exportador glTF integrado | **Disponible y usado** | `tools/create_models.py` produjo seis GLB y una variante propia; se reimportaron modelos y se revisaron renders. `assets/models/model_manifest.json` registra hashes, animaciones y superficies. | Mantener scripts reproducibles para geometría, rig, animación e importación/exportación. Los detalles y límites están en `ASSETS.md`. |
| `Coding-Solo/godot-mcp` | **Fuente disponible; no instalado ni usado** | README, `package.json` y `LICENSE` leídos. Ninguna llamada MCP realizada. | La CLI ya completó las operaciones necesarias. Agregar el puente exigiría una validación adicional que no mejora este cierre. |
| `ahujasid/mcp-for-blender` | **Fuente disponible; no instalado ni usado** | README, `pyproject.toml` y `LICENSE` leídos. Ningún addon ni servidor de este proyecto se habilitó. | La API Python ya produjo y verificó los recursos. No se incorpora un servidor persistente para repetir esas operaciones. |
| Catálogo `openai/skills` | **Consultado; sin nuevas instalaciones desde ese repositorio** | README y estructura visible del catálogo revisados. | Usar las capacidades ya presentes. El propio repositorio dirige actualmente a `openai/plugins` para ejemplos vigentes. |

“Disponible” describe el acceso a una herramienta o fuente. **Un MCP no se considera operativo por aparecer en documentación o configuración:** haría falta una operación pertinente completada mediante ese MCP. Ninguno de los dos puentes comunitarios se presenta aquí como operativo.

## Godot MCP: alcance documentado y límite de compatibilidad

El [README de Coding-Solo/godot-mcp](https://github.com/Coding-Solo/godot-mcp) describe apertura del editor, ejecución de proyectos, salida de depuración y operaciones de escenas. Requiere Godot instalado, Node.js ≥18 y un cliente MCP. Menciona gestión de UID para Godot 4.4+, lo que no acredita una prueba con 4.7.2.

El [`package.json` de `main`](https://github.com/Coding-Solo/godot-mcp/blob/main/package.json) declara `godot-mcp` **0.1.1**, Node ≥18 y SDK MCP 0.6.0. Su [`LICENSE`](https://github.com/Coding-Solo/godot-mcp/blob/main/LICENSE) es MIT, con autoría de Solomon Elias. El README usa el nombre npm `@coding-solo/godot-mcp`, mientras el manifiesto consultado declara `godot-mcp`: no se comprobó aquí el contenido del paquete publicado. La versión citada es la del manifiesto leído, no una instalación validada.

**Compatibilidad con Godot 4.7.2: no probada para este MCP.** La compatibilidad comprobada de los scripts y la CLI del proyecto no se transfiere automáticamente a ese puente.

## MCP for Blender: URL comprobada

La URL exacta [ahujasid/mcp-for-blender](https://github.com/ahujasid/mcp-for-blender) **sí respondió**. No fue necesario sustituirla por otro repositorio. Su README lo identifica como integración comunitaria, independiente de Blender Foundation, y señala el nombre anterior `blender-mcp`.

El [`pyproject.toml`](https://github.com/ahujasid/mcp-for-blender/blob/main/pyproject.toml) declara **2.2.4**, Python ≥3.10, `mcp>=1.26.0,<2` y `httpx>=0.27.0`; el [`LICENSE`](https://github.com/ahujasid/mcp-for-blender/blob/main/LICENSE) es MIT, de Siddharth Ahuja. El manifiesto conserva enlaces de proyecto con el nombre anterior; se registra esa diferencia sin inventar un segundo proveedor.

El README describe un addon de Blender y un servidor Python conectados por socket, y declara Blender 3.0 o posterior. **No se probó esta integración con Blender 4.0.2.** Modelar, exportar e inspeccionar mediante la API local no demuestra que el servidor o sus herramientas funcionen en este entorno.

## Catálogo de skills de OpenAI

El [README de openai/skills](https://github.com/openai/skills) marca actualmente el repositorio como **deprecado** y enlaza a [openai/plugins](https://github.com/openai/plugins). Describe licencias por habilidad, localizadas en `LICENSE.txt` dentro de su directorio; no corresponde asignar una licencia única a todas por el nombre del catálogo.

No se instaló un skill adicional ni se incorporó código del catálogo al juego. Tampoco se atribuye a ese catálogo una garantía de integración con Godot. Cualquier futura incorporación debe identificar la habilidad concreta, su versión y licencia y probar la operación necesaria.

## Desarrollo y ejecución del jugador

Los MCP candidatos, Blender y los scripts de generación pertenecen al flujo de desarrollo. El jugador usa el runtime exportado y los recursos ya producidos; no necesita esos servidores ni las herramientas de modelado. REA y Jev tienen sus registros separados en `REA.md`, `JEV.md` y `HERRAMIENTAS.md`; esta evaluación no modifica sus estados ni acredita pruebas externas que no se realizaron.

Los enlaces a `main` documentan lo consultado en esta fecha y pueden cambiar. Este archivo no fija un commit ni afirma equivalencia entre `main`, una release y un paquete publicado.
