extends SceneTree
const Archive = preload("res://scripts/ui/archive_panel.gd")
const Profile = preload("res://scripts/services/player_profile.gd")
const Catalog = preload("res://scripts/services/achievement_catalog.gd")
var checks: int = 0
var failures: Array[String] = []
var capture: bool = false
var screenshots: Array[String] = []
var shell: Control
var profile: RefCounted
var archive: Control
var fixture_path: String

func _initialize() -> void:
	_run.call_deferred()

func verify(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)

func _run() -> void:
	if "--test-settings" not in OS.get_cmdline_user_args():
		push_error("Archive fixture requires isolated --test-settings")
		quit(1)
		return
	capture = "--capture" in OS.get_cmdline_user_args()
	fixture_path = "user://archive-v05-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	profile = Profile.new(fixture_path)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	shell = Control.new()
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var theme := Theme.new()
	theme.default_font = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
	theme.default_font_size = 16
	shell.theme = theme
	root.add_child(shell)
	archive = Archive.new()
	shell.add_child(archive)
	var back: Array[bool] = []
	archive.back_requested.connect(func(): back.append(true))
	archive.present(profile)
	verify(archive.current_tab == "history" and archive.history_items.is_empty(), "Fresh archive opens its empty battle history without fabricating runs")
	verify(archive.previous_button.disabled and archive.next_button.disabled, "Empty history has disabled pagination")
	verify(profile.data.coins == 0 and not FileAccess.file_exists(fixture_path), "Reading an empty archive does not write or reward")
	await snap("archive-empty-en")
	archive.achievement_tab.pressed.emit()
	verify(archive.current_tab == "achievements" and archive.achievement_items.size() == 16, "Achievements tab lists sixteen parallel milestones")
	verify(archive.reward_button != null and archive.reward_button.disabled, "Locked title has a visible but disabled equip control")
	verify(archive.selected_status.progress == 0 and not archive.selected_status.claimed, "Locked cards display actual zero progress and unclaimed status")
	archive._choose_achievement("flawless_shift")
	verify(archive.selected_status.reward == "skin_aurora" and archive.reward_button.disabled, "Locked Aurora reward can be previewed without equipping")
	await snap("archive-aurora-locked-en")
	archive.next_button.pressed.emit()
	verify(archive.page == 1 and archive.selected_achievement == "boss_precision", "Achievement pagination selects the first card on the next page")
	archive.next_button.pressed.emit()
	verify(archive.page == 2 and archive.next_button.disabled, "Final achievement page disables forward navigation")
	# Fixtures are settled through the real profile service, not minted owned flags.
	for index: int in range(9):
		var stats: Dictionary = {"standard_mode": true, "map_id": ["yard", "foundry", "reactor"][index % 3], "wave": 6,
			"elapsed": 920.0 + index, "kills": 210 + index, "total_scrap": 1110 + index, "boss_kills": 1,
			"damage_taken": 0.0, "damage_events": 0, "boss_damage_taken": 0.0, "ability_id": "pulse", "ability_uses": 6,
			"loadout": {"weapons": {"brush": 2, "saw": 2, "arc": 1}, "mods": {"hull": 2, "magnet": 2}},
			"evolutions": ["steel_storm"]}
		verify(profile.settle("archive-fixture-%d" % index, stats, true).ok, "Real fixture settlement %d succeeds" % index)
	var overtime: Dictionary = {"endless_mode": true, "standard_mode": true, "map_id": "reactor", "rooms_completed": 12,
		"cycles_completed": 4, "boss_kills": 4, "elapsed": 901.0, "kills": 490, "total_scrap": 2100,
		"damage_taken": 89.5, "damage_events": 7, "boss_damage_taken": 36.0, "ability_id": "overdrive", "ability_uses": 21,
		"extracted": true, "loadout": {"weapons": {"brush": 2, "laser": 2, "arc": 2, "drone": 1}, "mods": {"capacitor": 2, "magnet": 2}},
		"evolutions": ["prism_relay", "compression_blast"], "mutators": ["armored", "hunters"]}
	verify(profile.settle("archive-overtime", overtime, false).ok, "Overtime fixture supports four-slot tools and new evolution history")
	archive.present(profile, "history")
	verify(archive.history_items.size() == 6 and archive.selected_run == "archive-overtime", "History presents six newest runs and selects the most recent")
	verify(archive.detail_text.text.contains("89.5 / 7") and archive.detail_text.text.contains("12 / 4"), "Selected history detail shows actual damage and completed rooms/cycles")
	verify(archive.detail_text.text.contains("archive-overtime") and archive.detail_text.scroll_active, "History retains run ID and scrollable complete details")
	var before: Dictionary = profile.data.duplicate(true)
	archive._choose_history(2)
	archive.next_button.pressed.emit()
	verify(archive.page == 1 and archive.history_items.size() == 4 and archive.next_button.disabled, "History final page retains its four older runs")
	verify(profile.data == before, "Selecting, paginating and browsing historical runs are read-only")
	archive.previous_button.pressed.emit()
	await snap("archive-history-en")
	archive.achievement_tab.pressed.emit()
	verify(archive.selected_status.claimed and not archive.reward_button.disabled, "Newly earned title can be equipped from its achievement card")
	archive.reward_button.pressed.emit()
	verify(profile.get_setup().title == "shiftbreaker" and archive.reward_button.disabled, "Equip button persists the earned title and becomes equipped")
	archive._choose_achievement("flawless_shift")
	archive.reward_button.pressed.emit()
	verify(profile.get_setup().skin == "aurora" and Profile.new(fixture_path).get_setup().skin == "aurora", "Achievement skin equip reaches real persisted setup")
	await snap("archive-aurora-earned-en")
	archive.next_button.pressed.emit()
	archive._choose_achievement("overtime_12")
	archive.reward_button.pressed.emit()
	verify(profile.get_setup().skill_color == "prism" and archive.reward_button.disabled, "Earned effect palette is equipped transactionally")
	await snap("archive-prism-earned-en")
	root.get_node("Settings").set_locale("zh_CN")
	archive.refresh()
	verify(archive.title_label.text == tr("ARCHIVE_TITLE") and archive.title_label.text != "ARCHIVE_TITLE", "Archive title is genuinely translated in Chinese")
	root.size = Vector2i(960, 540)
	await snap("archive-prism-zh-960")
	archive.history_tab.pressed.emit()
	verify(archive.detail_text.text.contains(tr("ARCHIVE_EXTRACTED")) == false and archive.history_items[0].extracted, "Chinese history still selects the actual extracted run")
	await snap("archive-history-zh-960")
	archive.back_button.pressed.emit()
	verify(back == [true], "Back action emits its navigation signal exactly once")
	verify(archive._escape("[b]run[/b]") == "[lb]b[rb]run[lb]/b[rb]", "User-derived archive identifiers cannot inject rich text markup")
	archive.queue_free()
	shell.queue_free()
	await process_frame
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(fixture_path + suffix):
			DirAccess.remove_absolute(fixture_path + suffix)
	print("ARCHIVE_UI_TEST ", JSON.stringify({"checks": checks, "failures": failures, "screenshots": screenshots, "fixture_only": true}))
	quit(0 if failures.is_empty() else 1)

func snap(label: String) -> void:
	if not capture:
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var destination: String = "res://captures/v05/" + label + ".png"
	DirAccess.make_dir_recursive_absolute("res://captures/v05")
	var error: Error = root.get_texture().get_image().save_png(destination)
	verify(error == OK, "Native archive screenshot " + label + " saves")
	if error == OK:
		screenshots.append(destination)
