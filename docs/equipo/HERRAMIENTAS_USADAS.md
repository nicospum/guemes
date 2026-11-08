# Herramientas usadas en la entrega «equipo 2026-11-08»

## REA (Reverse Engineer Anything) — MCP `rea`, uso real

**Duda concreta:** ¿qué contiene la última entrega ejecutable que recibió el usuario (`entregas/0.4.0-preview5/PatriaGuemes_preview5.exe`)? ¿Incluye el nivel II o solo los dos niveles originales?

**Qué se analizó:** `open_binary` + `inspect_artifact` (detalle `summary`) + `inspect_analysis_view` (inventario de ocurrencias) sobre el EXE, SHA-256 `2c673c79030d485d284fa0186b33653ae422fba2daec7509011cf5375156633d`.

**Evidencia obtenida (2026-11-08):** el EXE embebe un PCK de Godot 4.7.2 (formato 4, `pack_start` 109 268 480, 595 archivos declarados, 596 hashes verificados, 0 discrepancias). El inventario contiene `project.binary` y `scripts/main.gdc` (208 181 B), pero **no** contiene `scripts/humahuaca/ui/humahuaca_ui.gdc` ni `data/humahuaca_rules.json`. Límite: REA inventaría el contenedor; no decodificó bytecode ni ejecutó el juego.

**Cómo influyó:** confirma que ningún ejecutable entregado incluye el nivel II: la experiencia de tres niveles solo existe en el código. Por eso la entrega exige una build nueva (aceptación D1) y la regresión final se hace también sobre el EXE exportado, no solo desde el editor.

## Jev / TypeSafe — evaluado, sin llamadas en vivo

- La integración existente (`scripts/jev_client.gd`) elige intenciones del adversario del nivel III entre opciones legales; las reglas locales controlan todo lo demás y hay alternativa local con tope de 2 s. Es el diseño correcto según la guía de TypeSafe (juicios en Jev, decisiones en código).
- En esta sesión la variable `TYPESAFE_API_KEY` **está definida** en el entorno (no se imprimió ni se leyó su valor). Aun así **no se hizo ninguna llamada en vivo**: cada llamada consume créditos del usuario y el encargo prohíbe gastos externos sin autorización. Queda como pendiente con permiso explícito (presupuesto chico, estado sintético del nivel III, sin datos personales).
- El juego publicado no depende de la API: sin clave o sin red, la alternativa local decide y el juego se completa (verificado por las pruebas `jev_contract_test.gd`, offline).
- Conclusión: Jev no se usa para el playtest automático (las políticas de juego en código son reproducibles y gratuitas); no aporta una mejora demostrable a esta entrega sin una prueba viva autorizada.
