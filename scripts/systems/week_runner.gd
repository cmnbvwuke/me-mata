class_name WeekRunner extends RefCounted
## Lógica de uma semana, guiada por data/weeks/week_XX.json. Sem UI.
## Ordem: (dias 1–5: Feed → Sede ×3 → Live ×3 → Desabafo → Resolução) → Sábado → Domingo → Monólogo.

const DAYS := 5
const LIVE_QUESTIONS_PER_NIGHT := 3

var data: Dictionary
var rng := RandomNumberGenerator.new()
var rival_id := ""


func load_week(path: String) -> bool:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Semana inválida: %s" % path)
		return false
	data = parsed
	rival_id = data.rival.id
	return true


func start_week() -> void:
	GameState.week = int(data.number)
	GameState.day = 1
	GameState.rivals[rival_id] = "active"
	GameState.rival_attention[rival_id] = float(data.rival.attention_start)
	GameState.intel[rival_id] = 0


# --- Efeitos -----------------------------------------------------------------

func apply_effects(eff: Dictionary) -> void:
	var d := MetricDelta.new()
	d.obsession = eff.get("obsession", 0.0)
	d.credibility = eff.get("credibility", 0.0)
	d.narrative_control = eff.get("narrative_control", 0.0)
	d.legal_risk = eff.get("legal_risk", 0.0)
	d.internal_support = eff.get("internal_support", 0.0)
	d.suspicion = eff.get("suspicion", 0.0)
	ReputationSystem.apply(d)
	if eff.has("renan_attention"):
		GameState.set_metric(&"renan_attention", GameState.get_metric(&"renan_attention") + eff.renan_attention)
	if eff.has("rival_attention") and rival_active():
		GameState.rival_attention[rival_id] = clampf(rival_attention() + eff.rival_attention, 0.0, 100.0)


func rival_active() -> bool:
	return GameState.rivals.get(rival_id, "") == "active"


func rival_attention() -> float:
	return GameState.rival_attention.get(rival_id, 0.0)


func neutralize(method_id: String) -> void:
	GameState.rivals[rival_id] = "neutralized:" + method_id
	GameState.rival_attention[rival_id] = 0.0
	EventBus.rival_neutralized.emit(StringName(rival_id), StringName(method_id))


# --- Manhã: Feed ---------------------------------------------------------------

func feed_event() -> Dictionary:
	var ev: Dictionary = data.feed_events.get(str(GameState.day), {})
	if not ev.is_empty():
		apply_effects(ev.get("effects", {}))
	return ev


func posts() -> Array:
	return data.posts


func choose_post(index: int) -> Dictionary:
	var p: Dictionary = data.posts[index]
	apply_effects(p.effects)
	return p


# --- Tarde: Sede ---------------------------------------------------------------

func hq_slots() -> Array:
	return data.hq_slots


## Lista de opções da Sede: ações, métodos (com chance/bloqueio) e serviços do Teacher.
func hq_options() -> Array:
	var out := []
	for a in data.hq_actions:
		out.append({"type": "action", "id": a.id, "label": a.label, "enabled": true})
	for m in data.methods:
		var opt := {"type": "method", "id": m.id, "label": m.label, "desc": m.get("desc", "")}
		opt.enabled = rival_active() and method_unlocked(m) and requirements_met(m)
		if opt.enabled:
			opt.chance = method_chance(m)
		out.append(opt)
	for s in data.teacher_services:
		out.append({"type": "service", "id": s.id, "label": s.label, "enabled": not GameState.has_flag(StringName(s.sets_flag))})
	return out


func method_unlocked(m: Dictionary) -> bool:
	return ObsessionSystem.value() >= float(m.get("min_obsession", 0))


func requirements_met(m: Dictionary) -> bool:
	var reqs: Array = m.get("requires_any", [])
	if reqs.is_empty():
		return true
	for r in reqs:
		var s := String(r)
		if s.begins_with("flag:") and GameState.has_flag(StringName(s.substr(5))):
			return true
		if s.begins_with("intel:") and int(GameState.intel.get(rival_id, 0)) >= int(s.substr(6)):
			return true
	return false


func method_chance(m: Dictionary) -> float:
	var c := float(m.get("base_success", 0.5))
	c += 0.10 * mini(int(GameState.intel.get(rival_id, 0)), 2)
	for t in m.get("exploits", []):
		if t in data.rival.weaknesses:
			c += 0.05
		if t in data.rival.resistances:
			c -= 0.2
	for s in data.teacher_services:
		if GameState.has_flag(StringName(s.sets_flag)):
			c += float(s.get("adds_bonus", 0.0))
	return clampf(c, 0.05, 0.95)


func find_action(id: String) -> Dictionary:
	return _find(data.hq_actions, id)


func find_method(id: String) -> Dictionary:
	return _find(data.methods, id)


func _find(list: Array, id: String) -> Dictionary:
	for x in list:
		if x.id == id:
			return x
	return {}


func do_action(id: String) -> Dictionary:
	var a := _find(data.hq_actions, id)
	apply_effects(a.get("effects", {}))
	if a.has("gives_intel"):
		GameState.intel[rival_id] = int(GameState.intel.get(rival_id, 0)) + int(a.gives_intel)
	return a


## Retorna {ok, witnessed, locked, text, public, inner}.
## witnessed_override: -1 sorteia pela witness_chance; 0/1 vem do mapa (testemunhas reais).
func try_method(id: String, witnessed_override := -1) -> Dictionary:
	var m := _find(data.methods, id)
	if not method_unlocked(m) or not requirements_met(m) or not rival_active():
		return {"locked": true, "text": m.get("locked_text", "Ainda não dá.")}
	var ok := rng.randf() < method_chance(m)
	var witnessed := rng.randf() < float(m.get("witness_chance", 0.0))
	if witnessed_override >= 0:
		witnessed = witnessed_override == 1
	var eff: Dictionary = (m.on_success if ok else m.on_fail).duplicate()
	var neutral := bool(eff.get("neutralize", false))
	eff.erase("neutralize")
	apply_effects(eff)
	if witnessed:
		apply_effects(m.get("on_witnessed", {}))
	if ok and m.has("sets_flag"):
		GameState.set_flag(StringName(m.sets_flag))
	if ok and neutral:
		neutralize(id)
	# Atenção zerada por desgaste também tira o rival de cena.
	elif rival_active() and rival_attention() <= 0.0:
		neutralize(id)
	return {
		"ok": ok, "witnessed": witnessed, "locked": false,
		"public": m.get("public", ""), "inner": m.get("inner", ""),
		"text": m.success_text if ok else m.fail_text,
	}


func use_teacher_service(id: String) -> Dictionary:
	var s := _find(data.teacher_services, id)
	GameState.set_flag(StringName(s.sets_flag))
	var rec := ConfidantSystem.record_confession("service:" + id)
	return {"teacher": s.teacher, "severity": rec.severity}


# --- Noite: Live ---------------------------------------------------------------

func live_questions() -> Array:
	var qs: Array = data.live_questions.get(str(GameState.day), []).duplicate()
	var defaults: Array = data.live_questions.default
	var i := GameState.day
	while qs.size() < LIVE_QUESTIONS_PER_NIGHT:
		qs.append(defaults[i % defaults.size()])
		i += 1
	return qs.slice(0, LIVE_QUESTIONS_PER_NIGHT)


func available_answers(q: Dictionary) -> Array:
	return q.answers.filter(func(a): return ObsessionSystem.value() >= float(a.get("min_obsession", 0)))


## Responde uma pergunta. Pode haver vazamento verbal (GDD 4.1).
func answer_live(answer: Dictionary) -> Dictionary:
	if rng.randf() < ObsessionSystem.verbal_leak_chance():
		apply_effects(data.verbal_leak.effects)
		return {"leaked": true, "public": data.verbal_leak.text}
	apply_effects(answer.effects)
	return {"leaked": false, "public": answer.public}


# --- Madrugada: Desabafo -------------------------------------------------------

func confess() -> Dictionary:
	var rec := ConfidantSystem.record_confession()
	rec.transcript_key = "w%d_d%d_sev%d" % [GameState.week, GameState.day, rec.severity]
	var replies: Array = data.confession.teacher_replies
	return {
		"severity": rec.severity,
		"transcript": data.confession.transcripts[str(rec.severity)],
		"reply": replies[rng.randi() % replies.size()],
	}


func skip_confession() -> String:
	apply_effects(data.confession.skip_effects)
	return data.confession.skip_text


# --- Resolução -----------------------------------------------------------------

func resolve_day() -> Array:
	var lines := []
	if rival_active():
		apply_effects({"rival_attention": float(data.rival.attention_gain_per_day)})
		var jealousy := rival_attention() * 0.05
		ObsessionSystem.add(jealousy)
		lines.append("💗 Atenção do Renan para %s: %d/100 (ciúme +%.1f)" % [data.rival.name, rival_attention(), jealousy])
	var rl: Array = data.resolution_lines
	lines.append(rl[(GameState.day - 1) % rl.size()])
	ConfidantSystem.evaluate_night()
	EventBus.day_ended.emit(GameState.week, GameState.day)
	GameState.day += 1
	return lines


func is_weekend() -> bool:
	return GameState.day > DAYS


# --- Fim de semana -------------------------------------------------------------

func crisis() -> Dictionary:
	var c: Dictionary = data.weekend_crisis
	return c.if_active if rival_active() else c.if_neutralized


func resolve_crisis(choice_index: int = -1) -> Dictionary:
	var branch := crisis()
	if branch.has("choices"):
		var ch: Dictionary = branch.choices[choice_index]
		apply_effects(ch.effects)
		return ch
	apply_effects(branch.effects)
	return branch


func sunday() -> String:
	if rival_active() and rival_attention() >= float(data.rival.deadline_threshold):
		apply_effects(data.sunday.moment_effects)
		GameState.set_flag(StringName("moment_" + rival_id))
		return data.sunday.moment_text
	return data.sunday.calm_text


func monologue() -> Array:
	return data.monologue.active if rival_active() else data.monologue.neutralized


func finish_week() -> void:
	GameState.set_flag(StringName("week_%d_done" % int(data.number)))
	EventBus.week_ended.emit(int(data.number))
