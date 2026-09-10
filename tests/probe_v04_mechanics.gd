extends "res://tests/probe_standard_world.gd"
## Input-only map-counter policy alongside the unchanged v0.3 combo policy.
## No health/energy grants, damage calls, target deletion or timer skipping.
var _observed_counters: Dictionary = {}


func _simulate(seed_value: int, strategy: String) -> void:
	_observed_counters = {"boss_breaks": 0, "interactions": 0, "elite_kills": 0}
	await super._simulate(seed_value, strategy)
	if not reports.is_empty():
		reports.back().merge(_observed_counters, true)


func _run() -> void:
	strategies = ["combo", "counter"]
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--seeds="):
			seeds.clear()
			for value: String in argument.trim_prefix("--seeds=").split(","):
				seeds.append(value.to_int())
		elif argument.begins_with("--strategies="):
			strategies.clear()
			for value: String in argument.trim_prefix("--strategies=").split(","):
				strategies.append(value)
		elif argument.begins_with("--maps="):
			maps.clear()
			for value: String in argument.trim_prefix("--maps=").split(","):
				maps.append(value)
		elif argument.begins_with("--max-seconds="):
			maximum_seconds = maxf(1.0, argument.trim_prefix("--max-seconds=").to_float())
	for action: String in ["move_left", "move_right", "move_up", "move_down", "vacuum", "dash", "active_skill"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	Input.use_accumulated_input = false
	for id: String in maps:
		current_map = id
		for seed_value: int in seeds:
			for strategy: String in strategies:
				await _simulate(seed_value, strategy)
	var report: Dictionary = {"method": "Fixed 60 Hz input-only world simulation with ordinary purchases and paid rerolls. No grants, damage calls, deleted targets or skipped combat time.",
		"policies": {"combo": "Unchanged v0.3 movement/shop/aim policy.", "counter": "Same shop priorities as combo; movement goals additionally use visible bait blocks, vent windows, power nodes and map controls. Aim, vacuum release and skill button remain ordinary inputs."},
		"limitations": "One deterministic heuristic seed is not player win rate or difficulty approval. Per-tick net HP loss can include simultaneous repair; no rendering evidence, no shop-duration recording.", "runs": reports}
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var output: FileAccess = FileAccess.open("res://artifacts/v04-mechanics-probe.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	print("V04_MECHANICS_PROBE ", JSON.stringify(report))
	root.get_node("SoundBank").stop_all()
	await create_timer(0.1).timeout
	quit()


func _item_priority(id: String, level: int, strategy: String, world: Node2D) -> float:
	return super._item_priority(id, level, "combo" if strategy == "counter" else strategy, world)


func _choose_controls(world: Node2D, strategy: String) -> Dictionary:
	var observed: Dictionary = world._director.get_stats(world)
	for key: String in _observed_counters:
		_observed_counters[key] = int(observed.get(key, 0))
	var controls: Dictionary = super._choose_controls(world, "combo" if strategy == "counter" else strategy)
	if strategy != "counter":
		return controls
	var targets: Array = world._director.encounters.targets
	if targets.is_empty() or (not world._boss.is_empty() and str(world._boss.state) == "exposed"):
		return controls
	var choice: Dictionary = {}
	var best: float = INF
	var goal: Vector2 = world.player_position
	for target: Dictionary in targets:
		if bool(target.settled):
			continue
		var candidate: Vector2 = target.pos
		if str(target.kind) == "bait":
			if world._boss.is_empty() or Vector2(world._boss.pos).distance_to(candidate) < 95.0:
				continue
			candidate += (candidate - Vector2(world._boss.pos)).normalized() * 150.0
			if not Rect2(90, 165, 1100, 450).has_point(candidate):
				continue
		elif str(target.kind) in ["node", "relay"]:
			if float(world.energy) < 34.0 and str(world.get_stats().get("ability_state", "")) != "ready":
				continue
			candidate += (world.player_position - candidate).normalized() * 95.0
		var score: float = candidate.distance_to(world.player_position)
		if score < best:
			best = score
			choice = target
			goal = candidate
	if choice.is_empty():
		return controls
	if str(choice.kind) == "bait" and str(world._boss.state) in ["windup", "charge"]:
		return controls
	if str(choice.kind) in ["cache", "press", "relay"] and best > 360.0:
		return controls
	controls.move = _safe_direction(world, goal)
	controls.aim = choice.pos
	controls.vacuum = not world._vacuum_gate
	if str(choice.kind) in ["node", "relay"]:
		var near: bool = world.player_position.distance_to(Vector2(choice.pos)) < 190.0
		controls.vacuum = not (near and world._vacuum and float(world.energy) >= 34.0) and not world._vacuum_gate
		controls.ability = world.player_position.distance_to(Vector2(choice.pos)) < 160.0 and str(world.get_stats().get("ability_state", "")) == "ready"
	return controls


func _safe_direction(world: Node2D, goal: Vector2) -> Vector2:
	var best: Vector2 = Vector2.ZERO
	var best_score: float = INF
	var reach: float = 215.0 * float(world._modifiers.speed_scale) * 0.24
	for direction: Vector2 in DIRECTIONS:
		var candidate: Vector2 = world.player_position + direction * reach
		var score: float = candidate.distance_to(goal) * 0.045
		if not Rect2(72, 146, 1135, 488).has_point(candidate):
			score += 35.0
		for obstacle: Rect2 in world._obstacles:
			if obstacle.grow(28.0).has_point(candidate):
				score += 35.0
		for enemy: Dictionary in world._enemies:
			if bool(enemy.settled) or float(enemy.spawn) > 0:
				continue
			var danger: float = float(enemy.radius) + 36.0
			var separation: float = candidate.distance_to(Vector2(enemy.pos))
			if separation < danger:
				score += 25.0 + danger - separation
			var charge: bool = (int(enemy.kind) == 3 and str(enemy.state) in ["windup", "charge"]) or float(enemy.get("windup", 0)) > 0 or float(enemy.get("charge", 0)) > 0
			if charge:
				var end: Vector2 = Vector2(enemy.get("charge_end", Vector2(enemy.pos) + Vector2(enemy.charge_dir) * 180.0))
				var closest: Vector2 = Geometry2D.get_closest_point_to_segment(candidate, enemy.pos, end)
				if candidate.distance_to(closest) < danger:
					score += 30.0
		for hazard: Dictionary in world._director.hazards:
			var depth: float = 0.0
			if str(hazard.shape) == "rect":
				var area: Rect2 = Rect2(hazard.rect).grow(32.0)
				if area.has_point(candidate):
					depth = minf(minf(candidate.x - area.position.x, area.end.x - candidate.x), minf(candidate.y - area.position.y, area.end.y - candidate.y)) + 1.0
			else:
				depth = float(hazard.radius) + 32.0 - candidate.distance_to(Vector2(hazard.pos))
			if depth > 0:
				score += 30.0 + depth * 0.45
		for shot: Dictionary in world._projectiles:
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(candidate, shot.pos, Vector2(shot.pos) + Vector2(shot.vel) * 0.3)
			if candidate.distance_to(closest) < 36.0:
				score += 22.0
		if score < best_score:
			best_score = score
			best = direction
	return best
