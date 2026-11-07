class_name WorldNPC extends Node2D
## NPC com rotina por horário. Anda de spot em spot passando pelas portas.

signal arrived(npc: WorldNPC, spot: String)

const RADIUS := 16.0

var id := ""
var display_name := ""
var color := Color.WHITE
var is_rival := false
var is_senpai := false
var vision := 260.0
var barks: Array = []
var graph: MapGraph

var current_room := ""
var current_spot := ""
var gone := false
## Calculado pelo mapa a cada frame de física.
var sees_player := false
var player_sees := false

var _routine := []      # [{min, spot}]
var _path := []         # [{pos, room}]
var _target_spot := ""
var _speed := 120.0
var _label: Label


func setup(def: Dictionary, g: MapGraph, clock_min: float) -> void:
	graph = g
	id = def.id
	display_name = def.name
	color = Color(def.color)
	is_rival = def.get("is_rival", false)
	is_senpai = def.get("is_senpai", false)
	vision = float(def.get("vision", 260))
	barks = def.get("barks", [])
	for r in def.routine:
		_routine.append({"min": MapGraph.parse_time(r.at), "spot": r.spot})
	_label = Label.new()
	_label.text = display_name
	_label.position = Vector2(-80, -44)
	_label.size = Vector2(160, 20)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	add_child(_label)
	snap_to_time(clock_min)


func spot_for_time(m: float) -> String:
	var s: String = _routine[0].spot
	for r in _routine:
		if m >= r.min:
			s = r.spot
	return s


func snap_to_time(m: float) -> void:
	if gone:
		return
	var s := spot_for_time(m)
	current_spot = s
	_target_spot = s
	current_room = graph.spots[s].room
	position = graph.spots[s].pos
	_path.clear()


func update_time(m: float) -> void:
	if gone:
		return
	var s := spot_for_time(m)
	if s != _target_spot:
		go_to(s)


func go_to(s: String) -> void:
	_target_spot = s
	_path = graph.path_points(current_room, graph.spots[s].room)
	_path.append({"pos": graph.spots[s].pos, "room": graph.spots[s].room})


## Sai de cena pela recepção (rival neutralizada).
func leave(exit_spot: String) -> void:
	go_to(exit_spot)
	gone = true


func is_walking() -> bool:
	return not _path.is_empty()


func _process(delta: float) -> void:
	if _path.is_empty():
		return
	var step: Dictionary = _path[0]
	position = position.move_toward(step.pos, _speed * delta)
	if position.distance_to(step.pos) < 1.0:
		current_room = step.room
		_path.remove_at(0)
		if _path.is_empty():
			current_spot = _target_spot
			if gone:
				visible = false
			arrived.emit(self, current_spot)


func _draw() -> void:
	draw_circle(Vector2(0, 4), RADIUS, Color(0, 0, 0, 0.25))
	draw_circle(Vector2.ZERO, RADIUS, color)
	draw_arc(Vector2.ZERO, RADIUS, 0, TAU, 32, Color(0.1, 0.1, 0.12), 2.0)
	if is_rival:
		draw_arc(Vector2.ZERO, RADIUS + 5, 0, TAU, 32, Color("#ff7fbf"), 2.0)
	if is_senpai:
		draw_arc(Vector2.ZERO, RADIUS + 5, 0, TAU, 32, Color("#ffd76a"), 2.0)
	if sees_player:
		draw_string(ThemeDB.fallback_font, Vector2(-8, -RADIUS - 30), "👁", HORIZONTAL_ALIGNMENT_LEFT, -1, 14)


func set_sees_player(v: bool) -> void:
	if v != sees_player:
		sees_player = v
		queue_redraw()
