extends SceneTree
## Shop transactions, build constraints, and checkpoint recovery without rendering.

const Loadout = preload("res://scripts/game/run_loadout.gd")
const ShopPanel = preload("res://scripts/ui/shop_panel.gd")
var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func verify(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)


func _snapshot(loadout: RefCounted) -> Dictionary:
	return loadout.export_state()


func _find_offer(loadout: RefCounted, id: String) -> Dictionary:
	for attempt: int in range(300):
		for offer: Dictionary in loadout.generate_offers(1):
			if offer["id"] == id:
				return offer
	return {}


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-shop="):
			await _capture_shop(argument.trim_prefix("--capture-shop="))
			return
	var loadout: RefCounted = Loadout.new()
	loadout.reset(1138)
	verify(loadout.weapons == {"brush": 1, "foam": 0, "arc": 0, "saw": 0, "laser": 0, "missile": 0, "drone": 0, "mines": 0} and loadout.slots == 3, "A standard run owns one brush among eight known tools and retains three slots")
	verify(loadout.mods.size() == 6 and loadout.mods.values().all(func(level: Variant) -> bool: return int(level) == 0), "All six modifications start at zero")
	verify(loadout.get_modifiers() == {"health_bonus": 0.0, "speed_scale": 1.0, "vacuum_scale": 1.0, "energy_scale": 1.0, "damage_scale": 1.0, "cooldown_scale": 1.0}, "Default modifiers preserve base balance")
	var offers: Array[Dictionary] = loadout.generate_offers(1)
	verify(offers.size() == 3, "A shop has three candidates")
	var seen: Dictionary = {}
	var has_new_tool: bool = false
	var has_upgrade: bool = false
	var has_mod: bool = false
	for offer: Dictionary in offers:
		seen[offer["id"]] = true
		has_new_tool = has_new_tool or (offer["kind"] == "weapon" and offer["level"] == 1)
		has_upgrade = has_upgrade or (offer["id"] == "brush" and offer["level"] == 2)
		has_mod = has_mod or offer["kind"] == "mod"
	verify(seen.size() == 3, "Candidates never repeat an item")
	verify(has_new_tool and has_upgrade and has_mod, "First shop guarantees a discovery, an equipped upgrade, and a modification")
	var pristine: Dictionary = _snapshot(loadout)
	offers[0]["cost"] = 0
	offers[0]["sold"] = true
	offers.clear()
	verify(_snapshot(loadout) == pristine, "Returned offers cannot mutate internal prices or sold state")
	offers = loadout.get_offers()
	var chosen: Dictionary = offers[0]
	var denied: Dictionary = loadout.purchase(chosen["token"], int(chosen["cost"]) - 1)
	verify(not denied["ok"] and denied["reason"] == "insufficient_currency" and denied["cost"] == 0 and _snapshot(loadout) == pristine, "Insufficient balance causes no inventory, RNG, or offer writes")
	denied = loadout.purchase(chosen["token"], -10)
	verify(not denied["ok"] and _snapshot(loadout) == pristine, "Negative balance cannot purchase")
	denied = loadout.purchase("unknown", 999)
	verify(not denied["ok"] and denied["reason"] == "invalid_offer" and _snapshot(loadout) == pristine, "Unknown token is rejected without mutation")
	var purchased: Dictionary = loadout.purchase(chosen["token"], int(chosen["cost"]))
	verify(purchased["ok"] and purchased["cost"] == chosen["cost"] and loadout.weapons[chosen["id"]] == 1 and loadout.get_offers()[0]["sold"], "Exact balance grants an unowned tool and marks the offer sold")
	pristine = _snapshot(loadout)
	denied = loadout.purchase(chosen["token"], 999)
	verify(not denied["ok"] and denied["reason"] == "sold" and _snapshot(loadout) == pristine, "Double purchase never charges or grants twice")
	loadout.generate_offers(2)
	pristine = _snapshot(loadout)
	denied = loadout.purchase(chosen["token"], 999)
	verify(not denied["ok"] and denied["reason"] == "invalid_offer" and _snapshot(loadout) == pristine, "Tokens from previous shops are invalid")
	var old_token: String = loadout.get_offers()[0]["token"]
	loadout.reset(1138)
	loadout.generate_offers(2)
	verify(not loadout.purchase(old_token, 999)["ok"], "Reset invalidates tokens from a previous run")

	var price_ok: bool = true
	for id: String in Loadout.WEAPON_IDS:
		loadout.reset(20)
		var begin_level: int = int(loadout.weapons[id])
		for current_level: int in range(begin_level, 3):
			var item: Dictionary = _find_offer(loadout, id)
			var expected_cost: int = 22 if current_level == 0 else 18 + current_level * 10
			price_ok = price_ok and not item.is_empty() and item.get("cost", 0) == expected_cost and item.get("level", 0) == current_level + 1
			if not item.is_empty():
				price_ok = price_ok and loadout.purchase(item["token"], 999)["ok"]
	verify(price_ok, "Each of the four tools can independently reach level three at configured prices")
	loadout.weapons = {"brush": 3, "foam": 3, "arc": 3, "saw": 0}
	var no_maxed_tools: bool = true
	for wave: int in range(1, 51):
		for item: Dictionary in loadout.generate_offers(wave):
			no_maxed_tools = no_maxed_tools and item["kind"] != "weapon"
	verify(no_maxed_tools, "Three maxed tools exclude new tools and their own upgrades")
	price_ok = true
	for id: String in Loadout.MOD_IDS:
		for current_level: int in range(3):
			var item: Dictionary = _find_offer(loadout, id)
			price_ok = price_ok and not item.is_empty() and item.get("cost", 0) == 18 + current_level * 12
			if not item.is_empty():
				price_ok = price_ok and loadout.purchase(item["token"], 999)["ok"]
	verify(price_ok and loadout.mods.values().all(func(level: Variant) -> bool: return int(level) == 3), "All six modifications upgrade to level three")
	var modifiers: Dictionary = loadout.get_modifiers()
	verify(is_equal_approx(modifiers["health_bonus"], 60.0), "Three hull levels add sixty health")
	verify(is_equal_approx(modifiers["speed_scale"], 1.24), "Three tread levels add twenty-four percent movement")
	verify(is_equal_approx(modifiers["vacuum_scale"], 1.45), "Three magnet levels add forty-five percent vacuum range")
	verify(is_equal_approx(modifiers["energy_scale"], 1.60), "Three capacitor levels add sixty percent capacity")
	verify(is_equal_approx(modifiers["damage_scale"], 1.36), "Three torque levels add thirty-six percent damage")
	verify(is_equal_approx(modifiers["cooldown_scale"], 0.76), "Three coolant levels reduce cooldown by twenty-four percent")
	verify(loadout.generate_offers(5).is_empty() and not loadout.can_reroll(), "An exhausted build has no invalid offers and cannot pay to refresh")
	pristine = _snapshot(loadout)
	verify(not loadout.reroll(999, 5).ok and _snapshot(loadout) == pristine, "Sold-out refresh rejects without changing RNG or allowance")
	loadout.mods["coolant"] = 99
	verify(is_equal_approx(loadout.get_modifiers()["cooldown_scale"], 0.76), "Derived modifiers clamp out-of-range externally assigned levels")

	loadout.reset(20)
	var slot_offer: Dictionary = _find_offer(loadout, "foam")
	loadout.weapons["arc"] = 1
	loadout.weapons["saw"] = 1
	pristine = _snapshot(loadout)
	denied = loadout.purchase(slot_offer["token"], 999)
	verify(not denied["ok"] and denied["reason"] == "slots_full" and _snapshot(loadout) == pristine, "A newly full third slot rejects a pending fourth tool without mutation")
	var only_upgrades: bool = true
	for wave: int in range(5):
		for item: Dictionary in loadout.generate_offers(wave):
			only_upgrades = only_upgrades and not (item["kind"] == "weapon" and item["level"] == 1)
	verify(only_upgrades, "Full slots exclude unowned weapons during generation")
	var brush_offer: Dictionary = _find_offer(loadout, "brush")
	verify(loadout.purchase(brush_offer["token"], 999)["ok"], "Full slots still permit equipped upgrades")
	brush_offer = _find_offer(loadout, "brush")
	loadout.weapons["brush"] = 3
	pristine = _snapshot(loadout)
	denied = loadout.purchase(brush_offer["token"], 999)
	verify(not denied["ok"] and denied["reason"] == "max_level" and _snapshot(loadout) == pristine, "Stale offers cannot upgrade an already maxed weapon")

	var first: RefCounted = Loadout.new()
	var second: RefCounted = Loadout.new()
	first.reset(982)
	second.reset(982)
	var deterministic: bool = true
	for wave: int in range(1, 51):
		var first_offers: Array[Dictionary] = first.generate_offers(wave)
		for unused: int in range(9):
			randi()
		var second_offers: Array[Dictionary] = second.generate_offers(wave)
		deterministic = deterministic and first_offers == second_offers
		if not first_offers.is_empty():
			first.purchase(first_offers[0]["token"], 999)
			second.purchase(second_offers[0]["token"], 999)
	verify(deterministic, "Equal seed and transaction histories remain deterministic despite global RNG noise")
	pristine = _snapshot(second)
	first.reset(41)
	first.mods["hull"] = 2
	first.generate_offers(1)
	verify(_snapshot(second) == pristine, "Equipment, offers, and RNG belong to each independent run")
	var opportunities: bool = true
	var discovered: Dictionary = {}
	for seed_value: int in range(100):
		first.reset(seed_value)
		for wave: int in range(1, 6):
			for item: Dictionary in first.generate_offers(wave):
				if item["kind"] == "weapon" and item["level"] == 1:
					first.purchase(item["token"], 999)
					discovered[item["id"]] = true
		var occupied: int = 0
		for level: Variant in first.weapons.values():
			occupied += 1 if int(level) > 0 else 0
		opportunities = opportunities and occupied == 3
	verify(opportunities and discovered.size() == 7, "Tested seeds reveal all seven optional tool types while each standard run chooses at most three tools")
	var later_builds: bool = true
	var later_with_discovery: bool = true
	for seed_value: int in range(100):
		first.reset(seed_value)
		var later: Array[Dictionary] = first.generate_offers(5)
		later_builds = later_builds and later.any(func(item: Dictionary) -> bool: return item.id == "brush")
		later_with_discovery = later_with_discovery and later.any(func(item: Dictionary) -> bool: return item.kind == "weapon" and item.level == 1)
	verify(later_builds and later_with_discovery, "Late shops preserve an equipped upgrade and guarantee a discovery while weapon slots remain open")

	loadout.reset(910)
	var scaling_correct: bool = true
	for wave: int in range(1, 6):
		for offer: Dictionary in loadout.generate_offers(wave):
			var base_price: int = 22 if offer.kind == "weapon" and offer.level == 1 else (28 if offer.kind == "weapon" else 18)
			scaling_correct = scaling_correct and offer.cost == base_price + (wave - 1) * 12
	verify(scaling_correct, "Displayed costs add twelve per completed shop to the correct base price")
	var fifth_shop_item: Dictionary = loadout.get_offers()[0]
	pristine = _snapshot(loadout)
	denied = loadout.purchase(fifth_shop_item.token, int(fifth_shop_item.cost) - 1)
	verify(not denied.ok and denied.reason == "insufficient_currency" and _snapshot(loadout) == pristine, "Later shop prices reject insufficient balances without mutation")
	purchased = loadout.purchase(fifth_shop_item.token, int(fifth_shop_item.cost))
	verify(purchased.ok and purchased.cost == fifth_shop_item.cost, "Later purchases debit exactly the displayed price")
	loadout.reset(910)
	loadout.price_scale = 2.8
	offers = loadout.generate_offers(1)
	verify(offers[0].cost == 62 and offers[1].cost == 79 and offers[2].cost == 51 and loadout.get_reroll_cost(1) == 34, "Standard income scaling applies to discoveries, upgrades, mods, and refresh with integer prices")
	verify(second.import_state(JSON.parse_string(JSON.stringify(loadout.export_state()))) and second.price_scale == 2.8 and second.get_reroll_cost(1) == 34, "Checkpoint restores the standard price scale without falling back to cheap Demo prices")
	verify(loadout.reroll(34, 1) == second.reroll(34, 1), "Restored standard refresh charges the same price and generates the same stock")
	loadout.reset(910)
	verify(loadout.price_scale == 1.0 and loadout.get_reroll_cost(1) == 12, "A fresh run resets pricing before its mode configures the scale")

	loadout.reset(530)
	pristine = _snapshot(loadout)
	verify(not loadout.can_reroll() and not loadout.reroll(999, 1).ok and _snapshot(loadout) == pristine, "Refresh is unavailable before any shop opens")
	loadout.generate_offers(1)
	pristine = _snapshot(loadout)
	verify(loadout.can_reroll() and loadout.get_reroll_cost(1) == 12 and loadout.get_reroll_cost(5) == 36, "Each fresh shop starts with one affordable bounded refresh")
	denied = loadout.reroll(11, 1)
	verify(not denied.ok and denied.cost == 0 and denied.reason == "insufficient_currency" and _snapshot(loadout) == pristine, "Failed refresh preserves offers, RNG, tokens, and its allowance")
	verify(not loadout.reroll(999, 2).ok and _snapshot(loadout) == pristine, "A refresh request for the wrong shop is rejected")
	old_token = loadout.get_offers()[0].token
	var old_ids: Array[String] = []
	for offer: Dictionary in loadout.get_offers():
		old_ids.append(offer.id)
	var refreshed: Dictionary = loadout.reroll(12, 1)
	verify(refreshed.ok and refreshed.cost == 12 and not loadout.can_reroll(), "Exact refresh fee succeeds once and consumes allowance")
	var changed: int = 0
	for offer: Dictionary in loadout.get_offers():
		changed += 1 if offer.id not in old_ids else 0
	verify(changed >= 2, "Refresh prefers different discoveries and modifications when alternatives exist")
	verify(not loadout.purchase(old_token, 999).ok, "Every pre-refresh purchase token is invalidated")
	pristine = _snapshot(loadout)
	denied = loadout.reroll(999, 1)
	verify(not denied.ok and denied.cost == 0 and denied.reason == "reroll_used" and _snapshot(loadout) == pristine, "Repeated refresh cannot charge twice or advance RNG")
	loadout.generate_offers(2)
	verify(loadout.can_reroll() and loadout.get_reroll_cost(2) == 18, "Advancing to the next shop restores one refresh")

	first.reset(9223372036854775806)
	first.generate_offers(2)
	var bought: Dictionary = first.get_offers()[0]
	first.purchase(bought.token, 999)
	var saved: Dictionary = first.export_state()
	var json_saved: Dictionary = JSON.parse_string(JSON.stringify(saved))
	verify(second.import_state(json_saved) and second.export_state() == saved, "JSON checkpoint preserves sold stock and exact 64-bit RNG")
	verify(second.purchase(bought.token, 999).reason == "sold", "A sold item remains sold after checkpoint recovery")
	verify(first.reroll(999, 2) == second.reroll(999, 2), "Restored current RNG generates the same paid refresh")
	saved = first.export_state()
	verify(second.import_state(saved) and not second.can_reroll() and second.reroll(999, 2).cost == 0, "Reloading after a refresh does not restore the allowance")
	verify(first.generate_offers(3) == second.generate_offers(3), "Checkpoint also preserves the next shop serial and random sequence")
	saved = first.export_state()
	saved.weapons.brush = 3
	verify(first.weapons.brush == 1, "Exported checkpoint dictionaries cannot mutate live equipment")
	var fresh: RefCounted = Loadout.new()
	verify(second.import_state(fresh.export_state()) and not second.can_reroll(), "A pre-shop checkpoint round-trips without granting a refresh")

	first.reset(531)
	first.generate_offers(3)
	saved = first.export_state()
	var corruptions: Array[Dictionary] = []
	var bad: Dictionary = saved.duplicate(true)
	bad.version = 99
	corruptions.append(bad)
	bad = saved.duplicate(true)
	bad.weapons.brush = 0
	corruptions.append(bad)
	bad = saved.duplicate(true)
	bad.weapons.foam = 4
	corruptions.append(bad)
	bad = saved.duplicate(true)
	bad.weapons.arc = 1.25
	corruptions.append(bad)
	bad = saved.duplicate(true)
	bad.weapons.foam = 1
	bad.weapons.arc = 1
	bad.weapons.saw = 1
	corruptions.append(bad)
	bad = saved.duplicate(true)
	bad.mods.fake = 1
	corruptions.append(bad)
	bad = saved.duplicate(true)
	bad.mods.hull = "1"
	corruptions.append(bad)
	bad = saved.duplicate(true)
	bad.reroll_used = 1
	corruptions.append(bad)
	bad = saved.duplicate(true)
	bad.reroll_used = true
	corruptions.append(bad)
	bad = saved.duplicate(true)
	bad.shop_serial = -1
	corruptions.append(bad)
	bad = saved.duplicate(true)
	bad.shop_wave = 6
	corruptions.append(bad)
	bad = saved.duplicate(true)
	bad.rng_state = "9223372036854775808"
	corruptions.append(bad)
	bad = saved.duplicate(true)
	bad.rng_state = 123
	corruptions.append(bad)
	bad = saved.duplicate(true)
	bad.rng_seed = "001"
	corruptions.append(bad)
	bad = saved.duplicate(true)
	bad.offers[0].cost = 0
	corruptions.append(bad)
	bad = saved.duplicate(true)
	bad.offers[0].token = "previous:shop"
	corruptions.append(bad)
	bad = saved.duplicate(true)
	bad.offers[0].sold = 1
	corruptions.append(bad)
	bad = saved.duplicate(true)
	bad.offers[0].level = 3
	corruptions.append(bad)
	bad = saved.duplicate(true)
	bad.offers[1] = bad.offers[0].duplicate(true)
	corruptions.append(bad)
	bad = saved.duplicate(true)
	bad.offers[0].kind = "mod"
	corruptions.append(bad)
	bad = saved.duplicate(true)
	bad.offers[0].name_key = "HIDDEN_ITEM"
	corruptions.append(bad)
	bad = saved.duplicate(true)
	bad.price_scale = 0.0
	corruptions.append(bad)
	bad = saved.duplicate(true)
	bad.price_scale = INF
	corruptions.append(bad)
	bad = saved.duplicate(true)
	bad.price_scale = "2.8"
	corruptions.append(bad)
	bad = saved.duplicate(true)
	bad.price_scale = 2.8
	corruptions.append(bad)
	pristine = second.export_state()
	for index: int in range(corruptions.size()):
		verify(not second.import_state(corruptions[index]) and second.export_state() == pristine, "Corrupt checkpoint %d rejects atomically" % index)
	var pending: Dictionary = saved.duplicate(true)
	verify(second.import_state(pending) and second.export_state() == saved, "Valid checkpoint still loads after rejected imports")
	pending.mods.torque = 3
	pending.offers[0].sold = true
	verify(second.export_state() == saved, "Imported checkpoint is independent from caller-owned dictionaries")

	var damage_ok: bool = true
	var capacity_ok: bool = true
	for level: int in range(4):
		loadout.reset(70)
		loadout.mods.capacitor = level
		capacity_ok = capacity_ok and loadout.get_modifiers().energy_scale >= 1.0
		damage_ok = damage_ok and loadout.get_modifiers().damage_scale == 1.0
	verify(capacity_ok and damage_ok, "Capacity upgrades never dilute the world damage multiplier at identical charge")
	verify(Loadout.tool_stats("brush", 3).damage > Loadout.tool_stats("brush", 2).damage and Loadout.tool_stats("saw", 3).pierce == 5 and Loadout.tool_stats("arc", 3).hops == 4, "Shared tool preview values describe meaningful tier gains")
	# v0.4: exchanging one nonstarter tool preserves meaningful shop state.
	first.reset(502)
	verify(first.get_sell_options().is_empty() and not first.sell_weapon("brush", 1).ok, "No starter sale or pre-shop refund is possible")
	first.weapons.foam = 2
	first.weapons.arc = 1
	first.price_scale = 2.8
	first.generate_offers(3)
	var sell_rows: Array[Dictionary] = first.get_sell_options()
	verify(sell_rows.size() == 2 and sell_rows[0].available and first.get_sell_refund("foam") == 49, "Refund uses thirty-five percent of first-shop accumulated investment without later premiums")
	pristine = first.export_state()
	verify(not first.sell_weapon("brush", 3).ok and not first.sell_weapon("missing", 3).ok and not first.sell_weapon("foam", 2).ok and first.export_state() == pristine, "Invalid tool or wrong-shop sales cannot change inventory, RNG or money")
	old_token = first.get_offers()[0].token
	var sold_tool: Dictionary = first.sell_weapon("foam", 3)
	verify(sold_tool.ok and sold_tool.refund == 49 and first.weapons.foam == 0 and first.weapons.arc == 1 and first.weapons.brush == 1, "A valid sale removes only the selected optional tool and returns its exact refund")
	verify(first.get_offers().any(func(item: Dictionary) -> bool: return item.kind == "weapon" and item.id != "foam" and item.level == 1 and int(first.weapons.get(item.id, 0)) == 0), "The vacated equipment slot receives an unowned alternative tool offer")
	verify(not first.purchase(old_token, 999).ok, "Sale invalidates old UI transaction tokens")
	pristine = first.export_state()
	verify(not first.sell_weapon("arc", 3).ok and first.export_state() == pristine, "Only one sale per shop is allowed")
	verify(second.import_state(JSON.parse_string(JSON.stringify(pristine))) and second.export_state() == pristine and not second.get_sell_options()[0].available, "A JSON checkpoint preserves consumed sale allowance and revised offers")
	verify(first.can_reroll() and first.reroll(999, 3) == second.reroll(999, 3), "A sale does not restore or consume the independent paid reroll allowance")
	verify(second.import_state(first.export_state()) and second.export_state() == first.export_state(), "Both sale plus refresh revisions survive checkpoint validation")
	first.generate_offers(4)
	verify(first.get_sell_options()[0].available, "A new shop permits one new exchange")
	# Recreate each real four-weapon schema, including a consumed v2 sale. Keep
	# retained old-tool offers and RNG; remove fields/cards unavailable then.
	first.reset(844)
	first.weapons.foam = 1
	first.weapons.arc = 1
	first.generate_offers(2)
	for legacy_version: int in [1, 2]:
		if legacy_version == 2:
			first.sell_weapon("foam", 2)
		var legacy: Dictionary = first.export_state()
		legacy.version = legacy_version
		legacy.erase("slots")
		legacy.erase("repair_bought")
		if legacy_version == 1:
			legacy.erase("sell_used")
		for id: String in ["laser", "missile", "drone", "mines"]:
			legacy.weapons.erase(id)
		legacy.offers = legacy.offers.filter(func(item: Dictionary) -> bool: return item.id in Loadout.LEGACY_WEAPON_IDS or item.id in Loadout.MOD_IDS)
		var migrated: bool = second.import_state(JSON.parse_string(JSON.stringify(legacy)))
		var state: Dictionary = second.export_state()
		verify(migrated and state.version == Loadout.STATE_VERSION and state.slots == 3 and state.weapons.size() == 8 and state.weapons.laser == 0 and state.offers == legacy.offers and state.rng_state == legacy.rng_state and state.sell_used == (legacy_version == 2), "Real v%d loadout schema migrates while retaining offers, RNG and prior sale use" % legacy_version)
		if legacy_version == 2:
			var migrated_sales: Array[Dictionary] = second.get_sell_options()
			verify(not migrated_sales.is_empty() and not bool(migrated_sales[0].available) and not second.sell_weapon("arc", 2).ok, "A migrated consumed sale cannot be used again")
	first.reset(845)
	first.generate_offers(2)
	bad = first.export_state()
	bad.sell_used = 1
	pristine = second.export_state()
	verify(not second.import_state(bad) and second.export_state() == pristine, "Nonboolean sale allowance rejects atomically")
	bad = first.export_state()
	bad.sell_used = true
	verify(not second.import_state(bad), "Sale allowance and token revision must agree")
	# The evolution rules describe unlockable behavior contracts, not stat bonuses.
	first.reset(946)
	verify(first.get_evolutions().size() == 6 and first.get_evolutions().all(func(item: Dictionary) -> bool: return not item.active), "A new run exposes six progress-tracked evolutions without unlocking them")
	first.weapons.brush = 2
	first.weapons.saw = 1
	verify(not first.has_evolution("steel_storm"), "Steel storm needs both tier-two tools")
	first.weapons.saw = 2
	verify(first.has_evolution("steel_storm") and first.get_evolutions()[0].active, "Tier-two brush and saw unlock orbital steel storm behavior")
	first.generate_offers(3)
	first.sell_weapon("saw", 3)
	verify(not first.has_evolution("steel_storm"), "Selling a required tool immediately removes its evolution")
	first.reset(947)
	first.weapons.foam = 2
	first.weapons.arc = 2
	verify(first.has_evolution("conduction_grid") and not first.has_evolution("compression_blast"), "Tier-two foam and arc unlock the grid independently")
	first.mods.capacitor = 2
	first.mods.magnet = 1
	verify(not first.has_evolution("compression_blast"), "Compression requires both capacitor and magnetic control")
	first.mods.magnet = 2
	verify(first.has_evolution("compression_blast"), "Tier-two capacitor and magnet unlock delayed compression behavior")
	var evolution_copy: Array[Dictionary] = first.get_evolutions()
	evolution_copy[0].progress[0].required = 99
	verify(first.get_evolutions()[0].progress[0].required == 2 and not first.has_evolution("unknown"), "Evolution progress snapshots cannot mutate global thresholds")

	if "--logic-only" in OS.get_cmdline_user_args():
		print("LOADOUT_LOGIC_TEST ", JSON.stringify({"checks": checks, "failures": failures}))
		quit(0 if failures.is_empty() else 1)
		return

	var panel: Control = ShopPanel.new()
	root.add_child(panel)
	loadout.reset(923)
	offers = loadout.generate_offers(1)
	var panel_stats: Dictionary = {"currency": 100, "wave": 1, "max_health": 100, "max_energy": 100, "can_reroll": true, "reroll_cost": 12, "loadout": {"weapons": loadout.weapons, "mods": loadout.mods}}
	panel.present(offers, panel_stats, {"wave": 1})
	verify(panel.mod_labels.size() == 6 and panel.build_label.text.contains("1/3"), "Shop displays all six installed modification details and the three-slot build")
	verify((panel.cards[1].benefit.text + " " + panel.cards[1].comparison.text).contains("13 → 18.85"), "Shop previews damage before and after using the shared tool configuration")
	var requests: Array[int] = []
	panel.reroll_requested.connect(func() -> void: requests.append(1))
	panel.reroll_button.pressed.emit()
	verify(requests.size() == 1, "Refresh button emits one world-owned transaction request")
	panel_stats.can_reroll = false
	panel.refresh_result({"ok": true}, loadout.get_offers(), panel_stats)
	verify(panel.reroll_button.disabled, "Used refresh state disables the shop button")
	panel.queue_free()
	await process_frame
	print("LOADOUT_TEST ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)


func _capture_shop(path: String) -> void:
	# Optional real-render inspection of the same UI, isolated from an active run.
	TranslationServer.set_locale("zh_CN" if "--chinese" in OS.get_cmdline_user_args() else "en")
	var fixture: RefCounted = Loadout.new()
	var combo_fixture: bool = "--combo" in OS.get_cmdline_user_args()
	for seed_value: int in range(100):
		fixture.reset(seed_value)
		fixture.price_scale = 2.8
		fixture.mods = {"hull": 1, "treads": 1, "magnet": 2, "capacitor": 1, "torque": 1, "coolant": 1}
		if combo_fixture:
			fixture.weapons = {"brush": 1, "foam": 1, "arc": 1, "saw": 0}
		fixture.generate_offers(1)
		var choices: Array[Dictionary] = fixture.get_offers()
		if (not combo_fixture and choices[0].id == "saw") or (combo_fixture and choices.any(func(item: Dictionary) -> bool: return item.id == "foam") and choices.any(func(item: Dictionary) -> bool: return item.id == "arc")):
			break
	var panel: Control = ShopPanel.new()
	var shop_theme := Theme.new()
	shop_theme.default_font = load("res://assets/fonts/NotoSansCJKsc-Regular.otf")
	panel.theme = shop_theme
	root.add_child(panel)
	panel.present(fixture.get_offers(), {"currency": 180, "wave": 1, "max_health": 120.0, "max_energy": 120.0, "can_reroll": true, "reroll_cost": fixture.get_reroll_cost(1), "loadout": {"weapons": fixture.weapons, "mods": fixture.mods}}, {"wave": 1, "earned_scrap": 24, "bonus": 18, "repaired": 10})
	await process_frame
	await RenderingServer.frame_post_draw
	var result: int = root.get_texture().get_image().save_png(path)
	print("SHOP_CAPTURE ", JSON.stringify({"locale": TranslationServer.get_locale(), "path": path, "result": result}))
	panel.queue_free()
	await process_frame
	var sound_bank: Node = root.get_node_or_null("SoundBank")
	if sound_bank != null and sound_bank.has_method("shutdown"):
		await sound_bank.shutdown()
	quit(0 if result == OK else 1)
