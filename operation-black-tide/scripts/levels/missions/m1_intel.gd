extends MissionLevel
## FASE 1 — "Pacote Silencioso" (noite)
## Infiltração furtiva no porto de San Lázaro para coletar inteligência
## (manifestos, celulares e o HD do capitão), fixar um rastreador GPS no
## cargueiro atracado e exfiltrar pela lancha no cais.

const START := Vector3(-46, 0, -44)
const WH_A := Vector3(-24, 0, -14)   # armazém A (20 x 14)
const WH_B := Vector3(20, 0, -20)    # armazém B (18 x 14)
const OFFICE := Vector3(26, 0, 16)   # escritório da capitania (10 x 8)
const EXFIL := Vector3(-42, 0, 36)


func environment_preset() -> String:
	return "night"


func nav_bounds() -> AABB:
	return AABB(Vector3(-52, -2, -52), Vector3(104, 14, 94))


func intro_lines() -> Array:
	return [
		["OVERLORD", "TRIDENT, o porto de San Lázaro é a porta de saída do cartel. Precisamos dos registros deles.", 4.5],
		["CAP. REYES", "Entramos em silêncio, pegamos o pacote e saímos. Pistola suprimida e nada de alarme.", 4.5],
	]


func success_text() -> String:
	return "Manifestos, telefones e o HD do capitão foram entregues à inteligência. O rastreador revela a rota do cargueiro até Valderrama."


func build_world() -> void:
	ground(Vector2(110, 96), Vector3(0, 0, -6), Color(0.17, 0.17, 0.16), "asphalt")
	sea(Vector3(0, 0, 220), Vector2(800, 360), -2.0)
	builder.box(Vector3(110, 2, 1.0), Vector3(0, -1.0, 42.5), builder.material("quay", Color(0.3, 0.29, 0.27)), false)
	# Cargueiro atracado (visual) e defensas do cais
	builder.box(Vector3(70, 9, 14), Vector3(0, 2.0, 52), builder.material("ship_hull", Color(0.3, 0.08, 0.06), 0.7, 0.3), false)
	builder.box(Vector3(14, 8, 10), Vector3(22, 10, 52), builder.material("super_wall", Color(0.75, 0.75, 0.72)), false)
	for x in [-30.0, -15.0, 0.0, 15.0, 30.0]:
		builder.cylinder(0.35, 0.8, Vector3(x, 0, 41), builder.material("metal", Color(0.12, 0.13, 0.12), 0.6, 0.4), true, 8)
	# Armazéns e escritório
	house(WH_A, Vector2(20, 14), 6.0, ["s", "e"], Color(0.42, 0.4, 0.36))
	house(WH_B, Vector2(18, 14), 6.0, ["s", "w"], Color(0.36, 0.38, 0.4))
	house(OFFICE, Vector2(10, 8), 3.2, ["w"], Color(0.6, 0.58, 0.5))
	# Prateleiras/paletes dentro dos armazéns (cobertura)
	for dz in [-3.0, 2.5]:
		crates(WH_A + Vector3(-5, 0, dz))
		crates(WH_A + Vector3(4, 0, dz), 0.0)
		crates(WH_B + Vector3(-3, 0, dz))
		crates(WH_B + Vector3(5, 0, dz))
	# Pátio de contêineres
	var colors := [Color(0.55, 0.12, 0.08), Color(0.1, 0.25, 0.45), Color(0.2, 0.35, 0.18), Color(0.6, 0.45, 0.1), Color(0.4, 0.4, 0.42)]
	var k := 0
	for x in [-14.0, -6.0, 2.0, 10.0]:
		for z in [6.0, 18.0, 28.0]:
			k += 1
			if k % 4 == 0:
				continue
			container(Vector3(x, 0, z), 0.0, colors[k % colors.size()])
	# Pórtico (guindaste de cais) e iluminação
	var steel := builder.material("crane", Color(0.75, 0.5, 0.1), 0.6, 0.4)
	for x in [-28.0, -18.0]:
		builder.box(Vector3(1, 22, 1), Vector3(x, 11, 30), steel)
		builder.box(Vector3(1, 22, 1), Vector3(x, 11, 40), steel)
	builder.box(Vector3(12, 1.5, 30), Vector3(-23, 22, 40), steel, false)
	for p in [Vector3(-36, 0, 30), Vector3(-10, 0, 37), Vector3(14, 0, 34), Vector3(38, 0, 30), Vector3(0, 0, -2),
			Vector3(-40, 0, -2), Vector3(40, 0, -4)]:
		lamp(p, Color(1.0, 0.62, 0.3), 2.0, 11.0, p.x < -35.0)
	# Cerca do porto (perímetro) com portão a oeste
	var fence := builder.material("fence", Color(0.3, 0.3, 0.3), 0.7, 0.5)
	builder.box(Vector3(0.2, 2.5, 30), Vector3(-36, 1.25, -37), fence)
	builder.box(Vector3(70, 2.5, 0.2), Vector3(0, 1.25, -40), fence)
	alarm_light(Vector3(-24, 6.2, -6.8))
	alarm_light(Vector3(20, 6.2, -12.8))
	alarm_light(Vector3(26, 3.4, 20.2))
	add_siren(Vector3(0, 6, 0))
	# Lancha de exfiltração
	boat(Vector3(-42, -1.6, 47), 0.0, 7.0, Color(0.1, 0.1, 0.1), false)
	ammo_crate(START + Vector3(3, 0, 3))
	ammo_crate(WH_B + Vector3(7.5, 0, -5.5))
	boundary(Vector2(-52, -50), Vector2(52, 41.5))


func define_objectives() -> Array[Dictionary]:
	var intel := ObjectiveInteractable.Visual.INTEL
	var list: Array[Dictionary] = [
		{"type": "interact", "title": "Coletar a inteligência do cartel", "label": "Itens coletados",
			"checkpoint": [START, 225.0],
			"targets": [
				{"pos": OFFICE + Vector3(2, 0, -2), "visual": ObjectiveInteractable.Visual.TERMINAL, "yaw": 180.0,
					"prompt": "Segure [E] para copiar os manifestos de carga", "hold": 2.5},
				{"pos": WH_A + Vector3(6, 0, -5), "visual": intel, "prompt": "Segure [E] para recolher os celulares descartáveis"},
				{"pos": WH_B + Vector3(-6, 0, -5), "visual": intel, "prompt": "Segure [E] para pegar o HD do capitão"},
			],
			"radio": [["CAP. REYES", "Manifestos na capitania, celulares no armazém A, o HD está no armazém B.", 4.5]]},
		{"type": "interact", "title": "Fixar o rastreador GPS no cargueiro", "label": "Rastreador",
			"checkpoint": [Vector3(-20, 0, 2), 150.0],
			"targets": [{"pos": Vector3(4, 0, 40.2), "visual": ObjectiveInteractable.Visual.TERMINAL, "yaw": 180.0,
				"prompt": "Segure [E] para fixar o rastreador no casco do cargueiro", "hold": 2.5}],
			"radio": [["OVERLORD", "Pacote confirmado. Antes de sair, fixem o rastreador no casco junto à prancha.", 4.0]]},
		{"type": "reach", "title": "Exfiltrar pela lancha no cais oeste", "pos": EXFIL, "radius": 4.0,
			"checkpoint": [Vector3(4, 0, 36), 270.0],
			"on_start": _exfil_reinforcements},
	]
	return list


func _exfil_reinforcements() -> void:
	if not StealthSystem.alarm_active:
		hud.show_radio("CAP. REYES", "Ninguém nos viu. Saindo em silêncio.", 3.0)
		return
	hud.show_radio("OVERLORD", "Caminhonetes entrando pelo portão leste! Para a lancha!", 3.5)
	spawn_wave({"spawns": [["militia", Vector3(46, 0, 10)], ["militia", Vector3(46, 0, 14)], ["guard", Vector3(46, 0, 20)]]}, 2)


func spawn_enemies() -> void:
	spawn_enemy("guard", Vector3(-30, 0, 0), 0, [Vector3(-30, 0, 0), Vector3(-30, 0, 34), Vector3(-2, 0, 34)])
	spawn_enemy("guard", Vector3(18, 0, 0), 0, [Vector3(18, 0, 0), Vector3(-18, 0, 0)])
	spawn_enemy("militia", WH_A + Vector3(-2, 0, 0), 0, [], 90.0)
	spawn_enemy("guard", WH_A + Vector3(10, 0, 9), 0, [], 180.0)
	spawn_enemy("militia", WH_B + Vector3(2, 0, -1), 0, [], 270.0)
	spawn_enemy("guard", WH_B + Vector3(-11, 0, 9), 0, [WH_B + Vector3(-11, 0, 9), WH_B + Vector3(12, 0, 9)])
	spawn_enemy("elite", OFFICE + Vector3(-2, 0, 1), 0, [], 270.0)
	spawn_enemy("militia", Vector3(6, 0, 12), 0, [Vector3(6, 0, 12), Vector3(6, 0, 34), Vector3(14, 0, 24)])
	spawn_enemy("guard", Vector3(-6, 0, 37.5), 1, [Vector3(-6, 0, 37.5), Vector3(20, 0, 37.5)])
	spawn_enemy("militia", Vector3(9, 0, 39), 1, [], 270.0)
