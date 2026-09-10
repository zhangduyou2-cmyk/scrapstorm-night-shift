extends SceneTree
## Deterministic visual fixture, not a survival or difficulty test.
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
		world.start_standard(id, 841, {"skin": "arctic", "skill_color": "violet"})
		world.wave_index = 6
		world.player_position = Vector2(550, 420)
		world.player_aim = Vector2(0.8, -0.6).normalized()
		world._visual_time = 4.5
		world._loadout.weapons.saw = 2
		world._loadout.weapons.arc = 2
		for kind: int in range(3):
			world.debug_spawn_enemy(Vector2(340 + kind * 300, 510 - kind * 90), kind)
			world._enemies.back().spawn = 0.0
		world._spawn_boss()
		world._boss.spawn = 0.0
		world._boss.pos = Vector2(740, 300)
		world._boss.hp *= 0.45
		world._boss.stage = 2
		world._boss_brain._begin_zone(world, world._boss, true)
		world._director.event_timer = 0
		world._director.tick(world, 0.01)
		world._saw_timer = 0.0
		world._update_saws(0.01)
		world.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://captures")
		var path: String = "res://captures/standard-world-" + id + ".png"
		var result: Error = root.get_texture().get_image().save_png(path)
		print("STANDARD_CAPTURE ", id, " ", result)
	world.queue_free()
	await root.get_node("SoundBank").shutdown()
	await process_frame
	quit()
