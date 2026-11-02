extends Control
## Tayangan perburuan: penasihat membidik buruan yang berlari, panah dilepas
## beberapa kali, lalu buruan rebah (berhasil) atau lolos ke hutan.
##
## Seperti tayangan perang, hasil sudah dihitung GameModel.go_hunt(); tayangan
## hanya mengikuti "plan" ({shots, hit, seed, icon, animal}), jadi melewatinya
## tidak mengubah apa pun.
##
## Pemakaian: var v := HuntView.new(); v.setup(plan, info); add_child(v)
## info: title, portrait (penasihat), win, detail.

signal finished

const Art := preload("res://scripts/ui/art.gd")
const UI := preload("res://scripts/ui/ui_theme.gd")

const SHOT_GAP := 0.9  ## detik antar tembakan
const FLIGHT := 0.45  ## lama panah melayang

var plan: Dictionary
var info: Dictionary

var _canvas: Control
var _time := 0.0
var _rng := RandomNumberGenerator.new()
var _arrows: Array = []  ## {t0, to: Vector2, hit}
var _misses: Array = []  ## titik meleset per tembakan (acak tetap dari seed)
var _ended := false
var _skip_btn: Button
var _hunter_tex: Texture2D
var _animal_tex: Texture2D


func setup(hunt_plan: Dictionary, hunt_info: Dictionary) -> void:
	plan = hunt_plan
	info = hunt_info


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group("modal")
	_rng.seed = int(plan.get("seed", 1))
	_hunter_tex = Art.portrait(str(info.get("portrait", "arya")))
	_animal_tex = Art.icon(str(plan.get("icon", "animal_rusa")))
	for i in int(plan.get("shots", 1)):
		_misses.append(Vector2(_rng.randf_range(-90, 70), _rng.randf_range(-20, 30)))

	var bg := TextureRect.new()
	bg.texture = Art.bg("forest")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.08, 0.03, 0.3)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_scene)
	add_child(_canvas)

	var title := Label.new()
	title.text = str(info.get("title", "Perburuan"))
	title.theme_type_variation = "TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, size.y * 0.12)
	title.size = Vector2(size.x, 60)
	add_child(title)

	var skip_row := HBoxContainer.new()
	skip_row.alignment = BoxContainer.ALIGNMENT_CENTER
	skip_row.position = Vector2(0, size.y * 0.86)
	skip_row.size = Vector2(size.x, 80)
	add_child(skip_row)
	_skip_btn = Button.new()
	_skip_btn.text = "Lewati"
	_skip_btn.custom_minimum_size = Vector2(220, 72)
	_skip_btn.pressed.connect(_finish)
	skip_row.add_child(_skip_btn)


func _end_time() -> float:
	return 0.6 + SHOT_GAP * int(plan.get("shots", 1)) + 0.9


func _process(delta: float) -> void:
	if _ended:
		return
	_time += delta * float(Settings.battle_speed)
	var shots := int(plan.get("shots", 1))
	for i in shots:
		var t0 := 0.6 + SHOT_GAP * i
		if _time >= t0 and _arrows.size() <= i:
			var last := i == shots - 1
			var hit := last and bool(plan.get("hit", false))
			var target: Vector2 = _animal_pos(t0 + FLIGHT) + (Vector2.ZERO if hit else _misses[i])
			_arrows.append({"t0": t0, "from": _hunter_pos() + Vector2(60, -30), "to": target, "hit": hit})
			Audio.play("click", 0.1)
			if hit:
				get_tree().create_timer(FLIGHT / float(Settings.battle_speed)).timeout.connect(func():
					if not _ended:
						Audio.play("win", 0.0))
	if _time >= _end_time():
		_finish()
	_canvas.queue_redraw()


func _ground_y() -> float:
	return size.y * 0.62


func _hunter_pos() -> Vector2:
	return Vector2(size.x * 0.2, _ground_y())


## Buruan berlari ke kanan; bila kena, berhenti di titik kena lalu rebah.
func _animal_pos(t: float) -> Vector2:
	var hit_t := _hit_time()
	if hit_t >= 0.0:
		t = minf(t, hit_t)
	var x := size.x * 0.5 + t * size.x * 0.11
	return Vector2(x, _ground_y() - 10 - absf(sin(t * 9.0)) * 18.0)


func _hit_time() -> float:
	if not bool(plan.get("hit", false)):
		return -1.0
	return 0.6 + SHOT_GAP * (int(plan.get("shots", 1)) - 1) + FLIGHT


func _draw_scene() -> void:
	var hp := _hunter_pos()
	# Pemburu: potret dalam lingkaran dan busur.
	_canvas.draw_circle(hp + Vector2(0, -70), 66, Color("1e120a"))
	if _hunter_tex:
		_canvas.draw_texture_rect(_hunter_tex, Rect2(hp + Vector2(-60, -130), Vector2(120, 120)), false)
	_canvas.draw_arc(hp + Vector2(56, -40), 46, -PI / 2.2, PI / 2.2, 16, Color("7a4b1f"), 6.0)
	_canvas.draw_line(hp + Vector2(56, -40) + Vector2.from_angle(-PI / 2.2) * 46,
		hp + Vector2(56, -40) + Vector2.from_angle(PI / 2.2) * 46, Color("e9d6b0"), 2.0)

	# Buruan.
	var hit_t := _hit_time()
	var ap := _animal_pos(_time)
	var side := 120.0
	var fallen := hit_t >= 0.0 and _time >= hit_t
	var tilt := clampf((_time - hit_t) * 3.0, 0.0, 1.4) if fallen else 0.0
	var escaped := not bool(plan.get("hit", false)) and _time > _end_time() - 0.9
	var alpha := clampf(1.0 - (_time - (_end_time() - 0.9)) * 1.5, 0.0, 1.0) if escaped else 1.0
	if _animal_tex:
		_canvas.draw_set_transform(ap, tilt, Vector2.ONE)
		_canvas.draw_texture_rect(_animal_tex, Rect2(Vector2(-side / 2, -side), Vector2(side, side)), false,
			Color(1, 1, 1, alpha))
		_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Panah: melayang lalu menancap (di buruan bila kena, di tanah bila meleset).
	for a in _arrows:
		var k := clampf((_time - float(a["t0"])) / FLIGHT, 0.0, 1.0)
		var from: Vector2 = a["from"]
		var to: Vector2 = a["to"] if not a["hit"] else ap + Vector2(0, -side * 0.5)
		var pos := from.lerp(to, k) + Vector2(0, -sin(k * PI) * 70.0)
		var dir := (to - from).normalized().rotated(-cos(k * PI) * 0.6) if k < 1.0 else (to - from).normalized()
		_canvas.draw_line(pos - dir * 46, pos, Color("5e3a12"), 4.0)
		_canvas.draw_colored_polygon(PackedVector2Array([pos + dir * 12, pos + dir.orthogonal() * 6,
			pos - dir.orthogonal() * 6]), Color("c9d1da"))
		_canvas.draw_line(pos - dir * 46, pos - dir * 36 + dir.orthogonal() * 8, Color("c0392b"), 3.0)
		_canvas.draw_line(pos - dir * 46, pos - dir * 36 - dir.orthogonal() * 8, Color("c0392b"), 3.0)


func _finish() -> void:
	if _ended:
		return
	_ended = true
	_time = _end_time()
	_canvas.queue_redraw()
	_skip_btn.get_parent().visible = false
	var win: bool = info.get("win", false)
	Audio.play("win" if win else "lose", 0.0)
	var panel := PanelContainer.new()
	panel.theme_type_variation = "Toast"
	panel.position = Vector2(30, size.y * 0.66)
	panel.custom_minimum_size.x = size.x - 60
	panel.size.x = size.x - 60
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var big := Label.new()
	big.text = tr("BURUAN DIDAPAT!" if win else "BURUAN LOLOS...")
	big.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	big.theme_type_variation = "BigLabel"
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.add_theme_color_override("font_color", UI.GOLD if win else Color("e06050"))
	box.add_child(big)
	UI.fit_font(big, size.x - 60 - 48)
	var detail := Label.new()
	detail.text = str(info.get("detail", ""))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.max_lines_visible = 6
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
