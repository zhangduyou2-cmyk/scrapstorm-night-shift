class_name ScrapProfile
extends RefCounted
## Local progression. A successful disk write commits a purchase or reward.

const VERSION: int = 3
const Achievements = preload("res://scripts/services/achievement_catalog.gd")
const MAX_HISTORY: int = 100
const MAX_COINS: int = 100000000
const CATALOG: Dictionary = {
	"skin_industrial": {"kind": "skin", "value": "industrial", "cost": 0},
	"skin_arctic": {"kind": "skin", "value": "arctic", "cost": 90},
	"skin_hazard": {"kind": "skin", "value": "hazard", "cost": 140},
	"color_mint": {"kind": "skill_color", "value": "mint", "cost": 0},
	"color_cyan": {"kind": "skill_color", "value": "cyan", "cost": 40},
	"color_violet": {"kind": "skill_color", "value": "violet", "cost": 60},
	"skill_pulse": {"kind": "skill", "value": "pulse", "cost": 0},
	"skill_singularity": {"kind": "skill", "value": "singularity", "cost": 160},
	"skill_overdrive": {"kind": "skill", "value": "overdrive", "cost": 0},
}
const LEGACY_OWNED: Array[String] = ["skin_industrial", "color_mint", "skill_pulse"]
const DEFAULT_OWNED: Array[String] = ["skin_industrial", "color_mint", "skill_pulse", "skill_overdrive"]
const BADGES: Array[String] = ["yard_clear", "foundry_clear", "reactor_clear", "pulse_master", "singularity_master", "overdrive_master"]
var data: Dictionary = {}
var path: String
var last_error: String = ""
var recovered_backup: bool = false


func _init(save_path: String = "user://profile.json") -> void:
	path = save_path
	data = _empty()
	load_profile()


func _empty() -> Dictionary:
	return {"version": VERSION, "coins": 0, "owned": DEFAULT_OWNED.duplicate(),
		"selected": {"skin": "industrial", "skill_color": "mint", "skill": "pulse", "title": ""},
		"records": {}, "settled_runs": [], "checkpoint": {}, "target_unlock": "skill_singularity", "badges": [], "mastery": {}, "migration_refund": 0, "history": [], "achievements": {}, "career": _empty_career()}


func load_profile() -> bool:
	for candidate: String in [path, path + ".bak"]:
		var loaded: Dictionary = _read(candidate)
		if not loaded.is_empty():
			data = loaded
			recovered_backup = candidate.ends_with(".bak")
			last_error = "" if not recovered_backup else "PROFILE_RECOVERED"
			if int(data.version) < VERSION:
				return _migrate_legacy()
			return true
	if FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak"):
		last_error = "PROFILE_DAMAGED"
	return false


func _empty_career() -> Dictionary:
	return {"total_runs": 0, "total_kills": 0, "total_scrap": 0, "total_boss_kills": 0,
		"total_combat_seconds": 0.0, "best_endless_rooms": 0, "best_endless_cycles": 0,
		"best_endless_seconds": 0.0, "endless_bosses": 0, "clean_standard": 0,
		"clean_bosses": 0, "extractions": 0, "evolutions": []}


func _migrate_legacy() -> bool:
	# v1 refund, v2 preservation and v3 addition form one disk transaction.
	if not _valid(data) or int(data.version) >= VERSION:
		last_error = "PROFILE_INVALID"
		return false
	var previous: Dictionary = data.duplicate(true)
	if int(data.version) == 1:
		var refund: int = 180 if "skill_overdrive" in data.owned else 0
		data.coins = mini(MAX_COINS, int(data.coins) + refund)
		if "skill_overdrive" not in data.owned:
			data.owned.append("skill_overdrive")
		data.target_unlock = "" if "skill_singularity" in data.owned else "skill_singularity"
		data.badges = []
		data.mastery = {}
		data.migration_refund = refund
		for map_id: String in ["yard", "foundry", "reactor"]:
			if int(data.records.get(map_id, {}).get("clears", 0)) > 0:
				data.badges.append(map_id + "_clear")
	data.version = VERSION
	data.selected["title"] = ""
	data.history = []
	data.achievements = {}
	data.career = _empty_career()
	return _commit(previous)


func _ensure_current() -> bool:
	if not _valid(data):
		last_error = "PROFILE_INVALID"
		return false
	return int(data.version) == VERSION or _migrate_legacy()


func _read(candidate: String) -> Dictionary:
	if not FileAccess.file_exists(candidate):
		return {}
	var file := FileAccess.open(candidate, FileAccess.READ)
	if file == null or file.get_length() > 4_000_000:
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {}
	var envelope: Variant = parser.data
	if not envelope is Dictionary or not envelope.get("payload", null) is String:
		return {}
	var payload: String = envelope.payload
	if envelope.get("checksum", "") != payload.sha256_text():
		return {}
	if parser.parse(payload) != OK:
		return {}
	var decoded: Variant = parser.data
	if not decoded is Dictionary or not _valid(decoded):
		return {}
	return decoded


func _number(value: Variant, maximum: float = 1.0e12, integral: bool = true) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0.0 and float(value) <= maximum and (not integral or float(value) == floorf(float(value)))


func _strings(value: Variant, maximum: int, allowed: Array = []) -> bool:
	if not value is Array or value.size() > maximum:
		return false
	var seen: Array = []
	for id: Variant in value:
		if not id is String or id.is_empty() or id.length() > 128 or id in seen or (not allowed.is_empty() and id not in allowed):
			return false
		seen.append(id)
	return true


func _item(id: String) -> Dictionary:
	return CATALOG.get(id, Achievements.REWARDS.get(id, {}))


func _valid(value: Dictionary) -> bool:
	if not _number(value.get("version"), VERSION) or int(value.version) not in [1, 2, 3] or not _number(value.get("coins"), MAX_COINS):
		return false
	if not value.get("selected") is Dictionary or not value.get("records") is Dictionary or not value.get("checkpoint") is Dictionary:
		return false
	var allowed: Array = CATALOG.keys()
	if int(value.version) == VERSION:
		allowed.append_array(Achievements.REWARDS.keys())
	if not _strings(value.get("owned"), allowed.size(), allowed) or not _strings(value.get("settled_runs"), 256):
		return false
	for item: String in LEGACY_OWNED if int(value.version) == 1 else DEFAULT_OWNED:
		if item not in value.owned:
			return false
	for kind: String in ["skin", "skill_color", "skill"]:
		var valid_selection: bool = false
		for item: String in value.owned:
			valid_selection = valid_selection or (_item(item).kind == kind and _item(item).value == value.selected.get(kind))
		if not valid_selection:
			return false
	for map_id: Variant in value.records:
		if map_id not in ["yard", "foundry", "reactor", "quick", "demo", "endless"] or not value.records[map_id] is Dictionary:
			return false
		for stat: String in ["clears", "best_wave", "best_kills", "best_time", "best_rooms", "best_cycles", "best_survival"]:
			if not _number(value.records[map_id].get(stat, 0), 1.0e12, false):
				return false
	if int(value.version) >= 2:
		if not value.get("target_unlock") is String or (not value.target_unlock.is_empty() and not CATALOG.has(value.target_unlock)) or value.target_unlock in value.owned:
			return false
		if not _number(value.get("migration_refund"), 180) or int(value.migration_refund) not in [0, 180]:
			return false
		if not _strings(value.get("badges"), BADGES.size(), BADGES) or not value.get("mastery") is Dictionary:
			return false
		for skill: Variant in value.mastery:
			if skill not in ["pulse", "singularity", "overdrive"] or not _number(value.mastery[skill]):
				return false
	if int(value.version) == VERSION:
		if not value.selected.get("title") is String or (not value.selected.title.is_empty() and ("title_" + value.selected.title) not in value.owned):
			return false
		if not value.get("history") is Array or value.history.size() > MAX_HISTORY or not value.get("career") is Dictionary or not value.get("achievements") is Dictionary:
			return false
		var ids: Array[String] = []
		for entry: Variant in value.history:
			if not entry is Dictionary or not _valid_history(entry) or entry.run_id in ids or entry.run_id not in value.settled_runs:
				return false
			ids.append(entry.run_id)
		for key: String in _empty_career():
			if key == "evolutions":
				if not _strings(value.career.get(key), 6, Achievements.ALL_EVOLUTIONS):
					return false
			elif not _number(value.career.get(key), 1.0e12, not key.ends_with("seconds")):
				return false
		for id: Variant in value.achievements:
			if not Achievements.DEFINITIONS.has(id) or not value.achievements[id] is Dictionary or not _number(value.achievements[id].get("unlocked_at"), 1.0e12):
				return false
			var reward: String = Achievements.DEFINITIONS[id].reward
			if not reward.is_empty() and reward not in value.owned:
				return false
		for id: String in value.owned:
			if Achievements.REWARDS.has(id):
				var earned: bool = false
				for achievement: String in value.achievements:
					earned = earned or Achievements.DEFINITIONS[achievement].reward == id
				if not earned:
					return false
	return true


func _valid_loadout(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for group: String in ["weapons", "mods"]:
		if not value.get(group, {}) is Dictionary:
			return false
		var allowed: Array = ["brush", "foam", "arc", "saw", "laser", "missile", "drone", "mines"] if group == "weapons" else ["hull", "treads", "magnet", "capacitor", "torque", "coolant"]
		for id: Variant in value.get(group, {}):
			if id not in allowed or not _number(value[group][id], 3):
				return false
	return true


func _valid_history(entry: Dictionary) -> bool:
	var fields: Array[String] = ["run_id", "ended_at", "mode", "map", "combat_seconds", "waves", "rooms", "cycles", "kills", "scrap", "damage_taken", "damage_events", "damage_tracked", "skill", "skill_uses", "loadout", "evolutions", "won", "extracted", "abandoned", "coins", "boss_kills", "boss_damage_taken", "boss_damage_tracked", "mutators", "achievements"]
	if entry.size() != fields.size():
		return false
	for key: Variant in entry:
		if key not in fields:
			return false
	if not entry.get("run_id") is String or entry.run_id.is_empty() or entry.run_id.length() > 128:
		return false
	if entry.get("mode") not in ["standard", "endless", "quick", "demo"] or entry.get("map") not in ["yard", "foundry", "reactor", "quick", "demo"] or entry.get("skill") not in ["pulse", "singularity", "overdrive"]:
		return false
	for key: String in ["ended_at", "waves", "rooms", "cycles", "kills", "scrap", "damage_events", "skill_uses", "coins", "boss_kills"]:
		if not _number(entry.get(key), 1.0e12):
			return false
	for key: String in ["combat_seconds", "damage_taken", "boss_damage_taken"]:
		if not _number(entry.get(key), 1.0e12, false):
			return false
	for key: String in ["won", "extracted", "abandoned", "damage_tracked", "boss_damage_tracked"]:
		if not entry.get(key) is bool:
			return false
	if entry.mode in ["standard", "endless"] and entry.map not in ["yard", "foundry", "reactor"]:
		return false
	if (entry.won and entry.abandoned) or (entry.extracted and (entry.abandoned or entry.mode != "endless" or int(entry.rooms) == 0 or int(entry.rooms) % 3 != 0 or int(entry.boss_kills) == 0)):
		return false
	if int(entry.waves) > 5 or int(entry.cycles) > int(entry.rooms) or (entry.mode == "endless" and int(entry.boss_kills) > int(entry.rooms) / 3):
		return false
	return _valid_loadout(entry.get("loadout")) and _strings(entry.get("evolutions"), 6, Achievements.ALL_EVOLUTIONS) and _strings(entry.get("mutators"), 64) and _strings(entry.get("achievements"), Achievements.DEFINITIONS.size(), Achievements.DEFINITIONS.keys())


func save() -> bool:
	if _number(data.get("version"), VERSION) and int(data.version) in [1, 2]:
		return _migrate_legacy()
	if not _valid(data):
		last_error = "PROFILE_INVALID"
		return false
	var payload: String = JSON.stringify(data)
	var envelope: String = JSON.stringify({"payload": payload, "checksum": payload.sha256_text()})
	var temp_path: String = path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		last_error = "PROFILE_SAVE_FAILED"
		return false
	file.store_string(envelope)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		last_error = "PROFILE_SAVE_FAILED"
		return false
	# Preserve only a validated primary; a corrupt primary must not replace backup.
	if not _read(path).is_empty():
		if DirAccess.copy_absolute(path, path + ".bak") != OK:
			last_error = "PROFILE_SAVE_FAILED"
			return false
	if DirAccess.rename_absolute(temp_path, path) != OK:
		last_error = "PROFILE_SAVE_FAILED"
		return false
	last_error = ""
	return true


func _commit(previous: Dictionary) -> bool:
	if save():
		return true
	data = previous
	return false


func owns(item: String) -> bool:
	return item in data.owned


func purchase(item: String) -> Dictionary:
	if not _ensure_current():
		return {"ok": false, "reason": last_error}
	if not CATALOG.has(item):
		return {"ok": false, "reason": "PROFILE_INVALID"}
	if owns(item):
		return equip(item)
	var cost: int = int(CATALOG[item].cost)
	if int(data.coins) < cost:
		return {"ok": false, "reason": "GARAGE_NEED_COINS"}
	var previous: Dictionary = data.duplicate(true)
	data.coins = int(data.coins) - cost
	data.owned.append(item)
	data.selected[CATALOG[item].kind] = CATALOG[item].value
	if data.get("target_unlock", "") == item:
		data.target_unlock = ""
	var ok: bool = _commit(previous)
	return {"ok": ok, "reason": "GARAGE_UNLOCKED" if ok else last_error, "cost": cost if ok else 0}


func equip(item: String) -> Dictionary:
	if not _ensure_current():
		return {"ok": false, "reason": last_error}
	if not owns(item) or _item(item).is_empty():
		return {"ok": false, "reason": "PROFILE_INVALID"}
	var previous: Dictionary = data.duplicate(true)
	data.selected[_item(item).kind] = _item(item).value
	var ok: bool = _commit(previous)
	return {"ok": ok, "reason": "GARAGE_EQUIPPED" if ok else last_error, "cost": 0}


func get_setup() -> Dictionary:
	var setup: Dictionary = data.selected.duplicate(true)
	setup["badges"] = data.get("badges", []).duplicate()
	setup["achievement_badges"] = data.get("achievements", {}).keys()
	return setup


func set_target(item: String) -> Dictionary:
	if not _ensure_current():
		return {"ok": false, "reason": last_error}
	if not CATALOG.has(item) or owns(item):
		return {"ok": false, "reason": "PROFILE_INVALID"}
	var previous: Dictionary = data.duplicate(true)
	data.target_unlock = item
	var ok: bool = _commit(previous)
	return {"ok": ok, "reason": "HANGAR_TARGET" if ok else last_error}


func save_checkpoint(run_id: String, world_state: Dictionary, summary: Dictionary) -> bool:
	if not _ensure_current():
		return false
	if run_id.is_empty() or run_id.length() > 128 or world_state.is_empty() or run_id in data.settled_runs:
		return false
	var previous: Dictionary = data.duplicate(true)
	data.checkpoint = {"run_id": run_id, "world": world_state.duplicate(true), "summary": summary.duplicate(true)}
	return _commit(previous)


func clear_checkpoint() -> bool:
	if not _ensure_current():
		return false
	var previous: Dictionary = data.duplicate(true)
	data.checkpoint = {}
	return _commit(previous)


func _entry(run_id: String, stats: Dictionary, won: bool) -> Dictionary:
	# All supplied numeric data is checked before conversion; absent old metrics
	# are explicitly untracked and cannot accidentally unlock no-hit achievements.
	for key: String in ["standard_mode", "endless_mode", "demo_mode", "demo", "extracted", "abandoned", "metrics_known"]:
		if stats.has(key) and not stats[key] is bool:
			return {}
	for key: String in ["wave", "kills", "total_scrap", "damage_events", "ability_uses", "rooms_completed", "cycles_completed", "boss_kills"]:
		if stats.has(key) and not _number(stats[key], 1.0e9):
			return {}
	for key: String in ["elapsed", "damage_taken", "boss_damage_taken"]:
		if stats.has(key) and not _number(stats[key], 1.0e9, false):
			return {}
	var endless: bool = stats.get("endless_mode", false)
	var standard: bool = stats.get("standard_mode", false) and not endless
	var demo: bool = stats.get("demo_mode", stats.get("demo", false)) and not endless and not standard
	var mode: String = "endless" if endless else ("standard" if standard else ("demo" if demo else "quick"))
	var map_id: Variant = stats.get("map_id", "yard") if standard or endless else mode
	if not map_id is String:
		return {}
	var wave: int = clampi(int(stats.get("wave", 1)), 1, 6)
	var completed: int = 5 if won and (standard or demo) else clampi(wave - 1, 0, 5)
	if stats.get("phase", "") == "shop":
		completed = mini(wave, 5)
	var loadout: Variant = stats.get("loadout", {"weapons": {}, "mods": {}})
	if not loadout is Dictionary:
		return {}
	loadout = {"weapons": loadout.get("weapons", {}), "mods": loadout.get("mods", loadout.get("modifiers", {}))}
	var raw_evolutions: Variant = stats.get("evolutions_seen", stats.get("evolutions", []))
	if not raw_evolutions is Array or raw_evolutions.size() > 6:
		return {}
	var evolutions: Array[String] = []
	for raw: Variant in raw_evolutions:
		var id: Variant = raw.get("id") if raw is Dictionary else raw
		if not id is String or id not in Achievements.ALL_EVOLUTIONS:
			return {}
		if raw is Dictionary and not raw.get("active", false):
			continue
		if id in evolutions:
			return {}
		evolutions.append(id)
	var entry: Dictionary = {"run_id": run_id, "ended_at": int(Time.get_unix_time_from_system()), "mode": mode, "map": map_id,
		"combat_seconds": float(stats.get("elapsed", 0.0)), "waves": 0 if endless else completed,
		"rooms": int(stats.get("rooms_completed", 0)) if endless else 0, "cycles": int(stats.get("cycles_completed", 0)) if endless else 0,
		"kills": int(stats.get("kills", 0)), "scrap": int(stats.get("total_scrap", 0)), "damage_taken": float(stats.get("damage_taken", 0.0)),
		"damage_events": int(stats.get("damage_events", 0)), "damage_tracked": stats.get("metrics_known", true) and stats.has("damage_taken") and stats.has("damage_events"),
		"skill": stats.get("ability_id", "pulse"), "skill_uses": int(stats.get("ability_uses", 0)), "loadout": loadout.duplicate(true),
		"evolutions": evolutions, "won": won, "extracted": stats.get("extracted", false), "abandoned": stats.get("abandoned", false),
		"coins": 0, "boss_kills": int(stats.get("boss_kills", 0)), "boss_damage_taken": float(stats.get("boss_damage_taken", 0.0)),
		"boss_damage_tracked": stats.get("metrics_known", true) and stats.has("boss_damage_taken") and stats.has("boss_kills"), "mutators": stats.get("mutators", []).duplicate() if stats.get("mutators", []) is Array else null,
		"achievements": []}
	return entry if _valid_history(entry) else {}


func settle(run_id: String, stats: Dictionary, won: bool) -> Dictionary:
	if not _ensure_current():
		return {"ok": false, "coins": 0, "reason": last_error}
	if run_id.is_empty() or run_id.length() > 128:
		return {"ok": false, "coins": 0, "reason": "PROFILE_INVALID"}
	if run_id in data.settled_runs:
		return {"ok": true, "coins": 0, "base_coins": 0, "achievement_coins": 0, "new_achievements": [], "unlocks": [], "duplicate": true}
	var entry: Dictionary = _entry(run_id, stats, won)
	if entry.is_empty():
		return {"ok": false, "coins": 0, "reason": "PROFILE_INVALID"}
	var standard: bool = entry.mode == "standard"
	var endless: bool = entry.mode == "endless"
	var record_id: String = "endless" if endless else entry.map
	var record: Dictionary = data.records.get(record_id, {"clears": 0, "best_wave": 0, "best_kills": 0, "best_time": 0.0}).duplicate(true)
	var first_clear: bool = standard and won and int(record.get("clears", 0)) == 0
	var coins: int = mini(6, int(entry.kills) / 10) + int(entry.waves) * (12 if standard else 4)
	if won:
		coins += 70 if standard else 12
	if first_clear:
		coins += 30
	if endless:
		coins = int(entry.rooms) * 8 + int(entry.boss_kills) * 20 + mini(10, int(entry.kills) / 20)
		if entry.extracted:
			coins += mini(40, int(entry.boss_kills) * 10)
	var base_coins: int = coins
	var previous: Dictionary = data.duplicate(true)
	var new_badges: Array[String] = []
	if standard and won:
		var badge: String = entry.map + "_clear"
		if badge not in data.badges:
			data.badges.append(badge)
			new_badges.append(badge)
		if int(entry.skill_uses) >= 3:
			data.mastery[entry.skill] = int(data.mastery.get(entry.skill, 0)) + 1
			if int(data.mastery[entry.skill]) >= 3 and entry.skill + "_master" not in data.badges:
				data.badges.append(entry.skill + "_master")
				new_badges.append(entry.skill + "_master")
	record.best_wave = maxi(int(record.get("best_wave", 0)), int(entry.rooms) if endless else (clampi(int(stats.get("wave", 1)), 1, 6) if standard or entry.mode == "demo" else (1 if won else 0)))
	record.best_kills = maxi(int(record.get("best_kills", 0)), int(entry.kills))
	if won or entry.extracted:
		record.clears = int(record.get("clears", 0)) + 1
		if float(record.get("best_time", 0.0)) == 0.0 or float(entry.combat_seconds) < float(record.best_time):
			record.best_time = entry.combat_seconds
	if endless:
		record.best_rooms = maxi(int(record.get("best_rooms", 0)), int(entry.rooms))
		record.best_cycles = maxi(int(record.get("best_cycles", 0)), int(entry.cycles))
		record.best_survival = maxf(float(record.get("best_survival", 0.0)), float(entry.combat_seconds))
	data.records[record_id] = record
	_update_career(entry)
	var new_achievements: Array[String] = []
	var unlocks: Array[String] = []
	# A legacy record may contribute progress, but a zero-action exit never pays
	# either retroactive milestones or run achievements.
	if float(entry.combat_seconds) > 0.0 and (int(entry.kills) > 0 or int(entry.rooms) > 0 or (standard and won)):
		for id: String in Achievements.DEFINITIONS:
			var definition: Dictionary = Achievements.DEFINITIONS[id]
			if not data.achievements.has(id) and Achievements.progress(id, data) >= int(definition.target):
				data.achievements[id] = {"unlocked_at": entry.ended_at}
				new_achievements.append(id)
				coins += int(definition.coins)
				if not str(definition.reward).is_empty() and definition.reward not in data.owned:
					data.owned.append(definition.reward)
					unlocks.append(definition.reward)
	# Never credit more coins than the valid balance can hold.
	var credited: int = mini(coins, MAX_COINS - int(data.coins))
	data.coins = int(data.coins) + credited
	entry.coins = credited
	entry.achievements = new_achievements.duplicate()
	data.history.append(entry.duplicate(true))
	if data.history.size() > MAX_HISTORY:
		data.history.pop_front()
	data.settled_runs.append(run_id)
	if data.settled_runs.size() > 256:
		data.settled_runs.pop_front()
	if data.checkpoint.get("run_id", "") == run_id:
		data.checkpoint = {}
	var ok: bool = _commit(previous)
	return {"ok": ok, "coins": credited if ok else 0, "base_coins": mini(base_coins, credited) if ok else 0,
		"achievement_coins": maxi(0, credited - base_coins) if ok else 0, "total": int(data.coins), "first_clear": first_clear and ok,
		"completed": entry.rooms if endless else entry.waves, "badges": new_badges if ok else [],
		"new_achievements": new_achievements if ok else [], "unlocks": unlocks if ok else [],
		"history_entry": entry.duplicate(true) if ok else {}, "reason": "" if ok else last_error}


func _update_career(entry: Dictionary) -> void:
	var career: Dictionary = data.career
	career.total_runs = int(career.total_runs) + 1
	career.total_kills = int(career.total_kills) + int(entry.kills)
	career.total_scrap = int(career.total_scrap) + int(entry.scrap)
	career.total_boss_kills = int(career.total_boss_kills) + int(entry.boss_kills)
	career.total_combat_seconds = float(career.total_combat_seconds) + float(entry.combat_seconds)
	if entry.mode == "endless":
		career.best_endless_rooms = maxi(int(career.best_endless_rooms), int(entry.rooms))
		career.best_endless_cycles = maxi(int(career.best_endless_cycles), int(entry.cycles))
		career.best_endless_seconds = maxf(float(career.best_endless_seconds), float(entry.combat_seconds))
		career.endless_bosses = int(career.endless_bosses) + int(entry.boss_kills)
		if entry.extracted:
			career.extractions = int(career.extractions) + 1
	if ((entry.mode == "standard" and entry.won) or (entry.mode == "endless" and int(entry.rooms) >= 3)) and float(entry.combat_seconds) > 0.0 and int(entry.kills) > 0 and entry.boss_damage_tracked and int(entry.boss_kills) > 0 and float(entry.boss_damage_taken) == 0.0:
		career.clean_bosses = int(career.clean_bosses) + 1
	if entry.mode == "standard" and entry.won and entry.damage_tracked and int(entry.boss_kills) > 0 and float(entry.combat_seconds) >= 870.0 and float(entry.damage_taken) == 0.0 and int(entry.damage_events) == 0:
		career.clean_standard = int(career.clean_standard) + 1
	if float(entry.combat_seconds) > 0.0 and int(entry.kills) > 0:
		for id: String in entry.evolutions:
			if id not in career.evolutions:
				career.evolutions.append(id)


func get_history(page: int = 0, page_size: int = 6) -> Dictionary:
	var entries: Array = data.get("history", [])
	page_size = clampi(page_size, 1, 20)
	var pages: int = maxi(1, ceili(float(entries.size()) / float(page_size)))
	page = clampi(page, 0, pages - 1)
	var items: Array = []
	for offset: int in range(page * page_size, mini((page + 1) * page_size, entries.size())):
		items.append(entries[entries.size() - 1 - offset].duplicate(true))
	return {"items": items, "page": page, "pages": pages, "total": entries.size()}


func get_achievements() -> Array:
	var result: Array = []
	for id: String in Achievements.DEFINITIONS:
		result.append(Achievements.status(id, data))
	return result


func next_unlock() -> String:
	var target: String = str(data.get("target_unlock", ""))
	if CATALOG.has(target) and not owns(target):
		return target
	var choice: String = ""
	for item: String in CATALOG:
		if not owns(item) and (choice.is_empty() or int(CATALOG[item].cost) < int(CATALOG[choice].cost)):
			choice = item
	return choice
