# Balance y ritmo del escenario del norte

Fecha de la revisión: 28/10/2026. Alcance: `scripts/game_rules.gd`, `tests/test_rules.gd`, `data/history.json` y este documento.

## Problema

`docs/VERIFICACION_FASE2.md` registró que tres agrupaciones hostigando Salta/Jujuy en las rondas 3–4 podían ganar en la ronda 7, lejos de la duración objetivo de 20–35 minutos (`docs/ENCARGO.md`) y de la cronología de ronda 10–11 que describía la documentación. La causa estaba en la retirada realista (`_enemy_can_retreat`): exigía solo ronda ≥ 7 y 5 acciones de presión, y seis hostigamientos en dos rondas ya cubren esa presión.

## Cambio

| Constante | Antes | Ahora | Efecto |
| --- | --- | --- | --- |
| `RETREAT_MIN_ROUND` | 7 (literal) | 10 | La retirada realista no puede ofrecerse ni producir victoria antes de la ronda del 12 de abril de 1817. |
| `RETREAT_MIN_PRESSURE` | 5 (literal) | 7 | Hace falta algo más de presión acumulada, además de los umbrales de abastecimiento, cohesión y comunicaciones, que no cambian. |

Los umbrales de recursos del invasor no se tocaron: el desgaste sigue dependiendo de las decisiones del jugador. Solo se acotó cuándo puede cerrarse la campaña. Una retirada antes de la ronda 13 se sigue identificando en pantalla como desenlace alternativo anticipado.

## Evidencia de simulación

Núcleo real en Godot 4.7.2 sin ventana, perfil de usuario aislado. Política de estrés `biased`: las tres agrupaciones hostigan Jujuy/Salta en las rondas 3–4 y en las demás eligen al azar (con sesgo a hostigar) órdenes legales; el invasor elige al azar entre sus intenciones legales. 1500 partidas, semillas 1000–2499, generador con semilla fija 12345. Script de simulación fuera del repositorio (ejecución local, no versionado).

| Variante | Victorias | Victorias antes de la ronda 10 | Primera ronda con victoria |
| --- | --- | --- | --- |
| Antes (7 / 5) | 646 | 184 (49 en ronda 7, 62 en ronda 8, 73 en ronda 9) | 7 |
| Intermedia (9 / 7) | 616 | 157 (todas en ronda 9) | 9 |
| Ahora (10 / 7) | 655 | 0 | 10 |

Con la política `rush` determinista (exploración, hostigamiento intenso y descanso por fatiga con intención enemiga de respaldo) 1500 de 1500 partidas siguen ganándose en la ronda 10. Con órdenes totalmente aleatorias (1500 partidas) ganan 196 y la primera victoria ocurre en la ronda 10. La pasividad sigue perdiendo.

Estas cifras son una propiedad del modelo con políticas automáticas. **No son duración de partidas humanas**: con 10 rondas como mínimo, a 2 minutos por ronda la partida más corta rondaría los 20 minutos, pero ese ritmo humano no se midió. La meta de 20–35 minutos sigue sin validación con jugadores.

## Pruebas

`tests/test_rules.gd`, `_test_north_pacing`: (1) la retirada no se ofrece antes de `RETREAT_MIN_ROUND` ni con presión menor que `RETREAT_MIN_PRESSURE`, aun con el invasor agotado; (2) en 250 partidas de la política de estrés ninguna gana antes de la ronda 10 y algunas ganan (el escenario sigue siendo ganable). Los resultados se añaden al informe de la suite.

## Ocupación de Salta

Fuentes: Gobierno de Salta [S4], 15 de abril; *Ideario* [S1], p. 40 y parte del 25 de abril, p. 219. Antes la regla ocupaba Salta en la ronda 5 (9 de febrero), unos dos meses antes. Ahora:

- `SALTA_OCCUPATION_ROUND = 10`. La ronda 10 abarca del 12 al 22 de abril de 1817 y contiene el 15 de abril. La ocupación se aplica al resolver esa ronda aunque el invasor no elija avanzar.
- El invasor puede avanzar de la Quebrada a Jujuy en cualquier momento, pero la entrada en Salta (por elección) solo se ofrece desde la ronda 10 (`_enemy_can_advance`). Así una decisión externa o el respaldo local no ocupan Salta con meses de adelanto.
- El texto del evento ya no dice que su momento sea solo un ritmo de juego: cita la ocupación documentada del 15 de abril dentro de la ronda.
- Consecuencia de balance: el apoyo de la población cae más despacio antes de la ronda 10 (−3,5 por ronda en lugar de −6 desde la ronda 5). La partida pasiva sigue perdiendo (ronda 14, «Llegó mayo…»).

Lo que no se pudo precisar: el día exacto dentro de la ronda no se simula. La ronda 10 representa un tramo de diez días.

## Crecida del río (Justine)

Reproducción con `Aproximación preparada` en t ≥ 700: una orden de aproximación directa o por el sur emitida con la bajante ya cerrándose devolvía siempre «Aproximación preparada…», aunque la agrupación no llegara antes de que el agua cubriera el banco. A partir de t = 780 s el agua sube hasta 0,95 en 120 s; el banco central deja de ser transitable hacia t ≈ 829 s. Sin camino hasta el buque, la agrupación quedaba en `blocked` dentro del agua (por ejemplo en (2, 0) a profundidad 1,05 en t = 900), sin salir nunca.

Correcciones:

- `issue_order` valida el cruce: calcula el instante de inundación de cada punto del trayecto (`_flood_time`) y lo compara con la llegada estimada (`_crossing_in_time`, velocidad con fatiga actual y 3 % de margen). Si no llega, rechaza la orden y no modifica a la agrupación ni registra la orden.
- Con el río subiendo y sin camino se rechaza la espera en la orilla (no habrá otra bajante).
- El mensaje distingue «el cruce es posible con el nivel actual» de «espera en la orilla hasta que la bajante permita cruzar».
- Una agrupación que en espera de bajante ya no llega a tiempo cancela la orden con un aviso. Una agrupación bloqueada con el río subiendo cuyo destino quedó cubierto cancela su orden.
- `_rescue_submerged`: una agrupación que queda en una celda no transitable por la crecida vuelve al punto seco más cercano (con preferencia por la orilla oeste), con +10 de fatiga y un aviso en el registro. Es un reposicionamiento instantáneo (abstracción de jugabilidad), no una simulación de arrastre.

Barrido de verificación: 352 combinaciones de instante de la orden (0–870 s, paso 10), dos acciones y dos agrupaciones; ninguna orden aceptada terminó varada en el agua. El efecto colateral es que el rango de órdenes aceptadas se estrecha: con el criterio actual, la aproximación directa deja de aceptarse hacia t ≈ 640–680 s y la del sur antes (alrededor de t ≈ 600 s).

## Coherencia del guardado

`validate_snapshot` ahora llama a `_validate_coherence`, que rechaza estados con campos válidos por separado pero contradictorios entre sí. Táctico: nivel y fase del río según el tiempo (`_tide_at`); aviso de crecida; victoria con captura completa; partida en curso con captura completa, plazo vencido, acumulador mayor que un paso o descarga vencida; etapas (`moving`, `blocked`, `waiting_tide`, `rally`) sin orden o trayecto; trayecto en una agrupación quieta; montado/desmontado según la etapa; temporizador de desmontaje; dispersión con efectivos. Campaña: coordenadas de la agrupación igual a las de su sector; etapa `ordered` ⇔ orden pendiente; destino de la orden alcanzable; rutas entre sectores recíprocas; posición del invasor marcada como ocupada y coherente con `occupied_salta`; Salta ocupada pasada la ronda 10; Humahuaca recuperada ⇔ sector liberado y solo desde la ronda 7; presión acumulada posible; población y agrupaciones activas en una partida en curso; resumen de ronda según la ronda. Común: motivo de cierre solo si la partida terminó; primera orden y órdenes y registro sin acontecimientos del futuro; partida terminada sin órdenes ni trayectos pendientes.

Cobertura: `_test_snapshot_coherence` acepta estados reales y rechaza 27 mutaciones concretas. Los guardados anteriores a esta versión que cumplieran cada campo pero violaran estas relaciones se rechazan ahora; no se encontró ninguno entre los generados por las pruebas.

## Humahuaca: marzo o mayo

Se revisaron `docs/historia/MATRIZ_HISTORICA.md`, `REVISION_2026-10-28.md` y `FUENTES.md`. La fecha del 1 de marzo de 1817 y el mando de Arias coinciden en tres notas institucionales (S8a–S8c) y con el parte del *Ideario* p. 78 (3 de marzo). Las fechas de mayo del *Ideario* (pp. 41, 222–223) se explicaron como probable error de transcripción por inferencia indirecta (orden de páginas de *Güemes Documentado* t. 4, «el 6 del que rige» en un boletín del «4», evacuación de Salta el 5 de mayo). Esa inferencia no se pudo contrastar: no está disponible en el repositorio ni en esta sesión la edición íntegra o el manuscrito. **Por eso la discrepancia queda marcada como no verificada.** `history.json` conserva marzo como fecha adoptada para el juego, indica `verification: "parcial"` y ya no afirma que las fechas de mayo sean una discrepancia editorial demostrada. Pendiente: cotejar *Güemes Documentado*, t. 4, pp. 350–359.

## Qué no se verificó

- Ninguna duración con jugadores humanos.
- La suite de integración (`tests/test_integration.gd`) en este worktree: falla por recursos de audio sin importar y por una comprobación de modelos 3D; no se determinó si es independiente de estos cambios porque no se corrió la línea base en el mismo entorno.
- Interfaz y mensajes en pantalla de las nuevas respuestas de `issue_order` (`scripts/main.gd` no se modificó ni se revisó).
