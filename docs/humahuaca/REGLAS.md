# Reglas del nivel «Humahuaca»

Documento de `reglas_historia` (CONTRATO 1.2). **Estado: R1.0 (stubs de reglas y progreso, datos mínimos); se completa en R3.** Qué se juega y por qué está en `docs/DISENO_HUMAHUACA.md`; archivos, esquemas y firmas, en `docs/CONTRATO_HUMAHUACA.md`; cómo se certifica, en `docs/QA_NIVEL2.md`. Acá figura solo lo que las reglas deciden y lo que las pruebas fijan, para que quien siga en R1 no tenga que adivinarlo.

## Dónde viven los números

Todo número de juego sale de **`data/humahuaca_rules.json`** (reloj, ambiente, agrupaciones, frentes, combate, sigilo, torre, botín, refuerzo, desenlaces); el diseño de nivel (tapias, zanjas, accesos, zonas, luces), de **`data/humahuaca_level.json`**. El stub (`scripts/humahuaca/stubs/stub_rules*.gd`) y la clase real que lo reemplaza en R1 leen **los mismos archivos**: cambiar un valor es editar el JSON, nunca el código. Las pruebas leen la cifra del JSON y no la repiten.

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

`time_of_day` es lo único que lee la vista para la luz: 0 es noche plena, 0,5 el alba y 1 el día pleno. El pedido de `visual` (ADDENDA A-07) fija cinco muestras, con ±0,05: **0 a los 0 s, 0 a los 240 s (4:00), 0,5 a los 285 s (4:45), 0,67 a los 330 s (5:30) y 1 a los 420 s (7:00, `day_full_s`)**. La curva es continua y no baja nunca. Antes daba 0,15 a los 240 s y 0,35 a los 285 s (el alba llegaba tarde); hoy da 0,00, 0,00, 0,50, 0,67 y 1,00. Las capturas de antes y después quedan en `evidence/humahuaca/r1/reglas/` (ronda intermedia: no entra a Git).

**Cómo se mide.** Una partida pasiva termina a los 390 s por `amanecio` y su reloj se detiene ahí: pedirle el ambiente «a los 420 s» devuelve el de los 390 s (0,89). Por eso la muestra de 420 s se toma con el reloj fijado (`rules.state.elapsed = t` y después `environment()`) o con una partida en la que ya se dio la señal (`new_game(..., {"phase": "ataque"})` y `advance_to(420)`). `tests/test_hx_rules.gd::_test_environment_curve` hace las dos cosas, más la continuidad, el orden de las fases y la comprobación de que una partida pasiva se detiene antes de los 420 s.

## Qué hace el stub y qué no (R1.0)

Garantiza, con las cifras de los JSON: cinco agrupaciones, tres frentes, las 9 acciones de R1 más sostener y cancelar, señal, toma por fuerza y sorpresa, torre del cuartel como temporizador de 90 s (12 descargas de 7,5 s), botín en 5 clases que suma 100, refuerzo como temporizador, `hud_state`, `render_state` y `campaign_report` con la forma de los ejemplos de `docs/humahuaca/forma/`, y guardado, carga y validación con 34 mutaciones rechazadas. Una victoria alcanzable (tomar los tres frentes con «Atacar» y «Salir por el este») y la derrota por `amanecio`.

No hace: rutas que rodeen tapias o zanjas, la doble capa «lo que sabés / lo real», decisiones del campo, las acciones de R2a, el diario ni los puntos de control, y no produce la causa `descubiertos` (BACKLOG B-019). `render_state().tower` queda vacío hasta que la torre abre fuego; desde ahí trae las coordenadas del hito de **su** variante (`torre_casa_cura` o `torre_templo`, VP-02).

## Pruebas

- `tests/test_hx_rules.gd`: prueba la clase efectiva (la real si existe; si no, el stub). Se corre con `godot --headless --path . --script tests/test_hx_rules.gd -- --ronda=r1.0 --skip-strategies` y APPDATA aislado. Fija la curva de VP-01 y la torre de VP-02, el estado y sus rangos, las formas de `hud_state`, `render_state`, `campaign_report` y `plan_route` en las fases, las órdenes y sus rechazos, sigilo y señal, torre, refuerzo, botín, los desenlaces, guardado y carga, y el progreso. Lo que todavía no puede evaluar (políticas, `nav_build_ms`, la clase real) queda en `pending` y pasa a ser falla desde `r1`.
- `tests/test_hx_data.gd` (de compuertas y documentos) valida los JSON; `tests/test_hx_smoke.gd`, las corridas degradadas con cada capa en su versión mínima.

## Pendiente para R1

La clase real `HumahuacaRules` y `HumahuacaProgress`, la biblioteca de políticas (`experto` gana y `pasivo` pierde), `tools/humahuaca_playthrough.gd`, las 8 causas de derrota y las pruebas de balance. Cuando la clase real exista, `test_hx_rules` la prueba sola y las comprobaciones marcadas como propias del stub se apagan.
