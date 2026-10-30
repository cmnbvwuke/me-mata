class_name Enemy
extends CharacterBody3D
## IA inimiga com máquina de estados:
##   PATROL  — segue waypoints ou vigia um posto; a suspeita sobe ao ver o jogador.
##   ALERT   — investiga a origem de um ruído/avistamento, olha ao redor.
##   COMBAT  — usa cobertura (agacha/expõe), flanqueia, avança, atira em rajadas
##             e avisa aliados pelo rádio (alarme global após alguns segundos).
##   DEAD
## Percepção: visão (cone + alcance + linha de visão, bloqueada por vegetação),
## audição (StealthSystem.noise_emitted) e descoberta de corpos.

signal died(enemy: Enemy)
signal state_changed(enemy: Enemy, new_state: int)

enum State { PATROL, ALERT, COMBAT, DEAD }

## Segundos que um inimigo em combate leva para conseguir reportar pelo rádio.
## Matá-lo antes disso evita o alarme global.
const RADIO_DELAY := 3.0
const ALLY_ALERT_RADIUS := 28.0

@export var profile: EnemyProfile
## Lanterna pode ser desligada por instância (ex.: guardas das torres).
@export var use_flashlight: bool = true

var stage: int = 0
var patrol_points: Array[Vector3] = []
var guard_yaw: float = 0.0

var state: State = State.PATROL
var health: float = 100.0
var is_dead: bool = false
var awareness: float = 0.0
var last_known_position: Vector3 = Vector3.ZERO
var investigate_position: Vector3 = Vector3.ZERO
var is_crouched: bool = false
## Para corpos: já foi descoberto por outro guarda?
var discovered: bool = false

var _player: Player
var _rng := RandomNumberGenerator.new()
var _home_position := Vector3.ZERO
var _patrol_index := 0
var _wait_timer := 0.0
var _phase := 0.0
var _perception_timer := 0.0
var _decision_timer := 0.0
var _can_see_player := false
var _time_unseen := 0.0
var _reaction_timer := 0.0
var _radio_timer := -1.0
var _aim_quality := 0.0
var _burst_left := 0
var _burst_pause := 0.0
var _shot_cooldown := 0.0
var _cover: CoverPoint = null
var _cover_phase_timer := 0.0
var _peeking := true
var _time_in_cover := 0.0
var _flanking := false
var _moving := false
var _run := false
var _look_yaw := 0.0
var _search_timer := 0.0
var _search_base_yaw := 0.0
var _hit_flinch := 0.0
var _posture := 1.0
var _walk_cycle := 0.0

# Partes visuais
var _visual: Node3D
var _eyes: Marker3D
var _muzzle: Marker3D
var _leg_l: Node3D
var _leg_r: Node3D
var _flashlight: SpotLight3D

@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var body_shape: CollisionShape3D = $CollisionShape3D
@onready var indicator: Label3D = $Indicator


func _ready() -> void:
	add_to_group("enemies")
	_rng.randomize()
	_phase = _rng.randf() * TAU
	if profile == null:
		profile = load("res://resources/enemies/guard.tres") as EnemyProfile
	health = profile.max_health
	body_shape.shape = body_shape.shape.duplicate()
	_build_visual()
	_home_position = global_position
	_look_yaw = rotation.y
	if patrol_points.is_empty():
		guard_yaw = rotation.y
	_perception_timer = _rng.randf() * 0.2
	StealthSystem.noise_emitted.connect(_on_noise)
	StealthSystem.alarm_raised.connect(_on_alarm)


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	_hit_flinch = maxf(_hit_flinch - delta, 0.0)
	_perception_timer -= delta
	if _perception_timer <= 0.0:
		_perception_timer = 0.1
		_perceive(0.1)
	match state:
		State.PATROL:
			_tick_patrol(delta)
		State.ALERT:
			_tick_alert(delta)
		State.COMBAT:
			_tick_combat(delta)
	_apply_movement(delta)
	_update_posture(delta)
	_update_indicator()


# =========================================================================
# Percepção
# =========================================================================

func _perceive(dt: float) -> void:
	_can_see_player = _check_sight()
	if state == State.COMBAT:
		awareness = 1.0
		if _can_see_player:
			last_known_position = _player.global_position
			_time_unseen = 0.0
		elif not (_cover != null and is_crouched):
			# Escondido atrás da cobertura ele ainda "sabe" onde o jogador está
			_time_unseen += dt
		StealthSystem.report_awareness(self, 1.0)
		return

	if _can_see_player:
		var dist := global_position.distance_to(_player.global_position)
		var dist_factor := clampf(1.0 - dist / profile.vision_range, 0.0, 1.0)
		var gain := profile.detection_speed * _player.get_visibility() * (0.15 + dist_factor * dist_factor * 1.6)
		if state == State.ALERT:
			gain *= 1.8
		if StealthSystem.alarm_active:
			gain *= 2.0
		awareness += gain * dt
		last_known_position = _player.global_position
		if dist < 2.5:
			awareness = 1.0
		if awareness >= 1.0:
			_enter_combat()
		elif awareness >= 0.45:
			_enter_alert(_player.global_position)
	else:
		var decay := 0.06 if state == State.ALERT else 0.15
		awareness = maxf(0.0, awareness - dt * decay)
		_check_corpses()
	StealthSystem.report_awareness(self, minf(awareness, 0.99))


func _check_sight() -> bool:
	if _player == null or _player.is_dead or _player.cinematic_mode:
		return false
	var eye := _eyes.global_position
	var target := _player.get_eye_position()
	var to_player := target - eye
	var dist := to_player.length()
	var max_range := profile.vision_range
	if _player.flashlight.visible:
		max_range *= 1.6
	if state == State.COMBAT:
		max_range *= 2.5
	if dist > max_range:
		return false
	if state != State.COMBAT and dist > 2.0:
		var forward := -global_basis.z
		if rad_to_deg(forward.angle_to(to_player.normalized())) > profile.vision_fov * 0.5:
			return false
	return _has_los(eye, target) or _has_los(eye, _player.get_aim_point())


func _has_los(from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, Layers.SIGHT_MASK, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return not hit.is_empty() and hit["collider"] is Player


func _world_clear(from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _check_corpses() -> void:
	for node in get_tree().get_nodes_in_group("corpses"):
		var corpse := node as Enemy
		if corpse == null or corpse.discovered:
			continue
		var to := corpse.global_position + Vector3.UP * 0.3 - _eyes.global_position
		if to.length() > profile.vision_range * 0.7:
			continue
		if rad_to_deg((-global_basis.z).angle_to(to.normalized())) > profile.vision_fov * 0.5:
			continue
		if not _world_clear(_eyes.global_position, corpse.global_position + Vector3.UP * 0.3):
			continue
		corpse.discovered = true
		awareness = maxf(awareness, 0.8)
		_enter_alert(corpse.global_position)
		_radio_timer = RADIO_DELAY  # vai reportar "homem abatido"
		return


func _on_noise(pos: Vector3, radius: float, source: Node) -> void:
	if is_dead or source == self or source is Enemy:
		return
	var dist := global_position.distance_to(pos)
	var effective := radius * profile.hearing_multiplier
	if dist > effective:
		return
	# Paredes abafam o som
	if dist > effective * 0.5 and not _world_clear(_eyes.global_position, pos + Vector3.UP):
		effective *= 0.6
		if dist > effective:
			return
	match state:
		State.PATROL, State.ALERT:
			if radius >= 25.0:
				# Disparo não suprimido: entra em combate na direção do som
				last_known_position = pos
				_enter_combat()
			else:
				awareness = maxf(awareness, 0.5)
				_enter_alert(pos)
		State.COMBAT:
			if not _can_see_player:
				last_known_position = pos


func _on_alarm(pos: Vector3) -> void:
	if is_dead or state == State.COMBAT:
		return
	awareness = maxf(awareness, 0.6)
	if global_position.distance_to(pos) < 45.0:
		_enter_alert(pos)
	else:
		_set_state(State.ALERT)
		investigate_position = global_position


## Chamado por aliados (rádio) ou pelo holofote.
func notify_contact(pos: Vector3) -> void:
	if is_dead:
		return
	last_known_position = pos
	_enter_combat()


# =========================================================================
# Transições
# =========================================================================

func _set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(self, new_state)


func _enter_alert(pos: Vector3) -> void:
	if state == State.COMBAT or is_dead:
		return
	investigate_position = pos
	_search_timer = 0.0
	_wait_timer = 0.0
	_set_state(State.ALERT)
	_move_to(pos, false)


func _enter_combat() -> void:
	if state == State.COMBAT or is_dead:
		return
	_set_state(State.COMBAT)
	awareness = 1.0
	_reaction_timer = profile.reaction_time
	_decision_timer = 0.0
	_time_unseen = 0.0
	_aim_quality = 0.0
	if not StealthSystem.alarm_active and _radio_timer < 0.0:
		_radio_timer = RADIO_DELAY
	elif StealthSystem.alarm_active:
		_alert_allies()


func _alert_allies() -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e == self or e.is_dead or e.state == State.COMBAT:
			continue
		if e.global_position.distance_to(global_position) <= ALLY_ALERT_RADIUS:
			e.notify_contact(last_known_position)


# =========================================================================
# Comportamentos
# =========================================================================

func _tick_patrol(delta: float) -> void:
	_run = false
	_tick_radio(delta)
	var t := Time.get_ticks_msec() / 1000.0
	if patrol_points.is_empty():
		# Posto fixo: volta para casa se saiu, depois varre o olhar
		if not _moving and _flat_distance(global_position, _home_position) > 1.0:
			_move_to(_home_position, false)
		elif not _moving:
			_look_yaw = guard_yaw + sin(t * 0.35 + _phase) * 0.7
		return
	if _wait_timer > 0.0:
		_wait_timer -= delta
		_look_yaw = _search_base_yaw + sin(t * 0.6 + _phase) * 0.6
		if _wait_timer <= 0.0:
			_patrol_index = (_patrol_index + 1) % patrol_points.size()
			_move_to(patrol_points[_patrol_index], false)
		return
	if not _moving:
		if _flat_distance(global_position, patrol_points[_patrol_index]) < 1.2:
			_wait_timer = _rng.randf_range(2.0, 4.5)
			_search_base_yaw = rotation.y
		else:
			_move_to(patrol_points[_patrol_index], false)


func _tick_alert(delta: float) -> void:
	_run = false
	_tick_radio(delta)
	if _moving:
		return
	if _search_timer == 0.0:
		_search_base_yaw = rotation.y
	_search_timer += delta
	_look_yaw = _search_base_yaw + sin(_search_timer * 1.1) * 1.3
	if _search_timer > 6.0:
		if StealthSystem.alarm_active:
			# Alarme ativo: continua vasculhando a área
			_search_timer = 0.0
			var p := investigate_position + Vector3(_rng.randf_range(-8, 8), 0, _rng.randf_range(-8, 8))
			_move_to(p, false)
		elif awareness <= 0.05:
			_set_state(State.PATROL)
			_wait_timer = 0.0


func _tick_radio(delta: float) -> void:
	if _radio_timer < 0.0:
		return
	_radio_timer -= delta
	if _radio_timer <= 0.0:
		_radio_timer = -1.0
		StealthSystem.raise_alarm(global_position)
		_alert_allies()


func _tick_combat(delta: float) -> void:
	if _player == null or _player.is_dead:
		_moving = false
		is_crouched = false
		return
	_tick_radio(delta)
	_reaction_timer -= delta
	_tick_shooting(delta)
	_decision_timer -= delta
	if _decision_timer <= 0.0:
		_decision_timer = _rng.randf_range(1.2, 2.4)
		_decide_tactics()
	_tick_cover_cycle(delta)


func _decide_tactics() -> void:
	var ppos := _player.global_position
	var dist := global_position.distance_to(ppos)

	# Perdeu o contato há muito tempo: volta a procurar
	if _time_unseen > 12.0:
		_release_cover()
		_set_state(State.ALERT)
		awareness = 0.7
		investigate_position = last_known_position
		_search_timer = 0.0
		_move_to(last_known_position, false)
		return
	if _flanking and _moving:
		return
	_flanking = false

	# Sem visão por alguns segundos: pressiona a última posição conhecida
	if _time_unseen > 4.0:
		_release_cover()
		_move_to(last_known_position, true)
		return

	if profile.uses_cover:
		if _cover != null and _moving:
			return  # ainda correndo para a cobertura escolhida
		if _cover != null and _cover_is_safe(_cover):
			if _time_in_cover > 4.0 and _rng.randf() < profile.flank_chance and _try_flank():
				return
			if _rng.randf() < profile.aggression * 0.3 and dist > 9.0:
				_advance_toward(ppos, dist)
			return
		var c := _find_cover()
		if c != null:
			_take_cover(c)
			return
	# Sem cobertura (ou perfil agressivo): avança e faz strafe
	if dist > 11.0 or not _can_see_player or _rng.randf() < profile.aggression * 0.4:
		_advance_toward(ppos, dist)
	else:
		var side := global_basis.x * (1.0 if _rng.randf() < 0.5 else -1.0)
		_move_to(global_position + side * _rng.randf_range(2.0, 4.0), false)


func _advance_toward(ppos: Vector3, dist: float) -> void:
	_release_cover()
	var dir := (ppos - global_position).normalized()
	_move_to(global_position + dir * maxf(dist - 6.0, 1.5), true)


func _tick_cover_cycle(delta: float) -> void:
	if _cover == null or _moving:
		is_crouched = false
		return
	_time_in_cover += delta
	_cover_phase_timer -= delta
	if _cover_phase_timer <= 0.0:
		_peeking = not _peeking
		_cover_phase_timer = _rng.randf_range(1.6, 3.2) if _peeking else _rng.randf_range(1.0, 2.2)
		if _peeking:
			_reaction_timer = maxf(_reaction_timer, profile.reaction_time * 0.5)
	is_crouched = not _peeking


# --- Cobertura -------------------------------------------------------------

func _find_cover() -> CoverPoint:
	var best: CoverPoint = null
	var best_score := -INF
	var ppos := _player.global_position
	for node in get_tree().get_nodes_in_group("cover_point"):
		var c := node as CoverPoint
		if c == null or not c.is_free_for(self):
			continue
		var d_me := global_position.distance_to(c.global_position)
		if d_me > 16.0:
			continue
		var d_pl := ppos.distance_to(c.global_position)
		if d_pl < 4.0 or d_pl > 35.0:
			continue
		if not _cover_is_safe(c):
			continue
		var score := -d_me * 0.6 + _rng.randf() * 1.5
		if _world_clear(c.global_position + Vector3.UP * 1.55, _player.get_eye_position()):
			score += 6.0  # dá para expor e atirar daqui
		if score > best_score:
			best_score = score
			best = c
	return best


## Seguro = o jogador NÃO vê a cabeça agachada neste ponto.
func _cover_is_safe(c: CoverPoint) -> bool:
	return not _world_clear(_player.get_eye_position(), c.global_position + Vector3.UP * 0.9)


func _take_cover(c: CoverPoint) -> void:
	_release_cover()
	_cover = c
	c.occupant = self
	_time_in_cover = 0.0
	_peeking = false
	_cover_phase_timer = _rng.randf_range(0.8, 1.6)
	_move_to(c.global_position, true)


func _release_cover() -> void:
	if _cover != null and _cover.occupant == self:
		_cover.occupant = null
	_cover = null
	is_crouched = false


## Flanqueamento: busca um ponto lateral ao jogador com linha de tiro.
func _try_flank() -> bool:
	var ppos := _player.global_position
	var to_me := (global_position - ppos)
	to_me.y = 0.0
	if to_me.length() < 0.1:
		return false
	var perp := to_me.normalized().cross(Vector3.UP)
	if _rng.randf() < 0.5:
		perp = -perp
	var map := agent.get_navigation_map()
	for i in 3:
		var candidate := ppos + perp * _rng.randf_range(7.0, 12.0) + to_me.normalized() * _rng.randf_range(2.0, 6.0)
		candidate = NavigationServer3D.map_get_closest_point(map, candidate)
		if _world_clear(candidate + Vector3.UP * 1.5, _player.get_eye_position()):
			_release_cover()
			_flanking = true
			_move_to(candidate, true)
			return true
	return false


# --- Tiro ------------------------------------------------------------------

func _tick_shooting(delta: float) -> void:
	_shot_cooldown -= delta
	if not _can_see_player or is_crouched:
		_aim_quality = maxf(0.0, _aim_quality - delta * 0.5)
		return
	_aim_quality = minf(1.0, _aim_quality + delta * 0.45)  # mira melhora com o tempo
	if _reaction_timer > 0.0:
		return
	# Precisa estar virado para o jogador
	var to_player := _player.global_position - global_position
	to_player.y = 0.0
	if (-global_basis.z).angle_to(to_player.normalized()) > deg_to_rad(25.0):
		return
	if _burst_left <= 0:
		_burst_pause -= delta
		if _burst_pause > 0.0:
			return
		_burst_left = _rng.randi_range(profile.burst_min, profile.burst_max)
	if _shot_cooldown > 0.0:
		return
	_shot_cooldown = 60.0 / profile.fire_rate
	_burst_left -= 1
	if _burst_left <= 0:
		_burst_pause = _rng.randf_range(0.5, 1.3)
	_fire_shot()


func _fire_shot() -> void:
	var from := _muzzle.global_position
	var target := _player.get_aim_point() + Vector3(0, _rng.randf_range(-0.35, 0.45), 0)
	var dir := (target - from).normalized()
	var spread := lerpf(9.0, 1.0, profile.accuracy) * lerpf(1.8, 0.8, _aim_quality)
	spread += Vector2(_player.velocity.x, _player.velocity.z).length() * 0.6
	if _moving:
		spread *= 1.5
	if _hit_flinch > 0.0:
		spread *= 2.0
	dir = _apply_spread(dir, spread)
	var to := from + dir * 150.0
	var q := PhysicsRayQueryParameters3D.create(from, to, Layers.ENEMY_SHOT_MASK, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var end_point := to
	if not hit.is_empty():
		end_point = hit["position"]
		if hit["collider"] is Player:
			(hit["collider"] as Player).take_damage(DamageInfo.new(profile.damage, self, global_position, end_point))
		else:
			FX.impact(self, end_point, hit["normal"])
	# Bala passando perto do jogador ("zip")
	var closest := Geometry3D.get_closest_point_to_segment(_player.get_eye_position(), from, end_point)
	if closest.distance_to(_player.get_eye_position()) < 1.8 and not (not hit.is_empty() and hit["collider"] is Player):
		AudioManager.play_2d("whiz", -10.0, 0.25)
	FX.tracer(self, from, end_point, Color(1.0, 0.55, 0.25))
	FX.muzzle_flash(self, from, 0.8)
	AudioManager.play_3d(profile.weapon_sound, from, 0.0, 180.0, 12.0)


func _apply_spread(dir: Vector3, spread_deg: float) -> Vector3:
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	var right := dir.cross(up).normalized()
	var real_up := right.cross(dir).normalized()
	var angle := deg_to_rad(spread_deg) * sqrt(_rng.randf())
	var roll := _rng.randf() * TAU
	return (dir + (right * cos(roll) + real_up * sin(roll)) * tan(angle)).normalized()


# =========================================================================
# Movimento
# =========================================================================

func _move_to(pos: Vector3, run: bool) -> void:
	_run = run
	_moving = true
	agent.target_position = pos


func _nav_ready() -> bool:
	return NavigationServer3D.map_get_iteration_id(agent.get_navigation_map()) > 0


func _apply_movement(delta: float) -> void:
	var dir := Vector3.ZERO
	var speed := 0.0
	if _moving and _nav_ready():
		if agent.is_navigation_finished():
			_moving = false
		else:
			var next := agent.get_next_path_position()
			dir = next - global_position
			dir.y = 0.0
			if dir.length() > 0.05:
				dir = dir.normalized()
				speed = profile.run_speed if _run else profile.walk_speed
				if state == State.ALERT:
					speed *= 1.25
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).lerp(dir * speed, clampf(delta * 8.0, 0.0, 1.0))
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= 9.8 * delta
	move_and_slide()

	# Orientação: encara o jogador em combate; senão, a direção do movimento
	var face_yaw := _look_yaw
	if state == State.COMBAT and _player != null:
		var look_at_pos := _player.global_position if _can_see_player else last_known_position
		if _can_see_player or not _moving:
			var v := look_at_pos - global_position
			face_yaw = atan2(-v.x, -v.z)
		elif dir.length() > 0.1:
			face_yaw = atan2(-dir.x, -dir.z)
		_look_yaw = face_yaw
	elif dir.length() > 0.1:
		face_yaw = atan2(-dir.x, -dir.z)
		_look_yaw = face_yaw
	rotation.y = lerp_angle(rotation.y, face_yaw, clampf(delta * 7.0, 0.0, 1.0))
	_animate_walk(delta, horizontal.length())


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# =========================================================================
# Dano e morte
# =========================================================================

func is_headshot_point(point: Vector3) -> bool:
	return point.y - global_position.y > 1.5 * _posture


func take_damage(info: DamageInfo) -> void:
	if is_dead:
		return
	var amount := info.amount
	if not info.is_headshot and not info.is_explosion:
		amount *= 1.0 - profile.armor
	health -= amount
	if not info.is_explosion:
		FX.blood(self, info.hit_position, (info.hit_position - info.origin).normalized())
	_hit_flinch = 0.4
	if health <= 0.0:
		_die(info)
		return
	_visual.rotation.x = 0.15  # tranco do impacto
	if info.source is Player:
		last_known_position = (info.source as Player).global_position
		_enter_combat()
		_reaction_timer = minf(_reaction_timer, 0.3)


func _die(info: DamageInfo) -> void:
	is_dead = true
	_set_state(State.DEAD)
	_release_cover()
	_moving = false
	collision_layer = 0
	collision_mask = Layers.WORLD
	indicator.visible = false
	if _flashlight:
		_flashlight.visible = false
	StealthSystem.clear_awareness(self)
	if info.source is Player:
		GameManager.add_stat("kills")
	remove_from_group("enemies")
	add_to_group("corpses")
	AudioManager.play_3d("death_thud", global_position, -4.0, 30.0, 4.0)
	var fall := -1.0 if _rng.randf() < 0.5 else 1.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_visual, "rotation:x", fall * deg_to_rad(86.0), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_visual, "scale:y", 1.0, 0.2)
	tw.chain().tween_callback(func() -> void: FX.blood_pool(self, global_position))
	died.emit(self)
	set_physics_process(false)


# =========================================================================
# Visual procedural
# =========================================================================

func _update_posture(delta: float) -> void:
	_posture = move_toward(_posture, 0.62 if is_crouched else 1.0, delta * 3.0)
	_visual.scale.y = _posture
	var shape := body_shape.shape as CapsuleShape3D
	shape.height = 1.8 * _posture
	body_shape.position.y = shape.height * 0.5
	_visual.rotation.x = lerpf(_visual.rotation.x, 0.0, clampf(delta * 6.0, 0.0, 1.0))


func _animate_walk(delta: float, speed: float) -> void:
	if speed > 0.2:
		_walk_cycle += delta * speed * 3.2
	else:
		_walk_cycle = lerpf(_walk_cycle, roundf(_walk_cycle / PI) * PI, clampf(delta * 5.0, 0.0, 1.0))
	var swing := sin(_walk_cycle) * clampf(speed / 3.0, 0.0, 1.0) * 0.6
	_leg_l.rotation.x = swing
	_leg_r.rotation.x = -swing


func _update_indicator() -> void:
	match state:
		State.COMBAT:
			indicator.visible = true
			indicator.text = "!"
			indicator.modulate = Color(1.0, 0.15, 0.1)
		State.ALERT:
			indicator.visible = true
			indicator.text = "?"
			indicator.modulate = Color(1.0, 0.75, 0.15)
		_:
			indicator.visible = awareness > 0.12
			indicator.text = "?"
			indicator.modulate = Color(1.0, 1.0, 1.0, clampf(awareness * 2.0, 0.2, 1.0))


func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	var cloth := BodyParts.mat(profile.body_color, 0.95)
	var vest := BodyParts.mat(profile.vest_color, 0.9)
	var skin := BodyParts.mat(Color(0.42, 0.29, 0.21), 0.7)
	var boot := BodyParts.mat(Color(0.05, 0.045, 0.04), 0.6)
	var glove := BodyParts.mat(Color(0.07, 0.07, 0.06), 0.8)
	var webbing := BodyParts.mat(profile.vest_color.darkened(0.35), 0.9)
	var elite := profile.has_helmet
	var militia := not profile.uses_cover

	# Pernas (pivôs no quadril para a animação de caminhada)
	_leg_l = _pivot(Vector3(-0.1, 0.92, 0))
	_leg_r = _pivot(Vector3(0.1, 0.92, 0))
	BodyParts.leg(_leg_l, cloth, boot)
	BodyParts.leg(_leg_r, cloth, boot)
	# Quadril, cinto e tronco
	BodyParts.box(_visual, Vector3(0.34, 0.14, 0.22), Vector3(0, 0.96, 0), cloth)
	BodyParts.box(_visual, Vector3(0.36, 0.05, 0.24), Vector3(0, 1.02, 0), webbing)
	BodyParts.capsule(_visual, 0.17, 0.66, Vector3(0, 1.24, 0), cloth, Vector3(1.25, 1.0, 0.78))
	# Colete com porta-carregadores
	if not militia:
		BodyParts.box(_visual, Vector3(0.42, 0.38, 0.3), Vector3(0, 1.25, 0), vest)
		for x in [-0.11, 0.0, 0.11]:
			BodyParts.box(_visual, Vector3(0.09, 0.12, 0.06), Vector3(x, 1.14, -0.17), webbing)
		BodyParts.box(_visual, Vector3(0.12, 0.08, 0.05), Vector3(0.12, 1.35, -0.17), webbing)  # rádio
	else:
		BodyParts.box(_visual, Vector3(0.06, 0.5, 0.33), Vector3(-0.05, 1.25, 0), webbing, Vector3(0, 0, 0.5))  # bandoleira
	# Pescoço e cabeça
	BodyParts.limb(_visual, Vector3(0, 1.47, 0), Vector3(0, 1.57, 0), 0.06, 0.055, skin)
	var head_mat := skin if not elite else BodyParts.mat(Color(0.06, 0.06, 0.06), 0.9)  # balaclava na elite
	BodyParts.sphere(_visual, 0.12, Vector3(0, 1.66, 0), head_mat, Vector3(0.92, 1.05, 1.0))
	BodyParts.box(_visual, Vector3(0.03, 0.04, 0.04), Vector3(0, 1.65, -0.12), head_mat)                 # nariz
	if elite:
		BodyParts.sphere(_visual, 0.145, Vector3(0, 1.69, 0.005), vest, Vector3(1.0, 1.0, 1.08), true)    # capacete
		BodyParts.box(_visual, Vector3(0.09, 0.05, 0.06), Vector3(0, 1.79, -0.13), boot)                  # suporte NVG
		BodyParts.box(_visual, Vector3(0.11, 0.045, 0.08), Vector3(0, 1.75, -0.18), boot)                 # NVG
	elif militia:
		BodyParts.box(_visual, Vector3(0.2, 0.09, 0.14), Vector3(0, 1.6, -0.06), BodyParts.mat(Color(0.45, 0.08, 0.06)))  # bandana no rosto
		BodyParts.sphere(_visual, 0.125, Vector3(0, 1.7, 0.0), BodyParts.mat(Color(0.1, 0.09, 0.08)), Vector3(1, 0.7, 1), true)  # cabelo
	else:
		BodyParts.sphere(_visual, 0.128, Vector3(0, 1.71, 0.0), cloth, Vector3(1, 0.75, 1.05), true)      # boné
		BodyParts.box(_visual, Vector3(0.2, 0.02, 0.1), Vector3(0, 1.72, -0.15), cloth)                    # aba
	# Fuzil segurado com as duas mãos
	var gun := Vector3(0.08, 1.31, -0.3)
	BodyParts.rifle(_visual, gun)
	BodyParts.arm(_visual, Vector3(0.21, 1.43, 0.0), Vector3(0.27, 1.2, -0.06), gun + Vector3(0.01, -0.08, 0.07), cloth, glove)
	BodyParts.arm(_visual, Vector3(-0.21, 1.43, 0.0), Vector3(-0.13, 1.21, -0.3), gun + Vector3(-0.025, -0.05, -0.36), cloth, glove)

	_eyes = Marker3D.new()
	_eyes.position = Vector3(0, 1.66, -0.11)
	_visual.add_child(_eyes)
	_muzzle = Marker3D.new()
	_muzzle.position = Vector3(0.08, 1.32, -0.99)
	_visual.add_child(_muzzle)

	if profile.has_flashlight and use_flashlight:
		_flashlight = SpotLight3D.new()
		_flashlight.light_color = Color(1.0, 0.93, 0.8)
		_flashlight.light_energy = 2.5
		_flashlight.light_volumetric_fog_energy = 1.5
		_flashlight.spot_range = 20.0
		_flashlight.spot_angle = 20.0
		_flashlight.shadow_enabled = not OS.has_feature("web")
		_flashlight.position = Vector3(0.11, 1.31, -0.62)
		_visual.add_child(_flashlight)


func _mat(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	m.metallic = metallic
	return m


func _pivot(pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	_visual.add_child(n)
	return n


func _part(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot_y: float = 0.0) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position = pos
	mi.rotation.y = rot_y
	parent.add_child(mi)
