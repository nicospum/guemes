# Recursos, procedencia y producción

## Recursos originales de esta entrega

Los modelos, sonidos, geometría de escenario y shaders indicados como propios se crearon para este proyecto. Se entregan para uso, modificación y distribución como parte del juego, sin recursos extraídos de Civilization VII ni muestras o modelos descargados de terceros. La licencia general del código del proyecto se aplica a sus scripts de generación; las fuentes tipográficas conservan sus licencias específicas.

| Recurso | Autor/procedencia | Licencia o permiso de uso | Modificaciones y función |
| --- | --- | --- | --- |
| `assets/models/rider_1806.glb` | Modelado procedural original del proyecto, generado mediante `tools/create_models.py` (fase 2: Blender 4.4.3). | Recurso original de esta entrega; uso, modificación y distribución con el proyecto. | Caballo con geometría continua de torso y cuello, extremidades articuladas, cabeza, orejas, crin, cola, cascos, ojos, brida, riendas, manta y montura. Jinete con casaca sobria, calzón claro, botas y bicornio. Animación `trot`. |
| `assets/models/rider_1817.glb` | Mismo proceso propio. | Igual que el anterior. | Variante de caballo y jinete con poncho granate, sombrero de ala y barba; sin insignias modernas. Animación `trot`. |
| `assets/models/horse_only.glb` | Misma geometría y aparejo propios que el caballo de 1806. | Recurso original de esta entrega. | Montura sin jinete para permanecer estacionada en la ribera durante el abordaje; animación `trot` disponible, que debe detenerse cuando el caballo está quieto. |
| `assets/models/infantry.glb` | Mismo proceso propio. | Igual que el anterior. | Soldado de casaca roja para la dotación británica del Justine, con mosquete simplificado. Animación `walk`. |
| `assets/models/royalist_1817.glb` | Fase 2: malla propia generada por el mismo script (antes era una variante de material de la infantería). | Recurso original de esta entrega. | Figura agregada del ejército realista en 1817, de casaca blanco grisáceo y sin insignias británicas. Reconstrucción artística: no representa un uniforme regimental verificado. Animación `walk`. |
| `assets/models/dismounted_1806.glb` | Mismo proceso propio. | Igual que el anterior. | Variante a pie de casaca azul, para representar el abordaje después de dejar los caballos. Animación `walk`. |
| `assets/models/justine.glb` | Mismo proceso propio. | Igual que el anterior. | Mercante armado reconstruido: casco curvo, cubierta y cabina, dos mástiles, vergas, velas de malla, jarcia, barandas, escala de abordaje, carga y 26 portas sugeridas. Malla estática. |
| Terreno, casas coloniales, rocas, vegetación y agua | Geometría y materiales originales creados por el código de presentación del proyecto (`world_view.gd`). | Recursos originales de esta entrega. | Entornos generados para cada escenario. Relieve, rutas, costas y edificios son simplificaciones artísticas; no son escaneos arqueológicos. |
| `assets/audio/order.wav` y `error.wav` | Síntesis propia por `tools/generate_audio.py`. | Sonidos originales de esta entrega, sin muestras de terceros. | Avisos breves de orden aceptada/rechazada. |
| `assets/audio/hoof.wav` y `cannon.wav` | Síntesis propia por el mismo script. | Igual que el anterior. | Pulsos, ruido filtrado y envolventes para pasos y artillería. Son diseño sonoro sintético, no grabaciones históricas. |
| `assets/audio/river.wav` y `wind.wav` | Síntesis propia por el mismo script. | Igual que el anterior. | Ambientes de 12 segundos. |
| `assets/audio/victory.wav` | Síntesis propia por el mismo script. | Igual que el anterior. | Secuencia tonal breve de resolución. No incorpora composición o grabación ajena. |

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
- **Infantería.** `infantry` (dotación británica del Justine): shako cilíndrico liso, mochila, manta, cartucheras, bayoneta. `royalist_1817`: ahora una **malla propia** de casaca blanco grisácea con vueltas azules y chacó de lata lisa (ya no es una variante de material del GLB británico). `dismounted_1806`: casaca azul, bicornio, sable. Animación `walk` conservada, con giro de hombros y cabeceo.
- **Justine.** Casco y cubierta con tablazón, velas de lona con costuras y suciedad, timón, cabrestante, ancla, cadenas de obenques, faroles y barandilla de popa, timón de popa, rizos de vela, fardos y rollos de cabo. Mantiene 26 portas. Sin bandera ni insignia nacional.
- **Modelos nuevos, todavía sin referenciar por `world_view.gd`** (la integración corresponde a quien posea ese archivo): `house_colonial.glb` (planta 5,0 x 4,0 m, alto de muro 2,7 m, puerta hacia +Z de Godot, galería y teja), `church_colonial.glb` (nave 6 x 11 m, campanario frontal hasta unos 12,9 m, capilla andina genérica, no una iglesia concreta), `tree_algarrobo.glb` (unos 6,3 m), `tree_cardon.glb` (unos 4,4 m) y `rock_cluster.glb` (unos 2,5 m). Origen en la base, metros, frente en -Z. Para usarlos en `_house`/`_tree` basta instanciar el GLB y escalar el nodo; para muchas copias conviene MultiMesh o instancias compartidas.
- **Presupuesto.** Triángulos de malla base: jinete 17,4 mil (0.1.0: 12,9 mil), infantería 5,8-6,1 mil, Justine 27 mil. Más triángulos por figura pero la mitad de superficies; **no se midieron FPS** con estos modelos. El informe de auditoría señala las figuras con piel como costo dominante, así que la pista de rendimiento puede necesitar reducir la geometría (por ejemplo, menos mechones de crin o niveles de detalle).
- **Cómo regenerar.** `blender --background --factory-startup --python tools/create_models.py` (todo) o `... -- --only rider_1806,justine` (solo esos; el manifiesto se fusiona). Ya no existe `--only-royalist`.
- **Nombres.** No cambió ningún nombre de archivo ni de animación (`trot`, `walk`). Los nodos internos son los de Blender/glTF (malla unida `<nombre>_geometry`, esqueleto y `AnimationPlayer`); `world_view.gd` los busca por tipo.
- **Archivos extraídos por Godot.** Al importar, Godot 4.7 deja junto a cada GLB archivos `*_alb_*.jpg`, `*_nor_*.jpg` y `*_rm_*.jpg`; son derivados del importador, no se versionan.

### Qué sigue provisional

- Proporciones de caballo y persona aún estilizadas (extremidades tubulares, manos y rostro simples, sin dedos ni expresión).
- Texturas procedurales de 256-512 px: dan relieve y variación, no detalle fotográfico. La proyección es por caja, con costuras visibles de cerca en piezas redondas.
- Uniformes y ropas son interpretaciones; el color del poncho y las vueltas no están verificados para ninguna unidad.
- Casa, iglesia y vegetación nuevas no están integradas en el juego; el terreno y la hierba siguen siendo geometría de `world_view.gd`.
- Sin LOD, sin impostores, sin mediciones de rendimiento con la geometría nueva.
- Comprobación visual hecha con el visor `evidence/fase2/arte/viewer.gd` y las capturas del juego en `evidence/fase2/arte/`; no se probó en GPU integrada.

## Contrato de importación de los modelos

- Formato GLB 2.0 autocontenido, materiales PBR de color y rugosidad, sin texturas externas ni rutas absolutas.
- Metros como unidad de diseño. Frente en **−Z de Godot**, altura en **Y**. Blender usa +Y hacia delante y Z hacia arriba; el exportador realiza la transformación.
- Los jinetes miden aproximadamente 3.0 m de altura total con caballo. Los soldados a pie miden aproximadamente 1.94 m con bicornio. La escala artística no permite inferir la talla real de Güemes.
- El casco del Justine ocupa unos 14 m de eslora; el bauprés amplía la longitud total a unos 16.6 m. Manga de casco aproximada 5 m; cañones salientes amplían el ancho total. Cubierta central en Y≈3.5 m, quilla por debajo de Y=0; el origen corresponde a la referencia de agua.
- Se consolidaron las piezas en una malla por asset, conservando materiales y pesos de esqueleto. Esto evita cientos de nodos de dibujo por unidad; no equivale a una medición de FPS.
- `trot` y `walk` duran 1 segundo a 24 FPS. El script define fotogramas cíclicos. **glTF no transporta una propiedad universal de repetición**: en Godot, el integrador debe establecer `Animation.LOOP_LINEAR` antes de reproducir la animación.
- `assets/models/model_manifest.json` registra nombres de animación comprobados dentro del GLB, bytes, SHA-256, triángulos base, número de superficies y límites geométricos. Los límites no sustituyen las colisiones o zonas de selección del juego.

## Reproducción

Desde la carpeta del proyecto, con Blender 4.0.2 o compatible disponible:

```sh
blender --background --factory-startup --python tools/create_models.py
```

En Windows se puede reemplazar `blender` por la ruta local de `blender.exe`. El script no necesita red, cuentas, assets externos ni complementos comunitarios: utiliza la API Python y el exportador glTF incluido en Blender. Se deben conservar los nombres de archivo usados por el juego.

Para regenerar solo algunos modelos: `blender --background --factory-startup --python tools/create_models.py -- --only rider_1806,justine` (ver la sección de la fase 2).

Los siete WAV se reconstruyen con Python, NumPy y SciPy:

```sh
python tools/generate_audio.py
```

Blender, Python, NumPy y SciPy son herramientas de desarrollo. El ejecutable del jugador utiliza los GLB y WAV ya generados.

## Verificación y límites visuales

Se ejecutó Blender 4.0.2 en Linux remoto, se exportaron seis GLB y se creó una séptima variante de materiales, `royalist_1817.glb`, a partir de la infantería propia. Se analizaron las cabeceras JSON para verificar las animaciones y superficies; la variante conserva intactos los buffers de geometría y la animación del original. Se volvieron a importar los GLB de los dos jinetes y del barco en Blender y se inspeccionaron renders reales de esos archivos. Se ajustaron normales de malla, transición de hombros, forma de los cascos y el poncho tras la revisión. Las pruebas de importación en Godot, interacción y rendimiento pertenecen al informe de QA de la versión.

La dirección es **3D de detalle medio con estilización visible**. Hay siluetas y equipamiento reconocibles, rig y articulaciones, materiales naturales de color y geometría propia. No son personajes fotogramétricos, reconstrucciones arqueológicas ni assets de fidelidad cinematográfica demostrada. Los uniformes son interpretaciones de época: no se verificó un uniforme individual de cada personaje. El modelo del barco no reproduce un plano original; la descripción de mercante y la referencia a 26 cañones proceden del testimonio reproducido en el *Ideario*, p. 390.

No se distribuyen en los modelos banderas argentinas en 1806, nombres de Infernales para esa misión, el nombre «HMS Leander» ni una bandera moderna con sol para 1817. Los indicadores de bando en pantalla pertenecen a la interfaz.

## Material de consulta excluido de los assets

El paquete histórico del usuario, sus PDF y las imágenes conceptuales se preservaron en su ubicación de consulta y no se incorporan al ejecutable como recursos redistribuibles. La matriz histórica y sus enlaces están en `docs/historia/`. Las capturas de Civilization, cuando se disponga de ellas, serán evidencia de investigación de interacción y no recursos del juego.
