extends SceneTree
## CPU/object-bound fixture, deliberately invulnerable. Not a balance or GPU test.
const World = preload("res://scripts/game/game_world.gd")
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for action: String in ["move_left", "move_right", "move_up", "move_down", "vacuum", "dash", "active_skill"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	var results: Array[Dictionary] = []
	for id: String in ["yard", "foundry", "reactor"]:
		var world: Node2D = World.new()
		root.add_child(world)
		world.set_physics_process(false)
		world.start_standard(id, 531)
		world.wave_index = 6
		world._spawn_boss()
		world._boss.hp = 100000000.0
		world._boss.max_hp = 250000000.0
		world._invulnerability = 10000.0
		world._loadout.weapons = {"brush": 3, "foam": 0, "arc": 3, "saw": 3}
		var peaks: Dictionary = {"enemies": 0, "scrap": 0, "projectiles": 0, "hazards": 0, "particles": 0, "saws": 0}
		var start: int = Time.get_ticks_usec()
		for tick: int in range(36000):
			world._physics_process(1.0 / 60.0)
			peaks.enemies = maxi(int(peaks.enemies), world._enemies.size())
			peaks.scrap = maxi(int(peaks.scrap), world._scraps.size())
			peaks.projectiles = maxi(int(peaks.projectiles), world._projectiles.size())
			peaks.hazards = maxi(int(peaks.hazards), world._director.hazards.size())
			peaks.particles = maxi(int(peaks.particles), world._particles.size())
			peaks.saws = maxi(int(peaks.saws), world._saws.size())
		var milliseconds: float = float(Time.get_ticks_usec() - start) / 1000.0
		var valid: bool = world.active and world.elapsed > 599.9 and peaks.enemies <= 100 and peaks.scrap <= 150 and peaks.projectiles <= 70 and peaks.hazards <= 18 and peaks.particles <= 240 and peaks.saws <= 18
		if not valid:
			failures.append(id)
		results.append({"map": id, "seconds_simulated": world.elapsed, "ticks": 36000, "mean_cpu_ms": milliseconds / 36000.0, "peaks": peaks, "bounded": valid})
		world.queue_free()
		await process_frame
	var report: Dictionary = {"method": "Each map: ten minutes of fixed 60Hz headless boss combat, fixture player invulnerability and enlarged boss health only to keep load running; not difficulty/GPU evidence.", "runs": results, "failures": failures}
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var output: FileAccess = FileAccess.open("res://artifacts/standard-stress.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	print("STANDARD_STRESS ", JSON.stringify(report))
	root.get_node("SoundBank").stop_all()
	await create_timer(0.15).timeout
	quit(0 if failures.is_empty() else 1)
