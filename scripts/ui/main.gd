extends Control
## UI utama, dibangun lewat kode supaya mudah dibaca dan diubah.
## Tab: Kota (urusan), Penasihat, Kampanye, Istana.

const Data := preload("res://scripts/core/game_data.gd")

var model
var _header: Label
var _toast: Label
var _tabs: TabContainer
var _city: VBoxContainer
var _counselor_list: VBoxContainer
var _campaign: VBoxContainer
var _palace: VBoxContainer
## Label hitung mundur yang diperbarui tiap detik: key -> Label
var _charge_labels := {}


func _ready() -> void:
	model = Game.model
	theme = _make_theme()

	var bg := ColorRect.new()
	bg.color = Color("2b1d14")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	_header = Label.new()
	_header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_header.add_theme_color_override("font_color", Color("f5d08a"))
	root.add_child(_margin(_header))

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_tabs)
	_city = _add_tab("Kota")
	_counselor_list = _add_tab("Penasihat")
	_campaign = _add_tab("Kampanye")
	_palace = _add_tab("Istana")

	_toast = Label.new()
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.custom_minimum_size.y = 90
	root.add_child(_margin(_toast))

	model.changed.connect(_queue_rebuild)
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_tick)
	add_child(timer)
	_rebuild()


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 26
	return t


func _add_tab(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	var m := _margin(box)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(m)
	_tabs.add_child(scroll)
	return box


func _margin(child: Control) -> MarginContainer:
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 12)
	m.add_child(child)
	return m


func _panel(parent: Container) -> VBoxContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("4a3222")
	style.set_corner_radius_all(10)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	panel.add_child(box)
	parent.add_child(panel)
	return box


func _label(parent: Container, text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l


func _button(parent: Container, text: String, action: Callable, enabled := true) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 64
	b.disabled = not enabled
	b.pressed.connect(func(): _show(action.call()))
	parent.add_child(b)
	return b


func _show(result) -> void:
	if result is Dictionary and result.has("msg"):
		_toast.text = result["msg"]
		_toast.add_theme_color_override("font_color", Color("9be08a") if result["ok"] else Color("ff9a8a"))


func _clear(box: Container) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


# --- Render ---------------------------------------------------------------

var _rebuild_queued := false


## Ditunda ke akhir frame supaya tombol yang sedang ditekan tidak dihapus
## di tengah sinyalnya sendiri.
func _queue_rebuild() -> void:
	if not _rebuild_queued:
		_rebuild_queued = true
		_rebuild.call_deferred()


func _rebuild() -> void:
	_rebuild_queued = false
	_build_city()
	_build_counselors()
	_build_campaign()
	_build_palace()
	_tick()


func _tick() -> void:
	var now: float = Game.now()
	model.sync(now)
	_header.text = "%s  •  Kekuatan %d  •  Prestise %d\nPerak %d   Pangan %d   Prajurit %d" % [
		model.rank_info()["name"], model.power(), model.prestige,
		model.silver, model.grain, model.soldiers]
	for key in _charge_labels:
		var lbl: Label = _charge_labels[key]
		if not is_instance_valid(lbl):
			continue
		var eta: int = model.charge_eta(key, now)
		lbl.text = "Sisa: %d/%d%s" % [
			model.charge_value(key, now), model.max_charges(),
			"" if eta == 0 else "  (+1 dalam %ds)" % eta]


func _charge_label(parent: Container, key: String) -> void:
	_charge_labels[key] = _label(parent, "")


func _build_city() -> void:
	_clear(_city)
	_charge_labels.clear()
	for kind in model.AFFAIRS:
		var a: Dictionary = model.AFFAIRS[kind]
		var p := _panel(_city)
		_label(p, "%s — hasil +%d %s (berdasar %s)" % [
			a["label"], model.affair_yield(kind), model.resource_name(kind), Data.ATTR_NAMES[a["attr"]]])
		_charge_label(p, kind)
		_button(p, a["label"], func(): return model.do_affair(kind, Game.now()))

	var p := _panel(_city)
	var nxt: Dictionary = model.next_rank_info()
	if nxt.is_empty():
		_label(p, "Anda telah mencapai jabatan tertinggi.")
	else:
		_label(p, "Jabatan berikutnya: %s (butuh %d prestise)" % [nxt["name"], nxt["prestige"]])
		_button(p, "Naik Jabatan", model.promote, model.can_promote())

	var sys := _panel(_city)
	_button(sys, "Simpan Sekarang", func():
		Game.save_game()
		return {"ok": true, "msg": "Tersimpan."})
	_button(sys, "Mulai Ulang (hapus progres)", func():
		var dlg := ConfirmationDialog.new()
		dlg.dialog_text = "Hapus semua progres dan mulai dari awal?"
		dlg.confirmed.connect(func():
			Game.reset_game()
			_show({"ok": true, "msg": "Game baru dimulai."}))
		dlg.visibility_changed.connect(func():
			if not dlg.visible:
				dlg.queue_free())
		add_child(dlg)
		dlg.popup_centered()
		return null)


func _build_counselors() -> void:
	_clear(_counselor_list)
	_label(_counselor_list, "Total — Kekuatan %d • Kecerdasan %d • Politik %d • Karisma %d" % [
		model.total_attr("str"), model.total_attr("int"), model.total_attr("pol"), model.total_attr("cha")])
	for id in model.counselors:
		var def: Dictionary = Data.counselor_def(id)
		var p := _panel(_counselor_list)
		_label(p, "%s  (Lv %d/%d)" % [def["name"], model.counselors[id]["level"], model.rank_info()["level_cap"]])
		_label(p, "KEK %d   CER %d   POL %d   KAR %d" % [
			model.attr(id, "str"), model.attr(id, "int"), model.attr(id, "pol"), model.attr(id, "cha")])
		var cost: int = model.upgrade_cost(id)
		_button(p, "Latih (%d perak)" % cost, func(): return model.upgrade_counselor(id), model.silver >= cost)
	for c in Data.COUNSELORS:
		if not model.counselors.has(c["id"]):
			_label(_counselor_list, "[Terkunci] %s — menangkan Tahap %d" % [c["name"], c["unlock_stage"]])


func _build_campaign() -> void:
	_clear(_campaign)
	var info: Dictionary = model.current_stage_info()
	var losses: int = model.expected_losses()
	var p := _panel(_campaign)
	_label(p, info["name"])
	_label(p, "Musuh: %d prajurit, kekuatan %d" % [info["enemy_soldiers"], info["enemy_str"]])
	_label(p, "Kekuatan Anda: %d → perkiraan gugur %d prajurit" % [model.total_attr("str"), losses])
	_label(p, "Hadiah: %d perak, %d prestise" % [info["reward_silver"], info["reward_prestige"]])
	_button(p, "Serang!", model.fight_stage)
	_label(_campaign, "Tips: latih penasihat dengan Kekuatan tinggi untuk mengurangi korban.")


func _build_palace() -> void:
	_clear(_palace)
	var p := _panel(_palace)
	_label(p, "Energi kunjungan")
	_charge_label(p, "visit")
	for id in model.beauties:
		var b := _panel(_palace)
		_label(b, "%s — keakraban %d" % [Data.beauty_def(id)["name"], model.beauties[id]["intimacy"]])
		_button(b, "Kunjungi", func(): return model.visit_beauty(id, Game.now()))

	_label(_palace, "Anak (%d/%d kursi)" % [model.children.size(), model.child_seats()])
	for i in model.children.size():
		var child: Dictionary = model.children[i]
		var c := _panel(_palace)
		_label(c, "%s  (bakat %d/5)  Lv %d/%d" % [
			child["name"], child["talent"], child["level"], Data.CHILD_MAX_LEVEL])
		if child["level"] < Data.CHILD_MAX_LEVEL:
			var cost: int = model.train_cost(i)
			_button(c, "Didik (%d pangan)" % cost, func(): return model.train_child(i), model.grain >= cost)
		else:
			_button(c, "Nikahkan", func(): return model.marry_child(i))
	_label(_palace, "Anak yang telah menikah: %d" % model.married_count)
