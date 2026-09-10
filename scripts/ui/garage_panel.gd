extends Control
## Maintenance bay: preview first, then explicitly equip, unlock or track an item.
signal back_requested
const Kit = preload("res://scripts/ui/ui_kit.gd")
const Profile = preload("res://scripts/services/player_profile.gd")
const Preview = preload("res://scripts/ui/skill_preview.gd")
const Art = preload("res://scripts/ui/hangar_visual.gd")
var profile: RefCounted
var category: String = "skill"
var cards: Array[Dictionary] = []
var tabs: Dictionary = {}
var title_label: Label
var coins_label: Label
var status: Label
var back: Button
var message_key: String = "GARAGE_HINT"
var preview_layer: Control
var selected_id: String = "skill_pulse"
var preview_title: Label
var preview_caption: Label
var description: Label
var purchase_button: Button
var target_button: Button
var replay_button: Button
var target_label: Label
var target_progress: ProgressBar
var icon_layer: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	Kit.panel(self, Rect2(0, 0, 1280, 720), Kit.BG)
	title_label = Kit.text(self, Rect2(40, 26, 860, 58), 34)
	coins_label = Kit.text(self, Rect2(930, 33, 310, 49), 25, Kit.GOLD)
	coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	preview_caption = Kit.text(self, Rect2(41, 99, 1130, 32), 14, Kit.MINT)
	preview_layer = Preview.new()
	preview_layer.position = Vector2(40, 145)
	preview_layer.size = Vector2(552, 368)
	add_child(preview_layer)
	preview_title = Kit.text(self, Rect2(40, 524, 338, 39), 24, Kit.GOLD)
	replay_button = Kit.button(self, Rect2(388, 526, 204, 37), func() -> void: preview_layer.replay())
	target_label = Kit.text(self, Rect2(41, 576, 550, 52), 14, Kit.MUTED)
	target_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	target_progress = ProgressBar.new()
	target_progress.position = Vector2(41, 632)
	target_progress.size = Vector2(549, 6)
	target_progress.show_percentage = false
	target_progress.add_theme_font_size_override("font_size", 1)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Kit.GOLD
	target_progress.add_theme_stylebox_override("fill", fill)
	var trough := StyleBoxFlat.new()
	trough.bg_color = Kit.STEEL
	target_progress.add_theme_stylebox_override("background", trough)
	add_child(target_progress)
	target_progress.size = Vector2(549, 6)
	var categories: Array[String] = ["skill", "skin", "skill_color"]
	for index: int in range(3):
		var id: String = categories[index]
		var button: Button = Kit.button(self, Rect2(622 + index * 209, 145, 200, 47), _category.bind(id))
		button.add_theme_font_size_override("font_size", 14)
		tabs[id] = button
	for index: int in range(3):
		var y: float = 213 + index * 101
		var button: Button = Kit.button(self, Rect2(622, y, 618, 88), _inspect.bind(index))
		var name_label: Label = Kit.text(self, Rect2(698, y + 12, 340, 34), 21)
		var note: Label = Kit.text(self, Rect2(698, y + 48, 341, 27), 13, Kit.MUTED)
		var ownership: Label = Kit.text(self, Rect2(1040, y + 19, 178, 53), 14, Kit.GOLD)
		ownership.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cards.append({"id": "", "button": button, "name": name_label, "description": note, "ownership": ownership})
	description = Kit.text(self, Rect2(625, 531, 611, 79), 16, Kit.INK)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	target_button = Kit.button(self, Rect2(622, 630, 295, 49), _track)
	purchase_button = Kit.button(self, Rect2(932, 630, 308, 49), _purchase_selected, true)
	back = Kit.button(self, Rect2(40, 655, 215, 42), func() -> void: back_requested.emit())
	status = Kit.text(self, Rect2(273, 655, 317, 41), 12, Kit.MUTED)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	icon_layer = Control.new()
	icon_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_layer.draw.connect(_draw_icons)
	add_child(icon_layer)
	refresh()

func present(value: RefCounted) -> void:
	profile = value
	category = "skill"
	selected_id = "skill_" + str(profile.data.selected.skill)
	message_key = "GARAGE_HINT"
	refresh()
	_preview()

func _category(value: String) -> void:
	category = value
	for id: String in Profile.CATALOG:
		var item: Dictionary = Profile.CATALOG[id]
		if item.kind == category and item.value == profile.data.selected[category]:
			selected_id = id
	message_key = "GARAGE_HINT"
	refresh()
	_preview()

func _inspect(index: int) -> void:
	if profile == null or index >= cards.size():
		return
	selected_id = str(cards[index].id)
	message_key = "GARAGE_HINT"
	_preview()
	preview_layer.replay()
	get_node("/root/SoundBank").play("ui")
	refresh()

func _preview() -> void:
	if profile == null or not Profile.CATALOG.has(selected_id):
		return
	var setup: Dictionary = profile.get_setup()
	var item: Dictionary = Profile.CATALOG[selected_id]
	setup[item.kind] = item.value
	preview_layer.configure(setup)

func _purchase_selected() -> void:
	if profile == null:
		return
	var result: Dictionary = profile.purchase(selected_id)
	message_key = str(result.reason)
	if result.ok:
		get_node("/root/SoundBank").play("unlock" if int(result.get("cost", 0)) > 0 else "ui")
		_preview()
		preview_layer.replay()
	refresh()

func _purchase(index: int) -> void:
	# Preserve the existing UI testing helper while selection and purchase stay separate.
	if index >= 0 and index < cards.size():
		selected_id = str(cards[index].id)
		_purchase_selected()

func _track() -> void:
	if profile == null or not profile.has_method("set_target") or profile.owns(selected_id):
		return
	var result: Variant = profile.set_target(selected_id)
	if result is Dictionary and not result.get("ok", false):
		message_key = str(result.get("reason", "PROFILE_SAVE_FAILED"))
	else:
		message_key = "HANGAR_TARGET"
	refresh()

func refresh() -> void:
	if not is_instance_valid(title_label) or profile == null:
		return
	title_label.text = tr("GARAGE_TITLE")
	coins_label.text = "%s  %d" % [tr("COINS"), int(profile.data.coins)]
	back.text = tr("BACK")
	replay_button.text = tr("HANGAR_REPLAY")
	status.text = tr(message_key)
	preview_caption.text = tr("HANGAR_LIVE_PREVIEW") if profile.owns(selected_id) else tr("HANGAR_PREVIEW_ONLY")
	preview_title.text = tr("GARAGE_" + selected_id.to_upper())
	description.text = tr("GARAGE_" + selected_id.to_upper() + "_DESC")
	var items: Array[String] = []
	for id: String in Profile.CATALOG:
		if Profile.CATALOG[id].kind == category:
			items.append(id)
	for id: String in tabs:
		tabs[id].text = tr("GARAGE_TAB_" + id.to_upper())
		Kit.selected(tabs[id], id == category)
	for index: int in range(cards.size()):
		var id: String = items[index]
		var item: Dictionary = Profile.CATALOG[id]
		var card: Dictionary = cards[index]
		card.id = id
		card.name.text = tr("GARAGE_" + id.to_upper())
		var equipped: bool = profile.data.selected[item.kind] == item.value
		card.description.text = tr("GARAGE_ACTIVE") if equipped else (tr("HANGAR_OWNED") if profile.owns(id) else tr("HANGAR_LOCKED"))
		card.ownership.text = "✓" if equipped else (tr("HANGAR_OWNED") if profile.owns(id) else "%d %s" % [int(item.cost), tr("COINS")])
		card.ownership.add_theme_color_override("font_color", Kit.MINT if profile.owns(id) else Kit.GOLD)
		Kit.selected(card.button, id == selected_id)
	var item: Dictionary = Profile.CATALOG[selected_id]
	var owned: bool = profile.owns(selected_id)
	var equipped: bool = profile.data.selected[item.kind] == item.value
	purchase_button.disabled = equipped or (not owned and int(profile.data.coins) < int(item.cost))
	purchase_button.text = tr("GARAGE_ACTIVE") if equipped else (tr("GARAGE_EQUIP") if owned else "%s · %d %s" % [tr("GARAGE_UNLOCK"), int(item.cost), tr("COINS")])
	var target: String = str(profile.data.get("target_unlock", ""))
	target_button.disabled = owned or target == selected_id
	target_button.text = tr("HANGAR_TARGET") if target == selected_id else tr("HANGAR_SET_TARGET")
	target_progress.visible = not target.is_empty() and Profile.CATALOG.has(target)
	if target_progress.visible:
		var cost: int = int(Profile.CATALOG[target].cost)
		target_progress.value = 100.0 * int(profile.data.coins) / maxf(1, cost)
		target_label.text = tr("HANGAR_TARGET") + " / " + tr("GARAGE_" + target.to_upper()) + "\n" + tr("HANGAR_TARGET_PROGRESS") % [int(profile.data.coins), cost]
	else:
		target_label.text = tr("GARAGE_HINT")
	icon_layer.queue_redraw()

func _draw_icons() -> void:
	if profile == null:
		return
	for index: int in range(cards.size()):
		var id: String = str(cards[index].id)
		if id.is_empty():
			continue
		var item: Dictionary = Profile.CATALOG[id]
		var p := Vector2(660, 257 + index * 101)
		if category == "skill":
			Art.icon(icon_layer, p, str(item.value), Kit.MINT, 0.72)
		elif category == "skin":
			var tint: Color = Kit.GOLD if item.value == "industrial" else (Kit.MINT if item.value == "arctic" else Kit.RUST)
			icon_layer.draw_circle(p, 23, tint)
			icon_layer.draw_rect(Rect2(p + Vector2(-17, -10), Vector2(34, 14)), Kit.BG)
			icon_layer.draw_line(p + Vector2(-10, -3), p + Vector2(-4, -3), Kit.INK, 3)
			icon_layer.draw_line(p + Vector2(4, -3), p + Vector2(10, -3), Kit.INK, 3)
		else:
			var tint: Color = Art.skill_color({"skill_color": item.value})
			icon_layer.draw_circle(p, 21, tint)
			icon_layer.draw_arc(p, 28, -0.6, 4.9, 32, Color(tint, 0.45), 2, true)
