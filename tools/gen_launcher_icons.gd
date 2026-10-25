extends SceneTree
## Membuat ikon peluncur Android dan ikon Play Store dari icon.svg.
##   godot --headless --path . --script res://tools/gen_launcher_icons.gd
## Hasil di assets/launcher/ dan dipakai oleh export_presets.cfg.

const OUT := "res://assets/launcher/"


func _init() -> void:
	var svg := FileAccess.get_file_as_string("res://icon.svg")
	DirAccess.make_dir_recursive_absolute(OUT)
	# Ikon biasa (latar membulat sudah ada di SVG).
	_render(svg, 192, "icon_192.png")
	_render(svg, 512, "play_store_512.png")
	# Ikon adaptif: latar polos + gambar mahkota di zona aman (66% tengah).
	var lines := svg.split("\n")
	var body := []
	var bg_color := "#2b1d14"
	for line in lines.slice(1, lines.size()):
		if line.strip_edges().begins_with("<rect width=\"512\""):
			continue  # latar membulat diganti latar adaptif
		if line.strip_edges() == "</svg>":
			break
		body.append(line)
	var fg := "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"432\" height=\"432\" viewBox=\"0 0 432 432\">" \
		+ "<g transform=\"translate(72 72) scale(%f)\">%s</g></svg>" % [288.0 / 512.0, "\n".join(body)]
	_render(fg, 432, "adaptive_fg_432.png", 432)
	var bg := "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"432\" height=\"432\"><rect width=\"432\" height=\"432\" fill=\"%s\"/></svg>" % bg_color
	_render(bg, 432, "adaptive_bg_432.png", 432)
	print("Ikon ditulis ke ", ProjectSettings.globalize_path(OUT))
	quit()


func _render(svg: String, size: int, file: String, native := 512) -> void:
	var img := Image.new()
	var err := img.load_svg_from_string(svg, float(size) / native)
	if err != OK:
		push_error("Gagal merender %s" % file)
		return
	img.save_png(OUT + file)
