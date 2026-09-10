extends RefCounted
## Map-specific attack decisions. A committed attack never silently retargets.
const EXPOSE_SECONDS: float = 6.0

func configure(world: Node2D, enemy: Dictionary) -> void:
	var map: Dictionary = world._map_data
	enemy.merge({"hp": float(map.boss_health), "max_hp": float(map.boss_health), "state": "hunt", "state_timer": 1.5, "phase_key": "BOSS_HUNT", "stage": 1, "attack": 0, "last_attack": "", "move": "", "charge_end": Vector2(enemy.pos), "charge_start": Vector2(enemy.pos), "charge_speed": 600.0, "repeat_charge": false, "volley_timer": 0.0, "sweep_angle": 0.0, "attack_time": 0.0,
		"map_id": world.map_id, "countered": false, "pressure": 0.0, "pressure_timer": 7.0, "stage_seen": 1}, true)
	# The foundry's northern machine occupies the legacy spawn position.
	enemy.pos = world._move_body(Vector2(640, 250), Vector2.ZERO, float(enemy.radius))
	world._director.setup_boss(world)


func damage_multiplier(world: Node2D, enemy: Dictionary, source: String) -> float:
	if str(enemy.get("state", "")) == "exposed" and bool(enemy.get("countered", false)):
		return 1.85 if source == "blast" else (1.50 if source.begins_with("ability") else 1.65)
	if world.map_id == "reactor":
		return 0.45
	if world.map_id == "foundry":
		return 0.50
	return 0.55


func tick(world: Node2D, enemy: Dictionary, direction: Vector2, delta: float) -> Vector2:
	var enraged: bool = float(enemy.hp) <= float(enemy.max_hp) * 0.5
	enemy.stage = 2 if enraged else 1
	enemy.pressure = float(enemy.get("pressure", 0.0)) + delta
	enemy.pressure_timer = float(enemy.get("pressure_timer", 7.0)) - delta
	if int(enemy.get("stage_seen", 1)) < int(enemy.stage):
		enemy.stage_seen = int(enemy.stage)
		world.sound_requested.emit("boss_charge")
		world._spawn_particles(Vector2(enemy.pos), Color("ff9971"), 24, 90, 280)
	if float(enemy.pressure_timer) <= 0 and str(enemy.state) not in ["exposed", "vent_window"]:
		enemy.pressure_timer = maxf(4.8, (6.5 if enraged else 9.0) - minf(2.0, float(enemy.pressure) / 60.0))
		# A fresh, stationary marker forces distant orbiting builds to change
		# route; it never follows the player after the warning is committed.
		world._director.circle_hazard(world.player_position, 64.0 if enraged else 55.0, 1.4, 1.0, 18.0, "DAMAGE_PURSUIT")
	enemy.state_timer = float(enemy.state_timer) - delta
	var state: String = str(enemy.state)
	var expired: bool = float(enemy.state_timer) <= 0.0
	if state in ["aim", "windup", "charge"]:
		# Recoil cannot push a committed charge outside its visible corridor.
		enemy.knock = Vector2.ZERO
	if state == "hunt":
		if expired:
			_select(world, enemy, direction, enraged)
			return Vector2.ZERO
		if world.map_id == "reactor":
			return direction * 68.0 + direction.orthogonal() * (48.0 if int(enemy.attack) % 2 else -48.0)
		return direction * (140.0 if enraged else 112.0)
	if state == "aim":
		_preview_charge(world, enemy)
		if expired:
			if Vector2(enemy.charge_start).distance_to(Vector2(enemy.charge_end)) < 90.0:
				enemy.repeat_charge = false
				_begin_zone(world, enemy, enraged)
			else:
				enemy.state = "windup"
				enemy.phase_key = "BOSS_AIM_LOCKED"
				enemy.state_timer = float(enemy.get("lock_duration", 0.42))
				world.sound_requested.emit("warning")
		return Vector2.ZERO
	if state == "windup":
		if expired:
			enemy.state = "charge"
			enemy.phase_key = "BOSS_CHARGE"
			enemy.state_timer = Vector2(enemy.charge_start).distance_to(Vector2(enemy.charge_end)) / float(enemy.charge_speed)
		return Vector2.ZERO
	if state == "charge":
		if expired or Vector2(enemy.pos).distance_to(Vector2(enemy.charge_end)) < 12.0:
			if bool(enemy.repeat_charge):
				enemy.repeat_charge = false
				_begin_charge(world, enemy, (world.player_position - Vector2(enemy.pos)).normalized(), 0.75)
			else:
				_recover(enemy)
			return Vector2.ZERO
		return Vector2(enemy.charge_dir) * minf(float(enemy.charge_speed), Vector2(enemy.pos).distance_to(Vector2(enemy.charge_end)) / maxf(delta, 0.0001))
	if state == "sweep_warning" or state == "ring_warning":
		if expired:
			enemy.state = "sweep" if state == "sweep_warning" else "ring"
			enemy.phase_key = "BOSS_VOLLEY"
			enemy.state_timer = 1.65 if state == "sweep_warning" else 1.0
			enemy.attack_time = 0.0
			enemy.volley_timer = 0.0
		return Vector2.ZERO
	if state == "sweep":
		enemy.attack_time = float(enemy.attack_time) + delta
		enemy.volley_timer = float(enemy.volley_timer) - delta
		if float(enemy.volley_timer) <= 0.0:
			enemy.volley_timer = 0.27 if enraged else 0.34
			var center: float = float(enemy.sweep_angle) - 0.62 + clampf(float(enemy.attack_time) / 1.65, 0, 1) * 1.24
			var count: int = 5 if world.map_id == "foundry" else 3
			for index: int in range(count):
				var angle: float = center + (float(index) - float(count - 1) / 2.0) * 0.20
				world._fire_projectile(Vector2(enemy.pos), Vector2.from_angle(angle) * (265.0 if enraged else 230.0), 13.0, true)
		if expired:
			_recover(enemy)
		return Vector2.ZERO
	if state == "ring":
		enemy.volley_timer = float(enemy.volley_timer) - delta
		if float(enemy.volley_timer) <= 0.0:
			enemy.volley_timer = 0.46
			# The warning commits one safe bearing for the complete burst. Moving
			# it between volleys would hit players following the unchanged marker.
			var gap: float = float(enemy.sweep_angle)
			for index: int in range(20):
				var angle: float = gap + float(index) * TAU / 20.0
				if index <= 1 or index >= 19:
					continue
				world._fire_projectile(Vector2(enemy.pos), Vector2.from_angle(angle) * (220.0 if enraged else 195.0), 12.0, true)
			enemy.attack_time = float(enemy.attack_time) + 1.0
		if expired:
			_recover(enemy)
		return Vector2.ZERO
	if state == "zone":
		if expired:
			if enraged:
				_begin_sweep(enemy, direction, world.map_id == "reactor")
			else:
				_recover(enemy)
		return Vector2.ZERO
	if state == "vent_window":
		if expired:
			enemy.state = "hunt"
			enemy.phase_key = "BOSS_HUNT"
			enemy.state_timer = 0.35
		return Vector2.ZERO
	if expired:
		enemy.countered = false
		enemy.state = "hunt"
		enemy.phase_key = "BOSS_HUNT"
		enemy.state_timer = 0.30 if enraged else 0.50
	return Vector2.ZERO


func _select(world: Node2D, enemy: Dictionary, direction: Vector2, enraged: bool) -> void:
	enemy.attack = int(enemy.attack) + 1
	var distance: float = Vector2(enemy.pos).distance_to(world.player_position)
	var attack: String = "charge" if distance > 280.0 else "sweep"
	if distance < 130.0:
		attack = "zone"
	elif int(enemy.attack) % 3 == 0:
		attack = "zone"
	if attack == str(enemy.last_attack):
		attack = "sweep" if attack == "charge" else "charge"
	if world.map_id == "foundry" and int(enemy.attack) % 2 == 0:
		attack = "zone"
	elif world.map_id == "foundry" and distance > 190.0:
		# Conveyor-crossing charges pressure midrange orbits as well as players
		# far away; committed warning and collision prediction remain identical.
		attack = "charge"
	if world.map_id == "reactor":
		attack = "zone" if int(enemy.attack) % 3 == 0 else "ring"
		if distance < 145.0:
			attack = "zone"
	enemy.last_attack = attack
	enemy.move = attack
	if attack == "charge":
		enemy.repeat_charge = enraged and world.map_id == "yard"
		_begin_charge(world, enemy, direction, 1.05 if not enraged else 0.9)
	elif attack == "sweep" or attack == "ring":
		_begin_sweep(enemy, direction, attack == "ring")
		world.sound_requested.emit("warning")
	else:
		_begin_zone(world, enemy, enraged)
	if enraged and world.map_id == "yard" and attack == "sweep":
		world._director.circle_hazard(world.player_position, 65.0, 1.5, 1.0, 16.0, "DAMAGE_COMPRESSION")


func _begin_charge(world: Node2D, enemy: Dictionary, direction: Vector2, warning: float) -> void:
	world.sound_requested.emit("boss_charge")
	enemy.state = "aim"
	enemy.lock_duration = 0.42
	enemy.state_timer = clampf(warning - 0.42, 0.30, 0.65)
	enemy.phase_key = "BOSS_AIM_TRACK"
	enemy.charge_dir = direction
	enemy.charge_start = Vector2(enemy.pos)
	enemy.charge_speed = 670.0 if int(enemy.stage) == 1 else 750.0
	_preview_charge(world, enemy)


func _preview_charge(world: Node2D, enemy: Dictionary) -> void:
	# Only the dotted tracking phase predicts motion. A solid lock never tracks.
	var travel: float = Vector2(enemy.pos).distance_to(world.player_position) / float(enemy.charge_speed)
	var velocity: Vector2 = Vector2(world._player_velocity).limit_length(285.0)
	var prediction: Vector2 = world.player_position + velocity * clampf(float(enemy.lock_duration) + travel, 0.42, 0.90)
	var direction: Vector2 = (prediction - Vector2(enemy.pos)).normalized()
	if direction.length_squared() < 0.1:
		direction = Vector2.DOWN
	enemy.charge_dir = direction
	enemy.charge_start = Vector2(enemy.pos)
	var distance: float = clampf(Vector2(enemy.pos).distance_to(prediction) + 240.0, 400.0, 820.0)
	# Collision preview uses the same movement resolver and path as the real charge.
	var end: Vector2 = Vector2(enemy.pos)
	var remaining: float = distance
	while remaining > 0.0:
		var step: float = minf(5.0, remaining)
		var next: Vector2 = world._move_body(end, direction * step, float(enemy.radius))
		if next.distance_to(end + direction * step) > 0.8:
			break
		end = next
		remaining -= step
	enemy.charge_end = end


func _begin_sweep(enemy: Dictionary, direction: Vector2, ring: bool) -> void:
	enemy.state = "ring_warning" if ring else "sweep_warning"
	enemy.state_timer = 1.1
	enemy.phase_key = "BOSS_RING" if ring else "BOSS_SWEEP"
	enemy.charge_dir = direction
	# Reactor safe gaps are marked beside the player's current bearing, asking
	# for a deliberate move instead of granting an automatic stand-still refuge.
	enemy.sweep_angle = direction.angle() + ((1.15 if int(enemy.attack) % 2 else -1.15) if ring else 0.0)


func _begin_zone(world: Node2D, enemy: Dictionary, enraged: bool) -> void:
	world.sound_requested.emit("warning")
	enemy.state = "zone"
	enemy.phase_key = "BOSS_ZONE"
	enemy.state_timer = 1.9
	var target: Vector2 = world.player_position
	if world.map_id == "foundry":
		world._director.circle_hazard(target, 72.0, 1.25, 3.0, 15.0, "DAMAGE_MOLTEN")
		var other: Vector2 = Vector2(960.0 if target.x < 640 else 320.0, 340.0 if target.y > 390 else 445.0)
		world._director.circle_hazard(other, 68.0, 1.5, 3.0, 15.0, "DAMAGE_MOLTEN")
	elif world.map_id == "reactor":
		var vertical: bool = int(enemy.attack) % 2 == 0
		var rect: Rect2 = Rect2(clampf(target.x - 36, 60, 1148), 136, 72, 508) if vertical else Rect2(60, clampf(target.y - 34, 140, 570), 1160, 68)
		world._director.rect_hazard(rect, 1.35, 3.0 if enraged else 1.2, 16.0, "DAMAGE_SCAN")
		if enraged:
			world._director.circle_hazard(Vector2(enemy.pos), 100.0, 1.5, 0.7, 15.0, "DAMAGE_SHOCK")
	else:
		world._director.circle_hazard(target, 88.0, 1.35, 1.2, 17.0, "DAMAGE_COMPRESSION")
		if enraged:
			world._director.circle_hazard(Vector2(enemy.pos), 95.0, 1.6, 0.8, 15.0, "DAMAGE_SHOCK")


func _expose(enemy: Dictionary, duration: float) -> void:
	enemy.state = "exposed"
	enemy.state_timer = duration
	enemy.phase_key = "BOSS_EXPOSED"


func _recover(enemy: Dictionary) -> void:
	# Ordinary recovery is short and armored. Long exposed cores are earned
	# through the visible map counter, rather than awarded after every attack.
	var vent: bool = str(enemy.get("map_id", "")) == "foundry"
	enemy.state = "vent_window" if vent else "recover"
	enemy.state_timer = 3.6 if vent else 0.65
	enemy.phase_key = "BOSS_VENT_OPEN" if vent else "BOSS_ARMORED"


func draw(world: Node2D, enemy: Dictionary) -> void:
	var pos: Vector2 = enemy.pos
	var state: String = str(enemy.state)
	var aim: Vector2 = Vector2(enemy.charge_dir) if state in ["aim", "windup", "charge", "sweep_warning", "sweep", "ring_warning", "ring"] else (world.player_position - pos).normalized()
	if state == "aim":
		var end: Vector2 = enemy.charge_end
		world.draw_dashed_line(pos, end, Color("ffcc6477"), 2.0, 14.0, true)
		world.draw_arc(world.player_position, 28.0, world._visual_time * 3.0, world._visual_time * 3.0 + PI * 1.6, 24, Color("ffd989"), 2.0, true)
	if state in ["windup", "charge"]:
		var end: Vector2 = enemy.charge_end
		var normal: Vector2 = aim.orthogonal() * float(enemy.radius)
		world.draw_colored_polygon(PackedVector2Array([pos - normal, pos + normal, end + normal, end - normal]), Color(1.0, 0.49, 0.18, 0.18))
		world.draw_line(pos + normal, end + normal, Color("ffbf60"), 2.0, true)
		world.draw_line(pos - normal, end - normal, Color("ffbf60"), 2.0, true)
		world.draw_arc(end, float(enemy.radius), aim.angle() - PI / 2, aim.angle() + PI / 2, 30, Color("ffbf60"), 2.0, true)
	if state in ["sweep_warning", "sweep"]:
		var center: float = float(enemy.sweep_angle)
		world.draw_arc(pos, 120.0, center - 1.1, center + 1.1, 40, Color("ffb557"), 3.0, true)
		for side: float in [-1.1, 1.1]:
			world.draw_line(pos + Vector2.from_angle(center + side) * 57, pos + Vector2.from_angle(center + side) * 220, Color(1.0, 0.6, 0.2, 0.4), 2.0, true)
	if state in ["ring_warning", "ring"]:
		var gap: float = float(enemy.sweep_angle)
		world.draw_arc(pos, 95.0, gap + 0.48, gap + TAU - 0.48, 55, Color("ffb557"), 3.0, true)
		world.draw_line(pos + Vector2.from_angle(gap) * 62, pos + Vector2.from_angle(gap) * 122, Color("93e9bf"), 5.0, true)
	world.draw_circle(pos + Vector2(3, 7), 50.0, Color(0, 0, 0, 0.30))
	if state != "exposed":
		for segment: int in range(6):
			var start: float = float(segment) * TAU / 6.0 + world._visual_time * 0.15
			world.draw_arc(pos, 59.0, start, start + 0.72, 12, Color(0.63, 0.78, 0.98, 0.65), 4.0, true)
	else:
		world.draw_arc(pos, 62.0, -PI / 2, -PI / 2 + TAU * clampf(float(enemy.state_timer) / EXPOSE_SECONDS, 0, 1), 64, Color("8ffff0"), 4.0, true)
	world.draw_set_transform(pos, aim.angle())
	var exposed: bool = state == "exposed"
	var glow: Color = Color("a2ffd0") if exposed else Color("ff674a")
	var body: Color = Color("e6e7d4") if float(enemy.flash) > 0.0 and world._effects_enabled() else Color("647d82")
	if world.map_id == "yard":
		for y: float in [-31.0, 31.0]:
			world.draw_rect(Rect2(-44, y - 10, 80, 20), Color("101c24"))
			for index: int in range(8):
				world.draw_line(Vector2(-39 + index * 10, y - 7), Vector2(-39 + index * 10, y + 7), Color("708383"), 3)
		world.draw_rect(Rect2(-38, -26, 65, 52), body)
		world.draw_rect(Rect2(25, -38, 20, 76), Color("d7a653"))
		for y: int in range(-30, 36, 12):
			world.draw_line(Vector2(26, y), Vector2(44, y + 9), Color("18242a"), 4)
	elif world.map_id == "foundry":
		var hex: PackedVector2Array = PackedVector2Array()
		for index: int in range(6):
			hex.append(Vector2.from_angle(float(index) * TAU / 6.0) * 47)
		world.draw_colored_polygon(hex, Color("ad7856"))
		world.draw_rect(Rect2(-24, -34, 48, 68), Color("342b2b"))
		for side: float in [-1.0, 1.0]:
			world.draw_rect(Rect2(-12, side * 43 - 9, 47, 18), Color("deaa63"))
		for y: int in range(-26, 30, 10):
			world.draw_line(Vector2(-17, y), Vector2(17, y), glow, 3.5)
	else:
		world.draw_circle(Vector2.ZERO, 43, Color("465881"))
		world.draw_arc(Vector2.ZERO, 50, world._visual_time, world._visual_time + TAU * 0.86, 52, Color("a2baff"), 4, true)
		for index: int in range(4):
			var offset: Vector2 = Vector2.from_angle(float(index) * TAU / 4.0 + world._visual_time * 0.4) * 40
			world.draw_rect(Rect2(offset - Vector2(8, 8), Vector2(16, 16)), Color("8da4e4"))
	if exposed:
		_draw_exposed_core(world, enemy)
	else:
		world.draw_circle(Vector2.ZERO, 20, Color("14212b"))
		world.draw_circle(Vector2.ZERO, 13, glow)
		world.draw_line(Vector2(-6, -7), Vector2(6, 7), Color("f4f2d8"), 3.0)
	if int(enemy.stage) == 2 and not exposed:
		world.draw_arc(Vector2.ZERO, 54, 0, TAU, 48, Color(1.0, 0.34, 0.27, 0.45), 2.0, true)
	world.draw_set_transform(Vector2.ZERO)


func _draw_exposed_core(world: Node2D, enemy: Dictionary) -> void:
	# All pieces stay within the existing 62px counter timer. This is a body
	# transformation, not an arena flash that could cover another telegraph.
	var effects: bool = world._effects_enabled()
	var opening: float = clampf((EXPOSE_SECONDS - float(enemy.state_timer)) / 0.30, 0.0, 1.0) if effects else 1.0
	opening = opening * opening * (3.0 - 2.0 * opening)
	var pulse: float = 0.5 + 0.5 * sin(world._visual_time * 5.0) if effects else 0.5
	var mint := Color("8ffff0")
	world.draw_circle(Vector2.ZERO, 32.0, Color("0b1821"))
	if world.map_id == "reactor":
		for i: int in range(4):
			var angle: float = i * TAU / 4.0 + PI / 4.0
			var radial: Vector2 = Vector2.from_angle(angle)
			var tangent: Vector2 = radial.orthogonal()
			var center: Vector2 = radial * (28.0 + opening * 15.0)
			var plate := PackedVector2Array([center - radial * 8.0 - tangent * 13.0, center + radial * 6.0 - tangent * 10.0, center + radial * 6.0 + tangent * 10.0, center - radial * 8.0 + tangent * 13.0])
			world.draw_line(radial * 18.0, center, Color("46787f"), 4.0)
			world.draw_colored_polygon(plate, Color("566fa1"))
			world.draw_polyline(plate + PackedVector2Array([plate[0]]), Color("b6caff"), 2.0, true)
	else:
		var steel: Color = Color("be9761") if world.map_id == "foundry" else Color("6b8b8c")
		for side: float in [-1.0, 1.0]:
			var y: float = side * (15.0 + opening * 18.0)
			var plate := PackedVector2Array([Vector2(-27, y - side * 6), Vector2(-30, y + side * 10), Vector2(20, y + side * 10), Vector2(26, y - side * 6)])
			world.draw_line(Vector2(-19, side * 13), Vector2(-19, y), Color("d3dfd9"), 3.0)
			world.draw_line(Vector2(15, side * 13), Vector2(15, y), Color("d3dfd9"), 3.0)
			world.draw_colored_polygon(plate, steel)
			world.draw_polyline(plate + PackedVector2Array([plate[0]]), Color("e5d4a3"), 2.0, true)
			for rib: int in range(3):
				world.draw_line(Vector2(-20 + rib * 13, y), Vector2(-15 + rib * 13, y + side * 6), Color("243238"), 3.0)
	world.draw_circle(Vector2.ZERO, 22.0 + pulse * 2.0, Color(mint, 0.13))
	world.draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 32, mint, 2.0, true)
	for i: int in range(4):
		var angle: float = i * TAU / 4.0 + (world._visual_time * 0.45 if effects else 0.0)
		world.draw_arc(Vector2.ZERO, 15.0 + pulse, angle, angle + 0.7, 8, Color("b5fff0"), 3.0, true)
	var core := PackedVector2Array([Vector2(-9, -7), Vector2(7, -9), Vector2(11, 6), Vector2(-5, 11)])
	world.draw_colored_polygon(core, mint)
	world.draw_line(Vector2(-4, -5), Vector2(5, 4), Color("f4fff0"), 3.0, true)
