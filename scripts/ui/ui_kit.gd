extends RefCounted
## Shared industrial controls; all visual assets are original geometry.
const INK := Color("ede3ce")
const MUTED := Color("a0afb2")
const GOLD := Color("ffc04d")
const MINT := Color("58d9e7")
const BG := Color("101c24")
const STEEL := Color("334751")
const RUST := Color("f07842")
static var heading_font: FontVariation

static func panel(parent: Control, rect: Rect2, color: Color = Color("1c2c34")) -> Panel:
	var node := Panel.new()
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = STEEL
	style.set_border_width_all(1)
	style.border_width_top = 3
	style.set_corner_radius_all(2)
	node.add_theme_stylebox_override("panel", style)
	parent.add_child(node)
	return node

static func text(parent: Control, rect: Rect2, font_size: int = 16, color: Color = INK) -> Label:
	var node := Label.new()
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	if font_size >= 26:
		if heading_font == null:
			heading_font = FontVariation.new()
			heading_font.base_font = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
			heading_font.variation_embolden = 0.55
		node.add_theme_font_override("font", heading_font)
	parent.add_child(node)
	return node

static func button(parent: Control, rect: Rect2, callback: Callable, primary: bool = false) -> Button:
	var node := Button.new()
	node.position = rect.position
	node.size = rect.size
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.add_theme_font_size_override("font_size", 17)
	node.add_theme_color_override("font_color", BG if primary else INK)
	node.add_theme_color_override("font_hover_color", BG if primary else GOLD)
	node.add_theme_color_override("font_focus_color", BG if primary else INK)
	node.add_theme_color_override("font_pressed_color", BG if primary else GOLD)
	node.add_theme_color_override("font_disabled_color", MUTED)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = GOLD if primary else Color("1d3039")
		style.border_color = GOLD if primary else STEEL
		if state == "hover":
			style.bg_color = Color("ffda86") if primary else Color("344951")
		elif state == "pressed":
			style.bg_color = Color("db9f30") if primary else Color("13232b")
		elif state == "disabled":
			style.bg_color = Color("26343a")
			style.border_color = Color("465258")
		elif state == "focus":
			style.bg_color = Color.TRANSPARENT
			style.border_color = MINT
		style.set_border_width_all(2 if state == "focus" else 1)
		style.border_width_bottom = 3
		style.set_corner_radius_all(2)
		node.add_theme_stylebox_override(state, style)
	if callback.is_valid():
		node.pressed.connect(callback)
	parent.add_child(node)
	return node

static func selected(button_node: Button, active: bool) -> void:
	var style: StyleBoxFlat = button_node.get_theme_stylebox("normal").duplicate()
	style.bg_color = Color("3b3b2c") if active else Color("1d3039")
	style.border_color = GOLD if active else STEEL
	style.border_width_left = 5 if active else 1
	button_node.add_theme_stylebox_override("normal", style)
	var disabled_style: StyleBoxFlat = button_node.get_theme_stylebox("disabled").duplicate()
	disabled_style.bg_color = Color("302f25") if active else Color("26343a")
	disabled_style.border_color = GOLD if active else Color("465258")
	disabled_style.border_width_left = 5 if active else 1
	button_node.add_theme_stylebox_override("disabled", disabled_style)
