# Dictamen de QA — Güemes 0.5.0-preview1

Resumen versionado de los dictámenes de los revisores independientes (los originales completos, con capturas, videos, registros y scripts, están fuera de Git en `../qa-equipo/qa_ronda2/` y `../qa-equipo/qa_final/DICTAMEN_FINAL.md`). Los revisores no escribieron código del juego y verificaron por su cuenta: no tomaron como prueba los informes de los implementadores.

## Versión certificada

- Commit `1d76157` de `equipo/integracion` (árbol limpio al empezar y al terminar la revisión).
- EXE `../entregas/0.5.0-preview1/PatriaGuemes_0.5.0-preview1.exe`, SHA-256 `98804d529032fdd10583c6a4c7bb02848bf7acb8c8e05a3b2268edec99b4fb04` (construido desde `b9049e4`, que difiere de `1d76157` solo en `tests/`, excluido de la exportación).
- Los commits posteriores a `1d76157` solo agregan documentación (`docs/`, también excluida de la exportación): créditos del audio (Q-302) y estos documentos de entrega (Q-303). Reverificación acotada: ver al final.

## Dictamen: **APTO CON LIMITACIONES** (Windows 11 x64, esta PC)

Máquina de referencia: Windows 11 Pro, Ryzen 9 7950X, RTX 3080 Ti, Godot 4.7.2 estable (Forward+). Con la GPU compartida por otros procesos durante parte de la revisión: las cifras de rendimiento absolutas son ruidosas.

### Cifras

| Prueba | Resultado |
|---|---|
| `test_rules` | 884 / 0 |
| `test_integration` | 359 / 0 (también sobre una importación limpia) |
| `jev_contract_test` | 15 / 0 (sin llamadas vivas) |
| `test_hx_*` (data, smoke, terrain, rules, view, flow, camera) | 2 100 / 0 |
| `tests/revision_nube/` | 32 / 32 |
| `ui_qa` 1280×720 | 257 / 0 (HUD del I tapa 24,5 %) |
| `ui_qa_humahuaca` 1280×720 | 174 / 0 (HUD del II tapa 23,9 % al inicio, 33,9 % en ataque) |
| Recorrido completo menú → I → II → III → final, perfil limpio, por la interfaz real | 2 vueltas seguidas, 79/79 comprobaciones, 794 s |
| Derrota y reintento | en los tres niveles (corridas aparte) |
| EXE: `--qa=justine`, `--qa=humahuaca`, `--qa=norte`, 12 benchmarks | 0 errores, 0 fugas; Humahuaca completo dentro del EXE |
| EXE con teclas y clics reales | entrada al I (F5 guardó) y al II (Esc pausa) |
| SCRIPT ERROR / SHADER ERROR | 0 en todas las corridas (headless, ventana y EXE) |
| Construcción del nivel II (peor caso) | 853 ms (antes 1,57–2,06 s) |

### Criterios de `ACEPTACION.md`

| Grupo | Resultado |
|---|---|
| A1–A6 (funciona) | **PASA** |
| B1–B6 (se ve mejor) | **PASA** (B1: mejora clara en menú, II y III; en el 3D del I es leve y lo fuerte son las pantallas de misión y los partes. B6: el I por cociente; II y III por los topes de `QA_NIVEL2.md`, con cociente 1,18–1,28 contra la base) |
| C1–C5 (se entiende) | **PASA** (C2: audio no verificado de forma audible) |
| D1, D3 | **PASA** |
| D2 (licencias) | FALLA en `1d76157` → corregido después en `docs/CREDITOS.md` y `docs/ASSETS.md` (Q-302) |
| D4 (documentación) | FALLA en `1d76157` → corregido con `ENTREGA.md` y este documento (Q-303) |

### Tickets: estado final

- Ronda 2 (Q-101…Q-107, Q-201…Q-210): **todos cerrados y verificados** por el revisor final (Q-207 solo por prueba automática). Q-201 (la cámara que mareaba, el ALTO que rechazó el nivel II): 0 deslizamientos automáticos con las órdenes de la guía en 344 s; 10 acercamientos, todos tras una elección explícita del jugador.
- Nuevos de la certificación:
  - Q-301 BAJO — aviso de fuga al salir en 3 suites sin ventana (no aparece al jugar ni en el EXE).
  - Q-302 MEDIO — créditos del audio del II faltantes → **corregido** (solo documentación).
  - Q-303 MEDIO — faltaban `ENTREGA.md` y este dictamen → **corregido**.
  - Q-304 BAJO — en el III a 1280×720 un rótulo se recorta en algún estado y el HUD tapa 36–39 %.
  - Q-305 BAJO (por confirmar) — paneo por borde cuando el puntero cruza la ventana.
  - Q-306 BAJO — del clic al briefing del II pasan 1,3–1,6 s con la imagen quieta.

### Limitaciones (por qué no es «candidato de publicación»)

1. **Nadie jugó a mano.** Toda la prueba la hicieron scripts por la entrada real y revisores automáticos; diversión, ritmo y claridad para personas reales quedan para una prueba humana.
2. **Audio no verificado de forma audible** (los sonidos se generan y se reproducen por código; nadie los escuchó).
3. **Jev/TypeSafe sin decisión viva** (no se gastaron créditos del usuario sin autorización; el juego usa su alternativa local).
4. Probado solo en esta PC con Windows 11 y una GPU potente; sin Linux/Wine, otras GPU ni resoluciones fuera de 1024×640–2560×1440.
5. BAJOS abiertos: Q-301, Q-304, Q-305, Q-306.
6. Balance del II: quien sigue la guía gana con bronce (la exigencia está en plata y oro).

## Historia de QA en esta entrega

| Ronda | Resultado |
|---|---|
| Línea de base (playtest) | Los tres niveles se ganan y se pierden; 0 bloqueantes; 2 ALTOS y 9 MEDIOS (P-001…P-022) |
| QA ronda 2 · nivel II | **RECHAZA** (Q-201 ALTO) |
| QA ronda 2 · I, III y recorrido | ACEPTA CON OBSERVACIONES (Q-101 MEDIO) |
| Corrección | dos agentes en paralelo; todos los Q-1xx/Q-2xx cerrados con su prueba |
| Certificación final | **APTO CON LIMITACIONES** |

## Reverificación acotada posterior a `1d76157`

Pendiente de la reverificación del revisor (se completa abajo con su resultado).
