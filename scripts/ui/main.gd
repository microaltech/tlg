extends "res://scripts/ui/main_base.gd"
## Layar utama: panel Pengaturan, ringkasan kembali, hadiah login, dan panel lain.
## Helper UI dan halaman ada di main_base.gd.

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
	name_edit.add_theme_stylebox_override("normal", UI.box(UI.INPUT_BG, UI.GOLD_DARK, 2, 12))
	name_edit.add_theme_stylebox_override("focus", UI.box(UI.INPUT_BG, UI.GOLD, 3, 12))
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
	var lang_row := GridContainer.new()
	lang_row.columns = 2
	lang_row.add_theme_constant_override("h_separation", 8)
	lang_row.add_theme_constant_override("v_separation", 8)
	lang_box.add_child(lang_row)
	for code in ["auto"] + I18n.LANGUAGES.keys():
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
	_setting_toggle(device, "Mode malam", "dark_mode", "Tema gelap yang nyaman di mata saat bermain malam hari.")
	_label(device, "Ukuran tampilan", "CardLabel")
	var scale_row := HBoxContainer.new()
	scale_row.add_theme_constant_override("separation", 8)
	device.add_child(scale_row)
	for opt in [["Kecil", 0.9], ["Normal", 1.0], ["Besar", 1.1], ["Ekstra", 1.25]]:
		var sb := Button.new()
		sb.text = opt[0]
		sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sb.custom_minimum_size.y = 64
		sb.theme_type_variation = "GoldButton" if is_equal_approx(Settings.ui_scale, opt[1]) else ""
		sb.add_theme_font_size_override("font_size", 22)
		var value: float = opt[1]
		sb.pressed.connect(func():
			Audio.play("click")
			Settings.set_value("ui_scale", value))
		scale_row.add_child(sb)
	_setting_toggle(device, "Ramah buta warna", "colorblind",
		"Ganti merah dan hijau dengan oranye dan biru agar mudah dibedakan (buta warna merah-hijau).")
	_setting_toggle(device, "Getar", "vibration", "Getar singkat saat menang, naik jabatan, atau mendapat penasihat Legenda.")
	_setting_toggle(device, "Kalender login teks", "simple_login",
		"Tampilkan hadiah login sebagai daftar teks. Nyala otomatis bila kalender bergambar membuat game berhenti.")
	_setting_toggle(device, "Lewati tayangan perang", "skip_battles",
		"Langsung tampilkan hasil perang tanpa animasi. Hasil pertempuran tetap sama.")

	_build_online_section(box)
	_realm_ui.build_redeem(box)

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

	_build_backup_section(box, close)
	_build_wellbeing_section(box)
	_button(box, "Laporkan Masalah / Saran", func():
		close.call()
		_show_feedback.call_deferred()
		return null, true, "mail", "GreenButton")
	if Game.debug_enabled():
		_build_debug_section(box)

	var privacy := _inner_box(box)
	_label(privacy, "Privasi & Laporan Masalah", "CardLabel").add_theme_font_override("font", UI.font_bold)
	_setting_toggle(privacy, "Statistik bermain", "analytics",
		"Jumlah sesi, lama bermain, dan aksi. Hanya disimpan di perangkat ini, tidak dikirim ke mana pun.")
	_setting_toggle(privacy, "Bagikan statistik anonim", "share_stats",
		"Sekali sehari kirim angka ringkas (sesi, menit, tahap, jabatan, jumlah aksi) dengan ID acak ke server pengembang"
		+ " untuk memperbaiki game. Tanpa nama, akun, atau isi chat. Mati sejak awal.")
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


## Mode uji cepat: hanya ada di build debug (APK uji), tidak pernah di build rilis Play Store.
func _build_debug_section(box: VBoxContainer) -> void:
	var dbg := _inner_box(box)
	_label(dbg, "Uji Cepat (build debug)", "CardLabel").add_theme_font_override("font", UI.font_bold)
	var off := int(Game.time_offset)
	var info := _label(dbg, tr("Jam game maju %d jam %d menit dari jam HP.") % [off / 3600, off / 60 % 60], "SmallLabel")
	info.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	info.add_theme_color_override("font_color", UI.INK)
	var rows := [
		[["+10 Tahap", func(): return model.debug_skip_stages(10)],
			["+Sumber Daya", func(): return model.debug_grant()]],
		[["Maju 1 Jam", func():
			Game.debug_advance(3600)
			return {"ok": true, "msg": "Jam game maju 1 jam."}],
			["Maju 1 Hari", func():
			Game.debug_advance(86400)
			return {"ok": true, "msg": "Jam game maju 1 hari."}]],
	]
	for r in rows:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		dbg.add_child(row)
		for b in r:
			_button(row, b[0], b[1]).size_flags_horizontal = Control.SIZE_EXPAND_FILL


## Cadangan save: kode yang bisa disalin/ditempel, dan Google Play Games bila tersedia.
## Pengaturan server sosial: alamat server, status, dan tombol sambung/putus.
func _build_online_section(box: VBoxContainer) -> void:
	var sec := _inner_box(box)
	_label(sec, "Server Online", "CardLabel").add_theme_font_override("font", UI.font_bold)
	_label(sec, "Isi alamat server untuk chat aliansi, peringkat, dan arena dengan pemain sungguhan. "
		+ "Kosongkan untuk bermain offline.", "SmallLabel").add_theme_color_override("font_color", UI.INK)
	var status := _label(sec, "", "SmallLabel")
	var refresh := func():
		if not is_instance_valid(status):
			return
		match Online.status:
			Online.Status.ONLINE:
				status.text = tr("Tersambung sebagai %s") % str(Online.player.get("name", ""))
				status.add_theme_color_override("font_color", UI.GREEN.darkened(0.3))
			Online.Status.CONNECTING:
				status.text = tr("Menyambungkan...")
				status.add_theme_color_override("font_color", UI.INK)
			Online.Status.ERROR:
				status.text = tr("Gagal: %s") % tr(Online.error)
				status.add_theme_color_override("font_color", UI.RED)
			_:
				status.text = tr("Offline")
				status.add_theme_color_override("font_color", UI.INK)
	refresh.call()
	Online.status_changed.connect(refresh)
	sec.tree_exiting.connect(func(): Online.status_changed.disconnect(refresh))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	sec.add_child(row)
	var url := LineEdit.new()
	url.text = Settings.server_url
	url.placeholder_text = "https://server-anda.contoh.id"
	url.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	url.custom_minimum_size.y = 60
	row.add_child(url)
	var go := _button(row, "Sambungkan", func():
		Online.set_server(url.text)
		return null, true, "", "GreenButton")
	go.custom_minimum_size.x = 170
	if Settings.server_url != "":
		_button(sec, "Putuskan (main offline)", func():
			Online.set_server("")
			url.text = ""
			return null)
		_build_transfer_section(sec)
		_button(sec, "Hapus Akun Online", func():
			_confirm("Hapus akun online dan semua datanya di server (teman, surat, dagangan, save server)? "
				+ "Progres di HP ini tetap ada.", "Hapus", func():
				Online.delete_account(func(r: Dictionary): _show(r)))
			return null, Online.is_online(), "", "")


## Pindah perangkat lewat server: kode sekali pakai (24 jam) memindahkan akun dan save.
func _build_transfer_section(sec: VBoxContainer) -> void:
	_label(sec, "Pindah Perangkat", "CardLabel").add_theme_font_override("font", UI.font_bold)
	_label(sec, "Di HP lama: buat kode pindah. Di HP baru: sambungkan ke server yang sama lalu masukkan kodenya. "
		+ "Progres disimpan otomatis ke server setiap 10 menit.", "SmallLabel").add_theme_color_override("font_color", UI.INK)
	var code_label := _label(sec, "", "CardTitle")
	code_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_button(sec, "Buat Kode Pindah", func():
		Online.create_transfer(func(code: String, err: String):
			if code == "":
				_show({"ok": false, "msg": err if err != "" else "Tidak bisa terhubung ke server."})
				return
			if is_instance_valid(code_label):
				code_label.text = tr("Kode pindah: %s (berlaku 24 jam)") % code
			DisplayServer.clipboard_set(code)
			_show({"ok": true, "msg": "Kode pindah disalin. Masukkan di HP baru dalam 24 jam."}))
		return null, Online.is_online(), "", "GreenButton")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	sec.add_child(row)
	var edit := LineEdit.new()
	edit.placeholder_text = tr("Kode pindah dari HP lama")
	edit.max_length = 8
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.custom_minimum_size.y = 60
	row.add_child(edit)
	_button(row, "Pindahkan", func():
		var text := edit.text.strip_edges()
		if text.length() < 8:
			return {"ok": false, "msg": "Kode pindah terdiri dari 8 huruf/angka."}
		_confirm("Progres di HP ini akan diganti dengan akun dari HP lama. Lanjutkan?", "Pindahkan", func():
			Online.claim_transfer(text, func(r: Dictionary):
				_show(r)
				if r["ok"]:
					_queue_rebuild()))
		return null, true, "", "GoldButton").custom_minimum_size.x = 170


func _build_backup_section(box: VBoxContainer, close: Callable) -> void:
	var backup := _inner_box(box)
	_label(backup, "Cadangan Save", "CardLabel").add_theme_font_override("font", UI.font_bold)
	_label(backup, "Pindah HP? Salin kode cadangan lalu simpan di tempat aman (mis. catatan atau email). "
		+ "Tempelkan kode di HP baru untuk memulihkan progres.", "SmallLabel") \
		.add_theme_color_override("font_color", UI.INK)
	_button(backup, "Salin Kode Cadangan", func():
		Game.save_game()
		DisplayServer.clipboard_set(Game.export_code())
		return {"ok": true, "msg": "Kode cadangan disalin ke clipboard."}, true, "", "GreenButton")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	backup.add_child(row)
	var input := LineEdit.new()
	input.placeholder_text = "Tempel kode cadangan di sini"
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.custom_minimum_size.y = 64
	input.add_theme_stylebox_override("normal", UI.box(UI.INPUT_BG, UI.GOLD_DARK, 2, 12))
	input.add_theme_stylebox_override("focus", UI.box(UI.INPUT_BG, UI.GOLD, 3, 12))
	input.add_theme_color_override("font_color", UI.INK)
	input.add_theme_color_override("font_placeholder_color", Color("9a8670"))
	row.add_child(input)
	_button(row, "Pulihkan", func():
		if Game.model.decode_save(input.text).is_empty():
			return {"ok": false, "msg": "Kode cadangan tidak valid."}
		var code: String = input.text
		_confirm("Ganti progres sekarang dengan progres dari kode cadangan? Progres saat ini akan hilang.", "Pulihkan",
			func():
				close.call()
				_show(Game.import_code(code)))
		return null, true, "", "GoldButton").custom_minimum_size.x = 150
	if PlayGames.available():
		var cloud := HBoxContainer.new()
		cloud.add_theme_constant_override("separation", 8)
		backup.add_child(cloud)
		_button(cloud, "Simpan ke Google Play", func():
			Game.save_game()
			PlayGames.save_cloud(Game.export_code())
			return null, true, "", "GreenButton").size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_button(cloud, "Muat dari Google Play", func():
			PlayGames.load_cloud()
			return null).size_flags_horizontal = Control.SIZE_EXPAND_FILL


## Dialog konfirmasi sederhana (ok_text pada tombol setuju).
func _confirm(text: String, ok_text: String, on_ok: Callable) -> void:
	var dlg := ConfirmationDialog.new()
	dlg.add_to_group("modal")
	dlg.dialog_text = text
	dlg.ok_button_text = ok_text
	dlg.cancel_button_text = "Batal"
	dlg.confirmed.connect(on_ok)
	dlg.visibility_changed.connect(func():
		if not dlg.visible:
			dlg.queue_free())
	add_child(dlg)
	dlg.popup_centered()


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
	var track := UI.box(UI.TRACK_BG, UI.GOLD_DARK, 2, 8)
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
		Telemetry.mark("tutup: Selamat Datang Kembali")
		Audio.play("click")
		if is_instance_valid(holder.get("overlay")):
			holder["overlay"].queue_free()
		_maybe_prompt_login.call_deferred()
	Audio.play("promote", 0.0)
	Telemetry.mark("tampil: Selamat Datang Kembali")
	var p := _open_panel("Selamat Datang Kembali", "tab_city", close, 0.08, 0.9)
	holder["overlay"] = p["overlay"]
	p["subtitle"].text = "Tuan pergi selama " + _away_text(int(report["seconds"]))
	for line in report["lines"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_inner_box(p["content"]).add_child(row)
		row.add_child(_tex(Art.icon(line["icon"]), 56))
		_label(_col(row), line["text"], "CardLabel")
	# Tombol di luar area gulir agar selalu terlihat walau ringkasannya panjang.
	_button(p["panel_box"], "Lanjutkan", close, true, "", "GoldButton").custom_minimum_size.y = 80


# --- Hadiah login harian --------------------------------------------------

## Buka kalender login sekali per hari bila hadiahnya belum diklaim.
func _maybe_prompt_login() -> void:
	if Game.load_notice != "":
		_show({"ok": false, "msg": Game.load_notice})
		Game.load_notice = ""
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
	if not Settings.simple_login and Telemetry.crashed_before_drawn("Hadiah Login Harian"):
		Settings.simple_login = true
		Settings.save()
	_fill_login()
	Telemetry.mark("login: kalender terisi")
	_tick()
	Telemetry.mark("login: siap")


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

	if Settings.simple_login:
		Telemetry.mark("login: mode teks")
		for i in Data.LOGIN_REWARDS.size():
			var state := "sudah diambil" if i < claimed else ("hari ini" if can and i == today - 1 else "")
			var line := _label(_login_box, tr("Hari %d" % (i + 1)) + ": " + tr(_reward_text(Data.LOGIN_REWARDS[i]))
				+ ("  (%s)" % tr(state) if state != "" else ""), "CardLabel")
			line.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # sudah diterjemahkan per bagian
			if state == "hari ini":
				line.add_theme_font_override("font", UI.font_bold)
	else:
		Telemetry.mark("login: mode gambar")
		var grid := LoginGrid.new()
		for i in Data.LOGIN_REWARDS.size():
			var def: Dictionary = Data.LOGIN_REWARDS[i]
			var main_key := "gold"
			for key in Data.REWARD_KEYS:
				if def.has(key):
					main_key = key
					break
			var big := i == Data.LOGIN_REWARDS.size() - 1
			grid.days.append({"title": tr("Hari %d" % (i + 1)), "big": big,
				"icon": Art.icon("chest" if big else main_key),
				"lines": Array(_reward_text(def).split(", ")).map(func(t): return tr(t)),
				"claimed": i < claimed, "today": can and i == today - 1})
		_login_box.add_child(grid)

	if can:
		var day7: bool = today == Data.LOGIN_REWARDS.size()
		var b := _button(_login_box, "Klaim Hari %d" % today, func(): return model.claim_login(Game.now()),
			true, "calendar", "GreenButton", false, "reveal_ssr" if day7 else "reveal_sr")
		b.custom_minimum_size.y = 84
	else:
		_login_next_label = _label(_login_box, "", "CardLabel")
		_login_next_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_login_next_label.add_theme_font_override("font", UI.font_bold)


# --- Rekrut (gacha) -------------------------------------------------------

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
	var one := _button(row, "x1  ·  %d" % model.gacha_cost(1), func(): return _recruit(1, false),
		model.gold >= model.gacha_cost(1), "gold", "", false, "gacha_roll")
	one.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ten := _button(row, "x10  ·  %d" % model.gacha_cost(10), func(): return _recruit(10, false),
		model.gold >= model.gacha_cost(10), "gold", "GoldButton", false, "gacha_roll")
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
	if model.gold < model.gacha_cost(10):
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
	# Penasihat Legenda: tawarkan kartu "Bagikan".
	var legend := results.filter(func(x): return x["rarity"] == "ssr" and x.get("new", false))
	if not legend.is_empty():
		var lid: String = legend[0]["id"]
		var sb := _button(v, "Bagikan", func():
			share_card({"kind": "recruit", "headline": "PENASIHAT LEGENDA!", "title": Data.counselor_def(lid)["name"],
				"portrait": lid, "bg": "gacha", "lines": [], "text": "Aku mendapat penasihat Legenda di Tuan Nusantara!"})
			return null, true, "share")
		sb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		sb.custom_minimum_size.x = 260
		sb.modulate.a = 0.0
		done.draw.connect(func(): sb.modulate.a = done.modulate.a)

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
		["penjara", "Penjara (%d)" % model.prison["prisoners"].size()], ["perjamuan", "Perjamuan"],
		["sidang", "Sidang (%d)" % model.court_pending(now) if model.court_pending(now) > 0 else "Sidang"]],
		_palace_tab, func(key): _palace_tab = key, 18)
	match _palace_tab:
		"sidang":
			_build_court(box, now)
		"anak":
			_build_children(box, now)
		"penjara":
			_build_prison(box, now)
		"perjamuan":
			_build_banquet(box, now)
		_:
			_build_consorts(box)


## Sidang Istana: kesetiaan rakyat dan perkara hari ini.
func _build_court(box: VBoxContainer, now: float) -> void:
	var head := _card(box)
	head.add_child(_tex(Art.icon("court"), 92))
	var hcol := _col(head)
	_label(hcol, "Sidang Istana", "CardTitle")
	if not model.court_unlocked():
		_label(hcol, "Terbuka setelah menang Tahap %d." % Data.COURT_UNLOCK_STAGE, "CardLabel")
		return
	model.ensure_court(now)
	var loyalty: int = model.court["loyalty"]
	_label(hcol, "Kesetiaan rakyat %d / 100" % loyalty, "CardLabel")
	_bar(hcol, loyalty, 100, UI.GREEN if loyalty >= 50 else UI.RED)
	_label(hcol, "Semua hasil urusan %+d%%" % roundi(model.loyalty_bonus() * 100), "SmallLabel") \
		.add_theme_color_override("font_color", UI.GREEN.darkened(0.3) if loyalty >= 50 else UI.RED)
	_label(box, "Perkara baru datang setiap hari. Keputusan yang adil menaikkan kesetiaan rakyat; "
		+ "keputusan yang menguntungkan kas kadang membuat rakyat kecewa.", "SmallLabel")
	for id in model.court["cases"]:
		var c: Dictionary = model.court_case_def(id)
		var card := _card(box)
		var left := VBoxContainer.new()
		card.add_child(left)
		left.add_child(_tex(Art.portrait(c["portrait"]), 96))
		var col := _col(card)
		_label(col, c["who"], "CardTitle").add_theme_font_size_override("font_size", 24)
		_label(col, "\"%s\"" % tr(c["text"]), "CardLabel")
		var done: int = model.court["done"].get(id, -1)
		for i in c["options"].size():
			var o: Dictionary = c["options"][i]
			var effects := []
			var ys: Dictionary = model.court_option_yields(o)
			for k in ys:
				if ys[k] != 0:
					effects.append("%+d %s" % [ys[k], Data.REWARD_NAMES[k]])
			if int(o.get("prestige", 0)) != 0:
				effects.append("%+d prestise" % o["prestige"])
			if int(o.get("loyalty", 0)) != 0:
				effects.append("kesetiaan %+d" % o["loyalty"])
			var cid: String = id
			var idx: int = i
			var label: String = o["text"] + ("\n" + ", ".join(effects) if not effects.is_empty() else "")
			var b := _button(col, label, func(): return model.judge_case(cid, idx, Game.now()), done < 0,
				"", "GoldButton" if done < 0 else ("GreenButton" if done == i else ""), false, "promote")
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.custom_minimum_size.y = 84
			b.add_theme_font_size_override("font_size", 20)
		if done >= 0:
			_label(col, "Sudah diputuskan: %s." % tr(c["options"][done]["text"]), "SmallLabel") \
				.add_theme_color_override("font_color", UI.GREEN.darkened(0.3))


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
			var marry := _button(row, "Cari Jodoh", func():
				_realm_ui.show_marriage(i)
				return null, true, "ring", "GoldButton")
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
