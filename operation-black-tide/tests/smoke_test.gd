extends Node
## Teste de fumaça automatizado (headless). Percorre a missão Absolute Resolve
## inteira chamando os sistemas reais: intro, movimento, tiro, recarga,
## detecção, objetivos, apoio aéreo, captura do HVT, checkpoint e extração.
##
## Rodar:  godot --headless --path . res://tests/smoke_test.tscn
## Saída:  "SMOKE TEST PASSED" (código 0) ou "SMOKE TEST FAILED: ..." (código 1)

var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	# Sobrevive à troca de cena
	var tree := get_tree()
	get_parent().remove_child(self)
	tree.root.add_child(self)

	GameManager.start_mission("absolute_resolve")
	var level := await _wait_for_scene("AbsoluteResolve")
	await _frames(30)
	var player: Player = level.get_node("Player")
	_make_invulnerable(player)
	_check(player.cinematic_mode, "intro deveria travar o jogador no helicóptero")
	await _frames(120)
	level.call("_end_intro")
	await _frames(10)
	_check(not player.cinematic_mode, "jogador deveria estar livre após a intro")
	var objectives: ObjectiveManager = level.get_node("ObjectiveManager")
	_check(objectives.is_current("infiltrate"), "infiltração concluiu sozinha no início")
	_check(not StealthSystem.alarm_active, "alarme disparou antes de qualquer ação")

	# Movimento
	var start := player.global_position
	Input.action_press("move_forward")
	await _physics(60)
	Input.action_release("move_forward")
	_check(player.global_position.distance_to(start) > 1.5, "jogador não se moveu")

	# Agachar (toggle) e levantar
	await _tap("crouch")
	await _physics(30)
	_check(player.is_crouching, "agachar não funcionou")
	await _tap("crouch")
	await _physics(30)
	_check(not player.is_crouching, "levantar não funcionou")

	# Tiro automático + recarga
	var rifle := player.weapons.current
	await _physics(40)  # termina de equipar
	Input.action_press("fire")
	await _physics(40)
	Input.action_release("fire")
	_check(int(GameManager.stats["shots_fired"]) > 3, "rifle não disparou em automático")
	_check(rifle.ammo_in_mag < rifle.data.magazine_size, "munição não foi consumida")
	await _tap("reload")
	await _physics(200)
	_check(rifle.ammo_in_mag == rifle.data.magazine_size, "recarga não completou")

	# Troca para a pistola e ADS
	await _tap("weapon_2")
	await _physics(40)
	_check(player.weapons.current.data.suppressed, "troca para pistola falhou")
	Input.action_press("aim")
	await _physics(30)
	_check(player.weapons.is_aiming(), "ADS não ativou")
	_check(player.camera.fov < GameManager.field_of_view - 5.0, "FOV do ADS não mudou")
	Input.action_release("aim")
	await _tap("weapon_1")

	# Infiltração: entrar no pátio
	player.global_position = Vector3(-20, 0.1, 7)
	await _physics(20)
	_check(objectives.is_current("courtyard"), "objetivo de infiltração não concluiu")
	_check(GameManager.checkpoint_index == 1, "checkpoint 1 não salvo")

	# Deixa a IA reagir (visão, combate, cobertura, rádio)
	player.global_position = Vector3(-2, 0.1, 6)
	await _physics(420)
	var combat := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if (e as Enemy).state == Enemy.State.COMBAT:
			combat += 1
	print("  inimigos em combate: %d | alarme: %s" % [combat, StealthSystem.alarm_active])
	_check(combat > 0, "nenhum inimigo entrou em combate vendo o jogador no pátio")
	_check(StealthSystem.alarm_active, "alarme global não disparou")

	# Apoio aéreo
	var air: AirSupport = level.get_node("AirSupport")
	var charges := air.charges
	air.request_strike(Vector3(-2, 0, -40.5) + Vector3(0, 0, 30), player)
	await _physics(260)
	_check(air.charges == charges - 1, "apoio aéreo não foi executado")

	# Eliminar a resistência do pátio
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Enemy
		if en.stage == 1:
			en.take_damage(DamageInfo.new(999.0, player, player.global_position, en.global_position + Vector3.UP))
	await _physics(10)
	_check(objectives.is_current("capture"), "objetivo do pátio não concluiu")

	# Capturar o HVT
	var hvt: HVTCharacter = level.get("hvt")
	player.global_position = Vector3(11.5, 0.1, -32.5)
	await _physics(10)
	hvt.interact(player)
	await _physics(10)
	_check(objectives.is_current("extract"), "captura do HVT não concluiu")
	_check(hvt.state == HVTCharacter.State.FOLLOWING, "HVT não está seguindo")

	# Checkpoint: recarrega a partir da extração
	GameManager.restart_from_checkpoint()
	level = await _wait_for_scene("AbsoluteResolve", true)
	await _physics(30)
	player = level.get_node("Player")
	_make_invulnerable(player)
	objectives = level.get_node("ObjectiveManager")
	hvt = level.get("hvt")
	_check(objectives.is_current("extract"), "checkpoint não retomou na extração")
	_check(hvt.state == HVTCharacter.State.FOLLOWING, "HVT não retomou capturado")

	# HVT deve seguir o jogador pela navmesh
	var hvt_start := hvt.global_position
	player.global_position = Vector3(8, 0.1, -26)
	await _physics(240)
	print("  HVT andou %.1f m" % hvt.global_position.distance_to(hvt_start))
	_check(hvt.global_position.distance_to(hvt_start) > 2.0, "HVT não seguiu o jogador")

	# Extração
	await _physics(300)  # reforços chegam e combatem
	level.call("_on_heli_landed")
	player.global_position = Vector3(-20, 0.1, -4)
	hvt.global_position = Vector3(-21, 0.1, -4)
	await _physics(30)
	await _wait_for_scene("MissionEnd")
	_check(bool(GameManager.last_result.get("success", false)), "missão não terminou com sucesso")
	print("  stats: ", GameManager.last_result.get("stats"))
	await _frames(30)

	if _failures.is_empty():
		print("SMOKE TEST PASSED")
		get_tree().quit(0)
	else:
		print("SMOKE TEST FAILED: ", _failures)
		get_tree().quit(1)


func _make_invulnerable(p: Player) -> void:
	p.max_health = 1e9
	p.health = 1e9


func _check(cond: bool, msg: String) -> void:
	if cond:
		return
	push_error("FALHA: " + msg)
	_failures.append(msg)


func _tap(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await _physics(2)
	ev = InputEventAction.new()
	ev.action = action
	ev.pressed = false
	Input.parse_input_event(ev)
	await _physics(2)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait_for_scene(scene_name: String, force_new: bool = false) -> Node:
	var old := get_tree().current_scene
	for i in 600:
		await get_tree().process_frame
		var cs := get_tree().current_scene
		if cs != null and cs.name == scene_name and (not force_new or cs != old):
			return cs
	_check(false, "timeout esperando a cena " + scene_name)
	print("SMOKE TEST FAILED: ", _failures)
	get_tree().quit(1)
	return null
