# Balance del nivel 2 (R2b) · qué cambió y por qué

Rama `hx-balance-nube` sobre `humahuaca-r1` (333a657). Trabajo hecho en la nube, sin pantalla: todo lo que dice este documento se midió con Godot 4.7.2 `--headless` y la herramienta de recorrido de reglas (`tools/humahuaca_playthrough.gd`) con el agregador `qa_balance.py` del anexo A3 de `docs/QA_NIVEL2.md`. Las cifras completas, antes y después, están en `evidence/humahuaca/r2b/balance/antes.md` y `despues.md`.

## El problema, en una frase

En R1 el nivel se ganaba solo: el que seguía el «siguiente paso» ganaba el 100 % y el torpe el 98 % al primer intento, la victoria llegaba a los 8:44 y había tramos de hasta 102 s sin nada que decidir. El diseño pide: obediente 20–45 %, torpe 5–30 %, experto ≥ 90 %, victorias con mediana entre 11:00 y 13:00, ninguna brecha sin decisión mayor a 45 s (20 s en el ataque).

## Por qué se ganaba solo

1. El mundo no se sorteaba: las 60 semillas daban la misma partida (guardia descuidada, torre en la casa del cura, refuerzo normal).
2. El «siguiente paso» leía el reloj exacto del refuerzo (`state.alarm.reinforcement_at`): quien lo seguía salía justo a tiempo, siempre.
3. El combate era demasiado fácil: con la batería y el cuartel en alarma antes de la señal, igual caían en 44 y 92 s.
4. La carga iba a 36 kg/s (1 200 kg de pólvora en 33 s) y el refuerzo llegaba 300 s después de la señal: la partida duraba 8 a 9 minutos.

## Qué cambió (contenido, no multiplicadores globales)

Todos los números viven en `data/humahuaca_rules.json`; las reglas están en `scripts/humahuaca/rules/`. La parte de alarma, torre, reconocimiento, botín y decisiones de campo se mudó a `humahuaca_rules_field.gd` (el archivo de reglas pasaba las 1 500 líneas del contrato).

### 1. El mundo se sortea con la semilla

`world_from_seed` sortea las tres dimensiones activas (guardia descuidada o atenta; torre en el templo o en la casa del cura; refuerzo temprano, normal o tardío) con un congruencial propio (`variants.seed_mix`). La semilla 1817 (el mundo guiado de la campaña) sigue dando el mundo fijo; las ocho semillas de calibración, cada mitad de la compuerta y las 60 del QA cubren cada valor ≥ 2, ≥ 3 y ≥ 3 veces. La prueba «en R1 el mundo es fijo» se reemplazó por esa cobertura.

### 2. La guardia atenta se nota (y castiga al que mira de cerca)

`enemy.guard.atenta`: ve ×1,25 más lejos, la sorpresa dura 25 s (45 con la descuidada), el bono de sorpresa sobre el cuartel arranca en ×1,3 (en vez de ×1,8) y la torre se arma desde la señal. Lo nuevo: **a quien se para a reconocer un frente lo ven seguro** (`recon_seen_prob` 1), y la guardia que vio algo **corre la voz** (`spread_alarm_s` 30): a los 30 s los tres frentes están en alarma y la partida se pierde por «descubiertos» antes de la señal (en 1:10). Es una derrota temprana y barata de reintentar, con lección clara: el briefing ya decía «guardia atenta»; el diario anota «Te vieron cerca de la batería» y el «siguiente paso» deja de pedir reconocimiento en ese mundo. Con la guardia descuidada el reconocimiento de la batería es seguro (la guardia ve menos: `noise_mult` 1,5 y altura ×1,25 en vez de 2,0 y ×1,5).

### 3. La guardia que los vio sale entera y manda un jinete

Un frente que da la alarma **porque los vio** antes de la señal (no por el desvelo del alba) sale entero a los puestos (`turnout_garrison_mult` 1,4, bajas ×1,8 para quien lo ataca) y manda un jinete al sur; si nadie lo corta en 40 s, escapa y el refuerzo llega 90 s antes (`messenger_advance_s`). Todo se ve: hay evento y la banda del reloj del refuerzo se acorta.

### 4. El «siguiente paso» ya no conoce el reloj del refuerzo

Planea con la demora **normal** (`reinforcement.hint_plan.default`) descontando lo que el jugador vio (humo quemado, jinete escapado) y, cuando la polvareda ya se ve, con la cuenta exacta. Si el diario de ese mundo anotó una intercepción, planea con la demora **temprana**. En un mundo de refuerzo temprano el que sigue la pista al pie de la letra se queda cargando y destruyendo de más y el refuerzo lo alcanza; al segundo intento sale antes. La línea del mundo del briefing dice «refuerzo: no se sabe hasta ver la polvareda» (antes nombraba la variante). El chip «Refuerzo: entre a y b» cuenta desde la señal.

### 5. Cargar lleva tiempo y el refuerzo tarda más

Carga a 7,5 kg/s por equipo (antes 12): una pieza de 400 kg lleva 18 s. Víveres en seis lotes de 300 kg que tardan 25 s en quemarse. Refuerzo a 420 / 480 / 540 s de la señal (antes 240 / 300 / 360). `capture_k` 1,8 (antes 3,4): la batería y la posta caen en 25–40 s, el cuartel pide apoyo y cae a los 2–2,5 minutos. Bajas 0,08 (antes 0,09), descarga de la torre 2,5 % (antes 2,0).

### 6. El informante de los 0:40 y por dónde entra Portal

A los 0:40 un vendedor de ganado trae dos versiones sobre dónde está la torre con tiradores (una es cierta con probabilidad 0,75). Se ofrece como aviso con botón: el botón cree la segunda versión; sin tocar nada, a los 25 s se toma la primera. Lo que se cree manda la pista de Portal: **por los patios** si la torre está en la casa del cura, **por la calle** si está en el templo (`tower.approach_mult`: la calle a la vista de la torre de la casa del cura recibe ×1,25; tapada para la del templo ×0,6; los patios al revés). Con la guardia atenta la pista siempre manda por la calle (los patios pasan a la vista de la altura). El experto conoce la verdad y le cree a la versión cierta. Una orden de puesto con destino elige el puesto más cercano al destino, así el botón del «siguiente paso» cambia la entrada sin opciones nuevas en la interfaz.

### 7. Siempre hay algo que decidir

- Con las tres partidas en su puesto y todavía de noche, un aviso con botón ofrece dar la señal (`todos_en_puesto`).
- Mientras la torre recarga, un aviso ofrece «Cargar ahora» (`torre_hueco`): quien carga en el hueco llega al pie de la torre antes de la próxima descarga (esa descarga no lo alcanza) y gasta fatiga. Es la ventana de cruce del diseño.
- Mientras la columna carga o marcha, las partidas destruyen lo que quedó a mano (suma destruir × valor al golpe) y después se repliegan de a una por el vado a medida que la columna pasa su altura (Rodríguez, Portal, Arias, reconocedores).
- El arreo sigue destruyendo lo que no entra mientras el reloj estimado lo permita.

### 8. El experto planifica mejor la carga

Elige cada lote por puntos por recurso gastado (tiempo hasta tener que salir y kilos de mula que faltan), con un margen de ruta de 1,2 sobre la recta; durante el ataque no cruza el pueblo por una pieza. Con la guardia atenta no manda reconocedores y llega a los puestos en silencio.

## Qué dejó de valer

- `pending_choice()` devuelve {} en esta versión: la interfaz detiene el reloj de QA mientras hay una decisión pendiente y la resuelve con su reloj de pared, que sin ventana no corre. La decisión se ofrece como aviso con botón y `resolve_choice()` sigue siendo la forma de contestar (la acción `decide` de un aviso la llama).
- El arranque rápido en la extracción (`phase_starts.extraccion`) pasa a 690 s: con la carga más lenta y el refuerzo más tarde, a los 420 s sobraba reloj y la prueba de la interfaz «sin carga el paso salir queda apagado» dejaba de tener sentido.

## Resultados

Ver `evidence/humahuaca/r2b/balance/despues.md`. Lo que se alcanzó y lo que no, en palabras simples:

- **J05 (obediente y torpe):** el obediente queda dentro de 20–45 %; el torpe queda cerca del obediente, por encima del 30 % que pide la rúbrica. El torpe del contrato solo se demora, ignora avisos no urgentes y atrasa la señal; en este nivel ninguna de esas tres cosas decide una partida, porque las derrotas las deciden el mundo (guardia atenta, refuerzo temprano) y no la velocidad de la mano. Hacerlo perder más exigiría inventarle otra torpeza (que no está en el contrato) o un mecanismo de tiempo justo que también castigaría al jugador humano.
- **J07 (duración):** la mediana de las victorias cae entre 11:00 y 13:00 y las derrotas del primer intento son tempranas (mediana cerca de 1:10).
- **J03 por ofertas:** brechas ≤ 45 s y ≤ 20 s en el ataque en las partidas medidas; el informante de los 0:40 tapa el hueco inicial y los repliegues escalonados el final de la marcha.
- **J03 por ramificación:** no se alcanza. Una orden postergada 20 s casi nunca cambia el final en 10 puntos: el nivel tiene decisiones, pero sus consecuencias son graduales. Pedir una decisión de ese peso cada 45 s durante 12 minutos es otra clase de juego (más eventos con reloj y con castigo fuerte) y queda para la ronda siguiente, con diseño.
- **J06:** quedan medibles los cuatro ciegos, cinco estrategias de frente (frontal, gola, calle, patios, directa) y cuatro recetas de extracción; las que piden distraer, voltear piezas u ocultar siguen omitidas porque esas acciones no existen todavía. La matriz corre y se publica; con cinco estrategias no llega a las ocho que pide la rúbrica.
