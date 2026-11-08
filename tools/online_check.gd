extends Node
## Uji ujung ke ujung mode online melawan server sungguhan (server/server.js).
##   node server/server.js &   # atau PORT=... DB_PATH=...
##   godot --headless --path . res://tools/online_check.tscn -- http://127.0.0.1:8080
## Server harus berisi satu pemain lain bernama "Lawan" (kekuatan > 0) di aliansi
## "garuda" yang sudah mengirim pesan "Halo dari pemain lain" — lihat server/e2e.sh.
## Keluar dengan kode 1 bila ada yang gagal.

const Data := preload("res://scripts/core/game_data.gd")

var _fails := 0


func check(cond: bool, what: String) -> void:
	print(("OK    " if cond else "GAGAL ") + what)
	if not cond:
		_fails += 1


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var m = Game.model
	m.new_game(Game.now())
	m.skip_tutorial()
	m.set_lord_name("Uji Online")
	m.stage = 20
	m.join_alliance("garuda", Game.now())
	Online.set_server(args[0])
	for i in 50:
		await get_tree().create_timer(0.1).timeout
		if Online.is_online():
			break
	check(Online.is_online(), "tersambung ke server")
	check(str(Online.player.get("name", "")) == "Uji Online", "akun dibuat dengan nama Tuan")
	Online.push_profile()
	await get_tree().create_timer(0.5).timeout
	check(str(Online.player.get("alliance", "")) == "garuda", "profil terkirim (aliansi)")
	check(int(Online.player.get("power", 0)) == m.combat_power(), "profil terkirim (kekuatan)")
	Online.poll_chat()
	await get_tree().create_timer(0.5).timeout
	var remote: Array = m.chat_messages(Game.now()).filter(func(x): return x.has("remote"))
	check(remote.size() == 1 and remote[0]["text"] == "Halo dari pemain lain", "chat pemain lain masuk ke game")
	Online.poll_chat()
	await get_tree().create_timer(0.5).timeout
	check(m.chat_messages(Game.now()).filter(func(x): return x.has("remote")).size() == 1, "pesan tidak tergandakan")
	m.chat_send("Salam dari Godot", Game.now(), false)
	Online.send_chat("Salam dari Godot")
	await get_tree().create_timer(0.5).timeout
	# Lambda menyalin variabel lokal, jadi hasil callback ditaruh di dalam Dictionary bersama.
	var got := {}
	Online.fetch_leaderboard("power", func(top, me, players): got["lb"] = {"top": top, "me": me, "players": players})
	await get_tree().create_timer(0.5).timeout
	var lb: Dictionary = got.get("lb", {})
	check(int(lb.get("players", 0)) == 2 and lb["top"].size() == 2, "papan peringkat online berisi 2 pemain")
	Online.fetch_opponents(func(o, _r): got["opps"] = o)
	await get_tree().create_timer(0.5).timeout
	var opps: Array = got.get("opps", [])
	check(opps.size() == 1 and str(opps[0]["name"]) == "Lawan", "lawan arena sungguhan")
	m.stage = Data.ARENA_UNLOCK_STAGE + 1
	Online.arena_fight(str(opps[0]["id"]) if not opps.is_empty() else "x", func(r): got["fight"] = r)
	await get_tree().create_timer(0.5).timeout
	var fight: Dictionary = got.get("fight", {})
	check(fight.has("win") and fight.has("delta"), "pertarungan dihitung server")
	if fight.has("win"):
		check(m.arena_online_result(fight["win"], "Lawan", int(fight["delta"]), Game.now())["ok"], "hadiah arena lokal")
	# Teman, hadiah, kunjungan kota.
	Online.fetch_friends(func(d): got["friends"] = d)
	await get_tree().create_timer(0.5).timeout
	check(str(got.get("friends", {}).get("code", "")).length() == 8, "kode teman sendiri")
	var opp_code := str(opps[0].get("code", "")) if not opps.is_empty() else ""
	Online.add_friend(opp_code, func(ok, msg): got["add"] = [ok, msg])
	await get_tree().create_timer(0.5).timeout
	check(got.get("add", [false])[0] and got["add"][1] == "Lawan", "tambah teman dengan kode")
	var opp_id := str(opps[0]["id"]) if not opps.is_empty() else "x"
	Online.send_gift(opp_id, func(ok, _m): got["gift"] = ok)
	Online.visit_player(opp_id, func(d): got["visit"] = d)
	await get_tree().create_timer(0.5).timeout
	check(got.get("gift", false), "kirim hadiah ke teman")
	check(str(got.get("visit", {}).get("player", {}).get("name", "")) == "Lawan", "kunjungi kota teman")
	# Raja Hari Ini: kekuatan Tuan dibuat lebih besar dari "Lawan" (300).
	m.counselors[m.counselors.keys()[0]]["level"] = 200
	Online.push_profile()
	await get_tree().create_timer(0.4).timeout
	Online.poll_king()
	await get_tree().create_timer(0.5).timeout
	check(bool(Online.king.get("me", false)), "Tuan menjadi Raja Hari Ini")
	Online.set_decree("perak", func(ok, _m): got["decree"] = ok)
	await get_tree().create_timer(0.8).timeout
	check(got.get("decree", false) and m.king_effects.has("yield_silver"), "titah raja berlaku di game")
	check(m.owns_cosmetic("frame_raja_hari_ini"), "bingkai Raja Hari Ini terbuka")
	# Perang Wilayah.
	Online.guildwar_attack(0, func(r): got["gw"] = r)
	await get_tree().create_timer(0.5).timeout
	check(int(got.get("gw", {}).get("points", 0)) > 0, "serang wilayah dapat poin")
	Online.fetch_guildwar(func(d): got["board"] = d)
	await get_tree().create_timer(0.5).timeout
	var board: Dictionary = got.get("board", {})
	check(int(board.get("attacks_left", -1)) == 2 and str(board["territories"][0]["owner"]) == "garuda",
		"papan perang wilayah")
	# Bos Dunia.
	Online.world_boss_attack(func(r): got["boss"] = r)
	await get_tree().create_timer(0.5).timeout
	check(int(got.get("boss", {}).get("damage", 0)) > 0, "serang Bos Dunia")
	Online.fetch_world_boss(func(d): got["wb"] = d)
	await get_tree().create_timer(0.5).timeout
	check(int(got.get("wb", {}).get("me", {}).get("rank", 0)) == 1 and int(got["wb"]["attacks_left"]) == 2,
		"peringkat Bos Dunia")
	# Kode hadiah: bawaan (offline) dan dari server.
	var meteor: int = m.item_count("batu_meteor")
	Online.redeem("ujikode", func(r): got["code"] = r)
	await get_tree().create_timer(0.5).timeout
	check(got.get("code", {}).get("ok", false) and m.item_count("batu_meteor") == meteor + 1, "kode hadiah dari server")
	Online.redeem("UJIKODE", func(r): got["code2"] = r)
	await get_tree().create_timer(0.5).timeout
	check(not got.get("code2", {"ok": true})["ok"], "kode server tidak dipakai dua kali")
	Online.redeem("NUSANTARA", func(r): got["code3"] = r)
	await get_tree().create_timer(0.2).timeout
	check(got.get("code3", {}).get("ok", false), "kode bawaan ditukar tanpa server")
	Online.set_server("http://127.0.0.1:1")
	for i in 50:
		await get_tree().create_timer(0.1).timeout
		if Online.status == Online.Status.ERROR:
			break
	check(Online.status == Online.Status.ERROR and Online.error != "", "server mati: status gagal, game tetap jalan")
	Online.set_server("")
	check(Online.status == Online.Status.OFFLINE, "kembali offline")
	print("online_check: %d gagal" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
