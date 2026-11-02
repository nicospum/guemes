# Historia del nivel «Humahuaca»: qué se afirma y con qué certeza

Documento de `reglas_historia` (CONTRATO 1.2). **Estado: R1.** Cuenta qué dice el juego sobre el golpe de Humahuaca (1 o 2 de marzo de 1817), de dónde sale cada afirmación y con qué etiqueta se la muestra. No inventa nada: lo que no tiene fuente figura como diseño o como «sin datos». Los datos y las fuentes viven en `data/history.json` (`scenarios.humahuaca`, fuentes S46 a S54), la matriz de afirmaciones en `docs/DISENO_HUMAHUACA.md` (12.2) y `docs/historia/MATRIZ_HISTORICA.md` (sección J), y la bibliografía en `docs/historia/FUENTES.md`. De dónde sale cada número de juego, en `docs/humahuaca/PROCEDENCIA.md`.

## Las cinco etiquetas

| Id | Glifo | Qué quiere decir | Cuándo se usa |
|---|---|---|---|
| `documentado` | ● | Lo informó su autor, en un documento de época | Partes, oficios y cartas leídos en transcripción. «Documentado» no es «verdadero»: las cifras de un parte son de parte interesada |
| `razonado` | ◇ | Inferencia razonada a partir de lo documentado | Que Portal conociera las calles; que el plan sea anterior a Chacabuco |
| `discutido` | ◆ | Las fuentes se contradicen | El día (1 o 2 de marzo), 150 o 300 atacantes, «ocultos o enterrados» |
| `sin_datos` | ○ | No hay datos suficientes | Qué torre era y dónde estaba; la forma del templo; el cauce de 1817 |
| `diseno` | ▲ | Decisión de diseño del juego | Posiciones, cifras de combate, reparto de hombres, variantes, el refuerzo |

Una entidad mixta lleva como `tag` su parte **más débil** y separa las partes en `tag_parts` (por ejemplo el ataque: el hecho es ●, las cifras son ▲). La fuerza de evidencia va de más a menos: documentado, razonado, discutido, sin datos, diseño.

## Hechos que el juego no puede torcer (banco de hechos de `02_fuentes_primarias.md`, e.3)

| El juego puede decir | El juego no puede decir |
|---|---|
| Güemes, desde Salta, informa a Belgrano y recibe el parte de Arias | Que Güemes lidera el asalto |
| El 25 de febrero llegó a Güemes la noticia de Chacabuco y él la difundió el 26 | Que San Martín ordenó atacar Humahuaca, o que el golpe fue consecuencia de Chacabuco |
| El 20 de febrero Güemes dice haber mandado a Arias a San Andrés para operar contra la guarnición | Que Güemes ordenó tomar la batería, el cuartel y la posta (esa orden no se conserva; los tres objetivos figuran en el parte de Arias) |
| Belgrano esperaba que los realistas se movieran cuando se confirmara el suceso de Chile | Que Chacabuco hizo retirarse a La Serna (la retirada tuvo muchas causas) |
| Güemes era coronel; «coronel mayor» es de mayo | «General Güemes» |

Reglas que salen de ahí y que `test_hx_rules` y los textos obligatorios del QA (H03) fijan: la carta del 26 de febrero es una **dramatización** y «solo trae la noticia, sin ninguna orden»; «el golpe se preparaba desde febrero»; la nota de fecha dice «1 de marzo, según el itinerario de Arias; el 2, según La Serna y una inscripción del premio»; Güemes **recibe** el parte en Salta; el refuerzo es un recurso del juego y no ocurrió; el relieve es dato actual, no restitución del suelo de 1817; el tiempo está comprimido (unas 26 horas de marcha y hora y media de fuego pasan a minutos).

## Qué se afirma y con qué certeza (resumen)

| Afirmación del juego | Etiqueta | Fuente |
|---|---|---|
| Arias dirige el asalto; tres trozos con sus objetivos: batería (Rodríguez), cuartel (Portal y Ontiveros), posta y pólvora (Arias, reserva) | ● | S46 |
| Marcha de unas 26 horas; copiosa lluvia la tarde del 27 de febrero | ● | S46 |
| Lluvia durante la noche del 28 y el alba | ◇ reconstrucción (las horas del parte no se trasladan al reloj) | S46, S54 |
| 150 atacantes «la mayor parte sin más armas que palos»; el Diario realista dice 300 | ● la cifra de Arias · ◆ la discrepancia | S46, S49 |
| Reparto 48/52/50, porcentajes de armas, mulas propias, zona de partida del sudoeste | ▲ | |
| Reconocimiento personal de «tapial, zanjita» | ● el hecho · ▲ posiciones | S46 |
| Descarga «que pareció cañonazo»; el artillero que grita «viva el rey»; los dos caídos de la pólvora; el oficial alcanzado «a media cuadra» | ● los hechos · ▲ el momento y el lugar dentro del mapa | S46 |
| Resistencia desde una torre de 5:00 a 6:30 | ● el hecho · ○ cuál torre y dónde · ▲ cadencia y compresión | S46 |
| Un traidor avisó; la guardia «lo había esperado noches antes» | ● acusación (sin identificar) · ▲ la variante «guardia atenta» | S46 |
| Capilla de Santa Bárbara derribada y batería en esa altura (enero) | ● informe de un informante | S52 |
| Reducto con foso y camino cubierto hacia el pueblo | ◇ | S49 |
| La batería está al oeste, a 12 m de prominencia; la gola mira al este | ▲ (los 12 m son del prototipo; la gola no tiene dato) | S54 |
| Guarnición de unos 130 y 6 o 7 piezas | ● / ◆ | S46, S49 |
| Munición quemada o echada al río; cañones sin llevar; luego recuperados | ● Arias y La Serna · ◆ «ocultos o enterrados» | S46, S49, S50 |
| Clavar los cañones, tirar los víveres, los tres escondites y su distancia al camino | ▲ (ninguna fuente lo dice) | |
| Refuerzo realista inmediato por el camino del sur | ▲ (no ocurrió: se supo el 4 de marzo y las columnas salieron el 5 y el 6) | S49, S50 |
| Parte: 3-III San Andrés, 8-III Salta (22 h), 13-III Tucumán | ● | S46 |
| Seis piezas recuperadas por una columna realista entre el 9 y el 16 de marzo | ◆ versión realista | S49, S50 |
| Medallas en abril; premio posterior al combate; dos banderas tomadas | ● | S51, S53 |
| Planta del pueblo, posición del cuartel, la posta y la torre; vestuario de ambos bandos | ○ / ▲ | |

## Dónde vive cada texto

Los textos visibles salen de `data/humahuaca_rules.json`, no del código: `texts` (objetivo, briefing en dos páginas, carta del 26-II con su etiqueta, nota de fecha, nota del refuerzo, nota del relieve, aclaración del tiempo, «siguiente paso», alertas, eventos, errores), `field_events` (el aviso del alba y el alba), `outcome` (la victoria y las ocho causas de derrota con su texto de 140 caracteres o menos y su consejo), `epilogue.lines` (ocho líneas fechadas, cada una con su etiqueta y su fuente) y `campaign` (el diario, los consejos que rotan y las líneas del parte). La historia larga para quien quiera leerla está en `data/history.json` (18 hechos con sus fuentes) y se muestra en «Historia y reconstrucción».

Epílogo fechado (cada línea con su etiqueta): 3 de marzo (el parte, ●), 4 de marzo (La Serna sabe; no hubo refuerzo inmediato, ●), 8 y 9 de marzo (Mariscal y el parte, ●), 13 de marzo (Belgrano reenvía, ●), 9 al 16 de marzo (**en la realidad** una columna recupera seis piezas, ◆; **en tu partida** lo que pasó con cada una de las siete, ▲), abril (las medallas, ●), 6 de julio (un oficial realista cuenta «la sorpresa de Humahuaca», ●) y marzo a mayo (la resistencia continúa; botón «Ver la campaña completa: Sostener el norte», que cuenta la campaña de 1816 y 1817 desde Salta y de la que Humahuaca es una de sus operaciones: **no** se dice que el nivel III continúe al II).

## Anacronismos evitados

Monumento a los Héroes de la Independencia y escalinata; fachada y torres actuales del templo; cabildo actual como edificio de 1817; empedrado, postes, tendidos, alumbrado, álamos y eucaliptos; sol en la bandera (1818); cruz de Borgoña o bandera española actual para el trofeo; uniformes homogéneos; «todos Infernales»; Güemes entre los grupos del asalto o llamado «coronel mayor»; la chaqueta azul de húsar; San Martín dirigiendo; cierre como expulsión definitiva; tormenta durante todo el combate; la ruta final de Arias; el itinerario de García Camba (de una columna posterior) aplicado a Arias; cotas, alturas de tapias, caudal o vados presentados como medidos; el refuerzo realista presentado como hecho. `tools/qa_gate.sh` y el QA (H02) los buscan por patrón en las cadenas, los identificadores y los nombres de nodos y modelos.

## Qué falta cotejar (no bloquea; queda anotado)

Todo lo documentado se leyó en **transcripción OCR** de Güemes documentado, Torata y Camba, no en facsímil. Quedan sin leer: Güemes documentado t. VII (la inscripción del premio con «2 de marzo») y t. VIII, la *Gazeta de Buenos Aires* original de marzo de 1817, Temple y Mata, y el dossier completo de 52 páginas, el paquete de 39 archivos, las láminas 01, 04 y 05 y la tabla de 23 elementos (no se recibieron: se trabaja con el resumen y lo que falta se rotula como diseño). Ningún texto del juego depende de esas fuentes ausentes.
