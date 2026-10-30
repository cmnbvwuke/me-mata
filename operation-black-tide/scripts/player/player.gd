class_name Player
extends CharacterBody3D
## Controller FPS do operador.
## Movimento (andar/correr/agachar/pular), mouse look, recuo e tremor de câmera,
## vida com regeneração, passos que geram ruído (stealth), interação com
## "segurar E", lanterna, visão noturna e designação de apoio aéreo.

signal health_changed(current: float, maximum: float)
signal damaged(amount: float, from_position: Vector3)
signal died
signal interaction_changed(prompt: String, progress: float)
signal nvg_toggled(enabled: bool)

@export_group("Movimento")
@export var walk_speed: float = 4.2
@export var sprint_speed: float = 6.8
@export var crouch_speed: float = 2.1
@export var ads_speed_multiplier: float = 0.65
@export var ground_accel: float = 11.0
@export var air_accel: float = 2.5
@export var jump_velocity: float = 4.6

@export_group("Postura")
@export var stand_height: float = 1.8
@export var crouch_height: float = 1.1
@export var stand_eye: float = 1.62
@export var crouch_eye: float = 0.98
@export var crouch_transition_speed: float = 9.0

@export_group("Vida")
@export var max_health: float = 100.0
## Segundos sem levar dano até começar a regenerar.
@export var regen_delay: float = 4.5
@export var regen_rate: float = 28.0

@export_group("Câmera")
@export var base_mouse_sensitivity: float = 0.0022

@export_group("Furtividade (raio de ruído em metros)")
@export var noise_walk: float = 5.0
@export var noise_sprint: float = 14.0
@export var noise_crouch: float = 1.2
@export var noise_land: float = 8.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var weapons: WeaponManager = $Head/Camera3D/WeaponManager
@onready var flashlight: SpotLight3D = $Head/Camera3D/Flashlight
@onready var collision: CollisionShape3D = $CollisionShape3D

var health: float = 100.0
var is_dead: bool = false
var is_crouching: bool = false
var is_sprinting: bool = false
## Em modo cinemático o jogador só olha ao redor (ex.: dentro do helicóptero).
var cinematic_mode: bool = false
var nvg_enabled: bool = false

var _gravity: float = 9.8
var _capsule: CapsuleShape3D
var _pitch := 0.0
var _mouse_delta := Vector2.ZERO
var _time_since_damage := 999.0
var _recoil_target := Vector2.ZERO
var _recoil_current := Vector2.ZERO
var _shake := 0.0
var _bob_time := 0.0
var _bob_amount := 0.0
var _step_accum := 0.0
var _was_on_floor := true
var _fall_speed := 0.0
var _current_eye := 1.62
var _interact_target: Object = null
var _interact_progress := 0.0


func _ready() -> void:
	add_to_group("player")
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	health = max_health
	_capsule = (collision.shape as CapsuleShape3D).duplicate()
	collision.shape = _capsule
	_current_eye = stand_eye
	flashlight.visible = false
	_apply_settings()
	GameManager.settings_changed.connect(_apply_settings)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	health_changed.emit.call_deferred(health, max_health)


func _apply_settings() -> void:
	weapons.base_fov = GameManager.field_of_view


func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		var sens := base_mouse_sensitivity * GameManager.mouse_sensitivity * weapons.get_sensitivity_multiplier()
		rotate_y(-motion.relative.x * sens)
		_pitch = clampf(_pitch - motion.relative.y * sens, deg_to_rad(-88.0), deg_to_rad(88.0))
		head.rotation.x = _pitch
		_mouse_delta += motion.relative
	elif event.is_action_pressed("flashlight"):
		flashlight.visible = not flashlight.visible
		AudioManager.play_2d("fire_mode", -10.0)
	elif event.is_action_pressed("nvg"):
		nvg_enabled = not nvg_enabled
		AudioManager.play_2d("ui_click", -8.0)
		nvg_toggled.emit(nvg_enabled)
	elif event.is_action_pressed("air_support") and not cinematic_mode:
		_request_air_support()


func _physics_process(delta: float) -> void:
	_update_recoil(delta)
	_update_shake(delta)
	_update_health(delta)
	if is_dead:
		return
	if cinematic_mode:
		velocity = Vector3.ZERO
		is_sprinting = false
		head.position = Vector3(0, _current_eye, 0)
		interaction_changed.emit("", 0.0)
		return
	_update_posture(delta)
	_update_movement(delta)
	_update_head_bob(delta)
	_update_interaction(delta)


# =========================================================================
# Movimento
# =========================================================================

func _update_movement(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := (transform.basis * Vector3(input.x, 0.0, input.y))
	wish.y = 0.0
	wish = wish.normalized()

	# Correr só para frente, de pé, sem atirar/mirar
	var wants_sprint := Input.is_action_pressed("sprint") and input.y < -0.3 and is_on_floor() \
		and not Input.is_action_pressed("fire") and not Input.is_action_pressed("aim")
	if wants_sprint and is_crouching:
		_try_stand()
	is_sprinting = wants_sprint and not is_crouching

	var speed := walk_speed
	if is_crouching:
		speed = crouch_speed
	elif is_sprinting:
		speed = sprint_speed
	if weapons.is_aiming():
		speed *= ads_speed_multiplier

	var accel := ground_accel if is_on_floor() else air_accel
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	horizontal = horizontal.lerp(wish * speed, clampf(accel * delta, 0.0, 1.0))
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	if Input.is_action_just_pressed("jump") and is_on_floor():
		if is_crouching:
			_try_stand()
		else:
			velocity.y = jump_velocity

	_fall_speed = velocity.y
	move_and_slide()

	# Aterrissagem: som + ruído + tremor proporcional à queda
	if is_on_floor() and not _was_on_floor and _fall_speed < -3.0:
		AudioManager.play_2d("footstep", -2.0, 0.1)
		StealthSystem.emit_noise(global_position, noise_land, self)
		add_shake(clampf(-_fall_speed / 25.0, 0.05, 0.35))
	_was_on_floor = is_on_floor()
	_update_footsteps(delta, horizontal.length())


func _update_footsteps(delta: float, speed: float) -> void:
	if not is_on_floor() or speed < 0.6:
		return
	_step_accum += speed * delta
	var stride := 2.1 if is_sprinting else (1.0 if is_crouching else 1.6)
	if _step_accum < stride:
		return
	_step_accum = 0.0
	var vol := -8.0
	var radius := noise_walk
	if is_sprinting:
		vol = -3.0
		radius = noise_sprint
	elif is_crouching:
		vol = -22.0
		radius = noise_crouch
	AudioManager.play_2d("footstep", vol, 0.18)
	StealthSystem.emit_noise(global_position, radius, self)


func _update_posture(delta: float) -> void:
	if Input.is_action_just_pressed("crouch"):
		if is_crouching:
			_try_stand()
		else:
			is_crouching = true
	var target_h := crouch_height if is_crouching else stand_height
	_capsule.height = move_toward(_capsule.height, target_h, delta * crouch_transition_speed * 0.6)
	collision.position.y = _capsule.height * 0.5
	var target_eye := crouch_eye if is_crouching else stand_eye
	_current_eye = lerpf(_current_eye, target_eye, clampf(delta * crouch_transition_speed, 0.0, 1.0))


## Só levanta se houver espaço acima (evita atravessar o teto/mesas).
func _try_stand() -> bool:
	var needed := stand_height - _capsule.height
	if needed > 0.01 and test_move(global_transform, Vector3.UP * (needed + 0.05)):
		return false
	is_crouching = false
	return true


func _update_head_bob(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	var target_amount := 0.0
	var freq := 6.5
	if is_on_floor() and speed > 0.5:
		target_amount = 0.022
		if is_sprinting:
			target_amount = 0.045
			freq = 9.0
		elif is_crouching:
			target_amount = 0.012
			freq = 4.5
		if weapons.is_aiming():
			target_amount *= 0.3
		_bob_time += delta * freq
	_bob_amount = lerpf(_bob_amount, target_amount, clampf(delta * 8.0, 0.0, 1.0))
	head.position = Vector3(cos(_bob_time * 0.5) * _bob_amount * 0.6,
		_current_eye + sin(_bob_time) * _bob_amount, 0.0)


# =========================================================================
# Câmera: recuo e tremor
# =========================================================================

func add_recoil(pitch_deg: float, yaw_deg: float) -> void:
	_recoil_target.x += deg_to_rad(pitch_deg)
	_recoil_target.y += deg_to_rad(yaw_deg)


func add_shake(amount: float) -> void:
	_shake = minf(_shake + amount, 1.0)


func consume_mouse_delta() -> Vector2:
	var d := _mouse_delta
	_mouse_delta = Vector2.ZERO
	return d


func _update_recoil(delta: float) -> void:
	_recoil_current = _recoil_current.lerp(_recoil_target, clampf(delta * 18.0, 0.0, 1.0))
	_recoil_target = _recoil_target.lerp(Vector2.ZERO, clampf(delta * 5.0, 0.0, 1.0))
	camera.rotation.x = _recoil_current.x
	camera.rotation.y = _recoil_current.y


func _update_shake(delta: float) -> void:
	_shake = maxf(_shake - delta * 1.6, 0.0)
	var s := _shake * _shake
	camera.h_offset = randf_range(-1.0, 1.0) * 0.05 * s
	camera.v_offset = randf_range(-1.0, 1.0) * 0.05 * s
	if not is_dead:
		camera.rotation.z = randf_range(-1.0, 1.0) * 0.025 * s


# =========================================================================
# Vida
# =========================================================================

func take_damage(info: DamageInfo) -> void:
	if is_dead or cinematic_mode:
		return
	health -= info.amount
	_time_since_damage = 0.0
	damaged.emit(info.amount, info.origin)
	add_shake(clampf(info.amount / 30.0, 0.08, 0.5))
	AudioManager.play_2d("flesh_hit", -4.0, 0.1)
	health_changed.emit(maxf(health, 0.0), max_health)
	if health <= 0.0:
		_die()


func _update_health(delta: float) -> void:
	_time_since_damage += delta
	if is_dead or health >= max_health or _time_since_damage < regen_delay:
		return
	health = minf(max_health, health + regen_rate * delta)
	health_changed.emit(health, max_health)


func _die() -> void:
	is_dead = true
	is_sprinting = false
	flashlight.visible = false
	weapons.visible = false
	AudioManager.play_2d("death_thud", 0.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(head, "position:y", 0.25, 0.8).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(camera, "rotation:z", deg_to_rad(75.0), 0.8)
	died.emit()


# =========================================================================
# Interação, furtividade e apoio
# =========================================================================

func _update_interaction(delta: float) -> void:
	var target := _find_interactable()
	if target != _interact_target:
		_interact_target = target
		_interact_progress = 0.0
	if target == null:
		interaction_changed.emit("", 0.0)
		return
	var hold: float = target.get_interact_hold_time()
	if Input.is_action_pressed("interact"):
		_interact_progress += delta / maxf(hold, 0.01)
		if _interact_progress >= 1.0:
			target.interact(self)
			_interact_progress = 0.0
			_interact_target = null
	else:
		_interact_progress = 0.0
	interaction_changed.emit(String(target.get_interact_prompt()), _interact_progress)


func _find_interactable() -> Object:
	var from := camera.global_position
	var to := from - camera.global_basis.z * 2.6
	var query := PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD | Layers.HVT, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	var c: Object = hit["collider"]
	if c != null and c.has_method("can_interact") and c.can_interact():
		return c
	return null


func _request_air_support() -> void:
	var support := get_tree().get_first_node_in_group("air_support")
	if support == null:
		return
	var from := camera.global_position
	var to := from - camera.global_basis.z * 400.0
	var query := PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD | Layers.ENEMY, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		support.call("report", "OVERLORD: Sem ponto de referência. Marque o solo.")
		return
	support.call("request_strike", hit["position"], self)


## Fator de visibilidade usado pela detecção inimiga (1 = normal).
func get_visibility() -> float:
	var v := 1.0
	if is_crouching:
		v *= 0.45
	if is_sprinting:
		v *= 1.3
	if flashlight.visible:
		v *= 2.2
	return v


func get_eye_position() -> Vector3:
	return head.global_position


## Ponto do torso (alvo dos inimigos).
func get_aim_point() -> Vector3:
	return global_position + Vector3.UP * (_current_eye - 0.4)


func set_view_yaw(yaw: float, pitch: float = 0.0) -> void:
	rotation.y = yaw
	_pitch = pitch
	head.rotation.x = pitch
