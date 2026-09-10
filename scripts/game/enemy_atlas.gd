extends RefCounted
## Cached frames baked from our original Godot geometry, never external artwork.
const PATH: String = "res://assets/sprites/enemy_atlas.png"
const CELL: int = 80
static var texture: Texture2D
static var attempted: bool = false

static func draw_body(canvas: Node2D, map_id: String, kind: int, at: Vector2, angle: float, clock: float, flash: bool) -> bool:
	if not attempted:
		attempted = true
		if ResourceLoader.exists(PATH):
			texture = load(PATH) as Texture2D
	if texture == null or kind < 0 or kind > 2:
		return false
	var row: int = (["yard", "foundry", "reactor"].find(map_id) * 3) + kind
	if row < 0:
		return false
	var frame: int = (int(floor(clock * 8.0)) % 4) + (4 if flash else 0)
	canvas.draw_set_transform(at, angle)
	canvas.draw_texture_rect_region(texture, Rect2(-40, -40, CELL, CELL), Rect2(frame * CELL, row * CELL, CELL, CELL))
	canvas.draw_set_transform(Vector2.ZERO)
	return true
