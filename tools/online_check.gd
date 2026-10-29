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
