extends Node
## Credibilidade, Narrativa, Risco Jurídico, Apoio Interno e Suspeita.

func apply(d: MetricDelta) -> void:
	if d == null:
		return
	if d.obsession != 0.0:
		ObsessionSystem.add(d.obsession)
	_add(&"credibility", d.credibility)
	_add(&"narrative_control", d.narrative_control)
	_add(&"legal_risk", d.legal_risk)
	_add(&"internal_support", d.internal_support)
	_add(&"suspicion", d.suspicion)


func _add(key: StringName, delta: float) -> void:
	if delta == 0.0:
		return
	var v := clampf(GameState.get_metric(key) + delta, 0.0, 100.0)
	GameState.set_metric(key, v)
	EventBus.metric_changed.emit(key, v, delta)
	if (key == &"legal_risk" and v >= 100.0) or (key == &"credibility" and v <= 0.0) \
			or (key == &"internal_support" and v <= 0.0):
		EventBus.metric_threshold_hit.emit(key, v)


## Custo extra por usar ativo narrativo (GDD 4.2: inventado soma rastro × 2 ao RJ).
func use_asset(asset: NarrativeAsset) -> void:
	var d := MetricDelta.new()
	d.narrative_control = asset.weight * 5.0
	d.suspicion = asset.trace * 10.0
	if asset.veracity == NarrativeAsset.Veracity.FABRICATED:
		d.legal_risk = asset.trace * 2.0 * 10.0
	elif asset.veracity == NarrativeAsset.Veracity.EDITED:
		d.legal_risk = asset.trace * 10.0
	apply(d)
