extends SceneTree
## Portfolio screenshots rendered from actual v0.5.1 UI; three scenes use disclosed fixtures.
var app: Control
var images: Array[Dictionary] = []
var failures: Array[String] = []
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	if "--test-settings" not in OS.get_cmdline_user_args():
		push_error("Gallery capture requires isolated --test-settings")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var settings: Node = root.get_node("Settings")
	settings.set_locale("en")
	settings.set_tutorial_completed(true)
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	app.world.set_physics_process(false)
	await snap("v051-hangar", "Default menu with a fresh isolated profile; no awarded progress.")
	# Staged boss and entities use actual counter behavior and unmodified drawing.
	app._deploy_standard("yard")
	var world: Node2D = app.world
	world.set_physics_process(false)
	app.tutorial_panel.visible = false
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
	world._enemies.back().merge({"spawn":0.0,"boss_add":true,"boss_battery":true}, true)
	world.debug_spawn_enemy(Vector2(540, 290), 1)
	world._enemies.back().merge({"spawn":0.0,"boss_add":true}, true)
	world._director.encounters._break_boss(world)
	world._feedback.tick(0.3, true)
	app._update_hud(world.get_stats())
	world.queue_redraw()
	await snap("v051-counter", "Staged boss, positions and pre-counter resources. Actual break behavior and six-second HUD; not earned gameplay or a playthrough.")
	# Legal four-slot layout with explicit resources and two evolved prerequisites.
	app._deploy_overtime("reactor")
	world.set_physics_process(false)
	world._loadout.weapons.laser = 2
	world._loadout.weapons.arc = 2
	world._loadout.weapons.drone = 1
	world._loadout.mods.capacitor = 2
	world._loadout.mods.magnet = 2
	world._refresh_modifiers()
	world.currency = 210
	world._earned_currency = 210
	world.elapsed = 65.0
	world.wave_elapsed = 65.0
	world._complete_wave()
	await snap("v051-build", "Staged four-slot inventory, modifiers, wallet and first room clock. Actual shop offers and evolution requirements; not a purchased or earned build.")
	# A sample completed shift goes through the real profile settlement API.
	world.active = false
	var sample: Dictionary = {"standard_mode":true,"map_id":"yard","wave":6,"elapsed":920.0,
		"kills":210,"total_scrap":1110,"boss_kills":1,"damage_taken":0.0,"damage_events":0,
		"boss_damage_taken":0.0,"metrics_known":true,"ability_id":"pulse","ability_uses":6,
		"loadout":{"weapons":{"brush":2,"saw":2},"mods":{"magnet":2}},"evolutions_seen":["steel_storm"]}
	var settlement: Dictionary = app.profile.settle("public-gallery-fixture", sample, true)
	if not settlement.get("ok", false):
		failures.append("Staged profile settlement failed")
	app._open_archive("achievements")
	app.archive_screen._choose_achievement("flawless_shift")
	await snap("v051-achievements", "Achievement display populated by a staged successful run through the actual settlement service. Aurora is a previewed reward, not a claim of human completion.")
	var profile_path: String = app.profile.path
	await root.get_node("SoundBank").shutdown()
	app.queue_free()
	await process_frame
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(profile_path + suffix):
			DirAccess.remove_absolute(profile_path + suffix)
	var settings_path: String = settings.get_preferences_path()
	if FileAccess.file_exists(settings_path):
		DirAccess.remove_absolute(settings_path)
	var report: Dictionary = {"version":"0.5.1","resolution":[1280,720],"renderer":"Godot Compatibility native",
		"post_processing":"None. PNG captures are copied byte-for-byte to docs/media.","images":images,"failures":failures,
		"limitations":"Screenshots prove rendering only. Fixture state is disclosed per image; no playthrough, player win-rate, browser or performance claim."}
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var file := FileAccess.open("res://artifacts/public-gallery-v051.json", FileAccess.WRITE)
	if file == null:
		push_error("Cannot write gallery report")
		quit(1)
		return
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("PUBLIC_GALLERY ", JSON.stringify(report))
	quit(0 if failures.is_empty() and images.size() == 4 else 1)
func snap(name: String, provenance: String) -> void:
	var pointer := InputEventMouseMotion.new()
	pointer.position = Vector2(12, 12)
	pointer.global_position = pointer.position
	root.push_input(pointer)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://captures/public-gallery-v051")
	var path: String = "res://captures/public-gallery-v051/" + name + ".png"
	var error: Error = root.get_texture().get_image().save_png(path)
	if error == OK:
		images.append({"path":path.trim_prefix("res://"),"provenance":provenance})
	else:
		failures.append("Capture failed: " + name)
