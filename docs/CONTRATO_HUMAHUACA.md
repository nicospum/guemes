# Contrato entre pistas: nivel 2 «Humahuaca»

Versión del contrato: **1.1** (`contract: 1`; 1 de noviembre de 2026; la 1.1 es la revisión final **antes de escribir código**, así que no hay nada que migrar: los JSON siguen llevando `"contract": 1`). Complementa `docs/DISENO_HUMAHUACA.md` (qué se juega y por qué), los seis JSON de `data/humahuaca_*.json` (todos los números) y `docs/QA_NIVEL2.md` (qué es «presentable» y cómo se verifica). Cuatro pistas trabajan en paralelo y **cada una toca solo sus archivos**; dos roles de integración —el **integrador** (único autor de `scripts/main.gd`, del vocabulario compartido y de los merges) y **compuertas y documentos** (pruebas de datos y de humo, `qa_gate.sh`, ejemplos de forma, recorrido del QA, arnés del agente-jugador, trazabilidad y evidencia)— cierran el circuito. El **plan de rondas con lo que entrega cada pista** está en la sección 8.

> **Estilo y alcance.** Es el contrato de `docs/CONTRATO_JUSTINA.md` pero **más corto y verificable**: un solo documento vigente (sin apéndices «ronda N»), firmas cerradas, cada exigencia con su prueba. Los cambios entran como **addenda numeradas** (`docs/humahuaca/ADDENDA.md`) que el **integrador aplica al texto vigente** y que suben la revisión (1.1, 1.2…). **Nadie edita este contrato ni los JSON ajenos**: se pide por escrito al integrador con id, firma, motivo y prueba de aceptación.
>
> **Base:** `main` en `5ebbd28` (constante `BASE` de `tools/qa_gate.sh` y de la rúbrica del QA: **un hash, no una etiqueta**, para no tocar `git tag --list`). Los números de línea de `main.gd` salen de `investigacion-nivel2/preparacion/03_arquitectura_actual.md` (**[03]**) sobre ese commit; se corren si alguien toca `main.gd` antes del commit de andamiaje.

## 0. Convenciones

- **Coordenadas del mundo** = metros. `+x` este, `+z` **sur**, **norte = `−z`**, origen en la **esquina noroeste de la ventana de 900 × 650 m** (`x ∈ [0, 900]`, `z ∈ [0, 650]`). En 3D, `Vector3(x, altura, z)`; la altura `y` son **metros sobre el cero local** (`datum_asl_m = 2940,0`). 1 unidad de Godot = 1 m. Un punto de ruta es `{"x","z"}`; un parámetro de punto es `Vector2(x, z)`.
- **Lámina ↔ juego** (la única conversión permitida; vive en `HumahuacaTerrain`): `x = E + 450`, `z = 325 − N` (E = metros al este y N = metros al norte del ancla de la iglesia; ancla = (450, 325)). Nadie escribe estas constantes a mano.
- **Escenario:** id interno **`"humahuaca"`** (nunca se pasa a `GameRules`); nombre visible «Humahuaca: el depósito de la retaguardia» (nivel II); «Sostener el norte» pasa a ser el nivel III (sus reglas **no cambian**; **no se lo presenta como continuación del II**: es la campaña entera de 1816–1817 vista desde Salta y ya incluye la operación de Arias en Humahuaca).
- **Etiquetas de fuente** (`tag`): `"documentado"`, `"razonado"`, `"discutido"`, `"diseno"`, `"sin_datos"`. Fuerza de evidencia (de mayor a menor): `documentado > razonado > discutido > sin_datos > diseno`. Una entidad mixta lleva `tag` = su parte más débil y `tag_parts` (`{parte: tag}`, ≥ 2 entradas). Glifos y colores salen de `humahuaca_ui.json.source_tags`.
- **Nadie copia cifras de un JSON, y cada número de juego tiene una sola fuente: el JSON de reglas.** Se leen con `rules.map_data()` o con la API de la clase dueña. Los textos visibles salen de los JSON, no del código. Los otros archivos citan los números **por id** (por ejemplo, un puesto de ataque no repite «60–120 m»: una prueba la verifica contra `rules.combat.attack_range_m`). Las propiedades físicas de las superficies (`surfaces.mud`, `slope_penalty`) viven en el mapa porque las calcula el terreno, y no se repiten en las reglas.
- **Reglas es la fuente de verdad:** todo lo que devuelve `HumahuacaRules` es copia o JSON-serializable; la vista y la interfaz **no mutan** `rules.state`. Determinismo total: RNG propio (`rng_state`, congruencial como el de la Justina), **nunca** `randf()`/`randi()`/`Time` en las reglas.
- **Errores de órdenes:** `{"ok": false, "reason": String}` en español, con la causa concreta («Falta llegar a 150 m del frente»), sin jerga.
- **Código nuevo:** GDScript con **tabs** y fin de línea **LF**; sin `class_name` (se usa `const X = preload("res://…")`: `class_name` exige el caché global de clases y falla en worktrees nuevos); cada archivo ≤ ~1 500 líneas (se parte por responsabilidad dentro de la carpeta de la pista). **Regla de dependencia: solo hacia abajo** (UI → vista → reglas → terreno): una capa nunca hace `preload` de una superior; las referencias hacia arriba van **por parámetro, por señal o con `load()` diferido**. `tests/test_hx_data.gd` (V19) arma el grafo de `preload`/`load` de `scripts/humahuaca/` y falla ante una arista hacia arriba o un ciclo (los ciclos de `preload` entre clases grandes fallan al parsear). Los ganchos en `main.gd` usan **un espacio** de sangría (es el estilo de ese archivo). No se renormalizan fines de línea de archivos existentes (siete están en CRLF dentro del índice).
- **Texto al jugador:** español rioplatense (voseo), sin la lista negra de jerga de `humahuaca_ui.json`, y con la etiqueta honesta. Nada inventado se presenta como documentado.
- **Pruebas:** escriben en `user://`: **siempre** `export APPDATA="$TEMP/ap_iso_<pista>"` antes de correrlas (ver sección 5).

## 1. Arquitectura elegida, archivos y propiedad

### 1.1 Decisión (opción A) y por qué

**Clases nuevas por capa en `scripts/humahuaca/`, un JSON por dueño en `data/`, y un controlador `Node` hijo de `main` que `main.gd` crea y libera con ≈ 20 líneas insertadas y 4 textos modificados (ninguna lógica borrada).** Validado por el analista de arquitectura sobre `5ebbd28` con una prueba de concepto descartable ([03] §4.7): `test_integration` 283/283, el menú con tres botones entra a 1280 × 720 (último elemento en y = 856 de 900), y el flujo menú → Humahuaca → Esc → menú → Justina pasó 15/15.

| Criterio | **A. Clases nuevas + controlador (elegida)** | B. Generalizar el motor de la Justina | C1. Escena propia | C3. Heredar `WorldView` |
|---|---|---|---|---|
| Líneas de Justina/Norte tocadas | **0** en `game_rules`, `world_view`, `campaign`, `justina_map.json`; +20 en `main.gd` | miles (> 3 000 de las 4 228 líneas de `GameRules`) | 1 botón | 0, pero hereda 2 871 líneas |
| Riesgo de regresión | bajo (283/283 medido) | **alto**: 871 comprobaciones llaman internos | bajo | medio |
| 4 pistas sin conflicto | **sí**, con archivos propios | **no** (los mismos 3 archivos) | sí | parcial |
| Se prueba sin ventana | sí (`SceneTree`) | sí | no entra en `test_integration` | sí |
| Reversible | **sí** (quitar H1–H9) | no | sí | difícil |

Razones del código: `main.rules` es una instancia `Variant` y `main.world_script` una variable (las pruebas ya las cambian); los únicos puntos que atan por nombre son `GameRules.new_game` (`game_rules.gd:229-230` convierte **en silencio** cualquier escenario desconocido en «justine») y `validate_snapshot` (`:3853, 3865, 3886`), y ambos se esquivan sin tocarlos; con `mode != "play"` quedan inertes `_process` (708) y `_unhandled_input` (786), de modo que un `Node` hijo con su propio `_process` convive sin interferir. **Plan B** si los ganchos generan fricción: escena propia (C1); los archivos del nivel no cambian, solo quién los instancia.

### 1.2 Archivos nuevos y dueño (propiedad **exclusiva**)

La propiedad es **por carpeta**: cada pista puede crear archivos nuevos dentro de las suyas sin tocar el contrato.

| Pista o rol | Es dueño, en exclusiva, de |
|---|---|
| **`relieve_mapa`** | `scripts/humahuaca/terrain/**` (clase `humahuaca_terrain.gd`, `vocab_terrain.gd` y auxiliares) · `scripts/humahuaca/stubs/stub_terrain.gd` · `data/humahuaca_map.json` · `data/humahuaca_height.json` · `tools/build_humahuaca_terrain.py` · `tests/test_hx_terrain.gd` · `docs/humahuaca/{RELIEVE,CREDITOS_RELIEVE}.md` |
| **`reglas_historia`** | `scripts/humahuaca/rules/**` (`humahuaca_rules.gd`, `humahuaca_progress.gd`, `humahuaca_data.gd`, **`humahuaca_policies.gd`** —la única biblioteca de políticas—, `vocab_rules.gd` y auxiliares) · `scripts/humahuaca/stubs/{stub_rules,stub_progress}.gd` · `data/humahuaca_rules.json` · **`data/humahuaca_level.json`** (rasgos, accesos, zonas, escondites y luces: el diseño de nivel vive con quien calibra el balance) · `data/history.json` (**solo agrega** `scenarios.humahuaca` y fuentes desde **S46**; no edita nada existente) · `tests/test_hx_rules.gd` · `tools/humahuaca_playthrough.gd` · `docs/humahuaca/{REGLAS,HISTORIA,PROCEDENCIA}.md` · **agrega al final** de `docs/historia/MATRIZ_HISTORICA.md` y `FUENTES.md` |
| **`visual`** | `scripts/humahuaca/view/**` (`humahuaca_view.gd`, `humahuaca_gfx.gd`, `humahuaca_buildings.gd`, `humahuaca_units.gd`, `humahuaca_fx.gd`, `humahuaca_gen.gd` —el generador procedural del templo y de los arquetipos—, `vocab_view.gd` y auxiliares) · `scripts/humahuaca/stubs/stub_view.gd` · `shaders/humahuaca_*.gdshader` y `shaders/humahuaca_noise.gdshaderinc` · `assets/models/humahuaca/**` · `assets/audio/humahuaca/**` · `data/humahuaca_visual.json` · `tools/vis_humahuaca.gd` (+ `.sh`) · `tools/generate_audio_humahuaca.py` · `tests/test_hx_view.gd` · `docs/humahuaca/{VISUAL,CREDITOS_VISUAL}.md` · **agrega al final** de `docs/ASSETS.md` |
| **`ui_feel`** | `scripts/humahuaca/ui/**` (`humahuaca_ui.gd`, `humahuaca_hud.gd`, `humahuaca_overlay.gd`, `humahuaca_dialogs.gd`, `humahuaca_ui_kit.gd`, `humahuaca_camera.gd`, `vocab_ui.gd` y auxiliares) · `data/humahuaca_ui.json` · `tools/ui_qa_humahuaca.gd` · `tests/test_hx_flow.gd` · `docs/humahuaca/CONTROLES.md` |
| **Integrador** (merges y `main.gd`) | `scripts/main.gd` (ganchos H1–H9) · `scripts/humahuaca/humahuaca_vocab.gd` (solo lo compartido entre capas) · `scripts/humahuaca/stubs/stub_ui.gd` (la cáscara del controlador) · `tools/run_qa.py`, `tools/benchmark.py` (una línea cada una) · `docs/CONTRATO_HUMAHUACA.md`, `docs/DISENO_HUMAHUACA.md` (con el arquitecto) · `docs/humahuaca/ADDENDA.md` · `README.md`, `CLAUDE.md`, `project.godot` (**solo** `config/description` y `config/version`: nunca ajustes de render ni `shader_globals`), `VERSION.json`, `docs/CONTROLES.md`, `.gitignore`, `.gitattributes` (y `export_presets.cfg` solo si hiciera falta) |
| **Compuertas y documentos** (puede ser el mismo agente que el integrador, con la misma propiedad de archivos) | `tests/test_hx_data.gd`, `tests/test_hx_smoke.gd`, `tests/hx_fixtures.gd` · `tools/qa_gate.sh`, `tools/hx_qa_tour.gd`, `tools/hx_agent_play.gd` (el arnés del agente-jugador) · `docs/humahuaca/{BACKLOG,TRAZA,PLAYTEST}.md` y `docs/humahuaca/forma/*.json` (los ejemplos de forma) · `docs/CREDITOS.md` (**único escritor**, en **[final]**: concatena `CREDITOS_RELIEVE.md`, `CREDITOS_VISUAL.md` y los créditos de audio) · `evidence/humahuaca/**` (salvo `<ronda>/qa/**`) |
| **Control de calidad** | `docs/QA_NIVEL2.md` (solo por enmiendas «QA enmienda N:») · `evidence/humahuaca/<ronda>/qa/**` |

### 1.3 Archivos **protegidos** (nadie del nivel los toca)

`scripts/game_rules.gd`, `scripts/world_view.gd`, `scripts/campaign.gd`, `scripts/audio_manager.gd`, `scripts/jev_client.gd`, `data/justina_map.json`, `shaders/justina_*`, `shaders/terrain_justina_r4.gdshader`, `shaders/water_rio_plata.gdshader`, `assets/*.gdshader`, los `assets/models/*.glb` existentes, `tools/create_models.py`, `tests/test_rules.gd`, `tools/justina_playthrough.gd`, `tools/vis_shots.gd`, `tools/vis_r5.gd`, `tools/bench_gpu.gd`. La **compuerta de protegidos** (`tools/qa_gate.sh`) corre `git diff --quiet 5ebbd28 -- <lista>` (contra el **hash fijo** `BASE`, no contra `main`: `main` avanza con cada merge y un cambio colado se volvería la nueva referencia) y falla si algo cambió. **Tampoco se tocan** `project.godot` (salvo `config/description` y `config/version`) ni `shader_globals`: el aspecto del nivel vive en el `Environment` de su propia escena, porque los ajustes globales de render cambiarían también a la Justina y al Norte. Los shaders del nivel **no** incluyen `justina_noise.gdshaderinc`: se **copia** a `humahuaca_noise.gdshaderinc` con comentario de procedencia (aislamiento antes que no repetir código: si alguien arregla el ruido de la Justina no debe cambiar silenciosamente el nivel 2).

### 1.4 Zonas de archivos existentes que **sí** se tocan (solo ganchos; el resto es intocable)

| Archivo | Quién | Cuándo | Zona exacta (según [03]) |
|---|---|---|---|
| `scripts/main.gd` | **solo el integrador** | T0 (= R0; un commit), después **congelado**; un gancho nuevo se pide por escrito y entra en un commit propio `hook-N` | H1: `var hx: Node` junto a `rules`/`world` (l. 15–16). H2: `_menu()` (l. 389–427): primera línea `_stop_humahuaca()`; texto «Dos momentos» → «Tres momentos» (l. 405); botón del Norte «II» → «III» manteniendo la subcadena `SOSTENER EL NORTE` y el subtítulo bloqueado «Ganá la Justina para abrirlo» (las pruebas lo buscan: `test_integration.gd:544`, `ui_qa.gd:494`); su subtítulo habilitado pasa a «La campaña entera, 1816–1817, vista desde Salta» (no lo busca ninguna prueba); **botón de Humahuaca** insertado **entre** l. 411 (`var unlocked`) y l. 412 para que el orden sea I, II, III, **siempre habilitado** (sin `disabled`) y con la nota «Recomendado tras la Justina» mientras `not unlocked`, y sin las subcadenas «EL RÍO OFRECE», «SOSTENER EL NORTE» ni «Ganá la Justina para abrirlo». H2e: `title_label.text` del HUD del Norte «III» (l. 629). H3: `_start_game` (l. 432), **primera línea** `if scenario_name=="humahuaca":_start_humahuaca();return`. H4: después de l. 454, `_start_humahuaca(opts)` (con carga con respaldo: `_hx_make()`), `_stop_humahuaca()` y `_on_hx_exited(to)`. H5: `_load_game` (l. 888–903): rama `humahuaca` → `_start_humahuaca({"load":true})`. H6: `_history_dialog` (l. 967): `["justine","humahuaca","norte"]`. H7: `_ready` (l. 250–265), `_qa_run` (l. 1087–1128) y `_benchmark_run` (l. 1148–1172): aceptar `humahuaca` y delegar en `hx.qa_run()` / `hx.benchmark_prepare()`. H8: `_process`, `_input`, `_unhandled_input`: **sin cambios** (con `mode="hx"` quedan inertes). H9: `_return_menu` (l. 905): `_stop_humahuaca()` si `mode=="hx"` |
| `scripts/campaign.gd` | **nadie** (protegido) | — | Solo si se aprueba D1b: el texto de la l. 270 (integrador, [final]) |
| `scripts/game_rules.gd` | **nadie** | — | Ninguna. `HumahuacaRules` rechaza cualquier otro nombre y `main` nunca le pasa `"humahuaca"` |
| `tests/test_integration.gd` (CRLF) | integrador | T0 | Solo l. 15–19: sumar `humahuaca_progress.json` y `humahuaca_checkpoint.json` a la limpieza de archivos de perfil (hermeticidad). Si se aprueba D1b: l. 463, 465, 473, 539–551 (integrador, [final]) |
| `tools/ui_qa.gd` | integrador | T0 | Solo l. 38–40: ídem hermeticidad. Si D1b: l. 311, 489–503, 533 [final] |
| `data/history.json` | `reglas_historia` | T0: el integrador deja el **esqueleto** `scenarios.humahuaca` (título, fecha, lugar) para que `_history_dialog` no falle; desde ahí, un solo dueño | Solo **agregar**; el *fact* «Humahuaca: Arias al mando» del Norte **no se edita** (`test_rules.gd:3547-3561` fija sus textos) |
| `tools/run_qa.py`, `tools/benchmark.py` | integrador | T0 | `run_qa.py:3` (`choices` suma `"humahuaca"`); `benchmark.py:14` sin cambio obligatorio |
| `tools/package_release.py`, `tools/test_windows_wine.py` | integrador | **[final]** | `package_release.py:53,70,131` exige evidencia de Wine de **exactamente** `{justine, norte}`: al armar la entrega pasa a `{justine, humahuaca, norte}` |

**Ninguna de las cuatro pistas toca estas zonas** (ni `main.gd`, ni `campaign.gd`, ni `game_rules.gd`, ni las pruebas existentes): si `ui_feel` necesita, por ejemplo, un texto nuevo en el menú o un flag, o si `visual` necesita un atributo de `main`, lo pide por escrito al integrador y entra en un commit propio `hook-N`; mientras tanto trabajan contra el controlador y la API de la sección 3. Nadie, salvo las filas de arriba, escribe en estos archivos; cualquier otro edit a un existente es una **violación de contrato** y la compuerta lo detecta.

### 1.5 Carpetas y archivos de datos que el nivel crea

```
scripts/humahuaca/{terrain,rules,view,ui,stubs}/        + humahuaca_vocab.gd (integrador: solo lo compartido) y un vocab_<capa>.gd por dueño
data/humahuaca_{map,height,level,rules,visual,ui}.json  (solo .json: export_presets.cfg incluye data/*.json)
shaders/humahuaca_*.gdshader, humahuaca_noise.gdshaderinc
assets/models/humahuaca/, assets/audio/humahuaca/        (solo si hace falta)
tests/test_hx_{data,terrain,rules,view,flow,smoke}.gd, tests/hx_fixtures.gd
tools/{build_humahuaca_terrain.py, humahuaca_playthrough.gd, vis_humahuaca.gd, ui_qa_humahuaca.gd, hx_qa_tour.gd, hx_agent_play.gd, qa_gate.sh, generate_audio_humahuaca.py}
docs/humahuaca/{RELIEVE,CREDITOS_RELIEVE,REGLAS,HISTORIA,PROCEDENCIA,VISUAL,CREDITOS_VISUAL,CONTROLES,ADDENDA,BACKLOG,TRAZA,PLAYTEST}.md
docs/humahuaca/forma/{hud_state,render_state,campaign_report,plan_route,qa_state}.json      (ejemplos de forma, sección 3.6)
evidence/humahuaca/<ronda>/<pista>/                      (sección 6)
user://humahuaca_progress.json, user://humahuaca_checkpoint.json, user://save_humahuaca.json   (con prefijo qa_ en modo QA)
user://hx-balance-results.json, user://hx-route-atlas.json                                       (informes de las pruebas; con APPDATA aislado)
```

**Exportación:** todo lo que el juego lea en ejecución debe ser `data/*.json` o un recurso importado en `assets/`/`shaders/`; un `.bin`, `.exr` o `.tif` en `data/` **no se exporta** (`export_presets.cfg:9-10`). La tesela Copernicus, si llega, vive **fuera del repo** (`investigacion-nivel2/descargas/`).

---

## 2. Datos: esquemas, propiedad de claves y validación

**Principio (lección de la Justina):** el JSON es el **único origen de cifras**, pero con **un archivo por dueño**, sin notas de producción dentro (la procedencia larga va a `docs/humahuaca/PROCEDENCIA.md`: en `justina_map.json` el 15 % de los bytes no lo lee nadie) y con la estética **en datos**, no en el código (en la Justina, cambiar un color obligaba a abrir una ronda de «visual»). **Seis archivos**, todos con `"contract": 1` y UTF-8 sin BOM, fin de línea LF, sin comas finales ni `NaN`. El diseño de nivel (tapias, zanjas, accesos, zonas, escondites, luces) está **separado del relieve** y es de quien calibra el balance (`reglas_historia`): en el nivel 1 esas decisiones estaban repartidas y duplicaban números.

| Archivo | Dueño | Lo leen | Tope de tamaño |
|---|---|---|---|
| `data/humahuaca_height.json` | relieve_mapa | terreno (solo) | 450 KB |
| `data/humahuaca_map.json` | relieve_mapa | terreno; reglas, vista y UI **a través** de `HumahuacaTerrain`/`rules.map_data()` | 150 KB |
| `data/humahuaca_level.json` | reglas_historia | terreno (rasteriza muros, zanjas y superficies de los rasgos), reglas, vista (props) y UI, siempre **a través** de `HumahuacaTerrain`/`rules.map_data()` | 150 KB |
| `data/humahuaca_rules.json` | reglas_historia | reglas; vista y UI vía `rules.map_data()` y la API | 300 KB |
| `data/humahuaca_visual.json` | visual | vista; UI (colores, vistas canónicas) | 120 KB |
| `data/humahuaca_ui.json` | ui_feel | UI; pruebas | 120 KB |

### 2.1 `data/humahuaca_height.json` (la grilla de relieve)

| Clave | Tipo | Significado |
|---|---|---|
| `contract`, `map_version` | int | 1 y la versión del mapa (se suma 1 si cambian el ancla o las dimensiones) |
| `meta.source` | String | `lamina03_reconstruida` · `copernicus_glo30` · `opentopodata_srtm30` · `paquete_usuario` (el plan B, `lamina03_reconstruida`, es el de R1 si no hay permiso) |
| `meta.source_detail` | String | una línea: archivo y MD5 de la tesela, o «475 nodos de la lámina 03» |
| `meta.datum_asl_m` | float | **2940,0** (cero local; debe igualar `map.datum_asl_m`) |
| `meta.unit`, `meta.order` | String | `"dm"` (decímetros enteros sobre el datum) y `"filas norte->sur, columnas oeste->este; índice = fila * nx + columna"` |
| `meta.tag`, `meta.uncertainty_m` | String, float | `razonado`; ±10 m (plan B) o ±5 m (Copernicus). Es **dato actual, no restitución del suelo de 1817** |
| `meta.modified`, `meta.smooth_m`, `meta.credits_ref` | bool, float, String | `true` (remuestreo, suavizado y recorte); radio del suavizado en metros (30 con lámina, 30–45 con Copernicus, que es un modelo de superficie con techos y árboles); y `"docs/humahuaca/CREDITOS_RELIEVE.md"` |
| `window` | obj | **Ventana de juego**: `nx = 91`, `nz = 66`, `cell_m = 10.0`, `origin_x = 0.0`, `origin_z = 0.0`, `h` = 6 006 enteros. El nodo `(i, j)` está en `x = origin_x + i·cell_m`, `z = origin_z + j·cell_m` (`i` = columna oeste→este, `j` = fila norte→sur) |
| `context` | obj | **Contexto**: el dominio de la lámina 03 centrado en el ancla: `nx = 121`, `nz = 91`, `cell_m = 30.0`, `origin_x = −1350.0`, `origin_z = −1025.0`, `h` = 11 011 enteros |
| `stats` | obj | mínimos y máximos en dm de cada grilla (para el test) |

`value_dm = round((cota_snm − 2940) · 10)`. Los nodos del borde de `window` coinciden con `context` interpolado a ≤ 1 dm (lo fuerza `tools/build_humahuaca_terrain.py` y lo verifica el test). **Cambiar de plan de fuente no cambia este esquema**: `build_humahuaca_terrain.py --source lamina03|copernicus|opentopodata` regenera el archivo.

**Cómo se arma la altura (única implementación, `HumahuacaTerrain`):** (1) DEM de ventana a 10 m → **«relieve de juego»**: se suaviza a 30 m (`meta.smooth_m`; con Copernicus se van los techos y árboles de hoy, con la lámina no cambia nada) y se interpola a la malla de juego de **4 m** (226 × 164 nodos) por Catmull-Rom al cargar; (2) se suman las **capas de diseño** de `map.relief.design_layers` (domo de la batería **como residuo** —su `delta_m` se calcula para que la prominencia final sobre el anillo de 120–150 m sea 12,0 m con cualquier fuente—, plataforma, **explanadas** de cuartel, posta y plaza a altura fija respecto del templo, barranca, terraza, banco de grava, quebraditas, cauce) y el **micro-relieve** de semilla fija (±0,5 m, onda ≥ 25 m); (3) fuera de la ventana, `context` por interpolación bilineal con mezcla continua en los 60 m exteriores; (4) más allá del contexto, el horizonte procedural lo resuelve la vista con los mismos vértices del borde. Las **superficies y los rasgos** (muros, zanjas, charcos) se rasterizan **una sola vez** a `PackedByteArray`; el horneado entero cuesta **< 300 ms** (se mide por etapas). Cuando llega una fuente nueva, una **prueba A/B** (`test_hx_terrain`) exige que la diferencia de cota entre objetivos cambie ≤ 1 m, la curva de 2 960 m ≤ 15 m en z = 0, 325 y 650, el signo del gradiente oeste → este se conserve y la prominencia de la batería siga en 12,0 ± 0,5 m.

### 2.2 `data/humahuaca_map.json` (el mapa: relieve, superficies, río e hitos)

Dueño de **cada** clave de este archivo: `relieve_mapa`. La columna «Consumen» dice quién la lee (siempre **a través** de `HumahuacaTerrain` o de `rules.map_data()`, no del archivo). Las claves de **diseño de nivel** (rasgos, accesos, zonas, escondites, luces) están en `humahuaca_level.json` (2.2b), de otro dueño.

| Clave | Tipo | Contenido | Consumen | Obligatoria desde |
|---|---|---|---|---|
| `contract`, `map_id` (`"humahuaca"`), `map_version` | int, String, int | identidad; un guardado con otro `map_version` se rechaza | todas las pistas, `test_hx_data`, el guardado (reglas) | R0 |
| `size_m` | `{x, z}` | `{900.0, 650.0}` | terreno, reglas (límites), vista (cámara), UI (minimapa) | R0 |
| `axes` | obj | `{x:"este", z:"sur", norte:"-z", origen:"esquina NO", unidad:"m"}` | terreno, pruebas | R0 |
| `anchor` | obj | `{id:"templo", x:450.0, z:325.0, lat:-23.2041, lon:-65.3492, uncertainty_m:15, tag:"razonado"}` | terreno, vista (rótulo), UI | R0 |
| `lamina` | obj | `{offset_x:450.0, offset_z:325.0, nota:"x = E + 450; z = 325 - N"}` | terreno (conversión), pruebas | R0 |
| `datum_asl_m` | float | 2940.0 | terreno, vista (rótulo de cota), pruebas | R0 |
| `relief` | obj | `height_file` (`"res://data/humahuaca_height.json"`), `exaggeration` (1.0; máx. 1.5, solo del componente DEM, `diseno`), `game_relief` (`{smooth_m: 30}`), `micro` (`{amp_m: 0.5, wavelength_m: 25, seed, tag: "diseno"}`), `design_layers[]` | terreno (horneado), `build_humahuaca_terrain.py`, pruebas | R1 |
| `surfaces` | obj | `classes` (los ids de `SURFACES` del vocabulario), `layers[]` (`{class, kind: "poly"/"line"/"rule", pts o rule, priority}`), `mud` (clase → 0..1: camino 0,9; suelo_seco 0,95; sedimento_humedo 0,75; irrigado 0,6; zanja 0,5), `slope_penalty` (`start_deg` 8, `per_deg` 0,03, `floor` 0,6) | terreno → reglas (velocidad), vista (shader), UI (rótulo del paraje) | R1 |
| `landmarks[]` | Array | ver abajo | reglas (objetivos y posiciones), vista (props y rótulos), UI (rótulos, minimapa, picking), pruebas | R1 |
| `river` | obj | `{id:"rio_grande", pts[] (≥ 14 puntos de la lámina 03), bed_width_m:{min,max}, depth_m:{min,max}, fords[], tag, tag_parts, source}` | terreno → reglas (vados, pólvora mojada), vista (cauce), UI (minimapa) | R1 |
| `provenance` | obj | cinco líneas máximo; el texto largo va a `docs/humahuaca/PROCEDENCIA.md`; **la traza del río (14 puntos medidos de la lámina 03, © OpenStreetMap contributors) declara su licencia ODbL** como subconjunto de base de datos derivada | UI (créditos), documentación | R1 |

**Capas de diseño** (`relief.design_layers[]`): `{id, kind: "dome"/"platform"/"pad"/"step"/"bank"/"gully"/"ditch"/"carve", center:{x,z}, radius_m o (length_m, width_m, yaw_deg), delta_m o height_rel_templo_m, falloff_m, prominence_target_m?, tag, source}`. Obligatorias en R1: `cerro_bateria` (`dome`, centro (305, 345), radio 75 m, `prominence_target_m: 12.0` sobre la **media del anillo de 120–150 m** —un **residuo**: el builder calcula `delta_m` descontando lo que el DEM ya sube ahí, así no hay «doble joroba» con Copernicus—, `diseno`), `plataforma_bateria` (28 × 18 m), `quebradita_norte` y `quebradita_sur` (−2,5 m), `cauce_rio` (talla el lecho de 25–40 m). Obligatorias en R2a: `explanada_cuartel` (+0,7 m respecto del templo), `explanada_posta` (−3,0 m), `explanada_plaza` (0 m) (`pad`: los umbrales de tiro y visión entre objetivos no dependen del DEM), `barranca_cauce` (`step`, 3–5 m, con 2 rampas en los vados), `terraza_nucleo` (`step`, 3 m, 2 escaleras), `banco_grava` (`bank`, +1,2 m, 30 × 15 m). `report()` rotula cada una como `diseno`.

**Hitos** (`landmarks[]`): `{id, name, short, type, x, z, yaw_deg, footprint, height_m, tag, tag_parts?, source, priority, variant}`. `type`: `hito`, `objetivo`, `edificio`, `torre`, `refugio`, `acceso`, `salida`, `entrada`, `partida`, `plaza`, `cerro`. `footprint`: `{w, d}` (rectángulo orientado por `yaw_deg`), `{r}` o `{poly:[{x,z}]}`. `priority` 1–6 (grupo del dossier). `variant`: `{}` o, por ejemplo, `{"torre_en":"casa_cura"}` (el hito existe solo si el mundo tiene esa variante). **Ids obligatorios** (los usan reglas, vista y UI por nombre): `templo`, `bateria`, `cuartel`, `posta`, `torre_casa_cura`, `torre_templo`, `plaza`, `polvorin`, `parque`, `corral_posta`, `quebradita_norte`, `quebradita_sur`, `vado_este`, `salida_este`, `entrada_sur`, `zona_partida`, `spawn_rodriguez`, `spawn_portal`, `spawn_arias`, `spawn_reconocedores`, `spawn_arreo`. Valores de partida en `DISENO_HUMAHUACA.md` (secciones 3, 5.1 y 11.4); **`spawn_reconocedores` = (230, 480)**, a ≈ 160 m de la batería, para que la primera revelación llegue antes de los 40 s. Los hitos son la **única fuente de coordenadas** de partidas, salida y entrada del refuerzo: el nivel los cita por id.

### 2.2b `data/humahuaca_level.json` (el diseño de nivel: rasgos, accesos, zonas, escondites y luces)

Dueño de **cada** clave: `reglas_historia`. Lo **leen** el terreno (para rasterizar muros, zanjas y superficies: `is_blocked`, `speed_factor_at`, `los`, `surface_at`, `nav_grid`), las reglas, la vista (props) y la UI, siempre a través de `HumahuacaTerrain`/`rules.map_data()`. **No repite coordenadas de hitos (cita su id) ni números de juego (los citan las reglas por id)**. El `stub_terrain` de R1.0 ya lee este archivo y respeta tapias, zanjas y zonas (con rasterizado simple), para que las reglas se calibren desde R1 contra muros y no contra un plano vacío.

| Clave | Tipo | Contenido | Obligatoria desde |
|---|---|---|---|
| `contract`, `map_version`, `level_version` | int | identidad; `map_version` debe igualar al de `humahuaca_map.json` | R0 |
| `features` | obj | `tapias[]`, `zanjas[]`, `acequias[]`, `barricadas[]`, `portillos[]`, `calles[]`, `manzanas[]`, `patios[]`, `parcelas[]`, `caminos[]` (incluye `camino_sur`, por donde llega el refuerzo), `camino_cubierto` y `gola_bateria` (`{lado: "este", tag: "diseno"}`) | R1 (≥ 12 tapias, ≥ 4 zanjas) |
| `access` | obj | `spawns` (id de agrupación → **id de hito** `spawn_*`), `zona_partida` (id de hito), `attack_posts` (id de frente → `[{x, z, layout}]`; la distancia al objetivo (60–120 m, con cobertura) la verifica una prueba contra `rules.combat.attack_range_m`), `exit` (`{vado: "vado_este", salida: "salida_este"}`), `south_entry` (`"entrada_sur"`), `patrol_routes[]` | R1 |
| `zones[]` | Array | `{id, kind: toma/polvorin/corral/parque/mirador, center o poly, objective}`; **sin radios**: el radio de toma, el ángulo muerto de la torre y el alcance del mirador son `rules.objectives.<id>.capture_radius_m`, `rules.tower.dead_angle_m` y `rules.combat.mirador_range_m` | R1 |
| `hide_spots[]` | Array | tres escondites `{id, x, z, near: true/false/medio}`; la prueba de «a salvo» (a < 150 m del camino sur o de la posta) se calcula en las reglas con `caminos[]` | R2a |
| `lights[]` | Array | `{id, kind: brasero/ventana/candil/fogata, x, z, objective?, r_m}`; las reglas las devuelven en `render_state().lights` y habilitan `rules.stealth.light_reveal_m` | R1 (3 luces de objetivo), R2a (fogatas) |
| `layouts` | Array | `["A"]` hasta que `layout` sea una dimensión activa (entonces `["A", "B"]` y cada rasgo lleva `layout`) | R3 (candidata) |

**Rasgos lineales y de superficie** (`features`): cada elemento lleva `id`, `tag`, `layout` (`"A"`, `"B"` o `"AB"`) y: `tapias[]` `{pts[], height_m, thickness_m}`; `zanjas[]` `{pts[], depth_m, width_m}`; `portillos[]` `{tapia, at, width_m, state: "cerrado"/"abierto"}`; `barricadas[]` `{pts[]}`; `calles[]` `{pts[], width_m}`; `manzanas[]`, `patios[]` (`owner`), `parcelas[]` (`kind: "irrigada"`) con `poly[]`; `caminos[]` `{pts[], width_m}`; `camino_cubierto` `{pts[], width_m, wall_height_m}`. R1 exige ≥ 12 tapias, ≥ 4 zanjas y las 2 quebraditas (estas, en el mapa).

### 2.3 Los otros tres JSON: claves de primer nivel (cada dueño define el detalle; el contrato fija esto)

**`data/humahuaca_rules.json`** (dueño `reglas_historia`):

| Clave | Contenido (valores de partida en `DISENO_HUMAHUACA.md`) | La leen |
|---|---|---|
| `contract`, `map_version`, `rules_version` | identidad; `map_version` debe igualar al de `humahuaca_map.json` y `humahuaca_level.json` | todos |
| `time` | `alba_start_s` 270, `alba_full_s` 330, `day_full_s` 420, `dawn_discovery_s` 390, `deadline_s` 840, `surprise_s` 45, `checkpoint_positions_fallback_s` 210 | reglas, UI |
| `environment` | curva `time_of_day`/`rain`/`visibility_m`/`mud_dry_per_s` por tramo | reglas, vista |
| `groups` | por id de `GROUPS`: nombre, `tag`, `source`, hombres, `strength`, `armed`, `mounted`, ritmos, habilidades | reglas, UI |
| `objectives` | por id de `OBJECTIVES`: guarnición, cobertura, centinelas, torre, botín contenido, `capture_radius_m` (22 / 18 / 20 m: **única fuente**) | reglas |
| `enemy` | guarnición total, patrullas, mensajero, oficial de la posta, estados `guardado…tomado` | reglas |
| `combat` | sorpresa (`1 + 0,8 × (1 − alerta)`, `surprise_s`), fiabilidad de armas de chispa por lluvia, ventaja de altura, `attack_range_m` (150), `mirador_range_m` | reglas |
| `stealth` | ritmos y ruido, fórmula de detección, `dark_cost` (puntería, poder de asalto, alcance, demora de coordinación y su rampa 35 → 100 m), `dawn_drift` (`0,004 × visibilidad ÷ 60` por segundo), `light_reveal_m` (60) | reglas |
| `tower` | `volley_period_s` 7,5, `volleys` 12, `radius_m` 90, `dead_angle_m` 12, factores de daño (calle abierta ×2, tapia ×0,5, corriendo ×0,3), respuestas (a)–(d) | reglas, UI |
| `actions` | por id de acción: nombre visible, `tag`, `source`, costo, texto de costo, atajo sugerido, `round` (R1 o R2a) | reglas, UI |
| `loot`, `transport` | clases de `LOOT_KINDS` con cantidad, peso, puntos (suman **100** en R1 con 5 clases y en R2a con 9), capacidad, ritmo de carga; `treatments` (entregar ×1,0, destruir ×0,35, ocultar ×0,7 a salvo, tiempos y costos); `world_traits` (corral, plata, pólvora seca o húmeda) | reglas, UI |
| `reinforcement` | demoras por variante, efecto del mensajero, aviso, `smoke_advance_s` (20, 10 y tope 40), banda inicial del reloj | reglas |
| `variants` | dimensiones con valores, pesos y efectos; `active` (hoy `guardia`, `torre_en`, `refuerzo`; el resto, candidatas con su valor fijo); `counterweights` (la matriz de la sección 6 del diseño) | reglas, UI |
| `field_events` | por id: texto, opciones, ventana, `tag` (incluye las microescenas ●) | reglas, UI |
| `enemy_decisions` | los tres puntos de decisión del mando realista con su tabla local | reglas |
| `outcome` | victoria, `causes` (≥ 8, cada una con texto ≤ 140 caracteres y consejo), `medals`, puntaje | reglas, UI |
| `campaign` | ventaja de la experiencia por racha, ayudas, reglas del diario, puntos de control, opciones de reintento | progreso, UI |
| `play_targets` | metas de balance de la sección 10 del diseño (compuertas, umbrales, listas de semillas) | pruebas |
| `texts`, `epilogue` | briefing, objetivo en una línea, consejos, líneas del epílogo con su fecha y `tag`, la aclaración del tiempo comprimido | UI |

**`data/humahuaca_visual.json`** (dueño `visual`): `contract`, `palette` (**24 entradas** `{id, name, group, hex}` iguales a la lámina 06), `lights` (`noche_lluvia`, `alba`, `dia`), `rain`, `fog`, `materials`, `props` (por id de hito o rasgo: constructor, dimensiones y colores por **id de paleta**), `tokens` (por agrupación: forma de la ficha, alto mínimo en píxeles, glifo), `markers` (bandos: celeste con borde blanco, borgoña con borde negro, oro; **no son banderas**), `units` (variantes de figuras sin uniformar y los 3 arquetipos), `canonical_views` (las **7** del diseño, 11.3, cada una con `must_show`: la lista de 5 rasgos obligatorios escrita antes de pintar), `initial_frame`, `quality` (`baja/media/alta` con su presupuesto de cuadro), `fx`, `content_ring` (parcelas, sauces, ruinas de la capilla, rocas, huellas).

**`data/humahuaca_ui.json`** (dueño `ui_feel`): `contract`, `texts` (tarjetas, botones, avisos), `tutorial_steps` (6; entran en R3), `key_table` (tecla, acción, etiqueta), `jargon_blacklist` (lista **cerrada y explícita**: las entradas escritas enteramente en mayúsculas son **siglas sensibles a mayúsculas**, p. ej. `ETA`, `ZOC`, `LOS`, `DPS`, `HUD`, `FPS`; las demás son palabras que se buscan sin distinguir mayúsculas ni tildes, con límite de palabra), `source_tags` (por cada uno de los 5 ids: glifo, color, etiqueta, descripción corta), `camera` (`bounds_margin_m` 120, `min_distance_m` 40, `max_distance_m` 900, velocidades, límites de inclinación, `opening_s` 12–15), `minimap` (`default_size_px` [260, 188], `large_size_px` [520, 376], `refresh_s` 2, colores), `layout`, `hud_limits` (`max_controls` 5, `max_chars` 400), `toasts` (prioridades), `onboarding`.

### 2.4 Reglas de validación: `tests/test_hx_data.gd` (compuertas y documentos, ≥ 40 comprobaciones en R1 y ≥ 60 desde R2a, < 5 s, en la compuerta rápida)

Corre sin ventana: `godot --headless --path . --script tests/test_hx_data.gd`. Falla con la causa concreta y el archivo. Las reglas se **encienden por ronda** según la columna «Obligatoria desde»: R0 trae V1, V2, V3, V4, V5, V7, V8, V9, V17, V19 y V20; el resto, a medida que los archivos las hacen verificables.

1. **V1** Los seis archivos parsean; `contract == 1`; `map_version` igual en height, map, level y rules.
2. **V2** Claves obligatorias de cada archivo presentes con su tipo (las tablas 2.1–2.3), **según la ronda** (columna «Obligatoria desde»).
3. **V3** **Propiedad de claves:** ninguna clave aparece fuera del archivo de su dueño (por ejemplo `actions` no puede estar en `humahuaca_map.json`, ni `landmarks` en `humahuaca_level.json`, ni `features` en `humahuaca_map.json`).
4. **V4** Todo `tag` ∈ los cinco ids; cada hito, acción, clase de botín, evento de campo y línea de epílogo trae `tag` y `source` (≤ 120 caracteres); una entidad con `tag_parts` tiene `tag` = la parte más débil.
5. **V5** Ids únicos por arreglo y **toda referencia resuelve** (hitos citados por reglas, vista o UI; `access.spawns` cubre las 5 agrupaciones con ids de hito `spawn_*`; `attack_posts` cubre las 3 posiciones; `zones.objective` ∈ objetivos).
6. **V6** Geometría: hitos y rasgos dentro de `[0, 900] × [0, 650]` (salvo `outside: true`); los tres objetivos separados ≥ 80 m; las tapias no atraviesan un objetivo sin portillo.
7. **V7** Grilla: `len(h) == nx · nz`; `cell_m`, `origin_*` y `datum` como en 2.1; sin valores fuera de [−300, 3 000] dm; bordes de `window` vs `context` ≤ 1 dm; `meta.source` en la lista.
8. **V8** Tamaños bajo los topes de la tabla inicial; ningún archivo de `data/` que no sea `.json`.
9. **V9** `visual.palette` tiene **exactamente los 24 HEX** de la lámina 06 (el test los lleva como constante): `#B99A72 #776248 #8E8B81 #6D7653 #69794B #8C9B91 #C4AA82 #E4DDCA #59432E #745034 #B3A077 #4B4B47 #CEC2A7 #705741 #2E455A #9A443B #4F5E4C #E1D7BD #7FAAC4 #EFE8D7 #983F36 #B99A50 #383831 #843D40`; los colores de `props` y `tokens` citan ids de paleta, no HEX sueltos (salvo `markers`, marcados «interfaz»).
10. **V10** `ui.jargon_blacklist` no vacía y **con las siglas separadas de las palabras** (una entrada toda en mayúsculas se busca respetando mayúsculas; las demás, sin distinguir mayúsculas ni tildes, siempre con límite de palabra: así «los» no dispara «LOS»); **ninguna cadena visible** de `rules.texts`, `rules.field_events`, `rules.outcome`, `rules.actions`, `ui.texts`, `ui.tutorial_steps` contiene un término prohibido, **ni un identificador en snake_case, ni una cadena visible escrita entera en mayúsculas** (salvo siglas permitidas). El briefing completo y los 20 textos de acción pasan **sin excepciones**.
11. **V11** Límites de texto: causas de derrota ≤ 140 caracteres; página 1 del briefing ≤ 250; pistas ≤ 120.
12. **V12** Todo `res://` citado por los JSON existe; los `.glb` de `assets/models/humahuaca/` tienen su `.import` tras `--import`.
13. **V13** El vocabulario coincide: las claves de `rules.groups`, `rules.objectives`, `rules.actions`, `rules.loot`, `rules.variants` equivalen a la **unión** de los archivos de vocabulario (`humahuaca_vocab.gd` más los cuatro `vocab_<capa>.gd`); cada vocabulario es **solo-agregar** (quitar o renombrar un id exige un addendum).
14. **V14** `variants` y `landmarks[*].variant` usan solo valores legales; `layout` ∈ {A, B, AB}; `variants.active` ⊆ las seis dimensiones y las inactivas tienen un valor fijo.
15. **V15** `canonical_views` trae las **7** vistas y `initial_frame`; cada una con `target`, `distance`, `pitch_deg`, `yaw_deg`, `time_of_day`, `rain` y `must_show` (5 rasgos).
16. **V16** `alba_start_s < alba_full_s < day_full_s < deadline_s` y `alba_start_s < dawn_discovery_s`; `loot` suma **exactamente 100** puntos (5 clases en R1, 9 desde R2a); las clases ⊆ `LOOT_KINDS`.
17. **V17** `data/history.json`: existe `scenarios.humahuaca` con `title, date, place, context, notice, facts, reference_outcome`; las fuentes nuevas empiezan en **S46** y tienen ids únicos; el hecho «Humahuaca: Arias al mando» del Norte, sus 47 fuentes anteriores y `scenarios.justine/norte` quedan **byte a byte** como en `5ebbd28` (hash de su subárbol).
18. **V18** Créditos: si `meta.source` es `copernicus_glo30`, `docs/humahuaca/CREDITOS_RELIEVE.md` contiene el aviso «produced using Copernicus WorldDEM-30» y la frase de no responsabilidad; si la traza del río viene de la lámina 03, contiene «OpenStreetMap» y «ODbL» (y `map.provenance` declara la ODbL del subconjunto). En **[final]** el integrador concatena ese archivo en `docs/CREDITOS.md`.
19. **V19** **Grafo de dependencias:** se leen los `preload("res://scripts/humahuaca/…")` y los `load(…)` literales de `scripts/humahuaca/`; ninguna arista va hacia arriba (UI → vista → reglas → terreno) y no hay ciclos; además cada script se carga **solo** (`ResourceLoader.load` con caché ignorado) y parsea.
20. **V20** **Trazabilidad:** cada fila de `docs/humahuaca/TRAZA.md` (exigencia del contrato → prueba nombrada, p. ej. `test_hx_rules::_test_signal_sweep`) apunta a una función de prueba que existe; ninguna exigencia de las secciones 3 a 5 queda sin fila.
21. **V21** **Una sola fuente por número:** cada `attack_post` está a 60–120 m de su objetivo y a ≤ `rules.combat.attack_range_m`; ningún radio ni distancia de juego aparece en `map` ni en `level` (solo geometría); los hitos `spawn_*` están en la zona de partida.
22. **V22** `visual.canonical_views[*].time_of_day` y `initial_frame` son coherentes con `ui.camera`; `visual.quality` trae los tres perfiles con su presupuesto de cuadro.

---

## 3. API de las clases nuevas

Flujo entre capas (todo lo que cruza una flecha está en esta sección; nada más):

```
HumahuacaTerrain (relieve_mapa) ──altura, superficie, visión, rutas──▶ HumahuacaRules (reglas_historia)
HumahuacaRules.tick(dt) ──render_state()──▶ HumahuacaView (visual)      (la vista NO calcula daño, tiempo ni órdenes)
HumahuacaUI ──issue_order / give_signal / resolve_choice──▶ HumahuacaRules
HumahuacaUI ◀──hud_state / plan_route / action_availability / campaign_report── HumahuacaRules   (solo lectura)
HumahuacaUI ──pick_* / world_to_map / get_minimap_texture / initial_frame──▶ HumahuacaView
HumahuacaProgress ◀──▶ HumahuacaRules  (begin_attempt, record_result, checkpoints)
main.gd ──start / stop──▶ HumahuacaUI (controlador)  ◀── exited("menu"|"norte")
```

### 3.0 Vocabulario: lo compartido (integrador) y un archivo por dueño, solo-agregar

Todas las pistas **importan estas listas** en vez de repetir cadenas; `test_hx_data` (V13) compara los JSON con la **unión** de los cinco archivos. Cada archivo es **solo-agregar**: un dueño puede sumar ids cuando los necesita, sin pedir un addendum y sin esperar una ronda; **quitar o renombrar** un id sí exige addendum. El contenido inicial de cada archivo es el de esta sección, copiado literal en R1.0. Un archivo solo importa vocabularios **de su capa o de capas inferiores** (V19).

```gdscript
# scripts/humahuaca/humahuaca_vocab.gd   (integrador; lo que cruza TODAS las capas y casi no cambia)
const SCENARIO := "humahuaca"            # nunca se pasa a GameRules
const CONTRACT := 1
const MAP_PATH := "res://data/humahuaca_map.json"      # también HEIGHT_PATH, LEVEL_PATH, RULES_PATH, VISUAL_PATH, UI_PATH
const PROGRESS_PATH := "user://humahuaca_progress.json"
const CHECKPOINT_PATH := "user://humahuaca_checkpoint.json"
const GROUPS := ["rodriguez", "portal", "arias", "reconocedores", "arreo"]    # teclas 1..5
const COMBAT_GROUPS := ["rodriguez", "portal", "arias"]
const OBJECTIVES := ["bateria", "cuartel", "posta"]
const TAGS := ["documentado", "razonado", "discutido", "sin_datos", "diseno"]  # de más fuerte a más débil
const EXITS := ["menu", "norte"]
static func load_json(path: String) -> Dictionary    # parsea y devuelve {} (con push_error) si falta o no tiene "contract": 1
static func tag_min(tags: Array) -> String           # la etiqueta más débil de la lista

# scripts/humahuaca/terrain/vocab_terrain.gd   (relieve_mapa)
const SURFACES := ["suelo_seco", "sedimento_humedo", "piedra", "churqui", "irrigado", "agua", "camino", "patio", "zanja", "muro"]
const FEATURE_KINDS := ["tapia", "zanja", "acequia", "barricada", "portillo", "calle", "manzana", "patio", "parcela", "camino", "camino_cubierto"]
const LAYER_KINDS := ["dome", "platform", "pad", "step", "bank", "gully", "ditch", "carve"]
const LANDMARK_TYPES := ["hito", "objetivo", "edificio", "torre", "refugio", "acceso", "salida", "entrada", "partida", "plaza", "cerro"]

# scripts/humahuaca/rules/vocab_rules.gd   (reglas_historia)
const PHASES := ["briefing", "aproximacion", "ataque", "extraccion", "epilogo"]
const STATUS := ["playing", "victory", "defeat"]
const FRONT_STATES := ["guardado", "alertado", "en_alarma", "asaltado", "tomado"]
const PACES := ["sneak", "march", "run", "trot", "gallop"]
const STAGES := ["idle", "moving", "waiting_signal", "attacking", "holding", "loading", "retreating", "routed", "dismounting", "scouting", "exited"]
const ACTIONS := {
	"group": ["move", "position", "attack", "support", "hold", "secure_horses", "breach", "retreat", "cancel"],
	"scout": ["recon", "decoy", "watch", "cancel"],
	"train": ["bring", "load", "destroy", "hide", "leave", "drop", "cancel"],
	"global": ["give_signal", "retreat_all"]}
const ACTIONS_R1 := ["move", "position", "give_signal", "attack", "support", "recon", "load", "destroy", "leave", "hold", "cancel"]   # las 9 de R1 más hold (auto) y cancel
const LOOT_KINDS := ["polvora", "canones", "fusiles", "viveres", "ganado", "plata", "prisioneros", "bandera", "ornamentos"]
const LOOT_KINDS_R1 := ["polvora", "canones", "fusiles", "viveres", "plata"]       # R1: 5 clases con puntos provisionales que suman 100
const LOOT_STATES := ["en_sitio", "cargado", "destruido", "oculto", "abandonado", "entregado"]
const TREATMENTS := ["entregar", "destruir", "ocultar", "abandonar"]
const WORLD_TRAITS := {"corral": ["completo", "desbandado"], "plata": [true, false], "polvora": ["seca", "humeda"]}
const VARIANTS := {"guardia": ["descuidada", "atenta"], "torre_en": ["templo", "casa_cura"], "refugio": ["norte", "sur"],
	"lluvia": ["copiosa", "garua"], "refuerzo": ["temprano", "normal", "tardio"], "layout": ["A", "B"]}
const ACTIVE_DIMS := ["guardia", "torre_en", "refuerzo"]    # desde R2b; en R1 el mundo es fijo; el resto son candidatas con valor fijo
const APPROACHES := {"bateria": ["frontal", "gola", "distraccion"], "cuartel": ["calle", "patios", "piezas"], "posta": ["directa", "distraccion"]}
const EXTRACTIONS := ["cargar_todo", "destruir_todo", "ocultar", "ligera", "mixta"]
const CAUSES := ["amanecio", "descubiertos", "frente_roto", "sin_carga", "interceptados", "dispersos", "plazo", "retirada"]
const MEDALS := ["", "bronce", "plata", "oro"]
const RETRY := ["posiciones", "salida", "mismo_mundo", "mundo_nuevo"]
const EVENT_KINDS := ["objective", "briefing", "weather", "dawn", "noise", "detected", "alarm", "signal", "shot", "melee",
	"capture", "tower", "support", "horses", "recon", "decoy", "messenger", "reinforcement_warning", "reinforcement",
	"loot", "load", "destroy", "hide", "exit", "decision", "hint", "assist", "enemy_choice", "checkpoint",
	"victory", "defeat", "info", "warning"]

# scripts/humahuaca/view/vocab_view.gd   (visual)
const VIEW_IDS := ["acceso_so", "desde_bateria", "patio_posta", "panorama_alto", "grupos_en_accion", "juego_noche", "juego_alba"]
const QUALITY := ["baja", "media", "alta"]
const FX_KINDS := ["fogonazo", "humo", "impacto", "captura", "pisadas", "explosion", "senal"]
const LAYERS := ["paths", "visibility", "exposure", "labels", "landmarks", "diary", "enemy", "lights"]

# scripts/humahuaca/ui/vocab_ui.gd   (ui_feel)
const TUTORIAL_STEPS := ["reconocer", "puestos", "senal", "tres_a_la_vez", "cargar", "salir"]   # entran en R3
const TOAST_LEVELS := ["info", "aviso", "critica"]
```

### 3.1 `HumahuacaTerrain` (`scripts/humahuaca/terrain/humahuaca_terrain.gd`, `RefCounted`; dueña: `relieve_mapa`)

**Una sola implementación de la altura**, horneada en una rejilla de 4 m y servida en O(1). La consumen reglas (rutas, velocidad, visión), vista (malla, picking) y UI (minimapa, rótulo del paraje).

```gdscript
static func load_default() -> RefCounted               # caché por proceso; null (con push_error) si faltan los JSON
var size_m: Vector2                                    # (900, 650)
var cell_m: float                                      # 4.0  → nx = 226, nz = 164
var nx: int ; var nz: int
var datum_asl_m: float                                 # 2940.0
var anchor: Vector2                                    # (450, 325), la iglesia
func lamina_to_game(e: float, n: float) -> Vector2     # x = E + 450, z = 325 − N
func game_to_lamina(p: Vector2) -> Vector2             # (E, N)
func height_at(x: float, z: float) -> float           # m sobre el cero local; continua; fuera de la ventana usa el contexto
func height_dem_only(x: float, z: float) -> float     # solo el «relieve de juego» (DEM suavizado a 30 m), sin capas de diseño ni micro-relieve (para el test de la lámina 03)
func asl_at(x: float, z: float) -> float               # height_at + datum
func normal_at(x: float, z: float) -> Vector3
func slope_deg_at(x: float, z: float) -> float
func surface_at(x: float, z: float) -> String          # uno de SURFACES
func wetness_at(x: float, z: float, rain: float = 0.0) -> float    # 0..1 (humedad del suelo)
func is_blocked(x: float, z: float, mounted: bool = false, open_gaps: Array = []) -> bool   # muro, tapia sin portillo, agua honda
func speed_factor_at(x: float, z: float, rain: float = 0.0, mounted: bool = false) -> float   # 0..1 (barro, pendiente, zanja); 0 = intransitable
func los(a: Vector2, b: Vector2, eye_a: float = 1.6, eye_b: float = 1.6, open_gaps: Array = []) -> bool   # visión sobre relieve, tapias y edificios
func elevation_advantage(a: Vector2, b: Vector2) -> float      # height_at(a) − height_at(b) (m)
func landmark(id: String) -> Dictionary                # {id,name,short,type,x,z,yaw_deg,footprint,height_m,tag,tag_parts,source,priority,variant}
func landmarks(variant: Dictionary = {}) -> Array      # filtra por la variante del mundo; {} = todos
func features(kind: String, layout: String = "") -> Array     # FEATURE_KINDS (los rasgos salen de humahuaca_level.json): "tapia","zanja","acequia","barricada","portillo","calle","manzana","patio","parcela","camino","camino_cubierto"
func features_near(p: Vector2, radius_m: float, kind: String = "", layout: String = "") -> Array
func river() -> Dictionary ; func is_ford(x: float, z: float) -> bool
func heightfield() -> Dictionary                       # {nx, nz, cell, origin_x, origin_z, h: PackedFloat32Array} para la vista
func context_field() -> Dictionary                     # {nx, nz, cell, origin_x, origin_z, h: PackedFloat32Array} (30 m)
func nav_grid() -> Dictionary                          # {nx, nz, cell, solid: PackedByteArray, weight: PackedFloat32Array} estático (portillos cerrados)
func minimap_image(px: Vector2i, opts: Dictionary = {}) -> Image   # relieve sombreado + curvas de 20 m + cauce; norte arriba; sin unidades
func report() -> Dictionary                            # {source, tag, uncertainty_m, smooth_m, h_min, h_max, design_layers:[{id,kind,delta_m,prominence_target_m,tag}], prominence_bateria_m, slope_cells_pct_ge8, vertical_features:[{id,los_pairs,speed_pairs}], lamina_check:{n,ok,max_err_m,failed:[ids]}, bake_ms, bake_stages_ms:{...}, counts:{...}}
```

Exigencias: `height_at` es **la** altura (la vista dibuja `height_at`, el picking marcha sobre `height_at`, las rutas leen `speed_factor_at`); ninguna otra clase interpola la grilla por su cuenta. Presupuestos: horneado completo **< 300 ms**; `height_at` ≥ 1 M consultas/s en GDScript (se mide); `report()` rotula qué es dato actual y qué es diseño. **Alturas de referencia** que el test fija sobre la fuente que haya (±3 m con plan A, ±10 m con plan B): `height_at(450,325)` ≈ +17; el cauce en z = 325 (x = 859) ≈ +12; la zona de partida (70, 470) ≈ +27; **prominencia de la batería** (`height_at(bateria)` menos la media de `height_at` sobre 16 puntos del anillo de 120–150 m alrededor de (305, 345)) `= 12,0 ± 0,5` con cualquier fuente (el domo es un residuo del DEM). Las **consecuencias del relieve** que `test_hx_terrain` fija: `slope_cells_pct_ge8 ≥ 2,5 %` y ≥ 3 rasgos verticales con un par de puntos cuyo `los()` o `speed_factor_at()` cambia con y sin el rasgo; el signo del gradiente oeste → este (≥ 10 m de caída en z = 325) y la curva de 2 960 m en z = 0, 325 y 650. Las superficies y los rasgos se rasterizan **una vez** (no por consulta).

### 3.2 `HumahuacaRules` (`scripts/humahuaca/rules/humahuaca_rules.gd`, `RefCounted`; dueña: `reglas_historia`)

Misma filosofía que `GameRules` (paso fijo, RNG propio, eventos, `state` serializable) **sin heredar sus constantes ni sus ramas**. `MAX_DT = 60` por llamada a `tick`.

```gdscript
const SCENARIO := "humahuaca" ; const SAVE_VERSION := 1 ; const STEP := 0.25
var state: Dictionary

func new_game(seed_value: int = 1817, attempt: int = 1, opts: Dictionary = {}) -> Dictionary
# opts: {"skip_intro": bool, "phase": "briefing"|"aproximacion"|"ataque"|"extraccion", "variant": {dim: valor},
#        "loot_traits": {corral, plata, polvora}, "mercy_level": int, "assists": [ids], "diary_marks": [...]}. Con "phase" las pruebas empiezan en cualquier fase sin guiones de 200 s.
func world_from_seed(seed_value: int) -> Dictionary     # determinista: {guardia, torre_en, refugio, lluvia, refuerzo, layout, loot: {corral, plata, polvora}}; en R1 devuelve siempre el mundo fijo; desde R2b sortea solo las ACTIVE_DIMS (las otras dimensiones quedan en su valor fijo)
func map_data() -> Dictionary                           # map + level + rules fusionados, solo lectura (sin claves repetidas por V3); {} si falta
func terrain() -> RefCounted ; func map_size() -> Vector2
func terrain_height_at(x: float, z: float) -> float     # = terrain().height_at (misma firma que GameRules)
func tick(dt: float) -> Array                           # eventos nuevos (ver abajo); acumulador de pasos de 0,25 s
func advance_to(t: float) -> Array                      # solo pruebas y QA: avanza el reloj sin órdenes

func environment() -> Dictionary    # {phase: "noche"|"alba"|"dia", time_of_day: 0..1, rain: 0..1, visibility_m: float, mud: 0..1, firearm_reliability: 0..1}
func hud_state() -> Dictionary      # lo que la UI muestra tal cual (abajo)
func render_state() -> Dictionary   # lo que la vista dibuja (abajo); NO filtra nada que el jugador no deba ver
func units() -> Array ; func get_unit(id: String) -> Dictionary
func objectives() -> Array ; func objective(id: String) -> Dictionary
func loot_state() -> Dictionary     # {items[], capacity_kg, load_kg, golpe: {entregado, destruido, oculto, perdido, pendiente, total: 100.0}}; oculto = lo escondido en un escondite a salvo (×0,7); lo oculto cerca del camino sur o de la posta cuenta 0 y suma a perdido desde que se lo esconde (el HUD lo avisa: «lo van a encontrar»)

func list_actions(actor_kind: String) -> Array         # "group"|"scout"|"train"|"global": ids de ACTIONS en el orden de la UI
func action_info(action: String) -> Dictionary         # JSON rules.actions[action] + {"id": action}; {} si no existe
func action_availability(actor_id: String, action: String, target: Vector2 = Vector2.ZERO, opts: Dictionary = {}) -> Dictionary
# {"ok": bool, "reason": String, "cost_text": String, "tag": String}. Sin efectos. cost_text arma «12 kg/s · 4 mulas» desde el JSON.
func issue_order(actor_id: String, action: String, target: Vector2 = Vector2.ZERO, opts: Dictionary = {}) -> Dictionary
# opts: {"pace": PACES, "waypoints": [Vector2] (≤ 4), "front": objetivo, "posture": "a_fondo"|"con_cautela", "item": id de botín, "qty": int}
# Devuelve {"ok", "reason", "path": [{x,z}], "plan": <plan_route/plan_recon>}
func cancel_order(actor_id: String) -> Dictionary ; func undo_last() -> Dictionary
func plan_route(actor_id: String, target: Vector2, opts: Dictionary = {}) -> Dictionary
# Sin efectos. {"ok","reason","path":[{x,z}],"length_m","time_s","noise","seen_risk": 0..1,"mud_m","unknown_m",
#  "risk": "bajo"|"medio"|"alto"|"desconocido","arrives_before_dawn": bool,"warnings": [String]}. Planifica con lo que el jugador sabe; ejecuta con el terreno real.
func plan_recon(actor_id: String, points: Array, opts: Dictionary = {}) -> Dictionary
# {"ok","reason","risk_pct": float,"time_s": float,"reveals": [String]}  (riesgo decidible antes de ordenar)
func give_signal() -> Dictionary ; func retreat_all() -> Dictionary      # global; retreat_all termina en derrota «retirada»
func pending_choice() -> Dictionary                    # {} o {id, titulo, texto, opciones[{id,label,costo_txt}], vence_s}
func resolve_choice(option_id: String, by_timeout: bool = false) -> Dictionary
func set_mercy(level: int) -> void ; func apply_assist(kind: String) -> Dictionary
func campaign_report() -> Dictionary ; func epilogue() -> Array
func signal_info() -> Dictionary                       # {can_give, reason, in_position: [ids], waiting: [ids], dark_pct: 0..100, drift_pct: 0..100}: lo que la UI dice de la señal («Portal todavía no llegó», costo de la oscuridad y del desvelo)
func route_atlas(front: String = "") -> Array          # solo lectura: [{front, approach ∈ APPROACHES, length_m, time_s, seen_risk, unknown_m, cost_est}]; lo usan test_hx_rules (compuerta 10), la tabla de rutas por ronda y la pista del diario
func restore_snapshot(d: Dictionary) -> Dictionary     # {"ok","reason"}: valida y reemplaza el estado sin tocar archivos (la usan la ramificación de decisiones y los puntos de control)

func snapshot() -> Dictionary                           # state.duplicate(true)
func save_game(path: String) -> Error                   # atómico (.tmp + rename); tope 3 000 000 B UTF-8 (recorta log, órdenes)
func load_game(path: String) -> Dictionary              # {"ok", "reason"}; valida ANTES de reemplazar; game_id nuevo y previous_game_id
func validate_snapshot(v: Variant) -> Dictionary        # {"ok","reason"}; ver 3.2.4

# Decisiones del mando realista (forma del Norte; Jev fuera del MVP, D4): opcionales y siempre con alternativa local determinista
func enemy_observation() -> Dictionary ; func enemy_choices() -> Array
func enemy_fallback() -> String ; func record_external_decision(decision: Dictionary) -> Dictionary
```

#### 3.2.1 Estado (`state`, `schema_version = 1`): campos que otras capas pueden asumir

Mínimos y obligatorios (el resto de `state` es privado de las reglas; la vista y la UI **no** lo leen: usan `render_state`, `hud_state` y las consultas de arriba):

| Campo | Tipo / rango | Notas |
|---|---|---|
| `schema_version` (1), `game_id`, `state_version` (sube en cada paso), `scenario` (`"humahuaca"`), `map_id`, `map_version`, `contract` (1) | | un guardado con otro `map_version` se rechaza |
| `seed`, `rng_state`, `attempt`, `elapsed`, `accumulator` | | RNG congruencial propio; `elapsed` en segundos de juego a ×1 |
| `status` (`STATUS`), `reason`, `phase` (`PHASES`), `resistencia` (bool) | | `resistencia` = la torre dispara o el frente más duro sigue en pie |
| `world` | `{guardia, torre_en, refugio, lluvia, refuerzo, layout, loot_traits: {corral, plata, polvora}, known: [dims], rumors: [{id, dim, val, reliability, true_value, shown}]}` | fijo hasta ganar; `known` = dimensiones y rasgos del botín ya revelados |
| `alarm` | `{level 0..1, first_shot_at (−1), signaled, signal_at (−1), messenger: "none"/"sent"/"stopped"/"escaped", reinforcement_at (−1), reinforcement_arrived}` | |
| `objectives` | id de `OBJECTIVES` → `{state, toma 0..100, garrison, garrison_max, alert 0..1, surprise_until, reconocido 0..1, held_by, custody, taken_at, supporters[]}` | + `tower` (cuartel) y `battery` (batería) con sus campos propios |
| `units` | 5 unidades, ids de `GROUPS`; cada una `{id, name, kind, x, z, strength 0..100, fatigue 0..100, morale 0..100, armed 0..1, men, mounted, pace, stage, order, path[], noise 0..1, detected, custody, horses, carry_kg, capacity_kg, tag}` | `stage` ∈ `STAGES`; `order.action` ∈ `ACTIONS` |
| `loot` | `{items[{id, kind, qty, unit_kg, unit_value, state, x, z, where, carried_by, spot, safe}], capacity_kg, load_kg, delivered_value, destroyed_value, hidden_value, lost_value, total_value (=100)}` | `kind` ∈ `LOOT_KINDS` (`LOOT_KINDS_R1` en R1), `state` ∈ `LOOT_STATES`; `spot` = id de escondite y `safe` = a salvo (sale de la distancia al camino sur y a la posta) |
| `recon` | lo que el jugador **sabe**: tapias, zanjas, centinelas, torre, guardia por frente | alimenta `plan_route`, `hud_state` y `render_state` |
| `stats` | `start_strength{}`, `detections`, `losses`, `support_events`, `horses_lost`, `powder_wet`, `pacing{decision_gap_max_s, decision_gap_attack_max_s, first_decision_s, events_per_min, visible_actions_t0}` (cuentan **ofertas**: la medida de decisiones **significativas** la hace `humahuaca_playthrough.gd --measure=decisions` por ramificación), `charges_total`, `charges_in_gap` (cargas sobre el cuartel lanzadas en el hueco de recarga) | alimenta el parte y las compuertas 9 y 11 |
| `log` | Array de eventos, tope 400 | |

#### 3.2.2 Eventos (los devuelve `tick`; también quedan en `state.log`)

`{"time": float, "round": 1, "text": String, "kind": EVENT_KINDS, "tag"?: String, "pos"?: {x,z}, "unit"?: String, "objective"?: String, "field_event"?: String, "strong"?: bool, "options"?: [{id,label,costo_txt}], "until"?: float}`. Los eventos con `options` abren una **decisión** (la UI pausa automáticamente, con tope de 25 s, y vuelve a ×1). `kind` fuera de `EVENT_KINDS` es un error de contrato.

#### 3.2.3 `hud_state()`, `render_state()` y `campaign_report()`

**`hud_state()`** (la UI lo pinta y **no** recalcula nada; en la Justina las alertas, el «siguiente paso» y la fase se calculaban en la interfaz y eso impedía probarlas sin ventana):

```
{"objetivo": String,                                  # una línea
 "siguiente": {"texto", "actor", "action", "target": {x,z}|{}, "urgencia": 0|1|2},   # UNO solo
 "fase": {"id", "nombre": "Noche · Aproximación", "reloj": "Falta el alba: 2:10"},
 "alba": {"progreso": 0..1, "restante_s"},
 "frentes": [{"id","nombre","estado","estado_txt","toma_pct","guardia":{"min","max","conocida"},"alerta","sorpresa_s","apoyo":[ids],"tag"} ×3],
 "grupos": [{"id","nombre","glifo","fuerza_pct","fatiga_pct","etapa_txt","ruido":"silencio"|"se_oye"|"los_oyen","tag","custodia","vivo"} ×5],
 "alertas": [{"id","nivel":"info"|"aviso"|"critica","corto","largo","boton","accion":{},"pausa":bool,"vence_s"}],
 "chips": [{"id","txt","valor"}],                      # carga, golpe, refuerzo, caballos
 "senal": {"puede": bool, "faltan": [ids], "oscuridad_pct": 0..100, "desvelo_pct": 0..100},
 "torre": {} | {"activa": bool, "municion_pct", "proxima_en_s", "periodo_s": 7.5, "angulo_muerto_m": 12},
 "golpe": {"entregado","destruido","oculto","pendiente","total": 100.0},     # los chips muestran 3: entregado / quitado al enemigo (destruido + oculto) / pendiente
 "refuerzo": {"estado":"desconocido"|"en_camino"|"visible"|"llego","restante_s","banda": [min_s, max_s]},
 "decision": {} | {"id","titulo","texto","opciones":[{"id","label","costo_txt"}],"vence_s"},
 "ayudas": [ids visibles], "mundo": {"linea": String}}
```

**`render_state()`** (lo que dibuja la vista; **solo** lo que el jugador conoce o ve: la guardia y la postura no reconocidas no aparecen):

```
{"version": int, "t": float, "phase": String, "env": <environment()>,
 "units": [{"id","x","z","yaw_deg","kind","mounted","stage","strength_pct","men_visible": 2..14,"noise_state","detected","carry_ratio"}],
 "objectives": [{"id","x","z","state","toma","alert","garrison_pct": float (−1 si no reconocida),"under_fire"}],
 "enemies": [{"id","kind":"centinela"|"guardia"|"artillero"|"fusilero"|"torre"|"mensajero"|"refuerzo","x","z","alert","firing"}],   # solo visibles o conocidos
 "loot": [{"id","kind","state","x","z","qty"}], "fire_lines": [{"from":{x,z},"to":{x,z},"kind"}],
 "visibility_pools": [{"x","z","r"}], "marks": [{"key","kind","text","x","z","confirmed": false}], "horses": [{"x","z","state"}],
 "lights": [{"id","kind":"brasero"|"ventana"|"candil"|"fogata","x","z","r_m","objective"?}],      # se ven de lejos: información, no decorado
 "tower": {} | {"x","z","next_volley_in_s","period_s","dead_angle_m","firing"}}                          # el anillo de recarga y el ángulo muerto
```

**`campaign_report()`** (válido siempre; el definitivo con `status != "playing"`): `{status, reason, elapsed, outcome_title, cause_id ∈ CAUSES (o ""), cause (≤ 140 caracteres con momento y lugar), advice, medal ∈ MEDALS, medal_label, golpe{entregado, destruido, oculto, perdido, total}, pieces[{id, tratamiento ∈ TREATMENTS, estado}] (las 7 piezas: lo que alimenta el epílogo), loot_traits{...}, objectives[{id,nombre,estado,taken_at}], groups[{id,nombre,tag,start_strength,end_strength,loss_pct}], loss_pct, detections, support_events, horses{salvados, perdidos}, powder_wet, variant{...}, route_notes[String], pacing{...}, history[{text, tag}], epilogue[{fecha, texto, tag}], assists_used[], mercy_label}`.

#### 3.2.4 Guardado y validación

`validate_snapshot` exige, además de los tipos y rangos de 3.2.1: `scenario == "humahuaca"` (si no: «Este guardado es de otro escenario»), `schema_version == SAVE_VERSION`, `map_version` igual al del JSON, **5 unidades** con los ids de `GROUPS` sin repetir, coordenadas dentro de `map_size()`, `stage`/`pace`/`order.action` válidos, `variant` y `loot_traits` con valores legales, `loot.total_value == 100`, `delivered + destroyed + hidden + lost ≤ 100`, coherencia (`phase` compatible con el estado de los objetivos; `status == "victory"` ⇒ 3 objetivos `tomado`; `alarm.first_shot_at ≤ elapsed`; `moving` ⇒ `path` y `order` no vacíos; `loot.load_kg` ≤ `loot.capacity_kg`). **Round-trip:** guardar y cargar no cambia `snapshot()` (salvo `game_id`, `previous_game_id`, `state_version` y el evento de carga; tolerancia 1e-6, RNG exacto). `test_hx_rules` rechaza **≥ 30 mutaciones** (como el Norte) y confirma que un guardado de la Justina o del Norte se rechaza con motivo claro.

#### 3.2.5 Biblioteca de políticas: `HumahuacaPolicies` (`scripts/humahuaca/rules/humahuaca_policies.gd`, `RefCounted`; dueña: `reglas_historia`)

**Una sola biblioteca** para las reglas, la interfaz de prueba y las herramientas (nadie escribe un segundo juego de bots): `static func list() -> Array` (los nombres: `experto`, `obediente`, `torpe`, `ciego_sin_recon`, `ciego_tarde`, `ciego_un_frente`, `ciego_sin_arreo`, `pasivo`, `pausa_reanuda`, `aleatorio`, las 8 estrategias de frente `est_<frente>_<enfoque>` de `APPROACHES`, las recetas de extracción `ext_<receta>` de `EXTRACTIONS`, `barrido_senal` y `interfaz`) y `static func decide(policy: String, view: Dictionary, rng: RandomNumberGenerator) -> Array` (devuelve órdenes `[{actor, action, target, opts}]`). `view` es **lo que el jugador puede ver** (`hud_state()`, `render_state()` y consultas de solo lectura); solo `experto` y las `est_*`/`ext_*` reciben además `omniscient: true` (conocen el mundo); `obediente`, `torpe`, `ciego_*`, `pasivo`, `pausa_reanuda`, `aleatorio` e `interfaz` **no leen estado oculto** (el QA lo audita). El *obediente* solo ejecuta `hud_state().siguiente`; el *torpe* es el obediente con demoras de 2–8 s, ignora el 30 % de los avisos no urgentes y falla la sincronía ± 15 s. El **puntaje continuo** para comparar enfoques es `golpe − 0,5 × bajas (%)`, siempre por mundo.

### 3.3 `HumahuacaProgress` (`scripts/humahuaca/rules/humahuaca_progress.gd`, `RefCounted`; dueña: `reglas_historia`)

Guarda **progreso, no partida**, en `user://humahuaca_progress.json` y `user://humahuaca_checkpoint.json` (escritura atómica; si el archivo está dañado se empieza de cero con `load_note` y nunca bloquea). **No** toca `campaign.json` (`campaign.gd` descarta lo que no conoce y se reinicia si `version != 1`).

```gdscript
func _init(path: String = "user://humahuaca_progress.json", checkpoint_path: String = "user://humahuaca_checkpoint.json")
func load_progress() -> bool ; func save_progress() -> bool ; var load_note: String
func world_seed() -> int ; func new_world() -> void                 # fijo hasta ganar; al ganar se re-sortea
var attempts: int ; var defeats_in_row: int ; var best_medal: String ; var won: bool ; var best_golpe: float
func begin_attempt(rules: RefCounted) -> Dictionary                 # cuenta el intento; da a rules las marcas del diario y la ventaja de la experiencia
func record_result(rules: RefCounted) -> Dictionary
# {won, medal, medal_label, record_line, cause_id, cause, advice, hint, defeats_in_row, offered_assists[], lines[], new_diary[], facts{frentes, golpe, bajas, tiempo}, next_available: bool (true tras ganar), next_label: "Ver la campaña completa: Sostener el norte"}
func offered_assists(rules: RefCounted) -> Array                    # [{id, label, text}] según la racha; nunca se imponen
func apply_assists(rules: RefCounted, ids: Array) -> Array
func diary_entries() -> Array ; func diary_marks() -> Array         # marcas «anotado»: {key, kind, text, x, z, confirmed: false}
func checkpoint_tick(rules: RefCounted) -> void                    # barato; se llama cada cuadro: guarda `posiciones` y `deposito` cuando corresponde
func has_checkpoint(kind: String) -> bool ; func checkpoint_time(kind: String) -> float
func restore_checkpoint(rules: RefCounted, kind: String) -> Dictionary   # {ok, reason}; cuenta el intento
func retry_options() -> Array                                       # [{id ∈ RETRY, label, available, at_s}]
func tutorial_pending() -> bool ; func mark_tutorial_seen() -> void ; func reset_all() -> void
func recommended_by_profile(main_progress: Dictionary) -> bool      # solo la nota «Recomendado tras la Justina» del menú (el botón de Humahuaca ya no tiene candado): bool(main_progress.justina_ganada)
```

**Compatibilidad.** (a) `campaign.json`, `save_justine.json` y `save_norte.json` no se leen, no se migran y **no cambian ni un byte** (lo verifica `test_hx_smoke`); (b) un `humahuaca_progress.json` dañado o de otra versión se descarta con aviso y se empieza de cero, sin bloquear; (c) un guardado de partida de otro escenario se rechaza con motivo; (d) no existen guardados previos de Humahuaca que migrar; (e) `recommended_by_profile` solo **lee** `main.progress.justina_ganada` (que `CampaignProgress` mantiene sincronizado).

### 3.4 `HumahuacaView` (`scripts/humahuaca/view/humahuaca_view.gd`, `Node3D`; dueña: `visual`)

Lee **solo** `rules.render_state()`, `rules.environment()`, `rules.terrain()` y su propio JSON; no calcula daño, tiempo ni órdenes y no dibuja información que el jugador no tiene. La cámara es de la UI (`main.camera`); la vista solo ofrece funciones.

```gdscript
func build(rules: RefCounted, quality: String = "media") -> void     # "baja"|"media"|"alta"; construye terreno, contexto, horizonte, edificios, río, vegetación, luz
func update_state(delta: float) -> void                              # cada cuadro; lo caro se reconstruye solo si cambia render_state().version
func ground_xz_from_screen(camera: Camera3D, pos: Vector2) -> Variant        # Vector2 (x,z) o null (marcha un rayo sobre height_at)
func pick_unit(camera: Camera3D, pos: Vector2) -> String                      # id de agrupación; "" si ninguna (radio 55 px)
func pick_units_in_rect(camera: Camera3D, rect: Rect2) -> Array              # orden estable: GROUPS
func pick_front(camera: Camera3D, pos: Vector2) -> String                    # id de objetivo a ≤ 60 px, o ""
func pick_landmark(camera: Camera3D, pos: Vector2) -> String
func get_landmark_info(id: String) -> Dictionary ; func landmark_labels(camera: Camera3D) -> Array   # [{id, name, tag, screen, behind}]
func camera_bounds() -> Rect2 ; func clamp_camera_target(p: Vector3) -> Vector3     # ventana + 120 m; y = max(height_at, …)
func camera_frustum_on_ground(camera: Camera3D) -> PackedVector2Array
func meters_per_pixel(camera: Camera3D, pos: Vector2 = Vector2(-1, -1)) -> float
func world_to_map(p: Vector2) -> Vector2 ; func map_to_world(uv: Vector2) -> Vector2    # v = 0 es el NORTE
signal minimap_changed ; func get_minimap_texture(size: Vector2i) -> Texture2D          # relieve + curvas + cauce; sin unidades (las dibuja la UI)
func set_selected_ids(ids: Array) -> void ; var selected_ids: Array
func set_layer_visible(layer: String, on: bool) -> void ; func layer_visible(layer: String) -> bool   # LAYERS: "paths","visibility","exposure","labels","landmarks","diary","enemy","lights"
func fx(kind: String, pos: Vector2, opts: Dictionary = {}) -> void      # "fogonazo","humo","impacto","captura","pisadas","explosion","senal"
func initial_frame(camera: Camera3D) -> Dictionary     # {target: Vector3, distance, pitch_deg, yaw_deg, fits: bool}; DEBE incluir los 3 objetivos y la zona de partida
func canonical_view(id: String) -> Dictionary          # {target, distance, pitch_deg, yaw_deg, time_of_day, rain, must_show[5]} de las 7 vistas (VIEW_IDS)
func set_time_override(time_of_day: float, rain: float) -> void   # QA: congela la luz y la lluvia para las vistas canónicas (−1 = sin override)
func set_albedo_mode(on: bool) -> void                 # QA: render de albedo (materiales sin sombreado, sin niebla, sin exposición ni sombras) para la métrica de paleta
func probes(camera: Camera3D) -> Array                 # QA: [{kind: "edificio"|"suelo"|"ficha"|"objetivo", id, rect: [x, y, w, h]}] en píxeles: huellas proyectadas y anillos de suelo para medir ΔL*
var unit_nodes: Dictionary ; var unit_labels: Dictionary          # por id de agrupación
```

Exigencias: terreno **continuo** (ventana → contexto → horizonte sin grietas) y **sin discos de color**: cada agrupación tiene silueta propia y contorno; **sin bandera argentina ni de Burgundy**; el templo **sin torres ni fachada** de 1880–81; ningún modelo del listado de excluidos del diseño (sección 12.3); el templo mide ≤ 8 m de alto (AABB) y ninguna cresta de vértices pasa del caballete; **las luces** (`render_state().lights`) se dibujan de lejos y delatan a la guardia; micro-relieve, anillo de contenido de 0–400 m y **un solo shader de suelo** para ventana, contexto y horizonte; **un `Environment` por escena** (sin `shader_globals` ni ajustes de render en `project.godot`). Presupuesto: construir ≤ 1 500 ms; cuadro medio por perfil (`benchmark.py`, 1440 × 900, Forward+): **baja ≤ 2,5 ms, media ≤ 4,0 ms, alta ≤ 6,0 ms y p95 ≤ 8,3 ms**.

### 3.5 `HumahuacaUI` (`scripts/humahuaca/ui/humahuaca_ui.gd`, `Node`; dueña: `ui_feel`)

El **controlador**: hijo de `main` (lo crea `_start_humahuaca`), con sus propios `_process` y `_unhandled_input`; **nunca** pasa por `main.rules`, `_is_j()` ni `mode == "play"`. Al arrancar fija `main.camera.far ≥ 9000` y `fov = 46`.

```gdscript
signal exited(to: String)                                   # "menu" | "norte"
func start(main: Node, opts: Dictionary = {}) -> void      # opts: {load: bool, qa: bool, attempt: int, seed: int, phase: String, skip_intro: bool, force_stub: Array}
func stop() -> void                                         # libera vista, interfaz y audio propios; deja main.camera.current = true y RESTAURA lo que cambió (camera.far/fov, escala 3D y MSAA del viewport, ambiente del audio_manager, content_scale, settings.last_save)
# API de QA estable (ninguna prueba toca atributos privados de main ni del controlador)
func qa_state() -> Dictionary                               # {phase, elapsed, selected, camera, visible_controls, text_chars, alerts, front_states, ...}
func qa_set_camera(target: Vector2, dist: float, pitch_deg: float, yaw_deg: float) -> void
func qa_set_time(t: float) -> void ; func qa_run() -> void  # recorrido con las 7 vistas canónicas y qa_report.json (--qa=humahuaca)
func qa_step(seconds: float) -> void                        # arnés del agente-jugador: avanza `seconds` de juego (a ×1, con las pausas de decisión que correspondan) y vuelve a pausar
func benchmark_prepare() -> void                            # deja el nivel en pleno ataque (lluvia, fx, fichas) para --benchmark=humahuaca
```

**Qué dibuja y hace la interfaz** (exigencias que verifican `test_hx_flow` y `ui_qa_humahuaca`; todo el texto sale de `hud_state()` y de los JSON, sin recalcular reglas):

- **HUD de una mirada.** Cabecera con el título, el indicador permanente **«TIEMPO REAL · ▶ ×1» / «‖ EN PAUSA»**, la **fase** («Noche · Aproximación») y la **barra del alba** (`hud_state().alba`); abajo, **una sola línea de objetivo y un solo «siguiente paso»** (`siguiente`) con su botón. Tres **tarjetas de frente** (batería, cuartel, pólvora) con estado, barra de toma, guardia («?» hasta reconocer), alerta, cuenta de sorpresa e ícono de apoyo; **el costo de la oscuridad y del desvelo** y quién falta para la señal (`hud_state().senal`), el **anillo de recarga de la torre** (`hud_state().torre`) y el **reloj del refuerzo** con su banda (`hud_state().refuerzo`).
- **Panel de agrupaciones** (izquierda): cinco fichas (teclas 1–5) con glifo y silueta propios, fuerza, fatiga, etapa en palabras, ruido en tres niveles, custodia y etiqueta de fuente; selección por clic, caja (Shift suma, Ctrl alterna) y Tab; el panel dice a cuántas agrupaciones llegará la orden.
- **Barra de acciones contextual** (abajo): solo las usables más la recomendada para la selección, con `cost_text`, atajo y glifo de etiqueta; lo riesgoso va aparte («CON RIESGO»); una línea de **motivo de alto fijo** para que los botones no se muevan bajo el cursor; las acciones sin objetivo se disparan con un clic y las de mapa entran en modo apuntado.
- **Vista previa de ruta y de reconocimiento:** al apuntar se llama `plan_route` o `plan_recon` (sin efectos) y se muestra «412 m · llega en 3:10 · riesgo alto · te ven a 60 m»; la ruta se dibuja con color por riesgo; Shift agrega paradas (≤ 4); Ctrl+Z deshace.
- **Alertas:** una sola alerta crítica a la vez, con botón y cuenta regresiva; el resto, avisos con prioridad (un solo mensaje guía a la vez); **pausa automática corta** (≤ 2 s) o ninguna salvo decisiones; el ×2 se sugiere en esperas tranquilas y nunca cambia solo; la velocidad vuelve a ×1 en cada evento de campo.
- **Diálogos:** briefing en dos tarjetas con «Empezar» y «Saltar»; **decisión** (opciones con costo, reloj visible; se resuelve sola a los 25 s con la opción pasiva); **menú de pausa** (continuar, guardar, diario, ayuda, «Retirada general» con 2 clics, menú); **parte** de derrota (causa, consejo, tres datos y el botón primario sin scroll a 1280 × 720) y de victoria (medalla, por qué, mejor medalla, epílogo fechado con sus etiquetas, el contraste «en la realidad / en tu partida», la aclaración del tiempo comprimido, «Ver la campaña completa: Sostener el norte» y «Jugar de nuevo»); **diario**; **ayuda F1** y tutorial de 6 pasos (R3; antes, un botón «?» con las 6 líneas de «cómo se juega» y la flecha del «siguiente paso»); **apertura** de 12–15 s (cámara automática por los tres objetivos con su luz; cualquier tecla la salta).
- **Mapa:** minimapa de 260 × 188 px (M lo agranda) con unidades, cuadro de cámara, brújula (la N gira con la guiñada) y escala gráfica (de `meters_per_pixel`); rótulo del paraje («Ladera oeste», «Calle abierta», «Patio de la posta») y rótulos de hitos con el glifo de su etiqueta, sin solaparse; clic o arrastre en el minimapa mueve la cámara.
- **Todas las pantallas:** legibles desde **1024 × 640** (mínimo del proyecto) y probadas a 1280 × 720, 1920 × 1080 y 2560 × 1440; nada fuera del viewport; contraste de texto ≥ 4,5:1 medido sobre los píxeles; nada que dependa solo del color.

**Atributos de `main` que el controlador puede leer o usar** (lista cerrada; cualquier otro uso es una violación): `layer`, `ui` y `_new_ui()`, `camera`, `theme_main`, `title_font`, `audio_manager`, `settings` (y `_save_settings()` para fijar `settings.last_save = "humahuaca"`), `jev` (solo `invalidate()`), `qa_mode`, `qa_path`, `qa_size`, `progress` (Dictionary, **solo lectura**: `justina_ganada`), `_save_path(nombre)`. El kit de interfaz es **propio** (`humahuaca_ui_kit.gd`): no se llama `main._panel/_button/_label`, porque si `ui_feel` ajusta el kit no debe cruzarse con los ajustes de la Justina. **Audio:** `audio_manager.set_environment("norte")` (viento) más `AudioStreamPlayer` propios en el bus `Ambiente` para la lluvia; los efectos son los de siempre con otro tono; sin música.

**Cámara** (propia, `humahuaca_camera.gd`): WASD/flechas, borde de pantalla, arrastre del mapa, rueda hacia el cursor entre 40 y 900 m, Q/E guiñada, RePág/AvPág inclinación, piso a 3 m sobre `height_at`, recorte con `camera_bounds()`; el zoom inicial sale de `initial_frame()`. **Teclas reservadas** (no se reasignan): `Espacio` pausa; `F2/F3/F4` y `+/−` velocidad ×1/×2/×4 (siempre indicada: «TIEMPO REAL · ▶ ×1» / «‖ EN PAUSA»); `F1` ayuda; `Esc` cancelar o menú de pausa; `F5/F9` guardar y cargar; `F11` pantalla completa; `1–5` agrupaciones (**pulsar otra vez la misma tecla de 1 a 3 centra la cámara en el frente de esa partida**); `Tab` ciclar; `Ctrl+Z` deshacer. La tabla completa vive en `humahuaca_ui.json.key_table` y en `docs/humahuaca/CONTROLES.md`, y un test verifica que cada fila figure ahí.

---

### 3.6 Ejemplos de forma: el contrato fija la forma, no los valores

Las firmas y las formas de 3.2.3 son el contrato; **los stubs los escribe cada dueño** (R1.0), así que el contrato no congela ~120 firmas escritas por una sola persona. Para que las cuatro pistas hablen el mismo idioma desde el primer día, **compuertas y documentos** deja en R0 un **JSON de ejemplo por forma**, con valores plausibles y todas las claves: `docs/humahuaca/forma/hud_state.json`, `render_state.json`, `campaign_report.json`, `plan_route.json` y `qa_state.json`. `test_hx_smoke` comprueba que la salida de **cada** implementación (el stub y la real) contenga al menos las claves del ejemplo, con el mismo tipo (comparación recursiva de formas; los arreglos se comparan por su primer elemento). Una clave nueva se agrega al ejemplo por addendum; quitar una, no.

## 4. Enganches: menú, desbloqueo, flags, herramientas

Todo lo de esta sección lo hace **el integrador en el commit de andamiaje T0** (sección 6.3), salvo lo marcado **[final]**. Punto de partida: la prueba de concepto de `investigacion-nivel2/preparacion/03_poc/main_gd_ganchos.diff` (18 líneas, `test_integration` 283/283).

### 4.1 Menú y arranque (`main.gd`, 1 espacio de sangría)

```gdscript
# H1, junto a `var rules`/`var world` (l. 15-16)
 var hx: Node  # controlador del nivel «humahuaca» (null fuera de él)
# H2, primera línea de _menu() (l. 389)
 _stop_humahuaca()
# H2d, ENTRE `var unlocked=...` (l. 411) y el botón del Norte (l. 412), para que el orden sea I, II, III
 var hxb=_button(box,"II  ·   HUMAHUACA: EL DEPÓSITO DE LA RETAGUARDIA\n"+("El golpe de Arias  ·  1817" if unlocked else "Recomendado tras la Justina  ·  El golpe de Arias, 1817"),func():_start_game("humahuaca"),82)
 hxb.alignment=HORIZONTAL_ALIGNMENT_LEFT   # siempre habilitado (D1c): la Justina no está certificada y un candado dejaría sin probar el nivel
# El botón del Norte pasa a «III  ·   SOSTENER EL NORTE» (l. 412), con el subtítulo habilitado «La campaña entera, 1816–1817, vista desde Salta»;
# su subtítulo bloqueado «Ganá la Justina para abrirlo» y su candado NO cambian (las pruebas los buscan). Su título de HUD (l. 629) pasa a «III  ·  SOSTENER EL NORTE»;
# la frase «Dos momentos de una historia» (l. 405) pasa a «Tres momentos de una historia». La subcadena «SOSTENER EL NORTE» NO cambia.
# H3, primera línea de _start_game (l. 432)
 if scenario_name=="humahuaca":_start_humahuaca();return  # GameRules.new_game() convertiría cualquier nombre desconocido en "justine"
# H4, después de l. 454
func _start_humahuaca(opts:={}):
 jev.invalidate();pending_round=false;outcome_shown=false
 if is_instance_valid(world):remove_child(world);world.queue_free()
 world=null;mode="hx";paused=true;_new_ui()
 hx=_hx_make();add_child(hx)
 hx.exited.connect(_on_hx_exited)
 hx.start(self,opts)
func _hx_make():   # carga con respaldo: si el controlador real falta o no parsea, se usa la cáscara y el nivel igual arranca y vuelve al menú
 var path="res://scripts/humahuaca/ui/humahuaca_ui.gd"
 var script=load(path) if ResourceLoader.exists(path) else null
 if script==null or not script.can_instantiate():script=load("res://scripts/humahuaca/stubs/stub_ui.gd")
 return script.new()
func _stop_humahuaca():
 if not is_instance_valid(hx):return
 hx.stop();hx.queue_free();hx=null
 if is_instance_valid(camera):camera.current=true
func _on_hx_exited(to:String):
 if to=="norte":_start_game("norte")
 else:_menu()
```

El tercer botón **no** contiene «EL RÍO OFRECE», «SOSTENER EL NORTE» ni «Ganá la Justina para abrirlo» (`test_integration` y `ui_qa` buscan los botones por subcadena). Resultado medido en la prueba de concepto: el menú con tres botones entra a 1280 × 720 (último elemento en y = 856 de 900); **a 1920 × 1080, 2560 × 1440 y Compatibility no se midió**: `test_hx_smoke` agrega el chequeo «el último elemento del menú ≤ alto del viewport» y `ui_qa` lo corre en las tres resoluciones. `main.gd` queda con **≈ 26 líneas insertadas y 4 textos modificados, ninguna lógica borrada** (la rúbrica del QA admite hasta 80 agregadas y 10 borradas).

- **H5 · «Continuar» y guardado.** `_save_path("humahuaca")` ya da `user://save_humahuaca.json` (con `qa_` en modo QA); el controlador guarda con `rules.save_game(main._save_path("humahuaca"))` y fija `main.settings.last_save = "humahuaca"` + `main._save_settings()`. En `_load_game` (l. 888–903) la rama `scenario_name=="humahuaca"` llama `_start_humahuaca({"load":true})` **antes** de `rules.load_game` (que solo conoce `justine`/`norte`). Prueba: guardar en cada escenario y comprobar el destino de «Continuar» (riesgo R11 de [03]).
- **H6 · Historia.** `_history_dialog` (l. 967) itera `["justine","humahuaca","norte"]`; `scenarios.humahuaca` lo completa `reglas_historia` desde el esqueleto de T0.
- **H7 · QA y benchmark.** `_ready` (l. 250–265) ya pasa `--scenario=`, `--qa=` y `--benchmark=` a `_start_game`, `_qa_run` y `_benchmark_run`: estas dos últimas aceptan `"humahuaca"` y delegan (`hx.qa_run()`, `hx.benchmark_prepare()`); `_qa_run` y `_benchmark_run` hoy fuerzan «justine» para cualquier nombre desconocido (l. 1097) y para el escenario de benchmark (l. 1154–1157): se ramifican.
- **H9 · volver al menú.** `_return_menu` (l. 905) llama `_stop_humahuaca()` si `mode=="hx"` (el controlador también emite `exited("menu")` con Esc).

### 4.2 Desbloqueo (decisión D1)

- **D1a + D1c (este ciclo, en vigor):** el **Norte** sigue exactamente como hoy (`unlocked = bool(progress.justina_ganada)`, con su candado y su texto «Ganá la Justina para abrirlo»). **Humahuaca está siempre habilitado** y lleva la nota «Recomendado tras la Justina» mientras el perfil no la haya ganado: una línea en `_menu`, sin tocar el candado del Norte. Ganar Humahuaca registra `won` en `humahuaca_progress.json` y habilita el botón del epílogo «Ver la campaña completa: Sostener el norte» (`exited("norte")`; la campaña de 1816–1817 vista desde Salta, que ya incluye una versión abstracta de Humahuaca: **no se afirma que el nivel III continúe al II**). `PatriaGuemes.exe -- --scenario=humahuaca` abre el nivel directo (como `--scenario=norte`: pasa por `_start_game` sin mirar ningún candado).
- **D1b** (cuando el nivel 2 esté certificado; **[final]**): reencadenar Justina → Humahuaca → Norte. Cuesta **seis comprobaciones fijadas literalmente** que se reescriben **a la vez** que los textos: `main.gd:4397` y `4403` («Se desbloqueó el escenario 2: Sostener el Norte», «Ir a Sostener el Norte (escenario 2)»), `main.gd:4131` y `1061` («Ir a la campaña del norte»), `campaign.gd:270`, y `main.gd:411–414` (`unlocked` del Norte = `won` de Humahuaca); pruebas `test_integration.gd:463, 465, 473, 539–551`, `ui_qa.gd:311, 489–503, 533` y `test_rules.gd:1969`. **Lo menos riesgoso:** que la victoria de la Justina diga «Se desbloqueó el nivel 2: Humahuaca» y conserve una línea «Sostener el norte sigue abierto» hasta certificar. Se decide en R4.

### 4.3 Flags de línea de comandos

| Flag | Efecto |
|---|---|
| `--scenario=humahuaca` | Arranca directo en el briefing, sin mirar el candado |
| `--qa=humahuaca` (+ `--qa-path=<carpeta>` y `--qa-size=WxH`) | `hx.qa_run()`: recorre las 7 vistas canónicas (más las de calibración de albedo, las 4 de límite de cámara y la hoja de fichas) y escribe capturas y `qa_report.json` en `qa_path` (con `APPDATA` aislado y fuera de `evidence/`) |
| `--benchmark=humahuaca` (+ `--quality=baja`, `media` o `alta`) | `hx.benchmark_prepare()` deja el nivel en pleno ataque (lluvia, fx, fichas) y el benchmark mide 30 cuadros de calentamiento y 180 medidos |
| `--hx-seed=N`, `--hx-phase=<fase>`, `--hx-skip-intro` | Los lee el **controlador** (`OS.get_cmdline_user_args()`): fijan semilla, fase inicial y saltan las tarjetas; son para pruebas y capturas |

### 4.4 Herramientas, empaquetado y exportación

| Archivo | Cambio | Cuándo |
|---|---|---|
| `tools/run_qa.py:3` | `--scenario choices` suma `"humahuaca"`; en Windows **no aísla `APPDATA`** (exportarlo antes) | T0 |
| `tools/benchmark.py:14` | `--scenarios` acepta cualquier nombre: sin cambio. La compuerta de cierre corre **dos veces**: `--scenarios justine,norte --max-frame-ms 3` (regresión; no se tocan) y `--scenarios humahuaca --profiles baja,media,alta` con `--max-frame-ms 4` para `media` (presupuestos de cuadro medio: baja ≤ 2,5, media ≤ 4,0, alta ≤ 6,0 ms), más la lectura de `frame_ms_p95_mean` ≤ 8,3 en `resumen.json` | T0 (uso) |
| `tools/ui_qa.gd:38-40`, `tests/test_integration.gd:15-19` | sumar `humahuaca_progress.json` y `humahuaca_checkpoint.json` a la limpieza de perfil (hermeticidad) | T0 |
| `tools/justina_playthrough.gd`, `vis_shots.gd`, `vis_r5.gd`, `bench_gpu.gd` | **protegidos** (específicos de la Justina); el nivel trae las suyas: `humahuaca_playthrough.gd`, `vis_humahuaca.gd`, `ui_qa_humahuaca.gd`, `hx_qa_tour.gd`, `hx_agent_play.gd` | — |
| `tools/build_release.py` | genérico: sin cambio; verificar que el EXE incluye `data/humahuaca_*.json`, `shaders/humahuaca_*`, `assets/models/humahuaca/**` (y que **nada** que el juego lea esté fuera de esas rutas) | [final] |
| `tools/package_release.py:53,70,131`, `tools/test_windows_wine.py:30,61` | la evidencia de Wine pasa de `{justine, norte}` a `{justine, humahuaca, norte}`; README embebido | [final] |
| `.gitignore` | `evidence/humahuaca/*` con la excepción `!evidence/humahuaca/r4/` (toda ronda intermedia queda fuera de Git: r1, r2a, r2b, r3, y cualquier otra), `*.tif`, `evidence/humahuaca/**/_appdata/` | T0 |
| `.gitattributes` | `scripts/humahuaca/** text eol=lf`, `data/humahuaca_*.json text eol=lf`, `shaders/humahuaca_* text eol=lf`, `tests/test_hx_*.gd text eol=lf` (no renormaliza lo existente) | T0 |
| `README.md`, `CLAUDE.md`, `project.godot` (`config/description`, `config/version`), `VERSION.json`, `docs/CONTROLES.md`, `docs/CREDITOS.md`, `docs/ASSETS.md`, `docs/RECONSTRUIR.md`, `docs/historia/*` | «Dos escenarios» → «Tres»; controles; créditos (Copernicus con aviso modificado y frase de no responsabilidad, o SRTM; OpenStreetMap ODbL para el río y declarada también en `map.provenance`); versión | [final] |

`export_presets.cfg:9-10` solo exporta `data/*.json` y excluye `docs/*,tools/*,tests/*,evidence/*,builds/*`: **por eso el relieve es JSON en decímetros** (≈ 90 KB) y no un binario.

## 5. Pruebas nuevas, líneas base y aislamiento

### 5.1 Pruebas del nivel (pisos por ronda: solo pueden subir)

Los números son **pisos anti-desactivación** (detectan una prueba apagada por accidente), **no metas**: contar comprobaciones como progreso fue una de las cosas que no sirvieron en el nivel 1. Lo que cuenta es la **trazabilidad** (`docs/humahuaca/TRAZA.md`: cada exigencia de las secciones 3 a 5 tiene una prueba nombrada que existe, V20) y que, al cierre de R3, el QA rompa a propósito 8 reglas clave en una copia y compruebe que **al menos una prueba falla** por cada una (sanidad por mutación; no es un ítem de la rúbrica).

| Archivo | Dueño | Qué garantiza | Pisos R1 · R2a · R2b en adelante (los de R2b son los de T03 del QA) | Tiempo |
|---|---|---|---|---|
| `tests/test_hx_data.gd` | compuertas y documentos | Esquemas, propiedad de claves, etiquetas, paleta de 24 HEX, jerga, tamaños, historia intacta, grafo de dependencias, trazabilidad (V1–V22 de 2.4, encendidas por ronda) | 40 · 60 · 60 | < 5 s |
| `tests/test_hx_terrain.gd` | relieve_mapa | Los 41 puntos de la lámina 03 (≥ 37 a ≤ 12 m; ninguno a > 20 m), prominencia de la batería 12,0 ± 0,5 sobre su anillo, continuidad ventana–contexto (≤ 0,1 m), conectividad desde cada acceso a cada objetivo, `los` (la plataforma ve sobre tapias de 2,4 m; la torre tiene ángulo muerto de 12 m), cauce más bajo que el núcleo, signo del gradiente oeste → este, curva de 2 960 m en tres bordes, ≥ 2,5 % de celdas con pendiente ≥ 8° y ≥ 3 rasgos verticales con consecuencia (R2a), prueba A/B de fuente, horneado < 300 ms por etapas, `report()` rotula qué es diseño | 60 · 80 · 80 | < 20 s |
| `tests/test_hx_rules.gd` | reglas_historia | Determinismo por semilla; las 9 acciones de R1 y las 20 desde R2a con éxito, rechazo concreto y costo descontado; fases y transiciones; sorpresa, alarma, **oscuridad y desvelo**, torre con cadencia, apoyo, refuerzo con reloj; carga, capacidad, **tratamientos (entregar, destruir, ocultar)**, botín del mundo, puntaje (suma 100); victoria y las 8 causas de derrota con su texto; **`hud_state` en todas las fases**; guardado/carga con ≥ 30 mutaciones rechazadas (**desde R1**); cobertura de las variantes activas; **atlas de rutas**; **cadencia jugable**; **matriz de contrapesos por signo**; 8 estrategias de frente × 24 semillas; **barrido de la señal**; **recetas de extracción**; decisiones significativas por ramificación; rendimiento (`nav_build_ms` ≤ 80, `plan_route_ms` ≤ 30, `tick_ms` ≤ 2); modos `--matrix`, `--human`, `--skip-strategies` | 150 · 250 · 400 | rápido < 60 s; completo ≤ 240 s |
| `tests/test_hx_view.gd` | visual | Construye sin errores de shader ni de parseo; `initial_frame().fits` incluye los 3 objetivos y la zona de partida; picking coherente con el terreno; sin bandera argentina ni torres de 1880–81 (por nombre y por **altura de vértices**: AABB del templo ≤ 8 m); presupuesto de nodos y triángulos; ninguna entidad con color suelto fuera de la paleta; las 7 vistas y sus `must_show`; `set_albedo_mode`; luces; los 3 arquetipos distinguibles en escala de grises a 48 px | 25 · 40 · 40 | < 30 s |
| `tests/test_hx_flow.gd` | ui_feel | Sobre `main.tscn` sin ventana: menú → briefing → apertura → bot que sigue **solo** el «siguiente paso» → desenlace → parte → reintento; guardar/cargar; **jerga = 0**; **≤ 5 controles, ≤ 400 caracteres** al primer cuadro; en R1 el experto gana y el pasivo pierde por la escena real; primera decisión < 60 s | 50 · 80 · 80 | < 60 s |
| `tests/test_hx_smoke.gd` | compuertas y documentos | La prueba de concepto convertida (15 chequeos) + `campaign.json` **no cambia ni un byte** + `GameRules.new_game("humahuaca")` sigue devolviendo `justine` + «Continuar» va al escenario correcto + la Justina arranca después de volver + **5 corridas degradadas** (terreno, reglas, vista, interfaz y progreso reemplazados de a uno por su stub) + **ida y vuelta ×3** (Humahuaca → menú → Justina → menú → Humahuaca) con **igualdad de estado global** (`camera.far`/`fov`, escala 3D y MSAA del viewport, ambiente del `audio_manager`, `settings.last_save`, `content_scale`) y `Performance.OBJECT_ORPHAN_NODE_COUNT = 0` + salida de cada implementación contra los **ejemplos de forma** (3.6) | 25 · 25 · 25 | < 30 s |
| `tools/ui_qa_humahuaca.gd` | ui_feel | Diseño y flujos con entrada inyectada y capturas reales (`--size=WxH`, `--out=` propio). **R1:** completo a 1280 × 720 y chequeo de desborde (ningún panel fuera del viewport, último elemento del menú dentro) a 1920 × 1080 y 2560 × 1440. **Desde R2a:** completo a las tres | 60 en R1 (1280 × 720) · 120 por resolución | 30–60 s c/u |
| `tools/humahuaca_playthrough.gd` | reglas_historia | Sobre la escena real (`--level=scene`) o sin ella (`--level=rules`, headless): políticas de la biblioteca (3.2.5), `--policies=<lista de políticas, o los alias estrategias, extraccion y barrido_senal>`, `--seeds=a-b`, `--attempts=N`, `--replicas=N`, `--out=`, `--measure=decisions`, `--signal-from/--signal-to/--signal-step`; salida `hx_playthrough_v1`; sale con 0 si el experto gana y el pasivo pierde (R1) y, desde R2b, si se cumplen las compuertas 1–9 | — | 2–5 min |
| `tools/hx_qa_tour.gd` | compuertas y documentos | Las 7 vistas canónicas + 3 de calibración de albedo + 4 de límite de cámara + hoja de fichas + `scene_names.txt` + `qa_report.json` (FPS, ms de construcción, desbordes de texto, brecha de decisión, `probes`, victorias de los bots, jerga, controles visibles): **el QA revisa ese paquete y cada hallazgo cita una métrica o una vista** | — | 3–5 min |
| `tools/hx_agent_play.gd` | compuertas y documentos | Arnés del **agente-jugador** (sección 10 del diseño): por turnos, escribe `turno_NN.png`, espera `accion_NN.json` (`clic`, `tecla`, `esperar`), inyecta la entrada como `ui_qa`, avanza con `qa_step` y registra `primera_orden_turno`/`primera_orden_t_s`; **no** expone `qa_state()` ni código al agente | — | 20–40 min por corrida |

**Semillas** (las de calibración son las de la Justina, para poder comparar; el diseño las justifica en su sección 10): **calibración** (para ajustar) **3, 5, 7, 11, 13, 17, 19, 23**; **compuerta** (24 mundos, la misma lista para cada pista y para cada cierre de ronda): validación **29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73** más cierre **101, 103, 107, 109, 113, 127, 131, 137, 139, 149, 151, 157**; **informe** (obediente y torpe, ≥ 100 mundos × 3 intentos): **2001–2120**; **reservadas al QA: 9000–9999** (ninguna pista las usa, las publica ni las ve; la prueba de la rúbrica busca semillas 9xxx en archivos de las pistas). `test_hx_rules` y `humahuaca_playthrough` las usan por defecto y verifican que **cada valor de cada variante activa** (`ACTIVE_DIMS`) aparece en ≥ 2 semillas de calibración y en ≥ 3 de cada mitad de la compuerta (con 3 valores de `refuerzo` y 8 semillas de calibración no alcanza para pedir 3); si `world_from_seed` no lo logra, lo ajusta `reglas_historia`, **no** se cambian las listas. Los intervalos se publican con Wilson al 90 % en `user://hx-balance-results.json`. **La compuerta rápida de una pista corre `test_hx_rules` en modo rápido (sin matriz ni barridos); la matriz, el barrido de la señal, las recetas de extracción, las decisiones significativas y el informe corren en el cierre de ronda (24 mundos para las compuertas, 120 para el informe).**

### 5.2 Líneas base que **no pueden bajar** (commit `5ebbd28`)

| Medida | Comando / origen | Valor |
|---|---|---|
| `tests/test_rules.gd` completo | `--headless --script tests/test_rules.gd` | **871 / 0**, 184 s |
| ídem rápido | `-- --skip-strategies` | **818 / 0**, 44 s |
| `tests/test_integration.gd` | `--headless --script tests/test_integration.gd` | **283 / 0**, 10 s |
| `tests/jev_contract_test.gd` | idem | **15 / 0** |
| `tests/audio_runtime_test.gd` | idem | 17 comprobaciones, **1 falla aceptada** (driver Dummy) |
| `tools/ui_qa.gd` | ventana real, `--size=WxH` | **254 / 0** en 1280 × 720, 1920 × 1080 y 2560 × 1440 |
| `tools/benchmark.py` | `--max-frame-ms 3` para `justine,norte`; `--max-frame-ms 4` para `humahuaca` (perfil `media`) | Justina media **2,71 ms**, Norte media **0,97 ms** (las dos ≤ 3,0 ms); **Humahuaca**: baja ≤ 2,5 · media ≤ 4,0 · alta ≤ 6,0 ms de cuadro medio y p95 ≤ 8,3 ms; construcción ≤ 1 500 ms |
| `tools/justina_playthrough.gd` | escena real | ≥ 3 estilos ganadores, ≥ 2 rutas, ≥ 1 derrota y el bot de interfaz gana |

La **campaña «Sostener el norte» no cambia de reglas**; sus pruebas (`_test_campaign`, `_test_north_pacing`, `_test_norte_snapshot_coherence`, `_test_history_humahuaca_marked` y compañía) siguen verdes. Las pruebas nuevas **suman**; ninguna comprobación existente se borra ni se relaja.

### 5.3 Cómo se corren (Git Bash; **un `APPDATA` por pista y por corrida**)

```sh
G="C:/Users/User/Desktop/spum/IA/Proyectos/MaravillaArgentina/guemes/patria-guemes/.tools/godot/Godot_v4.7.2-stable_win64_console.exe"   # ruta absoluta: los worktrees no tienen .tools
export APPDATA="$TEMP/ap_iso_<pista>"; rm -rf "$APPDATA"; mkdir -p "$APPDATA"
git -C <repo> worktree add -b hx-<pista>-r1 "<ruta absoluta>" main
"$G" --headless --path "<worktree>" --import                                          # ≈ 9 s por worktree nuevo
"$G" --headless --path "<worktree>" --script tests/test_hx_data.gd
"$G" --headless --path "<worktree>" --script tests/test_rules.gd -- --skip-strategies  # ≥ 818
"$G" --headless --path "<worktree>" --script tests/test_integration.gd                 # ≥ 283
"$G" --path "<worktree>" --resolution 1280x720 --audio-driver Dummy --script tools/ui_qa_humahuaca.gd -- --out="<carpeta propia>" --size=1280x720
python tools/benchmark.py --binary "$G" --project . --output "<carpeta propia>" --profiles media --scenarios justine,norte --repeat 3 --renderer forward_plus --max-frame-ms 3      # solo, sin otras corridas en paralelo
python tools/benchmark.py --binary "$G" --project . --output "<carpeta propia>" --profiles media --scenarios humahuaca --repeat 3 --renderer forward_plus --max-frame-ms 4         # ídem; el p95 se lee de resumen.json (≤ 8,3)
```

Reglas de aislamiento: **no** abrir ni imprimir `.env*` ni `jev.cfg`; con `APPDATA` real las suites pisan guardados y el cliente Jev puede consultar la API; lanzar **un comando por tarea** y esperar la línea final del log (si un comando lanza subprocesos con `&`, el aviso de «completado» llega antes de que terminen las pruebas); ninguna prueba escribe en `evidence/` salvo con `--evidence=`/`--out=` explícitos; `treat_warnings_as_errors=false` en `project.godot`: los **warnings no rompen las pruebas**, así que se buscan `SCRIPT ERROR`, `SHADER ERROR`, `Parse Error` y `WARNING` en la salida.

## 6. Reglas de integración

### 6.1 Orden de merge y quién gana

**Merge train por ronda: `relieve_mapa` → `reglas_historia` → `visual` → `ui_feel`** (cada pista consume la API de la anterior). Cada pista trabaja en su worktree y rama (`hx-<pista>-rN`, con N ∈ `1`, `2a`, `2b`, `3`, `4`), **rebasea sobre `main`**, corre la compuerta rápida y pide el merge; el integrador hace `merge --no-ff` por pista («Merge hx-<pista>-rN») y corre la compuerta completa al cerrar la ronda. **Una rama que no pasa la compuerta rápida después del rebase no entra**: la ruta real conserva lo último verde (o el stub), y las pistas siguientes se prueban contra eso (sección 7). Conflictos esperables: **ninguno en código** (propiedad exclusiva por carpeta); posibles en `data/history.json` y en los documentos de «agregar al final» (por eso hay un solo dueño de cada uno). **Dos integradores no se pisan:** el integrador solo hace merges y toca `main.gd`; compuertas y documentos solo toca sus archivos (1.2).

| Conflicto | Gana |
|---|---|
| Un archivo | **su dueño** (sección 1.2); nadie edita archivos ajenos |
| Una clave de JSON | **el dueño del archivo** (V3 lo verifica); las demás pistas piden por escrito |
| Un id de vocabulario | **su dueño** agrega sin pedir permiso; **quitar o renombrar** exige addendum |
| Una firma o semántica del contrato | **el integrador / arquitecto** por addendum; hasta entonces, **manda el texto vigente** |
| Un gancho en `main.gd` | **el integrador** |
| Una tabla de este contrato contra un JSON | el **JSON** desde R2a (se corrige el texto); en R1 manda el texto |
| Una pista depende de otra que aún no entregó | trabaja contra el **stub de esa capa** (sección 7), que existe desde R1.0 |

**Pedidos entre pistas** van al integrador con: id, firma, motivo y prueba de aceptación (`docs/humahuaca/ADDENDA.md`). Una pista **no** pide algo que ya se puede lograr con la API vigente.

### 6.2 Resolución de claves de JSON

Cada clave de primer nivel tiene **un solo dueño** (2.2–2.3). Dentro de su archivo el dueño agrega sub-claves libremente; las demás pistas **no dependen de claves no listadas** (usan la API). Las referencias cruzadas son **por id** (hitos, agrupaciones, objetivos, clases de botín): el registro de ids de hitos es `humahuaca_map.json.landmarks`, y `humahuaca_level.json` los **cita** (no repite sus coordenadas). Si un dueño necesita un id nuevo en el registro, lo agrega él mismo en su archivo **solo si es suyo** (hitos: `relieve_mapa`); si no, lo pide. Cambiar el ancla, la ventana o la grilla sube `map_version` y obliga a regenerar los guardados (un guardado con otro `map_version` se rechaza con motivo).

### 6.3 Commit de andamiaje T0 (= R0; lo hacen el integrador y compuertas y documentos **antes** de abrir los worktrees)

T0 es **corto a propósito**: en el nivel 1 el andamiaje serial fue un cuello de botella, y cinco stubs con ~120 firmas escritos por una sola persona congelaban sus errores. Por eso T0 trae solo lo que **nadie más puede escribir**:

1. Ganchos H1–H9 completos en `main.gd` (con `_hx_make`, la carga con respaldo) y las dos líneas de hermeticidad (4.4).
2. `scripts/humahuaca/humahuaca_vocab.gd` (lo compartido) y los cuatro `vocab_<capa>.gd` con las listas iniciales de 3.0; cada dueño los hereda en R1.0.
3. `scripts/humahuaca/stubs/stub_ui.gd`, la **cáscara del controlador** (≤ 120 líneas: HUD de una línea, pausa y velocidades, Esc al menú, `qa_*` que devuelven valores válidos), copiada a la ruta real `ui/humahuaca_ui.gd`. **Los otros cuatro stubs no se escriben en T0**: son el primer commit de cada dueño (R1.0).
4. Los seis JSON mínimos (`contract: 1`, `map_version: 1`), `humahuaca_height.json` plano con `meta.source: "lamina03_reconstruida"`, el esqueleto de `scenarios.humahuaca`.
5. `tests/test_hx_data.gd` (V1–V5, V7–V9, V17, V19 y V20), `tests/test_hx_smoke.gd` (los 15 chequeos de la prueba de concepto, la ida y vuelta ×3 con la cáscara), `tests/hx_fixtures.gd`, `tools/qa_gate.sh`, los ejemplos de forma (3.6) y `docs/humahuaca/{ADDENDA,BACKLOG,TRAZA,PLAYTEST}.md`.
6. Este contrato y `docs/DISENO_HUMAHUACA.md` (ya commiteados) y la decisión del canal de arte (generador procedural; Blender opcional) anotada en `ADDENDA.md`.
7. **Verificación previa a abrir los worktrees:** compuerta rápida verde (`test_rules --skip-strategies` ≥ 818, `test_integration` ≥ 283, `test_hx_data` y `test_hx_smoke` ok, protegidos intactos contra `5ebbd28`). Recién entonces se crean `hx-relieve`, `hx-reglas`, `hx-visual` y `hx-ui` desde ese commit.

### 6.4 Compuerta (`tools/qa_gate.sh`; la constante `BASE=5ebbd28` está al principio)

**Rápida (cada pista antes de pedir el merge):** (1) `--headless --import`; (2) **protegidos intactos** (`git diff --quiet 5ebbd28 -- <lista de 1.3>`, contra el hash fijo y no contra `main`); (3) `test_rules --skip-strategies` ≥ 818 con `failures: []`; (4) `test_integration` ≥ 283; (5) `test_hx_data` y `test_hx_smoke` (que incluye la ida y vuelta ×3 con igualdad de estado global y cero nodos huérfanos); (6) los `test_hx_*` de la propia pista. **Completa (cierre de ronda, integrador y compuertas):** `test_rules` ≥ 871; `ui_qa` ×3 (≥ 254) y `ui_qa_humahuaca` según la ronda (5.1); `justina_playthrough` y `humahuaca_playthrough` con salida 0 y las compuertas 1–12 de la sección 10 del diseño que correspondan a la ronda; `benchmark.py` en dos corridas (`justine,norte` ≤ 3 ms y `humahuaca` ≤ 4 ms en `media`, más p95 ≤ 8,3); las 7 vistas canónicas; el informe de bots; la corrida del agente-jugador (informativa en R1 y R2a; aprobada desde R2b).

### 6.5 Evidencia y presupuesto de hallazgos

- **Evidencia chica** (el repo ya tiene 3 650 imágenes y 4,1 GB en `evidence/`): `evidence/humahuaca/<ronda>/<pista>/NN_vista_pista_rN.jpg` con **≤ 14 imágenes JPEG de ≤ 300 KB por pista y ronda** más un `metrics_<pista>.json`, cada archivo con una línea de qué prueba. **Solo `r4/` entra a Git** (`.gitignore` ignora toda ronda intermedia; el resto se guarda en `entregas/` o `respaldos/`, fuera del repo); `evidence/humahuaca/` < **60 MB** al cierre. Las capturas son **reales** (Godot sin `--headless`) y **se miran con `Read` una por una** antes de darlas por buenas; el QA no puede revisar centenares.
- **Hallazgos:** ≤ 7 por ronda, con severidad (P0 = BLOQUEA, P1 = ALTA, P2 = MEDIA con tope de 3 y razón escrita; BAJA al backlog), id, evidencia, pista dueña y prueba de aceptación; categorías fijadas en R1; duplicados fusionados; un hallazgo se cierra con evidencia posterior. **Cierre de ronda intermedia: 0 P0 y ≤ 3 P1 listados y fechados** (dueño y ronda en que se cierran). **Cierre final: todos los BLOQUEA y 0 ALTA** (regla de decisión del QA).
- **Ramas y commits:** `hx-<pista>-rN`; commits claros, en español, con el trailer `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`; **sin push, sin release, sin `--force`, sin borrar historial, sin etiquetas nuevas** (`git tag --list` queda en `v0.1.0`). El integrador borra las ramas `hx-*` al integrar (hay ≈ 39 ramas locales de rondas anteriores que no se tocan). No tocar `.claude/worktrees/` viejos (uno figura *locked*).

## 7. Stubs mínimos y degradación elegante

**Principio:** una pista que falla no puede dejar el nivel sin arrancar ni bloquear a las demás. Hay tres redes, de adentro hacia afuera:

1. **El stub de cada capa es el primer commit de su dueño (R1.0)**: lo escribe quien conoce esa API, no una sola persona para las cuatro; queda **congelado** desde el merge de R1.0 (se corrige solo por addendum) y **no depende del código real** de la pista. Cumple la firma completa de la sección 3 con valores válidos y la forma de los ejemplos de 3.6. La cáscara de la interfaz (`stub_ui.gd`) la escribe el integrador en T0.
2. **El controlador carga cada clase real por `load()` con `ResourceLoader.exists`** y, si falta o no parsea, usa el stub de `scripts/humahuaca/stubs/` y muestra **una línea roja** («Falta o falló la vista: se usa la versión mínima») sin impedir volver al menú; `start(opts.force_stub)` fuerza el reemplazo (lo usa `test_hx_smoke`). La propia carga del controlador tiene su respaldo en `main.gd` (`_hx_make`, 4.1).
3. **El integrador no fusiona una rama que no pasa la compuerta rápida.** «Una pista falla en R1» equivale a «su merge no entra esta ronda»: la ruta real conserva lo último verde (o el stub), las demás ramas entran igual y se prueban contra el stub de la que falta. El informe del QA dice qué capa corre en respaldo (p. ej. «capa en respaldo: visual») y eso es un P0 de esa pista para la ronda siguiente.

| Stub (quién lo escribe, cuándo) | Garantiza (mínimo) |
|---|---|
| `stub_terrain.gd` (`relieve_mapa`, R1.0) | Terreno plano a +17 m con los hitos obligatorios de 2.2; **lee `humahuaca_level.json` y respeta tapias, zanjas y zonas con rasterizado simple** (para que las reglas se calibren desde R1 contra muros y no contra un plano vacío); `height_at`, `surface_at`, `is_blocked`, `speed_factor_at`, `los`, `landmark(s)`, `features`, `heightfield`, `nav_grid`, `minimap_image` (un color) y `report()` válidos |
| `stub_rules.gd` (`reglas_historia`, R1.0) | 5 unidades, 3 objetivos, reloj con fases, `hud_state` y `render_state` con todas las claves de los ejemplos de 3.6, una victoria alcanzable (tomar los tres frentes con `attack` y salir) y una derrota (`amanecio`), `snapshot/save/load/validate/restore_snapshot` básicos |
| `stub_progress.gd` (`reglas_historia`, R1.0) | Semilla fija, intentos, `record_result` mínimo, sin diario |
| `stub_view.gd` (`visual`, R1.0) | Plano de terreno, cajas con la huella de cada hito, una ficha por agrupación, luz, `initial_frame` que incluye los tres objetivos, picking y `get_minimap_texture` |
| `stub_ui.gd` (integrador, T0) | HUD de una línea, pausa y velocidades, parte mínimo, Esc al menú y `qa_*` válidos (la cáscara) |

`test_hx_smoke` corre **cada combinación degradada** (terrain, rules, view, ui y progress reemplazados por su stub, de a una) y exige que el nivel arranque, avance y vuelva al menú. Las pistas prueban contra los stubs de las demás con `tests/hx_fixtures.gd` (construye una instancia de stub de cada vecina) para que **sus pruebas no dependan de que otra pista haya entregado**. **Lo que cada pista entrega en R1.0, R1, R2a, R2b, R3 y R4 está en la sección 8.**

## 8. Plan de rondas: qué entrega cada pista

**Rondas:** R0 (T0, 6.3) → **R1.0** (stubs primero, ≤ 1 h) → **R1** (corte vertical mínimo) → **R2a** (núcleo legible) → **R2b** (profundidad y contrapesos) → **R3** (pulido y verificación) → **R4** (cierre y certificación). El diseño (sección 14) dice qué se juega en cada una; esta sección dice **qué entrega cada pista**, para que el integrador pueda fusionar y cerrar la ronda aunque una de ellas se atrase (la que falte corre en respaldo; sección 7). **Reglas del plan:** (a) una ronda cierra con la compuerta completa (6.4), la tabla de estado de la rúbrica del QA y **0 P0 y ≤ 3 P1 listados y fechados**; (b) lo que no entra se descarta en el **orden de descarte** del diseño (sección 14) y se anota en `BACKLOG.md` con su ronda; (c) **nunca se descarta** el ciclo completo jugable, el relieve (plan B), las siete vistas canónicas, las etiquetas honestas, la compuerta de regresión de la Justina y el Norte ni la corrida del agente-jugador; (d) los pisos de pruebas por ronda están en 5.1 y los ítems de la rúbrica que se exigen por ronda, en la escalera de `QA_NIVEL2.md`.

### 8.1 R1.0 · stubs primero (primer commit de cada pista, en paralelo)

| Pista | Entrega | Se verifica con |
|---|---|---|
| `relieve_mapa` | `stubs/stub_terrain.gd`, `terrain/vocab_terrain.gd`, `humahuaca_map.json` mínimo con los 21 hitos con `tag` y `source` | `test_hx_data` y las corridas degradadas |
| `reglas_historia` | `stubs/stub_rules.gd` y `stub_progress.gd`, `rules/vocab_rules.gd`, `humahuaca_rules.json` y `humahuaca_level.json` mínimos (≥ 12 tapias, ≥ 4 zanjas, zonas, accesos, 3 luces) | ídem + formas de 3.6 |
| `visual` | `stubs/stub_view.gd`, `view/vocab_view.gd`, `humahuaca_visual.json` con la paleta de 24 HEX, las 7 vistas con su `must_show` (borrador) y `initial_frame` | ídem |
| `ui_feel` | `ui/humahuaca_ui.gd` (primera versión del controlador, con carga con respaldo de las otras capas), `ui/vocab_ui.gd`, `humahuaca_ui.json` mínimo (lista negra con siglas y palabras, textos del briefing) | ídem |
| integrador / compuertas | Fusiona en el orden del tren, corre la compuerta y reparte el resultado; las pistas rebasean y siguen con R1 | compuerta rápida verde |

### 8.2 R1 · corte vertical mínimo (jugable de punta a punta, en caja gris con relieve real)

| Pista | Entrega |
|---|---|
| `relieve_mapa` | API **completa** de `HumahuacaTerrain` devolviendo valores válidos sobre el plan B (grilla de 4 m, Catmull-Rom, domo como residuo, plataforma, quebraditas, cauce, micro-relieve); `humahuaca_map.json` v1 (hitos con etiqueta, río ≥ 14 puntos, superficies); `tools/build_humahuaca_terrain.py --source lamina03`; `nav_grid`, `los` e `is_blocked` leyendo `humahuaca_level.json`; `test_hx_terrain` (41 puntos, continuidad, conectividad, horneado < 300 ms) |
| `reglas_historia` | El **bucle completo** con **mundo fijo**: **9 acciones**; geometría toda conocida; torre como temporizador de 90 s; botín en **5 clases**; oscuridad, desvelo y señal; sorpresa y alarma; refuerzo como temporizador; victoria y las 8 causas con su texto; `hud_state` y `render_state` completos; `HumahuacaProgress` mínimo; **guardado y carga con `validate_snapshot` (≥ 30 mutaciones rechazadas)**; `humahuaca_policies.gd` con **`experto` (gana) y `pasivo` (pierde)**; `humahuaca_playthrough.gd` (reglas y escena) con salida `hx_playthrough_v1`; `humahuaca_level.json` v1; `test_hx_rules` (150) |
| `visual` | Terreno con shader y malla continua (ventana → contexto → horizonte); hitos como cajas con la huella correcta; **templo y 3 arquetipos de figura por el generador procedural con el render héroe aprobado**; fichas con silueta; luz de noche/alba/día con lluvia; **luces** de los tres objetivos; las vistas **`juego_noche` y `juego_alba`** (arte provisional, legibles); `initial_frame`; `build()` sin errores de shader; cuadro medio en `media` ≤ 4,0 ms; `test_hx_view` (25) |
| `ui_feel` | HUD con objetivo y «siguiente paso», pausa y ×1/×2/×4 siempre visibles, **apertura de 12–15 s**, órdenes por clic derecho y por teclas para las 9 acciones, parte de derrota y de victoria, reintento, menú de tres botones (Humahuaca siempre habilitado), `qa_state/qa_set_camera/qa_set_time/qa_run/qa_step`; `ui_qa_humahuaca` (completo a 1280 × 720 y desborde a las otras dos); `test_hx_flow` (50) |
| integrador / compuertas | `hx_qa_tour.gd` (vistas, calibración y `qa_report.json`), **`hx_agent_play.gd`** y la primera corrida del agente-jugador (informativa); el **mini-playtest humano** de 10 min (si hay quien juegue); la **captura de la cámara inicial en caja gris al usuario** con el sí o no; compuerta completa; tabla de estado del QA |

**Cierre de R1:** el experto gana y el pasivo pierde por la escena real; los 41 puntos de la lámina; guardado y carga; cero `SCRIPT ERROR`/`SHADER ERROR`; **0 P0 y ≤ 3 P1 listados y fechados**.

### 8.3 R2a · núcleo legible

| Pista | Entrega |
|---|---|
| `relieve_mapa` | Rasgos verticales (barranca, terraza, banco de grava) y explanadas; ≥ 2,5 % de celdas con pendiente ≥ 8° y ≥ 3 rasgos con consecuencia; prueba A/B de fuente (con una fuente sintética hasta que llegue la tesela); `RELIEVE.md`; `test_hx_terrain` (80) |
| `reglas_historia` | Las **20 acciones**; la doble capa «lo que sabés / lo real» y el reconocimiento con riesgo; torre con **cadencia, anillo de recarga y las cuatro respuestas**; apoyo y piezas; las **9 clases de botín**, los tres tratamientos, el botín del mundo y el epílogo por piezas; eventos del guion y microescenas; atlas de rutas (compuerta 10) y cadencia jugable (compuerta 11); luces y fogatas; `humahuaca_level.json` completo (portillos, barricadas, patios, escondites); políticas `aleatorio` (la usa T08), `obediente`, `torpe` y las `est_*` iniciales; `test_hx_rules` (250) |
| `visual` | **Las dos vistas de juego con arte final** (V06); templo y arquetipos finales; tapias, zanjas, portillos y torre; núcleo de casas; fx (humo, fogonazo, impacto); `set_albedo_mode` y `probes`; micro-relieve y anillo de contenido; presupuestos por perfil; `test_hx_view` (40) |
| `ui_feel` | Barra de acciones contextual con las 20, vista previa de ruta y de reconocimiento, alertas de a una, decisión con reloj, señal y torre en el HUD, minimapa con brújula y escala, rótulos de hitos, doble pulsación de 1–3, botón «?»; `ui_qa_humahuaca` completo a las tres resoluciones (≥ 120 por resolución); `test_hx_flow` (80) |
| integrador / compuertas | `hx_qa_tour` completo (7 vistas, albedo, límites, hoja de fichas, `probes`); `test_hx_data` (60); corrida del agente-jugador (informativa) |

### 8.4 R2b · profundidad y contrapesos

| Pista | Entrega |
|---|---|
| `relieve_mapa` | Ajustes por los hallazgos de R2a; mapa de rutas publicado; fuente definitiva si llegó la tesela; `test_hx_terrain` (80) |
| `reglas_historia` | **Variantes de 3 dimensiones (12 mundos)** y la matriz de contrapesos por signo; `HumahuacaProgress` completo (diario con marcas «anotado», dos puntos de control, ayudas, medallas, reintento); la biblioteca de políticas completa (obediente, torpe, los 4 ciegos, «pausa y reanuda», las 8 estrategias de frente, las 5 recetas de extracción y `barrido_senal`); decisiones significativas por ramificación; compuertas 1–9 y 12; `test_hx_rules` (400) |
| `visual` | Las demás vistas canónicas con arte final; vegetación (churqui, cardón, sauce); viviendas y recipientes; sonido de avisos y de la descarga; métricas de V06 en las siete vistas; `test_hx_view` (40) |
| `ui_feel` | Diario, parte con consejos que rotan, ayudas visibles y marcadas, puntos de control, selección por caja con Shift/Ctrl, minimapa grande (M), jerga en cero, `key_table` y `CONTROLES.md`; `test_hx_flow` (80) |
| integrador / compuertas | **Agente-jugador aprobado** (J08) y mini-playtest humano; `TRAZA.md` completa |

### 8.5 R3 · pulido y verificación

| Pista | Entrega |
|---|---|
| `relieve_mapa` | Retoques finales; prueba A/B con Copernicus si la tesela llegó; `CREDITOS_RELIEVE.md` |
| `reglas_historia` | Balance por **contenido**; informe de 120 mundos (obediente y torpe); prueba de inversión de una cuarta dimensión; textos finales y epílogo con el tiempo comprimido; `REGLAS.md`, `HISTORIA.md`, `PROCEDENCIA.md` y la matriz histórica |
| `visual` | Pulido con las métricas del QA (albedo, bordes, ΔL\*, correlación), sonido completo, rendimiento por perfil, `CREDITOS_VISUAL.md` y `ASSETS.md` |
| `ui_feel` | Tutorial de 6 pasos, ayuda F1 completa, accesibilidad (contraste, no solo color), textos finales |
| integrador / compuertas | Evidencia final; sanidad por mutación con el QA (8 reglas rotas a propósito; cada una hace fallar ≥ 1 prueba); README, CLAUDE.md, VERSION y créditos preparados |

### 8.6 R4 · cierre y certificación

Ninguna pista agrega contenido: corrigen la **lista cerrada** de hallazgos. El integrador arma el EXE desde el commit certificado (SHA-256, `verify_embedded_version`), concatena `docs/CREDITOS.md` y cierra README, CLAUDE.md y VERSION; decide D1b. El QA corre la **triple certificación** sobre un único commit. **Opcional y aparte:** la sesión humana de 20 min (anexo E del QA).

---

## Anexo. Revisiones y pendientes del contrato

- **1.0 (1-nov-2026):** versión inicial. Decisiones tomadas: D1a (Humahuaca y Norte se abren con la Justina), D2 (relieve en JSON de decímetros), D3 (cinco etiquetas), D4 (sin Jev en el MVP), D6 (mundo fijo hasta ganar), D7 (coordinación de cinco agrupaciones), D8 (fase en vez de hora), D9 (`tree_algarrobo` no tal cual), D10 (sin Blender salvo que R2 lo justifique).
- **1.1 (1-nov-2026, revisión final del arquitecto antes de escribir código; resuelve las objeciones del crítico, ver «Objeciones y decisiones» en `DISENO_HUMAHUACA.md`).** Cambios: **D1c** (Humahuaca siempre habilitado con la nota «Recomendado tras la Justina»; el Norte conserva su candado); **D11** (canal de arte: generador procedural por defecto, Blender opcional; el render héroe se aprueba al cierre de R1); **D12** (seis JSON: el diseño de nivel pasa a `humahuaca_level.json`, de `reglas_historia`; una sola fuente por número de juego); **D13** (los stubs los escribe cada dueño en R1.0; T0 queda corto; vocabulario por dueño, solo-agregar; regla de dependencia hacia abajo con prueba de grafo); **D14** (presupuestos de cuadro por perfil: baja 2,5, media 4,0, alta 6,0 ms y p95 8,3; Justina y Norte siguen en 3,0); **D15** (la señal tiene contrapeso: oscuridad y desvelo; la tabla del botín cambia: destruir ×0,35, ocultar ×0,7 a salvo, botín del mundo); **D16** (variantes: 3 dimensiones activas, 12 mundos de combate; matriz de contrapesos); **D17** (la gola de la batería mira al este); **D18** (balance: compuertas de extremos y de signo; obediente y torpe son informe; decisiones significativas por ramificación); **D19** (agente-jugador por la interfaz real y mini-playtests humanos no bloqueantes; «presentable» en dos etapas); **D20** (plan de rondas con R1.0, R2a y R2b). Nuevo: sección 8 (plan de rondas por pista), 3.6 (ejemplos de forma), 3.2.5 (biblioteca de políticas), V19–V22. La comparación de protegidos usa el hash `5ebbd28`.
- **Abiertos (no bloquean R0 ni R1):** permiso de la tesela Copernicus S24 (plan A) y de Blender (opcional); sí o no del usuario a la captura de R1; llegada de la lámina 04 y de la tabla de 23 elementos (cambiarían posiciones por addendum con `map_version + 1`); decisión D1b (se toma en R4); álamos rotulados «diseño»; quién hace los mini-playtests y la sesión humana de 20 minutos; el fondo del menú sigue siendo el mundo de la Justina (decisión de `ui_feel` en R3, no bloquea nada).
- **Riesgos conocidos del contrato:** (1) los números de línea de `main.gd` se corren si alguien lo toca antes de T0; (2) `data/history.json` puede romper pruebas del Norte si se edita lo existente (V17 lo detecta); (3) el menú con tres botones solo se midió a 1280 × 720 (`test_hx_smoke` y `ui_qa` lo miden en las tres resoluciones); (4) la Justina no usa Jev (solo el Norte): la forma `enemy_*` se copia del Norte; (5) los guardados de la Justina y del Norte no se migran ni se tocan; (6) la biblioteca de políticas es una sola y la escribe `reglas_historia`: si falla, caen a la vez las reglas, las herramientas y la interfaz de prueba (por eso `stub_rules` es jugable); (7) la ramificación de decisiones y el barrido de la señal cuestan minutos y corren solo al cierre de ronda.
