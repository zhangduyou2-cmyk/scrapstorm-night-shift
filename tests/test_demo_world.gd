extends SceneTree
## Stateful Demo regressions. No UI, timers or invincible survival claim.
const World = preload("res://scripts/game/game_world.gd")
var checks: int = 0
var failures: int = 0
var summaries: Array[Dictionary] = []
var outcomes: Array[bool] = []
var events: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for action: String in ["move_left", "move_right", "move_up", "move_down", "vacuum", "dash"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	var world: Node2D = World.new()
	root.add_child(world)
	world.set_physics_process(false)
	world.wave_completed.connect(func(summary: Dictionary) -> void: summaries.append(summary); events.append("shop"))
	world.run_finished.connect(func(won: bool, _stats: Dictionary) -> void: outcomes.append(won); events.append("finished"))
	world.stats_changed.connect(func(_stats: Dictionary) -> void: events.append("stats"))
	world.start_run(8102, true)
	_check(world.demo_mode and world.wave_index == 1 and world.phase == "combat", "Demo starts wave one in combat")
	_check(world.get_shop_offers().is_empty() and not world.buy_offer("x").ok, "combat rejects shop requests")
	world.energy = 23.0
	world.health = 50.0
	world.currency = 3
	world.total_scrap = 24
	world.debug_add_scrap(Vector2(130.0, 190.0), 50)
	world.wave_elapsed = 54.99
	world._spawn_timer = 10.0
	events.clear()
	world._physics_process(0.02)
	_check(world.phase == "shop" and summaries.size() == 1, "55 seconds finishes an ordinary wave into shop")
	_check(world.currency == 78 and world.energy == 23.0 and world.total_scrap == 24, "ground salvage and salary credit money without energy or pickup progress")
	_check(world.health == 70.0 and summaries[0].repaired == 20.0, "shop maintenance repairs 20HP independently of pickups")
	_check(summaries[0].earned_scrap == 57 and summaries[0].bonus == 18, "summary distinguishes ground salvage from salary")
	_check(events == ["stats", "shop"], "shop signal is final after its stats snapshot")
	var shop_snapshot: Dictionary = world.get_stats()
	world._complete_wave()
	world._physics_process(8.0)
	world.debug_damage_player(50.0)
	world.debug_release()
	_check(world.get_stats() == shop_snapshot and summaries.size() == 1, "shop freezes time and combat and settlement cannot repeat")
	_check(world._enemies.is_empty() and world._scraps.is_empty() and world._projectiles.is_empty() and world._foam.is_empty(), "wave transition removes combat objects")
	var offers: Array = world.get_shop_offers()
	var token: String = offers[0].token
	var cost: int = offers[0].cost
	var before: int = world.currency
	var purchased: Dictionary = world.buy_offer(token)
	_check(purchased.ok and world.currency == before - cost, "world purchase changes loadout and deducts exact cost synchronously")
	_check(not world.buy_offer(token).ok and world.currency == before - cost, "duplicate purchase does not double deduct")
	world.currency = 1000
	var hull: Dictionary = _offer_for(world, "hull")
	var hp_before: float = world.health
	_check(world.buy_offer(str(hull.token)).ok and world._max_health() == 120.0 and world.health == hp_before + 20.0, "hull raises effective max health and heals only its increase")
	var magnet: Dictionary = _offer_for(world, "magnet")
	world.buy_offer(str(magnet.token))
	_check(is_equal_approx(world._vacuum_range(), 276.0) and world.balance.vacuum_range == 240.0, "magnet changes runtime range without modifying balance Resource")
	var coolant: Dictionary = _offer_for(world, "coolant")
	world.buy_offer(str(coolant.token))
	_check(is_equal_approx(world._cooldown(1.0), 0.92), "coolant changes effective cooldown")
	var capacitor: Dictionary = _offer_for(world, "capacitor")
	world.buy_offer(str(capacitor.token))
	_check(world.get_stats().max_energy == 120.0, "capacitor changes effective HUD energy capacity")
	var brush: Dictionary = _offer_for(world, "brush")
	world.buy_offer(str(brush.token))
	_check(world._weapon_level("brush") == 2 and world._brush_radius() == 79.0, "brush upgrade changes the live weapon and radius")
	var copied_stats: Dictionary = world.get_stats()
	copied_stats.loadout.weapons.brush = 99
	_check(world._weapon_level("brush") == 2, "stats loadout is a deep copy")
	_check(world.start_next_wave() and world.wave_index == 2 and world.wave_elapsed == 0.0, "continue advances exactly one wave")
	_check(not world.start_next_wave() and world.wave_index == 2, "double continue cannot skip a wave")
	world.currency = 0
	world.health = 70.0
	world._collect_scrap(1)
	_check(world.total_scrap == 25 and world.health == 78.0, "repair progression follows cumulative pickups after spending currency")
	world.start_run(444, true)
	world.health = 0.0
	world.wave_elapsed = 55.0
	var shops_before: int = summaries.size()
	world._physics_process(0.01)
	_check(not world.active and outcomes.back() == false and summaries.size() == shops_before, "death on final ordinary-wave tick prevents maintenance and shop")
	world.start_run(444, true)
	for wave: int in range(5):
		world._complete_wave()
		world.start_next_wave()
	_check(world.wave_index == 6 and not world._boss.is_empty() and world._boss.hp > 0.0, "five ordinary shops lead to a live boss in wave six")
	world.elapsed = 10000.0
	world._physics_process(0.01)
	_check(world.active and world.phase == "combat" and world.get_stats().wave_duration == 0.0, "boss wave has no timeout victory")
	world._boss["spawn"] = 0.0
	var boss_before: float = world._boss.hp
	world._damage_enemy(world._boss, 10.0, Vector2.ZERO, "foam")
	world._damage_enemy(world._boss, 10.0, Vector2.ZERO, "arc")
	world._damage_enemy(world._boss, 10.0, Vector2.ZERO, "tool")
	_check(world._boss.hp == boss_before - 30.0, "all three basic tools can damage the boss outside exposure")
	world._boss["state"] = "exposed"
	boss_before = world._boss.hp
	world._damage_enemy(world._boss, 10.0, Vector2.ZERO, "blast")
	_check(is_equal_approx(world._boss.hp, boss_before - 18.0), "exposed boss amplifies discharge damage")
	world._boss["hp"] = 700.0
	world._boss["state"] = "hunt"
	world._boss["state_timer"] = 1.0
	world._boss_velocity(world._boss, Vector2.DOWN, 0.01)
	_check(world._boss.stage == 2, "boss enters second stage below half health")
	world._damage_enemy(world._boss, 10000.0, Vector2.ZERO)
	world._physics_process(0.01)
	_check(not world.active and outcomes.back() == true, "actual boss kill completes the Demo")
	world.start_run(223, true)
	world.wave_index = 6
	world._spawn_boss()
	world._damage_enemy(world._boss, 10000.0, Vector2.ZERO)
	world.health = 0.0
	world._physics_process(0.01)
	_check(outcomes.back() == false, "simultaneous boss kill and player death is a loss")
	_test_tools(world)
	_test_projectiles(world)
	_test_overcharge(world)
	world.start_run(73, true)
	_check(world._loadout.weapons == {"brush": 1, "foam": 0, "arc": 0, "saw": 0, "laser": 0, "missile": 0, "drone": 0, "mines": 0} and world._max_health() == 100.0 and world.total_scrap == 0 and world._boss.is_empty() and world._projectiles.is_empty() and world._foam.is_empty() and world._arcs.is_empty(), "restart resets all eight Demo tool levels, boss, hazards and cumulative salvage")
	world.queue_free()
	await process_frame
	print("DEMO_WORLD_TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _offer_for(world: Node2D, id: String) -> Dictionary:
	# Fixture samples valid offers to isolate an upgrade from shop probability.
	for attempt: int in range(100):
		for offer: Dictionary in world.get_shop_offers():
			if offer.id == id and not offer.sold:
				return offer
		world._loadout.generate_offers(world.wave_index)
	_check(false, "fixture can generate requested offer " + id)
	return {"token": "missing"}


func _test_tools(world: Node2D) -> void:
	world.start_run(171, true)
	world._scraps.clear()
	world._loadout.weapons.foam = 1
	world.debug_spawn_enemy(world.player_position + Vector2(170.0, 0.0), 2)
	var target: Dictionary = world._enemies[0]
	target["spawn"] = 0.0
	world._foam_timer = 0.0
	world._update_tools(0.01)
	_check(world._foam.size() == 1 and world._is_foamed(Vector2(target.pos)), "foam automatically paints a patch under a nearby target")
	var before: float = target.hp
	world._update_tools(0.02)
	_check(target.hp < before, "foam patch deals timed area damage")
	world._loadout.weapons.foam = 0
	world._foam_timer = 100.0
	world._loadout.weapons.arc = 1
	for index: int in range(3):
		world.debug_spawn_enemy(world.player_position + Vector2(180.0 + float(index) * 40.0, 0.0), 2)
		world._enemies.back()["spawn"] = 0.0
	world._arc_timer = 0.0
	world._update_tools(0.01)
	_check(world._arcs.size() == 2, "level-one arc chains to at most two distinct enemies")
	_check(bool(world._arcs[0].combo), "arc identifies and boosts a foamed target")
	world._foam.clear()
	world._arcs.clear()
	world._enemies.clear()
	world._loadout.weapons.arc = 3
	for index: int in range(5):
		world.debug_spawn_enemy(world.player_position + Vector2(100.0 + float(index) * 35.0, 0.0), 2)
		world._enemies.back()["spawn"] = 0.0
	world._arc_timer = 0.0
	world._update_tools(0.01)
	_check(world._arcs.size() == 4, "level-three arc reaches at most four distinct enemies")
	world._foam.append({"pos": world.player_position, "radius": 60.0, "life": 0.01, "tick": 1.0, "damage": 1.0})
	world._update_tools(0.02)
	_check(world._foam.is_empty(), "foam expires and leaves no permanent slowing zone")


func _test_projectiles(world: Node2D) -> void:
	world.start_run(77, true)
	world._projectiles.clear()
	world._fire_projectile(Vector2(190.0, 264.0), Vector2(210.0, 0.0), 10.0, false)
	world._update_projectiles(1.0)
	_check(world._projectiles.is_empty(), "projectile substeps collide with crates")
	world._fire_projectile(world.player_position - Vector2(80.0, 0.0), Vector2(210.0, 0.0), 10.0, false)
	world._update_projectiles(0.5)
	_check(world.health == 90.0 and world._projectiles.is_empty(), "enemy projectile causes one hit and is removed")
	for index: int in range(100):
		world._fire_projectile(Vector2(600.0, 200.0), Vector2.DOWN * 150.0, 10.0, true)
	_check(world._projectiles.size() == 70, "enemy projectile count is bounded")
	world._complete_wave()
	_check(world._projectiles.is_empty(), "entering shop clears existing bullets")
	world.start_run(13, true)
	world.debug_spawn_enemy(Vector2(640.0, 180.0), 2)
	var enemy: Dictionary = world._enemies[0]
	enemy["shot_timer"] = 0.0
	world._ranged_velocity(enemy, Vector2.DOWN, 210.0, 0.01)
	_check(enemy.shot_warning > 0.0 and world._projectiles.is_empty(), "ranged enemy warns before firing")
	world._ranged_velocity(enemy, Vector2.DOWN, 210.0, 0.9)
	_check(world._projectiles.size() == 1, "ranged warning completes into a dodgeable projectile")


func _test_overcharge(world: Node2D) -> void:
	world.start_run(81, true)
	world.player_aim = Vector2.RIGHT
	world.debug_spawn_enemy(world.player_position + Vector2(120.0, 0.0), 2)
	var target: Dictionary = world._enemies[0]
	target["spawn"] = 0.0
	target["hp"] = 1000.0
	world.energy = 80.0
	world.debug_release()
	var standard_damage: float = 1000.0 - float(target.hp)
	world._loadout.mods.capacitor = 3
	world._modifiers = world._loadout.get_modifiers()
	target["hp"] = 1000.0
	world.energy = 80.0
	world.debug_release()
	_check(is_equal_approx(1000.0 - float(target.hp), standard_damage), "capacitor upgrade never weakens discharge at identical stored energy")
	target["hp"] = 1000.0
	world.energy = 100.0
	world.debug_release()
	var full_damage: float = 1000.0 - float(target.hp)
	target["hp"] = 1000.0
	world.energy = 160.0
	world.debug_release()
	_check(1000.0 - float(target.hp) > full_damage and world._waves.back().radius == 345.0, "overcharge increases damage while capping discharge area")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)
	else:
		print("PASS: " + label)
