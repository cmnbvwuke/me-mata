class_name LevelBuilder
extends RefCounted
## Utilitário para montar níveis "greybox" em código: caixas com colisão,
## paredes com portas/janelas, obstáculos de cobertura (gerando CoverPoints
## automaticamente), cilindros, vegetação e luzes.
## Tudo que fica sob `root` (dentro da NavigationRegion3D) entra no navmesh.

var root: Node3D          ## Geometria estática (entra no bake do navmesh)
var cover_root: Node3D    ## Onde os CoverPoints são criados
var _materials: Dictionary = {}
var _detail_texture: NoiseTexture2D


func _init(p_root: Node3D, p_cover_root: Node3D) -> void:
	root = p_root
	cover_root = p_cover_root


# =========================================================================
# Materiais
# =========================================================================

## Material com textura de ruído triplanar sutil (quebra o aspecto "liso").
func material(mat_name: String, color: Color, roughness: float = 0.9, metallic: float = 0.0,
		detail: bool = true) -> StandardMaterial3D:
	if _materials.has(mat_name):
		return _materials[mat_name]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	if detail:
		m.albedo_texture = _get_detail_texture()
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(0.35, 0.35, 0.35)
	_materials[mat_name] = m
	return m


func emissive(mat_name: String, color: Color, energy: float = 2.0) -> StandardMaterial3D:
	if _materials.has(mat_name):
		return _materials[mat_name]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	_materials[mat_name] = m
	return m


func _get_detail_texture() -> NoiseTexture2D:
	if _detail_texture == null:
		var noise := FastNoiseLite.new()
		noise.frequency = 0.03
		noise.fractal_octaves = 4
		_detail_texture = NoiseTexture2D.new()
		_detail_texture.noise = noise
		_detail_texture.width = 256
		_detail_texture.height = 256
		_detail_texture.seamless = true
		var ramp := Gradient.new()
		ramp.set_color(0, Color(0.72, 0.72, 0.72))
		ramp.set_color(1, Color(1.0, 1.0, 1.0))
		_detail_texture.color_ramp = ramp
	return _detail_texture


# =========================================================================
# Primitivas
# =========================================================================

## Caixa com colisão (StaticBody3D na camada WORLD). `collide=false` cria só o visual.
func box(size: Vector3, center: Vector3, mat: Material, collide: bool = true, rot_y: float = 0.0,
		parent: Node3D = null) -> Node3D:
	var target := parent if parent != null else root
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	if not collide:
		mi.position = center
		mi.rotation.y = rot_y
		target.add_child(mi)
		return mi
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	body.add_child(mi)
	body.position = center
	body.rotation.y = rot_y
	target.add_child(body)
	return body


## Colisor invisível (limites do mapa, aproximação de objetos complexos).
func collider(size: Vector3, center: Vector3, rot_y: float = 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	body.position = center
	body.rotation.y = rot_y
	root.add_child(body)
	return body


func cylinder(radius: float, height: float, base: Vector3, mat: Material, collide: bool = true,
		segments: int = 16) -> Node3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mi.mesh = mesh
	mi.material_override = mat
	var center := base + Vector3.UP * height * 0.5
	if not collide:
		mi.position = center
		root.add_child(mi)
		return mi
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	cs.shape = shape
	body.add_child(cs)
	body.add_child(mi)
	body.position = center
	root.add_child(body)
	return body


func sphere(radius: float, center: Vector3, mat: Material, scale_y: float = 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 6
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = center
	mi.scale = Vector3(1, scale_y, 1)
	root.add_child(mi)
	return mi


## Arbusto: bloqueia a VISÃO dos inimigos (camada FOLIAGE), mas não o movimento nem tiros.
func bush(center: Vector3, radius: float, mat: Material) -> void:
	sphere(radius, center, mat, 0.75)
	var body := StaticBody3D.new()
	body.collision_layer = Layers.FOLIAGE
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius * 0.85
	cs.shape = shape
	body.add_child(cs)
	body.position = center
	root.add_child(body)


# =========================================================================
# Paredes com aberturas
# =========================================================================
# Aberturas: Vector4(centro, largura, base, topo)
#   porta  -> base 0,   topo 2.2
#   janela -> base 1.0, topo 2.1
#   vão total (sem verga) -> topo >= altura da parede

func wall_x(x0: float, x1: float, z: float, height: float, thickness: float, mat: Material,
		openings: Array[Vector4] = []) -> void:
	for seg in _segments(x0, x1, height, openings):
		box(Vector3(seg.y - seg.x, seg.w - seg.z, thickness),
			Vector3((seg.x + seg.y) * 0.5, (seg.z + seg.w) * 0.5, z), mat)


func wall_z(z0: float, z1: float, x: float, height: float, thickness: float, mat: Material,
		openings: Array[Vector4] = []) -> void:
	for seg in _segments(z0, z1, height, openings):
		box(Vector3(thickness, seg.w - seg.z, seg.y - seg.x),
			Vector3(x, (seg.z + seg.w) * 0.5, (seg.x + seg.y) * 0.5), mat)


## Divide uma parede em retângulos sólidos: Vector4(início, fim, base, topo).
func _segments(a0: float, a1: float, height: float, openings: Array[Vector4]) -> Array[Vector4]:
	var out: Array[Vector4] = []
	var sorted: Array[Vector4] = openings.duplicate()
	sorted.sort_custom(func(p: Vector4, q: Vector4) -> bool: return p.x < q.x)
	var cursor := a0
	for o in sorted:
		var left := o.x - o.y * 0.5
		var right := o.x + o.y * 0.5
		if left > cursor:
			out.append(Vector4(cursor, left, 0.0, height))
		if o.w < height:
			out.append(Vector4(left, right, o.w, height))   # verga
		if o.z > 0.0:
			out.append(Vector4(left, right, 0.0, o.z))      # peitoril
		cursor = right
	if a1 > cursor:
		out.append(Vector4(cursor, a1, 0.0, height))
	return out


# =========================================================================
# Cobertura
# =========================================================================

## Obstáculo de cobertura + CoverPoints nas laterais (a IA escolhe o lado seguro).
func cover_obstacle(size: Vector3, center: Vector3, mat: Material, rot_y: float = 0.0,
		points_on_ends: bool = false) -> Node3D:
	var node := box(size, center, mat, true, rot_y)
	var basis := Basis(Vector3.UP, rot_y)
	var ground := Vector3(center.x, 0.0, center.z)
	var offsets: Array[Vector3] = []
	var half_x := size.x * 0.5 + 0.55
	var half_z := size.z * 0.5 + 0.55
	# Pontos ao longo das faces compridas
	if size.x >= size.z:
		var n := maxi(1, int(size.x / 1.6))
		for i in n:
			var x := lerpf(-size.x * 0.5 + 0.5, size.x * 0.5 - 0.5, (i + 0.5) / n) if n > 1 else 0.0
			offsets.append(Vector3(x, 0, half_z))
			offsets.append(Vector3(x, 0, -half_z))
		if points_on_ends:
			offsets.append(Vector3(half_x, 0, 0))
			offsets.append(Vector3(-half_x, 0, 0))
	else:
		var n := maxi(1, int(size.z / 1.6))
		for i in n:
			var z := lerpf(-size.z * 0.5 + 0.5, size.z * 0.5 - 0.5, (i + 0.5) / n) if n > 1 else 0.0
			offsets.append(Vector3(half_x, 0, z))
			offsets.append(Vector3(-half_x, 0, z))
		if points_on_ends:
			offsets.append(Vector3(0, 0, half_z))
			offsets.append(Vector3(0, 0, -half_z))
	for off in offsets:
		add_cover_point(ground + basis * off)
	return node


func add_cover_point(pos: Vector3) -> CoverPoint:
	var cp := CoverPoint.new()
	cp.position = pos
	cover_root.add_child(cp)
	return cp


# =========================================================================
# Luzes
# =========================================================================

func omni(pos: Vector3, color: Color, energy: float, light_range: float, shadows: bool = false,
		parent: Node3D = null) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
	l.omni_attenuation = 1.2
	l.shadow_enabled = shadows
	l.position = pos
	(parent if parent != null else cover_root).add_child(l)
	return l


func spot(pos: Vector3, target: Vector3, color: Color, energy: float, light_range: float,
		angle: float, shadows: bool = true) -> SpotLight3D:
	var l := SpotLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.spot_range = light_range
	l.spot_angle = angle
	l.shadow_enabled = shadows
	l.light_volumetric_fog_energy = 1.5
	cover_root.add_child(l)
	l.global_position = pos
	l.look_at(target, Vector3.UP if absf((target - pos).normalized().y) < 0.98 else Vector3.FORWARD)
	return l
