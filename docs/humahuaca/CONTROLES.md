# Controles del nivel «Humahuaca»

Dueña: `ui_feel`. La tabla sale de `data/humahuaca_ui.json` (`key_table`); `test_hx_flow::_test_key_table` verifica que **cada fila figure acá** y `docs/CONTROLES.md` (el de todo el juego) la referencia en [final]. Todo se puede hacer con el mouse; las teclas son atajos. El nivel se juega en **tiempo real con pausa**: el indicador de arriba dice siempre `TIEMPO REAL · ▶ ×1` o `‖ EN PAUSA`, y la velocidad **nunca cambia sola** (cuando hay una espera tranquila el juego solo *sugiere* acelerar, con un botón).

## Lo básico en 30 segundos

1. Mirá el **siguiente paso** (abajo): es una sola cosa por vez y tiene su botón (con la tecla entre corchetes). Si no sabés qué hacer, apretalo.
2. El reloj arranca con tu **primera orden** (o con Espacio): si a los 12 segundos no diste ninguna, un aviso te lo recuerda. Podés pausar en cualquier momento para pensar y dar órdenes.
3. Elegí una agrupación con las teclas **1 a 5** o con un clic en su ficha; con el **clic derecho** le das la orden más lógica al punto o al frente que señalás.

## Tiempo

| Tecla o gesto | Qué hace |
|---|---|
| Espacio | Pausa o sigue el tiempo |
| F2 | Tiempo real ×1 |
| F3 | Doble velocidad ×2 |
| F4 | Cuádruple velocidad ×4 |
| + | Más velocidad |
| − | Menos velocidad |

## Interfaz y partida

| Tecla o gesto | Qué hace |
|---|---|
| F1 | Cómo se juega |
| Esc | Cancela lo que hacés o abre el menú de pausa |
| F5 | Guarda la partida |
| F9 | Recupera la partida guardada |
| F11 | Pantalla completa |

## Elegir agrupaciones

| Tecla o gesto | Qué hace |
|---|---|
| 1 | Partida de Rodríguez (otra vez: centra la cámara en la batería) |
| 2 | Partida de Portal (otra vez: centra la cámara en el cuartel) |
| 3 | División de Arias (otra vez: centra la cámara en la posta) |
| 4 | Reconocedores (otra vez: centra la cámara en ellos) |
| 5 | Arreo (otra vez: centra la cámara en él) |
| Tab | Pasa a la agrupación siguiente (Mayús: la anterior) |
| Ctrl+Z | Deshace la última orden |
| Clic o caja | Elige agrupaciones (Mayús suma, Ctrl alterna) |

## Cámara y mapa

| Tecla o gesto | Qué hace |
|---|---|
| W A S D o flechas | Mueve la cámara (Mayús: más rápido) |
| Q y E | Gira la cámara |
| RePág y AvPág | Inclina la cámara |
| Inicio | Vuelve al cuadro inicial |
| Rueda del mouse | Acerca y aleja hacia el cursor |
| Botón del medio | Arrastra el mapa |
| M | Agranda o achica el minimapa |

## Acciones (barra de abajo)

| Tecla o gesto | Qué hace |
|---|---|
| G | Mover (a un punto del mapa) |
| P | A su puesto de ataque |
| T | Atacar el frente (con Ctrl, a fondo) |
| C | Socorrer a otra partida |
| R | Reconocer un punto |
| L | Cargar en el arreo |
| X | Destruir lo que no se lleva (se pregunta antes, salvo que el siguiente paso lo pida) |
| V | Salir por el vado, al este |
| F | Dar la señal |
| H | Sostener lo tomado |
| Supr | Cancela la orden en curso |

## Órdenes con el mouse

| Tecla o gesto | Qué hace |
|---|---|
| Mayús + clic | Suma una parada a la ruta (hasta 4) |
| Ctrl + clic | Marcha a la carrera |
| Alt + clic | Marcha en silencio |
| Clic derecho | Da la orden más lógica al punto o al frente |

## Por qué algunas teclas no son las que dice `humahuaca_rules.json`

`humahuaca_rules.json` sugiere un atajo por acción (`actions.*.shortcut`), pero cuatro chocan con la cámara o el minimapa y se **remapearon** (la interfaz lee solo `key_table`, así que lo que vale es esta tabla):

| Acción | Atajo sugerido por reglas | Tecla en el juego | Motivo |
|---|---|---|---|
| Mover (a un punto del mapa) | `m` | `G` | M agranda el minimapa |
| Atacar el frente | `a` | `T` | A mueve la cámara |
| Socorrer a otra partida | `s` | `C` | S mueve la cámara |
| Salir por el vado, al este | `e` | `V` | E gira la cámara |

## Esc: cancelar o abrir el menú

- Con una orden en la mano (modo apuntado) o paradas sueltas: **cancela** eso y nada más.
- Con una ventana abierta: la cierra (el parte y la presentación no se cierran con Esc). El diario y «Cómo se juega» **vuelven adonde estabas**: si los abriste desde el menú de pausa, vuelven al menú de pausa (el reloj sigue frenado y «Seguir jugando» lo retoma como estaba); si los abriste desde el parte de una partida terminada, vuelven al parte, que siempre tiene a la vista «Reintentar» o «Jugar de nuevo». Esc sobre la pregunta de la retirada general es «No».
- Sin nada que cancelar y **antes de dar la primera orden** (con menos de 20 s de juego): vuelve al menú del juego; no hay nada que perder.
- Después: abre el **menú de pausa** (seguir, guardar, cargar, ayuda, diario, retirada general con dos clics, volver al menú).
- Durante la presentación de cámara, **cualquier tecla** la salta; en el briefing, Enter es «Empezar» y Espacio empieza ya con el reloj corriendo.

## Fichas, avisos y cartel de cada cosa

Cada ficha de agrupación (teclas 1 a 5) muestra, de arriba abajo: su número y nombre, lo que está haciendo en palabras, y las barras de **fuerza** (la gente en pie) y **fatiga** (el cansancio). Al elegirla suma, junto a las barras, la **etiqueta de fuente** (▲ diseño, ● documentado, ◇ razonado, ◆ discutido, ○ sin datos) y el **ruido** (●○○ en silencio, ●●○ se oye, ●●● los oyen); los dos explican qué son al pasar el mouse. Los chips de golpe, carga y refuerzo y la línea de la señal (oscuridad y desvelo) también traen su cartel, y F1 explica todo en «Qué significa lo que ves». El chip de **carga** se ve apenas el arreo empieza a cargar, ya en el ataque.

Cada orden dada se nombra en un aviso de pie («Orden dada a Rodríguez: Atacar»). Si una agrupación no puede hacer lo que le pedís, el motivo dice quién sí («Eso lo hacen Rodríguez, Portal y Arias (teclas 1 a 3)»). **Destruir** apretado a mano (X o el botón de la barra) pregunta una vez, porque no se deshace y quemar la pólvora adelanta al refuerzo; si es el siguiente paso el que lo pide, se hace directo. Pulsar otra vez 4 o 5 centra la cámara en los reconocedores o en el arreo. Mayús + clic derecho fuera del mapa no suma la parada y dice por qué. Si el botón del siguiente paso está apagado, el paso dice la causa («… El arreo no lleva carga.»).

## Ritmo de marcha y paradas

Al apuntar «Mover» aparecen tres botones de ritmo (*En silencio*, *Marcha*, *A la carrera*); con el clic derecho, **Alt** marcha en silencio y **Ctrl** a la carrera. **Mayús + clic** suma una parada (hasta 4 en «Mover» y 2 en «Reconocer»). La vista previa dice cuántos metros son, cuánto se tarda y el riesgo de que te vean, sin dar la orden. **Ctrl** con la tecla de «Atacar» ataca *a fondo* (más poder y más bajas); sin Ctrl, *con cautela*.

## Avisos, barra de órdenes y panel de abajo

Abajo hay **una sola columna que crece hacia arriba**, así que nada se pisa aunque haya de todo a la vez. De arriba hacia abajo: (1) las **notas al pie** (un aviso a la vez y, si una capa corre en su versión mínima, la línea roja); (2) la **barra de órdenes**, que solo existe mientras hay algo que decir o hacer con lo que elegiste: la línea de motivo y el estado de la señal y de la torre arriba, y debajo las acciones (si no entran en una línea siguen en la de abajo) y, al apuntar, los tres ritmos de marcha; (3) el **panel de abajo**: el objetivo en una línea, el **siguiente paso** en su propia fila (de dos líneas como máximo, con su botón) y las cinco fichas de agrupación. En el primer cuadro no hay barra ni notas: solo el panel de abajo, de alto fijo en todas las fases. El objetivo es **una sola línea y cambia con la fase** (H-R1-10): en la preparación dice el golpe entero; en la aproximación, llevar a cada partida a su puesto y dar la señal antes del alba; en el ataque, tomar los tres frentes a la vez y socorrer; en la extracción, cargar y salir por el vado antes del refuerzo. De cada fase hay una frase completa y otras más cortas (`texts.objective.by_phase` en `humahuaca_ui.json`) y el HUD pone la más completa que entra **entera** junto a los chips de golpe, carga y refuerzo: a 1024 × 640 en la extracción entra la mediana o la corta, y nunca queda cortada con «…». Si las reglas dan algún día la frase de cada fase (BACKLOG B-048), `texts.objective.source = "rules"` hace que mande la de ellas. Lo que aparece o desaparece está siempre *encima* de lo que no, para que los botones no se muevan bajo el cursor.

Una sola alerta a la vez, y solo si pide algo (lleva un botón) o es crítica; lo que apenas informa sale como nota breve abajo a la izquierda, una vez. La alerta aparece debajo de los frentes, al centro (en ventanas chicas es más angosta, 40 % del ancho, para entrar entre las fichas), y se **corre** a la derecha o a la izquierda si taparía una ficha o el rótulo de un frente (`HxHud.place_alert`, que recibe de la interfaz los rectángulos de las fichas). Mientras su lugar siga libre no salta de un lado al otro. Si el botón de la alerta repite el del «siguiente paso», se muestra una sola vez.

## Qué cuenta como «control» en el primer cuadro

La rúbrica pide ≤ 5 controles accionables (C03). Se cuentan **grupos**: pausa y velocidades son uno; ayuda y menú, otro; el botón del siguiente paso, otro; y cada botón de la barra de acciones, uno más. Las fichas de agrupación y las tarjetas de frente se eligen con el mouse pero son información, no controles. `qa_state()` informa `visible_controls` (grupos) y `visible_buttons` (botones sueltos).

## Legibilidad

Desde 1024 × 640 el texto de la interfaz no baja de 12 px reales (13 en los títulos y 15 en el cuerpo): en ventanas menores que la base de 1440 × 900 la interfaz propia se agranda (`ui_scale`). **Ningún texto queda cortado** a 1280 × 720, 1024 × 640, 1920 × 1080 ni 2560 × 1440: lo que no entra se acorta por partes (la línea de estado de un frente saca primero el apoyo y la sorpresa; la etapa de una ficha usa su texto compacto, «Sostiene lo tomado») y la frase completa queda en el cartel. `tools/ui_qa_humahuaca.gd` y `tests/test_hx_flow.gd` lo miden con la misma cuenta que la sonda de recortes del QA (`Kit.cut_labels`). El cuadro inicial deja las cinco partidas con su anillo entero a la vista (a ≥ 6 % del borde, también a 1024 × 640) y por encima de lo que ocupan la cabecera, el panel de abajo y una barra de órdenes de una línea. Ningún dato depende solo del color: el riesgo de una ruta cambia también el trazo (continuo, largo, corto) y se dice con palabras; el ruido de cada partida son tres puntos (●○○, ●●○, ●●●) con su nombre en el cartel; las etiquetas de fuente llevan glifo (● ◇ ◆ ▲ ○).
