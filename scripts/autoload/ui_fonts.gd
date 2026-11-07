extends Node
## Adiciona fonte de emoji do sistema como fallback da fonte padrão
## (sem isso, 📱🎭📼 aparecem como quadradinhos).

func _ready() -> void:
	var emoji := SystemFont.new()
	emoji.font_names = PackedStringArray(["Noto Color Emoji", "Segoe UI Emoji", "Apple Color Emoji", "Twemoji"])
	var base: Font = ThemeDB.fallback_font
	var fallbacks := base.fallbacks.duplicate()
	fallbacks.append(emoji)
	base.fallbacks = fallbacks
