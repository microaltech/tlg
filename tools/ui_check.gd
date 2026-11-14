extends Node
## Uji tampilan otomatis: membuka halaman utama dan pengaturan dalam tiap bahasa dan
## ukuran layar, menyimpan tangkapan layar, lalu memeriksa elemen yang keluar dari
## sisi kiri/kanan layar (teks/tombol terpotong). Dipakai CI (perlu layar; di Linux xvfb).
##
##   xvfb-run godot --path . res://tools/ui_check.tscn -- <folder_hasil>
## Keluar dengan kode 1 bila ada elemen yang keluar layar.

const LANGS := ["id", "en", "ms"]
const SIZES := [Vector2i(720, 1280), Vector2i(1080, 2400), Vector2i(1536, 2048)]
const PAGES := ["city", "counselor", "gacha", "campaign", "palace", "alliance", "arena"]
const MARGIN := 2.0

var _out := "user://ui_check"
var _problems: Array = []


func _ready() -> void:
	# Pengaman: bila galat skrip menghentikan pemeriksaan, keluar dengan gagal (jangan menggantung di CI).
	get_tree().create_timer(600.0).timeout.connect(func():
		printerr("ui_check: waktu habis")
		get_tree().quit(2))
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	Game.away = {}
	Game.model.tutorial["done"] = true
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(30)
	for lang in LANGS:
		Settings.language = lang
		I18n.apply()
		for size in SIZES:
			get_window().size = size
			await _frames(6)
			for page in PAGES:
				_close_modals()
				main._switch_page(page, false)
				main._queue_rebuild()
				await _frames(6)
				_check(main, "%s_%dx%d_%s" % [lang, size.x, size.y, page])
			_close_modals()
			main._show_settings()
			await _frames(6)
			_check(main, "%s_%dx%d_settings" % [lang, size.x, size.y])
	_close_modals()
	print("ui_check: %d masalah" % _problems.size())
	for p in _problems.slice(0, 40):
		print("  ", p)
	get_tree().quit(1 if not _problems.is_empty() else 0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _close_modals() -> void:
	for n in get_tree().get_nodes_in_group("modal"):
		n.queue_free()


func _check(root: Node, name: String) -> void:
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	var vw: float = get_viewport().get_visible_rect().size.x
	var seen := {}
	for c in _controls(root):
		var r: Rect2 = c.get_global_rect()
		if r.size.x <= 1.0:
			continue
		if r.end.x > vw + MARGIN or r.position.x < -MARGIN:
			var what := "%s %s" % [c.get_class(), _text_of(c)]
			if not seen.has(what):
				seen[what] = true
				_problems.append("%s: %s (x %d..%d, lebar layar %d)" % [name, what, r.position.x, r.end.x, vw])


## Kontrol yang terlihat dan ikut tata letak (bukan isi ScrollContainer yang tergulir mendatar).
func _controls(n: Node) -> Array:
	var out := []
	for c in n.get_children():
		if c is CanvasItem and not c.visible:
			continue
		if c is Control and (c is Label or c is Button or c is PanelContainer or c is HBoxContainer):
			out.append(c)
		out.append_array(_controls(c))
	return out


func _text_of(c: Control) -> String:
	if c is Label or c is Button:
		return "\"%s\"" % str(c.text).left(40)
	return str(c.name)
