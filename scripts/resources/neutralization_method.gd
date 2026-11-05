class_name NeutralizationMethod extends Resource
## Métodos de assassinato de REPUTAÇÃO. Nenhum é violência física.

enum Category { SOCIAL, POLITICAL, NARRATIVE, REPUTATION_THEATRICAL }

@export var id: StringName
@export var display_name := ""
@export var category: Category = Category.SOCIAL
@export var required_items: Array[StringName] = []
@export var required_location: StringName
@export var time_window := Vector2i(13, 18)
@export var exploits_tags: Array[StringName] = []
@export_range(0.0, 1.0) var base_success := 0.6
@export var on_success: MetricDelta
@export var on_fail: MetricDelta
@export var on_witnessed: MetricDelta
@export var stage_cutscene: PackedScene     ## só REPUTATION_THEATRICAL
@export_multiline var success_line := ""
@export_multiline var fail_line := ""
