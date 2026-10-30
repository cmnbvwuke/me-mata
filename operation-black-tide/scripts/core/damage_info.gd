class_name DamageInfo
extends RefCounted
## Pacote de dados de dano. Qualquer objeto que implemente
## `take_damage(info: DamageInfo)` pode receber dano (jogador, inimigos, HVT).

var amount: float = 0.0
var source: Node = null            # Quem causou o dano
var origin: Vector3 = Vector3.ZERO # De onde o dano veio (para o indicador direcional)
var hit_position: Vector3 = Vector3.ZERO
var hit_normal: Vector3 = Vector3.UP
var is_headshot: bool = false
var is_explosion: bool = false


func _init(p_amount: float = 0.0, p_source: Node = null, p_origin: Vector3 = Vector3.ZERO,
		p_hit_position: Vector3 = Vector3.ZERO, p_hit_normal: Vector3 = Vector3.UP) -> void:
	amount = p_amount
	source = p_source
	origin = p_origin
	hit_position = p_hit_position
	hit_normal = p_hit_normal
