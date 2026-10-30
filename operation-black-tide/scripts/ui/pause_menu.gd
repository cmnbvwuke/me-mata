extends CanvasLayer
## Menu de pausa (ESC / P). Funciona com a árvore pausada (PROCESS_MODE_ALWAYS).

var _panel: Control
var _main_box: VBoxContainer
var _settings: SettingsPanel
var _enabled := true
var _had_capture := false
var _lost_capture_time := 0.0


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


func _process(delta: float) -> void:
	# Na versão Web o Esc é consumido pelo navegador (libera o mouse sem enviar a tecla).
	# Se o mouse foi solto durante o jogo, abre a pausa automaticamente.
	if not OS.has_feature("web") or visible or not _enabled:
		_lost_capture_time = 0.0
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and _had_capture:
		_lost_capture_time += delta
		if _lost_capture_time > 0.25:
			pause()
	else:
		_lost_capture_time = 0.0
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_had_capture = true


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
