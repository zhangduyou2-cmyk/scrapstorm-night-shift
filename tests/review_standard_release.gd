extends SceneTree
## Independent release boundaries and a sustained high-density CPU fixture.
## Fixture mutations below are test setup, never evidence of human difficulty.
const World = preload("res://scripts/game/game_world.gd")
var checks: int = 0
var failures: Array[String] = []
var stress_runs: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for action: String in ["move_left", "move_right", "move_up", "move_down", "vacuum", "dash", "active_skill"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	var world: Node2D = World.new()
	root.add_child(world)
	world.set_physics_process(false)
	_test_ring(world)
	_test_charge(world)
	_test_hazard_escape(world)
	_test_settlement(world)
	_test_resume(world)
	# GDScript runtime errors can return from one function while SceneTree keeps
	# running; a partial test must not print a misleading successful report.
	_check(checks == 35, "all independent boundary assertions reached completion")
	world.queue_free()
	await process_frame
	if "--density" in OS.get_cmdline_user_args():
		for id: String in ["yard", "foundry", "reactor"]:
			_stress(id)
			await process_frame
		_check(stress_runs.size() == 3, "all density fixtures reached their reporting boundary")
	var report: Dictionary = {"checks": checks, "failures": failures, "density_runs": stress_runs,
		"limits": "Fixed 60 Hz headless logic only; density fixture grants invulnerability and maintains huge enemy HP, maximum projectiles, drops and hazards. No GPU, minimum-spec, difficulty or whole-run playability claim."}
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var output: FileAccess = FileAccess.open("res://artifacts/standard-release-review.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	print("STANDARD_RELEASE_REVIEW ", JSON.stringify(report))
	root.get_node("SoundBank").stop_all()
	await create_timer(0.15).timeout
	quit(0 if failures.is_empty() else 1)


func _test_ring(world: Node2D) -> void:
	world.start_standard("reactor", 6901)
	world._obstacles.clear()
	world._spawn_boss()
	world._boss.pos = Vector2(640, 390)
	world._boss.hp = float(world._boss.max_hp) * 0.40
	world._boss.stage = 2
	world._boss.attack = 1
	world._boss_brain._begin_sweep(world._boss, Vector2.RIGHT, true)
	var marked_gap: float = world._boss.sweep_angle
	var volleys: int = 0
	var safe: bool = true
	for tick: int in range(140):
		world._boss_velocity(world._boss, Vector2.DOWN, 1.0 / 60.0)
		if not world._projectiles.is_empty():
			volleys += 1
			for shot: Dictionary in world._projectiles:
				# A player 180 pixels down the marked safe bearing needs this
				# angular clearance from every projectile centerline.
				var separation: float = absf(wrapf(Vector2(shot.vel).angle() - marked_gap, -PI, PI))
				if separation < asin((float(shot.radius) + float(world.balance.player_radius)) / 180.0):
					safe = false
			world._projectiles.clear()
	_check(volleys == 3, "reactor second-stage ring executes its three committed volleys")
	_check(safe, "all ring volleys leave the visually marked safe bearing open")
	_check(world._boss.sweep_angle == marked_gap, "ring commitment keeps the marked safe bearing stable")


func _test_charge(world: Node2D) -> void:
	for id: String in ["yard", "foundry", "reactor"]:
		for phase: int in [1, 2]:
			for step: float in [1.0 / 60.0, 1.0 / 30.0]:
				world.start_standard(id, 6902)
				world._spawn_boss()
				world._boss.pos = Vector2(640, 390)
				world._boss.spawn = 0.0
				world._boss.stage = phase
				world._boss.hp = float(world._boss.max_hp) * (0.4 if phase == 2 else 1.0)
				world.player_position = Vector2(1130, 550)
				world._player_velocity = Vector2.ZERO
				world._invulnerability = 100.0
				var aim: Vector2 = (world.player_position - Vector2(world._boss.pos)).normalized()
				world._boss_brain._begin_charge(world, world._boss, aim, 0.9)
				for tick: int in range(45):
					if world._boss.state != "aim":
						break
					world._update_enemies(step)
				var start: Vector2 = world._boss.charge_start
				var end: Vector2 = world._boss.charge_end
				var recovery_state: String = "vent_window" if id == "foundry" else "recover"
				var inside: bool = true
				for tick: int in range(150):
					world._update_enemies(step)
					var position: Vector2 = world._boss.pos
					if position.distance_to(Geometry2D.get_closest_point_to_segment(position, start, end)) > 1.0:
						inside = false
					if str(world._boss.state) == recovery_state:
						break
				_check(inside and str(world._boss.state) == recovery_state and not bool(world._boss.get("countered", false)), "%s phase %d charge stays inside committed centerline and ends armored at %.4f seconds" % [id, phase, step])
	world.start_standard("yard", 6903)
	world._spawn_boss()
	world._boss.pos = Vector2(640, 390)
	world._boss.spawn = 0.0
	world._boss.hp = float(world._boss.max_hp) * 0.4
	world.player_position = Vector2(1140, 390)
	world._boss_velocity(world._boss, Vector2.RIGHT, 2.0)
	_check(world._boss.repeat_charge and world._boss.state == "aim", "enraged yard boss announces tracking for a two-charge combination")
	world._boss.state = "charge"
	world._boss.state_timer = 0.0
	world._boss_velocity(world._boss, Vector2.RIGHT, 0.01)
	_check(world._boss.state == "aim" and float(world._boss.state_timer) >= 0.30 and not world._boss.repeat_charge,
		"second charge has a fresh visible tracking warning before it can move")
	for tick: int in range(45):
		if world._boss.state != "aim":
			break
		world._boss_velocity(world._boss, Vector2.RIGHT, 1.0 / 60.0)
	var locked_end: Vector2 = world._boss.charge_end
	world.player_position = Vector2(220, 550)
	world._player_velocity = Vector2.UP * 215.0
	world._boss_velocity(world._boss, Vector2.LEFT, 0.01)
	_check(world._boss.state == "windup" and float(world._boss.state_timer) >= 0.40 and world._boss.charge_end == locked_end,
		"second charge grants a fresh 0.42-second solid lock that cannot retarget")


func _test_hazard_escape(world: Node2D) -> void:
	# From the center of a press on a live conveyor, normal movement can exit
	# during its warning without spending dash or relying on invulnerability.
	for location: Vector2 in [Vector2(410, 340), Vector2(795, 445), Vector2(990, 340)]:
		world.start_standard("foundry", 6904)
		world._enemies.clear()
		world._spawn_timer = 1000.0
		world.player_position = location
		world._director.rect_hazard(Rect2(location - Vector2(60, 42.5), Vector2(120, 85)), 1.6, 2.0, 13.0, "DAMAGE_PRESS")
		Input.action_press("move_up")
		for tick: int in range(115):
			world._physics_process(1.0 / 60.0)
		Input.action_release("move_up")
		_check(world.health == 100.0 and world._dash_cooldown == 0.0, "press at %s is escapable on foot against conveyor flow" % location)
	for id: String in ["yard", "foundry", "reactor"]:
		world.start_standard(id, 6905)
		world._spawn_boss()
		world._boss.hp = float(world._boss.max_hp) * 0.4
		world._boss_brain._begin_zone(world, world._boss, true)
		var all_warned: bool = true
		for hazard: Dictionary in world._director.hazards:
			all_warned = all_warned and float(hazard.warning) >= 1.2
		_check(all_warned and not world._director.hazards.is_empty(), id + " enraged area attacks all begin with readable warning time")


func _test_settlement(world: Node2D) -> void:
	for id: String in ["yard", "foundry", "reactor"]:
		world.start_standard(id, 6906)
		world._enemies.clear()
		world._scraps.clear()
		world.debug_spawn_enemy(Vector2(740, 390), 2)
		var enemy: Dictionary = world._enemies.back()
		enemy.spawn = 0.0
		world._damage_enemy(enemy, 10000.0, Vector2.ZERO, "ability")
		var recorded: Dictionary = world.damage_by_source.duplicate(true)
		world._damage_enemy(enemy, 10000.0, Vector2.ZERO, "blast")
		_check(world.kills == 1 and world._scraps.size() == 1 and int(world._scraps[0].value) == 3 and world.damage_by_source == recorded,
			id + " simultaneous sources settle one enemy, reward and effective damage exactly once")
		world._spawn_boss()
		world._boss.spawn = 0.0
		world._damage_enemy(world._boss, 1000000.0, Vector2.ZERO, "blast")
		world._damage_enemy(world._boss, 1000000.0, Vector2.ZERO, "ability")
		_check(world.kills == 2 and world._boss_defeated and world._scraps.size() == 1, id + " boss death settles once without ordinary pickup duplication")


func _test_resume(world: Node2D) -> void:
	world.start_standard("foundry", 6907, {"skill": "singularity", "skin": "arctic", "skill_color": "violet"})
	world._director.event_serial = 9
	world._director.salvage_completed = 4
	world.wave_index = 3
	world.wave_elapsed = 180.0
	world.elapsed = 465.0
	world._ability.charge = 47.125
	world._ability.uses = 7
	world._dash_cooldown = 0.43
	world._invulnerability = 0.27
	world._visual_time = 465.0
	world.currency = 2500
	world._complete_wave()
	world.reroll_shop()
	world.buy_offer(str(world.get_shop_offers()[0].token))
	var serialized: Dictionary = JSON.parse_string(JSON.stringify(world.create_checkpoint()))
	var clone: Node2D = World.new()
	root.add_child(clone)
	clone.set_physics_process(false)
	_check(clone.restore_checkpoint(serialized), "JSON checkpoint with rerolled and sold inventory loads")
	_check(clone._director.event_serial == 9 and clone._director.salvage_completed == 4 and clone._ability.uses == 7 and clone._ability.charge == 47.125,
		"checkpoint preserves map event sequence, completed objectives and partially filled independent ability charge")
	_check(clone.get_shop_offers() == world.get_shop_offers() and not clone.reroll_shop().ok,
		"sold rerolled inventory and consumed refresh survive JSON integer conversion")
	var sold_token: String = str(clone.get_shop_offers()[0].token)
	var wallet: int = clone.currency
	_check(not clone.buy_offer(sold_token).ok and clone.currency == wallet, "restored sold offer cannot charge or award a second time")
	world.start_next_wave()
	clone.start_next_wave()
	var consistent: bool = true
	for tick: int in range(900):
		world._physics_process(1.0 / 60.0)
		clone._physics_process(1.0 / 60.0)
		if world._enemies != clone._enemies or world.player_position != clone.player_position or world.health != clone.health or world.energy != clone.energy or world.currency != clone.currency or world._director.hazards != clone._director.hazards or world._director.salvage != clone._director.salvage or world._ability.export_state() != clone._ability.export_state():
			consistent = false
			break
	_check(consistent, "restored and uninterrupted runs remain gameplay-identical for fifteen seconds including first map event")
	clone.queue_free()


func _stress(id: String) -> void:
	var world: Node2D = World.new()
	root.add_child(world)
	world.set_physics_process(false)
	world.start_standard(id, 6991, {"skill": "overdrive"})
	world.wave_index = 6
	world._spawn_boss()
	world._boss.hp = 1.0e8
	world._boss.max_hp = 2.5e8
	world._boss.spawn = 0.0
	world._invulnerability = 10000.0
	world._loadout.weapons = {"brush": 3, "foam": 3, "arc": 3, "saw": 3}
	var samples: Array[float] = []
	var peaks: Dictionary = {"enemies": 0, "projectiles": 0, "scrap": 0, "hazards": 0, "particles": 0, "saws": 0}
	var min_enemies: int = 1000
	var min_projectiles: int = 1000
	for tick: int in range(1800):
		while world._enemies.size() < 100:
			var n: int = world._enemies.size()
			world.debug_spawn_enemy(world._move_body(Vector2(100 + n % 14 * 80, 170 + n / 14 * 66), Vector2.ZERO, 15.0), n % 3)
			world._enemies.back().hp = 1.0e8
			world._enemies.back().spawn = 0.0
		while world._projectiles.size() < 70:
			var angle: float = float(world._projectiles.size()) * TAU / 70.0 + float(tick) * 0.02
			world._fire_projectile(Vector2(640, 390) + Vector2.from_angle(angle) * 160.0, Vector2.from_angle(angle) * 230.0, 12.0, true)
		while world._scraps.size() < 150:
			world.debug_add_scrap(Vector2(90 + world._scraps.size() % 20 * 55, 180 + world._scraps.size() / 20 * 60), 1)
		while world._director.hazards.size() < 18:
			world._director.circle_hazard(Vector2(100 + world._director.hazards.size() % 6 * 190, 225 + world._director.hazards.size() / 6 * 145), 40, 1.2, 2.5, 8.0, "DAMAGE_SHOCK")
		if tick % 120 == 0:
			world._spawn_particles(Vector2(640, 390), Color.ORANGE, 240, 100.0, 300.0)
			world._ability.charge = 100.0
			world.energy = 100.0
			world._ability.activate(world)
		var before: int = Time.get_ticks_usec()
		world._physics_process(1.0 / 60.0)
		samples.append(float(Time.get_ticks_usec() - before) / 1000.0)
		min_enemies = mini(min_enemies, world._enemies.size())
		min_projectiles = mini(min_projectiles, world._projectiles.size())
		peaks.enemies = maxi(int(peaks.enemies), world._enemies.size())
		peaks.projectiles = maxi(int(peaks.projectiles), world._projectiles.size())
		peaks.scrap = maxi(int(peaks.scrap), world._scraps.size())
		peaks.hazards = maxi(int(peaks.hazards), world._director.hazards.size())
		peaks.particles = maxi(int(peaks.particles), world._particles.size())
		peaks.saws = maxi(int(peaks.saws), world._saws.size())
	samples.sort()
	var bounded: bool = peaks.enemies <= 100 and peaks.projectiles <= 70 and peaks.scrap <= 150 and peaks.hazards <= 18 and peaks.particles <= 240 and peaks.saws <= 18
	_check(bounded and min_enemies >= 80 and world.active and world.elapsed > 29.9, id + " sustained dense thirty-second fixture preserves all object caps")
	stress_runs.append({"map": id, "seconds": world.elapsed, "ticks": 1800, "p50_cpu_ms": samples[900], "p95_cpu_ms": samples[1710], "max_cpu_ms": samples.back(), "min_enemies": min_enemies, "min_post_tick_projectiles": min_projectiles, "peaks": peaks, "bounded": bounded})
	world.queue_free()


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)
