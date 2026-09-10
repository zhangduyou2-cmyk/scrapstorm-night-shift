extends Control
var endless_mode: bool = false
## Two-step dispatch desk: choose sector, then configure the actual next-run setup.
signal deploy_requested(map_id: String)
signal back_requested
const Kit = preload("res://scripts/ui/ui_kit.gd")
const Maps = preload("res://scripts/game/map_catalog.gd")
const Profile = preload("res://scripts/services/player_profile.gd")
const Preview = preload("res://scripts/ui/skill_preview.gd")
const Art = preload("res://scripts/ui/hangar_visual.gd")
var selected: String = "yard"
var step: int = 0
var profile: RefCounted
var cards: Array[Dictionary] = []
var skill_cards: Array[Dictionary] = []
var cosmetic_buttons: Dictionary = {}
var title_label: Label
var subtitle: Label
var deploy: Button
var back: Button
var hint: Label
var sector_content: Control
var loadout_content: Control
var sector_preview: Control
var rig_preview: Control
var map_description: Label
var boss_label: Label
var skill_description: Label
var preview_label: Label
var selected_label: Label
var replay: Button
var skin_label: Label
var color_label: Label
var inspected_skill: String = "pulse"
var message_key: String = ""
var icon_layer: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	Kit.panel(self, Rect2(0, 0, 1280, 720), Kit.BG)
	title_label = Kit.text(self, Rect2(40, 26, 1150, 56), 34)
	subtitle = Kit.text(self, Rect2(42, 91, 1120, 31), 16, Kit.GOLD)
	sector_content = Control.new()
	sector_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sector_content)
	for index: int in range(3):
		var id: String = Maps.ids()[index]
		var y: float = 145 + index * 145
		var button: Button = Kit.button(sector_content, Rect2(40, y, 350, 128), _select_sector.bind(id))
		var number: Label = Kit.text(sector_content, Rect2(60, y + 12, 50, 29), 14, Kit.MUTED)
		number.text = "0%d" % (index + 1)
		var name_label: Label = Kit.text(sector_content, Rect2(60, y + 41, 310, 34), 21)
		var status: Label = Kit.text(sector_content, Rect2(60, y + 83, 310, 27), 13, Kit.MUTED)
		cards.append({"id": id, "button": button, "name": name_label, "status": status})
	sector_preview = Preview.new()
	sector_preview.position = Vector2(416, 145)
	sector_preview.size = Vector2(824, 391)
	sector_content.add_child(sector_preview)
	Kit.panel(sector_content, Rect2(416, 496, 824, 40), Color("10222b"))
	boss_label = Kit.text(sector_content, Rect2(434, 500, 790, 29), 16, Kit.GOLD)
	map_description = Kit.text(sector_content, Rect2(417, 552, 820, 56), 16, Kit.INK)
	map_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	loadout_content = Control.new()
	loadout_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(loadout_content)
	preview_label = Kit.text(loadout_content, Rect2(40, 133, 510, 27), 14, Kit.MINT)
	rig_preview = Preview.new()
	rig_preview.position = Vector2(40, 168)
	rig_preview.size = Vector2(507, 338)
	loadout_content.add_child(rig_preview)
	replay = Kit.button(loadout_content, Rect2(345, 515, 202, 38), func() -> void: rig_preview.replay())
	selected_label = Kit.text(loadout_content, Rect2(41, 517, 298, 32), 20, Kit.GOLD)
	skill_description = Kit.text(loadout_content, Rect2(41, 567, 506, 63), 15, Kit.MUTED)
	skill_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for index: int in range(3):
		var id: String = ["pulse", "overdrive", "singularity"][index]
		var y: float = 145 + index * 102
		var button: Button = Kit.button(loadout_content, Rect2(581, y, 659, 91), _select_skill.bind(id))
		var name_label: Label = Kit.text(loadout_content, Rect2(658, y + 10, 385, 31), 20)
		var desc: Label = Kit.text(loadout_content, Rect2(658, y + 45, 561, 35), 13, Kit.MUTED)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var status: Label = Kit.text(loadout_content, Rect2(1043, y + 14, 177, 29), 13, Kit.GOLD)
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		skill_cards.append({"id": id, "button": button, "name": name_label, "description": desc, "status": status})
	skin_label = Kit.text(loadout_content, Rect2(581, 461, 650, 29), 14, Kit.MUTED)
	color_label = Kit.text(loadout_content, Rect2(581, 550, 650, 29), 14, Kit.MUTED)
	for kind: String in ["skin", "skill_color"]:
		var options: Array = ["skin_industrial", "skin_arctic", "skin_hazard"] if kind == "skin" else ["color_mint", "color_cyan", "color_violet"]
		var y: float = 496 if kind == "skin" else 584
		for index: int in range(3):
			var id: String = str(options[index])
			var button: Button = Kit.button(loadout_content, Rect2(581 + index * 224, y, 211, 39), _equip_cosmetic.bind(id))
			button.add_theme_font_size_override("font_size", 14)
			cosmetic_buttons[id] = button
	icon_layer = Control.new()
	icon_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_layer.draw.connect(_draw_skill_icons)
	loadout_content.add_child(icon_layer)
	back = Kit.button(self, Rect2(40, 652, 285, 47), _back)
	hint = Kit.text(self, Rect2(349, 647, 478, 53), 13, Kit.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	deploy = Kit.button(self, Rect2(851, 652, 389, 47), _advance, true)
	refresh()

func present(value: RefCounted) -> void:
	profile = value
	step = 0
	message_key = ""
	inspected_skill = str(profile.data.selected.skill)
	refresh()
	sector_preview.configure({}, "map", selected)
	rig_preview.configure(profile.get_setup())

func _select_sector(id: String) -> void:
	selected = id
	sector_preview.configure({}, "map", selected)
	get_node("/root/SoundBank").play("ui")
	refresh()

func _advance() -> void:
	if step == 0:
		step = 1
		if profile != null:
			inspected_skill = str(profile.data.selected.skill)
			rig_preview.configure(profile.get_setup())
		refresh()
	else:
		deploy_requested.emit(selected)

func _back() -> void:
	if step == 1:
		step = 0
		message_key = ""
		refresh()
	else:
		back_requested.emit()

func _select_skill(id: String) -> void:
	if profile == null:
		return
	inspected_skill = id
	message_key = ""
	if profile.owns("skill_" + id):
		var result: Dictionary = profile.equip("skill_" + id)
		if not result.ok:
			message_key = str(result.reason)
	else:
		message_key = "HANGAR_PREVIEW_ONLY"
	var setup: Dictionary = profile.get_setup()
	setup.skill = id
	rig_preview.configure(setup)
	rig_preview.replay()
	get_node("/root/SoundBank").play("ui")
	refresh()

func _equip_cosmetic(id: String) -> void:
	if profile == null or not profile.owns(id):
		return
	var result: Dictionary = profile.equip(id)
	message_key = "" if result.ok else str(result.reason)
	var setup: Dictionary = profile.get_setup()
	setup.skill = inspected_skill
	rig_preview.configure(setup)
	refresh()

func refresh() -> void:
	if not is_instance_valid(title_label):
		return
	sector_content.visible = step == 0
	loadout_content.visible = step == 1
	title_label.text = tr("OT_MISSION_TITLE" if endless_mode else "MISSION_TITLE") if step == 0 else tr("MISSION_STEP_LOADOUT")
	subtitle.text = tr("OT_MISSION_HINT" if endless_mode else "MISSION_STEP_SECTOR") if step == 0 else tr(Maps.get_map(selected).name_key) + "   /   " + tr("MISSION_LOADOUT_HINT")
	back.text = tr("BACK") if step == 0 else tr("MISSION_CHANGE_SECTOR")
	deploy.text = tr("MISSION_PREPARE") if step == 0 else tr("MISSION_DEPLOY")
	hint.text = tr("OT_MISSION_DETAIL" if endless_mode else "MISSION_HINT") if step == 0 else (tr(message_key) if not message_key.is_empty() else tr("GARAGE_HINT"))
	for card: Dictionary in cards:
		var map: Dictionary = Maps.get_map(card.id)
		card.name.text = tr(map.name_key)
		card.name.add_theme_color_override("font_color", map.color)
		card.status.text = tr("MISSION_PREPARE") if card.id == selected else tr("MISSION_SELECT")
		Kit.selected(card.button, card.id == selected)
	var map: Dictionary = Maps.get_map(selected)
	boss_label.text = tr("MISSION_BOSS") + "  /  " + tr(map.boss_name_key)
	map_description.text = tr(map.mechanic_key) + "\n" + tr(map.desc_key)
	replay.text = tr("HANGAR_REPLAY")
	preview_label.text = tr("HANGAR_PREVIEW_ONLY") if profile != null and not profile.owns("skill_" + inspected_skill) else tr("HANGAR_LIVE_PREVIEW")
	skin_label.text = tr("GARAGE_TAB_SKIN")
	color_label.text = tr("GARAGE_TAB_SKILL_COLOR")
	if profile == null:
		return
	selected_label.text = tr("GARAGE_SKILL_" + str(profile.data.selected.skill).to_upper())
	skill_description.text = tr("GARAGE_SKILL_" + inspected_skill.to_upper() + "_DESC")
	for card: Dictionary in skill_cards:
		var owned: bool = profile.owns("skill_" + card.id)
		var equipped: bool = profile.data.selected.skill == card.id
		card.name.text = tr("GARAGE_SKILL_" + str(card.id).to_upper())
		card.description.text = tr("MISSION_ROLE_" + str(card.id).to_upper())
		var owned_key: String = "HANGAR_FREE" if int(Profile.CATALOG["skill_" + card.id].cost) == 0 else "HANGAR_OWNED"
		card.status.text = tr("GARAGE_ACTIVE") if equipped else (tr(owned_key) if owned else tr("HANGAR_LOCKED"))
		Kit.selected(card.button, equipped)
	for id: String in cosmetic_buttons:
		var item: Dictionary = Profile.CATALOG[id]
		var button: Button = cosmetic_buttons[id]
		button.text = tr("GARAGE_" + id.to_upper())
		button.disabled = not profile.owns(id)
		button.tooltip_text = tr("HANGAR_LOCKED") if button.disabled else tr("GARAGE_" + id.to_upper() + "_DESC")
		Kit.selected(button, profile.data.selected[item.kind] == item.value)
	icon_layer.queue_redraw()

func _draw_skill_icons() -> void:
	for index: int in range(skill_cards.size()):
		var id: String = str(skill_cards[index].id)
		Art.icon(icon_layer, Vector2(622, 190 + index * 102), id, Kit.GOLD if profile != null and profile.data.selected.skill == id else Kit.MINT, 0.8)
