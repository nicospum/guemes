# F5 parte C · terreno: texturas PBR y relieve real (assets e investigación, sin integrar)

Estado: **9-nov-2026, rama `visual/r1`, sin commit.** Pista visual. Este paso solo agrega archivos nuevos en `assets/terrain/`, dos herramientas (`tools/f5_terreno_texturas.py`, `tools/f5_terreno_relieve.py`), esta nota y una sección en `docs/CREDITOS.md`. **No se tocó** ningún script del juego, shader, prueba ni JSON de `data/`; `data/humahuaca_height.json` sigue igual. Vistas previas en `../qa-visual-r1/f5_terreno_preview/` (fuera del repo).

## 1. Cómo está hecho el suelo hoy (punto de partida)

| Escenario | Altura | Color |
|---|---|---|
| Humahuaca | `HumahuacaTerrain.height_at` (scripts/humahuaca/terrain): ventana 91 × 66 a 10 m y contexto 121 × 91 a 30 m de `data/humahuaca_height.json`, **ya Copernicus GLO-30** desde el 2-nov (`meta.source = copernicus_glo30`, RELIEVE_COPERNICUS.md), más capas de diseño (domo, plataforma, cauce, micro-relieve). Más allá del contexto, el **anillo del horizonte** hasta ±8 km es procedural (`humahuaca_gfx.gd::ring_height`) | `shaders/humahuaca_terrain.gdshader`: dos texturas de pesos (suelo, sedimento, piedra, churqui, irrigada, agua, camino, zanja) por colores de la paleta y tres escalas de ruido. Sin texturas fotográficas: de cerca se ve una superficie parda lisa con manchas (captura `despues_f4_hx/f4_24_cerca_45m.png`) |
| Norte | `world_view.gd::terrain_height`: ruido `FastNoiseLite` (semilla 1817) + rampa por |x| y aplanado alrededor de cada sector; malla 110 × 90 (paso 1,2) | `assets/terrain.gdshader` con `northern = true`: rampa por altura y pendiente, curvas de nivel y borde a tinta |
| Justina | `game_rules.gd::terrain_height_at` (barranca, playa, bajos; **es regla**: marea y vados) | `shaders/terrain_justina_r4.gdshader` |

## 2. Texturas (Poly Haven, CC0)

`tools/f5_terreno_texturas.py --download-dir <vacía, fuera del repo>` baja de la API pública (`api.polyhaven.com/files/<id>`) los mapas a 1K, verifica el MD5 que publica la API, anota el SHA-256 del original y los re-codifica a JPG sin metadatos (`albedo` sRGB, `normal` OpenGL, `orm` = R oclusión / G rugosidad / B metal, que es el orden ORM de Godot, y `height` gris relativo). Manifiesto: `assets/terrain/terrain_textures_manifest.json` (URL, autores, MD5/SHA-256 de origen y de destino). `--verify` recalcula los hashes; `--preview` dibuja la hoja `10_texturas_iluminadas.png`.

| Lugar | id de juego | Poly Haven | Papel |
|---|---|---|---|
| humahuaca | `hx_suelo_grava` | gravelly_sand | suelo seco base (Namaqualand, semidesierto) |
| humahuaca | `hx_ladera_grava` | rock_ground_02 | ladera y conos: pedregoso gris pardo con plantas ralas |
| humahuaca | `hx_cauce_cantos` | dry_river_pebbles | lecho seco del Río Grande |
| humahuaca | `hx_roca_ladera` | cliff_side | barrancas: roca sedimentaria estratificada (Namaqualand) |
| humahuaca | `hx_pasto_seco` | grass_ground | churqui / pasto seco y sus claros |
| humahuaca | `hx_andenes_tierra` | farm_soil | rastrojos y andenes irrigados |
| norte | `norte_pasto` | sparse_grass | pasto del Valle de Lerma |
| norte | `norte_camino_pasto` | grass_path_2 | huella rural |
| norte | `norte_camino_tierra` | brown_mud_02 | camino de tierra |
| justina | `jn_arena_humeda` | damp_sand | playa de la ribera |
| justina | `jn_barro` | brown_mud_03 | barro (pisadas, sin huellas de ruedas) |
| justina | `jn_pasto_ribera` | leafy_grass | pasto de barranca y bajo |

48 archivos, **16,2 MB** en total (1K; `--res 2k` existe pero cuadruplica). Etiqueta `razonado`: son fotos de otros lugares; se toma el material (grano, piedra, aridez), no una vista de Humahuaca, Salta o el Retiro. Se descartaron `rock_face` (mancha rojiza sin estratos) y `sandy_gravel_02` (igual al suelo base); se evitaron texturas con huellas de neumáticos (`muddy_tracks`, `aerial_mud_1`).

Lo que muestra la hoja iluminada: `cliff_side` y `grass_path_2` **repiten a la vista** a 8 × 8 (estratos y matas en grilla) y `cliff_side` es más anaranjada que la paleta; el resto aguanta la repetición. Ver riesgos (5).

## 3. Relieve real (B-028)

`tools/f5_terreno_relieve.py --tiles-dir <fuera del repo> --download --humahuaca --norte --preview-dir <...>` es reproducible y determinista. Teselas del bucket público de AWS (`copernicus-dem-30m` / `copernicus-dem-90m`, release 2021) por HTTPS; las teselas no entran a Git. Licencia cotejada **literal** en el PDF oficial (sección 4).

### 3.1 Humahuaca: horizonte real (±9 km) y silueta lejana (±30 km)

- **`assets/terrain/humahuaca/hx_horizonte_copernicus.json`** (442 KB): grilla 301 × 301 a **60 m**, origen (−8550, −8675), mismo marco (`x = E + 450`, `z = 325 − N`), mismas unidades (dm sobre 2 940 m) y **misma receta** que el contexto (tesela GLO-30 S24 W066, la de A-02, verificada por SHA-256; mediana 5 × 5 px y gaussiano de 45 m; spline cúbica). Control de empalme: re-muestreada en los 11 011 nodos del `context` del juego da **los mismos decímetros en el 100 % de los nodos** (diferencia máxima 0 dm). Cotas 2 842 a 3 996 m. También en PNG gris de 16 bits (`cota = 2500 + valor/10`).
- **`hx_lejano_copernicus90.json`** (309 KB): 241 × 241 a **250 m**, ±30 km, de GLO-90 (S23 y S24 W066), cotas 2 516 a 5 111 m: Hornocal y la sierra de Aguilar, que son la silueta real que se ve desde el pueblo y quedan **fuera** de los ±8 km del anillo actual.

**Contra el anillo procedural** (subida media desde el borde del contexto; el procedural con sus ruidos en el valor medio):

| Lado | a 1 km | a 2 km | a 4 km | a 6,8 km |
|---|---|---|---|---|
| oeste, DEM | +71 m | +134 m | +247 m | +596 m |
| este, DEM | +36 m | +60 m | +116 m | +245 m |
| oeste/este, procedural | +503 m | +915 m | +915 m | +915 m |
| norte, DEM / procedural | +16 / +39 m | +105 / +118 m | +275 / +244 m | +246 / +275 m |
| sur, DEM / procedural | −3 / +39 m | +1 / +118 m | −38 / +244 m | −23 / +275 m |

Lectura: el anillo actual pone **paredes de 900 m a 2 km** a los dos lados; el terreno real es un valle ancho, con lomas de 60 a 250 m hasta 4 km y las sierras grandes **después de los 10 km** (perfil `21_hx_perfil_oeste_este.png`). Hacia el sur el valle sigue llano (el procedural lo hace subir). Si se integra, el horizonte se ve más abierto y la silueta pasa a venir del lejano. La comparación con la foto de 1923 (CREDITOS_VISUAL.md, «relación» ladera / cordillera) es una decisión de arte, no se resolvió acá.

### 3.2 Norte: relieve real sobre un mapa esquemático

- **`assets/terrain/norte/norte_relieve_copernicus90.json`** (188 KB): 221 × 181, la grilla del mapa (x −55..55, z −45..45, paso 0,5), **metros** reales. Mosaico de 42 teselas GLO-90 (S21–S27 × W063–W068, 196,7 MB, fuera del repo), bloques de 8 px y gaussiano σ ≈ 1,2 km. Cotas 188 a 5 809 m; sectores: Humahuaca 2 987, Tilcara 2 579, Jujuy 1 277, Salta 1 197, Cerrillos 1 256, Chicoana 1 251, Orán 356, Rosario de la Frontera 786 m.
- **El mapa del Norte no es geográfico.** Un ajuste afín de los 8 sectores a sus pueblos reales deja errores de 5 a 50 km (Rosario 50, Chicoana 45, Orán 40, Jujuy 34). Por eso se usa una **spline de placa delgada** (exacta en los 8 sectores): cada sector queda sobre su pueblo real y la geografía entre ellos se estira (en `30_norte_dem_hillshade.png` se ven las vetas del estiramiento al este). Etiqueta `razonado` (alturas medidas sobre una deformación de diseño).
- Escala vertical: el Norte de hoy va de 0,4 a ≈ 17 unidades. `meta.suggested_game_height` propone `0,4 + 16,6 · ((h − 300)/4700)^0,65`, y después el aplanado de sectores que ya hace `terrain_height`. Es diseño: lo decide quien integre.

### 3.3 Justina (Retiro, 1806): sin DEM, a propósito

La ribera de 1806 quedó bajo los rellenos del puerto y de Retiro (la costa actual está ≈ 1 km más afuera) y el DSM mide edificios: no hay dato moderno que sirva. Además la altura de la Justina **es regla** (marea, vados, `terrain_height_at`). Solo se proponen texturas.

## 4. Licencias (verificadas el 9-nov-2026)

- **Poly Haven**: todo el sitio es CC0 (https://polyhaven.com/license, leído en esta sesión). No exige crédito; se acredita igual en `docs/CREDITOS.md`.
- **Copernicus DEM**: PDF oficial `copernicus_contributing_mission_data_access_v2_cop_dem_licenses.pdf` (dataspace.copernicus.eu, 499 914 B, SHA-256 `bb4a01dc…c8701f`), enlazado desde la página de la colección COP-DEM. Las instancias públicas son **GLO-30-F** y **GLO-90-F** («Full, Free & Open»): Art. 4 concede reproducción, distribución, comunicación al público y modificación, gratis, en todo el mundo y sin límite de tiempo; Art. 6 (b) exige el aviso «produced using Copernicus WorldDEM-30 [o WorldDEM™-90] © DLR e.V. 2010-2014 and © Airbus Defence and Space GmbH 2014-2018 provided under COPERNICUS by the European Union and ESA; all rights reserved» y 6 (c) la frase «The organisations in charge of the Copernicus programme by law or by delegation do not incur any liability for any use of the Copernicus WorldDEM-30 [WorldDEM™-90]»; 6 (d) prohíbe sugerir aval oficial. Los textos literales están en `assets/terrain/terrain_relief_manifest.json` y en cada JSON (`meta.notice`, `meta.disclaimer`).
- **Hallazgo para el dueño de `CREDITOS_RELIEVE.md`** (no se editó: no es de este paso): su frase de no responsabilidad («…do not assume any responsibility or liability with respect to the use made of the Product», marcada «pendiente de cotejo») **no es** la del Art. 6 (c) de GLO-30-F; la literal es la de arriba. Y `docs/CREDITOS.md` (sección del nivel II) todavía dice «Copernicus preparado, no en uso», cuando `data/humahuaca_height.json` ya es `copernicus_glo30`.

## 5. Plan de integración y riesgos

**Qué depende de la altura del terreno** (por qué el riesgo es bajo si se respeta el orden):

| Dato | Lo usan | Riesgo de cambiarlo |
|---|---|---|
| `data/humahuaca_height.json` (ventana y contexto) | `HumahuacaTerrain.height_at` → reglas (`speed_factor_at` por pendiente, `nav_build`/`plan_route`, visión `los`, explanadas), vista (malla, picking `ground_xz_from_screen`, `rendered_h` para río y caminos), minimapa; pruebas `test_hx_terrain` (167 comprobaciones, referencias R05 por fuente, TR-021/022), `test_hx_rules` (679), `test_hx_view`, `test_hx_data` V7 (empalme ventana/contexto ≤ 1 dm), V18 (aviso) | **Alto. No se toca en F5**: ya es Copernicus y los archivos nuevos empalman con él sin cambiarlo |
| Anillo del horizonte (`ring_height`) | Solo la vista: `terreno_horizonte` (TR-091: un solo material, malla hasta ≈ 8 km, sin grietas; TR-093: un rayo sobre el horizonte da null), la niebla y lo que entra en cuadro (cámara hasta 900 m) | **Bajo** para reglas (nada de juego consulta fuera del contexto). Visual: cambia el encuadre del alba y las capturas de referencia |
| `world_view.terrain_height` (Norte) | Vista: malla, colisión para el clic, posición de fichas, casas y árboles, etiquetas (`main.gd` proyecta con ella); aplanado de sectores | **Bajo-medio**: no es regla, pero el clic y las etiquetas dependen de la colisión; el rango vertical tiene que quedar parecido (0,4..17) |
| `game_rules.terrain_height_at` (Justina) | **Reglas** (marea, vados, hoyos ocultos) | No se propone cambiar |

**Pasos propuestos** (cada uno en su ronda, con `vis_*.sh` y las pruebas de su pista):

1. **Horizonte de Humahuaca** (visual): en `_ring_mesh`, reemplazar `ring_height` por la bilineal de `hx_horizonte_copernicus.json` (fila 0 sigue siendo `h()` del contexto: el empalme ya es exacto) y, más allá de 9 km, de `hx_lejano_copernicus90.json`; o subir el radio del anillo a ≈ 25 km solo con el lejano. Mantener la malla hasta ≥ 8 km (TR-091). Copiar `meta.notice` y `meta.disclaimer` a créditos.
2. **Texturas en `humahuaca_terrain.gdshader`**: un `sampler2DArray` por mapa (albedo, normal, ORM) con las seis capas; los pesos que ya existen (suelo→`hx_suelo_grava`, piedra→`hx_ladera_grava`/`hx_roca_ladera` por pendiente con proyección triplanar, sedimento/agua→`hx_cauce_cantos`, churqui→`hx_pasto_seco`, irrigada→`hx_andenes_tierra`); mezcla por `height` para bordes naturales; **teñir hacia la paleta** (el color de la paleta multiplica la luminancia de la textura) y **anti-repetición** (rotación/desfase por celda o macro-ruido) porque `cliff_side` y `grass_path_2` repiten. Fundir a solo-paleta con la distancia (> 150 m) para no pagar muestras en el contexto ni en el horizonte.
3. **Norte**: leer `norte_relieve_copernicus90.json` en `terrain_height` con el mapeo vertical sugerido, conservar el aplanado de sectores y la rampa/curvas del shader del Norte; texturas `norte_*` solo si la cámara del Norte se acerca lo bastante (hoy es un mapa visto de lejos).
4. **Justina**: texturas `jn_*` en `terrain_justina_r4.gdshader` por zona (playa, bajo, barranca), sin tocar la altura.

**Riesgos a medir antes de aceptar:**

- **Métrica de paleta del QA** (`albedo_mode = 1`, lámina 06, 24 colores; V06 y la enmienda 6): con textura el albedo deja de ser plano. El modo albedo tiene que seguir devolviendo el color plano de la paleta (rama aparte en el shader) y el color final tiene que quedar teñido hacia la paleta.
- **Rendimiento**: el presupuesto oficial de Humahuaca es 4 ms por cuadro (`benchmark.py --max-frame-ms 4`, perfiles baja/media/alta). Seis capas × tres mapas con triplanar en las laderas pueden costar; en `baja`, una sola capa o ninguna.
- **Exportación**: `export_presets.cfg` exporta `all_resources` + `data/*.json`. Los JSON de `assets/terrain/` **no se exportan** si no se agrega `assets/terrain/*.json` al `include_filter` (o se mueven a `data/`, que tiene topes de tamaño por V8). Los PNG de 16 bits son para herramientas externas: Godot los importaría como textura de 8 bits; el juego tiene que leer el JSON.
- **Peso**: +16,2 MB de texturas y +1,4 MB de relieve en el repo y en el paquete.
- **Capturas y textos**: el horizonte más bajo cambia el aspecto del alba y las capturas de referencia de V06; revisar `CREDITOS_VISUAL.md` (composición de 1923).
- **Norte**: la deformación de placa delgada hace que las montañas entre sectores no estén en su lugar exacto; es un mapa de campaña, no un levantamiento (DISENO_REGLAS: «simplificación operativa»).
- **Importación de Godot**: al abrir el editor se crean `.import` para los 48 JPG y los 3 PNG; nada los referencia todavía.

## 6. Reproducir

```sh
PY=<python con numpy, scipy y Pillow>
$PY -I -X utf8 tools/f5_terreno_texturas.py --download-dir <vacía_fuera_del_repo>
$PY -I -X utf8 tools/f5_terreno_texturas.py --verify
$PY -I -X utf8 tools/f5_terreno_texturas.py --preview ../qa-visual-r1/f5_terreno_preview
$PY -I -X utf8 tools/f5_terreno_relieve.py --tiles-dir <fuera_del_repo> --download --humahuaca --norte --preview-dir ../qa-visual-r1/f5_terreno_preview
```

Vistas previas: `10_texturas_iluminadas.png` (cada material con su normal y su oclusión, de cerca y de lejos), `20_hx_horizonte_dem_hillshade.png`, `21_hx_perfil_oeste_este.png` (DEM contra anillo procedural), `22_hx_lejano_dem_hillshade.png`, `30_norte_dem_hillshade.png`.
