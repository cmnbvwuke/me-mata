class_name CoverPoint
extends Marker3D
## Ponto de cobertura usado pela IA. A segurança do ponto é avaliada em tempo
## real (raycast a partir do jogador), então não importa a orientação do marcador.
## Coloque-os rente a obstáculos baixos (~1 m) para permitir "agachar e expor".

var occupant: Node = null


func _ready() -> void:
	add_to_group("cover_point")


func is_free_for(who: Node) -> bool:
	return occupant == null or occupant == who or not is_instance_valid(occupant)
