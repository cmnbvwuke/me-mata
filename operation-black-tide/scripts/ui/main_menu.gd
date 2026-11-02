extends Control
## Menu principal: campanha (fases e missões com briefing), configurações,
## controles e sair.

const BG_SHADER := preload("res://shaders/menu_background.gdshader")

var _content: VBoxContainer
var _briefing_title: Label
var _briefing_text: Label
var _start_button: Button
var _selected_mission := ""


func _ready() -> void:
	theme = UIStyle.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = BG_SHADER
	bg.material = mat
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 56)
	add_child(margin)
	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 48)
	margin.add_child(layout)

	# Coluna esquerda: título + navegação
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.custom_minimum_size.x = 420
	layout.add_child(left)
	left.add_child(UIStyle.label("FORÇA-TAREFA TRIDENT", 16, UIStyle.AMBER))
	left.add_child(UIStyle.label("OPERATION", 34, UIStyle.DIM))
	left.add_child(UIStyle.label("BLACK TIDE", 64))
	left.add_child(UIStyle.label("República de Valderrama", 18, UIStyle.DIM))
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 40
	left.add_child(spacer)
	left.add_child(UIStyle.button("CAMPANHA", _show_campaign))
	left.add_child(UIStyle.button("CONFIGURAÇÕES", _show_settings))
	left.add_child(UIStyle.button("CONTROLES", _show_controls))
	left.add_child(UIStyle.button("CRÉDITOS", _show_credits))
	left.add_child(UIStyle.button("SAIR", _quit))
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(filler)
	left.add_child(UIStyle.label("Protótipo jogável — Godot 4", 14, UIStyle.DIM))

	# Coluna direita: conteúdo
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_content)
	_show_campaign()


func _clear() -> void:
	for c in _content.get_children():
		c.queue_free()


func _show_campaign() -> void:
	_clear()
	var setting := UIStyle.label(Campaign.SETTING, 16, UIStyle.DIM)
	setting.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(setting)
	# Lista de missões à esquerda, briefing + botão de início sempre visíveis à direita
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	_content.add_child(columns)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.size_flags_stretch_ratio = 0.9
	columns.add_child(list)
	for phase in Campaign.PHASES:
		var gap := Control.new()
		gap.custom_minimum_size.y = 8
		list.add_child(gap)
		list.add_child(UIStyle.label(String(phase["title"]), 18, UIStyle.AMBER))
		for mission in phase["missions"]:
			var playable := String(mission["scene"]) != ""
			var id := String(mission["id"])
			var done := "   ✓" if GameManager.is_mission_completed(id) else ""
			var b := UIStyle.button("   " + String(mission["title"]) + done, func() -> void: _select_mission(id))
			b.custom_minimum_size = Vector2(0, 40)
			if not playable:
				b.add_theme_color_override("font_color", UIStyle.DIM)
				b.tooltip_text = "Em desenvolvimento"
			list.add_child(b)
	var brief := VBoxContainer.new()
	brief.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brief.add_theme_constant_override("separation", 10)
	columns.add_child(brief)
	var gap2 := Control.new()
	gap2.custom_minimum_size.y = 8
	brief.add_child(gap2)
	_briefing_title = UIStyle.label("", 22, UIStyle.TEXT)
	_briefing_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	brief.add_child(_briefing_title)
	_start_button = UIStyle.button("INICIAR MISSÃO", func() -> void: GameManager.start_mission(_selected_mission))
	_start_button.visible = false
	brief.add_child(_start_button)
	_briefing_text = UIStyle.label("", 15, UIStyle.TEXT)
	_briefing_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	brief.add_child(_briefing_text)
	_add_loadout(brief)
	_select_mission("absolute_resolve")


## Escolha de equipamento: arma principal e secundária (salvas nas configurações).
func _add_loadout(parent: Control) -> void:
	var gap := Control.new()
	gap.custom_minimum_size.y = 6
	parent.add_child(gap)
	parent.add_child(UIStyle.label("EQUIPAMENTO", 18, UIStyle.AMBER))
	for slot in ["primary", "secondary"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		parent.add_child(row)
		var title := UIStyle.label("Principal" if slot == "primary" else "Secundária", 16)
		title.custom_minimum_size.x = 110
		row.add_child(title)
		var option := OptionButton.new()
		option.custom_minimum_size = Vector2(220, 32)
		row.add_child(option)
		var info := UIStyle.label("", 13, UIStyle.DIM)
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		parent.add_child(info)
		var list := GameManager.weapons_for_slot(slot)
		var current := GameManager.primary_weapon if slot == "primary" else GameManager.secondary_weapon
		for i in list.size():
			option.add_item(list[i].weapon_name, i)
			if list[i].resource_path == current:
				option.selected = i
		var show := func(i: int) -> void:
			var d := list[i]
			info.text = "%s\nDano %d · %d tiros/min · carregador %d%s" % [d.description, int(d.damage), int(d.fire_rate),
				d.magazine_size, " · automática" if d.allows_auto else ""]
		show.call(option.selected)
		option.item_selected.connect(func(i: int) -> void:
			if slot == "primary":
				GameManager.primary_weapon = list[i].resource_path
			else:
				GameManager.secondary_weapon = list[i].resource_path
			GameManager.save_settings()
			show.call(i))


func _select_mission(id: String) -> void:
	var m := Campaign.get_mission(id)
	if m.is_empty():
		return
	_selected_mission = id
	_briefing_title.text = "BRIEFING — " + String(m["title"]).to_upper()
	_briefing_text.text = String(m["brief"])
	var playable := String(m["scene"]) != ""
	_start_button.visible = true
	_start_button.disabled = not playable
	_start_button.text = "INICIAR MISSÃO" if playable else "EM DESENVOLVIMENTO"


func _show_settings() -> void:
	_clear()
	_content.add_child(SettingsPanel.new())


func _show_controls() -> void:
	_clear()
	_content.add_child(UIStyle.label("CONTROLES", 22, UIStyle.AMBER))
	var rows := [
		["W A S D", "Mover"], ["Mouse", "Olhar"], ["Shift (segurar)", "Correr"],
		["C / Ctrl", "Agachar (alternar)"], ["Espaço", "Pular / saltar janelas e obstáculos baixos"],
		["Botão esquerdo", "Atirar"], ["Botão direito (segurar)", "Mirar (ADS)"],
		["R", "Recarregar"], ["B", "Modo de disparo AUTO/SEMI"],
		["1 / 2 / Q / Roda", "Trocar entre arma principal e secundária"],
		["E (segurar)", "Interagir / capturar HVT / munição / inteligência"],
		["F", "Lanterna (aumenta sua visibilidade!)"], ["N", "Visão noturna"],
		["T", "Designar apoio aéreo (onde estiver mirando)"],
		["Enter", "Pular introdução"], ["Esc / P", "Pausar"],
	]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 6)
	_content.add_child(grid)
	for r in rows:
		grid.add_child(UIStyle.label(String(r[0]), 17, UIStyle.AMBER))
		grid.add_child(UIStyle.label(String(r[1]), 17))
	var tips := UIStyle.label("\nDICAS DE FURTIVIDADE\n" \
		+ "• Agachado você é ~2x mais difícil de ver e faz quase nenhum ruído.\n" \
		+ "• A vegetação bloqueia a visão inimiga. Holofotes das torres detectam rápido.\n" \
		+ "• Armas com silenciador (P226 SD, MP5SD) quase não fazem barulho; as outras alertam o complexo.\n" \
		+ "• Um guarda que te vê leva ~3 s para avisar pelo rádio — elimine-o antes.\n" \
		+ "• Corpos encontrados por outros guardas disparam o alarme.", 16, UIStyle.DIM)
	_content.add_child(tips)


func _show_credits() -> void:
	_clear()
	_content.add_child(UIStyle.label("CRÉDITOS", 22, UIStyle.AMBER))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 6)
	_content.add_child(grid)
	for e in Credits.ENTRIES:
		var a := UIStyle.label(String(e[0]), 15, UIStyle.AMBER)
		a.custom_minimum_size.x = 300
		a.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		grid.add_child(a)
		var b := UIStyle.label(String(e[1]), 15)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(b)
	var note := UIStyle.label("\n" + Credits.NOTE, 14, UIStyle.DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(note)


func _quit() -> void:
	# No export Web (ex.: dentro do Electron) get_tree().quit() não fecha a janela
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.close()")
	else:
		get_tree().quit()
