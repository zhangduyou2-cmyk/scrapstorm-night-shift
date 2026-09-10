extends SceneTree
## Isolated resource/counter contracts, not ordinary-input difficulty evidence.
const World = preload("res://scripts/game/game_world.gd")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if "--test-settings" not in OS.get_cmdline_user_args():
		push_error("Requires --test-settings")
		quit(1)
		return
	var world: Node2D = World.new()
	root.add_child(world)
	world.set_physics_process(false)
	for map_id: String in ["yard", "foundry", "reactor"]:
		_damage_and_break(world, map_id)
		_support(world, map_id)
	_valve(world)
	_nodes(world)
	_guards(world)
	if "--capture" in OS.get_cmdline_user_args():
		root.size = Vector2i(1280, 720)
		for map_id: String in ["yard", "foundry", "reactor"]:
			var encounters: RefCounted = _start(world, map_id)
			world.player_position = Vector2(460, 390)
			world._boss.pos = Vector2(720, 365)
			encounters._break_boss(world)
			world._boss.state_timer = 5.4
			world._visual_time = 1.0
			world.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute("res://captures/boss-loop")
			var error: int = root.get_texture().get_image().save_png("res://captures/boss-loop/" + map_id + "-exposed.png")
			_check(error == OK, map_id + " exposed native visual capture saved")
	await root.get_node("SoundBank").shutdown()
	world.queue_free()
	await process_frame
	print("BOSS_COUNTER_LOOP ", JSON.stringify({"checks": checks, "failures": failures, "method": "Actual-world isolated fixtures with normal numeric amounts; not a player win-rate, full run or performance benchmark."}))
	quit(0 if failures.is_empty() else 1)

func _start(world: Node2D, map_id: String) -> RefCounted:
	world.start_standard(map_id, 8081, {"skill": "pulse", "skin": "industrial", "skill_color": "mint"})
	world.wave_index = 6
	world._scraps.clear()
	world._enemies.clear()
	world._spawn_boss()
	world._boss.spawn = 0.0
	world.energy = 0.0
	world._ability.charge = 0.0
	world.currency = 37
	world.total_scrap = 17
	world.health = 67.0
	world._vacuum = false
	world.player_position = Vector2(640, 390)
	return world._director.encounters

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _damage_and_break(world: Node2D, map_id: String) -> void:
	var encounters: RefCounted = _start(world, map_id)
	var expected: float = {"yard": 0.55, "foundry": 0.50, "reactor": 0.45}[map_id]
	for source: String in ["brush", "blast", "ability"]:
		var before: float = world._boss.hp
		world._damage_enemy(world._boss, 100.0, Vector2.ZERO, source)
		_check(is_equal_approx(before - float(world._boss.hp), 100.0 * expected), map_id + " actual " + source + " damage remains useful through normal armor")
	world.energy = 7.0
	world._ability.charge = 10.0
	world.debug_spawn_enemy(Vector2(700, 430), 1)
	var add: Dictionary = world._enemies.back()
	add.merge({"boss_add": true, "spawn": 0.0, "charge": 0.3, "windup": 0.2, "shot_warning": 0.3}, true)
	world._fire_projectile(Vector2(300, 300), Vector2.RIGHT * 210.0, 10.0, false)
	world._director.circle_hazard(Vector2(600, 300), 30.0, 1.0, 1.0, 12.0, "DAMAGE_PURSUIT")
	if map_id == "yard":
		world._boss.state = "charge"
		world._boss.pos = encounters.targets[0].pos
		encounters.tick(world, 0.01)
	else:
		encounters._break_boss(world)
	_check(world._boss.state == "exposed" and world._boss.countered and world._boss.state_timer == 6.0 and encounters.boss_breaks == 1, map_id + " completed counter opens exactly six seconds")
	_check(world.energy == world._max_energy() and world._ability.charge == 40.0, map_id + " counter immediately fills discharge and gives thirty skill charge")
	_check(world.currency == 37 and world.total_scrap == 17 and world.health == 67 and world._scraps.is_empty(), map_id + " counter supply does not mint currency heal or ordinary pickups")
	_check(world._projectiles.is_empty() and world._director.hazards.is_empty() and add.boss_stun == 2.0 and add.charge == 0 and add.windup == 0 and add.shot_warning == 0, map_id + " break clears prior danger and interrupts existing support for two seconds")
	world.energy = 20.0
	encounters._break_boss(world)
	_check(world.energy == 20.0 and world._ability.charge == 40.0 and encounters.boss_breaks == 1, map_id + " repeated break cannot refill the same window")
	for source: String in ["brush", "blast", "ability", "ability_echo"]:
		var before: float = world._boss.hp
		var scale: float = {"brush": 1.65, "blast": 1.85, "ability": 1.5, "ability_echo": 1.5}[source]
		world._damage_enemy(world._boss, 100.0, Vector2.ZERO, source)
		_check(is_equal_approx(before - float(world._boss.hp), 100.0 * scale), map_id + " exposed " + source + " uses the shared actual damage multiplier")

func _valve(world: Node2D) -> void:
	var encounters: RefCounted = _start(world, "foundry")
	var valve: Dictionary = encounters.targets[0]
	world.player_position = valve.pos
	world._vacuum = true
	encounters.tick(world, 0.575)
	_check(valve.progress == 0.0 and world.energy == 0.0, "closed valve cannot advance or provide supply")
	world._boss.state = "vent_window"
	encounters.tick(world, 0.575)
	_check(is_equal_approx(world.energy, 20.0) and is_equal_approx(world._ability.charge, 6.0), "first half of the live valve provides exactly half of its 40/12 allowance")
	world._vacuum = false
	encounters.tick(world, 0.4)
	world._vacuum = true
	encounters.tick(world, 0.22)
	_check(is_equal_approx(world.energy, 20.0) and is_equal_approx(world._ability.charge, 6.0), "losing and repeating valve progress cannot farm energy or skill charge")
	encounters.tick(world, 0.565)
	_check(is_equal_approx(world.energy, 40.0 * 1.14 / 1.15) and is_equal_approx(world._ability.charge, 12.0 * 1.14 / 1.15), "nearly completed valve remains bounded by its total first-progress allowance")
	encounters.tick(world, 0.05)
	_check(world._boss.state == "exposed" and world.energy == 100.0 and is_equal_approx(world._ability.charge, 42.0), "finished valve combines its one-time twelve skill charge with thirty counter charge")
	_check(world.currency == 37 and world.total_scrap == 17 and world.health == 67, "valve supply leaves economy and healing untouched")

func _nodes(world: Node2D) -> void:
	var encounters: RefCounted = _start(world, "reactor")
	var first: Dictionary = encounters.targets[0]
	var second: Dictionary = encounters.targets[1]
	world._vacuum = true
	encounters.tick(world, 1.1)
	_check(first.dismantle_progress == 0.0 and second.dismantle_progress == 0.0, "distant vacuum cannot dismantle either reactor node")
	world.player_position = first.pos
	encounters.tick(world, 0.4)
	encounters.hit_targets(world, first.pos, 0.0, 10.0)
	_check(not first.settled and first.hp == 10.0 and is_equal_approx(first.dismantle_progress, 0.4) and world.energy == 0, "partial shooting and partial absorption coexist without an early reward")
	encounters.tick(world, 0.61)
	_check(first.settled and first.hp == 0.0 and world.energy == 45.0 and world._ability.charge == 12.0 and encounters.boss_breaks == 0, "one second of nearby vacuum settles the first node once without breaking the whole boss")
	encounters.hit_targets(world, first.pos, 0.0, 30.0)
	encounters.tick(world, 0.2)
	_check(world.energy == 45.0 and world._ability.charge == 12.0, "shooting an already vacuum-dismantled node cannot duplicate its supply")
	encounters.hit_targets(world, second.pos, 0.0, 20.0)
	_check(second.settled and encounters.boss_breaks == 1 and world.energy == 100.0 and world._ability.charge == 54.0, "second node can be shot and grants 45/12 plus the whole-counter refill")
	_check(world._scraps.is_empty() and world.currency == 37 and world.total_scrap == 17 and world.health == 67, "two-node recovery creates neither spendable scrap nor incidental healing")
	encounters = _start(world, "reactor")
	first = encounters.targets[0]
	encounters.hit_targets(world, first.pos, 0.0, 20.0)
	world.player_position = first.pos
	world._vacuum = true
	encounters.tick(world, 1.1)
	_check(world.energy == 45.0 and world._ability.charge == 12.0 and encounters.boss_breaks == 0, "vacuuming an already shot node cannot settle the same node twice")

func _support_count(world: Node2D) -> Vector2i:
	var count := Vector2i.ZERO
	for enemy: Dictionary in world._enemies:
		if bool(enemy.get("boss_add", false)) and not bool(enemy.settled):
			count.x += 1
			count.y += 1 if bool(enemy.get("boss_battery", false)) else 0
	for target: Dictionary in world._director.encounters.targets:
		count.x += 1 if str(target.kind) == "projection" and not bool(target.settled) else 0
	for portal: Dictionary in world._director.encounters.portals:
		count.x += 1
		count.y += 1 if bool(portal.get("boss_battery", false)) else 0
	return count

func _support(world: Node2D, map_id: String) -> void:
	var encounters: RefCounted = _start(world, map_id)
	encounters.tick(world, 5.01)
	_check(encounters.portals.size() == 3 and not encounters.portals[0].boss_battery, map_id + " first reinforcement remains three ordinary attack enemies")
	encounters.tick(world, 1.01)
	encounters.tick(world, 2.0)
	var count: Vector2i = _support_count(world)
	_check(count.y == 2 and count.x <= 6, map_id + " independent eight-second schedule reserves two battery arrivals within the shared cap")
	encounters.tick(world, 1.01)
	var battery: Dictionary = {}
	for enemy: Dictionary in world._enemies:
		if bool(enemy.get("boss_battery", false)):
			battery = enemy
	_check(not battery.is_empty() and int(battery.kind) == 0 and battery.boss_add and battery.spawn == 0.5, map_id + " announced batteries become real flagged enemies with spawn grace")
	for i: int in range(600):
		encounters.tick(world, 1.0 / 30.0)
	count = _support_count(world)
	_check(count.x <= 6 and count.y == 2 and count.x > count.y, map_id + " living batteries do not accumulate or replace all attack support")
	world._boss.stage = 2
	encounters._support_timer = 0.0
	for i: int in range(600):
		encounters.tick(world, 1.0 / 30.0)
	count = _support_count(world)
	_check(count.x <= 8 and count.y == 2 and count.x > count.y, map_id + " enraged attacks projections and batteries share eight total seats")
	world.energy = 0.0
	world._ability.charge = 0.0
	battery.spawn = 0.0
	world._damage_enemy(battery, float(battery.hp), Vector2.ZERO, "brush")
	world._prune_enemies()
	_check(world.energy == 35.0 and world._ability.charge == 12.0 and world._scraps.is_empty() and world.currency == 37 and world.total_scrap == 17 and world.health == 67, map_id + " actual battery death is collected directly without ordinary currency or healing")
	encounters.tick(world, 0.01)
	_check(_support_count(world).y == 2, map_id + " due battery supply fills a released reserved seat without waiting for hostile deaths")
	var timer: float = encounters._battery_timer
	var pending: Array = encounters.portals.duplicate(true)
	world._boss.state = "exposed"
	encounters.tick(world, 2.0)
	_check(encounters._battery_timer == timer and encounters.portals == pending, map_id + " exposed burst window pauses both support scheduling and portal arrivals")

func _guards(world: Node2D) -> void:
	for gate: String in ["pause", "shop", "dead"]:
		var encounters: RefCounted = _start(world, "reactor")
		world.player_position = encounters.targets[0].pos
		world._vacuum = true
		world.paused = gate == "pause"
		world.phase = "shop" if gate == "shop" else "combat"
		world.health = 0.0 if gate == "dead" else 67.0
		encounters.tick(world, 10.0)
		encounters.hit_targets(world, world.player_position, 0.0, 20.0)
		encounters._break_boss(world)
		_check(encounters.targets[0].hp == 20 and encounters.targets[0].dismantle_progress == 0 and encounters.boss_breaks == 0 and encounters.portals.is_empty() and world.energy == 0.0 and world._ability.charge == 0.0, gate + " cannot progress a counter schedule batteries or collect supply")
