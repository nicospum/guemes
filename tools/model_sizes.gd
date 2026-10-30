extends SceneTree
## Imprime el tamaño (AABB en metros, escala 1) de cada GLB de assets/models. Uso: godot --headless --path . --script tools/model_sizes.gd
func _initialize() -> void:
	for n in ["justine", "rider_1806", "dismounted_1806", "horse_only", "house_colonial", "church_colonial", "tree_algarrobo", "tree_cardon", "rock_cluster", "infantry"]:
		var ps = load("res://assets/models/%s.glb" % n)
		if ps == null:
			print(n, " no carga"); continue
		var r: Node = ps.instantiate()
		var box := AABB()
		var first := true
		for m in r.find_children("*", "MeshInstance3D", true, false):
			var xf := Transform3D.IDENTITY
			var cur: Node = m
			while cur != null and cur != r:
				if cur is Node3D: xf = cur.transform * xf
				cur = cur.get_parent()
			var bb: AABB = xf * m.mesh.get_aabb()
			box = bb if first else box.merge(bb)
			first = false
		print("%s: pos=%s size=%s" % [n, str(box.position), str(box.size)])
		r.free()
	quit()
