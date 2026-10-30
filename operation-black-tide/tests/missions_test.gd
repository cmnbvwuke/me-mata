extends Node
## Teste automatizado (headless) de TODAS as missões baseadas em MissionLevel.
## Para cada missão: carrega, conclui cada objetivo usando os sistemas reais
## (teleporte até zonas, interação com alvos e detonações, eliminação de
## inimigos, defesa, resgate e escolta), recarrega do checkpoint uma vez e
## verifica a tela de MISSÃO CUMPRIDA.
##
## Rodar:  godot --headless --path . res://tests/missions_test.tscn
## Opcional: só algumas missões ->  ... -- m1_recon m2_defector

const MISSIONS := ["m1_recon", "m1_boarding", "m1_intel", "m2_blockade", "m2_sabotage", "m2_defector", "m4_remnants"]

var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	get_parent().remove_child(self)
	tree.root.add_child(self)
	var wanted: Array = Array(OS.get_cmdline_user_args())
	for id in MISSIONS:
		if not wanted.is_empty() and not wanted.has(id):
			continue
		await _play_mission(id)
	if _failures.is_empty():
		print("MISSIONS TEST PASSED")
		get_tree().quit(0)
	else:
		print("MISSIONS TEST FAILED: ", _failures)
		get_tree().quit(1)


func _play_mission(id: String) -> void:
	print("== ", id)
	GameManager.start_mission(id)
	var level := await _wait_for_level()
	if level == null:
		_fail(id, "cena não carregou")
		return
	var total: int = level.objective_defs.size()
	var reloaded := false
	var guard := 0
	while guard < 20:
		guard += 1
		await _physics(20)
		if not is_instance_valid(level) or get_tree().current_scene != level:
			break
		var index: int = level.objectives.current_index
		if index >= total:
			break
		# Recarrega do checkpoint uma vez, no 2º objetivo, para testar o fluxo
		if index == 1 and not reloaded:
			reloaded = true
			GameManager.restart_from_checkpoint()
			level = await _wait_for_level(level)
			if level == null:
				_fail(id, "recarga de checkpoint falhou")
				return
			if level.objectives.current_index != 1:
				_fail(id, "checkpoint retomou no objetivo %d" % level.objectives.current_index)
			continue
		var obj: Dictionary = level.objective_defs[index]
		print("  objetivo %d (%s): %s" % [index, obj["type"], obj.get("title", "")])
		await _complete(level, index, obj)
		var ok := false
		for i in 900:
			if not is_instance_valid(level) or get_tree().current_scene != level or level.objectives.current_index != index:
				ok = true
				break
			await get_tree().physics_frame
		if not ok:
			_fail(id, "objetivo %d (%s) não concluiu" % [index, obj["type"]])
			return
	var end := await _wait_for_scene("MissionEnd", 900)
	if end == null or not bool(GameManager.last_result.get("success", false)):
		_fail(id, "não terminou com MISSÃO CUMPRIDA")
		return
	if not GameManager.is_mission_completed(id):
		_fail(id, "missão não marcada como concluída")
	print("  OK — ", GameManager.last_result.get("reason", ""))


## Conclui o objetivo atual acionando os sistemas de jogo de verdade.
func _complete(level: Node, index: int, obj: Dictionary) -> void:
	var player: Player = level.player
	player.max_health = 1e9
	player.health = 1e9
	match String(obj["type"]):
		"reach":
			player.global_position = obj["pos"] + Vector3.UP * 0.2
		"kill":
			for e in get_tree().get_nodes_in_group("enemies"):
				var en := e as Enemy
				if en.stage == int(obj.get("stage", index)):
					en.take_damage(DamageInfo.new(9999.0, player, player.global_position, en.global_position + Vector3.UP))
		"interact":
			for t in level._targets[index]:
				var target := t as ObjectiveInteractable
				player.global_position = target.global_position + Vector3(0, 0.2, 2.5)
				await _physics(5)
				if not target.can_interact():
					_fail(GameManager.current_mission_id, "alvo do objetivo %d inativo" % index)
				target.interact(player)
				await _physics(5)
			# Sai do raio das explosões
			player.global_position += Vector3(0, 0.2, 9.0)
		"defend":
			player.global_position = obj["pos"] + Vector3.UP * 0.2
			await _physics(60)
			level._defend_time = float(obj["duration"]) - 1.0
		"rescue":
			var npc: HVTCharacter = obj["npc"]
			player.global_position = npc.global_position + Vector3(1.5, 0.2, 0)
			await _physics(5)
			npc.interact(player)
		"escort":
			var npc: HVTCharacter = obj["npc"]
			_check(npc.state == HVTCharacter.State.FOLLOWING, "NPC não está seguindo na escolta")
			player.global_position = obj["pos"] + Vector3.UP * 0.2
			npc.global_position = obj["pos"] + Vector3(1, 0.2, 1)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fail(GameManager.current_mission_id, msg)


func _fail(id: String, msg: String) -> void:
	push_error("FALHA [%s]: %s" % [id, msg])
	_failures.append("%s: %s" % [id, msg])


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait_for_level(old: Node = null) -> Node:
	for i in 900:
		await get_tree().process_frame
		var cs := get_tree().current_scene
		if cs != null and cs != old and cs.get("objective_defs") != null and cs.is_node_ready():
			await _physics(30)
			return cs
	return null


func _wait_for_scene(scene_name: String, frames: int) -> Node:
	for i in frames:
		await get_tree().process_frame
		var cs := get_tree().current_scene
		if cs != null and cs.name == scene_name:
			return cs
	return null
