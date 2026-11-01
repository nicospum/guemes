extends RefCounted
## Vocabulario de la capa de terreno (contrato 3.0). Dueña: relieve_mapa. Es solo-agregar: sumar ids no necesita addendum;
## quitar o renombrar uno, sí. Una capa solo importa vocabularios de su propia capa o de capas inferiores (V19).
## El contenido inicial es el de la sección 3.0 del contrato; relieve_mapa lo hereda en R1.0.

const SURFACES := ["suelo_seco", "sedimento_humedo", "piedra", "churqui", "irrigado", "agua", "camino", "patio", "zanja", "muro"]
const FEATURE_KINDS := ["tapia", "zanja", "acequia", "barricada", "portillo", "calle", "manzana", "patio", "parcela", "camino", "camino_cubierto"]
const LAYER_KINDS := ["dome", "platform", "pad", "step", "bank", "gully", "ditch", "carve"]
const LANDMARK_TYPES := ["hito", "objetivo", "edificio", "torre", "refugio", "acceso", "salida", "entrada", "partida", "plaza", "cerro"]
