extends SceneTree
## Standard three-map input probe; visible positions/telegraphs, no stat grants or skipped time.
## No invulnerability, stat grants, direct damage, rerolls or skipped wave time.

const World = preload("res://scripts/game/game_world.gd")
const STEP: float = 1.0 / 60.0
const DIRECTIONS: Array[Vector2] = [
	Vector2.ZERO, Vector2.RIGHT, Vector2(0.707107, 0.707107), Vector2.DOWN,
	Vector2(-0.707107, 0.707107), Vector2.LEFT, Vector2(-0.707107, -0.707107),
	Vector2.UP, Vector2(0.707107, -0.707107),
]
var seeds: Array[int] = [8102]
var strategies: Array[String] = ["combo"]
var maps: Array[String] = ["yard", "foundry", "reactor"]
var current_map: String = "yard"
var maximum_seconds: float = 1400.0
var reports: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
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
	var report: Dictionary = {
		"method": "Fixed 60 Hz real world updates with input-only heuristic AI and normal shop purchases; no timer skipping or gameplay stat changes.",
		"ai_revision": "Map hazards use distance-to-safe-edge candidate cost so the bot can exit a zone when all immediate candidates are inside it. Normal economic choices include one paid reroll if affordable. No shop duration is recorded.",
		"limitations": "Scripted AI sees visible entity positions and telegraph states; wins do not replace human playtesting. HP loss is positive per-tick net loss, possibly reduced by same-tick pickup repairs. No rendering performance claim. Shops are instant.",
		"runs": reports,
	}
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var output: FileAccess = FileAccess.open("res://artifacts/standard-balance-probe.json", FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(report, "\t"))
		output.close()
	print("BALANCE_PROBE ", JSON.stringify(report))
	quit()


func _simulate(seed_value: int, strategy: String) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	root.add_child(viewport)
	var world: Node2D = World.new()
	viewport.add_child(world)
	world.set_physics_process(false)
	var outcome: Dictionary = {"finished": false, "won": false}
	world.run_finished.connect(func(won: bool, _stats: Dictionary) -> void:
		outcome["finished"] = true
		outcome["won"] = won
	)
	var purchases: Array[Dictionary] = []
	var waves: Array[Dictionary] = []
	var income: Dictionary = {"ground_recovery": 0, "salary": 0}
	world.wave_completed.connect(func(summary: Dictionary) -> void:
		income["ground_recovery"] += int(summary.get("earned_scrap", 0))
		income["salary"] += int(summary.get("bonus", 0))
	)
	world.start_standard(current_map, seed_value, {"skill": "pulse"})
	var minimum_health: float = world.health
	var net_hp_lost: float = 0.0
	var hurt_events: Array[Dictionary] = []
	var ticks: int = 0
	var aim_verified: bool = false
	var started: int = Time.get_ticks_msec()
	print("PROBE_START ", JSON.stringify({"map": current_map, "seed": seed_value, "strategy": strategy}))
	while world.active and world.elapsed < maximum_seconds:
		if world.phase == "shop":
			waves.append({"wave": world.wave_index, "elapsed": world.elapsed, "health": world.health, "currency_before_shop": world.currency, "recovered": world.total_scrap, "kills": world.kills})
			_buy(world, strategy, purchases)
			if world.currency >= int(world.get_stats().reroll_cost) + 30 and world.get_stats().can_reroll:
				var refresh: Dictionary = world.reroll_shop()
				if refresh.ok:
					purchases.append({"wave":world.wave_index,"id":"refresh","level":0,"cost":refresh.cost})
					_buy(world, strategy, purchases)
			print("PROBE_WAVE ", JSON.stringify({"map": current_map, "seed": seed_value, "strategy": strategy, "wave": world.wave_index, "health": world.health, "currency": world.currency, "loadout": world.get_stats().loadout}))
			_release_inputs()
			world.start_next_wave()
		var controls: Dictionary = _choose_controls(world, strategy)
		_apply_controls(controls, viewport)
		var health_before: float = world.health
		world._physics_process(STEP)
		if ticks == 0:
			var expected: Vector2 = (Vector2(controls.aim) - world.player_position).normalized()
			aim_verified = world.player_aim.dot(expected) > 0.97
			if not aim_verified:
				push_error("Probe mouse injection did not reach the world: expected %s / actual %s / mouse %s" % [expected, world.player_aim, world.get_global_mouse_position()])
				break
		minimum_health = minf(minimum_health, world.health)
		var loss: float = maxf(0.0, health_before - world.health)
		net_hp_lost += loss
		if loss > 0.0:
			hurt_events.append({"time": snappedf(world.elapsed, 0.01), "wave": world.wave_index, "loss": snappedf(loss, 0.01), "boss_state": world._boss.get("state", ""), "boss_distance": snappedf(world.player_position.distance_to(Vector2(world._boss.get("pos", world.player_position))), 0.01), "source": world.last_damage_source, "dash_cooldown": snappedf(world._dash_cooldown, 0.01)})
		ticks += 1
		# Batch half a simulated second per host frame. Dash is the only rising-edge
		# action, and its minimum legal cooldown exceeds a batch, preventing stale
		# frame flags from causing a second dash. Movement and suction use held state.
		if ticks % 30 == 0:
			await process_frame
	var stats: Dictionary = world.get_stats()
	var spent: int = 0
	for purchase: Dictionary in purchases:
		spent += int(purchase.cost)
	var report: Dictionary = {
		"map": current_map, "seed": seed_value, "strategy": strategy, "aim_input_verified": aim_verified,
		"outcome": (("won" if outcome.won else "lost") if outcome.finished else "probe_time_limit") if aim_verified else "invalid_input",
		"combat_seconds": snappedf(world.elapsed, 0.01), "boss_seconds": snappedf(world.wave_elapsed, 0.01) if world.wave_index == 6 else 0.0, "wave_reached": world.wave_index,
		"health": snappedf(world.health, 0.01), "minimum_health": snappedf(minimum_health, 0.01),
		"positive_net_hp_lost": snappedf(net_hp_lost, 0.01), "kills": world.kills,
		"discharges": world.shots, "recovered": world.total_scrap,
		"ground_recovery": income.ground_recovery, "salary": income.salary,
		"total_income": int(world._earned_currency),
		"spent": spent, "wallet": world.currency, "loadout": stats.loadout,
		"boss_health_remaining": stats.boss_health, "price_scale": world._loadout.price_scale, "last_damage_source": stats.last_damage_source, "damage_by_source": stats.damage_by_source, "salvage_objectives": stats.salvage_objectives, "purchases": purchases,
		"waves": waves, "hurt_events": hurt_events, "ticks": ticks, "probe_wall_ms": Time.get_ticks_msec() - started,
	}
	reports.append(report)
	print("PROBE_RESULT ", JSON.stringify(report))
	_release_inputs()
	viewport.queue_free()
	await process_frame


func _buy(world: Node2D, strategy: String, purchases: Array[Dictionary]) -> void:
	while true:
		var best: Dictionary = {}
		var best_priority: float = -1.0
		for offer: Dictionary in world.get_shop_offers():
			if bool(offer.sold) or int(offer.cost) > int(world.currency):
				continue
			var priority: float = _item_priority(str(offer.id), int(offer.level), strategy, world)
			if priority > best_priority:
				best = offer
				best_priority = priority
		if best.is_empty() or best_priority < 0.0:
			break
		var result: Dictionary = world.buy_offer(str(best.token))
		if not bool(result.get("ok", false)):
			break
		purchases.append({"wave": world.wave_index, "id": best.id, "level": best.level, "cost": result.cost})


func _item_priority(id: String, level: int, strategy: String, world: Node2D) -> float:
	if strategy == "saw":
		if id == "saw":
			return 180.0 if level == 1 else 130.0
		if id == "arc":
			return -1.0
		if id == "foam":
			return 150.0 if level == 1 else 85.0
	if strategy == "brush" and id in ["foam", "arc"]:
		return -1.0
	if strategy == "combo":
		if id in ["foam", "arc"]:
			return 160.0 if level == 1 else (110.0 if id == "arc" else 90.0)
		if id == "brush":
			return -1.0
	var priority: Dictionary = {"saw": -20, "brush": 120, "hull": 75, "torque": 95, "coolant": 85, "treads": 50, "magnet": 45, "capacitor": 40}
	var result: float = float(priority.get(id, 0)) - float(level) * 5.0
	if id == "hull" and world.health < world._max_health() * 0.65:
		result += 65.0
	return result


func _choose_controls(world: Node2D, strategy: String) -> Dictionary:
	var position: Vector2 = world.player_position
	var nearest: Dictionary = {}
	var nearest_distance: float = INF
	for enemy: Dictionary in world._enemies:
		if bool(enemy.settled) or float(enemy.spawn) > 0.0:
			continue
		var distance: float = position.distance_to(Vector2(enemy.pos))
		if distance < nearest_distance:
			nearest = enemy
			nearest_distance = distance
	var nearest_scrap: Dictionary = {}
	var scrap_distance: float = INF
	for scrap: Dictionary in world._scraps:
		var distance: float = position.distance_to(Vector2(scrap.pos))
		if distance < scrap_distance:
			nearest_scrap = scrap
			scrap_distance = distance
	var goal: Vector2 = Vector2(640, 390)
	var aim: Vector2 = goal
	var target_range: float = 70.0
	var has_ranged: bool = int(world._loadout.weapons.foam) > 0 or int(world._loadout.weapons.arc) > 0
	if strategy in ["combo", "saw"] and (has_ranged or int(world._loadout.weapons.get("saw", 0)) > 0):
		target_range = 170.0
	if not nearest.is_empty():
		var enemy_position: Vector2 = nearest.pos
		if int(nearest.kind) == 3:
			target_range = 100.0 if strategy == "brush" else 205.0
		var away: Vector2 = (position - enemy_position).normalized()
		goal = enemy_position + away * target_range
		aim = enemy_position
	if not nearest_scrap.is_empty():
		if scrap_distance < 200.0 and nearest_distance > 105.0:
			goal = nearest_scrap.pos
			aim = nearest_scrap.pos
		elif nearest.is_empty():
			goal = nearest_scrap.pos
			aim = nearest_scrap.pos
	var best_direction: Vector2 = Vector2.ZERO
	var best_score: float = INF
	var predict_distance: float = 215.0 * float(world._modifiers.speed_scale) * 0.25
	for direction: Vector2 in DIRECTIONS:
		var candidate: Vector2 = position + direction * predict_distance
		var score: float = candidate.distance_to(goal) * 0.03
		if not Rect2(71, 145, 1138, 490).has_point(candidate):
			score += 20.0
		for obstacle: Rect2 in world._obstacles:
			if obstacle.grow(28.0).has_point(candidate):
				score += 22.0
		for enemy: Dictionary in world._enemies:
			if bool(enemy.settled) or float(enemy.spawn) > 0.0:
				continue
			var enemy_pos: Vector2 = enemy.pos
			var danger_radius: float = float(enemy.radius) + 19.0 + 15.0
			var separation: float = candidate.distance_to(enemy_pos)
			if separation < danger_radius + 14.0:
				score += pow(maxf(0.0, danger_radius + 14.0 - separation) * 0.16, 2.0)
			var warning: bool = float(enemy.get("windup", 0.0)) > 0.0 or float(enemy.get("charge", 0.0)) > 0.0
			if int(enemy.kind) == 3:
				warning = str(enemy.get("state", "")) in ["windup", "charge"]
			if warning:
				var destination: Vector2 = enemy_pos + Vector2(enemy.charge_dir) * (440.0 if int(enemy.kind) == 3 else 160.0)
				var closest: Vector2 = Geometry2D.get_closest_point_to_segment(candidate, enemy_pos, destination)
				if candidate.distance_to(closest) < danger_radius + 10.0:
					score += 16.0
		for hazard: Dictionary in world._director.hazards:
			var danger: bool = Rect2(hazard.rect).grow(38.0).has_point(candidate) if str(hazard.shape) == "rect" else candidate.distance_to(Vector2(hazard.pos)) < float(hazard.radius) + 38.0
			if danger:
				var depth: float = 0.0
				if str(hazard.shape) == "rect":
					var expanded: Rect2 = Rect2(hazard.rect).grow(38.0)
					depth = minf(minf(candidate.x - expanded.position.x, expanded.end.x - candidate.x), minf(candidate.y - expanded.position.y, expanded.end.y - candidate.y))
				else:
					depth = float(hazard.radius) + 38.0 - candidate.distance_to(Vector2(hazard.pos))
				score += 26.0 + depth * 0.35 + (3.0 if float(hazard.warning) < 0.3 else 0.0)
		for projectile: Dictionary in world._projectiles:
			var projectile_pos: Vector2 = projectile.pos
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(candidate, projectile_pos, projectile_pos + Vector2(projectile.vel) * 0.30)
			if candidate.distance_to(closest) < 37.0:
				score += 15.0
		if score < best_score:
			best_score = score
			best_direction = direction
	var emergency_distance: float = 48.0
	if not nearest.is_empty():
		emergency_distance = float(nearest.radius) + float(world.balance.player_radius) + 20.0
	var immediate_danger: bool = nearest_distance < emergency_distance
	for projectile: Dictionary in world._projectiles:
		if position.distance_to(Vector2(projectile.pos)) < 47.0:
			immediate_danger = true
	var release: bool = world._vacuum and world.energy >= 45.0 and nearest_distance < 300.0
	return {"move": best_direction, "aim": aim, "vacuum": not release and not world._vacuum_gate, "dash": immediate_danger and world._dash_cooldown <= 0.0 and best_direction != Vector2.ZERO, "ability": immediate_danger and world.energy >= 30.0 and float(world.get_stats().ability_ratio) >= 1.0}


func _apply_controls(controls: Dictionary, viewport: Viewport) -> void:
	_release_inputs()
	var movement: Vector2 = controls.move
	if movement.x > 0.2:
		Input.action_press("move_right")
	elif movement.x < -0.2:
		Input.action_press("move_left")
	if movement.y > 0.2:
		Input.action_press("move_down")
	elif movement.y < -0.2:
		Input.action_press("move_up")
	if bool(controls.vacuum):
		Input.action_press("vacuum")
	if bool(controls.dash):
		Input.action_press("dash")
	if bool(controls.get("ability", false)):
		Input.action_press("active_skill")
	var mouse := InputEventMouseMotion.new()
	mouse.position = controls.aim
	mouse.global_position = controls.aim
	viewport.push_input(mouse, true)


func _release_inputs() -> void:
	for action: String in ["move_left", "move_right", "move_up", "move_down", "vacuum", "dash", "active_skill"]:
		Input.action_release(action)
