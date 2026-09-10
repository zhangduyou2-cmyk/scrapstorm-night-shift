extends Control
## Between-room route choice; world and profile own mutations and persistence.
signal route_requested(index: int)
signal back_requested
signal continue_requested
signal extract_requested
const Kit = preload("res://scripts/ui/ui_kit.gd")
const Maps = preload("res://scripts/game/map_catalog.gd")
var stats: Dictionary = {}
var cards: Array[Dictionary] = []
var title_label: Label
var subtitle: Label
var intel: Label
var status: Label
var back: Button
var onward: Button
var extract: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	Kit.panel(self, Rect2(0, 0, 1280, 720), Color("09151f"))
	Kit.panel(self, Rect2(34, 30, 1212, 100), Color("152a34"))
	title_label = Kit.text(self, Rect2(60, 41, 1130, 48), 36, Kit.GOLD)
	subtitle = Kit.text(self, Rect2(62, 94, 1155, 30), 16, Kit.MINT)
	intel = Kit.text(self, Rect2(62, 144, 1155, 56), 17, Kit.INK)
	intel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for index: int in range(3):
		var x: float = 50 + index * 400
		Kit.panel(self, Rect2(x, 218, 380, 340), Color("18303b"))
		var serial := Kit.text(self, Rect2(x + 22, 235, 330, 29), 16, Kit.MINT)
		serial.text = "0%d   /   OVERTIME" % (index + 1)
		var name := Kit.text(self, Rect2(x + 22, 275, 335, 40), 24, Kit.GOLD)
		var benefit := Kit.text(self, Rect2(x + 22, 325, 333, 72), 17, Kit.INK)
		benefit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var danger := Kit.text(self, Rect2(x + 22, 411, 333, 75), 15, Color("ffab87"))
		danger.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var button := Kit.button(self, Rect2(x + 22, 500, 336, 42), func() -> void: route_requested.emit(index))
		cards.append({"name": name, "benefit": benefit, "danger": danger, "button": button})
	status = Kit.text(self, Rect2(62, 580, 1150, 43), 16, Kit.MINT)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	back = Kit.button(self, Rect2(50, 652, 250, 46), func() -> void: back_requested.emit())
	extract = Kit.button(self, Rect2(480, 652, 310, 46), func() -> void: extract_requested.emit())
	onward = Kit.button(self, Rect2(870, 652, 360, 46), func() -> void: continue_requested.emit(), true)
	refresh()

func present(value: Dictionary) -> void:
	stats = value.duplicate(true)
	refresh()

func refresh() -> void:
	if not is_instance_valid(title_label):
		return
	var room: int = int(stats.get("endless_room", 1))
	var next: int = room + 1
	title_label.text = tr("OT_ROUTE_TITLE")
	subtitle.text = tr("OT_ROUTE_SUBTITLE") % [room, int(stats.get("cycles_completed", 0)), int(stats.get("currency", 0))]
	var boss_next: bool = next % 3 == 0
	intel.text = tr("OT_NEXT_BOSS" if boss_next else "OT_NEXT_ROOM") % next
	if room % 3 == 0:
		intel.text += "  " + tr("OT_MAP_ROTATES")
	var choices: Array = stats.get("route_choices", [])
	var selected: int = int(stats.get("route_choice", -1))
	for index: int in range(cards.size()):
		var card: Dictionary = cards[index]
		card.button.disabled = selected >= 0 or index >= choices.size()
		if index >= choices.size():
			continue
		var choice: Dictionary = choices[index]
		card.name.text = tr("OT_BOON_" + str(choice.boon).to_upper()) + "  " + ("MAX" if choice.supply else "◆ %d" % int(choice.rank))
		card.benefit.text = tr("OT_SUPPLY" if choice.supply else "OT_BOON_" + str(choice.boon).to_upper() + "_DESC")
		card.danger.text = tr("OT_RISK") + " · " + tr("OT_RISK_" + str(choice.risk).to_upper())
		card.button.text = tr("OT_SELECTED" if selected == index else "OT_CHOOSE")
		Kit.selected(card.button, selected == index)
		card.button.add_theme_color_override("font_color", Kit.INK)
		card.button.add_theme_color_override("font_disabled_color", Kit.GOLD if selected == index else Kit.MUTED)
	onward.disabled = selected < 0
	onward.text = tr("OT_DEPLOY") % next
	back.text = tr("OT_BACK_SHOP")
	extract.visible = bool(stats.get("can_extract", false))
	extract.text = tr("OT_EXTRACT")
	status.text = tr("OT_ROUTE_SAVED" if selected >= 0 else "OT_ROUTE_HINT")
