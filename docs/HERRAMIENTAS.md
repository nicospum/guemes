# Herramientas: desarrollo y ejecución

Registro de las integraciones REA / Jev y del motor comprobado en esta sesión, 28 de octubre de 2026. La configuración de otros proyectos se conservó. Los jugadores reciben el runtime exportado y los recursos del juego; no necesitan instalar las herramientas de análisis.

| Componente | Versión/procedencia | Uso y prueba real | ¿Necesario para jugar? |
| --- | --- | --- | --- |
| Godot | 4.7.2 stable official, `ed1daf0bf` | Ejecutó 80 comprobaciones de reglas, 61 de integración de escena y 15 del cliente Jev, todas correctas. El runtime Windows procede de las plantillas de la misma versión. | Runtime ya incluido; el editor solo para reconstruir. |
| GDScript | Incluido en Godot 4.7.2 | Cliente asíncrono, validación, logs y recuperación sin red. | Incluido en el juego. |
| Blender | 4.0.2 | Generación de modelos y animaciones propios; recursos importados en Godot y contenidos en el PCK final. | No; se entregan los modelos importados. |
| Xvfb | 21.1.12 | Pantalla virtual para ejecución visual y pruebas de entrada en el entorno Linux remoto. | No. |
| Mesa / llvmpipe | Mesa 25.2.8; renderer llvmpipe | Renderizado por CPU en la máquina remota. Sus mediciones no representan una GPU de la PC del usuario. | No; Windows usa el controlador del equipo del jugador. |
| Wine | 9.0 inicial; 11.0 oficial aislado | 9.0 falló también con la plantilla oficial sin juego en `VirtualProtect`; backtrace conservado. Con 11.0 el EXE final completó ambos escenarios con victoria y salida 0: Justine 13,123 s, norte 45,321 s. Ver `VERIFICACION.md` y `WINE_QA.md`; Windows nativo sigue pendiente. | No en Windows. |
| Audio original | Siete WAV sintetizados por `tools/generate_audio.py` | Efectos y ambientes de río/viento integrados; el paquete final contiene sus siete recursos importados. | Incluidos en el ejecutable. |
| HTTPRequest / ConfigFile / FileAccess | API integrada de Godot | Petición con timeout, credencial local, registro JSONL; recuperación y validación ejecutadas. | Incluidas en el runtime. |
| TypeSafe System One | API OpenAPI 0.2.0; `jev-latest` configurable | Contrato leído de documentación oficial; no hubo petición autenticada por falta de clave. | Opcional, solo si se desea Jev vivo. |
| Skill TypeSafe | MIT, commit `302eea662c54bca6730873fe245bec1d69ebc23d` | Leído completo; estructura de estado/opciones, autoridad de reglas, payload y errores explícitos aplicados. | No. |
| REA CLI | `rea-agents@6.8.0`, npm, MIT | `inspect_pe_imports` y `inspect_pe_resources` ejecutados sobre el EXE final `PatriaGuemes.exe`; evidencia completa en `evidence/rea/`. | No. |
| Skill REA | `reverse-engineer-anything`, metadata versión 49, incluido en paquete 6.8.0 | Leído antes del análisis, límites e IDs Evidence conservados. | No. |
| Node.js / npm | 24.22.1 / 11.9.0 | Runtime e instalación aislada de REA. | No. |
| Ghidra / Hopper / IDA | No instalados en esta tarea | No necesarios para las operaciones PE elegidas; no se fingió descompilación. | No. |
| MCP REA / TypeSafe | Sin conexión MCP creada | REA se usó por CLI; Jev por su contrato HTTP desde el juego. Instalar un skill no se contabilizó como integración viva. | No. |

## Dependencias y conservación de configuración

REA se instaló con versión fija en `/tmp/guemes-integrations/rea`, sin `setup` global, sin instalar Hopper y sin modificar el registro MCP o los skills del usuario. La instalación utilizó `--ignore-scripts`. Las inspecciones portables elegidas completaron su operación aun con esa restricción. La carpeta temporal no se distribuye con el juego.

El cliente TypeSafe no añade SDK ni servidor local: usa HTTPRequest integrado. El endpoint está fijado a HTTPS oficial; no acepta redirecciones ni guarda cabeceras de autorización. La clave proviene del entorno de ejecución del jugador o de `user://jev.cfg`, nunca del repositorio.

## Prueba y alcance

Los registros de la compilación final muestran **156 comprobaciones correctas, cero fallos**:

| Suite | Comprobaciones | Registro |
| --- | --- | --- |
| Reglas de ambos escenarios | 80 | `evidence/final-test_rules.log` |
| Integración de escena y recorrido del jugador, sin ventana | 61 | `evidence/final-test_integration.log` |
| Cliente Jev y recuperación sin red | 15 | `evidence/final-jev_contract_test.log` |

La suite Jev comprueba respuesta válida, opción inventada, distribución incorrecta, JSON inválido, alternativa local, filtro de campos, aplicación única, invalidación por reinicio, respuesta tardía, timeout simulado, error de respuesta y versión de estado cambiada. No hubo llamadas vivas. Estas suites no sustituyen las pruebas visuales o de input.

Las evidencias REA registran hashes, formato x64, imports y recursos del ejecutable final. Una lectura independiente verificó cabecera PCK v4, motor 4.7.2 y 54 hashes de recursos empacados coincidentes. Son observaciones estáticas sobre archivos propios de la entrega, no mediciones de gameplay ni comprobaciones sobre la instalación de Civilization.

Las pruebas del motor, assets, exportación, representación visual, duración y rendimiento se documentan en el informe general de verificación. Este registro no convierte una prueba de cliente HTTP en una prueba de ambos escenarios ni en una medición de la computadora del usuario.

## Fuentes

- [Godot CLI](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html).
- [REA 6.8.0 en npm](https://www.npmjs.com/package/rea-agents/v/6.8.0), [repositorio](https://github.com/morluto/rea).
- [Skills TypeSafe](https://github.com/typesafe-ai/skills), [System One](https://docs.typesafe.ai/api/system-one), [Choice](https://docs.typesafe.ai/primitives/choice).
