class_name RivalData extends CharacterData
## Rivais são SEMPRE fictícios (GDD 0.1).

@export var week := 1
@export_multiline var threat_reason := ""
@export var attention_gain_per_day := 5.0
@export var weaknesses: Array[StringName] = []
@export var resistances: Array[StringName] = []
@export_multiline var neutralized_epilogue := ""   ## destino absurdo e feliz
