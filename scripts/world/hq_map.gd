class_name HQMap extends Node2D
## A Sede do Movimento explorável (fase da Tarde). WASD anda, E interage, C abre o celular.
## Regras continuam no WeekRunner; aqui ficam espaço, tempo, rotinas e testemunhas.

signal finished

const MAP_PATH := "res://data/maps/sede.json"
const WALL := 10.0
const TALK_RANGE := 70.0
const HOTSPOT_RANGE := 60.0
const OBSERVE_RANGE := Vector2(90, 360)
const AUDIENCE_RANGE := 320.0
const RENAN_PROXIMITY := 220.0
const RENAN_OBSESSION_PER_MIN := 0.25
const RENAN_OBSESSION_DAILY_CAP := 8.0

var runner: WeekRunner
var map: Dictionary
var graph := MapGraph.new()
var clock := 0.0
var clock_end := 0.0
var minutes_per_second := 2.0

var player: WorldPlayer
var npcs: Array[WorldNPC] = []
var hotspots := {}           # id -> def (com pos)
var _fired_events := {}
var _renan_obsession_today := 0.0
var _seen_renan_today := false
var _done := false
var _modal := false

# HUD
var _hud: CanvasLayer
var _clock_label: Label
var _room_label: Label
var _metrics_label: Label
var _watch_label: Label
var _prompt: Label
var _thought: Label
var _thought_time := 0.0
var _log: RichTextLabel
var _panel: PanelContainer
var _panel_box: VBoxContainer


func setup(week_runner: WeekRunner) -> void:
	runner = week_runner


func _ready() -> void:
	map = JSON.parse_string(FileAccess.get_file_as_string(MAP_PATH))
	graph.load_from(map)
	clock = MapGraph.parse_time(map.clock.start)
	clock_end = MapGraph.parse_time(map.clock.end)
	minutes_per_second = float(map.clock.game_minutes_per_second)
	_build_world()
	_build_hud()
	EventBus.obsession_changed.connect(_on_obsession_changed)
	EventBus.metric_changed.connect(func(_k, _v, _d): _refresh_hud())
	player.set_obsession(ObsessionSystem.value())
	_log_line("🏢 Você chega à %s. São %s." % [map.name, MapGraph.format_time(clock)])
	_refresh_hud()


func _on_obsession_changed(v: float, _d: float) -> void:
	player.set_obsession(v)
	_refresh_hud()


# --- Construção ---------------------------------------------------------------

func _build_world() -> void:
	var floor_layer := Node2D.new()
	floor_layer.z_index = -10
	add_child(floor_layer)
	for r in map.rooms:
		var rect := ColorRect.new()
		rect.position = Vector2(r.rect[0], r.rect[1])
		rect.size = Vector2(r.rect[2], r.rect[3])
		rect.color = Color(r.floor)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		floor_layer.add_child(rect)
		var name_label := Label.new()
		name_label.text = r.name.to_upper()
		name_label.position = rect.position + Vector2(14, 10)
		name_label.modulate = Color(1, 1, 1, 0.35)
		name_label.add_theme_font_size_override("font_size", 15)
		floor_layer.add_child(name_label)
	for pr in map.props:
		var prop := ColorRect.new()
		prop.position = Vector2(pr.rect[0], pr.rect[1])
		prop.size = Vector2(pr.rect[2], pr.rect[3])
		prop.color = Color(0.2, 0.2, 0.23, 0.9)
		prop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		floor_layer.add_child(prop)
		var pl := Label.new()
		pl.text = pr.label
		pl.position = prop.position
		pl.size = prop.size
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pl.add_theme_font_size_override("font_size", 11)
		pl.modulate = Color(1, 1, 1, 0.7)
		floor_layer.add_child(pl)

	var walls := StaticBody2D.new()
	walls.collision_layer = 1
	add_child(walls)
	var wall_draw := Node2D.new()
	wall_draw.z_index = -5
	add_child(wall_draw)
	for seg in graph.wall_segments(float(map.door_width)):
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var rect := Rect2(a, b - a).abs().grow(WALL / 2.0)
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		cs.shape = shape
		cs.position = rect.get_center()
		walls.add_child(cs)
		var wr := ColorRect.new()
		wr.position = rect.position
		wr.size = rect.size
		wr.color = Color(0.12, 0.12, 0.14)
		wr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wall_draw.add_child(wr)

	for h in map.hotspots:
		var hd: Dictionary = h.duplicate()
		hd.pos = graph.spots[h.spot].pos
		hotspots[h.id] = hd
		var marker := Label.new()
		marker.text = "✦"
		marker.position = hd.pos + Vector2(-6, -12)
		marker.modulate = Color("#ffd0e6")
		marker.z_index = -4
		add_child(marker)

	for def in map.npcs:
		if def.get("is_rival", false) and def.id == runner.rival_id and not runner.rival_active():
			continue   # rival já neutralizada não volta
		if def.get("is_rival", false) and def.id != runner.rival_id:
			continue   # rivais de outras semanas
		var n := WorldNPC.new()
		add_child(n)
		n.setup(def, graph, clock)
		npcs.append(n)

	player = WorldPlayer.new()
	player.collision_layer = 2
	player.collision_mask = 1
	player.position = graph.spots[map.player_start].pos
	add_child(player)
	var cam := Camera2D.new()
	cam.zoom = Vector2(1.15, 1.15)
	cam.position_smoothing_enabled = true
	player.add_child(cam)
	cam.make_current()


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	add_child(_hud)
	var top := ColorRect.new()
	top.color = Color(0.08, 0.08, 0.1, 0.85)
	top.position = Vector2.ZERO
	top.size = Vector2(1280, 64)
	_hud.add_child(top)
	_clock_label = _hud_label(Vector2(20, 8), 26)
	_room_label = _hud_label(Vector2(120, 14), 18)
	_metrics_label = _hud_label(Vector2(20, 40), 13)
	_metrics_label.modulate = Color(0.85, 0.85, 0.9)
	_watch_label = _hud_label(Vector2(1060, 14), 18)

	_prompt = _hud_label(Vector2(340, 600), 18)
	_prompt.size = Vector2(600, 30)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_prompt.add_theme_constant_override("outline_size", 5)

	_thought = _hud_label(Vector2(240, 80), 20)
	_thought.size = Vector2(800, 60)
	_thought.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_thought.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_thought.add_theme_color_override("font_color", Color("#ffb8dc"))
	_thought.add_theme_color_override("font_outline_color", Color.BLACK)
	_thought.add_theme_constant_override("outline_size", 6)

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.position = Vector2(16, 632)
	_log.size = Vector2(1248, 80)
	_log.add_theme_font_size_override("normal_font_size", 14)
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var log_bg := ColorRect.new()
	log_bg.color = Color(0.08, 0.08, 0.1, 0.75)
	log_bg.position = Vector2(0, 628)
	log_bg.size = Vector2(1280, 92)
	_hud.add_child(log_bg)
	_hud.add_child(_log)

	_panel = PanelContainer.new()
	_panel.position = Vector2(340, 150)
	_panel.custom_minimum_size = Vector2(600, 0)
	_panel.visible = false
	_hud.add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	_panel.add_child(margin)
	_panel_box = VBoxContainer.new()
	_panel_box.add_theme_constant_override("separation", 8)
	margin.add_child(_panel_box)


func _hud_label(pos: Vector2, size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	_hud.add_child(l)
	return l


# --- Loop -----------------------------------------------------------------------

func _process(delta: float) -> void:
	if _done:
		return
	if _thought_time > 0.0:
		_thought_time -= delta
		_thought.modulate.a = clampf(_thought_time, 0.0, 1.0)
	if _modal:
		return
	var before := clock
	clock = minf(clock + delta * minutes_per_second, clock_end)
	_tick_minutes(clock - before)
	_refresh_hud()
	if clock >= clock_end:
		_end_afternoon("🕕 18h. O expediente acaba. A Missão continua amanhã.")


func _physics_process(_delta: float) -> void:
	if player == null:
		return
	var space := get_world_2d().direct_space_state
	for n in npcs:
		if not n.visible:
			n.set_sees_player(false)
			n.player_sees = false
			continue
		var d := n.position.distance_to(player.position)
		var los := d < maxf(n.vision, OBSERVE_RANGE.y) and _clear_line(space, n.position, player.position)
		n.set_sees_player(los and d < n.vision)
		n.player_sees = los


func _clear_line(space: PhysicsDirectSpaceState2D, a: Vector2, b: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(a, b, 1)
	return space.intersect_ray(q).is_empty()


func _tick_minutes(mins: float) -> void:
	for n in npcs:
		n.update_time(clock)
	var renan := _npc("renan")
	if renan and renan.player_sees and renan.position.distance_to(player.position) < RENAN_PROXIMITY:
		if not _seen_renan_today:
			_seen_renan_today = true
			_think(_pick(map.thoughts.renan_seen))
		var gain := minf(mins * RENAN_OBSESSION_PER_MIN, RENAN_OBSESSION_DAILY_CAP - _renan_obsession_today)
		if gain > 0.0:
			_renan_obsession_today += gain
			ObsessionSystem.add(gain)
	_check_events()


func _check_events() -> void:
	for ev in map.events:
		if _fired_events.has(ev.id) or clock < MapGraph.parse_time(ev.at):
			continue
		_fired_events[ev.id] = true
		if ev.type == "rival_with_senpai" and runner.rival_active():
			var r := _npc("renan")
			var j := _npc(runner.rival_id)
			if r and j and r.current_room == ev.room and j.current_room == ev.room:
				if graph.room_at(player.position) == ev.room:
					runner.apply_effects(ev.interrupted_effects)
					_log_line(ev.interrupted_text)
				else:
					runner.apply_effects(ev.effects)
					_log_line(ev.text)
					_think(ev.inner)


## Ações custam tempo: o relógio pula e os NPCs se reposicionam.
func _advance_minutes(mins: float) -> void:
	var before := clock
	clock = minf(clock + mins, clock_end)
	for n in npcs:
		n.snap_to_time(clock)
	_tick_minutes(clock - before)
	_refresh_hud()


# --- Interação ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _done or not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_E, KEY_ENTER, KEY_SPACE:
			if not _modal:
				open_interactions()
		KEY_C:
			if not _modal:
				open_phone()
		KEY_ESCAPE:
			close_panel()


func interaction_options() -> Array:
	var opts := []
	var hs := _nearest_hotspot()
	if not hs.is_empty():
		if hs.get("exit", false):
			opts.append({"label": "🚪 Ir para casa (encerra a tarde)", "cb": func(): _end_afternoon("Você vai embora mais cedo. Ponderadamente.")})
		for a in runner.data.hq_actions:
			if a.get("map", {}).get("hotspot", "") == hs.id:
				var act: Dictionary = a
				opts.append({"label": "%s (%d min)" % [a.label, a.map.minutes], "cb": func(): _do_action(act)})
		if hs.has("flavor"):
			var fl: Dictionary = hs.flavor
			opts.append({"label": fl.label, "cb": func(): _do_flavor(fl)})
	var npc := _nearest_npc(TALK_RANGE)
	if npc:
		var talk: WorldNPC = npc
		opts.append({"label": "💬 Conversar com %s" % npc.display_name, "cb": func(): _bark(talk)})
		for m in runner.data.methods:
			if m.get("map", {}).get("target", "") != npc.id:
				continue
			var meth: Dictionary = m
			var enabled := runner.rival_active() and runner.method_unlocked(m) and runner.requirements_met(m)
			var label: String = m.label
			if enabled:
				label = "🎯 %s  [%d%%]" % [m.label, int(runner.method_chance(m) * 100)]
				var aud := int(m.map.get("needs_audience", 0))
				if aud > 0:
					label += "  (plateia: %d/%d)" % [_audience(npc).size(), aud]
			elif not runner.method_unlocked(m):
				label = "%s — %s" % [m.label, m.get("locked_text", "bloqueado")]
			else:
				label = "🔒 %s — falta preparo (observe ou peça a ficha ao Teacher)" % m.label
			opts.append({"label": label, "cb": func(): _do_method(meth, talk), "disabled": not enabled})
	for n in npcs:
		if not (n.is_rival and n.visible and runner.rival_active() and n.player_sees):
			continue
		var d := n.position.distance_to(player.position)
		if d < OBSERVE_RANGE.x or d > OBSERVE_RANGE.y:
			continue
		for a in runner.data.hq_actions:
			if a.get("map", {}).get("observe", "") == n.id:
				var act: Dictionary = a
				opts.append({"label": "👀 %s (%d min)" % [a.label, a.map.minutes], "cb": func(): _do_action(act)})
	return opts


func open_interactions() -> void:
	var opts := interaction_options()
	if opts.is_empty():
		_think(_pick(["Nada aqui. Só eu e meus pensamentos. Muitos pensamentos.", "Ponderada. Andando. Ponderadamente."]))
		return
	_open_menu("O que fazer?", opts)


func open_phone() -> void:
	var opts := []
	for s in runner.data.teacher_services:
		var svc: Dictionary = s
		opts.append({"label": "📞 " + s.label, "cb": func(): _do_service(svc),
			"disabled": GameState.has_flag(StringName(s.sets_flag))})
	opts.append({"label": "📊 Atenção do Renan para %s: %d/100" % [runner.data.rival.name, runner.rival_attention()], "cb": func(): pass, "disabled": true})
	_open_menu("📱 Celular", opts)


func _do_action(a: Dictionary) -> void:
	var r := runner.do_action(a.id)
	_advance_minutes(float(a.map.minutes))
	_show_result(r.public, r.inner, r.result)


func _do_flavor(f: Dictionary) -> void:
	runner.apply_effects(f.get("effects", {}))
	_advance_minutes(float(f.minutes))
	_show_result("", f.inner, "")


func _do_method(m: Dictionary, target: WorldNPC) -> void:
	var need := int(m.map.get("needs_audience", 0))
	var audience := _audience(target)
	if audience.size() < need:
		_show_result("", "Elogio sem plateia é só conversa. Preciso de pelo menos %d pessoas olhando." % need, "Leve a Júlia para um lugar movimentado (a Redação, por exemplo).")
		return
	var watchers := _watchers(target)
	var witnessed := 1 if float(m.get("witness_chance", 0.0)) >= 1.0 else (1 if not watchers.is_empty() else 0)
	var r := runner.try_method(m.id, witnessed)
	_advance_minutes(float(m.map.get("minutes", 30)))
	var result: String = ("✅ " if r.ok else "❌ ") + r.text
	if r.witnessed and not watchers.is_empty():
		result += "\n👀 Testemunhas: " + ", ".join(PackedStringArray(watchers.map(func(n): return n.display_name)))
	elif r.witnessed:
		result += "\n👀 Todo mundo viu. Era essa a ideia."
	if not runner.rival_active():
		result += "\n🎉 %s saiu de cena." % runner.data.rival.name
		target.leave("saida")
	_show_result(r.public, r.inner, result)


func _do_service(s: Dictionary) -> void:
	var r := runner.use_teacher_service(s.id)
	_show_result("", "", "🎙️ Você manda um áudio para o Teacher.\n\nWELLINGTON: %s\n\n📼 Nova gravação no Arquivo (gravidade %d). Transcrição fictícia." % [r.teacher, r.severity])


func _bark(n: WorldNPC) -> void:
	_show_result("", "", "%s: “%s”" % [n.display_name, _pick(n.barks)])


## NPCs (exceto o alvo) que estão vendo a Espectro Cinza agora.
func _watchers(exclude: WorldNPC) -> Array:
	return npcs.filter(func(n): return n != exclude and n.visible and n.sees_player)


## NPCs (exceto o alvo) perto e com linha de visão: a "plateia".
func _audience(exclude: WorldNPC) -> Array:
	return npcs.filter(func(n): return n != exclude and n.visible and n.player_sees \
		and n.position.distance_to(player.position) < AUDIENCE_RANGE)


func _nearest_npc(max_dist: float) -> WorldNPC:
	var best: WorldNPC = null
	var bd := max_dist
	for n in npcs:
		if not n.visible:
			continue
		var d := n.position.distance_to(player.position)
		if d < bd:
			bd = d
			best = n
	return best


func _nearest_hotspot() -> Dictionary:
	var best := {}
	var bd := HOTSPOT_RANGE
	for id in hotspots:
		var d: float = hotspots[id].pos.distance_to(player.position)
		if d < bd:
			bd = d
			best = hotspots[id]
	return best


func _npc(id: String) -> WorldNPC:
	for n in npcs:
		if n.id == id and n.visible:
			return n
	return null


# --- UI -------------------------------------------------------------------------

func _open_menu(title: String, opts: Array) -> void:
	_clear_panel()
	_panel_title(title)
	for o in opts:
		var b := Button.new()
		b.text = o.label
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = o.get("disabled", false)
		var cb: Callable = o.cb
		b.pressed.connect(_on_menu_pick.bind(cb))
		_panel_box.add_child(b)
	var cancel := Button.new()
	cancel.text = "Voltar (Esc)"
	cancel.pressed.connect(close_panel)
	_panel_box.add_child(cancel)
	_show_panel()


func _on_menu_pick(cb: Callable) -> void:
	close_panel()
	cb.call()


func _show_result(public_text: String, inner_text: String, result: String) -> void:
	_clear_panel()
	if public_text != "":
		_panel_text("[b]ESPECTRO CINZA:[/b] " + public_text, "#d2d2d6")
	if inner_text != "":
		_panel_text("[i](pensando) %s[/i]" % inner_text, "#ffb8dc")
	if result != "":
		_panel_text(result, "#b0b0b8")
		_log_line(result.split("\n")[0])
	var ok := Button.new()
	ok.text = "OK"
	ok.pressed.connect(close_panel)
	_panel_box.add_child(ok)
	_show_panel()


func _panel_title(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 20)
	_panel_box.add_child(l)


func _panel_text(bb: String, color: String) -> void:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.custom_minimum_size = Vector2(568, 0)
	r.text = "[color=%s]%s[/color]" % [color, bb]
	_panel_box.add_child(r)


func _clear_panel() -> void:
	for c in _panel_box.get_children():
		_panel_box.remove_child(c)
		c.queue_free()


func _show_panel() -> void:
	_modal = true
	player.frozen = true
	_panel.visible = true
	_panel.reset_size()
	var first := _panel_box.get_children().filter(func(c): return c is Button and not c.disabled)
	if not first.is_empty():
		first[0].grab_focus()


func close_panel() -> void:
	_panel.visible = false
	_modal = false
	if player:
		player.frozen = false


func is_menu_open() -> bool:
	return _panel.visible


func _refresh_hud() -> void:
	if _clock_label == null:
		return
	_clock_label.text = MapGraph.format_time(clock)
	var room := graph.room_at(player.position)
	_room_label.text = graph.room_names.get(room, "")
	var m := GameState.metrics
	_metrics_label.text = "Obsessão %d (%s) · Credibilidade %d · Narrativa %d · Risco Jurídico %d · Suspeita %d · Atenção do Renan p/ %s: %d" % [
		m.get(&"obsession", 0), ObsessionSystem.tier_name(), m.get(&"credibility", 0),
		m.get(&"narrative_control", 0), m.get(&"legal_risk", 0), m.get(&"suspicion", 0),
		runner.data.rival.name.split(" ")[0], runner.rival_attention()]
	var w := npcs.filter(func(n): return n.visible and n.sees_player).size()
	_watch_label.text = ("👁 %d olhando" % w) if w > 0 else "👁 ninguém olhando"
	if not _modal:
		var opts := interaction_options()
		_prompt.text = ("[E] interagir (%d)   [C] celular" % opts.size()) if not opts.is_empty() else "[WASD] andar   [C] celular"


func _think(t: String) -> void:
	_thought.text = t
	_thought_time = 4.0
	_thought.modulate.a = 1.0


func _log_line(t: String) -> void:
	_log.append_text("[color=#a0a0a8]%s  [/color]%s\n" % [MapGraph.format_time(clock), t])


func _pick(arr: Array) -> String:
	return arr[runner.rng.randi() % arr.size()] if not arr.is_empty() else ""


func _end_afternoon(msg: String) -> void:
	if _done:
		return
	_done = true
	close_panel()
	_log_line(msg)
	finished.emit()
