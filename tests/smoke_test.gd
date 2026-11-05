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
	root.add_child(dp)
	await get_tree().process_frame
	for i in 200:
		dp._advance()
	check(gs.has_flag(&"prologue_done"), "prólogo concluído")
	check(gs.archive.size() == 1, "prólogo gera 1 gravação")
	check(gs.rivals.get(&"julia_planilha") == "active", "Júlia revelada")
	print("Obsessão ao fim do prólogo: ", obs.value())

	print("OK" if failures == 0 else "%d falha(s)" % failures)
	get_tree().quit(failures)
