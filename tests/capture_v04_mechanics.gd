extends SceneTree
## Deliberate visual state fixture. This does not represent a played run.
const World = preload("res://scripts/game/game_world.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for action: String in ["move_left", "move_right", "move_up", "move_down", "vacuum", "dash", "active_skill"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	root.size = Vector2i(1280, 720)
	var world: Node2D = World.new()
	root.add_child(world)
	world.set_physics_process(false)
	for id: String in ["yard", "foundry", "reactor"]:
		world.start_standard(id, 9431)
		world.wave_index = 6
		world._spawn_boss()
		world._boss.pos = Vector2(680, 310)
		world._boss.spawn = 0.0
		world._boss.hp *= 0.45
		world._boss.stage = 2
		world.player_position = Vector2(530, 475)
		world._director.encounters.spawn_elite(world)
		var elite: Dictionary = world._enemies.back()
		elite.pos = Vector2(985, 535)
		elite.spawn = 0.0
		elite.elite_timer = 0.0
		world._director.elite_velocity(world, elite, Vector2.LEFT, 200, 0.01)
		if id == "yard":
			world._boss_brain._begin_charge(world, world._boss, (Vector2(375, 390) - Vector2(world._boss.pos)).normalized(), 1.0)
		elif id == "foundry":
			world._boss_brain._recover(world._boss)
			world._director.encounters.targets[0].progress = 0.6
		else:
			world._boss_brain._begin_sweep(world._boss, Vector2.DOWN, true)
		world._director.circle_hazard(Vector2(790, 520), 62, 1.2, 2.0, 15, "DAMAGE_PURSUIT")
		world.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://captures")
		var result: Error = root.get_texture().get_image().save_png("res://captures/v04-mechanics-" + id + ".png")
		print("V04_MECHANICS_CAPTURE ", id, " ", result)
	world.queue_free()
	await root.get_node("SoundBank").shutdown()
	await process_frame
	quit()
