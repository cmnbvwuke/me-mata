class_name EndingData extends Resource
@export var id: StringName
@export var title := ""
@export var priority := 99              ## menor = avaliado primeiro
@export var all_of: Array[Condition] = []
@export var any_of: Array[Condition] = []
@export var scene: PackedScene
@export var is_secret := false


func is_met() -> bool:
	if not all_of.all(func(c: Condition): return c.evaluate()):
		return false
	return any_of.is_empty() or any_of.any(func(c: Condition): return c.evaluate())
