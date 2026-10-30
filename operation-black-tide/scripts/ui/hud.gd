extends CanvasLayer
## HUD tático: mira dinâmica, hitmarker, vida, munição, modo de disparo,
## objetivo + marcador, indicador de furtividade, indicador direcional de dano,
## vinheta de dano, visão noturna, prompts de interação, legendas de rádio,
## banners de objetivo/checkpoint e fade.
## A interface é construída em código para manter tudo versionável e fácil de ajustar.

const NVG_SHADER := preload("res://shaders/nvg.gdshader")
const VIGNETTE_SHADER := preload("res://shaders/damage_vignette.gdshader")

var player: Player

var _root: Control
var _nvg: ColorRect
var _vignette: ColorRect
var _fade: ColorRect
var _crosshair: Crosshair
var _damage_indicator: DamageIndicator
var _waypoint: WaypointMarker
var _objectives: ObjectiveManager

var _obj_title: Label
var _obj_progress: Label
var _stealth_label: Label
var _stealth_bar: ProgressBar
var _health_bar: ProgressBar
var _health_label: Label
var _air_label: Label
var _weapon_label: Label
var _ammo_label: Label
var _reserve_label: Label
var _mode_label: Label
var _hint_label: Label
var _prompt_label: Label
var _prompt_bar: ProgressBar
var _subtitle: RichTextLabel
var _banner: VBoxContainer
var _banner_title: Label
var _banner_sub: Label
var _toast: Label
var _equipment_label: Label
var _ammo_hint: Label

var _subtitle_queue: Array[Dictionary] = []
var _subtitle_timer := 0.0
var _banner_timer := 0.0
var _toast_timer := 0.0
var _damage_flash := 0.0
var _health_ratio := 1.0
var _heartbeat: AudioStreamPlayer


func _ready() -> void:
	layer = 5
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UIStyle.get_theme()
	add_child(_root)
	_build()
	_heartbeat = AudioStreamPlayer.new()
	_heartbeat.stream = AudioManager.get_stream("heartbeat")
	_heartbeat.volume_db = -6.0
	add_child(_heartbeat)


# =========================================================================
# Ligações
# =========================================================================

func bind_player(p: Player) -> void:
	player = p
	_damage_indicator.player = p
	_waypoint.camera = p.camera
	p.health_changed.connect(_on_health_changed)
	p.damaged.connect(_on_damaged)
	p.interaction_changed.connect(_on_interaction_changed)
	p.nvg_toggled.connect(func(on: bool) -> void: _nvg.visible = on)
	p.died.connect(func() -> void:
		_crosshair.visible = false
		_heartbeat.stop())
	p.weapons.weapon_changed.connect(_on_weapon_changed)
	p.weapons.ammo_changed.connect(_on_ammo_changed)
	p.weapons.fire_mode_changed.connect(func(_a: bool) -> void: _refresh_weapon())
	p.weapons.hit_confirmed.connect(_on_hit_confirmed)
	if p.weapons.current:
		_on_weapon_changed(p.weapons.current)


func bind_objectives(om: ObjectiveManager) -> void:
	_objectives = om
	om.objective_started.connect(func(_i: int, o: Dictionary) -> void: _show_objective(o))
	om.objective_updated.connect(func(_i: int, o: Dictionary) -> void: _show_objective(o))
	om.objective_completed.connect(func(_i: int, o: Dictionary) -> void:
		show_banner("OBJETIVO CONCLUÍDO", String(o.get("title", "")))
		AudioManager.play_2d("objective", -4.0))


func bind_air_support(air: AirSupport) -> void:
	air.message.connect(func(t: String) -> void: show_radio("", t, 4.0))
	air.charges_changed.connect(func(charges: int, available: bool) -> void:
		_air_label.visible = available
		_air_label.text = "[T] APOIO AÉREO — VIPER 2-1  ×%d" % charges
		_air_label.add_theme_color_override("font_color", UIStyle.AMBER if charges > 0 else UIStyle.DIM))


# =========================================================================
# API pública
# =========================================================================

## Legenda de rádio. Mensagens são enfileiradas e exibidas em sequência.
func show_radio(speaker: String, text: String, duration: float = 4.0) -> void:
	_subtitle_queue.append({"speaker": speaker, "text": text, "duration": duration})


func clear_radio() -> void:
	_subtitle_queue.clear()
	_subtitle_timer = 0.0
	_subtitle.visible = false


func show_banner(title: String, subtitle: String = "", duration: float = 3.5) -> void:
	_banner_title.text = title
	_banner_sub.text = subtitle
	_banner.visible = true
	_banner.modulate.a = 1.0
	_banner_timer = duration


func show_toast(text: String, duration: float = 2.5) -> void:
	_toast.text = text
	_toast.visible = true
	_toast.modulate.a = 1.0
	_toast_timer = duration


func show_hint(text: String) -> void:
	_hint_label.text = text
	_hint_label.visible = text != ""


func fade_to_black(duration: float) -> void:
	_fade.visible = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, duration)


func fade_from_black(duration: float) -> void:
	_fade.visible = true
	_fade.color.a = 1.0
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, duration)
	tw.tween_callback(func() -> void: _fade.visible = false)


func set_combat_hud_visible(v: bool) -> void:
	for n in [_crosshair, _health_bar.get_parent(), _ammo_label.get_parent()]:
		(n as CanvasItem).visible = v


# =========================================================================
# Atualização contínua
# =========================================================================

func _process(delta: float) -> void:
	_update_subtitles(delta)
	_update_timers(delta)
	_update_stealth()
	_damage_flash = maxf(_damage_flash - delta * 1.4, 0.0)
	var low := clampf((0.55 - _health_ratio) / 0.55, 0.0, 1.0)
	(_vignette.material as ShaderMaterial).set_shader_parameter("intensity", maxf(_damage_flash, low * 0.85))
	if player:
		var w := player.weapons
		_crosshair.spread_deg = w.current_spread
		_crosshair.fov = player.camera.fov
		var target_opacity := 1.0 - clampf(w.aim_blend * 2.0, 0.0, 1.0)
		if player.is_sprinting:
			target_opacity = 0.0
		_crosshair.opacity = lerpf(_crosshair.opacity, target_opacity, clampf(delta * 15.0, 0.0, 1.0))
		_equipment_label.text = "[F] LANTERNA %s    [N] VISÃO NOTURNA %s" % [
			"ON" if player.flashlight.visible else "OFF", "ON" if player.nvg_enabled else "OFF"]
		if w.current:
			var reloading := w.current.state == Weapon.State.RELOADING
			if reloading:
				_mode_label.text = "RECARREGANDO..."
			_refresh_low_ammo_hint()
	if _objectives:
		_waypoint.target = _objectives.get_marker_position()


func _update_subtitles(delta: float) -> void:
	if _subtitle_timer > 0.0:
		_subtitle_timer -= delta
		if _subtitle_timer <= 0.0:
			_subtitle.visible = false
	if _subtitle_timer <= 0.0 and not _subtitle_queue.is_empty():
		var s: Dictionary = _subtitle_queue.pop_front()
		var speaker := String(s["speaker"])
		var text := String(s["text"])
		if speaker != "":
			_subtitle.text = "[center][color=#ffb840]%s:[/color] %s[/center]" % [speaker, text]
		else:
			_subtitle.text = "[center]%s[/center]" % text
		_subtitle.visible = true
		_subtitle_timer = float(s["duration"])
		AudioManager.play_2d("radio_beep", -14.0)


func _update_timers(delta: float) -> void:
	if _banner_timer > 0.0:
		_banner_timer -= delta
		_banner.modulate.a = clampf(_banner_timer / 0.6, 0.0, 1.0)
		if _banner_timer <= 0.0:
			_banner.visible = false
	if _toast_timer > 0.0:
		_toast_timer -= delta
		_toast.modulate.a = clampf(_toast_timer / 0.5, 0.0, 1.0)
		if _toast_timer <= 0.0:
			_toast.visible = false


func _update_stealth() -> void:
	var aw := StealthSystem.get_max_awareness()
	_stealth_bar.value = aw
	if aw >= 1.0:
		_stealth_label.text = "DETECTADO"
		_stealth_label.add_theme_color_override("font_color", UIStyle.DANGER)
		UIStyle.set_bar_color(_stealth_bar, UIStyle.DANGER)
	elif StealthSystem.alarm_active:
		_stealth_label.text = "ALERTA GERAL"
		_stealth_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.15))
		UIStyle.set_bar_color(_stealth_bar, Color(1.0, 0.45, 0.15))
	elif aw > 0.08:
		_stealth_label.text = "SUSPEITO"
		_stealth_label.add_theme_color_override("font_color", UIStyle.AMBER)
		UIStyle.set_bar_color(_stealth_bar, UIStyle.AMBER)
	else:
		_stealth_label.text = "OCULTO"
		_stealth_label.add_theme_color_override("font_color", UIStyle.DIM)
		UIStyle.set_bar_color(_stealth_bar, UIStyle.DIM)


# =========================================================================
# Callbacks
# =========================================================================

func _on_health_changed(current: float, maximum: float) -> void:
	_health_ratio = current / maxf(maximum, 1.0)
	_health_bar.value = _health_ratio
	_health_label.text = "SAÚDE  %d" % int(ceil(current))
	var col := UIStyle.TEXT if _health_ratio > 0.5 else (UIStyle.AMBER if _health_ratio > 0.25 else UIStyle.DANGER)
	UIStyle.set_bar_color(_health_bar, col)
	if _health_ratio < 0.35 and current > 0.0:
		if not _heartbeat.playing:
			_heartbeat.play()
	elif _heartbeat.playing:
		_heartbeat.stop()


func _on_damaged(amount: float, from_position: Vector3) -> void:
	_damage_flash = clampf(_damage_flash + amount / 40.0, 0.0, 0.75)
	_damage_indicator.add_hit(from_position)


func _on_interaction_changed(prompt: String, progress: float) -> void:
	_prompt_label.visible = prompt != ""
	_prompt_label.text = prompt
	_prompt_bar.visible = prompt != "" and progress > 0.0
	_prompt_bar.value = progress


func _on_hit_confirmed(killed: bool, headshot: bool) -> void:
	_crosshair.show_hit(killed, headshot)
	AudioManager.play_2d("hitmarker", -10.0 if not killed else -6.0, 0.05)


func _on_weapon_changed(_w: Weapon) -> void:
	_refresh_weapon()


func _on_ammo_changed(_m: int, _r: int) -> void:
	_refresh_weapon()


func _refresh_weapon() -> void:
	if player == null or player.weapons.current == null:
		return
	var w := player.weapons.current
	_weapon_label.text = w.data.weapon_name.to_upper()
	_ammo_label.text = "%d" % w.ammo_in_mag
	_reserve_label.text = "/ %d" % w.ammo_reserve
	_ammo_label.add_theme_color_override("font_color",
		UIStyle.DANGER if w.ammo_in_mag <= int(w.data.magazine_size * 0.25) else UIStyle.TEXT)
	_mode_label.text = ("[B] AUTO" if w.is_auto else "[B] SEMI") if w.data.allows_auto else "SEMI"
	_refresh_low_ammo_hint()


func _refresh_low_ammo_hint() -> void:
	var w := player.weapons.current
	if w.state == Weapon.State.RELOADING:
		_prompt_label.visible = true
		_prompt_label.text = "RECARREGANDO"
		_prompt_bar.visible = true
		_prompt_bar.value = w.get_reload_progress()
	elif w.ammo_in_mag == 0 and w.ammo_reserve == 0:
		_set_ammo_hint("SEM MUNIÇÃO — troque de arma [Q]")
	elif w.ammo_in_mag <= int(w.data.magazine_size * 0.25):
		_set_ammo_hint("[R] RECARREGAR")
	else:
		_set_ammo_hint("")


func _set_ammo_hint(text: String) -> void:
	_ammo_hint.text = text
	_ammo_hint.visible = text != ""


func _show_objective(o: Dictionary) -> void:
	_obj_title.text = String(o.get("title", ""))
	var prog := String(o.get("progress", ""))
	_obj_progress.text = prog
	_obj_progress.visible = prog != ""


# =========================================================================
# Construção da interface
# =========================================================================

func _build() -> void:
	# 1) Visão noturna (precisa ser o primeiro: lê a tela antes do resto do HUD)
	_nvg = ColorRect.new()
	_nvg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_nvg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nvg_mat := ShaderMaterial.new()
	nvg_mat.shader = NVG_SHADER
	_nvg.material = nvg_mat
	_nvg.visible = false
	_root.add_child(_nvg)

	# 2) Vinheta de dano
	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vig_mat := ShaderMaterial.new()
	vig_mat.shader = VIGNETTE_SHADER
	_vignette.material = vig_mat
	_root.add_child(_vignette)

	# 3) Mira, indicador de dano e marcador de objetivo
	_waypoint = WaypointMarker.new()
	_root.add_child(_waypoint)
	_damage_indicator = DamageIndicator.new()
	_root.add_child(_damage_indicator)
	_crosshair = Crosshair.new()
	_root.add_child(_crosshair)

	# 4) Objetivo (canto superior esquerdo)
	var obj_box := VBoxContainer.new()
	obj_box.position = Vector2(28, 24)
	obj_box.add_theme_constant_override("separation", 2)
	_root.add_child(obj_box)
	obj_box.add_child(UIStyle.label("OBJETIVO ATUAL", 14, UIStyle.AMBER))
	_obj_title = UIStyle.label("", 22)
	obj_box.add_child(_obj_title)
	_obj_progress = UIStyle.label("", 16, UIStyle.DIM)
	obj_box.add_child(_obj_progress)
	_equipment_label = UIStyle.label("", 13, UIStyle.DIM)
	obj_box.add_child(_equipment_label)

	# 5) Furtividade (topo central)
	var stealth := VBoxContainer.new()
	stealth.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	stealth.offset_left = -110
	stealth.offset_right = 110
	stealth.offset_top = 22
	stealth.alignment = BoxContainer.ALIGNMENT_CENTER
	_root.add_child(stealth)
	_stealth_label = UIStyle.label("OCULTO", 18, UIStyle.DIM)
	_stealth_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stealth.add_child(_stealth_label)
	_stealth_bar = UIStyle.bar(UIStyle.DIM, 5)
	stealth.add_child(_stealth_bar)

	# 6) Vida + apoio aéreo (inferior esquerdo)
	var health := VBoxContainer.new()
	health.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	health.offset_left = 28
	health.offset_right = 340
	health.offset_top = -100
	health.offset_bottom = -26
	health.alignment = BoxContainer.ALIGNMENT_END
	_root.add_child(health)
	_air_label = UIStyle.label("", 15, UIStyle.AMBER)
	_air_label.visible = false
	health.add_child(_air_label)
	_health_label = UIStyle.label("SAÚDE  100", 15, UIStyle.DIM)
	health.add_child(_health_label)
	_health_bar = UIStyle.bar(UIStyle.TEXT, 9)
	_health_bar.value = 1.0
	health.add_child(_health_bar)

	# 7) Arma e munição (inferior direito)
	var ammo := VBoxContainer.new()
	ammo.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ammo.offset_left = -380
	ammo.offset_right = -30
	ammo.offset_top = -150
	ammo.offset_bottom = -22
	ammo.alignment = BoxContainer.ALIGNMENT_END
	_root.add_child(ammo)
	_ammo_hint = UIStyle.label("", 15, UIStyle.AMBER)
	_ammo_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo.add_child(_ammo_hint)
	_weapon_label = UIStyle.label("", 16, UIStyle.DIM)
	_weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo.add_child(_weapon_label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	ammo.add_child(row)
	_ammo_label = UIStyle.label("30", 46)
	row.add_child(_ammo_label)
	_reserve_label = UIStyle.label("/ 150", 22, UIStyle.DIM)
	_reserve_label.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(_reserve_label)
	_mode_label = UIStyle.label("AUTO", 14, UIStyle.DIM)
	_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo.add_child(_mode_label)

	# 8) Interação (abaixo da mira)
	var prompt := VBoxContainer.new()
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	prompt.offset_left = -260
	prompt.offset_right = 260
	prompt.offset_top = 60
	prompt.offset_bottom = 120
	_root.add_child(prompt)
	_prompt_label = UIStyle.label("", 18)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.visible = false
	prompt.add_child(_prompt_label)
	_prompt_bar = UIStyle.bar(UIStyle.AMBER, 5)
	_prompt_bar.custom_minimum_size.x = 220
	_prompt_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_prompt_bar.visible = false
	prompt.add_child(_prompt_bar)

	# 9) Legendas de rádio (inferior central)
	_subtitle = RichTextLabel.new()
	_subtitle.bbcode_enabled = true
	_subtitle.fit_content = true
	_subtitle.scroll_active = false
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_subtitle.offset_left = -480
	_subtitle.offset_right = 480
	_subtitle.offset_top = -190
	_subtitle.offset_bottom = -130
	_subtitle.add_theme_font_size_override("normal_font_size", 20)
	_subtitle.add_theme_constant_override("outline_size", 6)
	_subtitle.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_subtitle.visible = false
	_root.add_child(_subtitle)

	# 10) Banner (objetivo concluído, checkpoint)
	_banner = VBoxContainer.new()
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_left = -400
	_banner.offset_right = 400
	_banner.offset_top = 110
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_banner)
	_banner_title = UIStyle.label("", 30, UIStyle.AMBER)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_title)
	_banner_sub = UIStyle.label("", 18)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_sub)
	_banner.visible = false

	_toast = UIStyle.label("", 16, UIStyle.GOOD)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_left = -300
	_toast.offset_right = 300
	_toast.offset_top = 200
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.visible = false
	_root.add_child(_toast)

	_hint_label = UIStyle.label("", 16, UIStyle.DIM)
	_hint_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint_label.offset_left = -400
	_hint_label.offset_right = -30
	_hint_label.offset_top = -200
	_hint_label.offset_bottom = -170
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint_label.visible = false
	_root.add_child(_hint_label)

	# 11) Fade (por cima de tudo)
	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.color = Color(0, 0, 0, 0)
	_fade.visible = false
	_root.add_child(_fade)
