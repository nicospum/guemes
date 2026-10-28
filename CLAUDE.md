# Güemes — Juegos de la Patria (guía para Claude Code)

Juego 3D sobre Güemes: Justine/Justina (1806) y resistencia a La Serna (1816–17). Alfa 0.2.0 (base 0.1.0) en Godot 4.7.2 (GDScript) = semilla; se puede cambiar motor/diseño si mejora el juego.

- Repo: https://github.com/nicospum/guemes (rama main, tag v0.1.0 = alfa; no moverlo ni reutilizarlo).
- Raíz Git: esta carpeta. Fuera de Git, en la carpeta padre: `entregas/0.1.0/` (EXE y paquete original), `respaldos/` (bundle y copia sin git), `materiales-privados/` (fuentes sin licencia de redistribución).
- Léanse primero: README.md, docs/ENCARGO.md, docs/VERIFICACION.md, docs/DISENO_REGLAS.md, docs/HISTORIA (matriz y fuentes), docs/RECONSTRUIR.md.
- Código: scripts/game_rules.gd (reglas), main.gd (UI/cámara/input), world_view.gd (3D), jev_client.gd (TypeSafe), audio_manager.gd; tests/ y tools/.

## Reglas
- Jev/TypeSafe y REA: uso real y verificable; no declarar pruebas que no ocurrieron. Claves solo en entorno o `user://jev.cfg`; nunca en Git, chat ni capturas. No abrir ni subir `.env*`.
- Civilization VII (Steam) es solo referencia de interacción, en modo lectura; resultados fuera de su carpeta; no extraer assets.
- Historia: Güemes en el Justine = tradición no probada (Ideario pp. 33, 390–392); sin bandera argentina ni Infernales en 1806; Humahuaca = Arias, 1/3/1817; San Martín = contexto, no refuerzo.
- Tests de integración escriben en `user://`: aislar el perfil antes de correrlos. No mezclar evidencia nueva con `evidence/` de 0.1.0.
- Archivos >100 MB no van a Git: el EXE se publica como Release.
- Sin push --force. Commits claros; no borrar historial.
