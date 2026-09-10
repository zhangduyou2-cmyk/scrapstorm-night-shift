extends SceneTree

const Profile = preload("res://scripts/services/player_profile.gd")
var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func verify(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)


func _run() -> void:
	var path: String = "user://profile-fixture-%d.json" % Time.get_ticks_usec()
	var profile := Profile.new(path)
	verify(profile.data.coins == 0 and profile.data.owned.size() == 4 and profile.owns("skill_overdrive"), "Fresh profile has free loadout without paid power")
	verify(profile._valid(JSON.parse_string(JSON.stringify(profile.data))), "JSON-decoded integral version numbers remain a valid reloadable profile")
	if not failures.is_empty():
		print("PROFILE_TEST ", JSON.stringify({"checks": checks, "failures": failures}))
		quit(1)
		return
	verify(not profile.purchase("skill_singularity").ok and profile.data.coins == 0, "Unaffordable blueprint cannot debit or equip")
	var stats := {"standard_mode": true, "map_id": "yard", "wave": 6, "kills": 180, "elapsed": 950.0}
	var reward: Dictionary = profile.settle("fixture-one", stats, true)
	verify(reward.ok and reward.base_coins == 166 and reward.achievement_coins == 35 and reward.coins == 201 and reward.first_clear, "First standard clear awards stages, activity, boss and first clear")
	verify(profile.settle("fixture-one", stats, true).coins == 0 and profile.data.coins == 201, "Repeated result cannot award twice")
	verify(profile.purchase("skill_singularity").ok and profile.data.coins == 41 and profile.get_setup().skill == "singularity", "Blueprint purchase deducts once and equips")
	verify(profile.purchase("skill_singularity").cost == 0 and profile.data.coins == 41, "Owned selection never repurchases")
	var loaded := Profile.new(path)
	verify(loaded.owns("skill_singularity") and loaded.data.coins == 41, "Saved currency, ownership and equipped setup reload")
	verify(loaded.settle("fixture-one", stats, true).coins == 0, "Reward deduplication survives restart")
	var summary := {"wave": 2, "bonus": 18}
	verify(loaded.save_checkpoint("fixture-two", {"phase": "shop", "rng": "9223372036854775000"}, summary), "Shop checkpoint saves current run independently of coins")
	var resume := Profile.new(path)
	verify(resume.data.checkpoint.run_id == "fixture-two" and resume.data.checkpoint.world.rng == "9223372036854775000", "Checkpoint round-trip retains exact RNG text")
	var failed := {"standard_mode": true, "map_id": "yard", "wave": 3, "kills": 42, "elapsed": 310.0}
	var failed_reward: Dictionary = resume.settle("fixture-two", failed, false)
	verify(failed_reward.ok and failed_reward.coins == 28 and resume.data.checkpoint.is_empty(), "Failure keeps completed stage rewards and consumes checkpoint")
	var before: int = int(resume.data.coins)
	failed["currency"] = 100000
	failed["elapsed"] = 1000000.0
	verify(resume.settle("fixture-three", failed, false).coins == 28, "Shop wallet and idle duration cannot inflate rewards")
	verify(int(resume.data.coins) == before + 28, "Reward commits exact expected amount")
	var corrupt := FileAccess.open(path, FileAccess.WRITE)
	corrupt.store_string("incomplete write")
	corrupt.close()
	var recovered := Profile.new(path)
	verify(recovered.recovered_backup and recovered.owns("skill_singularity"), "Corrupt primary recovers validated backup")
	verify(recovered.save(), "Recovery can replace corrupt primary safely")
	var bad: Dictionary = recovered.data.duplicate(true)
	bad.coins = -1
	verify(not recovered._valid(bad), "Negative balance is rejected")
	bad = recovered.data.duplicate(true)
	bad.selected.skill = "not-unlocked"
	verify(not recovered._valid(bad), "Forged selected blueprint is rejected")
	var intact: Dictionary = recovered.data.duplicate(true)
	for invalid_case: String in ["map", "run_id", "time"]:
		var invalid_stats: Dictionary = stats.duplicate(true)
		var invalid_id: String = "invalid-fixture-" + invalid_case
		if invalid_case == "map":
			invalid_stats.map_id = "missing-map"
		elif invalid_case == "run_id":
			invalid_id = "a".repeat(129)
		else:
			invalid_stats.elapsed = INF
		var rejected: Dictionary = recovered.settle(invalid_id, invalid_stats, true)
		verify(not rejected.ok and recovered.data == intact, "Invalid %s cannot reward or mutate the profile" % invalid_case)
	var reopened_after_rejections := Profile.new(path)
	verify(reopened_after_rejections.data == intact and reopened_after_rejections.last_error == "", "Rejected settlement input leaves an intact reloadable primary")
	var primary_hash: String = FileAccess.get_sha256(path)
	recovered.data.coins = -1
	verify(not recovered.save() and FileAccess.get_sha256(path) == primary_hash, "Invalid in-memory state cannot overwrite a valid disk profile")
	recovered.data = intact.duplicate(true)
	verify(not recovered.save_checkpoint("fixture-one", {"phase": "shop"}, {}), "Already-settled run cannot create a new resumable checkpoint")
	var backup_failure_path: String = "user://profile-backup-failure-%d.json" % Time.get_ticks_usec()
	var backup_failure := Profile.new(backup_failure_path)
	backup_failure.save()
	DirAccess.make_dir_absolute(backup_failure_path + ".bak")
	# Deliberately replace the backup file with a directory. Godot prints an
	# expected OS copy error; the assertion checks the returned failure and disk.
	var previous_error_output: bool = Engine.print_error_messages
	Engine.print_error_messages = false
	var failed_backup_reward: Dictionary = backup_failure.settle("backup-copy-failure", stats, true)
	Engine.print_error_messages = previous_error_output
	var after_backup_failure := Profile.new(backup_failure_path)
	verify(not failed_backup_reward.ok and backup_failure.data.coins == 0 and after_backup_failure.data.coins == 0 and after_backup_failure.last_error == "", "Backup-copy failure rolls back reward and preserves valid primary")
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(backup_failure_path + suffix)
	var unavailable := Profile.new("user://nonexistent-profile-folder-%d/profile.json" % Time.get_ticks_usec())
	var failure: Dictionary = unavailable.settle("cannot-save", stats, true)
	verify(not failure.ok and unavailable.data.coins == 0 and unavailable.data.settled_runs.is_empty(), "Failed disk write rolls back reward and settlement marker")
	_test_v04_progression()
	var settings: Node = root.get_node("Settings")
	var original_path: String = settings._config_path
	var original_keys: Dictionary = settings.key_bindings.duplicate()
	settings._config_path = "user://input-fixture-%d.cfg" % Time.get_ticks_usec()
	settings.reset_keys()
	verify(settings.rebind("dash", KEY_Q) and settings.get_key("dash") == KEY_Q, "Dash can be rebound")
	verify(not settings.rebind("active_skill", KEY_Q) and not settings.rebind("dash", KEY_ESCAPE), "Duplicate and reserved keys are rejected")
	settings.apply_input_bindings()
	settings.apply_input_bindings()
	verify(InputMap.action_get_events("dash").size() == 1, "Reapplying bindings is idempotent")
	DirAccess.remove_absolute(settings._config_path)
	settings._config_path = original_path
	settings.key_bindings = original_keys
	settings.apply_input_bindings()
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	print("PROFILE_TEST ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)


func _fixture_path(label: String) -> String:
	return "user://profile-v04-%s-%d-%d.json" % [label, OS.get_process_id(), Time.get_ticks_usec()]


func _write_envelope(destination: String, value: Dictionary, valid_checksum: bool = true) -> void:
	var payload: String = JSON.stringify(value)
	var file := FileAccess.open(destination, FileAccess.WRITE)
	file.store_string(JSON.stringify({"payload": payload, "checksum": payload.sha256_text() if valid_checksum else "damaged"}))
	file.close()


func _legacy(bought_overdrive: bool) -> Dictionary:
	var owned: Array[String] = ["skin_industrial", "color_mint", "skill_pulse", "skin_arctic", "color_cyan"]
	if bought_overdrive:
		owned.append("skill_overdrive")
	return {"version": 1, "coins": 37, "owned": owned,
		"selected": {"skin": "arctic", "skill_color": "cyan", "skill": "overdrive" if bought_overdrive else "pulse"},
		"records": {"yard": {"clears": 2, "best_wave": 6, "best_kills": 170, "best_time": 901.0}},
		"settled_runs": ["historic-settled"], "checkpoint": {"run_id": "old-shop", "summary": {"wave": 2},
			"world": {"version": 1, "phase": "shop", "rng_state": "9223372036854775000", "loadout": {"offers": [{"id": "foam", "sold": true}], "reroll_used": true}, "ability": {"skill": "overdrive" if bought_overdrive else "pulse", "cooldown": 3.0}}}}


func _clean_fixture(path: String) -> void:
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(path + suffix)


func _test_v04_progression() -> void:
	for bought: bool in [false, true]:
		var path: String = _fixture_path("legacy-paid" if bought else "legacy-free")
		var previous: Dictionary = _legacy(bought)
		_write_envelope(path, previous)
		var migrated := Profile.new(path)
		var expected: int = 217 if bought else 37
		verify(migrated.data.version == Profile.VERSION and migrated.owns("skill_overdrive") and migrated.data.coins == expected, "Legacy %s migrates to free overdrive with only the paid owner refunded" % str(bought))
		verify(migrated.data.get("migration_refund", -1) == (180 if bought else 0), "Migration records its exact one-time compensation")
		verify(migrated.data.selected.skin == previous.selected.skin and migrated.data.selected.skill_color == previous.selected.skill_color and migrated.data.selected.skill == previous.selected.skill and migrated.data.selected.title == "" and migrated.owns("skin_arctic") and migrated.owns("color_cyan"), "Migration preserves collected cosmetics and selected loadout")
		verify(_same_json(migrated.data.records, previous.records) and _same_json(migrated.data.settled_runs, previous.settled_runs), "Migration preserves map records and settlement history")
		verify(_same_json(migrated.data.checkpoint, previous.checkpoint), "Migration preserves opaque shop checkpoint fields, RNG text, sold offers and refresh state")
		verify("yard_clear" in migrated.data.badges and migrated.data.mastery.is_empty(), "Existing clear records grant their map badge without invented skill mastery")
		var reloaded := Profile.new(path)
		verify(_same_json(reloaded.data, migrated.data) and reloaded.data.coins == expected, "A second launch never repeats the legacy refund")
		var normal_stats: Dictionary = {"standard_mode": true, "map_id": "yard", "wave": 6, "kills": 80, "elapsed": 900.0, "ability_id": "overdrive", "ability_uses": 3}
		verify(reloaded.settle("historic-settled", normal_stats, true).coins == 0 and reloaded.data.coins == expected, "Legacy settled IDs still prevent duplicate clear rewards")
		_clean_fixture(path)
	# A damaged or semantically invalid legacy save cannot manufacture compensation.
	for corruption: String in ["checksum", "ownership"]:
		var path: String = _fixture_path(corruption)
		var invalid: Dictionary = _legacy(true)
		if corruption == "ownership":
			invalid.owned.append("unknown-paid-item")
		_write_envelope(path, invalid, corruption != "checksum")
		var rejected := Profile.new(path)
		verify(rejected.last_error == "PROFILE_DAMAGED" and rejected.data.coins == 0 and rejected.data.get("migration_refund", 0) == 0, "Invalid legacy " + corruption + " grants neither coins nor compensation")
		_clean_fixture(path)
	# Fail a real backup copy while migrating: no uncommitted credit is visible.
	var failing_path: String = _fixture_path("migration-atomic")
	var old: Dictionary = _legacy(true)
	_write_envelope(failing_path, old)
	DirAccess.make_dir_absolute(failing_path + ".bak")
	var quiet: bool = Engine.print_error_messages
	Engine.print_error_messages = false
	var failed_migration := Profile.new(failing_path)
	Engine.print_error_messages = quiet
	verify(failed_migration.data.coins == 37 and failed_migration.last_error == "PROFILE_SAVE_FAILED", "Failed migration rolls back its visible 180-coin refund")
	verify(failed_migration._read(failing_path).coins == 37 and failed_migration._read(failing_path).version == 1, "Failed migration leaves the original save intact")
	var before_failure: Dictionary = failed_migration.data.duplicate(true)
	Engine.print_error_messages = false
	var blocked_purchase: Dictionary = failed_migration.purchase("color_violet")
	Engine.print_error_messages = quiet
	verify(not blocked_purchase.ok and failed_migration.data == before_failure, "A pending migration cannot mutate the old-format economy")
	DirAccess.remove_absolute(failing_path + ".bak")
	var retried := Profile.new(failing_path)
	verify(retried.data.version == Profile.VERSION and retried.data.coins == 217, "Retrying after disk recovery commits one refund")
	verify(Profile.new(failing_path).data.coins == 217, "Successful retry is not a second compensation")
	_clean_fixture(failing_path)
	# Preferred unlock survives launch and is removed only by a committed purchase.
	var path: String = _fixture_path("target-badges")
	var profile := Profile.new(path)
	verify(profile.next_unlock() == "skill_singularity", "A fresh hangar has a meaningful default blueprint goal")
	verify(profile.set_target("skin_arctic").ok and profile.next_unlock() == "skin_arctic", "Selecting a target overrides the cheapest-item suggestion")
	verify(Profile.new(path).data.target_unlock == "skin_arctic", "Preferred unlock target persists across launch")
	var pristine: Dictionary = profile.data.duplicate(true)
	verify(not profile.set_target("skill_overdrive").ok and not profile.set_target("unknown").ok and profile.data == pristine, "Owned or unknown targets reject without changing the saved goal")
	profile.data.coins = 200
	profile.save()
	verify(profile.purchase("skin_arctic").ok and profile.data.target_unlock == "" and profile.data.coins == 110, "Successful target purchase clears the goal and charges once")
	verify(Profile.new(path).data.target_unlock == "", "Cleared target state persists")
	var clear: Dictionary = {"standard_mode": true, "map_id": "yard", "wave": 6, "kills": 70, "elapsed": 905.0, "ability_id": "pulse", "ability_uses": 3}
	var earned: Dictionary = profile.settle("badge-yard-1", clear, true)
	verify(earned.ok and earned.badges == ["yard_clear"] and profile.data.mastery.pulse == 1, "First real standard clear awards the map badge and one qualified mastery clear")
	verify(profile.settle("badge-yard-1", clear, true).coins == 0 and profile.data.mastery.pulse == 1, "Duplicate settlement cannot advance mastery or repeat a badge")
	clear.ability_uses = 2
	profile.settle("too-few-casts", clear, true)
	verify(profile.data.mastery.pulse == 1 and "pulse_master" not in profile.data.badges, "A clear with fewer than three casts does not advance skill mastery")
	clear.ability_uses = 8
	profile.settle("failed-casts", clear, false)
	verify(profile.data.mastery.pulse == 1, "Casting skills in a failed run does not count as mastery completion")
	var quick: Dictionary = clear.duplicate(true)
	quick.standard_mode = false
	quick.demo_mode = false
	profile.settle("quick-casts", quick, true)
	verify(profile.data.mastery.pulse == 1, "Quick survival clears do not substitute for standard mastery")
	for map_id: String in ["foundry", "reactor"]:
		clear.map_id = map_id
		earned = profile.settle("badge-" + map_id, clear, true)
		verify(map_id + "_clear" in earned.badges, "A first " + map_id + " clear grants that map's unique badge")
	verify(profile.data.mastery.pulse == 3 and "pulse_master" in profile.data.badges, "Three qualified standard clears grant pulse mastery once")
	earned = profile.settle("pulse-fourth", clear, true)
	verify(earned.badges.is_empty() and profile.data.mastery.pulse == 4, "Later qualified clears increase records without duplicate badges")
	for skill: String in ["singularity", "overdrive"]:
		if not profile.owns("skill_" + skill):
			profile.purchase("skill_" + skill)
		clear.ability_id = skill
		for attempt: int in range(3):
			profile.settle(skill + str(attempt), clear, true)
		verify(profile.data.mastery[skill] == 3 and skill + "_master" in profile.data.badges, "Three qualified clears grant independent " + skill + " mastery")
	var setup: Dictionary = profile.get_setup()
	setup.badges.clear()
	verify(profile.data.badges.size() == 6 and Profile.new(path).data.badges.size() == 6, "Equipped setup snapshots cannot mutate earned badges and all six persist")
	# New target/badge state must participate in the same failed-write rollback.
	var unavailable := Profile.new("user://missing-profile-parent-%d/profile.json" % Time.get_ticks_usec())
	pristine = unavailable.data.duplicate(true)
	verify(not unavailable.set_target("skin_hazard").ok and unavailable.data == pristine, "Disk failure rolls back preferred target changes")
	unavailable.data.coins = 500
	pristine = unavailable.data.duplicate(true)
	verify(not unavailable.purchase("skill_singularity").ok and unavailable.data == pristine, "Disk failure restores purchase coins, ownership, equipment and target")
	var failed_reward: Dictionary = unavailable.settle("badge-save-failed", clear, true)
	verify(not failed_reward.ok and failed_reward.badges.is_empty() and unavailable.data == pristine, "Disk failure rolls back badges, mastery, coins, records and run deduplication together")
	for invalid_refund: Variant in [-1, 1, 180.1, "180", INF]:
		var invalid: Dictionary = profile.data.duplicate(true)
		invalid.migration_refund = invalid_refund
		verify(not profile._valid(invalid), "Malformed migration compensation cannot enter a v2 save")
	var invalid: Dictionary = profile.data.duplicate(true)
	invalid.target_unlock = "skill_overdrive"
	verify(not profile._valid(invalid), "A saved target cannot point at an already owned item")

	_clean_fixture(path)


func _same_json(left: Variant, right: Variant) -> bool:
	# JSON numbers decode as doubles; compare normalized data rather than memory types.
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))
