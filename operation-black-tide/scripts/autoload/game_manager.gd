extends Node
## GameManager (autoload)
## Estado global do jogo: configurações, missão atual, checkpoints,
## estatísticas e troca de cenas. Também registra o mapa de controles
## em tempo de execução (assim o project.godot fica enxuto e legível).

signal settings_changed

const MAIN_MENU_SCENE := "res://scenes/menus/main_menu.tscn"
const MISSION_END_SCENE := "res://scenes/menus/mission_end.tscn"
const SETTINGS_PATH := "user://settings.cfg"

# --- Configurações do jogador -------------------------------------------
var mouse_sensitivity: float = 1.0
var master_volume: float = 0.8
var field_of_view: float = 75.0
## 0 = Baixo, 1 = Médio, 2 = Alto (ver GraphicsQuality). -1 = detectar na 1ª execução.
var graphics_quality: int = -1
var show_fps: bool = false
## Equipamento escolhido no briefing (caminhos dos WeaponData).
const WEAPONS := [
	"res://resources/weapons/m4a1.tres",
	"res://resources/weapons/ak47.tres",
	"res://resources/weapons/p226_sd.tres",
	"res://resources/weapons/p226.tres",
	"res://resources/weapons/mp5sd.tres",
	"res://resources/weapons/m4_shotgun.tres",
	"res://resources/weapons/m24.tres",
	"res://resources/weapons/m249.tres",
	"res://resources/weapons/glock.tres",
	"res://resources/weapons/deagle.tres",
]
var primary_weapon: String = "res://resources/weapons/m4a1.tres"
var secondary_weapon: String = "res://resources/weapons/p226_sd.tres"
## Cor das mãos em primeira pessoa (índice de HAND_STYLES).
var hand_style: int = 0
const HAND_STYLES := [
	["Luva preta", Color(0.075, 0.072, 0.065)],
	["Luva coyote", Color(0.42, 0.33, 0.22)],
	["Luva verde", Color(0.2, 0.23, 0.15)],
	["Pele clara", Color(0.86, 0.66, 0.53)],
	["Pele morena", Color(0.6, 0.42, 0.3)],
	["Pele escura", Color(0.32, 0.21, 0.15)],
]

# --- Estado da missão -----------------------------------------------------
var current_mission_id: String = ""
## Índice do último checkpoint alcançado (== índice do objetivo a retomar).
var checkpoint_index: int = 0
## A introdução de helicóptero só toca na primeira tentativa.
var intro_seen: bool = false
var stats: Dictionary = {}
## Preenchido ao final da missão para a tela de resultado.
var last_result: Dictionary = {}
## IDs das missões já concluídas (salvo junto com as configurações).
var completed_missions: PackedStringArray = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input_map()
	load_settings()
	reset_stats()


# =========================================================================
# Fluxo de missão
# =========================================================================

func start_mission(mission_id: String) -> void:
	var mission := Campaign.get_mission(mission_id)
	if mission.is_empty() or String(mission.get("scene", "")) == "":
		push_warning("Missão '%s' ainda não é jogável." % mission_id)
		return
	current_mission_id = mission_id
	checkpoint_index = 0
	intro_seen = false
	reset_stats()
	_change_scene(String(mission["scene"]))


## Recarrega a missão atual a partir do último checkpoint salvo.
func restart_from_checkpoint() -> void:
	var mission := Campaign.get_mission(current_mission_id)
	if mission.is_empty():
		go_to_main_menu()
		return
	stats["restarts"] = int(stats.get("restarts", 0)) + 1
	_change_scene(String(mission["scene"]))


func set_checkpoint(index: int) -> void:
	checkpoint_index = maxi(checkpoint_index, index)


func finish_mission(success: bool, reason: String = "") -> void:
	var elapsed := (Time.get_ticks_msec() - int(stats.get("start_msec", 0))) / 1000.0
	last_result = {
		"success": success,
		"reason": reason,
		"mission_id": current_mission_id,
		"stats": stats.duplicate(),
		"elapsed": elapsed,
	}
	_change_scene(MISSION_END_SCENE)


func mark_mission_completed(mission_id: String) -> void:
	if not completed_missions.has(mission_id):
		completed_missions.append(mission_id)
		save_settings()


func is_mission_completed(mission_id: String) -> bool:
	return completed_missions.has(mission_id)


## Próxima missão jogável na ordem da campanha (ou "" se for a última).
func get_next_mission(mission_id: String) -> String:
	var ids: Array[String] = []
	for phase in Campaign.PHASES:
		for mission in phase["missions"]:
			if String(mission["scene"]) != "":
				ids.append(String(mission["id"]))
	var i := ids.find(mission_id)
	return ids[i + 1] if i >= 0 and i + 1 < ids.size() else ""


func go_to_main_menu() -> void:
	_change_scene(MAIN_MENU_SCENE)


func reset_stats() -> void:
	stats = {
		"kills": 0,
		"headshots": 0,
		"shots_fired": 0,
		"shots_hit": 0,
		"times_detected": 0,
		"intel": 0,
		"intel_total": 2,
		"restarts": 0,
		"start_msec": Time.get_ticks_msec(),
	}


func add_stat(key: String, amount: int = 1) -> void:
	stats[key] = int(stats.get(key, 0)) + amount


func _change_scene(path: String) -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	StealthSystem.reset()
	get_tree().change_scene_to_file.call_deferred(path)


# =========================================================================
# Configurações
# =========================================================================

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		mouse_sensitivity = float(cfg.get_value("controls", "mouse_sensitivity", mouse_sensitivity))
		master_volume = float(cfg.get_value("audio", "master_volume", master_volume))
		field_of_view = float(cfg.get_value("video", "field_of_view", field_of_view))
		completed_missions = PackedStringArray(cfg.get_value("progress", "completed_missions", PackedStringArray()))
		graphics_quality = int(cfg.get_value("video", "graphics_quality", -1))
		show_fps = bool(cfg.get_value("video", "show_fps", false))
		hand_style = clampi(int(cfg.get_value("video", "hand_style", 0)), 0, HAND_STYLES.size() - 1)
		primary_weapon = _valid_weapon(String(cfg.get_value("loadout", "primary", primary_weapon)), "primary")
		secondary_weapon = _valid_weapon(String(cfg.get_value("loadout", "secondary", secondary_weapon)), "secondary")
	if graphics_quality < 0:
		graphics_quality = GraphicsQuality.detect_default()
	apply_settings()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("video", "field_of_view", field_of_view)
	cfg.set_value("progress", "completed_missions", completed_missions)
	cfg.set_value("video", "graphics_quality", graphics_quality)
	cfg.set_value("video", "show_fps", show_fps)
	cfg.set_value("video", "hand_style", hand_style)
	cfg.set_value("loadout", "primary", primary_weapon)
	cfg.set_value("loadout", "secondary", secondary_weapon)
	cfg.save(SETTINGS_PATH)


## Armas disponíveis para um slot ("primary" / "secondary").
func weapons_for_slot(slot: String) -> Array[WeaponData]:
	var list: Array[WeaponData] = []
	for path in WEAPONS:
		var d := load(path) as WeaponData
		if d and d.slot == slot:
			list.append(d)
	return list


func _valid_weapon(path: String, slot: String) -> String:
	if path in WEAPONS and (load(path) as WeaponData).slot == slot:
		return path
	return weapons_for_slot(slot)[0].resource_path


func hand_color() -> Color:
	return HAND_STYLES[hand_style][1]


func apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	settings_changed.emit()


# =========================================================================
# Mapa de controles
# =========================================================================

func _setup_input_map() -> void:
	_bind_keys("move_forward", [KEY_W, KEY_UP])
	_bind_keys("move_back", [KEY_S, KEY_DOWN])
	_bind_keys("move_left", [KEY_A, KEY_LEFT])
	_bind_keys("move_right", [KEY_D, KEY_RIGHT])
	_bind_keys("jump", [KEY_SPACE])
	_bind_keys("sprint", [KEY_SHIFT])
	_bind_keys("crouch", [KEY_C, KEY_CTRL])
	_bind_keys("reload", [KEY_R])
	_bind_keys("interact", [KEY_E])
	_bind_keys("weapon_1", [KEY_1])
	_bind_keys("weapon_2", [KEY_2])
	_bind_keys("switch_weapon", [KEY_Q])
	_bind_keys("fire_mode", [KEY_B])
	_bind_keys("flashlight", [KEY_F])
	_bind_keys("nvg", [KEY_N])
	_bind_keys("air_support", [KEY_T])
	_bind_keys("skip_intro", [KEY_ENTER, KEY_KP_ENTER])
	_bind_keys("pause", [KEY_ESCAPE, KEY_P])
	_bind_mouse("fire", MOUSE_BUTTON_LEFT)
	_bind_mouse("aim", MOUSE_BUTTON_RIGHT)
	_bind_mouse("next_weapon", MOUSE_BUTTON_WHEEL_DOWN)
	_bind_mouse("prev_weapon", MOUSE_BUTTON_WHEEL_UP)


func _bind_keys(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)


func _bind_mouse(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
