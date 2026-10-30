class_name WeaponManager
extends Node3D
## Gerencia o arsenal do jogador: troca de armas, disparo (hitscan),
## dispersão dinâmica, ADS (FOV + posição da arma) e animações procedurais
## da viewmodel (balanço, sway, coice, recarga, sprint, equipar).
## Deve ser filho da Camera3D do jogador.

signal weapon_changed(weapon: Weapon)
signal ammo_changed(in_mag: int, reserve: int)
signal fire_mode_changed(is_auto: bool)
signal hit_confirmed(killed: bool, headshot: bool)

@export var loadout: Array[String] = [
	"res://resources/weapons/m4a1.tres",
	"res://resources/weapons/p226_sd.tres",
]

var weapons: Array[Weapon] = []
var current: Weapon
var current_index: int = -1
var base_fov: float = 75.0
## 0 = mira do quadril, 1 = mirando (ADS)
var aim_blend: float = 0.0
## Dispersão atual em graus (o HUD usa para abrir/fechar a mira).
var current_spread: float = 0.0

var player: Player
var camera: Camera3D
var _bloom := 0.0
var _sprint_blend := 0.0
var _kick := 0.0
var _sway := Vector2.ZERO
var _bob_time := 0.0


func _ready() -> void:
	camera = get_parent() as Camera3D
	player = owner as Player
	for path in loadout:
		var data := load(path) as WeaponData
		if data == null:
			push_error("Arma inválida: %s" % path)
			continue
		var w := Weapon.new()
		w.name = data.weapon_name.validate_node_name()
		add_child(w)
		w.setup(data)
		w.holster()
		w.ammo_changed.connect(func(m: int, r: int) -> void: ammo_changed.emit(m, r))
		w.fire_mode_changed.connect(func(a: bool) -> void: fire_mode_changed.emit(a))
		weapons.append(w)
	switch_to(0)


func _unhandled_input(event: InputEvent) -> void:
	if not _can_act() or current == null:
		return
	if event.is_action_pressed("weapon_1"):
		switch_to(0)
	elif event.is_action_pressed("weapon_2"):
		switch_to(1)
	elif event.is_action_pressed("switch_weapon") or event.is_action_pressed("next_weapon"):
		switch_to((current_index + 1) % weapons.size())
	elif event.is_action_pressed("prev_weapon"):
		switch_to((current_index - 1 + weapons.size()) % weapons.size())
	elif event.is_action_pressed("reload"):
		current.start_reload()
	elif event.is_action_pressed("fire_mode"):
		current.toggle_fire_mode()


func switch_to(index: int) -> void:
	if index == current_index or index < 0 or index >= weapons.size():
		return
	if current:
		current.holster()
	current_index = index
	current = weapons[index]
	current.equip()
	aim_blend = 0.0
	weapon_changed.emit(current)
	ammo_changed.emit(current.ammo_in_mag, current.ammo_reserve)


func refill_all() -> void:
	for w in weapons:
		w.refill()


func is_aiming() -> bool:
	return aim_blend > 0.5


func get_sensitivity_multiplier() -> float:
	return lerpf(1.0, 0.55, aim_blend)


func _can_act() -> bool:
	return player != null and not player.is_dead and not player.cinematic_mode and not player.is_vaulting


# =========================================================================
# Loop principal
# =========================================================================

func _process(delta: float) -> void:
	if current == null:
		return
	visible = not player.cinematic_mode and not player.is_dead
	var can_act := _can_act()
	var d := current.data
	var wants_aim := can_act and Input.is_action_pressed("aim") and not player.is_sprinting \
		and current.state != Weapon.State.RELOADING
	aim_blend = move_toward(aim_blend, 1.0 if wants_aim else 0.0, delta / d.ads_time)
	_sprint_blend = move_toward(_sprint_blend, 1.0 if player.is_sprinting else 0.0, delta * 5.0)
	camera.fov = lerpf(base_fov, d.ads_fov, smoothstep(0.0, 1.0, aim_blend))

	if can_act and not player.is_sprinting and Input.is_action_pressed("fire"):
		var just := Input.is_action_just_pressed("fire")
		if current.try_fire(just):
			_fire_bullet()
		elif current.ammo_in_mag == 0 and current.can_reload():
			current.start_reload()  # recarga automática ao puxar o gatilho vazio

	_update_spread(delta)
	_update_viewmodel(delta)


func _update_spread(delta: float) -> void:
	var d := current.data
	var base := lerpf(d.hip_spread, d.ads_spread, aim_blend)
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	var move_ratio := clampf(speed / player.walk_speed, 0.0, 1.5)
	base += d.move_spread * move_ratio * lerpf(1.0, 0.35, aim_blend)
	if player.is_crouching:
		base *= 0.7
	if not player.is_on_floor():
		base += 4.0
	_bloom = move_toward(_bloom, 0.0, delta * d.spread_recovery)
	current_spread = base + _bloom


# =========================================================================
# Balística
# =========================================================================

func _fire_bullet() -> void:
	var d := current.data
	var from := camera.global_position
	var dir := _spread_direction(-camera.global_basis.z, current_spread)
	var to := from + dir * d.max_range
	var query := PhysicsRayQueryParameters3D.create(from, to, Layers.PLAYER_SHOT_MASK, [player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	GameManager.add_stat("shots_fired")

	var end_point := to
	if not hit.is_empty():
		end_point = hit["position"]
		var collider: Object = hit["collider"]
		if collider != null and collider.has_method("take_damage"):
			var info := DamageInfo.new(d.damage, player, from, hit["position"], hit["normal"])
			if collider.has_method("is_headshot_point"):
				info.is_headshot = collider.is_headshot_point(hit["position"])
			if info.is_headshot:
				info.amount *= d.headshot_multiplier
			var was_alive := not bool(collider.get("is_dead"))
			collider.take_damage(info)
			GameManager.add_stat("shots_hit")
			var killed := was_alive and bool(collider.get("is_dead"))
			if killed and info.is_headshot:
				GameManager.add_stat("headshots")
			hit_confirmed.emit(killed, info.is_headshot)
		else:
			FX.impact(self, hit["position"], hit["normal"])

	# Traçante ocasional (armas não suprimidas)
	if not d.suppressed and randf() < 0.3:
		FX.tracer(self, current.muzzle.global_position, end_point, Color(1.0, 0.75, 0.4))
	StealthSystem.emit_noise(player.global_position, d.noise_radius, player)

	# Recuo: câmera + coice da arma + abertura da dispersão
	var factor := lerpf(1.0, 0.65, aim_blend) * (0.8 if player.is_crouching else 1.0)
	player.add_recoil(d.recoil_vertical * factor, randf_range(-1.0, 1.0) * d.recoil_horizontal * factor)
	player.add_shake(0.025 if d.suppressed else 0.05)
	_kick = 1.0
	_bloom += d.spread_per_shot


func _spread_direction(forward: Vector3, spread_deg: float) -> Vector3:
	var angle := deg_to_rad(spread_deg) * sqrt(randf())  # distribuição uniforme no disco
	var roll := randf() * TAU
	var offset := (camera.global_basis.x * cos(roll) + camera.global_basis.y * sin(roll)) * tan(angle)
	return (forward + offset).normalized()


# =========================================================================
# Animação procedural da viewmodel
# =========================================================================

func _update_viewmodel(delta: float) -> void:
	var d := current.data
	var e := smoothstep(0.0, 1.0, aim_blend)
	var hip_factor := 1.0 - e * 0.85
	var pos := d.hip_position.lerp(d.ads_position, e)
	var rot := Vector3.ZERO

	# Pose de corrida
	pos += Vector3(-0.06, -0.06, 0.04) * _sprint_blend
	rot += Vector3(-0.35, 0.75, 0.25) * _sprint_blend

	# Sway (atraso da arma em relação ao mouse)
	var md := player.consume_mouse_delta()
	var sway_target := Vector2(clampf(-md.x * 0.0015, -0.08, 0.08), clampf(-md.y * 0.0015, -0.08, 0.08))
	_sway = _sway.lerp(sway_target * (1.0 - e * 0.7), clampf(delta * 10.0, 0.0, 1.0))
	rot.y += _sway.x
	rot.x += _sway.y
	pos.x += _sway.x * 0.15

	# Balanço ao andar + respiração
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	var bob_amt := clampf(speed / 5.0, 0.0, 1.3) * hip_factor * (1.0 if player.is_on_floor() else 0.2)
	_bob_time += delta * (6.0 + speed * 0.9)
	pos.x += sin(_bob_time) * 0.011 * bob_amt
	pos.y += absf(cos(_bob_time)) * 0.012 * bob_amt
	var t := Time.get_ticks_msec() / 1000.0
	pos.y += sin(t * 1.7) * 0.0025 * (1.0 - e * 0.8)

	# Coice
	_kick = move_toward(_kick, 0.0, delta * 11.0)
	pos.z += 0.05 * _kick * (1.0 - e * 0.5)
	rot.x += 0.07 * _kick

	# Recarga: arma inclina e desce
	var rp := current.get_reload_progress()
	if rp >= 0.0:
		var r := sin(rp * PI)
		pos.y -= 0.09 * r
		rot.x -= 0.35 * r
		rot.z += 0.7 * r

	# Equipar: sobe de baixo
	var ep := smoothstep(0.0, 1.0, current.get_equip_progress())
	pos.y -= (1.0 - ep) * 0.3
	rot.x -= (1.0 - ep) * 0.9

	current.position = pos
	current.rotation = rot
