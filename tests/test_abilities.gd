extends SceneTree
## v0.4 independently charged skills, actual pull, branches and checkpoint migrations.
const World = preload("res://scripts/game/game_world.gd")
const Ability = preload("res://scripts/game/player_ability.gd")
var checks: int = 0
var failures: Array[String] = []
var world: Node2D

func _initialize() -> void:
	_run.call_deferred()

func verify(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)

func fresh(skill: String = "pulse") -> RefCounted:
	world.start_standard("yard", 4827, {"skill": skill, "skin": "arctic", "skill_color": "violet"})
	world._enemies.clear()
	world._scraps.clear()
	world._projectiles.clear()
	world.energy = 0.0
	world.currency = 42
	world._spawn_timer = 999.0
	return world._ability

func enemy(at: Vector2, kind: int = 0, spawn: float = 0.0) -> Dictionary:
	world.debug_spawn_enemy(at, kind)
	var result: Dictionary = world._enemies.back()
	result.spawn = spawn
	result.hp = 150.0
	result.max_hp = 150.0
	return result

func _run() -> void:
	world = World.new()
	root.add_child(world)
	world.set_physics_process(false)
	for id: String in ["pulse", "singularity", "overdrive"]:
		var a: RefCounted = fresh(id)
		verify(a.charge == 100.0 and a.get_stats().ability_state == "ready", id + " starts ready for the first encounter")
		verify(a.activate(world) and world.energy == 0.0 and world.currency == 42, id + " needs neither discharge energy nor currency")
		verify(a.charge == 0.0 and a.cooldown == 0.0 and a.uses == 1 and a.get_stats().ability_state == "active", id + " spends independent charge with no second long cooldown")
		verify(not a.activate(world) and a.uses == 1, id + " cannot reactivate while active")
		var before: Dictionary = a.get_stats()
		world.set_paused(true)
		a.tick(world, 2.0)
		verify(not a.activate(world) and a.get_stats() == before, id + " freezes active duration during pause")
		world.set_paused(false)
		world.phase = "shop"
		a.tick(world, 2.0)
		verify(not a.activate(world) and a.get_stats() == before, id + " cannot tick or cast in shop")
		world.phase = "combat"
		a.clear_effects()
		a.tick(world, 100.0)
		verify(a.charge == 0.0 and a.get_stats().ability_state == "charging", id + " cannot passively recharge by waiting")
		verify(not a.activate(world), id + " rejects an empty independent charge")
		verify(a.gain_scrap_charge(-4) == 0.0 and a.gain_scrap_charge(10) == 30.0, id + " rewards only positive recovered scrap")
		verify(a.gain_scrap_charge(1000) == 70.0 and a.charge == 100.0, id + " charge clamps at one activation")
		verify(a.activate(world) and a.uses == 2, id + " can cast after collecting enough scrap")
		world.active = false
		verify(not a.activate(world), id + " rejects inactive world")
	var a: RefCounted = fresh()
	a.activate(world)
	a.clear_effects()
	verify(a.gain_boss_charge(1000.0, "ability") == 0.0 and a.gain_boss_charge(1000.0, "ability_echo") == 0.0, "Active-skill damage never recharges itself")
	verify(a.gain_boss_charge(INF, "arc") == 0.0 and a.gain_boss_charge(-10.0, "brush") == 0.0, "Invalid damage cannot grant charge")
	verify(a.gain_boss_charge(1000.0, "arc") == 6.0 and a.gain_boss_charge(1000.0, "brush") == 0.0, "Boss recharge has a shared six-point burst budget")
	a.tick(world, 0.5)
	verify(a.gain_boss_charge(1000.0, "blast") == 3.0, "Boss damage replenishes its budget at six points per combat second")
	world.set_paused(true)
	a.tick(world, 100.0)
	verify(a.gain_boss_charge(1000.0, "arc") == 0.0, "Pause cannot refill the boss recharge budget")
	world.set_paused(false)
	a = fresh()
	a.activate(world)
	a.clear_effects()
	world._collect_scrap(3)
	verify(a.charge == 9.0 and world.energy == 27.0 and world.currency == 45, "Actual scrap settlement independently supplies charge, discharge energy and currency")
	a = fresh()
	a.activate(world)
	a.clear_effects()
	world._spawn_boss()
	world._boss.spawn = 0.0
	# Entry now readies the skill; isolate subsequent damage-based recharge.
	a.charge = 0.0
	world._damage_enemy(world._boss, 100.0, Vector2.ZERO, "ability")
	verify(a.charge == 0.0, "World boss damage integration excludes active skill hits from recharge")
	world._damage_enemy(world._boss, 100.0, Vector2.ZERO, "brush")
	verify(a.charge > 0.0 and a.charge <= 6.0, "Actual post-armor ordinary boss damage recharges within the shared cap")

	a = fresh()
	var inside: Dictionary = enemy(world.player_position + Vector2(90.0, 0.0))
	var outside: Dictionary = enemy(world.player_position + Vector2(230.0, 0.0))
	var protected: Dictionary = enemy(world.player_position + Vector2(0.0, 80.0), 0, 0.3)
	world._loadout.mods.torque = 3
	world._modifiers = world._loadout.get_modifiers()
	world._fire_projectile(world.player_position + Vector2(70, 0), Vector2.LEFT, 10.0, false)
	world._fire_projectile(world.player_position + Vector2(260, 0), Vector2.LEFT, 10.0, false)
	a.activate(world)
	verify(is_equal_approx(150.0 - float(inside.hp), 30.0 * 1.36) and float(inside.knock.length()) > 500.0, "Pulse applies the common damage multiplier and meaningful displacement")
	verify(outside.hp == 150.0 and protected.hp == 150.0, "Pulse respects radius and spawn protection")
	verify(world._projectiles.size() == 1 and world._projectiles[0].pos.distance_to(world.player_position) > 205.0, "Pulse clears nearby bullets without deleting distant threats")
	verify(is_equal_approx(float(world.damage_by_source.get("ability", 0.0)), 30.0 * 1.36), "Skill results record actual inflicted damage once")
	a = fresh()
	world.player_position = Vector2(210, 264)
	var blocked: Dictionary = enemy(Vector2(325, 264))
	a.activate(world)
	verify(blocked.hp == 150.0, "Pulse cannot attack through a solid yard crate")
	a = fresh("singularity")
	world.aim_position = world.player_position + Vector2(80, 10)
	verify(a.get_cast_position(world).is_equal_approx(world.aim_position), "Singularity can place at a nearer mouse target, not only maximum range")
	world.aim_position = world.player_position + Vector2(500, 0)
	verify(is_equal_approx(a.get_cast_position(world).distance_to(world.player_position), 260.0), "Far mouse targets clamp to the visible 260-unit cast range")

	a = fresh("singularity")
	world.player_position = Vector2(115, 264)
	world.player_aim = Vector2.RIGHT
	var preview: Vector2 = a.get_cast_position(world)
	a.activate(world)
	verify(a.center == preview and world._line_clear(world.player_position, a.center), "Singularity preview and placement share the same collision-limited point")
	a = fresh("singularity")
	world.player_position = Vector2(640, 390)
	world.player_aim = Vector2.RIGHT
	a.activate(world)
	var pulled: Dictionary = enemy(a.center + Vector2(-150, 0))
	var original_distance: float = Vector2(pulled.pos).distance_to(a.center)
	world.debug_add_scrap(a.center + Vector2(-100, 0), 2)
	for i: int in range(30):
		a.tick(world, 1.0 / 60.0)
		world._update_enemies(1.0 / 60.0)
	verify(Vector2(pulled.pos).distance_to(a.center) < original_distance - 45.0, "Half a second of real enemy movement confirms suction beats chase and knock decay")
	verify(world._scraps[0].pos.distance_to(a.center) < 100.0 and world.currency == 42, "Suction moves scrap through collision without awarding it twice")
	a.tick(world, 1.01)
	var hp_after: float = pulled.hp
	verify(a.duration == 0.0 and hp_after < 150.0, "Singularity collapses at its actual collected target position")
	a.tick(world, 1.0)
	verify(pulled.hp == hp_after, "A completed collapse cannot apply its burst twice")
	a = fresh("overdrive")
	world._dash_cooldown = 1.2
	a.activate(world)
	verify(world._dash_cooldown == 0.0 and a.tool_speed_scale() > 1.0 and a.move_speed_scale() > 1.0 and a.duration == 5.0, "Overdrive exposes actual tool acceleration and mobility during its five-second active state")
	world._brush_timer = 1.0
	world._foam_timer = 1.0
	world._arc_timer = 1.0
	world._update_brush(0.2)
	world._update_tools(0.2)
	verify(is_equal_approx(world._brush_timer, 0.69) and is_equal_approx(world._foam_timer, 0.69) and is_equal_approx(world._arc_timer, 0.69), "Overdrive actually advances equipped-tool firing clocks faster in the world")

	var victim: Dictionary = enemy(world.player_position + Vector2(90, 0))
	a.tick(world, 1.0 / 60.0)
	verify(victim.hp == 139.0, "Overdrive adds damaging mobile arcs")
	world.player_position += Vector2(15, 20)
	a.tick(world, 1.0 / 60.0)
	verify(a.center == world.player_position, "Overdrive's damage and visual center follow player motion")
	a.clear_effects()
	verify(a.tool_speed_scale() == 1.0 and a.move_speed_scale() == 1.0, "Clearing effects removes every temporary operation modifier")
	for id: String in ["pulse", "singularity", "overdrive"]:
		a = fresh(id)
		var options: Array[Dictionary] = a.get_branch_options(2)
		verify(options.size() == 2 and options[0].available and options[1].available, id + " offers two exclusive branches at shop two")
		verify(not a.choose_branch(options[0].id, 1).ok, id + " rejects a branch before its milestone")
		verify(a.choose_branch(options[0].id, 2).ok and a.branch_rank == 1, id + " selects one direction at shop two")
		verify(not a.choose_branch(options[1].id, 2).ok and not a.choose_branch(options[1].id, 4).ok, id + " cannot switch directions or double-spend a milestone")
		verify(a.choose_branch(options[0].id, 4).ok and a.branch_rank == 2, id + " strengthens the selected branch at shop four")
		verify(not a.choose_branch(options[0].id, 4).ok, id + " cannot repeatedly strengthen from reloaded UI")
		var restored: RefCounted = Ability.new()
		verify(restored.import_state(JSON.parse_string(JSON.stringify(a.export_state()))) and restored.export_state() == a.export_state(), id + " retains branch choices and charge through JSON")
	a = fresh("overdrive")
	verify(a.choose_branch("overdrive_stride", 4).ok and not a.choose_branch("overdrive_stride", 2).ok, "Skipping shop two permits a late first choice but rejects retroactive strengthening")

	a = fresh()
	a.choose_branch("pulse_bulwark", 2)
	a.activate(world)
	world._fire_projectile(world.player_position + Vector2(60, 0), Vector2.LEFT, 10.0, false)
	a.tick(world, 0.2)
	verify(world._projectiles.is_empty() and a.duration > 1.0, "Bulwark branch actively intercepts newly arriving bullets")
	a = fresh()
	a.choose_branch("pulse_echo", 2)
	a.choose_branch("pulse_echo", 4)
	a.activate(world)
	var echo_target: Dictionary = enemy(world.player_position + Vector2(100, 0))
	a.tick(world, 0.61)
	a.tick(world, 0.56)
	verify(echo_target.hp == 106.0, "Strengthened echo branch produces two distinct delayed waves")
	a = fresh("singularity")
	a.choose_branch("singularity_rupture", 2)
	a.activate(world)
	a.tick(world, 1.51)
	var aftershock: Dictionary = enemy(a.center + Vector2(-240, 0))
	a.tick(world, 0.46)
	verify(aftershock.hp == 100.0, "Rupture creates a second larger delayed collapse after the first burst")
	a = fresh("overdrive")
	a.choose_branch("overdrive_stride", 2)
	a.activate(world)
	var trail_enemy: Dictionary = enemy(world.player_position + Vector2(10, 0))
	world.player_position += Vector2(80, 0)
	a.tick(world, 0.02)
	verify(trail_enemy.hp < 139.0 and not a._trails.is_empty(), "Stride leaves a damaging trail at the previous position")
	a = fresh("singularity")
	a.activate(world)
	a.gain_scrap_charge(7)
	world._complete_wave()
	var checkpoint: Dictionary = world.create_checkpoint()
	verify(a.duration == 0.0 and checkpoint.ability.charge == 21.0, "Shop cleanup cancels effects without refunding charge")
	verify(world.restore_checkpoint(checkpoint) and world._ability.charge == 21.0 and world._ability.duration == 0.0, "Actual world checkpoint restores charge without resurrecting an effect")
	var restored: RefCounted = Ability.new()
	verify(restored.import_state({"skill":"pulse","skin":"industrial","skill_color":"mint","cooldown":4.0,"uses":2}) and restored.charge == 50.0 and restored.branch.is_empty(), "v0.3 remaining cooldown migrates to equivalent independent charge")
	var saved: Dictionary = restored.export_state()
	for field: String in ["charge", "uses", "boss_charge_budget", "branch_rank", "cooldown"]:
		var bad: Dictionary = saved.duplicate(true)
		bad[field] = NAN
		verify(not restored.import_state(bad) and restored.export_state() == saved, "Invalid " + field + " rejects atomically")
	var wrong: Dictionary = saved.duplicate(true)
	wrong.branch = "singularity_vortex"
	wrong.branch_rank = 1
	wrong.branch_waves = [2]
	verify(not restored.import_state(wrong), "Checkpoint cannot select another skill's branch")
	wrong = saved.duplicate(true)
	wrong.version = 1.5
	verify(not restored.import_state(wrong), "Fractional schema versions cannot bypass validation")
	a = fresh()
	world.health = 0.0
	verify(not a.activate(world) and a.charge == 100.0, "Dead players cannot consume charge before terminal transition")
	if not InputMap.has_action("active_skill"):
		InputMap.add_action("active_skill")
	a = fresh()
	Input.action_press("active_skill")
	a.tick(world, 0.01)
	verify(a.uses == 0, "A held key on entering the scene cannot automatically fire")
	Input.action_release("active_skill")
	a.tick(world, 0.01)
	await process_frame
	Input.action_press("active_skill")
	a.tick(world, 0.01)
	verify(a.uses == 1 and world.energy == 0.0, "A new press fires the independent ready charge without energy")
	world.set_paused(true)
	a.tick(world, 20.0)
	world.set_paused(false)
	a.gain_scrap_charge(100)
	a.tick(world, 20.0)
	verify(a.uses == 1, "Holding a key across pause cannot auto-fire even if charge is ready")
	Input.action_release("active_skill")
	world.queue_free()
	await process_frame
	print("ABILITY_TEST ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
