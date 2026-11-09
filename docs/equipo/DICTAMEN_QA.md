# Dictamen de QA — Güemes 0.5.0-preview2 (visual/r1)

Resumen versionado de los dictámenes de QA sobre `0.5.0-preview1` y la reverificación completa de `0.5.0-preview2` (`visual/r1`, fases F0–F7; evidencia fuera de Git en `../qa-visual-r1/` y `../qa-equipo/`).

## Versión certificada (`0.5.0-preview2`, rama `visual/r1`)

- Commit de código certificado: `896fba5fa3a0dc5bc28a33b24278e19af7ce2a62` (`896fba5`, árbol limpio al construir y verificar).
- EXE: `../entregas/0.5.0-preview2/PatriaGuemes_0.5.0-preview2.exe`, `156 007 576` bytes, SHA-256 `a2b0fb9b96f787837c1917d7642109ebaa4f8f688f3be9c3b99c075750ec06ce` (`VERIFICACION_EMBEBIDA OK` contra `896fba5`).
- Los commits posteriores a `896fba5` solo actualizan `VERSION.json` (campo `windows_exe_smoke_test`) y `docs/equipo/{ENTREGA,DICTAMEN_QA}.md` (excluidos de la exportación).

## Dictamen vigente: **APTO COMO CANDIDATO DE PUBLICACIÓN en las plataformas probadas** (Windows 11 x64, esta PC, 1024×640, 1280×720, 1440×900, 1920×1080 y 2560×1440), para `896fba5` + el EXE `PatriaGuemes_0.5.0-preview2.exe`

Máquina de referencia: Windows 11 Pro, Ryzen 9 7950X, RTX 3080 Ti, Godot 4.7.2 estable (Forward+). En `0.5.0-preview2` se cerraron además la prueba en vivo de Jev (`4e1a094`), el recorte de rótulos en el III (Q-304, `638186a`), el aviso de fuga en suites sin ventana (Q-301, `571e418`) y la saturación del alba con las texturas PBR nuevas (`vis_flow` 0 fallas, `571e418`).

### Cifras de verificación (`0.5.0-preview2`)

| Prueba | Resultado |
|---|---|
| `test_rules` | 884 / 0 |
| `test_integration` | 367 / 0 (0 fugas de ObjectDB) |
| `jev_contract_test` (offline) + `jev_vivo.gd` (en vivo) | 15 / 0 offline; en vivo `jev-1.14.0` respondió en 330 ms («buscar víveres», ronda 1 → 2) y fallback local verificado a 50 ms |
| `test_hx_*` (`data` 427, `smoke` 158, `terrain` 167, `rules` 701, `view` 312, `flow` 308, `camera` 47, `audio` 96) | 2 216 / 0 (0 fugas de ObjectDB) |
| `ui_qa` (Justina, Norte y menú) | 257 / 0 en **5 resoluciones**: 1024×640, 1280×720, 1440×900, 1920×1080 y 2560×1440 |
| `ui_qa_humahuaca` | 182 / 0 a 1280×720; 98 / 0 a 1440×900, 1920×1080 y 2560×1440 |
| `justina_playthrough` | 18 victorias, 6 estilos, 3 rutas, 6 derrotas, `ui_real_victory: true`, 0 acercamientos a < 6 m de los ranchos de la ribera |
| `humahuaca_playthrough` (reglas y escena real) | reglas 0 fallas; escena real: experto 3/3 victorias, pasivo 3/3 derrotas (`amanecio`), interfaz 3/3 victorias, 0 excepciones |
| `hx_qa_tour` + `qa_imagen.py` (V03, V04, V06) | 20 / 0 comprobaciones, bot gana (`victory`); V03 fichas peor IoU 0,41 PASA; V04 albedo mediana 1,0 / p90 3,9 PASA; V06 edificio–suelo 12,4 (noche) y 12,8 (alba) PASA, marca–fondo 34,5 y 43,7 PASA |
| `vis_humahuaca.gd --flow` (`vis_flow`) | **0 fallas** (naranja saturado 0,1 % en `ataque@300` y `extraccion@321`, saturación media 0,402 y 0,418 ≤ 0,42; marcha ×1 y ×4 con desfase 0,000 m) |
| `hx_agent_play` (selftest, partida por archivos, reintento, protocolo, archivos viejos) | 5 / 5 PASA (victoria en 82 turnos, primera orden a los 3,0 s) |
| Benchmark Forward+ (`media`, 3 repeticiones) | Justina: media **2,52 ms** (peor 2,62 ms ≤ 3,0 ms); Norte: media **1,77 ms** (peor 1,90 ms ≤ 3,0 ms); Humahuaca: media **1,98 ms** (peor 2,16 ms ≤ 4,0 ms, construcción 526–533 ms ≤ 1 500 ms) |
| EXE `PatriaGuemes_0.5.0-preview2.exe` | `VERIFICACION_EMBEBIDA OK`; `--qa=justine` (4 PNG), `--qa=humahuaca` (16 PNG), `--qa=norte` (4 PNG) con salida 0, 0 errores y 0 fugas |

---

## Historial de certificación previa (`0.5.0-preview1`, `1d76157` / `d3f3fc7`)

En `1d76157` el dictamen fue **APTO CON LIMITACIONES** porque fallaban D2 (créditos del audio) y D4 (documentos de entrega). Corregidos ambos solo en documentación, la reverificación aplicó la regla «Dictamen posible» de `ACEPTACION.md` sin cambiarla: A, B y C completos, D1–D3 pasan, sin BLOQUEANTES ni ALTOS abiertos. Ver «Reverificación» al final.

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
| Construcción del nivel II | benchmark, peor caso: 853 ms (tope 1 400). Entrada desde el menú con ventana: 1,28–1,57 s (antes 1,57–2,06 s; Q-306 abierto). Son medidas distintas |

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

- Ronda 2 (Q-101…Q-107, Q-201…Q-210): cerrados y verificados por el revisor final, con dos salvedades: Q-207 verificado solo por prueba automática, y Q-106 cerrado al jugar y en el EXE pero **parcial en las suites sin ventana** (sigue el aviso de fuga al salir, ver Q-301). Q-201 (la cámara que mareaba, el ALTO que rechazó el nivel II): 0 deslizamientos automáticos con las órdenes de la guía en 344 s; 10 acercamientos, todos tras una elección explícita del jugador.
- Nuevos de la certificación:
  - Q-301 BAJO — aviso de fuga al salir en 3 suites sin ventana (no aparece al jugar ni en el EXE).
  - Q-302 MEDIO — créditos del audio del II faltantes → **corregido** (solo documentación).
  - Q-303 MEDIO — faltaban `ENTREGA.md` y este dictamen → **corregido**.
  - Q-304 BAJO — en el III a 1280×720 un rótulo se recorta en algún estado y el HUD tapa 36–39 %.
  - Q-305 BAJO (por confirmar) — paneo por borde cuando el puntero cruza la ventana.
  - Q-306 BAJO — del clic al briefing del II pasan 1,3–1,6 s con la imagen quieta.

### Limitaciones del dictamen (no lo bajan de categoría, pero hay que saberlas)

1. **Nadie jugó a mano.** Toda la prueba la hicieron scripts por la entrada real y revisores automáticos; diversión, ritmo y claridad para personas reales quedan para una prueba humana.
2. **Audio no verificado de forma audible** (los sonidos se generan y se reproducen por código; nadie los escuchó).
3. **Jev/TypeSafe sin decisión viva** (no se gastaron créditos del usuario sin autorización; el juego usa su alternativa local).
4. Probado solo en esta PC con Windows 11 y una GPU potente; el revisor final probó 1280×720 y 1440×900 (las rondas anteriores y las pistas corrieron además `ui_qa` a 1024×640, 1920×1080 y 2560×1440). Sin Linux/Wine ni otras GPU.
5. BAJOS abiertos: Q-301, Q-304, Q-305, Q-306.
6. Balance del II: quien sigue la guía gana con bronce (la exigencia está en plata y oro).

## Historia de QA en esta entrega

| Ronda | Resultado |
|---|---|
| Línea de base (playtest) | Los tres niveles se ganan y se pierden; 0 bloqueantes; 2 ALTOS y 9 MEDIOS (P-001…P-022) |
| QA ronda 2 · nivel II | **RECHAZA** (Q-201 ALTO) |
| QA ronda 2 · I, III y recorrido | ACEPTA CON OBSERVACIONES (Q-101 MEDIO) |
| Corrección | dos agentes en paralelo; todos los Q-1xx/Q-2xx cerrados con su prueba |
| Certificación final (`1d76157`) | APTO CON LIMITACIONES (D2 y D4 en falla) |
| Reverificación (`d3f3fc7`) | **APTO COMO CANDIDATO DE PUBLICACIÓN en las plataformas probadas**; Q-307 (redacción de este documento) corregido después, solo documentación |

## Reverificación acotada posterior a `1d76157`

El revisor comprobó que los 15 archivos que cambian entre `1d76157` y `d3f3fc7` están todos bajo `docs/` (excluido de la exportación) y que el EXE sigue teniendo el mismo SHA-256: es la build de esta versión. D2 pasa (los 32 WAV acreditados como síntesis propia; observación menor: la lista de grupos de `CREDITOS.md` omite el de interfaz). D4 pasa con observaciones: abrió Q-307 (MEDIO, solo documentación) por cuatro inexactitudes de este resumen y dos de `ENTREGA.md`, corregidas en el commit siguiente sin tocar la build.
