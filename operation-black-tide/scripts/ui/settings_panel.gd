class_name SettingsPanel
extends VBoxContainer
## Painel de configurações reutilizado no menu principal e na pausa.

func _ready() -> void:
	add_theme_constant_override("separation", 12)
	add_child(UIStyle.label("CONFIGURAÇÕES", 22, UIStyle.AMBER))
	_add_slider("Sensibilidade do mouse", 0.2, 3.0, 0.05, GameManager.mouse_sensitivity,
		func(v: float) -> void: GameManager.mouse_sensitivity = v, "%.2fx")
	_add_slider("Volume geral", 0.0, 1.0, 0.01, GameManager.master_volume,
		func(v: float) -> void: GameManager.master_volume = v, "%d%%", 100.0)
	_add_slider("Campo de visão (FOV)", 60.0, 100.0, 1.0, GameManager.field_of_view,
		func(v: float) -> void: GameManager.field_of_view = v, "%d°")


func _add_slider(title: String, min_v: float, max_v: float, step: float, value: float,
		setter: Callable, fmt: String, display_scale: float = 1.0) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	add_child(row)
	var name_label := UIStyle.label(title, 17)
	name_label.custom_minimum_size.x = 230
	row.add_child(name_label)
	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(220, 24)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var value_label := UIStyle.label(fmt % (value * display_scale), 17, UIStyle.AMBER)
	value_label.custom_minimum_size.x = 64
	row.add_child(value_label)
	slider.value_changed.connect(func(v: float) -> void:
		setter.call(v)
		value_label.text = fmt % (v * display_scale)
		GameManager.apply_settings()
		GameManager.save_settings())
