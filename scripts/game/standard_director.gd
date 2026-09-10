extends RefCounted
## Visible, timed environmental hazards and salvage objectives. No timers run in shops.
const Encounters = preload("res://scripts/game/mechanical_encounters.gd")
var encounters: RefCounted = Encounters.new()

var hazards: Array[Dictionary] = []
var salvage: Dictionary = {}
var event_timer: float = 12.0
var salvage_timer: float = 20.0
var event_serial: int = 0
var salvage_completed: int = 0


func reset() -> void:
	encounters.reset()
	hazards.clear()
	salvage.clear()
	event_timer = 12.0
	salvage_timer = 20.0
	event_serial = 0
	salvage_completed = 0


func clear_stage() -> void:
	encounters.clear_stage()
	hazards.clear()
	salvage.clear()
	event_timer = 10.0
	salvage_timer = 18.0


func flow_at(world: Node2D, position: Vector2) -> Vector2:
	if not world.standard_mode or world.map_id != "foundry":
		return Vector2.ZERO
	if position.y >= 315.0 and position.y <= 367.0:
		return Vector2(68.0, 0.0)
	if position.y >= 419.0 and position.y <= 471.0:
		return Vector2(-68.0, 0.0)
	return Vector2.ZERO


func rect_hazard(rect: Rect2, warning: float, duration: float, damage: float, source: String) -> void:
	if hazards.size() >= 18:
		return
	hazards.append({"shape": "rect", "rect": rect, "pos": rect.get_center(), "radius": 0.0, "warning": warning, "max_warning": warning, "life": duration, "damage": damage, "source": source})


func circle_hazard(position: Vector2, radius: float, warning: float, duration: float, damage: float, source: String) -> void:
	if hazards.size() >= 18:
		return
	hazards.append({"shape": "circle", "rect": Rect2(), "pos": position, "radius": radius, "warning": warning, "max_warning": warning, "life": duration, "damage": damage, "source": source})


func tick(world: Node2D, delta: float) -> void:
	encounters.tick(world, delta)
	for index: int in range(hazards.size() - 1, -1, -1):
		var hazard: Dictionary = hazards[index]
		if float(hazard.warning) > 0.0:
			hazard.warning = maxf(0.0, float(hazard.warning) - delta)
			continue
		hazard.life = float(hazard.life) - delta
		if float(hazard.life) <= 0.0:
			hazards.remove_at(index)
			continue
		var hit: bool = Rect2(hazard.rect).grow(12.0).has_point(world.player_position) if hazard.shape == "rect" else Vector2(hazard.pos).distance_to(world.player_position) <= float(hazard.radius) + 12.0
		if hit:
			world._damage_player(float(hazard.damage), Vector2(hazard.pos), str(hazard.source))
	event_timer -= delta
	if event_timer <= 0.0:
		event_serial += 1
		event_timer = 18.0 if int(world.wave_index) < 4 else 14.0
		if world.map_id == "foundry":
			var press_x: float = [350.0, 735.0, 930.0][event_serial % 3]
			rect_hazard(Rect2(press_x, 298.0 if event_serial % 2 else 403.0, 120.0, 85.0), 1.6, 2.0, 13.0, "DAMAGE_PRESS")
		elif world.map_id == "reactor" and float(encounters.grid_disabled) <= 0.0:
			var lane: int = event_serial % 4
			var rect: Rect2 = Rect2(530.0, 150.0, 58.0, 480.0) if lane % 2 == 0 else Rect2(710.0, 150.0, 58.0, 480.0)
			if lane >= 2:
				rect = Rect2(100.0, 350.0 if lane == 2 else 445.0, 1080.0, 42.0)
			rect_hazard(rect, 1.8, 2.3, 12.0, "DAMAGE_GRID")
	if (world.endless_mode and world._overtime.boss_room()) or (not world.endless_mode and int(world.wave_index) >= 6):
		return
	salvage_timer -= delta
	if salvage.is_empty() and salvage_timer <= 0.0:
		# A marked pickup objective draws players off an otherwise safe orbit.
		var points: Array[Vector2] = [Vector2(340, 390), Vector2(940, 390), Vector2(640, 230), Vector2(640, 550)]
		var position: Vector2 = points[world._rng.randi_range(0, points.size() - 1)]
		salvage = {"pos": position, "progress": 0.0, "life": 18.0, "required": 2.8}
		salvage_timer = 26.0 if int(world.wave_index) == 4 else 42.0
	if not salvage.is_empty():
		salvage.life = float(salvage.life) - delta
		if world.player_position.distance_to(Vector2(salvage.pos)) <= 65.0 and world._vacuum:
			salvage.progress = minf(float(salvage.required), float(salvage.progress) + delta)
		else:
			salvage.progress = maxf(0.0, float(salvage.progress) - delta * 0.4)
		if float(salvage.progress) >= float(salvage.required):
			world._collect_scrap(10 if int(world.wave_index) == 4 else 6)
			world._spawn_particles(Vector2(salvage.pos), Color("f8df8a"), 22, 80.0, 260.0)
			world.sound_requested.emit("collect")
			salvage_completed += 1
			salvage.clear()
		elif float(salvage.life) <= 0.0:
			salvage.clear()


func draw_floor(world: Node2D) -> void:
	if world.map_id == "foundry":
		for lane: int in range(2):
			var y: float = 315.0 + float(lane) * 104.0
			world.draw_rect(Rect2(55.0, y, 1170.0, 52.0), Color("38332e"))
			world.draw_line(Vector2(55, y), Vector2(1225, y), Color("a77845"), 3.0)
			world.draw_line(Vector2(55, y + 52), Vector2(1225, y + 52), Color("a77845"), 3.0)
			for index: int in range(34):
				var x: float = 50.0 + fposmod(float(index) * 36.0 + world._visual_time * (68.0 if lane == 0 else -68.0), 1170.0)
				var direction: float = 1.0 if lane == 0 else -1.0
				world.draw_polyline(PackedVector2Array([Vector2(x - 7 * direction, y + 16), Vector2(x + 4 * direction, y + 26), Vector2(x - 7 * direction, y + 36)]), Color("7e7758"), 2.0, true)
	elif world.map_id == "reactor":
		for radius: float in [100.0, 176.0, 233.0]:
			world.draw_arc(Vector2(640, 390), radius, 0.0, TAU, 72, Color(0.40, 0.55, 0.9, 0.16), 2.0, true)
		for x: float in [558.0, 738.0]:
			world.draw_line(Vector2(x, 151), Vector2(x, 630), Color(0.4, 0.65, 1.0, 0.12), 12.0)
	else:
		for x: float in [340.0, 940.0]:
			world.draw_arc(Vector2(x, 390), 66.0, 0.0, TAU, 36, Color(0.85, 0.73, 0.38, 0.13), 2.0, true)


func draw_hazards(world: Node2D) -> void:
	for hazard: Dictionary in hazards:
		var warning: bool = float(hazard.warning) > 0.0
		var color: Color = Color(1.0, 0.64, 0.20, 0.22) if warning else Color(1.0, 0.25, 0.22, 0.36)
		var edge: Color = Color("ffbc58") if warning else Color("ff555a")
		if hazard.shape == "rect":
			var rect: Rect2 = hazard.rect
			world.draw_rect(rect, color)
			world.draw_rect(rect, edge, false, 2.5)
			for index: int in range(1, int(rect.size.x / 22.0)):
				var x: float = rect.position.x + float(index) * 22.0
				world.draw_line(Vector2(x, rect.position.y + 3), Vector2(minf(x + 18, rect.end.x), rect.end.y - 3), Color(edge, 0.30), 1.0)
		else:
			world.draw_circle(Vector2(hazard.pos), float(hazard.radius), color)
			world.draw_arc(Vector2(hazard.pos), float(hazard.radius), 0.0, TAU, 48, edge, 2.5, true)
		var pos: Vector2 = hazard.pos
		# Shape marker stays readable even when reduced-effects is selected.
		world.draw_line(pos + Vector2(0, -10), pos + Vector2(0, 3), edge, 3.5)
		world.draw_circle(pos + Vector2(0, 10), 2.2, edge)
	if not salvage.is_empty():
		var pos: Vector2 = salvage.pos
		world.draw_circle(pos, 65.0, Color(0.47, 0.92, 0.74, 0.07))
		world.draw_arc(pos, 65.0, 0, TAU, 48, Color("bde89f"), 2.0, true)
		world.draw_arc(pos, 58.0, -PI / 2.0, -PI / 2.0 + TAU * float(salvage.progress) / float(salvage.required), 40, Color("fff3a8"), 4.0, true)
		world.draw_rect(Rect2(pos - Vector2(14, 14), Vector2(28, 28)), Color("d3b76b"))
		world.draw_line(pos - Vector2(8, 0), pos + Vector2(8, 0), Color("17272e"), 4.0)
		world.draw_line(pos - Vector2(0, 8), pos + Vector2(0, 8), Color("17272e"), 4.0)
	encounters.draw(world)


func setup_boss(world: Node2D) -> void:
	encounters.prepare_boss(world)


func hit_targets(world: Node2D, origin: Vector2, reach: float, damage: float, aim: Vector2 = Vector2.ZERO, half_angle: float = PI) -> void:
	encounters.hit_targets(world, origin, reach, damage, aim, half_angle)


func elite_velocity(world: Node2D, enemy: Dictionary, direction: Vector2, distance: float, delta: float) -> Vector2:
	return encounters.elite_velocity(world, enemy, direction, distance, delta)


func draw_elite(world: Node2D, enemy: Dictionary) -> void:
	encounters.draw_elite(world, enemy)


func on_enemy_defeated(world: Node2D, enemy: Dictionary) -> void:
	encounters.on_enemy_defeated(world, enemy)


func enemy_damage_multiplier(_world: Node2D, enemy: Dictionary) -> float:
	return 0.48 if bool(enemy.get("elite_shield", false)) else 1.0


func get_stats(world: Node2D) -> Dictionary:
	return encounters.get_stats(world)


func export_state() -> Dictionary:
	# Only wave-boundary checkpoints exist. Transient devices and their clocks
	# are reset identically by clear_stage in uninterrupted and restored runs.
	return {"version": 1, "interactions": encounters.interactions, "elite_kills": encounters.elite_kills,
		"boss_breaks": encounters.boss_breaks, "elite_serial": encounters.elite_serial,
		"boss_adds_spawned": encounters.boss_adds_spawned, "projections_destroyed": encounters.projections_destroyed}


func validate_state(state: Dictionary) -> bool:
	if state.get("version", 0) != 1:
		return false
	for key: String in ["interactions", "elite_kills", "boss_breaks", "elite_serial"]:
		var value: Variant = state.get(key, null)
		if not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0 or float(value) > 1000000 or float(value) != floorf(float(value)):
			return false
	for key: String in ["boss_adds_spawned", "projections_destroyed"]:
		var value: Variant = state.get(key, 0)
		if not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0 or float(value) > 100000000 or float(value) != floorf(float(value)):
			return false
	return true


func import_state(state: Dictionary) -> bool:
	if not validate_state(state):
		return false
	encounters.interactions = int(state.interactions)
	encounters.elite_kills = int(state.elite_kills)
	encounters.boss_breaks = int(state.boss_breaks)
	encounters.elite_serial = int(state.elite_serial)
	encounters.boss_adds_spawned = int(state.get("boss_adds_spawned", 0))
	encounters.projections_destroyed = int(state.get("projections_destroyed", 0))
	return true
