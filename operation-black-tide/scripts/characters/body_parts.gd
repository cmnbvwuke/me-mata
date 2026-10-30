class_name BodyParts
extends RefCounted
## Peças procedurais para montar personagens (inimigos, HVT, NPCs) com formas
## arredondadas: cápsulas, membros afunilados entre dois pontos, esferas e caixas.
## Malhas iguais são compartilhadas (cache) para economizar memória.

static var _mesh_cache: Dictionary = {}


static func mat(color: Color, roughness: float = 0.85, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m


static func box(parent: Node3D, size: Vector3, pos: Vector3, material: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var key := "box_%s" % size
	if not _mesh_cache.has(key):
		var b := BoxMesh.new()
		b.size = size
		_mesh_cache[key] = b
	return _add(parent, _mesh_cache[key], material, Transform3D(Basis.from_euler(rot), pos))


static func sphere(parent: Node3D, radius: float, pos: Vector3, material: Material, scale: Vector3 = Vector3.ONE,
		hemisphere: bool = false) -> MeshInstance3D:
	var key := "sph_%.3f_%s" % [radius, hemisphere]
	if not _mesh_cache.has(key):
		var s := SphereMesh.new()
		s.radius = radius
		s.height = radius if hemisphere else radius * 2.0
		s.is_hemisphere = hemisphere
		s.radial_segments = 14
		s.rings = 7
		_mesh_cache[key] = s
	return _add(parent, _mesh_cache[key], material, Transform3D(Basis().scaled(scale), pos))


static func capsule(parent: Node3D, radius: float, height: float, pos: Vector3, material: Material,
		scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var key := "cap_%.3f_%.3f" % [radius, height]
	if not _mesh_cache.has(key):
		var c := CapsuleMesh.new()
		c.radius = radius
		c.height = height
		c.radial_segments = 14
		c.rings = 4
		_mesh_cache[key] = c
	return _add(parent, _mesh_cache[key], material, Transform3D(Basis().scaled(scale), pos))


## Membro afunilado de `a` até `b` (raio ra em a, rb em b).
static func limb(parent: Node3D, a: Vector3, b: Vector3, ra: float, rb: float, material: Material) -> MeshInstance3D:
	var length := a.distance_to(b)
	var key := "limb_%.3f_%.3f_%.3f" % [length, ra, rb]
	if not _mesh_cache.has(key):
		var c := CylinderMesh.new()
		c.bottom_radius = ra
		c.top_radius = rb
		c.height = length
		c.radial_segments = 10
		c.rings = 1
		_mesh_cache[key] = c
	return _add(parent, _mesh_cache[key], material, Transform3D(basis_along(b - a), (a + b) * 0.5))


## Base cujo eixo Y aponta na direção dada.
static func basis_along(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var ref := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
	var x := y.cross(ref).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


## Braço completo (ombro -> cotovelo -> mão) com articulações e mão.
static func arm(parent: Node3D, shoulder: Vector3, elbow: Vector3, hand: Vector3, sleeve: Material, hand_mat: Material) -> void:
	sphere(parent, 0.065, shoulder, sleeve)
	limb(parent, shoulder, elbow, 0.062, 0.052, sleeve)
	sphere(parent, 0.052, elbow, sleeve)
	limb(parent, elbow, hand, 0.05, 0.04, sleeve)
	sphere(parent, 0.045, hand, hand_mat, Vector3(1.0, 0.9, 1.25))


## Perna montada sob um pivô no quadril (para animar a caminhada).
static func leg(pivot: Node3D, cloth: Material, boot: Material) -> void:
	var knee := Vector3(0, -0.45, -0.025)
	var ankle := Vector3(0, -0.84, 0.0)
	limb(pivot, Vector3.ZERO, knee, 0.088, 0.07, cloth)
	sphere(pivot, 0.068, knee, cloth)
	limb(pivot, knee, ankle, 0.066, 0.052, cloth)
	box(pivot, Vector3(0.12, 0.11, 0.27), Vector3(0, -0.865, -0.05), boot)
	box(pivot, Vector3(0.125, 0.035, 0.28), Vector3(0, -0.905, -0.05), boot)


## Fuzil estilo AK (soldados) apontando para -Z, pronto para ser segurado.
static func rifle(parent: Node3D, origin: Vector3) -> void:
	var metal := mat(Color(0.06, 0.06, 0.065), 0.45, 0.6)
	var wood := mat(Color(0.32, 0.17, 0.08), 0.7)
	box(parent, Vector3(0.05, 0.085, 0.38), origin + Vector3(0, 0, -0.08), metal)            # receptor
	box(parent, Vector3(0.055, 0.07, 0.22), origin + Vector3(0, -0.005, -0.36), wood)        # guarda-mão
	limb(parent, origin + Vector3(0, 0.012, -0.47), origin + Vector3(0, 0.012, -0.68), 0.012, 0.012, metal)  # cano
	limb(parent, origin + Vector3(0, 0.045, -0.3), origin + Vector3(0, 0.045, -0.5), 0.01, 0.01, metal)     # tubo de gás
	box(parent, Vector3(0.04, 0.19, 0.07), origin + Vector3(0, -0.13, -0.12), metal, Vector3(0.35, 0, 0))   # carregador curvo
	box(parent, Vector3(0.04, 0.1, 0.05), origin + Vector3(0, -0.09, 0.06), wood, Vector3(-0.35, 0, 0))     # empunhadura
	box(parent, Vector3(0.045, 0.1, 0.26), origin + Vector3(0, -0.03, 0.24), wood, Vector3(0.12, 0, 0))     # coronha


static func _add(parent: Node3D, mesh: Mesh, material: Material, xform: Transform3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.transform = xform
	parent.add_child(mi)
	return mi
