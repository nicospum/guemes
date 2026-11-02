extends RefCounted
## Vocabulario de la capa de interfaz (contrato 3.0). Dueña: ui_feel. Es solo-agregar: sumar ids no necesita addendum;
## quitar o renombrar uno, sí. Una capa solo importa vocabularios de su propia capa o de capas inferiores (V19).
## Las dos primeras listas son las de la sección 3.0 del contrato; las demás las suma ui_feel desde R1.0.

const TUTORIAL_STEPS := ["reconocer", "puestos", "senal", "tres_a_la_vez", "cargar", "salir"]  # entran en R3
const TOAST_LEVELS := ["info", "aviso", "critica"]

## Las capas que el controlador arma con respaldo (cada una tiene su clase real y su versión mínima en stubs/). Son los ids de start(opts.force_stub).
const LAYER_IDS := ["terrain", "rules", "progress", "view"]

## Las velocidades del tiempo real, en el orden de F2, F3 y F4 (también + y −). Nunca cambian solas.
const SPEEDS := [1.0, 2.0, 4.0]
