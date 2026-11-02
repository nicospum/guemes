# Créditos del relieve y del mapa de «Humahuaca»

Este archivo es de la pista `relieve_mapa`. El integrador lo concatena en `docs/CREDITOS.md` al armar la entrega (CONTRATO 1.2 y 6.1). Lo verifica la regla V18 de `tests/test_hx_data.gd`: el aviso de Copernicus si `meta.source` es `copernicus_glo30`, y «OpenStreetMap» y «ODbL» mientras la traza del río salga de la lámina 03.

**Dato actual, no restitución del suelo de 1817.** El relieve, la traza del Río Grande y las posiciones del pueblo son del presente; la forma que tenía el valle en 1817 no se conoce. Lo que el juego agrega (cerro de la batería, plataforma, quebraditas, cauce, micro-relieve, tapias, zanjas, superficies y vados) es diseño y se rotula así en pantalla y en `report()`.

## Relieve (en uso)

- **Fuente de la grilla de relieve:** lámina 03 («Apoyo topográfico actual») de la documentación del proyecto, que declara «Modelo SRTM v3, resolución nominal 90 m… SRTMGL3v003: NASA/USGS, adquisición 2000, WGS84/EGM96; consulta OpenTopoData, 30 oct 2026». Los datos SRTM son de dominio público (NASA/USGS, que piden crédito): *NASA Shuttle Radar Topography Mission (SRTM) Version 3.0 Global 3 arc second, NASA JPL/USGS*.
- **Qué se hizo con ellos** (`meta.modified = true`): los 475 nodos de 150 m de la lámina se reconstruyeron (a ±10 m, 99,5 % de acuerdo con los colores de la lámina), se interpolaron en forma bilineal, se suavizaron con un gaussiano de σ = 15 m, se remuestrearon a una ventana de 10 m y a un contexto de 30 m y se recortaron. Generador: `tools/build_humahuaca_terrain.py --source lamina03`. Incertidumbre vertical: ±10 m. Etiqueta: «razonado».

## Traza del Río Grande y hitos (en uso)

- La traza del río (19 puntos medidos sobre la lámina 03, `humahuaca_map.json`: `river.pts`) y la posición del ancla de la iglesia (≈ 23,2041° S, 65,3492° O) provienen de la lámina 03, cuyo pie dice: «Hitos y río: © OpenStreetMap contributors, ODbL. La geometría urbana y el cauce actuales pueden diferir de los históricos».
- **© OpenStreetMap contributors.** Estos datos son un subconjunto de una base de datos derivada de OpenStreetMap, disponible bajo la **Open Database License (ODbL) 1.0** (https://opendatacommons.org/licenses/odbl/1-0/). Quien reutilice la traza del río debe conservar este aviso de atribución y distribuir el subconjunto bajo la misma licencia (ODbL, «share-alike»). El resto del juego (código y arte propios) no es una base de datos derivada y no queda alcanzado.
- Los hitos del nivel (templo, batería, cuartel, posta, partidas…) son posiciones **de diseño**, salvo el sitio de la iglesia (inferencia razonada, ±15 m): no se tomaron de ninguna base de datos.

## Copernicus DEM GLO-30 (preparado, todavía no en uso)

La tesela `Copernicus_DSM_COG_10_S24_00_W066_00_DEM.tif` (39 438 103 B, MD5 `8c0aef1d66f4d1e918a25ff7864ecab3`) está autorizada (ADDENDA A-02) y `tools/build_humahuaca_terrain.py --source copernicus` ya sabe leerla, pero **el juego no la usa**: sus alturas no cumplen la referencia de R05 (ver `RELIEVE.md`, sección 7) y el relieve sigue siendo el de la lámina. Si `meta.source` pasa a `copernicus_glo30`, rige este aviso (el texto literal del Artículo 6 de la licencia se copia del documento oficial al activarla; lo que sigue es el borrador de trabajo y la regla V18 lo exige):

> produced using Copernicus WorldDEM-30 © DLR e.V. 2010-2014 and © Airbus Defence and Space GmbH 2014-2018 provided under COPERNICUS by the European Union and ESA; all rights reserved.
>
> The organisations in charge of the Copernicus programme by law or by delegation do not assume any responsibility or liability with respect to the use made of the Product.

El dato se remuestrea, se filtra (mediana de 5 × 5 píxeles y gaussiano de 30 a 45 m) y se recorta, es decir, se **modifica** (`meta.modified = true`). No se sugiere ningún respaldo oficial de la Unión Europea, de la ESA ni de DLR o Airbus. Quien reciba derechos de redistribución del juego queda obligado a lo mismo (Art. 6 d y e).

## Herramientas

Python 3.11 con `numpy`, `scipy` y `Pillow`, ya instalados en la máquina de trabajo; no se descargó ni se instaló nada para el relieve.
