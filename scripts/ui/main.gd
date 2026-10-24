extends Control
## UI utama, dibangun lewat kode supaya mudah dibaca dan diubah.
## Header (avatar + sumber daya), 5 halaman, navigasi bawah, toast & efek.

const Data := preload("res://scripts/core/game_data.gd")
const Art := preload("res://scripts/ui/art.gd")
const UI := preload("res://scripts/ui/ui_theme.gd")

const PAGES := [
	{"key": "city", "title": "Kota", "icon": "tab_city", "bg": "city"},
	{"key": "counselor", "title": "Penasihat", "icon": "tab_counselor", "bg": "counselor"},
	{"key": "gacha", "title": "Rekrut", "icon": "tab_gacha", "bg": "gacha"},
	{"key": "campaign", "title": "Kampanye", "icon": "tab_campaign", "bg": "campaign"},
	{"key": "palace", "title": "Istana", "icon": "tab_palace", "bg": "palace"},
]

var model
var _theme: Theme
var _res_labels := {}
var _rank_label: Label
var _power_label: Label
var _pages := {}
var _nav_buttons := {}
var _current := "city"
var _toast: PanelContainer
var _toast_label: Label
var _toast_tween: Tween
var _fx: Control
## key -> {"label": Label, "bar": ProgressBar, "prefix": String}; diperbarui tiap detik.
var _charge_widgets := {}
var _rebuild_queued := false
var _battling := false
var _vs_lord: TextureRect
var _vs_enemy: TextureRect
var _free_button: Button
var _gacha_banner_done := false


func _ready() -> void:
	model = Game.model
	_theme = UI.build()
	theme = _theme

	var bg := TextureRect.new()
	bg.texture = Art.bg("kawung")
	bg.stretch_mode = TextureRect.STRETCH_TILE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	root.add_child(_build_header())

	var page_area := Control.new()
	page_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_area.clip_contents = true
	root.add_child(page_area)
	for p in PAGES:
		var page := _build_page(p)
		page_area.add_child(page["root"])
		_pages[p["key"]] = page

	root.add_child(_build_nav())

	_fx = Control.new()
	_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx)
	_build_toast()

	model.changed.connect(_queue_rebuild)
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_tick)
	add_child(timer)
	_switch_page("city", false)
	_rebuild()


# --- Kerangka -------------------------------------------------------------

func _build_header() -> Control:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "DarkPanel"
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	v.add_child(top)
	top.add_child(_tex(Art.portrait("lord"), 104))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 0)
	top.add_child(info)
	_rank_label = _label(info, "", "TitleLabel")
	_rank_label.add_theme_font_size_override("font_size", 32)
	var power_row := HBoxContainer.new()
	info.add_child(power_row)
	power_row.add_child(_tex(Art.icon("power"), 34))
	_power_label = _label(power_row, "")
	_power_label.add_theme_font_override("font", UI.font_bold)
	var prestige := _chip("prestige")
	prestige.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(prestige)

	var res := HBoxContainer.new()
	res.add_theme_constant_override("separation", 8)
	v.add_child(res)
	for kind in ["silver", "grain", "soldiers", "gold"]:
		var c := _chip(kind)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		res.add_child(c)

	var line := ColorRect.new()
	line.color = UI.GOLD_DARK
	line.custom_minimum_size.y = 3
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 0)
	wrap.add_child(panel)
	wrap.add_child(line)
	return wrap


func _chip(kind: String) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.theme_type_variation = "Chip"
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	chip.add_child(h)
	h.add_child(_tex(Art.icon(kind), 38))
	var l := _label(h, "0")
	l.add_theme_font_override("font", UI.font_bold)
	_res_labels[kind] = l
	return chip


func _build_page(p: Dictionary) -> Dictionary:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)

	var banner := Control.new()
	banner.custom_minimum_size.y = 300 if p["key"] == "campaign" else 220
	banner.clip_contents = true
	root.add_child(banner)
	var pic := TextureRect.new()
	pic.texture = Art.bg(p["bg"])
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	banner.add_child(pic)
	var shade := TextureRect.new()
	var grad := GradientTexture2D.new()
	grad.gradient = Gradient.new()
	grad.gradient.set_color(0, Color(0, 0, 0, 0))
	grad.gradient.set_color(1, Color(0.08, 0.04, 0.02, 0.85))
	grad.fill_from = Vector2(0, 0.35)
	grad.fill_to = Vector2(0, 1)
	shade.texture = grad
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	banner.add_child(shade)
	var title := Label.new()
	title.text = p["title"]
	title.theme_type_variation = "TitleLabel"
	title.position = Vector2(20, banner.custom_minimum_size.y - 62)
	banner.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	scroll.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	margin.add_child(content)
	return {"root": root, "banner": banner, "title": title, "scroll": scroll, "content": content}


func _build_nav() -> Control:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "DarkPanel"
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	panel.add_child(h)
	for p in PAGES:
		var b := Button.new()
		b.theme_type_variation = "NavButton"
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 104
		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 0)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := _tex(Art.icon(p["icon"]), 58)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(icon)
		var l := _label(v, p["title"], "SmallLabel")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(v)
		var key: String = p["key"]
		b.pressed.connect(func():
			Audio.play("click")
			_switch_page(key))
		h.add_child(b)
		_nav_buttons[key] = b
	var line := ColorRect.new()
	line.color = UI.GOLD_DARK
	line.custom_minimum_size.y = 3
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 0)
	wrap.add_child(line)
	wrap.add_child(panel)
	return wrap


func _switch_page(key: String, animate := true) -> void:
	_current = key
	Audio.play_music({"campaign": "battle", "palace": "palace", "gacha": "palace"}.get(key, "city"))
	for k in _pages:
		var on: bool = k == key
		_pages[k]["root"].visible = on
		var b: Button = _nav_buttons[k]
		var style: StyleBox = _theme.get_meta("nav_on") if on else _theme.get_meta("nav_off")
		for s in ["normal", "hover", "pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(s, style)
		b.modulate = Color.WHITE if on else Color(1, 1, 1, 0.65)
	if animate:
		var page: Control = _pages[key]["root"]
		page.modulate.a = 0.0
		create_tween().tween_property(page, "modulate:a", 1.0, 0.18)


func _build_toast() -> void:
	_toast = PanelContainer.new()
	_toast.theme_type_variation = "Toast"
	_toast.anchor_left = 0.05
	_toast.anchor_right = 0.95
	_toast.anchor_top = 1.0
	_toast.anchor_bottom = 1.0
	_toast.offset_top = -250
	_toast.offset_bottom = -140
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.modulate.a = 0.0
	_toast_label = Label.new()
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast.add_child(_toast_label)
	add_child(_toast)


# --- Komponen kecil -------------------------------------------------------

func _tex(t: Texture2D, side: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(side, side)
	return r


func _label(parent: Node, text: String, variation := "") -> Label:
	var l := Label.new()
	l.text = text
	# Wrap hanya di kolom vertikal; di baris/grid label tanpa lebar akan
	# terpotong menjadi satu huruf per baris.
	if parent is VBoxContainer:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if variation != "":
		l.theme_type_variation = variation
	parent.add_child(l)
	return l


func _card(parent: Node) -> HBoxContainer:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	panel.add_child(h)
	return h


func _col(parent: Node) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	parent.add_child(v)
	return v


func _icon_row(parent: Node, icon: String, text: String, color := UI.INK) -> Label:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	parent.add_child(h)
	h.add_child(_tex(Art.icon(icon), 30))
	var l := _label(h, text, "CardLabel")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", color)
	return l


func _bar(parent: Node, value: float, max_value: float, color := Color("d9a540")) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size.y = 14
	b.max_value = max_value
	b.value = value
	var fill: StyleBoxFlat = _theme.get_stylebox("fill", "ProgressBar").duplicate()
	fill.bg_color = color
	b.add_theme_stylebox_override("fill", fill)
	parent.add_child(b)
	return b


## Tombol yang menjalankan aksi model lalu menampilkan hasilnya.
## float_text: tampilkan pesan sukses sebagai teks melayang (untuk hasil cepat).
## sound: efek suara saat berhasil (default "click"); gagal selalu "error".
func _button(parent: Node, text: String, action: Callable, enabled := true, icon := "",
		variation := "", float_text := false, sound := "") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 72)
	b.disabled = not enabled
	if icon != "":
		b.icon = Art.icon(icon)
	if variation != "":
		b.theme_type_variation = variation
	b.pressed.connect(func():
		var result = action.call()
		if not (result is Dictionary) or result.get("ok", true):
			var s := sound if sound != "" else "click"
			if result is Dictionary and result.get("born", false):
				s = "birth"
			Audio.play(s)
		else:
			Audio.play("error")
		if result is Dictionary and result.has("msg"):
			if float_text and result["ok"]:
				_float(result["msg"], b)
			else:
				_show(result))
	parent.add_child(b)
	return b


func _show(result: Dictionary) -> void:
	_toast_label.text = result["msg"]
	_toast_label.add_theme_color_override("font_color", Color("b8f0a8") if result["ok"] else Color("ffb4a6"))
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 0.0
	_toast.pivot_offset = _toast.size / 2
	_toast.scale = Vector2(0.9, 0.9)
	_toast_tween = create_tween()
	_toast_tween.set_parallel()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.15)
	_toast_tween.tween_property(_toast, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.chain().tween_interval(2.6)
	_toast_tween.chain().tween_property(_toast, "modulate:a", 0.0, 0.4)


func _float(text: String, from: Control, color := Color("fff0b0")) -> void:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = "TitleLabel"
	l.add_theme_font_size_override("font_size", 34)
	l.add_theme_color_override("font_color", color)
	_fx.add_child(l)
	l.position = from.get_global_rect().get_center() - Vector2(l.get_minimum_size().x / 2, 40)
	var tw := create_tween().set_parallel()
	tw.tween_property(l, "position:y", l.position.y - 110, 1.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.75).set_delay(0.35)
	tw.chain().tween_callback(l.queue_free)


func _clear(box: Node) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


# --- Render ---------------------------------------------------------------

## Ditunda ke akhir frame supaya tombol yang sedang ditekan tidak dihapus
## di tengah sinyalnya sendiri.
func _queue_rebuild() -> void:
	if not _rebuild_queued:
		_rebuild_queued = true
		_rebuild.call_deferred()


func _rebuild() -> void:
	_rebuild_queued = false
	var scrolls := {}
	for k in _pages:
		scrolls[k] = _pages[k]["scroll"].scroll_vertical
	_charge_widgets.clear()
	_build_city(_pages["city"]["content"])
	_build_counselors(_pages["counselor"]["content"])
	_build_gacha(_pages["gacha"])
	_build_campaign(_pages["campaign"])
	_build_palace(_pages["palace"]["content"])
	_tick()
	# Kembalikan posisi gulir setelah layout dihitung ulang.
	await get_tree().process_frame
	for k in scrolls:
		_pages[k]["scroll"].scroll_vertical = scrolls[k]


func _tick() -> void:
	var now: float = Game.now()
	model.sync(now)
	_rank_label.text = model.rank_info()["name"]
	_power_label.text = "Kekuatan %s" % _num(model.power())
	_res_labels["silver"].text = _num(model.silver)
	_res_labels["grain"].text = _num(model.grain)
	_res_labels["soldiers"].text = _num(model.soldiers)
	_res_labels["prestige"].text = _num(model.prestige)
	_res_labels["gold"].text = _num(model.gold)
	if is_instance_valid(_free_button):
		var free_eta: int = model.free_pull_eta(now)
		_free_button.disabled = free_eta > 0
		_free_button.text = "Rekrut Gratis" if free_eta == 0 else "Gratis lagi %02d:%02d:%02d" % [
			free_eta / 3600, free_eta / 60 % 60, free_eta % 60]
	for key in _charge_widgets:
		var w: Dictionary = _charge_widgets[key]
		if not is_instance_valid(w["label"]):
			continue
		var eta: int = model.charge_eta(key, now)
		w["label"].text = "%s %d/%d%s" % [w["prefix"], model.charge_value(key, now), model.max_charges(),
			"" if eta == 0 else "  ·  +1 dalam %ds" % eta]
		w["bar"].value = model.CHARGE_SECONDS - eta if eta > 0 else model.CHARGE_SECONDS


static func _num(n: int) -> String:
	if n >= 1000000:
		return "%.1fJt" % (n / 1000000.0)
	if n >= 10000:
		return "%.1fRb" % (n / 1000.0)
	return str(n)


func _charge_widget(parent: Node, key: String, prefix: String) -> void:
	var l := _label(parent, "", "CardLabel")
	var bar := _bar(parent, 0, model.CHARGE_SECONDS, Color("6fa8dc"))
	_charge_widgets[key] = {"label": l, "bar": bar, "prefix": prefix}


func _build_city(box: VBoxContainer) -> void:
	_clear(box)
	for kind in model.AFFAIRS:
		var a: Dictionary = model.AFFAIRS[kind]
		var card := _card(box)
		card.add_child(_tex(Art.icon(kind), 92))
		var col := _col(card)
		_label(col, a["label"], "CardTitle")
		_label(col, "Hasil +%d %s · dari %s" % [
			model.affair_yield(kind), model.resource_name(kind), Data.ATTR_NAMES[a["attr"]]], "CardLabel")
		_charge_widget(col, kind, "Urusan")
		var b := _button(card, "Kerjakan", func(): return model.do_affair(kind, Game.now()),
			true, "", "", true, {"silver": "coin", "grain": "grain", "soldiers": "recruit"}[kind])
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.custom_minimum_size.x = 170

	var rank_card := _card(box)
	rank_card.add_child(_tex(Art.icon("prestige"), 92))
	var col := _col(rank_card)
	_label(col, "Jabatan: %s" % model.rank_info()["name"], "CardTitle")
	var nxt: Dictionary = model.next_rank_info()
	if nxt.is_empty():
		_label(col, "Anda telah mencapai jabatan tertinggi!", "CardLabel")
	else:
		_label(col, "Berikutnya %s · prestise %d/%d" % [nxt["name"], model.prestige, nxt["prestige"]], "CardLabel")
		_bar(col, model.prestige, nxt["prestige"])
		var promote := _button(col, "Naik Jabatan", model.promote, model.can_promote(), "", "GoldButton",
			false, "promote")
		promote.add_theme_font_size_override("font_size", 26)

	var sys := _card(box)
	var save := _button(sys, "Simpan", func():
		Game.save_game()
		return {"ok": true, "msg": "Tersimpan"}, true, "", "GreenButton", true)
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(sys, "Mulai Ulang", _confirm_reset).size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var audio := _card(box)
	var music_btn := _button(audio, "", func():
		Audio.set_music_on(not Audio.music_on)
		_queue_rebuild()
		return null, true, "", "GreenButton" if Audio.music_on else "")
	music_btn.text = "Musik: %s" % ("Nyala" if Audio.music_on else "Mati")
	music_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sfx_btn := _button(audio, "", func():
		Audio.set_sfx_on(not Audio.sfx_on)
		_queue_rebuild()
		return null, true, "", "GreenButton" if Audio.sfx_on else "")
	sfx_btn.text = "Suara: %s" % ("Nyala" if Audio.sfx_on else "Mati")
	sfx_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _confirm_reset():
	var dlg := ConfirmationDialog.new()
	dlg.dialog_text = "Hapus semua progres dan mulai dari awal?"
	dlg.ok_button_text = "Hapus"
	dlg.cancel_button_text = "Batal"
	dlg.confirmed.connect(func():
		Game.reset_game()
		_show({"ok": true, "msg": "Game baru dimulai."}))
	dlg.visibility_changed.connect(func():
		if not dlg.visible:
			dlg.queue_free())
	add_child(dlg)
	dlg.popup_centered()
	return null


func _build_counselors(box: VBoxContainer) -> void:
	_clear(box)
	var sum := _card(box)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	sum.add_child(grid)
	for key in Data.ATTRS:
		var l := _label(grid, "%s %s" % [Data.ATTR_NAMES[key], _num(model.total_attr(key))], "CardLabel")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_theme_color_override("font_color", UI.ATTR_COLORS[key])
		l.add_theme_font_override("font", UI.font_bold)

	for id in model.counselors:
		var def: Dictionary = Data.counselor_def(id)
		var card := _card(box)
		var left := VBoxContainer.new()
		left.add_theme_constant_override("separation", 6)
		card.add_child(left)
		left.add_child(_portrait_frame(id, 150))
		_rarity_tag(left, def["rarity"])
		var col := _col(card)
		_label(col, def["name"], "CardTitle")
		_stars(col, int(model.counselors[id].get("stars", 0)))
		var lv: int = model.counselors[id]["level"]
		var cap: int = model.rank_info()["level_cap"]
		_label(col, "Level %d / %d" % [lv, cap], "CardLabel")
		var attrs := GridContainer.new()
		attrs.columns = 2
		attrs.add_theme_constant_override("h_separation", 18)
		col.add_child(attrs)
		for key in Data.ATTRS:
			var l := _label(attrs, "%s %d" % [Data.ATTR_NAMES[key].substr(0, 3).to_upper(), model.attr(id, key)], "CardLabel")
			l.add_theme_color_override("font_color", UI.ATTR_COLORS[key])
			l.add_theme_font_override("font", UI.font_bold)
		var cost: int = model.upgrade_cost(id)
		_button(col, "Latih  %s" % _num(cost), func(): return model.upgrade_counselor(id),
			model.silver >= cost and lv < cap, "silver", "", false, "upgrade")

	for c in Data.COUNSELORS:
		if model.counselors.has(c["id"]):
			continue
		var card := _card(box)
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(110, 110)
		card.add_child(holder)
		var pic := _tex(Art.portrait(c["id"]), 110)
		pic.self_modulate = Color(0.12, 0.08, 0.05)
		holder.add_child(pic)
		var lock := _tex(Art.icon("lock"), 54)
		lock.position = Vector2(28, 28)
		holder.add_child(lock)
		var col := _col(card)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		_label(col, "???", "CardTitle")
		_rarity_tag(col, c["rarity"])
		if int(c["unlock_stage"]) >= 0:
			_label(col, "Bergabung setelah Tahap %d, atau lewat Rekrut" % c["unlock_stage"], "CardLabel")
		else:
			_label(col, "Hanya bisa didapat lewat Rekrut", "CardLabel")


func _build_campaign(page: Dictionary) -> void:
	var info: Dictionary = model.current_stage_info()
	var banner: Control = page["banner"]
	page["title"].text = info["name"]
	if _vs_lord == null:
		_vs_lord = _tex(Art.portrait("lord"), 190)
		_vs_lord.position = Vector2(36, 30)
		banner.add_child(_vs_lord)
		_vs_enemy = _tex(null, 190)
		_vs_enemy.position = Vector2(720 - 36 - 190, 30)
		banner.add_child(_vs_enemy)
		var vs := Label.new()
		vs.text = "VS"
		vs.theme_type_variation = "BigLabel"
		vs.add_theme_color_override("font_color", UI.GOLD)
		vs.position = Vector2(296, 60)
		banner.add_child(vs)
	_vs_enemy.texture = Art.portrait(info["enemy_id"])

	var box: VBoxContainer = page["content"]
	_clear(box)
	var losses: int = model.expected_losses()
	var card := _card(box)
	var col := _col(card)
	_label(col, info["enemy_name"], "CardTitle")
	_icon_row(col, "soldiers", "Prajurit musuh: %s" % _num(info["enemy_soldiers"]))
	_icon_row(col, "power", "Kekuatan musuh %d  ·  Anda %d" % [info["enemy_str"], model.total_attr("str")])
	_icon_row(col, "soldiers", "Perkiraan gugur: %s dari %s prajurit" % [_num(losses), _num(model.soldiers)],
		UI.GREEN.darkened(0.25) if model.soldiers >= losses else UI.RED)
	_icon_row(col, "silver", "Hadiah: %d perak" % info["reward_silver"])
	_icon_row(col, "prestige", "Hadiah: %d prestise" % info["reward_prestige"])
	_icon_row(col, "gold", "Hadiah: %d emas%s" % [info["reward_gold"],
		"  (tahap besar!)" if (model.stage + 1) % 5 == 0 else ""])

	var attack := _button(box, "SERANG!", _attack, true, "", "GoldButton", false, "attack")
	attack.custom_minimum_size.y = 96
	_label(box, "Tips: latih penasihat berkekuatan tinggi agar korban lebih sedikit. "
		+ "Rekrut prajurit di menu Kota.", "SmallLabel")


func _attack():
	if _battling:
		return null
	_battling = true
	var lord := _vs_lord
	var enemy := _vs_enemy
	var lord_x := lord.position.x
	var enemy_x := enemy.position.x
	var tw := create_tween()
	tw.tween_property(lord, "position:x", lord_x + 120, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): enemy.modulate = Color(3, 3, 3))
	for i in 6:
		tw.tween_property(enemy, "position:x", enemy_x + (14 if i % 2 == 0 else -14), 0.04)
	tw.tween_callback(func(): enemy.modulate = Color.WHITE)
	tw.tween_property(enemy, "position:x", enemy_x, 0.04)
	tw.parallel().tween_property(lord, "position:x", lord_x, 0.25)
	tw.tween_callback(func():
		_battling = false
		var result: Dictionary = model.fight_stage()
		_big_result(result["ok"])
		Audio.play("win" if result["ok"] else "lose", 0.0)
		_show(result))
	return null


func _big_result(win: bool) -> void:
	var l := Label.new()
	l.text = "MENANG!" if win else "KALAH..."
	l.theme_type_variation = "BigLabel"
	l.add_theme_color_override("font_color", UI.GOLD if win else Color("e06050"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx.add_child(l)
	l.pivot_offset = size / 2
	l.scale = Vector2(0.3, 0.3)
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.7)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)


# --- Rekrut (gacha) -------------------------------------------------------

static func _rarity_color(rarity: String) -> Color:
	return Color(Data.RARITIES[rarity]["color"])


## Potret dengan bingkai berwarna sesuai kelangkaan; Legenda diberi cahaya.
func _portrait_frame(id: String, side: float, dim := false) -> PanelContainer:
	var rarity: String = Data.counselor_def(id)["rarity"]
	var style := UI.box(Color.TRANSPARENT, _rarity_color(rarity), 5, 22)
	style.set_content_margin_all(3)
	if rarity == "ssr" and not dim:
		style.shadow_color = Color(_rarity_color(rarity), 0.8)
		style.shadow_size = 12
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", style)
	var pic := _tex(Art.portrait(id), side)
	if dim:
		pic.self_modulate = Color(0.25, 0.2, 0.18)
	frame.add_child(pic)
	return frame


func _rarity_tag(parent: Node, rarity: String) -> void:
	var l := _label(parent, Data.RARITIES[rarity]["name"].to_upper(), "SmallLabel")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", UI.font_bold)
	l.add_theme_color_override("font_color", _rarity_color(rarity).darkened(0.15))


func _stars(parent: Node, count: int, side := 26.0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	parent.add_child(row)
	for i in Data.MAX_STARS:
		var st := _tex(Art.icon("star"), side)
		if i >= count:
			st.modulate = Color(0.3, 0.25, 0.2, 0.3)
		row.add_child(st)
	return row


func _build_gacha(page: Dictionary) -> void:
	if not _gacha_banner_done:
		_gacha_banner_done = true
		var banner: Control = page["banner"]
		for i in 2:
			var f := _portrait_frame(["kedaton", "resi"][i], 120)
			f.position = Vector2(30 if i == 0 else 720 - 30 - 132, 30)
			banner.add_child(f)
		page["title"].position.x = 20

	var box: VBoxContainer = page["content"]
	_clear(box)
	var info := _card(box)
	info.add_child(_tex(Art.icon("gold"), 92))
	var col := _col(info)
	_label(col, "Emas: %s" % _num(model.gold), "CardTitle")
	var rates := []
	for r in ["ssr", "sr", "r"]:
		rates.append("%s %d%%" % [Data.RARITIES[r]["name"], int(Data.RARITIES[r]["rate"] * 100)])
	_label(col, " · ".join(rates), "CardLabel")
	_label(col, "Legenda dijamin dalam %d tarikan" % model.pity_left(), "CardLabel")
	_bar(col, Data.GACHA_PITY - model.pity_left(), Data.GACHA_PITY, _rarity_color("ssr"))

	var pulls := _card(box)
	var pcol := _col(pulls)
	_free_button = _button(pcol, "Rekrut Gratis", func(): return _recruit(1, true), true, "tab_gacha",
		"GreenButton", false, "gacha_roll")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	pcol.add_child(row)
	var one := _button(row, "x1  ·  %d" % Data.GACHA_COST, func(): return _recruit(1, false),
		model.gold >= Data.GACHA_COST, "gold", "", false, "gacha_roll")
	one.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ten := _button(row, "x10  ·  %d" % Data.GACHA_COST_10, func(): return _recruit(10, false),
		model.gold >= Data.GACHA_COST_10, "gold", "GoldButton", false, "gacha_roll")
	ten.add_theme_font_size_override("font_size", 26)
	ten.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(pcol, "x10 dijamin minimal satu Epik. Duplikat menambah bintang (+%d%% atribut), "
		% int(Data.STAR_BONUS * 100) + "atau perak bila bintang sudah penuh.", "CardLabel")
	_label(pcol, "Emas didapat dari kampanye (bonus tiap 5 tahap) dan naik jabatan.", "CardLabel")

	var head := _label(box, "Daftar Penasihat", "TitleLabel")
	head.add_theme_font_size_override("font_size", 30)
	var grid_card := PanelContainer.new()
	box.add_child(grid_card)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 12)
	grid_card.add_child(grid)
	for r in ["ssr", "sr", "r"]:
		for c in Data.counselors_of_rarity(r):
			var cell := VBoxContainer.new()
			cell.add_theme_constant_override("separation", 2)
			grid.add_child(cell)
			var owned: bool = model.counselors.has(c["id"])
			cell.add_child(_portrait_frame(c["id"], 136, not owned))
			if owned:
				var stars := _stars(cell, int(model.counselors[c["id"]].get("stars", 0)), 20)
				stars.alignment = BoxContainer.ALIGNMENT_CENTER
			else:
				_rarity_tag(cell, r)


func _recruit(count: int, free: bool):
	var result: Dictionary = model.recruit(count, Game.now(), free)
	if result["ok"]:
		_show_recruit(result["results"])
	return result if not result["ok"] else {"ok": true}


## Layar pengungkapan hasil rekrut dengan animasi.
func _show_recruit(results: Array) -> void:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.01, 0.03, 0.92)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 24)
	overlay.add_child(v)
	var title := _label(v, "Hasil Rekrut", "TitleLabel")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Gulungan bergetar sambil menunggu (suara gulungan dari tombol).
	var scroll := _tex(Art.icon("tab_gacha"), 220)
	scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(scroll)

	var cards: Array = []
	var holder: Container
	if results.size() == 1:
		holder = CenterContainer.new()
		cards.append(_reveal_card(results[0], 300))
		holder.add_child(cards[0])
	else:
		var grid := GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 16)
		for r in results:
			var c := _reveal_card(r, 122)
			cards.append(c)
			grid.add_child(c)
		holder = CenterContainer.new()
		holder.add_child(grid)
	holder.visible = false
	v.add_child(holder)

	var done := Button.new()
	done.text = "Lanjut"
	done.theme_type_variation = "GoldButton"
	done.custom_minimum_size = Vector2(300, 84)
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	done.modulate.a = 0.0
	done.disabled = true
	done.pressed.connect(func():
		Audio.play("click")
		overlay.queue_free())
	v.add_child(done)

	var tw := create_tween()
	scroll.pivot_offset = Vector2(110, 110)
	for i in 8:
		tw.tween_property(scroll, "rotation", 0.12 if i % 2 == 0 else -0.12, 0.07)
	tw.tween_property(scroll, "scale", Vector2(1.3, 1.3), 0.25)
	tw.parallel().tween_property(scroll, "modulate", Color(3, 3, 2, 0), 0.25)
	tw.tween_callback(func():
		scroll.visible = false
		holder.visible = true)
	for c in cards:
		var card: Control = c
		var rarity: String = card.get_meta("rarity")
		tw.tween_callback(func():
			card.pivot_offset = card.size / 2
			Audio.play("reveal_" + rarity if rarity != "r" or cards.size() == 1 else "click"))
		var pop := 0.3 if cards.size() == 1 else 0.16
		tw.tween_property(card, "modulate:a", 1.0, pop * 0.5)
		tw.parallel().tween_property(card, "scale", Vector2.ONE, pop).from(Vector2(0.3, 0.3)) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if cards.size() > 1 and rarity != "r":
			tw.tween_interval(0.3)  # jeda dramatis untuk Epik/Legenda
	tw.tween_callback(func(): done.disabled = false)
	tw.tween_property(done, "modulate:a", 1.0, 0.2)


func _reveal_card(res: Dictionary, side: float) -> Control:
	var rarity: String = res["rarity"]
	var def: Dictionary = Data.counselor_def(res["id"])
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 4)
	card.set_meta("rarity", rarity)
	card.modulate.a = 0.0

	var stage := Control.new()
	stage.custom_minimum_size = Vector2(side + 10, side + 10)
	card.add_child(stage)
	if rarity != "r":
		# Sinar berputar di belakang potret untuk Epik dan Legenda.
		var rays := _tex(Art.icon("rays"), side * 1.5)
		rays.size = Vector2(side * 1.5, side * 1.5)
		rays.position = Vector2(5 + side / 2, 5 + side / 2) - rays.size / 2
		rays.pivot_offset = rays.size / 2
		rays.modulate = Color(_rarity_color(rarity), 0.75 if rarity == "ssr" else 0.45)
		stage.add_child(rays)
		var spin := rays.create_tween().set_loops()
		spin.tween_property(rays, "rotation", TAU, 6.0).from(0.0)
	var frame := _portrait_frame(res["id"], side)
	frame.position = Vector2(0, 0)
	stage.add_child(frame)

	var small := side < 200
	var name_label := _label(card, def["name"], "SmallLabel" if small else "TitleLabel")
	name_label.custom_minimum_size.x = side + 10
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if small:
		name_label.add_theme_font_size_override("font_size", 16)
	else:
		name_label.add_theme_font_size_override("font_size", 30)
	var tag: String = Data.RARITIES[rarity]["name"]
	var status: String = "BARU!" if res["new"] else ("Bintang %d" % res["stars"] if res["stars"] > 0
		else "+%s perak" % _num(res["silver"]))
	var l := _label(card, "%s · %s" % [tag, status] if not small else status, "SmallLabel")
	l.custom_minimum_size.x = side + 10
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", UI.font_bold)
	l.add_theme_color_override("font_color", UI.GOLD if res["new"] else _rarity_color(rarity).lightened(0.3))
	if small:
		l.add_theme_font_size_override("font_size", 15)
	return card


func _build_palace(box: VBoxContainer) -> void:
	_clear(box)
	var energy := _card(box)
	energy.add_child(_tex(Art.icon("heart"), 72))
	var ecol := _col(energy)
	_label(ecol, "Energi Kunjungan", "CardTitle")
	_charge_widget(ecol, "visit", "Energi")

	for id in model.beauties:
		var card := _card(box)
		card.add_child(_tex(Art.portrait(id), 150))
		var col := _col(card)
		_label(col, Data.beauty_def(id)["name"], "CardTitle")
		var intimacy: int = model.beauties[id]["intimacy"]
		_icon_row(col, "heart", "Keakraban %d  ·  +%d Karisma" % [intimacy, intimacy])
		_button(col, "Kunjungi", func(): return model.visit_beauty(id, Game.now()), true, "heart",
			"", false, "heart")

	var head := _label(box, "Anak  (%d/%d kursi)" % [model.children.size(), model.child_seats()], "TitleLabel")
	head.add_theme_font_size_override("font_size", 30)
	if model.children.is_empty():
		_label(box, "Belum ada anak. Kunjungi selir untuk kesempatan mendapat keturunan.", "SmallLabel")
	for i in model.children.size():
		var child: Dictionary = model.children[i]
		var card := _card(box)
		card.add_child(_tex(Art.portrait("child_f" if child.get("gender", "m") == "f" else "child_m"), 124))
		var col := _col(card)
		_label(col, child["name"], "CardTitle")
		var mother: Dictionary = Data.beauty_def(child["mother"])
		if not mother.is_empty():
			_label(col, "Ibu: %s" % mother["name"], "CardLabel")
		var stars := HBoxContainer.new()
		stars.add_theme_constant_override("separation", 2)
		col.add_child(stars)
		for s in 5:
			var st := _tex(Art.icon("star"), 26)
			if s >= int(child["talent"]):
				st.modulate = Color(0.3, 0.25, 0.2, 0.35)
			stars.add_child(st)
		_label(col, "Level %d / %d" % [child["level"], Data.CHILD_MAX_LEVEL], "CardLabel")
		_bar(col, child["level"], Data.CHILD_MAX_LEVEL, Color("8bc34a"))
		if child["level"] < Data.CHILD_MAX_LEVEL:
			var cost: int = model.train_cost(i)
			_button(col, "Didik  %s" % _num(cost), func(): return model.train_child(i), model.grain >= cost, "grain",
				"", false, "upgrade")
		else:
			var marry := _button(col, "Nikahkan", func(): return model.marry_child(i), true, "heart", "GoldButton",
				false, "birth")
			marry.add_theme_font_size_override("font_size", 26)
	_label(box, "Anak yang telah menikah: %d" % model.married_count, "SmallLabel")
