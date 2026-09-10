extends RefCounted
## Evolved effects use the same damage/cover path and cannot recursively trigger.
var links: Array[Dictionary] = []
var wells: Array[Dictionary] = []
var known: Array[String] = []
var link_gate: float = 0.0


func clear() -> void:
	links.clear()
	wells.clear()
	link_gate = 0.0


func refresh(world: Node) -> void:
	var current: Array[String] = []
	for evo: Dictionary in world._loadout.get_evolutions():
		if bool(evo.active):
			current.append(str(evo.id))
			if str(evo.id) not in known:
				world.notify_ability_event(str(evo.name_key))
				world.sound_requested.emit("evolve")
	known = current


func arc_hit(world: Node, at: Vector2) -> void:
	if link_gate > 0.0 or not world._loadout.has_evolution("conduction_grid"):
		return
	var start: Vector2 = at
	for patch: Dictionary in world._foam:
		if Vector2(patch.pos).distance_to(at) <= float(patch.radius):
			start = patch.pos
			break
	for patch: Dictionary in world._foam:
		var finish: Vector2 = patch.pos
		if finish.distance_to(start) > 25.0 and finish.distance_to(start) < 390.0 and world._line_clear(start, finish) and links.size() < 8:
			links.append({"from": start, "to": finish, "life": 1.2, "tick": 0.0})
	link_gate = 0.7


func discharge(world: Node, power: float) -> void:
	if power < 1.0 or wells.size() >= 3 or not world._loadout.has_evolution("compression_blast"):
		return
	var target: Vector2 = world._move_body(world.player_position, Vector2(world.player_aim) * 180.0, 8.0)
	wells.append({"pos": target, "life": 0.85, "power": power})


func tick(world: Node, delta: float) -> void:
	link_gate = maxf(0.0, link_gate - delta)
	var hit_this_tick: Dictionary = {}
	for i: int in range(links.size() - 1, -1, -1):
		var link: Dictionary = links[i]
		link.life -= delta
		link.tick -= delta
		if link.life <= 0.0:
			links.remove_at(i)
			continue
		if link.tick > 0.0:
			continue
		link.tick = 0.25
		for enemy: Dictionary in world._enemies:
			if enemy.settled or enemy.spawn > 0 or hit_this_tick.has(enemy.id):
				continue
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(enemy.pos, link.from, link.to)
			if closest.distance_to(enemy.pos) <= 12.0 + float(enemy.radius) and world._line_clear(closest, enemy.pos):
				hit_this_tick[enemy.id] = true
				world._damage_enemy(enemy, 12.0, Vector2.ZERO, "evolution")
	for i: int in range(wells.size() - 1, -1, -1):
		var well: Dictionary = wells[i]
		well.life -= delta
		for enemy: Dictionary in world._enemies:
			if enemy.settled or enemy.spawn > 0 or Vector2(enemy.pos).distance_to(well.pos) > 170.0 or not world._line_clear(enemy.pos, well.pos):
				continue
			if well.life <= 0.0:
				world._damage_enemy(enemy, 70.0 * float(well.power), (Vector2(enemy.pos) - Vector2(well.pos)).normalized() * 400.0, "evolution")
			elif int(enemy.kind) != 3 and not (int(enemy.kind) == 4 and (float(enemy.get("charge", 0.0)) > 0.0 or float(enemy.get("elite_warning", 0.0)) > 0.0)):
				var motion: Vector2 = Vector2(well.pos) - Vector2(enemy.pos)
				enemy.pos = world._move_body(enemy.pos, motion.limit_length(220.0 * delta), float(enemy.radius))
		if well.life <= 0.0:
			world.combat_feedback(well.pos, 1.25, "evolution")
			world.sound_requested.emit("singularity_burst")
			if world.standard_mode:
				world._director.hit_targets(world, well.pos, 170.0, 70.0 * float(well.power))
			wells.remove_at(i)


func draw(world: Node2D) -> void:
	for link: Dictionary in links:
		var tint: Color = Color("58d9e7")
		var a: Vector2 = link.from
		var b: Vector2 = link.to
		var middle: Vector2 = a.lerp(b, 0.5) + (b - a).orthogonal().normalized() * sin(world._visual_time * 30.0) * 8.0
		if world._effects_enabled():
			world.draw_line(a, b, Color(tint, 0.16), 15.0, true)
		world.draw_polyline(PackedVector2Array([a, a.lerp(middle, 0.6), middle, middle.lerp(b, 0.5), b]), tint, 2.5, true)
		world.draw_circle(a, 6.0, Color("eefbff"))
		world.draw_circle(b, 6.0, Color("eefbff"))
	for well: Dictionary in wells:
		var progress: float = 1.0 - float(well.life) / 0.85
		world.draw_arc(well.pos, 170.0, 0, TAU, 64, Color("58d9e755"), 1.5, true)
		for i: int in range(3):
			var radius: float = 25.0 + fposmod(1.0 - progress + i / 3.0, 1.0) * 125.0
			world.draw_arc(well.pos, radius, progress * 4.0, progress * 4.0 + PI * 1.6, 48, Color("a5f9f2"), 2.0, true)
