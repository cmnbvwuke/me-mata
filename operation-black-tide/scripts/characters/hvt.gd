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
## Modelo 3D com esqueleto Mixamo (opcional). Sem ele, usa o boneco procedural.
## As poses (rendido, capturado) e a caminhada são aplicadas nos ossos por código.
@export var model_scene: PackedScene
@export var model_height: float = 1.78
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
var _skeleton: Skeleton3D
var _hands_up := true
var _walk_phase := 0.0
var _arms: Node3D

@onready var agent: NavigationAgent3D = $NavigationAgent3D


func _ready() -> void:
	add_to_group("hvt")
	health = max_health
	if model_scene:
		_build_model()
	else:
		_build_visual()
	_add_tag()
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
	if _skeleton:
		_animate_model(delta, horizontal.length())


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
	if _skeleton:
		_hands_up = hiding
		_animate_model(0.0, 0.0)
		return
	# Escondido: agachado com as mãos para cima. Capturado: de pé, mãos para trás.
	_visual.scale.y = 0.7 if hiding else 1.0
	_arms.rotation.x = deg_to_rad(160.0) if hiding else deg_to_rad(-20.0)


func _build_visual() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var uniform := BodyParts.mat(uniform_color, 0.85)
	var skin := BodyParts.mat(Color(0.45, 0.31, 0.22), 0.7)
	var beret := BodyParts.mat(beret_color, 0.9)
	var gold := BodyParts.mat(Color(0.85, 0.66, 0.22), 0.35, 0.7)
	var boot := BodyParts.mat(Color(0.04, 0.035, 0.03), 0.4)
	var hair := BodyParts.mat(Color(0.12, 0.1, 0.09), 0.9)
	for x in [-0.1, 0.1]:
		var pivot := Node3D.new()
		pivot.position = Vector3(x, 0.92, 0)
		_visual.add_child(pivot)
		BodyParts.leg(pivot, uniform, boot)
		MeshMerger.merge(pivot, false, 1000.0)
	BodyParts.box(_visual, Vector3(0.36, 0.16, 0.24), Vector3(0, 0.96, 0), uniform)
	BodyParts.box(_visual, Vector3(0.38, 0.05, 0.26), Vector3(0, 1.03, 0), boot)                       # cinto
	BodyParts.box(_visual, Vector3(0.07, 0.05, 0.02), Vector3(0, 1.03, -0.135), gold)                   # fivela
	BodyParts.capsule(_visual, 0.19, 0.68, Vector3(0, 1.25, 0), uniform, Vector3(1.22, 1.0, 0.8))       # tronco (barriga)
	for i in 3:
		BodyParts.box(_visual, Vector3(0.05, 0.03, 0.015), Vector3(-0.1 + (i % 2) * 0.05, 1.36 - i * 0.04, -0.15), gold)  # medalhas
	for x in [-0.22, 0.22]:
		BodyParts.box(_visual, Vector3(0.12, 0.025, 0.14), Vector3(x, 1.47, 0), gold)                   # dragonas
	BodyParts.limb(_visual, Vector3(0, 1.47, 0), Vector3(0, 1.57, 0), 0.065, 0.06, skin)
	BodyParts.sphere(_visual, 0.125, Vector3(0, 1.67, 0), skin, Vector3(0.95, 1.05, 1.0))
	BodyParts.box(_visual, Vector3(0.035, 0.045, 0.045), Vector3(0, 1.66, -0.125), skin)               # nariz
	BodyParts.box(_visual, Vector3(0.13, 0.025, 0.03), Vector3(0, 1.615, -0.115), hair)                # bigode
	BodyParts.sphere(_visual, 0.13, Vector3(0, 1.7, 0.01), hair, Vector3(1, 0.7, 1), true)             # cabelo
	BodyParts.sphere(_visual, 0.14, Vector3(0.03, 1.75, 0.0), beret, Vector3(1.05, 0.45, 1.05))        # boina
	BodyParts.box(_visual, Vector3(0.04, 0.04, 0.01), Vector3(-0.06, 1.77, -0.13), gold)               # insígnia
	# Braços num pivô no ombro: mãos para cima (rendido) ou para trás (algemado)
	_arms = Node3D.new()
	_arms.position = Vector3(0, 1.43, 0)
	_visual.add_child(_arms)
	for side in [-1.0, 1.0]:
		BodyParts.arm(_arms, Vector3(side * 0.22, 0, 0), Vector3(side * 0.25, -0.28, 0.02), Vector3(side * 0.22, -0.55, 0.0), uniform, skin)
	MeshMerger.merge(_visual, false, 1000.0)
	MeshMerger.merge(_arms, false, 1000.0)


# --- Modelo com esqueleto (Mixamo) ------------------------------------------

func _build_model() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var model := model_scene.instantiate() as Node3D
	_visual.add_child(model)
	model.rotation.y = PI  # modelos Mixamo olham para +Z; no Godot a frente é -Z
	for ap in model.find_children("*", "AnimationPlayer", true, false):
		(ap as AnimationPlayer).active = false  # só contém a pose T
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	_skeleton = skeletons[0] if not skeletons.is_empty() else null
	# Escala pela altura real da malha
	var top := 0.0
	var bottom := INF
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var aabb := (mi as MeshInstance3D).get_aabb()
		top = maxf(top, aabb.end.y)
		bottom = minf(bottom, aabb.position.y)
	if top > bottom:
		model.scale = Vector3.ONE * (model_height / (top - bottom))
	_arms = Node3D.new()  # compatibilidade com o código do boneco procedural
	_visual.add_child(_arms)


## Monta a pose a partir da pose de repouso: braços (rendido/capturado) e passada.
func _animate_model(delta: float, speed: float) -> void:
	_skeleton.reset_bone_poses()
	if _hands_up:
		_rotate_bone("LeftArm", Vector3.BACK, 68.0)
		_rotate_bone("RightArm", Vector3.BACK, -68.0)
		_rotate_bone("LeftForeArm", Vector3.BACK, 15.0)
		_rotate_bone("RightForeArm", Vector3.BACK, -15.0)
	else:
		_rotate_bone("LeftArm", Vector3.BACK, -74.0)
		_rotate_bone("RightArm", Vector3.BACK, 74.0)
	if speed > 0.2:
		_walk_phase += delta * (4.0 + speed * 1.6)
	else:
		_walk_phase = lerpf(_walk_phase, roundf(_walk_phase / PI) * PI, clampf(delta * 6.0, 0.0, 1.0))
	var amount := clampf(speed / 3.0, 0.0, 1.0)
	var swing := sin(_walk_phase) * 30.0 * amount
	_rotate_bone("LeftUpLeg", Vector3.RIGHT, -swing)
	_rotate_bone("RightUpLeg", Vector3.RIGHT, swing)
	_rotate_bone("LeftLeg", Vector3.RIGHT, maxf(0.0, swing) * 1.3)
	_rotate_bone("RightLeg", Vector3.RIGHT, maxf(0.0, -swing) * 1.3)


## Gira um osso em torno de um eixo do espaço do esqueleto (graus).
func _rotate_bone(bone: String, axis: Vector3, degrees: float) -> void:
	if absf(degrees) < 0.01:
		return
	var i := _skeleton.find_bone("mixamorig_" + bone)
	if i < 0:
		return
	var parent := _skeleton.get_bone_parent(i)
	var parent_global := _skeleton.get_bone_global_pose(parent) if parent >= 0 else Transform3D()
	var rotated := Basis(Quaternion(axis, deg_to_rad(degrees))) * _skeleton.get_bone_global_pose(i).basis
	_skeleton.set_bone_pose_rotation(i, (parent_global.basis.inverse() * rotated).get_rotation_quaternion())


func _add_tag() -> void:
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
