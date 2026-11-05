class_name Condition extends Resource
## Usada por eventos e finais. key: métrica, "week", "flag:<x>", "archive_size"...

enum Op { GTE, LTE, EQ, GT, LT }

@export var key: StringName
@export var op: Op = Op.GTE
@export var value := 0.0


func evaluate() -> bool:
	var v: float = GameState.read_key(key)
	match op:
		Op.GTE: return v >= value
		Op.LTE: return v <= value
		Op.EQ: return is_equal_approx(v, value)
		Op.GT: return v > value
		Op.LT: return v < value
	return false
