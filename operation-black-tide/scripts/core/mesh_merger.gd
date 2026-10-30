class_name MeshMerger
extends RefCounted
## Junta várias MeshInstance3D estáticas em poucas malhas (uma por material e
## por célula do mapa). Cada MeshInstance3D é uma chamada de desenho separada,
## e o greybox procedural cria milhares delas — agrupar reduz drasticamente o
## custo de CPU/GPU, principalmente em placas de vídeo integradas.
## A colisão não muda: os StaticBody3D continuam com seus CollisionShape3D.


## Agrupa as malhas sob `root`.
##  recursive = false: só filhos diretos (para personagens com partes animadas)
##  cell_size: tamanho da célula (m) para manter o descarte por câmera eficiente
static func merge(root: Node3D, recursive: bool = true, cell_size: float = 32.0) -> int:
	var buckets: Dictionary = {}
	var inv := root.global_transform.affine_inverse()
	var candidates: Array = root.find_children("*", "MeshInstance3D", recursive, false)
	for node in candidates:
		var mi := node as MeshInstance3D
		if mi.mesh == null or mi.skin != null or not mi.visible or mi.mesh.get_surface_count() != 1:
			continue
		var mat: Material = mi.material_override if mi.material_override else mi.mesh.surface_get_material(0)
		if mat == null or mat is ShaderMaterial:
			continue
		var xf := inv * mi.global_transform
		var cell := Vector3i(floori(xf.origin.x / cell_size), 0, floori(xf.origin.z / cell_size))
		var key := "%s|%d|%d" % [cell, mat.get_instance_id(), mi.cast_shadow]
		if not buckets.has(key):
			buckets[key] = {"mat": mat, "shadow": mi.cast_shadow, "items": []}
		buckets[key]["items"].append([mi, xf])
	var merged := 0
	for key in buckets:
		var b: Dictionary = buckets[key]
		var items: Array = b["items"]
		if items.size() < 2:
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for it in items:
			st.append_from((it[0] as MeshInstance3D).mesh, 0, it[1])
		var mesh := st.commit()
		var out := MeshInstance3D.new()
		out.mesh = mesh
		out.material_override = b["mat"]
		out.cast_shadow = b["shadow"]
		root.add_child(out)
		for it in items:
			var old := it[0] as MeshInstance3D
			old.get_parent().remove_child(old)
			old.free()
		merged += items.size()
	return merged
