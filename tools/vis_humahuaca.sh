#!/usr/bin/env bash
# Capturas reales (con ventana, NO --headless) de la vista del nivel «Humahuaca»: corre tools/vis_humahuaca.gd con un APPDATA propio y con tope de tiempo.
# Dueña: visual (CONTRATO 1.2). Git Bash en Windows. No toca el repositorio: escribe solo en la carpeta de salida.
#
#   bash tools/vis_humahuaca.sh <carpeta de salida> [WxH] [opciones de vis_humahuaca.gd]
#
# Ejemplos (desde la raíz del worktree):
#   bash tools/vis_humahuaca.sh "$TEMP/vis_v" 1280x720 --tag=visual_r1 --extras                              # las 7 vistas canónicas + albedo, minimapa y efectos
#   bash tools/vis_humahuaca.sh "$TEMP/vis_f" 1280x720 --no-views --tag=flujo --flow=aproximacion,ataque@300,extraccion@321
#                                                                                                           # las fases por la escena real (main.tscn + controlador)
#   bash tools/vis_humahuaca.sh "$TEMP/vis_b" 1440x900 --no-views --bench --bench-tod=0.5 --bench-rain=0.42 --quality=media
# Las opciones están en el encabezado de tools/vis_humahuaca.gd. Variables: G (Godot de consola), TIMEOUT (segundos, 300 por defecto), KEEP=1 (conserva el APPDATA).
# La última línea es la de la herramienta («VIS_HUMAHUACA {...}») y el código de salida es el suyo (0 si no hubo fallas, 124 si se pasó del tope).

set -u
OUT="${1:-}"
[ -n "$OUT" ] || { sed -n '2,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 2; }
shift
SIZE="1280x720"
case "${1:-}" in
  [0-9]*x[0-9]*) SIZE="$1"; shift ;;
esac

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$(cd "$SELF_DIR/.." && pwd)"
T="${TEMP:-/tmp}"
if command -v cygpath >/dev/null 2>&1; then
  SRC="$(cygpath -m "$SRC")"
  T="$(cygpath -m "$T")"
  OUT="$(cygpath -m "$OUT")"
fi
MAIN_REPO_GODOT="C:/Users/User/Desktop/spum/IA/Proyectos/MaravillaArgentina/guemes/patria-guemes/.tools/godot/Godot_v4.7.2-stable_win64_console.exe"
if [ -z "${G:-}" ]; then
  if [ -f "$SRC/.tools/godot/Godot_v4.7.2-stable_win64_console.exe" ]; then G="$SRC/.tools/godot/Godot_v4.7.2-stable_win64_console.exe"; else G="$MAIN_REPO_GODOT"; fi
fi
[ -f "$G" ] || { echo "vis_humahuaca.sh: no encuentro Godot en «$G» (definí G con la ruta del ejecutable de consola)" >&2; exit 2; }

export APPDATA="$T/ap_iso_hx_visual_$$"
rm -rf "$APPDATA"
mkdir -p "$APPDATA" "$OUT"
timeout "${TIMEOUT:-300}" "$G" --path "$SRC" --resolution "$SIZE" --audio-driver Dummy --script tools/vis_humahuaca.gd -- --out="$OUT" "$@" 2>&1 \
  | grep -v -E '^(Godot Engine|Vulkan|OpenGL)' | grep -v '^$'
STATUS=${PIPESTATUS[0]}
[ "${KEEP:-0}" = "1" ] || rm -rf "$APPDATA"
exit "$STATUS"
