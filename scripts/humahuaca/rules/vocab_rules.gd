extends RefCounted
## Vocabulario de la capa de reglas (contrato 3.0). Dueña: reglas_historia. Es solo-agregar: sumar ids no necesita addendum;
## quitar o renombrar uno, sí. Una capa solo importa vocabularios de su propia capa o de capas inferiores (V19).
## El contenido inicial es el de la sección 3.0 del contrato; reglas_historia lo hereda en R1.0.

const PHASES := ["briefing", "aproximacion", "ataque", "extraccion", "epilogo"]
const STATUS := ["playing", "victory", "defeat"]
const FRONT_STATES := ["guardado", "alertado", "en_alarma", "asaltado", "tomado"]
const PACES := ["sneak", "march", "run", "trot", "gallop"]
const STAGES := ["idle", "moving", "waiting_signal", "attacking", "holding", "loading", "retreating", "routed", "dismounting", "scouting", "exited"]
const ACTIONS := {
	"group": ["move", "position", "attack", "support", "hold", "secure_horses", "breach", "retreat", "cancel"],
	"scout": ["recon", "decoy", "watch", "cancel"],
	"train": ["bring", "load", "destroy", "hide", "leave", "drop", "cancel"],
	"global": ["give_signal", "retreat_all"]}
const ACTIONS_R1 := ["move", "position", "give_signal", "attack", "support", "recon", "load", "destroy", "leave", "hold", "cancel"]  # las 9 de R1 más hold (auto) y cancel
const LOOT_KINDS := ["polvora", "canones", "fusiles", "viveres", "ganado", "plata", "prisioneros", "bandera", "ornamentos"]
const LOOT_KINDS_R1 := ["polvora", "canones", "fusiles", "viveres", "plata"]  # R1: 5 clases con puntos provisionales que suman 100
const LOOT_STATES := ["en_sitio", "cargado", "destruido", "oculto", "abandonado", "entregado"]
const TREATMENTS := ["entregar", "destruir", "ocultar", "abandonar"]
const WORLD_TRAITS := {"corral": ["completo", "desbandado"], "plata": [true, false], "polvora": ["seca", "humeda"]}
const VARIANTS := {"guardia": ["descuidada", "atenta"], "torre_en": ["templo", "casa_cura"], "refugio": ["norte", "sur"],
	"lluvia": ["copiosa", "garua"], "refuerzo": ["temprano", "normal", "tardio"], "layout": ["A", "B"]}
const ACTIVE_DIMS := ["guardia", "torre_en", "refuerzo"]  # desde R2b; en R1 el mundo es fijo; el resto son candidatas con valor fijo
const APPROACHES := {"bateria": ["frontal", "gola", "distraccion"], "cuartel": ["calle", "patios", "piezas"], "posta": ["directa", "distraccion"]}
const EXTRACTIONS := ["cargar_todo", "destruir_todo", "ocultar", "ligera", "mixta"]
const CAUSES := ["amanecio", "descubiertos", "frente_roto", "sin_carga", "interceptados", "dispersos", "plazo", "retirada"]
const MEDALS := ["", "bronce", "plata", "oro"]
const RETRY := ["posiciones", "salida", "mismo_mundo", "mundo_nuevo"]
const EVENT_KINDS := ["objective", "briefing", "weather", "dawn", "noise", "detected", "alarm", "signal", "shot", "melee",
	"capture", "tower", "support", "horses", "recon", "decoy", "messenger", "reinforcement_warning", "reinforcement",
	"loot", "load", "destroy", "hide", "exit", "decision", "hint", "assist", "enemy_choice", "checkpoint",
	"victory", "defeat", "info", "warning"]

# --- Agregados de R1.0 (solo-agregar): los comparten el stub, las reglas reales, las políticas y las pruebas de reglas_historia ---
const ACTOR_KINDS := ["group", "scout", "train", "global"]  # los cuatro tipos de actor de ACTIONS
const UNIT_KINDS := ["partida", "reserva", "reconocedores", "arreo"]  # `kind` de cada agrupación (ficha de la vista)
const ENV_PHASES := ["noche", "alba", "dia"]  # `environment().phase`
const NOISE_STATES := ["silencio", "se_oye", "los_oyen"]  # el ruido que ve el jugador, sin números
const ALERT_LEVELS := ["info", "aviso", "critica"]  # `hud_state().alertas[].nivel` (la capa de reglas no importa vocab_ui)
const REINFORCEMENT_STATES := ["desconocido", "en_camino", "visible", "llego"]
const ROUTE_RISKS := ["bajo", "medio", "alto", "desconocido"]  # `plan_route().risk`
const ENEMY_KINDS := ["centinela", "guardia", "artillero", "fusilero", "torre", "mensajero", "refuerzo"]  # `render_state().enemies[].kind`
const LIGHT_KINDS := ["brasero", "ventana", "candil", "fogata"]  # `render_state().lights[].kind`
const POSTURES := ["a_fondo", "con_cautela"]  # `issue_order(..., "attack", ..., {"posture": ...})`
