# Güemes — Juegos de la Patria (guía para Claude Code)

Juego 3D sobre Güemes: la Justina (1806), Humahuaca (1817) y la resistencia a La Serna (1816–17). Alfa 0.3.0 (base 0.1.0) en Godot 4.7.2 (GDScript) = semilla; se puede cambiar motor/diseño si mejora el juego.

- Repo: https://github.com/nicospum/guemes (rama main, tag v0.1.0 = alfa; no moverlo ni reutilizarlo). `main` está congelada en `72077c8`; el nivel II vive en la rama `humahuaca-r1` (y en sus ramas de trabajo), no en `main`.
- Raíz Git: esta carpeta. Fuera de Git, en la carpeta padre: `entregas/0.1.0/` (EXE y paquete original), `respaldos/` (bundle y copia sin git), `materiales-privados/` (fuentes sin licencia de redistribución), `investigacion-nivel2/` (fuentes primarias y descargas del nivel II).
- Léanse primero: README.md, docs/ENCARGO.md, docs/VERIFICACION.md, docs/DISENO_REGLAS.md, docs/historia (matriz y fuentes), docs/RECONSTRUIR.md.
- Código: scripts/game_rules.gd (reglas), main.gd (UI/cámara/input), world_view.gd (3D), jev_client.gd (TypeSafe), audio_manager.gd; tests/ y tools/.

## Tres escenarios
- I · La Justina (1806): tiempo real con pausa; `scripts/game_rules.gd`, `data/justina_map.json`.
- II · Humahuaca: el depósito de la retaguardia (Arias, 1/3/1817): corte vertical en desarrollo, tiempo real con pausa. Mandan `docs/DISENO_HUMAHUACA.md`, `docs/CONTRATO_HUMAHUACA.md`, `docs/QA_NIVEL2.md` (criterios y procedimientos del QA) y `docs/humahuaca/RETOMAR.md` (estado y plan). Código en `scripts/humahuaca/{terrain,rules,view,ui,stubs}`; datos en `data/humahuaca_*.json` (reglas, nivel, mapa, relieve, interfaz, visual); pruebas `tests/test_hx_*.gd` (headless: `godot --headless --path . --script tests/test_hx_data.gd`); herramientas `tools/hx_*`, `tools/qa_gate.sh`. Documentos de la pista en `docs/humahuaca/` (reglas, historia, procedencia, relieve, visual, controles, créditos, backlog, traza). Cada archivo tiene una pista dueña (CONTRATO 1.2): no tocar los de otra pista; anotar lo que haga falta en `docs/humahuaca/TEXTOS_REVISION.md` o en el BACKLOG.
- III · Sostener el norte (1816–1817): campaña por rondas; `scripts/game_rules.gd`.

## Reglas
- Jev/TypeSafe y REA: uso real y verificable; no declarar pruebas que no ocurrieron. Claves solo en entorno o `user://jev.cfg`; nunca en Git, chat ni capturas. No abrir ni subir `.env*`.
- Civilization VII (Steam) es solo referencia de interacción, en modo lectura; resultados fuera de su carpeta; no extraer assets.
- Historia: Güemes en la Justina = tradición no probada (Ideario pp. 33, 390–392); sin bandera argentina ni Infernales en 1806; Humahuaca = Arias, 1/3/1817 (Güemes conduce desde Salta y no está en el asalto; sin «coronel mayor» ni «general Güemes»); la recuperación de las piezas del 9 al 16 de marzo de 1817 es versión realista del Diario del Estado Mayor y de Camba, no de La Serna (H03); San Martín = contexto, no refuerzo. Cada dato del nivel II lleva etiqueta (documentado, razonado, discutido, sin datos, diseño): nada inventado figura como documentado.
- Textos visibles del nivel II en castellano rioplatense, sin jerga, siglas, inglés ni identificadores en snake_case (QA C03); lista negra en `data/humahuaca_ui.json`.
- Tests de integración escriben en `user://`: aislar el perfil antes de correrlos. No mezclar evidencia nueva con `evidence/` de 0.1.0.
- Archivos >100 MB no van a Git: el EXE se publica como Release.
- Sin push --force. Commits claros; no borrar historial.
