class_name ScrapLoadout
extends RefCounted
## Per-run equipment and shop state. The world owns and synchronously debits scrap.

const MAX_LEVEL: int = 3
const MAX_WEAPON_SLOTS: int = 3
const OFFER_COUNT: int = 3
const NEW_WEAPON_COST: int = 22
const WEAPON_UPGRADE_BASE: int = 18
const WEAPON_UPGRADE_STEP: int = 10
const MOD_BASE_COST: int = 18
const MOD_UPGRADE_STEP: int = 12
const WAVE_PRICE_STEP: int = 12
const LEGACY_WEAPON_IDS: Array[String] = ["brush", "foam", "arc", "saw"]
const WEAPON_IDS: Array[String] = ["brush", "foam", "arc", "saw", "laser", "missile", "drone", "mines"]
const MOD_IDS: Array[String] = ["hull", "treads", "magnet", "capacitor", "torque", "coolant"]
const STATE_VERSION: int = 3
const EVOLUTIONS: Dictionary = {
	"steel_storm": {"brush": 2, "saw": 2},
	"conduction_grid": {"foam": 2, "arc": 2},
	"compression_blast": {"capacitor": 2, "magnet": 2},
	"prism_relay": {"laser": 2, "arc": 2},
	"hunter_swarm": {"drone": 2, "foam": 2},
	"ordnance_chain": {"missile": 2, "mines": 2},
}

var weapons: Dictionary = {}
var mods: Dictionary = {}
var price_scale: float = 1.0
var slots: int = MAX_WEAPON_SLOTS
var _repair_bought: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _offers: Array[Dictionary] = []
var _run_serial: int = 0
var _shop_serial: int = 0
var _shop_wave: int = 0
var _offer_revision: int = 0
var _reroll_used: bool = false
var _sell_used: bool = false


func _init() -> void:
	reset()


func reset(seed_value: int = 0) -> void:
	weapons.clear()
	for id: String in WEAPON_IDS:
		weapons[id] = 1 if id == "brush" else 0
	mods = {"hull": 0, "treads": 0, "magnet": 0, "capacitor": 0, "torque": 0, "coolant": 0}
	price_scale = 1.0
	_rng.seed = seed_value
	_offers.clear()
	_run_serial += 1
	_shop_serial = 0
	_shop_wave = 0
	_offer_revision = 0
	_reroll_used = false
	_sell_used = false
	_repair_bought = false
	slots = MAX_WEAPON_SLOTS


func configure_slots(count: int) -> bool:
	# Slot capacity is configured before a run/shop starts, never during a sale.
	if count not in [3, 4] or _weapon_count() > count or _shop_serial > 0:
		return false
	slots = count
	return true


func generate_offers(wave: int) -> Array[Dictionary]:
	_shop_serial += 1
	_shop_wave = clampi(wave, 1, 1000000 if slots == 4 else 5)
	_offer_revision = 0
	_reroll_used = false
	_sell_used = false
	_repair_bought = false
	_fill_offers()
	return get_offers()


func _candidate_groups() -> Dictionary:
	var upgrades: Array[String] = []
	var discoveries: Array[String] = []
	var modifications: Array[String] = []
	for id: String in WEAPON_IDS:
		var level: int = int(weapons.get(id, 0))
		if level > 0 and level < MAX_LEVEL:
			upgrades.append(id)
		elif level == 0 and _weapon_count() < slots:
			discoveries.append(id)
	for id: String in MOD_IDS:
		if int(mods.get(id, 0)) < MAX_LEVEL:
			modifications.append(id)
	if slots == 4 and _shop_wave >= 3 and not _repair_bought:
		modifications.append("repair")
	return {"upgrades": upgrades, "discoveries": discoveries, "mods": modifications}


func _fill_offers(avoid: Array[String] = []) -> void:
	_offers.clear()
	var groups: Dictionary = _candidate_groups()
	var upgrades: Array[String] = groups["upgrades"]
	var discoveries: Array[String] = groups["discoveries"]
	var modifications: Array[String] = groups["mods"]
	# Eight-tool builds need an actual discovery choice while a slot remains.
	# Filled loadouts instead spend every card on upgrades/mods/field repairs.
	if not discoveries.is_empty():
		_offers.append(_make_offer(_take_candidate(discoveries, avoid)))
	if not upgrades.is_empty():
		_offers.append(_make_offer(_take_candidate(upgrades, avoid)))
	if not modifications.is_empty():
		_offers.append(_make_offer(_take_candidate(modifications, avoid)))
	var remaining: Array[String] = []
	remaining.append_array(upgrades)
	remaining.append_array(discoveries)
	remaining.append_array(modifications)
	while _offers.size() < OFFER_COUNT and not remaining.is_empty():
		_offers.append(_make_offer(_take_candidate(remaining, avoid)))


func _take_candidate(candidates: Array[String], avoid: Array[String]) -> String:
	var preferred: Array[String] = []
	for id: String in candidates:
		if id not in avoid:
			preferred.append(id)
	var pool: Array[String] = candidates if preferred.is_empty() else preferred
	var selected: String = pool[_rng.randi_range(0, pool.size() - 1)]
	candidates.erase(selected)
	return selected


func get_offers() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for offer: Dictionary in _offers:
		result.append(offer.duplicate(true))
	return result


func get_reroll_cost(wave: int) -> int:
	return ceili(float(12 + (clampi(wave, 1, 5) - 1) * 6) * price_scale)


func can_reroll() -> bool:
	if _shop_serial == 0 or _reroll_used:
		return false
	var groups: Dictionary = _candidate_groups()
	return not groups["upgrades"].is_empty() or not groups["discoveries"].is_empty() or not groups["mods"].is_empty()


func reroll(available_currency: int, wave: int) -> Dictionary:
	if _shop_serial == 0 or wave != _shop_wave:
		return _reroll_rejected("shop_not_open")
	if _reroll_used:
		return _reroll_rejected("reroll_used")
	if not can_reroll():
		return _reroll_rejected("sold_out")
	var cost: int = get_reroll_cost(wave)
	if available_currency < cost:
		return _reroll_rejected("insufficient_currency")
	var previous: Array[String] = []
	for offer: Dictionary in _offers:
		previous.append(str(offer["id"]))
	# Validation precedes RNG and allowance changes; world debits without yielding.
	_reroll_used = true
	_offer_revision += 1
	_fill_offers(previous)
	return {"ok": true, "cost": cost, "offers": get_offers(), "reason": "ok"}


func _reroll_rejected(reason: String) -> Dictionary:
	return {"ok": false, "cost": 0, "offers": get_offers(), "reason": reason}


func purchase(token: String, available_currency: int) -> Dictionary:
	var index: int = -1
	for i: int in range(_offers.size()):
		if _offers[i]["token"] == token:
			index = i
			break
	if index < 0:
		return _rejected("invalid_offer")
	var offer: Dictionary = _offers[index]
	var id: String = offer["id"]
	if bool(offer["sold"]):
		return _rejected("sold", id)
	if id == "repair":
		if slots != 4 or _shop_wave < 3 or _repair_bought:
			return _rejected("invalid_offer", id)
		if available_currency < int(offer.cost):
			return _rejected("insufficient_currency", id)
		_offers[index].sold = true
		_repair_bought = true
		return {"ok": true, "reason": "ok", "cost": int(offer.cost), "id": id, "repair_amount": 35.0}
	var is_weapon: bool = offer["kind"] == "weapon"
	var inventory: Dictionary = weapons if is_weapon else mods
	var current_level: int = int(inventory.get(id, 0))
	if current_level >= MAX_LEVEL:
		return _rejected("max_level", id)
	if is_weapon and current_level == 0 and _weapon_count() >= slots:
		return _rejected("slots_full", id)
	if current_level + 1 != int(offer["level"]):
		return _rejected("invalid_offer", id)
	var cost: int = int(offer["cost"])
	if available_currency < cost:
		return _rejected("insufficient_currency", id)
	inventory[id] = int(offer["level"])
	_offers[index]["sold"] = true
	return {"ok": true, "reason": "ok", "cost": cost, "id": id}


func get_sell_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for id: String in WEAPON_IDS:
		if id != "brush" and int(weapons.get(id, 0)) > 0:
			options.append({"id": id, "level": int(weapons[id]), "name_key": "ITEM_" + id.to_upper(),
				"refund": get_sell_refund(id), "available": _shop_serial > 0 and not _sell_used})
	return options


func get_sell_refund(id: String) -> int:
	if id == "brush" or id not in WEAPON_IDS:
		return 0
	var basis: int = 0
	for level: int in range(1, int(weapons.get(id, 0)) + 1):
		# First-shop basis excludes later premiums, preventing price arbitrage.
		basis += item_cost(id, level, 1, price_scale)
	return floori(float(basis) * 0.35)


func sell_weapon(id: String, wave: int) -> Dictionary:
	if _shop_serial <= 0 or wave != _shop_wave:
		return {"ok": false, "reason": "shop_not_open", "refund": 0}
	if _sell_used:
		return {"ok": false, "reason": "sell_used", "refund": 0}
	if id == "brush" or id not in WEAPON_IDS or int(weapons.get(id, 0)) <= 0:
		return {"ok": false, "reason": "sell_unavailable", "refund": 0}
	var refund: int = get_sell_refund(id)
	var old_level: int = int(weapons[id])
	weapons[id] = 0
	_sell_used = true
	_offer_revision += 1
	# Keep other purchased cards and offer identities; only one slot changes to
	# offer a replacement discovery. All request tokens receive the new revision.
	var slot: int = -1
	var used: Array[String] = []
	for i: int in range(_offers.size()):
		if _offers[i].id == id:
			slot = i
		used.append(str(_offers[i].id))
	if slot < 0:
		for i: int in range(_offers.size()):
			if not bool(_offers[i].sold):
				slot = i
				break
	if slot < 0 and not _offers.is_empty():
		slot = 0
	if slot >= 0:
		used.erase(str(_offers[slot].id))
	var candidates: Array[String] = []
	for candidate: String in WEAPON_IDS:
		if int(weapons[candidate]) == 0 and candidate != id and candidate not in used:
			candidates.append(candidate)
	if candidates.is_empty():
		candidates.append(id)
	var replacement: String = candidates[_rng.randi_range(0, candidates.size() - 1)]
	if slot < 0:
		_offers.append(_make_offer(replacement))
	else:
		_offers[slot] = _make_offer(replacement)
	for offer: Dictionary in _offers:
		offer.token = "%d:%d:%d:%d:%s" % [_run_serial, _shop_serial, _shop_wave, _offer_revision, offer.id]
	return {"ok": true, "reason": "sold_weapon", "id": id, "level": old_level, "refund": refund,
		"replacement": replacement, "offers": get_offers()}


func has_evolution(id: String) -> bool:
	if not EVOLUTIONS.has(id):
		return false
	for item: String in EVOLUTIONS[id]:
		var current: int = int(weapons.get(item, mods.get(item, 0)))
		if current < int(EVOLUTIONS[id][item]):
			return false
	return true


func get_evolutions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: String in EVOLUTIONS:
		var progress: Array[Dictionary] = []
		for item: String in EVOLUTIONS[id]:
			var current: int = int(weapons.get(item, mods.get(item, 0)))
			var required: int = int(EVOLUTIONS[id][item])
			progress.append({"id": item, "name_key": "ITEM_" + item.to_upper(), "current": current, "required": required, "met": current >= required})
		result.append({"id": id, "name_key": "EVOLUTION_" + id.to_upper(), "desc_key": "EVOLUTION_" + id.to_upper() + "_DESC",
			"requirement_key": "EVOLUTION_" + id.to_upper() + "_REQUIRES", "active": has_evolution(id), "progress": progress})
	return result


func get_modifiers() -> Dictionary:
	return {
		"health_bonus": 20.0 * _mod_level("hull"),
		"speed_scale": 1.0 + 0.08 * _mod_level("treads"),
		"vacuum_scale": 1.0 + 0.15 * _mod_level("magnet"),
		"energy_scale": 1.0 + 0.20 * _mod_level("capacitor"),
		"damage_scale": 1.0 + 0.12 * _mod_level("torque"),
		"cooldown_scale": maxf(0.5, 1.0 - 0.08 * _mod_level("coolant")),
	}


static func tool_stats(id: String, level: int) -> Dictionary:
	var tier: int = clampi(level, 0, MAX_LEVEL)
	if tier == 0:
		return {"damage": 0.0, "radius": 0.0, "range": 0.0, "interval": 0.0, "hops": 0, "pierce": 0}
	match id:
		"brush":
			return {"damage": 13.0 * (1.0 + float(tier - 1) * 0.45), "radius": 68.0 + float(tier - 1) * 11.0, "interval": 0.55}
		"foam":
			return {"damage": 3.0 + float(tier) * 2.0, "radius": 49.0 + float(tier - 1) * 12.0, "range": 275.0, "interval": 2.4, "duration": 3.0, "tick": 0.45}
		"arc":
			return {"damage": 18.0 + float(tier - 1) * 8.0, "hops": tier + 1, "range": 265.0, "chain_range": 180.0, "interval": 1.5, "combo": 1.55}
		"saw":
			return {"damage": 22.0 + float(tier - 1) * 10.0, "range": 300.0, "radius": 12.0 + float(tier - 1) * 3.0, "interval": 2.2 - float(tier - 1) * 0.2, "speed": 440.0, "pierce": tier + 2}
		"laser":
			return {"damage": 34.0 + 17.0 * (tier - 1), "range": 500.0, "radius": 8.0 + tier, "interval": 2.2 - tier * 0.15, "charge": 0.55}
		"missile":
			return {"damage": 30.0 + 14.0 * (tier - 1), "range": 540.0, "radius": 65.0 + 13.0 * (tier - 1), "interval": 2.6 - tier * 0.2, "speed": 300.0, "count": 2 if tier == 3 else 1}
		"drone":
			return {"damage": 7.0 + 3.0 * tier, "range": 360.0, "interval": 1.15 - tier * 0.10, "count": tier}
		"mines":
			return {"damage": 38.0 + 20.0 * (tier - 1), "radius": 90.0 + 12.0 * (tier - 1), "interval": 2.7 - tier * 0.25, "arm": 0.7}
	return {}


func _mod_level(id: String) -> int:
	return clampi(int(mods.get(id, 0)), 0, MAX_LEVEL)


func _weapon_count() -> int:
	var count: int = 0
	for level: Variant in weapons.values():
		if int(level) > 0:
			count += 1
	return count


static func item_cost(id: String, target_level: int, wave: int, scale_value: float = 1.0) -> int:
	if id == "repair":
		return ceili(float(24 + (clampi(wave, 1, 5) - 1) * 8) * scale_value)
	var previous_level: int = target_level - 1
	var cost: int = MOD_BASE_COST + previous_level * MOD_UPGRADE_STEP
	if id in WEAPON_IDS:
		cost = NEW_WEAPON_COST if previous_level == 0 else WEAPON_UPGRADE_BASE + previous_level * WEAPON_UPGRADE_STEP
	return ceili(float(cost + (clampi(wave, 1, 5) - 1) * WAVE_PRICE_STEP) * scale_value)


func _make_offer(id: String) -> Dictionary:
	var is_weapon: bool = id in WEAPON_IDS
	var target_level: int = int(weapons.get(id, 0) if is_weapon else mods.get(id, 0)) + 1
	var name_key: String = "ITEM_" + id.to_upper()
	return {
		"token": "%d:%d:%d:%d:%s" % [_run_serial, _shop_serial, _shop_wave, _offer_revision, id],
		"id": id, "kind": "weapon" if is_weapon else ("consumable" if id == "repair" else "mod"),
		"level": target_level, "cost": item_cost(id, target_level, _shop_wave, price_scale),
		"name_key": name_key, "desc_key": name_key + "_DESC", "sold": false,
	}


func export_state() -> Dictionary:
	return {
		"version": STATE_VERSION, "weapons": weapons.duplicate(true), "mods": mods.duplicate(true),
		"slots": slots, "repair_bought": _repair_bought,
		"offers": get_offers(), "rng_seed": str(_rng.seed), "rng_state": str(_rng.state),
		"run_serial": _run_serial, "shop_serial": _shop_serial, "shop_wave": _shop_wave,
		"offer_revision": _offer_revision, "reroll_used": _reroll_used, "sell_used": _sell_used, "price_scale": price_scale,
	}


func import_state(data: Dictionary) -> bool:
	# Decode independent temporary values; corrupt saves never partially replace state.
	var required: Array[String] = ["version", "weapons", "mods", "offers", "rng_seed", "rng_state", "run_serial", "shop_serial", "shop_wave", "offer_revision", "reroll_used", "price_scale"]
	if not _integer_in(data.get("version"), 1, STATE_VERSION):
		return false
	var version: int = int(data.version)
	if version >= 2:
		required.append("sell_used")
	if version >= 3:
		required.append_array(["slots", "repair_bought"])
	if not _exact_keys(data, required):
		return false
	var next_sell_used: bool = false
	if version >= 2:
		if not data.sell_used is bool:
			return false
		next_sell_used = data.sell_used
	var next_slots: int = MAX_WEAPON_SLOTS
	var next_repair_bought: bool = false
	if version >= 3:
		if not _integer_in(data.slots, 3, 4) or not data.repair_bought is bool:
			return false
		next_slots = int(data.slots)
		next_repair_bought = data.repair_bought
	var allowed_weapons: Array[String] = WEAPON_IDS if version >= 3 else LEGACY_WEAPON_IDS
	if not _valid_inventory(data["weapons"], allowed_weapons) or not _valid_inventory(data["mods"], MOD_IDS):
		return false
	var next_weapons: Dictionary = data["weapons"].duplicate(true)
	var next_mods: Dictionary = data["mods"].duplicate(true)
	var used_slots: int = 0
	for id: String in WEAPON_IDS:
		next_weapons[id] = int(next_weapons.get(id, 0))
		if next_weapons[id] > 0:
			used_slots += 1
	for id: String in MOD_IDS:
		next_mods[id] = int(next_mods[id])
	if next_weapons["brush"] < 1 or used_slots > next_slots:
		return false
	if not _integer_in(data["run_serial"], 1, 1000000000) or not _integer_in(data["shop_serial"], 0, 1000000000):
		return false
	if not _integer_in(data["shop_wave"], 0, 1000000 if next_slots == 4 else 5) or not _integer_in(data["offer_revision"], 0, 2) or not data["reroll_used"] is bool:
		return false
	if not _int64_string(data["rng_seed"]) or not _int64_string(data["rng_state"]):
		return false
	if not (data["price_scale"] is float or data["price_scale"] is int) or not is_finite(float(data["price_scale"])) or float(data["price_scale"]) < 1.0 or float(data["price_scale"]) > 4.0:
		return false
	var next_price_scale: float = float(data["price_scale"])
	var run_serial: int = int(data["run_serial"])
	var shop_serial: int = int(data["shop_serial"])
	var shop_wave: int = int(data["shop_wave"])
	var revision: int = int(data["offer_revision"])
	var reroll_used: bool = data["reroll_used"]
	if revision != (1 if reroll_used else 0) + (1 if next_sell_used else 0) or ((shop_serial == 0) != (shop_wave == 0)):
		return false
	if not data["offers"] is Array or data["offers"].size() > OFFER_COUNT:
		return false
	if next_repair_bought and (next_slots != 4 or shop_wave < 3):
		return false
	if shop_serial == 0 and (not data["offers"].is_empty() or reroll_used or next_sell_used or next_repair_bought):
		return false
	var next_offers: Array[Dictionary] = []
	var seen: Dictionary = {}
	var offer_keys: Array[String] = ["token", "id", "kind", "level", "cost", "name_key", "desc_key", "sold"]
	for raw: Variant in data["offers"]:
		if not raw is Dictionary or not _exact_keys(raw, offer_keys):
			return false
		if not raw["id"] is String or not raw["sold"] is bool:
			return false
		var id: String = raw["id"]
		var repair: bool = id == "repair" and version >= 3 and next_slots == 4 and shop_wave >= 3
		if (id not in allowed_weapons and id not in MOD_IDS and not repair) or seen.has(id):
			return false
		seen[id] = true
		var is_weapon: bool = id in WEAPON_IDS
		var current_level: int = int(next_weapons[id] if is_weapon else next_mods.get(id, 0))
		var expected_level: int = 1 if repair else (current_level if raw["sold"] else current_level + 1)
		if repair and bool(raw.sold) != next_repair_bought:
			return false
		if not _integer_in(raw["level"], 1, MAX_LEVEL) or int(raw["level"]) != expected_level:
			return false
		if not _integer_in(raw["cost"], 0, 100000) or int(raw["cost"]) != item_cost(id, expected_level, shop_wave, next_price_scale):
			return false
		if raw["token"] != "%d:%d:%d:%d:%s" % [run_serial, shop_serial, shop_wave, revision, id]:
			return false
		var name_key: String = "ITEM_" + id.to_upper()
		if raw["kind"] != ("weapon" if is_weapon else ("consumable" if repair else "mod")) or raw["name_key"] != name_key or raw["desc_key"] != name_key + "_DESC":
			return false
		var decoded: Dictionary = raw.duplicate(true)
		decoded["level"] = int(decoded["level"])
		decoded["cost"] = int(decoded["cost"])
		next_offers.append(decoded)
	var next_rng := RandomNumberGenerator.new()
	next_rng.seed = String(data["rng_seed"]).to_int()
	next_rng.state = String(data["rng_state"]).to_int()
	weapons = next_weapons
	mods = next_mods
	price_scale = next_price_scale
	_offers = next_offers
	_rng = next_rng
	_run_serial = run_serial
	_shop_serial = shop_serial
	_shop_wave = shop_wave
	_offer_revision = revision
	_reroll_used = reroll_used
	_sell_used = next_sell_used
	slots = next_slots
	_repair_bought = next_repair_bought
	return true


static func _exact_keys(data: Dictionary, keys: Array[String]) -> bool:
	if data.size() != keys.size():
		return false
	for key: String in keys:
		if not data.has(key):
			return false
	return true


static func _valid_inventory(value: Variant, ids: Array[String]) -> bool:
	if not value is Dictionary or not _exact_keys(value, ids):
		return false
	for id: String in ids:
		if not _integer_in(value[id], 0, MAX_LEVEL):
			return false
	return true


static func _integer_in(value: Variant, minimum: int, maximum: int) -> bool:
	if value is int:
		return value >= minimum and value <= maximum
	# JSON has one numeric type; only finite, integral, bounded values are valid.
	return value is float and is_finite(value) and value == floor(value) and value >= minimum and value <= maximum


static func _int64_string(value: Variant) -> bool:
	return value is String and value.is_valid_int() and str(value.to_int()) == value


func _rejected(reason: String, id: String = "") -> Dictionary:
	return {"ok": false, "reason": reason, "cost": 0, "id": id}
