class_name Crosshair
extends Control
## Mira dinâmica: o espaçamento das linhas reflete a dispersão real da arma.
## Também desenha o hitmarker (branco = acerto, vermelho = abate).

var spread_deg: float = 2.0
var fov: float = 75.0
var opacity: float = 1.0
var _hit_time := 0.0
var _hit_kill := false
var _hit_head := false

const HIT_DURATION := 0.28


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func show_hit(killed: bool, headshot: bool) -> void:
	_hit_time = HIT_DURATION
	_hit_kill = killed
	_hit_head = headshot


func _process(delta: float) -> void:
	_hit_time = maxf(_hit_time - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var half_h := size.y * 0.5
	var gap := tan(deg_to_rad(spread_deg)) / tan(deg_to_rad(fov * 0.5)) * half_h + 3.0
	if opacity > 0.01:
		var col := Color(0.95, 0.95, 0.92, 0.85 * opacity)
		var shadow := Color(0, 0, 0, 0.5 * opacity)
		for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			var dir: Vector2 = d
			draw_line(c + dir * gap + Vector2(1, 1), c + dir * (gap + 9.0) + Vector2(1, 1), shadow, 2.0)
			draw_line(c + dir * gap, c + dir * (gap + 9.0), col, 2.0)
		draw_circle(c, 1.2, col)
	if _hit_time > 0.0:
		var a := _hit_time / HIT_DURATION
		var hc := Color(1.0, 0.18, 0.12, a) if _hit_kill else Color(1, 1, 1, a)
		var inner := 6.0
		var outer := 15.0 if _hit_kill else 12.0
		for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var dir: Vector2 = (d as Vector2).normalized()
			draw_line(c + dir * inner, c + dir * outer, hc, 3.0 if _hit_head else 2.0)
