# P6 · Modelos 3D propios para el nivel II «Humahuaca» (Blender en línea de comandos)

Pista P6 del equipo (BACKLOG: «P6 entrega GLB nuevos que integra P2»). Fecha: 2026-11-08. Base: `equipo/integracion` (70b2341).

## Estado en una línea

**El código de los nueve modelos está escrito y probado en seco, pero los GLB `assets/models/hx_*.glb` todavía no existen: en esta PC no hay un Blender que funcione.** Hace falta que el usuario reinstale Blender 4.4 (o autorice descargar el portable 4.4.3 de blender.org, unos 385 MB). Después alcanza con una sola orden (sección 6).

### Qué Blender hay en la PC (comprobado el 2026-11-08)

| Lugar | Qué hay | ¿Arranca? |
|---|---|---|
| `C:/Program Files/Blender Foundation/Blender 4.4/` | Solo `4.4/python` y `4.4/scripts` (209 archivos, 6,5 MB). **No hay `blender.exe`**; no figura en «Programas instalados» | no |
| `%TEMP%/bl443/blender-4.4.3-windows-x64/` | `blender.exe` firmado y `python311.dll`, pero `blender.shared/` vacío y `4.4/` casi vacío (97 MB de una instalación de ~1 GB; parece purgado por la limpieza de temporales) | no: «la configuración en paralelo no es correcta» |
| Python 3.10, 3.11 y 3.13 locales | sin el módulo `bpy` | — |

No se descargó ni se instaló nada (DISEÑO 13: «No descargar nada sin permiso (… Blender …)»).

## 1. Qué se entrega

- **`tools/create_models.py`**: solo se **agregaron** funciones al final, antes de `main()` (803 líneas nuevas, ninguna existente cambiada). Están el sistema de materiales `hx_*`, nueve constructores y su registro en `BUILDERS` y `NOTES` con `BUILDERS.update(...)` / `NOTES.update(...)`. Con `--only hx_...` no se reconstruye ni se toca ningún GLB anterior. El manifiesto se fusiona como siempre.
- **Prueba en seco sin Blender** (fuera del repo, en `qa-equipo/p6/`): `herramientas/hx_preview.py` ejecuta el `create_models.py` real con las primitivas de `bpy` (cubo, cono, esfera, toro, icosfera, malla) reemplazadas por un registrador numpy. Corre **los constructores y los generadores de texturas verdaderos** y escribe GLB *proxy* (color de vértice, normales planas, sin texturas PBR, sin biseles). `herramientas/hx_render.gd` los carga en Godot 4.7.2 con `GLTFDocument` (sin importarlos al proyecto), cuenta triángulos y superficies y saca renders con ventana real. **Los proxy son solo evidencia de revisión: no van a `assets/` ni al juego.**

## 2. Los modelos

Medidas en metros y en ejes de Godot (X ancho, Y alto, Z fondo). Triángulos y superficies **del proxy** contados por Godot. El GLB de Blender va a tener **+1 superficie** (la esfera ancla de 2 mm que exige el importador, ver ASSETS) y unos 30 a 60 triángulos más por los biseles del cimiento y la esfera ancla. **Peso en disco: no medido.** Por las texturas de 256 px de los otros modelos, estimo de 0,3 a 0,6 MB cada uno; se mide al generarlos.

| Modelo (`res://assets/models/…`) | Qué es | Tamaño X × Y × Z (m) | Triángulos | Superficies (proxy → GLB) | Materiales (clases) |
|---|---|---|---|---|---|
| `hx_casa_adobe.glb` | Casa baja de adobe 6 × 4 m: cimiento de piedra, muros de 0,55 m, techo plano de torta de barro y paja con caída a la calle, pretil en tres lados, rollizos asomados, puerta baja de tablas con dintel, ventanita con barrotes y postigo | 6,10 × 3,25 × 4,51 | 548 | 5 → 6 | piedra, adobe, torta, madera, tablas |
| `hx_casa_adobe_grande.glb` | Variante 10 × 5 m con ramada de horcones y cañizo al frente, dos puertas (una entornada, con interior en sombra) y dos ventanas | 10,10 × 3,40 × 7,61 | 1 088 | 6 → 7 | + paja |
| `hx_capilla.glb` | Capilla de adobe encalado, nave 6,4 × 13 m, techo a dos aguas de torta, hastiales con pretil, contrafuertes ataludados, portada de adobe saliente con puertas de tablas, ventana del coro y **espadaña de dos campanas** con cruz de madera. **Alto total 7,90 m** (todo el AABB queda por debajo de 8 m) | 8,10 × 7,90 × 13,58 | 764 | 6 → 7 | piedra, cal, torta, madera, tablas, bronce |
| `hx_tapia.glb` | Tramo de **tapial de 4 m** (en X), 2,0 m de alto, 0,55 m al pie y 0,45 m arriba, tongadas de 50 cm con mechinales en la textura, remate de paja y barro. Extremos a escuadra para repetir | 4,00 × 2,21 × 0,68 | 132 | 2 → 3 | tapial, paja |
| `hx_corral.glb` | **Corral de pirca** (piedra seca) 10 × 10 m, 1,15 m de alto, muro ataludado y cresta despareja, piedras de coronamiento, tranquera de tres palos al frente | 10,76 × 1,42 × 10,76 | 2 056 | 3 → 4 | pirca, piedra, madera |
| `hx_pirca.glb` | Tramo recto de **pirca de 4 m** (en X), la misma del corral, para repetir; sin piedra de remate sobre las juntas | 4,00 × 1,31 × 0,77 | 208 | 2 → 3 | pirca, piedra |
| `hx_pieza_artilleria.glb` | **Cañón de campaña** liviano (tubo de 1,6 m, del tamaño de uno «de a 4») en cureña de gualderas con contera en el suelo, ruedas de 1,35 m con doce rayos y llanta de hierro, teleras, cuña de puntería, atacador y lanada | 1,86 × 1,35 × 3,10 | 2 044 | 3 → 4 | madera, hierro, lana |
| `hx_brasero.glb` | Brasero de hierro sobre tres patas, aro, asas, brasas **emisivas** y dos tizones | 0,98 × 0,91 × 0,83 | 1 000 | 3 → 4 | hierro, brasas (emisión), madera |
| `hx_fogon.glb` | Fogón de guardia: cama de ceniza, nueve piedras en anillo, cinco leños hacia el centro (tiznados por color de vértice) y brasas **emisivas** | 1,57 × 0,23 × 1,52 | 464 | 3 → 4 | piedra, madera, brasas (emisión) |

Presupuesto: ninguna pieza pasa de 2 100 triángulos ni de 7 superficies (la casa colonial vieja tiene ~9). Para 120 casas del núcleo conviene `MultiMeshInstance3D` por modelo (ver 4).

## 3. Materiales y paleta

- **Colores:** los 24 HEX de la lámina 06 se leen al correr el script desde `data/humahuaca_visual.json → palette` (no se copian) y se pasan a albedo lineal. Usos: `adobe` en los muros, `cal_envejecida` en la capilla, `paja` mezclada con `suelo_seco` en techos de torta, `paja` en remates y ramada, `suelo_seco` mezclado con `adobe` en el tapial, `piedra_gris` en cimientos, pirca y fogón (con un poco de `churqui` como liquen), `madera_oscura` en puertas, rollizos, cureña y cruz, `hierro` en el cañón y el brasero, `oro_laton` oscurecido en las campanas, `lana_parda` en la lanada y `sedimento_humedo` como tinte del barro al pie de los muros. **Ningún color fuera de la lámina**, salvo el negro del interior en sombra de los vanos y el carbón de las brasas.
- **Clases nuevas** (solo las usan los modelos `hx_*`): `hx_adobe` (bloques de 40 × 13 cm con juntas de barro y restos de revoque), `hx_tapial` (tongadas de 50 cm, junta del cajón, mechinales, guijarros), `hx_cal` (encalado con chorreaduras y descascarado; su albedo medio es más alto porque `#E4DDCA` no se alcanza con la media común de 0,62), `hx_torta` (barro y paja picada, grietas), `hx_paja` (fibras), `hx_pirca` (piedras planas tipo Voronoi con juntas oscuras), `hx_hierro` (fundición áspera, medio metálica para que se lea de noche) y `hx_brasa` (carbón con mapa de emisión naranja). Todas son procedurales con numpy, de 256 px (las brasas, de 128). Hoja de muestra: `qa-equipo/p6/proxy_glb/texturas_hoja.png`.
- **Mismo sistema que el resto:** color por vértice (`COLOR_0`) que multiplica la textura de la clase; una superficie por clase; esfera ancla al principio. Pie de los muros oscurecido y entibiado hacia el barro (salpicadura de lluvia) en casas, tapia y capilla.
- **Etiqueta honesta:** todo es **reconstrucción artística propia**: «diseño» para planta, medidas y detalles, «razonado» para el tipo de casa de la quebrada (adobe, torta de barro sobre rollizos y cañizo, pretil) y para la pieza de campaña. No hay planos ni relevamientos de Humahuaca en 1817 detrás de estas formas.

## 4. Cómo instanciarlos (para P2)

- **Ruta:** `res://assets/models/<nombre>.glb` (`load(...)` → `PackedScene.instantiate()`). La malla viene unida en un solo nodo `<nombre>_geometry`.
- **Escala:** 1 unidad = 1 m; se instancian a escala 1. Tapia y pirca admiten escala no uniforme moderada en Y (tapia de 1,8 a 2,4 m: `scale.y` de 0,9 a 1,2).
- **Punto de apoyo:** el origen está **en el suelo, en el centro de la huella** (AABB centrado en X y Z, Y mínimo = 0; lo que quedaba bajo tierra se aplanó a Y = 0). Se apoya con `position.y = height_at(x, z)`. Con pendiente, la casa grande y la capilla conviene apoyarlas en la altura mínima de las cuatro esquinas: el cimiento y el zócalo de piedra (0,30 y 0,35 m) absorben el desnivel.
- **Orientación:** el **frente mira a −Z de Godot**: puerta y ventana de las casas, portada y espadaña de la capilla, tranquera del corral, boca del cañón. Así `look_at(objetivo)` apunta el frente al objetivo. **Ojo:** la `house_colonial.glb` vieja tiene la puerta hacia +Z; las `hx_*` siguen la convención de ASSETS («frente en −Z»).
- **Módulos repetibles:** `hx_tapia` y `hx_pirca` miden **4,00 m exactos en X** con extremos a escuadra. Para un tramo de A a B: `n = ceil(dist / 4)`, escala X = `dist / (4 n)`, rotación `atan2` del tramo, y un módulo cada `4 · escala` m. La textura no casa en la junta (cada módulo tiene su desfase de UV), lo que se lee como juntas de cajón o de pirca.
- **Cañón:** el eje de las ruedas queda en **Z = −0,53** desde el origen (el origen es el centro de la huella, no el eje), la boca en Z ≈ −1,55 y la contera en Z = +1,55. Boca a 1,01 m de alto, elevación de 2,5°. Para girarlo sobre el eje: `pivot.position.z = -0.53`.
- **Luces:** el brasero y el fogón traen **emisión** (`emission_enabled` en el material de brasas) pero no luz. Anclas sugeridas de la `OmniLight3D` cálida: **brasero, Y = 1,4 m** (sobre el borde; más abajo el cuenco proyecta un disco de sombra de ~1 m: si molesta, luz sin sombra); **fogón, Y = 0,6 m**.
- **Muchas copias:** la casa chica tiene 548 triángulos; 120 casas suman ~66 mil. Va con `MultiMeshInstance3D` (una por modelo y por superficie) o con instancias que compartan la malla. Sin LOD.
- **Vertex color:** como en todos los GLB del proyecto, Godot 4.7.2 activa `vertex_color_use_as_albedo` en todas las superficies menos la primera, y la primera es la esfera ancla. No quitarla.

## 5. Verificación hecha y la que falta

**Hecha (sin Blender, con proxy):**
- Los nueve constructores corren completos sobre el `create_models.py` real (sin errores de Python), con los generadores de texturas verdaderos.
- Godot 4.7.2 carga los nueve proxy por `GLTFDocument` sin errores. Cuenta triángulos, superficies y AABB (tabla 2) y ve color de vértice y emisión en las brasas.
- Renders con ventana real (RTX 3080 Ti, Forward+), 1440 × 900, en `qa-equipo/p6/`:
  - `proxy_noche.png`: los nueve juntos, luna fría `#A9B8E8`, ambiente `#2C2A4A`, niebla y dos luces cálidas `#FFB25A` en el brasero y el fogón (la luz de la dirección de arte B1).
  - `proxy_dia.png`: la misma disposición con sol a 35°.
  - `proxy_detalle.png`: grilla 3 × 3 con los frentes hacia la cámara.
  - `proxy_chicos.png`: primer plano del cañón, el brasero, el fogón, la tapia y la pirca.

**Crítica honesta de lo que se ve (proxy: sin texturas ni biseles, normales planas):**
- *Se leen bien:* la capilla, por la espadaña con las dos campanas y la cruz, la portada oscura y los contrafuertes. A 40–60 m es lo más reconocible y no tiene torres (respeta «sin torres de 1880»; igual no es el templo de Humahuaca). La casa grande se lee por la ramada y sus horcones. El cañón tiene silueta inequívoca (ruedas de rayos, cureña larga, tubo con brocal). El fogón y el brasero se leen por la luz.
- *Flojo:* la casa chica de lejos es una caja con tapa: lo que la distingue de la caja de hoy son el pretil, el vano oscuro y la sombra del alero de torta. Los rollizos no se ven a más de ~25 m. La tapia y la pirca en proxy son bloques lisos: su lectura depende de las texturas (tongadas, piedras), que el proxy no tiene. La cresta de la pirca ya se hizo más despareja después de la primera vuelta.
- *Coherencia 1817:* nada anacrónico a la vista (sin chapas, vidrios, postes ni teja industrial; techos de torta y paja, carpintería de madera, hierro solo en el cañón y el brasero). El cañón es genérico de fines del siglo XVIII. En 1817 las piezas de campaña españolas solían ser de **bronce**; acá se usó el `hierro` de la lámina porque es el color que la paleta asigna a «cañones». Si se prefiere bronce, se cambia una línea (`hx_col("oro_laton", .6)`).
- *Paleta:* todo sale de la lámina 06. La capilla en `cal_envejecida` es lo más claro de la escena, que es lo que pide el diseño (encalado = templo). De noche no quema como las cajas blancas de hoy porque la cal tiene su textura y el pie sucio.

**Falta (cuando haya Blender):**
1. Generar los GLB reales (sección 6) y repetir con ellos la importación del proyecto: `Godot_v4.7.2-stable_win64_console.exe --headless --path . --import` con `APPDATA` aislado.
2. Correr `qa-equipo/p6/herramientas/hx_render.gd` **sin** el tercer argumento (así carga los `res://` importados) en los modos `stats`, `noche`, `dia`, `detalle` y `chicos`. Comparar con los `proxy_*.png` y con esta tabla, y medir el peso en disco y los triángulos reales (con biseles y esfera ancla).
3. Mirar las texturas reales de cerca (proyección por caja: costuras en piezas redondas) y ajustar la intensidad de las juntas del adobe y de la pirca a 40–60 m.
4. Recién entonces sumar una línea por modelo en `docs/ASSETS.md` y `docs/CREDITOS.md` (texto propuesto en 7). **No se agregaron todavía**, para no acreditar archivos que no existen.

## 6. Cómo generarlos

Desde la raíz del repo, con Blender 4.4.x:

```sh
blender --background --factory-startup --python tools/create_models.py -- --only hx_casa_adobe,hx_casa_adobe_grande,hx_capilla,hx_tapia,hx_corral,hx_pirca,hx_pieza_artilleria,hx_brasero,hx_fogon
```

Escribe `assets/models/hx_*.glb` y agrega sus nueve entradas a `assets/models/model_manifest.json` (bytes, SHA-256, triángulos, superficies, límites y una nota histórica). Revisar con `git diff assets/models/model_manifest.json` que solo se sumen entradas `hx_*`. Las texturas van embebidas en el GLB; los `*_alb_*.jpg` que extrae Godot al importar ya están en `.gitignore`. Un detalle: la ADDENDA A-01 del nivel II decía «Blender no está autorizado». Esta pista existe porque el usuario cambió esa decisión (Blender para modelar y exportar, Godot como motor). Convendría que P2 o el líder lo anoten en `docs/humahuaca/VISUAL.md` y `CREDITOS_VISUAL.md` al integrar.

## 7. Texto propuesto para ASSETS y CREDITOS (cuando existan los GLB)

> `assets/models/hx_casa_adobe.glb`, `hx_casa_adobe_grande.glb`, `hx_capilla.glb`, `hx_tapia.glb`, `hx_corral.glb`, `hx_pirca.glb`, `hx_pieza_artilleria.glb`, `hx_brasero.glb`, `hx_fogon.glb` · Modelado procedural original del proyecto (pista P6), generado con `tools/create_models.py` en Blender 4.4 en línea de comandos, con texturas procedurales propias (numpy) y colores de la lámina 06. Sin descargas ni modelos de terceros ni IA. Recurso original de esta entrega. **Reconstrucción artística** de casas, capilla, tapial, pirca, pieza de campaña y fuegos de la quebrada hacia 1817 («diseño» y «razonado»): no reproduce edificios ni piezas documentadas de Humahuaca.
