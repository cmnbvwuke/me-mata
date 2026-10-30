class_name ObjectiveManager
extends Node
## Sequência linear de objetivos. Concluir um objetivo grava um checkpoint
## (GameManager.checkpoint_index) — ao morrer, a missão recomeça dali.
##
## Cada objetivo é um Dictionary:
##   { "id": String, "title": String, "marker": Node3D|Vector3|null, "progress": String }

signal objective_started(index: int, objective: Dictionary)
signal objective_completed(index: int, objective: Dictionary)
signal objective_updated(index: int, objective: Dictionary)
signal all_completed

var objectives: Array[Dictionary] = []
var current_index: int = -1


func setup(list: Array[Dictionary]) -> void:
	objectives = list
	current_index = -1


func start_at(index: int) -> void:
	current_index = clampi(index, 0, objectives.size() - 1)
	objective_started.emit(current_index, objectives[current_index])


func current() -> Dictionary:
	if current_index < 0 or current_index >= objectives.size():
		return {}
	return objectives[current_index]


func is_current(id: String) -> bool:
	return String(current().get("id", "")) == id


func complete(id: String) -> void:
	if not is_current(id):
		return
	var done := current_index
	objective_completed.emit(done, objectives[done])
	GameManager.set_checkpoint(done + 1)
	if done + 1 >= objectives.size():
		current_index = objectives.size()
		all_completed.emit()
	else:
		current_index = done + 1
		objective_started.emit(current_index, objectives[current_index])


func set_progress(id: String, text: String) -> void:
	for i in objectives.size():
		if objectives[i]["id"] == id:
			objectives[i]["progress"] = text
			if i == current_index:
				objective_updated.emit(i, objectives[i])


## Posição do marcador do objetivo atual (ou null).
func get_marker_position() -> Variant:
	var obj := current()
	if obj.is_empty():
		return null
	var marker: Variant = obj.get("marker")
	if typeof(marker) == TYPE_OBJECT:
		if is_instance_valid(marker) and marker is Node3D:
			return (marker as Node3D).global_position + Vector3.UP * 1.2
		return null
	if marker is Vector3:
		return marker
	return null
