extends Node
## Gera prints das telas: godot --path . res://tools/screenshots.tscn -- <pasta_saida>

var out_dir := "user://screenshots"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1280, 720)
	await _run()
	get_tree().quit()


func _frames(n := 8) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await _frames()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
	print("salvo: ", name)


func _spawn(path: String) -> Node:
	for c in get_children():
		c.queue_free()
	var n = load(path).instantiate()
	add_child(n)
	return n


func _click(hub: Node, text_prefix: String) -> void:
	for b in hub._choices.get_children():
		if b is Button and not b.is_queued_for_deletion() and b.text.begins_with(text_prefix):
			b.pressed.emit()
			await _frames(2)
			return
	push_warning("botão não encontrado: " + text_prefix)


func _run() -> void:
	var d = _spawn("res://scenes/boot/fiction_disclaimer.tscn")
	await get_tree().create_timer(0.3).timeout
	await _shot("01_aviso_ficcao")

	_spawn("res://scenes/menus/main_menu.tscn")
	await _shot("02_menu")

	GameState.new_run()
	var dp = _spawn("res://scenes/story/dialogue_player.tscn")
	dp.next_scene = ""
	await _frames()
	# avança até a fala da rejeição ("A Missão primeiro")
	for i in 60:
		var l: Dictionary = dp._lines[dp._index]
		if String(l.get("inner", "")).begins_with("A Missão primeiro"):
			break
		dp._advance()
	await _shot("03_prologo_rejeicao")

	GameState.new_run()
	var hub = load("res://scenes/story/week_hub.tscn").instantiate()
	hub.use_map = false
	for c in get_children():
		c.queue_free()
	add_child(hub)
	hub.runner.rng.seed = 7
	await _frames()
	await _click(hub, "Começar")
	await _click(hub, "Indireta")
	await _click(hub, "Ir para a sede")
	await _click(hub, "Observar")
	await _click(hub, "Continuar")
	await _click(hub, "Observar")
	await _click(hub, "Continuar")
	await _shot("04_sede_metodos")
	await _click(hub, "A Vaga dos Sonhos")
	await _shot("05_metodo_resultado")
	await _click(hub, "Continuar")
	await _click(hub, "(indireta)")
	await _shot("06_live")
	await _click(hub, "(ponderada)")
	await _click(hub, "(ponderada)")
	await _click(hub, "Encerrar")
	await _click(hub, "Mandar um áudio")
	await _shot("07_desabafo_teacher")
	# pula para o fim de semana com escolhas simples
	for i in 200:
		var labels := []
		for b in hub._choices.get_children():
			if b is Button and not b.is_queued_for_deletion() and not b.disabled:
				labels.append(b.text)
		if labels.is_empty() or labels[0].begins_with("Voltar ao menu"):
			break
		if hub._header.text.ends_with("Monólogo Interno"):
			break
		hub._choices.get_children().filter(func(b): return b is Button and not b.disabled and not b.is_queued_for_deletion())[0].pressed.emit()
		await _frames(2)
	await _shot("08_monologo")
	await _map_shots()


func _map_shots() -> void:
	GameState.new_run()
	var r := WeekRunner.new()
	r.rng.seed = 11
	r.load_week("res://data/weeks/week_01.json")
	r.start_week()
	for c in get_children():
		c.queue_free()
	var m: HQMap = load("res://scenes/world/hq_map.tscn").instantiate()
	m.setup(r)
	add_child(m)
	await _frames()
	# visão geral: câmera afastada no centro da planta
	var cam: Camera2D = m.player.get_child(m.player.get_child_count() - 1)
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(0.74, 0.74)
	m.player.position = Vector2(800, 470)
	m._advance_minutes(5)
	await _frames(12)
	await _shot("09_mapa_visao_geral")
	cam.zoom = Vector2(1.15, 1.15)
	# perto da sala do Renan às 13h30
	m.player.position = m.graph.spots["porta_renan"].pos + Vector2(0, 10)
	m._seen_renan_today = false
	await get_tree().physics_frame
	await get_tree().physics_frame
	m._advance_minutes(20)
	await _frames(12)
	await _shot("10_mapa_porta_do_renan")
	# Redação: perto da Júlia, menu aberto
	var j = m._npc("julia_planilha")
	m.player.position = j.position + Vector2(45, 10)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _frames(4)
	m.open_interactions()
	await _shot("11_mapa_menu_julia")
	m.close_panel()
	m._do_method(r.find_method("elogio_constrangedor"), j)
	await _shot("12_mapa_metodo_testemunhas")
	m.close_panel()
