extends SceneTree
## v0.4 integration fixtures: real world effects, not a normal-input playthrough.
const World = preload("res://scripts/game/game_world.gd")
var checks: int = 0
var failures: Array[String] = []
var world: Node2D
var settings: Node
var outcomes: Array[bool] = []


func _initialize() -> void:
	_run.call_deferred()


func verify(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)


func fresh(skill: String = "pulse") -> void:
	world.start_standard("yard", 4417, {"skill": skill})
	world._enemies.clear()
	world._scraps.clear()
	world._obstacles.clear()
	world.player_position = Vector2(600, 360)
	world.player_aim = Vector2.RIGHT
	world._spawn_timer = 999.0
	world._brush_timer = 999.0
	world._foam_timer = 999.0
	world._arc_timer = 999.0
	world._saw_timer = 999.0
	settings.effects_enabled = false


func enemy(at: Vector2, kind: int = 0) -> Dictionary:
	world.debug_spawn_enemy(at, kind)
	var target: Dictionary = world._enemies.back()
	target.spawn = 0.0
	target.hp = 1000.0
	target.max_hp = 1000.0
	return target


func foam(at: Vector2) -> void:
	world._foam.append({"pos": at, "radius": 45.0, "damage": 0.0, "life": 10.0, "tick": 99.0, "tick_interval": 99.0})


func _run() -> void:
	if not OS.get_cmdline_user_args().has("--test-settings"):
		push_error("V04 integration fixture requires --test-settings to isolate user state")
		quit(2)
		return
	for action: String in ["move_left", "move_right", "move_up", "move_down", "vacuum", "dash", "active_skill"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	settings = root.get_node("Settings")
	var prior_effects: bool = settings.effects_enabled
	world = World.new()
	root.add_child(world)
	world.set_physics_process(false)
	world.run_finished.connect(func(won: bool, _stats: Dictionary) -> void: outcomes.append(won))
	_test_steel_storm()
	_test_conduction_grid()
	_test_compression()
	_test_elite_commitments()
	_test_shop_and_sale()
	_test_feedback()
	_test_terminal_resolution()
	await _test_hud_isolation()
	settings.effects_enabled = prior_effects
	world.queue_free()
	await process_frame
	await root.get_node("SoundBank").shutdown()
	var report: Dictionary = {"checks": checks, "failures": failures, "note": "Real world effect and UI transform fixtures; equipment/enemies are prepared states, not normal-input progression, rendering performance or listening evidence."}
	var output := FileAccess.open("res://artifacts/v04-integration.json", FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(report, "  ") + "\n")
		output.close()
	print("V04_INTEGRATION ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)


func _test_steel_storm() -> void:
	fresh()
	world._loadout.weapons.brush = 2
	world._loadout.weapons.saw = 2
	var target: Dictionary = enemy(world.player_position + Vector2(220, 0))
	world._saw_timer = 0.0
	world._update_saws(0.0)
	verify(world._saws.size() == 2 and world._saws.all(func(saw: Dictionary) -> bool: return float(saw.orbit) > 0.8), "Brush II + Saw II launches two real orbiting saws")
	world._saw_timer = 999.0
	var first: Dictionary = world._saws[0]
	var previous: Vector2 = first.pos
	world._update_saws(0.1)
	verify(Vector2(first.pos).distance_to(previous) > 30.0 and absf(Vector2(first.pos).distance_to(world.player_position) - 84.0) < 0.01, "An evolved saw moves around the player instead of flying straight initially")
	# Isolate one of the two actually created projectiles and force repeated
	# contact with one prepared target to exercise its visited-target guard.
	world._saws.resize(1)
	target.pos = first.pos
	var health_before: float = target.hp
	world._update_saws(0.01)
	var after_first_hit: float = target.hp
	verify(after_first_hit < health_before and int(target.id) in first.visited, "The orbiting saw deals actual damage and records its target")
	for index: int in range(12):
		target.pos = first.pos
		world._update_saws(0.01)
	verify(target.hp == after_first_hit and first.visited.count(int(target.id)) == 1, "Repeated contact cannot damage the same enemy twice with one saw")
	target.pos = world.player_position + Vector2(220, 0)
	for index: int in range(65):
		world._update_saws(0.01)
	verify(float(first.orbit) == 0.0 and Vector2(first.velocity).length() > 400.0, "After its orbit the actual saw becomes an outbound projectile")
	previous = first.pos
	world._update_saws(0.03)
	verify(Vector2(first.pos).distance_to(previous) > 10.0, "The released saw continues moving after the orbit finishes")
	fresh()
	world._loadout.weapons.saw = 2
	enemy(world.player_position + Vector2(220, 0))
	world._saw_timer = 0.0
	world._update_saws(0.0)
	verify(world._saws.size() == 1 and world._saws[0].orbit == 0.0, "Without Brush II the same saw level retains its ordinary single-shot behavior")


func _test_conduction_grid() -> void:
	fresh()
	world._loadout.weapons.foam = 2
	world._loadout.weapons.arc = 2
	foam(Vector2(730, 320))
	foam(Vector2(930, 320))
	var source: Dictionary = enemy(Vector2(730, 320))
	var crossing: Dictionary = enemy(Vector2(830, 330))
	world._arc_timer = 0.0
	world._update_tools(0.01)
	verify(source.hp < 1000.0 and not world._evolution.links.is_empty(), "Actual Arc II hitting foam creates a cross-patch electrical link")
	var before: float = crossing.hp
	var link_count: int = world._evolution.links.size()
	world._evolution.tick(world, 0.01)
	verify(crossing.hp < before and float(world.damage_by_source.get("evolution", 0.0)) > 0.0, "An enemy crossing a conduction link receives real evolution damage")
	verify(world._evolution.links.size() == link_count, "Conduction damage does not recursively create new links")
	var after_tick: float = crossing.hp
	world._evolution.tick(world, 0.01)
	verify(crossing.hp == after_tick, "Link damage respects its tick interval")
	# A wall blocks damage to a nearby enemy across the line's width, while
	# leaving the line itself unobstructed; use the actual shared cover resolver.
	world._obstacles.append(Rect2(810, 323, 40, 3))
	for link: Dictionary in world._evolution.links:
		link.tick = 0.0
	before = crossing.hp
	world._evolution.tick(world, 0.01)
	verify(crossing.hp == before, "Conduction width cannot damage an enemy through a thin cover wall")
	world._evolution.clear()
	world._obstacles.clear()
	world._obstacles.append(Rect2(815, 270, 25, 120))
	world._evolution.arc_hit(world, source.pos)
	verify(world._evolution.links.is_empty(), "Opaque cover between foam patches prevents creating a link")
	world._obstacles.clear()
	world._loadout.weapons.arc = 1
	world._evolution.clear()
	world._evolution.arc_hit(world, source.pos)
	verify(world._evolution.links.is_empty(), "Dropping below Arc II disables conduction generation")


func _test_compression() -> void:
	fresh()
	world._loadout.mods.capacitor = 2
	world._loadout.mods.magnet = 2
	world._modifiers = world._loadout.get_modifiers()
	world.energy = 99.0
	world.debug_release()
	verify(world._evolution.wells.is_empty(), "A discharge below 100 energy cannot trigger compression")
	world.energy = 100.0
	world.debug_release()
	verify(world.energy == 0.0 and world._evolution.wells.size() == 1, "A real 100-energy discharge creates one compression well and spends only its energy")
	var well: Dictionary = world._evolution.wells[0]
	var target: Dictionary = enemy(Vector2(well.pos) + Vector2(0, 110))
	var before: Vector2 = target.pos
	world._evolution.tick(world, 0.1)
	verify(Vector2(target.pos).distance_to(well.pos) < before.distance_to(well.pos) - 15.0, "The compression well actually pulls a normal enemy toward its center")
	verify(target.hp == 1000.0, "The gathering period does not apply the future collapse damage early")
	var shielded: Dictionary = enemy(Vector2(well.pos) + Vector2(-100, 0))
	world._obstacles.append(Rect2(float(well.pos.x) - 50, float(well.pos.y) - 40, 10, 80))
	var shield_position: Vector2 = shielded.pos
	world._evolution.tick(world, 0.1)
	verify(shielded.pos == shield_position, "The compression well cannot pull through cover")
	var prior_damage: float = float(world.damage_by_source.get("evolution", 0.0))
	world._evolution.tick(world, 0.7)
	verify(target.hp < 1000.0 and world._evolution.wells.is_empty(), "The well collapses into real damage and retires exactly once")
	verify(shielded.hp == 1000.0 and float(world.damage_by_source.get("evolution", 0.0)) > prior_damage, "Collapse obeys cover and records its actual damage source")
	var after_collapse: float = target.hp
	world._evolution.tick(world, 1.0)
	verify(target.hp == after_collapse and world._evolution.wells.is_empty(), "A retired compression well cannot repeat damage or recursively spawn itself")
	fresh()
	world._loadout.mods.capacitor = 2
	world.energy = 100.0
	world.debug_release()
	verify(world._evolution.wells.is_empty(), "Capacity alone does not produce the Magnet II compression behavior")


func _test_elite_commitments() -> void:
	for skill: String in ["pulse", "singularity"]:
		fresh(skill)
		var center: Vector2 = world.player_position + Vector2(180, 0)
		if skill == "pulse":
			world._loadout.mods.capacitor = 2
			world._loadout.mods.magnet = 2
			world.energy = 100.0
			world.debug_release()
		else:
			world.aim_position = center
			world._ability.activate(world)
		var warning: Dictionary = enemy(center + Vector2(0, 95), 4)
		warning.elite_warning = 0.8
		warning.charge = 0.0
		var charging: Dictionary = enemy(center + Vector2(0, -95), 4)
		charging.elite_warning = 0.0
		charging.charge = 0.4
		var ordinary: Dictionary = enemy(center + Vector2(90, 0))
		var warning_at: Vector2 = warning.pos
		var charge_at: Vector2 = charging.pos
		var ordinary_at: Vector2 = ordinary.pos
		if skill == "pulse":
			world._evolution.tick(world, 0.1)
		else:
			world._ability.tick(world, 0.1)
		verify(warning.pos == warning_at and charging.pos == charge_at, ("Compression" if skill == "pulse" else "Singularity") + " preserves committed elite warning and charge paths")
		verify(Vector2(ordinary.pos).distance_to(center) < ordinary_at.distance_to(center), ("Compression" if skill == "pulse" else "Singularity") + " still pulls ordinary enemies in the same field")


func _test_shop_and_sale() -> void:
	fresh("overdrive")
	world._loadout.weapons.brush = 2
	world._loadout.weapons.saw = 2
	world._loadout.mods.capacitor = 2
	world._loadout.mods.magnet = 2
	world._evolution.refresh(world)
	world._ability.activate(world)
	world.energy = 100.0
	world.debug_release()
	enemy(world.player_position + Vector2(180, 0))
	world._saw_timer = 0.0
	world._update_saws(0.0)
	settings.effects_enabled = true
	world.combat_feedback(world.player_position, 2.0, "blast")
	verify(not world._evolution.wells.is_empty() and not world._saws.is_empty() and world._ability.duration > 0.0, "The shop-transition fixture has actual active skill, saw and compression effects")
	world._complete_wave()
	verify(world.phase == "shop" and world._saws.is_empty() and world._evolution.wells.is_empty() and world._evolution.links.is_empty(), "Entering a real shop clears weapon and evolution combat effects")
	verify(world._ability.duration == 0.0 and world._feedback.rings.is_empty() and world.position == Vector2.ZERO, "Shop entry clears active duration, presentation feedback and world offset")
	var result: Dictionary = world.sell_weapon("saw")
	verify(bool(result.ok) and not world._loadout.has_evolution("steel_storm") and "steel_storm" not in world._evolution.known, "Selling Saw II through world disables Steel Storm immediately")
	world.start_next_wave()
	world._spawn_timer = 999.0
	enemy(world.player_position + Vector2(180, 0))
	world._saw_timer = 0.0
	world._update_saws(0.1)
	verify(world._saws.is_empty(), "The sold weapon cannot keep producing evolved attacks in the next wave")
	fresh()
	world._loadout.weapons.foam = 2
	world._loadout.weapons.arc = 2
	foam(Vector2(720, 320))
	foam(Vector2(900, 320))
	world._evolution.arc_hit(world, Vector2(720, 320))
	world._complete_wave()
	verify(world._evolution.links.is_empty(), "Shop entry also clears an actual live conduction network")
	result = world.sell_weapon("foam")
	world.start_next_wave()
	foam(Vector2(720, 320))
	foam(Vector2(900, 320))
	world._evolution.arc_hit(world, Vector2(720, 320))
	verify(bool(result.ok) and world._evolution.links.is_empty(), "Residual prepared foam cannot reactivate conduction after its required weapon is sold")


func _test_feedback() -> void:
	fresh()
	settings.effects_enabled = true
	var rng_before: int = world._rng.state
	for index: int in range(250):
		world.combat_feedback(world.player_position, 99.0, "boss")
		world._feedback.caption(world.player_position, "TEST", Color.WHITE)
		world._feedback.clock += 0.04
		world._feedback.trail(world.player_position, Vector2.RIGHT, Color.WHITE)
	verify(world._feedback.rings.size() <= 24 and world._feedback.debris.size() <= 96 and world._feedback.trails.size() <= 16 and world._feedback.captions.size() <= 10, "Repeated feedback requests keep all presentation collections bounded")
	verify(world._feedback.stop_time <= 0.055 and world._feedback.rumble <= 7.0 and world._feedback.recoil <= 7.0, "Extreme feedback input cannot exceed the 55 ms hold or bounded displacement")
	verify(world._rng.state == rng_before, "Presentation randomness cannot change gameplay RNG")
	var before: float = world.elapsed
	world._physics_process(0.01)
	verify(world.elapsed == before and world.position.length() > 0.0, "An enabled impact holds combat briefly and moves only the world node")
	world.set_paused(true)
	var offset: Vector2 = world.position
	var remaining: float = world._feedback.stop_time
	world._physics_process(2.0)
	verify(world.elapsed == before and world.position == offset and world._feedback.stop_time == remaining, "Pause freezes the impact hold and world offset without advancing combat")
	world.set_paused(false)
	settings.effects_enabled = false
	world._physics_process(0.1)
	verify(world.elapsed > before and world.position == Vector2.ZERO, "Disabling effects removes existing shake and does not hold combat time")
	world._feedback.reset()
	world.combat_feedback(world.player_position, 2.0, "blast")
	verify(not world._feedback.rings.is_empty() and world._feedback.debris.is_empty() and world._feedback.stop_time == 0.0 and world._feedback.rumble == 0.0, "Reduced effects retain a readable impact ring without debris, shake or hit stop")


func _test_terminal_resolution() -> void:
	fresh()
	settings.effects_enabled = true
	var before: int = outcomes.size()
	world._damage_player(10000.0, world.player_position + Vector2.RIGHT, "DAMAGE_CONTACT")
	verify(world.health == 0.0 and world._feedback.stop_time > 0.0, "Lethal damage prepares the real hit-stop regression condition")
	world._physics_process(0.001)
	verify(not world.active and world.phase == "finished" and outcomes.size() == before + 1 and not outcomes.back(), "Hit stop cannot defer lethal-damage resolution")
	world._physics_process(0.1)
	verify(outcomes.size() == before + 1, "A lethal impact still finishes only once")
	fresh()
	settings.effects_enabled = true
	world._spawn_boss()
	world._boss.spawn = 0.0
	before = outcomes.size()
	world._damage_enemy(world._boss, 100000.0, Vector2.ZERO, "blast")
	verify(world._boss_defeated and world._feedback.stop_time > 0.0, "Boss destruction prepares the real terminal hit-stop regression condition")
	world._physics_process(0.001)
	verify(not world.active and outcomes.size() == before + 1 and outcomes.back(), "Boss victory resolves despite its cinematic impact hold")
	fresh()
	settings.effects_enabled = true
	world._spawn_boss()
	world._boss.spawn = 0.0
	world._damage_enemy(world._boss, 100000.0, Vector2.ZERO, "blast")
	world._damage_player(100000.0, world.player_position + Vector2.RIGHT)
	before = outcomes.size()
	world._physics_process(0.001)
	verify(outcomes.size() == before + 1 and not outcomes.back(), "Simultaneous lethal player and boss impacts still resolve as defeat")


func _test_hud_isolation() -> void:
	var app: Control = load("res://scripts/ui/main.gd").new()
	root.add_child(app)
	app.set_process(false)
	app.world.set_physics_process(false)
	app.world.start_standard("yard", 9917, {"skill": "overdrive"})
	app.world._spawn_timer = 999.0
	settings.effects_enabled = true
	var hud_before: Transform2D = app.hud.get_global_transform_with_canvas()
	app.world.combat_feedback(app.world.player_position, 2.0, "blast")
	app.world._physics_process(0.01)
	verify(app.world.position.length() > 0.0 and app.hud.get_global_transform_with_canvas() == hud_before, "The actual app HUD transform stays stable while world feedback shakes")
	app.world.set_paused(true)
	var offset: Vector2 = app.world.position
	app.world._physics_process(2.0)
	verify(app.world.position == offset and app.hud.get_global_transform_with_canvas() == hud_before, "The actual paused HUD remains stable with a frozen impact offset")
	app.queue_free()
	await process_frame
	for suffix: String in ["", ".bak", ".tmp"]:
		var path: String = "user://profile-test-%d.json%s" % [OS.get_process_id(), suffix]
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
