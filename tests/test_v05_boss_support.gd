extends SceneTree
## Controlled mechanics fixtures. Trajectory comparisons are not human difficulty evidence.
const World = preload("res://scripts/game/game_world.gd")
var checks: int = 0
var failures: Array[String] = []
var trajectories: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for action: String in ["move_left", "move_right", "move_up", "move_down", "vacuum", "dash", "active_skill"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	var world: Node2D = World.new()
	root.add_child(world)
	world.set_physics_process(false)
	for map_id: String in ["yard", "foundry", "reactor"]:
		_start(world, map_id)
		var encounters: RefCounted = world._director.encounters
		for i: int in range(151):
			encounters.tick(world, 1.0 / 30.0)
		_check(encounters.portals.size() == 3 and world._enemies.size() == 1, map_id + " room-three boss announces three portals before creating adds")
		for i: int in range(32):
			encounters.tick(world, 1.0 / 30.0)
		var adds: Array[Dictionary] = []
		for enemy: Dictionary in world._enemies:
			if bool(enemy.get("boss_add", false)):
				adds.append(enemy)
		_check(adds.size() == 3 and encounters.boss_adds_spawned == 3 and float(adds[0].spawn) >= 0.5, map_id + " portal creates real flagged enemies with their normal spawn grace")
		for add: Dictionary in adds:
			world._damage_enemy(add, 1000000.0, Vector2.ZERO, "brush")
		world._prune_enemies()
		world.energy = 0.0
		world._ability.charge = 10.0
		var scrap_value: int = 0
		var pickups: Array = world._scraps.duplicate()
		for drop: Dictionary in pickups:
			scrap_value += int(drop.value)
			world.player_position = drop.pos
			world._update_scraps(0.01)
		_check(scrap_value >= 3 and world.energy > 0.0 and world._ability.charge > 10.0 and world._scraps.is_empty(), map_id + " actual add drops replenish discharge and skill charge through pickup ownership")
		for i: int in range(1500):
			encounters.tick(world, 1.0 / 30.0)
		_check(_support_count(world) + encounters.portals.size() <= 6, map_id + " first-phase add and projection total stays capped at six")
		world._boss.stage = 2
		encounters._support_timer = 0.0
		for i: int in range(900):
			encounters.tick(world, 1.0 / 30.0)
		_check(_support_count(world) + encounters.portals.size() <= 8, map_id + " second-phase support stays capped at eight")
		encounters.portals.clear()
		encounters.portals.append({"pos": Vector2(100, 180), "warning": 0.2, "kind": 0})
		world._boss.state = "exposed"
		var count_before: int = world._enemies.size()
		encounters.tick(world, 1.0)
		_check(world._enemies.size() == count_before and encounters.portals[0].warning == 0.2, map_id + " a rewarded break pauses pending reinforcements")
	_projection(world)
	_endless_elite(world)
	for step: float in [1.0 / 60.0, 1.0 / 30.0]:
		var old: Dictionary = _trajectory(world, false, false, step)
		var lead: Dictionary = _trajectory(world, true, false, step)
		var dodge: Dictionary = _trajectory(world, true, true, step)
		trajectories.append_array([old, lead, dodge])
		_check(float(lead.closest) < float(old.closest) - 35.0, "tracked prediction pressures a continuing lateral move more than the old snapshot at %.4f" % step)
		_check(float(dodge.closest) > float(lead.closest) + 35.0, "changing direction at the solid lock preserves an escape at %.4f" % step)
		_check(bool(lead.locked) and bool(dodge.locked) and bool(lead.inside) and bool(dodge.inside), "locked direction and full corridor remain honest at %.4f" % step)
	_check(checks == 33, "all support and trajectory assertions reached completion")
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var report: Dictionary = {"checks": checks, "failures": failures, "trajectories": trajectories, "limits": "Isolated trajectories and invulnerable support fixtures. Not a normal-input full run, human difficulty or performance result."}
	var file := FileAccess.open("res://artifacts/v05-boss-support-tests.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("V05_BOSS_SUPPORT ", JSON.stringify(report))
	world.queue_free()
	await root.get_node("SoundBank").shutdown()
	await process_frame
	quit(0 if failures.is_empty() else 1)


func _start(world: Node2D, map_id: String) -> void:
	world.start_standard(map_id, 5501)
	world.wave_index = 3 # Deliberately not six: shared endless bosses use room IDs.
	world._spawn_boss()
	world._boss.spawn = 0.0
	world._invulnerability = 1000.0
	world.player_position = Vector2(640, 390)


func _endless_elite(world: Node2D) -> void:
	world.start_endless("reactor", 5502)
	world.wave_index = 4
	world._overtime.room = 4
	world.debug_spawn_enemy(Vector2(200, 200), 4)
	var enemy: Dictionary = world._enemies.back()
	_check(enemy.has_all(["elite_map", "elite_timer", "elite_warning", "elite_aim", "elite_cycle", "cargo"]) and str(enemy.get("elite_map", "")) == world.map_id, "direct endless elite spawns receive the full movement and drawing schema")
	_check(is_equal_approx(float(enemy.max_hp), (155.0 + 4.0 * 24.0) * world._overtime.hp_scale()), "endless elite initialization preserves actual room HP scaling")
	if not enemy.has("elite_map"):
		return
	enemy.hp -= 7.0
	enemy.elite_warning = 0.3
	var before: Dictionary = enemy.duplicate(true)
	world._director.encounters.configure_elite(world, enemy)
	_check(enemy == before, "a repeated elite initializer cannot heal damage or restart a committed warning")


func _support_count(world: Node2D) -> int:
	var result: int = 0
	for enemy: Dictionary in world._enemies:
		result += 1 if bool(enemy.get("boss_add", false)) and not bool(enemy.settled) else 0
	for target: Dictionary in world._director.encounters.targets:
		result += 1 if str(target.kind) == "projection" and not bool(target.settled) else 0
	return result


func _projection(world: Node2D) -> void:
	_start(world, "reactor")
	var encounters: RefCounted = world._director.encounters
	encounters._projection_timer = 0.0
	encounters.tick(world, 0.01)
	var projection: Dictionary = encounters.targets.back()
	_check(projection.kind == "projection" and projection.spawn > 1.0 and world._projectiles.is_empty(), "cyan projection materializes with a readable grace before any attack")
	projection.spawn = 0.0
	projection.shot_timer = 0.0
	encounters._tick_projection(world, projection, 0.01)
	var committed: Vector2 = projection.aim
	world.player_position = Vector2(1150, 160)
	encounters._tick_projection(world, projection, 0.5)
	_check(projection.aim == committed and world._projectiles.is_empty(), "projection volley commits its direction for a full warning")
	world._boss.state = "ring_warning"
	encounters._tick_projection(world, projection, 1.0)
	_check(world._projectiles.is_empty() and projection.shot_warning == 0.0, "projection does not fill the boss's announced safe ring gap")
	world._boss.state = "hunt"
	projection.shot_timer = 0.0
	encounters._tick_projection(world, projection, 0.01)
	encounters._tick_projection(world, projection, 0.91)
	_check(world._projectiles.size() == 3, "outside the safe-ring sequence a warned projection emits its three-shot fan")
	var before: int = world._scraps.size()
	var breaks_before: int = encounters.boss_breaks
	encounters.hit_targets(world, projection.pos, 0.0, 100.0)
	encounters.hit_targets(world, projection.pos, 0.0, 100.0)
	_check(projection.settled and encounters.projections_destroyed == 1 and world._scraps.size() == before + 1 and world._scraps.back().value == 3, "projection destruction settles one real three-part pickup")
	_check(encounters.boss_breaks == breaks_before, "destroying a projection never grants an unearned core break")


func _trajectory(world: Node2D, predictive: bool, reverse_on_lock: bool, step: float) -> Dictionary:
	_start(world, "yard")
	world._boss.pos = Vector2(640, 180)
	world.player_position = Vector2(490, 490)
	world._player_velocity = Vector2.RIGHT * 215.0
	var initial: Vector2 = (world.player_position - Vector2(world._boss.pos)).normalized()
	if predictive:
		world._boss_brain._begin_charge(world, world._boss, initial, 1.05)
	else:
		# Historical v0.4 snapshot fixture; uses current collision resolver only.
		var end: Vector2 = world._boss.pos
		var remaining: float = clampf(end.distance_to(world.player_position) + 145.0, 320.0, 540.0)
		while remaining > 0.0:
			var advance: float = minf(5.0, remaining)
			var next: Vector2 = world._move_body(end, initial * advance, float(world._boss.radius))
			if next.distance_to(end + initial * advance) > 0.8:
				break
			end = next
			remaining -= advance
		world._boss.merge({"state": "windup", "state_timer": 1.05, "charge_dir": initial, "charge_start": Vector2(world._boss.pos), "charge_end": end, "charge_speed": 600.0}, true)
	var closest: float = INF
	var locked: bool = true
	var inside: bool = true
	var stored: Dictionary = {}
	var moved: bool = false
	for tick: int in range(180):
		if str(world._boss.state) == "windup" and stored.is_empty():
			stored = {"dir": world._boss.charge_dir, "start": world._boss.charge_start, "end": world._boss.charge_end}
			if reverse_on_lock:
				world._player_velocity = Vector2.LEFT * 215.0
		world.player_position = world._move_body(world.player_position, Vector2(world._player_velocity) * step, 19.0)
		world._update_enemies(step)
		if not stored.is_empty() and str(world._boss.state) in ["windup", "charge"]:
			locked = locked and world._boss.charge_dir == stored.dir and world._boss.charge_end == stored.end
		if str(world._boss.state) == "charge":
			moved = true
			closest = minf(closest, world.player_position.distance_to(world._boss.pos))
			inside = inside and Vector2(world._boss.pos).distance_to(Geometry2D.get_closest_point_to_segment(world._boss.pos, stored.start, stored.end)) < 1.0
		elif moved:
			break
	return {"predictive": predictive, "reverse_on_lock": reverse_on_lock, "step": step, "closest": closest, "locked": locked, "inside": inside, "moved": moved}


func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
		push_error(description)
