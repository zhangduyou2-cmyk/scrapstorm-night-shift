extends RefCounted
## New automatic tools own bounded pools; the world retains damage and loot.
const Loadout = preload("res://scripts/game/run_loadout.gd")
const IDS: Array[String] = ["laser", "missile", "drone", "mines"]
const CAPS: Dictionary = {"missiles": 12, "mines": 12, "beams": 20, "blasts": 16}
var missiles: Array[Dictionary] = []
var mines: Array[Dictionary] = []
var beams: Array[Dictionary] = []
var blasts: Array[Dictionary] = []
var timers: Dictionary = {}
var charging: Dictionary = {}
var clock: float = 0.0
var mark: Dictionary = {}
var drone_positions: Array[Vector2] = []
var _mine_serial: int = 0
var _foam_gate: float = 0.0


func _init() -> void:
	clear()


func clear() -> void:
	missiles.clear()
	mines.clear()
	beams.clear()
	blasts.clear()
	charging.clear()
	mark = {}
	drone_positions.clear()
	timers = {"laser": 0.5, "missile": 0.7, "drone": 0.4, "mines": 0.8}
	clock = 0.0
	_mine_serial = 0
	_foam_gate = 0.0


func tick(world: Node2D, delta: float) -> void:
	if not world.active or world.paused or world.phase != "combat" or delta <= 0.0:
		return
	clock += delta
	_foam_gate = maxf(0.0, _foam_gate - delta)
	var speed: float = world._ability.tool_speed_scale() if world._ability != null else 1.0
	for id: String in IDS:
		timers[id] = maxf(0.0, float(timers[id]) - delta * speed)
	for collection: Array in [beams, blasts]:
		for i: int in range(collection.size() - 1, -1, -1):
			collection[i].life -= delta
			if float(collection[i].life) <= 0.0:
				collection.remove_at(i)
	_update_missiles(world, delta)
	_update_mines(world, delta)
	_update_drones(world)
	var laser_level: int = int(world._loadout.weapons.get("laser", 0))
	if laser_level == 0:
		charging.clear()
	elif not charging.is_empty():
		charging.time -= delta * speed
		if float(charging.time) <= 0.0:
			_fire_laser(world, charging)
			charging.clear()
	elif float(timers.laser) <= 0.0:
		var values: Dictionary = Loadout.tool_stats("laser", laser_level)
		var target: Dictionary = world._nearest_target(world.player_position, float(values.range))
		if not target.is_empty():
			charging = {"time": values.charge, "total": values.charge, "aim": (Vector2(target.pos) - world.player_position).normalized(), "damage": values.damage, "range": values.range, "radius": values.radius}
			timers.laser = world._cooldown(float(values.interval))
			world.sound_requested.emit("arc")
	var missile_level: int = int(world._loadout.weapons.get("missile", 0))
	if missile_level > 0 and float(timers.missile) <= 0.0:
		var values: Dictionary = Loadout.tool_stats("missile", missile_level)
		var target: Dictionary = world._nearest_target(world.player_position, float(values.range))
		if not target.is_empty():
			timers.missile = world._cooldown(float(values.interval))
			for i: int in range(int(values.count)):
				if missiles.size() >= int(CAPS.missiles):
					break
				var aim: Vector2 = (Vector2(target.pos) - world.player_position).normalized().rotated(0.20 if i == 1 else -0.10)
				missiles.append({"pos": world.player_position + aim * 24.0, "velocity": aim * float(values.speed), "target": int(target.id), "damage": values.damage, "radius": values.radius, "life": 3.0})
			world.sound_requested.emit("blast")
	var mine_level: int = int(world._loadout.weapons.get("mines", 0))
	if mine_level > 0 and float(timers.mines) <= 0.0 and mines.size() < int(CAPS.mines):
		var values: Dictionary = Loadout.tool_stats("mines", mine_level)
		timers.mines = world._cooldown(float(values.interval))
		_mine_serial += 1
		mines.append({"id": _mine_serial, "pos": world._move_body(world.player_position, -Vector2(world.player_aim) * 28.0, 8.0), "arm": values.arm, "fuse": -1.0, "life": 14.0, "damage": values.damage, "radius": values.radius, "settled": false})


func _fire_laser(world: Node2D, shot: Dictionary) -> void:
	var origin: Vector2 = world.player_position
	var end: Vector2 = world._move_body(origin, Vector2(shot.aim) * float(shot.range), 2.0)
	var first: Dictionary = {}
	var first_distance: float = INF
	var struck: Dictionary = {}
	for enemy: Dictionary in world._enemies:
		if bool(enemy.settled) or float(enemy.spawn) > 0.0:
			continue
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(enemy.pos, origin, end)
		if closest.distance_to(enemy.pos) <= float(shot.radius) + float(enemy.radius) and world._line_clear(origin, enemy.pos):
			struck[int(enemy.id)] = true
			world._damage_enemy(enemy, float(shot.damage), Vector2(shot.aim) * 100.0, "laser")
			var distance: float = origin.distance_squared_to(enemy.pos)
			if distance < first_distance:
				first = enemy
				first_distance = distance
	_hit_devices_line(world, origin, end, float(shot.radius), float(shot.damage))
	_ray(origin, end, Color("7ce9ff"), 5.0, 0.22)
	if world._loadout.has_evolution("prism_relay") and not first.is_empty():
		var forks: int = 0
		for enemy: Dictionary in world._enemies:
			if bool(enemy.settled) or float(enemy.spawn) > 0.0 or struck.has(int(enemy.id)) or Vector2(enemy.pos).distance_to(first.pos) > 230.0 or not world._line_clear(first.pos, enemy.pos):
				continue
			world._damage_enemy(enemy, float(shot.damage) * 0.60, Vector2.ZERO, "prism_relay")
			_ray(first.pos, enemy.pos, Color("d3a8ff"), 3.0, 0.32)
			_hit_devices_line(world, first.pos, enemy.pos, 6.0, float(shot.damage) * 0.60)
			forks += 1
			if forks == 2:
				break
	world.sound_requested.emit("arc")


func _update_missiles(world: Node2D, delta: float) -> void:
	for i: int in range(missiles.size() - 1, -1, -1):
		var missile: Dictionary = missiles[i]
		missile.life -= delta
		var target: Dictionary = _find_enemy(world, int(missile.target))
		if target.is_empty():
			target = world._nearest_target(missile.pos, 540.0)
			if not target.is_empty():
				missile.target = int(target.id)
		var before: Vector2 = missile.pos
		if not target.is_empty():
			var desired: float = (Vector2(target.pos) - before).angle()
			var current: float = Vector2(missile.velocity).angle()
			missile.velocity = Vector2.from_angle(current + clampf(angle_difference(current, desired), -4.6 * delta, 4.6 * delta)) * 300.0
		var after: Vector2 = before + Vector2(missile.velocity) * delta
		var blocked: bool = not world._line_clear(before, after) or not world.ARENA.has_point(after)
		if blocked:
			after = world._move_body(before, after - before, 3.0)
		missile.pos = after
		var contact: bool = false
		for enemy: Dictionary in world._enemies:
			if not bool(enemy.settled) and float(enemy.spawn) <= 0.0 and Geometry2D.get_closest_point_to_segment(enemy.pos, before, after).distance_to(enemy.pos) < float(enemy.radius) + 6.0 and world._line_clear(before, enemy.pos):
				contact = true
				break
		if blocked or contact or float(missile.life) <= 0.0:
			_blast(world, after, float(missile.radius), float(missile.damage), "missile")
			if world._loadout.has_evolution("ordnance_chain"):
				_chain_mines(world, after, float(missile.radius))
			missiles.remove_at(i)


func _update_mines(world: Node2D, delta: float) -> void:
	var triggered: Array[int] = []
	for mine: Dictionary in mines:
		mine.life -= delta
		mine.arm = maxf(0.0, float(mine.arm) - delta)
		if float(mine.arm) > 0.0:
			continue
		if float(mine.fuse) < 0.0:
			for enemy: Dictionary in world._enemies:
				if not bool(enemy.settled) and float(enemy.spawn) <= 0.0 and Vector2(enemy.pos).distance_to(mine.pos) <= 64.0 + float(enemy.radius) and world._line_clear(mine.pos, enemy.pos):
					mine.fuse = 0.28
					break
		else:
			mine.fuse -= delta
			if float(mine.fuse) <= 0.0:
				triggered.append(int(mine.id))
	for id: int in triggered:
		for mine: Dictionary in mines:
			if int(mine.id) == id and not bool(mine.settled):
				if world._loadout.has_evolution("ordnance_chain"):
					_chain_mines(world, mine.pos, 1.0)
				else:
					mine.settled = true
					_blast(world, mine.pos, float(mine.radius), float(mine.damage), "mines")
				break
	for i: int in range(mines.size() - 1, -1, -1):
		if bool(mines[i].settled) or float(mines[i].life) <= 0.0:
			mines.remove_at(i)


func _chain_mines(world: Node2D, origin: Vector2, radius: float) -> void:
	var queue: Array[Dictionary] = [{"pos": origin, "radius": radius}]
	var detonated: int = 0
	while not queue.is_empty() and detonated < 8:
		var pulse: Dictionary = queue.pop_front()
		for mine: Dictionary in mines:
			if detonated >= 8:
				break
			if bool(mine.settled) or float(mine.arm) > 0.0 or Vector2(mine.pos).distance_to(pulse.pos) > float(pulse.radius) + 8.0 or not world._line_clear(pulse.pos, mine.pos):
				continue
			# Mark first: overlapping missile/mine sources cannot settle it twice.
			mine.settled = true
			detonated += 1
			_blast(world, mine.pos, float(mine.radius), float(mine.damage), "ordnance_chain")
			queue.append({"pos": mine.pos, "radius": 135.0})


func _update_drones(world: Node2D) -> void:
	drone_positions.clear()
	var level: int = int(world._loadout.weapons.get("drone", 0))
	if level <= 0:
		mark = {}
		return
	var values: Dictionary = Loadout.tool_stats("drone", level)
	if mark.is_empty() or bool(mark.get("settled", true)) or Vector2(mark.pos).distance_to(world.player_position) > float(values.range) or not world._line_clear(world.player_position, mark.pos):
		mark = world._nearest_target(world.player_position, float(values.range))
	var hunt: bool = world._loadout.has_evolution("hunter_swarm") and not mark.is_empty()
	var center: Vector2 = Vector2(mark.pos) if hunt else world.player_position
	for i: int in range(int(values.count)):
		var offset: Vector2 = Vector2.from_angle(clock * 1.9 + i * TAU / int(values.count)) * (72.0 if hunt else 66.0)
		drone_positions.append(world._move_body(center, offset, 5.0))
	if mark.is_empty() or float(timers.drone) > 0.0:
		return
	timers.drone = world._cooldown(float(values.interval))
	for drone: Vector2 in drone_positions:
		if bool(mark.settled):
			break
		if world._line_clear(world.player_position, drone) and world._line_clear(drone, mark.pos):
			world._damage_enemy(mark, float(values.damage), Vector2.ZERO, "drone")
			_ray(drone, mark.pos, Color("ffe6a1"), 2.0, 0.13)
	if hunt and _foam_gate <= 0.0 and world._foam.size() < int(world.balance.max_foam):
		_foam_gate = 1.8
		world._foam.append({"pos": Vector2(mark.pos), "radius": 56.0, "damage": 4.0, "life": 2.5, "tick": 0.0, "tick_interval": 0.45})
		world.sound_requested.emit("foam")


func _find_enemy(world: Node2D, id: int) -> Dictionary:
	for enemy: Dictionary in world._enemies:
		if int(enemy.id) == id and not bool(enemy.settled) and float(enemy.spawn) <= 0.0:
			return enemy
	return {}


func _hit_devices_line(world: Node2D, origin: Vector2, end: Vector2, width: float, damage: float) -> void:
	if not world.standard_mode:
		return
	# Snapshot because a node death can replace the counter target collection.
	for target: Dictionary in world._director.encounters.targets.duplicate():
		if bool(target.settled):
			continue
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(target.pos, origin, end)
		if closest.distance_to(target.pos) <= width + float(target.radius) and world._line_clear(origin, target.pos):
			world._director.hit_targets(world, target.pos, 0.0, damage)


func _blast(world: Node2D, at: Vector2, radius: float, damage: float, source: String) -> void:
	for enemy: Dictionary in world._enemies:
		if not bool(enemy.settled) and float(enemy.spawn) <= 0.0 and Vector2(enemy.pos).distance_to(at) <= radius + float(enemy.radius) and world._line_clear(at, enemy.pos):
			world._damage_enemy(enemy, damage, (Vector2(enemy.pos) - at).normalized() * 260.0, source)
	if world.standard_mode:
		world._director.hit_targets(world, at, radius, damage)
	if blasts.size() >= int(CAPS.blasts):
		blasts.pop_front()
	blasts.append({"pos": at, "radius": radius, "life": 0.30, "color": Color("ffc476") if source != "ordnance_chain" else Color("a6eeff")})
	world.sound_requested.emit("blast")


func _ray(origin: Vector2, end: Vector2, color: Color, width: float, life: float) -> void:
	if beams.size() >= int(CAPS.beams):
		beams.pop_front()
	beams.append({"from": origin, "to": end, "color": color, "width": width, "life": life, "total": life})


func draw(world: Node2D) -> void:
	if not charging.is_empty():
		var end: Vector2 = world._move_body(world.player_position, Vector2(charging.aim) * float(charging.range), 2.0)
		world.draw_line(world.player_position, end, Color("85dce755"), 1.5, true)
		world.draw_arc(world.player_position, 30.0, 0, TAU * (1.0 - float(charging.time) / float(charging.total)), 32, Color("91e9ff"), 3.0, true)
	for ray: Dictionary in beams:
		var tint := Color(ray.color, float(ray.life) / float(ray.total))
		if world._effects_enabled():
			world.draw_line(ray.from, ray.to, Color(tint, tint.a * 0.18), float(ray.width) * 3.0, true)
		world.draw_line(ray.from, ray.to, tint, float(ray.width), true)
	for missile: Dictionary in missiles:
		var aim: Vector2 = Vector2(missile.velocity).normalized()
		var side: Vector2 = aim.orthogonal()
		world.draw_line(Vector2(missile.pos) - aim * 22.0, missile.pos, Color("ffb75c88"), 3.0, true)
		world.draw_colored_polygon(PackedVector2Array([Vector2(missile.pos) + aim * 10, Vector2(missile.pos) - aim * 7 + side * 5, Vector2(missile.pos) - aim * 7 - side * 5]), Color("fff2c3"))
	for mine: Dictionary in mines:
		if bool(mine.settled):
			continue
		var tint := Color("ffe697") if float(mine.arm) <= 0.0 else Color("897557")
		world.draw_circle(mine.pos, 10.0, Color("172b33"))
		world.draw_arc(mine.pos, 10.0, 0, TAU, 16, tint, 2.0, true)
		world.draw_line(Vector2(mine.pos) + Vector2(-5, 0), Vector2(mine.pos) + Vector2(5, 0), tint, 2.0)
		if float(mine.fuse) >= 0.0:
			world.draw_arc(mine.pos, float(mine.radius), 0, TAU, 36, Color("fff0b877"), 1.5, true)
	for drone: Vector2 in drone_positions:
		world.draw_colored_polygon(PackedVector2Array([drone + Vector2(0, -8), drone + Vector2(10, 0), drone + Vector2(0, 8), drone + Vector2(-10, 0)]), Color("efdaa0"))
		world.draw_circle(drone, 3.5, Color("233745"))
	if not mark.is_empty() and not bool(mark.get("settled", true)):
		world.draw_arc(mark.pos, float(mark.radius) + 8.0, clock, clock + PI * 1.6, 28, Color("ffe4a388"), 1.5, true)
	for blast: Dictionary in blasts:
		var progress: float = 1.0 - float(blast.life) / 0.30
		world.draw_arc(blast.pos, float(blast.radius) * progress, 0, TAU, 36, Color(blast.color, 1.0 - progress), 4.0 * (1.0 - progress) + 1.0, true)


func get_stats() -> Dictionary:
	return {"arsenal_missiles": missiles.size(), "arsenal_mines": mines.size(), "arsenal_beams": beams.size(), "arsenal_blasts": blasts.size(), "arsenal_drones": drone_positions.size(), "arsenal_laser_charging": not charging.is_empty()}


func export_state() -> Dictionary:
	# World checkpoints are shop-only and clear transient projectiles before save.
	return {"version": 1, "timers": timers.duplicate(true), "clock": clock}


func import_state(data: Dictionary) -> bool:
	if data.size() != 3 or not data.has_all(["version", "timers", "clock"]) or not Loadout._integer_in(data.version, 1, 1) or not data.timers is Dictionary or not Loadout._exact_keys(data.timers, IDS):
		return false
	if not (data.clock is int or data.clock is float) or not is_finite(float(data.clock)) or float(data.clock) < 0.0 or float(data.clock) > 1.0e8:
		return false
	for id: String in IDS:
		var value: Variant = data.timers[id]
		if not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0.0 or float(value) > 30.0:
			return false
	clear()
	for id: String in IDS:
		timers[id] = float(data.timers[id])
	clock = float(data.clock)
	return true
