extends Control
## Protótipo jogável da semana (texto + botões). Toda a regra fica no WeekRunner.

@export_file("*.json") var week_path := "res://data/weeks/week_01.json"

const COLOR_PUBLIC := "#d2d2d6"
const COLOR_INNER := "#ffb8dc"
const COLOR_STAGE := "#9a9aa0"

var runner := WeekRunner.new()
var _slot := 0
var _live_qs: Array = []
var _live_i := 0

var _header: Label
var _metrics: Label
var _log: RichTextLabel
var _choices: VBoxContainer


func _ready() -> void:
	_build_ui()
	if not runner.load_week(week_path):
		return
	runner.start_week()
	EventBus.obsession_changed.connect(func(_v, _d): _refresh_metrics())
	EventBus.metric_changed.connect(func(_k, _v, _d): _refresh_metrics())
	_say_stage("🎭 SEMANA %d — “%s”" % [runner.data.number, runner.data.title])
	_say_stage("Rival: %s. %s" % [runner.data.rival.name, runner.data.rival.bio])
	_say_stage("Ameaça: " + runner.data.rival.threat)
	_choose([["Começar", _morning]])


# --- Fases ---------------------------------------------------------------------

func _morning() -> void:
	_clear()
	_set_header("Manhã — Feed")
	var ev := runner.feed_event()
	if not ev.is_empty():
		_say_stage(ev.text)
	_say_stage("Escolha o Post do Dia:")
	var opts := []
	for i in runner.posts().size():
		var idx: int = i
		opts.append([runner.posts()[i].label, func(): _on_post(idx)])
	_choose(opts)


func _on_post(i: int) -> void:
	var p := runner.choose_post(i)
	_dual(p.public, p.inner)
	_slot = 0
	_choose([["Ir para a sede do Movimento", _hq]])


func _hq() -> void:
	_clear()
	var slots := runner.hq_slots()
	if _slot >= slots.size():
		_evening()
		return
	_set_header("Tarde — Sede do Movimento (%s)" % slots[_slot])
	var opts := []
	for o in runner.hq_options():
		var label: String = o.label
		if o.type == "method" and o.has("chance"):
			label += "  [%d%%]" % int(o.chance * 100)
		var opt: Dictionary = o
		opts.append([label, func(): _on_hq(opt), not o.enabled])
	_choose(opts)


func _on_hq(o: Dictionary) -> void:
	_clear()
	match o.type:
		"action":
			var a := runner.do_action(o.id)
			_dual(a.public, a.inner)
			_say_stage(a.result)
		"method":
			var r := runner.try_method(o.id)
			if r.locked:
				_say_stage(r.text)
			else:
				_dual(r.public, r.inner)
				_say_stage(("✅ " if r.ok else "❌ ") + r.text)
				if r.witnessed:
					_say_stage("👀 Alguém viu. A Suspeita sobe.")
				if not runner.rival_active():
					_say_stage("🎉 %s saiu de cena." % runner.data.rival.name)
		"service":
			var s := runner.use_teacher_service(o.id)
			_say_stage("🎙️ Você manda um áudio para o Teacher pedindo ajuda.")
			_say("WELLINGTON", s.teacher, COLOR_PUBLIC)
			_say_stage("📼 Nova entrada no Arquivo Wellington (gravidade %d). Transcrição fictícia." % s.severity)
	_slot += 1
	_choose([["Continuar", _hq]])


func _evening() -> void:
	_clear()
	_set_header("Noite — Live “Tons de Cinza”")
	_live_qs = runner.live_questions()
	_live_i = 0
	_next_question()


func _next_question() -> void:
	if _live_i >= _live_qs.size():
		_choose([["Encerrar a live", _night]])
		return
	var q: Dictionary = _live_qs[_live_i]
	_say("CHAT", q.q, COLOR_STAGE)
	var opts := []
	for a in runner.available_answers(q):
		var ans: Dictionary = a
		opts.append(["(%s) %s" % [a.type, a.public], func(): _on_answer(ans)])
	_choose(opts)


func _on_answer(a: Dictionary) -> void:
	var r := runner.answer_live(a)
	_say("ESPECTRO CINZA", r.public, COLOR_PUBLIC)
	if r.leaked:
		_say_stage("⚠️ VAZAMENTO VERBAL! O pensamento escapou na live.")
	_live_i += 1
	_next_question()


func _night() -> void:
	_clear()
	_set_header("Madrugada — Desabafo")
	_say_stage(runner.data.confession.prompt)
	_choose([
		["Mandar um áudio “rapidinho” (−Obsessão, +1 gravação)", _on_confess],
		["Não mandar (a Obsessão sobe)", _on_skip],
	])


func _on_confess() -> void:
	var c := runner.confess()
	_say_stage("🎙️ " + c.transcript)
	_say("WELLINGTON", c.reply, COLOR_PUBLIC)
	_say_stage("📼 Arquivo Wellington: %d gravação(ões). Transcrições fictícias." % GameState.archive.size())
	_choose([["Dormir", _resolution]])


func _on_skip() -> void:
	_say_stage(runner.skip_confession())
	_choose([["Dormir", _resolution]])


func _resolution() -> void:
	_clear()
	_set_header("Resolução — Dia %d" % GameState.day)
	for l in runner.resolve_day():
		_say_stage(l)
	if GameState.has_flag(&"pendrive_active"):
		_say_stage("💾 O Teacher mandou: “We need to talk about the audios, dear.”")
	SaveManager.save(0)
	_choose([["Próximo dia", _saturday if runner.is_weekend() else _morning]])


func _saturday() -> void:
	_clear()
	var c: Dictionary = runner.data.weekend_crisis
	_set_header(c.title)
	_say_stage(c.intro)
	var branch := runner.crisis()
	_say_stage(branch.text)
	if branch.has("choices"):
		var opts := []
		for i in branch.choices.size():
			var idx: int = i
			opts.append([branch.choices[i].label, func(): _on_crisis(idx)])
		_choose(opts)
	else:
		_on_crisis(-1)


func _on_crisis(i: int) -> void:
	var r := runner.resolve_crisis(i)
	_dual(r.public, r.inner)
	_choose([["Domingo", _sunday]])


func _sunday() -> void:
	_clear()
	_set_header("Domingo")
	_say_stage(runner.sunday())
	_choose([["Monólogo da semana", _monologue]])


func _monologue() -> void:
	_clear()
	_set_header("Monólogo Interno")
	for l in runner.monologue():
		if l.has("stage"):
			_say_stage(l.stage)
		if l.has("inner"):
			_log.append_text("[color=%s][i]%s[/i][/color]\n\n" % [COLOR_INNER, l.inner])
	if not runner.rival_active():
		_say_stage("Epílogo de %s: %s" % [runner.data.rival.name, runner.data.rival.epilogue])
	_say_stage(runner.data.monologue.teaser)
	runner.finish_week()
	SaveManager.save(0)
	_choose([["Voltar ao menu", func(): get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")]])


# --- UI helpers ----------------------------------------------------------------

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.14, 0.14, 0.16)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_header = Label.new()
	_header.position = Vector2(32, 16)
	_header.add_theme_font_size_override("font_size", 22)
	add_child(_header)

	_metrics = Label.new()
	_metrics.position = Vector2(32, 50)
	_metrics.modulate = Color(0.8, 0.8, 0.85)
	add_child(_metrics)

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.position = Vector2(32, 84)
	_log.size = Vector2(1216, 380)
	add_child(_log)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(32, 476)
	scroll.size = Vector2(1216, 228)
	add_child(scroll)
	_choices = VBoxContainer.new()
	_choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_choices)
	_refresh_metrics()


func _refresh_metrics() -> void:
	var m := GameState.metrics
	_metrics.text = "Obsessão %d (%s) · Credibilidade %d · Narrativa %d · Risco Jurídico %d · Apoio Interno %d · Arquivo %d" % [
		m.get(&"obsession", 0), ObsessionSystem.tier_name(), m.get(&"credibility", 0),
		m.get(&"narrative_control", 0), m.get(&"legal_risk", 0), m.get(&"internal_support", 0),
		GameState.archive.size()]


func _set_header(t: String) -> void:
	_header.text = "Semana %d · Dia %d · %s" % [GameState.week, mini(GameState.day, 5), t]


func _clear() -> void:
	_log.clear()


func _say(speaker: String, text: String, color: String) -> void:
	_log.append_text("[b]%s:[/b] [color=%s]%s[/color]\n" % [speaker, color, text])


func _say_stage(text: String) -> void:
	_log.append_text("[color=%s]%s[/color]\n\n" % [COLOR_STAGE, text])


func _dual(public_text: String, inner_text: String) -> void:
	if public_text != "":
		_say("ESPECTRO CINZA", public_text, COLOR_PUBLIC)
	if inner_text != "":
		_log.append_text("[color=%s][i](pensando) %s[/i][/color]\n\n" % [COLOR_INNER, inner_text])


## opts: [[label, callable, disabled?], ...]
func _choose(opts: Array) -> void:
	for c in _choices.get_children():
		c.queue_free()
	for o in opts:
		var b := Button.new()
		b.text = o[0]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = o.size() > 2 and o[2]
		b.pressed.connect(o[1])
		_choices.add_child(b)
