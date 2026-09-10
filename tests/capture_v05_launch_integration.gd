extends SceneTree
## Real application scene, isolated settings/profile. Signal-driven navigation only.
## Browser ordinary-input smoke remains separate from this visual capture fixture.
var scene: Control
var captures: Array[String] = []
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if "--test-settings" not in OS.get_cmdline_user_args():
		push_error("Requires --test-settings")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.get_node("Settings").set_locale("en")
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	for window_size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(960, 540), Vector2i(2554, 1513)]:
		root.size = window_size
		for language: String in ["en", "zh_CN"]:
			root.get_node("Settings").set_locale(language)
			await snap("main-launch-%dx%d-%s" % [window_size.x, window_size.y, language])
	root.size = Vector2i(1280, 720)
	root.get_node("Settings").set_locale("en")
	scene.menu.buttons.overtime.pressed.emit()
	await snap("main-overtime-sectors-en")
	scene.mission_screen.deploy.pressed.emit()
	await snap("main-overtime-preparation-en")
	scene.mission_screen._back()
	scene.mission_screen._back()
	scene.menu.buttons.standard.pressed.emit()
	await snap("main-standard-sectors-en")
	scene.mission_screen._back()
	scene.menu.buttons.garage.pressed.emit()
	await snap("main-workshop-en")
	scene.garage_screen.back_requested.emit()
	scene.menu.buttons.archive.pressed.emit()
	await snap("main-archive-en")
	scene.archive_screen.back_requested.emit()
	scene.menu.buttons.achievements.pressed.emit()
	await snap("main-achievements-en")
	scene.archive_screen.back_requested.emit()
	scene.menu.buttons.settings.pressed.emit()
	root.get_node("Settings").set_locale("zh_CN")
	root.size = Vector2i(960, 540)
	await snap("main-settings-zh-960")
	var profile_path: String = scene.profile.path
	await root.get_node("SoundBank").shutdown()
	scene.queue_free()
	await process_frame
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(profile_path + suffix):
			DirAccess.remove_absolute(profile_path + suffix)
	var result: Dictionary = {"screenshots": captures, "failures": failures, "fixture": "Real main.tscn with actual project canvas_items/keep scaling; isolated profile. Entry navigation via real signal connections, not ordinary-input browser testing."}
	var file := FileAccess.open("res://artifacts/v05-main-visual-validation.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(result, "  ") + "\n")
	print("V05_MAIN_CAPTURE ", JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)

func snap(name: String) -> void:
	var pointer := InputEventMouseMotion.new()
	pointer.position = Vector2(12, 12)
	pointer.global_position = pointer.position
	root.push_input(pointer)
	await process_frame
	await create_timer(0.09).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://captures/v05")
	var path: String = "res://captures/v05/" + name + ".png"
	var result: int = root.get_texture().get_image().save_png(path)
	if result == OK:
		captures.append(path.trim_prefix("res://"))
	else:
		failures.append(name)
