extends "res://tests/probe_v05_arsenal.gd"
## Input-only expedition probe. No grants, direct damage, deleted enemies or skipped combat.
var maximum_room: int = 6


func _run() -> void:
	maximum_seconds = 1200.0
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--maps="):
			maps.clear()
			for value: String in argument.trim_prefix("--maps=").split(","):
				maps.append(value)
		elif argument.begins_with("--seeds="):
			seeds.clear()
			for value: String in argument.trim_prefix("--seeds=").split(","):
				seeds.append(value.to_int())
		elif argument.begins_with("--max-seconds="):
			maximum_seconds = clampf(argument.trim_prefix("--max-seconds=").to_float(), 1.0, 1200.0)
	for action: String in ["move_left", "move_right", "move_up", "move_down", "vacuum", "dash", "active_skill"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	Input.use_accumulated_input = false
	for id: String in maps:
		current_map = id
		for seed_value: int in seeds:
			await _expedition(seed_value)
	var report: Dictionary = {
		"method": "Fixed 60 Hz real input and normal shop/route APIs, pulse skill, seed 8102 by default; stop at room 6 extraction, actual death or 1200 combat seconds. No grants, direct damage, deleted targets, timer skipping or shop-duration recording.",
		"policy": "v05 new_tools movement and preferred pair for starting sector; fourth slot additionally accepts saw/arc/laser for yard/foundry/reactor. Normal purchases and one affordable paid reroll per shop. Low health prioritizes real repair cards. Route score prefers salvager, power, chain, bulwark and avoids armored/crossfire; relay objective uses ordinary movement and held vacuum. No later knowledge or future RNG inspection.",
		"limitations": "Three deterministic heuristic runs do not establish human difficulty, win rate, full endless balance or rendering performance. Immediate warning reactions and per-tick net HP loss may overstate reaction ability or understate damage repaired in the same tick. Failure samples are retained.",
		"runs": reports,
	}
	var file := FileAccess.open("res://artifacts/v05-overtime-probe.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("OVERTIME_PROBE ", JSON.stringify(report))
	await root.get_node("SoundBank").shutdown()
	await process_frame
	quit()


func _expedition(seed_value: int) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	root.add_child(viewport)
	var world: Node2D = World.new()
	viewport.add_child(world)
	world.set_physics_process(false)
	var ending: Dictionary = {"finished": false, "won": false}
	world.run_finished.connect(func(won: bool, _stats: Dictionary) -> void:
		ending.finished = true
		ending.won = won
	)
	support_observed = {"boss_adds_spawned": 0, "projections_destroyed": 0, "ability_uses": 0}
	_observed_counters = {"boss_breaks": 0, "interactions": 0, "elite_kills": 0}
	world.start_endless(current_map, seed_value, {"skill": "pulse"})
	var purchases: Array[Dictionary] = []
	var rooms: Array[Dictionary] = []
	var entries: Array[Dictionary] = []
	var routes: Array[Dictionary] = []
	var hurt_events: Array[Dictionary] = []
	var ticks: int = 0
	var recorded_room: int = 0
	var aim_verified: bool = false
	var minimum_health: float = world.health
	var net_hp_lost: float = 0.0
	var invalid_reason: String = ""
	var started: int = Time.get_ticks_msec()
	print("OVERTIME_START ", JSON.stringify({"map": current_map, "seed": seed_value}))
	while world.active and world.elapsed < maximum_seconds:
		if world.phase == "shop":
			var room_stats: Dictionary = world.get_stats()
			rooms.append({"room": world.wave_index, "map": world.map_id, "pattern": room_stats.overtime_pattern, "combat_seconds": snappedf(world.wave_elapsed, 0.01), "elapsed": snappedf(world.elapsed, 0.01), "health": world.health, "currency_before_shop": world.currency, "kills": world.kills, "recovered": world.total_scrap, "boss_kills": room_stats.boss_kills})
			if world.wave_index >= maximum_room:
				if not world.extract_overtime():
					invalid_reason = "legal room-six extraction rejected"
				break
			_buy(world, "new_tools", purchases)
			if world.currency >= int(world.get_stats().reroll_cost) + 30 and world.get_stats().can_reroll:
				var refresh: Dictionary = world.reroll_shop()
				if refresh.ok:
					purchases.append({"wave": world.wave_index, "id": "refresh", "level": 0, "cost": refresh.cost})
					_buy(world, "new_tools", purchases)
			var route_index: int = _route_index(world)
			var visible_routes: Array = world.get_stats().route_choices
			if route_index < 0 or not world.choose_overtime_route(route_index):
				invalid_reason = "visible route selection rejected"
				break
			routes.append({"after_room": world.wave_index, "chosen_index": route_index, "visible_choices": visible_routes})
			print("OVERTIME_ROOM ", JSON.stringify({"room": world.wave_index, "map": world.map_id, "health": world.health, "currency": world.currency, "loadout": world.get_stats().loadout, "route": visible_routes[route_index]}))
			_release_inputs()
			if not world.start_next_wave():
				invalid_reason = "selected route did not advance"
				break
		if world.wave_index != recorded_room:
			recorded_room = world.wave_index
			entries.append({"room": world.wave_index, "map": world.map_id, "pattern": world.get_stats().overtime_pattern, "health": world.health, "currency": world.currency, "loadout": world.get_stats().loadout, "boons": world.get_stats().boons, "boss_max_health": world._boss.get("max_hp", 0.0)})
		var controls: Dictionary = _choose_controls(world, "new_tools")
		if world._overtime.pattern() == "relay" and world._overtime.relays < 3:
			controls.move = _safe_direction(world, world._overtime.relay_position())
			controls.vacuum = not world._vacuum_gate
		_apply_controls(controls, viewport)
		var before: float = world.health
		world._physics_process(STEP)
		if ticks == 0:
			var expected: Vector2 = (Vector2(controls.aim) - world.player_position).normalized()
			aim_verified = world.player_aim.dot(expected) > 0.97
			if not aim_verified:
				invalid_reason = "mouse injection failed"
				break
		minimum_health = minf(minimum_health, world.health)
		var loss: float = maxf(0.0, before - world.health)
		net_hp_lost += loss
		if loss > 0.0:
			hurt_events.append({"time": snappedf(world.elapsed, 0.01), "room": world.wave_index, "map": world.map_id, "loss": snappedf(loss, 0.01), "boss_state": world._boss.get("state", ""), "source": world.last_damage_source})
		ticks += 1
		if ticks % 30 == 0:
			await process_frame
	var stats: Dictionary = world.get_stats()
	var spent: int = 0
	for item: Dictionary in purchases:
		spent += int(item.cost)
	var report: Dictionary = {
		"start_map": current_map, "seed": seed_value, "strategy": "new_tools", "aim_input_verified": aim_verified,
		"outcome": "invalid_probe" if not invalid_reason.is_empty() else (("extracted_room_6" if ending.won else "lost") if ending.finished else "combat_time_limit"), "invalid_reason": invalid_reason,
		"room_reached": world.wave_index, "rooms_completed": stats.rooms_completed, "boss_kills": stats.boss_kills, "last_map": world.map_id,
		"combat_seconds": snappedf(world.elapsed, 0.01), "last_room_seconds": snappedf(world.wave_elapsed, 0.01), "health": snappedf(world.health, 0.01), "minimum_health": snappedf(minimum_health, 0.01), "positive_net_hp_lost": snappedf(net_hp_lost, 0.01),
		"boss_health_remaining": stats.boss_health, "kills": world.kills, "recovered": world.total_scrap, "discharges": world.shots, "total_income": world._earned_currency, "spent": spent, "wallet": world.currency, "loadout": stats.loadout, "boons": stats.boons,
		"damage_by_source": stats.damage_by_source, "purchases": purchases, "routes": routes, "room_entries": entries, "completed_rooms": rooms, "hurt_events": hurt_events, "ticks": ticks, "probe_wall_ms": Time.get_ticks_msec() - started,
	}
	report.merge(support_observed, true)
	report.merge(_observed_counters, true)
	reports.append(report)
	print("OVERTIME_RESULT ", JSON.stringify(report))
	_release_inputs()
	viewport.queue_free()
	await process_frame


func _item_priority(id: String, level: int, strategy: String, world: Node2D) -> float:
	if id == "repair":
		return 250.0 if world.health < world._max_health() - 25.0 else -1.0
	var additional: String = "saw" if current_map == "yard" else ("arc" if current_map == "foundry" else "laser")
	if id == additional:
		return 80.0 if level == 1 else 55.0
	return super._item_priority(id, level, strategy, world)


func _route_index(world: Node2D) -> int:
	var choices: Array = world.get_stats().route_choices
	var boon_scores: Dictionary = {"salvager": 100.0, "power": 85.0, "chain": 80.0, "bulwark": 75.0, "haste": 70.0, "afterburn": 65.0, "magnet": 55.0, "capacitor": 50.0}
	var risk_scores: Dictionary = {"hunters": -5.0, "overclock": -10.0, "volatile": -12.0, "artillery": -15.0, "crossfire": -25.0, "armored": -35.0}
	var best: int = -1
	var best_score: float = -INF
	for index: int in range(choices.size()):
		var score: float = float(boon_scores.get(choices[index].boon, 0.0)) + float(risk_scores.get(choices[index].risk, 0.0))
		if score > best_score:
			best = index
			best_score = score
	return best
