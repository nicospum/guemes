# Ingeniería inversa de juegos locales (R8): qué hay instalado y qué dinámicas sirven a Justina

Fecha: 30/10/2026. Alcance: aprender mecánicas de juegos de estrategia/guerra presentes en esta máquina para un cruce táctico en tiempo real con pausa (Justina). Solo lectura: no se modificó ni borró nada de los juegos ni de sus partidas; las bases de datos se copiaron a una carpeta temporal de la sesión y se consultaron en modo solo lectura. No se copian assets ni código; los textos del juego se parafrasean. Ninguna clave ni dato personal entra en este informe (el perfil de AoE3 contiene un GUID y nombre de usuario de Steam: no se reproducen).

Convención: **[DATO]** = leído en un archivo local (ruta + valor); **[INF]** = inferencia mía; **[NO VERIFICADO]** = no se pudo comprobar.

## 1. Descubrimiento: qué hay realmente instalado

Biblioteca Steam única: `C:\Program Files (x86)\Steam` (`steamapps/libraryfolders.vdf` lista solo esa ruta). Epic, GOG y Ubisoft: sin manifiestos ni juegos (`C:\Program Files\Epic Games` y `(x86)\Epic Games` vacías; `C:\ProgramData\Epic` y `\GOG.com` inexistentes).

**Hallazgo central: casi ningún juego militar de la lista está instalado hoy.** Las carpetas de `steamapps/common` de los títulos de guerra son cáscaras con 0 a 3 archivos. Hay apenas 7 `appmanifest` y todos son de gestión/deportes (Ultimate MMA, Tennis Manager 2023, Football Manager 2011/26/Editor, MMA Simulator, redistribuibles).

| Juego | Estado local [DATO] | ¿Datos de reglas legibles? |
| --- | --- | --- |
| Sid Meier's Civilization VII | `common/Sid Meier's Civilization VII/Base` y `Binaries` existen **vacías** (0 archivos). El informe previo `CIV7_OBSERVACION.md` leyó XML de `Base/modules`: ese contenido ya no está (desinstalado desde entonces). Quedan logs y partidas del usuario | Solo logs de IA (ver 3.3). No hay XML |
| Civilization VI | No hay carpeta en `common`, pero sí **caché de bases de datos de reglas** en `%LOCALAPPDATA%\Firaxis Games\Sid Meier's Civilization VI\Cache\` | **Sí, completo**: `DebugGameplay.sqlite` (5,7 MB) y `DebugLocalization.sqlite` (64,9 MB) |
| Old World | `common/Old World/` solo `GfxPluginEOSInit.log`. Quedan partidas y opciones en `Documents\My Games\OldWorld` | Parcial: guardado XML de un escenario tutorial + `hotkeys.xml` |
| Age of Empires III DE | Sin carpeta de juego. Datos de perfil en `C:\Users\User\Games\Age of Empires 3 DE\<id_steam>\` | Parcial: un script de campaña `Trigger\trigtemp.xs` (XS) |
| Star Wars Empire at War | `common/Star Wars Empire at War/` 3 archivos (0,8 MB, textos/rec). Partidas en `Saved Games\Petroglyph\Empire At War\Save` (3 archivos, 16 MB) | Parcial: Lua serializado de la IA dentro de los guardados |
| Napoleon Total War, Total War Saga Troy, A Game of Thrones, Arma 3, Galactic Battlegrounds Saga, Patron, Kenshi, Cities Skylines | 0 a 3 archivos sueltos (vdf, log, txt). Arma 3: 0 archivos | No |
| Age of Civilizations II | `common/AoCII` 48 archivos (5 MB): solo `saves/` y `settings/` | No relevante (sin reglas) |
| Otros | `C:\Jeux\ABWFR\InTheFirstDegree` (DOSBox, juego de misterio legal de 1995), Football/Tennis/MMA Manager, F1 Manager | Descartados: no son militares |

Comprobaciones: `Get-ChildItem -Recurse` sobre cada carpeta de `steamapps/common`; conteos y tamaños arriba de cada fila.

### Sobre REA
Se cargaron las herramientas REA y se evaluó su uso. **No se abrió ningún ejecutable de juego**: no queda ningún `.exe` de un juego militar en disco (Civ VII `Binaries` vacía; el único `.exe` de juego restante es `DEGREE.EXE` bajo DOSBox, irrelevante). Por tanto `open_binary`, `list_strings`, `inspect_pe_resources`, etc. no tenían objetivo útil. Las observaciones salen de lectura directa de bases SQLite, XML, CSV y cadenas de archivos de guardado/caché (no es una operación REA). Las herramientas de UI nativa ya se sabían inutilizables en Windows.

## 2. Mina de oro: reglas de Civilization VI en caché (`DebugGameplay.sqlite`)

Ruta: `C:\Users\User\AppData\Local\Firaxis Games\Sid Meier's Civilization VI\Cache\DebugGameplay.sqlite` (318 tablas). Es la base de reglas que el juego compila al arrancar. Consultas: tablas `Units`, `Terrains`, `Features`, `GlobalParameters`, `UnitAbilities`, `UnitAbilityModifiers`, `ModifierArguments`, `UnitCommands`, `UnitFormationClasses`.

### 2.1 Escala de unidades (tabla `Units`, 97 filas)
- Todas tienen 100 puntos de vida (`COMBAT_MAX_HIT_POINTS = 100`, `GlobalParameters`).
- Fuerza cuerpo a cuerpo / a distancia / alcance / movimiento base, ejemplos [DATO]:
  - Guerrero 20 / 0 / 0 / 2; Espadachín 35 / 0 / 0 / 2; Lancero 25 / 0 / 0 / 2; Piquero 45; Mosquetero 55; Infantería de línea 65; Casaca roja 70.
  - Arquero 15 / 25 / alcance 2 / mov 2; Honda 5 / 15 / alcance 1.
  - Jinete 36 / mov 4; Caballería 62 / mov 5; Cosaco 67 / mov 5 (la caballería mueve 4-5 contra 2 de la infantería: 2 a 2,5 veces).
  - Explorador 10 / mov 3, `ZoneOfControl = 1` en la tabla pero con habilidad de ignorarla.
  - Catapulta 25 / bombardeo 35 / alcance 2; Bombarda 45 / bombardeo 55; Artillería 60 / bombardeo 80; Cañón de campaña 50 / a distancia 60 / alcance 2.
- Visión base 2 casillas para casi todos; 3 para algunos (Ironclad, helicóptero).
- **Lectura**: una escala de rango estrecho (unos 20 a 70 en la época de pólvora) donde la diferencia entre tipos viene de pocos modificadores explícitos, no de multiplicar números.

### 2.2 Fórmula de daño: constantes visibles (`GlobalParameters`)
Constantes [DATO]: `COMBAT_BASE_DAMAGE = 24`, `COMBAT_POWER_SCALING = 0.04`, `COMBAT_MAX_EXTRA_DAMAGE = 12`, `COMBAT_MINIMUM_DAMAGE = 1`, `COMBAT_DAMAGE_MULTIPLIER_MINIMUM = 0.25`, `COMBAT_POWER_DAMPENER = 5`.
[INF] La fórmula vive en el motor, pero estas constantes son coherentes con el daño base 24 escalado exponencialmente por la diferencia de fuerza (el 0,04 por punto implica que +17 de diferencia casi duplica el daño, +25 lo multiplica por ~2,7), más una variación aleatoria de 0 a 12. Es la receta clásica: al paridad ronda 24 a 36 de 100 por golpe, de modo que una pelea pareja dura 3-4 golpes y una ventaja de unos 25 puntos liquida en 2.
- Daño de respuesta: el defensor de un ataque cuerpo a cuerpo también hace daño; las unidades a distancia atacan sin respuesta. (`COMBAT_DEFENSE_DAMAGE_PERCENT_*` ahí son contra murallas, ver 2.6.)

### 2.3 Terreno (tablas `Terrains` y `Features`)
- Colinas: costo de movimiento 2, defensa +3. Llanura/pasto: costo 1, defensa 0. Montaña: infranqueable.
- Bosque y selva: movimiento +1, defensa +3. **Pantano (marsh) y llanura de inundación: defensa −2** [DATO]; el pantano además cuesta +1 de movimiento.
- Río: `COMBAT_RIVER_DEFENSE = 5` (bonus por defender/atacar del lado correcto del río).
- Texto del juego [DATO, parafraseado]: los ríos bloquean la zona de control; se recomienda evitar pelear en llanuras inundables y pantanos.
- **Adaptación**: el barro y los bañados de Justina deben ser una trampa clara (−2 a −3 de defensa y lento), y los bancos firmes de arena/barranca una posición fuerte (+3).

### 2.4 Zona de control (ZOC) y habilidades
- Texto de la Civilopedia (`DebugLocalization.sqlite`, etiqueta `LOC_PEDIA_CONCEPTS_PAGE_MOVEMENT_3_...`) [DATO]: entrar a la ZOC enemiga detiene el avance aunque sobre movimiento, pero se puede atacar si queda movimiento; las unidades a distancia y de asedio no ejercen ZOC; la caballería y los raiders navales la ignoran; los ríos bloquean la ZOC.
- `ABILITY_IGNORE_ZOC`: "no le afecta la ZOC enemiga". `ABILITY_NO_MOVE_AND_SHOOT`: "no puede moverse y atacar en el mismo turno" (para asedio/artillería).
- `ABILITY_ANTI_CAVALRY`: +10 de fuerza contra caballería ligera y pesada (`ANTI_CAVALRY_COMBAT_BONUS`, `Amount = 10`, [DATO]).
- `ABILITY_LIGHT_CHARIOT`: +2 de movimiento si el turno empieza en terreno despejado.

### 2.5 Flanqueo, apoyo, atrincheramiento, curación (parámetros y textos)
- Flanqueo `COMBAT_FLANKING_BONUS_MODIFIER = 2`; apoyo `COMBAT_SUPPORT_BONUS_MODIFIER = 2`. Texto [DATO]: un atacante cuerpo a cuerpo gana +2 por cada unidad aliada adicional que rodee al objetivo; el defensor gana +2 por cada aliado adyacente.
- Fortificar: `FORTIFY_BONUS_PER_TURN = 3`, `FORTIFY_TURN_MAX = 2` (hasta +6 tras dos turnos quieto).
- Curación por turno: territorio propio 15, neutral 10, enemigo 5 (`COMBAT_HEAL_LAND_FRIENDLY/NEUTRAL/ENEMY`); guarnición de ciudad 20.
- Cuerpos y ejércitos [DATO texto Pedia]: dos unidades iguales se unen en un Corps (+10 de fuerza), tres en un Army (+7) **sin aumentar vida**; la experiencia y las promociones de la mejor unidad se conservan.
- Experiencia: sobrevivir a un combate da XP; al subir de nivel se elige una mejora y se cura una parte de la vida (texto Pedia).
- Captura: `COMBAT_BASE_CAPTURE_STRENGTH_DIFFERENCE = 20`.
- `COMBAT_WOUNDED_DAMAGE_MULTIPLIER = 10` existe, pero la semántica exacta **[NO VERIFICADO]** (la Civilopedia dice que las unidades dañadas pierden fuerza).

### 2.6 Murallas y asedio
Texto Pedia [DATO]: contra murallas, el cuerpo a cuerpo hace el 15 % de su daño, la distancia el 50 % y solo el bombardeo hace el 100 % (`COMBAT_DEFENSE_DAMAGE_PERCENT_MELEE = 15`, `_RANGED = 50`, `_BOMBARD = 100`). Una ciudad se considera sitiada si sus 6 casillas vecinas están ocupadas por enemigos, bajo ZOC enemiga o son infranqueables.
- **Adaptación**: el fuerte del Retiro debe ser inmune a la infantería sola y vulnerable solo a la artillería.

### 2.7 Cadena de órdenes de unidad (tabla `UnitCommands`, 22 filas)
Categorías de interfaz [DATO]: `INPLACE` (despertar, cancelar), `SPECIFIC` (promover, mejorar, formar Corps/Army, entrar/salir de formación, nombrar unidad), `SECONDARY` (borrar, acariciar al perro), `MOVE` (puente aéreo). Es decir: el juego **separa las órdenes frecuentes de las peligrosas** (borrar unidad queda en la categoría secundaria). Eso responde al hallazgo "acciones peligrosas pegadas".

## 3. Otras fuentes locales

### 3.1 Textos de tutorial y escenarios cortos de Civ VI (`DebugLocalization.sqlite`, etiquetas `LOC_TUTORIAL_*`, 62 filas)
- **Objetivos con dos niveles**: "PARA COMPLETAR el tutorial" y "PARA GANAR el tutorial" (`LOC_TUTORIAL_GOAL_GENERAL_2` y `_3`), con una lista corta de metas de una línea con verbo en mayúscula al inicio (EXPLORAR, DEFENDER, DESARROLLAR). [DATO]
- **Escenario "Red Death"** (`LOC_TUTORIAL_CIVROYALE_*`): batalla de supervivencia donde la zona segura se achica con el tiempo y las unidades fuera de ella (o en el agua) pierden vida cada turno; sin ciudades ni diplomacia; solo se consiguen unidades nuevas explorando ruinas, despejando puestos y recogiendo suministros; se pierde cuando cae la última unidad civil. [DATO, parafraseado]
- **Escenario "Pirates"** (`LOC_TUTORIAL_PIRATES_*`): partida rápida de 60 turnos con puntaje por categorías (tesoro, fama, combate) y una tabla de puntos pequeña y concreta: enterrar tesoro +30, hundir barco de tesoro +20, saquear +1 a +5, destruir/capturar unidad +5 a +10, sobrevivir a un combate +1. Los barcos cuestan mantenimiento y se amotinan si no hay oro. [DATO]
- **Adaptación**: una tabla de puntos (acciones valientes valen más) en lugar de victoria/derrota binaria permite "rejugar para mejorar" y es lo que sostiene la directriz de volver a intentar.

### 3.2 Campaña de AoE3: script de objetivos (`Games\Age of Empires 3 DE\<id>\Trigger\trigtemp.xs`, 3.539 líneas)
Estructura [DATO]: un `eventHandler` que habilita reglas por número de evento (`xsEnableRule("_Obj5_Mills_Show")`, etc.); 9 objetivos encadenados, cada uno con tres estados (`trObjectiveDiscover` → `trObjectiveShow` → `trObjectiveComplete`); contadores de XP que se activan y se limpian; un bloqueo (`Obj8_Blockade_Discover`) y depósitos de munición destruibles con explosión (`Destroy_Ammo_Store1_Explosion`). Frecuencia de funciones: 386 `trUnitSelectByID`, 31 `trUnitDead`, 25 `trUnitMoveToUnit`, 22 `trUnitChangeProtoUnit`, 14 `trUnitConvert`.
- **Adaptación**: objetivos que **aparecen** solos al cumplir el anterior (descubrir → mostrar → completar), y escenas escritas a mano (explosión de un depósito, cambio de bando de una unidad) que cambian el ritmo a mitad de partida.

### 3.3 Logs de la IA de Civ VII (`%LOCALAPPDATA%\Firaxis Games\Sid Meier's Civilization VII\Logs\`)
- `AI_UnitEfficiency.csv` [DATO]: matriz 89×89 de "eficiencia" entre tipos de unidad (diagonal = 100). Ejemplo, fila Jinete: 323,8 contra Guerrero, 454,3 contra Honda, 225,0 contra Lancero, 148,0 contra Carro. Fila Lancero contra Jinete: 44,1. **[NO VERIFICADO]** la orientación fila/columna y que incorpore los bonos anticaballería (el Lancero no aparece fuerte contra el Jinete en ninguna orientación evidente). Aun así sirve como técnica: **una matriz publicada de enfrentamientos entre tipos** que la IA usa para decidir.
- `AI_MovementPlanning.csv` [DATO]: por turno y unidad, una lista `MOVES` de casillas candidatas con dos enteros pequeños cada una (p. ej. `36:14(2/1)`) y una lista `TARGETS` con tipo, identificador, casilla de destino y puntajes. `AI_Targets.csv` registra tipos de objetivo como `TARGET_ENEMY_CITY`. Semántica de los enteros **[NO VERIFICADO]**.
- **Adaptación**: la IA enemiga de Justina puede puntuar casillas candidatas y objetivos con una lista corta, y exponer ese puntaje en un modo de depuración.

### 3.4 Old World (`Documents\My Games\OldWorld`)
- `Saves\Auto\OW-Save-Auto-9.zip` contiene XML (585 KB) de un escenario tutorial ("Learn to Play 2"); opciones de partida [DATO]: `TurnStyle="TURNSTYLE_STRICT"`, `ForceMarch="FORCEMARCH_UNLIMITED"`, `OpponentLevel="OPPONENTLEVEL_PASSIVE"`, `Mortality`, `EventLevel`. Aparece `YIELD_ORDERS` (15 veces) como recurso de la partida junto con alimento, hierro, etc.
- `hotkeys.xml` [DATO]: atajos `HOTKEY_FORTIFY`, `HOTKEY_HEAL`, `HOTKEY_FORCE_MARCH`, `HOTKEY_PASS`, `HOTKEY_PAUSE`, y **capas de información conmutables**: `HOTKEY_LOCK_ZOC`, `HOTKEY_LOCK_DANGER_TILES`, `HOTKEY_LOCK_IDLE_UNITS`, `HOTKEY_LOCK_ROADS_RIVERS`.
- [INF] "Órdenes" es la moneda de acciones por turno y la marcha forzada una apuesta de fatiga. No se pudieron leer las tablas de unidades de Old World (juego desinstalado).

### 3.5 Empire at War (guardados `Saved Games\Petroglyph\Empire At War\Save\*.PetroglyphEaWSave`)
Los guardados serializan el Lua de la IA. Nombres de funciones/variables legibles [DATO]: `GroundTotal`, `NearbyGroundTotal`, `SpaceTotal`, `combat_power`, `build_cost`, `score_value`, `POWER_TO_WEAPONS`, `TimeSinceGroundConflict`, `DistanceToNearestFriendly`, `EnemyInternalConnectivity`, `SPREAD_OUT`. [INF] La IA decide comparando **poder total propio vs. enemigo vs. vecino** por zona, con el tiempo desde el último conflicto. `POWER_TO_WEAPONS` apunta a la decisión del jugador de reasignar energía entre sistemas (no verificado cómo se usa).

## 4. Dinámicas más aprovechables para un cruce táctico en tiempo real con pausa

Ordenadas por impacto en diversión/claridad. Las cifras son propuestas a probar, no copias.

1. **Daño exponencial con diferencia de fuerza y aleatoriedad acotada.** Parámetros de partida: base 24 sobre 100 de vida, +0,04 por punto, variación 0 a 12 (2.2). Así un duelo parejo no se resuelve en un golpe y una ventaja de terreno de +3 se siente sin ser decisiva. Resuelve "victorias pírricas" si el vencedor sale con daño visible.
2. **Terreno con signo claro y legible**: bancos/barranca firmes +3, barro y bañado −2 y más lentos, río +5 al defensor (2.3). Marcar el modificador en el tooltip de la casilla.
3. **Atrincherar acumulativo**: +3 por escalón, máximo 2 escalones (+6), cada escalón por ~8 a 10 segundos de juego quieto (2.5). Da una decisión de pausa: "¿me quedo o avanzo?".
4. **ZOC que frena pero no impide atacar; jinetes la ignoran; tiradores y artillería no la ejercen** (2.4). Es la regla que hace valioso al jinete para rodear por la ruta sur y explica la barrera de infantería del norte.
5. **Contrapuntos con bono plano visible**: lanceros/bayonetas +10 contra caballería (2.4); artillería sin respuesta pero "no mueve y dispara" (se descubre al desplegarse); murallas del fuerte: infantería 15 %, tirador 50 %, artillería 100 % (2.6).
6. **Flanqueo y apoyo de +2 por unidad adicional** (2.5): fácil de explicar con un icono y gratificante en tiempo real (dos escuadras desde lados opuestos). Es la mecánica barata que más "baja" a pantalla el reposicionamiento.
7. **Curación según zona**: 15/10/5 por unidad de tiempo en zona propia/neutral/enemiga (2.5). Permite retirar una escuadra herida a la retaguardia y volverla a mandar: elimina el bloqueo "si perdés, perdiste" en medio de la misión.
8. **Fusión de escuadras débiles** (Corps +10, sin más vida) (2.5): botón "juntar milicias" que convierte dos escuadras en una más fuerte pero igual de frágil; riesgo/recompensa.
9. **Puntaje por categorías y acciones valientes** en lugar de victoria binaria (3.1, Pirates): estrellas por objetivo primario, secundario (p. ej. capturar el buque sin perder el fuerte) y supervivencia. Se complementa con la lectura de "COMPLETAR vs GANAR" de los tutoriales de Civ VI.
10. **Reloj ambiental que presiona**: la zona segura que se achica (Red Death) se mapea a la marea/bajante del Río de la Plata: una ventana de oportunidad que se cierra y obliga a decidir pronto sin turnos.
11. **Objetivos que aparecen encadenados** (descubrir → mostrar → completar) y 1 o 2 escenas escritas a mano en medio de la partida (explosión de un depósito, llegada de refuerzos) (3.2). Rompen la monotonía del cruce.
12. **Panel con órdenes peligrosas separadas** (categoría secundaria) y capas conmutables de información (ZOC, casillas peligrosas, unidades ociosas) (2.7, 3.4). Resuelve "acciones peligrosas pegadas" y "jerga en el panel".
13. **IA enemiga basada en comparación de poder por zona y puntaje de objetivos** (3.3, 3.5): fácil de calibrar y de explicar al jugador ("el enemigo carga donde ve menos fuerza").
14. **Matriz publicada de enfrentamientos** (3.3): una tabla 5×5 (infantería de línea, miliciano, jinete, tirador, artillería) de ventaja relativa, ajustable por datos en `data/justina_map.json`, usada tanto por el balance como por la IA.

## 5. Límites y advertencias
- La fórmula de daño exacta, la semántica de `WOUNDED_DAMAGE_MULTIPLIER` y las columnas `(a/b)` de los CSV de la IA de Civ VII no están en los datos; no se inventaron.
- No hay juegos militares instalados con binarios analizables; no se usó REA sobre ejecutables. Si el usuario reinstala Civ VII, Total War o Old World, las rutas para repetir son `Base/modules/*/data/*.xml` (Civ VII) y los `.xml` de `Reference` de Old World.
- Los números de Civ VI/VII son órdenes de magnitud para calibrar; Güemes no copia valores, tablas ni textos.
- Las bases SQLite se consultaron en copias temporales; los originales no se tocaron.
