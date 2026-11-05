extends Node
## Aplica deltas de Obsessão e calcula a faixa atual.

## Limites mínimos de cada faixa (ver GDD 4.1).
const TIER_MINS: Array[int] = [0, 25, 50, 75, 90]
const TIER_NAMES: Array[String] = [
	"Ponderada", "Ligeiramente Enviesada", "Dialética Possessiva", "Tese Final", "Síntese Absoluta",
]

var _last_tier := 0


func value() -> float:
	return GameState.get_metric(&"obsession")


func add(delta: float) -> void:
	var v := clampf(value() + delta, 0.0, 100.0)
	GameState.set_metric(&"obsession", v)
	EventBus.obsession_changed.emit(v, delta)
	var t := tier_index(v)
	if t != _last_tier:
		_last_tier = t
		EventBus.obsession_tier_changed.emit(t)


static func tier_index(v: float) -> int:
	var idx := 0
	for i in TIER_MINS.size():
		if v >= TIER_MINS[i]:
			idx = i
	return idx


func tier_name() -> String:
	return TIER_NAMES[tier_index(value())]


## Chance de a fala pública "vazar" o pensamento interno (GDD 4.1).
func verbal_leak_chance() -> float:
	var v := value()
	return 0.0 if v < 75.0 else (v - 70.0) * 0.015


func category_unlocked(category: int) -> bool:
	# category segue NeutralizationMethod.Category (0..3); faixas 0,1,2,4 liberam.
	var needed: Array[int] = [0, 25, 50, 90]
	return value() >= needed[category]
