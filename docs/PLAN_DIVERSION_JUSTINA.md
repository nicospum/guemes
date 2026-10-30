# Plan de diversión de la Justina (Ronda 8, diseñador jefe)

Base: preview 4 (commit 3529ded). Insumos: catálogo de clásicos (16 refs), catálogo de código abierto (12 repos), `docs/investigacion/RE_JUEGOS_LOCALES_R8.md`, `docs/investigacion/ANALISIS_DIVERSION_R8.md`, `data/justina_map.json`.

Directriz del usuario (manda sobre todo): la fidelidad histórica es solo una guía; lo que importa es que se pueda jugar y sea entretenido; si perdés, jugás de nuevo, y hay que ganar para pasar al segundo escenario; el Justina es tiempo real con pausa; el Norte no se toca ahora.

## 0. Límites de este plan (honestidad)

- Nadie jugó con personas reales en esta ronda. Todo "humano promedio" sale del Monte Carlo del analista (24 partidas por nivel, ±15 puntos). Los objetivos de la sección 5 son metas a medir con ese mismo modelo y, al final, con el usuario jugando.
- Los catálogos de juegos son de investigación web sin descargar nada; las licencias y rutas marcadas "no verificado" no se verificaron. Regla: de OpenRA, Mindustry, Wesnoth, 0 A.D., Freeciv, etc. (GPL) se toman IDEAS de diseño, nunca código. Solo godot-open-rts (MIT) admite adaptar patrones, con atribución en `docs/CREDITOS.md`.
- Las cifras numéricas de este plan (tiempos, porcentajes, daños) son propuestas a probar con `tools/justina_playthrough.gd`, no valores medidos.
- JEV/TypeSafe no se usó para este documento; no hay conclusión que dependa de él.
- Las derivadas de Civ VI/VII (RE local) son constantes de otro juego tomadas como orden de magnitud, no copias.

## 1. Pilares de diseño

1. **Una cosa clara por vez.** En todo momento el jugador sabe cuál es el objetivo y cuál es el siguiente paso útil, en una línea. Nada de panel de ocho datos al arrancar. (AoE2 Wallace, They Are Billions, OpenRA.)
2. **Perder enseña y reintentar es barato.** El río es el mismo hasta que ganás; lo que descubriste queda anotado; la derrota dice en una frase qué falló y qué probar; volver a jugar toma segundos. (Frozen Synapse, Door Kickers, Shadow Tactics, Oregon Trail.)
3. **Presión visible con picos avisados.** El enemigo y el río avisan antes de pegar (humo, círculo en el suelo, cuenta regresiva), así que un golpe se puede evitar con una decisión y no se siente arbitrario. (They Are Billions, Shadow Tactics, Warcraft/StarCraft.)
4. **Decisiones que cambian el resultado.** Centro, sur y reserva tienen costos y premios distintos; cada partida avisa una variante que inclina cuál conviene; rechazar un contraataque o dispersar bajo una andanada importan. (Wesnoth, OpenRA, Close Combat.)
5. **Se lee de un vistazo.** Unidades con silueta, color y estandarte grandes; buque que se entiende como amenaza; río y barranca con identidad. Si no se ve en una captura a escala de juego, no cuenta. (Total War, Frozen Synapse, Door Kickers.)

Corolario: la historia es ambientación y se etiqueta con honestidad, pero ninguna regla se mantiene "por ser histórica" si aburre. Se conservan solo los dos límites ya fijados: nada de bandera argentina ni Infernales en 1806, y nada inventado presentado como documentado.

## 2. Ciclo de campaña: perder → reintentar con conocimiento → pasar

### 2.1 Estado persistente (archivo de progreso en `user://`, separado de la partida)

- `seed_justina`: se sortea una vez al primer arranque o al "Mundo nuevo" y se **mantiene hasta ganar**. Define pozos, vado, variante de río y variante de misión (ver C10).
- `diario`: lista de hechos aprendidos (ver 2.3).
- `intentos`, `derrotas_seguidas`, `mejor_medalla`, `justina_ganada` (bool).
- `norte_desbloqueado` = `justina_ganada`.

### 2.2 Flujo

1. Menú: "Justina" activo; "Norte" con candado y texto "Ganá la Justina para abrirlo".
2. Intento 1: tutorial de 3 pasos (sección 7). Mismo mundo siempre.
3. Derrota: parte de 1 pantalla (C3): causa en una frase, un consejo, tres datos (captura, bajas, tiempo), botón grande "Reintentar" (mismo río) y chico "Río nuevo". La historia va colapsada.
4. Reintento en menos de 3 segundos hasta tener el control; opción "Desde el cruce" (C4) si ya hubo un reconocimiento.
5. Cada derrota agrega entradas al diario. En el intento siguiente el diario aparece sobre el mapa como marcas tenues "anotado" (no son confirmadas: el explorador las confirma con sondeo, así que sigue habiendo juego).
6. Ayuda en escalera (anti-frustración): derrota 2 seguida → pista de texto concreta del diario ("El pozo del flanco norte te costó 3 tropiezos"). Derrota 3 seguida → se ofrece **"Baqueano"**: revela confirmado un flanco seguro y suma 8 de munición, y queda marcado en el resultado (la medalla máxima exige jugar sin baqueano). Derrota 5 seguida → se ofrece además "Bajante generosa" (ventana de río +60 s). Nunca se impone: es botón opcional.
7. Victoria: pantalla celebratoria con medalla (bronce/plata/oro), tres líneas de por qué, y "Se desbloqueó: Sostener el Norte". Se fija `justina_ganada`. Después de ganar, "Rejugar" sortea mundo nuevo y variante para mejorar medalla.
8. Pasar al segundo escenario exige haber ganado una vez (cualquier medalla).

### 2.3 Qué entra al diario

| Evento | Entrada | Efecto en el próximo intento |
|---|---|---|
| Un grupo tropieza en un pozo | "Pozo del flanco X" | Marca "anotado" sobre ese tramo |
| Un sondeo revela un vado | "Vado en Y" | Marca "anotado" |
| El buque barre una zona | "Zona de fuego del costado" | Círculo tenue del alcance |
| Derrota por plazo | "Llegaste tarde: el río subió a las MM:SS" | Recordatorio de reloj en el objetivo |
| Variante de misión | "Hoy: costado fuerte al sur" | Ya visible desde el segundo 0 (C10) |

## 3. Ritmo de una partida de 10–15 minutos (curva de tensión)

Objetivo: victoria típica en 10 a 13 minutos de juego a ×1 (con ×2 en esperas), derrota típica en 4 a 9 minutos (no más). Hoy: 12–14 min para ganar y 8–18 para perder. Tiempos en minutos de juego, a probar con el playthrough.

| Tramo | Qué pasa | Tensión | Hito / recompensa |
|---|---|---|---|
| 0:00–0:30 | Despliegue y aviso de Liniers (variante de misión). Un solo objetivo en pantalla. | baja | Primera orden clara: "mandá un explorador" |
| 0:30–2:30 | Acto 1, Reconocer. Sondeos, mensajero de Liniers con una elección (munición o voluntarios), primer tiro del buque telegrafiado a los 2:00. | sube | Primer pozo/vado revelado: "anotado en el diario" |
| 2:30–3:30 | Se abre la ventana del vado (hoy 5:36–7:30). Sonido y banner "El vado cede". | pico 1 | Hito 1: Vado marcado (+1 estrella) |
| 3:30–7:00 | Acto 2, Cruce. Elegir ruta; marcha en barro; andanada del buque cada 45 s con aviso; evento de campo cada 60–90 s. | alta con respiro entre andanadas | Hito 2: Orilla alcanzada (+1 estrella) |
| 7:00–8:00 | Respiro táctico: reunir, abastecer, curación en zona propia. | baja | Decisión: cuánto esperar |
| 8:00–10:30 | Acto 3, Abordaje. Contraataques en cubierta con aviso de 5 s; andanada fuerte; captura sube con riesgo. | pico 2 y final | Hito 3: Cubierta tomada |
| 10:30–11:00 | Remate o último esfuerzo (reserva única). | máximo | Victoria / medalla |
| 13:00 | Plazo duro del río (hoy 18:00). A los 9:30 aparece la marea que vuelve y la zona segura se achica. | presión de fondo | — |

Reglas de ritmo:
- Nunca más de 90 s sin un evento, aviso o decisión en los primeros 5 minutos.
- Después del despliegue, ×2 sugerido durante esperas, y vuelve solo a ×1 cuando hay evento.
- Picos alternan con respiros: tras una andanada fuerte, 20 a 30 s sin fuego fuerte.
- Compresión del río: bajante 30–240 s, mínimo 240–600 s, subida desde 600 s, plazo 780 s (a validar con el recorrido; si la ruta sur no llega, se agranda el plazo o se acelera la marcha, no se vuelve a una bajante lenta).

## 4. Lista priorizada de cambios (20)

Criterio de prioridad: P0 = sin esto no hay MVP divertido; P1 = muy recomendable; P2 = pulido. Pistas: `mapa_reglas` (reglas, datos, balance), `visual` (render, arte, shaders), `ui_feel` (interfaz, flujo, feedback, progreso).

### P0

**C1. Mundo fijo hasta ganar** (`mapa_reglas`, con menú en `ui_feel`)
- Qué cambia: `forced_seed` deja de ser -1 en cada partida; la semilla se guarda en el progreso y solo cambia con "Río nuevo" o tras ganar. Hoy reintentar sortea otro mundo (`main.gd:432`).
- Inspira: Oregon Trail (reintento corto con "mejorar el próximo intento"), Frozen Synapse (replay del mismo escenario), Wesnoth ("rejugar escenario").
- Aceptación: en 50 reinicios automáticos tras derrota, pozo, vado y variante de río son idénticos 50/50; "Río nuevo" cambia al menos uno en 20/20; la semilla sobrevive a cerrar y abrir el juego (test de integración); tests existentes siguen verdes con `forced_seed` fijo.

**C2. Diario del Bañado** (`ui_feel` + datos en `mapa_reglas`)
- Qué cambia: lista persistente de hechos descubiertos o sufridos; marcas "anotado" tenues en el mapa del siguiente intento; pantalla "Diario" accesible desde el menú y la pausa.
- Inspira: Civilopedia de Civ VI que se va llenando, Battle Brothers (la derrota deja algo), Wesnoth (info de terreno en un clic).
- Aceptación: tras una partida que descubrió N rasgos ocultos, el siguiente inicio muestra exactamente esas N marcas (test); las marcas no cuentan como "confirmadas" para reglas (el sondeo sigue revelando); el diario cabe en una pantalla a 1280x720.

**C3. Parte de derrota que enseña** (`ui_feel`)
- Qué cambia: arriba, una frase de causa en lenguaje de jugador y un consejo accionable, generados por `defeat_cause`, `stumble_at`, `scouts_lost`, `exposure_s` (ya calculados en `campaign_report()`); botón "Reintentar" arriba y sin scroll; la historia queda en un desplegable.
- Inspira: Frozen Synapse (replay que explica), Door Kickers y Shadow Tactics (quién te vio y desde dónde).
- Aceptación: el 100 % de las causas de derrota definidas tienen texto (test que recorre todas); el botón "Reintentar" es visible sin scroll en 1280x720, 1600x900 y 1920x1080 (`ui_qa.gd`); el texto de causa tiene ≤ 140 caracteres y no usa jerga ("ZOC", "tag", "halted_by_expiry").

**C4. Reintento rápido y "Desde el cruce"** (`ui_feel`, apoyo `mapa_reglas`)
- Qué cambia: de la pantalla de derrota al control en ≤ 3 s; recarga sin pasar por menú. Si ya se hizo un reconocimiento, se ofrece reanudar desde un guardado automático al abrir el vado.
- Inspira: Shadow Tactics y Desperados (quicksave: perder cuesta segundos), Door Kickers.
- Aceptación: clic en "Reintentar" a primer cuadro jugable ≤ 3 s en el equipo de prueba (medido en `ui_qa`); el guardado automático restaura exactamente el estado (hash de estado del reglamento igual tras restaurar en 20 semillas). Si el snapshot resulta costoso de implementar, se difiere a P1 sin bloquear el resto.

**C5. Río y partida comprimidos** (`mapa_reglas`)
- Qué cambia: tiempos de la sección 3 (bajante, mínimo, subida, plazo), marcha un poco más rápida, vado que abre antes de 3:30. Se eliminan las variantes de río que vuelven injusta la partida ("breve" sin compensación) o se pagan con una compensación y se muestran en C10.
- Inspira: Mindustry y They Are Billions (partidas cortas, fallar y reintentar barato), análisis de diversión (problemas 3, 4 y 12).
- Aceptación: con el guion fuerte, mediana de victoria entre 9 y 12 minutos en 30 semillas; ninguna variante de río deja al guion fuerte con menos de 55 % de victoria; la ventana del vado abre ≤ 3:30 en todas las variantes; derrota por plazo suele ocurrir ≤ 13:00.

**C6. Objetivo en una línea y tutorial de 3 pasos** (`ui_feel`)
- Qué cambia: panel inicial mínimo: objetivo + siguiente paso sugerido, que cambia con el estado ("1. Mandá un explorador (Z). 2. Esperá a que el vado ceda. 3. Señalá a Liniers y cargá"). El paso de señal sale del primer minuto. "Retirada general" se mueve a un menú de pausa y no está en la barra principal. Jerga fuera del panel.
- Inspira: AoE2 Wallace (un objetivo por vez), OpenRA (panel de objetivos), Shadow Tactics (una mecánica nueva por tramo).
- Aceptación: a los 30 s de juego aparece como máximo 1 objetivo y 1 paso (assert de UI); el tutorial nunca ordena gastar la señal antes de que el vado esté a ≤ 60 s; "Retirada general" necesita 2 clics; ningún término de una lista negra de jerga aparece en el panel (test de cadenas).

**C7. Fuego del buque telegrafiado** (`visual` + `mapa_reglas`)
- Qué cambia: cada descarga muestra humo de cañón, un círculo en el suelo y una cuenta de 3 s sobre el grupo apuntado; se puede dispersar o cubrir; andanada fuerte cada 45 s (más fuerte que la media) con aviso de 4 s.
- Inspira: They Are Billions (cuenta regresiva de oleada), Shadow Tactics (conos y alcance dibujados), Warcraft/StarCraft (aviso de ataque).
- Aceptación: toda descarga tiene marcador visible ≥ 2,5 s antes del impacto (test sobre la cola de eventos); un guion que dispersa al recibir el aviso reduce el daño por andanada en ≥ 50 % frente a uno que no reacciona; el aviso se lee en captura a escala de juego.

**C8. Contraataques con consecuencias reales** (`mapa_reglas`)
- Qué cambia: rechazar un contraataque cuesta munición y tiempo pero conserva la cubierta; no rechazar baja la captura de −9 a −25 y puede dispersar un grupo; evacuar salva a un grupo entero. Aviso de 5 s; la pausa automática pasa a ser corta (2 s) en dificultad normal.
- Inspira: Close Combat (moral central), análisis de diversión (problema 6), Wesnoth (predicción antes de actuar).
- Aceptación: en 18 semillas, la política `noreply` gana al menos 25 puntos menos que la que rechaza; evacuar un grupo en peligro lo salva en ≥ 90 % de los casos con aviso a tiempo; el aviso aparece 5 s antes.

**C17. Norte bloqueado y victoria con medalla** (`ui_feel`)
- Qué cambia: candado hasta ganar la Justina; pantalla de victoria con medalla, 3 estadísticas y desbloqueo; derrota sin botón de ir al Norte.
- Inspira: Wesnoth (campaña con reintento), Freeciv/Civ (pantalla de cierre con puntaje).
- Aceptación: perfil nuevo: botón del Norte deshabilitado (test de UI); tras victoria queda habilitado y persiste; derrota nunca muestra "Ir a la campaña del norte".

### P1

**C9. Rutas con identidad** (`mapa_reglas`)
- Qué cambia: Centro = rápido, premio de captura ×1,3, riesgo de pozo y fuego directo del costado. Sur = lento, protegido del costado fuerte pero con vado sensible a la marea y fuego de costa, y gasta munición. Reserva/mixta = flexible pero exige coordinar. Ninguna ruta domina.
- Inspira: Oregon Trail (opciones de cruce con distinta chance de fallar), Wesnoth (terreno visible), Civ VI (terreno con signo: colina/bañado).
- Aceptación: en 30 semillas con el mejor guion de cada ruta, ninguna ruta supera a otra en más de 20 puntos de victoria; cada ruta es la mejor en al menos una variante de misión (C10).

**C10. Variantes de misión visibles al arrancar** (`mapa_reglas`, aviso en `ui_feel`)
- Qué cambia: 4 variantes sorteadas con la semilla fija: "el costado fuerte mira al sur", "munición escasa pero llegan voluntarios", "viento fuerte: bajante rápida", "el buque dispara más seguido pero tiene tripulación escasa en cubierta". Se muestran en una línea en el segundo 0 con su consecuencia.
- Inspira: Warcraft/StarCraft (objetivos que cambian), Mindustry (oleadas con spawn), análisis de diversión (problemas 5 y 12).
- Aceptación: ≥ 3 variantes implementadas; el aviso aparece antes de 0:30; para cada variante, la mejor ruta difiere en al menos 2 de 4; el guion único `central_flank_pair` deja de ser el mejor en todas (win rate < 80 % en al menos una).

**C11. Moral y quiebre gradual** (`mapa_reglas`)
- Qué cambia: un grupo con poca fuerza pasa a "quebrado" (lento, no ataca, se puede reagrupar) antes de dispersarse; reunir y liderazgo (Güemes, Liniers) suben moral; derrota por dispersión solo cuando ≥ 2 grupos quedan quebrados o dispersos.
- Inspira: Close Combat (suprimir en vez de matar), Wesnoth (liderazgo adyacente), 0 A.D. (cohesión).
- Aceptación: la política ciega pierde más tarde (bajas ≤ 90 % en vez de 98–100 %); el novato del Monte Carlo gana entre 10 y 25 %; un grupo quebrado se recupera con "reunir" en ≥ 70 % de los casos controlados.

**C12. Derrota blanda y medallas** (`mapa_reglas` + `ui_feel`)
- Qué cambia: un "último esfuerzo" (voluntarios de reserva, una vez) cuando la fuerza total cae bajo un umbral; permite cerrar con captura alta como victoria bronce. Medallas: bronce (ganaste), plata (+ vado marcado + bajas < 55 %), oro (sin baqueano, bajas < 40 %, antes de 11:00).
- Inspira: Door Kickers (estrellas por objetivos), Civ VI (puntaje), Battle Brothers.
- Aceptación: caso `ui_real` semilla 5 (captura 86,7 % y derrota) pasa a victoria bronce o a derrota con mensaje explicando que el último esfuerzo estaba disponible; las tres medallas son alcanzables por scripts (bronce ≥ 70 %, plata 25–40 %, oro 10–20 % del guion fuerte).

**C13. Unidades legibles** (`visual`)
- Qué cambia: marcador de grupo con banderín grande, icono de rol (jinete, voluntarios, artillería, explorador), barra de fuerza; siluetas distintas por tipo; estandartes grandes con colores del paquete (azul, encarnado, lino); selección con halo claro.
- Inspira: Total War (banderas de unidad con cantidad e icono), Frozen Synapse (formas y colores legibles), Door Kickers.
- Aceptación: a 1280x720 y zoom por defecto, cada grupo ocupa ≥ 48 px de alto con su marcador; los 5 tipos se distinguen en una captura en escala de grises (revisión del QA); ninguna "manchita" de < 24 px.

**C14. Buque grande y legible** (`visual`)
- Qué cambia: buque con casco, mástiles y velas reconocibles, escala mayor, línea de cañones, estela y humo de descarga, indicador de cubierta; cámara por defecto lo incluye.
- Inspira: Total War (barco como amenaza legible), They Are Billions (lo que te amenaza se ve).
- Aceptación: a escala de juego el buque ocupa ≥ 15 % del ancho de la vista en el encuadre de arranque (hoy diminuto); se identifican proa y costado de cañones; no tapa los grupos de abordaje.

**C15. Río creíble y lindo** (`visual`)
- Qué cambia: shader de agua turbia pardo-verdosa cálida con tres bandas de profundidad (somera/media/profunda), olas, espuma en la orilla y alrededor del casco, reflejo del cielo cálido, brillo; barro sin remolinos (tono uniforme con huellas); transición de bajante a orilla visible; sin gris plano.
- Inspira: no es de un juego concreto; referencia de legibilidad de terreno de Wesnoth y Civ VI (terreno con identidad).
- Aceptación: en la captura de arranque, el agua tiene ≥ 3 tonos distinguibles y una desviación estándar de luminancia ≥ el umbral que fije el QA sobre una captura de referencia aprobada por el usuario; la paleta usa los colores de `palette` (terreno/agua) y no domina el gris frío; espuma visible en la orilla; costo ≤ 3 ms/cuadro (`benchmark.py`).

**C16. Fuerte y barranca menos genéricos** (`visual`)
- Qué cambia: fuerte reducido y desaturado (hoy enorme y saturado), con textura de adobe/tosca; barranca con estratos y vegetación baja, sin aspecto de cubos; ranchos y objetos de ambientación para dar escala.
- Inspira: legibilidad de escenario de Total War y Wesnoth (puntos de referencia).
- Aceptación: huella del fuerte ≤ 60 % de la actual; no se ven aristas de cubos en el perfil de la barranca a escala de juego (revisión de QA); el fuerte no es el objeto más saturado de la escena.

**C18. Presión de reloj** (`mapa_reglas` + `ui_feel`)
- Qué cambia: Liniers manda un mensaje cada 3 min; punto sin retorno marcado en la barra de tiempo; derrota anticipada por inacción si no hay avance a los 11 min.
- Inspira: They Are Billions (reloj que presiona sin ser injusto), Wesnoth (derrota por tiempo listada de antemano).
- Aceptación: la política pasiva termina en derrota ≤ 11 min con causa "inacción"; el punto sin retorno aparece en la barra y se explica en el objetivo; ninguna derrota por plazo sin que el jugador haya visto al menos 2 avisos.

**C19. Eventos de campo y ritmo** (`mapa_reglas` + `ui_feel`)
- Qué cambia: ≥ 6 eventos por partida (mensajero con elección, voluntarios que llegan, tirador del buque que hostiga la playa, viento que cambia, vecino que avisa de un pozo). ×2/×3 con regreso automático a ×1 al ocurrir un evento.
- Inspira: Warcraft/StarCraft (eventos que cambian la situación), Door Kickers (control de ritmo), Mindustry (oleadas).
- Aceptación: ≥ 6 eventos en una partida de 12 min; en los primeros 5 min nunca > 90 s sin evento, aviso o decisión (test sobre log de eventos); ×2 vuelve a ×1 al evento.

### P2

**C20. Previsualización del plan y capas de información** (`ui_feel` + `visual`)
- Qué cambia: al dar una orden de movimiento, línea de ruta con hora de llegada estimada y alcance del buque; capa conmutable de "casillas peligrosas" y zonas de fuego (de Old World/Civ).
- Inspira: Frozen Synapse (fantasma del plan), Door Kickers (waypoints), Old World (capa de casillas peligrosas), Commandos (conos).
- Aceptación: toda orden de `move` muestra tiempo estimado con error < 15 % respecto del tiempo real en 30 pruebas; la capa se activa con una tecla y se oculta; no suma > 0,5 ms/cuadro.

## 5. Objetivos de balance (para humano, medidos con modelo hasta tener personas)

Metas:

| Medida | Hoy (modelo) | Meta MVP |
|---|---|---|
| Victoria en 1.er intento (humano promedio) | 3–8 % | **25–40 %** |
| Victoria en el 3.er intento (con diario) | 15–30 % | **60–80 %** |
| Haber ganado al menos una vez en 5 intentos | ≈ 50–70 % | **≥ 90 %** |
| Novato total (todos los errores del Monte Carlo) | 0/24 | **10–25 %** |
| Guion fuerte ejecutado a tiempo | ≈ 78–92 % | **85–95 %** |
| Política ciega (rush) | pierde 100 % | pierde ≥ 85 %, y más tarde |
| Derrota media | 8–18 min | ≤ 9 min (mediana ≤ 7) |
| Victoria media | 12–14 min | 9–12 min |
| Derrota por dispersión con captura ≥ 85 % | existe (semilla 5) | 0 casos sin último esfuerzo |

Reglas de equilibrio:
- **Derrota que enseña, nunca arbitraria.** Toda derrota debe poder explicarse con una causa listada (C3) y en el parte siempre debe haber un consejo accionable. Las pérdidas por moneda al aire (elegir flanco a ciegas sin información) desaparecen: el diario, el sondeo y el baqueano dan información antes de que haga falta apostar.
- **Gradiente, no precipicio.** La puntuación y la medalla bajan de a poco; el último esfuerzo (C12) y el quiebre gradual (C11) evitan el "perdí con el 87 % de captura".
- **Dificultad escalonada por intento**, nunca oculta: baqueano y bajante generosa son opciones visibles y marcadas.
- **Cómo se mide:** (a) `tools/justina_playthrough.gd` con las políticas existentes más las nuevas (dispersa-al-aviso, noreply); (b) Monte Carlo del analista con 24+ partidas por nivel por variante de misión, publicando los intervalos; (c) prueba humana: el usuario juega 3 partidas seguidas y cuenta cuántas veces entendió la causa de la derrota. Si el modelo y la prueba humana discrepan, manda la prueba humana.

## 6. Prioridades visuales

Orden de importancia para un espectador (la fidelidad estricta no es criterio):

1. **Río creíble y bonito** (C15): paleta cálida y limosa (pardo-verdoso, no gris), tres profundidades, olas suaves, espuma en la orilla y en el casco, reflejo del cielo, profundidad que cambia con la bajante; el barro sin remolinos, con huellas.
2. **Unidades legibles** (C13): siluetas distintas, banderín grande de color (azul/encarnado/lino del paquete), icono de rol, barra de fuerza.
3. **Buque grande y legible** (C14): se entiende en un segundo qué es, de dónde dispara y a quién apunta.
4. **Fuerte y barranca menos genéricos** (C16): escala menor, desaturado, textura de adobe y tosca; barranca con estratos y plantas.
5. **Telegrafiado** (C7) y **capas informativas** (C20): la información de juego es parte del arte.
6. Coherencia de paleta: ningún elemento (fuerte, bandera, UI) rompe la escena por saturación; el paquete (lámina 04) es guía, no obligación.

Criterios de revisión visual: captura real con ventana (no `--headless`), a 1280x720 y 1920x1080, mirada por el QA; el usuario aprueba la captura de referencia del río. Rendimiento: `benchmark.py` < 3 ms/cuadro medio.

## 7. Onboarding de 30 segundos

Objetivo del jugador en una frase: **"Tomar el buque Justina varado en el Río de la Plata antes de que suba la marea."**

Secuencia propuesta:
- 0–5 s: pausa automática; una tarjeta de tres líneas: qué es el objetivo, "perder no es grave: volvés a jugar con lo que aprendiste", y botón "Empezar". El aviso de variante de misión (C10) aparece abajo en una línea.
- 5–15 s: flecha sobre el explorador y texto "1. Mandá el explorador a sondear el agua (Z)". El resto de la UI está atenuada.
- 15–30 s: ya con el explorador en camino, aparece "2. Mientras esperás el vado, juntá la tropa (reunir) y abastecé". Solo una acción sugerida por vez; las demás siguen disponibles.
- Cuando el vado está a ≤ 60 s: "3. Señalá a Liniers y cargá". La señal se explica una sola vez.
- Qué pasa si perdés: el texto de la tarjeta inicial más el parte con causa y consejo (C3). Primer intento perdido: se enseña el diario con un globo ("anotamos lo que descubriste").
- Retirada general, jerga y datos técnicos fuera del panel; el panel completo se abre con una tecla ("Detalles").
- Tutorial saltable. Se muestra una vez por perfil (más un botón "Ayuda" siempre).

Aceptación: en la prueba humana, un jugador sin contexto ejecuta la primera orden útil (sondear) antes de los 30 s en ≥ 80 % de las partidas y dice, sin leer el manual, cuál es el objetivo.

## 8. Qué NO hacer

- No pasar el Justina a turnos ni tocar el Norte en esta ronda.
- No cambiar el motor ni agregar sistemas nuevos grandes (formaciones, economía, producción): es un cruce corto, no un RTS completo.
- No copiar código de proyectos GPL; no descargar ni ejecutar juegos de fuentes dudosas; no usar descargas "abandonware". Solo ideas.
- No sacrificar diversión por historia, pero tampoco introducir anacronismos groseros (bandera argentina, Infernales) ni afirmar como documentado lo inventado.
- No agregar eventos aleatorios que decidan la partida sin que el jugador pueda reaccionar. El azar se anuncia o se compensa.
- No esconder la ayuda: baqueano y bajante generosa son opciones visibles y marcadas, nunca trampas silenciosas.
- No subir la dificultad "por defecto" para ser fiel: preferimos que se gane en 3 intentos.
- No esconder la tabla de balance: los objetivos de la sección 5 se reportan con intervalos y límites.
- No más texto: cada cambio de interfaz debe quitar al menos tanto texto como agrega.
- No sumar música ni sonido pesado: avisos sonoros cortos y distintos (vado, andanada, contraataque) alcanzan.
- No imprimir ni guardar claves (JEV/TypeSafe) en el repo.
- No hacer push ni release.

## 9. Objeciones de una segunda mirada y respuestas

Revisión adversaria (el mismo diseñador con otra mirada; no es una persona):

1. **"Mundo fijo hasta ganar aplana el juego: una vez aprendido, siempre es lo mismo."** Respuesta: es lo buscado para el MVP (reintento con maestría), y después de ganar el sorteo vuelve (rejugar). Además C10 (variantes) y las medallas mantienen valor de rejuego. Riesgo aceptado.
2. **"El diario regala demasiada información y mata el reconocimiento."** Respuesta: las marcas son "anotadas", no confirmadas; el sondeo sigue siendo necesario para que las reglas las traten como conocidas. Aun así, hay que medir: si con diario la tasa del 2.º intento supera 85 %, se atenúa (solo muestra la zona, no el tipo).
3. **"20 cambios son demasiados para una ronda."** Respuesta: de acuerdo. Se prioriza P0 (C1–C8, C17) en la ronda 9, P1 en la 10, P2 si hay tiempo. P0 son sobre todo flujo y datos: bajo riesgo de render.
4. **"C4 (guardado desde el cruce) puede ser costoso y frágil."** Respuesta: es opcional; sin él, C1 + C5 + reinicio en 3 s ya cumplen el espíritu. Se implementa solo si `rules` se puede duplicar con un hash de estado verificable.
5. **"Comprimir tiempos puede dejar sin tiempo a la ruta sur."** Respuesta: C5 exige que el guion fuerte conserve ≥ 55 % en toda variante; si la sur no llega, se acelera la marcha o se aumenta el plazo en vez de volver a la bajante lenta.
6. **"Telegrafiar el fuego lo vuelve trivial."** Respuesta: el aviso es de 3 s y hay una andanada fuerte cada 45 s que requiere dispersar y por tanto abandonar la formación; el costo de reaccionar es de tiempo y cohesión.
7. **"Mover Retirada general al menú rompe la sensación de poder."** Respuesta: sigue accesible con 2 clics; el objetivo es evitar errores. El análisis detectó que estaba pegada a las acciones normales.
8. **"Los números de balance son del modelo, no de personas."** Respuesta: correcto, y está dicho en la sección 0 y 5. Antes de cerrar el MVP, el usuario debe jugar 3 partidas y su veredicto manda.
9. **"El plan no dice nada de audio."** Respuesta: se acota a avisos sonoros cortos (C7, C10, C19); `audio_runtime_test.gd` se mantiene con su única falla aceptada (driver Dummy).
10. **"Los ítems visuales (C13–C16) son subjetivos y pueden no cerrar nunca."** Respuesta: tienen umbrales en píxeles y una captura de referencia aprobada por el usuario; el QA final rechaza con puntos concretos y el circuito se repite.

Cambios incorporados tras la revisión: P0/P1/P2 explícitos; C4 pasa a opcional con criterio de descarte; el diario tiene un freno si el 2.º intento supera 85 %; C5 tiene piso de 55 % para el guion fuerte; los objetivos de la sección 5 se atan a una prueba humana final.

## 10. Plan final

### 10.1 Orden de trabajo

- **Ronda 9 (jugable y claro):** C1, C2, C3, C4 (si es viable), C5, C6, C7, C8, C17; en paralelo, en `visual`, C15 y C14 (lo que más duele hoy: el río y el buque).
- **Ronda 10 (profundidad):** C9, C10, C11, C12, C18, C19; en `visual`, C13 y C16.
- **Ronda 11 (pulido):** C20, ajuste de balance con Monte Carlo, capturas finales y revisión de textos.
- Cada ronda cierra con QA final.

### 10.2 Reparto por pista

| Pista | Cambios |
|---|---|
| `mapa_reglas` | C1, C5, C8, C9, C10, C11, C12 (reglas), C18 (reglas), C19 (eventos), C7 (reglas), C4 (snapshot) |
| `visual` | C7 (humo y círculos), C13, C14, C15, C16, C20 (capas) |
| `ui_feel` | C2, C3, C4 (flujo), C6, C12 (medallas), C17, C18 (mensajes), C19 (ritmo), C20 (previsualización) |

### 10.3 Compuerta del QA final (qué hace falta para decir "MVP mostrable")

El QA aprueba solo si se cumplen todos:
1. Pruebas: `test_rules`, `test_integration`, `jev_contract_test`, `audio_runtime_test` (solo falla Dummy), `ui_qa` en 3 resoluciones, `justina_playthrough` y `benchmark.py` (< 3 ms/cuadro) en verde, con APPDATA aislado.
2. Tasas de la sección 5 en las políticas y el Monte Carlo, dentro del rango o con una explicación documentada.
3. Capturas reales con ventana, miradas una por una: río, unidades, buque, fuerte y barranca cumplen los criterios de C13–C16.
4. Ciclo completo jugable: perder, ver parte, reintentar con el mismo río, ver el diario, ganar, ver la medalla, desbloquear el Norte, todo en un perfil limpio.
5. Onboarding: la prueba de los 30 s sin leer manual.
6. Cero anacronismos groseros y etiquetas honestas.
7. Si algo falla: el QA lista puntos concretos con evidencia y el circuito (proponer, investigar, mejorar, probar) vuelve a empezar.

### 10.4 Cierre

El MVP no necesita más escenario ni más sistemas: necesita que el primer intento se entienda en 30 segundos, que perder dé información útil, que reintentar sea inmediato, que el río y el buque se vean bien y que haya presión con avisos. Con los nueve cambios P0 más el río y el buque se puede mostrar; con P1, se puede disfrutar; con P2, se pule.
