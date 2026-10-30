class_name HVTCharacter
extends CharacterBody3D
## General Rodrigo Salcedo — Alvo de Alto Valor (HVT).
## Escondido na sala segura; o jogador segura [E] para rendê-lo e algemá-lo.
## Depois disso segue o jogador via navmesh até a extração.
## Se morrer (inclusive por fogo amigo), a missão falha.
## Também é reutilizado como NPC escoltável (ex.: o desertor Coronel Ibarra),
## configurando nome, texto da interação e cores pelas propriedades exportadas.

signal captured
signal killed

enum State { HIDING, FOLLOWING, BOARDING }

@export var max_health: float = 140.0
@export var follow_distance: float = 2.6
@export var tag_text: String = "HVT"
@export var interact_prompt: String = "Segure [E] para render e algemar o General Salcedo"
@export var uniform_color: Color = Color(0.27, 0.3, 0.2)
@export var beret_color: Color = Color(0.5, 0.05, 0.05)
## Som ao interagir ("zip_tie" = algemas; "radio_beep" = resgate amigável)
@export var interact_sound: String = "zip_tie"

var state: State = State.HIDING
var health: float = 140.0
var is_dead: bool = false
var follow_target: Node3D = null
var _board_position := Vector3.ZERO
var _last_target := Vector3(INF, INF, INF)
var _stuck_time := 0.0
var _stuck_sample := 0.0
var _stuck_check_pos := Vector3.ZERO
var _visual: Node3D
var _arms: Node3D

@onready var agent: NavigationAgent3D = $NavigationAgent3D


func _ready() -> void:
	add_to_group("hvt")
	health = max_health
	_build_visual()
	_set_pose_hiding(true)


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	var dir := Vector3.ZERO
	var speed := 0.0
	var target := Vector3.ZERO
	var has_target := false
	match state:
		State.FOLLOWING:
			if follow_target != null and is_instance_valid(follow_target):
				target = follow_target.global_position
				has_target = global_position.distance_to(target) > follow_distance
		State.BOARDING:
			target = _board_position
			has_target = global_position.distance_to(target) > 0.6
	if has_target and NavigationServer3D.map_get_iteration_id(agent.get_navigation_map()) > 0:
		if target.distance_to(_last_target) > 0.5:
			_last_target = target
			agent.target_position = target
		if not agent.is_navigation_finished():
			dir = agent.get_next_path_position() - global_position
			dir.y = 0.0
			if dir.length() > 0.05:
				dir = dir.normalized()
				var dist := global_position.distance_to(target)
				speed = clampf(dist * 1.3, 2.0, 6.0)
	_update_stuck(delta, has_target, target)
	var horizontal := Vector3(velocity.x, 0, velocity.z).lerp(dir * speed, clampf(delta * 8.0, 0.0, 1.0))
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = -0.5 if is_on_floor() else velocity.y - 9.8 * delta
	move_and_slide()
	if dir.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), clampf(delta * 6.0, 0.0, 1.0))


## Recuperação de travamento: se ele quer andar mas não sai do lugar,
## recalcula a rota; se continuar preso, reaparece atrás do jogador
## (fora da linha de visão, sobre o navmesh).
func _update_stuck(delta: float, wants_to_move: bool, target: Vector3) -> void:
	if not wants_to_move:
		_stuck_time = 0.0
		_stuck_sample = 0.0
		_stuck_check_pos = global_position
		return
	_stuck_sample += delta
	if _stuck_sample < 1.0:
		return
	# Amostra a cada 1 s: quanto ele andou nesse intervalo?
	_stuck_sample = 0.0
	var moved := global_position.distance_to(_stuck_check_pos)
	_stuck_check_pos = global_position
	if moved > 0.4:
		_stuck_time = 0.0
		return
	_stuck_time += 1.0
	# Preso: força novo caminho
	_last_target = Vector3(INF, INF, INF)
	agent.target_position = target
	if _stuck_time >= 3.0 and global_position.distance_to(target) > 5.0 and follow_target != null:
		var behind := follow_target.global_position + follow_target.global_basis.z * 2.0
		var map := agent.get_navigation_map()
		global_position = NavigationServer3D.map_get_closest_point(map, behind) + Vector3.UP * 0.1
		velocity = Vector3.ZERO
		_stuck_time = 0.0


# --- Interação (contrato usado pelo Player) ----------------------------------

func can_interact() -> bool:
	return state == State.HIDING and not is_dead


func get_interact_prompt() -> String:
	return interact_prompt


func get_interact_hold_time() -> float:
	return 1.8


func interact(by: Node3D) -> void:
	set_captured(by)
	AudioManager.play_2d(interact_sound, -2.0)
	captured.emit()


## Também usado ao carregar o checkpoint pós-captura.
func set_captured(by: Node3D) -> void:
	state = State.FOLLOWING
	follow_target = by
	_set_pose_hiding(false)


func board(position_on_heli: Vector3) -> void:
	state = State.BOARDING
	_board_position = position_on_heli


func get_distance_to(pos: Vector3) -> float:
	return Vector2(global_position.x - pos.x, global_position.z - pos.z).length()


# --- Dano ---------------------------------------------------------------------

func is_headshot_point(point: Vector3) -> bool:
	return point.y - global_position.y > 1.4


func take_damage(info: DamageInfo) -> void:
	if is_dead:
		return
	health -= info.amount
	if not info.is_explosion:
		FX.blood(self, info.hit_position, (info.hit_position - info.origin).normalized())
	if health <= 0.0:
		is_dead = true
		collision_layer = 0
		var tw := create_tween()
		tw.tween_property(_visual, "rotation:x", deg_to_rad(-86.0), 0.6)
		killed.emit()


# --- Visual ---------------------------------------------------------------------

func _set_pose_hiding(hiding: bool) -> void:
	# Escondido: agachado com as mãos para cima. Capturado: de pé, mãos para trás.
	_visual.scale.y = 0.7 if hiding else 1.0
	_arms.rotation.x = deg_to_rad(160.0) if hiding else deg_to_rad(-20.0)


func _build_visual() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var uniform := _mat(uniform_color)
	var skin := _mat(Color(0.4, 0.28, 0.2))
	var beret := _mat(beret_color)
	var gold := _mat(Color(0.8, 0.62, 0.2))
	_box(_visual, Vector3(0.36, 0.88, 0.22), Vector3(0, 0.44, 0), uniform)
	_box(_visual, Vector3(0.48, 0.64, 0.3), Vector3(0, 1.18, 0), uniform)
	_box(_visual, Vector3(0.18, 0.05, 0.02), Vector3(-0.12, 1.32, -0.16), gold)  # medalhas
	_box(_visual, Vector3(0.12, 0.12, 0.02), Vector3(0.24, 1.47, 0), gold)       # dragonas
	_box(_visual, Vector3(0.12, 0.12, 0.02), Vector3(-0.24, 1.47, 0), gold)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.13
	sphere.height = 0.27
	head.mesh = sphere
	head.material_override = skin
	head.position = Vector3(0, 1.64, 0)
	_visual.add_child(head)
	_box(_visual, Vector3(0.28, 0.06, 0.3), Vector3(0.03, 1.75, 0), beret)
	_box(_visual, Vector3(0.14, 0.03, 0.03), Vector3(0, 1.58, -0.12), _mat(Color(0.08, 0.06, 0.05)))  # bigode
	_arms = Node3D.new()
	_arms.position = Vector3(0, 1.42, 0)
	_visual.add_child(_arms)
	_box(_arms, Vector3(0.12, 0.6, 0.12), Vector3(0.3, -0.28, 0), uniform)
	_box(_arms, Vector3(0.12, 0.6, 0.12), Vector3(-0.3, -0.28, 0), uniform)
	var tag := Label3D.new()
	tag.text = tag_text
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = Color(1.0, 0.75, 0.25)
	tag.outline_size = 10
	tag.font_size = 48
	tag.pixel_size = 0.004
	tag.position = Vector3(0, 2.15, 0)
	add_child(tag)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
