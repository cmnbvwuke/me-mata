class_name EventChoice extends Resource
@export var label := ""
@export var conditions: Array[Condition] = []
@export var effects: MetricDelta
@export var set_flags: Array[StringName] = []
@export_multiline var public_line := ""
@export_multiline var inner_line := ""
