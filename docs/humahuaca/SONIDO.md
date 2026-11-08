# Sonido del nivel II «Humahuaca» (pista visual)

Estado al 2026-11-02, rama `hx-sonido-nube` (desde `humahuaca-r1`, 333a657). El nivel no tenía sonido propio (pendiente de
R3): el controlador pide `audio_manager.play()` con nombres de la Justina (`order`, `error`, `alert`, `bell`, `cannon`, `hoof`,
`victory`) y con alias que el `audio_manager` de esta rama resuelve con **los mismos .wav de la Justina a otro tono**
(`capture`, `volley_warn`, `messenger`, `ford`, `defeat`, `select`: campana, error u orden re-afinados). Ni lluvia, ni torre, ni
mulas, ni carga, ni alba: solo esos avisos. Esta ronda deja **material propio generado por código** (32 WAV), un **mapeo de
eventos** y un **nodo reproductor** listo, sin tocar `scripts/audio_manager.gd`, `scripts/main.gd` ni archivos de otras pistas.
Falta **una línea** en el controlador (sección 3).

## 1. Paleta sonora (`assets/audio/humahuaca/`, 32 archivos, 5,3 MB)

Todo lo genera `tools/generate_audio_humahuaca.py` (`python tools/generate_audio.py --humahuaca`) con numpy y scipy sobre las
primitivas de `tools/generate_audio.py`: ruido filtrado por bandas, envolventes, tonos de metal por armónicos, campana de
parciales inarmónicos y reverberación por convolución. **Sin bancos de sonido ni grabaciones.** WAV de 44,1 kHz, mono, 16 bits,
≤ 300 KB cada uno (tope de 3,3 s); los lazos son periódicos exactos. La receta de cada archivo y sus cifras están en
`assets/audio/humahuaca/MANIFIESTO.md`.

| Grupo | Sonido (id del mapeo) | Archivos | Cuándo suena | Fuente |
|---|---|---|---|---|
| Ambiente | `lluvia_noche` | lluvia_noche.wav (lazo 3,3 s) | noche y alba; su nivel sigue la lluvia del ambiente (−28 dB con lluvia 0, 0 dB con lluvia 1) | documentado (llovió la noche del 1 de marzo) |
| Ambiente | `viento_quebrada` | viento_quebrada.wav (lazo 3,0 s) | siempre, salvo que el `audio_manager` ya sople el viento del Norte (hoy el controlador pide `set_environment("norte")`: entonces esta capa calla para no duplicar) | razonado |
| Ambiente | `grillos` | grillos.wav (lazo 3,3 s) | de noche; se apagan con la lluvia fuerte (−16 dB con lluvia 1) | diseño |
| Ambiente | `alba_pajaros` | alba_pajaros.wav (lazo 3,3 s) | alba y día | diseño |
| Combate | `descarga_torre` | descarga_torre.wav | **cada descarga de la torre**: cuando `render_state().tower.next_volley_in_s` vuelve a subir | documentado (la torre y su fuego) |
| Combate | `descarga_senal` | descarga_senal.wav | la señal: la descarga «que pareció cañonazo» | documentado (la descarga) / diseño (la señal) |
| Combate | `disparo` | disparo_1/2/3.wav | tiros sueltos: frentes bajo fuego, centinelas que disparan, señuelos | razonado |
| Combate | `choque_armas` | choque_armas_1/2.wav | frentes en estado `asaltado` (cuerpo a cuerpo) | razonado («sin más armas que palos») |
| Combate | `impacto` | impacto.wav | efecto `impacto` de la vista | diseño |
| Combate | `explosion_polvora` | explosion_polvora.wav | destruir pólvora | documentado |
| Combate | `brasas_humo` | brasas_humo.wav | efecto `humo` | diseño |
| Animales y carga | `cascos_mulas` | cascos_mulas_1/2.wav | agrupaciones montadas en marcha; alias de `hoof` y `dismount` | documentado (las mulas) |
| Animales y carga | `galope` | galope.wav | el mensajero realista | razonado |
| Animales y carga | `relincho_mula` | relincho_mula.wav | evento `horses`; entrada a la extracción | diseño |
| Animales y carga | `carga_bultos` | carga_bultos.wav | agrupación en `loading`; eventos `load` y `hide` | documentado (la carga) |
| Animales y carga | `pisadas` | pisadas.wav | infantería en marcha que se oye; efecto `pisadas` | diseño |
| Animales y carga | `vado_agua` | vado_agua.wav | evento `exit` (el vado); alias de `ford` | documentado (el cruce del río) |
| Señales | `corneta` | corneta.wav | entrada al ataque, apoyo, alba (toque lejano) | diseño |
| Señales | `captura` | captura.wav | frente tomado | diseño |
| Señales | `campana_alarma` | campana_alarma.wav | alarma de la guarnición | diseño (no está documentado que tocaran la campana) |
| Señales | `campana_decision` | campana_decision.wav | se abre una decisión; alias de `bell` | diseño |
| Señales | `tambor_refuerzo` | tambor_refuerzo.wav | aviso y llegada del refuerzo; columna realista a la vista | razonado |
| Interfaz | `orden_ok` / `orden_rechazada` | orden_ok.wav, orden_rechazada.wav | orden aceptada / rechazada (alias de `order` y `error`) | diseño |
| Interfaz | `alerta` | alerta.wav | alertas críticas, `detected`, `warning`, la torre que se arma o calla (alias de `alert`, `volley_warn`) | diseño |
| Interfaz | `aviso` | aviso.wav | eventos menores (información, pista, punto de control, reconocimiento); alias de `select` | diseño |
| Interfaz | `victoria` / `derrota` | victoria.wav, derrota.wav | parte de victoria / derrota | diseño |

El mapeo completo vive en `data/humahuaca_audio.json`: `events` (los 33 `EVENT_KINDS`, ninguno sin sonido), `fx` (los 7
`FX_KINDS`), `phases`, `status`, `ui`, `aliases` (los nombres que ya pide el controlador), `ambient` (capas por noche/alba/día)
y `world` (la textura que sale de `render_state()`). Cada sonido lleva `tag` y `source` con el vocabulario del nivel.

## 2. El nodo: `scripts/humahuaca/view/humahuaca_audio.gd`

`Node` con `AudioStreamPlayer` propios (uno por sonido de una vez, con polifonía, cadencia mínima, prioridad y tope de 8
voces; uno por capa ambiental, en lazo sobre una copia del recurso, como hace el `audio_manager`). Sale por los buses
`Ambiente`, `Efectos` y `UI` que crea `audio_manager.ensure_buses()` (con el limitador de Master) y, si no existen, por
`Master`. **Volumen y silencio:** lee `main.settings.volume` y `main.settings.muted` cada 0,25 s (son los mismos que obedece
el `audio_manager`; `settings` está en la lista de atributos de `main` que el controlador puede leer, CONTRATO 3.5). Silenciado
detiene los efectos y pausa las capas.

Qué escucha, sin cambiar otra capa:

- `render_state()` cada 0,1 s: la **fase** (sonido de entrada por fase), el **ambiente** (`env.phase` elige las capas; `env.rain`
  gradúa lluvia y grillos), la **torre** (cada vez que su cuenta de recarga vuelve a empezar suena `descarga_torre`) y la
  **textura del mundo**: cascos de las montadas en marcha, pasos de la infantería que se oye, carga del arreo, tiros en los
  frentes bajo fuego, choques en los asaltados y el tambor de la columna realista, cada uno con su cadencia al azar.
- `state.log` de las reglas: los **eventos** que `tick()` ya emite (señal, alarma, captura, mensajero, refuerzo, carga, destrucción,
  vado…). Se sigue por el tiempo de cada evento, así el recorte del registro (tope 400) y una partida nueva no repiten historia.
  Si el controlador reenvía los eventos con `on_events()`, deja de leer el registro.
- `hud_state()` cada 0,5 s: una decisión nueva (`campana_decision`).
- `state.status`: victoria o derrota.

**No duplica lo que el controlador ya hace sonar.** `humahuaca_ui.json` (`toasts.kinds[*].sound`) dice qué nombre pide el
controlador por cada evento; si el `audio_manager` conoce ese nombre (lo lee de sus `EFFECTS`), el evento es del controlador y el
nodo calla. En esta rama eso cubre los 18 eventos con sonido del controlador (`signal`, `alarm`, `detected`, `capture`, `tower`,
`dawn`, `recon`, `support`, `horses`, `messenger`, `reinforcement*`, `destroy`, `exit`, `decision`, `victory`, `defeat`, `warning`),
que hoy suenan con la Justina re-afinada. El nodo aporta lo que no sonaba: las capas ambientales, la torre, la textura del mundo
(cascos, pasos, carga, tiros, choques, tambor), las fases, las decisiones y los eventos sin sonido en el controlador (`shot`,
`melee`, `load`, `hide`, `loot`, `objective`, `noise`, `weather`, `hint`, `checkpoint`, `info`…). Cuando el controlador enrute
`play_sound()` por `play_ui()` (abajo), **toda** la paleta pasa a ser la del nivel: los nombres viejos se traducen por `aliases`
(`cannon` → `descarga_senal`, `capture` → `captura`, `volley_warn` → `alerta`, `alert` → `alerta`, `order` → `orden_ok`…) y los
eventos con sonido del controlador siguen a su cargo (no hay dobles).

## 3. Lo que falta enganchar (pista `ui_feel`; una línea)

El contrato (3.5) pone el audio propio bajo el controlador, así que el gancho va en `scripts/humahuaca/ui/humahuaca_ui.gd`,
que esta rama **no toca**. Al final de `start()` (después de `_build_view()`):

```gdscript
load("res://scripts/humahuaca/view/humahuaca_audio.gd").attach_to(self)
```

`attach_to()` crea el nodo `HumahuacaAudio` como hijo del controlador (se libera con él en `stop()`/`queue_free()`, sin
huérfanos), le toma `main` y `rules`, y en cada cuadro relee `rules`, `paused` y `mode` del controlador (el reintento reutiliza
las reglas con `new_game()`: el reloj vuelve atrás y el nodo reinicia su seguimiento). Si el nodo falta o no parsea, `load()`
devuelve null y la línea no hace nada: el nivel sigue sonando como hoy.

Opcionales, también de `ui_feel`, cuando quiera que **toda** la paleta sea la del nivel:

1. En `humahuaca_ui_play.gd::play_sound()`, antes de llamar al `audio_manager`:
   `var a := get_node_or_null("HumahuacaAudio"); if a != null: a.play_ui(name_text); return`
   Con eso `order`/`error`/`alert`/`cannon`/`victory`/`defeat`… suenan con los archivos de Humahuaca y el nodo deja de
   reproducir por su cuenta los eventos con sonido del controlador (no hay dobles).
2. Reemplazar `main.audio_manager.set_environment("norte")` por nada (o por `""`) para que entre `viento_quebrada` en lugar del
   viento del Norte; `stop()` ya restaura el ambiente guardado.
3. En `_handle_events()`: `if a != null: a.on_events(events)` (ahorra la lectura de `state.log`; no cambia lo que suena).

## 4. Pruebas

```sh
export APPDATA="$TEMP/ap_iso_sonido"   # perfil aislado
"$G" --headless --path . --import
"$G" --headless --path . --audio-driver Dummy --script tests/test_hx_audio.gd
```

`tests/test_hx_audio.gd` (≥ 40 comprobaciones): los WAV existen, cargan, son 44,1 kHz mono 16 bits, duran lo esperado y pesan
≤ 300 KB; los lazos enlazan sin salto; el mapeo apunta a archivos reales y no deja evento, efecto, fase, estado ni nombre del
controlador sin sonido; el nodo arranca sobre `stub_rules` y un `main` de mentira con el `audio_manager` real, carga los 32
archivos, levanta las capas de la noche, resuelve los 33 tipos de evento, distingue orden aceptada de rechazada, suena en cada
descarga de la torre, cambia las capas al alba, calla con `muted` y con volumen 0, lee `state.log` sin sonidos desconocidos,
se engancha con `attach_to()` sobre la cáscara del controlador y se libera sin huérfanos. Con el driver Dummy no hay señal que
medir: se cuenta lo que el nodo pidió reproducir. `test_hx_data`, `test_hx_view` y `test_hx_smoke` siguen verdes (ver abajo).

## 5. Análisis objetivo (`tools/analyze_audio.py --dir assets/audio/humahuaca --loops lluvia_noche,viento_quebrada,grillos,alba_pajaros --max-kb 300`)

Picos entre −13,7 y −1,5 dBFS (las descargas y la explosión en −1,5; los avisos de interfaz entre −12 y −6), RMS entre −30,6 y
−12,8 dBFS, **0 recortes** en los 32 archivos, DC 0, costuras de los cuatro lazos con razón ≤ 0,27 (salto en la costura frente al
salto típico entre muestras vecinas; el umbral es 1,0) y todos los disparos terminan en silencio (extremo final < 0,01). Salida
completa:

```text
alba_pajaros       44100 Hz 1ch  3.30s  284.3 KB  pico  -13.6 dBFS  RMS  -28.0 dBFS  recortes 0  DC 0.00000  costura 0.0094 (p99.9 vecinas 0.0350, razon 0.27)
alerta             44100 Hz 1ch  1.00s   86.2 KB  pico   -6.0 dBFS  RMS  -13.8 dBFS  recortes 0  DC 0.00000  extremo final 0.00089
aviso              44100 Hz 1ch  0.31s   26.7 KB  pico  -12.0 dBFS  RMS  -30.2 dBFS  recortes 0  DC 0.00000  extremo final 0.00000
brasas_humo        44100 Hz 1ch  1.60s  137.9 KB  pico  -10.0 dBFS  RMS  -26.5 dBFS  recortes 0  DC 0.00000  extremo final 0.00006
campana_alarma     44100 Hz 1ch  3.30s  284.3 KB  pico   -4.0 dBFS  RMS  -16.2 dBFS  recortes 0  DC 0.00000  extremo final 0.00000
campana_decision   44100 Hz 1ch  1.80s  155.1 KB  pico   -7.0 dBFS  RMS  -18.0 dBFS  recortes 0  DC 0.00000  extremo final 0.00177
captura            44100 Hz 1ch  1.25s  107.7 KB  pico   -5.0 dBFS  RMS  -13.5 dBFS  recortes 0  DC 0.00000  extremo final 0.00186
carga_bultos       44100 Hz 1ch  1.60s  137.9 KB  pico   -6.0 dBFS  RMS  -23.4 dBFS  recortes 0  DC 0.00000  extremo final 0.00058
cascos_mulas_1     44100 Hz 1ch  1.62s  139.6 KB  pico   -6.0 dBFS  RMS  -24.5 dBFS  recortes 0  DC 0.00000  extremo final 0.00198
cascos_mulas_2     44100 Hz 1ch  1.62s  139.6 KB  pico   -6.0 dBFS  RMS  -25.8 dBFS  recortes 0  DC 0.00000  extremo final 0.00128
choque_armas_1     44100 Hz 1ch  1.30s  112.0 KB  pico   -4.0 dBFS  RMS  -29.7 dBFS  recortes 0  DC 0.00000  extremo final 0.00000
choque_armas_2     44100 Hz 1ch  1.30s  112.0 KB  pico   -4.0 dBFS  RMS  -28.0 dBFS  recortes 0  DC 0.00000  extremo final 0.00000
corneta            44100 Hz 1ch  1.87s  161.1 KB  pico   -4.0 dBFS  RMS  -13.5 dBFS  recortes 0  DC 0.00000  extremo final 0.00626
derrota            44100 Hz 1ch  2.90s  249.8 KB  pico   -4.0 dBFS  RMS  -12.8 dBFS  recortes 0  DC 0.00000  extremo final 0.00107
descarga_senal     44100 Hz 1ch  3.25s  280.0 KB  pico   -1.5 dBFS  RMS  -24.3 dBFS  recortes 0  DC 0.00000  extremo final 0.00003
descarga_torre     44100 Hz 1ch  3.00s  258.4 KB  pico   -1.5 dBFS  RMS  -24.6 dBFS  recortes 0  DC 0.00000  extremo final 0.00009
disparo_1          44100 Hz 1ch  1.20s  103.4 KB  pico   -3.0 dBFS  RMS  -25.5 dBFS  recortes 0  DC 0.00000  extremo final 0.00027
disparo_2          44100 Hz 1ch  1.20s  103.4 KB  pico   -3.0 dBFS  RMS  -23.8 dBFS  recortes 0  DC 0.00000  extremo final 0.00009
disparo_3          44100 Hz 1ch  1.20s  103.4 KB  pico   -3.0 dBFS  RMS  -25.7 dBFS  recortes 0  DC 0.00000  extremo final 0.00037
explosion_polvora  44100 Hz 1ch  3.25s  280.0 KB  pico   -1.5 dBFS  RMS  -21.8 dBFS  recortes 0  DC 0.00000  extremo final 0.00037
galope             44100 Hz 1ch  1.96s  168.9 KB  pico   -5.0 dBFS  RMS  -22.7 dBFS  recortes 0  DC 0.00000  extremo final 0.00269
grillos            44100 Hz 1ch  3.30s  284.3 KB  pico  -13.7 dBFS  RMS  -30.0 dBFS  recortes 0  DC 0.00000  costura 0.0011 (p99.9 vecinas 0.1022, razon 0.01)
impacto            44100 Hz 1ch  0.65s   56.0 KB  pico   -5.0 dBFS  RMS  -26.3 dBFS  recortes 0  DC 0.00000  extremo final 0.00107
lluvia_noche       44100 Hz 1ch  3.30s  284.3 KB  pico  -10.0 dBFS  RMS  -23.0 dBFS  recortes 0  DC 0.00000  costura 0.0035 (p99.9 vecinas 0.1887, razon 0.02)
orden_ok           44100 Hz 1ch  0.45s   38.8 KB  pico   -8.0 dBFS  RMS  -24.1 dBFS  recortes 0  DC 0.00000  extremo final 0.00012
orden_rechazada    44100 Hz 1ch  0.50s   43.1 KB  pico   -8.0 dBFS  RMS  -21.2 dBFS  recortes 0  DC 0.00000  extremo final 0.00024
pisadas            44100 Hz 1ch  1.20s  103.4 KB  pico   -9.0 dBFS  RMS  -30.6 dBFS  recortes 0  DC 0.00000  extremo final 0.00089
relincho_mula      44100 Hz 1ch  1.80s  155.1 KB  pico   -5.0 dBFS  RMS  -18.7 dBFS  recortes 0  DC 0.00000  extremo final 0.00064
tambor_refuerzo    44100 Hz 1ch  3.00s  258.4 KB  pico   -8.0 dBFS  RMS  -25.9 dBFS  recortes 0  DC 0.00000  extremo final 0.00180
vado_agua          44100 Hz 1ch  2.60s  224.0 KB  pico   -6.0 dBFS  RMS  -29.3 dBFS  recortes 0  DC 0.00000  extremo final 0.00012
victoria           44100 Hz 1ch  3.10s  267.1 KB  pico   -3.0 dBFS  RMS  -16.7 dBFS  recortes 0  DC 0.00000  extremo final 0.00095
viento_quebrada    44100 Hz 1ch  3.00s  258.4 KB  pico   -9.3 dBFS  RMS  -26.0 dBFS  recortes 0  DC 0.00000  costura 0.0006 (p99.9 vecinas 0.0179, razon 0.03)
RESULTADO: OK
```

## 6. Pendientes

- **Propiedad de archivos (para el integrador).** Son de `visual` según el contrato: `scripts/humahuaca/view/humahuaca_audio.gd`,
  `assets/audio/humahuaca/**` y `tools/generate_audio_humahuaca.py`. Quedan **fuera de las listas de 1.2** y conviene un
  addendum: `data/humahuaca_audio.json` (séptimo JSON; `test_hx_data` lo tolera porque V3 solo mira los seis), `tests/test_hx_audio.gd`,
  este documento, y dos retoques compatibles a herramientas de la Justina: `tools/generate_audio.py` (siete líneas: `--humahuaca`
  delega en el generador del nivel; `python tools/generate_audio_humahuaca.py` hace lo mismo sin tocarlo) y `tools/analyze_audio.py`
  (`--dir`, `--loops` y `--max-kb`; sin argumentos sigue analizando `assets/audio/` y sus cuatro lazos, y ahora sale con 1 si
  encuentra fallas). Si la compuerta de propiedad los rechaza, los dos retoques se pueden descartar sin perder nada.
- La **escucha humana** y el ajuste fino de ganancias con placa de sonido real (acá no hay salida de audio: solo medición).
- **Paneo por frente** (va a R3 según la objeción O15 del diseño): los reproductores son mono y sin posición.
- Que `ui_feel` agregue la línea de la sección 3 (y, si quiere, las opcionales).
- `docs/CREDITOS.md` concatena los créditos de audio en [final] (compuertas y documentos): el MANIFIESTO ya dice que todo es
  original y sintetizado.
