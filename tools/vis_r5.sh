#!/bin/sh
# Uso: sh tools/vis_r5.sh <tag> [only] [outdir]
G="C:/Users/User/Desktop/spum/IA/Proyectos/MaravillaArgentina/guemes/patria-guemes/.tools/godot/Godot_v4.7.2-stable_win64_console.exe"
export APPDATA="$TEMP/ap_iso_r5"
mkdir -p "$APPDATA"
OUT="${3:-evidence/justina-ui/diversion_r5}"
"$G" --path . --resolution 1600x900 --script tools/vis_r5.gd -- --out="$OUT" --tag="$1" --only="$2" 2>&1 | tail -20
