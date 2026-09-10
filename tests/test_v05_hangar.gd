extends SceneTree
## Isolated presentation fixture. It does not award progression or prove human UX.
const Launch = preload("res://scripts/ui/launch_hangar.gd")
const Art = preload("res://scripts/ui/hangar_visual.gd")
const Preview = preload("res://scripts/ui/skill_preview.gd")
const Profile = preload("res://scripts/services/player_profile.gd")
var checks: int = 0
var failures: Array[String] = []
var captures: Array[String] = []
var menu: Control
var fixture: RefCounted
var settings: Node
var fixture_path: String
var capture: bool = false
var navigation: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func verify(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	if "--test-settings" not in OS.get_cmdline_user_args():
		push_error("This fixture requires --test-settings")
		quit(1)
		return
	capture = "--capture" in OS.get_cmdline_user_args()
	settings = root.get_node("Settings")
	settings.set_locale("en")
	verify(tr("LAUNCH_PROFILE") != "LAUNCH_PROFILE" and tr("LAUNCH_OVERTIME") != "LAUNCH_OVERTIME", "New launch localization is actually imported")
	if not failures.is_empty():
		quit(1)
		return
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280, 720)
	fixture_path = "user://v05-hangar-fixture-%d.json" % OS.get_process_id()
	fixture = Profile.new(fixture_path)
	menu = Launch.new()
	menu.configure(fixture)
	root.add_child(menu)
	await process_frame
	verify(menu.buttons.size() == 8, "Eight real menu buttons exist")
	verify(menu.buttons["continue"].disabled, "Continue clearly disables with no checkpoint")
	verify(menu.buttons.overtime.size.y > menu.buttons.quick.size.y, "Overtime has stronger entry hierarchy than Quick Sweep")
	verify(menu.buttons.standard.text == tr("LAUNCH_STANDARD"), "Standard entry uses live localization")
	verify(menu.labels.rig_skill.text == tr("GARAGE_SKILL_PULSE"), "Rig summary reads current profile skill")
	verify(menu.KEYART.get_width() == 1672 and menu.KEYART.get_height() == 941, "Native generated asset dimensions are reported truthfully")
	verify(menu.body_font.multichannel_signed_distance_field and menu.display_font.multichannel_signed_distance_field, "Private scalable fonts keep high-resolution UI text crisp")
	verify(not menu.BODY_FONT.multichannel_signed_distance_field, "Launch cannot modify the shared combat CJK font")
	for id: String in menu.ENTRIES:
		menu.connect(id + "_requested", func() -> void: navigation.append(id))
		if id != "continue":
			menu.buttons[id].pressed.emit()
	verify(navigation == ["overtime", "standard", "quick", "garage", "archive", "achievements", "settings"], "Every enabled entry emits its distinct navigation intent once")
	fixture.data.checkpoint = {"fixture": "UI availability only; never saved"}
	menu.refresh()
	verify(not menu.buttons["continue"].disabled, "Existing checkpoint enables continuation")
	menu.buttons["continue"].pressed.emit()
	verify(navigation.back() == "continue", "Continue emits a separate resume intent")
	fixture.data.checkpoint = {}
	fixture.data.coins = 168
	fixture.data.selected.skill = "overdrive"
	fixture.data.selected.skill_color = "violet"
	fixture.data.selected.skin = "arctic"
	menu.refresh()
	verify(menu.labels.rig_skill.text == tr("GARAGE_SKILL_OVERDRIVE") and menu.labels.rig_cosmetics.text.contains(tr("GARAGE_SKIN_ARCTIC")), "Actual skill and cosmetics remain explicit beside fixed illustrative key art")
	var before: String = JSON.stringify(fixture.data)
	menu.refresh()
	verify(before == JSON.stringify(fixture.data), "Menu refresh cannot modify profile or grant rewards")
	for window_size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(960, 540), Vector2i(2554, 1513)]:
		root.size = window_size
		await process_frame
		await process_frame
		menu._layout()
		var wanted: float = minf(float(window_size.x) / 1280.0, float(window_size.y) / 720.0)
		verify(is_equal_approx(menu.canvas.scale.x, wanted) and is_equal_approx(menu.canvas.scale.x, menu.canvas.scale.y), "Uniform control scale at %s" % window_size)
		verify(is_equal_approx(menu.art_rect.size.x / menu.art_rect.size.y, 1672.0 / 941.0), "Key art never stretches at %s" % window_size)
		var inside: bool = true
		for button: Button in menu.buttons.values():
			var bounds: Rect2 = button.get_global_rect()
			inside = inside and bounds.position.x >= 0 and bounds.position.y >= 0 and bounds.end.x <= window_size.x + 0.1 and bounds.end.y <= window_size.y + 0.1
		verify(inside, "All eight controls fit the actual window at %s" % window_size)
		for language: String in ["en", "zh_CN"]:
			settings.set_locale(language)
			menu.refresh()
			await process_frame
			verify(_labels_fit(menu), "Translations fit their controls at %s / %s" % [window_size, language])
			await snap("launch-%dx%d-%s" % [window_size.x, window_size.y, language])
	settings.effects_enabled = false
	menu.time = 3
	menu._process(0.1)
	verify(is_zero_approx(menu.time), "Reduced effects stops ambient motion")
	menu.hide()
	verify(not menu.is_processing(), "Hidden menu stops animation work")
	menu.show()
	verify(menu.is_processing(), "Visible menu restores its light animation loop")
	settings.effects_enabled = true
	for dimension: Vector2 in [Vector2(508, 333), Vector2(552, 360), Vector2(810, 420), Vector2(1280, 720)]:
		var mapping: Dictionary = Art.scene_transform(dimension)
		var extent: Vector2 = Vector2(720, 480) * float(mapping.scale)
		verify(mapping.scale > 0 and extent.y <= dimension.y + 0.1 and extent.x <= dimension.x + 0.1, "Preview art fits by one uniform scale at %s" % dimension)
	verify(Art.skin_color("cobalt") == Color("295f94") and Art.skin_color("aurora") == Color("205b59"), "Achievement skins have explicit preview palettes")
	verify(Art.skill_color({"skill_color": "ember"}) == Color("ff8c4b") and Art.skill_color({"skill_color": "prism"}) == Color("f6a9ef"), "Achievement skill colors have explicit preview palettes")
	menu.hide()
	root.size = Vector2i(1280, 720)
	var preview: Control = Preview.new()
	preview.position = Vector2(280, 100)
	preview.size = Vector2(720, 480)
	root.add_child(preview)
	preview.configure({"skill": "overdrive", "skin": "cobalt", "skill_color": "ember"})
	preview.time = 2.1
	await snap("crawler-proportion-preview")
	preview.queue_free()
	menu.queue_free()
	await process_frame
	if root.get_node("SoundBank").has_method("shutdown"):
		await root.get_node("SoundBank").shutdown()
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(fixture_path + suffix):
			DirAccess.remove_absolute(fixture_path + suffix)
	var report: Dictionary = {"checks": checks, "failures": failures, "screenshots": captures, "native_asset_size": [1672, 941], "fixture": "Isolated profile and UI navigation signals; not ordinary gameplay or subjective acceptance."}
	print("V05_HANGAR_TEST ", JSON.stringify(report))
	var file := FileAccess.open("res://artifacts/v05-hangar-validation.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "  ") + "\n")
	quit(0 if failures.is_empty() else 1)

func _labels_fit(node: Node) -> bool:
	if node is Label:
		var label: Label = node
		var font: Font = label.get_theme_font("font")
		var height: int = label.get_theme_font_size("font_size")
		if font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, height).x > label.size.x + 1:
			push_warning("Label does not fit: " + label.text)
			return false
	for child: Node in node.get_children():
		if not _labels_fit(child):
			return false
	return true

func snap(name: String) -> void:
	if not capture:
		return
	var pointer := InputEventMouseMotion.new()
	pointer.position = Vector2(12, 12)
	pointer.global_position = pointer.position
	root.push_input(pointer)
	await process_frame
	await create_timer(0.08).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://captures/v05")
	var path: String = "res://captures/v05/" + name + ".png"
	var result: int = root.get_texture().get_image().save_png(path)
	verify(result == OK, "Native capture saved: " + name)
	if result == OK:
		captures.append(path.trim_prefix("res://"))
