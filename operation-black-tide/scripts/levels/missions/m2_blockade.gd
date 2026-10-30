extends MissionLevel
## FASE 2 — "Linha Vermelha" (amanhecer)
## Bloqueio naval: retomar o posto de interdição no píer de Puerto Cardón,
## segurá-lo contra ondas do cartel vindas por terra e por mar, sabotar as
## lanchas de fuga e eliminar os remanescentes.

const POST := Vector3(0, 0, 30)
const LAND_SPAWNS := [Vector3(-20, 0, -40), Vector3(20, 0, -40), Vector3(0, 0, -42), Vector3(-42, 0, -22), Vector3(42, 0, -26)]
const PIER_SPAWNS := [Vector3(-3, 0, 58), Vector3(3, 0, 58), Vector3(0, 0, 56)]

var _escape_boats: Array[Node3D] = []


func environment_preset() -> String:
	return "dawn"


func nav_bounds() -> AABB:
	return AABB(Vector3(-52, -2, -48), Vector3(104, 14, 110))


func intro_lines() -> Array:
	return [
		["OVERLORD", "TRIDENT, o bloqueio começa agora. Ninguém sai de Puerto Cardón por mar.", 4.0],
		["CAP. REYES", "A milícia tomou nosso posto no píer. Vamos retomá-lo.", 3.5],
	]


func success_text() -> String:
	return "O bloqueio de Puerto Cardón se manteve. Nenhuma embarcação do cartel deixou o porto."


func build_world() -> void:
	ground(Vector2(104, 66), Vector3(0, 0, -13), Color(0.3, 0.29, 0.26), "concrete_yard", 20.0)
	sea(Vector3(0, 0, 200), Vector2(800, 420), -1.5)
	builder.box(Vector3(104, 1.5, 0.6), Vector3(0, -0.75, 20.3), builder.material("quay", Color(0.3, 0.29, 0.27)), false)
	# Píer
	builder.box(Vector3(12, 1.0, 41), Vector3(0, -0.5, 40), builder.material("pier", Color(0.28, 0.24, 0.2)))
	for z in [24.0, 36.0, 48.0, 59.0]:
		for x in [-5.8, 5.8]:
			builder.cylinder(0.3, 0.7, Vector3(x, 0, z), builder.material("metal", Color(0.12, 0.13, 0.12), 0.6, 0.4), true, 8)
	# Posto de interdição (anel de sacos de areia)
	sandbags(POST + Vector3(0, 0, -4), 5.0)
	sandbags(POST + Vector3(0, 0, 4), 5.0)
	sandbags(POST + Vector3(-4, 0, 0), 3.0, PI * 0.5)
	sandbags(POST + Vector3(4, 0, 0), 3.0, PI * 0.5)
	builder.box(Vector3(2.0, 2.4, 2.0), POST + Vector3(3.5, 1.2, 7.5), builder.material("booth", Color(0.4, 0.42, 0.35)))
	ammo_crate(POST + Vector3(-1.5, 0, 1.5))
	# Lanchas de fuga atracadas
	# Atracadas rente ao píer (sem balanço), com o convés quase no nível do píer
	_escape_boats.append(boat(Vector3(-8.0, -0.7, 45), 0.0, 9.0, Color(0.85, 0.85, 0.82), true, false))
	_escape_boats.append(boat(Vector3(8.0, -0.7, 52), 0.0, 9.0, Color(0.15, 0.2, 0.3), true, false))
	boat(Vector3(-30, -1.0, 70), 0.6, 12.0, Color(0.5, 0.5, 0.5), false)   # navio da Marinha ao fundo
	# Porto em terra
	house(Vector3(-30, 0, -10), Vector2(16, 12), 5.0, ["s", "e"], Color(0.45, 0.43, 0.38))
	house(Vector3(30, 0, -15), Vector2(14, 12), 5.0, ["s", "w"], Color(0.4, 0.42, 0.44))
	house(Vector3(0, 0, -30), Vector2(10, 8), 3.2, ["s"], Color(0.6, 0.58, 0.5))
	var colors := [Color(0.55, 0.12, 0.08), Color(0.1, 0.25, 0.45), Color(0.6, 0.45, 0.1)]
	for i in 6:
		container(Vector3(-16.0 + (i % 3) * 16.0, 0, 4.0 + float(i / 3) * 9.0), PI * 0.5, colors[i % 3])
	for p in [Vector3(-40, 0, 10), Vector3(40, 0, 8)]:
		builder.cylinder(3.0, 6.0, p, builder.material("tank", Color(0.7, 0.7, 0.68), 0.5, 0.4), true, 24)
	sandbags(Vector3(-8, 0, -6), 4.0)
	sandbags(Vector3(10, 0, -4), 4.0, 0.3)
	crates(Vector3(18, 0, 14))
	crates(Vector3(-20, 0, 15), 0.4)
	for p in [Vector3(-8, 0, 18), Vector3(8, 0, 18), Vector3(-20, 0, -20), Vector3(20, 0, -22)]:
		lamp(p, Color(1.0, 0.7, 0.4), 1.4, 9.0)
	ammo_crate(Vector3(-2, 0, -25))
	# Limites: terra + píer
	builder.collider(Vector3(106, 14, 1), Vector3(0, 7, -46))
	builder.collider(Vector3(1, 14, 66), Vector3(-52, 7, -13))
	builder.collider(Vector3(1, 14, 66), Vector3(52, 7, -13))
	builder.collider(Vector3(45, 14, 1), Vector3(-29.5, 7, 20.6))
	builder.collider(Vector3(45, 14, 1), Vector3(29.5, 7, 20.6))
	builder.collider(Vector3(1, 14, 41), Vector3(-6.4, 7, 40))
	builder.collider(Vector3(1, 14, 41), Vector3(6.4, 7, 40))
	builder.collider(Vector3(14, 14, 1), Vector3(0, 7, 60.7))


func define_objectives() -> Array[Dictionary]:
	var list: Array[Dictionary] = [
		{"type": "kill", "stage": 0, "title": "Retomar o posto de interdição no píer", "marker": POST,
			"checkpoint": [Vector3(-12, 0, -40), 165.0]},
		{"type": "defend", "title": "Manter o bloqueio no posto do píer", "pos": POST, "radius": 9.0, "duration": 120.0,
			"checkpoint": [POST, 0.0], "air": true,
			"radio": [["OVERLORD", "Posto retomado. Eles vão tentar romper o bloqueio — segurem por dois minutos.", 4.5],
				["OVERLORD", "Viper 2-1 em órbita. Apoio aéreo disponível [T].", 3.0]],
			"defend_waves": [
				{"time": 3.0, "spawns": [["militia", LAND_SPAWNS[0]], ["militia", LAND_SPAWNS[1]], ["guard", LAND_SPAWNS[2]], ["militia", LAND_SPAWNS[3]]]},
				{"time": 35.0, "spawns": [["militia", PIER_SPAWNS[0]], ["militia", PIER_SPAWNS[1]], ["guard", LAND_SPAWNS[4]], ["militia", LAND_SPAWNS[2]]]},
				{"time": 70.0, "spawns": [["elite", LAND_SPAWNS[0]], ["guard", LAND_SPAWNS[1]], ["militia", LAND_SPAWNS[3]], ["militia", LAND_SPAWNS[4]]]},
				{"time": 95.0, "spawns": [["militia", PIER_SPAWNS[0]], ["guard", PIER_SPAWNS[1]], ["elite", PIER_SPAWNS[2]]]},
			]},
		{"type": "interact", "title": "Sabotar as lanchas de fuga", "label": "Lanchas sabotadas", "detonate": "each",
			"checkpoint": [POST, 180.0], "air": true,
			"targets": [
				{"pos": Vector3(-6.9, -0.1, 45), "yaw": 90.0, "visual": ObjectiveInteractable.Visual.SATCHEL, "wreck": _escape_boats[0],
					"prompt": "Segure [E] para fixar a carga no casco da lancha", "hold": 2.0},
				{"pos": Vector3(6.9, -0.1, 52), "yaw": -90.0, "visual": ObjectiveInteractable.Visual.SATCHEL, "wreck": _escape_boats[1],
					"prompt": "Segure [E] para fixar a carga no casco da lancha", "hold": 2.0},
			],
			"waves": [{"spawns": [["militia", PIER_SPAWNS[2]], ["militia", LAND_SPAWNS[2]]]}],
			"radio": [["CAP. REYES", "As lanchas no píer ainda podem fugir. Cargas nelas — 5 segundos de espoleta, afastem-se!", 4.5]]},
		{"type": "kill", "stage": 3, "title": "Eliminar os remanescentes no porto", "marker": Vector3(0, 0, -10),
			"checkpoint": [Vector3(0, 0, 22), 180.0], "air": true,
			"waves": [{"spawns": [["militia", LAND_SPAWNS[0]], ["guard", LAND_SPAWNS[1]], ["militia", LAND_SPAWNS[3]], ["elite", LAND_SPAWNS[4]]]}],
			"radio": [["OVERLORD", "Lanchas no fundo. Últimos hostis recuando para os armazéns — limpem a área.", 4.0]]},
	]
	return list


func spawn_enemies() -> void:
	spawn_enemy("militia", POST + Vector3(-2, 0, -1), 0, [], 0.0)
	spawn_enemy("militia", POST + Vector3(2, 0, 2), 0, [], 180.0)
	spawn_enemy("guard", Vector3(-3, 0, 22), 0, [], 0.0)
	spawn_enemy("militia", Vector3(4, 0, 15), 0, [Vector3(4, 0, 15), Vector3(-10, 0, 12)])
	spawn_enemy("militia", Vector3(0, 0, 45), 0, [], 0.0)
