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

# --- Agregados de R1 (solo-agregar) ---

## Estados del controlador: la tarjeta de arranque, la apertura de cámara, el juego y el parte final.
const MODES := ["briefing", "opening", "play", "ended"]

## Ventanas que se abren sobre el juego (una a la vez).
const DIALOGS := ["briefing", "pausa", "ayuda", "decision", "parte", "diario", "confirmar"]

## Grupos de controles: lo que cuenta como UN control accionable en la medida del primer cuadro (diseño 9: pausa y velocidad cuentan como uno,
## ayuda y menú como uno, y cada botón de la barra de acciones como uno).
const CONTROL_GROUPS := ["tiempo", "sistema", "accion"]

## `kind` de cada agrupación (render_state y reglas) → tipo de actor de ACTIONS.
const ACTOR_OF_KIND := {"partida": "group", "reserva": "group", "reconocedores": "scout", "arreo": "train"}

## Las acciones que piden marcar un punto en el mapa antes de ejecutarse (modo apuntado); el resto se ejecuta con un clic o una tecla.
const AIM_ACTIONS := ["move", "recon", "support"]

## El orden de los botones de la barra de acciones.
const ACTION_ORDER := ["recon", "move", "position", "attack", "support", "load", "destroy", "leave", "give_signal", "hold", "cancel"]

## Los ritmos de marcha que el jugador puede elegir (el resto son para montados y llegan con R2a).
const PACE_ORDER := ["sneak", "march", "run"]

## Lo que se dibuja en el mapa como riesgo de una ruta: orden de menor a mayor.
const RISK_ORDER := ["bajo", "medio", "alto", "desconocido"]

## Grupos de la tabla de teclas (key_table[*].group), en el orden en que se listan en la ayuda y en CONTROLES.md.
const KEY_GROUPS := ["tiempo", "interfaz", "seleccion", "camara", "acciones", "ordenes"]
