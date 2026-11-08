extends Control
## Tayangan pacuan kuda: enam kuda melaju di lintasan dan finis sesuai urutan yang
## sudah dihitung GameModel.go_race() ("order"), jadi melewatinya tidak mengubah hasil.
##
## Pemakaian: var v := RaceView.new(); v.setup(result); add_child(v)
## result: lanes [{name, horse, me}], order (indeks jalur sesuai urutan finis), place, msg.

signal finished

const Art := preload("res://scripts/ui/art.gd")
const UI := preload("res://scripts/ui/ui_theme.gd")

const BASE_TIME := 4.2  ## detik pemenang mencapai garis finis
const GAP := 0.32  ## selisih waktu antarperingkat

var result: Dictionary

var _canvas: Control
var _time := 0.0
var _ended := false
var _skip_btn: Button
var _finish_time := {}  ## jalur -> detik finis
var _phase := {}  ## jalur -> fase goyangan
var _tex := {}


func setup(race_result: Dictionary) -> void:
	result = race_result


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group("modal")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(result.get("order", []))
	var order: Array = result.get("order", [])
	for k in order.size():
		_finish_time[int(order[k])] = BASE_TIME + GAP * k + rng.randf_range(0.0, 0.08)
	var lanes: Array = result.get("lanes", [])
	for i in lanes.size():
		_phase[i] = rng.randf() * TAU
		_tex[i] = Art.icon("horse_" + str(lanes[i]["horse"]))

	var bg := TextureRect.new()
	bg.texture = Art.bg("racecourse")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_race)
	add_child(_canvas)

	var title := Label.new()
	title.text = "Pacuan Kuda"
	title.theme_type_variation = "TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, size.y * 0.08)
	title.size = Vector2(size.x, 60)
	add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.position = Vector2(0, size.y * 0.88)
	row.size = Vector2(size.x, 80)
	add_child(row)
	_skip_btn = Button.new()
	_skip_btn.text = "Lewati"
	_skip_btn.custom_minimum_size = Vector2(220, 72)
	_skip_btn.pressed.connect(_finish)
	row.add_child(_skip_btn)


func _process(delta: float) -> void:
	if _ended:
		return
	_time += delta * float(Settings.battle_speed)
	var last := 0.0
	for t in _finish_time.values():
		last = maxf(last, t)
	if _time >= last + 0.6:
		_finish()
	_canvas.queue_redraw()


func _track_rect() -> Rect2:
	return Rect2(40, size.y * 0.2, size.x - 80, size.y * 0.6)


## Posisi 0..1 jalur `i` pada waktu t: dipercepat di awal, goyang kecil, tepat 1 saat finis.
func _progress(i: int, t: float) -> float:
	var ft: float = _finish_time.get(i, BASE_TIME)
	var k := clampf(t / ft, 0.0, 1.0)
	var wobble := sin(t * 3.0 + float(_phase[i])) * 0.025 * (1.0 - k) * k * 4.0
	return clampf(k * (2.0 - k) * 0.15 + k * 0.85 + wobble, 0.0, 1.0)


func _draw_race() -> void:
	var track := _track_rect()
	var lanes: Array = result.get("lanes", [])
	var lane_h := track.size.y / maxf(1, lanes.size())
	var finish_x := track.end.x - 30
	for y in range(int(track.position.y), int(track.end.y), 16):
		_canvas.draw_rect(Rect2(finish_x, y, 8, 8), Color.WHITE if (y / 16) % 2 == 0 else Color.BLACK)
		_canvas.draw_rect(Rect2(finish_x + 8, y + 8, 8, 8), Color.WHITE if (y / 16) % 2 == 0 else Color.BLACK)
	var order: Array = result.get("order", [])
	for i in lanes.size():
		var lane: Dictionary = lanes[i]
		var y := track.position.y + lane_h * i
		_canvas.draw_rect(Rect2(track.position.x, y + lane_h - 3, track.size.x, 3), Color(1, 1, 1, 0.5))
		if lane["me"]:
			_canvas.draw_rect(Rect2(track.position.x, y + 2, track.size.x, lane_h - 5), Color(UI.GOLD, 0.25))
		var x := track.position.x + (finish_x - track.position.x - 70) * _progress(i, _time)
		var gallop := absf(sin(_time * 12.0 + float(_phase[i]))) * 6.0 * (0.0 if _time >= float(_finish_time[i]) else 1.0)
		var t: Texture2D = _tex.get(i)
		if t:
			_canvas.draw_texture_rect(t, Rect2(x, y + lane_h - 76 - gallop, 76, 76), false)
		var font := UI.font_bold
		var label := str(lane["name"])
		_canvas.draw_string_outline(font, Vector2(track.position.x + 4, y + 22), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
			6, Color("1e120a"))
		_canvas.draw_string(font, Vector2(track.position.x + 4, y + 22), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
			UI.GOLD if lane["me"] else Color.WHITE)
		if _time >= float(_finish_time[i]):
			var place := order.find(i) + 1
			_canvas.draw_string_outline(font, Vector2(finish_x - 64, y + lane_h - 14), "#%d" % place,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 26, 6, Color("1e120a"))
			_canvas.draw_string(font, Vector2(finish_x - 64, y + lane_h - 14), "#%d" % place, HORIZONTAL_ALIGNMENT_LEFT,
				-1, 26, UI.GOLD if place == 1 else Color.WHITE)


func _finish() -> void:
	if _ended:
		return
	_ended = true
	_time = 999.0
	_canvas.queue_redraw()
	_skip_btn.get_parent().visible = false
	var place := int(result.get("place", 6))
	Audio.play("win" if place <= 3 else "lose", 0.0)
	var panel := PanelContainer.new()
	panel.theme_type_variation = "Toast"
	panel.position = Vector2(30, size.y * 0.3)
	panel.custom_minimum_size.x = size.x - 60
	panel.size.x = size.x - 60
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var big := Label.new()
	big.text = tr("JUARA %d!") % place if place <= 3 else tr("PERINGKAT %d") % place
	big.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	big.theme_type_variation = "BigLabel"
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.add_theme_color_override("font_color", UI.GOLD if place <= 3 else Color("e06050"))
	box.add_child(big)
	UI.fit_font(big, size.x - 60 - 48)
	var detail := Label.new()
	detail.text = str(result.get("msg", ""))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.add_theme_font_size_override("font_size", 20)
	detail.add_theme_color_override("font_color", UI.PARCHMENT)
	box.add_child(detail)
	var ok := Button.new()
	ok.text = "Lanjut"
	ok.theme_type_variation = "GoldButton"
	ok.custom_minimum_size = Vector2(300, 84)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(func():
		Audio.play("click")
		close())
	box.add_child(ok)


func close() -> void:
	finished.emit()
	queue_free()
