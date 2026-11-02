extends RefCounted
## Relieve de HumahuacaTerrain (CONTRATO 2.1 y 3.1). Dueña: relieve_mapa. Solo funciones estáticas sobre arreglos empaquetados: la clase
## `humahuaca_terrain.gd` las llama una vez al hornear y no vuelve a interpolar nada por consulta.
##
## Qué hay acá: la interpolación de Catmull-Rom SEPARABLE de la ventana de 10 m a la malla de juego de 4 m, el micro-relieve de semilla fija
## (tres ondas planas; la misma definición que usa tools/build_humahuaca_terrain.py), las capas de diseño (domo, plataforma, quebraditas y
## cauce), el residuo del domo y la lectura bilineal de una malla de 4 m. Todas las alturas son metros sobre el cero local (datum 2 940 m).
## Convenciones: nodo (i, j) de la malla en x = i·cell, z = j·cell; índice = j·nx + i; +z es el sur. `yaw_deg` es el rumbo horario visto en el
## mapa (VP-03): el eje local «largo» de una capa apunta a (cos yaw, sin yaw) en (x, z), el «ancho» a (−sin yaw, cos yaw).

const RING_R_M := 135.0  # radio del anillo con el que el QA (R05) mide la prominencia: 16 puntos alrededor del centro del domo
const RING_POINTS := 16


## Catmull-Rom separable: primero cada fila de la ventana a las columnas de salida y después cada columna a las filas de salida (52 000 evaluaciones
## en vez de 600 000). Los nodos de afuera de la ventana se repiten (borde plano); el nodo de salida que cae sobre un nodo de la ventana lo reproduce.
static func resample_catmull(win: PackedFloat32Array, wnx: int, wnz: int, wcell: float, nx: int, nz: int, cell: float) -> PackedFloat32Array:
	var cols := _catmull_axis(wnx, wcell, nx, cell)
	var rows := _catmull_axis(wnz, wcell, nz, cell)
	var ci0: PackedInt32Array = cols[0]
	var ci1: PackedInt32Array = cols[1]
	var ci2: PackedInt32Array = cols[2]
	var ci3: PackedInt32Array = cols[3]
	var cw0: PackedFloat32Array = cols[4]
	var cw1: PackedFloat32Array = cols[5]
	var cw2: PackedFloat32Array = cols[6]
	var cw3: PackedFloat32Array = cols[7]
	var tmp := PackedFloat32Array()
	tmp.resize(wnz * nx)
	for j in range(wnz):
		var base := j * wnx
		var out_base := j * nx
		for i in range(nx):
			tmp[out_base + i] = cw0[i] * win[base + ci0[i]] + cw1[i] * win[base + ci1[i]] + cw2[i] * win[base + ci2[i]] + cw3[i] * win[base + ci3[i]]
	var ri0: PackedInt32Array = rows[0]
	var ri1: PackedInt32Array = rows[1]
	var ri2: PackedInt32Array = rows[2]
	var ri3: PackedInt32Array = rows[3]
	var rw0: PackedFloat32Array = rows[4]
	var rw1: PackedFloat32Array = rows[5]
	var rw2: PackedFloat32Array = rows[6]
	var rw3: PackedFloat32Array = rows[7]
	var out := PackedFloat32Array()
	out.resize(nx * nz)
	for j in range(nz):
		var o0 := ri0[j] * nx
		var o1 := ri1[j] * nx
		var o2 := ri2[j] * nx
		var o3 := ri3[j] * nx
		var w0 := rw0[j]
		var w1 := rw1[j]
		var w2 := rw2[j]
		var w3 := rw3[j]
		var out_base := j * nx
		for i in range(nx):
			out[out_base + i] = w0 * tmp[o0 + i] + w1 * tmp[o1 + i] + w2 * tmp[o2 + i] + w3 * tmp[o3 + i]
	return out


## Índices y pesos de Catmull-Rom de un eje: devuelve [i0, i1, i2, i3, w0, w1, w2, w3] con un valor por nodo de salida.
static func _catmull_axis(n_src: int, src_cell: float, n_out: int, out_cell: float) -> Array:
	var i0 := PackedInt32Array()
	var i1 := PackedInt32Array()
	var i2 := PackedInt32Array()
	var i3 := PackedInt32Array()
	var w0 := PackedFloat32Array()
	var w1 := PackedFloat32Array()
	var w2 := PackedFloat32Array()
	var w3 := PackedFloat32Array()
	for k in range(n_out):
		var f := float(k) * out_cell / src_cell
		var base := clampi(int(floorf(f)), 0, n_src - 1)
		var t := f - float(base)
		i0.append(clampi(base - 1, 0, n_src - 1))
		i1.append(base)
		i2.append(clampi(base + 1, 0, n_src - 1))
		i3.append(clampi(base + 2, 0, n_src - 1))
		var t2 := t * t
		var t3 := t2 * t
		w0.append(0.5 * (-t3 + 2.0 * t2 - t))
		w1.append(0.5 * (3.0 * t3 - 5.0 * t2 + 2.0))
		w2.append(0.5 * (-3.0 * t3 + 4.0 * t2 + t))
		w3.append(0.5 * (t3 - t2))
	return [i0, i1, i2, i3, w0, w1, w2, w3]


## Lectura bilineal de una malla de `cell` m con origen en (0, 0). Es EL interpolador de la altura: height_at lo repite en línea (una prueba las compara).
static func bilerp(arr: PackedFloat32Array, nx: int, nz: int, cell: float, x: float, z: float) -> float:
	var fx := clampf(x / cell, 0.0, float(nx - 1))
	var fz := clampf(z / cell, 0.0, float(nz - 1))
	var i := mini(int(fx), nx - 2)
	var j := mini(int(fz), nz - 2)
	var tx := fx - float(i)
	var tz := fz - float(j)
	var k := j * nx + i
	var a := arr[k]
	var b := arr[k + 1]
	var c := arr[k + nx]
	var d := arr[k + nx + 1]
	return a + (b - a) * tx + (c - a) * tz + (a - b - c + d) * tx * tz


static func sstep(e0: float, e1: float, x: float) -> float:
	var t := clampf((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


# ---------------------------------------------------------------------------------------------------------------------
# Micro-relief: cinco ondas planas de semilla fija, torcidas por un desplazamiento suave y con la amplitud modulada (diseño, ±amp m, onda de 25 m o más)

const MICRO_BASE_LAMBDA := [36.0, 44.0, 55.0, 70.0, 90.0]  # × (longitud de onda mínima / 25 m) × (0,9 a 1,1): con la torsión nunca baja de ≈ 25 m
const MICRO_WEIGHTS := [0.30, 0.25, 0.20, 0.15, 0.10]  # suman 1: |micro| ≤ amp
const WARP_A := [10.0, 6.0, 9.0, 5.0]  # amplitudes del desplazamiento (m): wx = A0·sin(2π z/190 + φ0) + A1·sin(2π (x − z)/310 + φ1); wz = A2·sin(2π x/170 + φ2) + A3·sin(2π (x + z)/260 + φ3)


## Parámetros del micro-relieve: las cinco ondas {ang, lam, phase, weight}, las cuatro fases del desplazamiento y la fase de la modulación. LCG de 31 bits
## (el mismo de tools/build_humahuaca_terrain.py, que lo repite para estimar el residuo del domo): tres sorteos por onda y después cinco más.
static func micro_params(seed_value: int, wavelength: float) -> Dictionary:
	var s := seed_value & 0x7FFFFFFF
	var comps: Array = []
	for k in range(5):
		var vals: Array = []
		for _n in range(3):
			s = (s * 1103515245 + 12345) & 0x7FFFFFFF
			vals.append(float(s) / 2147483648.0)
		comps.append({"ang": (float(vals[0]) - 0.5) * 2.618, "lam": wavelength / 25.0 * float(MICRO_BASE_LAMBDA[k]) * (0.9 + 0.2 * float(vals[1])),
			"phase": float(vals[2]) * TAU, "weight": float(MICRO_WEIGHTS[k])})
	var warp: Array = []
	for _n in range(5):
		s = (s * 1103515245 + 12345) & 0x7FFFFFFF
		warp.append(float(s) / 2147483648.0 * TAU)
	return {"comps": comps, "warp": warp.slice(0, 4), "mod_phase": warp[4]}


## Valor del micro-relieve en un punto (sin el apagado de los bordes de la ventana): la definición de referencia. add_micro la repite por nodo.
static func micro_at(x: float, z: float, params: Dictionary, amp: float) -> float:
	var warp: Array = params["warp"]
	var wx := float(WARP_A[0]) * sin(TAU * z / 190.0 + float(warp[0])) + float(WARP_A[1]) * sin(TAU * (x - z) / 310.0 + float(warp[1]))
	var wz := float(WARP_A[2]) * sin(TAU * x / 170.0 + float(warp[2])) + float(WARP_A[3]) * sin(TAU * (x + z) / 260.0 + float(warp[3]))
	var mod := 0.8 + 0.2 * sin(TAU * (x * 0.8 + z * 0.6) / 420.0 + float(params["mod_phase"]))
	var total := 0.0
	for c in params["comps"]:
		total += float(c.weight) * sin(TAU * ((x + wx) * cos(float(c.ang)) + (z + wz) * sin(float(c.ang))) / float(c.lam) + float(c.phase))
	return amp * mod * total


## Suma el micro-relieve a la malla `h`. Se apaga en los `fade_m` metros de adentro del borde de la ventana (suave), para que el borde coincida con
## el contexto y la altura sea continua al salir de la ventana. Las ondas del desplazamiento y de la modulación se tabulan por columna y por fila.
static func add_micro(h: PackedFloat32Array, nx: int, nz: int, cell: float, params: Dictionary, amp: float, fade_m: float, size: Vector2) -> void:
	var warp: Array = params["warp"]
	var comps: Array = params["comps"]
	var n_comp := comps.size()
	var kc := PackedFloat32Array()  # cos(ang), sin(ang), 2π/lam, fase y peso de cada onda, en fila
	for c in comps:
		kc.append(cos(float(c.ang)))
		kc.append(sin(float(c.ang)))
		kc.append(TAU / float(c.lam))
		kc.append(float(c.phase))
		kc.append(float(c.weight))
	var w0 := float(warp[0])
	var w1 := float(warp[1])
	var w2 := float(warp[2])
	var w3 := float(warp[3])
	var wm := float(params["mod_phase"])
	var a0 := float(WARP_A[0])
	var a1 := float(WARP_A[1])
	var a2 := float(WARP_A[2])
	var a3 := float(WARP_A[3])
	# tablas por columna (x) y por fila (z) de las ondas del desplazamiento y de la modulación
	var sx1 := PackedFloat32Array()  # sin y cos de 2π(x − z)/310 + φ1 = sin(ax)·cos(az) − cos(ax)·sin(az), con ax = 2πx/310 + φ1, az = 2πz/310
	var cx1 := PackedFloat32Array()
	var sx2 := PackedFloat32Array()  # 2π x/170 + φ2
	var sx3 := PackedFloat32Array()  # 2π(x + z)/260 + φ3: sin(ax + az)
	var cx3 := PackedFloat32Array()
	var sxm := PackedFloat32Array()  # 2π(0,8 x + 0,6 z)/420 + φm
	var cxm := PackedFloat32Array()
	var dxi := PackedFloat32Array()
	for i in range(nx):
		var x := float(i) * cell
		var a := TAU * x / 310.0 + w1
		sx1.append(sin(a))
		cx1.append(cos(a))
		sx2.append(sin(TAU * x / 170.0 + w2))
		var b := TAU * x / 260.0 + w3
		sx3.append(sin(b))
		cx3.append(cos(b))
		var m := TAU * x * 0.8 / 420.0 + wm
		sxm.append(sin(m))
		cxm.append(cos(m))
		dxi.append(minf(x, size.x - x))
	for j in range(nz):
		var z := float(j) * cell
		var dz := minf(z, size.y - z)
		var wxz := a0 * sin(TAU * z / 190.0 + w0)
		var az := TAU * z / 310.0
		var s_az := sin(az)
		var c_az := cos(az)
		var bz := TAU * z / 260.0
		var s_bz := sin(bz)
		var c_bz := cos(bz)
		var mz := TAU * z * 0.6 / 420.0
		var s_mz := sin(mz)
		var c_mz := cos(mz)
		var base := j * nx
		for i in range(nx):
			var d := minf(dxi[i], dz)
			if d <= 0.0:
				continue
			var wx := wxz + a1 * (sx1[i] * c_az - cx1[i] * s_az)
			var wz := a2 * sx2[i] + a3 * (sx3[i] * c_bz + cx3[i] * s_bz)
			var mod := 0.8 + 0.2 * (sxm[i] * c_mz + cxm[i] * s_mz)
			var px := float(i) * cell + wx
			var pz := float(j) * cell + wz
			var total := 0.0
			for c in range(n_comp):
				var o := c * 5
				total += kc[o + 4] * sin((px * kc[o] + pz * kc[o + 1]) * kc[o + 2] + kc[o + 3])
			var m := amp * mod * total
			if d < fade_m:
				var t := d / fade_m
				m *= t * t * (3.0 - 2.0 * t)
			h[base + i] += m


# ---------------------------------------------------------------------------------------------------------------------
# Capas de diseño

## Perfil del domo: 1 hasta `core` m del centro y media onda de coseno hasta `support` m (fuera, 0). Es un diseño (rotulado como tal en report()).
static func dome_profile(r: float, core: float, support: float) -> float:
	if r <= core:
		return 1.0
	if r >= support:
		return 0.0
	return 0.5 * (1.0 + cos(PI * (r - core) / (support - core)))


static func add_dome(h: PackedFloat32Array, nx: int, nz: int, cell: float, center: Vector2, core: float, support: float, delta: float) -> void:
	for j in range(maxi(0, floori((center.y - support) / cell)), mini(nz - 1, ceili((center.y + support) / cell)) + 1):
		for i in range(maxi(0, floori((center.x - support) / cell)), mini(nx - 1, ceili((center.x + support) / cell)) + 1):
			var r := Vector2(float(i) * cell - center.x, float(j) * cell - center.y).length()
			if r < support:
				h[j * nx + i] += delta * dome_profile(r, core, support)


## Nivelación de una plataforma rectangular: dentro del rectángulo la altura vale `level`; afuera se mezcla con el terreno en `falloff` m (coseno),
## con esquinas redondeadas. El rectángulo se gira `yaw_deg` (rumbo horario) alrededor de `center`. Devuelve el peso de la nivelación por nodo
## (1 dentro, 0 lejos): el micro-relieve se apaga con ese peso, porque una plataforma es plana.
static func level_platform(h: PackedFloat32Array, nx: int, nz: int, cell: float, center: Vector2, length: float, width: float, yaw_deg: float, falloff: float, level: float) -> PackedFloat32Array:
	var weights := PackedFloat32Array()
	weights.resize(nx * nz)
	var ang := deg_to_rad(yaw_deg)
	var ca := cos(ang)
	var sa := sin(ang)
	var reach := 0.5 * Vector2(length, width).length() + falloff
	for j in range(maxi(0, floori((center.y - reach) / cell)), mini(nz - 1, ceili((center.y + reach) / cell)) + 1):
		for i in range(maxi(0, floori((center.x - reach) / cell)), mini(nx - 1, ceili((center.x + reach) / cell)) + 1):
			var dx := float(i) * cell - center.x
			var dz := float(j) * cell - center.y
			var u := dx * ca + dz * sa
			var v := -dx * sa + dz * ca
			var out_u := maxf(absf(u) - length * 0.5, 0.0)
			var out_v := maxf(absf(v) - width * 0.5, 0.0)
			var d := sqrt(out_u * out_u + out_v * out_v)
			if d >= falloff:
				continue
			var w := 1.0 if d <= 0.0 else 0.5 * (1.0 + cos(PI * d / falloff))
			var k := j * nx + i
			h[k] = lerpf(h[k], level, w)
			weights[k] = w
	return weights


## Hondonada (quebradita): `delta` (negativo) en un canal de `width` m medido a media profundidad, con piso de un nodo de ancho para que cualquier
## alineación con la malla de 4 m la vea entera, y dos bancos de `bank_m` m a los costados (la tierra que sacó el agua): en una ladera el canal solo
## no tapa nada del lado de abajo y con los bancos sí. El extremo cerrado termina en una pared; el abierto sigue y se desvanece en `falloff` m hacia
## el llano. `open_side`: «oeste» abre hacia el −x local (con yaw 0), «este» hacia el +x.
static func add_gully(h: PackedFloat32Array, nx: int, nz: int, cell: float, center: Vector2, length: float, width: float, yaw_deg: float, delta: float, falloff: float, open_side: String, bank_m: float = 0.0) -> void:
	var ang := deg_to_rad(yaw_deg)
	var ca := cos(ang)
	var sa := sin(ang)
	var wall := cell
	var half_len := length * 0.5
	var open_sign := -1.0 if open_side == "oeste" else 1.0
	var bank_w := 4.0
	var reach := half_len + falloff + wall + bank_w
	for j in range(maxi(0, floori((center.y - reach) / cell)), mini(nz - 1, ceili((center.y + reach) / cell)) + 1):
		for i in range(maxi(0, floori((center.x - reach) / cell)), mini(nx - 1, ceili((center.x + reach) / cell)) + 1):
			var dx := float(i) * cell - center.x
			var dz := float(j) * cell - center.y
			var u := (dx * ca + dz * sa) * open_sign  # + hacia el extremo abierto
			var v := -dx * sa + dz * ca
			var av := absf(v)
			var cross := 1.0 - sstep(width * 0.5 - wall * 0.5, width * 0.5 + wall * 0.5, av)
			var lift := 0.0
			if bank_m > 0.0:
				var v0 := width * 0.5 + wall * 0.5
				if av > v0 and av < v0 + bank_w:
					lift = bank_m * sin(PI * (av - v0) / bank_w)
			if cross <= 0.0 and lift <= 0.0:
				continue
			var along := 1.0
			if u > half_len:
				along = 1.0 - sstep(0.0, falloff, u - half_len)
			elif u < -half_len:
				along = sstep(-half_len - wall * 0.5, -half_len + wall * 0.5, u)
			h[j * nx + i] += (delta * cross + lift) * along


## Talla el cauce a lo largo de la polilínea del río (`pts`: Vector2 en x, z; `widths`: ancho del lecho en cada punto). Devuelve [distancia al eje,
## semiancho del lecho en el punto más cercano] por nodo (para las superficies: agua y sedimento) y suma la talla a `h`. El perfil tiene un fondo
## llano hasta 0,55 del semiancho y sube con suavidad hasta el semiancho más `falloff` m.
static func carve_river(h: PackedFloat32Array, nx: int, nz: int, cell: float, pts: PackedVector2Array, widths: PackedFloat32Array, delta: float, falloff: float) -> Array:
	var dist := PackedFloat32Array()
	dist.resize(nx * nz)
	dist.fill(1.0e9)
	var half := PackedFloat32Array()
	half.resize(nx * nz)
	var carve := PackedFloat32Array()
	carve.resize(nx * nz)
	var lo_i := nx
	var hi_i := -1
	var lo_j := nz
	var hi_j := -1
	for k in range(pts.size() - 1):
		var a := pts[k]
		var b := pts[k + 1]
		var ab := b - a
		var len2 := maxf(ab.length_squared(), 0.000001)
		var reach := maxf(widths[k], widths[k + 1]) * 0.5 + falloff
		var i0 := maxi(0, floori((minf(a.x, b.x) - reach) / cell))
		var i1 := mini(nx - 1, ceili((maxf(a.x, b.x) + reach) / cell))
		var j0 := maxi(0, floori((minf(a.y, b.y) - reach) / cell))
		var j1 := mini(nz - 1, ceili((maxf(a.y, b.y) + reach) / cell))
		lo_i = mini(lo_i, i0)
		hi_i = maxi(hi_i, i1)
		lo_j = mini(lo_j, j0)
		hi_j = maxi(hi_j, j1)
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				var px := float(i) * cell - a.x
				var pz := float(j) * cell - a.y
				var t := clampf((px * ab.x + pz * ab.y) / len2, 0.0, 1.0)
				var ex := px - ab.x * t
				var ez := pz - ab.y * t
				var d := sqrt(ex * ex + ez * ez)
				var idx := j * nx + i
				if d >= dist[idx]:
					continue
				var hw := 0.5 * lerpf(widths[k], widths[k + 1], t)
				dist[idx] = d
				half[idx] = hw
				carve[idx] = delta * (1.0 - sstep(hw * 0.55, hw + falloff, d))
	for j in range(maxi(lo_j, 0), mini(hi_j, nz - 1) + 1):
		for i in range(maxi(lo_i, 0), mini(hi_i, nx - 1) + 1):
			var idx := j * nx + i
			h[idx] += carve[idx]
	return [dist, half]


## Prominencia de un punto sobre la media de su anillo: 16 puntos a 135 m del centro del domo (la medida del QA, R05), con `h` ya sin domo ni plataforma.
static func ring_mean(h: PackedFloat32Array, nx: int, nz: int, cell: float, center: Vector2) -> float:
	var total := 0.0
	for k in range(RING_POINTS):
		var ang := TAU * float(k) / float(RING_POINTS)
		total += bilerp(h, nx, nz, cell, center.x + RING_R_M * cos(ang), center.y + RING_R_M * sin(ang))
	return total / float(RING_POINTS)
