# Casas del territorio · visual/r1 F5, parte B (kit de edificios)

Estado: **assets solamente** (9-nov-2026, rama `visual/r1`, sin commit). Ningún script del juego, prueba ni JSON de datos los usa todavía: la integración es el paso siguiente (tabla «De lo viejo a lo nuevo»). Decisión del usuario: **no hay casas europeas**; solo edificios del territorio (adobe, torta, paja, pirca; teja y ladrillo blanqueado donde corresponde: ciudades del Norte y Buenos Aires).

- Herramienta: `tools/f5_casas.py` (Blender 4.4.3 en línea de comandos; obra propia, sin material de terceros).
- Salidas: `assets/models/casa_*.glb` (26 modelos), `casa_*_lod.glb` (23 LOD; las tapias no llevan) y `assets/models/f5_casas_manifest.json` (triángulos, superficies, materiales, cotas Godot, puertas, L* de muros y techos, sha256, etiqueta y nota).
- Vistas previas: `../qa-visual-r1/f5_casas_preview/` (cada modelo con una figura de 1,70 m y el caballo criollo `caballo_criollo_zaino_lod.glb`; tres pueblos de prueba a 95 m y a 40 m; el pueblo de la quebrada de noche).

## Etiquetas

Las del proyecto (CLAUDE.md): **documentado** (lo dice una fuente), **razonado** (inferencia desde una fuente; ◇ en el nivel II), **discutido**, **sin datos**, **diseño** (▲). En la Justina «razonado» equivale a la «Reconstrucción» de `PROCEDENCIA_VISUAL.md`. **Ningún edificio del kit es un edificio documentado**: son tipos, y sus medidas, vanos y detalles son diseño. Lo que una fuente respalda es el **tipo constructivo** (material, techo, partido), y eso es lo que llevan las etiquetas de abajo.

## Fuentes de esta parte (consultadas el 9-nov-2026)

Solo se citan; no se incorporó ninguna imagen ni texto al juego. Quedan sin número S: si `reglas_historia` las quiere en `FUENTES.md`, que las numere.

| Clave | Fuente | Qué se tomó | Cotejo |
|---|---|---|---|
| PVR | Olga Paterlini, Susana Villavicencio y María Alejandra Rega (Universidad Nacional de Tucumán), «Arquitectura popular y "modernidad apropiada" en la Quebrada de Humahuaca, Argentina. Paisaje Cultural de la Humanidad», pp. 366–373. PDF: https://upo.es/area-historia-arte/wp-content/uploads/2019/04/Olga_Paterlini_Susana_Villavicencio_Maria_Alejandra_Rega__Arquitectura_popular_y_modernidad_apropiada_en_la_Quebrada_de_Humahuaca_Argentina._Paisaje_Cultural_de_la_Humanidad.pdf (sha256 del PDF bajado `6a619930dac379e4ca3e260b5990fa7782258a0ff60536723f76035b5f25e447`; no se guarda en el repo) | p. 369–370: «Con la tierra se realizan tapias o tapiales mampuestos de adobes, lo más frecuente en la constitución de los muros; […] para cubiertas una torta de barro»; «La piedra se usa en los cimientos»; maderas de álamo y algarrobo para cubiertas y «columnas de galerías», queñoa en dinteles, «las cañas y la madera de cardón» en el cielorraso bajo la torta; «el material cerámico (ladrillos, tejas, tejuelas, baldosas) fue incorporado por los colonizadores y sólo el ladrillo y la baldosa constituyen elementos de la arquitectura popular». p. 368: iglesia de Purmamarca «muros de adobe y una peculiar carpintería de cardón»; «casas encaladas […] con sus adobes o sus techos de torta de barro bien visibles». p. 369: la iglesia «exento respecto de la trama, con espacios libres en sus lados para atrio y cementerio; el conjunto se cierra con un muro bajo, a la manera de una "pirca"»; «Las viviendas, tanto urbanas como rurales, responden a la composición a patios» | Leído en el texto del PDF (extracción propia). **Es arquitectura popular actual descripta por arquitectas, no un documento de 1817**: proyectarla a 1817 es inferencia (razonado) |
| CNM-AR | Comisión Nacional de Monumentos, ficha «Museo Casa de Arias Rengel» (Salta, Florida 20), https://www.argentina.gob.ar/node/401474 | Casa «construida a mediados del XVIII»; «Gruesos muros de adobe»; «techos con cabriadas y tirantes de madera, tejuelas y tejas coloniales»; tres patios | Leído en la página (resumen de la herramienta de lectura, no la declaratoria) |
| S24 | Vidal, vistas de Buenos Aires c. 1817–20 (ya en `FUENTES.md` y `PROCEDENCIA_VISUAL.md`) | Techos de teja a dos aguas, azoteas, tapias revocadas, ranchos de paja en las afueras | Ya cotejado por la pista de historia; posterior en ~11 años a 1806 |
| S52 | Informe de Arias del 31-I-1817 (ya en `FUENTES.md`) | Existencia de la capilla de Santa Bárbara (derribada) | Solo como prueba de que había capillas en el lugar; no da su forma |
| UQ | Iglesia de Uquía: Monumento Histórico Nacional (decreto 95.687 de 1941), fines del s. XVII; «gruesos muros de adobe», «techo volado», torre con cupulín (páginas de Presidencia de la Nación y prensa jujeña halladas en búsqueda; https://www.argentina.gob.ar/node/400482) | Torre con cupulín como rasgo posible de las iglesias de la quebrada | **Sin cotejar**: resumen de búsqueda; dos páginas discrepan sobre si la torre está separada. No se usa más que como «posible» |

Lo que **no** se encontró y queda sin datos: el aspecto de las casas de Humahuaca en marzo de 1817 (no hay plano ni vista de época en el proyecto), el techo exacto de la iglesia de Humahuaca y de las capillas de 1817 (torta o paja), la forma de la posta de Hornillos o de otras postas de la quebrada en 1817, y la planta de una pulpería del Valle de Lerma.

## Base histórica por tipo

| Tipo (archivos) | Qué es | Base | Etiqueta |
|---|---|---|---|
| Rancho de paja (`casa_rancho_a`, `_b`) | Adobe sin revocar o con revoque de barro, techo de paja a dos aguas con caballete de barro; `_b` con ramada de horcones | Valle de Lerma y campaña: paja como cubierta rural es inferencia (no hay fuente de 1816 en el proyecto). En la Justina, Vidal (S24) muestra ranchos de paja en las afueras | razonado (Justina, S24); diseño (Valle de Lerma) |
| Rancho de torta (`casa_rancho_c`) | Una pieza de adobe con techo de torta a un agua, rollizos, poyo junto a la puerta | PVR: muros de adobe y cubierta de torta de barro; piedra en los cimientos | razonado |
| Casa de torta (`casa_torta_a`, `_b`) | Mejora de `hx_casa_adobe`: cimiento de piedra, muros de adobe (o encalados al frente en `_b`), techo de torta sobre cañizo y rollizos cayendo al frente, pretil al fondo y a los costados, gárgolas de madera; `_b` en dos cuerpos con leña y escalera de palo para subir al techo | PVR (adobe, torta, cañas, piedra en cimientos, casas encaladas); pretil, gárgolas, escalera y leña son diseño | razonado (tipo) · diseño (detalles) |
| Casa con galería de horcones (`casa_galeria_a`, `_b`) | `_a`: torta y galería de horcones con cañizo (quebrada); `_b`: encalada con teja y galería (pueblos del Valle de Lerma y Jujuy) | PVR: álamo y algarrobo en «columnas de galerías»; la horqueta del horcón es diseño. `_b`: teja documentada en una casa de Salta del s. XVIII (CNM-AR); llevarla a un pueblo del valle es inferencia | razonado |
| Casa con patio y tapia (`casa_patio_a`, `_b`) | `_a`: cuartos en L con torta, patio cerrado por tapia con portón y horno de barro (quebrada). `_b`: casa de ciudad (Salta, Jujuy) con frente encalado y zaguán, ala con corredor, techo de teja, tapias encaladas y aljibe | PVR: «composición a patios», urbana y rural. CNM-AR: casa salteña del s. XVIII de adobe, con tejas y tres patios. Horno, aljibe, rejas y corredor: diseño | razonado (partido) · diseño (detalles) |
| Capilla con espadaña (`casa_capilla_a`, `_b`) | Nave única de adobe encalado, techo de torta a dos aguas, contrafuertes, portada de arco de medio punto, espadaña de dos campanas y cruz; `_b` con atrio cerrado por pirca, portada de atrio y cruz | PVR: iglesia de adobe con atrio cerrado por un muro bajo de pirca; arco de medio punto como rasgo tradicional de la zona. Espadaña y techo de torta en las capillas de 1817: inferencia, sin fuente propia. **No es la iglesia de Humahuaca** (esa la arma `humahuaca_gen.gd`, sin torres) | razonado (atrio, adobe) · diseño (espadaña, medidas) |
| Iglesia con torre (`casa_capilla_c`) | Nave encalada con torre a un costado del frente, campanario abierto y cupulín, techo de teja | UQ (sin cotejar) para la torre con cupulín; teja como en CNM-AR. Silueta genérica para pueblos del Norte y, de lejos, para la ciudad de Buenos Aires (Vidal muestra torres, S24) | diseño |
| Corrales de pirca (`casa_corral_pirca_a` redondo, `_b` rectangular con brete) | Piedra sin mortero en hiladas, con talud y piedras sueltas encima; tranquera de palos | PVR: pirca de piedra y barro en el cierre del atrio y pircas altas; el corral de pirca como uso ganadero es inferencia | razonado |
| Corral de palo a pique (`casa_corral_palos_c`) | Palos hincados juntos, tranquera | Para la llanura de Buenos Aires: sin fuente en el proyecto | diseño |
| Tapias y pirca en módulos de 4 m (`casa_tapia_adobe_a`, `casa_tapia_cal_b`, `casa_tapia_pirca_c`) | Tapia de adobe con cumbrera de barro y pie de piedra; tapia encalada con cumbrera de teja (ciudades); pirca | PVR (tapias, pirca); S24 (tapias revocadas en Buenos Aires); S46 (el parte de Arias menciona «tapial», ya en `PROCEDENCIA.md`) | razonado |
| Pulpería (`casa_pulperia_a` paja, `_b` torta) | Casa de adobe con despacho enrejado (reja de madera), galería o ramada de horcones, palenque y banco | Sin fuente en el proyecto sobre una pulpería concreta del Norte en 1816–17; la reja del despacho es un rasgo tradicional, no cotejado | diseño |
| Casa de posta (`casa_posta_a` torta, `_b` paja) | Cuerpo largo de cuartos con galería corrida de horcones, palenque (y bebedero en `_b`) | Postas del camino real existían (la de Yatasto es monumento histórico; página turística sin cotejar habla de «galería con columnas de madera»). La forma es diseño | diseño |
| Casa de Buenos Aires (`casa_ba_a` teja, `_b` azotea) | Ladrillo revocado y blanqueado, rejas de hierro, postigos; `_a` techo de teja a dos aguas, `_b` azotea con pretil, cornisa y gárgolas | S24 (Vidal: teja a dos aguas, azoteas, tapias revocadas), ya usado en `PROCEDENCIA_VISUAL.md` como «Reconstrucción»; ladrillo bajo el revoque: inferencia | razonado |
| Quinta (`casa_quinta_a`, `_b`) | `_a`: casa encalada de teja con corredor de pilares de madera; `_b`: casa de teja con tapia baja alrededor y pozo de balde | S24 y la decisión ya tomada en `world_view.gd` (quintas con tapia sobre la meseta del Retiro, «Reconstrucción estética»); corredor y pozo son diseño | razonado (quinta con tapia) · diseño (corredor, pozo) |

**Lo que se evitó a propósito:** teja en la quebrada (PVR: la teja no es de la arquitectura popular de la quebrada; ninguna casa de la quebrada del kit la lleva), casas europeas de dos plantas, balcones de hierro forjado, vidrios en las ventanas, banderas o insignias; el rojo: la teja es pardo-terracota apagada (#85634E, saturación 0,41) porque en el Norte el rojo es solo del enemigo.

## Color y contraste (B-062 c)

Paleta en `tools/f5_casas.py: HEX` (diseño). Contra el suelo seco de la lámina 06 (#B99A72, L* 65,5) el kit separa en las dos direcciones: techos de torta y paja oscuros (L* de albedo con oclusión 39–46, ΔL* −19 a −27), teja oscura (ΔL* −24 a −33), muros encalados claros (L* 75–82, ΔL* +10 a +16) y adobe sin revocar más oscuro y cálido que el adobe #C4AA82 de la lámina (L* 45–48, ΔL* −18 a −20). Los valores de cada modelo están en el manifiesto (`lstar_albedo`). Son L* de albedo, no del cuadro: la medida que manda es la de `hx_qa_tour.gd` (V06) con la luz del juego, que **no se corrió** (no hay integración todavía). La vista `pueblo_quebrada_plano_oscuro.png` (EEVEE, luna fría) muestra los techos leyéndose contra el suelo.

## De lo viejo a lo nuevo (para el paso de integración)

| Nivel · lugar del código | Hoy | Propuesta |
|---|---|---|
| II · `data/humahuaca_visual.json: models.casa_adobe` (lo lee `humahuaca_gfx.gd: model()`; lo usa `humahuaca_buildings.gd: _add_house`, casas del núcleo con `w < 9,5`) | `hx_casa_adobe.glb` | `casa_torta_a.glb` (6,1 × 5,0 m; frente −Z). Variedad: `casa_torta_b`, `casa_rancho_c`, `casa_galeria_a` (hace falta una clave por variante o una lista; hoy hay una sola clave) |
| II · `models.casa_adobe_grande` (`_add_house` con `w ≥ 9,5`; `_build_posta`: casa de posta contra el muro norte del patio, `model_fit(…, house_w, 6.0)`) | `hx_casa_adobe_grande.glb` | Núcleo: `casa_torta_b` o `casa_patio_a`. Posta: `casa_posta_a` (cuarto largo con galería; el palenque agranda la caja: ver riesgos) |
| II · `models.capilla` (`_build_landmark` con `props.por_id.<id>.model`, ajuste «uniforme», lumbre en la portada) | `hx_capilla.glb` (≤ 8 m) | `casa_capilla_a.glb` (sin atrio, ≈ 7,9 m con la cruz). `casa_capilla_b` si el hito admite el atrio (18,6 m de largo) |
| II · `models.tapia` (`build_features`: un módulo de 4 m estirado por tramo) | `hx_tapia.glb` | `casa_tapia_adobe_a.glb` (4,04 × 2,2 × 0,66 m, como el viejo) |
| II · `models.pirca` | `hx_pirca.glb` | `casa_tapia_pirca_c.glb` |
| II · `models.corral` (constructor `corral` de `_build_landmark`) | `hx_corral.glb` | `casa_corral_pirca_a.glb` (10,8 m, igual que el viejo) o `_b` |
| III · `world_view.gd: _north()` → `_house(…, 1.15, 1.45, j == 0)` (4 casas por sector; Salta suma una iglesia y una torre cilíndrica procedural) | `house_colonial.glb`, `church_colonial.glb` (escalados a 1,15 m: maqueta) | Salta y Jujuy: `casa_patio_b`, `casa_galeria_b`, `casa_capilla_c`; Valle de Lerma, Chicoana, Rosario de la Frontera, Orán: `casa_rancho_a/_b`, `casa_galeria_b`, `casa_pulperia_a`, `casa_posta_b`, `casa_capilla_a`; Quebrada: `casa_torta_a/_b`, `casa_capilla_b`, `casa_corral_pirca_a`. `_house` supone una huella de 5,7 × 6,0 m (`sx = w/5.7; sz = d/6.0`): usar la caja de cada GLB del manifiesto |
| I · `world_view.gd: _coast()` (obstáculos y 10 casas de la ribera, una de cada tres con `church_colonial`) | `house_colonial`, `church_colonial` | Ribera: `casa_rancho_a/_b` y `casa_ba_a`; **ninguna iglesia en la ribera** (una de cada tres casas es hoy una iglesia: conviene sacarla) |
| I · `world_view.gd: _house_at()` (quintas y ciudad: azotea procedural, rancho procedural de paja, `house_colonial` desde `hv ≥ 0,80`) y `_meseta_town_j()` | `house_colonial` + cajas procedurales | `casa_ba_b` (azotea), `casa_ba_a` (teja), `casa_rancho_a` (paja), `casa_quinta_a/_b` en la meseta; tapias de patio con `casa_tapia_cal_b` |
| I · `_scenery_j()` (torres de iglesia en la ciudad, hasta 4 + 7) | `church_colonial` | `casa_capilla_c` (torre y cupulín, teja) a escala 1 |

Todos los GLB nuevos usan las mismas convenciones que los que reemplazan (metros, frente −Z, origen en el suelo y en el centro de la caja, color por vértice con el ancla primero): los dos cargadores (`humahuaca_gfx.gd: model()` y `world_view.gd: _glb_parts()`) los leen sin cambios (comprobado: los 49 GLB se importan y cargan en Godot 4.7.2 con color por vértice en todas las superficies).

## Riesgos y pendientes

1. **La caja incluye galerías, palenques, cántaros y atrios.** `model_fit` estira el modelo a la huella por su caja: una casa con galería o palenque queda con el cuerpo más chico que la huella del diseño de nivel. Para el núcleo de Humahuaca conviene `casa_torta_a` (caja = cuerpo + 0,5 m de alero y cántaros) o pasar en el manifiesto una «huella del cuerpo» si hace falta.
2. **Puertas.** La lumbre de las puertas del núcleo (`_add_house`) supone la puerta de la casa procedural; las puertas reales de cada GLB están en el manifiesto (`doors_godot`, coordenadas Godot sin escalar).
3. **Triángulos.** La mayoría queda entre 0,7 y 3,5 mil; pasan de 4 mil `casa_capilla_b` (4,3 mil, por la pirca del atrio), `casa_capilla_c` (4,7 mil, torre y teja) y `casa_patio_b` (5,3 mil: dos alas, tapias y aljibe, ≈ dos casas). Los LOD quedan en 0,23–1,6 mil. No se midieron FPS.
4. **Contraste medido en el cuadro: pendiente** (V06 de `hx_qa_tour.gd` tras la integración). Los techos encalados no existen; si la cámara de juego ve sobre todo techos, el aporte al ΔL* lo dan la torta y la teja oscuras; los muros encalados suman en el alba.
5. **Teja de lejos.** Con luz rasante la teja pardo-terracota puede leerse rojiza; si el QA la confunde con el rojo del enemigo en el Norte, bajar su saturación en `HEX`.
6. **La paja de las ramadas** es una losa con franjas de color: de cerca (≤ 20 m) se ve lisa.
7. **Fuentes.** PVR describe la arquitectura popular actual; CNM-AR es una ficha de una sola casa de Salta; UQ y la página de Yatasto no se cotejaron. Nada de esto prueba el aspecto de un edificio de 1806 o 1817: por eso todo el kit es razonado o diseño.

## Integración en el nivel II (9-nov-2026, visual/r1 F5, sin commit)

Lo que hace hoy el juego con el kit en Humahuaca (`data/humahuaca_visual.json: models`, `scripts/humahuaca/view/humahuaca_buildings.gd`). Las etiquetas de arriba no cambian: los tipos son razonados y las medidas, el reparto y las puertas con lumbre son diseño.

| Clave | Modelo | Dónde |
|---|---|---|
| `casa_adobe` | `casa_torta_a` | núcleo, lotes de menos de 9,5 m de frente |
| `casa_rancho`, `casa_galeria` | `casa_rancho_c`, `casa_galeria_a` | núcleo (variantes de los lotes chicos) |
| `casa_adobe_grande` | `casa_torta_b` | núcleo (lotes chicos y grandes) |
| `casa_patio` | `casa_patio_a` | núcleo, lotes de 9,5 m o más |
| `casa_posta` | `casa_posta_a` | casa de posta contra el muro norte del patio (`_build_posta`) |
| `capilla` | `casa_capilla_a` | el templo (`_build_landmark`, ajuste uniforme; la portada con lumbre va en la puerta del manifiesto) |
| `tapia` | `casa_tapia_adobe_a` | módulos de 4 m de las tapias del terreno |
| `pirca` | `casa_tapia_pirca_c` | anotada; no hay pirca en el nivel todavía |
| `corral` | `casa_corral_pirca_a` | corral de la posta, con su piso de tierra pisoteada |

- **Riesgo 1 (la caja incluye galerías, palenques y tapias de patio): resuelto con dos reglas.** (a) Cada lote del núcleo elige, entre las variantes de `models.nucleo`, la que menos se deforma (con la posición como desempate) y `house_fit` no la estira más de 1,2 veces en un sentido que en el otro, sin pasarse del lote; el frente queda sobre la calle. (b) La casa de posta va sin deformar, a la escala que le da el largo de su huella (0,9 a 1,15), con el fondo contra el muro norte: antes se la aplastaba a 6 m de fondo.
- **Riesgo 2 (puertas):** la lumbre del núcleo, de la posta y de la capilla va en la puerta del manifiesto (`models.nucleo.puertas`), ya no en la de la casa procedural.
- **Riesgo 4 (contraste medido):** V06 con `hx_qa_tour.gd --no-bot` a 1280 × 720 y `qa_imagen.py legible`: edificio–suelo 9,9 → 12,2 de noche y 9,3 → 12,9 al alba (piso 12; de noche varió de 12,1 a 12,6 entre corridas). Los tres pares son el polvorín, el parque de artillería y el corral; el kit sumó las tapias y la casa de posta más oscuras, y además el piso del patio de la posta pasó a un poco más claro (diseño) y el corral recuperó su piso de tierra. El corral de pirca sigue casi sin contraste en su par (≈ 2): la pirca sola no se lee desde 470 m.
- Los `hx_*.glb` de la pista P6 quedan en la carpeta como respaldo (cambiar la ruta en `models` los vuelve a poner); si falta un archivo del kit, la vista usa el generador procedural.

## Integración en los niveles I y III (commit 8672a6a)

- **Nivel I (Justina, 1806):** meseta con `casa_ba_b`, ranchos, `casa_quinta_a` y `casa_ba_a`, a escala real (±4 %), casas a 12 m mirando a la calle y tapias de patio `casa_tapia_cal_b`; quintas del camino de Las Conchas con ranchos y quintas; ciudad con mayoría de `casa_ba_a` (la azotea de `casa_ba_b` se confunde con el suelo vista de arriba); torres de la ciudad con `casa_capilla_c`. Ribera al pie de la barranca: 9 edificios sin iglesia (ranchos 18 % más oscuros para separarlos de la arena, uno de cada cuatro `casa_ba_a`). **Etiqueta:** que hubiera ranchos en la ribera en 1806 es una reconstrucción estética (razonado/diseño); ningún edificio es documentado.
- **Nivel III (Sostener el norte):** el mapa es esquemático (Salta y Lerma a 7,3 m), así que los pueblos van en **miniatura a escala uniforme 0,24** (sin deformar proporciones); las tropas siguen a 0,8 porque son la marca del juego. Salta y Jujuy: `casa_capilla_c`, `casa_patio_b`, `casa_galeria_b`; Lerma, Chicoana, Rosario y Orán: ranchos, pulpería, posta, `casa_galeria_b`, `casa_capilla_a`; Quebrada y Humahuaca: casas de torta, `casa_capilla_b` o `_a`, corral de pirca. Los campamentos evitan todos los edificios.
- **Pendiente:** Chicoana y Orán (adobe oscuro, sin encalado) cuestan distinguirlos a 60 m; teja algo anaranjada con luz cálida en Justina; los ranchos de la ribera no son obstáculo en las reglas.
