# Recursos, procedencia y producción

## Recursos originales de esta entrega

Los modelos, sonidos, geometría de escenario y shaders indicados como propios se crearon para este proyecto. Se entregan para uso, modificación y distribución como parte del juego, sin recursos extraídos de Civilization VII ni muestras o modelos descargados de terceros. La licencia general del código del proyecto se aplica a sus scripts de generación; las fuentes tipográficas conservan sus licencias específicas.

| Recurso | Autor/procedencia | Licencia o permiso de uso | Modificaciones y función |
| --- | --- | --- | --- |
| `assets/models/rider_1806.glb` | Modelado procedural original del proyecto, generado mediante `tools/create_models.py` (fase 2: Blender 4.4.3). | Recurso original de esta entrega; uso, modificación y distribución con el proyecto. | Caballo con geometría continua de torso y cuello, extremidades articuladas, cabeza, orejas, crin, cola, cascos, ojos, brida, riendas, manta y montura. Jinete con casaca sobria, calzón claro, botas y bicornio. Animación `trot`. |
| `assets/models/rider_1817.glb` | Mismo proceso propio. | Igual que el anterior. | Variante de caballo y jinete con poncho granate, sombrero de ala y barba; sin insignias modernas. Animación `trot`. |
| `assets/models/horse_only.glb` | Misma geometría y aparejo propios que el caballo de 1806. | Recurso original de esta entrega. | Montura sin jinete para permanecer estacionada en la ribera durante el abordaje; animación `trot` disponible, que debe detenerse cuando el caballo está quieto. |
| `assets/models/infantry.glb` | Mismo proceso propio. | Igual que el anterior. | Soldado de casaca roja para la dotación británica de la Justina, con mosquete simplificado. Animación `walk`. |
| `assets/models/royalist_1817.glb` | Fase 2: malla propia generada por el mismo script (antes era una variante de material de la infantería). | Recurso original de esta entrega. | Figura agregada del ejército realista en 1817, de casaca blanco grisáceo y sin insignias británicas. Reconstrucción artística: no representa un uniforme regimental verificado. Animación `walk`. |
| `assets/models/dismounted_1806.glb` | Mismo proceso propio. | Igual que el anterior. | Variante a pie de casaca azul, para representar el abordaje después de dejar los caballos. Animación `walk`. |
| `assets/models/justine.glb` | Mismo proceso propio. | Igual que el anterior. | Mercante armado reconstruido: casco curvo, cubierta y cabina, dos mástiles, vergas, velas de malla, jarcia, barandas, escala de abordaje, carga y 26 portas sugeridas. Malla estática. |
| Terreno, casas coloniales, rocas, vegetación y agua | Geometría y materiales originales creados por el código de presentación del proyecto (`world_view.gd`). | Recursos originales de esta entrega. | Entornos generados para cada escenario. Relieve, rutas, costas y edificios son simplificaciones artísticas; no son escaneos arqueológicos. |
| `assets/audio/order.wav`, `error.wav`, `alert.wav`, `bell.wav` | Síntesis propia por `tools/generate_audio.py` (numpy/scipy). | Sonidos originales de esta entrega, sin muestras de terceros. | Orden aceptada (dos tonos con reverb), rechazo (dos golpes graves), toque de aviso (dos notas de metal sintético) y campana de ronda (parciales inarmónicos con batido). |
| `assets/audio/cannon.wav`, `hoof.wav`, `hoof2.wav`, `hoof3.wav`, `dismount.wav` | Mismo script. | Igual que el anterior. | Cañón en capas (chasquido, cuerpo, barrido grave, eco y cola); tres variantes de cascos al trote; desmontaje (botas, espuelas, resoplido). Diseño sonoro sintético, no grabaciones históricas. |
| `assets/audio/river.wav`, `ribera.wav`, `wind.wav`, `wind_north.wav` | Mismo script. | Igual que el anterior. | Ambientes estéreo en lazo de 10, 12, 12 y 15 s, construidos como señal periódica (fase aleatoria en frecuencia y moduladores de ciclos enteros), sin clic en la costura. Se superponen dos capas por escenario (Justina: río + ribera con grillos; Norte: viento + viento frío con silbido). |
| `assets/audio/victory.wav` | Mismo script. | Igual que el anterior. | Timbal y fanfarria de metal sintético con acorde sostenido. No incorpora composición ni grabación ajena. |

**Estado de evaluación:** los WAV se analizaron numéricamente (`tools/analyze_audio.py`, resultado en `evidence/fase2/audio/analisis_wav.txt`) y se reprodujeron con el driver real de Windows (WASAPI; el log `audio_runtime_log.txt` lo registra: «Driver de audio: WASAPI», latencia de salida 10 ms) en `tests/audio_runtime_test.gd`, que mide señal en los buses. **Nadie los ha escuchado todavía**: la evaluación auditiva humana (timbre, balance, fatiga, claridad de las alertas) sigue pendiente.

**Mezcla:** buses `Musica`, `Ambiente`, `Efectos` y `UI` creados en ejecución por `audio_manager.gd`, con limitador (`AudioEffectHardLimiter`, techo −1 dB) en Master. Variación de tono por reproducción, variantes de cascos, polifonía por efecto (cañón 2, resto 1–2) y tope de 6 voces: sobre el tope se descartan los efectos de prioridad baja. Las alertas (`alert`, `bell`, `error`, `victory`) nunca se descartan por el tope.

**Enlazado en `main.gd`** (integración 963c3a5): `alert` ante amenazas, `bell` al resolver una ronda del Norte y `dismount` al pasar la agrupación a la etapa `dismounting`. `ribera.wav` y `wind_north.wav` suenan por `set_environment`. Corrección posterior: `play()` ya no reasigna el stream mientras el reproductor suena; antes lo hacía y cortaba la voz anterior, con lo que la polifonía 2 del cañón no funcionaba. El tope de 6 cuenta reproductores, no voces: con polifonía el recuento puede superar 6 (el test tolera `MAX_VOICES + 3` y llegó a 7).

## Tipografías de terceros

| Archivo | Autor y fuente | Licencia | Estado |
| --- | --- | --- | --- |
| `assets/fonts/Cinzel.ttf` | The Cinzel Project Authors; [proyecto](https://github.com/NDISCOVER/Cinzel), distribuido por [google/fonts, ofl/cinzel](https://github.com/google/fonts/tree/main/ofl/cinzel). | SIL Open Font License 1.1, incluida íntegramente en `assets/fonts/Cinzel-OFL.txt`. | Fuente descargada por el desarrollo; sin modificación del diseño tipográfico. |
| `assets/fonts/Inter.ttf` | The Inter Project Authors; [proyecto](https://github.com/rsms/inter), distribuido por [google/fonts, ofl/inter](https://github.com/google/fonts/tree/main/ofl/inter). | SIL Open Font License 1.1, incluida íntegramente en `assets/fonts/Inter-OFL.txt`. | Fuente descargada por el desarrollo; sin modificación del diseño tipográfico. |

Se inspeccionaron los avisos de autoría y licencia incluidos. Esas licencias deben acompañar la distribución. El origen `main` identifica la rama de descarga; no se presenta como una versión de fuente fijada por etiqueta.

## Fase 2 (pista ARTE): materiales PBR procedurales y modelos nuevos

Todo es propio y generado por `tools/create_models.py` (Blender 4.4.3 en línea de comandos + numpy; sin descargas de assets, sin recursos de Civilization VII). Licencia: la misma de los recursos originales de la entrega.

- **Texturas.** Cada GLB lleva texturas PBR procedurales (albedo + normal + rugosidad/metal, JPEG calidad 88, embebidas): tejido de lana (sarga) y lino, cuero, madera, tablazón de casco y cubierta, pelo de caballo, piel, metal, lona con costuras, revoque, teja, corteza, follaje, piedra y cardón. El color de cada pieza va en el atributo de vértice `COLOR_0`, que multiplica la textura. Resultado: 7-9 superficies por modelo (0.1.0 tenía 16-17 en los jinetes).
- **Importante para Godot 4.7.2.** El importador glTF no activa `vertex_color_use_as_albedo` en la primera primitiva de una malla (comprobado en el motor). Cada GLB empieza por una esfera de 2 mm con un material propio (`PBR | anchor`) para absorber ese defecto. No eliminarla sin repetir la prueba.
- **Jinetes y caballo.** Más masa muscular (pecho, grupa, flanco, cruz), crin y flequillo en mechones, cola más densa, aparejo (pretal, baticola), sombreado de color en el vientre y las patas, estrella y dos calzados blancos en el caballo de 1806. Animación `trot` conservada (mismos huesos y nombre) con balanceo del jinete, giro de cuello y cabeza y oscilación de cola.
  - 1806: casaca con cuello y puños de vuelta, hombreras, cartuchera, pistolera, espuelas, bicornio con escarapela roja lisa. **Sin bandera argentina, sin escarapela celeste y blanca, sin Infernales.**
  - 1817: sombrero, poncho granate con cuello, pañuelo, pellón de oveja sobre el recado, lazo, boleadoras, rebenque. Sin insignias de unidad.
- **Infantería.** `infantry` (dotación británica de la Justina): shako cilíndrico liso, mochila, manta, cartucheras, bayoneta. `royalist_1817`: ahora una **malla propia** de casaca blanco grisácea con vueltas azules y chacó de lata lisa (ya no es una variante de material del GLB británico). `dismounted_1806`: casaca azul, bicornio, sable. Animación `walk` conservada, con giro de hombros y cabeceo.
- **Justina.** Casco y cubierta con tablazón, velas de lona con costuras y suciedad, timón, cabrestante, ancla, cadenas de obenques, faroles y barandilla de popa, timón de popa, rizos de vela, fardos y rollos de cabo. Mantiene 26 portas. Sin bandera ni insignia nacional.
- **Modelos nuevos, todavía sin referenciar por `world_view.gd`** (la integración corresponde a quien posea ese archivo): `house_colonial.glb` (planta 5,0 x 4,0 m, alto de muro 2,7 m, puerta hacia +Z de Godot, galería y teja), `church_colonial.glb` (nave 6 x 11 m, campanario frontal hasta unos 12,9 m, capilla andina genérica, no una iglesia concreta), `tree_algarrobo.glb` (unos 6,3 m), `tree_cardon.glb` (unos 4,4 m) y `rock_cluster.glb` (unos 2,5 m). Origen en la base, metros, frente en -Z. Para usarlos en `_house`/`_tree` basta instanciar el GLB y escalar el nodo; para muchas copias conviene MultiMesh o instancias compartidas.
- **Presupuesto.** Triángulos de malla base: jinete 17,4 mil (0.1.0: 12,9 mil), infantería 5,8-6,1 mil, Justina 27 mil. Más triángulos por figura pero la mitad de superficies; **no se midieron FPS** con estos modelos. El informe de auditoría señala las figuras con piel como costo dominante, así que la pista de rendimiento puede necesitar reducir la geometría (por ejemplo, menos mechones de crin o niveles de detalle).
- **Cómo regenerar.** `blender --background --factory-startup --python tools/create_models.py` (todo) o `... -- --only rider_1806,justine` (solo esos; el manifiesto se fusiona). Ya no existe `--only-royalist`.
- **Nombres.** No cambió ningún nombre de archivo ni de animación (`trot`, `walk`). Los nodos internos son los de Blender/glTF (malla unida `<nombre>_geometry`, esqueleto y `AnimationPlayer`); `world_view.gd` los busca por tipo.
- **Archivos extraídos por Godot.** Al importar, Godot 4.7 deja junto a cada GLB archivos `*_alb_*.jpg`, `*_nor_*.jpg` y `*_rm_*.jpg`; son derivados del importador, no se versionan.

### Qué sigue provisional

- Proporciones de caballo y persona aún estilizadas (extremidades tubulares, manos y rostro simples, sin dedos ni expresión).
- Texturas procedurales de 256-512 px: dan relieve y variación, no detalle fotográfico. La proyección es por caja, con costuras visibles de cerca en piezas redondas.
- Uniformes y ropas son interpretaciones; el color del poncho y las vueltas no están verificados para ninguna unidad.
- Casa, iglesia, algarrobo, cardón y roca (`house_colonial`, `church_colonial`, `tree_algarrobo`, `tree_cardon`, `rock_cluster`) están versionados y registrados en el manifiesto, pero `world_view.gd` no los usa: **no están en el juego**; el terreno y la hierba siguen siendo geometría de `world_view.gd`.
- Sin LOD, sin impostores, sin mediciones de rendimiento con la geometría nueva.
- Comprobación visual hecha con el visor `evidence/fase2/arte/viewer.gd` y las capturas del juego en `evidence/fase2/arte/`; no se probó en GPU integrada.

## Contrato de importación de los modelos

- Formato GLB 2.0 autocontenido, materiales PBR de color y rugosidad, sin texturas externas ni rutas absolutas.
- Metros como unidad de diseño. Frente en **−Z de Godot**, altura en **Y**. Blender usa +Y hacia delante y Z hacia arriba; el exportador realiza la transformación.
- Los jinetes miden aproximadamente 3.0 m de altura total con caballo. Los soldados a pie miden aproximadamente 1.94 m con bicornio. La escala artística no permite inferir la talla real de Güemes.
- El casco de la Justina ocupa unos 14 m de eslora; el bauprés amplía la longitud total a unos 16.6 m. Manga de casco aproximada 5 m; cañones salientes amplían el ancho total. Cubierta central en Y≈3.5 m, quilla por debajo de Y=0; el origen corresponde a la referencia de agua.
- Se consolidaron las piezas en una malla por asset, conservando materiales y pesos de esqueleto. Esto evita cientos de nodos de dibujo por unidad; no equivale a una medición de FPS.
- `trot` y `walk` duran 1 segundo a 24 FPS. El script define fotogramas cíclicos. **glTF no transporta una propiedad universal de repetición**: en Godot, el integrador debe establecer `Animation.LOOP_LINEAR` antes de reproducir la animación.
- `assets/models/model_manifest.json` registra nombres de animación comprobados dentro del GLB, bytes, SHA-256, triángulos base, número de superficies y límites geométricos. Los límites no sustituyen las colisiones o zonas de selección del juego.

## Reproducción

Desde la carpeta del proyecto, con Blender 4.4.3 (versión de la fase 2) o compatible disponible; la ruta local en esta PC es `C:/Program Files/Blender Foundation/Blender 4.4`:

```sh
blender --background --factory-startup --python tools/create_models.py
```

En Windows se puede reemplazar `blender` por la ruta local de `blender.exe`. El script no necesita red, cuentas, assets externos ni complementos comunitarios: utiliza la API Python y el exportador glTF incluido en Blender. Se deben conservar los nombres de archivo usados por el juego.

Para regenerar solo algunos modelos: `blender --background --factory-startup --python tools/create_models.py -- --only rider_1806,justine` (ver la sección de la fase 2).

Los catorce WAV se reconstruyen con Python, NumPy y SciPy:

```sh
python tools/generate_audio.py
```

Blender, Python, NumPy y SciPy son herramientas de desarrollo. El ejecutable del jugador utiliza los GLB y WAV ya generados.

## Verificación y límites visuales

Versión 0.1.0: se ejecutó Blender 4.0.2 en Linux remoto y se exportaron seis GLB; el séptimo, `royalist_1817.glb`, fue entonces una variante de materiales de la infantería. En la fase 2 se regeneró todo con Blender 4.4.3 y `royalist_1817` pasó a ser una malla propia (12 GLB en total, ver la tabla y la sección de la fase 2). Lo que sigue describe la verificación de 0.1.0. Se analizaron las cabeceras JSON para verificar las animaciones y superficies; la variante conserva intactos los buffers de geometría y la animación del original. Se volvieron a importar los GLB de los dos jinetes y del barco en Blender y se inspeccionaron renders reales de esos archivos. Se ajustaron normales de malla, transición de hombros, forma de los cascos y el poncho tras la revisión. Las pruebas de importación en Godot, interacción y rendimiento pertenecen al informe de QA de la versión.

La dirección es **3D de detalle medio con estilización visible**. Hay siluetas y equipamiento reconocibles, rig y articulaciones, materiales naturales de color y geometría propia. No son personajes fotogramétricos, reconstrucciones arqueológicas ni assets de fidelidad cinematográfica demostrada. Los uniformes son interpretaciones de época: no se verificó un uniforme individual de cada personaje. El modelo del barco no reproduce un plano original; la descripción de mercante y la referencia a 26 cañones proceden del testimonio reproducido en el *Ideario*, p. 390.

No se distribuyen en los modelos banderas argentinas en 1806, nombres de Infernales para esa misión, el nombre «HMS Leander» ni una bandera moderna con sol para 1817. Los indicadores de bando en pantalla pertenecen a la interfaz.

## Material de consulta excluido de los assets

El paquete histórico del usuario, sus PDF y las imágenes conceptuales se preservaron en su ubicación de consulta y no se incorporan al ejecutable como recursos redistribuibles. La matriz histórica y sus enlaces están en `docs/historia/`. Las capturas de Civilization, cuando se disponga de ellas, serán evidencia de investigación de interacción y no recursos del juego.

## Nivel 2 «Humahuaca»: arte procedural (R1, pista `visual`)

El arte del nivel no usa ningún modelo importado ni nuevo: todo sale del generador `scripts/humahuaca/view/humahuaca_gen.gd` (ADDENDA A-01: Blender no está autorizado) y de shaders propios. **No se agregó ningún `.glb`, `.blend` ni textura** (la compuerta `higiene` lo verifica) y `assets/models/humahuaca/` sigue vacío. (Esto describe R1; desde la entrega de equipo del 2026-11-08 el nivel usa los modelos propios `assets/models/hx_*.glb` y el sonido propio de `assets/audio/humahuaca/`, acreditados más abajo y en `docs/CREDITOS.md`.) Los `.glb` de la Justina no se tocan ni se reutilizan en R1 (el caballo, la mula y las figuras son geometría propia con color de vértice).

| Pieza | Archivo | Qué es | Procedencia |
|---|---|---|---|
| Generador de arte | `scripts/humahuaca/view/humahuaca_gen.gd` | Templo (nave de adobe encalado a dos aguas, caballete a 7 m, sin torres ni fachada), batería (losa con parapeto y tres piezas bajas), casa del cura, torre provisional, casas del núcleo, cañones, carretas, cercos, los tres arquetipos de figura (`poncho_sombrero`, `camisa_gorra`, `artillero`) más el realista retintado, jinete, mula, churqui, cardón, sauce, rocas y bultos | Propia; color por id de paleta |
| Shader del suelo | `shaders/humahuaca_terrain.gdshader` | Un solo shader para la ventana de 4 m, el contexto de 30 m y el horizonte hasta ±8 km: pesos de capa por texturas, ruido a tres escalas, curvas de nivel sutiles, estratos, lluvia (×0,75) y modo de albedo | Propia |
| Shader de edificios y vegetación | `shaders/humahuaca_props.gdshader` | Color de vértice de la paleta con desgaste al pie, tongadas del tapial y lluvia | Propia |
| Shader del agua | `shaders/humahuaca_water.gdshader` | Agua turbia opaca con hebras que siguen la corriente | Propia |
| Shader de lluvia | `shaders/humahuaca_rain.gdshader` | Rayas en el espacio de la cámara con un MultiMesh (0 / 700 / 1 400 según la calidad) | Propia |
| Ruido | `shaders/humahuaca_noise.gdshaderinc` | Copia de `justina_noise.gdshaderinc` con las funciones renombradas (`hx_`) y funciones propias | Copia con procedencia en su encabezado |
| Datos de arte | `data/humahuaca_visual.json` | Paleta de 24 HEX de la lámina 06, luces, materiales, constructores de cada hito, fichas, arquetipos, vistas canónicas y calidades | Propia; la paleta, del usuario |

Los créditos y la procedencia de cada pieza están en `docs/humahuaca/CREDITOS_VISUAL.md`; la dirección de arte, las medidas y los pedidos, en `docs/humahuaca/VISUAL.md`. Las capturas de evidencia de R1 usan un relieve de prueba derivado de Copernicus GLO-30 **solo en la herramienta de captura** (nunca en el juego): su aviso está en `CREDITOS_VISUAL.md`.

## Nivel II «Humahuaca»: modelos GLB propios de la pista P6 (2026-11-08)

Decisión del usuario: modelar con código y exportar GLB para Godot. En esta PC no hay un Blender que funcione, así que el lead decidió usar el exportador sin Blender: `python tools/hx_models_sin_blender.py` corre los mismos constructores `hx_*` de `tools/create_models.py`, reemplaza las primitivas de `bpy` por equivalentes en numpy y escribe GLB 2.0 con **color por vértice**, sin texturas PBR. Para darles lectura agrega biseles, normales suavizadas por ángulo y una variación de color que imita las tongadas del tapial y las piedras de la pirca. Mantiene la esfera ancla de 2 mm al principio de cada malla (ver fase 2). Colores: los 24 HEX de la lámina 06, leídos de `data/humahuaca_visual.json`; la única excepción deliberada es el bronce del cañón. Esto deja sin efecto, para estos modelos, la nota de R1 de más abajo («no se agregó ningún `.glb`»). Detalle, medidas, triángulos y cómo instanciarlos: `docs/equipo/P6_MODELOS.md`. La integración en la escena es de la pista P2.

| Recurso | Autor/procedencia | Licencia o permiso de uso | Modificaciones y función |
| --- | --- | --- | --- |
| `assets/models/hx_casa_adobe.glb` | Pista P6 (equipo, 2026-11-08): constructores `hx_*` de `tools/create_models.py`, exportados por `tools/hx_models_sin_blender.py` (numpy, sin Blender). | Recurso original de esta entrega. | Casa baja de adobe 6 × 4 m: cimiento de piedra, techo plano de torta de barro y paja con caída al frente, pretil, rollizos, puerta baja y ventanita. Etiqueta: reconstrucción artística propia, generada por código sin Blender (variante sin texturas PBR); se puede regenerar con Blender cuando esté disponible con `create_models.py --only hx_...`. |
| `assets/models/hx_casa_adobe_grande.glb` | Pista P6 (equipo, 2026-11-08): constructores `hx_*` de `tools/create_models.py`, exportados por `tools/hx_models_sin_blender.py` (numpy, sin Blender). | Recurso original de esta entrega. | Casa de adobe 10 × 5 m con ramada de horcones y cañizo, dos puertas (una entornada) y dos ventanas. Etiqueta: reconstrucción artística propia, generada por código sin Blender (variante sin texturas PBR); se puede regenerar con Blender cuando esté disponible con `create_models.py --only hx_...`. |
| `assets/models/hx_capilla.glb` | Pista P6 (equipo, 2026-11-08): constructores `hx_*` de `tools/create_models.py`, exportados por `tools/hx_models_sin_blender.py` (numpy, sin Blender). | Recurso original de esta entrega. | Capilla de adobe encalado, nave 6,4 × 13 m, techo de torta a dos aguas, contrafuertes y espadaña de dos campanas; alto total 7,90 m. Capilla genérica de la quebrada, no el templo de Humahuaca. Etiqueta: reconstrucción artística propia, generada por código sin Blender (variante sin texturas PBR); se puede regenerar con Blender cuando esté disponible con `create_models.py --only hx_...`. |
| `assets/models/hx_tapia.glb` | Pista P6 (equipo, 2026-11-08): constructores `hx_*` de `tools/create_models.py`, exportados por `tools/hx_models_sin_blender.py` (numpy, sin Blender). | Recurso original de esta entrega. | Tramo de tapial de 4 m, 2 m de alto, con tongadas de 50 cm (por color de vértice) y remate de paja; se repite en X. Etiqueta: reconstrucción artística propia, generada por código sin Blender (variante sin texturas PBR); se puede regenerar con Blender cuando esté disponible con `create_models.py --only hx_...`. |
| `assets/models/hx_corral.glb` | Pista P6 (equipo, 2026-11-08): constructores `hx_*` de `tools/create_models.py`, exportados por `tools/hx_models_sin_blender.py` (numpy, sin Blender). | Recurso original de esta entrega. | Corral de pirca (piedra seca) 10 × 10 m, 1,15 m de alto, con tranquera de palos. Etiqueta: reconstrucción artística propia, generada por código sin Blender (variante sin texturas PBR); se puede regenerar con Blender cuando esté disponible con `create_models.py --only hx_...`. |
| `assets/models/hx_pirca.glb` | Pista P6 (equipo, 2026-11-08): constructores `hx_*` de `tools/create_models.py`, exportados por `tools/hx_models_sin_blender.py` (numpy, sin Blender). | Recurso original de esta entrega. | Tramo recto de pirca de 4 m para repetir. Etiqueta: reconstrucción artística propia, generada por código sin Blender (variante sin texturas PBR); se puede regenerar con Blender cuando esté disponible con `create_models.py --only hx_...`. |
| `assets/models/hx_pieza_artilleria.glb` | Pista P6 (equipo, 2026-11-08): constructores `hx_*` de `tools/create_models.py`, exportados por `tools/hx_models_sin_blender.py` (numpy, sin Blender). | Recurso original de esta entrega. | Cañón de campaña liviano (tubo de 1,6 m) en cureña de gualderas con ruedas de rayos. Tubo de bronce: la lámina 06 asigna «hierro» a los cañones; se apartó a propósito (las piezas de campaña españolas de la época solían ser de bronce). Pieza genérica, no un modelo documentado. Etiqueta: reconstrucción artística propia, generada por código sin Blender (variante sin texturas PBR); se puede regenerar con Blender cuando esté disponible con `create_models.py --only hx_...`. |
| `assets/models/hx_brasero.glb` | Pista P6 (equipo, 2026-11-08): constructores `hx_*` de `tools/create_models.py`, exportados por `tools/hx_models_sin_blender.py` (numpy, sin Blender). | Recurso original de esta entrega. | Brasero de hierro de tres patas con brasas emisivas (la luz la pone la vista). Etiqueta: reconstrucción artística propia, generada por código sin Blender (variante sin texturas PBR); se puede regenerar con Blender cuando esté disponible con `create_models.py --only hx_...`. |
| `assets/models/hx_fogon.glb` | Pista P6 (equipo, 2026-11-08): constructores `hx_*` de `tools/create_models.py`, exportados por `tools/hx_models_sin_blender.py` (numpy, sin Blender). | Recurso original de esta entrega. | Fogón de guardia: anillo de piedras, leños y brasas emisivas. Etiqueta: reconstrucción artística propia, generada por código sin Blender (variante sin texturas PBR); se puede regenerar con Blender cuando esté disponible con `create_models.py --only hx_...`. |

## Nivel II · sonido propio (rama `hx-sonido-nube`, integrada el 2026-11-08)

Obra propia del proyecto: 32 WAV en `assets/audio/humahuaca/` (44,1 kHz, mono, 16 bits) generados por código con numpy y scipy por `tools/generate_audio_humahuaca.py` (`python tools/generate_audio.py --humahuaca`) sobre las primitivas de `tools/generate_audio.py`: ruido filtrado, envolventes, tonos de metal por armónicos, campana de parciales inarmónicos y reverberación por convolución. **Sin bancos de sonido, grabaciones, muestras de terceros ni IA generativa de audio; sin descargas.** Misma licencia que el resto del proyecto (`LICENSE`). La receta y las cifras de cada archivo están en `assets/audio/humahuaca/MANIFIESTO.md`; el mapeo evento → sonido y la etiqueta de cada uno (documentado / razonado / diseño) en `docs/humahuaca/SONIDO.md`. Grupos: ambiente (lluvia, viento de la quebrada, grillos, pájaros del alba), combate (descargas de la torre y de la señal, disparos, choque de armas, impacto, explosión de pólvora, brasas), animales y carga (cascos de mulas, galope, relincho, carga de bultos, pisadas, vado) y señales (corneta, captura, campana de alarma).
