# Procedencia de los números y del diseño de nivel

Documento de `reglas_historia` (CONTRATO 1.2). **Estado: R1.** El CONTRATO 2 pide que los JSON no lleven notas de producción (en la Justina el 15 % de los bytes de `justina_map.json` no lo leía nadie): cada entidad lleva su `tag` y un `source` de 120 caracteres o menos, y la historia larga está acá. Este archivo dice de dónde sale cada grupo de cifras de `data/humahuaca_rules.json` y de `data/humahuaca_level.json`, qué es dato de un documento y qué es **diseño** (la inmensa mayoría: el parte de Arias cuenta un resultado, no un reglamento), y qué se tocó al medir. Las fuentes con su sigla (S46 a S54) están en `docs/historia/FUENTES.md` y en `data/history.json`. La procedencia del relieve y del río es de `relieve_mapa` (`docs/humahuaca/CREDITOS_RELIEVE.md`).

## Regla de lectura

- **Dato de una fuente** (●): lo que el parte, un oficio o una carta dicen: el hecho, no la cifra de juego que lo representa.
- **Inferencia** (◇), **versión discutida** (◆) y **sin datos** (○): como en `HISTORIA.md`.
- **Diseño** (▲): una decisión de balance o de representación. Se mueve **contenido** (cifras, reparto, matriz de contrapesos), nunca un multiplicador global, y cada cambio queda escrito acá con su motivo.

## `data/humahuaca_rules.json`

| Clave | De dónde sale | Etiqueta |
|---|---|---|
| `time.*` (alba a los 4:30, luz plena a los 5:30 y 7:00, amanecer a los 6:30, plazo a los 14:00, sorpresa de 45 s) | Diseño. El parte da horas de la marcha, no un reloj de partida; las horas del parte no se trasladan al reloj | ▲ |
| `environment.segments` (lluvia, visibilidad, `time_of_day`, fiabilidad de las armas de chispa) | Lluvia: copiosa la tarde del 27 de febrero (S46, ●); la de la noche y el alba es reconstrucción razonada; visibilidades y fiabilidades, diseño. Las cinco muestras de `time_of_day` las pide `visual` (ADDENDA A-07 y A-08) | ◇ / ▲ |
| `groups.*` (hombres 48/52/50, 2 reconocedores, 6 arrieros y 6 mulas, armas del 25, 30 y 35 %) | Función y nombres: S46 (Rodríguez, Portal y Ontiveros, Arias, «bomberos» = reconocedores). Reparto, armas y mulas propias: diseño. La cifra total de 150 es de Arias; el Diario realista dice 300 | ● la función · ▲ las cifras |
| `objectives.*` (guarnición 24, 66 y 22; cobertura; centinelas; texto de la revelación) | Los tres objetivos y sus nombres: S46. Guarnición total de unos 130 y 6 o 7 piezas: S46, S49 y S50; el reparto por frente es diseño | ● el objetivo · ▲ la guarnición |
| `enemy.*` (alerta, mensajero a los 40 s, oficial de la posta que refuerza el cuartel con 8, patrullas) | El oficial «alcanzado a media cuadra» y el grito de «viva el rey» son del parte (S46); todo lo demás es diseño | ▲ |
| `combat.*` (rango 150 m, bono de sorpresa de 0,8, posturas, toma, bajas, custodia) | Diseño. El parte cuenta el resultado | ▲ |
| `stealth.*` (ritmos, ruido, detección `visibilidad × (1 + 2 × ruido)`, costo de la oscuridad, desvelo, reconocimiento) | Diseño sobre el hecho de que Arias reconoció «con la mayor cautela» y de que la guardia «lo había esperado noches antes» | ▲ |
| `tower.*` (12 descargas de 7,5 s, radio 90 m, ángulo muerto de 12 m, daño por descarga) | El hecho (fuego «indecible» desde una torre, hora y media) es de S46; qué torre, dónde, la cadencia y su compresión a unos 90 segundos son diseño u ○ | ● el hecho · ○ la torre · ▲ las cifras |
| `actions.*` | Diseño; `hide` es ◆ («ocultos o enterrados», S49) | ▲ / ◆ |
| `loot.*` (clases, puntos, pesos, capacidad de 2 200 kg, tratamientos ×1 / ×0,35 / ×0,7) | La existencia de cañones, fusiles, víveres, pólvora y la dificultad de llevarlos: S46. Cantidades, pesos y puntos: diseño. La plata es versión de oídas de Portal (S51, ◆) | ● / ◆ / ▲ |
| `transport.*` (12 kg/s por equipo, 3 equipos, vado a media velocidad, ritmo de mula) | Diseño | ▲ |
| `reinforcement.*` (demoras de 240, 300 y 360 s, aviso a los 60 s, humo, banda inicial) | Diseño. **No ocurrió**: los realistas se enteraron el 4 de marzo (S49, S50) | ▲ |
| `variants.*` (guardia, torre, refugio, lluvia, refuerzo, planta) | Cada incertidumbre del dossier convertida en variante: diseño | ▲ |
| `outcome.*` (victoria, ocho causas, medallas) | Diseño. Las medallas de abril de 1817 son de S51, ●, pero su umbral de juego es ▲ | ▲ |
| `campaign.*` (mundo fijo hasta ganar, diario, controles, consejos) | Aprendizaje entre intentos heredado de la Justina: diseño | ▲ |
| `texts.briefing.carta` | Dramatización de la carta del 26-II (S47): la carta existe y no trae órdenes; el texto del juego es una lectura adaptada, rotulada | ▲ |
| `epilogue.lines` | Cada línea con su fecha, etiqueta y fuente (S46, S49, S50, S51) | ● / ◆ |

## `data/humahuaca_level.json`

| Clave | De dónde sale | Etiqueta |
|---|---|---|
| `features.tapias`, `zanjas`, `acequias` | Existen «tapial» y «zanjita» (S46: el reconocimiento); número, posición, largo y altura son diseño. Los muros del patio de la posta siguen la huella de 30 × 24 m del hito | ▲ |
| `features.barricadas` | El Diario realista (S49) cuenta bocacalles cerradas en enero; si estaban cerradas el 1 de marzo, no se sabe | ▲ |
| `features.camino_cubierto` | Diario realista (S49): camino cubierto entre la iglesia y el reducto; el trazado es diseño | ◇ |
| `features.gola_bateria` | La orientación al este no figura en ninguna fuente: se deduce del camino cubierto («que protegiese la retirada») | ▲ |
| `features.calles`, `manzanas`, `parcelas`, `caminos` | No hay plano de 1817. Planta de manzanas de 54 × 54 m, calles de 8 m: diseño del prototipo | ▲ |
| `access.attack_posts` | Puestos de ataque a 60-120 m del frente, con cobertura: diseño (los verifica una prueba contra `combat.attack_range_m`) | ▲ |
| `access.patrol_routes` | Diseño (R2a las usa) | ▲ |
| `zones[]` (toma, mirador, polvorín, parque, corral) | Los objetivos están en el parte; el polvorín en la posta es inferencia; las huellas son diseño; el corral con 16 mulas figura en el parte («16 mulas capturadas») | ◇ / ▲ |
| `lights[]` (brasero, ventana, candil) | «Luz progresiva» del dossier: la luz de la guardia delata dónde está. Lugar y alcance: diseño | ▲ |

## Lo que se tocó al medir en R1 (y por qué)

Se movieron solo cifras de contenido, nunca un multiplicador global:

1. **Costo de la oscuridad** (`stealth.dark_cost`): puntería en plena noche 0,4 → **0,25** y poder de asalto 0,8 → **0,7**. Con los valores de partida del diseño el barrido del instante de la señal daba un máximo a las 4:00 (el límite inferior que pide la compuerta 7 es 4:15) y una curva casi plana; con estos, el máximo cae entre las 4:15 y las 5:15 y el costo de adelantarse se nota.
2. **Bajas** (`combat.casualty_k`): 0,06 → **0,09**. Las partidas ganaban con 10 % de bajas; con 0,09 pierden 14-16 % y el desvelo del alba cuesta de verdad.
3. **Salir por el este exige carga** (`errores.sin_carga_para_salir`). En el stub, salir sin haber cargado hacía que el arreo se llevara «lo que entra por densidad» al instante y sin viajar: una carga gratis que tiraba abajo la decisión de qué cargar. Ahora lo que se entrega se carga, y cargar cuesta tiempo (`transport`).
4. **Destruir deja el 65 % como valor perdido** (`loot.treatments.destruir` = 0,35): al cierre, entregado, destruido, oculto y perdido suman exactamente 100.
5. **Textos de las ocho causas**: todas llevan el momento (m:ss) y el lugar, con la preposición contraída (`{deLugar}`: «del cuartel», «de la batería»).

Nada de esto cambia una etiqueta: todo sigue siendo ▲.

## Lo que se tocó en el pase 2 de R1 (solo textos y topes de sensatez)

1. **Preposiciones contraídas (BACKLOG B-036).** Cinco plantillas de `texts` (`siguiente.attack`, `siguiente.wait_attack`, `eventos.apoyo`, `eventos.detectado`, `avisos_ruta.cerca`) anteponían «de» o «a» a `{frente}`, que se llena con el lugar («el cuartel»), y el jugador leía «de el cuartel». Ahora usan `{deFrente}` y `{aFrente}` (el lugar con la preposición contraída: «del cuartel», «a la batería»), que `humahuaca_data.gd` deriva solo de `{frente}` y de `{lugar}`. Ninguna cifra ni etiqueta cambia.
2. **Pista de reintento acortada (B-025).** `campaign.tips.dispersos[0]` medía 123 caracteres y el tope es 120: ahora mide 117 y dice lo mismo.
3. **Textos nuevos del guardado y de las paradas** (`texts.guardado` y `texts.errores.parada_fuera`): diseño, sin cifras. Los topes del esquema del guardado (un porcentaje va de 0 a 100, una cantidad de hombres hasta 1 000…) son de sensatez, no de juego: las cifras de juego siguen saliendo solo de `humahuaca_rules.json`.
