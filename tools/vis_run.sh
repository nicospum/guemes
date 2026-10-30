#!/bin/sh
# Uso: sh tools/vis_run.sh <tag> [only] [outdir]   (desde la raiz del proyecto)
G="C:/Users/User/Desktop/spum/IA/Proyectos/MaravillaArgentina/guemes/patria-guemes/.tools/godot/Godot_v4.7.2-stable_win64_console.exe"
export APPDATA="$TEMP/ap_iso7"
mkdir -p "$APPDATA"
OUT="${3:-evidence/justina-ui/calidad_r2}"
"$G" --path . --resolution 1440x900 --script tools/vis_shots.gd -- --out="$OUT" --tag="$1" --only="$2" 2>&1 | tail -20
