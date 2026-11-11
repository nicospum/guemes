# Dictamen de QA — Güemes 0.5.0-preview2 (visual/r1)

Resumen versionado del QA de `0.5.0-preview2` (rama `visual/r1`, fases F0–F7) y, más abajo, la historia de `0.5.0-preview1`. Evidencia fuera de Git: `../qa-visual-r1/f7_verificacion/` (verificación independiente del 2026-11-09 por la tarde), `../qa-visual-r1/` (trabajo de las fases) y `../qa-equipo/` (entrega anterior).

## Versión revisada

- Commit revisado: `7e896e3`, el de `origin/main`. El commit que trae este texto es posterior y solo cambia `docs/equipo/`; el de la ratificación de la enmienda 8 cambia `docs/QA_NIVEL2.md` y `tools/qa_gate.sh`. Ninguno de los dos entra en la exportación. Commit de código del ejecutable: `896fba5fa3a0dc5bc28a33b24278e19af7ce2a62`; los commits posteriores solo cambian `VERSION.json` y `docs/equipo/`, que no entran en la exportación.
- EXE: `../entregas/0.5.0-preview2/PatriaGuemes_0.5.0-preview2.exe`, `156 007 576` bytes, SHA-256 `a2b0fb9b96f787837c1917d7642109ebaa4f8f688f3be9c3b99c075750ec06ce` (`VERIFICACION_EMBEBIDA OK` contra `896fba5`, comprobada el 2026-11-09 a las 17:53).

## Cómo se llegó a este dictamen

1. La primera versión de este documento (en `7e896e3`, 13:31) declaraba «APTO COMO CANDIDATO DE PUBLICACIÓN» sin revisión independiente: la escribió quien hizo los últimos cambios. La última compuerta completa que había en disco (11:30) daba FALLA en 5 pasos, varias filas de su tabla no tenían corrida posterior al último cambio de código y de la verificación del EXE no había registro.
2. El 2026-11-09, de 17:22 a 18:28, se repitió toda la regresión sobre `7e896e3` con la clave de TypeSafe fuera del entorno: compuerta completa sin pasos omitidos, QA de interfaz en las resoluciones que la compuerta no corre, las suites que no están en la compuerta, recorrido completo por la interfaz real, importación desde un clon limpio y el EXE. Todo quedó en `../qa-visual-r1/f7_verificacion/`.
3. Un revisor independiente, en solo lectura y sin haber escrito código, auditó los cinco commits posteriores a `638186a`, releyó registros e informes y miró unas 50 capturas: `REVISION_INDEPENDIENTE_A.md`, `REVISION_INDEPENDIENTE_B.md` y `REVISION_INDEPENDIENTE_C.md` en esa carpeta.

## Dictamen vigente: **APTO COMO CANDIDATO DE PUBLICACIÓN en las plataformas probadas** (Windows 11 x64, esta PC, 1024×640, 1280×720, 1440×900, 1920×1080 y 2560×1440), para `7e896e3` + el EXE `PatriaGuemes_0.5.0-preview2.exe`

El revisor lo dejó primero en APTO CON LIMITACIONES, sin BLOQUEANTES ni ALTOS, por dos faltas que se cerraron sin tocar el código ni el EXE: **D4** (los documentos de `7e896e3` afirmaban cosas que no eran ciertas y traían cifras viejas; corregidos en el commit que trae este texto) y **A1** (faltaba la importación desde un clon limpio; hecha a las 18:25, sin errores). Las limitaciones de abajo siguen en pie.

Máquina de referencia: Windows 11 Pro, Ryzen 9 7950X, RTX 3080 Ti, Godot 4.7.2 estable (Forward+).

### Cifras de verificación (todas sobre `7e896e3`, 2026-11-09 de 17:22 a 18:28)

| Prueba | Resultado |
|---|---|
| Compuerta completa (`tools/qa_gate.sh full`, sin pasos omitidos) | `GATE full (r1): PASA`, 36 pasos en PASA y 1 AVISO (`push`), 24 min 52 s. Los pasos `protegidos`, `compartidos` e `higiene` pasan por la enmienda 8 (ver abajo) |
| `test_rules` | 884 / 0 |
| `test_integration` | 367 / 0 (también 367 / 0 sobre el clon limpio) |
| `jev_contract_test` (sin red) | 15 / 0. En vivo hubo una sola consulta, el 2026-11-09 a las 09:59 (`4e1a094`, `../qa-visual-r1/jev_vivo/`); la alternativa local por tiempo agotado tardó 95 ms |
| `audio_runtime_test` | 17 comprobaciones y la falla aceptada del driver Dummy |
| `test_hx_*` (`data` 427, `smoke` 158, `terrain` 167, `rules` 701, `view` 312, `flow` 308, `camera` 47, `audio` 96) | 2 216 / 0 |
| `tests/revision_nube` | 32 / 32 (una de ellas pasa pero emite 2 `SCRIPT ERROR`: Q-308) |
| `ui_qa` (Justina, Norte y menú, ventana real) | 257 / 0 en 5 resoluciones: 1024×640, 1280×720, 1440×900, 1920×1080 y 2560×1440 |
| `ui_qa_humahuaca` (ventana real) | 182 / 0 a 1280×720 (recorrido completo); 98 / 0 (chequeo de desborde) a 1024×640, 1440×900, 1920×1080 y 2560×1440 |
| `justina_playthrough` | 18 victorias, 6 estilos, 3 rutas, 6 derrotas; el bot de interfaz gana |
| `humahuaca_playthrough` | reglas: el experto gana y el pasivo pierde. Escena real: experto 3 de 3, pasivo pierde 3 de 3 (por `amanecio`), interfaz 3 de 3, 0 excepciones |
| `hx_qa_tour` + `qa_imagen.py` | 28 capturas, 0 fallas, el bot gana. V03 fichas, peor IoU 0,41. V04 albedo, mediana 1,0 y p90 3,9. V06 edificio–suelo 12,8 (noche) y 12,9 (alba) con piso 12; marca–fondo 34,5 y 43,3 con piso 25 |
| `vis_flow` | 0 fallas: naranja saturado 0,1 %; saturación media 0,402 y 0,418 con tope 0,42; marcha ×1 y ×4 con desfase 0,000 m |
| Arnés del agente (`selftest`, partida por archivos, reintento, protocolo, archivos viejos) | 5 de 5 (victoria en 82 turnos, primera orden a los 3,0 s de juego) |
| Benchmark Forward+ (`media`, 3 repeticiones) | Justina 2,60 ms de media (peor 2,82; tope 3,0). Norte 2,02 (peor 2,17; tope 3,0). Humahuaca 1,87 (peor 2,11; tope 4,0), construcción 505–526 ms (tope 1 500) |
| Recorrido completo menú → I → II → III → final | por la interfaz real, perfil limpio, una vuelta: 40 comprobaciones, 0 fallas, 401 s, 0 errores de script, 0 fugas (guion del QA final de `0.5.0-preview1`) |
| Importación desde un clon limpio de `7e896e3` | importa sin errores de script ni de shader y sin recursos faltantes (876 archivos en `.godot/imported`); el motor emitió 37 avisos «Unicode parsing error» que no se pudieron atribuir a un archivo. `test_hx_smoke` 158 / 0 y `test_integration` 367 / 0 sobre el clon; `--qa` de los tres niveles con 4, 16 y 4 capturas. El clon necesitó `core.longpaths` (Q-319) |
| EXE `PatriaGuemes_0.5.0-preview2.exe` | `VERIFICACION_EMBEBIDA OK`; `--qa=justine` (4 PNG), `--qa=humahuaca` (16 PNG) y `--qa=norte` (4 PNG) con salida 0, 0 errores y 0 fugas |

### Criterios de `ACEPTACION.md` (revisor independiente)

| Grupo | Resultado |
|---|---|
| A1–A6 (funciona) | **PASA**. A3: la derrota y el reintento del III no se repitieron por la interfaz (reglas y diálogos del III sin cambios desde `0.5.0-preview1`). A5: el recorrido completo tuvo una vuelta. A6: Q-308 |
| B1–B6 (se ve mejor) | **PASA con observaciones**: mejora clara en el II y el III, mixta en el I (Q-309, Q-311) y sin mejora en el menú (Q-315). B6: la Justina queda al 94 % de su tope de 3,0 ms |
| C1–C5 (se entiende) | **PASA**. C2 con la salvedad de Q-309 y el audio sin escuchar; C5: D-03, D-04, D-05 y D-10 reverificadas, el resto por arrastre |
| D1, D2, D3 | **PASA**. D3: toda la regresión es sobre `7e896e3`; faltó el EXE con teclas reales |
| D4 (documentación) | FALLA en `7e896e3` → `docs/equipo/` corregido en el commit que trae este texto; lo que queda fuera de esa carpeta sigue en Q-310 |

### Enmienda 8 de `docs/QA_NIVEL2.md`: ratificada por el dueño el 2026-11-09

`01c77f2` cambió la compuerta para que, en modo completo o de integrador, `protegidos`, `compartidos` (topes de líneas) e `higiene` (modelos `.glb` bajo `assets/models/`) informen sin bloquear. Sin ella esos tres pasos darían FALLA —como ya pasaba en `0.5.0-preview1`— y el resto, PASA. La primera redacción no traía cita del dueño ni medición y dejaba sin tocar la fila T01; después de esta verificación el dueño la ratificó de forma explícita, y la ratificación, la evidencia y la nota en T01 quedaron asentadas en la rúbrica (commit aparte, titulado «QA enmienda 8: …»).

Al asentarla se corrigieron dos efectos de `tools/qa_gate.sh` que la enmienda no declaraba: la regla de ruido del benchmark vuelve a valer solo si no se tocó ningún archivo protegido, y cualquier `.blend` versionado falla en `higiene`. Las dos dejan la compuerta igual o más estricta y no cambian el resultado de la corrida de las 17:22 (el benchmark pasó sin reintento y no hay `.blend` versionados). La compuerta rápida de integrador repetida a las 19:01 con el ajuste dio PASA (`rules` 831 / 0, `integracion` 367 / 0, `hx_data` 427 / 0, `hx_smoke` 158 / 0; `f7_verificacion/gate_quick_tras_ratificacion.log`).

Este dictamen no depende de la enmienda: ningún criterio A–D se apoya en esos tres pasos.

### Tickets abiertos

- **Q-308 MEDIO** — `SCRIPT ERROR` en `scripts/main.gd:2172` (`_reset_camera_j` con el mundo todavía nulo) al saltar del II en curso al I por `_start_game("justine")` o `_load_game("justine")`. El paso del II al III está limpio. La interfaz no ofrece ese camino y la prueba que lo recorre pasa sus 12 comprobaciones. Regresión de `9c171fd`.
- **Q-309 MEDIO** — Nivel I: con la cámara cercana, cuando la tropa llega al buque la vista puede mostrar solo agua (`f7_verificacion/recorrido/f7rec_r1_115_central.jpg`; en `0.5.0-preview1` ese instante mostraba buque y tropa). En el I las partidas fuera de cámara no dejan marca en el borde: hay que usar «Buque», «ver» o el minimapa.
- **Q-319 MEDIO** (viene de antes de esta entrega) — un `git clone` en Windows sin `core.longpaths` se corta con «Filename too long»: hay 83 rutas de 241 a 270 caracteres (relativas a la raíz) bajo `evidence/justina-ui/calidad_r5/bench.json/_appdata/`, una caché de shaders versionada por error en `c029e40` (2026-10-30). No afecta al EXE.
- **BAJOS** — Q-305 y Q-306 (de `0.5.0-preview1`, sin volver a medir). Q-311: ranchos de la ribera como bloques lisos a 2560×1440. Q-312: en el II, «5 Arreo» pisado por un aro y «2 Portal» cortado a 1024×640. Q-313: dos discos blancos sobre la torre y el cuartel de mañana. Q-314: la pantalla final deja ver el HUD por detrás (ya estaba). Q-315: el buque del menú se ve más chico que antes. Q-316 a Q-318: pares antes/después a distinta resolución, un símbolo suelto en el briefing a 1024×640 y un rótulo pegado al chip «Buque ▸». Q-320: tras importar en un clon, 186 archivos figuran cambiados; quien corrió el clon vio que eran `.import` con otro fin de línea y sin cambio de contenido, y el revisor no lo pudo comprobar porque el clon ya no existe.
- **Q-310 MEDIO** — documentación: corregido en `docs/equipo/{DICTAMEN_QA,ENTREGA,BACKLOG}.md` y en `README.md` (nombre del ejecutable, resoluciones probadas, Jev en vivo, estado de `main` y cómo clonar en Windows; la copia que viaja junto al EXE se actualizó el 2026-11-09 a las 19:12; va en commit aparte del de `docs/equipo/`). Quedan pendientes `VERSION.json:6`, `CLAUDE.md:5` y los documentos que siguen describiendo la entrega anterior (`DIRECCION_DE_ARTE.md`, `REFERENTES_Y_DECISIONES.md`, `HERRAMIENTAS_USADAS.md`).
- Cerrados en esta versión: Q-301 (ningún registro de la compuerta trae fugas) y Q-304 (el rótulo ya no se recorta; el HUD del III sigue tapando 39 % a 1280×720).

### Limitaciones

1. **Nadie jugó a mano** y **el audio no se escuchó**: toda la prueba es automática, por la entrada real.
2. Jev en vivo fue una sola consulta; toda esta verificación corrió con la alternativa local.
3. El EXE se probó por sus modos automáticos, no con teclas y clics reales.
4. El II se revisa completo solo a 1280×720; en las otras cuatro resoluciones se revisa el desborde.
5. Una sola PC (Windows 11, GPU potente). Sin Linux, Wine ni otras placas.
6. Balance del II: quien sigue la guía gana con bronce.

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
