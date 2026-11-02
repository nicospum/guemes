# Diseño del nivel 2: Humahuaca, el depósito de la retaguardia

Documento de diseño del escenario `humahuaca` (nivel II). Arquitecto jefe de diseño, 1 de noviembre de 2026. Versión del diseño: **1.1** (`contract: 1`; revisión final antes de escribir código: las objeciones del crítico y su resolución están en «Objeciones y decisiones», al final). Base: `main` en `5ebbd28`. El contrato entre pistas, con firmas, archivos, pruebas y plan de rondas, es `docs/CONTRATO_HUMAHUACA.md`; el criterio de calidad («presentable») y su rúbrica, `docs/QA_NIVEL2.md`; este texto explica **qué se juega y por qué**.

> **Cómo leer este documento.**
> - Los números son **valores de partida**: viven en `data/humahuaca_rules.json` (reglas y cifras de juego), `data/humahuaca_level.json` (rasgos, accesos y zonas del nivel), `data/humahuaca_map.json` (relieve e hitos) y los otros tres JSON del contrato (`height`, `visual`, `ui`). **Cada número de juego tiene una sola fuente**: el JSON de reglas; los demás archivos lo citan por id. Hasta que la ronda 1 los mida, este texto manda; desde la ronda 2a, si el JSON y este texto discrepan, vale el JSON y se corrige el texto.
> - Todo dato, lugar o regla lleva una de **cinco etiquetas** (sección 12): Documentado ●, Inferencia razonada ◇, Versión discutida ◆, Diseño ▲, Sin datos suficientes ○. Una entidad mixta se rotula por su parte más débil.
> - Fuentes de este diseño: el resumen del dossier del usuario (`info/2/Humahuaca, comienzos de marzo de 1817.md`, citado como **[md §X]**) y sus láminas 02, 03 y 06 y la foto de 1923; los informes de preparación `investigacion-nivel2/preparacion/01_dossier_humahuaca.md` (**[01]**), `02_fuentes_primarias.md` (**[02]**, con el parte de Arias leído completo), `03_arquitectura_actual.md` (**[03]**) y `04_herramientas.md` (**[04]**); y las lecciones de `docs/DISENO_JUSTINA.md`, `docs/CONTRATO_JUSTINA.md` y `docs/PLAN_DIVERSION_JUSTINA.md`.
> - **Faltan** el dossier de 52 páginas, el paquete editable de 39 archivos, las láminas 01, 04 y 05, la tabla de 23 elementos y las 16 fichas (el `.md` solo los enlaza a una biblioteca externa). **No se inventó nada para suplirlos**: todo lo que la lámina 04 (plano del prototipo) fijaría queda como diseño rotulado y se corrige por addendum cuando llegue (anexo A).

**Decisión de alcance (del lead; el usuario puede revertirla).** El nivel 2 pasa a ser *Humahuaca*. La campaña por rondas «Sostener el norte» se conserva **sin cambios de reglas** y pasa a ser el nivel III; sus pruebas siguen verdes. **No se la presenta como continuación del II**: esa campaña empieza el 15 de diciembre de 1816 y ya incluye, desde su ronda del 1 de marzo de 1817, la operación de Arias en Humahuaca (abstracta); el menú y el epílogo la llaman «la campaña entera, 1816–1817, vista desde Salta (Humahuaca es una de sus operaciones)». **Confirmación barata:** al cierre de R1 el integrador le manda al usuario una captura de la cámara inicial en caja gris y una pregunta de sí o no («¿es lo que querías?») antes de gastar R2a–R4; si la respuesta es no, se revierte la decisión de alcance y lo hecho queda como escenario opcional. La Justina (nivel 1) **no se toca** y no está certificada: este trabajo no la mejora, solo se asegura de no romperla. El nivel nuevo se construye en el espíritu de la Justina (tiempo real con pausa y ×1/×2/×4, agrupaciones, órdenes contextuales, ciclo perder → reintentar con lo aprendido) pero como **escenario propio**, con relieve real (DEM) y la paleta del dossier.

**Directriz vigente del usuario:** la diversión y la claridad mandan; la fidelidad histórica es una guía. Pero: etiquetas honestas (nada inventado se presenta como documentado) y cero anacronismos groseros. Lo que el dossier marca como diseño va como diseño.

---

## 1. Pilares y promesa

**Promesa al jugador (una frase):** *Esta noche, con la lluvia, tenés unas 150 personas casi sin armas y un amanecer por delante: repartilas en tres partidas, tomá la batería, el cuartel y la pólvora de Humahuaca a la vez y sacá lo que el transporte aguante antes de que se arme la respuesta.*

| # | Pilar | Qué significa en el juego | Qué evita (lección del nivel 1) |
|---|---|---|---|
| 1 | **Tres frentes, un solo reloj** | El ataque dividido es simultáneo: batería, cuartel y pólvora corren a la vez, cada uno con su barra de toma, y la sorpresa dura 45 s desde la primera descarga. Las partidas se apoyan entre sí (Arias acude a Portal; las piezas de la batería voltean contra la torre). | Esperas sin decisiones: nunca hay un solo frente, siempre hay algo que atender. |
| 2 | **El terreno se lee y se usa** | La altura occidental da visión y tiro; las tapias y zanjas canalizan y ocultan; el barro cobra tiempo; el río es el borde de la salida. Todo sale de **una** grilla de relieve real más capas de diseño rotuladas. | Mapa «una parte definida y todo lo demás genérico y feo»; figuras que no se leen sobre el suelo. |
| 3 | **La noche protege pero ciega; el alba descubre** | Sigilo contra velocidad y oscuridad contra luz: andar en silencio es lento, correr hace ruido; la lluvia tapa el ruido y moja las armas de chispa (las de ellos también). **Atacar en plena oscuridad cuesta** (se pierde puntería, se pelea casi cuerpo a cuerpo, las partidas lejanas se coordinan tarde) y **esperar la luz también cuesta** (la guardia se desvela, la sorpresa se gasta): *cuándo dar la señal* es la decisión central. Información incompleta: se reconoce antes de atacar, y los informes pueden mentir. | Una receta fija ganadora («todos a su puesto y señal enseguida»): acá cada objetivo tiene al menos dos enfoques, el mundo cambia por variantes y el instante de la señal tiene un óptimo que se mide. |
| 4 | **No alcanza el transporte** | Tomar el depósito es la mitad. Hay más de lo que se puede llevar: se elige qué cargar, qué destruir y qué ocultar —y dónde—, mirando el reloj del refuerzo. «Los cañones no me atrevo a llevarlos» es una decisión, no un texto, y ningún tratamiento (cargar, destruir, ocultar) gana en todos los mundos. | Una victoria con inventario ilimitado; un final sin tensión; una cuenta fija que se resuelve de memoria. |
| 5 | **Perder enseña y reintentar es barato** | Mundo fijo hasta ganar, diario de lo aprendido, dos puntos de control, parte de derrota con causa, momento y lugar en una línea. | 94 hallazgos sin priorizar, bucles sin salida, arranque abrumador. |

**Principios transversales (de las lecciones del nivel 1, obligatorios):** una cosa clara por vez (objetivo en una línea y un solo «siguiente paso»); nada de jerga al arrancar (sin «ETA», «sondeo», «tag»); se lee de noche (fichas y marcadores de interfaz, no solo color de ropa); ninguna decisión estratégica depende de esperar sin hacer nada; el azar se anuncia o se compensa; nadie jugó a mano en el nivel 1, así que el nivel 2 mete **un agente-jugador que juega por la interfaz real** y un mini-playtest humano de 10 minutos al cierre de R1 y de R2b, y su veredicto máximo dice siempre «no certificado por humanos» hasta que una persona lo juegue 20 minutos (secciones 10 y 14).

---

## 2. Arco de la partida

Duración objetivo: **10 a 14 minutos de reloj a ×1** (victoria típica 11–13; derrota típica ≤ 8 para que reintentar sea barato; plazo duro a los 14:00). La **primera decisión llega antes de los 20 s, la primera revelación visible antes de los 40 s y la primera decisión significativa antes de los 60 s**; hay **una decisión significativa posible cada ≤ 45 s** (≤ 20 s durante el ataque). «Significativa» tiene una definición medible (sección 10): no cuenta una alerta con botón si todas sus opciones dan lo mismo.

| Fase (`phase`) | Reloj típico | Qué hace el jugador | Qué pasa |
|---|---|---|---|
| **Briefing** (`briefing`) | 0:00, en pausa; ≤ 30 s de lectura | Dos tarjetas: (1) objetivo en tres líneas; (2) **la carta de Güemes a Arias del 26 de febrero sobre Chacabuco, como dramatización** (nada de orden táctica) y el contexto del plan: «El golpe se preparaba desde febrero; la carta solo trae la noticia». Toca «Empezar». | Se muestra en una línea la **variante del mundo** de esta partida (por ejemplo «Hoy: la guardia está atenta»). La nota de fecha: «1 de marzo según el itinerario de Arias; el 2, según La Serna y una inscripción del premio» (◆). |
| **Apertura** (`briefing` → `aproximacion`; solo cámara) | 12–15 s de reloj de pared, **con el reloj de juego en 0:00**; se salta con cualquier tecla | Mira. | La cámara recorre los tres objetivos, cada uno con luz propia (brasero en la batería, ventana en la casa del cura, candil en la posta) y la frase de Arias como subtítulo («la mayor parte sin más armas que palos», ●); termina en la cámara inicial con los tres objetivos y la zona de partida a la vista. |
| **Aproximación nocturna** (`aproximacion`) | 0:00 a ≈ 4:30 (el alba) | Reparte las cinco agrupaciones desde la zona de partida del sudoeste; manda reconocedores; elige ritmo (silencio, marcha, correr) y ruta; **decide dónde dejar los caballos** de Rodríguez; lleva cada partida a su puesto de ataque; **elige cuándo dar la señal**. | Lluvia copiosa que afloja hacia el alba; visibilidad de 35 a 45 m (las luces, en cambio, se ven de lejos); centinelas; el informante; una patrulla que cruza el camino. La guardia **se desvela** desde las 4:30. Si nadie atacó a los 6:30, **amaneció**: derrota. |
| **Ataque dividido** (`ataque`) | desde la primera descarga (≈ 4:45–5:15) hasta tomar los tres objetivos (≈ 6:30–8:00) | Da la señal y lanza los tres frentes a la vez (las partidas que no llegaron atacan al llegar); reparte el apoyo; decide cuándo cargar, **entre qué descargas cruzar** y cuándo esperar. | **Ventana de sorpresa de 45 s**: desde la primera descarga, la alerta de cada frente sube de 0 a 1 en esos 45 s (25 s si la guardia está atenta) y el bono de sorpresa de quien ataca decae con ella (sección siguiente); el que llega tarde encuentra la guardia alerta y atrincherada. |
| **Resistencia y apoyo** (subestado `resistencia`, dentro de `ataque`) | mientras la torre tenga munición (≈ 90 s desde su primera descarga) o el frente más duro siga en pie | La torre del cuartel mantiene un fuego «indecible» sobre las calles, **con un anillo de recarga visible**: se la rodea por patios, se la silencia con las piezas de la batería, se la espera o se la carga **justo después de una descarga**. Arias deja la pólvora y **acude en apoyo de Portal**. | Cada decisión tiene costo: el que apoya deja custodia atrás (la posición tomada sin custodia se pierde); el que espera gasta el reloj del refuerzo. |
| **Extracción** (`extraccion`) | desde que el depósito está tomado (típico 7:00) hasta salir por el borde este (≈ 10:00–11:30) | Trae el arreo; elige **qué cargar, destruir u ocultar —y dónde—** con una capacidad limitada de mulas, mirando **el reloj visible del refuerzo**; decide qué hacer con los prisioneros; sale por el vado del este. | El refuerzo realista se acerca por el camino del sur con aviso visible; el río moja la pólvora; la columna cargada es lenta y vulnerable. |
| **Epílogo** (`epilogo`) | ≈ 60–90 s de lectura | Lee el parte de su partida y el epílogo fechado; ve la medalla; elige «Ver la campaña completa: Sostener el norte», «Jugar de nuevo» o «Menú». | Línea de fechas documentadas (sección 7), el contraste «en la realidad / en tu partida» (qué pasó con cada una de las 7 piezas) y la aclaración del tiempo comprimido. |

**La señal: la decisión central y sus contrapesos.** La señal se puede dar **apenas hay una partida en su puesto** («esperando la señal»); la interfaz avisa quién todavía no llegó («Portal todavía no llegó»). Las partidas que no llegaron atacan cuando llegan, con la guardia ya alerta. **Si nadie da la señal, las partidas esperan** (no atacan solas) y a los 6:30 amanece: derrota `amanecio`. Adelantarse y esperar cuestan distinto, y nada de esto es un multiplicador oculto (se muestra en la fase y en el parte):

- **Oscuridad** (`rules.stealth.dark_cost`; visibilidad < 100 m): el fuego propio pierde puntería (hasta ×0,4) y alcance útil (25 m en plena noche), el asalto pierde poder (hasta ×0,8: en la oscuridad se confunden amigos y enemigos) y el reconocimiento ve a 25 m en vez de 40. Con visibilidad < 60 m, el apoyo entre partidas separadas más de 150 m llega con demora (corre un mensajero: distancia ÷ 3,2 m/s). Todo se recupera linealmente hasta 100 m de visibilidad (≈ 5:00). Las armas de chispa del defensor también fallan (0,55): la noche **iguala**, no regala.
- **Desvelo** (desde `alba_start_s`, 4:30): la alerta de cada frente sube sola `0,004 × visibilidad ÷ 60` por segundo y el bono de sorpresa de quien ataca es `1 + 0,8 × (1 − alerta)` en lugar de un ×1,8 fijo. A las 5:30 el frente ya va por ≈ 0,4 de alerta y a las 6:00 está en alarma aunque nadie haya disparado.
- **La luz da y quita**: con visibilidad ≥ 100 m el atacante recupera puntería y **lee la guardia a < 60 m sin reconocer**, pero el defensor también ve más (detección sin el tope de 35 m: sección 5.2).

Con los valores de partida, un modelo de papel (potencia de asalto × bono de sorpresa) da un óptimo cerca de las 5:00 con una meseta de unos 30 s; adelantarse a las 3:00 rinde ≈ 30 % menos y esperar a las 6:00 ≈ 40 % menos. **Aceptación:** el barrido del instante de la señal de la sección 10 (compuerta 7) debe mostrar un máximo único dentro de una ventana ≥ 30 s que no sea el primer instante posible; si no lo muestra, se ajustan estos números (contenido), no se agrega un multiplicador global.

**Guion de eventos (cadencia garantizada).** Los eventos con elección **pausan solos** (pausa corta, nunca bloquean el reloj más de 25 s) y el juego **vuelve a ×1** cuando ocurre uno. Los tiempos son de partida a ×1.

| t (×1) | Evento (`field_event`) | Decisión o efecto |
|---|---|---|
| 0:00 | `apertura` | Cámara automática (reloj en 0). Primer cuadro jugable: los tres objetivos a la vista y **≥ 3 puntos de luz**. |
| 0:10 | «Siguiente paso» | Mandar a los reconocedores a mirar la altura o el pueblo (solo uno primero). **Primera decisión < 20 s.** |
| ≤ 0:40 | `recon_revela` | Los reconocedores llegan a 60 m de la batería (la luz de la guardia la delata) y se **revela** con un cono de luz y un sonido: «4 centinelas · 3 cañones». **Primera revelación ≤ 40 s.** |
| 0:45 | `informante` | Un vendedor de ganado que anduvo entre los realistas (como el de enero, [02]) da **dos informes** de fiabilidad desigual (≈ 75 %): elegís a cuál creer, **ya con algo visto para contrastar**. Define el segundo reconocimiento. |
| 1:00 | `lluvia` (info) | La lluvia arrecia: visibilidad 35 m; los pasos no se oyen. |
| 1:30 | `centinela` | Una patrulla cruza el camino: esperar, rodear (+25 s) o silenciarla (riesgo de ruido). |
| 2:15 | `tapia_hallada` / `zanja_hallada` | El reconocedor topó con un obstáculo: abrir portillo (ruido), trepar (lento) o rodear. |
| 3:00 | `caballos` | Si Rodríguez llegó al alto y no aseguró los caballos: ¿los deja con custodia o los lleva al asalto? |
| 3:30 | `aviso_alba` | Falta un minuto para las primeras luces: ¿ya están en sus puestos? ¿es hora de la señal? (pausa corta) |
| 4:30 | `alba` | Llega la primera luz: la visibilidad pasa de 60 a 140 m en un minuto, el ataque deja de perder puntería en la oscuridad y la guardia empieza a desvelarse. La señal se puede dar desde antes (ver arriba). |
| +0:00 | `primera_descarga` | Ventana de sorpresa de 45 s en cada frente (cuenta visible). La descarga «que pareció cañonazo» (●): temblor de cámara, trueno y «Viva la patria». |
| +0:15 | `artillero_viva_rey` | «Un ayudante de artillería que huía de la batería gritó “viva el rey” y un cabo patriota lo mató.» (información, ●) |
| +0:20 | `polvora_resiste` | «La guardia de la pólvora resiste: dos de los nuestros caen.» (información, ●) |
| +0:30 | `torre_fuego` | La torre abre fuego y aparece su anillo de recarga: cargar entre descargas, rodear por patios, pedir las piezas o esperar a que se le acabe la munición. |
| +0:45 | `mensajero` | Un jinete sale a galope al sur: perseguirlo con los caballos asegurados (si los hay) o aceptar un refuerzo 90 s antes. |
| +1:15 | `pide_apoyo` | Portal pide ayuda: Arias acude (deja custodia) o sigue con la pólvora. |
| ≈ +1:30 | `oficial_alcanzado` | «El oficial que corría a su cuartel fue alcanzado “a media cuadra”.» (información, ●) Si la pólvora ya cayó, el cuartel pierde 8 hombres de refuerzo. |
| ≈ 7:00 | `deposito_tomado` | Pasa a extracción; aparece el **reloj del refuerzo** («Refuerzo: entre 1:30 y 4:00», una banda que se angosta con la vigilancia); elección de prisioneros (llevarlos, atarlos o soltarlos). |
| 7:00–10:00 | `botin` | Por clase de carga: cargar, destruir u ocultar (sección 7). |
| llegada del refuerzo − 60 s | `refuerzo_visto` | «Polvareda al sur»: salir ya con lo que hay o cargar un poco más. |
| llegada del refuerzo | `refuerzo` | Combate de retaguardia; la columna que no salió pierde la carga. |

Las microescenas de información (el grito, los dos caídos de la pólvora, el oficial «a media cuadra») llevan ● solo en lo que el parte dice; el momento y el lugar donde ocurren en el mapa son ▲. En los mundos de guardia atenta, el briefing agrega «Algún pícaro avisó la noche» (● la acusación del parte, sin identificar a nadie).

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
| `vado_este` / `salida_este` | (862, 340) / (895, 332) | (+412, −15) / (+445, −7) | Salida de la carga; hacia San Andrés (ENE, sin traza ○). **El parte no dice por dónde salieron**: en pantalla se rotula «borde este (▲)» y no se fija la ruta final de Arias |
| `entrada_sur` | (540, 650) | (+90, −325) | Por donde llega el refuerzo desde Jujuy (▲ geometría; el refuerzo inmediato es ▲, ver sección 6) |
| `rio_grande` | polilínea de 14 puntos; entra en (572, 0), sale en (900, 406) | entra (+122,+325), sale (+450,−81) | Traza moderna (OSM, ODbL); lecho de 25–40 m (▲); solo el 8,4 % de la ventana queda al este del cauce |

**Terreno continuo hasta el horizonte** (crítica del usuario al nivel 1: «una parte definida y después todo genérico y feo»). Tres capas con **una sola** implementación de la altura (`HumahuacaTerrain`):

1. **Ventana** (900 × 650 m): grilla de juego de **4 m** (226 × 164 nodos) obtenida del DEM de 10 m **suavizado a 30 m** (el «relieve de juego»: con el DEM de Copernicus se van los techos y árboles de hoy; con la lámina no cambia nada) más las capas de diseño; es la que usan reglas (rutas, visión, velocidad), vista (malla y picking) y UI (minimapa).
2. **Contexto** (3 600 × 2 700 m, **el mismo dominio de la lámina 03**, centrado en la iglesia: `x ∈ [−1350, 2250]`, `z ∈ [−1025, 1675]`): grilla de 30 m (121 × 91). Es lo que se ve desde la altura: el valle, el río que sigue, las laderas que suben a ±120–185 m. Sin reglas.
3. **Horizonte**: anillo procedural hasta ±8 km que comparte los vértices del borde del contexto (sin grietas), con estratos claros tipo «cerros erosionados» (foto 1923, plano 6) y niebla de profundidad 1 500–6 000 m. La cámara de juego queda recortada a la ventana más 120 m.

**Nada liso, nada genérico** (la crítica del usuario, otra vez): (a) **micro-relieve** de semilla fija en toda la ventana (terrazas anisotrópicas de ±0,5 m como máximo y longitud de onda ≥ 25 m, de modo que la pendiente queda bajo 8° y no activa la regla de subida), rotulado ▲; (b) un **anillo de contenido de 0 a 400 m** fuera del núcleo —parcelas con tapias, sauces de ribera, ruinas de la capilla de Santa Bárbara (según el informe de enero ●, forma ▲), rocas, huellas de carreta— repartido con `MultiMeshInstance3D` según pendiente y humedad; (c) **el mismo shader de suelo** para ventana, contexto y horizonte. Se mide: en cada vista canónica y en la cámara inicial, con una grilla de 8 × 6, la baldosa con menos bordes tiene ≥ 40 % de la mediana y ninguna zona lisa ocupa más del 25 % del cuadro (sección 11.3).

**Reloj del escenario y visibilidad.** El tiempo se muestra por **fase**, no por hora ficticia: «Noche · Aproximación» → «Alba · Ataque» → «Mañana · Extracción». El dossier advierte que las horas del parte no se trasladan al reloj actual [md §D]. `environment()` entrega `{phase, time_of_day, rain, visibility_m, mud}`:

| Tramo (×1) | `phase` | Lluvia | Visibilidad a nivel del suelo | Efecto de juego |
|---|---|---|---|---|
| 0:00–3:30 | noche | 0,9 | 35 m | Los pasos no se oyen (ruido ×0,8); las armas de chispa fallan (fiabilidad 0,55, **para los dos bandos**); **oscuridad plena**: el atacante pierde puntería y poder de asalto (sección 2) |
| 3:30–4:30 | noche tardía | 0,8 | 45 m | idem, con menos oscuridad |
| 4:30–5:30 | alba | 0,5 → 0,2 | 60 → 140 m | La guardia ve más y **se desvela**; las armas de chispa mejoran (0,9); el atacante recupera puntería (plena a 100 m, ≈ 5:00) |
| 5:30+ | día | 0,1 | 300 → 600 m | Todo se ve; el barro queda (seca −0,01/s); la sorpresa ya está casi gastada |

(Lluvia durante la aproximación: ● solo la tarde del 27-II; la noche y el alba son ▲ «reconstrucción razonada» según el propio dossier. Un cálculo propio sin verificar con efeméride da luna casi llena esa semana: no se usa; la noche cubierta es diseño.)

---

## 4. Relieve con consecuencias de juego

**Principio:** el relieve no es decorado. Cada rasgo tiene una regla, una lectura visual y una etiqueta; todo sale de la **misma** grilla. **Declaración honesta:** *relieve real = base; relieve jugable = capas ▲.* Dentro de la ventana el terreno real sube apenas 25 a 38 m en 900 m (pendiente media de ≈ 1,6° a 2,4° a lo largo del gradiente; la máxima ronda los 3°): por sí solo no activaría ninguna regla de pendiente, visión o tiro. Por eso el juego suma **capas de diseño rotuladas** (el cerro de la batería, las explanadas de los objetivos, la barranca del cauce, la terraza del núcleo, el banco de grava, las quebraditas y un micro-relieve) y las dice como tales en `report()` y en pantalla. La base real da la forma amplia del valle; las capas dan las decisiones.

| Rasgo (dato de `relieve_mapa`) | Consecuencia en las reglas | Cómo se lee | Etiqueta |
|---|---|---|---|
| **Altura occidental** (cerro de Santa Bárbara): DEM base más un domo de diseño cuya **prominencia sobre el anillo de 120–150 m es de 12,0 m** (se calcula como residuo: lo que el DEM ya sube en ese lugar se descuenta, así que con cualquier fuente no hay «doble joroba»), con plataforma de 28 × 18 m en `bateria`; la superficie final queda ≈ 16–17 m sobre la plaza | **Visión:** desde la plataforma la línea de visión pasa sobre tapias de hasta 2,4 m y el radio de visión sube ×1,5; quien la tiene ve el núcleo entero. **Tiro:** desnivel ≥ 6 m → daño ×1,25 a favor del que dispara hacia abajo; ≥ 3 m → ×1,1. **Subida:** pendiente > 8° → velocidad ×(1 − 0,03·(grados − 8)), piso 0,6: atacar de frente por la ladera sudoeste cuesta tiempo y fuego. **Piezas:** tomada la batería se pueden voltear contra la torre (sección 6). | Ladera clara con arbustos oscuros y una tapia baja en diagonal (foto 1923, plano 1) | Relieve base ◇; domo y plataforma ▲ (los 12 m son del prototipo; el SRTM no los ve) |
| **Explanadas de los objetivos y de la plaza** (cuartel, posta, plaza; la de la batería es su plataforma) | Cada objetivo y la plaza tienen una plataforma de diseño a **altura fija respecto del templo** (cuartel +0,7 m, posta −3,0 m, plaza 0 m: valores de partida que se miden sobre el plan B y se congelan). Garantiza que los umbrales de tiro y visión entre objetivos no dependan de qué DEM se use | Suelo apisonado y nivelado | ▲ |
| **Barranca del cauce** (escalón de 3 a 5 m en la margen noroeste del Río Grande, con dos rampas en los vados) | Se baja y se sube por las rampas (los vados) o trepando (velocidad ×0,4); desde la cresta se ve el lecho y desde el lecho no se ve la cresta (corta la línea de visión); la columna cargada solo cruza por las rampas | Escalón de tierra con borde de grava | ▲ (el cauce de 1817 es ○) |
| **Terraza del núcleo** (escalón de 3 m entre la plaza y las manzanas del oeste, con dos escaleras de tierra) | Se pasa por las escaleras o trepando (×0,4); quien está arriba tiene ventaja de tiro (≥ 3 m: ×1,1) y corta la visión de la calle abierta; de acá sale el camino cubierto | Muro de contención bajo (talud) | ▲ |
| **Banco de grava junto al vado** (+1,2 m, 30 × 15 m) | Cobertura ligera (×1,15) para cubrir el cruce de la columna; drena (barro 0,9) | Montículo de grava clara | ▲ |
| **Tapias** (polilíneas de 1,8–2,4 m) | Bloquean paso y visión salvo portillos. Trepar: 6 s y ruido 0,4. Abrir portillo: 10 s y ruido 0,6, y queda abierto para todos. Una tapia **no reconocida** en la ruta obliga a rodear (+8 s) | Muro de tierra compactada con remate de paja | Existencia ● (el parte reconoce «tapial»); cantidad y posición ▲ |
| **Zanjas y acequias** (0,8–1,2 m de profundidad) | Velocidad ×0,5; el que está dentro se ve menos (visibilidad ×0,5 a 20 m). Una zanja no reconocida hace tropezar (3 s, ruido +0,3) | Franja oscura húmeda con borde de tierra | Existencia ● («zanjita»); posición ▲ |
| **Quebradita** (36 × 8 m, −2,5 m, abierta al oeste) | No se ve desde más de 40 m: **refugio de caballos** (hasta 60). Sin custodia, si pasa una patrulla a < 60 m la caballada se pierde | Hondonada con churqui | Existencia ● («en ese alto»); lugar ▲ ○ |
| **Río Grande** (traza moderna; lecho ancho y claro de 25–40 m; dos vados) | Borde NE y este de la ventana y **camino de la salida**. Cruzar: velocidad ×0,5; la **pólvora se moja** y pierde su valor salvo carga seca; «echar al río» destruye al instante lo que se tira. Caudal visible según la lluvia del mundo | Lecho claro entre monte ribereño (foto 1923, planos 4–5), agua turbia | Traza: dato moderno; cauce de 1817 y vados ○ |
| **Barro** (humedad por superficie × lluvia) | Velocidad: camino 0,9; suelo seco 0,95; sedimento húmedo 0,75; **irrigado 0,6**; charcos 0,5; seca despacio tras el alba | Suelo oscuro y brillante donde llovió; huellas | ▲ sobre lluvia ● (tarde del 27-II) |
| **Núcleo** (manzanas de 54 × 54 m, calles de 8 m; bocacalles cerradas con barricadas) | La calle abierta es rápida y queda a la vista de la torre; los patios por detrás de las tapias son lentos y ocultos. Las barricadas obligan a entrar por puntos | Casas bajas con azoteas y patios (foto 1923, plano 2) | ◇ sitio; planta ▲ |
| **Camino cubierto** (60 m entre el cuartel y la **gola** de la batería, al este) | Ruta de repliegue de los defensores: tomar la batería **primero** lo cierra, y el cuartel cae con más prisioneros; cortarlo evita refuerzos hacia la altura | Pasaje entre dos tapias altas | ◇ (Diario realista: «camino cubierto» entre la iglesia y el reducto) |
| **Micro-relieve** (terrazas anisotrópicas, ±0,5 m, onda ≥ 25 m, semilla fija) | Ninguna regla (la pendiente queda bajo 8°); evita el suelo liso y da sombras largas al alba | Ondulación fina del suelo | ▲ |

**Fuente del relieve.**

| Plan | Fuente | Estado | Qué se rotula |
|---|---|---|---|
| **A (recomendado)** | **Copernicus DEM GLO-30**, tesela `Copernicus_DSM_COG_10_S24_00_W066_00_DEM.tif` (**39 438 103 B**, MD5 `8c0aef1d66f4d1e918a25ff7864ecab3`), leída con Pillow + `receta_dem.py` ([04] §3–§4): ventana de 91 × 66 a 10 m y contexto de 121 × 91 a 30 m, centrados en el ancla. Es un modelo de **superficie** (trae techos y árboles de hoy, ±3–6 m en un pueblo): el builder lo suaviza con un filtro de 30–45 m | **Pendiente del permiso del usuario** (no se descargó nada) | «Relieve actual, Copernicus GLO-30 (modificado: remuestreo, suavizado y recorte); no restitución del suelo de 1817». Aviso de licencia (Art. 6 b y c) copiado literal de la licencia oficial a `docs/humahuaca/CREDITOS_RELIEVE.md` (que el integrador concatena en `docs/CREDITOS.md`) |
| **B (arranque sin permiso)** | Relieve **reconstruido de la lámina 03**: los 475 nodos de 25 × 19 a 150 m (`preparacion/01b_relieve_lamina03_nodos_25x19.csv`, ±10 m, 99,5 % de acuerdo con la lámina), interpolación bicúbica a 30 m y 10 m | Disponible hoy; **R1 arranca con este plan y no espera nada** | «Relieve reconstruido de la lámina 03 (±10 m)» |
| C (pedido aparte) | SRTM 30 m por la API pública de OpenTopoData (solo viajan coordenadas; 61 + 111 pedidos) | Pendiente de permiso | «SRTM 30 m (NASA/USGS)» |
| D | Los datos de relieve del paquete del usuario, si llega | Pendiente | A definir |

Cambiar de plan **no cambia el esquema** (`humahuaca_height.json`, ver el contrato): `tools/build_humahuaca_terrain.py --source lamina03|copernicus|opentopodata` regenera el archivo y `meta.source` cambia. Prohibido Google Elevation. **Una fuente tardía no debe mover el juego:** `test_hx_terrain` corre una prueba A/B (con la fuente nueva en un archivo temporal) que exige que (a) la diferencia de cota entre los tres objetivos cambie ≤ 1 m (las explanadas de diseño la fijan), (b) la curva de 2 960 m se mueva ≤ 15 m en z = 0, 325 y 650, (c) el signo del gradiente oeste → este se conserve y (d) la prominencia de la batería siga en 12,0 ± 0,5 m. Con el plan A, además, `verificar_dem_vs_srtm.py` (error medio < 12 m) corre una vez.

**Resolución, extensión y las dos cifras de variación.** DEM de ventana a 10 m (interpolación, no detalle nuevo; con 30 m nativos son ≈ 32 × 21 muestras reales dentro de la ventana, y con el plan B ≈ 35 nodos); malla de juego de 4 m; contexto a 30 m. **Dos cifras, una explicación:** la lámina 03 (SRTM de 90 m en 475 nodos de 150 m, ±10 m) da **25 m** de rango dentro de la ventana (2 946–2 971) y la grilla de prueba de OpenTopoData del informe [04] (SRTM de 30 m) da **38 m** (2 941–2 979); la diferencia de 13 m es resolución (los 30 m ven el pie del cerro y los 90 m lo promedian) más el error vertical de cada producto (±10 m y ±16 m al 90 %), no una contradicción. El juego usa la lámina hasta tener un DEM mejor, y todas las reglas están escritas para que **ninguna dependa de cuál de las dos cifras es la cierta** (para eso están las capas de diseño). Una única curva de 2 960 m cruza la ventana casi norte–sur: de (270, 0) a (366, 325) a (380, 650). **Política vertical:** exageración 1,0 en la lógica; si en R2a el relieve se lee plano, se admite un factor ≤ 1,5 **solo del componente DEM** (`relief.exaggeration` en `humahuaca_map.json`), aplicado dentro de `height_at` (reglas, vista y picking lo ven igual) y rotulado ▲. Nunca solo en la vista.

**Verificación contra la lámina 03.** El test `tests/test_hx_terrain.gd` evalúa el **DEM sin capas de diseño** en los **41 puntos** de la tabla de [01] §d.7 (convertidos con `lamina_to_game`): al menos **37 de 41** a ≤ 12 m de la estimación, **ninguno** a > 20 m, y **todos** dentro de la banda de color ±8 m; además `report()` lista qué capas son diseño (domo y explanadas, barranca, terraza, banco, quebraditas, micro-relieve, zanjas, tapias, barro) y el error medio contra los nodos. Otras comprobaciones: la curva de 2 960 m pasa por (366, 325) ±15 m y la de los tres bordes (z = 0, 325, 650); el signo del gradiente oeste → este (el oeste es más alto que el este en ≥ 10 m en z = 325); el cauce en z = 325 está a x = 859 ±5 m; el núcleo queda más bajo que la plataforma y el cauce más bajo que el núcleo; cada acceso llega a cada objetivo por la rejilla de navegación; tiempo de horneado < 300 ms. **Consecuencias del relieve (que las capas no sean decorado):** ≥ **2,5 %** de las celdas de la ventana con pendiente ≥ 8° (el flanco del domo aporta ≈ 1,9 %; la barranca, la terraza y las quebraditas, el resto) y **≥ 3 rasgos verticales** (domo, barranca, terraza, banco o quebradita) para los cuales existe un par de puntos cuya `los()` o cuyo `speed_factor_at()` cambia con y sin el rasgo.

---

## 5. Agrupaciones del jugador, acciones e información

**Quién se controla** (decisión D7): **coordinación de cinco agrupaciones**; no hay protagonista inventado. Güemes **no** está entre ellas: conduce desde Salta y solo aparece en el briefing (la carta del 26-II) y en el epílogo (recibe el parte) [md §H, §L]. Arias es la tercera división, no un héroe individual.

### 5.1 Las cinco agrupaciones

| Tecla | Id | Nombre visible | Quién (histórico) | Hombres · fuerza | Armas | Rol y habilidad propia | Partida (x, z) |
|---|---|---|---|---|---|---|---|
| 1 | `rodriguez` | Partida de Rodríguez · la altura | capitán Hilario Rodríguez, 1.er trozo; «dejando sus cabalgaduras en una quebradita que está en ese alto» ● | 48 · 100 | 25 % fusiles; el resto palos y sables | **Batería.** Parte **montada**; puede **asegurar los caballos** | (70, 470) |
| 2 | `portal` | Partida de Portal y Ontiveros · el cuartel | teniente Manuel Portal, con el alférez Ontiveros; Portal fue prisionero en Humahuaca y se fugó ● | 52 · 100 | 30 % fusiles | **Cuartel.** **Conoce las calles** ◇: arranca con la calle de entrada del cuartel y la barricada sur ya reconocidas | (110, 580) |
| 3 | `arias` | División de Arias · la reserva | Manuel Eduardo Arias, «tercera división protectora para todos los lances» ● | 50 · 100 | 35 % fusiles | **Pólvora (posta).** Es la **reserva**: puede acudir a cualquier frente; al tomar una posición deja **custodia** | (260, 625) |
| 4 | `reconocedores` | Reconocedores | el reconocimiento «en persona» de «tapial, zanjita» ● (léxico de época: «bomberos») | 2 | pistolas | **Reconocer**, hacer ruido, vigilar el sur | (230, 480) |
| 5 | `arreo` | Arreo · mulas de carga | arrieros y mulas; el parte captura 16 mulas ● | 6 arrieros · 6 mulas (600 kg) | — | **Traer, cargar, destruir, ocultar, salir** | (60, 625) |

Los reconocedores parten **más cerca de la altura** (a ≈ 160 m de la batería, en el borde norte de la zona de partida) para que la primera revelación llegue antes de los 40 s. Total de combatientes: **150** (cifra de Arias ●; el Diario del Estado Mayor realista dice 300 ◆). **El reparto 48/52/50, los porcentajes de armas y las mulas propias son ▲** (el parte solo dice «la mayor parte sin más armas que palos» y que reunió «tres trozos» a una legua del pueblo). Las cifras se muestran como «≈ 50 hombres» y barra de fuerza relativa.

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

Ejemplo de la tensión: cruzar 300 m de ladera en silencio lleva ≈ 150 s (190 s con barro) y llega antes del alba por poco; a la carrera lleva 60 s pero a 84 m de distancia ya te ven. La luz (≈ 4:30) es el reloj que obliga a elegir, y la señal es el momento de elegir (sección 2).

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
| 9 | **Reconocer** (`recon`) | reconocedores | hasta 3 puntos; riesgo estimado % de que los vean | Revela guardia (cuántos y cómo están), tapias, zanjas, centinelas y la torre en una franja de 40 m (25 m en plena oscuridad; **60 m si el objetivo tiene luz propia**: la luz delata a la guardia); la revelación se ve (cono de luz y texto «4 centinelas · 3 cañones») y suena; antes de ordenar se muestra el riesgo | ● el hecho |
| 10 | **Hacer ruido** (`decoy`) | reconocedores | 8 s a ≥ 120 m del frente | La guardia de ese frente mira hacia allá (alerta −30 %; **−45 % si la guardia está atenta**, que mira más al ruido, pero dura 20 s menos); la alerta global sube 0,1; pueden descubrir al reconocedor. Los reconocedores son dos: **una distracción por vez** | ▲ |
| 11 | **Vigilar el sur** (`watch`) | reconocedores | quedarse en un punto alto | Avisa el refuerzo 60 s antes y ve al mensajero | ▲ |
| 12 | **Traer el arreo** (`bring`) | arreo | viaje a ritmo de mula | Lleva las mulas al patio de la posta | ▲ |
| 13 | **Cargar** (`load`) | arreo | 12 kg/s por equipo de 6 hombres (hasta 3 equipos) | Sube una clase de carga a las mulas; pólvora sin protección se moja al cruzar el río | ● el hecho / ▲ pesos |
| 14 | **Destruir** (`destroy`) | arreo / grupo | pólvora: quemar 20 s (humo a 300 m, explosión a 25 m) o echar al río (solo a ≤ 40 m del cauce); cañones: clavar 10 s c/u | Quita el valor al enemigo: vale **×0,35** de su puntaje (ver sección 7); quemar tiene un **costo real**: el humo se ve a 300 m y adelanta la llegada del refuerzo 20 s la primera vez y 10 s cada vez siguiente (tope 40 s) | ● la munición («dar al fuego y echar al río»); ▲ clavar cañones y tirar víveres |
| 15 | **Ocultar** (`hide`) | arreo / grupo | enterrar 25 s por pieza, lejos del camino | Vale **×0,7 si queda a salvo** y ×0 si el refuerzo lo halla (escondite a < 150 m del camino sur o de la posta); hay tres escondites con distinta distancia al camino (más lejos = más traslado); el epílogo dice qué pasó con cada pieza | ◆ (Diario realista: «ocultos o enterrados») |
| 16 | **Salir por el este** (`leave`) | arreo / grupo | cruzar el vado ×0,5 | La carga que cruza se **entrega**; sale del mapa | ● el hecho / ▲ lugar |
| 17 | **Soltar la carga** (`drop`) | arreo | — | Abandona lo que carga para huir (emergencia) | ▲ |
| 18 | **Dar la señal** (`give_signal`) | global | abre la ventana de sorpresa de **todos** los frentes (alerta 0 → 1 en 45 s) | La «descarga que pareció cañonazo»: lanza a todas las partidas en espera. Se puede dar apenas hay una partida en su puesto; **sin ella las partidas esperan** y a los 6:30 amanece (derrota). Cuándo darla es la decisión central (sección 2) | ● la descarga / ▲ la señal general |
| 19 | **Retirada general** (`retreat_all`) | global | 2 clics (desde el menú de pausa) | Termina como derrota ordenada | ▲ |
| 20 | **Cancelar** (`cancel`) | todos | — | Anula la orden en curso (Ctrl+Z deshace la última) | — |

**Qué entra en cada ronda.** R1 trae **9 acciones**: `move` (con ritmo), `position`, `give_signal`, `attack` (con postura), `support`, `recon`, `load`, `destroy` y `leave`, más `hold` automática al tomar y `cancel` con Esc (el arreo llega a la posta con `move`). R2a suma las demás: `secure_horses`, `breach`, `retreat`, `decoy`, `watch`, `bring`, `hide`, `drop`, `retreat_all` y el deshacer. Las 20 existen antes del cierre de R2a.

**Información incompleta y ruido.** (a) **Niebla de reconocimiento:** al principio los frentes muestran «?» en guardia y postura; reconocer los resuelve; sin reconocer, la barra del enemigo es una franja ancha (el rango que dan los informes). (b) **Informes:** el informante da dos afirmaciones (por ejemplo «la pólvora está en la posta» / «la torre es la del templo»), cada una con fiabilidad ≈ 75 %; el mundo guarda cuáles eran ciertas y el **diario** lo anota en el parte. (c) **Ruido** de las acciones propias (disparos, portillos, caballos) que el enemigo oye. (d) Lo no reconocido en la ruta (tapias, zanjas) cobra tiempo y ruido al toparse. **En R1 la geometría es toda conocida** (no existe aún la doble capa «lo que sabés / lo real»; solo la guardia y la postura de cada frente están ocultas hasta reconocer); la doble capa entra en R2a.

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
| **Batería** (`bateria`) | 24 artilleros, 3 piezas de a 4 | Parapeto y foso ×1,6; la **gola** (entrada trasera) mira al **este**, hacia el camino cubierto y el núcleo, y está abierta (orientación ▲: el parte no la dice, pero un camino cubierto «que protegiese la retirada» de la altura hacia el pueblo ◇ implica la gola hacia el pueblo) | 2 centinelas («alertas a porfía») | Las piezas barren las laderas **oeste y sur**, por donde llega el atacante (alcance 300 m, ×1,5 contra quien sube de frente). Girarlas hacia atrás lleva 15 s: **por la gola se las toma de espalda (×0,5)**, pero a la gola se llega **desde el pueblo y bajo la torre**: el flanqueo es largo y caro, no un atajo, y distraer a la guardia abre una tercera vía |
| **Cuartel** (`cuartel`) | 56 fusileros en la casa del cura **+ 10 tiradores en la torre** | Muros aspillerados ×1,5; torre ×2 | 1 centinela en la puerta | **La torre** abre fuego en cuanto se arma: 12 s después de la alarma si la guardia está descuidada, al instante si está atenta; 12 descargas de 7,5 s (≈ 90 s; **anillo de recarga visible**), radio de 90 m con línea de visión sobre tapias; ángulo muerto de 12 m al pie, **marcado en el mapa** |
| **Posta** (`posta`) | 22: 12 guardianes del polvorín y 10 de servicio | Muros de 2,4 m ×1,3 | 1 centinela en la entrada principal | «Resistencia de ordenanza»: el primer minuto mata a 2 de los nuestros; un **oficial** que sobrevive 15 s tras la alarma corre al cuartel y le suma 8 hombres |
| **Patrullas** | 8 en 4 recorridos | — | — | Detectan por ruido y visibilidad |
| **Camino sur** | 8 y un **mensajero** | — | — | El mensajero sale a los 40 s de la alarma si nadie lo corta |

**Variantes del mundo** (una por dimensión activa, sorteadas con la semilla y fijas hasta ganar; encarnan las incertidumbres que el dossier declara sin resolver [md §M] y siempre se rotulan ▲). **Se empieza con 3 dimensiones y se suma otra solo si invierte al menos un mejor enfoque** (prueba de inversión en R3). En R1 el mundo es **fijo** (guardia descuidada, torre en la casa del cura, refuerzo normal).

| Dimensión | Valores | Activa desde | Qué cambia |
|---|---|---|---|
| `guardia` | `descuidada` / `atenta` | R2b | Descuidada («con algún poco más de descuido», ●): detección ×0,8, ventana de sorpresa de 45 s, torre armada 12 s después de la alarma. Atenta («el traidor avisó», ●; la guardia «lo había esperado noches antes»; el briefing agrega «Algún pícaro avisó la noche»): detección ×1,25, patrullas +50 %, ventana de sorpresa de 25 s, torre armada desde el inicio y el bono de sorpresa sobre el cuartel parte de ×1,3 en vez de ×1,8 |
| `torre_en` | `templo` / `casa_cura` | R2b | Lugar de la torre ○ (el parte no la identifica): cambia el ángulo muerto, qué calles barre y la ruta de apoyo (matriz de abajo) |
| `refuerzo` | `temprano` / `normal` / `tardio` | R2b | Demora del refuerzo desde la primera descarga: 240 / 300 / 360 s |
| `refugio` | `norte` / `sur` | candidata (hoy `sur`) | Cuál de las dos quebraditas existe |
| `lluvia` | `copiosa` / `garua` | candidata (hoy `copiosa`) | Copiosa: visibilidad −15 %, fiabilidad de armas de chispa 0,55; garúa: +15 % y 0,70 |
| `layout` | `A` / `B` | candidata (hoy `A`) | Dos disposiciones de tapias, zanjas y barricadas |

3 dimensiones activas = **12 mundos de combate**. Una línea del briefing dice las variantes ya conocidas («Hoy: guardia atenta, refuerzo temprano»); el resto se descubre reconociendo. Las otras tres dimensiones pasan a activas **solo** si una prueba de inversión (un enfoque que no era el mejor en ningún mundo pasa a serlo al sumarla) lo justifica.

**Rasgos del botín del mundo** (no son variantes de combate; se descubren al reconocer o al tomar la posta, y cambian solo la extracción; todos ▲): `corral` completo o desbandado (16 o 10 mulas capturables: capacidad total de 2 200 o 1 600 kg), `plata` presente o ausente (3 cargas, ◆), `polvora` seca o húmeda (el techo del polvorín goteó: húmeda vale ×0,2 salvo que se la seque, +10 s por carga; 1 de cada 3 mundos). 8 combinaciones por mundo de combate; el sorteo sale de la misma semilla.

**Matriz de contrapesos (se escribe antes del código y se prueba por signo).** Costo de un enfoque en un frente = bajas del frente (%) + segundos hasta tomarlo ÷ 6; la base de cada enfoque es 100 salvo donde se indica, y cada celda es el multiplicador de esa variante (vacío = ×1,00). Son valores de partida (▲); lo que se exige es el **signo** y que ningún enfoque sea el mejor siempre.

| Enfoque (costo base) | Guardia atenta | Guardia descuidada | Torre en la casa del cura | Torre en el templo | Refuerzo temprano | Refuerzo tardío | Por qué |
|---|---|---|---|---|---|---|---|
| Batería · **frontal** (100) | ×1,15 | ×0,90 | | | ×0,92 | | Cañones apuntados con guardia atenta; con apuro, lo rápido gana |
| Batería · **gola** (85) | ×1,25 | ×0,90 | ×1,30 | ×0,90 | ×1,12 | ×0,95 | Se entra por el pueblo y bajo la torre; patrullas +50 % con guardia atenta; lento si el refuerzo apura |
| Batería · **distracción** (90) | ×0,80 | ×1,10 | | | ×1,08 | | La guardia atenta mira más al ruido; la descuidada no reacciona. Cuesta a los reconocedores (una distracción por vez) |
| Cuartel · **calle** (100) | ×1,10 | ×0,90 | ×1,25 | ×0,80 | ×0,92 | | Calle abierta a la vista de la torre; el edificio del cuartel tapa a la torre del templo |
| Cuartel · **patios** (90) | ×1,20 | ×0,90 | ×0,80 | | ×1,10 | | El ángulo muerto al pie de la torre cae sobre el cuartel; patrullas en los patios; lento |
| Cuartel · **piezas** (80; exige la batería) | ×0,90 | ×1,10 | | ×1,10 | ×1,15 | ×0,90 | Las piezas hacen el trabajo a distancia; el armado lleva tiempo |
| Posta · **directa** (100) | ×1,20 | ×0,85 | | | ×0,95 | | Asalto a la entrada contra guardia atenta cuesta; con descuido y apuro, gana |
| Posta · **con distracción** (85) | ×0,90 | ×1,10 | | | ×1,10 | | Distraer el corral abre la entrada, pero tarda |

Con estos valores el modelo de papel da el mejor enfoque por mundo así: batería = gola en 3 de los 12 mundos, frontal en 3, distracción en 6; cuartel = calle en 4, patios en 3, piezas en 5; posta = directa en 6, distracción en 6. **Ningún enfoque es el mejor en más de la mitad de los mundos y cada uno lo es en al menos 3.** El modelo no certifica nada; lo certifica `test_hx_rules` (sección 10): (1) en ≥ 90 % de los 24 mundos de la compuerta, el costo medido de cada celda se mueve en el sentido de la tabla al cambiar solo esa variante; (2) cada enfoque es el mejor, por puntaje continuo (golpe − 0,5 × bajas), en ≥ 1 de los 12 mundos; (3) el experto no puede distraer dos frentes a la vez. Si una celda no se sostiene, se corrige el **contenido** (el valor de la celda o la regla que la origina), no un multiplicador global.

**Reacción de los defensores.** Estados del frente: `guardado` → `alertado` (alerta ≥ 0,5) → `en_alarma` (alerta = 1) → `asaltado` → `tomado`. En alarma: cobertura ×1,25 (se atrincheran); el cuartel abre la torre; el oficial de la posta corre al cuartel; el mensajero sale. Si el **camino cubierto** está abierto, los defensores del cuartel que pierden se **repliegan** hacia la batería (el Diario realista cuenta que fueron «acuchillados dentro de las mismas calles», ◇); si la batería ya cayó, se rinden: **tomar la batería primero cierra el repliegue y rinde más prisioneros**. Una posición tomada sin custodia se pierde.

**La torre que resiste** (consecuencia jugable de «se subieron a la torre ... fuego indecible de 5:00 a 6:30», ●; el parte habla de unos 90 **minutos** de fuego y el juego los comprime a ≈ 90 **segundos** de cadencia: la compresión se declara en el epílogo). Mientras tenga munición dispara **una descarga cada 7,5 s** contra toda partida con línea de visión a ≤ 90 m (daño ×2 sobre quien está en la calle abierta, ×0,5 si está detrás de tapia, ×0,3 a quien cruza corriendo); su **anillo de recarga** se ve sobre la torre y en el panel, y el ángulo muerto de 12 m al pie es donde se refugia quien llega. **La cadencia es una ventana de cruce:** salir a la calle justo después de una descarga y llegar al ángulo muerto antes de la siguiente cuesta poco; el experto lo hace en ≥ 60 % de sus cargas sobre el cuartel (prueba de `test_hx_rules`). Cuatro respuestas: **(a)** rodear por patios y tapias (lento, necesita portillos o reconocimiento), **(b)** cargarla «a sangre y fuego» (rápido, caro salvo que se cronometre con la recarga), **(c)** **voltear las piezas** de la batería tomada (≈ 15 s y 3 de las 7 piezas; reduce el fuego de la torre ×0,4 por descarga durante 20 s; es el apoyo de Rodríguez a Portal ▲), **(d)** esperar a que se acabe la munición (el reloj del refuerzo corre). El fin del fuego de la torre ○ (el parte no lo cuenta) es diseño.

**Refuerzo (diseño).** Los realistas se enteraron el **4 de marzo** y mandaron tres columnas el 5–6 (●): **no hubo refuerzo inmediato**. El refuerzo del juego (40 infantes y 6 jinetes por `entrada_sur`, `refuerzo` demora desde la primera descarga, −90 s si el mensajero escapa, +120 s si lo cortan, aviso −60 s con `watch`) es un **recurso de diseño para dar tensión a la extracción** y se rotula ▲ en pantalla; el epílogo cuenta lo que pasó de verdad. **El reloj es visible:** desde que cae el depósito el HUD muestra «Refuerzo: entre 1:30 y 4:00» (una banda que se angosta con la vigilancia y con lo que se ve) y, cuando se lo ve venir, una cuenta regresiva; **quemar lo adelanta** (humo a 300 m: −20 s la primera vez, −10 s cada otra, tope −40 s) y cortar al mensajero lo atrasa 120 s. La tensión está en ese reloj y en qué dejar, no en una cuenta fija. Inspiración rotulada ◆: Güemes dijo haber visto pasar el 24-II «una división de 300 hombres» sin confirmación realista.

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
| **Cuartel** | Silencia la torre; rinde prisioneros | Fusiles (≈ 100), bandera del primer regimiento, plata (3 cargas, ◆, solo en algunos mundos), ornamentos; prisioneros |
| **Posta** | Polvorín, parque, corral | Pólvora y municiones (12 cargas), 3 piezas + 1 de a 2, víveres (30 cargas), **16 mulas** (+1 600 kg de capacidad; 10 si el corral se desbandó), ganado |

**Botín (valores de partida; suma 100 «puntos de golpe»).**

| Clase | Cantidad | Peso | Puntos | Notas |
|---|---|---|---|---|
| Pólvora y municiones (`polvora`) | 12 cargas | 100 kg c/u | 28 | Se moja en el río salvo carga seca (+10 s por carga); **húmeda de origen** en 1 de cada 3 mundos (vale ×0,2). Quemar: 20 s, humo visible a 300 m (adelanta el refuerzo), explosión a 25 m (pierde 40 de fuerza quien esté dentro) |
| Cañones (`canones`) | 6 de a 4 (400 kg) + 1 de a 2 (200 kg) ◆ | 2 600 kg | 28 (4 por pieza) | Cargar una pieza: 4 mulas y 60 s; clavar: 10 s (negación); ocultar: 25 s + traslado |
| Fusiles (`fusiles`) | ≈ 100 | 4 kg c/u | 10 | 4 cargas |
| Víveres (`viveres`: harina y aguardiente) | 30 cargas | 100 kg c/u | 12 | La peor relación valor/peso |
| Ganado (`ganado`: 2 000 ovejas y 60 vacas) | — | camina | 8 | 6 arrieros; ralentiza la columna ×0,75; se puede dispersar |
| Plata (`plata`) | 3 cargas, **solo en algunos mundos** | 100 kg c/u | 6 | Versión de oídas de Portal (Belgrano, 10-IV) ◆ |
| Prisioneros (`prisioneros`: 86 soldados y 7 oficiales) | 93 | caminan | 5 | 1 guardia cada 8; ralentizan ×0,8 |
| Bandera (`bandera`) | 1 | 5 kg | 2 | Del primer regimiento; «Pumacagua degollado» en una punta; paño sin completar ▲ |
| Ornamentos y misal (`ornamentos`) | 1 juego | 15 kg | 1 | Destinados a la Virgen de Humahuaca ●: se pueden devolver al templo |

**Capacidad.** 6 mulas propias (600 kg) + 16 del corral (1 600 kg) = **2 200 kg** (1 600 kg si el corral se desbandó: 10 mulas capturables, rasgo del botín del mundo), contra ≈ 7 500 kg de carga pesada: no alcanza (≈ 29 %) y eso **es** la decisión («por no tener cómo conducirlos», ●). Cada equipo de carga hace 12 kg/s. Lo que no se carga recibe uno de tres tratamientos (o se abandona):

| Tratamiento | Valor sobre los puntos de la clase | Tiempo | Costo y riesgo | Etiqueta |
|---|---|---|---|---|
| **Entregar** (cargar y cruzar el vado) | ×1,0 (pólvora mojada ×0,2) | 12 kg/s por equipo + viaje de ≈ 275 m a ritmo de mula + vado ×0,5 | Ocupa mulas; la columna es lenta (ganado ×0,75, prisioneros ×0,8) y se la puede interceptar | ● el hecho / ▲ cifras |
| **Destruir** | **×0,35** | Pólvora: quemar 20 s (humo a 300 m: adelanta el refuerzo 20 s la 1.ª vez y 10 s cada otra, tope 40 s) o echar al río (≤ 40 m del cauce, sin humo); cañones: clavar 10 s c/u; víveres: tirar 15 s | Explosión a 25 m; el humo avisa al enemigo | ● la munición; ▲ clavar y tirar víveres |
| **Ocultar** | **×0,7 si queda a salvo, ×0 si el refuerzo lo halla** (escondite a < 150 m del camino sur o de la posta) | 25 s por pieza + traslado al escondite (tres escondites: cerca, medio y lejos del camino) | El escondite lejano cuesta tiempo de traslado; el cercano lo encuentran. El epílogo dice qué pasó con cada pieza | ◆ (Diario realista: «ocultos o enterrados») |
| **Abandonar** | 0 (el enemigo lo recupera) | — | — | — |

Con estos valores no hay un tratamiento que gane siempre: **entregar** gana en lo denso (bandera, ornamentos, fusiles, pólvora seca, plata) mientras haya tiempo y mulas; **destruir** gana cuando el reloj del refuerzo aprieta o no hay escondite alcanzable; **ocultar** gana para lo pesado (cañones, víveres) cuando hay tiempo y un escondite a salvo, y pierde si el refuerzo pasa cerca. La pólvora húmeda, el corral desbandado y la plata ausente mueven el óptimo de un mundo a otro, y los 12 mundos de combate mueven el tiempo disponible (30 a 360 s entre la caída del depósito y la llegada del refuerzo). **Aceptación (R2b, compuerta 8):** con el experto como atacante y una receta de extracción fija por vez (`cargar_todo`, `destruir_todo`, `ocultar`, `ligera`, `mixta`), **ninguna receta gana en más del 60 % de los mundos** y `ocultar` es la mejor (por puntaje continuo) en **al menos un mundo**.

**Puntaje (`golpe`, 0–100):** `golpe = entregado × 1,0 + destruido × 0,35 + oculto a salvo × 0,7`. La carga solo cuenta si **cruza el vado** del este; lo interceptado vale 0, y lo oculto que el refuerzo halla también. El HUD muestra «Golpe» y tres chips (entregado / quitado al enemigo —destruido más oculto— / pendiente), nunca una planilla; el detalle con lo oculto aparte está en el parte. **R1 usa solo cinco clases** (`polvora`, `canones`, `fusiles`, `viveres`, `plata`) con puntos provisionales que suman 100 (30, 30, 14, 14 y 12) y un único tratamiento de cada clase (entregar o destruir); **R2a trae las nueve clases** con los puntos de la tabla, `ocultar` y el botín del mundo.

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
| 9 al 16 de marzo | **En la realidad:** una columna realista entra en el pueblo vacío y, según las fuentes realistas (el Diario del Estado Mayor y Camba; no el oficio de La Serna: H03, 2-11-2026), recupera **seis piezas** ocultas o enterradas cerca de San Andrés e inutiliza lo que no puede cargar «por falta de acémilas». **En tu partida:** lo que pasó con cada una de las 7 piezas (llevadas, clavadas, ocultas a salvo, ocultas y halladas, abandonadas), que sale de `campaign_report()`. | ◆ la línea histórica; ▲ la de tu partida |
| Abril | Belgrano manda hacer medallas para los de Humahuaca; el premio se concede después del combate, no antes. | ● |
| 6 de julio | Un oficial realista cuenta «la sorpresa de Humahuaca» entre las causas de la retirada del ejército del rey: la retirada tuvo muchas causas. | ● versión realista |
| Marzo a mayo | La resistencia continúa. Botón **«Ver la campaña completa: Sostener el norte»** (1816–1817, desde Salta: Humahuaca es una de sus operaciones; no es la continuación del nivel II). | ● |

Güemes recibe el parte en Salta (**no** estuvo en el asalto, ●) y San Martín es contexto (Chacabuco, 12-II): ninguna línea dice que ordenó este golpe. El nivel **no** cierra como expulsión definitiva. **Tiempo comprimido (se dice en el epílogo):** «En la realidad la marcha duró unas 26 horas y el fuego desde la torre, hora y media; el juego los reduce a minutos». La salida «por el este» es una abstracción del borde del mapa (▲): el parte no dice por dónde salieron.

---

## 8. Aprendizaje entre intentos

Heredado de la Justina porque **funcionó** (mundo fijo, diario, punto de control, derrota que enseña, ayudas visibles) y reescrito en archivos propios: `scripts/humahuaca/rules/humahuaca_progress.gd` y `user://humahuaca_progress.json`. **No** se agrega nada a `campaign.json` (descarta lo que no conoce y se reinicia si `version != 1`).

- **Mundo fijo hasta ganar.** La semilla (`world_seed`) y por lo tanto las variantes activas y los rasgos del botín de la sección 6 se mantienen entre intentos y entre sesiones. «Mundo nuevo» (con confirmación) las vuelve a sortear; al ganar, el mundo se re-sortea solo («Jugar de nuevo: otro mundo»).
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
- **Condición para pasar al nivel siguiente y candado (decisiones D1a y D1c).** Ganar (cualquier medalla) registra `won = true`. **El botón de Humahuaca queda siempre habilitado** y, mientras el perfil no haya ganado la Justina, lleva la nota «Recomendado tras la Justina» (una línea en `_menu`; el candado del Norte **no se toca**): la Justina no está certificada y un candado detrás de ella dejaría sin probar el nivel nuevo. `--scenario=humahuaca` lo abre directo, como `--scenario=norte`. El epílogo de la victoria ofrece **«Ver la campaña completa: Sostener el norte»** (la campaña de 1816–1817 vista desde Salta; Humahuaca es una de sus operaciones, así que **no se afirma que el nivel III continúe al II**) y registra `won` por si más adelante se reencadena (D1b: Justina → Humahuaca → Norte, que cuesta reescribir 6 comprobaciones fijadas: contrato, sección 4). No hay puente de estado hacia el Norte.

---

## 9. Onboarding de 30 segundos y lenguaje

**Objetivo en una frase (siempre visible, una línea):** *«Tomá la batería, el cuartel y la pólvora a la vez, y sacá lo que puedas antes del refuerzo.»*

| Reloj de juego | Qué ve el jugador | Control |
|---|---|---|
| antes de 0:00 | Pausa automática y **una tarjeta de tres líneas**: el objetivo, «perder no es grave: volvés a intentar con lo que aprendiste» y el botón **Empezar**. Una segunda tarjeta (saltable) con la carta del 26-II como dramatización y la nota de fecha. Después, la **apertura** de 12–15 s (cámara por los tres objetivos con su luz propia; se salta con cualquier tecla). | Empezar |
| 0:00–0:15 | Flecha sobre los reconocedores y el texto **«1. Mandá a los reconocedores a mirar la altura»** (tecla 4 y clic derecho en el cerro). El resto de la interfaz queda atenuado. | Reconocer |
| 0:15–0:40 | La **revelación**: cono de luz sobre la batería y «4 centinelas · 3 cañones» (con sonido). Después, **«2. Llevá cada partida a su puesto»** (teclas 1, 2, 3 y «A su puesto»). Una sola acción sugerida por vez. | A su puesto |
| 0:45–1:00 | Tarjeta del informante, **con algo ya visto para contrastar**, y la primera elección significativa (**antes de los 60 s**). | Elegir |

**Qué se oculta al inicio:** panel de carga y botín (hasta la extracción), diario, puntaje, «Retirada general» (menú de pausa, 2 clics), leyenda del minimapa, barra del enemigo (muestra «?» hasta reconocer) y las etiquetas de fuente (aparecen al seleccionar). **Métricas de arranque** (se miden en el primer cuadro jugable, `test_hx_flow`): **≤ 5 controles accionables** (pausa y velocidad cuentan como uno, ayuda y menú como uno, la barra de acciones muestra ≤ 3), **≤ 400 caracteres** de texto de juego, **0 términos** de la lista negra, **0 identificadores** (palabras en snake_case) en texto visible, una línea de objetivo y un solo «siguiente paso». **Prueba con el agente-jugador** (sección 10): llega a su primera orden útil en ≤ 40 s de juego.

**Tutorial de 6 pasos** (**entra en R3**; hasta entonces hacen de tutorial la flecha, el «siguiente paso» y la tarjeta de arranque; saltable, una vez por perfil, se repite con F1): (1) *Reconocer*: mandar a los reconocedores; (2) *A sus puestos*: cada partida a su lugar; (3) *La señal*: cuándo atacar (la oscuridad cuesta, y esperar la luz también); (4) *Los tres a la vez*: atacar los tres frentes dentro de la sorpresa y apoyar; (5) *Cargar el arreo*: qué llevar, qué destruir; (6) *Salir por el este*: cruzar el vado antes del refuerzo. Cada paso se marca solo cuando el jugador lo cumple.

**Ayuda F1** (R3; hasta entonces, un botón «?» con las 6 líneas de «cómo se juega»): una página con el objetivo, cómo se juega (6 líneas), la tabla de teclas de `docs/humahuaca/CONTROLES.md`, un glosario sin jerga, qué significa cada una de las cinco etiquetas y la nota de fecha.

**Lenguaje.** Se usan: *reconocer, puesto, señal, alba, guardia, sorpresa, alerta, ruido, toma, carga, golpe, refuerzo, arreo*. **Lista negra cerrada y explícita** (`humahuaca_ui.json.jargon_blacklist`; la verifica un test sobre **todas** las cadenas visibles de los JSON y de la interfaz): *siglas* (se distinguen mayúsculas y se busca la palabra completa): ETA, ZOC, LOS, DPS, HUD, FPS; *palabras* (sin distinguir mayúsculas ni tildes, palabra completa): sondeo, sondear, tag, aggro, buff, fog, spawn, waypoint, pathfinding, snapshot, hash, seed, payload, cooldown; e *identificadores*: cualquier palabra en snake_case, o clave de `hud_state`/`render_state` escrita como identificador, dentro de un texto visible. El artículo «los» **no** es la sigla LOS: por eso las siglas distinguen mayúsculas y los textos visibles **no se escriben enteros en mayúsculas** (los rótulos de menú que fija el gancho de `main.gd` no pasan por este test). Palabras de juego que también son claves de estado (*alerta, toma, ruido, guardia, alba*) **están permitidas** como palabras. Aceptación: el briefing completo y los 20 textos de acción pasan sin excepciones. Un solo mensaje guía a la vez (aviso, alerta o toast con prioridad); pausa automática **corta o nula** salvo decisiones; el ×2 se sugiere en esperas tranquilas y **nunca cambia solo**.

---

## 10. Balance: qué se garantiza y qué solo se informa

**Honestidad primero.** En el nivel 1 nadie jugó: «humano promedio» era un modelo inventado, los bots solo ganaban con información perfecta, las perillas globales movían al novato y al experto juntos y las metas eran bandas de tasa que ni con 14 semillas se podían verificar (4 victorias de 12 tienen un intervalo de Wilson al 90 % de 16 a 57 %). Acá: (1) las **compuertas** usan solo lo que se puede medir con las semillas y el tiempo que hay —**extremos** (el experto gana, el pasivo pierde) y **señales de contrapeso** (el signo de cada efecto, un máximo único, una receta que no domina)—; (2) todo lo que depende de un modelo de jugador (**obediente** y **torpe**) es **informe con intervalo**, nunca compuerta ni hallazgo de bloqueo; (3) se mueve **contenido** (enfoques, variantes, ayudas visibles, cifras de las reglas), no multiplicadores globales; (4) los números del modelo **no certifican nada** sin una persona: lo máximo que firma el circuito es «presentable, no certificado por humanos».

**Compuertas de ronda** (cada una dice quién la mide y desde cuándo; las 24 semillas de la compuerta y las demás listas están en «Método»):

| # | Compuerta | Umbral | Cómo se mide | Desde |
|---|---|---|---|---|
| 1 | **Experto** (conoce el mundo; ejecuta el mejor plan de su familia) | gana ≥ **90 %** al 1.er intento en las 24 semillas | `tools/humahuaca_playthrough.gd` | R1 (mundo fijo) |
| 2 | **Pasivo** y «solo pausa y reanuda» | pierden en el **100 %**, todos por `amanecio` | ídem | R1 |
| 3 | **Ciegos** (todos atacan sin reconocer, ataque tarde, un solo frente, sin arreo) | ≤ **5 %** | matriz de estrategias | R2b |
| 4 | **Gradiente, no acantilado** | las estrategias parciales (un frente sin apoyo, sin arreo, sin custodia) ganan **menos y más caro**, no 0 o 100 | matriz | R2b |
| 5 | **Contrapesos con signo** | cada celda de la matriz de la sección 6 se mueve en el sentido previsto en ≥ 90 % de las 24 semillas | `test_hx_rules` | R2b |
| 6 | **Cada enfoque tiene su mundo** | cada uno de los 8 enfoques de frente es el mejor (puntaje continuo `golpe − 0,5 × bajas`) en **≥ 1 de los 12 mundos de combate**, y ninguno es el mejor en más de la mitad | matriz de 8 estrategias (2 a 3 por frente) × 24 mundos | R2b |
| 7 | **La señal tiene contrapeso** | el barrido del instante de la señal cumple (a)–(c) de abajo | `--policies=barrido_senal` | R2b |
| 8 | **La extracción no tiene receta** | ninguna receta (`cargar_todo`, `destruir_todo`, `ocultar`, `ligera`, `mixta`) gana en más del 60 % de los mundos y `ocultar` es la mejor en ≥ 1 mundo | `--policies=extraccion` | R2b |
| 9 | **Ritmo (decisiones significativas)** | la primera ≤ 60 s; ninguna brecha > 45 s; ninguna > 20 s durante el ataque | ramificación de snapshots en las 24 semillas, con el experto | R2b |
| 10 | **Atlas de rutas** | cada objetivo tiene **≥ 2 aproximaciones** cuyo tiempo o riesgo difieren ≥ 25 %; la tabla se publica en cada ronda en `user://hx-route-atlas.json` | `test_hx_rules` (`route_atlas`) | R2a |
| 11 | **Cadencia jugable** | ≥ 60 % de las cargas del experto sobre el cuartel salen en el hueco de recarga de la torre | `test_hx_rules` | R2a |
| 12 | **Victorias no pírricas y duración** | mediana de bajas ≤ 55 %; ≤ 15 % de las victorias con bajas > 80 %; victorias de 10 a 14 min (mediana 11–13); derrotas con mediana ≤ 8 min y máximo 14:00 | log de eventos y `campaign_report().loss_pct` | R2b |

**Informe, no compuerta** (se publica en cada cierre de ronda con intervalos de Wilson al 90 %; **nunca** abre un hallazgo P0 ni P1): el **obediente** (solo hace lo que dice «siguiente paso»; proxy *imperfecto* del jugador promedio) y el **torpe** (obediente con demoras de 2–8 s, ignora el 30 % de los avisos no urgentes y falla la sincronía ±15 s), con **≥ 100 mundos × 3 intentos** (semillas 2001–2120). La *intención de diseño* es: obediente 25–40 % al 1.er intento y 60–80 % al 3.º (con diario), ≥ 90 % gana alguna vez en 5 intentos; torpe 10–25 %. Esos números los fija en buena parte quien escribe el algoritmo de pistas, no una persona; por eso no certifican: si el informe se aparta, se anota, se mira con el agente-jugador y el mini-playtest, y se decide con personas.

**Qué es una decisión significativa.** La mide la herramienta, no el juego: en cada oferta (una orden que cambia lo que viene, una elección, una alerta con acción) se **bifurca el snapshot** (el motor es determinista y `snapshot()` es completo), se simula cada opción hasta el final con la política experta y 2 semillas de RNG por opción, y se compara. Cuenta como **significativa** si la mejor y la peor opción difieren en **≥ 10 puntos de golpe o de bajas, o una convierte victoria en derrota**, y si **ninguna opción es la mejor en más del 80 % de los mundos** (si lo fuera, la decisión está resuelta). Sale `decisiones_sig_por_min` por fase y las brechas de la compuerta 9. Un bot «solo pausa y reanuda» no demuestra ritmo (se limita a perder por `amanecio`, y no debe recibir más de una alerta crítica a la vez). Costo: ≈ 6 min para las 24 semillas, así que corre al cierre de ronda y en el QA sobre 12 semillas propias.

**Barrido de la señal (compuerta 7).** `humahuaca_playthrough.gd --policies=barrido_senal --seeds=<las 24> --signal-from=120 --signal-to=375 --signal-step=15`: el experto juega cada mundo dando la señal en cada instante del barrido (2:00 a 6:15) y se registra el puntaje (`golpe − 0,5 × bajas`) de cada partida. Se exige: **(a)** el máximo del puntaje medio cae entre 4:15 y 5:45 y **no** en uno de los tres primeros instantes barridos; **(b)** unimodal: tras una media móvil de 3 puntos hay un único máximo local (los secundarios de menos de 3 puntos de prominencia se ignoran); **(c)** meseta: ≥ 3 instantes consecutivos (≥ 30 s) con ≥ 90 % del máximo. Si falla, se ajustan los contrapesos de la oscuridad y del desvelo (sección 2), que son contenido.

**Agente-jugador (el sustituto de las personas que sí está al alcance del circuito).** Un agente **sin acceso al código, a `qa_state()` ni a las reglas** juega por la interfaz real: ve una captura de 1280 × 720, decide, y el arnés `tools/hx_agent_play.gd` inyecta la entrada como hace `ui_qa` (el juego queda en pausa entre turnos y avanza `paso` segundos de juego por turno). Escribe una bitácora en voz alta y al final responde **«¿entendiste qué hacer?»** (con el objetivo en sus palabras) y **«¿cuándo te aburriste?»**. El arnés registra cuántos turnos y cuántos segundos de juego pasan hasta la primera orden aceptada. Lo corre el integrador al cierre de R1 y de R2a (para enterarse temprano de que «no se entiende») y el QA en la certificación (criterio J08 de la rúbrica). Aprobación: primera orden aceptada en ≤ 40 s de juego y ≤ 8 turnos; objetivo en sus palabras con ≥ 2 de 3 conceptos (tomar los tres frentes; sacar carga; antes del refuerzo o del alba); llega a un parte en ≤ 150 turnos; si pierde, reintenta y dice qué aprendió; responde las dos preguntas. Se informa (no bloquea) cualquier racha de 4 turnos seguidos esperando sin nada que decidir. También sirve para la métrica de legibilidad de las vistas de juego: tiene que identificar los tres objetivos en < 3 turnos (sección 11.3).

**Mini-playtest humano (no bloqueante).** 10 minutos, una persona, tres preguntas («¿entendiste qué hacer?», «¿cuándo te aburriste?», «¿qué cambiarías primero?»), al cierre de **R1** y de **R2b**, con la plantilla `docs/humahuaca/PLAYTEST.md`. Si no hay nadie, el QA anota «mini-playtest no realizado» y el agente-jugador lo reemplaza: no es un hallazgo y no bloquea. Si hay una persona y contradice al modelo, **manda la persona**.

**Método.** Semillas de **calibración** (para ajustar) **3, 5, 7, 11, 13, 17, 19, 23**; de la **compuerta** (24 mundos, la misma lista para cada pista y para cada cierre de ronda): validación **29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73** y cierre **101, 103, 107, 109, 113, 127, 131, 137, 139, 149, 151, 157**; del **informe** (≥ 100 mundos): **2001–2120**; **reservadas al QA: 9000–9999** (ninguna pista las usa, las publica ni las ve). `world_from_seed()` es determinista y las semillas cubren **cada valor de cada variante activa en ≥ 2 semillas de calibración y en ≥ 3 de cada mitad de la compuerta** (si el sorteo no lo logra, se ajusta `world_from_seed`, no las listas). Se publican tasas con **intervalos de Wilson al 90 %**, bajas, duraciones y decisiones significativas en `user://hx-balance-results.json` (con `APPDATA` aislado). El obediente aprende solo lo que el diario le muestra (con probabilidad 0,7 de usarlo). Si el modelo y una persona discrepan, **manda la persona**. Las perillas permitidas para calibrar son las de **contenido** (cifras de `humahuaca_rules.json`: sorpresa, cobertura, daño de la torre, costos de la oscuridad y del desvelo, demora del refuerzo, capacidad, valores del botín y de cada tratamiento, la matriz de contrapesos); cambiar un multiplicador global no cuenta como mejora. **Una sola biblioteca de políticas** (`scripts/humahuaca/rules/humahuaca_policies.gd`, `decide(vista, rng) → órdenes`) sirve a las reglas, a la interfaz de prueba y a las herramientas: nadie escribe un segundo juego de bots.

**Cómo se leen los números del diseño frente a los de la rúbrica del QA** (`docs/QA_NIVEL2.md`; los umbrales de la rúbrica son más laxos que la meta de la pista a propósito, para absorber el ruido entre las 24 semillas de la pista y las 60 del QA):

| Tema | Meta de la pista (compuerta de ronda) | Rúbrica del QA |
|---|---|---|
| Experto | ≥ 90 % (24 mundos) | J04: ≥ 80 % (BLOQUEA, 60 semillas del QA); J05: ≥ 90 % (MEDIA, informe) |
| Pasivo y «pausa y reanuda» | 100 % pierden | J04 (BLOQUEA) |
| Ciegos | ≤ 5 % | J04: ≤ 10 % (BLOQUEA) |
| Obediente y torpe | informe | J05 (MEDIA, informe con intervalos) |
| Contrapesos, enfoques, señal, extracción | compuertas 5–8 | J06 (BLOQUEA) |
| Ritmo | compuerta 9 | J03 (BLOQUEA) |
| Gradiente, atlas de rutas y cadencia jugable | compuertas 4, 10 y 11 | solo de la pista (el QA las ve correr dentro de `test_hx_rules`, T03) |
| Duración y bajas | compuerta 12 | J07 (ALTA) |
| Agente-jugador | aprobación de arriba | J08 (ALTA) |

---

## 11. Dirección de arte

**Reglas que salen de la lección del nivel 1** («lo visual quedó pobre»: barranca, fuerte y casas de cajas; unidades como discos de color; río re-pintado cinco veces sin referencia; cámara inicial casi solo agua): (1) **referencias objetivas** — la lámina 06 (paleta) y la composición de la foto de 1923; (2) **siete vistas canónicas aprobadas una sola vez** —cinco de primer plano y **dos a la distancia a la que se juega** (cámara inicial de noche y de alba, con interfaz y fichas)— y, desde ahí, solo comparaciones antes/después; (3) **silueta antes que color**; (4) el agua y el suelo **no se re-pintan** salvo un hallazgo P0 con evidencia; (5) la cámara inicial muestra los tres objetivos y el pueblo, nunca solo suelo o agua ni solo noche cerrada; (6) **se aprueba donde se juega**: a 470 m una casa de 12 m mide ≈ 22 px y el templo ≈ 40 × 15 px, así que la lectura viene de la **luz, el trazo y la ficha**, no del color del muro; (7) **una lista escrita de 5 rasgos obligatorios por vista antes de pintar** (`canonical_views[*].must_show`, a partir de la lista del anexo B del QA).

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

**Legibilidad (no alcanza el color):** (1) la identidad de partida y de bando la dan **anillo, ícono, contorno y marcador de interfaz**, no el color de la ropa (el dossier lo pide: «los colores pueden superponerse entre bandos»); (2) contorno oscuro (`#383831`) en todas las figuras; (3) azul, rojo y verde solo como **acentos** (≤ 15 % de la superficie de una figura); (4) los marcadores de interfaz se validan con `validate_palette.js` (skill `dataviz`), umbral de ΔE fijado en R1; (5) **métrica de paleta sobre un render de albedo** (materiales sin sombreado, sin niebla, sin exposición ni sombras: `set_albedo_mode`) de tres vistas de día y sin interfaz, no sobre capturas iluminadas —la noche, la lluvia y la niebla cambian el color a propósito—: mediana de distancia cromática a la lámina 06 ≤ 8, p90 ≤ 14 y ≤ 3 % de píxeles a > 22 (la mide el QA, V04); (6) un anillo tenue de **visibilidad** alrededor de cada partida de noche (dónde ve y dónde se la ve); (7) **la lectura de noche la da la luz**: brasero en la batería, ventana en la casa del cura, candil en la posta y fogatas junto a los centinelas (las luces se ven de lejos y delatan a la guardia: son información, no decorado), sombras largas al alba, contorno de tapias y huellas de los edificios, y curvas de nivel sutiles.

### 11.2 Materiales, luz y vegetación

- **Materiales (todos procedurales; sin descargas):** adobe (bloques de tierra con juntas irregulares y desgaste en la base), **tapia** (tierra compactada en franjas horizontales de 40–60 cm, remate de paja), cal envejecida (blanco sucio, manchas de lluvia), piedra gris (cimientos y cerro), madera oscura, paja y azotea de barro con pretil o techo a dos aguas, suelo de grava clara con piedras sueltas en la ladera, tierra apisonada en patios, barro brillante con charcos. Se retinta **por rol** (atributos de color por vértice), no por heurística de rangos RGB: la de la Justina es frágil ante modelos nuevos.
- **Luz:** `noche_lluvia` (luz fría hacia `#2E455A`, energía ≈ 0,15, niebla densa de 220 m), `alba` (sol a 6°, cálido, sombras largas, niebla de valle), `dia` (sol a 35°). Transiciones continuas con `time_of_day`; un `Environment` **por escena** (nada de `shader_globals` ni de cambios de render en `project.godot`: cambiarían también a la Justina). **Lluvia:** rayas por partículas, suelo que se oscurece ×0,75 y brilla donde llueve, charcos. **Presupuesto por perfil de calidad** (`benchmark.py`, 1440 × 900, Forward+): **baja ≤ 2,5 ms, media ≤ 4,0 ms, alta ≤ 6,0 ms de cuadro medio y p95 ≤ 8,3 ms**; la Justina y el Norte siguen en ≤ 3,0 ms (no se tocan). Lluvia, ~200 figuras y sombras no entran en 3 ms: el techo no puede recortar lo visual. Las superficies y los rasgos se **rasterizan una sola vez** a `Image` o `PackedByteArray` (clasificar por polígono con `Geometry2D` cuesta ≈ 81 ms cada 30 polígonos) y el horneado se mide por etapas; el total sigue < 300 ms.
- **Vegetación:** churqui (arbusto espinoso de 2–3 m; se retinta `tree_algarrobo` solo si su silueta sirve, D9), cardón (`tree_cardon`, 3–5 m, en laderas), sauce criollo (6–8 m) en el monte ribereño y parcelas irrigadas de alfalfa. **Excluidos:** álamos piramidales, eucaliptos, postes, tendidos y alumbrado (la foto es de 1923 y no los acredita para 1817). Pregunta abierta al usuario: si los quiere igual, irían rotulados «diseño, no acreditado» (anexo B).
- **Arquitectura de 1817:** **templo sin fachada ni torres de 1880–1881**: nave simple de adobe encalado con cubierta a dos aguas; el **sector Santa Bárbara** es un reducto de tierra con foso y parapeto sobre la altura (no una capilla ni un monumento ni una escalinata); sin cabildo actual; calles de tierra (acabado editable); casas bajas de adobe con azotea o dos aguas; patios y tapias. La foto de 1923 sirve como **relación** (ladera → núcleo → monte ribereño → lecho claro → llanura → cerros con estratos → horizonte), no como copia.
- **Figuras y fichas:** figuras 3D de ≥ 1,7 m con contorno, **sin uniformar** (camisa de lino o lana natural, poncho o chaqueta de lana parda o azul, sombreros y gorras variados; un rojo o verde cada seis); realistas con equipo que distingue función (fusil y cartuchera, artillero con herramienta, «chicheño» sin uniforme cerrado ○), sin «todos de blanco». **Tres arquetipos de figura** (siluetas distintas, no solo retintes): *poncho y sombrero de ala ancha* (jinetes y arreo), *camisa y gorra* (infantes) y *artillero* (herramienta y delantal); más el realista de `royalist_1817`. Fichas de **tamaño fijo en pantalla** (≥ 48 px de alto a zoom por defecto, distinguibles en escala de grises): `rodriguez` jinete, `portal` infante con fusil, `arias` infante con banderín de mando, `reconocedores` dos figuras agachadas, `arreo` mula cargada. Banderín de bando = **marcador de interfaz** (diseño), nunca una bandera de 1817.
- **Modelos y canal de arte (se decide en R0, no en R2):** el camino por defecto es un **generador procedural en GDScript** (`SurfaceTool` y primitivas con bisel, alero y azotea) para el **templo** y para los **tres arquetipos de figura**: `church_colonial.glb` es una sola malla con un campanario de ≈ 12,9 m que no se puede quitar sin Blender y no existe base de figura para la infantería patriota. Un **render «héroe»** del templo y de los tres arquetipos se aprueba al cierre de R1, antes de abrir R2a. GLB existentes retintados solo donde sirven: `horse_only`, `royalist_1817`, `rider_1817` con el poncho retintado, `house_colonial`, `tree_cardon`, `rock_cluster`; **no sirven** `infantry`, `dismounted_1806`, `rider_1806` ni `church_colonial`. Lo nuevo (tapias, torre, posta, cargas, mulas, cañones, cerco) sale de **primitivas de Godot** (`BoxMesh`, `PrismMesh`, `CylinderMesh`, `SurfaceTool`, `MultiMeshInstance3D`). **Blender 4.4.3 portable** (385 412 148 B) es una **mejora opcional** si el usuario la concede (anexo B): no está instalado y nada del diseño espera por él; ningún modelo de IA ni de descarga. **Aceptación medible:** AABB del templo ≤ 8 m de alto (el QA tolera 8,5) y ninguna cresta de vértices por encima del caballete de 7 m; los tres arquetipos se distinguen en escala de grises a 48 px (silueta rellena, ΔL* ≥ 15 entre pares). La prueba «sin torres de 1880–81» mira la geometría (altura de los vértices), no solo el nombre del nodo.

### 11.3 Siete vistas canónicas (en `humahuaca_visual.json.canonical_views`; cámara fija)

| Id | Qué debe mostrar | Cámara (objetivo x,z · distancia · inclinación · rumbo) | Luz |
|---|---|---|---|
| `acceso_so` | Desde el acceso del sudoeste: la ladera a la izquierda, el núcleo y el templo al fondo [md §K] | (300, 520) · 150 m · 22° · 45° | noche con lluvia |
| `desde_bateria` | Desde la plataforma: el pueblo por debajo hacia el este, el río y el lecho claro [md §K] | (318, 350) · 60 m · 18° · 90° | alba |
| `patio_posta` | El patio de la posta: cargas, mulas, polvorín [md §K] | (590, 300) · 45 m · 40° · 315° | mañana |
| `panorama_alto` | La composición de la foto de 1923, sin torres ni monumento | (450, 330) · 330 m · 28° · 90° | alba |
| `grupos_en_accion` | El asalto al cuartel con la torre, fichas, humo y bajas | (418, 335) · 90 m · 45° · 0° | alba, lluvia floja |
| `juego_noche` | **A distancia de juego, con interfaz y fichas**: los tres objetivos identificables por su luz (brasero, ventana, candil), relieve y núcleo; no «casi solo noche» | `initial_frame` · 470 m · 52° · 35° | noche con lluvia, t = 0 |
| `juego_alba` | La misma cámara al alba (≈ 4:45, visibilidad ≈ 80 m): sombras largas, fichas en sus puestos, fogatas de la guardia | `initial_frame` · 470 m · 52° · 35° | alba |

**Cámara inicial** (`initial_frame()`): objetivo (350, 470), 470 m, 52°, rumbo 35°; debe **incluir los tres objetivos y la zona de partida**; zoom de juego entre 40 y 900 m. Las dos vistas de juego **son** esa cámara: allí se aprueba la legibilidad.

**Criterios de legibilidad a distancia de juego** (los mide el QA en `juego_noche`, `juego_alba` y las demás vistas; criterio V06): (a) **ΔL\*** entre la huella proyectada de los edificios y el suelo que los rodea ≥ 12, y entre la ficha y el suelo ≥ 25 (promedio de L\* sobre rectángulos que informa el recorrido, `probes`); (b) los **tres objetivos identificables** en menos de 3 turnos por el agente-jugador; (c) **riqueza uniforme**: con una grilla de 8 × 6, la baldosa con menos bordes tiene ≥ 40 % de la mediana de densidad de bordes y ninguna zona lisa ocupa más del 25 % del cuadro (en cada vista canónica y en la cámara inicial); (d) `panorama_alto`: **correlación ≥ 0,6** del perfil de valores por franjas horizontales con la foto de 1923 recortada (sin márgenes, óvalo ni título) **y ≥ 0,3 quitada la tendencia lineal** (para que un simple degradé de cielo claro a suelo oscuro no alcance) (ladera clara → arbustos oscuros → techos claros → arbolado oscuro → lecho claro → llanura → estratos → cordillera). Las cuatro son medidas objetivas sobre capturas reales; ninguna depende del gusto.

### 11.4 Lista priorizada de elementos a modelar (29)

Orden de producción del dossier [md §G]: 1 terreno y relaciones · 2 tres objetivos · 3 torre · 4 conexiones · 5 logística · 6 vida cotidiana. La tabla original de 23 filas **no está**; esta es una reconstrucción propia (más la plaza, el templo, el trofeo y las fichas). Coordenadas de juego `x,z`; «R1» = entra como caja con la huella correcta en la rebanada vertical.

| # | Elemento (id) | Ubicación | Dimensiones de prototipo | Materiales | Colores | Referencia | Certeza | Función | Prioridad |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Cerro occidental (`cerro_occidental`) | domo en (305, 345), radio 75 m | +12 m de prominencia sobre el anillo de 120–150 m (residuo del DEM); plataforma 28 × 18 m | grava, suelo seco, piedra, churqui | `#B99A72` `#8E8B81` `#6D7653` | foto 1923 plano 1; lám. 03 | relieve ◇; domo ▲ | visión, tiro, flanqueo | 1 · R1 |
| 2 | Núcleo urbano (`nucleo_urbano`) | x 340–700, z 200–470 | manzanas de 54 × 54 m; calles de 8 m | adobe, cal, paja | `#C4AA82` `#E4DDCA` `#B3A077` | foto plano 2 | sitio ◇; planta ▲ | laberinto de tapias y cobertura | 1 · R1 (cajas) |
| 3 | Río Grande (`rio_grande`) | (572, 0) → (900, 406) | lecho de 25–40 m; agua de 0,2–0,6 m; 2 vados | agua, sedimento, piedra | `#8C9B91` `#776248` `#8E8B81` | foto planos 4–5; lám. 03 | traza moderna; cauce de 1817 ○ | borde y salida | 1 · R1 |
| 4 | Templo (`templo`) | (450, 325) | nave 22 × 8 m; alero 5,5 m; caballete 7 m; atrio 14 × 10 m; **AABB ≤ 8 m** | adobe encalado, madera, paja | `#E4DDCA` `#C4AA82` `#59432E` `#B3A077` | foto 1923 (sin torres ni fachada) | sitio ◇; forma ○ | hito, cobertura | 1 · R1 (caja; generador procedural y render héroe al cierre de R1) |
| 5 | Plaza (`plaza`) | (450, 392) | 56 × 50 m | tierra apisonada | `#B99A72` | [md §G] | ▲ parámetro | cruce y reunión del refuerzo | 1 · R1 |
| 6 | Batería de Santa Bárbara (`bateria`) | (318, 350) | plataforma 28 × 18 m; parapeto 1,6 m; foso 2 × 2 m; gola al este (▲); 3 piezas | tierra, piedra, madera, hierro | `#B99A72` `#8E8B81` `#59432E` `#4B4B47` | lám. 03 (−111,−35); Diario realista | objetivo ●; posición, cota y orientación de la gola ▲ | frente 1 | 2 · R1 |
| 7 | Cuartel, casa del cura (`cuartel`) | (418, 335) | 22 × 14 m; muro 0,7 m; alero 3,2 m; patio 8 × 8 m; aspilleras | adobe, cal, madera, paja | `#C4AA82` `#E4DDCA` `#59432E` `#B3A077` | parte («casa del Cura») | objetivo ●; lugar ▲ ○ | frente 2 | 2 · R1 |
| 8 | Posta con polvorín (`posta`) | (590, 300) | patio 30 × 24 m; muros 2,4 m; 2 entradas; polvorín 6 × 5 m al NE; corral 20 × 14 m | adobe, madera, cuero | `#C4AA82` `#59432E` `#745034` | parte («casa de Posta»); [md §K] | objetivo ●; planta ▲; pólvora ahí ◇ | frente 3 y botín | 2 · R1 |
| 9 | Torre provisional (`torre_casa_cura` / `torre_templo`) | (426, 326) o (466, 322) | base 3,5 × 3,5 m; 10 m; plataforma a 9 m con 8 aspilleras | adobe y madera | `#C4AA82` `#59432E` `#B3A077` | parte («la torre») | resistencia ●; cuál y dónde ○ | fuego sobre las calles | 3 · R1 (caja) |
| 10 | Tapias (`tapias`) | entre el acceso y el núcleo; ≥ 12 en R1 | 1,8–2,4 m de alto; 0,5 m de espesor | tierra compactada, remate de paja | `#C4AA82` `#B99A72` `#B3A077` | parte («tapial»); foto plano 3 | existencia ●; posición ▲ | rutas y ocultamiento | 4 · R1 (líneas) |
| 11 | Patios (`patios`) | dentro del núcleo; ≥ 6 | 12–30 m de lado | tierra apisonada | `#B99A72` | foto plano 2; [md §K] | ▲ | rutas ocultas | 4 · R2a |
| 12 | Zanjas y acequias (`zanjas`) | cerca de parcelas y posta; ≥ 4 en R1 | 0,8–1,2 m de profundidad; 1,2–2 m de ancho | sedimento húmedo | `#776248` | parte («zanjita») | existencia ●; posición ▲ | lentitud y tropiezo | 4 · R1 |
| 13 | Portillos y pasajes (`portillos`) | ≥ 6 en tapias | 2,5–3 m; portillo abierto 1,8 m | madera | `#59432E` | [md §G] | ▲ | rutas | 4 · R2a |
| 14 | Quebradita (`quebradita_norte` / `quebradita_sur`) | (282, 298) / (288, 402) | 36 × 8 m; −2,5 m | suelo seco, churqui | `#B99A72` `#6D7653` | parte («quebradita») | existencia ●; lugar ▲ ○ | refugio de caballos | 4 · R1 |
| 15 | Camino cubierto y barricadas (`camino_cubierto`, `barricadas`) | (405, 338) → (345, 350); bocacalles del SO | 60 m entre tapias de 1,8 m; barricada de 8 m | tapia, maderos, carretas | `#C4AA82` `#59432E` | Diario realista (enero) | ◇ | repliegue y entradas | 4 · R2a |
| 16 | Cargas (`cargas`) | posta y cuartel | 100 kg c/u; 0,9 × 0,5 × 0,4 m | cuero, lana, madera | `#745034` `#CEC2A7` `#59432E` | parte (recursos capturados) | existencia ●; pesos ▲ | botín | 5 · R1 (cajas) |
| 17 | Recipientes (`recipientes`) | polvorín y depósito | barriles de 50 l; botijas; cajones | madera, hierro, cuero | `#59432E` `#4B4B47` `#745034` | ▲ | ▲ | pólvora y víveres | 5 · R2b |
| 18 | Armas (`armas`) | armería del cuartel | fusil de chispa 1,45 m; sables; lanzas; palos | hierro, madera | `#4B4B47` `#59432E` | parte («armas muy desiguales») | desiguales ●; modelos ○ | botín y equipo de figuras | 5 · R2b |
| 19 | Cañones (`canones`) | 3 en la batería; 4 en el parque de la posta | tubo 1,6 m; 400 kg (de a 4) y 200 kg (de a 2) | hierro, madera | `#4B4B47` `#59432E` | parte («siete piezas») | 6–7 ◆; modelo ○ | botín; voltear | 2 · R1 (cajas) |
| 20 | Animales (`animales`) | arreo, corral, caballada, ovejas, vacas | mula 1,3 m a la cruz; caballo 1,4 m | lana parda, cuero | `#705741` `#745034` | parte (16 mulas, 2 000 ovejas, 60 vacas) | ●; cantidades iniciales ▲ | transporte | 5 · R1 (siluetas) |
| 21 | Arreos (`arreos`) | sobre mulas y caballos | aparejos, cinchas, cabestros | cuero, lana | `#745034` `#CEC2A7` | analogía Vidal 1820 y Temple 1830 | ▲ (analogía tardía) | lectura de la carga | 5 · R3 |
| 22 | Viviendas (`viviendas`) | núcleo; ≥ 40 | 6 × 4 m a 12 × 6 m; muro 0,6 m; alero 2,6–3,2 m | adobe, cal, paja | `#C4AA82` `#E4DDCA` `#B3A077` | foto plano 2 (analogía tardía) | ▲ | volumen y cobertura | 6 · R2b |
| 23 | Corrales (`corrales`) | cerca de la posta y del núcleo | 12 × 12 m; tapia baja de 1,2 m | tierra, palos | `#B99A72` `#59432E` | ▲ | ▲ | ganado | 6 · R3 |
| 24 | Utensilios (`utensilios`) | patios | tinajas, ollas, bancos | barro, madera, hierro | `#C4AA82` `#59432E` `#4B4B47` | ▲ | ▲ | vida cotidiana | 6 · R3 |
| 25 | Vegetación (`vegetacion`) | churqui y cardón en la ladera oeste; sauce y parcelas hacia el río | churqui 2–3 m; cardón 3–5 m; sauce 6–8 m | — | `#6D7653` `#69794B` | foto planos 1, 3, 4; [md §D] | ◇ (álamos y eucaliptos excluidos) | cobertura y lectura | 6 · R2b |
| 26 | Trofeo, bandera (`bandera_trofeo`) | cuartel | 1,4 × 1,0 m; plegada | tela | `#EFE8D7` `#B99A50` | parte y anexo («Pumacagua degollado») | ● parcial; paño ▲ ○ | botín opcional | 5 · R3 |
| 27 | Fichas y estandartes (`fichas`) | interfaz | ficha fija ≥ 48 px; banderín de bando | — | `#7FAAC4` `#EFE8D7` `#983F36` `#383831` `#B99A50` | lám. 06 (símbolos) | ▲ marcadores, no banderas | lectura de partidas y bandos | 1 · R1 |
| 28 | Rasgos verticales (`barranca_cauce`, `terraza_nucleo`, `banco_grava`) | margen del Río Grande; entre la plaza y el oeste del núcleo; junto al vado | escalón de 3–5 m; escalón de 3 m con 2 escaleras; montículo de +1,2 m (30 × 15 m) | tierra, grava | `#776248` `#8E8B81` `#B99A72` | lám. 03 (cauce) | ▲ | cortan la línea de visión y el paso | 4 · R2a |
| 29 | Luces de la guardia (`luces`) | brasero en la batería, ventana en el cuartel, candil en la posta, fogatas junto a los centinelas | puntos de luz cálidos visibles de lejos | llama, vidrio | `#B99A50` `#59432E` | [md §D] «luz progresiva» | ▲ | información: marcan objetivos y guardias | 1 · R1 (puntos) |

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
| La **gola** de la batería mira al este, hacia el pueblo y el camino cubierto (orientación de la gola) | ▲ (◇ lo sugiere el camino cubierto «que protegiese la retirada») | Diario realista; sin dato del rumbo |
| Resistencia desde una torre (5:00–6:30) | ● el hecho; ○ cuál torre y dónde | parte |
| La pólvora está en la posta | ◇ | parte («por la casa de Posta... ganar la pólvora») |
| Portal fue prisionero en Humahuaca y se fugó; conoce las calles | ● la fuga; ◇ que las conozca | oficio de Güemes, 20-II |
| Un traidor avisó; la guardia «lo había esperado noches antes» | ● acusación (sin identificar); ▲ la variante «atenta» | parte |
| Munición quemada o echada al río; cañones sin llevar; luego recuperados | ● Arias y La Serna; ◆ «ocultos o enterrados» | parte; Camba; Diario |
| Clavar los cañones, tirar los víveres, los tres escondites y su distancia al camino | ▲ (ninguna fuente lo dice) | — |
| El grito de «viva el rey» del ayudante de artillería, los dos caídos de la pólvora y el oficial alcanzado «a media cuadra» | ● el hecho; ▲ el momento y el lugar dentro del mapa | parte de Arias, GD IV p. 356 |
| Tiempo comprimido (≈ 26 h de marcha; 5:00 a 6:30 de fuego desde la torre) y salida «por el este» | ▲ (se declara en el epílogo; el parte no dice por dónde salieron) | parte |
| Luces de la guardia (brasero, ventana, candil, fogatas) | ▲ | md §D («luz progresiva») |
| Fecha: 1 de marzo (itinerario de Arias, Diario realista) o 2 (La Serna, prisioneros, inscripción del premio) | ◆ | md §A; [02] b.5 |
| Guarnición ≈ 130 y 6–7 piezas | ● / ◆ | Camba; Diario; Arias |
| Refuerzo realista inmediato | ▲ (**no ocurrió**: se supo el 4 y salieron columnas el 5–6) | Camba; Diario |
| Pueblo casi vacío de vecinos; informantes y arrieros presentes | ● / ◇ | Diario; md §D |
| Parte: 3-III San Andrés → 8-III Salta (22 h) → 13-III Tucumán | ● | md §C.1; GD IV |
| Seis piezas recuperadas por una columna realista entre el 9 y el 16 de marzo | ◆ versión realista (no se atribuye a La Serna: H03, 2-11-2026) | Diario; Camba (S49, S50) |
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
- No tocar `project.godot` ni usar `shader_globals` para el aspecto del nivel: cada escena trae su `Environment` (los ajustes de render globales cambiarían también a la Justina).
- No generalizar un motor común ni crear sistemas nuevos grandes (economía, formaciones): es un golpe de mano de 10–14 minutos, no un RTS.
- No inventar planta, rutas, cifras ni vestuario y presentarlos como documentados; no afirmar el refuerzo como hecho; no fijar la ruta de Arias.
- No re-pintar el agua o el suelo ronda tras ronda sin referencia; no cambiar la paleta (los 24 HEX son la referencia).
- No esconder ayudas ni multiplicadores: baqueano, noche más larga y la ventaja de la experiencia son visibles y marcadas.
- No perillas globales para «dar» el balance: se mueve contenido.
- No más de 7 hallazgos por ronda ni listas abiertas; no reportar «94 pendientes».
- No usar bandas de tasa de bots como criterio de salida (el obediente y el torpe son informe); no contar «ofertas» como decisiones.
- No dejar una receta fija ganadora: ni «señal enseguida», ni un tratamiento único de la extracción, ni un enfoque que gane en todos los mundos.
- No presentar el nivel III como continuación del II.
- No mostrar la carta del 26-II como cita: es una dramatización rotulada.
- No descargar nada sin permiso (tesela, Blender, paquetes de PyPI); no usar Google Elevation; no copiar código GPL; no modelos de IA.
- No imprimir ni guardar claves de Jev; no abrir `.env*` ni `jev.cfg`.
- No capturas por volumen: ≤ 14 JPEG ≤ 300 KB por pista y ronda; solo la última ronda entra a Git.
- No declarar «certificado por humanos» sin una sesión humana: el circuito puede firmar «presentable, no certificado por humanos» (con la corrida del agente-jugador), y esa es una salida válida del bucle, no un bloqueo.
- No push ni release.

---

## 14. Plan de rondas del bucle

**Equipo.** **Cuatro pistas** (`relieve_mapa`, `reglas_historia`, `visual`, `ui_feel`) con propiedad exclusiva de archivos; **dos roles de integración**: el **integrador** (único autor de `main.gd`, del vocabulario compartido y de los merges) y **compuertas y documentos** (`qa_gate.sh`, `test_hx_data`, `test_hx_smoke`, ejemplos de forma, recorrido del QA, arnés del agente-jugador, trazabilidad, evidencia; si un solo agente cumple los dos roles, la propiedad de archivos es la misma); **control de calidad** (un solo informe por ronda, con **presupuesto de hallazgos**); un revisor por pista sobre su diff; y el arquitecto (este documento y el contrato). Severidades (iguales a las de la rúbrica de `docs/QA_NIVEL2.md`): **P0 = BLOQUEA** (se cuelga, no se entiende el objetivo, ilegible, regresión), **P1 = ALTA**, **P2 = MEDIA** (cuenta contra un tope de 3 aceptables con razón escrita) y **BAJA** (va a `docs/humahuaca/BACKLOG.md` y no cuenta). La lista de trabajo de una ronda tiene **≤ 7 hallazgos** (primero P0, luego P1, luego P2). Cada hallazgo trae id, evidencia (una imagen o una métrica), pista dueña y prueba de aceptación; las categorías se fijan en R1 y solo se agregan por regresión; los duplicados se fusionan.

**«Presentable», en dos etapas** (el circuito no puede producir personas, pero sí puede producir un agente que juega por la interfaz):

1. **Presentable para playtest** (lo que firma el QA): todos los BLOQUEA pasan, **0 ALTA abiertas**, ≤ 3 MEDIA con razón escrita, la rúbrica corrió completa sobre **un único commit**, y el **agente-jugador** (sección 10) aprobó. Veredicto: *«PRESENTABLE, no certificado por humanos»*. Es una salida válida del bucle: **si el humano no aparece, el QA lo escribe así y el bucle termina**.
2. **Certificado por humanos** (paso aparte, **no bloqueante**): la sesión de 20 minutos del anexo E del QA con tres personas; solo ella quita el sello.

Las rondas intermedias cierran con **0 P0 y ≤ 3 P1 listados y fechados** (cada uno con dueño y la ronda en que se cierra); la salida final exige 0 P1. Un P1 que viene arrastrado de dos rondas se vuelve P0 de la siguiente.

| Ronda | Entra | **No** se hace todavía | Salida (verificable) |
|---|---|---|---|
| **R0** (integrador, serie corta) | Andamiaje mínimo: ganchos de `main.gd` con carga con respaldo, cáscara del controlador (`stub_ui.gd`), `tools/qa_gate.sh`, `tests/test_hx_data.gd` (V1–V9 + grafo de dependencias) y `test_hx_smoke.gd`, ejemplos de forma de `hud_state` y `render_state`, vocabularios iniciales, `.gitignore`/`.gitattributes`; estos tres documentos. **Decisión del canal de arte** (procedural; Blender opcional) | Cualquier contenido de juego y los stubs de las capas (los escribe cada dueño en R1.0) | Compuerta rápida verde (reglas ≥ 818, integración ≥ 283, smoke y data ok, protegidos intactos contra `5ebbd28`); recién entonces se abren los worktrees |
| **R1.0 · stubs primero** (las cuatro pistas, en paralelo, ≤ 1 h de agente) | El **primer commit** de cada pista: su stub (`stub_terrain`, `stub_rules`, `stub_view`, `stub_progress`) con la firma completa del contrato 3 y valores válidos, su archivo de vocabulario y su JSON mínimo; el integrador los fusiona en orden y corre la compuerta | Todo lo demás | El nivel arranca, avanza y vuelve al menú con las cuatro capas de respaldo; `test_hx_smoke` pasa las corridas degradadas; recién entonces las pistas rebasean y siguen con R1 |
| **R1 · corte vertical mínimo** | Menú → briefing → apertura → aproximación → tres objetivos → resistencia → extracción → epílogo → reintento, **en caja gris con relieve real**: **mundo fijo**; **9 acciones**; geometría toda conocida; torre como temporizador de 90 s; botín en **5 clases** con puntos provisionales que suman 100; **guardado y carga** con `validate_snapshot`; HUD mínimo con «siguiente paso»; fichas por silueta; cámara inicial correcta y **las vistas `juego_noche` y `juego_alba`** (luces, relieve y fichas; arte provisional); **render héroe** del templo y de los 3 arquetipos; dos bots (**experto gana, pasivo pierde**) | Variantes del mundo, diario con marcas, medallas, tapias y zanjas con reconocimiento fino, torre con respuestas, decisiones, audio, tutorial, F1, Jev | `test_hx_flow`: el experto gana y el pasivo pierde por la escena real; `ui_qa_humahuaca` completo a 1280 × 720 y chequeo de desborde a las otras dos; benchmark (media ≤ 4,0 ms); 41 puntos de la lámina 03; **corrida del agente-jugador** (informativa); **mini-playtest humano de 10 min** (no bloqueante) y la **captura al usuario para el sí/no**. **Cierra con 0 P0 y ≤ 3 P1 listados y fechados** (no «sin esto no se abre R2») |
| **R2a · núcleo legible** | Rasgos del mapa (tapias, zanjas, portillos, quebraditas, barranca, terraza, banco de grava); reconocimiento con riesgo y la doble capa «lo que sabés / lo real»; torre con cadencia, anillo de recarga y las cuatro respuestas; apoyo y piezas; las 20 acciones; las 9 clases de botín con `ocultar`, destrucción con costo y botín del mundo; eventos del guion y microescenas; apertura y luces como información; **las dos vistas de juego con arte final**; templo y arquetipos de figura finales; atlas de rutas y cadencia jugable | Variantes del mundo, diario, medallas, ayudas, matriz de estrategias, tutorial, F1, sonido | Compuertas 10 y 11; V02 y V06 (las dos vistas de juego) sin P0; agente-jugador informativo; benchmark; 0 P0 y ≤ 3 P1 |
| **R2b · profundidad y contrapesos** | Variantes de **3 dimensiones** (12 mundos) con su matriz de contrapesos; diario con marcas «anotado», dos puntos de control, ayudas, medallas; biblioteca de políticas y 3 bots; 8 estrategias de frente y 5 recetas de extracción; barrido de la señal; ramificación de decisiones significativas; las demás vistas canónicas; edificios y vegetación; sonido de avisos y de la descarga | Más dimensiones de variante, estrategias extra, tutorial, F1, pulido | Compuertas 1–9 y 12; `ocultar` mejor en ≥ 1 mundo; **agente-jugador aprobado** (J08); **mini-playtest humano de 10 min**; 0 P0 y ≤ 3 P1 |
| **R3 · pulido y verificación** | Tutorial de 6 pasos, ayuda F1, sonido completo, estrategias extra si hacen falta, pulido visual con las métricas del QA (albedo, bordes, ΔL\*, correlación), rendimiento por perfil, accesibilidad (contraste, no solo color), jerga en cero, **informe de 120 mundos** (obediente y torpe), prueba de inversión de una cuarta dimensión de variante, evidencia final | Contenido nuevo | 0 P0 y ≤ 3 P1; benchmark por perfil; métricas visuales bajo el umbral; compuertas de la sección 10 verdes |
| **R4 · cierre y certificación** | Compuerta completa, **triple certificación del QA** sobre un único commit, EXE armado desde ese commit con SHA-256, evidencia final (< 60 MB), README, CLAUDE.md, VERSION, créditos; decisión D1b (reencadenar o no); **opcional y aparte**: sesión humana de 20 min | — | **«PRESENTABLE, no certificado por humanos»** o una lista cerrada y corta. El sello humano se agrega solo si alguien corre el anexo E |

**Orden de descarte si una ronda se atrasa** (se descarta de arriba hacia abajo, y cada descarte se anota en `docs/humahuaca/BACKLOG.md` con su ronda): (1) estrategias extra de la matriz y el informe de 120 mundos; (2) sonido más allá de la lluvia, la descarga y los avisos; (3) tutorial de 6 pasos (queda el «siguiente paso» con la flecha) y ayuda F1 completa (queda el «?»); (4) medallas plata y oro (queda bronce); (5) la segunda y tercera dimensión de variante (queda `guardia`, más `refuerzo`); (6) marcas del diario (queda la lista de texto); (7) el punto de control `deposito`; (8) rasgos verticales del relieve salvo la barranca; (9) pulido de textos finales. **Nunca se descarta:** el ciclo completo jugable, el relieve (plan B), las siete vistas canónicas, las etiquetas honestas, la compuerta de regresión de la Justina y el Norte, y la corrida del agente-jugador.

**Criterio de salida del bucle (lo que firma el QA, ver «Presentable, en dos etapas»):** compuerta técnica verde con todas las líneas base (contrato, sección 5); las siete vistas canónicas sin P0 a 1280 × 720 y 1920 × 1080, **miradas una por una**, y las métricas de legibilidad a distancia de juego (sección 11.3); extremos y contrapesos en rango (sección 10); decisiones significativas con la brecha pedida; arranque (≤ 5 controles, ≤ 400 caracteres, 0 jerga); cero anacronismos y etiquetas honestas; **0 ALTA abiertas**; evidencia dentro del presupuesto; y el agente-jugador. Una ronda que no mueve ese criterio no cuenta.

---

## Anexo A. Qué falta del material del usuario y qué haríamos si llega

| Falta | Impacto | Si llega | Mientras tanto |
|---|---|---|---|
| Paquete editable (zip de 39 archivos), PDF/MD del dossier de 52 páginas, 16 fichas | Alto en trazabilidad; riesgo en derechos de imagen | Se contrastan las citas y se agregan fuentes a partir de **S46** en `data/history.json` | Se trabaja con el resumen y se repiten las citas «según el md» |
| **Lámina 04** (plano del prototipo) y **tabla de 23 elementos × 9 campos** | **Muy alto**: fijaría plaza, templo, posta, casas y los tres objetivos | `map_version + 1`, addendum al contrato con las posiciones y dimensiones; se actualizan `humahuaca_map.json`, `humahuaca_level.json` y las pruebas | Posiciones de la sección 3 como **diseño** rotulado |
| Láminas 01 y 05 (estratégica; perfil A–A′ y quizá los 12 m) | Medio | Se contrasta el perfil con la grilla | Perfil A–A′ reconstruido en [01] §d.6; los 12 m son diseño |
| Datos de relieve del zip | Alto | Plan D (sección 4) | Plan B desde la lámina 03 |
| Facsímil de *Güemes documentado* IV y VII, *Gazeta* | Medio | Verificar fecha (1 o 2) y cifras | Cifras tomadas de OCR sin cotejo |

## Anexo B. Permisos y preguntas pendientes (no se descargó ni instaló nada)

**Se pide una sola vez, junto con la captura de la cámara inicial al cierre de R1 (o antes, si el usuario contesta):** (1) permiso para bajar la tesela de relieve; (2) si quiere Blender portable (opcional); (3) un sí o un no a «¿es lo que querías?» sobre el reemplazo del nivel 2. **Nada de esto bloquea el trabajo**: cada fila dice qué se hace si la respuesta no llega.

| Qué | Origen | Tamaño | Si no hay respuesta o es no |
|---|---|---|---|
| Tesela **Copernicus GLO-30 S24_00_W066_00** | `https://copernicus-dem-30m.s3.amazonaws.com/Copernicus_DSM_COG_10_S24_00_W066_00_DEM/Copernicus_DSM_COG_10_S24_00_W066_00_DEM.tif` (destino: `investigacion-nivel2/descargas/`, fuera de Git) | 39 438 103 B | Plan B (lámina 03): el juego funciona completo; solo el contorno de 20 m muestra los quiebres de la grilla de 150 m |
| **Blender 4.4.3 portable** (**mejora opcional**; el canal de arte por defecto es el generador procedural) | `https://download.blender.org/release/Blender4.4/blender-4.4.3-windows-x64.zip` | 385 412 148 B | Generador procedural en GDScript y GLB retintados (decidido en R0) |
| ¿Es lo que querías? El nivel 2 pasa a ser Humahuaca y «Sostener el norte» pasa a ser el III | captura de la cámara inicial (caja gris) al cierre de R1 | — | Se sigue con el alcance del lead; si la respuesta es no, se revierte y lo hecho queda como escenario opcional |
| Paquete del dossier, láminas 01/04/05, tabla de 23 filas, 16 fichas | Biblioteca de ChatGPT del usuario (copiar a `info/2` o autorizar abrir con Claude in Chrome) | n/d | Sección 3 como diseño rotulado |

**Decididas con un valor razonable (el usuario puede cambiarlas):** álamos y eucaliptos **excluidos** (si los quiere igual, irían rotulados «diseño, no acreditado para 1817»); **Humahuaca siempre habilitado** con la nota «Recomendado tras la Justina» (`--scenario=humahuaca` lo abre directo); **D1a** (el Norte conserva su candado; reencadenar Justina → Humahuaca → Norte, D1b, cuesta 6 comprobaciones fijadas y 5 textos y se decide en R4); mini-playtests y sesión humana: **quien el usuario designe**, y si nadie aparece, el agente-jugador los reemplaza y el veredicto dice «no certificado por humanos».

---

## Objeciones y decisiones (revisión final del arquitecto, antes de escribir código)

Un crítico leyó el diseño, el contrato y la rúbrica contra el repo (los ganchos de `main.gd` calzan con el código; los 24 HEX de la lámina 06 son exactos; el terreno no es un problema de rendimiento: `height_at` 3,2 M/s, horneado bicúbico 64 ms, línea de visión 5 µs por rayo) y presentó **27 objeciones: 6 ALTA, 17 MEDIA y 4 BAJA**. Cada una está **resuelta en los documentos** o **rechazada con razón** abajo; las tres piezas se revisaron juntas para que los nombres de archivos, las claves de los JSON, la API, los números de la rúbrica, los tiempos, los comandos y los rangos de semillas coincidan (hecho; ver el final). La columna «Decisión» dice **Aceptada**, **Aceptada con ajuste** (y qué se ajustó y por qué) o **Rechazada**.

| # | Objeción (severidad) | Decisión | Dónde quedó y por qué |
|---|---|---|---|
| O1 | **Alcance:** R2 carga ≈ 3/4 del juego y R1 no tiene salida de emergencia (ALTA) | Aceptada | Se usa la sexta ronda: **R1.0 → R1 → R2a → R2b → R3 → R4** (sección 14 de este documento y sección 8 del contrato). R1 es mínimo (mundo fijo, 9 acciones, geometría toda conocida, torre como temporizador, botín en 5 clases, experto y pasivo, `ui_qa` completo a 1 resolución y desborde a 3); R2a es el núcleo legible; R2b, las variantes de 3 dimensiones, el diario y los bots; a R3, el tutorial, F1, el sonido y las estrategias extra. «Sin esto no se abre R2» pasó a «**cierra con ≤ 3 P1 listados y fechados**». El **orden de descarte** quedó escrito en la sección 14 |
| O2 | **El bucle no puede terminar en «presentable»** sin una sesión humana (ALTA) | Aceptada con ajuste | «Presentable» tiene **dos etapas** (sección 14): la **1** (la firma el circuito: todos los BLOQUEA, **0 ALTA**, ≤ 3 MEDIA con razón, un único commit y el **agente-jugador**) y la **2** (sesión humana de 20 min, aparte y no bloqueante). Agente-jugador y mini-playtest de 10 min: sección 10. **Ajuste:** se conserva el «0 ALTA abiertas» del lead para la salida final (es más estricto que «≤ 2 P1»); «≤ 3 P1 listados y fechados» rige solo para cerrar rondas intermedias. Si el humano no aparece, el QA escribe «no certificado por humanos» y el bucle termina (L1 de `QA_NIVEL2.md`) |
| O3 | **Metas de balance** que no se pueden verificar con 8/12/14 semillas ni con bots propios (ALTA) | Aceptada | Sección 10 reescrita: **compuertas de extremos** (experto ≥ 90 %, pasivo 0 %, ciegos ≤ 5 %) y **de signo** (matriz de contrapesos, señal, extracción); el **obediente y el torpe son informe** con intervalos y ≥ 100 mundos × 3 intentos, nunca P0 ni P1; la matriz completa y el informe corren al cierre de ronda y la compuerta usa 24 mundos. En la rúbrica, J04 quedó con los extremos y el obediente y el torpe pasaron a **J05 (MEDIA)** |
| O4 | **La señal y el alba:** «atacar ya» no tiene contrapeso (ALTA) | Aceptada | Sección 2: la señal se puede dar apenas hay una partida en su puesto; sin señal las partidas **esperan** y a los 6:30 amanece; **costos de la oscuridad** (puntería ×0,4, asalto ×0,8, reconocimiento a 25 m, demora de coordinación a más de 150 m) y **desvelo** (la alerta sube sola desde las 4:30 y el bono de sorpresa es `1 + 0,8 × (1 − alerta)`). Aceptación: **barrido del instante de la señal** (compuerta 7 y J06): máximo único entre 4:15 y 5:45, no en los 3 primeros instantes, meseta ≥ 30 s al 90 %. Se corrigieron las contradicciones del texto (fila de las 4:30, acción 18 y tutorial) |
| O5 | **Extracción:** puntaje resuelto por aritmética, opciones dominadas, historia invertida (ALTA) | Aceptada con ajuste | Sección 7: **destruir ×0,35** con costo real (el humo adelanta el refuerzo 20 s, tope 40 s), **ocultar ×0,7 a salvo / ×0 si el refuerzo lo halla** (tres escondites), **botín del mundo** (corral desbandado, plata ausente, pólvora húmeda), reloj del refuerzo **visible** con su banda, y el epílogo con «en la realidad / en tu partida» por cada una de las 7 piezas. **Ajuste:** no se sube el umbral de victoria (45): con destruir ×0,35, destruirlo todo da 27 y no alcanza. Aceptación: ninguna receta de extracción gana en > 60 % de los mundos y `ocultar` es la mejor en ≥ 1 (compuerta 8 y J06). «Clavar» y tirar víveres se rotulan ▲ (la etiqueta ● cubre solo la munición) |
| O6 | **Templo y figuras** sin base de modelo; Blender se decide tarde (ALTA) | Aceptada con ajuste | Sección 11.2: el canal de arte se **decide en R0**: **generador procedural en GDScript** (templo y 3 arquetipos de figura) por defecto y render héroe aprobado al cierre de R1; **Blender portable es una mejora opcional** que se le pide al usuario sin que nada espere por ella (anexo B). Aceptación medible: AABB del templo ≤ 8 m (el QA tolera 8,5), sin cresta sobre el caballete; 3 arquetipos distinguibles en escala de grises a 48 px (ΔL* ≥ 15) |
| O7 | Se aprueban primeros planos pero se juega a 470 m (MEDIA) | Aceptada | Sección 11.3: **siete** vistas canónicas (se suman `juego_noche` y `juego_alba`, la cámara inicial con interfaz y fichas); lectura por **luz y trazo** (luces como información: brasero, ventana, candil, fogatas); ΔL* edificio–suelo ≥ 12 y ficha–suelo ≥ 25; los tres objetivos identificables en < 3 turnos por el agente-jugador. En la rúbrica: **V06** (nuevo), V01 y V02 |
| O8 | **Métricas visuales** mal definidas (MEDIA) | Aceptada con ajuste | Paleta medida sobre **render de albedo** (`set_albedo_mode`), uniformidad por baldosa 8 × 6 (mínima ≥ 40 % de la mediana; zona lisa ≤ 25 %), lista `must_show` de 5 rasgos por vista antes de pintar, correlación con la foto de 1923 (recortada). **Ajuste:** se agregó la condición «≥ 0,3 sin la tendencia lineal», porque la prueba con un degradé de cielo a suelo mostró que el 0,6 por sí solo lo aprobaba (0,74) |
| O9 | **Integrador único**, vocabulario cerrado, stubs congelados y ciclos de `preload` (MEDIA) | Aceptada con ajuste | T0 se acortó a ganchos, cáscara del controlador, `qa_gate.sh`, pruebas de datos y de humo y ejemplos de forma (6.3); **cada dueño escribe su stub como primer commit de R1.0** (sección 7); **vocabulario por dueño, solo-agregar** (3.0 y V13); **regla de dependencia hacia abajo** con una prueba de grafo (V19); segundo rol de integración «compuertas y documentos» (1.2; puede ser el mismo agente con la misma propiedad de archivos). **Ajuste:** la cáscara de la interfaz la escribe el integrador, porque el gancho de `main.gd` necesita algo que arranque desde el primer día |
| O10 | **Diseño de nivel** repartido y con números duplicados (MEDIA) | Aceptada | Seis JSON: nuevo **`humahuaca_level.json`** (rasgos, accesos, zonas, escondites, luces) de `reglas_historia`; el mapa queda con relieve, superficies, río e hitos; **una sola fuente por número de juego** (el JSON de reglas: radio de toma, ángulo muerto, alcance de ataque); los puestos de ataque se verifican contra `attack_range_m` (V21); el `stub_terrain` ya lee el nivel para calibrar contra muros desde R1; **atlas de rutas** (≥ 2 aproximaciones por objetivo con diferencia ≥ 25 %; compuerta 10) |
| O11 | Dos juegos de bots y 18 estrategias × 96 mundos (MEDIA) | Aceptada | **Una sola biblioteca de políticas** (`humahuaca_policies.gd`, 3.2.5); **8 estrategias de frente** (3 + 3 + 2, las del diseño) en R2b y las recetas de extracción; puntaje continuo `golpe − 0,5 × bajas`; informe siempre por mundo. Las «18» desaparecen |
| O12 | La «brecha de decisión» cuenta ofertas, no decisiones (MEDIA) | Aceptada con ajuste | Sección 10: **decisión significativa por ramificación de snapshots** (mejor y peor opción difieren ≥ 10 puntos o cambian victoria por derrota; ninguna opción es la mejor en > 80 % de los mundos). **Ajuste:** la medida es cara (≈ 6 min para 24 mundos), así que corre al cierre de ronda y en 12 semillas del QA; las ofertas siguen midiéndose en todas las partidas como condición necesaria. J03 mide las dos cosas |
| O13 | **Variantes:** «96 mundos» sin matriz de contrapesos (MEDIA) | Aceptada | Sección 6: **3 dimensiones activas** (guardia, torre, refuerzo = **12 mundos de combate**); las otras tres son candidatas con valor fijo y se activan solo si una prueba de inversión lo justifica (R3); **matriz de contrapesos** escrita antes del código (8 enfoques × 3 dimensiones, con signo y magnitud) y un cálculo de papel que da a cada enfoque ≥ 3 mundos; pruebas de signo y monotonía |
| O14 | **Primer minuto:** una moneda al aire en la oscuridad (MEDIA) | Aceptada | Sección 2: **apertura** de 12–15 s con los tres objetivos iluminados; los reconocedores parten a ≈ 160 m de la batería y la **primera revelación** (cono de luz, «4 centinelas · 3 cañones», con sonido) llega **≤ 40 s**; el informante entra a los 0:45, **con algo ya visto para contrastar**. Aceptación: primer cuadro con 3 objetivos y ≥ 3 puntos de luz |
| O15 | **Ataque dividido:** riesgo de «mirar barras llenarse» (MEDIA) | Aceptada con ajuste | Anillo de recarga de la torre, **cruzar entre descargas** (×0,3 a quien cruza corriendo), ángulo muerto legible, doble pulsación de 1–3 para saltar de frente, microescenas ● del parte (el grito de «viva el rey», los dos caídos, el oficial «a media cuadra»), la descarga que «pareció cañonazo» como evento. Aceptación: ≥ 60 % de las cargas del experto sobre el cuartel salen en el hueco de recarga (compuerta 11). **Ajuste:** el sonido por frente (paneo) va a R3, no a R2 |
| O16 | **Lista negra de jerga insatisfacible:** «LOS» es el artículo «los» (MEDIA) | Aceptada | Lista **cerrada y explícita**: siglas sensibles a mayúsculas (ETA, ZOC, LOS, DPS, HUD, FPS), palabras sin distinguir mayúsculas con límite de palabra, e identificadores snake_case; los textos visibles no se escriben enteros en mayúsculas; V10, C03 y la herramienta del QA actualizados. Aceptación: briefing y 20 textos de acción sin excepciones |
| O17 | **El relieve real no tiene consecuencias de juego** (MEDIA) | Aceptada con ajuste | Sección 4: «*relieve real = base; relieve jugable = capas ▲*»; se suman **barranca del cauce, terraza del núcleo, banco de grava** y explanadas de objetivos, y se reconcilian 25 y 38 m en una explicación con fuente. **Ajuste:** el umbral de celdas con pendiente ≥ 8° es **2,5 %**, no 15 %: la aritmética de áreas (domo ≈ 1,9 %, barranca, terraza y quebraditas el resto) no llega a 15 % sin volver el mapa un barranco; lo que de verdad se exige es que **≥ 3 rasgos verticales cambien la visión o la velocidad** entre pares de puntos |
| O18 | **Fuente DEM**, plan B y prueba de 41 puntos circular (MEDIA) | Aceptada | Sección 4 y contrato 2.1: «relieve de juego» (DEM suavizado a 30 m con filtro de 30–45 m para Copernicus), domo **como residuo** (prominencia sobre el anillo de 120–150 m = 12,0 ± 0,5), **explanadas de diseño** de altura fija respecto del templo (por eso la prueba A/B puede exigir que la diferencia de cota entre objetivos cambie ≤ 1 m), curva de 2 960 m en tres bordes, signo del gradiente oeste → este; se pide la tesela S24 en la pregunta única (anexo B) y se construye con el plan B sin esperar. R05 del QA pasó a medir la prominencia |
| O19 | **Zona definida vs genérica:** sin presupuesto de contenido fuera del núcleo (MEDIA) | Aceptada con ajuste | Micro-relieve de semilla fija, anillo de contenido de 0–400 m (MultiMesh), el mismo shader de suelo para ventana, contexto y horizonte, y la métrica de baldosas (O8). **Ajuste:** micro-relieve de **±0,5 m** (no ±0,3–0,8) y onda ≥ 25 m, para que la pendiente quede bajo 8° y no active la regla de subida |
| O20 | **Gola de la batería al oeste** contradice las fuentes (MEDIA) | Aceptada | La gola mira al **este**, hacia el camino cubierto y el núcleo (rotulada «orientación de la gola ▲»); el flanqueo obliga a entrar al pueblo bajo la torre; distraer abre una tercera vía; la matriz de contrapesos y el atlas de rutas lo prueban |
| O21 | **«Seguir: Sostener el norte» no es continuidad** (MEDIA) | Aceptada | Solo texto: botón del epílogo «Ver la campaña completa: Sostener el norte» y subtítulo del menú «La campaña entera, 1816–1817, vista desde Salta»; no se afirma que el nivel III continúe al II (gancho H2 y 4.2 del contrato; texto obligatorio nº 8 de H03) |
| O22 | **Candado de Humahuaca** y confirmación del alcance (MEDIA) | Aceptada | Humahuaca **siempre habilitado** con la nota «Recomendado tras la Justina» (una línea en `_menu`; el Norte conserva su candado); al cierre de R1, **una captura de la cámara inicial y un sí o no** al usuario (anexo B), junto con los permisos; C04 actualizado |
| O23 | **Regresión en Justina y Norte:** huecos de la compuerta (MEDIA) | Aceptada con ajuste | La compuerta compara contra el **hash fijo `5ebbd28`** y no contra `main`; `test_hx_smoke` hace la **ida y vuelta ×3** con igualdad de estado global y cero nodos huérfanos; **sin `shader_globals` ni ajustes de render** (un `Environment` por escena). **Ajuste:** hash y no etiqueta, porque E05 exige que `git tag --list` quede en `v0.1.0` |
| O24 | **Mínimos de comprobaciones** como meta (BAJA) | Aceptada en parte | Los mínimos son **pisos anti-desactivación por ronda** (5.1 del contrato) y se agrega la **trazabilidad** (`TRAZA.md`, V20) y la **sanidad por mutación** al cierre de R3. No se agrega un ítem de rúbrica: la mutación la hace el QA a mano sobre 8 reglas |
| O25 | **Presupuestos de rendimiento** (BAJA) | Aceptada | Baja ≤ 2,5 · media ≤ 4,0 · alta ≤ 6,0 ms y p95 ≤ 8,3; Justina y Norte siguen en ≤ 3,0; superficies y rasgos se rasterizan una vez; horneado por etapas (11.2, 3.4 y 5.2; T06 y E02) |
| O26 | **Fidelidad:** compresión temporal, ruta de salida, causalidad del briefing, ODbL (BAJA) | Aceptada | Aclaración del tiempo comprimido en el epílogo (14.º texto obligatorio); salida «borde este (▲)»; «El golpe se preparaba desde febrero; la carta solo trae la noticia»; ODbL del subconjunto del río en `map.provenance` y en los créditos |
| O27 | **Inconsistencias internas del contrato** (BAJA) | Aceptada | Cinco corridas degradadas (una por capa); «prominencia» y «delta» reconciliados (residuo); `CREDITOS_RELIEVE.md` propio y V18 alineado, con `docs/CREDITOS.md` concatenado por un único escritor en [final]; ambigüedad de la señal y de la lista negra resueltas (O4, O16) |

**Coherencia entre los tres documentos (revisada punto por punto).** Archivos y carpetas: la tabla de propiedad del contrato (1.2) es la única fuente; el diseño y la rúbrica citan los mismos nombres (`humahuaca_level.json`, `humahuaca_policies.gd`, `hx_agent_play.gd`, `TRAZA.md`, `PLAYTEST.md`, `CREDITOS_RELIEVE.md`). Claves de JSON: propiedad por archivo (V3) con `features`, `access`, `zones` y `hide_spots` en el nivel. Números: cuadro por perfil (T06, E02, 11.2, 5.2), pisos de pruebas (5.1 contra T03), 14 capturas y 7 vistas (diseño, contrato, V01, anexo B), 14 textos obligatorios (H03). Semillas: calibración 8, compuerta 24, informe 2001–2120 y QA 9000–9999 en el diseño, el contrato y la rúbrica. Rúbrica contra diseño: la tabla «Cómo se leen los números del diseño frente a los de la rúbrica» (sección 10) fija qué umbral es de la pista y cuál es del QA (experto 90 % contra 80 % BLOQUEA y 90 % MEDIA; ciegos 5 % contra 10 %; el obediente y el torpe, informe). Tiempos y comandos: los procedimientos P3, P5-d, P6 y P7 del QA se reescribieron contra el diseño 1.1 y las herramientas se **extrajeron del documento y se probaron** contra datos sintéticos y la foto de 1923 (anexo F del QA).

**Preguntas que de verdad necesitan al usuario** (todo lo demás se decidió con un valor razonable y se anotó): (1) permiso para bajar la tesela Copernicus S24 (39 438 103 B); (2) si quiere Blender portable (opcional; 385 412 148 B); (3) el sí o no a «¿es lo que querías?» sobre el reemplazo del nivel 2, con la captura de R1; (4) quién hace los mini-playtests de 10 min y la sesión de 20 min (si nadie, los reemplaza el agente-jugador); (5) copiar a `info/2` el paquete que falta (láminas 01/04/05, tabla de 23 filas) o autorizar abrirlo. Ninguna bloquea R0 ni R1.
