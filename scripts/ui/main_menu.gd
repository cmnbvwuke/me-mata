extends Control

const PROLOGUE_SCENE := "res://scenes/story/dialogue_player.tscn"


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.55, 0.55, 0.58)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var box := VBoxContainer.new()
	box.position = Vector2(80, 200)
	box.add_theme_constant_override("separation", 12)
	add_child(box)

	var title := Label.new()
	title.text = "ESPECTRO SIMULATOR"
	title.add_theme_font_size_override("font_size", 48)
	box.add_child(title)

	_add_button(box, "Novo jogo", _on_new)
	var load_btn := _add_button(box, "Carregar", _on_load)
	load_btn.disabled = not SaveManager.has_slot(0)
	_add_button(box, "Sair", func(): get_tree().quit())

	var footer := Label.new()
	footer.text = "Ficção satírica. Todos os personagens são caricaturas."
	footer.position = Vector2(80, 660)
	footer.modulate = Color(1, 1, 1, 0.6)
	add_child(footer)


func _add_button(parent: Node, label: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(260, 44)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _on_new() -> void:
	GameState.new_run()
	get_tree().change_scene_to_file(PROLOGUE_SCENE)


func _on_load() -> void:
	if SaveManager.load_slot(0):
		var next := "res://scenes/story/week_hub.tscn" if GameState.has_flag(&"prologue_done") else PROLOGUE_SCENE
		get_tree().change_scene_to_file(next)
