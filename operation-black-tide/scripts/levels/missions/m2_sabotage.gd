extends MissionLevel
## FASE 2 — "Céu Cego" (noite)
## Sabotagem da estação de radar costeiro de Punta Herrera: destruir os
## transformadores da subestação (a base fica às escuras), invadir a sala de
## controle para desligar o radar e fugir até o ponto de extração.

const START := Vector3(-44, 0, 42)
const SUBSTATION := Vector3(-15, 0, -12)
const CONTROL := Vector3(15, 0, -16)   # prédio de controle (12 x 10)
const EXFIL := Vector3(-46, 0, -44)

var _station_lights: Array[Light3D] = []


func environment_preset() -> String:
	return "night"


func nav_bounds() -> AABB:
	return AABB(Vector3(-52, -2, -52), Vector3(104, 14, 104))


func intro_lines() -> Array:
	return [
		["OVERLORD", "O radar de Punta Herrera cobre todo o corredor aéreo para a Fase 3. Precisamos dele cego.", 4.5],
		["CAP. REYES", "Primeiro a subestação: sem energia, sem luzes, sem radar.", 4.0],
	]


func success_text() -> String:
	return "O radar de Punta Herrera está fora do ar. O corredor aéreo para a Operação Absolute Resolve está aberto."


func build_world() -> void:
	ground(Vector2(106, 106), Vector3.ZERO, Color(0.14, 0.15, 0.11))
	var wall := builder.material("compound_wall", Color(0.4, 0.37, 0.33))
	# Muro da estação (x -32..32, z -34..22) com portão sul e brecha a oeste
	builder.wall_x(-32, 32, 22, 3.2, 0.5, wall, [Vector4(0, 6, 0, 3.2)])
	builder.wall_x(-32, 32, -34, 3.2, 0.5, wall)
	builder.wall_z(-34, 22, -32, 3.2, 0.5, wall, [Vector4(8, 2.4, 0, 3.2)])
	builder.wall_z(-34, 22, 32, 3.2, 0.5, wall)
	scatter_jungle(Rect2(-52, 26, 104, 26), 40, [Rect2(-50, 34, 14, 14), Rect2(-6, 24, 12, 28)])
	scatter_jungle(Rect2(-52, -52, 18, 104), 26, [Rect2(-52, -50, 14, 14), Rect2(-40, 2, 8, 14)])
	scatter_jungle(Rect2(36, -52, 16, 104), 18)
	# Subestação: transformadores atrás de uma cerca
	var fence := builder.material("fence", Color(0.3, 0.3, 0.3), 0.7, 0.5)
	builder.box(Vector3(14, 2.2, 0.15), SUBSTATION + Vector3(0, 1.1, -4), fence)
	builder.box(Vector3(0.15, 2.2, 8), SUBSTATION + Vector3(-7, 1.1, 0), fence)
	builder.box(Vector3(0.15, 2.2, 8), SUBSTATION + Vector3(7, 1.1, 0), fence)
	for x in [-5.0, 0.0, 5.0]:
		builder.box(Vector3(0.3, 6, 0.3), SUBSTATION + Vector3(x, 3, -3), builder.material("metal", Color(0.12, 0.13, 0.12), 0.6, 0.4), false)
	builder.box(Vector3(14, 0.2, 0.2), SUBSTATION + Vector3(0, 5.8, -3), builder.material("metal", Color()), false)
	# Prédio de controle e antena do radar
	house(CONTROL, Vector2(12, 10), 3.5, ["s", "w"], Color(0.62, 0.62, 0.6))
	builder.cover_obstacle(Vector3(4, 1.0, 0.8), CONTROL + Vector3(0, 0.5, -2), builder.material("console", Color(0.15, 0.16, 0.18)))
	var radar_base := CONTROL + Vector3(0, 0, 14)
	builder.cylinder(1.2, 8.0, radar_base, builder.material("concrete", Color(0.45, 0.44, 0.42)), true, 16)
	var dish := Node3D.new()
	dish.position = radar_base + Vector3(0, 8.6, 0)
	dynamic_root.add_child(dish)
	_mesh(dish, Vector3(9, 3.5, 0.4), Vector3(0, 0.8, -0.6), Color(0.85, 0.85, 0.82)).rotation.x = -0.35
	_mesh(dish, Vector3(0.4, 1.4, 0.4), Vector3.ZERO, Color(0.3, 0.3, 0.3))
	spinner(dish, 0.8)
	# Quartel e cobertura no pátio
	house(Vector3(-20, 0, 10), Vector2(14, 8), 3.2, ["s", "e"], Color(0.5, 0.48, 0.4))
	sandbags(Vector3(0, 0, 16), 4.0)
	sandbags(Vector3(-4, 0, -2), 3.0, 0.5)
	sandbags(Vector3(8, 0, 2), 3.0, -0.4)
	crates(Vector3(24, 0, 6))
	crates(Vector3(-2, 0, -26), 0.3)
	for side in [-1.0, 1.0]:
		builder.cover_obstacle(Vector3(2.0, 1.5, 4.6), Vector3(side * 8 + 4, 0.75, 8), builder.material("truck", Color(0.18, 0.2, 0.15)), 0.2 * side, true)
	# Torre de vigia com holofote no canto sudeste
	var tower := Vector3(28, 0, 18)
	var wood := builder.material("tower_wood", Color(0.2, 0.15, 0.1))
	for off in [Vector3(-1.4, 0, -1.4), Vector3(1.4, 0, -1.4), Vector3(-1.4, 0, 1.4), Vector3(1.4, 0, 1.4)]:
		builder.box(Vector3(0.3, 5.5, 0.3), tower + off + Vector3.UP * 2.75, wood)
	builder.box(Vector3(3.4, 0.3, 3.4), tower + Vector3.UP * 5.5, wood)
	for e in [Vector3(0, 6.1, 1.65), Vector3(0, 6.1, -1.65)]:
		builder.box(Vector3(3.4, 0.95, 0.1), tower + e, wood)
	for e in [Vector3(1.65, 6.1, 0), Vector3(-1.65, 6.1, 0)]:
		builder.box(Vector3(0.1, 0.95, 3.4), tower + e, wood)
	# Iluminação da base (apaga quando a subestação explode)
	for p in [Vector3(-10, 0, 18), Vector3(12, 0, 18), Vector3(-26, 0, -6), Vector3(4, 0, -10), Vector3(26, 0, -2), Vector3(-8, 0, -28)]:
		_station_lights.append(lamp(p, Color(1.0, 0.62, 0.3), 2.2, 11.0))
	_station_lights.append(builder.spot(Vector3(0, 3.5, 22.4), Vector3(0, 0, 40), Color(0.9, 0.95, 1.0), 5.0, 30.0, 32.0))
	_station_lights.append(builder.omni(CONTROL + Vector3(0, 3.0, 0), Color(0.7, 0.85, 1.0), 1.0, 8.0))
	for p in [Vector3(0, 3.4, 22.6), CONTROL + Vector3(0, 3.8, 5.3), Vector3(-20, 3.4, 14.3), tower + Vector3(0, 8, 0)]:
		alarm_light(p)
	add_siren(CONTROL + Vector3(0, 4, 0))
	ammo_crate(START + Vector3(2, 0, -2))
	ammo_crate(Vector3(-24, 0, 14.5))
	ammo_crate(CONTROL + Vector3(-4.5, 0, 3.5))
	boundary(Vector2(-52, -52), Vector2(52, 52))


func define_objectives() -> Array[Dictionary]:
	var charge := ObjectiveInteractable.Visual.CHARGE
	var list: Array[Dictionary] = [
		{"type": "interact", "title": "Plantar cargas nos transformadores da subestação", "label": "Cargas plantadas",
			"detonate": "all", "checkpoint": [START, 315.0],
			"targets": [
				{"pos": SUBSTATION + Vector3(-4.5, 0, 0), "yaw": 180.0, "visual": charge, "prompt": "Segure [E] para plantar a carga no transformador", "hold": 2.0},
				{"pos": SUBSTATION + Vector3(0, 0, 0), "yaw": 180.0, "visual": charge, "prompt": "Segure [E] para plantar a carga no transformador", "hold": 2.0},
				{"pos": SUBSTATION + Vector3(4.5, 0, 0), "yaw": 180.0, "visual": charge, "prompt": "Segure [E] para plantar a carga no transformador", "hold": 2.0},
			],
			"radio": [["CAP. REYES", "Entrem pela brecha no muro oeste. A subestação fica no lado norte do pátio.", 4.0]]},
		{"type": "interact", "title": "Desligar o radar na sala de controle", "label": "Radar",
			"checkpoint": [Vector3(-12, 0, 2), 90.0], "air": true, "on_start": _blackout,
			"targets": [{"pos": CONTROL + Vector3(2.5, 0, -4.2), "visual": ObjectiveInteractable.Visual.TERMINAL,
				"prompt": "Segure [E] para desligar o radar e apagar os registros", "hold": 3.0}],
			"waves": [{"spawns": [["guard", Vector3(-20, 0, 15)], ["militia", Vector3(-16, 0, 15)]]}],
			"radio": [["CAP. REYES", "Base às escuras. Óculos de visão noturna [N]! Sala de controle a leste.", 4.0]]},
		{"type": "reach", "title": "Fugir até o ponto de extração", "pos": EXFIL, "radius": 5.0,
			"checkpoint": [CONTROL + Vector3(-8, 0, 7), 230.0], "air": true,
			"waves": [{"spawns": [["militia", Vector3(46, 0, 30)], ["militia", Vector3(46, 0, 34)], ["elite", Vector3(0, 0, 40)], ["guard", Vector3(4, 0, 44)]]}],
			"radio": [["OVERLORD", "Radar fora do ar! Reforços vindo pela estrada sul. Saiam pelo noroeste.", 4.0]]},
	]
	return list


## Ao explodir a subestação: luzes da base apagam (só as de alarme ficam).
func _blackout() -> void:
	for l in _station_lights:
		if is_instance_valid(l):
			l.visible = false
	StealthSystem.raise_alarm(SUBSTATION)


func spawn_enemies() -> void:
	spawn_enemy("guard", Vector3(-6, 0, 25), 0, [Vector3(-6, 0, 25), Vector3(6, 0, 25)], 180.0)
	spawn_enemy("guard", Vector3(-24, 0, -20), 0, [Vector3(-24, 0, -20), Vector3(-24, 0, 4), Vector3(-6, 0, -20)])
	spawn_enemy("elite", SUBSTATION + Vector3(0, 0, 4), 0, [], 180.0)
	spawn_enemy("militia", Vector3(4, 0, 12), 0, [], 180.0)
	spawn_enemy("guard", Vector3(10, 0, -4), 0, [Vector3(10, 0, -4), Vector3(26, 0, 10)])
	spawn_enemy("militia", Vector3(-20, 0, 10), 0, [], 90.0)
	var tower_guard := spawn_enemy("guard", Vector3(28, 5.75, 18), 0, [], 180.0, null, false)
	if tower_guard:
		var light := Searchlight.new()
		light.owner_enemy = tower_guard
		light.position = Vector3(28, 6.9, 19.4)
		light.base_yaw = PI + 0.6
		dynamic_root.add_child(light)
	spawn_enemy("elite", CONTROL + Vector3(-2, 0, 1), 1, [], 180.0)
	spawn_enemy("elite", CONTROL + Vector3(3, 0, 2.5), 1, [], 270.0)
	spawn_enemy("guard", CONTROL + Vector3(-8, 0, 7), 1, [], 270.0)
