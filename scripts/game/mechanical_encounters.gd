extends RefCounted
## Map interactions and elite state share the world's damage/pickup ownership.
var targets: Array[Dictionary] = []
var job_timer: float = 24.0
var elite_timer: float = 38.0
var grid_disabled: float = 0.0
var boss_rearm: float = 0.0
var interactions: int = 0
var elite_kills: int = 0
var boss_breaks: int = 0
var elite_serial: int = 0
var _boss_active: bool = false
var portals: Array[Dictionary] = []
var boss_adds_spawned: int = 0
var projections_destroyed: int = 0
var _support_timer: float = 5.0
var _projection_timer: float = 8.0
var _support_serial: int = 0
var _battery_timer: float = 8.0
var _battery_serial: int = 0


func reset() -> void:
	interactions = 0
	elite_kills = 0
	boss_breaks = 0
	elite_serial = 0
	boss_adds_spawned = 0
	projections_destroyed = 0
	clear_stage()


func clear_stage() -> void:
	targets.clear()
	job_timer = 24.0
	elite_timer = 38.0
	grid_disabled = 0.0
	boss_rearm = 0.0
	_boss_active = false
	portals.clear()
	_support_timer = 5.0
	_projection_timer = 8.0
	_support_serial = 0
	_battery_timer = 8.0
	_battery_serial = 0


func prepare_boss(world: Node2D) -> void:
	targets.clear()
	_boss_active = true
	boss_rearm = 0.0
	_arm_counter(world)
	portals.clear()
	_support_timer = 5.0
	_projection_timer = 8.0
	_battery_timer = 8.0
	_battery_serial = 0


func _arm_counter(world: Node2D) -> void:
	if world.map_id == "yard":
		# One designated block per cycle asks for deliberate positioning instead
		# of letting any ordinary orbit accidentally collide with three targets.
		var positions: Array[Vector2] = [Vector2(375, 390), Vector2(905, 390), Vector2(640, 535)]
		_add_target("bait", positions[boss_breaks % positions.size()], 31.0, 0.0)
	elif world.map_id == "foundry":
		# The live valve alternates after each counter, so players must cross the
		# factory and read the next pressure window instead of camping one spot.
		_add_target("vent", Vector2(420 if boss_breaks % 2 == 0 else 860, 390), 38.0, 1.15)
	else:
		_add_target("node", Vector2(350, 390), 27.0, 20.0)
		_add_target("node", Vector2(930, 390), 27.0, 20.0)


func _add_target(kind: String, pos: Vector2, radius: float, required: float) -> void:
	targets.append({"kind": kind, "pos": pos, "radius": radius, "required": required,
		"progress": 0.0, "supply_progress": 0.0, "dismantle_progress": 0.0,
		"hp": required, "settled": false, "flash": 0.0})


func tick(world: Node2D, delta: float) -> void:
	if not world.active or world.paused or world.phase != "combat" or float(world.health) <= 0.0:
		return
	grid_disabled = maxf(0.0, grid_disabled - delta)
	for enemy: Dictionary in world._enemies:
		enemy.elite_shield = false
	for elite: Dictionary in world._enemies:
		if int(elite.kind) == 4 and str(elite.get("elite_map", "")) == "reactor" and not bool(elite.settled):
			for enemy: Dictionary in world._enemies:
				if int(enemy.kind) < 3 and Vector2(enemy.pos).distance_to(Vector2(elite.pos)) < 155.0:
					enemy.elite_shield = true
	if _boss_active:
		if world._boss.is_empty() or bool(world._boss.get("settled", false)):
			targets.clear()
			portals.clear()
			return
		_tick_support(world, delta)
		var counters_alive: bool = false
		for target: Dictionary in targets:
			counters_alive = counters_alive or (str(target.kind) in ["bait", "vent", "node"] and not bool(target.settled))
		if not counters_alive:
			boss_rearm -= delta
			if boss_rearm <= 0.0 and str(world._boss.state) != "exposed":
				_arm_counter(world)
	else:
		job_timer -= delta
		if job_timer <= 0.0 and targets.is_empty():
			var locations: Array[Vector2] = [Vector2(365, 390), Vector2(915, 390), Vector2(640, 525)]
			var pos: Vector2 = locations[world._rng.randi_range(0, 2)]
			_add_target("cache" if world.map_id == "yard" else ("press" if world.map_id == "foundry" else "relay"), pos, 32.0, 20.0 if world.map_id == "reactor" else 1.4)
			job_timer = 48.0
		elite_timer -= delta
		if int(world.wave_index) >= 2 and elite_timer <= 0.0:
			var existing: bool = false
			for enemy: Dictionary in world._enemies:
				existing = existing or (int(enemy.kind) == 4 and not bool(enemy.settled))
			if not existing and world._enemies.size() < int(world.balance.max_enemies):
				spawn_elite(world)
			elite_timer = 68.0
	for target: Dictionary in targets:
		target.flash = maxf(0.0, float(target.flash) - delta)
		if bool(target.settled):
			continue
		var kind: String = str(target.kind)
		if kind == "projection":
			_tick_projection(world, target, delta)
			continue
		if kind == "bait" and not world._boss.is_empty() and str(world._boss.state) == "charge":
			if Vector2(world._boss.pos).distance_to(Vector2(target.pos)) <= float(world._boss.radius) + float(target.radius):
				_break_boss(world)
				return
		if kind == "node":
			var near: bool = world.player_position.distance_to(Vector2(target.pos)) < 78.0
			if near and world._vacuum and world._line_clear(world.player_position, target.pos):
				target.dismantle_progress = minf(1.0, float(target.dismantle_progress) + delta)
			else:
				target.dismantle_progress = maxf(0.0, float(target.dismantle_progress) - delta * 0.55)
			if float(target.dismantle_progress) >= 1.0:
				_settle_node(world, target)
				if _nodes_complete():
					_break_boss(world)
					return
			continue
		if kind in ["vent", "cache", "press"]:
			var allowed: bool = kind != "vent" or (not world._boss.is_empty() and str(world._boss.state) in ["vent_window", "recover"])
			var near: bool = world.player_position.distance_to(Vector2(target.pos)) < 78.0
			if allowed and near and world._vacuum:
				target.progress = minf(float(target.required), float(target.progress) + delta)
			else:
				target.progress = maxf(0.0, float(target.progress) - delta * 0.55)
			if kind == "vent":
				# Only new high-water progress earns supply. Losing/repeating progress
				# cannot farm energy or blueprint charge from the same valve.
				var gained: float = maxf(0.0, float(target.progress) - float(target.supply_progress))
				if gained > 0.0:
					target.supply_progress = target.progress
					var fraction: float = gained / float(target.required)
					world.boss_supply(40.0 * fraction, 12.0 * fraction)
			if float(target.progress) >= float(target.required):
				if kind == "vent":
					_break_boss(world)
					return
				_complete_job(world, target)
	for index: int in range(targets.size() - 1, -1, -1):
		if bool(targets[index].settled):
			targets.remove_at(index)


func _break_boss(world: Node2D) -> void:
	if not world.active or world.paused or world.phase != "combat" or float(world.health) <= 0.0 or world._boss.is_empty() or bool(world._boss.get("settled", false)) or str(world._boss.state) == "exposed":
		return
	boss_breaks += 1
	interactions += 1
	targets.clear()
	boss_rearm = 6.0
	world._boss.repeat_charge = false
	world._boss.countered = true
	world._boss.state = "exposed"
	world._boss.phase_key = "BOSS_CORE_BROKEN"
	world._boss.state_timer = 6.0
	world._boss.knock = Vector2.ZERO
	world._boss.pressure = maxf(0.0, float(world._boss.get("pressure", 0.0)) - 15.0)
	# The payoff includes clearing hostile projectiles; a successful counter
	# must not be immediately obscured by the previous attack's lingering shots.
	world._projectiles.clear()
	world._director.hazards.clear()
	# Dedicated supply is not currency, healing, or another ordinary pickup.
	world.boss_supply(0.0, 30.0, true)
	for enemy: Dictionary in world._enemies:
		if bool(enemy.get("boss_add", false)) and not bool(enemy.get("settled", false)):
			enemy.boss_stun = maxf(2.0, float(enemy.get("boss_stun", 0.0)))
			enemy.windup = 0.0
			enemy.charge = 0.0
			enemy.shot_warning = 0.0
	world._spawn_particles(Vector2(world._boss.pos), Color("84ffdb"), 32, 90.0, 360.0)
	world.sound_requested.emit("boss_break")
	if world.has_method("combat_feedback"):
		world.combat_feedback(Vector2(world._boss.pos), 1.0, "boss_break")


func hit_targets(world: Node2D, origin: Vector2, reach: float, damage: float, aim: Vector2 = Vector2.ZERO, half_angle: float = PI) -> void:
	if damage <= 0.0 or not world.active or world.paused or world.phase != "combat" or float(world.health) <= 0.0:
		return
	var counter_changed: bool = false
	for target: Dictionary in targets:
		if bool(target.settled) or str(target.kind) not in ["node", "relay", "projection"]:
			continue
		var offset: Vector2 = Vector2(target.pos) - origin
		if offset.length() > reach + float(target.radius) or not world._line_clear(origin, target.pos):
			continue
		if aim.length_squared() > 0.01 and offset.length_squared() > 1.0 and aim.normalized().dot(offset.normalized()) < cos(half_angle):
			continue
		target.hp = maxf(0.0, float(target.hp) - damage)
		target.flash = 0.18
		if float(target.hp) <= 0.0:
			if str(target.kind) == "node":
				counter_changed = _settle_node(world, target) or counter_changed
				continue
			target.settled = true
			world._spawn_particles(Vector2(target.pos), Color("92efff"), 18, 70, 250)
			if str(target.kind) == "relay":
				_complete_job(world, target)
			elif str(target.kind) == "projection":
				projections_destroyed += 1
				world.debug_add_scrap(target.pos, 3)
				world.sound_requested.emit("arc")
	if counter_changed and _boss_active and _nodes_complete():
		_break_boss(world)


func _settle_node(world: Node2D, target: Dictionary) -> bool:
	if bool(target.settled):
		return false
	# Shooting and vacuum dismantling share this sole settlement transition.
	target.settled = true
	target.hp = 0.0
	world.boss_supply(45.0, 12.0)
	world._spawn_particles(Vector2(target.pos), Color("92efff"), 18, 70, 250)
	world.sound_requested.emit("arc")
	return true


func _nodes_complete() -> bool:
	for target: Dictionary in targets:
		if str(target.kind) == "node" and not bool(target.settled):
			return false
	return true


func _tick_support(world: Node2D, delta: float) -> void:
	var exposed: bool = str(world._boss.state) == "exposed"
	var limit: int = 8 if int(world._boss.stage) == 2 else 6
	var living: int = 0
	var batteries: int = 0
	for enemy: Dictionary in world._enemies:
		if bool(enemy.get("boss_add", false)) and not bool(enemy.settled):
			living += 1
			batteries += 1 if bool(enemy.get("boss_battery", false)) else 0
	for target: Dictionary in targets:
		if str(target.kind) == "projection" and not bool(target.settled):
			living += 1
	for i: int in range(portals.size() - 1, -1, -1):
		if exposed:
			continue
		portals[i].warning -= delta
		if float(portals[i].warning) > 0.0:
			continue
		var portal: Dictionary = portals[i]
		if living < limit and world._enemies.size() < int(world.balance.max_enemies):
			var id: int = world.debug_spawn_enemy(portal.pos, int(portal.kind))
			if id >= 0:
				var add: Dictionary = world._enemies.back()
				add.boss_add = true
				add.boss_battery = bool(portal.get("boss_battery", false))
				add.spawn = 0.50
				boss_adds_spawned += 1
				living += 1
				batteries += 1 if bool(add.boss_battery) else 0
		portals.remove_at(i)
	if exposed:
		return
	var queued_batteries: int = 0
	for portal: Dictionary in portals:
		queued_batteries += 1 if bool(portal.get("boss_battery", false)) else 0
	# Two seats remain available for dedicated supply; hostile support still
	# owns four/six seats. Both kinds and projections share the same 6/8 cap.
	_battery_timer -= delta
	if _battery_timer <= 0.0:
		var count: int = mini(2 - batteries - queued_batteries, limit - living - portals.size())
		for i: int in range(maxi(0, count)):
			_queue_support(world, 0, true, _battery_serial + i)
		if count > 0:
			_battery_serial += count
			queued_batteries += count
			_battery_timer = 8.0
			world.notify_ability_event("BOSS_BATTERIES")
			world.sound_requested.emit("collect")
	_support_timer -= delta
	if _support_timer <= 0.0:
		_support_timer = 10.5 if int(world._boss.stage) == 2 else 12.5
		var hostile: int = living - batteries + portals.size() - queued_batteries
		var count: int = mini(4 if int(world._boss.stage) == 2 else 3, limit - 2 - hostile)
		for i: int in range(maxi(0, count)):
			_queue_support(world, 2 if (_support_serial + i) % 3 == 2 else (_support_serial + i) % 2, false, _support_serial + i)
		_support_serial += maxi(0, count)
		if count > 0:
			world.notify_ability_event("BOSS_REINFORCEMENTS")
			world.sound_requested.emit("warning")
	if world.map_id == "reactor":
		_projection_timer -= delta
		if _projection_timer <= 0.0:
			_projection_timer = 12.0
			var copies: int = 0
			for target: Dictionary in targets:
				if str(target.kind) == "projection" and not bool(target.settled):
					copies += 1
			var hostile: int = living - batteries + portals.size() - queued_batteries
			if copies < 2 and hostile < limit - 2 and living + portals.size() < limit:
				var positions: Array[Vector2] = [Vector2(260, 220), Vector2(1020, 560), Vector2(1020, 220), Vector2(260, 560)]
				for at: Vector2 in positions:
					var occupied: bool = at.distance_to(world.player_position) < 160.0
					for target: Dictionary in targets:
						occupied = occupied or (str(target.kind) == "projection" and not bool(target.settled) and Vector2(target.pos).distance_to(at) < 80.0)
					if occupied:
						continue
					_add_target("projection", at, 30.0, 28.0)
					targets.back().merge({"spawn": 1.1, "shot_timer": 1.2, "shot_warning": 0.0, "aim": Vector2.RIGHT, "life": 19.0})
					world.notify_ability_event("BOSS_PROJECTION_HINT")
					break


func _queue_support(world: Node2D, kind: int, battery: bool, serial: int) -> void:
	var positions: Array[Vector2] = [Vector2(100, 185), Vector2(1180, 585), Vector2(100, 585), Vector2(1180, 185), Vector2(630, 155), Vector2(630, 615)]
	var at: Vector2 = positions[serial % positions.size()]
	if at.distance_to(world.player_position) < 160.0:
		at = positions[(serial + 3) % positions.size()]
	portals.append({"pos": world._move_body(at, Vector2.ZERO, 18.0), "warning": 1.0, "kind": kind, "boss_battery": battery})


func _tick_projection(world: Node2D, projection: Dictionary, delta: float) -> void:
	projection.life -= delta
	if float(projection.life) <= 0.0:
		projection.settled = true
		return
	if float(projection.spawn) > 0.0:
		projection.spawn = maxf(0.0, float(projection.spawn) - delta)
		return
	# The boss's green ring gap stays useful for the entire committed burst.
	if str(world._boss.state) in ["ring_warning", "ring", "exposed"]:
		projection.shot_warning = 0.0
		projection.shot_timer = maxf(0.9, float(projection.shot_timer))
		return
	if float(projection.shot_warning) > 0.0:
		projection.shot_warning = maxf(0.0, float(projection.shot_warning) - delta)
		if float(projection.shot_warning) <= 0.0:
			for offset: float in [-0.22, 0.0, 0.22]:
				world._fire_projectile(projection.pos, Vector2(projection.aim).rotated(offset) * 205.0, 9.0, false)
		return
	projection.shot_timer -= delta
	if float(projection.shot_timer) <= 0.0:
		projection.shot_timer = 3.4
		projection.shot_warning = 0.9
		projection.aim = (world.player_position - Vector2(projection.pos)).normalized()


func _complete_job(world: Node2D, target: Dictionary) -> void:
	# A settled relay reaches here from its one-time hit transition; callers
	# never call this for a settled target again.
	target.settled = true
	interactions += 1
	world._collect_scrap(18)
	var radius: float = 220.0 if world.map_id == "yard" else 310.0
	for enemy: Dictionary in world._enemies:
		if not bool(enemy.settled) and int(enemy.kind) != 3 and Vector2(enemy.pos).distance_to(Vector2(target.pos)) < radius:
			world._damage_enemy(enemy, 130.0, (Vector2(enemy.pos) - Vector2(target.pos)).normalized() * 400.0, "mechanism")
	grid_disabled = 10.0
	world._director.hazards.clear()
	world._waves.append({"pos": Vector2(target.pos), "aim": Vector2.RIGHT, "life": 0.65, "max": 0.65, "radius": radius, "cone": false, "color": Color("8cffe5")})
	world.sound_requested.emit("unlock")


func spawn_elite(world: Node2D) -> void:
	var id: int = world.debug_spawn_enemy(world._pick_spawn(), 4)
	if id < 0:
		return
	elite_serial += 1
	configure_elite(world, world._enemies.back())


func configure_elite(world: Node2D, enemy: Dictionary) -> void:
	# Both scheduled encounters and expedition spawning use the same schema.
	# A second caller must not heal an existing elite or restart its warning.
	if enemy.has("elite_map"):
		return
	var hp: float = 155.0 + float(world.wave_index) * 24.0
	if world.endless_mode:
		hp *= world._overtime.hp_scale()
	enemy.merge({"hp": hp, "max_hp": hp, "radius": 24.0, "elite_map": world.map_id, "elite_timer": 2.0,
		"elite_warning": 0.0, "elite_aim": Vector2.RIGHT, "cargo": 0, "elite_cycle": 0}, true)


func elite_velocity(world: Node2D, enemy: Dictionary, direction: Vector2, distance: float, delta: float) -> Vector2:
	enemy.elite_timer = float(enemy.elite_timer) - delta
	if float(enemy.elite_warning) > 0.0:
		enemy.elite_warning = maxf(0.0, float(enemy.elite_warning) - delta)
		if float(enemy.elite_warning) <= 0.0:
			if str(enemy.elite_map) == "yard":
				enemy.charge = Vector2(enemy.pos).distance_to(Vector2(enemy.charge_end)) / 335.0
				enemy.charge_dir = enemy.elite_aim
			elif str(enemy.elite_map) == "foundry":
				for offset: float in [-0.35, 0.0, 0.35]:
					world._director.circle_hazard(Vector2(enemy.pos) + Vector2(enemy.elite_aim).rotated(offset) * 160.0, 42.0, 1.0, 2.2, 12.0, "DAMAGE_ELITE_SLAG")
			else:
				for offset: float in [-0.4, -0.2, 0.0, 0.2, 0.4]:
					world._fire_projectile(Vector2(enemy.pos), Vector2(enemy.elite_aim).rotated(offset) * 230.0, 11.0, false)
		return Vector2.ZERO
	if str(enemy.elite_map) == "yard":
		if float(enemy.charge) > 0.0:
			enemy.charge = maxf(0.0, float(enemy.charge) - delta)
			if Vector2(enemy.pos).distance_to(Vector2(enemy.charge_end)) <= 9.0:
				enemy.charge = 0.0
				return Vector2.ZERO
			return Vector2(enemy.charge_dir) * 335.0
		for index: int in range(world._scraps.size() - 1, -1, -1):
			var scrap: Dictionary = world._scraps[index]
			if Vector2(scrap.pos).distance_to(Vector2(enemy.pos)) < 38.0 and int(enemy.cargo) < 24:
				enemy.cargo = int(enemy.cargo) + int(scrap.value)
				world._scraps.remove_at(index)
	if float(enemy.elite_timer) <= 0.0 and distance < 480.0:
		enemy.elite_timer = 4.5
		enemy.elite_warning = 1.0
		enemy.elite_aim = direction
		if str(enemy.elite_map) == "yard":
			var end: Vector2 = enemy.pos
			for step: int in range(37):
				var next: Vector2 = world._move_body(end, direction * 5.0, float(enemy.radius))
				if next.distance_to(end + direction * 5.0) > 0.8:
					break
				end = next
			enemy.charge_end = end
			if end.distance_to(Vector2(enemy.pos)) < 30.0:
				enemy.elite_warning = 0.0
				enemy.elite_timer = 1.0
		return Vector2.ZERO
	return direction * (72.0 if str(enemy.elite_map) == "yard" else (45.0 if distance > 205.0 else -22.0))


func on_enemy_defeated(world: Node2D, enemy: Dictionary) -> void:
	if int(enemy.kind) != 4 or bool(enemy.get("elite_rewarded", false)):
		return
	enemy.elite_rewarded = true
	elite_kills += 1
	if str(enemy.get("elite_map", "")) == "reactor":
		for other: Dictionary in world._enemies:
			other.elite_shield = false
	world.debug_add_scrap(Vector2(enemy.pos), 8 + int(enemy.get("cargo", 0)))
	world.sound_requested.emit("unlock")


func get_stats(world: Node2D) -> Dictionary:
	var key: String = "INTERACT_YARD" if world.map_id == "yard" else ("INTERACT_FOUNDRY" if world.map_id == "foundry" else "INTERACT_REACTOR")
	if _boss_active:
		key = "COUNTER_YARD" if world.map_id == "yard" else ("COUNTER_FOUNDRY" if world.map_id == "foundry" else "COUNTER_REACTOR")
	return {"interaction_key": key if not targets.is_empty() else "", "interactions": interactions,
		"elite_kills": elite_kills, "boss_breaks": boss_breaks, "grid_disabled": grid_disabled > 0.0,
		"boss_adds_spawned": boss_adds_spawned, "projections_destroyed": projections_destroyed}


func draw(world: Node2D) -> void:
	for portal: Dictionary in portals:
		if bool(portal.get("boss_battery", false)):
			var pos: Vector2 = portal.pos
			world.draw_arc(pos, 29.0, 0, TAU, 24, Color("76f5c7"), 2.0, true)
			world.draw_rect(Rect2(pos - Vector2(13, 18), Vector2(26, 36)), Color("76f5c7"), false, 2.0)
			world.draw_line(pos + Vector2(-6, -21), pos + Vector2(6, -21), Color("76f5c7"), 3.0)
			world.draw_line(pos - Vector2(7, 0), pos + Vector2(7, 0), Color("76f5c7"), 3.0)
			world.draw_line(pos - Vector2(0, 7), pos + Vector2(0, 7), Color("76f5c7"), 3.0)
			continue
		world.draw_arc(portal.pos, 29.0, 0, TAU, 24, Color("ffb679"), 2.0, true)
		world.draw_line(Vector2(portal.pos) - Vector2(0, 18), Vector2(portal.pos) + Vector2(0, 5), Color("ffda9b"), 3.0)
		world.draw_circle(Vector2(portal.pos) + Vector2(0, 13), 2.0, Color("ffda9b"))
	for target: Dictionary in targets:
		if bool(target.settled):
			continue
		var pos: Vector2 = target.pos
		var radius: float = float(target.radius)
		if str(target.kind) == "projection":
			var alpha: float = 0.35 if float(target.spawn) > 0.0 else 0.9
			var tint := Color("6adce7", alpha)
			world.draw_dashed_line(pos + Vector2(-28, -28), pos + Vector2(28, 28), Color(tint, 0.35), 1.5, 7.0, true)
			world.draw_arc(pos, 30.0, world._visual_time, world._visual_time + PI * 1.7, 32, tint, 3.0, true)
			world.draw_arc(pos, 16.0, -world._visual_time, -world._visual_time + PI * 1.7, 24, tint, 2.0, true)
			world.draw_line(pos + Vector2(-23, 39), pos + Vector2(-23 + 46.0 * float(target.hp) / float(target.required), 39), tint, 3.0)
			if float(target.shot_warning) > 0.0:
				for side: float in [-0.22, 0.0, 0.22]:
					world.draw_line(pos, pos + Vector2(target.aim).rotated(side) * 190.0, Color("ffcb77"), 1.5, true)
			continue
		var color: Color = Color("85efcd") if str(target.kind) in ["node", "relay"] else Color("ffdc85")
		if str(target.kind) == "vent" and not world._boss.is_empty() and str(world._boss.state) not in ["vent_window", "recover"]:
			color = Color("857965")
		world.draw_circle(pos + Vector2(3, 5), radius + 6, Color(0, 0, 0, 0.35))
		world.draw_arc(pos, radius + 11.0, 0.0, TAU, 36, Color(color, 0.30), 2.0, true)
		if str(target.kind) in ["node", "relay"]:
			var shape: PackedVector2Array = PackedVector2Array([pos + Vector2(0, -radius), pos + Vector2(radius, 0), pos + Vector2(0, radius), pos - Vector2(radius, 0)])
			world.draw_colored_polygon(shape, Color("263f59"))
			world.draw_polyline(shape + PackedVector2Array([shape[0]]), color, 3.0, true)
			world.draw_circle(pos, 9.0, Color.WHITE if float(target.flash) > 0 else color)
			world.draw_line(pos + Vector2(-23, 37), pos + Vector2(-23 + 46 * float(target.hp) / maxf(1, float(target.required)), 37), color, 4.0)
			if str(target.kind) == "node" and float(target.dismantle_progress) > 0.0:
				world.draw_arc(pos, radius + 8.0, -PI / 2, -PI / 2 + TAU * float(target.dismantle_progress), 36, Color("ffc04d"), 4.0, true)
			if _boss_active and not world._boss.is_empty():
				world.draw_line(pos, Vector2(world._boss.pos), Color(color, 0.22), 2.0, true)
		else:
			world.draw_rect(Rect2(pos - Vector2(radius, radius * 0.72), Vector2(radius * 2, radius * 1.44)), Color("544738"))
			world.draw_rect(Rect2(pos - Vector2(radius, radius * 0.72), Vector2(radius * 2, radius * 1.44)), color, false, 3.0)
			if str(target.kind) == "vent":
				world.draw_arc(pos, 15, 0, TAU, 24, color, 3.0, true)
				for spoke: int in range(3):
					world.draw_line(pos, pos + Vector2.from_angle(spoke * TAU / 3.0 - PI / 2) * 14, color, 3.0, true)
				world.draw_circle(pos, 4, Color("28313a"))
			elif str(target.kind) == "bait":
				for strip: int in range(3):
					world.draw_line(pos + Vector2(-23, -13 + strip * 13), pos + Vector2(23, -19 + strip * 13), Color("c8b48b"), 5.0, true)
				world.draw_polyline(PackedVector2Array([pos + Vector2(4, -18), pos + Vector2(-6, 0), pos + Vector2(7, -3), pos + Vector2(-3, 18)]), Color("ffe392"), 3.0, true)
			elif str(target.kind) == "press":
				world.draw_line(pos + Vector2(-18, -9), pos + Vector2(18, -9), color, 7.0)
				world.draw_line(pos + Vector2(0, -18), pos + Vector2(0, -9), color, 5.0)
				world.draw_colored_polygon(PackedVector2Array([pos + Vector2(-10, 2), pos + Vector2(10, 2), pos + Vector2(0, 14)]), color)
			else:
				for strip: int in range(3):
					world.draw_rect(Rect2(pos + Vector2(-18 + strip * 12, -10 + strip % 2 * 4), Vector2(9, 22)), color)
			if str(target.kind) != "bait":
				world.draw_arc(pos, radius + 8, -PI / 2, -PI / 2 + TAU * float(target.progress) / maxf(0.1, float(target.required)), 36, color, 4.0, true)


func draw_elite(world: Node2D, enemy: Dictionary) -> void:
	var pos: Vector2 = enemy.pos
	var color: Color = Color("ffc168") if str(enemy.elite_map) == "yard" else (Color("ff9273") if str(enemy.elite_map) == "foundry" else Color("a4baff"))
	if float(enemy.elite_warning) > 0.0:
		if str(enemy.elite_map) == "yard":
			var end: Vector2 = enemy.get("charge_end", pos)
			var normal: Vector2 = Vector2(enemy.elite_aim).orthogonal() * float(enemy.radius)
			world.draw_colored_polygon(PackedVector2Array([pos - normal, pos + normal, end + normal, end - normal]), Color(1.0, 0.6, 0.2, 0.18))
			world.draw_line(pos - normal, end - normal, Color("ffca79"), 2.0, true)
			world.draw_line(pos + normal, end + normal, Color("ffca79"), 2.0, true)
		else:
			var angle: float = Vector2(enemy.elite_aim).angle()
			world.draw_arc(pos, 130.0, angle - 0.45, angle + 0.45, 24, Color("ffca79"), 3.0, true)
			for side: float in [-0.45, 0.45]:
				world.draw_line(pos + Vector2.from_angle(angle + side) * 30, pos + Vector2.from_angle(angle + side) * 230, Color("ffca79"), 2.0, true)
	if str(enemy.elite_map) == "reactor":
		world.draw_arc(pos, 155.0, 0, TAU, 56, Color(color, 0.22), 1.5, true)
	world.draw_circle(pos + Vector2(3, 6), 30.0, Color(0, 0, 0, 0.4))
	if str(enemy.elite_map) == "yard":
		world.draw_rect(Rect2(pos - Vector2(25, 22), Vector2(50, 44)), Color("233044"))
		world.draw_rect(Rect2(pos - Vector2(25, 22), Vector2(50, 44)), color, false, 3.0)
		for strip: int in range(3):
			world.draw_line(pos + Vector2(-16, -12 + strip * 12), pos + Vector2(14, -16 + strip * 12), Color("bac2b1"), 4.0, true)
		world.draw_arc(pos + Vector2(-23, 0), 16, PI / 2, PI * 1.5, 20, color, 7.0, true)
		for offset: float in [-1.0, 1.0]:
			world.draw_line(pos + Vector2(-21, offset * 27), pos + Vector2(23, offset * 27), Color("718b97"), 7.0)
	elif str(enemy.elite_map) == "foundry":
		var body: PackedVector2Array = PackedVector2Array()
		for side: int in range(6):
			body.append(pos + Vector2.from_angle(side * TAU / 6) * 30)
		world.draw_colored_polygon(body, Color("3c3033"))
		world.draw_polyline(body + PackedVector2Array([body[0]]), color, 3.0, true)
		for side: float in [-1.0, 1.0]:
			world.draw_rect(Rect2(pos + Vector2(side * 12 - 5, -17), Vector2(10, 34)), color)
			world.draw_line(pos + Vector2(side * 33, -14), pos + Vector2(side * 36, 15), Color("849094"), 7.0)
	else:
		var body: PackedVector2Array = PackedVector2Array([pos + Vector2(0, -31), pos + Vector2(29, 0), pos + Vector2(0, 31), pos + Vector2(-29, 0), pos + Vector2(0, -31)])
		world.draw_colored_polygon(body, Color("293b59"))
		world.draw_polyline(body, color, 3.0, true)
		world.draw_circle(pos, 10, color)
		for side: float in [-1.0, 1.0]:
			world.draw_circle(pos + Vector2(side * 38, 0), 5, color)
			world.draw_line(pos + Vector2(side * 25, 0), pos + Vector2(side * 36, 0), color, 2)
	world.draw_line(pos + Vector2(-28, -34), pos + Vector2(-28 + 56 * float(enemy.hp) / maxf(1, float(enemy.max_hp)), -34), color, 4.0)
