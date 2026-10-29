extends Control
## Kalender hadiah login 7 hari yang digambar langsung di satu kanvas.
##
## Versi lama (PanelContainer + label membungkus otomatis per sel) membuat game
## crash di sebagian HP Mali. Versi ini sengaja sederhana: tinggi tetap, tanpa
## kontainer bersarang, tanpa label autowrap, tanpa bayangan/tween; hanya
## persegi, ikon, dan teks satu baris yang dikecilkan bila tidak muat.

const UI := preload("res://scripts/ui/ui_theme.gd")
const Art := preload("res://scripts/ui/art.gd")

const CELL_H := 178.0
const GAP := 8.0
const ROWS := [[0, 1, 2, 3], [4, 5, 6]]

## Satu entri per hari: {title, icon (Texture2D), lines (Array[String]), claimed, today, big}
var days: Array = []


func _init() -> void:
	custom_minimum_size = Vector2(0, CELL_H * ROWS.size() + GAP * (ROWS.size() - 1))
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if days.is_empty() or size.x <= 0.0:
		return
	var font := UI.font_bold
	var y := 0.0
	for row in ROWS:
		var units := 0
		for i in row:
			units += 2 if days[i]["big"] else 1
		var unit_w: float = (size.x - GAP * (row.size() - 1)) / units
		var x := 0.0
		for i in row:
			var d: Dictionary = days[i]
			var w: float = unit_w * (2 if d["big"] else 1)
			_draw_cell(Rect2(x, y, w, CELL_H), d, font)
			x += w + GAP
		y += CELL_H + GAP


func _draw_cell(r: Rect2, d: Dictionary, font: Font) -> void:
	var today: bool = d["today"]
	var claimed: bool = d["claimed"]
	var bg := Color("fff3c8") if today else (Color("e2cfa6") if claimed else Color("efe3c6"))
	draw_rect(r, bg)
	draw_rect(r.grow(-1.0 if not today else -2.0), UI.GOLD if today else UI.GOLD_DARK, false, 4.0 if today else 2.0)

	var inner := r.size.x - 12.0
	_text(d["title"], Vector2(r.position.x + r.size.x / 2, r.position.y + 28), inner, 20, font, UI.INK)

	var side := 70.0 if d["big"] else 54.0
	var icon_rect := Rect2(r.position.x + (r.size.x - side) / 2, r.position.y + 38, side, side)
	var tex: Texture2D = d["icon"]
	if tex:
		draw_texture_rect(tex, icon_rect, false, Color(1, 1, 1, 0.45) if claimed else Color.WHITE)
	if claimed:
		var check: Texture2D = Art.icon("check")
		if check:
			draw_texture_rect(check, Rect2(icon_rect.position + Vector2(side * 0.45, side * 0.4),
				Vector2(side, side) * 0.6), false)

	var line_y := r.position.y + 38 + side + 22
	for line in d["lines"]:
		if line_y > r.end.y - 4:
			break
		_text(line, Vector2(r.position.x + r.size.x / 2, line_y), inner, 15, UI.font_body, UI.INK)
		line_y += 19


## Teks satu baris rata tengah; ukuran huruf dikecilkan agar muat di max_w.
func _text(text: String, center: Vector2, max_w: float, font_size: int, font: Font, color: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if w > max_w and w > 0.0:
		font_size = maxi(9, int(font_size * max_w / w))
		w = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2(center.x - w / 2, center.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
