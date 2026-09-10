extends "res://tests/probe_v04_mechanics.gd"
## ISOLATED EARLY OVERTIME BOSS FIXTURE, not a normally purchased full run.
## Establishes room 3 + two early tools. All combat uses real input and world ticks.
## Never edits health, enemy health, invulnerability, energy, skill charge or clocks.
## Run only after B integration: Godot --headless --path . --script
## res://tests/probe_boss_counter_b.gd -- --test-settings --label=b-integrated

const BUILDS: Dictionary = {
	"melee": {"brush": 2, "saw": 1},
	"ranged": {"brush": 1, "arc": 2},
}
const B_EVENT_LIMIT: int = 2500
var b_builds: Array[String] = ["melee", "ranged"]
var b_label: String = "b-initial"
var b_path: String = ""
var b_report: Dictionary = {}
var b_failures: Array[String] = []


func _run() -> void:
	if "--test-settings" not in OS.get_cmdline_user_args():
		push_error("Isolated settings required. No boss probe ran.")
		quit(1)
		return
	maximum_seconds = 240.0
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--maps="):
			maps.clear()
			for value: String in argument.trim_prefix("--maps=").split(","):
				if value not in ["yard", "foundry", "reactor"]:
					b_failures.append("Unknown map: " + value)
				maps.append(value)
		elif argument.begins_with("--builds="):
			b_builds.clear()
			for value: String in argument.trim_prefix("--builds=").split(","):
				if not BUILDS.has(value):
					b_failures.append("Unknown build: " + value)
				b_builds.append(value)
		elif argument.begins_with("--seeds="):
			seeds.clear()
			for value: String in argument.trim_prefix("--seeds=").split(","):
				if not value.is_valid_int():
					b_failures.append("Seed is not an integer")
				seeds.append(value.to_int())
		elif argument.begins_with("--max-seconds="):
			var value: String = argument.trim_prefix("--max-seconds=")
			if not value.is_valid_float() or not is_finite(value.to_float()) or value.to_float() < 1.0 or value.to_float() > 600.0:
				b_failures.append("Max seconds must be finite and between 1 and 600")
			else:
				maximum_seconds = value.to_float()
		elif argument.begins_with("--label="):
			b_label = argument.trim_prefix("--label=")
	var pattern := RegEx.new()
	pattern.compile("^[a-z0-9_-]+$")
	if pattern.search(b_label) == null:
		b_failures.append("Use a lowercase alphanumeric/hyphen/underscore label")
	b_path = "res://artifacts/boss-counter-" + b_label + ".json"
	if FileAccess.file_exists(b_path):
		b_failures.append("Report already exists; use a new --label to retain previous wins and losses")
	if not b_failures.is_empty():
		push_error(JSON.stringify(b_failures))
		quit(1)
		return
	for action: String in ["move_left", "move_right", "move_up", "move_down", "vacuum", "dash", "active_skill"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	Input.use_accumulated_input = false
	var hashes: Dictionary = {}
	for path: String in ["scripts/game/game_world.gd", "scripts/game/standard_boss.gd", "scripts/game/mechanical_encounters.gd", "scripts/game/standard_director.gd", "scripts/game/overtime_director.gd", "scripts/game/player_ability.gd", "scripts/game/run_loadout.gd", "tests/probe_boss_counter_b.gd", "tests/probe_v04_mechanics.gd", "tests/probe_standard_world.gd"]:
		hashes[path] = FileAccess.get_sha256("res://" + path)
	b_report = {
		"complete": false, "fixture": true, "engine": Engine.get_version_info().string,
		"method": "Isolated early OVERTIME room-three boss, not a normal full run or purchased build. Start_endless supplies ordinary initial health/resources/spawn grace; room index and two early tools are fixture setup. No health, invulnerability, enemy HP, energy, skill-charge or clock edits; all battle outcomes follow fixed 60 Hz movement/mouse/vacuum/dash/skill input.",
		"builds": BUILDS, "skill": "pulse", "mods": "All zero", "boons": "All zero; initial hunters risk", "max_combat_seconds": maximum_seconds,
		"policy": "Melee approaches within brush reach; ranged holds arc range. Reacts to visible counter targets, battery enemies, drops and committed warning corridors. Pulse availability never depends on discharge energy. Uses held vacuum and release to discharge, normal dash and skill inputs. No direct counter progress, damage or resource calls.",
		"resource_observation": "Positive resource changes are per-tick net gains, not exact gross supply; simultaneous spending/capping can conceal gains. Mechanism counters/events are retained when the integrated world exposes them. Zero-energy valley means energy <=0.01 and skill charge<99.99; active-skill overlap is recorded separately. No idle/shop recharge is inserted.",
		"limitations": "Two deliberately established early builds and deterministic heuristic inputs cannot establish full-run economy, human difficulty or player win rate. Immediate reactions can outperform people. A dead player remains a failure even if the final boss died on the same tick. No rendering-performance claim.",
		"source_sha256": hashes, "runs": [], "failures": b_failures,
	}
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	_write_b_report()
	for map_id: String in maps:
		for build: String in b_builds:
			for seed_value: int in seeds:
				await _isolated_boss(map_id, build, seed_value)
				_write_b_report()
	b_report.complete = true
	_write_b_report()
	print("BOSS_COUNTER_B_REPORT ", JSON.stringify({"path": b_path, "runs": b_report.runs.size(), "failures": b_failures}))
	await root.get_node("SoundBank").shutdown()
	await process_frame
	quit(0 if b_failures.is_empty() else 1)


func _isolated_boss(map_id: String, build: String, seed_value: int) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	root.add_child(viewport)
	var world: Node2D = World.new()
	viewport.add_child(world)
	world.set_physics_process(false)
	var settlement: Dictionary = {}
	world.wave_completed.connect(func(summary: Dictionary) -> void: settlement.merge(summary, true))
	world.start_endless(map_id, seed_value, {"skill": "pulse"})
	# This is the entire privileged setup. It does not advance any battle clock.
	world._overtime.room = 3
	world._overtime.completed = 2
	world.wave_index = 3
	for id: String in BUILDS[build]:
		world._loadout.weapons[id] = int(BUILDS[build][id])
	world._refresh_modifiers()
	world._overtime.begin(world)
	world._spawn_boss()
	var initial: Dictionary = {"health": world.health, "energy": world.energy, "skill_charge": world._ability.charge, "boss_hp": world._boss.hp, "loadout": world.get_stats().loadout, "boss_spawn_grace": world._boss.spawn, "player_spawn_grace": world._invulnerability, "risk": world._overtime.risk, "mechanism_metrics": _mechanism_metrics(world)}
	var timeline: Array[Dictionary] = []
	var events: Array[Dictionary] = []
	var hurt: Array[Dictionary] = []
	var valley_windows: Array[Dictionary] = []
	var zero_start: float = -1.0
	var zero_total: float = 0.0
	var zero_longest: float = 0.0
	var zero_active: float = 0.0
	var energy_net_gained: float = 0.0
	var skill_net_gained: float = 0.0
	var valley_auto_damage: float = 0.0
	var valley_auto_seconds: float = 0.0
	var valley_auto_by_phase: Dictionary = {}
	var valley_state_seconds: Dictionary = {}
	var valley_no_boss_hit: float = 0.0
	var longest_valley_no_boss_hit: float = 0.0
	var energy_minimum: float = world.energy
	var skill_minimum: float = world._ability.charge
	var next_sample: float = 0.0
	var ticks: int = 0
	var input_verified: bool = false
	var invalid_reason: String = ""
	var boss_damage_by_phase: Dictionary = {}
	var state_seconds: Dictionary = {}
	var start_wall: int = Time.get_ticks_msec()
	print("BOSS_COUNTER_B_START ", JSON.stringify({"map": map_id, "build": build, "seed": seed_value, "initial": initial}))
	while world.active and world.phase == "combat" and world.elapsed < maximum_seconds:
		if ticks > ceili(maximum_seconds * 180.0):
			invalid_reason = "Input tick guard reached without combat clock progress"
			break
		var before: Dictionary = _observation(world)
		var controls: Dictionary = _b_controls(world, build)
		_apply_controls(controls, viewport)
		world._physics_process(STEP)
		if ticks == 0:
			var aim: Vector2 = (Vector2(controls.aim) - world.player_position).normalized()
			input_verified = world.player_aim.dot(aim) > 0.97
			if not input_verified:
				invalid_reason = "Mouse injection did not reach actual world input"
				break
		var after: Dictionary = _observation(world)
		var elapsed_delta: float = float(after.time) - float(before.time)
		state_seconds[before.state] = float(state_seconds.get(before.state, 0.0)) + elapsed_delta
		var dealt: float = maxf(0.0, float(before.boss_hp) - float(after.boss_hp))
		boss_damage_by_phase[before.state] = float(boss_damage_by_phase.get(before.state, 0.0)) + dealt
		var energy_gain: float = maxf(0.0, float(after.energy) - float(before.energy))
		var skill_gain: float = maxf(0.0, float(after.skill_charge) - float(before.skill_charge))
		energy_net_gained += energy_gain
		skill_net_gained += skill_gain
		energy_minimum = minf(energy_minimum, after.energy)
		skill_minimum = minf(skill_minimum, after.skill_charge)
		if energy_gain > 0.001 or skill_gain > 0.001 or after.breaks != before.breaks or after.uses != before.uses or after.discharges != before.discharges:
			if events.size() < B_EVENT_LIMIT:
				events.append({"time": after.time, "state": after.state, "energy_net_gain": energy_gain, "skill_net_gain": skill_gain, "energy": after.energy, "skill_charge": after.skill_charge, "break_delta": int(after.breaks) - int(before.breaks), "ability_use_delta": int(after.uses) - int(before.uses), "discharge_delta": int(after.discharges) - int(before.discharges), "mechanism_metrics": _mechanism_metrics(world)})
		if float(after.damage_taken) > float(before.damage_taken):
			hurt.append({"time": after.time, "source": world.last_damage_source, "damage": float(after.damage_taken) - float(before.damage_taken), "state": before.state, "energy": after.energy, "skill_charge": after.skill_charge})
		var zero: bool = float(after.energy) <= 0.01 and float(after.skill_charge) < 99.99
		if zero:
			if zero_start < 0.0:
				zero_start = float(before.time)
			zero_total += elapsed_delta
			valley_state_seconds[before.state] = float(valley_state_seconds.get(before.state, 0.0)) + elapsed_delta
			if dealt <= 0.00001:
				valley_no_boss_hit += elapsed_delta
				longest_valley_no_boss_hit = maxf(longest_valley_no_boss_hit, valley_no_boss_hit)
			else:
				valley_no_boss_hit = 0.0
			# Both ends are resource-poor, no new discharge/cast, no active effect.
			# These fixtures only have brush/saw/arc plus instantaneous Pulse;
			# boss HP lost here is actual automatic-tool damage, including saws
			# already in flight. It excludes attacks that just spent the resource.
			if float(before.energy) <= 0.01 and float(before.skill_charge) < 99.99 and int(after.uses) == int(before.uses) and int(after.discharges) == int(before.discharges) and float(before.skill_duration) <= 0.0 and float(before.skill_effect) <= 0.0:
				valley_auto_damage += dealt
				valley_auto_seconds += elapsed_delta
				valley_auto_by_phase[before.state] = float(valley_auto_by_phase.get(before.state, 0.0)) + dealt
			if float(world._ability.duration) > 0.0 or float(world._ability.effect) > 0.0:
				zero_active += elapsed_delta
		elif zero_start >= 0.0:
			var duration: float = float(before.time) - zero_start
			zero_longest = maxf(zero_longest, duration)
			valley_windows.append({"start": zero_start, "end": before.time, "seconds": duration})
			zero_start = -1.0
			valley_no_boss_hit = 0.0
		if world.elapsed >= next_sample:
			timeline.append(after)
			next_sample += 1.0
		ticks += 1
		if ticks % 30 == 0:
			await process_frame
	if zero_start >= 0.0:
		var duration: float = world.elapsed - zero_start
		zero_longest = maxf(zero_longest, duration)
		valley_windows.append({"start": zero_start, "end": world.elapsed, "seconds": duration})
	var defeated: bool = bool(world._boss_defeated)
	var outcome: String = "won_boss" if defeated and world.health > 0.0 else ("lost_simultaneous_boss_defeat" if defeated else "lost")
	if world.health > 0.0 and not defeated:
		outcome = "combat_time_limit"
	if not invalid_reason.is_empty():
		outcome = "invalid_probe"
		b_failures.append(map_id + "/" + build + ": " + invalid_reason)
	var result: Dictionary = {
		"map": map_id, "build": build, "seed": seed_value, "outcome": outcome, "invalid_reason": invalid_reason, "input_verified": input_verified,
		"initial": initial, "combat_seconds": world.elapsed, "input_ticks": ticks, "wall_ms": Time.get_ticks_msec() - start_wall,
		"health_after_room_settlement": world.health, "room_clear_heal": settlement.get("repaired", 0.0), "health_at_boss_end_before_room_heal": world.health - float(settlement.get("repaired", 0.0)),
		"actual_player_damage_taken": world.damage_taken, "hurt_events": hurt, "boss_hp_remaining": world._boss.get("hp", 0.0), "boss_actual_damage_dealt": float(initial.boss_hp) - float(world._boss.get("hp", 0.0)),
		"boss_damage_by_phase": boss_damage_by_phase, "state_seconds": state_seconds, "all_target_damage_by_source": world.damage_by_source.duplicate(true),
		"boss_breaks": world._director.encounters.boss_breaks, "ability_uses": world._ability.uses, "discharges": world.shots,
		"energy_positive_net_gains": energy_net_gained, "skill_positive_net_gains": skill_net_gained, "minimum_energy": energy_minimum, "minimum_skill_charge": skill_minimum,
		"zero_energy_and_skill_low_seconds": zero_total, "longest_zero_energy_and_skill_low_seconds": zero_longest, "zero_energy_low_skill_with_active_effect_seconds": zero_active, "zero_energy_windows": valley_windows,
		"strict_valley_automatic_boss_damage": valley_auto_damage, "strict_valley_automatic_seconds": valley_auto_seconds, "strict_valley_automatic_boss_damage_by_phase": valley_auto_by_phase,
		"valley_state_seconds": valley_state_seconds, "longest_valley_without_boss_damage_seconds": longest_valley_no_boss_hit,
		"valley_damage_method": "Automatic damage counts actual boss HP loss only when both tick boundaries have energy<=0.01 and skill charge<99.99, no new ability/discharge, and no prior active-skill effect or duration. With these brush/saw/arc + instantaneous Pulse fixtures this isolates automatic tools; it excludes transition casts and does not infer enemy damage from all-target totals. Longest no-boss-hit interval may include useful movement/counter/battery work, not necessarily idle input.",
		"mechanism_metrics": _mechanism_metrics(world), "resource_and_cast_events": events, "event_limit_reached": events.size() == B_EVENT_LIMIT, "one_second_timeline": timeline,
	}
	for key: String in ["boss_supply_energy", "boss_supply_charge"]:
		if initial.mechanism_metrics.has(key) and result.mechanism_metrics.has(key):
			result[key + "_during_combat"] = float(result.mechanism_metrics[key]) - float(initial.mechanism_metrics[key])
	b_report.runs.append(result)
	print("BOSS_COUNTER_B_RESULT ", JSON.stringify({"map": map_id, "build": build, "seed": seed_value, "outcome": outcome, "seconds": world.elapsed, "health": result.health_at_boss_end_before_room_heal, "boss_hp_remaining": result.boss_hp_remaining, "breaks": result.boss_breaks, "discharges": world.shots, "skill_uses": result.ability_uses, "zero_energy_skill_low_seconds": zero_total, "longest_valley": zero_longest}))
	_release_inputs()
	viewport.queue_free()
	await process_frame


func _observation(world: Node2D) -> Dictionary:
	return {"time": world.elapsed, "state": world._boss.get("state", ""), "boss_hp": world._boss.get("hp", 0.0), "health": world.health, "damage_taken": world.damage_taken, "energy": world.energy, "skill_charge": world._ability.charge, "skill_effect": world._ability.effect, "skill_duration": world._ability.duration, "uses": world._ability.uses, "discharges": world.shots, "breaks": world._director.encounters.boss_breaks, "enemies": world._enemies.size(), "drops": world._scraps.size()}


func _mechanism_metrics(world: Node2D) -> Dictionary:
	var metrics: Dictionary = {}
	var stats: Dictionary = world.get_stats()
	for key: String in stats:
		if key.begins_with("boss_supply") or key.begins_with("boss_batter") or key in ["boss_adds_spawned", "projections_destroyed", "boss_breaks", "boss_exposed_seconds", "boss_focused"]:
			metrics[key] = stats[key]
	return metrics


func _write_b_report() -> void:
	b_report.failures = b_failures
	var output := FileAccess.open(b_path, FileAccess.WRITE)
	if output == null:
		push_error("Cannot write isolated boss report: " + b_path)
		quit(1)
		return
	output.store_string(JSON.stringify(b_report, "  "))
	output.close()


func _b_controls(world: Node2D, build: String) -> Dictionary:
	var position: Vector2 = world.player_position
	var target: Dictionary = world._boss
	var energy_low: bool = world.energy < 35.0
	var skill_ready: bool = str(world.get_stats().ability_state) == "ready"
	var target_score: float = INF
	for enemy: Dictionary in world._enemies:
		if bool(enemy.settled) or float(enemy.spawn) > 0.0:
			continue
		var distance: float = position.distance_to(enemy.pos)
		var score: float = distance - (130.0 if energy_low and bool(enemy.get("boss_battery", false)) else 0.0)
		if score < target_score:
			target_score = score
			target = enemy
	var reach: float = 94.0 if build == "melee" else 200.0
	if int(target.get("kind", 3)) != 3:
		reach = 58.0 if build == "melee" else 140.0
	var away: Vector2 = (position - Vector2(target.pos)).normalized()
	if away.length_squared() < 0.1:
		away = Vector2.DOWN
	var goal: Vector2 = Vector2(target.pos) + away * reach
	var aim: Vector2 = target.pos
	var hold_vacuum: bool = not world._vacuum_gate
	var release: bool = world._vacuum and world.energy >= 45.0 and position.distance_to(aim) < 285.0 and world._line_clear(position, aim)
	var cast: bool = skill_ready and position.distance_to(aim) < 165.0 and float(target.get("spawn", 0.0)) <= 0.0
	if world._boss.get("state", "") == "exposed":
		goal = Vector2(world._boss.pos) + (position - Vector2(world._boss.pos)).normalized() * 94.0
		aim = world._boss.pos
		cast = skill_ready and position.distance_to(aim) < 175.0
		release = world._vacuum and world.energy >= 35.0 and position.distance_to(aim) < 285.0
	else:
		var best_counter: float = INF
		for device: Dictionary in world._director.encounters.targets:
			if bool(device.settled):
				continue
			var kind: String = str(device.kind)
			var candidate: Vector2 = device.pos
			if kind == "bait":
				if str(world._boss.state) in ["windup", "charge"] or Vector2(world._boss.pos).distance_to(candidate) < 95.0:
					continue
				candidate += (candidate - Vector2(world._boss.pos)).normalized() * 110.0
				if not Rect2(85, 158, 1110, 465).has_point(candidate):
					continue
			elif kind in ["node", "relay", "projection"]:
				candidate += (position - candidate).normalized() * 65.0
			elif kind != "vent":
				continue
			var distance: float = candidate.distance_to(position)
			if distance >= best_counter:
				continue
			best_counter = distance
			goal = candidate
			aim = device.pos
			hold_vacuum = not world._vacuum_gate
			release = kind in ["node", "relay", "projection"] and world._vacuum and world.energy >= 34.0 and position.distance_to(aim) < 190.0
			cast = kind in ["node", "relay", "projection"] and skill_ready and position.distance_to(aim) < 160.0
		if energy_low:
			var nearest_drop: float = 200.0
			for drop: Dictionary in world._scraps:
				var distance: float = position.distance_to(drop.pos)
				if distance < nearest_drop:
					nearest_drop = distance
					goal = drop.pos
					aim = drop.pos
					release = false
	var move: Vector2 = _safe_direction(world, goal)
	var danger: bool = false
	for enemy: Dictionary in world._enemies:
		if not bool(enemy.settled) and float(enemy.spawn) <= 0.0 and position.distance_to(enemy.pos) < float(enemy.radius) + float(world.balance.player_radius) + 17.0:
			danger = true
	for shot: Dictionary in world._projectiles:
		if Geometry2D.get_closest_point_to_segment(position, shot.pos, Vector2(shot.pos) + Vector2(shot.vel) * 0.12).distance_to(position) < 32.0:
			danger = true
	return {"move": move, "aim": aim, "vacuum": hold_vacuum and not release, "dash": danger and world._dash_cooldown <= 0.0 and move != Vector2.ZERO, "ability": cast}
