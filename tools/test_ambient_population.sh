#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VIEW="$ROOT/scripts/world_view.gd"

grep -q '_ambient_population' "$VIEW"
grep -q 'PoblacionAmbiental' "$VIEW"
grep -q 'persona_arriero_1817_lod' "$VIEW"
grep -q 'persona_voluntario_1806_lod' "$VIEW"
grep -q 'persona_gaucho_1817_lod' "$VIEW"
grep -q 'persona_realista_1817_lod' "$VIEW"

echo "ambient_population: PASS"
