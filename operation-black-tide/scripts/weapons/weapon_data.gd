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

@export_group("Recuo (graus)")
@export var recoil_vertical: float = 0.9
@export var recoil_horizontal: float = 0.35

@export_group("Mira (ADS)")
@export var ads_fov: float = 52.0
@export var ads_time: float = 0.2
@export var hip_position: Vector3 = Vector3(0.18, -0.17, -0.38)
@export var ads_position: Vector3 = Vector3(0.0, -0.088, -0.34)

@export_group("Furtividade")
## Raio (m) em que inimigos ouvem o disparo. >= 25 é tratado como "tiro alto".
@export var noise_radius: float = 60.0
