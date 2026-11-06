extends Control
## Toca um roteiro JSON (data/dialogue/*.json) com balão público + balão interno.

@export_file("*.json") var dialogue_path := "res://data/dialogue/prologo.json"
@export_file("*.tscn") var next_scene := "res://scenes/story/week_hub.tscn"

const COLOR_PUBLIC := Color(0.82, 0.82, 0.84)
const COLOR_INNER := Color(1.0, 0.72, 0.86)

var _lines: Array = []
var _index := -1

var _scene_title: Label
var _speaker: Label
var _public: RichTextLabel
var _inner: RichTextLabel
var _stage: Label
var _obsession: ProgressBar


func _ready() -> void:
	_build_ui()
	var data = JSON.parse_string(FileAccess.get_file_as_string(dialogue_path))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Roteiro inválido: %s" % dialogue_path)
		return
	for sc in data.scenes:
		_lines.append({"speaker": "__SCENE__", "title": sc.title})
		_lines.append_array(sc.lines)
	EventBus.obsession_changed.connect(func(v, _d): _obsession.value = v)
	_obsession.value = ObsessionSystem.value()
	_advance()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed):
		_advance()


func _advance() -> void:
	_index += 1
	if _index >= _lines.size():
		_finish()
		return
	var l: Dictionary = _lines[_index]
	if l.speaker == "__SCENE__":
		_scene_title.text = l.title
		_advance()
		return
	_speaker.text = "" if l.speaker == "NARRADOR" else l.speaker
	_public.text = l.get("public", "")
	_public.visible = l.has("public")
	_inner.text = "[i]%s[/i]" % l.get("inner", "")
	_inner.visible = l.has("inner")
	_stage.text = l.get("stage", "")
	_apply_effects(l)


func _apply_effects(l: Dictionary) -> void:
	var eff: Dictionary = l.get("effects", {})
	if eff.has("obsession"):
		ObsessionSystem.add(float(eff.obsession))
	var fx := String(l.get("fx", ""))
	if fx.begins_with("archive_add:"):
		# O próprio record_confession já reduz Obsessão; descontamos o efeito do roteiro.
		var before := ObsessionSystem.value()
		ConfidantSystem.record_confession(fx.substr(12))
		ObsessionSystem.add(before - ObsessionSystem.value())
	elif fx.begins_with("rival_reveal:"):
		GameState.rivals[fx.substr(13)] = "active"


func _finish() -> void:
	GameState.set_flag(&"prologue_done")
	SaveManager.save(0)
	set_process_unhandled_input(false)
	if next_scene != "":
		get_tree().change_scene_to_file(next_scene)


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.16, 0.16, 0.18)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_scene_title = Label.new()
	_scene_title.position = Vector2(40, 24)
	_scene_title.add_theme_font_size_override("font_size", 22)
	add_child(_scene_title)

	_obsession = ProgressBar.new()
	_obsession.position = Vector2(980, 28)
	_obsession.size = Vector2(260, 22)
	_obsession.modulate = COLOR_INNER
	add_child(_obsession)

	_stage = Label.new()
	_stage.position = Vector2(80, 120)
	_stage.size = Vector2(1120, 120)
	_stage.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stage.modulate = Color(0.7, 0.7, 0.72)
	add_child(_stage)

	_speaker = Label.new()
	_speaker.position = Vector2(80, 380)
	_speaker.add_theme_font_size_override("font_size", 20)
	add_child(_speaker)

	_public = _bubble(Vector2(80, 420), COLOR_PUBLIC)
	_inner = _bubble(Vector2(80, 540), COLOR_INNER)


func _bubble(pos: Vector2, color: Color) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.position = pos
	r.size = Vector2(1120, 100)
	r.add_theme_color_override("default_color", color)
	r.add_theme_font_size_override("normal_font_size", 22)
	r.add_theme_font_size_override("italics_font_size", 22)
	add_child(r)
	return r
