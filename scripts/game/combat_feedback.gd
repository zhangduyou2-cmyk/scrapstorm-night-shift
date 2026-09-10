extends RefCounted
## Presentation RNG and bounded effects never generate loot or combat damage.
var rings: Array[Dictionary] = []
var debris: Array[Dictionary] = []
var trails: Array[Dictionary] = []
var captions: Array[Dictionary] = []
var recoveries: Array[Dictionary] = []
var rumble: float = 0.0
var stop_time: float = 0.0
var stop_gate: float = 0.0
var clock: float = 0.0
var trail_clock: float = 0.0
var recoil: float = 0.0
var offset: Vector2 = Vector2.ZERO
var rng := RandomNumberGenerator.new()


func reset() -> void:
	rings.clear()
	debris.clear()
	trails.clear()
	captions.clear()
	recoveries.clear()
	rumble = 0.0
	stop_time = 0.0
	stop_gate = 0.0
	clock = 0.0
	trail_clock = 0.0
	recoil = 0.0
	offset = Vector2.ZERO
	rng.seed = 99401


func burst(at: Vector2, strength: float, kind: String, tint: Color, enabled: bool) -> void:
	var power: float = clampf(strength, 0.0, 2.5)
	if rings.size() < 24:
		rings.append({"pos": at, "life": 0.48 if kind != "boss" else 1.1, "max": 0.48 if kind != "boss" else 1.1, "power": power, "color": tint, "kind": kind})
	if enabled:
		rumble = minf(7.0, maxf(rumble, power * 4.0))
		recoil = minf(7.0, power * 5.0)
		if power >= 0.65 and stop_gate <= 0.0:
			stop_time = minf(0.055, power * 0.025)
			stop_gate = 0.16
		for i: int in range(mini(10 + int(power * 7), 96 - debris.size())):
			var velocity: Vector2 = Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(80.0, 250.0) * maxf(power, 0.35)
			debris.append({"pos": at, "velocity": velocity, "life": rng.randf_range(0.25, 0.7), "angle": rng.randf_range(0, TAU), "size": rng.randf_range(2, 6), "color": tint if i % 3 == 0 else Color("bac3bd")})


func tick(delta: float, enabled: bool) -> bool:
	clock += delta
	stop_gate = maxf(0.0, stop_gate - delta)
	var stopped: bool = enabled and stop_time > 0.0
	stop_time = maxf(0.0, stop_time - delta)
	rumble = maxf(0.0, rumble - delta * 28.0)
	recoil = maxf(0.0, recoil - delta * 42.0)
	offset = Vector2(sin(clock * 137.0), cos(clock * 163.0)) * rumble if enabled else Vector2.ZERO
	for collection: Array in [rings, debris, trails, captions, recoveries]:
		for i: int in range(collection.size() - 1, -1, -1):
			collection[i].life = float(collection[i].life) - delta
			if float(collection[i].life) <= 0.0:
				collection.remove_at(i)
	for bit: Dictionary in debris:
		bit.pos += Vector2(bit.velocity) * delta
		bit.velocity = Vector2(bit.velocity).move_toward(Vector2.ZERO, delta * 240.0)
		bit.angle += delta * 12.0
	return stopped


func trail(at: Vector2, aim: Vector2, tint: Color) -> void:
	if trails.size() < 16 and clock >= trail_clock:
		trail_clock = clock + 0.035
		trails.append({"pos": at, "angle": aim.angle(), "color": tint, "life": 0.24})


func caption(at: Vector2, text: String, tint: Color) -> void:
	if captions.size() >= 10:
		captions.pop_front()
	captions.append({"pos": at, "text": text, "color": tint, "life": 0.8})


func recover(at: Vector2, tint: Color) -> void:
	# Energy is credited immediately; these bounded ribbons are presentation only.
	if recoveries.size() >= 10:
		recoveries.pop_front()
	recoveries.append({"pos": at, "color": tint, "life": 0.65})


func draw(world: Node2D) -> void:
	for recovery: Dictionary in recoveries:
		var progress: float = 1.0 - float(recovery.life) / 0.65
		var destination: Vector2 = world.player_position
		var origin: Vector2 = recovery.pos
		var side: Vector2 = (destination - origin).normalized().orthogonal()
		for strand: int in range(3 if world._effects_enabled() else 1):
			var curve: float = float(strand - 1) * 48.0
			var points := PackedVector2Array()
			for step: int in range(8):
				var t: float = clampf(progress - float(step) * 0.025, 0.0, 1.0)
				points.append(origin.lerp(destination, t) + side * sin(t * PI) * curve)
			world.draw_polyline(points, Color(recovery.color, minf(1.0, float(recovery.life) * 6.0)), 2.5, true)
		world.draw_circle(origin.lerp(destination, progress), 4.0, Color("f1ffe7"))
	for ghost: Dictionary in trails:
		var tint := Color(ghost.color, float(ghost.life) / 0.24 * 0.28)
		world.draw_circle(ghost.pos, 23.0, tint)
		world.draw_arc(ghost.pos, 29, float(ghost.angle) + 1.0, float(ghost.angle) + 5.1, 22, tint, 3.0, true)
	for ring: Dictionary in rings:
		var progress: float = 1.0 - float(ring.life) / float(ring.max)
		var radius: float = lerpf(8.0, 45.0 + float(ring.power) * (140.0 if ring.kind == "boss" else 60.0), 1.0 - pow(1.0 - progress, 2.0))
		var tint := Color(ring.color, (1.0 - progress) * 0.8)
		world.draw_arc(ring.pos, radius, 0, TAU, 60, tint, maxf(1.0, 5.0 * (1.0 - progress)), true)
		if world._effects_enabled():
			world.draw_arc(ring.pos, radius * 0.75, 0, TAU, 60, Color(tint, tint.a * 0.4), 8.0, true)
			for i: int in range(8):
				var direction := Vector2.from_angle(i * TAU / 8.0)
				world.draw_line(Vector2(ring.pos) + direction * radius, Vector2(ring.pos) + direction * (radius + 13.0 * (1.0 - progress)), tint, 2.0, true)
	for bit: Dictionary in debris:
		var direction := Vector2.from_angle(float(bit.angle)) * float(bit.size)
		world.draw_line(Vector2(bit.pos) - direction, Vector2(bit.pos) + direction, Color(bit.color, minf(1.0, float(bit.life) * 3.0)), 2.0, true)
	for message: Dictionary in captions:
		var font: Font = ThemeDB.fallback_font
		world.draw_string(font, Vector2(message.pos) + Vector2(-28, -28 - (0.8 - float(message.life)) * 24), str(message.text), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(message.color, minf(1.0, float(message.life) * 3.0)))
