extends SceneTree
## Isolated world ownership/targeting checks, not balance or human play evidence.
const World = preload("res://scripts/game/game_world.gd")
var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for action: String in ["move_left", "move_right", "move_up", "move_down", "vacuum", "dash", "active_skill"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	var world: Node2D = World.new()
	root.add_child(world)
	world.set_physics_process(false)
	for id: String in ["yard", "foundry", "reactor"]:
		world.start_endless(id, 51001)
		world.energy = 7.0
		world._ability.charge = 4.0
		world._spawn_boss()
		_check(world.energy == 100.0 and world._ability.charge == 100.0, id + " boss entry provides one stored blast and a ready active skill")
		world.energy = 0.0
		world._ability.charge = 0.0
		var enemies_before: int = world._enemies.size()
		world._spawn_boss()
		_check(world.energy == 0.0 and world._ability.charge == 0.0 and world._enemies.size() == enemies_before, id + " repeated boss setup cannot farm the entry supply")
		var cash: int = world.currency
		var pickups: int = world.total_scrap
		var hp: float = world.health
		world._overtime.boons["salvager"] = 5
		world.boss_supply(35, 12)
		_check(world.energy == 35 and world._ability.charge == 12 and world.currency == cash and world.total_scrap == pickups and world.health == hp, id + " supply changes only combat energy and charge")
		world.boss_supply(NAN, 20)
		world.boss_supply(20, INF)
		world.boss_supply(-1, 20, true)
		_check(world.energy == 35 and world._ability.charge == 12, id + " invalid supply is rejected atomically")
		world.paused = true
		world.boss_supply(35, 12, true)
		world.paused = false
		world.phase = "shop"
		world.boss_supply(35, 12, true)
		world.phase = "combat"
		world.health = 0.0
		world.boss_supply(35, 12, true)
		world.health = hp
		_check(world.energy == 35 and world._ability.charge == 12, id + " pause shop and death cannot gain supply or revive")
		world._boss.settled = true
		world.boss_supply(35, 12, true)
		world._boss.settled = false
		_check(world.energy == 35 and world._ability.charge == 12, id + " settled boss cannot generate more supply")
		world.boss_supply(10000, 10000)
		_check(world.energy == world._max_energy() and world._ability.charge == 100, id + " supply respects separate capacities")
		_battery(world, id)
		_contact(world, id)
		_focus(world, id)
	world.start_standard("yard", 51002)
	world._modifiers.energy_scale = 1.5
	world.energy = 135.0
	world._spawn_boss()
	_check(world.energy == 135, "entry preserves stored overcharge")
	world.energy = 0.0
	world.boss_supply(0, 30, true)
	_check(world.energy == 150, "earned core break fills upgraded capacity")
	for i: int in range(50):
		world._feedback.recover(Vector2(100, 200), Color.WHITE)
	_check(world._feedback.recoveries.size() == 10, "supply visual ribbons remain bounded")
	world.start_run(51003)
	_check(world._feedback.recoveries.is_empty() and world._boss_supply_energy == 0, "new run clears supply visuals and boss-only metrics")
	world.boss_supply(100, 100, true)
	_check(world.energy == 0, "boss supply never spills into quick mode")
	await _hud()
	print("BOSS_WORLD_B ", JSON.stringify({"checks": checks, "failures": failures}))
	world.queue_free()
	await root.get_node("SoundBank").shutdown()
	await process_frame
	quit(0 if failures.is_empty() else 1)


func _battery(world: Node2D, id: String) -> void:
	world.energy = 0.0
	world._ability.charge = 0.0
	world.debug_spawn_enemy(Vector2(150, 180), 0)
	var battery: Dictionary = world._enemies.back()
	battery.boss_battery = true
	battery.boss_add = true
	var cash: int = world.currency
	var scrap: int = world._scraps.size()
	world._damage_enemy(battery, 10000, Vector2.ZERO, "brush")
	world._damage_enemy(battery, 10000, Vector2.ZERO, "brush")
	_check(world.energy == 35 and world._ability.charge == 12 and world._boss_batteries_destroyed == 1, id + " battery death returns supply once immediately")
	_check(world.currency == cash and world._scraps.size() == scrap, id + " battery death cannot create ordinary money pickups")
	world._prune_enemies()


func _contact(world: Node2D, id: String) -> void:
	world._boss.spawn = 0.0
	world._boss.pos = Vector2(640, 390)
	world.player_position = world._boss.pos
	world._boss.state = "exposed"
	world._boss.countered = true
	world._boss.state_timer = 6.0
	world._invulnerability = 0.0
	var hp: float = world.health
	world._update_enemies(0.01)
	_check(world.health == hp, id + " exposed boss body is safe for close-range counterattacks")
	world.debug_spawn_enemy(world.player_position, 2)
	var add: Dictionary = world._enemies.back()
	add.spawn = 0.0
	add.boss_add = true
	add.boss_stun = 2.0
	add.shot_warning = 0.001
	add.shot_dir = Vector2.DOWN
	var before: Vector2 = add.pos
	var bullets: int = world._projectiles.size()
	world._update_enemies(0.5)
	_check(world.health == hp and add.pos == before and world._projectiles.size() == bullets and add.shot_warning == 0.001, id + " stunned support cannot move fire or deal contact damage")
	_check(is_equal_approx(float(add.boss_stun), 1.5), id + " stun has a finite countdown")
	world._boss.state = "hunt"
	world._boss.state_timer = 2.0
	world._update_enemies(0.01)
	_check(world.health < hp, id + " body contact damage returns when the break ends")
	add.settled = true
	world._prune_enemies()


func _focus(world: Node2D, id: String) -> void:
	world.player_position = Vector2(640, 390)
	world.player_aim = Vector2.RIGHT
	world._boss.pos = Vector2(840, 390)
	world.debug_spawn_enemy(Vector2(700, 390), 0)
	var nearby: Dictionary = world._enemies.back()
	nearby.spawn = 0.0
	_check(world._nearest_target(world.player_position, 300).id == world._boss.id, id + " aiming at boss prioritizes it over nearby support")
	_check(world._nearest_target(world.player_position, 100).id == nearby.id, id + " focus never extends the tool range")
	world.player_aim = Vector2.LEFT
	_check(world._nearest_target(world.player_position, 300).id == nearby.id, id + " looking away restores ordinary nearby targeting")
	world.player_aim = Vector2.RIGHT
	var excluded: Array[int] = [int(world._boss.id)]
	_check(world._nearest_target(world.player_position, 300, excluded).id == nearby.id, id + " chain exclusions prevent a second boss hit")
	world._boss.pos = Vector2(320, 264)
	world.player_position = Vector2(205, 264)
	world._obstacles.append(Rect2(237, 236, 70, 56))
	_check(not world._boss_in_aim(), id + " solid cover blocks a focus lock")


func _hud() -> void:
	var app: Control = load("res://scripts/ui/main.gd").new()
	root.add_child(app)
	app.set_process(false)
	app.world.set_physics_process(false)
	app.last_run_demo = true
	app.last_run_standard = true
	app.world.start_standard("reactor", 51004)
	app.world._spawn_boss()
	app.world._director.encounters._break_boss(app.world)
	for locale: String in ["en", "zh_CN"]:
		TranslationServer.set_locale(locale)
		app._update_hud(app.world.get_stats())
		_check(app.boss_window_bar.visible and app.boss_window_bar.value == 100 and "6.0" in app.boss_label.text, locale + " HUD shows the actual six-second core opening")
		_check(not "BOSS_" in app.boss_label.text and not "BOSS_" in app.notice_label.text, locale + " boss supply and timer texts are translated")
		var font: Font = app.boss_label.get_theme_font("font")
		_check(font.get_string_size(app.boss_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, app.boss_label.get_theme_font_size("font_size")).x <= app.boss_label.size.x, locale + " exposed label fits the boss panel")
	app.world._boss.state = "hunt"
	app._update_hud(app.world.get_stats())
	_check(not app.boss_window_bar.visible, "core countdown hides outside the opening")
	app.queue_free()
	await process_frame


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)
