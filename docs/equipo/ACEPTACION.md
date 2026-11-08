# Lista de aceptación de la entrega «equipo 2026-11-08»

Fijada el 2026-11-08 **antes de implementar**, por el lead (dirección e integración). No se modifica para justificar problemas: si un punto no se cumple, el dictamen lo dice. Rama de trabajo: `equipo/integracion` (punto de recuperación: rama `respaldo/pre-equipo-2026-11-08` y bundle `../respaldos/pre-equipo-2026-11-08.bundle`, ambos en `4f1792a`).

Esta lista **no reemplaza** `docs/QA_NIVEL2.md` (rúbrica de 41 criterios del nivel II, pensada para la certificación de ese nivel); la complementa con lo que pide esta entrega: los tres niveles como una experiencia. Donde se cruzan, se usa la cifra más exigente salvo que se diga lo contrario.

## A. Funciona (todo BLOQUEANTE si falla)

| ID | Criterio | Cómo se verifica |
|---|---|---|
| A1 | El juego arranca desde el proyecto limpio (importación nueva) y desde el EXE exportado, sin `SCRIPT ERROR`/`SHADER ERROR` ni recursos faltantes en la consola. | Corrida con ventana + log filtrado; `--headless --import` limpio. |
| A2 | Cada nivel (I, II, III) se completa con **victoria por el recorrido normal** (interfaz/entrada del jugador o políticas de juego del propio proyecto, sin trucos de depuración que alteren reglas). | Scripts de playtest con capturas del parte de victoria de cada nivel. |
| A3 | Cada nivel tiene **derrota** alcanzable y el **reinicio** tras perder deja el estado limpio (mismo objetivo, sin restos visuales ni de reglas). | Playtest de derrota → reintento → partida jugable. |
| A4 | El recorrido **menú → I → II → III → final** funciona en una sola sesión de juego, con desbloqueos correctos y sin estado filtrado entre niveles (el bug «Norte negro tras Humahuaca» queda cerrado con prueba). | Script de recorrido completo + capturas de cada entrada de nivel. |
| A5 | Volver al menú, pausa, guardar/cargar (donde existen) no rompen ni corrompen el estado; repetir una partida completa da el mismo comportamiento. | Pruebas existentes + recorrido repetido. |
| A6 | Las suites existentes pasan sin bajar pisos: `test_rules`, `test_integration`, `jev_contract_test`, `test_hx_*` (y las nuevas que se agreguen). Las pruebas de `tests/revision_nube/` que documentan fallas reales quedan resueltas o justificadas una por una. | Corrida headless con cifras. |

## B. Se ve mejor (ALTO si falla)

| ID | Criterio | Cómo se verifica |
|---|---|---|
| B1 | **Mejora visual demostrable en los tres niveles** y en el menú: comparativas antes/después desde encuadres equivalentes (`tools/captura_tres_niveles.gd`) + secuencia en movimiento de cada nivel. | Carpeta de evidencia con pares antes/después revisados por QA. |
| B2 | Una **dirección de arte coherente** escrita y aplicada (paleta, tipografía, iluminación por nivel, reglas de color aliado/enemigo/objetivo), con identidad propia por nivel (no el mismo escenario recoloreado). | Documento de dirección + capturas. |
| B3 | Se distinguen a simple vista jugador, enemigo, objetivo y fondo en los tres niveles (en el II, de noche, inclusive). | Revisión de QA sobre capturas a 1280×720 y 1440×900. |
| B4 | El HUD no tapa la información del juego y se lee a 1280×720 (sin recortes ni solapes). | `ui_qa` / `ui_qa_humahuaca` + capturas. |
| B5 | No hay placeholders importantes presentados como acabado final (cajas grises, fichas sin forma, pantallas vacías). | Revisión de QA. |
| B6 | El rendimiento no empeora de forma relevante: cuadro medio de cada nivel ≤ 1,15 × la base medida en la misma sesión en esta PC, o dentro de los topes de `QA_NIVEL2.md` (T06). | Benchmark antes/después en la misma sesión. |

## C. Se entiende y se juega mejor (ALTO si falla)

| ID | Criterio | Cómo se verifica |
|---|---|---|
| C1 | En cada nivel, a los 30 s se sabe qué hacer: objetivo visible, siguiente paso indicado, controles explicados. | Captura del primer cuadro jugable + revisión de QA. |
| C2 | Las acciones importantes tienen respuesta visual/sonora (orden dada, objetivo cumplido, daño/pérdida, victoria/derrota). | Secuencias de captura en movimiento. |
| C3 | Los peligros se anticipan (telegrafiado) antes de castigar. | Revisión de diseño + playtest. |
| C4 | Victoria y derrota explican qué pasó y qué sigue; la transición entre niveles y el cierre final dan sentido de progresión I → II → III. | Capturas de partes y del final. |
| C5 | Las decisiones aplicadas de los referentes tienen su verificación cumplida o se informan como no cumplidas. | Documento de referentes y decisiones. |

## D. Entrega (MEDIO si falla, salvo D1)

| ID | Criterio |
|---|---|
| D1 | Existe una build o forma reproducible de ejecutar lo entregado (instrucciones probadas). **BLOQUEANTE.** |
| D2 | Licencias de todos los recursos nuevos identificadas en `docs/CREDITOS.md`/`licenses/`. |
| D3 | QA revisó **la misma versión** (mismo commit) que se entrega, después de la última corrección relevante, con regresión completa. |
| D4 | Documentación: diagnóstico y mapa de niveles, referencias y decisiones, backlog y registro de iteraciones, pruebas/capturas/dictamen, instrucciones y pendientes reales (en `docs/equipo/`). |

## Dictamen posible

- **APTO COMO CANDIDATO DE PUBLICACIÓN** en las plataformas probadas: A, B, C completos y D1–D3.
- **APTO CON LIMITACIONES**: A completo, sin BLOQUEANTES ni ALTOS abiertos, con limitaciones escritas.
- **NO APTO**: cualquier BLOQUEANTE o ALTO abierto, con evidencia.

Límite conocido de antemano: nadie juega a mano en este circuito; la diversión para personas reales queda para una prueba humana posterior y el dictamen lo dice.
