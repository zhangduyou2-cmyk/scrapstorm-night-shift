extends SceneTree
## Staged rendering fixtures for boss feedback; never a playthrough or balance result.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if "--test-settings" not in OS.get_cmdline_user_args():
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	var app: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	app.world.set_physics_process(false)
	var captures: Array[String] = []
	for locale: String in ["en", "zh_CN"]:
		root.get_node("Settings").set_locale(locale)
		for map_id: String in ["yard", "foundry", "reactor"]:
			app._deploy_standard(map_id)
			app.world.set_physics_process(false)
			app.tutorial_panel.visible = false
			var world: Node2D = app.world
			world.wave_index = 6
			world._spawn_boss()
			world._boss.pos = Vector2(770, 360)
			world._boss.spawn = 0.0
			world.player_position = Vector2(615, 445)
			world.player_aim = (Vector2(world._boss.pos) - world.player_position).normalized()
			world._visual_time = 8.0
			world.energy = 25.0
			world._ability.charge = 45.0
			world.debug_spawn_enemy(Vector2(1015, 415), 0)
			var battery: Dictionary = world._enemies.back()
			battery.spawn = 0.0
			battery.boss_add = true
			battery.boss_battery = true
			world.debug_spawn_enemy(Vector2(540, 290), 1)
			world._enemies.back().spawn = 0.0
			world._enemies.back().boss_add = true
			if map_id == "foundry":
				world._boss_brain._recover(world._boss)
				world._director.encounters.targets[0].progress = 0.65
				await _capture(app, locale + "-foundry-valve", captures)
			elif map_id == "reactor":
				world._director.encounters.targets[0].dismantle_progress = 0.65
				await _capture(app, locale + "-reactor-nodes", captures)
			world._director.encounters._break_boss(world)
			world._feedback.tick(0.3, true)
			await _capture(app, locale + "-" + map_id + "-exposed", captures)
	var report: Dictionary = {"fixture": true, "captures": captures, "method": "Staged native-rendered scenes with actual HUD, both locales. Not player actions, a playthrough, or performance evidence."}
	var file := FileAccess.open("res://artifacts/v051-boss-captures.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("BOSS_B_CAPTURE ", JSON.stringify(report))
	app.queue_free()
	await root.get_node("SoundBank").shutdown()
	await process_frame
	quit(0 if captures.size() == 10 else 1)


func _capture(app: Control, label: String, captures: Array[String]) -> void:
	app._update_hud(app.world.get_stats())
	app.world.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://captures/v051")
	var path: String = "res://captures/v051/" + label + ".png"
	var saved: Error = root.get_texture().get_image().save_png(path)
	if saved == OK:
		captures.append(path)
	else:
		push_error("Capture failed: " + path)
