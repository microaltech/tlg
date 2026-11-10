extends RefCounted
## Kartu "Bagikan": gambar 1080x1080 (potret, judul, angka, kode undangan) yang
## digambar di SubViewport, disimpan ke user://share/kartu.png, lalu dibuka di menu
## bagikan Android lewat plugin TlgNotify. Di PC/editor (tanpa plugin) gambar hanya
## disimpan dan teksnya disalin ke clipboard.
##
## Pemakaian: ShareCard.share(main, {title, headline, portrait, lines, text})

const Art := preload("res://scripts/ui/art.gd")
const UI := preload("res://scripts/ui/ui_theme.gd")
const SIZE := 1080
const DIR := "user://share"
const FILE := "user://share/kartu.png"


## Bangun kartu sebagai Control (dipakai juga tes untuk memastikan kartu bisa dibuat).
static func build(card: Dictionary, invite_code: String) -> Control:
	var root := Control.new()
	root.size = Vector2(SIZE, SIZE)
	var bg := TextureRect.new()
	bg.texture = Art.bg(str(card.get("bg", "palace")))
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.size = root.size
	root.add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0.08, 0.03, 0.01, 0.62)
	shade.size = root.size
	root.add_child(shade)
	var frame := ReferenceRect.new()
	frame.border_color = UI.GOLD
	frame.border_width = 10.0
	frame.editor_only = false
	frame.position = Vector2(28, 28)
	frame.size = root.size - Vector2(56, 56)
	root.add_child(frame)

	var v := VBoxContainer.new()
	v.position = Vector2(70, 80)
	v.size = Vector2(SIZE - 140, SIZE - 160)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 18)
	root.add_child(v)
	v.add_child(_text(TranslationServer.translate(str(card.get("headline", ""))), 54, UI.GOLD, UI.font_bold))
	var portrait := TextureRect.new()
	portrait.texture = Art.portrait(str(card.get("portrait", "lord")))
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(380, 380)
	v.add_child(portrait)
	v.add_child(_text(str(card.get("title", "")), 64, Color("fff3d6"), UI.font_title if UI.font_title else UI.font_bold))
	for line in card.get("lines", []):
		v.add_child(_text(TranslationServer.translate(str(line)), 36, Color("f2e2c0"), UI.font_body))
	var foot := _text("Tuan Nusantara" + ("  ·  " + TranslationServer.translate("Kode undangan: %s") % invite_code if invite_code != "" else ""),
		30, Color("c8b89a"), UI.font_body)
	foot.position = Vector2(0, SIZE - 100)
	foot.size = Vector2(SIZE, 50)
	root.add_child(foot)
	return root


static func _text(text: String, font_size: int, color: Color, font: Font) -> Label:
	var l := Label.new()
	l.text = text
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if font:
		l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color("1e120a"))
	l.add_theme_constant_override("outline_size", 8)
	return l


## Gambar kartu, simpan, lalu bagikan (toast lewat host._show bila tidak ada menu bagikan).
static func share(host: Node, card: Dictionary) -> void:
	# Autoload diambil lewat pohon node agar skrip ini juga bisa dimuat di tes tanpa autoload.
	var root: Node = host.get_tree().root
	var online = root.get_node_or_null("Online")
	var invite := ""
	if online and online.is_online() and online.player.has("code"):
		invite = str(online.player["code"])
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.add_child(build(card, invite))
	host.add_child(vp)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	DirAccess.make_dir_recursive_absolute(DIR)
	img.save_png(FILE)
	var text := TranslationServer.translate(str(card.get("text", "Ayo main Tuan Nusantara!")))
	if invite != "":
		text += " " + TranslationServer.translate("Kode undangan: %s") % invite
	var shared := false
	if Engine.has_singleton("TlgNotify"):
		var plugin = Engine.get_singleton("TlgNotify")
		if plugin.has_method("share_image"):
			shared = plugin.share_image(ProjectSettings.globalize_path(FILE), text)
	if not shared:
		DisplayServer.clipboard_set(text)
		if host.has_method("_show"):
			host._show({"ok": true, "msg": "Gambar disimpan di perangkat dan teks ajakan disalin."})
	if root.get_node_or_null("Telemetry"):
		root.get_node("Telemetry").mark("bagikan: " + str(card.get("kind", "")))
	if root.get_node_or_null("Game"):
		root.get_node("Game").model._track("share")
