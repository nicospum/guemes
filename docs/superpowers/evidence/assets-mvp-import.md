# Evidencia del MVP de assets

Fecha: 2026-11-18

## Escena

`scenes/lab/assets_mvp.tscn` carga una escena aislada con:

- `assets/lab/UAL1_Standard.glb` — candidato gratuito CC0 para humano y
  animaciones;
- `assets/models/rider_1817.glb` — baseline propio de caballo y jinete;
- `assets/models/arma_carabina.glb` — baseline propio de arma, no candidato CC0.

La escena usa suelo, luz, cámara y rótulos propios del laboratorio. No modifica
las escenas de los tres capítulos.

## Verificaciones ejecutadas

```text
./tools/test_assets_mvp.sh
assets_mvp: PASS
```

```text
Godot_v4.7.2-stable_win64_console.exe --headless \
  --path C:\Users\User\Desktop\spum\IA\Proyectos\MaravillaArgentina\guemes\patria-guemes \
  --scene res://scenes/lab/assets_mvp.tscn --quit-after 2
Godot Engine v4.7.2.stable.official.ed1daf0bf
exit 0
```

La carga headless no informó errores de script, importación o recursos faltantes.
La aprobación visual y auditiva humana todavía está pendiente. El arma CC0 y
un caballo externo todavía no están integrados porque sus descargas requieren
un flujo manual.

## Medidas y límites de esta prueba

| Asset | Tamaño | Estado de medición |
|---|---:|---|
| `UAL1_Standard.glb` | 7 618 436 bytes | importación comprobada; escala, triángulos y clips requieren revisión visual del laboratorio |
| `rider_1817.glb` | 139 736 bytes | baseline; detalles en los manifiestos F4/F5 |
| `arma_carabina.glb` | 8 224 bytes | baseline propio, estático |

La prueba actual demuestra existencia, importación y carga de escena. Todavía no
declara aprobación de escala, orientación, calidad visual ni rendimiento.

## Estado

Esto es un laboratorio de comparación, no una integración de producción. Los
modelos actuales del juego siguen sin reemplazarse. La procedencia completa
está en `assets-mvp-sources.md`.
