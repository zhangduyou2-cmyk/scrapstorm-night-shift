extends SceneTree
## Presentation fixtures use explicit equipment and currency; never earned gameplay.
const Shop = preload("res://scripts/ui/shop_panel.gd")
const Loadout = preload("res://scripts/game/run_loadout.gd")
var checks: int = 0
var failures: Array[String] = []
var captures: Array[String] = []
var panel: Control
var loadout: RefCounted
var capture: bool = false

func _initialize() -> void:
	_run.call_deferred()

func verify(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func _run() -> void:
	if "--test-settings" not in OS.get_cmdline_user_args():
		push_error("Requires --test-settings")
		quit(1)
		return
	capture = "--capture" in OS.get_cmdline_user_args()
	root.get_node("Settings").set_locale("en")
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var theme := Theme.new()
	theme.default_font = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
	panel = Shop.new()
	panel.theme = theme
	root.add_child(panel)
	loadout = Loadout.new()
	loadout.weapons.foam = 1
	loadout.weapons.arc = 1
	var standard: Dictionary = _stats(3)
	panel.present([_offer("saw", 1), _offer("brush", 2), _offer("hull", 1)], standard, {"wave": 1})
	verify(panel.slot_panels[2].visible and not panel.slot_panels[3].visible and panel.build_label.text.ends_with("3/3"), "Standard shop retains exactly three visible installed slots")
	verify(panel.cards[0].buy.disabled and not panel.cards[1].buy.disabled, "Full standard rig blocks discovery but permits installed-tool upgrades")
	verify(panel.help_label.text == tr("SHOP_RULE_SLOTS") and panel.continue_button.text == tr("NEXT_WAVE") % 2, "Standard rules and next-stage wording remain intact")
	await snap("shop-standard-three-en")
	loadout.weapons.foam = 0
	loadout.weapons.arc = 1
	loadout.weapons.laser = 1
	var endless: Dictionary = _stats(4)
	panel.present([_offer("drone", 1), _offer("missile", 1), _offer("mines", 1)], endless, {"wave": 6})
	verify(not panel.cards[0].buy.disabled and panel.build_label.text.ends_with("3/4"), "Overtime's fourth slot accepts another tool")
	verify(panel.continue_button.text == tr("OT_ROUTE_OPEN") and panel.help_label.text == tr("SHOP_RULE_FOUR"), "Overtime routes replace the standard boss or wave-five button")
	loadout.weapons.drone = 1
	endless = _stats(4)
	panel.present([_offer("laser", 2), _offer("missile", 1), _offer("drone", 2)], endless, {"wave": 6})
	verify(panel.slot_panels[3].visible and panel.build_label.text.ends_with("4/4"), "All four installed overtime tools remain visible")
	verify(panel.cards[1].buy.disabled and not panel.cards[0].buy.disabled, "Full overtime rig blocks a fifth tool but permits upgrades")
	verify(panel.cards[1].buy.text == tr("SHOP_SLOTS_FULL_FOUR") and panel.title_label.text == tr("OT_SHOP_TITLE") % 6, "Overtime names four filled slots and cleared rooms accurately")
	verify(panel.slot_panels[3].get_rect().end.y < panel.evolve_label.position.y, "Fourth slot cannot overlap the evolution label")
	verify(panel.sell_buttons[3].visible and panel.sell_buttons[3].position.y >= panel.slot_panels[3].position.y, "Fourth tool keeps its own aligned sale button")
	for id: String in Loadout.WEAPON_IDS:
		var text: String = panel._comparison(_offer(id, 2))
		var after: Dictionary = Loadout.tool_stats(id, 2)
		verify(not text.is_empty() and text.contains(panel._number(float(after.damage) * 1.24)) and not text.contains("STAT_"), "Shared damage multiplier and valid comparison for " + id)
	verify(panel._comparison(_offer("laser", 2)).contains("500") and panel._comparison(_offer("laser", 2)).contains("0.55"), "Laser preview includes range and wind-up")
	verify(panel._comparison(_offer("drone", 2)).contains("Drones 1 → 2") and panel._comparison(_offer("drone", 2)).contains("360"), "Drone preview uses drone count and range without a radius field")
	verify(panel._comparison(_offer("missile", 3)).contains("Missiles 1 → 2"), "Top missile tier previews its second missile")
	verify(panel._comparison(_offer("mines", 2)).contains("0.7"), "Mine preview exposes its arming delay")
	await snap("shop-four-slots-laser-missile-drone-en")
	panel.present([_offer("drone", 2), _offer("mines", 2), _offer("repair", 1)], endless, {"wave": 6})
	verify(panel.cards[2].tag.text == tr("SHOP_CONSUMABLE") and panel.cards[2].benefit.text.contains("+35"), "Repair is a consumable with an explicit 35-hull benefit")
	verify(panel.cards[2].comparison.text.contains("40 → 75") and not panel.cards[2].comparison.text.contains(tr("STAT_HULL")), "Repair previews actual current hull and never permanent max hull")
	verify(not panel.cards[2].buy.disabled, "A damaged affordable rig can buy the repair pack")
	var requested: Array[String] = []
	panel.purchase_requested.connect(func(token: String) -> void: requested.append(token))
	panel.cards[2].buy.pressed.emit()
	verify(requested.size() == 1 and panel.stats.currency == 200, "Repair emits its offer token without local currency mutation")
	await snap("shop-mines-repair-en")
	root.get_node("Settings").set_locale("zh_CN")
	panel.refresh()
	root.size = Vector2i(960, 540)
	await snap("shop-four-slots-zh-960")
	endless.health = 91.0
	panel.present([_offer("repair", 1)], endless, {"wave": 6})
	verify(panel.cards[0].comparison.text.contains("91 → 100"), "Repair preview caps restoration at maximum hull")
	endless.health = 100.0
	panel.present([_offer("repair", 1)], endless, {"wave": 6})
	verify(panel.cards[0].buy.disabled and panel.cards[0].buy.text == tr("SHOP_HULL_FULL"), "A full hull cannot accidentally spend scrap on repair")
	panel.queue_free()
	await process_frame
	await root.get_node("SoundBank").shutdown()
	var result: Dictionary = {"checks": checks, "failures": failures, "screenshots": captures, "fixture": "Explicit UI inventory, health and currency; not gameplay balance or earned progression."}
	print("V05_SHOP_TEST ", JSON.stringify(result))
	var file := FileAccess.open("res://artifacts/v05-shop-validation.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(result, "  ") + "\n")
	quit(0 if failures.is_empty() else 1)

func _stats(slots: int) -> Dictionary:
	return {"weapon_slots": slots, "endless_mode": slots == 4, "wave": 6 if slots == 4 else 1, "currency": 200, "health": 40.0, "max_health": 100.0, "damage_scale": 1.24, "cooldown_scale": 0.84, "loadout": {"weapons": loadout.weapons.duplicate(), "mods": loadout.mods.duplicate()}, "sell_options": [{"id": "arc", "refund": 12, "available": true}, {"id": "laser", "refund": 12, "available": true}, {"id": "drone", "refund": 12, "available": true}]}

func _offer(id: String, level: int) -> Dictionary:
	return {"id": id, "kind": "consumable" if id == "repair" else ("weapon" if id in Loadout.WEAPON_IDS else "mod"), "token": "fixture:" + id + ":" + str(level), "level": level, "cost": 48, "sold": false, "name_key": "ITEM_" + id.to_upper(), "desc_key": "ITEM_" + id.to_upper() + "_DESC"}

func snap(name: String) -> void:
	if not capture:
		return
	await process_frame
	await create_timer(0.07).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://captures/v05")
	var path: String = "res://captures/v05/" + name + ".png"
	var result: int = root.get_texture().get_image().save_png(path)
	verify(result == OK, "Native shop screenshot saved: " + name)
	if result == OK:
		captures.append(path.trim_prefix("res://"))
