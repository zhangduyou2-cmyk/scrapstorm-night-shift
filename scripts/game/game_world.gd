class_name ScrapWorld
extends Node2D
## Three-minute arena prototype. The shell owns menus, settings and translations.
## Enemies and drops have one owner and settle once through the methods below.

signal stats_changed(stats: Dictionary)
signal run_finished(won: bool, stats: Dictionary)
signal sound_requested(event: String)
signal wave_completed(summary: Dictionary)

const Balance = preload("res://scripts/game/game_balance.gd")
const Loadout = preload("res://scripts/game/run_loadout.gd")
const Maps = preload("res://scripts/game/map_catalog.gd")
const Director = preload("res://scripts/game/standard_director.gd")
const BossBrain = preload("res://scripts/game/standard_boss.gd")
const Ability = preload("res://scripts/game/player_ability.gd")
const Feedback = preload("res://scripts/game/combat_feedback.gd")
const Evolution = preload("res://scripts/game/evolution_effects.gd")
const ArenaDetail = preload("res://scripts/game/arena_detail.gd")
const Overtime = preload("res://scripts/game/overtime_director.gd")
const Arsenal = preload("res://scripts/game/arsenal_effects.gd")
const EnemyAtlas = preload("res://scripts/game/enemy_atlas.gd")
const ARENA: Rect2 = Rect2(42.0, 116.0, 1196.0, 548.0)
const FLOOR: Color = Color("14252c")
const DARK: Color = Color("09161e")
const INK: Color = Color("0a171d")
const TEAL: Color = Color("6df5bf")
const YELLOW: Color = Color("ffcf5c")
const ORANGE: Color = Color("ff8559")
const RED: Color = Color("ff5b61")

var balance: Resource = Balance.new()
var active: bool = false
var use_sprite_atlas: bool = true
var paused: bool = false
var player_position: Vector2 = Vector2(640.0, 390.0)
var player_aim: Vector2 = Vector2.RIGHT
var aim_position: Vector2 = Vector2.ZERO
var _feedback: RefCounted = Feedback.new()
var _evolution: RefCounted = Evolution.new()
var ability_notice: String = ""
var _notice_time: float = 0.0
var health: float = 100.0
var currency: int = 0
var energy: float = 0.0
var kills: int = 0
var elapsed: float = 0.0
var shots: int = 0
var total_scrap: int = 0
var demo_mode: bool = false
var standard_mode: bool = false
var endless_mode: bool = false
var extracted: bool = false
var metrics_known: bool = true
var damage_taken: float = 0.0
var damage_events: int = 0
var boss_damage_taken: float = 0.0
var boss_kills: int = 0
var evolutions_seen: Array[String] = []
var _overtime: RefCounted = Overtime.new()
var _arsenal: RefCounted = Arsenal.new()
var map_id: String = "yard"
var player_skin: String = "industrial"
var skill_color: Color = Color("6df5bf")
var damage_by_source: Dictionary = {}
var last_damage_source: String = ""
var combo: int = 0
var _combo_timer: float = 0.0
var _combo_awarded: int = 0
var _damage_direction: Vector2 = Vector2.ZERO
var _map_data: Dictionary = Maps.get_map("yard")
var _director: RefCounted = Director.new()
var _boss_brain: RefCounted = BossBrain.new()
var _ability: RefCounted = null
var _setup: Dictionary = {}
var _saws: Array[Dictionary] = []
var _saw_timer: float = 0.4
var _earned_currency: int = 0
var wave_index: int = 1
var wave_elapsed: float = 0.0
var phase: String = "combat"
var _loadout: RefCounted = Loadout.new()
var _modifiers: Dictionary = {"health_bonus": 0.0, "speed_scale": 1.0, "vacuum_scale": 1.0, "energy_scale": 1.0, "damage_scale": 1.0, "cooldown_scale": 1.0}
var _wave_pickups_start: int = 0
var _projectiles: Array[Dictionary] = []
var _foam: Array[Dictionary] = []
var _arcs: Array[Dictionary] = []
var _foam_timer: float = 0.0
var _arc_timer: float = 0.0
var _boss: Dictionary = {}
var _boss_defeated: bool = false
var _boss_supply_energy: float = 0.0
var _boss_supply_charge: float = 0.0
var _boss_batteries_destroyed: int = 0

var _enemies: Array[Dictionary] = []
var _scraps: Array[Dictionary] = []
var _particles: Array[Dictionary] = []
var _waves: Array[Dictionary] = []
var _dash_ghosts: Array[Dictionary] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _fx_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _obstacles: Array[Rect2] = [
	Rect2(237.0, 236.0, 70.0, 56.0), Rect2(973.0, 236.0, 70.0, 56.0),
	Rect2(237.0, 500.0, 70.0, 56.0), Rect2(973.0, 500.0, 70.0, 56.0),
]
var _vacuum: bool = false
var _vacuum_gate: bool = false
var _dash_left: float = 0.0
var _dash_cooldown: float = 0.0
var _dash_direction: Vector2 = Vector2.RIGHT
var _invulnerability: float = 0.0
var _brush_timer: float = 0.0
var _brush_flash: float = 0.0
var _spawn_timer: float = 0.0
var _stats_timer: float = 0.0
var _visual_time: float = 0.0
var _hurt_flash: float = 0.0
var _reclaim_flash: float = 0.0
var _next_enemy_id: int = 0
var _last_health_milestone: int = 0
var _player_velocity: Vector2 = Vector2.ZERO
var _settings: Node = null


func _ready() -> void:
	_fx_rng.randomize()
	_settings = get_node_or_null("/root/Settings")
	queue_redraw()


func start_run(seed_value: int = 0, demo: bool = false) -> void:
	_feedback.reset()
	_evolution.clear()
	_evolution.known.clear()
	position = Vector2.ZERO
	aim_position = Vector2.ZERO
	ability_notice = ""
	_notice_time = 0.0
	standard_mode = false
	endless_mode = false
	extracted = false
	metrics_known = true
	damage_taken = 0.0
	damage_events = 0
	boss_damage_taken = 0.0
	boss_kills = 0
	evolutions_seen.clear()
	_arsenal.clear()
	map_id = "yard"
	_setup.clear()
	_map_data = Maps.get_map(map_id)
	_obstacles.assign(_map_data.obstacles)
	_director.reset()
	player_skin = "industrial"
	skill_color = TEAL
	damage_by_source.clear()
	last_damage_source = ""
	combo = 0
	_combo_timer = 0.0
	_combo_awarded = 0
	_damage_direction = Vector2.ZERO
	_earned_currency = 0
	_saws.clear()
	_saw_timer = 0.4
	_ability = Ability.new()
	_ability.configure({})
	_enemies.clear()
	_scraps.clear()
	_particles.clear()
	_waves.clear()
	_dash_ghosts.clear()
	if seed_value == 0:
		_rng.randomize()
	else:
		_rng.seed = seed_value
	_fx_rng.randomize()
	demo_mode = demo
	phase = "combat"
	wave_index = 1
	wave_elapsed = 0.0
	total_scrap = 0
	_wave_pickups_start = 0
	_projectiles.clear()
	_foam.clear()
	_arcs.clear()
	_boss.clear()
	_boss_defeated = false
	_boss_supply_energy = 0.0
	_boss_supply_charge = 0.0
	_boss_batteries_destroyed = 0
	_foam_timer = 0.8
	_arc_timer = 0.5
	_loadout.reset(_rng.seed)
	_refresh_modifiers()
	active = true
	paused = false
	player_position = ARENA.get_center()
	player_aim = Vector2.RIGHT
	_player_velocity = Vector2.ZERO
	health = float(balance.player_health)
	currency = 0
	energy = 0.0
	kills = 0
	elapsed = 0.0
	shots = 0
	_dash_left = 0.0
	_dash_cooldown = 0.0
	_invulnerability = 0.0
	_brush_timer = 0.2
	_brush_flash = 0.0
	_spawn_timer = 1.5
	_stats_timer = 0.0
	_hurt_flash = 0.0
	_reclaim_flash = 0.0
	_visual_time = 0.0
	_next_enemy_id = 0
	_last_health_milestone = 0
	cancel_input()
	# A starter trail makes the reclaim / discharge loop discoverable immediately.
	for index: int in range(7):
		var angle: float = -0.45 + float(index) * 0.15
		debug_add_scrap(player_position + Vector2.from_angle(angle) * 130.0, 1)
	_emit_stats()
	queue_redraw()


func start_standard(selected_map: String, seed_value: int = 0, setup: Dictionary = {}) -> void:
	start_run(seed_value, true)
	standard_mode = true
	map_id = selected_map if selected_map in Maps.ids() else "yard"
	_map_data = Maps.get_map(map_id)
	_obstacles.assign(_map_data.obstacles)
	_setup = setup.duplicate(true)
	_loadout.price_scale = 2.8
	player_skin = str(setup.get("skin", "industrial"))
	var colors: Dictionary = Ability.COLORS
	skill_color = colors.get(str(setup.get("skill_color", "mint")), TEAL)
	if _ability != null:
		_ability.configure(setup)
	player_position = _move_body(player_position, Vector2.ZERO, float(balance.player_radius))
	_emit_stats()
	queue_redraw()


func _current_wave_duration() -> float:
	if endless_mode:
		return _overtime.duration()
	return Maps.stage_duration(wave_index) if standard_mode else float(balance.wave_duration)


func _line_clear(start: Vector2, end: Vector2) -> bool:
	# Slab intersection: tools and hostile bullets use the same opaque crates.
	var direction: Vector2 = end - start
	var left: float = minf(start.x, end.x)
	var right: float = maxf(start.x, end.x)
	var top: float = minf(start.y, end.y)
	var bottom: float = maxf(start.y, end.y)
	for obstacle: Rect2 in _obstacles:
		# Most projectile segments and tool rays miss a crate's bounding box.
		if right < obstacle.position.x or left > obstacle.end.x or bottom < obstacle.position.y or top > obstacle.end.y:
			continue
		var near: float = 0.0
		var far: float = 1.0
		var intersects: bool = true
		for axis: int in range(2):
			if absf(direction[axis]) < 0.0001:
				if start[axis] < obstacle.position[axis] or start[axis] > obstacle.end[axis]:
					intersects = false
					break
			else:
				var a: float = (obstacle.position[axis] - start[axis]) / direction[axis]
				var b: float = (obstacle.end[axis] - start[axis]) / direction[axis]
				near = maxf(near, minf(a, b))
				far = minf(far, maxf(a, b))
				if near > far:
					intersects = false
					break
		if intersects:
			return false
	return true


func _max_health() -> float:
	return float(balance.player_health) + float(_modifiers["health_bonus"])


func _max_energy() -> float:
	return float(balance.energy_capacity) * float(_modifiers["energy_scale"])


func _vacuum_range() -> float:
	return float(balance.vacuum_range) * float(_modifiers["vacuum_scale"])


func _cooldown(base: float) -> float:
	return base * float(_modifiers["cooldown_scale"])


func _weapon_level(id: String) -> int:
	return int(_loadout.weapons.get(id, 0))


func _brush_radius() -> float:
	return float(Loadout.tool_stats("brush", _weapon_level("brush")).radius)


func get_shop_offers() -> Array:
	return _loadout.get_offers() if phase == "shop" else []


func buy_offer(token: String) -> Dictionary:
	if not active or phase != "shop" or not demo_mode:
		return {"ok": false, "reason": "SHOP_NOT_OPEN", "cost": 0}
	var previous_maximum: float = _max_health()
	var result: Dictionary = _loadout.purchase(token, currency)
	if bool(result.get("ok", false)):
		currency -= int(result["cost"])
		_refresh_modifiers()
		if health > 0.0:
			health = minf(_max_health(), health + _max_health() - previous_maximum + float(result.get("repair_amount", 0.0)))
		_evolution.refresh(self)
		_emit_stats()
	return result


func reroll_shop() -> Dictionary:
	if not active or phase != "shop" or not demo_mode:
		return {"ok": false, "cost": 0, "reason": "SHOP_NOT_OPEN"}
	var result: Dictionary = _loadout.reroll(currency, wave_index)
	if bool(result.get("ok", false)):
		currency -= int(result.cost)
		_emit_stats()
	return result


func choose_ability_branch(id: String) -> Dictionary:
	if not active or phase != "shop":
		return {"ok": false, "reason": "SHOP_NOT_OPEN"}
	var result: Dictionary = _ability.choose_branch(id, wave_index)
	if result.get("ok", false):
		sound_requested.emit("evolve")
		_emit_stats()
	return result


func sell_weapon(id: String) -> Dictionary:
	if not active or phase != "shop":
		return {"ok": false, "reason": "SHOP_NOT_OPEN"}
	var result: Dictionary = _loadout.sell_weapon(id, wave_index)
	if result.get("ok", false):
		currency += int(result.refund)
		_refresh_modifiers()
		_evolution.refresh(self)
		_emit_stats()
	return result


func notify_ability_event(key: String) -> void:
	ability_notice = key
	_notice_time = 1.4
	if key == "ABILITY_CAST":
		if endless_mode:
			_overtime.last_uses = _ability.uses
			if _overtime.rank("bulwark") > 0:
				_overtime.shield = 1.5 + _overtime.rank("bulwark") * 0.4
		sound_requested.emit("skill_" + str(_ability.skill))
	elif key == "ABILITY_READY":
		sound_requested.emit("skill_ready")
	_emit_stats()


func combat_feedback(at: Vector2, strength: float, kind: String = "impact") -> void:
	var tint: Color = Color("ff795a") if kind == "hurt" else (Color("ffc04d") if kind in ["boss", "break"] else skill_color)
	_feedback.burst(at, strength, kind, tint, _effects_enabled())
	queue_redraw()


func create_checkpoint() -> Dictionary:
	if not active or not standard_mode or phase != "shop" or health <= 0.0:
		return {}
	return {
		"version": 1, "map_id": map_id, "setup": _setup.duplicate(true),
		"seed": str(_rng.seed), "rng_state": str(_rng.state), "wave": wave_index,
		"player_position": [player_position.x, player_position.y], "player_aim": [player_aim.x, player_aim.y], "visual_time": _visual_time,
		"health": health, "currency": currency, "energy": energy, "kills": kills,
		"elapsed": elapsed, "wave_elapsed": wave_elapsed, "shots": shots, "total_scrap": total_scrap,
		"earned_currency": _earned_currency, "wave_pickups_start": _wave_pickups_start,
		"health_milestone": _last_health_milestone, "next_enemy_id": _next_enemy_id,
		"dash_cooldown": _dash_cooldown, "invulnerability": _invulnerability,
		"damage_by_source": damage_by_source.duplicate(true), "last_damage_source": last_damage_source,
		"combo": combo, "combo_timer": _combo_timer, "combo_awarded": _combo_awarded,
		"salvage_objectives": _director.salvage_completed, "event_serial": _director.event_serial, "loadout": _loadout.export_state(),
		"ability": _ability.export_state() if _ability != null else {},
		"director": _director.export_state(),
		"arsenal": _arsenal.export_state(), "endless_mode": endless_mode,
		"overtime": _overtime.export_state() if endless_mode else {},
		"metrics_known": metrics_known, "damage_taken": damage_taken, "damage_events": damage_events,
		"boss_damage_taken": boss_damage_taken, "boss_kills": boss_kills, "evolutions_seen": evolutions_seen.duplicate(),
	}


func restore_checkpoint(data: Dictionary) -> bool:
	# Validate into a temporary loadout before mutating the live world.
	if int(data.get("version", 0)) != 1 or str(data.get("map_id", "")) not in Maps.ids():
		return false
	if not data.get("setup", {}) is Dictionary or not data.get("loadout", null) is Dictionary:
		return false
	var saved_wave: int = int(data.get("wave", 0))
	if saved_wave < 1 or saved_wave > (1000000 if data.get("endless_mode", false) == true else 5):
		return false
	for key: String in ["health", "currency", "energy", "kills", "elapsed", "wave_elapsed", "shots", "total_scrap", "earned_currency", "health_milestone", "next_enemy_id", "dash_cooldown", "invulnerability", "combo", "combo_timer", "combo_awarded", "salvage_objectives", "wave_pickups_start", "visual_time", "event_serial"]:
		var value: Variant = data.get(key, null)
		if not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0.0 or float(value) > 100000000.0:
			return false
	if float(data.health) <= 0.0 or not str(data.get("seed", "")).is_valid_int() or not str(data.get("rng_state", "")).is_valid_int():
		return false
	if not data.get("damage_by_source", null) is Dictionary or not data.get("ability", {}) is Dictionary:
		return false
	for key: String in ["player_position", "player_aim"]:
		if not data.get(key, null) is Array or data[key].size() != 2:
			return false
		for component: Variant in data[key]:
			if not (component is int or component is float) or not is_finite(float(component)) or absf(float(component)) > 2000.0:
				return false
	if not ARENA.has_point(Vector2(float(data.player_position[0]), float(data.player_position[1]))):
		return false
	for amount: Variant in data.damage_by_source.values():
		if not (amount is int or amount is float) or not is_finite(float(amount)) or float(amount) < 0.0:
			return false
	if not data.get("endless_mode", false) is bool or not data.get("metrics_known", false) is bool:
		return false
	for key: String in ["damage_taken", "damage_events", "boss_damage_taken", "boss_kills"]:
		var value: Variant = data.get(key, 0)
		if not (value is int or value is float) or not is_finite(float(value)) or value < 0 or value > 100000000:
			return false
		if key in ["damage_events", "boss_kills"] and float(value) != floorf(float(value)):
			return false
	if float(data.get("boss_damage_taken", 0)) > float(data.get("damage_taken", 0)):
		return false
	if not data.get("evolutions_seen", []) is Array:
		return false
	var seen_evolutions: Array[String] = []
	for id: Variant in data.get("evolutions_seen", []):
		if not id is String or not Loadout.EVOLUTIONS.has(id) or id in seen_evolutions:
			return false
		seen_evolutions.append(id)
	var restored_overtime: RefCounted = Overtime.new()
	if data.get("endless_mode", false):
		if not data.get("overtime") is Dictionary or not restored_overtime.import_state(data.overtime) or restored_overtime.room != saved_wave or restored_overtime.map_id() != str(data.map_id):
			return false
		if int(data.get("boss_kills", 0)) != restored_overtime.completed / 3:
			return false
	var restored_arsenal: RefCounted = Arsenal.new()
	if data.has("arsenal") and (not data.arsenal is Dictionary or not restored_arsenal.import_state(data.arsenal)):
		return false
	var restored_loadout: RefCounted = Loadout.new()
	if not restored_loadout.import_state(data.loadout):
		return false
	var restored_ability: RefCounted = Ability.new()
	if not restored_ability.import_state(data.get("ability", {})):
		return false
	var restored_director: RefCounted = Director.new()
	restored_director.clear_stage()
	if data.has("director") and (not data.director is Dictionary or not restored_director.import_state(data.director)):
		return false
	if data.get("endless_mode", false) and restored_loadout.slots != 4:
		return false
	var restored_mods: Dictionary = restored_loadout.get_modifiers()
	if data.get("endless_mode", false):
		restored_mods = restored_overtime.modify(restored_mods)
	if float(data.health) > float(balance.player_health) + float(restored_mods.health_bonus) or float(data.energy) > float(balance.energy_capacity) * float(restored_mods.energy_scale):
		return false
	start_standard(str(data.map_id), int(str(data.seed)), data.setup)
	_clear_combat_objects()
	endless_mode = bool(data.get("endless_mode", false))
	_overtime = restored_overtime
	_arsenal = restored_arsenal
	metrics_known = bool(data.get("metrics_known", false)) and data.has("damage_taken") and data.has("damage_events") and data.has("boss_damage_taken")
	damage_taken = float(data.get("damage_taken", 0.0))
	damage_events = int(data.get("damage_events", 0))
	boss_damage_taken = float(data.get("boss_damage_taken", 0.0))
	boss_kills = int(data.get("boss_kills", 0))
	evolutions_seen.assign(data.get("evolutions_seen", []))
	_loadout = restored_loadout
	_modifiers = restored_mods
	_rng.state = int(str(data.rng_state))
	player_position = Vector2(float(data.player_position[0]), float(data.player_position[1]))
	player_aim = Vector2(float(data.player_aim[0]), float(data.player_aim[1])).normalized()
	_visual_time = float(data.visual_time)
	wave_index = saved_wave
	phase = "shop"
	health = float(data.health)
	currency = int(data.currency)
	energy = float(data.energy)
	kills = int(data.kills)
	elapsed = float(data.elapsed)
	wave_elapsed = float(data.wave_elapsed)
	shots = int(data.shots)
	total_scrap = int(data.total_scrap)
	_earned_currency = int(data.earned_currency)
	_wave_pickups_start = int(data.wave_pickups_start)
	_last_health_milestone = int(data.health_milestone)
	_next_enemy_id = int(data.next_enemy_id)
	_dash_cooldown = float(data.dash_cooldown)
	_invulnerability = float(data.invulnerability)
	damage_by_source = data.damage_by_source.duplicate(true)
	last_damage_source = str(data.get("last_damage_source", ""))
	combo = int(data.combo)
	_combo_timer = float(data.combo_timer)
	_combo_awarded = int(data.combo_awarded)
	_director.salvage_completed = int(data.salvage_objectives)
	_director.event_serial = int(data.event_serial)
	_ability = restored_ability
	if data.has("director"):
		_director = restored_director
		_director.salvage_completed = int(data.salvage_objectives)
		_director.event_serial = int(data.event_serial)
	_evolution.refresh(self)
	_emit_stats()
	queue_redraw()
	return true


func _clear_combat_objects() -> void:
	_arsenal.clear()
	_evolution.clear()
	_feedback.reset()
	position = Vector2.ZERO
	_enemies.clear()
	_scraps.clear()
	_projectiles.clear()
	_foam.clear()
	_arcs.clear()
	_particles.clear()
	_waves.clear()
	_dash_ghosts.clear()
	_saws.clear()
	_director.clear_stage()
	if _ability != null:
		_ability.clear_effects()
	_dash_left = 0.0
	cancel_input()


func _complete_wave() -> void:
	if endless_mode:
		_complete_overtime_room()
		return
	if not active or not demo_mode or phase != "combat" or wave_index > 5:
		return
	if health <= 0.0:
		_finish(false)
		return
	phase = "shop"
	var ground_value: int = 0
	for scrap: Dictionary in _scraps:
		ground_value += int(scrap["value"])
	var salary: int = int(balance.wave_salary)
	currency += ground_value + salary
	_earned_currency += ground_value + salary
	var previous_health: float = health
	health = minf(_max_health(), health + float(balance.shop_repair))
	var summary: Dictionary = {"wave": wave_index, "earned_scrap": ground_value, "total_earned": total_scrap - _wave_pickups_start + ground_value + salary, "collected": total_scrap - _wave_pickups_start, "bonus": salary, "repaired": health - previous_health, "currency": currency}
	_clear_combat_objects()
	_loadout.generate_offers(wave_index)
	_emit_stats()
	queue_redraw()
	wave_completed.emit(summary)


func start_next_wave() -> bool:
	if endless_mode:
		return _next_overtime_room()
	if not active or not demo_mode or phase != "shop" or wave_index >= 6:
		return false
	phase = "combat"
	paused = false
	wave_index += 1
	wave_elapsed = 0.0
	_wave_pickups_start = total_scrap
	_spawn_timer = 1.0
	_brush_timer = 0.1
	_foam_timer = 0.3
	_arc_timer = 0.4
	_saw_timer = 0.5
	_invulnerability = maxf(_invulnerability, 1.0)
	cancel_input()
	if wave_index == 6:
		_spawn_boss()
	_emit_stats()
	queue_redraw()
	return true


func set_paused(value: bool) -> void:
	paused = value
	if paused:
		position = Vector2.ZERO
	cancel_input()
	queue_redraw()


func cancel_input() -> void:
	_vacuum = false
	# A held button must be released before another vacuum can begin.
	_vacuum_gate = true
	_player_velocity = Vector2.ZERO
	if _ability != null:
		_ability.cancel_input()


func get_stats() -> Dictionary:
	var result: Dictionary = {
		"health": health, "max_health": _max_health(),
		"currency": currency, "energy": energy,
		"max_energy": _max_energy(), "kills": kills,
		"elapsed": elapsed, "duration": 870.0 if standard_mode else (float(balance.wave_duration) * 5.0 if demo_mode else float(balance.shift_duration)),
		"dash_ratio": 1.0 - clampf(_dash_cooldown / _cooldown(float(balance.dash_cooldown)), 0.0, 1.0),
		"enemies": _enemies.size(), "shots": shots,
		"vacuum": _vacuum, "scrap_on_ground": _scraps.size(),
		"seed": _rng.seed, "rng_state": _rng.state,
		"wave": wave_index, "wave_elapsed": wave_elapsed, "phase": phase,
		"wave_duration": _current_wave_duration() if endless_mode or wave_index <= 5 else 0.0,
		"demo_mode": demo_mode, "total_scrap": total_scrap,
		"loadout": {"weapons": _loadout.weapons.duplicate(true), "mods": _loadout.mods.duplicate(true)}, "weapon_slots": _loadout.slots,
		"boss_health": float(_boss.get("hp", 0.0)), "boss_max_health": float(_boss.get("max_hp", 0.0)),
		"boss_phase_key": str(_boss.get("phase_key", "")), "boss_vulnerable": str(_boss.get("state", "")) == "exposed",
		"boss_exposed_seconds": maxf(0.0, float(_boss.get("state_timer", 0.0))) if str(_boss.get("state", "")) == "exposed" else 0.0,
		"boss_focused": _boss_in_aim(), "boss_supply_energy": _boss_supply_energy,
		"boss_supply_charge": _boss_supply_charge, "boss_batteries_destroyed": _boss_batteries_destroyed,
		"projectiles": _projectiles.size(), "foam_patches": _foam.size(),
		"standard_mode": standard_mode, "map_id": map_id, "map_name_key": str(_map_data.name_key),
		"boss_name_key": str(_map_data.boss_name_key), "wave_name_key": Maps.wave_key(wave_index),
		"objective_key": "OBJECTIVE_SALVAGE" if not _director.salvage.is_empty() else (str(_map_data.mechanic_key) if standard_mode else ""),
		"damage_by_source": damage_by_source.duplicate(true), "last_damage_source": last_damage_source,
		"combo": combo, "combo_ratio": clampf(_combo_timer / 4.0, 0.0, 1.0), "ability_ratio": 1.0,
		"can_reroll": phase == "shop" and _loadout.has_method("can_reroll") and _loadout.can_reroll(),
		"reroll_cost": _loadout.get_reroll_cost(wave_index) if _loadout.has_method("get_reroll_cost") else 0,
		"salvage_objectives": _director.salvage_completed, "earned_currency": _earned_currency,
		"completed_waves": mini(5, wave_index if phase == "shop" else wave_index - 1),
		"player_speed": float(balance.player_speed) * float(_modifiers.speed_scale),
		"vacuum_range": _vacuum_range(), "damage_scale": float(_modifiers.damage_scale), "cooldown_scale": float(_modifiers.cooldown_scale),
	}
	if _ability != null:
		result.merge(_ability.get_stats(), true)
		result["ability_branches"] = _ability.get_branch_options(wave_index) if phase == "shop" else []
	result["ability_notice"] = ability_notice if _notice_time > 0.0 else ""
	result["evolutions"] = _loadout.get_evolutions()
	result["sell_options"] = _loadout.get_sell_options() if phase == "shop" else []
	if standard_mode:
		result.merge(_director.get_stats(self), true)
	result.merge({"endless_mode": endless_mode, "extracted": extracted, "metrics_known": metrics_known, "damage_taken": damage_taken, "damage_events": damage_events, "boss_damage_taken": boss_damage_taken, "boss_kills": boss_kills, "evolutions_seen": evolutions_seen.duplicate()}, true)
	result.merge(_arsenal.get_stats(), true)
	if endless_mode:
		result.merge(_overtime.get_stats(self), true)
	return result


func _physics_process(delta: float) -> void:
	if not paused:
		var stopped: bool = _feedback.tick(delta, _effects_enabled())
		position = _feedback.offset
		_notice_time = maxf(0.0, _notice_time - delta)
		if stopped and active and health > 0.0 and not _boss_defeated and phase == "combat":
			# Brief impact holds must still accept newly pressed controls.
			_update_player(0.0)
			_ability.tick(self, 0.0)
			queue_redraw()
			return
	if not active or paused or phase != "combat":
		queue_redraw()
		return
	_visual_time += delta
	elapsed = elapsed + delta if demo_mode else minf(elapsed + delta, float(balance.shift_duration))
	wave_elapsed += delta
	_invulnerability = maxf(0.0, _invulnerability - delta)
	_dash_cooldown = maxf(0.0, _dash_cooldown - delta)
	_brush_flash = maxf(0.0, _brush_flash - delta)
	_hurt_flash = maxf(0.0, _hurt_flash - delta * 2.5)
	_reclaim_flash = maxf(0.0, _reclaim_flash - delta * 3.0)
	_combo_timer = maxf(0.0, _combo_timer - delta)
	if _combo_timer <= 0.0:
		combo = 0
		_combo_awarded = 0
	_update_player(delta)
	if standard_mode:
		_director.tick(self, delta)
	if endless_mode:
		_overtime.tick(self, delta)
	if _ability != null:
		_ability.tick(self, delta)
	_update_spawning(delta)
	_update_enemies(delta)
	_update_projectiles(delta)
	_update_brush(delta)
	_update_tools(delta)
	_arsenal.tick(self, delta)
	_evolution.tick(self, delta)
	_update_scraps(delta)
	_update_effects(delta)
	# Resolve damage first: death takes precedence over the shift ending this tick.
	if health <= 0.0:
		_finish(false)
		return
	elif endless_mode and _overtime.ready(self):
		_complete_overtime_room()
		return
	elif not endless_mode and demo_mode and _boss_defeated:
		_finish(true)
		return
	elif not endless_mode and demo_mode and wave_index <= 5 and wave_elapsed >= _current_wave_duration():
		_complete_wave()
		return
	elif not demo_mode and elapsed >= float(balance.shift_duration):
		_finish(true)
		return
	_stats_timer -= delta
	if _stats_timer <= 0.0:
		_stats_timer = 0.08
		_emit_stats()
	queue_redraw()


func _update_player(delta: float) -> void:
	aim_position = get_local_mouse_position()
	var mouse_delta: Vector2 = aim_position - player_position
	if mouse_delta.length_squared() > 9.0:
		player_aim = mouse_delta.normalized()
	var input_direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var holding: bool = Input.is_action_pressed("vacuum")
	var toggle: bool = _settings != null and _settings.get("vacuum_toggle") == true
	if _vacuum_gate:
		if not holding:
			_vacuum_gate = false
	elif _dash_left <= 0.0:
		if toggle and Input.is_action_just_pressed("vacuum"):
			_vacuum = not _vacuum
			if not _vacuum:
				_discharge()
		elif not toggle and holding:
			_vacuum = true
		elif not toggle and _vacuum:
			_vacuum = false
			_discharge()
	if Input.is_action_just_pressed("dash") and _dash_cooldown <= 0.0:
		_dash_direction = input_direction if input_direction.length_squared() > 0.01 else player_aim
		_dash_left = float(balance.dash_duration)
		_dash_cooldown = _cooldown(float(balance.dash_cooldown))
		cancel_input()
		sound_requested.emit("dash")
	if _dash_left > 0.0:
		_dash_left = maxf(0.0, _dash_left - delta)
		_player_velocity = _dash_direction * float(balance.dash_speed)
		_dash_ghosts.append({"pos": player_position, "aim": player_aim, "life": 0.22})
	else:
		var speed_scale: float = float(balance.vacuum_move_scale) if _vacuum else 1.0
		_player_velocity = input_direction * float(balance.player_speed) * float(_modifiers["speed_scale"]) * speed_scale
		if _ability != null:
			_player_velocity *= _ability.move_speed_scale()
	if _effects_enabled() and (_dash_left > 0.0 or (_ability != null and _ability.move_speed_scale() > 1.0 and _player_velocity.length() > 20.0)):
		_feedback.trail(player_position, player_aim, skill_color)
	var flow: Vector2 = _director.flow_at(self, player_position)
	player_position = _move_body(player_position, (_player_velocity + flow) * delta, float(balance.player_radius))


func _move_body(position: Vector2, movement: Vector2, radius: float) -> Vector2:
	# Substeps prevent dash tunnelling through crates even on a long physics frame.
	var steps: int = maxi(1, ceili(movement.length() / 9.0))
	var step: Vector2 = movement / float(steps)
	var result: Vector2 = position
	for index: int in range(steps):
		result.x += step.x
		result = _resolve_obstacles(result, radius)
		result.y += step.y
		result = _resolve_obstacles(result, radius)
		result.x = clampf(result.x, ARENA.position.x + radius, ARENA.end.x - radius)
		result.y = clampf(result.y, ARENA.position.y + radius, ARENA.end.y - radius)
	return result


func _resolve_obstacles(position: Vector2, radius: float) -> Vector2:
	var result: Vector2 = position
	for obstacle: Rect2 in _obstacles:
		var nearest: Vector2 = result.clamp(obstacle.position, obstacle.end)
		var difference: Vector2 = result - nearest
		if difference.length_squared() >= radius * radius:
			continue
		var distance: float = difference.length()
		if distance > 0.001 and distance < radius:
			result = nearest + difference / distance * radius
		elif distance <= 0.001 and obstacle.has_point(result):
			var distances: Array[float] = [result.x - obstacle.position.x, obstacle.end.x - result.x, result.y - obstacle.position.y, obstacle.end.y - result.y]
			var nearest_side: int = distances.find(distances.min())
			match nearest_side:
				0: result.x = obstacle.position.x - radius
				1: result.x = obstacle.end.x + radius
				2: result.y = obstacle.position.y - radius
				3: result.y = obstacle.end.y + radius
	return result


func _update_spawning(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	if endless_mode:
		_spawn_overtime_group()
		return
	if standard_mode:
		_spawn_standard_group()
		return
	var progress: float = elapsed / float(balance.shift_duration)
	_spawn_timer = maxf(0.5, 1.05 - float(wave_index) * 0.09) if demo_mode else lerpf(1.15, 0.40, progress)
	if demo_mode and wave_index == 6:
		_spawn_timer = 3.5
	var count: int = (2 if wave_index >= 4 and wave_index < 6 else 1) if demo_mode else (2 if elapsed > 65.0 else 1)
	for index: int in range(count):
		if _enemies.size() >= int(balance.max_enemies):
			break
		var spawn_position: Vector2 = _pick_spawn()
		var kind: int = 1 if (wave_index > 1 if demo_mode else elapsed > 16.0) and _rng.randf() < 0.30 else 0
		if demo_mode and wave_index >= 3 and _rng.randf() < 0.20:
			kind = 2
		debug_spawn_enemy(spawn_position, kind)


func _spawn_standard_group() -> void:
	if wave_index == 6:
		_spawn_timer = 4.2
		debug_spawn_enemy(_pick_spawn(), 0 if _rng.randf() < 0.65 else 1)
		return
	# Every stage has a push, a collection window, and a different unit mix.
	var beat: float = fposmod(wave_elapsed, 30.0)
	var resting: bool = beat >= 24.0
	_spawn_timer = (1.55 if resting else maxf(0.60, 1.25 - float(wave_index) * 0.105))
	var count: int = 1 if wave_index <= 2 or resting else 2
	if wave_index == 3 and wave_elapsed < 30.0:
		count = 1
	if wave_index == 2 and beat > 10.0 and beat < 19.0:
		count = 2
	for index: int in range(count):
		if _enemies.size() >= int(balance.max_enemies):
			break
		var roll: float = _rng.randf()
		var kind: int = 0
		match wave_index:
			1: kind = 1 if wave_elapsed > 60.0 and roll < 0.10 else 0
			2: kind = 1 if roll < 0.50 else 0
			3: kind = 2 if roll < 0.42 else (1 if roll < 0.57 else 0)
			4: kind = 0 if roll < 0.62 else (2 if roll < 0.82 else 1)
			5: kind = 2 if roll < 0.28 else (1 if roll < 0.60 else 0)
		if kind == 2:
			var ranged_count: int = 0
			for existing: Dictionary in _enemies:
				if int(existing.kind) == 2 and not bool(existing.settled):
					ranged_count += 1
			var ranged_cap: int = (3 if map_id == "reactor" else 5) + maxi(0, wave_index - 3)
			if wave_index == 3 and wave_elapsed < 30.0:
				ranged_cap = 2
			if ranged_count >= ranged_cap:
				kind = 0
		var position: Vector2 = _pick_spawn()
		if wave_index == 2:
			position = Vector2(72.0 if int(wave_elapsed / 6.0) % 2 == 0 else 1208.0, _rng.randf_range(150.0, 630.0))
		debug_spawn_enemy(position, kind)


func _pick_spawn() -> Vector2:
	var result: Vector2 = Vector2.ZERO
	for attempt: int in range(8):
		match _rng.randi_range(0, 3):
			0: result = Vector2(_rng.randf_range(72.0, 1208.0), 138.0)
			1: result = Vector2(_rng.randf_range(72.0, 1208.0), 642.0)
			2: result = Vector2(64.0, _rng.randf_range(146.0, 630.0))
			3: result = Vector2(1216.0, _rng.randf_range(146.0, 630.0))
		if result.distance_squared_to(player_position) > 260.0 * 260.0:
			return result
	return result


func debug_spawn_enemy(position: Vector2, kind: int = 0) -> int:
	if _enemies.size() >= int(balance.max_enemies):
		return -1
	_next_enemy_id += 1
	var max_hp: float = 25.0 if kind == 0 else 21.0
	var speed: float = _rng.randf_range(64.0, 83.0) if kind == 0 else _rng.randf_range(90.0, 106.0)
	if kind == 2:
		max_hp = 44.0
		speed = 49.0
	elif kind == 4:
		max_hp = 185.0
		speed = 65.0
	if demo_mode and not endless_mode:
		max_hp *= 1.0 + float(mini(wave_index, 5) - 1) * 0.16
	if standard_mode:
		max_hp *= 1.08
		if map_id == "foundry":
			max_hp *= 1.16
			speed *= 0.94
		elif map_id == "reactor":
			speed *= 1.09
	if endless_mode and kind != 3:
		max_hp *= _overtime.hp_scale()
		speed *= _overtime.speed_scale()
	_enemies.append({
		"id": _next_enemy_id, "pos": position, "kind": kind, "hp": max_hp,
		"max_hp": max_hp, "speed": speed, "radius": 15.0 if kind == 0 else 13.0,
		"knock": Vector2.ZERO, "flash": 0.0, "phase": _rng.randf_range(0.0, TAU),
		"windup": 0.0, "charge": 0.0, "charge_dir": Vector2.RIGHT,
		"charge_cooldown": _rng.randf_range(1.0, 2.8), "spawn": 0.48,
		"settled": false,
		"shot_timer": _rng.randf_range(1.0, 2.0), "shot_warning": 0.0, "shot_dir": Vector2.RIGHT,
		"variant": map_id if standard_mode else "yard", "orbit": 1.0 if _rng.randf() < 0.5 else -1.0,
	})
	if kind == 4:
		_director.encounters.configure_elite(self, _enemies.back())
	return _next_enemy_id


func _update_enemies(delta: float) -> void:
	for enemy: Dictionary in _enemies:
		if bool(enemy["settled"]):
			continue
		var position: Vector2 = enemy["pos"]
		var difference: Vector2 = player_position - position
		var distance: float = difference.length()
		var direction: Vector2 = difference / maxf(distance, 0.001)
		var radius: float = float(enemy["radius"])
		enemy["flash"] = maxf(0.0, float(enemy["flash"]) - delta)
		enemy["spawn"] = maxf(0.0, float(enemy["spawn"]) - delta)
		if float(enemy["spawn"]) > 0.0:
			continue
		if float(enemy.get("boss_stun", 0.0)) > 0.0:
			enemy.boss_stun = maxf(0.0, float(enemy.boss_stun) - delta)
			continue
		var velocity: Vector2 = direction * float(enemy["speed"])
		if int(enemy["kind"]) == 1:
			velocity = _spring_velocity(enemy, direction, distance, delta)
		else:
			velocity += direction.orthogonal() * sin(_visual_time * 6.0 + float(enemy["phase"])) * 12.0
		if int(enemy["kind"]) == 2:
			velocity = _ranged_velocity(enemy, direction, distance, delta)
		if int(enemy["kind"]) == 3:
			velocity = _boss_velocity(enemy, direction, delta)
		elif standard_mode and int(enemy.kind) == 4:
			velocity = _director.elite_velocity(self, enemy, direction, distance, delta)
		elif bool(enemy.get("boss_battery", false)):
			velocity = direction * (75.0 if distance > 85.0 else 0.0)
		elif standard_mode and int(enemy["kind"]) == 0:
			if map_id == "reactor":
				# Orbit drones flank rather than simply follow the same pursuit line.
				velocity = direction * (float(enemy.speed) * 0.58 if distance < 200.0 else float(enemy.speed)) + direction.orthogonal() * 57.0 * float(enemy.orbit)
			elif map_id == "foundry":
				# Tread haulers pulse forward in visibly different stop/start strides.
				velocity = direction * float(enemy.speed) * (1.40 if sin(_visual_time * 2.5 + float(enemy.phase)) > -0.15 else 0.28)
		if _vacuum and int(enemy["kind"]) < 2 and _in_cone(position, _vacuum_range(), float(balance.vacuum_half_angle)):
			# Stop normal pursuit outside the brush: collecting must not pull into contact.
			if float(enemy["charge"]) <= 0.0 and float(enemy["windup"]) <= 0.0:
				velocity = direction * maxf(0.0, minf(175.0, (distance - float(balance.vacuum_enemy_stop)) * 5.0))
		var committed_charge: bool = (int(enemy.kind) == 3 and str(enemy.get("state", "")) == "charge") or (int(enemy.kind) == 4 and float(enemy.charge) > 0.0)
		if not committed_charge:
			velocity = _avoid_obstacles(position, velocity, radius)
		if _is_foamed(position):
			if not committed_charge:
				velocity *= 0.82 if int(enemy["kind"]) == 3 else 0.42
		var knock: Vector2 = enemy["knock"]
		enemy["knock"] = knock.move_toward(Vector2.ZERO, delta * 1050.0)
		var flow: Vector2 = Vector2.ZERO if int(enemy.kind) == 3 else _director.flow_at(self, position)
		position = _move_body(position, (velocity + knock + flow) * delta, radius)
		enemy["pos"] = position
		var broken_core: bool = int(enemy.kind) == 3 and standard_mode and str(enemy.get("state", "")) == "exposed" and bool(enemy.get("countered", false))
		if not broken_core and position.distance_squared_to(player_position) < pow(radius + float(balance.player_radius) - 3.0, 2.0):
			_damage_player(float(balance.contact_damage) * (1.7 if int(enemy["kind"]) == 3 else 1.0), position, "DAMAGE_BOSS" if int(enemy.kind) == 3 else ("DAMAGE_CHARGER" if int(enemy.kind) == 1 else "DAMAGE_CONTACT"))
	# Dead entities are removed only after all damage iteration has completed.
	_prune_enemies()


func _ranged_velocity(enemy: Dictionary, direction: Vector2, distance: float, delta: float) -> Vector2:
	var warning: float = float(enemy["shot_warning"])
	if warning > 0.0:
		enemy["shot_warning"] = maxf(0.0, warning - delta)
		if float(enemy["shot_warning"]) <= 0.0:
			if standard_mode and map_id == "foundry":
				_director.circle_hazard(Vector2(enemy.get("shot_target", player_position)), 43.0, 0.75, 1.8, 11.0, "DAMAGE_SLAG")
			elif standard_mode and map_id == "reactor":
				for offset: float in [-0.20, 0.0, 0.20]:
					_fire_projectile(Vector2(enemy.pos), Vector2(enemy.shot_dir).rotated(offset) * 235.0, 9.0, false)
			else:
				_fire_projectile(Vector2(enemy["pos"]), Vector2(enemy["shot_dir"]) * 210.0, 10.0, false)
			enemy["shot_timer"] = 2.7
		return Vector2.ZERO
	enemy["shot_timer"] = float(enemy["shot_timer"]) - delta
	if float(enemy["shot_timer"]) <= 0.0 and distance < 470.0:
		enemy["shot_warning"] = 0.85
		enemy["shot_dir"] = direction
		enemy["shot_target"] = player_position
		return Vector2.ZERO
	if distance < 170.0:
		return -direction * float(enemy["speed"])
	if distance > 275.0:
		return direction * float(enemy["speed"])
	return direction.orthogonal() * sin(_visual_time + float(enemy["phase"])) * 22.0


func _spawn_boss() -> void:
	if not _boss.is_empty() and not bool(_boss.get("settled", false)):
		return
	debug_spawn_enemy(Vector2(640.0, 198.0), 3)
	_boss = _enemies.back()
	_boss.merge({"hp": float(balance.boss_health), "max_hp": float(balance.boss_health), "radius": 43.0, "speed": 45.0, "spawn": 1.7, "state": "hunt", "state_timer": 2.0, "phase_key": "BOSS_HUNT", "attack": 0, "stage": 1, "volley_timer": 0.0}, true)
	_boss_defeated = false
	if standard_mode:
		_boss_brain.configure(self, _boss)
	if endless_mode:
		var factor: float = 0.68 + float(_overtime.cycle() - 1) * 0.18
		_boss.hp *= factor
		_boss.max_hp = _boss.hp
	_boss_supply_energy = 0.0
	_boss_supply_charge = 0.0
	_boss_batteries_destroyed = 0
	if standard_mode:
		boss_supply(maxf(0.0, float(balance.energy_capacity) - energy), 100.0)
		notify_ability_event("BOSS_ENTRY_SUPPLY")
		_feedback.recover(Vector2(_boss.pos), skill_color)


func boss_supply(energy_amount: float, skill_amount: float, fill_energy: bool = false) -> void:
	# Dedicated combat supply never calls the currency/pickup/healing pathway.
	if not active or paused or phase != "combat" or health <= 0.0 or not standard_mode or _boss.is_empty() or bool(_boss.get("settled", false)) or _boss_defeated:
		return
	if not is_finite(energy_amount) or not is_finite(skill_amount) or energy_amount < 0.0 or skill_amount < 0.0:
		return
	var previous: float = energy
	energy = _max_energy() if fill_energy else minf(_max_energy(), energy + energy_amount)
	_boss_supply_energy += maxf(0.0, energy - previous)
	if _ability != null:
		var gained: float = minf(100.0 - _ability.charge, skill_amount)
		_ability.charge += gained
		_boss_supply_charge += gained
	_reclaim_flash = 1.0
	if fill_energy:
		_feedback.recover(Vector2(_boss.pos), skill_color)
		notify_ability_event("BOSS_BREAK_SUPPLY")
	queue_redraw()


func _boss_velocity(enemy: Dictionary, direction: Vector2, delta: float) -> Vector2:
	if standard_mode:
		return _boss_brain.tick(self, enemy, direction, delta)
	var enraged: bool = float(enemy["hp"]) <= float(enemy["max_hp"]) * 0.5
	enemy["stage"] = 2 if enraged else 1
	enemy["state_timer"] = float(enemy["state_timer"]) - delta
	var state: String = str(enemy["state"])
	var expired: bool = float(enemy["state_timer"]) <= 0.0
	if state == "hunt":
		if expired:
			enemy["attack"] = int(enemy["attack"]) + 1
			enemy["charge_dir"] = direction
			if int(enemy["attack"]) % 2 == 1:
				enemy["state"] = "windup"
				enemy["state_timer"] = 1.0
				enemy["phase_key"] = "BOSS_WINDUP"
			else:
				enemy["state"] = "volley"
				enemy["state_timer"] = 2.2
				enemy["volley_timer"] = 0.85
				enemy["phase_key"] = "BOSS_VOLLEY"
		return direction * (58.0 if enraged else 42.0)
	if state == "windup":
		if expired:
			enemy["state"] = "charge"
			enemy["state_timer"] = 0.85
			enemy["phase_key"] = "BOSS_CHARGE"
		return Vector2.ZERO
	if state == "charge":
		if expired:
			_expose_boss(enemy)
			return Vector2.ZERO
		return Vector2(enemy["charge_dir"]) * (480.0 if enraged else 385.0)
	if state == "volley":
		enemy["volley_timer"] = float(enemy["volley_timer"]) - delta
		if float(enemy["volley_timer"]) <= 0.0:
			enemy["volley_timer"] = 0.44 if enraged else 0.57
			var count: int = 7 if enraged else 5
			for index: int in range(count):
				var angle: float = -0.90 + float(index) / float(count - 1) * 1.80
				_fire_projectile(Vector2(enemy["pos"]), Vector2(enemy["charge_dir"]).rotated(angle) * (220.0 if enraged else 175.0), 12.0, true)
		if expired:
			_expose_boss(enemy)
		return Vector2.ZERO
	if expired:
		enemy["state"] = "hunt"
		enemy["state_timer"] = 1.3 if enraged else 1.9
		enemy["phase_key"] = "BOSS_HUNT"
	return Vector2.ZERO


func _expose_boss(enemy: Dictionary) -> void:
	enemy["state"] = "exposed"
	enemy["state_timer"] = 2.8
	enemy["phase_key"] = "BOSS_EXPOSED"
	_spawn_particles(Vector2(enemy["pos"]), TEAL, 12, 50.0, 150.0)


func _fire_projectile(position: Vector2, velocity: Vector2, damage: float, boss_shot: bool) -> void:
	if _projectiles.size() >= int(balance.max_projectiles):
		return
	if endless_mode:
		velocity *= minf(1.35, 1.0 + float(_overtime.cycle() - 1) * 0.025)
	_projectiles.append({"pos": position + velocity.normalized() * (49.0 if boss_shot else 20.0), "vel": velocity, "life": 5.0, "radius": 6.0 if boss_shot else 7.0, "damage": damage, "boss": boss_shot})


func _update_projectiles(delta: float) -> void:
	for index: int in range(_projectiles.size() - 1, -1, -1):
		var projectile: Dictionary = _projectiles[index]
		projectile["life"] = float(projectile["life"]) - delta
		var position: Vector2 = projectile["pos"]
		var movement: Vector2 = Vector2(projectile["vel"]) * delta
		var steps: int = maxi(1, ceili(movement.length() / 6.0))
		var remove: bool = float(projectile["life"]) <= 0.0
		var radius: float = float(projectile["radius"])
		for step: int in range(steps):
			if remove:
				break
			position += movement / float(steps)
			if not ARENA.has_point(position):
				remove = true
			for obstacle: Rect2 in _obstacles:
				if obstacle.grow(radius).has_point(position):
					remove = true
			if not remove and position.distance_to(player_position) < radius + float(balance.player_radius):
				_damage_player(float(projectile["damage"]), position, "DAMAGE_BOSS_BULLET" if bool(projectile.boss) else "DAMAGE_PROJECTILE")
				remove = true
		if remove:
			_projectiles.remove_at(index)
		else:
			projectile["pos"] = position


func _boss_in_aim() -> bool:
	if not standard_mode or _boss.is_empty() or bool(_boss.get("settled", false)) or float(_boss.get("spawn", 0.0)) > 0.0:
		return false
	var offset: Vector2 = Vector2(_boss.pos) - player_position
	return offset.length_squared() > 1.0 and player_aim.dot(offset.normalized()) >= cos(0.22) and _line_clear(player_position, Vector2(_boss.pos))


func _nearest_target(position: Vector2, distance: float, excluded: Array[int] = []) -> Dictionary:
	# Aim selects the boss only inside this weapon's real range and clear sight.
	# Chain attacks keep their excluded IDs; no homing through walls or extra hits.
	if _boss_in_aim() and int(_boss.id) not in excluded and position.distance_to(Vector2(_boss.pos)) < distance and _line_clear(position, Vector2(_boss.pos)):
		return _boss
	var target: Dictionary = {}
	var shortest: float = distance
	for enemy: Dictionary in _enemies:
		if bool(enemy["settled"]) or float(enemy["spawn"]) > 0.0 or int(enemy["id"]) in excluded:
			continue
		var separation: float = position.distance_to(Vector2(enemy["pos"]))
		if separation < shortest and _line_clear(position, Vector2(enemy.pos)):
			shortest = separation
			target = enemy
	return target


func _is_foamed(position: Vector2) -> bool:
	for patch: Dictionary in _foam:
		if position.distance_squared_to(Vector2(patch["pos"])) <= float(patch["radius"]) * float(patch["radius"]):
			return true
	return false


func _update_tools(delta: float) -> void:
	for index: int in range(_foam.size() - 1, -1, -1):
		var patch: Dictionary = _foam[index]
		patch["life"] = float(patch["life"]) - delta
		if float(patch["life"]) <= 0.0:
			_foam.remove_at(index)
			continue
		patch["tick"] = float(patch["tick"]) - delta
		if float(patch["tick"]) <= 0.0:
			patch["tick"] = float(patch.get("tick_interval", 0.45))
			for enemy: Dictionary in _enemies:
				if float(enemy["spawn"]) <= 0.0 and Vector2(enemy["pos"]).distance_to(Vector2(patch["pos"])) <= float(patch["radius"]) + float(enemy["radius"]) * 0.4:
					if _line_clear(Vector2(patch.pos), Vector2(enemy.pos)):
						_damage_enemy(enemy, float(patch["damage"]), Vector2.ZERO, "foam")
	for index: int in range(_arcs.size() - 1, -1, -1):
		_arcs[index]["life"] = float(_arcs[index]["life"]) - delta
		if float(_arcs[index]["life"]) <= 0.0:
			_arcs.remove_at(index)
	var tool_speed: float = _ability.tool_speed_scale() if _ability != null else 1.0
	_foam_timer -= delta * tool_speed
	_arc_timer -= delta * tool_speed
	_update_saws(delta)
	var foam_level: int = _weapon_level("foam")
	if foam_level > 0 and _foam_timer <= 0.0:
		var values: Dictionary = Loadout.tool_stats("foam", foam_level)
		var target: Dictionary = _nearest_target(player_position, float(values.range))
		if not target.is_empty():
			_foam_timer = _cooldown(float(values.interval))
			if _foam.size() >= int(balance.max_foam):
				_foam.remove_at(0)
			_foam.append({"pos": Vector2(target["pos"]), "radius": float(values.radius), "damage": float(values.damage), "life": float(values.duration), "tick": 0.0, "tick_interval": float(values.tick)})
			sound_requested.emit("foam")
			_waves.append({"pos": Vector2(target["pos"]), "aim": Vector2.RIGHT, "life": 0.23, "max": 0.23, "radius": 50.0, "cone": false, "color": Color("abe6ff")})
	var arc_level: int = _weapon_level("arc")
	if arc_level > 0 and _arc_timer <= 0.0:
		var values: Dictionary = Loadout.tool_stats("arc", arc_level)
		var target: Dictionary = _nearest_target(player_position, float(values.range))
		if not target.is_empty():
			_arc_timer = _cooldown(float(values.interval))
			sound_requested.emit("arc")
			var visited: Array[int] = []
			var origin: Vector2 = player_position
			for hop: int in range(int(values.hops)):
				if target.is_empty():
					break
				var destination: Vector2 = target["pos"]
				visited.append(int(target["id"]))
				var combo: bool = _is_foamed(destination)
				var damage: float = float(values.damage) * (float(values.combo) if combo else 1.0)
				_damage_enemy(target, damage, Vector2.ZERO, "arc")
				if combo:
					_evolution.arc_hit(self, destination)
				_arcs.append({"from": origin, "to": destination, "life": 0.22, "combo": combo})
				origin = destination
				target = _nearest_target(origin, float(values.chain_range), visited)
	_prune_enemies()


func _update_saws(delta: float) -> void:
	for index: int in range(_saws.size() - 1, -1, -1):
		var saw: Dictionary = _saws[index]
		var old_position: Vector2 = saw.pos
		var movement: Vector2 = Vector2(saw.velocity) * delta
		var next: Vector2 = old_position + movement
		if float(saw.get("orbit", 0.0)) > 0.0:
			saw.orbit = maxf(0.0, float(saw.orbit) - delta)
			saw.orbit_angle = float(saw.orbit_angle) + delta * TAU * 1.15
			next = player_position + Vector2.from_angle(float(saw.orbit_angle)) * 84.0
			if float(saw.orbit) <= 0.0:
				var target: Dictionary = _nearest_target(next, 400.0)
				var direction: Vector2 = (Vector2(target.pos) - next).normalized() if not target.is_empty() else player_aim
				saw.velocity = direction * 440.0
		saw.life = float(saw.life) - delta
		saw.spin = float(saw.spin) + delta * 20.0
		if float(saw.life) <= 0.0 or not ARENA.has_point(next) or not _line_clear(old_position, next):
			_saws.remove_at(index)
			continue
		saw.pos = next
		for enemy: Dictionary in _enemies:
			if bool(enemy.settled) or float(enemy.spawn) > 0.0 or int(enemy.id) in saw.visited:
				continue
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(Vector2(enemy.pos), old_position, next)
			if closest.distance_to(Vector2(enemy.pos)) <= float(saw.radius) + float(enemy.radius):
				saw.visited.append(int(enemy.id))
				_damage_enemy(enemy, float(saw.damage), Vector2(saw.velocity).normalized() * 70.0, "saw")
				if saw.visited.size() >= int(saw.pierce):
					break
		if saw.visited.size() >= int(saw.pierce):
			_saws.remove_at(index)
	_saw_timer -= delta * (_ability.tool_speed_scale() if _ability != null else 1.0)
	var level: int = _weapon_level("saw")
	if level <= 0 or _saw_timer > 0.0 or _saws.size() >= 18:
		return
	var values: Dictionary = Loadout.tool_stats("saw", level)
	var target: Dictionary = _nearest_target(player_position, float(values.range))
	if target.is_empty():
		return
	_saw_timer = _cooldown(float(values.interval))
	var direction: Vector2 = (Vector2(target.pos) - player_position).normalized()
	var evolved: bool = _loadout.has_evolution("steel_storm")
	for i: int in range(2 if evolved else 1):
		if _saws.size() >= 18:
			break
		var angle: float = direction.angle() + i * PI
		_saws.append({"pos": player_position + Vector2.from_angle(angle) * (84.0 if evolved else 25.0), "velocity": direction * float(values.speed), "life": float(values.range) / float(values.speed) + (0.9 if evolved else 0.0), "radius": float(values.radius), "damage": float(values.damage) * (0.8 if evolved else 1.0), "pierce": int(values.pierce) + (4 if evolved else 0), "visited": [], "spin": 0.0, "orbit": 0.86 if evolved else 0.0, "orbit_angle": angle})
	sound_requested.emit("blast")


func _spring_velocity(enemy: Dictionary, direction: Vector2, distance: float, delta: float) -> Vector2:
	var charge_left: float = float(enemy["charge"])
	var windup_left: float = float(enemy["windup"])
	if charge_left > 0.0:
		enemy["charge"] = maxf(0.0, charge_left - delta)
		return Vector2(enemy["charge_dir"]) * 370.0
	if windup_left > 0.0:
		enemy["windup"] = maxf(0.0, windup_left - delta)
		if float(enemy["windup"]) <= 0.0:
			enemy["charge"] = 0.40
			enemy["charge_cooldown"] = 3.3
			if standard_mode and map_id == "foundry":
				_director.circle_hazard(Vector2(enemy.pos), 33.0, 0.65, 2.0, 8.0, "DAMAGE_SLAG")
			elif standard_mode and map_id == "reactor":
				enemy["charge"] = 0.52
		return Vector2.ZERO
	var cooldown: float = maxf(0.0, float(enemy["charge_cooldown"]) - delta)
	enemy["charge_cooldown"] = cooldown
	if cooldown <= 0.0 and distance < 340.0 and distance > 105.0:
		enemy["windup"] = 0.70
		enemy["charge_dir"] = direction
		return Vector2.ZERO
	return direction * float(enemy["speed"])


func _avoid_obstacles(position: Vector2, velocity: Vector2, radius: float) -> Vector2:
	var result: Vector2 = velocity
	for obstacle: Rect2 in _obstacles:
		var inflated: Rect2 = obstacle.grow(radius + 8.0)
		if inflated.has_point(position + velocity.normalized() * 34.0):
			var to_center: Vector2 = obstacle.get_center() - position
			var tangent: Vector2 = to_center.normalized().orthogonal()
			if tangent.dot(player_position - position) < 0.0:
				tangent = -tangent
			result = velocity.lerp(tangent * velocity.length(), 0.85)
	return result


func _update_brush(delta: float) -> void:
	delta *= _ability.tool_speed_scale() if _ability != null else 1.0
	_brush_timer -= delta
	if _brush_timer > 0.0:
		return
	var values: Dictionary = Loadout.tool_stats("brush", _weapon_level("brush"))
	_brush_timer = _cooldown(float(values.interval))
	_brush_flash = 0.16
	var did_hit: bool = false
	for enemy: Dictionary in _enemies:
		if bool(enemy["settled"]) or float(enemy["spawn"]) > 0.0:
			continue
		var position: Vector2 = enemy["pos"]
		if player_position.distance_to(position) < _brush_radius() + float(enemy["radius"]) and _line_clear(player_position, position):
			var damage: float = float(values.damage)
			_damage_enemy(enemy, damage, (position - player_position).normalized() * 140.0, "brush")
			did_hit = true
	if did_hit:
		sound_requested.emit("enemy_down")
	_prune_enemies()


func _damage_enemy(enemy: Dictionary, amount: float, knockback: Vector2, source: String = "tool") -> void:
	if bool(enemy["settled"]) or amount <= 0.0:
		return
	var position: Vector2 = enemy["pos"]
	amount *= float(_modifiers["damage_scale"])
	if int(enemy["kind"]) == 3:
		knockback *= 0.06
		if standard_mode:
			amount *= _boss_brain.damage_multiplier(self, enemy, source)
		elif source == "blast" and str(enemy.get("state", "")) == "exposed":
			amount *= 1.8
	elif standard_mode:
		amount *= _director.enemy_damage_multiplier(self, enemy)
	var actual_damage: float = minf(float(enemy.hp), amount)
	if int(enemy.kind) == 3 and _ability != null:
		_ability.gain_boss_charge(actual_damage, source)
	damage_by_source[source] = float(damage_by_source.get(source, 0.0)) + actual_damage
	enemy["hp"] = maxf(0.0, float(enemy["hp"]) - amount)
	enemy["flash"] = 0.13
	enemy["knock"] = Vector2(enemy["knock"]) + knockback
	_spawn_particles(position, ORANGE, 4, 65.0, 160.0)
	if float(enemy["hp"]) <= 0.0:
		enemy["settled"] = true
		kills += 1
		if endless_mode:
			_overtime.on_kill(self, enemy)
		if standard_mode:
			_director.on_enemy_defeated(self, enemy)
		if int(enemy["kind"]) == 3:
			_boss_defeated = true
			boss_kills += 1
			if endless_mode:
				# A simultaneous final hit and death still records the defeated boss.
				_overtime.completed = wave_index
			combat_feedback(position, 2.5, "boss")
			sound_requested.emit("boss_break")
		elif bool(enemy.get("boss_battery", false)):
			_boss_batteries_destroyed += 1
			boss_supply(35.0, 12.0)
			_feedback.recover(position, TEAL)
			_feedback.caption(position, tr("BOSS_BATTERY_RECLAIMED"), TEAL)
			sound_requested.emit("collect")
		else:
			debug_add_scrap(position, 3 if int(enemy["kind"]) == 2 else (2 if int(enemy["kind"]) == 1 else 1))
			_feedback.burst(position, 0.25, "scrap", ORANGE, _effects_enabled())
		_spawn_particles(position, ORANGE, 7, 90.0, 210.0)
		_waves.append({"pos": position, "aim": Vector2.RIGHT, "life": 0.26, "max": 0.26, "radius": 38.0, "cone": false, "color": ORANGE})


func _prune_enemies() -> void:
	for index: int in range(_enemies.size() - 1, -1, -1):
		if bool(_enemies[index]["settled"]):
			_enemies.remove_at(index)


func _damage_player(amount: float, source_position: Vector2, source: String = "DAMAGE_CONTACT") -> void:
	if not active or paused or phase != "combat" or health <= 0.0 or _dash_left > 0.0 or _invulnerability > 0.0 or amount <= 0.0:
		return
	if endless_mode:
		if _overtime.shield > 0.0:
			_overtime.shield = 0.0
			_invulnerability = 0.35
			combat_feedback(player_position, 0.6, "break")
			return
		amount *= _overtime.damage_scale()
	var actual: float = minf(health, amount)
	damage_taken += actual
	damage_events += 1
	if not _boss.is_empty() and not _boss_defeated:
		boss_damage_taken += actual
	health = maxf(0.0, health - amount)
	last_damage_source = source
	_damage_direction = (source_position - player_position).normalized()
	_invulnerability = float(balance.hurt_invulnerability)
	_hurt_flash = 1.0
	combat_feedback(player_position, 0.85, "hurt")
	_spawn_particles(player_position, YELLOW, 10, 80.0, 240.0)
	var away: Vector2 = (player_position - source_position).normalized()
	player_position = _move_body(player_position, away * 14.0, float(balance.player_radius))
	sound_requested.emit("hit")
	_emit_stats()


func debug_damage_player(amount: float) -> void:
	_damage_player(amount, player_position - Vector2.RIGHT)


func debug_add_scrap(position: Vector2, value: int = 1) -> void:
	if value <= 0:
		return
	if _scraps.size() >= int(balance.max_scrap):
		# Preserve the economy while bounding entity count: combine with one drop.
		var nearest_index: int = 0
		var nearest_distance: float = INF
		for index: int in range(_scraps.size()):
			var distance: float = position.distance_squared_to(Vector2(_scraps[index]["pos"]))
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_index = index
		_scraps[nearest_index]["value"] = int(_scraps[nearest_index]["value"]) + value
		return
	_scraps.append({"pos": position, "value": value, "vel": Vector2.ZERO, "phase": _rng.randf_range(0.0, TAU), "pull": false})


func _update_scraps(delta: float) -> void:
	for index: int in range(_scraps.size() - 1, -1, -1):
		var scrap: Dictionary = _scraps[index]
		var position: Vector2 = scrap["pos"]
		var velocity: Vector2 = scrap["vel"]
		var distance: float = position.distance_to(player_position)
		var pulling: bool = _vacuum and _in_cone(position, _vacuum_range(), float(balance.vacuum_half_angle))
		scrap["pull"] = pulling
		if pulling:
			var direction: Vector2 = (player_position - position).normalized()
			var curl: Vector2 = direction.orthogonal() * sin(float(scrap["phase"]) + _visual_time * 8.0) * minf(distance * 0.8, 75.0)
			var target_velocity: Vector2 = direction * (180.0 + (_vacuum_range() - distance) * 2.7) + curl
			velocity = velocity.move_toward(target_velocity, float(balance.vacuum_pull) * delta)
		else:
			velocity = velocity.move_toward(Vector2.ZERO, 450.0 * delta)
		var old_position: Vector2 = position
		position = _move_body(position, (velocity + _director.flow_at(self, position)) * delta, 4.0)
		scrap["pos"] = position
		scrap["vel"] = velocity
		# Crossing the collector in a large step also counts, without double settlement.
		var collected: bool = position.distance_to(player_position) < float(balance.pickup_radius)
		if pulling and not collected:
			var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(player_position, old_position, position)
			collected = nearest.distance_to(player_position) < float(balance.pickup_radius)
		if collected:
			var value: int = int(scrap["value"])
			_scraps.remove_at(index)
			_collect_scrap(value)


func _collect_scrap(value: int) -> void:
	currency += value
	_earned_currency += value
	total_scrap += value
	if _ability != null and active and phase == "combat":
		_ability.gain_scrap_charge(value)
		if endless_mode and health > 0.0 and _overtime.rank("salvager") > 0:
			health = minf(_max_health(), health + value * 0.14 * _overtime.rank("salvager"))
	if standard_mode:
		combo += value
		_combo_timer = 4.0
		var bonus: int = floori(float(combo) / 10.0)
		if bonus > _combo_awarded:
			currency += bonus - _combo_awarded
			_earned_currency += bonus - _combo_awarded
			_combo_awarded = bonus
	energy = minf(_max_energy(), energy + float(value) * float(balance.energy_per_scrap))
	_reclaim_flash = 1.0
	_spawn_particles(player_position + player_aim * 20.0, TEAL, 3, 20.0, 90.0)
	# Salvage repairs reward deliberate collection; each 25-scrap threshold settles once.
	var milestone: int = floori(float(total_scrap) / 25.0)
	if milestone > _last_health_milestone:
		if health > 0.0:
			health = minf(_max_health(), health + float(milestone - _last_health_milestone) * 8.0)
		_last_health_milestone = milestone
	sound_requested.emit("collect")


func _in_cone(position: Vector2, radius: float, half_angle: float) -> bool:
	var offset: Vector2 = position - player_position
	if offset.length_squared() > radius * radius:
		return false
	if offset.length_squared() < 16.0:
		return true
	return player_aim.dot(offset.normalized()) >= cos(half_angle)


func _discharge() -> void:
	if energy <= 0.0 or not active or paused or phase != "combat":
		return
	var spent: float = energy
	energy = 0.0
	shots += 1
	# A larger capacitor stores overcharge; it must not dilute an identical charge.
	var power: float = spent / float(balance.energy_capacity)
	var fraction: float = clampf(power, 0.0, 1.0)
	var radius: float = lerpf(150.0, 345.0, fraction)
	# No fixed damage per release: an equal amount split into tiny shots cannot
	# manufacture extra damage. Stored charge increases damage per unit energy.
	var damage: float = 95.0 * power * (0.65 + 0.35 * minf(power, 1.6))
	var half_angle: float = 0.80
	if standard_mode:
		_director.hit_targets(self, player_position, radius, damage, player_aim, half_angle)
	_evolution.discharge(self, power)
	combat_feedback(player_position + player_aim * 30.0, clampf(power, 0.2, 1.45), "blast")
	for enemy: Dictionary in _enemies:
		if float(enemy["spawn"]) > 0.0:
			continue
		var position: Vector2 = enemy["pos"]
		if _in_cone(position, radius, half_angle) and _line_clear(player_position, position):
			_damage_enemy(enemy, damage, (position - player_position).normalized() * lerpf(300.0, 740.0, fraction), "blast")
			# Impact interrupts a charging spring rat so discharge can rescue the player.
			enemy["windup"] = 0.0
			enemy["charge"] = 0.0
			enemy["charge_cooldown"] = 2.2
	_prune_enemies()
	_waves.append({"pos": player_position, "aim": player_aim, "life": 0.36, "max": 0.36, "radius": radius, "cone": true, "color": TEAL})
	for index: int in range(32):
		var direction: Vector2 = player_aim.rotated(_fx_rng.randf_range(-half_angle, half_angle))
		_append_particle(player_position + player_aim * 27.0, direction * _fx_rng.randf_range(180.0, 650.0), TEAL if index % 3 else YELLOW, _fx_rng.randf_range(0.15, 0.40), _fx_rng.randf_range(2.0, 5.0))
	sound_requested.emit("blast")
	_emit_stats()


func debug_release() -> void:
	_vacuum = false
	_discharge()


func _finish(won: bool) -> void:
	if not active:
		return
	active = false
	phase = "finished"
	cancel_input()
	if _ability != null:
		_ability.clear_effects()
	sound_requested.emit("win" if won else "lose")
	_emit_stats()
	queue_redraw()
	run_finished.emit(won, get_stats())


func _emit_stats() -> void:
	for evolution: Dictionary in _loadout.get_evolutions():
		if bool(evolution.active) and str(evolution.id) not in evolutions_seen:
			evolutions_seen.append(str(evolution.id))
	stats_changed.emit(get_stats())


func _spawn_particles(position: Vector2, color: Color, count: int, minimum_speed: float, maximum_speed: float) -> void:
	for index: int in range(count):
		var velocity: Vector2 = Vector2.from_angle(_fx_rng.randf_range(0.0, TAU)) * _fx_rng.randf_range(minimum_speed, maximum_speed)
		_append_particle(position, velocity, color, _fx_rng.randf_range(0.18, 0.42), _fx_rng.randf_range(2.0, 4.0))


func _append_particle(position: Vector2, velocity: Vector2, color: Color, life: float, size: float) -> void:
	if not _effects_enabled():
		return
	if _particles.size() >= int(balance.max_particles):
		_particles.remove_at(0)
	_particles.append({"pos": position, "vel": velocity, "color": color, "life": life, "max": life, "size": size})


func _update_effects(delta: float) -> void:
	for index: int in range(_particles.size() - 1, -1, -1):
		var particle: Dictionary = _particles[index]
		particle["life"] = float(particle["life"]) - delta
		if float(particle["life"]) <= 0.0:
			_particles.remove_at(index)
		else:
			particle["pos"] = Vector2(particle["pos"]) + Vector2(particle["vel"]) * delta
			particle["vel"] = Vector2(particle["vel"]).move_toward(Vector2.ZERO, delta * 180.0)
	for index: int in range(_waves.size() - 1, -1, -1):
		_waves[index]["life"] = float(_waves[index]["life"]) - delta
		if float(_waves[index]["life"]) <= 0.0:
			_waves.remove_at(index)
	for index: int in range(_dash_ghosts.size() - 1, -1, -1):
		_dash_ghosts[index]["life"] = float(_dash_ghosts[index]["life"]) - delta
		if float(_dash_ghosts[index]["life"]) <= 0.0:
			_dash_ghosts.remove_at(index)


func _draw() -> void:
	_draw_yard()
	if standard_mode:
		_director.draw_floor(self)
		_director.draw_hazards(self)
	_draw_ground_tools()
	if _vacuum:
		_draw_vacuum()
	_draw_scraps()
	for ghost: Dictionary in _dash_ghosts:
		draw_circle(Vector2(ghost["pos"]), 21.0, Color(0.4, 0.95, 0.8, float(ghost["life"]) * 1.2))
	for enemy: Dictionary in _enemies:
		_draw_enemy(enemy)
	_draw_player()
	_draw_waves()
	_draw_ranged_effects()
	_draw_saws()
	for particle: Dictionary in _particles:
		var color: Color = particle["color"]
		color.a = float(particle["life"]) / float(particle["max"])
		var position: Vector2 = particle["pos"]
		var velocity: Vector2 = particle["vel"]
		draw_line(position, position - velocity * 0.025, color, float(particle["size"]), true)
	if _hurt_flash > 0.0 and _effects_enabled():
		draw_rect(ARENA.grow(1.0), Color(1.0, 0.32, 0.3, _hurt_flash * 0.6), false, 4.0)
	if _hurt_flash > 0.0:
		var tip: Vector2 = player_position + _damage_direction * 58.0
		var normal: Vector2 = _damage_direction.orthogonal() * 8.0
		draw_colored_polygon(PackedVector2Array([tip + _damage_direction * 12.0, tip - normal, tip + normal]), Color(1.0, 0.35, 0.32, _hurt_flash))
	if _ability != null:
		_ability.draw(self)
	_evolution.draw(self)
	_arsenal.draw(self)
	if endless_mode:
		_overtime.draw(self)
	_feedback.draw(self)


func _draw_yard() -> void:
	draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), DARK)
	draw_rect(ARENA.grow(7.0), Color("2f454a"))
	draw_rect(ARENA.grow(3.0), INK)
	draw_rect(ARENA, Color(_map_data.floor) if standard_mode else FLOOR)
	ArenaDetail.floor_plates(self, map_id)
	draw_rect(Rect2(478.0, 117.0, 324.0, 546.0), Color(0.24, 0.42, 0.42, 0.04))
	for y: int in range(138, 645, 30):
		draw_line(Vector2(464.0, float(y)), Vector2(464.0, float(y + 13)), Color(0.60, 0.65, 0.45, 0.14), 2.0)
		draw_line(Vector2(816.0, float(y)), Vector2(816.0, float(y + 13)), Color(0.60, 0.65, 0.45, 0.14), 2.0)
	var center: Vector2 = ARENA.get_center()
	draw_arc(center, 119.0, 0.0, TAU, 80, Color(0.50, 0.75, 0.65, 0.055), 2.0, true)
	draw_arc(center, 129.0, 0.0, TAU, 80, Color(0.50, 0.75, 0.65, 0.04), 1.0, true)
	for index: int in range(3):
		var angle: float = float(index) * TAU / 3.0 - 0.25
		var point_a: Vector2 = center + Vector2.from_angle(angle) * 91.0
		var point_b: Vector2 = center + Vector2.from_angle(angle + 0.82) * 91.0
		draw_line(point_a, point_b, Color(0.5, 0.75, 0.65, 0.045), 16.0, true)
	_draw_boundary_details()
	for obstacle: Rect2 in _obstacles:
		_draw_crate(obstacle)
	# Drain grates use fixed geometry and never affect random gameplay state.
	for position: Vector2 in [Vector2(119.0, 197.0), Vector2(1119.0, 584.0), Vector2(1120.0, 183.0), Vector2(120.0, 598.0)]:
		draw_rect(Rect2(position, Vector2(40.0, 14.0)), INK)
		for index: int in range(6):
			var x: float = position.x + 4.0 + float(index) * 6.0
			draw_line(Vector2(x, position.y + 2.0), Vector2(x, position.y + 12.0), Color("345057"), 2.0)


func _draw_boundary_details() -> void:
	for x: int in range(52, 1230, 28):
		var tint: Color = Color("6f6946") if x % 56 == 24 else Color("3c4b42")
		draw_line(Vector2(float(x), 118.0), Vector2(float(x + 10), 124.0), tint, 4.0)
		draw_line(Vector2(float(x), 655.0), Vector2(float(x + 10), 661.0), tint, 4.0)
	for position: Vector2 in [Vector2(53.0, 134.0), Vector2(1226.0, 134.0), Vector2(53.0, 646.0), Vector2(1226.0, 646.0)]:
		draw_circle(position, 7.0, Color(0.3, 0.9, 0.72, 0.09))
		draw_circle(position, 2.3, TEAL)
	for y: int in range(171, 616, 88):
		draw_rect(Rect2(44.0, float(y), 6.0, 34.0), Color("32474c"))
		draw_rect(Rect2(1230.0, float(y), 6.0, 34.0), Color("32474c"))


func _draw_crate(rect: Rect2) -> void:
	draw_rect(Rect2(rect.position + Vector2(4.0, 7.0), rect.size), Color(0.0, 0.0, 0.0, 0.24))
	draw_rect(rect.grow(2.0), INK)
	draw_rect(rect, Color("34484e"))
	draw_rect(Rect2(rect.position + Vector2(4.0, 4.0), rect.size - Vector2(8.0, 10.0)), Color("40545a"))
	draw_line(rect.position + Vector2(6.0, 5.0), rect.position + Vector2(rect.size.x - 6.0, 5.0), Color("65777a"), 2.0)
	draw_line(rect.position + Vector2(12.0, 11.0), rect.end - Vector2(12.0, 13.0), Color("263a42"), 5.0)
	draw_line(rect.position + Vector2(12.0, rect.size.y - 13.0), rect.position + Vector2(rect.size.x - 12.0, 11.0), Color("263a42"), 5.0)
	draw_rect(Rect2(rect.position + Vector2(22.0, rect.size.y - 10.0), Vector2(26.0, 5.0)), Color("c4a752"))
	draw_rect(Rect2(rect.position + Vector2(6, 9), Vector2(4, rect.size.y - 19)), Color("182c35"))
	draw_line(rect.position + Vector2(6, 9), rect.position + Vector2(6, 24), Color("72a6ab"), 2.0)
	for tooth: int in range(3):
		var start: Vector2 = rect.position + Vector2(rect.size.x - 25 + tooth * 5, rect.size.y - 10)
		draw_line(start, start + Vector2(3, 3), Color("a89964"), 2.0)
	for offset: Vector2 in [Vector2(5.0, 5.0), Vector2(rect.size.x - 5.0, 5.0), Vector2(5.0, rect.size.y - 5.0), rect.size - Vector2(5.0, 5.0)]:
		draw_circle(rect.position + offset, 1.7, Color("93a09a"))


func _draw_vacuum() -> void:
	var angle: float = player_aim.angle()
	var radius: float = _vacuum_range()
	var half_angle: float = float(balance.vacuum_half_angle)
	var points: PackedVector2Array = PackedVector2Array([player_position])
	for index: int in range(25):
		points.append(player_position + Vector2.from_angle(angle - half_angle + float(index) / 24.0 * half_angle * 2.0) * radius)
	draw_colored_polygon(points, Color(0.39, 0.95, 0.74, 0.045))
	draw_arc(player_position, radius, angle - half_angle, angle + half_angle, 32, Color(0.4, 0.98, 0.78, 0.33), 1.5, true)
	for edge: float in [-half_angle, half_angle]:
		var direction: Vector2 = Vector2.from_angle(angle + edge)
		draw_line(player_position + direction * 35.0, player_position + direction * radius, Color(0.4, 0.98, 0.78, 0.16), 1.0, true)
	for index: int in range(11):
		var phase: float = fposmod(_visual_time * 1.1 + float(index) * 0.197, 1.0)
		var ray_angle: float = angle + sin(float(index) * 12.31) * half_angle * 0.87
		var distance: float = lerpf(radius - 12.0, 33.0, phase)
		var ray: Vector2 = Vector2.from_angle(ray_angle)
		var alpha: float = sin(phase * PI) * 0.5
		draw_line(player_position + ray * distance, player_position + ray.rotated(0.02) * (distance + 20.0), Color(0.6, 1.0, 0.82, alpha), 1.2, true)


func _draw_scraps() -> void:
	for scrap: Dictionary in _scraps:
		var position: Vector2 = scrap["pos"]
		var velocity: Vector2 = scrap["vel"]
		var size: float = 4.0 + minf(3.0, float(int(scrap["value"]) - 1))
		var pulse: float = 0.8 + sin(_visual_time * 3.0 + float(scrap["phase"])) * 0.2
		draw_circle(position, size + 5.0, Color(0.36, 0.96, 0.72, 0.07 * pulse))
		if bool(scrap["pull"]):
			draw_line(position - velocity * 0.036, position, Color(0.5, 1.0, 0.8, 0.40), 2.0, true)
		var points: PackedVector2Array = PackedVector2Array([position + Vector2(0.0, -size - 1.0), position + Vector2(size, 0.0), position + Vector2(0.0, size + 1.0), position + Vector2(-size, 0.0)])
		draw_colored_polygon(points, TEAL)
		draw_line(position + Vector2(-2.0, 0.0), position + Vector2(0.0, -3.0), Color("c7ffe5"), 1.5, true)


func _draw_enemy(enemy: Dictionary) -> void:
	if float(enemy.get("boss_stun", 0.0)) > 0.0:
		draw_arc(enemy.pos, float(enemy.radius) + 8.0, _visual_time * 3.0, _visual_time * 3.0 + PI * 1.5, 24, TEAL, 2.0, true)
	if bool(enemy.get("boss_battery", false)):
		_draw_battery_drone(enemy)
		return
	if standard_mode and int(enemy.kind) == 4:
		_director.draw_elite(self, enemy)
		return
	if standard_mode and int(enemy.kind) == 3:
		_boss_brain.draw(self, enemy)
		if _boss_in_aim():
			for index: int in range(4):
				var angle: float = PI / 4.0 + index * PI / 2.0
				draw_arc(enemy.pos, float(enemy.radius) + 14.0, angle - 0.17, angle + 0.17, 6, TEAL, 3.0, true)
		return
	if standard_mode and map_id != "yard":
		_draw_map_enemy(enemy)
		return
	if int(enemy["kind"]) >= 2:
		_draw_heavy_enemy(enemy)
		return
	var position: Vector2 = enemy["pos"]
	var phase: float = float(enemy["phase"])
	var flash: bool = float(enemy["flash"]) > 0.0
	var spawning: float = float(enemy["spawn"])
	var kind: int = int(enemy["kind"])
	var aim: Vector2 = (player_position - position).normalized()
	var windup: float = float(enemy["windup"])
	var charging: bool = float(enemy["charge"]) > 0.0
	if spawning > 0.0:
		draw_arc(position, 23.0, -PI / 2.0, -PI / 2.0 + (1.0 - spawning / 0.48) * TAU, 24, Color(1.0, 0.52, 0.34, 0.5), 2.0, true)
	if windup > 0.0:
		var charge_direction: Vector2 = enemy["charge_dir"]
		var alpha: float = 0.20 + 0.45 * (1.0 - windup / 0.70)
		var warning_length: float = 370.0 * 0.40
		for index: int in range(7):
			var start: Vector2 = position + charge_direction * (16.0 + float(index) * warning_length / 7.0)
			draw_line(start, start + charge_direction * 12.0, Color(1.0, 0.35, 0.3, alpha), 2.0, true)
		draw_arc(position, 25.0 + sin(_visual_time * 25.0) * 2.0, 0.0, TAU, 24, Color(1.0, 0.4, 0.3, alpha), 2.0, true)
		aim = charge_direction
	if charging:
		aim = Vector2(enemy["charge_dir"])
		draw_line(position - aim * 32.0, position - aim * 12.0, Color(1.0, 0.4, 0.3, 0.5), 8.0, true)
	if use_sprite_atlas and EnemyAtlas.draw_body(self, "yard", kind, position, aim.angle(), _visual_time + phase / 15.0, flash and _effects_enabled()):
		_draw_small_health(enemy, -25.0)
		return
	draw_circle(position + Vector2(2.0, 5.0), 17.0, Color(0.0, 0.0, 0.0, 0.25))
	draw_set_transform(position, aim.angle())
	if kind == 0:
		var body: Color = Color("fff1d1") if flash else ORANGE
		for index: int in range(3):
			var leg_x: float = -10.0 + float(index) * 9.0
			var wobble: float = sin(_visual_time * 15.0 + phase + float(index)) * 3.0
			draw_line(Vector2(leg_x, -9.0), Vector2(leg_x - 5.0 + wobble, -19.0), Color("a85746"), 3.5, true)
			draw_line(Vector2(leg_x, 9.0), Vector2(leg_x - 5.0 - wobble, 19.0), Color("a85746"), 3.5, true)
		var hex: PackedVector2Array = PackedVector2Array()
		for index: int in range(6):
			hex.append(Vector2.from_angle(float(index) * TAU / 6.0) * 16.0)
		draw_colored_polygon(hex, INK)
		var inner: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in hex:
			inner.append(point * 0.83)
		draw_colored_polygon(inner, body)
		draw_circle(Vector2(-2.0, 0.0), 7.0, Color("bf6147") if not flash else Color("ffffff"))
		draw_line(Vector2(-7.0, -4.0), Vector2(3.0, 4.0), INK, 3.0, true)
		draw_line(Vector2(-6.0, 4.0), Vector2(2.0, -4.0), INK, 2.0, true)
		draw_rect(Rect2(8.0, -5.0, 7.0, 10.0), INK)
		draw_line(Vector2(11.0, -3.0), Vector2(11.0, 3.0), Color("ffd487"), 2.0)
	else:
		var body: Color = Color("fff4dc") if flash else Color("e9a17c")
		var compression: float = 0.65 if windup > 0.0 else 1.0
		var spring: PackedVector2Array = PackedVector2Array()
		for index: int in range(8):
			spring.append(Vector2(-24.0 + float(index) * 3.0 * compression, -5.0 if index % 2 == 0 else 5.0))
		draw_polyline(spring, Color("aaafb0"), 2.2, true)
		draw_circle(Vector2(-3.0, -10.0), 5.0, INK)
		draw_circle(Vector2(-3.0, 10.0), 5.0, INK)
		var shell: PackedVector2Array = PackedVector2Array([Vector2(-10.0, -8.0), Vector2(5.0, -10.0), Vector2(18.0, 0.0), Vector2(5.0, 10.0), Vector2(-10.0, 8.0)])
		draw_colored_polygon(shell, INK)
		var shell_inner: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in shell:
			shell_inner.append(point * 0.82)
		draw_colored_polygon(shell_inner, body)
		draw_line(Vector2(4.0, -5.0), Vector2(4.0, 5.0), RED if windup > 0.0 else Color("7e3e3f"), 3.0)
		draw_circle(Vector2(12.0, 0.0), 2.5, Color("ffe0a3"))
	draw_set_transform(Vector2.ZERO)
	if float(enemy["hp"]) < float(enemy["max_hp"]):
		var ratio: float = float(enemy["hp"]) / float(enemy["max_hp"])
		draw_line(position + Vector2(-12.0, -25.0), position + Vector2(12.0, -25.0), INK, 3.0)
		draw_line(position + Vector2(-12.0, -25.0), position + Vector2(-12.0 + ratio * 24.0, -25.0), ORANGE, 2.0)


func _draw_battery_drone(enemy: Dictionary) -> void:
	var at: Vector2 = enemy.pos
	var tint: Color = Color("f1ffe7") if float(enemy.flash) > 0.0 and _effects_enabled() else TEAL
	draw_circle(at + Vector2(0, 5), 20.0, Color(0.0, 0.0, 0.0, 0.3))
	draw_arc(at, 24.0, 0.0, TAU, 32, Color(tint, 0.45), 1.5, true)
	for side: float in [-1.0, 1.0]:
		var rotor: Vector2 = at + Vector2(side * 21.0, sin(_visual_time * 8.0 + float(enemy.phase)) * 2.0)
		draw_line(at, rotor, Color("899ba0"), 4.0, true)
		draw_arc(rotor, 7.0, _visual_time * 9.0, _visual_time * 9.0 + PI * 1.5, 12, tint, 2.0, true)
	draw_rect(Rect2(at - Vector2(12, 16), Vector2(24, 32)), INK)
	draw_rect(Rect2(at - Vector2(10, 14), Vector2(20, 28)), tint, false, 2.0)
	draw_rect(Rect2(at + Vector2(-4, -19), Vector2(8, 4)), tint)
	for index: int in range(3):
		draw_rect(Rect2(at + Vector2(-6, 6 - index * 8), Vector2(12, 5)), tint)
	_draw_small_health(enemy, -29.0)


func _draw_map_enemy(enemy: Dictionary) -> void:
	var position: Vector2 = enemy.pos
	var kind: int = int(enemy.kind)
	var direction: Vector2 = (player_position - position).normalized()
	var warning: float = float(enemy.windup) if kind == 1 else float(enemy.shot_warning)
	if kind == 1 and (warning > 0.0 or float(enemy.charge) > 0.0):
		direction = Vector2(enemy.charge_dir)
	elif kind == 2 and warning > 0.0:
		direction = Vector2(enemy.shot_dir)
	if float(enemy.spawn) > 0.0:
		draw_arc(position, 25.0, 0, TAU, 32, Color("eab26a"), 2, true)
	if warning > 0.0:
		if kind == 1:
			var length: float = 370.0 * (0.52 if map_id == "reactor" else 0.4)
			var normal: Vector2 = direction.orthogonal() * 13
			draw_line(position + normal, position + direction * length + normal, Color(1.0, 0.65, 0.25, 0.6), 1.5, true)
			draw_line(position - normal, position + direction * length - normal, Color(1.0, 0.65, 0.25, 0.6), 1.5, true)
		elif map_id == "foundry":
			var target: Vector2 = enemy.get("shot_target", player_position)
			draw_arc(target, 43.0, 0, TAU, 32, Color(1.0, 0.65, 0.25, 0.7), 2.0, true)
		else:
			for offset: float in [-0.2, 0, 0.2]:
				draw_line(position + direction.rotated(offset) * 24, position + direction.rotated(offset) * 170, Color(1.0, 0.65, 0.25, 0.45), 1.5, true)
	if use_sprite_atlas and EnemyAtlas.draw_body(self, map_id, kind, position, direction.angle(), _visual_time + float(enemy.phase) / 15.0, float(enemy.flash) > 0.0 and _effects_enabled()):
		_draw_small_health(enemy, -28.0)
		return
	draw_circle(position + Vector2(2, 5), 21.0, Color(0, 0, 0, 0.25))
	draw_set_transform(position, direction.angle())
	var flashed: bool = float(enemy.flash) > 0.0 and _effects_enabled()
	if map_id == "foundry":
		var body: Color = Color("fff0cd") if flashed else Color("b9946c")
		if kind == 0:
			for y: float in [-14.0, 14.0]:
				draw_rect(Rect2(-20, y - 5, 37, 10), INK)
				for index: int in range(5):
					draw_line(Vector2(-16 + index * 7, y - 3), Vector2(-16 + index * 7, y + 3), Color("747b78"), 2)
			draw_rect(Rect2(-16, -11, 30, 22), body)
			draw_rect(Rect2(12, -15, 8, 30), Color("ca804e"))
		elif kind == 1:
			draw_rect(Rect2(-18, -12, 30, 24), body)
			draw_circle(Vector2(0, 0), 11, Color("5a3b30"))
			draw_circle(Vector2(0, 0), 6, Color("ff9760") if warning <= 0 else Color("ffe7a2"))
			draw_colored_polygon(PackedVector2Array([Vector2(10, -14), Vector2(26, 0), Vector2(10, 14)]), Color("dfb670"))
			draw_line(Vector2(-17, -17), Vector2(-17, 17), Color("87938b"), 5)
		else:
			draw_rect(Rect2(-18, -16, 30, 32), body)
			draw_circle(Vector2(11, 0), 14, Color("393331"))
			draw_arc(Vector2(11, 0), 10, -1.3, 1.3, 20, Color("ffae63"), 5, true)
			draw_line(Vector2(-11, -20), Vector2(-11, 20), Color("64635b"), 5)
	else:
		var body: Color = Color("effbff") if flashed else Color("879dca")
		if kind == 0:
			draw_colored_polygon(PackedVector2Array([Vector2(23, 0), Vector2(-15, -17), Vector2(-8, 0), Vector2(-15, 17)]), body)
			draw_arc(Vector2(-1, 0), 23, _visual_time * 2.0, _visual_time * 2.0 + PI, 24, Color("abc8ff"), 2, true)
		elif kind == 1:
			draw_colored_polygon(PackedVector2Array([Vector2(25, 0), Vector2(0, -16), Vector2(-20, 0), Vector2(0, 16)]), body)
			for side: float in [-1.0, 1.0]:
				draw_line(Vector2(-13, side * 8), Vector2(5, side * 18), Color("b4d6ff"), 3)
		else:
			draw_rect(Rect2(-15, -15, 30, 30), body)
			for angle: float in [0.0, PI / 2, PI, 3 * PI / 2]:
				var ray: Vector2 = Vector2.from_angle(angle)
				draw_line(ray * 12, ray * 25, Color("7190bf"), 5)
		draw_circle(Vector2(1, 0), 7, INK)
		draw_circle(Vector2(3, 0), 3.5, Color("ffb95b") if warning > 0 else Color("bedcff"))
	draw_set_transform(Vector2.ZERO)
	if float(enemy.hp) < float(enemy.max_hp):
		draw_line(position + Vector2(-13, -28), position + Vector2(13, -28), INK, 3)
		draw_line(position + Vector2(-13, -28), position + Vector2(-13 + 26 * float(enemy.hp) / float(enemy.max_hp), -28), ORANGE, 2)


func _draw_saws() -> void:
	for saw: Dictionary in _saws:
		var points: PackedVector2Array = PackedVector2Array()
		var radius: float = float(saw.radius)
		if _effects_enabled():
			draw_arc(Vector2(saw.pos), radius * 1.6, float(saw.spin), float(saw.spin) + PI * 1.45, 24, Color(skill_color, 0.18), 5.0, true)
		if float(saw.get("orbit", 0.0)) > 0.0:
			draw_arc(player_position, 84.0, float(saw.orbit_angle) - 0.7, float(saw.orbit_angle), 18, Color(skill_color, 0.48), 2.5, true)
		for index: int in range(24):
			var distance: float = radius if index % 3 else radius * 1.40
			points.append(Vector2(saw.pos) + Vector2.from_angle(float(saw.spin) + float(index) * TAU / 24) * distance)
		draw_colored_polygon(points, Color("c6dbe0"))
		draw_circle(Vector2(saw.pos), radius * 0.55, Color("557981"))
		draw_circle(Vector2(saw.pos), 3.0, skill_color)


func _draw_player() -> void:
	var position: Vector2 = player_position
	draw_circle(position + Vector2(2.0, 7.0), 27.0, Color(0.0, 0.0, 0.0, 0.30))
	var brush_opacity: float = 0.22 + _brush_flash * 2.0
	var angle: float = _visual_time * 5.2
	var tool_radius: float = _brush_radius() - 20.0
	draw_arc(position, tool_radius, 0.0, TAU, 48, Color(0.68, 0.83, 0.73, 0.11), 1.0, true)
	for index: int in range(3):
		var brush_angle: float = angle + float(index) * TAU / 3.0
		draw_arc(position, tool_radius, brush_angle, brush_angle + 0.82, 11, Color(0.69, 0.89, 0.76, brush_opacity), 5.0, true)
		for tooth: int in range(5):
			var direction: Vector2 = Vector2.from_angle(brush_angle + float(tooth) * 0.17)
			draw_line(position + direction * (tool_radius - 2.0), position + direction * (tool_radius + 9.0), Color(0.7, 0.9, 0.78, brush_opacity), 2.0, true)
	if _brush_flash > 0.0:
		draw_arc(position, _brush_radius(), angle, angle + TAU * 0.92, 48, Color(0.82, 0.99, 0.86, _brush_flash * 1.5), 1.5, true)
	if _invulnerability > 0.0:
		draw_arc(position, 31.0, 0.0, TAU, 36, Color(1.0, 0.75, 0.3, 0.26 + sin(_visual_time * 26.0) * 0.14), 2.0, true)
	var charged: float = _ability.charge / 100.0 if _ability != null else 0.0
	var overdrive: bool = _ability != null and _ability.skill == "overdrive" and _ability.duration > 0.0
	if charged > 0.0:
		draw_arc(position, 27.0, -PI / 2.0, -PI / 2.0 + TAU * charged, 36, Color(skill_color, 0.75), 2.0, true)
	if overdrive and _effects_enabled():
		for vent: int in [-1, 1]:
			var exhaust: Vector2 = position - player_aim * 27.0 + player_aim.orthogonal() * vent * 15.0
			draw_line(exhaust, exhaust - player_aim * (22.0 + sin(_visual_time * 50.0) * 7.0), Color(skill_color, 0.24), 11.0, true)
			draw_line(exhaust, exhaust - player_aim * 22.0, skill_color, 3.0, true)
	draw_set_transform(position - player_aim * _feedback.recoil * 0.35, player_aim.angle())
	var skin_tint: Color = Color("d9ebf2") if player_skin == "arctic" else (Color("f5a251") if player_skin == "hazard" else YELLOW)
	if player_skin == "cobalt":
		skin_tint = Color("295f94")
	elif player_skin == "aurora":
		skin_tint = Color("205b59")
	var body_color: Color = Color("fff5cc") if _hurt_flash > 0.70 and _effects_enabled() else skin_tint
	if _dash_left > 0.0:
		body_color = Color("dcffe8")
	# Tracked chassis, front nozzle and two expressive lamps create a readable silhouette.
	draw_rect(Rect2(-18.0, -23.0, 31.0, 10.0), INK)
	draw_rect(Rect2(-18.0, 13.0, 31.0, 10.0), INK)
	for index: int in range(5):
		var tread_x: float = -17.0 + float(index) * 5.7 + fposmod(_visual_time * minf(_player_velocity.length(), 25.0), 5.7)
		draw_line(Vector2(tread_x, -21.0), Vector2(tread_x, -15.0), Color("55706c"), 2.0)
		draw_line(Vector2(tread_x, 15.0), Vector2(tread_x, 21.0), Color("55706c"), 2.0)
	draw_circle(Vector2.ZERO, 23.0, INK)
	draw_circle(Vector2.ZERO, 20.0, body_color)
	draw_arc(Vector2.ZERO, 19.0, -PI * 0.85, -PI * 0.12, 18, Color("fff0b7"), 1.5, true)
	draw_arc(Vector2.ZERO, 18.0, PI * 0.10, PI * 0.64, 16, Color("71532b"), 2.0, true)
	if player_skin in ["cobalt", "aurora"]:
		var rim: Color = Color("74e7ff") if player_skin == "cobalt" else Color("8af0bf")
		draw_arc(Vector2.ZERO, 20.0, 0, TAU, 32, rim, 2.3, true)
		for crest: int in range(3):
			var cp: Vector2 = Vector2(-5 + crest * 5, -16)
			draw_line(cp, cp + Vector2(3, 5), rim, 1.8)
	if player_skin == "hazard":
		for offset: int in [-10, 0, 10]:
			draw_line(Vector2(-13, offset - 4), Vector2(13, offset + 4), Color("72552d"), 3.0)
	elif player_skin == "arctic":
		draw_arc(Vector2.ZERO, 17.0, -0.5, 1.8, 24, Color("67b4e9"), 3.5, true)
	draw_arc(Vector2.ZERO, 17.0, PI * 0.67, PI * 1.36, 15, Color("ffe69a"), 2.0, true)
	draw_rect(Rect2(-19.0, -9.0, 8.0, 18.0), Color("b99344"))
	for y: int in range(-5, 7, 4):
		draw_line(Vector2(-17.0, float(y)), Vector2(-13.0, float(y)), INK, 1.5)
	draw_rect(Rect2(-5.0, -12.0, 19.0, 24.0), INK)
	draw_rect(Rect2(-2.0, -9.0, 13.0, 18.0), Color("254a4b"))
	var eye_color: Color = Color("ffffff") if _reclaim_flash > 0.6 or overdrive else skill_color
	draw_line(Vector2(5.0, -6.0), Vector2(5.0, -2.0), eye_color, 3.0)
	draw_line(Vector2(5.0, 2.0), Vector2(5.0, 6.0), eye_color, 3.0)
	var nozzle: PackedVector2Array = PackedVector2Array([Vector2(16.0, -9.0), Vector2(31.0, -13.0), Vector2(31.0, 13.0), Vector2(16.0, 9.0)])
	draw_colored_polygon(nozzle, INK)
	draw_colored_polygon(PackedVector2Array([Vector2(18,-7), Vector2(27,-10), Vector2(27,10), Vector2(18,7)]), Color("36515e"))
	draw_line(Vector2(28.0, -10.0), Vector2(28.0, 10.0), skill_color if _vacuum else Color("78918a"), 3.0)
	for rib: int in [-5, 0, 5]:
		draw_line(Vector2(20, rib), Vector2(25, rib * 1.35), INK, 1.0)
	draw_circle(Vector2(-6.0, -14.0), 2.2, Color("fff0aa"))
	if _weapon_level("foam") > 0:
		draw_rect(Rect2(-15.0, 20.0, 16.0, 8.0), INK)
		draw_line(Vector2(-12.0, 24.0), Vector2(-3.0, 24.0), Color("abe6ff"), 5.0)
	if _weapon_level("arc") > 0:
		draw_line(Vector2(-8.0, -20.0), Vector2(-12.0, -30.0), Color("8baed8"), 3.0)
		draw_circle(Vector2(-12.0, -30.0), 4.5, Color("c0abff"))
	if _weapon_level("saw") > 0:
		draw_circle(Vector2(-24, 0), 10.0, Color("afc7cb"))
		draw_line(Vector2(-31, -5), Vector2(-17, 5), INK, 3.0)
	draw_set_transform(Vector2.ZERO)
	# A short aim chevron stays readable without obscuring the target area.
	var marker: Vector2 = position + player_aim * 81.0
	var side: Vector2 = player_aim.orthogonal()
	draw_polyline(PackedVector2Array([marker - player_aim * 5.0 - side * 4.0, marker, marker - player_aim * 5.0 + side * 4.0]), Color(0.93, 0.84, 0.5, 0.5), 1.5, true)


func _draw_waves() -> void:
	for wave: Dictionary in _waves:
		var progress: float = 1.0 - float(wave["life"]) / float(wave["max"])
		var radius: float = float(wave["radius"]) * (1.0 - pow(1.0 - progress, 3.0))
		var position: Vector2 = wave["pos"]
		var color: Color = wave["color"]
		color.a = (1.0 - progress) * 0.9
		if bool(wave["cone"]):
			var angle: float = Vector2(wave["aim"]).angle()
			draw_arc(position, maxf(radius, 4.0), angle - 0.80, angle + 0.80, 36, color, 5.0 * (1.0 - progress) + 1.0, true)
			color.a *= 0.35
			draw_arc(position, maxf(radius * 0.83, 3.0), angle - 0.76, angle + 0.76, 32, color, 12.0 * (1.0 - progress) + 1.0, true)
		else:
			draw_arc(position, maxf(radius, 2.0), 0.0, TAU, 24, color, 2.0 * (1.0 - progress) + 0.5, true)


func _draw_ground_tools() -> void:
	for patch: Dictionary in _foam:
		var position: Vector2 = patch["pos"]
		var radius: float = float(patch["radius"])
		var alpha: float = minf(1.0, float(patch["life"]))
		draw_circle(position, radius, Color(0.58, 0.87, 0.98, 0.13 * alpha))
		draw_arc(position, radius, 0.0, TAU, 36, Color(0.63, 0.90, 1.0, 0.5 * alpha), 1.5, true)
		for index: int in range(9):
			var direction: Vector2 = Vector2.from_angle(float(index) * 2.399)
			var offset: Vector2 = direction * radius * (0.23 + float(index % 3) * 0.21)
			var bubble: float = 5.0 + sin(float(index) + _visual_time * 2.0) * 2.0
			draw_arc(position + offset, bubble, 0.0, TAU, 12, Color(0.7, 0.94, 1.0, 0.4 * alpha), 1.0, true)


func _draw_ranged_effects() -> void:
	for projectile: Dictionary in _projectiles:
		var position: Vector2 = projectile["pos"]
		var velocity: Vector2 = projectile["vel"]
		var color: Color = ORANGE if bool(projectile["boss"]) else Color("dfc27c")
		draw_line(position - velocity * 0.055, position, Color(color, 0.25), 5.0, true)
		draw_circle(position, float(projectile["radius"]) + 2.0, INK)
		draw_circle(position, float(projectile["radius"]), color)
		draw_circle(position - Vector2(1.5, 1.5), 2.0, Color("fff2bd"))
	for arc: Dictionary in _arcs:
		var start: Vector2 = arc["from"]
		var end: Vector2 = arc["to"]
		var normal: Vector2 = (end - start).normalized().orthogonal()
		var points: PackedVector2Array = PackedVector2Array([start])
		for index: int in range(1, 6):
			points.append(start.lerp(end, float(index) / 6.0) + normal * (7.0 if index % 2 else -7.0))
		points.append(end)
		var color: Color = TEAL if bool(arc["combo"]) else Color("c0abff")
		color.a = minf(1.0, float(arc["life"]) * 7.0)
		if _effects_enabled():
			draw_polyline(points, Color(color, color.a * 0.2), 8.0, true)
		draw_polyline(points, color, 2.0, true)


func _draw_heavy_enemy(enemy: Dictionary) -> void:
	var position: Vector2 = enemy["pos"]
	var boss: bool = int(enemy["kind"]) == 3
	var direction: Vector2 = (player_position - position).normalized()
	var state: String = str(enemy.get("state", ""))
	var spawning: float = float(enemy["spawn"])
	var warning: bool = (state == "windup" or state == "volley") if boss else float(enemy["shot_warning"]) > 0.0
	if warning or state == "charge":
		direction = Vector2(enemy["charge_dir"] if boss else enemy["shot_dir"])
	if spawning > 0.0:
		draw_arc(position, 58.0 if boss else 26.0, 0.0, TAU, 36, Color(1.0, 0.6, 0.35, 0.6), 2.0, true)
	if warning:
		var length: float = (480.0 if int(enemy.get("stage", 1)) == 2 else 385.0) * 0.85 if boss else 250.0
		for index: int in range(10):
			var from: Vector2 = position + direction * (32.0 + float(index) * length / 10.0)
			draw_line(from, from + direction * 15.0, Color(1.0, 0.43, 0.30, 0.64), 3.0 if boss else 1.5, true)
		if boss and state == "windup":
			var normal: Vector2 = direction.orthogonal() * float(enemy.radius)
			draw_colored_polygon(PackedVector2Array([position - normal, position + normal, position + direction * length + normal, position + direction * length - normal]), Color(1.0, 0.35, 0.24, 0.08))
		if boss and state == "volley":
			draw_arc(position, 115.0, direction.angle() - 0.9, direction.angle() + 0.9, 24, Color(1.0, 0.55, 0.3, 0.6), 2.5, true)
	if not boss and use_sprite_atlas and EnemyAtlas.draw_body(self, "yard", 2, position, direction.angle(), _visual_time, float(enemy.flash) > 0.0 and _effects_enabled()):
		_draw_small_health(enemy, -27.0)
		return
	draw_circle(position + Vector2(3.0, 8.0), 48.0 if boss else 21.0, Color(0.0, 0.0, 0.0, 0.3))
	draw_set_transform(position, direction.angle())
	if boss:
		var exposed: bool = state == "exposed"
		var enraged: bool = int(enemy.get("stage", 1)) == 2
		var body: Color = Color("a6624b") if enraged else Color("6c7e81")
		if float(enemy["flash"]) > 0.0 and _effects_enabled():
			body = Color("fff1ce")
		draw_rect(Rect2(-41.0, -40.0, 70.0, 17.0), INK)
		draw_rect(Rect2(-41.0, 23.0, 70.0, 17.0), INK)
		for index: int in range(7):
			var x: float = -35.0 + float(index) * 9.0
			draw_line(Vector2(x, -36.0), Vector2(x, -27.0), Color("687472"), 3.0)
			draw_line(Vector2(x, 27.0), Vector2(x, 36.0), Color("687472"), 3.0)
		draw_rect(Rect2(-38.0, -27.0, 67.0, 54.0), INK)
		draw_rect(Rect2(-34.0, -23.0, 59.0, 46.0), body)
		draw_rect(Rect2(-24.0, -16.0, 21.0, 32.0), Color("273d43"))
		for y: int in range(-11, 14, 6):
			draw_line(Vector2(-20.0, float(y)), Vector2(-8.0, float(y)), ORANGE if enraged else Color("637e7e"), 2.0)
		draw_rect(Rect2(23.0, -33.0, 23.0, 66.0), INK)
		draw_rect(Rect2(28.0, -28.0, 13.0, 56.0), TEAL if exposed else Color("d19b52"))
		for y: int in range(-23, 28, 10):
			draw_line(Vector2(30.0, float(y)), Vector2(40.0, float(y + 6)), INK, 3.0)
		draw_circle(Vector2(6.0, 0.0), 14.0, INK)
		draw_circle(Vector2(6.0, 0.0), 9.0, TEAL if exposed else RED)
		draw_line(Vector2(3.0, -5.0), Vector2(9.0, 5.0), Color("fff3cf"), 2.0)
		if exposed:
			draw_arc(Vector2.ZERO, 58.0, 0.0, TAU, 36, Color(0.5, 1.0, 0.75, 0.65), 2.0, true)
	else:
		draw_rect(Rect2(-15.0, -19.0, 30.0, 38.0), INK)
		draw_rect(Rect2(-12.0, -16.0, 24.0, 32.0), Color("a8a479"))
		draw_line(Vector2(-9.0, -9.0), Vector2(8.0, -9.0), Color("dbcd9a"), 3.0)
		draw_line(Vector2(-9.0, 9.0), Vector2(8.0, 9.0), Color("635f4b"), 3.0)
		draw_circle(Vector2.ZERO, 7.0, Color("3c5548"))
		draw_circle(Vector2.ZERO, 3.5, Color("d9ed8a"))
		draw_rect(Rect2(10.0, -6.0, 14.0, 12.0), INK)
		draw_line(Vector2(21.0, -4.0), Vector2(21.0, 4.0), ORANGE if warning else Color("cdd694"), 3.0)
	draw_set_transform(Vector2.ZERO)
	if not boss and float(enemy["hp"]) < float(enemy["max_hp"]):
		draw_line(position + Vector2(-13.0, -27.0), position + Vector2(13.0, -27.0), INK, 3.0)
		draw_line(position + Vector2(-13.0, -27.0), position + Vector2(-13.0 + 26.0 * float(enemy["hp"]) / float(enemy["max_hp"]), -27.0), ORANGE, 2.0)


func _draw_small_health(enemy: Dictionary, height: float) -> void:
	if float(enemy.hp) >= float(enemy.max_hp):
		return
	var at: Vector2 = enemy.pos
	draw_line(at + Vector2(-13, height), at + Vector2(13, height), INK, 3.0)
	draw_line(at + Vector2(-13, height), at + Vector2(-13 + 26 * float(enemy.hp) / float(enemy.max_hp), height), ORANGE, 2.0)


func _effects_enabled() -> bool:
	return _settings == null or bool(_settings.get("effects_enabled"))


func _refresh_modifiers() -> void:
	_modifiers = _loadout.get_modifiers()
	if endless_mode:
		_modifiers = _overtime.modify(_modifiers)


func start_endless(selected_map: String, seed_value: int = 0, setup: Dictionary = {}) -> void:
	start_standard(selected_map, seed_value, setup)
	endless_mode = true
	_overtime.reset(map_id, _rng.seed)
	_loadout.configure_slots(4)
	_loadout.price_scale = 1.35
	_refresh_modifiers()
	_overtime.begin(self)
	_emit_stats()


func _spawn_overtime_group() -> void:
	if _overtime.boss_room():
		_spawn_timer = 3.0
		return # Boss brain owns warned, bounded reinforcements.
	var rest: bool = fposmod(wave_elapsed, 24.0) >= 19.0
	_spawn_timer = 1.45 if rest else maxf(0.43, 0.95 - float(_overtime.cycle() - 1) * 0.05)
	var count: int = 1 if rest else mini(3, 1 + _overtime.cycle() / 3 + (1 if _overtime.pattern() == "swarm" else 0))
	for i: int in range(count):
		var roll: float = _rng.randf()
		var kind: int = 1 if roll < (0.43 if _overtime.risk == "hunters" else 0.20) else 0
		if roll > 0.78 and wave_elapsed > 10.0:
			kind = 2
		if _overtime.cycle() >= 2 and roll > 0.95:
			kind = 4
		var special_count: int = 0
		for enemy: Dictionary in _enemies:
			if int(enemy.kind) == kind and not enemy.settled:
				special_count += 1
		if (kind == 2 and special_count >= mini(10, 3 + _overtime.cycle())) or (kind == 4 and special_count >= 3):
			kind = 0
		debug_spawn_enemy(_pick_spawn(), kind)


func _complete_overtime_room() -> void:
	if not active or phase != "combat" or not endless_mode:
		return
	if health <= 0.0:
		_finish(false)
		return
	phase = "shop"
	var ground: int = 0
	for scrap: Dictionary in _scraps:
		ground += int(scrap.value)
	var objective_bonus: int = 25 if not _overtime.boss_room() and _overtime.target() > 0 and _overtime.progress(self) >= _overtime.target() else 0
	var salary: int = (90 if _overtime.boss_room() else 50) + objective_bonus
	currency += ground + salary
	_earned_currency += ground + salary
	var before: float = health
	health = minf(_max_health(), health + (25.0 if _overtime.boss_room() else 10.0))
	var summary: Dictionary = {"wave": wave_index, "earned_scrap": ground, "total_earned": total_scrap - _wave_pickups_start + ground + salary, "collected": total_scrap - _wave_pickups_start, "bonus": salary, "repaired": health - before, "currency": currency}
	_overtime.finish_room()
	_clear_combat_objects()
	_loadout.generate_offers(wave_index)
	_emit_stats()
	wave_completed.emit(summary)


func choose_overtime_route(index: int) -> bool:
	if not active or not endless_mode or phase != "shop":
		return false
	var ok: bool = _overtime.choose(index, self)
	if ok:
		sound_requested.emit("evolve")
		_emit_stats()
	return ok


func _next_overtime_room() -> bool:
	if not active or phase != "shop" or not _overtime.advance():
		return false
	_clear_combat_objects()
	_boss = {}
	_boss_defeated = false
	map_id = _overtime.map_id()
	_map_data = Maps.get_map(map_id)
	_obstacles.assign(_map_data.obstacles)
	wave_index = _overtime.room
	wave_elapsed = 0.0
	_wave_pickups_start = total_scrap
	player_position = _move_body(ARENA.get_center(), Vector2.ZERO, float(balance.player_radius))
	phase = "combat"
	paused = false
	_spawn_timer = 1.0
	_invulnerability = 1.4
	_dash_cooldown = 0.0
	_foam_timer = 0.3
	_arc_timer = 0.4
	_saw_timer = 0.5
	_overtime.begin(self)
	if _overtime.boss_room():
		_spawn_boss()
	_emit_stats()
	return true


func extract_overtime() -> bool:
	if not active or not endless_mode or phase != "shop" or not _overtime.boss_room() or _overtime.completed != wave_index:
		return false
	extracted = true
	_finish(true)
	return true
