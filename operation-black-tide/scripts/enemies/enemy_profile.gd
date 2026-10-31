class_name EnemyProfile
extends Resource
## Perfil de um tipo de inimigo (guarda comum, elite, milícia...).
## Novos tipos = novo .tres em res://resources/enemies/.

@export_group("Identidade")
@export var type_name: String = "Guarda"
@export var body_color: Color = Color(0.22, 0.25, 0.18)
@export var vest_color: Color = Color(0.12, 0.13, 0.1)
@export var has_helmet: bool = false
@export var has_flashlight: bool = true
@export var weapon_sound: String = "enemy_rifle"
## Usa o modelo animado do soldado raso (SoldierModel) em vez do boneco procedural.
@export var use_soldier_model: bool = false

@export_group("Atributos")
@export var max_health: float = 100.0
## Redução de dano no torso (colete). Tiros na cabeça ignoram.
@export_range(0.0, 0.9) var armor: float = 0.0
@export var walk_speed: float = 1.7
@export var run_speed: float = 4.2

@export_group("Percepção")
@export var vision_range: float = 24.0
@export var vision_fov: float = 110.0
@export var hearing_multiplier: float = 1.0
## Multiplicador da velocidade com que a suspeita sobe ao ver o jogador.
@export var detection_speed: float = 1.0
## Atraso (s) entre ver o jogador em combate e começar a atirar.
@export var reaction_time: float = 0.65

@export_group("Combate")
@export_range(0.0, 1.0) var accuracy: float = 0.5
@export var damage: float = 6.0
@export var fire_rate: float = 480.0
@export var burst_min: int = 3
@export var burst_max: int = 5

@export_group("Tática")
@export var uses_cover: bool = true
@export_range(0.0, 1.0) var flank_chance: float = 0.15
## Chance de avançar agressivamente sobre o jogador a cada decisão.
@export_range(0.0, 1.0) var aggression: float = 0.2
