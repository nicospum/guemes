# Entrega «visual/r1 2026-11-09» — Güemes 0.5.0-preview2 (sobre 0.5.0-preview1)

Rama `visual/r1` (sin push; `origin/main` en `e0fd223`). Punto de recuperación previo a `visual/r1`: rama `respaldo/pre-visual-r1-2026-11-09` (= `main` en `e0fd223`) y `../respaldos/pre-visual-r1-2026-11-09.bundle`. EXE: `../entregas/0.5.0-preview2/PatriaGuemes_0.5.0-preview2.exe` (`156 007 576` bytes, SHA-256 `a2b0fb9b96f787837c1917d7642109ebaa4f8f688f3be9c3b99c075750ec06ce` en `SHA256.txt`, construido desde el commit de código `896fba5`). Dictamen de QA: `docs/equipo/DICTAMEN_QA.md`.

## 0. Qué suma 0.5.0-preview2 (`visual/r1`, fases F0 a F7)

- **F1 · Marcas sutiles y rótulos de una línea en los tres niveles:** reemplaza los discos grandes y anillos que crecían con la distancia por un aro fino sobre el terreno, una marca de 12–16 px (14 px en juego) y un rótulo de una línea que se ensancha al nombre completo de la agrupación elegida y se pega al borde libre cuando la partida queda fuera de cámara o detrás del HUD.
- **F2 · Cámara cercana y paneo inicial en la Justina:** encuadre inicial cercano (~165–190 m en Justina y Humahuaca, ~60 m en el Norte, zoom mínimo 15–20 m). En la Justina, al entrar desde el menú la cámara muestra el buque («Objetivo: el buque») y planea en 3,5 s hasta las tropas sin consumir tiempo de juego (cualquier tecla, clic o rueda lo saltea).
- **F3 · Formaciones a escala real según la dotación:** cada agrupación dibuja una figura cada 3–4 hombres (6 a 24 figuras en MultiMesh, sin agrandarse con la distancia y con LOD lejano). En Humahuaca se atenúan los círculos blancos de visión y en `humahuaca_declutter.gd` las agrupaciones que coinciden en el mismo punto se reparten lado a lado en la vista.
- **F4 · Caballos criollos animados (`tools/f4_caballos.py`):** malla base CC0 («Rigged Horse» de Lyndon Daniels / ChadM), esqueleto de 25 huesos, recado criollo, cuatro pelajes (zaino, alazán tostado, tordillo, overo) y andares `idle`, `walk`, `trot` y `gallop` por cinemática inversa sincronizados con la velocidad real.
- **F5 · Personas animadas, kit de 26 edificios del territorio, texturas CC0 y relieve Copernicus:**
  - **Personas (`tools/f5_personas.py`):** jinetes de 1806 y 1817 con simulación de caída de poncho; figuras de a pie con `idle`, `walk`, `run` y `crouch` (segundo reconocedor agachado): gauchos con tacuara o carabina, voluntarios de 1806, arrieros y realistas de 1817.
  - **Kit de 26 casas (`tools/f5_casas.py`, `docs/historia/CASAS_F5.md`):** casas de torta, ranchos de paja, galerías de horcones, casas de patio y zaguán, pulperías, postas, capillas con espadaña o torre, corrales de pirca y casas encaladas del Retiro de 1806 (con su `_lod.glb`). Paredes encaladas de Humahuaca con manchas de cal, grano, chorreaduras y zócalo de barro (`shaders/humahuaca_muro.gdshader`).
  - **Terreno y relieve (`tools/f5_terreno_*.py`):** 12 materiales fotográficos CC0 de Poly Haven (6 en Humahuaca, 3 en el Norte, 3 en la Justina) y relieve real de Copernicus GLO-30/90 para el horizonte de ±29 km de Humahuaca y la campaña del Norte.
- **F6 · Cierre, pulido visual y prueba de Jev en vivo:**
  - **Jev en vivo (`4e1a094`, `tools/jev_vivo.gd`, `docs/JEV.md`):** consulta autenticada real a TypeSafe (`jev-1.14.0`, decisión «buscar víveres» en 330 ms aplicada a la ronda 1 → 2 del Norte) y prueba de recuperación local por timeout (50 ms).
  - **Justina y Norte (`638186a`):** cabecera centrada, chips que no recortan nombres (cierra Q-304), rótulos de mapa que esquivan avisos, minimapa legible a 1024×640, «Buque ▸» fuera de rótulos 3D de pozos/vados, Chicoana y Orán con capilla/galería encalada y adobe aclarado, teja apagada en la Justina, tropa del Norte a escala 0,6 y ranchos de la ribera fuera de rutas y zona de marcha.
  - **Humahuaca (`55c7a5d`, `571e418`, `c5bfee0`):** Q-201…Q-210 reverificados, B-049 (reparto visual de fichas superpuestas y reconocedor agachado), B-058 (desvanecimiento de curvas de nivel en el contexto lejano), B-064 (paredes encaladas con detalle cercano), ajuste de saturación del alba (`vis_flow` 0 fallas) y carga diferida sin fuga de `RefCounted` al salir en modo headless (cierra Q-301).
- **F7 · Compuerta de QA, benchmarks, capturas antes/después y ejecutable `0.5.0-preview2`:** todas las suites y resoluciones en verde (`ui_qa` 257/0 en 5 resoluciones; `ui_qa_humahuaca` 182/0 y 98/0 ×2; `qa_gate quick integrador` PASA; `vis_flow` 0 fallas; benchmarks dentro de presupuesto: Justina `media` 2,52 ms, Norte `media` 1,77 ms, Humahuaca `media` 1,98 ms). Capturas antes/después en `../qa-visual-r1/{antes,despues}/`.

## 1. Qué juego encontramos

Godot 4.7.2 (GDScript, Forward+), Windows x64. Tres capítulos de estrategia histórica en 3D sobre Güemes y la guerra en el norte (mapa completo en `REFERENTES_Y_DECISIONES.md`):

- **I · La Justina (1806)**, tiempo real con pausa: tomar un buque varado antes de que suba el río. Maduro en reglas; visual plano.
- **II · Humahuaca (1817)**, tiempo real con pausa: golpe nocturno de Arias contra el depósito realista. Corte vertical en una rama, **nunca incluido en un EXE** (comprobado con REA sobre el EXE de preview5), con 6 ramas de trabajo en la nube sin integrar, balance roto y aspecto «lavado» de cajas pálidas.
- **III · Sostener el norte (1816–17)**, campaña por rondas. Maduro en reglas; relieve beige uniforme y regla de color invertida (el poncho patriota se leía rojo).

Documentación vieja vs. implementación: el README hablaba de «dos escenarios» y el EXE entregado tenía dos; el nivel II solo existía en código.

## 2. Equipo y método

Subagentes reales (herramienta Agent), en tandas, cada pista en su propio worktree con archivos propios; el lead integró. Tanda 1 (solo lectura): auditoría técnica, playtest de línea de base, diseño y referentes, dirección de arte. Tanda 2 (implementación): P1 arte I/III y menú, P2 arte y cámara del II, P3 reglas del II, P4 interfaz y flujo I/III, P5 interfaz del II, P6 modelos propios; rondas extra P1 r2, P2 r2–r4, P4b. QA independiente (dos revisores por ronda, sin escribir código) con autoridad de rechazo: ronda 2 rechazó el II (cámara que mareaba) → ronda de corrección (dos agentes) → certificación final sobre la misma versión del EXE. Lista de aceptación fijada antes de implementar: `ACEPTACION.md`. Backlog y registro: `BACKLOG.md`.

## 3. Referentes y qué se adaptó

Into the Breach (telegrafiar la amenaza → intención del invasor visible con reconocimiento en el III; aviso de 5 s del centinela en el II), Shadow Tactics/Desperados III (detección que avisa y da tiempo → aro ámbar que se vacía), Unity of Command (objetivos con plazo y puntaje → presión «x de 7» en el III, medallas en el II), Frostpunk (el final repasa lo hecho → pantalla final de campaña «En tu partida» / «En la historia»). Detalle, costos y verificación: `REFERENTES_Y_DECISIONES.md`.

## 4. Qué cambió visualmente

Dirección «Crónica en oro y noche» (`DIRECCION_DE_ARTE.md`): menú heroico con el buque a contraluz al atardecer y capítulos como tarjetas; Norte con fondo tinta, sol rasante dorado, rampa por altura, regla de color corregida y realce de figuras; Justina con tarde dorada, barranca del Retiro con relieve, talas, ombúes y quintas, estela y gallardetes en el buque; Humahuaca con noche de luna fría y tierra ocre, braseros y ventanas que iluminan, 9 modelos propios (casas de adobe, capilla con espadaña, tapias, pirca, corral, cañones de bronce, brasero, fogón), cardones y algarrobos, bruma con la pared de la quebrada, parcelas con surcos, figuras con siluetas (lanza, chacó), fichas de 65–85 px, aviso de detección y una apertura de 6 s desde 1,75 km sobre la quebrada; briefings y partes a pantalla completa con la composición del mockup 05 en los tres capítulos; paleta e interfaz comunes.

## 5. Qué cambió en las mecánicas y la experiencia

Cadena I → II → III por el botón principal del parte y pantalla final de campaña; el III se abre al ganar I o II. II: la guía ya no lleva a perder; aviso de detección esquivable; rutas que rodean lo vigilado antes de la señal; medallas que premian decidir (oro alcanzable); «Esperá» dice qué se espera y cuánto falta y ofrece ×2/×4; destruir continúa solo; cámara que se acerca a la partida elegida (solo por elección explícita) con horizonte; reintento en ~0,5 s. I: un solo mensaje en el primer cuadro; HUD ≤ 25 % de pantalla; velocidad ×4 que se conserva; decisión pendiente que detiene el reloj; parte reabrible. III: barra de órdenes estable; metas y presión visibles; intención del invasor con reconocimiento; causas de derrota reales; F5 separado del autoguardado.

## 6. Errores corregidos (resumen)

III negro tras el II (estado filtrado entre niveles); balance del II roto por el relieve real (una ruta pasaba sobre la batería); interfaz del II un 25 % más grande viniendo de la Justina; menú recortado tras el III; puertas de la posta cerradas para la navegación; Ctrl+Z que deshacía órdenes ajenas; arrastre pegado; puntos de control fantasma; `height_at(NaN)` con errores; epílogo mal atribuido (H03); 31 fallas documentadas por la revisión en la nube (32/32 pasan); HUD encendido detrás de la pantalla de misión; error de script al salir con el teclado; aviso de fuga por la carga en hilo del precalentado; textos truncados (16 → 0 en las 14 pantallas auditadas; queda un recorte en el III a 1280×720, Q-304). Lista completa con causa y prueba: `BACKLOG.md` y los informes de pista `P1…P6`.

## 7. Pruebas y dictamen

**Dictamen de QA independiente: APTO COMO CANDIDATO DE PUBLICACIÓN en las plataformas probadas** (Windows 11 x64, 1280×720 y 1440×900; en `1d76157` fue «con limitaciones» por créditos y documentos, ya corregidos). Detalle, cifras, criterios y limitaciones: `DICTAMEN_QA.md`. En corto: 0 fallas en todas las suites (≈ 3 470 comprobaciones), 32/32 en la revisión de la nube, `ui_qa` sin fallas, recorrido completo menú → I → II → III → final dos veces seguidas con perfil limpio por la interfaz real, derrota y reintento en los tres, EXE probado por sus modos automáticos y con teclas reales, 0 errores de script. No se probó: personas reales jugando, audio audible, Jev vivo, otras máquinas.

Capturas antes/después versionadas (livianas) en `docs/equipo/capturas/` (la «antes» del Norte en `base_vs_despues_..._30` muestra el mundo del II en lugar del Norte por el bug T-001 de la herramienta de entonces; el Norte de antes entrado directo se ve en `../qa-equipo/antes/antes_31_norte_directo.png`). Evidencia completa, videos y registros fuera de Git en `../qa-equipo/qa_final/` y `../qa-equipo/qa_ronda2/`.

## 8. Herramientas usadas realmente

REA (inventario del EXE de preview5: confirmó que el nivel II nunca se había exportado), Godot 4.7.2 por línea de comandos (pruebas headless, capturas con ventana real, exportación), Python+PIL (hojas comparativas), ffmpeg (videos de QA), generador de modelos propio sin Blender (Blender 4.4 no tiene ejecutable en esta PC). Jev/TypeSafe: evaluado, **sin llamadas en vivo** (gastaría créditos del usuario sin autorización). Detalle: `HERRAMIENTAS_USADAS.md`.

## 9. Cómo ejecutarlo y recorrerlo

- Jugar: abrir `PatriaGuemes_0.5.0-preview1.exe` (no requiere instalación). Empezar por **I · La Justina**; al ganar, «Seguir: Humahuaca»; al ganar, «Seguir al capítulo III»; al ganar el III, pantalla final.
- Desde el código: `.tools/godot/Godot_v4.7.2-stable_win64.exe --path patria-guemes`.
- Reconstruir el EXE: `python tools/build_release.py --godot <Godot consola> --templates <plantillas 4.7.2> --target windows`.
- Capturas comparables: `godot --path . --resolution 1440x900 --script tools/captura_tres_niveles.gd -- --out=<carpeta> --tag=<x>`.

## 10. Incidente y pendientes reales

- Incidente del 2026-11-08 19:10–19:21: borrado externo de `../respaldos/`, `../qa-equipo/` y `evidence/`; restaurado lo restaurable (ver `BACKLOG.md`).
- Prueba con personas reales (diversión, claridad, duración) y escucha del audio.
- BAJOS abiertos: Q-301 (aviso de fuga en suites sin ventana), Q-304 (recorte en el III a 1280×720), Q-305 (paneo por borde, por confirmar), Q-306 (1,3–1,6 s del clic al briefing del II).
- Jev en vivo, con permiso y presupuesto del usuario.
- Figuras y casas con texturas PBR cuando haya Blender ejecutable (`create_models.py --only hx_*`).
- Balance fino del II (quien sigue la guía gana con bronce).
- Nada se subió a GitHub ni se publicó: falta el OK del usuario para push/release.
