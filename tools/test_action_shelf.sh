#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAIN="$ROOT/scripts/main.gd"

grep -q 'advanced_actions_open' "$MAIN"
grep -q 'Más acciones' "$MAIN"
grep -q 'advanced_action_ids' "$MAIN"
grep -Eq 'advanced_actions_open[[:space:]]*=[[:space:]]*false' "$MAIN"
grep -q '_focus_advanced_toggle' "$MAIN"

echo "action_shelf: PASS"
