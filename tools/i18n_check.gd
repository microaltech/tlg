extends Node
## Pemeriksa cakupan terjemahan. Menjalankan game dalam bahasa tujuan dengan save
## yang membuka hampir semua fitur, menelusuri semua halaman, sub-tab, dan panel,
## lalu menjalankan bot beberapa hari untuk memunculkan pesan hasil aksi, log,
## dan chat. Teks yang setelah diterjemahkan masih mengandung kata yang hanya ada
## di teks sumber (bahasa Indonesia) dilaporkan.
##
##   godot --path . res://tools/i18n_check.tscn            (butuh layar/xvfb)
##   godot --path . res://tools/i18n_check.tscn -- en
##
## Hasil: daftar teks bermasalah di output dan di build/i18n/check_<kode>.txt, serta
## semua pasangan sumber -> hasil di build/i18n/check_<kode>_all.tsv untuk dibaca ulang.
## Keluar dengan kode 1 bila ada teks yang belum diterjemahkan.

const Model := preload("res://scripts/core/game_model.gd")
const Data := preload("res://scripts/core/game_data.gd")

var lang := "en"
var main: Control
var seen := {}  ## teks sumber -> hasil terjemahan
var source_only := {}  ## kata yang hanya muncul di teks sumber
var problems := {}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		lang = args[0]
	Settings.language = lang
	I18n.apply()
	_build_vocabulary()
	print_verbose("[cek] save")
	_prepare_save(Game.model)
	print_verbose("[cek] ui")
	Game.away = {}
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(3)
	await _walk_ui()
	print_verbose("[cek] bot")
	_run_bot()
	_report()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


# --- Kosakata ----------------------------------------------------------------

## Kata yang ada di teks sumber kamus tetapi tidak pernah muncul di terjemahannya.
func _build_vocabulary() -> void:
	var src_words := {}
	var dst_words := {}
	var word := RegEx.create_from_string("[A-Za-z]{3,}")
	for line in FileAccess.get_file_as_string("res://translations/%s.tsv" % lang).split("\n"):
		var cols := line.split("\t")
		if cols.size() < 2 or line.begins_with("#"):
			continue
		for m in word.search_all(cols[0].c_unescape()):
			src_words[m.get_string().to_lower()] = true
		for m in word.search_all(cols[1].c_unescape()):
			dst_words[m.get_string().to_lower()] = true
	# Nama diri boleh tetap.
	var consts: Dictionary = load("res://scripts/core/game_data.gd").get_script_constant_map()
	for key in ["COUNSELORS", "BEAUTIES", "ALLIANCES", "NPC_NAMES", "CHILD_NAMES", "NPC_TITLES", "LB_ALLIANCE_WORDS"]:
		for v in consts[key] if not consts[key] is Dictionary else consts[key].values():
			for item in (v if v is Array else [v]):
				var name: String = item["name"] if item is Dictionary else str(item)
				for m in word.search_all(name):
					dst_words[m.get_string().to_lower()] = true
	for w in src_words:
		if not dst_words.has(w):
			source_only[w] = true


func _untranslated(text: String) -> bool:
	for m in RegEx.create_from_string("[A-Za-z]{3,}").search_all(text):
		if source_only.has(m.get_string().to_lower()):
			return true
	return false


func _check(src: String, where: String) -> void:
	src = src.strip_edges()
	if src.is_empty() or seen.has(src):
		return
	var out := tr(src)
	seen[src] = out
	if _untranslated(out):
		problems[src] = "%s → %s   [%s]" % [src.c_escape(), out.c_escape(), where]


func _collect(node: Node, where: String) -> void:
	if node is Label or node is Button or node is RichTextLabel:
		if node.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED and node.is_visible_in_tree():
			_check(node.text, where)
	elif node is LineEdit:
		_check(node.placeholder_text, where)
	for c in node.get_children():
		_collect(c, where)


# --- Save uji ----------------------------------------------------------------

func _prepare_save(m: Model) -> void:
	var now := Game.now()
	m.new_game(now)
	m.skip_tutorial()
	for intro in Data.FEATURE_INTROS:
		m.mark_intro_seen(intro["id"])
	m.story["seen"] = range(Data.STORY_CHAPTERS.size())
	m.soldiers = 1 << 40
	m.silver = 1 << 40
	m.grain = 1 << 40
	m.gold = 100000
	for i in 25:
		m.fight_stage()
	m.rank = 3
	m.prestige = 6000
	m.join_alliance(Data.ALLIANCES[0]["id"], now)
	m.ensure_arena(now)
	for id in ["keris_besi", "kitab_negara", "mahkota_binokasih"]:
		m.add_equipment(id)
	m.equip(m.equipment[0]["uid"], "arya")
	m.add_pass_xp(Data.PASS_XP_PER_TIER * 3)
	m._create_offer("offer_rescue", {"soldiers": 1000, "grain": 5000}, now)
	for id in Data.ITEMS:
		m.add_item(id, 2)
	var t := now
	while m.children.size() < 3:
		t += 60.0
		m.charges["visit"]["value"] = 5
		m.visit_beauty(m.beauties.keys()[0], t)
	m.children[0]["level"] = Data.CHILD_MAX_LEVEL
	m.sync(now)


# --- UI ---------------------------------------------------------------------

func _close_modals() -> void:
	for c in main.get_children():
		if c.is_in_group("modal"):
			c.queue_free()
	await _frames(2)


func _snap(where: String) -> void:
	await _frames(2)
	_collect(main, where)


func _walk_ui() -> void:
	await _close_modals()
	var subtabs := {
		"palace": ["_palace_tab", ["selir", "anak", "penjara", "perjamuan"]],
		"alliance": ["_alliance_tab", ["markas", "bos", "perang", "chat", "toko", "anggota"]],
		"arena": ["_arena_tab", ["lawan", "peringkat", "toko", "catatan"]],
	}
	for p in main.PAGES:
		main._switch_page(p["key"], false)
		if subtabs.has(p["key"]):
			for tab in subtabs[p["key"]][1]:
				main.set(subtabs[p["key"]][0], tab)
				main._rebuild()
				await _snap("%s/%s" % [p["key"], tab])
		else:
			main._rebuild()
			await _snap(p["key"])
	var panels := ["_show_missions", "_show_login", "_show_event", "_show_store", "_show_vip", "_show_bag",
		"_show_story", "_show_settings", "_show_privacy", "_show_help", "_show_equipment", "_show_tower",
		"_show_pass", "_show_achievements", "_show_offers", "_show_promotion"]
	for f in panels:
		print_verbose("[cek] ", f)
		main.call(f)
		await _snap(f)
		await _close_modals()
	for cat in Data.LEADERBOARDS:
		main._lb_cat = cat["id"]
		main._show_leaderboard()
		await _snap("leaderboard/" + cat["id"])
		await _close_modals()
	main._show_story_dialog(0)
	await _snap("story_dialog")
	await _close_modals()
	main._show_intro(Data.FEATURE_INTROS[0])
	await _snap("intro")
	await _close_modals()
	var snap: Dictionary = Game.model.away_snapshot(Game.now() - 3 * 86400.0)
	snap["charges"] = {"silver": 0, "grain": 0, "soldiers": 0, "visit": 0}
	snap["free"] = false
	Game.away = Game.model.away_report(snap, Game.now())
	main._show_away()
	await _snap("away")
	await _close_modals()


# --- Pesan model ---------------------------------------------------------------

func _msg(r, where: String) -> void:
	if r is Dictionary and r.has("msg"):
		_check(r["msg"], where)


func _run_bot() -> void:
	var m := Model.new()
	m.rng.seed = 3
	var t := 20000 * 86400.0
	m.new_game(t)
	_msg(m.promote(), "promote")
	_msg(m.fight_stage(), "fight")
	m.soldiers = 10
	_msg(m.fight_stage(), "fight-kalah")
	_msg(m.recruit(10, t), "recruit-gagal")
	_msg(m.join_alliance(Data.ALLIANCES[0]["id"], t), "alliance-terkunci")
	_msg(m.arena_fight(0, t), "arena-terkunci")
	for day in 12:
		for h in [8.0, 13.0, 20.0]:
			var now: float = t + day * 86400.0 + h * 3600.0
			m.sync(now)
			_msg(m.claim_login(now), "login")
			_msg(m.recruit(1, now, true), "recruit-free")
			for kind in ["silver", "grain", "soldiers"]:
				_msg(m.do_affair(kind, now), "affair")
				_msg(m.do_affair(kind, now), "affair")
			_msg(m.visit_beauty(m.beauties.keys()[0], now), "visit")
			for c in m.children.size():
				_msg(m.train_child(c, now), "train")
			for c in range(m.children.size() - 1, -1, -1):
				if int(m.children[c]["level"]) >= Data.CHILD_MAX_LEVEL:
					_msg(m.take_exam(c, now) if c % 2 == 0 else m.marry_child(c), "child")
			m.soldiers += 200000
			for i in 4:
				_msg(m.fight_stage(), "fight")
			_msg(m.promote(), "promote")
			for id in m.counselors.keys().slice(0, 3):
				_msg(m.upgrade_counselor(id), "upgrade")
			for id in m.inventory.keys():
				var target: String = m.counselors.keys()[0] if Data.ITEMS[id]["target"] == "counselor" \
					else (m.beauties.keys()[0] if Data.ITEMS[id]["target"] == "beauty" else "")
				_msg(m.use_item(id, target, now), "item")
			if not m.prison["prisoners"].is_empty():
				_msg(m.interrogate(0, "interrogate", now), "prison")
				_msg(m.interrogate(0, "intimidate", now), "prison")
				if m.prison["prisoners"].size() > 1:
					_msg(m.release_prisoner(1), "prison")
			_msg(m.hold_banquet("simple", now), "banquet")
			_msg(m.attend_banquet(0, now), "banquet")
			_msg(m.join_alliance(Data.ALLIANCES[day % 3]["id"], now), "alliance")
			if not m.alliance.is_empty():
				for kind in ["silver", "grain", "gold"]:
					_msg(m.donate(kind, now), "donate")
				_msg(m.attack_boss(now), "boss")
				_msg(m.claim_boss(now), "boss")
				_msg(m.shop_buy(Data.ALLIANCE_SHOP[0]["id"], now), "shop")
				_msg(m.chat_send("halo semua, terima kasih!", now), "chat")
				_msg(m.chat_send("", now), "chat")
				if not m.war.is_empty():
					for f in Data.WAR_FORTS.size():
						_msg(m.attack_fort(f, now), "war")
				_msg(m.claim_war_reward(), "war")
			if m.arena_unlocked():
				_msg(m.arena_fight(0, now), "arena")
				_msg(m.buy_arena_ticket(now), "arena")
				_msg(m.refresh_arena(now), "arena")
				_msg(m.claim_arena_season(), "arena")
				_msg(m.arena_shop_buy(Data.ARENA_SHOP[0]["id"], now), "arena")
			for i in m.daily["missions"].size():
				_msg(m.claim_mission(i), "mission")
			for i in Data.DAILY_CHESTS.size():
				_msg(m.claim_chest(i), "chest")
			for i in Data.EVENT_TIERS.size():
				_msg(m.claim_event_tier(i), "event")
			for i in m.story_quests().size():
				_msg(m.claim_quest(i), "story")
			var pending: Dictionary = m.story_choice_pending()
			if not pending.is_empty():
				_msg(m.choose_story(pending["options"][m.story["chapter"] % 2]["id"]), "story")
			_msg(m.claim_chapter(), "story")
			_msg(m.claim_lb_reward(), "lb")
			_msg(m.claim_vip_daily(now), "vip")
	_msg(m.set_lord_name("x"), "name")
	_msg(m.set_lord_name("Wira"), "name")
	for id in Data.IAP_PRODUCTS.map(func(p): return p["id"]):
		_msg(m.grant_purchase(id, "tok-" + id, t), "iap")
	_msg(m.claim_card(t), "iap")
	# Log dan chat yang tersimpan juga tampil ke pemain.
	for line in m.alliance.get("log", []):
		_check(line, "alliance-log")
	for line in m.war.get("log", []):
		_check(line, "war-log")
	for line in m.arena.get("log", []):
		_check(line, "arena-log")
	for msg in m.chat_messages(t + 12 * 86400.0):
		if not msg.get("me", false):
			_check(msg["text"], "chat")
	for n in m.notification_plan(t):
		_check(n["title"], "notif")
		_check(n["text"], "notif")


func _report() -> void:
	var lines := problems.values()
	lines.sort()
	DirAccess.make_dir_recursive_absolute("res://build/i18n")
	var path := "res://build/i18n/check_%s.txt" % lang
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	# Daftar lengkap sumber -> hasil, untuk dibaca ulang kualitas terjemahannya.
	var all := []
	for src in seen:
		all.append("%s\t%s" % [src.c_escape(), seen[src].c_escape()])
	all.sort()
	var full := FileAccess.open("res://build/i18n/check_%s_all.tsv" % lang, FileAccess.WRITE)
	full.store_string("\n".join(all) + "\n")
	print("Diperiksa %d teks unik, %d belum diterjemahkan -> %s" % [seen.size(), problems.size(), path])
	for line in lines:
		print("  ", line)
	get_tree().quit(1 if not problems.is_empty() else 0)
