class_name Grenade
extends Node3D
## Granada de fragmentação lançada pela elite: voa em arco até o alvo, fica no
## chão com o aviso "GRANADA!" e explode. Só fere o jogador (a Guarda Negra não
## arrisca o próprio General) e a cobertura protege (linha de visão até o centro).

const FUSE := 1.8
const RADIUS := 7.0
const MAX_DAMAGE := 85.0

var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _flight := 1.0
var _t := 0.0
var _landed := false
var _beep := 0.0
var _label: Label3D


## Lança de `from` para `to` (a altura do arco cresce com a distância).
func launch(from: Vector3, to: Vector3) -> void:
	_from = from
	_to = to
	_flight = clampf(from.distance_to(to) / 13.0, 0.5, 2.0)
	global_position = from


func _ready() -> void:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.055
	s.height = 0.11
	mi.mesh = s
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.18, 0.22, 0.14)
	m.roughness = 0.7
	mi.material_override = m
	add_child(mi)
	_label = Label3D.new()
	_label.text = "GRANADA!"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = true
	_label.pixel_size = 0.0012
	_label.font_size = 28
	_label.outline_size = 8
	_label.modulate = Color(1.0, 0.2, 0.15)
	_label.position = Vector3(0, 0.45, 0)
	_label.visible = false
	add_child(_label)


func _process(delta: float) -> void:
	_t += delta
	if not _landed:
		var k := minf(_t / _flight, 1.0)
		var arc := 4.0 * k * (1.0 - k) * clampf(_from.distance_to(_to) * 0.18, 1.0, 4.0)
		global_position = _from.lerp(_to, k) + Vector3.UP * arc
		if k >= 1.0:
			_landed = true
			_t = 0.0
			_label.visible = true
			AudioManager.play_3d("radio_beep", global_position, -4.0, 25.0, 3.0)
		return
	_label.modulate.a = 0.6 + 0.4 * sin(_t * 18.0)
	_beep -= delta
	if _beep <= 0.0:
		_beep = 0.45
		AudioManager.play_3d("radio_beep", global_position, -8.0, 20.0, 2.0)
	if _t >= FUSE:
		_explode()


func _explode() -> void:
	var pos := global_position + Vector3.UP * 0.15
	FX.explosion(self, pos, RADIUS * 0.6)
	AudioManager.play_3d("explosion", pos, 2.0, 200.0, 10.0)
	StealthSystem.emit_noise(pos, 90.0, self)
	var player := get_tree().get_first_node_in_group("player") as Player
	if player and not player.is_dead:
		var target := player.global_position + Vector3.UP * 0.9
		var d := target.distance_to(pos)
		player.add_shake(clampf(1.0 - d / 30.0, 0.0, 0.9))
		if d < RADIUS and _clear(pos, target):
			var info := DamageInfo.new(MAX_DAMAGE * (1.0 - d / RADIUS), self, pos, target)
			info.is_explosion = true
			player.take_damage(info)
	queue_free()


## A cobertura protege: precisa haver linha livre (só cenário bloqueia).
func _clear(from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()
