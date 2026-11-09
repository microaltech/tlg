extends SceneTree
## Ukur waktu muat adegan utama dan waktu bangun tiap halaman (dingin lalu hangat).
##
##   godot --path . --script res://tools/perf_check.gd -- [id|en]
##
## Jalankan dengan layar (xvfb di server). Hasilnya dicatat di docs/performance.md.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	root.get_node("Settings").language = args[0] if args.size() > 0 else "id"
	root.get_node("I18n").apply()
	var m = root.get_node("Game").model
	m.tutorial["done"] = true
	var t0 := Time.get_ticks_msec()
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	print("muat adegan utama: %d ms" % (Time.get_ticks_msec() - t0))
	await create_timer(1.5).timeout
	for o in get_nodes_in_group("modal"):
		o.queue_free()
	await create_timer(0.3).timeout
	var main = current_scene
	for pass_name in ["dingin", "hangat"]:
		for page in ["city", "counselor", "gacha", "campaign", "palace", "alliance", "arena"]:
			if not main._pages.has(page):
				continue
			var t := Time.get_ticks_usec()
			main._build_page_content(page)
			print("%s %s: %.1f ms, %d node" % [pass_name, page, (Time.get_ticks_usec() - t) / 1000.0,
				main._pages[page]["content"].find_children("*", "", true, false).size()])
	print("memori statis: %.1f MB, objek: %d" % [OS.get_static_memory_usage() / 1048576.0,
		Performance.get_monitor(Performance.OBJECT_COUNT)])
	quit()
