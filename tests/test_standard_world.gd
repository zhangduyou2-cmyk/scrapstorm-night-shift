extends SceneTree
## Stateful checks of map rules, fair warnings, economy, and portable checkpoints.
const World = preload("res://scripts/game/game_world.gd")
const Maps = preload("res://scripts/game/map_catalog.gd")
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
	_check(Maps.ids().size() == 3, "all three promised maps have playable configuration")
	var copy: Dictionary = Maps.get_map("yard")
	copy.obstacles.clear()
	_check(Maps.get_map("yard").obstacles.size() == 4, "map configuration is immutable across runs")
	_check(Maps.stage_duration(1) + Maps.stage_duration(2) + Maps.stage_duration(3) + Maps.stage_duration(4) + Maps.stage_duration(5) == 870.0, "five standard combat stages have the planned total without shop timing")
	for id: String in Maps.ids():
		world.start_standard(id, 721, {"skin": "arctic", "skill": "singularity", "skill_color": "violet"})
		_check(world.standard_mode and world.demo_mode and world.map_id == id and world.wave_index == 1, id + " starts standard stage one")
		_check(world.get_stats().wave_duration == 120.0 and world._obstacles == Maps.get_map(id).obstacles, id + " applies its stage clock and collision layout")
		_check(world.player_skin == "arctic" and world.get_stats().ability_id == "singularity", id + " keeps selected cosmetics and skill")
		_check(world.create_checkpoint().is_empty(), id + " rejects mid-combat checkpoint")
		world._scraps.clear()
		world._enemies.clear()
		world._director.event_timer = 0.0
		world._director.tick(world, 0.01)
		_check(world._director.hazards.is_empty() if id == "yard" else not world._director.hazards.is_empty(), id + " runs its actual map event")
		world._spawn_boss()
		_check(world._boss.hp == Maps.get_map(id).boss_health and world.get_stats().boss_name_key == Maps.get_map(id).boss_name_key, id + " uses its distinct boss definition")
		world._boss.spawn = 0.0
		world._boss.hp = float(world._boss.max_hp) * 0.45
		world._boss.state_timer = 0.0
		world._boss_velocity(world._boss, Vector2.DOWN, 0.01)
		_check(world._boss.stage == 2 and world._boss.state in ["windup", "sweep_warning", "ring_warning", "zone"], id + " enters a telegraphed second-stage attack")
		world._clear_combat_objects()
		_check(world._director.hazards.is_empty() and world._saws.is_empty(), id + " clears all map and weapon hazards at a shop")
	_test_hazards(world)
	_test_combat(world)
	_test_checkpoint(world)
	_test_stage_groups(world)
	world.start_run(12, false)
	_check(not world.standard_mode and not world.demo_mode and world.map_id == "yard", "quick restart resets all standard map state")
	world.start_run(12, true)
	_check(not world.standard_mode and world.get_stats().wave_duration == 55.0, "legacy Demo retains its 55 second stage clock")
	world.queue_free()
	await process_frame
	print("STANDARD_TEST ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)


func _test_hazards(world: Node2D) -> void:
	world.start_standard("foundry", 101)
	_check(world._director.flow_at(world, Vector2(500, 340)).x > 0.0 and world._director.flow_at(world, Vector2(500, 445)).x < 0.0, "conveyor lanes move in opposite directions")
	world.player_position = Vector2(500, 340)
	var before: Vector2 = world.player_position
	world._update_player(0.1)
	_check(world.player_position.x > before.x, "conveyor applies to the actual player movement")
	world._scraps.clear()
	world.debug_add_scrap(Vector2(700, 340), 1)
	world._update_scraps(0.1)
	_check(float(world._scraps[0].pos.x) > 700.0, "conveyor applies to dropped scrap")
	world._director.hazards.clear()
	world._director.circle_hazard(world.player_position, 70.0, 1.0, 2.0, 10.0, "DAMAGE_PRESS")
	var health_before: float = world.health
	world._director.tick(world, 0.5)
	_check(world.health == health_before, "hazard warning never deals damage")
	world._director.tick(world, 0.5)
	_check(world.health == health_before, "warning transition grants a full visible boundary tick")
	world._director.tick(world, 0.01)
	_check(world.health == health_before - 10.0 and world.last_damage_source == "DAMAGE_PRESS", "live hazard applies damage with an explainable source")
	world.set_paused(true)
	var snapshot: Dictionary = world._director.hazards[0].duplicate(true)
	world._physics_process(2.0)
	_check(world._director.hazards[0] == snapshot, "pause freezes environmental warning and damage clocks")
	world.start_standard("yard", 103)
	world._director.salvage_timer = 0.0
	world._director.tick(world, 0.01)
	_check(not world._director.salvage.is_empty(), "marked active salvage objective spawns")
	world.player_position = world._director.salvage.pos
	world._vacuum = true
	for i: int in range(30):
		world._director.tick(world, 0.1)
	_check(world._director.salvage_completed == 1 and world.total_scrap == 6, "holding suction in objective earns a one-time pickup reward")
	world._director.tick(world, 0.1)
	_check(world._director.salvage_completed == 1, "completed objective cannot reward twice")


func _target(world: Node2D, position: Vector2, kind: int = 0) -> Dictionary:
	world.debug_spawn_enemy(position, kind)
	var enemy: Dictionary = world._enemies.back()
	enemy.spawn = 0.0
	enemy.hp = 5000.0
	enemy.max_hp = 5000.0
	return enemy


func _test_combat(world: Node2D) -> void:
	world.start_standard("yard", 201)
	world.player_position = Vector2(160, 260)
	world.player_aim = Vector2.RIGHT
	world._enemies.clear()
	var target: Dictionary = _target(world, Vector2(335, 260))
	world.energy = 100.0
	world.debug_release()
	_check(target.hp == 5000.0, "opaque crate blocks spray rather than allowing safe return fire through cover")
	_check(world._nearest_target(world.player_position, 300.0).is_empty(), "automatic weapon targeting respects opaque cover")
	world._obstacles.clear()
	world.energy = 99.0
	world.debug_release()
	var charged_damage: float = 5000.0 - float(target.hp)
	target.hp = 5000.0
	for i: int in range(11):
		world.energy = 9.0
		world.debug_release()
	_check(5000.0 - float(target.hp) < charged_damage, "splitting identical energy into tiny sprays does not manufacture damage")
	target.hp = 20.0
	world.damage_by_source.clear()
	world._damage_enemy(target, 1000.0, Vector2.ZERO, "saw")
	_check(world.damage_by_source.saw == 20.0, "contribution records effective damage without overkill inflation")
	world.start_standard("yard", 202)
	world._collect_scrap(12)
	_check(world.currency == 13 and world.total_scrap == 12 and world.combo == 12, "continuous collection grants modest extra currency without fake pickups")
	world._spawn_timer = 100.0
	world._physics_process(4.01)
	_check(world.combo == 0, "collection chain expires in combat")
	world.start_standard("yard", 203)
	world._obstacles.clear()
	world._enemies.clear()
	target = _target(world, Vector2(740, 390))
	world._loadout.weapons.saw = 1
	world._saw_timer = 0.0
	world._update_saws(0.01)
	_check(world._saws.size() == 1, "equipped saw creates a moving blade")
	world._update_saws(0.25)
	_check(target.hp < 5000.0 and world.damage_by_source.has("saw"), "swept blade collision hits its target and reports contribution")
	var hp: float = target.hp
	world._update_saws(0.01)
	_check(target.hp == hp, "one blade never repeatedly hits the same target")
	world.start_standard("yard", 204)
	world._obstacles.clear()
	world._spawn_boss()
	world._boss.spawn = 0.0
	world.player_position = Vector2(640, 580)
	world._player_velocity = Vector2.ZERO
	world._boss_brain._begin_charge(world, world._boss, Vector2.DOWN, 1.0)
	for tick: int in range(45):
		if world._boss.state != "aim":
			break
		world._boss_velocity(world._boss, Vector2.DOWN, 1.0 / 60.0)
	var committed_end: Vector2 = world._boss.charge_end
	_check(committed_end.y <= world.ARENA.end.y - float(world._boss.radius), "charge telegraph stops at the actual collision boundary")
	world.player_position = Vector2(1100, 580)
	world._boss_velocity(world._boss, Vector2.RIGHT, 0.2)
	_check(world._boss.state == "windup" and world._boss.charge_dir == Vector2.DOWN and world._boss.charge_end == committed_end, "solid locked charge does not silently track a dodging player")
	world._boss.state = "charge"
	world._boss.state_timer = 0.4
	world._foam.append({"pos": world._boss.pos, "radius": 200.0, "life": 3.0, "tick": 1.0, "damage": 0.0})
	var start: Vector2 = world._boss.pos
	world._update_enemies(0.01)
	_check(is_equal_approx(Vector2(world._boss.pos).distance_to(start), float(world._boss.charge_speed) * 0.01), "boss charge is not nullified by foam slowing")
	world._boss.state = "hunt"
	hp = world._boss.hp
	world._damage_enemy(world._boss, 100.0, Vector2.ZERO, "brush")
	var armored: float = hp - float(world._boss.hp)
	world._boss.state = "exposed"
	world._boss.countered = true
	hp = world._boss.hp
	world._damage_enemy(world._boss, 100.0, Vector2.ZERO, "blast")
	_check(hp - float(world._boss.hp) > armored * 2.0, "earned counter exposure rewards a stored spray while armor remains damageable")


func _test_checkpoint(world: Node2D) -> void:
	world.start_standard("reactor", 301, {"skin": "hazard", "skill": "overdrive", "skill_color": "cyan"})
	world.player_position = Vector2(960, 390)
	world.currency = 500
	world._complete_wave()
	var offer: Dictionary = world.get_shop_offers()[0]
	world.buy_offer(str(offer.token))
	var rerolled: Dictionary = world.reroll_shop()
	_check(rerolled.ok and not world.get_stats().can_reroll, "shop reroll deducts once and consumes its single opportunity")
	var wallet: int = world.currency
	_check(not world.reroll_shop().ok and world.currency == wallet, "second reroll cannot deduct money")
	var data: Dictionary = world.create_checkpoint()
	_check(not data.is_empty(), "live standard shop creates a checkpoint")
	var clone: Node2D = World.new()
	root.add_child(clone)
	clone.set_physics_process(false)
	var json_copy: Dictionary = JSON.parse_string(JSON.stringify(data))
	_check(clone.restore_checkpoint(json_copy), "JSON checkpoint restores independently of in-memory Godot types")
	_check(clone.phase == "shop" and clone.currency == world.currency and clone.player_position == world.player_position, "checkpoint restores map position, wallet, and shop phase")
	_check(clone.get_shop_offers() == world.get_shop_offers() and not clone.get_stats().can_reroll, "checkpoint preserves exact offers and spent reroll")
	_check(clone._rng.state == world._rng.state and clone._rng.seed == world._rng.seed, "checkpoint preserves full 64-bit RNG state")
	_check(clone.get_stats().ability_id == "overdrive" and clone.get_stats().skin == "hazard", "checkpoint preserves selected skill and cosmetic choices")
	var before: Dictionary = clone.get_stats()
	var broken: Dictionary = json_copy.duplicate(true)
	broken.health = -1.0
	_check(not clone.restore_checkpoint(broken) and clone.get_stats() == before, "malformed checkpoint is rejected without changing a live world")
	broken = json_copy.duplicate(true)
	broken.ability.cooldown = -2.0
	_check(not clone.restore_checkpoint(broken) and clone.get_stats() == before, "invalid nested skill state is rejected atomically")
	world.start_next_wave()
	clone.start_next_wave()
	world._spawn_standard_group()
	clone._spawn_standard_group()
	_check(world._enemies == clone._enemies, "restored shop resumes the same next spawn sequence")
	clone.queue_free()


func _test_stage_groups(world: Node2D) -> void:
	var groups: Array = []
	for wave: int in range(1, 6):
		world.start_standard("yard", 401)
		world.wave_index = wave
		world.wave_elapsed = 15.0
		var counts: Array[int] = [0, 0, 0]
		for i: int in range(100):
			world._enemies.clear()
			world._spawn_standard_group()
			for enemy: Dictionary in world._enemies:
				counts[int(enemy.kind)] += 1
		groups.append(counts)
	_check(groups[0][1] == 0 and groups[0][2] == 0, "opening collection stage introduces only pursuit enemies")
	_check(groups[1][1] > groups[1][0] * 0.5, "pincer stage materially emphasizes chargers")
	_check(groups[2][2] > groups[2][1], "breakthrough stage emphasizes ranged pressure")
	_check(groups[3][0] > groups[3][1] and groups[3][0] > groups[3][2], "salvage stage gives collectable crowds around its objectives")
	_check(groups[4][0] > 0 and groups[4][1] > 0 and groups[4][2] > 0, "siege stage combines all established threats")


func _check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures.append(description)
		push_error(description)
