class_name NarrativeAsset extends Resource

enum Kind { PRINT, AUDIO, THREAD, LIVE_CLIP, ALLIANCE, ACCUSATION, OFFICIAL_NOTE }
enum Veracity { REAL, EDITED, FABRICATED }

@export var kind: Kind = Kind.PRINT
@export var veracity: Veracity = Veracity.REAL
@export var weight := 1.0
@export_range(0.0, 1.0) var trace := 0.0
@export var target: StringName      ## sempre um rival fictício
