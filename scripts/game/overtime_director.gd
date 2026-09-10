extends RefCounted
## Deterministic expedition state. Only combat advances clocks; routes freeze at shops.
const MAPS: Array[String] = ["yard", "foundry", "reactor"]
const BOONS: Array[String] = ["power", "magnet", "capacitor", "salvager", "bulwark", "afterburn", "chain", "haste"]
const RISKS: Array[String] = ["hunters", "crossfire", "volatile", "armored", "overclock", "artillery"]
const PATTERNS: Array[String] = ["swarm", "harvest", "bounty", "relay"]
var room: int = 1
var completed: int = 0
var start_map: String = "yard"
var boons: Dictionary = {}
var routes: Array[Dictionary] = []
var risk: String = "hunters"
var risk_history: Array[String] = []
var choice: int = -1
var rng := RandomNumberGenerator.new()
var kills_start: int = 0
var scrap_start: int = 0
var relay_progress: float = 0.0
var relays: int = 0
var hazard_timer: float = 7.0
var chain_timer: float = 3.0
var shield: float = 0.0
var last_uses: int = 0
var last_dash: bool = false

func reset(map: String, seed_value: int) -> void:
	start_map = map if map in MAPS else "yard"
	room = 1
	completed = 0
	boons.clear()
	for id: String in BOONS:
		boons[id] = 0
	routes.clear()
	risk_history.clear()
	risk = "hunters"
	choice = -1
	rng.seed = seed_value ^ 0x5a7126

func cycle() -> int:
	return (room - 1) / 3 + 1

func map_id() -> String:
	return MAPS[(MAPS.find(start_map) + cycle() - 1) % MAPS.size()]

func boss_room() -> bool:
	return room % 3 == 0

func pattern() -> String:
	return "boss" if boss_room() else PATTERNS[((cycle() - 1) * 2 + (room - 1) % 3) % PATTERNS.size()]

func duration() -> float:
	return 0.0 if boss_room() else (65.0 if pattern() == "swarm" else 80.0)

func hp_scale() -> float:
	return (1.0 + float(room - 1) * 0.09 + float(maxi(0, cycle() - 4)) * 0.12) * (1.25 if risk == "armored" else 1.0)

func speed_scale() -> float:
	return minf(1.38, 1.0 + float(cycle() - 1) * 0.035) * (1.13 if risk == "overclock" else 1.0)

func damage_scale() -> float:
	return minf(2.4, 1.0 + float(cycle() - 1) * 0.075)

func rank(id: String) -> int:
	return int(boons.get(id, 0))

func modify(base: Dictionary) -> Dictionary:
	var result: Dictionary = base.duplicate(true)
	result.damage_scale *= 1.0 + rank("power") * 0.10
	result.vacuum_scale *= 1.0 + rank("magnet") * 0.08
	result.energy_scale *= 1.0 + rank("capacitor") * 0.10
	result.cooldown_scale *= 1.0 - rank("haste") * 0.045
	return result

func begin(world: Node2D) -> void:
	kills_start = world.kills
	scrap_start = world.total_scrap
	relay_progress = 0.0
	relays = 0
	hazard_timer = 7.0
	chain_timer = 3.0
	shield = 0.0
	last_uses = world._ability.uses
	last_dash = false
	if risk not in risk_history:
		risk_history.append(risk)

func finish_room() -> void:
	completed = room
	choice = -1
	routes.clear()
	var available: Array[String] = BOONS.duplicate()
	var risks: Array[String] = RISKS.duplicate()
	for index: int in range(3):
		var boon_index: int = rng.randi_range(0, available.size() - 1)
		var risk_index: int = rng.randi_range(0, risks.size() - 1)
		routes.append({"boon": available[boon_index], "risk": risks[risk_index], "rank": mini(5, rank(available[boon_index]) + 1), "supply": rank(available[boon_index]) >= 5})
		available.remove_at(boon_index)
		risks.remove_at(risk_index)

func choose(index: int, world: Node2D) -> bool:
	if world.phase != "shop" or completed != room or choice != -1 or index < 0 or index >= routes.size():
		return false
	choice = index
	var route: Dictionary = routes[index]
	risk = str(route.risk)
	if bool(route.supply):
		world.health = minf(world._max_health(), world.health + 35.0)
		world.currency += 45
		world._earned_currency += 45
	else:
		boons[route.boon] = mini(5, rank(str(route.boon)) + 1)
	world._refresh_modifiers()
	return true

func advance() -> bool:
	if choice < 0 or completed != room or room >= 1000000:
		return false
	room += 1
	routes.clear()
	choice = -1
	return true

func target() -> int:
	match pattern():
		"harvest": return 28 + mini(30, cycle() * 3)
		"bounty": return 32 + mini(36, cycle() * 4)
		"relay": return 3
	return 0

func progress(world: Node2D) -> int:
	match pattern():
		"harvest": return world.total_scrap - scrap_start
		"bounty": return world.kills - kills_start
		"relay": return relays
	return int(world.wave_elapsed)

func ready(world: Node2D) -> bool:
	if boss_room():
		return world._boss_defeated
	if world.wave_elapsed >= duration():
		return true
	return pattern() != "swarm" and world.wave_elapsed >= 40.0 and progress(world) >= target()

func relay_position() -> Vector2:
	return [Vector2(640, 218), Vector2(353, 395), Vector2(922, 537)][mini(relays, 2)]

func tick(world: Node2D, delta: float) -> void:
	shield = maxf(0.0, shield - delta)
	if world._ability.uses != last_uses:
		last_uses = world._ability.uses
		if rank("bulwark") > 0:
			shield = 1.5 + rank("bulwark") * 0.4
	var dashing: bool = world._dash_left > 0.0
	if dashing and not last_dash and rank("afterburn") > 0:
		world._foam.append({"pos": world.player_position, "life": 2.5 + rank("afterburn") * 0.4, "radius": 48.0 + rank("afterburn") * 7.0, "tick": 0.0, "damage": 5.0 + rank("afterburn") * 2.0})
		if world._foam.size() > int(world.balance.max_foam):
			world._foam.pop_front()
	last_dash = dashing
	chain_timer -= delta
	if rank("chain") > 0 and chain_timer <= 0.0:
		chain_timer = 3.6 - rank("chain") * 0.30
		var hits: int = 0
		for enemy: Dictionary in world._enemies:
			if not enemy.settled and float(enemy.spawn) <= 0 and world.player_position.distance_squared_to(enemy.pos) < 240.0 * 240.0 and world._line_clear(world.player_position, enemy.pos):
				world._damage_enemy(enemy, 8.0 + rank("chain") * 4.0, Vector2.ZERO, "overtime_chain")
				world._arcs.append({"from": world.player_position, "to": enemy.pos, "life": 0.18, "combo": true})
				hits += 1
				if hits >= 3:
					break
	if pattern() == "relay" and relays < 3:
		if world._vacuum and world.player_position.distance_to(relay_position()) < 68.0:
			relay_progress += delta
		else:
			relay_progress = maxf(0.0, relay_progress - delta * 0.3)
		if relay_progress >= 3.0:
			relays += 1
			relay_progress = 0.0
			world._collect_scrap(9)
			world.combat_feedback(world.player_position, 1.0, "break")
	hazard_timer -= delta
	if hazard_timer > 0.0:
		return
	hazard_timer = maxf(5.5, 11.0 - cycle() * 0.4)
	if risk == "artillery" or (cycle() >= 4 and room % 2 == 0):
		world._director.circle_hazard(world.player_position + world._player_velocity.limit_length(110.0) * 0.4, 66.0, 1.5, 0.55, 16.0, "DAMAGE_OVERTIME")
	if risk == "crossfire":
		var y: float = clampf(world.player_position.y, 165.0, 602.0)
		world._director.rect_hazard(Rect2(60, y - 18.0, 1160, 36), 1.65, 1.1, 13.0, "DAMAGE_OVERTIME")

func on_kill(world: Node2D, enemy: Dictionary) -> void:
	if risk == "volatile" and int(enemy.kind) != 3:
		world._director.circle_hazard(enemy.pos, 37.0, 1.0, 0.4, 11.0, "DAMAGE_OVERTIME")

func draw(world: Node2D) -> void:
	if pattern() == "relay" and relays < 3:
		var p: Vector2 = relay_position()
		world.draw_circle(p, 68, Color(0.3, 0.95, 0.83, 0.08))
		world.draw_arc(p, 68, 0, TAU, 40, Color("58d9e7"), 2.0, true)
		world.draw_arc(p, 60, -PI / 2, -PI / 2 + TAU * relay_progress / 3.0, 40, Color("ffc04d"), 5.0, true)
		world.draw_rect(Rect2(p - Vector2(14, 14), Vector2(28, 28)), Color("58d9e7"), false, 3)
	if shield > 0.0:
		world.draw_arc(world.player_position, 37, 0, TAU, 36, Color("8bf2ff"), 3.0, true)

func get_stats(world: Node2D) -> Dictionary:
	return {"rooms_completed": completed, "cycles_completed": completed / 3, "endless_room": room, "endless_cycle": cycle(), "overtime_pattern": pattern(), "overtime_progress": progress(world), "overtime_target": target(), "overtime_risk": risk, "overtime_threat": cycle(), "mutators": risk_history.duplicate(), "boons": boons.duplicate(true), "route_choices": routes.duplicate(true), "route_choice": choice, "can_extract": world.phase == "shop" and completed == room and boss_room(), "shield_seconds": shield}

func export_state() -> Dictionary:
	return {"version": 1, "room": room, "completed": completed, "start_map": start_map, "boons": boons.duplicate(true), "routes": routes.duplicate(true), "risk": risk, "risk_history": risk_history.duplicate(), "choice": choice, "rng_seed": str(rng.seed), "rng_state": str(rng.state), "kills_start": kills_start, "scrap_start": scrap_start, "relays": relays, "relay_progress": relay_progress}

func import_state(data: Dictionary) -> bool:
	if data.get("version") != 1 or str(data.get("start_map", "")) not in MAPS or str(data.get("risk", "")) not in RISKS:
		return false
	for key: String in ["room", "completed", "kills_start", "scrap_start", "relays"]:
		var value: Variant = data.get(key)
		if not (value is float or value is int) or not is_finite(float(value)) or float(value) != floorf(float(value)) or float(value) < 0 or float(value) > 100000000:
			return false
	if int(data.room) < 1 or int(data.room) > 1000000 or data.completed != data.room or int(data.relays) > 3:
		return false
	if not data.get("boons") is Dictionary or data.boons.size() != BOONS.size() or not data.get("routes") is Array or data.routes.size() != 3 or not data.get("risk_history") is Array:
		return false
	for id: String in BOONS:
		var n: Variant = data.boons.get(id)
		if not (n is float or n is int) or not is_finite(float(n)) or float(n) != floorf(float(n)) or n < 0 or n > 5:
			return false
	var seen: Array[String] = []
	for item: Variant in data.routes:
		if not item is Dictionary or str(item.get("boon", "")) not in BOONS or str(item.get("risk", "")) not in RISKS or not item.get("supply") is bool:
			return false
		if str(item.boon) in seen or not (item.get("rank") is int or item.get("rank") is float) or float(item.rank) != floorf(float(item.rank)) or item.rank < 1 or item.rank > 5:
			return false
		seen.append(item.boon)
	var seen_risks: Array[String] = []
	for id: Variant in data.risk_history:
		if not id is String or id not in RISKS or id in seen_risks:
			return false
		seen_risks.append(id)
	var selected: Variant = data.get("choice")
	var relay: Variant = data.get("relay_progress")
	if not (selected is int or selected is float) or not is_finite(float(selected)) or float(selected) != floorf(float(selected)) or selected < -1 or selected > 2:
		return false
	if not (relay is int or relay is float) or not is_finite(float(relay)) or relay < 0 or relay > 3:
		return false
	if not str(data.get("rng_seed", "")).is_valid_int() or not str(data.get("rng_state", "")).is_valid_int():
		return false
	room = int(data.room)
	completed = int(data.completed)
	start_map = data.start_map
	boons = data.boons.duplicate(true)
	for id: String in BOONS:
		boons[id] = int(boons[id])
	routes.assign(data.routes.duplicate(true))
	for route: Dictionary in routes:
		route.rank = int(route.rank)
	risk = data.risk
	risk_history.assign(data.risk_history)
	choice = int(selected)
	rng.seed = int(data.rng_seed)
	rng.state = int(data.rng_state)
	kills_start = int(data.kills_start)
	scrap_start = int(data.scrap_start)
	relays = int(data.relays)
	relay_progress = float(relay)
	return true
