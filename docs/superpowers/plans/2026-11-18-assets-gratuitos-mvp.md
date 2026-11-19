# MVP de assets gratuitos — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Preparar y validar un MVP aislado de personajes, caballería y armas gratuitas sin degradar el juego actual.

**Architecture:** Las fuentes descargadas viven fuera del runtime del juego. La
escena de prueba consume copias convertidas o referencias explícitas y no
modifica los assets actuales hasta superar los criterios de aprobación.

**Tech Stack:** Godot 4.7.2, GDScript, GLB/glTF, Blender sólo si hace falta para
convertir o limpiar una fuente, documentación Markdown.

**Spec:** `docs/superpowers/specs/2026-11-18-assets-gratuitos-mvp-design.md`

## Global Constraints

- Mantener Godot 4.7.2.
- No usar recursos pagos ni cuentas externas.
- No abrir ni subir secretos `.env*`.
- No reemplazar assets aprobados sin comparación.
- No versionar archivos fuente grandes o con licencia incompatible.
- Documentar autor, URL, licencia, versión, formato y transformación.

## Review Focus

- Escala/orientación incorrecta: la escena debe medir y mostrar ejes y suelo.
- Animación no reproducible o deformada: cada candidato debe tener una prueba de
  reproducción y cambio de clip.
- Materiales/texturas ausentes: la importación debe quedar sin recursos faltantes.
- Coste excesivo: registrar tamaño y triángulos antes de integrar.
- Licencia no distribuible: bloquear la integración y dejar sólo una referencia.

---

### Task 1: Inventario y descarga aislada

**Files:**
- Create: `../materiales-privados/fuentes-gratuitas-mvp/`
- Modify: ninguno del juego
- Test: manifiesto local de fuentes

- [x] Registrar URLs, autores, licencia y tamaño de cada candidato.
- [x] Descargar sólo fuentes gratuitas verificadas en la carpeta aislada.
- [x] Calcular SHA-256 y conservar los archivos originales.
- [x] Marcar como `candidato`, `descargado`, `convertido` o `rechazado`.

### Task 2: Prueba de importación

**Files:**
- Create: `scenes/lab/assets_mvp.tscn`
- Create: `scripts/tools/assets_mvp_lab.gd`
- Create: `docs/superpowers/evidence/assets-mvp-import.md`

- [x] Crear una escena aislada con suelo, iluminación, cámara y rótulos.
- [x] Instanciar un humano candidato, un caballo con jinete baseline y un arma baseline.
- [x] Reproducir los clips disponibles y registrar errores.
- [ ] Medir escala, orientación, materiales, tamaño y triángulos.

### Task 3: Integración mínima aprobable

**Files:**
- Modify: sólo el archivo de integración de modelos que corresponda después de
  la prueba
- Test: escena aislada y pruebas existentes de importación

- [x] Elegir un candidato gratuito humano para el laboratorio.
- [ ] Integrar candidatos en producción sólo después de la prueba humana.
- [x] Actualizar procedencia y manifiesto de evidencia.
- [x] Mantener una ruta de reversión al asset actual.

### Task 4: Verificación y prueba humana

**Files:**
- Modify: documentación de entrega/QA sólo si cambia el estado real

- [x] Ejecutar la prueba específica de importación.
- [ ] Capturar una comparación antes/después.
- [x] Entregar al usuario la escena de prueba.
- [ ] Registrar comentarios humanos sobre claridad, movimiento y audio.
- [ ] No declarar el MVP aprobado hasta recibir esa evaluación.
