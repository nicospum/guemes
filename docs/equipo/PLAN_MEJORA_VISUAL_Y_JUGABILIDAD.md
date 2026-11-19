# Plan de mejora visual y jugabilidad

Fecha: 2026-11-18  
Proyecto: **Güemes — Juegos de la Patria**  
Base: `visual/r1`, `0.5.0-preview2`, Godot 4.7.2

## Resumen ejecutivo

El juego ya tiene una base 3D funcional, tres capítulos y una verificación
automática fuerte. El problema ahora no es que falten polígonos: es que la
escena todavía comunica poco cuando se la mira como jugador y la cantidad de
órdenes exige aprender demasiadas reglas antes de tomar una decisión.

La mejora debe avanzar en dos frentes:

1. **Una familia visual reconocible:** personajes principales, soldados,
   enemigos, civiles, caballos, armas y objetos con proporciones, materiales,
   animaciones y LOD coherentes.
2. **Una experiencia más legible y divertida:** menos fricción al empezar,
   mejores decisiones visibles, más consecuencias en pantalla y menos opciones
   técnicas expuestas de entrada.

No conviene sumar soldados, gente y objetos sólo como decoración. Cada elemento
debe mejorar una de estas tres cosas: lectura táctica, atmósfera histórica o
respuesta a una decisión del jugador.

## Diagnóstico actual

### Visual

Ya existen:

- caballos criollos con cuatro pelajes y `idle`, `walk`, `trot`, `gallop`;
- jinetes de 1806 y 1817;
- gauchos, voluntarios, arrieros y realistas;
- armas de tacuara, carabina y fusil;
- edificios, vegetación, terreno y relieve;
- modelos con variantes LOD y manifiestos.

Todavía falta:

- un protagonista de cerca que tenga rostro, ropa y silueta memorables;
- más variedad de rostros, edades, complexiones y prendas;
- animaciones de acciones históricas: cargar, disparar, recargar, reaccionar,
  caer, montar, desmontar, girar y esperar;
- vínculos creíbles entre manos, armas, riendas, estribos y cuerpos;
- civiles y actividad de fondo para que los mapas no parezcan maquetas vacías;
- una jerarquía visual clara entre protagonista, aliados, enemigos, objetivos y
  decoración;
- una prueba humana de la escala y de la legibilidad a la distancia normal;
- medición real de rendimiento con la nueva cantidad de figuras.

### Jugabilidad y claridad

#### I · La Justina

La idea central es buena: reconocer el río, elegir ruta, conseguir la orden,
cruzar y abordar. Pero el jugador también encuentra señales, balizas, pólvora,
reunir, abastecer, ritmo, sondeo cauteloso, marcar vado, rechazar, evacuar,
retirar y deshacer.

**Propuesta:** mantener esas reglas en el motor, pero mostrar sólo el siguiente
paso y una acción recomendada. Las opciones avanzadas quedan en “Más acciones”.
La primera partida debería poder jugarse con:

1. reconocer;
2. pedir la orden;
3. cruzar;
4. responder al contraataque;
5. decidir si seguir o retirarse.

El jugador experto puede abrir las demás opciones sin perderlas.

#### II · Humahuaca

La cadena actual es comprensible en papel, pero tiene demasiadas órdenes
repetitivas y períodos de espera. El balance ya mejoró: el nivel tiene
variantes, informante, alarma, carga y extracción; aun así faltan decisiones
con consecuencias más visibles en la escena real.

**Propuesta:** organizar la partida en tres decisiones grandes:

1. **Cómo aproximarse:** silencioso, rápido o rodeando la vigilancia.
2. **Dónde concentrar el golpe:** batería, cuartel o posta primero.
3. **Qué salvar al retirarse:** pólvora, piezas, heridos o velocidad.

Las órdenes pequeñas siguen existiendo internamente, pero la interfaz las
agrupa y las presenta como consecuencias de esas decisiones.

#### III · Sostener el norte

La campaña tiene buenas reglas de abastecimiento, cohesión, comunicaciones,
reconocimiento y hostigamiento. Lo que falta es que el jugador entienda por qué
una ronda importa y qué plan está intentando construir.

**Propuesta:** mostrar en cada ronda:

- objetivo inmediato;
- amenaza del invasor;
- recurso que está en riesgo;
- consecuencia probable de cada orden;
- progreso hacia la condición de victoria.

## Qué personajes y elementos hacen falta

### Prioridad 1 — personajes jugables

Preparar una familia mínima:

| Rol | Variantes mínimas | Uso |
|---|---:|---|
| Güemes / héroe | 1 | retrato, menú, partes y presencia excepcional |
| Gaucho montado | 3 | jugador y caballería patriota |
| Paisano a pie | 3 | reconocedores, apoyo y población armada |
| Realista | 3 | enemigo y guarnición |
| Voluntario de 1806 | 2 | Justina |
| Arriero / baqueano | 2 | Humahuaca y ambiente |
| Civil | 4 | plazas, casas, caminos y lectura de población |
| Soldado de guarnición | 3 | puestos, cuartel y defensa |

No hace falta modelar cada variante desde cero. Se pueden variar cabeza, pelo,
sombrero, poncho, color, arma, escala dentro de un rango pequeño y postura,
conservando un esqueleto común.

### Prioridad 2 — acciones y animaciones

**Humano:** `idle`, caminar, correr, girar, frenar, agacharse, apuntar,
disparar, recargar, atacar, recibir impacto, caer, levantarse, rendirse,
cargar y desmontar.

**Caballo:** quieto, paso, trote, galope, giro, frenada, transición entre
andares, reacción, caída y espera con jinete.

**Conjunto montado:** socket de montura, pelvis, manos, riendas, pies,
estribos, inclinación del torso y transición sin saltos.

### Prioridad 3 — vida del mundo

Agregar primero elementos con función visual clara:

- civiles que caminan o trabajan;
- soldados que vigilan, descansan o cambian de puesto;
- arrieros que cargan mulas;
- caballos atados y caballos de reserva;
- fogones, humo, banderas de unidad sólo cuando históricamente corresponda,
  carros, herramientas, cajas y cargas;
- huellas, polvo, cascos, humo de disparos y señales nocturnas.

La población no debe convertirse todavía en una simulación compleja. Para el
primer pase alcanza con rutas, estados y animaciones simples.

## Recursos y herramientas disponibles

### Ya disponibles

- Godot 4.7.2.
- Blender/recetas y generadores del proyecto.
- MPFB 2.0.18.
- Universal Animation Library 1 y 2, CC0.
- Modelos propios actuales.
- Escenas y pruebas de QA.
- Relieve, texturas y manifiestos existentes.

### A conseguir manualmente

| Recurso | Para qué | Qué necesito del usuario |
|---|---|---|
| Warhorse Lite | comparar rig y socket equino | hacer clic en la descarga gratuita de itch.io |
| Flintlock CC0 | arma de época | descargar el archivo desde OpenGameArt |
| Sable CC0 | objeto de caballería | descargar desde BlendSwap |
| Referencias visuales históricas | ropa, armas, caras y civiles | aportar imágenes o aprobar las fuentes |

No se usarán recursos pagos, cuentas nuevas ni assets con licencia incierta.

## Qué necesito de vos

### Imprescindible

1. **Descargas manuales:** si una página exige botón, formulario o sesión,
   descargá el archivo y dejalo en:

   ```text
   C:\Users\User\Desktop\spum\IA\Proyectos\MaravillaArgentina\
   materiales-privados\fuentes-gratuitas-mvp\
   ```

2. **Prueba humana del juego:** jugá una partida breve de cada capítulo y
   respondé:

   ```text
   Qué entendí sin ayuda:
   Dónde me perdí:
   Qué opción sobró:
   Qué opción faltó:
   Qué personaje/objeto se veía genérico:
   Qué movimiento se veía mal:
   Qué sonido molestó o faltó:
   ```

3. **Definición del tono visual:** salvo que indiques lo contrario, propongo
   “realismo estilizado histórico”: rostros y ropa creíbles, materiales
   naturales, siluetas claras y detalle concentrado en cámara cercana; no
   fotorealismo ni estética medieval genérica.

### Útil pero no bloqueante

- referencias de cómo imaginás a Güemes, gauchos, realistas y civiles;
- prioridad entre “más realista” y “más estilizado”;
- qué capítulo debe recibir el primer salto visual;
- resolución y equipo donde querés que el juego siga funcionando;
- si querés que los civiles sean sólo ambiente o también den información y
  consecuencias jugables.

## Orden de trabajo propuesto

### Fase 1 — claridad antes que contenido

- reducir opciones visibles en la primera partida;
- corregir textos y acciones recomendadas;
- asegurar que cada decisión tenga respuesta visual;
- probar Justina y Humahuaca con personas.

### Fase 2 — kit de personajes

- elegir esqueleto humano y equino;
- crear Güemes, gaucho, realista, civil y arriero;
- preparar ropa, armas, sockets, LOD y animaciones;
- integrar una unidad a pie y una montada en una escena real.

### Fase 3 — población y ambiente

- añadir soldados de guardia, civiles, arrieros y animales;
- vincular estados simples con las reglas existentes;
- mejorar humo, polvo, fogones, huellas, sonido y señales.

### Fase 4 — integración y balance

- revisar la densidad de figuras;
- medir rendimiento;
- ajustar cámaras y lectura;
- probar las tres campañas con personas;
- cerrar sólo lo que tenga evidencia.

## Criterios de éxito

- Una persona nueva entiende el objetivo de cada capítulo sin leer toda la
  documentación.
- Las primeras acciones importantes aparecen como una secuencia clara.
- Las opciones avanzadas no abruman, pero siguen disponibles.
- Los personajes principales se distinguen a distancia y de cerca.
- Aliados, enemigos, civiles y objetivos se reconocen sin depender sólo del
  color.
- No hay T-pose, pies flotando, manos separadas de armas, riendas sueltas ni
  jinete despegado.
- La cantidad de figuras agrega vida sin destruir el rendimiento.
- Cada asset tiene origen, licencia, hash, formato y prueba registrada.
- La diversión se valida con personas, no sólo con bots.

## Decisión pendiente

Este documento propone empezar por **claridad de la Justina + un kit visual
mínimo de cinco roles**: Güemes, gaucho, realista, civil y arriero. Después se
extiende al caballo, la caballería y Humahuaca.

No se deben hacer cambios grandes de código o assets hasta que el usuario
confirme esa prioridad y entregue las descargas manuales disponibles.
