extends RefCounted
## Vocabulario de la capa de vista (contrato 3.0). Dueña: visual. Es solo-agregar: sumar ids no necesita addendum;
## quitar o renombrar uno, sí. Una capa solo importa vocabularios de su propia capa o de capas inferiores (V19).
## El contenido inicial es el de la sección 3.0 del contrato; visual lo hereda en R1.0 y suma lo que la vista usa por nombre.

const VIEW_IDS := ["acceso_so", "desde_bateria", "patio_posta", "panorama_alto", "grupos_en_accion", "juego_noche", "juego_alba"]
const QUALITY := ["baja", "media", "alta"]
const FX_KINDS := ["fogonazo", "humo", "impacto", "captura", "pisadas", "explosion", "senal"]
const LAYERS := ["paths", "visibility", "exposure", "labels", "landmarks", "diary", "enemy", "lights"]

## Agregados de R1.0 (solo-agregar).
const LIGHT_KINDS := ["brasero", "ventana", "candil", "fogata"]
const ENEMY_KINDS := ["centinela", "guardia", "artillero", "fusilero", "torre", "mensajero", "refuerzo"]
const TOKEN_SHAPES := ["jinete", "infante_fusil", "infante_banderin", "agachados", "mula_cargada"]
const PROBE_KINDS := ["edificio", "suelo", "ficha", "objetivo"]
const BANDS := ["patriota", "realista", "neutral"]  # bandos de los marcadores de interfaz (humahuaca_visual.json: markers)

## Qué significa `environment().time_of_day` (0..1) para la vista: continuo y creciente. La luz se interpola entre estas claves de
## `humahuaca_visual.json: lights` (noche_lluvia, alba, dia). `reglas_historia` alinea su curva con esto (pedido de visual en R1.0).
const TIME_OF_DAY := {"noche_lluvia": 0.0, "alba": 0.5, "dia": 1.0}

## Cuántos píxeles de borde se respetan al verificar que un cuadro «incluye» un punto (V02 del QA pide ≥ 5 % del borde).
const FRAME_MARGIN_PCT := 5.0
