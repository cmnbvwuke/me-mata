extends Node
## Teste de fumaça: godot --headless --path . res://tests/smoke_test.tscn

var failures := 0


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		printerr("FALHOU: ", msg)


func _ready() -> void:
	var root := get_tree().root
	await get_tree().process_frame
	var gs = root.get_node("GameState")
	var obs = root.get_node("ObsessionSystem")
	var conf = root.get_node("ConfidantSystem")
	var rep = root.get_node("ReputationSystem")

	# Faixas de Obsessão
	for pair in [[24, 0], [25, 1], [49, 1], [50, 2], [74, 2], [75, 3], [89, 3], [90, 4], [100, 4]]:
		check(obs.tier_index(pair[0]) == pair[1], "faixa de %d" % pair[0])

	# Clamp
	gs.new_run()
	obs.add(500)
	check(obs.value() == 100.0, "obsessão clamp em 100")

	# Confidente: gravação e ultimato só a partir da semana 4
	gs.new_run()
	var rec = conf.record_confession("teste")
	check(gs.archive.size() == 1 and rec.severity >= 1, "gravação adicionada")
	gs.set_metric(&"legal_risk", 100.0)
	gs.confidant.loyalty = 0.0
	conf.evaluate_night()
	check(not gs.has_flag(&"pendrive_active"), "sem ultimato antes da semana 4")
	gs.week = 4
	conf.evaluate_night()
	check(gs.has_flag(&"pendrive_active"), "ultimato na semana 4 com pressão alta")

	# Ativo inventado custa mais Risco Jurídico que real
	gs.new_run()
	var a := NarrativeAsset.new()
	a.veracity = NarrativeAsset.Veracity.FABRICATED
	a.trace = 0.5
	rep.use_asset(a)
	check(gs.get_metric(&"legal_risk") == 10.0, "ativo inventado soma RJ")

	# Condition
	var c := Condition.new()
	c.key = &"legal_risk"; c.op = Condition.Op.GTE; c.value = 10.0
	check(c.evaluate(), "condition GTE")

	# Roteiro do prólogo é JSON válido
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/prologo.json"))
	check(typeof(data) == TYPE_DICTIONARY and data.scenes.size() == 5, "prólogo com 5 cenas")

	# Dialogue player roda até o fim
	gs.new_run()
	var dp = load("res://scenes/story/dialogue_player.tscn").instantiate()
	dp.next_scene = ""
	root.add_child(dp)
	await get_tree().process_frame
	for i in 200:
		dp._advance()
	check(gs.has_flag(&"prologue_done"), "prólogo concluído")
	check(gs.archive.size() == 1, "prólogo gera 1 gravação")
	check(gs.rivals.get("julia_planilha") == "active", "Júlia revelada")
	print("Obsessão ao fim do prólogo: ", obs.value())

	# Semana 1: lógica completa com escolhas fixas
	_test_week_1(gs, obs)
	# Semana 1: a UI percorre a semana inteira clicando sempre no 1º botão habilitado
	await _test_week_hub_ui(gs)

	print("OK" if failures == 0 else "%d falha(s)" % failures)
	get_tree().quit(failures)


func _test_week_1(gs, obs) -> void:
	gs.new_run()
	var r := WeekRunner.new()
	r.rng.seed = 42
	check(r.load_week("res://data/weeks/week_01.json"), "semana 1 carrega")
	r.start_week()
	check(r.rival_active() and r.rival_attention() == 30.0, "Júlia ativa com atenção 30")
	var vaga_locked := true
	for o in r.hq_options():
		if o.id == "vaga_dos_sonhos": vaga_locked = not o.enabled
		if o.id == "thread_com_nuance": check(not o.enabled, "método narrativo bloqueado com Obsessão baixa")
	check(vaga_locked, "Vaga dos Sonhos exige pré-requisito")
	r.do_action("observar_julia")
	r.do_action("observar_julia")
	var vaga_open := false
	for o in r.hq_options():
		if o.id == "vaga_dos_sonhos": vaga_open = o.enabled
	check(vaga_open, "Vaga dos Sonhos libera com 2 observações")
	var guard := 0
	while not r.is_weekend() and guard < 10:
		guard += 1
		r.feed_event()
		r.choose_post(0)
		for i in 3:
			if r.rival_active(): r.try_method("vaga_dos_sonhos")
			else: r.do_action("yoga")
		for q in r.live_questions():
			r.answer_live(r.available_answers(q)[0])
		r.confess()
		r.resolve_day()
	check(r.is_weekend() and gs.day == 6, "5 dias úteis")
	check(gs.archive.size() == 5, "5 desabafos = 5 gravações")
	r.resolve_crisis(0)
	r.sunday()
	check(r.monologue().size() > 0, "monólogo existe")
	r.finish_week()
	check(gs.has_flag(&"week_1_done"), "semana 1 concluída")
	print("Semana 1 (lógica): Júlia = ", gs.rivals.get("julia_planilha"), " · Obsessão ", obs.value(), " · CP ", gs.get_metric(&"credibility"))


func _test_week_hub_ui(gs) -> void:
	gs.new_run()
	var hub = load("res://scenes/story/week_hub.tscn").instantiate()
	add_child(hub)
	await get_tree().process_frame
	var clicks := 0
	while clicks < 300:
		var btn: Button = null
		for b in hub._choices.get_children():
			if b is Button and not b.disabled and not b.is_queued_for_deletion():
				btn = b
				break
		if btn == null or btn.text == "Voltar ao menu":
			break
		btn.pressed.emit()
		clicks += 1
		await get_tree().process_frame
	check(gs.has_flag(&"week_1_done"), "UI percorre a semana 1 até o monólogo (%d cliques)" % clicks)
	hub.queue_free()
