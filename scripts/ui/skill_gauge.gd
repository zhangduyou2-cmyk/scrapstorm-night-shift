extends Control
## One stable combat readout: blueprint identity, charge, ready, active duration.
var stats: Dictionary = {}
var time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func update_state(value: Dictionary) -> void:
	stats = value
	queue_redraw()


func _process(delta: float) -> void:
	if is_visible_in_tree():
		time += delta
		queue_redraw()


func _draw() -> void:
	var center := Vector2(34, 34)
	var state: String = str(stats.get("ability_state", "charging"))
	var charge: float = clampf(float(stats.get("ability_charge", 0.0)) / 100.0, 0.0, 1.0)
	var tint := Color("ffc04d") if state == "ready" else Color("58d9e7")
	var skill: String = str(stats.get("ability_id", "pulse"))
	draw_circle(center, 30.0, Color("101c24"))
	draw_arc(center, 29.0, 0, TAU, 60, Color("334751"), 4.0, true)
	if state == "active":
		charge = clampf(float(stats.get("ability_remaining", 0.0)) / maxf(0.1, float(stats.get("ability_duration", 1.0))), 0.0, 1.0)
	if charge > 0.0:
		draw_arc(center, 29.0, -PI / 2, -PI / 2 + TAU * charge, 60, tint, 4.0, true)
	if state == "ready" and Settings.effects_enabled:
		draw_arc(center, 32.0, 0, TAU, 60, Color(tint, 0.17 + sin(time * 3.0) * 0.07), 3.0, true)
	if skill == "singularity":
		draw_circle(center, 8.0, Color("02090f"))
		for i: int in range(2):
			draw_arc(center, 13.0 + i * 6.0, time * 0.5 + i, time * 0.5 + i + PI * 1.6, 32, tint, 2.0, true)
	elif skill == "overdrive":
		draw_polyline(PackedVector2Array([center + Vector2(7,-19), center + Vector2(-10,2), center + Vector2(3,0), center + Vector2(-5,19), center + Vector2(13,-4), center + Vector2(0,-2)]), tint, 3.0, true)
	else:
		for i: int in range(3):
			draw_arc(center, 6.0 + i * 6.0, -0.6, PI * 1.6, 32, tint, 2.0, true)
