extends RefCounted
## One independently charged active blueprint. Scrap and ordinary boss hits recharge it.

const STATE_VERSION: int = 2
const COOLDOWNS: Dictionary = {"pulse": 8.0, "singularity": 15.0, "overdrive": 12.0} # v0.3 migration only.
const COSTS: Dictionary = {"pulse": 0.0, "singularity": 0.0, "overdrive": 0.0} # Legacy HUD API; no discharge energy cost.
const COLORS: Dictionary = {"mint": Color("6df5bf"), "cyan": Color("64d9ff"), "violet": Color("c095ff"), "ember": Color("ff8c4b"), "prism": Color("f6a9ef")}
const BRANCHES: Dictionary = {"pulse": ["pulse_bulwark", "pulse_echo"], "singularity": ["singularity_vortex", "singularity_rupture"], "overdrive": ["overdrive_turbine", "overdrive_stride"]}
var skill: String = "pulse"
var skin: String = "industrial"
var color_id: String = "mint"
var tint: Color = COLORS.mint
var charge: float = 100.0
var cooldown: float = 0.0 # Compatibility field: charging has no parallel long cooldown.
var duration: float = 0.0
var total_duration: float = 0.0
var effect: float = 0.0
var center: Vector2 = Vector2.ZERO
var origin: Vector2 = Vector2.ZERO
var branch: String = ""
var branch_rank: int = 0
var branch_waves: Array[int] = []
var uses: int = 0
var _damage_timer: float = 0.0
var _input_gate: bool = true
var _boss_charge_budget: float = 6.0
var _elapsed: float = 0.0
var _collapsed: bool = false
var _echoes: int = 0
var _last_trail: Vector2 = Vector2.ZERO
var _trails: Array[Dictionary] = []
var _burst_radius: float = 185.0


func configure(setup: Dictionary = {}) -> void:
	skill = str(setup.get("skill", "pulse"))
	if not BRANCHES.has(skill):
		skill = "pulse"
	skin = str(setup.get("skin", "industrial"))
	if skin not in ["industrial", "arctic", "hazard", "cobalt", "aurora"]:
		skin = "industrial"
	color_id = str(setup.get("skill_color", "mint"))
	if not COLORS.has(color_id):
		color_id = "mint"
	tint = COLORS[color_id]
	charge = 100.0
	cooldown = 0.0
	uses = 0
	branch = ""
	branch_rank = 0
	branch_waves.clear()
	_boss_charge_budget = 6.0
	clear_effects()


func gain_scrap_charge(value: int) -> float:
	var gained: float = minf(100.0 - charge, maxf(0.0, float(value)) * 3.0)
	charge += gained
	return gained


func gain_boss_charge(actual_damage: float, source: String) -> float:
	if not is_finite(actual_damage) or actual_damage <= 0.0 or source.begins_with("ability"):
		return 0.0
	var gained: float = minf(100.0 - charge, minf(_boss_charge_budget, actual_damage * 0.10))
	charge += gained
	_boss_charge_budget -= gained
	return gained


func tool_speed_scale() -> float:
	if skill != "overdrive" or duration <= 0.0:
		return 1.0
	return 1.55 if branch != "overdrive_turbine" else (1.9 if branch_rank == 1 else 2.2)


func move_speed_scale() -> float:
	if skill != "overdrive" or duration <= 0.0:
		return 1.0
	return 1.12 if branch != "overdrive_stride" else (1.35 if branch_rank == 1 else 1.5)


func get_branch_options(wave: int) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var eligible: bool = wave in [2, 4] and wave not in branch_waves and branch_rank < 2 and (branch_waves.is_empty() or wave > branch_waves.back())
	for id: String in BRANCHES[skill]:
		var chosen: bool = branch == id
		var rank: int = mini(branch_rank + 1, 2) if chosen else 1
		options.append({"id": id, "name_key": "BRANCH_" + id.to_upper(),
			"desc_key": "BRANCH_" + id.to_upper() + ("_UPGRADE_DESC" if chosen else "_DESC"),
			"rank": rank, "selected": chosen, "available": eligible and (branch.is_empty() or chosen)})
	return options


func choose_branch(id: String, wave: int) -> Dictionary:
	for option: Dictionary in get_branch_options(wave):
		if option.id == id and option.available:
			branch = id
			branch_rank = int(option.rank)
			branch_waves.append(wave)
			return {"ok": true, "reason": "ABILITY_BRANCH_SELECTED", "id": id, "rank": branch_rank}
	return {"ok": false, "reason": "ABILITY_BRANCH_UNAVAILABLE"}


func get_cast_position(world: Node2D) -> Vector2:
	# Mouse distance and the visible reticle share the exact cast collision resolver.
	var offset: Vector2 = Vector2(world.player_aim).normalized() * 260.0
	var aimed: Variant = world.get("aim_position")
	if aimed is Vector2 and aimed != Vector2.ZERO:
		offset = (Vector2(aimed) - Vector2(world.player_position)).limit_length(260.0)
	var target: Vector2 = world._move_body(world.player_position, offset, 8.0)
	target.x = clampf(target.x, 75.0, 1205.0)
	target.y = clampf(target.y, 150.0, 630.0)
	return target


func tick(world: Node, delta: float) -> void:
	if not world.active or world.paused or world.phase != "combat" or float(world.health) <= 0.0:
		_input_gate = true
		return
	_boss_charge_budget = minf(6.0, _boss_charge_budget + delta * 6.0)
	effect = maxf(0.0, effect - delta)
	_elapsed += delta
	world.player_skin = skin
	world.skill_color = tint
	if InputMap.has_action("active_skill"):
		if not Input.is_action_pressed("active_skill"):
			_input_gate = false
		if not _input_gate and Input.is_action_just_pressed("active_skill"):
			activate(world)
	for i: int in range(_trails.size() - 1, -1, -1):
		_trails[i].life -= delta
		if float(_trails[i].life) <= 0.0:
			_trails.remove_at(i)
	if duration <= 0.0:
		return
	duration = maxf(0.0, duration - delta)
	if skill == "pulse":
		if branch == "pulse_bulwark":
			center = world.player_position
			_clear_projectiles(world, center, 130.0 if branch_rank == 1 else 165.0)
		elif branch == "pulse_echo":
			_damage_timer -= delta
			if _damage_timer <= 0.0 and _echoes > 0:
				_echoes -= 1
				_damage_timer = 0.55
				center = world.player_position
				_hit_radius(world, center, 200.0, 22.0, 560.0)
				_clear_projectiles(world, center, 200.0)
				effect = 0.6
				_burst_radius = 200.0
				_feedback(world, center, 0.45, "pulse")
				world.sound_requested.emit("skill_pulse")
	elif skill == "singularity":
		if _collapsed:
			if duration <= 0.0:
				_burst_radius = 280.0 if branch_rank == 1 else 320.0
				_hit_radius(world, center, _burst_radius, 50.0, 600.0)
				effect = 0.8
				_feedback(world, center, 0.9, "collapse")
				world.sound_requested.emit("singularity_burst")
			return
		var radius: float = 240.0 if branch != "singularity_vortex" else (280.0 if branch_rank == 1 else 315.0)
		for enemy: Dictionary in world._enemies:
			if float(enemy.hp) <= 0.0 or float(enemy.spawn) > 0.0:
				continue
			var toward: Vector2 = center - Vector2(enemy.pos)
			if toward.length() < radius and toward.length() > 24.0 and world._line_clear(center, enemy.pos):
				var boss: bool = int(enemy.kind) == 3
				# Committed boss attacks keep their displayed path. Ordinary enemies
				# move directly through collisions so knock decay cannot erase suction.
				if boss and str(enemy.get("state", "")) in ["windup", "charge"]:
					continue
				if int(enemy.kind) == 4 and (float(enemy.get("charge", 0.0)) > 0.0 or float(enemy.get("elite_warning", 0.0)) > 0.0):
					continue
				var speed: float = 32.0 if boss else (470.0 if branch == "singularity_vortex" else 350.0)
				var movement: Vector2 = toward.normalized() * minf(speed * delta, maxf(0.0, toward.length() - 24.0))
				enemy.pos = world._move_body(enemy.pos, movement, float(enemy.radius))
		for scrap: Dictionary in world._scraps:
			var toward: Vector2 = center - Vector2(scrap.pos)
			if toward.length() < radius + 30.0:
				scrap.pos = world._move_body(scrap.pos, toward.limit_length(240.0 * delta), 4.0)
		if duration <= 0.0:
			_burst_radius = 185.0
			_hit_radius(world, center, _burst_radius, 102.0, 430.0)
			_clear_projectiles(world, center, 185.0)
			_collapsed = true
			effect = 0.8
			if branch == "singularity_rupture":
				duration = 0.45
			_feedback(world, center, 0.85, "collapse")
			world.sound_requested.emit("singularity_burst")
	elif skill == "overdrive":
		center = world.player_position
		_damage_timer -= delta
		if _damage_timer <= 0.0:
			_damage_timer = 0.40
			_hit_radius(world, center, 120.0, 11.0, 90.0)
			if branch == "overdrive_turbine":
				# Capacitor vent attacks two off-axis points rather than scaling only DPS.
				var side: Vector2 = Vector2(world.player_aim).orthogonal() * 130.0
				if world._line_clear(center, center + side):
					_hit_radius(world, center + side, 62.0, 8.0, 100.0)
				if world._line_clear(center, center - side):
					_hit_radius(world, center - side, 62.0, 8.0, 100.0)
			world.sound_requested.emit("arc")
		if branch == "overdrive_stride" and center.distance_to(_last_trail) >= 42.0:
			if _trails.size() < 18:
				_trails.append({"pos": _last_trail, "life": 0.7})
			_hit_radius(world, _last_trail, 70.0 if branch_rank == 1 else 95.0, 14.0, 140.0)
			_last_trail = center


func activate(world: Node) -> bool:
	if not world.active or world.paused or world.phase != "combat" or float(world.health) <= 0.0:
		return false
	_input_gate = true
	if duration > 0.0:
		_notify(world, "ABILITY_ACTIVE")
		return false
	if charge < 100.0:
		_notify(world, "ABILITY_NOT_READY")
		return false
	charge = 0.0
	cooldown = 0.0
	uses += 1
	origin = world.player_position
	center = origin
	_elapsed = 0.0
	_collapsed = false
	_damage_timer = 0.0
	_trails.clear()
	if skill == "pulse":
		_burst_radius = 185.0
		_hit_radius(world, center, _burst_radius, 30.0, 700.0)
		_clear_projectiles(world, center, 205.0)
		duration = 0.45
		if branch == "pulse_bulwark":
			duration = 1.8 if branch_rank == 1 else 2.5
		elif branch == "pulse_echo":
			_echoes = branch_rank
			_damage_timer = 0.6
			duration = 0.7 if branch_rank == 1 else 1.3
		effect = 0.6
		_feedback(world, center, 0.65, "pulse")
	elif skill == "singularity":
		center = get_cast_position(world)
		duration = 1.5 if branch != "singularity_vortex" else (2.1 if branch_rank == 1 else 2.5)
	elif skill == "overdrive":
		duration = 5.0
		world._dash_cooldown = 0.0
		_last_trail = origin
	total_duration = duration + (0.45 if branch == "singularity_rupture" else 0.0)
	_notify(world, "ABILITY_CAST")
	return true


func _clear_projectiles(world: Node, at: Vector2, radius: float) -> void:
	for i: int in range(world._projectiles.size() - 1, -1, -1):
		var projectile: Dictionary = world._projectiles[i]
		if at.distance_to(Vector2(projectile.pos)) <= radius and world._line_clear(at, projectile.pos):
			world._projectiles.remove_at(i)


func _hit_radius(world: Node, at: Vector2, radius: float, damage: float, knock: float) -> void:
	for enemy: Dictionary in world._enemies:
		if float(enemy.hp) <= 0.0 or float(enemy.spawn) > 0.0:
			continue
		var offset: Vector2 = Vector2(enemy.pos) - at
		if offset.length() <= radius + float(enemy.radius) and world._line_clear(at, enemy.pos):
			world._damage_enemy(enemy, damage, offset.normalized() * knock, "ability")
	if world.standard_mode and world._director.has_method("hit_targets"):
		world._director.hit_targets(world, at, radius, damage)


func _notify(world: Node, key: String) -> void:
	if world.has_method("notify_ability_event"):
		world.notify_ability_event(key)


func _feedback(world: Node, at: Vector2, strength: float, kind: String) -> void:
	if world.has_method("combat_feedback"):
		world.combat_feedback(at, strength, kind)


func get_stats() -> Dictionary:
	var state: String = "active" if duration > 0.0 else ("ready" if charge >= 100.0 else "charging")
	var remaining: float = duration + (0.45 if branch == "singularity_rupture" and not _collapsed and duration > 0.0 else 0.0)
	return {"ability_id": skill, "ability_ratio": charge / 100.0, "ability_charge": charge,
		"ability_state": state, "ability_remaining": remaining, "ability_duration": total_duration,
		"ability_cost": 0.0, "ability_cooldown": 0.0, "ability_uses": uses,
		"ability_branch": branch, "ability_branch_rank": branch_rank,
		"skin": skin, "skill_color": color_id}


func cancel_input() -> void:
	_input_gate = true


func clear_effects() -> void:
	duration = 0.0
	total_duration = 0.0
	effect = 0.0
	_damage_timer = 0.0
	_echoes = 0
	_elapsed = 0.0
	_collapsed = false
	_trails.clear()
	cancel_input()


func export_state() -> Dictionary:
	return {"version": STATE_VERSION, "skill": skill, "skin": skin, "skill_color": color_id,
		"charge": charge, "cooldown": 0.0, "uses": uses, "boss_charge_budget": _boss_charge_budget,
		"branch": branch, "branch_rank": branch_rank, "branch_waves": branch_waves.duplicate()}


func import_state(value: Dictionary) -> bool:
	if not BRANCHES.has(value.get("skill", "")) or not COLORS.has(value.get("skill_color", "")):
		return false
	if value.get("skin", "") not in ["industrial", "arctic", "hazard", "cobalt", "aurora"]:
		return false
	if not _number(value.get("uses"), 0.0, 100000000.0) or float(value.uses) != floorf(float(value.uses)):
		return false
	if not _number(value.get("version", 1), 1.0, float(STATE_VERSION)) or float(value.get("version", 1)) != floorf(float(value.get("version", 1))):
		return false
	var version: int = int(value.get("version", 1))
	var saved_charge: float = 100.0
	var saved_budget: float = 6.0
	var saved_branch: String = ""
	var saved_rank: int = 0
	var saved_waves: Array[int] = []
	if version == 1:
		if not _number(value.get("cooldown"), 0.0, float(COOLDOWNS[value.skill])):
			return false
		saved_charge = 100.0 * (1.0 - float(value.cooldown) / float(COOLDOWNS[value.skill]))
	elif version == STATE_VERSION:
		if not _number(value.get("charge"), 0.0, 100.0) or not _number(value.get("boss_charge_budget"), 0.0, 6.0) or value.get("cooldown") != 0.0:
			return false
		if not value.get("branch", null) is String or not _number(value.get("branch_rank"), 0.0, 2.0) or float(value.branch_rank) != floorf(float(value.branch_rank)):
			return false
		saved_branch = value.branch
		saved_rank = int(value.branch_rank)
		if (saved_branch.is_empty() != (saved_rank == 0)) or (not saved_branch.is_empty() and saved_branch not in BRANCHES[value.skill]):
			return false
		if not value.get("branch_waves", null) is Array or value.branch_waves.size() != saved_rank:
			return false
		for wave: Variant in value.branch_waves:
			if not _number(wave, 2.0, 4.0) or int(wave) not in [2, 4] or float(wave) != float(int(wave)) or int(wave) in saved_waves:
				return false
			saved_waves.append(int(wave))
		if saved_waves.size() == 2 and saved_waves != [2, 4]:
			return false
		saved_charge = float(value.charge)
		saved_budget = float(value.boss_charge_budget)
	else:
		return false
	configure(value)
	charge = saved_charge
	_boss_charge_budget = saved_budget
	uses = int(value.uses)
	branch = saved_branch
	branch_rank = saved_rank
	branch_waves = saved_waves
	return true


static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high


func draw(world: Node2D) -> void:
	var reduced: bool = not world._effects_enabled()
	if skill == "singularity" and duration <= 0.0 and charge >= 100.0 and world.active and not world.paused and world.phase == "combat":
		var preview: Vector2 = get_cast_position(world)
		world.draw_arc(preview, 30.0, 0.0, TAU, 48, Color(tint, 0.8), 1.5, true)
		world.draw_line(preview - Vector2(39, 0), preview + Vector2(39, 0), Color(tint, 0.5), 1.0, true)
		world.draw_line(preview - Vector2(0, 39), preview + Vector2(0, 39), Color(tint, 0.5), 1.0, true)
		world.draw_dashed_line(world.player_position, preview, Color(tint, 0.25), 1.0, 12.0, true)
	if duration > 0.0 and skill == "singularity":
		var radius: float = 240.0 if branch != "singularity_vortex" else (280.0 if branch_rank == 1 else 315.0)
		if _collapsed and branch == "singularity_rupture":
			radius = 280.0 if branch_rank == 1 else 320.0
		var spin: float = _elapsed * 4.0
		world.draw_arc(center, radius, 0.0, TAU, 64, Color(tint, 0.24), 1.0, true)
		world.draw_circle(center, 23.0 + 4.0 * sin(spin * 2.0), Color("08101b"))
		for i: int in range(2 if reduced else 4):
			var r: float = 35.0 + float(i) * 24.0
			world.draw_arc(center, r, spin * (1.0 if i % 2 == 0 else -1.0), spin * (1.0 if i % 2 == 0 else -1.0) + PI * 1.65, 40, Color(tint, 0.85 - float(i) * 0.17), 2.0, true)
		if not reduced:
			for i: int in range(12):
				var angle: float = spin + float(i) * TAU / 12.0
				var r: float = 50.0 + fposmod(float(i) * 23.0 - _elapsed * 100.0, radius - 50.0)
				world.draw_line(center + Vector2.from_angle(angle) * r, center + Vector2.from_angle(angle + 0.20) * maxf(28.0, r - 23.0), Color(tint, 0.48), 2.0, true)
	elif duration > 0.0 and skill == "overdrive":
		var spin: float = _elapsed * 7.0
		world.draw_arc(center, 120.0, 0.0, TAU, 64, Color(tint, 0.4), 1.5, true)
		if branch == "overdrive_turbine":
			for sign_value: float in [-1.0, 1.0]:
				var vent: Vector2 = center + Vector2(world.player_aim).orthogonal() * 130.0 * sign_value
				if world._line_clear(center, vent):
					world.draw_line(center, vent, Color(tint, 0.5), 2.0, true)
					world.draw_arc(vent, 62.0, 0.0, TAU, 24, Color(tint, 0.3), 1.0, true)
		for i: int in range(3 if reduced else 6):
			var angle: float = spin + float(i) * TAU / (3.0 if reduced else 6.0)
			var a: Vector2 = center + Vector2.from_angle(angle) * 34.0
			var b: Vector2 = center + Vector2.from_angle(angle + 0.35) * 114.0
			world.draw_polyline(PackedVector2Array([a, a.lerp(b, 0.5) + Vector2.from_angle(angle + PI / 2.0) * 15.0, b]), tint, 2.0 if reduced else 3.0, true)
	elif duration > 0.0 and skill == "pulse" and branch == "pulse_bulwark":
		var radius: float = 130.0 if branch_rank == 1 else 165.0
		world.draw_arc(center, radius, 0.0, TAU, 64, Color(tint, 0.5), 3.0, true)
		for i: int in range(8):
			var point: Vector2 = center + Vector2.from_angle(float(i) * TAU / 8.0 + _elapsed) * radius
			world.draw_circle(point, 3.0, tint)
	for trail: Dictionary in _trails:
		world.draw_arc(trail.pos, 70.0 if branch_rank == 1 else 95.0, 0.0, TAU, 32, Color(tint, float(trail.life) * 0.5), 1.5, true)
	if effect > 0.0:
		var lifetime: float = 0.8 if skill == "singularity" else 0.6
		var progress: float = clampf(1.0 - effect / lifetime, 0.0, 1.0)
		var radius: float = _burst_radius
		world.draw_arc(center, lerpf(22.0, radius, progress), 0.0, TAU, 72, Color(tint, 1.0 - progress), 2.0 if reduced else 6.0, true)
		if not reduced:
			world.draw_arc(center, lerpf(12.0, radius * 0.8, progress), 0.0, TAU, 64, Color(tint, (1.0 - progress) * 0.38), 3.0, true)
