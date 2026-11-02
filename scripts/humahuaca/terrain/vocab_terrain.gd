extends RefCounted
## Vocabulario de la capa de terreno (contrato 3.0). Dueña: relieve_mapa. Es solo-agregar: sumar ids no necesita addendum;
## quitar o renombrar uno, sí. Una capa solo importa vocabularios de su propia capa o de capas inferiores (V19).
## Las cuatro primeras listas son las de la sección 3.0 del contrato (heredadas en R1.0); las demás las sumó relieve_mapa.

const SURFACES := ["suelo_seco", "sedimento_humedo", "piedra", "churqui", "irrigado", "agua", "camino", "patio", "zanja", "muro"]
const FEATURE_KINDS := ["tapia", "zanja", "acequia", "barricada", "portillo", "calle", "manzana", "patio", "parcela", "camino", "camino_cubierto"]
const LAYER_KINDS := ["dome", "platform", "pad", "step", "bank", "gully", "ditch", "carve"]
const LANDMARK_TYPES := ["hito", "objetivo", "edificio", "torre", "refugio", "acceso", "salida", "entrada", "partida", "plaza", "cerro"]

# --- agregados de relieve_mapa (R1.0) ---

## Clave de `humahuaca_level.json` → `features` de cada tipo de rasgo. Todas son arreglos salvo `camino_cubierto`, que es un solo objeto.
const FEATURE_KEYS := {"tapia": "tapias", "zanja": "zanjas", "acequia": "acequias", "barricada": "barricadas", "portillo": "portillos",
	"calle": "calles", "manzana": "manzanas", "patio": "patios", "parcela": "parcelas", "camino": "caminos", "camino_cubierto": "camino_cubierto"}

## Los 21 ids de hito que reglas, vista e interfaz usan por nombre (contrato 2.2): el mapa los trae todos, cada uno con `tag` y `source`.
const MANDATORY_LANDMARKS := ["templo", "bateria", "cuartel", "posta", "torre_casa_cura", "torre_templo", "plaza", "polvorin", "parque", "corral_posta",
	"quebradita_norte", "quebradita_sur", "vado_este", "salida_este", "entrada_sur", "zona_partida", "spawn_rodriguez", "spawn_portal", "spawn_arias",
	"spawn_reconocedores", "spawn_arreo"]

## Capas de diseño obligatorias en R1 (contrato 2.2): el `report()` las rotula como diseño.
const DESIGN_LAYERS_R1 := ["cerro_bateria", "plataforma_bateria", "quebradita_norte", "quebradita_sur", "cauce_rio"]
