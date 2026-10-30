class_name MissionLevel
extends Node3D
## Base das missões da campanha (exceto Absolute Resolve, que tem script próprio).
##
## Uma missão concreta só precisa sobrescrever:
##   build_world()          -> geometria com o LevelBuilder (`builder`) e os helpers abaixo
##   define_objectives()    -> lista de objetivos (dados, ver "Tipos de objetivo")
##   spawn_enemies()        -> inimigos iniciais via spawn_enemy(..., stage)
##   environment_preset()   -> "night", "dusk", "dawn" ou "overcast"
##   intro_lines(), success_text()
##
## Tipos de objetivo (Dictionary, campo "type"):
##   reach    {pos, radius}                           chegar a um ponto
##   kill     {stage, marker?}                        eliminar todos os inimigos da etapa `stage`
##   interact {targets: [{pos, yaw?, visual, prompt, hold?}], label, detonate?: "", "each", "all"}
##   defend   {pos, radius, duration, defend_waves: [{time, spawns: [[tipo, pos], ...]}]}
##            (o tempo só corre com o jogador dentro do raio)
##   rescue   {npc: HVTCharacter}                     segurar E no NPC; ele passa a seguir
##   escort   {npc, pos, radius}                      levar o NPC (e você) até o ponto
## Campos comuns: title, hint, checkpoint: [pos, yaw_graus], radio: [[quem, texto, s]],
##   air: bool (apoio aéreo liberado), on_start: Callable,
##   waves: [{spawns: [[tipo, pos], ...]}] (reforços que nascem ao iniciar o objetivo)
## Cada objetivo concluído grava checkpoint. Inimigos com stage < checkpoint não nascem.

const ENEMY_SCENE := preload("res://scenes/enemies/enemy.tscn")
const NPC_SCENE := preload("res://scenes/characters/hvt.tscn")
const PROFILES := {
	"guard": preload("res://resources/enemies/guard.tres"),
	"elite": preload("res://resources/enemies/elite.tres"),
	"militia": preload("res://resources/enemies/militia.tres"),
}

@onready var player: Player = $Player
@onready var hud: Node = $HUD
@onready var pause_menu: Node = $PauseMenu
@onready var objectives: ObjectiveManager = $ObjectiveManager
@onready var air_support: AirSupport = $AirSupport
@onready var nav_region: NavigationRegion3D = $NavigationRegion3D
@onready var geometry: Node3D = $NavigationRegion3D/Geometry
@onready var dynamic_root: Node3D = $Dynamic
@onready var enemies_root: Node3D = $Enemies
@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var sun: DirectionalLight3D = $Moon

var builder: LevelBuilder
var start_stage: int = 0
var rng := RandomNumberGenerator.new()
var objective_defs: Array[Dictionary] = []

var _mission_over := false
var _time := 0.0
var _alarm_lights: Array[OmniLight3D] = []
var _flicker_lights: Array[OmniLight3D] = []
var _siren: AudioStreamPlayer3D
var _targets: Dictionary = {}        # índice do objetivo -> Array[ObjectiveInteractable]
var _defend_time := 0.0
var _defend_spawned: Dictionary = {}
var _npcs: Array[HVTCharacter] = []
var _bobbing: Array[Node3D] = []
var _spinning: Array[Node3D] = []


# =========================================================================
# Pontos de extensão (sobrescreva nas missões)
# =========================================================================

func build_world() -> void:
	pass


func define_objectives() -> Array[Dictionary]:
	return []


func spawn_enemies() -> void:
	pass


func environment_preset() -> String:
	return "night"


## Limites do bake do navmesh (AABB) — deve cobrir toda a área jogável.
func nav_bounds() -> AABB:
	return AABB(Vector3(-70, -2, -70), Vector3(140, 14, 140))


func intro_lines() -> Array:
	return []


func success_text() -> String:
	return "Missão cumprida."


func on_objective_started(_index: int, _obj: Dictionary) -> void:
	pass


# =========================================================================
# Ciclo de vida
# =========================================================================

func _ready() -> void:
	rng.seed = hash(GameManager.current_mission_id)
	start_stage = GameManager.checkpoint_index
	builder = LevelBuilder.new(geometry, dynamic_root)
	_setup_environment(environment_preset())
	build_world()
	nav_region.navigation_mesh = nav_region.navigation_mesh.duplicate()
	nav_region.navigation_mesh.filter_baking_aabb = nav_bounds()
	nav_region.bake_navigation_mesh(false)
	MeshMerger.merge(geometry)  # milhares de peças estáticas -> poucas malhas
	objective_defs = define_objectives()
	start_stage = clampi(start_stage, 0, maxi(objective_defs.size() - 1, 0))
	spawn_enemies()
	_setup_objectives()
	GameManager.stats["intel_total"] = get_tree().get_nodes_in_group("intel_pickup").size()
	if OS.has_feature("web"):
		for node in find_children("*", "Light3D", true, false):
			if node is OmniLight3D or node is SpotLight3D:
				(node as Light3D).shadow_enabled = false
	hud.bind_player(player)
	hud.bind_objectives(objectives)
	hud.bind_air_support(air_support)
	player.died.connect(func() -> void: fail("KIA — o operador foi abatido em combate."))
	StealthSystem.alarm_raised.connect(_on_alarm)
	NavigationServer3D.map_changed.connect(_on_nav_map_changed)
	GraphicsQuality.apply(self, world_env.environment, sun)
	GameManager.settings_changed.connect(func() -> void: GraphicsQuality.apply(self, world_env.environment, sun))
	_begin()


func _process(delta: float) -> void:
	_time += delta
	for i in _flicker_lights.size():
		var l := _flicker_lights[i]
		var base: float = l.get_meta("base_energy", 1.5)
		l.light_energy = base if sin(_time * 23.0 + i * 7.0) * sin(_time * 3.1 + i) > -0.85 else base * 0.1
	if StealthSystem.alarm_active:
		for i in _alarm_lights.size():
			_alarm_lights[i].light_energy = 3.5 * pow(absf(sin(_time * 3.5 + i * 0.7)), 3.0)
	for i in _bobbing.size():
		var n := _bobbing[i]
		n.position.y = float(n.get_meta("base_y", 0.0)) + sin(_time * 0.9 + i) * 0.25
		n.rotation.z = sin(_time * 0.7 + i * 2.0) * 0.04
	for n in _spinning:
		n.rotate_y(delta * float(n.get_meta("spin", 0.5)))
	if not _mission_over:
		_tick_objective(delta)


func _begin() -> void:
	var cp: Array = objective_defs[start_stage].get("checkpoint", [Vector3.ZERO, 0.0])
	player.global_position = cp[0]
	player.set_view_yaw(deg_to_rad(float(cp[1])))
	# Efeitos de objetivos já concluídos (checkpoint)
	for i in start_stage:
		var o := objective_defs[i]
		match String(o["type"]):
			"rescue":
				var npc: HVTCharacter = o["npc"]
				npc.global_position = player.global_position + Vector3(1.2, 0, 1.2)
				npc.set_captured(player)
			"interact":
				for t in _targets.get(i, []):
					(t as ObjectiveInteractable).mark_used()
	hud.fade_from_black(1.5)
	if start_stage == 0 and not GameManager.intro_seen:
		for line in intro_lines():
			hud.show_radio(String(line[0]), String(line[1]), float(line[2]))
		GameManager.intro_seen = true
	objectives.start_at(start_stage)


# =========================================================================
# Objetivos
# =========================================================================

func _setup_objectives() -> void:
	var list: Array[Dictionary] = []
	for i in objective_defs.size():
		var o := objective_defs[i]
		var entry := {"id": "obj_%d" % i, "title": o.get("title", ""), "progress": o.get("hint", ""), "marker": null}
		match String(o["type"]):
			"reach":
				entry["marker"] = o["pos"]
				_add_reach_trigger(i, o["pos"], float(o.get("radius", 4.0)))
			"interact":
				var arr: Array = []
				for t in o["targets"]:
					var target := _make_target(t)
					target.used.connect(_on_target_used.bind(i))
					arr.append(target)
				_targets[i] = arr
			"defend", "escort":
				entry["marker"] = o["pos"]
				_add_zone_marker(o["pos"], float(o.get("radius", 6.0)))
			"rescue":
				var npc: HVTCharacter = o["npc"]
				entry["marker"] = npc
				npc.captured.connect(func() -> void: complete_index(i))
			"kill":
				entry["marker"] = o.get("marker", null)
		list.append(entry)
	objectives.setup(list)
	objectives.objective_started.connect(_on_objective_started)
	objectives.objective_completed.connect(func(_i: int, _o: Dictionary) -> void: hud.show_toast("CHECKPOINT SALVO"))
	objectives.all_completed.connect(_on_success)


func _on_objective_started(index: int, entry: Dictionary) -> void:
	var o := objective_defs[index]
	air_support.set_available(bool(o.get("air", false)))
	for line in o.get("radio", []):
		hud.show_radio(String(line[0]), String(line[1]), float(line[2]))
	for i in _targets.keys():
		for t in _targets[i]:
			(t as ObjectiveInteractable).set_active(i == index)
	_defend_time = 0.0
	for w in o.get("waves", []):
		spawn_wave(w, index)
	if o.has("on_start"):
		(o["on_start"] as Callable).call()
	on_objective_started(index, entry)
	_refresh_progress(index)


func _tick_objective(delta: float) -> void:
	var index := objectives.current_index
	if index < 0 or index >= objective_defs.size():
		return
	var o := objective_defs[index]
	match String(o["type"]):
		"kill":
			if count_alive(int(o.get("stage", index))) == 0:
				complete_index(index)
		"defend":
			var inside := _flat_dist(player.global_position, o["pos"]) <= float(o.get("radius", 6.0))
			if inside:
				_defend_time += delta
			for w in o.get("defend_waves", []):
				var key := "%d_%s" % [index, str(w["time"])]
				if _defend_time >= float(w["time"]) and not _defend_spawned.has(key):
					_defend_spawned[key] = true
					spawn_wave(w, index)
					hud.show_toast("Nova onda inimiga!")
			var left := maxf(float(o["duration"]) - _defend_time, 0.0)
			var text := "Resista: %d:%02d" % [int(left) / 60, int(left) % 60]
			if not inside:
				text += "  —  VOLTE PARA A POSIÇÃO!"
			objectives.set_progress("obj_%d" % index, text)
			if left <= 0.0:
				complete_index(index)
		"escort":
			var npc: HVTCharacter = o["npc"]
			var r := float(o.get("radius", 6.0))
			if _flat_dist(player.global_position, o["pos"]) <= r and npc.get_distance_to(o["pos"]) <= r + 1.5:
				complete_index(index)


func complete_index(index: int) -> void:
	if _mission_over or objectives.current_index != index:
		return
	objectives.complete("obj_%d" % index)


func _refresh_progress(index: int) -> void:
	var o := objective_defs[index]
	var id := "obj_%d" % index
	match String(o["type"]):
		"kill":
			if not o.has("hint"):
				objectives.set_progress(id, "Hostis restantes: %d" % count_alive(int(o.get("stage", index))))
		"interact":
			var arr: Array = _targets.get(index, [])
			var done := arr.filter(func(t: ObjectiveInteractable) -> bool: return t.is_used).size()
			objectives.set_progress(id, "%s: %d/%d" % [String(o.get("label", "Concluídos")), done, arr.size()])
			var next: Variant = null
			for t in arr:
				if not (t as ObjectiveInteractable).is_used:
					next = t
					break
			objectives.objectives[index]["marker"] = next
		"escort":
			objectives.set_progress(id, String(o.get("hint", "Leve o alvo até o ponto de extração")))


func _on_target_used(target: ObjectiveInteractable, index: int) -> void:
	var o := objective_defs[index]
	var mode := String(o.get("detonate", ""))
	if mode == "each":
		detonate_later(target.global_position, 5.0, target)
	_refresh_progress(index)
	var arr: Array = _targets[index]
	if arr.all(func(t: ObjectiveInteractable) -> bool: return t.is_used):
		if mode == "all":
			hud.show_radio("TRIDENT", "Cargas armadas. Detonação em 6 segundos — afastem-se!", 4.0)
			for t in arr:
				detonate_later((t as Node3D).global_position, 6.0, t)
			var tw := create_tween()
			tw.tween_interval(6.6)
			tw.tween_callback(complete_index.bind(index))
		elif mode == "each":
			var tw := create_tween()
			tw.tween_interval(5.6)
			tw.tween_callback(complete_index.bind(index))
		else:
			complete_index(index)


func _on_success() -> void:
	if _mission_over:
		return
	_mission_over = true
	pause_menu.set_enabled(false)
	GameManager.mark_mission_completed(GameManager.current_mission_id)
	hud.show_banner("MISSÃO CUMPRIDA", success_text(), 5.0)
	hud.fade_to_black(3.5)
	var tw := create_tween()
	tw.tween_interval(4.0)
	tw.tween_callback(func() -> void: GameManager.finish_mission(true, success_text()))


func fail(reason: String) -> void:
	if _mission_over:
		return
	_mission_over = true
	pause_menu.set_enabled(false)
	hud.show_banner("MISSÃO FALHOU", reason, 4.0)
	hud.fade_to_black(2.5)
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_callback(func() -> void: GameManager.finish_mission(false, reason))


# =========================================================================
# Inimigos e NPCs
# =========================================================================

func spawn_enemy(kind: String, pos: Vector3, stage: int, patrol: Array[Vector3] = [], yaw_deg: float = 0.0,
		profile_override: EnemyProfile = null, flashlight: bool = true) -> Enemy:
	if stage < start_stage:
		return null
	var e := ENEMY_SCENE.instantiate() as Enemy
	e.profile = profile_override if profile_override != null else PROFILES[kind]
	e.stage = stage
	e.use_flashlight = flashlight and environment_preset() != "overcast"  # sem lanterna em plena luz do dia
	e.patrol_points = patrol.duplicate()
	e.position = pos
	e.rotation.y = deg_to_rad(yaw_deg)
	enemies_root.add_child(e)
	e.died.connect(_on_enemy_died)
	return e


## Onda de reforço: nasce já em combate, indo atrás do jogador.
func spawn_wave(wave: Dictionary, stage: int) -> void:
	for s in wave.get("spawns", []):
		var e := spawn_enemy(String(s[0]), s[1], stage)
		if e:
			e.notify_contact.call_deferred(player.global_position)


func spawn_npc(pos: Vector3, tag: String, prompt: String, uniform: Color, beret: Color, yaw_deg: float = 0.0) -> HVTCharacter:
	var npc := NPC_SCENE.instantiate() as HVTCharacter
	npc.tag_text = tag
	npc.interact_prompt = prompt
	npc.uniform_color = uniform
	npc.beret_color = beret
	npc.interact_sound = "radio_beep"
	npc.position = pos
	npc.rotation.y = deg_to_rad(yaw_deg)
	dynamic_root.add_child(npc)
	npc.killed.connect(func() -> void: fail("%s foi morto. A missão exigia mantê-lo vivo." % tag.capitalize()))
	_npcs.append(npc)
	return npc


func boss_profile(base: String, display_name: String, health: float) -> EnemyProfile:
	var p := (PROFILES[base] as EnemyProfile).duplicate() as EnemyProfile
	p.type_name = display_name
	p.max_health = health
	p.armor = 0.35
	p.accuracy = minf(p.accuracy + 0.1, 0.95)
	return p


func count_alive(stage: int) -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e and e.stage == stage and not e.is_dead:
			n += 1
	return n


func _on_enemy_died(_enemy: Enemy) -> void:
	var index := objectives.current_index
	if index >= 0 and index < objective_defs.size():
		_refresh_progress.call_deferred(index)


# =========================================================================
# Explosões
# =========================================================================

func detonate_later(pos: Vector3, seconds: float, owner_node: Node = null) -> void:
	var tw := create_tween()
	tw.tween_interval(seconds)
	tw.tween_callback(func() -> void:
		explode(pos + Vector3.UP, 7.0, 300.0)
		if owner_node and is_instance_valid(owner_node):
			(owner_node as Node3D).visible = false
			if owner_node.has_meta("wreck"):
				_wreck(owner_node.get_meta("wreck") as Node3D))


## Destroço: o barco/objeto aderna, afunda devagar e fica queimando.
func _wreck(node: Node3D) -> void:
	_bobbing.erase(node)
	var fire := OmniLight3D.new()
	fire.light_color = Color(1.0, 0.5, 0.15)
	fire.light_energy = 3.0
	fire.omni_range = 9.0
	fire.position = Vector3(0, 1.5, 0)
	node.add_child(fire)
	add_flicker(fire)
	var tw := node.create_tween().set_parallel(true)
	tw.tween_property(node, "rotation:z", node.rotation.z + 0.45, 3.0).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "rotation:x", node.rotation.x - 0.12, 3.0)
	tw.tween_property(node, "position:y", node.position.y - 1.6, 8.0).set_ease(Tween.EASE_IN)
	var smoke := CPUParticles3D.new()
	smoke.amount = 24
	smoke.lifetime = 3.5
	smoke.direction = Vector3.UP
	smoke.spread = 15.0
	smoke.initial_velocity_min = 1.5
	smoke.initial_velocity_max = 3.0
	smoke.gravity = Vector3(0, 0.6, 0)
	smoke.scale_amount_min = 0.8
	smoke.scale_amount_max = 1.8
	var sm := BoxMesh.new()
	sm.size = Vector3(0.6, 0.6, 0.6)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.08, 0.08)
	sm.material = mat
	smoke.mesh = sm
	smoke.position = Vector3(0, 1.2, 0)
	node.add_child(smoke)


func explode(pos: Vector3, radius: float, max_damage: float) -> void:
	FX.explosion(self, pos, radius)
	StealthSystem.emit_noise(pos, 120.0, self)
	var targets: Array[Node] = []
	targets.append_array(get_tree().get_nodes_in_group("enemies"))
	targets.append_array(get_tree().get_nodes_in_group("player"))
	targets.append_array(get_tree().get_nodes_in_group("hvt"))
	for node in targets:
		var body := node as Node3D
		if body == null or not body.has_method("take_damage"):
			continue
		var d := (body.global_position + Vector3.UP * 0.9).distance_to(pos)
		if body is Player:
			(body as Player).add_shake(clampf(1.0 - d / 40.0, 0.0, 0.9))
		if d > radius:
			continue
		var info := DamageInfo.new(max_damage * (1.0 - d / radius), null, pos, body.global_position)
		info.is_explosion = true
		body.take_damage(info)


# =========================================================================
# Helpers de construção
# =========================================================================

## Chão jogável + terreno visual que se estende até o horizonte (sem colisão).
## `horizon_until_z` limita a extensão quando há mar além desse z.
func ground(size: Vector2, center: Vector3, color: Color, mat_name: String = "ground", horizon_until_z: float = INF) -> void:
	var m := builder.material(mat_name, color)
	builder.box(Vector3(size.x, 1.0, size.y), center + Vector3(0, -0.5, 0), m)
	var z0 := -600.0
	var z1 := minf(horizon_until_z, 600.0)
	builder.box(Vector3(1200, 0.02, z1 - z0), Vector3(0, -0.03, (z0 + z1) * 0.5), m, false)


func sea(center: Vector3, size: Vector2, level: float = -0.8) -> void:
	builder.water(center, size, level)


## Paredes invisíveis delimitando a área jogável.
func boundary(min_xz: Vector2, max_xz: Vector2, height: float = 14.0) -> void:
	var c := (min_xz + max_xz) * 0.5
	var s := max_xz - min_xz
	builder.collider(Vector3(s.x + 2, height, 1), Vector3(c.x, height * 0.5, min_xz.y))
	builder.collider(Vector3(s.x + 2, height, 1), Vector3(c.x, height * 0.5, max_xz.y))
	builder.collider(Vector3(1, height, s.y + 2), Vector3(min_xz.x, height * 0.5, c.y))
	builder.collider(Vector3(1, height, s.y + 2), Vector3(max_xz.x, height * 0.5, c.y))


## Árvores e moitas espalhadas num retângulo, evitando áreas livres.
func scatter_jungle(area: Rect2, count: int, avoid: Array[Rect2] = [], bush_chance: float = 0.5) -> void:
	var trunk := builder.material("trunk", Color(0.13, 0.1, 0.07))
	var leaves := builder.material("leaves", Color(0.04, 0.08, 0.04), 1.0)
	var bush_mat := builder.material("bush", Color(0.05, 0.1, 0.05), 1.0)
	var placed := 0
	var tries := 0
	while placed < count and tries < count * 10:
		tries += 1
		var p2 := Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
		if avoid.any(func(r: Rect2) -> bool: return r.has_point(p2)):
			continue
		var p := Vector3(p2.x, 0, p2.y)
		var h := rng.randf_range(5.0, 9.0)
		if rng.randf() < 0.5:
			builder.palm(p, h + 1.5, rng)
		else:
			builder.broadleaf(p, h * 0.75, rng)
		if rng.randf() < bush_chance:
			builder.bush(p + Vector3(rng.randf_range(-2, 2), 0.5, rng.randf_range(-2, 2)), rng.randf_range(0.8, 1.3), bush_mat)
		placed += 1


func lamp(pos: Vector3, color: Color = Color(1.0, 0.62, 0.3), energy: float = 2.0, light_range: float = 10.0,
		flicker: bool = false) -> OmniLight3D:
	var metal := builder.material("metal", Color(0.12, 0.13, 0.12), 0.6, 0.4)
	builder.cylinder(0.08, 4.2, pos, metal, true, 6)
	var l := builder.omni(pos + Vector3(0, 4.1, 0), color, energy, light_range, true)
	if flicker:
		add_flicker(l)
	return l


func add_flicker(l: OmniLight3D) -> void:
	l.set_meta("base_energy", l.light_energy)
	_flicker_lights.append(l)


## Luz de alarme vermelha (acende quando o alarme global dispara).
func alarm_light(pos: Vector3) -> void:
	var e := builder.omni(pos, Color(1.0, 0.08, 0.04), 0.0, 14.0)
	e.visible = false
	_alarm_lights.append(e)


## Casa/galpão com porta(s) e janelas. sides: lados com porta ("n","s","e","w").
func house(center: Vector3, size: Vector2, height: float, door_sides: Array = ["s"], wall_color: Color = Color(0.55, 0.48, 0.4),
		interior_light: bool = true, windows: bool = true) -> void:
	var mat := builder.material("house_%s" % wall_color.to_html(false), wall_color)
	var roof := builder.material("roof_house", Color(0.25, 0.14, 0.1))
	var x0 := center.x - size.x * 0.5
	var x1 := center.x + size.x * 0.5
	var z0 := center.z - size.y * 0.5
	var z1 := center.z + size.y * 0.5
	var door := Vector4(0, 1.6, 0, 2.2)
	for side in ["n", "s", "e", "w"]:
		var openings: Array[Vector4] = []
		var along_x: bool = side == "n" or side == "s"
		var mid := center.x if along_x else center.z
		var length := size.x if along_x else size.y
		if side in door_sides:
			openings.append(Vector4(mid, door.y, door.z, door.w))
		if windows and length > 6.0:
			openings.append(Vector4(mid - length * 0.3, 1.4, 1.0, 2.0))
			openings.append(Vector4(mid + length * 0.3, 1.4, 1.0, 2.0))
		match side:
			"n": builder.wall_x(x0, x1, z0, height, 0.3, mat, openings)
			"s": builder.wall_x(x0, x1, z1, height, 0.3, mat, openings)
			"w": builder.wall_z(z0, z1, x0, height, 0.3, mat, openings)
			"e": builder.wall_z(z0, z1, x1, height, 0.3, mat, openings)
	builder.box(Vector3(size.x + 0.6, 0.3, size.y + 0.6), Vector3(center.x, height + 0.15, center.z), roof)
	if interior_light:
		builder.omni(Vector3(center.x, height - 0.4, center.z), Color(1.0, 0.75, 0.45), 1.0, maxf(size.x, size.y) * 0.8)


func container(pos: Vector3, rot_y: float, color: Color) -> void:
	var mat := builder.material("container_%s" % color.to_html(false), color, 0.7, 0.3)
	builder.cover_obstacle(Vector3(2.4, 2.6, 6.0), pos + Vector3.UP * 1.3, mat, rot_y, true)


func sandbags(pos: Vector3, length: float = 3.0, rot_y: float = 0.0) -> void:
	builder.cover_obstacle(Vector3(length, 1.1, 0.6), pos + Vector3.UP * 0.55,
		builder.material("sandbag", Color(0.33, 0.29, 0.2)), rot_y)


func crates(pos: Vector3, rot_y: float = 0.0) -> void:
	builder.cover_obstacle(Vector3(2.4, 1.2, 1.2), pos + Vector3.UP * 0.6,
		builder.material("crate", Color(0.3, 0.21, 0.12)), rot_y, true)


## Barco decorativo que balança na água.
func boat(pos: Vector3, rot_y: float, length: float = 9.0, color: Color = Color(0.75, 0.75, 0.72), lit: bool = true,
		bob: bool = true) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = rot_y
	root.set_meta("base_y", pos.y)
	dynamic_root.add_child(root)
	_mesh(root, Vector3(length * 0.3, 1.2, length), Vector3.ZERO, color)
	_mesh(root, Vector3(length * 0.22, 1.0, length * 0.3), Vector3(0, 1.0, length * 0.1), Color(0.2, 0.22, 0.25))
	if lit:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.85, 0.6)
		l.light_energy = 1.2
		l.omni_range = 6.0
		l.position = Vector3(0, 2.0, 0)
		root.add_child(l)
	if bob:
		_bobbing.append(root)
	return root


func spinner(node: Node3D, speed: float) -> void:
	node.set_meta("spin", speed)
	_spinning.append(node)


func _mesh(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.7
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


func ammo_crate(pos: Vector3, yaw: float = 0.0) -> void:
	var p := Pickup.new()
	p.kind = Pickup.Kind.AMMO
	p.position = pos
	p.rotation.y = yaw
	dynamic_root.add_child(p)


# =========================================================================
# Internos
# =========================================================================

func _make_target(t: Dictionary) -> ObjectiveInteractable:
	var target := ObjectiveInteractable.new()
	target.visual = int(t.get("visual", ObjectiveInteractable.Visual.TERMINAL)) as ObjectiveInteractable.Visual
	target.prompt = String(t.get("prompt", "Segure [E] para interagir"))
	target.hold_time = float(t.get("hold", 1.8))
	target.position = t["pos"]
	target.rotation.y = deg_to_rad(float(t.get("yaw", 0.0)))
	if t.has("wreck"):
		target.set_meta("wreck", t["wreck"])
	dynamic_root.add_child(target)
	return target


func _add_reach_trigger(index: int, pos: Vector3, radius: float) -> void:
	var area := Area3D.new()
	area.collision_layer = Layers.TRIGGER
	area.collision_mask = Layers.PLAYER
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 6.0
	cs.shape = shape
	area.add_child(cs)
	area.position = pos + Vector3.UP * 2.0
	dynamic_root.add_child(area)
	area.body_entered.connect(func(body: Node3D) -> void:
		if body is Player and not (body as Player).cinematic_mode:
			complete_index(index))
	_add_zone_marker(pos, radius)


## Anel luminoso discreto no chão marcando zonas de objetivo.
func _add_zone_marker(pos: Vector3, radius: float) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.08
	torus.outer_radius = radius
	torus.rings = 48
	ring.mesh = torus
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.72, 0.25, 0.35)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = m
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = pos + Vector3.UP * 0.05
	ring.scale = Vector3(1, 0.05, 1)
	dynamic_root.add_child(ring)


func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _on_alarm(_pos: Vector3) -> void:
	for e in _alarm_lights:
		e.visible = true
	if _siren and not _siren.playing:
		_siren.play()
	if not _mission_over:
		hud.show_radio("TRIDENT", "Fomos detectados! Alarme soando — armas livres!", 3.5)


func add_siren(pos: Vector3) -> void:
	_siren = AudioManager.make_loop_player("alarm_loop", dynamic_root, -2.0, 25.0, 220.0)
	_siren.position = pos


func _on_nav_map_changed(map: RID) -> void:
	if map != nav_region.get_navigation_map():
		return
	NavigationServer3D.map_changed.disconnect(_on_nav_map_changed)
	for node in get_tree().get_nodes_in_group("cover_point"):
		var cp := node as CoverPoint
		var closest := NavigationServer3D.map_get_closest_point(map, cp.global_position)
		if Vector2(closest.x - cp.global_position.x, closest.z - cp.global_position.z).length() > 0.6:
			cp.queue_free()
		else:
			cp.global_position = closest


# --- Ambiente -------------------------------------------------------------------

func _setup_environment(preset: String) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	var top := Color(0.004, 0.007, 0.018)
	var horizon := Color(0.03, 0.04, 0.06)
	var ambient := Color(0.1, 0.12, 0.18)
	var ambient_energy := 0.45
	var light_color := Color(0.55, 0.65, 1.0)
	var light_energy := 0.28
	var light_rot := Vector3(-35, 30, 0)
	var fog := Color(0.035, 0.045, 0.065)
	var fog_density := 0.01
	match preset:
		"dusk":
			top = Color(0.06, 0.08, 0.16)
			horizon = Color(0.55, 0.28, 0.15)
			ambient = Color(0.3, 0.25, 0.28)
			ambient_energy = 0.5
			light_color = Color(1.0, 0.55, 0.3)
			light_energy = 0.7
			light_rot = Vector3(-8, -120, 0)
			fog = Color(0.35, 0.22, 0.18)
			fog_density = 0.008
		"dawn":
			top = Color(0.12, 0.18, 0.3)
			horizon = Color(0.6, 0.45, 0.35)
			ambient = Color(0.35, 0.36, 0.4)
			ambient_energy = 0.6
			light_color = Color(1.0, 0.75, 0.55)
			light_energy = 0.9
			light_rot = Vector3(-14, 70, 0)
			fog = Color(0.45, 0.42, 0.42)
			fog_density = 0.012
		"overcast":
			top = Color(0.3, 0.33, 0.36)
			horizon = Color(0.5, 0.52, 0.53)
			ambient = Color(0.45, 0.47, 0.5)
			ambient_energy = 0.7
			light_color = Color(0.85, 0.87, 0.9)
			light_energy = 0.6
			light_rot = Vector3(-50, 20, 0)
			fog = Color(0.5, 0.52, 0.54)
			fog_density = 0.014
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = horizon
	sky_mat.ground_horizon_color = horizon
	sky_mat.ground_bottom_color = horizon.darkened(0.4)
	sky_mat.sun_angle_max = 2.0
	sky_mat.sun_curve = 0.05
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient
	env.ambient_light_energy = ambient_energy
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.15
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.04
	env.ssao_enabled = true
	# Pós-processamento: luz indireta em tela, oclusão mais marcada e grade de cor
	env.ssil_enabled = true
	env.ssil_intensity = 0.8
	env.ssao_intensity = 2.2
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 0.9
	env.fog_enabled = true
	env.fog_light_color = fog
	env.fog_density = fog_density
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.008 if preset == "night" else 0.004
	env.volumetric_fog_albedo = Color(0.7, 0.75, 0.8)
	env.volumetric_fog_length = 90.0
	world_env.environment = env
	sun.rotation_degrees = light_rot
	sun.light_color = light_color
	sun.light_energy = light_energy
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
