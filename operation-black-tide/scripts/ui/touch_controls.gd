class_name TouchControls
extends CanvasLayer
## Controles de toque (celular): joystick flutuante na metade esquerda, olhar
## arrastando na direita e botões de ação. Os botões disparam as mesmas ações
## do teclado (Input.action_press), então o resto do jogo não muda.

const LEFT_ZONE := 0.42      # fração da largura que inicia o joystick
const STICK_RADIUS := 120.0
const LOOK_SCALE := 1.0      # multiplicador sobre a sensibilidade do mouse

var player: Player

var _stick_index := -1
var _stick_center := Vector2.ZERO
var _stick_vec := Vector2.ZERO
var _look_index := -1
var _aiming := false
var _buttons: Array[TouchScreenButton] = []
var _stick_draw: Control
var _skip_button: TouchScreenButton
var _aim_button: TouchScreenButton


func _ready() -> void:
	layer = 6
	_stick_draw = Control.new()
	_stick_draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stick_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stick_draw.draw.connect(_draw_stick)
	add_child(_stick_draw)
	var size := get_viewport().get_visible_rect().size
	var r := size.x
	var b := size.y
	# Botões principais (canto inferior direito)
	_add_button("ATIRAR", "fire", Vector2(r - 165, b - 215), 92, Color(0.85, 0.2, 0.15))
	_aim_button = _add_button("MIRAR", "", Vector2(r - 345, b - 145), 62, Color(0.9, 0.75, 0.3))
	_aim_button.pressed.connect(_toggle_aim)
	_add_button("RECARREGAR", "reload", Vector2(r - 335, b - 315), 52)
	_add_button("AGACHAR", "crouch", Vector2(r - 210, b - 395), 50)
	_add_button("PULAR", "jump", Vector2(r - 82, b - 375), 50)
	_add_button("USAR", "interact", Vector2(r - 495, b - 205), 54, Color(0.4, 0.8, 0.5))
	_add_button("TROCAR\nARMA", "switch_weapon", Vector2(r - 480, b - 375), 46)
	# Botões secundários (topo)
	_add_button("PAUSA", "pause", Vector2(r - 62, 58), 38)
	_add_button("LANTERNA", "flashlight", Vector2(r - 162, 58), 38)
	_add_button("VISÃO\nNOTURNA", "nvg", Vector2(r - 262, 58), 38)
	_add_button("APOIO\nAÉREO", "air_support", Vector2(r - 362, 58), 38, Color(0.9, 0.75, 0.3))
	_skip_button = _add_button("PULAR\nINTRO", "skip_intro", Vector2(size.x * 0.5, 64), 44)


func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player
	var cinematic := player != null and player.cinematic_mode
	_skip_button.visible = cinematic
	visible = not get_tree().paused
	# Mira desliga sozinha ao trocar de arma / recarregar / morrer
	if _aiming and player and (player.is_dead or cinematic):
		_set_aim(false)


## Botão redondo com texto (TouchScreenButton aceita vários toques ao mesmo tempo).
func _add_button(text: String, action: String, center: Vector2, radius: float,
		tint: Color = Color(0.85, 0.85, 0.85)) -> TouchScreenButton:
	var b := TouchScreenButton.new()
	b.texture_normal = _circle_texture(radius, tint, 0.28)
	b.texture_pressed = _circle_texture(radius, tint, 0.55)
	var shape := CircleShape2D.new()
	shape.radius = radius
	b.shape = shape
	b.shape_centered = true
	b.position = center - Vector2(radius, radius)
	b.action = action
	b.passby_press = false
	add_child(b)
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(radius * 2, radius * 2)
	var longest := 0
	for line in text.split("\n"):
		longest = maxi(longest, line.length())
	label.add_theme_font_size_override("font_size", int(clampf(radius * 0.32 * minf(1.0, 8.0 / longest), 11, 22)))
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(label)
	_buttons.append(b)
	return b


func _circle_texture(radius: float, tint: Color, alpha: float) -> Texture2D:
	var d := int(radius * 2)
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var c := Vector2(radius, radius)
	for y in d:
		for x in d:
			var dist := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var a := clampf(radius - dist, 0.0, 1.0)
			var ring := 1.0 if dist > radius - 3.0 else 0.0
			img.set_pixel(x, y, Color(tint.r, tint.g, tint.b, a * (alpha + ring * 0.35)))
	return ImageTexture.create_from_image(img)


func _toggle_aim() -> void:
	_set_aim(not _aiming)


func _set_aim(on: bool) -> void:
	_aiming = on
	if on:
		Input.action_press("aim")
	else:
		Input.action_release("aim")
	_aim_button.modulate = Color(1.4, 1.4, 1.0) if on else Color.WHITE


func _on_button(pos: Vector2) -> bool:
	for b in _buttons:
		if not b.visible:
			continue
		var r: float = (b.shape as CircleShape2D).radius
		if pos.distance_to(b.position + Vector2(r, r)) <= r:
			return true
	return false


func _input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if _on_button(t.position):
				return
			var width := get_viewport().get_visible_rect().size.x
			if t.position.x < width * LEFT_ZONE and _stick_index < 0:
				_stick_index = t.index
				_stick_center = t.position
				_stick_vec = Vector2.ZERO
			elif _look_index < 0:
				_look_index = t.index
		else:
			if t.index == _stick_index:
				_stick_index = -1
				_stick_vec = Vector2.ZERO
				_apply_stick()
			elif t.index == _look_index:
				_look_index = -1
		_stick_draw.queue_redraw()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _stick_index:
			_stick_vec = ((d.position - _stick_center) / STICK_RADIUS).limit_length(1.0)
			_apply_stick()
			_stick_draw.queue_redraw()
		elif d.index == _look_index and player:
			player.look(d.relative * LOOK_SCALE)


## Joystick -> ações de movimento com intensidade; empurrado até o fim para a frente = correr.
func _apply_stick() -> void:
	var v := _stick_vec
	_set_axis("move_left", maxf(-v.x, 0.0))
	_set_axis("move_right", maxf(v.x, 0.0))
	_set_axis("move_forward", maxf(-v.y, 0.0))
	_set_axis("move_back", maxf(v.y, 0.0))
	if v.length() > 0.95 and v.y < -0.75:
		Input.action_press("sprint")
	else:
		Input.action_release("sprint")


func _set_axis(action: String, strength: float) -> void:
	if strength > 0.05:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func _draw_stick() -> void:
	if _stick_index < 0:
		# dica discreta de onde fica o joystick
		var hint := Vector2(200, get_viewport().get_visible_rect().size.y - 190)
		_stick_draw.draw_circle(hint, STICK_RADIUS, Color(1, 1, 1, 0.06))
		_stick_draw.draw_arc(hint, STICK_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.18), 2.0)
		return
	_stick_draw.draw_circle(_stick_center, STICK_RADIUS, Color(1, 1, 1, 0.08))
	_stick_draw.draw_arc(_stick_center, STICK_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.3), 2.0)
	_stick_draw.draw_circle(_stick_center + _stick_vec * STICK_RADIUS, 52, Color(1, 1, 1, 0.35))
