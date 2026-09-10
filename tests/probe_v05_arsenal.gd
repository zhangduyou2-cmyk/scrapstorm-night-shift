extends "res://tests/probe_v04_mechanics.gd"
## Normal input and ordinary purchases only; failed runs remain in the report.
const Catalog = preload("res://scripts/game/run_loadout.gd")
var support_observed: Dictionary = {}


func _run() -> void:
	strategies = ["combo", "new_tools"]
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--strategies="):
			strategies.clear()
			for value: String in argument.trim_prefix("--strategies=").split(","):
				strategies.append(value)
		elif argument.begins_with("--maps="):
			maps.clear()
			for value: String in argument.trim_prefix("--maps=").split(","):
				maps.append(value)
		elif argument.begins_with("--seeds="):
			seeds.clear()
			for value: String in argument.trim_prefix("--seeds=").split(","):
				seeds.append(value.to_int())
		elif argument.begins_with("--max-seconds="):
			maximum_seconds = maxf(1.0, argument.trim_prefix("--max-seconds=").to_float())
	for action: String in ["move_left", "move_right", "move_up", "move_down", "vacuum", "dash", "active_skill"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	Input.use_accumulated_input = false
	for id: String in maps:
		current_map = id
		for seed_value: int in seeds:
			for strategy: String in strategies:
				await _simulate(seed_value, strategy)
	var report: Dictionary = {"method": "Fixed 60 Hz ordinary movement/mouse/vacuum/skill input with normal purchases and paid rerolls. No stat grants, direct damage, target deletion, skipped combat or shop-duration recording.",
		"policies": {"combo": "Legacy combo movement/purchase policy operating against the new eight-tool catalog.", "new_tools": "Visible counter/long-charge-corridor and projection-aware input. Preferred normal purchases: yard laser+arc; foundry drone+foam; reactor missile+mines. New pairs are not granted and RNG may prevent completion."},
		"limitations": "One deterministic heuristic seed, immediate responses to observed warnings; not human difficulty approval, win rate or rendering performance.", "runs": reports}
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var output := FileAccess.open("res://artifacts/v05-arsenal-probe.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "  "))
	output.close()
	print("V05_ARSENAL_PROBE ", JSON.stringify(report))
	await root.get_node("SoundBank").shutdown()
	await process_frame
	quit()


func _simulate(seed_value: int, strategy: String) -> void:
	support_observed = {"boss_adds_spawned": 0, "projections_destroyed": 0, "ability_uses": 0}
	await super._simulate(seed_value, strategy)
	reports.back().merge(support_observed, true)


func _item_priority(id: String, level: int, strategy: String, world: Node2D) -> float:
	if strategy != "new_tools":
		return super._item_priority(id, level, strategy, world)
	var pair: Array = ["laser", "arc"] if current_map == "yard" else (["drone", "foam"] if current_map == "foundry" else ["missile", "mines"])
	if id in pair:
		return 200.0 if level == 1 else (145.0 if level == 2 else 110.0)
	if id in Catalog.WEAPON_IDS and id != "brush":
		return -1.0
	if id == "brush":
		return 60.0
	return super._item_priority(id, level, "combo", world)


func _choose_controls(world: Node2D, strategy: String) -> Dictionary:
	var stats: Dictionary = world.get_stats()
	support_observed.boss_adds_spawned = int(stats.get("boss_adds_spawned", 0))
	support_observed.projections_destroyed = int(stats.get("projections_destroyed", 0))
	support_observed.ability_uses = int(stats.get("ability_uses", world._ability.uses))
	var controls: Dictionary = super._choose_controls(world, "counter" if strategy == "new_tools" else strategy)
	if strategy != "new_tools":
		return controls
	if not world._boss.is_empty() and str(world._boss.state) in ["windup", "charge"]:
		controls.move = _safe_direction(world, world.player_position + Vector2(controls.move) * 160.0)
	for target: Dictionary in world._director.encounters.targets:
		if str(target.kind) != "projection" or bool(target.settled):
			continue
		var distance: float = world.player_position.distance_to(target.pos)
		if distance < 230.0 and (world.energy >= 30.0 or str(stats.get("ability_state", "")) == "ready"):
			controls.aim = target.pos
			controls.vacuum = not (world._vacuum and world.energy >= 30.0) and not world._vacuum_gate
			controls.ability = distance < 160.0 and str(stats.get("ability_state", "")) == "ready"
			break
	return controls
