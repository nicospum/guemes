#!/bin/sh
# Corre los tests headless con APPDATA aislado y resume. Uso: sh tools/vis_tests.sh
G="C:/Users/User/Desktop/spum/IA/Proyectos/MaravillaArgentina/guemes/patria-guemes/.tools/godot/Godot_v4.7.2-stable_win64_console.exe"
export APPDATA="$TEMP/ap_iso_tests"
mkdir -p "$APPDATA"
"$G" --headless --path . --script tests/test_rules.gd > "$TEMP/p1_rules.txt" 2>&1
"$G" --headless --path . --script tests/test_integration.gd > "$TEMP/p1_integ.txt" 2>&1
echo "rules:"; grep -o '"failures":\[[^]]*\]' "$TEMP/p1_rules.txt" | head -2
echo "integration:"; grep -o '"failures":\[[^]]*\]' "$TEMP/p1_integ.txt" | head -2; grep -o '"checks":[0-9]*' "$TEMP/p1_integ.txt" | head -2
echo "errores shader/script:"; grep -i -c "SHADER ERROR\|SCRIPT ERROR\|Parse Error" "$TEMP/p1_integ.txt"
