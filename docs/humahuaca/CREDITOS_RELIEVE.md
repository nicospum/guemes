# Créditos del relieve y del mapa de «Humahuaca»

Este archivo es de la pista `relieve_mapa`. El integrador lo concatena en `docs/CREDITOS.md` al armar la entrega (CONTRATO 1.2 y 6.1). Lo verifica la regla V18 de `tests/test_hx_data.gd`: el aviso de Copernicus (con la frase de no responsabilidad) porque `meta.source` es `copernicus_glo30`, y «OpenStreetMap» y «ODbL» porque la traza del río sale de la lámina 03.

**Dato actual, no restitución del suelo de 1817.** El relieve, la traza del Río Grande y las posiciones del pueblo son del presente; la forma que tenía el valle en 1817 no se conoce. Lo que el juego agrega (cerro de la batería, plataforma, quebraditas, cauce, micro-relieve, tapias, zanjas, superficies y vados) es diseño y se rotula así en pantalla y en `report()`.

## Relieve (en uso desde el 2 de noviembre de 2026): Copernicus DEM GLO-30

- **Fuente de la grilla de relieve:** tesela `Copernicus_DSM_COG_10_S24_00_W066_00_DEM.tif` del Copernicus DEM, instancia GLO-30 (modelo digital de **superficie** de 1 arcosegundo, ≈ 30 m, EGM2008), distribuida en el bucket público de AWS `copernicus-dem-30m` (AWS Open Data, a cargo de Sinergise). 39 438 103 bytes; SHA-256 `1b38c9054683f2ea927915ffc9f81e664f919cf13a6cbb4e93a1bd637301f97f`; MD5 `8c0aef1d66f4d1e918a25ff7864ecab3` (la misma tesela que autorizó el usuario en ADDENDA A-02; descargada de nuevo en la sesión del 2-nov-2026 y verificada contra ese SHA-256). La tesela vive fuera del repo y nunca entra a Git (`*.tif` está en `.gitignore`); el juego solo lee `data/humahuaca_height.json`.
- **Qué se hizo con ella** (`meta.modified = true`): se recortó alrededor del ancla (georreferencia píxel-es-punto verificada en las etiquetas del GeoTIFF), se filtró con una mediana de 5 × 5 píxeles (quita techos y árboles aislados) y un gaussiano de 45 m (`meta.smooth_m`), se remuestreó a una ventana de 10 m y a un contexto de 30 m en decímetros enteros sobre el cero local de 2 940 m, y la clase la interpola a 4 m al cargar. Generador: `tools/build_humahuaca_terrain.py --source copernicus`. Incertidumbre vertical declarada: ±5 m. Etiqueta: «razonado». Es un modelo de superficie: en el núcleo del pueblo los techos de hoy pueden sumar 1 a 3 m. Método y cifras: `docs/humahuaca/RELIEVE_COPERNICUS.md`.
- **Licencia:** «Licence for Copernicus DEM instance COP-DEM-GLO-30-PUBLIC and COP-DEM-GLO-90-PUBLIC» (`License-COPDEM-30.pdf`, https://documentation.dataspace.copernicus.eu/APIs/SentinelHub/Data/DEM/resources/license/License-COPDEM-30.pdf). Uso gratuito con atribución obligatoria; el producto se puede modificar y redistribuir conservando el aviso.

### Aviso de atribución (Artículo 6 de la licencia)

> produced using Copernicus WorldDEM-30 © DLR e.V. 2010-2014 and © Airbus Defence and Space GmbH 2014-2018 provided under COPERNICUS by the European Union and ESA; all rights reserved.
>
> The organisations in charge of the Copernicus programme by law or by delegation do not incur any liability for any use of the Copernicus WorldDEM-30
>
> (Para el horizonte lejano de Humahuaca y el relieve del Norte, hechos con GLO-90: «produced using Copernicus WorldDEM™-90 © DLR e.V. 2010-2014 and © Airbus Defence and Space GmbH 2014-2018 provided under COPERNICUS by the European Union and ESA; all rights reserved» y «The organisations in charge of the Copernicus programme by law or by delegation do not incur any liability for any use of the Copernicus WorldDEM™-90».)

En castellano, para el jugador: el relieve del nivel se produjo con el Copernicus WorldDEM-30 (© DLR e.V. 2010-2014 y © Airbus Defence and Space GmbH 2014-2018), provisto bajo el programa COPERNICUS por la Unión Europea y la ESA, todos los derechos reservados; el dato se remuestreó, se filtró y se recortó (producto **modificado**). La Unión Europea, la ESA, DLR y Airbus Defence and Space no respaldan este juego, y la organización a cargo del programa Copernicus no se hace responsable del uso que el juego hace del producto. Quien reciba derechos de redistribución del juego queda obligado a conservar este aviso (Art. 6 d y e).

**Cotejado (9-nov-2026, visual/r1 F5).** El Artículo 6 se cotejó con el PDF oficial de las licencias de la colección COP-DEM (`copernicus_contributing_mission_data_access_v2_cop_dem_licenses.pdf`, dataspace.copernicus.eu, 499 914 B, SHA-256 `bb4a01dc…c8701f`; detalle en `docs/humahuaca/F5_TERRENO.md`, sección 4): el aviso del 6 (b) coincide con el de arriba y la frase del 6 (c) es la que figura ahora (antes decía «…do not assume any responsibility or liability with respect to the use made of the Product», un texto estándar de catálogo que no es el de GLO-30-F). Los textos literales están también en `assets/terrain/terrain_relief_manifest.json` (`disclaimer_glo30`, `disclaimer_glo90`) y en `meta.notice` y `meta.disclaimer` de cada JSON de relieve. Lo corrigió la integración de F5 en el nivel II a pedido del dueño del proyecto (`docs/humahuaca/TEXTOS_REVISION.md`); V18 sigue exigiendo el prefijo «produced using Copernicus WorldDEM-30» y la frase de no responsabilidad en castellano.

## Lámina 03 (fue el relieve de R1; sigue siendo la referencia de los 41 puntos)

- **Lámina 03** («Apoyo topográfico actual») de la documentación del proyecto, que declara «Modelo SRTM v3, resolución nominal 90 m… SRTMGL3v003: NASA/USGS, adquisición 2000, WGS84/EGM96; consulta OpenTopoData, 30 oct 2026». Los datos SRTM son de dominio público (NASA/USGS, que piden crédito): *NASA Shuttle Radar Topography Mission (SRTM) Version 3.0 Global 3 arc second, NASA JPL/USGS*.
- De ella salen los **41 puntos** de la tabla d.7 del dossier (`humahuaca_map.json`: `relief.lamina_points`, la verificación R02) y el relieve reconstruido de R1 (475 nodos de 150 m, ±10 m; `--source lamina03`, plan B, recuperable del historial de Git: commit `333a657` de la rama `humahuaca-r1`).

## Traza del Río Grande y hitos (en uso)

- La traza del río (19 puntos medidos sobre la lámina 03, `humahuaca_map.json`: `river.pts`) y la posición del ancla de la iglesia (≈ 23,2041° S, 65,3492° O) provienen de la lámina 03, cuyo pie dice: «Hitos y río: © OpenStreetMap contributors, ODbL. La geometría urbana y el cauce actuales pueden diferir de los históricos».
- **© OpenStreetMap contributors.** Estos datos son un subconjunto de una base de datos derivada de OpenStreetMap, disponible bajo la **Open Database License (ODbL) 1.0** (https://opendatacommons.org/licenses/odbl/1-0/). Quien reutilice la traza del río debe conservar este aviso de atribución y distribuir el subconjunto bajo la misma licencia (ODbL, «share-alike»). El resto del juego (código y arte propios) no es una base de datos derivada y no queda alcanzado.
- Los hitos del nivel (templo, batería, cuartel, posta, partidas…) son posiciones **de diseño**, salvo el sitio de la iglesia (inferencia razonada, ±15 m): no se tomaron de ninguna base de datos.

## Herramientas

- Generación y verificación numérica: Python 3 con `numpy` 2.5.3, `scipy` 1.18.1, `Pillow` 12.3.0 y `tifffile` 2026.10.15 (instalados con `pip` en la sesión del 2-nov-2026, autorizados por el usuario; `tifffile` solo leyó las etiquetas de georreferencia, la grilla la lee Pillow).
- Pruebas sin pantalla: Godot 4.7.2 estable para Linux (`Godot_v4.7.2-stable_linux.x86_64.zip`, release oficial en GitHub, SHA-512 verificado contra `SHA512-SUMS.txt`), también autorizado y descargado fuera del repo.
