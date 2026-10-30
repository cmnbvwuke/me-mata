extends MissionLevel
## FASE 1 — "Maré Baixa" (noite)
## Abordagem (VBSS) ao cargueiro de bandeira falsa "Estrella del Sur":
## limpar o convés entre os contêineres, tomar a ponte de comando, cortar as
## máquinas e segurar a proa até a lancha da Marinha encostar.
## O convés fica em y = 0 (o "chão" do mapa); o mar está 7 m abaixo.

const HALF_W := 8.0      # meia largura do convés
const HALF_L := 45.0     # meio comprimento
const SUPER_Z0 := 24.0   # superestrutura (ponte) entre z 24 e 36
const SUPER_Z1 := 36.0


func environment_preset() -> String:
	return "night"


func nav_bounds() -> AABB:
	return AABB(Vector3(-10, -2, -48), Vector3(20, 10, 96))


func intro_lines() -> Array:
	return [
		["PILOTO", "Sobre o cargueiro. Cordas fora — descida rápida na popa!", 3.5],
		["CAP. REYES", "Tripulação armada no convés. Limpem os contêineres, depois a ponte.", 4.5],
	]


func success_text() -> String:
	return "O \"Estrella del Sur\" foi tomado com 4 toneladas de cocaína a bordo. A tripulação está sob custódia da Marinha."


func build_world() -> void:
	var steel := builder.material("ship_steel", Color(0.2, 0.22, 0.24), 0.8, 0.5)
	var hull := builder.material("ship_hull", Color(0.32, 0.08, 0.06), 0.7, 0.3)
	var deck := builder.material("ship_deck", Color(0.24, 0.25, 0.22))
	sea(Vector3(0, 0, 0), Vector2(900, 900), -7.0)
	# Convés (chão jogável) e casco visual
	builder.box(Vector3(HALF_W * 2, 1.0, HALF_L * 2), Vector3(0, -0.5, 0), deck)
	builder.box(Vector3(0.5, 7, HALF_L * 2), Vector3(-HALF_W - 0.25, -3.5, 0), hull, false)
	builder.box(Vector3(0.5, 7, HALF_L * 2), Vector3(HALF_W + 0.25, -3.5, 0), hull, false)
	builder.box(Vector3(HALF_W * 2 + 1, 7, 0.5), Vector3(0, -3.5, HALF_L + 0.25), hull, false)
	builder.box(Vector3(HALF_W * 1.2, 7, 0.5), Vector3(0, -3.5, -HALF_L - 2.5), hull, false)
	# Amurada (cobertura baixa) + limites invisíveis
	builder.box(Vector3(0.3, 1.2, HALF_L * 2), Vector3(-HALF_W + 0.15, 0.6, 0), steel)
	builder.box(Vector3(0.3, 1.2, HALF_L * 2), Vector3(HALF_W - 0.15, 0.6, 0), steel)
	builder.box(Vector3(HALF_W * 2, 1.2, 0.3), Vector3(0, 0.6, HALF_L - 0.15), steel)
	builder.box(Vector3(HALF_W * 2, 1.2, 0.3), Vector3(0, 0.6, -HALF_L + 0.15), steel)
	boundary(Vector2(-HALF_W + 0.3, -HALF_L + 0.3), Vector2(HALF_W - 0.3, HALF_L - 0.3))

	# Contêineres em duas fileiras, com corredor central e corredores laterais
	var colors := [Color(0.55, 0.12, 0.08), Color(0.1, 0.25, 0.45), Color(0.2, 0.35, 0.18), Color(0.6, 0.45, 0.1)]
	var zs := [-36.0, -27.0, -18.0, -6.0, 3.0, 13.0]
	for i in zs.size():
		for side in [-1.0, 1.0]:
			if (i + int(side)) % 5 == 0:
				continue  # vão para variar as rotas
			var c: Color = colors[(i * 2 + int(side + 1)) % colors.size()]
			container(Vector3(side * 4.2, 0, zs[i]), 0.0, c)
			if (i + int(side)) % 2 == 0:
				builder.box(Vector3(2.4, 2.6, 6.0), Vector3(side * 4.2, 3.9, zs[i]),
					builder.material("container_%s" % c.to_html(false), c, 0.7, 0.3))
	# Cabrestantes e escotilhas como cobertura no corredor central
	for z in [-41.0, -12.0, 8.0, 19.0]:
		builder.cover_obstacle(Vector3(2.0, 0.9, 1.6), Vector3(0, 0.45, z), steel, 0.0, true)

	# Superestrutura com a ponte de comando
	builder.glass_windows = true  # ponte de comando com vidraças
	var white := Color(0.75, 0.75, 0.72)
	var wall := builder.material("super_wall", white)
	var h := 3.2
	builder.wall_x(-6, 6, SUPER_Z0, h, 0.3, wall, [Vector4(-3.5, 1.4, 0, 2.2), Vector4(3.5, 1.4, 0, 2.2), Vector4(0, 4.0, 1.1, 2.4)])
	builder.wall_x(-6, 6, SUPER_Z1, h, 0.3, wall, [Vector4(-3, 1.4, 0, 2.2)])
	builder.wall_z(SUPER_Z0, SUPER_Z1, -6, h, 0.3, wall, [Vector4(32.5, 1.4, 0, 2.2)])
	builder.wall_z(SUPER_Z0, SUPER_Z1, 6, h, 0.3, wall, [Vector4(32.5, 1.4, 0, 2.2)])
	builder.wall_x(-6, 6, 29.5, h, 0.2, wall, [Vector4(0, 1.4, 0, 2.2)])
	builder.wall_z(29.5, SUPER_Z1, 0, h, 0.2, wall, [Vector4(31.5, 1.2, 0, 2.2)])
	builder.box(Vector3(12.6, 0.3, 12.6), Vector3(0, h + 0.15, 30), builder.material("super_roof", Color(0.6, 0.6, 0.58)))
	builder.box(Vector3(6, 3, 5), Vector3(0, h + 1.8, 31), wall, false)     # casa do leme superior (visual)
	builder.cylinder(0.2, 9.0, Vector3(0, h + 3.3, 31), builder.material("metal", Color(0.12, 0.13, 0.12), 0.6, 0.4), false, 6)
	# Mobília da ponte, sala de rádio e cabine do capitão
	builder.cover_obstacle(Vector3(4.0, 1.0, 0.8), Vector3(0, 0.5, 26.4), steel)
	builder.box(Vector3(1.6, 0.8, 0.6), Vector3(-4.6, 0.4, 30.0), steel)
	builder.box(Vector3(1.6, 0.6, 2.0), Vector3(4.6, 0.3, 34.5), builder.material("bunk", Color(0.3, 0.1, 0.1)))
	builder.omni(Vector3(0, 2.8, 27), Color(0.6, 0.85, 1.0), 0.9, 7.0, true)
	builder.omni(Vector3(-3, 2.8, 33), Color(1.0, 0.8, 0.5), 0.7, 5.0)
	builder.omni(Vector3(3, 2.8, 33), Color(1.0, 0.75, 0.45), 0.6, 5.0)
	alarm_light(Vector3(0, 3.0, 31))

	# Guindaste, botes salva-vidas e iluminação do convés
	builder.cylinder(0.4, 10.0, Vector3(-6.5, 0, -22), steel, true, 8)
	builder.box(Vector3(0.6, 0.6, 14), Vector3(-6.5, 10, -16), steel, false)
	for side in [-1.0, 1.0]:
		builder.box(Vector3(1.6, 1.2, 5), Vector3(side * 7.2, 2.6, 30), builder.material("lifeboat", Color(0.9, 0.45, 0.1)), false)
	for z in [-40.0, -22.0, -2.0, 18.0]:
		var l := builder.omni(Vector3(0, 6.5, z), Color(1.0, 0.8, 0.55), 2.0, 13.0, true)
		if z == -22.0:
			add_flicker(l)
	builder.spot(Vector3(0, h + 0.6, SUPER_Z0 - 0.4), Vector3(0, 0, -20), Color(0.95, 0.97, 1.0), 4.0, 50.0, 22.0)
	add_siren(Vector3(0, 6.0, 30))
	ammo_crate(Vector3(-5.5, 0, 41))
	ammo_crate(Vector3(5.6, 0, 20))


func define_objectives() -> Array[Dictionary]:
	var list: Array[Dictionary] = [
		{"type": "kill", "stage": 0, "title": "Neutralizar a tripulação armada no convés",
			"marker": Vector3(0, 0, -10), "checkpoint": [Vector3(0, 0, 42), 0.0]},
		{"type": "kill", "stage": 1, "title": "Tomar a ponte de comando", "marker": Vector3(0, 0, 27),
			"checkpoint": [Vector3(0, 0, 19), 180.0],
			"radio": [["CAP. REYES", "Convés limpo. Entrando na superestrutura — CQB, cuidado com a ponte.", 4.0]]},
		{"type": "interact", "title": "Cortar as máquinas do navio", "label": "Máquinas",
			"checkpoint": [Vector3(0, 0, 31), 180.0],
			"targets": [{"pos": Vector3(-4.2, 0, 28.6), "visual": ObjectiveInteractable.Visual.HELM,
				"prompt": "Segure [E] para cortar as máquinas e travar o leme", "hold": 2.0}],
			"radio": [["CAP. REYES", "Ponte tomada. Desliguem as máquinas antes que fujam para águas internacionais.", 4.0]]},
		{"type": "defend", "title": "Segurar a proa até a lancha da Marinha encostar", "pos": Vector3(0, 0, -38),
			"radius": 7.0, "duration": 45.0, "checkpoint": [Vector3(0, 0, 20), 0.0], "air": true,
			"defend_waves": [
				{"time": 5.0, "spawns": [["militia", Vector3(-6, 0, 10)], ["militia", Vector3(6, 0, 12)], ["guard", Vector3(0, 0, 21)]]},
				{"time": 22.0, "spawns": [["militia", Vector3(-6.5, 0, -2)], ["elite", Vector3(6.5, 0, 0)], ["militia", Vector3(0, 0, 15)]]},
			],
			"radio": [["OVERLORD", "Máquinas paradas. Tripulantes saindo da casa de máquinas! Segurem a proa por 45 segundos.", 4.5]]},
	]
	return list


func spawn_enemies() -> void:
	spawn_enemy("guard", Vector3(-6.5, 0, -35), 0, [Vector3(-6.5, 0, -40), Vector3(-6.5, 0, 2)])
	spawn_enemy("guard", Vector3(6.5, 0, -20), 0, [Vector3(6.5, 0, -32), Vector3(6.5, 0, 16)])
	spawn_enemy("militia", Vector3(0, 0, -30), 0, [], 180.0)
	spawn_enemy("militia", Vector3(1.5, 0, -9), 0, [], 160.0)
	spawn_enemy("guard", Vector3(0, 0, 10), 0, [], 180.0)
	spawn_enemy("militia", Vector3(-1.5, 0, 16), 0, [Vector3(-1.5, 0, 16), Vector3(-1.5, 0, -2)])
	spawn_enemy("guard", Vector3(2, 0, -43), 0, [], 0.0)
	spawn_enemy("militia", Vector3(-6.5, 0, 21), 0, [], 90.0)
	spawn_enemy("elite", Vector3(-2.5, 0, 27.5), 1, [], 0.0)
	spawn_enemy("guard", Vector3(3, 0, 28), 1, [], 10.0)
	spawn_enemy("militia", Vector3(-3, 0, 34), 1, [], 90.0)
	spawn_enemy("elite", Vector3(3, 0, 33), 1, [], 270.0)
