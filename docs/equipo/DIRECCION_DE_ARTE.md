# Dirección de arte «Crónica en oro y noche» — entrega «equipo 2026-11-08»

Versión versionada del documento de la pista de dirección de arte (el original y sus prototipos en `../qa-equipo/arte/` se perdieron en el borrado del 2026-11-08). Los valores de abajo son los que las pistas aplicaron en código; la fuente de verdad son los archivos citados.

Pedido del usuario (2026-11-02): «retomá esta estética más épica y linda; la de ahora no dice mucho», con seis mockups en `docs/referencias/humahuaca/estetica/`. Se adoptó su tono con arte propio: no se copian sus imágenes ni sus citas sin fuente.

## Principios

1. **Tinta y oro.** Fondo `#0E0C12`, paneles `#16131C`, oro viejo `#C9A25E` para mando y objetivo, violeta `#7A5BB5` para rutas y selección. Alertas en ámbar `#D9903A`. El rojo `#B8433A` queda **solo para el enemigo**.
2. **Bandos iguales en los tres niveles.** Aliado: celeste `#8DB8D6` (exploradores `#A9CBE2`); objetivo: oro que late; enemigo: rojo con aro y contorno; neutral/arreo: hueso `#BFB6A3`.
3. **Una luz por nivel, mismo juego.** I: tarde dorada sobre el río y la barranca. II: noche de lluvia con luna fría, braseros y ventanas ámbar, tierra ocre de la quebrada, madrugada rosada y alba. III: relieve dorado con sol rasante sobre fondo negro.
4. **Grading común** (sombras violáceas, luces doradas) y viñeta 0,3 en juego (0,5 en pantallas).
5. **Tipografía** (OFL, ya en `assets/fonts`): Cinzel para títulos, Inter para la interfaz; citas en cursiva derivada de Inter, siempre con fuente real.
6. **Interfaz de juego, no tablero.** HUD en esquinas y bandas (objetivo ≤ 25 % de pantalla tapada a 1440×900); briefing y partes a pantalla completa con la composición del mockup 05 (objetivo y fuerzas a la izquierda, enemigo y cronología a la derecha, cita al pie, acción principal abajo a la derecha). La derrota no va en rojo.

## Dónde vive cada cosa

| Tema | Archivos |
|---|---|
| Looks de Justina, Norte y menú (`set_look`) | `scripts/world_view.gd`, `scripts/looks/world_looks.gd`, `assets/terrain.gdshader` |
| Noche, fuegos, bruma, vegetación, fichas del II | `scripts/humahuaca/view/*`, `data/humahuaca_visual.json` |
| Cámara del II (encuadre, acercamiento al elegir, apertura) | `scripts/humahuaca/ui/humahuaca_camera.gd`, `data/humahuaca_camera.json`, sección `camera` de `data/humahuaca_ui.json` |
| Modelos propios del II (adobe, capilla, tapias, pirca, corral, cañón de bronce, brasero, fogón) | `assets/models/hx_*.glb`, generados por `tools/hx_models_sin_blender.py` (variante sin Blender) y definidos en `tools/create_models.py` |
| Paleta e interfaz I/III | `scripts/main.gd` |
| Paleta e interfaz II | `scripts/humahuaca/ui/humahuaca_ui_kit.gd`, `humahuaca_dialogs.gd`, `humahuaca_hud.gd` |

## Límites conocidos

- Las figuras siguen siendo de bajo detalle a corta distancia; el salto pide figuras modeladas (pendiente para cuando haya Blender ejecutable; ver `docs/equipo/P6_MODELOS.md`).
- El valle de juego del II es casi llano en el relieve real (±20 m): la quebrada se ve en la apertura y de reojo en la bruma, no con el dramatismo de los mockups.
- En la Justina, a la distancia de juego, la mejora de luz es moderada; el cambio fuerte se ve en planos oblicuos (barranca, buque).
