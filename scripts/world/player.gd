class_name WorldPlayer extends CharacterBody2D
## Espectro Cinza. WASD/setas para andar. A cor esquenta com a Obsessão.

const RADIUS := 16.0

var speed := 230.0
var frozen := false
var tint := Color(0.62, 0.62, 0.66)
var aura := 0.0     # 0..1, contorno rosa conforme a Obsessão


func _ready() -> void:
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 14.0
	cs.shape = c
	add_child(cs)
	var l := Label.new()
	l.text = "Espectro Cinza"
	l.position = Vector2(-80, -46)
	l.size = Vector2(160, 20)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color("#ffd0e6"))
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	add_child(l)


func set_obsession(v: float) -> void:
	aura = clampf((v - 25.0) / 75.0, 0.0, 1.0)
	tint = Color(0.62, 0.62, 0.66).lerp(Color(0.45, 0.42, 0.47), aura)
	queue_redraw()


func _physics_process(_delta: float) -> void:
	if frozen:
		velocity = Vector2.ZERO
		return
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	dir += Vector2(
		int(Input.is_physical_key_pressed(KEY_D)) - int(Input.is_physical_key_pressed(KEY_A)),
		int(Input.is_physical_key_pressed(KEY_S)) - int(Input.is_physical_key_pressed(KEY_W)))
	velocity = dir.limit_length(1.0) * speed
	move_and_slide()


func _draw() -> void:
	draw_circle(Vector2(0, 4), RADIUS, Color(0, 0, 0, 0.25))
	draw_circle(Vector2.ZERO, RADIUS, tint)
	draw_arc(Vector2.ZERO, RADIUS, 0, TAU, 32, Color(0.85, 0.85, 0.88), 2.0)
	if aura > 0.0:
		draw_arc(Vector2.ZERO, RADIUS + 4, 0, TAU, 32, Color(1.0, 0.5, 0.75, 0.3 + aura * 0.7), 2.0 + aura * 3.0)
