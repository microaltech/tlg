extends Control
## Tayangan perang otomatis: dua barisan prajurit saling menyerbu beberapa ronde,
## penasihat mengeluarkan jurus, korban berjatuhan, lalu hasil ditampilkan.
##
## Hasil pertempuran sudah dihitung GameModel sebelum tayangan dimulai. Tayangan
## hanya mengikuti naskah dari GameModel.battle_plan() (sisa pasukan tiap ronde),
## jadi melewati atau mempercepatnya tidak pernah mengubah hasil.
##
## Pemakaian: var v := BattleView.new(); v.setup(plan, info); add_child(v)
## info: title, me_name, them_name, me_count, them_count, me_portrait,
##       them_portrait, win, detail, bg (nama latar), headline (pengganti
##       MENANG!/KALAH...), units ([pihak kita, lawan]: "soldiers", "power", "hp").

signal finished

const Art := preload("res://scripts/ui/art.gd")
const UI := preload("res://scripts/ui/ui_theme.gd")

const PER_SIDE := 36  ## figur prajurit per pihak
const COLS := 6
const ME_COLOR := Color("3f7fc4")
const THEM_COLOR := Color("b8423a")
const SKIN := Color("e0b088")

var plan: Dictionary
var info: Dictionary

var _canvas: Control
var _units: Array = []  ## {side, home, alive, fall_t, seed}
var _adv := 0.0  ## 0 = di barisan, 1 = bertemu di tengah
var _time := 0.0
var _shake := 0.0
var _flash := 0.0
var _dust: Array = []  ## {pos, t, r}
var _tw: Tween
var _bars: Array = []
var _count_labels: Array = []
var _round_label: Label
var _speed_btn: Button
var _skip_btn: Button
var _end_box: VBoxContainer
var _formation_label: Label
var _ended := false
var _rng := RandomNumberGenerator.new()
var _field := Rect2()


func setup(battle_plan: Dictionary, battle_info: Dictionary) -> void:
	plan = battle_plan
	info = battle_info


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group("modal")
	_rng.seed = hash(info.get("title", "")) + int(info.get("me_count", 0))

	var bg := TextureRect.new()
	bg.texture = Art.bg(str(info.get("bg", "campaign")))
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.03, 0.01, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_field = Rect2(0, size.y * 0.30, size.x, size.y * 0.40)
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_field)
	add_child(_canvas)

	_build_hud()
	_spawn_units()
	_start()


func _process(delta: float) -> void:
	_time += delta * float(Settings.battle_speed)
	_shake = maxf(0.0, _shake - delta * 3.0)
	_flash = maxf(0.0, _flash - delta * 2.5)
	for u in _units:
		if not u["alive"]:
			u["fall_t"] = minf(1.0, float(u["fall_t"]) + delta * 3.0)
	for d in _dust:
		d["t"] = float(d["t"]) + delta * 1.6
	_dust = _dust.filter(func(d): return float(d["t"]) < 1.0)
	_canvas.position = Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * _shake * 14.0
	_canvas.queue_redraw()


# --- Tampilan --------------------------------------------------------------

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
		var head := HBoxContainer.new()
		head.alignment = BoxContainer.ALIGNMENT_BEGIN if side == 0 else BoxContainer.ALIGNMENT_END
		col.add_child(head)
		var pic := TextureRect.new()
		pic.texture = Art.portrait(str(info.get("me_portrait" if side == 0 else "them_portrait", "lord")))
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.custom_minimum_size = Vector2(72, 72)
		var who := Label.new()
		who.text = str(info.get("me_name" if side == 0 else "them_name", ""))
		who.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		who.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if side == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		who.add_theme_font_override("font", UI.font_bold)
		who.add_theme_font_size_override("font_size", 24)
		who.add_theme_color_override("font_color", Color("fff3d6"))
		if side == 0:
			head.add_child(pic)
			head.add_child(who)
		else:
			head.add_child(who)
			head.add_child(pic)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size.y = 20
		bar.max_value = 1.0
		bar.step = 0.0
		bar.value = 1.0
		bar.fill_mode = ProgressBar.FILL_BEGIN_TO_END if side == 0 else ProgressBar.FILL_END_TO_BEGIN
		var fill := StyleBoxFlat.new()
		fill.bg_color = ME_COLOR.lightened(0.15) if side == 0 else THEM_COLOR.lightened(0.1)
		fill.set_corner_radius_all(6)
		bar.add_theme_stylebox_override("fill", fill)
		col.add_child(bar)
		_bars.append(bar)
		var count := Label.new()
		count.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if side == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		count.add_theme_font_size_override("font_size", 20)
		count.add_theme_color_override("font_color", Color("fff3d6"))
		col.add_child(count)
		_count_labels.append(count)
	_set_counts(1.0, 1.0)

	_round_label = Label.new()
	_round_label.theme_type_variation = "TitleLabel"
	_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_round_label.position = Vector2(0, _field.position.y - 56)
	_round_label.custom_minimum_size.x = size.x
	_round_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_round_label)

	var form: Dictionary = preload("res://scripts/core/game_data.gd").FORMATIONS.get(
		str(plan.get("formation", "balanced")), {})
	if not form.is_empty():
		var fl := Label.new()
		fl.text = tr("Formasi: %s") % tr(form["name"])
		fl.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		fl.add_theme_font_size_override("font_size", 20)
		fl.add_theme_color_override("font_color", Color("c8b89a"))
		fl.position = Vector2(24, _field.end.y + 8)
		fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_formation_label = fl
		add_child(fl)

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


func _set_counts(me: float, them: float) -> void:
	var units: Array = info.get("units", ["soldiers", "soldiers"])
	var vals := [me, them]
	var totals := [int(info.get("me_count", 0)), int(info.get("them_count", 0))]
	for i in 2:
		# Diterjemahkan setelah diisi agar angka ringkas (Rb/Jt) ikut diubah ke K/M.
		var n := _fmt(int(round(totals[i] * vals[i])))
		_bars[i].value = vals[i]
		match units[i]:
			"hp":
				_count_labels[i].text = tr("HP %s" % n)
			"power":
				_count_labels[i].text = tr("Kekuatan %s" % n, "power")
			_:
				_count_labels[i].text = tr("%s prajurit" % n)


static func _fmt(n: int) -> String:
	if n >= 1000000:
		return "%.1fJt" % (n / 1000000.0)
	if n >= 10000:
		return "%dRb" % int(n / 1000.0)
	return str(n)


func _spawn_units() -> void:
	var rows := int(ceil(float(PER_SIDE) / COLS))
	var dy := _field.size.y / (rows + 1)
	for side in 2:
		for i in PER_SIDE:
			var c := i % COLS
			var r := i / COLS
			var x := 46.0 + c * 34.0 + (r % 2) * 14.0
			if side == 1:
				x = size.x - x
			_units.append({
				"side": side, "home": Vector2(x, _field.position.y + dy * (r + 1)),
				"alive": true, "fall_t": 0.0, "seed": _rng.randf() * TAU, "col": c, "flag": i % (COLS * 3) == 0,
			})


func _unit_pos(u: Dictionary) -> Vector2:
	if u.has("dead_pos"):
		return u["dead_pos"]
	var home: Vector2 = u["home"]
	# Seluruh barisan maju bersama sampai ujung tombak barisan terdepan bertemu di tengah.
	var front := 46.0 + (COLS - 1) * 34.0 + 14.0
	var reach := size.x / 2.0 - front - 14.0
	var dir := 1.0 if int(u["side"]) == 0 else -1.0
	return home + Vector2(dir * reach * _adv, 0)


func _draw_field() -> void:
	# Tanah medan perang.
	var ground := Rect2(_field.position - Vector2(0, 20), _field.size + Vector2(0, 40))
	_canvas.draw_rect(ground, Color(0.30, 0.20, 0.10, 0.55))
	_canvas.draw_rect(Rect2(ground.position, Vector2(ground.size.x, 4)), Color(0.85, 0.65, 0.35, 0.5))
	_canvas.draw_rect(Rect2(ground.end - Vector2(ground.size.x, 4), Vector2(ground.size.x, 4)),
		Color(0.85, 0.65, 0.35, 0.5))
	# Prajurit gugur di bawah, yang hidup di atas; urut dari belakang ke depan.
	var order := _units.duplicate()
	order.sort_custom(func(a, b):
		if a["alive"] != b["alive"]:
			return not a["alive"]
		return a["home"].y < b["home"].y)
	for u in order:
		_draw_unit(u)
	for d in _dust:
		var t: float = d["t"]
		_canvas.draw_circle(d["pos"] + Vector2(0, -t * 30), float(d["r"]) * (0.6 + t), Color(0.9, 0.82, 0.65, 0.5 * (1.0 - t)))
	if _flash > 0.0:
		_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0.95, 0.7, _flash * 0.35))


func _draw_unit(u: Dictionary) -> void:
	var side := int(u["side"])
	var dir := 1.0 if side == 0 else -1.0
	var p := _unit_pos(u)
	var color := ME_COLOR if side == 0 else THEM_COLOR
	if not u["alive"]:
		var t: float = u["fall_t"]
		var a := lerpf(1.0, 0.7, t)
		_canvas.draw_set_transform(p + Vector2(0, 8 * t), -dir * PI / 2 * t, Vector2.ONE)
		_canvas.draw_rect(Rect2(-5, -16, 10, 16), Color(color.darkened(0.4), a))
		_canvas.draw_circle(Vector2(0, -21), 5, Color(SKIN.darkened(0.3), a))
		_canvas.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		return
	var moving := _adv > 0.02 and _adv < 0.98
	var bob := sin(_time * 14.0 + float(u["seed"])) * (2.5 if moving else 0.8)
	var stride := sin(_time * 14.0 + float(u["seed"])) * (5.0 if moving else 0.0)
	var base := p + Vector2(0, bob * 0.3)
	_canvas.draw_rect(Rect2(base + Vector2(-9, 1), Vector2(18, 4)), Color(0, 0, 0, 0.25))
	# Kaki
	_canvas.draw_line(base + Vector2(-2, -8), base + Vector2(-3 - stride * 0.6, 0), color.darkened(0.5), 3)
	_canvas.draw_line(base + Vector2(2, -8), base + Vector2(3 + stride * 0.6, 0), color.darkened(0.5), 3)
	# Badan & kepala
	var body := base + Vector2(0, -8 + bob)
	_canvas.draw_rect(Rect2(body + Vector2(-6, -14), Vector2(12, 14)), color)
	_canvas.draw_rect(Rect2(body + Vector2(-6, -4), Vector2(12, 3)), Color("e8c070"))
	_canvas.draw_circle(body + Vector2(0, -19), 5.5, SKIN)
	_canvas.draw_arc(body + Vector2(0, -19), 6, PI, TAU, 8, color.darkened(0.35), 3)
	# Tombak; menusuk saat bertemu di tengah
	var thrust := 6.0 if _adv > 0.95 and sin(_time * 18.0 + float(u["seed"])) > 0 else 0.0
	var hand := body + Vector2(dir * 7, -8)
	_canvas.draw_line(hand - Vector2(dir * 10, -6), hand + Vector2(dir * (18 + thrust), -14), Color("6b4a2a"), 2)
	var tip := hand + Vector2(dir * (18 + thrust), -14)
	_canvas.draw_colored_polygon(PackedVector2Array([tip + Vector2(dir * 7, -4), tip + Vector2(-dir * 1, -4),
		tip + Vector2(0, 3)]), Color("d8d8d0"))
	# Perisai untuk formasi bertahan (pihak pemain)
	if side == 0 and str(plan.get("formation", "")) == "defense":
		_canvas.draw_circle(body + Vector2(dir * 8, -6), 6, Color("8a6a3a"))
		_canvas.draw_circle(body + Vector2(dir * 8, -6), 3, Color("e8c070"))
	# Pembawa panji di tengah barisan belakang
	if u["flag"]:
		var pole := body + Vector2(-dir * 4, -4)
		_canvas.draw_line(pole, pole + Vector2(0, -40), Color("6b4a2a"), 2)
		var wave := sin(_time * 6.0) * 3.0
		_canvas.draw_colored_polygon(PackedVector2Array([pole + Vector2(0, -40), pole + Vector2(dir * 22, -36 + wave),
			pole + Vector2(0, -28)]), color.lightened(0.2))


# --- Alur ------------------------------------------------------------------

func _start() -> void:
	if Settings.skip_battles:
		skip.call_deferred()
		return
	var me: Array = plan.get("me", [1.0, 0.0])
	var them: Array = plan.get("them", [1.0, 0.0])
	var skills: Array = plan.get("skills", [])
	var heroes: Array = plan.get("heroes", [])
	_tw = create_tween()
	_tw.set_speed_scale(float(Settings.battle_speed))
	_tw.tween_callback(func(): _round_label.text = tr("Bersiap!"))
	_tw.tween_interval(0.5)
	for k in range(1, me.size()):
		var round_no := k
		_tw.tween_callback(func(): _round_label.text = tr("Ronde %d") % round_no)
		var hero_i: int = skills[k - 1] if k - 1 < skills.size() else -1
		if hero_i >= 0 and hero_i < heroes.size():
			var hero: Dictionary = heroes[hero_i]
			_tw.tween_callback(func(): _callout(hero))
			_tw.tween_interval(0.75)
			_tw.tween_callback(func():
				_flash = 1.0
				Audio.play("upgrade")
				for i in 6:
					_add_dust(Vector2(size.x * 0.62 + _rng.randf_range(-60, 90), _field.position.y
						+ _rng.randf_range(20, _field.size.y - 10)), 18))
		_tw.tween_property(self, "_adv", 1.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		var me_now: float = me[k]
		var them_now: float = them[k]
		var me_prev: float = me[k - 1]
		var them_prev: float = them[k - 1]
		_tw.tween_callback(func(): _clash(me_prev, me_now, them_prev, them_now))
		_tw.tween_interval(0.6)
		_tw.tween_property(self, "_adv", 0.35, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tw.tween_callback(_finish)


func _clash(me_prev: float, me_now: float, them_prev: float, them_now: float) -> void:
	Audio.play("attack")
	_shake = 1.0
	for i in 10:
		_add_dust(Vector2(size.x / 2 + _rng.randf_range(-70, 70), _field.position.y
			+ _rng.randf_range(10, _field.size.y)), _rng.randf_range(10, 22))
	_kill_to(0, me_now)
	_kill_to(1, them_now)
	_set_counts(me_now, them_now)
	var lost := [me_prev - me_now, them_prev - them_now]
	var totals := [int(info.get("me_count", 0)), int(info.get("them_count", 0))]
	for side in 2:
		var n := int(round(totals[side] * lost[side]))
		if n > 0:
			_float_text(tr("-" + _fmt(n)), Vector2(size.x * (0.3 if side == 0 else 0.7), _field.position.y + 20),
				Color("ff9a8a") if side == 0 else Color("fff0b0"))


## Jumlah figur hidup mengikuti sisa pasukan (minimal satu selama belum habis).
func _kill_to(side: int, frac: float) -> void:
	var alive := _units.filter(func(u): return int(u["side"]) == side and u["alive"])
	var target := 0 if frac <= 0.0 else maxi(1, int(ceil(PER_SIDE * frac)))
	# Yang gugur lebih dulu barisan terdepan.
	alive.sort_custom(func(a, b): return int(a["col"]) > int(b["col"]) or (int(a["col"]) == int(b["col"])
		and float(a["seed"]) > float(b["seed"])))
	for i in maxi(0, alive.size() - target):
		alive[i]["dead_pos"] = _unit_pos(alive[i])
		alive[i]["alive"] = false


func _add_dust(pos: Vector2, r: float) -> void:
	_dust.append({"pos": pos, "t": 0.0, "r": r})


func _float_text(text: String, pos: Vector2, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.add_theme_font_override("font", UI.font_bold)
	l.add_theme_font_size_override("font_size", 40)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.15, 0.05, 0.0))
	l.add_theme_constant_override("outline_size", 8)
	l.position = pos - Vector2(60, 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", pos.y - 70, 0.9).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.4)
	tw.tween_callback(l.queue_free)


## Penasihat meluncur masuk dari kiri dan meneriakkan jurusnya.
func _callout(hero: Dictionary) -> void:
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
	n.text = str(hero["name"])
	n.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	n.add_theme_font_override("font", UI.font_bold)
	n.add_theme_font_size_override("font_size", 26)
	n.add_theme_color_override("font_color", Color("fff3d6"))
	col.add_child(n)
	var s := Label.new()
	s.text = tr("%s!") % tr(str(hero["skill"]))
	s.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	s.add_theme_font_override("font", UI.font_title)
	s.add_theme_font_size_override("font_size", 34)
	s.add_theme_color_override("font_color", UI.GOLD)
	col.add_child(s)
	var y := _field.end.y - 60
	panel.position = Vector2(-420, y)
	var tw := create_tween()
	tw.set_speed_scale(float(Settings.battle_speed))
	tw.tween_property(panel, "position:x", 20.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.8)
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


## Lompat ke akhir: keadaan pasukan langsung sesuai hasil.
func skip() -> void:
	if _ended:
		return
	if _tw and _tw.is_valid():
		_tw.kill()
	var me: Array = plan.get("me", [1.0, 0.0])
	var them: Array = plan.get("them", [1.0, 0.0])
	_kill_to(0, me[-1])
	_kill_to(1, them[-1])
	_set_counts(me[-1], them[-1])
	_adv = 0.35
	_finish()


func _finish() -> void:
	if _ended:
		return
	_ended = true
	_skip_btn.get_parent().visible = false
	if _formation_label:
		_formation_label.visible = false
	_round_label.text = ""
	var win: bool = info.get("win", false)
	Audio.play("win" if win else "lose", 0.0)
	for c in get_tree().get_nodes_in_group("battle_callout"):
		c.queue_free()
	var panel := PanelContainer.new()
	panel.theme_type_variation = "Toast"
	panel.position = Vector2(30, _field.position.y + 30)
	panel.custom_minimum_size.x = size.x - 60
	add_child(panel)
	_end_box = VBoxContainer.new()
	_end_box.add_theme_constant_override("separation", 10)
	panel.add_child(_end_box)
	var big := Label.new()
	big.text = str(info.get("headline", "MENANG!" if win else "KALAH..."))
	big.theme_type_variation = "BigLabel"
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.add_theme_color_override("font_color", UI.GOLD if win else Color("e06050"))
	_end_box.add_child(big)
	var detail := Label.new()
	detail.text = str(info.get("detail", ""))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.add_theme_font_size_override("font_size", 20)
	detail.max_lines_visible = 7
	detail.add_theme_color_override("font_color", UI.PARCHMENT)
	_end_box.add_child(detail)
	var ok := Button.new()
	ok.text = "Lanjut"
	ok.theme_type_variation = "GoldButton"
	ok.custom_minimum_size = Vector2(300, 84)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(func():
		Audio.play("click")
		close())
	_end_box.add_child(ok)
	big.pivot_offset = Vector2(panel.custom_minimum_size.x / 2 - 20, 40)
	big.scale = Vector2(0.3, 0.3)
	panel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property(big, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close() -> void:
	finished.emit()
	queue_free()
