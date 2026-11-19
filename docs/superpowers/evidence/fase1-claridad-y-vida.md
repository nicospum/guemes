# Evidencia — Fase 1: claridad y vida

Fecha: 2026-11-18

## Cambios

- La bandeja inicial de La Justina conserva la acción recomendada y oculta
  acciones técnicas o de emergencia.
- `Más acciones` revela `sondeo cauteloso`, `marcar vado`, `volver`,
  `distraer con fuego`, `cargar sin orden` y otras opciones avanzadas.
- La selección y las reglas no cambian.
- El foco de teclado vuelve al control `Más acciones`/`Menos acciones` después
  de reconstruir la bandeja.
- La marcha en terreno seco genera polvo breve y de bajo costo; en agua no se
  genera, para no confundir el estado del río.
- Se agregaron figuras ambientales de bajo costo bajo `PoblacionAmbiental`.
  En Justina son voluntarios de 1806; en Norte y Humahuaca son arrieros de
  1817. No tienen IDs, órdenes, colisiones ni selección.
- Calidad baja usa tres figuras; las demás usan seis.

## Verificación

```text
./tools/test_action_shelf.sh
action_shelf: PASS

./tools/test_ambient_population.sh
ambient_population: PASS

Godot 4.7.2 --check-only res://scripts/world_view.gd
exit 0

Godot 4.7.2 --headless res://tests/test_integration.gd
checks: 370
failures: []
ok: true
```

## Limitaciones

- Las figuras ambientales son estáticas y no simulan una población completa.
- Todavía falta revisar visualmente su colocación en cada resolución.
- Todavía no se modificó el balance ni se retiraron reglas del núcleo.
- La prueba runtime confirma seis figuras ambientales a calidad media y que no
  entran en `unit_nodes`.
- La prueba de reglas sigue en 831/0 y la integración en 370/0 después del
  efecto de polvo.
- La prueba humana de claridad y diversión sigue pendiente.
