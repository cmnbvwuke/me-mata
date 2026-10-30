class_name ObjectiveInteractable
extends StaticBody3D
## Alvo interativo de objetivo ("segure E"): carga explosiva, terminal,
## documentos, ponto de observação, leme etc. Só aceita interação enquanto
## o objetivo dono estiver ativo. Usa o mesmo contrato de interação do HVT.

signal used(target: ObjectiveInteractable)

## CHARGE = painel/transformador com carga; SATCHEL = bolsa de explosivo pequena (barcos, bancadas)
enum Visual { CHARGE, TERMINAL, INTEL, SPOTTER, HELM, SATCHEL }

@export var visual: Visual = Visual.TERMINAL
@export var prompt: String = "Segure [E] para interagir"
@export var hold_time: float = 1.5
@export var sound: String = "objective"

var active: bool = false
var is_used: bool = false
var _light: OmniLight3D
var _blink_tween: Tween


func _ready() -> void:
	collision_layer = Layers.WORLD
	collision_mask = 0
	_build()


func can_interact() -> bool:
	return active and not is_used


func get_interact_prompt() -> String:
	return prompt


func get_interact_hold_time() -> float:
	return hold_time


func interact(_by: Node3D) -> void:
	mark_used()
	AudioManager.play_2d(sound, -4.0)
	used.emit(self)


## Marca como concluído sem disparar o sinal (ex.: ao carregar um checkpoint).
func mark_used() -> void:
	is_used = true
	if visual == Visual.CHARGE or visual == Visual.SATCHEL:
		_arm_charge()
	elif _light:
		_light.light_color = Color(0.3, 1.0, 0.4)


func set_active(value: bool) -> void:
	active = value
	if _light and not is_used:
		_light.visible = value


# --- Visual ------------------------------------------------------------------

func _build() -> void:
	match visual:
		Visual.CHARGE:
			# Ponto de fixação (painel/transformador) + bolsa de explosivo
			_part(Vector3(0.9, 1.6, 0.6), Vector3(0, 0.8, 0), Color(0.28, 0.3, 0.3), true)
			_part(Vector3(0.3, 0.2, 0.08), Vector3(0, 1.0, -0.34), Color(0.18, 0.2, 0.1))
		Visual.TERMINAL:
			_part(Vector3(0.8, 1.1, 0.5), Vector3(0, 0.55, 0), Color(0.12, 0.13, 0.14), true)
			_part(Vector3(0.6, 0.35, 0.03), Vector3(0, 1.3, -0.1), Color(0.2, 0.6, 1.0), false, true)
		Visual.INTEL:
			_part(Vector3(1.2, 0.8, 0.7), Vector3(0, 0.4, 0), Color(0.22, 0.15, 0.09), true)
			_part(Vector3(0.35, 0.04, 0.26), Vector3(0, 0.82, 0), Color(0.85, 0.82, 0.7))
			_part(Vector3(0.12, 0.02, 0.2), Vector3(0.3, 0.81, 0.05), Color(0.05, 0.05, 0.06))
		Visual.SPOTTER:
			# Tripé com binóculo/telêmetro laser
			_part(Vector3(0.6, 1.2, 0.6), Vector3(0, 0.6, 0), Color(0.1, 0.1, 0.1), true, false, true)
			_part(Vector3(0.12, 0.12, 0.35), Vector3(0, 1.3, 0), Color(0.12, 0.14, 0.1))
		Visual.SATCHEL:
			# Bolsa de explosivo plástico com detonador e antena
			_part(Vector3(0.34, 0.2, 0.22), Vector3(0, 0.1, 0), Color(0.24, 0.26, 0.16), true)
			_part(Vector3(0.12, 0.06, 0.1), Vector3(0.06, 0.23, 0), Color(0.08, 0.08, 0.08))
			_part(Vector3(0.01, 0.18, 0.01), Vector3(0.1, 0.33, 0.02), Color(0.05, 0.05, 0.05))
			_part(Vector3(0.36, 0.03, 0.05), Vector3(0, 0.12, -0.08), Color(0.12, 0.1, 0.08))
		Visual.HELM:
			_part(Vector3(1.4, 1.0, 0.6), Vector3(0, 0.5, 0), Color(0.15, 0.16, 0.18), true)
			_part(Vector3(0.5, 0.5, 0.05), Vector3(0, 1.25, -0.1), Color(0.35, 0.25, 0.12))
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.75, 0.25)
	_light.light_energy = 0.8
	_light.omni_range = 2.5
	_light.position = Vector3(0, 0.5, 0) if visual == Visual.SATCHEL else Vector3(0, 1.6, -0.3)
	_light.visible = false
	add_child(_light)


func _arm_charge() -> void:
	_light.visible = true
	_light.light_color = Color(1.0, 0.1, 0.05)
	_light.omni_range = 3.0
	_blink_tween = create_tween().set_loops()
	_blink_tween.tween_property(_light, "light_energy", 0.1, 0.25)
	_blink_tween.tween_property(_light, "light_energy", 2.0, 0.25)


func _part(size: Vector3, pos: Vector3, color: Color, collide: bool = false, emissive: bool = false,
		thin_collider: bool = false) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size if not thin_collider else Vector3(0.08, size.y, 0.08)
	mi.mesh = mesh
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
	if collide:
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		cs.position = pos
		add_child(cs)
