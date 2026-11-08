# P1 · Arte 3D de la Justina (I), el Norte (III) y el fondo del menú

Pista P1, 8/11/2026, rama del worktree `worktree-agent-a9d3bab930364ed9f` (base `equipo/integracion` 70b2341). Tickets V-01 (look), V-02 y V-04. Aplica `qa-equipo/arte/DIRECCION_DE_ARTE.md` (paquetes A1, A2, A3, C1, C2 y C3 en la parte que se resuelve por código).

## Qué cambió

**Contrato con P4.** `world_view.set_look(nombre)` acepta `"menu"`, `"justina"` y `"norte"`, y también los alias `"juego"` y `"heroico"`.
- Es idempotente: pedir el look que ya está no hace nada.
- Cada cambio parte de una **copia nueva** del Environment base (con su cielo y su material de cielo) y del sol base. Repone además los parámetros del agua y la visibilidad de las capas, y reemplaza la viñeta. No se acumula nada: la prueba de 11 cambios seguidos terminó con 1 viñeta, el sol en su valor y las capas visibles.
- Si se pide un look de otro escenario, se ignora (por ejemplo, `"menu"` sobre el mundo del Norte).
- `build()` aplica el look que corresponde **sin que nadie lo llame**: `"norte"` en el III; `"menu"` si el padre tiene `mode == "menu"` (es lo que pasa en `main._menu()`); `"justina"` en el resto de los casos.
- Hay dos ganchos para P4:
  - `look_vignette_enabled`: ponerlo en `false` antes de `set_look` si la interfaz pone su propia viñeta.
  - `menu_camera_pose()`: devuelve la pose del fondo heroico.

**Archivos**
- `scripts/looks/world_looks.gd` (nuevo). Contiene la paleta, los tres looks, la curva de grading por canal (cálida, cálida suave y fría), la viñeta (CanvasLayer de capa 0, debajo de la interfaz) y los parámetros de cielo del agua de cada look.
- `scripts/world_view.gd`. Suma `set_look`, el look automático, la niebla del Norte que sigue a la cámara, la regla de color y el reteñido del poncho.
- `assets/terrain.gdshader`. Modo `northern`: rampa por altura y pendiente, curvas de nivel y borde que se funde a tinta. Lo usa solo `_ground()` (Norte). El modo anterior queda igual.

### Menú (A2, look `"menu"`)
- **Sol:** `#FFB36B`, 1,6, rotación (−11°, 75°).
- **Ambiente:** `#8F86A6` a 0,42.
- **Cielo:** horizonte (0,98, 0,70, 0,42); cénit (0,14, 0,16, 0,28); nubes (1,0, 0,76, 0,52) y (0,26, 0,20, 0,30).
- **Niebla:** `#D9925A`.
- **Glow:** 0,7, bloom 0,08, umbral 0,95.
- **Grading:** cálido, contraste 1,12, saturación 1,02.
- **Viñeta:** 0,5.
- **Agua:** el cielo que refleja el agua pasa a horizonte (0,98, 0,70, 0,42) y cénit (0,20, 0,21, 0,33), con `sun_dir` = el sol del look.
- **Se ocultan:** la **baliza blanca** (las balizas no se ven en este look), el abanico y el rótulo de la zona de fuego, los rótulos, la ficha del buque, las fichas y los aros de los grupos.

**Pose de cámara del prototipo, para que la ponga P4 en `main._menu()`:**
- `camera_target = buque + (−60, 18, −45)` = `Vector3(520, 18, 217)`
- `camera_distance = 230`
- `camera_pitch = 0.16`
- `camera_yaw = -1.25`

La misma pose la devuelve `world.menu_camera_pose()`. El prototipo sumaba además una deriva lenta de ±0,04 rad en 30 s. Queda a criterio de P4, porque el pedido era «sin movimiento de cámara».

### Justina en juego (A1 + A3, look `"justina"`)
- **Luz:**
  - Sol `#FFDAB0` a 1,1, rotación (−26°, −60°).
  - Ambiente `#BAB3BA` a 0,6.
  - Cielo: horizonte (0,95, 0,80, 0,60), cénit (0,30, 0,36, 0,48), nubes (0,98, 0,86, 0,70) y (0,40, 0,38, 0,46).
  - Niebla `#D8B48A`. Glow 0,6, sin bloom, umbral 0,95.
  - Grading **cálido suave**, contraste 1,07, saturación 1,0. Calienta las luces y casi no toca los medios.
  - Agua: horizonte (0,95, 0,82, 0,64) y cénit **sin cambios** (0,50, 0,58, 0,62).
- **Por qué esos valores y no los del prototipo:** con los de la dirección (sol `#FFD6A4` a 1,15 y curva cálida plena), el agua perdía el verde y quedaba del mismo marrón que la orilla, y el contraste agua/orilla es la lectura del nivel.
- **Regla de color (vale en todos los looks):**
  - Fichas propias: **celeste `#8DB8D6`**. Antes `#F0C25A`, `#4FC7B8` y `#EC8FB6`; los exploradores van en `#A9CBE2`. La identidad la da la silueta, que ya existía.
  - Aro de selección: oro viejo `#C9A25E`. Tropezó: ámbar `#D9903A`. Trabajando: violeta `#9A80D4`.
  - Ancla y halo del grupo: celeste con borde pergamino. El halo pasa a violeta cuando el grupo está seleccionado.
  - El encarnado del guion de Güemes (`#983C3C`, viene del JSON) se reemplaza en código por oro viejo.
  - **Zona de fuego** en rojo realista `#B8433A`: relleno ≤ 0,065, degradado desde el buque; aro al 0,55; aro punteado de Gillespie al 0,2; rótulo `#E58478` (antes rosa salmón `#E6A08C`). El relleno queda más bajo que el 14 % que pedía A3: con 12 % todo el río se teñía de rosa.
  - Señal de captura: la franja bermellón pasa a violeta hondo `#3B2A5C`.

### Norte (C1 + C2 + C3, look `"norte"`)
- **Fondo:** `BG_COLOR #0C0A10`, sin cielo.
- **Niebla de profundidad:** `#15111A`, curva 1,6, `fog_sky_affect` 1. Empieza a 1,08 × la distancia al punto que mira la cámara y llega a tinta 95 m después; con la cámara inicial queda en ≈ 104 → 199 m, igual que el prototipo. Se recalcula solo si cambia más de 2 m, así el zoom no apaga el mapa.
- **Sol:** `#FFC282` a 1,55, rotación (−24°, −118°).
- **Ambiente:** `#6A6288` a **0,8**. Con 0,6 las figuras en ladera quedaban negras; es lo que preveía C1.
- **SSAO** 1,7, glow con umbral 1,0, grading cálido con contraste 1,12. Viñeta 0,45. Sin niebla volumétrica.
- **Relieve (`terrain.gdshader`, modo `northern`):**
  - Rampa valle `#574B3E` → ladera `#94856B` → cresta `#CFC2A8`, entre 0,4 y 15 m.
  - Le queda un 22 % del color de vértice en los valles. Se oscurece ×0,7 a 45° de pendiente.
  - Curvas de nivel cada 1,5 m (oscurecen un 16 %, con antialias y se apagan donde se amontonan). Borde de 6 m que se funde a `#0E0C12`.
  - Los HEX de la dirección (`#4A3A28` / `#A9814A` / `#D8C49A`) daban un relieve naranja bajo el sol `#FFC282`: se desaturaron.
- **Bandos:**
  - `rider_1817` se retiñe en carga, sin regenerar el GLB: el poncho y la faja granates pasan a lana parda `#705741` y ocre `#8A7350`.
  - Solo la primera figura del grupo de Güemes conserva un granate oscuro `#5E1F1A`, como acento de héroe (regla 4).
  - El marcador realista suma un aro rojo `#B8433A` con borde `#2A1414`; la banderola es 1,6 veces mayor (2,4 × 1,28 m), en `#B8433A`; el rótulo «◆ REALISTAS» va en `#E58478`.
  - Aros de grupo: celeste siempre visible y oro viejo el elegido.
  - Aro de sector: oro viejo si está elegido, violeta si está reconocido.
  - Caminos fijos en oro viejo; ruta propia en violeta claro `#A58AE0`.

## Pruebas

- `tests/test_rules.gd` (headless): **871 comprobaciones, 0 fallas**. Corrió dos veces: sobre `7605514` y sobre el estado final.
- `tests/test_integration.gd` (headless): **283 comprobaciones, 0 fallas**. Corrió dos veces: sobre `7605514` y sobre el estado final.
- Sin `SCRIPT ERROR` ni `SHADER ERROR` en esas corridas ni en las capturas.
- No hubo que tocar ningún test. El `tests/test_integration.gd:1426` que cita A3 pertenece a un mundo de prueba (StubWorld) y no compara colores de `world_view`, así que no falla.
- **Muestreo de color del Norte** (`qa-equipo/p1/color_check.log`). Cuenta vértices con tono a menos de 15° del rojo, saturación > 0,45 y valor > 0,3, en sRGB:
  - GLB original: 890 de 16 209.
  - Después: 0 en 11 de las 12 figuras patriotas.
  - Queda 472 en la figura de héroe de Güemes, que lleva el granate oscuro a propósito.
- La misma corrida comprueba también:
  - `set_look` idempotente.
  - El Norte ignora `"menu"`.
  - Después de 11 cambios menú↔juego queda 1 viñeta, el sol vuelve a 1,1 (en el menú es 1,6) y las capas ya no están ocultas.

## Rendimiento

Medido con `tools/bench_gpu.gd`: calidad media, 1440 × 900, sin V-Sync, 3 corridas por escenario, con otros agentes usando la GPU en paralelo.

| Escenario | Cuadro medio antes | Cuadro medio después | GPU (mediana) antes → después |
|---|---|---|---|
| I · Justina | 2,84 ms | 2,64 ms | 2,59 → 2,43 ms |
| III · Norte | 1,78 ms (mediana 1,38) | 1,41 ms (mediana 1,32) | 0,758 → 0,788 ms (+4 %) |

Los dos niveles quedan dentro del margen de 1,15×. En el I se recorta el bloom: no hay efectos nuevos y el glow es más barato. En el Norte la niebla de profundidad reemplaza a la exponencial; el SSAO, el glow y el shader nuevo suman unos 0,03 ms de GPU. Los JSON están en `qa-equipo/p1/bench_*.json`.

## Evidencia

Todo está en `qa-equipo/p1/`. Antes y después salen del mismo encuadre, con perfil nuevo en cada corrida, semilla del río 1806 y el ratón neutralizado para que no mueva la cámara.

- **Hojas lado a lado:** `cmp_00_menu`, `cmp_01_menu_heroico` (pose del prototipo), `cmp_02_menu_tras_norte`, `cmp_11_justina_inicio`, `cmp_12_justina_en_juego`, `cmp_30_norte_inicio`, `cmp_31_norte_cerca`.
- **Recortes:** `zoom_norte_bandos.png`, `zoom_justina_fichas.png`.
- **Scripts:** `qa-equipo/p1/scripts/`. Son las capturas, el muestreo de color, las hojas y el resumen del banco de pruebas.

## Crítica honesta

- **Menú con la pose del prototipo:** es la mejora más clara. El buque queda a contraluz, el reflejo del sol cae en el agua y la baliza ya no está.
- **Menú con la cámara actual de `main.gd`:** queda un agua marrón oscura vista desde arriba. Es correcto pero no lucido, porque el look necesita la pose baja (P4).
- **Norte:** el cambio es grande y va en la dirección del prototipo: relieve dorado y escultórico, valles violáceos y bordes que se funden en negro. Tiene dos costos:
  - Las figuras patriotas ya no se recortan contra el suelo como cuando eran rojas (en los valles en sombra se leen poco). Las sostienen los aros y los rótulos de la interfaz.
  - Las curvas de nivel apenas se ven a la distancia de juego.
- **Justina:** la mejora es moderada, como anticipaba la dirección. La orilla toma oro y el agua conserva el verde agrisado. Lo que más pesa en ese nivel es el HUD, que no es de esta pista. Los iconos pastel que se ven sobre las fichas los dibuja `main.gd`.

## Pendientes y pedidos a otras pistas (no se tocaron archivos ajenos)

- **P4 · `scripts/main.gd`:**
  - `:396–398` (`_menu`): poner la pose de `world.menu_camera_pose()` (valores arriba). Si se agrega `world.set_look("menu")` con `has_method`, hacerlo después de `_rebuild_world()`; es inocuo porque ya está aplicado.
  - `:400`: el `ColorRect` del panel del menú (`Color(0.025,0.05,0.055,0.80)`) pasa al degradé de tinta de D2.
  - `:74`, `UNIT_COLORS`: pasar a la regla de color para que la interfaz coincida con las fichas 3D. Los tres grupos van en `Color("8db8d6")` y los exploradores en `Color("a9cbe2")`. La identidad la dan `UNIT_GLYPHS`, que ya existen. Estos colores también tiñen los iconos y elipses que `main.gd` dibuja sobre los grupos en el I y en el III (hoy amarillo, turquesa y rosa).
  - Si P4 pone su propia viñeta (D1): `world.look_vignette_enabled = false` antes de `_rebuild_world()`, o quitar el nodo `VinetaLook`. Si no, quedan dos viñetas.
- **P6 / lead · `tools/create_models.py:377`:** cuando se pueda regenerar `rider_1817.glb`, poncho en `#705741` y variante «héroe» aparte. Hoy el reteñido en carga (`world_view._recolor_poncho`) lo resuelve.
- **Lead, decisión:** la figura de héroe granate en el grupo de Güemes sigue la regla 4 de la dirección. Para quitarla: en `_create_group`, cambiar `str(unit.id)=="guemes" and i==0` por `false`.
- **P1, queda para después:**
  - Sumar la orilla en primer plano del menú, que depende de la pose.
  - Un contorno o realce de las figuras del Norte en sombra, si el playtest lo pide.
  - Marcar más las curvas de nivel en el zoom cercano.

---

# Ronda 2 · lectura del lugar en la Justina y realce en el Norte

Pedido del lead: la Justina «se lee como un mapa, no como un lugar». En el Norte, las figuras propias se perdían en los valles en sombra. Trabajo sobre `equipo/integracion` 3ea36d8.

## Qué cambió

**Barranca del Retiro** (`shaders/terrain_justina_r4.gdshader` y `world_view._barranca_j`)
- **Por qué no se veía:** el shader buscaba la pared con umbrales de pendiente que la barranca real (17–30°, `slope` 0,04–0,13) nunca alcanzaba. Por eso la pared salía como arena lisa. Con umbrales nuevos de 0,012–0,045 aparecen:
  - La pared más oscura (×0,84).
  - Manchones de pasto y matorral pegados al talud.
  - Canaletas de escurrimiento irregulares.
  - Un filo claro de tosca arriba y una franja de sombra al pie.
- **Talas y ombúes en el borde:** grupos de 1 a 3 árboles cada 8–18 m, con escala 1,25–2,3. Su sombra de la tarde cae por el talud hacia el río.
- **Talud:** unas 300 matas, cortaderas y arbustos (densidad con ruido).
- **Zonas libres:** no se planta sobre hitos, bajadas, obstáculos ni el arranque de los grupos (`_reserved_j`).

**Caserío** (`world_view._meseta_town_j`)
- Quintas sobre la meseta (x 22–62 m), al oeste de los hitos.
- Cada una lleva 2–4 casas variadas (azotea, rancho o teja), una tapia de patio y 3–6 frutales. Dan escala humana.
- Es reconstrucción estética: Vidal 1820 muestra caserío bajo y árboles sueltos.

**Agua** (`shaders/water_rio_plata.gdshader`)
- El agua **recibe sombras reales** (antes `shadows_disabled`).
- **Sombra del casco reforzada:** el reflejo del cielo no se oscurece con la luz, así que se refuerza en el shader. La sombra cae del lado opuesto al sol, a unas dos mangas, y se escala con el casco.
- **Estela de corriente aguas abajo:** una cola que se abre, con vetas de espuma que viajan. Se apaga con el río bajo.
- Sigue siendo **agua turbia uniforme**. Lo medido ya se resalta: las franjas de sondeo verde, ámbar y rojo existían y no cambian. La lectura de la profundidad no revela el fondo.
- La saturación del look «justina» baja a 0,95: la meseta ocre se iba a naranja en el plano oblicuo.

**Buque**
- Gallardetes largos en el tope de cada palo, en rojo realista (el buque es del bando enemigo).
- El tope sale del vértice más alto de cada palo del GLB. Ondean por shader y siguen la escala del casco.
- Se suman al pabellón mercante, que ya estaba.

**Norte, realce de las figuras propias**
- Cada figura propia (`rider_1817` reteñido) lleva un `material_overlay`: luz de borde celeste pálido `#A8CCE6` (fresnel ^2,2 × 0,62) más un piso mínimo de luz (0,035). Es aditivo y sin luz, así que se ve también en sombra. No vuelve al rojo.
- El aro de aliado es más grueso (2,45–2,9 m), sin luz y se dibuja por encima del relieve (`no_depth_test`): en ladera ya no queda medio enterrado.
- El elegido pasa a oro viejo.

## Pruebas

- `tests/test_integration.gd`: **283 comprobaciones, 0 fallas**.
- `tests/test_rules.gd`: **871 comprobaciones, 0 fallas**.
- Sin `SCRIPT ERROR` ni `SHADER ERROR` en las pruebas ni en las capturas.

## Rendimiento

Medido con `tools/bench_gpu.gd`: calidad media, 1440 × 900, sin V-Sync, 3 corridas. La base es la medición original de la ronda 1, antes de P1.

| Escenario | Base | Ronda 1 | Ronda 2 | Ronda 2 / base |
|---|---|---|---|---|
| I · cuadro medio | 2,84 ms | 2,64 ms | 3,01 ms | 1,06× |
| I · GPU (mediana) | 2,59 ms | 2,43 ms | 2,62 ms | 1,01× |
| III · cuadro medio | 1,78 ms | 1,41 ms | 1,51 ms | 0,85× |
| III · GPU (mediana) | 0,758 ms | 0,788 ms | 0,795 ms | 1,05× |

- El I suma 10 llamadas de dibujo (389 → 402).
- El III suma unas 100 por el pase de realce (255 → 357); el CPU de render pasa de 0,23 a 0,27 ms.
- Los JSON están en `qa-equipo/p1/r2/bench_r2_*.json`.

## Evidencia

Todo está en `qa-equipo/p1/r2/`: antes = ronda 1 (3ea36d8); mismo encuadre, perfil nuevo, semilla 1806 y ratón neutralizado.
- **Hojas:** `cmp_11_justina_inicio`, `cmp_12_justina_en_juego`, `cmp_13_justina_barranca` (oblicuo, sin interfaz), `cmp_14_justina_buque`, `cmp_30_norte_inicio`, `cmp_31_norte_cerca`.
- **Recortes:** `zoom_justina_barranca_juego.png`, `zoom_norte_figuras.png`.
- **Secuencia en movimiento:** `seq/despues_seq_00..17.png` y `seq/antes_seq_00..17.png`. Son 18 cuadros cada 0,5 s con los tres grupos en marcha. Tiras: `seq_despues_tira.png` y `seq_antes_tira.png`.
- **Scripts:** `qa-equipo/p1/scripts/` (`p1_capturas_r2.gd`, `cap_r2.sh`, `hojas_r2.py`).

## Crítica honesta

- **Barranca en oblicuo (`cmp_13`):** es el cambio más grande. La barranca pasa a leerse como un escalón real, con filo, pared en sombra, pie oscuro y árboles cuyas sombras largas bajan al río. Las quintas dan escala.
- **A la distancia de juego (`cmp_11`, cámara a unos 380 m):** la mejora existe pero es moderada. Se ve una franja de barranca más oscura con textura y algunos árboles. Al lado del HUD y de la cámara casi cenital, el lugar todavía pesa poco. Lo que más ayudaría es una cámara de juego algo más baja o inclinada, y eso es de P4.
- **Buque:** los gallardetes y la estela se ven. La sombra del casco es sutil desde arriba, y desde la cámara oblicua la tapa el propio casco.
  - Sigue la gran lente clara alrededor del casco: el bajo y la espuma del borde, ya existentes, escalados con el buque. Se lee como banco de arena y le resta presencia al barco. Es lo próximo a revisar.
  - También quedan las manchas claras de espuma en primer plano del agua cercana.
- **Norte:** las figuras ya no se pierden en sombra. De cerca el realce las deja algo plateadas, como estatuillas; a la distancia de juego se leen como fichas propias celestes, que es lo que pide la regla.
- **Secuencia:** el agua, la estela y los gallardetes se animan. La marcha a ×2 vuelve sola a ×1: es el ticket P-004 de P4, no de esta pista.

## Pendientes

- **P1:**
  - Achicar o rediseñar la lente del bajo alrededor del casco: que muestre «apoyado» sin tapar el barco.
  - Quitar las manchas claras de espuma cercana.
- **P4:** si se baja un poco la cámara de juego del I (por ejemplo inclinación de 48–50° en lugar de 55°), la barranca y los árboles ganan mucho. Hoy `pitch_deg_default` sale de `data/justina_map.json: camera`, que no es de esta pista.
