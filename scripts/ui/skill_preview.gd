extends Control
## Presentation-only loop; it never activates gameplay skills or changes charge.
const Art = preload("res://scripts/ui/hangar_visual.gd")
var setup: Dictionary = {"skill": "pulse", "skin": "industrial", "skill_color": "mint"}
var mode: String = "hangar"
var map_id: String = "yard"
var time: float = 0.0
var demonstration: bool = true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

func configure(value: Dictionary, scene_mode: String = "hangar", sector: String = "yard") -> void:
	setup = value.duplicate(true)
	mode = scene_mode
	map_id = sector
	time = 0.0
	queue_redraw()

func replay() -> void:
	time = 1.3
	queue_redraw()

func _process(delta: float) -> void:
	if is_visible_in_tree():
		time += minf(delta, 0.1)
		queue_redraw()

func _draw() -> void:
	var settings: Node = get_node_or_null("/root/Settings")
	var reduced: bool = settings != null and not bool(settings.get("effects_enabled"))
	Art.draw(self, size, setup, 0.0 if reduced else time, mode, map_id)
	if mode != "hangar" or not demonstration:
		return
	var phase: float = fmod(time, 5.2)
	if phase < 1.3 or phase > 4.7:
		return
	var t: float = phase - 1.3
	var tint: Color = Art.skill_color(setup)
	var scene_transform: Dictionary = Art.scene_transform(size, mode)
	draw_set_transform(scene_transform.origin, 0, Vector2.ONE * float(scene_transform.scale))
	var center := Vector2(357, 294)
	var skill: String = str(setup.get("skill", "pulse"))
	if skill == "pulse":
		for i: int in range(1 if reduced else 3):
			var progress: float = clampf((t - i * 0.16) / 1.0, 0, 1)
			if progress > 0 and progress < 1:
				draw_arc(center, 77 + progress * 118, 0, TAU, 72, Color(tint, (1 - progress) * 0.85), 4 - progress * 2, true)
	elif skill == "singularity":
		var target := Vector2(488, 300)
		if t < 1.5:
			draw_circle(target, 24 + sin(t * 9) * 2, Color("040b12"))
			for i: int in range(3):
				draw_arc(target, 35 + i * 16, t * (2 + i) + i, t * (2 + i) + i + PI * 1.5, 48, Color(tint, 0.8 - i * 0.15), 2, true)
			for i: int in range(0 if reduced else 12):
				var radius: float = 20 + fposmod(i * 14 - t * 65, 93)
				draw_circle(target + Vector2.from_angle(i * 2.4 + t) * radius, 2.5, tint)
		elif t < 2.15:
			var progress: float = (t - 1.5) / 0.65
			draw_arc(target, 30 + progress * 118, 0, TAU, 64, Color(tint, 1 - progress), 6, true)
	else:
		for i: int in range(3 if reduced else 6):
			var a: float = i * TAU / (3 if reduced else 6) + t * 1.1
			var p: Vector2 = center + Vector2.from_angle(a) * 95
			var end: Vector2 = center + Vector2.from_angle(a + 0.67) * 95
			draw_polyline(PackedVector2Array([p, p.lerp(end, 0.45) + Vector2(8, -8), end]), Color(tint, minf(1, (3.4 - t) * 2)), 2.5, true)
		if t < 0.55:
			draw_arc(center, 80 + t * 165, 0, TAU, 64, Color(tint, 1 - t / 0.55), 3, true)
	draw_set_transform(Vector2.ZERO)
