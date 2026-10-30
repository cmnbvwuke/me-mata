class_name AirSupport
extends Node
## Apoio aéreo (Viper 2-1). O jogador mira e aperta [T] para designar o alvo;
## após alguns segundos, três impactos de foguete atingem a área.
## Restrições realistas: precisa de céu aberto sobre o alvo e não atira
## "perto demais" do operador (danger close).

signal message(text: String)
signal charges_changed(charges: int, available: bool)

@export var charges: int = 2
@export var delay: float = 2.6
@export var radius: float = 7.0
@export var max_damage: float = 260.0
@export var min_safe_distance: float = 12.0

var available: bool = false
var _busy := false


func _ready() -> void:
	add_to_group("air_support")


func set_available(value: bool) -> void:
	available = value
	charges_changed.emit(charges, available)


func report(text: String) -> void:
	message.emit(text)


func request_strike(point: Vector3, requester: Node3D) -> void:
	if not available:
		report("OVERLORD: Negativo, apoio aéreo indisponível no momento.")
		return
	if charges <= 0:
		report("VIPER 2-1: Sem munição para apoio. Estamos Winchester.")
		return
	if _busy:
		report("VIPER 2-1: Aguarde, ainda em corrida de ataque.")
		return
	var space := requester.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.5, point + Vector3.UP * 80.0, Layers.WORLD)
	if not space.intersect_ray(q).is_empty():
		report("VIPER 2-1: Alvo coberto, sem linha de tiro. Marque área aberta.")
		return
	if requester.global_position.distance_to(point) < min_safe_distance:
		report("VIPER 2-1: Perigo próximo! Negativo, vocês estão muito perto.")
		return
	charges -= 1
	_busy = true
	charges_changed.emit(charges, available)
	AudioManager.play_2d("radio_beep", -4.0)
	report("VIPER 2-1: Alvo marcado. Foguetes em %d segundos — abriguem-se!" % int(ceil(delay)))
	_spawn_laser_marker(point)
	var tw := create_tween()
	tw.tween_interval(delay)
	for i in 3:
		var offset := Vector3(randf_range(-3.0, 3.0), 0.0, randf_range(-3.0, 3.0))
		if i == 0:
			offset = Vector3.ZERO
		tw.tween_callback(_impact.bind(point + offset))
		tw.tween_interval(0.35)
	tw.tween_callback(func() -> void: _busy = false)


func _spawn_laser_marker(point: Vector3) -> void:
	var root := get_tree().current_scene
	var marker := OmniLight3D.new()
	marker.light_color = Color(1.0, 0.1, 0.05)
	marker.light_energy = 2.0
	marker.omni_range = 3.0
	root.add_child(marker)
	marker.global_position = point + Vector3.UP * 0.3
	var tw := marker.create_tween().set_loops(int(delay / 0.3))
	tw.tween_property(marker, "light_energy", 0.2, 0.15)
	tw.tween_property(marker, "light_energy", 2.0, 0.15)
	var t := Timer.new()
	t.wait_time = delay + 0.1
	t.one_shot = true
	t.autostart = true
	t.timeout.connect(marker.queue_free)
	marker.add_child(t)


func _impact(pos: Vector3) -> void:
	FX.tracer(self, pos + Vector3(25.0, 90.0, 15.0), pos, Color(1.0, 0.85, 0.5))
	FX.explosion(self, pos, radius)
	var space := get_viewport().find_world_3d().direct_space_state
	var targets: Array[Node] = []
	targets.append_array(get_tree().get_nodes_in_group("enemies"))
	targets.append_array(get_tree().get_nodes_in_group("player"))
	targets.append_array(get_tree().get_nodes_in_group("hvt"))
	for node in targets:
		var body := node as Node3D
		if body == null or not body.has_method("take_damage"):
			continue
		var center := body.global_position + Vector3.UP * 0.9
		var d := center.distance_to(pos)
		if body is Player:
			(body as Player).add_shake(clampf(1.0 - d / 45.0, 0.0, 0.9))
		if d > radius:
			continue
		var dmg := max_damage * (1.0 - d / radius)
		var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.5, center, Layers.WORLD)
		if not space.intersect_ray(q).is_empty():
			dmg *= 0.3  # protegido por cobertura
		var info := DamageInfo.new(dmg, null, pos, center)
		info.is_explosion = true
		body.take_damage(info)
