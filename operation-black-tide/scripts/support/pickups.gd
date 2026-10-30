class_name Pickup
extends StaticBody3D
## Objeto interativo genérico (segurar [E]). Implementa o mesmo contrato
## de interação do HVT: can_interact / get_interact_prompt /
## get_interact_hold_time / interact.
## Tipos: AMMO (caixa de munição, reutilizável) e INTEL (inteligência, uso único).

signal collected(pickup: Pickup)

enum Kind { AMMO, INTEL }

@export var kind: Kind = Kind.AMMO
@export var intel_name: String = "laptop"

var _used := false
var _screen: MeshInstance3D
var _light: OmniLight3D


func _ready() -> void:
	collision_layer = Layers.WORLD
	collision_mask = 0
	if kind == Kind.AMMO:
		_build_ammo_crate()
	else:
		_build_laptop()


func can_interact() -> bool:
	return not _used


func get_interact_prompt() -> String:
	if kind == Kind.AMMO:
		return "Segure [E] para reabastecer munição"
	return "Segure [E] para coletar inteligência (%s)" % intel_name


func get_interact_hold_time() -> float:
	return 0.8 if kind == Kind.AMMO else 1.5


func interact(by: Node3D) -> void:
	if kind == Kind.AMMO:
		var p := by as Player
		if p:
			p.weapons.refill_all()
		AudioManager.play_2d("mag_in", -2.0)
	else:
		_used = true
		GameManager.add_stat("intel")
		AudioManager.play_2d("objective", -6.0)
		if _screen:
			_screen.visible = false
		if _light:
			_light.visible = false
	collected.emit(self)


func _build_ammo_crate() -> void:
	_add_shape(Vector3(0.9, 0.45, 0.5), Vector3(0, 0.225, 0))
	_add_mesh(Vector3(0.9, 0.45, 0.5), Vector3(0, 0.225, 0), Color(0.18, 0.2, 0.12))
	_add_mesh(Vector3(0.92, 0.06, 0.52), Vector3(0, 0.42, 0), Color(0.1, 0.1, 0.08))
	var label := Label3D.new()
	label.text = "MUNIÇÃO"
	label.font_size = 40
	label.pixel_size = 0.003
	label.modulate = Color(0.9, 0.8, 0.4)
	label.position = Vector3(0, 0.25, -0.26)
	label.rotation.y = PI
	add_child(label)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.4, 1.0, 0.4)
	_light.light_energy = 0.25
	_light.omni_range = 1.6
	_light.position = Vector3(0, 0.7, 0)
	add_child(_light)


func _build_laptop() -> void:
	_add_shape(Vector3(0.4, 0.3, 0.3), Vector3(0, 0.15, 0))
	_add_mesh(Vector3(0.36, 0.02, 0.26), Vector3(0, 0.01, 0), Color(0.05, 0.05, 0.06))
	_screen = _add_mesh(Vector3(0.36, 0.24, 0.015), Vector3(0, 0.13, 0.12), Color(0.3, 0.6, 1.0), true)
	_screen.rotation.x = -0.25
	_light = OmniLight3D.new()
	_light.light_color = Color(0.4, 0.6, 1.0)
	_light.light_energy = 0.6
	_light.omni_range = 2.5
	_light.position = Vector3(0, 0.3, -0.1)
	add_child(_light)


func _add_shape(size: Vector3, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = pos
	add_child(cs)


func _add_mesh(size: Vector3, pos: Vector3, color: Color, emissive: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	if emissive:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 1.5
	mi.material_override = m
	mi.position = pos
	add_child(mi)
	return mi
