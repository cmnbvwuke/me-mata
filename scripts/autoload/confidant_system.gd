extends Node
## Teacher Wellington: Confiança, Lealdade e o Arquivo (GDD 4.3).

const ULTIMATUM_MIN_WEEK := 4


func record_confession(transcript_key: String = "") -> Recording:
	var rec := Recording.new()
	rec.week = GameState.week
	rec.day = GameState.day
	rec.severity = clampi(int(GameState.get_metric(&"obsession") / 20.0) + 1, 1, 5)
	rec.transcript_key = transcript_key
	GameState.archive.append(rec)
	GameState.confidant.trust = minf(GameState.confidant.trust + 4.0, 100.0)
	ObsessionSystem.add(-randf_range(10.0, 20.0))
	EventBus.recording_added.emit(rec)
	return rec


func archive_severity() -> int:
	var total := 0
	for r in GameState.archive:
		total += r.severity
	return total


func pressure() -> float:
	return archive_severity() * 2.0 \
		+ GameState.get_metric(&"legal_risk") * 0.5 \
		+ GameState.get_metric(&"suspicion") * 0.3


func protection() -> float:
	var c := GameState.confidant
	return c.loyalty + c.trust * 0.2 + c.favors_paid * 5.0


## Chamado na Resolução de cada dia.
func evaluate_night() -> void:
	if GameState.week < ULTIMATUM_MIN_WEEK or GameState.has_flag(&"pendrive_active"):
		return
	if pressure() > protection():
		GameState.set_flag(&"pendrive_active")
		EventBus.confidant_ultimatum.emit()


enum UltimatumChoice { NEGOTIATE, COUNTER_NARRATIVE, IGNORE }

func resolve_ultimatum(choice: UltimatumChoice) -> void:
	var d := MetricDelta.new()
	match choice:
		UltimatumChoice.NEGOTIATE:
			GameState.confidant.favors_paid += 2
			GameState.confidant.loyalty = minf(GameState.confidant.loyalty + 20.0, 100.0)
			d.internal_support = -5.0
			d.narrative_control = -5.0
		UltimatumChoice.COUNTER_NARRATIVE:
			d.narrative_control = -15.0
			d.legal_risk = 10.0
			GameState.confidant.loyalty = maxf(GameState.confidant.loyalty - 10.0, 0.0)
		UltimatumChoice.IGNORE:
			if randf() < 0.5:
				d.credibility = -30.0
				EventBus.leak_triggered.emit(false)
	ReputationSystem.apply(d)
	GameState.flags.erase(&"pendrive_active")
