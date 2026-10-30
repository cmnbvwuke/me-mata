class_name Searchlight
extends Node3D
## Holofote de torre: varre um arco e, se o jogador ficar dentro do facho
## (com linha de visão), o guarda dono do holofote entra em combate.
## Em combate, o facho persegue o jogador. Matar o guarda desliga o holofote.

@export var sweep_angle_deg: float = 45.0
@export var sweep_speed: float = 0.35
@export var pitch_deg: float = -15.0
@export var light_range: float = 60.0
@export var cone_deg: float = 9.0

var owner_enemy: Enemy
var base_yaw: float = 0.0
var light: SpotLight3D
var _t := 0.0
var _detect := 0.0
var _disabled := false


func _ready() -> void:
	_t = randf() * TAU
	light = SpotLight3D.new()
	light.light_color = Color(0.95, 0.97, 1.0)
	light.light_energy = 9.0
	light.light_volumetric_fog_energy = 2.5
	light.spot_range = light_range
	light.spot_angle = cone_deg
	light.spot_attenuation = 0.5
	light.shadow_enabled = not OS.has_feature("web")
	add_child(light)
	var housing := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.28
	cyl.bottom_radius = 0.22
	cyl.height = 0.55
	housing.mesh = cyl
	housing.rotation.x = PI * 0.5
	housing.position = Vector3(0, 0, 0.3)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.08, 0.08, 0.08)
	m.metallic = 0.6
	housing.material_override = m
	add_child(housing)
	var lens := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.26
	disc.bottom_radius = 0.26
	disc.height = 0.02
	lens.mesh = disc
	lens.rotation.x = PI * 0.5
	lens.position = Vector3(0, 0, 0.02)
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color(1, 1, 0.95)
	lm.emission_enabled = true
	lm.emission = Color(1, 1, 0.95)
	lm.emission_energy_multiplier = 8.0
	lens.material_override = lm
	add_child(lens)


func _physics_process(delta: float) -> void:
	if _disabled:
		return
	if owner_enemy == null or not is_instance_valid(owner_enemy) or owner_enemy.is_dead:
		_disabled = true
		var tw := create_tween()
		tw.tween_property(light, "light_energy", 0.0, 0.4)
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	_t += delta * sweep_speed
	var target_yaw := base_yaw + sin(_t) * deg_to_rad(sweep_angle_deg)
	var target_pitch := deg_to_rad(pitch_deg)
	if owner_enemy.state == Enemy.State.COMBAT and player != null and not player.is_dead:
		# Persegue o jogador
		var v := player.global_position - global_position
		target_yaw = atan2(-v.x, -v.z)
		target_pitch = atan2(v.y, Vector2(v.x, v.z).length())
	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(delta * 2.5, 0.0, 1.0))
	rotation.x = lerp_angle(rotation.x, target_pitch, clampf(delta * 2.5, 0.0, 1.0))
	if player == null or player.is_dead or player.cinematic_mode:
		return
	if _is_player_lit(player):
		_detect += delta * 2.0
		if _detect >= 0.6 and owner_enemy.state != Enemy.State.COMBAT:
			owner_enemy.notify_contact(player.global_position)
	else:
		_detect = maxf(_detect - delta, 0.0)


func _is_player_lit(player: Player) -> bool:
	var to := player.get_aim_point() - light.global_position
	if to.length() > light_range:
		return false
	if rad_to_deg((-light.global_basis.z).angle_to(to.normalized())) > cone_deg * 1.1:
		return false
	var q := PhysicsRayQueryParameters3D.create(light.global_position, player.get_aim_point(), Layers.SIGHT_MASK)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return not hit.is_empty() and hit["collider"] is Player
