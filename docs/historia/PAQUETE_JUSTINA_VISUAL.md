# Paquete "Justina_Retiro_1806" (informe A-K, 30-oct-2026): qué se tomó para el aspecto

Fuente: `Maravilla Argentina/Justina_Retiro_1806_Paquete_Editable` (LEEME, Informe.md, info/*.md, assets/). Es un punto de partida: se contrastó con Vidal, Boneo 1801, Arrowsmith 1806 y Gillespie de `docs/referencias/justina/`. Pista visual (ronda 1); la matriz histórica y el área jugable los trata la pista de mapa.

| Elemento del paquete | Decisión | Dónde / por qué |
|---|---|---|
| F01 Plaza de Toros octogonal, ruedo circular, ladrillo/cal | Adoptado en el dibujo; medida = `radius_m` del JSON | `world_view.gd _bullring_j`. 90 m entre vértices es Diseño (no verificado). Cuatro puertas: Pillado, orientación desconocida |
| H4 bandera blanca con escudo español (cuenta 1803) | Adoptado como inferencia razonada | Mástil del circo; sin escudo argentino |
| H1 Red Ensign (hipótesis del mercante) | Adoptado como hipótesis/Reconstrucción | Popa del buque. Bandera real del Justina no identificada; sin White Ensign |
| H2 Union del Retiro, H3 guion del 71.º, H5-H6 pabellones españoles | No dibujados | Sin evidencia de izado en la acción; evita anacronismo |
| G7 paleta (HEX) | Adoptada para guiones, muros y teja | Son decisión de diseño, no tintes medidos |
| G1-G4 fichas de personajes | No se rehicieron los modelos | Pendiente; solo guiones de color por grupo (diseño) |
| C: "no extender avenida ribereña uniforme" | Alameda convertida en arboleda irregular | Etiqueta Diseño |
| D3 materiales (tosca, arena húmeda, barro, agua turbia) | Adoptados en shaders | Estética reconstruida |
| D5/F10 casco 40 x 9 m (RMG SLR0583, LNG0016, MSA0204) | Ya en 82f7135 (40 x ~10,5 m) | Diseño por comparables |
| F excluir: Torre, estaciones, grúas, jardines modernos, herrería 1807 | Ninguno modelado | |
| metodo/georef_experimental.json | No usado | Residuo ~17 m: no fija el encallamiento |

Advertencias respetadas: Güemes en la Justina = tradición; sin bandera argentina ni Infernales; Morris/Dunn no se usan (pista no verificada); la nota de Cultura 2022 contiene la atribución errónea de un "Fijo de Caballería".
