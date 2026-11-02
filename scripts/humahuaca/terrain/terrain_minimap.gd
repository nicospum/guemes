extends RefCounted
## Imagen del mapa chico de HumahuacaTerrain (CONTRATO 3.1: `minimap_image`). Dueña: relieve_mapa. Relieve sombreado + curvas de nivel de 20 m + cauce
## (y, si se pide, las superficies teñidas), con el norte arriba y SIN texto ni unidades: los rótulos, la brújula y la escala los pone la interfaz.
## Se pinta sobre la malla de 4 m (226 × 163 nodos de la ventana), se remuestrea (bilineal) al tamaño pedido y las curvas se trazan sobre las alturas
## ya remuestreadas, de modo que quedan finas a cualquier escala. El resultado mide EXACTAMENTE `px`. No dibuja las tapias ni los hitos (son rasgos y
## los dibuja quien los consume). Colores: ids de la paleta de 24 HEX de la lámina 06.

const VT = preload("res://scripts/humahuaca/terrain/vocab_terrain.gd")

const COLORS := {  # superficie → HEX de la paleta (el muro se pinta como suelo seco: las tapias son rasgos)
	"suelo_seco": "B99A72", "sedimento_humedo": "776248", "piedra": "8E8B81", "churqui": "6D7653", "irrigado": "69794B",
	"agua": "8C9B91", "camino": "C4AA82", "patio": "C4AA82", "zanja": "776248", "muro": "B99A72"}
const CONTOUR_HEX := "59432E"  # madera oscura
const CONTOUR_STEP_M := 20.0
const LIGHT := Vector3(-0.55, 0.62, -0.55)  # la luz viene del noroeste, alta


## opts: {"shade": true, "contours": true, "river": true, "surfaces": true (tiñe cada superficie; si no, solo el suelo seco y el río), "exaggeration": 1.3}.
static func render(t, px: Vector2i, opts: Dictionary = {}) -> Image:
	var w := clampi(px.x, 1, 4096)
	var h := clampi(px.y, 1, 4096)
	var shade_on := bool(opts.get("shade", true))
	var contours_on := bool(opts.get("contours", true))
	var river_on := bool(opts.get("river", true))
	var surf_on := bool(opts.get("surfaces", true))
	var ex := float(opts.get("exaggeration", 1.3))
	var nx: int = t.nx
	var nz: int = t.nz
	var cols: int = int(t._imax) + 1
	var rows: int = int(t._jmax) + 1
	var cell: float = t.cell_m
	var hh: PackedFloat32Array = t._h_macro
	var surf: PackedByteArray = t._surf
	var datum: float = t.datum_asl_m
	var palette: Array = []
	for sid in VT.SURFACES:
		palette.append(Color(str(COLORS.get(sid, "B99A72"))))
	var dry: Color = palette[0]
	var light := LIGHT.normalized()
	var base_bytes := PackedByteArray()
	base_bytes.resize(cols * rows * 4)
	var height_bytes := PackedFloat32Array()
	height_bytes.resize(cols * rows)
	for j in range(rows):
		var jm := maxi(j - 1, 0)
		var jp := mini(j + 1, nz - 1)
		for i in range(cols):
			var k := j * nx + i
			var sid := int(surf[k])
			var col: Color = dry
			if surf_on:
				col = palette[sid]
			elif river_on and (sid == 5 or sid == 1):
				col = palette[sid]
			var f := 1.0
			if shade_on:
				var im := maxi(i - 1, 0)
				var ip := mini(i + 1, nx - 1)
				var gx := (hh[j * nx + ip] - hh[j * nx + im]) / (float(ip - im) * cell)
				var gz := (hh[jp * nx + i] - hh[jm * nx + i]) / (float(jp - jm) * cell)
				var n := Vector3(-gx * ex, 1.0, -gz * ex).normalized()
				f = 0.62 + 0.55 * clampf(n.dot(light), 0.0, 1.0)
			var o := (j * cols + i) * 4
			base_bytes[o] = int(clampf(col.r * f, 0.0, 1.0) * 255.0)
			base_bytes[o + 1] = int(clampf(col.g * f, 0.0, 1.0) * 255.0)
			base_bytes[o + 2] = int(clampf(col.b * f, 0.0, 1.0) * 255.0)
			base_bytes[o + 3] = 255
			height_bytes[j * cols + i] = hh[k] + datum
	var base := Image.create_from_data(cols, rows, false, Image.FORMAT_RGBA8, base_bytes)
	var heights := Image.create_from_data(cols, rows, false, Image.FORMAT_RF, height_bytes.to_byte_array())
	if w != cols or h != rows:
		base.resize(w, h, Image.INTERPOLATE_BILINEAR)
		heights.resize(w, h, Image.INTERPOLATE_BILINEAR)
	if contours_on:
		var data := base.get_data()
		var hz := heights.get_data().to_float32_array()
		var cc := Color(CONTOUR_HEX)
		var cr := int(cc.r * 255.0)
		var cg := int(cc.g * 255.0)
		var cb := int(cc.b * 255.0)
		for j in range(h):
			for i in range(w):
				var k := j * w + i
				var band := floorf(hz[k] / CONTOUR_STEP_M)
				if (i + 1 < w and floorf(hz[k + 1] / CONTOUR_STEP_M) != band) or (j + 1 < h and floorf(hz[k + w] / CONTOUR_STEP_M) != band):
					var o := k * 4
					data[o] = int(lerpf(float(data[o]), float(cr), 0.6))
					data[o + 1] = int(lerpf(float(data[o + 1]), float(cg), 0.6))
					data[o + 2] = int(lerpf(float(data[o + 2]), float(cb), 0.6))
		base = Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)
	return base
