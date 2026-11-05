extends Node
## Sinais globais. Sistemas emitem, UI e diretores escutam.

signal obsession_changed(value: float, delta: float)
signal obsession_tier_changed(tier_index: int)
signal metric_changed(key: StringName, value: float, delta: float)
signal metric_threshold_hit(key: StringName, value: float)
signal recording_added(recording: Recording)
signal confidant_ultimatum
signal leak_triggered(full: bool)
signal rival_neutralized(rival_id: StringName, method_id: StringName)
signal phase_started(phase: int)
signal day_ended(week: int, day: int)
signal week_ended(week: int)
signal ending_reached(ending_id: StringName)
