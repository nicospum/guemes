# Relieve y mapa del nivel «Humahuaca» (pista `relieve_mapa`)

Estado: **R1** (corte vertical mínimo), 2 de noviembre de 2026. Dueña: `relieve_mapa`. Lo que esta pista entrega: la clase `HumahuacaTerrain` (`scripts/humahuaca/terrain/`), `data/humahuaca_height.json` y `data/humahuaca_map.json`, el generador `tools/build_humahuaca_terrain.py`, `tests/test_hx_terrain.gd` y este documento. El contrato es `docs/CONTRATO_HUMAHUACA.md` (2.1, 2.2, 3.1); lo que se juega y por qué, `docs/DISENO_HUMAHUACA.md` (3 y 4); cómo se certifica, `docs/QA_NIVEL2.md` (R01 a R06 y el anexo A1).

**Lo primero, la honestidad del dato.** El relieve de base es **dato actual, no restitución del suelo de 1817**: sale de la lámina 03 del material del usuario (SRTM v3 de 90 m, NASA/USGS; 475 nodos de 150 m reconstruidos a ±10 m). Todo lo que el juego le suma para que haya decisiones (el domo de la batería, la plataforma, las quebraditas, el cauce, el micro-relieve, las tapias, las zanjas y las superficies) es **diseño** y `report()` lo rotula como tal.

## 1. Cómo se arma la altura (una sola implementación)

| Paso | Qué pasa | Dónde |
|---|---|---|
| 1. Fuente | Una superficie continua del relieve actual S(E, N) en metros sobre el nivel del mar: bilineal sobre los 475 nodos (como se dibujó la lámina), suavizada con un gaussiano de σ = 15 m (`meta.smooth_m` = 30 m) | `tools/build_humahuaca_terrain.py` |
| 2. Muestreo | **Ventana** de 91 × 66 nodos a 10 m (esquina noroeste en (0, 0)) y **contexto** de 121 × 91 nodos a 30 m (origen (−1350, −1025); el dominio de la lámina), las dos de la misma superficie, en decímetros enteros sobre el cero local de 2 940 m | builder → `data/humahuaca_height.json` |
| 3. Borde | Los nodos del borde de la ventana valen la bilineal del contexto, redondeada (≤ 0,5 dm; V7 pide ≤ 1 dm) | builder |
| 4. Malla de juego | Catmull-Rom **separable** de la ventana a 226 × 164 nodos de 4 m → `height_dem_only` | `terrain_relief.gd` |
| 5. Capas de diseño | Quebraditas, cauce, domo (como residuo), plataforma y micro-relieve, en ese orden → `height_at` | `terrain_relief.gd` |
| 6. Fuera de la ventana | El contexto (bilineal) más la diferencia que trae el borde de la ventana, apagada en 60 m; más allá del contexto la lectura se sujeta al borde | `humahuaca_terrain.gd` |
| 7. Rasterizado | Superficies, muros, portillos, edificios y pesos de ruta, **una sola vez**, desde `humahuaca_level.json` y el mapa | `terrain_raster.gd` |

`height_at(x, z)` es **la** altura: dentro de la ventana, bilineal sobre la malla de 4 m que dibuja la vista; el picking y las rutas leen lo mismo. Ninguna otra clase interpola la grilla (una prueba mira el código).

**Regenerar el relieve** (Git Bash; el csv, el tif y la lámina viven fuera del repo y se pasan con ruta absoluta):

```sh
PREP="<...>/investigacion-nivel2/preparacion"; LAM="<...>/info/2/03_relieve_actual.png"
python -I -X utf8 tools/build_humahuaca_terrain.py --source lamina03 --csv "$PREP/01b_relieve_lamina03_nodos_25x19.csv" --check-lamina "$LAM" --update-map
python -I -X utf8 tools/build_humahuaca_terrain.py --source copernicus --tif <...>/Copernicus_DSM_COG_10_S24_00_W066_00_DEM.tif --out <archivo temporal> --smooth-m 45 --check-lamina "$LAM"
python -I -X utf8 tools/build_humahuaca_terrain.py --measure-river "$LAM"     # imprime la traza del Río Grande medida en la lámina
```

El generador es determinista (sin fechas): correrlo dos veces da el mismo archivo. `--update-map` escribe en el mapa el último `delta_m` del domo; la clase **lo resuelve de nuevo al cargar** con la fuente que tenga (una prueba exige que coincidan a 0,1 m). La tesela Copernicus nunca entra a Git (`*.tif` está en `.gitignore`).

## 2. Capas de diseño (todas `diseno`)

| Capa (`id`) | Tipo | Qué hace | Consecuencia de juego |
|---|---|---|---|
| `cerro_bateria` | `dome` | Domo de núcleo plano de 16 m y flanco de coseno hasta 75 m de radio, centrado en (305, 345). Es un **residuo**: `delta_m` se calcula para que la plataforma quede a 12,0 m sobre la media del anillo de 16 puntos a 135 m (la medida del QA, R05) con la fuente que sea. Hoy `delta_m` = 12,3 m | Ventaja de vista y de tiro de la batería; subir el flanco (hasta 18°) cuesta velocidad (×0,7) |
| `plataforma_bateria` | `platform` | Losa llana de 28 × 18 m en (318, 350), a 33,9 m sobre el cero local (talud de 6 m). La visión de quien está sobre la losa pasa por encima de su propio borde (7.2) | La batería domina la calle del cuartel y la plaza (16,5 m sobre la plaza) |
| `quebradita_norte`, `quebradita_sur` | `gully` | Hondonada de 36 × 8 m (ancho medido a media profundidad), −2,5 m, piso de un nodo de ancho, bancos de 1,2 m a los costados, abierta al oeste. Giradas ±20° para seguir la caída de la ladera (los hitos llevan el mismo `yaw_deg`) | Refugio de caballos: desde el este y el sur no se ve el piso a más de 25–40 m; desde el norte y el oeste (cuesta abajo, extremo abierto) sí |
| `cauce_rio` | `carve` | Talla de −1,6 m a lo largo de la traza del río (fondo llano hasta 0,55 del semiancho, subida suave hasta el semiancho + 12 m) | El cauce queda más bajo que el núcleo; define el agua y el sedimento |
| `micro` | micro-relieve | Cinco ondas planas de semilla fija (1817), torcidas por un desplazamiento suave y con la amplitud modulada: ±0,5 m, onda de 25 m o más, pendiente máxima 5,5°. Se apaga en los 40 m del borde de la ventana y sobre la plataforma | Ninguna regla (no llega a los 8°); da sombras largas al alba y evita el suelo liso |

Faltan, y llegan en R2a: las explanadas del cuartel, la posta y la plaza (`pad`), la barranca del cauce, la terraza del núcleo y el banco de grava.

## 3. Convenciones (confirmadas)

- **Ejes:** `+x` este, `+z` sur, norte = `−z`, origen en la esquina noroeste de la ventana. `x = E + 450`, `z = 325 − N` (la conversión vive en `lamina_to_game` y `game_to_lamina`; nadie la escribe a mano).
- **VP-03 (huella y `yaw_deg`): confirmada.** `yaw_deg` es el rumbo horario visto en el mapa. La huella `{w, d}` es un rectángulo con `w` sobre `+x` y `d` sobre `+z` **antes** de girar; las esquinas son `centro + R(yaw)·(±w/2, ±d/2)` con `R` el giro horario del mapa (`x' = x·cos − z·sin`, `z' = x·sin + z·cos`, que es `Vector2.rotated(yaw)`). `footprint_polygon(id)` (extra de la clase) devuelve esas esquinas y `test_hx_terrain::_test_footprint_convention` las fija con un hito girado 30°. Los edificios que tapan la vista usan ese polígono y el techo es la cota del suelo en su centro más su alto.
- **VP-04: confirmada.** `height_at` es continua y finita en `x ∈ [−1350, 2250]`, `z ∈ [−1050, 1700]` y más allá (se sujeta al borde del contexto); `landmarks({})` trae los 21 hitos con `footprint`, `height_m`, `yaw_deg` y `tag`; `features(kind)` trae los puntos como `{x, z}`; `river()` trae `bed_width_m` y `pts` (con el ancho `w` del lecho en cada punto); `minimap_image(px, {})` mide **exactamente** `px` (probado con 5 tamaños, en la clase real y en el stub).
- **Malla de rutas (`nav_grid`):** 226 × 164 nodos; el nodo (i, j) está en x = 4i, z = 4j y manda en ±2 m; índice `j·nx + i`. Los nodos de la última fila (z = 652 m) quedan sólidos. `weight` = 1 / (velocidad en seco × factor de pendiente) de 1,0 a 2,3; los sólidos valen 1,0. Los sólidos son **idénticos** a los del stub de R1.0 (391 nodos), así que las reglas calibradas contra el stub ven los mismos muros.
- **Una prioridad por superficie** (gana la más alta): reglas del relieve 20–26 < irrigado 50 < patio 55 < camino 60 < sedimento 62 < zanja 65 < agua 70 < muro 90. Cambió respecto del stub en una cosa: el río gana al camino, así que el vado es «agua» (velocidad ×0,5 con o sin lluvia; el stub lo pintaba «camino»).
- **Velocidad:** `speed_factor_at` = superficie (con barro según la lluvia) × pendiente. Pendiente: 1 hasta 8°, después `1 − 0,03·(grados − 8)` con piso 0,6 (`surfaces.slope_penalty`). `mounted` no cambia nada en R1.

## 4. Visión (`los`)

La recta va de la altura de los ojos de A (suelo + `eye_a`) a la de B y la tapan, en este orden: el **terreno** (se lee `height_at` cada 3 m), las **tapias y barricadas** (cota del suelo en el cruce más su alto; un portillo abierto deja pasar) y los **edificios** de los hitos (quien está adentro de uno lo ignora). Cuesta 26 µs en 100–170 m. Es simétrica con ojos a la misma altura.

Dos decisiones que conviene saber:

1. **La losa de la batería ve por encima de su propio borde.** Desde el centro de una losa llana de 28 × 18 m con ojos a 1,6 m no se vería nada a menos de ≈ 140 m (el borde estorba), lo contrario de lo que pide el diseño («quien la tiene ve el núcleo entero»). Para quien está parado sobre la plataforma de diseño (y para quien mira hacia ella) no se cuenta el tramo de la recta que pasa sobre la losa y su talud. El resto del terreno, las tapias y los edificios tapan igual. La prueba lo fija: la calle del cuartel se ve desde la batería y **no** se ve en el DEM sin domo ni plataforma.
2. **La quebradita esconde el piso solo de quien mira cuesta arriba.** El hueco de 2,5 m está en el flanco del domo: desde el este y el sur (hacia la ladera) no se ve el piso a más de 25–40 m, que es lo que pide el diseño («no se ve desde más de 40 m»); desde el norte y el oeste, el terreno de afuera queda más bajo que el piso y se ve. Las reglas ponen su propio umbral de 40 m y 60 m: el terreno solo da la geometría. No se movieron los hitos (posiciones de diseño).

## 5. Mapa chico

`minimap_image(px, opts)`: relieve sombreado (luz del noroeste, exageración 1,3 de la superficie sin micro-relieve), curvas de 20 m trazadas sobre las alturas ya remuestreadas, superficies teñidas con la paleta de la lámina 06 y cauce; norte arriba; sin texto ni unidades; no dibuja tapias ni hitos. `opts`: `shade`, `contours`, `river`, `surfaces`, `exaggeration`. Se cachea por tamaño y opciones y devuelve una copia.

## 6. Qué se midió (R1, lámina 03, todo sobre la clase real)

`qa_relieve.gd` y `qa_relieve.py` (anexo A1 de `QA_NIVEL2.md`) sobre `main` + esta rama:

| Ítem | Umbral | Medido |
|---|---|---|
| R01 ancla, ventana e hitos | 7 relaciones | **pasa** (los 21 hitos, 226 × 164) |
| R02 los 41 puntos | ≥ 37 a ≤ 12 m; ninguno > 20; banda ±8 | **41 de 41** a ≤ 12 m, peor 2,2 m, 41 en banda |
| R03 curvas de 20 m | ventana ≥ 97 %, dominio ≥ 95 % | **99,64 %** y **98,54 %** |
| R04 Río Grande | ≥ 15 filas, medio ≤ 6 m, máx ≤ 12 m | 21 filas, medio **0,7 m**, máx **2,6 m**; entra en (574,5; 0) y sale en (900; 405) |
| R05 prominencia y referencias | 12,0 ± 0,5; batería 14–19 m sobre la plaza; ±10 m | **12,000 m**; **16,51 m**; templo +16,9, cauce +10,5, partida +28,7 |
| R06 continuidad y rutas | salto ≤ 0,10 m; 5 partidas → 3 objetivos y vado | **0,03 m**; un solo componente (9 de 9 puntos) |
| H01 (A-10) | 0 violaciones | **188 entidades, 0 violaciones, 0 sin etiqueta** (con `anchor.id = ancla_iglesia`) |

`tests/test_hx_terrain.gd`: **160 comprobaciones**, 0 fallas, < 1 s, en la clase real (la vista y el stub entran en VP-03 y VP-04). Horneado completo **≈ 56 ms** (lectura 2,4; relieve 4,0; capas 33,8; pendiente 6,8; superficies 5,4; muros 0,3; navegación 1,7; informe 1,2) y ≈ 70 ms desde que se piden los JSON, contra el tope de 300 ms. `height_at`: **2,5 millones de consultas por segundo** (tope pedido: 1 millón). Sanidad por mutación (copias descartables): sin nivelar la plataforma, sin las tapias en la visión, sin el cauce, sin muros sólidos y con `height_at` sin contexto hacen fallar al menos una prueba cada una.

Fuera de la tabla del QA, `report()` informa: 2,1 % de las celdas con pendiente ≥ 8° (R2a pide ≥ 2,5 % y lo alcanzan la barranca, la terraza y el banco) y los tres rasgos verticales de R1 (domo y las dos quebraditas) con pares de puntos cuya visión o velocidad cambia con y sin el rasgo.

## 7. A/B de fuente: lámina 03 contra Copernicus GLO-30

Tesela `Copernicus_DSM_COG_10_S24_00_W066_00_DEM.tif` (39 438 103 B, SHA-256 `1b38c905…301f97f`, verificado), mediana de 5 × 5 píxeles y gaussiano de 45 m (con 30 m da lo mismo a un decimal). Mismo mapa, mismo código; solo cambia `humahuaca_height.json`. La prominencia de la batería se resuelve sola (12,0 m con las dos fuentes; el domo pide 12,3 m con la lámina y 6,6 m con Copernicus).

| Ítem | Lámina 03 | Copernicus (45 m) |
|---|---|---|
| R01 | pasa | pasa |
| R02 (41 puntos) | 41 de 41; peor 2,2 m | 40 de 41 a ≤ 12 m; peor 14,3 m; 41 en banda; **pasa** |
| R03 (curvas) | 99,64 % / 98,54 % | 93,27 % / 84,94 %: **pasa** con el umbral de otra fuente (75 / 70) |
| R04 (río) | pasa | pasa |
| R05 referencias | templo +16,9; cauce +10,5; partida +28,7; batería 16,5 m sobre la plaza | templo **+7,9** (pide +17 ± 3); cauce **+0,2** (pide +12 ± 3); partida +28,9; batería **25,6 m** sobre la plaza (pide 14–19): **falla** |
| R06 | pasa | pasa |

**Lectura.** La tesela real discrepa de la lámina en el núcleo y el cauce por 9 a 12 m, que es la incertidumbre de la lámina (±10 m): las cotas de referencia del QA (+17, +12, +27) salen de la lámina, así que ningún DEM real las cumple con ±3 m. Una mezcla (lámina de baja frecuencia más el detalle local de Copernicus) se midió en un experimento descartable: R02 y R03 pasan, pero templo y cauce siguen a 4 a 7 m de lo pedido. Por la regla de la ADDENDA A-02 («si alguno falla, el relieve se queda con la lámina y se anota acá»), **R1 sigue con la lámina y `--source copernicus` queda listo**. Para pasar a Copernicus en R2a hace falta una enmienda del QA que fije las alturas de referencia de R05 sobre la fuente real (o un addendum que acepte el híbrido); es una decisión del integrador (pedido C1 de abajo). La prueba A/B de `test_hx_terrain` ya corre con una fuente sintética (+4 m y ondulación de ±0,8 m): la prominencia sigue en 12,0 ± 0,5 m y el signo del gradiente se conserva; la parte «los tres objetivos a ≤ 1 m entre sí» espera a las explanadas de R2a.

## 8. Límites honestos

- La lámina resuelve 150 m: dentro de la ventana el relieve base sube 25 m en 900 m. Todo lo que se ve como cerro, plataforma, hondonada o cauce es diseño; la forma del relieve de 1817 se desconoce.
- Las tapias, zanjas, caminos y parcelas vienen de `humahuaca_level.json` (de `reglas_historia`) y se rasterizan a 4 m: una zanja de 1,6 m de ancho es un renglón de nodos, no un hueco en la malla (la vista dibuja sus cintas).
- El camino cubierto solo pinta su suelo (sus tapias de 1,8 m no son sólidas) y las manzanas no son sólidas: simplificaciones heredadas del stub.
- Las quebraditas no esconden el piso de quien mira desde el norte o el oeste (4, punto 2).
- El contexto es de 30 m: el cerro occidental llega a ≈ 3 135 m, pero sus detalles no existen.
- La herramienta `scripts/humahuaca/terrain/terrain_preview.gd` saca capturas del relieve sin las otras capas (la vista real es de `visual`): `godot --path . --resolution 1280x720 --script res://scripts/humahuaca/terrain/terrain_preview.gd -- --out=<carpeta> --views=acceso_so,desde_bateria,general`.

## 9. Pedidos al integrador (CONTRATO 6.1)

| Id | Pedido | Motivo | Prueba de aceptación |
|---|---|---|---|
| C1 | Decidir sobre Copernicus: (a) se queda la lámina (A-02, ítem R05 falla con la tesela); (b) enmienda del QA que fije las referencias de R05 sobre la fuente real; (c) addendum del híbrido | Sección 7 | La decisión escrita en `ADDENDA.md`; si es (b) o (c), `meta.source` cambia y V18 exige el aviso de Copernicus |
| A1 | Addendum de VP-04 y VP-03: quedan **confirmadas** tal como las pidió `visual` (esta sección 3) | Cerrar los pedidos de `VISUAL.md` | Fila nueva en `ADDENDA.md`; `test_hx_terrain::_test_footprint_convention` y `_test_vp04_contracts` |
| V1 | Encender V6, V12, V18 y V21 en `test_hx_data` (B-013) | El mapa ya trae hitos, río y relieve con sus etiquetas: V6 (21 hitos dentro de la ventana, objetivos separados 101, 175 y 277 m), V12 (`relief.height_file` existe), V18 (`CREDITOS_RELIEVE.md` trae «OpenStreetMap» y «ODbL» y el texto de Copernicus) y V21 (los `r_m` y `radius_m` del mapa son geometría) tienen con qué verificarse | `test_hx_data --ronda=r1` los lista como activas y pasa |

## 10. Extras de la clase (no cambian ninguna firma de 3.1)

- `new(fuentes := {})`: sin argumentos arma el terreno del juego; con `{"map": ..., "height": ..., "level": ...}` (cada valor, un Dictionary ya leído o la ruta de un JSON) arma otro: así la prueba A/B carga una fuente nueva desde un archivo temporal. También `from_data(mapa, relieve, nivel)` y `from_paths(ruta_mapa, ruta_relieve, ruta_nivel)`. Sin datos de relieve el terreno se arma **plano a +17 m** y `report().source` dice `ausente` (no se cae).
- `footprint_polygon(id)`: las esquinas de la huella de un hito (VP-03).
- `los_on(alturas, a, b, ...)` y `heights_without_dome()`: la visión sobre una malla alternativa (la de 4 m sin domo ni plataforma) para medir qué cambia cada rasgo de diseño.
- `river().pts[*].w`: el ancho del lecho en cada punto (25 a 40 m); `river().fords`: los dos vados (`vado_norte` y `vado_este`).
- `report()`: además de las claves del contrato trae `labels` (qué es dato actual y qué es diseño, con el texto «Dato actual, no restitución del suelo de 1817…»), `dome_delta_m` y `height_file_ok`.
