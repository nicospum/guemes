# Revisión de textos visibles del nivel II (2 de noviembre de 2026, rama `hx-docs-nube`)

Revisión de «compuertas y documentos» sobre `333a657` (`humahuaca-r1`): jerga, inglés, anacronismos, errores de ortografía y frases que no se entienden al primer intento. Lo que está en archivos de esta pista se corrigió acá; lo que pertenece a otra pista queda listado con el texto de reemplazo listo para pegar. Nadie de esta pista tocó `data/humahuaca_rules.json`, `data/humahuaca_level.json`, `data/humahuaca_visual.json`, `scripts/humahuaca/**` ni `scripts/main.gd`.

**Cómo se revisó.** (1) El escáner de jerga del QA (P5-d de `docs/QA_NIVEL2.md`: lista negra de 34 términos de `humahuaca_ui.json`, siglas en mayúsculas, identificadores en snake_case y textos enteros en mayúsculas) sobre los cuatro JSON y `scripts/humahuaca/ui/*.gd`: **0 aciertos** sobre `333a657` y sobre esta rama. (2) Lectura completa de `humahuaca_ui.json`, de `humahuaca_rules.json` (`texts`, `outcome`, `campaign`, `epilogue`) y de `humahuaca_level.json`, y de los rótulos del menú en `scripts/main.gd`. (3) Las teclas de `key_table` contra `docs/CONTROLES.md` y `docs/humahuaca/CONTROLES.md`. (4) `tests/test_hx_data.gd` suma la comprobación C03 sobre `humahuaca_visual.json` (misma lista negra y patrón de snake_case que el escáner, con dos mutaciones de sanidad).

## Corregido en esta rama

| Archivo | Dónde | Antes → después | Motivo |
|---|---|---|---|
| `data/humahuaca_ui.json` | `texts.objective.by_phase.aproximacion[0]` y `[1]`, `texts.help.lines[2]` | «dá la señal» → «da la señal» (×3) | «da» es monosílabo y no lleva tilde, tampoco en el imperativo del voseo (Ortografía de la RAE, 2010); el resto de los imperativos del nivel («tomá», «cargá», «salí») están bien |
| `data/history.json` | `scenarios.humahuaca.facts`, «Lo que contaron los realistas» | «Entre el 9 y el 16 de marzo una columna realista recuperó…» con fuente «Camba, Diario, oficio de La Serna» → «Lo que pasó después lo cuentan las fuentes realistas: según el Diario del Estado Mayor realista y las Memorias de García Camba, … «por falta de acémilas» (mulas de carga)»; `kind` cita S49 y S50 y dice que el juego no atribuye el relato al oficio de La Serna | H03 (ver `docs/historia/MATRIZ_HISTORICA.md`, sección J) |

Lo demás de `humahuaca_ui.json` se leyó entero y no tiene jerga, inglés ni anacronismos: los nombres de las fases, los chips (golpe, carga, refuerzo), los avisos, la ayuda y el glosario están en castellano rioplatense y explican los términos propios del nivel (golpe, desvelo, ruido, oscuridad).

## Para la pista `reglas_historia` (`data/humahuaca_rules.json`)

1. **H03 (ALTA) · `epilogue.lines[4]`, la línea «9 al 16 de marzo».** Hoy dice «según La Serna recupera seis piezas…» con `source` «Oficio de La Serna, 11-IV-1817: versión realista.». Las fuentes leídas en el repo que cuentan la recuperación, el lugar (cerca de San Andrés) y «por falta de acémilas» son el Diario del Estado Mayor realista (S49) y las Memorias de Camba (S50). Reemplazo exacto (conserva el texto obligatorio «9 al 16 de marzo» del anexo C.2 y no usa «García Camba», que está en la lista B del QA):

   ```json
   {"fecha": "9 al 16 de marzo", "texto": "En la realidad: una columna realista entra en el pueblo vacío y, según las fuentes realistas, recupera seis piezas ocultas o enterradas cerca de San Andrés e inutiliza lo que no puede cargar «por falta de acémilas» (mulas de carga).", "tag": "discutido", "source": "Versión realista: Diario del Estado Mayor realista (S49) y Memorias de Camba (S50); no es el oficio de La Serna."}
   ```

   Nota: el banco de hechos de la investigación (`02_fuentes_primarias.md`, fuera de Git) dice que el oficio de La Serna solo afirma «se ha logrado quitarles los seis cañones». Eso no se cotejó en el repo, así que la línea no cita el oficio para nada.
2. **Ortografía · `texts.siguiente.signal` y `texts.alertas.amanece.largo`:** «Dá la señal» → «Da la señal» (mismo motivo que arriba).
3. **Claridad · `texts.etapas.routed` = «Quebrada» y `texts.errores.quebrada`.** En un nivel que transcurre en la Quebrada de Humahuaca, la etapa de una partida «Quebrada» (en la ficha y en el cartel) se lee como el lugar. Sugerencia: «Deshecha» y «Esa partida está deshecha y no puede obedecer.» (o «Rota», si el QA prefiere una sílaba menos). Ninguna prueba ni texto obligatorio depende de la palabra «Quebrada».
4. **Palabra de época · «por falta de acémilas»** (epílogo): es cita y va entre comillas, pero «acémilas» no se entiende al primer intento; agregar «(mulas de carga)» como en `history.json`.
5. **Baja · `variants.guardia.source`** («Incertidumbre del dossier convertida en variante…»): «dossier» es jerga interna; si esa cadena `source` llega a la leyenda o al botón «?», decir «del material del usuario».

## Para la pista `relieve_mapa` (`data/humahuaca_level.json`, `data/humahuaca_map.json`)

- **Baja · `lights[*].source`** («Luz progresiva del dossier; …»): mismo caso que el punto 5 de arriba. Los demás `source` del nivel (tapias, zanjas, calles, manzanas, caminos) están claros y en castellano.

## Para la pista `ui_feel` (`scripts/humahuaca/ui/**`, `data/humahuaca_ui.json` salvo los textos)

- **«Custodia %d»** (`texts.hud.custody`, en el cartel de cada ficha, `humahuaca_hud.gd`): el número sale de `custody` de la agrupación (la gente que dejó custodiando lo tomado) y no está en el glosario de F1 ni en `docs/humahuaca/CONTROLES.md`. Sugerencia: «Custodia %d (gente que dejó cuidando lo tomado)» en el cartel, o una línea más en `help.glossary`. No se cambió acá para no pisar la sección de interfaz que `ui_feel` tiene abierta (cámara, R2a).
- Lo que el agente de usabilidad no entendió («Desvelo», «Golpe», «Fatiga», «postura») ya está en el BACKLOG (B-052); el glosario de F1 explica los tres primeros.

## Para la pista `visual` (`data/humahuaca_visual.json`)

- **C03 cerrado.** Las dos cadenas en snake_case (`royalist_1817` en `units.realista_1817.silueta` y `juego_noche` en `canonical_views[6].source`) ya estaban reemplazadas en `9d733b4` (pase 3 de R1): «camisa y gorra retintadas del modelo del realista de 1817…» y «la misma cámara que la de juego de noche (rumbo 325°, A-11)». Escáner P5-d: 0 aciertos. Desde esta rama, `tests/test_hx_data.gd` lo vigila (comprobación «C03 ninguna cadena visible de humahuaca_visual.json…»). BACKLOG B-051 pasa a cerrado.

## Para el integrador (`scripts/main.gd`)

- Los rótulos del menú («II · HUMAHUACA: EL DEPÓSITO DE LA RETAGUARDIA», «III · SOSTENER EL NORTE») van en mayúsculas como el del escenario I: coherentes entre sí; el escáner del QA no los mira (no son JSON ni `scripts/humahuaca/ui`). Nada que corregir.

## Para el Jefe de QA (`docs/QA_NIVEL2.md`)

- Anexo C.3, fila «línea del epílogo «9 al 16 de marzo»»: la razón dice «versión realista (La Serna) ◆». El techo (`discutido`) no cambia; solo la razón debería decir «versión realista (Diario y Camba) ◆». Es una enmienda de texto, sin umbral: se deja al QA.
