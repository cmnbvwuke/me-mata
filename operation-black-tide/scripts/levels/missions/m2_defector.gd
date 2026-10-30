extends MissionLevel
## FASE 2 — "Voz de Dentro" (entardecer)
## Extração do desertor Coronel Ibarra, escondido numa casa em San Isidro.
## A polícia secreta (SEBIN) e a milícia patrulham as ruas. Depois do resgate,
## uma emboscada tenta impedir a escolta até o veículo de extração.

const START := Vector3(-40, 0, 40)
const SAFEHOUSE := Vector3(26, 0, -26)   # casa 10 x 8, porta a oeste
const EXFIL := Vector3(-40, 0, 40)

var ibarra: HVTCharacter


func environment_preset() -> String:
	return "dusk"


func nav_bounds() -> AABB:
	return AABB(Vector3(-52, -2, -52), Vector3(104, 14, 104))


func intro_lines() -> Array:
	return [
		["OVERLORD", "O Coronel Ibarra conhece a rotina do General. A SEBIN está fechando o cerco sobre ele.", 4.5],
		["CAP. REYES", "Casa no extremo nordeste de San Isidro. Chegamos, pegamos ele e voltamos ao carro.", 4.5],
	]


func success_text() -> String:
	return "O Coronel Ibarra está a salvo. Seu depoimento revela a rotina e o esconderijo do General Salcedo."


func build_world() -> void:
	ground(Vector2(106, 106), Vector3.ZERO, Color(0.25, 0.22, 0.18), "dirt")
	var road := builder.material("road", Color(0.17, 0.15, 0.13))
	builder.box(Vector3(104, 0.02, 7), Vector3(0, 0.012, 0), road, false)
	builder.box(Vector3(7, 0.02, 104), Vector3(0, 0.012, 0), road, false)
	builder.box(Vector3(104, 0.02, 5), Vector3(0, 0.012, -36), road, false)
	# Quarteirões de casas (deixando as ruas livres)
	var palette := [Color(0.75, 0.6, 0.4), Color(0.6, 0.65, 0.55), Color(0.7, 0.45, 0.35), Color(0.55, 0.6, 0.7), Color(0.8, 0.75, 0.6)]
	var lots := [
		[Vector3(-34, 0, -20), "s"], [Vector3(-18, 0, -20), "s"], [Vector3(14, 0, -18), "s"],
		[Vector3(-34, 0, 16), "n"], [Vector3(-18, 0, 18), "n"], [Vector3(16, 0, 16), "n"], [Vector3(34, 0, 18), "n"],
		[Vector3(-34, 0, -46), "s"], [Vector3(-12, 0, -46), "s"], [Vector3(14, 0, -46), "s"],
		[Vector3(30, 0, 36), "n"], [Vector3(-14, 0, 38), "w"],
	]
	for i in lots.size():
		var size := Vector2(rng.randf_range(8, 11), rng.randf_range(7, 9))
		house(lots[i][0], size, rng.randf_range(3.0, 3.6), [lots[i][1]], palette[i % palette.size()], i % 3 == 0)
	# Esconderijo do desertor
	house(SAFEHOUSE, Vector2(10, 8), 3.2, ["w"], Color(0.65, 0.55, 0.45))
	builder.box(Vector3(1.6, 0.6, 2.0), SAFEHOUSE + Vector3(3, 0.3, -2), builder.material("bunk", Color(0.3, 0.1, 0.1)))
	# Mercado / praça: barracas e carros como cobertura
	for p in [Vector3(-6, 0, -8), Vector3(6, 0, 8), Vector3(-8, 0, 9)]:
		builder.cover_obstacle(Vector3(3, 1.6, 2.2), p + Vector3.UP * 0.8, builder.material("stall", Color(0.5, 0.2, 0.15)), 0.0, true)
	for c in [[Vector3(-22, 0, -4.5), 0.0], [Vector3(20, 0, 4.5), PI], [Vector3(4.5, 0, -24), PI * 0.5], [Vector3(-4.5, 0, 26), PI * 0.5]]:
		builder.cover_obstacle(Vector3(1.9, 1.4, 4.4), (c[0] as Vector3) + Vector3.UP * 0.7,
			builder.material("car", Color(0.2, 0.22, 0.25), 0.5, 0.5), float(c[1]) + PI * 0.5, true)
	# Veículo de extração (SUV da equipe)
	builder.cover_obstacle(Vector3(2.1, 1.7, 4.8), EXFIL + Vector3(4, 0.85, -2), builder.material("suv", Color(0.08, 0.08, 0.09), 0.5, 0.5), 0.0, true)
	for p in [Vector3(-10, 0, -4), Vector3(10, 0, 4), Vector3(-30, 0, 4), Vector3(30, 0, -4), Vector3(4, 0, -30), Vector3(-4, 0, 30), Vector3(20, 0, -32)]:
		lamp(p, Color(1.0, 0.7, 0.4), 1.6, 10.0, p.x > 25.0)
	scatter_jungle(Rect2(40, -52, 12, 104), 14)
	ammo_crate(START + Vector3(3, 0, -5))
	ammo_crate(SAFEHOUSE + Vector3(-3, 0, 2.8))
	boundary(Vector2(-52, -52), Vector2(52, 52))
	ibarra = spawn_npc(SAFEHOUSE + Vector3(2.5, 0, 1.5), "IBARRA", "Segure [E] para resgatar o Coronel Ibarra",
		Color(0.2, 0.28, 0.2), Color(0.12, 0.3, 0.12), 90.0)


func define_objectives() -> Array[Dictionary]:
	var list: Array[Dictionary] = [
		{"type": "reach", "title": "Chegar ao esconderijo do desertor", "pos": SAFEHOUSE + Vector3(-7, 0, 0), "radius": 3.0,
			"hint": "Patrulhas da SEBIN nas ruas. Evite a praça.", "checkpoint": [START, 315.0]},
		{"type": "rescue", "title": "Resgatar o Coronel Ibarra", "npc": ibarra,
			"checkpoint": [SAFEHOUSE + Vector3(-7, 0, 0), 270.0],
			"radio": [["CAP. REYES", "Ele está lá dentro. Identifiquem-se — ele está armado e assustado.", 3.5]]},
		{"type": "escort", "title": "Escoltar Ibarra até o veículo de extração", "npc": ibarra, "pos": EXFIL, "radius": 7.0,
			"hint": "Ibarra não pode morrer.", "checkpoint": [SAFEHOUSE + Vector3(-7, 0, 1), 225.0], "air": true,
			"on_start": _second_ambush,
			"waves": [{"spawns": [["militia", Vector3(4, 0, -48)], ["militia", Vector3(-4, 0, -48)], ["guard", Vector3(48, 0, 4)], ["guard", Vector3(48, 0, -4)]]}],
			"radio": [["IBARRA", "Eles sabem que estou fugindo! Vão bloquear a rua principal!", 3.5],
				["CAP. REYES", "Fique colado em mim, Coronel. Viper 2-1, apoio aéreo disponível [T].", 4.0]]},
	]
	return list


## Segunda emboscada pelo oeste durante a escolta.
func _second_ambush() -> void:
	var tw := create_tween()
	tw.tween_interval(25.0)
	tw.tween_callback(func() -> void:
		if objectives.is_current("obj_2"):
			hud.show_toast("Emboscada à frente!")
			spawn_wave({"spawns": [["militia", Vector3(-48, 0, 4)], ["militia", Vector3(-48, 0, -4)], ["elite", Vector3(-26, 0, 48)]]}, 2))


func spawn_enemies() -> void:
	spawn_enemy("guard", Vector3(-20, 0, 2), 0, [Vector3(-20, 0, 2), Vector3(20, 0, 2)])
	spawn_enemy("militia", Vector3(-6, 0, -4), 0, [], 0.0)
	spawn_enemy("militia", Vector3(2, 0, 4), 0, [], 180.0)
	spawn_enemy("guard", Vector3(2, 0, -30), 0, [Vector3(2, 0, -30), Vector3(2, 0, 30)])
	spawn_enemy("guard", Vector3(-20, 0, -36), 0, [Vector3(-20, 0, -36), Vector3(40, 0, -36)])
	spawn_enemy("militia", Vector3(-26, 0, 28), 0, [], 90.0)
	spawn_enemy("elite", SAFEHOUSE + Vector3(-9, 0, -6), 1, [], 90.0)
	spawn_enemy("guard", SAFEHOUSE + Vector3(-4, 0, 8), 1, [], 0.0)
