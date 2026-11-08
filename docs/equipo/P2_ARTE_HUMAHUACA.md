# P2 · Arte 3D y cámara del nivel II «Humahuaca»

Pista P2 del equipo, tanda 2. Fecha: 2026-11-08. Rama `equipo/p2-arte-humahuaca`, que sale de `equipo/integracion` (70b2341) y tiene mezclado `equipo/integracion` (72da483, los modelos de P6). Tickets: V-03, P-006, T-007 (la mitad de la vista) y T-010. Las capturas están fuera del repo, en `qa-equipo/p2/`.

## 1. Qué cambió

**Noche con contraste (objetivo 1).** Todo sale de `data/humahuaca_visual.json`, sin HEX nuevos: la paleta sigue con sus 24 ids y lo nuevo se arma con ganancias y mezclas.
- La luna es fría (celeste con un 15 % de blanco) y tiene energía 0,62, viene del ESE con 36° de elevación y proyecta sombras. Ilumina las caras que ve la cámara, que mira con rumbo 325°.
- El ambiente es azul y violáceo, con energía 0,38 (antes 1,35). El cielo nocturno tiene la franja del horizonte violácea.
- Hay una hora nueva, **madrugada** (`time_of_day` 0,3, a los ≈ 267 s): la tierra sigue oscura y los fuegos encendidos, pero el horizonte ya se pone rosado. Después llegan el alba (0,5) y el día. La vista mezcla las horas que estén en `lights`, ordenadas por su hora.
- La curva de color va por hora (`lights.<hora>.grade`): fría de noche (contraste 1,15 y saturación 0,92) y más cálida al alba. El resplandor es aditivo con umbral 1 en media y alta, y la oclusión SSAO solo se activa en alta (`look` del JSON).
- La niebla va por distancia (`fog.mode = profundidad`, de 120 a 7 000 m, curva 0,6, niebla máxima `depth_max` por hora): deja limpio el cuadro de juego y pone los cerros en capas. La `density` exponencial queda igual para el stub.
- Los **fuegos iluminan de verdad**: OmniLight sin sombra con energía 14 en media y 16 en alta, alcance de 2,4 × el radio de la luz, atenuación 1, parpadeo de ±12 % y color de fuego (oro con 22 % de rojo). La mancha y el resplandor toman el mismo color. Pesan según la hora: 1 de noche, 0,35 al alba y 0,12 de día.
- Casi la mitad de las casas tienen **lumbre en la puerta**: puntos emisivos que el resplandor abre y que se apagan con el día. Es aspecto de diseño, sin datos.
- La lluvia es más tenue (alfa 0,18, antes 0,35).

**Legibilidad (objetivo 2).**
- Las fichas propias miden 72, 68, 68, 64 y 68 px (`min_px`). Medido a 1280 × 720: **65 a 85 px** en las cinco tomas (antes 49 a 75).
- Los enemigos tienen un piso de 28 px en media y alta (antes 14) y de 24 en baja. Medido en el ataque: **37 px** (antes 18).
- Regla de color común:
  - aliado: celeste ×1,1 ≈ #8DB8D6;
  - objetivo: **oro que late** (alertado también; en alarma o asaltado pasa a rojo, y tomado, a celeste), con un filete de tinta debajo;
  - enemigo: anillo rojo ×1,2 ≈ #B8433A con borde de tinta y contorno 1,8 veces más grueso;
  - arreo: anillo hueso.
- Las fichas usan el shader nuevo `shaders/humahuaca_token.gdshader`: luz propia (22 %) y un borde de luz del color del bando. Llevan debajo un disco de tinta al 50 %, y los anillos son más finos.
- Reconocedores: un baqueano de pie con tacuara y otro agachado. Antes eran dos figuras agachadas que, al estirarlas hasta el alto pedido, se volvían una mancha ancha.
- **P-006: las cinco partidas y los tres objetivos entran en el primer cuadro** con el preset nuevo `partidas_y_objetivos` de `data/humahuaca_camera.json`: objetivos a ≥ 10 % del borde y partidas a ≥ 3 %. `test_hx_camera` lo exige a 1280 × 720, 1920 × 1080 y 2560 × 1440. El peor margen de partida es 3,0 % (el arreo).

**Escenario (objetivo 3).**
- **Paredes de la quebrada**: el anillo del horizonte sube de 500 a 900 m en unos 2,5 km al oeste y al este, con cárcavas y crestas dentadas. Hacia el norte y el sur el valle sigue y sube menos (`gfx.ring_height`). Es aspecto razonado: el relieve real de Copernicus llega solo hasta el borde del contexto y acá se lo continúa.
- Suelo: manchones de tierra húmeda y de pasto seco de decenas a cientos de metros, más variación a gran escala y laderas más oscuras. La piedra de ladera pasa a parda, porque con la luna el gris se leía como charcos azules. El brillo especular es más bajo.
- La plaza usa el mismo material del suelo (`material: suelo`), en lugar de un parche liso y claro.
- Casas procedurales (las que quedan de respaldo): adobe con cal en una de cada cuatro y techos de torta de barro pardos. Churqui más claro.
- **Modelos de P6 enchufados** (sección 4): casas del núcleo, capilla, casa de posta, corral, tapias en módulos de 4 m, piezas de artillería reales en la batería, brasero y fogón.
- **T-010**: `height_at`, `_hf_lookup`, `_ctx_at` y `Relief.bilerp` leen una coordenada NaN como 0, y `Sight.los` con un punto NaN da false. `tests/revision_nube/d_nan_altura.gd` pasa con 0 errores.
- **T-007, la mitad de la vista**: cada hueco entre dos tapias (extremos de tapias distintas a 2,5–10 m) se dibuja según lo que dice `terrain.is_blocked` en su centro. Si se puede cruzar, lleva jambas y un umbral; si no, una tranquera de tres palos. Hoy salen 2 abiertas y 7 cerradas: los dos huecos de 4 m de la posta se ven cerrados porque la navegación los da por muro. Cuando P3 los abra, la vista los mostrará abiertos sin tocar nada.

**Cámara (objetivo 4).**
- La inclinación inicial pasa a **42°** (antes 52°) en `initial_frame` y en las vistas `juego_noche` y `juego_alba`. El rumbo sigue en 325° (A-11).
- Nuevo **`zoom_tilt`**: al acercar con la rueda por debajo de 220 m, la cámara se va acostando hasta 24° a 50 m. Ahí aparecen el horizonte y los cerros (`qa-equipo/p2/despues_6_cerca/`). Al alejarse vuelve a 42°; inclinar a mano lo desactiva hasta volver a estar lejos.
- La rueda corrige hasta tres veces el punto que queda bajo el cursor: desvío 0,13 m en 5 pasos (antes 0,65 m; con la cámara baja y sin la corrección llegaba a 8,5 m).

## 2. El compromiso, dicho claro

**Con 40–44° no se ve el cielo en el cuadro inicial.** Con 46° de campo vertical, el borde de arriba mira 19° por debajo del horizonte y pega en el suelo a unos 600 m del centro, todavía dentro de la ventana. Medí hasta 32° y tampoco alcanza. El horizonte y los cerros aparecen al acercar (`zoom_tilt`), en la apertura y en las vistas bajas.

**«Más cerca» contra «las cinco partidas en el cuadro».** El contenido mide 621 m de punta a punta (del arreo a la posta). Con los objetivos a 10 % y las partidas a 3 %, la cámara queda a **455 m**, contra 321 m del preset de la nube, que dejaba cuatro partidas fuera, y 489 m de R1. El pueblo ocupa el 11,5 % del cuadro (antes 35 %). Los rumbos de 35°, 55°, 235° y 255° dan entre 661 y 814 m, y el de 340° unos 401 m (rompe A-11). Las fichas no pierden tamaño (64–85 px a cualquier zoom) y los objetivos se leen por los fuegos y el oro. Si el lead prefiere el pueblo grande, cambiar el preset por `pueblo_zona_al_borde` es una sola clave en el JSON.

## 3. Pruebas (headless, Godot 4.7.2, APPDATA aislado)

| Suite | Antes (70b2341) | Después |
|---|---|---|
| `test_hx_view` | 284 / 0 fallas | 284 / 0 |
| `test_hx_camera` | 47 / 0 | 51 / 0 (4 nuevas: P-006 a tres tamaños y el criterio de los reconocedores) |
| `test_hx_terrain` | 167 / 0 | 167 / 0 |
| `test_hx_smoke` | 158 / 0 | 158 / 0 |
| `test_hx_data` | 0 fallas | 426 / 0 |
| `revision_nube/d_nan_altura` | falla (11 SCRIPT ERROR) | pasa |

El único cambio a una prueba de mi área: `tests/test_hx_camera.gd`. Si el preset tiene las partidas como puntos duros, ahora exige que las cinco entren a ≥ 2 % (es más estricto) y el criterio «reconocedores o zona» acepta ese preset. No se debilitó ningún criterio de legibilidad.

`revision_nube/d_borde_sur` sigue fallando. Lo probé: con la fila de z = 652 transitable pasa, pero rompe en `test_hx_terrain` la comprobación de que el borde del mapa está cerrado. Lo revertí y queda como pedido a P3 (sección 6).

## 4. Integración de los modelos de P6

Están en `models` de `humahuaca_visual.json`: `dir` más el nombre de cada archivo, sin `res://`, para que la validación V12 no exija archivos ausentes, y `enabled`. Si un archivo falta, se usa el generador de siempre. Reemplazar un modelo es cambiar su nombre o su carpeta en el JSON.

`gfx.model(clave)` une las piezas del GLB en una sola malla, conserva el material de cada superficie (el ancla del color por vértice y las brasas emisivas) y la guarda en una caché estática. `gfx.model_fit` estira el modelo a la huella, y lo gira si el lado largo no coincide.

| Modelo | Dónde | Cómo |
|---|---|---|
| `hx_casa_adobe`, `hx_casa_adobe_grande` (frente ≥ 9,5 m) | 85 casas del núcleo (56 + 29) | Una MultiMesh por modelo, con un tono por casa (0,74–0,90) por color de instancia |
| `hx_capilla` | templo (`props.por_id.templo.model`) | Sin deformar (`model_fit: uniforme`) y con la huella ajustada; 7,9 m pasa TR-094 (≤ 8 m) |
| `hx_casa_adobe_grande` | casa de posta | Frente hacia el patio |
| `hx_corral` | `corral_posta` | Al alto del hito (1,2 m) |
| `hx_tapia` | tapias de `terrain.features("tapia")` | Un módulo por tramo de ≈ 4 m, en MultiMesh |
| `hx_pieza_artilleria` | batería | Una por cañonera (`gen.battery_piece_spots`), con la boca al oeste |
| `hx_brasero`, `hx_fogon` | luces de la guardia | La llama del fogón a 0,6 m |

`hx_pirca` queda listado, sin uso: no hay rasgos «pirca» en el nivel. El cuartel (casa del cura) sigue procedural, porque es la única casa encalada con aspilleras y patio, y es la que identifica al objetivo.

## 5. Rendimiento (benchmark oficial, 1440 × 900, 3 repeticiones)

| | Cuadro medio | Peor repetición | p95 | Construcción (`scene_build_ms`) |
|---|---|---|---|---|
| media antes | 1,472 ms | 1,704 | 3,454 | 1 176 ms |
| **media después** | **1,586 ms** | 1,649 | 1,771 | **1 392 ms** (otra corrida: 1 316) |
| alta antes | 1,271 ms | 1,345 | 1,699 | 1 266 ms |
| **alta después** | **1,850 ms** | 1,859 | 1,984 | 1 295 ms |

Todo entra en los topes (4,0 ms de cuadro y 1 500 ms de construcción). La construcción en media queda ajustada, y lo que más suma es el terreno (≈ 220 ms por etapa en la prueba). En alta la SSAO cuesta unos 0,5 ms.

## 6. Pedidos a otras pistas

1. **P3 (navegación), T-007 y `d_borde_sur`.**
   - `scripts/humahuaca/terrain/terrain_raster.gd::_stroke_nodes`: el redondeo de los extremos (`roundi`) cierra los huecos de 4 m de la posta. Propuesta: que el extremo de una tapia que termina en un hueco se redondee hacia adentro de la tapia (`floor`/`ceil` según el sentido). Cuando estén abiertos, la vista dibujará las jambas sola.
   - `scripts/humahuaca/rules/humahuaca_nav.gd:90` (`cell_of`): sujeta la fila a `nz − 1` (z = 652, sólida). Propuesta: sujetarla a `floori(size_m.y / cell)`, como `_node_index` del terreno.
   - El centinela de la posta (`d_centinela_posta`) es dato de reglas.
2. **QA (`tests/hx_validators.gd`, `OWNER_KEYS.visual`)**: agregar `look` y `models` como claves de la pista visual. Hoy salen como «sin dueño conocido», que no es falla.
3. **P5 (`data/humahuaca_ui.json: camera.opening`)**: bajar las paradas de la apertura a 22–28° de inclinación para que se vean el cielo y la quebrada (dirección de arte, B4). El cuadro final sale del preset y ya está a 42°.
4. **P5 (`tools/ui_qa_humahuaca.gd`)**: `_token_margins` y `_cycle_overflow` ya pueden volver a exigir las cinco partidas en el cuadro. `avoid_rects` supone 62 px por figura, y las fichas ahora miden hasta 85 px.
5. **P4/P5 (viñeta común)**: la viñeta de 0,3 de la dirección de arte (D1) le haría bien al II. No la puse en la vista porque es una capa de interfaz.
6. **P6**: el color por vértice de los GLB se ve bien con su propio material. Si algún día pasan por el material de props de la vista, hay que tener en cuenta que ese shader supone sRGB.

## 7. Evidencia (`qa-equipo/p2/`)

- **Hojas comparativas, antes a la izquierda y después a la derecha, mismo procedimiento:**
  - `cmp_1_inicio.png`: tras «Empezar»; cada versión con su cámara inicial.
  - `cmp_2_noche_ataque.png`: juego guiado hasta la señal, a 266 s.
  - `cmp_3_alba_extraccion.png`: a 321 s.
  - `cmp_4_fichas_cerca.png`: la misma cámara en las dos.
  - `cmp_5_camara_r1_ataque.png`: arte contra arte con la cámara de R1.
- **Secuencias**: `secuencia_despues/00–19.png`, 20 cuadros, uno por segundo, jugando a ×2 con el botón del siguiente paso. Hojas de contacto `secuencia_despues_hoja.png` y `secuencia_antes_hoja.png`.
- **De cerca, con la cámara acostada**: `despues_6_cerca/pano_0..2.png`.
- **Métricas** en `metricas_antes.json` y `metricas_despues.json`: alto de fichas y enemigos, objetivos en cuadro y luminancia. La luminancia media nocturna bajó de 0,34 a 0,26 en el inicio y de 0,40 a 0,15 en la madrugada del ataque.
- **Banco**: `bench_antes/`, `bench_despues/` y `bench_despues2/`.
- **Scripts**: `scripts/captura_p2.gd` (tomas y secuencia), `exp_pano.gd` (vistas libres) y `sheets.py` (hojas).

**Crítica honesta.**
- La noche ahora es noche: fuegos cálidos que iluminan, pueblo con lumbre, objetivos en oro, enemigos en rojo y la quebrada recortada al acercar.
- La madrugada del ataque es la toma más lograda, aunque quizás un poco oscura para leer las casas: subir 0,05 el ambiente de `madrugada` es un ajuste fino posible.
- El cuadro inicial ganó atmósfera y las cinco partidas, pero el pueblo es más chico que en el preset de la nube (sección 2).
- Las figuras procedurales siguen siendo toscas de cerca. Tienen el tamaño y el color que piden los criterios; el modelado de las figuras queda para otra tanda.
