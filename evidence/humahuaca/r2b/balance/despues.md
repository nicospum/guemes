# Balance del nivel 2 · medición DESPUÉS (R2b, sesión en la nube)

- Código medido: rama `hx-balance-nube`, commit `4dcabe9` (reglas, datos y pruebas) + `18bf2db` (evidencia y notas; no cambia reglas).
- Motor: Godot 4.7.2 estable para Linux, `--headless` (SHA-512 verificado). Perfil `user://` aislado. Corrida del 2026-11-03, 00:17 a 01:26 UTC (los bots y las decisiones; el contenedor se reinició y la matriz, la señal y el determinismo se relanzaron sobre el mismo código, de 01:12 a 01:30).
- Mismos comandos que en `antes.md` (60 semillas 9001–9060, 3 réplicas, hasta 5 intentos; ramificación en 9001–9012; barrido de la señal en 9001–9024), más la matriz de estrategias y recetas (`--policies=estrategias,extraccion`) y dos corridas idénticas para el determinismo (experto, obediente y torpe, 9001–9060).
- Agregados en esta carpeta: `J_result.json` (qa_balance.py), `qa_balance.txt`, `resumen.txt`, `resumen_matriz.txt`, `determinismo.txt`.

## Tasas por política e intento (60 semillas × 3 réplicas; Wilson al 90 %)

| política/intento | n | gana | tasa | Wilson 90 % | mediana victoria | mediana derrota | causas |
|---|---|---|---|---|---|---|---|
| experto/1 | 180 | 180 | **100 %** | 0,985–1 | 11:40 | – | – |
| obediente/1 | 180 | 72 | **40,0 %** | 0,342–0,461 | 11:02 | 1:10 | descubiertos 93 · interceptados 15 |
| obediente/2 | 108 | 108 | 100 % | 0,976–1 | 11:09 | – | – |
| torpe/1 | 180 | 57 | **31,7 %** | 0,263–0,376 | 11:34 | 1:10 | descubiertos 93 · interceptados 30 |
| torpe/2 | 123 | 96 | 78,0 % | 0,713–0,835 | 11:36 | 11:21 | interceptados 27 |
| torpe/3 | 27 | 27 | 100 % | – | 10:44 | – | – |
| ciego_sin_recon/1 | 180 | 0 | 0 % | 0–0,015 | – | 12:45 | interceptados 180 |
| ciego_tarde/1 | 180 | 0 | 0 % | – | – | 1:10 | descubiertos 93 · plazo 57 · interceptados 30 |
| ciego_un_frente/1 | 180 | 0 | 0 % | – | – | 1:10 | descubiertos 93 · frente_roto 87 |
| ciego_sin_arreo/1 | 180 | 0 | 0 % | – | – | 1:10 | descubiertos 93 · interceptados 87 |
| pasivo/1 · pausa_reanuda/1 | 180 · 180 | 0 | 0 % | – | – | 6:30 | amanecio 180 · 180 |

Obediente por mundo (victorias/partidas): guardia atenta 0/93 en los seis mundos; guardia descuidada 72/87: gana todo con refuerzo normal y tardío (57/57) y con refuerzo temprano gana 15/30 (0/15 con la torre en la casa del cura, 15/15 con la torre en el templo).

Cobertura de variantes en las 60 semillas: guardia descuidada 29 / atenta 31; torre templo 31 / casa del cura 29; refuerzo normal 25 / temprano 19 / tardío 16.

## Ritmo (J03)

- Por ofertas, en las 1 698 partidas de experto, obediente, torpe y «pausa y reanuda»: primera decisión ≤ 1 s, **mayor brecha 40 s**, mayor brecha en el ataque **18 s**: **0 partidas incumplen** (antes: 102 s y 27 s; 543 incumplían).
- En la matriz de estrategias, 29 partidas de `est_bateria_gola` tienen una brecha de 87 s (la gola lleva a Rodríguez bajo la torre y por delante de la batería: la partida se tuerce temprano). `qa_balance.py` las cuenta en J03 y, además, reemplaza las 12 partidas del experto por sus filas de ramificación (abajo), por eso su veredicto J03 por ofertas sale FALLA con «peor 704 s»: ese 704 es la medida por ramificación, no por ofertas.
- Por ramificación (experto, 12 semillas): **2 decisiones significativas en 215 órdenes** (una en las semillas 9001 y 9003, a los 5:08: dar la señal; 0 en las otras diez). Una orden postergada 20 s casi nunca cambia el final en 10 puntos. **FALLA**, igual que antes (0 de 180).

## Duración y bajas (J07)

- Victorias (experto + obediente, n = 360): mediana **11:10** (669,8 s); **95,8 %** entre 10:00 y 14:00. Diseño: 11:00–13:00 y ≥ 90 %. **PASA** (antes 8:44 y 0 %).
- Derrotas del primer intento (obediente + torpe, n = 231): mediana **1:10**, máxima 11:33. **PASA**.
- Bajas: mediana de las victorias 28,9 %; 0 % con bajas > 80 %. **PASA**.

## Matriz (J06, base)

| política | victorias / 60 | mediana | derrotas |
|---|---|---|---|
| est_bateria_frontal | 60 (100 %) | 11:40 | – |
| est_bateria_gola | 19 (31,7 %) | 10:25 | descubiertos 31 · sin_carga 10 |
| est_cuartel_calle | 60 (100 %) | 11:40 | – |
| est_cuartel_patios | 29 (48,3 %) | 11:40 | descubiertos 31 (guardia atenta: los patios pasan a la vista de la altura) |
| est_posta_directa | 60 (100 %) | 11:40 | – |
| ext_mixta | 60 (100 %) | 11:40 | – |
| ext_cargar_todo | 10 (16,7 %) | 10:59 | sin_carga 50 |
| ext_ligera | 10 (16,7 %) | 10:59 | sin_carga 50 |
| ext_destruir_todo | 0 | – | interceptados 60 |

Omitidas con motivo (piden acciones de R2a que no existen): `est_bateria_distraccion`, `est_cuartel_piezas`, `est_posta_distraccion`, `ext_ocultar`. La rúbrica pide 8 estrategias (hay 5), que ninguna gane en > 80 % de los mundos (tres ganan el 100 %: con el experto detrás, el enfoque por defecto gana siempre) y que cada enfoque sea el mejor en algún mundo (la gola nunca lo es; los patios lo son en 14 mundos). **FALLA**, como se esperaba para una base.

## Señal (J06, barrido con el experto dando la señal apenas una partida está en su puesto, 24 semillas)

Puntaje medio por instante: 2:00 29,7 · 2:15 16,5 · 2:30 16,4 · 3:00 17,1 · 3:30 20,5 · 4:00 30,9 · 4:15 35,8 · 4:30 35,9 · 4:45 37,0 · **5:00 37,2** · 5:15 36,9 · 5:30 36,3 · 5:45 35,0 · 6:00 29,4 · 6:15 29,4. Máximo en 5:00 con meseta de 7 instantes: pasan el máximo y la meseta; **falla la unimodalidad** por el pico de 2:00 (a esa hora solo Rodríguez está en su puesto: la señal con una sola partida y las otras llegando después rinde más que a las 2:15–3:30, cuando llegan de a una bajo la guardia ya alerta). Antes el barrido pasaba porque la hora de la señal casi no cambiaba nada (29 a 38 puntos); ahora la curva tiene forma (16 a 37).

## Determinismo

Dos corridas idénticas de experto, obediente y torpe en 9001–9060: **180 partidas comparadas, 0 distintas** (`snapshot_sha256`).

## Veredicto de `qa_balance.py` (después)

| Criterio | Resultado | Por qué |
|---|---|---|
| J03 | FALLA | ofertas: 0 de 1 698 partidas de bots incumplen (brecha 40 s, ataque 18 s), pero la matriz suma 29 partidas de la gola con 87 s y la rúbrica exige también la ramificación: 2 decisiones significativas en 215 |
| J04 | FALLA solo por la escena | experto 100 %, los cuatro ciegos 0 %, pasivos 0 % por amanecio: pasan; faltan las filas de la escena real (`--level=scene`), que no corre sin pantalla |
| J05 (informe) | obediente PASA, torpe FALLA | obediente 40,0 % (20–45); torpe 31,7 % (5–30), apenas por encima; obediente gana alguna vez en ≤ 5 intentos: 100 %; 3.er intento del obediente sin muestra (todos ganan al 2.º) |
| J06 | FALLA | base: 5 estrategias y 4 recetas medidas; el enfoque por defecto del experto gana siempre; señal bimodal |
| J07 | **PASA** | victorias 11:10 de mediana y 95,8 % en 10:00–14:00; derrotas 1:10; bajas 28,9 % |

Pruebas sobre este código, con `--headless` y perfil aislado: `test_hx_rules` 682/0, `test_hx_data` 421/0, `test_hx_flow` 285/0, `test_hx_terrain` 158/0, `test_rules` (Justina) 871/0.
