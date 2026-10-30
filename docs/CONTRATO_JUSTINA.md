# Contrato entre pistas: escenario Justina rediseñado

Versión del contrato: **1** (2026-10-29). Complementa `docs/DISENO_JUSTINA.md` (qué se juega) y `data/justina_map.json` (todos los números). Tres pistas trabajan en paralelo y **cada una toca solo sus archivos**:

| Pista | Archivos que puede modificar |
|---|---|
| **Reglas** | `scripts/game_rules.gd`, `tests/test_rules.gd`, `docs/DISENO_REGLAS.md` |
| **Vista** | `scripts/world_view.gd`, `assets/**`, `tools/create_models.py` |
| **UI** | `scripts/main.gd`, `tools/ui_qa.gd`, `tests/test_integration.gd` |

Nadie edita `data/justina_map.json` ni este contrato: si hace falta un campo, se pide al arquitecto/orquestador y se versiona (`map_version`, "Versión del contrato"). El escenario **Norte** no cambia en esta ronda: sus métodos, estado y tests siguen igual (`issue_campaign_order`, `resolve_round`, etc.).

## 0. Convenciones

- Coordenadas del mundo = metros. `+x` es este (el río), `+z` es sur, **norte = `-z`**. En 3D de Godot el vector de posición es `Vector3(x, altura, z)`: el mundo de reglas `(x, z)` es el plano XZ y la altura Y es la **elevación en metros sobre el cero de bajante** (la misma del JSON). 1 unidad Godot = 1 m.
- Un punto de trayecto es `{"x": float, "z": float}`. Un parámetro de punto es `Vector2(x, z)`.
- Identificador interno del escenario: **`"justine"`** (no cambia). El texto visible dice **Justina**.
- Etiquetas de fuente (`tag`): `"documentado"`, `"tradicion"`, `"reconstruccion"`, `"diseno"`. Definición visual (glifo, color) en `map.source_tags`; la UI y la Vista las leen de ahí.
- Ninguna pista copia cifras del JSON. Se leen con `rules.map_data()`.
- Todo lo que devuelve Reglas es JSON-serializable o copia: la Vista y la UI **no mutan** `rules.state`.
- Errores de órdenes: `{"ok": false, "reason": String}` en español, con la causa concreta (como hoy).

## 1. Reglas (`scripts/game_rules.gd`)

### 1.1 Constantes y carga

```gdscript
const JUSTINE_SAVE_VERSION := 2      # SAVE_VERSION (=1) sigue siendo el del Norte
const MAP_PATH := "res://data/justina_map.json"
```

Se **eliminan** `SHIP`, `BOARD_POINT`, `RISE_START`, `RISE_DURATION` y la lista fija de obstáculos. Se mantienen `STEP := 0.25`, `MAX_ROUNDS`, `DATES`, `CAMPAIGN_ACTIONS`, `RETREAT_*`, `SALTA_*` (Norte).

```gdscript
func map_data() -> Dictionary      # JSON parseado y validado una vez; cacheado; {} si falta o es inválido (push_error)
func map_size() -> Vector2         # (w, h) = (900, 520)
func board_point() -> Vector2      # ship.capture.boarding_point = (548, 262)
func ship_position() -> Vector2    # (580, 262)
```

`new_game("justine", seed)` carga el mapa, crea el estado de 1.2 y emite el evento `objective` con `texts.objective`. `new_game("norte", ...)` no cambia.

### 1.2 Estado `justine` (schema_version = 2)

Se mantienen los campos comunes de hoy (`schema_version, game_id, state_version, scenario, seed, rng_state, elapsed, accumulator, status, reason, round(=1), units, log, orders, external_decisions, first_order_at`). Para Justina `schema_version` vale **2**. Un guardado de Justina con versión 1 se rechaza con *"Este guardado es de una versión anterior del escenario Justina y no es compatible."* Los guardados del Norte siguen en versión 1.

Campos propios (todos nuevos o redefinidos):

| Campo | Tipo / rango | Notas |
|---|---|---|
| `map_id` | `"justina"` | |
| `map_version` | int = `map_data().map_version` | un guardado con otra versión se rechaza |
| `water_level_m` | float 0..1.65 | nivel real, **fuente de verdad** |
| `water_level` | float 0.05..0.95 | derivado: `0.05 + 0.9 * water_level_m / 1.65` (compat con el shader viejo y la UI vieja) |
| `tide_phase` | `"alta"\|"bajando"\|"baja"\|"subiendo"` | `alta` t<45; `bajando` 45≤t<375; `baja` 375≤t<645; `subiendo` t≥645 |
| `capture` | float 0..100 | |
| `crew_morale` | float 0..100 | |
| `next_volley` | float | segundo de la próxima descarga |
| `deadline` | float = 900 | `time.deadline_s` |
| `bajante_announced`, `rising_announced` | bool | |
| `ammo` | int 0..`ammo_max` | |
| `ammo_max` | int | del JSON |
| `balizas` | int ≥ 0 | |
| `volunteers_pool` | float ≥ 0 | |
| `advance_authorized` | bool | `true` tras `signal_liniers` |
| `fire_support` | `{"until": float, "ready_at": float}` | `until` > elapsed mientras está activo; `ready_at` = elapsed mínimo de la próxima |
| `probes` | Array de sondas (abajo) | |
| `scouts` | Array de 2 exploradores (abajo) | ids `scout_1`, `scout_2` |
| `hazards_found` | Array de ids (`"pozo_central"`) | |
| `fords_found` | Array de ids (`"vado_sur"`) | |
| `stats` | Dictionary (abajo) | alimenta el parte |
| `historical_note` | String = `texts.historical_note` | |
| `briefing` | String = `texts.briefing` | nuevo; la UI lo muestra al empezar |

Se **elimina** `obstacles` del estado (los obstáculos están en el mapa).

**Sonda** (`probes[i]`): `{"id": "p1", "kind": "lane"|"marked", "pts": [{"x","z"},...], "width": float, "t": float, "scout": "scout_1"}`. `width` es 6 (`lane`) o 16 (`marked`). Los puntos están dentro del mapa. Un punto del mundo es **conocido** si está a ≤ `width/2` de algún segmento de alguna sonda.

**Explorador** (`scouts[i]`): `{"id", "name", "x", "z", "hp": int 0..3, "stage": "idle"|"moving"|"probing"|"marking"|"lost", "order": {} | {"action": "probe"|"mark_ford", "points": [{"x","z"},...]}, "path": [{"x","z"}], "work_remaining": float}`. Un explorador con `hp==0` pasa a `lost`, queda en su lugar y no recibe órdenes.

**Estadísticas** (`stats`): `{"start_strength": {"guemes","arias","zavala"}, "shots_taken": int, "damage_taken": float, "stumbles": int, "probe_m": float, "marked_m": float, "ammo_used": int, "balizas_used": int, "fire_support_uses": int, "muster_gain": float, "scouts_lost": int, "exposure_s": {"central": float, "sur": float, "otra": float}, "boarded_at": float (-1 si nunca), "level_at_boarding": float (-1), "first_water_entry_at": float (-1)}`. `exposure_s[k]` acumula `exposure * dt` por unidad en cada banco (k según el banco/vado donde está, `otra` en cualquier otro punto de agua en alcance).

**Unidades** (`state.units`, siempre 3: `guemes`, `arias`, `zavala`). Campos actuales (`id,name,x,z,strength,fatigue,supply,mounted,stage,order,path,sector_id,dismount_remaining,revealed_until,blocked_until`) más:

| Campo | Tipo | Notas |
|---|---|---|
| `pace` | `"walk"\|"trot"\|"gallop"` | por defecto `trot`; desmontado fuerza `walk` |
| `work` | `{}` o `{"kind": "muster"\|"resupply"\|"signal", "remaining": float}` | trabajo en curso en un hito |
| `stumble_remaining` | float 0..20 | |
| `tag` | String | etiqueta de fuente del grupo (del JSON) |

`name` y `x,z,strength` iniciales salen de `map.groups`. `supply` y `revealed_until`, `sector_id` se conservan sin uso en Justina (`sector_id == ""`).

`unit.stage` en Justina: `ready, moving, working, stumbling, rally, blocked, dismounting, boarding, routed`. Desaparece `waiting_tide` (la espera la decide el jugador). `ordered` queda solo para el Norte. `unit.order.action` en Justina: `move, board, rally, withdraw, muster, resupply, signal_liniers`, más `x, z` del destino (salvo `rally`).

**Eventos / log**: igual que hoy (`{time, round, text, kind}`) y opcionalmente `pos: {x,z}` y `tag: String` y `unit: String`. `kind` válidos de Justina: `objective, tide, warning, shot, boarding, recon, ford, stumble, muster, ammo, signal, fire_support, victory, defeat, load, info`.

### 1.3 Terreno, conocimiento y velocidad (lectura, sin efectos)

Existe **una sola implementación** del fondo (la Vista la llama; no la duplica).

```gdscript
func terrain_height_at(x: float, z: float) -> float        # elevación REAL del suelo/fondo, m sobre el cero de bajante
func water_level_m() -> float
func water_depth_at(x: float, z: float) -> float           # REAL: water_level_m - terrain_height_at. Negativo = emergido (altura sobre el agua = -valor)
func knowledge_at(x: float, z: float) -> String            # "visible" | "probed" | "marked" | "unknown"
func perceived_height_at(x: float, z: float) -> float      # lo que el jugador cree: real si knowledge != "unknown"; si no, ver 1.3.2
func perceived_depth_at(x: float, z: float) -> float
func terrain_kind_at(x: float, z: float) -> String         # REAL: "meseta"|"barranca"|"bajada"|"firme"|"barro"|"somera"|"agua"|"honda"|"obstaculo"|"casco"
func speed_at(x: float, z: float, pace: String, mounted: bool) -> float   # m/s REAL; 0 = intransitable
func is_walkable(x: float, z: float, mounted: bool = true) -> bool        # REAL; firma ampliada, compatible con la llamada vieja
func exposure_at(x: float, z: float) -> float              # 0..1 por rumbo/alcance; incluye fire_support activo
func exposure_for(u: Dictionary) -> float                  # como hoy, usando exposure_at y la etapa (desmontando/abordando => ×0.3)
```

#### 1.3.1 Algoritmo de `terrain_height_at` (fuente de verdad)

1. `crest_x(z)`, `toe_x(z)`, `crest_h(z)` se interpolan linealmente por `z` sobre `barranca.crest`, `barranca.toe`, `crest_height_m`.
2. `x <= crest_x(z)` → `crest_h(z)` (meseta).
3. `crest_x < x < toe_x` → `lerp(crest_h, toe_elevation_m, smoothstep(t))` con `t = (x - crest_x) / (toe_x - crest_x)`.
4. `x >= toe_x` → se parte de `bed_profile.points_x_elev` interpolado linealmente por `x` y se aplican, **en este orden**, las capas del JSON:
   - `banks` (modo *max*): `e = lerp(e, top_m, w)` solo si `top_m > e`.
   - `channels` (modo *set*): `e = lerp(e, bed_m, w)`.
   - `fords` (modo *max*): ídem bancos. Cada vado usa `centerline`+`half_width_m` o `center`+`radius_m`.
   - `hazards` (modo *set*): `e = lerp(e, bed_m, w)` con `blend=4`.
   - `hull` (modo *set*): `e = lerp(e, bed_m, w)` en `center`/`radius_m`.
   - Peso `w = 1 - smoothstep(d_borde, d_borde + blend, d)` con `d` = distancia al eje (segmento más cercano) o al centro, y `d_borde` = `half_width_m` o `radius_m`. Con `d <= d_borde` el peso es 1.
5. Los valores de referencia (ya calculados sobre el JSON por el arquitecto; ±0,02 m) son: `(548,262)=-1.0`, `(580,262)=-1.5`, `(415,264)=-1.9`, `(415,290)=-0.34`, `(330,264)=-0.25`, `(450,376)=-0.83`, `(314,400)=-0.9`, `(304,350)=-2.0`. Reglas debe incluirlos en su test.

#### 1.3.2 Conocimiento

- `visible`: `water_depth_at(x,z) <= knowledge.visibility_depth_m` (0,3 m). Cuenta el suelo emergido y el fondo muy somero. En tierra (x < `toe_x`) todo es `visible`.
- `probed`: dentro de una sonda `lane`. `marked`: dentro de una sonda `marked`. (`marked` gana a `probed`.)
- `unknown`: el resto.
- `perceived_height_at` para `unknown`: la elevación **solo del perfil base** (sin capas) `+ knowledge.unknown_optimism_m` (0,5 m).

#### 1.3.3 Velocidad (`speed_at`)

Con `h = -water_depth_at` (altura sobre el agua), `d = water_depth_at` (profundidad), valores de `movement` del JSON:

1. `terrain_kind_at` en `meseta|obstaculo|casco` → 0. `barranca` → 0 (salvo `bajada`).
2. `v_pace = paces_mps[pace]`; si no `mounted`, `v_pace = min(v_pace, 1.3)`.
3. `bajada` (zona de las rampas): `v_pace * ramp_speed_factor`.
4. `d <= 0` y `h >= 0.6` → `firme`: `v_pace`. (El galope solo vale en `firme`; en cualquier otro tipo, `min(v_pace, trot)`.)
5. `d <= 0` y `h < 0.6` → `barro`: `min(v_pace, lerp(1.0, 1.5, h / 0.6))`.
6. `0 < d <= 0.6` → `somera`: `min(v_pace, mounted ? 2.0 : 1.0)`.
7. `0.6 < d <= limite` (limite = 1.3 montado, 1.2 a pie) → `agua`: `min(v_pace, 0.8)`.
8. `d > limite` → `honda`: **0**.
9. Si el punto está dentro de una sonda `lane` pero no `marked` y el grupo avanza en columna: `× column_unmarked_lane_factor` (0,75).

Las velocidades de un grupo **nunca** superan este resultado en ningún paso del `tick`.

### 1.4 Tiempo y río

```gdscript
func tide_at(t: float) -> Dictionary        # {"level_m": float, "level_norm": float, "phase": String}
func tide_marks() -> Dictionary             # {"drop_start","drop_end","low_hold_end","rise_end","deadline"}
func ford_window(x: float, z: float, mounted: bool = true) -> Dictionary
# {"known": bool, "certain": bool, "opens_at": float, "closes_at": float, "depth_at_low_m": float}
# opens_at/closes_at: instantes en que la profundidad (percibida si knowledge=="unknown", real si no) baja/sube del límite; -1 si nunca abre.
# certain = knowledge_at(x,z) != "unknown".
```

`tick(dt)` y `_justine_step(STEP)`: igual estructura que hoy (acumulador, paso fijo 0,25 s, `dt` máx 60 por llamada). Cada paso: actualiza río, mueve grupos y exploradores, trabajos (`work`), tropiezos, descarga del buque cada `ship.fire.volley_interval_s` (+2 s si hay apoyo de fuego activo), captura, victoria/derrota, `state_version += 1`.

### 1.5 Planificación y órdenes de grupo

```gdscript
func plan_route(group_id: String, target: Vector2, pace: String = "trot", opts: Dictionary = {}) -> Dictionary
```
Sin efectos. `opts.waypoints: Array` de `Vector2` (hasta 4) intermedios en orden. Devuelve:

```
{"ok": bool, "reason": String,
 "path": [{"x","z"},...],        # puntos de giro (suavizados), no una celda por 4 m
 "length_m": float,
 "eta_s": float,                 # con velocidades de speed_at PERCIBIDAS en el nivel de cada instante estimado
 "unknown_m": float,             # metros de ruta sobre knowledge "unknown" Y con agua (profundidad percibida > 0)
 "exposed_s": float,             # segundos estimados dentro del alcance del buque, ponderados por exposure_at
 "max_depth_m": float,           # máxima profundidad percibida a lo largo de la ruta
 "arrives_in_window": bool,      # true si, para el vado del buque, eta cae dentro de ford_window(...).opens_at..closes_at
 "risk": "bajo"|"medio"|"alto"|"desconocido",
 "warnings": [String]}
```
- `risk`: `bajo` si `unknown_m == 0` y no hay punto con profundidad percibida > 0,6·límite; `medio` si `unknown_m <= 80`; `alto` si `unknown_m > 80`; `desconocido` si el destino mismo es `unknown` y en agua.
- Planifica con el conocimiento del jugador (`perceived_*`); **ejecuta** con el fondo real. Una celda `unknown` con agua cuesta ×1,0 y una conocida ×0,8 (el planificador prefiere lo reconocido). Si la ruta pasa donde el fondo real supera el límite, el grupo **tropieza** (1.7).
- Cuadrícula A*: celdas de 4 m en el rectángulo `(0,0)-(w,h)`, pesos por `1 / speed_at_percibida`. Se reconstruye cuando cambia el nivel (cuantizado a 0,05 m) o cambia `probes`. Presupuesto: construir ≤ 80 ms, `plan_route` ≤ 30 ms, `tick` ≤ 2 ms medios (medidos por Reglas en su test, no asumidos).

```gdscript
func issue_order(group_id: String, action: String, target: Vector2 = Vector2.ZERO, opts: Dictionary = {}) -> Dictionary
```
`opts`: `{"pace": "walk"|"trot"|"gallop", "waypoints": [Vector2,...]}`. Acciones de grupo: `move, board, rally, withdraw, muster, resupply, signal_liniers, cancel`. Comportamiento y rechazos (mensajes concretos):

| `action` | Efecto | Rechazos principales |
|---|---|---|
| `move` | traza `plan_route` y mueve; guarda `u.pace` | destino fuera del mapa/obstáculo/`honda` conocida; grupo disperso; ruta imposible |
| `board` | como `move` a `board_point()` + al llegar `dismounting` (12 s) → `boarding` | **sin `advance_authorized`**: *"Falta la orden de avance de Liniers: señalá primero."*; `plan_route` imposible |
| `rally` | `stage="rally"`; si está fuera de la playa seca o dentro del alcance del buque: rechaza | |
| `withdraw` | ruta a la playa seca más cercana (x ≤ `shore_high`+40 y fuera de alcance), ritmo ≤ trote | |
| `muster` | exige estar a ≤ `muster.radius_m` de `plaza_toros`; si no, marcha hasta allí (por una bajada) y trabaja `work_s` | `volunteers_pool` agotado; fuerza ya en 100 |
| `resupply` | ídem sobre `bateria_abascal`, `work_s` 25, +16 de munición | munición al tope |
| `signal_liniers` | ídem sobre `puesto_liniers`, 10 s, `advance_authorized=true`, +8 munición | ya concedida |
| `cancel` | detiene, `stage="ready"`, limpia `order/path/work` | |

Cada orden aceptada llama a `_record_order` (como hoy) y devuelve `{"ok": true, "reason": String, "path": [...], "plan": <resultado de plan_route>}`. Para Norte, `issue_order` sigue redirigiendo a `issue_campaign_order`. Las órdenes viejas `direct` y `flank` ya **no existen** en Justina: *"Orden táctica desconocida."*

### 1.6 Exploradores y acciones globales

```gdscript
func issue_scout(scout_id: String, action: String, points: Array = []) -> Dictionary
# action: "probe" | "mark_ford" | "recall"; points: Array de Vector2 (≤ actions.probe.waypoints_max = 3)
func call_fire_support() -> Dictionary      # "distract_fire"
func retreat_all() -> Dictionary            # termina la partida: defeat, reason "Retirada general ordenada. ..."
```

- `probe`: el explorador recorre `points` en orden a `speed_mps_dry`/`speed_mps_water`; va "sondeando" y agrega a `probes` segmentos de 6 m de ancho a medida que avanza (no al final: la UI ve crecer la franja). No entra en profundidad real > `max_depth_m` (1,1): se detiene, **revela** esa celda y el hazard (si lo hay) pasa a `hazards_found`/`fords_found` cuando la sonda lo toca. Recibe fuego con peso 0,15; si `hp` llega a 0, `lost`.
- `mark_ford`: exige que `points` (1 o 2) estén sobre una sonda `lane` (≤ 3 m de su eje); recorre el tramo trabajando a `work_mps` y convierte esa parte en sonda `marked` de ancho 16. Gasta `ceil(longitud/10)` balizas; rechaza si faltan: *"Faltan balizas (quedan N)."* El tramo trabajado antes de acabarse las balizas queda marcado.
- `recall`: vuelve a la playa seca.
- Rechazos: explorador `lost`, sin puntos, más de 3 puntos, punto fuera del mapa/obstáculo.
- `call_fire_support`: exige `ammo >= 8` y `elapsed >= fire_support.ready_at`; consume 8; fija `until = elapsed + 45`, `ready_at = elapsed + 90`; moral de la dotación −2; evento `fire_support`. Mientras `elapsed < until`, `exposure_at` se multiplica por 0,5 y el intervalo entre descargas suma 2 s.
- `retreat_all`: válido solo en `playing`.

### 1.7 Tropiezos, fuego y captura

- **Tropiezo**: si un grupo montado entra en un punto con profundidad real > 1,3 (o a pie > 1,2) estando el punto `unknown`, se detiene `hazard.stumble.stop_s` (20 s, `stage="stumbling"`, `stumble_remaining` decrece), +12 fatiga, −3 de fuerza; el punto pasa a conocido (se agrega una sonda `lane` corta de 6 m y el hazard a `hazards_found`) y se replanifica desde ahí hacia el destino original (si no hay ruta: `stage="blocked"` con motivo). Si el punto era `probed`/`marked` nunca ocurre. Evento `stumble`.
- **Fuego del buque**: cada descarga elige entre las unidades con `exposure_for > 0` con pesos `target_weights` (grupo 1,0; explorador 0,15). Daño `uniform(damage_min, damage_max) * exposure * max(morale_floor, crew_morale/100)`. Los exploradores usan `hp`. Un explorador perdido suma `stats.scouts_lost`. Alcance `ship.fire.range_m` (280 m) desde `ship_position()`. Exposición por rumbo (ángulo agudo respecto del eje este-oeste del buque, `heading_deg == 0` = proa al norte): `<= 40°` → 1,0; `<= 70°` → 0,5; resto → 0,25.
- **Captura**: igual que hoy con los parámetros de `ship.capture`: `capture += Σ(board_power) * 0.19 * dt`, `crew_morale -= Σ(board_power) * 0.12 * dt`, `board_power = (strength/100) * max(0.35, 1 - fatigue*0.004)`. Grupo `boarding` → desmontado, caballos "estacionados" en el vado (la Vista los dibuja). Si el río sube sobre el límite del vado, los caballos se retiran solos (sin penalidad).
- **Rescate**: una unidad cuyo punto pasa a ser `honda` por la subida del río vuelve al punto transitable más cercano de la playa seca (+10 fatiga) con evento `warning`, como hoy.
- **Victoria**: `capture >= 100`. **Derrota**: todos los grupos con `strength <= 5`; `elapsed >= deadline` sin captura; `retreat_all`.

### 1.8 Consultas de presentación (todas devuelven copias)

```gdscript
func ship_state() -> Dictionary
# {"x","z","heading_deg","guns_total":26,"broadside_guns":13,"range_m","next_volley_in":float,
#  "crew_morale","capture","fire_support_active":bool,"fire_support_ready_in":float}
func resources() -> Dictionary
# {"ammo","ammo_max","balizas","volunteers_pool","advance_authorized"}
func scouts() -> Array            # copia de state.scouts
func probes() -> Array            # copia de state.probes
func action_info(action: String) -> Dictionary
# JSON map.actions[action] + {"id": action}; vacío si no existe
func list_actions(actor_kind: String) -> Array
# actor_kind: "group"|"scout"|"global"; devuelve ids en el orden de la UI:
# group: move, board, muster, resupply, signal_liniers, withdraw, rally, cancel
# scout: probe, mark_ford, recall
# global: distract_fire, retreat_all
func action_availability(actor_id: String, action: String, target: Vector2 = Vector2.ZERO) -> Dictionary
# {"ok": bool, "reason": String, "cost_text": String, "tag": String}
# Sin efectos. "reason" explica el bloqueo (munición, balizas, orden de avance, distancia, explorador perdido, partida terminada...).
# cost_text: resumen corto "8 munición · 45 s" armado desde el JSON.
func campaign_report() -> Dictionary
```

`campaign_report()` (válido en cualquier momento; el definitivo cuando `status != "playing"`):

```
{"status": "playing"|"victory"|"defeat", "reason": String, "elapsed": float,
 "outcome_title": String,                    # "Buque capturado"/"Plazo agotado"/"Grupos dispersos"/"Retirada general"
 "groups": [{"id","name","tag","start_strength","end_strength","loss_pct"}],
 "route": "central"|"sur"|"mixta"|"ninguna",
 "route_notes": [String],                    # p. ej. "Tropezaron en el pozo del banco central (2 veces)"
 "probe_m","marked_m","stumbles","ammo_used","balizas_used","fire_support_uses","scouts_lost",
 "shots_taken","damage_taken","level_at_boarding","boarded_at",
 "exposure_s": {"central","sur","otra"},
 "history": [{"text": String, "tag": String}]}   # "Qué fue historia"; ver abajo
```
`history` es **fija** (lista constante en Reglas, redactada con el JSON `texts` y `landmarks`): como mínimo estas cinco líneas, con estas etiquetas — mercante de 26 cañones varado frente al Retiro (`documentado`); captura por la caballería de Pueyrredón (`documentado`); Güemes al frente de los jinetes (`tradicion`); distancia ~390 m y profundidad del vado (`diseno`, "cifra divulgativa"); bancos, canal, vados, pozo, tiempos, fuerzas y munición (`diseno`).

### 1.9 Guardado

- `snapshot()` devuelve `state.duplicate(true)`. `save_game` y `load_game` no cambian de firma; `load_game` además descarta `_nav` y los caches de conocimiento.
- `validate_snapshot` agrega para Justina (y mantiene todo lo del Norte):
  - `schema_version == JUSTINE_SAVE_VERSION`, `map_id == "justina"`, `map_version` igual al del JSON.
  - Presencia y tipo de todos los campos de 1.2; rangos: `water_level_m` 0..1.65, `water_level` 0.05..0.95, `ammo` 0..`ammo_max`, `balizas` 0..`balizas_start`, `volunteers_pool` 0..60, `crew_morale/capture` 0..100.
  - Coordenadas dentro de `map_size()` (el límite viejo ±38/±28 queda solo para el Norte).
  - `units.size()==3`, ids únicos; `pace`, `work`, `stumble_remaining` válidos; `stage` en la lista de 1.2; `order.action` en la lista de 1.2.
  - `scouts`: 2, ids `scout_1/2`, `hp` 0..3, `stage` válido, puntos dentro del mapa; `probes`: `kind` válido, `width` ∈ {6, 16}, puntos dentro del mapa, ≤ 400 sondas, ≤ 200 puntos por sonda.
  - `hazards_found ⊆ ids de hazards`, `fords_found ⊆ ids de fords`.
  - Coherencia: nivel y fase corresponden a `elapsed` (tolerancia 0,002 m); `water_level` derivado de `water_level_m`; `stage=="working"` ⇒ `work` no vacío y viceversa; `stage=="stumbling"` ⇔ `stumble_remaining>0`; `moving` ⇒ `path` no vacío y `order` no vacío; `capture>=100` solo si `status=="victory"`; `advance_authorized` verdadero si existe una orden `signal_liniers` en `orders`; `fire_support.until <= ready_at`; `stats.start_strength` presentes; sondas con `t <= elapsed`.
- Round-trip: guardar y cargar no cambia `snapshot()` (salvo `game_id`, `previous_game_id`, `state_version`, el evento `load`), tolerancia 1e-6; el estado del RNG se compara exacto.

### 1.10 Tests exigidos a Reglas (`tests/test_rules.gd`)

Se reescriben los tests de Justina (los del Norte no se tocan). Obligatorios, además de los de 1.9:
1. Alturas de referencia de 1.3.1; `speed_at` por tipo de terreno con la tabla de 1.3.3; ningún grupo supera `speed_at` (muestreo de 200 pasos).
2. `tide_at`: valores en t = 0, 45, 210, 375, 500, 645, 735, 825, 900 (según `time`); `ford_window` del vado del buque ≈ 315..677 s y del vado sur ≈ 295..688 s (±5 s), certeza falsa antes de sondear.
3. Conocimiento: antes de sondear, `perceived_height_at(415,264)` ≈ perfil base +0,5 (no −1,9); tras `probe` sobre ese punto, `knowledge_at == "probed"` y `perceived == real`.
4. Recorridos scripteados de `play_targets` (DISENO_JUSTINA 10): ruta central a ciegas tropieza y pierde ≥ 30 % de fuerza; reconocer+marcar gana antes de 760 s (central) y 800 s (sur); salir tarde pierde; pasividad pierde en t = 900; `exposure_s.central ≥ 1,4 × exposure_s.sur` con los mismos tres grupos recorriendo cada ruta.
5. Cada acción: éxito, rechazo concreto, costo descontado (munición, balizas, pool, tiempo) y efecto.
6. `board` sin orden de avance rechaza; con orden, acepta.
7. Rendimiento medido (construcción de la cuadrícula, `plan_route`, `tick` medio) impreso en el resultado; sin umbral duro si el equipo es lento, pero se informa.
8. `evidence/`: los tests no deben reescribir `evidence/` de 0.1.0; si lo hacen, `git checkout evidence` antes de comitear.

## 2. Vista (`scripts/world_view.gd`)

La Vista dibuja **solo** lo que le dice Reglas. Lee: `rules.state`, `rules.map_data()`, `rules.terrain_height_at`, `rules.water_level_m()`, `rules.knowledge_at`, `rules.probes()`, `rules.scouts()`, `rules.ship_state()`, `rules.exposure_at`. No guarda geometría propia que contradiga el JSON.

### 2.1 Qué recibe y cuándo

- `build(game_rules, quality_name)`: igual que hoy. Para `scenario == "justine"` construye todo desde `map_data()` (tamaño, hitos, barranca, banco...). Para Norte no cambia.
- `update_state(delta)`: cada fotograma. Lee `water_level_m`, unidades, exploradores, sondas y `ship_state`. Las sondas y los exploradores se reflejan cuando cambia `rules.state.state_version`.
- Las etapas nuevas (`working`, `stumbling`) tienen animación o indicador propio; `waiting_tide` ya no existe en Justina.

### 2.2 Terreno y agua

- **Malla de terreno** a 4 m de resolución sobre `(0,0)-(w,h)` (≈ 30 000 vértices) con `terrain_height_at` **real**, más una malla de baja resolución más allá del borde hasta 3000 m (horizonte, sin geografía inventada: niebla/agua). Barranca real (8-15 m) con textura/color distinto de la playa. Sin ruido que contradiga la altura de Reglas (solo detalle de color/normales).
- **Agua turbia**: superficie plana a `y = water_level_m`, **opaca** (≥ 0,97 de opacidad más allá de `visibility_depth_m`), color pardo del Plata. **Prohibido** el degradé por profundidad que revele bancos, canal o pozo. Se permite: espuma/borde en la línea de contacto con tierra emergida, y un halo de 0,3 m (`visibility_depth_m`) que deja ver el suelo muy somero (coincide con `knowledge "visible"`). El parámetro del shader `water_level` se alimenta con `state.water_level` (compat) o `water_level_m`.
- **Conocimiento visible**: sobre la superficie del agua se dibujan, con material emisivo que no ocluya el suelo emergido:
  - Sonda `lane`: franja de 6 m a lo largo de `pts`, coloreada **por profundidad real en cada tramo**: verde ≤ 0,6 m, ámbar 0,6-1,3 m, rojo > 1,3 m. Se actualiza mientras el explorador avanza.
  - Sonda `marked`: franja de 16 m con borde claro y **balizas** (postes) cada 10 m.
  - `hazards_found`: boya roja + rótulo del hazard. `fords_found`: boyas verdes + rótulo.
  - En zonas `unknown` no se dibuja nada (ni hachurado dentro del 3D; la niebla del fondo es una capa de **minimapa**, 2.5).
- **Alcance del buque** (capa `exposure`, desactivable): anillo de `range_m` alrededor del buque y sectores por exposición (1,0 / 0,5 / 0,25) proyectados al agua, tenues. Se activa con `set_layer_visible("exposure", true)`; por defecto visible al seleccionar un grupo.

### 2.3 Hitos, buque y unidades

- **Hitos** (`map.landmarks`): geometría simple, escala real (Plaza de Toros circular de 24 m de radio con muro; batería con parapeto y 3-4 piezas; Alameda como hilera de árboles; campamento con tiendas; puesto de Liniers con tienda; carretas y cañaverales de `obstacles`). La `tag` del hito se expone con `get_landmark_info(id)` (2.5). Referencia de silueta: `docs/referencias/justina/vidal_05_*` y `vidal_02_*`. Los modelos nuevos se agregan a `assets/` y se registran en `tools/create_models.py`; cualquier asset reutilizable cita su fuente en `docs/CREDITOS.md` (el arquitecto no toca ese archivo: la pista Vista lo agrega al final si usa material de `docs/referencias`, o se lo pide al orquestador).
- **Buque**: en `ship.x/z`, casco de 16 m de radio, fondo `hull.bed_m`, proa hacia `heading_deg` (0 = norte), escora leve; humo y destello (`cannon_effect`) en cada descarga en la banda de babor. **Sin bandera argentina.** Sin etiqueta de tipo (nada de "fragata"/"goleta"); el rótulo es "Buque Justina". Si lleva insignia, genérica y no nacional.
- **Unidades**: un grupo de jinetes se dibuja como columna de `n = clamp(round(strength / 100 * 14), 2, 14)` jinetes con separación realista (≈ 2,5 m), en una banda de 14 m de ancho (16 m en carril `marked`), orientados por la dirección de marcha. Hundimiento: caballos con el agua al pecho se dibujan con la profundidad real a esa posición (más bajos). Desmontados en el vado: los caballos quedan estacionados en `board_point()`. Exploradores (`scout_1/2`): un jinete con lanza; `lost` se dibuja caído.
- Mantener batch/instancing (MultiMesh) para jinetes. Presupuesto de dibujo: ≥ 60 FPS en el equipo de pruebas de `docs/RENDER.md`; si no se cumple, bajar `quality`.
- `unit_nodes[id]` sigue existiendo con `{root, mounted, ...}` para ids de grupos **y** de exploradores; `unit_labels[id]` también (la UI los usa).

### 2.4 Funciones públicas para cámara y mundo

Las cinco primeras no cambian de firma; el resto es nuevo.

```gdscript
func pick_ground(camera: Camera3D, mouse_pos: Vector2) -> Variant        # Vector3 o null (sin cambios)
func pick_unit(camera: Camera3D, mouse_pos: Vector2) -> String            # id de grupo o explorador; "" si ninguno (radio 55 px)
func pick_sector(camera: Camera3D, mouse_pos: Vector2) -> String         # solo Norte
func refresh_paths()
func cannon_effect(from: Vector2 = Vector2.ZERO, to: Vector2 = Vector2.ZERO) -> void   # args opcionales

func terrain_height(x: float, z: float) -> float                          # = rules.terrain_height_at (compat)
func map_size() -> Vector2                                                # (900, 520)
func world_to_map(p: Vector2) -> Vector2                                  # uv (0..1, 0..1); u=x/w, v=z/h; v=0 es el NORTE (arriba en el minimapa)
func map_to_world(uv: Vector2) -> Vector2
func camera_bounds() -> Rect2                                             # el mapa agrandado en camera.bounds_margin_m
func clamp_camera_target(p: Vector3) -> Vector3                           # recorta x,z a camera_bounds; y = max(terrain_height, water_level_m)
func ground_xz_from_screen(camera: Camera3D, mouse_pos: Vector2) -> Variant   # Vector2 (x,z) o null
func camera_frustum_on_ground(camera: Camera3D) -> PackedVector2Array     # 4 puntos (x,z), orden NO, NE, SE, SO de pantalla; recortados a camera_bounds
func meters_per_pixel(camera: Camera3D, screen_pos: Vector2 = Vector2(-1, -1)) -> float   # en screen_pos; (-1,-1) = centro de la pantalla
func pick_units_in_rect(camera: Camera3D, screen_rect: Rect2) -> Array    # ids (String) de grupos y exploradores cuyo centro proyecta dentro del rect; orden estable: guemes, arias, zavala, scout_1, scout_2
func pick_landmark(camera: Camera3D, mouse_pos: Vector2) -> String       # id de hito a ≤ 40 px, o ""
func get_landmark_info(id: String) -> Dictionary                          # {id,name,type,tag,source,x,z}
func landmark_labels(camera: Camera3D) -> Array                           # [{id,name,tag,screen: Vector2, behind: bool}] para que la UI rotule
func set_layer_visible(layer: String, on: bool) -> void                   # "paths"|"probes"|"exposure"|"labels"|"landmarks"
func set_selected_ids(ids: Array) -> void                                 # resalta anillos; `selected` (String) = ids[0] o ""
```

Variables que la UI sigue leyendo: `unit_nodes`, `unit_labels`, `selected`, `selected_sector`, `show_paths`, `sector_nodes` (Norte). Se agrega `selected_ids: Array`.

La Vista **no** maneja la cámara (la UI es dueña de `Camera3D`); solo ofrece las funciones de arriba. `camera.far` ≥ 4000 lo fija la UI (`camera.far_m`). La Vista aplica niebla de distancia suave a partir de 1500 m.

### 2.5 Minimapa (textura) y niebla del fondo

```gdscript
signal minimap_changed
func get_minimap_texture(size: Vector2i) -> Texture2D       # ImageTexture del mapa completo, norte arriba; cacheada por (size, version)
func minimap_refresh(force: bool = false) -> void           # la Vista lo llama sola cada minimap.refresh_s (2 s) y emite minimap_changed si cambió algo
```
Contenido de la textura (colores de `minimap.colors`):
- Meseta/barranca sombreadas por relieve; playa alta; **suelo emergido** (`knowledge "visible"` y altura sobre el agua > 0) en color `emerged`: cambia con la bajante.
- Agua **desconocida** en `water_unknown` **sin ningún relieve** (misma regla de ocultamiento que el 3D) con hachurado diagonal tenue como "niebla del fondo".
- Franjas de sondas: `probe_lane_width` por profundidad real (verde/ámbar/rojo), `marked` en `marked`; hazards y vados hallados en `danger`/verde.
- Hitos como puntos con el color de su `tag`; buque; línea de agua actual.
- **No incluye** unidades, exploradores ni el cuadro de cámara: los dibuja la UI encima con `world_to_map` (así se mueven a 60 FPS sin regenerar la textura).

### 2.6 Lo que la Vista no hace

Ni reglas (daño, nivel), ni órdenes, ni lee `data/justina_map.json` por su cuenta (siempre `rules.map_data()`), ni dibuja información que el jugador no tiene (fondo real fuera de lo `visible`/`probed`/`marked`).

## 3. UI (`scripts/main.gd`)

`main.gd` sigue siendo el dueño de `Camera3D`, el HUD, la entrada y los modales. Leer del estado está permitido; **escribir** solo vía métodos de Reglas.

### 3.1 Cámara libre

| Entrada | Acción |
|---|---|
| `W A S D` / flechas | paneo en el plano del suelo respecto de la orientación de la cámara; velocidad ∝ distancia (`pan_speed_mps_at_100m` = 120 m/s a 100 m); `Shift` ×3 |
| Borde de pantalla (`edge_pan_px` = 14) | paneo; solo con la ventana enfocada, el ratón dentro, sin modal ni arrastre activos |
| Arrastre con **botón derecho** (> 6 px de movimiento) o **central** | "agarrar el mapa": el punto bajo el cursor sigue al cursor (usa `ground_xz_from_screen`). Un clic derecho **sin** mover es una orden (3.3) |
| Rueda | zoom hacia el cursor entre `min_distance_m` (25) y `max_distance_m` (900); mantener `camera_goal` suavizado como hoy |
| `Q` / `E` | rotar la vista (guiñada) por pasos suaves; `Alt`+arrastre central rota libre |
| `R` / `F` | inclinación (pitch) 25°-80° |
| `Inicio` | centrar en la selección (o en `camera.focus_start` si no hay) |
| `B` | centrar en el buque |
| Doble clic sobre un grupo | centrar y acercar |

El objetivo de cámara se recorta siempre con `world.clamp_camera_target`. El zoom inicial es `camera.initial_height_m` (90 m) centrado en `focus_start` (el campamento y la playa): **no** debe mostrar el mapa completo. La cámara nunca entra bajo el terreno (`y >= terrain_height + 3`). Norte conserva su cámara actual.

### 3.2 Minimapa, brújula, escala

- **Minimapa** abajo a la izquierda, `minimap.default_size_px` (260 x 150), con marco, y `M` lo alterna a `large_size_px`. Muestra `world.get_minimap_texture(size)` (se re-pide al recibir `minimap_changed`). Encima dibuja: grupos con su glifo y color (`UNIT_COLORS`, `UNIT_GLYPHS`), exploradores (rombos), el cuadro de la cámara (`camera_frustum_on_ground` → `world_to_map`), un punto en el buque, marcas de la selección, y una "N". Interacción: **clic izquierdo o arrastre** mueve la cámara (centra en ese punto); **clic derecho** con selección da la orden `move` ahí (con vista previa de riesgo como 3.3); `Shift`+clic derecho agrega waypoint.
- **Brújula**: rosa en la esquina del minimapa que gira con la guiñada de la cámara; la N apunta al `-z` del mundo; E es `+x` (el río). Siempre visible.
- **Escala gráfica**: barra con longitud "bonita" (10, 20, 50, 100, 200, 500 m) que ocupa 80-160 px, calculada con `world.meters_per_pixel(camera)`; se recalcula en cada cambio de zoom/inclinación. Rótulo "100 m".
- **Nombre del paraje**: línea fija arriba a la izquierda con el hito/zona más cercano al centro de la pantalla (p. ej. "Playa alta", "Barro", "Banco central (sin reconocer)", "Frente al buque"), más la coordenada `x,z`.
- Los hitos tienen rótulos (de `world.landmark_labels`) con el glifo de su `tag`; se ocultan los que se solapen (como hoy `_draw_map_labels`).

### 3.3 Selección y órdenes

- **Clic izquierdo** sobre un grupo o explorador: lo selecciona. **Caja de selección**: arrastre izquierdo (> 6 px) dibuja un rectángulo; `world.pick_units_in_rect`. `Shift` suma, `Ctrl` alterna. Teclas `1`, `2`, `3` seleccionan `guemes`, `arias`, `zavala`; `4`, `5` los exploradores; `Tab` cicla.
- La selección puede mezclar grupos y exploradores, pero **cada comando solo se aplica a los actores de su tipo**; si hay mezcla el panel muestra un aviso ("la acción se aplica a los 2 grupos seleccionados").
- **Clic derecho (sin arrastre)** sobre el suelo = `move` al ritmo actual de la selección. Con varios grupos, el destino de cada uno se desplaza para que no se apilen: separación lateral de 18 m centrada en el punto (a lo largo del eje perpendicular a la marcha).
- `Shift`+clic derecho agrega waypoints (hasta 4, pasan en `opts.waypoints`). `Enter` confirma, `Esc` cancela.
- **Ritmo**: `G` galope, `T` trote, `C` caminar (sobre la selección de grupos). El panel lo muestra; el galope se ofrece pero la UI avisa "solo en terreno firme".
- **Vista previa de ruta**: al apuntar un destino (cursor o minimapa) se llama `plan_route(...)` (sin efectos) y se dibuja la ruta en 3D y el resumen: `412 m · 3:20 · 120 m sin reconocer · riesgo alto · expuesto 18 s`. Color de la línea según `risk` (verde/ámbar/rojo/gris). Si `unknown_m > 0` el clic de confirmación pide **confirmar** (segundo clic o `Enter`).
- **Panel de acciones** (abajo, centro). Muestra solo los botones del tipo del actor seleccionado (`rules.list_actions(...)`). Cada botón: icono/glifo de `tag`, nombre `map.actions[id].label`, `cost_text`, atajo. Si `action_availability(...).ok == false`, el botón se muestra deshabilitado y el motivo en información emergente y en la línea de ayuda. Acciones sin objetivo (Reunir, Abastecer, Señalar) se disparan con un clic y la UI muestra el trayecto previsto; las de mapa (Mover, Reconocer, Marcar vado) entran en modo apuntado.
- **Reconocer / Marcar vado** (explorador): modo apuntado con 1-3 puntos (`Shift` agrega); al confirmar llama `issue_scout`. La vista previa dibuja los segmentos y el texto "sondeo de 140 m · ≈ 2:20".
- **Acciones globales**: botón "Distraer con fuego" (con munición y tiempo de recarga) y menú "Retirada general" (con confirmación modal).
- **Barras**: nivel del río con marcas cada 0,5 m y los umbrales 1,3 m (caballo) y 1,2 m (a pie); **línea de tiempo** de 0 a 900 s con las fases (`tide_marks`), el instante actual y las **ventanas de vados conocidos** (`ford_window` con `certain == true`; los inciertos se dibujan punteados con "?"); recursos (munición, balizas, voluntarios, orden de avance); captura y moral de la dotación; fuerza/fatiga de cada grupo con el badge de su etapa (`STAGE_TEXT` extendido con `working` "Trabaja", `stumbling` "Tropezó").
- **Etiquetas de fuente**: junto al nombre de cada grupo, hito y acción aparece el glifo de su `tag` con el color de `source_tags`; en el panel de información, "Fuente: …" con el texto del hito/acción. La vanguardia muestra siempre "◆ Tradición".
- **Eventos**: los toasts usan el `kind` del evento (color e icono propios); los eventos con `pos` llevan un botón "ver" que centra la cámara allí.
- **Parte de campaña**: modal al terminar (y botón/atajo `P` durante la partida para un parte parcial) renderizado desde `rules.campaign_report()`: título, resultado, tiempo, tabla de grupos, ruta usada, metros sondeados, tropiezos, munición, y la lista "Qué fue historia" con el glifo de cada línea. Sin cálculos propios del resultado.
- **Briefing inicial**: modal con `state.briefing`, la leyenda de las 4 etiquetas y 3 consejos de `texts.tips`; se puede reabrir con `F1`.
- **Guardado/carga**: sin cambios de uso. Si `load_game` rechaza un guardado de Justina por versión, mostrar el motivo y ofrecer "Nueva partida".
- **Tiempo**: pausa y velocidades ×1, ×2, ×4 se aplican entregando `dt` a `rules.tick`; el paso fijo no cambia.

**Tabla de atajos (única)**: `Espacio` = pausa; `Inicio` = centrar selección; `B` = centrar buque; `M` = minimapa grande; `P` = parte; `F1` = ayuda/briefing; `1-5` = selección; `Tab` = ciclar; `G/T/C` = ritmo; `Enter` = confirmar; `Esc` = cancelar/cerrar; `Q/E/R/F` = rotar/inclinar; `+/-` velocidad de simulación. La barra espaciadora ya no centra la cámara.

### 3.4 Tests y QA de la UI

`tools/ui_qa.gd` y `tests/test_integration.gd` verifican, en Justina:

1. El minimapa, la brújula y la escala están dentro de la pantalla, no se solapan con paneles y tienen tamaño mínimo (260 x 150; brújula ≥ 48 px; barra de escala 80-160 px).
2. La longitud de la barra de escala coincide con `meters_per_pixel` (±5 %).
3. WASD, borde de pantalla, arrastre derecho y rueda mueven la cámara, y el objetivo nunca sale de `camera_bounds()`; el zoom respeta 25-900 m.
4. Un clic en el minimapa centra la cámara en el punto; el cuadro de cámara se actualiza.
5. Caja de selección sintética sobre dos grupos devuelve ambos; `Shift` suma, `Ctrl` alterna.
6. Cada una de las 10 acciones de 1.5/1.6 tiene un botón con etiqueta y glifo de `tag`, y un motivo cuando está bloqueada.
7. Vista previa de ruta: apuntar a un destino sin reconocer muestra `riesgo alto` y exige confirmar; tras `probe` del mismo tramo cambia a `bajo`.
8. Flujo completo: briefing → sondear → marcar → pedir orden de avance → cruzar → abordar → parte de campaña (con el parte coincidiendo con `campaign_report()`).
9. Ningún texto de la UI de Justina afirma que Güemes mandó (siempre "Tradición"); ningún texto dice "fragata" ni "goleta"; ninguna imagen del buque lleva bandera argentina.
10. Capturas del estado inicial, mitad de bajante, cruce y parte, guardadas fuera de `evidence/` de 0.1.0 (carpeta propia).

Los tests de integración escriben en `user://`: aislar `APPDATA` (`export APPDATA="$TEMP/<nombre>_appdata"`).

## 4. Flujos entre capas (resumen)

```
Reglas.tick(dt) ──state──▶ Vista.update_state()    (lee rules.state, ship_state, probes, scouts)
UI ──orden──▶ Reglas.issue_order / issue_scout / call_fire_support / retreat_all
UI ◀──plan_route / action_availability / campaign_report── Reglas  (solo lectura)
UI ──pick_* / world_to_map / get_minimap_texture──▶ Vista
```

## 5. Puntos abiertos y cambios de contrato

- Cualquier ajuste de cifras (daño, tiempos, balizas) se hace en el JSON por el arquitecto, no en el código de una pista; Reglas lo lee de `map_data()`.
- Si Reglas necesita un campo de estado nuevo, lo agrega, lo documenta en `docs/DISENO_REGLAS.md` y avisa para versionar el contrato; la UI y la Vista no pueden depender de campos no listados aquí.
- El **Norte** queda para otra ronda (síntesis 1.2 y 4): este contrato no lo cambia.
- Pendientes que no resuelve el contrato: contrastar posiciones con las láminas de Vidal (Vista), cotejar a Gillespie con el escaneo (historia), playtest humano (todas).

## 6. Claves nuevas del JSON (Ronda 1, 30-oct-2026, `map_version` 4)

Todas son **aditivas**: Reglas, Vista y UI siguen funcionando si las ignoran. Las lee quien las necesite con `rules.map_data().get("clave", ...)`. Etiquetas siempre en `tag` / `status` con los ids de `source_tags` (`documentado`, `tradicion`, `reconstruccion`, `diseno`). Coordenadas de juego (+x este, +z sur, 1 u = 1 m).

| Clave | Contenido | Quién la consume |
|---|---|---|
| `size_note` | Decisión 900 x 520 simulado + contexto 900 x 750 | documentación |
| `bed_warp` | `points_z_dx` (pares [z, dx]), `fade_in_from_toe_m`, `fade_in_len_m`, `fade_out_from_x`, `fade_out_to_x`. Ya lo aplica `terrain_height_at`; la Vista que dibuje con `terrain_height_at` lo recibe sola. **Quien use `bed_profile.points_x_elev` directamente (p. ej. shader de fondo en `world_view.gd`, línea ~859) ignora los meandros: debe pasar por `terrain_height_at`** | Vista |
| `tide.states[]` | `id` (alto, bajante, minimo, subida), `label`, `level_m_range`, `shows` (texto), `visual.wet_sand_width_m`, `visual.water_clarity`, `visual.banks_visible`. Sirve para rotular el estado del agua y graduar arena húmeda y transparencia (un solo tono de agua, varía la transparencia) | Vista, UI |
| `tide.alternative_variant` | Variante «banco expuesto»: `implemented:false` | documentación |
| `hull` (+ `length_m`, `beam_m`, `heading_deg`, `note`) y `ship.hull_envelope`, `ship.position_candidates`, `ship.rigging`, `ship.crew_composition`, `ship.distance_note` | Casco visual 40 x 9 m, proa al norte; el círculo de `radius_m` 16 sigue siendo la zona de contacto. Mesana dañada (hipótesis, `tradicion` si se desarbola). Candidatos A (usado) y B (no) | Vista, UI |
| `landmarks[justina]` (+ `hull_length_m`, `hull_beam_m`, `heading_deg`, `uncertainty_radius_m` 120) | Zona de incertidumbre del lugar: dibujarla como mancha tenue, no como pin | Vista |
| `landmarks[plaza_toros]` (+ `tag_parts`, `shape: octagon`, `rotation_deg`, `vertex_span_m`, `ring_radius_m`, `wall_height_m`, `gates`, `previous_radius_m`) | El rótulo debe mostrar la parte débil: `tag` = `reconstruccion`; `tag_parts.existencia` = `documentado`. Dibujar exterior octogonal (circunradio `radius_m`) y ruedo circular | Vista, UI |
| `landmarks[alameda]` | Ahora `diseno`, `trees:false`, polilínea corta. **No plantar arboleda regular** | Vista |
| `landmarks[bateria_abascal]` | Nombre «Piezas de a 18 del Retiro»; el id no cambia | Vista, UI |
| `scenery{tag, note, items[]}` | Decorado no jugable: `kind` ∈ dependencias_militares, casa, tapia, huellas, carros, bote, vegetacion; con `x,z,w,d,rot_deg` o `polyline`, `tag`, `source` | Vista |
| `context{extent, north, south, skyline[], excluded_anachronisms[]}` | Contexto fuera de `size` (z -115..0 y 520..635): casas, ribera, siluetas de Santa Catalina, Fuerte y campanarios con `bearing_deg`. La cámara sigue acotada por `size` | Vista |
| `palette{package, terrain, water, map_overlays}` | Hex de la paleta del paquete (azul del Fijo `#253B53`, encarnado `#983C3C`, etc.), terreno y agua turbia (`water.shallow/mid/deep`), `fire_arc_fill_alpha_max` 0,12: el abanico de fuego va como contorno tenue | Vista, UI (minimapa: usar `water`/`terrain`) |
| `forces{groups, opposing, kits}` | Por grupo: etiqueta, `headcount_hint` (figuras a dibujar, no efectivos), `composition[]` con `status`, `kit_ref`; `kits` con colores por nombre de `palette.package`, silueta y `token_color` | Vista, UI |
| `characters[]` | Fichas: Güemes (tradición; cadete de Infantería), Liniers, Pueyrredón, Gillespie (fuente), capitán sin nombre, marineros; `in_play` | UI (fichas), Vista |
| `banners{items[], forbidden[]}` | `red_ensign_mercante` (popa del buque, `reconstruccion`, `draw_default:true`), `bandera_circo` (`reconstruccion`, `draw_default:true`), el resto `draw_default:false`. Etiqueta visible: «Pabellón mercante (hipótesis)», «Bandera del circo (inferencia)». **Prohibido** celeste y blanca, escarapela, Infernales | Vista, UI |
| `play_targets.cohort_win_rate`, `victory_loss`, `max_victory_loss_pct` | Objetivos de la matriz (tests) | tests |
| `package_ref` | Procedencia del paquete | documentación |
| `data/history.json`: `uncertainties[]`, `justina_package`, `facts[]` (+4 hechos), `sources` S13-S28 | Pantalla de fuentes / parte | UI |

**Para otras pistas (no son de Reglas):**
- Vista: el rótulo «Pie de la barranca» (`world_view.gd` ~l. 1333) está fijo en (190, 60): ahora el pie está en x=190 (z=50) / 200 (z=100); usar `barranca.toe`. Los shaders de agua/playa deben leer `tide.states`; el color del agua sale de `palette.water` (turbio pardo-verdoso, sin rosa ni ocre saturado). Con la bajante, la playa baja sigue la curva con meandros (`terrain_height_at`).
- Vista: `enemy_marker` («◆ REALISTAS», bandera roja, `royalist_1817`) es del Norte; verificar que no se muestre en Justina (el paquete excluye cualquier bandera ajena; no hay realistas en la escena).
- UI: mostrar «Güemes y los jinetes (tradición)» en lugar de «Vanguardia» (`main.gd` l. 1166 abrevia por id: usar `forces.groups[id].label`); la acción «Volver» desconocida se detecta en el QA de UI, no es de datos.
- Las posiciones de los hitos cambiaron: `plaza_toros` (112,225) r45; `bateria_abascal` (148,176); `campamento_pueyrredon` (148,292); `puesto_liniers` (140,345); `signal_liniers` y `muster` usan esos hitos (`muster.radius_m` 45).

