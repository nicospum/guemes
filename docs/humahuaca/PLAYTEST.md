# Playtest del nivel «Humahuaca»

Registro de las pruebas de juego del nivel. Lo lleva «compuertas y documentos».

## Estado

**Sin playtesters humanos.** Decisión del usuario del 1 de noviembre de 2026 (ADDENDA A-03, punto 2): nadie jugará a mano. Los mini-playtests de 10 minutos al cierre de R1 y R2b y la sesión humana de 20 minutos **no se hacen**. El **agente-jugador** (arnés `tools/hx_agent_play.gd`) los reemplaza.

**El veredicto máximo del QA es «PRESENTABLE, no certificado por humanos»** y nunca «certificado». Cualquier cifra de balance (tasas de victoria del obediente y del torpe, duración, bajas) viene de políticas escritas por las pistas, no de personas, y se informa con intervalos de Wilson al 90 %: no certifica nada. Si algún día una persona juega y contradice al modelo, **manda la persona** (DISEÑO, sección 10).

## El agente-jugador (lo que reemplaza al humano)

Un agente **sin acceso al código, a `qa_state()` ni a las reglas** juega por la interfaz real: ve una captura de 1280 × 720, decide, y el arnés inyecta la entrada como hace `ui_qa` (el juego queda en pausa entre turnos y avanza unos segundos de juego por turno). El arnés **no** le muestra ni el estado ni el código: solo la captura de cada turno.

| Qué se mide | Aprobación (J08 de la rúbrica) |
|---|---|
| Primera orden aceptada | 40 s de juego o menos y 8 turnos o menos |
| Objetivo dicho con sus palabras | Al menos 2 de 3 conceptos: tomar los tres frentes; sacar carga; antes del refuerzo o del alba |
| Llega a un parte (victoria o derrota) | 150 turnos o menos |
| Si pierde | Reintenta y dice qué aprendió |
| Tres objetivos en `juego_noche` | Los identifica en menos de 3 turnos |
| Lecturas fuera de su carpeta | Cero |
| Preguntas finales | Responde «¿entendiste qué hacer?» y «¿cuándo te aburriste?» |

Se informa (no bloquea) cualquier racha de 4 turnos seguidos esperando sin nada que decidir.

**Cuándo corre.** Informativa al cierre de R1 y de R2a (para enterarse temprano de que «no se entiende»), **aprobada** desde R2b y en la certificación del QA. La corre el integrador o compuertas y documentos con `tools/hx_agent_play.gd` (R1) y la registra abajo; como el agente tiene que ser un subagente nuevo sin acceso al código, quien escribió el arnés no puede serlo (B-027).

## Cómo se corre el arnés (protocolo por archivos)

```sh
G="C:/Users/User/Desktop/spum/IA/Proyectos/MaravillaArgentina/guemes/patria-guemes/.tools/godot/Godot_v4.7.2-stable_win64_console.exe"
export APPDATA="$TEMP/ap_iso_<quien>"; rm -rf "$APPDATA"; mkdir -p "$APPDATA"
"$G" --path "<repo>" --resolution 1280x720 --audio-driver Dummy --script tools/hx_agent_play.gd -- --turns-dir=<carpeta> --out=<arnes.json> --seed=<N> --step-s=3 --max-turns=150 [--wait-s=120] [--selftest]
```

| Quién | Qué escribe en `<carpeta>` |
|---|---|
| El arnés (lado del juego) | `turno_NN.png`, de 1280 × 720, lo que ve quien juega (sin `qa_state()` ni código); lo escribe con otro nombre y lo renombra, así que el agente nunca lee una imagen a medias |
| El agente | `accion_NN.json` (`{"tipo":"clic","x":..,"y":..,"boton":"izq"}`, `{"tipo":"tecla","tecla":"4"}` o `{"tipo":"esperar","s":3}`), `bitacora.md` (qué ve y qué prueba antes de cada acción) y, al terminar, `respuestas.json` |
| El arnés, al cerrar | `--out` (`arnes.json`, esquema `hx_agente_v1`): `turnos[]` (con `t_juego_s` y `t_despues_s`), `primera_orden_turno` y `primera_orden_t_s`, `intentos[]`, `objetivos_identificados_en_turnos`, `cierre` y `archivos_viejos_borrados`; y en la carpeta de turnos `fin.json` (`{"cierre", "turnos"}`: la razón del cierre y cuántos turnos hubo, nada del estado del juego), para que un agente que espera el turno siguiente sepa que la corrida terminó |

- **Cada turno pasa `--step-s` segundos de juego** (también si la acción es un clic o una tecla) y `esperar` pasa hasta 60. En el briefing no pasa tiempo y en la apertura pasa tiempo real. **Cuenta de tiempo:** 150 turnos de 3 s son 450 s de juego como máximo y una victoria del bot de interfaz dura de 496 a 551 s, así que un agente que solo espere de a 3 s no puede ganar dentro de los 150 turnos; tiene que esperar de a más o el QA tiene que subir `--step-s`.
- **Archivos viejos.** Al arrancar el arnés borra de la carpeta los `turno_NN.png`, `accion_NN.json`, `respuestas.json` y `fin.json` de una corrida anterior (antes los consumía: una acción vieja se aplicaba en el turno 1 y unas respuestas viejas cerraban la corrida) y no toca `bitacora.md`. Lo informa como `archivos_viejos_borrados`.
- **Cierres** (`cierre`): `respuestas` (el agente escribió `respuestas.json`), `max_turnos`, `abandono` (el agente no contestó en `--wait-s`, 120 s por defecto), `sin_captura` y `sin_controlador`. Una acción mal escrita (JSON roto, tipo desconocido o clic fuera de la ventana) no se aplica, queda registrada con `aplicada: false` y el turno sigue: pasan los `--step-s` y se entrega el cuadro siguiente. Un archivo que llega a medias se vuelve a leer hasta 3 s.
- **`objetivos_identificados_en_turnos` (J08: «identifica los 3 objetivos en < 3 turnos en `juego_noche`»).** El arnés no puede leer la mente del agente y los clics no sirven (tres frentes necesitan tres clics: nunca daría menos de 3), así que lo mide con la bitácora: cuenta los turnos desde el primer cuadro con mapa (la apertura o el juego; `mapa_desde_turno`) hasta que lo que el agente escribió **desde ese cuadro** nombra los tres frentes (batería o Santa Bárbara; cuartel o casa del cura; posta o pólvora). Lo escrito antes de ver el mapa (por ejemplo, lo que lee del briefing) no cuenta; -1 si nunca los nombra o no hay bitácora. Los clics sobre los frentes quedan aparte (`objetivos_tocados`, `objetivos_tocados_en_turnos`).
- **`lecturas_fuera_de_carpeta`** vale 0 por defecto porque el arnés no puede ver qué lee el agente: lo corrige el Jefe de QA después de auditar el registro de herramientas del agente (P6-e).
- **Pruebas del arnés** (la compuerta completa las corre desde `r1`): `--selftest` (el arnés contesta solo con el botón de «siguiente paso» y comprueba el lazo de punta a punta: primera orden en el turno 4 a los 3,0 s), `hx_agent_partida` (un agente de guion repite por archivos las 30 acciones de ese `--selftest` y el arnés tiene que dar la misma partida turno a turno: `python tools/hx_agent_guion.py --turns-dir <carpeta> --arnes <arnes.json> --guion repetir:<arnes del selftest>`), `hx_agent_protocolo` (un agente de guion, `tools/hx_agent_guion.py`, que escribe cada acción por archivo, una de cada dos a medias, más un JSON roto, un clic fuera de la ventana y un tipo desconocido, anota su bitácora y cierra con `respuestas.json`) y `hx_agent_viejos` (archivos viejos y abandono). Ninguna es una corrida del agente-jugador.

## Registro de corridas del agente-jugador

| Fecha | Ronda | Commit | Turnos hasta la primera orden | Segundos de juego hasta la primera orden | Parte alcanzado | ¿Entendió qué hacer? | ¿Cuándo se aburrió? | Veredicto |
|---|---|---|---|---|---|---|---|---|
| 2-nov-2026 | R1 | `70124a0` | 4 | 3,0 | con las 30 acciones del `--selftest` repetidas **por archivos** (agente de guion, `--step-s=3`): derrota `frente_roto` a los 234,8 s (turno 30), la misma que da el `--selftest` en la compuerta; con un clic en «Reintentar» (927, 492) sigue el intento 2 desde la aproximación, sin briefing | n/a (el guion escribió unas respuestas de prueba) | n/a | **Prueba del protocolo, no del agente.** El resultado por archivos es idéntico al del `--selftest` en las 30 acciones y los 30 tiempos de juego; `qa_agente.py` (anexo A7) lee el `arnes.json` y da 8 de 8 (con el reintento) y 7 de 8 (sin él, porque no reintentó): primera orden en el turno 4 (3,0 s), tres frentes identificados en 1 turno por la bitácora, 0 lecturas fuera de la carpeta |
| 2-nov-2026 | R1 | `15627bb` | 4 | 3,0 | con `--selftest` y esperas de 3 s: ningún parte en 150 turnos (a los 441 s de juego el arreo todavía iba al vado); con `--selftest=pasivo`: derrota por `amanecio` a los 390 s (turno 16) y, tras «Reintentar», dos derrotas por `interceptados` a los 582 s (el bot esperaba de a 12 s). El bot del recorrido, que avanza de a 1 s, gana a los 497 s | n/a | n/a | **Prueba del arnés, no del agente.** El arnés contestó solo con el botón de «siguiente paso» (con información que un agente no tiene): comprueba el lazo de punta a punta (`turno_NN.png`, `accion_NN.json`, `arnes.json` `hx_agente_v1`, reintento y cierres), no que el nivel se entienda |
| 2-nov-2026 | R1 (pase 2) | `10d9ae0` | 4 | 3,0 | con `--selftest` (30 turnos de 3 s, el arnés contesta solo con el botón de «siguiente paso»): primera orden en el turno 4 a los 3,0 s de juego y cierre `max_turnos` con una derrota `frente_roto` a los 234,8 s (turno 30), igual que en R1. Con el agente de guion por archivos: 8 turnos y 9 comprobaciones sin fallas (acción a medias, JSON roto, clic fuera de la ventana, tipo desconocido, `respuestas.json` y bitácora), y con archivos viejos en la carpeta el arnés los borra (3) y abandona a los 4 s. El bot del recorrido de QA, que avanza de a 1 s, gana a los 496,8 s con 21 órdenes (medalla de bronce) | n/a | n/a | **Prueba del arnés, no del agente.** Lo mismo que en R1, con el código del pase 2 (`ui_feel` y `reglas_historia` fusionados y hook-10): el lazo de punta a punta funciona y la primera orden entra a los 3 s. No dice que el nivel se entienda (B-027) |
| 2-nov-2026 | R1 (pase 2) | `0758465` | 4 | 3,0 | con `--selftest` (30 turnos de 3 s, el arnés contesta solo con el botón de «siguiente paso»): primera orden en el turno 4 a los 3,0 s y cierre `max_turnos` con la derrota `frente_roto` a los 234,8 s (turno 30), igual que en R1. **Las mismas 30 acciones repetidas por archivos por un agente de guion dan la misma partida turno a turno** (acción, aplicada, orden aceptada, modo, diálogo, fase, tiempo de juego antes y después, primera orden e intentos; desde este pase la compuerta lo exige: `hx_agent_partida`, 30,8 s). Con el agente de guion del protocolo: 8 turnos y 9 comprobaciones sin fallas, y con archivos viejos en la carpeta el arnés los borra (3), abandona a los 4 s y deja `fin.json` con `abandono`. El bot del recorrido, que avanza de a 1 s, gana a los 496,8 s con 21 órdenes (bronce) | n/a | n/a | **Prueba del arnés, no del agente.** El lazo de punta a punta funciona con el código del pase 2 y el protocolo por archivos no cambia la partida; no dice que el nivel se entienda (B-027) |
| 2-nov-2026 | R1 | `224140f` | 3 | 3,0 | `arnes.json` guardado: 60 turnos con `--step-s=3`, cierre `respuestas`, dos derrotas por `interceptados` a los 434 s (turnos 43 y 58) y un tercer intento sin terminar. El informe del QA cita otras cifras de esa corrida (74 turnos y tres derrotas en 131) que no están en el archivo guardado | Sí, con sus palabras: «Tomar a la vez la bateria, el cuartel y la posta con la polvora de noche, con unas 150 personas casi sin armas, y sacar la carga por el vado al este antes de que llegue el refuerzo» (los tres conceptos de J08). Le costó entender cuándo salir con la carga y qué miden «Golpe», «Desvelo» y el símbolo ▲ con puntos | En la aproximación (entre 2 y 4 minutos de juego): largos tramos de solo esperar a que lleguen las partidas, sin nada que decidir salvo la señal; y en la carga del arreo, donde hay que volver a apretar «Cargar» cada unos 20 s | **Corrida de un agente de verdad** (un subagente sin acceso al código, del revisor de usabilidad del QA; evidencia en `evidence/humahuaca/r1/rev/usabilidad/agente/`). El QA la usa solo como referencia (J08 es informe en R1). Tres frentes nombrados en la bitácora a 2 turnos del primer cuadro con mapa; lecturas fuera de la carpeta: 0 por defecto del arnés, sin auditar. Lo que dijo y no figuraba en el backlog está en B-052 |
| — | — | — | — | — | — | — | — | **Falta la corrida del Jefe de QA para J08** (BACKLOG B-027): la hace él con un subagente nuevo, sin acceso al código ni a `qa_state()`, con `tools/hx_agent_play.gd -- --turns-dir=<carpeta> --out=<arnes.json> --step-s=3 --max-turns=150`; la del revisor de usabilidad de arriba no la reemplaza |

## Lo que se ve en las capturas del arnés (lectura de quien lo escribió, no del agente; `70124a0`)

Se miraron con `Read` los turnos 1 a 3, 26, 28, 30 y 31 de la repetición por archivos. Sirve para enterarse temprano de lo que un agente sin código va a ver; no reemplaza su corrida (B-027).

- **Turno 1, briefing (página 1):** «Esta noche, con lluvia, tenés unas 150 personas casi sin armas y un amanecer por delante. Tomá la batería, el cuartel y la pólvora a la vez y sacá lo que puedas antes del refuerzo. Perder no es grave: volvés a intentar con lo que aprendiste.» Las tres ideas que pide J08 (tomar los tres frentes, sacar carga, antes del refuerzo o del alba) están dichas en tres frases llanas, con «Seguir leyendo» y «Empezar».
- **Turno 2, página 2:** la carta del 26 de febrero marcada «Dramatización», la fecha discutida (1 o 2 de marzo) y «Qué es real y qué es diseño» (el relieve es dato actual; el refuerzo es un recurso del juego). Las etiquetas honestas ya están en el briefing.
- **Turno 3, apertura:** una cámara baja sobre el pueblo con una cita de Arias («La mayor parte sin más armas que palos») y «Cualquier tecla salta la presentación».
- **Primer cuadro:** cinco fichas con su anillo y su número, tres luces amarillas con su rótulo (batería, cuartel, posta), una sola línea de objetivo, un solo «Siguiente paso: Mandá a los reconocedores a mirar la batería.» con su botón «Reconocer [R]», el reloj «Falta el alba: 4:30» y el minimapa. A 1280 × 720 las cinco fichas y los tres objetivos quedan a la vista.
- **Ataque (turnos 26 a 30, de 157 a 234 s):** la batería y la posta tomadas, el cuartel «Asaltado · Toma 12 % a 23 %»; el «Siguiente paso» dice «Esperá la toma de el cuartel.» (contracción sin hacer, B-036) mientras la partida de Portal se rompe bajo la torre, sin un aviso crítico a la vista (B-037).
- **Turno 31, parte de derrota:** «A los 3:54 la partida de Portal quedó clavada frente al cuartel y se rompió bajo el fuego», un consejo («Atacá con cautela y mandá a Arias en apoyo»), tres datos y el tiempo (frentes 2 de 3, golpe 0 de 100, bajas 35 %, tiempo 3:54) y «Reintentar» como botón primario sin scroll. Al reintentar sigue el intento 2 desde la aproximación, sin briefing.
- **Pase 2 (`0758465`, turno 30 de la partida repetida por archivos, 233 s):** el «Siguiente paso» dice «Esperá la toma del cuartel.» (la contracción de B-036 está arreglada); las fichas 2, 3 y 4 siguen apiladas sobre la batería (B-049) y el parte de derrota llega recién en el turno 31, que una corrida de 30 turnos no escribe. Captura en `evidence/humahuaca/r1/compuertas/cierre_r1_p2/14_agente_repeticion_turno_30_compuertas_r1p2.jpg`.

## Plantilla del mini-playtest humano (no se usa en este circuito)

Se deja por si alguna vez aparece una persona. Son **10 minutos**, una persona, sin explicarle nada antes, y se anota:

1. Quién juega y su experiencia con juegos de estrategia en tiempo real (ninguna, poca o mucha).
2. **¿Entendiste qué hacer?** Con sus palabras, a los 30 segundos y al final.
3. **¿Cuándo te aburriste?** Minuto aproximado y qué estaba pasando.
4. **¿Qué cambiarías primero?**
5. Cuánto tardó en dar la primera orden, si ganó o perdió y si quiso reintentar.

Todo lo que diga una persona **manda sobre el modelo**. Cada observación va al backlog (BAJA) o se convierte en un hallazgo con evidencia, según el presupuesto de la ronda.

## Sesión humana de 20 minutos (anexo E del QA)

Opcional y aparte, tres personas. **Solo ella quita el sello «no certificado por humanos».** No es un paso del bucle y no bloquea la salida.
