extends SceneTree
## Reproducible UI fixture captures. These are staged screens, not playthroughs.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var screen := "shop"
	var locale := "en"
	var output := "res://captures/demo-fixture.png"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--screen="):
			screen = argument.trim_prefix("--screen=")
		elif argument.begins_with("--locale="):
			locale = argument.trim_prefix("--locale=")
		elif argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	var settings: Node = root.get_node("Settings")
	settings.set_locale(locale)
	var app: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app._start_run()
	app.world.start_run(73, true)
	app.world.set_physics_process(false)
	if screen == "menu":
		app._return_to_menu()
	else:
		var count: int = 5 if screen == "boss" else 1
		for wave: int in range(count):
			app.world.wave_elapsed = 54.99
			app.world.health = 68.0
			app.world._physics_process(0.02)
			if wave < count - 1 or screen == "boss":
				for offer: Dictionary in app.world.get_shop_offers():
					if offer.kind == "weapon":
						app._purchase_offer(offer.token)
				app._next_wave()
		if screen == "boss":
			for tick: int in range(170):
				app.world._physics_process(1.0 / 60.0)
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(output)
	print("DEMO_CAPTURE ", JSON.stringify({"fixture": true, "screen": screen, "locale": locale, "output": output, "result": result, "stats": app.world.get_stats()}))
	root.get_node("SoundBank").stop_all()
	app.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	quit(0 if result == OK else 1)
