#!/usr/bin/env bash
# Compuerta del nivel «Humahuaca» (CONTRATO 6.4 y 5.3; QA_NIVEL2.md, P1). Dueño: compuertas y documentos. Git Bash en Windows.
#
#   tools/qa_gate.sh quick <pista>   RÁPIDA: cada pista, antes de pedir el merge (corre desde el worktree de la pista)
#   tools/qa_gate.sh full            COMPLETA: cierre de ronda (integrador y compuertas), con ventana real para ui_qa, benchmark y --qa
#   <pista>: relieve | reglas | visual | ui | integrador   (también: relieve_mapa, reglas_historia, ui_feel, compuertas)
#
# La rápida corre: (1) importación; (2) archivos protegidos contra el hash fijo BASE (no contra main) y tope de líneas en los compartidos;
# (3) test_rules --skip-strategies (>= 818, sin fallas); (4) test_integration (>= 283, sin fallas); (5) test_hx_data y test_hx_smoke;
# (6) la prueba propia de la pista (test_hx_terrain|rules|view|flow; obligatoria desde r1); más los entregables de R1.0 de la pista (r1.0),
# la higiene de Git y la limpieza de los registros. La completa suma test_rules completo (>= 871), Jev (15), audio (17 con 1 falla aceptada),
# las cuatro pruebas del nivel, ui_qa x3 (>= 254), justina_playthrough, --scenario y --qa de Humahuaca y benchmark.py (Justina y Norte <= 3 ms). Desde r1 suma las herramientas
# del nivel (herramientas_hx): ui_qa_humahuaca x3, humahuaca_playthrough (por reglas, y por la escena real: humahuaca_escena, el criterio de cierre de R1), el recorrido de QA
# (hx_qa_tour, con las vistas en acción), el arnés del agente-jugador con --selftest hasta la victoria (hx_agent_play), el reintento tras una derrota (hx_agent_reintento) y con un agente
# de guion por archivos (hx_agent_partida: la partida del --selftest repetida por archivos; hx_agent_protocolo y hx_agent_viejos) y la verificación por la escena real de visual (vis_flow).
# La última línea es siempre «GATE <modo> ...: PASA|FALLA|PARCIAL | cifras». Sale con 0 (PASA), 1 (FALLA), 2 (uso o entorno) o 3 (PARCIAL).
#
# Variables opcionales:
#   RONDA   r0 | r1.0 | r1 | r2a | r2b | r3 | r4   (por defecto, la línea «Ronda vigente:» de docs/humahuaca/TRAZA.md; la cambia el integrador)
#   G       Godot de consola (por defecto, el de .tools/godot de este repo o, en un worktree, el del repo principal)
#   SKIP    pasos a omitir, separados por coma (la compuerta queda PARCIAL): import,protegidos,compartidos,propiedad,rules,integracion,data,smoke,pista,etapa,higiene
#           y, en full: jev_audio,scenario,qa_humahuaca,ui_qa,justina_playthrough,benchmark,herramientas_hx
#   KEEP    1 = conserva los registros y el perfil aislado aunque pase
# Cada corrida usa su propio APPDATA aislado (TEMP/ap_iso_hx_gate_<pista>_<pid>), un timeout por paso (con corte del árbol de procesos
# de Godot) y no abre ni imprime .env* ni jev.cfg. Los registros quedan en TEMP/hx_gate_<modo>_<pista>_<pid> si algo falla.

BASE=5ebbd28   # hash fijo de la línea base de la Justina y el Norte (CONTRATO 1.3): un hash, no una etiqueta, para no tocar `git tag --list`
ORIGIN_MAIN_FROZEN=72077c8655f8489109950a24b0b09db14af7563c   # punta de origin/main al congelar (QA E05): si cambia, alguien hizo push
MAIN_REPO_GODOT="C:/Users/User/Desktop/spum/IA/Proyectos/MaravillaArgentina/guemes/patria-guemes/.tools/godot/Godot_v4.7.2-stable_win64_console.exe"

ROUNDS=(r0 r1.0 r1 r2a r2b r3 r4)
NFAIL=0
declare -a R_NAME R_STATE R_INFO
declare -A FIG

usage() {   # el encabezado de este archivo (hasta la primera línea que no es comentario)
  awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "${BASH_SOURCE[0]}"
}

die() {
  echo "qa_gate: $*" >&2
  exit 2
}

# ---------------------------------------------------------------------------------------------------------------------
# Argumentos y entorno

MODE="${1:-}"
case "$MODE" in
  quick)
    [ -n "${2:-}" ] || die "falta la pista: tools/qa_gate.sh quick <relieve|reglas|visual|ui|integrador>"
    case "$2" in
      relieve|relieve_mapa|terrain) PISTA=relieve; OWN=terrain ;;
      reglas|reglas_historia|rules) PISTA=reglas; OWN=rules ;;
      visual|view) PISTA=visual; OWN=view ;;
      ui|ui_feel|flow) PISTA=ui; OWN=flow ;;
      integrador|compuertas|integracion) PISTA=integrador; OWN="" ;;
      *) die "pista desconocida «$2» (relieve, reglas, visual, ui o integrador)" ;;
    esac ;;
  full) PISTA=integrador; OWN="" ;;
  help|-h|--help|"") usage; exit 0 ;;
  *) die "modo desconocido «$MODE» (quick <pista> o full)" ;;
esac

if [ "$MODE" = quick ]; then LABEL="quick $PISTA"; else LABEL="full"; fi
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$(cd "$SELF_DIR/.." && pwd)"
if command -v cygpath >/dev/null 2>&1; then
  SRC="$(cygpath -m "$SRC")"
  T="$(cygpath -m "${TEMP:-/tmp}")"
else
  T="${TEMP:-/tmp}"
fi
git -C "$SRC" rev-parse --git-dir >/dev/null 2>&1 || die "$SRC no es un repositorio Git"

if [ -z "${G:-}" ]; then
  if [ -f "$SRC/.tools/godot/Godot_v4.7.2-stable_win64_console.exe" ]; then
    G="$SRC/.tools/godot/Godot_v4.7.2-stable_win64_console.exe"   # ruta absoluta: los worktrees no tienen .tools, por eso el respaldo de abajo
  else
    G="$MAIN_REPO_GODOT"
  fi
fi
[ -f "$G" ] || die "no encuentro Godot en «$G» (definí G con la ruta del ejecutable de consola)"
PY=python
command -v python >/dev/null 2>&1 || PY=python3
command -v "$PY" >/dev/null 2>&1 || die "hace falta Python (python -I) para leer los informes JSON"
py() { "$PY" -I -X utf8 "$@"; }   # modo aislado y UTF-8: los informes y los mensajes van en UTF-8 aunque la consola de Windows use otra página de códigos

if [ -z "${RONDA:-}" ]; then
  RONDA="$(sed -n 's/^Ronda vigente: \(r[0-9a-z.]*\).*/\1/p' "$SRC/docs/humahuaca/TRAZA.md" 2>/dev/null | head -n 1 | tr -d '\r')"
fi
RONDA="${RONDA:-r0}"

round_idx() {
  local i=0 r
  for r in "${ROUNDS[@]}"; do
    if [ "$r" = "$1" ]; then echo "$i"; return; fi
    i=$((i + 1))
  done
  echo -1
}
round_ge() { [ "$(round_idx "$1")" -ge "$(round_idx "$2")" ]; }
[ "$(round_idx "$RONDA")" -ge 0 ] || die "ronda desconocida «$RONDA» (${ROUNDS[*]})"

# Pisos de comprobaciones por ronda (CONTRATO 5.1): solo pueden subir.
floor_for() {
  case "$1" in
    data) if round_ge "$RONDA" r2a; then echo 60; else echo 40; fi ;;
    smoke) echo 25 ;;
    terrain) if round_ge "$RONDA" r2a; then echo 80; else echo 60; fi ;;
    rules) if round_ge "$RONDA" r2b; then echo 400; elif round_ge "$RONDA" r2a; then echo 250; else echo 150; fi ;;
    view) if round_ge "$RONDA" r2a; then echo 40; else echo 25; fi ;;
    flow) if round_ge "$RONDA" r2a; then echo 80; else echo 50; fi ;;
  esac
}

# ---------------------------------------------------------------------------------------------------------------------
# APPDATA aislado, registros y limpieza

setup_isolation() {
  LOGD="$T/hx_gate_${MODE}_${PISTA}_$$"
  APPDATA="$T/ap_iso_hx_gate_${PISTA}_$$"
  export APPDATA
  export GODOT_SILENCE_ROOT_WARNING=1
  rm -rf "$LOGD" "$APPDATA"
  mkdir -p "$LOGD" "$APPDATA"
}

cleanup() {
  rm -rf "$APPDATA" 2>/dev/null
  if [ "${KEEP:-0}" != "1" ] && [ "$NFAIL" -eq 0 ] && [ -z "${PARTIAL:-}" ]; then
    rm -rf "$LOGD" 2>/dev/null
  fi
}

skipped() {
  case ",${SKIP:-}," in
    *",$1,"*) PARTIAL="${PARTIAL:+$PARTIAL,}$1"; record "$1" OMITIDO "pedido en SKIP; la compuerta queda PARCIAL"; return 0 ;;
  esac
  return 1
}

record() {  # record <paso> <PASA|FALLA|OMITIDO|N/A|AVISO> <detalle>
  R_NAME+=("$1"); R_STATE+=("$2"); R_INFO+=("$3")
  printf '  [%-7s] %-18s %s\n' "$2" "$1" "$3"
  if [ "$2" = "FALLA" ]; then NFAIL=$((NFAIL + 1)); fi
}

# ---------------------------------------------------------------------------------------------------------------------
# Ejecución con timeout y corte del árbol de procesos

kill_tree() {  # el ejecutable de consola de Godot lanza al motor como hijo: `timeout` solo mataría al envoltorio
  local pid="$1" winpid=""
  if [ -r "/proc/$pid/winpid" ]; then winpid="$(cat "/proc/$pid/winpid" 2>/dev/null)"; fi
  if [ -n "$winpid" ] && command -v taskkill >/dev/null 2>&1; then
    MSYS2_ARG_CONV_EXCL='*' taskkill /F /T /PID "$winpid" >/dev/null 2>&1
  fi
  kill -9 "$pid" 2>/dev/null
}

run_proc() {  # run_proc <segundos> <registro> <comando...>   → RC (124 si se cortó por tiempo)
  local tmo="$1" log="$2"; shift 2
  "$@" > "$log" 2>&1 &
  local pid=$! waited=0 limit=$((tmo * 4))
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$waited" -ge "$limit" ]; then
      kill_tree "$pid"
      wait "$pid" 2>/dev/null
      RC=124
      return 124
    fi
    sleep 0.25
    waited=$((waited + 1))
  done
  wait "$pid"
  RC=$?
  return "$RC"
}

run_godot() {  # run_godot <segundos> <registro> <argumentos de Godot...>
  local tmo="$1" log="$2"; shift 2
  run_proc "$tmo" "$log" "$G" "$@"
}

fmt_time() { printf '%d min %02d s' $(($1 / 60)) $(($1 % 60)); }

# ---------------------------------------------------------------------------------------------------------------------
# Lectura de informes

json_last() {  # la última línea de un registro que es un objeto JSON (con o sin prefijo en mayúsculas), como `lastjson` del QA
  tr -d '\r' < "$1" | grep -E '^([A-Z_]+ )?\{' | tail -n 1 | sed -E 's/^[A-Z_]+ //'
}

suite_numbers() {  # → "checks fallas ok pendientes" o NOJSON
  json_last "$1" | py -c '
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    print("NOJSON"); sys.exit(0)
fails = d.get("failures", []) or []
print(d.get("checks", "?"), len(fails), str(d.get("ok", len(fails) == 0)).lower(), len(d.get("pending", []) or []))'
}

show_failures() {  # las primeras fallas de una suite (máximo 6, cortadas a 330 caracteres)
  json_last "$1" | py -c '
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for f in (d.get("failures") or [])[:6]:
    print("      · " + str(f)[:330])
more = len(d.get("failures") or []) - 6
if more > 0:
    print("      · … y %d más" % more)'
}

# Ejecuta una suite de Godot sin ventana y la juzga: salida 0 o 1 con su JSON final, `ok`, sin fallas y con el piso de comprobaciones.
run_suite() {  # run_suite <paso> <clave> <piso> <segundos> <registro> <argumentos de Godot...>
  local step="$1" key="$2" floor="$3" tmo="$4" log="$5"; shift 5
  local started=$SECONDS nums checks fails ok pend verdict detail
  run_godot "$tmo" "$log" --headless --path "$SRC" "$@"
  if [ "$RC" -eq 124 ]; then
    record "$step" FALLA "se cortó por timeout a los ${tmo} s (registro: $log.falla)"; mv "$log" "$log.falla" 2>/dev/null; return
  fi
  nums="$(suite_numbers "$log")"
  if [ "$nums" = "NOJSON" ] || [ -z "$nums" ]; then
    record "$step" FALLA "no imprimió su JSON final (salida $RC); últimas líneas: $(tail -n 3 "$log" | tr -d '\r' | tr '\n' ' ' | cut -c1-260)"; return
  fi
  read -r checks fails ok pend <<< "$nums"
  FIG[$key]="$checks/$fails"
  detail="$checks comprobaciones, $fails fallas, piso $floor, $(fmt_time $((SECONDS - started)))"
  if [ "$pend" != "0" ]; then detail="$detail, $pend pendientes de rondas futuras"; fi
  verdict=PASA
  if [ "$ok" != "true" ] || [ "$fails" != "0" ]; then verdict=FALLA; fi
  if ! [[ "$checks" =~ ^[0-9]+$ ]] || [ "$checks" -lt "$floor" ]; then verdict=FALLA; detail="$detail (menos del piso $floor)"; fi
  if [ "$RC" -ne 0 ] && [ "$verdict" = PASA ]; then verdict=FALLA; detail="$detail (salió con $RC)"; fi
  record "$step" "$verdict" "$detail"
  if [ "$verdict" = FALLA ]; then
    show_failures "$log"
    mv "$log" "$log.falla" 2>/dev/null   # la falla ya está informada: salida_limpia no la cuenta por segunda vez
  fi
}

# ---------------------------------------------------------------------------------------------------------------------
# Pasos

step_import() {
  skipped import && return
  local started=$SECONDS
  run_godot 300 "$LOGD/import.log" --headless --path "$SRC" --import
  if [ "$RC" -ne 0 ]; then record import FALLA "--import salió con $RC (registro: $LOGD/import.log)"; return; fi
  if tr -d '\r' < "$LOGD/import.log" | grep -qE '^(SCRIPT ERROR|SHADER ERROR|Parse Error)'; then
    record import FALLA "--import informó errores de script o de shader (registro: $LOGD/import.log)"; return
  fi
  record import PASA "proyecto importado en $(fmt_time $((SECONDS - started)))"
}

protected_list() {  # los archivos protegidos (CONTRATO 1.3 y QA P1-a): 14 fijos más los shaders y modelos de la línea base
  {
    printf '%s\n' scripts/game_rules.gd scripts/world_view.gd scripts/campaign.gd scripts/audio_manager.gd scripts/jev_client.gd data/justina_map.json \
      tests/test_rules.gd tools/create_models.py tools/justina_playthrough.gd tools/vis_shots.gd tools/vis_r5.gd tools/bench_gpu.gd \
      shaders/terrain_justina_r4.gdshader shaders/water_rio_plata.gdshader
    git -C "$SRC" ls-tree -r --name-only "$BASE" -- shaders assets | grep -E '^(shaders/justina_|assets/[^/]+\.gdshader$|assets/models/[^/]+\.glb$)'
  } | sort -u
}

step_protected() {
  skipped protegidos && return
  if ! git -C "$SRC" cat-file -e "$BASE^{commit}" 2>/dev/null; then
    record protegidos FALLA "el commit base $BASE no existe en este repositorio"; return
  fi
  local prot=() n changed
  mapfile -t prot < <(protected_list | tr -d '\r')
  n=${#prot[@]}
  changed="$(git -C "$SRC" diff --name-only "$BASE" -- "${prot[@]}" | tr -d '\r')"
  FIG[protegidos]="$n"
  if [ -z "$changed" ]; then PROT_OK=1; fi   # la regla de ruido del benchmark solo vale si no se tocó nada de la Justina ni del Norte
  if [ -n "$changed" ] && [ "$MODE" = quick ] && [ "$PISTA" != integrador ]; then
    record protegidos FALLA "$(printf '%s\n' "$changed" | wc -l | tr -d ' ') de $n archivos protegidos cambiaron contra $BASE: $(printf '%s' "$changed" | tr '\n' ' ' | cut -c1-300)"
  elif [ -n "$changed" ]; then
    PROT_OK=1
    record protegidos PASA "$(printf '%s\n' "$changed" | wc -l | tr -d ' ') de $n archivos de la base $BASE evolucionaron por el encargo multi-nivel (QA enmienda 8; regresión cubierta por T02 y T04)"
  elif [ "$n" -ne 40 ]; then
    record protegidos AVISO "$n archivos protegidos intactos contra $BASE (la rúbrica T01 cuenta 40; revisar la lista)"
  else
    record protegidos PASA "$n archivos protegidos intactos contra $BASE"
  fi
}

numstat_within() {  # numstat_within <archivo> <máx. agregadas> <máx. borradas>  → imprime «+a/-d» y devuelve 1 si se pasa
  local file="$1" max_add="$2" max_del="$3" add=0 del=0
  read -r add del _ < <(git -C "$SRC" diff --numstat "$BASE" -- "$file")
  add="${add:-0}"; del="${del:-0}"
  if ! [[ "$add" =~ ^[0-9]+$ ]]; then add=0; del=0; fi
  printf '+%s/-%s' "$add" "$del"
  [ "$add" -le "$max_add" ] && [ "$del" -le "$max_del" ]
}

step_shared() {
  skipped compartidos && return
  local bad="" out lines
  out="$(numstat_within scripts/main.gd 80 10)" || { if [ "$MODE" = quick ] && [ "$PISTA" != integrador ]; then bad="$bad main.gd $out (tope +80/-10)"; fi; }
  lines="main.gd $out"
  out="$(numstat_within tests/test_integration.gd 6 2)" || { if [ "$MODE" = quick ] && [ "$PISTA" != integrador ]; then bad="$bad test_integration.gd $out (tope +6/-2)"; fi; }
  lines="$lines, test_integration $out"
  out="$(numstat_within tools/ui_qa.gd 6 2)" || { if [ "$MODE" = quick ] && [ "$PISTA" != integrador ]; then bad="$bad ui_qa.gd $out (tope +6/-2)"; fi; }
  lines="$lines, ui_qa $out"
  out="$(numstat_within tools/run_qa.py 4 2)" || { if [ "$MODE" = quick ] && [ "$PISTA" != integrador ]; then bad="$bad run_qa.py $out (tope +4/-2)"; fi; }
  lines="$lines, run_qa $out"
  local loose
  loose="$(git -C "$SRC" log --format=%s -- docs/QA_NIVEL2.md | sed '$d' | grep -vc '^QA enmienda [0-9]\+:')"
  if [ "${loose:-0}" != "0" ]; then bad="$bad docs/QA_NIVEL2.md tiene $loose commits que no se titulan «QA enmienda N:»"; fi
  if [ -n "$bad" ]; then record compartidos FALLA "$bad"; else record compartidos PASA "$lines (QA enmienda 8: encargo multi-nivel; commits de QA_NIVEL2 titulados)"; fi
}

# Propiedad exclusiva de archivos por pista (CONTRATO 1.2). Los .uid y .import de un archivo siguen a su dueño.
owner_allows() {  # owner_allows <pista> <ruta relativa>  → 0 si la pista es dueña de esa ruta
  local p="$1" f="$2"
  f="${f%.uid}"; f="${f%.import}"
  case "$f" in evidence/humahuaca/*) return 0 ;; esac
  case "$p" in
    relieve)
      case "$f" in
        scripts/humahuaca/terrain/*|scripts/humahuaca/stubs/stub_terrain.gd|data/humahuaca_map.json|data/humahuaca_height.json|tools/build_humahuaca_terrain.py|tests/test_hx_terrain.gd|docs/humahuaca/RELIEVE.md|docs/humahuaca/CREDITOS_RELIEVE.md) return 0 ;;
      esac ;;
    reglas)
      case "$f" in
        scripts/humahuaca/rules/*|scripts/humahuaca/stubs/stub_rules*.gd|scripts/humahuaca/stubs/stub_progress.gd|data/humahuaca_rules.json|data/humahuaca_level.json|data/history.json|tests/test_hx_rules.gd|tests/hx_rules_checks.gd|tools/humahuaca_playthrough.gd|docs/humahuaca/REGLAS.md|docs/humahuaca/HISTORIA.md|docs/humahuaca/PROCEDENCIA.md|docs/historia/MATRIZ_HISTORICA.md|docs/historia/FUENTES.md) return 0 ;;
      esac ;;
    visual)
      case "$f" in
        scripts/humahuaca/view/*|scripts/humahuaca/stubs/stub_view.gd|shaders/humahuaca_*|assets/models/humahuaca/*|assets/audio/humahuaca/*|data/humahuaca_visual.json|tools/vis_humahuaca.gd|tools/vis_humahuaca.sh|tools/generate_audio_humahuaca.py|tests/test_hx_view.gd|docs/humahuaca/VISUAL.md|docs/humahuaca/CREDITOS_VISUAL.md|docs/ASSETS.md) return 0 ;;
      esac ;;
    ui)
      case "$f" in
        scripts/humahuaca/ui/*|data/humahuaca_ui.json|tools/ui_qa_humahuaca.gd|tests/test_hx_flow.gd|docs/humahuaca/CONTROLES.md) return 0 ;;
      esac ;;
  esac
  return 1
}

# Una rama de pista solo toca lo suyo (CONTRATO 1.2: propiedad exclusiva por pista). Modificar, renombrar o borrar un archivo que ya existía en main
# fuera de lo propio es una violación de contrato y falla; un archivo NUEVO fuera de lo propio se avisa. Compara contra el punto donde la rama salió de main.
step_ownership() {
  if [ "$MODE" != quick ] || [ "$PISTA" = integrador ]; then return; fi
  skipped propiedad && return
  local mb status f g bad="" added="" n=0
  mb="$(git -C "$SRC" merge-base HEAD main 2>/dev/null)"
  if [ -z "$mb" ]; then record propiedad N/A "no encuentro la rama main para comparar los archivos de la pista"; return; fi
  while IFS=$'\t' read -r status f g; do
    [ -n "$f" ] || continue
    n=$((n + 1))
    case "$status" in
      A*) owner_allows "$PISTA" "$f" || added="$added $f" ;;
      R*|C*) owner_allows "$PISTA" "$f" || bad="$bad $f"; owner_allows "$PISTA" "$g" || bad="$bad $g" ;;
      *) owner_allows "$PISTA" "$f" || bad="$bad $f" ;;
    esac
  done < <(git -C "$SRC" diff --name-status "$mb" | tr -d '\r')
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    n=$((n + 1))
    owner_allows "$PISTA" "$f" || added="$added $f"
  done < <(git -C "$SRC" ls-files --others --exclude-standard | tr -d '\r')
  if [ -n "$bad" ]; then
    record propiedad FALLA "la pista $PISTA tocó archivos que no son suyos (CONTRATO 1.2):$(printf '%s' "$bad" | cut -c1-360); si hace falta, se pide por escrito al integrador"
  elif [ -n "$added" ]; then
    record propiedad AVISO "$n archivos cambiados; nuevos fuera de lo propio de la pista $PISTA:$(printf '%s' "$added" | cut -c1-300)"
  else
    record propiedad PASA "$n archivos cambiados desde main y todos son de la pista $PISTA"
  fi
}

step_rules() {
  skipped rules && return
  if [ "$MODE" = "full" ]; then
    run_suite rules rules 871 900 "$LOGD/rules.log" --script tests/test_rules.gd
  else
    run_suite rules rules 818 420 "$LOGD/rules.log" --script tests/test_rules.gd -- --skip-strategies
  fi
}

step_integration() {
  skipped integracion && return
  run_suite integracion integracion 283 300 "$LOGD/integration.log" --script tests/test_integration.gd
}

step_jev_audio() {
  skipped jev_audio && return
  run_suite jev jev 15 180 "$LOGD/jev.log" --script tests/jev_contract_test.gd
  local started=$SECONDS line n f other
  run_godot 180 "$LOGD/audio.log" --headless --path "$SRC" --script tests/audio_runtime_test.gd
  line="$(tr -d '\r' < "$LOGD/audio.log" | grep -E '^RESULTADO: ' | tail -n 1)"
  n="$(printf '%s' "$line" | sed -nE 's/^RESULTADO: ([0-9]+) comprobaciones, ([0-9]+) fallas.*/\1/p')"
  f="$(printf '%s' "$line" | sed -nE 's/^RESULTADO: ([0-9]+) comprobaciones, ([0-9]+) fallas.*/\2/p')"
  other="$(tr -d '\r' < "$LOGD/audio.log" | grep -E '^FALLA: ' | grep -vc '^FALLA: driver de audio real (no Dummy)$')"
  if [ -n "$n" ] && [ "$n" -ge 17 ] && [ "$f" = "1" ] && [ "${other:-1}" = "0" ] && [ "$RC" -ne 124 ]; then
    FIG[audio]="$n/$f"
    record audio PASA "$n comprobaciones y 1 falla aceptada (driver de audio real, no Dummy), $(fmt_time $((SECONDS - started)))"
  else
    record audio FALLA "esperaba «RESULTADO: >=17 comprobaciones, 1 fallas» con la única falla del driver Dummy; salió con «$line» y $other fallas distintas (salida $RC)"
  fi
}

# Pruebas del nivel (CONTRATO 5.1). Obligatorias desde r1 las de las pistas; test_hx_data y test_hx_smoke, siempre.
run_hx_suite() {  # run_hx_suite <data|smoke|terrain|rules|view|flow> [argumentos extra de la prueba]
  local s="$1"; shift
  local file="tests/test_hx_${s}.gd" floor
  floor="$(floor_for "$s")"
  if [ ! -f "$SRC/$file" ]; then
    if [ "$s" = data ] || [ "$s" = smoke ] || round_ge "$RONDA" r1; then
      record "hx_$s" FALLA "falta $file (obligatoria en $RONDA; piso $floor)"
    else
      record "hx_$s" N/A "$file todavía no existe (la entrega su dueño en R1; obligatoria desde r1)"
    fi
    return
  fi
  run_suite "hx_$s" "hx_$s" "$floor" 300 "$LOGD/hx_$s.log" --script "$file" -- "--ronda=$RONDA" "$@"
}

step_hx_suites() {
  local pista_arg=()
  if [ "$MODE" = quick ] && [ "$PISTA" != integrador ]; then pista_arg=("--pista=$PISTA"); fi
  if ! skipped data; then run_hx_suite data "${pista_arg[@]}"; fi
  if ! skipped smoke; then run_hx_suite smoke; fi
  if [ "$MODE" = quick ]; then
    if [ -n "$OWN" ] && ! skipped pista; then
      if [ "$OWN" = rules ]; then run_hx_suite rules --skip-strategies; else run_hx_suite "$OWN"; fi
    fi
  else
    run_hx_suite terrain
    run_hx_suite rules
    run_hx_suite view
    run_hx_suite flow
  fi
}

# Entregables de R1.0 (CONTRATO 8.1): el stub de la propia pista debe existir desde r1.0; todos, y la cáscara reemplazada, desde r1.
step_stages() {
  skipped etapa && return
  if ! round_ge "$RONDA" r1.0; then record etapa N/A "los stubs de las pistas se exigen desde r1.0 (ronda vigente: $RONDA)"; return; fi
  local want=() missing="" f
  if [ "$MODE" = full ] || [ "$PISTA" = integrador ] || round_ge "$RONDA" r1; then   # el integrador (rápida o completa) exige los cuatro stubs
    want=(scripts/humahuaca/stubs/stub_terrain.gd scripts/humahuaca/stubs/stub_rules.gd scripts/humahuaca/stubs/stub_progress.gd scripts/humahuaca/stubs/stub_view.gd)
  else
    case "$PISTA" in
      relieve) want=(scripts/humahuaca/stubs/stub_terrain.gd) ;;
      reglas) want=(scripts/humahuaca/stubs/stub_rules.gd scripts/humahuaca/stubs/stub_progress.gd) ;;
      visual) want=(scripts/humahuaca/stubs/stub_view.gd) ;;
    esac
  fi
  for f in "${want[@]}"; do [ -f "$SRC/$f" ] || missing="$missing $f"; done
  # la interfaz: ui/humahuaca_ui.gd tiene que ser la primera versión del controlador y no la copia de la cáscara
  if [ "$PISTA" = ui ] || [ "$MODE" = full ] || round_ge "$RONDA" r1; then
    if [ ! -f "$SRC/scripts/humahuaca/ui/humahuaca_ui.gd" ]; then
      missing="$missing scripts/humahuaca/ui/humahuaca_ui.gd"
    elif cmp -s "$SRC/scripts/humahuaca/ui/humahuaca_ui.gd" "$SRC/scripts/humahuaca/stubs/stub_ui.gd"; then
      missing="$missing (scripts/humahuaca/ui/humahuaca_ui.gd sigue siendo la copia de la cáscara)"
    fi
  fi
  if [ -n "$missing" ]; then record etapa FALLA "faltan entregables de R1.0:$missing"; else record etapa PASA "entregables de R1.0 presentes (${#want[@]} stubs y el controlador)"; fi
}

step_hygiene() {
  skipped higiene && return
  local bad="" tags secret bin blend
  tags="$(git -C "$SRC" tag --list | tr -d '\r' | tr '\n' ' ' | sed 's/ $//')"
  # enmienda 5: las etiquetas deben ser exactamente las que ya existían (v0.1.0, v0.2.0-alpha, v0.3.0-alpha); ninguna nueva ni movida
  if [ "$tags" != "v0.1.0 v0.2.0-alpha v0.3.0-alpha" ]; then bad="$bad etiquetas={$tags} (deben ser v0.1.0 v0.2.0-alpha v0.3.0-alpha, sin agregar ni mover);"; fi
  secret="$(git -C "$SRC" ls-files | grep -E '(^|/)(\.env[^/]*|jev\.cfg|[^/]*\.key)$' | head -n 3 | tr '\n' ' ')"
  if [ -n "$secret" ]; then bad="$bad hay archivos de secretos versionados: $secret;"; fi
  bin="$(git -C "$SRC" ls-files '*.tif' '*.exe' '*.zip' | head -n 3 | tr '\n' ' ')"
  if [ -n "$bin" ]; then bad="$bad hay binarios versionados que no van a Git: $bin;"; fi
  blend="$(git -C "$SRC" diff --name-only --diff-filter=A "$BASE" -- '*.blend' '*.glb' ':!assets/models/humahuaca/' ':!assets/models/' | head -n 3 | tr '\n' ' ')"
  if [ -n "$blend" ]; then bad="$bad modelos nuevos fuera de assets/models/: $blend;"; fi
  if [ -n "$bad" ]; then record higiene FALLA "$bad"; else record higiene PASA "etiquetas = las tres de siempre, sin secretos, binarios ni archivos .blend versionados (QA enmienda 8)"; fi
  local origin
  origin="$(git -C "$SRC" rev-parse origin/main 2>/dev/null | tr -d '\r')"
  if [ -n "$origin" ] && [ "$origin" != "$ORIGIN_MAIN_FROZEN" ]; then
    record push AVISO "origin/main está en ${origin:0:12} y al congelar estaba en ${ORIGIN_MAIN_FROZEN:0:12}: ¿alguien hizo push o fetch? (E05)"
  fi
}

scan_logs() {  # la salida limpia de la rúbrica (T05): ni errores de script o de shader, ni fugas, ni cuelgues; los WARNING solo se cuentan
  local bad warn
  bad="$(find "$LOGD" -name '*.log' -print0 | xargs -0 -r cat | tr -d '\r' | grep -nE '^(SCRIPT ERROR|SHADER ERROR|USER ERROR|Parse Error|ERROR:|FATAL|Segmentation|Assertion failed)|ObjectDB instances leaked|resources still in use at exit|Leaked instance|leaked at exit' | head -n 5)"
  warn="$(find "$LOGD" -name '*.log' -print0 | xargs -0 -r cat | tr -d '\r' | grep -cE '^WARNING:')"
  if [ -n "$bad" ]; then
    record salida_limpia FALLA "los registros traen errores o fugas: $(printf '%s' "$bad" | tr '\n' ' ' | cut -c1-420)"
  else
    record salida_limpia PASA "ningún SCRIPT ERROR, SHADER ERROR, Parse Error, ERROR: ni fuga en los registros (${warn:-0} WARNING contados)"
  fi
}

# ---- Pasos de la compuerta completa -------------------------------------------------------------------------------------

step_scenario_flag() {
  skipped scenario && return
  local started=$SECONDS
  run_godot 120 "$LOGD/scenario_hx.log" --headless --path "$SRC" --quit-after 200 -- --scenario=humahuaca
  if [ "$RC" -eq 0 ] && ! tr -d '\r' < "$LOGD/scenario_hx.log" | grep -qE '^(SCRIPT ERROR|Parse Error)'; then
    record scenario PASA "--scenario=humahuaca abre el nivel directo y sale con 0 ($(fmt_time $((SECONDS - started))))"
  else
    record scenario FALLA "--scenario=humahuaca salió con $RC o con errores de script (registro: $LOGD/scenario_hx.log)"
  fi
}

report_numbers() {  # report_numbers <json de ui_qa> → "checks fallas captura resolucion_real"
  py - "$1" <<'EOF'
import json, sys
try:
    d = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception:
    print("NOJSON"); sys.exit(0)
n = d.get("notes", {}) or {}
cap = n.get("captura_px")
if isinstance(cap, (list, tuple)) and len(cap) == 2:
    cap = "%sx%s" % (int(cap[0]), int(cap[1]))
print(d.get("checks", "?"), len(d.get("failures", []) or []), cap, str(n.get("resolucion_real")).lower())
EOF
}

step_ui_qa() {
  skipped ui_qa && return
  local S out nums checks fails cap real started
  for S in 1280x720 1920x1080 2560x1440; do
    started=$SECONDS
    out="$LOGD/uiqa_$S"; mkdir -p "$out"
    run_godot 600 "$LOGD/uiqa_$S.log" --path "$SRC" --resolution "$S" --audio-driver Dummy --script tools/ui_qa.gd -- "--out=$out" "--size=$S"
    nums="$(report_numbers "$out/ui_qa_report.json")"
    if [ "$nums" = "NOJSON" ]; then record "ui_qa_$S" FALLA "no escribió ui_qa_report.json (salida $RC; registro: $LOGD/uiqa_$S.log.falla)"; mv "$LOGD/uiqa_$S.log" "$LOGD/uiqa_$S.log.falla" 2>/dev/null; continue; fi   # la falla ya está informada: salida_limpia no la cuenta por segunda vez
    read -r checks fails cap real <<< "$nums"
    FIG["ui_qa_$S"]="$checks/$fails"
    if [ "$RC" -eq 0 ] && [ "$fails" = "0" ] && [ "$checks" -ge 254 ] && [ "$cap" = "$S" ] && [ "$real" = "true" ]; then
      record "ui_qa_$S" PASA "$checks comprobaciones, $fails fallas, captura $cap real, $(fmt_time $((SECONDS - started)))"
    else
      record "ui_qa_$S" FALLA "$checks comprobaciones (piso 254), $fails fallas, captura $cap (pedida $S), resolución real: $real, salida $RC (registro: $LOGD/uiqa_$S.log.falla)"
      mv "$LOGD/uiqa_$S.log" "$LOGD/uiqa_$S.log.falla" 2>/dev/null
    fi
  done
}

step_justina_playthrough() {
  skipped justina_playthrough && return
  local started=$SECONDS out="$LOGD/justina-playthrough.json" line
  run_godot 900 "$LOGD/justina_playthrough.log" --path "$SRC" --resolution 1440x900 --audio-driver Dummy --script tools/justina_playthrough.gd -- "--out=$out"
  line="$(py - "$out" <<'EOF'
import json, sys
try:
    p = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception:
    print("NOJSON"); sys.exit(0)
print(p.get("victories"), len(p.get("victory_styles", [])), len(p.get("victory_routes", [])), p.get("defeats"), str(p.get("ui_real_victory")).lower())
EOF
)"
  if [ "$line" = "NOJSON" ]; then record justina_playthrough FALLA "no escribió su informe (salida $RC)"; return; fi
  local vic styles routes defeats ui
  read -r vic styles routes defeats ui <<< "$line"
  if [ "$RC" -eq 0 ] && [ "$styles" -ge 3 ] && [ "$routes" -ge 2 ] && [ "$defeats" -ge 1 ] && [ "$ui" = "true" ]; then
    record justina_playthrough PASA "$vic victorias, $styles estilos, $routes rutas, $defeats derrotas, el bot de interfaz gana ($(fmt_time $((SECONDS - started))))"
  else
    record justina_playthrough FALLA "$vic victorias, $styles estilos (min 3), $routes rutas (min 2), $defeats derrotas (min 1), ui_real_victory=$ui, salida $RC"
  fi
}

step_qa_humahuaca() {
  skipped qa_humahuaca && return
  local out="$LOGD/qa_hx" pngs need=1 started=$SECONDS
  mkdir -p "$out"
  run_godot 300 "$LOGD/qa_humahuaca.log" --path "$SRC" --resolution 1280x720 --audio-driver Dummy -- --qa=humahuaca "--qa-path=$out" --qa-size=1280x720
  pngs="$(find "$out" -name '*.png' | wc -l | tr -d ' ')"
  if round_ge "$RONDA" r1; then need=8; fi   # r1: menú más las 7 vistas canónicas
  if [ "$RC" -eq 0 ] && [ -f "$out/qa_report.json" ] && [ "$pngs" -ge "$need" ]; then
    record qa_humahuaca PASA "--qa=humahuaca salió con 0, escribió qa_report.json y $pngs capturas (mínimo $need), $(fmt_time $((SECONDS - started)))"
  else
    record qa_humahuaca FALLA "--qa=humahuaca salió con $RC; qa_report.json: $([ -f "$out/qa_report.json" ] && echo sí || echo no); capturas: $pngs (mínimo $need)"
  fi
}

step_benchmark() {
  skipped benchmark && return
  local started=$SECONDS out="$LOGD/bench" rows noisy="" note="" rc_final
  run_proc 1200 "$LOGD/bench_regresion.log" "$PY" "$SRC/tools/benchmark.py" --binary "$G" --project "$SRC" --output "$out" --profiles media --scenarios justine,norte --repeat 3 --renderer forward_plus --max-frame-ms 3
  rc_final=$RC
  # Regla de ruido de la rúbrica (P3): si la Justina o el Norte pasan de 3,0 ms pero su media de medias es de 3,0 o menos y no se tocó nada suyo
  # (los protegidos pasaron), se repite UNA vez ese escenario solo y vale el reintento.
  if [ "$rc_final" -eq 2 ] && [ -f "$out/resumen.json" ] && [ "${PROT_OK:-0}" = "1" ]; then
    noisy="$(py - "$out/resumen.json" <<'EOF'
import json, sys
r = json.load(open(sys.argv[1], encoding="utf-8"))
bad = [x for x in r if x["frame_ms_mean_max"] > 3.0]
print(",".join(x["scenario"] for x in bad) if bad and all(x["frame_ms_mean_mean"] <= 3.0 for x in bad) else "")
EOF
)"
    if [ -n "$noisy" ]; then
      run_proc 1200 "$LOGD/bench_reintento.log" "$PY" "$SRC/tools/benchmark.py" --binary "$G" --project "$SRC" --output "$LOGD/bench_reintento" --profiles media --scenarios "$noisy" --repeat 3 --renderer forward_plus --max-frame-ms 3
      rc_final=$RC
      note=" (la regla de ruido repitió una vez: $noisy)"
    fi
  fi
  rows="$(py - "$out/resumen.json" "$LOGD/bench_reintento/resumen.json" <<'EOF'
import json, os, sys
try:
    r = {x["scenario"]: x for x in json.load(open(sys.argv[1], encoding="utf-8"))}
except Exception:
    print("NOJSON"); sys.exit(0)
if os.path.exists(sys.argv[2]):
    for x in json.load(open(sys.argv[2], encoding="utf-8")):
        r[x["scenario"]] = x
print(" ".join("%s=%.2f" % (k, v["frame_ms_mean_max"]) for k, v in r.items()))
EOF
)"
  if [ "$rc_final" -eq 0 ] && [ "$rows" != "NOJSON" ]; then
    record benchmark PASA "cuadro medio (peor de 3 repeticiones, ms): $rows; tope 3,0 ms$note; $(fmt_time $((SECONDS - started)))"
  else
    record benchmark FALLA "salió con $rc_final; cuadro medio: $rows (tope 3,0 ms)$note"
  fi
  if round_ge "$RONDA" r1; then
    run_proc 1800 "$LOGD/bench_hx.log" "$PY" "$SRC/tools/benchmark.py" --binary "$G" --project "$SRC" --output "$LOGD/bench_hx" --profiles baja,media,alta --scenarios humahuaca --repeat 3 --renderer forward_plus --max-frame-ms 6
    rows="$(py - "$LOGD/bench_hx/resumen.json" <<'EOF'
import json, sys
B = {"baja": 2.5, "media": 4.0, "alta": 6.0}
try:
    r = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception:
    print("NOJSON"); sys.exit(0)
ok = True; out = []
for x in r:
    q = x["quality"]; good = x["frame_ms_mean_max"] <= B[q]
    if q == "media": good = good and x["frame_ms_p95_mean"] <= 8.3 and x["scene_build_ms_mean"] <= 1500; ok = ok and good
    out.append("%s=%.2f%s" % (q, x["frame_ms_mean_max"], "" if good else "!"))
print(("OK " if ok else "MAL ") + " ".join(out))
EOF
)"
    case "$rows" in
      OK*) record benchmark_hx PASA "Humahuaca por perfil (ms, peor media): ${rows#OK }; compuerta en «media» (4,0 ms, p95 8,3, construcción 1 500 ms)" ;;
      *) record benchmark_hx FALLA "Humahuaca fuera de presupuesto o sin informe: $rows (salida $RC)" ;;
    esac
  else
    record benchmark_hx N/A "el presupuesto de Humahuaca se mide desde r1 (la cáscara de R0 no dibuja nada)"
  fi
}

# Desde r1: las herramientas del nivel que escriben las pistas. Si todavía no existen, no se pueden evaluar y eso es una falla.
step_level_tools() {
  skipped herramientas_hx && return
  local tool S out nums checks fails floor
  if ! round_ge "$RONDA" r1; then
    record herramientas_hx N/A "ui_qa_humahuaca, humahuaca_playthrough y hx_qa_tour se exigen desde r1 (ronda vigente: $RONDA)"; return
  fi
  for tool in ui_qa_humahuaca humahuaca_playthrough hx_qa_tour hx_agent_play; do
    if [ ! -f "$SRC/tools/$tool.gd" ]; then record "$tool" FALLA "falta tools/$tool.gd (no evaluable = falla)"; fi
  done
  if [ -f "$SRC/tools/ui_qa_humahuaca.gd" ]; then
    floor=120; if ! round_ge "$RONDA" r2a; then floor=60; fi
    for S in 1280x720 1920x1080 2560x1440; do
      out="$LOGD/uiqa_hx_$S"; mkdir -p "$out"
      run_godot 600 "$LOGD/uiqa_hx_$S.log" --path "$SRC" --resolution "$S" --audio-driver Dummy --script tools/ui_qa_humahuaca.gd -- "--out=$out" "--size=$S"
      nums="$(report_numbers "$out/ui_qa_report.json")"
      if [ "$nums" = "NOJSON" ]; then record "ui_qa_hx_$S" FALLA "no escribió ui_qa_report.json (salida $RC; registro: $LOGD/uiqa_hx_$S.log.falla)"; mv "$LOGD/uiqa_hx_$S.log" "$LOGD/uiqa_hx_$S.log.falla" 2>/dev/null; continue; fi
      read -r checks fails _ _ <<< "$nums"
      # r1: completo a 1280x720 y chequeo de desborde en las otras dos; desde r2a, completo a las tres (el piso se aplica a las completas)
      if [ "$S" != 1280x720 ] && ! round_ge "$RONDA" r2a; then floor=1; fi
      if [ "$RC" -eq 0 ] && [ "$fails" = "0" ] && [ "$checks" -ge "$floor" ]; then
        record "ui_qa_hx_$S" PASA "$checks comprobaciones, $fails fallas (piso $floor)"
      else
        record "ui_qa_hx_$S" FALLA "$checks comprobaciones (piso $floor), $fails fallas, salida $RC (registro: $LOGD/uiqa_hx_$S.log.falla)"
        mv "$LOGD/uiqa_hx_$S.log" "$LOGD/uiqa_hx_$S.log.falla" 2>/dev/null
      fi
    done
  fi
  if [ -f "$SRC/tools/humahuaca_playthrough.gd" ]; then
    run_godot 900 "$LOGD/hx_playthrough.log" --headless --path "$SRC" --script tools/humahuaca_playthrough.gd -- --level=rules --policies=experto,pasivo "--out=$LOGD/hx_playthrough.json"
    if [ "$RC" -eq 0 ]; then record humahuaca_playthrough PASA "sale con 0: el experto gana y el pasivo pierde"; else record humahuaca_playthrough FALLA "salió con $RC (registro: $LOGD/hx_playthrough.log)"; fi
    # el criterio de cierre de R1 (CONTRATO 8.2): «el experto gana y el pasivo pierde por la escena real». El mismo recorrido, pero por main.tscn con el controlador real y ventana
    # (semillas de calibración 3, 5 y 7). La política «interfaz» aprieta el botón del «siguiente paso»: se informa cuántas gana y no decide el paso.
    local escena_started=$SECONDS
    out="$LOGD/hx_escena"; mkdir -p "$out"
    run_godot 600 "$LOGD/hx_escena.log" --path "$SRC" --resolution 1280x720 --audio-driver Dummy --disable-vsync --script tools/humahuaca_playthrough.gd -- --level=scene --policies=experto,pasivo,interfaz --seeds=3,5,7 "--out=$out/hx_escena.json" --quiet
    nums="$(py - "$out/hx_escena.json" <<'EOF'
import json, sys
try:
    r = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception:
    print("NOJSON"); sys.exit(0)
g = r.get("games", [])
def n(policy, status=None, cause=None):
    return sum(1 for x in g if x.get("policy") == policy and (status is None or x.get("status") == status) and (cause is None or x.get("cause_id") == cause))
print(n("experto", "victory"), n("experto"), n("pasivo", "victory"), n("pasivo"), n("pasivo", "defeat", "amanecio"), n("interfaz", "victory"), n("interfaz"),
      sum(int(x.get("exceptions", 0) or 0) for x in g), r.get("level"))
EOF
)"
    if [ "$nums" = "NOJSON" ]; then
      record humahuaca_escena FALLA "no escribió su informe (salida $RC; registro: $LOGD/hx_escena.log)"
    else
      read -r ewin etot pwin ptot pdawn iwin itot eexc elevel <<< "$nums"
      if [ "$RC" -eq 0 ] && [ "$elevel" = scene ] && [ "$etot" -ge 3 ] && [ "$ewin" = "$etot" ] && [ "$ptot" -ge 3 ] && [ "$pwin" = 0 ] && [ "$pdawn" = "$ptot" ] && [ "$eexc" = 0 ]; then
        record humahuaca_escena PASA "por la escena real el experto gana $ewin de $etot, el pasivo pierde $ptot de $ptot (todos por amanecio) y el bot de interfaz gana $iwin de $itot, sin excepciones, $(fmt_time $((SECONDS - escena_started)))"
      else
        record humahuaca_escena FALLA "salió con $RC; nivel $elevel; experto gana $ewin de $etot (pide todas, mínimo 3), pasivo gana $pwin de $ptot (pide 0; por amanecio $pdawn), interfaz $iwin de $itot, excepciones $eexc (registro: $LOGD/hx_escena.log)"
      fi
    fi
  fi
  # el recorrido de QA por la escena real (Q2): las 7 vistas con y sin interfaz, la calibración de albedo, los límites de cámara, la hoja de fichas, los nombres de la escena
  # y qa_report.json. Con --disable-vsync, porque frame_ms_mean solo vale sin sincronía vertical.
  if [ -f "$SRC/tools/hx_qa_tour.gd" ]; then
    out="$LOGD/hx_tour"; mkdir -p "$out"
    run_godot 300 "$LOGD/hx_tour.log" --path "$SRC" --resolution 1280x720 --audio-driver Dummy --disable-vsync --script tools/hx_qa_tour.gd -- "--out=$out" --size=1280x720
    nums="$(py - "$out/qa_report.json" <<'EOF'
import json, sys
try:
    r = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception:
    print("NOJSON"); sys.exit(0)
png = [a for a in r.get("archivos", []) if a.endswith(".png")]
brecha = r.get("brecha_decision_s") or {}
print(len(png), len(r.get("failures", [])), len(r.get("views", {})), r.get("initial_frame", {}).get("fits"), r.get("templo_aabb_h_m"), r.get("frame_ms_mean"), (r.get("bot") or {}).get("status", "sin_bot"),
      (r.get("jerga") or {}).get("aciertos", "?"), (r.get("desbordes_texto") or {}).get("controles", "?"), brecha.get("max", "?"), brecha.get("ataque_max", "?"), (r.get("gramatica") or {}).get("aciertos", "?"),
      (r.get("escala") or {}).get("px_por_unidad_logica", "?"),
      sum(1 for v in (r.get("en_accion") or {}).values() if isinstance(v, dict) and v.get("capturada")), (r.get("frame_ms_ataque") or {}).get("mean", "?"))
EOF
)"
    if [ "$nums" = "NOJSON" ]; then
      record hx_qa_tour FALLA "no escribió qa_report.json (salida $RC; registro: $LOGD/hx_tour.log)"
    else
      read -r tpng tfails tviews tfits taabb tframe tbot tjerga tdesb tgap tgapa tgram tesc tacc tatk <<< "$nums"
      if [ "$RC" -eq 0 ] && [ "$tfails" = "0" ] && [ "$tpng" -ge 27 ] && [ "$tviews" -ge 7 ] && [ "$tfits" = "True" ] && [ "$tacc" = "2" ]; then
        record hx_qa_tour PASA "$tpng capturas, 7 vistas, cuadro inicial con los tres objetivos y la partida, templo ${taabb} m, cuadro medio ${tframe} ms (indicativo) y ${tatk} ms en pleno ataque, el bot ${tbot}, vistas en acción ${tacc} de 2 (torre disparando y arreo cargando); texto del bot: jerga ${tjerga}, desbordes ${tdesb}, brecha sin siguiente paso ${tgap} s (ataque ${tgapa} s), contracciones sin hacer ${tgram} (informativo); posiciones en píxeles de la captura (x${tesc})"
      else
        record hx_qa_tour FALLA "salió con $RC; $tpng capturas (mínimo 27: 7 vistas con y sin interfaz, el primer cuadro, 3 de albedo, 4 de límite, la hoja de fichas y las 4 de las vistas en acción), $tfails fallas, $tviews vistas, initial_frame.fits=$tfits, vistas en acción $tacc de 2"
      fi
    fi
  else
    record hx_qa_tour FALLA "falta tools/hx_qa_tour.gd (no evaluable = falla)"
  fi
  # el arnés del agente-jugador (Q8): el lazo de punta a punta con el arnés contestando solo (--selftest: aprieta el botón del «siguiente paso» como quien obedece la guía; no es una corrida
  # del agente). La primera orden entra por clic a ≤ 8 turnos y ≤ 40 s de juego (J08) y la partida llega al parte de victoria y cierra con respuestas.json (en R1 el selftest de 30 turnos
  # perdía el primer ataque porque daba la señal apenas un aviso la ofrecía: no probaba el final). La corrida del agente de verdad la hace el Jefe de QA.
  if [ -f "$SRC/tools/hx_agent_play.gd" ]; then
    out="$LOGD/hx_agent"; mkdir -p "$out"
    run_godot 300 "$LOGD/hx_agent.log" --path "$SRC" --resolution 1280x720 --audio-driver Dummy --disable-vsync --script tools/hx_agent_play.gd -- "--turns-dir=$out" "--out=$out/arnes.json" --step-s=3 --max-turns=150 --selftest
    nums="$(py - "$out/arnes.json" <<'EOF'
import json, sys
try:
    a = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception:
    print("NOJSON"); sys.exit(0)
it = a.get("intentos", [])
last = it[-1] if it else {}
print(a.get("schema"), len(a.get("turnos", [])), a.get("primera_orden_turno"), a.get("primera_orden_t_s"), "x".join(str(v) for v in a.get("captura_px", [])), a.get("cierre"), last.get("resultado", "sin_intentos"), last.get("t_juego_s", 0))
EOF
)"
    if [ "$nums" = "NOJSON" ]; then
      record hx_agent_play FALLA "no escribió arnes.json (salida $RC; registro: $LOGD/hx_agent.log)"
    else
      read -r aschema aturns aorder atime acap aclose aresult asecs <<< "$nums"
      if [ "$RC" -eq 0 ] && [ "$aschema" = "hx_agente_v1" ] && [ "$aturns" -ge 20 ] && [ "$aorder" -ge 1 ] && [ "$aorder" -le 8 ] && [ "$acap" = "1280x720" ] && [ "$aclose" = respuestas ] && [ "$aresult" = victory ] && py -c "import sys; sys.exit(0 if 0 <= float('$atime') <= 40 else 1)"; then
        record hx_agent_play PASA "arnés hx_agente_v1: $aturns turnos con capturas de $acap, primera orden aceptada en el turno $aorder (${atime} s de juego), la partida llegó a la victoria a los ${asecs} s de juego y cerró con $aclose (selftest, no es el agente)"
      else
        record hx_agent_play FALLA "salió con $RC; esquema $aschema, $aturns turnos, primera orden en el turno $aorder a los $atime s, captura $acap, cierre $aclose (pide respuestas), último intento $aresult (pide victory) (registro: $LOGD/hx_agent.log)"
      fi
    fi
  else
    record hx_agent_play FALLA "falta tools/hx_agent_play.gd (no evaluable = falla)"
  fi
  # una partida por turnos con un guion (TR-217): las acciones que el arnés aplicó en el --selftest las repite un agente de guion por el protocolo de archivos (espera cada turno_NN.png,
  # escribe accion_NN.json, la mitad a medias) y el arnés tiene que dar la misma partida turno a turno: acción, tiempo de juego, órdenes aceptadas, fase, modo, primera orden y desenlace.
  # No juega: prueba que el protocolo por archivos no cambia la partida. La corrida del agente de verdad (J08) la hace el Jefe de QA.
  if [ -f "$SRC/tools/hx_agent_play.gd" ] && [ -f "$SRC/tools/hx_agent_guion.py" ]; then
    local ppid prc pwaited pline pnums pturns pchecks psecs rturns pstarted=$SECONDS
    out="$LOGD/hx_agent_partida"; mkdir -p "$out"
    rturns="$(py -c "import json, sys; print(len(json.load(open(sys.argv[1], encoding='utf-8'))['turnos']))" "$LOGD/hx_agent/arnes.json" 2>/dev/null)"   # la repetición tiene los mismos turnos que la referencia
    if [ ! -f "$LOGD/hx_agent/arnes.json" ] || [ -z "$rturns" ]; then
      record hx_agent_partida FALLA "no hay arnes.json del --selftest con qué comparar (no evaluable = falla)"
    else
      "$G" --path "$SRC" --resolution 1280x720 --audio-driver Dummy --disable-vsync --script tools/hx_agent_play.gd -- "--turns-dir=$out" "--out=$out/arnes.json" --step-s=3 --max-turns="$rturns" --wait-s=60 > "$LOGD/hx_agent_partida.log" 2>&1 &
      ppid=$!
      py "$SRC/tools/hx_agent_guion.py" --turns-dir "$out" --arnes "$out/arnes.json" --guion "repetir:$LOGD/hx_agent/arnes.json" --timeout 120 --log "$out/guion.json" > "$LOGD/hx_agent_partida_guion.log" 2>&1
      prc=$?
      pwaited=0
      while kill -0 "$ppid" 2>/dev/null && [ "$pwaited" -lt 80 ]; do sleep 0.25; pwaited=$((pwaited + 1)); done   # el arnés sale solo después de escribir arnes.json
      if kill -0 "$ppid" 2>/dev/null; then kill_tree "$ppid"; fi
      wait "$ppid" 2>/dev/null
      pline="$(json_last "$LOGD/hx_agent_partida_guion.log")"
      pnums="$(printf '%s' "$pline" | py -c 'import json,sys; d=json.load(sys.stdin); print(d["turnos"], d["comprobaciones"], d["duracion_s"])' 2>/dev/null)"
      if [ "$prc" -eq 0 ] && [ -n "$pnums" ]; then
        read -r pturns pchecks psecs <<< "$pnums"
        record hx_agent_partida PASA "la partida del --selftest repetida por archivos da lo mismo turno a turno: $pturns turnos, $pchecks comprobaciones (acción, aplicada, orden aceptada, modo, diálogo, fase y tiempo de juego, primera orden e intentos), ${psecs} s; $(fmt_time $((SECONDS - pstarted)))"
      else
        record hx_agent_partida FALLA "el agente de guion salió con $prc; $(tr -d '\r' < "$LOGD/hx_agent_partida_guion.log" | tail -n 3 | cut -c1-420 | tr '\n' ' ') (registros: $LOGD/hx_agent_partida.log y $out/guion.json)"
      fi
    fi
  fi
  # el reintento por el arnés (J08: «si perdés, podés reintentar»): con --selftest=pasivo el primer intento no hace nada y pierde por el alba (amanecio); el arnés aprieta el «Reintentar» del parte
  # y el segundo intento sigue el «siguiente paso» hasta la victoria. Prueba el parte de derrota, su botón y el intento nuevo por la interfaz real; no es una corrida del agente.
  if [ -f "$SRC/tools/hx_agent_play.gd" ]; then
    local rn rfirst rcause rlast rclose rturns2 rsecs
    out="$LOGD/hx_agent_reintento"; mkdir -p "$out"
    run_godot 300 "$LOGD/hx_agent_reintento.log" --path "$SRC" --resolution 1280x720 --audio-driver Dummy --disable-vsync --script tools/hx_agent_play.gd -- "--turns-dir=$out" "--out=$out/arnes.json" --step-s=3 --max-turns=150 --selftest=pasivo
    nums="$(py - "$out/arnes.json" <<'EOF'
import json, sys
try:
    a = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception:
    print("NOJSON"); sys.exit(0)
it = a.get("intentos", [])
first = it[0] if it else {}
last = it[-1] if it else {}
print(len(it), first.get("resultado", "?"), first.get("cause_id") or "-", last.get("resultado", "?"), a.get("cierre"), len(a.get("turnos", [])), last.get("t_juego_s", 0))
EOF
)"
    if [ "$nums" = "NOJSON" ]; then
      record hx_agent_reintento FALLA "no escribió arnes.json (salida $RC; registro: $LOGD/hx_agent_reintento.log)"
    else
      read -r rn rfirst rcause rlast rclose rturns2 rsecs <<< "$nums"
      if [ "$RC" -eq 0 ] && [ "$rn" -ge 2 ] && [ "$rfirst" = defeat ] && [ "$rcause" = amanecio ] && [ "$rlast" = victory ] && [ "$rclose" = respuestas ]; then
        record hx_agent_reintento PASA "el primer intento pasivo perdió por amanecio, el arnés apretó «Reintentar» en el parte y el intento $rn ganó a los ${rsecs} s de juego; cerró con $rclose en $rturns2 turnos (selftest, no es el agente)"
      else
        record hx_agent_reintento FALLA "salió con $RC; $rn intentos, el primero $rfirst ($rcause) y el último $rlast (pide defeat por amanecio y victory), cierre $rclose (pide respuestas) (registro: $LOGD/hx_agent_reintento.log)"
      fi
    fi
  fi
  # el protocolo por archivos con un «agente» de guion (tools/hx_agent_guion.py): lo que --selftest no recorre porque el arnés contesta solo (esperar accion_NN.json, lectura a medias,
  # JSON roto, clic fuera de la ventana, tipo desconocido, respuestas.json y los tres frentes nombrados en la bitácora). No juega: prueba que el arnés lee, aplica, mide y cierra.
  # La corrida del agente de verdad (J08) la hace el Jefe de QA.
  if [ -f "$SRC/tools/hx_agent_play.gd" ] && [ -f "$SRC/tools/hx_agent_guion.py" ]; then
    local gpid grc gwaited gline gnums
    out="$LOGD/hx_agent_protocolo"; mkdir -p "$out"
    "$G" --path "$SRC" --resolution 1280x720 --audio-driver Dummy --disable-vsync --script tools/hx_agent_play.gd -- "--turns-dir=$out" "--out=$out/arnes.json" --step-s=2 --max-turns=40 --wait-s=60 > "$LOGD/hx_agent_protocolo.log" 2>&1 &
    gpid=$!
    py "$SRC/tools/hx_agent_guion.py" --turns-dir "$out" --arnes "$out/arnes.json" --timeout 90 --log "$out/guion.json" > "$LOGD/hx_agent_guion.log" 2>&1
    grc=$?
    gwaited=0
    while kill -0 "$gpid" 2>/dev/null && [ "$gwaited" -lt 80 ]; do sleep 0.25; gwaited=$((gwaited + 1)); done   # el arnés sale solo después de escribir arnes.json
    if kill -0 "$gpid" 2>/dev/null; then kill_tree "$gpid"; fi
    wait "$gpid" 2>/dev/null
    gline="$(json_last "$LOGD/hx_agent_guion.log")"
    gnums="$(printf '%s' "$gline" | py -c 'import json,sys; d=json.load(sys.stdin); print(d["turnos"], d["comprobaciones"], d["duracion_s"])' 2>/dev/null)"
    if [ "$grc" -eq 0 ] && [ -n "$gnums" ]; then
      read -r gturns gchecks gsecs <<< "$gnums"
      record hx_agent_protocolo PASA "el arnés atendió un agente de guion por archivos: $gturns turnos, $gchecks comprobaciones sin fallas (acción a medias, JSON roto, clic fuera de la ventana, tipo desconocido, respuestas.json y bitácora), ${gsecs} s"
    else
      record hx_agent_protocolo FALLA "el agente de guion salió con $grc; $(tr -d '\r' < "$LOGD/hx_agent_guion.log" | tail -n 3 | cut -c1-360 | tr '\n' ' ') (registros: $LOGD/hx_agent_protocolo.log y $out/guion.json)"
    fi
    # archivos de una corrida anterior en la carpeta de turnos: el arnés los borra al arrancar (no los consume), no toca la bitácora del agente y, sin acciones nuevas, abandona
    out="$LOGD/hx_agent_viejos"; mkdir -p "$out"
    printf '%s' '{"tipo":"esperar","s":1}' > "$out/accion_01.json"
    printf '%s' '{"objetivo":"viejo"}' > "$out/respuestas.json"
    printf '%s' 'no es un png' > "$out/turno_01.png"
    printf '%s' 'la bitacora del agente no se toca' > "$out/bitacora.md"
    run_godot 120 "$LOGD/hx_agent_viejos.log" --path "$SRC" --resolution 1280x720 --audio-driver Dummy --disable-vsync --script tools/hx_agent_play.gd -- "--turns-dir=$out" "--out=$out/arnes.json" --max-turns=5 --wait-s=4
    gnums="$(py - "$out/arnes.json" "$out/bitacora.md" "$out/fin.json" <<'EOF'
import json, sys
try:
    a = json.load(open(sys.argv[1], encoding="utf-8"))
    bit = open(sys.argv[2], encoding="utf-8").read()
except Exception:
    print("NOJSON"); sys.exit(0)
try:
    fin = json.load(open(sys.argv[3], encoding="utf-8")).get("cierre", "sin_cierre")
except Exception:
    fin = "sin_fin"
print(a.get("cierre"), len(a.get("turnos", [])), a.get("archivos_viejos_borrados"), "intacta" if bit == "la bitacora del agente no se toca" else "tocada", fin)
EOF
)"
    if [ "$gnums" = "NOJSON" ]; then
      record hx_agent_viejos FALLA "no escribió arnes.json (salida $RC; registro: $LOGD/hx_agent_viejos.log)"
    else
      read -r vclose vturns vstale vbit vfin <<< "$gnums"
      if [ "$RC" -eq 0 ] && [ "$vclose" = abandono ] && [ "$vturns" = 0 ] && [ "$vstale" = 3 ] && [ "$vbit" = intacta ] && [ "$vfin" = abandono ]; then
        record hx_agent_viejos PASA "con una acción, unas respuestas y una captura viejas en la carpeta: las borró (3), no tocó la bitácora, abandonó a los 4 s sin contestar con lo viejo y dejó fin.json con el cierre (abandono)"
      else
        record hx_agent_viejos FALLA "cierre $vclose (esperaba abandono), $vturns turnos (esperaba 0), $vstale archivos viejos borrados (esperaba 3), bitácora $vbit, fin.json $vfin (esperaba abandono), salida $RC"
      fi
    fi
  fi
  # lo que solo se ve por la escena real (VP-13, B-024): fichas a escala real (QA enmienda 6; antes ≥ 48 px), el alba sin naranja saturado y los anillos de visibilidad sin cruces
  if [ -f "$SRC/tools/vis_humahuaca.sh" ]; then
    out="$LOGD/vis_flow"; mkdir -p "$out"
    run_proc 360 "$LOGD/vis_flow.log" env TIMEOUT=300 bash "$SRC/tools/vis_humahuaca.sh" "$out" 1280x720 --no-views --flow=aproximacion,ataque@300,extraccion@321
    line="$(tr -d '\r' < "$LOGD/vis_flow.log" | grep -E '^VIS_HUMAHUACA ' | tail -n 1)"
    if [ "$RC" -eq 0 ] && printf '%s' "$line" | grep -q '"fallas":0'; then
      record vis_flow PASA "escena real por tools/vis_humahuaca.sh --flow: 0 fallas (fichas, alba y anillos)"
    else
      record vis_flow FALLA "salió con $RC; $line"
    fi
  fi
}

# ---------------------------------------------------------------------------------------------------------------------

final_line() {
  local state parts="" key figs="" failed="" i
  if [ "$NFAIL" -gt 0 ]; then
    state="FALLA ($NFAIL pasos)"
    for i in "${!R_NAME[@]}"; do
      if [ "${R_STATE[$i]}" = FALLA ]; then failed="${failed:+$failed, }${R_NAME[$i]}"; fi
    done
  elif [ -n "${PARTIAL:-}" ]; then
    state="PARCIAL (omitido: $PARTIAL)"
  else
    state="PASA"
  fi
  for key in protegidos rules integracion jev audio hx_data hx_smoke hx_terrain hx_rules hx_view hx_flow ui_qa_1280x720 ui_qa_1920x1080 ui_qa_2560x1440; do
    if [ -n "${FIG[$key]:-}" ]; then figs="$figs | $key ${FIG[$key]}"; fi
  done
  echo
  echo "GATE $LABEL ($RONDA): $state$figs${failed:+ | falla: $failed} | $(fmt_time $SECONDS)"
  if [ "$NFAIL" -gt 0 ]; then echo "(registros en $LOGD; KEEP=1 conserva también el perfil aislado)"; fi
}

main() {
  setup_isolation
  trap cleanup EXIT
  echo "qa_gate $LABEL · ronda $RONDA · base $BASE · $SRC"
  echo "  Godot: $G"
  echo "  perfil aislado: $APPDATA"
  step_import
  step_protected
  step_shared
  step_ownership
  step_rules
  step_integration
  step_hx_suites
  step_stages
  step_hygiene
  if [ "$MODE" = full ]; then
    step_jev_audio
    step_scenario_flag
    step_qa_humahuaca
    step_ui_qa
    step_justina_playthrough
    step_benchmark
    step_level_tools
  fi
  scan_logs
  final_line "$@"
  if [ "$NFAIL" -gt 0 ]; then return 1; fi
  if [ -n "${PARTIAL:-}" ]; then return 3; fi
  return 0
}

main "$@"
RC_FINAL=$?
exit "$RC_FINAL"
