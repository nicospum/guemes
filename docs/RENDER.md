# Render y rendimiento (fase 2, pista render)

## Decisión de renderer
- `project.godot` pasa de Compatibility a **Forward+** (Vulkan). `rendering_device/fallback_to_opengl3=true` y `rendering_method.mobile/web=gl_compatibility` dejan el camino de máquinas modestas.
- Forzar Compatibility (OpenGL): `godot --rendering-method gl_compatibility` (o `--rendering-driver opengl3`). Verificado en esta PC con ese flag; el fallback automático cuando no hay Vulkan **no se probó** (la PC tiene Vulkan 1.4).
- Los shaders y `world_view.gd` funcionan en ambos. Los efectos extra (SSAO, glow, niebla volumétrica, sombras en 4 cortes) solo se activan si el renderer no es Compatibility (`advanced_renderer`) y el perfil no es `baja`.
- Exportar para Linux/xvfb (QA de 0.1.0) requiere ajustar el preset o usar `--rendering-method gl_compatibility`; no se probó aquí.

## Perfiles
| Perfil | Forward+ | Compatibility |
|---|---|---|
| baja | escala 3D 0,5, sin sombras ni MSAA, 2 figuras/grupo, sin efectos | igual |
| media | sombras 2 cortes, MSAA 2x, SSAO, glow, ajuste de color | sombras, MSAA 2x |
| alta | media + MSAA 4x, sombras 4 cortes, niebla volumétrica leve | MSAA 4x (igual que media en costo) |
(MSAA y escala 3D los fija `main.gd`; no se tocó.)

## Cambios en `world_view.gd`
- Casas, árboles, chimenea y caminos de Norte pasan a 5 `MultiMeshInstance3D` (lotes `Lote_box`, `Lote_prism`, `Lote_cyl8`, `Lote_cyl12`, `Lote_sphere`) con color por instancia y un solo material. Antes: 516 `MeshInstance3D` en Norte.
- Rutas: un único `MultiMesh` persistente (`refresh_paths` ya no destruye y crea nodos).
- Terreno indexado (`SurfaceTool.index()`): normales suaves en lugar de facetas.
- Etiquetas 3D `fixed_size` (`LABEL_PIXEL_SIZE`), tamaño constante en pantalla; el texto solo se reasigna si cambió.
- Animaciones de figuras en pausa real (`pause()`) cuando no se mueven.
- API pública y nombres de nodos consumidos por `main.gd` sin cambios (`build`, `update_state`, `refresh_paths`, `pick_*`, `selected*`, `show_paths`, `cannon_effect`). Cambia internamente: casas y árboles ya no son nodos individuales; las etiquetas de Label3D siguen existiendo (`find_children("*","Label3D")` funciona).

## Agua y terreno
- `water.gdshader`: la profundidad sigue saliendo de la misma función `riverbed()` y el umbral de vado `wade_depth = 0.55` es el de `GameRules.is_walkable` (nivel - terreno <= 0,55). Vadeable = más claro y transparente; espuma en la orilla y en el borde del vado; fresnel leve. Cambia el nivel (bajante) y todo se mueve con él.
- `terrain.gdshader`: pendiente fuerte aclara a roca, ruido fino, `color_gamma` (1,9 en Compatibility; 2,6 en Forward+, ajustado a ojo para que el brillo se parezca).

## Método de medición
Equipo: Ryzen 9 7950X, RTX 3080 Ti, Windows 11, Godot 4.7.2 desde el proyecto fuente (no EXE exportado), ventana 1440x900, `--disable-vsync`, audio Dummy, APPDATA aislado.
1. `tools/benchmark.py` (usa `--benchmark=` de main.gd: 30 cuadros de calentamiento + 180 medidos, 3 repeticiones). Los 180 cuadros duran 0,2-0,7 s: es una muestra corta.
2. `tools/bench_gpu.gd` + `tools/bench_gpu_matrix.py`: 60 cuadros de calentamiento + 600 medidos, 2 repeticiones, con tiempo de GPU del motor, draw calls y primitivas.
Datos crudos en `evidence/fase2/render/`.

## Resultados (FPS medios, `benchmark.py`, 3 repeticiones)
| Escenario / perfil | Antes (Compat, código 0.1.0) | Después Compat | Después Forward+ |
|---|---|---|---|
| Justine baja | 478 | 489 | 1544 |
| Justine media | 245 | 248 | 966 |
| Justine alta | 243 | 245 | 921 |
| Norte baja | 450 | 461 | 1628 |
| Norte media | 235 | 286 | 1035 |
| Norte alta | 233 | 283 | 978 |

Con `bench_gpu` (600 cuadros): Forward+ tiempo de GPU mediano 0,16-0,89 ms; en Compatibility Justine media/alta 3,96 ms (las figuras con piel dominan, como en la auditoría). Draw calls contados por el motor (incluye pasadas de sombra): 244-246 en baja, ~600 en media/alta; primitivas 81k-303k.

Metas: 60 FPS en alta y 30+ en baja se cumplen con amplio margen en esta GPU. No se midió GPU integrada ni hardware modesto: no hay evidencia para ese caso.

## Límites conocidos
- Ganancia grande de Forward+ sobre Compat en Justine: viene del renderer, no de los lotes (con Compat Justine no mejora; Norte sí, por menos draw calls).
- No se reemplazaron las figuras con piel (12 jinetes ~12.900 triángulos cada uno): sigue siendo el costo dominante en Compatibility. LOD o modelos más livianos requieren cambiar los GLB.
- El fallo de fuga de texturas GL al cerrar en Compatibility ya existía; no se investigó.
- El ajuste de brillo entre renderers y los colores del agua son criterio visual, comparado sobre capturas, no medido colorimétricamente. Las etiquetas pueden seguir solapándose cuando hay unidades juntas.
