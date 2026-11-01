# Diseño del nivel 2: Humahuaca, el depósito de la retaguardia

Documento de diseño del escenario `humahuaca` (nivel II). Arquitecto jefe de diseño, 1 de noviembre de 2026. Versión del diseño: **1** (`contract: 1`). Base: `main` en `5ebbd28`. El contrato entre pistas, con firmas, archivos y pruebas, es `docs/CONTRATO_HUMAHUACA.md`; este texto explica **qué se juega y por qué**.

> **Cómo leer este documento.**
> - Los números son **valores de partida**: viven en `data/humahuaca_rules.json` (reglas), `data/humahuaca_map.json` (mapa) y los otros tres JSON del contrato. Hasta que la ronda 1 los mida, este texto manda; desde la ronda 2, si el JSON y este texto discrepan, vale el JSON y se corrige el texto.
> - Todo dato, lugar o regla lleva una de **cinco etiquetas** (sección 12): Documentado ●, Inferencia razonada ◇, Versión discutida ◆, Diseño ▲, Sin datos suficientes ○. Una entidad mixta se rotula por su parte más débil.
> - Fuentes de este diseño: el resumen del dossier del usuario (`info/2/Humahuaca, comienzos de marzo de 1817.md`, citado como **[md §X]**) y sus láminas 02, 03 y 06 y la foto de 1923; los informes de preparación `investigacion-nivel2/preparacion/01_dossier_humahuaca.md` (**[01]**), `02_fuentes_primarias.md` (**[02]**, con el parte de Arias leído completo), `03_arquitectura_actual.md` (**[03]**) y `04_herramientas.md` (**[04]**); y las lecciones de `docs/DISENO_JUSTINA.md`, `docs/CONTRATO_JUSTINA.md` y `docs/PLAN_DIVERSION_JUSTINA.md`.
> - **Faltan** el dossier de 52 páginas, el paquete editable de 39 archivos, las láminas 01, 04 y 05, la tabla de 23 elementos y las 16 fichas (el `.md` solo los enlaza a una biblioteca externa). **No se inventó nada para suplirlos**: todo lo que la lámina 04 (plano del prototipo) fijaría queda como diseño rotulado y se corrige por addendum cuando llegue (anexo A).

**Decisión de alcance (del lead; el usuario puede revertirla).** El nivel 2 pasa a ser *Humahuaca*. La campaña por rondas «Sostener el norte» se conserva **sin cambios de reglas** y pasa a ser el nivel III (continuación estratégica); sus pruebas siguen verdes. La Justina (nivel 1) **no se toca** y no está certificada: este trabajo no la mejora, solo se asegura de no romperla. El nivel nuevo se construye en el espíritu de la Justina (tiempo real con pausa y ×1/×2/×4, agrupaciones, órdenes contextuales, ciclo perder → reintentar con lo aprendido) pero como **escenario propio**, con relieve real (DEM) y la paleta del dossier.

**Directriz vigente del usuario:** la diversión y la claridad mandan; la fidelidad histórica es una guía. Pero: etiquetas honestas (nada inventado se presenta como documentado) y cero anacronismos groseros. Lo que el dossier marca como diseño va como diseño.

---

## 1. Pilares y promesa

**Promesa al jugador (una frase):** *Esta noche, con la lluvia, tenés unas 150 personas casi sin armas y un amanecer por delante: repartilas en tres partidas, tomá la batería, el cuartel y la pólvora de Humahuaca a la vez y sacá lo que el transporte aguante antes de que se arme la respuesta.*

| # | Pilar | Qué significa en el juego | Qué evita (lección del nivel 1) |
|---|---|---|---|
| 1 | **Tres frentes, un solo reloj** | El ataque dividido es simultáneo: batería, cuartel y pólvora corren a la vez, cada uno con su barra de toma, y la sorpresa dura 45 s desde la primera descarga. Las partidas se apoyan entre sí (Arias acude a Portal; las piezas de la batería voltean contra la torre). | Esperas sin decisiones: nunca hay un solo frente, siempre hay algo que atender. |
| 2 | **El terreno se lee y se usa** | La altura occidental da visión y tiro; las tapias y zanjas canalizan y ocultan; el barro cobra tiempo; el río es el borde de la salida. Todo sale de **una** grilla de relieve real más capas de diseño rotuladas. | Mapa «una parte definida y todo lo demás genérico y feo»; figuras que no se leen sobre el suelo. |
| 3 | **La noche protege, el alba descubre** | Sigilo contra velocidad: andar en silencio es lento, correr hace ruido; la lluvia tapa el ruido y moja las armas de chispa (las de ellos también); al alba la luz y la visibilidad suben y la guardia reacciona mejor. Información incompleta: se reconoce antes de atacar, y los informes pueden mentir. | Una receta fija ganadora: acá cada objetivo tiene al menos dos enfoques y el mundo cambia por variantes. |
| 4 | **No alcanza el transporte** | Tomar el depósito es la mitad. Hay más de lo que se puede llevar: se elige qué cargar, qué destruir y qué ocultar, contra un refuerzo que se acerca. «Los cañones no me atrevo a llevarlos» es una decisión, no un texto. | Una victoria con inventario ilimitado; un final sin tensión. |
| 5 | **Perder enseña y reintentar es barato** | Mundo fijo hasta ganar, diario de lo aprendido, dos puntos de control, parte de derrota con causa, momento y lugar en una línea. | 94 hallazgos sin priorizar, bucles sin salida, arranque abrumador. |

**Principios transversales (de las lecciones del nivel 1, obligatorios):** una cosa clara por vez (objetivo en una línea y un solo «siguiente paso»); nada de jerga al arrancar (sin «ETA», «sondeo», «tag»); se lee de noche (fichas y marcadores de interfaz, no solo color de ropa); ninguna decisión estratégica depende de esperar sin hacer nada; el azar se anuncia o se compensa; nadie jugó a mano en el nivel 1, así que **el nivel 2 no se declara presentable sin una sesión humana** (sección 10).

---

## 2. Arco de la partida

Duración objetivo: **10 a 14 minutos de reloj a ×1** (victoria típica 11–13; derrota típica ≤ 8 para que reintentar sea barato; plazo duro a los 14:00). La **primera decisión significativa llega antes de los 60 s** y hay **una decisión posible cada ≤ 45 s** (≤ 20 s durante el ataque).

| Fase (`phase`) | Reloj típico | Qué hace el jugador | Qué pasa |
|---|---|---|---|
| **Briefing** (`briefing`) | 0:00, en pausa; ≤ 30 s de lectura | Dos tarjetas: (1) objetivo en tres líneas; (2) **la carta de Güemes a Arias del 26 de febrero sobre Chacabuco, como dramatización** (nada de orden táctica) y el contexto del plan. Toca «Empezar». | Se muestra en una línea la **variante del mundo** de esta partida (por ejemplo «Hoy: la guardia está atenta»). La nota de fecha: «1 de marzo según el itinerario de Arias; el 2, según La Serna y una inscripción del premio» (◆). |
| **Aproximación nocturna** (`aproximacion`) | 0:00 a ≈ 4:30 (el alba) | Reparte las cinco agrupaciones desde la zona de partida del sudoeste; manda reconocedores; elige ritmo (silencio, marcha, correr) y ruta; **decide dónde dejar los caballos** de Rodríguez; lleva cada partida a su puesto de ataque. | Lluvia copiosa que afloja hacia el alba; visibilidad de 35 a 45 m; centinelas; el informante; una patrulla que cruza el camino. Si nadie atacó a los 6:30, **amaneció**: derrota. |
| **Ataque dividido** (`ataque`) | desde la primera descarga (≈ 4:30–5:15) hasta tomar los tres objetivos (≈ 6:30–8:00) | Da la señal (o la deja al alba) y lanza los tres frentes a la vez; reparte el apoyo; decide cuándo cargar y cuándo esperar. | **Ventana de sorpresa de 45 s**: desde la primera descarga, la alerta de cada frente sube de 0 a 1 en esos 45 s (25 s si la guardia está atenta) y el bono de sorpresa de quien ataca decae de ×1,8 a ×1,0 con ella; el que llega tarde encuentra la guardia alerta y atrincherada. |
| **Resistencia y apoyo** (subestado `resistencia`, dentro de `ataque`) | mientras la torre tenga munición (≈ 90 s desde su primera descarga) o el frente más duro siga en pie | La torre del cuartel mantiene un fuego «indecible» sobre las calles: se la rodea por patios, se la silencia con las piezas de la batería, se la espera o se la carga. Arias deja la pólvora y **acude en apoyo de Portal**. | Cada decisión tiene costo: el que apoya deja custodia atrás (la posición tomada sin custodia se pierde); el que espera gasta el reloj del refuerzo. |
| **Extracción** (`extraccion`) | desde que el depósito está tomado (típico 7:00) hasta salir por el vado del este (≈ 10:00–11:30) | Trae el arreo; elige **qué cargar, destruir u ocultar** con una capacidad limitada de mulas; decide qué hacer con los prisioneros; sale por el vado del este. | El refuerzo realista se acerca por el camino del sur con aviso visible; el río moja la pólvora; la columna cargada es lenta y vulnerable. |
| **Epílogo** (`epilogo`) | ≈ 60–90 s de lectura | Lee el parte de su partida y el epílogo fechado; ve la medalla; elige «Seguir: Sostener el norte», «Jugar de nuevo» o «Menú». | Línea de fechas documentadas (sección 7) y el contraste «lo que pasó / lo que jugaste». |

**Guion de eventos (cadencia garantizada).** Los eventos con elección **pausan solos** (pausa corta, nunca bloquean el reloj más de 25 s) y el juego **vuelve a ×1** cuando ocurre uno.

| t (×1) | Evento (`field_event`) | Decisión o efecto |
|---|---|---|
| 0:05 | `informante` | Un vendedor de ganado que anduvo entre los realistas (como el de enero, [02]) da **dos informes** de fiabilidad desigual (≈ 75 %): elegís a cuál creer. Define el primer reconocimiento. |
| 0:20 | «Siguiente paso» | Mandar a los reconocedores a mirar la altura o el pueblo (solo uno primero). **Primera decisión < 60 s.** |
| 0:45 | `lluvia` (info) | La lluvia arrecia: visibilidad 35 m; los pasos no se oyen. |
| 1:30 | `centinela` | Una patrulla cruza el camino: esperar, rodear (+25 s) o silenciarla (riesgo de ruido). |
| 2:15 | `tapia_hallada` / `zanja_hallada` | El reconocedor topó con un obstáculo: abrir portillo (ruido), trepar (lento) o rodear. |
| 3:00 | `caballos` | Si Rodríguez llegó al alto y no aseguró los caballos: ¿los deja con custodia o los lleva al asalto? |
| 3:30 | `aviso_alba` | Falta un minuto para las primeras luces: ¿ya están en sus puestos? (pausa corta) |
| 4:30 | `alba` | Llega la luz; se puede dar la señal; la lluvia afloja; en 60 s la visibilidad sube a 140 m. |
| +0:00 | `primera_descarga` | Ventana de sorpresa de 45 s en cada frente (cuenta visible). |
| +0:20 | `polvora_resiste` | «La guardia de la pólvora resiste: dos de los nuestros caen.» (información, sin pausa) |
| +0:30 | `torre_fuego` | La torre abre fuego: cargar, rodear por patios, pedir las piezas o esperar a que se le acabe la munición. |
| +0:45 | `mensajero` | Un jinete sale a galope al sur: perseguirlo con los caballos asegurados (si los hay) o aceptar un refuerzo 90 s antes. |
| +1:15 | `pide_apoyo` | Portal pide ayuda: Arias acude (deja custodia) o sigue con la pólvora. |
| ≈ 7:00 | `deposito_tomado` | Pasa a extracción; elección de prisioneros (llevarlos, atarlos o soltarlos). |
| 7:00–10:00 | `botin` | Por clase de carga: cargar, destruir u ocultar (sección 7). |
| llegada del refuerzo − 60 s | `refuerzo_visto` | «Polvareda al sur»: salir ya con lo que hay o cargar un poco más. |
| llegada del refuerzo | `refuerzo` | Combate de retaguardia; la columna que no salió pierde la carga. |

---

## 3. Mundo y escala

**Escala y área.** 1 unidad de Godot = 1 m. Ventana jugable de **900 × 650 m** (58,5 ha), declarada **decisión de diseño** por el dossier [md §C.3]. El ancla es la **iglesia actual**, ≈ 23,2041° S, 65,3492° O (lámina 03; ±15 m), que queda en el **centro** de la ventana.

**Ejes y origen (decisión, justificada).** `+x` = este, `+z` = **sur**, norte = `−z`, **origen en la esquina noroeste** de la ventana: `x ∈ [0, 900]`, `z ∈ [0, 650]`. Es la convención de la Justina, de la cámara por defecto de Godot (mira hacia `−z` = norte), del minimapa (`v = 0` es el norte) y de las rejillas (índice `[iz·nx + ix]`). Las láminas usan «metros al este y al norte del ancla»; la conversión es **exacta y única** (`HumahuacaTerrain.lamina_to_game / game_to_lamina`):

```
x = E + 450        z = 325 − N          ancla (iglesia)  → (450, 325)
E = x − 450        N = 325 − z
```

**Altura.** Cero local `datum_asl_m = 2940,0` (la curva de 2940 m de la lámina 03): `height_at` devuelve metros **sobre ese cero** (la iglesia queda en ≈ +17; el cauce, ≈ +12; la zona de partida, ≈ +27). Rótulo del relieve: *dato actual, no restitución del suelo de 1817*.

**Puntos de referencia** (juego `x,z`; lámina `E,N`). Las posiciones de los tres objetivos y de las demás piezas son **diseño** rotulado (no hay planta de 1817 [md §C.3, §G]); el sitio del templo es inferencia razonada.

| Id | Juego (x, z) | Lámina (E, N) | Nota |
|---|---|---|---|
| `templo` | (450, 325) | (0, 0) | Ancla ±15 m (◇ sitio; forma de 1817 ○) |
| `bateria` (Santa Bárbara) | (318, 350) | (−132, −25) | A ≈ 132 m del templo: entre los círculos «Santa Bárbara» (−111,−35) y «Monumento» (−143,+3) de la lámina; el monumento **no** se modela (▲) |
| `cuartel` (casa del cura) | (418, 335) | (−32, −10) | Pegado al templo, al oeste (▲ lado, ● objetivo) |
| `torre` | `torre_casa_cura` (426, 326) o `torre_templo` (466, 322) | (−24, −1) o (+16, +3) | Variante por mundo; 10 m de alto (○ identificación y lugar) |
| `posta` | (590, 300) | (+140, +25) | Patio de 30 × 24 m, polvorín al NE, corral al este (▲ lugar; ◇ pólvora en la posta) |
| `plaza` | (450, 392) | (0, −67) | Parámetro de prototipo (▲) |
| `quebradita_norte` / `quebradita_sur` | (282, 298) / (288, 402) | (−168, +27) / (−162, −77) | Dos lugares posibles del refugio de caballos; **una** existe por mundo (▲) |
| `zona_partida` | arco (60–260, 470–630) | SO | Cinco puntos de partida (sección 5); «acceso SO» ▲ |
| `vado_este` / `salida_este` | (862, 340) / (895, 332) | (+412, −15) / (+445, −7) | Salida de la carga; hacia San Andrés (ENE, sin traza ○) |
| `entrada_sur` | (540, 650) | (+90, −325) | Por donde llega el refuerzo desde Jujuy (▲ geometría; el refuerzo inmediato es ▲, ver sección 6) |
| `rio_grande` | polilínea de 14 puntos; entra en (572, 0), sale en (900, 406) | entra (+122,+325), sale (+450,−81) | Traza moderna (OSM, ODbL); lecho de 25–40 m (▲); solo el 8,4 % de la ventana queda al este del cauce |

**Terreno continuo hasta el horizonte** (crítica del usuario al nivel 1: «una parte definida y después todo genérico y feo»). Tres capas con **una sola** implementación de la altura (`HumahuacaTerrain`):

1. **Ventana** (900 × 650 m): grilla de juego de **4 m** (226 × 164 nodos) obtenida del DEM de 10 m más las capas de diseño; es la que usan reglas (rutas, visión, velocidad), vista (malla y picking) y UI (minimapa).
2. **Contexto** (3 600 × 2 700 m, **el mismo dominio de la lámina 03**, centrado en la iglesia: `x ∈ [−1350, 2250]`, `z ∈ [−1025, 1675]`): grilla de 30 m (121 × 91). Es lo que se ve desde la altura: el valle, el río que sigue, las laderas que suben a ±120–185 m. Sin reglas.
3. **Horizonte**: anillo procedural hasta ±8 km que comparte los vértices del borde del contexto (sin grietas), con estratos claros tipo «cerros erosionados» (foto 1923, plano 6) y niebla de profundidad 1 500–6 000 m. La cámara de juego queda recortada a la ventana más 120 m.

**Reloj del escenario y visibilidad.** El tiempo se muestra por **fase**, no por hora ficticia: «Noche · Aproximación» → «Alba · Ataque» → «Mañana · Extracción». El dossier advierte que las horas del parte no se trasladan al reloj actual [md §D]. `environment()` entrega `{phase, time_of_day, rain, visibility_m, mud}`:

| Tramo (×1) | `phase` | Lluvia | Visibilidad a nivel del suelo | Efecto de juego |
|---|---|---|---|---|
| 0:00–3:30 | noche | 0,9 | 35 m | Los pasos no se oyen (ruido ×0,8); las armas de chispa fallan (fiabilidad 0,55) |
| 3:30–4:30 | noche tardía | 0,8 | 45 m | idem |
| 4:30–5:30 | alba | 0,5 → 0,2 | 60 → 140 m | La guardia ve más; las armas de chispa mejoran (0,9) |
| 5:30+ | día | 0,1 | 300 → 600 m | Todo se ve; el barro queda (seca −0,01/s) |

(Lluvia durante la aproximación: ● solo la tarde del 27-II; la noche y el alba son ▲ «reconstrucción razonada» según el propio dossier. Un cálculo propio sin verificar con efeméride da luna casi llena esa semana: no se usa; la noche cubierta es diseño.)

---

## 4. Relieve con consecuencias de juego

**Principio:** el relieve no es decorado. Cada rasgo tiene una regla, una lectura visual y una etiqueta; todo sale de la **misma** grilla.

| Rasgo (dato de `relieve_mapa`) | Consecuencia en las reglas | Cómo se lee | Etiqueta |
|---|---|---|---|
| **Altura occidental** (cerro de Santa Bárbara): DEM base más un domo de diseño de **+12 m** (prominencia) con plataforma de 28 × 18 m en `bateria`; la superficie final queda ≈ 16–17 m sobre la plaza | **Visión:** desde la plataforma la línea de visión pasa sobre tapias de hasta 2,4 m y el radio de visión sube ×1,5; quien la tiene ve el núcleo entero. **Tiro:** desnivel ≥ 6 m → daño ×1,25 a favor del que dispara hacia abajo; ≥ 3 m → ×1,1. **Subida:** pendiente > 8° → velocidad ×(1 − 0,03·(grados − 8)), piso 0,6: atacar de frente por la ladera este cuesta tiempo y fuego. **Piezas:** tomada la batería se pueden voltear contra la torre (sección 6). | Ladera clara con arbustos oscuros y una tapia baja en diagonal (foto 1923, plano 1) | Relieve base ◇; domo y plataforma ▲ (los 12 m son del prototipo; el SRTM no los ve) |
| **Tapias** (polilíneas de 1,8–2,4 m) | Bloquean paso y visión salvo portillos. Trepar: 6 s y ruido 0,4. Abrir portillo: 10 s y ruido 0,6, y queda abierto para todos. Una tapia **no reconocida** en la ruta obliga a rodear (+8 s) | Muro de tierra compactada con remate de paja | Existencia ● (el parte reconoce «tapial»); cantidad y posición ▲ |
| **Zanjas y acequias** (0,8–1,2 m de profundidad) | Velocidad ×0,5; el que está dentro se ve menos (visibilidad ×0,5 a 20 m). Una zanja no reconocida hace tropezar (3 s, ruido +0,3) | Franja oscura húmeda con borde de tierra | Existencia ● («zanjita»); posición ▲ |
| **Quebradita** (36 × 8 m, −2,5 m, abierta al oeste) | No se ve desde más de 40 m: **refugio de caballos** (hasta 60). Sin custodia, si pasa una patrulla a < 60 m la caballada se pierde | Hondonada con churqui | Existencia ● («en ese alto»); lugar ▲ ○ |
| **Río Grande** (traza moderna; lecho ancho y claro de 25–40 m; dos vados) | Borde NE y este de la ventana y **camino de la salida**. Cruzar: velocidad ×0,5; la **pólvora se moja** y pierde su valor salvo carga seca; «echar al río» destruye al instante lo que se tira. Caudal visible según la lluvia del mundo | Lecho claro entre monte ribereño (foto 1923, planos 4–5), agua turbia | Traza: dato moderno; cauce de 1817 y vados ○ |
| **Barro** (humedad por superficie × lluvia) | Velocidad: camino 0,9; suelo seco 0,95; sedimento húmedo 0,75; **irrigado 0,6**; charcos 0,5; seca despacio tras el alba | Suelo oscuro y brillante donde llovió; huellas | ▲ sobre lluvia ● (tarde del 27-II) |
| **Núcleo** (manzanas de 54 × 54 m, calles de 8 m; bocacalles cerradas con barricadas) | La calle abierta es rápida y queda a la vista de la torre; los patios por detrás de las tapias son lentos y ocultos. Las barricadas obligan a entrar por puntos | Casas bajas con azoteas y patios (foto 1923, plano 2) | ◇ sitio; planta ▲ |
| **Camino cubierto** (60 m entre cuartel y batería) | Ruta de repliegue de los defensores: tomar la batería **primero** lo cierra, y el cuartel cae con más prisioneros; cortarlo evita refuerzos hacia la altura | Pasaje entre dos tapias altas | ◇ (Diario realista: «camino cubierto» entre la iglesia y el reducto) |

**Fuente del relieve.**

| Plan | Fuente | Estado | Qué se rotula |
|---|---|---|---|
| **A (recomendado)** | **Copernicus DEM GLO-30**, tesela `Copernicus_DSM_COG_10_S24_00_W066_00_DEM.tif` (**39 438 103 B**, MD5 `8c0aef1d66f4d1e918a25ff7864ecab3`), leída con Pillow + `receta_dem.py` ([04] §3–§4): ventana de 91 × 66 a 10 m y contexto de 121 × 91 a 30 m, centrados en el ancla | **Pendiente del permiso del usuario** (no se descargó nada) | «Relieve actual, Copernicus GLO-30 (modificado: remuestreo y recorte); no restitución del suelo de 1817». Aviso de licencia (Art. 6 b y c) copiado literal de la licencia oficial a `docs/CREDITOS.md` |
| **B (arranque sin permiso)** | Relieve **reconstruido de la lámina 03**: los 475 nodos de 25 × 19 a 150 m (`preparacion/01b_relieve_lamina03_nodos_25x19.csv`, ±10 m, 99,5 % de acuerdo con la lámina), interpolación bicúbica a 30 m y 10 m | Disponible hoy; **R1 arranca con este plan** | «Relieve reconstruido de la lámina 03 (±10 m)» |
| C (pedido aparte) | SRTM 30 m por la API pública de OpenTopoData (solo viajan coordenadas; 61 + 111 pedidos) | Pendiente de permiso | «SRTM 30 m (NASA/USGS)» |
| D | Los datos de relieve del paquete del usuario, si llega | Pendiente | A definir |

Cambiar de plan **no cambia el esquema** (`humahuaca_height.json`, ver el contrato): `tools/build_humahuaca_terrain.py --source lamina03|copernicus|opentopodata` regenera el archivo y `meta.source` cambia. Prohibido Google Elevation.

**Resolución y extensión.** DEM de ventana a 10 m (interpolación, no detalle nuevo; con 30 m nativos son ≈ 32 × 21 muestras reales dentro de la ventana, y con el plan B ≈ 35 nodos); malla de juego de 4 m; contexto a 30 m. Dentro de la ventana el relieve real varía apenas **≈ 38 m** (2 941–2 979 m, SRTM 30 m; la lámina da 2 946–2 971 ±10), con una única curva de 2 960 m casi norte–sur: de (270, 0) a (366, 325) a (380, 650). **Política vertical:** exageración 1,0 en la lógica; si en R2 el relieve se lee plano, se admite un factor ≤ 1,5 **solo del componente DEM** (`relief.exaggeration` en `humahuaca_map.json`), aplicado dentro de `height_at` (reglas, vista y picking lo ven igual) y rotulado ▲. Nunca solo en la vista.

**Verificación contra la lámina 03.** El test `tests/test_hx_terrain.gd` evalúa el **DEM sin capas de diseño** en los **41 puntos** de la tabla de [01] §d.7 (convertidos con `lamina_to_game`): al menos **37 de 41** a ≤ 12 m de la estimación, **ninguno** a > 20 m, y **todos** dentro de la banda de color ±8 m; además `report()` lista qué capas son diseño (domo de la batería de +12,0 ±0,3 m, quebraditas, zanjas, tapias, barro) y el error medio contra los nodos. Otras comprobaciones: la curva de 2 960 m pasa por (366, 325) ±15 m; el cauce en z = 325 está a x = 859 ±5 m; el núcleo queda más bajo que la plataforma y el cauce más bajo que el núcleo; cada acceso llega a cada objetivo por la rejilla de navegación; tiempo de horneado < 300 ms.

---

## 5. Agrupaciones del jugador, acciones e información

**Quién se controla** (decisión D7): **coordinación de cinco agrupaciones**; no hay protagonista inventado. Güemes **no** está entre ellas: conduce desde Salta y solo aparece en el briefing (la carta del 26-II) y en el epílogo (recibe el parte) [md §H, §L]. Arias es la tercera división, no un héroe individual.

### 5.1 Las cinco agrupaciones

| Tecla | Id | Nombre visible | Quién (histórico) | Hombres · fuerza | Armas | Rol y habilidad propia | Partida (x, z) |
|---|---|---|---|---|---|---|---|
| 1 | `rodriguez` | Partida de Rodríguez · la altura | capitán Hilario Rodríguez, 1.er trozo; «dejando sus cabalgaduras en una quebradita que está en ese alto» ● | 48 · 100 | 25 % fusiles; el resto palos y sables | **Batería.** Parte **montada**; puede **asegurar los caballos** | (70, 470) |
| 2 | `portal` | Partida de Portal y Ontiveros · el cuartel | teniente Manuel Portal, con el alférez Ontiveros; Portal fue prisionero en Humahuaca y se fugó ● | 52 · 100 | 30 % fusiles | **Cuartel.** **Conoce las calles** ◇: arranca con la calle de entrada del cuartel y la barricada sur ya reconocidas | (110, 580) |
| 3 | `arias` | División de Arias · la reserva | Manuel Eduardo Arias, «tercera división protectora para todos los lances» ● | 50 · 100 | 35 % fusiles | **Pólvora (posta).** Es la **reserva**: puede acudir a cualquier frente; al tomar una posición deja **custodia** | (260, 625) |
| 4 | `reconocedores` | Reconocedores | el reconocimiento «en persona» de «tapial, zanjita» ● (léxico de época: «bomberos») | 2 | pistolas | **Reconocer**, hacer ruido, vigilar el sur | (120, 600) |
| 5 | `arreo` | Arreo · mulas de carga | arrieros y mulas; el parte captura 16 mulas ● | 6 arrieros · 6 mulas (600 kg) | — | **Traer, cargar, destruir, ocultar, salir** | (60, 625) |

Total de combatientes: **150** (cifra de Arias ●; el Diario del Estado Mayor realista dice 300 ◆). **El reparto 48/52/50, los porcentajes de armas y las mulas propias son ▲** (el parte solo dice «la mayor parte sin más armas que palos» y que reunió «tres trozos» a una legua del pueblo). Las cifras se muestran como «≈ 50 hombres» y barra de fuerza relativa.

Estadísticas por agrupación (JSON `groups`): `strength` 0–100, `fatigue` 0–100 (resta 0,4 % de poder por punto, mínimo ×0,4), `armed` 0–1, `morale` 0–100, `noise` 0–1, `custody` (hombres dejados atrás), `mounted`, `carry_kg` (arreo). Una agrupación con fuerza ≤ 15 se **quiebra** (lenta, no ataca, se reagrupa con «A su puesto» lejos del fuego); con ≤ 5 se dispersa.

### 5.2 Ritmos, ruido y detección (sigilo contra velocidad)

| Ritmo | Velocidad (m/s en firme) | Ruido | Fatiga/s | Nota |
|---|---|---|---|---|
| Silencio (`sneak`) | 2,0 | 0,10 | 0,02 | De noche con lluvia el ruido vale ×0,8 |
| Marcha (`march`) | 3,2 | 0,35 | 0,04 | Ritmo por defecto |
| Correr (`run`) | 5,0 | 0,70 | 0,12 | A los 20 s seguidos baja a marcha |
| Trote (montado) | 5,5 | 0,50 | 0,05 | En barro ×0,85 |
| Galope (montado) | 8,5 | 0,90 | 0,10 | Solo en firme; en otro suelo vale trote |

Los multiplicadores del suelo mojado (camino 0,9 … irrigado 0,6), de la pendiente y de las zanjas (×0,5) están en la sección 4. **Detección:** un centinela con línea de visión ve a una partida si `distancia < visibilidad × (1 + 2 × ruido)`; **de noche con lluvia (35 m)**: silencio 42 m, marcha 60 m, correr 84 m, galope 98 m; **al alba (140 m)**: 168, 238, 336 y 392 m. Centinelas en altura (torre, batería) ×1,5. Ser visto sube la **alerta** del frente (0 → 1) y, a 1, el centinela da la alarma en 6 s. El HUD resume el ruido de cada partida en tres estados sin números: *En silencio*, *Se oye*, *Los oyen*.

Ejemplo de la tensión: cruzar 300 m de ladera en silencio lleva ≈ 150 s (190 s con barro) y llega antes del alba por poco; a la carrera lleva 60 s pero a 84 m de distancia ya te ven. El alba (≈ 4:30) es el reloj que obliga a elegir.

### 5.3 Acciones contextuales (20) con costo y beneficio

Las define `rules.list_actions(kind)` y `action_availability(actor, action, target)` devuelve `{ok, reason, cost_text, tag}` con el motivo concreto; la interfaz **solo pinta** (se muestran las usables más la recomendada; lo riesgoso va aparte con «CON RIESGO»). Cifras en `humahuaca_rules.json.actions`.

| # | Acción (id) | Quién | Costo | Efecto | Etiqueta |
|---|---|---|---|---|---|
| 1 | **Mover** (`move`) | grupo | tiempo, fatiga y ruido según ritmo | Marcha a un punto; muestra tiempo, riesgo y alcance de la visión enemiga antes de confirmar | ▲ |
| 2 | **A su puesto** (`position`) | grupo | — | Va al **puesto de ataque** de su frente (a 60–120 m, con cobertura) y queda «esperando la señal» | ▲ |
| 3 | **Atacar** (`attack`) | grupo | fatiga +20; bajas según postura | Asalta el frente elegido; postura **a fondo** (+40 % de poder, +60 % de bajas propias) o **con cautela** (−20 % de poder, −30 % de bajas); a ≤ 150 m del objetivo | ● el hecho / ▲ cifras |
| 4 | **Socorrer** (`support`) | grupo | viaje; deja `custody` si tomó algo | Suma su poder al frente socorrido; el frente apoyado muestra el ícono de apoyo. Es el «Arias acude a Portal» | ● |
| 5 | **Sostener** (`hold`) | grupo (auto al tomar) | 8–12 % de la fuerza queda de **custodia** | Una posición tomada sin custodia se pierde si hay enemigos a < 80 m | ▲ |
| 6 | **Asegurar caballos** (`secure_horses`) | `rodriguez` | 10 s y 4 hombres de guardia (−8 % de fuerza) | La caballada queda a salvo en la quebradita y está disponible después (perseguir al mensajero, huir, cargas livianas) | ● el hecho / ▲ el lugar |
| 7 | **Abrir portillo** (`breach`) | grupo | 10 s, ruido 0,6 | Abre paso en una tapia; queda abierto también para los realistas | ▲ |
| 8 | **Replegarse** (`retreat`) | grupo | marcha de vuelta | Va al punto de salida; los heridos se llevan | ▲ |
| 9 | **Reconocer** (`recon`) | reconocedores | hasta 3 puntos; riesgo estimado % de que los vean | Revela guardia (cuántos y cómo están), tapias, zanjas, centinelas y la torre en una franja de 40 m; antes de ordenar se muestra el riesgo | ● el hecho |
| 10 | **Hacer ruido** (`decoy`) | reconocedores | 8 s a ≥ 120 m del frente | La guardia de ese frente mira hacia allá (alerta −30 %); la alerta global sube 0,1; pueden descubrir al reconocedor | ▲ |
| 11 | **Vigilar el sur** (`watch`) | reconocedores | quedarse en un punto alto | Avisa el refuerzo 60 s antes y ve al mensajero | ▲ |
| 12 | **Traer el arreo** (`bring`) | arreo | viaje a ritmo de mula | Lleva las mulas al patio de la posta | ▲ |
| 13 | **Cargar** (`load`) | arreo | 12 kg/s por equipo de 6 hombres (hasta 3 equipos) | Sube una clase de carga a las mulas; pólvora sin protección se moja al cruzar el río | ● el hecho / ▲ pesos |
| 14 | **Destruir** (`destroy`) | arreo / grupo | pólvora: quemar 20 s (humo a 300 m, explosión a 25 m) o echar al río (solo a ≤ 40 m del cauce); cañones: clavar 10 s c/u | Quita el valor al enemigo: vale ×0,6 de su puntaje | ● («dar al fuego y echar al río») |
| 15 | **Ocultar** (`hide`) | arreo / grupo | enterrar 25 s por pieza, lejos del camino | Vale ×0,4; el epílogo dice si la recuperan | ◆ (Diario realista: «ocultos o enterrados») |
| 16 | **Salir por el este** (`leave`) | arreo / grupo | cruzar el vado ×0,5 | La carga que cruza se **entrega**; sale del mapa | ● el hecho / ▲ lugar |
| 17 | **Soltar la carga** (`drop`) | arreo | — | Abandona lo que carga para huir (emergencia) | ▲ |
| 18 | **Dar la señal** (`give_signal`) | global | abre la ventana de sorpresa de **todos** los frentes (alerta 0 → 1 en 45 s) | La «descarga que pareció cañonazo»: lanza a todas las partidas en espera; sin ella el ataque empieza solo al alba | ● la descarga / ▲ la señal general |
| 19 | **Retirada general** (`retreat_all`) | global | 2 clics (desde el menú de pausa) | Termina como derrota ordenada | ▲ |
| 20 | **Cancelar** (`cancel`) | todos | — | Anula la orden en curso (Ctrl+Z deshace la última) | — |

**Información incompleta y ruido.** (a) **Niebla de reconocimiento:** al principio los frentes muestran «?» en guardia y postura; reconocer los resuelve; sin reconocer, la barra del enemigo es una franja ancha (el rango que dan los informes). (b) **Informes:** el informante da dos afirmaciones (por ejemplo «la pólvora está en la posta» / «la torre es la del templo»), cada una con fiabilidad ≈ 75 %; el mundo guarda cuáles eran ciertas y el **diario** lo anota en el parte. (c) **Ruido** de las acciones propias (disparos, portillos, caballos) que el enemigo oye. (d) Lo no reconocido en la ruta (tapias, zanjas) cobra tiempo y ruido al toparse.

### 5.4 Caballos asegurados o asalto a pie

| Opción | Costo | Beneficio | Riesgo |
|---|---|---|---|
| **Asegurar** en la quebradita (con custodia) | 10 s; 4 hombres (−8 % de fuerza) | Caballada a salvo: después persigue al mensajero, escolta la columna y sirve para huir (×2,5 de velocidad para un tercio de la partida) | Pocos hombres para el asalto |
| **Dejarlos sin custodia** | nada ahora | Más fuerza en la batería | Si una patrulla pasa a < 60 m, se pierden (40 %) |
| **Llevarlos al asalto** (carga montada) | ruido 0,5 hasta el contacto | +10 % de poder los primeros 15 s; llegan antes | Los caballos reciben fuego (pierde 30 %) y sin caballada no hay persecución ni huida rápida |

El parte dice que Rodríguez **dejó** sus cabalgaduras y atacó a pie ●; que lo haga **con** custodia es la opción mejor pagada, no una obligación.

---

## 6. Defensores y su comportamiento

**Fuerza realista** (valores de partida; el parte y los realistas dan 100–135 hombres y 6–7 piezas ●◆): **≈ 130 hombres** (los 128 del cuadro de abajo más el mensajero y el jefe de la guarnición) y **7 piezas** (6 de a 4 y 1 de a 2; la séptima ◆).

| Frente | Defensa | Cobertura | Postura inicial | Particularidades |
|---|---|---|---|---|
| **Batería** (`bateria`) | 24 artilleros, 3 piezas de a 4 | Parapeto y foso ×1,6; la **gola** (entrada trasera) mira al oeste y está abierta | 2 centinelas («alertas a porfía») | Las piezas barren la ladera este y el núcleo (alcance 300 m, ×1,5 contra quien sube de frente). Girarlas hacia atrás lleva 15 s: **el flanco por la gola las toma de espalda (×0,5)** |
| **Cuartel** (`cuartel`) | 56 fusileros en la casa del cura **+ 10 tiradores en la torre** | Muros aspillerados ×1,5; torre ×2 | 1 centinela en la puerta | **La torre** abre fuego en cuanto se arma: 12 s después de la alarma si la guardia está descuidada, al instante si está atenta; 12 descargas de 7,5 s (≈ 90 s), radio de 90 m con línea de visión sobre tapias; ángulo muerto de 12 m al pie |
| **Posta** (`posta`) | 22: 12 guardianes del polvorín y 10 de servicio | Muros de 2,4 m ×1,3 | 1 centinela en la entrada principal | «Resistencia de ordenanza»: el primer minuto mata a 2 de los nuestros; un **oficial** que sobrevive 15 s tras la alarma corre al cuartel y le suma 8 hombres |
| **Patrullas** | 8 en 4 recorridos | — | — | Detectan por ruido y visibilidad |
| **Camino sur** | 8 y un **mensajero** | — | — | El mensajero sale a los 40 s de la alarma si nadie lo corta |

**Variantes del mundo** (una por dimensión, sorteadas con la semilla y fijas hasta ganar; encarnan las incertidumbres que el dossier declara sin resolver [md §M] y siempre se rotulan ▲):

| Dimensión | Valores | Qué cambia |
|---|---|---|
| `guardia` | `descuidada` / `atenta` | Descuidada («con algún poco más de descuido», ●): detección ×0,8, ventana de sorpresa de 45 s, torre armada 12 s después de la alarma. Atenta («el traidor avisó», ●; la guardia «lo había esperado noches antes»): detección ×1,25, patrullas +50 %, ventana de sorpresa de 25 s, torre armada desde el inicio y el bono de sorpresa sobre el cuartel parte de ×1,3 en vez de ×1,8 |
| `torre_en` | `templo` / `casa_cura` | Lugar de la torre ○ (el parte no la identifica): cambia el ángulo muerto y la ruta de apoyo |
| `refugio` | `norte` / `sur` | Cuál de las dos quebraditas existe |
| `lluvia` | `copiosa` / `garua` | Copiosa: visibilidad −15 %, fiabilidad de armas de chispa 0,55; garúa: +15 % y 0,70 |
| `refuerzo` | `temprano` / `normal` / `tardio` | Demora del refuerzo desde la primera descarga: 240 / 300 / 360 s |
| `layout` | `A` / `B` | Dos disposiciones de tapias, zanjas y barricadas |

48 combinaciones de reglas × 2 de disposición = **96 mundos**. Una línea del briefing dice las variantes ya conocidas («Hoy: guardia atenta, lluvia copiosa»); el resto se descubre reconociendo. Esto da a cada objetivo una mejor apertura **distinta** según el mundo (sección 10).

**Reacción de los defensores.** Estados del frente: `guardado` → `alertado` (alerta ≥ 0,5) → `en_alarma` (alerta = 1) → `asaltado` → `tomado`. En alarma: cobertura ×1,25 (se atrincheran); el cuartel abre la torre; el oficial de la posta corre al cuartel; el mensajero sale. Si el **camino cubierto** está abierto, los defensores del cuartel que pierden se **repliegan** hacia la batería (el Diario realista cuenta que fueron «acuchillados dentro de las mismas calles», ◇); si la batería ya cayó, se rinden: **tomar la batería primero cierra el repliegue y rinde más prisioneros**. Una posición tomada sin custodia se pierde.

**La torre que resiste** (consecuencia jugable de «se subieron a la torre ... fuego indecible de 5:00 a 6:30», ●). Mientras tenga munición castiga a toda partida con línea de visión a ≤ 90 m (daño ×2 sobre quien está en la calle abierta, ×0,5 si está detrás de tapia). Cuatro respuestas: **(a)** rodear por patios y tapias (lento, necesita portillos o reconocimiento), **(b)** cargarla «a sangre y fuego» (rápido, caro), **(c)** **voltear las piezas** de la batería tomada (≈ 15 s y 3 de las 7 piezas; reduce el fuego de la torre ×0,4 por descarga durante 20 s; es el apoyo de Rodríguez a Portal ▲), **(d)** esperar a que se acabe la munición (el reloj del refuerzo corre). El fin del fuego de la torre ○ (el parte no lo cuenta) es diseño.

**Refuerzo (diseño).** Los realistas se enteraron el **4 de marzo** y mandaron tres columnas el 5–6 (●): **no hubo refuerzo inmediato**. El refuerzo del juego (40 infantes y 6 jinetes por `entrada_sur`, `refuerzo` demora desde la primera descarga, −90 s si el mensajero escapa, +120 s si lo cortan, aviso −60 s con `watch`) es un **recurso de diseño para dar tensión a la extracción** y se rotula ▲ en pantalla; el epílogo cuenta lo que pasó de verdad. Inspiración rotulada ◆: Güemes dijo haber visto pasar el 24-II «una división de 300 hombres» sin confirmación realista.

**Decisiones del mando realista (interfaz Jev y alternativa local).** Tres puntos de decisión con menú de opciones legales, calculadas por las reglas; **la alternativa local es determinista** (tabla por estado y semilla) y es la que se juega y se prueba. Jev (TypeSafe) queda **fuera del MVP** (D4) y se puede enchufar sin rediseñar: `enemy_observation()`, `enemy_choices()`, `enemy_fallback()` y `record_external_decision()` tienen la forma del Norte (2 s de presupuesto, descarte de respuestas viejas, registro de la alternativa local). Nota: **la Justina no usa Jev** (solo el Norte lo usa); acá se reutiliza el patrón del Norte.

| Punto | Cuándo | Opciones (las ilegales se omiten) | Alternativa local |
|---|---|---|---|
| `reaccion_alarma` | primera alarma | `atrincherar`, `repliegue_camino_cubierto` (solo si está abierto), `contraataque_posta` (solo si la pólvora corre riesgo), `mensajero` (solo si no salió) | prioridad por estado: pólvora en riesgo → contraataque; mensajero sin salir → mensajero; si no, atrincherar |
| `torre_municion` | la torre abre fuego | `fuego_continuo` / `fuego_selectivo` (mitad de cadencia, doble duración) | continuo si hay partidas a < 60 m; selectivo si no |
| `refuerzo_ruta` | el refuerzo entra por el sur | `por_el_vado` (cierra la salida), `por_las_calles` (cae sobre la posta), `por_la_altura` (retoma la batería) | hacia donde está la columna cargada; si no hay, la posta |

---

## 7. Objetivos, victoria, derrota, puntuación y extracción

**Objetivos.** Tres frentes, cada uno con una barra de **toma** (0–100) y un estado (`guardado`, `alertado`, `en_alarma`, `asaltado`, `tomado`). Se toma cuando la toma llega a 100 y la guarnición queda ≤ 15 % o se rinde. Tomar cada uno **cambia el juego**:

| Frente | Al tomarlo | Botín que contiene |
|---|---|---|
| **Batería** | Mirador sobre el núcleo (radio de visión ×1,5), cierra el camino cubierto, habilita **voltear las piezas** | 3 piezas de a 4 (12 puntos) |
| **Cuartel** | Silencia la torre; rinde prisioneros | Fusiles (≈ 100), bandera del primer regimiento, plata (3 cargas, ◆), ornamentos; prisioneros |
| **Posta** | Polvorín, parque, corral | Pólvora y municiones (12 cargas), 3 piezas + 1 de a 2, víveres (30 cargas), **16 mulas** (+1 600 kg de capacidad), ganado |

**Botín (valores de partida; suma 100 «puntos de golpe»).**

| Clase | Cantidad | Peso | Puntos | Notas |
|---|---|---|---|---|
| Pólvora y municiones (`polvora`) | 12 cargas | 100 kg c/u | 28 | Se moja en el río salvo carga seca (+10 s por carga). Quemar: 20 s, humo visible a 300 m, explosión a 25 m (pierde 40 de fuerza quien esté dentro) |
| Cañones (`canones`) | 6 de a 4 (400 kg) + 1 de a 2 (200 kg) ◆ | 2 600 kg | 28 | Cargar una pieza: 4 mulas y 60 s; clavar: 10 s (negación); ocultar: 25 s |
| Fusiles (`fusiles`) | ≈ 100 | 4 kg c/u | 10 | 4 cargas |
| Víveres (`viveres`: harina y aguardiente) | 30 cargas | 100 kg c/u | 12 | La peor relación valor/peso |
| Ganado (`ganado`: 2 000 ovejas y 60 vacas) | — | camina | 8 | 6 arrieros; ralentiza la columna ×0,75; se puede dispersar |
| Plata (`plata`) | 3 cargas | 100 kg c/u | 6 | Versión de oídas de Portal (Belgrano, 10-IV) ◆ |
| Prisioneros (`prisioneros`: 86 soldados y 7 oficiales) | 93 | caminan | 5 | 1 guardia cada 8; ralentizan ×0,8 |
| Bandera (`bandera`) | 1 | 5 kg | 2 | Del primer regimiento; «Pumacagua degollado» en una punta; paño sin completar ▲ |
| Ornamentos y misal (`ornamentos`) | 1 juego | 15 kg | 1 | Destinados a la Virgen de Humahuaca ●: se pueden devolver al templo |

**Capacidad.** 6 mulas propias (600 kg) + 16 del corral (1 600 kg) = **2 200 kg**, contra ≈ 7 500 kg de carga pesada: no alcanza (≈ 29 %) y eso **es** la decisión («por no tener cómo conducirlos», ●). Lo que no se carga se **destruye** (valor ×0,6), se **oculta** (×0,4) o se **abandona** (0 y el enemigo lo recupera). Cada equipo de carga hace 12 kg/s.

**Puntaje (`golpe`, 0–100):** `golpe = carga entregada × 1,0 + destruido × 0,6 + oculto × 0,4`. La carga solo cuenta si **cruza el vado** del este; lo interceptado vale 0. El HUD muestra «Golpe» y tres chips (entregado / destruido / pendiente), nunca una planilla.

**Victoria.** Los tres frentes `tomado`, `golpe ≥ 45`, fuerza total de combate ≥ 20 % al cerrar, y la extracción cerrada por salida (no por captura de la columna). **Derrota:** `amanecio` (nadie atacó a los 6:30), `descubiertos` (la alarma saltó antes de la señal y los tres frentes fallaron), `frente_roto` (una partida se rompió bajo la torre o la batería), `sin_carga` (depósito tomado pero `golpe < 45`), `interceptados` (el refuerzo alcanzó a la columna), `dispersos` (fuerza total < 20 %), `plazo` (14:00), `retirada`. **Cada causa tiene texto ≤ 140 caracteres con momento y lugar y un consejo.**

**Medallas** (por lo que hiciste): **bronce** = victoria; **plata** = `golpe ≥ 65` y bajas ≤ 45 %; **oro** = `golpe ≥ 80`, bajas ≤ 35 %, sin ayudas y la columna no fue alcanzada. Sin victorias pírricas: bajas = 1 − fuerza final / inicial de las tres partidas.

**Fin del combate.** Se cierra cuando (a) la columna y las partidas salieron o se replegaron, (b) el refuerzo alcanzó a la columna, (c) 14:00, (d) dispersión o retirada. Lo que queda atrás se evalúa en el epílogo.

**Epílogo fechado** (cada línea con su etiqueta; el contraste «tu partida» sale de `campaign_report()`):

| Fecha | Texto | Etiqueta |
|---|---|---|
| 3 de marzo | Arias firma el parte en San Andrés y pide «un botiquín para mis infelices heridos». | ● |
| 4 de marzo | En Jujuy, La Serna sabe que la guarnición de Humahuaca «había caído en poder de los enemigos». (No hubo refuerzo inmediato.) | ● versión realista |
| 8 y 9 de marzo | Juan Pablo Mariscal entra en Salta con el parte a las 22 h del 8; Güemes lo remite a Belgrano el 9. | ● |
| 13 de marzo | Belgrano reenvía el parte formal desde Tucumán. | ● |
| 9 al 16 de marzo | Una columna realista entra en el pueblo vacío; según La Serna recupera **seis piezas** ocultas o enterradas cerca de San Andrés e inutiliza lo que no puede cargar «por falta de acémilas». | ◆ |
| Abril | Belgrano manda hacer medallas para los de Humahuaca; el premio se concede después del combate, no antes. | ● |
| 6 de julio | Un oficial realista cuenta «la sorpresa de Humahuaca» entre las causas de la retirada del ejército del rey: la retirada tuvo muchas causas. | ● versión realista |
| Marzo a mayo | La resistencia continúa: **III · Sostener el norte** (botón «Seguir»). | ● |

Güemes recibe el parte en Salta (**no** estuvo en el asalto, ●) y San Martín es contexto (Chacabuco, 12-II): ninguna línea dice que ordenó este golpe. El nivel **no** cierra como expulsión definitiva.

---

## 8. Aprendizaje entre intentos

Heredado de la Justina porque **funcionó** (mundo fijo, diario, punto de control, derrota que enseña, ayudas visibles) y reescrito en archivos propios: `scripts/humahuaca/rules/humahuaca_progress.gd` y `user://humahuaca_progress.json`. **No** se agrega nada a `campaign.json` (descarta lo que no conoce y se reinicia si `version != 1`).

- **Mundo fijo hasta ganar.** La semilla (`world_seed`) y por lo tanto las seis variantes de la sección 6 se mantienen entre intentos y entre sesiones. «Mundo nuevo» (con confirmación) las vuelve a sortear; al ganar, el mundo se re-sortea solo («Jugar de nuevo: otro mundo»).
- **Diario de Humahuaca** (máximo 40 entradas; accesible desde el parte y el menú de pausa). Cada entrada deja, en el intento siguiente, una marca tenue **«anotado»**. Las marcas **no cuentan como reconocimiento**: el planificador las evita y se dibujan, pero el sigilo, la sorpresa y el riesgo estimado siguen pidiendo reconocer.

| Qué pasó | Entrada del diario | Marca en el próximo intento |
|---|---|---|
| Te vio un centinela o te oyeron | «Te vieron cerca de la barricada sur (a 52 m)» | Círculo tenue en el lugar |
| Tropezaste con una zanja o una tapia | «Zanja a 40 m de la posta, lado sur» | Línea tenue |
| Reconociste la torre o la guardia | «La torre estaba en la casa del cura» | Ícono tenue; la variante se dice en el briefing |
| Perdiste los caballos | «Caballos sin custodia: se perdieron en la quebradita sur» | Marca en la quebradita |
| Llegó el refuerzo | «El refuerzo llegó a los 9:40 por el sur» | Marca en la entrada sur y reloj sugerido |
| Se mojó la pólvora | «La pólvora se mojó en el vado» | Marca en el vado |
| El informante se equivocó | «El informante falló: la torre no era la del templo» | Nota; baja la fiabilidad que se muestra del tipo de informe |

- **Dos puntos de control** (`humahuaca_checkpoint.json`): `posiciones` (todas las partidas en su puesto y aún sin descarga, o a los 3:30) y `deposito` (al tomar el tercer objetivo). El parte de derrota ofrece **«Reintentar desde las posiciones»**, **«Reintentar la salida»**, **«Empezar de nuevo (mismo mundo)»** y **«Mundo nuevo»**; llegar al control demora ≤ 3 s (se mide). Reintentar la salida enseña lo más difícil (qué cargar) sin repetir el ataque.
- **Derrota que enseña.** Una pantalla: causa en ≤ 140 caracteres **con momento y lugar** («A los 5:10 la partida de Portal quedó clavada frente a la torre»), un consejo que rota, tres datos (frentes tomados, golpe, bajas) y el botón primario arriba, sin scroll a 1280 × 720. La historia queda colapsada.
- **Ayudas en escalera, siempre visibles y marcadas** (excluyen la medalla de oro; nunca se imponen): 2.ª derrota seguida → **pista concreta** del diario; 3.ª → **Informante fiel** (confirma la torre y la guardia); 5.ª → **Noche más larga** (el alba llega 60 s después) y **Mulas de más** (+2 mulas). Más la *ventaja de la experiencia* de la Justina (multiplicadores por racha, con etiqueta y evento `assist` en el segundo 0).
- **Condición para pasar al nivel siguiente:** ganar (cualquier medalla): `won = true`. **Alcance de este ciclo (decisión D1a):** Humahuaca se abre con la Justina ganada, igual que hoy el Norte; ganar Humahuaca habilita el botón **«Seguir: Sostener el norte»** del epílogo (ya abierto desde la Justina) y registra `won` para reencadenar más adelante (Justina → Humahuaca → Norte), lo que cuesta reescribir 6 comprobaciones fijadas (contrato, sección 4). No hay puente de estado hacia el Norte.

---

## 9. Onboarding de 30 segundos y lenguaje

**Objetivo en una frase (siempre visible, una línea):** *«Tomá la batería, el cuartel y la pólvora a la vez, y sacá lo que puedas antes del refuerzo.»*

| t | Qué ve el jugador | Control |
|---|---|---|
| 0–5 s | Pausa automática y **una tarjeta de tres líneas**: el objetivo, «perder no es grave: volvés a intentar con lo que aprendiste» y el botón **Empezar**. Una segunda tarjeta (saltable) con la carta del 26-II como dramatización y la nota de fecha. | Empezar |
| 5–15 s | Flecha sobre los reconocedores y el texto **«1. Mandá a los reconocedores a mirar la altura»** (tecla 4 y clic derecho en el cerro). El resto de la interfaz queda atenuado. | Reconocer |
| 15–30 s | **«2. Llevá cada partida a su puesto»** (teclas 1, 2, 3 y «A su puesto»). Una sola acción sugerida por vez. | A su puesto |
| 30–60 s | Tarjeta del informante y la primera elección (**primera decisión significativa antes de los 60 s**). | Elegir |

**Qué se oculta al inicio:** panel de carga y botín (hasta la extracción), diario, puntaje, «Retirada general» (menú de pausa, 2 clics), leyenda del minimapa, barra del enemigo (muestra «?» hasta reconocer) y las etiquetas de fuente (aparecen al seleccionar). **Métricas de arranque** (se miden en el primer cuadro jugable, `test_hx_flow`): **≤ 5 controles accionables** (pausa y velocidad cuentan como uno, ayuda y menú como uno, la barra de acciones muestra ≤ 3), **≤ 400 caracteres** de texto de juego, **0 términos** de la lista negra, una línea de objetivo y un solo «siguiente paso».

**Tutorial de 6 pasos** (saltable, una vez por perfil, se repite con F1): (1) *Reconocer*: mandar a los reconocedores; (2) *A sus puestos*: cada partida a su lugar; (3) *La señal y el alba*: esperar la luz o dar la señal; (4) *Los tres a la vez*: atacar los tres frentes dentro de la sorpresa y apoyar; (5) *Cargar el arreo*: qué llevar, qué destruir; (6) *Salir por el este*: cruzar el vado antes del refuerzo. Cada paso se marca solo cuando el jugador lo cumple.

**Ayuda F1:** una página con el objetivo, cómo se juega (6 líneas), la tabla de teclas de `docs/humahuaca/CONTROLES.md`, un glosario sin jerga, qué significa cada una de las cinco etiquetas y la nota de fecha.

**Lenguaje.** Se usan: *reconocer, puesto, señal, alba, guardia, sorpresa, alerta, ruido, toma, carga, golpe, refuerzo, arreo*. **Lista negra** (`humahuaca_ui.json.jargon_blacklist`, la verifica un test sobre **todas** las cadenas visibles de los JSON y de la interfaz): ETA, sondeo, sondear, ZOC, tag, LOS, DPS, aggro, buff, fog, spawn, waypoint, pathfinding, snapshot, hash, seed, payload, cooldown, HUD, FPS, y los nombres de campos de estado. Un solo mensaje guía a la vez (aviso, alerta o toast con prioridad); pausa automática **corta o nula** salvo decisiones; el ×2 se sugiere en esperas tranquilas y **nunca cambia solo**.

---

## 10. Balance objetivo medible

**Honestidad primero.** En el nivel 1 nadie jugó: «humano promedio» era un modelo inventado, los bots solo ganaban con información perfecta y las perillas globales movían al novato y al experto juntos. Acá: (1) **tres bots, no uno**; (2) se mueve **contenido** (enfoques, variantes, ayudas visibles), no multiplicadores ocultos; (3) los números del modelo **no certifican nada** sin una sesión humana (sección 14).

| Medida | Meta MVP | Cómo se mide |
|---|---|---|
| **Experto** (conoce el mundo; ejecuta el mejor plan de su familia) | ≥ 90 % al 1.er intento, semillas de validación | `tools/humahuaca_playthrough.gd` |
| **Obediente** (solo hace lo que dice «siguiente paso»; es el **proxy del humano promedio**) | **1.er intento 25–40 %; 3.er intento (con diario) 60–80 %**; ≥ 90 % gana al menos una vez en 5 intentos; termina en ≤ 12 min | ídem, con `--attempts=5` |
| **Torpe** (obediente con demoras de 2–8 s, ignora el 30 % de los avisos no urgentes y falla la sincronía ±15 s) | 10–25 % al 1.er intento | ídem, semilla fija |
| **Ciegos** (todos atacan sin reconocer, ataque tarde, pasivo, sin arreo, un solo frente) | ≈ 0 % (≤ 5 %): pierden en el 95 % de los mundos o más | matriz de estrategias |
| **No dominancia** | Ninguna estrategia concentra > 60 % de las victorias globales; ≥ 3 estrategias ganan ≥ 50 % de sus mundos; **ningún guion gana en > 80 % de los 96 mundos**; cada enfoque (batería: gola / frontal / distracción; cuartel: patios / calle / piezas; posta: directa / con distracción) es el mejor en **≥ 1 variante** | `test_hx_rules`, matriz de 18 estrategias × 8 semillas (calibración) y 12 (validación) |
| **Victorias no pírricas** | Mediana de bajas ≤ 55 %; ≤ 15 % de las victorias con bajas > 80 % | `campaign_report().loss_pct` |
| **Duración** | Victorias 10–14 min (mediana 11–13); derrotas: mediana ≤ 8 min, máximo 14:00 | log de eventos |
| **Densidad de decisiones** (la mide `state.stats.pacing` de las reglas, no la interfaz) | Mayor intervalo sin una **decisión posible** (orden que cambia el resultado, elección, alerta con acción) **≤ 45 s**, y **≤ 20 s durante el ataque**; un bot «solo pausa y reanuda» recibe una alerta con acción al menos cada 45 s | `test_hx_rules`, `hx_qa_tour` |
| **Gradiente, no acantilado** | Las estrategias parciales (un frente sin apoyo, sin arreo, sin custodia) ganan **menos y más caro**, no 0 o 100 | matriz |
| **Pasividad** | Pierde en el 100 % (`amanecio` a los 6:30) | `passive` |
| **Rejugabilidad** | La mejor apertura **difiere** entre mundos (al menos 3 aperturas distintas son las mejores en ≥ 1 mundo cada una) | matriz por mundo |

**Método.** Semillas de calibración **3, 5, 7, 11, 13, 17, 19, 23**; de validación **29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73**; de cierre **101, 103, 107, 109, 113, 127, 131, 137, 139, 149, 151, 157, 163, 167**. `world_from_seed()` es determinista y las semillas elegidas cubren **cada valor de cada variante en ≥ 2 semillas de calibración y en ≥ 3 de validación y de cierre** (si el sorteo no lo logra, se ajusta `world_from_seed`, no las listas). Se publican tasas con **intervalos de Wilson al 90 %**, bajas, duraciones y brechas de decisión en `user://hx-balance-results.json` (con `APPDATA` aislado). El obediente aprende solo lo que el diario le muestra (con probabilidad 0,7 de usarlo). Si el modelo y la sesión humana discrepan, **manda la sesión humana**. Las perillas permitidas para calibrar son las de **contenido** (cifras de `humahuaca_rules.json`: sorpresa, cobertura, daño de la torre, demora del refuerzo, capacidad, valores del botín); cambiar un multiplicador global no cuenta como mejora.

---

## 11. Dirección de arte

**Reglas que salen de la lección del nivel 1** («lo visual quedó pobre»: barranca, fuerte y casas de cajas; unidades como discos de color; río re-pintado cinco veces sin referencia; cámara inicial casi solo agua): (1) **referencias objetivas** — la lámina 06 (paleta) y la composición de la foto de 1923; (2) **cinco vistas canónicas aprobadas una sola vez** y, desde ahí, solo comparaciones antes/después; (3) **silueta antes que color**; (4) el agua y el suelo **no se re-pintan** salvo un hallazgo P0 con evidencia; (5) la cámara inicial muestra los tres objetivos y el pueblo, nunca solo suelo o agua.

### 11.1 Paleta (24 HEX de la lámina 06; verificados exactos contra los píxeles, [01] §f)

Los HEX son **decisiones digitales de producción, no mediciones de 1817**. Son **albedo** (color propio a plena luz): la noche, la lluvia y el alba se logran con luz, niebla y exposición, no con otros HEX. Fuente única: `humahuaca_visual.json.palette` (la iguala un test al listado de la lámina).

| Grupo | Nombre | HEX | Uso en el juego | Cuidado |
|---|---|---|---|---|
| Paisaje | Suelo seco | `#B99A72` | Terreno base, caminos, patios | Parecido al adobe y a la paja (ΔE 4,4–4,8): separar por textura y brillo |
| Paisaje | Sedimento húmedo | `#776248` | Zanjas, barro, orillas | La lana parda se pierde encima (ΔE 4,7): contorno |
| Paisaje | Piedra gris | `#8E8B81` | Cimientos, cerro, lecho | — |
| Paisaje | Churqui / arbusto | `#6D7653` | Churcal de ladera | Casi igual al irrigado (ΔE 3,6): separar por ubicación y textura |
| Paisaje | Vegetación irrigada | `#69794B` | Parcelas regadas junto al núcleo y el río | idem |
| Paisaje | Agua turbia | `#8C9B91` | Río, charcos | Opaca; sin degradé de profundidad |
| Construcciones | Adobe / revoque | `#C4AA82` | Muros | — |
| Construcciones | Cal envejecida | `#E4DDCA` | Encalado de templo y casas | Casi igual al lino y al blanco (ΔE 2,6–5,0) |
| Construcciones | Madera oscura | `#59432E` | Puertas, vigas, torre | — |
| Construcciones | Cuero | `#745034` | Aparejos, cargas | — |
| Construcciones | Paja / cubierta | `#B3A077` | Techos, remates de tapia | — |
| Construcciones | Hierro | `#4B4B47` | Cañones, herrajes | — |
| Personajes | Lana natural | `#CEC2A7` | Camisas y ponchos claros | Se confunde con cal y adobe (ΔE 7,1–8,3) |
| Personajes | Lana parda | `#705741` | Ponchos | Se confunde con cuero y barro (ΔE 4,4–4,7) |
| Personajes | Azul elegido | `#2E455A` | Acento de pañería y chaquetas | El que mejor se lee |
| Personajes | Rojo reservado | `#9A443B` | **Solo acentos** de variantes (cinta, banda) | Nunca uniforme; ΔE 1,4 con la borgoña |
| Personajes | Verde elegido | `#4F5E4C` | Acentos | Límite con el churqui (ΔE 11) |
| Personajes | Lino crudo | `#E1D7BD` | Camisas | Casi igual a la cal (ΔE 2,8) |
| Símbolos | Celeste de producción | `#7FAAC4` | **Marcador de interfaz** del bando patriota, banderines (sin sol) | Colores consagrados en 1816 ●; que la partida llevara una bandera concreta ○ |
| Símbolos | Blanco textil | `#EFE8D7` | Borde de marcadores; trofeo plegado | — |
| Símbolos | Borgoña hipotética | `#983F36` | **Marcador de interfaz** del bando realista (diseño) | **No** completar el trofeo con cruz de Borgoña genérica ni con la bandera española actual |
| Símbolos | Oro / latón | `#B99A50` | Marcador neutral del arreo, bordes de ficha, herrajes | — |
| Símbolos | Negro textil | `#383831` | Contornos y sombras de las figuras | — |
| Símbolos | Grana como analogía | `#843D40` | Evitar salvo detalle | Analogía, no dato |

**Legibilidad (no alcanza el color):** (1) la identidad de partida y de bando la dan **anillo, ícono, contorno y marcador de interfaz**, no el color de la ropa (el dossier lo pide: «los colores pueden superponerse entre bandos»); (2) contorno oscuro (`#383831`) en todas las figuras; (3) azul, rojo y verde solo como **acentos** (≤ 15 % de la superficie de una figura); (4) los marcadores de interfaz se validan con `validate_palette.js` (skill `dataviz`), umbral de ΔE fijado en R1; (5) **métrica de paleta**: distancia media de color de suelo, edificios y figuras de las vistas canónicas a la lámina 06, umbral fijado en R1 con la primera captura aprobada; (6) un anillo tenue de **visibilidad** alrededor de cada partida de noche (dónde ve y dónde se la ve).

### 11.2 Materiales, luz y vegetación

- **Materiales (todos procedurales; sin descargas):** adobe (bloques de tierra con juntas irregulares y desgaste en la base), **tapia** (tierra compactada en franjas horizontales de 40–60 cm, remate de paja), cal envejecida (blanco sucio, manchas de lluvia), piedra gris (cimientos y cerro), madera oscura, paja y azotea de barro con pretil o techo a dos aguas, suelo de grava clara con piedras sueltas en la ladera, tierra apisonada en patios, barro brillante con charcos. Se retinta **por rol** (atributos de color por vértice), no por heurística de rangos RGB: la de la Justina es frágil ante modelos nuevos.
- **Luz:** `noche_lluvia` (luz fría hacia `#2E455A`, energía ≈ 0,15, niebla densa de 220 m), `alba` (sol a 6°, cálido, sombras largas, niebla de valle), `dia` (sol a 35°). Transiciones continuas con `time_of_day`. **Lluvia:** rayas por partículas, suelo que se oscurece ×0,75 y brilla donde llueve, charcos. Presupuesto: cuadro medio < 3 ms.
- **Vegetación:** churqui (arbusto espinoso de 2–3 m; se retinta `tree_algarrobo` solo si su silueta sirve, D9), cardón (`tree_cardon`, 3–5 m, en laderas), sauce criollo (6–8 m) en el monte ribereño y parcelas irrigadas de alfalfa. **Excluidos:** álamos piramidales, eucaliptos, postes, tendidos y alumbrado (la foto es de 1923 y no los acredita para 1817). Pregunta abierta al usuario: si los quiere igual, irían rotulados «diseño, no acreditado» (anexo B).
- **Arquitectura de 1817:** **templo sin fachada ni torres de 1880–1881**: nave simple de adobe encalado con cubierta a dos aguas; el **sector Santa Bárbara** es un reducto de tierra con foso y parapeto sobre la altura (no una capilla ni un monumento ni una escalinata); sin cabildo actual; calles de tierra (acabado editable); casas bajas de adobe con azotea o dos aguas; patios y tapias. La foto de 1923 sirve como **relación** (ladera → núcleo → monte ribereño → lecho claro → llanura → cerros con estratos → horizonte), no como copia.
- **Figuras y fichas:** figuras 3D de ≥ 1,7 m con contorno, **sin uniformar** (camisa de lino o lana natural, poncho o chaqueta de lana parda o azul, sombreros y gorras variados; un rojo o verde cada seis); realistas con equipo que distingue función (fusil y cartuchera, artillero con herramienta, «chicheño» sin uniforme cerrado ○), sin «todos de blanco». Fichas de **tamaño fijo en pantalla** (≥ 48 px de alto a zoom por defecto, distinguibles en escala de grises): `rodriguez` jinete, `portal` infante con fusil, `arias` infante con banderín de mando, `reconocedores` dos figuras agachadas, `arreo` mula cargada. Banderín de bando = **marcador de interfaz** (diseño), nunca una bandera de 1817.
- **Modelos:** GLB existentes retintados (`horse_only`, `royalist_1817`, `rider_1817` con el poncho retintado, `house_colonial`, `church_colonial` **sin torre**, `tree_cardon`, `rock_cluster`); **no sirven** `infantry`, `dismounted_1806`, `rider_1806`. Lo nuevo (tapias, torre, posta, cargas, mulas, cañones, cerco) sale de **primitivas de Godot** (`BoxMesh`, `PrismMesh`, `CylinderMesh`, `SurfaceTool`, `MultiMeshInstance3D`). **Blender no está instalado**: se pide el portable solo si R2 muestra que no alcanza (D10); ningún modelo de IA ni de descarga.

### 11.3 Cinco vistas canónicas (en `humahuaca_visual.json.canonical_views`; cámara fija)

| Id | Qué debe mostrar | Cámara (objetivo x,z · distancia · inclinación · rumbo) | Luz |
|---|---|---|---|
| `acceso_so` | Desde el acceso del sudoeste: la ladera a la izquierda, el núcleo y el templo al fondo [md §K] | (300, 520) · 150 m · 22° · 45° | noche con lluvia |
| `desde_bateria` | Desde la plataforma: el pueblo por debajo hacia el este, el río y el lecho claro [md §K] | (318, 350) · 60 m · 18° · 90° | alba |
| `patio_posta` | El patio de la posta: cargas, mulas, polvorín [md §K] | (590, 300) · 45 m · 40° · 315° | mañana |
| `panorama_alto` | La composición de la foto de 1923, sin torres ni monumento | (450, 330) · 330 m · 28° · 90° | alba |
| `grupos_en_accion` | El asalto al cuartel con la torre, fichas, humo y bajas | (418, 335) · 90 m · 45° · 0° | alba, lluvia floja |

**Cámara inicial** (`initial_frame()`): objetivo (350, 470), 470 m, 52°, rumbo 35°; debe **incluir los tres objetivos y la zona de partida**; zoom de juego entre 40 y 900 m.

### 11.4 Lista priorizada de elementos a modelar (27)

Orden de producción del dossier [md §G]: 1 terreno y relaciones · 2 tres objetivos · 3 torre · 4 conexiones · 5 logística · 6 vida cotidiana. La tabla original de 23 filas **no está**; esta es una reconstrucción propia (más la plaza, el templo, el trofeo y las fichas). Coordenadas de juego `x,z`; «R1» = entra como caja con la huella correcta en la rebanada vertical.

| # | Elemento (id) | Ubicación | Dimensiones de prototipo | Materiales | Colores | Referencia | Certeza | Función | Prioridad |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Cerro occidental (`cerro_occidental`) | domo en (305, 345), radio 75 m | +12 m sobre el DEM; plataforma 28 × 18 m | grava, suelo seco, piedra, churqui | `#B99A72` `#8E8B81` `#6D7653` | foto 1923 plano 1; lám. 03 | relieve ◇; domo ▲ | visión, tiro, flanqueo | 1 · R1 |
| 2 | Núcleo urbano (`nucleo_urbano`) | x 340–700, z 200–470 | manzanas de 54 × 54 m; calles de 8 m | adobe, cal, paja | `#C4AA82` `#E4DDCA` `#B3A077` | foto plano 2 | sitio ◇; planta ▲ | laberinto de tapias y cobertura | 1 · R1 (cajas) |
| 3 | Río Grande (`rio_grande`) | (572, 0) → (900, 406) | lecho de 25–40 m; agua de 0,2–0,6 m; 2 vados | agua, sedimento, piedra | `#8C9B91` `#776248` `#8E8B81` | foto planos 4–5; lám. 03 | traza moderna; cauce de 1817 ○ | borde y salida | 1 · R1 |
| 4 | Templo (`templo`) | (450, 325) | nave 22 × 8 m; alero 5,5 m; caballete 7 m; atrio 14 × 10 m | adobe encalado, madera, paja | `#E4DDCA` `#C4AA82` `#59432E` `#B3A077` | foto 1923 (sin torres ni fachada) | sitio ◇; forma ○ | hito, cobertura | 1 · R1 |
| 5 | Plaza (`plaza`) | (450, 392) | 56 × 50 m | tierra apisonada | `#B99A72` | [md §G] | ▲ parámetro | cruce y reunión del refuerzo | 1 · R1 |
| 6 | Batería de Santa Bárbara (`bateria`) | (318, 350) | plataforma 28 × 18 m; parapeto 1,6 m; foso 2 × 2 m; gola al oeste; 3 piezas | tierra, piedra, madera, hierro | `#B99A72` `#8E8B81` `#59432E` `#4B4B47` | lám. 03 (−111,−35); Diario realista | objetivo ●; posición y cota ▲ | frente 1 | 2 · R1 |
| 7 | Cuartel, casa del cura (`cuartel`) | (418, 335) | 22 × 14 m; muro 0,7 m; alero 3,2 m; patio 8 × 8 m; aspilleras | adobe, cal, madera, paja | `#C4AA82` `#E4DDCA` `#59432E` `#B3A077` | parte («casa del Cura») | objetivo ●; lugar ▲ ○ | frente 2 | 2 · R1 |
| 8 | Posta con polvorín (`posta`) | (590, 300) | patio 30 × 24 m; muros 2,4 m; 2 entradas; polvorín 6 × 5 m al NE; corral 20 × 14 m | adobe, madera, cuero | `#C4AA82` `#59432E` `#745034` | parte («casa de Posta»); [md §K] | objetivo ●; planta ▲; pólvora ahí ◇ | frente 3 y botín | 2 · R1 |
| 9 | Torre provisional (`torre_casa_cura` / `torre_templo`) | (426, 326) o (466, 322) | base 3,5 × 3,5 m; 10 m; plataforma a 9 m con 8 aspilleras | adobe y madera | `#C4AA82` `#59432E` `#B3A077` | parte («la torre») | resistencia ●; cuál y dónde ○ | fuego sobre las calles | 3 · R1 (caja) |
| 10 | Tapias (`tapias`) | entre el acceso y el núcleo; ≥ 12 en R1 | 1,8–2,4 m de alto; 0,5 m de espesor | tierra compactada, remate de paja | `#C4AA82` `#B99A72` `#B3A077` | parte («tapial»); foto plano 3 | existencia ●; posición ▲ | rutas y ocultamiento | 4 · R1 (líneas) |
| 11 | Patios (`patios`) | dentro del núcleo; ≥ 6 | 12–30 m de lado | tierra apisonada | `#B99A72` | foto plano 2; [md §K] | ▲ | rutas ocultas | 4 · R2 |
| 12 | Zanjas y acequias (`zanjas`) | cerca de parcelas y posta; ≥ 4 en R1 | 0,8–1,2 m de profundidad; 1,2–2 m de ancho | sedimento húmedo | `#776248` | parte («zanjita») | existencia ●; posición ▲ | lentitud y tropiezo | 4 · R1 |
| 13 | Portillos y pasajes (`portillos`) | ≥ 6 en tapias | 2,5–3 m; portillo abierto 1,8 m | madera | `#59432E` | [md §G] | ▲ | rutas | 4 · R2 |
| 14 | Quebradita (`quebradita_norte` / `quebradita_sur`) | (282, 298) / (288, 402) | 36 × 8 m; −2,5 m | suelo seco, churqui | `#B99A72` `#6D7653` | parte («quebradita») | existencia ●; lugar ▲ ○ | refugio de caballos | 4 · R1 |
| 15 | Camino cubierto y barricadas (`camino_cubierto`, `barricadas`) | (405, 338) → (345, 350); bocacalles del SO | 60 m entre tapias de 1,8 m; barricada de 8 m | tapia, maderos, carretas | `#C4AA82` `#59432E` | Diario realista (enero) | ◇ | repliegue y entradas | 4 · R2 |
| 16 | Cargas (`cargas`) | posta y cuartel | 100 kg c/u; 0,9 × 0,5 × 0,4 m | cuero, lana, madera | `#745034` `#CEC2A7` `#59432E` | parte (recursos capturados) | existencia ●; pesos ▲ | botín | 5 · R1 (cajas) |
| 17 | Recipientes (`recipientes`) | polvorín y depósito | barriles de 50 l; botijas; cajones | madera, hierro, cuero | `#59432E` `#4B4B47` `#745034` | ▲ | ▲ | pólvora y víveres | 5 · R2 |
| 18 | Armas (`armas`) | armería del cuartel | fusil de chispa 1,45 m; sables; lanzas; palos | hierro, madera | `#4B4B47` `#59432E` | parte («armas muy desiguales») | desiguales ●; modelos ○ | botín y equipo de figuras | 5 · R2 |
| 19 | Cañones (`canones`) | 3 en la batería; 4 en el parque de la posta | tubo 1,6 m; 400 kg (de a 4) y 200 kg (de a 2) | hierro, madera | `#4B4B47` `#59432E` | parte («siete piezas») | 6–7 ◆; modelo ○ | botín; voltear | 2 · R1 (cajas) |
| 20 | Animales (`animales`) | arreo, corral, caballada, ovejas, vacas | mula 1,3 m a la cruz; caballo 1,4 m | lana parda, cuero | `#705741` `#745034` | parte (16 mulas, 2 000 ovejas, 60 vacas) | ●; cantidades iniciales ▲ | transporte | 5 · R1 (siluetas) |
| 21 | Arreos (`arreos`) | sobre mulas y caballos | aparejos, cinchas, cabestros | cuero, lana | `#745034` `#CEC2A7` | analogía Vidal 1820 y Temple 1830 | ▲ (analogía tardía) | lectura de la carga | 5 · R3 |
| 22 | Viviendas (`viviendas`) | núcleo; ≥ 40 | 6 × 4 m a 12 × 6 m; muro 0,6 m; alero 2,6–3,2 m | adobe, cal, paja | `#C4AA82` `#E4DDCA` `#B3A077` | foto plano 2 (analogía tardía) | ▲ | volumen y cobertura | 6 · R2 |
| 23 | Corrales (`corrales`) | cerca de la posta y del núcleo | 12 × 12 m; tapia baja de 1,2 m | tierra, palos | `#B99A72` `#59432E` | ▲ | ▲ | ganado | 6 · R3 |
| 24 | Utensilios (`utensilios`) | patios | tinajas, ollas, bancos | barro, madera, hierro | `#C4AA82` `#59432E` `#4B4B47` | ▲ | ▲ | vida cotidiana | 6 · R3 |
| 25 | Vegetación (`vegetacion`) | churqui y cardón en la ladera oeste; sauce y parcelas hacia el río | churqui 2–3 m; cardón 3–5 m; sauce 6–8 m | — | `#6D7653` `#69794B` | foto planos 1, 3, 4; [md §D] | ◇ (álamos y eucaliptos excluidos) | cobertura y lectura | 6 · R2 |
| 26 | Trofeo, bandera (`bandera_trofeo`) | cuartel | 1,4 × 1,0 m; plegada | tela | `#EFE8D7` `#B99A50` | parte y anexo («Pumacagua degollado») | ● parcial; paño ▲ ○ | botín opcional | 5 · R3 |
| 27 | Fichas y estandartes (`fichas`) | interfaz | ficha fija ≥ 48 px; banderín de bando | — | `#7FAAC4` `#EFE8D7` `#983F36` `#383831` `#B99A50` | lám. 06 (símbolos) | ▲ marcadores, no banderas | lectura de partidas y bandos | 1 · R1 |

---

## 12. Historia: etiquetas, matriz y límites

### 12.1 Las cinco etiquetas visibles

El código usa cuatro (`documentado`, `tradicion`, `reconstruccion`, `diseno`) y el dossier cinco. Para Humahuaca se adoptan **las cinco del dossier** con ids propios, porque «versión discutida» y «sin datos suficientes» no son «tradición» ni «diseño» (decisión D3). Una entidad mixta se rotula por su parte más débil y separa sus partes en `tag_parts`. Documentado = «lo informó su autor»: las cifras y explicaciones de un parte igual requieren contraste.

| Id | Glifo | Etiqueta | Equivale a (dossier) | Equivalente heredado |
|---|---|---|---|---|
| `documentado` | ● | Documentado | documentado | `documentado` |
| `razonado` | ◇ | Inferencia razonada | inferencia razonada | `reconstruccion` |
| `discutido` | ◆ | Versión discutida | versión discutida | `tradicion` (solo si es una atribución) |
| `diseno` | ▲ | Diseño | decisión de diseño | `diseno` |
| `sin_datos` | ○ | Sin datos suficientes | sin datos suficientes | (nueva) |

### 12.2 Matriz resumida: qué se afirma y con qué certeza

| Afirmación (texto del juego) | Etiqueta | Fuente corta |
|---|---|---|
| Arias dirige el asalto; Güemes conduce el frente regional desde Salta y **no está** en el asalto; San Martín ya había vencido en Chacabuco y no lo dirige | ● | parte de Arias; md §B, §H |
| Los tres trozos y objetivos: batería de Santa Bárbara (Rodríguez), cuartel en la casa del Cura (Portal y Ontiveros), posta y pólvora (Arias) | ● | parte de Arias, 3-III-1817 |
| Marcha de ≈ 26 h, lluvia copiosa en la primera tarde (27-II); 150 hombres «sin más armas que palos» | ● (cifra de Arias) | parte; el Diario realista dice 300 → ◆ |
| Lluvia durante la noche del 28 y el alba | ▲ (reconstrucción razonada) | md §D |
| Reparto 48/52/50 y porcentajes de armas; zona de partida del SO | ▲ | — |
| Caballos de Rodríguez en una quebradita «en ese alto» | ● el hecho; ▲ cuál | parte |
| Reconocimiento personal de «tapial, zanjita y campo» | ● el hecho; ▲ posiciones | parte |
| Capilla de Santa Bárbara derribada y batería en esa altura (enero) | ● informe (informante indígena) | informe de Arias, 31-I |
| La batería está al **oeste**, a 12 m de prominencia | ▲ | lám. 03; md §C.3 |
| Resistencia desde una torre (5:00–6:30) | ● el hecho; ○ cuál torre y dónde | parte |
| La pólvora está en la posta | ◇ | parte («por la casa de Posta... ganar la pólvora») |
| Portal fue prisionero en Humahuaca y se fugó; conoce las calles | ● la fuga; ◇ que las conozca | oficio de Güemes, 20-II |
| Un traidor avisó; la guardia «lo había esperado noches antes» | ● acusación (sin identificar); ▲ la variante «atenta» | parte |
| Munición quemada o al río; cañones sin llevar; luego recuperados | ● Arias y La Serna; ◆ «ocultos o enterrados» | parte; Camba; Diario |
| Fecha: 1 de marzo (itinerario de Arias, Diario realista) o 2 (La Serna, prisioneros, inscripción del premio) | ◆ | md §A; [02] b.5 |
| Guarnición ≈ 130 y 6–7 piezas | ● / ◆ | Camba; Diario; Arias |
| Refuerzo realista inmediato | ▲ (**no ocurrió**: se supo el 4 y salieron columnas el 5–6) | Camba; Diario |
| Pueblo casi vacío de vecinos; informantes y arrieros presentes | ● / ◇ | Diario; md §D |
| Parte: 3-III San Andrés → 8-III Salta (22 h) → 13-III Tucumán | ● | md §C.1; GD IV |
| Seis piezas recuperadas por La Serna | ● versión realista | oficio de La Serna, 11-IV |
| Bandera del primer regimiento, «Pumacagua degollado» en una punta | ● parcial; diseño del paño ▲ ○ | anexo del parte |
| Premio de Humahuaca (medallas, abril) | ● posterior al combate | Belgrano, 10-IV |
| Vestuario de ambos bandos | ○ | — |
| Planta del pueblo, posición del cuartel, la posta y la torre | ○ / ▲ | no hay plano de 1817 |

### 12.3 Anacronismos prohibidos (cada uno con su sustituto)

Monumento a los Héroes de la Independencia y escalinata (sustituto: cerro con reducto) · fachada y torres actuales del templo (nave provisional) · cabildo actual como edificio de 1817 (casas genéricas) · empedrado de calles por una foto tardía (tierra) · álamos piramidales, eucaliptos, postes, tendidos y alumbrado de 1923 · el óvalo inferior de la foto · el **premio de Humahuaca en el pecho** al comenzar · **sol en la bandera** (1818) · cruz de Borgoña genérica o bandera española actual para completar el trofeo · **uniformes homogéneos** (todos de rojo o de blanco) · «todos Infernales» (el parte no los menciona) · **Güemes** entre los grupos del asalto o llamado «coronel mayor» (es de mayo) · su chaqueta azul de húsar (abril de 1818) · **San Martín** dirigiendo o una orden táctica en la carta del 26-II · cierre como **expulsión definitiva** · retirada realista por **una sola causa** · victoria con **inventario ilimitado** · **tormenta durante todo el combate** · horas del parte trasladadas al reloj actual · población como fondo inmóvil o uniformemente entusiasta · la **ruta final de Arias** o el paso de Zenta · la línea de la lámina 02 como «ruta 9» o camino de carretas · el itinerario de García Camba (de una columna realista posterior) aplicado a Arias · mezclar Yungas, planicie puneña y valle de Lerma · **cotas, alturas de tapias, caudal o vados presentados como medidos** · los círculos de la lámina 03 como huellas de 1817 · los HEX como mediciones · el **refuerzo realista** presentado como hecho.

### 12.4 Tratamiento de figuras y símbolos

**Güemes:** 32 años, coronel (no coronel mayor), gobernador y conductor regional; aparece en el briefing (la carta del 26-II es una **dramatización** rotulada: «Hay una lectura adaptada; la carta no contiene ninguna orden») y en el epílogo; **nunca** como figura en el mapa. **San Martín:** contexto (Chacabuco, 12-II), sin dirección del asalto. **Arias, Rodríguez, Portal, Ontiveros:** funciones documentadas; su ropa **no** lo está. **Bandera:** celeste y blanco consagrados en 1816; el sol recién en 1818; **no** se dibuja una bandera para la partida (los marcadores son de interfaz); el trofeo es el del primer regimiento, plegado y declarado diseño. **Escarapela:** su autorización es anterior, pero forma y distribución en la partida están abiertas: no se dibuja una por figura. **Uniformes:** variantes por prenda y equipo, bando por marcador. **Realistas:** no todos peninsulares (chicheños, servicios). **Premio:** solo en el epílogo, con su fecha.

---

## 13. Qué NO hacer

- No tocar la Justina ni las reglas del Norte (`game_rules.gd`, `world_view.gd`, `campaign.gd`, `justina_map.json`, sus shaders y modelos): el nivel nuevo vive en archivos propios.
- No pasar el nivel por `main.rules`, `_is_j()` ni `mode == "play"`; no llamar `GameRules.new_game("humahuaca")` (convierte cualquier nombre desconocido en «justine»).
- No guardar progreso en `campaign.json`; no sumar `"humahuaca"` a las listas de `GameRules`.
- No generalizar un motor común ni crear sistemas nuevos grandes (economía, formaciones): es un golpe de mano de 10–14 minutos, no un RTS.
- No inventar planta, rutas, cifras ni vestuario y presentarlos como documentados; no afirmar el refuerzo como hecho; no fijar la ruta de Arias.
- No re-pintar el agua o el suelo ronda tras ronda sin referencia; no cambiar la paleta (los 24 HEX son la referencia).
- No esconder ayudas ni multiplicadores: baqueano, noche más larga y la ventaja de la experiencia son visibles y marcadas.
- No perillas globales para «dar» el balance: se mueve contenido.
- No más de 7 hallazgos por ronda ni listas abiertas; no reportar «94 pendientes».
- No mostrar la carta del 26-II como cita: es una dramatización rotulada.
- No descargar nada sin permiso (tesela, Blender, paquetes de PyPI); no usar Google Elevation; no copiar código GPL; no modelos de IA.
- No imprimir ni guardar claves de Jev; no abrir `.env*` ni `jev.cfg`.
- No capturas por volumen: ≤ 12 JPEG ≤ 300 KB por pista y ronda; solo la última ronda entra a Git.
- No declarar «presentable» sin una sesión humana: sin ella, el QA dice «no certificado por humanos».
- No push ni release.

---

## 14. Plan de rondas del bucle

Equipo: **cuatro pistas** (`relieve_mapa`, `reglas_historia`, `visual`, `ui_feel`) con propiedad exclusiva de archivos, **un integrador** (único autor de `main.gd`, del andamiaje y de los merges), **control de calidad** (un solo informe por ronda, con **presupuesto de hallazgos**), un revisor por pista sobre su diff, y el arquitecto (este documento y el contrato). El QA reporta **≤ 7 hallazgos por ronda**: **P0** (bloquea: se cuelga, no se entiende el objetivo, > 45 s sin decisión, ilegible), **P1** (cuentan los 3 primeros), **P2** (van a `docs/humahuaca/BACKLOG.md` y no cuentan). Cada hallazgo trae id, evidencia (una imagen o una métrica), pista dueña y prueba de aceptación; las categorías se fijan en R1 y solo se agregan por regresión; los duplicados se fusionan.

| Ronda | Entra | **No** se hace todavía | Salida (verificable) |
|---|---|---|---|
| **R0** (integrador) | Andamiaje T0: stubs que compilan, ganchos de `main.gd`, cinco JSON mínimos, `tests/test_hx_data.gd` y `test_hx_smoke.gd`, `tools/qa_gate.sh`, `.gitignore`/`.gitattributes`; estos dos documentos | Cualquier contenido de juego | Compuerta rápida verde (reglas ≥ 818, integración ≥ 283, smoke y data ok, protegidos intactos); recién entonces se abren los worktrees |
| **R1 · corte vertical** | Menú → briefing → aproximación → tres objetivos → resistencia → extracción → epílogo → reintento, **en caja gris pero con relieve real**: grilla (plan B si no hay permiso), tres objetivos con combate y sorpresa, alba y visibilidad, alarma, carga con capacidad, victoria y derrota, parte, HUD mínimo con «siguiente paso», fichas por silueta, cámara inicial correcta | Variantes del mundo, diario con marcas, medallas, tapias y zanjas con reconocimiento fino, torre con apoyo, decisiones, audio, arte fino, Jev | Un bot **gana** y otro **pierde** por caminos distintos (`test_hx_flow`); `ui_qa_humahuaca` en 3 resoluciones; benchmark < 3 ms; el QA fija las categorías de criterios. **Sin esto no se abre R2** |
| **R2 · legibilidad y profundidad** | Tapias, zanjas, portillos, quebraditas y reconocimiento con riesgo; torre con las cuatro respuestas; apoyo entre sectores y piezas; decisiones y eventos del guion; seis variantes (96 mundos); diario con marcas «anotado», puntos de control, ayudas, medallas; tres bots y matriz de estrategias; edificios, figuras, noche con lluvia → alba, vistas canónicas v1; tutorial de 6 pasos y ayuda F1; sonido de avisos | Pulido fino de arte, textos finales, certificación | Informe de bots (experto, obediente, torpe, ciegos); vistas canónicas **aprobadas una sola vez**; brecha de decisión ≤ 45 s; 0 P0 |
| **R3 · pulido visual y ritmo** | Balance por **contenido** (no por perillas), pulido de arte y textos, rendimiento, accesibilidad (contraste, no solo color), la lista negra de jerga en cero, evidencia final | Contenido nuevo | 0 P0 y ≤ 3 P1; benchmark < 3 ms; métrica de paleta bajo el umbral; metas de la sección 10 dentro de rango o con explicación |
| **R4 · cierre y certificación** | Compuerta completa, **sesión humana de 20 min** (el usuario o quien designe: «¿entendiste qué hacer?» y «¿cuándo te aburriste?»), evidencia final (< 60 MB), README, CLAUDE.md, VERSION, créditos; decisión D1 (reencadenar o no) | — | «Presentable» o una lista cerrada y corta. Sin sesión humana el QA dice «no certificado por humanos» |

**Criterio de salida del bucle (lo que firma el QA):** compuerta técnica verde con todas las líneas base (contrato, sección 5); las cinco vistas canónicas sin P0 a 1280 × 720 y 1920 × 1080, **miradas una por una**; bots y no dominancia en rango (sección 10); decisiones ≤ 45 s; arranque (≤ 5 controles, ≤ 400 caracteres, 0 jerga); cero anacronismos y etiquetas honestas; 0 P0 y ≤ 2 P1; evidencia dentro del presupuesto; y la sesión humana. Una ronda que no mueve ese criterio no cuenta.

---

## Anexo A. Qué falta del material del usuario y qué haríamos si llega

| Falta | Impacto | Si llega | Mientras tanto |
|---|---|---|---|
| Paquete editable (zip de 39 archivos), PDF/MD del dossier de 52 páginas, 16 fichas | Alto en trazabilidad; riesgo en derechos de imagen | Se contrastan las citas y se agregan fuentes a partir de **S46** en `data/history.json` | Se trabaja con el resumen y se repiten las citas «según el md» |
| **Lámina 04** (plano del prototipo) y **tabla de 23 elementos × 9 campos** | **Muy alto**: fijaría plaza, templo, posta, casas y los tres objetivos | `map_version + 1`, addendum al contrato con las posiciones y dimensiones; se actualizan `humahuaca_map.json` y las pruebas | Posiciones de la sección 3 como **diseño** rotulado |
| Láminas 01 y 05 (estratégica; perfil A–A′ y quizá los 12 m) | Medio | Se contrasta el perfil con la grilla | Perfil A–A′ reconstruido en [01] §d.6; los 12 m son diseño |
| Datos de relieve del zip | Alto | Plan D (sección 4) | Plan B desde la lámina 03 |
| Facsímil de *Güemes documentado* IV y VII, *Gazeta* | Medio | Verificar fecha (1 o 2) y cifras | Cifras tomadas de OCR sin cotejo |

## Anexo B. Permisos y preguntas pendientes (no se descargó ni instaló nada)

| Qué | Origen | Tamaño | Si no |
|---|---|---|---|
| Tesela **Copernicus GLO-30 S24_00_W066_00** | `https://copernicus-dem-30m.s3.amazonaws.com/Copernicus_DSM_COG_10_S24_00_W066_00_DEM/Copernicus_DSM_COG_10_S24_00_W066_00_DEM.tif` (destino: `investigacion-nivel2/descargas/`, fuera de Git) | 39 438 103 B | Plan B (lámina 03) sin pérdida de funcionalidad |
| **Blender 4.4.3 portable** (solo si R2 lo justifica) | `https://download.blender.org/release/Blender4.4/blender-4.4.3-windows-x64.zip` | 385 412 148 B | Primitivas de Godot y GLB retintados |
| Paquete del dossier, láminas 01/04/05, tabla de 23 filas, 16 fichas | Biblioteca de ChatGPT del usuario (copiar a `info/2` o autorizar abrir con Claude in Chrome) | n/d | Sección 3 como diseño |
| Álamos y eucaliptos: ¿los querés igual (rotulados «diseño, no acreditado para 1817»)? | — | — | Excluidos |
| Sesión humana de 20 min: ¿quién juega? | — | — | «No certificado por humanos» |
| ¿Probar Humahuaca sin ganar la Justina? | `--scenario=humahuaca` lo abre directo (como `--scenario=norte`) | — | Candado normal |
| Reencadenar Justina → Humahuaca → Norte (D1b) | Cuesta 6 comprobaciones fijadas y 5 textos | — | D1a: Humahuaca y Norte se abren con la Justina |
