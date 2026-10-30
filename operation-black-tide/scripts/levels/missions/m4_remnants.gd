extends MissionLevel
## FASE 4 — "Brasas" (manhã nublada)
## Após a queda do General, o Cartel del Mar tenta ocupar o vácuo de poder.
## Destruir os laboratórios de cocaína de Las Cenizas, eliminar o chefe local
## "El Tiburón" e segurar a zona de pouso até o helicóptero chegar.

const START := Vector3(44, 0, 44)
const LABS := [Vector3(-26, 0, -18), Vector3(26, 0, -12), Vector3(2, 0, 26)]
## Bancada de cada laboratório (relativa ao barraco), onde vai a carga
const BENCHES := [Vector3(-1.5, 0, -1.5), Vector3(1.5, 0, -1.5), Vector3(2.0, 0, 0)]
const MAIN_HOUSE := Vector3(0, 0, -28)
const LZ := Vector3(-32, 0, 34)


func environment_preset() -> String:
	return "overcast"


func nav_bounds() -> AABB:
	return AABB(Vector3(-52, -2, -52), Vector3(104, 14, 104))


func intro_lines() -> Array:
	return [
		["OVERLORD", "Salcedo caiu, mas o Cartel del Mar está se reorganizando em Las Cenizas.", 4.0],
		["CAP. REYES", "Três laboratórios e um chefe: El Tiburón. Queimamos tudo e saímos.", 4.0],
	]


func success_text() -> String:
	return "Os laboratórios de Las Cenizas viraram cinzas e El Tiburón está morto. Valderrama começa a respirar."


func build_world() -> void:
	ground(Vector2(106, 106), Vector3.ZERO, Color(0.22, 0.2, 0.14), "dirt")
	var path := builder.material("road", Color(0.27, 0.23, 0.17))
	builder.box(Vector3(4, 0.02, 90), Vector3(0, 0.012, 0), path, false, 0.6)
	builder.box(Vector3(70, 0.02, 4), Vector3(0, 0.012, 2), path, false)
	scatter_jungle(Rect2(-52, -52, 104, 12), 34)
	scatter_jungle(Rect2(-52, 40, 82, 12), 16, [Rect2(-42, 24, 20, 20)])
	scatter_jungle(Rect2(-52, -40, 12, 80), 18, [Rect2(-52, 24, 30, 20)])
	scatter_jungle(Rect2(40, -40, 12, 76), 18)
	scatter_jungle(Rect2(-30, -10, 60, 30), 7, [Rect2(-14, -10, 28, 22), Rect2(-6, 16, 16, 16), Rect2(18, -18, 16, 14),
		Rect2(-30, 10, 12, 12), Rect2(18, 14, 12, 12), Rect2(-20, -10, 8, 8)], 0.7)
	# Laboratórios (barracos com tambores de químicos)
	var doors := ["e", "w", "n"]
	for i in LABS.size():
		house(LABS[i], Vector2(7, 6), 2.8, [doors[i]], Color(0.42, 0.36, 0.28), true, false)
		# Bancada com vidraria do laboratório
		var bench: Vector3 = LABS[i] + BENCHES[i]
		builder.box(Vector3(1.6, 0.85, 0.8), bench + Vector3.UP * 0.425, builder.material("bench", Color(0.3, 0.24, 0.16)))
		for k in 3:
			builder.cylinder(0.06, 0.22, bench + Vector3(-0.55 + k * 0.22, 0.85, 0.15),
				builder.material("glassware", Color(0.6, 0.75, 0.7), 0.1, 0.2), false, 8)
		for j in 3:
			builder.cylinder(0.3, 0.95, LABS[i] + Vector3(-2.4 + j * 0.7, 0, 2.0), builder.material("drum_blue", Color(0.1, 0.25, 0.5), 0.6, 0.3), true, 10)
	# Casa principal de El Tiburón
	house(MAIN_HOUSE, Vector2(14, 10), 3.4, ["s", "e"], Color(0.8, 0.78, 0.7))
	builder.cover_obstacle(Vector3(2.6, 0.85, 0.9), MAIN_HOUSE + Vector3(-3, 0.425, 0), builder.material("fabric", Color(0.3, 0.08, 0.08)))
	builder.cover_obstacle(Vector3(1.8, 0.8, 1.0), MAIN_HOUSE + Vector3(3.5, 0.4, -2), builder.material("furniture", Color(0.2, 0.13, 0.08)))
	sandbags(MAIN_HOUSE + Vector3(-4, 0, 8), 4.0)
	sandbags(MAIN_HOUSE + Vector3(5, 0, 9), 3.0, 0.4)
	# Barracos, caminhonetes e cobertura espalhada
	house(Vector3(-24, 0, 16), Vector2(6, 5), 2.8, ["e"], Color(0.5, 0.42, 0.3), false, false)
	house(Vector3(24, 0, 22), Vector2(7, 5), 2.8, ["w"], Color(0.45, 0.4, 0.33), false, false)
	for t in [[Vector3(-10, 0, 8), 0.4], [Vector3(14, 0, -2), -0.3], [Vector3(-14, 0, -32), 1.2]]:
		builder.cover_obstacle(Vector3(2.0, 1.6, 4.8), (t[0] as Vector3) + Vector3.UP * 0.8,
			builder.material("truck", Color(0.3, 0.3, 0.28)), float(t[1]), true)
	crates(Vector3(8, 0, 12), 0.2)
	crates(Vector3(-16, 0, -6), -0.5)
	crates(Vector3(32, 0, 6), 1.0)
	# Zona de pouso
	builder.cylinder(5.0, 0.04, LZ, builder.material("lz_mark", Color(0.35, 0.33, 0.25)), false, 24)
	builder.box(Vector3(3, 0.02, 0.4), LZ + Vector3(0, 0.05, 0), builder.material("lz_paint", Color(0.8, 0.75, 0.2)), false)
	builder.box(Vector3(0.4, 0.02, 3), LZ + Vector3(0, 0.05, 0), builder.material("lz_paint", Color()), false)
	sandbags(LZ + Vector3(6, 0, -4), 3.0, 0.8)
	sandbags(LZ + Vector3(-1, 0, -7), 3.0)
	ammo_crate(START + Vector3(-3, 0, -3))
	ammo_crate(LZ + Vector3(3, 0, -6))
	ammo_crate(Vector3(12, 0, 4))
	boundary(Vector2(-52, -52), Vector2(52, 52))


func define_objectives() -> Array[Dictionary]:
	var targets: Array = []
	for i in LABS.size():
		targets.append({"pos": LABS[i] + BENCHES[i] + Vector3(0.3, 0.85, -0.1), "visual": ObjectiveInteractable.Visual.SATCHEL, "hold": 2.0,
			"prompt": "Segure [E] para plantar a carga incendiária no laboratório"})
	var list: Array[Dictionary] = [
		{"type": "interact", "title": "Destruir os laboratórios do cartel", "label": "Laboratórios destruídos",
			"detonate": "each", "targets": targets, "checkpoint": [START, 45.0], "air": true,
			"radio": [["CAP. REYES", "Cada carga tem 5 segundos de espoleta. Plantem e saiam do barraco!", 4.0],
				["OVERLORD", "Viper 2-1 cobrindo a área. Apoio aéreo disponível [T].", 3.0]]},
		{"type": "kill", "stage": 1, "title": "Eliminar El Tiburón e sua guarda", "marker": MAIN_HOUSE,
			"checkpoint": [Vector3(18, 0, 8), 300.0], "air": true,
			"radio": [["OVERLORD", "El Tiburón está na casa branca ao norte. Ele não sai vivo de lá.", 4.0]]},
		{"type": "defend", "title": "Segurar a zona de pouso até o helicóptero chegar", "pos": LZ, "radius": 8.0,
			"duration": 75.0, "checkpoint": [LZ + Vector3(4, 0, -10), 200.0], "air": true,
			"radio": [["PILOTO", "Viper 2-1 a caminho, 75 segundos! Segurem a LZ!", 3.5]],
			"defend_waves": [
				{"time": 4.0, "spawns": [["militia", Vector3(-46, 0, -10)], ["militia", Vector3(-46, 0, -4)], ["militia", Vector3(0, 0, -46)]]},
				{"time": 30.0, "spawns": [["guard", Vector3(46, 0, 10)], ["militia", Vector3(46, 0, 0)], ["elite", Vector3(-20, 0, -46)]]},
				{"time": 52.0, "spawns": [["militia", Vector3(-46, 0, 0)], ["militia", Vector3(-46, 0, 10)], ["elite", Vector3(10, 0, -46)], ["guard", Vector3(20, 0, -46)]]},
			]},
	]
	return list


func spawn_enemies() -> void:
	# Guardas dos laboratórios
	spawn_enemy("militia", LABS[0] + Vector3(5, 0, 2), 0, [], 90.0)
	spawn_enemy("militia", LABS[0] + Vector3(0, 0, 5), 0, [LABS[0] + Vector3(0, 0, 5), LABS[0] + Vector3(12, 0, 8)])
	spawn_enemy("militia", LABS[1] + Vector3(-5, 0, 1), 0, [], 270.0)
	spawn_enemy("guard", LABS[1] + Vector3(2, 0, 6), 0, [LABS[1] + Vector3(2, 0, 6), LABS[1] + Vector3(-10, 0, 14)])
	spawn_enemy("militia", LABS[2] + Vector3(0, 0, -5), 0, [], 0.0)
	spawn_enemy("militia", LABS[2] + Vector3(-6, 0, -2), 0, [], 300.0)
	spawn_enemy("guard", Vector3(-8, 0, 2), 0, [Vector3(-20, 0, 2), Vector3(20, 0, 2)])
	spawn_enemy("militia", Vector3(-24, 0, 22), 0, [], 180.0)
	# El Tiburón e a guarda pessoal
	var boss := spawn_enemy("elite", MAIN_HOUSE + Vector3(2, 0, -1.5), 1, [], 180.0, boss_profile("elite", "El Tiburón", 420.0))
	if boss:
		objective_defs[1]["marker"] = boss
	spawn_enemy("elite", MAIN_HOUSE + Vector3(-4, 0, 2), 1, [], 180.0)
	spawn_enemy("guard", MAIN_HOUSE + Vector3(-3, 0, 9.5), 1, [], 180.0)
	spawn_enemy("guard", MAIN_HOUSE + Vector3(6, 0, 10.5), 1, [], 160.0)
	spawn_enemy("militia", MAIN_HOUSE + Vector3(9, 0, 2), 1, [MAIN_HOUSE + Vector3(9, 0, 2), MAIN_HOUSE + Vector3(-9, 0, 7)])
