# Plan de rediseño de Güemes: Justina y Norte

Documento de dirección de diseño. Está basado en los resultados de investigación, con lo verificado separado de lo inferido.

## 0. Diagnóstico y principios

La crítica del usuario es correcta y está medida. En Justina el área jugable es de 76x56 m y el 90 % no se pisa nunca. Las unidades se mueven a 0,24 u/s, unas 6 veces más lento que una persona caminando. Solo hay 2 decisiones reales y las dos rutas ganan con 83-87 % de fuerza. En el Norte hay 8 nodos sin geografía, con distancias incoherentes (de 3 a 12 km por unidad) y unidades que se teletransportan. No hay minimapa, brújula ni escala. No hay ninguna imagen de referencia en el repo. `ui_qa` pasa en verde porque mide solapes de paneles, no si el juego se entiende.

**Principios del rediseño**
1. **Una sola escala explícita por escenario.** Se define metros por unidad y velocidades en m/s, derivados de una única fuente de datos (JSON).
2. **Fidelidad con etiquetas honestas.** Lo documentado se dibuja con precisión. Lo inferido se marca como "reconstrucción" en el briefing. No se inventa geografía y se la presenta como cierta.
3. **Dos capas en el Norte.** Un mapa operativo regional con geografía real y escenas tácticas cortas en los lugares de las batallas.
4. **Medir lo que importa.** Se agregan playtests guiados y métricas de legibilidad y ritmo, además de los 47 checks de interfaz.
5. **Conservar el núcleo probado.** Se mantienen la separación reglas/vista, el paso fijo de 0,25 s, el guardado validado, los motivos de rechazo de órdenes, el balance del Norte, el audio y el pipeline GLB.

Nota de nombres: el repo usa "Justine". Las fuentes usan Justina o Justinia. Se unifica como **Justina** en textos visibles y se deja el identificador interno (`justine`) hasta migrar. Esa migración es opcional.

---

## 1. Escala de mapa y escenarios

### 1.1 Justina (12 de agosto de 1806, Retiro)

**Lo que se sabe (usar como ancla):**
- El lugar es **frente al Retiro**, cerca de la batería Abascal, la Plaza de Toros (hoy Plaza San Martín) y la Alameda sobre la barranca. No es Quilmes ni Barragán, que son hechos anteriores y separados. Confianza alta en el Retiro. La equivalencia con la Torre Monumental es de confianza media/baja.
- Era un mercante de 26 cañones (Gillespie, 1818, dominio público). La caballería de Pueyrredón lo tomó al cierre del día "por una súbita bajada del río".
- La distancia a la orilla suele darse como menos de 400 m, y es una cifra de divulgación sin cita primaria. La profundidad final llegaba al pecho o cuello de los caballos, es decir 1-1,5 m. Tampoco tiene sondeo de época.
- Hidrografía (Gillespie): el Plata puede subir o bajar 2,1-2,4 m de golpe por el viento. Hoy los vientos del oeste de 40-60 km/h causan bajantes de unos 1,65 m. El viento del 12 de agosto no está documentado.
- La captura por caballería de Pueyrredón es documental. **Güemes como jefe es tradición, no documento** (Obligado 1920 y Güemes Documentado, no Gillespie ni Concha). Se mantiene la regla actual: tradición no probada.

**Escala y dimensiones propuestas** (1 unidad = 1 m):

| Parámetro | Valor | Estatus |
|---|---|---|
| Área jugable | 900 x 520 m (hoy 76x56) | decisión de diseño |
| Distancia costa-buque | 380 m con el río en su mínimo | dato divulgativo, media |
| Barranca | franja 8-15 m de alto, 120 m al oeste de la línea de agua | reconstrucción |
| Profundidad en el buque al bajar | ~1,5 m | diseño, plausible, no verificado |
| Gradiente medio | ~0,004 m/m, con 2-3 bancos y un canal | diseño, no verificado |
| Bajante | de 0,95 a 0,05 de nivel normalizado ≈ 1,65 m, en 5-6 min de juego | diseño anclado en la cifra moderna |
| Velocidades | a pie 1,3 m/s; trote 3 m/s; galope 7 m/s; en barro 1,0-1,5 m/s; en agua de más de 0,6 m, 0,8 m/s; más de 1,3 m, intransitable para caballos | diseño, valores comunes de equitación |

**Decisiones de abstracción:**
- No se simula el viento real. La bajante es un temporizador visible con barra de nivel y marcas de profundidad.
- La grilla de rutas pasa de 2 u a 4 u para la distancia larga. Cerca de la orilla se usa una malla fina de 1 u. Se agrega suavizado de rutas.
- Se elimina la espera pasiva de 146 s. Mientras baja el río, el jugador reúne grupos, explora, distrae y reconoce bancos.
- El área jugable cubre la franja del Retiro, la Plaza de Toros, la batería Abascal y el agua hasta el buque. Más allá no se dibuja geografía inventada.

### 1.2 Norte (marzo a mayo de 1817 y secuelas hasta enero de 1818)

**Escala de datos:** 1 unidad = 1 km real, con coordenadas geocodificadas por OSM/IGN y proyección plana local.

**Referencias de distancia (verificadas con Google Distance Matrix, carretera moderna):**

| Tramo | km |
|---|---|
| Salta-Jujuy | 125 (recta ≈ 67-70) |
| Jujuy-Humahuaca | 128 |
| Humahuaca-La Quiaca | 157 |
| Salta-La Quiaca | 407 |
| Salta-Cerrillos | 24 |
| Salta-Chicoana | 51 |

**Altitudes** (SRTM, orientativas):

| Lugar | m s. n. m. |
|---|---|
| Salta | ≈1187 |
| Jujuy | ≈1272 |
| Valle de Lerma | ≈1200-1250 |
| Humahuaca | ≈2959 |
| La Quiaca | ≈3452 |

- **Legua:** no usar un valor fijo. Contrastada con la tabla de Concolorcorvo (1773), sale entre 4,6 y 5,4 km por legua según el tramo. La legua queda como etiqueta histórica y el mapa se fija en km.
- **Jornada:** 1 jornada de partida montada es de 35 km. 50 km sería un máximo sin hostigamiento. Un dato de época: La Serna hostigado avanzó 11 leguas en 9 días. Con 14 rondas por partida, el recorrido total (~400 km) equivale a 8-12 jornadas. Es coherente.
- **Capa operativa:** 15-25 nodos hechos a mano con nombre real. Se proponen La Quiaca, Yavi, Humahuaca, Uquía, Huacalera, Tilcara, Perchel, Maimará, Purmamarca, Hornillos, Volcán, Tumbaya, Jujuy, Las Cieneguillas, La Caldera, Salta, Castañares, Cerrillos, Chicoana, Los Sauces, El Pasaje y Rosario de la Frontera. La lista se valida contra `docs/historia`. Los ríos y quebradas son aristas con costo de movimiento. Los vados se cierran con la creciente de verano.
- **Capa táctica:** escenas de 1-2 km de lado (1 u = 1 m) para Humahuaca (1/3/1817), Castañares y Cerrillos (abril de 1817), El Perchel y el Volcán (mayo de 1817). El terreno viene de un DEM de 30 m (Copernicus, SRTM o ASTER). Cada escena dura 1-3 min.
- **Aclaración histórica obligatoria:** la evacuación de Jujuy fue el 21 de mayo y la de Salta el 4-5 de mayo según el repo. Son hechos distintos. Humahuaca el 1/3/1817 es de Arias (regla de CLAUDE.md). San Martín es solo contexto.

---

## 2. Sistemas de juego priorizados

Los costos son estimaciones propias, sin evidencia de desarrollo en Godot.

**P0 (sin esto nada se entiende):**
1. **Datos de escenario en JSON y escala única.** Hoy los límites están duplicados en 3 archivos. Costo medio.
2. **Orientación:** minimapa con cuadro de cámara, brújula, escala gráfica, nombre del paraje siempre visible, líneas de ruta y alcance al seleccionar. Costo medio.
3. **Cámara:** paneo por arrastre y por borde, rotación sin botón medio, objetivo que sigue el relieve, límites según el mapa nuevo, y zoom inicial que no muestre todo el mapa. Costo bajo-medio.
4. **Movimiento real en el Norte:** las unidades recorren las aristas con tiempo de viaje y se ven en el camino. Se reemplaza el teletransporte de `game_rules.gd:653-656`. Costo medio.

**P1 (profundidad de decisión):**
5. **Presupuesto de órdenes por jornada** (Old World): 4-6 disposiciones por jornada que compiten entre sí, con Undo antes de confirmar. Costo bajo.
6. **Reconocimiento y rumores:** tres estados por nodo (desconocido, visto antes, visible). El enemigo aparece como rumor con margen de error. Costo medio.
7. **Emboscada** como preparar, esperar y gatillar, con terreno propicio como quebrada, monte o vado. Si fue detectada, falla. Costo medio.
8. **Suministros y monturas** (víveres, caballadas, municiones), con requisa que baja el apoyo local. Fundamento primario: los partes reales señalan falta de caballos, municiones, chispas y víveres. Costo bajo-medio.
9. **Apoyo del pueblo** (0-100 por nodo habitado): información, comida y aviso del enemigo, o delación. Costo bajo.
10. **Justina con funciones distintas por grupo:** flanquear, distraer la artillería y abordar. Los bancos y el canal ofrecen riesgo distinto. Se agrega una capa de exposición visible. Costo medio.

**P2 (riqueza):**
11. Moral y cohesión de la partida (0-5, con umbrales que bloquean acciones).
12. Chasquis y mensajeros con latencia, interceptables.
13. Fortificar y cortar pasos, y vigilar vados.
14. Clima y estación (lluvia, frío de altura, crecidas).
15. De 30 a 40 eventos de ruta escritos a mano y ligados a lugares y hechos documentados.
16. Selección por caja, formaciones, órdenes con cola y suavizado de rutas.

**Bucle de jornada** (Norte): amanecer y rumores (10 s), disposiciones (45-60 s), resolución y posible escaramuza táctica (15-30 s), anochecer con consumos y eventos (10 s). Partida de 20-35 min. Los tiempos son propuestas a playtestear.

**Se recortan:** 3D libre en el mapa operativo, IA enemiga compleja, y más de 8 sistemas visibles en la primera partida.

---

## 3. Plan de arte e imágenes de época

**Regla de uso:** las imágenes sirven de **referencia y calco** (silueta, trazado, vestimenta, paleta). No se embeben como texturas salvo las marcadas "dominio público". Cada pieza usada se registra en `docs/CREDITOS.md` con autor, fecha, URL y licencia.

**Justina y Buenos Aires:**

| Imagen | Fecha | Licencia | Uso |
|---|---|---|---|
| Vidal, "El Fuerte y la playa baja" | 1816 | PD (Commons) | costa baja y ribera |
| Vidal, "Landing place" | 1816-18 | PD (Getty/Commons) | carretas y caballos entrando al agua |
| Vidal, Plaza desde la Recova | 1817-18 | PD | arquitectura y vestimenta |
| Vidal, aguatero y soldado/escolta | c. 1818 | PD | props y vestuario |
| Vidal, "General view from the Plaza de Toros" | 1816-18 | PD | silueta de barranca y ribera (confirmar en Commons) |
| Plano de Buenos Aires de Boneo y Villalonga | 1801 | PD (AGN/Commons) | manzanas y Retiro |
| Arrowsmith, Chart of the Rio de la Plata | 1807 | mapa PD; imagen Rumsey normalmente CC BY-NC-SA (verificar) | referencia de bancos y canales |
| Gillespie, *Gleanings and Remarks* (carta y pilotaje) | 1818 | PD | cita y referencia |
| Brambila (Malaspina) | c. 1794 | CC BY-SA 4.0 declarada, confirmar en la ficha | solo referencia de silueta |
| Bandera del 71st (Commons) | foto 2021 | CC BY-SA 4.0 (GNC1808) | referencia de bandera, con atribución |

Los demás SVG de banderas (Union Jack, Red Ensign, St Helena) requieren verificar su diseño (la fecha de la cruz de San Patricio) y la licencia de cada archivo.

**No usar como fuente de época:** Fouqueray 1909 (composición de referencia, derechos por verificar), Estruch 1912, Caras y Caretas 1906, Mulhall 1878 y el grabado de 1844. Son reconstrucciones. El grabado de 1807 del Museo Naval de Madrid (Artres) es comercial y no se usa sin licencia.

**Norte:**
- Mapa base: **Moussy, Carte des provinces de Salta et de Jujuy** (1860-64). PD y la mejor cartografía libre con escala, pero es posterior a 1817. Se usa para validar el ordenamiento y la posición relativa, y no se presenta como mapa de 1817.
- Terreno: **DEM de 30 m** (Copernicus, SRTM o ASTER). Es datos abiertos. Se construye el terreno a partir de él, con exageración vertical controlada.
- Grabados: **d'Orbigny** (atlas 1835-47, BHL, PD). Hay que revisar plancha por plancha cuáles muestran Tupiza, Humahuaca, Salta o Jujuy. Joseph Andrews (1827, PD) sirve como descripción verbal.
- Cabildo de Salta: foto c. 1890 (AGN, PD) más fotos modernas como referencia de proporción (CC BY-SA, solo referencia). El edificio fue restaurado y la iglesia de San Francisco actual es del siglo XIX, así que **no representa 1817**.
- Posta de Hornillos: único edificio de posta que sobrevive. Casa baja de adobe con patio y corral. Hay que revisar los derechos de las fotos del museo.
- Vegetación:
  - Valle de Lerma: yungas, selva pedemontana, bosque chaqueño serrano, algarrobo, cebil y mistol.
  - **Cardón:** solo en zonas áridas de valle alto como Cachi, Tin-Tin y Puna. **No en el Valle de Lerma ni en la Pampa.**
  - Churqui, tala, ceibo y ombú: no verificados. No se usan hasta tener fuente.

**Personajes y uniformes (marcar todo como "reconstrucción"):**
- Gaucho del norte: poncho, sombrero de ala ancha, guardamonte (sólido) y lanza. Chiripá y bota de potro no se verificaron para Salta.
- Poncho: rojo liso o con franjas discretas. Las listas negras como luto por 1821 son tradición. Su institucionalización en 1931 y 1971 no es un hecho de 1817.
- Infernales: **uniforme y color en disputa** (rojo, azul, poncho blanco o pardo). Se evita afirmar un color. Se usa una variante neutra marcada como hipótesis.
- Realistas de 1817: **Talavera y Carabineros de Abascal son del ejército realista de Chile, no del invasor de Salta.** No usarlos como unidad salteña.
- Británicos de 1806: el 71st **sin kilt** (trews o pantalón gris, baja confianza). El 20th Light Dragoons no está confirmado en 1806.
- Buque Justina: "merchant ship" de 26 cañones. Sin tonelaje, tipo ni capitán documentados. Se modela genérico y se evitan etiquetas como fragata o goleta.

**Qué necesita del usuario** (nada se descarga sin su sí):
1. **Autorizar las descargas de referencia** (archivo, fuente y tamaño a confirmar al pedirlas):
   - Vidal: 5 o 6 láminas desde Commons.
   - Plano de Boneo 1801.
   - Moussy 1860-64.
   - Láminas de d'Orbigny desde BHL.
   - DEM de 30 m del Norte.
2. **Aportar o gestionar** material del AGN, el Museo Histórico Nacional, el Museo Mitre, el Museo Histórico del Norte (Salta) y planos coloniales de Salta. Allí puede haber imágenes que no encontré. Esto incluye licencias o permisos de uso.
3. **Decidir fidelidad frente a jugabilidad.** Mi recomendación es mapa a escala real en lo operativo y una abstracción reconocible en lo táctico.
4. **Jugar cada escenario una vez** y marcar dónde se pierde o aburre.
5. **Priorizar Justina o Norte.** Recomiendo Justina primero: es más acotada y arregla la queja del "primer escenario".

---

## 4. Pistas de trabajo (archivos disjuntos)

`game_rules.gd`, `main.gd` y `world_view.gd` concentran todo y chocan entre sí. Por eso hay una **Fase 0 secuencial y corta** que las parte. Después se trabaja en paralelo con propiedad exclusiva de archivos.

**Fase 0 (una sola persona o agente, primero):** pista **A, Fundaciones.**
- Crea `data/escenarios/justina.json`, `data/escenarios/norte.json` y `scripts/scenario_data.gd` (el cargador).
- Parte `game_rules.gd` en `rules_core.gd` (paso fijo, generador, guardado), `justina_rules.gd` y `norte_rules.gd`, con una fachada compatible.
- Parte `world_view.gd` en `views/justina_view.gd`, `views/norte_view.gd` y `views/common_view.gd`.
- Extrae de `main.gd` la cámara a `scripts/camera_rig.gd` y el HUD a `scripts/ui/`.
- Criterio de salida: los tests existentes siguen en verde y no hay constantes duplicadas de límites.

**Fase 1 (en paralelo, archivos disjuntos):**

| Pista | Es dueña de | Contenido |
|---|---|---|
| **B. Reglas Justina** | `scripts/justina_rules.gd`, `tests/test_justina.gd` | bajante progresiva, batimetría, velocidades en m/s, grupos con funciones, artillería con exposición, balance |
| **C. Vista Justina** | `scripts/views/justina_view.gd`, `assets/shaders/water.gdshader`, `assets/justina/**` | barranca, costa, Plaza de Toros, batería, buque, bancos visibles, espuma, vida (caballos, marineros, humo) |
| **D. Reglas Norte** | `scripts/norte_rules.gd`, `tests/test_norte.gd`, `docs/BALANCE_NORTE.md` | movimiento sobre aristas, jornadas, suministros, apoyo, reconocimiento y rumores, emboscada, eventos |
| **E. Vista y terreno Norte** | `scripts/views/norte_view.gd`, `tools/build_terrain.*`, `assets/norte/**` | terreno desde DEM, ríos, nodos con carácter, unidades en camino, escenas tácticas |
| **F. Cámara y orientación** | `scripts/camera_rig.gd`, `scripts/ui/minimap.gd`, `scripts/ui/compass_scale.gd` | paneo, rotación, límites desde datos, minimapa, brújula, escala, nombre del paraje |
| **G. Interfaz y control** | `scripts/ui/hud.gd`, `scripts/ui/orders_panel.gd`, `scripts/input_controller.gd` | menos botones, tutorial contextual, paneles plegables, selección por caja, órdenes con cola, suavizado de rutas |
| **H. Arte y licencias** | `assets/ref/**`, `docs/ARTE.md`, `docs/CREDITOS.md` | descargas autorizadas, fichas con licencia, paleta y silueta por zona |
| **I. Historia y verificación** | `docs/historia/**` | cerrar los huecos, validar nodos, fechas y la regla de Güemes y Arias |
| **J. Calidad** | `tools/ui_qa.gd`, `tools/playtest_*.gd` | métricas de legibilidad, ritmo y "tiempo muerto"; capturas por escenario; guion de playtest |

**Puntos de integración** (los gestiona A y los toca solo A, o el orquestador):
- `main.gd` queda como orquestador mínimo y solo importa los módulos.
- Los contratos entre reglas y vista son el esquema JSON y una API de señales documentada en `docs/CONTRATOS.md`.
- Cada pista abre su rama y entrega con tests y una captura nueva.

**Orden sugerido:** A, luego B+C+F+H en paralelo (**Justina primero, con orientación y cámara**), luego G, y finalmente D+E con I. J acompaña todo el tiempo.

---

## 5. Riesgos y lo no verificado

**Históricos y de arte:**
- Del Justina no hay tonelaje, tipo ni capitán, y la distancia de 400 m y la profundidad son de divulgación. No hay plano de la costa de 1806 en el Retiro, y la equivalencia con la Torre es afirmación divulgativa. No hay viento ni nivel del 12/8/1806 documentados. Las cifras de Gillespie (pp. 28-29 y 94) salen de resúmenes del OCR y hay que cotejarlas con el escaneo. El total de efectivos del Justina tampoco está confirmado (100 contra 180 según la fuente).
- El rol de Güemes proviene de tradición y no figura en Gillespie ni en Concha. "Ocampo" no aparece en ninguna fuente y no debe incluirse.
- No hay imágenes de época del Retiro de 1806 ni de Salta entre 1800 y 1820. Lo más cercano es Vidal (1816-18, 10-14 años después) y Moussy (1860-64). Habrá que decir en el juego que son reconstrucciones.
- No se vieron mapas de la zona de 1810-20. Faltan los planos coloniales de Salta y las cartas de la época.
- Uniformes de Infernales, realistas del Alto Perú, artillería y británicos de 1806 sin documento primario. No se pudo leer a Solá ni la bibliografía de Luqui Lagleyze y Fletcher.
- Fechas a confirmar: la evacuación de Salta (4-5 de mayo) se apoya en una cita indirecta. El detalle táctico de Humahuaca del 1/3/1817 no tiene fuente primaria leída.
- Las coordenadas de las localidades se pusieron de memoria y se comprobaron por altitud. Hay que geocodificar con OSM o IGN antes de construir el mapa.

**Licencias:**
- Rumsey (Arrowsmith) probablemente CC BY-NC-SA. No usable como textura en un producto que podría ser comercial. Brambila, el 71st y las fotos modernas son CC BY-SA, que exige compartir igual y atribuir. Por eso se usan como referencia y calco.
- Obras del siglo XX (Estruch 1912, Yglesias 1951) pueden no estar en dominio público en todos los países. No se redistribuyen.
- Los textos de prensa y *Güemes Documentado* tienen derechos. Se parafrasea y no se copia. Los datos de Google Maps son solo de consulta: no se redistribuyen, y las distancias se re-derivan de OSM para el JSON final.

**Técnicos y de producto:**
- Ampliar el mapa multiplica el costo de la grilla A*. Hay que reconstruirla solo por zona y usar malla fina cerca de la orilla.
- El balance actual del Norte (estrategia dominante, victoria en las rondas 10-11) se rompe al agregar sistemas. Se requiere rebalancear y reescribir las pruebas.
- Riesgo de alcance: son más de 15 sistemas. Se mitiga mostrando como máximo 8 en la primera partida y desbloqueando el resto por escenario.
- Los tiempos de partida, las velocidades y las estimaciones de costo son propuestas mías y requieren playtest. No hay referencias directas de Godot para los costos.
- Las referencias de diseño de otros juegos son de confianza media o baja: prensa, wikis y foros, sin postmortems leídos de primera mano. No se identificó "Frontlines".
- Los 47 checks de `ui_qa` en verde no garantizan legibilidad. Sin la pista J, se repite el problema original.
- `docs/ASSETS.md` contradice el código (dice que los GLB de casas y árboles no se usan, pero `world_view.gd:36` los instancia). Hay que corregirlo.

**Higiene de la investigación:** un resultado de búsqueda traía un espejo de Wikipedia con texto incrustado que pedía ignorar instrucciones. Se descartó y no afecta ningún dato de este plan.