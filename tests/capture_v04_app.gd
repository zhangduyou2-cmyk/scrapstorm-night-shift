extends SceneTree
## Explicit native presentation fixtures, never a normal gameplay clear.
var scene: Control

func _initialize() -> void:
	_run.call_deferred()

func shot(name: String) -> void:
	scene.queue_redraw()
	scene.world.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var path: String = "res://captures/v04/" + name + ".png"
	print("V04_APP_CAPTURE ", name, " ", root.get_texture().get_image().save_png(path))

func _run() -> void:
	if "--test-settings" not in OS.get_cmdline_user_args():
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	DirAccess.make_dir_recursive_absolute("res://captures/v04")
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var world: Node2D = scene.world
	world.set_physics_process(false)
	var settings: Node = root.get_node("Settings")
	settings.set_tutorial_completed(true)
	for locale: String in ["en", "zh_CN"]:
		settings.set_locale(locale)
		var suffix: String = "zh" if locale == "zh_CN" else "en"
		scene._set_screen("menu")
		await shot("menu-" + suffix)
		scene._open_settings()
		await shot("settings-" + suffix)
		scene._close_settings()
		for skill: String in ["pulse", "overdrive", "singularity"]:
			scene._deploy_standard("foundry" if skill == "overdrive" else ("reactor" if skill == "singularity" else "yard"))
			world._ability.configure({"skill": skill, "skill_color": "cyan"})
			world.skill_color = world._ability.tint
			world.player_position = Vector2(610, 424)
			world.player_aim = Vector2(1, -0.1).normalized()
			world.aim_position = Vector2(800, 360)
			world._visual_time = 3.2
			world._loadout.weapons = {"brush": 2, "foam": 0, "arc": 2, "saw": 2}
			world._loadout.mods.capacitor = 2
			world._loadout.mods.magnet = 2
			world._modifiers = world._loadout.get_modifiers()
			world._ability.choose_branch("pulse_echo" if skill == "pulse" else ("overdrive_turbine" if skill == "overdrive" else "singularity_rupture"), 2)
			world._enemies.clear()
			for index: int in range(17):
				var at := Vector2(155 + (index % 7) * 144, 235 + (index / 7) * 152)
				world.debug_spawn_enemy(at, index % 3)
				world._enemies.back().spawn = 0.0
				world._enemies.back().hp = 200.0
				world._enemies.back().max_hp = 200.0
			world._director.encounters.spawn_elite(world)
			world._enemies.back().pos = Vector2(1080, 480)
			world._enemies.back().spawn = 0.0
			world._ability.activate(world)
			world._ability.tick(world, 0.19)
			world._feedback.tick(0.08, true)
			world._saw_timer = 0.0
			world._update_saws(0.1)
			world._update_saws(0.2)
			world._emit_stats()
			await shot("combat-" + skill + "-" + suffix)
			if skill == "overdrive":
				world.wave_index = 6
				world.elapsed = 922.0
				world.damage_by_source = {"evolution": 2546.0, "arc": 1800.0}
				world.kills = 823
				world.total_scrap = 602
				world._ability.uses = 23
				world._evolution.refresh(world)
				scene._finish_run(true, world.get_stats())
				if is_instance_valid(scene.result_reveal):
					scene.result_reveal.kill()
				scene.result_screen.modulate.a = 1.0
				await shot("result-win-" + suffix)
				root.size = Vector2i(960, 540)
				await shot("result-win-" + suffix + "-960")
				root.size = Vector2i(1280, 720)
				world.active = false
			scene._return_to_menu()
	await root.get_node("SoundBank").shutdown()
	scene.queue_free()
	await process_frame
	quit()
