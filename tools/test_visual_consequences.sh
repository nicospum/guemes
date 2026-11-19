#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VIEW="$ROOT/scripts/world_view.gd"

grep -q 'dust_pool' "$VIEW"
grep -q 'func _dust' "$VIEW"
grep -q '_dust(' "$VIEW"
grep -q 'water_depth_at' "$VIEW"
grep -q '_splash(' "$VIEW"

echo "visual_consequences: PASS"
