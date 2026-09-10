extends SceneTree
## Rebuild the original 9-machine / 4-frame / normal-and-hit atlas in Godot.
## The body geometry stays in game_world.gd as the editable source and fallback.
class Baker extends "res://scripts/game/game_world.gd":
	var specimen: Dictionary = {}
	func _draw() -> void:
		if not specimen.is_empty():
			_draw_enemy(specimen)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Atlas baking needs a rendering device.")
		quit(1)
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(80, 80)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var art := Baker.new()
	viewport.add_child(art)
	art.set_physics_process(false)
	art.use_sprite_atlas = false
	var atlas := Image.create_empty(640, 720, false, Image.FORMAT_RGBA8)
	for map_index: int in range(3):
		var id: String = ["yard", "foundry", "reactor"][map_index]
		art.start_standard(id, 17004)
		art.player_position = Vector2(90, 40)
		for kind: int in range(3):
			art.debug_spawn_enemy(Vector2(40, 40), kind)
			art.specimen = art._enemies.back()
			art.specimen.spawn = 0.0
			art.specimen.phase = 0.0
			for frame: int in range(8):
				art._visual_time = (frame % 4) * 0.125
				art.specimen.flash = 1.0 if frame >= 4 else 0.0
				art.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
				atlas.blit_rect(viewport.get_texture().get_image(), Rect2i(0, 0, 80, 80), Vector2i(frame * 80, (map_index * 3 + kind) * 80))
	DirAccess.make_dir_recursive_absolute("res://assets/sprites")
	var result: Error = atlas.save_png("res://assets/sprites/enemy_atlas.png")
	print("ENEMY_ATLAS_BAKE ", result, " / 9 machines, 72 frames, 640x720 RGBA")
	viewport.queue_free()
	await root.get_node("SoundBank").shutdown()
	await process_frame
	quit(0 if result == OK else 1)
