class_name MapGraph extends RefCounted
## Planta do mapa: salas (retângulos), portas (pontos nas paredes) e spots nomeados.
## Gera as paredes com vãos nas portas e calcula caminhos sala→sala por BFS.

var rooms := {}        # id -> Rect2
var room_names := {}   # id -> String
var doors := []        # [{pos: Vector2, a: String, b: String}]
var spots := {}        # id -> {room: String, pos: Vector2}


func load_from(d: Dictionary) -> void:
	for r in d.rooms:
		rooms[r.id] = Rect2(r.rect[0], r.rect[1], r.rect[2], r.rect[3])
		room_names[r.id] = r.name
	for dp in d.doors:
		var p := Vector2(dp[0], dp[1])
		var touching := []
		for id in rooms:
			if on_boundary(rooms[id], p):
				touching.append(id)
		if touching.size() == 2:
			doors.append({"pos": p, "a": touching[0], "b": touching[1]})
		else:
			push_warning("Porta %s toca %d salas" % [p, touching.size()])
	for id in d.spots:
		var s: Dictionary = d.spots[id]
		spots[id] = {"room": s.room, "pos": Vector2(s.pos[0], s.pos[1])}


static func on_boundary(r: Rect2, p: Vector2) -> bool:
	var e := 1.0
	var on_h := (absf(p.y - r.position.y) < e or absf(p.y - r.end.y) < e) and p.x > r.position.x and p.x < r.end.x
	var on_v := (absf(p.x - r.position.x) < e or absf(p.x - r.end.x) < e) and p.y > r.position.y and p.y < r.end.y
	return on_h or on_v


func room_at(p: Vector2) -> String:
	for id in rooms:
		if rooms[id].grow(-1.0).has_point(p):
			return id
	return ""


## Caminho de from_room até to_room: [{pos, room}], onde room é a sala em que se entra.
func path_points(from_room: String, to_room: String) -> Array:
	if from_room == to_room:
		return []
	var prev := {from_room: null}
	var queue := [from_room]
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		if cur == to_room:
			break
		for d in doors:
			var nxt := ""
			if d.a == cur:
				nxt = d.b
			elif d.b == cur:
				nxt = d.a
			if nxt != "" and not prev.has(nxt):
				prev[nxt] = [cur, d]
				queue.append(nxt)
	if not prev.has(to_room):
		return []
	var out := []
	var node := to_room
	while prev[node] != null:
		var link: Array = prev[node]
		out.push_front({"pos": link[1].pos, "room": node})
		node = link[0]
	return out


## Segmentos de parede [a, b], com vão de door_width em cada porta.
func wall_segments(door_width: float) -> Array:
	var segs := []
	for id in rooms:
		var r: Rect2 = rooms[id]
		var c := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
		for i in 4:
			segs.append_array(_split(c[i], c[(i + 1) % 4], door_width))
	return segs


func _split(a: Vector2, b: Vector2, w: float) -> Array:
	var horizontal := is_equal_approx(a.y, b.y)
	var lo := minf(a.x, b.x) if horizontal else minf(a.y, b.y)
	var hi := maxf(a.x, b.x) if horizontal else maxf(a.y, b.y)
	var cuts := []
	for d in doors:
		var p: Vector2 = d.pos
		if horizontal and absf(p.y - a.y) < 1.0 and p.x > lo and p.x < hi:
			cuts.append(p.x)
		elif not horizontal and absf(p.x - a.x) < 1.0 and p.y > lo and p.y < hi:
			cuts.append(p.y)
	cuts.sort()
	var out := []
	var cur := lo
	for cut in cuts:
		if cut - w / 2.0 > cur:
			out.append(_seg(horizontal, a, cur, cut - w / 2.0))
		cur = cut + w / 2.0
	if hi > cur:
		out.append(_seg(horizontal, a, cur, hi))
	return out


func _seg(h: bool, a: Vector2, s: float, e: float) -> Array:
	return [Vector2(s, a.y), Vector2(e, a.y)] if h else [Vector2(a.x, s), Vector2(a.x, e)]


static func parse_time(s: String) -> int:
	var p := s.split(":")
	return int(p[0]) * 60 + int(p[1])


static func format_time(minutes: float) -> String:
	var m := int(minutes)
	return "%02d:%02d" % [m / 60, m % 60]
