#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCENE="$ROOT/scenes/lab/assets_mvp.tscn"
SCRIPT="$ROOT/scripts/tools/assets_mvp_lab.gd"

test -f "$SCENE"
test -f "$SCRIPT"
test -f "$ROOT/assets/lab/UAL1_Standard.glb"
test -f "$ROOT/assets/models/rider_1817.glb"
test -f "$ROOT/assets/models/arma_carabina.glb"
grep -q 'assets/lab/UAL1_Standard.glb' "$SCRIPT"
grep -q 'assets/models/rider_1817.glb' "$SCRIPT"
grep -q 'assets/models/arma_carabina.glb' "$SCRIPT"
grep -q 'look_at_from_position' "$SCRIPT"
grep -q 'get_tree().quit(1)' "$SCRIPT"
grep -q 'Baseline propio' "$SCRIPT"
test -f "$ROOT/docs/superpowers/evidence/assets-mvp-sources.md"

PROJECT_PATH="${PROJECT_PATH:-C:\Users\User\Desktop\spum\IA\Proyectos\MaravillaArgentina\guemes\patria-guemes}"
GODOT="${GODOT_BIN:-/mnt/c/Users/User/Desktop/spum/IA/Proyectos/MaravillaArgentina/guemes/patria-guemes/.tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
if [ ! -x "$GODOT" ]; then
	echo "assets_mvp: Godot executable not found: $GODOT" >&2
	exit 1
fi
mkdir -p /tmp/opencode
"$GODOT" --headless --path "$PROJECT_PATH" --editor --quit >/tmp/opencode/assets-mvp-import.log 2>&1
"$GODOT" --headless --path "$PROJECT_PATH" --scene 'res://scenes/lab/assets_mvp.tscn' --quit-after 2 >/tmp/opencode/assets-mvp-godot.log 2>&1
if grep -Eiq '(^|[^[:alpha:]])(error|failed|missing)([^[:alpha:]]|$)' /tmp/opencode/assets-mvp-import.log /tmp/opencode/assets-mvp-godot.log; then
	echo "assets_mvp: log contains an import/runtime error" >&2
	exit 1
fi

echo "assets_mvp: PASS"
