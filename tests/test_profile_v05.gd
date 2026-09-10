extends SceneTree
const Profile = preload("res://scripts/services/player_profile.gd")
const Catalog = preload("res://scripts/services/achievement_catalog.gd")
var checks: int = 0
var failures: Array[String] = []
var paths: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)

func fixture(label: String) -> RefCounted:
	var path: String = "user://v05-profile-%s-%d-%d.json" % [label, OS.get_process_id(), Time.get_ticks_usec()]
	paths.append(path)
	return Profile.new(path)

func envelope(path: String, data: Dictionary) -> void:
	var payload: String = JSON.stringify(data)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"payload": payload, "checksum": payload.sha256_text()}))
	file.close()

func standard(map_id: String = "yard") -> Dictionary:
	return {"standard_mode": true, "map_id": map_id, "wave": 6, "kills": 180, "elapsed": 950.0,
		"ability_id": "pulse", "ability_uses": 4, "total_scrap": 900, "boss_kills": 1,
		"damage_taken": 0.0, "damage_events": 0, "boss_damage_taken": 0.0, "metrics_known": true,
		"loadout": {"weapons": {"brush": 2, "saw": 2}, "mods": {"magnet": 1}}, "evolutions": ["steel_storm"]}

func endless(rooms: int, extracted: bool = false) -> Dictionary:
	return {"endless_mode": true, "standard_mode": true, "map_id": "yard", "rooms_completed": rooms,
		"cycles_completed": rooms / 3, "boss_kills": rooms / 3, "elapsed": rooms * 75.0, "wave": rooms + 1,
		"kills": rooms * 24, "total_scrap": rooms * 60, "ability_id": "overdrive", "ability_uses": rooms,
		"damage_taken": 30.0, "damage_events": 3, "boss_damage_taken": 10.0, "extracted": extracted,
		"mutators": ["armored", "hunters"], "loadout": {"weapons": {"brush": 1}, "mods": {}}}

func _run() -> void:
	check(Profile.VERSION == 3 and Catalog.DEFINITIONS.size() >= 12, "Version 3 includes at least twelve distinct milestones")
	var profile: RefCounted = fixture("migration-v2")
	var old: Dictionary = profile.data.duplicate(true)
	old.version = 2
	for key: String in ["history", "career", "achievements"]:
		old.erase(key)
	old.selected.erase("title")
	old.coins = 321
	old.migration_refund = 180
	old.badges = ["yard_clear", "pulse_master"]
	old.mastery = {"pulse": 3}
	old.target_unlock = "skin_hazard"
	old.owned.append("skin_arctic")
	old.selected.skin = "arctic"
	old.records = {"yard": {"clears": 3, "best_wave": 6, "best_kills": 181, "best_time": 911.5}}
	old.settled_runs = ["v2-paid"]
	old.checkpoint = {"run_id": "v2-shop", "world": {"version": 1, "phase": "shop", "rng_state": "9223372036854775000", "loadout": {"offers": [{"id": "saw", "sold": true}], "reroll_used": true}}, "summary": {"wave": 2}}
	envelope(profile.path, old)
	profile = Profile.new(profile.path)
	check(profile.data.version == 3 and profile.data.coins == 321 and profile.data.migration_refund == 180, "v2 migration never repeats v1's refund or invents achievement coins")
	check(profile.data.badges == old.badges and same(profile.data.mastery, old.mastery) and profile.data.target_unlock == old.target_unlock, "v2 migration preserves badges, mastery and chosen unlock target")
	check(profile.data.selected.skin == "arctic" and profile.data.selected.title == "" and profile.data.owned == old.owned, "v2 selected cosmetics remain equipped and title defaults empty")
	check(same(profile.data.checkpoint, old.checkpoint) and same(profile.data.records, old.records) and profile.data.settled_runs == old.settled_runs, "v2 migration preserves exact checkpoint, records and dedupe IDs")
	check(profile.data.history.is_empty() and profile.data.achievements.is_empty() and profile.data.career.total_runs == 0, "Migration does not fabricate detailed historical battles")
	check(same(Profile.new(profile.path).data, profile.data), "v3 migration survives JSON reload exactly")
	check(profile.settle("v2-paid", standard(), true).coins == 0, "v2 settled IDs still suppress v3 settlement")
	var before: Dictionary = profile.data.duplicate(true)
	var zero: Dictionary = {"elapsed": 0.0, "kills": 0, "abandoned": true}
	var reward: Dictionary = profile.settle("empty-quit", zero, false)
	check(reward.ok and reward.coins == 0 and reward.new_achievements.is_empty(), "Empty quit never pays retroactive achievement progress")
	check(profile.get_achievements()[0].progress == 1 and not profile.get_achievements()[0].claimed, "Existing records show honest progress before the next active settlement")
	# Migration itself must roll back on a real disk-copy failure.
	var migration: RefCounted = fixture("v2-rollback")
	envelope(migration.path, old)
	DirAccess.make_dir_absolute(migration.path + ".bak")
	var quiet: bool = Engine.print_error_messages
	Engine.print_error_messages = false
	migration = Profile.new(migration.path)
	Engine.print_error_messages = quiet
	check(migration.data.version == 2 and migration.data.coins == 321 and same(migration.data.checkpoint, old.checkpoint) and migration.last_error == "PROFILE_SAVE_FAILED", "Failed v2 migration retains all old state and its original version")
	DirAccess.remove_absolute(migration.path + ".bak")
	check(Profile.new(migration.path).data.version == 3 and Profile.new(migration.path).data.coins == 321, "Recovered disk permits migration once without compensation duplication")
	# A complete, tracked no-hit clear earns cosmetic rewards exactly once.
	profile = fixture("achievements")
	var stats: Dictionary = standard()
	reward = profile.settle("clean-yard", stats, true)
	check(reward.ok and reward.base_coins == 166 and reward.achievement_coins == 120 and reward.coins == 286, "Base reward and four first-clear achievement rewards have separate exact amounts")
	check(reward.new_achievements.size() == 4 and "flawless_shift" in reward.new_achievements and "boss_precision" in reward.new_achievements, "Tracked full-shift and boss no-hit conditions unlock independently")
	check(profile.owns("skin_aurora") and profile.owns("color_ember") and profile.owns("title_shiftbreaker"), "Earned appearance, color and title enter ownership together")
	check(profile.get_setup().skin == "industrial" and profile.get_setup().title == "", "Achievement rewards never unexpectedly replace the chosen equipment")
	check(profile.equip("skin_aurora").ok and profile.equip("color_ember").ok and profile.equip("title_shiftbreaker").ok, "Unlocked reward skin, color and title can be equipped")
	check(Profile.new(profile.path).get_setup().skin == "aurora" and Profile.new(profile.path).get_setup().title == "shiftbreaker", "Reward equipment persists across a real disk reload")
	before = profile.data.duplicate(true)
	check(not profile.purchase("skin_cobalt").ok and not profile.equip("skin_cobalt").ok and not profile.set_target("skin_cobalt").ok and profile.data == before, "Locked achievements cannot be purchased, equipped or mistaken for coin-shop goals")
	check(profile.settle("clean-yard", stats, true).coins == 0 and profile.data == before, "Repeat settlement cannot re-award achievements, history, records or coins")
	var first: Dictionary = profile.get_history().items[0]
	check(first.combat_seconds == 950.0 and first.scrap == 900 and first.damage_tracked and first.boss_damage_tracked and first.coins == 286, "History records actual combat, cumulative scrap, tracked damage and credited coins")
	check(first.ended_at > 0 and first.loadout.weapons.saw == 2 and first.evolutions == ["steel_storm"] and first.skill_uses == 4, "History captures time, equipment, evolution and skill-use details")
	first.loadout.weapons.saw = 0
	check(profile.data.history[0].loadout.weapons.saw == 2, "History view returns a detached snapshot")
	for map_id: String in ["foundry", "reactor"]:
		stats = standard(map_id)
		stats.damage_taken = 30.0
		stats.damage_events = 3
		stats.boss_damage_taken = 10.0
		stats.evolutions = ["conduction_grid" if map_id == "foundry" else "compression_blast"]
		profile.settle("clear-" + map_id, stats, true)
	check(profile.owns("skin_cobalt") and profile.owns("title_stormforged") and profile.data.career.evolutions.size() == 3, "Three-sector and three distinct evolution goals award meaningful cosmetics")
	# Untracked, healed, partial or short runs must never farm no-hit awards.
	for kind: String in ["legacy", "unknown", "healed", "failed", "short", "quick"]:
		var target: RefCounted = fixture("nohit-" + kind)
		stats = standard()
		var won: bool = true
		if kind == "legacy":
			stats.erase("damage_taken")
			stats.erase("boss_damage_taken")
		elif kind == "unknown":
			stats.metrics_known = false
		elif kind == "healed":
			stats.health = 100.0
			stats.damage_taken = 20.0
			stats.damage_events = 2
			stats.boss_damage_taken = 5.0
		elif kind == "failed":
			won = false
			stats.boss_kills = 0
		elif kind == "short":
			won = false
			stats.elapsed = 0.0
			stats.kills = 0
			stats.boss_kills = 0
			stats.abandoned = true
		else:
			stats.standard_mode = false
		reward = target.settle(kind, stats, won)
		check(reward.ok and not target.data.achievements.has("flawless_shift") and not target.data.achievements.has("boss_precision"), "%s run cannot falsely earn either no-hit challenge" % kind)
	# Endless economics pays completed rooms, bosses and activity, with limited extraction bonus.
	profile = fixture("endless")
	stats = endless(3, true)
	reward = profile.settle("extract-3", stats, false)
	check(reward.ok and reward.base_coins == 57 and reward.achievement_coins == 60 and reward.coins == 117, "First 3-room extraction pays 24 rooms +20 boss +3 activity +10 exit, plus milestones")
	check(reward.history_entry.extracted and not reward.history_entry.won and reward.history_entry.rooms == 3 and reward.history_entry.cycles == 1, "Safe extraction is distinct from winning or dying")
	check(profile.data.records.endless.best_rooms == 3 and profile.data.career.best_endless_cycles == 1, "Endless records use completed rooms and completed cycles")
	for rooms: int in [6, 12, 24]:
		reward = profile.settle("endless-" + str(rooms), endless(rooms), false)
		check(reward.ok and "overtime_" + str(rooms) in reward.new_achievements, "Endless %d-room milestone unlocks on failure without erasing completed progress" % rooms)
	check(profile.owns("title_voidwalker") and profile.owns("color_prism") and profile.owns("title_nightlegend"), "Medium and long endless pursuits grant all advertised equipment")
	check(profile.data.records.endless.best_rooms == 24 and profile.data.records.endless.best_survival == 1800.0, "Highest endless depth and combat duration are retained")
	stats = endless(24, true)
	reward = profile.settle("cap-extract", stats, false)
	check(reward.base_coins == 402 and reward.achievement_coins == 0, "Repeat deep extraction has capped kill and extraction bonuses and no repeat achievement reward")
	var history_count: int = profile.data.history.size()
	check(Profile.new(profile.path).settle("cap-extract", stats, false).coins == 0 and Profile.new(profile.path).data.history.size() == history_count, "Endless extraction cannot be paid again after reload")
	# Invalid incoming metrics leave both memory and disk byte-for-byte intact.
	before = profile.data.duplicate(true)
	var hash: String = FileAccess.get_sha256(profile.path)
	var invalid_values: Dictionary = {"elapsed": INF, "kills": -1, "damage_taken": "zero", "damage_events": 1.5, "boss_damage_taken": NAN, "rooms_completed": -3, "cycles_completed": 1.5, "boss_kills": 1000, "mutators": ["same", "same"], "loadout": {"weapons": {"unknown": 2}}, "evolutions": ["imaginary"], "extracted": "yes", "ability_id": "unknown", "metrics_known": "false"}
	for key: String in invalid_values:
		stats = endless(3)
		stats[key] = invalid_values[key]
		reward = profile.settle("bad-" + key, stats, false)
		check(not reward.ok and profile.data == before and FileAccess.get_sha256(profile.path) == hash, "Invalid incoming %s is atomically rejected" % key)
	stats = endless(4, true)
	check(not profile.settle("illegal-extraction", stats, false).ok and profile.data == before, "Extraction away from a boss room cannot create a bonus")
	for key: String in ["ended_at", "coins", "damage_taken", "mode", "loadout", "run_id", "mutators"]:
		var broken: Dictionary = before.duplicate(true)
		if key in ["ended_at", "coins", "damage_taken"]:
			broken.history[0][key] = -1
		elif key == "mode":
			broken.history[0][key] = "fake"
		elif key == "loadout":
			broken.history[0][key] = {"weapons": {"brush": 7}}
		elif key == "run_id":
			broken.history[0][key] = "unsettled-forgery"
		else:
			broken.history[0][key] = ["duplicate", "duplicate"]
		check(not profile._valid(broken), "Invalid persisted history %s fails semantic validation" % key)
	var injected: Dictionary = profile.data.duplicate(true)
	injected.history[0]["shop_seconds"] = 99999
	check(not profile._valid(injected), "Unexpected shop-time telemetry cannot be loaded into a battle-history entry")
	var extended: RefCounted = fixture("extended-builds")
	stats = endless(3)
	stats.loadout = {"weapons": {"brush": 1, "laser": 2, "missile": 2, "drone": 2, "mines": 0}, "mods": {}}
	stats.evolutions_seen = ["prism_relay", "hunter_swarm", "ordnance_chain"]
	reward = extended.settle("new-builds", stats, false)
	check(reward.ok and reward.history_entry.evolutions.size() == 3, "History accepts the three new evolution IDs and expanded tool catalogue")
	check(not extended.data.achievements.has("stormforge"), "Three new evolutions cannot impersonate the specifically named original evolution trio")
	stats.evolutions_seen = Catalog.ALL_EVOLUTIONS.duplicate()
	stats.evolutions = [] # Earlier evolved tools may have been sold by settlement.
	reward = extended.settle("all-builds", stats, false)
	check(reward.ok and extended.data.career.evolutions.size() == 6 and extended.owns("title_stormforged"), "Previously activated and later sold evolutions remain in career and can complete the real trio")
	check(extended.data.mastery.is_empty() and not extended.data.records.has("yard") and extended.data.badges.is_empty(), "Endless flags never grant standard map clears or standard skill mastery")
	var known_failure: Dictionary = profile.data.duplicate(true)
	known_failure.history[0].damage_taken = "unknown"
	envelope(profile.path, known_failure)
	var recovered: RefCounted = Profile.new(profile.path)
	check(recovered.recovered_backup and recovered.last_error == "PROFILE_RECOVERED", "Checksummed but semantically invalid history recovers a validated backup")
	# Backup failure rolls back every new aggregate, collectible and history row.
	var fail: RefCounted = fixture("settle-rollback")
	fail.save()
	fail.save_checkpoint("atomic-clear", {"phase": "shop"}, {})
	before = fail.data.duplicate(true)
	DirAccess.remove_absolute(fail.path + ".bak")
	DirAccess.make_dir_absolute(fail.path + ".bak")
	Engine.print_error_messages = false
	reward = fail.settle("atomic-clear", standard(), true)
	Engine.print_error_messages = quiet
	check(not reward.ok and reward.coins == 0 and reward.new_achievements.is_empty() and fail.data == before, "Disk failure rolls back achievement coins, cosmetics, history, career and checkpoint together")
	check(same(Profile.new(fail.path).data, before), "Failed transaction leaves the previous disk profile intact")
	DirAccess.remove_absolute(fail.path + ".bak")
	check(fail.settle("atomic-clear", standard(), true).ok and fail.data.checkpoint.is_empty(), "Successful retry pays once and consumes only its own checkpoint")
	# History cap and dedupe cap are independent; pagination is newest first.
	profile = fixture("retention")
	for index: int in range(270):
		reward = profile.settle("retention-%d" % index, {"elapsed": 0.0, "kills": 0, "abandoned": true}, false)
		if not reward.ok:
			check(false, "Retention settlement %d succeeds" % index)
			break
	check(profile.data.history.size() == 100 and profile.data.history[0].run_id == "retention-170" and profile.data.history[99].run_id == "retention-269", "Only the latest 100 battles are retained")
	check(profile.data.settled_runs.size() == 256 and profile.data.settled_runs[0] == "retention-14" and profile.data.career.total_runs == 270, "Dedupe retains 256 IDs while lifetime aggregate remains complete")
	check(profile.get_history(0, 6).items[0].run_id == "retention-269" and profile.get_history(16, 6).items.size() == 4, "History pagination sorts newest first and handles its partial final page")
	check(profile.get_history(-1, 0).page == 0 and profile.get_history(999, 999).page == 4, "Pagination clamps caller bounds without exposing invalid entries")
	check(Profile.new(profile.path).data.history.size() == 100 and Profile.new(profile.path).data.career.total_runs == 270, "Capped history and lifetime statistics survive reload")
	var derived: Array = profile.get_achievements()
	derived[0].progress = 999
	check(profile.get_achievements()[0].progress == 0, "Achievement views cannot mutate persistent progression")
	for path: String in paths:
		for suffix: String in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)
	print("PROFILE_V05_TEST ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func same(left: Variant, right: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))
