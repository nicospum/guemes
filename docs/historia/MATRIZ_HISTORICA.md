# Matriz histórica — Güemes: Juegos de la Patria

Revisión: 28 de octubre de 2026; Justina ampliada el 30 de octubre de 2026 (sección C, paquete P1). Alcance: los dos escenarios del juego. Las páginas indicadas corresponden tanto a la numeración impresa como a la página física del PDF local de *Ideario de Güemes* (424 páginas). Las referencias [S1]–[S8] se desarrollan en `FUENTES.md`.

## Criterio de certeza

**Documentado en transcripción** significa que se leyó un testimonio o parte reproducido en la compilación; no equivale a inspección del manuscrito original. **Síntesis concordante** identifica una interpretación histórica coincidente entre fuentes. **Tradición discutida** conserva la atribución sin presentarla como demostrada. **Reconstrucción** y **regla de juego** identifican decisiones del desarrollo. La fiabilidad de una afirmación no aumenta solo porque la repitan varias notas conmemorativas.

Las cuatro etiquetas que ve el jugador siguen esta regla, y una afirmación lleva la más débil de las fuentes que la sostienen: **Documentado** exige testimonio o documento de época (aunque se lea en transcripción) o un plano de época; **Tradición** es una atribución transmitida y no probada; **Reconstrucción** cubre lo que solo sostienen fuentes secundarias o divulgativas, o lo inferido de planos y vistas posteriores; **Diseño** es regla, cifra o geografía inventada. Un lugar que sale de una fuente divulgativa es Reconstrucción aunque la descripción del objeto sea documentada (ejemplo: el buque es documentado como descripción de Gillespie, pero su lugar de varado es reconstrucción). La definición dada al jugador está en `data/history.json` (`general_notice`) y en `source_tags` de `data/justina_map.json`; ambas deben decir lo mismo (revisión 2026-10-29).

## A. Justina, Reconquista de Buenos Aires

| Hecho o decisión | Fuente y localización | Naturaleza y certeza | Discrepancia o límite | Adaptación autorizada por el dossier |
| --- | --- | --- | --- | --- |
| El episodio se sitúa el 12 de agosto de 1806 durante la Reconquista. | [S1], p. 390; [S2]. | Testimonio retrospectivo de un participante reproducido en compilación; fecha concordante. | Gillespie publicó su relato en 1818; aquí se consultó la traducción reproducida, no su edición inglesa. | Mostrar fecha y contexto virreinal al iniciar la misión. |
| Caballería tomó un buque después de una bajante del río. | [S1], p. 390, fragmento de Gillespie. | Documentado en transcripción. | No prueba un pronóstico de mareas ni las rutas o tiempos exactos. | La bajante abre pasos en la misión. Gillespie describe en el pilotaje caídas repentinas del Plata de siete u ocho pies (~2,1-2,4 m) y las liga a las brisas («reemplazada por D»: la Ronda 1 decía que no las atribuía al viento y era un error); el viento del 12 de agosto no está documentado. El reloj, los umbrales de profundidad y las rutas alternativas son reglas ficticias. |
| Güemes como jefe de la acción. | [S1], p. 33 y pp. 390–392; [S3]. | Tradición discutida. | La p. 33 declara que su intervención no está probada y registra que ese día volvía de Córdoba con los aprendices de música. Gillespie no identifica al comandante. En el relato de Pastor Obligado (1920, p. 391) Güemes es ayudante de Liniers que transmite a Pueyrredón la orden de avanzar con caballería; el jefe de los jinetes sería Pueyrredón. Núñez y la nota oficial [S2] lo presentan «al mando de un grupo de jinetes»; el Gobierno de Salta [S4] lo hace comandar un pelotón de húsares de Pueyrredón. Núñez admite que Obligado incurre en anacronismos, entre ellos el «brillante uniforme» el día de la Reconquista. Revisión 2026-10-28. | Güemes protagoniza una recreación de esa tradición. Advertencia breve visible en el escenario y explicación consultable. |
| El buque era un mercante armado, británico, de 26 cañones, y combatió el día de la rendición. | [S1], p. 390 y pp. 28-29, 94 (Gillespie 1818); [S3] («de bandera inglesa»). | Documentado en transcripción, para la descripción del testigo (revisión 2026-10-29). Esto vale para la descripción del buque, no para su lugar de varado, que es Reconstrucción (fila siguiente). | Cifras de Gillespie leídas en OCR/transcripción; falta cotejar con el escaneo. Sin tipo, tonelaje ni capitán. La denominación «fragata» de notas posteriores no permite convertirlo en un navío de línea. | El juego lo presenta como mercante británico, sin bandera argentina, y con la banda de 13 cañones hacia tierra (el reparto por banda es diseño). |
| El buque varó frente al Retiro, cerca de la Plaza de Toros y de la batería de Abascal. | **No es Gillespie.** Fuentes divulgativas: edisalta ([S3]), La Nación y Recalada (enlaces exactos por incorporar a `FUENTES.md`). La Plaza de Toros figura en el plano de Boneo-Villalonga 1801 (`docs/referencias/justina`). | Secundaria/divulgativa; confianza media-alta en el Retiro, media-baja en cualquier equivalencia moderna. Etiqueta del juego: **Reconstrucción** (revisión 2026-10-29). | Gillespie no da el lugar; la existencia y posición de la batería de Abascal no se cotejó con un plano o documento primario. No se dibuja equivalencia con la Torre Monumental. | La costa inicial queda al pie de la barranca (la de 1806); los ~390 m al buque son una cifra divulgativa que se mide desde el pie de la barranca, no desde una orilla adelantada. |
| La caballería que tomó el buque era la de Pueyrredón. | [S9] solo dice «caballería» («some cavalry», p. 36; «taken by cavalry», p. 94) y no identifica a su jefe. La investigación del repo cita un parte de Concha (15-ago-1806) y un oficio de Liniers (Archivo Pueyrredón, t. I, p. 54) en `docs/investigacion/REDISENO_HALLAZGOS_2026-10-29.json`; ninguno se vio en original. | **Relato posterior o tradición, sin cotejo del original** (Ronda 4: se quita la etiqueta «Documental»; el paquete G2 los trata como «asociados por la tradición a Pueyrredón»). Etiqueta del juego: Reconstrucción para el grupo (cantidad, fuerza y composición: Diseño); Tradición para el vínculo. | No se muestra ninguna cifra de jinetes (el paquete dice 30, 50 o 60 «sin datos suficientes»; la cifra «40 a 60» del repo queda fuera de pantalla). | Gillespie no identifica al jefe de la caballería. |
| Liniers ordenó avanzar por un mensajero; Güemes sería ese mensajero. | Obligado 1920 (vía [S1], p. 391); [S3]. | Tradición / relato secundario (anteojo, mensajero por la Alameda y rendición con pañuelo son de Obligado y divulgación). | Núñez admite anacronismos en Obligado. | La reserva de caballería lleva etiqueta Reconstrucción; la **orden de avance de Liniers** es una regla del juego (etiqueta Diseño sobre fuente secundaria, vigencia de 420 s; la de 300 s de antes quedó reemplazada, ver D) y no afirma que Güemes la lleve. |
| Justine y Justina son variantes usadas por las fuentes. | [S1], p. 390: Justina; [S2]: Justine; [S9] escribe «Justinia». | Variación nominal comprobada. | No se resuelve aquí la historia registral del nombre. | Usar **Justina** en todo texto visible, títulos, órdenes y objetivos (decisión de 2026-10-29); explicar la variante Justine en fuentes. El identificador interno del escenario sigue siendo `justine`. No usar «HMS Leander». |
| Güemes era un joven militar, no el general de 1817. | [S1], p. 33; [S4], nacimiento y carrera inicial. | Edad deducida de 1785: 21 años; cadete en las fuentes revisadas. | Las tradiciones mezclan nombramientos y unidades posteriores. | No llamarlo general en 1806. Vestuario colonial propio de la recreación, sin adjudicar exactitud de regimiento no verificada. |
| No corresponde la bandera argentina ni la División Infernal en 1806. | [S5], origen de la bandera en 1812; [S6], organización de Infernales en 1815. | Cronología concordante. | Las imágenes conceptuales contienen símbolos de épocas posteriores. | Evitar bandera celeste y blanca y rótulo «Infernales» en este episodio. Usar símbolos de selección abstractos claramente pertenecientes a la interfaz. |
| Artillería, aproximación, desmontaje y rendición. | [S1], pp. 390–392. | Amenaza de artillería en Gillespie; rendición en relato tradicional. | No se comprobó la secuencia individual de abordaje ni un combate detallado en cubierta. | Resolver aproximación y captura con una transición a pie. Los grupos, bajas, probabilidades, rutas y oportunidades de acción son ficción jugable. |
| Costa, casas, iluminación y clima de la misión. | [S1], pp. 391–392 para la ambientación de la tradición. | Reconstrucción artística. | No hay levantamiento de la ribera de 1806 en los materiales revisados. | Construir ribera colonial evocativa; no presentarla como reproducción cartográfica o meteorológica. |

## B. Frente norte, campaña de La Serna

| Hecho o decisión | Fuente y localización | Naturaleza y certeza | Discrepancia o límite | Adaptación autorizada por el dossier |
| --- | --- | --- | --- | --- |
| La invasión se desarrolla entre fines de 1816 y 1817. | [S1], pp. 39–41; [S7]. | Síntesis concordante con cronología documental. | La campaña excede una sola batalla; las fechas de cada movimiento no equivalen a rondas del juego. | Campaña comprimida de diciembre de 1816 a primeros días de mayo de 1817. Rondas y agrupaciones son abstracciones. |
| Los realistas ocupan Salta en abril de 1817. | [S1], p. 40 y parte del 25 de abril en p. 219; [S4], 15 de abril. | Documentado en transcripción y síntesis concordante. | Ocupación urbana y capacidad de sostener una campaña son condiciones distintas. | La ocupación temporal modifica recursos y presión; por sí sola no concede victoria realista. Regla alineada (revisión de balance): la ocupación se aplica en la ronda 10 (12–22 de abril), que contiene el 15 de abril; antes de esa ronda el invasor no puede entrar en Salta. Ver docs/BALANCE_NORTE.md. |
| Víveres, animales, caballos y comunicaciones condicionan las operaciones. | [S1], pp. 78, 213 y 219–222; oficio de Carabajal del 2 de mayo. | Documentado en transcripciones y resúmenes de correspondencia. | No se conoce una serie cuantitativa completa de existencias o consumo. | Recursos agregados de abastecimiento y cohesión; proteger poblaciones, retirar suministros, explorar, hostigar y conservar fuerzas. Los valores y fórmulas no son estadísticas históricas. |
| Los problemas de monturas limitan la presión sobre el enemigo. | [S1], pp. 213 y 221. | Documentado en transcripción. | No usar las cifras de un parte como efectivos permanentes en todo el escenario. | Fatiga, conservación y recuperación con coste de oportunidad. Retirarse puede ser una decisión favorable. |
| Humahuaca: referencia del 1 de marzo de 1817; mando de Manuel Eduardo Arias. | [S1], p. 78: parte fechado 3 de marzo en San Andrés; [S8a–c]. | Fecha (1 de marzo) y jefe concordantes con tres notas institucionales; las fechas de mayo del *Ideario* siguen sin verificarse con el documento original (discrepancia marzo/mayo no resuelta; certeza media para marzo). | [S1], pp. 41, 222–223 fecha en mayo un oficio de Güemes (9 de mayo) y un boletín (4 de mayo) sobre Humahuaca. Indicios de error de transcripción: ambos citan *Güemes Documentado* t. 4 pp. 353–359, que en esa obra siguen al oficio del 7 de marzo (p. 350) y preceden al 14 de abril (p. 426); el boletín habla de «el 6 del que rige» siendo del «4»; y el 9 de mayo Salta estaba recién evacuada (5 de mayo). El encabezado de la p. 78 atribuye el parte del 3 de marzo a Güemes, pero se firma en San Andrés, base de Arias. No se inspeccionó el manuscrito ni la edición íntegra. | Operación dentro de la campaña con Arias como jefe de campo. La interfaz no la atribuye personalmente a Güemes ni la fecha en mayo. |
| Objetivos de Humahuaca: golpe a la guarnición y recursos militares. | [S1], p. 78, resumen del parte que refiere armas y pólvora; p. 222, noticia de artillería con problema de fecha. | Base documental parcial más relato institucional secundario; certeza media. | Fundamentos del proyecto 1505-D-2022 [S8c] describen tres columnas: cañones en Santa Bárbara, cuartel y depósito de pólvora, con rendición tras hora y media; coincide con el parte de la p. 78 (tres partes; de las 5 a las 6:30). Es relato secundario y parlamentario; sin plano ni posiciones verificadas. | Puede representarse una operación coordinada contra el abastecimiento o un objetivo agregado. Se usan tres puntos (artillería, cuartel, depósito de pólvora; el texto del juego dice «depósito de pólvora» y no «arsenal»); etiquetarlos como abstracción táctica, no como plano reconstruido. |
| Relación con San Martín y el frente de Chile. | [S7]; [S1], cronología de 1817. | Interpretación estratégica concordante. | No se documenta una llegada de San Martín con un ejército a Salta para resolver esta campaña. | Mantener a San Martín en el frente de Chile. Una noticia por mensajero puede dar contexto; texto y momento de recepción se identifican como dramatización. Chacabuco fue el 12 de febrero de 1817; el juego muestra la noticia en la ronda del 15 de marzo (el *Ideario* p. 39 registra que la Gaceta de ese día celebraba los triunfos de Cuyo); la fecha real de llegada a Salta no se verificó. |
| Retirada de Salta: movimientos del 4 y 5 de mayo. | [S1], p. 41 y parte del 5 de mayo en p. 223; [S4], entrada del 4 de mayo. | Documento transcrito para evacuación al amanecer del 5; síntesis con variantes. | Salta resume la salida el 4; el *Ideario* distingue primera columna el 4 y La Serna el 5. | Desenlace histórico de referencia: **primeros días de mayo de 1817**. La victoria del jugador depende de las reglas de desgaste, no de esperar una fecha automática. |
| El frente norte necesita apoyo de su población. | [S1], pp. 213, 219, 221–224; [S4], dificultades de recursos en 1817. | Síntesis basada en correspondencia. | No todas las poblaciones ni grupos tenían idénticos intereses. | Representar protección y coste social del esfuerzo; no reducir a los habitantes a recursos gratuitos ilimitados. |
| Banderas de 1817. | [S5]. | Cronología institucional. | El modelo oficial con sol se ratifica en 1818. No se verificó aquí cada enseña histórica usada en cada sector. | Evitar el pabellón moderno con sol; los indicadores de bando pueden ser símbolos de interfaz. |
| Sectores, alturas y distancias. | Nombres presentes en [S1], pp. 39–41 y 219–222. | Simplificación espacial. | El mapa no es cartografía operativa ni un relevamiento del terreno de 1817. | Conservar una relación regional coherente: Humahuaca/Tilcara al norte de Jujuy, y Salta/Valle de Lerma al sur. Los enlaces y tamaños se comprimen para jugar. |

## C. Justina: paquete Justina_Retiro_1806 (30 de octubre de 2026)

Qué se tomó del paquete P1 (ver `FUENTES.md`, S13 a S28), qué se adaptó y qué se descartó, y por qué. «Adoptado» = entra en `data/justina_map.json` / `history.json` con la etiqueta indicada; «adaptado» = entra con cambios; «descartado» = no se usa. Los números de ficha son los del informe (A-K).

| Elemento del paquete | Decisión | Etiqueta en el juego | Por qué / dónde |
| --- | --- | --- | --- |
| Cita «boarded, and taken by cavalry», Gillespie p. 94 (B) | Adoptado; **cotejado con el OCR local** | Documentado (descripción) | El texto del paquete coincide con el OCR. Respalda caballería, no jefe ni lugar. |
| Güemes = cadete del Regimiento de Infantería de Buenos Aires (B, G1) | Adoptado | Documentado (adscripción); su papel el 12 = Tradición; presencia = sin datos suficientes | Corrige «cadete de caballería» (S2). No se convierte posibilidad de viaje en presencia comprobada. «Volvía de Córdoba» (Ideario p. 33) queda como dato no cotejado. |
| Nombre Justine / Justina / «Justinia» (B) | Adoptado | Documentado (variantes) | El juego usa **Justina**. |
| Mercante armado británico, no fragata regular ni HMS; Princeps y Saunders (B) | Adoptado | Documentado (mercante); comisión naval = sin datos | Se mantiene sin tipo, tonelaje ni capitán. |
| 26 cañones **en total**, no por banda (B) | Adoptado | Documentado (26); 13 por banda = Diseño | Ya era así; se explicita. |
| Cien marineros de la escuadra, no 180 de Santa Elena (B, G4) | Adoptado | Documentado | `ship.crew_composition`. Los 180 son otra fase. |
| ~400 m «desde las barrancas» (material de 2006, p. 93) (B) | Adaptado | Tradición discutida; el juego usa 390 m desde el pie de la barranca = Diseño | Se unifica el texto y se explica la diferencia de 10 m (cifra de diseño). |
| 30, 50 o 60 jinetes (B) | Adoptado | Sin datos suficientes → Diseño | La cantidad de cada grupo es puntaje de juego; `forces.groups[].headcount_hint` muestra figuras, no efectivos. |
| Bajante súbita; mecanismo local no medido (B, D4) | Adoptado | Documentado el relato; mecánica = Diseño | Estados `tide.states`; la variante principal es banco húmedo. |
| Mesana: daño parcial, no desarbolado (B) | Adoptado | Tradición discutida (palo entero); hipótesis (daño parcial) | `ship.rigging`. |
| Captura «exactamente en la Torre actual» (B, C) | Descartado | Tradición discutida | Se representa una zona (`landmarks.justina.uncertainty_radius_m`, 120 m), no un pin. |
| Contexto actual: Plaza San Martín, Plaza Fuerza Aérea, Torre Monumental (C) | Descartado como geometría | No se dibuja | Solo ayudan a imaginar el bajo; la Torre es de 1916. |
| Georreferenciación experimental (residuo ~17 m) (C, LEEME) | **Descartada** para ubicar el buque | n/d | Residuo interno, no precisión histórica. |
| Área jugable 900 x 750 m (D2) | Conciliada: simulación 900 x 520 + contexto 900 x 750 | Diseño | `DISENO_JUSTINA.md` 1.0 y `context`. |
| Plaza de Toros: existencia 1801, octogonal, ruedo circular, 4 puertas, 90 m entre vértices (F01, E, Pillado) | Adoptado / adaptado | Existencia Documentado; posición Reconstrucción; medidas Diseño | Radio 24 → 45 m (circunradio), ruedo 30 m, altura 9 m (diseño). Orientación de puertas sin fijar. |
| Dependencias militares entre circo y borde (F02) | Adoptado como decorado | Reconstrucción | `scenery.items` (cuarteles bajos). No se importan las obras de 1807 (herrería, arcadas, fortificación). |
| Dos piezas de a 18 de la goleta Dolores, parte de Liniers del 11-ago (F03) | Adoptado en lugar de la «batería Abascal» | Reconstrucción (posición abierta) | Se renombra el hito `bateria_abascal` a «Piezas de a 18 del Retiro» (el id interno se mantiene); la batería Abascal no se cotejó con ningún documento primario. |
| Barranca de 10-12 m y bajada con 8-12 % de pendiente (F04, F05, D2, D4) | Adaptado | Diseño | Barranca 9-14 m. La pendiente de juego (~25-30 %) difiere: ver 1.1 del diseño; el desarrollo de 145 m no cabe sin mover a los grupos. |
| Costa irregular, gradación polvo-arena húmeda-barro-agua; sin línea de agua fija (A, D3, F06-F07) | Adoptado | Reconstrucción / Diseño | Costa, pie y cresta con meandros; `bed_warp`; `tide.states`; paleta de terreno. |
| Alameda del frente central; no extender a todo Retiro (C) | Adoptado (corrige el mapa) | Diseño | De 520 m con arboleda a un tramo de ~125 m sin árboles. La mensajería de Obligado no la exige. |
| Mercante apoyado en banco A; posición B más exterior, alternativa no simultánea (D2) | A adoptada; B registrada | Diseño | `ship.position_candidates`; B no implementada (cambia el balance). |
| Casco 40 x 9 m por comparables RMG (D5) | Adoptado como envolvente visual | Diseño | `hull.length_m/beam_m`; el círculo de 16 m sigue como zona de contacto. |
| Procedimiento final: desmontar y subir por escala/cabo (D5, J) | Adoptado como opción lúdica | Diseño | Coincide con `dismount_s`; los caballos no suben a cubierta. |
| Variante «banco localmente expuesto» (D4, J) | Registrada, no implementada | Diseño | `tide.alternative_variant`; cambiaría el balance y la geografía de bancos. |
| Casas, tapias, carros, bote, vegetación dispersa, huellas (F11, F12, F15, F16) | Adoptado como decorado | Reconstrucción / Diseño | `scenery.items`; sin césped continuo ni arboledas alineadas. |
| Santa Catalina, Fuerte y Plaza Mayor como siluetas (F13, F14) | Adoptado como horizonte | Reconstrucción | `context.skyline`; distancias estimadas, comprimidas. |
| Lista de elementos excluidos y anacronismos (F, H) | Adoptado | n/d | `context.excluded_anachronisms` y `banners.forbidden`. |
| Fichas de personajes G1-G6 (Güemes, jinetes, regulares, marineros, capitán, 71.º) | Adoptado / adaptado | Reconstrucción o Diseño | `characters` y `forces.kits`. G3 y G6 no entran en la escena. |
| Paleta de 12 colores (G7, lámina 04) | Adoptada | Diseño | `palette.package`. Los de terreno y agua son propuesta de Ronda 1. |
| H1 Red Ensign posterior a 1801 | Adoptada como hipótesis dibujable | Reconstrucción | `banners.red_ensign_mercante`; la bandera concreta no está identificada. |
| H2 Union Flag «del Retiro» | Registrada, no dibujada por defecto | Tradición | `banners.union_retiro` (variante opcional). |
| H3 guion del 71.º (MC1256) | Registrado, no dibujado | Documentado como objeto; no situado en el abordaje | Es trofeo del 23-ago. |
| H4 bandera blanca con escudo español del circo (Pillado) | Adoptada | Reconstrucción (inferencia razonada) | `banners.bandera_circo`; sin escudo argentino. |
| H5-H6 pabellones españoles de 1785; H7 coronelas; H8 estandarte de Luján y Húsares | Registrados, no usados | Documentado el diseño; presencia local sin datos | El Estandarte de Húsares es del 21-sep-1806 y no se anticipa. |
| Pistas Morris / Dunn (Schlez) (B, G5) | Registradas, no usadas | No verificado | `characters.capitan_mercante`. |
| Oleo de M. Prieto, Cancio Lazo 2007, Schiaffino (E3) | Descartados como evidencia | Alegorías posteriores | No fijan agua, edificio ni rostro. |

**Revisión de etiquetas que cambia esta sección:** «La Plaza de Toros» deja de ser *Documentado* en bloque (existencia sí; posición y medidas no); «La Alameda» pasa de Reconstrucción a **Diseño**; «Río de la Plata» queda como rótulo de orientación; «La caballería de Pueyrredón» pasa de Documentado a **Reconstrucción**.

## D. Ronda 2 (30 de octubre de 2026): correcciones y qué se tomó de dónde

Correcciones a la matriz anterior tras reverificar Gillespie en el OCR local (`FUENTES.md`, «Cotejo propio Ronda 2»). Las filas de la sección C que digan lo contrario quedan reemplazadas por estas.

| Afirmación | Fuente y localización | Etiqueta en el juego | Cambio / por qué |
| --- | --- | --- | --- |
| La bajada del río se liga a la brisa, y un buque de fuerza quedó «left dry» y fue abordado por caballería | Gillespie 1818, pp. 35-36 (S9) | **Documentado** (el relato); lo concreto del 12/8/1806 (viento, cota, hora) = sin datos | **Corrige** la Ronda 1 («no atribuye la causa al viento»). `time.note`, `tide_gillespie`, hecho «Una oportunidad del río». |
| El juego muestra un banco «parcialmente inundado», no «en seco» | Paquete D4/J; elección de diseño | **Diseño** | Se declara como elección (vado jugable, riesgo de ahogo). Variante «banco expuesto» evaluada y no implementada (DISENO_JUSTINA 2.4). |
| Armadores Princeps y Saunders, de Londres | Gillespie p. 29 (S9) | **Documentado** | Antes citado «según el paquete». `owners_and_trade`. |
| Se había acercado a la ciudad para comerciar | Gillespie p. 94 (S9) | **Documentado** | Hecho que no se usaba; entra en `owners_and_trade` y en la ficha del buque. |
| 26 cañones en total; 13 por banda | Gillespie pp. 29 y 94; reparto = diseño | 26 **Documentado**, 13/13 **Diseño** | Un comentario de `world_view.gd` lo marcaba como documentado (pista Vista). El paquete pide no dibujar 13 idénticos por banda. |
| Dotación: propia + cien marineros de la escuadra | Gillespie p. 94 | Conjunto **Reconstrucción** (partes: refuerzo documentado; total y capitán, diseño) | `forces.opposing.ship_crew` baja de «documentado» a «reconstruccion» con `tag_parts`. |
| Güemes: portador de la orden (Obligado 1920) / jefe de jinetes (notas posteriores) | Obligado vía Luis Güemes (S13); Ideario (S1) | **Tradición** (dos versiones), cadete de Infantería = documentado | Redacción unificada (`texts.briefing`, `source_tags.tradicion`, `forces.groups.guemes.tradition_versions`); rótulo corto «Vanguardia (trad.)». |
| Liniers concede la orden de avance | Obligado 1920 (secundaria) | **Diseño** (regla basada en una fuente secundaria) | Se declara; no es un hecho documentado. |
| Piezas de a 18 del Retiro / campamento de Pueyrredón / puesto de Liniers / camino sobre la barranca | Parte de Liniers del 11/8 solo para «dos piezas de a 18 de la Dolores»; el resto, ninguna | **Hipótesis** de mapa (`marker_style: hipotesis`) | Se dibujan punteados con sufijo «(hipótesis)». |
| Vado del buque a 1,0 m | Paquete D4 propone 0-0,6 m | **Diseño** (desvío documentado) | DISENO_JUSTINA 2.4. |
| Zona de incertidumbre del varado (~120 m) | Paquete B/C («zona, no pin») | **Diseño** | `landmarks.justina.draw_uncertainty_zone`: mancha tenue, no un pin exacto. |
| Rutas central, sur y «mensajero por la Alameda» | Paquete D2 («propuestas»), Obligado | **Diseño** / **Tradición** (la del mensajero) | Bloque `routes`; overlay, no reglas. |
| Casas: lino crudo y tejas apagadas, manzanas con claros de quinta | Vidal (S24), paleta del paquete (04) | **Reconstrucción/Diseño** | `palette.house`, `scenery.house_style/blocks/quinta_clearings`. |

**Pendientes (actualizados):** escaneo de Gillespie pp. 29, 35-36, 94; viento/nivel del 12/8/1806; plano de la ribera de 1806; nómina de jinetes; originales de Obligado, Concha, Liniers; AGN IX-11-5-1 e IX-26-7-7; TNA PC 1/3823; bandera de la presa; decidir con el usuario «banco expuesto» y la posición B del buque.

## E. Ronda 3 (30 de octubre de 2026): Gillespie otra vez, condición del río y etiquetas

| Afirmación | Fuente y localización | Etiqueta en el juego | Cambio / por qué |
| --- | --- | --- | --- |
| Nada fondea con seguridad a menos de cuatro millas, salvo embarcaciones menores; la playa queda seca «por un gran trecho» con las bajadas | Gillespie p. 38 (pilotaje, S9) | **Documentado** (el pasaje); choca con el buque a ~390 m, que es **Diseño** | Antes ignorado. `ship.pilotage_tension`, `tide_gillespie.anchorage_four_miles`, ficha «Agua, banco y estados del río». Los 390 m y el calado quedan declarados como zona de diseño tensa con la fuente. |
| El buque quedó «left dry» (en seco); el juego lo apoya con agua alrededor | Gillespie pp. 35-36 y 94 | Relato **Documentado**; agua alrededor **Diseño** | Se dice en pantalla (`texts.dry_note`, briefing). Decisión pendiente del usuario: banco expuesto. |
| Buque «manned» con oficiales y cien marineros, además de su dotación | Gillespie p. 94 | **Documentado** (refuerzo); «armado» era una adición | «Armado» pasa a «tripulado». Marineros: **Reconstrucción** en `historical_figures_roles` (la parte más débil: total y vestuario son diseño). |
| Los 180 hombres de Santa Elena (embarcados en el Justinia) no estaban a bordo el día 12 | Gillespie pp. 28-29; inferencia | **Reconstrucción** (inferencia razonada) | Gillespie no dice cuándo desembarcaron. No se pueblan la cubierta con ellos hasta otra prueba. |
| «El Retiro, o Plaza del Toros» da nombre al sitio; sargento y 17 soldados británicos allí el 10 de agosto; el buque batía «la playa y las calles» | Gillespie pp. 121, 94-95, 94 | **Documentado** (contexto) | Refuerza la existencia de la Plaza de Toros. `context.gillespie_retiro`. |
| Liniers como jefe de la Reconquista; concede la orden de avance | Documentado (jefe); Obligado 1920 (orden) | Rol **Reconstrucción** con `tag_parts` {jefe: documentado, orden: diseno} | Antes `documentado` a secas: sobreetiquetado. |
| Distancias Retiro-Santa Catalina (1 km) y Retiro-Fuerte (2 km) | Estimación del repo, sin medir | **Diseño** (estimación); el hito es Reconstrucción | Antes Reconstrucción. Ronda 4: el Fuerte se midió contando cuadras en Boneo 1801 (ver sección F). Santa Catalina sigue sin medir. |
| Costa casi N-S frente a diagonal NO-SE del paquete | Ninguna: geometría de diseño en ambos | **Diseño** | `context.geometry_note`: ninguna es histórica. |
| La bajante cambia entre partidas (brisa ordinaria, sostenida, lenta, que cede pronto) | Gillespie liga el nivel a las brisas casuales | **Diseño** | `time.variants`. Ninguna variante reconstruye el 12/8/1806 (sin serie de viento ni nivel). |

**Pendientes (actualizados a la Ronda 3):** escaneo de Gillespie (hoy OCR) pp. 28-29, 35-38, 94-95, 121; Concha 15-ago y oficio de Liniers (solo vistos por cita); parte de Liniers del 11-ago (dos piezas de a 18, segunda mano); cifra de 1801 de la Plaza de Toros (paquete y Pillado, sin ver la fuente); Ideario p. 33; temporal/sudestada del 4 al 8 de agosto (investigación info/, no cotejada); distancias a Santa Catalina y al Fuerte sobre plano; viento y nivel del 12/8/1806; plano de la ribera; nómina de jinetes; originales de Obligado; AGN IX-11-5-1 e IX-26-7-7; TNA PC 1/3823.

## F. Ronda 4 (30 de octubre de 2026): mapa e historia

| Afirmación o elemento | Fuente (qué se tomó de dónde) | Etiqueta | Cambio en esta ronda |
| --- | --- | --- | --- |
| Costa irregular y en diagonal NO-SE, sin línea de agua fija | Paquete A, D2 y F (lámina 02, prototipo 900 x 750 m); no hay coordenadas de 1806 | **Diseño** | La costa y la barranca se inclinan ≈8,5° (`bed_warp.tilt_k` = 0,15, pivote z = 262) en lugar de una recta N-S. Se queda corto del 45° del paquete a propósito (balance). |
| Área jugable 900 x 750 m | Paquete D2 (elegida por diseño, origen arbitrario) | **Diseño** | Se mantiene 900 x 520 m y 115 m de contexto por lado; la razón es el balance (DISENO_JUSTINA 15.1). Se dice en pantalla (`texts.map_decisions`). |
| Fuerte a ≈1,5 km del circo | Boneo y Villalonga 1801 (copia local): ≈13 cuadras entre la Plaza de Toros y el Fuerte; cuadra supuesta de 140 varas (≈117 m) | **Diseño** (medida gruesa ±20 %) | Pasa de 2 km (estimación) a 1,5 km (conteo). Los rumbos (170°, 185°, 200°) siguen siendo estimación y ya no se muestran (`context.skyline[].bearing_visible` = false). |
| Santa Catalina a ≈1 km | Sin medir: no se identificó la iglesia en la copia de Boneo | **Diseño** (estimación) | Sin cambio; pendiente. |
| Liniers: jefe de la Reconquista; dos piezas de a 18; orden de avance | Parte de Liniers del 11-ago reproducido en [S13] (segunda mano); Obligado 1920 para la orden | **Reconstrucción** con `tag_parts` (jefe: Documentado; piezas: Reconstrucción; orden y mensajero: Diseño) | Se unifica con `historical_figures_roles`; la ficha lleva la etiqueta de la parte más débil. |
| Pueyrredón al frente de la caballería del abordaje | Concha y Liniers solo por cita; paquete G2 | **Tradición** (vínculo) / Documentado (su rol en la Reconquista) | Se baja de Reconstrucción a Tradición para el vínculo; el briefing deja de nombrar a Concha y Liniers como verificados. |
| Güemes jefe o mensajero | Obligado 1920 vía [S13]; Gillespie no lo nombra | **Tradición** | Sin cambio. El kit visual sigue sin insignias de mando. |
| Banco apoyado frente a «left dry» | Gillespie pp. 35-36 y 38 | **Diseño** | Sin cambio de reglas; se agregan `ship.grounded_visual` (cómo debe verse apoyado) y `ship.position_note`. La variante «banco expuesto» sigue pendiente de decisión del usuario. |
| Banderas: Red Ensign (hipótesis), bandera del circo (inferencia), Union «del Retiro» (tradición), guion del 71.º (trofeo), 1785 naval y mercante español (diseño vigente), borbónicas (omitir) | Paquete H1-H8 [P1], Pillado, Trofeos 1882 | Cada una con `status` y `status_label` | `banners.group_markers`: los guiones de color de los grupos son marcadores del juego, no estandartes históricos. |
| Cronología 10-ago, 11-ago, 12-ago, 23-ago, 21-sep, 1807 | Gillespie pp. 94-95; [S13]; Trofeos 1882; paquete B | Por hito | `milestones` nuevo, con `in_game`. |
| «Recreación histórica» | Rótulo del menú | — | `general_notice` pasa a «Reconstrucción jugable». Quedan «Recreación» en `scripts/main.gd` (líneas 405 y 910): es de la pista de UI. |

**Pendientes (Ronda 4):** escaneo de Gillespie; Concha 15-ago y oficio de Liniers en original; parte de Liniers del 11-ago; Santa Catalina sobre plano; decisión del usuario sobre el banco expuesto; originales de Obligado; AGN IX-11-5-1 e IX-26-7-7; TNA PC 1/3823; serie de viento y nivel del 12/8/1806; plano de la ribera.

## G. Ronda 5 (30 de octubre de 2026): mapa e historia con el paquete completo

| Afirmación o elemento | Fuente (qué se tomó de dónde) | Etiqueta | Cambio en esta ronda |
| --- | --- | --- | --- |
| Dos piezas de a 18 en el Retiro | Parte de Liniers del 11-ago vía [S13] (segunda mano); paquete F03 («emplazamiento abierto») | Existencia: **Reconstrucción**; emplazamiento, alcance de 600 m y parapeto: **Diseño** | Se dibujan **dos** (antes cuatro con siete gaviones) y el hito pasa a Diseño con sufijo «(diseño)». |
| El buque batía playa y calles | Gillespie p. 94 («not only along the beach, but in the different streets») | **Documentado** (el testimonio); el alcance de 265 m es **Diseño** y lo contradice | `ship.fire.p94_tension`; anillo visual de 420 m no simulado (`cover_zone`). |
| Plaza de Toros «inaugurada en 1801» | Boneo 1801 la muestra; el año de inauguración viene del paquete y de Pillado, sin fuente primaria vista; Gillespie p. 121 es retrospectiva (una sola corrida) | Existencia **Documentada**; fecha **sin fuente primaria** | «En uso desde c. 1801»; la cita de p. 121 conserva su matiz. |
| 26 cañones y armadores | Gillespie p. 28 (26 cañones) y p. 29 (Princeps y Saunders) | **Documentado** | Se corrige la página (antes «p. 29» para los 26). |
| Perros del Retiro la noche del 11 | Gillespie p. 95 | **Documentado** | Hito `noche_11` y `tide_gillespie.dogs_p95`. |
| Acantilados del Retiro «a poca distancia del Plata» | Gillespie p. 274 (septiembre de 1807) | **Documentado** para 1807 | Respaldo de la barranca cercana al agua, con el aviso de la fecha. |
| Cuarteles, casas, manzanas, tapias, costa irregular | Paquete F02/F12 («huellas y alturas sin datos», «lotes no reconstruidos») | Existencia/área: **Reconstrucción**; huella y volumen: **Diseño** | Etiquetas bajadas a Diseño con `tag_parts`. |
| Campamento de Pueyrredón | Obligado 1920 (secundaria); sin cotejo | **Tradición**; posición **Diseño** | Antes Reconstrucción. |
| Cantidad de jinetes | Parte de Concha del 15-ago citado en la investigación de apoyo (S41); el informe dice 30, 50 o 60 «sin datos suficientes» | **Reconstrucción** sin cotejo | No se muestra cifra; `forces.groups.zavala.composition` registra el orden de magnitud. |
| Pabellón del buque | Paquete H1; Perrin 1922; RMG AAA0773 | **Reconstrucción** (hipótesis) | El cantón lleva las aspas de la Union de 1801 (`canton_layers`). |
| Bandera del cuartel | Paquete H7 (omitir) | **Diseño** (opcional) | `bandera_cuartel` con aspa de Borgoña; se prohíbe el círculo/cuadrado rojo centrado. |
| Colores de unidad | Paquete G7 («no usar colores como prueba infalible de bando») | **Diseño** | Marcadores neutros y asta oscura de 3-4 m (`group_markers`). |
| Güemes protagonista | Obligado 1920 vía [S13]; Gillespie no lo nombra | **Tradición** | `texts.result_contrast`: la pantalla de resultado contrasta la versión de Gillespie con lo jugado. |
| Bajada de 8-12 % | Paquete D2/D4 | **Diseño** | Pendiente de juego sin cambio; `visual_path` con el desarrollo largo, solo visual. |
| Texto de producción en el briefing | — | — | Eliminado de los textos del jugador. |

**Pendientes (Ronda 5):** playtest humano; banco expuesto; fuente primaria de 1801; Gillespie en el escaneo; Concha 15-ago, oficio y parte de Liniers del 11-ago en original; Obligado 1920; AGN IX-11-5-1 e IX-26-7-7; TNA PC 1/3823; serie de viento y nivel del 12/8/1806; Santa Catalina sobre Boneo.


## H. Ronda 6 (30 de octubre de 2026): mapa e historia

| Afirmación o elemento | Fuente (qué se tomó de dónde) | Etiqueta | Cambio en esta ronda |
| --- | --- | --- | --- |
| Reserva de caballería «de Pueyrredón» | Gillespie solo dice «caballería» (pp. 36, 94); el nombre es relato posterior | **Tradición** (afirmación más débil) | Antes Reconstrucción; cantidad y composición siguen en Diseño |
| Camino sobre la barranca | Ninguna; la Alameda documentada es la del frente central (paquete C) | **Diseño** | Se llama «Camino de la barranca (diseño)», ya no «Alameda»; el sufijo va en el nombre |
| Goleta del teniente Herrick cañoneando el campamento de Liniers | Gillespie p. 93 (OCR) | **Documentado** (testimonio retrospectivo); relación con el Retiro y las piezas de a 18: sin datos | Hecho nuevo en `history.json` y `gillespie_context_p93`; no entra en las reglas |
| Nivel del río del HUD (1,65 m) | Ninguna: valor de juego | **Diseño** | `tide.hud_label` = «Nivel de juego (diseño)» |
| Banco expuesto (casco «left dry») | Gillespie pp. 36-38 | Variante más cercana al testimonio; **no incluida** | Se documenta por qué (quita el riesgo de ahogo) |
| Aspecto: casas, circo, campo, perfil urbano | Vidal (c. 1817-20), Boneo 1801, Arrowsmith 1806, Gillespie | Reconstrucción / Diseño | Tabla completa en `PROCEDENCIA_VISUAL.md` |
| Textos con notas de producción | — | — | Se quitan «Ronda N», rutas de docs y «el paquete» de lo que ve el jugador |

**Pendientes (Ronda 6):** playtest humano (la tasa de 40-60 % sigue siendo de guiones); cotejo de Gillespie pp. 93-94-121 en el escaneo; fuente primaria de 1801; Concha 15-ago y oficio de Liniers; Obligado 1920; AGN IX-11-5-1 e IX-26-7-7; TNA PC 1/3823; retinte de caballos y jinetes y lectura de `cover_zone`, `marker_suffix` y `banners.*` por la vista (otra pista).

## Límites y compromisos de presentación

- Los desenlaces alternativos son resultados de una partida, no nuevos hechos históricos.
- Los diálogos, textos de órdenes y noticias redactados para el juego son dramatización salvo que se identifique una cita con fuente localizable.
- La proporción de figuras en pantalla representa agrupaciones: no reproduce el número exacto de soldados.
- Las imágenes conceptuales son referencias de atmósfera. Sus banderas, nombres, edades, dimensiones y frases no prueban hechos.
- No se revisaron linealmente las 424 páginas ni todos los originales archivísticos citados por la compilación. Se verificaron directamente las páginas pertinentes y las fuentes públicas indicadas.
- Puesto del Marqués, 14 de abril de 1815, queda fuera de estos dos escenarios.

Esta matriz es un contrato de contenido para la implementación. La inclusión de una adaptación en ella no acredita que la mecánica correspondiente ya esté implementada o probada; eso se documenta en el informe de versión y QA.

## I. Ronda 7 (30 de octubre de 2026): etiquetado y ubicación

| Afirmación o elemento | Fuente (qué se tomó de dónde) | Etiqueta | Cambio en esta ronda |
| --- | --- | --- | --- |
| Reserva de Pueyrredón | Gillespie dice «caballería»; el nombre es relato posterior | **Tradición** (vínculo), Diseño (cantidad) | Etiqueta única en `groups` y `forces` |
| Ubicación del varado frente al Retiro | Divulgación S3, S10, S11; no Gillespie | **Reconstrucción**, rotulada «ubicación hipotética»; más débil que la Plaza de Toros (Boneo, UWM, Vidal) | Anillo de ±120 m desde el inicio |
| Liniers avanza contra un sargento y 17 hombres (10-ago) | Gillespie pp. 94-95 (OCR) | Lectura nuestra, no «Retiro tomado» | `verification: lectura_gillespie` |
| Acta del Cabildo 23-ago, estandarte 21-sep, 1807, junio de 1806 | Solo paquete P1 | **Reconstrucción** («dato del paquete, sin cotejo») | Bajan de «documentado» |
| Goleta de Herrick | Gillespie p. 93 | Documentado (hecho); lugar no consta, probablemente no el Retiro (inferencia) | Se retira «6-9 de agosto» y «otra costa» |
| Justina «para comerciar» | Gillespie p. 94 «traffic» vs. pp. 28-29 | Lectura nuestra, sin resolver | Rebajado |
| Alcance de fuego del buque | Gillespie p. 94 (playa y calles) vs. 265 m de juego | Diseño; anillo de 420 m «no simulado» | Rótulos en pantalla |
| Abordaje disputado | Gillespie: toma «al cerrar el 12» | La dotación contraatacando es Diseño | `texts.boarding_not_described` |

**Pendientes (Ronda 7):** playtest humano; banco expuesto; cotejo de pp. 93, 94, 121 con el escaneo; Concha, oficio y parte de Liniers en original; Obligado 1920; fuente primaria de 1801. El georef del paquete NO se usa.

## J. Humahuaca, ronda R1 (2 de noviembre de 2026): qué se afirma, de dónde y con qué etiqueta

Afirmaciones del nivel II («Humahuaca: el depósito de la retaguardia», 1 de marzo de 1817). El detalle por afirmación está en `docs/humahuaca/HISTORIA.md`; la procedencia de cada cifra, en `docs/humahuaca/PROCEDENCIA.md`; los textos, en `data/history.json` (`scenarios.humahuaca`, 18 hechos) y `data/humahuaca_rules.json`. Una entidad mixta lleva la etiqueta de su parte más débil. Las fuentes S46 a S54 figuran en `FUENTES.md`.

| Afirmación o elemento | Fuente (qué se tomó de dónde) | Etiqueta | Cómo se muestra |
| --- | --- | --- | --- |
| Arias dirige el asalto, en tres trozos: batería (Rodríguez), cuartel (Portal y Ontiveros), posta y pólvora (Arias, de reserva) | S46 | **Documentado** (el hecho) · Diseño (reparto 48/52/50, armas, mulas propias) | `groups`, briefing |
| Güemes conduce desde Salta, informa a Belgrano y recibe el parte; no está en el asalto | S46, S48 | **Documentado** | briefing y epílogo |
| Carta del 26 de febrero | S47 | **Documentado** (existe y no trae órdenes) · Diseño (el texto del juego es una lectura adaptada) | briefing, rotulada «dramatización» |
| Marcha de unas 26 horas; lluvia copiosa la tarde del 27 | S46 | **Documentado**; la lluvia de la noche y el alba, Razonado | `environment.segments` |
| 150 atacantes «la mayor parte sin más armas que palos»; el Diario realista dice 300 | S46, S49 | **Documentado** la cifra de Arias · **Discutido** la discrepancia | `groups` |
| Reconocimiento de «tapial, zanjita» | S46 | **Documentado** (el hecho) · Diseño (posiciones y alturas) | `features` |
| Descarga «que pareció cañonazo», artillero que grita «viva el rey», dos caídos de la pólvora, oficial alcanzado «a media cuadra» | S46 | **Documentado** (los hechos) · Diseño (momento y lugar dentro del mapa) | eventos del alba |
| Resistencia desde una torre, de 5:00 a 6:30 | S46 | **Documentado** el hecho · Sin datos (qué torre y dónde) · Diseño (cadencia; compresión a unos 90 s) | `tower`, variante de torre |
| Un traidor avisó; la guardia «lo había esperado noches antes» | S46 | **Documentado** como acusación sin identificar · Diseño (variante «guardia atenta») | briefing, variante |
| Capilla de Santa Bárbara derribada y batería en esa altura (enero) | S52 | **Documentado** (informe de un informante) | batería al oeste |
| Reducto con foso y camino cubierto hacia el pueblo | S49 | **Razonado** | `features.camino_cubierto` |
| Altura de 12 m y gola al este | Ninguna fuente | Diseño | batería |
| Guarnición de unos 130 y 6 o 7 piezas | S46, S49, S50 | **Documentado** · Discutido (las cuentas difieren) | `objectives` |
| Munición quemada o echada al río, cañones sin llevar, luego recuperados | S46 (lo quemado y lo no llevado); S49, S50 (la recuperación posterior) | **Documentado** (Arias) · **Discutido** («ocultos o enterrados», según el Diario y Camba) | tratamientos del botín |
| Clavar los cañones, tirar los víveres, los tres escondites y su distancia al camino | Ninguna fuente | Diseño | acciones |
| Refuerzo realista por el camino del sur durante la extracción | S49, S50 (se supo el 4-III; salieron columnas el 5 y el 6) | Diseño: **no ocurrió** | nota de pantalla |
| Fecha: 1 de marzo (itinerario de Arias, Diario) o 2 (prisioneros, La Serna, inscripción del premio) | S46, S49, S50, S53 | **Discutido** | nota de fecha en pantalla |
| Parte del 3-III (San Andrés), 8-III Salta (22 h), 13-III Tucumán | S46, S51 | **Documentado** | epílogo fechado |
| Seis piezas recuperadas por una columna realista entre el 9 y el 16 de marzo | S49 (Diario del Estado Mayor realista), S50 (Camba); **no** el oficio de La Serna (H03) | **Discutido** (versión realista) | epílogo, «en la realidad»; `history.json`, «Lo que contaron los realistas» |
| Plata en «tres cargas» | S51 | **Discutido** (de oídas de Portal) | no entra en el botín |
| Medallas de abril, premio posterior al combate, dos banderas tomadas | S51, S53 | **Documentado** | epílogo |
| Planta del pueblo, posición del cuartel, la posta y la torre; vestuario de ambos bandos | Ninguna fuente | Sin datos / Diseño; el relieve es dato actual, no restitución de 1817 | rótulo de relieve |

**Lo que el juego no afirma:** que Güemes lideró el asalto; que San Martín ordenó atacarlo; que fue consecuencia de Chacabuco ni que Chacabuco hizo retirarse a La Serna; que el refuerzo realista fue un hecho; que hubo bandera argentina o sol en las partidas; «coronel mayor» (es de mayo); cotas, alturas o vados como medidos.

**Compromisos de presentación:** el desenlace de una partida es un resultado de esa partida, no un hecho nuevo; las órdenes y avisos redactados para el juego son dramatización; el tiempo está comprimido (unas 26 horas de marcha y hora y media de fuego pasan a minutos); la proporción de figuras representa agrupaciones.

**Pendientes (R1):** cotejo con facsímil del parte y de la carta del 26-II; t. VII y VIII de *Güemes documentado*; *Gazeta de Buenos Aires* de marzo de 1817; el dossier completo y las láminas que no se recibieron; playtest humano (a cargo del QA de la ronda).

**Corrección H03 (2 de noviembre de 2026, rama `hx-docs-nube`).** El epílogo del 9 al 16 de marzo decía «según La Serna recupera seis piezas…» con fuente «Oficio de La Serna, 11-IV-1817». La recuperación de las piezas, el lugar (cerca de San Andrés) y la frase «por falta de acémilas» están en el Diario del Estado Mayor realista (S49) y en las Memorias de Camba (S50), que son las fuentes que este repositorio tiene leídas; el oficio de La Serna no se cita para ese detalle. Corregidos: `data/history.json` (hecho «Lo que contaron los realistas»), esta sección, `docs/humahuaca/HISTORIA.md` y `docs/DISENO_HUMAHUACA.md` (11.5 y 12.2). Pendiente de la pista `reglas_historia`: la línea `epilogue.lines[4]` de `data/humahuaca_rules.json` (texto listo en `docs/humahuaca/TEXTOS_REVISION.md`). Sin cotejo en el repo: la cita del oficio de La Serna («se ha logrado quitarles los seis cañones») que trae el banco de hechos `02_fuentes_primarias.md`, que no está en Git.
