extends SceneTree
const World = preload("res://scripts/game/game_world.gd")
const Arsenal = preload("res://scripts/game/arsenal_effects.gd")
const Loadout = preload("res://scripts/game/run_loadout.gd")
var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world: Node2D = World.new()
	root.add_child(world)
	world.set_physics_process(false)
	for action: String in ["move_left", "move_right", "move_up", "move_down", "vacuum", "dash", "active_skill"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	_test_loadout()
	_test_discovery_slots()
	var arsenal := Arsenal.new()
	world.start_standard("yard", 5051)
	world.player_position = Vector2(300, 390)
	var first: Dictionary = _enemy(world, Vector2(420, 390))
	var second: Dictionary = _enemy(world, Vector2(520, 390))
	var fork: Dictionary = _enemy(world, Vector2(445, 470))
	arsenal._fire_laser(world, {"aim": Vector2.RIGHT, "range": 500.0, "radius": 9.0, "damage": 34.0})
	_check(first.hp == 966.0 and second.hp == 966.0 and fork.hp == 1000.0, "laser penetrates aligned bodies once without hitting outside its width")
	world._loadout.weapons.laser = 2
	world._loadout.weapons.arc = 2
	arsenal._fire_laser(world, {"aim": Vector2.RIGHT, "range": 500.0, "radius": 9.0, "damage": 34.0})
	_check(fork.hp == 979.6, "prism relay adds an actual off-axis branch")
	world.start_standard("yard", 5052)
	world.player_position = Vector2(200, 267)
	first = _enemy(world, Vector2(350, 267))
	arsenal._fire_laser(world, {"aim": Vector2.RIGHT, "range": 500.0, "radius": 9.0, "damage": 34.0})
	_check(first.hp == 1000.0, "laser and secondary branches respect opaque crates")
	world.start_standard("reactor", 5053)
	world._spawn_boss()
	world.player_position = Vector2(200, 390)
	arsenal._fire_laser(world, {"aim": Vector2.RIGHT, "range": 200.0, "radius": 9.0, "damage": 34.0})
	_check(bool(world._director.encounters.targets[0].settled), "laser can destroy a visible power node through normal target hook")
	world.start_standard("yard", 5054)
	world.player_position = Vector2(640, 390)
	first = _enemy(world, Vector2(830, 420))
	arsenal.clear()
	arsenal.missiles.append({"pos": Vector2(690, 390), "velocity": Vector2.RIGHT * 300.0, "target": first.id, "damage": 30.0, "radius": 65.0, "life": 3.0})
	for i: int in range(60):
		arsenal._update_missiles(world, 1.0 / 60.0)
	_check(first.hp == 970.0 and arsenal.missiles.is_empty(), "guided missile steers, impacts and deals one splash")
	world.start_standard("yard", 5055)
	world.player_position = Vector2(640, 390)
	first = _enemy(world, Vector2(670, 390))
	arsenal.clear()
	for i: int in range(3):
		arsenal.mines.append({"id": i, "pos": Vector2(620 + i * 45, 390), "arm": 0.0, "fuse": -1.0, "life": 10.0, "damage": 38.0, "radius": 90.0, "settled": false})
	arsenal._chain_mines(world, Vector2(620, 390), 5.0)
	var after_chain: float = first.hp
	arsenal._chain_mines(world, Vector2(620, 390), 200.0)
	_check(after_chain == 886.0 and first.hp == after_chain and arsenal.blasts.size() == 3, "armed mine chain settles each mine once even with overlapping triggers")
	arsenal.clear()
	arsenal.mines.append({"id": 1, "pos": first.pos, "arm": 0.7, "fuse": -1.0, "life": 10.0, "damage": 38.0, "radius": 90.0, "settled": false})
	arsenal._chain_mines(world, first.pos, 100.0)
	_check(first.hp == after_chain and not bool(arsenal.mines[0].settled), "chain cannot bypass mine arming")
	world._loadout.weapons.drone = 2
	world._loadout.weapons.foam = 2
	arsenal.timers.drone = 0.0
	arsenal._update_drones(world)
	_check(arsenal.drone_positions.size() == 2 and first.hp < after_chain and world._foam.size() == 1, "hunter swarm drones orbit their mark, focus damage and lay foam")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(arsenal.export_state()))
	var clone := Arsenal.new()
	_check(clone.import_state(saved) and clone.export_state() == arsenal.export_state(), "arsenal shop timer checkpoint survives JSON floats")
	saved.timers.laser = INF
	var pristine: Dictionary = clone.export_state()
	_check(not clone.import_state(saved) and clone.export_state() == pristine, "invalid arsenal timing rejects atomically")
	world.start_standard("yard", 5056)
	world._loadout.weapons = {"brush": 3, "foam": 0, "arc": 2, "saw": 0, "laser": 3, "missile": 3, "drone": 3, "mines": 3}
	world.player_position = Vector2(640, 390)
	for i: int in range(30):
		var enemy: Dictionary = _enemy(world, Vector2(400 + i % 10 * 40, 330 + i / 10 * 55))
		enemy.hp = 100000.0
	arsenal.clear()
	var bounded: bool = true
	for i: int in range(900):
		arsenal.tick(world, 1.0 / 60.0)
		bounded = bounded and arsenal.missiles.size() <= 12 and arsenal.mines.size() <= 12 and arsenal.beams.size() <= 20 and arsenal.blasts.size() <= 16
	_check(bounded and float(world.damage_by_source.get("laser", 0)) > 0 and float(world.damage_by_source.get("missile", 0)) > 0 and float(world.damage_by_source.get("drone", 0)) > 0, "fifteen-second synthetic arsenal fixture exercises actual bounded weapon pools")
	var tracked_enemy: Dictionary = arsenal.mark
	arsenal.clear()
	_check(not tracked_enemy.is_empty() and tracked_enemy.has("kind") and tracked_enemy.has("hp"), "clearing the drone target releases its reference without erasing the world-owned enemy")
	_check(arsenal.missiles.is_empty() and arsenal.mines.is_empty() and arsenal.beams.is_empty() and arsenal.drone_positions.is_empty() and arsenal.clock == 0.0, "stage clear removes all new transient effects")
	_check(checks == 35, "all arsenal/loadout test sections reached completion")
	print("V05_ARSENAL ", JSON.stringify({"checks": checks, "failures": failures}))
	world.queue_free()
	await root.get_node("SoundBank").shutdown()
	await process_frame
	quit(0 if failures.is_empty() else 1)


func _test_loadout() -> void:
	var loadout := Loadout.new()
	_check(loadout.weapons.size() == 8 and loadout.slots == 3 and loadout.weapons.brush == 1, "standard begins with eight known tools and three slots")
	_check(not loadout.configure_slots(5) and loadout.configure_slots(4), "only standard or endless slot capacities are accepted")
	loadout.generate_offers(12)
	_check(not loadout.configure_slots(3) and loadout._shop_wave == 12, "live shops cannot change capacity and endless room IDs do not collapse to five")
	var imported := Loadout.new()
	_check(imported.import_state(JSON.parse_string(JSON.stringify(loadout.export_state()))) and imported.slots == 4, "version three preserves endless capacity")
	_check(loadout.reroll(9999, 12) == imported.reroll(9999, 12), "version three preserves offer RNG and full room identity")
	for version: int in [1, 2]:
		loadout.reset(44)
		loadout.weapons.foam = 1
		loadout.generate_offers(2)
		var legacy: Dictionary = loadout.export_state()
		legacy.version = version
		legacy.erase("slots")
		legacy.erase("repair_bought")
		if version == 1:
			legacy.erase("sell_used")
		for id: String in ["laser", "missile", "drone", "mines"]:
			legacy.weapons.erase(id)
		# Real old inventories never contained new discovery cards.
		legacy.offers.clear()
		_check(imported.import_state(JSON.parse_string(JSON.stringify(legacy))) and imported.slots == 3 and imported.weapons.laser == 0 and imported.weapons.foam == 1, "strict four-key version %d inventory migrates to eight keys" % version)
	loadout.reset(61)
	var discovered: Dictionary = {}
	for seed_value: int in range(80):
		loadout.reset(seed_value)
		for offer: Dictionary in loadout.generate_offers(1):
			if offer.kind == "weapon" and offer.level == 1:
				discovered[offer.id] = true
	_check(discovered.size() == 7, "all seven discoveries occur across deterministic seeds")
	loadout.reset(55)
	loadout.configure_slots(4)
	for id: String in ["brush", "laser", "missile", "mines"]:
		loadout.weapons[id] = 3
	for id: String in Loadout.MOD_IDS:
		loadout.mods[id] = 3
	var offers: Array[Dictionary] = loadout.generate_offers(30)
	_check(offers.size() == 1 and offers[0].id == "repair" and offers[0].kind == "consumable", "fully completed endless build still offers consumable repair")
	var token: String = str(offers[0].token)
	var saved: Dictionary = loadout.export_state()
	_check(not loadout.purchase(token, 0).ok and loadout.export_state() == saved, "failed consumable purchase changes no allowance or RNG")
	var purchase: Dictionary = loadout.purchase(token, 9999)
	_check(purchase.ok and purchase.repair_amount == 35.0 and not loadout.purchase(token, 9999).ok and not loadout.can_reroll(), "one repair settles once and cannot be reset by refresh")
	_check(imported.import_state(JSON.parse_string(JSON.stringify(loadout.export_state()))) and not imported.purchase(token, 9999).ok, "sold consumable remains sold after restore")
	_check(loadout.generate_offers(33)[0].id == "repair" and loadout.can_reroll(), "next endless shop replenishes its consumable allowance")
	saved = loadout.export_state()
	for field: String in ["fractional_slots", "fifth_weapon", "new_key_in_legacy", "fake_consumable", "bad_rng"]:
		var bad: Dictionary = saved.duplicate(true)
		match field:
			"fractional_slots": bad.slots = 3.5
			"fifth_weapon": bad.weapons.drone = 1
			"new_key_in_legacy": bad.version = 2
			"fake_consumable": bad.offers[0].kind = "weapon"
			"bad_rng": bad.rng_state = "001"
		var before: Dictionary = imported.export_state()
		_check(not imported.import_state(bad) and imported.export_state() == before, "reject %s atomically" % field)


func _enemy(world: Node2D, at: Vector2) -> Dictionary:
	world.debug_spawn_enemy(at, 0)
	var enemy: Dictionary = world._enemies.back()
	enemy.spawn = 0.0
	enemy.hp = 1000.0
	enemy.max_hp = 1000.0
	return enemy


func _test_discovery_slots() -> void:
	var loadout := Loadout.new()
	var guaranteed: bool = true
	var refreshed: bool = true
	var filled: bool = true
	for capacity: int in [3, 4]:
		for seed_value: int in range(24):
			loadout.reset(seed_value)
			loadout.configure_slots(capacity)
			loadout.weapons.laser = 1
			if capacity == 4:
				loadout.weapons.drone = 1
			for room: int in [3, 5, 9, 30]:
				var offers: Array[Dictionary] = loadout.generate_offers(room)
				guaranteed = guaranteed and _has_discovery(offers) and offers.size() == 3
				var result: Dictionary = loadout.reroll(9999, loadout._shop_wave)
				refreshed = refreshed and result.ok and _has_discovery(loadout.get_offers())
			loadout.weapons.mines = 1
			for room: int in [3, 5, 9, 30]:
				var offers: Array[Dictionary] = loadout.generate_offers(room)
				filled = filled and not _has_discovery(offers) and offers.size() == 3
	_check(guaranteed, "every later standard and endless shop reserves one discovery while one slot remains")
	_check(refreshed, "paid later-shop rerolls preserve an available discovery choice")
	_check(filled, "filled three/four-slot builds spend their offers on upgrades and mods instead of unusable discoveries")
	loadout.reset(91)
	loadout.generate_offers(4)
	var saved: Dictionary = loadout.export_state()
	# Existing legal shop cards remain a checkpoint fact; a changed generation
	# rule must not silently reroll or reject a previously open sparse shop.
	for index: int in range(saved.offers.size() - 1, -1, -1):
		if saved.offers[index].kind == "weapon" and saved.offers[index].level == 1:
			saved.offers.remove_at(index)
	var clone := Loadout.new()
	_check(clone.import_state(saved) and clone.get_offers() == saved.offers and clone.export_state().rng_state == saved.rng_state,
		"existing valid sparse shop checkpoints preserve their exact cards and RNG under the discovery guarantee")


func _has_discovery(offers: Array[Dictionary]) -> bool:
	for offer: Dictionary in offers:
		if offer.kind == "weapon" and offer.level == 1:
			return true
	return false


func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
		push_error(description)
