class_name CharacterData extends Resource

@export var id: StringName
@export var display_name := ""
@export var portrait: Texture2D
@export var is_fictional := true          ## false só para figuras públicas (ver GDD 0)
@export var routine: Array[RoutineStep] = []
@export var perception_radius := 6.0
