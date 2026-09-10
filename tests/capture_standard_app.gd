extends SceneTree
## Native rendering fixtures only. Setups below are not gameplay completion evidence.
var scene: Control


func _initialize() -> void:
	_run.call_deferred()


func _shot(name: String) -> void:
	scene.queue_redraw()
	scene.world.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var path: String = "res://captures/" + name + ".png"
	var result: Error = root.get_texture().get_image().save_png(path)
	print("APP_CAPTURE ", name, " ", result)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.world.set_physics_process(false)
	scene.profile.data.coins = 125
	scene.profile.save()
	for locale: String in ["en", "zh_CN"]:
		root.get_node("Settings").set_locale(locale)
		var suffix: String = "zh" if locale == "zh_CN" else "en"
		scene._set_screen("menu")
		await _shot("menu-v03-" + suffix)
		scene._open_missions()
		await _shot("missions-v03-" + suffix)
		scene._set_screen("menu")
		scene._open_garage()
		scene.garage_screen.category = "skill"
		scene.garage_screen.refresh()
		await _shot("garage-v03-" + suffix)
		scene._set_screen("menu")
		scene._open_settings()
		await _shot("settings-v03-" + suffix)
		scene._close_settings()
		scene._deploy_standard("foundry")
		scene.world.player_position = Vector2(640, 420)
		for index: int in range(12):
			scene.world.debug_spawn_enemy(Vector2(190 + (index % 6) * 180, 220 + (index / 6) * 325), index % 3)
			scene.world._enemies.back().spawn = 0.0
		scene.world._director.event_timer = 0.0
		scene.world._director.tick(scene.world, 0.01)
		scene.world._emit_stats()
		await _shot("gameplay-v03-" + suffix)
		scene.world.wave_index = 6
		scene.world._spawn_boss()
		scene.world._boss.spawn = 0.0
		scene.world._boss.pos = Vector2(770, 300)
		scene.world._boss_brain._begin_zone(scene.world, scene.world._boss, true)
		scene.world._emit_stats()
		scene._complete_tutorial()
		await _shot("boss-v03-" + suffix)
		scene.world._invulnerability = 0.0
		scene.world._damage_player(10000.0, Vector2(680, 420), "DAMAGE_MOLTEN")
		scene.world._physics_process(0.02)
		await _shot("result-v03-" + suffix)
		scene._return_to_menu()
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(scene.profile.path + suffix):
			DirAccess.remove_absolute(scene.profile.path + suffix)
	await root.get_node("SoundBank").shutdown()
	scene.queue_free()
	await process_frame
	quit()
