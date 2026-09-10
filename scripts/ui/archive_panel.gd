extends Control
## Read-only battle archive; only explicitly equipping an earned reward writes data.
signal back_requested
const K = preload("res://scripts/ui/ui_kit.gd")
const Catalog = preload("res://scripts/services/achievement_catalog.gd")
const Art = preload("res://scripts/ui/hangar_visual.gd")
const PAGE_SIZE: int = 6
var profile: RefCounted
var current_tab: String = "history"
var page: int = 0
var selected_run: String = ""
var selected_achievement: String = "first_shift"
var history_items: Array = []
var achievement_items: Array = []
var title_label: Label
var subtitle: Label
var overview: Label
var back_button: Button
var history_tab: Button
var achievement_tab: Button
var previous_button: Button
var next_button: Button
var page_label: Label
var local_label: Label
var list_root: Control
var detail_root: Control
var detail_text: RichTextLabel
var reward_button: Button
var selected_status: Dictionary = {}
var message: String = ""

class Medal:
	extends Control
	var tint: Color = Color("ffc04d")
	var earned: bool = false
	var number: int = 1
	var large: bool = false
	func _draw() -> void:
		var p: Vector2 = size * 0.5
		var radius: float = minf(size.x, size.y) * 0.37
		var ink: Color = tint if earned else Color("6a7c85")
		draw_colored_polygon(PackedVector2Array([p + Vector2(-radius * 0.7, radius * 0.6), p + Vector2(-radius * 0.75, radius * 1.35), p + Vector2(0, radius * 1.0), p + Vector2(radius * 0.75, radius * 1.35), p + Vector2(radius * 0.7, radius * 0.6)]), Color(ink, 0.5))
		var points := PackedVector2Array()
		for index: int in range(8):
			points.append(p + Vector2.from_angle(index * TAU / 8.0 + PI / 8.0) * radius)
		draw_colored_polygon(points, Color("14252e"))
		points.append(points[0])
		draw_polyline(points, ink, 3.0 if large else 2.0, true)
		draw_arc(p, radius * 0.77, 0, TAU, 32, Color(ink, 0.4), 1.5, true)
		var arms: int = 3 + number % 4
		for index: int in range(arms):
			var direction: Vector2 = Vector2.from_angle(index * TAU / float(arms) - PI / 2)
			draw_line(p + direction * radius * 0.18, p + direction * radius * 0.53, ink, 3.0 if large else 2.0, true)
		draw_circle(p, radius * 0.16, ink)
		if earned:
			draw_circle(p + Vector2(radius * 0.71, -radius * 0.71), radius * 0.18, Color("8af0bf"))

class RewardArt:
	extends Control
	var item: Dictionary = {}
	var setup: Dictionary = {}
	func _draw() -> void:
		var center: Vector2 = size * 0.5
		var tint: Color = Color(item.get("color", "ffc04d"))
		draw_circle(center, 73, Color(tint, 0.06))
		draw_arc(center, 70, 0.15, TAU - 0.15, 64, Color(tint, 0.4), 1.5, true)
		if item.get("kind", "") == "skin":
			Art.robot(self, center + Vector2(0, 9), 0.7, setup, 0.0)
		elif item.get("kind", "") == "skill_color":
			for index: int in range(14):
				var angle: float = index * TAU / 14.0
				var p: Vector2 = center + Vector2.from_angle(angle) * 28
				var q: Vector2 = center + Vector2.from_angle(angle + 0.17) * 57
				draw_line(p, q, tint, 2.5, true)
				draw_circle(q, 2.0, Color("ede3ce"))
			Art.icon(self, center, setup.get("skill", "pulse"), tint, 1.2)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	K.panel(self, Rect2(0, 0, 1280, 720), K.BG)
	title_label = K.text(self, Rect2(44, 22, 900, 49), 32)
	subtitle = K.text(self, Rect2(46, 73, 1100, 27), 15, K.MUTED)
	back_button = K.button(self, Rect2(1080, 28, 154, 44), func(): back_requested.emit())
	history_tab = K.button(self, Rect2(44, 111, 244, 43), func(): _select_tab("history"))
	achievement_tab = K.button(self, Rect2(299, 111, 258, 43), func(): _select_tab("achievements"))
	overview = K.text(self, Rect2(587, 116, 646, 32), 17, K.MINT)
	overview.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	list_root = Control.new()
	list_root.position = Vector2(44, 170)
	list_root.size = Vector2(730, 446)
	add_child(list_root)
	detail_root = Control.new()
	detail_root.position = Vector2(792, 170)
	detail_root.size = Vector2(442, 462)
	add_child(detail_root)
	previous_button = K.button(self, Rect2(44, 640, 152, 41), func(): _change_page(-1))
	next_button = K.button(self, Rect2(368, 640, 152, 41), func(): _change_page(1))
	page_label = K.text(self, Rect2(207, 643, 150, 35), 18)
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	local_label = K.text(self, Rect2(552, 643, 682, 34), 13, K.MUTED)
	local_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func present(value: RefCounted, tab: String = "history") -> void:
	profile = value
	current_tab = tab if tab in ["history", "achievements"] else "history"
	page = 0
	selected_run = ""
	message = ""
	refresh()
	visible = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and profile != null:
		refresh()

func _clear(control: Control) -> void:
	for child: Node in control.get_children():
		control.remove_child(child)
		child.queue_free()

func _select_tab(tab: String) -> void:
	current_tab = tab
	page = 0
	message = ""
	refresh()

func _change_page(direction: int) -> void:
	page += direction
	selected_run = ""
	message = ""
	refresh()

func refresh() -> void:
	if profile == null or not is_node_ready():
		return
	title_label.text = tr("ARCHIVE_TITLE")
	subtitle.text = tr("ARCHIVE_SUBTITLE")
	back_button.text = tr("BACK")
	history_tab.text = tr("ARCHIVE_HISTORY")
	achievement_tab.text = tr("ARCHIVE_ACHIEVEMENTS")
	previous_button.text = tr("ARCHIVE_PREVIOUS")
	next_button.text = tr("ARCHIVE_NEXT")
	local_label.text = tr("ARCHIVE_LOCAL")
	K.selected(history_tab, current_tab == "history")
	K.selected(achievement_tab, current_tab == "achievements")
	_clear(list_root)
	_clear(detail_root)
	detail_text = null
	reward_button = null
	if current_tab == "history":
		_history()
	else:
		_achievements()

func _pagination(pages: int) -> void:
	page = clampi(page, 0, pages - 1)
	page_label.text = tr("ARCHIVE_PAGE") % [page + 1, pages]
	previous_button.disabled = page == 0
	next_button.disabled = page >= pages - 1

func _history() -> void:
	var result: Dictionary = profile.get_history(page, PAGE_SIZE)
	page = result.page
	history_items = result.items
	_pagination(result.pages)
	overview.text = tr("ARCHIVE_RUNS") % result.total
	if history_items.is_empty():
		var empty: Label = K.text(list_root, Rect2(26, 144, 680, 110), 22, K.MUTED)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.text = tr("ARCHIVE_EMPTY")
		K.panel(detail_root, Rect2(0, 0, 442, 462))
		var hint: Label = K.text(detail_root, Rect2(26, 183, 390, 110), 18, K.MUTED)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.text = tr("ARCHIVE_SELECT")
		return
	if selected_run.is_empty() or not history_items.any(func(entry: Dictionary): return entry.run_id == selected_run):
		selected_run = history_items[0].run_id
	for index: int in range(history_items.size()):
		var entry: Dictionary = history_items[index]
		var button: Button = K.button(list_root, Rect2(0, index * 73, 730, 66), _choose_history.bind(index))
		K.selected(button, entry.run_id == selected_run)
		var row_name: Label = K.text(button, Rect2(17, 6, 476, 26), 17)
		row_name.text = "%s · %s" % [tr("ARCHIVE_" + str(entry.mode).to_upper()), _map(entry)]
		row_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var outcome: Label = K.text(button, Rect2(494, 8, 217, 26), 14, _outcome_color(entry))
		outcome.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		outcome.text = _outcome(entry)
		var secondary: Label = K.text(button, Rect2(17, 34, 695, 25), 14, K.MUTED)
		secondary.text = "%s   /   %s   /   %s %d   /   +%d %s" % [_date(entry.ended_at), _clock(entry.combat_seconds), tr("KILLS"), entry.kills, entry.coins, tr("COINS")]
		if entry.run_id == selected_run:
			_history_detail(entry)

func _choose_history(index: int) -> void:
	if index >= 0 and index < history_items.size():
		selected_run = history_items[index].run_id
		refresh()

func _history_detail(entry: Dictionary) -> void:
	K.panel(detail_root, Rect2(0, 0, 442, 462))
	var heading: Label = K.text(detail_root, Rect2(21, 15, 400, 34), 22, _outcome_color(entry))
	heading.text = _outcome(entry)
	detail_text = RichTextLabel.new()
	detail_text.position = Vector2(22, 60)
	detail_text.size = Vector2(397, 379)
	detail_text.bbcode_enabled = true
	detail_text.selection_enabled = true
	detail_text.add_theme_font_size_override("normal_font_size", 16)
	detail_text.add_theme_color_override("default_color", K.INK)
	detail_root.add_child(detail_text)
	var lines: Array[String] = []
	lines.append(_pair("ARCHIVE_DATE", _date(entry.ended_at)))
	lines.append(_pair("ARCHIVE_COMBAT", _clock(entry.combat_seconds)))
	lines.append(_pair("ARCHIVE_ROOMS" if entry.mode == "endless" else "ARCHIVE_WAVES", "%d / %d" % [entry.rooms, entry.cycles] if entry.mode == "endless" else str(entry.waves)))
	lines.append(_pair("KILLS", str(entry.kills)) + "    " + _pair("RESULT_SCRAP", str(entry.scrap)))
	lines.append(_pair("COINS", "+%d" % entry.coins))
	lines.append(_pair("ARCHIVE_DAMAGE", "%.1f / %d" % [entry.damage_taken, entry.damage_events] if entry.damage_tracked else tr("ARCHIVE_UNKNOWN")))
	lines.append(_pair("ARCHIVE_BOSSES", "%d / %.1f" % [entry.boss_kills, entry.boss_damage_taken] if entry.boss_damage_tracked else tr("ARCHIVE_UNKNOWN")))
	lines.append(_pair("ARCHIVE_SKILL", "%s / %d" % [tr("GARAGE_SKILL_" + str(entry.skill).to_upper()), entry.skill_uses]))
	lines.append("\n[color=#ffc04d]%s[/color]" % tr("ARCHIVE_LOADOUT"))
	var tools: Array[String] = []
	for group: String in ["weapons", "mods"]:
		for id: String in entry.loadout.get(group, {}):
			if int(entry.loadout[group][id]) > 0:
				tools.append("%s %s" % [tr("ITEM_" + id.to_upper()), ["", "I", "II", "III"][int(entry.loadout[group][id])]])
	lines.append(" · ".join(tools) if not tools.is_empty() else tr("ARCHIVE_NONE"))
	var evolved: Array[String] = []
	for id: String in entry.evolutions:
		evolved.append(tr("EVOLUTION_" + id.to_upper()))
	lines.append(_pair("ARCHIVE_EVOLUTIONS", " · ".join(evolved) if not evolved.is_empty() else tr("ARCHIVE_NONE")))
	if entry.mode == "endless":
		var conditions: Array[String] = []
		for id: String in entry.mutators:
			var key: String = "OT_RISK_" + id.to_upper()
			conditions.append(_escape(tr(key) if tr(key) != key else id))
		lines.append(_pair("ARCHIVE_MUTATORS", " · ".join(conditions) if not conditions.is_empty() else tr("ARCHIVE_NONE")))
	if not entry.achievements.is_empty():
		var milestones: Array[String] = []
		for id: String in entry.achievements:
			milestones.append(tr(Catalog.DEFINITIONS[id].name_key))
		lines.append(_pair("ARCHIVE_NEW_ACHIEVEMENTS", " · ".join(milestones)))
	lines.append("\n[color=#a0afb2]%s: %s[/color]" % [tr("ARCHIVE_RUN_ID"), _escape(entry.run_id)])
	detail_text.text = "\n".join(lines)

func _achievements() -> void:
	achievement_items = profile.get_achievements()
	var pages: int = maxi(1, ceili(float(achievement_items.size()) / PAGE_SIZE))
	_pagination(pages)
	var earned: int = profile.data.achievements.size()
	overview.text = tr("ARCHIVE_ACH_COUNT") % [earned, achievement_items.size()]
	var first: int = page * PAGE_SIZE
	var stop: int = mini(first + PAGE_SIZE, achievement_items.size())
	if not achievement_items.slice(first, stop).any(func(status: Dictionary): return status.id == selected_achievement):
		selected_achievement = achievement_items[first].id
	for index: int in range(first, stop):
		var status: Dictionary = achievement_items[index]
		var relative: int = index - first
		var origin := Vector2((relative % 2) * 370, (relative / 2) * 149)
		var card: Button = K.button(list_root, Rect2(origin, Vector2(359, 140)), _choose_achievement.bind(status.id))
		K.selected(card, status.id == selected_achievement)
		var medal := Medal.new()
		medal.position = Vector2(10, 16)
		medal.size = Vector2(71, 78)
		medal.mouse_filter = MOUSE_FILTER_IGNORE
		medal.tint = Color(status.color)
		medal.earned = status.claimed
		medal.number = index
		card.add_child(medal)
		var name_label: Label = K.text(card, Rect2(89, 13, 254, 48), 17)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.text = tr(status.name_key)
		var progress: Label = K.text(card, Rect2(90, 65, 245, 23), 14, K.MINT if status.claimed else K.MUTED)
		progress.text = tr("ARCHIVE_CLAIMED") if status.claimed else tr("ARCHIVE_PROGRESS") % [status.progress, status.target]
		var bar := ColorRect.new()
		bar.position = Vector2(17, 116)
		bar.size = Vector2(326, 5)
		bar.color = Color("0d1b23")
		bar.mouse_filter = MOUSE_FILTER_IGNORE
		card.add_child(bar)
		var fill := ColorRect.new()
		fill.size = Vector2(326 * (1.0 if status.claimed else float(status.progress) / float(status.target)), 5)
		fill.color = Color(status.color) if status.claimed else K.STEEL
		fill.mouse_filter = MOUSE_FILTER_IGNORE
		bar.add_child(fill)
		if status.id == selected_achievement:
			selected_status = status
			_achievement_detail(status, index)

func _choose_achievement(id: String) -> void:
	selected_achievement = id
	message = ""
	refresh()

func _achievement_detail(status: Dictionary, index: int) -> void:
	K.panel(detail_root, Rect2(0, 0, 442, 462))
	var item: Dictionary = Catalog.REWARDS.get(status.reward, {})
	if item.get("kind", "") in ["skin", "skill_color"]:
		var art := RewardArt.new()
		art.position = Vector2(120, 6)
		art.size = Vector2(200, 155)
		art.mouse_filter = MOUSE_FILTER_IGNORE
		art.item = item
		art.setup = profile.get_setup()
		art.setup[item.kind] = item.value
		detail_root.add_child(art)
	else:
		var medal := Medal.new()
		medal.position = Vector2(143, 3)
		medal.size = Vector2(156, 151)
		medal.mouse_filter = MOUSE_FILTER_IGNORE
		medal.tint = Color(status.color)
		medal.number = index
		medal.earned = status.claimed
		medal.large = true
		detail_root.add_child(medal)
	var heading: Label = K.text(detail_root, Rect2(19, 160, 404, 38), 24)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.text = tr(status.name_key)
	heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var description: Label = K.text(detail_root, Rect2(23, 206, 396, 81), 16, K.MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.text = tr(status.desc_key)
	var reward: Label = K.text(detail_root, Rect2(24, 294, 397, 49), 17, K.GOLD)
	reward.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reward.text = tr("ARCHIVE_COIN_REWARD") % status.coins + " · " + (tr(item.name_key) if not item.is_empty() else tr("ARCHIVE_BADGE"))
	var state: Label = K.text(detail_root, Rect2(24, 350, 397, 25), 14, K.MINT if status.claimed else K.MUTED)
	state.text = tr("ARCHIVE_CLAIMED") if status.claimed else "%s · %s" % [tr("ARCHIVE_LOCKED"), tr("ARCHIVE_PROGRESS") % [status.progress, status.target]]
	if not item.is_empty():
		reward_button = K.button(detail_root, Rect2(24, 391, 393, 45), _equip_reward, bool(status.claimed))
		var equipped: bool = status.claimed and profile.data.selected.get(item.kind, "") == item.value
		reward_button.disabled = not status.claimed or equipped
		reward_button.text = tr("ARCHIVE_EQUIPPED" if equipped else "ARCHIVE_EQUIP")
	else:
		var note: Label = K.text(detail_root, Rect2(24, 399, 395, 28), 14, K.MUTED)
		note.text = tr("ARCHIVE_COSMETIC")
	if not message.is_empty():
		state.text = tr(message)

func _equip_reward() -> void:
	if profile == null or selected_status.is_empty() or not selected_status.get("claimed", false):
		return
	var result: Dictionary = profile.equip(str(selected_status.reward))
	message = result.get("reason", "")
	if result.ok:
		var sound: Node = get_node_or_null("/root/SoundBank")
		if sound != null:
			sound.call("play", "install")
	refresh()

func _map(entry: Dictionary) -> String:
	return tr("MAP_" + str(entry.map).to_upper()) if entry.map in ["yard", "foundry", "reactor"] else tr("ARCHIVE_" + str(entry.mode).to_upper())

func _outcome(entry: Dictionary) -> String:
	return tr("ARCHIVE_EXTRACTED" if entry.extracted else ("ARCHIVE_WON" if entry.won else ("ARCHIVE_ABANDONED" if entry.abandoned else "ARCHIVE_DEFEAT")))

func _outcome_color(entry: Dictionary) -> Color:
	return K.MINT if entry.won or entry.extracted else (K.GOLD if entry.abandoned else K.RUST)

func _pair(key: String, value: String) -> String:
	return "[color=#a0afb2]%s[/color]  %s" % [tr(key), value]

func _escape(value: String) -> String:
	var escaped: String = ""
	for character: String in value:
		escaped += "[lb]" if character == "[" else ("[rb]" if character == "]" else character)
	return escaped

func _clock(seconds: float) -> String:
	return "%02d:%02d" % [int(seconds) / 60, int(seconds) % 60]

func _date(timestamp: int) -> String:
	return Time.get_datetime_string_from_unix_time(timestamp).replace("T", " ").left(16) + " UTC"
