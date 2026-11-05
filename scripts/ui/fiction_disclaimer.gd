extends Control
## Tela de aviso obrigatória (GDD 8.1). Não pulável na primeira execução
## ou quando DISCLAIMER_VERSION muda.

const DISCLAIMER_VERSION := 1
const SETTINGS_PATH := "user://settings.cfg"
const MIN_SECONDS := 4.0
const NEXT_SCENE := "res://scenes/menus/main_menu.tscn"

## Texto canônico; usado se a tradução ainda não foi importada.
const FALLBACK_MAIN := "Este é um jogo de ficção satírica e dark comedy. Nenhuma ação real é incentivada. Todos os personagens e eventos são caricaturas exageradas baseadas em drama público já noticiado."
const FALLBACK_DETAIL := "Diálogos, pensamentos, motivações e situações deste jogo são inteiramente inventados. Nada aqui deve ser lido como fato."

var _button: Button


static func t(key: String, fallback: String) -> String:
	var s := TranslationServer.translate(key)
	return fallback if s == key else s


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.09, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(820, 0)
	box.position = Vector2(-410, -140)
	box.add_theme_constant_override("separation", 24)
	add_child(box)

	var main := Label.new()
	main.text = t("DISCLAIMER_MAIN", FALLBACK_MAIN)
	main.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main.add_theme_font_size_override("font_size", 26)
	box.add_child(main)

	var detail := Label.new()
	detail.text = t("DISCLAIMER_DETAIL", FALLBACK_DETAIL)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.modulate = Color(0.75, 0.75, 0.78)
	box.add_child(detail)

	_button = Button.new()
	_button.text = t("DISCLAIMER_ACK", "Entendi")
	_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_button.disabled = true
	_button.pressed.connect(_on_ack)
	box.add_child(_button)

	var wait := MIN_SECONDS if not _already_acknowledged() else 0.5
	get_tree().create_timer(wait).timeout.connect(_enable_button)


func _enable_button() -> void:
	_button.disabled = false
	_button.grab_focus()


func _already_acknowledged() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return false
	return int(cfg.get_value("disclaimer", "ack_version", 0)) >= DISCLAIMER_VERSION


func _on_ack() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("disclaimer", "ack_version", DISCLAIMER_VERSION)
	cfg.save(SETTINGS_PATH)
	get_tree().change_scene_to_file(NEXT_SCENE)
