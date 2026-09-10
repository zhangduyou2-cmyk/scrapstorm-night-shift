extends Control
## Full-resolution, aspect-preserving key art with live translated menu controls.
## This screen only reads the profile. Navigation is owned by the application.
signal overtime_requested
signal standard_requested
signal quick_requested
signal garage_requested
signal archive_requested
signal achievements_requested
signal settings_requested
signal continue_requested

const Kit = preload("res://scripts/ui/ui_kit.gd")
const Art = preload("res://scripts/ui/hangar_visual.gd")
const KEYART: Texture2D = preload("res://assets/images/hangar-keyart-v05.png")
const DISPLAY_FONT: Font = preload("res://assets/fonts/Rajdhani-Bold.ttf")
const BODY_FONT: Font = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
const DESIGN_SIZE := Vector2(1280, 720)
const ENTRIES: Array[String] = ["overtime", "standard", "quick", "garage", "archive", "achievements", "settings", "continue"]

var profile: RefCounted
var buttons: Dictionary = {}
var canvas: Control
var labels: Dictionary = {}
var layout_scale: float = 1.0
var layout_offset := Vector2.ZERO
var art_rect := Rect2()
var setup: Dictionary = {"skill": "pulse", "skin": "industrial", "skill_color": "mint"}
var time: float = 0.0
var _motion_clock: float = 0.0
var _hovered: String = ""
var _booted: bool = false
var display_font: FontFile
var body_font: FontFile

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# Private scalable glyph atlases keep large windows crisp without mutating
	# the shared CJK resource used by combat and other screens.
	body_font = BODY_FONT.duplicate() as FontFile
	body_font.multichannel_signed_distance_field = true
	body_font.msdf_size = 64
	display_font = DISPLAY_FONT.duplicate() as FontFile
	display_font.multichannel_signed_distance_field = true
	display_font.msdf_size = 64
	var ui_theme := Theme.new()
	ui_theme.default_font = body_font
	ui_theme.default_font_size = 16
	theme = ui_theme
	canvas = Control.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.size = DESIGN_SIZE
	add_child(canvas)
	_build()
	_booted = true
	resized.connect(_layout)
	visibility_changed.connect(_visibility_changed)
	_layout()
	refresh()
	var settings: Node = get_node_or_null("/root/Settings")
	if settings != null and settings.has_signal("preferences_changed"):
		settings.connect("preferences_changed", refresh)

func configure(value: RefCounted) -> void:
	profile = value
	if _booted:
		refresh()

func refresh() -> void:
	if not _booted:
		return
	var data: Dictionary = profile.get("data") if profile != null else {}
	setup = profile.call("get_setup") if profile != null and profile.has_method("get_setup") else data.get("selected", setup).duplicate(true)
	labels.kicker.text = tr("LAUNCH_KICKER")
	labels.subtitle.text = tr("SUBTITLE")
	labels.profile.text = tr("LAUNCH_PROFILE") % [int(data.get("coins", 0)), data.get("owned", []).size()]
	labels.overtime_desc.text = tr("LAUNCH_OVERTIME_DESC")
	labels.standard_desc.text = tr("LAUNCH_STANDARD_DESC")
	labels.quick_desc.text = tr("LAUNCH_QUICK_DESC")
	labels.version.text = tr("LAUNCH_VERSION")
	labels.ready.text = tr("LAUNCH_READY")
	labels.rig_skill.text = tr("GARAGE_SKILL_" + str(setup.get("skill", "pulse")).to_upper())
	labels.rig_cosmetics.text = tr("GARAGE_SKIN_" + str(setup.get("skin", "industrial")).to_upper()) + "  /  " + tr("GARAGE_COLOR_" + str(setup.get("skill_color", "mint")).to_upper())
	labels.rig_hint.text = tr("LAUNCH_EDIT_HINT")
	var title: String = str(setup.get("title", ""))
	labels.title.text = "" if title.is_empty() else tr("TITLE_" + title.to_upper())
	var button_keys: Dictionary = {"overtime": "LAUNCH_OVERTIME", "standard": "LAUNCH_STANDARD", "quick": "LAUNCH_QUICK", "garage": "GARAGE", "archive": "LAUNCH_ARCHIVE", "achievements": "LAUNCH_ACHIEVEMENTS", "settings": "SETTINGS"}
	for id: String in button_keys:
		buttons[id].text = tr(button_keys[id])
		buttons[id].add_theme_font_override("font", body_font if TranslationServer.get_locale().begins_with("zh") else display_font)
		buttons[id].add_theme_font_size_override("font_size", _entry_font_size(id))
	var checkpoint: Variant = data.get("checkpoint", {})
	var saved: bool = checkpoint is Dictionary and not checkpoint.is_empty()
	buttons["continue"].disabled = not saved
	buttons["continue"].text = tr("CONTINUE_SAVED" if saved else "NO_SAVED_SHIFT")
	buttons["continue"].tooltip_text = tr("LAUNCH_RESUME_HINT" if saved else "LAUNCH_NO_SAVE_HINT")
	buttons.quick.tooltip_text = tr("QUICK_LOADOUT") % labels.rig_skill.text
	labels.rig_skill.add_theme_color_override("font_color", Art.skill_color(setup))
	queue_redraw()

func _entry_font_size(id: String) -> int:
	var chinese: bool = TranslationServer.get_locale().begins_with("zh")
	if id == "overtime":
		return 27 if chinese else 35
	if id == "standard":
		return 22 if chinese else 28
	return 17 if chinese else 21

func _build() -> void:
	labels.kicker = _label(Rect2(58, 37, 580, 25), 13, Color("88afb9"))
	var wordmark := _label(Rect2(54, 77, 565, 83), 78, Kit.INK)
	wordmark.text = "SCRAPSTORM"
	wordmark.add_theme_font_override("font", display_font)
	labels.subtitle = _label(Rect2(59, 159, 500, 37), 25, Kit.GOLD)
	labels.profile = _label(Rect2(60, 211, 500, 25), 14, Color("b2c0c0"))
	_entry("overtime", Rect2(58, 256, 488, 87), true)
	labels.overtime_desc = _label(Rect2(82, 310, 435, 24), 14, Color("302b1e"))
	_entry("standard", Rect2(58, 358, 488, 73))
	labels.standard_desc = _label(Rect2(82, 402, 435, 22), 13, Color("acbabd"))
	_entry("quick", Rect2(58, 446, 488, 45))
	labels.quick_desc = _label(Rect2(430, 457, 91, 25), 13, Kit.MUTED)
	labels.quick_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_entry("garage", Rect2(58, 516, 238, 42))
	_entry("archive", Rect2(308, 516, 238, 42))
	_entry("achievements", Rect2(58, 568, 238, 42))
	_entry("settings", Rect2(308, 568, 238, 42))
	_entry("continue", Rect2(58, 632, 488, 39))
	buttons["continue"].add_theme_font_size_override("font_size", 15)
	labels.version = _label(Rect2(60, 690, 430, 21), 11, Color("72939f"))
	labels.ready = _label(Rect2(786, 574, 410, 21), 12, Color("a3bbc2"))
	labels.rig_skill = _label(Rect2(786, 601, 425, 34), 22, Kit.MINT)
	labels.rig_cosmetics = _label(Rect2(786, 640, 420, 25), 13, Color("b6c5c6"))
	labels.rig_hint = _label(Rect2(786, 670, 420, 24), 12, Color("809ba4"))
	labels.title = _label(Rect2(750, 48, 474, 27), 15, Kit.GOLD)
	labels.title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for i: int in range(ENTRIES.size()):
		var current: Button = buttons[ENTRIES[i]]
		current.focus_next = current.get_path_to(buttons[ENTRIES[(i + 1) % ENTRIES.size()]])
		current.focus_previous = current.get_path_to(buttons[ENTRIES[(i - 1 + ENTRIES.size()) % ENTRIES.size()]])

func _label(rect: Rect2, font_size: int, color: Color) -> Label:
	var result: Label = Kit.text(canvas, rect, font_size, color)
	result.add_theme_font_override("font", body_font)
	result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return result

func _entry(id: String, rect: Rect2, primary: bool = false) -> void:
	var button := Button.new()
	button.position = rect.position
	button.size = rect.size
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_color_override("font_color", Color("152129") if primary else Kit.INK)
	button.add_theme_color_override("font_hover_color", Color("152129") if primary else Kit.GOLD)
	button.add_theme_color_override("font_pressed_color", Color("152129") if primary else Kit.GOLD)
	button.add_theme_color_override("font_focus_color", Color("152129") if primary else Kit.INK)
	button.add_theme_color_override("font_disabled_color", Color("61757c"))
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("f3b849") if primary else Color(0.063, 0.10, 0.12, 0.9)
		style.border_color = Color("ffd486") if primary else Color("344750")
		style.border_width_left = 3 if primary else 1
		style.border_width_bottom = 3 if primary else 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.corner_radius_top_right = 10 if primary else 2
		style.corner_radius_bottom_left = 2
		style.content_margin_left = 23
		style.content_margin_right = 24
		style.content_margin_top = 2
		style.content_margin_bottom = 25 if id in ["overtime", "standard"] else 2
		style.shadow_color = Color(0, 0, 0, 0.4)
		style.shadow_size = 5 if primary else 1
		style.shadow_offset = Vector2(0, 4)
		if state == "hover":
			style.bg_color = Color("ffd481") if primary else Color("23343e")
			style.border_color = Kit.GOLD
		elif state == "pressed":
			style.bg_color = Color("c68b28") if primary else Color("0b161b")
		elif state == "disabled":
			style.bg_color = Color(0.05, 0.08, 0.10, 0.7)
			style.border_color = Color("283b43")
		elif state == "focus":
			style.bg_color = Color.TRANSPARENT
			style.border_color = Kit.MINT
			style.set_border_width_all(2)
			style.shadow_size = 0
		button.add_theme_stylebox_override(state, style)
	canvas.add_child(button)
	buttons[id] = button
	button.pressed.connect(func() -> void: emit_signal(id + "_requested"))
	button.mouse_entered.connect(func() -> void: _hovered = id; queue_redraw())
	button.mouse_exited.connect(func() -> void: _hovered = ""; queue_redraw())

func _layout() -> void:
	if not _booted or size.x <= 0 or size.y <= 0:
		return
	layout_scale = minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	layout_offset = (size - DESIGN_SIZE * layout_scale) * 0.5
	canvas.scale = Vector2.ONE * layout_scale
	canvas.position = layout_offset
	var artwork_scale: float = maxf(size.x / KEYART.get_width(), size.y / KEYART.get_height())
	var artwork_size := KEYART.get_size() * artwork_scale
	art_rect = Rect2((size - artwork_size) * 0.5, artwork_size)
	queue_redraw()

func _visibility_changed() -> void:
	set_process(is_visible_in_tree())
	if is_visible_in_tree():
		refresh()

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var settings: Node = get_node_or_null("/root/Settings")
	if settings != null and not bool(settings.get("effects_enabled")):
		if time != 0:
			time = 0
			queue_redraw()
		return
	_motion_clock += delta
	if _motion_clock < 1.0 / 24.0:
		return
	time += _motion_clock
	_motion_clock = 0
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("050c11"))
	if art_rect.has_area():
		draw_texture_rect(KEYART, art_rect, false)
	# UI uses an independent, uniform logical scale. No width/height distortion.
	draw_set_transform(layout_offset, 0, Vector2.ONE * layout_scale)
	# A quiet editorial rail protects small text without boxing in the scene.
	draw_line(Vector2(58, 243), Vector2(546, 243), Color("526063"), 1)
	draw_line(Vector2(58, 243), Vector2(155, 243), Kit.GOLD, 2)
	draw_rect(Rect2(750, 559, 474, 142), Color(0.022, 0.045, 0.060, 0.88))
	draw_line(Vector2(750, 559), Vector2(1224, 559), Color("475c64"), 1)
	draw_line(Vector2(750, 559), Vector2(808, 559), Art.skill_color(setup), 2)
	Art.icon(self, Vector2(765, 618), str(setup.get("skill", "pulse")), Art.skill_color(setup), 0.37)
	# Sparse dust hangs in the right-hand light shaft; no gameplay RNG is touched.
	if time > 0:
		for i: int in range(12):
			var p := Vector2(707 + fposmod(i * 89.0 + sin(time * 0.12 + i) * 18, 488), 108 + fposmod(i * 43.0 - time * (1.3 + i % 3), 401))
			draw_circle(p, 0.8 + float(i % 2) * 0.3, Color(0.95, 0.78, 0.46, 0.12 + sin(time * 0.6 + i) * 0.045))
	if _hovered in ["overtime", "standard", "quick"]:
		var rect: Rect2 = buttons[_hovered].get_rect()
		draw_line(rect.position + Vector2(-9, 10), rect.position + Vector2(-9, rect.size.y - 10), Kit.GOLD, 2)
	draw_set_transform(Vector2.ZERO)
