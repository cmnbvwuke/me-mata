extends Node3D
## FASE 3 — "ABSOLUTE RESOLVE"
## Operação noturna de captura do General Rodrigo Salcedo na Hacienda El Mirador.
##
## Fluxo:  infiltração de helicóptero (voo baixo sobre o mar)
##      -> 0 INFILTRAR o complexo (furtividade, holofotes, vegetação)
##      -> 1 ELIMINAR a resistência no pátio (apoio aéreo liberado)
##      -> 2 CAPTURAR o HVT na residência (CQB, sala segura)
##      -> 3 EXTRAIR com o HVT até o helicóptero (reforços do cartel)
##
## A geometria é montada em código (greybox) com o LevelBuilder e o navmesh é
## gerado em tempo de execução. Cada objetivo concluído é um checkpoint: ao
## recarregar, só nascem os inimigos das etapas >= checkpoint.

const ENEMY_SCENE := preload("res://scenes/enemies/enemy.tscn")
const HVT_SCENE := preload("res://scenes/characters/hvt.tscn")
const PROFILES := {
	"guard": preload("res://resources/enemies/guard.tres"),
	"elite": preload("res://resources/enemies/elite.tres"),
	"militia": preload("res://resources/enemies/militia.tres"),
}

enum Stage { INFILTRATE, CLEAR_COURTYARD, CAPTURE_HVT, EXTRACT }

const LZ_POS := Vector3(-8, 0, 56)
const HELIPAD_POS := Vector3(-20, 0, -4)
const HVT_POS := Vector3(12, 0, -35)
const COMPOUND_CENTER := Vector3(0, 0, -15)
## [posição, yaw em graus] de cada checkpoint (índice = objetivo)
const CHECKPOINTS := [
	[Vector3(-8, 0, 56), 200.0],
	[Vector3(-20, 0, 7), 0.0],
	[Vector3(0, 0, -10.5), 0.0],
	[Vector3(11.5, 0, -29.5), 0.0],
]

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
@onready var moon: DirectionalLight3D = $Moon

var builder: LevelBuilder
var heli: Helicopter
var hvt: HVTCharacter
var start_stage: int = 0

var _helipad_marker: Marker3D
var _breach_marker: Marker3D
var _courtyard_marker: Marker3D
var _emergency_lights: Array[OmniLight3D] = []
var _flicker_lights: Array[OmniLight3D] = []
var _siren: AudioStreamPlayer3D
var _mission_over := false
var _intro_active := false
var _heli_landed := false
var _extraction_started := false
var _time := 0.0
var _hvt_warned := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 1337
	start_stage = mini(GameManager.checkpoint_index, Stage.EXTRACT)
	builder = LevelBuilder.new(geometry, dynamic_root)
	_setup_environment()
	_build_terrain()
	_build_jungle()
	_build_outer_area()
	_build_compound_walls()
	_build_courtyard()
	_build_residence()
	_build_boundaries()
	nav_region.bake_navigation_mesh(false)
	_build_lights()
	_spawn_enemies()
	_spawn_hvt()
	_spawn_pickups()
	_setup_heli()
	_setup_objectives()
	_connect_signals()
	hud.bind_player(player)
	hud.bind_objectives(objectives)
	hud.bind_air_support(air_support)
	NavigationServer3D.map_changed.connect(_on_nav_map_changed)
	_begin()


func _process(delta: float) -> void:
	_time += delta
	_animate_lights()
	if _intro_active:
		player.global_position = heli.seat.global_position
		if Input.is_action_just_pressed("skip_intro"):
			_end_intro()
	if _mission_over:
		return
	if objectives.is_current("extract"):
		_check_extraction()
	if hvt and hvt.state == HVTCharacter.State.FOLLOWING and not _hvt_warned:
		if hvt.global_position.distance_to(player.global_position) > 25.0:
			_hvt_warned = true
			hud.show_radio("REYES", "O HVT ficou para trás! Não o perca de vista.", 3.0)
	elif hvt and _hvt_warned and hvt.global_position.distance_to(player.global_position) < 10.0:
		_hvt_warned = false


# =========================================================================
# Ambiente noturno
# =========================================================================

func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.004, 0.007, 0.018)
	sky_mat.sky_horizon_color = Color(0.03, 0.04, 0.06)
	sky_mat.ground_horizon_color = Color(0.03, 0.04, 0.06)
	sky_mat.ground_bottom_color = Color(0.0, 0.0, 0.0)
	sky_mat.sun_angle_max = 2.0
	sky_mat.sun_curve = 0.05
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.1, 0.12, 0.18)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.15
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.05
	env.ssao_enabled = true
	env.fog_enabled = true
	env.fog_light_color = Color(0.035, 0.045, 0.065)
	env.fog_density = 0.01
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.01
	env.volumetric_fog_albedo = Color(0.7, 0.75, 0.8)
	env.volumetric_fog_length = 90.0
	world_env.environment = env
	moon.light_color = Color(0.55, 0.65, 1.0)
	moon.light_energy = 0.28
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 90.0


# =========================================================================
# Geometria
# =========================================================================

func _build_terrain() -> void:
	var ground := builder.material("ground", Color(0.11, 0.12, 0.09))
	var sand := builder.material("sand", Color(0.32, 0.3, 0.25))
	var road := builder.material("road", Color(0.16, 0.14, 0.12))
	builder.box(Vector3(300, 1, 230), Vector3(0, -0.5, -40), ground)
	builder.box(Vector3(300, 0.02, 14), Vector3(0, 0.01, 69), sand, false)
	builder.box(Vector3(6, 0.02, 60), Vector3(8, 0.012, 40), road, false)
	builder.box(Vector3(3, 0.02, 40), Vector3(-6, 0.012, 48), road, false, 0.35)
	# Mar
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.01, 0.025, 0.04)
	water.metallic = 0.7
	water.roughness = 0.12
	builder.box(Vector3(800, 0.1, 400), Vector3(0, -0.8, 275), water, false)
	builder.box(Vector3(300, 1.2, 4), Vector3(0, -0.6, 76.5), sand, false)
	# Píer e lancha do cartel (ambientação da Fase 1)
	var wood := builder.material("wood", Color(0.22, 0.16, 0.1))
	builder.box(Vector3(3, 0.3, 24), Vector3(-30, -0.2, 88), wood, false)
	var boat := builder.material("boat", Color(0.75, 0.75, 0.72), 0.5)
	builder.box(Vector3(2.6, 1.2, 9), Vector3(-26.5, -0.3, 96), boat, false)
	builder.box(Vector3(2.0, 1.0, 3), Vector3(-26.5, 0.8, 97), builder.material("boat_cabin", Color(0.2, 0.22, 0.25)), false)


func _build_jungle() -> void:
	var trunk := builder.material("trunk", Color(0.13, 0.1, 0.07))
	var leaves := builder.material("leaves", Color(0.04, 0.08, 0.04), 1.0)
	var bush_mat := builder.material("bush", Color(0.05, 0.1, 0.05), 1.0)
	var placed := 0
	var tries := 0
	while placed < 120 and tries < 1000:
		tries += 1
		var p := Vector3(_rng.randf_range(-62, 62), 0, _rng.randf_range(15, 68))
		if p.distance_to(LZ_POS) < 10.0:
			continue
		if absf(p.x - 8.0) < 5.0 and p.z < 60.0:   # estrada
			continue
		if p.z < 22.0 and absf(p.x) < 34.0:         # faixa limpa junto ao muro
			continue
		if Vector2(p.x + 22, p.z - 30).length() < 6.0 or Vector2(p.x - 14, p.z - 24).length() < 6.0:
			continue
		var h := _rng.randf_range(5.0, 9.0)
		builder.cylinder(_rng.randf_range(0.18, 0.3), h, p, trunk, true, 8)
		builder.sphere(_rng.randf_range(2.0, 3.2), p + Vector3.UP * h, leaves, 0.6)
		if _rng.randf() < 0.6:
			builder.bush(p + Vector3(_rng.randf_range(-2, 2), 0.5, _rng.randf_range(-2, 2)), _rng.randf_range(0.8, 1.3), bush_mat)
		placed += 1
	# Selva fora dos muros laterais/fundo (silhueta)
	for i in 70:
		var side := _rng.randi_range(0, 2)
		var p := Vector3.ZERO
		match side:
			0: p = Vector3(_rng.randf_range(-70, -38), 0, _rng.randf_range(-70, 14))
			1: p = Vector3(_rng.randf_range(38, 70), 0, _rng.randf_range(-70, 14))
			_: p = Vector3(_rng.randf_range(-40, 40), 0, _rng.randf_range(-75, -48))
		var h := _rng.randf_range(6.0, 11.0)
		builder.cylinder(0.25, h, p, trunk, true, 6)
		builder.sphere(_rng.randf_range(2.5, 3.5), p + Vector3.UP * h, leaves, 0.6)
	# Moitas que permitem uma aproximação furtiva até a brecha do muro sul
	for p in [Vector3(-24, 0.5, 18), Vector3(-17, 0.5, 19.5), Vector3(-21, 0.5, 24), Vector3(-13, 0.5, 26),
			Vector3(-26, 0.5, 33), Vector3(-15, 0.5, 34), Vector3(-9, 0.5, 40), Vector3(-19, 0.5, 42),
			Vector3(-11, 0.5, 47), Vector3(2, 0.5, 20), Vector3(20, 0.5, 19), Vector3(26, 0.5, 23)]:
		builder.bush(p, 1.2, bush_mat)


func _build_outer_area() -> void:
	var concrete := builder.material("concrete", Color(0.34, 0.32, 0.29))
	var sandbag := builder.material("sandbag", Color(0.33, 0.29, 0.2))
	var metal := builder.material("metal", Color(0.12, 0.13, 0.12), 0.6, 0.4)
	var rust := builder.material("rust", Color(0.25, 0.13, 0.07), 0.8, 0.3)
	var rock := builder.material("rock", Color(0.2, 0.2, 0.19))

	# Galpão de armazenagem
	builder.cover_obstacle(Vector3(5, 3, 4), Vector3(-22, 1.5, 30), concrete, 0.0, true)
	builder.box(Vector3(5.6, 0.2, 4.6), Vector3(-22, 3.1, 30), metal, false)

	# Caminhão militar estacionado
	builder.collider(Vector3(2.4, 2.8, 6.4), Vector3(14, 1.4, 24))
	builder.box(Vector3(2.3, 1.0, 6.2), Vector3(14, 0.9, 24), metal, false)
	builder.box(Vector3(2.3, 1.6, 4.0), Vector3(14, 2.2, 25.0), builder.material("canvas", Color(0.2, 0.22, 0.15)), false)
	builder.box(Vector3(2.3, 1.3, 1.8), Vector3(14, 2.0, 21.8), metal, false)
	for z in [21.8, 25.5]:
		for x in [12.8, 15.2]:
			builder.box(Vector3(0.35, 0.9, 0.9), Vector3(x, 0.45, z), builder.material("tire", Color(0.03, 0.03, 0.03)), false)
	for p in [Vector3(12.4, 0, 24), Vector3(15.6, 0, 24), Vector3(14, 0, 20.2), Vector3(14, 0, 27.8)]:
		builder.add_cover_point(p)

	# Posto de controle na estrada
	builder.cover_obstacle(Vector3(2.6, 1.1, 0.6), Vector3(4.2, 0.55, 31), sandbag)
	builder.cover_obstacle(Vector3(2.6, 1.1, 0.6), Vector3(11.8, 0.55, 31), sandbag)
	builder.box(Vector3(6, 0.12, 0.12), Vector3(8, 1.0, 31), builder.material("barrier", Color(0.6, 0.1, 0.08)), false)
	builder.cover_obstacle(Vector3(1.6, 2.5, 1.6), Vector3(13.6, 1.25, 33.5), concrete)

	# Tambores de combustível e pedras (cobertura no caminho)
	for base in [Vector3(-6, 0, 34), Vector3(2, 0, 41), Vector3(18, 0, 34)]:
		for i in 4:
			var off := Vector3((i % 2) * 0.65, 0, (i / 2) * 0.65)
			builder.cylinder(0.3, 0.95, base + off, rust, true, 10)
		for p in [base + Vector3(0.3, 0, -0.9), base + Vector3(0.3, 0, 1.6), base + Vector3(-0.9, 0, 0.3), base + Vector3(1.6, 0, 0.3)]:
			builder.add_cover_point(p)
	builder.cover_obstacle(Vector3(2.4, 1.2, 1.6), Vector3(-14, 0.6, 44), rock, 0.4)
	builder.cover_obstacle(Vector3(2.0, 1.0, 1.5), Vector3(0, 0.5, 49), rock, -0.3)
	builder.cover_obstacle(Vector3(2.8, 1.4, 1.8), Vector3(-27, 0.7, 40), rock, 0.8)
	builder.cover_obstacle(Vector3(1.8, 1.1, 1.4), Vector3(24, 0.55, 40), rock, 0.2)


func _build_compound_walls() -> void:
	var wall := builder.material("compound_wall", Color(0.4, 0.37, 0.33))
	var rubble := builder.material("rubble", Color(0.3, 0.28, 0.25))
	# Muro sul: portão de veículos (x=8) e brecha desmoronada (x=-20)
	builder.wall_x(-32, 32, 10, 3.6, 0.5, wall, [Vector4(8, 6, 0, 3.6), Vector4(-20, 2.4, 0, 3.6)])
	builder.wall_x(-32, 32, -42, 3.6, 0.5, wall)
	builder.wall_z(-42, 10, -32, 3.6, 0.5, wall)
	builder.wall_z(-42, 10, 32, 3.6, 0.5, wall)
	# Entulho da brecha (só nas laterais, sem bloquear a passagem)
	builder.box(Vector3(1.2, 0.6, 1.0), Vector3(-22.0, 0.3, 10.6), rubble, true, 0.4)
	builder.box(Vector3(1.0, 0.4, 0.8), Vector3(-17.9, 0.2, 9.4), rubble, true, -0.6)
	builder.box(Vector3(2.4, 0.9, 0.5), Vector3(-20, 3.15, 10), rubble, false)
	# Arame farpado no topo (visual)
	builder.box(Vector3(64, 0.25, 0.25), Vector3(0, 3.75, 10), builder.material("wire", Color(0.1, 0.1, 0.1)), false)
	_breach_marker = Marker3D.new()
	_breach_marker.position = Vector3(-20, 0, 10)
	dynamic_root.add_child(_breach_marker)

	# Torres de vigia (SO e SE) — plataforma a 5,5 m
	for x in [-28.0, 28.0]:
		_build_watchtower(Vector3(x, 0, 6))
	# Guarita no portão
	builder.cover_obstacle(Vector3(4, 3, 3.5), Vector3(14, 1.5, 6.5), builder.material("concrete", Color()), 0.0, true)
	builder.box(Vector3(4.4, 0.2, 3.9), Vector3(14, 3.1, 6.5), builder.material("metal", Color()), false)
	# Galpões laterais (quartel e garagem)
	builder.cover_obstacle(Vector3(8, 3.2, 16), Vector3(-27, 1.6, -26), wall, 0.0, true)
	builder.cover_obstacle(Vector3(8, 3.6, 14), Vector3(27, 1.8, -26), wall, 0.0, true)


func _build_watchtower(base: Vector3) -> void:
	var wood := builder.material("tower_wood", Color(0.2, 0.15, 0.1))
	for off in [Vector3(-1.4, 0, -1.4), Vector3(1.4, 0, -1.4), Vector3(-1.4, 0, 1.4), Vector3(1.4, 0, 1.4)]:
		builder.box(Vector3(0.3, 5.5, 0.3), base + off + Vector3.UP * 2.75, wood)
		builder.box(Vector3(0.15, 2.6, 0.15), base + off + Vector3.UP * 6.95, wood, false)
	builder.box(Vector3(3.4, 0.3, 3.4), base + Vector3.UP * 5.5, wood)
	builder.box(Vector3(3.4, 0.95, 0.1), base + Vector3(0, 6.1, 1.65), wood)
	builder.box(Vector3(3.4, 0.95, 0.1), base + Vector3(0, 6.1, -1.65), wood)
	builder.box(Vector3(0.1, 0.95, 3.4), base + Vector3(1.65, 6.1, 0), wood)
	builder.box(Vector3(0.1, 0.95, 3.4), base + Vector3(-1.65, 6.1, 0), wood)
	builder.box(Vector3(3.8, 0.2, 3.8), base + Vector3.UP * 8.3, builder.material("metal", Color()), false)
	builder.box(Vector3(0.5, 5.4, 0.08), base + Vector3(0, 2.7, -1.7), wood, false)  # escada (visual)


func _build_courtyard() -> void:
	var concrete := builder.material("concrete", Color())
	var sandbag := builder.material("sandbag", Color())
	var metal := builder.material("metal", Color())
	var crate := builder.material("crate", Color(0.3, 0.21, 0.12))
	var paving := builder.material("paving", Color(0.22, 0.21, 0.19))
	builder.box(Vector3(63, 0.02, 52), Vector3(0, 0.005, -16), paving, false)

	# Chafariz com a estátua do General
	builder.cylinder(2.3, 0.8, Vector3(0, 0, -2), concrete, true, 24)
	builder.cylinder(0.5, 1.2, Vector3(0, 0.8, -2), concrete, false, 12)
	builder.box(Vector3(0.7, 1.6, 0.5), Vector3(0, 2.8, -2), builder.material("bronze", Color(0.25, 0.2, 0.12), 0.5, 0.6), false)
	for a in 8:
		var ang := a * TAU / 8.0
		builder.add_cover_point(Vector3(0, 0, -2) + Vector3(cos(ang), 0, sin(ang)) * 2.9)

	# SUVs blindados
	for car in [[Vector3(-8, 0, 2), 0.35], [Vector3(6, 0, -6), -0.2]]:
		var pos: Vector3 = car[0]
		var rot: float = car[1]
		builder.cover_obstacle(Vector3(2.0, 1.4, 4.8), pos + Vector3.UP * 0.7, metal, rot, true)
		builder.box(Vector3(1.9, 0.6, 2.6), pos + Vector3(0, 1.7, 0) + Basis(Vector3.UP, rot) * Vector3(0, 0, 0.4),
			builder.material("glass_dark", Color(0.02, 0.03, 0.04), 0.1, 0.5, false), false, rot)

	# Sacos de areia
	builder.cover_obstacle(Vector3(4, 1.1, 0.6), Vector3(-4, 0.55, -9), sandbag)
	builder.cover_obstacle(Vector3(4, 1.1, 0.6), Vector3(6, 0.55, -10.5), sandbag)
	builder.cover_obstacle(Vector3(3, 1.1, 0.6), Vector3(3.5, 0.55, 6.5), sandbag)
	builder.cover_obstacle(Vector3(0.6, 1.1, 3), Vector3(12.5, 0.55, 2), sandbag)
	builder.cover_obstacle(Vector3(3, 1.1, 0.6), Vector3(-14, 0.55, 5), sandbag)

	# Pilha de caixotes
	builder.cover_obstacle(Vector3(2.4, 1.2, 1.2), Vector3(18, 0.6, -3), crate, 0.0, true)
	builder.box(Vector3(1.2, 1.2, 1.2), Vector3(17.6, 1.8, -3), crate)
	builder.cover_obstacle(Vector3(1.2, 1.2, 1.2), Vector3(20.5, 0.6, -6), crate, 0.3, true)

	# Gerador
	builder.cover_obstacle(Vector3(3, 2.2, 2), Vector3(22, 1.1, -10), metal, 0.0, true)
	builder.box(Vector3(0.4, 0.3, 0.05), Vector3(22, 1.5, -11.02), builder.emissive("gen_led", Color(0.2, 1.0, 0.3), 3.0), false)

	# Heliponto do General
	builder.cylinder(5.0, 0.04, HELIPAD_POS, builder.material("helipad", Color(0.2, 0.2, 0.21)), false, 32)
	var mark := builder.material("helipad_mark", Color(0.75, 0.72, 0.6))
	builder.box(Vector3(0.6, 0.02, 3.6), HELIPAD_POS + Vector3(-1.1, 0.05, 0), mark, false)
	builder.box(Vector3(0.6, 0.02, 3.6), HELIPAD_POS + Vector3(1.1, 0.05, 0), mark, false)
	builder.box(Vector3(1.6, 0.02, 0.6), HELIPAD_POS + Vector3(0, 0.05, 0), mark, false)
	_helipad_marker = Marker3D.new()
	_helipad_marker.position = HELIPAD_POS
	dynamic_root.add_child(_helipad_marker)
	_courtyard_marker = Marker3D.new()
	_courtyard_marker.position = Vector3(0, 0, -2)
	dynamic_root.add_child(_courtyard_marker)

	# Postes de luz (o poste em si)
	for p in _lamp_positions():
		builder.cylinder(0.08, 4.2, p, metal, true, 6)
		builder.box(Vector3(0.5, 0.15, 0.3), p + Vector3(0, 4.25, 0), metal, false)


func _lamp_positions() -> Array[Vector3]:
	return [Vector3(-10, 0, 8), Vector3(10, 0, 8), Vector3(-16, 0, -10), Vector3(16, 0, -10),
		Vector3(-6, 0, -12.5), Vector3(6, 0, -12.5)]


func _build_residence() -> void:
	var ext := builder.material("villa_ext", Color(0.55, 0.5, 0.42))
	var inner := builder.material("villa_int", Color(0.45, 0.42, 0.37))
	var roof := builder.material("roof", Color(0.18, 0.12, 0.1))
	var tile := builder.material("floor_tile", Color(0.3, 0.26, 0.21))
	var wood := builder.material("furniture", Color(0.2, 0.13, 0.08))
	var fabric := builder.material("fabric", Color(0.3, 0.08, 0.08))
	var metal := builder.material("metal", Color())
	var h := 3.4
	var door := 2.2

	builder.box(Vector3(28, 0.02, 24), Vector3(0, 0.02, -26), tile, false)
	builder.box(Vector3(29, 0.3, 25), Vector3(0, h + 0.15, -26), roof)
	# Paredes externas
	builder.wall_x(-14, 14, -14, h, 0.35, ext, [Vector4(0, 2.0, 0, door), Vector4(-9, 2.0, 1.0, 2.1), Vector4(9, 2.0, 1.0, 2.1)])
	builder.wall_x(-14, 14, -38, h, 0.35, ext, [Vector4(-9, 2.0, 1.0, 2.1), Vector4(0, 2.4, 1.0, 2.1)])
	builder.wall_z(-38, -14, -14, h, 0.35, ext, [Vector4(-31, 2.0, 1.0, 2.1), Vector4(-17, 1.6, 1.0, 2.1), Vector4(-22, 1.4, 0, door)])
	builder.wall_z(-38, -14, 14, h, 0.35, ext, [Vector4(-17, 1.6, 1.0, 2.1), Vector4(-22, 1.4, 0, door)])
	# Paredes internas
	builder.wall_z(-20, -14, -4, h, 0.2, inner, [Vector4(-17, 1.4, 0, door)])                 # guarda | hall
	builder.wall_z(-20, -14, 4, h, 0.2, inner, [Vector4(-17, 1.4, 0, door)])                  # hall | cozinha
	builder.wall_x(-14, 14, -20, h, 0.2, inner, [Vector4(-9, 1.4, 0, door), Vector4(0, 2.0, 0, door), Vector4(9, 1.4, 0, door)])
	builder.wall_x(-14, 14, -24, h, 0.2, inner, [Vector4(-9.5, 1.4, 0, door), Vector4(0, 3.0, 0, door), Vector4(8, 1.4, 0, door)])
	builder.wall_z(-38, -24, -5, h, 0.2, inner, [Vector4(-31, 1.4, 0, door)])                 # escritório | sala
	builder.wall_z(-38, -24, 5, h, 0.2, inner, [Vector4(-34, 1.4, 0, door)])                  # sala | quarto
	builder.wall_z(-38, -31, 9, h, 0.3, metal)                                                # sala segura (blindada)
	builder.wall_x(9, 14, -31, h, 0.3, metal, [Vector4(11.5, 1.4, 0, door)])
	# Varanda frontal
	for x in [-4.0, 4.0]:
		builder.cylinder(0.2, h, Vector3(x, 0, -12.6), ext, true, 10)
	builder.box(Vector3(10, 0.2, 2.2), Vector3(0, h, -12.9), roof, false)

	# Mobília — sala da guarda
	builder.cover_obstacle(Vector3(1.8, 0.8, 0.9), Vector3(-9, 0.4, -17), wood)
	builder.box(Vector3(2.0, 1.2, 0.9), Vector3(-12.9, 0.6, -18.8), metal)                     # beliche
	builder.box(Vector3(0.4, 1.8, 1.6), Vector3(-4.4, 0.9, -15.4), metal)                      # armário de armas
	# Cozinha
	builder.cover_obstacle(Vector3(2.4, 0.95, 1.1), Vector3(8.5, 0.475, -17), builder.material("counter", Color(0.5, 0.48, 0.44)))
	builder.box(Vector3(0.65, 0.95, 4.5), Vector3(13.5, 0.475, -17.2), builder.material("counter", Color()))
	# Corredor
	builder.box(Vector3(1.2, 0.9, 0.5), Vector3(-6, 0.45, -23.6), wood)
	builder.box(Vector3(1.2, 0.9, 0.5), Vector3(5, 0.45, -20.4), wood)
	# Escritório
	builder.cover_obstacle(Vector3(2.2, 0.8, 1.0), Vector3(-9.5, 0.4, -33), wood, 0.0, true)
	builder.box(Vector3(0.5, 2.4, 3.5), Vector3(-13.5, 1.2, -28), wood)                        # estante
	builder.box(Vector3(0.8, 1.0, 0.7), Vector3(-6, 0.5, -37.4), metal)                        # cofre
	# Sala de estar
	builder.cover_obstacle(Vector3(2.6, 0.85, 0.9), Vector3(-1, 0.425, -28.5), fabric)
	builder.cover_obstacle(Vector3(0.9, 0.85, 2.4), Vector3(2.8, 0.425, -31.5), fabric)
	builder.cover_obstacle(Vector3(1.4, 0.5, 0.8), Vector3(-1, 0.25, -31), wood)
	builder.box(Vector3(2.4, 1.3, 0.1), Vector3(-1, 1.5, -37.75), builder.emissive("tv", Color(0.25, 0.35, 0.6), 1.2), false)
	builder.cover_obstacle(Vector3(1.0, 0.8, 2.6), Vector3(-3.0, 0.4, -35), wood)              # mesa de jantar
	# Quarto
	builder.cover_obstacle(Vector3(2.0, 0.6, 2.4), Vector3(7.2, 0.3, -28.5), fabric)
	builder.box(Vector3(0.6, 2.2, 1.8), Vector3(13.6, 1.1, -27.5), wood)
	# Sala segura: monitores do CFTV e mesa
	builder.box(Vector3(1.6, 0.8, 0.7), Vector3(12.5, 0.4, -37.4), metal)
	builder.box(Vector3(1.4, 0.5, 0.05), Vector3(12.5, 1.3, -37.8), builder.emissive("cctv", Color(0.3, 0.55, 0.4), 1.5), false)


func _build_boundaries() -> void:
	# Limites invisíveis da área jogável
	builder.collider(Vector3(130, 12, 1), Vector3(0, 6, 74))
	builder.collider(Vector3(130, 12, 1), Vector3(0, 6, -60))
	builder.collider(Vector3(1, 12, 140), Vector3(-62, 6, 5))
	builder.collider(Vector3(1, 12, 140), Vector3(62, 6, 5))


# =========================================================================
# Luzes
# =========================================================================

func _build_lights() -> void:
	var sodium := Color(1.0, 0.62, 0.3)
	for p in _lamp_positions():
		var l := builder.omni(p + Vector3(0, 4.1, 0), sodium, 2.2, 11.0, true)
		if p.x < -12.0:
			_add_flicker(l)
	# Luz da porta do galpão e do posto de controle
	_add_flicker(builder.omni(Vector3(-22, 2.6, 27.6), sodium, 1.6, 7.0, true))
	builder.omni(Vector3(13.6, 2.7, 32.6), sodium, 1.4, 6.0)
	# Refletores fixos no portão e na fachada
	builder.spot(Vector3(11.5, 4.2, 10.4), Vector3(8, 0, 24), Color(0.9, 0.95, 1.0), 5.0, 30.0, 30.0)
	builder.spot(Vector3(-13.5, 3.2, -13.6), Vector3(-6, 0, 0), Color(0.9, 0.95, 1.0), 3.0, 22.0, 35.0)
	builder.spot(Vector3(13.5, 3.2, -13.6), Vector3(6, 0, 0), Color(0.9, 0.95, 1.0), 3.0, 22.0, 35.0)
	# Luzes do heliponto
	for a in 6:
		var ang := a * TAU / 6.0
		builder.omni(HELIPAD_POS + Vector3(cos(ang) * 5.2, 0.15, sin(ang) * 5.2), Color(0.3, 1.0, 0.4), 0.5, 1.8)
	# Interior da residência (pouca luz, quentes; uma lâmpada falhando no corredor)
	builder.omni(Vector3(0, 3.0, -17), Color(1.0, 0.75, 0.45), 1.3, 7.0, true)
	builder.omni(Vector3(-9, 3.0, -17), Color(0.8, 0.9, 1.0), 0.9, 6.5)
	builder.omni(Vector3(9, 3.0, -17), Color(1.0, 0.8, 0.55), 0.6, 6.0)
	_add_flicker(builder.omni(Vector3(-6, 3.0, -22), Color(1.0, 0.85, 0.6), 1.0, 6.0, true))
	builder.omni(Vector3(7, 3.0, -22), Color(1.0, 0.85, 0.6), 0.7, 6.0)
	builder.omni(Vector3(-9.5, 1.4, -33), Color(1.0, 0.7, 0.4), 0.8, 4.5, true)
	builder.omni(Vector3(-1, 1.5, -36.8), Color(0.35, 0.45, 0.9), 0.9, 6.0)
	builder.omni(Vector3(7, 2.8, -28), Color(1.0, 0.7, 0.45), 0.5, 5.5)
	builder.omni(Vector3(12, 3.0, -34.5), Color(1.0, 0.15, 0.1), 1.2, 6.0, true)
	# Giroflex de emergência (ligam com o alarme)
	for p in [Vector3(0, 3.6, -13.4), Vector3(14, 3.4, 8.3), Vector3(-26.9, 3.4, -17.8), Vector3(26.9, 3.8, -18.8),
			Vector3(0, 3.0, -22), Vector3(-28, 8.1, 6), Vector3(28, 8.1, 6)]:
		var e := builder.omni(p, Color(1.0, 0.08, 0.04), 0.0, 14.0)
		e.visible = false
		_emergency_lights.append(e)
	_siren = AudioManager.make_loop_player("alarm_loop", dynamic_root, -2.0, 25.0, 220.0)
	_siren.position = Vector3(0, 4.0, -26)


func _add_flicker(l: OmniLight3D) -> void:
	l.set_meta("base_energy", l.light_energy)
	_flicker_lights.append(l)


func _animate_lights() -> void:
	# Lâmpadas com mau contato
	for i in _flicker_lights.size():
		var l := _flicker_lights[i]
		var n := sin(_time * 23.0 + i * 7.0) * sin(_time * 3.1 + i)
		var base: float = l.get_meta("base_energy", 1.5)
		l.light_energy = base if n > -0.85 else base * 0.1
	if StealthSystem.alarm_active:
		for i in _emergency_lights.size():
			_emergency_lights[i].light_energy = 3.5 * pow(absf(sin(_time * 3.5 + i * 0.7)), 3.0)


func _on_alarm_raised(_pos: Vector3) -> void:
	for e in _emergency_lights:
		e.visible = true
	if not _siren.playing:
		_siren.play()
	if not _mission_over:
		hud.show_radio("REYES", "Fomos detectados! Alarme no complexo — armas livres!", 3.5)


# =========================================================================
# Personagens
# =========================================================================

func _spawn_enemies() -> void:
	# --- Etapa 0: perímetro externo -------------------------------------------
	_spawn("guard", Vector3(-26, 0, 14), Stage.INFILTRATE, [Vector3(-26, 0, 14), Vector3(4, 0, 14)])
	_spawn("guard", Vector3(6, 0, 29.5), Stage.INFILTRATE, [], 180.0)
	_spawn("guard", Vector3(10, 0, 32), Stage.INFILTRATE, [Vector3(10, 0, 32), Vector3(10, 0, 48), Vector3(-4, 0, 44)])
	_spawn("militia", Vector3(-22, 0, 27.2), Stage.INFILTRATE, [], 150.0)
	_spawn("guard", Vector3(8, 0, 8), Stage.INFILTRATE, [], 180.0)
	for x in [-28.0, 28.0]:
		var tower_guard := _spawn("guard", Vector3(x, 5.75, 6), Stage.INFILTRATE, [], 180.0, false)
		if tower_guard:
			var light := Searchlight.new()
			light.owner_enemy = tower_guard
			light.position = Vector3(x, 6.9, 7.4)
			light.base_yaw = PI + (0.35 if x < 0 else -0.35)
			dynamic_root.add_child(light)
	# --- Etapa 1: pátio --------------------------------------------------------
	var loop: Array[Vector3] = [Vector3(-10, 0, 3.5), Vector3(10, 0, 3.5), Vector3(10, 0, -9), Vector3(-10, 0, -9)]
	_spawn("guard", loop[0], Stage.CLEAR_COURTYARD, loop)
	var loop_rev: Array[Vector3] = [loop[2], loop[1], loop[0], loop[3]]
	_spawn("guard", loop[2], Stage.CLEAR_COURTYARD, loop_rev)
	_spawn("guard", Vector3(2.5, 0, 1.5), Stage.CLEAR_COURTYARD, [], 180.0)
	_spawn("militia", Vector3(-6, 0, 4.8), Stage.CLEAR_COURTYARD, [], 200.0)
	_spawn("militia", Vector3(8.5, 0, -3.5), Stage.CLEAR_COURTYARD, [], 140.0)
	_spawn("elite", Vector3(1.5, 0, -12), Stage.CLEAR_COURTYARD, [], 180.0)
	_spawn("guard", Vector3(-18, 0, -1), Stage.CLEAR_COURTYARD, [Vector3(-18, 0, -1), Vector3(-24, 0, -8)])
	_spawn("militia", Vector3(17, 0, -1.5), Stage.CLEAR_COURTYARD, [], 160.0)
	# --- Etapa 2: residência (CQB) ---------------------------------------------
	_spawn("elite", Vector3(2, 0, -18), Stage.CAPTURE_HVT, [], 180.0)
	_spawn("guard", Vector3(-10.5, 0, -18.5), Stage.CAPTURE_HVT, [], 90.0)
	_spawn("militia", Vector3(10.5, 0, -15.5), Stage.CAPTURE_HVT, [], 120.0)
	_spawn("elite", Vector3(-12, 0, -22), Stage.CAPTURE_HVT, [Vector3(-12, 0, -22), Vector3(12, 0, -22)])
	_spawn("elite", Vector3(-8, 0, -30), Stage.CAPTURE_HVT, [], 0.0)
	_spawn("elite", Vector3(-2, 0, -33), Stage.CAPTURE_HVT, [], 0.0)
	_spawn("elite", Vector3(1.5, 0, -36), Stage.CAPTURE_HVT, [], 30.0)
	_spawn("elite", Vector3(7, 0, -26), Stage.CAPTURE_HVT, [], 180.0)


## Instancia um inimigo, a menos que sua etapa já tenha sido superada (checkpoint).
func _spawn(kind: String, pos: Vector3, stage: int, patrol: Array[Vector3] = [], yaw_deg: float = 0.0,
		flashlight: bool = true) -> Enemy:
	if stage < start_stage:
		return null
	var e := ENEMY_SCENE.instantiate() as Enemy
	e.profile = PROFILES[kind]
	e.stage = stage
	e.use_flashlight = flashlight
	e.patrol_points = patrol.duplicate()
	e.position = pos
	e.rotation.y = deg_to_rad(yaw_deg)
	enemies_root.add_child(e)
	e.died.connect(_on_enemy_died)
	return e


func _spawn_hvt() -> void:
	hvt = HVT_SCENE.instantiate() as HVTCharacter
	hvt.position = HVT_POS
	hvt.rotation.y = deg_to_rad(20.0)
	dynamic_root.add_child(hvt)
	hvt.captured.connect(_on_hvt_captured)
	hvt.killed.connect(_on_hvt_killed)


func _spawn_pickups() -> void:
	for data in [[Vector3(-7.4, 0, 34.3), Pickup.Kind.AMMO, PI * 0.5], [Vector3(11.5, 0, 7.8), Pickup.Kind.AMMO, 0.0],
			[Vector3(-13.3, 0, -16), Pickup.Kind.AMMO, PI * 0.5], [Vector3(-23.5, 0, -6), Pickup.Kind.AMMO, 0.0]]:
		var p := Pickup.new()
		p.kind = data[1]
		p.position = data[0]
		p.rotation.y = data[2]
		dynamic_root.add_child(p)
	var laptop := Pickup.new()
	laptop.kind = Pickup.Kind.INTEL
	laptop.intel_name = "laptop do General"
	laptop.position = Vector3(-9.5, 0.8, -33)
	dynamic_root.add_child(laptop)
	var drive := Pickup.new()
	drive.kind = Pickup.Kind.INTEL
	drive.intel_name = "HD do CFTV"
	drive.position = Vector3(12.2, 0.8, -37.3)
	dynamic_root.add_child(drive)
	for pk in [laptop, drive]:
		(pk as Pickup).collected.connect(func(_p: Pickup) -> void:
			hud.show_toast("Inteligência coletada (%d/%d)" % [int(GameManager.stats["intel"]), int(GameManager.stats["intel_total"])]))


func _setup_heli() -> void:
	heli = Helicopter.new()
	heli.name = "Viper21"
	dynamic_root.add_child(heli)
	heli.global_position = Vector3(-70, 7, 180)


func _on_nav_map_changed(map: RID) -> void:
	if map == nav_region.get_navigation_map():
		NavigationServer3D.map_changed.disconnect(_on_nav_map_changed)
		_validate_cover_points()


## Remove pontos de cobertura que ficaram fora do navmesh (dentro de obstáculos).
func _validate_cover_points() -> void:
	var map := nav_region.get_navigation_map()
	for node in get_tree().get_nodes_in_group("cover_point"):
		var cp := node as CoverPoint
		var closest := NavigationServer3D.map_get_closest_point(map, cp.global_position)
		if Vector2(closest.x - cp.global_position.x, closest.z - cp.global_position.z).length() > 0.6:
			cp.queue_free()
		else:
			cp.global_position = closest


# =========================================================================
# Objetivos e fluxo da missão
# =========================================================================

func _setup_objectives() -> void:
	var list: Array[Dictionary] = [
		{"id": "infiltrate", "title": "Infiltrar a Hacienda El Mirador", "marker": _breach_marker, "progress": "Evite os holofotes. Brecha no muro sul."},
		{"id": "courtyard", "title": "Eliminar a resistência no pátio", "marker": _courtyard_marker, "progress": ""},
		{"id": "capture", "title": "Capturar o HVT — General Salcedo", "marker": hvt, "progress": "Ele está na sala segura. NÃO o mate."},
		{"id": "extract", "title": "Escoltar o HVT até o heliponto", "marker": _helipad_marker, "progress": ""},
	]
	objectives.setup(list)
	# Gatilho: entrar no pátio conclui a infiltração
	var area := Area3D.new()
	area.collision_layer = Layers.TRIGGER
	area.collision_mask = Layers.PLAYER
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(62, 4, 20)
	cs.shape = shape
	area.add_child(cs)
	area.position = Vector3(0, 2, -1)
	dynamic_root.add_child(area)
	area.body_entered.connect(func(body: Node3D) -> void:
		# Confere a posição real (evita disparo espúrio no 1º frame, antes do spawn)
		if body is Player and not (body as Player).cinematic_mode and body.global_position.z < 9.6:
			objectives.complete("infiltrate"))


func _connect_signals() -> void:
	objectives.objective_started.connect(_on_objective_started)
	objectives.objective_completed.connect(func(_i: int, _o: Dictionary) -> void:
		hud.show_toast("CHECKPOINT SALVO"))
	objectives.all_completed.connect(_on_mission_success)
	player.died.connect(_on_player_died)
	StealthSystem.alarm_raised.connect(_on_alarm_raised)


func _begin() -> void:
	var cp: Array = CHECKPOINTS[start_stage]
	player.global_position = cp[0]
	player.set_view_yaw(deg_to_rad(float(cp[1])))
	if start_stage == Stage.EXTRACT:
		hvt.global_position = player.global_position + Vector3(0, 0, -1.5)
		hvt.set_captured(player)
	if start_stage == Stage.INFILTRATE and not GameManager.intro_seen:
		_play_intro()
	else:
		hud.fade_from_black(1.2)
		_send_heli_to_orbit()
	objectives.start_at(start_stage)


func _play_intro() -> void:
	_intro_active = true
	player.cinematic_mode = true
	pause_menu.set_enabled(false)
	var path: Array[Vector3] = [Vector3(-55, 6, 150), Vector3(-30, 5, 110), Vector3(-14, 4, 78), LZ_POS + Vector3(0, 2.4, 1.0)]
	var times: Array[float] = [5.0, 6.0, 5.5, 4.5]
	heli.fly_path(path, times)
	heli.flight_finished.connect(_end_intro, CONNECT_ONE_SHOT)
	player.set_view_yaw(deg_to_rad(-60.0), deg_to_rad(-8.0))
	hud.fade_from_black(2.0)
	hud.show_hint("[ENTER] Pular introdução")
	hud.show_radio("OVERLORD", "Todas as estações, aqui é Overlord. Operação Absolute Resolve em andamento.", 4.5)
	hud.show_radio("PILOTO", "Viper 2-1, mantendo dez metros sobre a água. Abaixo da cobertura de radar.", 4.5)
	hud.show_radio("CAP. REYES", "Lembrem-se: o alvo é o General Salcedo. Queremos ele VIVO.", 4.0)
	hud.show_radio("CAP. REYES", "Torres com holofotes nos cantos sul. Fiquem na vegetação.", 4.0)
	hud.show_radio("PILOTO", "Trinta segundos! Preparar para desembarque!", 3.5)


func _end_intro() -> void:
	if not _intro_active:
		return
	_intro_active = false
	GameManager.intro_seen = true
	heli.stop_flight()
	if heli.flight_finished.is_connected(_end_intro):
		heli.flight_finished.disconnect(_end_intro)
	heli.global_position = LZ_POS + Vector3(0, 2.4, 1.0)
	player.cinematic_mode = false
	pause_menu.set_enabled(true)
	player.global_position = LZ_POS
	player.set_view_yaw(deg_to_rad(200.0))
	hud.show_hint("")
	hud.clear_radio()
	hud.show_radio("CAP. REYES", "Vai, vai, vai! Silêncio até o muro — use a pistola suprimida.", 4.0)
	hud.show_radio("CAP. REYES", "Brecha no muro sul, lado oeste. Agachados e longe das luzes.", 4.0)
	_send_heli_to_orbit()


func _send_heli_to_orbit() -> void:
	var climb: Array[Vector3] = [heli.global_position + Vector3(-15, 25, 20)]
	var t: Array[float] = [6.0]
	heli.fly_path(climb, t)
	heli.flight_finished.connect(func() -> void:
		if not _extraction_started:
			heli.orbit(COMPOUND_CENTER, 85.0, 55.0, 0.06), CONNECT_ONE_SHOT)


func _on_objective_started(index: int, _obj: Dictionary) -> void:
	match index:
		Stage.INFILTRATE:
			pass
		Stage.CLEAR_COURTYARD:
			air_support.set_available(true)
			hud.show_radio("OVERLORD", "Viper 2-1 em órbita. Apoio aéreo disponível — marque alvos com [T].", 4.5)
			_update_courtyard_progress()
		Stage.CAPTURE_HVT:
			hud.show_radio("CAP. REYES", "Pátio limpo. Entrem na residência — CQB, sala por sala.", 4.0)
			hud.show_radio("CAP. REYES", "Sala segura no canto nordeste. Cuidado com o fogo: o HVT tem que sair vivo.", 4.5)
		Stage.EXTRACT:
			air_support.set_available(true)
			_start_extraction()


func _count_alive(stage: int) -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e and e.stage == stage and not e.is_dead:
			n += 1
	return n


func _update_courtyard_progress() -> void:
	var alive := _count_alive(Stage.CLEAR_COURTYARD)
	objectives.set_progress("courtyard", "Hostis restantes no pátio: %d" % alive)
	if alive == 0 and objectives.is_current("courtyard"):
		objectives.complete.call_deferred("courtyard")


func _on_enemy_died(enemy: Enemy) -> void:
	if enemy.stage == Stage.CLEAR_COURTYARD:
		_update_courtyard_progress.call_deferred()


func _on_hvt_captured() -> void:
	hud.show_radio("CAP. REYES", "JACKPOT, JACKPOT! HVT sob custódia!", 3.5)
	objectives.complete("capture")


func _start_extraction() -> void:
	_extraction_started = true
	hud.show_radio("OVERLORD", "Copiado Jackpot. Viper 2-1 a caminho do heliponto — ETA 45 segundos.", 4.5)
	hud.show_radio("OVERLORD", "Múltiplos veículos do cartel chegando pelo portão sul!", 4.0)
	objectives.set_progress("extract", "Aguarde o helicóptero e proteja o HVT.")
	# Reforços em duas ondas
	_spawn_reinforcements(0)
	var tw := create_tween()
	tw.tween_interval(18.0)
	tw.tween_callback(_spawn_reinforcements.bind(1))
	# Aproximação do helicóptero
	var approach: Array[Vector3] = [HELIPAD_POS + Vector3(30, 30, 40), HELIPAD_POS + Vector3(0, 14, 0), HELIPAD_POS + Vector3(0, 1.4, 0)]
	var times: Array[float] = [22.0, 16.0, 7.0]
	var heli_tw := create_tween()
	heli_tw.tween_interval(1.0)
	heli_tw.tween_callback(func() -> void:
		heli.fly_path(approach, times)
		heli.flight_finished.connect(_on_heli_landed, CONNECT_ONE_SHOT))


func _spawn_reinforcements(wave: int) -> void:
	if _mission_over:
		return
	var spawns: Array = []
	if wave == 0:
		spawns = [["militia", Vector3(6, 0, 20)], ["militia", Vector3(9, 0, 22)], ["militia", Vector3(11, 0, 19)],
			["guard", Vector3(7, 0, 24)]]
	else:
		spawns = [["elite", Vector3(-22.5, 0, -14)], ["elite", Vector3(-22.5, 0, -17)],
			["militia", Vector3(8, 0, 21)], ["guard", Vector3(22.5, 0, -16)]]
	for s in spawns:
		var e := _spawn(String(s[0]), s[1], Stage.EXTRACT, [], 0.0)
		if e:
			e.notify_contact.call_deferred(player.global_position)
	hud.show_toast("Reforços inimigos chegando!")


func _on_heli_landed() -> void:
	_heli_landed = true
	hud.show_radio("PILOTO", "Viper 2-1 no solo! Embarquem, embarquem!", 4.0)
	objectives.set_progress("extract", "Helicóptero no solo — leve o HVT até o heliponto!")


func _check_extraction() -> void:
	if not _heli_landed or hvt == null or hvt.is_dead:
		return
	var player_ok := Vector2(player.global_position.x - HELIPAD_POS.x, player.global_position.z - HELIPAD_POS.z).length() < 6.5
	var hvt_ok := hvt.get_distance_to(HELIPAD_POS) < 7.0
	if player_ok and hvt.state == HVTCharacter.State.FOLLOWING:
		var seat := heli.seat.global_position
		hvt.board(Vector3(seat.x, 0.0, seat.z))
	if player_ok and hvt_ok:
		objectives.complete("extract")


# =========================================================================
# Fim de missão
# =========================================================================

func _on_mission_success() -> void:
	if _mission_over:
		return
	_mission_over = true
	pause_menu.set_enabled(false)
	player.cinematic_mode = true
	hud.show_banner("JACKPOT", "General Salcedo capturado com vida. Extraindo...", 5.0)
	hud.show_radio("OVERLORD", "Viper 2-1 decolando com o pacote. Excelente trabalho, TRIDENT.", 4.0)
	hud.fade_to_black(3.5)
	var tw := create_tween()
	tw.tween_interval(4.0)
	tw.tween_callback(func() -> void:
		GameManager.finish_mission(true, "O General Rodrigo Salcedo foi capturado com vida e entregue às autoridades internacionais. " \
			+ "Mas o vácuo de poder em Valderrama está apenas começando..."))


func _on_player_died() -> void:
	_fail("KIA — o operador foi abatido em combate.")


func _on_hvt_killed() -> void:
	hud.show_radio("OVERLORD", "Overlord para todas as estações: o HVT está morto. Abortar, abortar.", 4.0)
	_fail("O HVT foi morto. A operação exigia a captura do General COM VIDA.")


func _fail(reason: String) -> void:
	if _mission_over:
		return
	_mission_over = true
	pause_menu.set_enabled(false)
	hud.show_banner("MISSÃO FALHOU", reason, 4.0)
	hud.fade_to_black(2.5)
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_callback(func() -> void: GameManager.finish_mission(false, reason))
