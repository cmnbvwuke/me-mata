class_name FX
extends RefCounted
## Efeitos visuais simples e baratos, criados proceduralmente:
## faíscas/poeira de impacto, sangue, buracos de bala (Decal), traçantes,
## clarão de cano e explosões. Todas as funções recebem um nó "contexto"
## qualquer que esteja na árvore (para encontrar a cena atual).

const MAX_DECALS := 70

static var _decals: Array = []
static var _hole_texture: Texture2D
static var _blood_texture: Texture2D
static var _scorch_texture: Texture2D
static var _flash_material: StandardMaterial3D
static var _particle_meshes: Dictionary = {}


static func impact(ctx: Node, pos: Vector3, normal: Vector3) -> void:
	var root := _root(ctx)
	if root == null:
		return
	_burst(root, pos, normal, Color(1.0, 0.7, 0.35), 8, 5.0, 0.22, 0.012, true, 25.0)
	_burst(root, pos, normal, Color(0.32, 0.3, 0.27), 7, 1.4, 0.7, 0.05, false, 40.0)
	AudioManager.play_3d("impact", pos, -10.0, 35.0, 3.0)
	_decal(root, pos, normal, _get_hole_texture(), Vector3(0.09, 0.15, 0.09))


static func blood(ctx: Node, pos: Vector3, dir: Vector3) -> void:
	var root := _root(ctx)
	if root == null:
		return
	_burst(root, pos, dir, Color(0.4, 0.015, 0.015), 14, 2.6, 0.55, 0.028, false, 35.0)
	AudioManager.play_3d("flesh_hit", pos, -6.0, 25.0, 3.0)


static func blood_pool(ctx: Node, pos: Vector3) -> void:
	var root := _root(ctx)
	if root == null:
		return
	_decal(root, pos + Vector3.UP * 0.05, Vector3.UP, _get_blood_texture(), Vector3(1.5, 0.6, 1.5))


static func muzzle_flash(ctx: Node, pos: Vector3, strength: float = 1.0) -> void:
	var root := _root(ctx)
	if root == null:
		return
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.35)
	light.light_energy = 3.0 * strength
	light.omni_range = 5.0
	var quad := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.35, 0.35) * strength
	quad.mesh = qm
	quad.material_override = flash_material()
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	light.add_child(quad)
	root.add_child(light)
	light.global_position = pos
	_free_after(light, 0.05)


## Traçante: um segmento brilhante que viaja da origem ao destino.
static func tracer(ctx: Node, from: Vector3, to: Vector3, color: Color) -> void:
	var root := _root(ctx)
	if root == null:
		return
	var length := from.distance_to(to)
	if length < 1.5:
		return
	var dir := (to - from) / length
	var seg := minf(3.0, length * 0.5)
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.018, 0.018, seg)
	mi.mesh = box
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 6.0
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var start := from + dir * seg * 0.5
	var finish := to - dir * seg * 0.5
	mi.global_position = start
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	mi.look_at(start + dir, up)
	var tw := mi.create_tween()
	tw.tween_property(mi, "global_position", finish, length / 420.0)
	tw.tween_callback(mi.queue_free)


static func explosion(ctx: Node, pos: Vector3, radius: float) -> void:
	var root := _root(ctx)
	if root == null:
		return
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.25)
	light.light_energy = 14.0
	light.omni_range = radius * 5.0
	light.shadow_enabled = GraphicsQuality.level() == GraphicsQuality.Level.HIGH and not OS.has_feature("web")
	root.add_child(light)
	light.global_position = pos + Vector3.UP * 1.5
	var tw := light.create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.7)
	tw.tween_callback(light.queue_free)
	_burst(root, pos + Vector3.UP * 0.5, Vector3.UP, Color(1.0, 0.55, 0.15), 36, 9.0, 0.55, 0.35, true, 80.0)
	_burst(root, pos + Vector3.UP * 0.8, Vector3.UP, Color(0.12, 0.11, 0.1), 26, 3.5, 3.2, 0.9, false, 60.0, -1.0)
	_burst(root, pos + Vector3.UP * 0.3, Vector3.UP, Color(0.1, 0.08, 0.06), 22, 13.0, 1.6, 0.08, false, 70.0)
	_decal(root, pos + Vector3.UP * 0.2, Vector3.UP, _get_scorch_texture(), Vector3(radius, 1.5, radius))
	AudioManager.play_3d("explosion", pos, 8.0, 500.0, 25.0, 0.1)


static func flash_material() -> StandardMaterial3D:
	if _flash_material == null:
		_flash_material = StandardMaterial3D.new()
		_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flash_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_flash_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_flash_material.albedo_color = Color(1.0, 0.75, 0.35, 0.9)
		_flash_material.albedo_texture = _radial_texture(Color(1, 1, 0.9, 1), Color(1, 0.5, 0.1, 0))
	return _flash_material


# =========================================================================
# Internos
# =========================================================================

static func _root(ctx: Node) -> Node:
	if ctx == null or not ctx.is_inside_tree():
		return null
	return ctx.get_tree().current_scene


static func _burst(root: Node, pos: Vector3, dir: Vector3, color: Color, amount: int, speed: float,
		lifetime: float, size: float, emissive: bool, spread: float, gravity_scale: float = 1.0) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = lifetime
	p.explosiveness = 1.0
	p.randomness = 0.5
	p.direction = dir.normalized() if dir.length() > 0.01 else Vector3.UP
	p.spread = spread
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -9.8 * gravity_scale, 0)
	p.damping_min = 1.0
	p.damping_max = 3.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.mesh = _particle_mesh(color, size, emissive)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(p)
	p.global_position = pos
	p.emitting = true
	_free_after(p, lifetime + 0.3)


static func _particle_mesh(color: Color, size: float, emissive: bool) -> Mesh:
	var key := "%s_%.3f_%s" % [color.to_html(), size, emissive]
	if _particle_meshes.has(key):
		return _particle_meshes[key]
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size, size, size)
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	if emissive:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 5.0
	mesh.material = m
	_particle_meshes[key] = mesh
	return mesh


static func _decal(root: Node, pos: Vector3, normal: Vector3, tex: Texture2D, size: Vector3) -> void:
	var d := Decal.new()
	d.texture_albedo = tex
	d.size = size
	d.upper_fade = 0.2
	d.lower_fade = 0.2
	root.add_child(d)
	d.global_transform = Transform3D(_basis_from_normal(normal), pos)
	_decals.append(d)
	while _decals.size() > MAX_DECALS:
		var old: Variant = _decals.pop_front()
		if is_instance_valid(old):
			(old as Node).queue_free()


## Base cujo eixo Y aponta na direção da normal (Decal projeta ao longo de -Y).
static func _basis_from_normal(n: Vector3) -> Basis:
	var y := n.normalized()
	var ref := Vector3.UP if absf(y.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var x := ref.cross(y).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


static func _free_after(node: Node, seconds: float) -> void:
	var t := Timer.new()
	t.wait_time = seconds
	t.one_shot = true
	t.autostart = true
	t.timeout.connect(node.queue_free)
	node.add_child(t)


static func _radial_texture(inner: Color, outer: Color, mid_offset: float = 0.4, mid: Color = Color(0, 0, 0, -1)) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, inner)
	g.set_color(1, outer)
	if mid.a >= 0.0:
		g.add_point(mid_offset, mid)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t


static func _get_hole_texture() -> Texture2D:
	if _hole_texture == null:
		_hole_texture = _radial_texture(Color(0.01, 0.01, 0.01, 1), Color(0.1, 0.09, 0.08, 0), 0.35, Color(0.04, 0.04, 0.04, 0.85))
	return _hole_texture


static func _get_blood_texture() -> Texture2D:
	if _blood_texture == null:
		_blood_texture = _radial_texture(Color(0.2, 0.0, 0.0, 0.95), Color(0.15, 0.0, 0.0, 0), 0.6, Color(0.22, 0.01, 0.01, 0.8))
	return _blood_texture


static func _get_scorch_texture() -> Texture2D:
	if _scorch_texture == null:
		_scorch_texture = _radial_texture(Color(0.02, 0.02, 0.02, 0.95), Color(0.05, 0.04, 0.03, 0), 0.5, Color(0.04, 0.035, 0.03, 0.7))
	return _scorch_texture
