# Diseño del escenario Justina (rediseño 2026-10-29, tercera pasada de Reglas; Ronda 1 de mapa e historia 2026-10-30)

> **Ronda 1 (30-oct-2026, pista Mapa e Historia):** el paquete `Justina_Retiro_1806_Paquete_Editable` del usuario reconstruye el Retiro (ciudad alta, circo octogonal, barranca, ribera variable, buque apoyado). Qué se adoptó, qué se adaptó y qué se descartó está en `docs/historia/MATRIZ_HISTORICA.md` (sección C) y las fuentes en `docs/historia/FUENTES.md` (P1, S13-S28). Cambios de geometría y balance: sección 12 de este documento. Donde una tabla de abajo discrepa de la sección 12 o del JSON, vale el JSON (`data/justina_map.json`, `map_version` 4).

Documento de diseño del escenario rediseñado. Decisión del usuario: **escala real (1 unidad = 1 m), mapa de ~900 x 520 m, buque a unos 390 m del pie de la barranca, con minimapa y cámara libre**. La tercera pasada (revisión independiente del 29 de octubre) agrega: **fondo oculto distinto por partida**, **recursos limitados que obligan a elegir** (2 señales, 16 de pólvora de reserva), **captura con decisiones** (contraataques, heridos, marea), **explorador con riesgo decidible** (sondeo cauteloso y riesgo estimado) y las correcciones de etiquetas. Los números viven en `data/justina_map.json` (único origen, `map_version` 3); este texto los explica y no debe contradecirlos. La API entre pistas está en `docs/CONTRATO_JUSTINA.md`; los cambios de esta pasada respecto del contrato están en `docs/DISENO_REGLAS.md` ("Cambios de la segunda pasada").

## 0. Etiquetas de fuente

Todo dato, lugar o regla lleva una de estas etiquetas, en el JSON (`tag`) y en pantalla (glifo + color). **Documentado solo se usa para lo que respalda un testimonio, plano o parte reproducido en una compilación o fuente académica citada en `docs/historia/FUENTES.md`** (Gillespie 1818 en la transcripción del Ideario, plano de 1801, vistas de Vidal); es la regla del proyecto ("Documentado en transcripción": no se inspeccionó el manuscrito) y es la misma definición que ve el jugador. Lo que repiten fuentes divulgativas es Reconstrucción. Una **entidad mixta se rotula por su parte más débil** y separa sus partes en `tag_parts`: el buque (`landmarks.justina` y `ship`) es Reconstrucción, con `descripcion: documentado` (mercante británico de 26 cañones), `lugar: reconstruccion` y `posicion_casco: diseno`.

| Etiqueta | Glifo | Significa |
|---|---|---|
| **Documentado** | ● | Documentado en transcripción: testimonio, plano o parte reproducido en una compilación o fuente académica citada en `docs/historia/FUENTES.md`. Las fuentes divulgativas no bastan. Vale para el hecho o la descripción, nunca para el trazado exacto ni las cifras del juego. |
| **Tradición** | ◆ | Atribución transmitida y no probada (Güemes al frente de los jinetes; Ideario pp. 33, 390-392). |
| **Reconstrucción** | ◇ | El hecho o el lugar viene de fuentes secundarias o divulgativas, o la forma exacta se infiere de planos y vistas posteriores (Vidal 1816-20, Boneo 1801). |
| **Diseño** | ▲ | Regla, cifra o geografía inventada para jugar. No es dato histórico. |

### Qué es histórico y qué no (lo mínimo que el juego debe respetar)

| Afirmación | Etiqueta | Fuente / nota |
|---|---|---|
| Era un **buque mercante británico de 26 cañones**, que **combatió el día de la rendición** y fue tomado por **caballería** al cerrar el 12 de agosto de 1806 "por una súbita bajada del río". | Documentado (en transcripción; solo la **descripción**: el lugar es Reconstrucción) | Gillespie 1818 (traducción reproducida en el Ideario, pp. 28-29, 94 y 390 por OCR/transcripción; falta cotejar con el escaneo). **Sin tipo, tonelaje ni capitán**: no rotular fragata/goleta ni inventar nombre. |
| Varó **frente al Retiro**, cerca de la **Plaza de Toros** (hoy Plaza San Martín); con la barranca en tierra. No es Quilmes ni Barragán. | **Reconstrucción** (confianza media-alta en el Retiro; una **zona**, no un pin) | **El lugar NO viene de Gillespie**: lo sostienen fuentes divulgativas (edisalta, La Nación, Recalada; S3, S10, S11). La Torre Monumental (1916) no marca el punto. La «batería Abascal» no se cotejó con ningún documento primario: lo que consta (Liniers, 11-ago, S13) son **dos piezas de a 18** de la goleta Dolores. |
| La caballería era la de **Pueyrredón**. | **Reconstrucción** (antes figuraba Documentado) | Concha (15-ago-1806) y Liniers (Archivo Pueyrredón, t. I, p. 54) según la investigación del repo, **sin cotejo del original**; el paquete P1 reconstruye el vínculo por relatos posteriores. Gillespie solo dice «caballería». «40 a 60 jinetes» queda no verificado (el paquete: 30, 50 o 60 sin datos suficientes). |
| **Liniers** ordenó avanzar. | **Reconstrucción** | Obligado 1920 (fuente secundaria). La orden de avance del juego es regla de **Diseño**. |
| **Güemes como jefe de los jinetes**. | **Tradición, no probada** | Obligado 1920 lo hace ayudante de Liniers que lleva la orden a Pueyrredón (Luis Güemes identifica a Obligado como la fuente de la atribución, S13 p. 72). Dato **documentado** distinto: cadete de 21 años del **Regimiento de Infantería de Buenos Aires** (no de caballería; documento del 11-ago); su presencia en el buque el 12 queda **sin datos suficientes**. Ideario p. 33 (no probada; «volvía de Córdoba» no se cotejó con P1). |
| La costa de 1806 estaba **al pie de la barranca** (Plaza de Toros). | Reconstrucción | La línea de agua inicial del juego queda a ~20 m del pie. |
| Distancia al buque «~400 m». | **Tradición discutida** (un material bonaerense de 2006, S26 p. 93, «desde las barrancas de la Plaza de Toros»; sin medición contemporánea). El juego usa 390 m = **Diseño** (`distance_tag: diseno`) | Se mide **desde el pie de la barranca** (x≈190) hasta el casco (x=580). La etiqueta visible es una sola: «~400 m (tradición discutida); el juego mide 390 m (diseño)». No medir 400 m desde la orilla moderna. |
| Profundidad al final "pecho o cuello de los caballos" (1-1,5 m). | Divulgación, sin sondeo de época | Se usa 1,0 m en el vado de abordaje (diseño). |
| El Plata tiene bajadas muy repentinas de siete u ocho pies (≈ 2,1-2,4 m). | Documentado en transcripción (Gillespie) | **Gillespie no atribuye la causa al viento en ese pasaje**: «por el viento» es una explicación moderna de la investigación del repo (vientos del oeste, bajantes de ~1,65 m hoy). El viento del 12/8/1806 **no** está documentado. |
| Ocurrió sin bandera argentina, sin Infernales, sin San Martín. | Regla de CLAUDE.md | El buque era británico y se dibuja sin bandera nacional; si lleva insignia, genérica y marcada reconstrucción. |
| Todo lo demás: bancos, canal, vados, hoyos, tiempos, cifras de fuerza, munición, cuerpo a cuerpo, puesto de Liniers, **las dos órdenes de avance de 420 s**, los contraataques de la dotación. | **Diseño** | No hay carta de sondeo de 1806 del Retiro. |

## 1. Geografía (coordenadas métricas)

Mapa de **900 m (x, este) por 520 m (z, sur)**. El **norte es -z**; el río está al **este (+x)**. Elevaciones en metros sobre el "cero de bajante" (nivel mínimo del río durante la partida).

```
 x=0 ────────── 150 164 178 194 ─ 210 ──── 270 ──────────── 548 580 ───── 900
 meseta        cresta pie   playa   línea     bajo/bancos      vado  buque   río abierto
 (Alameda,     (8-15 m) (3 m) alta   de agua   (turbio: no se ve el fondo)
  Plaza de Toros,                    inicial
  batería)
```

En 1806 la costa estaba al pie de la barranca: **toda la tierra (cresta, pie, Alameda, Plaza, batería, campamento y puesto) se corrió 120 m al este** respecto de la primera versión, y la playa alta "siempre seca" de 120 m desapareció. Queda una **franja de playa alta de ~20 m** entre el pie y la línea de agua inicial (x≈210), donde parten los grupos. La bajante *descubre* la playa de barro y los bancos: ya no hay un tramo de tierra firme que regale la mitad del camino.

### 1.0 Área jugable: 900 x 750 m del paquete frente a 900 x 520 m (decisión de la Ronda 1)

El paquete (D2) propone un prototipo de **900 x 750 m** para «incluir ciudad alta, un hito reconocible, la transición topográfica y suficiente recorrido abierto hasta el casco», con la costa en diagonal NO-SE y origen arbitrario; aclara que no exige que todo el rectángulo sea transitable ni presupone cámara, género ni motor. Se evaluaron tres opciones:

| Opción | Qué implica | Veredicto |
|---|---|---|
| **A. Adoptar 900 x 750 como zona simulada** | Rehacer minimapa (la relación 900:520 de 1,73 pasa a 1,2: cambia el diseño del minimapa y su QA de UI), mallas de ruta, matriz de balance y la geometría de bancos; 230 m más sin reglas ni decisiones | Descartada: gran costo de re-balance y de UI para espacio sin juego. |
| **B. Conservar 900 x 520 sin más** | Pierde la ciudad alta, el circo grande, Santa Catalina, la ribera que continúa | Descartada: es justamente la queja «una parte definida y todo lo demás genérico». |
| **C. Conciliar (adoptada)** | La zona simulada y jugable sigue siendo 900 x 520 m (`size`), con toda la geografía del paquete que importa a las reglas: ciudad alta y circo en la meseta, barranca irregular, bajadas, playa y franja húmeda con meandros, bancos, canal, vado y buque. Los 230 m extra se reparten como **contexto visual** de 115 m al norte (z de -115 a 0) y 115 m al sur (z de 520 a 635): ribera y barranca que continúan sin reglas, caserío, siluetas de Santa Catalina y del Fuerte | Bloque `context` del JSON. La Vista decide cuánto dibuja; la cámara no sale de `size` + `camera.bounds_margin_m`. |

Detalles: `context.extent` = x 0-900, z -115 a 635; `context.north/south.features` (casas, ribera); `context.skyline` (Santa Catalina, Fuerte y Plaza Mayor, campanarios, con rumbo y distancia estimada comprimida al horizonte, etiquetada Reconstrucción); `context.excluded_anachronisms`. La diagonal del prototipo no se traslada: el juego conserva el eje +x este / +z sur, con el río al este, que ya pedía el contrato.

### 1.1 Tierra

| Elemento | Posición (m) | Etiqueta |
|---|---|---|
| **Camino de la barranca (Alameda)** | polilínea corta [[152,262],[149,300],[151,345],[144,386]] (~125 m), sin arboleda | **Diseño** (antes Reconstrucción de 520 m con árboles a ambos lados; el paquete C advierte no extender una avenida ribereña uniforme a todo Retiro; Obligado solo pide un camino por donde corra un mensajero) |
| **Plaza de Toros del Retiro** | centro (112, 225), circunradio 45 m (90 m entre vértices opuestos), octógono con rotación de 22,5°, ruedo circular de 30 m, 9 m de altura, 4 puertas de orientación no fijada | **Existencia: Documentado** (Boneo 1801, UWM 1808, Vidal; Pillado: 4 puertas); **posición: Reconstrucción** («próxima al borde»); **medidas: Diseño**. Antes: centro (134,225), radio 24 m, Documentado en bloque. La acción Reunir pasa a radio 45 m para conservar el recorrido (el borde queda a la misma distancia de la bajada) |
| **Campamento de Pueyrredón** | centro (148, 292), radio 18 | Reconstrucción (fuentes secundarias). Corrido para no pisar el circo ensanchado |
| **Piezas de a 18 del Retiro** (id interno `bateria_abascal`) | (148, 176), 22 x 14 m, junto a la cresta | **Reconstrucción**: dos piezas de a 18 de la goleta Dolores (parte de Liniers, 11-ago, S13) con emplazamiento abierto (F03 del paquete); la «batería Abascal» no se cotejó con documentos primarios. Que su fuego llegue al buque (rango 600 m): Diseño |
| **Puesto de mando de Liniers** | (140, 345), radio 12 | **Diseño**: el lugar donde estuvo Liniers no está documentado |
| **Cresta de la barranca** | irregular: x≈140-166, 12 puntos entre z=0 y 520; altura 9-14 m | Reconstrucción (paquete F04: contraste local de 10-12 m, Diseño; los ~20 m regionales de Favelukes no son el corte de Retiro) |
| **Pie de la barranca** | irregular: x≈168-200, elevación 3,0 m | Reconstrucción |
| **Bajadas** (únicos pasos de la barranca) | `bajada_norte` (178,190) y `bajada_sur` (172,335), **40 m de ancho** (antes 24) | Diseño. Se ensanchan porque con una barranca irregular el planificador cortaba la esquina y dejaba al grupo «bloqueado» en el borde. El paquete propone 8-12 % de pendiente con 83-150 m de desarrollo; aquí la barranca mide ~30 m de ancho (pendiente de juego ~25-30 %): se registra `desarrollo_paquete_m` y no se adopta |
| **Playa alta** (franja seca al pie) | 20-35 m entre el pie y la línea de agua inicial | Reconstrucción |
| **Cañaverales y carretas** (obstáculos) | `canaveral_norte` (250,120), `canaveral_sur` (240,470), `carretas_varadas` (218,345) | Diseño |

Salida de los grupos: en la franja de playa alta, a ~10 m de la línea de agua inicial: Vanguardia (199,240), voluntarios (200,268), reserva (198,296). Exploradores en (204,255) y (204,283).

### 1.2 Río, orilla y buque

- **Línea de agua inicial** (`shore_high`): **irregular**, x≈196-236 según z (entrantes y salientes de ±10-15 m), nivel 1,65 m, a 20-35 m del pie de la barranca. Los **390 m** hasta el buque (x=580, z=262) se miden **desde el pie de la barranca** (x≈190); desde la línea de agua hay ~370 m. Un material de 2006 habla de ~400 m: tradición discutida; los 390 son Diseño. Con la bajante, la franja húmeda (`bed_warp`, meandros de ±10-28 m que corren las curvas de nivel entre el pie y x≈400) deja una orilla con bahías, no una recta; `tide.states` describe los cuatro estados (alto, bajante, mínimo con banco húmedo, subida).
- **Buque Justina**: centro (580, 262). **Zona de contacto** del casco de 16 m de radio (bloquea el paso), fondo -1,5 m; **envolvente visual de 40 x 9 m** con proa al norte (Diseño, por los comparables RMG SLR0583, LNG0016 y MSA0204; no es un plano del Justina). La banda de 13 cañones (de los 26 documentados, en total y no por banda; el reparto es diseño) mira al oeste, hacia tierra. Posición A del paquete (banco conectado a la ribera); la B, más exterior, queda registrada y no implementada (`ship.position_candidates`). Lugar = zona de incertidumbre de ~120 m (`uncertainty_radius_m`). Dibujado con el pabellón mercante post-1801 **como hipótesis** (`banners`), nunca la bandera argentina.
- **Perfil base** del fondo (igual en todo z): 3,0 m en el pie de la barranca, 2,4 en x=203, 1,65 en la línea de agua inicial (x=210), 1,2 en x=222, 0,5 en x=245, 0,0 en x=270 (**línea de agua en la bajante máxima**), -0,35 en x=330, -0,7 en x=420, -1,05 en x=500, -1,5 en x=580, -3,0 en el borde este. Todo Diseño.
- **Bancos** (el fondo sube hasta `top_m`; ver `bed_layers_order` para el orden de capas, **con los vados en modo `set`**):

| Banco | Eje (m) | Ancho | Cota superior | Papel |
|---|---|---|---|---|
| **Central** | (272,266) a (500,264) | 40 m | -0,25 m | Ruta **directa**: ~280 m de agua, totalmente en el arco de la banda del buque. Contiene el **pozo oculto** y dos **falsos vados** en sus bordes. |
| **Sur** | (332,404) → (380,430) → (450,455) → (520,440) → (565,390) → (572,320) → (556,282) | 28 m | -0,45 m | Ruta **larga** que llega por la popa del buque (cañones de caza: poca exposición). Solo se alcanza por el **vado sur**. |
| **Norte** | (300,150) a (480,150) | 70 m | -0,10 m | **Señuelo**: sin salida, termina a ~136 m del buque. |

- **Canal de la ribera**: eje (300,320)-(310,480), 36 m de ancho, fondo -2,0 m. Corta el acceso al banco sur. Cruzarlo a ciegas **tropieza** (40 s detenido, +30 fatiga, −38 de fuerza).
- **Vado sur** (oculto): carril (268,400)-(342,406), 20 m de ancho, cota -0,9 m. Abre con nivel ≤ 0,4 m: **t ≈ 355 s** hasta ≈ 989 s para caballos.
- **Vado del buque**: círculo (548,262) de 22 m de radio, cota -1,0 m: profundidad 1,0 m con el río en mínimo. Transitable para caballos con nivel ≤ 0,3 m: **t ≈ 379 a ≈ 982 s**. Para gente a pie (límite 1,2 m) el vado deja de ser vadeable con el río a 0,2 m: **t ≈ 974 s**. Punto de abordaje.
- **Hoyos ocultos** (todos Diseño; quien pasa sin haberlos reconocido **cae** y pierde caballos y jinetes):

| Hoyo | Centro | Radio | Costo del tropiezo | ¿Existe siempre? |
|---|---|---|---|---|
| **Pozo del banco central** | (345,264) | 11 m | 45 s detenido, +35 fatiga, **−45 de fuerza** | sí |
| **Falso vado del borde norte** | (352,222) | 9 m | 30 s, +25 fatiga, −32 de fuerza | sí |
| **Falso vado del borde sur** | (372,306) | 9 m | 30 s, +25 fatiga, −32 de fuerza | sí |
| **Hoyo del flanco norte** (`pozo_flanco_norte`) | (348,240) | 9 m | 40 s, +30, −38 | **solo si el sorteo de la semilla lo elige** |
| **Hoyo del flanco sur** (`pozo_flanco_sur`) | (348,288) | 9 m | 40 s, +30, −38 | **solo si lo elige** (exactamente uno de los dos flancos) |
| **Hoyo del banco sur, salida del vado** (`pozo_sur_a`) | (362,419) | 9 m | 40 s, +30, −38 | **solo si lo elige** (uno de `pozo_sur_a`/`pozo_sur_b`) |
| **Hoyo del banco sur, tramo medio** (`pozo_sur_b`) | (380,429) | 9 m | 40 s, +30, −38 | **solo si lo elige** |
| **Canal de la ribera** (si se cruza fuera del vado) | eje del canal | 36 m de ancho | 40 s, +30 fatiga, −38 de fuerza | sí |

  Antes la caída costaba −3 de fuerza y luego −28: reconocer no pesaba lo bastante. Ahora un trazado a ciegas por el centro o por el borde norte pierde más del 95 % de la fuerza de los tres grupos en las simulaciones, y **no depende del azar de A\***: el pozo central y los falsos vados están siempre y cubren cualquier trazado recto.

#### 1.2.1 Resultado oculto por partida (`hidden_layout`)

Al empezar, la **semilla** sortea una variante por grupo (con un generador propio que no consume el azar del fuego): `state.hidden.picks = {flanco_central, hoyo_banco_sur}`. Solo la variante elegida **existe** en el fondo de esa partida (terreno, malla de rutas y colisiones); la otra es fondo normal. El resultado queda **fijo** y se guarda en la partida: cargar restaura el mismo fondo.

- **Flanco del banco central.** Con el pozo central descubierto, el planificador lo rodea por el flanco que cree libre. Una de las dos orillas tiene un segundo hoyo; la otra es firme. Sondear **un** carril por un flanco lo resuelve: si el carril termina frente a un hoyo, el firme es el otro (solo hay uno); si lo recorre entero, es ese. Quien solo sondea el eje central apuesta a un lado.
- **Hoyo del banco sur.** Hay un hoyo en uno de dos puntos del eje del banco, a 60-120 m de la salida del vado. Con el vado abierto, un carril por el eje lo descubre antes de cargar.
- **Por qué la semilla y no el azar de A\*:** antes lo único que impedía que el planificador pasara por el pozo era la suerte del trazado. Ahora el desastre de ir a ciegas es **determinista** (hay hoyos en todos los trazados rectos), y reconocer es la única forma de saber cuál variante tocó. Descubrir un hoyo lo marca para el planificador con su fondo real; los hoyos inactivos nunca se descubren ni se marcan.
- Todo lo anterior es **Diseño**: no existe sondeo de 1806 del Retiro.

### 1.3 Información incompleta (fondo desconocido)

El Plata es **turbio**: el jugador **no ve el fondo**. Lo único que sabe a ciencia cierta:
1. Lo **emergido** (altura sobre el agua > 0): bancos y barro que ya asoman.
2. Los **carriles reconocidos** por exploradores (franja de 6 m) y los **vados marcados** (corredor de 16 m).
3. Para todo lo demás vale la **estimación**: perfil base suave, sin bancos, canal, vados ni pozos. La ruta calculada por el planificador usa solo este conocimiento; la simulación aplica el fondo **real**.

El resultado jugable: la ruta central parece buena en el mapa y esconde el pozo, dos falsos vados y (según la semilla) un hoyo de flanco; la ruta sur parece cortada por un canal "invisible", exige descubrir el vado y esconde un hoyo en el banco. Reconocer el centro cuesta: el explorador entra en el arco de la banda del buque (ver 5) y solo puede empezar cuando el agua baja (t ≳ 250 s; los exploradores entran hasta 1,3 m de profundidad, igual que los caballos). Para reconocer con riesgo decidible, `probe_careful` y `scout_risk` dan el riesgo de baja antes de ordenar (ver 5).

## 2. Tiempos

| Hito | t (s) | Nivel (m) |
|---|---|---|
| Alta inicial | 0-60 | 1,65 |
| **Bajante** (lineal) | 60-450 (**390 s ≈ 6,5 min**) | 1,65 → 0,0 |
| Mínimo sostenido | 450-960 | 0,0 |
| Subida (lineal) | 960-1080 (120 s) | 0,0 → 1,65 |
| **Plazo** | 1080 (18 min) | derrota si no hay captura |

Partida objetivo **12-18 min**. En las simulaciones las victorias duran entre 12,4 y 16,2 min (ver 10). La bajante es un **temporizador visible** con barra de nivel y marcas de profundidad (Diseño, anclado en Gillespie y en una bajante moderna típica de ~1,65 m). El plazo es de 18 min (antes 15) porque el abordaje ya no es instantáneo (ver 5): el riesgo real es que **el agua que sube alcance a los que están a pie en el vado** (~t 974 s).

## 3. Velocidades

Valores de equitación comunes (Diseño). Un grupo desmontado solo camina.

| Situación | Velocidad |
|---|---|
| A pie | 1,3 m/s |
| Trote | 3,0 m/s |
| Galope | 7,0 m/s (solo en **firme**: altura sobre el agua ≥ 0,6 m y sin barro) |
| Barro (altura sobre el agua < 0,6 m, sin cubrir) | 1,0 m/s en la línea de agua → 1,5 m/s a 0,6 m (nunca más que el ritmo elegido) |
| Agua somera (profundidad ≤ 0,6 m) | caballo 2,0 m/s; a pie 1,0 m/s |
| Agua de 0,6 a 1,3 m | 0,8 m/s |
| Profundidad > 1,3 m | **intransitable para caballos**; a pie el límite es 1,2 m |
| Bajadas de la barranca | ×0,7 |
| Carril sondeado sin marcar (columna de a uno) | ×0,75 |

Fatiga por segundo: caminar 0,02; trote 0,05; galope 0,12; ×1,5 en barro; ×1,6 en agua. La fatiga resta poder de abordaje (hasta −60 %).

## 4. Bucle del jugador

1. **Mirar** (0-60 s, río alto): el mapa muestra solo orilla, barranca, hitos y el buque. Hay que decidir cómo repartir las tareas entre tres grupos y dos exploradores.
2. **Prepararse** (≈0-300 s): reunir jinetes (cuesta 4 de munición y +20 de fatiga), abastecer munición de la reserva (solo 16), **señalar a Liniers** (solo 2 señales de 420 s: una pronto da +8 de munición pero vence antes de llegar; una tarde no da munición para cubrir a los exploradores) y reconocer. La pólvora no alcanza para todo: **cubrir a los exploradores, cubrir el cruce, armar reclutas y rechazar contraataques compiten por los mismos 44 de munición**.
3. **Reconocer y decidir ruta** (≈250-500 s): el centro exige un carril por un flanco **bajo el fuego del buque** (sondeo cauteloso: más lento pero con la mitad de riesgo; el riesgo estimado de baja se informa al ordenar) o apostar a ciegas; el sur exige descubrir y marcar el vado (≈100-250 s) y sondear el banco desde que el vado abre (t ≳ 355 s), fuera del alcance del buque. Se puede dividir fuerzas.
4. **Cruzar** (≈330-750 s): marcha con el ritmo elegido, fuego de distracción en las ventanas de 45 s (8 de munición, recarga 90 s), a la vez o escalonados. **Si la orden de avance vence con un grupo en marcha, el grupo se detiene**: `plan_route` avisa cuando la ETA supera la vigencia.
5. **Abordar y sostener** (≈550-1000 s): llegar al vado, desmontar (12 s) y **sostener el abordaje con decisiones**: cada ~55 s la dotación **contraataca** y hay 14 s para **rechazarlo** (3 de munición) o se pierde terreno; los heridos del cuerpo a cuerpo y de los contraataques pueden **evacuarse** (el grupo no suma captura 10 s y recupera el 60 %) o retirarse con el grupo; y hay que **retirar a tiempo** a los de a pie cuando el agua del vado se acerca a 1,2 m.
6. **Cierre**: victoria al 100 % de captura; si el río alcanza a la gente a pie en el vado, se ahoga.

## 5. Acciones (13) con coste y efecto

Cifras en `actions` del JSON. La tercera pasada agrega `probe_careful` (explorador), `repel` y `evacuate` (grupos que abordan).

| # | Acción (id) | Quién | Coste | Efecto | Etiqueta |
|---|---|---|---|---|---|
| 1 | **Mover** (`move`, ritmo walk/trot/gallop) | grupo | tiempo de marcha + fatiga por segundo | Marcha a un punto. La ruta se calcula con lo que el jugador sabe. | Diseño |
| 2 | **Reconocer fondo** (`probe`) | explorador | ocupa al explorador; hasta 3 puntos; 1,0 m/s en agua, 3,0 m/s en seco; no entra en agua > 1,3 m (como los caballos); **4 de salud, cada descarga lo acierta con probabilidad 0,4 x exposición** | Revela el fondo real en una franja de 6 m: aparecen pozos y vados. Al ordenarlo se informa el **riesgo estimado**: segundos expuestos, impactos esperados y % de baja (peor caso: único blanco). | Diseño |
| 2b | **Sondeo cauteloso** (`probe_careful`, o `issue_scout(..., {"cautious": true})`) | explorador | igual que `probe`, pero donde el buque alcanza avanza a **0,7** de la velocidad | Mismo efecto con **la mitad** de la probabilidad de ser alcanzado (`hit_mult` 0,5). Con la mitad del riesgo y 30 % más de tiempo bajo el fuego, el explorador del centro sobrevive la mayoría de las veces; con dos exploradores el fuego se reparte. | Diseño |
| 3 | **Marcar vado** (`mark_ford`) | explorador | 1 baliza por cada 10 m (16 al inicio), trabaja a 1,0 m/s; solo sobre un tramo ya sondeado | Ensancha el carril a 16 m: columna a velocidad plena y sin tropiezo. | Diseño |
| 4 | **Reunir jinetes** (`muster`) | grupo | subir por una bajada hasta la Plaza de Toros; 40 s allí; **4 de munición**; sale del reservorio de 60; **+20 de fatiga** (reclutas sin entrenar) | +20 de fuerza (tope 100). | Diseño |
| 5 | **Distraer con fuego** (`distract_fire`) | global | 8 de munición; reutilizable cada 90 s | 45 s con la exposición a la mitad; el buque pierde **3** de moral y tarda 2 s más entre descargas. Dispara la batería Abascal y tiradores de la barranca. | Diseño |
| 6 | **Abastecer munición** (`resupply`) | grupo | subir hasta la batería; 25 s allí | +16 de munición (tope 40; arranca en **12**), retirados de la **reserva de la batería (16 en total: se agota)**. | Diseño |
| 7 | **Señalar a Liniers** (`signal_liniers`) | grupo | ir al puesto de mando (148,345), 10 s allí; **solo 2 señales en toda la partida** | Concede la **orden de avance durante 420 s** (necesaria para `board`; si vence con un grupo en marcha hacia el buque, **el grupo se detiene**; vencida hay que volver a señalar) y +8 de munición. | **Diseño** (que Liniers ordenó avanzar lo cuenta Obligado, fuente secundaria; Güemes como mensajero es tradición y **no se afirma**) |
| 8 | **Cargar y abordar** (`board`) | grupo | requiere orden de avance vigente; llegar al vado del buque; desmontar 12 s | Suma poder de captura 0,55 %/s por unidad de fuerza; baja la moral de la dotación 0,12/s. Los caballos quedan en el vado. Costo: fuego x0,3, cuerpo a cuerpo, contraataques y agua que sube. | Documentado en transcripción (el hecho) / Diseño (cifras) |
| 9 | **Retirar** (`withdraw`; `retreat_all`) | grupo / global | la marcha de vuelta | Vuelve a la playa seca; **también desde el abordaje** (los jinetes montan los caballos del vado). `retreat_all` termina la partida como derrota ordenada. | Diseño |
| 10 | **Reagrupar** (`rally`) | grupo | tiempo | En la playa seca y fuera de alcance: -0,18 fatiga/s, +0,025 fuerza/s. | Diseño |
| 11 | **Rechazar contraataque** (`repel`) | grupo que aborda | **3 de munición**, +3 de fatiga; solo durante la ventana de 14 s de un contraataque | La captura no retrocede y el daño se reduce a la cuarta parte. | Diseño |
| 12 | **Evacuar heridos** (`evacuate`) | grupo que aborda | 10 s sin sumar poder de captura; hacen falta ≥ 3 de heridos | Recupera el **60 %** de los heridos como fuerza. | Diseño |

Más `cancel` (anula la orden en curso).

### Fuego del buque (el castigo)

Cada **7,5 s** el buque dispara una descarga contra un objetivo dentro de **265 m** (alcance Diseño; era 280). Daño 7,8-11,9 × exposición × moral de la dotación (mín. 0,2). Exposición por rumbo desde el buque: banda (±40° del oeste) **1,0**; cuartel (hasta ±70°) **0,4**; popa/proa **0,15**. Quien desmonta o aborda recibe el **fuego x0,3** (era x0,5: así el castigo está en el cruce, que es lo que diferencia las rutas, y no en el sitio de abordaje, que es igual para todas). En la playa y el barro no hay fuego (fuera de alcance): el riesgo empieza donde empieza el agua. El centro acumula ≈ 1,6 veces la exposición de cruce de la sur con los mismos recursos (ver 10).

### Abordaje: costo, decisiones y agua que sube

- **Cuerpo a cuerpo**: cada grupo que aborda pierde 0,05 de fuerza por segundo × moral de la dotación/100. Con la dotación quebrada casi nada. **La mitad de lo que se pierde son heridos** (`wounded`), recuperables con `evacuate` o retirando al grupo (mitad de efecto).
- **Contraataque de la dotación** (`ship.capture.counter`): a los 30 s del primer abordaje y luego cada 55 s ± 12 s, la dotación contraataca (si su moral ≥ 15). Se abre una **ventana de 14 s**: si algún grupo que aborda **rechaza** (`repel`), el daño es un cuarto; si no, los grupos que abordan reparten 22 de daño y la captura retrocede 8 puntos. Es la decisión que impide la espera pasiva: **sin responder, la captura no se sostiene** (ver `central_flank_noreply` y `south_noreply` en 10).
- **Agua que sube**: quien está desmontando o abordando con una profundidad mayor que 1,2 m pierde `3,0 × (exceso + 0,1)` de fuerza por segundo. Con el río en mínimo nadie se ahoga. Desde el 85 % del límite (1,02 m) el parte avisa cada 10 s para que se retire o se evacue a tiempo (**gestión de la marea**).
- **Poder de captura** = fuerza/100 × (1 − 0,004 × fatiga, mínimo 0,4); el ritmo es 0,55 %/s por unidad de poder (era 0,30: ahora hay contraataques que lo deshacen).

## 6. Victoria y derrota

- **Victoria**: captura 100 %. La dotación se rinde; los caballos no suben a cubierta.
- **Derrota**: (a) todos los grupos dispersos (fuerza ≤ 5); (b) plazo de 1080 s sin captura; (c) retirada general.
- El texto de cierre dice siempre **qué es documentado y qué es adaptación** y muestra el parte de campaña (sección 8).

## 7. Cómo se muestra tradición vs documento

- Cada hito, grupo y acción tiene `tag`. En el HUD: glifo y color de `source_tags` (● documentado, ◆ tradición, ◇ reconstrucción, ▲ diseño) junto al nombre, y una línea de fuente al seleccionar.
- La vanguardia se titula **"Vanguardia · Güemes (tradición)"** con glifo ◆; al seleccionarla: "Atribución tradicional, no probada". La reserva de Pueyrredón es **reconstrucción** (fuente secundaria) y aparece en el parte. **El rótulo 3D de Güemes debe llevar la misma marca de tradición** (trabajo de la Vista).
- Las cifras divulgativas (390 m, profundidad 1,0 m, 26 cañones por banda) se rotulan "cifra divulgativa" o "diseño" en el panel de información y en el parte.
- El briefing inicial dice que es una **reconstrucción jugable, no una crónica**, y distingue lo que cuenta Gillespie (mercante británico de 26 cañones que combatió, tomado por caballería por una súbita bajada del río) de lo que ubican fuentes divulgativas (el Retiro) y de lo que viene de relatos secundarios (Pueyrredón, Liniers). El menú **no** debe titularse "documentada".

## 8. Parte de campaña (final)

Reglas entrega `campaign_report()` (contrato). Contenido: resultado y motivo; tiempo; fuerza inicial/final/bajas por grupo; ruta usada (central/sur/mixta); metros sondeados y marcados; tropiezos y **caballos perdidos**; **pérdidas en el cuerpo a cuerpo y por el agua**; munición gastada; nivel del río al abordar; descargas recibidas; y **"Qué fue historia"**: cinco líneas con su etiqueta (documentado, reconstrucción, tradición y dos de diseño). La UI lo muestra sin recalcular nada.

## 9. Pistas y propiedad de archivos

| Pista | Archivos propios |
|---|---|
| Reglas + datos + textos | `scripts/game_rules.gd`, `data/justina_map.json`, `data/history.json`, `tests/test_rules.gd`, `docs/DISENO_JUSTINA.md`, `docs/DISENO_REGLAS.md`, `docs/historia/` |
| Vista | `scripts/world_view.gd`, `assets/`, `tools/create_models.py` |
| UI | `scripts/main.gd`, `tools/ui_qa.gd`, `tests/test_integration.gd` |

Todo cambio entre pistas pasa por el contrato; no se tocan archivos ajenos.

## 10. Objetivos de balance para los tests de Reglas

Medidos con **18 estrategias scripteadas x 8 semillas de calibración** (3, 5, 7, 11, 13, 17, 19, 23; 144 partidas) **y 12 semillas de validación** (29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73) para las 12 estrategias razonables (144 partidas más) sobre el juego real, no con un modelo aparte. Tabla completa y lectura en `docs/DISENO_REGLAS.md`.

| Criterio | Cómo se comprueba |
|---|---|
| Ninguna estrategia acumula más del **60 %** de las victorias de la matriz (antes 70 %); al menos 3 ganan en la mitad o más de las semillas; ninguna familia (centro, sur) gana más del 75 % de sus partidas | `_test_strategies` (`play_targets.dominance`) |
| Hay victorias por el centro y por el sur; ninguna ruta acumula más del 75 % | `_test_strategies` |
| **A ciegas casi nunca se gana** (≤ 10 % de las partidas de las estrategias ciegas) y **reconocer mejora la tasa de éxito** (≥ 40 % y ≥ 30 puntos más) | `rush_central`, `rush_gallop`, `blind_north_edge`, `south_wrong_crossing` frente a `central_flank_*`, `south_full`, `mixed_split` |
| **Tasa de victoria de una partida humana razonable ≈ 40-60 %** (Ronda 1): las 12 estrategias que reconocen y se comprometen (`COHORT`) ganan entre 40 y 60 % tanto en las semillas de calibración (**55/96 = 57 %**) como en las de validación (**79/144 = 55 %**), con menos de 15 puntos de diferencia; al menos 4 estrategias distintas ganan la mitad o más en validación | `_test_victory_quality` (`play_targets.cohort_win_rate`) |
| **Victorias no pírricas** (Ronda 1): bajas medianas de las victorias ≤ 65 % (medido **60 %**), tope **75 %** para las que defienden el abordaje (medido 75 %), 92 % si no lo defienden (medido 81 %), y como mucho el 15 % de las victorias por encima de 80 % de bajas (medido 2 de 134). Antes: 73-94 % | `_test_victory_quality` (`play_targets.max_victory_loss_pct`, `victory_loss`) |
| Ruta central a ciegas: tropieza en casi todas las semillas y pierde ≥ 30 % | `rush_central`, `rush_gallop` |
| Sondear solo el eje del centro (o solo el vado sur) **no basta**: el hoyo oculto cobra | `central_center_lane` vs `central_flank_lane`; `south_vado_only` vs `south_full` |
| Rechazar contraataques y evacuar heridos paga (menos pérdida por contraataque, no menos victorias); con captura activa hay una ventana de decisión cada ≲ 90 s | `central_flank_noreply`, `south_noreply`; ventana en todas las victorias |
| **Ruta sur: mejor victoria < 960 s** y **exposición centro/sur ≥ 1,4**; la central gana antes (media < 900 s) y la sur con menos bajas | `south_full` vs `central_flank_lane` |
| Las victorias duran entre 10 y 18 min | tiempos de todas las victorias |
| Salir tarde pierde; pasividad pierde exactamente en t=1080 s | `late_all_in`, `passive` |
| La métrica de bajas queda entre 0 y 100 en todas las partidas (`campaign_report().loss_total_pct`) | todas |
| Guardar/cargar en cualquier momento: estado idéntico (1e-6); guardado compacto bajo 3 MB **medido en bytes**, con recorte de registro, órdenes y sondas | `_test_justine_persistence`, `_test_save_size`, `_test_labels_and_save_trim` |
| Ningún grupo supera las velocidades de la sección 3 | muestreo de posiciones |

**Cambios de objetivos de balance respecto de la pasada anterior** (con justificación, en `play_targets`): `max_win_share` 0,7 → 0,6 (pedido de la revisión), `strategies_min` 8 → 10 y `seeds_min` 6 → 8 (matriz de 18 x 8), `recon_then_south.victory_before_s` se mantiene en 960 s y ahora se exige al **mejor caso** (912 s medidos; la media sur es 935 s y varias semillas pasan de 960 s: la sur es lenta a propósito), `central_vs_south_exposure_ratio_min` se mantiene en 1,4 (1,58 medido). Para lograrlo se tocó: alcance del buque 280 → 265 m, arcos de cuartel/popa 0,5/0,25 → 0,4/0,15, daño 3,2-5,0 → 7,8-11,9, fuego sobre quien aborda x0,5 → x0,3, ritmo de captura 0,30 → 0,55 %/s, validez de la orden de avance 300 → 420 s, sondeo hasta 1,3 m y costos de tropiezo. Son números de **Diseño**; no hay datos históricos que los sustenten.

## 11. Lo que no se verificó

- **(Ronda 1: se miró `vidal_05` y las láminas del paquete; el resto sigue sin calco.) Las láminas de `docs/referencias/justina/` no se miraron una por una**: las posiciones de barranca, playa y Plaza de Toros se tomaron de la síntesis y de los hallazgos, no de un calco sobre Vidal. La Vista debe contrastar la silueta con `vidal_05` y `vidal_02` y proponer ajustes por contrato.
- Las cifras de Gillespie (pp. 28-29, 94 y 390) vienen del OCR o de la transcripción del Ideario; la Ronda 1 las cotejó con el OCR local (p. 94 y pp. 28-29 coinciden con el paquete); falta cotejar con el escaneo. Los enlaces concretos de La Nación y Recalada para el lugar del varado no están en la bibliografía de `docs/historia/FUENTES.md`: hay que incorporarlos y cotejarlos. El total de efectivos (100 contra 180) no está confirmado: el juego **no** muestra cifras de hombres, solo fuerza relativa.
- Ninguna cifra de diseño (tiempos, velocidades, daños, costes) se jugó con personas. Las estrategias están scripteadas con conocimiento del mapa que un jugador no tiene al principio. Ahora las semillas cambian el **fondo oculto** (flanco central y hoyo del banco sur) además del azar del fuego; aun así el balance es sensible: variar el daño del buque entre 7,5 y 8,2 pasa la ruta central de ~100 % a ~15 % de victorias. Con 8 semillas el ruido es grande: la variante `central_flank_pair` ganó 8/8 en las semillas de la matriz y 6/10 en otras diez (29-67), y `central_flank_lane` 5/8 y 2/10; la ventaja del par no es un defecto del guion sino de diseño: **dos exploradores comparten una sola ventana de fuego de cobertura (8 de munición) y dejan pólvora para rechazar contraataques**. Esta es la estrategia más fuerte de la matriz (≈ 78 % en 18 semillas) y **no cumple una lectura estricta de «ninguna estrategia gana más del 60 %»**; sí cumple la de reparto de victorias (≤ 60 % del total, 33 % medido).
- La posición real de la batería, la Plaza de Toros y el campamento se dan por reconstrucción; no hay plano de la ribera de 1806.
- La interfaz (pista UI) **todavía no conoce** `probe_careful`, `repel`, `evacuate` ni `scout_risk`: las acciones aparecen como botones genéricos (sin tecla ni modo de apuntado para el sondeo cauteloso), y `main.gd` no muestra `resources().signals_left`/`ammo_reserve` ni `state.counter`. Los tests de integración (181 comprobaciones) siguen en verde con ese estado, pero hace falta el trabajo de UI para jugar las decisiones nuevas.

## 12. Ronda 1 (30-oct-2026): mapa e historia con el paquete Justina_Retiro_1806

Pista «Mapa e historia». Objetivo: reconstruir el mapa y los hechos con el paquete del usuario, sin romper el balance. Cambios (todo en `data/justina_map.json`, `map_version` 4, salvo lo indicado):

**Geografía.**
- Cresta, pie de barranca y línea de agua inicial **irregulares** (12 puntos), con la meseta a 9-14 m. Las bajadas pasan de 24 a 40 m de ancho (el planificador de rutas cortaba la esquina de la barranca y dejaba grupos «bloqueados»).
- `bed_warp` (nuevo, regla en `game_rules.gd::_bed_warp`): desplaza el perfil base del fondo ±10-28 m según z entre el pie de la barranca y x≈400, con valor cero en ambos extremos. La playa baja y la franja húmeda con la bajante quedan con bahías y meandros; bancos, canal, vados y hoyos no se mueven.
- Plaza de Toros: circunradio 45 m (era 24), octogonal, centro (112,225). Piezas de a 18 en (148,176); campamento (148,292); puesto de Liniers (140,345). **Camino de la barranca** (Alameda) reducido a ~125 m, sin árboles, Diseño. Decorado nuevo (`scenery`): cuarteles bajos, casas, tapias, huellas, carros, bote, vegetación dispersa. Contexto fuera del área jugable (`context`): ver 1.0.
- Buque: envolvente 40 x 9 m (`hull.length_m/beam_m`), mesana dañada como hipótesis (`ship.rigging`), candidatos de posición A/B, composición de la dotación.
- Estados del agua (`tide.states`) y variante alternativa «banco expuesto» registrada y no implementada (`tide.alternative_variant`).

**Historia y presentación.** `forces` (conjuntos y composiciones con estado de fuente), `characters`, `banners` (Red Ensign como hipótesis, bandera blanca del circo como inferencia, Union Flag «del Retiro» y guion del 71.º como variantes no dibujadas, lista de prohibidos), `palette` (12 colores del paquete más terreno y agua propios), `scenery`, `context`. Textos de briefing y nota histórica corregidos (cadete de Infantería; 400 m = tradición discutida). `history.json`: cuatro hechos nuevos, tres corregidos, fuentes S13-S28.

**Balance (re-medido).** Los cambios de geometría y de textos movían poco la matriz; lo que reajustó el balance fue la mortalidad. Parámetros que cambiaron respecto de la Ronda 7 anterior:

| Parámetro | Antes | Ahora | Razón |
|---|---|---|---|
| `ship.fire.damage_min` / `damage_max` | 7,8 / 11,9 | **8,2 / 12,4** | Ver abajo: con el abordaje menos castigado, el cruce expuesto sigue cobrando |
| `ship.capture.boarding_exposure_mult` | 0,3 | **0,12** | Quien aborda recibe menos fuego (ya está a cubierto bajo la borda); aligera lo que más pesaba en la ruta sur |
| `ship.capture.melee_loss_per_s` | 0,05 | **0,03** | El cuerpo a cuerpo era la segunda causa de bajas del abordaje largo |
| `ship.capture.counter.damage` / `capture_loss_pct` | 22 / 8 | **16 / 9** | El daño baja pero retroceder por no responder duele más: responder (Rechazar, Evacuar) sigue valiendo |
| `barranca.ramps[].width_m` | 24 | **40** | Robustez de rutas (ver arriba) |
| `actions.muster.radius_m` | 30 | **45** | Misma distancia al borde del circo ensanchado |

Resultado (matriz de 18 estrategias x 8 semillas de calibración; tabla completa en `docs/DISENO_REGLAS.md`): las estrategias buenas ganan 8/8 con **55-58 % de bajas** (antes 74-86 %), la ruta sur gana 8/8 con 55 % en 900 s (15,0 min) y la central en 11-13 min; ciegas, pasiva y tardía siguen en 0; ninguna estrategia concentra más del 15 % de las victorias (8 de 55). Validación (12 semillas nuevas): `central_flank_lane`, `central_flank_pair`, `central_hasty` y `south_full` ganan 12/12, `central_center_lane` 5/12, `mixed_split` 7/12, las `noreply` 9 y 10 de 12; las ciegas, 0. **Limitaciones**: (a) los guiones son más hábiles que una persona que juega por primera vez, por eso la cohorte incluye estrategias incompletas que pierden (`central_bare`, `south_vado_only`, `south_bare`, `central_flank_stagger`) y la tasa de la cohorte es solo un proxy del 40-60 %; (b) con guiones deterministas el balance es un precipicio (daño mínimo 6,6 → casi todas las `noreply` ganan; 8,2 → hay un compromiso), y en validación las `noreply` ganan más que en calibración: **hay que jugarlo con personas**; (c) el intercambio sur-centro se redujo (55 % de bajas del sur contra 58 % de la central) y se mantuvo por pocos puntos.

**Decisiones que no se tomaron** (a decidir con el usuario): adoptar 900 x 750 como zona jugable; implementar el estado «banco localmente expuesto»; mover el buque a la posición B; usar la bandera Union «del Retiro»; dibujar al capitán con nombre (Morris/Dunn no está verificado).
