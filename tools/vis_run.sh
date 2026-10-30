#!/bin/sh
# Uso: sh tools/vis_run.sh <tag> [only]   (corre desde la raiz del proyecto)
G="C:/Users/User/Desktop/spum/IA/Proyectos/MaravillaArgentina/guemes/patria-guemes/.tools/godot/Godot_v4.7.2-stable_win64_console.exe"
export APPDATA="$TEMP/ap_iso"
mkdir -p "$APPDATA"
"$G" --path . --resolution 1440x900 --script tools/vis_shots.gd -- --out=evidence/justina-ui/calidad_r1 --tag="$1" --only="$2" 2>&1 | tail -20
