class_name Helicopter
extends Node3D
## Helicóptero de transporte/ataque (MH-60 estilizado), totalmente procedural.
## Sem colisão: é usado em sequências (infiltração, órbita e extração).

signal flight_finished

enum Mode { IDLE, PATH, ORBIT }

@export var rotor_speed: float = 24.0

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


func _ready() -> void:
	_build()
	_audio = AudioManager.make_loop_player("heli_loop", self, 6.0, 18.0, 400.0)
	_audio.play()
	_prev_position = global_position


func _process(delta: float) -> void:
	_rotor.rotate_y(rotor_speed * delta)
	_tail_rotor.rotate_x(rotor_speed * 1.6 * delta)
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
	var body := _mat(Color(0.13, 0.14, 0.13), 0.3, 0.6)
	var dark := _mat(Color(0.04, 0.04, 0.045), 0.5, 0.5)
	var glass := _mat(Color(0.05, 0.08, 0.1), 0.6, 0.1)
	_box(Vector3(2.3, 2.0, 6.0), Vector3(0, 0, 0), body)            # fuselagem
	_box(Vector3(2.1, 1.4, 1.6), Vector3(0, 0.15, -3.6), glass)       # cabine
	_box(Vector3(0.8, 0.7, 6.5), Vector3(0, 0.45, 6.0), body)         # cauda
	_box(Vector3(0.15, 1.8, 1.2), Vector3(0, 1.3, 9.0), body)         # deriva
	_box(Vector3(2.6, 0.08, 0.6), Vector3(0, 0.5, 8.6), body)         # estabilizador
	_box(Vector3(1.2, 0.5, 2.2), Vector3(0, 1.2, -0.3), body)         # motores
	_box(Vector3(0.1, 0.1, 4.0), Vector3(1.0, -1.3, 0), dark)          # esquis
	_box(Vector3(0.1, 0.1, 4.0), Vector3(-1.0, -1.3, 0), dark)
	_box(Vector3(0.6, 0.15, 0.15), Vector3(1.15, 0.6, 0.6), dark)      # metralhadora de porta
	_rotor = Node3D.new()
	_rotor.position = Vector3(0, 1.55, -0.3)
	add_child(_rotor)
	for i in 4:
		var blade := _box(Vector3(0.35, 0.05, 7.8), Vector3(0, 0, 3.9), dark)
		remove_child(blade)
		var arm := Node3D.new()
		arm.rotation.y = i * PI * 0.5
		_rotor.add_child(arm)
		arm.add_child(blade)
	_tail_rotor = Node3D.new()
	_tail_rotor.position = Vector3(0.25, 1.2, 9.0)
	add_child(_tail_rotor)
	for i in 2:
		var tb := _box(Vector3(0.05, 1.6, 0.18), Vector3.ZERO, dark)
		remove_child(tb)
		tb.rotation.x = i * PI * 0.5
		_tail_rotor.add_child(tb)
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
	seat = Marker3D.new()
	seat.position = Vector3(1.45, -1.0, 0.6)
	add_child(seat)


func _mat(c: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metallic
	m.roughness = roughness
	return m


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi
