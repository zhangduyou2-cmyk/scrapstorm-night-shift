extends SceneTree
## Synthetic native rendering load, not a playable loadout or balance probe.
## Run without --headless, with --position -1800,-1200 and -- --test-settings.
## Example: Godot --path . --position -1800,-1200 --script res://tests/benchmark_v05_render.gd -- --test-settings

const World = preload("res://scripts/game/game_world.gd")
const FRAME_MINIMUM: int = 600
const SECONDS_MINIMUM: float = 3.0
const WARMUP_SECONDS: float = 1.0
const PHASE_TIMEOUT_SECONDS: float = 90.0
const SKILLS: Array[String] = ["pulse", "overdrive", "singularity"]
const BRANCHES: Dictionary = {"pulse": "pulse_echo", "overdrive": "overdrive_stride", "singularity": "singularity_rupture"}
var failures: Array[String] = []
var fixture_clock: float = 0.0
var next_burst: float = 0.0
var next_discharge: float = 0.0
var next_ability: float = 0.0
var next_grid: float = 0.0
var serial: int = 0
var selected_maps: Array[String] = ["yard", "foundry", "reactor"]
var selected_skills: Array[String] = ["overdrive"]
var output_stem: String = "v05-render-benchmark"
var capture_stem: String = "v05-render"
var minimum_seconds: float = SECONDS_MINIMUM
var maintenance_calls: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless" or not OS.get_cmdline_user_args().has("--test-settings"):
		push_error("Native renderer and --test-settings are required; no benchmark ran.")
		quit(1)
		return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--map="):
			var map_id: String = argument.trim_prefix("--map=")
			if map_id not in ["yard", "foundry", "reactor"]:
				push_error("Unknown benchmark map: " + map_id)
				quit(1)
				return
			selected_maps = [map_id]
		elif argument.begins_with("--skill="):
			var skill: String = argument.trim_prefix("--skill=")
			if skill not in SKILLS:
				push_error("Unknown benchmark skill: " + skill)
				quit(1)
				return
			selected_skills = [skill]
		elif argument.begins_with("--label="):
			var label: String = argument.trim_prefix("--label=")
			var pattern := RegEx.new()
			pattern.compile("^[a-z0-9_-]+$")
			if pattern.search(label) == null:
				push_error("Benchmark label must contain only lowercase letters, digits, underscores or hyphens.")
				quit(1)
				return
			output_stem = "v05-render-" + label
			capture_stem = output_stem
		elif argument.begins_with("--seconds="):
			var requested: String = argument.trim_prefix("--seconds=")
			if not requested.is_valid_float() or not is_finite(float(requested)) or float(requested) < 3.0 or float(requested) > 60.0:
				push_error("Benchmark seconds must be finite and between 3 and 60.")
				quit(1)
				return
			minimum_seconds = float(requested)
	for action: String in ["move_left", "move_right", "move_up", "move_down", "vacuum", "dash", "active_skill"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		Input.action_release(action)
	root.size = Vector2i(1280, 720)
	root.mode = Window.MODE_WINDOWED
	root.always_on_top = false
	root.position = Vector2i(-1800, -1200)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.max_fps = 0
	OS.low_processor_usage_mode = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.set_render_loop_enabled(true)
	paused = false
	create_timer(900.0, true, false, true).timeout.connect(func() -> void:
		push_error("Native rendering benchmark exceeded its 900-second watchdog; incomplete results must not be reported as passing.")
		quit(2))
	root.get_node("Settings").effects_enabled = true
	var title := Label.new()
	title.position = Vector2(42, 30)
	title.z_index = 100
	title.add_theme_font_size_override("font_size", 23)
	root.add_child(title)
	var report: Dictionary = {
		"method": "Native 1280x720 World only; actual frame_post_draw boundaries, ordinary 60 Hz physics, uncapped frames and VSync disabled. Each map/skill has one second warmup then at least 600 frames and the configured minimum wall-clock seconds. No manual simulation ticks.",
		"minimum_frames": FRAME_MINIMUM, "minimum_seconds": minimum_seconds, "seed": 7041,
		"world_source_sha256": FileAccess.get_sha256("res://scripts/game/game_world.gd"),
		"source_sha256": {"game_world.gd": FileAccess.get_sha256("res://scripts/game/game_world.gd"), "enemy_atlas.gd": FileAccess.get_sha256("res://scripts/game/enemy_atlas.gd"), "enemy_atlas.png": FileAccess.get_sha256("res://assets/sprites/enemy_atlas.png"), "benchmark_v05_render.gd": FileAccess.get_sha256("res://tests/benchmark_v05_render.gd")},
		"fixture": "Deliberate invulnerability, huge enemy HP, replenished enemy/projectile/drop/hazard pools, refilled discharge and skill charge. All eight level-three tools plus capped overtime boons exceed the legal four-slot build to exercise all six evolutions together. Maintenance overhead is included. Audio/menu/HUD shell are not connected. This is not a normal run.",
		"limitations": "Frame intervals include CPU work, render submission, driver and scheduling; they are not isolated GPU timings or physical display presentation. Off-screen Windows composition may differ from an onscreen game. This hardware is not minimum specification. No difficulty, whole-run playability or minimum-spec claim.",
		"performance_target_evaluated": false,
		"monitor_notes": "TIME_PROCESS and TIME_PHYSICS_PROCESS are Godot engine time monitors sampled at each rendered frame, converted from seconds to milliseconds. Built-in monitors can lag by up to one second. Their sampled-value distributions are not independent timings of every physics call; accounting can overlap and must not be subtracted from frame intervals to infer GPU time.",
		"monitor_reference": "https://docs.godotengine.org/en/stable/classes/class_performance.html",
		"hardware": {"os": OS.get_name(), "cpu": OS.get_processor_name(), "logical_processors": OS.get_processor_count(), "gpu": RenderingServer.get_video_adapter_name(), "gpu_vendor": RenderingServer.get_video_adapter_vendor(), "graphics_api": RenderingServer.get_video_adapter_api_version(), "rendering_method": RenderingServer.get_current_rendering_method(), "rendering_driver": RenderingServer.get_current_rendering_driver_name(), "display_server": DisplayServer.get_name(), "engine": Engine.get_version_info().string},
		"settings": {"size": [root.size.x, root.size.y], "position": [root.position.x, root.position.y], "vsync": DisplayServer.window_get_vsync_mode(), "fps_cap": Engine.max_fps, "low_processor_usage": OS.low_processor_usage_mode, "physics_hz": Engine.physics_ticks_per_second, "focus_pause_shell_loaded": false},
		"runs": [], "failures": failures,
	}
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	DirAccess.make_dir_recursive_absolute("res://captures")
	var world: Node2D = World.new()
	root.add_child(world)
	world.process_mode = Node.PROCESS_MODE_ALWAYS
	for source: String in ["arsenal_effects.gd", "run_loadout.gd", "standard_boss.gd", "mechanical_encounters.gd", "standard_director.gd", "overtime_director.gd", "player_ability.gd", "evolution_effects.gd", "combat_feedback.gd", "game_balance.gd"]:
		report.source_sha256[source] = FileAccess.get_sha256("res://scripts/game/" + source)
	report["complete"] = false
	report["fixture_revision"] = "Bounded maintenance attempts with growth checks; completed phases saved before continuing. Production gameplay is unchanged."
	for map_id: String in selected_maps:
		print("V05_RENDER_STAGE ", map_id, " setup")
		report["current_stage"] = map_id + "/setup"
		_write_report(report)
		_setup_world(world, map_id)
		print("V05_RENDER_STAGE ", map_id, " setup_complete ", JSON.stringify(_counts(world)))
		for skill: String in selected_skills:
			title.text = "SYNTHETIC RENDER LOAD / " + map_id.to_upper() + " / " + skill.to_upper()
			world._ability.configure({"skill": skill, "skill_color": "violet" if skill == "singularity" else "cyan"})
			world._ability.choose_branch(BRANCHES[skill], 2)
			world._ability.choose_branch(BRANCHES[skill], 4)
			next_ability = fixture_clock
			print("V05_RENDER_STAGE ", map_id, "/", skill, " measure")
			report.current_stage = map_id + "/" + skill + "/measure"
			_write_report(report)
			var result: Dictionary = await _measure(world, map_id, skill)
			report.runs.append(result)
			var compact: Dictionary = result.duplicate()
			compact.erase("raw_frame_ms")
			print("V05_RENDER_PHASE ", JSON.stringify(compact))
			report.current_stage = map_id + "/" + skill + "/capture"
			_write_report(report)
			# Readback and PNG compression are intentionally outside measurement.
			world._ability.clear_effects()
			world._ability.charge = 100.0
			world._ability.activate(world)
			_replenish(world, 0.0)
			world.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var path: String = "res://captures/" + capture_stem + "-" + map_id + "-" + skill + ".png"
			var saved: Error = root.get_texture().get_image().save_png(path)
			result.screenshot = path
			if saved != OK:
				failures.append("Screenshot failed: " + path)
			_write_report(report)
	world.set_physics_process(false)
	world.queue_free()
	for action: String in ["move_left", "move_right", "move_up", "move_down", "vacuum", "dash", "active_skill"]:
		Input.action_release(action)
	report.failures = failures
	report.complete = true
	report.current_stage = "finished"
	_write_report(report)
	print("V05_RENDER_BENCHMARK ", JSON.stringify({"hardware": report.hardware, "settings": report.settings, "phases": report.runs.size(), "failures": failures}))
	await root.get_node("SoundBank").shutdown()
	await process_frame
	quit(0 if failures.is_empty() else 1)


func _write_report(report: Dictionary) -> void:
	report.failures = failures
	var output := FileAccess.open("res://artifacts/" + output_stem + ".json", FileAccess.WRITE)
	if output == null:
		push_error("Cannot write " + output_stem + ".json")
		quit(1)
		return
	output.store_string(JSON.stringify(report, "  "))
	output.close()


func _setup_world(world: Node2D, map_id: String) -> void:
	world.start_endless(map_id, 7041, {"skill": "pulse"})
	world._overtime.room = 18
	world._overtime.completed = 17
	world._overtime.risk = "crossfire"
	for id: String in world._overtime.BOONS:
		world._overtime.boons[id] = 5
	world.wave_index = 18
	world._spawn_boss()
	world._boss.hp = 1.0e8
	world._boss.max_hp = 2.5e8
	world._boss.spawn = 0.0
	world._invulnerability = 10000.0
	world._loadout.weapons = {"brush": 3, "foam": 3, "arc": 3, "saw": 3, "laser": 3, "missile": 3, "drone": 3, "mines": 3}
	world._loadout.mods = {"hull": 3, "treads": 3, "magnet": 3, "capacitor": 3, "torque": 3, "coolant": 3}
	world._refresh_modifiers()
	world._evolution.refresh(world)
	world._director.encounters.spawn_elite(world)
	world._enemies.back().hp = 1.0e8
	fixture_clock = 0.0
	next_burst = 0.0
	next_discharge = 0.0
	next_ability = 0.0
	next_grid = 0.0
	maintenance_calls = 0
	_replenish(world, 0.0)


func _measure(world: Node2D, map_id: String, skill: String) -> Dictionary:
	var began: int = Time.get_ticks_usec()
	var previous: int = began
	while float(Time.get_ticks_usec() - began) / 1.0e6 < WARMUP_SECONDS:
		_replenish(world, float(Time.get_ticks_usec() - previous) / 1.0e6)
		previous = Time.get_ticks_usec()
		await process_frame
		await RenderingServer.frame_post_draw
	var samples: Array[float] = []
	var process_samples: Array[float] = []
	var physics_samples: Array[float] = []
	var minimums: Dictionary = {}
	var peaks: Dictionary = {}
	var render_draw_calls: int = 0
	var active_frames: int = 0
	var active_elapsed_start: float = world.elapsed
	var physics_start: int = Engine.get_physics_frames()
	began = Time.get_ticks_usec()
	previous = began
	while samples.size() < FRAME_MINIMUM or float(Time.get_ticks_usec() - began) / 1.0e6 < minimum_seconds:
		_replenish(world, samples.back() / 1000.0 if not samples.is_empty() else 1.0 / 60.0)
		world.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var now: int = Time.get_ticks_usec()
		samples.append(float(now - previous) / 1000.0)
		process_samples.append(float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0)
		physics_samples.append(float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0)
		previous = now
		var counts: Dictionary = _counts(world)
		for key: String in counts:
			minimums[key] = mini(int(minimums.get(key, counts[key])), int(counts[key]))
			peaks[key] = maxi(int(peaks.get(key, 0)), int(counts[key]))
		render_draw_calls = maxi(render_draw_calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		if world._ability.duration > 0.0 or world._ability.effect > 0.0:
			active_frames += 1
		if float(now - began) / 1.0e6 > PHASE_TIMEOUT_SECONDS:
			failures.append(map_id + "/" + skill + ": phase timed out before frame requirement")
			break
	var seconds: float = float(Time.get_ticks_usec() - began) / 1.0e6
	var sorted: Array[float] = samples.duplicate()
	sorted.sort()
	var caps: Dictionary = {"arsenal_missiles": 12, "arsenal_mines": 12, "arsenal_beams": 20, "arsenal_blasts": 16, "arsenal_drones": 3, "enemies": int(world.balance.max_enemies), "projectiles": int(world.balance.max_projectiles), "scrap": int(world.balance.max_scrap), "hazards": 18, "particles": int(world.balance.max_particles), "foam": int(world.balance.max_foam), "saws": 18, "evolution_links": 8, "compression_wells": 3, "feedback_rings": 24, "feedback_debris": 96, "feedback_trails": 16, "feedback_captions": 10, "skill_trails": 18}
	var bounded: bool = true
	for key: String in caps:
		if int(peaks[key]) > int(caps[key]):
			bounded = false
			failures.append(map_id + "/" + skill + ": count cap exceeded for " + key)
	if not world.active or world.paused or Engine.get_physics_frames() <= physics_start or world.elapsed <= active_elapsed_start:
		failures.append(map_id + "/" + skill + ": fixture stopped simulating")
	if int(minimums.enemies) < 80 or int(peaks.projectiles) < 70 or active_frames == 0 or render_draw_calls == 0 or int(peaks.saws) == 0 or int(peaks.evolution_links) == 0 or int(peaks.compression_wells) == 0:
		failures.append(map_id + "/" + skill + ": expected rendered load was not exercised")
	return {"map": map_id, "skill": skill, "branch": world._ability.branch, "frames": samples.size(), "seconds": seconds, "fps": float(samples.size()) / seconds, "p50_frame_ms": _percentile(sorted, 0.50), "p95_frame_ms": _percentile(sorted, 0.95), "max_frame_ms": sorted.back(), "mean_frame_ms": seconds * 1000.0 / samples.size(), "engine_process_ms": _distribution(process_samples), "engine_physics_ms": _distribution(physics_samples), "physics_ticks": Engine.get_physics_frames() - physics_start, "combat_clock_advanced": world.elapsed - active_elapsed_start, "active_skill_frames": active_frames, "draw_calls_peak": render_draw_calls, "minimum_counts_after_draw": minimums, "peaks": peaks, "caps": caps, "bounded": bounded, "raw_frame_ms": samples}


func _replenish(world: Node2D, wall_delta: float) -> void:
	maintenance_calls += 1
	fixture_clock += maxf(0.0, wall_delta)
	world.paused = false
	world.player_position = world._move_body(Vector2(640, 390), Vector2.from_angle(fixture_clock * 0.5) * 135.0, 20.0)
	world.player_aim = Vector2.from_angle(fixture_clock * 1.1)
	for attempt: int in range(maxi(0, 100 - world._enemies.size())):
		var n: int = world._enemies.size()
		var added: int = world.debug_spawn_enemy(world._move_body(Vector2(95 + n % 14 * 81, 170 + n / 14 * 65), Vector2.ZERO, 15.0), n % 3)
		if added < 0 or world._enemies.size() <= n:
			_maintenance_failed(world, "enemies", n)
			break
		world._enemies.back().hp = 1.0e8
		world._enemies.back().spawn = 0.0
	for attempt: int in range(maxi(0, 70 - world._projectiles.size())):
		var before: int = world._projectiles.size()
		var angle: float = float(serial % 70) * TAU / 70.0 + fixture_clock * 0.2
		serial += 1
		world._fire_projectile(Vector2(640, 390) + Vector2.from_angle(angle) * 190.0, Vector2.from_angle(angle + PI * 0.45) * 230.0, 12.0, true)
		if world._projectiles.size() <= before:
			_maintenance_failed(world, "projectiles", before)
			break
	for attempt: int in range(maxi(0, 150 - world._scraps.size())):
		var n: int = world._scraps.size()
		world.debug_add_scrap(Vector2(90 + n % 20 * 55, 180 + n / 20 * 60), 1)
		if world._scraps.size() <= n:
			_maintenance_failed(world, "scrap", n)
			break
	for attempt: int in range(maxi(0, 18 - world._director.hazards.size())):
		var n: int = world._director.hazards.size()
		world._director.circle_hazard(Vector2(110 + n % 6 * 190, 235 + n / 6 * 135), 42.0, 0.8 + (n % 3) * 0.25, 2.0, 8.0, "DAMAGE_SHOCK")
		if world._director.hazards.size() <= n:
			_maintenance_failed(world, "hazards", n)
			break
	for attempt: int in range(maxi(0, 5 - world._foam.size())):
		var n: int = world._foam.size()
		world._foam.append({"pos": Vector2(440 + n * 85, 390), "radius": 62.0, "damage": 8.0, "life": 3.5, "tick": 0.0, "tick_interval": 0.45})
	if fixture_clock >= next_grid:
		next_grid = fixture_clock + 0.75
		world._evolution.arc_hit(world, world._foam[0].pos)
	if fixture_clock >= next_burst:
		next_burst = fixture_clock + 0.18
		world._spawn_particles(world.player_position, Color.ORANGE, 240, 70.0, 300.0)
	if fixture_clock >= next_discharge:
		next_discharge = fixture_clock + 0.75
		world.energy = 160.0
		world._discharge()
	if fixture_clock >= next_ability and world._ability.duration <= 0.0:
		next_ability = fixture_clock + 0.8
		world._ability.charge = 100.0
		world._ability.activate(world)


func _maintenance_failed(world: Node2D, pool: String, count: int) -> void:
	var issue: String = "%s: maintenance %s stopped growing at %d" % [world.map_id, pool, count]
	if issue not in failures:
		failures.append(issue)
		print("V05_RENDER_MAINTENANCE_FAILURE ", issue)


func _counts(world: Node2D) -> Dictionary:
	return {"enemies": world._enemies.size(), "projectiles": world._projectiles.size(), "scrap": world._scraps.size(), "hazards": world._director.hazards.size(), "particles": world._particles.size(), "foam": world._foam.size(), "arcs": world._arcs.size(), "saws": world._saws.size(), "shockwaves": world._waves.size(), "evolution_links": world._evolution.links.size(), "compression_wells": world._evolution.wells.size(), "feedback_rings": world._feedback.rings.size(), "feedback_debris": world._feedback.debris.size(), "feedback_trails": world._feedback.trails.size(), "feedback_captions": world._feedback.captions.size(), "skill_trails": world._ability._trails.size(), "arsenal_missiles": world._arsenal.missiles.size(), "arsenal_mines": world._arsenal.mines.size(), "arsenal_beams": world._arsenal.beams.size(), "arsenal_blasts": world._arsenal.blasts.size(), "arsenal_drones": world._arsenal.drone_positions.size()}


func _percentile(sorted: Array[float], percentile: float) -> float:
	return sorted[clampi(ceili(float(sorted.size()) * percentile) - 1, 0, sorted.size() - 1)]


func _distribution(values: Array[float]) -> Dictionary:
	var ordered: Array[float] = values.duplicate()
	ordered.sort()
	var total: float = 0.0
	for value: float in values:
		total += value
	return {"p50": _percentile(ordered, 0.5), "p95": _percentile(ordered, 0.95), "max": ordered.back(), "mean": total / values.size()}
