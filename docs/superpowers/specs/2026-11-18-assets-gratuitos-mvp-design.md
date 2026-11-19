# MVP de assets gratuitos — Güemes

## Intención

Evaluar si los recursos gratuitos conseguidos mejoran de forma comprobable la
presentación de personajes, caballería y armas del juego sin romper Godot,
licencias, rendimiento ni la dirección histórica del proyecto.

## Alcance

- Preparar una escena/laboratorio aislado con un personaje a pie, un caballo
  con jinete y un arma gratuita.
- Verificar formato, escala, orientación, rig, animaciones, materiales y
  licencia.
- Comparar contra los modelos actuales antes de integrar cualquier reemplazo.
- Mantener los archivos fuente fuera del flujo de producción hasta aprobarlos.

## Fuera de alcance

- Cambiar de Godot.
- Reemplazar todos los personajes del juego.
- Usar recursos pagos, cuentas externas o licencias ambiguas.
- Distribuir archivos fuente de Mixamo, BlendSwap o similares si sus
  condiciones lo impiden.
- Resolver todavía todo el sistema de montar/desmontar.

## Recursos candidatos

- UAL 1 y 2: ya descargados, CC0, GLB compatible con Godot.
- MPFB 2.0.18: ya descargado; fuente editable para preparar un humano.
- Warhorse Lite: gratuito, uso comercial permitido, GLB/FBX; candidato técnico,
  no aprobado históricamente por su estética medieval.
- Horse Rigged All Gaits: CC0, pero fuente Blender pesada; sólo candidato de
  estudio si el tamaño y el pelo por partículas son manejables.
- Flintlock de OpenGameArt: CC0.
- Sable de caballería de BlendSwap: CC0.

## Criterio de aprobación

Un recurso sólo entra al juego si:

1. carga sin errores en Godot 4.7.2;
2. conserva escala y orientación correctas;
3. tiene animaciones utilizables y sin deformaciones graves;
4. mejora una vista de juego real frente al asset actual;
5. no excede el presupuesto medido;
6. tiene procedencia y licencia documentadas.

## Ayuda humana necesaria

La evaluación final requiere que el usuario juegue el EXE, escuche el audio y
confirme claridad, aspecto y sensación de movimiento. Las pruebas automáticas
no sustituyen esa validación.
