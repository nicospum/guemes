# Créditos y procedencia del arte del nivel «Humahuaca» (pista `visual`)

Lo concatena `docs/CREDITOS.md` en [final] (CONTRATO 1.2). Todo el arte del nivel sale del **generador procedural** de `scripts/humahuaca/view/humahuaca_gen.gd` y de shaders propios (ADDENDA A-01: Blender no está autorizado). **No se descargó ni se instaló nada**, no hay modelos de IA y no se usó ninguna biblioteca de arte ajena.

## Qué hay y de dónde sale

| Pieza | Procedencia | Licencia o estado |
|---|---|---|
| Templo, batería, casa del cura, posta, torre, casas del núcleo, cañones, carretas, cercos, caballo, mula, figuras (los tres arquetipos y el realista), churqui, cardón, sauce, rocas y bultos | Geometría propia armada por `humahuaca_gen.gd` con cajas, troncos de cono, prismas a dos aguas, cilindros y elipsoides, y color de vértice por **id de paleta**. Sin mallas importadas | Obra propia del proyecto; sin terceros |
| `shaders/humahuaca_terrain.gdshader`, `humahuaca_props.gdshader`, `humahuaca_water.gdshader`, `humahuaca_rain.gdshader` | Escritos para el nivel | Obra propia del proyecto |
| `shaders/humahuaca_noise.gdshaderinc` | **Copia** de `shaders/justina_noise.gdshaderinc` (Justina, ronda 4: hash sin seno), con las funciones renombradas de `j_` a `hx_`, más las funciones propias del nivel (celdas de Worley, crestas, conversión sRGB). Se copia y no se incluye a propósito (CONTRATO 1.3) | Obra propia del proyecto (misma licencia que la Justina) |
| Paleta de 24 colores | Lámina 06 del material del usuario (`info/2/06_paletas.png`), verificada exacta contra los píxeles en el informe 01 §f. Son **decisiones digitales de producción, no mediciones de 1817** | Material del usuario, solo lectura |
| Composición del panorama (ladera clara, arbustos oscuros, techos claros, arbolado oscuro, lecho claro, llanura, estratos, cordillera) | **Relación** tomada de la foto de 1923 *Panorama de Humahuaca* (*Plus Ultra*, abril de 1923; la reproducción declara dominio público), **no copia**: no se usa ninguna textura, recorte ni vista de la foto, y se excluyen sus torres, su fachada, sus álamos y su alumbrado (DISEÑO 12.3) | Referencia compositiva; sin píxeles de la foto en el juego |
| Silueta de las fichas y vestuario | Diseño propio sobre el dossier (informe 01 §h y diseño 12.4): variantes por prenda, sin uniformar; el bando lo dan el anillo y el contorno, no el color de la ropa; el banderín de Arias es un marcador de interfaz, no una bandera | Diseño; etiquetado `diseno` en `humahuaca_visual.json` |

## Relieve en las capturas de evidencia de R1

El juego **no** incluye ningún dato de Copernicus: el relieve del juego es `data/humahuaca_height.json` (`relieve_mapa`, plan B hasta que se decida otra fuente, ADDENDA A-02). Las capturas de `evidence/humahuaca/r1/visual/` se renderizaron con `tools/vis_humahuaca.gd --relief=<carpeta>` sobre un relieve de prueba derivado del DEM de Copernicus GLO-30 que preparó el explorador (fuera del repositorio; remuestreado, suavizado y recortado), **solo para ver el suelo con pendientes** mientras llega la clase real de relieve. Aviso de la licencia para esas imágenes: *produced using Copernicus WorldDEM-30 © DLR e.V. 2010-2014 and © Airbus Defence and Space GmbH 2014-2018 provided under COPERNICUS by the European Union and ESA; all rights reserved.* El dato fue modificado y las imágenes no son restitución del suelo de 1817. La frase de no responsabilidad del Artículo 6 de la licencia la copia `relieve_mapa` en `docs/humahuaca/CREDITOS_RELIEVE.md`.

## Qué no entra

Álamos piramidales, eucaliptos, postes, tendidos, alumbrado, la fachada y las torres actuales del templo, el monumento y su escalinata, banderas de 1817 con sol, uniformes homogéneos y toda figura de Güemes en el mapa (DISEÑO 12.3 y 12.4). La prueba `tests/test_hx_view.gd` mira los **nombres de los nodos** y la **altura de los vértices** (el templo no pasa de su caballete de 7 m).
