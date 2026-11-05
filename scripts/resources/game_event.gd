class_name GameEvent extends Resource
@export var id: StringName
@export var day := -1                   ## -1 = aleatório
@export var conditions: Array[Condition] = []
@export var choices: Array[EventChoice] = []
@export var dialogue_path := ""


func can_trigger() -> bool:
	return conditions.all(func(c: Condition): return c.evaluate())
