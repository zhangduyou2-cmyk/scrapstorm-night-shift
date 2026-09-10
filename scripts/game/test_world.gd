extends SceneTree
## Headless behavioral regression checks: run with --headless --path .
## --script scripts/game/test_world.gd -- --test-settings

const World = preload("res://scripts/game/game_world.gd")
var _failures: int = 0
var _checks: int = 0
var _outcomes: Array[bool] = []
var _event_order: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for action: String in ["move_left", "move_right", "move_up", "move_down", "vacuum", "dash"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	var world: Node2D = World.new()
	root.add_child(world)
	world.set_physics_process(false)
	world.run_finished.connect(func(won: bool, _stats: Dictionary) -> void: _outcomes.append(won))
	world.stats_changed.connect(func(_stats: Dictionary) -> void: _event_order.append("stats"))
	world.run_finished.connect(func(_won: bool, _stats: Dictionary) -> void: _event_order.append("finished"))
	world.start_run(12345)
	_check(world.active and world.health == 100.0 and world.currency == 0, "start initializes a live clean run")
	_check(world.get_stats()["duration"] == 180.0 and world._scraps.size() == 7, "three-minute run includes reclaim teaching trail")
	world._scraps.clear()
	world.debug_spawn_enemy(world.player_position + Vector2(100.0, 0.0), 0)
	var enemy: Dictionary = world._enemies[0]
	world._damage_enemy(enemy, 100.0, Vector2.ZERO)
	world._damage_enemy(enemy, 100.0, Vector2.ZERO)
	_check(world.kills == 1 and world._scraps.size() == 1, "enemy death awards one kill and one drop only")
	world._prune_enemies()
	_check(world._enemies.is_empty(), "dead enemies leave the live collection")
	world._scraps.clear()
	world.debug_add_scrap(world.player_position, 2)
	world._update_scraps(1.0 / 60.0)
	world._update_scraps(1.0 / 60.0)
	_check(world.currency == 2 and world.energy == 18.0 and world._scraps.is_empty(), "pickup settles once into currency and energy")
	world.player_aim = Vector2.RIGHT
	world.debug_spawn_enemy(world.player_position + Vector2(110.0, 0.0), 0)
	world._enemies[0]["spawn"] = 0.0
	world.debug_release()
	_check(world.currency == 2 and world.energy == 0.0 and world.shots == 1, "discharge spends energy without spending currency")
	var kills_before: int = world.kills
	world.debug_release()
	_check(world.shots == 1 and world.kills == kills_before, "empty discharge has no effect")
	world.energy = 70.0
	world.set_paused(true)
	var paused_snapshot: Dictionary = world.get_stats()
	world._physics_process(3.0)
	world.debug_damage_player(50.0)
	world.debug_release()
	_check(world.get_stats() == paused_snapshot, "pause freezes timer, combat, cooldowns and discharge")
	world.set_paused(false)
	Input.action_press("vacuum")
	world._update_player(0.0)
	_check(not world._vacuum and world.energy == 70.0, "held vacuum is gated after pause")
	Input.action_release("vacuum")
	world._update_player(0.0)
	_check(world.energy == 70.0 and world.shots == 1, "releasing a cancelled vacuum does not discharge")
	Input.action_press("vacuum")
	world._update_player(0.0)
	_check(world._vacuum, "a fresh press restarts vacuum after the gate clears")
	world.cancel_input()
	Input.action_release("vacuum")
	world._update_player(0.0)
	_check(world.energy == 70.0, "explicit cancellation preserves energy")
	var health_before: float = world.health
	world._dash_left = 0.10
	world.debug_damage_player(20.0)
	_check(world.health == health_before, "dash is invulnerable to contact damage")
	world._dash_left = 0.0
	world.debug_damage_player(12.0)
	world.debug_damage_player(12.0)
	_check(world.health == health_before - 12.0, "hurt invulnerability prevents stacked contact damage")
	var blocked_position: Vector2 = world._move_body(Vector2(209.0, 264.0), Vector2(200.0, 0.0), 19.0)
	_check(blocked_position.x <= 218.001, "dash substeps cannot cross a crate")
	var bounded_position: Vector2 = world._move_body(Vector2(60.0, 180.0), Vector2(-100.0, 0.0), 19.0)
	_check(bounded_position.x >= 61.0, "movement remains within arena boundaries")
	world.start_run(999)
	_check(world.health == 100.0 and world.energy == 0.0 and world.currency == 0 and world.kills == 0 and world.shots == 0 and world._enemies.is_empty() and world._particles.is_empty() and world._waves.is_empty(), "restart clears all prior combat and presentation state")
	world._scraps.clear()
	for index: int in range(175):
		world.debug_add_scrap(Vector2(100.0 + float(index), 150.0), 1)
	var total_value: int = 0
	for scrap: Dictionary in world._scraps:
		total_value += int(scrap["value"])
	_check(world._scraps.size() == 150 and total_value == 175, "ground drop cap merges value without destroying currency")
	world._scraps.clear()
	world.currency = 24
	world.total_scrap = 24
	world.health = 0.0
	world.debug_add_scrap(world.player_position, 1)
	world._update_scraps(0.016)
	_check(world.health == 0.0, "repair milestone cannot revive a player killed this tick")
	world.elapsed = 179.99
	_event_order.clear()
	world._physics_process(0.02)
	_check(_outcomes == [false] and not world.active, "death takes precedence over timeout victory in the same tick")
	_check(_event_order == ["stats", "finished"], "terminal signal follows final stats without a later overwrite")
	world._physics_process(0.02)
	_check(_outcomes.size() == 1, "a finished run signals its outcome once")
	_check(_event_order == ["stats", "finished"], "finished run emits no subsequent stats updates")
	world.start_run(54321)
	world.elapsed = 179.99
	world._physics_process(0.02)
	_check(_outcomes == [false, true], "surviving three minutes completes the shift")
	world.start_run(777)
	var expected_spawn: Vector2 = world._pick_spawn()
	world.start_run(777)
	world._spawn_particles(Vector2.ZERO, Color.WHITE, 50, 1.0, 10.0)
	var actual_spawn: Vector2 = world._pick_spawn()
	_check(expected_spawn == actual_spawn, "presentation randomness does not change gameplay RNG")
	if OS.get_cmdline_user_args().has("--stress"):
		_stress_run(world)
	world.queue_free()
	await process_frame
	print("WORLD TESTS: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _stress_run(world: Node2D) -> void:
	# CPU simulation only. Invulnerability intentionally removes survival variance;
	# this is an entity-cap / long-session check, not evidence of gameplay balance.
	world.start_run(99119)
	world._invulnerability = 1000.0
	world._scraps.clear()
	for index: int in range(100):
		world.debug_spawn_enemy(world._pick_spawn(), index % 2)
	for index: int in range(150):
		world.debug_add_scrap(Vector2(90.0 + float(index % 30) * 37.0, 155.0 + float(index / 30) * 70.0), 1)
	var peak_enemies: int = 0
	var peak_scraps: int = 0
	var peak_particles: int = 0
	var ticks: int = 0
	var started_us: int = Time.get_ticks_usec()
	while world.active and ticks < 10805:
		world._physics_process(1.0 / 60.0)
		peak_enemies = maxi(peak_enemies, world._enemies.size())
		peak_scraps = maxi(peak_scraps, world._scraps.size())
		peak_particles = maxi(peak_particles, world._particles.size())
		ticks += 1
	var elapsed_us: int = Time.get_ticks_usec() - started_us
	_check(not world.active and world.elapsed >= 180.0, "180-second stress simulation reaches a terminal state")
	_check(peak_enemies <= 100 and peak_scraps <= 150 and peak_particles <= 240, "long-session enemy, scrap and particle limits hold")
	print("STRESS: %d ticks, %.3f ms mean CPU/tick, peaks enemies=%d scrap=%d particles=%d; headless, no rendering, invulnerable player" % [ticks, float(elapsed_us) / float(ticks) / 1000.0, peak_enemies, peak_scraps, peak_particles])


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("PASS: " + description)
	else:
		_failures += 1
		push_error("FAIL: " + description)
