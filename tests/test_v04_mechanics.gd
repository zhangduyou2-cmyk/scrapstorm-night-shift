extends SceneTree
## Focused mechanics fixtures; not player-difficulty or rendering evidence.
const World = preload("res://scripts/game/game_world.gd")
var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for action: String in ["move_left", "move_right", "move_up", "move_down", "vacuum", "dash", "active_skill"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	var world: Node2D = World.new()
	root.add_child(world)
	world.set_physics_process(false)
	_yard(world)
	_foundry(world)
	_reactor(world)
	_jobs(world)
	_elites(world)
	_checkpoints(world)
	_world_resume(world)
	world.queue_free()
	await process_frame
	print("V04_MECHANICS ", JSON.stringify({"checks": checks, "failures": failures}))
	root.get_node("SoundBank").stop_all()
	await create_timer(0.1).timeout
	quit(0 if failures.is_empty() else 1)


func _boss(world: Node2D, id: String) -> void:
	world.start_standard(id, 9401)
	world.wave_index = 6
	world._spawn_boss()
	world._boss.spawn = 0.0
	world._invulnerability = 100.0


func _yard(world: Node2D) -> void:
	_boss(world, "yard")
	_check(world._director.encounters.targets.size() == 1, "yard provides one designated visible charge-bait target per cycle")
	world._boss.pos = Vector2(640, 390)
	world.player_position = Vector2(170, 390)
	world._player_velocity = Vector2.ZERO
	world._boss_brain._begin_charge(world, world._boss, Vector2.LEFT, 1.0)
	for tick: int in range(45):
		if world._boss.state != "aim":
			break
		world._boss_velocity(world._boss, Vector2.LEFT, 1.0 / 60.0)
	var locked_end: Vector2 = world._boss.charge_end
	world._boss_velocity(world._boss, Vector2.UP, 0.3)
	_check(world._boss.state == "windup" and world._boss.charge_end == locked_end and world._boss.charge_dir == Vector2.LEFT, "charge preview remains committed after tracking ends and solid lock begins")
	for tick: int in range(160):
		world._director.tick(world, 1.0 / 60.0)
		world._update_enemies(1.0 / 60.0)
		if str(world._boss.state) == "exposed":
			break
	_check(str(world._boss.state) == "exposed" and world._boss.countered, "actual boss movement into a scrap block breaks its core")
	_check(world._director.encounters.boss_breaks == 1 and world._director.encounters.targets.is_empty(), "charge counter settles all bait devices once")
	_check(world._boss_brain.damage_multiplier(world, world._boss, "blast") > 5.0 * 0.30, "earned exposure produces a substantial stored-blast damage window")
	var drops: int = world._scraps.size()
	world._director.encounters._break_boss(world)
	_check(world._director.encounters.boss_breaks == 1 and world._scraps.size() == drops, "the same exposed core cannot duplicate the counter reward")
	world._director.tick(world, 0.1)
	_check(world._projectiles.is_empty(), "a counter clears lingering hostile projectiles for readable follow-up")
	world._boss.state = "hunt"
	world._director.encounters.boss_rearm = 0.0
	world._director.tick(world, 0.01)
	_check(world._director.encounters.targets.size() == 1 and Vector2(world._director.encounters.targets[0].pos) == Vector2(905, 390), "yard counter rotates to the next designated bait location")


func _foundry(world: Node2D) -> void:
	_boss(world, "foundry")
	var target: Dictionary = world._director.encounters.targets[0]
	world.player_position = target.pos
	world._vacuum = true
	world._boss.state = "hunt"
	world._director.tick(world, 1.3)
	_check(float(target.progress) == 0 and world._director.encounters.boss_breaks == 0, "closed vents cannot be activated by permanent suction")
	world._boss_brain._recover(world._boss)
	_check(world._boss.state == "vent_window" and float(world._boss.state_timer) >= 3.5, "foundry opens a clear valve-interaction window after its attack")
	for tick: int in range(72):
		world._director.tick(world, 1.0 / 60.0)
	_check(world._boss.state == "exposed" and world._director.encounters.boss_breaks == 1, "sustained vacuum at an open valve breaks the foundry core")
	_check(world._director.hazards.is_empty(), "vent counter removes lingering floor hazards before its payoff")
	world._boss.state = "hunt"
	world._director.encounters.boss_rearm = 0.0
	world._director.tick(world, 0.01)
	_check(world._director.encounters.targets.size() == 1 and Vector2(world._director.encounters.targets[0].pos) == Vector2(860, 390), "foundry alternates the active valve instead of rewarding a permanent camp")
	world._boss.pos = Vector2(640, 250)
	world.player_position = Vector2(640, 455)
	world._boss.attack = 0
	world._boss.last_attack = ""
	world._boss_brain._select(world, world._boss, Vector2.DOWN, false)
	_check(str(world._boss.last_attack) == "charge" and str(world._boss.state) == "aim", "foundry announces tracking before its locked cross-belt charge against midrange orbiting")


func _reactor(world: Node2D) -> void:
	_boss(world, "reactor")
	_check(world._director.encounters.targets.size() == 2, "reactor has two visible power nodes")
	world._director.hit_targets(world, Vector2(700, 390), 260.0, 100.0, Vector2.LEFT, 0.8)
	_check(float(world._director.encounters.targets[1].hp) == 20.0, "a shot facing away cannot hit a nearby node")
	world._director.hit_targets(world, Vector2(700, 390), 260.0, 100.0, Vector2.RIGHT, 0.8)
	_check(world._director.encounters.boss_breaks == 0 and bool(world._director.encounters.targets[1].settled), "breaking only one node does not bypass the second target")
	world._director.hit_targets(world, Vector2(500, 390), 220.0, 100.0, Vector2.LEFT, 0.8)
	_check(world._boss.state == "exposed" and world._director.encounters.boss_breaks == 1, "breaking both power nodes produces one core exposure")
	world._director.hit_targets(world, Vector2(640, 390), 1000.0, 1000.0)
	_check(world._director.encounters.boss_breaks == 1, "a later area attack cannot reward already destroyed nodes")
	world._director.encounters.boss_rearm = 0.0
	world._director.tick(world, 0.1)
	_check(world._director.encounters.targets.is_empty(), "reactor does not rearm its shield during earned exposure")
	world._boss.state = "hunt"
	world._director.tick(world, 0.1)
	_check(world._director.encounters.targets.size() == 2, "power nodes can rearm for the next readable counter cycle")


func _jobs(world: Node2D) -> void:
	for id: String in ["yard", "foundry", "reactor"]:
		world.start_standard(id, 9402)
		world._director.encounters.job_timer = 0.0
		world._director.tick(world, 0.01)
		var target: Dictionary = world._director.encounters.targets[0]
		_check(str(target.kind) == ("cache" if id == "yard" else ("press" if id == "foundry" else "relay")), id + " spawns its own usable map interaction")
		world.player_position = target.pos
		world._vacuum = true
		if id == "reactor":
			world._director.hit_targets(world, world.player_position, 100, 100)
		else:
			for tick: int in range(90):
				world._director.tick(world, 1.0 / 60.0)
		_check(world._director.encounters.interactions == 1 and world.total_scrap == 18, id + " interaction earns one substantive salvage reward")
		_check(world._director.encounters.grid_disabled > 0.0, id + " interaction creates a safe tactical window")
		var total: int = world.total_scrap
		world._director.tick(world, 0.1)
		world._director.hit_targets(world, world.player_position, 1000, 100)
		_check(world.total_scrap == total, id + " repeated input cannot collect a completed interaction twice")


func _elites(world: Node2D) -> void:
	for id: String in ["yard", "foundry", "reactor"]:
		world.start_standard(id, 9403)
		world.wave_index = 3
		world._director.encounters.spawn_elite(world)
		var elite: Dictionary = world._enemies.back()
		elite.spawn = 0.0
		_check(int(elite.kind) == 4 and str(elite.elite_map) == id and float(elite.hp) > 200.0, id + " creates its actual elite with combat stats")
		elite.elite_timer = 0.0
		world._director.elite_velocity(world, elite, Vector2.RIGHT, 200, 0.1)
		_check(float(elite.elite_warning) >= 1.0, id + " elite commits a visible attack warning before execution")
		if id == "reactor":
			world.debug_spawn_enemy(Vector2(elite.pos) + Vector2(60, 0), 0)
			var escorted: Dictionary = world._enemies.back()
			world._director.tick(world, 0.01)
			_check(world._director.enemy_damage_multiplier(world, escorted) < 0.5, "relay sentinel shields nearby ordinary enemies")
			_check(world._director.enemy_damage_multiplier(world, elite) == 1.0, "relay sentinel itself remains an unshielded priority target")
		world._director.on_enemy_defeated(world, elite)
		var value: int = int(world._scraps.back().value)
		world._director.on_enemy_defeated(world, elite)
		_check(world._director.encounters.elite_kills == 1 and int(world._scraps.back().value) == value, id + " elite loot and counter settle once")
		if id == "reactor":
			_check(world._director.enemy_damage_multiplier(world, world._enemies.back()) == 1.0, "destroying the relay removes allied shields immediately")


func _checkpoints(world: Node2D) -> void:
	world._director.encounters.interactions = 5
	world._director.encounters.elite_kills = 2
	world._director.encounters.elite_serial = 3
	world._director.encounters.boss_adds_spawned = 17
	world._director.encounters.projections_destroyed = 4
	var encoded: Dictionary = JSON.parse_string(JSON.stringify(world._director.export_state()))
	world._director.reset()
	_check(world._director.import_state(encoded), "JSON checkpoint imports mechanic counters with integral floats")
	_check(world._director.encounters.interactions == 5 and world._director.encounters.elite_kills == 2 and world._director.encounters.elite_serial == 3, "map progression counters survive resume")
	_check(world._director.encounters.boss_adds_spawned == 17 and world._director.encounters.projections_destroyed == 4, "new boss support and projection counters survive JSON resume")
	var legacy: Dictionary = encoded.duplicate(true)
	legacy.erase("boss_adds_spawned")
	legacy.erase("projections_destroyed")
	_check(world._director.import_state(legacy) and world._director.encounters.boss_adds_spawned == 0 and world._director.encounters.projections_destroyed == 0,
		"legacy director checkpoints default absent support metrics to zero")
	world._director.import_state(encoded)
	var before: Dictionary = world._director.export_state()
	var invalid_metric: Dictionary = encoded.duplicate(true)
	invalid_metric.projections_destroyed = 0.5
	_check(not world._director.import_state(invalid_metric) and world._director.export_state() == before, "fractional support metrics reject without changing any live counter")
	encoded.elite_kills = -1
	_check(not world._director.import_state(encoded) and world._director.export_state() == before, "invalid mechanic state is rejected without mutating live counters")


func _world_resume(world: Node2D) -> void:
	world.start_standard("foundry", 9404)
	world.wave_index = 3
	world.elapsed = 465.0
	world.wave_elapsed = 180.0
	world._invulnerability = 60.0
	world._director.event_serial = 8
	world._director.encounters.elite_serial = 4
	world._director.encounters.interactions = 7
	world._loadout.weapons.foam = 1
	world._loadout.weapons.arc = 1
	world.combat_feedback(world.player_position, 1.0, "blast")
	world._complete_wave()
	var encoded: Dictionary = JSON.parse_string(JSON.stringify(world.create_checkpoint()))
	var clone: Node2D = World.new()
	root.add_child(clone)
	clone.set_physics_process(false)
	_check(clone.restore_checkpoint(encoded), "new integrated world checkpoint restores with mechanic counters")
	world.start_next_wave()
	clone.start_next_wave()
	var equal: bool = true
	var first_difference: int = -1
	for frame: int in range(2520):
		world._physics_process(1.0 / 60.0)
		clone._physics_process(1.0 / 60.0)
		if world.elapsed != clone.elapsed or world._enemies != clone._enemies or world.player_position != clone.player_position or world._director.hazards != clone._director.hazards or world._director.encounters.targets != clone._director.encounters.targets or world._director.export_state() != clone._director.export_state():
			equal = false
			first_difference = frame
			break
	_check(equal, "immediate resume matches uninterrupted play for 42 seconds including job/elite; first difference %d" % first_difference)
	clone.queue_free()


func _check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures.append(description)
		push_error(description)
