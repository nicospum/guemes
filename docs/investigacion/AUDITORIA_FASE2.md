# Auditoría técnica y de jugabilidad · Fase 2

Fecha: 28 de octubre de 2026. Alcance: **solo lectura** del código y del juego 0.1.0 (alfa). No se modificó ningún archivo del proyecto salvo este documento y la evidencia nueva en `evidence/fase2/auditoria/`. Sin commit.

Nota de árbol de trabajo: durante la auditoría otras pistas tenían cambios sin confirmar (`data/history.json`, `docs/historia/*`, `scripts/game_rules.gd` y `scripts/main.gd`, solo textos de eventos y de una ayuda). Ninguno toca render, UI ni rendimiento. Las mediciones corresponden a ese árbol, no al tag v0.1.0 limpio.

## 1. Línea base de pruebas (esta PC)

Godot 4.7.2 estable (`.tools/godot`), consola, `--headless`, con `APPDATA=C:/Users/User/AppData/Local/Temp/qa_auditoria` (perfil aislado de `user://`).

| Suite | Resultado |
|---|---|
| `tests/test_rules.gd` | **80/80**, sin fallos (Justine directo 473,75 s; rodeo 547 s; norte ronda 11 y 10; pasividad derrota ronda 12) |
| `tests/jev_contract_test.gd` | **15/15**, sin fallos (`live_api_tested: false`) |
| `tests/test_integration.gd` | **61/61**, sin fallos |

`evidence/` de 0.1.0 no cambió (comprobado con `git status`).

## 2. Equipo y método de medición

- Hardware: AMD Ryzen 9 7950X, 63,1 GB de RAM, **NVIDIA GeForce RTX 3080 Ti 12 GB** (controlador 610.88), monitor a 239 Hz, Windows 11 Pro 10.0.26300. Godot informa `OpenGL API 3.3.0 NVIDIA 610.88 - Compatibility`; el adaptador activo es la NVIDIA (hay también una AMD Radeon integrada, no usada).
- Ventana real de 1440×900 (`--resolution 1440x900`), ejecutable de consola de Godot 4.7.2 con ventana, proyecto desde fuentes (no el EXE exportado). Audio: driver Dummy.
- Script propio temporal (copia en `evidence/fase2/auditoria/audit_fase2.gd.txt`, es un `SceneTree` que instancia `scenes/main.tscn`). **V-Sync desactivado** (`VSYNC_DISABLED`) y `Engine.max_fps = 0`.
- Cada prueba: construcción con `_start_game`, 60 cuadros de calentamiento por cámara, luego **400 cuadros** medidos como delta entre `process_frame` consecutivos con `Time.get_ticks_usec`. FPS medio = 400 / tiempo total. Se informan también mediana, p95, p99 y "1 % peor" (inverso de la media del 1 % de cuadros más lentos). Perfiles tal como los aplica el juego (`settings.quality` + `_rebuild_world`): baja = escala 3D 0,5, sin sombras, sin MSAA, 2 figuras por grupo, mallas de terreno más gruesas; media = escala 1,0, sombras, MSAA 2×; alta = ídem con MSAA 4×.
- Justine: las tres agrupaciones con "rodeo sur", 170 s simulados, tiempo corriendo (igual que `--benchmark`). Norte: ronda 1 sin órdenes. "Lejos" = cámara por defecto del escenario (distancia 81 / 96, pitch 0,91). "Cerca" = distancia 30, pitch 0,6.
- Límites: una sola corrida por configuración; la medida es tiempo de cuadro de CPU/presentación, **sin separar tiempo de GPU** (el renderer Compatibility no lo expone). No se midió memoria de proceso, ni arranque en frío, ni sesiones largas. Los FPS de baja con cámara "cerca" son tan altos porque las agrupaciones quedan fuera de cuadro (ver 4.1).

### 2.1 FPS medidos (RTX 3080 Ti, 1440×900, V-Sync off)

| Escenario | Perfil | Cámara | FPS medio | Mediana ms | p95 ms | "1 % peor" FPS | Draw calls | Primitivas |
|---|---|---|---:|---:|---:|---:|---:|---:|
| Justine | baja | lejos | **473** | 1,94 | 2,28 | 68 | 387 | 90.850 |
| Justine | baja | cerca | 1367 | 0,72 | 0,79 | 915 | 137 | 63.868 |
| Justine | media | lejos | **248** | 4,00 | 4,50 | 200 | 898 | 249.374 |
| Justine | media | cerca | 253 | 3,95 | 4,28 | 223 | 555 | 288.818 |
| Justine | alta | lejos | **248** | 4,00 | 4,50 | 204 | 898 | 249.374 |
| Justine | alta | cerca | 251 | 3,97 | 4,35 | 211 | 555 | 288.818 |
| Norte | baja | lejos | **459** | 2,27 | 2,46 | 351 | 728 | 84.221 |
| Norte | baja | cerca | 471 | 2,20 | 2,40 | 387 | 622 | 99.317 |
| Norte | media | lejos | **240** | 4,12 | 4,62 | 195 | 1561 | 223.640 |
| Norte | media | cerca | 243 | 4,09 | 4,47 | 211 | 1418 | 320.732 |
| Norte | alta | lejos | **240** | 4,12 | 4,62 | 197 | 1561 | 223.640 |
| Norte | alta | cerca | 241 | 4,11 | 4,51 | 197 | 1418 | 320.732 |

Lectura: en esta GPU **los tres perfiles superan 60 FPS con holgura** (peor caso medido: 240 FPS medios, 195 FPS en el 1 % peor). La meta de 30/60 FPS no está en riesgo en un equipo de esta clase; **no se extrapola a GPU integradas ni a portátiles**, que no se probaron. Para comparar: la alfa midió 16,5 / 3,9 FPS (Justine baja/media) y 19,4 / 5,2 (norte baja/media) con llvmpipe en un servidor sin GPU; no es comparable con estas cifras.

Observaciones sobre las cifras:
1. **Media y alta son indistinguibles** (diferencia ≤ 0,05 ms): MSAA 4× no cuesta más que 2× aquí, de modo que el perfil "alta" no ofrece nada que "media" no tenga (ver R3).
2. El valor 240–253 FPS de media/alta coincide con el refresco del monitor (239 Hz), pero **no es un tope**: las sondas siguientes llegaron a 988–1395 FPS en la misma ventana.
3. La baja de Justine "lejos" tiene un 1 % peor de 68 FPS (cuadros aislados de ~15 ms de media en el 1 % peor) frente a p99 de 2,56 ms: hay al menos un pico puntual. No se identificó su causa; no se repitió con más cuadros.

### 2.2 Sondas de atribución (Justine, perfil medio, 400 cuadros cada una)

| Sonda | Lejos ms | Cerca ms | Conclusión |
|---|---:|---:|---|
| Referencia (media) | 3,97 | 3,93 | |
| MSAA desactivado | 3,91 | 3,89 | MSAA no es el costo |
| Agua oculta | 3,89 | 3,85 | El agua no es el costo |
| Sombras desactivadas | 3,85 | **0,77** | **Sombras: ~3,2 ms con la cámara cerca** |
| Sin sombras + sin MSAA + sin agua | 3,75 | 0,74 | |
| Sin sombras + terreno oculto | 3,81 | 0,77 | El terreno no es el costo |
| Sin sombras + multimallas (hierba/rocas) ocultas | 3,83 | 0,76 | La vegetación decorativa no es el costo |
| Sin sombras + escala 3D 0,5 | 3,77 | 0,80 | **No depende de los píxeles** |
| Solo buque oculto | 3,97 | 3,94 | El buque (23.000 triángulos, sin piel) no es el costo |
| **Figuras de las agrupaciones ocultas (+buque)** | **0,97–1,00** | 0,82 | **Las figuras con piel cuestan ~2,9 ms** |
| Norte, figuras ocultas | 1,53 | 1,42 | De 4,12 ms a 1,53 ms (~2,6 ms) |

Se concluye, con evidencia de ocultación individual: **el costo dominante del juego en esta GPU son las 12 figuras animadas con piel** (4 jinetes por grupo en media/alta), no el terreno, el agua ni los antialiasing. Con la cámara "cerca" en Justine las agrupaciones quedaban fuera de campo, por eso allí domina la sombra de las figuras y del buque. Cada figura de jinete son 12.941–12.769 triángulos, 16–17 superficies y 18 huesos (GLB medidos con un script de carga: `rider_1806`, `rider_1817`; `horse_only` 8.502; infantería/desmontado 4.399–4.431): 12 jinetes = ~155.000 triángulos, el 62 % de las 249.000 primitivas del cuadro de Justine, para figuras que a distancia de juego ocupan ~20–30 píxeles. Con la hipótesis (no verificada con un perfilador) de que el costo viene del número de superficies/llamadas por figura y de la actualización de la piel, no solo de los triángulos.

### 2.3 Costos de CPU del lado del juego (medidos por llamada)

| Operación | Justine | Norte |
|---|---:|---:|
| `world.update_state()` por cuadro | 0,03 ms | 0,04 ms |
| `world.refresh_paths()` (regeneración de la ruta) | 0,36–0,41 ms | 0,001 ms |
| `_update_hud()` | 0,19–0,30 ms | 0,16–0,17 ms |
| Construcción del mundo (`_start_game`) baja / media-alta | 48 / 96 ms | 73 / 137–139 ms |
| `_rebuild_world()` (cambio de calidad, menú) baja / media-alta | 43 / 91–95 ms | 66 / 130–133 ms |

Nada de esto compromete la tasa de cuadros; sí implica un tirón de 45–140 ms al cambiar calidad en juego.

### 2.4 Inventario de escena (conteos con `find_children`)

| | Justine | Norte |
|---|---:|---:|
| Nodos totales | 369–382 | 753 |
| `MeshInstance3D` | 175–188 | **516** |
| `MultiMeshInstance3D` | 2 | 2 |
| Materiales únicos de `material_override` | 11–12 | 15 |
| `Label3D` | 7 | 12 |
| Luces | 2 | 1 |
| Draw calls (alta, lejos) | 882–918 | 1561 |
| Memoria de vídeo / texturas | 74 / 57 MB | 75 / 58 MB |

La caché de materiales funciona: **no hay materiales por instancia** (11–15 materiales para 175–516 mallas). El problema de draw calls es de geometría separada, no de materiales (ver R4).

## 3. Capturas y qué se vio

Capturas reales (viewport 1440×900, perfil alta, y baja para `justine_bajante_cerca`) en `evidence/fase2/auditoria/alta/` y `.../baja/`: `menu`, `justine_lejos`, `justine_cerca`, `justine_bajante_lejos`, `justine_bajante_cerca`, `justine_rasante`, `norte_lejos`, `norte_cerca`. Se ven con el script citado; no son una partida humana.

## 4. Defectos concretos

### 4.1 Interfaz y cámara

- **UI-1 · La interfaz cubre más de la mitad de la pantalla.** Paneles fijos: cabecera 1400×83 (arriba), izquierdo 280×574 (objetivo + parte), derecho 262×250, inferior 1400×178. El espacio de juego libre es aproximadamente el rectángulo central 858×593 más una columna derecha 262×335: **≈ 596.000 px de 1.296.000, el 46 %**. Con el aviso emergente (805×70, 4–7 s) y el texto de ayuda (790×54, sin fondo) baja más. En `justine_bajante_cerca` el buque queda debajo de la cabecera y el panel derecho; en `norte_cerca` Salta queda bajo el texto de ayuda.
- **UI-2 · El texto de ayuda contextual no tiene fondo.** Se superpone a terreno y etiquetas 3D (ver `justine_lejos`: "RODEO SUR" ocupa la misma línea que "Primera decisión…" y ambos se vuelven ilegibles; `norte_lejos`: la ayuda cruza árboles y rocas).
- **UI-3 · Etiquetas 3D con tamaño fijo en el mundo, no en pantalla.** `Label3D.pixel_size = 0,038` y `font_size` 26–35 con `billboard`. Resultado medido en las capturas: a distancia 81 el texto "RIBERA DE BUENOS AIRES · 1806" mide ~9 px de alto y queda **cortado por el panel izquierdo**; a distancia 28–30 "BANCO CENTRAL" mide ~35 px y "● 2 · 100 %" ~40 px, tapando a las agrupaciones. Con `no_depth_test = true` las etiquetas atraviesan buque y terreno ("JUSTINE" se dibuja sobre las velas). No es un problema de cantidad (7 y 12 etiquetas) sino de escala y colisión.
- **UI-4 · Las etiquetas de agrupación se apilan y se mezclan.** Con agrupaciones a < 4,5 u se elevan `index × 2,1` y el texto flota lejos de los jinetes (`justine_rasante`: tres etiquetas a 150–250 px sobre el grupo); a distancia 81 las tres se superponen en una mancha ("2 · 100 %", "3 · 83 %" ilegibles en `justine_bajante_lejos`). En el norte, "VALLE DE LERMA" y "SALTA" se pisan y "ROSARIO DE LA FRONTERA" cubre a "CHICOANA".
- **UI-5 · Desplegable de sectores (Norte): navegable con teclado dentro del motor, pero mal integrado.** Prueba con eventos de teclado inyectados vía `Input.parse_input_event` (no teclas del sistema operativo): Enter abre el menú; Abajo, Abajo, Enter pasó de "Valle de Lerma" (índice 4) a "Orán" (índice 6) y el juego actualizó el sector. Es decir, **el desplegable sí responde**; la nota de 0.1.0 sobre el intento de Xvfb no se reproduce aquí, y esta prueba tampoco sustituye una de entrada real del SO. Defectos observados: (a) **mientras el desplegable tiene el foco, las flechas Arriba/Abajo siguen moviendo la cámara** (`camera_target.z` pasó de 4,31 a 5,21 en seis pulsaciones, incluso con el menú abierto) porque `_camera_keys` lee `is_physical_key_pressed` sin comprobar el foco de la UI; (b) **solo 1 de 22 botones del HUD admite foco** (`_button` fuerza `FOCUS_NONE`), así que Tab no recorre el HUD y el desplegable es el único control alcanzable; (c) tras elegir, el desplegable conserva el foco: es probable (no probado) que Espacio/Enter lo reabran en vez de resolver la ronda, y que 1/2/3 no seleccionen agrupación hasta quitar el foco con el ratón.
- **UI-6 · Texto duplicado:** "Jev: Jev: sin consultar" (`jev_label.text = "Jev: " + jev.status_text` cuando el estado ya empieza por "Jev:").
- **UI-7 · Diseño atado a 1440×900.** Todas las posiciones son absolutas (`Vector2(20,116)`, `Vector2(1158,116)`…), sin anclajes ni contenedores; los modales se centran con 1440/900 fijos. Con `stretch/mode = canvas_items` el contenido se escala, pero **no se probó** en 1920×1080 ni en 1024×640 (mínimo permitido). Riesgo: barras laterales y tipografía pequeña (11–13 px en varios rótulos).
- **UI-8 · Parte de situación repetitivo.** En `justine_bajante_*` las cinco líneas visibles son casi idénticas ("Artillería sobre Güemes · vanguardia: −4,2 / −4,6 efectivos. Exposición alta."), cada disparo genera una línea (`game_rules.gd:382`); desplaza la información útil (marea, llegada). Sin agrupar ni resumir por ventana.
- **UI-9 · Cámara:** sin desplazamiento por borde de pantalla, sin zoom hacia el cursor, límites duros ±40/±32; `focus_objective` (O) no sigue a las agrupaciones. En el norte el mapa en vista lejana (`norte_lejos`) pierde las agrupaciones bajo sus etiquetas.

### 4.2 Arte

- **ART-1 · Terreno facetado.** La malla del terreno es no indexada (`add_vertex` seis veces por celda) y `generate_normals()` sin suavizado produce **normales planas**: en `norte_lejos`/`norte_cerca` se ven facetas triangulares duras y costuras de color por vértice. El terreno no tiene texturas, solo color de vértice + ruido procedural en el shader.
- **ART-2 · Legibilidad del agua.** El agua es un único tono azul verdoso oscuro (`water.gdshader`: albedo 0,08/0,17/0,17 a 0,025/0,10/0,14, alfa 0,52–0,99) sin espuma, orilla, ni diferencia de color clara entre canal profundo, banco central, rodeo sur y bajío. En `justine_bajante_lejos` la zona transitable aparece como **rectángulos de bordes duros y apenas más oscuros** que no se leen como banco ni como vado; la bajante de 0,95 a 0,05 casi no cambia la imagen de lejos. Es el elemento que el jugador necesita leer para decidir la ruta.
- **ART-3 · Pixelado en perfil bajo.** `scaling_3d_scale = 0,5` reescala 720×450 a 1440×900: las texturas del buque y los bordes de los jinetes se ven en bloques (`baja/justine_bajante_cerca`), mientras la UI queda nítida y el contraste con el 3D se nota. Con la RTX 3080 Ti baja no hace falta (473 FPS), pero en equipos modestos es el perfil que se usará.
- **ART-4 · Escala y repetición.** El buque ocupa ~100 px de ancho a distancia de juego; las figuras (12.900 triángulos) se leen como puntos de color; las casas (cajas con prisma) son idénticas, los árboles esferas sobre cilindros, el camino del norte es una fila de discos. Casas de la ribera y obstáculos tácticos en el mismo lenguaje, sin diferenciar zonas.
- **ART-5 · Sin identidad de sectores en el norte.** Ocho sectores con la misma casa de 4 cubos; solo Salta tiene iglesia. La orientación depende del texto.

### 4.3 Render y rendimiento (`world_view.gd`)

- **R1 · Costo de figuras con piel (2,6–2,9 ms por cuadro de 4 ms; ~70 %).** 12 jinetes de ~12.900 triángulos y 16–17 superficies cada uno, más caballos estacionados (8.502 triángulos), todos con `AnimationPlayer`. Propuestas: LOD/mallas simplificadas por distancia, 1 `MeshInstance3D` con menos superficies, una sola figura representativa por grupo a distancia lejos, animación solo cuando se mueve.
- **R2 · Sombras (≈ 3,2 ms con cámara cerca en Justine).** `DirectionalLight3D` con dos divisiones (`SHADOW_PARALLEL_2_SPLITS`) a 130 m renderiza las figuras con piel dos veces. Reducir distancia, o excluir figuras lejanas de la sombra.
- **R3 · El perfil "alta" no existe en la práctica.** Sombras y escala son iguales a media; MSAA 4× no difirió de 2× (≤ 0,05 ms). Añadir algo real (distancia de sombra, resolución de sombra, densidad de decoración, figuras detalladas) o eliminarlo.
- **R4 · Draw calls y nodos (Norte: 1.418–1.561; 516 `MeshInstance3D`).** `_road` crea un `CylinderMesh` + `MeshInstance3D` por cada 0,9 u de camino (cientos de discos), `_house` crea ~7 nodos por casa (cuatro casas × ocho sectores), `_tree` dos, `_ring`/anillos de selección uno por agrupación. En Compatibility no hay instanciado automático: cada nodo es una llamada. Propuesta: `MultiMesh` para caminos, árboles y casas, o malla combinada por sector. Justine: 898 llamadas con sombras (387–555 sin).
- **R5 · Regeneración de rutas (`refresh_paths`).** Cada 0,5 s, si cambia la firma (que incluye `path.hash()` y `stage` de las tres agrupaciones; mientras se mueven cambia siempre), destruye con `queue_free()` y recrea un `CylinderMesh` + `MeshInstance3D` por punto cada 3 nodos de ruta. Cuesta 0,36–0,41 ms por regeneración, sin impacto en FPS, pero crea y libera decenas de recursos por segundo; mejor un solo `MultiMesh` o `ImmediateMesh` actualizado.
- **R6 · Construcción del terreno.** 6 vértices por celda (sin índices) y `terrain_height()` (ruido FastNoise de 4 octavas + bucle sobre sectores en el norte) evaluada por vértice: 43–139 ms. `create_trimesh_collision()` crea un colisionador de triángulos del terreno completo solo para el rayo del cursor. Alternativas: malla indexada, `HeightMapShape3D` o intersección analítica con la función de altura.
- **R7 · `update_state` con `rules.state.units.find(u)` en bucles anidados** (compara diccionarios): 0,03–0,04 ms hoy, sin efecto con tres unidades, pero no escala.
- **R8 · Tirón al cambiar calidad.** `_rebuild_world()` reconstruye todo (45–133 ms); el menú también reconstruye el mundo de Justine cada vez que se vuelve.
- **R9 · Fugas al cerrar (se reproducen con la ruta de salida normal del juego).** Al terminar mis ejecuciones con `quit()` de `SceneTree` (no la ruta `_finish_automation` de QA): (a) en las corridas de capturas y de teclado: *2 ObjectDB instances leaked* (`AudioStreamWAV` y `AudioStreamPlaybackWAV`, el ambiente duplicado con `original.duplicate()` en `_start_environment`), pese a que `_exit_tree()` llama a `shutdown()`; (b) en las seis corridas de benchmark (que terminan con `_rebuild_world`, `_select_unit`, `refresh_paths`): **4 instancias, `Texture with GL ID … leaked 349524 bytes` ×2 y `1 resources still in use`** — el mismo mensaje de 349.524 bytes documentado en `docs/VERIFICACION.md`. Como la corrida de capturas (con varios cambios de escenario) no lo mostró y la de benchmark sí, el defecto no es una fuga simple de reconstrucción de escena. **El origen no se aisló** y no se atribuye. Es un aviso de cierre; no se midió crecimiento de memoria.
- **R10 · Vsync / límite de cuadros.** El juego no expone ajuste de V-Sync ni de tope de FPS; con V-Sync activo el uso de GPU no se vería, pero tampoco hay forma de elegirlo.

### 4.4 Audio

- **AUD-1 · No se oyó nada.** Las corridas usaron el driver Dummy; **no hay evaluación auditiva en esta auditoría**, igual que en 0.1.0.
- **AUD-2 · Datos de los WAV (análisis de archivos):** todos 22.050 Hz, mono, 16 bits. `cannon` 2,20 s, pico −0,45 dBFS; `hoof` 0,25 s, pico −1,82 dBFS; `order` 0,24 s (−10,5); `error` 0,24 s (−17,1); `victory` 3,00 s (−12,8); ambientes `river` y `wind` 12,0 s con pico −7,2 y −16,7 dBFS y RMS −24,0 y −30,9 dBFS. Empalme de bucle ≈ 0 (sin chasquido en el cierre). El viento queda ~7 dB más bajo que el río y luego se aplica −15 dB de ganancia más: probablemente casi inaudible (**sin verificar al oído**). 22 kHz recorta agudos del cañón.
- **AUD-3 · Cobertura de eventos pobre.** Solo cinco efectos y dos ambientes. Sin sonido para desmontaje, captura, bajante, llegada de ronda, ocupación de Salta, mensajes históricos, selección de sector ni cierre de modal; el casco solo suena en Justine y con etapa `moving`. El norte no tiene sonidos de marcha. Sin música ni transición entre menú y partida. Sin audio posicional: el cañón no se localiza.
- **AUD-4 · Cooldown del cañón (900 ms)** y una sola voz (`max_polyphony = 1`): una descarga de varios disparos suena como uno.

### 4.5 Reglas y ritmo

- **RUL-1 · Justine es casi pasivo tras una sola decisión.** La decisión significativa es elegir banco directo o rodeo sur; el cruce es automático. Con la bajante entre 40 s y 210 s y victoria a 473,75 s (directo) o 547 s (rodeo) en la semilla de prueba, **más de la mitad del escenario es esperar** (a 1×; 3× lo comprime pero no añade decisiones). Reagrupar y abordar apenas cambian el resultado. Es una hipótesis de diseño derivada de los datos de las reglas y la lectura del código, no de jugadores.
- **RUL-2 · Casi no hay decisiones intermedias** durante el cruce (exposición alta/baja, fatiga): el jugador no puede responder a las bajas del parte salvo cancelando.
- **RUL-3 · Norte: ritmo por ronda no medido por humanos.** Las rondas 1–6 se resumen en reconocer y proteger; el modelo de pruebas obtiene victoria en 10–11 rondas, derrota pasiva en 12. La tutoría ("Explorar antes de hostigar") es textual y fija. Los botones deshabilitados explican el motivo solo con tooltip (no se ve con teclado ni táctil).
- **RUL-4 · Las dos victorias del norte se encontraron con automatización**; no hay evidencia de alternativas intermedias ni de dificultad ajustable; la carga de decisiones del adversario siempre cae en "buscar víveres" con el mando local (11 decisiones locales en el EXE de Wine).
- **RUL-5 · Información en pantalla.** El panel "SITUACIÓN" de Justine repite texto estático ("Banco central: exposición alta / sur: reducida") en lugar de mostrar el estado de cada agrupación y la profundidad por ruta. En el norte, la fuerza del enemigo en el sector no aparece sobre el mapa salvo el marcador.

## 5. Backlog priorizado por pista

Prioridad: P0 bloquea una buena primera impresión o la legibilidad; P1 mejora clara; P2 pulido. Esfuerzo: S/M/L.

### Interfaz / cámara
| Id | Prioridad | Tarea | Esf. | Criterio medible |
|---|---|---|---|---|
| UI-1 | P0 | Reducir el HUD: paneles colapsables (parte e información) y cabecera de ~48 px | M | Área 3D libre ≥ 65 % (hoy 46 %) |
| UI-3/4 | P0 | Etiquetas con escala constante en pantalla (distance-scale), colisión entre etiquetas, ocultar las de sectores no relevantes y fondo suave | M | Altura de texto 12–20 px a cualquier zoom; 0 solapamientos en las 8 capturas |
| UI-2 | P0 | Fondo y posición fija para la ayuda contextual | S | Contraste ≥ 4,5:1 |
| UI-5 | P0 | Ignorar teclado de cámara si hay un `Control` con foco; liberar foco del desplegable tras elegir; botones con foco y orden de tabulación | S | La cámara no se mueve con foco en el desplegable; Tab recorre ≥ 90 % de los botones (hoy 1 de 22) |
| UI-8 | P1 | Agrupar el parte de artillería por ventana de 10–15 s | S | ≤ 1 línea por ventana |
| UI-7 | P1 | Anclajes/contenedores y prueba en 1920×1080 y 1024×640 | M | Capturas sin recortes en tres resoluciones |
| UI-6 | P2 | Corregir "Jev: Jev:" | S | Una sola ocurrencia |
| UI-9 | P1 | Zoom al cursor, borde de pantalla, seguir selección | M | |

### Arte
| ART-2 | P0 | Agua con diferencia de color por profundidad, espuma de orilla y contorno del banco/vado | M | Banco y canal distinguibles en la captura `justine_bajante_lejos` |
| ART-1 | P1 | Malla indexada con normales suavizadas, textura de terreno o detalle | M | Sin facetas visibles en `norte_lejos` |
| ART-4/5 | P1 | Variantes de casas, identidad por sector, buque de mayor presencia, figuras con LOD | L | |
| ART-3 | P1 | Reescalado 3D más fino o FSR en baja | S | Comparación de capturas |

### Render / rendimiento
| R1 | P0 | LOD y menos superficies en jinetes (≈13 k triángulos, 16–17 superficies); desactivar piel lejos | M | Costo de figuras ≤ 1 ms en media (hoy ~2,9 ms) |
| R2 | P1 | Ajustar distancia/divisiones de sombra y excluir figuras lejanas | S | Cerca-Justine con sombras ≤ 1,5 ms (hoy 3,9) |
| R4 | P1 | `MultiMesh` para caminos, casas y árboles del norte | M | Draw calls norte ≤ 700 en media (hoy 1.561) |
| R3 | P1 | Dar contenido real al perfil alta o retirarlo | S | Diferencia medible ≥ 10 % de costo o eliminación |
| R5 | P2 | Rutas con `MultiMesh` | S | 0 reservas por actualización |
| R6/R8 | P2 | Terreno indexado, colisión por heightmap, reconstrucción incremental | M | Construcción ≤ 60 ms |
| R9 | P1 | Aislar el origen de los 2 avisos de textura de 349.524 bytes y de las instancias de audio con `--verbose` | M | Cierre limpio sin errores |
| R10 | P2 | Ajuste de V-Sync y tope de FPS | S | |

### Audio
| AUD-1 | P0 | Evaluación auditiva real en un dispositivo de salida (sin Dummy) | S | Informe de audibilidad por efecto |
| AUD-3 | P1 | Eventos faltantes (desmontaje, captura, ronda, selección, marcha del norte) | M | ≥ 8 eventos cubiertos |
| AUD-2 | P1 | Rebalancear viento/río, subir muestreo a 44,1 kHz o sintetizar a más calidad | S | Ambientes dentro de ±3 dB |
| AUD-3b | P2 | Audio posicional para el cañón; música/atmósfera opcional | M | |
| AUD-4 | P2 | Polifonía de 2–3 voces para descargas | S | |

### Reglas / ritmo
| RUL-1/2 | P0 | Decisiones durante el cruce (cambiar de ruta, retraso, concentración de fuego); dar sentido a Reagrupar/Abordar | L | ≥ 3 decisiones con consecuencia en 8 min, sin pérdida de determinismo (tests actualizados) |
| RUL-3 | P1 | Ritmo y tutoría de las primeras rondas; sesión con jugadores | M | Tiempo de primera decisión < 60 s y duración 20–35 min medidos con personas |
| RUL-5 | P1 | Mostrar profundidad/estado por ruta y exposición por agrupación | M | |
| RUL-4 | P2 | Más de dos estrategias ganadoras y dificultad | M | |

## 6. Lo que se probó y lo que no

Probado de verdad: las tres suites; arranque del juego con ventana en esta GPU; escenas, capturas (16 PNG) de ambos escenarios, cámaras lejana/cercana, bajante, rasante, menú, perfil alta y baja; FPS de 3 perfiles × 2 escenarios × 2 cámaras con 400 cuadros cada una; sondas de atribución; foco y teclado del desplegable por eventos inyectados; conteos de escena; análisis de archivos de audio y de las mallas; avisos al cerrar.

No probado: sonido real (Dummy); EXE exportado; entrada física del SO; otras resoluciones y GPU integradas; memoria, arranque en frío y partidas largas; jugadores humanos; el costo por GPU frente a CPU; la causa de la fuga de texturas; el pico de la baja de Justine; el sistema de rondas completas con la automatización QA propia (no se repitió).

## 7. Evidencia nueva

`evidence/fase2/auditoria/`: `alta/` y `baja/` (PNG), `json/` (conteos y resultados de cada corrida), `audit_fase2.gd.txt` (script de medición, extensión `.txt` para que Godot no lo importe; para usarlo, copiar como `.gd` fuera del proyecto y ejecutarlo con `--script`, argumentos tras `--`: `--mode=shots|bench|keys --scenario= --quality= --out=`).
