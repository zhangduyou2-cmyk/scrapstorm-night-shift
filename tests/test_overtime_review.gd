extends SceneTree
## Targeted final review fixtures, including same-frame input and resource effects.
const World = preload("res://scripts/game/game_world.gd")
var checks: int = 0
var failures: Array[String] = []
func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	if "--test-settings" not in OS.get_cmdline_user_args():
		quit(1)
		return
	for id: String in ["active_skill", "move_left", "move_right", "move_up", "move_down", "vacuum", "dash"]:
		if not InputMap.has_action(id):
			InputMap.add_action(id)
	await process_frame
	root.get_node("Settings").effects_enabled = false
	var world := World.new()
	root.add_child(world)
	world.set_physics_process(false)
	world.start_endless("yard", 55723, {"skill":"overdrive"})
	world._obstacles.clear()
	world._director.clear_stage()
	world._enemies.clear()
	world._spawn_timer = 1000
	world._overtime.boons.bulwark = 1
	world._invulnerability = 0
	world.health = 50
	world._ability.tick(world, 0)
	world._projectiles.append({"pos":world.player_position,"vel":Vector2.ZERO,"life":2.0,"radius":6.0,"damage":12.0,"boss":false})
	Input.action_press("active_skill")
	world._physics_process(1.0/60.0)
	Input.action_release("active_skill")
	verify(world._ability.uses == 1, "Actual skill input activates in tested physics frame")
	verify(world.health == 50 and world.damage_taken == 0, "Cast shield blocks the hit on its activation frame")
	world._overtime.tick(world, 1.0/60.0)
	verify(world._overtime.shield == 0, "Consumed activation shield is not granted again on the next tick")
	world._invulnerability = 0
	world._damage_player(12, Vector2.ZERO)
	verify(world._overtime.shield == 0, "One hit consumes the cast shield")
	world.start_endless("yard", 55724)
	world._overtime.boons.salvager = 5
	world.health = 0
	world.total_scrap = 24
	world._last_health_milestone = 0
	world._collect_scrap(1)
	verify(world.health == 0, "Neither salvager nor threshold healing resurrect a dead player")
	world.health = 50
	world.total_scrap = 0
	world._last_health_milestone = 0
	world._collect_scrap(1)
	verify(is_equal_approx(world.health, 50.7), "Salvager rank five restores exactly 0.7 hull per field scrap")
	world.phase = "shop"
	world._collect_scrap(1)
	verify(is_equal_approx(world.health, 50.7), "Salvager does not heal during shop")
	world.phase = "combat"
	for id: String in ["power", "magnet", "capacitor", "haste"]:
		world._overtime.boons[id] = 2
	world._refresh_modifiers()
	var modifiers: Dictionary = world._modifiers.duplicate(true)
	world._refresh_modifiers()
	world._refresh_modifiers()
	verify(world._modifiers == modifiers, "Refreshing modifiers always derives from loadout without double stacking")
	verify(is_equal_approx(float(modifiers.damage_scale), 1.2) and is_equal_approx(float(modifiers.vacuum_scale), 1.16), "Damage and vacuum boon ranks match their descriptions")
	verify(is_equal_approx(float(modifiers.energy_scale), 1.2) and is_equal_approx(float(modifiers.cooldown_scale), 0.91), "Capacity and cooldown boon ranks match their descriptions")
	world.wave_elapsed = world._current_wave_duration()
	world._complete_wave()
	var selected: int = 0
	var old_history: Array = world._overtime.risk_history.duplicate()
	verify(world.choose_overtime_route(selected), "One route can be chosen at the shop")
	var chosen_modifiers: Dictionary = world._modifiers.duplicate(true)
	verify(world._overtime.risk_history == old_history, "Choosing next risk does not falsely record it as already played")
	var checkpoint: Dictionary = world.create_checkpoint()
	verify(world.restore_checkpoint(JSON.parse_string(JSON.stringify(checkpoint))), "Chosen route restores from actual JSON types")
	verify(world._modifiers == chosen_modifiers, "Checkpoint restore does not apply boon twice")
	verify(not world.choose_overtime_route(1) and world._modifiers == chosen_modifiers, "Restored chosen route cannot be replaced for an extra boon")
	verify(world.start_next_wave(), "Chosen route launches next room")
	verify(world._overtime.risk in world._overtime.risk_history, "Risk is recorded once when next combat actually begins")
	verify(world._modifiers == chosen_modifiers, "Next room does not compound player boon modifiers")
	var n: int = world._overtime.risk_history.size()
	world._overtime.begin(world)
	verify(world._overtime.risk_history.size() == n, "Repeated room setup never duplicates encountered risk")
	world.start_endless("yard", 55725)
	world._obstacles.clear()
	world._director.clear_stage()
	world._enemies.clear()
	world._overtime.boons.afterburn = 2
	world._dash_left = 0.1
	world._overtime.tick(world, 0.01)
	verify(world._foam.size() == 1 and is_equal_approx(world._foam[0].radius, 62.0) and is_equal_approx(world._foam[0].damage, 9.0) and is_equal_approx(world._foam[0].life, 3.3), "Dash residue rank two changes real foam radius damage and lifetime")
	verify(world._is_foamed(world.player_position), "Dash residue participates in the real enemy slow query")
	world._foam.clear()
	world._dash_left = 0
	world._overtime.boons.chain = 2
	world._overtime.chain_timer = 0
	for at: Vector2 in [Vector2(730,400),Vector2(500,400),Vector2(640,500),Vector2(640,300)]:
		world.debug_spawn_enemy(at, 0)
		world._enemies.back().spawn = 0
	world.player_position = Vector2(640,400)
	world._obstacles.append(Rect2(680,375,20,50))
	var blocked_hp: float = world._enemies[0].hp
	var visible_hp: float = world._enemies[1].hp
	world._overtime.tick(world, 0.01)
	verify(world._enemies[0].hp == blocked_hp and world._enemies[1].hp == visible_hp - 16.0, "Arc satellite respects walls and deals the documented rank-scaled damage")
	verify(world._arcs.size() == 3 and is_equal_approx(world._overtime.chain_timer, 3.0), "Arc satellite hits at most three visible targets with rank-scaled interval")
	world.queue_free()
	await process_frame
	await root.get_node("SoundBank").shutdown()
	print("OVERTIME_REVIEW_TEST ", JSON.stringify({"checks":checks,"failures":failures,"fixture":true}))
	quit(0 if failures.is_empty() else 1)
