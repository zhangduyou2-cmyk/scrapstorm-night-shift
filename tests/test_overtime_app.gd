extends SceneTree
## Main-scene integration using real UI signals and disk saves. Room completion,
## affordability and boss damage are explicit state fixtures, not ordinary input play.
const Profile = preload("res://scripts/services/player_profile.gd")
var checks: int = 0
var failures: Array[String] = []
var screenshots: Array[String] = []
var scene: Control
var world: Node2D
var capture: bool = false
var test_path: String

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)

func _run() -> void:
	if "--test-settings" not in OS.get_cmdline_user_args():
		push_error("Overtime app fixture requires --test-settings")
		quit(1)
		return
	capture = "--capture" in OS.get_cmdline_user_args()
	var settings: Node = root.get_node("Settings")
	settings.set_locale("en")
	settings.set_effects(false)
	settings.set_tutorial_completed(true)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	await create_app()
	test_path = scene.profile.path
	check(scene.mode == "menu" and scene.menu.buttons.size() == 8 and scene.continue_button.disabled, "Real main scene exposes eight wired entries and disables missing continuation")
	await snap("overtime-main-menu-en")
	check(scene.profile.equip("skill_overdrive").ok, "Free Overdrive is selected through the actual profile service")
	scene.menu.buttons.quick.pressed.emit()
	check(scene.mode == "playing" and not world.standard_mode and not world.endless_mode and not scene.last_run_endless, "Quick menu entry starts actual Quick rules")
	check(world._ability.skill == "overdrive", "Quick entry inherits selected equipment")
	abandon()
	check(scene.mode == "result" and scene.final_stats.reward.ok and scene.final_stats.abandoned, "Quick exit goes through confirmation and persisted result")
	check(scene.profile.data.history.back().mode == "quick" and scene.profile.data.history.back().coins == 0, "Zero-action Quick fixture records no invented activity payout")
	scene._return_to_menu()
	scene.menu.buttons.standard.pressed.emit()
	check(scene.mode == "missions" and not scene.pending_endless and not scene.mission_screen.endless_mode, "Standard menu entry selects standard deployment context")
	scene.mission_screen.cards[1].button.pressed.emit()
	scene.mission_screen.deploy.pressed.emit()
	scene.mission_screen.deploy.pressed.emit()
	check(scene.mode == "playing" and world.standard_mode and not world.endless_mode and world.map_id == "foundry", "Standard deploy retains the chosen sector and three tool slots")
	check(world._loadout.slots == 3 and not scene.last_run_endless, "Standard does not inherit Overtime's four-slot rules")
	abandon()
	scene._return_to_menu()
	deploy_endless()
	check(scene.mode == "playing" and world.endless_mode and world.standard_mode and scene.last_run_endless and world._loadout.slots == 4, "Primary Overtime entry reaches a real four-slot endless run")
	check(world._ability.skill == "overdrive" and world.wave_index == 1, "Overtime uses the selected free skill and begins in room one")
	finish_room_fixture()
	check(scene.mode == "shop" and world._overtime.completed == 1 and scene.profile.data.checkpoint.world.endless_mode, "Room completion signal opens the real shop and persists Overtime checkpoint")
	var first_run: String = scene.run_id
	var elapsed: float = world.elapsed
	world._physics_process(300.0)
	check(world.elapsed == elapsed and not scene.profile.data.checkpoint.world.has("shop_time"), "Actual shop leaves combat time unchanged and stores no shop duration")
	scene.shop_screen.next_wave_requested.emit()
	check(scene.mode == "route" and scene.overtime_screen.cards.size() == 3 and scene.overtime_screen.onward.disabled, "Shop's continue signal opens three route options before launch")
	check(not scene.overtime_screen.extract.visible, "Ordinary-room route cannot offer safe extraction")
	var button: Button = scene.overtime_screen.cards[0].button
	var background: Color = button.get_theme_stylebox("normal").bg_color
	var foreground: Color = button.get_theme_color("font_color")
	check(contrast(foreground, background) >= 4.5, "Available route button text is legible against its normal background")
	await snap("overtime-route-unselected-en")
	var choices: Array = world.get_stats().route_choices
	var boon: String = choices[0].boon
	scene.overtime_screen.cards[0].button.pressed.emit()
	check(world._overtime.choice == 0 and world._overtime.rank(boon) == 1 and not scene.overtime_screen.onward.disabled, "Choosing one route installs its single boon and enables deployment")
	check(scene.profile.data.checkpoint.world.overtime.choice == 0 and scene.profile.data.checkpoint.world.overtime.boons[boon] == 1, "Selected route and installed rank reach the disk checkpoint")
	var disk: RefCounted = Profile.new(test_path)
	check(disk.data.checkpoint.world.overtime.choice == 0 and int(disk.data.checkpoint.world.ability.uses) == 1, "Disk reload preserves route choice and actual active-skill use counter")
	settings.set_locale("zh_CN")
	root.size = Vector2i(960, 540)
	await snap("overtime-route-selected-zh-960")
	scene.overtime_screen.back.pressed.emit()
	scene.shop_screen.menu_requested.emit()
	check(scene.mode == "menu" and not world.active and not scene.continue_button.disabled, "Back to shop and menu retains a resumable selected route")
	# Destroy and recreate the actual application scene against the same PID save.
	scene.queue_free()
	await process_frame
	await create_app()
	check(scene.mode == "menu" and scene.profile.data.checkpoint.run_id == first_run, "New main-scene instance discovers its actual on-disk continuation")
	scene.menu.buttons["continue"].pressed.emit()
	check(scene.mode == "shop" and scene.last_run_endless and world.endless_mode and scene.run_id == first_run, "Continue entry restores mode, sector and exact run identity")
	check(world._overtime.choice == 0 and world._overtime.rank(boon) == 1 and world._ability.uses == 1, "Selected route's boon and skill statistics survive actual app recreation")
	scene.shop_screen.next_wave_requested.emit()
	check(scene.mode == "route" and not scene.overtime_screen.onward.disabled and scene.overtime_screen.cards[0].button.disabled, "Restored route remains selected rather than asking for another reward")
	scene.overtime_screen.cards[1].button.pressed.emit()
	check(world._overtime.choice == 0 and world._overtime.rank(boon) == 1, "Repeated route signal cannot grant a second boon after restart")
	scene.overtime_screen.onward.pressed.emit()
	check(scene.mode == "playing" and world.wave_index == 2 and world._overtime.completed == 1, "Selected route deploys exactly the next room")
	finish_room_fixture()
	choose_and_launch(1)
	check(world.wave_index == 3 and not world._boss.is_empty(), "Second route reaches an actual boss encounter")
	finish_room_fixture()
	check(scene.mode == "shop" and world._overtime.completed == 3 and world.boss_kills == 1 and world._ability.uses == 3, "Boss fixture updates real boss and skill counters before checkpoint")
	scene.shop_screen.next_wave_requested.emit()
	check(scene.mode == "route" and scene.overtime_screen.extract.visible and scene.overtime_screen.onward.disabled, "Completed boss offers extraction without demanding another route choice")
	settings.set_locale("en")
	root.size = Vector2i(1280, 720)
	await snap("overtime-boss-route-en")
	scene.overtime_screen.extract.pressed.emit()
	check(scene.mode == "result" and scene.final_stats.extracted and scene.final_stats.reward.ok and not world.active, "Extraction signal finishes and settles the actual main result")
	check(scene.result_title.text == tr("OT_EXTRACTED") and scene.profile.data.checkpoint.is_empty(), "Extraction has distinct result copy and consumes the saved checkpoint")
	var entry: Dictionary = scene.profile.data.history.back()
	check(entry.mode == "endless" and entry.extracted and entry.rooms == 3 and entry.cycles == 1 and entry.boss_kills == 1, "Main settlement writes complete endless extraction history")
	if float(entry.boss_damage_taken) == 0.0:
		print("OVERTIME_EXTRACTION_DAMAGE_DIAGNOSTIC ", JSON.stringify({"entry": entry, "reward": scene.final_stats.reward}))
	check(entry.skill == "overdrive" and entry.skill_uses == 3 and entry.boss_damage_taken > 0, "History keeps the exact active skill, real casts and tracked boss damage")
	check(scene.final_stats.reward.new_achievements.has("overtime_3") and scene.final_stats.reward.new_achievements.has("safe_extraction"), "Main result includes newly earned endless achievements")
	var coins: int = int(scene.profile.data.coins)
	var runs: int = scene.profile.data.history.size()
	scene._finish_run(true, scene.final_stats)
	check(scene.profile.data.coins == coins and scene.profile.data.history.size() == runs, "Duplicate main finish cannot repeat extraction coins or history")
	await snap("overtime-extraction-result-en")
	scene._return_to_menu()
	scene.menu.buttons.archive.pressed.emit()
	check(scene.mode == "archive" and scene.archive_screen.current_tab == "history" and scene.archive_screen.selected_run == first_run, "Main history entry opens the actual latest extracted battle")
	await snap("overtime-main-history-en")
	scene.archive_screen.back_button.pressed.emit()
	scene.menu.buttons.achievements.pressed.emit()
	check(scene.mode == "archive" and scene.archive_screen.current_tab == "achievements", "Separate achievements menu entry selects the correct archive tab")
	scene.archive_screen.back_button.pressed.emit()
	# Replace an older saved Overtime boss checkpoint with another mode.
	deploy_endless()
	for room: int in range(1, 4):
		finish_room_fixture()
		if room < 3:
			choose_and_launch(0)
	var replaced_id: String = scene.run_id
	var expected_skill_uses: int = world._ability.uses
	var expected_rooms: int = world._overtime.completed
	var expected_bosses: int = world.boss_kills
	var expected_base: int = expected_rooms * 8 + expected_bosses * 20 + mini(10, int(world.kills) / 20)
	scene.shop_screen.menu_requested.emit()
	check(scene.mode == "menu" and scene.profile.data.checkpoint.run_id == replaced_id, "Second boss shop remains saved while away at the hangar")
	scene.menu.buttons.standard.pressed.emit()
	check(scene.confirm_dialog.visible and scene.mode == "menu", "Replacing a saved Overtime run requires the existing explicit replacement confirmation")
	scene.confirm_dialog.hide()
	scene.confirm_dialog.confirmed.emit()
	check(scene.mode == "missions" and not scene.pending_endless and scene.profile.data.checkpoint.is_empty(), "Confirmed replacement settles Overtime and then opens standard missions")
	entry = scene.profile.data.history.back()
	check(entry.run_id == replaced_id and entry.mode == "endless" and entry.rooms == expected_rooms and entry.boss_kills == expected_bosses, "Replacement normalizes nested checkpoint progression through world restoration")
	check(entry.skill == "overdrive" and entry.skill_uses == expected_skill_uses and expected_skill_uses == 3, "Replacement preserves saved Overdrive and casts instead of defaulting to Pulse / zero")
	if int(entry.coins) != expected_base:
		print("OVERTIME_REPLACEMENT_REWARD_DIAGNOSTIC ", JSON.stringify({"expected_base": expected_base, "entry": entry, "achievements": scene.profile.data.achievements}))
	check(entry.abandoned and not entry.extracted and not entry.won and entry.coins == expected_base, "Replacing continuation is an early ending with completed-content reward and no extraction bonus")
	check(not scene.profile.data.achievements.has("flawless_shift") and not scene.profile.data.records.has("yard"), "Endless replacement cannot create standard clear or no-hit achievements")
	scene.mission_screen.back_requested.emit()
	settings.set_locale("zh_CN")
	root.size = Vector2i(960, 540)
	await snap("overtime-main-menu-zh-960")
	scene.menu.buttons.archive.pressed.emit()
	check(scene.archive_screen.history_items[0].abandoned and scene.archive_screen.history_items[0].skill == "overdrive", "Main history exposes the replaced continuation's honest early-ending record")
	await snap("overtime-replaced-history-zh-960")
	scene.archive_screen.back_button.pressed.emit()
	scene.menu.buttons.quick.pressed.emit()
	check(scene.mode == "playing" and not world.endless_mode and not scene.last_run_endless, "Quick remains reachable after endless continuation replacement")
	abandon()
	check(scene.profile.data.history.back().mode == "quick" and scene.final_stats.reward.ok, "Later Quick settlement remains independent of prior Overtime progression")
	# One real physics tick resolves a lethal projectile and a lethal brush hit.
	# Only placement, health and timer are fixtures; main receives the normal signal.
	scene._return_to_menu()
	deploy_endless()
	for room: int in range(1, 3):
		finish_room_fixture()
		choose_and_launch(0)
	world._obstacles.clear()
	world._director.clear_stage()
	world._projectiles.clear()
	world.player_position = Vector2(640, 400)
	world.health = 1.0
	world._invulnerability = 0.0
	world._dash_left = 0.0
	world._overtime.shield = 0.0
	world._boss.pos = Vector2(705, 400)
	world._boss.spawn = 0.0
	world._boss.hp = 0.001
	world._boss.state = "exposed"
	world._boss.state_timer = 10.0
	world._brush_timer = 0.0
	world._projectiles.append({"pos": world.player_position, "vel": Vector2.ZERO, "life": 2.0, "radius": 6.0, "damage": 100.0, "boss": true})
	world._physics_process(1.0 / 60.0)
	check(scene.mode == "result" and not scene.final_stats.won and scene.final_stats.reward.ok, "Same-tick boss kill and player death still produces a saved failure result")
	check(world.health == 0.0 and not world.active and world.phase == "finished", "Mutual destruction does not enter a shop, repair or revive the player")
	entry = scene.profile.data.history.back()
	check(entry.rooms == 3 and entry.boss_kills == 1 and not entry.extracted and entry.damage_taken > 0.0, "Mutual destruction preserves completed boss room and actual damage with no extraction flag")
	coins = scene.profile.data.coins
	runs = scene.profile.data.history.size()
	scene._finish_run(false, scene.final_stats)
	check(scene.profile.data.coins == coins and scene.profile.data.history.size() == runs, "Repeating a mutual-destruction result cannot pay twice")
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(test_path + suffix):
			DirAccess.remove_absolute(test_path + suffix)
	await root.get_node("SoundBank").shutdown()
	scene.queue_free()
	await process_frame
	print("OVERTIME_APP_TEST ", JSON.stringify({"checks": checks, "failures": failures, "screenshots": screenshots, "state_fixture": true}))
	quit(0 if failures.is_empty() else 1)

func create_app() -> void:
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	world = scene.world
	world.set_physics_process(false)

func abandon() -> void:
	scene._pause_run()
	scene._request_exit()
	scene.confirm_dialog.hide()
	scene.confirm_dialog.confirmed.emit()

func deploy_endless() -> void:
	scene.menu.buttons.overtime.pressed.emit()
	scene.mission_screen.cards[0].button.pressed.emit()
	scene.mission_screen.deploy.pressed.emit()
	scene.mission_screen.deploy.pressed.emit()

func finish_room_fixture() -> void:
	world._ability.clear_effects()
	world._ability.charge = 100.0
	world._ability.activate(world)
	world.elapsed += 65.0
	world.wave_elapsed = world._current_wave_duration()
	world.kills += 24 # Explicit activity fixture; no ordinary-input claims.
	world._collect_scrap(60)
	if world._overtime.boss_room():
		# This explicit injured-boss fixture must remain injured with any random
		# route. Cast Shield is granted synchronously by the activation above.
		world._invulnerability = 0.0
		world._dash_left = 0.0
		world._overtime.shield = 0.0
		var damage_before: float = world.boss_damage_taken
		world._damage_player(9.0, Vector2.ZERO)
		check(world.boss_damage_taken > damage_before, "Injured-boss fixture records real damage after clearing temporary defenses")
		world._damage_enemy(world._boss, 1000000.0, Vector2.ZERO, "brush")
	world._complete_wave()

func choose_and_launch(index: int) -> void:
	scene.shop_screen.next_wave_requested.emit()
	scene.overtime_screen.cards[index].button.pressed.emit()
	scene.overtime_screen.onward.pressed.emit()

func snap(label: String) -> void:
	if not capture:
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://captures/v05")
	var destination: String = "res://captures/v05/" + label + ".png"
	var saved: Error = root.get_texture().get_image().save_png(destination)
	check(saved == OK, "Main-scene screenshot " + label + " saves")
	if saved == OK:
		screenshots.append(destination)

func contrast(first: Color, second: Color) -> float:
	var a: Color = first.srgb_to_linear()
	var b: Color = second.srgb_to_linear()
	var one: float = a.r * 0.2126 + a.g * 0.7152 + a.b * 0.0722
	var two: float = b.r * 0.2126 + b.g * 0.7152 + b.b * 0.0722
	return (maxf(one, two) + 0.05) / (minf(one, two) + 0.05)
