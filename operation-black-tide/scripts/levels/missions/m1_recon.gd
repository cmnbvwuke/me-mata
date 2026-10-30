extends MissionLevel
## FASE 1 — "Olhos no Horizonte" (entardecer)
## Reconhecimento e interdição marítima: a equipe se infiltra pela costa de
## Valderrama, marca com laser as lanchas do cartel na baía para a Marinha,
## destrói o repetidor de rádio que avisaria o porto e extrai pela enseada.

const START := Vector3(-45, 0, -40)
const RELAY := Vector3(30, 0, -25)
const EXFIL := Vector3(-52, 0, 30)


func environment_preset() -> String:
	return "dusk"


func nav_bounds() -> AABB:
	return AABB(Vector3(-62, -2, -55), Vector3(124, 14, 98))


func intro_lines() -> Array:
	return [
		["OVERLORD", "TRIDENT, aqui é Overlord. Lanchas do cartel estão se reunindo na baía de San Lázaro.", 4.5],
		["CAP. REYES", "Vamos até a linha da costa, marcar os barcos para a Marinha e sair sem ser vistos.", 4.5],
	]


func success_text() -> String:
	return "As lanchas marcadas foram interceptadas pela Marinha. A rede de rádio do cartel na costa está fora do ar."


func build_world() -> void:
	ground(Vector2(140, 100), Vector3(0, 0, -10), Color(0.16, 0.15, 0.1), "ground", 40.0)
	# Penhasco e mar ao sul
	sea(Vector3(0, 0, 200), Vector2(800, 320), -12.0)
	builder.box(Vector3(140, 12, 2), Vector3(0, -6, 41), builder.material("cliff", Color(0.22, 0.2, 0.17)), false)
	for i in 14:
		var x := -60.0 + i * 9.0 + rng.randf_range(-2, 2)
		builder.cover_obstacle(Vector3(rng.randf_range(1.6, 2.6), rng.randf_range(0.9, 1.3), 1.4),
			Vector3(x, 0.5, 38.5), builder.material("rock", Color(0.24, 0.23, 0.21)), rng.randf_range(-0.4, 0.4))
	# Estrada costeira
	builder.box(Vector3(130, 0.02, 5), Vector3(0, 0.012, 10), builder.material("road", Color(0.17, 0.15, 0.13)), false)
	scatter_jungle(Rect2(-60, -50, 120, 44), 70, [Rect2(-52, -48, 14, 14), Rect2(18, -36, 26, 24)])
	scatter_jungle(Rect2(-60, 16, 120, 16), 18, [Rect2(-36, 20, 12, 14), Rect2(-6, 20, 12, 16), Rect2(22, 20, 12, 14), Rect2(-58, 22, 12, 14)], 0.8)
	# Acampamento da milícia
	for p in [Vector3(-3, 0, -2), Vector3(5, 0, 3)]:
		builder.cover_obstacle(Vector3(3, 1.8, 4), p + Vector3.UP * 0.9, builder.material("tent", Color(0.22, 0.25, 0.16)), 0.3)
	var fire := builder.omni(Vector3(1, 0.6, 0), Color(1.0, 0.5, 0.2), 1.8, 9.0, true)
	add_flicker(fire)
	crates(Vector3(-8, 0, 4), 0.4)
	# Repetidor de rádio
	house(RELAY + Vector3(-3, 0, 0), Vector2(6, 5), 3.0, ["s"], Color(0.5, 0.5, 0.48))
	builder.cylinder(0.25, 18.0, RELAY + Vector3(3.5, 0, 3), builder.material("metal", Color(0.12, 0.13, 0.12), 0.6, 0.4), true, 6)
	var beacon := builder.omni(RELAY + Vector3(3.5, 18.3, 3), Color(1.0, 0.1, 0.05), 1.5, 6.0)
	add_flicker(beacon)
	sandbags(RELAY + Vector3(-1, 0, 8), 4.0)
	sandbags(RELAY + Vector3(8, 0, -2), 3.0, PI * 0.5)
	lamp(RELAY + Vector3(-7, 0, 4))
	# Lanchas do cartel na baía (alvos a marcar)
	for b in [Vector3(-34, -11.4, 80), Vector3(2, -11.4, 95), Vector3(30, -11.4, 75), Vector3(60, -11.4, 110)]:
		boat(b, rng.randf_range(0, TAU), 10.0, Color(0.2, 0.22, 0.25))
	# Enseada de extração: RHIB aguardando
	boat(Vector3(-52, -11.4, 48), PI * 0.5, 7.0, Color(0.1, 0.1, 0.1), false)
	ammo_crate(Vector3(-46, 0, -36))
	ammo_crate(RELAY + Vector3(-6, 0, 9))
	boundary(Vector2(-62, -55), Vector2(62, 39.5))


func define_objectives() -> Array[Dictionary]:
	var spot := ObjectiveInteractable.Visual.SPOTTER
	var list: Array[Dictionary] = [
		{"type": "reach", "title": "Chegar à linha da costa sem ser detectado", "pos": Vector3(-30, 0, 28), "radius": 5.0,
			"hint": "Use a vegetação. A estrada costeira tem patrulha.", "checkpoint": [START, 195.0]},
		{"type": "interact", "title": "Marcar as lanchas do cartel na baía", "label": "Lanchas marcadas",
			"checkpoint": [Vector3(-30, 0, 26), 120.0],
			"targets": [
				{"pos": Vector3(-30, 0, 35), "visual": spot, "yaw": 180.0, "prompt": "Segure [E] para marcar a lancha com o designador laser"},
				{"pos": Vector3(0, 0, 35.5), "visual": spot, "yaw": 180.0, "prompt": "Segure [E] para marcar a lancha com o designador laser"},
				{"pos": Vector3(27, 0, 35), "visual": spot, "yaw": 180.0, "prompt": "Segure [E] para marcar a lancha com o designador laser"},
			],
			"radio": [["OVERLORD", "Três pontos de observação no penhasco. Marquem cada grupo de lanchas.", 4.0]]},
		{"type": "interact", "title": "Destruir o repetidor de rádio do cartel", "label": "Cargas", "detonate": "all",
			"checkpoint": [Vector3(10, 0, 22), 20.0], "air": true,
			"targets": [{"pos": RELAY + Vector3(2.2, 0, 4.2), "visual": ObjectiveInteractable.Visual.CHARGE,
				"prompt": "Segure [E] para plantar a carga no repetidor", "hold": 2.5}],
			"radio": [["OVERLORD", "Lanchas marcadas. O repetidor no morro vai avisar o porto — derrubem.", 4.0],
				["OVERLORD", "Viper 2-1 disponível para apoio [T].", 3.0]]},
		{"type": "reach", "title": "Extração: RHIB na enseada oeste", "pos": EXFIL, "radius": 5.0,
			"checkpoint": [RELAY + Vector3(-10, 0, 14), 250.0],
			"waves": [{"spawns": [["militia", Vector3(45, 0, 2)], ["militia", Vector3(47, 0, 6)], ["militia", Vector3(44, 0, 9)], ["guard", Vector3(10, 0, -40)]]}],
			"radio": [["CAP. REYES", "Repetidor abatido. Caminhonetes chegando pela estrada — para a enseada, agora!", 4.5]]},
	]
	return list


func spawn_enemies() -> void:
	spawn_enemy("militia", Vector3(-40, 0, 10), 0, [Vector3(-40, 0, 10), Vector3(20, 0, 10)])
	spawn_enemy("guard", Vector3(-20, 0, 22), 0, [], 180.0)
	spawn_enemy("militia", Vector3(-38, 0, -8), 0, [Vector3(-38, 0, -8), Vector3(-20, 0, -20), Vector3(-10, 0, -5)])
	spawn_enemy("guard", Vector3(5, 0, 28), 1, [Vector3(5, 0, 28), Vector3(20, 0, 30)])
	spawn_enemy("militia", Vector3(-12, 0, 30), 1, [], 180.0)
	spawn_enemy("militia", Vector3(0, 0, 2), 1, [], 200.0)
	spawn_enemy("militia", Vector3(4, 0, -3), 1, [], 90.0)
	spawn_enemy("guard", RELAY + Vector3(-2, 0, 6), 2, [], 200.0)
	spawn_enemy("guard", RELAY + Vector3(-8, 0, -6), 2, [RELAY + Vector3(-8, 0, -6), RELAY + Vector3(8, 0, 6)])
	spawn_enemy("elite", RELAY + Vector3(4, 0, -3), 2, [], 220.0)
	spawn_enemy("militia", RELAY + Vector3(-4, 0, 11), 2, [], 160.0)
