# Análisis de diversión de la Justina (Ronda 8, analista de game feel)

Preview 4, rama main (commit 3529ded). Directriz del usuario: la dinámica manda sobre la fidelidad histórica; si perdés, jugás de nuevo, y para pasar al segundo escenario hay que ganar. Acá no se evalúa nada histórico: solo si el juego es entretenido, claro y rejugable.

## 0. Método y límites (leer primero)

- **Qué se hizo**: lectura de `scripts/game_rules.gd`, `scripts/main.gd`, `data/justina_map.json`, `docs/DISENO_JUSTINA.md` (secciones 4, 5, 10, 14-18); revisión de las capturas de `evidence/justina-ui/final_r7/1920x1080/` (`justina-inicio.png`, `justina-mitad-bajante.png`, `justina-parte.png`) y de `evidence/justina-ui/final_r7/recorrido.json`; y un Monte Carlo propio de "jugadores con errores humanos" (ver 0.2).
- **Qué NO se hizo**: no se jugó con ventana ni se capturaron pantallas nuevas (se usaron las de la ronda 7, que corresponden a este mismo commit). `tools/justina_playthrough.gd` se relanzó con APPDATA aislado pero no terminó dentro del tiempo disponible; las cifras de recorrido son las del `recorrido.json` de la ronda 7 (mismas 7 políticas x 3 semillas + `ui_real`). JEV/TypeSafe no se usó (no se buscó clave; sin conclusión sobre él).
- **Ningún dato es de personas.** Todo lo de "humano promedio" es un modelo. Está rotulado como estimación.

### 0.1 Cifras duras (de `recorrido.json`, scripts que conocen el mapa)

| Política | Resultado | Tiempo | Bajas |
|---|---|---|---|
| `rush_central` (ir directo, sin reconocer) | derrota 3/3 (dispersos) | 473-683 s (7,9-11,4 min) | 98-100 % |
| `central_flank_pair`, `_lane`, `_hasty` | victoria 9/9 | 729-768 s (12,2-12,8 min) | 51-66 % |
| `south_full` | victoria 3/3 | 843-867 s (14-14,4 min) | 40-45 % |
| `mixed_split` | derrota 3/3 | 1050-1080 s | 78-100 % (captura 48-56 %) |
| `late_all_in` | derrota 3/3, plazo | 1080 s (18:00) | 0-33 % |
| `ui_real` (clics reales) | victoria 2/3; derrota en semilla 5 | 723-790 s | 64-66 % (derrota: 95 %, **captura 86,7 %**) |

### 0.2 Monte Carlo de "humano con errores" (propio, script de apoyo `mc_r8.gd` en el scratchpad de la sesión, no entra al repo)

Se tomó una mezcla de 15 guiones de `tests/test_rules.gd` (35 % de la mezcla son guiones capaces de ganar; el resto son ciegos, incompletos o apurados, como un novato real) y se les aplicó ruido: tiempos desplazados, y omisión probabilística de cobertura de fuego, rechazo de contraataque, evacuación, reunir, abastecer y sondeo cauteloso. 24 partidas por nivel, semillas al azar (incluye la condición del río sorteada).

| Nivel de "habilidad" | Victorias | Derrota por dispersión / por plazo | Tiempo mediano de victoria | Bajas medianas |
|---|---|---|---|---|
| Novato total (1,0) | **0/24** | 19 / 5 | - | - |
| Torpe (0,7) | 5/24 | 18 / 1 | 13,7 min | 61 % |
| Medio (0,45) | 2/24 | 14 / 8 | 13,1 min | 68 % |
| Bueno (0,2) | 6/24 | 15 / 3 | 14,6 min | 64 % |
| Experto (0,0) | 7/24 | 16 / 1 | 12,4 min | 53 % |

Con n = 24 el ruido es de ±15 puntos y la mezcla pesa mucho (ver la no monotonía entre 0,7 y 0,45). Lo que sí es robusto: **el novato total no gana nunca, y la gran mayoría de las derrotas son por dispersión total (grupos destruidos), no por plazo**. Dato por guion: `central_flank_pair` ejecutado perfecto gana 11/12 y con errores moderados (0,45) 7/12.

## 1. Respuestas de diseñador

**¿Dónde hay tiempo muerto?** En los primeros ~4-5 min. El río baja de 1:00 a 7:30 y el vado junto al buque abre "en 05:36" (panel de `justina-inicio.png`). Los guiones óptimos emiten unas 5-6 órdenes en los primeros 250 s (señal, abastecer, reunir, posicionar, sondear) y recién a 255-330 s arranca la acción. Después, la marcha de ~390 m a trote (3 m/s, menos en barro) es otro tramo de mirar.

**¿Cuándo hay decisiones interesantes?** Tres momentos reales: (a) elegir flanco/ruta y cuándo sondear (≈250-350 s); (b) cubrir o no con el fuego (8 de munición contra 3 de cada rechazo); (c) contraataques en cubierta cada ~55 s. El resto es ejecución.

**¿Qué se aprende al perder y cómo se aplica en el reintento?** Casi nada, y casi nada se puede aplicar (hallazgos 1 y 2).

**¿Hay picos, sorpresa, recompensa?** Un pico (abordaje, ≈550-750 s), sorpresas solo por el sorteo oculto, recompensa pobre (pantalla de historia, sin ranking ni apertura de nada).

**¿Se entiende en 30 s?** El objetivo ("Rendir al Buque Justina") se lee; el primer paso útil no. Ver hallazgo 8.

**¿Decisiones falsas?** Sí, varias (hallazgos 5 y 6).

**Balance con un humano promedio (modelo, no datos)**: primer intento 3-8 % de ganar (el novato total no ganó ninguna del Monte Carlo); tercer intento 15-30 %; quinto intento 30-50 %, y esos números suponen que el jugador deduce por su cuenta que tiene que reconocer el flanco y esperar el río, cosa que el juego no le dice. Probabilidad de haber ganado al menos una vez en 3 intentos ≈ 25-40 %; en 5, ≈ 50-70 %. Cada intento perdido cuesta entre 8 y 18 minutos. Incertidumbre ±15 puntos.

## 2. Los 12 problemas más graves

### 1. Reintentar no conserva nada: cada partida sorteó otro mundo
**Evidencia**: `scripts/main.gd:375` (`forced_seed = -1`) y `:432` (semilla = `Time.get_ticks_usec()`), "Volver a jugar" llama a `_start_game`. La semilla elige el pozo del flanco central (`pozo_flanco_norte`/`sur`), el pozo del banco sur (`pozo_sur_a`/`b`) y la condición del río (4 variantes) (`data/justina_map.json`, `hidden_layout`, `time.variants`).
**Por qué duele**: lo que perdiendo "aprendiste" (por dónde caíste) es un 50 % de coincidencia en el reintento. El jugador siente azar, no maestría.
**Arreglo**: el primer reintento (y los dos siguientes) repite el mismo mundo ("misma marea, mismo fondo") salvo que el jugador elija "mundo nuevo". Mostrar en el menú de reintento: "Mismo río / Río nuevo". Así lo aprendido sirve.

### 2. La pantalla de derrota es una clase de historia, no una lección de juego
**Evidencia**: `evidence/justina-ui/final_r7/1920x1080/justina-parte.png` ("Plazo agotado": tabla de fuerzas, "Ruta: ninguna" y cinco párrafos de etiquetas históricas; los botones están debajo del scroll). `campaign_report()` ya calcula `defeat_cause`, `stumble_at`, `scouts_lost`, `halted_by_expiry`, `counter_hits`, `exposure_s`, pero solo imprime números.
**Arreglo**: una línea de diagnóstico arriba, en lenguaje de jugador, con un consejo accionable: "Perdiste porque cargaron sin reconocer el flanco: cayeron en el pozo del norte (3 tropiezos). Probá mandar un explorador antes." Reglas de texto por `defeat_cause` + estadísticas. Botón primario "Reintentar" grande; "Qué fue historia" colapsado.

### 3. Reintentar cuesta demasiado: el ciclo "perdés → jugás de nuevo" tarda 8-18 min
**Evidencia**: derrotas a 473-683 s (rush) o a 1080 s (plazo; `mixed_split`, `late_all_in`); la victoria tarda 12-14,4 min. Pasar al segundo escenario con 3-5 intentos significa 40-60 min de un solo escenario.
**Arreglo**: (a) corte rápido de partidas perdidas: si el estado ya es irrecuperable (p. ej. fuerza total < 60 y captura < 20 %), ofrecer "¿Reintentar ya?"; (b) checkpoint automático a los ~240 s ("tras el reconocimiento") para repetir solo el cruce y el abordaje; (c) acortar la bajante (ver 4).

### 4. Los primeros 4-5 minutos son espera con papeleo
**Evidencia**: `justina-inicio.png`: "Vado junto al buque abre en 05:36", bajante empieza a 01:00 y termina a 7:30 (`time.drop_*`). La mayor parte de las órdenes útiles (señal, reunir, abastecer) son viajes a puntos fijos.
**Arreglo**: comprimir el reloj del río (bajante 390 s → ~200 s, mínimo y subida escalados; es Diseño, no historia) o poner un "evento de campo" cada 60-90 s (un mensajero que trae una decisión, un tirador del buque que hostiga la playa, un grupo de voluntarios que llegan o se asustan). Arrancar en ×2 después del despliegue.

### 5. Hay un guion óptimo único y es el mismo todas las partidas
**Evidencia**: `docs/DISENO_JUSTINA.md` (líneas 280 y 337): `central_flank_pair` es "la estrategia más fuerte de la matriz (≈ 78 % en 18 semillas)"; el guion siempre es señal 180 s, abastecer, reunir, posicionar 260 s, sondear los dos flancos 255 s, cargar 330 s. `central_flank_lane`, `_pair` y `_hasty` ganan 8/8 casi iguales. El Monte Carlo muestra 11/12 para el guion ejecutado a tiempo.
**Arreglo**: que el mejor plan dependa de la partida. Variantes de misión sorteadas y VISIBLES al arrancar (ej. "el buque cambió de rumbo: su costado fuerte mira al sur", "faltan municiones", "llegan voluntarios extra al norte") para que centro/sur/dividir se turnen como óptimos. Que el flanco inseguro no sea siempre un solo carril sondeable.

### 6. Varias decisiones no cambian el resultado (decisiones falsas)
**Evidencia**: (a) rechazar contraataque y evacuar: `central_flank_noreply` gana 8/8 y `south_noreply` 8/8 con apenas más bajas (62 % vs 52-58 %; `DISENO_JUSTINA.md` 337); (b) elección de ruta: la sur cuesta 40-45 % de bajas contra 51-66 % del centro y solo 2 min más (`recorrido.json`), así que casi siempre conviene la sur, salvo con la marea "breve"; (c) sondear el flanco: siempre vale la pena (un sondeo resuelve una moneda 50/50 sin costo real: el explorador tiene 4 de salud).
**Arreglo**: darle consecuencia a cada una: rechazar un contraataque tiene que decidir si se pierde la cubierta (captura -25, no -9); evacuar debe poder salvar a un grupo entero; hacer que el sur tenga un costo propio (el vado sur se cierra por la marea, fuego de la costa sur, o el banco sur cuesta munición) y el centro un premio (captura x1,3, moral de la dotación cae más).

### 7. Precipicio: o hacés todo bien o perdés del todo, sin gradiente
**Evidencia**: las cuatro estrategias ciegas y las "bare" ganan 0/8 en la matriz de reglas; en mi Monte Carlo el novato total (errores en todo) ganó 0/24 y 19 de 24 derrotas son "grupos dispersos". `ui_real` semilla 5: captura **86,7 %**, derrota por dispersión con 94,7 % de bajas a 723 s. Perder con casi la victoria en la mano y sin segunda oportunidad se siente injusto.
**Arreglo**: derrota "blanda": al quedar sin fuerza, un último "empujón" (los voluntarios de reserva, o Liniers manda refuerzos una vez) que permite terminar a 90 %+ de captura con ranking bajo, para que un casi-triunfo sea victoria pírrica y no derrota. Rangos de victoria (bronce, plata, oro) en vez de binario.

### 8. Onboarding: no se entiende en 30 s qué hacer, y el tutorial recomienda algo malo
**Evidencia**: `justina-inicio.png`: a los 30 s se ven 5 fichas, un banner de pausa, un paso 1/6 sobre el reloj, un panel de objetivo con ocho datos y debajo la barra de acciones con "Retirada general: termina la partida" resaltada en rojo junto a las acciones normales. `scripts/main.gd:193-199`: el paso 4/6 manda "Señalar a Liniers (K)" casi de inmediato, pero la señal vale 420 s y solo hay 2 en toda la partida (`resources.signals_max`); según el propio diseño, señalar temprano la gasta (el guion óptimo señala a 180 s y la repite al cargar).
**Arreglo**: un objetivo en una línea con el siguiente paso sugerido, que cambie con el estado: "1. Mandá un explorador a sondear el agua (Z). 2. Esperá el río. 3. Señalá a Liniers cuando el vado esté abierto." Tutorial reescrito en 3 pasos: sondear, esperar con propósito, cargar. Que "Retirada general" salga del tablero principal y vaya a un menú.

### 9. Poca tensión entre picos: el fuego del buque es ruido, no un enemigo con personalidad
**Evidencia**: una descarga cada 7,5 s de 8-12 de daño sobre un único objetivo (`ship.fire`, `_artillery`), solo texto en el registro ("El buque dispara cerca de Explorador 1 y no lo alcanza"). El único pico fuerte es el contraataque (ventana de 14 s, `Pausa auto` lo detiene: se transforma en un "apretar coma" sin tensión).
**Arreglo**: telegrafiar las descargas (humo del cañón, aviso "descarga en 3 s" sobre el grupo apuntado, una opción de dispersar), una "andanada" más fuerte cada 60 s y el contraataque sin pausa automática (o con una pausa de 2 s) en dificultad normal.

### 10. No hay progresión ni recompensa: el segundo escenario no está atado al primero
**Evidencia**: el menú (`main.gd:389-` `_menu`) ofrece "II · Sostener el Norte" desde el primer segundo; el parte final ofrece "Ir a la campaña del norte" tanto en victoria como en derrota (`_report_dialog` y `_outcome_dialog`); la victoria muestra la misma pantalla de historia. No hay ranking, medallas ni desbloqueo.
**Arreglo**: Norte bloqueado hasta ganar la Justina (con su candado visible y el texto "ganá la Justina para abrirlo"); pantalla de victoria con título celebratorio, calificación (bajas, tiempo, vado marcado) y qué se desbloquea. Al perder, solo "Reintentar".

### 11. Perder esperando: el plazo de 18 min deja a un jugador pasivo 18 minutos sin avisar
**Evidencia**: `late_all_in` y la política pasiva terminan a 1080 s con 0-33 % de bajas; el parte final de `justina-parte.png` muestra "Bajas 0 %" y "Ruta: ninguna". La partida no empuja a actuar: no hay un reloj que ponga presión visible hasta que sube el río.
**Arreglo**: Liniers presiona (mensajes cada 3 min: "El virrey espera"), la barra de tiempo con un "punto sin retorno" claro, y derrota anticipada por inacción a los 11 min.

### 12. El sorteo de la marea puede hacer la partida injusta, y el jugador no lo sabe
**Evidencia**: `time.variants`: "breve" (peso 1 de 6) hace que el río suba desde 11:00 y "solo una ruta rápida y un abordaje resuelto llegan; la ruta sur no". "Lenta" deja la sur "justa". El panel dice solo "Río (brisa ordinaria)" (`justina-inicio.png`), sin consecuencias.
**Arreglo**: mostrar el pronóstico con su consecuencia en el despliegue ("Brisa que cede pronto: tenés 11 min; el vado sur no alcanza"). O sacar "breve" y reemplazarlo por una variante con compensación.

## 3. Prioridades sugeridas para la ronda 8

| Prioridad | Qué | Por qué rinde |
|---|---|---|
| 1 | Hallazgos 1 + 2 (mismo mundo en el reintento y diagnóstico de derrota) | Convierte "perdí" en "aprendí"; cuesta poco (semilla persistente + textos por causa) |
| 2 | Hallazgo 10 (Norte bloqueado hasta ganar, victoria con calificación) | Es el ciclo que pidió el usuario |
| 3 | Hallazgos 8 y 4 (objetivo guiado, bajante más corta o eventos) | Mejora los primeros 30 s y baja el costo de cada intento |
| 4 | Hallazgo 7 (derrota blanda / rangos) | Suaviza el precipicio para el humano promedio |
| 5 | Hallazgos 5, 6, 9, 12 | Profundidad y tensión; requieren re-medir la matriz (`tests/test_rules.gd --matrix`) |

Cualquier cambio de reglas obliga a re-medir la matriz (DISENO_JUSTINA.md 16.3: el balance es "un precipicio"). Los cambios 1, 2, 8 y 10 son de interfaz y progresión y no la tocan.
