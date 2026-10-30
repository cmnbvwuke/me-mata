class_name UIStyle
extends RefCounted
## Tema visual compartilhado (menus e HUD): tons escuros com destaque âmbar,
## estilo de interface militar.

const AMBER := Color(1.0, 0.72, 0.25)
const TEXT := Color(0.87, 0.89, 0.86)
const DIM := Color(0.55, 0.58, 0.55)
const DANGER := Color(0.95, 0.22, 0.15)
const GOOD := Color(0.45, 0.9, 0.45)
const PANEL_BG := Color(0.02, 0.03, 0.04, 0.82)

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Rajdhani", "Bahnschrift", "Roboto Condensed", "DejaVu Sans Condensed", "Arial Narrow", "Sans-Serif"])
	t.default_font = font
	t.default_font_size = 18

	t.set_stylebox("normal", "Button", _box(Color(0.05, 0.06, 0.07, 0.9), Color(0.25, 0.27, 0.27), 1))
	t.set_stylebox("hover", "Button", _box(Color(0.16, 0.12, 0.05, 0.95), AMBER, 2))
	t.set_stylebox("pressed", "Button", _box(Color(0.3, 0.2, 0.05, 0.95), AMBER, 2))
	t.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), AMBER, 1))
	t.set_stylebox("disabled", "Button", _box(Color(0.04, 0.04, 0.04, 0.7), Color(0.15, 0.15, 0.15), 1))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", AMBER)
	t.set_color("font_pressed_color", "Button", AMBER)
	t.set_color("font_focus_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", Color(0.35, 0.36, 0.35))
	t.set_font_size("font_size", "Button", 20)
	t.set_stylebox("panel", "PanelContainer", _box(PANEL_BG, Color(0.2, 0.22, 0.22), 1, 18))
	t.set_stylebox("panel", "Panel", _box(PANEL_BG, Color(0.2, 0.22, 0.22), 1, 18))
	t.set_stylebox("background", "ProgressBar", _box(Color(0, 0, 0, 0.6), Color(0.25, 0.25, 0.25), 1, 0))
	t.set_stylebox("fill", "ProgressBar", _box(TEXT, Color(0, 0, 0, 0), 0, 0))
	t.set_color("font_color", "Label", TEXT)
	return t


static func _box(bg: Color, border: Color, border_w: int, margin: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.content_margin_left = margin
	sb.content_margin_right = margin
	sb.content_margin_top = margin * 0.6
	sb.content_margin_bottom = margin * 0.6
	return sb


static func label(text: String, size: int = 18, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l


static func button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(260, 44)
	b.pressed.connect(func() -> void: AudioManager.play_2d("ui_click", -8.0))
	b.pressed.connect(callback)
	return b


static func bar(fill: Color, height: float = 8.0) -> ProgressBar:
	var p := ProgressBar.new()
	p.show_percentage = false
	p.custom_minimum_size = Vector2(0, height)
	p.min_value = 0.0
	p.max_value = 1.0
	var sb := _box(fill, Color(0, 0, 0, 0), 0, 0)
	p.add_theme_stylebox_override("fill", sb)
	return p


static func set_bar_color(p: ProgressBar, color: Color) -> void:
	var sb := p.get_theme_stylebox("fill") as StyleBoxFlat
	if sb:
		sb.bg_color = color
