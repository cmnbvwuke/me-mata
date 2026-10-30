class_name WaypointMarker
extends Control
## Marcador de objetivo projetado na tela (losango + distância).
## Quando o alvo está fora da tela, fica preso na borda.

var camera: Camera3D
var target: Variant = null   # Vector3 ou null
var color: Color = Color(1.0, 0.72, 0.25)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if camera == null or not (target is Vector3):
		return
	var pos: Vector3 = target
	var margin := 48.0
	var sp := camera.unproject_position(pos)
	var behind := camera.is_position_behind(pos)
	if behind:
		sp = size - sp
		sp.y = size.y - margin
	var clamped := Vector2(clampf(sp.x, margin, size.x - margin), clampf(sp.y, margin, size.y - margin))
	var off_screen := behind or clamped != sp
	var s := 9.0
	var pts := PackedVector2Array([clamped + Vector2(0, -s), clamped + Vector2(s, 0), clamped + Vector2(0, s), clamped + Vector2(-s, 0)])
	var alpha := 0.55 if off_screen else 0.9
	draw_colored_polygon(pts, Color(color, alpha * 0.35))
	pts.append(pts[0])
	draw_polyline(pts, Color(color, alpha), 2.0)
	var dist := camera.global_position.distance_to(pos)
	var font := get_theme_default_font()
	draw_string(font, clamped + Vector2(-30, 28), "%d m" % int(dist), HORIZONTAL_ALIGNMENT_CENTER, 60, 15, Color(color, alpha))
