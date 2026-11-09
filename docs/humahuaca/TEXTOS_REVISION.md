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

## visual/r1 F5 (terreno): documentos viejos sobre Copernicus que tienen otro dueño (9-nov-2026)

La integración de F5 (horizonte real, texturas, relieve del Norte) los encontró desactualizados; no se editan acá porque son de otra pista (CONTRATO 1.2). Textos literales en `assets/terrain/terrain_relief_manifest.json` (`disclaimer_glo30`, `disclaimer_glo90`) y en `meta.notice`/`meta.disclaimer` de cada JSON de relieve; cotejo del PDF oficial en `docs/humahuaca/F5_TERRENO.md` 4.

- **Para `relieve_mapa` · `docs/humahuaca/CREDITOS_RELIEVE.md`, l. 17:** la frase de no responsabilidad («…do not assume any responsibility or liability with respect to the use made of the Product», marcada «pendiente de cotejo») no es la del Art. 6 (c) de la licencia GLO-30-F. Reemplazar por la literal: «The organisations in charge of the Copernicus programme by law or by delegation do not incur any liability for any use of the Copernicus WorldDEM-30» (y, para el horizonte lejano y el Norte, la misma con «Copernicus WorldDEM™-90»), y quitar «pendiente de cotejo».
- **Para compuertas y documentos · `docs/CREDITOS.md`, l. 40 (sección del nivel II):** dice «Copernicus DEM GLO-30 (preparado, no en uso)» y «el juego no la usa», pero `data/humahuaca_height.json` es `copernicus_glo30` desde el 2-nov y, desde F5, también lo son el horizonte (GLO-30, ±9 km) y la silueta lejana (GLO-90, ±30 km) de Humahuaca y el relieve del Norte (GLO-90). Pasar el párrafo a «en uso» con el aviso del Art. 6 (b) y la frase del 6 (c) literales. (Otros dos agentes de visual/r1 agregaban secciones a ese archivo en paralelo: no se lo tocó para no pisarlos.)
- **Para compuertas y documentos · `docs/humahuaca/BACKLOG.md`, fila B-028:** sigue «abierto» con «La lámina sigue (A-02)». El juego ya usa Copernicus (meta.source = `copernicus_glo30`; RELIEVE_COPERNICUS.md) y F5 lo extiende a la vista. Lo que queda abierto, si queda, es solo la enmienda de R05 del QA; sugerencia: estado «cerrado en la vista; R05 pendiente del QA».
- **Hecho en F5 (integrador, a pedido del dueño del proyecto):** `export_presets.cfg` suma `assets/terrain/*.json` al `include_filter` de los dos perfiles; sin eso el EXE no lleva los JSON de relieve y Humahuaca y el Norte vuelven, sin error, al relieve procedural.
