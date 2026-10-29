# Diseño del escenario Justina (rediseño 2026-10-29, segunda pasada de Reglas)

Documento de diseño del escenario rediseñado. Decisión del usuario: **escala real (1 unidad = 1 m), mapa de ~900 x 520 m, buque a unos 390 m del pie de la barranca, con minimapa y cámara libre**. Los números viven en `data/justina_map.json` (único origen, `map_version` 2); este texto los explica y no debe contradecirlos. La API entre pistas está en `docs/CONTRATO_JUSTINA.md`; los cambios de esta pasada respecto del contrato están en `docs/DISENO_REGLAS.md` ("Cambios de la segunda pasada").

## 0. Etiquetas de fuente

Todo dato, lugar o regla lleva una de estas etiquetas, en el JSON (`tag`) y en pantalla (glifo + color). **Documentado solo se usa para lo que respalda una fuente primaria o sólida** (Gillespie 1818, planos de 1801 y vistas de Vidal); lo que repiten fuentes divulgativas es Reconstrucción.

| Etiqueta | Glifo | Significa |
|---|---|---|
| **Documentado** | ● | Sustentado por fuente primaria o sólida citada en `docs/historia`. |
| **Tradición** | ◆ | Atribución transmitida y no probada (Güemes al frente de los jinetes; Ideario pp. 33, 390-392). |
| **Reconstrucción** | ◇ | El hecho o el lugar viene de fuentes secundarias o divulgativas, o la forma exacta se infiere de planos y vistas posteriores (Vidal 1816-20, Boneo 1801). |
| **Diseño** | ▲ | Regla, cifra o geografía inventada para jugar. No es dato histórico. |

### Qué es histórico y qué no (lo mínimo que el juego debe respetar)

| Afirmación | Etiqueta | Fuente / nota |
|---|---|---|
| Era un **buque mercante británico de 26 cañones**, que **combatió el día de la rendición** y fue tomado por **caballería** al cerrar el 12 de agosto de 1806 "por una súbita bajada del río". | Documentado | Gillespie 1818 (traducción reproducida en el Ideario, pp. 28-29, 94 y 390 por OCR/transcripción; falta cotejar con el escaneo). **Sin tipo, tonelaje ni capitán**: no rotular fragata/goleta ni inventar nombre. |
| Varó **frente al Retiro**, cerca de la **Plaza de Toros** (hoy Plaza San Martín) y de la **batería Abascal**, con la barranca y la Alameda en tierra. No es Quilmes ni Barragán. | **Reconstrucción** (confianza media-alta en el Retiro) | **El lugar NO viene de Gillespie**: lo sostienen fuentes divulgativas (edisalta, La Nación, Recalada). La Plaza de Toros sí figura en el plano de Boneo-Villalonga 1801. La equivalencia con la Torre Monumental es de confianza media/baja: **no se dibuja**. |
| La caballería era la de **Pueyrredón**; **Liniers** ordenó avanzar. | **Reconstrucción** | Obligado 1920 y divulgación; Gillespie solo dice "caballería". |
| **Güemes como jefe de los jinetes**. | **Tradición, no probada** | Obligado lo hace ayudante de Liniers que lleva la orden a Pueyrredón; la tropa montada era de Pueyrredón. Ideario p. 33. Gillespie y Concha no lo nombran. |
| La costa de 1806 estaba **al pie de la barranca** (Plaza de Toros). | Reconstrucción | La línea de agua inicial del juego queda a ~20 m del pie. |
| Distancia al buque "menos de 400 m". | Cifra divulgativa sin cita primaria (**marcada como tal**; en el JSON `distance_tag: diseno`) | Se mide **desde el pie de la barranca** (x≈190) hasta el casco (x=580): 390 m. Ya no se mide desde una orilla adelantada 120 m. |
| Profundidad al final "pecho o cuello de los caballos" (1-1,5 m). | Divulgación, sin sondeo de época | Se usa 1,0 m en el vado de abordaje (diseño). |
| El Plata puede subir o bajar 2,1-2,4 m de golpe por el viento. | Documentado (Gillespie) | El viento del 12/8/1806 **no** está documentado. |
| Ocurrió sin bandera argentina, sin Infernales, sin San Martín. | Regla de CLAUDE.md | El buque era británico y se dibuja sin bandera nacional; si lleva insignia, genérica y marcada reconstrucción. |
| Todo lo demás: bancos, canal, vados, hoyos, tiempos, cifras de fuerza, munición, cuerpo a cuerpo, puesto de Liniers, **la orden de avance de 300 s**. | **Diseño** | No hay carta de sondeo de 1806 del Retiro. |

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

### 1.1 Tierra

| Elemento | Posición (m) | Etiqueta |
|---|---|---|
| **Alameda** (calle sobre la barranca) | polilínea x≈138-154, de z=0 a 520 | Documentado (existencia) / Reconstrucción (trazado) |
| **Plaza de Toros del Retiro** | centro (134, 225), radio 24 | Documentado (lugar, plano de 1801) / Reconstrucción (posición junto a la cresta) |
| **Campamento de Pueyrredón** | centro (140, 275), radio 20 | Reconstrucción (fuentes secundarias) |
| **Batería Abascal** | (156, 205), 22 x 14 m, sobre la cresta | **Reconstrucción** (existencia y zona por fuentes divulgativas; sin plano ni documento primario cotejado). Que su fuego llegue al buque (rango 600 m): Diseño |
| **Puesto de mando de Liniers** | (148, 345), radio 12 | **Diseño**: el lugar donde estuvo Liniers no está documentado |
| **Cresta de la barranca** | x≈148-164, altura 8-15 m | Reconstrucción |
| **Pie de la barranca** | x≈178-194, elevación 3,0 m | Reconstrucción |
| **Bajadas** (únicos pasos de la barranca) | `bajada_norte` (178,190) y `bajada_sur` (172,335), 24 m de ancho | Diseño |
| **Playa alta** (franja seca al pie) | x≈186-208 | Reconstrucción |
| **Cañaverales y carretas** (obstáculos) | `canaveral_norte` (250,120), `canaveral_sur` (240,470), `carretas_varadas` (218,345) | Diseño |

Salida de los grupos: en la franja de playa alta, a ~10 m de la línea de agua inicial: Vanguardia (199,240), voluntarios (200,268), reserva (198,296). Exploradores en (204,255) y (204,283).

### 1.2 Río, orilla y buque

- **Línea de agua inicial** (`shore_high`): x≈210 (nivel 1,65 m), a ~20 m del pie de la barranca. Los **390 m** hasta el buque (x=580, z=262) se miden **desde el pie de la barranca** (x≈190); desde la línea de agua hay ~370 m. Cifra divulgativa, marcada como tal.
- **Buque Justina**: centro (580, 262), casco de 16 m de radio, fondo -1,5 m. Proa al norte; la banda de 13 cañones (de los 26 documentados; el reparto es diseño) mira al oeste, hacia tierra. Se dibuja genérico, británico, sin bandera argentina.
- **Perfil base** del fondo (igual en todo z): 3,0 m en el pie de la barranca, 2,4 en x=203, 1,65 en la línea de agua inicial (x=210), 1,2 en x=222, 0,5 en x=245, 0,0 en x=270 (**línea de agua en la bajante máxima**), -0,35 en x=330, -0,7 en x=420, -1,05 en x=500, -1,5 en x=580, -3,0 en el borde este. Todo Diseño.
- **Bancos** (el fondo sube hasta `top_m`; ver `bed_layers_order` para el orden de capas, **con los vados en modo `set`**):

| Banco | Eje (m) | Ancho | Cota superior | Papel |
|---|---|---|---|---|
| **Central** | (272,266) a (500,264) | 40 m | -0,25 m | Ruta **directa**: ~280 m de agua, totalmente en el arco de la banda del buque. Contiene el **pozo oculto** y dos **falsos vados** en sus bordes. |
| **Sur** | (332,404) → (380,430) → (450,455) → (520,440) → (565,390) → (572,320) → (556,282) | 28 m | -0,45 m | Ruta **larga** que llega por la popa del buque (cañones de caza: poca exposición). Solo se alcanza por el **vado sur**. |
| **Norte** | (300,150) a (480,150) | 70 m | -0,10 m | **Señuelo**: sin salida, termina a ~136 m del buque. |

- **Canal de la ribera**: eje (300,320)-(310,480), 36 m de ancho, fondo -2,0 m. Corta el acceso al banco sur. Cruzarlo a ciegas **tropieza** (30 s detenido, +25 fatiga, −22 de fuerza).
- **Vado sur** (oculto): carril (268,400)-(342,406), 20 m de ancho, cota -0,9 m. Abre con nivel ≤ 0,4 m: **t ≈ 355 s** hasta ≈ 989 s para caballos.
- **Vado del buque**: círculo (548,262) de 22 m de radio, cota -1,0 m: profundidad 1,0 m con el río en mínimo. Transitable para caballos con nivel ≤ 0,3 m: **t ≈ 379 a ≈ 982 s**. Para gente a pie (límite 1,2 m) el vado deja de ser vadeable con el río a 0,2 m: **t ≈ 974 s**. Punto de abordaje.
- **Hoyos ocultos** (todos Diseño; quien pasa sin haberlos reconocido **cae** y pierde caballos y jinetes):

| Hoyo | Centro | Radio | Costo del tropiezo |
|---|---|---|---|
| **Pozo del banco central** | (415,264) | 11 m | 35 s detenido, +30 fatiga, **−28 de fuerza** |
| **Falso vado del borde norte** | (352,242) | 9 m | 25 s, +20 fatiga, −18 de fuerza |
| **Falso vado del borde sur** | (372,292) | 9 m | 25 s, +20 fatiga, −18 de fuerza |
| **Canal de la ribera** (si se cruza fuera del vado) | eje del canal | 36 m de ancho | 30 s, +25 fatiga, −22 de fuerza |

  Antes la caída costaba −3 de fuerza: reconocer no pesaba. Ahora un trazado a ciegas por el centro (los tres grupos juntos) pierde ≈ 95 % de la fuerza en las simulaciones.
- Todo lo anterior es **Diseño**: no existe sondeo de 1806 del Retiro.

### 1.3 Información incompleta (fondo desconocido)

El Plata es **turbio**: el jugador **no ve el fondo**. Lo único que sabe a ciencia cierta:
1. Lo **emergido** (altura sobre el agua > 0): bancos y barro que ya asoman.
2. Los **carriles reconocidos** por exploradores (franja de 6 m) y los **vados marcados** (corredor de 16 m).
3. Para todo lo demás vale la **estimación**: perfil base suave, sin bancos, canal, vados ni pozos. La ruta calculada por el planificador usa solo este conocimiento; la simulación aplica el fondo **real**.

El resultado jugable: la ruta central parece buena en el mapa y esconde tres trampas; la ruta sur parece cortada por un canal "invisible" y exige descubrir el vado. Reconocer el centro cuesta: el explorador entra en el arco de la banda del buque (ver 5) y solo puede empezar cuando el agua baja de ~0,85 m sobre el banco (t ≳ 270 s).

## 2. Tiempos

| Hito | t (s) | Nivel (m) |
|---|---|---|
| Alta inicial | 0-60 | 1,65 |
| **Bajante** (lineal) | 60-450 (**390 s ≈ 6,5 min**) | 1,65 → 0,0 |
| Mínimo sostenido | 450-960 | 0,0 |
| Subida (lineal) | 960-1080 (120 s) | 0,0 → 1,65 |
| **Plazo** | 1080 (18 min) | derrota si no hay captura |

Partida objetivo **12-18 min**. En las simulaciones las victorias duran entre 13,1 y 16,6 min. La bajante es un **temporizador visible** con barra de nivel y marcas de profundidad (Diseño, anclado en Gillespie y en una bajante moderna típica de ~1,65 m). El plazo es de 18 min (antes 15) porque el abordaje ya no es instantáneo (ver 5): el riesgo real es que **el agua que sube alcance a los que están a pie en el vado** (~t 974 s).

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
2. **Prepararse** (≈0-300 s): reunir jinetes (cuesta 4 de munición y +20 de fatiga), abastecer munición, **señalar a Liniers cuando falte poco para cruzar** (la orden vale 300 s) y reconocer. No hay espera pasiva: cada tarea saca al grupo de la playa y la bajante no espera.
3. **Reconocer y decidir ruta** (≈250-450 s): el centro exige sondear **bajo el fuego del buque** (el explorador cae en ≈ 12 descargas (≈ 90 s) si es el único blanco; el fuego de distracción lo alarga) o aceptar el riesgo a ciegas; el sur se reconoce a salvo, fuera del alcance, pero es más largo. Se puede dividir fuerzas.
4. **Cruzar** (≈330-600 s): marcha con el ritmo elegido, fuego de distracción en las ventanas de 45 s (8 de munición, recarga 90 s), a la vez o escalonados. Cada grupo que cruza solo recibe todo el fuego.
5. **Abordar y sostener** (≈550-1000 s): llegar al vado, desmontar (12 s) y **mantener el abordaje** mientras el buque dispara (x0,5), la dotación pelea cuerpo a cuerpo (0,06 de fuerza por segundo por grupo mientras tenga moral) y el agua sube. Decidir cuándo cargar con todo, cuándo cubrir con fuego (baja la moral 3 por uso) y cuándo retirar a un grupo que flaquea (puede, monta y vuelve).
6. **Cierre**: victoria al 100 % de captura; si el río alcanza a la gente a pie en el vado, se ahoga.

## 5. Acciones (10) con coste y efecto

Cifras en `actions` del JSON.

| # | Acción (id) | Quién | Coste | Efecto | Etiqueta |
|---|---|---|---|---|---|
| 1 | **Mover** (`move`, ritmo walk/trot/gallop) | grupo | tiempo de marcha + fatiga por segundo | Marcha a un punto. La ruta se calcula con lo que el jugador sabe. | Diseño |
| 2 | **Reconocer fondo** (`probe`) | explorador | ocupa al explorador; hasta 3 puntos; 1,0 m/s en agua, 3,0 m/s en seco; no entra en agua > 1,1 m; **4 de salud, cada descarga lo acierta con probabilidad 0,4 x exposición** | Revela el fondo real en una franja de 6 m: aparecen pozos y vados. | Diseño |
| 3 | **Marcar vado** (`mark_ford`) | explorador | 1 baliza por cada 10 m (16 al inicio), trabaja a 1,0 m/s; solo sobre un tramo ya sondeado | Ensancha el carril a 16 m: columna a velocidad plena y sin tropiezo. | Diseño |
| 4 | **Reunir jinetes** (`muster`) | grupo | subir por una bajada hasta la Plaza de Toros; 40 s allí; **4 de munición**; sale del reservorio de 60; **+20 de fatiga** (reclutas sin entrenar) | +20 de fuerza (tope 100). | Diseño |
| 5 | **Distraer con fuego** (`distract_fire`) | global | 8 de munición; reutilizable cada 90 s | 45 s con la exposición a la mitad; el buque pierde **3** de moral y tarda 2 s más entre descargas. Dispara la batería Abascal y tiradores de la barranca. | Diseño |
| 6 | **Abastecer munición** (`resupply`) | grupo | subir hasta la batería; 25 s allí | +16 de munición (tope 40; arranca en **12**). | Diseño |
| 7 | **Señalar a Liniers** (`signal_liniers`) | grupo | ir al puesto de mando (148,345), 10 s allí | Concede la **orden de avance durante 300 s** (necesaria para `board`; vencida hay que volver a señalar) y +8 de munición. | **Diseño** (que Liniers ordenó avanzar lo cuenta Obligado, fuente secundaria; Güemes como mensajero es tradición y **no se afirma**) |
| 8 | **Cargar y abordar** (`board`) | grupo | requiere orden de avance vigente; llegar al vado del buque; desmontar 12 s | Suma poder de captura 0,30 %/s por unidad de fuerza; baja la moral de la dotación 0,12/s. Los caballos quedan en el vado. Costo: fuego x0,5, cuerpo a cuerpo y agua que sube. | Documentado (el hecho) / Diseño (cifras) |
| 9 | **Retirar** (`withdraw`; `retreat_all`) | grupo / global | la marcha de vuelta | Vuelve a la playa seca; **también desde el abordaje** (los jinetes montan los caballos del vado). `retreat_all` termina la partida como derrota ordenada. | Diseño |
| 10 | **Reagrupar** (`rally`) | grupo | tiempo | En la playa seca y fuera de alcance: -0,18 fatiga/s, +0,025 fuerza/s. | Diseño |

Más `cancel` (anula la orden en curso).

### Fuego del buque (el castigo)

Cada **7,5 s** el buque dispara una descarga contra un objetivo dentro de **280 m** (alcance Diseño). Daño 3,2-5,0 × exposición × moral de la dotación (mín. 0,2). Exposición por rumbo desde el buque: banda (±40° del oeste) **1,0**; cuartel (hasta ±70°) **0,5**; popa/proa **0,25**. Quien desmonta o aborda recibe el **fuego x0,5**. En la playa y el barro no hay fuego (fuera de alcance): el riesgo empieza donde empieza el agua. En las simulaciones el centro acumula ≥ 1,4 veces la exposición de cruce de la ruta sur con los mismos recursos (1,69 en la matriz).

### Abordaje: costo y agua que sube

- **Cuerpo a cuerpo**: cada grupo que aborda pierde 0,06 de fuerza por segundo × moral de la dotación/100. Con la dotación quebrada casi nada.
- **Agua que sube**: quien está desmontando o abordando con una profundidad mayor que 1,2 m pierde `3,0 × (exceso + 0,1)` de fuerza por segundo. Con el río en mínimo nadie se ahoga.
- **Poder de captura** = fuerza/100 × (1 − 0,004 × fatiga, mínimo 0,4).

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

Medidos con 11 estrategias scripteadas x 6 semillas (66 partidas) sobre el juego real, no con un modelo aparte. Resultados en `docs/DISENO_REGLAS.md`.

| Criterio | Cómo se comprueba |
|---|---|
| Ninguna estrategia gana más del 70 % de las victorias y al menos 3 ganan en la mitad o más de las semillas | `_test_strategies` (`play_targets.dominance`) |
| Hay victorias por el centro y por el sur; ninguna ruta acumula más del 75 % | `_test_strategies` |
| Ruta central a ciegas: tropieza en todas las semillas, pierde ≥ 30 % y no gana | `rush_central` |
| Reconocer + central: solo tropieza si el explorador cayó antes de hallar el pozo | `probed_central_full` |
| Sur: gana en la mitad o más de las semillas, con ≥ 60 s de margen antes de que el agua alcance a la gente a pie; exposición del centro ≥ 1,4 × la del sur | `south_full` vs `probed_central_full` |
| Las victorias duran 12-18 min | tiempos de todas las victorias |
| Salir tarde pierde; pasividad pierde exactamente en t=1080 s | `late_all_in`, `passive` |
| Guardar/cargar en cualquier momento: estado idéntico (1e-6); guardado compacto bajo 3 MB | `_test_justine_persistence`, `_test_save_size` |
| Ningún grupo supera las velocidades de la sección 3 | muestreo de posiciones |

## 11. Lo que no se verificó

- **Las láminas de `docs/referencias/justina/` no se miraron una por una**: las posiciones de barranca, playa y Plaza de Toros se tomaron de la síntesis y de los hallazgos, no de un calco sobre Vidal. La Vista debe contrastar la silueta con `vidal_05` y `vidal_02` y proponer ajustes por contrato.
- Las cifras de Gillespie (pp. 28-29, 94 y 390) vienen del OCR o de la transcripción del Ideario; falta cotejar con el escaneo. Los enlaces concretos de La Nación y Recalada para el lugar del varado no están en la bibliografía de `docs/historia/FUENTES.md`: hay que incorporarlos y cotejarlos. El total de efectivos (100 contra 180) no está confirmado: el juego **no** muestra cifras de hombres, solo fuerza relativa.
- Ninguna cifra de diseño (tiempos, velocidades, daños, costes) se jugó con personas. Las estrategias están scripteadas con conocimiento del mapa que un jugador no tiene al principio; las semillas solo cambian el azar del fuego, así que muchas estrategias dan el mismo resultado en las seis.
- La posición real de la batería, la Plaza de Toros y el campamento se dan por reconstrucción; no hay plano de la ribera de 1806.
- La prueba de integración de la interfaz (`tests/test_integration.gd`) no se ajustó a la nueva geografía y a la nueva línea de tiempo: ocho de sus comprobaciones fallan (selección por caja, nombre del lugar, tiempos de la bajante y del sondeo). Es trabajo de la pista UI.
