extends RefCounted
## Tema visual: kartu perkamen, tombol merah-emas, font Cinzel & Nunito.

const GOLD := Color("e8c070")
const GOLD_DARK := Color("a8742c")
const PARCHMENT := Color("f4e4c1")
const INK := Color("3b2416")
const RED := Color("a8322d")
const GREEN := Color("4f9a4a")
const ATTR_COLORS := {
	"str": Color("c0392b"),
	"int": Color("2e86c1"),
	"pol": Color("27ae60"),
	"cha": Color("c2457a"),
}

static var font_body: Font = load("res://assets/fonts/Nunito-SemiBold.woff2")
static var font_bold: Font = load("res://assets/fonts/Nunito-ExtraBold.woff2")
static var font_title: Font = load("res://assets/fonts/Cinzel-Bold.woff2")


static func box(bg: Color, border := Color.TRANSPARENT, width := 0, radius := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(12)
	s.anti_aliasing = true
	return s


static func _button_styles(t: Theme, type: String, base: Color, edge: Color, font_color: Color) -> void:
	var normal := box(base, GOLD, 2)
	normal.border_width_bottom = 6
	normal.border_color = edge
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	var hover := normal.duplicate()
	hover.bg_color = base.lightened(0.12)
	var pressed := normal.duplicate()
	pressed.bg_color = base.darkened(0.12)
	pressed.border_width_bottom = 2
	pressed.content_margin_top = 16
	var disabled := normal.duplicate()
	disabled.bg_color = Color("7d7064")
	disabled.border_color = Color("4f463e")
	t.set_stylebox("normal", type, normal)
	t.set_stylebox("hover", type, hover)
	t.set_stylebox("pressed", type, pressed)
	t.set_stylebox("hover_pressed", type, pressed)
	t.set_stylebox("disabled", type, disabled)
	t.set_stylebox("focus", type, StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(state, type, font_color)
	t.set_color("font_disabled_color", type, Color("d8cfc4"))
	t.set_font("font", type, font_bold)
	t.set_constant("icon_max_width", type, 34)
	t.set_constant("h_separation", type, 8)


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = font_body
	t.default_font_size = 24

	t.set_color("font_color", "Label", PARCHMENT)

	t.set_type_variation("CardLabel", "Label")
	t.set_color("font_color", "CardLabel", INK)

	t.set_type_variation("CardTitle", "Label")
	t.set_font("font", "CardTitle", font_title)
	t.set_font_size("font_size", "CardTitle", 27)
	t.set_color("font_color", "CardTitle", Color("5e2a12"))

	t.set_type_variation("TitleLabel", "Label")
	t.set_font("font", "TitleLabel", font_title)
	t.set_font_size("font_size", "TitleLabel", 38)
	t.set_color("font_color", "TitleLabel", GOLD)
	t.set_color("font_outline_color", "TitleLabel", Color("1a0e06"))
	t.set_constant("outline_size", "TitleLabel", 10)

	t.set_type_variation("SmallLabel", "Label")
	t.set_font_size("font_size", "SmallLabel", 19)

	t.set_type_variation("BigLabel", "Label")
	t.set_font("font", "BigLabel", font_title)
	t.set_font_size("font_size", "BigLabel", 84)
	t.set_color("font_outline_color", "BigLabel", Color("1a0e06"))
	t.set_constant("outline_size", "BigLabel", 18)

	_button_styles(t, "Button", RED, Color("6b1a12"), Color("fff3d6"))
	t.set_type_variation("GoldButton", "Button")
	_button_styles(t, "GoldButton", Color("d9a540"), Color("7a4b1f"), INK)
	t.set_font_size("font_size", "GoldButton", 34)
	t.set_type_variation("GreenButton", "Button")
	_button_styles(t, "GreenButton", GREEN, Color("2a5a26"), Color("fff3d6"))

	t.set_type_variation("NavButton", "Button")
	var nav := box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 14)
	nav.set_content_margin_all(4)
	var nav_on := box(Color(GOLD, 0.22), GOLD, 2, 14)
	nav_on.set_content_margin_all(4)
	for s in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		t.set_stylebox(s, "NavButton", nav)
	t.set_stylebox("focus", "NavButton", StyleBoxEmpty.new())
	t.set_meta("nav_on", nav_on)
	t.set_meta("nav_off", nav)

	var card := box(PARCHMENT, GOLD_DARK, 3, 16)
	card.shadow_color = Color(0, 0, 0, 0.45)
	card.shadow_size = 6
	card.shadow_offset = Vector2(0, 3)
	card.set_content_margin_all(14)
	t.set_stylebox("panel", "PanelContainer", card)

	t.set_type_variation("DarkPanel", "PanelContainer")
	var dark := box(Color("1e120a", 0.94), GOLD_DARK, 0, 0)
	dark.set_content_margin_all(10)
	t.set_stylebox("panel", "DarkPanel", dark)

	t.set_type_variation("Chip", "PanelContainer")
	var chip := box(Color(0, 0, 0, 0.45), Color(GOLD, 0.7), 2, 22)
	chip.content_margin_left = 8
	chip.content_margin_right = 14
	chip.content_margin_top = 4
	chip.content_margin_bottom = 4
	t.set_stylebox("panel", "Chip", chip)

	t.set_type_variation("Toast", "PanelContainer")
	var toast := box(Color("1e120a", 0.95), GOLD, 3, 18)
	toast.set_content_margin_all(16)
	t.set_stylebox("panel", "Toast", toast)

	var bar_bg := box(Color(0, 0, 0, 0.25), Color.TRANSPARENT, 0, 8)
	bar_bg.set_content_margin_all(0)
	var bar_fill := box(Color("d9a540"), Color.TRANSPARENT, 0, 8)
	bar_fill.set_content_margin_all(0)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)

	var empty := StyleBoxEmpty.new()
	t.set_stylebox("panel", "ScrollContainer", empty)
	return t
