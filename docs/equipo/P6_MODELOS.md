# P6 · Modelos 3D propios para el nivel II «Humahuaca»

Pista P6 del equipo (BACKLOG: «P6 entrega GLB nuevos que integra P2»). Fecha: 2026-11-08. Base: `equipo/integracion` (70b2341).

## Estado

**Nueve GLB jugables en `assets/models/hx_*.glb`, importados por Godot 4.7.2 sin errores.** Los generó `tools/hx_models_sin_blender.py`, un exportador en numpy que corre **los mismos constructores** `hx_*` de `tools/create_models.py` sin Blender. Es la variante **sin texturas PBR**: el color va por vértice.

Por qué sin Blender: en esta PC no hay un Blender que funcione (comprobado el 2026-11-08):
- en `C:/Program Files/Blender Foundation/Blender 4.4/` solo quedan `python/` y `scripts/`, sin `blender.exe`;
- el portable 4.4.3 de `%TEMP%/bl443/` tiene vacío `blender.shared/` y no arranca;
- ningún Python local tiene `bpy`.

El lead decidió no pedir la descarga y promover el exportador a herramienta del repo. No se descargó ni se instaló nada.

Cuando haya Blender, la variante **con texturas PBR** sale del mismo código, con estos mismos nombres de archivo:

```sh
blender --background --factory-startup --python tools/create_models.py -- --only hx_casa_adobe,hx_casa_adobe_grande,hx_capilla,hx_tapia,hx_corral,hx_pirca,hx_pieza_artilleria,hx_brasero,hx_fogon
```

Esa variante no se probó nunca con Blender real: solo corrió en seco con el reemplazo en numpy. Su tabla de triángulos va a diferir un poco (sin bisel por clase y con biseles de Blender en el cimiento).

## 1. Qué se entrega

| Archivo | Qué es |
|---|---|
| `tools/create_models.py` | Solo **funciones agregadas** antes de `main()`, ninguna existente cambiada: clases de material `hx_*`, nueve constructores y `BUILDERS.update(...)` / `NOTES.update(...)`. Con `--only hx_...` no toca ningún GLB anterior |
| `tools/hx_models_sin_blender.py` | Exportador sin Blender (requiere solo numpy). `python tools/hx_models_sin_blender.py [--only a,b]`. Escribe `assets/models/hx_*.glb` y fusiona sus entradas en `model_manifest.json` (solo agrega claves `hx_*`) |
| `assets/models/hx_*.glb` (+ `.import`) | Los nueve modelos |
| `assets/models/model_manifest.json` | Nueve entradas nuevas: bytes, SHA-256, triángulos, superficies, límites, procedencia y nota histórica |
| `docs/ASSETS.md`, `docs/CREDITOS.md` | Una línea por modelo, con la etiqueta honesta |

Herramientas de verificación (fuera del repo): `qa-equipo/p6/herramientas/hx_render.gd` carga los GLB importados, cuenta y saca renders.

### Qué hace el exportador sin Blender

- Primitivas equivalentes a las de `bpy`: cubo, cono, esfera UV, toro, icosfera y malla libre. Los constructores no cambian.
- **Bisel** de 6 cm en las cajas de adobe, 5 cm en la cal, 3,5 cm en la torta, 3 cm en la piedra y 2 cm en la paja: chaflán real de 12 caras más 8 esquinas, solo en piezas de al menos 6 cm. Tapial y pirca no llevan, porque los módulos se apoyan uno contra otro.
- **Normales suavizadas por ángulo**: 50° en general (los chaflanes se funden con las caras y el adobe queda de canto blando); 25° en la piedra y 12° en la pirca, que quedan facetadas.
- **Variación de color que imita la textura**:
  - tapial: subdividido en filas de 25 cm, con tongadas de 50 cm más claras arriba que abajo y tono propio por tongada;
  - pirca: subdividida en celdas de ~30 cm con tono propio y el centro abultado hacia afuera, que forman piedras;
  - piedra, torta, adobe y madera: variación leve por cara;
  - todo, además, sobre el oscurecido del pie de los muros que ya ponen los constructores.
- Esfera ancla de 2 mm como **primera primitiva**, igual que en los GLB de Blender: con ella Godot activa `vertex_color_use_as_albedo` en todas las demás superficies (comprobado: solo el ancla queda en `vc=false`).
- Emisión naranja (`emissiveFactor`) en el material de brasas.
- Vértices deduplicados con índices.

## 2. Tabla de modelos (medida en Godot sobre los GLB importados)

Ejes de Godot (X ancho, Y alto, Z fondo). Triángulos y superficies contados por `hx_render.gd` en las mallas importadas; incluyen la esfera ancla (6 triángulos y 1 superficie).

| Modelo (`res://assets/models/…`) | Qué es | Tamaño X × Y × Z (m) | Triángulos | Superficies | Peso |
|---|---|---|---|---|---|
| `hx_casa_adobe.glb` | Casa baja de adobe 6 × 4 m: cimiento de piedra, techo plano de torta con caída al frente, pretil, rollizos, puerta baja y ventanita con barrotes | 6,10 × 3,25 × 4,51 | 1 226 | 6 | 164 KB |
| `hx_casa_adobe_grande.glb` | Casa 10 × 5 m con ramada de horcones y cañizo, dos puertas (una entornada) y dos ventanas | 10,10 × 3,40 × 7,61 | 2 054 | 7 | 272 KB |
| `hx_capilla.glb` | Capilla de adobe encalado, nave 6,4 × 13 m, techo de torta a dos aguas, hastiales con pretil, contrafuertes, portada y espadaña de dos campanas con cruz. **Alto 7,90 m** | 8,08 × 7,90 × 13,58 | 1 442 | 7 | 171 KB |
| `hx_tapia.glb` | Tramo de tapial de **4,00 m en X**, 2,0 m de alto, tongadas y remate de paja | 4,00 × 2,21 × 0,68 | 306 | 3 | 42 KB |
| `hx_corral.glb` | Corral de pirca 10 × 10 m, 1,15 m de alto, tranquera de tres palos al frente | 10,77 × 1,42 × 10,77 | 5 528 | 4 | 717 KB |
| `hx_pirca.glb` | Tramo recto de pirca de **4,00 m en X** | 4,00 × 1,31 × 0,77 | 586 | 3 | 79 KB |
| `hx_pieza_artilleria.glb` | Cañón de campaña liviano (tubo de **bronce** de 1,6 m) en cureña de gualderas, ruedas de rayos de 1,35 m, atacador y lanada | 1,86 × 1,35 × 3,10 | 2 050 | 4 | 178 KB |
| `hx_brasero.glb` | Brasero de hierro de tres patas, brasas emisivas, tizones | 0,98 × 0,91 × 0,83 | 1 006 | 4 | 62 KB |
| `hx_fogon.glb` | Fogón de guardia: ceniza, nueve piedras, cinco leños, brasas emisivas | 1,57 × 0,23 × 1,52 | 470 | 4 | 58 KB |

**Presupuesto:** hasta 7 superficies por modelo. La casa chica tiene 1 226 triángulos (el bisel cuesta unos 650); 120 casas del núcleo sumarían ~147 mil. No se midieron FPS. Si la calidad «baja» lo necesita, quitar `hx_adobe` de `CHAMFER` en el exportador deja la casa en ~560 triángulos. El corral (5,5 mil) es el más pesado por la subdivisión de la pirca: usar pocos.

## 3. Cómo instanciarlos (para P2)

- **Ruta:** `res://assets/models/<nombre>.glb` → `load(...).instantiate()`. Una sola malla, `<nombre>_geometry`.
- **Escala:** 1 unidad = 1 m, escala 1. Tapia y pirca admiten escala moderada en Y (tapia de 1,8 a 2,4 m: `scale.y` de 0,9 a 1,2).
- **Punto de apoyo:** el origen está **en el suelo, en el centro de la huella** (AABB centrado en X y Z, Y mínimo = 0). Se apoya con `position.y = height_at(x, z)`. En pendiente, casas y capilla se apoyan en la altura mínima de las cuatro esquinas: el cimiento de piedra (0,30 m) y el zócalo (0,35 m) absorben el desnivel.
- **Orientación:** el **frente mira a −Z de Godot**: puertas y ventanas, portada y espadaña, tranquera, boca del cañón. Así `look_at(objetivo)` apunta el frente al objetivo. La `house_colonial.glb` vieja tiene la puerta hacia +Z; las `hx_*` siguen la convención de ASSETS.
- **Módulos repetibles:** `hx_tapia` y `hx_pirca` miden 4,00 m exactos en X con extremos a escuadra. Para un tramo de A a B: `n = ceil(dist / 4)`, `scale.x = dist / (4 n)`, rumbo del tramo, un módulo cada `4 · scale.x` m.
- **Cañón:** el eje de las ruedas queda en **Z = −0,53** desde el origen, la boca en Z ≈ −1,55 y a 1,01 m de alto, y la contera en Z = +1,55. Para girarlo sobre el eje, el pivote va en `z = -0.53`.
- **Luces:** el brasero y el fogón traen emisión pero no luz. Anclas sugeridas de la `OmniLight3D` cálida: **brasero, Y = 1,4 m** (el cuenco proyecta igual un disco de sombra de ~1 m; si molesta, luz sin sombra); **fogón, Y = 0,6 m**.
- **Muchas copias:** `MultiMeshInstance3D` por modelo, o instancias que compartan la malla. Sin LOD.
- **No quitar la esfera ancla** (primera superficie, material `PBR | anchor`).

## 4. Materiales y paleta

- **Colores de la lámina 06** (`data/humahuaca_visual.json → palette`), leídos al correr y pasados a albedo lineal:
  - `adobe`: muros;
  - `cal_envejecida`: capilla;
  - `paja` con `suelo_seco`: torta de los techos;
  - `paja`: remates y ramada;
  - `suelo_seco` con `adobe`: tapial;
  - `piedra_gris`: cimientos, pirca y fogón, con algo de `churqui` como liquen;
  - `madera_oscura`: carpintería, cureña y cruz;
  - `hierro`: herrajes y brasero;
  - `oro_laton` oscurecido: campanas;
  - `lana_parda`: lanada;
  - `sedimento_humedo`: barro al pie de los muros.
- **Excepción deliberada:** el tubo del cañón es de **bronce con pátina** (`oro_laton` mezclado con `verde_elegido`, al 45 %), aunque la lámina asigna «hierro» a los cañones. Las piezas de campaña españolas de la época solían ser de bronce. Para volver al hierro: una línea en `hx_pieza_artilleria` (`bronze = HxMat(..., hx_col("hierro"), ...)`).
- **Etiqueta:** reconstrucción artística propia, generada por código sin Blender (variante sin texturas PBR). Planta, medidas y detalles son «diseño»; el tipo de casa de la quebrada (adobe, torta de barro sobre rollizos y cañizo, pretil) y la pieza de campaña, «razonado». No reproducen edificios ni piezas documentadas de Humahuaca en 1817.

## 5. Verificación

- `python tools/hx_models_sin_blender.py`: los nueve se generan. `git diff assets/models/model_manifest.json` solo agrega líneas.
- `Godot_v4.7.2-stable_win64_console.exe --headless --path . --import` con `APPDATA` aislado (`%TEMP%/ap_iso_p6_x`): sale con código 0 e importa los nueve sin ninguna línea `ERROR:`.
- `hx_render.gd` (modo `stats`) sobre los `res://` importados da la tabla 2: vertex color activo en todas las superficies menos el ancla y emisión activa en las brasas.
- Renders con ventana real (RTX 3080 Ti, Forward+, 1440 × 900) en `qa-equipo/p6/`:
  - `hx_noche.png`: los nueve, luna `#A9B8E8`, ambiente `#2C2A4A`, niebla, luces `#FFB25A` en brasero y fogón;
  - `hx_dia.png`: sol a 35°;
  - `hx_detalle.png`: grilla 3 × 3 con los frentes a la cámara;
  - `hx_casas.png`: primer plano de las casas, la capilla y la tapia;
  - `hx_chicos.png`: cañón, brasero, fogón, tapia y pirca.

  Los `proxy_*.png` son la vuelta anterior, sin biseles ni dibujo.

**Crítica honesta:**
- **Mejoró respecto del proxy:** la casa chica dejó de ser «caja con tapa». Ahora tiene canto blando de adobe, pretil con borde, zócalo de piedra, vano oscuro de la puerta, ventanita con barrotes y, en la grande, la fila de rollizos y la ramada. La tapia muestra las tongadas y la pirca se lee como piedra seca facetada. El cañón de bronce con pátina se distingue de la cureña oscura.
- **Se lee bien a 40–60 m:** capilla (espadaña, campanas, cruz, portada), ramada, cañón, y los fuegos por su luz.
- **Flojo:**
  - sin texturas, los paños grandes de muro y de techo son lisos y de un solo tono;
  - los cortes de los muros alrededor de los vanos marcan juntas verticales leves (se leen como pilastras);
  - la ramada es una losa lisa;
  - el brasero se ve chico de lejos y depende de su luz;
  - la capilla es lo más claro de la escena; de noche no quema, pero de día compite con el suelo claro: el contraste lo da la sombra.
- **Coherencia con 1817:** sin chapas, vidrios, postes ni teja industrial. Techos de torta y paja, carpintería de madera, hierro solo en herrajes y brasero.

**Falta:** medir FPS con muchas casas (P2 o la pista de rendimiento) y la variante PBR con Blender cuando esté.
