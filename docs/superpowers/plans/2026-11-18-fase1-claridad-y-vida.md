# Fase 1 — Claridad y vida visual Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Hacer más clara la primera partida de La Justina y agregar vida visual
controlada sin alterar las reglas ni el balance.

**Architecture:** La capa de reglas permanece intacta. La interfaz de Justina
separa acciones primarias de acciones avanzadas mediante un control explícito;
la vista agrega figuras ambientales estáticas o de bajo costo con los GLB
existentes y las mantiene fuera de la selección y de las reglas.

**Tech Stack:** Godot 4.7.2, GDScript, escenas GLB existentes, pruebas
headless/integración.

**Spec:** `docs/equipo/PLAN_MEJORA_VISUAL_Y_JUGABILIDAD.md`

## Global Constraints

- Mantener Godot 4.7.2 y los tres capítulos.
- No modificar fórmulas, costos, rutas, estados ni condiciones de victoria.
- No convertir civiles o decoración en unidades seleccionables.
- No usar recursos pagos ni licencias no verificadas.
- Mantener la pausa activa y la acción recomendada visible.
- Textos visibles en castellano rioplatense.

## Review Focus

- Primera partida: el jugador debe ver reconocer, pedir orden y abordar sin
  abrir un menú avanzado.
- Acciones avanzadas: abrir/cerrar no debe perder selección, foco ni órdenes.
- Reinicio y cambio de capítulo: el estado del panel debe reconstruirse limpio.
- Población ambiental: no debe interceptar clics ni afectar rutas, rendimiento o
  selección.
- Falta de un GLB: la vista debe omitir sólo el decorado y conservar el juego.

---

### Task 1: Separar acciones primarias y avanzadas

**Files:**
- Modify: `scripts/main.gd`
- Modify: `tests/test_integration.gd`

**Interfaces:**
- `scripts/main.gd` conserva `_next_step()` y `_update_action_states()`.
- La interfaz produce un botón `Más acciones` y un contenedor avanzado local a
  la bandeja de Justina.

- [x] Escribir una prueba de integración que compruebe que la bandeja inicial
  contiene la acción recomendada y el control `Más acciones`, pero no muestra
  acciones avanzadas hasta activarlo.
- [x] Ejecutar la prueba y observar el fallo.
- [x] Implementar el estado local de expansión, el botón accesible y el
  contenedor sin tocar `game_rules.gd`.
- [x] Hacer que el estado se reinicie en `_new_ui()` y al cambiar de capítulo.
- [x] Ejecutar `test_integration.gd` y la prueba focalizada.

### Task 2: Población ambiental de bajo costo

**Files:**
- Modify: `scripts/world_view.gd`
- Modify: `tests/test_integration.gd` o prueba visual existente
- Modify: `docs/ASSETS.md`

**Interfaces:**
- Las figuras usan `assets/models/persona_arriero_1817_lod.glb` o un GLB
  existente y se instancian sólo desde la vista.
- No se agregan IDs a `game_rules.gd`, `main.gd` ni al sistema de selección.

- [x] Escribir una prueba que compruebe que la población ambiental se crea sólo
  para los escenarios previstos y no altera el conteo de unidades jugables.
- [x] Ejecutar la prueba y observar el fallo.
- [x] Añadir pequeños grupos de arrieros/civiles estáticos o de animación
  limitada en zonas seguras, con `visible_instance_count` acotado por calidad.
- [x] Evitar caminos, objetivos, rutas y zonas de clic.
- [x] Ejecutar la prueba visual/headless y registrar el límite de figuras.

### Task 3: Evidencia y verificación

**Files:**
- Modify: `docs/equipo/PLAN_MEJORA_VISUAL_Y_JUGABILIDAD.md`
- Create: `docs/superpowers/evidence/fase1-claridad-y-vida.md`

- [x] Registrar comandos, capturas y límites.
- [ ] Ejecutar pruebas de reglas sin cambios esperados.
- [x] Ejecutar integración y carga de escenas.
- [ ] Preparar una prueba humana de cinco minutos con preguntas concretas.

## Fuera de esta fase

- Rehacer modelos de Güemes o soldados.
- Integrar MPFB en producción.
- Rebalancear la dificultad.
- Cambiar acciones o fórmulas.
- Añadir civiles con comportamiento complejo.
