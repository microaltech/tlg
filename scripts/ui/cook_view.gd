extends Control
## Mini-game Dapur Nusantara: penanda bergerak bolak-balik di atas tungku; pemain
## menekan "Aduk!" tiga kali. Tiap tekanan saat penanda di zona emas = satu adukan
## tepat. Jumlah adukan tepat (0–3) dikirim ke GameModel.cook lewat callback.
##
## Pemakaian: var v := CookView.new(); v.setup(recipe_id); v.done.connect(func(stars): ...); add_child(v)

signal done(stars: int)

const Art := preload("res://scripts/ui/art.gd")
const UI := preload("res://scripts/ui/ui_theme.gd")
const Data := preload("res://scripts/core/game_data.gd")

const STIRS := 3
const ZONE := [0.4, 0.6]  ## zona emas (posisi 0..1)

var recipe := ""
var _pos := 0.0
var _dir := 1.0
var _speed := 0.9
var _stirs := 0
var _hits := 0
var _results: Array = []  ## true/false per adukan
var _canvas: Control
var _btn: Button
var _info: Label
var _ended := false
var _dish: Texture2D


func setup(recipe_id: String) -> void:
	recipe = recipe_id


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group("modal")
	_dish = Art.icon(str(Data.RECIPES[recipe]["icon"]))
	var shade := ColorRect.new()
	shade.color = Color(0.1, 0.05, 0.02, 0.94)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_kitchen)
	add_child(_canvas)
	var title := Label.new()
	title.text = tr(str(Data.RECIPES[recipe]["name"]))
	title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	title.theme_type_variation = "TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, size.y * 0.08)
	title.size = Vector2(size.x, 60)
	add_child(title)
	_info = Label.new()
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.position = Vector2(30, size.y * 0.15)
	_info.size = Vector2(size.x - 60, 80)
	_info.add_theme_font_size_override("font_size", 22)
	_info.add_theme_color_override("font_color", UI.PARCHMENT)
	_info.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	add_child(_info)
	_btn = Button.new()
	_btn.text = "Aduk!"
	_btn.theme_type_variation = "GoldButton"
	_btn.custom_minimum_size = Vector2(320, 110)
	_btn.add_theme_font_size_override("font_size", 34)
	_btn.position = Vector2(size.x / 2 - 160, size.y * 0.78)
	_btn.size = Vector2(320, 110)
	_btn.pressed.connect(_stir)
	add_child(_btn)
	_update_info()


func _update_info() -> void:
	if _info == null:
		return
	_info.text = tr("Tekan \"Aduk!\" saat penanda di zona emas. Adukan %d/%d · tepat %d") % [_stirs, STIRS, _hits]


func _process(delta: float) -> void:
	if _ended:
		return
	_pos += _dir * _speed * delta
	if _pos >= 1.0:
		_pos = 1.0
		_dir = -1.0
	elif _pos <= 0.0:
		_pos = 0.0
		_dir = 1.0
	_canvas.queue_redraw()


func _stir() -> void:
	if _ended:
		return
	var hit := _pos >= ZONE[0] and _pos <= ZONE[1]
	_results.append(hit)
	_stirs += 1
	if hit:
		_hits += 1
	var audio := get_node_or_null("/root/Audio")
	if audio:
		audio.play("coin" if hit else "click", 0.1)
	_speed *= 1.25  # makin cepat tiap adukan
	_update_info()
	if _stirs >= STIRS:
		_finish()


## Untuk tes: atur posisi penanda lalu aduk.
func stir_at(pos: float) -> void:
	_pos = pos
	_stir()


func _bar_rect() -> Rect2:
	return Rect2(60, size.y * 0.62, size.x - 120, 44)


func _draw_kitchen() -> void:
	# Tungku dan hidangan.
	var c := Vector2(size.x / 2, size.y * 0.42)
	_canvas.draw_circle(c + Vector2(0, 40), 170, Color("3a2412"))
	_canvas.draw_circle(c + Vector2(0, 40), 150, Color("5e3a1e"))
	for i in 5:
		var fx := c.x - 100 + i * 50
		var flick := sin(Time.get_ticks_msec() / 90.0 + i) * 10.0
		_canvas.draw_colored_polygon(PackedVector2Array([Vector2(fx - 18, c.y + 200), Vector2(fx + 18, c.y + 200),
			Vector2(fx, c.y + 140 - flick)]), Color("f2a33a"))
	if _dish:
		var wob := sin(Time.get_ticks_msec() / 200.0) * 0.05 * (0.0 if _ended else 1.0)
		_canvas.draw_set_transform(c, wob, Vector2.ONE)
		_canvas.draw_texture_rect(_dish, Rect2(Vector2(-120, -120), Vector2(240, 240)), false)
		_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Bilah waktu dengan zona emas.
	var r := _bar_rect()
	_canvas.draw_rect(r, Color("2b1d10"))
	_canvas.draw_rect(Rect2(r.position.x + r.size.x * ZONE[0], r.position.y, r.size.x * (ZONE[1] - ZONE[0]), r.size.y),
		UI.GOLD)
	_canvas.draw_rect(r, UI.GOLD_DARK, false, 3.0)
	var x := r.position.x + r.size.x * _pos
	_canvas.draw_rect(Rect2(x - 5, r.position.y - 12, 10, r.size.y + 24), Color.WHITE)
	# Hasil tiap adukan.
	for i in STIRS:
		var p := Vector2(size.x / 2 - 60 + i * 60, r.end.y + 40)
		var col := Color("4a3a2a")
		if i < _results.size():
			col = UI.GOLD if _results[i] else Color("8a3a2a")
		_canvas.draw_circle(p, 18, col)


func _finish() -> void:
	_ended = true
	_btn.disabled = true
	await get_tree().create_timer(0.5).timeout
	done.emit(_hits)
	queue_free()
