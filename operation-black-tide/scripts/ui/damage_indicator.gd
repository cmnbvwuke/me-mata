class_name DamageIndicator
extends Control
## Arcos vermelhos ao redor da mira apontando para a origem do dano.

const DURATION := 1.8

var player: Node3D
var _hits: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func add_hit(from_position: Vector3) -> void:
	# Agrupa acertos vindos da mesma direção
	for h in _hits:
		if (h["pos"] as Vector3).distance_to(from_position) < 2.0:
			h["t"] = DURATION
			return
	_hits.append({"pos": from_position, "t": DURATION})


func _process(delta: float) -> void:
	for h in _hits:
		h["t"] = float(h["t"]) - delta
	_hits.assign(_hits.filter(func(h: Dictionary) -> bool: return float(h["t"]) > 0.0))
	queue_redraw()


func _draw() -> void:
	if player == null:
		return
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.17
	for h in _hits:
		var to: Vector3 = (h["pos"] as Vector3) - player.global_position
		var local := player.global_transform.basis.inverse() * to
		var ang := atan2(local.x, -local.z) - PI * 0.5
		var a := clampf(float(h["t"]) / DURATION, 0.0, 1.0)
		draw_arc(c, r, ang - 0.32, ang + 0.32, 18, Color(0.9, 0.06, 0.04, 0.8 * a), 7.0, true)
