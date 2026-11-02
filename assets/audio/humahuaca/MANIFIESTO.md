# Manifiesto del audio del nivel II «Humahuaca»

Todos los archivos de esta carpeta son **originales y sintetizados por código**: los genera `tools/generate_audio_humahuaca.py`
(`python tools/generate_audio.py --humahuaca`) con numpy y scipy sobre las primitivas de `tools/generate_audio.py`. **No hay ningún
material externo**: ni muestras, ni bancos de sonido, ni grabaciones. Cada archivo es WAV de 44,1 kHz, mono, 16 bits y pesa menos de
300 KB (tope de 3,3 s). Las semillas fijas hacen la generación determinista. Las cifras de abajo las mide el propio generador al escribir
cada archivo (pico y RMS en dBFS sobre las muestras de 16 bits; «recortes» cuenta muestras en ±0,9995). El análisis independiente está en
`docs/humahuaca/SONIDO.md` (`tools/analyze_audio.py --dir assets/audio/humahuaca --loops lluvia_noche,viento_quebrada,grillos,alba_pajaros`).

La etiqueta de fuente sigue el vocabulario del nivel (`documentado`, `razonado`, `discutido`, `sin_datos`, `diseno`): dice qué parte del
sonido se apoya en el parte de Arias (la lluvia, la descarga que pareció cañonazo, la pólvora, las mulas, el cruce del río) y qué parte es
ambientación de diseño. Ningún sonido se presenta como grabación de época.

| Archivo | Grupo | Receta (síntesis) | Duración | Tamaño | Pico | RMS | Recortes | Fuente |
|---|---|---|---|---|---|---|---|---|
| `alba_pajaros.wav` | ambiente (lazo periodico) | tres aves (registro 2,1-4,3 kHz) con frases de 2 a 5 trinos: barridos de frecuencia de 50-140 ms, la mitad con tremolo de 25-45 Hz, envueltos circularmente, sobre una brisa de 180-1400 Hz; semilla 531 | 3.30 s | 284.3 KB | -13.6 dBFS | -28.0 dBFS | 0 | diseno (el alba del 1 de marzo es documentada; las aves son ambientacion) |
| `grillos.wav` | ambiente (lazo periodico) | cuatro voces de 4,2-5,4 kHz en pulsos de 11 ms con ventana de Hann, grupos de 3 a 5 pulsos cada 21 ms, envueltos circularmente, sobre un lecho tenue de 2,5-7 kHz; semilla 521 | 3.30 s | 284.3 KB | -13.7 dBFS | -30.0 dBFS | 0 | diseno |
| `lluvia_noche.wav` | ambiente (lazo periodico) | ruido periodico por FFT en dos bandas (500-9000 Hz y 120-1100 Hz) con moduladores de 1, 2 y 3 ciclos; 140 gotas (barridos descendentes de 1,4-3,8 kHz, 6-20 ms) y 18 gotas gordas sobre charcos (280-700 Hz), envueltas circularmente; semilla 501 | 3.30 s | 284.3 KB | -10.0 dBFS | -23.0 dBFS | 0 | documentado (lluvia la noche del 1 de marzo de 1817, parte de Arias) / diseno (la textura) |
| `viento_quebrada.wav` | ambiente (lazo periodico) | cuerpo 55-480 Hz y aire 300-1900 Hz de ruido periodico por rafagas (moduladores de 1 y 2 ciclos, exponente 1,4) mas un silbido de 650-1100 Hz cuya fase neta es un numero entero de vueltas; semilla 511 | 3.00 s | 258.4 KB | -9.3 dBFS | -26.0 dBFS | 0 | razonado (viento de quebrada) / diseno |
| `carga_bultos.wav` | animales, carga y agua | crujido de cincha (430 -> 360 Hz), bulto que cae (< 170 Hz, 62 Hz, chasquido 400-2000 Hz) a 0,32 y 0,92 s y roce de soga y lona (1,1-5 kHz con aleteo de 12 Hz); semilla 691 | 1.60 s | 137.9 KB | -6.0 dBFS | -23.4 dBFS | 0 | documentado (la carga del botin en mulas) / diseno |
| `cascos_mulas_1.wav` | animales, carga y agua | siete pisadas al paso de mula (0 a 1,28 s con desorden de 20 ms): cuerpo 240-1500 Hz, golpe de 100-130 Hz, chapoteo del barro (< 900 Hz, 8 ms despues) y chasquido del casco; semilla 661 | 1.62 s | 139.6 KB | -6.0 dBFS | -24.5 dBFS | 0 | documentado (las mulas de la posta) / diseno |
| `cascos_mulas_2.wav` | animales, carga y agua | idem, semilla 664 | 1.62 s | 139.6 KB | -6.0 dBFS | -25.8 dBFS | 0 | documentado / diseno |
| `galope.wav` | animales, carga y agua | galope de caballo: cuatro trancos de 0,44 s con cuatro cascos por tranco (0, 85, 170 y 300 ms), mas seco que el paso de mula; semilla 671 | 1.96 s | 168.9 KB | -5.0 dBFS | -22.7 dBFS | 0 | razonado (el mensajero a caballo) / diseno |
| `pisadas.wav` | animales, carga y agua | cuatro pasos sobre barro (< 600 Hz con chapoteo de 400-2500 Hz) a 0, 0,29, 0,57 y 0,86 s; semilla 701 | 1.20 s | 103.4 KB | -9.0 dBFS | -30.6 dBFS | 0 | diseno |
| `relincho_mula.wav` | animales, carga y agua | rebuzno en dos tiempos: inspiracion aguda (540 -> 800 Hz con vibrato de 7 Hz, armonicos y aliento, formantes 1000/1900/3000 Hz) y espiracion grave (400 -> 230 Hz, tremolo de 5,5 Hz, formantes 650/1150/2400 Hz); semilla 681 | 1.80 s | 155.1 KB | -5.0 dBFS | -18.7 dBFS | 0 | diseno |
| `vado_agua.wav` | animales, carga y agua | nueve chapoteos de 600-5000 Hz con burbujas (barridos de 0,5-1,5 kHz) sobre un lecho de 200-3000 Hz: la columna cruza el vado; semilla 711 | 2.60 s | 224.0 KB | -6.0 dBFS | -29.3 dBFS | 0 | documentado (el cruce del rio) / diseno |
| `brasas_humo.wav` | combate | soplido de 250-2200 Hz en arco de 1,2 s con 22 chasquidos de brasas; semilla 651 | 1.60 s | 137.9 KB | -10.0 dBFS | -26.5 dBFS | 0 | diseno |
| `choque_armas_1.wav` | combate | tres golpes de metal a 0, 130 y 310 ms: parciales inarmonicos (2,3-8,8 kHz) con batido y decaimiento rapido mas un golpe de ruido de 1,8-9 kHz; semilla 641 | 1.30 s | 112.0 KB | -4.0 dBFS | -29.7 dBFS | 0 | razonado (palos y sables: «sin mas armas que palos») / diseno |
| `choque_armas_2.wav` | combate | idem, semilla 645 | 1.30 s | 112.0 KB | -4.0 dBFS | -28.0 dBFS | 0 | razonado / diseno |
| `descarga_senal.wav` | combate | catorce fusiles en dos filas (0-160 ms), retumbo x1,3 y ecos a 0,42 y 0,86 s: la descarga «que parecio canonazo» del parte; misma sintesis que descarga_torre; semilla 611 | 3.25 s | 280.0 KB | -1.5 dBFS | -24.3 dBFS | 0 | documentado (la descarga que parecio canonazo) / diseno (la senal general) |
| `descarga_torre.wav` | combate | diez fusiles de chispa (chasquido > 2,2 kHz, cuerpo 180-1400 Hz, golpe grave con barrido 155 -> 95 Hz) disparados en una fila con desorden de 0-70 ms, retumbo grave (< 300 Hz) y subgrave 72 -> 32 Hz, dos ecos de la quebrada a 0,36 y 0,72 s, reverberacion de 1,9 s; semilla 601 | 3.00 s | 258.4 KB | -1.5 dBFS | -24.6 dBFS | 0 | documentado (la torre con tiradores; el fuego «indecible») / diseno (la cantidad) |
| `disparo_1.wav` | combate | un fusil de chispa: chasquido, cuerpo y golpe grave con barrido; reverberacion corta de 0,8 s; semilla 621 | 1.20 s | 103.4 KB | -3.0 dBFS | -25.5 dBFS | 0 | razonado |
| `disparo_2.wav` | combate | idem, semilla 622 (otra variante al azar) | 1.20 s | 103.4 KB | -3.0 dBFS | -23.8 dBFS | 0 | razonado |
| `disparo_3.wav` | combate | idem, semilla 623 | 1.20 s | 103.4 KB | -3.0 dBFS | -25.7 dBFS | 0 | razonado |
| `explosion_polvora.wav` | combate | chasquido, retumbo (< 240 Hz), subgrave 70 -> 26 Hz y medios, 45 chisporroteos que se apagan, tres escombros, eco a 0,5 s y reverberacion de 2 s; semilla 641 | 3.25 s | 280.0 KB | -1.5 dBFS | -21.8 dBFS | 0 | documentado (la polvora quemada) / diseno |
| `impacto.wav` | combate | golpe sordo (< 350 Hz, 95 Hz) con tierra que salta (> 3 kHz, 15 ms despues); semilla 631 | 0.65 s | 56.0 KB | -5.0 dBFS | -26.3 dBFS | 0 | diseno |
| `alerta.wav` | interfaz | tres notas de pifano (880, 880 y 1175 Hz; armonicos impares) en 0,65 s | 1.00 s | 86.2 KB | -6.0 dBFS | -13.8 dBFS | 0 | diseno (interfaz) |
| `aviso.wav` | interfaz | un toque breve y suave (1320 Hz con un chasquido de 2-5 kHz); semilla 801 | 0.31 s | 26.7 KB | -12.0 dBFS | -30.2 dBFS | 0 | diseno (interfaz) |
| `derrota.wav` | interfaz | dos notas graves de metal descendentes (re2, sib1) con un redoble que se apaga; semilla 821 | 2.90 s | 249.8 KB | -4.0 dBFS | -12.8 dBFS | 0 | diseno (interfaz) |
| `orden_ok.wav` | interfaz | dos toques de madera (1,5-4,5 kHz) con notas de 740 y 988 Hz; semilla 771 | 0.45 s | 38.8 KB | -8.0 dBFS | -24.1 dBFS | 0 | diseno (interfaz) |
| `orden_rechazada.wav` | interfaz | dos notas graves (185 y 139 Hz, 5 armonicos) con un bloque de madera apagado; semilla 781 | 0.50 s | 43.1 KB | -8.0 dBFS | -21.2 dBFS | 0 | diseno (interfaz) |
| `victoria.wav` | interfaz | dos timbales, cuatro notas de metal ascendentes (re4, fa#4, la4, re5) y el acorde de re mayor sostenido; reverberacion de 1,6 s; semilla 811 | 3.10 s | 267.1 KB | -3.0 dBFS | -16.7 dBFS | 0 | diseno (interfaz) |
| `campana_alarma.wav` | senales y avisos del campo | tres golpes de campana (fundamental 480 Hz, parciales inarmonicos con batido) a 0, 0,55 y 1,1 s; reverberacion de 1,5 s; semillas 741-744 | 3.30 s | 284.3 KB | -4.0 dBFS | -16.2 dBFS | 0 | diseno (la alarma de la guarnicion; que tocaran la campana no esta documentado) |
| `campana_decision.wav` | senales y avisos del campo | un golpe de campana chica (660 Hz) con cola; semillas 751-752 | 1.80 s | 155.1 KB | -7.0 dBFS | -18.0 dBFS | 0 | diseno (interfaz) |
| `captura.wav` | senales y avisos del campo | golpe de tambor y dos notas de corneta (do5, sol5): el frente cae; semilla 731 | 1.25 s | 107.7 KB | -5.0 dBFS | -13.5 dBFS | 0 | diseno |
| `corneta.wav` | senales y avisos del campo | toque de corneta de cuatro notas (sol4, do5, mi5, sol5) con armonicos de metal cuyo corte se abre en el ataque y vibrato en la ultima; reverberacion de 1,4 s | 1.87 s | 161.1 KB | -4.0 dBFS | -13.5 dBFS | 0 | diseno (no hay toque documentado) |
| `tambor_refuerzo.wav` | senales y avisos del campo | redoble militar (cuatro golpes rapidos y dos acentos, dos veces) filtrado a 1,4 kHz y con reverberacion larga: la columna realista por el camino del sur; semilla 761 | 3.00 s | 258.4 KB | -8.0 dBFS | -25.9 dBFS | 0 | razonado (el refuerzo) / diseno |

Los lazos (`lluvia_noche`, `viento_quebrada`, `grillos`, `alba_pajaros`) se reproducen con `loop_mode = LOOP_FORWARD` sobre una copia del
recurso (igual que hace `scripts/audio_manager.gd` con los ambientes de la Justina); el resto son disparos de una vez. El mapeo de eventos a
sonidos vive en `data/humahuaca_audio.json` y el reproductor en `scripts/humahuaca/view/humahuaca_audio.gd`.
