extends SceneTree
## Real UI/world signals with short timer fixtures, not a full-length playthrough.

var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func verify(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)


func _finish_wave(world: Node) -> void:
	world.wave_elapsed = float(world.balance.wave_duration) - 0.01
	world._physics_process(0.02)


func _run() -> void:
	var settings: Node = root.get_node("Settings")
	var original_path: String = settings.get_preferences_path()
	var previous: Dictionary = {"locale": settings.locale, "volume": settings.master_volume, "effects": settings.effects_enabled}
	var fixture_path: String = "user://settings-demo-test-%d.cfg" % Time.get_ticks_usec()
	settings.set("_config_path", fixture_path)
	settings.set_locale("en")
	var scene: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var world: Node = scene.world
	# Advance only at explicit fixture points so menu assertions cannot race physics.
	world.set_physics_process(false)
	verify(scene.mode == "menu" and not scene.shop_screen.visible, "Demo shell starts in hangar with shop hidden")
	scene._start_run()
	verify(scene.mode == "playing" and world.demo_mode and scene.last_run_demo and world.wave_index == 1, "Primary start launches demo wave one")
	verify(not scene.boss_panel.visible and not scene.shop_screen.visible and world.get_shop_offers().is_empty(), "Ordinary combat hides shop and boss HUD")
	world.health = 60.0
	world.energy = 43.0
	world._vacuum_gate = false
	world._vacuum = true
	Input.action_press("vacuum")
	_finish_wave(world)
	verify(scene.mode == "shop" and scene.shop_screen.visible and world.phase == "shop", "Wave completion signal opens the real shop screen")
	verify(not world._vacuum and world._vacuum_gate and world.shots == 0 and is_equal_approx(world.energy, 43.0), "Shop transition cancels held suction without discharge or energy loss")
	Input.action_release("vacuum")
	verify(is_equal_approx(world.health, 60.0 + float(world.balance.shop_repair)), "Shop summary accompanies the configured wave repair")
	verify(world.currency >= 22 and scene.shop_summary.bonus == int(world.balance.wave_salary), "Ground recovery and salary fund a first-shop new tool")
	var original_offers: Array = world.get_shop_offers()
	verify(original_offers.size() == 3 and scene.shop_screen.offers == original_offers, "Three actual world offers reach shop cards without rerolling")
	var frozen_time: float = world.elapsed
	var frozen_wave_time: float = world.wave_elapsed
	var frozen_position: Vector2 = world.player_position
	var frozen_health: float = world.health
	Input.action_press("move_right")
	world._physics_process(1.0)
	Input.action_release("move_right")
	verify(world.elapsed == frozen_time and world.wave_elapsed == frozen_wave_time and world.player_position == frozen_position and world.health == frozen_health, "Shop phase freezes combat time, movement and damage")
	scene._pause_run()
	scene._resume_run()
	verify(scene.mode == "shop" and world.phase == "shop" and world.wave_index == 1, "Pause and resume callbacks cannot bypass a shop")
	scene._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	verify(scene.mode == "shop" and scene.shop_screen.visible, "Shop focus loss preserves its decisions screen")
	var new_tool: Dictionary = {}
	var bought_index: int = -1
	for index: int in range(original_offers.size()):
		var offer: Dictionary = original_offers[index]
		if offer.kind == "weapon" and int(offer.level) == 1:
			new_tool = offer
			bought_index = index
			break
	verify(not new_tool.is_empty(), "First shop exposes an unowned weapon purchase")
	if not new_tool.is_empty():
		var balance_before: int = world.currency
		var recovered_before: int = world.total_scrap
		scene._purchase_offer(new_tool.token)
		verify(world.currency == balance_before - int(new_tool.cost) and world.get_stats().loadout.weapons[new_tool.id] == 1, "UI purchase deducts the exact cost and equips the weapon")
		verify(world.total_scrap == recovered_before, "Spending does not alter lifetime recovered parts")
		verify(scene.shop_screen.cards[bought_index].buy.disabled and scene.shop_screen.offers[bought_index].sold, "Successful purchase disables its sold card")
		var disabled_correctly: bool = true
		for index: int in range(scene.shop_screen.offers.size()):
			var offer: Dictionary = scene.shop_screen.offers[index]
			var expected_disabled: bool = bool(offer.sold) or int(offer.cost) > int(world.currency)
			disabled_correctly = disabled_correctly and scene.shop_screen.cards[index].buy.disabled == expected_disabled
		verify(disabled_correctly, "Every shop card recomputes affordability after spending")
		var spent_balance: int = world.currency
		scene._purchase_offer(new_tool.token)
		verify(world.currency == spent_balance and world.get_stats().loadout.weapons[new_tool.id] == 1, "Repeated UI purchase cannot deduct or grant twice")
	var retained_offers: Array = world.get_shop_offers()
	scene._open_settings()
	verify(scene.mode == "settings" and scene.return_mode == "shop" and world.phase == "shop", "Shop settings remember the correct return screen")
	settings.set_locale("zh_CN")
	verify(scene.shop_screen.title_label.text == tr("SHOP_TITLE") % 1 and tr("SHOP_TITLE") != "SHOP_TITLE" and scene.language_option.selected == 1, "Chinese settings relocalize the existing shop")
	world._physics_process(2.0)
	scene._close_settings()
	verify(scene.mode == "shop" and scene.shop_screen.visible and world.elapsed == frozen_time and world.get_shop_offers() == retained_offers, "Returning from Chinese settings preserves offers and frozen combat")
	scene._open_settings()
	settings.set_locale("en")
	scene._close_settings()
	verify(scene.mode == "shop" and scene.shop_screen.title_label.text == tr("SHOP_TITLE") % 1 and world.get_shop_offers() == retained_offers, "English settings return without replacing purchases or offers")
	scene._next_wave()
	verify(scene.mode == "playing" and world.phase == "combat" and world.wave_index == 2 and not scene.shop_screen.visible, "Continue enters exactly wave two")
	scene._next_wave()
	verify(world.wave_index == 2 and scene.mode == "playing", "Repeated continue cannot skip another wave")
	var balance_outside_shop: int = world.currency
	if not new_tool.is_empty():
		scene._purchase_offer(new_tool.token)
	verify(world.currency == balance_outside_shop and world.get_shop_offers().is_empty(), "Combat cannot buy stale shop offers")
	scene._pause_run()
	world._physics_process(1.0)
	verify(scene.mode == "pause" and world.elapsed == frozen_time, "Demo combat still supports a safe pause")
	scene._resume_run()
	verify(scene.mode == "playing" and not world.paused and world.wave_index == 2, "Demo pause resumes its existing wave")
	# The fixture skips waves three and four; world rule tests cover full progression.
	world.wave_index = 5
	_finish_wave(world)
	verify(scene.mode == "shop" and scene.shop_screen.continue_button.text == tr("ENTER_BOSS_ANY"), "Fifth shop presents the final-wave action")
	scene._next_wave()
	verify(world.wave_index == 6 and scene.mode == "playing" and world.active and not world._boss.is_empty(), "Final continue starts an active boss fight without winning")
	verify(scene.boss_panel.visible and scene.boss_bar.value > 0.0 and scene.boss_label.text.contains(tr("BOSS_NAME")), "Boss health and localized name appear in the HUD")
	world.elapsed = float(world.balance.shift_duration) + 1.0
	world.wave_elapsed = float(world.balance.wave_duration) + 1.0
	world._physics_process(0.02)
	verify(world.active and scene.mode == "playing" and scene.final_stats.is_empty(), "Boss combat does not auto-win at the prototype or ordinary-wave time limits")
	# Collect real drops so the result must distinguish recovery from shop balance.
	world.debug_add_scrap(world.player_position, 73)
	world._update_scraps(0.01)
	var recovered_total: int = world.total_scrap
	var wallet_total: int = world.currency
	verify(recovered_total != wallet_total, "Result fixture separates recovered parts from remaining currency")
	world._damage_enemy(world._boss, 100000.0, Vector2.ZERO)
	world._physics_process(0.02)
	verify(scene.mode == "result" and scene.result_screen.visible and scene.final_stats.get("won", false) and not world.active, "Actual boss defeat signal opens the winning result")
	verify(int(scene.final_stats.total_scrap) == recovered_total and scene.result_numbers.text.contains("%s  %03d" % [tr("RESULT_SCRAP"), recovered_total]), "Results display lifetime recovered parts instead of the shop wallet")
	scene._restart_run()
	verify(scene.mode == "playing" and world.demo_mode and world.wave_index == 1 and scene.final_stats.is_empty() and world.currency == 0 and world.total_scrap == 0, "Demo restart preserves mode while clearing its previous run")
	verify(not scene.boss_panel.visible and world.get_stats().loadout.weapons == {"brush": 1, "foam": 0, "arc": 0, "saw": 0, "laser": 0, "missile": 0, "drone": 0, "mines": 0}, "Demo restart clears boss HUD and all eight purchased tool levels")
	scene._start_run(false)
	verify(not world.demo_mode and not scene.last_run_demo and scene.mode == "playing", "Quick-start callback retains the three-minute prototype")
	world.elapsed = float(world.balance.shift_duration) - 0.01
	world._physics_process(0.02)
	verify(scene.mode == "result" and scene.final_stats.get("won", false) and not scene.shop_screen.visible, "Quick shift still ends with its time-based victory")
	scene._restart_run()
	verify(not world.demo_mode and not scene.last_run_demo and world.elapsed == 0.0 and scene.mode == "playing", "Quick-shift restart preserves the quick mode")
	scene._return_to_menu()
	verify(scene.mode == "menu" and not world.active and not scene.shop_screen.visible, "Return to hangar closes the current run")
	settings.set_locale(previous.locale)
	settings.set_volume(previous.volume)
	settings.set_effects(previous.effects)
	settings.set("_config_path", original_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_path))
	for action: String in ["vacuum", "move_right", "move_left", "move_up", "move_down", "dash"]:
		Input.action_release(action)
	root.get_node("SoundBank").stop_all()
	scene.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	print("DEMO_APP_TEST ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
