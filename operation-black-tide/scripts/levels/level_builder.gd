class_name LevelBuilder
extends RefCounted
## Utilitário para montar níveis "greybox" em código: caixas com colisão,
## paredes com portas/janelas, obstáculos de cobertura (gerando CoverPoints
## automaticamente), cilindros, vegetação e luzes.
## Tudo que fica sob `root` (dentro da NavigationRegion3D) entra no navmesh.

var root: Node3D          ## Geometria estática (entra no bake do navmesh)
var cover_root: Node3D    ## Onde os CoverPoints são criados
var _materials: Dictionary = {}
## Janelas recebem vidro (visual, sem colisão) quando true; moldura sempre.
var glass_windows: bool = false
var _detail_texture: NoiseTexture2D
var _normal_texture: NoiseTexture2D
const WATER_SHADER := preload("res://shaders/water.gdshader")


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
		# Relevo sutil (normal map de ruído) para as superfícies não parecerem lisas
		m.normal_enabled = true
		m.normal_texture = _get_normal_texture()
		m.normal_scale = 0.55
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


func _get_normal_texture() -> NoiseTexture2D:
	if _normal_texture == null:
		var noise := FastNoiseLite.new()
		noise.frequency = 0.08
		noise.fractal_octaves = 3
		_normal_texture = NoiseTexture2D.new()
		_normal_texture.noise = noise
		_normal_texture.width = 256
		_normal_texture.height = 256
		_normal_texture.seamless = true
		_normal_texture.as_normal_map = true
		_normal_texture.bump_strength = 5.0
	return _normal_texture


## Superfície de água animada (sem colisão).
func water(center: Vector3, size: Vector2, level: float, subdivisions: int = 140) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = size
	plane.subdivide_width = subdivisions
	plane.subdivide_depth = subdivisions
	mi.mesh = plane
	var m := ShaderMaterial.new()
	m.shader = WATER_SHADER
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(center.x, level, center.z)
	root.add_child(mi)
	return mi


## Coqueiro: tronco curvado em segmentos, folhas caídas em leque e cocos.
func palm(base: Vector3, height: float, rng: RandomNumberGenerator) -> void:
	var trunk := material("palm_trunk", Color(0.32, 0.25, 0.17))
	var frond := material("palm_frond", Color(0.12, 0.22, 0.07), 1.0, 0.0, false)
	var lean := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized() * rng.randf_range(0.6, 1.6)
	var pts: Array[Vector3] = []
	for i in 4:
		var t := float(i) / 3.0
		pts.append(base + Vector3.UP * height * t + lean * t * t)
	var holder := Node3D.new()
	root.add_child(holder)
	for i in 3:
		var r := lerpf(0.2, 0.13, float(i) / 3.0)
		BodyParts.limb(holder, pts[i], pts[i + 1], r, r - 0.03, trunk)
	# Colisão simples do tronco
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.2
	shape.height = height * 0.6
	cs.shape = shape
	body.add_child(cs)
	body.position = base + Vector3.UP * height * 0.3 + lean * 0.1
	root.add_child(body)
	var top := pts[3]
	var count := 8
	for i in count:
		var yaw := TAU * i / count + rng.randf_range(-0.2, 0.2)
		var droop := rng.randf_range(0.35, 0.75)
		var dir := Vector3(sin(yaw), 0, cos(yaw))
		var tip := top + dir * 2.4 * cos(droop) - Vector3.UP * 2.4 * sin(droop) * 0.7
		var mid := top + dir * 1.3 + Vector3.UP * 0.25
		var leaf := BodyParts.box(holder, Vector3(0.55, 0.03, top.distance_to(mid) + 0.1), (top + mid) * 0.5, frond)
		leaf.look_at_from_position(leaf.position, mid, Vector3.UP)
		var leaf2 := BodyParts.box(holder, Vector3(0.45, 0.03, mid.distance_to(tip)), (mid + tip) * 0.5, frond)
		leaf2.look_at_from_position(leaf2.position, tip, Vector3.UP)
		leaf.visibility_range_end = 140.0
		leaf2.visibility_range_end = 140.0
	var nut := material("coconut", Color(0.25, 0.18, 0.09))
	for i in 3:
		var c := BodyParts.sphere(holder, 0.11, top + Vector3(cos(i * 2.1) * 0.18, -0.2, sin(i * 2.1) * 0.18), nut)
		c.visibility_range_end = 45.0


## Árvore de copa larga: tronco com galho e copa formada por esferas sobrepostas.
func broadleaf(base: Vector3, height: float, rng: RandomNumberGenerator) -> void:
	var trunk := material("trunk", Color(0.13, 0.1, 0.07))
	var greens := [material("leaves", Color(0.04, 0.08, 0.04), 1.0), material("leaves_light", Color(0.07, 0.12, 0.05), 1.0)]
	cylinder(rng.randf_range(0.2, 0.3), height, base, trunk, true, 8)
	var holder := Node3D.new()
	root.add_child(holder)
	BodyParts.limb(holder, base + Vector3.UP * height * 0.6, base + Vector3(1.2, height * 0.85, 0.4), 0.12, 0.07, trunk)
	var crown := base + Vector3.UP * height
	for i in 4:
		var off := Vector3(rng.randf_range(-1.4, 1.4), rng.randf_range(-0.6, 0.5), rng.randf_range(-1.4, 1.4))
		var r := rng.randf_range(1.5, 2.4)
		var s := BodyParts.sphere(holder, r, crown + off, greens[i % 2], Vector3(1, 0.7, 1))
		s.visibility_range_end = 160.0


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
	for o in openings:
		if o.z > 0.0:
			_window_frame(Vector3(o.x, 0, z), o.y, o.z, minf(o.w, height), thickness, false)


func wall_z(z0: float, z1: float, x: float, height: float, thickness: float, mat: Material,
		openings: Array[Vector4] = []) -> void:
	for seg in _segments(z0, z1, height, openings):
		box(Vector3(thickness, seg.w - seg.z, seg.y - seg.x),
			Vector3(x, (seg.z + seg.w) * 0.5, (seg.x + seg.y) * 0.5), mat)
	for o in openings:
		if o.z > 0.0:
			_window_frame(Vector3(x, 0, o.x), o.y, o.z, minf(o.w, height), thickness, true)


## Moldura de janela (peitoril saliente, verga e batentes) + vidro opcional.
## Peças finas e sem colisão: não atrapalham o salto pela janela.
func _window_frame(center: Vector3, width: float, sill: float, top: float, thickness: float, along_z: bool) -> void:
	var trim := material("window_trim", Color(0.82, 0.8, 0.74), 0.7)
	var depth := thickness + 0.1
	var parts := [
		[Vector3(width + 0.16, 0.07, depth + 0.06), Vector3(0, sill - 0.035, 0)],   # peitoril
		[Vector3(width + 0.16, 0.08, depth), Vector3(0, top + 0.04, 0)],            # verga
		[Vector3(0.07, top - sill, depth), Vector3(-width * 0.5 - 0.035, (sill + top) * 0.5, 0)],
		[Vector3(0.07, top - sill, depth), Vector3(width * 0.5 + 0.035, (sill + top) * 0.5, 0)],
	]
	for part in parts:
		var size: Vector3 = part[0]
		var off: Vector3 = part[1]
		if along_z:
			size = Vector3(size.z, size.y, size.x)
			off = Vector3(off.z, off.y, off.x)
		box(size, center + off, trim, false)
	if glass_windows:
		var glass := StandardMaterial3D.new()
		glass.albedo_color = Color(0.45, 0.6, 0.7, 0.18)
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.metallic = 0.4
		glass.roughness = 0.05
		var gsize := Vector3(width, top - sill, 0.02)
		if along_z:
			gsize = Vector3(0.02, top - sill, width)
		var g := box(gsize, center + Vector3(0, (sill + top) * 0.5, 0), glass, false)
		(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Travessa central para ler como janela, não como buraco
		var bar := Vector3(0.05, top - sill, 0.05) if not along_z else Vector3(0.05, top - sill, 0.05)
		box(bar, center + Vector3(0, (sill + top) * 0.5, 0), trim, false)


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
