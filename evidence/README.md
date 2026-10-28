# Índice de evidencias

Los registros pertenecen a distintos momentos del desarrollo. **No todos muestran los mismos recursos visuales ni el mismo binario.** La identidad de entrega está en `rea/PatriaGuemes-file-identity.json`; los hashes del manifiesto permiten comprobarla.

- `rules-test-results.json`, `integration-test-results.json`, `final-*.log`: suites funcionales de cierre. 80 reglas, 61 integración y 15 contrato Jev sin servicio vivo.
- `release-benchmarks/`: mediciones secuenciales del binario Linux exportado, con capturas y RSS de GNU time. Hardware en `hardware.json`. Los reportes del motor contienen memoria estática cero; debe usarse la RSS externa.
- `windows-wine/`: intento inicial con Wine 9.0 y diagnóstico del fallo de `VirtualProtect`, reproducido también por la plantilla oficial sin PCK.
- `windows-wine11/`: recorrido del EXE con Wine 11.0 aislado. Su resumen incluye el SHA del ejecutable probado. No valida Windows nativo.
- `input-os/`: prueba real de teclado/ratón Linux del 28/10/2026, 13:35–13:39 UTC. Conserva 17 comprobaciones y 21 capturas, incluidos intentos intermedios. Los retoques posteriores de agua, etiquetas y perfil bajo no están reflejados en esas capturas.
- `rea/`: inspección PE real con REA y validación PCK independiente del ejecutable identificado.
- `justine/`, `norte/`: primeras pruebas renderizadas completas, anteriores a la revisión visual final. No usarlas como imágenes finales ni como benchmarks aislados.
- `benchmarks/`, `final-benchmarks/`, `release-benchmarks-before-cleanup/`: mediciones preliminares, interrumpidas o anteriores a la corrección de salida. Quedaron superadas por `release-benchmarks/`. La memoria cero de las primeras pruebas es una limitación de la captura, no consumo cero.
- `teardown-diagnosis/`: reproducción de objetos de audio retenidos, comparación después de corregir su cierre y controles de las dos texturas GL que todavía se informan al salir. No se ocultan esos errores ni se atribuyen a un origen no comprobado.
- `release-build-report.json`: copia del registro de exportación correspondiente al EXE identificado por REA y al binario Linux de QA.
- `import.log`, `export-smoke.log`, `export-final.log`: importación/exportación. Compilar o importar sin errores no constituye una validación visual.

Las capturas son ejecución real. Los recorridos `--qa` automatizan métodos de la escena y aceleran reglas; la sesión `input-os` usa eventos del sistema operativo. Ninguna duración automatizada equivale a tiempo de partida humana.
