extends Node
## StealthSystem (autoload)
## Barramento de eventos de furtividade:
##  * Ruídos (passos, disparos, quedas) são emitidos com um raio audível;
##    cada inimigo decide se ouviu, considerando paredes no caminho.
##  * Alarme global: disparado quando um inimigo consegue reportar contato.
##  * Agrega o nível de "suspeita" dos inimigos para o HUD.

signal noise_emitted(position: Vector3, radius: float, source: Node)
signal alarm_raised(position: Vector3)

var alarm_active: bool = false
var _awareness: Dictionary = {}   # instance_id -> float (0..1, 1 = combate)


func emit_noise(position: Vector3, radius: float, source: Node = null) -> void:
	if radius <= 0.0:
		return
	noise_emitted.emit(position, radius, source)


func raise_alarm(position: Vector3) -> void:
	if alarm_active:
		return
	alarm_active = true
	GameManager.add_stat("times_detected")
	alarm_raised.emit(position)


func report_awareness(reporter: Node, value: float) -> void:
	_awareness[reporter.get_instance_id()] = value


func clear_awareness(reporter: Node) -> void:
	_awareness.erase(reporter.get_instance_id())


## Maior nível de suspeita entre todos os inimigos vivos (0..1).
func get_max_awareness() -> float:
	var best := 0.0
	for v in _awareness.values():
		best = maxf(best, float(v))
	return best


func reset() -> void:
	alarm_active = false
	_awareness.clear()
