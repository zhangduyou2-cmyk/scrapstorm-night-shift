extends Control
## Industrial supply bench. World remains the only transaction authority.
signal purchase_requested(token: String)
signal next_wave_requested
signal settings_requested
signal menu_requested
signal reroll_requested
signal branch_requested(id: String)
signal sell_requested(id: String)
const Loadout = preload("res://scripts/game/run_loadout.gd")
const Kit = preload("res://scripts/ui/ui_kit.gd")
const Preview = preload("res://scripts/ui/skill_preview.gd")
const BG := Color("101c24")
const PANEL := Color("1c2c34")
const INK := Color("ede3ce")
const MUTED := Color("a0afb2")
const GOLD := Color("ffc04d")
const MINT := Color("58d9e7")
var offers: Array = []
var stats: Dictionary = {}
var summary: Dictionary = {}
var title_label: Label
var summary_label: Label
var wallet_label: Label
var build_label: Label
var help_label: Label
var status_label: Label
var continue_button: Button
var settings_button: Button
var menu_button: Button
var reroll_button: Button
var mod_labels: Array[Label] = []
var cards: Array[Dictionary] = []
var last_message_key: String = "SHOP_HINT"
var icon_layer: Control
var rig_preview: Control
var slot_labels: Array[Label] = []
var slot_panels: Array[Panel] = []
var sell_buttons: Array[Button] = []
var slot_ids: Array[String] = []
var branch_cards: Array[Dictionary] = []
var branch_title: Label
var branch_hint: Label
var install_fx: float = 0.0
var install_index: int = -1
var evolve_label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	Kit.panel(self, Rect2(0, 0, 1280, 720), BG)
	title_label = _text(Vector2(40, 27), Vector2(850, 57), 34, INK)
	summary_label = _text(Vector2(42, 88), Vector2(1195, 34), 15, MUTED)
	wallet_label = _text(Vector2(954, 30), Vector2(286, 46), 26, GOLD)
	wallet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	build_label = _text(Vector2(41, 146), Vector2(275, 28), 16, GOLD)
	rig_preview = Preview.new()
	rig_preview.position = Vector2(40, 181)
	rig_preview.size = Vector2(270, 180)
	rig_preview.demonstration = false
	add_child(rig_preview)
	for index: int in range(4):
		var y: float = 374 + index * 56
		slot_panels.append(Kit.panel(self, Rect2(40, y, 270, 47)))
		var slot: Label = _text(Vector2(82, y + 6), Vector2(144, 36), 14, INK)
		slot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		slot_labels.append(slot)
		var sell: Button = _action(Rect2(229, y + 5, 76, 37))
		sell.add_theme_font_size_override("font_size", 12)
		sell.pressed.connect(_sell.bind(index))
		sell_buttons.append(sell)
	evolve_label = _text(Vector2(42, 546), Vector2(268, 58), 13, MINT)
	evolve_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for index: int in range(3):
		var x: float = 330 + index * 307
		_panel(Rect2(x, 177, 296, 286))
		var tag := _text(Vector2(x + 15, 189), Vector2(266, 22), 12, MINT)
		var item_name := _text(Vector2(x + 77, 220), Vector2(204, 53), 20, INK)
		item_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var benefit := _text(Vector2(x + 15, 281), Vector2(266, 35), 19, GOLD)
		var comparison := _text(Vector2(x + 15, 320), Vector2(266, 67), 14, MINT)
		comparison.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var description := _text(Vector2(x + 15, 389), Vector2(266, 21), 12, MUTED)
		description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var buy := _action(Rect2(x + 15, 414, 266, 39), true)
		buy.add_theme_font_size_override("font_size", 14)
		buy.pressed.connect(_request_purchase.bind(index))
		cards.append({"tag": tag, "name": item_name, "description": description, "comparison": comparison, "benefit": benefit, "buy": buy})
	branch_title = _text(Vector2(330, 478), Vector2(470, 29), 14, GOLD)
	branch_hint = _text(Vector2(802, 478), Vector2(440, 29), 12, MUTED)
	branch_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for index: int in range(2):
		var x: float = 330 + index * 460
		var button: Button = _action(Rect2(x, 514, 450, 84))
		button.pressed.connect(_branch.bind(index))
		var label: Label = _text(Vector2(x + 14, 520), Vector2(330, 29), 17, INK)
		var rank: Label = _text(Vector2(x + 330, 521), Vector2(105, 27), 12, GOLD)
		rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var description: Label = _text(Vector2(x + 14, 552), Vector2(423, 40), 13, MUTED)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		branch_cards.append({"button": button, "name": label, "description": description, "rank": rank, "id": ""})
	Kit.panel(self, Rect2(40, 612, 1200, 44), Color("14262e"))
	for index: int in range(6):
		var detail: Label = _text(Vector2(78 + index * 199, 614), Vector2(153, 40), 12, INK)
		mod_labels.append(detail)
	help_label = _text(Vector2(332, 132), Vector2(534, 28), 12, MUTED)
	status_label = _text(Vector2(332, 157), Vector2(908, 22), 12, MINT)
	reroll_button = _action(Rect2(886, 131, 354, 39))
	reroll_button.add_theme_font_size_override("font_size", 13)
	reroll_button.pressed.connect(func() -> void: reroll_requested.emit())
	menu_button = _action(Rect2(40, 668, 189, 38))
	menu_button.pressed.connect(func() -> void: menu_requested.emit())
	settings_button = _action(Rect2(242, 668, 154, 38))
	settings_button.pressed.connect(func() -> void: settings_requested.emit())
	continue_button = _action(Rect2(922, 668, 318, 38), true)
	continue_button.pressed.connect(func() -> void: next_wave_requested.emit())
	icon_layer = Control.new()
	icon_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_layer.draw.connect(_draw_icons)
	add_child(icon_layer)
	refresh()

func present(next_offers: Array, next_stats: Dictionary, next_summary: Dictionary) -> void:
	offers = next_offers.duplicate(true)
	stats = next_stats.duplicate(true)
	summary = next_summary.duplicate(true)
	last_message_key = "SHOP_HINT"
	refresh()
	rig_preview.configure({"skill": stats.get("ability_id", "pulse"), "skin": stats.get("skin", "industrial"), "skill_color": stats.get("skill_color", "mint")})

func purchase_result(result: Dictionary, next_offers: Array, next_stats: Dictionary) -> void:
	offers = next_offers.duplicate(true)
	stats = next_stats.duplicate(true)
	last_message_key = "SHOP_PURCHASED" if result.get("ok", false) else "SHOP_CANNOT_BUY"
	if result.get("ok", false):
		install_fx = 0.9
	refresh()

func sale_result(result: Dictionary, next_offers: Array, next_stats: Dictionary) -> void:
	purchase_result(result, next_offers, next_stats)
	last_message_key = str(result.get("reason", "SHOP_PURCHASED" if result.get("ok", false) else "SHOP_CANNOT_BUY"))
	refresh()

func branch_result(result: Dictionary, next_offers: Array, next_stats: Dictionary) -> void:
	sale_result(result, next_offers, next_stats)

func refresh_result(result: Dictionary, next_offers: Array, next_stats: Dictionary) -> void:
	offers = next_offers.duplicate(true)
	stats = next_stats.duplicate(true)
	last_message_key = "SHOP_REFRESHED" if result.get("ok", false) else "SHOP_REFRESH_FAILED"
	refresh()

func _process(delta: float) -> void:
	if install_fx > 0:
		install_fx = maxf(0, install_fx - delta)
		icon_layer.queue_redraw()

func refresh() -> void:
	if not is_instance_valid(title_label):
		return
	var completed: int = int(summary.get("wave", stats.get("wave", 1)))
	title_label.text = tr("OT_SHOP_TITLE" if bool(stats.get("endless_mode", false)) else "SHOP_TITLE") % completed
	summary_label.text = tr("SHOP_SUMMARY") % [int(summary.get("earned_scrap", 0)), int(summary.get("bonus", 0)), int(summary.get("repaired", 0))]
	wallet_label.text = "%s  %03d" % [tr("SCRAP"), int(stats.get("currency", 0))]
	var slot_count: int = _weapon_slots()
	help_label.text = tr("SHOP_RULE_FOUR" if slot_count == 4 else "SHOP_RULE_SLOTS")
	help_label.tooltip_text = help_label.text
	help_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status_label.text = tr(last_message_key)
	settings_button.text = tr("SETTINGS")
	menu_button.text = tr("MAIN_MENU")
	continue_button.text = tr("OT_ROUTE_OPEN") if bool(stats.get("endless_mode", false)) else (tr("ENTER_BOSS_ANY") if completed == 5 else tr("NEXT_WAVE") % (completed + 1))
	var refresh_cost: int = int(stats.get("reroll_cost", 12 + (completed - 1) * 6))
	var refresh_available: bool = bool(stats.get("can_reroll", false))
	reroll_button.disabled = not refresh_available or int(stats.get("currency", 0)) < refresh_cost
	reroll_button.text = tr("SHOP_REFRESH") % refresh_cost if refresh_available else tr("SHOP_REFRESH_USED")
	reroll_button.tooltip_text = tr("SHOP_REFRESH_HELP")
	for index: int in range(cards.size()):
		var card: Dictionary = cards[index]
		if index >= offers.size():
			card.tag.text = tr("SHOP_SOLD_OUT")
			card.name.text = ""
			card.description.text = ""
			card.comparison.text = ""
			card.benefit.text = ""
			card.buy.text = tr("SHOP_SOLD_OUT")
			card.buy.disabled = true
			continue
		var offer: Dictionary = offers[index]
		var consumable: bool = offer.get("kind") == "consumable"
		card.tag.text = tr("SHOP_CONSUMABLE") if consumable else "%s / %s %d" % [tr("SHOP_WEAPON" if offer.get("kind") == "weapon" else "SHOP_MOD"), tr("LEVEL"), int(offer.get("level", 1))]
		card.name.text = tr(str(offer.get("name_key", "")))
		card.description.text = tr(str(offer.get("desc_key", "")))
		card.buy.tooltip_text = card.description.text + "\n" + _comparison(offer)
		var compare: PackedStringArray = _comparison(offer).split("\n")
		if offer.get("kind") == "weapon" or consumable:
			card.benefit.text = compare[0]
			compare.remove_at(0)
			card.comparison.text = "\n".join(compare)
		else:
			card.benefit.text = _mod_detail(str(offer.id), int(offer.get("level", 1)))
			card.comparison.text = _comparison(offer)
		var sold: bool = bool(offer.get("sold", false))
		var affordable: bool = int(stats.get("currency", 0)) >= int(offer.get("cost", 0))
		var full_slots: bool = offer.get("kind") == "weapon" and int(offer.get("level", 1)) == 1 and _equipped_count() >= slot_count
		var full_hull: bool = str(offer.get("id", "")) == "repair" and float(stats.get("health", 0)) >= float(stats.get("max_health", 100))
		card.buy.disabled = sold or not affordable or full_slots or full_hull
		var action_key: String = ("SHOP_USE" if consumable else "SHOP_BUY") if affordable else "SHOP_NEED"
		card.buy.text = tr("SHOP_CONSUMED" if consumable else "SHOP_INSTALLED") if sold else (tr("SHOP_HULL_FULL") if full_hull else (tr("SHOP_SLOTS_FULL_FOUR" if slot_count == 4 else "SHOP_SLOTS_FULL") if full_slots else "%s · %d %s" % [tr(action_key), int(offer.get("cost", 0)), tr("SCRAP")]))
	var loadout: Dictionary = stats.get("loadout", {})
	var weapons: Dictionary = loadout.get("weapons", {"brush": 1})
	slot_ids.clear()
	for id: String in Loadout.WEAPON_IDS:
		if int(weapons.get(id, 0)) > 0:
			slot_ids.append(id)
	build_label.text = "%s · %d/%d" % [tr("SHOP_BENCH"), slot_ids.size(), slot_count]
	_layout_slots(slot_count)
	for index: int in range(slot_labels.size()):
		var id: String = slot_ids[index] if index < slot_ids.size() else ""
		slot_labels[index].text = "—" if id.is_empty() else "%s\n%s %d" % [tr("ITEM_" + id.to_upper()), tr("LEVEL"), int(weapons[id])]
		var option: Dictionary = {}
		for value: Dictionary in stats.get("sell_options", []):
			if value.id == id:
				option = value
		sell_buttons[index].visible = index < slot_count and not option.is_empty()
		sell_buttons[index].disabled = not bool(option.get("available", false))
		sell_buttons[index].text = tr("SHOP_SELL") % int(option.get("refund", 0))
		sell_buttons[index].tooltip_text = tr("SHOP_SELL_HELP")
	for index: int in range(Loadout.MOD_IDS.size()):
		var id: String = Loadout.MOD_IDS[index]
		var level: int = int(loadout.get("mods", {}).get(id, 0))
		mod_labels[index].text = "%s %s%d\n%s" % [tr("ITEM_" + id.to_upper()), tr("LEVEL_SHORT"), level, _mod_detail(id, level)]
		mod_labels[index].add_theme_color_override("font_color", INK if level > 0 else MUTED)
	var evolutions: PackedStringArray = []
	for value: Variant in stats.get("evolutions", []):
		if value is Dictionary:
			if bool(value.get("active", value.get("unlocked", false))):
				evolutions.append(tr(str(value.get("name_key", "EVO_" + str(value.get("id", "")).to_upper()))))
		elif value is String:
			evolutions.append(tr("EVO_" + value.to_upper()))
	evolve_label.text = " + ".join(evolutions)
	branch_title.text = tr("SHOP_BRANCH_TITLE")
	branch_hint.text = tr("SHOP_BRANCH_WAIT")
	var options: Array = stats.get("ability_branches", [])
	var available_branch: bool = false
	for option: Dictionary in options:
		available_branch = available_branch or bool(option.get("available", false))
	branch_title.add_theme_color_override("font_color", MINT if available_branch else GOLD)
	branch_hint.text = tr("SHOP_BRANCH_CHOOSE") if available_branch else tr("SHOP_BRANCH_WAIT")
	for index: int in range(branch_cards.size()):
		var card: Dictionary = branch_cards[index]
		card.button.visible = index < options.size()
		card.name.visible = card.button.visible
		card.description.visible = card.button.visible
		card.rank.visible = card.button.visible
		if index >= options.size():
			continue
		var option: Dictionary = options[index]
		card.id = str(option.id)
		card.name.text = tr(str(option.name_key))
		card.button.disabled = not bool(option.get("available", false))
		var selected: bool = bool(option.get("selected", false))
		var desc_key: String = str(option.desc_key)
		if selected and card.button.disabled:
			var rank: int = int(stats.get("ability_branch_rank", maxi(1, int(option.get("rank", 2)) - 1)))
			desc_key = str(option.name_key) + ("_UPGRADE_DESC" if rank >= 2 else "_DESC")
		card.description.text = tr(desc_key)
		card.button.tooltip_text = tr(desc_key)
		card.rank.text = tr("SHOP_BRANCH_UPGRADE" if selected else "SHOP_BRANCH_CHOOSE") if not card.button.disabled else (tr("GARAGE_ACTIVE") if selected else "—")
		Kit.selected(card.button, bool(option.get("selected", false)))
	icon_layer.queue_redraw()

func _sell(index: int) -> void:
	if index < slot_ids.size():
		sell_requested.emit(slot_ids[index])

func _branch(index: int) -> void:
	if index < branch_cards.size() and not branch_cards[index].button.disabled:
		branch_requested.emit(str(branch_cards[index].id))

func _equipped_count() -> int:
	var count: int = 0
	for level: Variant in stats.get("loadout", {}).get("weapons", {"brush": 1}).values():
		if int(level) > 0:
			count += 1
	return count

func _weapon_slots() -> int:
	return clampi(int(stats.get("weapon_slots", Loadout.MAX_WEAPON_SLOTS)), 3, 4)

func _layout_slots(count: int) -> void:
	for index: int in range(slot_panels.size()):
		var compact: bool = count == 4
		var y: float = (370 + index * 43) if compact else (374 + index * 56)
		slot_panels[index].visible = index < count
		slot_panels[index].position.y = y
		slot_panels[index].size.y = 39 if compact else 47
		slot_labels[index].visible = index < count
		slot_labels[index].position.y = y + (2 if compact else 6)
		slot_labels[index].size.y = 35 if compact else 36
		slot_labels[index].add_theme_font_size_override("font_size", 12 if compact else 14)
		sell_buttons[index].position.y = y + (3 if compact else 5)
		sell_buttons[index].size.y = 33 if compact else 37


func _comparison(offer: Dictionary) -> String:
	var id: String = str(offer.get("id", ""))
	if id == "repair":
		var hull: float = float(stats.get("health", 0))
		var maximum: float = float(stats.get("max_health", 100))
		return "%s +35\n%s %s → %s" % [tr("STAT_REPAIR"), tr("STAT_CURRENT_HULL"), _number(hull), _number(minf(maximum, hull + 35))]
	var after_level: int = int(offer.get("level", 1))
	var before_level: int = after_level - 1
	if id in Loadout.MOD_IDS:
		return "%s\n%s" % [tr("SHOP_BEFORE_AFTER"), _mod_detail(id, before_level) + "  →  " + _mod_value(id, after_level)]
	var before: Dictionary = Loadout.tool_stats(id, before_level)
	var after: Dictionary = Loadout.tool_stats(id, after_level)
	if after.is_empty():
		return ""
	var mod_levels: Dictionary = stats.get("loadout", {}).get("mods", {})
	var damage_scale: float = float(stats.get("damage_scale", 1.0 + 0.12 * int(mod_levels.get("torque", 0))))
	var cooldown_scale: float = float(stats.get("cooldown_scale", 1.0 - 0.08 * int(mod_levels.get("coolant", 0))))
	var damage: String = _number(float(before.get("damage", 0)) * damage_scale) if before_level > 0 else "—"
	var cycle: String = _number(float(before.get("interval", 0)) * cooldown_scale) if before_level > 0 else "—"
	var detail_key: String = "STAT_RADIUS"
	var detail_field: String = "radius"
	match id:
		"arc":
			detail_key = "STAT_TARGETS"
			detail_field = "hops"
		"saw":
			detail_key = "STAT_PIERCE"
			detail_field = "pierce"
		"laser":
			detail_key = "STAT_RANGE"
			detail_field = "range"
		"drone":
			detail_key = "STAT_DRONES"
			detail_field = "count"
	var prior_detail: String = _number(float(before.get(detail_field, 0))) if before_level > 0 else "—"
	var comparison: String = "%s %s → %s\n%s %s → %s  /  %s %s → %ss" % [tr("STAT_TICK_DAMAGE" if id == "foam" else "STAT_DAMAGE"), damage, _number(float(after.damage) * damage_scale), tr(detail_key), prior_detail, _number(float(after.get(detail_field, 0))), tr("STAT_CYCLE"), cycle, _number(float(after.interval) * cooldown_scale)]
	if id == "arc":
		comparison += "\n%s ×%s" % [tr("STAT_FOAM_COMBO"), _number(float(after.combo))]
	elif id == "foam":
		comparison += "\n%s %ss  /  %s %ss" % [tr("STAT_TICK_RATE"), _number(float(after.tick)), tr("STAT_DURATION"), _number(float(after.duration))]
	elif id == "laser":
		comparison += "\n%s %ss" % [tr("STAT_CHARGE_TIME"), _number(float(after.charge))]
	elif id == "missile":
		comparison += "\n%s %s → %s" % [tr("STAT_PROJECTILES"), _number(float(before.get("count", 0))) if before_level > 0 else "—", _number(float(after.count))]
	elif id == "drone":
		comparison += "\n%s %s" % [tr("STAT_RANGE"), _number(float(after.range))]
	elif id == "mines":
		comparison += "\n%s %ss" % [tr("STAT_ARM_TIME"), _number(float(after.arm))]
	return comparison


func _mod_detail(id: String, level: int) -> String:
	var key: String = str({"hull": "STAT_HULL", "treads": "STAT_SPEED", "magnet": "STAT_REACH", "capacitor": "STAT_CAPACITY", "torque": "STAT_DAMAGE", "coolant": "STAT_COOLDOWN"}.get(id, ""))
	return "%s %s" % [tr(key), _mod_value(id, level)]


func _mod_value(id: String, level: int) -> String:
	var current: int = int(stats.get("loadout", {}).get("mods", {}).get(id, 0))
	match id:
		"hull":
			return _number(float(stats.get("max_health", 100.0 + 20.0 * current)) - 20.0 * current + 20.0 * level)
		"treads":
			return _number(float(stats.get("player_speed", 215.0 * (1.0 + 0.08 * current))) / (1.0 + 0.08 * current) * (1.0 + 0.08 * level))
		"magnet":
			return _number(float(stats.get("vacuum_range", 240.0 * (1.0 + 0.15 * current))) / (1.0 + 0.15 * current) * (1.0 + 0.15 * level))
		"capacitor":
			return _number(float(stats.get("max_energy", 100.0 * (1.0 + 0.20 * current))) / (1.0 + 0.20 * current) * (1.0 + 0.20 * level))
		"torque":
			return "%d%%" % (100 + 12 * level)
		"coolant":
			return "%d%%" % (100 - 8 * level)
	return ""


func _number(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else ("%.2f" % value).trim_suffix("0")


func _request_purchase(index: int) -> void:
	if index < offers.size():
		install_index = index
		purchase_requested.emit(str(offers[index]["token"]))


func _text(pos: Vector2, box: Vector2, font_size: int, color: Color) -> Label:
	return Kit.text(self, Rect2(pos, box), font_size, color)

func _panel(rect: Rect2) -> void:
	Kit.panel(self, rect, PANEL)

func _action(rect: Rect2, primary: bool = false) -> Button:
	return Kit.button(self, rect, Callable(), primary)

func _draw_icons() -> void:
	for index: int in range(mini(offers.size(), cards.size())):
		_draw_item_icon(str(offers[index].get("id", "")), Vector2(368 + index * 307, 244), 0.74)
	for index: int in range(Loadout.MOD_IDS.size()):
		_draw_item_icon(Loadout.MOD_IDS[index], Vector2(58 + index * 199, 634), 0.33)
	for index: int in range(mini(slot_ids.size(), _weapon_slots())):
		var y: float = slot_panels[index].position.y + slot_panels[index].size.y * 0.5
		_draw_item_icon(slot_ids[index], Vector2(61, y), 0.34 if _weapon_slots() == 4 else 0.38)
	if install_fx > 0 and install_index >= 0:
		var rect := Rect2(330 + install_index * 307, 177, 296, 286)
		icon_layer.draw_rect(rect, Color(GOLD, install_fx * 0.65), false, 3)
		var p := Vector2(175, 292)
		for i: int in range(10):
			var a: float = i * TAU / 10
			var d: float = (1 - install_fx) * 52
			icon_layer.draw_line(p + Vector2.from_angle(a) * d, p + Vector2.from_angle(a) * (d + 9), Color(GOLD, install_fx), 2)

func _draw_item_icon(item: String, center: Vector2, scale_value: float) -> void:
	var color: Color = MINT if item in ["foam", "coolant"] else GOLD
	if item in ["arc", "capacitor", "magnet"]:
		color = Color("9bc9ff")
	elif item in ["laser", "drone"]:
		color = Color("d0abff") if item == "laser" else Color("87dfba")
	elif item in ["missile", "mines"]:
		color = Color("ffab71")
	elif item == "repair":
		color = Color("a5edbb")
	icon_layer.draw_set_transform(center, 0.0, Vector2.ONE * scale_value)
	icon_layer.draw_circle(Vector2.ZERO, 33, Color("233d47"))
	match item:
		"foam":
			for offset: Vector2 in [Vector2(-11, 4), Vector2(10, 7), Vector2(0, -12)]:
				icon_layer.draw_circle(offset, 11, color, false, 2, true)
		"arc":
			icon_layer.draw_polyline(PackedVector2Array([Vector2(9, -24), Vector2(-10, 2), Vector2(8, 2), Vector2(-9, 24)]), color, 4, true)
		"brush":
			icon_layer.draw_arc(Vector2.ZERO, 20, 0, TAU, 32, color, 5, true)
			for spoke: int in range(8):
				var direction := Vector2.from_angle(spoke * TAU / 8.0)
				icon_layer.draw_line(direction * 15, direction * 27, color, 3, true)
		"saw":
			var teeth := PackedVector2Array()
			for vertex: int in range(24):
				teeth.append(Vector2.from_angle(vertex * TAU / 24.0) * (26.0 if vertex % 2 == 0 else 18.0))
			teeth.append(teeth[0])
			icon_layer.draw_polyline(teeth, color, 2.0, true)
			icon_layer.draw_circle(Vector2.ZERO, 7, color, false, 3, true)
		"laser":
			icon_layer.draw_polyline(PackedVector2Array([Vector2(-24, 16), Vector2(-13, 5), Vector2(-5, 13), Vector2(-16, 24), Vector2(-24, 16)]), color, 3, true)
			icon_layer.draw_line(Vector2(-6, 5), Vector2(25, -26), color, 4, true)
			icon_layer.draw_line(Vector2(0, 9), Vector2(26, -17), Color(color, 0.4), 2, true)
			icon_layer.draw_line(Vector2(-10, -1), Vector2(16, -27), Color(color, 0.4), 2, true)
		"missile":
			icon_layer.draw_polyline(PackedVector2Array([Vector2(0, -27), Vector2(10, -11), Vector2(10, 12), Vector2(-10, 12), Vector2(-10, -11), Vector2(0, -27)]), color, 3, true)
			icon_layer.draw_polyline(PackedVector2Array([Vector2(-10, 1), Vector2(-21, 17), Vector2(-9, 13)]), color, 3, true)
			icon_layer.draw_polyline(PackedVector2Array([Vector2(10, 1), Vector2(21, 17), Vector2(9, 13)]), color, 3, true)
			icon_layer.draw_line(Vector2(0, 16), Vector2(0, 28), color, 4, true)
		"drone":
			icon_layer.draw_rect(Rect2(-8, -6, 16, 12), color, false, 3)
			for p: Vector2 in [Vector2(-20, -18), Vector2(20, -18), Vector2(-20, 18), Vector2(20, 18)]:
				icon_layer.draw_line(Vector2.ZERO, p, color, 2, true)
				icon_layer.draw_circle(p, 9, color, false, 2, true)
		"mines":
			icon_layer.draw_arc(Vector2(0, 7), 21, PI, TAU, 28, color, 3, true)
			icon_layer.draw_line(Vector2(-25, 9), Vector2(25, 9), color, 4, true)
			icon_layer.draw_circle(Vector2(0, -3), 4, color)
			for i: int in range(3):
				var p := Vector2(-16 + i * 16, -13)
				icon_layer.draw_line(p, p + Vector2(0, -9), color, 3, true)
			icon_layer.draw_line(Vector2(-15, 17), Vector2(15, 17), Color(color, 0.5), 2, true)
		"repair":
			icon_layer.draw_rect(Rect2(-22, -13, 44, 34), color, false, 3)
			icon_layer.draw_polyline(PackedVector2Array([Vector2(-10, -14), Vector2(-10, -23), Vector2(10, -23), Vector2(10, -14)]), color, 3, true)
			icon_layer.draw_line(Vector2(-11, 4), Vector2(11, 4), color, 5, true)
			icon_layer.draw_line(Vector2(0, -7), Vector2(0, 15), color, 5, true)
		"hull":
			icon_layer.draw_polyline(PackedVector2Array([Vector2(-21, -19), Vector2(21, -19), Vector2(19, 9), Vector2(0, 25), Vector2(-19, 9), Vector2(-21, -19)]), color, 3, true)
			icon_layer.draw_line(Vector2(0, -12), Vector2(0, 13), color, 3, true)
			icon_layer.draw_line(Vector2(-10, 0), Vector2(10, 0), color, 3, true)
		"treads":
			for side: float in [-14.0, 14.0]:
				icon_layer.draw_rect(Rect2(side - 7, -23, 14, 46), color, false, 3)
				for tooth: int in range(5):
					icon_layer.draw_line(Vector2(side - 6, -16 + tooth * 8), Vector2(side + 6, -16 + tooth * 8), color, 2, true)
		"magnet":
			icon_layer.draw_arc(Vector2(0, 3), 17, 0, PI, 24, color, 7, true)
			for side: float in [-17.0, 17.0]:
				icon_layer.draw_line(Vector2(side, 3), Vector2(side, -20), color, 7, true)
				icon_layer.draw_line(Vector2(side - 4, -12), Vector2(side + 4, -12), PANEL, 3, true)
		"capacitor":
			icon_layer.draw_line(Vector2(-7, -23), Vector2(-7, 23), color, 5, true)
			icon_layer.draw_line(Vector2(7, -23), Vector2(7, 23), color, 5, true)
			icon_layer.draw_line(Vector2(-26, 0), Vector2(-7, 0), color, 3, true)
			icon_layer.draw_line(Vector2(7, 0), Vector2(26, 0), color, 3, true)
		"torque":
			icon_layer.draw_arc(Vector2.ZERO, 19, 0, TAU, 24, color, 5, true)
			for spoke: int in range(6):
				var direction := Vector2.from_angle(spoke * TAU / 6.0)
				icon_layer.draw_line(direction * 20, direction * 28, color, 6, true)
			icon_layer.draw_circle(Vector2.ZERO, 7, color, false, 3, true)
		"coolant":
			for blade: int in range(3):
				var angle: float = blade * TAU / 3.0
				var points := PackedVector2Array([Vector2.ZERO, Vector2(21, -4).rotated(angle), Vector2(20, 11).rotated(angle), Vector2(7, 16).rotated(angle)])
				icon_layer.draw_colored_polygon(points, color)
			icon_layer.draw_circle(Vector2.ZERO, 5, PANEL)
	icon_layer.draw_set_transform(Vector2.ZERO)
