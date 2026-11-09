extends SceneTree
## Buat aset listing Google Play ke build/store/:
##   - feature_graphic.png (1024x500)
##   - screenshot_<n>_<bahasa>.png (ukuran jendela; jalankan dengan 1080x1920)
##
##   xvfb-run -s "-screen 0 1080x1920x24" godot --path . --resolution 1080x1920 \
##       --script res://tools/store_assets.gd -- id
##
## Data tampilan diisi contoh (tahap 30, sumber daya cukup); save pemain tidak disentuh
## karena game tidak disimpan selama skrip ini berjalan.

const Art := preload("res://scripts/ui/art.gd")
const UI := preload("res://scripts/ui/ui_theme.gd")
const OUT := "res://build/store/"

## [judul keterangan, langkah] untuk tiap tangkapan layar.
const SHOTS := [
	["Bangun kerajaanmu di Nusantara", "city"],
	["Perang kolosal dengan pasukan tombak, berkuda, dan panah", "battle"],
	["Rekrut penasihat legendaris Nusantara", "counselor"],
	["Taklukkan wilayah di Peta Nusantara", "map"],
	["Jelajahi candi kuno dan kalahkan Buto penjaganya", "candi"],
	["Berburu, berpacu kuda, dan tonton wayang", "hub"],
]


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var lang: String = args[0] if args.size() > 0 else "id"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	# build/ bukan bagian game: jangan diimpor Godot (gambar toko tidak masuk APK).
	FileAccess.open("res://build/.gdignore", FileAccess.WRITE).store_string("")
	var settings = root.get_node("Settings")
	settings.language = lang
	root.get_node("I18n").apply()
	_prepare_model(root.get_node("Game").model)
	root.get_node("Game").set_process(false)  # jangan autosave data contoh
	if lang == "id":
		await _feature_graphic()
	change_scene_to_file("res://scenes/main.tscn")
	await _wait(1.6)
	for i in SHOTS.size():
		await _shot(i, SHOTS[i], lang)
	print("Aset toko ditulis ke ", ProjectSettings.globalize_path(OUT))
	quit()


func _prepare_model(m) -> void:
	var now: float = root.get_node("Game").now()
	m.new_game(now - 20 * 86400.0)
	m.skip_tutorial()
	m.tutorial["done"] = true
	m.tutorial["intros_v"] = 999
	for intro in load("res://scripts/core/game_data.gd").FEATURE_INTROS:
		m.mark_intro_seen(intro["id"])
	m.stage = 30
	m.rank = 4
	m.prestige = 21000
	m.silver = 3500000
	m.grain = 2400000
	m.soldiers = 860000
	m.gold = 2500
	m._unlock_content()
	for id in m.counselors:
		m.counselors[id]["level"] = 70
	for r in ["pasundan", "majapahit", "sriwijaya", "bali"]:
		if not m.territory["owned"].has(r):
			m.territory["owned"].append(r)
	m.horses["kuda_sandel"] = {"level": 3, "rider": ""}
	m.login["last_day"] = m.day_index(now)
	m.login["streak"] = 3
	m.lord_name = "Wiratama"
	for c in ["gajah", "dewi", "satria", "ratna"]:
		if not m.counselors.has(c):
			m.counselors[c] = {"level": 70, "stars": 2, "bonus": {}}
	m.sync(now)


func _clear_modals() -> void:
	for o in get_nodes_in_group("modal"):
		o.queue_free()
	await _wait(0.3)


func _shot(i: int, shot: Array, lang: String) -> void:
	await _clear_modals()
	var main = current_scene
	var m = root.get_node("Game").model
	var r = main._realm_ui
	match shot[1]:
		"city":
			main._switch_page("city", false)
			main._pages["city"]["scroll"].scroll_vertical = 0
		"battle":
			main._play_battle(m.battle_plan(0.62, 0.0, 77), {"title": tr("Tahap Besar · %s") % tr("Benteng Begal"),
				"me_name": m.me_name(), "them_name": "Kepala Begal", "me_count": 12000, "them_count": 9000,
				"me_portrait": "lord", "them_portrait": "enemy_warlord", "win": true, "detail": "", "bg": "campaign",
				"me_mix": [0.4, 0.3, 0.3], "them_mix": [0.6, 0.2, 0.2]})
			await _wait(1.15)
		"counselor":
			main._switch_page("gacha", false)
		"map":
			main._switch_page("campaign", false)
			main._show_map()
		"candi":
			m.enter_candi(root.get_node("Game").now())
			r.show_candi()
		"hub":
			main._switch_page("city", false)
			r._hub_tab = "petualangan"
			main._rebuild()
			await _wait(0.2)
			for l in main._pages["city"]["content"].find_children("*", "Label", true, false):
				if l.text == tr("Urusan Kerajaan") or l.text == "Urusan Kerajaan":
					var sc: ScrollContainer = main._pages["city"]["scroll"]
					sc.scroll_vertical = int(l.global_position.y - sc.global_position.y + sc.scroll_vertical - 260)
	await _wait(0.5)
	var caption := _caption(tr(shot[0]))
	await _wait(0.2)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "screenshot_%d_%s.png" % [i + 1, lang])
	caption.queue_free()
	for v in current_scene.get_children():
		if v.has_method("close") and v.is_in_group("modal"):
			v.queue_free()


## Pita keterangan di atas tangkapan layar.
func _caption(text: String) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.box(Color("1e120a", 0.94), UI.GOLD, 4, 0))
	panel.position = Vector2(0, 0)
	panel.size = Vector2(720, 150)
	panel.custom_minimum_size = Vector2(720, 150)
	layer.add_child(panel)
	var l := Label.new()
	l.text = text
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.add_theme_font_override("font", UI.font_title)
	l.add_theme_font_size_override("font_size", 38)
	l.add_theme_color_override("font_color", UI.GOLD)
	l.add_theme_color_override("font_outline_color", Color("1a0e06"))
	l.add_theme_constant_override("outline_size", 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(l)
	return layer


## Feature graphic 1024x500: latar kota, potret tokoh, dan slogan.
func _feature_graphic() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1024, 500)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var bg := TextureRect.new()
	bg.texture = Art.bg("city")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.size = Vector2(1024, 500)
	vp.add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0.08, 0.03, 0.01, 0.35)
	shade.size = Vector2(1024, 500)
	vp.add_child(shade)
	var x := 470.0
	for id in ["satria", "lord_raja", "ratna"]:
		var t := TextureRect.new()
		t.texture = Art.portrait(id)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var side := 300.0 if id == "lord_raja" else 230.0
		t.size = Vector2(side, side)
		t.position = Vector2(x, 500 - side - 20)
		vp.add_child(t)
		x += side - 70
	var title := Label.new()
	title.text = "Bangun Kerajaanmu\ndi Nusantara!"
	title.add_theme_font_override("font", UI.font_title)
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", UI.GOLD)
	title.add_theme_color_override("font_outline_color", Color("1a0e06"))
	title.add_theme_constant_override("outline_size", 14)
	title.position = Vector2(40, 120)
	vp.add_child(title)
	var sub := Label.new()
	sub.text = "Strategi kerajaan · perang kolosal · cerita rakyat"
	sub.add_theme_font_override("font", UI.font_bold)
	sub.add_theme_font_size_override("font_size", 28)
	sub.add_theme_color_override("font_color", Color("fff3d6"))
	sub.add_theme_color_override("font_outline_color", Color("1a0e06"))
	sub.add_theme_constant_override("outline_size", 8)
	sub.position = Vector2(44, 330)
	vp.add_child(sub)
	await _wait(0.5)
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(OUT + "feature_graphic.png")
	vp.queue_free()
