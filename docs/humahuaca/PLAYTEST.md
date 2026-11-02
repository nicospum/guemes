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

**Cuándo corre.** Informativa al cierre de R1 y de R2a (para enterarse temprano de que «no se entiende»), **aprobada** desde R2b y en la certificación del QA. La corre el integrador o compuertas y documentos con `tools/hx_agent_play.gd` (R1) y la registra abajo.

## Registro de corridas del agente-jugador

| Fecha | Ronda | Commit | Turnos hasta la primera orden | Segundos de juego hasta la primera orden | Parte alcanzado | ¿Entendió qué hacer? | ¿Cuándo se aburrió? | Veredicto |
|---|---|---|---|---|---|---|---|---|
| — | — | — | — | — | — | — | — | Todavía no hay corridas: el arnés llega en R1 |

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
