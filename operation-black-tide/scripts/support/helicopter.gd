class_name Helicopter
extends Node3D
## Helicóptero de transporte/ataque (MH-60 estilizado), totalmente procedural.
## Fuselagem e cauda têm colisão (AnimatableBody3D, acompanha o voo); rotores não.

signal flight_finished

enum Mode { IDLE, PATH, ORBIT }

@export var rotor_speed: float = 24.0

const BLACKHAWK := preload("res://assets/vehicles/blackhawk.glb")

var seat: Marker3D        ## Onde o jogador "senta" (porta lateral direita)
var mode: Mode = Mode.IDLE
var _rotor: Node3D
var _tail_rotor: Node3D
var _audio: AudioStreamPlayer3D
var _flight_tween: Tween
var _orbit_center := Vector3.ZERO
var _orbit_radius := 70.0
var _orbit_height := 45.0
var _orbit_angle := 0.0
var _orbit_speed := 0.08
var _prev_position := Vector3.ZERO
var _strobe: OmniLight3D
var _strobe_time := 0.0


func _ready() -> void:
	_build()
	_audio = AudioManager.make_loop_player("heli_loop", self, 6.0, 18.0, 400.0)
	_audio.play()
	_prev_position = global_position


func _process(delta: float) -> void:
	_rotor.rotate_y(rotor_speed * delta)
	_tail_rotor.rotate_x(rotor_speed * 1.6 * delta)
	_strobe_time += delta
	_strobe.light_energy = 4.0 if fmod(_strobe_time, 1.2) < 0.08 else 0.0
	if mode == Mode.ORBIT:
		_orbit_angle += _orbit_speed * delta
		var p := _orbit_center + Vector3(cos(_orbit_angle) * _orbit_radius, _orbit_height,
			sin(_orbit_angle) * _orbit_radius)
		global_position = global_position.lerp(p, clampf(delta * 0.8, 0.0, 1.0))
	# Orientação e inclinação a partir do deslocamento
	var vel := (global_position - _prev_position) / maxf(delta, 0.0001)
	_prev_position = global_position
	var flat := Vector3(vel.x, 0, vel.z)
	if flat.length() > 0.8:
		rotation.y = lerp_angle(rotation.y, atan2(-flat.x, -flat.z), clampf(delta * 1.5, 0.0, 1.0))
	rotation.x = lerpf(rotation.x, -clampf(flat.length() / 40.0, 0.0, 0.25), clampf(delta * 2.0, 0.0, 1.0))


## Voa por uma lista de pontos; cada trecho dura `durations[i]` segundos.
func fly_path(points: Array[Vector3], durations: Array[float]) -> void:
	stop_flight()
	mode = Mode.PATH
	_flight_tween = create_tween()
	for i in points.size():
		var trans := Tween.TRANS_SINE
		var step := _flight_tween.tween_property(self, "global_position", points[i], durations[i]).set_trans(trans)
		if i == points.size() - 1:
			step.set_ease(Tween.EASE_OUT)
		elif i == 0:
			step.set_ease(Tween.EASE_IN)
	_flight_tween.tween_callback(func() -> void:
		mode = Mode.IDLE
		flight_finished.emit())


func stop_flight() -> void:
	if _flight_tween and _flight_tween.is_valid():
		_flight_tween.kill()
	mode = Mode.IDLE


func orbit(center: Vector3, radius: float, height: float, speed: float = 0.08) -> void:
	stop_flight()
	_orbit_center = center
	_orbit_radius = radius
	_orbit_height = height
	_orbit_speed = speed
	var off := global_position - center
	_orbit_angle = atan2(off.z, off.x)
	mode = Mode.ORBIT


func _build() -> void:
	# UH-60 Black Hawk (Blend Swap #25582, CC0), convertido no Blender: nariz em
	# -Z, rotores como nós separados com o pivô no cubo (giram em _process)
	var model := BLACKHAWK.instantiate() as Node3D
	add_child(model)
	_rotor = model.find_child("MainRotor", true, false) as Node3D
	_tail_rotor = model.find_child("TailRotor", true, false) as Node3D
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).lod_bias = 0.5
	_build_collision()
	# Luz vermelha de cabine (operações noturnas) e luzes de navegação
	var cabin := OmniLight3D.new()
	cabin.light_color = Color(1.0, 0.1, 0.05)
	cabin.light_energy = 1.2
	cabin.omni_range = 3.5
	cabin.position = Vector3(0.5, 0.3, 0.5)
	add_child(cabin)
	var nav_l := OmniLight3D.new()
	nav_l.light_color = Color(0.2, 1.0, 0.3)
	nav_l.light_energy = 0.6
	nav_l.omni_range = 2.0
	nav_l.position = Vector3(1.3, 0.5, -1.5)
	add_child(nav_l)
	# Holofote de pouso apontado para baixo e luz anticolisão piscante:
	# deixam o helicóptero visível de longe à noite
	var landing := SpotLight3D.new()
	landing.light_color = Color(0.95, 0.97, 1.0)
	landing.light_energy = 6.0
	landing.spot_range = 70.0
	landing.spot_angle = 22.0
	landing.light_volumetric_fog_energy = 2.0
	landing.shadow_enabled = GraphicsQuality.positional_shadows_allowed(true)
	landing.position = Vector3(0, -0.9, -3.8)
	landing.rotation.x = -deg_to_rad(70.0)
	add_child(landing)
	_strobe = OmniLight3D.new()
	_strobe.light_color = Color(1.0, 0.15, 0.1)
	_strobe.light_energy = 0.0
	_strobe.omni_range = 9.0
	_strobe.position = Vector3(0, 2.0, 4.0)
	add_child(_strobe)
	seat = Marker3D.new()
	seat.position = Vector3(1.7, -1.0, 0.6)
	add_child(seat)


func _build_collision() -> void:
	var body := AnimatableBody3D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	body.sync_to_physics = false
	for part in [[Vector3(2.4, 2.7, 8.6), Vector3(0, 0.15, -0.6)], [Vector3(1.0, 1.2, 6.6), Vector3(0, 0.75, 6.4)],
			[Vector3(2.6, 0.4, 3.0), Vector3(0, -1.15, -1.0)]]:
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = part[0]
		cs.shape = shape
		cs.position = part[1]
		body.add_child(cs)
	add_child(body)
