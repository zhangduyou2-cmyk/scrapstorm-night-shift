extends RefCounted
## Original deterministic scene art. Never consumes gameplay RNG.
const K = preload("res://scripts/ui/ui_kit.gd")

static func draw(c: CanvasItem, size: Vector2, setup: Dictionary, time: float, mode: String = "hangar", map_id: String = "yard") -> void:
	c.draw_rect(Rect2(Vector2.ZERO, size), K.BG)
	var transform: Dictionary = scene_transform(size, mode)
	c.draw_set_transform(transform.origin, 0, Vector2.ONE * float(transform.scale))
	if mode == "map":
		_sector(c, map_id, time)
	else:
		_hangar(c, setup, time)
	c.draw_set_transform(Vector2.ZERO)

static func scene_transform(size: Vector2, mode: String = "hangar") -> Dictionary:
	var rect := Rect2(Vector2.ZERO, size)
	if mode == "hangar" and size.x > 1000:
		rect = Rect2(Vector2(size.x * 0.46, 0), Vector2(size.x * 0.54, size.y))
	var uniform: float = minf(rect.size.x / 720.0, rect.size.y / 480.0)
	return {"origin": rect.position + (rect.size - Vector2(720, 480) * uniform) * 0.5, "scale": uniform}

static func _plate(c: CanvasItem, rect: Rect2, color: Color) -> void:
	c.draw_rect(rect, color)
	c.draw_rect(rect, K.STEEL, false, 1)
	for p: Vector2 in [rect.position + Vector2(7, 7), rect.end - Vector2(7, 7), Vector2(rect.end.x - 7, rect.position.y + 7), Vector2(rect.position.x + 7, rect.end.y - 7)]:
		c.draw_circle(p, 2, Color("75858a"))
		c.draw_line(p - Vector2(1, 0), p + Vector2(1, 0), K.BG, 1)

static func _stripes(c: CanvasItem, rect: Rect2, color: Color = K.GOLD) -> void:
	c.draw_rect(rect, Color("17232a"))
	for i: int in range(int(rect.size.x / 22)):
		var p := rect.position + Vector2(i * 22, 0)
		c.draw_colored_polygon(PackedVector2Array([p + Vector2(2, 0), p + Vector2(12, 0), p + Vector2(21, rect.size.y), p + Vector2(11, rect.size.y)]), color)

static func _hangar(c: CanvasItem, setup: Dictionary, t: float) -> void:
	c.draw_rect(Rect2(0, 0, 720, 480), Color("101b21"))
	for x: int in range(0, 720, 120):
		_plate(c, Rect2(x + 2, 12, 116, 280), Color("1a2930"))
		c.draw_line(Vector2(x + 24, 26), Vector2(x + 87, 274), Color("203139"), 2)
	_plate(c, Rect2(0, 8, 720, 37), Color("33424a"))
	_stripes(c, Rect2(209, 16, 286, 10), Color("8a733a"))
	for x: float in [176.0, 528.0]:
		c.draw_line(Vector2(x, 43), Vector2(x, 74), K.STEEL, 6)
		c.draw_colored_polygon(PackedVector2Array([Vector2(x - 32, 77), Vector2(x + 32, 77), Vector2(x + 111, 357), Vector2(x - 111, 357)]), Color(1, 0.75, 0.30, 0.04))
		_plate(c, Rect2(x - 37, 67, 74, 16), Color("475459"))
		c.draw_line(Vector2(x - 29, 80), Vector2(x + 29, 80), K.GOLD, 5)
	for x: float in [37.0, 55.0]:
		c.draw_polyline(PackedVector2Array([Vector2(x, 44), Vector2(x, 232), Vector2(x + 39, 268), Vector2(x + 39, 347)]), Color("3f535b"), 9, true)
		for y: float in [94.0, 185.0]:
			c.draw_rect(Rect2(x - 8, y, 16, 9), Color("768083"))
	_plate(c, Rect2(86, 130, 121, 99), Color("243740"))
	c.draw_rect(Rect2(95, 139, 103, 73), Color("07171d"))
	for row: int in range(5):
		c.draw_line(Vector2(106, 153 + row * 10), Vector2(123 + fmod(row * 27 + 39, 60), 153 + row * 10), Color(K.MINT, 0.4 if row % 2 else 0.75), 3)
	c.draw_circle(Vector2(194, 220), 3, K.GOLD)
	_plate(c, Rect2(553, 118, 125, 184), Color("223039"))
	for x: int in range(6):
		for y: int in range(8):
			c.draw_circle(Vector2(564 + x * 20, 131 + y * 20), 1.5, Color("506068"))
	for i: int in range(3):
		var p := Vector2(576 + i * 37, 157 + i % 2 * 16)
		c.draw_line(p, p + Vector2(0, 66), Color("8f9b9c"), 8)
		c.draw_arc(p, 11, 0, PI, 16, Color("b3b9af"), 5, true)
		c.draw_circle(p + Vector2(0, 65), 6, K.RUST)
	c.draw_rect(Rect2(0, 304, 720, 176), Color("152129"))
	for x: int in range(-360, 1100, 120):
		c.draw_line(Vector2(360 + (x - 360) * 0.45, 304), Vector2(x, 480), Color("2d3b42"), 1)
	for y: float in [327.0, 360.0, 407.0, 467.0]:
		c.draw_line(Vector2(0, y), Vector2(720, y), Color("2d3b42"), 1)
	var ring := PackedVector2Array()
	for i: int in range(65):
		ring.append(Vector2(355, 393) + Vector2(cos(i * TAU / 64.0) * 173, sin(i * TAU / 64.0) * 48))
	c.draw_colored_polygon(ring, Color("0a131a"))
	c.draw_polyline(ring, Color("5c6665"), 6, true)
	_plate(c, Rect2(215, 384, 281, 37), Color("3a464a"))
	_stripes(c, Rect2(233, 407, 242, 12))
	var tip := Vector2(240, 236 + sin(t * 0.9) * 9)
	c.draw_polyline(PackedVector2Array([Vector2(116, 365), Vector2(159, 296), Vector2(193, 227), tip]), K.STEEL, 20, true)
	c.draw_polyline(PackedVector2Array([Vector2(116, 365), Vector2(159, 296), Vector2(193, 227), tip]), Color("718084"), 8, true)
	for joint: Vector2 in [Vector2(159, 296), Vector2(193, 227)]:
		c.draw_circle(joint, 12, Color("17262e"))
		c.draw_circle(joint, 5, K.GOLD)
	c.draw_line(tip, tip + Vector2(15, 8), K.MINT, 4)
	robot(c, Vector2(357, 282 + sin(t * 1.4) * 2), 1, setup, t)
	c.draw_polyline(PackedVector2Array([Vector2(668, 333), Vector2(613, 345), Vector2(622, 429), Vector2(534, 448), Vector2(506, 424)]), Color("090f14"), 8, true)
	_plate(c, Rect2(560, 339, 105, 55), Color("30434b"))
	c.draw_line(Vector2(577, 365), Vector2(627, 365), K.RUST, 8)

static func robot(c: CanvasItem, p: Vector2, s: float, setup: Dictionary, t: float) -> void:
	var body: Color = skin_color(str(setup.get("skin", "industrial")))
	var energy: Color = skill_color(setup)
	# Wide crawler stance and a low bevelled hull replace the old circular egg.
	c.draw_rect(Rect2(p + Vector2(-106, 63) * s, Vector2(212, 21) * s), Color(0.01, 0.04, 0.06, 0.7))
	for side: float in [-1.0, 1.0]:
		var tread := Rect2(p + Vector2(side * 79 - 29, -18) * s, Vector2(58, 91) * s)
		c.draw_rect(tread, Color("071016"))
		c.draw_rect(tread.grow(-4 * s), Color("42535b"))
		for i: int in range(7):
			c.draw_line(tread.position + Vector2(3, 7 + i * 12) * s, tread.position + Vector2(55, 7 + i * 12) * s, Color("14232a"), 5 * s)
		c.draw_rect(Rect2(tread.position + Vector2(8, 14) * s, Vector2(42, 55) * s), Color("20323b"))
		for y: float in [27.0, 55.0]:
			c.draw_circle(tread.position + Vector2(29, y) * s, 15 * s, Color("061218"))
			c.draw_circle(tread.position + Vector2(29, y) * s, 9 * s, Color("697b80"))
			c.draw_circle(tread.position + Vector2(29, y) * s, 4 * s, body)
	var hull := PackedVector2Array()
	for point: Vector2 in [Vector2(-61, -47), Vector2(52, -47), Vector2(71, -25), Vector2(71, 40), Vector2(48, 63), Vector2(-55, 63), Vector2(-76, 39), Vector2(-76, -24)]:
		hull.append(p + point * s)
	c.draw_colored_polygon(hull, body.darkened(0.38))
	var armor := PackedVector2Array()
	for point: Vector2 in [Vector2(-57, -45), Vector2(48, -45), Vector2(64, -28), Vector2(60, 25), Vector2(-66, 25), Vector2(-69, -23)]:
		armor.append(p + point * s)
	c.draw_colored_polygon(armor, body)
	c.draw_polyline(PackedVector2Array([p + Vector2(-57, -43) * s, p + Vector2(48, -43) * s, p + Vector2(63, -27) * s]), body.lightened(0.4), 3 * s, true)
	c.draw_rect(Rect2(p + Vector2(-57, 31) * s, Vector2(113, 24) * s), Color("253d46"))
	var visor := Rect2(p + Vector2(-49, -27) * s, Vector2(101, 33) * s)
	c.draw_rect(visor.grow(4 * s), Color("43525a"))
	c.draw_rect(visor, Color("071720"))
	var blink: float = 0.18 if fmod(t, 6) > 5.83 else 1.0
	for x: float in [-24.0, 24.0]:
		c.draw_rect(Rect2(p + Vector2(x - 10, -17) * s, Vector2(20, 6 * blink) * s), energy)
		c.draw_line(p + Vector2(x - 10, -4) * s, p + Vector2(x + 10, -4) * s, Color(energy, 0.28), 1.5 * s)
	c.draw_rect(Rect2(p + Vector2(-27, 34) * s, Vector2(54, 14) * s), Color("071720"))
	for i: int in range(6):
		c.draw_line(p + Vector2(-20 + i * 8, 36) * s, p + Vector2(-20 + i * 8, 46) * s, Color("78929a"), 2 * s)
	for point: Vector2 in [Vector2(-59, 15), Vector2(52, 15), Vector2(-60, -34), Vector2(47, -34)]:
		c.draw_circle(p + point * s, 4 * s, K.STEEL)
		c.draw_line(p + (point - Vector2(2, 0)) * s, p + (point + Vector2(2, 0)) * s, Color("81969a"), 1 * s)
	c.draw_line(p + Vector2(30, -45) * s, p + Vector2(42, -70) * s, K.STEEL, 4 * s)
	c.draw_circle(p + Vector2(42, -72) * s, 4 * s, energy)
	if setup.get("skin", "industrial") == "hazard":
		for i: int in range(4):
			c.draw_line(p + Vector2(-26 + i * 15, 10) * s, p + Vector2(-18 + i * 15, 22) * s, K.BG, 6 * s)
	elif setup.get("skin", "industrial") == "aurora":
		c.draw_line(p + Vector2(-53, 17) * s, p + Vector2(50, 17) * s, Color("8af0bf"), 3 * s)
		c.draw_line(p + Vector2(-35, 20) * s, p + Vector2(55, 20) * s, Color("bb91ff"), 2 * s)
	elif setup.get("skin", "industrial") == "cobalt":
		c.draw_line(p + Vector2(-58, -38) * s, p + Vector2(49, -38) * s, Color("74e7ff"), 3 * s)
	for side: float in [-1.0, 1.0]:
		var mount: Vector2 = p + Vector2(side * 111, 53) * s
		c.draw_line(p + Vector2(side * 59, 29) * s, mount, K.STEEL, 11 * s)
		c.draw_circle(mount, 22 * s, Color("172b34"))
		if side < 0:
			for i: int in range(12):
				var a: float = i * TAU / 12 + t * 0.22
				c.draw_line(mount + Vector2.from_angle(a) * 15 * s, mount + Vector2.from_angle(a) * 27 * s, body, 4 * s)
		else:
			c.draw_rect(Rect2(mount + Vector2(-12, -24) * s, Vector2(24, 42) * s), K.STEEL)
			c.draw_circle(mount - Vector2(0, 22) * s, 9 * s, energy)
	var module: Vector2 = p + Vector2(-19, -57) * s
	c.draw_rect(Rect2(module - Vector2(18, 12) * s, Vector2(36, 24) * s), Color("243a42"))
	icon(c, module, str(setup.get("skill", "pulse")), energy, 0.33 * s, t)

static func skill_color(setup: Dictionary) -> Color:
	var colors: Dictionary = {"mint": Color("72e4ba"), "cyan": K.MINT, "violet": Color("c095ff"), "ember": Color("ff8c4b"), "prism": Color("f6a9ef")}
	return colors.get(str(setup.get("skill_color", "mint")), colors.mint)

static func skin_color(id: String) -> Color:
	var colors: Dictionary = {"industrial": K.GOLD, "arctic": Color("8ed7db"), "hazard": K.RUST, "cobalt": Color("295f94"), "aurora": Color("205b59")}
	return colors.get(id, K.GOLD)

static func icon(c: CanvasItem, p: Vector2, skill: String, color: Color, s: float = 1.0, t: float = 0.0) -> void:
	if skill == "overdrive":
		c.draw_polyline(PackedVector2Array([p + Vector2(8, -25) * s, p + Vector2(-12, 2) * s, p + Vector2(7, 2) * s, p + Vector2(-8, 25) * s]), color, 4 * s, true)
	elif skill == "singularity":
		c.draw_circle(p, 13 * s, Color("071118"))
		for i: int in range(2):
			c.draw_arc(p, (19 + i * 9) * s, t * 0.4 + i * PI, t * 0.4 + i * PI + PI * 1.4, 36, color, 2 * s, true)
	else:
		for i: int in range(3):
			c.draw_arc(p, (9 + i * 10) * s, -0.5, TAU - 1.1, 40, color, 2.5 * s, true)

static func _sector(c: CanvasItem, id: String, t: float) -> void:
	var color: Color = K.GOLD if id == "yard" else (K.RUST if id == "foundry" else K.MINT)
	c.draw_rect(Rect2(0, 0, 720, 480), Color("0c171e"))
	for i: int in range(9):
		var height: float = 75 + fmod(i * 73, 85)
		c.draw_rect(Rect2(i * 86 - 20, 195 - height, 66, height), Color("20323b"))
		for j: int in range(3):
			c.draw_rect(Rect2(i * 86 - 10 + j * 15, 190 - height, 5, 7), Color(color, 0.6))
	for i: int in range(20):
		c.draw_circle(Vector2(fmod(i * 131.0 + t * (3 + i % 4), 720), fmod(i * 73.0, 260)), 1, Color(color, 0.16))
	c.draw_rect(Rect2(0, 225, 720, 255), Color("1a292f"))
	for x: int in range(-360, 1000, 90):
		c.draw_line(Vector2(360 + (x - 360) * 0.3, 225), Vector2(x, 480), Color("344148"), 1)
	for y: float in [249.0, 287.0, 348.0, 441.0]:
		c.draw_line(Vector2(0, y), Vector2(720, y), Color("344148"), 1)
	if id == "yard":
		c.draw_polyline(PackedVector2Array([Vector2(87, 257), Vector2(87, 48), Vector2(362, 48), Vector2(362, 77)]), K.STEEL, 14)
		c.draw_line(Vector2(310, 53), Vector2(310, 171 + sin(t * 0.6) * 8), Color("788084"), 2)
		c.draw_arc(Vector2(310, 179 + sin(t * 0.6) * 8), 18, 0, PI, 16, color, 6)
		for i: int in range(7):
			var p := Vector2(39 + (i % 4) * 88, 278 - (i / 4) * 58)
			_plate(c, Rect2(p, Vector2(70, 49)), Color("4a4a3b") if i % 2 else K.STEEL)
			c.draw_line(p + Vector2(8, 8), p + Vector2(61, 39), Color("786a4b"), 3)
	elif id == "foundry":
		for i: int in range(3):
			_plate(c, Rect2(38 + i * 137, 117, 92, 140), Color("49392e"))
			c.draw_rect(Rect2(50 + i * 137, 148, 68, 54), Color("9c4a27"))
			c.draw_rect(Rect2(59 + i * 137, 156, 50, 37), Color(color, 0.5 + sin(t * 2 + i) * 0.12))
		for y: float in [292.0, 366.0]:
			c.draw_rect(Rect2(0, y, 720, 34), Color("0d171c"))
			for i: int in range(25):
				var x: float = fmod(i * 32 + t * 24, 780) - 32
				c.draw_line(Vector2(x, y + 4), Vector2(x + 10, y + 30), Color("617077"), 5)
	else:
		for i: int in range(4):
			var p := Vector2(90 + i * 115, 235)
			_plate(c, Rect2(p - Vector2(26, 119), Vector2(52, 125)), Color("243f49"))
			c.draw_line(p - Vector2(0, 98), p - Vector2(0, 23), Color(color, 0.65), 13)
		for i: int in range(3):
			c.draw_arc(Vector2(267, 319), 71 + i * 30, t * 0.12 + i, t * 0.12 + i + PI * 1.6, 64, Color(color, 0.2 + i * 0.08), 3, true)
		var beam_y: float = 250 + fmod(t * 24, 169)
		c.draw_line(Vector2(25, beam_y), Vector2(451, beam_y), Color(color, 0.3), 2)
	# Recognizable silhouettes communicate distinct bosses without obscuring the map.
	var p := Vector2(551, 296 + sin(t * 0.8) * 2)
	for side: float in [-1.0, 1.0]:
		c.draw_rect(Rect2(p + Vector2(side * 76 - 22, -15), Vector2(44, 98)), Color("071017"))
		for i: int in range(6):
			c.draw_line(p + Vector2(side * 76 - 16, i * 14 - 7), p + Vector2(side * 76 + 16, i * 14 - 7), K.STEEL, 4)
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(-78, -43), p + Vector2(-46, -78), p + Vector2(47, -78), p + Vector2(80, -41), p + Vector2(65, 60), p + Vector2(-61, 60)]), Color("09131b"))
	c.draw_polyline(PackedVector2Array([p + Vector2(-78, -43), p + Vector2(-46, -78), p + Vector2(47, -78), p + Vector2(80, -41)]), Color(color, 0.65), 3, true)
	c.draw_line(p + Vector2(-37, -36), p + Vector2(37, -36), color, 7)
	if id == "yard":
		for i: int in range(6):
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-62 + i * 22, 28), p + Vector2(-44 + i * 22, 28), p + Vector2(-53 + i * 22, 54)]), Color("677278"))
	elif id == "foundry":
		c.draw_circle(p + Vector2(0, 7), 28, Color("643622"))
		c.draw_circle(p + Vector2(0, 7), 19, color)
	else:
		for side: float in [-1.0, 1.0]:
			c.draw_line(p + Vector2(side * 45, -58), p + Vector2(side * 63, -120), K.STEEL, 10)
			c.draw_circle(p + Vector2(side * 63, -120), 13, color)
	_stripes(c, Rect2(12, 456, 696, 10), color.darkened(0.5))
