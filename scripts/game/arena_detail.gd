extends RefCounted
## Original steelwork, with quiet traversable floors and lit, solid boundaries.

static func floor_plates(world: Node2D, map_id: String) -> void:
	var accent: Color = Color("58d9e7") if map_id == "reactor" else (Color("f07842") if map_id == "foundry" else Color("ffc04d"))
	for row: int in range(6):
		for column: int in range(8):
			var origin := Vector2(47 + column * 148, 128 + row * 87)
			var rect := Rect2(origin, Vector2(137, 75))
			world.draw_rect(rect, Color("a6b2af0a"), false, 1.0)
			world.draw_line(origin + Vector2(1, 1), origin + Vector2(136, 1), Color("00000020"), 2.0)
			for offset: Vector2 in [Vector2(4, 4), Vector2(133, 71)]:
				world.draw_circle(origin + offset, 1.0, Color("839d9d2a"))
	# Inset conduits and work lights sit against the non-traversable arena wall.
	for y: int in range(164, 628, 93):
		for x: float in [34.0, 1239.0]:
			world.draw_rect(Rect2(x, y, 8, 51), Color("090f16"))
			world.draw_rect(Rect2(x + 1, y + 1, 4, 48), Color("46606b"))
			for offset: int in [5, 41]:
				world.draw_rect(Rect2(x - 2, y + offset, 12, 4), Color("283c45"))
	for x: int in range(141, 1220, 204):
		for y: float in [114.0, 663.0]:
			world.draw_rect(Rect2(x - 22, y - 3, 44, 6), Color("111c22"))
			world.draw_line(Vector2(x - 17, y), Vector2(x + 17, y), accent, 2.0)
			if world._effects_enabled():
				world.draw_line(Vector2(x - 16, y), Vector2(x + 16, y), Color(accent, 0.09), 12.0, true)
	# Stencilled alignment ticks describe the work floor without resembling hazards.
	for anchor: Vector2 in [Vector2(425, 272), Vector2(850, 525)]:
		world.draw_polyline(PackedVector2Array([anchor + Vector2(0, 18), anchor, anchor + Vector2(18, 0)]), Color(accent, 0.16), 2.0)
		world.draw_line(anchor + Vector2(5, 5), anchor + Vector2(11, 5), Color(accent, 0.16), 2.0)
