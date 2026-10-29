extends Control
## Tayangan duel satu lawan satu: dua petarung saling menerjang bergantian,
## menangkis, menghindar, serangan kritis, dan satu jurus penasihat, lalu hasil.
##
## Seperti BattleView, hasil sudah dihitung GameModel; tayangan hanya mengikuti
## naskah GameModel.duel_plan(). Lewati dan Kecepatan x2 tidak mengubah hasil.
##
## Pemakaian: var v := DuelView.new(); v.setup(plan, info); add_child(v)
## info: title, me_name, them_name, me_portrait, them_portrait, me_total,
##       them_total (nilai HP penuh untuk angka kerusakan), units ([kita, lawan]:
##       "hp" atau "power"), me_weapon, them_weapon ("keris", "tombak", "gada"),
##       them_big (lawan raksasa), win, detail, headline, bg.

signal finished

const Art := preload("res://scripts/ui/art.gd")
const UI := preload("res://scripts/ui/ui_theme.gd")

const ME_COLOR := Color("1f3a5f")
const THEM_COLOR := Color("7a1f1a")
const SKIN := Color("dfa97c")
const BODY := 1.6  ## skala badan terhadap kepala (potret)
const HEAD := 124.0

## Keadaan tiap petarung (Object agar bisa di-tween): dx/dy (geser), tilt (rebah),
## swing (ayunan senjata 0..1), flash (kilat kena pukul), alpha.
class Fighter extends RefCounted:
	var dx := 0.0
	var dy := 0.0
	var tilt := 0.0
	var swing := 0.4
	var flash := 0.0
	var alpha := 1.0


var plan: Dictionary
var info: Dictionary

var _canvas: Control
var _ground := 0.0
var _f: Array[Fighter] = [Fighter.new(), Fighter.new()]
var _heads: Array = []
var _bars: Array = []
var _hp_labels: Array = []
var _sparks: Array = []  ## {pos, t, color}
var _shake := 0.0
var _dark := 0.0
var _flash := 0.0
var _time := 0.0
var _combo := 0
var _combo_label: Label
var _tw: Tween
var _speed_btn: Button
var _skip_btn: Button
var _ended := false
var _rng := RandomNumberGenerator.new()


func setup(duel_plan: Dictionary, duel_info: Dictionary) -> void:
	plan = duel_plan
	info = duel_info


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group("modal")
	_rng.seed = hash(str(info.get("title", ""))) + plan.get("steps", []).size()

	var bg := TextureRect.new()
	bg.texture = Art.bg(str(info.get("bg", "arena")))
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.01, 0.4)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_ground = size.y * 0.64
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_stage)
	add_child(_canvas)
	for side in 2:
		var head := TextureRect.new()
		head.texture = Art.portrait(str(info.get("me_portrait" if side == 0 else "them_portrait", "lord")))
		head.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		head.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var hs := HEAD * _scale(side)
		head.size = Vector2(hs, hs)
		head.pivot_offset = Vector2(hs / 2, hs)
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if side == 1:
			head.flip_h = true
		_canvas.add_child(head)
		_heads.append(head)
	_build_hud()
	_start()


func _scale(side: int) -> float:
	return 1.35 if side == 1 and info.get("them_big", false) else 1.0


func _home_x(side: int) -> float:
	return size.x * (0.27 if side == 0 else 0.73)


func _process(delta: float) -> void:
	var sp := float(Settings.battle_speed)
	_time += delta * sp
	_shake = maxf(0.0, _shake - delta * 3.0)
	_flash = maxf(0.0, _flash - delta * 2.5)
	for f in _f:
		f.flash = maxf(0.0, f.flash - delta * 4.0)
	for s in _sparks:
		s["t"] = float(s["t"]) + delta * 2.2 * sp
	_sparks = _sparks.filter(func(s): return float(s["t"]) < 1.0)
	_canvas.position = Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * _shake * 16.0
	for side in 2:
		var f: Fighter = _f[side]
		var k := _scale(side)
		var hs := HEAD * k
		var base := Vector2(_home_x(side) + float(f.dx), _ground + float(f.dy))
		var neck := base + Vector2(0, -140 * k * BODY).rotated(_tilt(side))
		_heads[side].position = neck - Vector2(hs / 2, hs - 10 * k)
		_heads[side].rotation = _tilt(side)
		_heads[side].modulate = Color(1, 1, 1, f.alpha).lerp(Color(3, 1.2, 1.2, f.alpha), f.flash)
	_canvas.queue_redraw()


func _tilt(side: int) -> float:
	return float(_f[side].tilt) * (-1.0 if side == 0 else 1.0) * PI / 2


# --- Gambar ------------------------------------------------------------------

func _draw_stage() -> void:
	_canvas.draw_rect(Rect2(0, _ground, size.x, size.y - _ground), Color(0.3, 0.2, 0.1, 0.5))
	_canvas.draw_rect(Rect2(0, _ground - 2, size.x, 4), Color(0.85, 0.65, 0.35, 0.6))
	for side in 2:
		_draw_fighter(side)
	for s in _sparks:
		var t: float = s["t"]
		var c: Color = s["color"]
		for i in 8:
			var a := TAU * i / 8.0 + float(s["seed"])
			var p: Vector2 = s["pos"] + Vector2.from_angle(a) * (10 + 50 * t)
			_canvas.draw_line(p, p + Vector2.from_angle(a) * 14 * (1 - t), Color(c, 1 - t), 3)
		_canvas.draw_circle(s["pos"], 18 * (1 - t), Color(1, 1, 0.9, 0.7 * (1 - t)))
	if _dark > 0.0:
		_canvas.draw_rect(Rect2(Vector2(-40, -40), size + Vector2(80, 80)), Color(0, 0, 0, _dark * 0.55))
	if _flash > 0.0:
		_canvas.draw_rect(Rect2(Vector2(-40, -40), size + Vector2(80, 80)), Color(1, 0.92, 0.6, _flash * 0.45))


func _draw_fighter(side: int) -> void:
	var f: Fighter = _f[side]
	var k := _scale(side)
	var dir := 1.0 if side == 0 else -1.0
	var color: Color = ME_COLOR if side == 0 else THEM_COLOR
	if side == 1 and info.get("them_big", false):
		color = Color("3d5a2a")
	var a: float = f.alpha
	var base := Vector2(_home_x(side) + float(f.dx), _ground + float(f.dy))
	_canvas.draw_set_transform(base, _tilt(side), Vector2(k, k) * BODY)
	var lit := color.lerp(Color(1, 0.5, 0.45), f.flash)
	var breath := sin(_time * 3.0 + side) * 2.0
	_canvas.draw_rect(Rect2(-36, -6, 72, 10), Color(0, 0, 0, 0.25 * a))
	# Kaki (kuda-kuda silat)
	_canvas.draw_line(Vector2(-6, -60), Vector2(-26 * dir, 0), Color(color.darkened(0.45), a), 10)
	_canvas.draw_line(Vector2(6, -60), Vector2(22 * dir, 0), Color(color.darkened(0.45), a), 10)
	# Badan dengan sabuk emas
	_canvas.draw_colored_polygon(PackedVector2Array([Vector2(-26, -62), Vector2(26, -62), Vector2(30, -140 + breath),
		Vector2(-30, -140 + breath)]), Color(lit, a))
	_canvas.draw_rect(Rect2(-27, -76, 54, 9), Color(UI.GOLD, a))
	# Lengan belakang & lengan senjata; ayunan memutar lengan senjata
	_canvas.draw_line(Vector2(-14 * dir, -128), Vector2(-34 * dir, -96), Color(SKIN.darkened(0.15), a), 9)
	var swing: float = f.swing
	var ang := lerpf(-1.9, 0.35, swing) if dir > 0 else PI - lerpf(-1.9, 0.35, swing)
	var shoulder := Vector2(16 * dir, -128 + breath)
	var hand := shoulder + Vector2.from_angle(ang) * 46
	_canvas.draw_line(shoulder, hand, Color(SKIN, a), 10)
	_draw_weapon(str(info.get("me_weapon" if side == 0 else "them_weapon", "keris")), hand, ang, a)
	_canvas.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


func _draw_weapon(kind: String, hand: Vector2, ang: float, a: float) -> void:
	var d := Vector2.from_angle(ang)
	var n := d.orthogonal()
	match kind:
		"tombak":
			_canvas.draw_line(hand - d * 50, hand + d * 90, Color(Color("6b4a2a"), a), 5)
			var tip := hand + d * 90
			_canvas.draw_colored_polygon(PackedVector2Array([tip + d * 24, tip + n * 7, tip - n * 7]),
				Color(Color("d8d8d0"), a))
			_canvas.draw_line(tip - d * 2 + n * 8, tip - d * 2 - n * 8, Color(Color("c0392b"), a), 4)
		"gada":
			_canvas.draw_line(hand - d * 10, hand + d * 60, Color(Color("5e3a12"), a), 9)
			_canvas.draw_circle(hand + d * 68, 18, Color(Color("6a6a70"), a))
			for i in 6:
				var sp := hand + d * 68 + Vector2.from_angle(TAU * i / 6.0) * 18
				_canvas.draw_circle(sp, 4, Color(Color("c9c9c9"), a))
		_:
			# Keris berlekuk
			var pts := PackedVector2Array()
			for i in 9:
				var t := float(i) / 8.0
				pts.append(hand + d * (8 + 62 * t) + n * sin(t * TAU * 1.5) * 4.0 * (1.0 - t))
			_canvas.draw_polyline(pts, Color(Color("d8d8d0"), a), 5)
			_canvas.draw_line(hand - n * 9, hand + n * 9, Color(UI.GOLD, a), 5)


# --- HUD ---------------------------------------------------------------------

func _build_hud() -> void:
	var top := VBoxContainer.new()
	top.position = Vector2(24, size.y * 0.06)
	top.custom_minimum_size.x = size.x - 48
	top.add_theme_constant_override("separation", 6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	var title := Label.new()
	title.text = str(info.get("title", ""))
	title.theme_type_variation = "TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	top.add_child(row)
	for side in 2:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		var who := Label.new()
		who.text = str(info.get("me_name" if side == 0 else "them_name", ""))
		who.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		who.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if side == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		who.add_theme_font_override("font", UI.font_bold)
		who.add_theme_font_size_override("font_size", 24)
		who.add_theme_color_override("font_color", Color("fff3d6"))
		col.add_child(who)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size.y = 24
		bar.max_value = 1.0
		bar.step = 0.0
		bar.value = float(plan.get("me_start" if side == 0 else "them_start", 1.0))
		bar.fill_mode = ProgressBar.FILL_BEGIN_TO_END if side == 0 else ProgressBar.FILL_END_TO_BEGIN
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("4caf50") if side == 0 else Color("d9534f")
		fill.set_corner_radius_all(6)
		bar.add_theme_stylebox_override("fill", fill)
		col.add_child(bar)
		_bars.append(bar)
		var hp := Label.new()
		hp.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if side == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		hp.add_theme_font_size_override("font_size", 20)
		hp.add_theme_color_override("font_color", Color("fff3d6"))
		col.add_child(hp)
		_hp_labels.append(hp)
	_set_hp(float(plan.get("me_start", 1.0)), float(plan.get("them_start", 1.0)))

	_combo_label = Label.new()
	_combo_label.add_theme_font_override("font", UI.font_title)
	_combo_label.add_theme_font_size_override("font_size", 40)
	_combo_label.add_theme_color_override("font_color", UI.GOLD)
	_combo_label.add_theme_color_override("font_outline_color", Color(0.2, 0.05, 0))
	_combo_label.add_theme_constant_override("outline_size", 8)
	_combo_label.position = Vector2(24, size.y * 0.27)
	_combo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_combo_label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	buttons.position = Vector2(0, size.y - 140)
	buttons.custom_minimum_size.x = size.x
	add_child(buttons)
	_speed_btn = Button.new()
	_speed_btn.custom_minimum_size = Vector2(170, 72)
	_speed_btn.pressed.connect(_toggle_speed)
	buttons.add_child(_speed_btn)
	_skip_btn = Button.new()
	_skip_btn.text = "Lewati"
	_skip_btn.theme_type_variation = "GoldButton"
	_skip_btn.custom_minimum_size = Vector2(220, 72)
	_skip_btn.pressed.connect(func():
		Audio.play("click")
		skip())
	buttons.add_child(_skip_btn)
	_update_speed_text()


func _set_hp(me: float, them: float) -> void:
	var vals := [me, them]
	var totals := [int(info.get("me_total", 100)), int(info.get("them_total", 100))]
	var units: Array = info.get("units", ["hp", "hp"])
	for i in 2:
		create_tween().tween_property(_bars[i], "value", vals[i], 0.2)
		var n := _fmt(int(round(totals[i] * vals[i])))
		_hp_labels[i].text = tr("Kekuatan %s" % n, "power") if units[i] == "power" else tr("HP %s" % n)


static func _fmt(n: int) -> String:
	if n >= 1000000:
		return "%.1fJt" % (n / 1000000.0)
	if n >= 10000:
		return "%dRb" % int(n / 1000.0)
	return str(n)


# --- Alur --------------------------------------------------------------------

func _start() -> void:
	if Settings.skip_battles:
		skip.call_deferred()
		return
	_tw = create_tween()
	_tw.set_speed_scale(float(Settings.battle_speed))
	_tw.tween_interval(0.5)
	for st in plan.get("steps", []):
		_queue_step(st)
	_tw.tween_interval(0.3)
	_tw.tween_callback(_finish)


func _queue_step(st: Dictionary) -> void:
	var side: int = st["by"]
	var foe := 1 - side
	var dir := 1.0 if side == 0 else -1.0
	var kind: String = st["kind"]
	# Berhenti tepat sebelum lawan agar kepala tidak bertumpuk.
	var reach := absf(_home_x(1) - _home_x(0)) - 150.0 - 60.0 * (_scale(foe) - 1.0) * 2.0
	if kind == "skill":
		var hero: Dictionary = plan.get("hero", {})
		_tw.tween_callback(func(): _callout(hero))
		_tw.tween_property(self, "_dark", 1.0, 0.25)
		_tw.tween_interval(0.7)
	# Ancang-ancang lalu menerjang
	_tw.tween_property(_f[side], "swing", 0.0, 0.12)
	_tw.tween_property(_f[side], "dx", dir * reach, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tw.parallel().tween_property(_f[side], "swing", 1.0, 0.18)
	_tw.tween_callback(func(): _impact(st))
	if kind == "crit" or kind == "skill":
		_tw.tween_interval(0.35)  # jeda "gerak lambat" untuk pukulan besar
	_tw.tween_property(_f[side], "dx", 0.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tw.parallel().tween_property(_f[side], "swing", 0.4, 0.22)
	_tw.parallel().tween_property(_f[foe], "dx", 0.0, 0.22)
	_tw.parallel().tween_property(_f[foe], "dy", 0.0, 0.22)
	if kind == "skill":
		_tw.parallel().tween_property(self, "_dark", 0.0, 0.22)
	_tw.tween_interval(0.12)


func _impact(st: Dictionary) -> void:
	var side: int = st["by"]
	var foe := 1 - side
	var dir := 1.0 if side == 0 else -1.0
	var kind: String = st["kind"]
	var contact := Vector2(_home_x(foe) - dir * 60, _ground - 110 * _scale(foe) * BODY)
	var text := ""
	var color := Color("fff0b0")
	match kind:
		"miss":
			_f[foe].dx = dir * 70.0
			_f[foe].dy = -40.0
			text = tr("Meleset!")
			color = Color("c8d8f0")
			Audio.play("click")
		"block":
			_f[foe].dx = dir * 14.0
			_spark(contact, Color("8fc8ff"))
			text = tr("Ditangkis!")
			color = Color("8fc8ff")
			Audio.play("upgrade")
		_:
			_f[foe].dx = dir * (60.0 if kind != "hit" else 32.0)
			_f[foe].flash = 1.0
			_spark(contact, Color("ffd36b"))
			_shake = 1.2 if kind == "skill" else (1.0 if kind == "crit" else 0.6)
			if kind == "skill":
				_flash = 1.0
				for i in 3:
					_spark(contact + Vector2(_rng.randf_range(-50, 50), _rng.randf_range(-60, 40)), UI.GOLD)
			var total := int(info.get("them_total" if foe == 1 else "me_total", 100))
			text = tr("-" + _fmt(maxi(1, int(round(total * float(st["dmg"]))))))
			if kind == "crit":
				_float_text(tr("KRITIS!"), contact + Vector2(0, -70), Color("ff7a4a"), 44)
			Audio.play("attack")
	_float_text(text, contact, color, 40)
	if side == 0 and kind in ["hit", "crit", "skill"]:
		_combo += 1
	elif side == 1 and kind in ["hit", "crit"]:
		_combo = 0
	_combo_label.text = tr("%d Kombo!") % _combo if _combo >= 2 else ""
	_set_hp(st["me"], st["them"])


func _spark(pos: Vector2, color: Color) -> void:
	_sparks.append({"pos": pos, "t": 0.0, "color": color, "seed": _rng.randf() * TAU})


func _float_text(text: String, pos: Vector2, color: Color, font_size: int) -> void:
	var l := Label.new()
	l.text = text
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.add_theme_font_override("font", UI.font_bold)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.15, 0.05, 0.0))
	l.add_theme_constant_override("outline_size", 8)
	l.position = pos - Vector2(70, 20)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", pos.y - 100, 0.9).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.4)
	tw.tween_callback(l.queue_free)


func _callout(hero: Dictionary) -> void:
	if hero.is_empty():
		return
	var panel := PanelContainer.new()
	panel.theme_type_variation = "Toast"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_to_group("battle_callout")
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var pic := TextureRect.new()
	pic.texture = Art.portrait(str(hero["id"]))
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(110, 110)
	row.add_child(pic)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	var n := Label.new()
	n.text = tr("%s membantu:") % str(hero["name"])
	n.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	n.add_theme_font_override("font", UI.font_bold)
	n.add_theme_font_size_override("font_size", 24)
	n.add_theme_color_override("font_color", Color("fff3d6"))
	col.add_child(n)
	var s := Label.new()
	s.text = tr("%s!") % tr(str(hero["skill"]))
	s.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	s.add_theme_font_override("font", UI.font_title)
	s.add_theme_font_size_override("font_size", 34)
	s.add_theme_color_override("font_color", UI.GOLD)
	col.add_child(s)
	panel.position = Vector2(-460, size.y * 0.33)
	var tw := create_tween()
	tw.set_speed_scale(float(Settings.battle_speed))
	tw.tween_property(panel, "position:x", 20.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.9)
	tw.tween_property(panel, "modulate:a", 0.0, 0.25)
	tw.tween_callback(panel.queue_free)


func _toggle_speed() -> void:
	Audio.play("click")
	Settings.set_value("battle_speed", 1 if Settings.battle_speed == 2 else 2)
	if _tw and _tw.is_valid():
		_tw.set_speed_scale(float(Settings.battle_speed))
	_update_speed_text()


func _update_speed_text() -> void:
	_speed_btn.text = "Kecepatan ×%d" % Settings.battle_speed
	_speed_btn.theme_type_variation = "GreenButton" if Settings.battle_speed == 2 else ""


func skip() -> void:
	if _ended:
		return
	if _tw and _tw.is_valid():
		_tw.kill()
	var steps: Array = plan.get("steps", [])
	if not steps.is_empty():
		_set_hp(steps[-1]["me"], steps[-1]["them"])
	for f in _f:
		f.dx = 0.0
		f.dy = 0.0
		f.swing = 0.4
	_dark = 0.0
	_finish()


func _finish() -> void:
	if _ended:
		return
	_ended = true
	_skip_btn.get_parent().visible = false
	_combo_label.text = ""
	for c in get_tree().get_nodes_in_group("battle_callout"):
		c.queue_free()
	var steps: Array = plan.get("steps", [])
	# Yang kehabisan HP rebah.
	if not steps.is_empty():
		for side in 2:
			if float(steps[-1]["me" if side == 0 else "them"]) <= 0.0:
				create_tween().tween_property(_f[side], "tilt", 0.8, 0.5).set_trans(Tween.TRANS_BOUNCE) \
					.set_ease(Tween.EASE_OUT)
	var win: bool = info.get("win", false)
	Audio.play("win" if win else "lose", 0.0)
	var panel := PanelContainer.new()
	panel.theme_type_variation = "Toast"
	panel.position = Vector2(30, size.y * 0.30)
	panel.custom_minimum_size.x = size.x - 60
	panel.size.x = size.x - 60
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var big := Label.new()
	big.text = str(info.get("headline", "MENANG!" if win else "KALAH..."))
	big.theme_type_variation = "BigLabel"
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.add_theme_color_override("font_color", UI.GOLD if win else Color("e06050"))
	big.text = tr(big.text)  # ukur teks yang benar-benar tampil
	big.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	box.add_child(big)
	UI.fit_font(big, size.x - 60 - 48)
	var detail := Label.new()
	detail.text = str(info.get("detail", ""))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.max_lines_visible = 7
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
	panel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(panel, "modulate:a", 1.0, 0.25)


func close() -> void:
	finished.emit()
	queue_free()
