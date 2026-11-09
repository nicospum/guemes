# Entrega «equipo 2026-11-08» — Güemes 0.5.0-preview1

Rama `equipo/integracion` (sin push). Punto de recuperación: rama `respaldo/pre-equipo-2026-11-08` (= `main` en `4f1792a`) y `../respaldos/pre-equipo-2026-11-08.bundle`. EXE: `../entregas/0.5.0-preview1/PatriaGuemes_0.5.0-preview1.exe` (SHA-256 en `SHA256.txt` de esa carpeta). Dictamen de QA: `docs/equipo/DICTAMEN_QA.md`.

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
