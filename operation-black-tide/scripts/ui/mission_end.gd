extends Control
## Tela de resultado: MISSÃO CUMPRIDA / MISSÃO FALHOU + estatísticas.

const BG_SHADER := preload("res://shaders/menu_background.gdshader")


func _ready() -> void:
	theme = UIStyle.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var result := GameManager.last_result
	var success := bool(result.get("success", false))
	var stats: Dictionary = result.get("stats", {})

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = BG_SHADER
	bg.material = mat
	add_child(bg)
	var tint := ColorRect.new()
	tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	tint.color = Color(0.0, 0.1, 0.02, 0.35) if success else Color(0.2, 0.0, 0.0, 0.4)
	add_child(tint)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var mission := Campaign.get_mission(String(result.get("mission_id", "")))
	box.add_child(UIStyle.label(String(mission.get("title", "Operação")).to_upper(), 16, UIStyle.DIM))
	box.add_child(UIStyle.label("MISSÃO CUMPRIDA" if success else "MISSÃO FALHOU", 44,
		UIStyle.GOOD if success else UIStyle.DANGER))
	var reason := UIStyle.label(String(result.get("reason", "")), 18)
	reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(reason)
	box.add_child(HSeparator.new())

	var shots := int(stats.get("shots_fired", 0))
	var hits := int(stats.get("shots_hit", 0))
	var accuracy := (100.0 * hits / shots) if shots > 0 else 0.0
	var elapsed := float(result.get("elapsed", 0.0))
	var lines := [
		["Tempo de operação", "%02d:%02d" % [int(elapsed) / 60, int(elapsed) % 60]],
		["Inimigos neutralizados", str(stats.get("kills", 0))],
		["Tiros na cabeça (abates)", str(stats.get("headshots", 0))],
		["Precisão", "%.0f%%  (%d/%d)" % [accuracy, hits, shots]],
		["Vezes detectado (alarmes)", str(stats.get("times_detected", 0))],
		["Inteligência coletada", "%d / %d" % [int(stats.get("intel", 0)), int(stats.get("intel_total", 0))]],
		["Reinícios de checkpoint", str(stats.get("restarts", 0))],
	]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	box.add_child(grid)
	for l in lines:
		grid.add_child(UIStyle.label(String(l[0]), 17, UIStyle.DIM))
		grid.add_child(UIStyle.label(String(l[1]), 17, UIStyle.AMBER))
	box.add_child(HSeparator.new())
	if not success:
		box.add_child(UIStyle.button("TENTAR NOVAMENTE (CHECKPOINT)", func() -> void: GameManager.restart_from_checkpoint()))
	box.add_child(UIStyle.button("REINICIAR MISSÃO", func() -> void: GameManager.start_mission(String(result.get("mission_id", "")))))
	box.add_child(UIStyle.button("MENU PRINCIPAL", func() -> void: GameManager.go_to_main_menu()))
