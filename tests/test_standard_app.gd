extends SceneTree
## App integration fixtures. Explicit state setup is not a normal gameplay clear.

const Profile = preload("res://scripts/services/player_profile.gd")
var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func verify(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)


func _run() -> void:
	var settings: Node = root.get_node("Settings")
	settings.set_locale("en")
	settings.set_tutorial_completed(false)
	var scene: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var world: Node = scene.world
	world.set_physics_process(false)
	verify(scene.mode == "menu" and scene.continue_button.disabled, "Fresh hangar exposes standard, quick, workshop and disabled continue")
	scene._open_missions()
	verify(scene.mode == "missions" and scene.mission_screen.cards.size() == 3 and not world.active, "Standard entry opens three sector choices before combat")
	scene.mission_screen.cards[1].button.pressed.emit()
	verify(scene.mission_screen.selected == "foundry", "Map card updates selected sector")
	scene.mission_screen.deploy.pressed.emit()
	verify(scene.mode == "missions" and scene.mission_screen.step == 1 and not world.active, "First dispatch action opens preparation before entering combat")
	verify(scene.profile.owns("skill_pulse") and scene.profile.owns("skill_overdrive"), "Two active blueprints are available without a purchase")
	scene.mission_screen.deploy.pressed.emit()
	verify(scene.mode == "playing" and world.standard_mode and world.map_id == "foundry", "Deploy starts the selected map under standard rules")
	verify(scene.last_run_standard and scene.last_run_demo and world.wave_index == 1, "Standard flow uses five stages and boss progression")
	verify(root.get_node("SoundBank").get_music_state().map_id == "foundry" and root.get_node("SoundBank").get_music_state().phase == "combat", "Selected map controls combat music")
	verify(scene.tutorial_panel.visible and scene.tutorial_step == 0, "First run has an unobtrusive action guide")
	world.player_position += Vector2(80, 0)
	scene._update_tutorial()
	verify(scene.tutorial_step == 1, "Guide advances when movement is performed")
	world._collect_scrap(3)
	scene._update_tutorial()
	verify(scene.tutorial_step == 2, "Guide advances after actual collection")
	world.debug_release()
	scene._update_tutorial()
	verify(scene.tutorial_step == 3, "Guide advances after energy discharge")
	world._dash_cooldown = 1.0
	scene._update_tutorial()
	verify(scene.tutorial_step == 4 and not settings.tutorial_completed, "The guide asks for a charged active ability after dash")
	world._ability.activate(world)
	scene._update_tutorial()
	verify(scene.tutorial_step == -1 and settings.tutorial_completed and not scene.tutorial_panel.visible, "Completed movement/collection/discharge/dash/active guide persists")
	scene._pause_run()
	scene._open_settings()
	verify(scene.mode == "settings" and world.paused and scene.return_mode == "pause", "Expanded settings preserve pause")
	settings.set_locale("zh_CN")
	settings.set_music_volume(0.25)
	settings.set_sfx_volume(0.8)
	settings.set_vacuum_toggle(true)
	verify(scene.music_slider.value == 0.25 and scene.sfx_slider.value == 0.8 and scene.toggle_check.button_pressed, "Independent audio and toggle controls reflect persisted settings")
	verify(scene.control_tips[1].text == tr("TIP_VACUUM_TOGGLE") and scene.language_option.selected == 1, "Toggle instructions and language relocalize together")
	settings.rebind("active_skill", KEY_Q)
	verify(scene.control_tips[4].text.begins_with("Q"), "HUD reflects remapped active ability")
	scene._close_settings()
	scene._resume_run()
	verify(scene.mode == "playing" and not world.paused, "Return from settings resumes the same run")
	world.currency = 350 # Shop affordability fixture, not earned currency evidence.
	world._feedback.reset() # Finish the presentation hold from the explicit skill fixture.
	world.wave_elapsed = world._current_wave_duration() - 0.01
	world._physics_process(0.02)
	verify(scene.mode == "shop" and world.phase == "shop" and not scene.profile.data.checkpoint.is_empty(), "Completed stage opens shop and automatically saves a checkpoint")
	verify(root.get_node("SoundBank").get_music_state().phase == "shop", "Shop music changes intensity without timing the shop")
	var saved_run: String = scene.run_id
	var offers: Array = world.get_shop_offers()
	var price: int = int(offers[0].cost)
	var before: int = int(world.currency)
	scene._purchase_offer(offers[0].token)
	verify(world.currency == before - price and world.get_shop_offers()[0].sold, "Shop purchase changes world exactly once")
	var disk := Profile.new(scene.profile.path)
	verify(disk.data.checkpoint.world.currency == world.currency and disk.data.checkpoint.world.loadout.offers[0].sold, "Purchase is saved with its sold state and exact wallet")
	before = int(world.currency)
	var reroll_price: int = int(world.get_stats().reroll_cost)
	scene._reroll_shop()
	verify(world.currency == before - reroll_price and not world.get_stats().can_reroll, "UI reroll charges once and consumes the opportunity")
	var retained: Array = world.get_shop_offers()
	before = int(world.currency)
	scene._reroll_shop()
	verify(world.currency == before and world.get_shop_offers() == retained, "Repeated refresh cannot mutate wallet or stock")
	var combat_time: float = world.elapsed
	world._physics_process(10.0)
	verify(world.elapsed == combat_time and not scene.profile.data.checkpoint.world.has("shop_time"), "Shop neither advances combat time nor records shop duration")
	scene._request_exit()
	verify(scene.mode == "menu" and not scene.continue_button.disabled and not world.active, "Leaving a standard shop preserves a resumable run")
	scene._open_missions()
	verify(scene.confirm_dialog.visible and scene.mode == "menu", "A new run asks before replacing the saved shift")
	scene.confirm_dialog.hide()
	scene._continue_saved()
	verify(scene.mode == "shop" and scene.run_id == saved_run and world.map_id == "foundry", "Continue restores the same run and sector")
	verify(world.currency == before and world.get_shop_offers() == retained and not world.get_stats().can_reroll, "Restored shop retains exact wallet, offers and used refresh")
	scene._next_wave()
	verify(scene.mode == "playing" and world.wave_index == 2, "Continue advances one saved stage")
	world._physics_process(1.05) # Let the legitimate wave-entry invulnerability expire.
	world.debug_damage_player(10000.0)
	world._physics_process(0.02)
	verify(scene.mode == "result" and not scene.final_stats.won and scene.final_stats.reward.ok, "Loss settles completed stages through the actual result signal")
	verify(scene.profile.data.coins >= 12 and scene.profile.data.checkpoint.is_empty(), "Completed-stage gold persists and the consumed checkpoint is removed")
	before = int(scene.profile.data.coins)
	scene._finish_run(false, scene.final_stats)
	verify(scene.profile.data.coins == before, "Duplicate finish cannot award gold twice")
	scene._return_to_menu()
	scene._open_garage()
	verify(scene.mode == "garage" and scene.garage_screen.profile == scene.profile, "Workshop shares the saved progression profile")
	scene.profile.data.coins = 500 # Explicit unlock fixture.
	scene.profile.save()
	scene.garage_screen.category = "skill"
	scene.garage_screen.refresh()
	scene.garage_screen._purchase(1)
	verify(scene.profile.get_setup().skill == "singularity" and scene.profile.data.coins == 340, "Workshop unlock equips the paid blueprint with exact debit")
	scene.garage_screen.category = "skin"
	scene.garage_screen.refresh()
	scene.garage_screen._purchase(1)
	scene.garage_screen.category = "skill_color"
	scene.garage_screen.refresh()
	scene.garage_screen._purchase(2)
	scene._deploy_standard("reactor")
	verify(world.map_id == "reactor" and world._ability.skill == "singularity" and world._ability.skin == "arctic" and world._ability.color_id == "violet", "Selected skin, ability and energy color enter the next sector")
	verify(not scene.tutorial_panel.visible, "Completed guide is hidden on later runs")
	scene._pause_run()
	scene._request_exit()
	verify(scene.confirm_dialog.visible and world.paused, "Combat exit presents a clear abandonment confirmation")
	scene.confirm_dialog.hide()
	scene.confirm_action.call()
	verify(scene.mode == "result" and not world.active, "Confirmed abandonment settles and stops the run")
	verify(scene.final_stats.get("abandoned", false) and scene.result_title.text == tr("WITHDRAWN"), "Voluntary withdrawal has a distinct result instead of reporting destruction")
	verify(not scene.result_details.text.contains(tr("RESULT_CAUSE").split("%")[0]), "Withdrawal omits a misleading last-damage cause")
	scene._start_run(false)
	verify(not world.standard_mode and world._ability.skill == "singularity" and world.player_skin == "arctic" and world.skill_color == world._ability.COLORS.violet, "Quick Sweep uses the equipped skill and the actual rendered skin and energy tint")
	scene._return_to_menu()
	settings.set_locale("en")
	settings.set_vacuum_toggle(false)
	settings.reset_keys()
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(scene.profile.path + suffix):
			DirAccess.remove_absolute(scene.profile.path + suffix)
	await root.get_node("SoundBank").shutdown()
	scene.queue_free()
	await process_frame
	print("STANDARD_APP_TEST ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
