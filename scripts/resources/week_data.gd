class_name WeekData extends Resource
@export var number := 1
@export var title := ""
@export var rival: RivalData
@export var unlocks: Array[StringName] = []
@export var scheduled_events: Array[GameEvent] = []
@export var weekend_crisis: GameEvent
@export var monologue_dialogue := ""
