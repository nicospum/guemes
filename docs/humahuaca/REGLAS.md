# Reglas del nivel «Humahuaca»

Documento de `reglas_historia` (CONTRATO 1.2). **Estado: R1 (clases reales de reglas y progreso, biblioteca de políticas y herramienta de recorrido); se completa en R3.** Qué se juega y por qué está en `docs/DISENO_HUMAHUACA.md`; archivos, esquemas y firmas, en `docs/CONTRATO_HUMAHUACA.md`; cómo se certifica, en `docs/QA_NIVEL2.md`; de dónde sale cada cifra, en `docs/humahuaca/PROCEDENCIA.md`, y qué se afirma de la historia, en `docs/humahuaca/HISTORIA.md`. Acá figura lo que las reglas deciden y lo que las pruebas fijan, para que quien siga en R2a no tenga que adivinarlo.

## Dónde viven los números

Todo número de juego sale de **`data/humahuaca_rules.json`** (reloj, ambiente, agrupaciones, frentes, combate, sigilo, torre, botín, refuerzo, desenlaces, aprendizaje); el diseño de nivel (tapias, zanjas, accesos, puestos de ataque, zonas, luces), de **`data/humahuaca_level.json`**; los hitos, de `data/humahuaca_map.json`. Las clases reales, el stub y las pruebas leen **los mismos archivos**: cambiar un valor es editar el JSON, nunca el código; las pruebas leen la cifra del JSON y no la repiten.

## Archivos de la capa

| Archivo (`scripts/humahuaca/rules/`) | Qué hace |
|---|---|
| `humahuaca_rules.gd` | `HumahuacaRules`: el estado, el reloj de paso fijo de 0,25 s, la señal, el ataque, la torre, el botín, el refuerzo, las órdenes y el desenlace. Los 43 métodos de la API de CONTRATO 3.2 más `set_terrain()` y `set_diary_marks()` |
| `humahuaca_rules_info.gd` | Solo lectura: `hud_state`, `render_state`, `campaign_report`, el epílogo, `plan_route`, `plan_recon`, `route_atlas` y el «siguiente paso» |
| `humahuaca_rules_save.gd` | Guardado atómico, carga y `validate_snapshot` |
| `humahuaca_setup.gd` | El estado inicial: mundo, cinco agrupaciones, tres frentes y botín |
| `humahuaca_nav.gd` | La grilla de navegación de A* (`AStarGrid2D`) armada con `terrain.nav_grid()`; rutas alisadas |
| `humahuaca_data.gd` | Lectura de los JSON, textos con marcas, hitos y lugares dichos en palabras |
| `humahuaca_progress.gd` | `HumahuacaProgress`: intentos, racha, mejor medalla, mundo fijo, diario con marcas «anotado» y los controles `posiciones` y `salida` |
| `humahuaca_policies.gd` | `HumahuacaPolicies`: la **única** biblioteca de políticas (experto, obediente, torpe, pasivo, pausa y reanuda, aleatorio, barrido de la señal) |
| `vocab_rules.gd` | El vocabulario de la capa (solo-agregar) |

Más `tools/humahuaca_playthrough.gd` (recorridos por reglas o por la escena real), `tests/test_hx_rules.gd` y `tests/hx_rules_checks.gd` (partida por el tope de líneas del contrato). El stub (`stubs/stub_rules*.gd`, `stub_progress.gd`) sigue congelado y es lo que corre si la clase real no carga. Ni las reglas ni sus ayudantes usan `randf`, `randi` ni el reloj del sistema: el azar es un congruencial en `state.rng_state`.

## El reloj de la partida

Los tiempos son de partida a ×1. Las fases del juego (`phase`) y las del ambiente (`environment().phase`) son cosas distintas: las primeras las cambian los hechos (señal, frentes tomados, fin) y las segundas, solo el reloj.

| Tramo | Ambiente | `time_of_day` | Lluvia | Visibilidad | Armas de chispa |
|---|---|---|---|---|---|
| 0:00 a 3:30 | noche | 0 | 0,9 | 35 m | 0,55 |
| 3:30 a 4:00 | noche | 0 | 0,8 | 45 m | 0,55 |
| 4:00 a 4:30 | noche | 0 → 0,33 | 0,8 | 45 m | 0,55 |
| 4:30 a 4:45 | alba | 0,33 → 0,5 | 0,5 → 0,43 | 60 → 80 m | 0,9 |
| 4:45 a 5:30 | alba | 0,5 → 0,67 | 0,43 → 0,2 | 80 → 140 m | 0,9 |
| 5:30 a 7:00 | día | 0,67 → 1 | 0,1 | 300 → 600 m | 0,9 |
| desde 7:00 | día | 1 | 0,1 | 600 m | 0,9 |

El barro arranca en 0,55, se mantiene hasta las 5:30 y se seca 0,01 por segundo. La guardia se desvela desde el alba (4:30) y a las 6:30 (`time.dawn_discovery_s`) amanece: si nadie dio la señal, la partida termina por `amanecio`. El plazo duro es a las 14:00.

### `time_of_day` y la luz de la vista (VP-01)

`time_of_day` es lo único que lee la vista para la luz: 0 es noche plena, 0,5 el alba y 1 el día pleno. El pedido de `visual` (ADDENDA A-07 y A-08) fija cinco muestras, con ±0,05: **0 a los 0 s, 0 a los 240 s (4:00), 0,5 a los 285 s (4:45), 0,67 a los 330 s (5:30) y 1 a los 420 s (7:00, `day_full_s`)**. La curva es continua y no baja nunca, y vive en los datos (`environment.segments`, 7 tramos). Una partida pasiva termina a los 390 s por `amanecio` y su reloj se detiene ahí: la muestra de 420 s se toma con el reloj fijado o con una partida en la que ya se dio la señal. `tests/test_hx_rules.gd::_test_environment_curve` lo fija.

## Cómo juega la clase real

**Rutas y velocidad.** Cada orden de marcha (`move`, `position`, `support`, `recon`, `leave`) calcula una ruta de A* sobre la grilla de 226 × 164 nodos de 4 m que entrega el terreno (`nav_grid()`: muros, tapias sin portillo y agua honda son sólidos; el costo de cada nodo es 1 / velocidad, de modo que el barro, el riego y las zanjas cuestan), la alisa en tramos rectos que nunca rozan un muro y la sigue a la velocidad que da `terrain.speed_factor_at()` en cada punto (ritmo × barro × pendiente; el vado, a media velocidad como mucho). Un destino dentro de un edificio (el polvorín) termina en la celda libre más cercana; si no hay camino, la orden se rechaza («No hay camino hasta ese punto»). `plan_route` y `route_atlas` usan la misma ruta, así que lo que la interfaz promete es lo que pasa. La grilla se arma una vez por terreno (3,2 ms medidos; tope 80 ms) y cada ruta cuesta 2 a 3 ms (tope 30 ms).

**Ver y ser visto.** Un centinela detecta a una agrupación si `distancia < visibilidad × (1 + 2 × ruido)` (×1,5 en la batería y en la torre armada) **y** ningún muro le tapa la vista (`terrain.los()`): quien marcha por detrás de una tapia no se ve. Cada segundo que lo ven sube la alerta del frente 0,02 × (1 + ruido) por paso de 0,25 s; a 0,5 el frente queda `alertado` y a 1, `en_alarma` (se atrinchera: cobertura ×1,25). El desvelo del alba suma `0,004 × visibilidad / 60` por segundo desde las 4:30 y a las 6:00 todos los frentes están en alarma aunque nadie haya disparado: **esa alarma es del reloj y no cuenta como «descubiertos»**.

**La señal.** Se puede dar apenas una partida espera en su puesto (`waiting_signal`); las que no llegaron atacan al llegar. Sin señal las partidas esperan y a los 6:30 amanece. La señal abre la ventana de sorpresa de 45 s en los tres frentes (bono de sorpresa `1 + 0,8 × (1 − alerta)`) y arma el reloj del refuerzo (señal + 240, 300 o 360 s). **Adelantarse y esperar cuestan distinto:** la oscuridad le resta al atacante puntería (hasta ×0,25) y poder de asalto (hasta ×0,7) hasta que la visibilidad llega a 100 m (≈ 5:00); el desvelo le resta sorpresa y suma alarmas; y señalar temprano deja menos tiempo para que el arreo cargue (a los 2:00 y 2:15 la partida se pierde por `sin_carga`).

**Toma y bajas.** `toma += 3,4 × ataque / defensa × sorpresa × paso`, donde el ataque suma por agrupación `hombres × (0,5 + 0,5 × armas × puntería × fiabilidad) × fuerza × fatiga × postura × oscuridad` y la defensa es `guarnición × cobertura × (armas de chispa mojadas)`; el frente cae al llegar a 100. Las bajas del atacante son `0,09 × defensa / ataque × bajas de la postura` por segundo; el que toma un frente deja el 10 % de sus hombres de custodia. Una partida con 15 % de fuerza o menos se quiebra (`frente_roto`); con las tres por debajo del 20 %, `dispersos`.

**La torre del cuartel** abre fuego 12 s después de la señal (descuidada) o al instante (atenta) y dispara 12 descargas, una cada 7,5 s: 90 s. Hiere a quien está a menos de 90 m **y a la vista** de ella (a 10 m de altura), no al pie (ángulo muerto de 12 m), ×2 a quien asalta a fondo o está en la calle abierta, ×0,5 a quien asalta con cautela o tiene una tapia de por medio, ×0,3 a quien cruza corriendo. La carga sobre el cuartel cuenta como «en el hueco de recarga» si la próxima descarga está a 3 s o más (`stats.charges_in_gap`; la compuerta 11 llega en R2a).

**Botín y extracción.** Cinco clases que suman 100 puntos (pólvora 30, cañones 30, fusiles 14, víveres 14, plata 12); capacidad de 600 kg propios más 16 mulas del corral (2 200 kg); 12 kg/s por equipo y hasta 3 equipos; se carga lo que está a menos de 30 m de un frente ya tomado. Entregar vale ×1, destruir ×0,35 (el 65 % restante se anota como perdido) y la pólvora mojada ×0,2. **Salir por el este exige llevar algo** (no hay carga gratis) y cruzar el vado. Quemar pólvora adelanta el refuerzo 20 s la primera vez y 10 s las siguientes (tope 40).

**Refuerzo.** A 60 s de llegar hay una polvareda («Polvareda al sur») y una alerta crítica con cuenta regresiva. Si llega antes de que el arreo salga, `interceptados`.

### Las ocho causas de derrota

| Causa | Cuándo | Texto de ejemplo (≤ 140 caracteres, con momento y lugar) |
|---|---|---|
| `amanecio` | nadie dio la señal a los 6:30 | «A los 6:30 amaneció con las partidas cerca de la zona de partida y sin señal dada: la guarnición los vio venir.» |
| `descubiertos` | la alarma saltó **porque los vieron** antes de la señal: en los tres frentes (derrota al instante), o en un frente cuya partida después se rompe, o con las tres partidas dispersas | «A los 1:15 la guardia de la batería dio la alarma antes de la señal y los frentes se defendieron alertas.» |
| `frente_roto` | una partida de combate baja del 15 % de fuerza antes de tomar los tres frentes | «A los 4:45 la partida de Portal quedó clavada frente al cuartel y se rompió bajo el fuego.» |
| `sin_carga` | sale la columna con menos de 45 puntos de golpe | «A los 7:00 la columna cruzó el vado con menos de la mitad del golpe: faltaron mulas, tiempo o decisión.» |
| `interceptados` | llega el refuerzo antes de que el arreo salga | «A los 9:45 el refuerzo cayó sobre la columna cerca de la posta y la carga se perdió.» |
| `dispersos` | las tres partidas bajan del 20 % de fuerza | «A los 4:45 las tres partidas quedaron con menos de la quinta parte de su fuerza cerca de la batería y se dispersaron.» |
| `plazo` | 14:00 | «A los 14:00 se cumplió el plazo con la columna cerca de la posta y el depósito sin vaciar.» |
| `retirada` | «Retirada general» | «A los 0:05 diste la retirada general cerca de la zona de partida: el golpe quedó a medias.» |

Los textos de la tabla son los que escribe el juego en esas situaciones (el momento y el lugar cambian con la partida). Cada causa trae su consejo (`outcome.causes.<id>.consejo`) y, desde el segundo intento seguido por la misma causa, una pista que rota (`campaign.tips`) y que **agrega** algo en vez de repetir el consejo de siempre. `tests/test_hx_rules.gd::_test_outcomes` las alcanza las ocho.

### Ritmo (`stats.pacing`)

Cuenta **ofertas**: una oferta es un «siguiente paso» con algo para hacer, una alerta con botón o una decisión pendiente; una orden dada cuenta como una oferta que existía. Se mide una vez por segundo de juego: `first_decision_s`, `decision_gap_max_s` y `decision_gap_attack_max_s` (la brecha mayor sin ofertas, en total y durante el ataque). El «siguiente paso» recorre ahora: reconocer la batería, llevar cada partida a su puesto, traer el arreo, reconocer el cuartel y la posta, dar la señal, atacar, **socorrer** (quien terminó su frente puede ir a ayudar al que más cuesta) y cargar, destruir y salir.

## Guardado

`save_game` escribe de forma atómica (`.tmp` y renombre) con tope de 3 000 000 B; `load_game` valida **antes** de reemplazar el estado (id nuevo, `previous_game_id`) y `validate_snapshot` rechaza con motivo y sin tocar nada: otro escenario («Este guardado es de otro escenario»: la Justina y el Norte), otra versión de esquema o de mapa, tipos y rangos, agrupaciones repetidas o fuera del mapa, etapas, ritmos y órdenes que no existen, variantes y rasgos ilegales, botín que no suma 100 o supera la capacidad, «en marcha» sin camino, una victoria sin los tres frentes, un primer disparo en el futuro, y las secciones internas. `test_hx_rules` rechaza 34 mutaciones y `qa_guardado.gd` (anexo A5 del QA) 24 de 24 obligatorias, con el estado intacto.

## Progreso

`HumahuacaProgress` guarda **progreso, no partida**: el mundo es fijo hasta ganar (lista `campaign.world_seeds`); el diario (hasta 40 entradas) anota lo que enseñó cada intento y deja una marca tenue «Anotado» (`render_state().marks`) que **no** cuenta como reconocimiento; los controles `posiciones` (las tres partidas en su puesto y sin descarga, o a los 210 s) y `salida` (al tomar el tercer frente) cuestan un intento y se restauran con `restore_snapshot`. Un archivo dañado o de otra versión se descarta con aviso y se empieza de cero. Las ayudas en escalera, las medallas por ventaja y el reintento con ayudas son de R2b.

## La biblioteca de políticas y la herramienta de recorrido

`HumahuacaPolicies.decide(policy, view, rng)` devuelve órdenes a partir de `view` (lo que el jugador ve: `hud_state`, `render_state`, `signal_info`, `loot_state`, el ambiente y una memoria). Solo `experto`, `barrido_senal` y las `est_*`/`ext_*` reciben `omniscient: true` y el estado de las reglas; las otras no leen nada oculto (`_test_policies_blindness` cambia la guardia real, el reloj del refuerzo y las pistas del mundo y exige las mismas órdenes). El **experto** reconoce la batería, lleva cada partida a su puesto (la de Rodríguez, a fondo), da la señal a los 4:45, socorre, carga lo que más puntos da por kilo de mula **apenas cae cada frente**, destruye lo que sobra si hay tiempo y sale antes del refuerzo. El **obediente** solo hace lo que dice el «siguiente paso»; el **torpe** es el obediente con demoras de 2 a 8 s, que ignora el 30 % de los avisos no urgentes y falla la señal ± 15 s; el **pasivo** y «pausa y reanuda» no hacen nada; el **aleatorio** da órdenes al azar (robustez). Los ciegos, las 8 estrategias de frente y las recetas de extracción están armadas sobre el plan del experto pero **no se miden en R1**: sin la doble capa de conocimiento y sin `ocultar` todavía no cambian el resultado y medirlas daría un número que no quiere decir lo que dice (`skipped` con su motivo).

```
godot --headless --path . --script tools/humahuaca_playthrough.gd -- --level=rules --policies=experto,pasivo --seeds=compuerta --attempts=3 --replicas=1 --out=<json>
godot --path . --resolution 1280x720 --audio-driver Dummy --script tools/humahuaca_playthrough.gd -- --level=scene --policies=experto,pasivo --seeds=3 --shots=<carpeta> --out=<json>
```

Sale con 0 si el experto gana ≥ 90 % al primer intento, el pasivo y «pausa y reanuda» pierden todas por `amanecio` y no hubo excepciones; con 1 si no. El informe es `hx_playthrough_v1` (lo lee `qa_balance.py`) con `snapshot_sha256` por partida: misma entrada, mismo hash. `--measure=decisions` bifurca el estado en cada orden del experto (con la orden y con las órdenes postergadas 20 s) y cuenta como significativa la que cambia ≥ 10 puntos o una victoria en derrota. Con `--level=scene` la herramienta entra por `main._start_humahuaca({seed, attempt, skip_intro, qa})`, lleva el reloj con `qa_step()` del controlador y, para la política `interfaz`, pulsa el botón del «siguiente paso» (`qa_press_next()` o un botón visible cuyo nombre diga «siguiente»); si el controlador no lo ofrece, la política se omite con su motivo.

## Qué se midió en R1

Compuerta rápida y recorridos, con `APPDATA` aislado, el 2-nov-2026:

| Medida | Resultado |
|---|---|
| `test_hx_rules` | 621 comprobaciones, 0 fallas, 18 s (modo rápido; piso de R1: 150); la clase real de reglas y de progreso |
| `performance` (línea final de la suite) | `nav_build_ms_avg` ≈ 3,3 (tope 80) · `plan_route_ms_avg` ≈ 2,2 (tope 30) · `tick_ms_avg` ≈ 0,06 (tope 2) · `hud_state` + `render_state` ≈ 0,26 ms |
| Experto, 24 mundos de la compuerta, 1.er intento | 24 de 24 (Wilson 90 %: 0,90 a 1,00); victorias de 9:11 (mediana), golpe 46,8 (la victoria pide 45), bajas de 15,7 a 17,2 % |
| Pasivo y «pausa y reanuda», 24 mundos × 3 intentos | 0 victorias; todas por `amanecio` a los 6:30 |
| Obediente y torpe (informe, no compuerta) | 24 de 24 y 24 de 24 al 1.er intento (victorias de 8:15 y 8:51): **más fácil de lo que se quiere**; la intención de diseño es 25-40 % y 10-25 %, y con el mundo fijo de R1 el «siguiente paso» alcanza: lo que lo hace fallar son las variantes y el reconocimiento con riesgo de R2a y R2b |
| Barrido de la señal, 8 mundos (2:00 a 6:15) | máximo a las 4:45-5:00 (puntaje 38,4-38,5); 31,0 a las 2:00 (con `sin_carga`) y 35,2 a las 6:00: sube, llega a un máximo y baja |
| Decisiones significativas del experto por ramificación | 0 de 15 órdenes cambian el final ≥ 10 puntos: **en R1 ninguna decisión suelta es significativa** (J03 se exige desde R2b) |
| Brechas por ofertas (experto, obediente y torpe, 24 mundos) | primera decisión a los 0-1 s; mayor brecha sin ofertas de 90 a 102 s, en la aproximación (todas las partidas en marcha: es lo que R2a llena con el informante, la patrulla, la tapia hallada y el aviso del alba); en el ataque, de 12 a 18 s (≤ 20 s); a lo sumo una alerta crítica a la vez |
| Escena real (`--level=scene`) | experto gana y pasivo pierde por la escena con la clase real (551 s y 390 s) |

## Lo que todavía no hace (R2a y R2b)

La doble capa «lo que sabés / lo real» y el reconocimiento con riesgo fino, las acciones de R2a (`secure_horses`, `breach`, `retreat`, `decoy`, `watch`, `bring`, `hide`, `drop`, `retreat_all` desde la UI), las cuatro respuestas a la torre y su cadencia como compuerta, las nueve clases de botín con `ocultar`, los eventos del guion y las decisiones del campo, las variantes de tres dimensiones y la matriz de contrapesos, las ayudas y las medallas con ventaja, y las políticas ciegas, de enfoque y de extracción medidas. El mundo de R1 es fijo: guardia descuidada, torre en la casa del cura, refuerzo normal, refugio sur, lluvia copiosa, planta A; botín con el corral completo, la plata y la pólvora seca.
