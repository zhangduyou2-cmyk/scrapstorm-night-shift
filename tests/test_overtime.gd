extends SceneTree
## State fixtures test transitions and corruption. They do not certify human balance.
const World = preload("res://scripts/game/game_world.gd")
const Profile = preload("res://scripts/services/player_profile.gd")
const Overtime = preload("res://scripts/game/overtime_director.gd")
var checks: int = 0
var failures: Array[String] = []

func verify(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func make_world() -> Node2D:
	var world := World.new()
	root.add_child(world)
	world.set_physics_process(false)
	return world

func run() -> void:
	await process_frame
	root.get_node("Settings").effects_enabled = false
	var world: Node2D = make_world()
	world.start_endless("yard", 593204, {"skill": "pulse", "skin": "cobalt", "skill_color": "ember"})
	verify(world.endless_mode and world.standard_mode and world._loadout.slots == 4, "Endless starts a real four-slot map run")
	verify(world.player_skin == "cobalt" and world.skill_color == Color("ff8c4b"), "Achievement cosmetics reach actual combat")
	verify(not world.extract_overtime(), "Cannot extract from combat")
	verify(not world.choose_overtime_route(0), "No route mutations in combat")
	world._damage_player(19, Vector2.ZERO)
	verify(world.damage_events == 1 and world.damage_taken == 19, "Actual incoming damage recorded once")
	world._damage_player(19, Vector2.ZERO)
	verify(world.damage_events == 1, "Invulnerability does not create phantom damage events")
	world.health = world._max_health()
	verify(world.damage_taken == 19, "Healing never erases damage history")
	world._loadout.weapons.brush = 2
	world._loadout.weapons.saw = 2
	world._emit_stats()
	world._loadout.weapons.saw = 0
	verify("steel_storm" in world.get_stats().evolutions_seen, "Past evolved builds survive subsequent equipment changes")
	var maps: Array[String] = []
	var patterns: Array[String] = []
	var checkpoint: Dictionary = {}
	for room: int in range(1, 10):
		verify(world.wave_index == room and world.phase == "combat", "Room %d is reachable" % room)
		if world.map_id not in maps:
			maps.append(world.map_id)
		if world._overtime.pattern() not in patterns:
			patterns.append(world._overtime.pattern())
		world.elapsed += 65.0
		world.wave_elapsed = world._current_wave_duration()
		if room % 3 == 0:
			verify(not world._boss.is_empty(), "Room %d has its sector boss" % room)
			world._damage_enemy(world._boss, 1000000, Vector2.ZERO, "test")
		world._complete_wave()
		verify(world.phase == "shop" and world._overtime.completed == room, "Room %d transitions to a shop" % room)
		var t: float = world.elapsed
		var charge: float = world._ability.charge
		for frame: int in range(120):
			world._physics_process(0.05)
		verify(world.elapsed == t and world._ability.charge == charge, "Shop %d does not advance clocks or recharge" % room)
		verify(world.get_stats().can_extract == (room % 3 == 0), "Extraction gated to boss checkpoints")
		verify(not world.start_next_wave(), "Unchosen route blocks advance")
		checkpoint = JSON.parse_string(JSON.stringify(world.create_checkpoint()))
		var clone: Node2D = make_world()
		verify(clone.restore_checkpoint(checkpoint), "JSON checkpoint room %d restores" % room)
		verify(JSON.stringify(clone.get_shop_offers()) == JSON.stringify(world.get_shop_offers()) and JSON.stringify(clone._overtime.routes) == JSON.stringify(world._overtime.routes), "Offers and route cards persist exactly")
		verify(clone.damage_taken == world.damage_taken and clone.evolutions_seen == world.evolutions_seen, "Combat metrics round-trip")
		verify(world.choose_overtime_route(1), "Can accept one route")
		verify(not world.choose_overtime_route(0), "Cannot reroll reward by selecting twice")
		verify(clone.choose_overtime_route(1), "Restored checkpoint accepts same route")
		verify(JSON.stringify(clone._overtime.export_state()) == JSON.stringify(world._overtime.export_state()), "Route choice deterministic after restore")
		if room < 9:
			verify(world.start_next_wave() and clone.start_next_wave(), "Both routes launch")
			verify(world._rng.state == clone._rng.state and world.map_id == clone.map_id, "Gameplay RNG and map agree after resume")
		clone.queue_free()
	verify(maps == ["yard", "foundry", "reactor"], "Three sectors rotate across cycles")
	verify(patterns.size() == 5, "All four objective types and bosses appear")
	var bad: Dictionary = checkpoint.duplicate(true)
	bad.damage_events = 0.5
	verify(not world.restore_checkpoint(bad), "Reject fractional damage event count")
	bad = checkpoint.duplicate(true)
	bad.overtime.risk_history.append(bad.overtime.risk_history[0])
	verify(not world.restore_checkpoint(bad), "Reject duplicate risk history")
	bad = checkpoint.duplicate(true)
	bad.boss_kills = 0
	verify(not world.restore_checkpoint(bad), "Reject contradictory boss progression")
	verify(world.extract_overtime() and not world.active, "Boss checkpoint extracts and finishes")
	var profile: RefCounted = Profile.new("user://overtime-suite-%d.json" % OS.get_process_id())
	var reward: Dictionary = profile.settle("overtime-run-a", world.get_stats(), true)
	verify(reward.ok and reward.coins > 0, "Actual world stats settle successfully")
	verify(profile.data.history.back().rooms == 9 and profile.data.history.back().mode == "endless", "History records nine rooms as endless")
	var coins: int = profile.data.coins
	profile.settle("overtime-run-a", world.get_stats(), true)
	verify(profile.data.coins == coins and profile.data.history.size() == 1, "No duplicated payouts or history")
	verify(not profile.data.achievements.has("untouchable"), "Endless cannot counterfeit standard no-hit achievement")
	# Standard envelope v1 checkpoints from before metrics remain playable but untracked.
	world.start_standard("yard", 22)
	world._complete_wave()
	var legacy: Dictionary = world.create_checkpoint()
	for id: String in ["endless_mode", "overtime", "metrics_known", "damage_taken", "damage_events", "boss_damage_taken", "boss_kills", "evolutions_seen", "arsenal"]:
		legacy.erase(id)
	verify(world.restore_checkpoint(legacy) and not world.metrics_known and not world.endless_mode, "Legacy standard checkpoint imports without invented no-hit evidence")
	# Every reward has a real in-world effect and bounded pressure.
	world.start_endless("reactor", 443)
	for id: String in Overtime.BOONS:
		world._overtime.boons[id] = 5
	world._refresh_modifiers()
	verify(world._max_energy() > 100 and world._vacuum_range() > 240, "Capacity and reach boons change actual stats")
	world._overtime.last_uses = 0
	world._ability.uses = 1
	world._overtime.tick(world, 0.01)
	verify(world._overtime.shield > 0, "Skill casts grant shield boon")
	world._invulnerability = 0
	world._damage_player(12, Vector2.ZERO)
	verify(world.damage_taken == 0 and world._overtime.shield == 0, "Shield blocks exactly one real hit")
	world._dash_left = 0.1
	world._overtime.tick(world, 0.01)
	verify(world._foam.size() == 1 and world._foam[0].damage > 0, "Dash boon leaves actual damaging slow field")
	world._dash_left = 0.0
	world.health = 50
	world._collect_scrap(1)
	verify(world.health > 50, "Salvager heals actual field pickup")
	world._overtime.risk = "volatile"
	world.debug_spawn_enemy(Vector2(850, 550), 0)
	var enemy: Dictionary = world._enemies.back()
	world._damage_enemy(enemy, 10000, Vector2.ZERO)
	verify(world._director.hazards.size() == 1 and world._director.hazards[0].warning >= 1, "Volatile death has visible warning before damage")
	world._overtime.room = 2400
	verify(world._overtime.speed_scale() <= 1.6 and world._overtime.damage_scale() <= 2.4, "Late pressure has explicit speed and damage bounds")
	print("OVERTIME_TESTS ", JSON.stringify({"checks": checks, "failures": failures}))
	world.queue_free()
	await process_frame
	await root.get_node("SoundBank").shutdown()
	quit(0 if failures.is_empty() else 1)
