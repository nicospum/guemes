# Relieve real de «Humahuaca»: Copernicus DEM GLO-30 (pista `relieve_mapa`)

Estado: **hecho el 2 de noviembre de 2026** en la rama `hx-relieve-nube` (sobre `humahuaca-r1`, `333a657`), por decisión del usuario de usar el DEM Copernicus GLO-30 como fuente real del relieve (ADDENDA A-02 lo autorizaba desde R2a). Dueña: `relieve_mapa`. Este documento registra el método, la comparación con el plan B (lámina 03) en los 41 puntos, lo que se verificó sin pantalla (R01 a R06 del anexo A1 de `docs/QA_NIVEL2.md` y las pruebas `--headless`), **dónde el relieve real contradice el diseño y qué ajuste se propone**, y lo que no se alcanzó. Complementa `RELIEVE.md` (cómo se arma la altura, convenciones, visión, mapa chico) y `CREDITOS_RELIEVE.md` (licencia y aviso).

**Regla que se siguió:** el relieve real no se fuerza para que cumpla cifras que salían de la lámina. Donde el DEM contradice un hito de diseño, el dato se deja como está, la prueba de la pista mide contra la fuente en uso (`map.relief.references.<fuente>`) y la diferencia queda acá, con la enmienda del QA o el ajuste de diseño propuesto, para que lo decidan el jefe de QA, el integrador y el usuario.

## 1. Qué cambió y qué no

| Archivo | Cambio |
|---|---|
| `data/humahuaca_height.json` | Regenerado desde la tesela: `meta.source = copernicus_glo30`, `source_detail` con nombre, tamaño, SHA-256 y MD5 de la tesela, `uncertainty_m = 5`, `smooth_m = 45`, `modified = true`. Mismo esquema (ventana 91 × 66 a 10 m, contexto 121 × 91 a 30 m, decímetros, `map_version` 1): 66 KB |
| `data/humahuaca_map.json` | `cerro_bateria.delta_m` 12,31 → **6,56** (residuo recalculado por el builder; la clase lo resuelve igual al cargar); **`relief.references`** nuevo (alturas de referencia por fuente, sección 5.1); `provenance` y `license` dicen Copernicus. Ancla, ventana, hitos, río, superficies y capas de diseño: **sin cambios** |
| `tools/build_humahuaca_terrain.py` | `--expect-sha256` (corta si la tesela no es la autorizada), hashes reales en `meta.source_detail`, `--compare` (los 41 puntos, R05, curva de 2 960 m y pendientes de varios archivos: la verificación «DEM contra SRTM» del diseño §4), georreferencia documentada |
| `tests/test_hx_terrain.gd` | Referencias por fuente, visión desde el parapeto, pendiente del micro-relieve medida sola, TR-021 evaluado, sanidad de la fuente real (sección 4) |
| `docs/humahuaca/CREDITOS_RELIEVE.md`, `RELIEVE.md` | Aviso de Copernicus en uso; estado y cifras |
| **No se tocó** | `scripts/humahuaca/terrain/**` (la clase ya resolvía el domo como residuo), `humahuaca_level.json`, `scripts/main.gd`, la Justina, el Norte, `docs/QA_NIVEL2.md`, `ADDENDA.md`, `TRAZA.md`, `main`, etiquetas |

El plan B no se duplicó en `data/` (no existía con otro nombre y sumaría 69 KB al export): se recupera con `git show 333a657:data/humahuaca_height.json` o con `--source lamina03` y el CSV de la lámina.

## 2. Método

1. **Tesela.** `Copernicus_DSM_COG_10_S24_00_W066_00_DEM.tif` (39 438 103 B; SHA-256 `1b38c905…301f97f` verificado contra el esperado; MD5 `8c0aef1d…ecab3`), bajada del bucket público de AWS `copernicus-dem-30m` a una carpeta fuera del repo. GeoTIFF float32 de 3 600 × 3 600 píxeles, WGS 84, 1 arcosegundo, Deflate con predictor 3; la lee Pillow (`tifffile` solo sirvió para las etiquetas).
2. **Georreferencia (verificada en las etiquetas).** `GTRasterTypeGeoKey = PixelIsPoint` y punto de amarre (−66,0; −23,0) en el **centro** del píxel (0, 0): el píxel (fila r, columna c) está centrado en lon = −66 + c/3600, lat = −23 − r/3600. El ancla (23,2041° S, 65,3492° O; `x = 450, z = 325`) cae en la fila 734,76 y la columna 2342,88 y el muestreo cúbico va directo sobre esas coordenadas continuas, sin corrimiento de medio píxel. Un píxel mide 30,76 m de norte a sur y 28,44 m de oeste a este (fórmulas de metros por grado a esa latitud). Datum vertical: EGM2008 (la lámina/SRTM usa EGM96; la diferencia entre geoides en la zona es submétrica y no se corrigió).
3. **Filtro.** Es un modelo de **superficie** (techos y árboles de hoy): mediana de 5 × 5 píxeles (≈ 140 m; quita picos aislados) y gaussiano de 45 m (σ = 22,5 m; `meta.smooth_m`, el rango 30–45 m que fija A-02). Con 30 m el resultado es el mismo en los 41 puntos (40 de 41, peor 15,1 m contra 14,3) y apenas más áspero (p95 de pendiente 10,5° contra 9,6°); se dejó 45 m, que era la receta medida en R1. Sin filtro, el DSM crudo tiene p95 de 12,5° y máximo 20° dentro de la ventana; el filtro cambia la cota en 0,86 m de media (p95 2,8 m, máximo 7 m).
4. **Muestreo.** Spline cúbica sobre el recorte filtrado → ventana de 10 m y contexto de 30 m, decímetros enteros sobre 2 940 m; el borde de la ventana se fuerza a la bilineal del contexto (130 nodos tocados, ≤ 0,5 dm). Al cargar, `HumahuacaTerrain` interpola a la malla de 4 m con Catmull-Rom, igual que antes. El generador es determinista.
5. **Capas de diseño, sin cambios.** El domo de la batería es un residuo: `delta_m` pasa de 12,31 a 6,56 m porque la ladera real ya sube 5,45 m sobre el anillo de 135 m; la prominencia final sigue en 12,0 m. Plataforma, quebraditas, cauce y micro-relieve, idénticos.

Comandos (Git Bash o Linux; rutas absolutas fuera del repo):

```sh
python -I -X utf8 tools/build_humahuaca_terrain.py --source copernicus --tif "$TIF" --expect-sha256 1b38c9054683f2ea927915ffc9f81e664f919cf13a6cbb4e93a1bd637301f97f --update-map
python -I -X utf8 tools/build_humahuaca_terrain.py --compare <relieve_plan_B.json> data/humahuaca_height.json
godot --headless --path . --script tests/test_hx_terrain.gd      # con XDG_DATA_HOME o APPDATA en una carpeta ap_iso_<pista>
```

## 3. Plan B (lámina 03) contra Copernicus en los 41 puntos

DEM sin capas de diseño, en metros sobre el nivel del mar; `est` es la estimación de la lámina (tabla d.7 del dossier, SRTM de 90 m) y la banda, su curva de 20 m; `err` = |valor − est|. El plan B **se reconstruyó de esas mismas estimaciones**, por eso les acierta a 0,3 m: no es un dato independiente. Copernicus sí lo es.

| Punto | E | N | est | Banda | Plan B | err | Copernicus | err |
|---|---|---|---|---|---|---|---|---|
| P01 (ancla) | 0 | 0 | 2957 | 2940–2960 | 2957,1 | 0,1 | 2947,8 | 9,2 |
| P02 | −111 | −35 | 2961 | 2960–2980 | 2960,8 | 0,2 | 2964,2 | 3,2 |
| P03 | −143 | 3 | 2962 | 2960–2980 | 2961,7 | 0,3 | 2964,9 | 2,9 |
| P04 (NO) | −450 | 325 | 2971 | 2960–2980 | 2971,0 | 0,0 | 2976,0 | 5,0 |
| P05 (NE) | 450 | 325 | 2954 | 2940–2960 | 2954,2 | 0,2 | 2947,9 | 6,1 |
| P06 (SO) | −450 | −325 | 2969 | 2960–2980 | 2968,8 | 0,2 | 2967,9 | 1,1 |
| P07 (SE) | 450 | −325 | 2946 | 2940–2960 | 2945,9 | 0,1 | 2937,7 | 8,3 |
| P08 | −450 | 0 | 2970 | 2960–2980 | 2970,0 | 0,0 | 2973,1 | 3,1 |
| P09 | 450 | 0 | 2952 | 2940–2960 | 2951,9 | 0,1 | 2942,2 | 9,8 |
| P10 | 0 | 325 | 2955 | 2940–2960 | 2955,1 | 0,1 | 2948,1 | 6,9 |
| P11 | 0 | −325 | 2958 | 2940–2960 | 2957,4 | 0,6 | 2958,0 | 0,0 |
| P12 | −225 | 162 | 2964 | 2960–2980 | 2963,4 | 0,6 | 2965,5 | 1,5 |
| P13 | 225 | 162 | 2953 | 2940–2960 | 2953,0 | 0,0 | 2945,0 | 8,0 |
| P14 | −225 | −162 | 2965 | 2960–2980 | 2965,0 | 0,0 | 2968,9 | 3,9 |
| P15 | 225 | −162 | 2952 | 2940–2960 | 2951,9 | 0,1 | 2942,4 | 9,6 |
| P16 | 122 | 325 | 2954 | 2940–2960 | 2953,6 | 0,4 | 2946,2 | 7,8 |
| P17 | 297 | 200 | 2953 | 2940–2960 | 2952,4 | 0,6 | 2944,4 | 8,6 |
| P18 | 409 | 0 | 2952 | 2940–2960 | 2951,9 | 0,1 | 2941,5 | 10,5 |
| P19 | 450 | −81 | 2951 | 2940–2960 | 2951,0 | 0,0 | 2940,9 | 10,1 |
| P20 | 596 | −271 | 2948 | 2940–2960 | 2948,6 | 0,6 | 2939,2 | 8,8 |
| P21 | 460 | −700 | 2939 | < 2940 | 2939,1 | 0,1 | 2932,9 | 6,1 |
| P22 | −279 | 1000 | 2958 | 2940–2960 | 2958,3 | 0,3 | 2956,3 | 1,7 |
| P23 | 435 | −1345 | 2932 | < 2940 | 2932,1 | 0,1 | 2926,3 | 5,7 |
| P24 (curva) | −180 | 325 | 2960 | = 2960 | 2960,1 | 0,1 | 2956,9 | 3,1 |
| P25 (curva) | −84 | 0 | 2960 | = 2960 | 2959,8 | 0,2 | 2957,3 | 2,7 |
| P26 (curva) | −70 | −325 | 2960 | = 2960 | 2959,6 | 0,4 | 2963,1 | 3,1 |
| P27 | −1800 | 0 | 3014 | 3000–3020 | 3014,0 | 0,0 | 3011,5 | 2,5 |
| P28 | −1500 | 0 | 3004 | 3000–3020 | 3004,8 | 0,8 | 2999,0 | 5,0 |
| P29 | −1000 | 0 | 2990 | 2980–3000 | 2990,1 | 0,1 | 2984,1 | 5,9 |
| P30 | −750 | 0 | 2977 | 2960–2980 | 2977,2 | 0,2 | 2978,7 | 1,7 |
| P31 | 750 | 0 | 2956 | 2940–2960 | 2956,2 | 0,2 | 2953,1 | 2,9 |
| P32 | 1000 | 0 | 2973 | 2960–2980 | 2973,3 | 0,3 | 2968,7 | 4,3 |
| P33 | 1250 | 0 | 2992 | 2980–3000 | 2992,5 | 0,5 | 2991,9 | 0,1 |
| P34 | 1500 | 0 | 3024 | 3020–3040 | 3024,9 | 0,9 | 3020,3 | 3,7 |
| P35 | 1800 | 0 | 3088 | 3080–3100 | 3086,2 | 1,8 | 3086,8 | 1,2 |
| P36 | −1800 | 1350 | 3025 | 3020–3040 | 3024,9 | 0,1 | 3031,1 | 6,1 |
| P37 | 1800 | 1350 | 3065 | 3060–3080 | 3064,9 | 0,1 | 3066,1 | 1,1 |
| P38 | −1800 | −1350 | 3003 | 3000–3020 | 3002,9 | 0,1 | 3008,3 | 5,3 |
| P39 | 1800 | −1350 | 3116 | 3100–3120 | 3116,1 | 0,1 | 3101,7 | **14,3** |
| P40 | 350 | −1250 | 2932 | < 2940 | 2932,5 | 0,5 | 2927,8 | 4,2 |
| P41 | 1800 | −750 | 3137 | > 3120 | 3134,8 | 2,2 | 3136,5 | 0,5 |

| Resumen (R02) | Plan B | Copernicus (45 m) |
|---|---|---|
| Puntos a ≤ 12 m (pide ≥ 37) | 41 de 41 | **40 de 41** (P39, esquina SE del dominio, a 2,2 km del pueblo) |
| Peor error (pide ≤ 20 m) | 2,2 m | 14,3 m |
| En su banda de color ±8 m (pide 41) | 41 | **41** |
| Error medio (diseño §4: < 12 m) | 0,32 m | **5,0 m** (mediana 4,3 m) |

**Lectura.** Copernicus está **8 a 10 m más bajo** que la lámina en el núcleo del pueblo y hacia el este (P01, P05, P07, P09, P13, P15 a P20) y 1 a 5 m más alto en la ladera del oeste (P02 a P04, P08, P12, P14): el gradiente real de oeste a este dentro de la ventana es de **31 m** (la lámina decía 17) y el rango de cotas, de **38 m** (2 938 a 2 976; la lámina, 25). Es la diferencia entre un SRTM de 90 m reconstruido a ±10 m y un modelo de 30 m: dentro de lo que la lámina admitía, pero con consecuencias para el diseño (sección 5). Diferencia nodo a nodo en la ventana: media −4,3 m, |d| media 6,6 m, extremos −11,9 y +7,8 m; en el contexto, media −2,6 m.

Dos consecuencias más del relieve real, que la lámina no podía mostrar: **la ladera.** El 7 % de las celdas de la ventana a 10 m (8,4 % de la malla de 4 m con las capas) tiene 8° o más, concentradas en la franja x ≈ 330–430 (el pie del cerro, 9° a 14°, justo donde el diseño puso la calle del cuartel) y en la barranca del cauce; la lámina daba 0 %. Y **el río:** sobre el DEM solo, a lo largo de la traza del mapa el Río Grande cae 5,2 m de norte a sur en 536 m (0,97 %, sin ningún tramo que suba; la lámina lo tenía a 0,47 %) y el perfil se aparta de una recta 0,17 m de media (máximo 0,34 m): un perfil creíble para un cauce de piedemonte.

## 4. Qué se verificó sin pantalla

### 4.1 Los ítems R01 a R06 del QA (anexo A1 sobre el volcado real)

`qa_relieve.gd` (extraído tal cual del anexo A1) volcó la clase real con `--headless`; sobre ese volcado se corrió la misma lógica y los mismos umbrales de `qa_relieve.py`, salvo lo que necesita la lámina 03 en PNG o una pantalla, que en la nube no hay.

| Ítem | Umbral (QA v1.5) | Medido con Copernicus | Estado |
|---|---|---|---|
| R01 ancla, ventana, 21 hitos y 7 relaciones | exactos | ancla (450, 325), conversión exacta, 226 × 164 a 4 m, 21 hitos, 7 relaciones | **pasa** |
| R02 los 41 puntos | ≥ 37 a ≤ 12 m; ninguno > 20; 41 en banda | 40 de 41; peor 14,3 m; 41 en banda; error medio 5,0 m | **pasa** |
| R03 curvas de 20 m | con otra fuente: ventana ≥ 75 %, dominio ≥ 70 % | **no medible en la nube** (pide los píxeles de `03_relieve_actual.png`). Última medida con esta misma receta, en la PC del usuario el 2-nov (RELIEVE.md §7): 93,3 % y 84,9 % | pasa (medida previa) |
| R04 Río Grande | ≥ 15 filas, medio ≤ 6 m, máx ≤ 12 m; entra por el norte, sale por el este | la traza del río **no depende de la fuente** (19 puntos del mapa, sin cambios): entra en (574,5; 0) y sale en (900; 405); el cotejo fila por fila contra la lámina no se repitió en la nube (medido en R1: 21 filas, 0,7 m medio, 2,6 m máx) | pasa (traza sin cambios) |
| R05 prominencia de la batería | 12,0 ± 0,5 m sobre el anillo de 120–150 m | **12,000 m** (residuo 6,57 m sobre el DEM); `report()` rotula `cerro_bateria` como `diseno` con `prominence_target_m` = 12 | **pasa** |
| R05 batería sobre la plaza | 14–19 m | **25,57 m** | **falla con la rúbrica**: sección 5.1 |
| R05 alturas de referencia | templo +17, cauce +12, partida +27 (± 3 m con DEM real) | templo **+7,86**, cauce **+0,19**, partida +28,91 | **falla con la rúbrica**: sección 5.1 |
| R06 continuidad y rutas | salto ≤ 0,10 m; 5 partidas → 3 objetivos y vado | salto máximo **0,04 m**; un solo componente (9 de 9 puntos) | **pasa** |
| R06 capturas de cámara en el límite | sin huecos ni borde del mundo | no medible sin pantalla | pendiente (igual que en R1: lo cubre la compuerta completa) |

### 4.2 Pruebas `--headless` (Godot 4.7.2 Linux, perfil aislado)

| Suite | Resultado | Cifras |
|---|---|---|
| `tests/test_hx_terrain.gd` (ronda vigente `r1`) | **167 comprobaciones, 0 fallas**; 1 pendiente (TR-022, vence en r2a: sección 5.4) | horneado **70 ms** (lectura 2,7; relieve 5,1; capas 41,9; pendiente 9,6; superficies 6,7; muros 0,5; navegación 2,4; informe 1,5; tope 300); `height_at` 2,17 millones de consultas/s; `los` 35 µs; error medio contra la lámina 5,02 m; batería 25,57 m sobre la plaza; DEM solo: pendiente máxima 13,7°, 7,35 % de celdas ≥ 8°, río cae 5,21 m |
| `tests/test_hx_terrain.gd -- --ronda=r2a` | 168 comprobaciones, **1 falla**: TR-022 «diferencia de cota entre objetivos ≤ 1 m con otra fuente», que exige las explanadas de R2a (sección 5.4) | igual |
| `tests/test_hx_data.gd` | **421 comprobaciones, 0 fallas** (V18 verde con el aviso de Copernicus; V7 verde con la grilla nueva) | 2,6 s |
| `tests/test_hx_rules.gd` (de `reglas_historia`, sin tocar) | **679 comprobaciones, 0 fallas** sobre el relieve real | **`nav_build` 4,49 ms** (tope 80) · **`plan_route` 3,65 ms** (tope 30) · `tick` 0,14 ms · HUD 0,51 ms |
| `tests/test_hx_smoke.gd`, `test_hx_view.gd`, `test_hx_flow.gd` (de otras pistas, sin tocar) | **158 / 284 / 285 comprobaciones, 0 fallas** sobre el relieve real | 39 s, 13 s, 43 s |

Qué cambió en `test_hx_terrain` (todo en la pista): (a) las referencias de altura se leen de `map.relief.references.<fuente>` (con la lámina, las de la rúbrica; sin bloque declarado la prueba falla); (b) el error medio contra las 41 estimaciones (≤ 12 m) se mide y se publica; (c) la banda del ancla y de las esquinas usa la tolerancia ±8 m con la que R02 define «en banda» (la esquina SE real está a 2 937,7 m, 2,3 m bajo la banda de la lámina); (d) la visión de la calle del cuartel se exige desde el **parapeto este** de la losa y se publica si se ve desde el centro (sección 5.2), y se mide cuántos puntos a 60–120 m se ven solo gracias al domo y la plataforma (≥ 3); (e) la pendiente del micro-relieve se mide **sola** (< 8°) y, donde el DEM es llano, la final (< 8°): la ladera real sí pasa de 8° y eso es dato; (f) TR-021 (≥ 2,5 % de celdas ≥ 8° y ≥ 3 rasgos con consecuencia) ya se cumple y se evalúa; (g) sanidad de una fuente real: el río baja sin tramos que suban, sin picos ni acantilados (< 25°) y con ≥ 2,5 % de ladera sin capas. Ninguna función de prueba citada en `TRAZA.md` cambió de nombre (V20 verde).

## 5. Dónde el relieve real contradice el diseño y qué se propone

### 5.1 Las alturas de referencia de R05 salían de la lámina (enmienda del QA, opción b del pedido C1)

| Referencia | Rúbrica v1.5 (lámina) | Plan B medido | **Copernicus medido** | Propuesta para R05 con DEM real |
|---|---|---|---|---|
| templo (450, 325) | +17 ± 3 | +17,1 | **+7,9** | **+7,9 ± 3** |
| cauce en z = 325 (859, 325) | +12 ± 3 | +11,9 | **+0,2** | **+0,2 ± 3** |
| zona de partida (70, 470) | +27 ± 3 | +28,6 | +28,9 | +28,9 ± 3 |
| batería sobre la plaza | 14–19 | 16,7 | **25,6** | **23–28** (sección 5.2 discute si conviene bajarla) |
| curva de 2 960 m en z = 0 / 325 / 650 | x = 270 / 366 / 380 ± 15 | 272 / 361 / 371 | **256 / 348 / 433** | 256 / 348 / 433 ± 15 |
| prominencia sobre el anillo | 12,0 ± 0,5 | 12,0 | 12,0 | sin cambio (es un residuo y funciona) |

Las cifras de la columna «rúbrica» son las de la propia lámina (±10 m), y ningún DEM real las cumple a ±3 m; con el relieve real la tolerancia de ±15 m para la curva de 2 960 m equivale a ±0,5 m de cota en una ladera del 3 %, por eso la posición cambió 18 y 53 m en dos de los tres bordes. Los valores propuestos ya están en `humahuaca_map.json` (`relief.references.copernicus_glo30`, etiqueta `razonado`) y `qa_relieve.py` los daría por buenos si la rúbrica los adopta (la corrida de la sección 4.1 lo verificó con el mismo volcado). Las dos relaciones de diseño que importan se conservan con cualquier fuente: el cauce queda 6,2 m bajo el templo (lámina 5,2) y el oeste 31 m sobre el este.

### 5.2 La ladera real pasa por donde el diseño puso la calle del cuartel (ajuste de diseño, decisión del usuario e integrador)

Lo que dice el DEM: el pie del cerro de Santa Bárbara (el «cerro de la batería» del diseño) está unos 30 a 60 m más al este que el domo (305, 345): entre x = 330 y x = 430 el suelo cae de 24 a 9 m, una ladera de 9° a 14° que atraviesa la calle del cuartel (tapias de (344, 376)–(404, 376) y (344, 386)–(404, 386)). Consecuencias medidas:

- La calle sube 15 m en 60 m: su tapia norte queda 3 a 4 m **por encima** de la calle, y desde el **centro** de la losa de la batería la calle no se ve (la tapia la tapa); desde el **parapeto este** (a 10 m del centro, donde apuntan las piezas) sí se ve, y también la calle de la posta a 200 m. La prueba ahora exige el parapeto y publica el centro (`los_calle_cuartel_desde_centro = false`).
- La batería queda 25,6 m sobre la plaza (el diseño pensaba 16–17): domina el núcleo entero y, por encima del templo (7 m), también el patio de la posta (`los_patio_posta_desde_bateria = true`; con la lámina el templo lo tapaba). Sobre el tiro no cambia nada (el bono de altura satura a 6 m); cambia la visión.
- La regla de pendiente, que el diseño creía que solo activarían las capas, ahora actúa en esa franja: subir del cuartel a la batería cuesta ×0,97 a ×0,82 según el tramo.
- Con el domo como residuo, la plataforma queda a 32,66 m; su borde oeste coincide con el núcleo del domo (33,8 m), apenas 1 m más alto: desde el oeste el «cerro» es un hombro, no una loma (ya pasaba con la lámina: la zona de partida está a 28,9 m).

Opciones, de menor a mayor intervención (ninguna se aplicó):

1. **Aceptar el relieve y enmendar R05** (banda 23–28 m sobre la plaza, referencias de 5.1). Costo cero; la batería domina más de lo pensado y el patio de la posta queda a la vista desde ella. Recomendada si «la diversión y la claridad mandan»: la ventaja de la batería se lee mejor, no peor.
2. **Mover o girar la calle del cuartel** (`humahuaca_level.json`, de `reglas_historia`): correr las tapias 30–40 m al este (x 380–440, donde la ladera baja a 5°) o alinearlas norte–sur siguiendo la curva, para que la calle sea llana y la tapia no quede cuesta arriba. Costo: una ronda de `reglas_historia` con sus puestos de ataque y su prueba.
3. **Dimensionar las explanadas de R2a sobre el relieve real** (sección 5.4) en vez de sobre la lámina; la del cuartel pediría un desmonte de 1,5 m en el edificio pero de 10 a 15 m en el extremo oeste de la calle, es decir, forzar el DEM: no se recomienda sin mover la calle.
4. **Bajar `prominence_target_m`** (p. ej. a 5 m: la plataforma quedaría a 18,6 m sobre la plaza, dentro de 14–19). Cambia un número de diseño que el QA mide (12,0 ± 0,5) y vuelve la batería más chata desde el oeste; solo si el usuario prefiere la escala original.

### 5.3 La premisa «el relieve real por sí solo no activa ninguna regla» ya no vale

`DISENO_HUMAHUACA.md` §4 dice que dentro de la ventana el terreno real sube 25 a 38 m con pendiente máxima de ≈ 3°. Con Copernicus sube 38 m y el 7 % de las celdas tiene 8° o más **sin ninguna capa de diseño** (la lámina daba 0 %); TR-021 (≥ 2,5 % de celdas ≥ 8° y ≥ 3 rasgos verticales con consecuencia) ya se cumple sin la barranca, la terraza ni el banco. Propuesta: en R2a, antes de agregar esas tres capas, medir qué aporta cada una sobre el relieve real; la barranca del cauce, por ejemplo, ya existe en el DEM (el cauce está 1,5 m bajo su orilla antes de tallarlo).

### 5.4 TR-022 y las explanadas de R2a (pendiente, vence en r2a)

La prueba A/B del contrato (2.1) exige que al cambiar de fuente la diferencia de cota entre los tres objetivos cambie ≤ 1 m, cosa que garantizan las explanadas (`pad`) de R2a, todavía no construidas. Hoy, sin ellas, cambió 7 a 8 m: batería − cuartel pasó de 15,8 a 22,6 m y batería − posta de 19,7 a 28,2 m. Lo que el relieve real dice de esas explanadas (altura respecto del templo): cuartel **+2,2** (el diseño pide +0,7), posta **−3,4** (pide −3,0), plaza **−0,8** (pide 0). Posta y plaza ya están casi donde el diseño las quería; el cuartel está en el pie de la ladera (sección 5.2). TR-022 queda **pendiente** en `test_hx_terrain` (falla desde `--ronda=r2a`) hasta que se construyan las explanadas sobre estas cifras.

### 5.5 Lo que es un modelo de superficie

El DSM incluye techos y árboles: en el núcleo (templo, cuartel, plaza) el «suelo» puede estar 1 a 3 m alto, y en la ribera los sauces pueden levantar la orilla. La mediana de 5 × 5 quita árboles y casas aisladas, no manzanas enteras. Se declara ±5 m (`meta.uncertainty_m`), etiqueta `razonado`, y el rótulo «dato actual, no restitución del suelo de 1817» sigue en pantalla y en `report()`.

## 6. Qué no se alcanzó

1. **El Artículo 6 de la licencia, literal.** `License-COPDEM-30.pdf` no se pudo bajar: `documentation.dataspace.copernicus.eu` (y los espejos de Copernicus y Sentinel Hub) no están permitidos en la red de la sesión. `CREDITOS_RELIEVE.md` lleva el aviso estándar con el prefijo y la frase de no responsabilidad que exige V18, marcado «pendiente de cotejo» para que quien tenga el PDF lo coteje antes de [final].
2. **R03 y el cotejo de R04 contra la lámina** no se repitieron (hace falta `03_relieve_actual.png`, que está en la PC del usuario); valen las medidas previas con esta misma receta (93,3 % / 84,9 %; 21 filas, 0,7 m). **R06 capturas** y cualquier verificación visual: sin pantalla ni GPU.
3. **La enmienda del QA y el addendum** no son de esta pista: quedan propuestos (sección 5) para el jefe de QA y el integrador. Hasta que se escriban, `qa_relieve.py` con la rúbrica v1.5 marca dos comprobaciones de R05 en falla (4.1) aunque `test_hx_terrain` esté verde.
4. **Las explanadas, la barranca, la terraza y el banco de R2a** no se construyeron (fuera del encargo): TR-022 sigue pendiente.
5. `receta_dem.py` y `verificar_dem_vs_srtm.py` no existían en la rama (`investigacion-nivel2/` vive fuera de Git): su función la cumple `tools/build_humahuaca_terrain.py` (`--source copernicus --expect-sha256` y `--compare`), sin scripts sueltos.
