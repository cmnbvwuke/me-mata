extends Node
## Estado serializável de uma run. Sem lógica de regras: só dados e acesso.

enum Phase { MORNING_FEED, HEADQUARTERS, EVENING_LIVE, NIGHT_CONFESSION, RESOLUTION, WEEKEND_CRISIS }

const METRIC_KEYS: Array[StringName] = [
	&"obsession", &"credibility", &"narrative_control",
	&"legal_risk", &"internal_support", &"suspicion",
]

var week := 1
var day := 1
var phase: Phase = Phase.MORNING_FEED

var metrics := {}
var confidant := {"trust": 30.0, "loyalty": 60.0, "favors_paid": 0}
var archive: Array[Recording] = []
var rivals := {}            # rival_id -> "active" | "neutralized:<method_id>"
var rival_attention := {}   # rival_id -> 0..100 (Atenção do Renan para o rival)
var intel := {}             # rival_id -> int (observações acumuladas)
var flags := {}             # StringName -> true
var extreme_methods_used := 0
var inventory: Array[NarrativeAsset] = []


func _ready() -> void:
	new_run()


func new_run() -> void:
	week = 1
	day = 1
	phase = Phase.MORNING_FEED
	metrics = {
		&"obsession": 15.0,
		&"credibility": 70.0,
		&"narrative_control": 50.0,
		&"legal_risk": 0.0,
		&"internal_support": 60.0,
		&"suspicion": 0.0,
	}
	confidant = {"trust": 30.0, "loyalty": 60.0, "favors_paid": 0}
	archive.clear()
	rivals.clear()
	rival_attention.clear()
	intel.clear()
	flags.clear()
	extreme_methods_used = 0
	inventory.clear()


func get_metric(key: StringName) -> float:
	return metrics.get(key, 0.0)


func set_metric(key: StringName, value: float) -> void:
	metrics[key] = clampf(value, 0.0, 100.0)


func set_flag(key: StringName) -> void:
	flags[key] = true


func has_flag(key: StringName) -> bool:
	return flags.has(key)


## Resolve chaves usadas por Condition: métricas, "flag:<x>", contadores.
func read_key(key: StringName) -> float:
	var k := String(key)
	if k.begins_with("flag:"):
		return 1.0 if has_flag(StringName(k.substr(5))) else 0.0
	match k:
		"week": return week
		"archive_size": return archive.size()
		"archive_leaked": return 1.0 if has_flag(&"archive_leaked_full") else 0.0
		"extreme_methods_used": return extreme_methods_used
		"rivals_active": return rivals.values().count("active")
		"confidant_trust": return confidant.trust
		"confidant_loyalty": return confidant.loyalty
	return get_metric(key)


func to_dict() -> Dictionary:
	var arch := []
	for r in archive:
		arch.append({"w": r.week, "d": r.day, "sev": r.severity, "key": r.transcript_key})
	return {
		"week": week, "day": day, "phase": phase,
		"metrics": metrics.duplicate(), "confidant": confidant.duplicate(),
		"archive": arch, "rivals": rivals.duplicate(), "flags": flags.keys(),
		"rival_attention": rival_attention.duplicate(), "intel": intel.duplicate(),
		"extreme_methods_used": extreme_methods_used,
	}


func from_dict(d: Dictionary) -> void:
	new_run()
	week = d.get("week", 1)
	day = d.get("day", 1)
	phase = d.get("phase", Phase.MORNING_FEED)
	for k in d.get("metrics", {}):
		metrics[StringName(k)] = float(d.metrics[k])
	confidant.merge(d.get("confidant", {}), true)
	for a in d.get("archive", []):
		var r := Recording.new()
		r.week = a.w; r.day = a.d; r.severity = a.sev; r.transcript_key = a.get("key", "")
		archive.append(r)
	rivals = d.get("rivals", {})
	rival_attention = d.get("rival_attention", {})
	intel = d.get("intel", {})
	for f in d.get("flags", []):
		flags[StringName(f)] = true
	extreme_methods_used = d.get("extreme_methods_used", 0)
