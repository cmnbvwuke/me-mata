class_name WeaponData
extends Resource
## Definição de uma arma (dados puros). Crie novas armas duplicando um .tres
## em res://resources/weapons/ e ajustando os valores no Inspector.

@export_group("Identidade")
@export var weapon_name: String = "Arma"
## Tipo do modelo procedural da viewmodel: "rifle" ou "pistol".
@export var model_type: String = "rifle"
@export var sound_name: String = "rifle_shot"
@export var shot_volume_db: float = 0.0
@export var suppressed: bool = false

@export_group("Balística")
@export var damage: float = 34.0
@export var headshot_multiplier: float = 3.6
## Cadência em disparos por minuto.
@export var fire_rate: float = 750.0
@export var max_range: float = 250.0
@export var allows_auto: bool = true
@export var default_auto: bool = true

@export_group("Munição")
@export var magazine_size: int = 30
@export var reserve_ammo: int = 150
## Recarga tática (ainda há munição na arma) e recarga com arma vazia.
@export var reload_time: float = 2.1
@export var empty_reload_time: float = 2.7
@export var equip_time: float = 0.45

@export_group("Precisão (graus)")
@export var hip_spread: float = 3.2
@export var ads_spread: float = 0.25
@export var move_spread: float = 2.5
## Abertura extra por disparo e velocidade de recuperação por segundo.
@export var spread_per_shot: float = 0.45
@export var spread_recovery: float = 6.0

@export_group("Recuo da câmera (graus)")
## Subida da mira por disparo.
@export var recoil_vertical: float = 0.9
## Desvio lateral aleatório por disparo (±).
@export var recoil_horizontal: float = 0.35
## Tendência do desvio lateral: -1 puxa para a esquerda, +1 para a direita.
@export_range(-1.0, 1.0) var recoil_horizontal_bias: float = 0.0
## Multiplicador do primeiro disparo de uma sequência (tiro inicial mais controlado).
@export var recoil_first_shot: float = 1.0
## Aumento da subida a cada disparo seguido (0.1 = +10% por tiro) e o limite.
@export var recoil_climb: float = 0.0
@export var recoil_climb_max: float = 0.0
## Tempo sem atirar (s) para a sequência zerar e a mira começar a voltar.
@export var recoil_reset_time: float = 0.25
## Redução ao mirar e agachado.
@export var recoil_ads_mult: float = 0.65
@export var recoil_crouch_mult: float = 0.8
## O recuo empurra a mira de verdade e acumula enquanto se atira (o jogador
## compensa puxando o mouse para baixo). Ao parar, só esta fração da subida
## volta sozinha (o que o jogador já compensou não volta).
@export_range(0.0, 1.0) var recoil_return: float = 0.5
## Rapidez com que a mira sobe a cada tiro (snap) e com que a fração volta (recovery).
@export var recoil_snap: float = 18.0
@export var recoil_recovery: float = 5.0
## Tremor da câmera por disparo.
@export var recoil_shake: float = 0.05

@export_group("Coice da arma (viewmodel)")
## Recuo para trás (m), cano subindo (rad), giro lateral e rolagem aleatórios (rad).
@export var kick_back: float = 0.05
@export var kick_pitch: float = 0.07
@export var kick_yaw: float = 0.0
@export var kick_roll: float = 0.0
## Rapidez com que a arma volta à posição.
@export var kick_recovery: float = 11.0

@export_group("Mira (ADS)")
@export var ads_fov: float = 52.0
@export var ads_time: float = 0.2
@export var hip_position: Vector3 = Vector3(0.18, -0.17, -0.38)
@export var ads_position: Vector3 = Vector3(0.0, -0.088, -0.34)

@export_group("Furtividade")
## Raio (m) em que inimigos ouvem o disparo. >= 25 é tratado como "tiro alto".
@export var noise_radius: float = 60.0
