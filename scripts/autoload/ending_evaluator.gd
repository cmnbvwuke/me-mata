extends Node
## Avalia os EndingData em ordem de prioridade (GDD 7).

const ENDINGS_DIR := "res://data/endings/"

var _endings: Array[EndingData] = []


func _ready() -> void:
	var dir := DirAccess.open(ENDINGS_DIR)
	if dir == null:
		return
	for f in dir.get_files():
		if f.ends_with(".tres") or f.ends_with(".tres.remap"):
			var res := load(ENDINGS_DIR + f.trim_suffix(".remap"))
			if res is EndingData:
				_endings.append(res)
	_endings.sort_custom(func(a, b): return a.priority < b.priority)


func evaluate() -> EndingData:
	for e in _endings:
		if e.is_met():
			return e
	return null
