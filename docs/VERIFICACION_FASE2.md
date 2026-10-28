# Verificación de 0.2.0-alfa (fase 2)

Fecha: 28 de octubre de 2026. Este documento recoge solo lo que se ejecutó. La verificación de 0.1.0 sigue en `docs/VERIFICACION.md` y **no** cubre los modelos PBR, la interfaz ni el audio de esta versión.

## Equipo y condiciones de las mediciones

AMD Ryzen 9 7950X, 63 GB de RAM, NVIDIA GeForce RTX 3080 Ti de 12 GB (driver 610.88), Windows 11 Pro 10.0.26300, Godot 4.7.2 estable (ed1daf0bf). Escena `main` real lanzada desde Godot (no desde el EXE), 1440×900, V-Sync apagado (`--disable-vsync`), audio Dummy, perfil `APPDATA` aislado. Método: 120 cuadros de calentamiento y 900 medidos por corrida, tres repeticiones por combinación (dos en Compatibilidad), media de las repeticiones. Justine: las tres agrupaciones con rodeo sur, 170 s simulados. Norte: ronda 1 sin resolver. RSS/USS con psutil cada 100 ms (pico). Scripts y salidas: `evidence/fase2/qa/` (`bench_qa.gd`, `run_bench.py`).

### Forward+ (Vulkan), configuración por defecto del proyecto

| Escenario y detalle | FPS | Cuadro mediana / p95 / p99 / máx. (ms) | GPU mediana (ms) | RSS / USS pico (MB) | Draw calls | Primitivas | Arranque |
| --- | ---: | --- | ---: | --- | ---: | ---: | ---: |
| Justine baja | 909 | 1,06 / 1,24 / 1,67 / 3,7 | 0,21 | 765 / 642 | 174 | 112 mil | 1,79 s |
| Justine media | 826 | 1,17 / 1,37 / 1,83 / 3,8 | 0,71 | 757 / 637 | 211 | 306 mil | 1,74 s |
| Justine alta | 804 | 1,21 / 1,39 / 1,57 / 3,6 | 0,87 | 750 / 630 | 227 | 361 mil | 1,70 s |
| Norte baja | 1196 | 0,82 / 0,92 / 1,10 / 2,8 | 0,15 | 747 / 627 | 159 | 99 mil | 1,72 s |
| Norte media | 1037 | 0,95 / 1,10 / 1,35 / 3,2 | 0,61 | 759 / 638 | 209 | 278 mil | 1,83 s |
| Norte alta | 991 | 0,99 / 1,15 / 1,43 / 3,1 | 0,74 | 746 / 626 | 213 | 303 mil | 1,81 s |

El FPS mínimo entre repeticiones fue 798 (Justine) y 975 (norte); el mayor cuadro individual, 3,8 ms.

### Compatibilidad (`gl_compatibility`), dos repeticiones

Justine 675 / 601 / 605 FPS (baja / media / alta); norte 844 / 728 / 718 FPS. Cuadro mediano 1,17–1,62 ms, p99 1,5–2,5 ms, RSS 253–285 MB, arranque 1,22–1,38 s.

### Memoria

Forward+ pico 746–765 MB de RSS (USS 626–642 MB); Compatibilidad 253–285 MB. La memoria de video que informa el motor fue 163–368 MB en Forward+ y 38–87 MB en Compatibilidad. `nvidia-smi` devolvió 0 MB (no lista aplicaciones WDDM), así que no hay VRAM medida desde fuera. **No se atribuye la diferencia a los modelos nuevos**: no existe una medición de 0.1.0 en esta PC para comparar. No se midió en hardware modesto ni integrado.

## Recorridos probados (escena real, tiempo acelerado, por script)

`evidence/fase2/qa/journeys.gd`, capturas en `evidence/fase2/qa/journeys/`. Todos los desenlaces llegaron, con su ventana de desenlace y el botón «Volver a jugar» (que deja captura y tiempo en 0):

- Justine, banco directo con orden en t=0: victoria, 473,75 s simulados. Rodeo sur: victoria, 547 s. Sin orden: derrota a los 900 s.
- Orden tardía: a los 400 s ganan ambos (822 s y 873 s); a los 600 s pierden ambos (captura 46 y 0); a 700 y 800 s pierden. El corte está entre 400 y 600 s y no se acotó.
- Norte con las órdenes del QA automático: victoria en 11 decisiones. Norte pasivo: derrota; en la escena real (`jugabilidad/s1.log`, bloque F) en la ronda 12.
- Fuzz y pruebas de jugabilidad con reglas (`evidence/fase2/qa/jugabilidad/`): sin cuelgues ni recursos negativos.

Tests automáticos tras los cambios de cierre (con `APPDATA` aislado): reglas 82/82, contrato Jev 15/15, integración 62/62. Las cifras subieron respecto de 80 y 61 por dos comprobaciones nuevas en reglas (ruta junto a un obstáculo y limpieza de marcas del enemigo) y una en integración (R pide confirmación).

## Hallazgos corregidos en esta versión

| Hallazgo | Cambio |
| --- | --- |
| R reiniciaba sin confirmar y perdía el progreso | R abre un diálogo de confirmación (`_confirm_restart`). El test de integración comprueba que R no reinicia por sí sola y que reinicia al confirmar. |
| «Menú» autoguardaba sobre el único espacio y destruía el F5 manual | El autoguardado al salir solo ocurre si la partida está en curso y tiene avances. Una partida recién reiniciada o terminada no pisa el guardado; el autoguardado tras la última ronda del norte tampoco escribe una partida terminada. Sigue habiendo un único espacio por escenario: un autoguardado con avances **sí** reemplaza al F5 anterior (diseño, documentado en CONTROLES). |
| Clic derecho válido junto a obstáculos rechazado | `_route()` usa la celda libre vecina más cercana cuando la celda del destino es sólida. Con la semilla de `t10.gd`: antes 16 de 194 puntos transitables rechazados, ahora 0, sin unidades atascadas. |
| Marcas de sector enemigo obsoletas en el norte | El avance realista limpia el sector que deja (`_enemy_moves_to`); Humahuaca se conserva hasta que Arias lo recupere. Efecto de balance posible: Jujuy y Quebrada quedan libres antes para descansar y proteger; no se re-corrió la simulación masiva de balance (los tests de reglas, con sus cinco estrategias, siguen pasando). |
| Previsión de «Operar en Humahuaca» con la fórmula del hostigamiento | `_readiness_text` muestra ahora el resultado fijo (−10 fuerza, −18 suministros, −22 fatiga, sin azar). Verificado leyendo el código; no se vio en pantalla. |
| Audio: reasignar el stream cortaba la voz en curso | `play()` solo asigna el stream si es distinto y el reproductor no suena. **No se volvió a medir con audio real** tras el cambio. |
| ASSETS.md: enlaces de audio «pendientes», versión de Blender y conteo de GLB contradictorios | Corregido. |
| La afirmación WASAPI de ASSETS.md no se confirmaba | Sí consta: `audio_runtime_log.txt` registra «Driver de audio: WASAPI», latencia de 10 ms. Se añadió la cita. La prueba mide señal en los buses, no audio audible. |
| README/VERIFICACION presentaban evidencia de 0.1.0 como si cubriera el arte nuevo | README distingue 0.1.0 y 0.2.0, indica que el EXE de 0.2.0 solo tiene una prueba de arranque y que cinco modelos no están usados. |
| `.claude/` sin ignorar | Añadido a `.gitignore`, junto con los perfiles temporales de QA. |

## Hallazgos no resueltos o descartados

- **Balance del norte**: tres grupos hostigando Salta/Jujuy en las rondas 3–4 ganan en la ronda 7 (1037 victorias de 1500 partidas al azar con sesgo a hostigar, 828 en la ronda 7). Contradice la duración de 20–35 min y la cronología «ronda 10–11» de la documentación. **Actualización posterior**: se ajustó el ritmo (retirada realista desde la ronda 10 con presión ≥ 7); ver docs/BALANCE_NORTE.md. Sigue sin validarse con jugadores.
- **Unidad ahogada a mitad del río** (t=835, `t3.gd`): «Aproximación preparada» devuelve ok sin ruta y la unidad queda inmóvil. Solo cerca del final de la partida; no corregido.
- **`validate_snapshot` no comprueba coherencia entre campos**: un guardado editado a mano permite hacer trampa (`t11.gd`). Es un guardado local; no corregido.
- **Fecha de la ocupación de Salta**: la mecánica ocurría en la ronda 5 (9/2/1817) y la ocupación real fue el 15/4/1817. Resuelto después: ahora ocurre en la ronda 10 (12–22/4/1817); ver `docs/BALANCE_NORTE.md`.
- **Fechas de Humahuaca**: se mantiene Arias el 1/3/1817; el Ideario (pp. 41, 222–223) transcribe fechas de mayo. Falta cotejar *Güemes Documentado* t. 4 pp. 350–359.
- **Polifonía y tope de voces**: el tope de 6 cuenta reproductores, no voces; el test de audio tolera `MAX_VOICES + 3` y observó 7. Solo comprueba `max_polyphony == 2`, no que dos voces suenen a la vez.
- **Mensajes de recursos al salir**: «4 ObjectDB instances were leaked at exit» persiste también en el EXE de 0.2.0; no hay `SCRIPT ERROR`. Origen no aislado.
- Las teclas R, F5 y F9 no actúan con el modal de desenlace abierto, y el autoguardado por ronda del norte pisa el F5: son comportamientos de diseño.

## EXE de Windows 0.2.0-alfa

Generado con `tools/build_release.py` (no asumía Linux; no hizo falta adaptarlo) y las plantillas 4.7.2.stable, desde el commit indicado en `VERSION.json`. Se guarda fuera de Git en `entregas/0.2.0-alpha/PatriaGuemes.exe` (carpeta hermana del repositorio); tamaño y SHA-256 constan en `VERSION.json`. El `VERSION.json` embebido en el EXE es anterior a que se le añadieran el hash y el tamaño.

**Prueba de arranque realizada**: el EXE se lanzó con ventana (`--quit-after 300`, audio Dummy, perfil aislado), inicializó Vulkan Forward+ en la RTX 3080 Ti, corrió 300 cuadros del menú y salió con código 0, sin líneas «error» en el log y con el aviso de 4 instancias ObjectDB filtradas al salir. Una ejecución headless equivalente también terminó correctamente. **No se entró en un escenario con el EXE ni lo jugó una persona.**

## Pendiente (no probado)

- **Windows nativo con una persona jugando**: ningún recorrido del EXE de 0.2.0; ni 1920×1080 ni 1024×640, ni V-Sync activo, ni otra GPU distinta de la RTX 3080 Ti, ni equipos modestos. Los tiempos de cuadro de los recorridos incluyen simulación acelerada y no equivalen a juego humano; la «entrada real» fue `Input.parse_input_event` más llamadas directas a `main`.
- **Jev vivo**: sigue sin credencial; solo contrato y alternativa local.
- **Audio audible**: nadie escuchó los WAV ni la mezcla; el cambio de polifonía de esta versión no se midió con audio real.
- **Sesiones con jugadores**: duración humana, claridad de la interfaz y balance del norte.
- Arranque en frío (el medido es con caché de importación y shaders caliente) y ensayo prolongado de memoria.
- Casa, iglesia, algarrobo, cardón y roca: modelos presentes y sin cablear en `world_view.gd`.
