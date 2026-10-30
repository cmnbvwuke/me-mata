extends CanvasLayer
## Menu de pausa (ESC / P). Funciona com a árvore pausada (PROCESS_MODE_ALWAYS).

var _panel: Control
var _main_box: VBoxContainer
var _settings: SettingsPanel
var _enabled := true


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UIStyle.get_theme()
	add_child(root)
	_panel = root
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.65)
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(UIStyle.label("OPERAÇÃO PAUSADA", 30, UIStyle.AMBER))
	box.add_child(UIStyle.label("Absolute Resolve — Hacienda El Mirador", 16, UIStyle.DIM))
	_main_box = VBoxContainer.new()
	_main_box.add_theme_constant_override("separation", 8)
	box.add_child(_main_box)
	_main_box.add_child(UIStyle.button("CONTINUAR", resume))
	_main_box.add_child(UIStyle.button("REINICIAR DO CHECKPOINT", func() -> void: GameManager.restart_from_checkpoint()))
	_main_box.add_child(UIStyle.button("CONFIGURAÇÕES", _toggle_settings))
	_main_box.add_child(UIStyle.button("ABANDONAR MISSÃO (MENU)", func() -> void: GameManager.go_to_main_menu()))
	_settings = SettingsPanel.new()
	_settings.visible = false
	box.add_child(_settings)
	visible = false


## O nível pode bloquear a pausa (ex.: durante a tela de morte).
func set_enabled(v: bool) -> void:
	_enabled = v


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if visible:
			resume()
		elif _enabled:
			pause()
		get_viewport().set_input_as_handled()


func pause() -> void:
	visible = true
	_settings.visible = false
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func resume() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _toggle_settings() -> void:
	_settings.visible = not _settings.visible
