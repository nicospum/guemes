export const meta = {
  name: 'guemes-nivel2-bucle',
  description: 'Nivel 2 Humahuaca: rondas con lector de informes, explorador de herramientas, 4 pistas que modifican, integración, revisores y control de calidad hasta presentable',
  whenToUse: 'Construcción y certificación del nivel 2 (después de la preparación). Se lanza por tramos con args.etapas y args.estado',
  phases: [
    { title: 'Andamiaje', detail: 'R0: ganchos, vocabularios, compuerta y pruebas base' },
    { title: 'Planificacion', detail: 'lector de informes y explorador de herramientas' },
    { title: 'Mejora', detail: 'cuatro pistas en worktrees propios' },
    { title: 'Integracion', detail: 'merge train, compuerta completa y herramientas de QA' },
    { title: 'Revision', detail: 'revisores independientes y agente-jugador' },
    { title: 'Control de calidad', detail: 'jefe de QA: tabla de estado y hallazgos' },
    { title: 'Certificacion', detail: 'triple certificación sobre un único commit' },
  ],
}

const REPO = 'C:/Users/User/Desktop/spum/IA/Proyectos/MaravillaArgentina/guemes/patria-guemes'
const RAIZ = 'C:/Users/User/Desktop/spum/IA/Proyectos/MaravillaArgentina/guemes'
const INFO2 = 'C:/Users/User/Desktop/spum/Maravilla Argentina/Justina_Retiro_1806_Paquete_Editable/info/2'
const INV2 = RAIZ + '/investigacion-nivel2'
const PREP = INV2 + '/preparacion'
const GODOT = REPO + '/.tools/godot/Godot_v4.7.2-stable_win64_console.exe'
const DEM = INV2 + '/descargas/Copernicus_DSM_COG_10_S24_00_W066_00_DEM.tif'
const ARGS = (typeof args !== 'undefined' && args) ? args : {}
const ETAPAS = ARGS.etapas || ['R0', 'R1.0', 'R1']
let estado = ARGS.estado || { abiertos: [], permisos: [], etapas: [], commit: null, certificado: false, veredicto: null, integ: null }
if (!estado.permisos) estado.permisos = []
if (!estado.etapas) estado.etapas = []
if (!estado.abiertos) estado.abiertos = []

const cut = (x, n) => { const s = (typeof x === 'string') ? x : JSON.stringify(x); if (!s) return ''; return s.length > n ? s.slice(0, n) + ' …[cortado; leé el archivo]' : s }
async function ag(prompt, opts, reintentos) {
  let r = await agent(prompt, opts)
  for (let i = 0; i < (reintentos === undefined ? 1 : reintentos) && !r; i++) {
    log('Reintento de ' + opts.label + ' (resultado nulo)')
    r = await agent(prompt, Object.assign({}, opts, { label: opts.label + ':reintento' }))
  }
  return r
}

// ---------- esquemas ----------
const SA = { type: 'array', items: { type: 'string' } }
const FALLOS = { type: 'array', items: { type: 'object', properties: { pista: { type: 'string' }, problema: { type: 'string' } }, required: ['pista', 'problema'] } }
const SCAFF = { type: 'object', properties: { resumen: { type: 'string' }, commits: SA, compuerta: { type: 'string' }, compuerta_verde: { type: 'boolean' }, pendientes: SA }, required: ['resumen', 'commits', 'compuerta', 'compuerta_verde', 'pendientes'] }
const TRACK = { type: 'object', properties: { rama: { type: 'string' }, commit: { type: 'string' }, resumen: { type: 'string' }, entregado: SA, no_entregado: SA, pruebas: { type: 'string' }, capturas: SA, pedidos: SA, permisos_pendientes: SA }, required: ['rama', 'commit', 'resumen', 'entregado', 'no_entregado', 'pruebas'] }
const INTEG = { type: 'object', properties: { commit: { type: 'string' }, resumen: { type: 'string' }, merges: SA, compuerta: { type: 'string' }, fallos_abiertos: FALLOS, capturas: SA, exe: { type: 'string' } }, required: ['commit', 'resumen', 'merges', 'compuerta', 'fallos_abiertos'] }
const GATE = { type: 'object', properties: { resumen: { type: 'string' }, compuerta_verde: { type: 'boolean' }, mediciones: { type: 'string' }, fallos: FALLOS, herramientas: SA, evidencia: { type: 'string' } }, required: ['resumen', 'compuerta_verde', 'mediciones', 'fallos'] }
const BRIEF = { type: 'object', properties: { briefs: { type: 'object', properties: { relieve_mapa: { type: 'string' }, reglas_historia: { type: 'string' }, visual: { type: 'string' }, ui_feel: { type: 'string' }, integrador: { type: 'string' }, qa: { type: 'string' } }, required: ['relieve_mapa', 'reglas_historia', 'visual', 'ui_feel'] }, alertas: SA }, required: ['briefs', 'alertas'] }
const TOOLS = { type: 'object', properties: { por_pista: { type: 'object', properties: { relieve_mapa: { type: 'string' }, reglas_historia: { type: 'string' }, visual: { type: 'string' }, ui_feel: { type: 'string' }, integrador: { type: 'string' }, qa: { type: 'string' } }, required: ['relieve_mapa', 'reglas_historia', 'visual', 'ui_feel'] }, herramientas_ok: { type: 'boolean' }, permisos_pendientes: { type: 'array', items: { type: 'object', properties: { objeto: { type: 'string' }, origen: { type: 'string' }, tamano: { type: 'string' }, motivo: { type: 'string' }, alternativa: { type: 'string' } }, required: ['objeto', 'motivo'] } }, notas: SA }, required: ['por_pista', 'herramientas_ok', 'permisos_pendientes'] }
const FIND = { type: 'object', properties: { hallazgos: { type: 'array', items: { type: 'object', properties: { severidad: { type: 'string', enum: ['ALTA', 'MEDIA', 'BAJA'] }, criterio: { type: 'string' }, titulo: { type: 'string' }, evidencia: { type: 'string' }, repro: { type: 'string' }, pista: { type: 'string', enum: ['relieve_mapa', 'reglas_historia', 'visual', 'ui_feel', 'integrador'] }, aceptacion: { type: 'string' } }, required: ['severidad', 'criterio', 'titulo', 'evidencia', 'pista', 'aceptacion'] } }, mediciones: { type: 'string' }, resumen: { type: 'string' } }, required: ['hallazgos', 'resumen'] }
const PLAYER = { type: 'object', properties: { primera_orden_turno: { type: 'number' }, primera_orden_t_s: { type: 'number' }, turnos: { type: 'number' }, resultado: { type: 'string' }, objetivo_dicho: { type: 'string' }, entendio: { type: 'string' }, aburrimiento: { type: 'string' }, aprendido: { type: 'string' }, lecturas_fuera_de_carpeta: { type: 'number' }, bitacora: { type: 'string' }, hallazgos: FIND.properties.hallazgos, resumen: { type: 'string' } }, required: ['turnos', 'resultado', 'objetivo_dicho', 'entendio', 'lecturas_fuera_de_carpeta', 'resumen'] }
const QAR = { type: 'object', properties: { ronda: { type: 'string' }, commit: { type: 'string' }, tabla_estado: { type: 'array', items: { type: 'object', properties: { id: { type: 'string' }, estado: { type: 'string', enum: ['P', 'F', 'N', 'NE'] }, medicion: { type: 'string' } }, required: ['id', 'estado'] } }, hallazgos: { type: 'array', items: { type: 'object', properties: { id: { type: 'string' }, criterio: { type: 'string' }, severidad: { type: 'string', enum: ['P0', 'P1', 'P2'] }, titulo: { type: 'string' }, evidencia: { type: 'string' }, repro: { type: 'string' }, pista: { type: 'string', enum: ['relieve_mapa', 'reglas_historia', 'visual', 'ui_feel', 'integrador'] }, aceptacion: { type: 'string' }, razon_aceptada: { type: 'string' } }, required: ['id', 'criterio', 'severidad', 'titulo', 'evidencia', 'pista', 'aceptacion'] } }, backlog: SA, cierre_ok: { type: 'boolean' }, todo_exigible_en_verde: { type: 'boolean' }, resumen: { type: 'string' }, evidencia: { type: 'string' } }, required: ['ronda', 'commit', 'tabla_estado', 'hallazgos', 'cierre_ok', 'todo_exigible_en_verde', 'resumen'] }
const CERT = { type: 'object', properties: { certificador: { type: 'string' }, commit: { type: 'string' }, rubrica_sha256: { type: 'string' }, veredicto_json: { type: 'string' }, pasan: { type: 'number' }, fallan: SA, no_evaluables: SA, hallazgos: QAR.properties.hallazgos, resumen: { type: 'string' } }, required: ['certificador', 'commit', 'rubrica_sha256', 'veredicto_json', 'pasan', 'fallan', 'no_evaluables', 'resumen'] }
const CONS = { type: 'object', properties: { presentable: { type: 'boolean' }, veredicto: { type: 'string' }, commit: { type: 'string' }, tabla_estado: QAR.properties.tabla_estado, hallazgos: QAR.properties.hallazgos, medias_aceptadas: SA, discrepancias: SA, evidencia_commit: { type: 'string' }, resumen: { type: 'string' } }, required: ['presentable', 'veredicto', 'commit', 'hallazgos', 'resumen'] }

// ---------- contexto común ----------
const COMUN = `PROYECTO: videojuego histórico "Güemes — Juegos de la Patria" (Godot 4.7.2, GDScript). Repo: ${REPO} (rama main). NUNCA push, release, tags nuevos ni --force; no se borra historial. Carpeta padre (fuera de Git): ${RAIZ}.
OBJETIVO DEL BUCLE: llevar el NIVEL 2 «Humahuaca: el depósito de la retaguardia» (ataque de Arias, 1/3/1817) a calidad PRESENTABLE, sin romper la Justina ni «Sostener el norte» (que pasa a ser el nivel III). El usuario aprobó el alcance (Humahuaca = nivel 2; el Norte = nivel 3 sin cambios de reglas).
DOCUMENTOS QUE MANDAN (ya escritos y commiteados; leelos POR SECCIONES, no enteros cada vez): ${REPO}/docs/DISENO_HUMAHUACA.md (qué se juega y por qué), ${REPO}/docs/CONTRATO_HUMAHUACA.md (archivos y dueños, esquemas, API, enganches, rondas), ${REPO}/docs/QA_NIVEL2.md v1.2 (qué es presentable y cómo se mide: rúbrica de 41 criterios CONGELADA). Informes de la preparación: ${PREP}/01_dossier_humahuaca.md, 02_fuentes_primarias.md, 03_arquitectura_actual.md, 04_herramientas.md (más 03_poc/ y las recetas .py). Material del usuario (solo lectura): ${INFO2} (md y 4 láminas). Si dos documentos chocan: sobre qué se juega manda el diseño/contrato; sobre cómo se certifica manda la rúbrica; un cambio de contrato exige un addendum en docs/humahuaca/ADDENDA.md.
NOVEDADES POSTERIORES A LA PREPARACIÓN (decisiones del usuario): (1) Autorizó la tesela Copernicus GLO-30 S24_00_W066_00: ya está en ${DEM} (39.438.103 bytes, SHA-256 1b38c9054683f2ea927915ffc9f81e664f919cf13a6cbb4e93a1bd637301f97f); en la misma carpeta están S25 y S26. Usenla como fuente principal del relieve desde R2a si R02–R06 pasan con ella (la lámina 03 reconstruida es el plan B de R1 y la referencia de verificación), con atribución en créditos; el relieve del juego es un JSON (la tesela no se exporta ni entra a Git). (2) Blender NO está autorizado: el canal de arte es el generador procedural en GDScript. (3) Nadie jugará a mano: el agente-jugador reemplaza al humano y el veredicto máximo es «PRESENTABLE, no certificado por humanos». (4) No hay más material del usuario (zip de 39 archivos, láminas 01/04/05, tabla de 23 elementos): se trabaja con lo que hay y lo que falta se rotula como diseño.
DIRECTRIZ DEL USUARIO: la diversión y la claridad mandan; la fidelidad es una guía, pero con etiquetas honestas y cero anacronismos graves. El nivel 1 fracasó 5 de 5 veces en el control de calidad (visual pobre, tiempos muertos, receta única, arranque abrumador, balance malo, 94 hallazgos sin priorizar): aplicá esas lecciones.
REGLAS DE TRABAJO: propiedad EXCLUSIVA de archivos por pista (CONTRATO §1.2); los archivos protegidos (CONTRATO §1.3) no se tocan; no abras ni imprimas .env* ni jev.cfg; no descargues ni instales nada (si hace falta, anotalo en permisos_pendientes con nombre, origen y tamaño); no toques ni borres ramas ni worktrees ajenos (hay ≈39 ramas viejas y un worktree bloqueado en .claude/worktrees); todo shell es Git Bash con rutas absolutas; Godot: ${GODOT}; SIEMPRE con timeout y con APPDATA aislado propio (export APPDATA="$TEMP/ap_iso_<tuId>"; rm -rf; mkdir -p); las corridas con ventana no deben solaparse con un benchmark; las capturas son reales (Godot sin --headless) y se MIRAN con Read una por una antes de darlas por buenas; no declares una prueba que no corriste (no evaluable = falla); cifras reales, sin maquillar. Commits en español, claros, con el trailer 'Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>'. Español rioplatense en todo texto visible del juego y de los docs.`

const PISTAS = {
  relieve_mapa: {
    slug: 'relieve', desc: 'RELIEVE Y MAPA: terreno (DEM y lámina 03), grilla de relieve, mapa de hitos, superficies, río, navegación y línea de visión; clase HumahuacaTerrain.',
    propios: 'scripts/humahuaca/terrain/** (humahuaca_terrain.gd, vocab_terrain.gd y auxiliares), scripts/humahuaca/stubs/stub_terrain.gd, data/humahuaca_map.json, data/humahuaca_height.json, tools/build_humahuaca_terrain.py, tests/test_hx_terrain.gd, docs/humahuaca/RELIEVE.md y CREDITOS_RELIEVE.md',
    diseno: 'DISENO §3 (mundo y escala), §4 (relieve con consecuencias de juego), §11.2 y §12 (lo que toca a hitos)',
    r10: 'scripts/humahuaca/stubs/stub_terrain.gd (terreno plano a +17 m con los hitos obligatorios de §2.2; lee data/humahuaca_level.json y respeta tapias, zanjas y zonas con rasterizado simple; API COMPLETA de §3.1 con valores válidos), scripts/humahuaca/terrain/vocab_terrain.gd (hereda el de T0) y data/humahuaca_map.json mínimo con los 21 hitos con tag y source',
  },
  reglas_historia: {
    slug: 'reglas', desc: 'REGLAS E HISTORIA: HumahuacaRules, HumahuacaProgress, políticas, datos de reglas y de nivel, etiquetas de fuente, textos históricos, balance y pruebas de reglas.',
    propios: 'scripts/humahuaca/rules/** (humahuaca_rules.gd, humahuaca_progress.gd, humahuaca_data.gd, humahuaca_policies.gd —la única biblioteca de políticas—, vocab_rules.gd y auxiliares), scripts/humahuaca/stubs/stub_rules.gd y stub_progress.gd, data/humahuaca_rules.json, data/humahuaca_level.json, data/history.json (SOLO agregar scenarios.humahuaca y fuentes desde S46; no edites nada existente), tests/test_hx_rules.gd, tools/humahuaca_playthrough.gd, docs/humahuaca/REGLAS.md, HISTORIA.md y PROCEDENCIA.md, y agregar al final de docs/historia/MATRIZ_HISTORICA.md y FUENTES.md',
    diseno: 'DISENO §2 (arco), §5 a §10 (agrupaciones, defensores, objetivos y extracción, aprendizaje, onboarding, balance) y §12 (historia)',
    r10: 'scripts/humahuaca/stubs/stub_rules.gd (5 unidades, 3 objetivos, reloj con fases, hud_state y render_state con TODAS las claves de los ejemplos de forma de §3.6, una victoria alcanzable —tomar los tres frentes con attack y salir— y una derrota por amanecio, snapshot/save/load/validate/restore_snapshot básicos) y stub_progress.gd (semilla fija, intentos, record_result mínimo), scripts/humahuaca/rules/vocab_rules.gd, data/humahuaca_rules.json y data/humahuaca_level.json mínimos (≥ 12 tapias, ≥ 4 zanjas, zonas, accesos, 3 luces)',
  },
  visual: {
    slug: 'visual', desc: 'ASPECTO VISUAL: HumahuacaView (terreno con shader, agua, cielo, luz de noche/alba/día con lluvia, edificios, vegetación, fichas con silueta, fx, minimapa, cámaras iniciales y vistas canónicas), generador procedural de arte, paleta del dossier y sonido.',
    propios: 'scripts/humahuaca/view/** (humahuaca_view.gd, humahuaca_gfx.gd, humahuaca_buildings.gd, humahuaca_units.gd, humahuaca_fx.gd, humahuaca_gen.gd —generador procedural del templo y de los arquetipos—, vocab_view.gd y auxiliares), scripts/humahuaca/stubs/stub_view.gd, shaders/humahuaca_*.gdshader y shaders/humahuaca_noise.gdshaderinc, assets/models/humahuaca/**, assets/audio/humahuaca/**, data/humahuaca_visual.json, tools/vis_humahuaca.gd (y su .sh), tools/generate_audio_humahuaca.py, tests/test_hx_view.gd, docs/humahuaca/VISUAL.md y CREDITOS_VISUAL.md, y agregar al final de docs/ASSETS.md',
    diseno: 'DISENO §11 (dirección de arte, completa), §3 (escala), §4 (consecuencias visuales del relieve)',
    r10: 'scripts/humahuaca/stubs/stub_view.gd (plano de terreno, cajas con la huella de cada hito, una ficha por agrupación, luz, initial_frame que incluye los tres objetivos, picking y get_minimap_texture), scripts/humahuaca/view/vocab_view.gd y data/humahuaca_visual.json con la paleta de 24 HEX, las 7 vistas con su must_show (borrador) y el initial_frame',
  },
  ui_feel: {
    slug: 'ui', desc: 'INTERFAZ Y SENSACIÓN DE JUEGO: controlador HumahuacaUI, HUD, panel de agrupaciones, acciones contextuales, alertas, diálogos (briefing, parte, epílogo), cámara y entrada, onboarding, tutorial, ayuda, textos sin jerga y pruebas de interfaz.',
    propios: 'scripts/humahuaca/ui/** (humahuaca_ui.gd, humahuaca_hud.gd, humahuaca_overlay.gd, humahuaca_dialogs.gd, humahuaca_ui_kit.gd, humahuaca_camera.gd, vocab_ui.gd y auxiliares), data/humahuaca_ui.json, tools/ui_qa_humahuaca.gd, tests/test_hx_flow.gd, docs/humahuaca/CONTROLES.md',
    diseno: 'DISENO §2 (arco), §5 (acciones e información), §8 y §9 (aprendizaje, onboarding y lenguaje)',
    r10: 'scripts/humahuaca/ui/humahuaca_ui.gd (primera versión del controlador a partir de la cáscara de T0, con carga con respaldo de las otras capas), scripts/humahuaca/ui/vocab_ui.gd y data/humahuaca_ui.json mínimo (lista negra cerrada con siglas y palabras, textos del briefing)',
  },
}
const SPEC = {
  'R0': { sec: '6.3', rama: null, max: 2, titulo: 'andamiaje T0', ev: 'r0' },
  'R1.0': { sec: '8.1', rama: 'r1-0', max: 2, titulo: 'stubs primero', ev: 'r1' },
  'R1': { sec: '8.2', rama: 'r1', max: 3, titulo: 'corte vertical mínimo', ev: 'r1' },
  'R2a': { sec: '8.3', rama: 'r2a', max: 3, titulo: 'núcleo legible', ev: 'r2a' },
  'R2b': { sec: '8.4', rama: 'r2b', max: 3, titulo: 'profundidad y contrapesos', ev: 'r2b' },
  'R3': { sec: '8.5', rama: 'r3', max: 2, titulo: 'pulido y verificación', ev: 'r3' },
  'R4': { sec: '8.6', rama: 'r4', max: 3, titulo: 'cierre y certificación', ev: 'r4' },
}
const ESC = {
  'R0': 'T01, T02, E05 (T03 solo se informa)',
  'R1.0': 'compuerta rápida y corridas degradadas de test_hx_smoke (no se convoca a QA)',
  'R1': 'T01 T02 E05 + T03 T04 T05 T06 T07 J01 J02 C01 (completo a 1280x720 y desborde en las otras dos) R01 R02 R06 H01; solo se informan C03 J03 J04 J08 V02 V06',
  'R2a': 'lo de R1 + T08 C03 C04 C05 V02 V03 V06 R03 R04 R05 H02 H03 (H01 con su leyenda; C01 completo a las tres resoluciones); solo se informan J03 J04 J05 J06 J07 J08 V01 V04 V05 C02 E03',
  'R2b': 'lo de R2a + J03 J04 J06 J08 V01; J01 completo (aperturas y causas); solo se informan J05 J07 V04 V05 C02 E03',
  'R3': 'lo de R2b + J05 J07 V04 V05 C02 E03; solo se informan E01 E02 E04',
  'R4': 'los 41 criterios',
}

// ---------- prompts ----------
function promptPista(id, pase, pista, brief, herr, abiertos) {
  const P = PISTAS[pista], S = SPEC[id]
  const suf = S.rama + (pase > 1 ? '-p' + pase : '')
  const rama = 'hx-' + P.slug + '-' + suf
  const wt = REPO + '/.claude/worktrees/' + rama
  const mias = (abiertos || []).filter(f => f.pista === pista)
  const entrega = id === 'R1.0'
    ? 'SOLO STUBS (≤ 1 h de trabajo; CONTRATO §7 y §8.1): ' + P.r10 + '. Todo válido contra test_hx_data y las corridas degradadas de test_hx_smoke. No implementes nada más: queda congelado desde el merge.'
    : (id === 'R4'
      ? 'R4 = CIERRE: ninguna pista agrega contenido. Corregí SOLO la lista cerrada de hallazgos de abajo (CONTRATO §8.6).'
      : 'Tu fila de la tabla de CONTRATO §' + S.sec + ' (entregá todo lo que dice; si algo no entra, descartá en el orden de DISENO §14 y anotalo en tu informe para BACKLOG.md) más los hallazgos abiertos de abajo.')
  return `${COMUN}

RONDA ${id}${pase > 1 ? ' (pase ' + pase + ')' : ''} — ${S.titulo}. TU PISTA: ${pista} — ${P.desc}
AISLAMIENTO: NO trabajes en ${REPO} directamente. Creá tu worktree con rutas absolutas: git -C ${REPO} worktree add -b ${rama} ${wt} main (si la rama ya existe, usá el sufijo -b2). Todo tu trabajo y tus commits van en ESA rama; invocá Godot con la ruta absoluta y --path ${wt}; corré --headless --import en el worktree (≈ 9 s). APPDATA propio: export APPDATA="$TEMP/ap_iso_hx_${P.slug}_${id.replace('.', '')}"; rm -rf; mkdir -p. Antes de terminar rebaseá sobre main (git rebase main) y corré la compuerta rápida desde tu worktree (bash tools/qa_gate.sh quick ${P.slug}); una rama que no la pasa NO entra al merge train. Declará la rama y el hash en tu informe.
TU PROPIEDAD EXCLUSIVA (CONTRATO §1.2): ${P.propios}. Nada más (si necesitás algo ajeno, va como pedido escrito en tu informe: id, firma, motivo y prueba de aceptación).
LECTURA (por secciones): CONTRATO §0, §1.2 a §1.4, §2 (los esquemas de tus JSON), §3 (la API de tu capa y la de tus vecinas), §5, §6, §7 y §8 (tu fila); ${P.diseno}; QA_NIVEL2 §2 (las filas de tu dimensión) y §4; los informes de ${PREP} que correspondan (01 dossier, 02 fuentes, 03 arquitectura, 04 herramientas).
BRIEF DE LA RONDA (del lector de informes): ${brief || '(sin brief: usá el contrato)'}
HERRAMIENTAS RECOMENDADAS (del explorador): ${herr || '(sin recomendaciones)'}
ENTREGA DE ESTA RONDA: ${entrega}
HALLAZGOS ABIERTOS DE TU PISTA (resolvelos primero; cada uno trae su prueba de aceptación): ${mias.length ? JSON.stringify(mias) : 'ninguno'}
EVIDENCIA: ≤ 14 JPEG de ≤ 300 KB en ${REPO}/evidence/humahuaca/${S.ev}/${P.slug}/ más metrics_${P.slug}.json; las capturas son reales y las miraste con Read. Las rondas intermedias NO entran a Git (están ignoradas): no uses git add -f.
CIERRE: commits claros con el trailer; sin push; árbol limpio en tu worktree. Devolvé el resultado estructurado: rama, commit, entregado, no_entregado, pruebas con cifras REALES, capturas, pedidos y permisos_pendientes.`
}

function promptLector(id, abiertos, integ) {
  const S = SPEC[id]
  return `${COMUN}

TAREA: LECTOR DE INFORMES — ronda ${id} (${S.titulo}). Solo lectura: no edites nada del repo. Leé: (1) CONTRATO_HUMAHUACA.md §${S.sec} (las filas de las cuatro pistas y del integrador) y §5.1; (2) DISENO_HUMAHUACA.md §14 y las secciones que toca cada pista; (3) QA_NIVEL2.md §2 (escalera y filas exigibles de la ronda: ${ESC[id]}); (4) los hallazgos abiertos: ${cut(abiertos, 6000)}; (5) el informe de la integración anterior: ${cut(integ, 3000)}; (6) docs/humahuaca/ADDENDA.md y BACKLOG.md si existen; (7) en ${PREP} lo que haga falta (01 dossier, 02 fuentes, 03 arquitectura, 04 herramientas).
Producí un BRIEF por pista (≤ 450 palabras cada uno): qué entregar esta ronda (con ids de criterio de la rúbrica), qué secciones leer (encabezados o líneas), hechos y números clave que NO deben equivocarse (del dossier, de las fuentes y de los JSON), trampas conocidas (tabs y LF, CRLF de archivos existentes, sin class_name, regla de dependencia hacia abajo, ganchos de main.gd solo del integrador, protegidos), y qué pedir al integrador. Agregá 'alertas': contradicciones o huecos entre diseño, contrato y rúbrica que haya que resolver por addendum. Devolvé el resultado estructurado.`
}
function promptExplorador(id, abiertos) {
  return `${COMUN}

TAREA: EXPLORADOR DE APLICACIONES Y SKILLS — ronda ${id}. No edites el repo ni instales ni descargues nada. Partí del inventario de ${PREP}/04_herramientas.md y de las novedades (DEM bajado; Blender NO autorizado). Para esta ronda y estos hallazgos abiertos (${cut(abiertos, 3000)}), decidí por pista qué herramientas, skills y conectores conviene usar y cómo (comandos probados): Godot ${GODOT}, Python con numpy/scipy/Pillow/scikit-image/tifffile (verificá con import real), git, la lectura del DEM Copernicus con la receta de ${PREP}/receta_dem.py, el generador procedural de modelos, las skills del entorno que sirvan (game-development, run, design:design-critique, design:accessibility-review, design:ux-copy, etc.: probá que se pueden invocar). Verificá con comandos reales que todo sigue disponible. Si algún hallazgo o entrega exige algo que falta (una biblioteca, una app, una descarga), listalo en permisos_pendientes con nombre exacto, origen, tamaño, motivo y alternativa sin permiso. Devolvé el resultado estructurado.`
}

function promptIntegrador(id, pase, res, abiertos) {
  const S = SPEC[id]
  const partes = Object.keys(PISTAS).map(k => '--- ' + k + ' ---\n' + (res && res[k] ? cut(res[k], 2800) : 'SIN RESULTADO (la pista falló o no corrió: corre en respaldo con su stub)')).join('\n')
  const mios = (abiertos || []).filter(f => f.pista === 'integrador')
  const extra = id === 'R1'
    ? '\n6) R1: ademàs de tu zona, la ronda cierra con la captura de la cámara inicial en caja gris: dejala en evidence/humahuaca/r1/inicial_caja_gris.jpg (miráda con Read).'
    : (id === 'R3' ? '\n6) R3: armá un EXE informativo (python tools/build_release.py --godot <ruta> con el APPDATA REAL, que tiene las plantillas de exportación) en entregas/0.5.0-preview1/ y verificá que incluye data/humahuaca_*.json, shaders/humahuaca_* y assets/models/humahuaca; no cuenta todavía.' : '')
  return `${COMUN}

RONDA ${id}${pase > 1 ? ' (pase ' + pase + ')' : ''} — INTEGRADOR (único autor de main.gd, del vocabulario compartido y de los merges). Trabajás en ${REPO}, rama main (debe estar limpia; si no, entendé qué hay antes de seguir). Informes de las pistas:
${partes}
HALLAZGOS ABIERTOS PARA TI (integrador): ${mios.length ? JSON.stringify(mios) : 'ninguno'}
Tareas (CONTRATO §6.1, §6.4, §7 y §8.${S.sec.split('.')[1] || ''}):
1) Merge train en el orden relieve_mapa -> reglas_historia -> visual -> ui_feel con la rama declarada por cada pista (git branch --list 'hx-*'): para cada una comprobá la compuerta rápida sobre la rama rebaseada (bash tools/qa_gate.sh quick <pista>); si pasa, git merge --no-ff -m "Merge hx-<pista>-<ronda>"; si no pasa o la pista devolvió null, NO entra: queda el stub o lo último verde y se anota como P0 de esa pista para la ronda siguiente (fallos_abiertos). Conflictos: gana el dueño del archivo (CONTRATO §6.1).
2) Pedidos entre pistas: aplicá los que sean ganchos de main.gd (un commit propio hook-N) y registrá addenda en docs/humahuaca/ADDENDA.md; el resto respondelo en el informe.
3) Compuerta COMPLETA de cierre (bash tools/qa_gate.sh full) con APPDATA aislado y cifras reales: test_rules ≥ 871, test_integration ≥ 283, jev 15, audio (1 falla aceptada), ui_qa x3 ≥ 254, justina_playthrough y los test_hx_* con los pisos de la ronda. NO corras benchmark (lo corre el jefe de QA a solas, sin otras ventanas).
4) Capturas reales de integración (inicio, aproximación, ataque, extracción, derrota y victoria) y MIRALAS con Read; corregí solo defectos de tu zona; los de otra pista vuelven como fallos_abiertos con su pista.
5) Commit(s) en main con el trailer; sin push; borrá las ramas hx-* ya fusionadas y sus worktrees (solo las de esta ronda; no toques las viejas). main limpia al terminar.${extra}
Devolvé el resultado estructurado con el commit final y las cifras REALES.`
}

function promptCompuertas(id, pase, integ) {
  const S = SPEC[id]
  const porRonda = {
    'R1.0': '- Corré test_hx_smoke con las cinco combinaciones degradadas (terreno, reglas, vista, interfaz y progreso reemplazados de a uno por su stub) y la ida y vuelta x3; actualizá TRAZA.md. compuerta_verde = rápida verde + degradadas ok.',
    'R1': '- Escribí tools/hx_qa_tour.gd (las 7 vistas canónicas + 3 de calibración de albedo + 4 de límite de cámara + hoja de fichas + scene_names.txt + qa_report.json, CONTRATO §5.1) y tools/hx_agent_play.gd (arnés por turnos del agente-jugador: escribe turno_NN.png, espera accion_NN.json con clic/tecla/esperar, inyecta como ui_qa, avanza con qa_step, registra primera_orden_turno y primera_orden_t_s; NO expone qa_state ni código), ambos con su salida a un --out propio. Corré el tour y el arnés (una partida de prueba por turnos con un guion tuyo) y verificá que funcionan.\n- Dejá la captura de la cámara inicial en caja gris en evidence/humahuaca/r1/inicial_caja_gris.jpg.',
    'R2a': '- Completá hx_qa_tour (7 vistas, albedo, límites, hoja de fichas, probes) y subí test_hx_data a ≥ 60; verificá que el arnés del agente-jugador sigue andando.',
    'R2b': '- TRAZA.md completa (V20: cada exigencia con prueba nombrada que existe); verificá el arnés y el tour; BACKLOG.md al día con lo descartado.',
    'R3': '- Sanidad por mutación con la rúbrica: rompé a propósito 8 reglas clave en una copia y comprobá que cada una hace fallar al menos una prueba; evidencia final; docs de créditos preparados (CREDITOS.md es tuyo: concatená CREDITOS_RELIEVE.md, CREDITOS_VISUAL.md y los créditos de audio, con OpenStreetMap/ODbL y la atribución del DEM).',
    'R4': '- Evidencia final de R4: evidence/humahuaca/r4/ (únicamente las 14 capturas obligatorias del anexo B del QA, las 7 vistas a 1280x720 y las 4 de límite, a JPEG ≤ 300 KB con INDEX.json de SHA-256 de los originales, más los metrics); evidence/humahuaca/ < 60 MB; docs/CREDITOS.md final; TRAZA.md completa. Esta evidencia entra a Git en un commit propio.',
  }
  return `${COMUN}

RONDA ${id}${pase > 1 ? ' (pase ' + pase + ')' : ''} — COMPUERTAS Y DOCUMENTOS (CONTRATO §1.2 tu fila: tests/test_hx_data.gd, test_hx_smoke.gd, hx_fixtures.gd, tools/qa_gate.sh, tools/hx_qa_tour.gd, tools/hx_agent_play.gd, docs/humahuaca/{BACKLOG,TRAZA,PLAYTEST}.md y forma/*.json, docs/CREDITOS.md, evidence/humahuaca/** salvo <ronda>/qa/**). El integrador ya fusionó en main (${cut(integ, 2500)}). Trabajás en ${REPO}, rama main limpia, después del integrador.
Tareas:
- Corré la compuerta completa que te corresponde (bash tools/qa_gate.sh full) y reportá cifras REALES; NO corras benchmark (lo corre el jefe de QA a solas).
${porRonda[id] || ''}
- Mantené docs/humahuaca/BACKLOG.md (agregá lo que el QA mande a backlog y lo que las pistas descartaron) y TRAZA.md.
- Si algo del andamiaje falla por un archivo de otra pista o del integrador, NO lo arregles vos: devolvelo en fallos con su pista.
Commit en main con el trailer; árbol limpio; sin push. Devolvé el resultado estructurado.`
}

const LENTES = {
  tecnica: 'INGENIERO DE CALIDAD escéptico. Sobre el commit integrado de main (tu propio worktree detached de ese commit, APPDATA aislado): re-ejecutá con timeout las suites de regresión y las del nivel (test_rules, test_integration, jev_contract_test, audio_runtime_test, test_hx_*; ui_qa x3 y justina_playthrough si la ronda lo exige), buscá errores de script o de shader, fugas de ObjectDB, problemas de guardado y carga, robustez (partidas aleatorias), determinismo y regresión de la Justina y del Norte (línea base en CONTRATO §5.2). NO corras benchmark. Reportá cifras reales.',
  usabilidad: 'EVALUADOR DE USABILIDAD sin contexto. Leé SOLO README.md y docs/humahuaca/CONTROLES.md (si existe); luego jugá la escena real (tools/ui_qa_humahuaca.gd, hx_qa_tour o el EXE si existe) e intentá: entender el objetivo, dar la primera orden, leer estado y avisos, perder y reintentar. Medí C01 a C05 (solapes y recortes a 1280x720, 1920x1080 y 2560x1440; ≤ 5 controles y ≤ 400 caracteres en el primer cuadro; jerga cero; menú de tres botones; derrota que enseña y reintento ≤ 3 s). MIRÁ cada captura con Read.',
  visual: 'DIRECTOR DE ARTE escéptico. Generá las vistas canónicas con tools/hx_qa_tour.gd (--qa=humahuaca) y MIRÁ una por una con Read. Juzgá: continuidad del terreno hasta el horizonte (sin "zona definida vs genérica"), cámara inicial, legibilidad de los tres objetivos, edificios y fichas a distancia de juego (noche y alba), paleta del dossier (06_paletas.png), comparación con la foto de 1923 (v04) y con la lámina 03, luces y lluvia, costuras, z-fighting, planos lisos o cajas de relleno. En R1 el arte es provisional (exigí legibilidad, no belleza); desde R2a exigí arte final de las dos vistas de juego. Usá Pillow para medidas objetivas (ΔL*, bordes, correlación) cuando puedas.',
  relieve_historia: 'CARTÓGRAFO E HISTORIADOR escéptico. (a) Relieve: volcá el relieve de HumahuacaTerrain y verificá R01 a R06 contra la lámina 03 (ancla, 41 puntos, curvas de 20 m, río, prominencia de la batería, continuidad) con tus propios cálculos y un overlay. (b) Historia: recorré los textos visibles y los datos (data/*.json, history.json, docs/humahuaca/*) contra el dossier y contra ' + PREP + '/02_fuentes_primarias.md: etiquetas honestas (H01), anacronismos (H02: monumento, torres del templo, premio de Humahuaca en el pecho, sol de la bandera antes de 1818, cruz de Borgoña genérica, uniformes homogéneos, Güemes en el asalto), textos obligatorios (H03). Cada hallazgo con archivo y línea o cita.',
}
function promptLente(id, key, integ, gate) {
  return `${COMUN}

TAREA: REVISOR INDEPENDIENTE (${key}) — ronda ${id}. ${LENTES[key]}
No edites archivos del proyecto (tu evidencia va en ${REPO}/evidence/humahuaca/${SPEC[id].ev}/rev/${key}/, ignorada por Git). Exigible esta ronda (QA_NIVEL2 §2): ${ESC[id]}. Integración de esta ronda: ${cut(integ, 2500)}. Compuertas: ${cut(gate, 1500)}.
Devolvé hallazgos con severidad ALTA (defecto OBJETIVO con evidencia o ítem exigible que falla), MEDIA o BAJA (gusto, mejoras), criterio de la rúbrica o tipo de defecto objetivo, evidencia (captura, archivo y línea, o comando y valor), cómo reproducir, pista dueña y prueba de aceptación de una frase. Sin evidencia no hay hallazgo; el gusto nunca es ALTA.`
}
function promptJugador(id, integ) {
  return `${COMUN}

TAREA: AGENTE-JUGADOR (J08) — ronda ${id}. Vas a jugar por la interfaz real SIN conocer el juego ni su código.
PREPARACIÓN (esto sí lo hacés): creá un worktree detached del commit integrado de main (git -C ${REPO} worktree add --detach "$TEMP/hx_jug_${id.replace('.', '')}" main), importá con --headless --import, APPDATA aislado, y lanzá el arnés en segundo plano: "${GODOT}" --path "<worktree>" --resolution 1280x720 --audio-driver Dummy --script tools/hx_agent_play.gd -- --turns-dir="<RAW>/agente" --seed=9001 --step-s=3 --max-turns=150 --out="<RAW>/agente_arnes.json" (RAW = una carpeta temporal tuya; los PNG pesados no van al repo). Si tools/hx_agent_play.gd no existe o no corre, devolvé resultado 'N' y por qué.
DESDE QUE EL ARNÉS ARRANCA: SOLO podés leer imágenes turno_NN.png y escribir accion_NN.json, bitacora.md y respuestas.json en la carpeta agente, y esperar con sleep. NO abras ningún otro archivo ni carpeta, ni el repo, ni qa_state, ni docs. Contá honestamente en lecturas_fuera_de_carpeta cuántas veces lo hiciste (debe ser 0).
TEXTO DE JUEGO (se pega tal cual): «Vas a jugar un videojuego histórico de estrategia en tiempo real que se puede pausar. No conocés las reglas. En la carpeta agente aparecen imágenes turno_NN.png: es lo que ves en pantalla. Para actuar escribí accion_NN.json con {"tipo":"clic","x":..,"y":..,"boton":"izq"} (o "der"), {"tipo":"tecla","tecla":"4"} o {"tipo":"esperar","s":3}; después aparece el turno siguiente. Antes de cada acción anotá en bitacora.md qué ves, qué entendés y qué probás. Si perdés, podés reintentar. Al terminar (o a los 150 turnos) escribí respuestas.json con {"objetivo":"...","entendiste":"...","aburrimiento":"...","aprendido":"..."}: qué había que lograr, si entendiste qué hacer, cuándo te aburriste y por qué, y qué harías distinto.»
Al terminar: medí primera orden aceptada (turno y segundos de juego; umbral J08: ≤ 8 turnos y ≤ 40 s), si dijiste con tus palabras ≥ 2 de 3 conceptos (tomar los tres frentes; sacar carga; antes del refuerzo o del alba), si llegaste a un parte en ≤ 150 turnos y qué aprendiste al perder. Integración de la ronda: ${cut(integ, 1500)}. Los hallazgos que reportes (de claridad, ritmo o aburrimiento) llevan evidencia (turno y captura). Devolvé el resultado estructurado.`
}

function promptQA(id, pase, integ, gate, revs, jug, abiertos) {
  return `${COMUN}

ERES EL JEFE DE CONTROL DE CALIDAD (certificador A en solitario) — ronda ${id}${pase > 1 ? ' (pase ' + pase + ')' : ''}. Leé ${REPO}/docs/QA_NIVEL2.md COMPLETO salvo el cuerpo de código del anexo A (se extrae con el procedimiento P0) y el anexo E; aplicá sus reglas LITERALMENTE: la rúbrica está congelada, nadie mueve postes. Commit a evaluar: el HEAD de main tras la integración (${cut(integ && integ.commit, 80)}); trabajá en tu worktree detached de ese commit, con tu propio APPDATA y evidencia en ${REPO}/evidence/humahuaca/${SPEC[id].ev}/qa/A/ (ignorada por Git en rondas intermedias).
EXIGIBLE EN ${id} (escalera de §2): ${ESC[id]}. Corré los procedimientos de los ítems exigibles (y medí e informá los demás cuando sea barato). Si una herramienta del anexo A no coincide con la API real, corregila con una "QA enmienda N:" (anexo F; el umbral no cambia; commit solo de docs/QA_NIVEL2.md).
ENTRADAS: hallazgos CRUDOS de los revisores (verificalos y reproducilos; aceptá solo los que cumplan la regla 1 de §4 —defecto objetivo con evidencia— o sean ítems de la rúbrica; el gusto va a backlog o como MEDIA sin bloquear): ${cut(revs, 9000)}; corrida del agente-jugador (J08; informativa hasta R2a, exigida desde R2b): ${cut(jug, 3500)}; compuertas: ${cut(gate, 2000)}; integración: ${cut(integ, 2500)}.
HALLAZGOS PREVIOS ABIERTOS (verificá cierre o regresión y aplicá la escalada: un P1 arrastrado dos rondas pasa a P0): ${cut(abiertos, 5000)}.
El benchmark (P3) lo corrés vos, a solas: no hay otras ventanas abiertas ahora.
PUBLICÁ: tabla de estado de los 41 (P/F/N/NE = no exigible aún) y como máximo 7 hallazgos con id H-${id}-<n>, severidad P0 (BLOQUEA) / P1 (ALTA) / P2 (MEDIA, tope de 3 con razón escrita), evidencia (ruta y valor), repro, pista dueña y prueba de aceptación; BAJA va a la lista 'backlog' (la agrega a BACKLOG.md el de compuertas). cierre_ok = 0 P0 y ≤ 3 P1 (cada P1 con dueño y ronda de cierre); todo_exigible_en_verde = todos los ítems exigibles pasan. Escribí ${REPO}/evidence/humahuaca/${SPEC[id].ev}/qa/A/ESTADO.md con la tabla. No edites nada más del proyecto. Honestidad: lo que no corriste es N y cuenta como falla.`
}

const GPU = 'TURNO DE GPU: antes de cualquier corrida con ventana o benchmark tomá el candado con: d="$TEMP/hx_gpu.lock"; while ! mkdir "$d" 2>/dev/null; do if [ -n "$(find "$d" -maxdepth 0 -mmin +25 2>/dev/null)" ]; then rmdir "$d" 2>/dev/null; fi; sleep 15; done  y soltalo apenas termine esa corrida con: rmdir "$d". Las corridas headless no lo necesitan.'
function promptCert(c, commit, intento, jug) {
  const foco = { A: 'técnica y entrega (T y E; espejo de C/J/V/R/H no, pero sí de lo que te toque)', B: 'jugabilidad y claridad (C y J; espejo de T y E)', C: 'visual, relieve e historia (V, R y H; espejo de C y J)' }[c]
  return `${COMUN}

ERES EL CERTIFICADOR INDEPENDIENTE ${c} — intento ${intento}. Foco primario: ${foco}. Aplicá docs/QA_NIVEL2.md v1.2 LITERALMENTE (leelo completo salvo el cuerpo de código del anexo A, que se extrae con P0): las secciones 2 a 6 mandan; la rúbrica está congelada y no podés agregar ítems ni mover umbrales. COMMIT CERTIFICADO (el mismo para los tres): ${commit}. Corré P0 y los procedimientos de tus criterios primarios y de los espejos (§6: cada criterio lo evalúan al menos dos; los de juicio visual o textual V01, V02, R03, R06, H02 y H03 los evalúan los tres) con TU PROPIO worktree detached, APPDATA y carpeta de evidencia (export CERT=${c} RONDA=r4; EV=${REPO}/evidence/humahuaca/r4/qa/${c}). No leas el veredicto de otro certificador hasta entregar el tuyo. Solo lectura sobre el proyecto salvo tu carpeta de evidencia. Abrí con Read, una por una, las 14 capturas obligatorias, el overlay y las 4 de límite de cámara, y declaralo.
${GPU}
El agente-jugador (J08) ya corrió una vez sobre este commit; su bitácora y resultado: ${cut(jug, 3500)} (B y C la evalúan; el arnés y qa_agente.py están en las herramientas extraídas).
Escribí veredicto.json (formato de §6: rubrica, rubrica_sha256 del docs/QA_NIVEL2.md del commit, commit, ronda, certificador, criterios con v = P/F/N más medición y evidencia, hallazgos y no_ejecutado) y VEREDICTO.md con la misma tabla. Un P sin evidencia vale N; N falla. Devolvé el resultado estructurado.`
}
function promptConsolidar(commit, certs, jug, intento) {
  return `${COMUN}

ERES EL JEFE DE CONTROL DE CALIDAD — consolidación de la triple certificación (intento ${intento}). Commit certificado: ${commit}. Leé QA_NIVEL2.md §5 y §6. Los tres veredictos están en ${REPO}/evidence/humahuaca/r4/qa/{A,B,C}/veredicto.json (resúmenes: ${cut(certs, 6000)}). Corré qa_veredicto.py (extraelo con P0 si hace falta) para consolidar por mayoría (≥ 2 votos por criterio; empate 1–1 sin tercero = N; una N falla; un F aislado de un certificador contra dos P queda como discrepancia y, si trae evidencia objetiva, lo convertís en hallazgo según la regla 1 de §4 o lo descartás según la regla 3). Verificá que los tres usaron el mismo rubrica_sha256 y el mismo commit, y que los criterios de comando dan los mismos números en dos certificadores (si no: hallazgo ALTA de no reproducibilidad salvo causa explicada). Agente-jugador: ${cut(jug, 2500)}.
Regla de decisión (§5): PRESENTABLE (no certificado por humanos) ⇔ todos los BLOQUEA pasan ∧ 0 ALTA abiertas ∧ ≤ 3 MEDIA con razón escrita (razon_aceptada) ∧ la rúbrica corrió completa sobre un único commit. Si no: NO PRESENTABLE con una lista cerrada de ≤ 7 hallazgos (P0 primero, luego P1, luego P2, con pista dueña y prueba de aceptación) y la tabla de estado de los 41. Escribí evidence/humahuaca/r4/qa/VEREDICTO.md y, si es PRESENTABLE, commiteá la evidencia chica de r4/ (≤ 300 KB por JPEG; evidence/humahuaca < 60 MB) en un commit propio titulado «Evidencia de certificación r4» (los certificados siguen siendo los del commit ${commit}: la evidencia no cambia código). Devolvé el resultado estructurado.`
}

// ---------- mecánica de etapas ----------
function registrarPermisos(tools, res) {
  const nuevos = []
  if (tools && tools.permisos_pendientes) for (const p of tools.permisos_pendientes) nuevos.push(p)
  for (const k of Object.keys(res || {})) if (res[k] && res[k].permisos_pendientes) for (const p of res[k].permisos_pendientes) nuevos.push({ objeto: String(p), motivo: 'pedido por la pista ' + k })
  for (const p of nuevos) if (!estado.permisos.some(q => JSON.stringify(q) === JSON.stringify(p))) estado.permisos.push(p)
}
function conteo(h) { const l = h || []; return { p0: l.filter(x => x.severidad === 'P0').length, p1: l.filter(x => x.severidad === 'P1').length, p2: l.filter(x => x.severidad === 'P2').length } }

async function etapaR0() {
  phase('Andamiaje')
  let pase = 0, verde = false, pend = []
  while (!verde && pase < SPEC['R0'].max) {
    pase++
    const a = await ag(`${COMUN}

RONDA R0 — ANDAMIAJE T0, PARTE DEL INTEGRADOR (pase ${pase}). Trabajás DIRECTAMENTE en ${REPO} (rama main, limpia; nadie más escribe ahora). Leé CONTRATO_HUMAHUACA.md §0, §1, §3.0, §4 (enganches H1 a H9; si los números de línea se corrieron, ubicalos por contexto), §6.3 y §7, y los informes ${PREP}/03_arquitectura_actual.md y la prueba de concepto ${PREP}/03_poc/ (main_gd_ganchos.diff).
Hacé exactamente (CONTRATO §6.3 puntos 1 a 4 y 6):
1) Ganchos H1–H9 en scripts/main.gd con _hx_make (carga con respaldo) y los textos del menú; en tests/test_integration.gd (líneas 15–19) y tools/ui_qa.gd (líneas 38–40) solo la hermeticidad de perfil; tools/run_qa.py (choices suma "humahuaca"); .gitignore y .gitattributes (§4.4). main.gd usa sangría de 1 espacio y tiene ~4462 líneas: respetá ese estilo y no borres lógica; no renormalices fines de línea de archivos existentes.
2) scripts/humahuaca/humahuaca_vocab.gd y los cuatro vocab_<capa>.gd con las listas iniciales de §3.0 (cada dueño los hereda en R1.0).
3) scripts/humahuaca/stubs/stub_ui.gd (cáscara del controlador, ≤ 120 líneas: start(main, opts), stop(), signal exited(to), qa_run(), benchmark_prepare(), qa_* válidos) y su copia en scripts/humahuaca/ui/humahuaca_ui.gd.
4) Los seis JSON mínimos (data/humahuaca_{map,height,level,rules,visual,ui}.json con "contract": 1 y "map_version": 1; height plano con meta.source "lamina03_reconstruida") y el esqueleto scenarios.humahuaca en data/history.json (SOLO agregar; no edites nada existente: los tests del Norte fijan sus textos).
6) docs/humahuaca/ADDENDA.md con: la decisión del canal de arte (generador procedural; Blender NO autorizado), el permiso de la tesela Copernicus S24 (ya descargada: ruta y SHA-256 de arriba) y las decisiones del usuario de esta sesión (alcance aprobado; sin playtesters humanos).
No toques nada protegido (§1.3). Verificá con Godot headless que el proyecto importa (--headless --import) y que test_integration sigue en ≥ 283 (APPDATA aislado, timeout). Commits claros en main con el trailer. Pendientes de un pase anterior: ${pend.length ? JSON.stringify(pend) : 'ninguno'}. Devolvé el resultado estructurado.`, { label: 'R0p' + pase + ':integrador', phase: 'Andamiaje', schema: SCAFF })
    const b = await ag(`${COMUN}

RONDA R0 — ANDAMIAJE T0, PARTE DE COMPUERTAS Y DOCUMENTOS (pase ${pase}). Trabajás DIRECTAMENTE en main de ${REPO}, después del integrador (verificá git log y que el árbol esté limpio). Informe del integrador: ${cut(a, 2500)}. Leé CONTRATO §1.2 (tu fila), §2.4 (V1 a V22), §3.6 (ejemplos de forma), §5 (pruebas, líneas base y cómo se corren), §6.3 a §6.5 y §7, y QA_NIVEL2.md §3 P1 (compuerta técnica y lista de protegidos).
Hacé (CONTRATO §6.3 punto 5 y 7):
- tools/qa_gate.sh con modos "quick <pista>" y "full" (BASE=5ebbd28 al principio; protegidos contra el hash fijo; test_rules --skip-strategies ≥ 818 con failures: []; test_integration ≥ 283; test_hx_data; test_hx_smoke; los test_hx_* de la pista indicada), con APPDATA aislado, timeouts y una línea final PASA o FALLA con cifras. Verificá que tests/test_rules.gd soporta --skip-strategies (es un archivo protegido: no lo edites; si no existiera el flag, documentá la alternativa en ADDENDA.md).
- tests/test_hx_data.gd (V1–V5, V7–V9, V17, V19, V20; piso 40), tests/test_hx_smoke.gd (los 15 chequeos de la prueba de concepto de ${PREP}/03_poc/, la ida y vuelta x3 con la cáscara y el chequeo "el último elemento del menú ≤ alto del viewport"; piso 25) y tests/hx_fixtures.gd.
- docs/humahuaca/forma/*.json (ejemplos de forma de §3.6) y docs/humahuaca/{BACKLOG,TRAZA,PLAYTEST}.md.
- Verificación previa a abrir worktrees (§6.3 punto 7): compuerta rápida VERDE (test_rules --skip-strategies ≥ 818, test_integration ≥ 283, test_hx_data y test_hx_smoke ok, protegidos intactos contra 5ebbd28). Si algo del andamiaje del integrador falla y es chico y obvio, corregilo con un commit aparte «hook-fix:» y avisá; si no, devolvelo en pendientes.
Commit en main con el trailer; árbol limpio; sin push. Devolvé el resultado estructurado con cifras REALES de la compuerta.`, { label: 'R0p' + pase + ':compuertas', phase: 'Andamiaje', schema: SCAFF })
    verde = !!(b && b.compuerta_verde)
    pend = (b && b.pendientes) || (a && a.pendientes) || []
    estado.etapas.push({ id: 'R0', pase, cierre_ok: verde, resumen: cut((b && b.resumen) || 'sin resultado', 500), compuerta: cut(b && b.compuerta, 500) })
    log('R0 pase ' + pase + ': compuerta ' + (verde ? 'VERDE' : 'roja'))
  }
  return verde
}

async function etapaStubs() {
  const id = 'R1.0'
  let pase = 0, cerrada = false, abiertos = estado.abiertos
  while (!cerrada && pase < SPEC[id].max) {
    pase++
    phase('Mejora')
    const claves = Object.keys(PISTAS).filter(k => pase === 1 || abiertos.some(f => f.pista === k))
    const rs = await parallel(claves.map(k => () => ag(promptPista(id, pase, k, '', '', abiertos), { label: id + 'p' + pase + ':' + k, phase: 'Mejora', schema: TRACK })))
    const res = {}; claves.forEach((k, i) => { res[k] = rs[i] })
    phase('Integracion')
    const integ = await ag(promptIntegrador(id, pase, res, abiertos), { label: id + 'p' + pase + ':integrador', phase: 'Integracion', schema: INTEG })
    const gate = integ ? await ag(promptCompuertas(id, pase, integ), { label: id + 'p' + pase + ':compuertas', phase: 'Integracion', schema: GATE }) : null
    cerrada = !!(integ && gate && gate.compuerta_verde && (integ.fallos_abiertos || []).length === 0)
    abiertos = []
    if (integ) for (const f of (integ.fallos_abiertos || [])) abiertos.push({ id: 'I-' + id + '-' + abiertos.length, criterio: 'integracion', severidad: 'P0', titulo: f.problema, evidencia: 'informe del integrador', pista: Object.keys(PISTAS).includes(f.pista) ? f.pista : 'integrador', aceptacion: 'la compuerta rápida pasa' })
    if (gate) for (const f of (gate.fallos || [])) abiertos.push({ id: 'G-' + id + '-' + abiertos.length, criterio: 'compuerta', severidad: 'P0', titulo: f.problema, evidencia: 'informe de compuertas', pista: Object.keys(PISTAS).includes(f.pista) ? f.pista : 'integrador', aceptacion: 'la compuerta pasa' })
    if (integ) estado.commit = integ.commit
    estado.integ = integ
    estado.etapas.push({ id, pase, cierre_ok: cerrada, resumen: cut(integ && integ.resumen, 500), compuerta: cut(gate && gate.mediciones, 500) })
    log(id + ' pase ' + pase + ': ' + (cerrada ? 'cerrada' : 'abierta (' + abiertos.length + ' fallos)'))
  }
  estado.abiertos = abiertos
  return cerrada
}

async function etapaRonda(id) {
  const S = SPEC[id]
  let pase = 0, cerrada = false
  let plan = null
  while (!cerrada && pase < S.max) {
    pase++
    if (pase === 1) {
      phase('Planificacion')
      const pl = await parallel([
        () => ag(promptLector(id, estado.abiertos, estado.integ), { label: id + ':lector', phase: 'Planificacion', schema: BRIEF }),
        () => ag(promptExplorador(id, estado.abiertos), { label: id + ':explorador', phase: 'Planificacion', schema: TOOLS }),
      ])
      plan = { lector: pl[0], explorador: pl[1] }
      if (pl[1]) registrarPermisos(pl[1], null)
      if (pl[0] && pl[0].alertas && pl[0].alertas.length) log('Alertas del lector (' + id + '): ' + cut(pl[0].alertas, 1500))
    }
    phase('Mejora')
    const todas = Object.keys(PISTAS)
    const claves = (pase === 1 && id !== 'R4') ? todas : todas.filter(k => estado.abiertos.some(f => f.pista === k))
    log(id + ' pase ' + pase + ': pistas activas = ' + claves.join(','))
    let res = {}
    if (claves.length) {
      const rs = await parallel(claves.map(k => () => ag(promptPista(id, pase, k, plan && plan.lector && plan.lector.briefs ? plan.lector.briefs[k] : '', plan && plan.explorador && plan.explorador.por_pista ? plan.explorador.por_pista[k] : '', estado.abiertos), { label: id + 'p' + pase + ':' + k, phase: 'Mejora', schema: TRACK })))
      claves.forEach((k, i) => { res[k] = rs[i] })
      registrarPermisos(null, res)
    }
    phase('Integracion')
    const integ = await ag(promptIntegrador(id, pase, res, estado.abiertos), { label: id + 'p' + pase + ':integrador', phase: 'Integracion', schema: INTEG })
    if (!integ) { log('ABORTO de ' + id + ': el integrador no devolvió resultado'); break }
    estado.integ = integ; estado.commit = integ.commit
    const gate = await ag(promptCompuertas(id, pase, integ), { label: id + 'p' + pase + ':compuertas', phase: 'Integracion', schema: GATE })
    if (id === 'R4') { return { integ, gate, pase } }
    phase('Revision')
    const claves2 = Object.keys(LENTES)
    const rv = await parallel([
      ...claves2.map(k => () => ag(promptLente(id, k, integ, gate), { label: id + 'p' + pase + ':rev:' + k, phase: 'Revision', schema: FIND })),
      () => ag(promptJugador(id, integ), { label: id + 'p' + pase + ':agente-jugador', phase: 'Revision', schema: PLAYER }),
    ])
    const revs = {}; claves2.forEach((k, i) => { revs[k] = rv[i] })
    const jug = rv[claves2.length]
    phase('Control de calidad')
    const qa = await ag(promptQA(id, pase, integ, gate, revs, jug, estado.abiertos), { label: id + 'p' + pase + ':jefe-qa', phase: 'Control de calidad', schema: QAR })
    if (!qa) { log('ABORTO de ' + id + ': el jefe de QA no devolvió resultado'); break }
    const hall = (qa.hallazgos || []).slice(0, 7)
    estado.abiertos = hall; estado.commit = qa.commit || integ.commit; estado.tabla = qa.tabla_estado
    cerrada = !!qa.cierre_ok
    const c = conteo(hall)
    estado.etapas.push({ id, pase, cierre_ok: cerrada, todo_verde: !!qa.todo_exigible_en_verde, p0: c.p0, p1: c.p1, p2: c.p2, commit: estado.commit, resumen: cut(qa.resumen, 700), jugador: cut(jug && jug.resumen, 300) })
    log(id + ' pase ' + pase + ': P0=' + c.p0 + ' P1=' + c.p1 + ' P2=' + c.p2 + ' -> ' + (cerrada ? 'CERRADA' : 'abierta'))
  }
  return cerrada
}

async function etapaCierre() {
  const id = 'R4'
  let intento = 0
  while (!estado.certificado && intento < SPEC[id].max) {
    intento++
    // R4: pistas corrigen la lista cerrada; el integrador arma EXE y documentos; luego triple certificación
    phase('Planificacion')
    const pl = await parallel([
      () => ag(promptLector(id, estado.abiertos, estado.integ), { label: 'R4i' + intento + ':lector', phase: 'Planificacion', schema: BRIEF }),
      () => ag(promptExplorador(id, estado.abiertos), { label: 'R4i' + intento + ':explorador', phase: 'Planificacion', schema: TOOLS }),
    ])
    if (pl[1]) registrarPermisos(pl[1], null)
    phase('Mejora')
    const claves = Object.keys(PISTAS).filter(k => estado.abiertos.some(f => f.pista === k))
    const res = {}
    if (claves.length) {
      const rs = await parallel(claves.map(k => () => ag(promptPista(id, intento, k, pl[0] && pl[0].briefs ? pl[0].briefs[k] : '', pl[1] && pl[1].por_pista ? pl[1].por_pista[k] : '', estado.abiertos), { label: 'R4i' + intento + ':' + k, phase: 'Mejora', schema: TRACK })))
      claves.forEach((k, i) => { res[k] = rs[i] })
      registrarPermisos(null, res)
    }
    phase('Integracion')
    const integ = await ag(promptIntegrador(id, intento, res, estado.abiertos) + `

R4 — CIERRE (CONTRATO §8.6 y QA E01–E05): además armás el EXE desde el commit de código ya integrado con python tools/build_release.py --godot <ruta> (APPDATA REAL: tiene las plantillas), lo dejás en entregas/0.5.0-preview1/PatriaGuemes_preview6.exe con SHA256.txt, verificás con tools/verify_embedded_version.gd, actualizás VERSION.json (version 0.5.0-preview1, runtime_source_commit, bytes y SHA-256), project.godot (SOLO config/version y config/description), README.md (tres escenarios), CLAUDE.md (incluí el nivel II), docs/CONTROLES.md, y dejás TODO en un único commit final de documentación sobre el commit de código (entre ambos solo pueden cambiar VERSION.json, README.md, CLAUDE.md, docs/** y evidence/**). El commit final es el que se certifica. Decidí D1b (CONTRATO §4.2) con el valor por defecto: NO reencadenar.`, { label: 'R4i' + intento + ':integrador', phase: 'Integracion', schema: INTEG })
    if (!integ) { log('ABORTO de R4: el integrador no devolvió resultado'); break }
    estado.integ = integ; estado.commit = integ.commit
    const gate = await ag(promptCompuertas(id, intento, integ), { label: 'R4i' + intento + ':compuertas', phase: 'Integracion', schema: GATE })
    // agente-jugador sobre el commit a certificar, luego los tres certificadores en paralelo y la consolidación
    phase('Certificacion')
    const jug = await ag(promptJugador(id, integ), { label: 'R4i' + intento + ':agente-jugador', phase: 'Certificacion', schema: PLAYER })
    const commit = integ.commit
    const certs = await parallel(['A', 'B', 'C'].map(c => () => ag(promptCert(c, commit, intento, jug), { label: 'R4i' + intento + ':cert:' + c, phase: 'Certificacion', schema: CERT })))
    const cons = await ag(promptConsolidar(commit, certs, jug, intento), { label: 'R4i' + intento + ':consolidacion', phase: 'Certificacion', schema: CONS })
    if (!cons) { log('R4: la consolidación no devolvió resultado'); break }
    estado.veredicto = cons.veredicto
    estado.certificado = !!cons.presentable
    estado.abiertos = estado.certificado ? [] : (cons.hallazgos || []).slice(0, 7)
    estado.tabla = cons.tabla_estado
    const c = conteo(cons.hallazgos)
    estado.etapas.push({ id: 'R4', pase: intento, cierre_ok: estado.certificado, p0: c.p0, p1: c.p1, p2: c.p2, commit, resumen: cut(cons.resumen, 700), veredicto: cons.veredicto })
    log('R4 intento ' + intento + ': ' + cons.veredicto)
  }
  return estado.certificado
}

// ---------- ejecución ----------
log('Etapas de esta corrida: ' + ETAPAS.join(' → '))
for (const id of ETAPAS) {
  try {
    if (id === 'R0') await etapaR0()
    else if (id === 'R1.0') await etapaStubs()
    else if (id === 'R4') await etapaCierre()
    else await etapaRonda(id)
  } catch (e) {
    log('ERROR en la etapa ' + id + ': ' + String(e && e.message || e))
    estado.etapas.push({ id, pase: 0, cierre_ok: false, resumen: 'EXCEPCIÓN: ' + String(e && e.message || e) })
    break
  }
}
return { estado, resumen_etapas: estado.etapas.map(e => e.id + (e.pase ? 'p' + e.pase : '') + ': ' + (e.cierre_ok ? 'OK' : 'abierta') + (e.p0 !== undefined ? ' P0=' + e.p0 + ' P1=' + e.p1 + ' P2=' + e.p2 : '')) }