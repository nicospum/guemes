# Balance del nivel 2 · medición ANTES (R2b, sesión en la nube)

- Commit medido: `333a657` (punta de `humahuaca-r1`), sin cambios.
- Motor: Godot 4.7.2 estable para Linux, `--headless` (SHA-512 verificado contra `SHA512-SUMS.txt` del release).
- Fecha: 2026-11-02. Perfil `user://` aislado (`XDG_DATA_HOME` propio de la sesión).
- Herramienta: `tools/humahuaca_playthrough.gd --level=rules` con la biblioteca única de políticas; agregado con `qa_balance.py` (anexo A3 de `docs/QA_NIVEL2.md`, extraído literal del documento).
- Semillas del QA: 9001–9060 (60), 3 réplicas, hasta 5 intentos (solo repite quien perdió). Ramificación: experto, 9001–9012. Barrido de la señal: 9001–9024, 2:00 a 6:15 cada 15 s.

## Comandos

```
godot --headless --path . --script tools/humahuaca_playthrough.gd -- --level=rules --policies=experto,obediente,torpe,ciego_sin_recon,ciego_tarde,ciego_un_frente,ciego_sin_arreo,pasivo,pausa_reanuda --seeds=9001-9060 --attempts=5 --replicas=3 --out=bots.json
godot --headless --path . --script tools/humahuaca_playthrough.gd -- --level=rules --policies=experto --seeds=9001-9012 --attempts=1 --replicas=1 --measure=decisions --out=decisiones.json
godot --headless --path . --script tools/humahuaca_playthrough.gd -- --level=rules --policies=estrategias,extraccion --seeds=9001-9060 --attempts=1 --replicas=1 --out=matriz.json
godot --headless --path . --script tools/humahuaca_playthrough.gd -- --level=rules --policies=barrido_senal --seeds=9001-9024 --signal-from=120 --signal-to=375 --signal-step=15 --out=senal.json
python -I qa_balance.py --in bots.json decisiones.json matriz.json senal.json --out J
```

## Tasas por política e intento (60 semillas × 3 réplicas; Wilson al 90 %)

| política/intento | n | gana | tasa | Wilson 90 % | mediana victoria | mediana derrota | causas |
|---|---|---|---|---|---|---|---|
| experto/1 | 180 | 180 | 100 % | 0,985–1 | 9:11 | – | – |
| obediente/1 | 180 | 180 | 100 % | 0,985–1 | 8:15 | – | – |
| torpe/1 | 180 | 177 | 98,3 % | 0,959–0,993 | 8:51 | 8:54 | sin_carga 3 |
| torpe/2 | 3 | 3 | 100 % | – | 8:42 | – | – |
| pasivo/1 | 180 | 0 | 0 % | 0–0,015 | – | 6:30 | amanecio 180 |
| pausa_reanuda/1 | 180 | 0 | 0 % | 0–0,015 | – | 6:30 | amanecio 180 |

Los cuatro ciegos, las 8 estrategias de frente y las 5 recetas de extracción quedaron **omitidas** por la biblioteca («se mide desde R2b» / «pide una acción de R2a»): 0 partidas.

El mundo es **fijo** en las 60 semillas (guardia descuidada, torre en la casa del cura, refuerzo normal): la partida del experto es idéntica en todas (misma duración, 551 s); solo el azar propio del torpe cambia algo.

## Ritmo (J03)

- Por ofertas (1443 partidas de experto, obediente, torpe y «pausa y reanuda»): primera decisión 0–1 s; **mayor brecha 102 s** (la marcha del arreo al vado, de 6:18 a 8:00); brecha en el ataque hasta 27 s. 543 partidas incumplen alguna de las tres cifras.
- Tramos sin oferta de una partida obediente (semilla 9001): 4→41 s (37 s), 41→65 s (24 s), **145→210 s (65 s, «esperá la luz del alba»)**, **378→480 s (102 s, «el arreo va camino al vado»)**.
- Por ramificación (experto, 12 semillas): **0 decisiones significativas de 15 órdenes** en cada partida; una orden postergada 20 s nunca cambia el final en ≥ 10 puntos. Las tres cifras valen 551/551/266 s: FALLA.

## Duración y bajas (J07)

- Victorias (experto + obediente, n = 360): mediana **8:44** (524 s); 0 % entre 10:00 y 14:00. Diseño: 11:00–13:00 y ≥ 90 %.
- Derrotas del primer intento (obediente + torpe): n = 3, mediana 8:55.
- Bajas: mediana de las victorias 22 %, ninguna > 80 % (pasa).

## Señal (J06, barrido con el experto, 24 semillas)

Puntaje medio (golpe − 0,5 × bajas) por instante: 2:00 29,3 · 2:30 31,0 · 3:00 33,3 · 3:30 35,3 · 4:00 36,7 · 4:30 38,2 · 4:45 37,8 · 5:00 38,0 · 5:30 37,8 · 6:00 36,3 · 6:15 37,5. Máximo en 4:30–5:00, unimodal, meseta de 13 instantes: **las tres comprobaciones de la señal pasan**, pero la meseta es tan ancha que la hora de la señal casi no importa (diferencia de 9 puntos entre 2:00 y 5:00).

## Veredicto de `qa_balance.py` (antes)

| Criterio | Resultado | Por qué |
|---|---|---|
| J03 | FALLA | brechas de 102 s (ofertas) y 0 decisiones significativas (ramificación) |
| J04 | FALLA | experto 100 % y pasivos 0 % pasan; faltan los ciegos y la escena real (no corre sin pantalla) |
| J05 | FALLA (informe) | obediente 100 % (diseño 20–45 %), torpe 98 % (diseño 5–30 %), sin 3.er intento |
| J06 | FALLA | sin matriz, sin recetas, variantes no activas; la señal pasa |
| J07 | FALLA | mediana de victoria 8:44 (diseño 11:00–13:00) |

Detalle completo en `J_result.json` de esta carpeta.

## Lectura

1. El combate es demasiado fácil: con las alarmas de la batería y del cuartel dadas **antes** de la señal (los reconocedores se acercan de más y las levantan a los 1:10 y 2:02), la batería cae en 44 s y el cuartel en 92 s, sin apoyo.
2. El «siguiente paso» conoce el reloj exacto del refuerzo (`state.alarm.reinforcement_at`): quien lo sigue sale justo a tiempo, siempre.
3. La partida termina a los 8–9 minutos porque la carga se hace a 36 kg/s (1 200 kg de pólvora en 33 s) y el refuerzo llega a los 300 s de la señal.
4. Las variantes del mundo no se sortean: no hay mundos difíciles.
