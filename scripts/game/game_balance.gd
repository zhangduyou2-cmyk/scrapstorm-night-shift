class_name ScrapBalance
extends Resource
## Read-only tuning defaults. Runtime state belongs to ScrapWorld, never here.

@export var shift_duration: float = 180.0
@export var player_health: float = 100.0
@export var player_speed: float = 215.0
@export var player_radius: float = 19.0
@export var vacuum_move_scale: float = 0.79
@export var vacuum_range: float = 240.0
@export var vacuum_half_angle: float = 0.66
@export var vacuum_pull: float = 800.0
@export var vacuum_enemy_stop: float = 79.0
@export var pickup_radius: float = 27.0
@export var energy_per_scrap: float = 9.0
@export var energy_capacity: float = 100.0
@export var brush_radius: float = 68.0
@export var brush_interval: float = 0.55
@export var brush_damage: float = 13.0
@export var contact_damage: float = 12.0
@export var hurt_invulnerability: float = 0.9
@export var dash_speed: float = 780.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 1.65
@export var max_enemies: int = 100
@export var max_scrap: int = 150
@export var max_particles: int = 240
@export var wave_duration: float = 55.0
@export var ordinary_waves: int = 5
@export var wave_salary: int = 18
@export var shop_repair: float = 20.0
@export var foam_duration: float = 3.0
@export var foam_interval: float = 2.4
@export var arc_interval: float = 1.5
@export var max_foam: int = 10
@export var max_projectiles: int = 70
@export var boss_health: float = 1800.0
