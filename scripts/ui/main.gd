extends Control
## Application shell: menus, localization, HUD and safe focus transitions.

const BG := Color("101c24")
const PANEL := Color("1c2c34")
const INK := Color("ede3ce")
const MUTED := Color("819aa6")
const GOLD := Color("ffc04d")
const MINT := Color("58d9e7")
const RED := Color("ff795a")
const Loadout = preload("res://scripts/game/run_loadout.gd")
const Achievements = preload("res://scripts/services/achievement_catalog.gd")
const Profile = preload("res://scripts/services/player_profile.gd")
const HangarVisual = preload("res://scripts/ui/hangar_visual.gd")
const Kit = preload("res://scripts/ui/ui_kit.gd")

var pending_endless: bool = false
var last_run_endless: bool = false
var overtime_screen: Control
var archive_screen: Control
var world: Node2D
var ui: Control
var menu: Control
var hud: Control
var pause_screen: Control
var settings_screen: Control
var result_screen: Control
var shop_screen: Control
var shop_summary: Dictionary = {}
var last_run_demo: bool = true
var equipment_label: Label
var repair_hint_label: Label
var boss_panel: Control
var boss_bar: ProgressBar
var boss_window_bar: ProgressBar
var boss_label: Label
var bindings: Array[Dictionary] = []
var mode: String = "menu"
var return_mode: String = "menu"
var display_stats: Dictionary = {}
var final_stats: Dictionary = {}
var time_label: Label
var health_label: Label
var scrap_label: Label
var kills_label: Label
var energy_label: Label
var phase_label: Label
var health_bar: ProgressBar
var energy_bar: ProgressBar
var dash_bar: ProgressBar
var language_option: OptionButton
var volume_slider: HSlider
var effects_check: CheckButton
var result_title: Label
var result_desc: Label
var result_numbers: Label
var elapsed_visual: float = 0.0
var hangar_visible: bool = true
var smoke_mode: bool = false
var diagnostic_timer: float = 0.0
var capture_path: String = ""
var capture_remaining: float = 2.0
var profile: RefCounted
var run_id: String = ""
var last_run_standard: bool = false
var selected_map: String = "yard"
var mission_screen: Control
var garage_screen: Control
var continue_button: Button
var quick_button: Button
var profile_label: Label
var objective_label: Label
var combo_label: Label
var ability_label: Label
var ability_bar: ProgressBar
var skill_gauge: Control
var ability_status: Label
var notice_label: Label
var _last_ability_state: String = ""
var music_slider: HSlider
var sfx_slider: HSlider
var toggle_check: CheckButton
var key_buttons: Dictionary = {}
var key_hint: Label
var awaiting_key: String = ""
var control_tips: Array[Label] = []
var confirm_dialog: ConfirmationDialog
var confirm_action: Callable
var result_reward: Label
var result_details: Label
var result_build: Label
var result_badges: Label
var result_reveal: Tween
var tutorial_panel: Control
var tutorial_label: Label
var tutorial_step: int = -1
var tutorial_origin: Vector2 = Vector2.ZERO
var tutorial_start_scrap: int = 0
var tutorial_start_shots: int = 0
var tutorial_start_abilities: int = 0


func _ready() -> void:
	_configure_input()
	var profile_path: String = "user://profile.json"
	if OS.get_cmdline_user_args().has("--test-settings"):
		profile_path = "user://profile-test-%d.json" % OS.get_process_id()
	profile = Profile.new(profile_path)
	var shared_theme := Theme.new()
	shared_theme.default_font = load("res://assets/fonts/NotoSansCJKsc-Regular.otf")
	shared_theme.default_font_size = 16
	theme = shared_theme
	world = load("res://scripts/game/game_world.gd").new()
	world.name = "GameWorld"
	add_child(world)
	world.stats_changed.connect(_update_hud)
	world.run_finished.connect(_finish_run)
	world.wave_completed.connect(_open_shop)
	world.sound_requested.connect(SoundBank.play)
	world.visible = false
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	ui = Control.new()
	ui.name = "Interface"
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = shared_theme
	layer.add_child(ui)
	_build_menu()
	_build_hud()
	_build_pause()
	_build_settings()
	_build_result()
	mission_screen = load("res://scripts/ui/mission_panel.gd").new()
	ui.add_child(mission_screen)
	mission_screen.deploy_requested.connect(_deploy_selected)
	mission_screen.back_requested.connect(func() -> void: _set_screen("menu"))
	mission_screen.present(profile)
	garage_screen = load("res://scripts/ui/garage_panel.gd").new()
	ui.add_child(garage_screen)
	garage_screen.back_requested.connect(func() -> void: _set_screen("menu"))
	garage_screen.present(profile)
	shop_screen = load("res://scripts/ui/shop_panel.gd").new()
	ui.add_child(shop_screen)
	shop_screen.purchase_requested.connect(_purchase_offer)
	shop_screen.reroll_requested.connect(_reroll_shop)
	shop_screen.next_wave_requested.connect(_next_wave)
	shop_screen.settings_requested.connect(_open_settings)
	shop_screen.menu_requested.connect(_request_exit)
	shop_screen.branch_requested.connect(_choose_branch)
	shop_screen.sell_requested.connect(_sell_tool)
	overtime_screen = load("res://scripts/ui/overtime_panel.gd").new()
	ui.add_child(overtime_screen)
	overtime_screen.route_requested.connect(_choose_route)
	overtime_screen.back_requested.connect(func() -> void:
		shop_screen.present(world.get_shop_offers(), world.get_stats(), shop_summary)
		_set_screen("shop")
	)
	overtime_screen.continue_requested.connect(_launch_overtime_room)
	overtime_screen.extract_requested.connect(func() -> void:
		if mode == "route":
			world.extract_overtime()
	)
	archive_screen = load("res://scripts/ui/archive_panel.gd").new()
	ui.add_child(archive_screen)
	archive_screen.back_requested.connect(func() -> void: _set_screen("menu"))
	confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.size = Vector2i(610, 220)
	confirm_dialog.confirmed.connect(func() -> void:
		if confirm_action.is_valid():
			confirm_action.call()
	)
	add_child(confirm_dialog)
	Settings.preferences_changed.connect(_refresh_localization)
	_refresh_localization()
	_set_screen("menu")
	if OS.has_feature("web"):
		smoke_mode = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('smoke')"))
	if "--smoke-start" in OS.get_cmdline_user_args():
		_start_run()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			capture_path = argument.trim_prefix("--capture=")
		elif argument.begins_with("--capture-delay="):
			capture_remaining = maxf(0.1, argument.trim_prefix("--capture-delay=").to_float())
	queue_redraw()


func _configure_input() -> void:
	Settings.apply_input_bindings()
	var keys := {"pause": KEY_ESCAPE}
	for action: String in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var event := InputEventKey.new()
		event.physical_keycode = keys[action]
		InputMap.action_add_event(action, event)
	if not InputMap.has_action("vacuum"):
		InputMap.add_action("vacuum")
	InputMap.action_erase_events("vacuum")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("vacuum", mouse)


func _process(delta: float) -> void:
	elapsed_visual += delta
	if mode == "playing" and tutorial_step >= 0:
		_update_tutorial()
	if not capture_path.is_empty() and capture_remaining > 0.0:
		capture_remaining -= delta
		if capture_remaining <= 0.0:
			_save_capture.call_deferred()
	if smoke_mode:
		diagnostic_timer -= delta
		if diagnostic_timer <= 0.0:
			diagnostic_timer = 0.1
			_publish_diagnostics()
	if hangar_visible:
		queue_redraw()


func _publish_diagnostics() -> void:
	var pos: Vector2 = world.player_position
	var payload := {"ui_started": true, "mode": mode, "locale": Settings.locale, "stats": world.get_stats(), "result": final_stats, "position": {"x": pos.x, "y": pos.y}, "fps": Engine.get_frames_per_second()}
	payload["shop_offers"] = world.get_shop_offers()
	payload["shop_summary"] = shop_summary
	payload["selected_map"] = selected_map
	payload["mission_step"] = mission_screen.step
	payload["profile"] = {"coins": profile.data.coins, "owned": profile.data.owned, "selected": profile.data.selected, "has_checkpoint": not profile.data.checkpoint.is_empty()}
	payload.profile["history_count"] = profile.data.history.size()
	payload.profile["achievement_count"] = profile.data.achievements.size()
	payload["archive_tab"] = archive_screen.current_tab
	payload["music"] = SoundBank.get_music_state()
	# Visible arena observations let input-only browser checks react to enemies.
	# Published only with ?smoke=1; there is no state-changing browser hook.
	var enemies: Array[Dictionary] = []
	for enemy: Dictionary in world._enemies:
		var position: Vector2 = enemy["pos"]
		var direction: Vector2 = enemy.get("charge_dir", Vector2.ZERO)
		enemies.append({"x": position.x, "y": position.y, "kind": enemy["kind"], "radius": enemy["radius"], "spawn": enemy["spawn"], "windup": enemy["windup"], "charge": enemy["charge"], "dx": direction.x, "dy": direction.y})
	var scraps: Array[Dictionary] = []
	for scrap: Dictionary in world._scraps:
		var position: Vector2 = scrap["pos"]
		scraps.append({"x": position.x, "y": position.y, "value": scrap["value"]})
	payload["observations"] = {"enemies": enemies, "scraps": scraps}
	JavaScriptBridge.eval("window.__scrapstorm = " + JSON.stringify(payload) + ";")


func _save_capture() -> void:
	await RenderingServer.frame_post_draw
	var shot := get_viewport().get_texture().get_image()
	var result := shot.save_png(capture_path)
	print("NATIVE_CAPTURE ", JSON.stringify({"mode": mode, "locale": Settings.locale, "image": capture_path, "result": result, "stats": world.get_stats()}))
	await SoundBank.shutdown()
	get_tree().quit(0 if result == OK else 1)


func _input(event: InputEvent) -> void:
	if not awaiting_key.is_empty() and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			awaiting_key = ""
			_refresh_localization()
		elif Settings.rebind(awaiting_key, event.physical_keycode):
			awaiting_key = ""
			_refresh_localization()
		else:
			key_hint.text = tr("KEY_CONFLICT")
		get_viewport().set_input_as_handled()
		return


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if mode == "playing":
			_pause_run()
		elif mode == "pause":
			_resume_run()
		elif mode == "settings":
			_close_settings()
		elif mode == "route":
			shop_screen.present(world.get_shop_offers(), world.get_stats(), shop_summary)
			_set_screen("shop")
		elif mode in ["missions", "garage", "archive"]:
			_set_screen("menu")
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and is_instance_valid(world):
		world.cancel_input()
		if mode == "playing":
			_pause_run()


func _surface(parent: Control, rect: Rect2, color: Color, border: Color = Color.TRANSPARENT) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1 if border.a > 0.0 else 0)
	style.set_corner_radius_all(2)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel


func _label(parent: Control, key: String, pos: Vector2, box: Vector2, font_size: int = 16, color: Color = INK) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = box
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	if key.begins_with("="):
		label.text = key.substr(1)
	else:
		bindings.append({"node": label, "key": key})
		label.text = tr(key)
	return label


func _button(parent: Control, key: String, rect: Rect2, callback: Callable, primary: bool = false) -> Button:
	var button := Kit.button(parent, rect, func() -> void:
		SoundBank.play("ui")
		callback.call()
	, primary)
	bindings.append({"node": button, "key": key})
	button.text = tr(key)
	return button


func _screen() -> Control:
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(screen)
	return screen


func _dim(screen: Control) -> void:
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.018, 0.035, 0.05, 0.88)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	screen.add_child(shade)


func _build_menu() -> void:
	menu = load("res://scripts/ui/launch_hangar.gd").new()
	menu.configure(profile)
	ui.add_child(menu)
	menu.overtime_requested.connect(_open_overtime)
	menu.standard_requested.connect(_open_missions)
	menu.quick_requested.connect(_request_quick)
	menu.garage_requested.connect(_open_garage)
	menu.archive_requested.connect(func() -> void: _open_archive("history"))
	menu.achievements_requested.connect(func() -> void: _open_archive("achievements"))
	menu.settings_requested.connect(_open_settings)
	menu.continue_requested.connect(_continue_saved)
	continue_button = menu.buttons["continue"]
	quick_button = menu.buttons.quick
	profile_label = menu.labels.profile


func _bar(parent: Control, rect: Rect2, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = rect.position
	bar.size = rect.size
	bar.show_percentage = false
	bar.add_theme_font_size_override("font_size", 1)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := StyleBoxFlat.new()
	back.bg_color = Color("263c46")
	back.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", back)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	bar.size = rect.size
	return bar


func _build_hud() -> void:
	hud = _screen()
	_surface(hud, Rect2(20, 12, 1240, 88), Color("172831"), Color("44575d"))
	_label(hud, "HEALTH", Vector2(39, 19), Vector2(130, 23), 13, MUTED)
	health_label = _label(hud, "=100 / 100", Vector2(160, 19), Vector2(120, 26), 17, INK)
	health_bar = _bar(hud, Rect2(40, 53, 231, 13), GOLD)
	_label(hud, "ENERGY", Vector2(308, 19), Vector2(197, 23), 13, MUTED)
	energy_label = _label(hud, "=0%", Vector2(509, 19), Vector2(65, 26), 17, MINT)
	energy_bar = _bar(hud, Rect2(309, 53, 258, 13), MINT)
	time_label = _label(hud, "=03:00", Vector2(605, 15), Vector2(140, 45), 29, INK)
	phase_label = _label(hud, "=", Vector2(605, 67), Vector2(160, 24), 13, MUTED)
	scrap_label = _label(hud, "=000", Vector2(42, 76), Vector2(120, 20), 13, GOLD)
	kills_label = _label(hud, "=000", Vector2(165, 76), Vector2(120, 20), 13, MUTED)
	repair_hint_label = _label(hud, "REPAIR_HINT", Vector2(309, 76), Vector2(282, 19), 11, MUTED)
	equipment_label = _label(hud, "=", Vector2(309, 75), Vector2(282, 20), 11, MINT)
	equipment_label.clip_text = true
	_surface(hud, Rect2(775, 17, 294, 77), Color("0e1d25"), Color("46616b"))
	skill_gauge = load("res://scripts/ui/skill_gauge.gd").new()
	skill_gauge.position = Vector2(777, 21)
	skill_gauge.size = Vector2(68, 68)
	hud.add_child(skill_gauge)
	ability_label = _label(hud, "=", Vector2(847, 24), Vector2(215, 26), 15, INK)
	ability_status = _label(hud, "=", Vector2(847, 53), Vector2(215, 27), 17, GOLD)
	ability_bar = _bar(hud, Rect2(847, 85, 209, 3), MINT)
	_button(hud, "TIP_PAUSE", Rect2(1084, 33, 151, 42), _pause_run)
	_surface(hud, Rect2(24, 103, 1232, 29), Color(0.035, 0.075, 0.10, 0.95))
	objective_label = _label(hud, "=", Vector2(40, 103), Vector2(1189, 28), 14, INK)
	objective_label.clip_text = true
	_surface(hud, Rect2(24, 675, 1232, 32), Color("172831"))
	for i: int in range(4):
		control_tips.append(_label(hud, "=", Vector2(43 + i * 199, 678), Vector2(195, 23), 12, MUTED))
	control_tips.append(_label(hud, "=", Vector2(843, 678), Vector2(181, 23), 12, MINT))
	dash_bar = _bar(hud, Rect2(1030, 686, 193, 6), GOLD)
	boss_panel = _surface(hud, Rect2(345, 139, 590, 68), Color("172831"), Color("865a37"))
	boss_label = _label(boss_panel, "=", Vector2(14, 7), Vector2(562, 26), 14, GOLD)
	boss_bar = _bar(boss_panel, Rect2(14, 42, 562, 9), RED)
	boss_window_bar = _bar(boss_panel, Rect2(14, 56, 562, 4), MINT)
	boss_window_bar.visible = false
	boss_panel.visible = false
	combo_label = _label(hud, "=", Vector2(1000, 140), Vector2(235, 28), 16, MINT)
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	notice_label = _label(hud, "=", Vector2(350, 630), Vector2(580, 31), 19, GOLD)
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.add_theme_constant_override("outline_size", 5)
	notice_label.add_theme_color_override("font_outline_color", BG)
	tutorial_panel = _surface(hud, Rect2(40, 533, 447, 115), Color(0.04, 0.1, 0.14, 0.96), Color("567780"))
	tutorial_label = _label(tutorial_panel, "=", Vector2(14, 8), Vector2(419, 61), 15, INK)
	tutorial_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(tutorial_panel, "TUTORIAL_SKIP", Rect2(283, 78, 149, 28), _complete_tutorial).add_theme_font_size_override("font_size", 12)
	tutorial_panel.visible = false


func _build_pause() -> void:
	pause_screen = _screen()
	_dim(pause_screen)
	_surface(pause_screen, Rect2(409, 174, 462, 400), PANEL, Color("35515d"))
	_label(pause_screen, "PAUSE", Vector2(435, 209), Vector2(410, 53), 32, GOLD).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(pause_screen, "PAUSE_DESC", Vector2(427, 267), Vector2(426, 36), 15, MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button(pause_screen, "RESUME", Rect2(462, 323, 356, 52), _resume_run, true)
	_button(pause_screen, "SETTINGS", Rect2(462, 391, 356, 48), _open_settings)
	_button(pause_screen, "ABANDON_RUN", Rect2(462, 456, 356, 48), _request_exit)


func _build_settings() -> void:
	settings_screen = _screen()
	_dim(settings_screen)
	_surface(settings_screen, Rect2(70, 72, 1140, 592), PANEL, Color("35515d"))
	_label(settings_screen, "SETTINGS", Vector2(106, 89), Vector2(500, 53), 30, GOLD)
	_label(settings_screen, "LANGUAGE", Vector2(106, 164), Vector2(224, 35), 17, INK)
	language_option = OptionButton.new()
	language_option.position = Vector2(360, 160)
	language_option.size = Vector2(235, 44)
	language_option.add_item("English", 0)
	language_option.add_item("简体中文", 1)
	language_option.item_selected.connect(func(index: int) -> void:
		Settings.set_locale("en" if index == 0 else "zh_CN")
		SoundBank.play("ui")
	)
	settings_screen.add_child(language_option)
	_label(settings_screen, "VOLUME", Vector2(106, 238), Vector2(244, 35), 17, INK)
	volume_slider = _mix_slider(Vector2(360, 242), Settings.master_volume, Settings.set_volume)
	_label(settings_screen, "MUSIC_VOLUME", Vector2(106, 298), Vector2(244, 35), 17, INK)
	music_slider = _mix_slider(Vector2(360, 302), Settings.music_volume, Settings.set_music_volume)
	_label(settings_screen, "SFX_VOLUME", Vector2(106, 358), Vector2(244, 35), 17, INK)
	sfx_slider = _mix_slider(Vector2(360, 362), Settings.sfx_volume, Settings.set_sfx_volume)
	_label(settings_screen, "EFFECTS", Vector2(106, 418), Vector2(244, 35), 17, INK)
	effects_check = CheckButton.new()
	effects_check.position = Vector2(494, 416)
	effects_check.size = Vector2(100, 43)
	effects_check.button_pressed = Settings.effects_enabled
	effects_check.toggled.connect(Settings.set_effects)
	settings_screen.add_child(effects_check)
	_label(settings_screen, "VACUUM_TOGGLE", Vector2(106, 478), Vector2(320, 35), 17, INK)
	toggle_check = CheckButton.new()
	toggle_check.position = Vector2(494, 476)
	toggle_check.size = Vector2(100, 43)
	toggle_check.toggled.connect(func(value: bool) -> void:
		world.cancel_input()
		Settings.set_vacuum_toggle(value)
	)
	settings_screen.add_child(toggle_check)
	_label(settings_screen, "VACUUM_TOGGLE_HELP", Vector2(106, 531), Vector2(520, 42), 13, MUTED)
	_label(settings_screen, "KEY_BINDINGS", Vector2(710, 160), Vector2(450, 40), 20, GOLD)
	var actions: Array[String] = ["move_up", "move_down", "move_left", "move_right", "dash", "active_skill"]
	for index: int in range(actions.size()):
		var action: String = actions[index]
		var button: Button = _button(settings_screen, "KEY_" + action.to_upper(), Rect2(710 + (index % 2) * 238, 212 + (index / 2) * 68, 222, 48), func() -> void:
			awaiting_key = action
			key_hint.text = tr("KEY_WAIT")
		)
		button.add_theme_font_size_override("font_size", 14)
		key_buttons[action] = button
	key_hint = _label(settings_screen, "=", Vector2(710, 424), Vector2(460, 53), 14, MUTED)
	key_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(settings_screen, "KEY_RESET", Rect2(710, 494, 185, 44), Settings.reset_keys).add_theme_font_size_override("font_size", 14)
	_button(settings_screen, "TUTORIAL_REPLAY", Rect2(906, 494, 264, 44), func() -> void: Settings.set_tutorial_completed(false)).add_theme_font_size_override("font_size", 13)
	_button(settings_screen, "BACK", Rect2(106, 592, 1064, 48), _close_settings, true)


func _mix_slider(pos: Vector2, value: float, callback: Callable) -> HSlider:
	var slider := HSlider.new()
	slider.position = pos
	slider.size = Vector2(235, 28)
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.value_changed.connect(callback)
	settings_screen.add_child(slider)
	return slider


func _build_result() -> void:
	result_screen = _screen()
	_dim(result_screen)
	_surface(result_screen, Rect2(180, 54, 920, 626), PANEL, Color("35515d"))
	_surface(result_screen, Rect2(180, 54, 920, 5), GOLD)
	result_title = _label(result_screen, "=", Vector2(220, 77), Vector2(840, 66), 40, GOLD)
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_desc = _label(result_screen, "=", Vector2(220, 148), Vector2(840, 42), 17, MUTED)
	result_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_numbers = _label(result_screen, "=", Vector2(220, 207), Vector2(840, 60), 18, INK)
	result_numbers.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_reward = _label(result_screen, "=", Vector2(220, 278), Vector2(840, 59), 23, MINT)
	result_reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_surface(result_screen, Rect2(210, 342, 423, 163), BG)
	_surface(result_screen, Rect2(647, 342, 423, 163), BG)
	result_details = _label(result_screen, "=", Vector2(230, 355), Vector2(382, 145), 15, MUTED)
	result_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_build = _label(result_screen, "=", Vector2(667, 354), Vector2(384, 146), 14, INK)
	result_build.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_badges = _label(result_screen, "=", Vector2(220, 515), Vector2(840, 29), 16, GOLD)
	result_badges.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button(result_screen, "PLAY_AGAIN", Rect2(230, 551, 820, 46), _restart_run, true)
	_button(result_screen, "LAUNCH_ACHIEVEMENTS", Rect2(230, 612, 402, 43), func() -> void: _open_archive("achievements"))
	_button(result_screen, "MAIN_MENU", Rect2(648, 612, 402, 43), _return_to_menu)


func _set_screen(next_mode: String) -> void:
	mode = next_mode
	menu.visible = mode == "menu" or (mode == "settings" and return_mode == "menu")
	hud.visible = mode in ["playing", "pause", "result"] or (mode == "settings" and return_mode == "pause")
	pause_screen.visible = mode == "pause"
	settings_screen.visible = mode == "settings"
	result_screen.visible = mode == "result"
	shop_screen.visible = mode == "shop"
	mission_screen.visible = mode == "missions"
	garage_screen.visible = mode == "garage"
	archive_screen.visible = mode == "archive"
	overtime_screen.visible = mode == "route"
	hangar_visible = mode == "menu" or (mode == "settings" and return_mode == "menu")
	world.visible = not hangar_visible and mode not in ["missions", "garage", "archive", "route"]
	if mode == "menu":
		_refresh_menu_progress()
	_sync_music()
	queue_redraw()


func _start_run(use_demo: bool = true) -> void:
	final_stats.clear()
	shop_summary.clear()
	last_run_demo = use_demo
	last_run_standard = false
	last_run_endless = false
	run_id = Crypto.new().generate_random_bytes(16).hex_encode()
	_set_screen("playing")
	world.start_run(0, use_demo)
	world._ability.configure(profile.get_setup())
	world.player_skin = world._ability.skin
	world.skill_color = world._ability.tint
	world._emit_stats()
	_begin_tutorial()
	_sync_music()
	SoundBank.play("start")


func _restart_run() -> void:
	if not _ensure_result_saved():
		return
	if last_run_endless:
		_deploy_overtime(selected_map)
	elif last_run_standard:
		_deploy_standard(selected_map)
	else:
		_start_run(last_run_demo)


func _open_shop(summary: Dictionary) -> void:
	shop_summary = summary.duplicate(true)
	shop_screen.present(world.get_shop_offers(), world.get_stats(), shop_summary)
	_set_screen("shop")
	_save_checkpoint()
	SoundBank.play("win")


func _purchase_offer(token: String) -> void:
	if mode != "shop":
		return
	var result: Dictionary = world.buy_offer(token)
	shop_screen.purchase_result(result, world.get_shop_offers(), world.get_stats())
	if result.get("ok", false):
		SoundBank.play("start")
		_save_checkpoint()


func _next_wave() -> void:
	if mode != "shop":
		return
	if world.endless_mode:
		if _save_checkpoint():
			overtime_screen.present(world.get_stats())
			_set_screen("route")
		return
	if not _save_checkpoint():
		return
	if world.start_next_wave():
		_set_screen("playing")
		SoundBank.play("start")


func _pause_run() -> void:
	if mode != "playing":
		return
	world.set_paused(true)
	_set_screen("pause")


func _resume_run() -> void:
	if mode != "pause":
		return
	world.set_paused(false)
	_set_screen("playing")


func _return_to_menu() -> void:
	if not _ensure_result_saved():
		return
	world.set_paused(true)
	world.active = false
	_set_screen("menu")


func _open_settings() -> void:
	return_mode = mode
	SoundBank.play("ui")
	_set_screen("settings")
	_refresh_localization()


func _close_settings() -> void:
	awaiting_key = ""
	_set_screen(return_mode)


func _finish_run(won: bool, stats: Dictionary) -> void:
	if final_stats.has("won") and final_stats.get("reward", {}).get("ok", false):
		return
	final_stats = stats.duplicate()
	final_stats["won"] = won
	final_stats["reward"] = profile.settle(run_id, final_stats, won)
	_set_screen("result")
	_refresh_result()
	if is_instance_valid(result_reveal):
		result_reveal.kill()
	result_screen.modulate.a = 1.0
	if Settings.effects_enabled:
		result_screen.modulate.a = 0.0
		result_reveal = create_tween()
		result_reveal.tween_property(result_screen, "modulate:a", 1.0, 0.42).set_delay(0.18)


func _refresh_localization() -> void:
	for binding: Dictionary in bindings:
		binding.node.set("text", tr(binding.key))
	if is_instance_valid(language_option):
		language_option.select(1 if Settings.locale == "zh_CN" else 0)
		volume_slider.set_value_no_signal(Settings.master_volume)
		music_slider.set_value_no_signal(Settings.music_volume)
		sfx_slider.set_value_no_signal(Settings.sfx_volume)
		effects_check.set_pressed_no_signal(Settings.effects_enabled)
		toggle_check.set_pressed_no_signal(Settings.vacuum_toggle)
		for action: String in key_buttons:
			key_buttons[action].text = "%s  [%s]" % [tr("KEY_" + action.to_upper()), OS.get_keycode_string(Settings.get_key(action))]
		key_hint.text = tr("KEY_WAIT" if not awaiting_key.is_empty() else "KEY_HELP")
	if is_instance_valid(mission_screen):
		mission_screen.refresh()
	if is_instance_valid(garage_screen):
		garage_screen.refresh()
	_refresh_menu_progress()
	_refresh_control_tips()
	if is_instance_valid(shop_screen):
		shop_screen.refresh()
	if is_instance_valid(overtime_screen):
		overtime_screen.refresh()
	if is_instance_valid(archive_screen):
		archive_screen.refresh()
	if not display_stats.is_empty():
		_update_hud(display_stats)
		_refresh_result()


func _refresh_result() -> void:
	if not final_stats.has("won"):
		return
	var won: bool = final_stats.won
	var abandoned: bool = bool(final_stats.get("abandoned", false))
	result_title.text = tr("WITHDRAWN" if abandoned else ("WON" if won else "LOST"))
	result_desc.text = tr("WITHDRAWN_DESC" if abandoned else ("WON_DESC" if won else "LOST_DESC"))
	if final_stats.get("extracted", false):
		result_title.text = tr("OT_EXTRACTED")
		result_desc.text = tr("OT_EXTRACTED_DESC")
	result_title.add_theme_color_override("font_color", MINT if won else GOLD)
	var stage: String = ""
	if last_run_endless:
		stage = "  /  " + tr("OT_RESULT_ROOMS") % int(final_stats.get("rooms_completed", 0))
	elif last_run_demo:
		stage = "  /  %s %d/6" % [tr("WAVE"), int(final_stats.get("wave", 1))]
	result_numbers.text = "%s  %s%s\n%s  %03d    /    %s  %03d" % [tr("TIME"), _clock(final_stats.get("elapsed", 0.0)), stage, tr("RESULT_SCRAP"), final_stats.get("total_scrap", final_stats.get("currency", 0)), tr("KILLS"), final_stats.get("kills", 0)]
	var reward: Dictionary = final_stats.get("reward", {})
	result_reward.text = tr("RESULT_COINS") % [int(reward.get("coins", 0)), int(profile.data.coins)] if reward.get("ok", false) else tr("PROFILE_SAVE_FAILED")
	if reward.get("first_clear", false):
		result_reward.text += "\n" + tr("RESULT_FIRST_CLEAR")
		result_reward.add_theme_font_size_override("font_size", 19)
	else:
		result_reward.add_theme_font_size_override("font_size", 23)
	var details: PackedStringArray = []
	var equipped: PackedStringArray = []
	for id: String in final_stats.get("loadout", {}).get("weapons", {}):
		var level: int = int(final_stats.loadout.weapons[id])
		if level > 0:
			equipped.append("%s L%d" % [tr("ITEM_" + id.to_upper()), level])
	var build_lines: PackedStringArray = []
	build_lines.append(tr("RESULT_BLUEPRINT") % [tr("GARAGE_SKILL_" + str(final_stats.get("ability_id", "pulse")).to_upper()), int(final_stats.get("ability_uses", 0))])
	var branch: String = str(final_stats.get("ability_branch", ""))
	if not branch.is_empty():
		build_lines.append("%s · %d" % [tr("BRANCH_" + branch.to_upper()), int(final_stats.get("ability_branch_rank", 1))])
	if not equipped.is_empty():
		build_lines.append(" / ".join(equipped))
	for evolution: Dictionary in final_stats.get("evolutions", []):
		if evolution.active:
			build_lines.append("◆ " + tr(evolution.name_key))
	result_build.text = "\n".join(build_lines)
	var new_badges: PackedStringArray = []
	for badge: String in reward.get("badges", []):
		new_badges.append(tr("BADGE_" + badge.to_upper()))
	for id: String in reward.get("new_achievements", []):
		new_badges.append(tr(Achievements.DEFINITIONS[id].name_key))
	result_badges.text = tr("RESULT_BADGE") % " / ".join(new_badges) if not new_badges.is_empty() else ""
	result_badges.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	result_badges.tooltip_text = " / ".join(new_badges)
	var contributions: Dictionary = final_stats.get("damage_by_source", {})
	var top_tool: String = ""
	var highest: float = 0.0
	for source: String in contributions:
		if float(contributions[source]) > highest:
			highest = float(contributions[source])
			top_tool = source
	if top_tool.begins_with("overtime_"):
		top_tool = "evolution"
	if top_tool in ["prism_relay", "hunter_swarm", "ordnance_chain"]:
		top_tool = "evolution"
	if not top_tool.is_empty():
		var name_key: String = "RESULT_ABILITY" if top_tool.begins_with("ability") else ("RESULT_BLAST" if top_tool == "blast" else ("RESULT_EVOLUTION" if top_tool == "evolution" else "ITEM_" + top_tool.to_upper()))
		if top_tool == "mechanism":
			name_key = "RESULT_MECHANISM"
		details.append(tr("RESULT_TOP_TOOL") % [tr(name_key), int(highest)])
	if not won and not abandoned:
		var cause: String = str(final_stats.get("last_damage_source", "unknown"))
		var cause_key: String = cause if cause.begins_with("DAMAGE_") else "DAMAGE_" + (cause.to_upper() if not cause.is_empty() else "UNKNOWN")
		details.append(tr("RESULT_CAUSE") % tr(cause_key))
	var map_id: String = "endless" if last_run_endless else (selected_map if last_run_standard else ("demo" if last_run_demo else "quick"))
	var record: Dictionary = profile.data.records.get(map_id, {})
	details.append(tr("OT_PERSONAL_BEST" if last_run_endless else "RESULT_RECORD") % [int(record.get("best_wave", 0)), int(record.get("best_kills", 0))])
	var next: String = profile.next_unlock()
	if next.is_empty():
		details.append(tr("RESULT_ALL_UNLOCKED"))
	elif int(Profile.CATALOG[next].cost) <= int(profile.data.coins):
		details.append(tr("RESULT_UNLOCK_READY") % tr("GARAGE_" + next.to_upper()))
	else:
		details.append(tr("RESULT_NEXT_UNLOCK") % [tr("GARAGE_" + next.to_upper()), int(Profile.CATALOG[next].cost) - int(profile.data.coins)])
	result_details.text = "\n".join(details)


func _clock(seconds: float) -> String:
	var whole := maxi(0, int(ceil(seconds)))
	return "%02d:%02d" % [whole / 60, whole % 60]


func _update_hud(stats: Dictionary) -> void:
	if not is_instance_valid(health_bar):
		return
	display_stats = stats.duplicate()
	health_label.text = "%d / %d" % [stats.get("health", 100), stats.get("max_health", 100)]
	health_bar.value = 100.0 * float(stats.get("health", 100.0)) / maxf(1.0, float(stats.get("max_health", 100.0)))
	energy_bar.value = 100.0 * float(stats.get("energy", 0.0)) / maxf(1.0, float(stats.get("max_energy", 100.0)))
	energy_label.text = "%d%%" % int(energy_bar.value)
	scrap_label.text = "%s %03d" % [tr("SCRAP"), stats.get("currency", 0)]
	kills_label.text = "%s %03d" % [tr("KILLS"), stats.get("kills", 0)]
	time_label.text = _clock(float(stats.get("duration", 180.0)) - float(stats.get("elapsed", 0.0)))
	phase_label.text = "%s  %02d" % [tr("PHASE"), mini(4, 1 + int(float(stats.get("elapsed", 0.0)) / 45.0))]
	if last_run_demo:
		var wave: int = int(stats.get("wave", 1))
		time_label.text = _clock(float(stats.get("wave_duration", 55.0)) - float(stats.get("wave_elapsed", 0.0))) if wave < 6 else tr("FINAL_WAVE")
		time_label.add_theme_font_size_override("font_size", 29 if wave < 6 else 20)
		phase_label.text = "%s  %02d / 06" % [tr("WAVE"), wave]
	else:
		time_label.add_theme_font_size_override("font_size", 29)
	if bool(stats.get("endless_mode", false)):
		var is_boss: bool = int(stats.get("endless_room", 1)) % 3 == 0
		time_label.text = tr("OT_BOSS") if is_boss else _clock(float(stats.get("wave_duration", 80)) - float(stats.get("wave_elapsed", 0)))
		time_label.add_theme_font_size_override("font_size", 20 if is_boss else 29)
		phase_label.text = tr("OT_HUD_ROOM") % [int(stats.get("endless_room", 1)), int(stats.get("endless_cycle", 1))]
	var weapons: Dictionary = stats.get("loadout", {}).get("weapons", {"brush": 1})
	var equipped: PackedStringArray = []
	for id: String in Loadout.WEAPON_IDS:
		if int(weapons.get(id, 0)) > 0:
			equipped.append("%s %s%d" % [tr("ITEM_" + id.to_upper()), tr("LEVEL_SHORT"), weapons[id]])
	equipment_label.text = "   /   ".join(equipped)
	equipment_label.visible = last_run_demo
	repair_hint_label.visible = not last_run_demo
	boss_panel.visible = last_run_demo and float(stats.get("boss_max_health", 0)) > 0.0
	if boss_panel.visible:
		boss_bar.value = 100.0 * float(stats.get("boss_health", 0.0)) / maxf(1.0, float(stats.get("boss_max_health", 1.0)))
		var exposed: float = float(stats.get("boss_exposed_seconds", 0.0))
		var phase_text: String = tr("BOSS_EXPOSED_TIMER") % exposed if exposed > 0.0 else tr(str(stats.get("boss_phase_key", "BOSS_HUNT")))
		boss_label.text = "%s  /  %s" % [tr(str(stats.get("boss_name_key", "BOSS_NAME"))) if last_run_standard else tr("BOSS_NAME"), phase_text]
		boss_label.add_theme_color_override("font_color", MINT if exposed > 0.0 else GOLD)
		boss_window_bar.visible = exposed > 0.0
		boss_window_bar.value = clampf(exposed / 6.0, 0.0, 1.0) * 100.0
	dash_bar.value = float(stats.get("dash_ratio", 1.0)) * 100.0
	objective_label.text = tr(str(stats.get("wave_name_key", ""))) + "  ·  " + tr(str(stats.get("objective_key", ""))) if last_run_standard else ""
	if last_run_standard and not str(stats.get("interaction_key", "")).is_empty():
		objective_label.text = tr(str(stats.get("interaction_key")))
	if bool(stats.get("endless_mode", false)):
		var pattern: String = str(stats.get("overtime_pattern", "swarm"))
		if pattern != "boss":
			objective_label.text = tr("OT_PATTERN_" + pattern.to_upper())
			if int(stats.get("overtime_target", 0)) > 0:
				objective_label.text += "  %d/%d" % [int(stats.get("overtime_progress", 0)), int(stats.overtime_target)]
			objective_label.text += "  ·  " + tr("OT_RISK_" + str(stats.get("overtime_risk", "hunters")).to_upper())
		objective_label.tooltip_text = objective_label.text
		objective_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if boss_panel.visible and float(stats.get("boss_exposed_seconds", 0.0)) > 0.0:
		objective_label.text = tr("BOSS_BREAK_SUPPLY")
		objective_label.tooltip_text = objective_label.text
	combo_label.text = tr("COMBO_COUNT") % int(stats.get("combo", 0)) if int(stats.get("combo", 0)) >= 5 else ""
	var ability: String = str(stats.get("ability_id", "pulse"))
	var ability_name: String = tr("GARAGE_SKILL_" + ability.to_upper())
	var state: String = str(stats.get("ability_state", "charging"))
	ability_label.text = ability_name
	var key: String = OS.get_keycode_string(Settings.get_key("active_skill"))
	if state == "active":
		ability_status.text = tr("HUD_SKILL_ACTIVE") % float(stats.get("ability_remaining", 0.0))
	elif state == "ready":
		ability_status.text = tr("HUD_SKILL_READY") % key
	else:
		ability_status.text = tr("HUD_SKILL_CHARGING") % int(stats.get("ability_charge", 0))
	ability_status.add_theme_color_override("font_color", GOLD if state == "ready" else MINT)
	if _last_ability_state in ["charging", "active"] and state == "ready" and mode == "playing":
		SoundBank.play("skill_ready")
	_last_ability_state = state
	skill_gauge.update_state(stats)
	notice_label.text = tr(str(stats.get("ability_notice", ""))) if not str(stats.get("ability_notice", "")).is_empty() else ""
	ability_bar.value = float(stats.get("ability_ratio", 1.0)) * 100.0
	if mode == "playing":
		_sync_music()


func _refresh_control_tips() -> void:
	if control_tips.size() != 5:
		return
	var movement: String = "/".join([OS.get_keycode_string(Settings.get_key("move_up")), OS.get_keycode_string(Settings.get_key("move_left")), OS.get_keycode_string(Settings.get_key("move_down")), OS.get_keycode_string(Settings.get_key("move_right"))])
	control_tips[0].text = movement + "  " + tr("MOVE")
	control_tips[1].text = tr("TIP_VACUUM_TOGGLE" if Settings.vacuum_toggle else "TIP_VACUUM")
	control_tips[2].text = tr("TIP_BLAST_TOGGLE" if Settings.vacuum_toggle else "TIP_BLAST")
	control_tips[3].text = OS.get_keycode_string(Settings.get_key("dash")) + "  " + tr("DASH")
	control_tips[4].text = OS.get_keycode_string(Settings.get_key("active_skill")) + "  " + tr("ACTIVE_ABILITY")


func _sync_music() -> void:
	var phase: String = "menu"
	var context_mode: String = return_mode if mode == "settings" else mode
	if context_mode == "playing":
		phase = "boss" if last_run_demo and not world._boss.is_empty() and not world._boss_defeated else "combat"
	elif context_mode == "route":
		phase = "shop"
	elif context_mode in ["shop", "pause", "result"]:
		phase = context_mode
	SoundBank.set_context(str(world.map_id) if last_run_standard else "yard", phase)


func _refresh_menu_progress() -> void:
	if not is_instance_valid(menu) or profile == null:
		return
	menu.refresh()
	if not profile.last_error.is_empty():
		profile_label.text = tr(profile.last_error)


func _open_missions() -> void:
	pending_endless = false
	mission_screen.endless_mode = false
	_replace_saved_then(func() -> void:
		mission_screen.selected = selected_map
		mission_screen.present(profile)
		_set_screen("missions")
	)


func _request_quick() -> void:
	_replace_saved_then(func() -> void: _start_run(false))


func _replace_saved_then(callback: Callable) -> void:
	if profile.data.checkpoint.is_empty():
		callback.call()
		return
	_confirm("CONFIRM_REPLACE", func() -> void:
		var saved: Dictionary = profile.data.checkpoint
		if not world.restore_checkpoint(saved.get("world", {})):
			profile.last_error = "CHECKPOINT_INVALID"
			_refresh_menu_progress()
			return
		var stats: Dictionary = world.get_stats()
		stats["abandoned"] = true
		world.active = false
		var result: Dictionary = profile.settle(str(saved.get("run_id", "")), stats, false)
		if result.get("ok", false):
			callback.call()
		else:
			profile.last_error = "PROFILE_SAVE_FAILED"
			_refresh_menu_progress()
	)


func _deploy_standard(map_id: String) -> void:
	last_run_endless = false
	final_stats.clear()
	shop_summary.clear()
	selected_map = map_id
	last_run_standard = true
	last_run_demo = true
	run_id = Crypto.new().generate_random_bytes(16).hex_encode()
	_set_screen("playing")
	world.start_standard(map_id, 0, profile.get_setup())
	_begin_tutorial()
	_sync_music()
	SoundBank.play("start")


func _open_garage() -> void:
	garage_screen.present(profile)
	_set_screen("garage")


func _save_checkpoint() -> bool:
	if not last_run_standard:
		return true
	var checkpoint: Dictionary = world.create_checkpoint()
	if checkpoint.is_empty():
		return false
	var ok: bool = profile.save_checkpoint(run_id, checkpoint, shop_summary)
	if not ok:
		shop_screen.status_label.text = tr("PROFILE_SAVE_FAILED")
	return ok


func _continue_saved() -> void:
	var saved: Dictionary = profile.data.checkpoint.duplicate(true)
	if saved.is_empty() or str(saved.get("run_id", "")) in profile.data.settled_runs:
		return
	last_run_standard = true
	last_run_demo = true
	selected_map = str(saved.get("world", {}).get("map_id", "yard"))
	run_id = str(saved.get("run_id", ""))
	if not world.restore_checkpoint(saved.get("world", {})):
		profile_label.text = tr("CHECKPOINT_INVALID")
		return
	last_run_endless = world.endless_mode
	selected_map = world._overtime.start_map if world.endless_mode else world.map_id
	final_stats.clear()
	tutorial_step = -1
	tutorial_panel.visible = false
	_open_shop(saved.get("summary", {}))


func _reroll_shop() -> void:
	if mode != "shop":
		return
	var result: Dictionary = world.reroll_shop()
	shop_screen.refresh_result(result, world.get_shop_offers(), world.get_stats())
	if result.get("ok", false):
		SoundBank.play("ui")
		_save_checkpoint()


func _choose_branch(id: String) -> void:
	if mode != "shop":
		return
	var result: Dictionary = world.choose_ability_branch(id)
	shop_screen.branch_result(result, world.get_shop_offers(), world.get_stats())
	if result.get("ok", false):
		_save_checkpoint()


func _sell_tool(id: String) -> void:
	if mode != "shop":
		return
	var result: Dictionary = world.sell_weapon(id)
	shop_screen.sale_result(result, world.get_shop_offers(), world.get_stats())
	if result.get("ok", false):
		SoundBank.play("install")
		_save_checkpoint()


func _request_exit() -> void:
	if mode == "shop" and last_run_standard:
		if _save_checkpoint():
			_return_to_menu()
	elif world.active:
		_confirm("CONFIRM_ABANDON", func() -> void:
			var stats: Dictionary = world.get_stats()
			stats["abandoned"] = true
			world.active = false
			world.cancel_input()
			_finish_run(false, stats)
		)
	else:
		_return_to_menu()


func _confirm(key: String, callback: Callable) -> void:
	confirm_action = callback
	confirm_dialog.title = tr("CONFIRM_TITLE")
	confirm_dialog.dialog_text = tr(key)
	confirm_dialog.ok_button_text = tr("CONFIRM_YES")
	confirm_dialog.cancel_button_text = tr("CANCEL")
	confirm_dialog.popup_centered()


func _ensure_result_saved() -> bool:
	if final_stats.is_empty() or final_stats.get("reward", {}).get("ok", false):
		return true
	final_stats.reward = profile.settle(run_id, final_stats, bool(final_stats.get("won", false)))
	_refresh_result()
	return bool(final_stats.reward.get("ok", false))


func _begin_tutorial() -> void:
	tutorial_step = -1 if Settings.tutorial_completed else 0
	tutorial_origin = world.player_position
	tutorial_start_scrap = int(world.total_scrap)
	tutorial_start_shots = int(world.shots)
	tutorial_start_abilities = int(world.get_stats().get("ability_uses", 0))
	tutorial_panel.visible = tutorial_step >= 0
	_update_tutorial()


func _update_tutorial() -> void:
	if tutorial_step < 0:
		return
	if tutorial_step == 0 and Vector2(world.player_position).distance_to(tutorial_origin) > 65.0:
		tutorial_step = 1
	if tutorial_step == 1 and int(world.total_scrap) >= tutorial_start_scrap + 3:
		tutorial_step = 2
	if tutorial_step == 2 and int(world.shots) > tutorial_start_shots:
		tutorial_step = 3
	if tutorial_step == 3 and float(world._dash_cooldown) > 0.0:
		tutorial_step = 4
	if tutorial_step == 4 and int(world.get_stats().get("ability_uses", 0)) > tutorial_start_abilities:
		_complete_tutorial()
		return
	var text: String = tr(["TUTORIAL_MOVE", "TUTORIAL_VACUUM", "TUTORIAL_BLAST", "TUTORIAL_DASH", "TUTORIAL_ABILITY"][tutorial_step]).replace("\\n", "\n")
	if tutorial_step == 0:
		text = text % "/".join([OS.get_keycode_string(Settings.get_key("move_up")), OS.get_keycode_string(Settings.get_key("move_left")), OS.get_keycode_string(Settings.get_key("move_down")), OS.get_keycode_string(Settings.get_key("move_right"))])
	elif tutorial_step == 3:
		text = text % OS.get_keycode_string(Settings.get_key("dash"))
	elif tutorial_step == 4:
		text = text % OS.get_keycode_string(Settings.get_key("active_skill"))
	tutorial_label.text = text


func _complete_tutorial() -> void:
	tutorial_step = -1
	tutorial_panel.visible = false
	Settings.set_tutorial_completed(true)


func _draw() -> void:
	pass # LaunchHangar owns the aspect-preserving background.


func _robot_track() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("253c48")
	style.border_color = Color("3d5660")
	style.set_border_width_all(4)
	style.set_corner_radius_all(17)
	return style


func draw_ellipse_shadow(center: Vector2) -> void:
	var points := PackedVector2Array()
	for i: int in range(40):
		var angle: float = i * TAU / 40.0
		points.append(center + Vector2(cos(angle) * 144, sin(angle) * 33))
	draw_colored_polygon(points, Color(0.0, 0.0, 0.0, 0.2))


func _open_overtime() -> void:
	pending_endless = true
	mission_screen.endless_mode = true
	_replace_saved_then(func() -> void:
		mission_screen.selected = selected_map
		mission_screen.present(profile)
		_set_screen("missions")
	)


func _deploy_selected(map_id: String) -> void:
	if pending_endless:
		_deploy_overtime(map_id)
	else:
		_deploy_standard(map_id)


func _deploy_overtime(map_id: String) -> void:
	final_stats.clear()
	shop_summary.clear()
	selected_map = map_id
	last_run_standard = true
	last_run_endless = true
	last_run_demo = true
	run_id = Crypto.new().generate_random_bytes(16).hex_encode()
	_set_screen("playing")
	world.start_endless(map_id, 0, profile.get_setup())
	_begin_tutorial()
	_sync_music()
	SoundBank.play("start")


func _open_archive(tab: String = "history") -> void:
	if not _ensure_result_saved():
		return
	archive_screen.present(profile, tab)
	_set_screen("archive")


func _choose_route(index: int) -> void:
	if mode != "route" or not world.choose_overtime_route(index):
		return
	overtime_screen.present(world.get_stats())
	if not _save_checkpoint():
		overtime_screen.status.text = tr("PROFILE_SAVE_FAILED")


func _launch_overtime_room() -> void:
	if mode != "route" or not _save_checkpoint():
		return
	if world.start_next_wave():
		_set_screen("playing")
		SoundBank.play("start")
