# Diseño del escenario Justina (rediseño 2026-10-29)

Documento de diseño del escenario rediseñado. Decisión del usuario: **escala real (1 unidad = 1 m), mapa de ~900 x 520 m, buque a ~380-400 m de la orilla, con minimapa y cámara libre**. Los números viven en `data/justina_map.json` (único origen); este texto los explica y no debe contradecirlos. La API entre pistas está en `docs/CONTRATO_JUSTINA.md`.

## 0. Etiquetas de fuente

Todo dato, lugar o regla lleva una de estas etiquetas, en el JSON (`tag`) y en pantalla (glifo + color):

| Etiqueta | Glifo | Significa |
|---|---|---|
| **Documentado** | ● | Sustentado por fuente citada en `docs/historia` o `docs/investigacion`. |
| **Tradición** | ◆ | Atribución transmitida y no probada (Güemes al frente de los jinetes; Ideario pp. 33, 390-392). |
| **Reconstrucción** | ◇ | El hecho es documentado, pero la forma o posición exacta se infiere de planos y vistas posteriores (Vidal 1816-20, Boneo 1801). |
| **Diseño** | ▲ | Regla, cifra o geografía inventada para jugar. No es dato histórico. |

### Qué es histórico y qué no (lo mínimo que el juego debe respetar)

| Afirmación | Etiqueta | Fuente / nota |
|---|---|---|
| El buque varó frente al **Retiro**, junto a la **batería Abascal**, cerca de la **Plaza de Toros** (hoy Plaza San Martín), con la barranca y la Alameda en tierra. No es Quilmes ni Barragán. | Documentado (fuentes secundarias; confianza alta en el Retiro) | síntesis 1.1; hallazgos JSON. La equivalencia con la Torre Monumental es de confianza media/baja: **no se dibuja**. |
| Era un **buque mercante de 26 cañones**. | Documentado | Gillespie 1818 (pp. 28-29, 94 por OCR; falta cotejar con el escaneo). **Sin tipo, tonelaje ni capitán**: no rotular fragata/goleta ni inventar nombre. |
| Lo tomó la **caballería de Pueyrredón** al cierre del 12 de agosto por una **súbita bajada del río**. | Documentado | Gillespie 1818; Obligado 1920 (secundaria). |
| **Güemes como jefe de los jinetes**. | **Tradición, no probada** | Obligado lo hace ayudante de Liniers que lleva la orden a Pueyrredón; la tropa montada era de Pueyrredón. Ideario p. 33. Gillespie y Concha no lo nombran. |
| Distancia al buque "menos de 400 m". | Cifra divulgativa sin cita primaria (**marcada como tal**; en el JSON `distance_tag: diseno`) | síntesis 1.1. |
| Profundidad al final "pecho o cuello de los caballos" (1-1,5 m). | Divulgación, sin sondeo de época | Se usa 1,0 m en el vado de abordaje (diseño). |
| El Plata puede subir o bajar 2,1-2,4 m de golpe por el viento. | Documentado (Gillespie) | El viento del 12/8/1806 **no** está documentado. |
| Ocurrió sin bandera argentina, sin Infernales, sin San Martín. | Regla de CLAUDE.md | El buque se dibuja sin bandera nacional; si lleva insignia, genérica y marcada reconstrucción. |
| Todo lo demás: bancos, canal, vados, pozo, tiempos, cifras de fuerza, munición, puesto de Liniers. | **Diseño** | No hay carta de sondeo de 1806 del Retiro. |

## 1. Geografía (coordenadas métricas)

Mapa de **900 m (x, este) por 520 m (z, sur)**. El **norte es -z**; el río está al **este (+x)**. Elevaciones en metros sobre el "cero de bajante" (nivel mínimo del río durante la partida).

```
 x=0 ───────── 44 ─ 70 ───────── 190 ──── 270 ───────────── 548 580 ─────── 900
 meseta      barranca  playa alta   playa    bajo/bancos      vado  buque     río abierto
 Alameda     (cresta   (seca       (barro al    (turbio: no se ve el fondo)
 Plaza de     8-15 m)   siempre)    bajar)
 Toros, batería                      ▲ línea de agua inicial (x≈190)
```

### 1.1 Tierra

| Elemento | Posición (m) | Etiqueta |
|---|---|---|
| **Alameda** (calle sobre la barranca) | polilínea x≈18-34, de z=0 a 520 | Documentado (existencia) / Reconstrucción (trazado) |
| **Plaza de Toros del Retiro** | centro (14, 225), radio 24 | Documentado (lugar) / Reconstrucción (posición) |
| **Campamento de Pueyrredón** | centro (20, 275), radio 20 | Documentado (zona) / Reconstrucción |
| **Batería Abascal** | (36, 205), 22 x 14 m, sobre la cresta | Documentado (existencia y zona) / Reconstrucción (posición). Que su fuego llegue al buque (rango 600 m): Diseño |
| **Puesto de mando de Liniers** | (28, 345), radio 12 | **Diseño**: el lugar donde estuvo Liniers no está documentado |
| **Cresta de la barranca** | x≈28-44, altura 8-15 m (`crest_height_m`) | Reconstrucción |
| **Pie de la barranca** | x≈58-74, elevación 3,0 m | Reconstrucción |
| **Bajadas** (únicos pasos de la barranca) | `bajada_norte` (58,190) y `bajada_sur` (52,335), 24 m de ancho | Diseño |
| **Playa alta** (siempre seca) | x 70-190 | Reconstrucción (Vidal 1816-20) |
| **Cañaverales y carretas** (obstáculos) | `canaveral_norte` (130,120), `canaveral_sur` (135,430), `carretas_varadas` (165,345) | Diseño |

Salida de los grupos: en la playa alta, a ~85 m de la línea de agua inicial: Güemes (105,240), voluntarios (110,268), reserva (100,296). Exploradores en (120,255) y (120,283).

### 1.2 Río, orilla y buque

- **Línea de agua inicial** (`shore_high`): x≈185-192 (nivel 1,65 m). Es la "orilla" desde la que se miden los **390 m** hasta el buque (x=580, z=262). Cifra divulgativa, marcada como tal.
- **Buque Justina**: centro (580, 262), casco de 16 m de radio, fondo -1,5 m. Proa al norte; la banda de 13 cañones (de los 26 documentados; el reparto es diseño) mira al oeste, hacia tierra. Se dibuja genérico, sin bandera argentina.
- **Perfil base** del fondo (igual en todo z): 3,0 m en el pie de la barranca, 1,65 en la línea de agua inicial, 0,0 en x=270 (**línea de agua en la bajante máxima**), -0,35 en x=330, -0,7 en x=420, -1,05 en x=500, -1,5 en x=580, -3,0 en el borde este. Mar adentro la pendiente es ~0,004 m/m (síntesis 1.1). Todo Diseño.
- **Bancos** (el fondo sube hasta `top_m`; ver `bed_layers_order` para el orden de capas):

| Banco | Eje (m) | Ancho | Cota superior | Papel |
|---|---|---|---|---|
| **Central** | (272,266) a (500,264) | 40 m | -0,25 m | Ruta **directa**: ~280 m de agua, totalmente en el arco de la banda del buque. Contiene el **pozo oculto**. |
| **Sur** | (332,404) → (380,430) → (450,455) → (520,440) → (565,390) → (572,320) → (556,282) | 28 m | -0,45 m | Ruta **larga** que llega por la popa del buque (cañones de caza: poca exposición). Solo se alcanza por el **vado sur**. |
| **Norte** | (300,150) a (480,150) | 70 m | -0,10 m | **Señuelo**: sin salida, termina a ~136 m del buque. |

- **Canal de la ribera**: eje (300,320)-(310,480), 36 m de ancho, fondo -2,0 m. Corta el acceso al banco sur.
- **Vado sur** (oculto): carril (268,400)-(342,406), 20 m de ancho, cota -0,9 m. Abre con nivel ≤ 0,4 m (desde t≈295 s hasta ≈688 s para caballos).
- **Vado del buque**: círculo (548,262) de 22 m de radio, cota -1,0 m: profundidad 1,0 m con el río en mínimo. Transitable para caballos con nivel ≤ 0,3 m: **t ≈ 315 a ≈ 677 s** (calculado sobre el perfil del JSON). Punto de abordaje.
- **Pozo central** (oculto): círculo (415,264) de 11 m de radio, fondo -1,9 m (intransitable para caballos casi siempre). Quien pase sin haberlo reconocido **tropieza**: 20 s detenido, +12 fatiga, -3 de fuerza.
- Todo lo anterior es **Diseño**: no existe sondeo de 1806 del Retiro.

### 1.3 Información incompleta (fondo desconocido)

El Plata es **turbio**: el jugador **no ve el fondo**. Lo único que sabe a ciencia cierta:
1. Lo **emergido** (altura sobre el agua > 0): bancos y barro que ya asoman.
2. Los **carriles reconocidos** por exploradores (franja de 6 m) y los **vados marcados** (corredor de 16 m).
3. Para todo lo demás vale la **estimación**: perfil base suave, sin bancos, canal, vados ni pozos. La ruta calculada por el planificador usa solo este conocimiento; la simulación aplica el fondo **real**.

El resultado jugable: la ruta central parece buena en el mapa y esconde un pozo; la ruta sur parece cortada por un canal "invisible" y exige descubrir el vado.

## 2. Tiempos

| Hito | t (s) | Nivel (m) |
|---|---|---|
| Alta inicial | 0-45 | 1,65 |
| **Bajante** (lineal) | 45-375 (**330 s ≈ 5,5 min**) | 1,65 → 0,0 |
| Mínimo sostenido | 375-645 | 0,0 |
| Subida (lineal) | 645-825 (180 s) | 0,0 → 1,65 |
| **Plazo** | 900 (15 min) | derrota si no hay captura |

Partida total objetivo: **12-18 min**; una buena partida termina hacia los 10-13 min. No se simula el viento: la bajante es un **temporizador visible** con barra de nivel y marcas de profundidad (Diseño, anclado en Gillespie y en una bajante moderna típica de ~1,65 m).

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

Fatiga por segundo: caminar 0,02; trote 0,05; galope 0,12; ×1,5 en barro; ×1,6 en agua.

## 4. Bucle del jugador

1. **Mirar** (0-45 s, río alto): el mapa muestra solo orilla, barranca, hitos y el buque. Hay que decidir cómo distribuir la bajante.
2. **Reconocer** (≈45-250 s): los exploradores sondean la playa de barro y los bancos que van asomando; el jugador marca vados, reúne jinetes y abastece munición mientras el río baja. No hay espera pasiva.
3. **Decidir ruta** (≈250-330 s): central (corta, expuesta, pozo oculto) o sur (larga, poco expuesta, vado por descubrir), o dividir fuerzas. Pedir la orden de avance a Liniers.
4. **Cruzar** (≈300-480 s): marcha con ritmo elegido, fuego de distracción desde la barranca, retirar a quien se rompe.
5. **Abordar** (≈400-700 s): llegar al vado del buque, desmontar (12 s), captura progresiva con los grupos que lleguen.
6. **Cierre**: victoria al 100 % de captura; si sube el río los caballos se retiran solos al vado seco.

Cada fase pide una decisión distinta: ya no hay dos rutas que ganen con el mismo porcentaje de fuerza.

## 5. Acciones (10) con coste y efecto

Cifras en `actions` del JSON.

| # | Acción (id) | Quién | Coste | Efecto | Etiqueta |
|---|---|---|---|---|---|
| 1 | **Mover** (`move`, ritmo walk/trot/gallop) | grupo | tiempo de marcha + fatiga por segundo | Marcha a un punto. La ruta se calcula con lo que el jugador sabe. | Diseño |
| 2 | **Reconocer fondo** (`probe`) | explorador | ocupa al explorador; hasta 3 puntos; 1,0 m/s en agua, 3,0 m/s en seco; no entra en agua > 1,1 m; puede recibir fuego (peso 0,15, 3 vidas) | Revela el fondo real en una franja de 6 m: aparecen pozos y vados. | Diseño |
| 3 | **Marcar vado** (`mark_ford`) | explorador | 1 baliza por cada 10 m (16 al inicio), trabaja a 1,0 m/s; solo sobre un tramo ya sondeado | Ensancha el carril a 16 m: columna a velocidad plena y sin tropiezo. | Diseño |
| 4 | **Reunir jinetes** (`muster`) | grupo | subir por una bajada hasta la Plaza de Toros; 40 s allí; sale del reservorio de 60 | +25 de fuerza (tope 100). | Diseño |
| 5 | **Distraer con fuego** (`distract_fire`) | global | 8 de munición; reutilizable cada 90 s | 45 s con la exposición a la mitad; el buque pierde 2 de moral y tarda 2 s más entre descargas. Dispara la batería Abascal y tiradores de la barranca. | Diseño (la batería: Documentada) |
| 6 | **Abastecer munición** (`resupply`) | grupo | subir hasta la batería; 25 s allí | +16 de munición (tope 40; arranca en 16). | Diseño |
| 7 | **Señalar a Liniers** (`signal_liniers`) | grupo | ir al puesto de mando (28,345), 10 s allí | Concede la **orden de avance** (necesaria para `board`) y +8 de munición. La vanguardia lleva el mensaje: es **tradición** de Güemes; que Liniers ordenó avanzar a la caballería lo cuenta Obligado. | Tradición / Diseño (el lugar) |
| 8 | **Cargar y abordar** (`board`) | grupo | requiere orden de avance; llegar al vado del buque; desmontar 12 s | Suma poder de captura 0,19 %/s por unidad de fuerza; baja la moral de la dotación 0,12/s. Los caballos quedan en el vado. | Documentado (el hecho) / Diseño (cifras) |
| 9 | **Retirar** (`withdraw`; `retreat_all`) | grupo / global | la marcha de vuelta | Vuelve a la playa seca. `retreat_all` termina la partida como derrota ordenada. | Diseño |
| 10 | **Reagrupar** (`rally`) | grupo | tiempo | En la playa seca y fuera de alcance: -0,18 fatiga/s, +0,025 fuerza/s. | Diseño |

Más `cancel` (anula la orden en curso).

### Fuego del buque (el castigo)

Cada **7,5 s** el buque dispara una descarga contra un objetivo dentro de **280 m** (alcance Diseño). Daño 3,2-5,0 × exposición × moral de la dotación (mín. 0,2). Exposición por rumbo desde el buque: banda (±40° del oeste) **1,0**; cuartel (hasta ±70°) **0,5**; popa/proa **0,25**. En la playa y el barro no hay fuego (fuera de alcance): el riesgo empieza donde empieza el agua. Con el vado sur la exposición total es ~0,67 de la de la ruta central; con fuego de distracción baja otro 50 % (cálculo de diseño sobre la geometría del JSON; Reglas debe confirmar con tests).

## 6. Victoria y derrota

- **Victoria**: captura 100 %. La dotación se rinde; los caballos no suben a cubierta.
- **Derrota**: (a) todos los grupos dispersos (fuerza ≤ 5); (b) plazo de 900 s sin captura; (c) retirada general.
- El texto de cierre dice siempre **qué es documentado y qué es adaptación** y muestra el parte de campaña (sección 8).

## 7. Cómo se muestra tradición vs documento

- Cada hito, grupo y acción tiene `tag`. En el HUD: glifo y color de `source_tags` (● documentado, ◆ tradición, ◇ reconstrucción, ▲ diseño) junto al nombre, y una línea de fuente al seleccionar.
- La vanguardia se titula **"Vanguardia de jinetes · Güemes"** con glifo ◆; al seleccionarla: "Atribución tradicional, no probada". Pueyrredón (documentado) aparece en la reserva y en el parte.
- Las cifras divulgativas (390 m, profundidad 1,0 m, 26 cañones por banda) se rotulan "cifra divulgativa" o "diseño" en el panel de información y en el parte.
- El briefing inicial dice: "Reconstrucción jugable del 12 de agosto de 1806. Lugares: documentados o reconstruidos. Fondo, bancos, vados y tiempos: diseño."

## 8. Parte de campaña (final)

Reglas entrega `campaign_report()` (contrato). Contenido: resultado y motivo; tiempo; fuerza inicial/final/bajas por grupo; ruta usada (central/sur/mixta); metros sondeados y marcados; tropiezos; munición gastada; nivel del río al abordar; descargas recibidas; y **"Qué fue historia"**: lista de líneas con su etiqueta. La UI lo muestra sin recalcular nada.

## 9. Pistas y propiedad de archivos

| Pista | Archivos propios |
|---|---|
| Reglas | `scripts/game_rules.gd`, `tests/test_rules.gd`, `docs/DISENO_REGLAS.md` |
| Vista | `scripts/world_view.gd`, `assets/`, `tools/create_models.py` |
| UI | `scripts/main.gd`, `tools/ui_qa.gd`, `tests/test_integration.gd` |
| Arquitecto (ya hecho) | `docs/DISENO_JUSTINA.md`, `data/justina_map.json`, `docs/CONTRATO_JUSTINA.md` |

Todo cambio entre pistas pasa por el contrato; no se tocan archivos ajenos.

## 10. Objetivos de balance para los tests de Reglas

Derivados de `play_targets` y de los cálculos del arquitecto (modelo simplificado en Python, **no** el juego real):

| Recorrido scripteado | Resultado esperado |
|---|---|
| Ruta central a ciegas (sin `probe`, sin `mark_ford`), salida t≈250 | Algún grupo **tropieza** en el pozo; bajas ≥ 30 % de la fuerza; puede aun así ganar o perder: debe ser claramente peor que con reconocimiento. |
| Reconocer + marcar el borde norte del banco central, salida t≈330 | Victoria antes de t=760 s. |
| Reconocer el vado sur + ruta sur | Victoria antes de t=800 s; exposición acumulada de la central ≥ 1,4 × la del sur con los mismos grupos. |
| Salir demasiado tarde (llegar al vado después de t≈677 s) | No se puede abordar; derrota por plazo. |
| Pasividad | Derrota exactamente en t=900 s. |
| Guardar/cargar en cualquier momento con sondas y balizas | Estado idéntico (tolerancia 1e-6). |
| Ningún grupo supera las velocidades de la sección 3 en ningún paso | Verificado por muestreo de posiciones. |

## 11. Lo que no se verificó

- **Las láminas de `docs/referencias/justina/` no se miraron una por una en esta pasada**: las posiciones de barranca, playa y Plaza de Toros se tomaron de la síntesis y de los hallazgos, no de un calco sobre Vidal. La pista de Vista debe contrastar la silueta con `vidal_05` y `vidal_02` y proponer ajustes por contrato.
- Las cifras de Gillespie (pp. 28-29 y 94) vienen del OCR; falta cotejar con el escaneo. El total de efectivos (100 contra 180) no está confirmado: el juego **no** muestra cifras de hombres, solo fuerza relativa.
- Ninguna cifra de diseño (tiempos, velocidades, daños, costes) se jugó con personas. Los balances salen de un modelo en Python de rutas y exposición; la simulación real aún no existe.
- La posición real de la batería, la Plaza de Toros y el campamento se dan por reconstrucción; no hay plano de la ribera de 1806.
