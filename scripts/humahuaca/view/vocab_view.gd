extends RefCounted
## Vocabulario de la capa de vista (contrato 3.0). Dueña: visual. Es solo-agregar: sumar ids no necesita addendum;
## quitar o renombrar uno, sí. Una capa solo importa vocabularios de su propia capa o de capas inferiores (V19).
## El contenido inicial es el de la sección 3.0 del contrato; visual lo hereda en R1.0.

const VIEW_IDS := ["acceso_so", "desde_bateria", "patio_posta", "panorama_alto", "grupos_en_accion", "juego_noche", "juego_alba"]
const QUALITY := ["baja", "media", "alta"]
const FX_KINDS := ["fogonazo", "humo", "impacto", "captura", "pisadas", "explosion", "senal"]
const LAYERS := ["paths", "visibility", "exposure", "labels", "landmarks", "diary", "enemy", "lights"]
