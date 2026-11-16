extends Node
## Video promosi 25 detik untuk Play Store (dipakai tools/make_store_assets.sh):
##   godot --path . --resolution 1080x1920 --fixed-fps 30 --write-movie build/store/promo.avi \
##       res://tools/promo_video.tscn
## Urutan: kartu judul → kota → perang → peta → rekrut Legenda → ajakan unduh.

const UI := preload("res://scripts/ui/ui_theme.gd")

var _main
var _caption: Label
var _layer: CanvasLayer


var _band: ColorRect


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		Settings.language = args[0]
		I18n.apply()
	var m = Game.model
	Game.set_process(false)  # data contoh tidak disimpan
	Game.away = {}
	var now: float = Game.now()
	m.new_game(now - 20 * 86400.0)
	m.tutorial["done"] = true
	m.tutorial["intros_v"] = 999
	for intro in load("res://scripts/core/game_data.gd").FEATURE_INTROS:
		m.mark_intro_seen(intro["id"])
	m.stage = 30
	m.rank = 4
	m.silver = 3500000
	m.grain = 2400000
	m.soldiers = 860000
	m.gold = 2500
	m.lord_name = "Wiratama"
	m.realm["decor"] = ["gapura", "lampion", "patung"]
	m._unlock_content()
	for id in m.counselors:
		m.counselors[id]["level"] = 70
	m.login["last_day"] = m.day_index(now)
	m.sync(now)
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	_band = ColorRect.new()
	_band.color = Color(0.12, 0.04, 0.02, 0.82)
	_layer.add_child(_band)
	_caption = Label.new()
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.add_theme_font_override("font", UI.font_title)
	_caption.add_theme_font_size_override("font_size", 46)
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.add_theme_color_override("font_color", Color("ffe9a8"))
	_caption.add_theme_color_override("font_outline_color", Color("1e120a"))
	_caption.add_theme_constant_override("outline_size", 18)
	_layer.add_child(_caption)
	await _scene_list()
	get_tree().quit()


func _say(text: String, top := true) -> void:
	var vp := get_viewport().get_visible_rect().size
	_caption.text = tr(text)
	# Pita di bawah layar agar isi game tetap terlihat.
	var y := vp.y * 0.8 if top else vp.y * 0.42
	_band.visible = top
	_band.position = Vector2(0, y - 20)
	_band.size = Vector2(vp.x, 200)
	_caption.position = Vector2(40, y)
	_caption.size = Vector2(vp.x - 80, 160)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _clear() -> void:
	for n in get_tree().get_nodes_in_group("modal"):
		n.queue_free()


func _card(title: String, sub: String) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Color(0.2, 0.05, 0.02, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(bg)
	_layer.move_child(bg, 0)
	var icon := TextureRect.new()
	icon.texture = load("res://icon.svg")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var vp := get_viewport().get_visible_rect().size
	icon.position = Vector2(vp.x / 2 - 200, vp.y * 0.18)
	icon.size = Vector2(400, 400)
	bg.add_child(icon)
	_say(title, false)
	var s := Label.new()
	s.text = tr(sub)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.add_theme_font_size_override("font_size", 42)
	s.add_theme_color_override("font_color", Color("f4e4c1"))
	s.position = Vector2(60, vp.y * 0.62)
	s.size = Vector2(vp.x - 120, 200)
	bg.add_child(s)
	return bg


func _scene_list() -> void:
	await _wait(1.0)
	_clear()
	var title := _card("Tuan Nusantara", "Dari kepala desa menjadi Maharaja!")
	await _wait(3.0)
	title.queue_free()
	_main._switch_page("city", false)
	_say("Bangun kerajaanmu di Nusantara")
	var sc: ScrollContainer = _main._pages["city"]["scroll"]
	for i in 90:
		sc.scroll_vertical = i * 6
		await get_tree().process_frame
	await _wait(1.0)
	var m = Game.model
	_say("Perang kolosal dengan pasukan tombak, berkuda, dan panah")
	_main._play_battle(m.battle_plan(0.62, 0.0, 77), {"title": tr("Tahap Besar · %s") % tr("Benteng Begal"),
		"me_name": m.me_name(), "them_name": "Kepala Begal", "me_count": 12000, "them_count": 9000,
		"me_portrait": "lord", "them_portrait": "enemy_warlord", "win": true, "detail": "", "bg": "campaign",
		"me_mix": [0.4, 0.3, 0.3], "them_mix": [0.6, 0.2, 0.2]})
	await _wait(5.0)
	_clear()
	_say("Satukan Nusantara dari Mataram sampai Raja Ampat")
	_main._switch_page("campaign", false)
	_main._show_map()
	await _wait(3.5)
	_clear()
	_say("Rekrut penasihat legendaris Nusantara")
	_main._switch_page("gacha", false)
	_main._show_recruit([{"id": "mambri", "rarity": "ssr", "new": true, "stars": 0, "silver": 0}])
	await _wait(4.0)
	_clear()
	_card("Main gratis sekarang", "Unduh di Google Play")
	await _wait(3.5)
