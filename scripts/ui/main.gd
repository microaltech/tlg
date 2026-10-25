extends Control
## UI utama, dibangun lewat kode supaya mudah dibaca dan diubah.
## Header (avatar + sumber daya), 7 halaman, navigasi bawah, toast & efek.

const Data := preload("res://scripts/core/game_data.gd")
const Art := preload("res://scripts/ui/art.gd")
const UI := preload("res://scripts/ui/ui_theme.gd")
const TutorialLayer := preload("res://scripts/ui/tutorial_layer.gd")

const PAGES := [
	{"key": "city", "title": "Kota", "icon": "tab_city", "bg": "city"},
	{"key": "counselor", "title": "Penasihat", "icon": "tab_counselor", "bg": "counselor"},
	{"key": "gacha", "title": "Rekrut", "icon": "tab_gacha", "bg": "gacha"},
	{"key": "campaign", "title": "Kampanye", "icon": "tab_campaign", "bg": "campaign"},
	{"key": "palace", "title": "Istana", "icon": "tab_palace", "bg": "palace"},
	{"key": "alliance", "title": "Aliansi", "icon": "tab_alliance", "bg": "alliance"},
	{"key": "arena", "title": "Arena", "icon": "tab_arena", "bg": "arena"},
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
var _mission_hb: Dictionary
var _login_hb: Dictionary
var _mission_overlay: Control
var _login_overlay: Control
var _login_box: VBoxContainer
var _login_subtitle: Label
var _login_next_label: Label
var _login_prompted_day := -1
var _startup_prompted := false  ## true setelah prompt awal (ringkasan/login) pertama kali dicoba.
var _event_overlay: Control
var _event_box: VBoxContainer
var _event_subtitle: Label
## Label hitung mundur event yang diperbarui tiap detik.
var _event_timer_labels: Array = []
var _city_nav_badge: Dictionary
var _alliance_nav_badge: Dictionary
var _alliance_tab := "markas"
var _pending_boss_hit := 0
var _pending_fort_hit := {}
var _chat_list: VBoxContainer
var _chat_scroll: ScrollContainer
var _chat_input: LineEdit
var _chat_draft := ""
var _chat_focus := false
var _chat_shown := 0
var _arena_tab := "lawan"
var _palace_tab := "selir"
var _arena_nav_badge: Dictionary
var _tutorial: Control
## Elemen yang bisa disorot tutorial (diisi saat halaman dibangun).
var _res_row: Control
var _affair_buttons := {}
var _first_upgrade_button: Button
var _attack_button: Button
var _first_visit_button: Button
var _store_overlay: Control
var _store_box: VBoxContainer
var _gold_badge: Dictionary
var _vip_tag: Label
var _vip_badge: Dictionary
var _vip_overlay: Control
var _vip_box: VBoxContainer
var _vip_view := -1
var _lb_hb: Dictionary
var _lb_overlay: Control
var _lb_box: VBoxContainer
var _lb_cat := "power"
var _bag_overlay: Control
var _bag_box: VBoxContainer
var _bag_pick := ""  ## Item yang sedang menunggu pilihan target.
var _equip_overlay: Control
var _equip_box: VBoxContainer
var _equip_pick := -1  ## uid pusaka yang sedang menunggu pilihan penasihat.
var _ad_overlay: Control
var _tower_overlay: Control
var _tower_box: VBoxContainer
var _story_overlay: Control
var _story_box: VBoxContainer  ## Level VIP yang sedang dilihat di panel (-1 = level sekarang).
var _mission_box: VBoxContainer
var _mission_reset_label: Label
var _gacha_banner_done := false
## Tombol Didik anak yang sedang menunggu jeda; diperbarui tiap detik.
var _train_waits: Array = []


## Jarak geser (piksel) sebelum sentuhan dianggap menggulir, bukan mengetuk.
const SCROLL_DEADZONE := 20


func _ready() -> void:
	model = Game.model
	# Agar layar bisa digeser walau jari mulai di atas kartu/tombol: kontrol bawaan
	# Godot "menelan" sentuhan (MOUSE_FILTER_STOP) sehingga ScrollContainer tidak
	# pernah menerimanya. Setiap kontrol baru diubah meneruskan sentuhan ke induknya.
	get_tree().node_added.connect(_on_node_added)
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
	_tutorial = TutorialLayer.new()
	add_child(_tutorial)
	_tutorial.setup(self)

	model.changed.connect(_queue_rebuild)
	Store.purchase_completed.connect(func(r):
		Audio.play("reveal_ssr", 0.0)
		_show(r))
	Store.purchase_failed.connect(func(msg):
		Audio.play("error")
		_show({"ok": false, "msg": msg}))
	Store.prices_updated.connect(_queue_rebuild)
	Ads.ad_started.connect(_on_ad_started)
	Ads.ad_finished.connect(func(r):
		if is_instance_valid(_ad_overlay):
			_ad_overlay.queue_free()
		Audio.play("reveal_sr" if r["ok"] else "error")
		_show(r)
		_queue_rebuild())
	model.mission_completed.connect(func(_text):
		Audio.play("upgrade")
		_float("Misi selesai!", _mission_hb["root"], Color("b8f0a8")))
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_tick)
	add_child(timer)
	_switch_page("city", false)
	_rebuild()
	Game.returned.connect(func():
		if get_tree().get_nodes_in_group("modal").is_empty():
			_maybe_prompt_login())
	# Tampilkan ringkasan kembali lalu hadiah login otomatis setelah layar siap.
	get_tree().create_timer(0.6).timeout.connect(_maybe_prompt_login)


func _notification(what: int) -> void:
	# Label/tombol menerjemahkan ulang dirinya sendiri; bangun ulang halaman agar
	# teks yang dirangkai kode (dan ukuran tata letak) ikut diperbarui.
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_queue_rebuild()


func _on_node_added(node: Node) -> void:
	if not (node is Control) or not is_ancestor_of(node):
		return
	if _tutorial and (node == _tutorial or _tutorial.is_ancestor_of(node)):
		return  # lapisan tutorial memang harus memblokir sentuhan
	if node is ScrollContainer:
		node.scroll_deadzone = SCROLL_DEADZONE
	elif node.mouse_filter == Control.MOUSE_FILTER_STOP:
		node.mouse_filter = Control.MOUSE_FILTER_PASS


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
	top.add_child(_build_avatar())
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 0)
	top.add_child(info)
	_rank_label = _label(info, "", "TitleLabel")
	_rank_label.add_theme_font_size_override("font_size", 24)
	_rank_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_rank_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_rank_label.clip_text = true
	var power_row := HBoxContainer.new()
	info.add_child(power_row)
	power_row.add_child(_tex(Art.icon("power"), 34))
	_power_label = _label(power_row, "")
	_power_label.add_theme_font_override("font", UI.font_bold)
	_power_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # diterjemahkan dengan konteks "power"
	var prestige := _chip("prestige")
	prestige.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(prestige)
	_lb_hb = _header_button("trophy", "Peringkat", _show_leaderboard)
	top.add_child(_lb_hb["root"])
	_login_hb = _header_button("calendar", "Login", _show_login)
	top.add_child(_login_hb["root"])
	_mission_hb = _header_button("mission", "Misi", _show_missions)
	top.add_child(_mission_hb["root"])

	var res := HBoxContainer.new()
	res.add_theme_constant_override("separation", 8)
	v.add_child(res)
	_res_row = res
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
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_res_labels[kind] = l
	if kind == "gold":
		# Tombol "+" membuka toko emas.
		var plus := Button.new()
		plus.theme_type_variation = "NavButton"
		plus.icon = Art.icon("plus")
		plus.expand_icon = true
		plus.custom_minimum_size = Vector2(36, 36)
		plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		plus.pressed.connect(func():
			Audio.play("click")
			_show_store())
		h.add_child(plus)
		_gold_badge = _badge(plus, Vector2(22, -12))
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
		if key == "city":
			_city_nav_badge = _badge(b, Vector2(70, 4))
		elif key == "alliance":
			_alliance_nav_badge = _badge(b, Vector2(70, 4))
		elif key == "arena":
			_arena_nav_badge = _badge(b, Vector2(70, 4))
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
	if _tutorial:
		_tutorial.on_page(key)
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
	# Buang label hitung mundur milik kartu yang sudah dihapus.
	var alive := []
	for l in _event_timer_labels:
		if is_instance_valid(l) and not l.is_queued_for_deletion():
			alive.append(l)
	_event_timer_labels = alive
	_build_city(_pages["city"]["content"])
	_build_counselors(_pages["counselor"]["content"])
	_build_gacha(_pages["gacha"])
	_build_campaign(_pages["campaign"])
	_build_palace(_pages["palace"]["content"])
	_build_alliance(_pages["alliance"]["content"])
	_build_arena(_pages["arena"]["content"])
	if is_instance_valid(_mission_overlay):
		_fill_missions()
	if is_instance_valid(_login_overlay):
		_fill_login()
	if is_instance_valid(_event_overlay):
		_fill_event()
	if is_instance_valid(_store_overlay):
		_fill_store()
	if is_instance_valid(_vip_overlay):
		_fill_vip()
	if is_instance_valid(_lb_overlay):
		_fill_leaderboard()
	if is_instance_valid(_bag_overlay):
		_fill_bag()
	if is_instance_valid(_equip_overlay):
		_fill_equipment()
	if is_instance_valid(_tower_overlay):
		_fill_tower()
	if is_instance_valid(_story_overlay):
		_fill_story()
	_tick()
	# Kembalikan posisi gulir setelah layout dihitung ulang.
	await get_tree().process_frame
	for k in scrolls:
		_pages[k]["scroll"].scroll_vertical = scrolls[k]


func _tick() -> void:
	var now: float = Game.now()
	model.sync(now)
	var honor: Dictionary = model.honor_title()
	_rank_label.text = tr(honor["name"] if not honor.is_empty() else model.rank_info()["name"]) \
		+ (" " + model.lord_name if model.lord_name != "" else "")
	_rank_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # nama Tuan tidak diterjemahkan
	_power_label.text = tr("Kekuatan %s", "power") % _num(model.power())
	_res_labels["silver"].text = _num(model.silver)
	_res_labels["grain"].text = _num(model.grain)
	_res_labels["soldiers"].text = _num(model.soldiers)
	_res_labels["prestige"].text = _num(model.prestige)
	_res_labels["gold"].text = _num(model.gold)
	var claimable: int = model.claimable_count()
	_mission_hb["badge"].visible = claimable > 0
	_mission_hb["badge_label"].text = str(claimable)
	var boss_ready: bool = not model.alliance.is_empty() and model.boss_info(now)["can_claim"]
	boss_ready = boss_ready or not model.war_reward.is_empty()
	var chat_open: bool = is_instance_valid(_chat_list) and _chat_list.is_visible_in_tree()
	if chat_open:
		var count: int = model.chat_messages(now).size()
		if count != _chat_shown:
			_fill_chat_list(now)
	var unread: int = 0 if chat_open else model.chat_unread(now)
	_alliance_nav_badge["badge"].visible = boss_ready or unread > 0
	_alliance_nav_badge["badge_label"].text = str(unread) if unread > 0 else "1"
	var season_ready: bool = not model.arena.is_empty() and not model.arena["season_reward"].is_empty()
	_arena_nav_badge["badge"].visible = season_ready
	_arena_nav_badge["badge_label"].text = "1"
	_vip_tag.text = "VIP %d" % model.vip_level()
	_vip_badge["badge"].visible = model.vip_daily_can_claim(now)
	_vip_badge["badge_label"].text = "!"
	_lb_hb["badge"].visible = not model.leaderboard.get("reward", {}).is_empty()
	_lb_hb["badge_label"].text = "1"
	_gold_badge["badge"].visible = model.card_can_claim(now)
	_gold_badge["badge_label"].text = "1"
	var event_ready: int = model.event_claimable_count()
	_city_nav_badge["badge"].visible = event_ready > 0
	_city_nav_badge["badge_label"].text = str(event_ready)
	var event_left := _duration(model.seconds_until_week_end(now))
	for l in _event_timer_labels:
		if is_instance_valid(l):
			l.text = "Berakhir dalam " + event_left
	if not Game.away.is_empty() and _startup_prompted \
			and get_tree().get_nodes_in_group("modal").is_empty():
		_maybe_prompt_login()
	elif not model.tutorial_active() and get_tree().get_nodes_in_group("modal").is_empty() \
			and not model.pending_intro().is_empty():
		_show_intro(model.pending_intro())
	elif not model.tutorial_active() and get_tree().get_nodes_in_group("modal").is_empty() \
			and model.story_pending_dialog() >= 0:
		_show_story_dialog(model.story_pending_dialog())
	var login_ready: bool = model.login_can_claim(now)
	_login_hb["badge"].visible = login_ready
	_login_hb["badge_label"].text = "1"
	# -1 = startup belum selesai (ditangani timer di _ready); setelah itu
	# pengecekan ini menangani pergantian hari saat game tetap terbuka.
	if login_ready and _login_prompted_day != -1 and _login_prompted_day != model.day_index(now):
		_maybe_prompt_login()
	if is_instance_valid(_login_next_label):
		var wait: int = model.seconds_until_reset(now)
		_login_next_label.text = "Hadiah berikutnya dalam %02d:%02d:%02d" % [wait / 3600, wait / 60 % 60, wait % 60]
	if is_instance_valid(_mission_reset_label):
		var left: int = model.seconds_until_reset(now)
		_mission_reset_label.text = "Reset dalam %02d:%02d:%02d" % [left / 3600, left / 60 % 60, left % 60]
	if is_instance_valid(_free_button):
		var free_eta: int = model.free_pull_eta(now)
		_free_button.disabled = free_eta > 0
		_free_button.text = "Rekrut Gratis" if free_eta == 0 else "Gratis lagi %02d:%02d:%02d" % [
			free_eta / 3600, free_eta / 60 % 60, free_eta % 60]
	for tw in _train_waits:
		if not is_instance_valid(tw["button"]) or tw["index"] >= model.children.size():
			continue
		var wait: int = model.train_wait(tw["index"], now)
		tw["button"].disabled = wait > 0 or model.grain < tw["cost"]
		tw["button"].text = "Istirahat %02d:%02d" % [wait / 60, wait % 60] if wait > 0 \
			else "Didik  %s" % _num(tw["cost"])
	for key in _charge_widgets:
		var w: Dictionary = _charge_widgets[key]
		if not is_instance_valid(w["label"]):
			continue
		var eta: int = model.charge_eta(key, now)
		w["label"].text = "%s %d/%d%s" % [w["prefix"], model.charge_value(key, now), model.max_charges(),
			"" if eta == 0 else "  ·  +1 dalam %ds" % eta]
		w["bar"].value = model.CHARGE_SECONDS - eta if eta > 0 else model.CHARGE_SECONDS


static func _duration(seconds: int) -> String:
	var clock := "%02d:%02d:%02d" % [seconds / 3600 % 24, seconds / 60 % 60, seconds % 60]
	return clock if seconds < 86400 else "%d hari %s" % [seconds / 86400, clock]


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
	box.add_child(_event_banner())
	_build_quick_row(box)
	_build_story_tracker(box)
	for kind in model.AFFAIRS:
		var a: Dictionary = model.AFFAIRS[kind]
		var card := _card(box)
		card.add_child(_tex(Art.icon(kind), 92))
		var col := _col(card)
		_label(col, a["label"], "CardTitle")
		var info := "Hasil +%d %s · dari %s" % [
			model.affair_yield(kind), model.resource_name(kind), Data.ATTR_NAMES[a["attr"]]]
		if kind == "soldiers":
			info += "\nMakan %d pangan" % ceili(model.affair_yield(kind) * Data.SOLDIER_GRAIN)
		_label(col, info, "CardLabel")
		_event_tag(col, "yield_" + kind)
		_charge_widget(col, kind, "Urusan")
		var b := _button(card, "Kerjakan", func(): return model.do_affair(kind, Game.now()),
			true, "", "", true, {"silver": "coin", "grain": "grain", "soldiers": "recruit"}[kind])
		_affair_buttons[kind] = b
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
	var settings := _button(sys, "Pengaturan", func():
		_show_settings()
		return null, true, "settings", "GreenButton")
	settings.add_theme_font_size_override("font_size", 24)
	settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var help := _button(sys, "Panduan", func():
		_show_help()
		return null, true, "help", "GoldButton")
	help.add_theme_font_size_override("font_size", 24)
	help.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _confirm_reset():
	var dlg := ConfirmationDialog.new()
	dlg.add_to_group("modal")
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
	_build_bonds(box)

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
		if Data.SKILLS.has(id):
			var sk: Dictionary = Data.SKILLS[id]
			var skill := _label(col, "%s: %s" % [sk["name"], Data.SKILL_EFFECT_NAMES[sk["effect"]] % roundi(
				model.skill_value(id) * 100)], "SmallLabel")
			skill.add_theme_color_override("font_color", Color("6c3483"))
			skill.add_theme_font_override("font", UI.font_bold)
		var gear := []
		for slot in Data.EQUIP_SLOTS:
			var e: Dictionary = model.equipped(id, slot)
			if not e.is_empty():
				gear.append("%s +%d" % [Data.equip_def(e["id"])["name"], int(e["level"]) - 1])
		if not gear.is_empty():
			_label(col, "Pusaka: %s" % ", ".join(gear), "SmallLabel").add_theme_color_override("font_color", UI.GOLD_DARK)
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
		var train := _button(col, "Latih  %s" % _num(cost), func(): return model.upgrade_counselor(id),
			model.silver >= cost and lv < cap, "silver", "", false, "upgrade")
		if id == model.counselors.keys()[0]:
			_first_upgrade_button = train

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
	_event_tag(col, "losses")
	_icon_row(col, "silver", "Hadiah: %d perak" % info["reward_silver"])
	_icon_row(col, "prestige", "Hadiah: %d prestise" % info["reward_prestige"])
	_icon_row(col, "gold", "Hadiah: %d emas%s" % [info["reward_gold"],
		"  (tahap besar!)" if (model.stage + 1) % 5 == 0 else ""])

	var attack := _button(box, "SERANG!", _attack, true, "", "GoldButton", false, "attack")
	_attack_button = attack
	attack.custom_minimum_size.y = 96
	_label(box, "Tips: latih penasihat berkekuatan tinggi agar korban lebih sedikit. "
		+ "Rekrut prajurit di menu Kota.", "SmallLabel")

	var tower_card := _card(box)
	tower_card.add_child(_tex(Art.icon("tower"), 92))
	var tcol := _col(tower_card)
	_label(tcol, "Menara Ujian", "CardTitle")
	if model.tower_unlocked():
		model.ensure_tower(Game.now())
		_label(tcol, "Lantai minggu ini %d · rekor %d" % [model.tower["floor"], model.tower["best"]], "CardLabel")
		var tb := _button(tower_card, "Masuk", func():
			_show_tower()
			return null, true, "", "GoldButton")
		tb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tb.custom_minimum_size.x = 150
	else:
		_label(tcol, "Terbuka setelah menang Tahap %d." % Data.TOWER_UNLOCK_STAGE, "CardLabel")


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


# --- Misi harian ----------------------------------------------------------

## Halaman tujuan tombol "Pergi" untuk tiap jenis misi.
const MISSION_PAGES := {
	"affair": "city", "affair_silver": "city", "affair_grain": "city", "affair_soldiers": "city",
	"earn_silver": "city", "upgrade": "counselor", "win": "campaign", "visit": "palace",
	"train": "palace", "recruit": "gacha",
}


## Tombol ikon kecil di header dengan lencana angka merah.
## Mengembalikan {"root": Control, "badge": PanelContainer, "badge_label": Label}.
func _header_button(icon_name: String, caption: String, on_press: Callable) -> Dictionary:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(72, 84)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var b := Button.new()
	b.theme_type_variation = "NavButton"
	b.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.pressed.connect(func():
		Audio.play("click")
		on_press.call())
	holder.add_child(b)
	var icon := _tex(Art.icon(icon_name), 58)
	icon.position = Vector2(7, 4)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(icon)
	var cap := Label.new()
	cap.text = caption
	cap.theme_type_variation = "SmallLabel"
	cap.add_theme_font_size_override("font_size", 16)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.position = Vector2(0, 62)
	cap.size = Vector2(72, 20)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(cap)
	var badge := _badge(holder, Vector2(46, -4))
	badge["root"] = holder
	return badge


## Lencana angka merah. Mengembalikan {"badge": PanelContainer, "badge_label": Label}.
func _badge(parent: Control, pos: Vector2) -> Dictionary:
	var badge := PanelContainer.new()
	var red := UI.box(Color("d63a2f"), Color("fff3d6"), 2, 14)
	red.content_margin_left = 8
	red.content_margin_right = 8
	red.content_margin_top = 0
	red.content_margin_bottom = 0
	badge.add_theme_stylebox_override("panel", red)
	badge.position = pos
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.visible = false
	var badge_label := Label.new()
	badge_label.add_theme_font_override("font", UI.font_bold)
	badge_label.add_theme_font_size_override("font_size", 18)
	badge.add_child(badge_label)
	parent.add_child(badge)
	return {"badge": badge, "badge_label": badge_label}


## Panel pop-up perkamen di atas layar dengan judul, subjudul, dan isi bergulir.
## Mengembalikan {"overlay": Control, "content": VBoxContainer, "subtitle": Label}.
func _open_panel(title: String, icon_name: String, on_close: Callable, top := 0.06,
		bottom := 0.94) -> Dictionary:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_to_group("modal")
	add_child(overlay)
	move_child(overlay, _toast.get_index())  # toast tetap di atas panel
	var dim := Button.new()
	dim.flat = true
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim_style := StyleBoxFlat.new()
	dim_style.bg_color = Color(0.04, 0.01, 0.03, 0.82)
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		dim.add_theme_stylebox_override(st, dim_style)
	dim.pressed.connect(on_close)
	overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.03
	panel.anchor_right = 0.97
	panel.anchor_top = top
	panel.anchor_bottom = bottom
	overlay.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	head.add_child(_tex(Art.icon(icon_name), 64))
	var titles := _col(head)
	_label(titles, title, "CardTitle").add_theme_font_size_override("font_size", 32)
	var subtitle := _label(titles, "", "CardLabel")
	var close := Button.new()
	close.text = "Tutup"
	close.custom_minimum_size = Vector2(130, 64)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(on_close)
	head.add_child(close)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)

	panel.pivot_offset = Vector2(size.x * 0.47, size.y * (top + bottom) / 2 - size.y * top)
	panel.scale = Vector2(0.9, 0.9)
	overlay.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(overlay, "modulate:a", 1.0, 0.15)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return {"overlay": overlay, "content": content, "subtitle": subtitle}


func _show_missions() -> void:
	if is_instance_valid(_mission_overlay):
		return
	var p := _open_panel("Misi Harian", "mission", _close_missions)
	_mission_overlay = p["overlay"]
	_mission_box = p["content"]
	_mission_reset_label = p["subtitle"]
	_fill_missions()
	_tick()


func _close_missions() -> void:
	if is_instance_valid(_mission_overlay):
		Audio.play("click")
		_mission_overlay.queue_free()
	_mission_overlay = null


func _fill_missions() -> void:
	_clear(_mission_box)
	var daily: Dictionary = model.daily
	var max_points: int = Data.DAILY_CHESTS[-1]["points"]

	# Peti aktivitas
	var chest_box := _inner_box(_mission_box)
	_label(chest_box, "Poin Aktivitas: %d / %d" % [daily["points"], max_points], "CardLabel") \
		.add_theme_font_override("font", UI.font_bold)
	_bar(chest_box, daily["points"], max_points, Color("e0a030"))
	var chests := HBoxContainer.new()
	chests.add_theme_constant_override("separation", 8)
	chest_box.add_child(chests)
	for i in Data.DAILY_CHESTS.size():
		var def: Dictionary = Data.DAILY_CHESTS[i]
		var opened: bool = daily["chests"][i]
		var ready: bool = model.can_claim_chest(i)
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 2)
		chests.add_child(cell)
		var icon := _tex(Art.icon("chest_open" if opened else "chest"), 84)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if not opened and not ready:
			icon.modulate = Color(0.6, 0.55, 0.5)
		cell.add_child(icon)
		if ready:
			icon.pivot_offset = Vector2(42, 42)
			var bob := icon.create_tween().set_loops()
			bob.tween_property(icon, "scale", Vector2(1.12, 1.12), 0.4)
			bob.tween_property(icon, "scale", Vector2.ONE, 0.4)
		var l := _label(cell, "%d poin" % def["points"], "CardLabel")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var idx: int = i
		var b := _button(cell, "Dibuka" if opened else "Buka", func(): return model.claim_chest(idx),
			ready, "", "GreenButton" if ready else "", false, "reveal_sr")
		b.custom_minimum_size.y = 56
		var reward := _label(cell, _reward_text(def), "SmallLabel")
		reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reward.add_theme_color_override("font_color", UI.INK)
		reward.add_theme_font_size_override("font_size", 16)

	# Daftar misi
	for i in daily["missions"].size():
		var m: Dictionary = daily["missions"][i]
		var def: Dictionary = Data.mission_def(m["id"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_inner_box(_mission_box).add_child(row)
		var col := _col(row)
		_label(col, def["text"], "CardLabel").add_theme_font_override("font", UI.font_bold)
		var target: int = def["target"]
		_bar(col, m["progress"], target, Color("8bc34a") if model.mission_done(i) else Color("d9a540"))
		_label(col, "%s / %s   ·   %s, +%d poin" % [_num(m["progress"]), _num(target), _reward_text(def),
			Data.DAILY_POINTS], "SmallLabel").add_theme_color_override("font_color", UI.INK)
		var idx: int = i
		var b: Button
		if m["claimed"]:
			b = _button(row, "Diambil", func(): return null, false)
		elif model.mission_done(i):
			b = _button(row, "Klaim", func(): return model.claim_mission(idx), true, "", "GreenButton",
				false, "coin")
		else:
			var page: String = MISSION_PAGES.get(def["event"], "city")
			b = _button(row, "Pergi", func():
				_close_missions()
				_switch_page(page)
				return null)
		b.custom_minimum_size = Vector2(140, 64)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER


## Kotak bergaris di dalam panel perkamen.
func _inner_box(parent: Node) -> VBoxContainer:
	var p := PanelContainer.new()
	var st := UI.box(Color(1, 1, 1, 0.35), UI.GOLD_DARK, 2, 12)
	st.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", st)
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	return v


static func _reward_text(def: Dictionary) -> String:
	var parts := []
	for key in Data.REWARD_KEYS:
		if int(def.get(key, 0)) > 0:
			parts.append("+%s %s" % [_num(def[key]), Data.REWARD_NAMES[key]])
	var items: Dictionary = def.get("items", {})
	for id in items:
		parts.append("+%d %s" % [items[id], Data.ITEMS[id]["name"]])
	return ", ".join(parts)


# --- Event mingguan --------------------------------------------------------

## Label kecil "bonus event" di menu yang terpengaruh (kosong bila tidak ada).
func _event_tag(parent: Node, bonus: String) -> void:
	if model.event_bonus(bonus) == 0.0:
		return
	var ev: Dictionary = model.event_def()
	var l := _label(parent, "%s: %s" % [ev["name"], ev["bonus_text"]], "CardLabel")
	l.add_theme_font_override("font", UI.font_bold)
	l.add_theme_color_override("font_color", Color("b5651d"))


func _event_banner() -> Control:
	var ev: Dictionary = model.event_def()
	var holder := Control.new()
	holder.custom_minimum_size.y = 230
	holder.clip_contents = true
	var pic := TextureRect.new()
	pic.texture = Art.bg(ev["bg"])
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(pic)
	var shade := ColorRect.new()
	shade.color = Color(0.08, 0.03, 0.02, 0.62)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(shade)
	var frame := Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_stylebox_override("panel", UI.box(Color.TRANSPARENT, UI.GOLD, 3, 16))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(frame)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 16
	row.offset_right = -16
	row.offset_top = 10
	row.offset_bottom = -10
	row.add_theme_constant_override("separation", 14)
	holder.add_child(row)
	var icon := _tex(Art.icon(ev["icon"]), 110)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var col := _col(row)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	var kicker := _label(col, "EVENT MINGGUAN", "SmallLabel")
	kicker.add_theme_color_override("font_color", UI.GOLD)
	kicker.add_theme_font_override("font", UI.font_bold)
	_label(col, ev["name"], "TitleLabel").add_theme_font_size_override("font_size", 30)
	_label(col, ev["bonus_text"], "SmallLabel")
	var timer := _label(col, "", "SmallLabel")
	timer.add_theme_color_override("font_color", Color("f5d08a"))
	_event_timer_labels.append(timer)
	var ready: int = model.event_claimable_count()
	var status := _label(col, "%d hadiah siap diklaim!" % ready if ready > 0
		else "Poin event: %s" % _num(model.weekly["points"]), "SmallLabel")
	status.add_theme_font_override("font", UI.font_bold)
	status.add_theme_color_override("font_color", Color("b8f0a8") if ready > 0 else UI.PARCHMENT)
	var b := _button(row, "Lihat", func():
		_show_event()
		return null, true, "", "GoldButton")
	b.add_theme_font_size_override("font_size", 24)
	b.custom_minimum_size = Vector2(120, 64)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if ready > 0:
		b.pivot_offset = Vector2(60, 32)
		var pulse := b.create_tween().set_loops()
		pulse.tween_property(b, "scale", Vector2(1.08, 1.08), 0.45)
		pulse.tween_property(b, "scale", Vector2.ONE, 0.45)
	return holder


func _show_event() -> void:
	if is_instance_valid(_event_overlay):
		return
	var ev: Dictionary = model.event_def()
	var p := _open_panel(ev["name"], ev["icon"], _close_event)
	_event_overlay = p["overlay"]
	_event_box = p["content"]
	_event_subtitle = p["subtitle"]
	_event_timer_labels.append(_event_subtitle)
	_fill_event()
	_tick()


func _close_event() -> void:
	if is_instance_valid(_event_overlay):
		Audio.play("click")
		_event_overlay.queue_free()
	_event_overlay = null


func _fill_event() -> void:
	_clear(_event_box)
	var ev: Dictionary = model.event_def()
	var points: int = model.weekly["points"]

	var info := _inner_box(_event_box)
	_label(info, ev["desc"], "CardLabel")
	var bonus := _label(info, "Bonus minggu ini: " + ev["bonus_text"], "CardLabel")
	bonus.add_theme_font_override("font", UI.font_bold)
	bonus.add_theme_color_override("font_color", Color("b5651d"))
	_label(info, "Cara mendapat poin:", "CardLabel").add_theme_font_override("font", UI.font_bold)
	for action in ev["points"]:
		_label(info, "•  %s: +%d poin" % [Data.EVENT_ACTION_NAMES.get(action, action), ev["points"][action]], "CardLabel")
	_label(info, "•  Klaim misi harian: +%d poin" % Data.EVENT_MISSION_POINTS, "CardLabel")

	var progress := _inner_box(_event_box)
	var next_tier := -1
	for i in Data.EVENT_TIERS.size():
		if points < int(Data.EVENT_TIERS[i]["points"]):
			next_tier = i
			break
	var top: int = Data.EVENT_TIERS[-1]["points"]
	_label(progress, "Poin event: %s" % _num(points) + ("" if next_tier < 0
		else "  ·  %s lagi ke hadiah berikutnya" % _num(int(Data.EVENT_TIERS[next_tier]["points"]) - points)),
		"CardLabel").add_theme_font_override("font", UI.font_bold)
	_bar(progress, mini(points, top), top, Color("e0a030"))

	for i in Data.EVENT_TIERS.size():
		var tier: Dictionary = Data.EVENT_TIERS[i]
		var claimed: bool = model.weekly["claimed"][i]
		var ready: bool = model.can_claim_event_tier(i)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_inner_box(_event_box).add_child(row)
		var icon := _tex(Art.icon("chest_open" if claimed else "chest"), 64)
		if not claimed and not ready:
			icon.modulate = Color(0.6, 0.55, 0.5)
		row.add_child(icon)
		var col := _col(row)
		_label(col, "%s poin" % _num(tier["points"]), "CardLabel").add_theme_font_override("font", UI.font_bold)
		_label(col, _reward_text(tier), "SmallLabel").add_theme_color_override("font_color", UI.INK)
		var idx: int = i
		var b: Button
		if claimed:
			b = _button(row, "Diambil", func(): return null, false)
		elif ready:
			b = _button(row, "Klaim", func(): return model.claim_event_tier(idx), true, "", "GreenButton",
				false, "reveal_sr")
		else:
			b = _button(row, "%d%%" % int(100.0 * points / int(tier["points"])), func(): return null, false)
		b.custom_minimum_size = Vector2(130, 60)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER


## Baris tombol sub-tab; tombol aktif berwarna emas. on_select(key) dipanggil lalu UI dibangun ulang.
func _segment_tabs(box: Node, items: Array, current: String, on_select: Callable, font_size := 22) -> void:
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	box.add_child(tabs)
	for t in items:
		var key: String = t[0]
		var b := _button(tabs, t[1], func():
			on_select.call(key)
			_queue_rebuild()
			# Mulai dari atas halaman saat berpindah sub-tab.
			for p in _pages.values():
				if p["root"].visible:
					p["scroll"].scroll_vertical = 0
			return null, true, "", "GoldButton" if current == key else "")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 60)
		b.add_theme_font_size_override("font_size", font_size)
		# Margin samping kecil agar 6 tab tetap muat di layar ponsel.
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			var st: StyleBox = b.get_theme_stylebox(state).duplicate()
			st.content_margin_left = 4
			st.content_margin_right = 4
			b.add_theme_stylebox_override(state, st)


# --- Arena PvP -------------------------------------------------------------

static func _league_index(league: Dictionary) -> int:
	return Data.ARENA_LEAGUES.find(league)


func _build_arena(box: VBoxContainer) -> void:
	_clear(box)
	var now: float = Game.now()
	if not model.arena_unlocked():
		var card := _card(box)
		card.add_child(_tex(Art.icon("lock"), 92))
		var col := _col(card)
		_label(col, "Arena Terkunci", "CardTitle")
		_label(col, "Menangkan Tahap %d di Kampanye untuk membuka Arena." % Data.ARENA_UNLOCK_STAGE, "CardLabel")
		_bar(col, model.stage, Data.ARENA_UNLOCK_STAGE)
		return
	if model.arena.is_empty():
		model.ensure_arena(now)
	var arena: Dictionary = model.arena
	var league: Dictionary = model.arena_league()
	var li := _league_index(league)

	var head := _card(box)
	head.add_child(_tex(Art.icon("league_%d" % li), 110))
	var col := _col(head)
	var league_label := _label(col, "Liga " + league["name"], "CardTitle")
	league_label.add_theme_color_override("font_color", Color(league["color"]).darkened(0.25))
	_label(col, "Poin arena %d · terbaik %d" % [arena["rating"], arena["best"]], "CardLabel")
	if li + 1 < Data.ARENA_LEAGUES.size():
		var nxt: Dictionary = Data.ARENA_LEAGUES[li + 1]
		var lo := int(league["min"])
		_bar(col, int(arena["rating"]) - lo, int(nxt["min"]) - lo, Color(nxt["color"]))
		_label(col, "%d poin lagi ke liga %s" % [int(nxt["min"]) - int(arena["rating"]), nxt["name"]], "SmallLabel") \
			.add_theme_color_override("font_color", UI.INK)
	_label(col, "Menang %d · Kalah %d" % [arena["wins"], arena["losses"]], "CardLabel")
	_icon_row(col, "arena_coin", "Koin arena: %s" % _num(arena["coins"]))

	var season := _inner_box(box)
	var timer := _label(season, "", "CardLabel")
	timer.add_theme_font_override("font", UI.font_bold)
	_event_timer_labels.append(timer)
	_label(season, "Hadiah akhir musim liga %s: %s" % [league["name"], _reward_text(league["reward"])], "CardLabel")
	if not arena["season_reward"].is_empty():
		var sr: Dictionary = arena["season_reward"]
		_button(season, "Klaim hadiah musim lalu (%s)" % sr["league"], func(): return model.claim_arena_season(),
			true, "chest", "GreenButton", false, "reveal_ssr")

	_segment_tabs(box, [["lawan", "Lawan"], ["peringkat", "Peringkat"], ["toko", "Toko"], ["catatan", "Catatan"]],
		_arena_tab, func(key): _arena_tab = key)
	match _arena_tab:
		"peringkat":
			_build_arena_board(box)
		"toko":
			_build_arena_shop(box, now)
		"catatan":
			var log := _inner_box(box)
			_label(log, "Catatan Pertarungan", "CardTitle")
			for line in model.arena["log"].slice(0, 15):
				_label(log, "•  " + line, "SmallLabel").add_theme_color_override("font_color", UI.INK)
		_:
			_build_arena_opponents(box, now)


func _build_arena_opponents(box: VBoxContainer, now: float) -> void:
	var tickets: int = model.arena_tickets_left(now)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	box.add_child(bar)
	var t := PanelContainer.new()
	t.theme_type_variation = "Chip"
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(t)
	var th := HBoxContainer.new()
	t.add_child(th)
	th.add_child(_tex(Art.icon("ticket"), 40))
	_label(th, "Tiket %d" % tickets).add_theme_font_override("font", UI.font_bold)
	var buy := _button(bar, "+1  %d" % Data.ARENA_TICKET_COST, func(): return model.buy_arena_ticket(Game.now()),
		model.gold >= Data.ARENA_TICKET_COST and int(model.arena["tickets_bought"]) < Data.ARENA_TICKET_BUY_MAX,
		"gold", "", false, "coin")
	buy.custom_minimum_size = Vector2(150, 60)
	var refresh := _button(bar, "Segarkan (%d)" % model.arena_refresh_left(), func(): return model.refresh_arena(Game.now()),
		model.arena_refresh_left() > 0)
	refresh.custom_minimum_size = Vector2(190, 60)

	var my_power: int = model.combat_power()
	for i in model.arena["opponents"].size():
		var opp: Dictionary = model.arena["opponents"][i]
		var card := _card(box)
		card.add_child(_tex(Art.portrait(opp["avatar"]), 120))
		var col := _col(card)
		_label(col, opp["name"], "CardTitle")
		var ol: Dictionary = Data.league_of(int(opp["rating"]))
		var row := HBoxContainer.new()
		col.add_child(row)
		row.add_child(_tex(Art.icon("league_%d" % _league_index(ol)), 34))
		_label(row, "%s · %d poin" % [ol["name"], opp["rating"]], "CardLabel")
		var chance: float = model.arena_win_chance(int(opp["power"]))
		var color := UI.GREEN.darkened(0.25) if chance >= 0.6 else (Color("b5651d") if chance >= 0.35 else UI.RED)
		_icon_row(col, "power", "Kekuatan %s (Anda %s)" % [_num(opp["power"]), _num(my_power)], color)
		var stakes: Array = model.arena_stakes(int(opp["rating"]))
		_label(col, "Peluang menang %d%% · menang +%d, kalah -%d" % [roundi(chance * 100), stakes[0], stakes[1]],
			"SmallLabel").add_theme_color_override("font_color", UI.INK)
		var idx: int = i
		_button(col, "Tantang", func():
			var r: Dictionary = model.arena_fight(idx, Game.now())
			if r["ok"]:
				_show_arena_battle(r)
				return null
			return r, tickets > 0, "ticket", "GoldButton", false, "attack").add_theme_font_size_override("font_size", 26)


func _build_arena_board(box: VBoxContainer) -> void:
	var board: Dictionary = model.arena_leaderboard()
	_label(box, "Peringkat Anda: #%d dari %d" % [board["rank"], board["total"]], "TitleLabel") \
		.add_theme_font_size_override("font_size", 28)
	var rows: Array = board["rows"]
	if board["rank"] > rows.size():
		rows = rows + [board["me"]]
	for i in rows.size():
		var e: Dictionary = rows[i]
		var rank: int = i + 1 if i < 10 else board["rank"]
		var inner := _inner_box(box)
		if e["me"]:
			inner.get_parent().add_theme_stylebox_override("panel", UI.box(Color("fff3c8"), UI.GOLD, 3, 12))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		inner.add_child(row)
		var r := _label(row, "#%d" % rank, "CardTitle")
		r.custom_minimum_size.x = 64
		row.add_child(_tex(Art.portrait(e["avatar"]), 56))
		var col := _col(row)
		_label(col, e["name"], "CardLabel").add_theme_font_override("font", UI.font_bold)
		var l: Dictionary = Data.league_of(int(e["rating"]))
		_label(col, "%s · %d poin" % [l["name"], e["rating"]], "SmallLabel").add_theme_color_override("font_color", UI.INK)
		row.add_child(_tex(Art.icon("league_%d" % _league_index(l)), 44))


func _build_arena_shop(box: VBoxContainer, now: float) -> void:
	for item in Data.ARENA_SHOP:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_inner_box(box).add_child(row)
		row.add_child(_tex(Art.icon(item["icon"]), 64))
		var col := _col(row)
		_label(col, item["name"], "CardLabel").add_theme_font_override("font", UI.font_bold)
		var id: String = item["id"]
		var left: int = model.arena_shop_left(id, now)
		_label(col, "%s · sisa %d/%d hari ini" % [_reward_text(item["reward"]), left, item["limit"]], "SmallLabel") \
			.add_theme_color_override("font_color", UI.INK)
		var ok: bool = left > 0 and int(model.arena["coins"]) >= int(item["cost"])
		var b := _button(row, "%d" % item["cost"], func(): return model.arena_shop_buy(id, Game.now()), ok,
			"arena_coin", "GreenButton" if ok else "", false, "coin")
		b.custom_minimum_size = Vector2(130, 60)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER


## Layar pertarungan arena: 3 ronde dengan bar HP, lalu hasil.
func _show_arena_battle(r: Dictionary) -> void:
	var opp: Dictionary = r["opponent"]
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_to_group("modal")
	add_child(overlay)
	move_child(overlay, _toast.get_index())
	var bg := TextureRect.new()
	bg.texture = Art.bg("arena")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.02, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 18)
	overlay.add_child(v)
	var round_label := _label(v, "Bersiap!", "TitleLabel")
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var fighters := HBoxContainer.new()
	fighters.alignment = BoxContainer.ALIGNMENT_CENTER
	fighters.add_theme_constant_override("separation", 40)
	v.add_child(fighters)
	var sides := []
	for who in [[model.me_name(), "lord", model.combat_power()], [opp["name"], opp["avatar"], opp["power"]]]:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		fighters.add_child(col)
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(250, 250)
		col.add_child(holder)
		var pic := _tex(Art.portrait(who[1]), 250)
		holder.add_child(pic)
		var n := _label(col, who[0], "TitleLabel")
		n.add_theme_font_size_override("font_size", 26)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.custom_minimum_size.x = 250
		var hp := _bar(col, 100, 100, Color("4caf50"))
		hp.custom_minimum_size = Vector2(250, 22)
		var p := _label(col, tr("Kekuatan %s", "power") % _num(who[2]), "SmallLabel")
		p.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		p.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sides.append({"pic": pic, "hp": hp})

	var result_label := _label(v, "", "BigLabel")
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.modulate.a = 0.0
	var detail := _label(v, "", "CardLabel")
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.add_theme_color_override("font_color", UI.PARCHMENT)
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

	var rounds: Array = r["rounds"]
	var tw := create_tween()
	tw.tween_interval(0.4)
	for k in range(1, rounds.size()):
		var state: Dictionary = rounds[k]
		tw.tween_callback(func():
			round_label.text = "Ronde %d" % k
			Audio.play("attack"))
		for s_i in 2:
			var side: Dictionary = sides[s_i]
			var pic: TextureRect = side["pic"]
			var target: int = state["me"] if s_i == 0 else state["them"]
			tw.tween_callback(func(): pic.modulate = Color(3, 2.5, 2.5))
			tw.tween_property(pic, "position:x", 10.0 if s_i == 0 else -10.0, 0.05)
			tw.tween_property(pic, "position:x", 0.0, 0.05)
			tw.tween_callback(func(): pic.modulate = Color.WHITE)
			tw.tween_property(side["hp"], "value", float(target), 0.25)
		tw.tween_interval(0.35)
	tw.tween_callback(func():
		var win: bool = r["win"]
		round_label.text = "Selesai"
		result_label.text = "MENANG!" if win else "KALAH..."
		result_label.add_theme_color_override("font_color", UI.GOLD if win else Color("e06050"))
		detail.text = "%+d poin arena · +%d koin arena%s" % [r["delta"], r["coins"],
			" · +%d perak" % Data.ARENA_WIN["silver"] if win else ""]
		Audio.play("win" if win else "lose", 0.0)
		var loser: TextureRect = sides[1 if win else 0]["pic"]
		loser.modulate = Color(0.45, 0.45, 0.45)
		done.disabled = false)
	tw.tween_property(result_label, "modulate:a", 1.0, 0.25)
	tw.tween_property(done, "modulate:a", 1.0, 0.2)


# --- Aliansi ---------------------------------------------------------------

func _build_alliance(box: VBoxContainer) -> void:
	_clear(box)
	var now: float = Game.now()
	if not model.alliance_unlocked():
		var card := _card(box)
		card.add_child(_tex(Art.icon("lock"), 92))
		var col := _col(card)
		_label(col, "Aliansi Terkunci", "CardTitle")
		_label(col, "Menangkan Tahap %d di Kampanye untuk membuka Aliansi." % Data.ALLIANCE_UNLOCK_STAGE, "CardLabel")
		_bar(col, model.stage, Data.ALLIANCE_UNLOCK_STAGE)
		return
	if model.alliance.is_empty():
		_build_alliance_choices(box, now)
		return

	if _alliance_tab != "chat":
		_build_alliance_header(box)
	var unread: int = model.chat_unread(now) if _alliance_tab != "chat" else 0
	_segment_tabs(box, [["markas", "Markas"], ["bos", "Bos"], ["perang", "Perang"],
		["chat", "Chat (%d)" % unread if unread > 0 else "Chat"], ["toko", "Toko"], ["anggota", "Anggota"]],
		_alliance_tab, func(key): _alliance_tab = key, 19)
	_chat_list = null
	match _alliance_tab:
		"chat":
			_build_alliance_chat(box, now)
		"perang":
			_build_alliance_war(box, now)
		"bos":
			_build_alliance_boss(box, now)
		"toko":
			_build_alliance_shop(box, now)
		"anggota":
			_build_alliance_members(box, now)
		_:
			_build_alliance_hq(box, now)


func _build_alliance_header(box: VBoxContainer) -> void:
	var def: Dictionary = model.alliance_def()
	var head := _card(box)
	head.add_child(_tex(Art.icon(def["emblem"]), 110))
	var col := _col(head)
	_label(col, def["name"], "CardTitle")
	var lv: int = model.alliance_level()
	var prog: Array = model.alliance_level_progress()
	if prog[1] > 0:
		_label(col, "Level %d · exp %s / %s" % [lv, _num(prog[0]), _num(prog[1])], "CardLabel")
		_bar(col, prog[0], prog[1], Color("6fa8dc"))
	else:
		_label(col, "Level %d (maksimal)" % lv, "CardLabel")
	var buff := _label(col, "Bonus hasil urusan kota +%d%%" % roundi(model.alliance_bonus() * 100), "CardLabel")
	buff.add_theme_font_override("font", UI.font_bold)
	buff.add_theme_color_override("font_color", Color("b5651d"))
	_icon_row(col, "jasa", "Jasa: %s" % _num(model.alliance["jasa"]))


func _build_alliance_choices(box: VBoxContainer, now: float) -> void:
	_label(box, "Pilih aliansi untuk bergabung. Anggota aliansi saling membantu: menyumbang, "
		+ "melawan bos mingguan, dan berbelanja di toko aliansi.", "SmallLabel")
	var wait: int = model.alliance_join_wait(now)
	for a in Data.ALLIANCES:
		var card := _card(box)
		card.add_child(_tex(Art.icon(a["emblem"]), 110))
		var col := _col(card)
		_label(col, a["name"], "CardTitle")
		var lv := 1
		for i in Data.ALLIANCE_LEVELS.size():
			if int(a["exp"]) >= int(Data.ALLIANCE_LEVELS[i]):
				lv = i + 1
		_label(col, "Level %d · %d anggota" % [lv, a["members"]], "CardLabel")
		var motto := _label(col, "\"%s\"" % a["motto"], "CardLabel")
		motto.add_theme_color_override("font_color", Color("6b4a2a"))
		_label(col, "Bonus hasil urusan kota +%d%%" % roundi(lv * Data.ALLIANCE_YIELD_PER_LEVEL * 100), "CardLabel") \
			.add_theme_color_override("font_color", Color("b5651d"))
		var id: String = a["id"]
		_button(col, "Gabung" if wait == 0 else "Bisa bergabung dalam %s" % _duration(wait),
			func(): return model.join_alliance(id, Game.now()), wait == 0, "", "GreenButton", false, "promote")


func _build_alliance_hq(box: VBoxContainer, now: float) -> void:
	var don := _inner_box(box)
	_label(don, "Sumbangan Harian", "CardTitle")
	_label(don, "Sisa hari ini: %d / %d" % [model.donations_left(now), model.donations_per_day()], "CardLabel")
	for d in Data.ALLIANCE_DONATIONS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		don.add_child(row)
		row.add_child(_tex(Art.icon(d["icon"]), 56))
		var col := _col(row)
		_label(col, d["label"], "CardLabel").add_theme_font_override("font", UI.font_bold)
		var cost_key: String = d["cost"].keys()[0]
		_label(col, "Biaya %s %s · +%d exp, +%d jasa" % [_num(d["cost"][cost_key]), Data.REWARD_NAMES[cost_key],
			d["exp"], d["jasa"]], "SmallLabel").add_theme_color_override("font_color", UI.INK)
		var kind: String = d["id"]
		var ok: bool = model.donations_left(now) > 0 and int(model.get(cost_key)) >= int(d["cost"][cost_key])
		var b := _button(row, "Sumbang", func(): return model.donate(kind, Game.now()), ok, "", "", false, "coin")
		b.custom_minimum_size = Vector2(150, 60)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var log := _inner_box(box)
	_label(log, "Kabar Aliansi", "CardTitle")
	for line in model.alliance["log"].slice(0, 10):
		_label(log, "•  " + line, "SmallLabel").add_theme_color_override("font_color", UI.INK)

	var leave := _button(box, "Keluar dari Aliansi", _confirm_leave)
	leave.custom_minimum_size.y = 60


func _confirm_leave():
	var dlg := ConfirmationDialog.new()
	dlg.add_to_group("modal")
	dlg.dialog_text = "Keluar dari aliansi? Jasa dan progres aliansi akan hilang, dan Anda harus menunggu 24 jam untuk bergabung lagi."
	dlg.ok_button_text = "Keluar"
	dlg.cancel_button_text = "Batal"
	dlg.confirmed.connect(func(): _show(model.leave_alliance(Game.now())))
	dlg.visibility_changed.connect(func():
		if not dlg.visible:
			dlg.queue_free())
	add_child(dlg)
	dlg.popup_centered()
	return null


func _build_alliance_boss(box: VBoxContainer, now: float) -> void:
	var info: Dictionary = model.boss_info(now)
	var card := _inner_box(box)
	_label(card, info["name"], "CardTitle")
	var stage := CenterContainer.new()
	card.add_child(stage)
	var pic := _tex(Art.portrait("boss_buto"), 220)
	if info["defeated"]:
		pic.modulate = Color(0.45, 0.45, 0.45)
	stage.add_child(pic)
	_label(card, "HP %s / %s" % [_num(info["hp"]), _num(info["hp_max"])], "CardLabel") \
		.add_theme_font_override("font", UI.font_bold)
	_bar(card, info["hp"], info["hp_max"], Color("c0392b"))
	var timer := _label(card, "", "SmallLabel")
	timer.add_theme_color_override("font_color", UI.INK)
	_event_timer_labels.append(timer)

	if info["defeated"]:
		_label(card, "%s telah dikalahkan minggu ini! Bos baru muncul hari Senin." % Data.BOSS_NAME, "CardLabel")
		if info["can_claim"]:
			_button(card, "Klaim Hadiah (+%d emas, +%d jasa)" % [Data.BOSS_REWARD["gold"], Data.BOSS_REWARD["jasa"]],
				func(): return model.claim_boss(Game.now()), true, "chest", "GreenButton", false, "reveal_ssr")
		elif info["claimed"]:
			_label(card, "Hadiah sudah diambil.", "CardLabel")
		else:
			_label(card, "Anda tidak ikut menyerang, jadi tidak mendapat hadiah.", "CardLabel")
	else:
		_label(card, "Serangan tersisa hari ini: %d / %d" % [info["attacks_left"], model.boss_attacks_per_day()], "CardLabel")
		var attack := _button(card, "SERANG!", func():
			var r: Dictionary = model.attack_boss(Game.now())
			if r["ok"]:
				_pending_boss_hit = r["damage"]
			return r, info["attacks_left"] > 0, "", "GoldButton", false, "attack")
		attack.custom_minimum_size.y = 90
	_label(card, "Kerusakan Anda: %s · anggota lain: %s" % [_num(info["my_damage"]), _num(info["npc_damage"])],
		"CardLabel")
	_label(card, "Tiap serangan +%d jasa. Bila bos kalah, semua yang ikut menyerang mendapat %d emas dan %d jasa."
		% [Data.BOSS_ATTACK_JASA, Data.BOSS_REWARD["gold"], Data.BOSS_REWARD["jasa"]], "SmallLabel") \
		.add_theme_color_override("font_color", UI.INK)

	if _pending_boss_hit > 0:
		var dmg := _pending_boss_hit
		_pending_boss_hit = 0
		# Tunggu satu frame supaya CenterContainer sudah menempatkan potret.
		await get_tree().process_frame
		if not is_instance_valid(pic):
			return
		var x := pic.position.x
		pic.modulate = Color(3, 2.5, 2.5)
		_float("-%s" % _num(dmg), pic, Color("ff8a70"))
		var tw := create_tween()
		for i in 6:
			tw.tween_property(pic, "position:x", x + (12 if i % 2 == 0 else -12), 0.04)
		tw.tween_property(pic, "position:x", x, 0.04)
		tw.tween_callback(func():
			var dead: bool = model.boss_info(Game.now())["defeated"]
			pic.modulate = Color(0.45, 0.45, 0.45) if dead else Color.WHITE)


## Kartu ikatan penasihat dan ringkasan bonus skill.
func _build_bonds(box: VBoxContainer) -> void:
	var panel := PanelContainer.new()  # kartu perkamen agar teks terbaca di atas latar gelap
	box.add_child(panel)
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 6)
	panel.add_child(card)
	_label(card, "Ikatan Penasihat", "CardTitle").add_theme_font_size_override("font_size", 24)
	for b in Data.BONDS:
		var owned: int = b["members"].filter(func(id): return model.counselors.has(id)).size()
		var active: bool = owned == b["members"].size()
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		card.add_child(row)
		for id in b["members"]:
			var pic := _tex(Art.portrait(id), 40)
			if not model.counselors.has(id):
				pic.modulate = Color(0.25, 0.2, 0.18)
			row.add_child(pic)
		var text := _label(row, "%s (%d/%d): %s" % [b["name"], owned, b["members"].size(),
			Data.SKILL_EFFECT_NAMES[b["effect"]] % roundi(float(b["value"]) * 100)], "SmallLabel")
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_theme_color_override("font_color", UI.GREEN.darkened(0.25) if active else Color("8a7a6a"))
		if active:
			text.add_theme_font_override("font", UI.font_bold)
	var totals := []
	for effect in Data.SKILL_EFFECT_NAMES:
		var v: float = model.skill_bonus(effect)
		if v > 0.0:
			totals.append(Data.SKILL_EFFECT_NAMES[effect] % roundi(v * 100))
	if not totals.is_empty():
		var t := _label(card, "Total bonus: %s" % "; ".join(totals), "SmallLabel")
		t.add_theme_color_override("font_color", Color("6c3483"))


func _build_alliance_war(box: VBoxContainer, now: float) -> void:
	if not model.war_reward.is_empty():
		var wr: Dictionary = model.war_reward
		var rbox := _inner_box(box)
		rbox.get_parent().add_theme_stylebox_override("panel", UI.box(Color("fff3c8"), UI.GOLD, 3, 12))
		var head := _label(rbox, ("MENANG" if wr["win"] else "KALAH") + " melawan %s" % wr["enemy"], "CardTitle")
		head.add_theme_color_override("font_color", UI.GREEN.darkened(0.2) if wr["win"] else UI.RED)
		_label(rbox, "Skor %d - %d · jasa perang Anda %d" % [wr["ours"], wr["theirs"], wr["merit"]], "CardLabel")
		_button(rbox, "Klaim Hadiah (+%d emas, +%d jasa)" % [wr["reward"]["gold"], wr["reward"]["jasa"]],
			func(): return model.claim_war_reward(), true, "chest", "GreenButton", false, "reveal_ssr")
	if model.war.is_empty():
		return
	var enemy: Dictionary = model.war_enemy_def()
	var mine: Dictionary = model.alliance_def()

	# Papan skor: lambang kedua aliansi dan skor.
	var vs := _inner_box(box)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	vs.add_child(row)
	for side in [[mine, model.war_score(true)], [enemy, model.war_score(false)]]:
		var col := VBoxContainer.new()
		col.custom_minimum_size.x = 230
		row.add_child(col)
		var em := _tex(Art.icon(side[0]["emblem"]), 90)
		em.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(em)
		var n := _label(col, side[0]["name"], "CardLabel")
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.add_theme_font_override("font", UI.font_bold)
		var sc := _label(col, str(side[1]), "CardTitle")
		sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sc.add_theme_font_size_override("font_size", 40)
		if side[0] == mine:
			var vs_l := _label(row, "VS", "BigLabel")
			vs_l.add_theme_font_size_override("font_size", 48)
			vs_l.add_theme_color_override("font_color", UI.GOLD_DARK)
	var timer := _label(vs, "", "SmallLabel")
	timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer.add_theme_color_override("font_color", UI.INK)
	_event_timer_labels.append(timer)
	var attacks: int = model.war_attacks_left(now)
	var info := _label(vs, "Serangan tersisa %d / %d · jasa perang Anda %d" % [attacks, model.war_attacks_per_day(),
		model.war["merit"]], "CardLabel")
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_override("font", UI.font_bold)

	# Benteng lawan.
	_label(box, "Benteng %s" % enemy["name"], "TitleLabel").add_theme_font_size_override("font_size", 26)
	for i in Data.WAR_FORTS.size():
		var fdef: Dictionary = Data.WAR_FORTS[i]
		var hp: int = model.war["their"][i]
		var hp_max: int = model.war["their_max"][i]
		var frow := HBoxContainer.new()
		frow.add_theme_constant_override("separation", 10)
		_inner_box(box).add_child(frow)
		var core := i == Data.WAR_FORTS.size() - 1
		var icon := _tex(Art.icon("fort_captured" if hp <= 0 else ("fort_core" if core else "fort")), 70)
		frow.add_child(icon)
		var col := _col(frow)
		_label(col, "%s · %d poin" % [fdef["name"], fdef["points"]], "CardLabel").add_theme_font_override("font", UI.font_bold)
		if hp <= 0:
			_label(col, "Direbut!", "CardLabel").add_theme_color_override("font_color", UI.GREEN.darkened(0.2))
		else:
			_bar(col, hp, hp_max, Color("c0392b"))
			_label(col, "HP %s / %s" % [_num(hp), _num(hp_max)], "SmallLabel").add_theme_color_override("font_color", UI.INK)
		var idx: int = i
		var locked: bool = model.war_fort_locked(i)
		var b := _button(frow, "Terkunci" if locked else ("Direbut" if hp <= 0 else "Serang"), func():
			var r: Dictionary = model.attack_fort(idx, Game.now())
			if r["ok"]:
				_pending_fort_hit = {"index": idx, "damage": r["damage"]}
			return r, hp > 0 and not locked and attacks > 0, "", "GoldButton", false, "attack")
		b.custom_minimum_size = Vector2(130, 60)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if not _pending_fort_hit.is_empty() and _pending_fort_hit["index"] == i:
			var dmg: int = _pending_fort_hit["damage"]
			_pending_fort_hit = {}
			_hit_fx.call_deferred(icon, dmg)

	# Benteng sendiri.
	var ours := _inner_box(box)
	_label(ours, "Benteng %s" % mine["name"], "CardLabel").add_theme_font_override("font", UI.font_bold)
	for i in Data.WAR_FORTS.size():
		var hp: int = model.war["our"][i]
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 8)
		ours.add_child(r)
		var l := _label(r, Data.WAR_FORTS[i]["name"], "SmallLabel")
		l.add_theme_color_override("font_color", UI.INK)
		l.custom_minimum_size.x = 200
		var bar := _bar(r, hp, model.war["our_max"][i], Color("2e86c1"))
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if hp <= 0:
			var lost := _label(r, "Jatuh", "SmallLabel")
			lost.add_theme_color_override("font_color", UI.RED)

	var log := _inner_box(box)
	_label(log, "Kabar Perang", "CardLabel").add_theme_font_override("font", UI.font_bold)
	for line in model.war["log"].slice(0, 8):
		_label(log, "•  " + line, "SmallLabel").add_theme_color_override("font_color", UI.INK)
	_label(box, ("Rebut %d benteng untuk membuka Keraton Inti. Menang: %d emas + %d jasa; kalah: %d emas + %d jasa; "
		+ "ditambah bonus emas dari jasa perang.") % [Data.WAR_CORE_UNLOCK, Data.WAR_REWARD_WIN["gold"],
		Data.WAR_REWARD_WIN["jasa"], Data.WAR_REWARD_LOSE["gold"], Data.WAR_REWARD_LOSE["jasa"]], "SmallLabel")


## Efek kena serang pada ikon: kilat, guncang, dan angka kerusakan.
func _hit_fx(target: Control, dmg: int) -> void:
	await get_tree().process_frame
	if not is_instance_valid(target):
		return
	var x := target.position.x
	target.modulate = Color(3, 2.5, 2.5)
	_float("-%s" % _num(dmg), target, Color("ff8a70"))
	var tw := create_tween()
	for i in 6:
		tw.tween_property(target, "position:x", x + (8 if i % 2 == 0 else -8), 0.04)
	tw.tween_property(target, "position:x", x, 0.04)
	tw.tween_callback(func(): target.modulate = Color.WHITE)


func _build_alliance_chat(box: VBoxContainer, now: float) -> void:
	var panel := _inner_box(box)
	_chat_scroll = ScrollContainer.new()
	# Tinggi disesuaikan agar tombol pesan cepat dan kolom ketik terlihat tanpa menggulir halaman.
	_chat_scroll.custom_minimum_size.y = 400
	_chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(_chat_scroll)
	_chat_list = VBoxContainer.new()
	_chat_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_list.add_theme_constant_override("separation", 10)
	_chat_scroll.add_child(_chat_list)
	_fill_chat_list(now)

	var quick := HFlowContainer.new()
	quick.add_theme_constant_override("h_separation", 6)
	quick.add_theme_constant_override("v_separation", 6)
	box.add_child(quick)
	for text in Data.CHAT_QUICK:
		var q := Button.new()
		q.text = text
		q.theme_type_variation = "GreenButton"
		q.add_theme_font_size_override("font_size", 18)
		q.custom_minimum_size.y = 48
		q.pressed.connect(func(): _send_chat(text))
		quick.add_child(q)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	_chat_input = LineEdit.new()
	_chat_input.placeholder_text = "Tulis pesan..."
	_chat_input.max_length = Data.CHAT_MAX_LENGTH
	_chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_input.custom_minimum_size.y = 64
	_chat_input.text = _chat_draft
	_chat_input.add_theme_stylebox_override("normal", UI.box(Color("fffaf0"), UI.GOLD_DARK, 2, 12))
	_chat_input.add_theme_stylebox_override("focus", UI.box(Color("fffaf0"), UI.GOLD, 3, 12))
	_chat_input.add_theme_color_override("font_color", UI.INK)
	_chat_input.add_theme_color_override("font_placeholder_color", Color("9a8670"))
	_chat_input.text_changed.connect(func(t): _chat_draft = t)
	_chat_input.text_submitted.connect(func(t): _send_chat(t))
	_chat_input.focus_entered.connect(func(): _chat_focus = true)
	_chat_input.focus_exited.connect(func(): _chat_focus = false)
	row.add_child(_chat_input)
	var send := Button.new()
	send.text = "Kirim"
	send.theme_type_variation = "GoldButton"
	send.add_theme_font_size_override("font_size", 24)
	send.custom_minimum_size = Vector2(130, 64)
	send.pressed.connect(func(): _send_chat(_chat_input.text))
	row.add_child(send)
	if _chat_focus:
		_chat_input.grab_focus.call_deferred()
		_chat_input.caret_column = _chat_draft.length()


func _send_chat(text: String) -> void:
	var r: Dictionary = model.chat_send(text, Game.now())
	if not r["ok"]:
		Audio.play("error")
		_show(r)
		return
	Audio.play("click")
	_chat_draft = ""
	if is_instance_valid(_chat_input):
		_chat_input.text = ""
	_fill_chat_list(Game.now())


## Isi ulang daftar pesan saja (kolom ketik tidak disentuh) lalu gulir ke bawah.
func _fill_chat_list(now: float) -> void:
	if not is_instance_valid(_chat_list):
		return
	_clear(_chat_list)
	var msgs: Array = model.chat_messages(now)
	_chat_shown = msgs.size()
	model.chat_mark_read(now)
	for m in msgs:
		_chat_list.add_child(_chat_bubble(m))
	await get_tree().process_frame
	if is_instance_valid(_chat_scroll):
		_chat_scroll.scroll_vertical = int(_chat_scroll.get_v_scroll_bar().max_value)


func _chat_bubble(m: Dictionary) -> Control:
	var d := Time.get_datetime_dict_from_unix_time(int(float(m["t"]) + model.tz_bias))
	var clock := "%02d:%02d" % [d["hour"], d["minute"]]
	if m.get("system", false):
		var l := Label.new()
		l.text = "— %s · %s —" % [m["text"], clock]
		l.theme_type_variation = "SmallLabel"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_color_override("font_color", Color("8a6a4a"))
		return l
	var me: bool = m.get("me", false)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_END if me else BoxContainer.ALIGNMENT_BEGIN
	var avatar := _tex(Art.portrait("lord" if me else m.get("avatar", "arya")), 56)
	avatar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := Label.new()
	head.text = ("Anda" if me else "%s · %s" % [m.get("from", "?"), m.get("role", "Anggota")]) + "  " + clock
	head.theme_type_variation = "SmallLabel"
	head.add_theme_font_size_override("font_size", 16)
	head.add_theme_color_override("font_color", Color("6b4a2a"))
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if me else HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(head)
	var bubble := PanelContainer.new()
	var st := UI.box(Color("f7d98a") if me else Color("fffaf0"), UI.GOLD_DARK, 1, 14)
	st.set_content_margin_all(10)
	bubble.add_theme_stylebox_override("panel", st)
	bubble.size_flags_horizontal = Control.SIZE_SHRINK_END if me else Control.SIZE_SHRINK_BEGIN
	var text := Label.new()
	text.text = m["text"]
	text.theme_type_variation = "CardLabel"
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = mini(460, maxi(60, m["text"].length() * 13))
	bubble.add_child(text)
	col.add_child(bubble)
	if me:
		row.add_child(col)
		row.add_child(avatar)
	else:
		row.add_child(avatar)
		row.add_child(col)
	return row


func _build_alliance_shop(box: VBoxContainer, now: float) -> void:
	var lv: int = model.alliance_level()
	for item in Data.ALLIANCE_SHOP:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_inner_box(box).add_child(row)
		row.add_child(_tex(Art.icon(item["icon"]), 64))
		var col := _col(row)
		_label(col, item["name"], "CardLabel").add_theme_font_override("font", UI.font_bold)
		var id: String = item["id"]
		var left: int = model.shop_left(id, now)
		var info := "%s · sisa %d/%d hari ini" % [_reward_text(item["reward"]), left, item["limit"]]
		if lv < int(item["level"]):
			info = "%s · butuh aliansi level %d" % [_reward_text(item["reward"]), item["level"]]
		_label(col, info, "SmallLabel").add_theme_color_override("font_color", UI.INK)
		var ok: bool = lv >= int(item["level"]) and left > 0 and int(model.alliance["jasa"]) >= int(item["cost"])
		var b := _button(row, "%d" % item["cost"], func(): return model.shop_buy(id, Game.now()), ok, "jasa",
			"GreenButton" if ok else "", false, "coin")
		b.custom_minimum_size = Vector2(130, 60)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _build_alliance_members(box: VBoxContainer, now: float) -> void:
	var members: Array = model.alliance_members(now)
	_label(box, "%d anggota · diurutkan berdasarkan kekuatan" % members.size(), "SmallLabel")
	for i in members.size():
		var m: Dictionary = members[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var inner := _inner_box(box)
		inner.add_child(row)
		if m["me"]:
			inner.get_parent().add_theme_stylebox_override("panel", UI.box(Color("fff3c8"), UI.GOLD, 3, 12))
		var rank := _label(row, "#%d" % (i + 1), "CardTitle")
		rank.custom_minimum_size.x = 64
		var col := _col(row)
		_label(col, "%s  ·  %s" % [m["name"], m["role"]], "CardLabel").add_theme_font_override("font", UI.font_bold)
		_label(col, "Kekuatan %s · Kerusakan bos %s" % [_num(m["power"]), _num(m["damage"])], "SmallLabel") \
			.add_theme_color_override("font_color", UI.INK)


# --- Cerita & misi utama -------------------------------------------------------

func _build_story_tracker(box: VBoxContainer) -> void:
	var card := _card(box)
	card.add_child(_tex(Art.icon("item_scroll"), 72))
	var col := _col(card)
	if model.story_done():
		_label(col, "Kisah Tamat", "CardTitle")
		_label(col, "Anda telah menjadi Mahapatih Nusantara. Terima kasih telah bermain!", "CardLabel")
		return
	var def: Dictionary = model.story_chapter_def()
	_label(col, "Bab %d: %s" % [int(model.story["chapter"]) + 1, def["title"]], "CardTitle") \
		.add_theme_font_size_override("font_size", 24)
	var next := {}
	for q in model.story_quests():
		if not q["claimed"]:
			next = q
			break
	if next.is_empty():
		_label(col, "Semua misi selesai! Ambil hadiah bab.", "CardLabel")
	else:
		_label(col, "%s (%s/%s)" % [next["text"], _num(mini(next["current"], next["target"])), _num(next["target"])],
			"CardLabel")
		_bar(col, mini(next["current"], next["target"]), next["target"], Color("8e44ad"))
	var ready: int = model.story_claimable()
	var b := _button(card, "Klaim (%d)" % ready if ready > 0 else "Lihat", func():
		_show_story()
		return null, true, "", "GreenButton" if ready > 0 else "GoldButton")
	b.custom_minimum_size = Vector2(140, 64)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 22)


func _show_story() -> void:
	if is_instance_valid(_story_overlay):
		return
	var holder := {}
	var close := func():
		Audio.play("click")
		if is_instance_valid(holder.get("overlay")):
			holder["overlay"].queue_free()
		_story_overlay = null
	var p := _open_panel("Misi Utama", "item_scroll", close)
	holder["overlay"] = p["overlay"]
	_story_overlay = p["overlay"]
	_story_box = p["content"]
	p["subtitle"].text = "Kisah dari Kepala Desa menuju Perdana Menteri"
	_fill_story()


func _fill_story() -> void:
	_clear(_story_box)
	if model.story_done():
		_label(_story_box, "Semua bab telah tamat. Anda adalah Mahapatih Nusantara!", "CardTitle")
		return
	var chapter: int = model.story["chapter"]
	var def: Dictionary = model.story_chapter_def()
	var head := HBoxContainer.new()
	_story_box.add_child(head)
	var t := _label(head, "Bab %d dari %d: %s" % [chapter + 1, Data.STORY_CHAPTERS.size(), def["title"]], "CardTitle")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var replay := _button(head, "Cerita", func():
		_show_story_dialog(chapter)
		return null)
	replay.custom_minimum_size = Vector2(130, 56)
	var quests: Array = model.story_quests()
	for i in quests.size():
		var q: Dictionary = quests[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_inner_box(_story_box).add_child(row)
		var col := _col(row)
		_label(col, q["text"], "CardLabel").add_theme_font_override("font", UI.font_bold)
		_bar(col, mini(q["current"], q["target"]), q["target"], Color("8bc34a") if q["done"] else Color("8e44ad"))
		_label(col, "%s/%s · %s" % [_num(mini(q["current"], q["target"])), _num(q["target"]), _reward_text(q["reward"])],
			"SmallLabel").add_theme_color_override("font_color", UI.INK)
		var idx: int = i
		var b: Button
		if q["claimed"]:
			b = _button(row, "Diambil", func(): return null, false)
		else:
			b = _button(row, "Klaim", func(): return model.claim_quest(idx), q["done"], "", "GreenButton", false, "coin")
		b.custom_minimum_size = Vector2(130, 60)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var all_claimed: bool = model.story["claimed"].size() == quests.size()
	var reward := _inner_box(_story_box)
	reward.get_parent().add_theme_stylebox_override("panel", UI.box(Color("fff3c8"), UI.GOLD, 3, 12))
	_label(reward, "Hadiah tamat bab: " + _reward_text(def["reward"]), "CardLabel").add_theme_font_override("font", UI.font_bold)
	_button(reward, "Tamatkan Bab", func(): return model.claim_chapter(), all_claimed, "chest", "GoldButton", false,
		"promote").add_theme_font_size_override("font_size", 24)


## Dialog cerita bab: potret pembicara dan teks, maju dengan tombol Lanjut.
func _show_story_dialog(chapter: int) -> void:
	model.mark_story_seen(chapter)
	var lines: Array = Data.STORY_CHAPTERS[chapter]["story"]
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_to_group("modal")
	add_child(overlay)
	move_child(overlay, _toast.get_index())
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.01, 0.02, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var title := Label.new()
	title.text = "Bab %d\n%s" % [chapter + 1, Data.STORY_CHAPTERS[chapter]["title"]]
	title.theme_type_variation = "TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 220
	overlay.add_child(title)
	var pic := _tex(null, 300)
	pic.size = Vector2(300, 300)
	pic.position = Vector2(size.x / 2 - 150, 380)
	overlay.add_child(pic)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.04
	panel.anchor_right = 0.96
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -470
	panel.offset_bottom = -150
	overlay.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var name := _label(v, "", "CardTitle")
	var text := _label(v, "", "CardLabel")
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("font_size", 26)
	var next := Button.new()
	next.theme_type_variation = "GoldButton"
	next.custom_minimum_size = Vector2(0, 72)
	next.add_theme_font_size_override("font_size", 26)
	v.add_child(next)
	var state := {"i": 0}
	var show_line := func():
		var line: Dictionary = lines[state["i"]]
		var sp: String = line["speaker"]
		pic.texture = Art.portrait(sp)
		var who: String = Data.STORY_SPEAKER_NAMES.get(sp, "")
		if who == "":
			who = Data.counselor_def(sp).get("name", Data.beauty_def(sp).get("name", sp))
		name.text = who
		text.text = line["text"]
		next.text = "Mulai Bab" if state["i"] == lines.size() - 1 else "Lanjut"
		pic.modulate.a = 0.0
		create_tween().tween_property(pic, "modulate:a", 1.0, 0.25)
	next.pressed.connect(func():
		Audio.play("click")
		state["i"] += 1
		if state["i"] >= lines.size():
			overlay.queue_free()
		else:
			show_line.call())
	show_line.call()


# --- Tombol cepat Kota & tas ---------------------------------------------------

## Baris tombol cepat di menu Kota (Tas, dll.).
func _build_quick_row(box: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var count := 0
	for id in model.inventory:
		count += int(model.inventory[id])
	var bag := _button(row, "Tas (%d)" % count, func():
		_show_bag()
		return null, true, "bag", "GoldButton")
	bag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag.add_theme_font_size_override("font_size", 22)
	var eq := _button(row, "Pusaka (%d)" % model.equipment.size(), func():
		_show_equipment()
		return null, true, "eq_weapon", "GoldButton")
	eq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eq.add_theme_font_size_override("font_size", 22)
	if Ads.mode != Ads.Mode.UNAVAILABLE:
		var need_refill := false
		for key in model.CHARGE_KEYS:
			need_refill = need_refill or model.charge_value(key, Game.now()) < model.max_charges()
		if need_refill:
			_ad_button(box, "refill")
	if model.do_all_unlocked():
		var all := _button(row, "Kerjakan Semua", func(): return model.do_all(Game.now()), true, "",
			"GreenButton", false, "coin")
		all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		all.add_theme_font_size_override("font_size", 22)


func _show_bag() -> void:
	if is_instance_valid(_bag_overlay):
		return
	_bag_pick = ""
	var p := _open_panel("Tas", "bag", _close_bag)
	_bag_overlay = p["overlay"]
	_bag_box = p["content"]
	p["subtitle"].text = "Item dari misi, event, toko, dan kampanye"
	_fill_bag()


func _close_bag() -> void:
	if is_instance_valid(_bag_overlay):
		Audio.play("click")
		_bag_overlay.queue_free()
	_bag_overlay = null


func _fill_bag() -> void:
	_clear(_bag_box)
	if _bag_pick != "":
		_fill_bag_targets()
		return
	var any := false
	for id in Data.ITEM_ORDER:
		var n: int = model.item_count(id)
		if n <= 0:
			continue
		any = true
		var def: Dictionary = Data.ITEMS[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_inner_box(_bag_box).add_child(row)
		row.add_child(_tex(Art.icon(def["icon"]), 64))
		var col := _col(row)
		_label(col, "%s  x%d" % [def["name"], n], "CardLabel").add_theme_font_override("font", UI.font_bold)
		_label(col, def["desc"], "SmallLabel").add_theme_color_override("font_color", UI.INK)
		var item_id: String = id
		var b: Button
		if id == "recruit_ticket":
			b = _button(row, "Rekrut", func():
				_close_bag()
				_switch_page("gacha")
				return null, true, "", "")
		elif def["target"] != "":
			b = _button(row, "Pakai", func():
				_bag_pick = item_id
				_queue_rebuild()
				return null, true, "", "GreenButton")
		else:
			b = _button(row, "Pakai", func(): return model.use_item(item_id, "", Game.now()), true, "",
				"GreenButton", false, "upgrade")
		b.custom_minimum_size = Vector2(120, 60)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not any:
		_label(_bag_box, "Tas kosong. Item didapat dari misi harian, login, event, toko, dan tahap besar kampanye.",
			"CardLabel")


## Daftar penasihat/selir untuk item bertarget.
func _fill_bag_targets() -> void:
	var def: Dictionary = Data.ITEMS[_bag_pick]
	var head := HBoxContainer.new()
	_bag_box.add_child(head)
	var back := _button(head, "Kembali", func():
		_bag_pick = ""
		_queue_rebuild()
		return null)
	back.custom_minimum_size = Vector2(150, 56)
	var title := _label(head, "%s: pilih %s" % [def["name"], "penasihat" if def["target"] == "counselor" else "selir"],
		"CardLabel")
	title.add_theme_font_override("font", UI.font_bold)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ids: Array = model.counselors.keys() if def["target"] == "counselor" else model.beauties.keys()
	for id in ids:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_inner_box(_bag_box).add_child(row)
		row.add_child(_tex(Art.portrait(id), 64))
		var col := _col(row)
		if def["target"] == "counselor":
			var st: Dictionary = model.counselors[id]
			_label(col, Data.counselor_def(id)["name"], "CardLabel").add_theme_font_override("font", UI.font_bold)
			_label(col, "Level %d · bintang %d" % [st["level"], st.get("stars", 0)], "SmallLabel") \
				.add_theme_color_override("font_color", UI.INK)
		else:
			_label(col, Data.beauty_def(id)["name"], "CardLabel").add_theme_font_override("font", UI.font_bold)
			_label(col, "Keakraban %d" % model.beauties[id]["intimacy"], "SmallLabel") \
				.add_theme_color_override("font_color", UI.INK)
		var target: String = id
		var item_id: String = _bag_pick
		var b := _button(row, "Pilih", func():
			var r: Dictionary = model.use_item(item_id, target, Game.now())
			if r["ok"] and model.item_count(item_id) <= 0:
				_bag_pick = ""
			return r, true, "", "GreenButton", false, "upgrade")
		b.custom_minimum_size = Vector2(120, 56)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER


# --- Iklan berhadiah -----------------------------------------------------------

func _ad_button(parent: Node, kind: String) -> Button:
	var def: Dictionary = Data.AD_REWARDS[kind]
	var left: int = model.ad_left(kind, Game.now())
	var b := _button(parent, "Iklan: %s (sisa %d)" % [def["name"], left], func():
		Ads.show_rewarded(kind)
		return null, left > 0 and not Ads.busy(), def["icon"], "GreenButton")
	b.add_theme_font_size_override("font_size", 20)
	return b


func _on_ad_started(_kind: String) -> void:
	if Ads.mode != Ads.Mode.TEST:
		return  # iklan sungguhan tampil layar penuh dari plugin
	_ad_overlay = Control.new()
	_ad_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ad_overlay.add_to_group("modal")
	add_child(_ad_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ad_overlay.add_child(dim)
	var l := Label.new()
	l.text = "Memutar iklan (mode uji)..."
	l.theme_type_variation = "TitleLabel"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ad_overlay.add_child(l)


# --- Menara Ujian ------------------------------------------------------------

func _show_tower() -> void:
	if is_instance_valid(_tower_overlay):
		return
	var p := _open_panel("Menara Ujian", "tower", _close_tower)
	_tower_overlay = p["overlay"]
	_tower_box = p["content"]
	p["subtitle"].text = "Reset tiap Senin · rekor terbaik masuk peringkat"
	_fill_tower()


func _close_tower() -> void:
	if is_instance_valid(_tower_overlay):
		Audio.play("click")
		_tower_overlay.queue_free()
	_tower_overlay = null


func _tower_reward_text(info: Dictionary) -> String:
	var parts := ["+%s perak" % _num(info["silver"]), "+%d emas" % info["gold"]]
	if info["rare"]:
		parts.append("pusaka langka")
	elif info["equip"]:
		parts.append("pusaka")
	return ", ".join(parts)


func _fill_tower() -> void:
	_clear(_tower_box)
	var now: float = Game.now()
	model.ensure_tower(now)
	var next: int = int(model.tower["floor"]) + 1
	var info: Dictionary = Data.tower_floor(next)
	var head := _inner_box(_tower_box)
	_label(head, "Lantai %d" % next, "CardTitle").add_theme_font_size_override("font_size", 30)
	_label(head, "Kekuatan penjaga %s · kekuatan tempur Anda %s" % [_num(info["power"]), _num(model.combat_power())],
		"CardLabel")
	var chance: float = model.tower_win_chance(next)
	var chance_l := _label(head, "Peluang menang %d%%" % roundi(chance * 100), "CardLabel")
	chance_l.add_theme_color_override("font_color", UI.GREEN if chance >= 0.5 else UI.RED)
	chance_l.add_theme_font_override("font", UI.font_bold)
	_label(head, "Hadiah: %s" % _tower_reward_text(info), "SmallLabel").add_theme_color_override("font_color", UI.INK)
	var left: int = model.tower_attempts_left(now)
	var fight := _button(head, "Serang Lantai %d  (%d percobaan)" % [next, left], func():
		var r: Dictionary = model.tower_fight(Game.now())
		return r, left > 0, "", "GoldButton", false, "win")
	fight.custom_minimum_size.y = 84
	_label(_tower_box, "Lantai minggu ini %d · rekor %d · percobaan hari ini %d / %d" % [
		model.tower["floor"], model.tower["best"], left, Data.TOWER_ATTEMPTS + int(model.vip_perk("arena_tickets"))],
		"SmallLabel").add_theme_color_override("font_color", UI.INK)
	_label(_tower_box, "Lantai berikutnya", "CardLabel").add_theme_font_override("font", UI.font_bold)
	for f in range(next + 1, next + 6):
		var fi: Dictionary = Data.tower_floor(f)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_inner_box(_tower_box).add_child(row)
		row.add_child(_tex(Art.icon("eq_weapon" if fi["equip"] else "tower"), 48))
		var col := _col(row)
		_label(col, "Lantai %d · kekuatan %s" % [f, _num(fi["power"])], "CardLabel")
		_label(col, _tower_reward_text(fi), "SmallLabel").add_theme_color_override("font_color", UI.INK)


# --- Pusaka -----------------------------------------------------------------

func _show_equipment() -> void:
	if is_instance_valid(_equip_overlay):
		return
	_equip_pick = -1
	var p := _open_panel("Pusaka", "eq_weapon", _close_equipment)
	_equip_overlay = p["overlay"]
	_equip_box = p["content"]
	p["subtitle"].text = "Pasang di penasihat untuk menambah atribut"
	_fill_equipment()


func _close_equipment() -> void:
	if is_instance_valid(_equip_overlay):
		Audio.play("click")
		_equip_overlay.queue_free()
	_equip_overlay = null


func _equip_stats_text(e: Dictionary) -> String:
	var parts := []
	var st: Dictionary = model.equip_stats(e)
	for k in st:
		parts.append("%s +%d" % [Data.ATTR_NAMES[k], st[k]])
	return ", ".join(parts)


func _fill_equipment() -> void:
	_clear(_equip_box)
	if _equip_pick >= 0:
		_fill_equipment_targets()
		return
	_label(_equip_box, "Gudang %d / %d · didapat dari tahap besar kampanye, perang guild, dan Menara Ujian." % [
		model.equipment.size(), Data.EQUIP_CAPACITY], "SmallLabel").add_theme_color_override("font_color", UI.INK)
	if model.equipment.is_empty():
		_label(_equip_box, "Belum ada pusaka. Menangkan tahap besar (tiap tahap ke-5) untuk peluang mendapatkannya.",
			"CardLabel")
		return
	var order := {"ssr": 0, "sr": 1, "r": 2}
	var list: Array = model.equipment.duplicate()
	list.sort_custom(func(a, b):
		var da: Dictionary = Data.equip_def(a["id"])
		var db: Dictionary = Data.equip_def(b["id"])
		if order[da["rarity"]] != order[db["rarity"]]:
			return order[da["rarity"]] < order[db["rarity"]]
		return int(a["level"]) > int(b["level"]))
	for e in list:
		var def: Dictionary = Data.equip_def(e["id"])
		var box := _inner_box(_equip_box)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		box.add_child(row)
		row.add_child(_tex(Art.icon(Data.EQUIP_SLOTS[def["slot"]]["icon"]), 64))
		var col := _col(row)
		var name := _label(col, "%s +%d" % [def["name"], int(e["level"]) - 1], "CardLabel")
		name.add_theme_font_override("font", UI.font_bold)
		name.add_theme_color_override("font_color", _rarity_color(def["rarity"]).darkened(0.25))
		_label(col, "%s · %s" % [Data.EQUIP_SLOTS[def["slot"]]["name"], _equip_stats_text(e)], "SmallLabel") \
			.add_theme_color_override("font_color", UI.INK)
		var owner: String = e["owner"]
		_label(col, "Dipakai: %s" % Data.counselor_def(owner)["name"] if owner != "" else "Belum dipakai", "SmallLabel") \
			.add_theme_color_override("font_color", UI.GREEN if owner != "" else UI.INK)
		var uid: int = e["uid"]
		var actions := HBoxContainer.new()
		actions.add_theme_constant_override("separation", 6)
		box.add_child(actions)
		var put := _button(actions, "Pasang" if owner == "" else "Pindah", func():
			_equip_pick = uid
			_queue_rebuild()
			return null, true, "", "GreenButton")
		put.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if owner != "":
			_button(actions, "Lepas", func(): return model.unequip(uid)).size_flags_horizontal = \
				Control.SIZE_EXPAND_FILL
		var maxed: bool = int(e["level"]) >= Data.EQUIP_MAX_LEVEL
		var cost: int = model.equip_upgrade_cost(e)
		var up := _button(actions, "Maks" if maxed else "+1 · %s" % _num(cost), func(): return model.upgrade_equipment(uid),
			not maxed and model.silver >= cost, "silver", "GoldButton", true, "upgrade")
		up.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_button(actions, "Lebur", func(): return model.salvage_equipment(uid), owner == "").size_flags_horizontal = \
			Control.SIZE_EXPAND_FILL


func _fill_equipment_targets() -> void:
	var e: Dictionary = model.equip_find(_equip_pick)
	if e.is_empty():
		_equip_pick = -1
		_fill_equipment()
		return
	var def: Dictionary = Data.equip_def(e["id"])
	var head := HBoxContainer.new()
	_equip_box.add_child(head)
	_button(head, "Kembali", func():
		_equip_pick = -1
		_queue_rebuild()
		return null).custom_minimum_size = Vector2(150, 56)
	var title := _label(head, "%s: pilih %s" % [def["name"], "penasihat"], "CardLabel")
	title.add_theme_font_override("font", UI.font_bold)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ids: Array = model.counselors.keys()
	var key: String = def["attrs"].keys()[0]
	ids.sort_custom(func(a, b): return model.attr(a, key) > model.attr(b, key))
	for id in ids:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_inner_box(_equip_box).add_child(row)
		row.add_child(_tex(Art.portrait(id), 64))
		var col := _col(row)
		_label(col, Data.counselor_def(id)["name"], "CardLabel").add_theme_font_override("font", UI.font_bold)
		var cur: Dictionary = model.equipped(id, def["slot"])
		_label(col, "%s %d · %s" % [Data.ATTR_NAMES[key], model.attr(id, key),
			"%s: %s" % [Data.EQUIP_SLOTS[def["slot"]]["name"], Data.equip_def(cur["id"])["name"]] if not cur.is_empty()
			else "slot kosong"], "SmallLabel").add_theme_color_override("font_color", UI.INK)
		var target: String = id
		var uid: int = _equip_pick
		var b := _button(row, "Pilih", func():
			var r: Dictionary = model.equip(uid, target)
			_equip_pick = -1
			return r, true, "", "GreenButton", false, "upgrade")
		b.custom_minimum_size = Vector2(120, 56)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER


# --- Leaderboard global -----------------------------------------------------

func _show_leaderboard() -> void:
	if is_instance_valid(_lb_overlay):
		return
	var p := _open_panel("Peringkat Global", "trophy", _close_leaderboard)
	_lb_overlay = p["overlay"]
	_lb_box = p["content"]
	p["subtitle"].text = "%s pemain · diperbarui tiap hari" % _num_dots(Data.LB_PLAYERS + 1)
	_fill_leaderboard()


func _close_leaderboard() -> void:
	if is_instance_valid(_lb_overlay):
		Audio.play("click")
		_lb_overlay.queue_free()
	_lb_overlay = null


## 100001 -> "100.001" (pemisah ribuan gaya Indonesia).
static func _num_dots(n: int) -> String:
	return Data.format_idr(n).substr(2)


func _fill_leaderboard() -> void:
	_clear(_lb_box)
	var now: float = Game.now()
	var items := []
	for lb in Data.LEADERBOARDS:
		items.append([lb["id"], lb["name"]])
	_segment_tabs(_lb_box, items, _lb_cat, func(key): _lb_cat = key, 18)

	var reward: Dictionary = model.leaderboard.get("reward", {})
	if not reward.is_empty():
		var rb := _inner_box(_lb_box)
		rb.get_parent().add_theme_stylebox_override("panel", UI.box(Color("fff3c8"), UI.GOLD, 3, 12))
		_label(rb, "Hadiah peringkat minggu lalu: %s (#%s)" % [reward["tier"], _num_dots(reward["rank"])], "CardLabel") \
			.add_theme_font_override("font", UI.font_bold)
		_button(rb, "Klaim +%d Emas" % reward["gold"], func(): return model.claim_lb_reward(), true, "gold",
			"GreenButton", false, "reveal_sr")

	if _lb_cat == "alliance":
		_fill_lb_alliances(now)
		return
	var def: Dictionary = Data.leaderboard_def(_lb_cat)
	var mine: Dictionary = model.lb_rank(_lb_cat, now)
	var me := _inner_box(_lb_box)
	me.get_parent().add_theme_stylebox_override("panel", UI.box(Color("fff3c8"), UI.GOLD, 3, 12))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	me.add_child(row)
	row.add_child(_tex(Art.icon(def["icon"]), 72))
	var col := _col(row)
	if mine["value"] <= 0:
		_label(col, "Belum berperingkat", "CardTitle").add_theme_font_size_override("font_size", 26)
		_label(col, "Mainkan fitur ini untuk masuk peringkat %s." % def["name"], "CardLabel")
	else:
		_label(col, "Peringkat Anda: #%s" % _num_dots(mine["rank"]), "CardTitle").add_theme_font_size_override("font_size", 28)
		_label(col, "%s %s · Top %s%%" % [def["name"], _num(mine["value"]), _percent(mine["top_percent"])], "CardLabel")
	if _lb_cat == "power":
		var tier: Dictionary = model.lb_reward_tier(mine["top_percent"])
		_label(me, "Hadiah akhir minggu bila bertahan: %s, +%d emas (dihitung dari Kekuatan)." % [tier["name"], tier["gold"]],
			"SmallLabel").add_theme_color_override("font_color", UI.INK)
		var timer := _label(me, "", "SmallLabel")
		timer.add_theme_color_override("font_color", UI.INK)
		_event_timer_labels.append(timer)

	var rows: Array = model.lb_top(_lb_cat, now)
	for i in rows.size():
		_lb_row(i + 1, rows[i]["avatar"], "%s %s" % [rows[i]["tag"], rows[i]["name"]], _num(rows[i]["value"]), rows[i]["me"])


static func _percent(p: float) -> String:
	return ("%.2f" % p if p < 1.0 else "%.1f" % p).replace(".", ",")


func _lb_row(rank: int, avatar: String, name: String, value: String, me: bool, is_icon := false) -> void:
	var inner := _inner_box(_lb_box)
	if me:
		inner.get_parent().add_theme_stylebox_override("panel", UI.box(Color("fff3c8"), UI.GOLD, 3, 12))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	inner.add_child(row)
	var r := _label(row, "#%d" % rank, "CardTitle")
	r.custom_minimum_size.x = 64
	if rank <= 3:
		r.add_theme_color_override("font_color", [Color("d4a017"), Color("8a9aa8"), Color("b07a45")][rank - 1])
		r.add_theme_font_size_override("font_size", 30)
	row.add_child(_tex(Art.icon(avatar) if is_icon else Art.portrait(avatar), 52))
	var n := _label(row, name, "CardLabel")
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.add_theme_font_override("font", UI.font_bold)
	n.clip_text = true
	var v := _label(row, value, "CardLabel")
	v.add_theme_font_override("font", UI.font_bold)
	v.add_theme_color_override("font_color", Color("5e2a12"))


func _fill_lb_alliances(now: float) -> void:
	var rows: Array = model.lb_alliances(now)
	var my_rank := -1
	for i in rows.size():
		if rows[i]["me"]:
			my_rank = i + 1
	_label(_lb_box, ("Aliansi Anda di peringkat #%d dari %d" % [my_rank, rows.size()]) if my_rank > 0
		else "Bergabunglah dengan aliansi untuk ikut peringkat aliansi.", "TitleLabel").add_theme_font_size_override("font_size", 24)
	for i in rows.size():
		var a: Dictionary = rows[i]
		_lb_row(i + 1, a["emblem"], "%s (%d anggota)" % [a["name"], a["members"]], _num(a["power"]), a["me"], true)


# --- VIP --------------------------------------------------------------------

## Avatar di header dengan label VIP; diketuk untuk membuka panel VIP.
func _build_avatar() -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(104, 104)
	var b := Button.new()
	b.theme_type_variation = "NavButton"
	b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.pressed.connect(func():
		Audio.play("click")
		_show_vip())
	holder.add_child(b)
	var pic := _tex(Art.portrait("lord"), 104)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(pic)
	var tag := PanelContainer.new()
	var st := UI.box(Color("c0392b"), UI.GOLD, 2, 10)
	st.content_margin_left = 8
	st.content_margin_right = 8
	st.content_margin_top = 0
	st.content_margin_bottom = 0
	tag.add_theme_stylebox_override("panel", st)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.position = Vector2(18, 82)
	_vip_tag = Label.new()
	_vip_tag.add_theme_font_override("font", UI.font_bold)
	_vip_tag.add_theme_font_size_override("font_size", 17)
	_vip_tag.add_theme_color_override("font_color", Color("fff3d6"))
	tag.add_child(_vip_tag)
	holder.add_child(tag)
	_vip_badge = _badge(holder, Vector2(82, -4))
	return holder


func _show_vip() -> void:
	if is_instance_valid(_vip_overlay):
		return
	_vip_view = -1
	var p := _open_panel("VIP", "vip", _close_vip)
	_vip_overlay = p["overlay"]
	_vip_box = p["content"]
	p["subtitle"].text = "Keuntungan khusus para Tuan"
	_fill_vip()


func _close_vip() -> void:
	if is_instance_valid(_vip_overlay):
		Audio.play("click")
		_vip_overlay.queue_free()
	_vip_overlay = null


func _fill_vip() -> void:
	_clear(_vip_box)
	var now: float = Game.now()
	var lv: int = model.vip_level()
	var top := _inner_box(_vip_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	top.add_child(row)
	row.add_child(_tex(Art.icon("vip"), 90))
	var col := _col(row)
	_label(col, "VIP %d" % lv, "CardTitle").add_theme_font_size_override("font_size", 36)
	var prog: Array = model.vip_progress()
	if prog[1] > 0:
		_label(col, "%d / %d poin ke VIP %d" % [prog[0], prog[1], lv + 1], "CardLabel")
		_bar(col, prog[0], prog[1], Color("c0392b"))
	else:
		_label(col, "Level VIP tertinggi!", "CardLabel")
	_label(top, "1 poin VIP untuk setiap %s pembelian · +%d poin tiap klaim login harian" % [
		Data.format_idr(Data.VIP_IDR_PER_POINT), Data.VIP_LOGIN_POINTS], "SmallLabel") \
		.add_theme_color_override("font_color", UI.INK)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	top.add_child(actions)
	var daily_text := "Hadiah harian mulai VIP 1"
	if lv > 0:
		daily_text = "Hadiah Harian" if model.vip_daily_can_claim(now) else "Sudah diambil hari ini"
	var daily := _button(actions, daily_text,
		func(): return model.claim_vip_daily(Game.now()), model.vip_daily_can_claim(now), "chest", "GreenButton",
		false, "reveal_sr")
	daily.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var store := _button(actions, "Toko", func():
		_close_vip()
		_show_store()
		return null, true, "store", "GoldButton")
	store.add_theme_font_size_override("font_size", 24)

	# Penjelajah level: lihat keuntungan dan paket tiap level VIP.
	var view: int = clampi(lv if _vip_view < 0 else _vip_view, 1, Data.VIP_LEVELS.size() - 1)
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 8)
	_vip_box.add_child(nav)
	var prev := _button(nav, "<", func():
		_vip_view = view - 1
		_queue_rebuild()
		return null, view > 1)
	prev.custom_minimum_size = Vector2(80, 60)
	var title := _label(nav, "Keuntungan VIP %d" % view, "TitleLabel")
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var nxt := _button(nav, ">", func():
		_vip_view = view + 1
		_queue_rebuild()
		return null, view < Data.VIP_LEVELS.size() - 1)
	nxt.custom_minimum_size = Vector2(80, 60)

	var def: Dictionary = Data.VIP_LEVELS[view]
	var perks := _inner_box(_vip_box)
	var reached: bool = lv >= view
	var status := _label(perks, "Aktif" if reached else "Butuh %d poin VIP" % def["points"], "CardLabel")
	status.add_theme_font_override("font", UI.font_bold)
	status.add_theme_color_override("font_color", UI.GREEN.darkened(0.25) if reached else UI.RED)
	for key in Data.VIP_PERK_NAMES:
		if not def["perks"].has(key):
			continue
		var value: float = def["perks"][key]
		var shown := roundi(value * 100) if key == "yield" else int(value)
		_label(perks, "•  " + Data.VIP_PERK_NAMES[key] % shown, "CardLabel")
	_label(perks, "•  Hadiah harian: " + _reward_text(def["daily"]), "CardLabel")
	_label(perks, "•  Hadiah naik level: " + _reward_text(def["gift"]), "CardLabel")

	var pack: Dictionary = def["pack"]
	var pbox := _inner_box(_vip_box)
	pbox.get_parent().add_theme_stylebox_override("panel", UI.box(Color("fff3c8"), UI.GOLD, 3, 12))
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 12)
	pbox.add_child(prow)
	prow.add_child(_tex(Art.portrait(pack["counselor"]) if pack.has("counselor") else Art.icon("starter"), 84))
	var pcol := _col(prow)
	_label(pcol, "Paket Hadiah VIP %d" % view, "CardTitle").add_theme_font_size_override("font_size", 24)
	var contents := _reward_text(pack)
	if pack.has("counselor"):
		var c: Dictionary = Data.counselor_def(pack["counselor"])
		contents = ("%s, " % contents if contents != "" else "") + "penasihat %s %s" % [
			Data.RARITIES[c["rarity"]]["name"], c["name"]]
	_label(pcol, contents + " · sekali beli", "SmallLabel").add_theme_color_override("font_color", UI.INK)
	var bought: bool = view in model.vip["packs"]
	var level := view
	var buy := _button(prow, "Dibeli" if bought else "%d" % pack["cost"], func(): return model.buy_vip_pack(level),
		reached and not bought and model.gold >= int(pack["cost"]), "" if bought else "gold", "GoldButton",
		false, "reveal_ssr")
	buy.add_theme_font_size_override("font_size", 24)
	buy.custom_minimum_size = Vector2(140, 64)
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER


# --- Toko (pembelian dalam aplikasi) ----------------------------------------

func _show_store() -> void:
	if is_instance_valid(_store_overlay):
		return
	var p := _open_panel("Toko Emas", "store", _close_store)
	_store_overlay = p["overlay"]
	_store_box = p["content"]
	p["subtitle"].text = {Store.Mode.PLAY_BILLING: "Pembayaran lewat Google Play",
		Store.Mode.TEST: "MODE UJI · pembayaran disimulasikan"}.get(Store.mode, "Toko belum tersedia")
	_fill_store()


func _close_store() -> void:
	if is_instance_valid(_store_overlay):
		Audio.play("click")
		_store_overlay.queue_free()
	_store_overlay = null


func _fill_store() -> void:
	_clear(_store_box)
	var now: float = Game.now()
	var can_buy: bool = Store.available()
	if Store.mode == Store.Mode.TEST:
		var warn := _label(_store_box, "Mode Uji: tidak ada uang sungguhan yang ditagih. Di versi rilis, "
			+ "pembayaran diproses oleh Google Play.", "CardLabel")
		warn.add_theme_color_override("font_color", Color("b5651d"))
		warn.add_theme_font_override("font", UI.font_bold)
	elif not can_buy:
		_label(_store_box, "Toko belum tersedia. Pastikan terhubung ke internet dan Google Play.", "CardLabel") \
			.add_theme_color_override("font_color", UI.RED)

	for def in Data.IAP_PRODUCTS:
		var id: String = def["id"]
		if def["type"] == "once" and model.iap_owned(id):
			continue
		var box := _inner_box(_store_box)
		if def["type"] != "gold":
			box.get_parent().add_theme_stylebox_override("panel", UI.box(Color("fff3c8"), UI.GOLD, 3, 12))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		box.add_child(row)
		row.add_child(_tex(Art.icon(def["icon"]), 84))
		var col := _col(row)
		_label(col, def["name"], "CardTitle").add_theme_font_size_override("font_size", 24)
		if def.has("desc"):
			_label(col, def["desc"], "SmallLabel").add_theme_color_override("font_color", UI.INK)
		elif int(def.get("bonus", 0)) > 0:
			_label(col, "%d + bonus %d emas" % [def["gold"], def["bonus"]], "SmallLabel") \
				.add_theme_color_override("font_color", UI.INK)
		if model.iap_first_bonus(id):
			var first := _label(col, "x2 untuk pembelian pertama! (+%d emas)" % def["gold"], "SmallLabel")
			first.add_theme_color_override("font_color", Color("c0392b"))
			first.add_theme_font_override("font", UI.font_bold)
		if def["type"] == "card" and model.card_days_left(now) > 0:
			_label(col, "Aktif · sisa %d hari" % model.card_days_left(now), "CardLabel") \
				.add_theme_font_override("font", UI.font_bold)
			if model.card_can_claim(now):
				_button(col, "Ambil %d Emas Hari Ini" % def["daily_gold"], func(): return model.claim_card(Game.now()),
					true, "gold", "GreenButton", false, "coin")
		var buy := _button(row, Store.price_text(id), func():
			_buy(id)
			return null, can_buy, "", "GoldButton")
		buy.add_theme_font_size_override("font_size", 22)
		buy.custom_minimum_size = Vector2(160, 64)
		buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var foot := HBoxContainer.new()
	_store_box.add_child(foot)
	var restore := _button(foot, "Pulihkan Pembelian", func():
		Store.restore()
		return null, Store.mode == Store.Mode.PLAY_BILLING)
	restore.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(_store_box, "Total pembelian: %s" % Data.format_idr(model.iap["spent_idr"]), "SmallLabel") \
		.add_theme_color_override("font_color", UI.INK)


func _buy(id: String) -> void:
	if Store.mode != Store.Mode.TEST:
		Store.purchase(id)
		return
	var def: Dictionary = Data.iap_def(id)
	var dlg := ConfirmationDialog.new()
	dlg.add_to_group("modal")
	dlg.title = "Mode Uji"
	dlg.dialog_text = "Beli %s seharga %s?\n(Mode uji: tidak ada uang sungguhan yang ditagih.)" % [
		def["name"], Store.price_text(id)]
	dlg.ok_button_text = "Beli"
	dlg.cancel_button_text = "Batal"
	dlg.confirmed.connect(func(): Store.purchase(id))
	dlg.visibility_changed.connect(func():
		if not dlg.visible:
			dlg.queue_free())
	add_child(dlg)
	dlg.popup_centered()


# --- Tutorial, pengenalan fitur, panduan ------------------------------------

## Elemen UI untuk kunci target di Data.TUTORIAL_STEPS.
func tutorial_target(key: String) -> Control:
	if key.begins_with("nav_"):
		return _nav_buttons.get(key.substr(4))
	match key:
		"resources":
			return _res_row
		"affair_silver":
			return _affair_buttons.get("silver")
		"affair_soldiers":
			return _affair_buttons.get("soldiers")
		"upgrade":
			return _first_upgrade_button
		"attack":
			return _attack_button
		"free_recruit":
			return _free_button
		"visit":
			return _first_visit_button
		"missions":
			return _mission_hb["root"]
	return null


## Gulirkan halaman agar elemen yang disorot terlihat.
func tutorial_reveal(target: Control) -> void:
	var n: Node = target.get_parent()
	while n:
		if n is ScrollContainer:
			n.ensure_control_visible(target)
			return
		n = n.get_parent()


func tutorial_finished() -> void:
	_maybe_prompt_login.call_deferred()


func _show_intro(intro: Dictionary) -> void:
	model.mark_intro_seen(intro["id"])
	Audio.play("promote", 0.0)
	var holder := {}
	var close := func():
		Audio.play("click")
		if is_instance_valid(holder.get("overlay")):
			holder["overlay"].queue_free()
	var p := _open_panel(intro["title"], intro["icon"], close, 0.25, 0.68)
	var overlay: Control = p["overlay"]
	holder["overlay"] = overlay
	p["subtitle"].text = "Fitur baru"
	var box: VBoxContainer = p["content"]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	row.add_child(_tex(Art.icon(intro["icon"]), 110))
	_label(_col(row), intro["text"], "CardLabel")
	var page: String = intro["page"]
	var panel: String = intro.get("panel", "")
	var go := _button(box, "Lihat Sekarang", func():
		overlay.queue_free()
		_switch_page(page)
		if panel == "tower":
			_show_tower()
		return null, true, "", "GoldButton")
	go.custom_minimum_size.y = 80


func _show_help() -> void:
	var holder := {}
	var close := func():
		Audio.play("click")
		if is_instance_valid(holder.get("overlay")):
			holder["overlay"].queue_free()
	var p := _open_panel("Panduan", "help", close)
	holder["overlay"] = p["overlay"]
	p["subtitle"].text = "Ringkasan semua fitur"
	for topic in Data.HELP_TOPICS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_inner_box(p["content"]).add_child(row)
		row.add_child(_tex(Art.icon(topic["icon"]), 64))
		var col := _col(row)
		_label(col, topic["title"], "CardLabel").add_theme_font_override("font", UI.font_bold)
		_label(col, topic["text"], "SmallLabel").add_theme_color_override("font_color", UI.INK)


# --- Pengaturan -----------------------------------------------------------

func _show_settings() -> void:
	var holder := {}
	var close := func():
		Audio.play("click")
		if is_instance_valid(holder.get("overlay")):
			holder["overlay"].queue_free()
	var p := _open_panel("Pengaturan", "settings", close)
	holder["overlay"] = p["overlay"]
	p["subtitle"].text = "Profil, suara, dan perangkat"
	var box: VBoxContainer = p["content"]

	var profile := _inner_box(box)
	_label(profile, "Nama Tuan", "CardLabel").add_theme_font_override("font", UI.font_bold)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	profile.add_child(row)
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "Belum diatur"
	name_edit.text = model.lord_name
	name_edit.max_length = model.NAME_MAX
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.custom_minimum_size.y = 64
	name_edit.add_theme_stylebox_override("normal", UI.box(Color("fffaf0"), UI.GOLD_DARK, 2, 12))
	name_edit.add_theme_stylebox_override("focus", UI.box(Color("fffaf0"), UI.GOLD, 3, 12))
	name_edit.add_theme_color_override("font_color", UI.INK)
	name_edit.add_theme_color_override("font_placeholder_color", Color("9a8670"))
	row.add_child(name_edit)
	var save_name := func():
		var r: Dictionary = model.set_lord_name(name_edit.text)
		name_edit.text = model.lord_name
		name_edit.release_focus()
		return r
	name_edit.text_submitted.connect(func(_t):
		var r: Dictionary = save_name.call()
		Audio.play("click" if r["ok"] else "error")
		_show(r))
	_button(row, "Simpan", save_name, true, "", "GoldButton").custom_minimum_size.x = 140
	_label(profile, "Tampil di header, daftar anggota aliansi, arena, dan peringkat.", "SmallLabel") \
		.add_theme_color_override("font_color", UI.INK)

	var sound := _inner_box(box)
	_label(sound, "Suara", "CardLabel").add_theme_font_override("font", UI.font_bold)
	_volume_slider(sound, "Musik latar", "music_volume")
	_volume_slider(sound, "Efek suara", "sfx_volume")

	var lang_box := _inner_box(box)
	_label(lang_box, "Bahasa / Language", "CardLabel").add_theme_font_override("font", UI.font_bold)
	var lang_row := HBoxContainer.new()
	lang_row.add_theme_constant_override("separation", 8)
	lang_box.add_child(lang_row)
	for code in ["auto", "id", "en"]:
		var b := Button.new()
		b.text = "Otomatis" if code == "auto" else I18n.LANGUAGES[code]
		# Nama bahasa selalu ditulis dalam bahasanya sendiri.
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS if code == "auto" \
			else Node.AUTO_TRANSLATE_MODE_DISABLED
		b.theme_type_variation = "GoldButton" if Settings.language == code else ""
		b.custom_minimum_size.y = 64
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(func():
			Audio.play("click")
			if Settings.language == code:
				return
			Settings.set_value("language", code)
			close.call()
			_show_settings.call_deferred())
		lang_row.add_child(b)

	var device := _inner_box(box)
	_label(device, "Perangkat", "CardLabel").add_theme_font_override("font", UI.font_bold)
	_setting_toggle(device, "Hemat baterai", "battery_saver",
		"Batasi 30 FPS dan gambar ulang layar hanya saat ada perubahan.")
	var notif_desc := "Pengingat saat urusan kota penuh, rekrut gratis siap, dan hadiah login."
	if not Notifier.available():
		notif_desc += " (Hanya di Android dengan plugin TlgNotify.)"
	_setting_toggle(device, "Notifikasi", "notifications", notif_desc)

	var data := _inner_box(box)
	_label(data, "Data", "CardLabel").add_theme_font_override("font", UI.font_bold)
	var data_row := HBoxContainer.new()
	data_row.add_theme_constant_override("separation", 10)
	data.add_child(data_row)
	_button(data_row, "Simpan Sekarang", func():
		Game.save_game()
		return {"ok": true, "msg": "Tersimpan"}, true, "", "GreenButton", true).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(data_row, "Mulai Ulang", func():
		close.call()
		return _confirm_reset()).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(data, "Progres tersimpan otomatis tiap 15 detik dan saat game ditutup. Versi %s." % \
		ProjectSettings.get_setting("application/config/version", "0.1.0"), "SmallLabel") \
		.add_theme_color_override("font_color", UI.INK)

	var privacy := _inner_box(box)
	_label(privacy, "Privasi & Laporan Masalah", "CardLabel").add_theme_font_override("font", UI.font_bold)
	_setting_toggle(privacy, "Statistik bermain", "analytics",
		"Jumlah sesi, lama bermain, dan aksi. Hanya disimpan di perangkat ini, tidak dikirim ke mana pun.")
	var st: Dictionary = Telemetry.stats
	var events := 0
	for k in st.get("events", {}):
		events += int(st["events"][k])
	var play := int(st.get("play_seconds", 0))
	_label(privacy, "%d sesi · %d jam %d menit · %d hari aktif · %s aksi" % [int(st.get("sessions", 0)),
		play / 3600, play / 60 % 60, int(st.get("active_days", 0)), _num(events)], "SmallLabel") \
		.add_theme_color_override("font_color", UI.INK)
	var crash: Dictionary = Telemetry.last_crash()
	var crash_text := "Tidak ada crash tercatat." if crash.is_empty() else \
		"Game terakhir berhenti tiba-tiba pada %s." % Time.get_datetime_string_from_unix_time(int(crash["t"]), true)
	_label(privacy, crash_text, "SmallLabel").add_theme_color_override("font_color", UI.INK)
	var privacy_row := HBoxContainer.new()
	privacy_row.add_theme_constant_override("separation", 10)
	privacy.add_child(privacy_row)
	_button(privacy_row, "Salin Laporan", func():
		DisplayServer.clipboard_set(Telemetry.problem_report())
		return {"ok": true, "msg": "Laporan disalin. Tempelkan di email ke pengembang."}).size_flags_horizontal = \
		Control.SIZE_EXPAND_FILL
	_button(privacy_row, "Kebijakan Privasi", func():
		_show_privacy()
		return null).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(privacy, "Hapus Statistik", func():
		Telemetry.clear_stats()
		close.call()
		_show_settings.call_deferred()
		return {"ok": true, "msg": "Statistik bermain dihapus."})


func _show_privacy() -> void:
	var holder := {}
	var close := func():
		Audio.play("click")
		if is_instance_valid(holder.get("overlay")):
			holder["overlay"].queue_free()
	var p := _open_panel("Kebijakan Privasi", "lock", close, 0.08, 0.92)
	holder["overlay"] = p["overlay"]
	p["subtitle"].text = "Ringkasan data yang disimpan game ini"
	for section in Data.PRIVACY_SECTIONS:
		var sec := _inner_box(p["content"])
		_label(sec, section["title"], "CardLabel").add_theme_font_override("font", UI.font_bold)
		_label(sec, section["text"], "SmallLabel").add_theme_color_override("font_color", UI.INK)


func _volume_slider(parent: Node, title: String, key: String) -> void:
	var head := HBoxContainer.new()
	parent.add_child(head)
	var name_l := _label(head, title, "CardLabel")
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value_l := _label(head, "", "CardLabel")
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = Settings.get(key)
	slider.custom_minimum_size.y = 56
	var track := UI.box(Color("d8c49a"), UI.GOLD_DARK, 2, 8)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	slider.add_theme_stylebox_override("slider", track)
	var fill := UI.box(UI.GREEN, Color.TRANSPARENT, 0, 8)
	fill.content_margin_top = 6
	fill.content_margin_bottom = 6
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	var knob := _knob_texture()
	slider.add_theme_icon_override("grabber", knob)
	slider.add_theme_icon_override("grabber_highlight", knob)
	parent.add_child(slider)
	var render := func(v: float):
		value_l.text = "Mati" if v <= 0 else "%d%%" % int(v)
	render.call(slider.value)
	slider.value_changed.connect(func(v: float):
		render.call(v)
		Settings.set_value(key, int(v)))
	if key == "sfx_volume":
		slider.drag_ended.connect(func(_changed): Audio.play("click"))


var _knob: ImageTexture


func _knob_texture() -> ImageTexture:
	if _knob == null:
		var img := Image.create(44, 44, false, Image.FORMAT_RGBA8)
		for y in 44:
			for x in 44:
				var d := Vector2(x - 21.5, y - 21.5).length()
				if d <= 21.0:
					img.set_pixel(x, y, UI.GOLD_DARK if d > 17.0 else UI.GOLD)
		_knob = ImageTexture.create_from_image(img)
	return _knob


func _setting_toggle(parent: Node, title: String, key: String, desc: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var col := _col(row)
	_label(col, title, "CardLabel")
	_label(col, desc, "SmallLabel").add_theme_color_override("font_color", UI.INK)
	var b := Button.new()
	b.custom_minimum_size = Vector2(130, 64)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var refresh := func():
		var on: bool = Settings.get(key)
		b.text = "Nyala" if on else "Mati"
		b.theme_type_variation = "GreenButton" if on else ""
	refresh.call()
	b.pressed.connect(func():
		Settings.set_value(key, not Settings.get(key))
		Audio.play("click")
		refresh.call())
	row.add_child(b)


# --- Ringkasan saat kembali ------------------------------------------------

func _show_away() -> void:
	var report: Dictionary = Game.away
	Game.away = {}
	var holder := {}
	var close := func():
		Audio.play("click")
		if is_instance_valid(holder.get("overlay")):
			holder["overlay"].queue_free()
		_maybe_prompt_login.call_deferred()
	Audio.play("promote", 0.0)
	var p := _open_panel("Selamat Datang Kembali", "tab_city", close, 0.16, 0.76)
	holder["overlay"] = p["overlay"]
	p["subtitle"].text = "Tuan pergi selama " + _away_text(int(report["seconds"]))
	for line in report["lines"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_inner_box(p["content"]).add_child(row)
		row.add_child(_tex(Art.icon(line["icon"]), 56))
		_label(_col(row), line["text"], "CardLabel")
	_button(p["content"], "Lanjutkan", close, true, "", "GoldButton").custom_minimum_size.y = 80


static func _away_text(seconds: int) -> String:
	if seconds >= 86400:
		return "%d hari %d jam" % [seconds / 86400, seconds / 3600 % 24]
	if seconds >= 3600:
		return "%d jam %d menit" % [seconds / 3600, seconds / 60 % 60]
	return "%d menit" % (seconds / 60)


# --- Hadiah login harian --------------------------------------------------

## Buka kalender login sekali per hari bila hadiahnya belum diklaim.
func _maybe_prompt_login() -> void:
	if model.tutorial_active():
		Game.away = {}
		return  # ditampilkan setelah tutorial selesai (tutorial_finished)
	_startup_prompted = true
	if not Game.away.is_empty():
		# Hadiah login menyusul setelah ringkasan ditutup. Bila ada panel lain
		# terbuka, _tick() mencoba lagi setelah panel itu ditutup.
		if get_tree().get_nodes_in_group("modal").is_empty():
			_show_away()
		return
	var now: float = Game.now()
	if _login_prompted_day == model.day_index(now):
		return
	_login_prompted_day = model.day_index(now)
	if model.login_can_claim(now):
		_show_login()


func _show_login() -> void:
	if is_instance_valid(_login_overlay):
		return
	var p := _open_panel("Hadiah Login Harian", "calendar", _close_login, 0.12, 0.7)
	_login_overlay = p["overlay"]
	_login_box = p["content"]
	_login_subtitle = p["subtitle"]
	_fill_login()
	_tick()


func _close_login() -> void:
	if is_instance_valid(_login_overlay):
		Audio.play("click")
		_login_overlay.queue_free()
	_login_overlay = null


func _fill_login() -> void:
	_clear(_login_box)
	var now: float = Game.now()
	var claimed: int = model.login_claimed_days(now)
	var today: int = model.login_day(now)
	var can: bool = model.login_can_claim(now)
	_login_subtitle.text = "Berturut-turut %d hari · Total %d hari" % [
		model.login["streak"] if not model.login_streak_broken(now) else 0, model.login["total"]]
	_login_next_label = null
	if can and model.login_streak_broken(now):
		var warn := _label(_login_box, "Rangkaian login terputus, kalender dimulai lagi dari Hari 1.", "CardLabel")
		warn.add_theme_color_override("font_color", UI.RED)
	_label(_login_box, "Login setiap hari tanpa terputus. Hari 7 berisi hadiah besar!", "CardLabel")

	var rows := [[0, 1, 2, 3], [4, 5, 6]]
	for row_days in rows:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_login_box.add_child(row)
		for i in row_days:
			row.add_child(_login_cell(i, i < claimed, can and i == today - 1))

	if can:
		var day7: bool = today == Data.LOGIN_REWARDS.size()
		var b := _button(_login_box, "Klaim Hari %d" % today, func(): return model.claim_login(Game.now()),
			true, "calendar", "GreenButton", false, "reveal_ssr" if day7 else "reveal_sr")
		b.custom_minimum_size.y = 84
	else:
		_login_next_label = _label(_login_box, "", "CardLabel")
		_login_next_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_login_next_label.add_theme_font_override("font", UI.font_bold)


func _login_cell(i: int, claimed: bool, is_today: bool) -> Control:
	var def: Dictionary = Data.LOGIN_REWARDS[i]
	var big := i == Data.LOGIN_REWARDS.size() - 1
	var bg := Color("fff3c8") if is_today else (Color("e2cfa6") if claimed else Color(1, 1, 1, 0.45))
	var style := UI.box(bg, UI.GOLD if is_today else UI.GOLD_DARK, 4 if is_today else 2, 12)
	style.set_content_margin_all(8)
	if is_today:
		style.shadow_color = Color(UI.GOLD, 0.8)
		style.shadow_size = 10
	var cell := PanelContainer.new()
	cell.add_theme_stylebox_override("panel", style)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.size_flags_stretch_ratio = 2.0 if big else 1.0
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	cell.add_child(v)
	var title := _label(v, "Hari %d" % (i + 1), "CardLabel")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UI.font_bold)

	var side := 78.0 if big else 58.0
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(side, side)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(holder)
	var main_key := "gold"
	for key in Data.REWARD_KEYS:
		if def.has(key):
			main_key = key
			break
	var icon := _tex(Art.icon("chest" if big else main_key), side)
	if claimed:
		icon.modulate = Color(1, 1, 1, 0.45)
	holder.add_child(icon)
	if claimed:
		var tick := _tex(Art.icon("check"), side * 0.6)
		tick.position = Vector2(side * 0.45, side * 0.4)
		holder.add_child(tick)

	var reward := _label(v, _reward_text(def).replace(", ", "\n"), "SmallLabel")
	reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward.add_theme_color_override("font_color", UI.INK)
	reward.add_theme_font_size_override("font_size", 16)
	if is_today:
		var glow := cell.create_tween().set_loops()
		glow.tween_property(cell, "self_modulate", Color(1.12, 1.08, 0.9), 0.5)
		glow.tween_property(cell, "self_modulate", Color.WHITE, 0.5)
	return cell


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


func _build_rateup(box: VBoxContainer) -> void:
	var now: float = Game.now()
	var feat: String = model.rateup_id(now)
	var def: Dictionary = Data.counselor_def(feat)
	var card := _card(box)
	card.add_child(_portrait_frame(feat, 110))
	var col := _col(card)
	_label(col, "BANNER MINGGU INI", "SmallLabel").add_theme_color_override("font_color", _rarity_color("ssr"))
	_label(col, def["name"], "CardTitle")
	var skill: Dictionary = Data.SKILLS.get(feat, {})
	if not skill.is_empty():
		_label(col, "%s: %s" % [skill["name"], Data.SKILL_EFFECT_NAMES[skill["effect"]] % roundi(model.skill_value(feat) * 100
			if model.counselors.has(feat) else float(skill["base"]) * 100)], "SmallLabel") \
			.add_theme_color_override("font_color", Color("6c3483"))
	var chance := roundi(Data.RATEUP_CHANCE * 100)
	if model.rateup_guarantee:
		_label(col, "Legenda berikutnya dijamin %s!" % def["name"], "CardLabel") \
			.add_theme_color_override("font_color", UI.GREEN)
	else:
		_label(col, "%d%% Legenda yang didapat adalah %s. Bila meleset, Legenda berikutnya pasti %s." % [
			chance, def["name"], def["name"]], "SmallLabel").add_theme_color_override("font_color", UI.INK)
	var left := _label(col, "", "SmallLabel")
	left.add_theme_color_override("font_color", UI.INK)
	left.text = "Berganti dalam %s" % _duration(model.seconds_until_week_end(now))


func _build_gacha(page: Dictionary) -> void:
	if not _gacha_banner_done:
		_gacha_banner_done = true
		var banner: Control = page["banner"]
		var feat: String = model.rateup_id(Game.now())
		var other: String = Data.counselors_of_rarity("ssr").filter(func(c): return c["id"] != feat)[0]["id"]
		for i in 2:
			var f := _portrait_frame([feat, other][i], 120)
			f.position = Vector2(30 if i == 0 else 720 - 30 - 132, 30)
			banner.add_child(f)
		page["title"].position.x = 20

	var box: VBoxContainer = page["content"]
	_clear(box)
	_build_rateup(box)
	var info := _card(box)
	info.add_child(_tex(Art.icon("gold"), 92))
	var col := _col(info)
	_label(col, "Emas: %s" % _num(model.gold), "CardTitle")
	var ssr_rate: float = Data.RARITIES["ssr"]["rate"] + model.event_bonus("ssr_rate")
	var sr_rate: float = Data.RARITIES["sr"]["rate"]
	_label(col, "Legenda %d%% · Epik %d%% · Langka %d%%" % [
		roundi(ssr_rate * 100), roundi(sr_rate * 100), roundi((1.0 - ssr_rate - sr_rate) * 100)], "CardLabel")
	_event_tag(col, "ssr_rate")
	_label(col, "Legenda dijamin dalam %d tarikan" % model.pity_left(), "CardLabel")
	_bar(col, Data.GACHA_PITY - model.pity_left(), Data.GACHA_PITY, _rarity_color("ssr"))

	if Ads.mode != Ads.Mode.UNAVAILABLE:
		_ad_button(box, "recruit")
		_ad_button(box, "gold")
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
	_label(pcol, ("x10 dijamin minimal satu Epik. Duplikat menambah bintang (+%d%% atribut), "
		+ "atau perak bila bintang sudah penuh.") % int(Data.STAR_BONUS * 100), "CardLabel")
	if model.item_count("recruit_ticket") > 0:
		_button(pcol, "Pakai Tiket Rekrut (%d)" % model.item_count("recruit_ticket"), func():
			var r: Dictionary = model.recruit(1, Game.now(), false, true)
			if r["ok"]:
				_show_recruit(r["results"])
				return {"ok": true}
			return r, true, "ticket_recruit", "GoldButton", false, "gacha_roll").add_theme_font_size_override("font_size", 24)
	_label(pcol, "Emas didapat dari kampanye (bonus tiap 5 tahap) dan naik jabatan.", "CardLabel")
	if model.gold < Data.GACHA_COST_10:
		_button(pcol, "Beli Emas di Toko", func():
			_show_store()
			return null, true, "store", "GreenButton")

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
	overlay.add_to_group("modal")
	add_child(overlay)
	move_child(overlay, _toast.get_index())
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
	var now: float = Game.now()
	_segment_tabs(box, [["selir", "Selir"], ["anak", "Anak (%d)" % model.children.size()],
		["penjara", "Penjara (%d)" % model.prison["prisoners"].size()], ["perjamuan", "Perjamuan"]],
		_palace_tab, func(key): _palace_tab = key, 20)
	match _palace_tab:
		"anak":
			_build_children(box, now)
		"penjara":
			_build_prison(box, now)
		"perjamuan":
			_build_banquet(box, now)
		_:
			_build_consorts(box)


func _build_consorts(box: VBoxContainer) -> void:
	var energy := _card(box)
	energy.add_child(_tex(Art.icon("heart"), 72))
	var ecol := _col(energy)
	_label(ecol, "Energi Kunjungan", "CardTitle")
	_charge_widget(ecol, "visit", "Energi")
	_event_tag(ecol, "child_chance")

	for id in model.beauties:
		var card := _card(box)
		card.add_child(_tex(Art.portrait(id), 150))
		var col := _col(card)
		_label(col, Data.beauty_def(id)["name"], "CardTitle")
		var intimacy: int = model.beauties[id]["intimacy"]
		_icon_row(col, "heart", "Keakraban %d  ·  +%d Karisma" % [intimacy, intimacy])
		var visit := _button(col, "Kunjungi", func(): return model.visit_beauty(id, Game.now()), true, "heart",
			"", false, "heart")
		if id == model.beauties.keys()[0]:
			_first_visit_button = visit


func _build_children(box: VBoxContainer, now: float) -> void:
	_train_waits.clear()
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
			var wait: int = model.train_wait(i, now)
			var train := _button(col, "Didik  %s" % _num(cost), func(): return model.train_child(i, Game.now()),
				model.grain >= cost and wait == 0, "grain", "", false, "upgrade")
			if wait > 0:
				train.text = "Istirahat %02d:%02d" % [wait / 60, wait % 60]
				_train_waits.append({"button": train, "index": i, "cost": cost})
		else:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			col.add_child(row)
			var marry := _button(row, "Nikahkan", func(): return model.marry_child(i), true, "heart", "GoldButton",
				false, "birth")
			marry.add_theme_font_size_override("font_size", 22)
			marry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var can_exam: bool = model.exam_available(i, now) and model.silver >= model.exam_cost(i) \
				and model.officials.size() < Data.OFFICIALS_MAX
			var exam := _button(row, "Ujian %s" % _num(model.exam_cost(i)), func(): return model.take_exam(i, Game.now()),
				can_exam, "item_scroll", "GreenButton", false, "promote")
			exam.add_theme_font_size_override("font_size", 22)
			exam.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var hint := "Peluang lulus ujian %d%%" % roundi(model.exam_chance(i) * 100)
			if not model.exam_available(i, now):
				hint = "Sudah ujian hari ini, coba lagi besok"
			_label(col, hint, "SmallLabel").add_theme_color_override("font_color", UI.INK)
	_label(box, "Anak yang telah menikah: %d" % model.married_count, "SmallLabel")

	var off := _label(box, "Pejabat (%d/%d) · hasil urusan kota +%d%%" % [model.officials.size(), Data.OFFICIALS_MAX,
		roundi(model.officials_bonus() * 100)], "TitleLabel")
	off.add_theme_font_size_override("font_size", 24)
	if model.officials.is_empty():
		_label(box, "Anak dewasa yang lulus Ujian Negara menjadi pejabat dan memberi bonus permanen.", "SmallLabel")
	for o in model.officials:
		var card := _card(box)
		card.add_child(_tex(Art.portrait("child_f" if o["gender"] == "f" else "child_m"), 72))
		var col := _col(card)
		_label(col, "%s · %s" % [o["name"], o["title"]], "CardTitle").add_theme_font_size_override("font_size", 22)
		var bonus := 0.0
		for t in Data.OFFICIAL_TITLES:
			if t["name"] == o["title"]:
				bonus = t["bonus"]
		_label(col, "Bakat %d/5 · hasil urusan kota +%d%%" % [o["talent"], roundi(bonus * 100)], "CardLabel")


func _build_prison(box: VBoxContainer, now: float) -> void:
	var info := _card(box)
	info.add_child(_tex(Art.icon("prison"), 80))
	var col := _col(info)
	_label(col, "Penjara (%d/%d)" % [model.prison["prisoners"].size(), Data.PRISON_CAPACITY], "CardTitle")
	_label(col, "Interogasi tersisa hari ini: %d / %d · biaya %d pangan" % [model.prison_left(now),
		Data.PRISON_DAILY_LIMIT, Data.PRISON_COST_GRAIN], "CardLabel")
	_label(col, "Tahanan ditangkap dari kemenangan kampanye. Patahkan daya tahannya sampai mengaku.", "SmallLabel") \
		.add_theme_color_override("font_color", UI.INK)
	if model.prison["prisoners"].is_empty():
		_label(box, "Penjara kosong. Menangkan kampanye untuk menangkap tahanan.", "SmallLabel")
	var can: bool = model.prison_left(now) > 0 and model.grain >= Data.PRISON_COST_GRAIN
	for i in model.prison["prisoners"].size():
		var p: Dictionary = model.prison["prisoners"][i]
		var card := _card(box)
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(110, 110)
		card.add_child(holder)
		var pic := _tex(Art.portrait(p["avatar"]), 110)
		pic.modulate = Color(0.75, 0.7, 0.7)
		holder.add_child(pic)
		var bars := _tex(Art.icon("prison"), 110)
		bars.modulate = Color(1, 1, 1, 0.75)
		holder.add_child(bars)
		var pcol := _col(card)
		_label(pcol, p["name"], "CardTitle").add_theme_font_size_override("font_size", 22)
		var st: Dictionary = Data.prisoner_stats(int(p["stage"]))
		_label(pcol, "Daya tahan %s / %s · bila mengaku: +%s perak, +%d prestise" % [_num(p["hp"]), _num(p["max"]),
			_num(st["silver"]), st["prestige"]], "SmallLabel").add_theme_color_override("font_color", UI.INK)
		_bar(pcol, p["hp"], p["max"], Color("c0392b"))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		pcol.add_child(row)
		var idx: int = i
		for method in Data.PRISON_METHODS:
			var m: Dictionary = Data.PRISON_METHODS[method]
			var key: String = method
			var b := _button(row, "%s ~%s" % [m["name"], _num(model.prison_damage(method))], func():
				var r: Dictionary = model.interrogate(idx, key, Game.now())
				if r["ok"] and not r.get("confessed", false):
					_float("-%s" % _num(r["damage"]), pic, Color("ff8a70"))
				return r, can, "", "GoldButton" if method == "interrogate" else "", false, "attack")
			b.add_theme_font_size_override("font_size", 20)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.custom_minimum_size.y = 60
		var free := _button(pcol, "Bebaskan (+%d prestise)" % Data.PRISON_RELEASE_PRESTIGE,
			func(): return model.release_prisoner(idx), true, "", "GreenButton")
		free.custom_minimum_size.y = 52
		free.add_theme_font_size_override("font_size", 18)


func _build_banquet(box: VBoxContainer, now: float) -> void:
	for kind in Data.BANQUETS:
		var def: Dictionary = Data.BANQUETS[kind]
		var card := _card(box)
		card.add_child(_tex(Art.icon("event_palace" if kind == "grand" else "item_tea"), 84))
		var col := _col(card)
		_label(col, def["name"], "CardTitle")
		var cost := []
		for key in def["cost"]:
			cost.append("%s %s" % [_num(def["cost"][key]), Data.REWARD_NAMES[key]])
		var extra := " · +%d exp aliansi" % def["alliance_exp"] if int(def["alliance_exp"]) > 0 else ""
		_label(col, "Biaya %s · %d+ tamu, %d+ prestise, %d hadiah%s" % [" + ".join(cost), def["guests"],
			def["prestige"], def["items"], extra], "SmallLabel").add_theme_color_override("font_color", UI.INK)
		var ok: bool = model.banquet_available(kind, now)
		for key in def["cost"]:
			ok = ok and int(model.get(key)) >= int(def["cost"][key])
		var k: String = kind
		_button(col, "Adakan" if model.banquet_available(kind, now) else "Sudah diadakan hari ini",
			func(): return model.hold_banquet(k, Game.now()), ok, "", "GoldButton" if kind == "grand" else "GreenButton",
			false, "promote")
	var head := _label(box, "Undangan Hari Ini", "TitleLabel")
	head.add_theme_font_size_override("font_size", 26)
	var invites: Array = model.banquet_invites(now)
	for i in invites.size():
		var inv: Dictionary = invites[i]
		var card := _card(box)
		card.add_child(_tex(Art.portrait(inv["avatar"]), 72))
		var col := _col(card)
		_label(col, "Perjamuan %s" % inv["host"], "CardLabel").add_theme_font_override("font", UI.font_bold)
		_label(col, "Bawa hadiah %s perak · +%d prestise" % [_num(Data.INVITE_GIFT_SILVER), Data.INVITE_PRESTIGE],
			"SmallLabel").add_theme_color_override("font_color", UI.INK)
		var idx: int = i
		var b := _button(card, "Hadir" if not inv["attended"] else "Sudah hadir", func(): return model.attend_banquet(idx, Game.now()),
			not inv["attended"] and model.silver >= Data.INVITE_GIFT_SILVER, "", "GreenButton", false, "coin")
		b.custom_minimum_size = Vector2(150, 60)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
