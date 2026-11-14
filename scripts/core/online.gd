extends Node
## Autoload "Online": klien server sosial (server/server.js). Mode online aktif bila
## Settings.server_url diisi; tanpa URL game tetap sepenuhnya offline.
##
## - Akun perangkat: ID acak di user://online.cfg ditukar dengan token.
## - Profil (nama, kostum, aliansi, kekuatan, tahap, menara, prestise) dikirim
##   berkala untuk papan peringkat dan arena pemain sungguhan.
## - Chat aliansi: pesan pemain lain diambil berkala dan dimasukkan ke chat game.
##
## Semua permintaan memakai HTTPRequest dan callback; kegagalan jaringan hanya
## mengubah status, tidak pernah menghentikan game.

const Data := preload("res://scripts/core/game_data.gd")

signal status_changed
## Info Raja Hari Ini berubah (lihat `king`).
signal king_changed
## Konfigurasi jarak jauh diterima (pengumuman, versi minimum, bonus).
signal config_changed

enum Status { OFFLINE, CONNECTING, ONLINE, ERROR }

const CFG_PATH := "user://online.cfg"
const PROFILE_SECONDS := 30.0
const CHAT_SECONDS := 6.0
const KING_SECONDS := 300.0
const TIMEOUT := 10.0
const SAVE_SECONDS := 600.0  ## cadangan save ke server tiap 10 menit saat online

var status := Status.OFFLINE
var error := ""
var player := {}
var _token := ""
var _device_id := ""
var _profile_timer := 0.0
var _chat_timer := 0.0
var _chat_busy := false
var _king_timer := 0.0
var _save_timer := 0.0
## {"king": {...}, "decree": String|null, "me": bool, "decrees": [...]} dari /v1/king; kosong bila belum ada.
var king := {}
## ID pemain yang diblokir: pesannya tidak ditampilkan (disimpan di online.cfg).
var blocked: Array = []


func _ready() -> void:
	var cfg := ConfigFile.new()
	cfg.load(CFG_PATH)
	_device_id = str(cfg.get_value("account", "device_id", ""))
	if _device_id.length() < 16:
		_device_id = "%016x%016x" % [randi() << 32 | randi(), randi() << 32 | randi()]
		cfg.set_value("account", "device_id", _device_id)
		cfg.save(CFG_PATH)
	_token = str(cfg.get_value("account", "token", ""))
	blocked = cfg.get_value("account", "blocked", [])
	if Settings.server_url != "":
		connect_server.call_deferred()


## Token sesi (dipakai pemantau server di plugin Android saat game ditutup).
func token() -> String:
	return _token


func is_online() -> bool:
	return status == Status.ONLINE


func base_url() -> String:
	return Settings.server_url.strip_edges().trim_suffix("/")


## Simpan URL lalu sambungkan (URL kosong = putuskan, kembali offline).
func set_server(url: String) -> void:
	Settings.set_value("server_url", url.strip_edges())
	if Settings.server_url == "":
		_set_status(Status.OFFLINE)
		return
	connect_server()


func connect_server() -> void:
	if base_url() == "":
		_set_status(Status.OFFLINE)
		return
	_set_status(Status.CONNECTING)
	_request(HTTPClient.METHOD_POST, "/v1/auth/device", {"device_id": _device_id, "name": Game.model.me_name()},
		func(code: int, data: Dictionary):
			if code != 200 or str(data.get("token", "")) == "":
				if status != Status.ERROR:  # galat jaringan sudah dilaporkan _request
					_fail(data.get("error", "Server tidak menjawab."))
				return
			_token = data["token"]
			player = data.get("player", {})
			var cfg := ConfigFile.new()
			cfg.load(CFG_PATH)
			cfg.set_value("account", "token", _token)
			cfg.save(CFG_PATH)
			_set_status(Status.ONLINE)
			fetch_config()
			upload_save()
			push_profile()
			poll_chat(), false)


func _process(delta: float) -> void:
	if status != Status.ONLINE:
		return
	_profile_timer += delta
	_chat_timer += delta
	_king_timer += delta
	_save_timer += delta
	if _save_timer >= SAVE_SECONDS:
		_save_timer = 0.0
		upload_save()
	if _king_timer >= KING_SECONDS:
		_king_timer = 0.0
		poll_king()
	if _profile_timer >= PROFILE_SECONDS:
		_profile_timer = 0.0
		push_profile()
	if _chat_timer >= CHAT_SECONDS:
		_chat_timer = 0.0
		poll_chat()


## Data profil yang dikirim ke server.
static func profile_payload(m) -> Dictionary:
	return {"name": m.me_name(), "portrait": m.lord_portrait(), "frame": str(m.cosmetics.get("frame", "")),
		"alliance": str(m.alliance.get("id", "")) if not m.alliance.is_empty() else "",
		"power": m.combat_power(), "stage": m.stage, "tower": int(m.tower.get("best", 0)), "prestige": m.prestige,
		"city": {"rank": m.rank, "buildings": m.buildings["levels"].duplicate(), "kin": m.kin_count(),
			"decor": m.realm.get("decor", []).duplicate(),
			"ships": m.ships_owned().size(), "regions": m.territory.get("owned", []).size(),
			"counselors": m.counselors.size(), "badges": m.badge_album().map(func(b): return b["id"])}}


func push_profile() -> void:
	_request(HTTPClient.METHOD_POST, "/v1/profile", profile_payload(Game.model), func(code: int, data: Dictionary):
		if code == 200:
			player = data.get("player", player))


func poll_chat() -> void:
	if _chat_busy or Game.model.alliance.is_empty():
		return
	_chat_busy = true
	_request(HTTPClient.METHOD_GET, "/v1/chat?after=%d" % Game.model.chat_remote_after(), {},
		func(code: int, data: Dictionary):
			_chat_busy = false
			if code == 200:
				var msgs: Array = data.get("messages", [])
				Game.model.chat_add_remote(msgs.filter(func(m): return not blocked.has(str(m.get("player", ""))))))


func send_chat(text: String) -> void:
	_request(HTTPClient.METHOD_POST, "/v1/chat", {"text": text}, func(_code: int, _data: Dictionary): pass)


## Laporkan pesan pemain lain ke pengelola server. callback(ok: bool).
func report_message(message_id: int, callback: Callable) -> void:
	_request(HTTPClient.METHOD_POST, "/v1/chat/report", {"message_id": message_id}, func(code: int, _data: Dictionary):
		callback.call(code == 200))


## Blokir pemain: pesannya disembunyikan di perangkat ini, termasuk yang sudah tampil.
func block_player(player_id: String) -> void:
	if player_id == "" or blocked.has(player_id):
		return
	blocked.append(player_id)
	var cfg := ConfigFile.new()
	cfg.load(CFG_PATH)
	cfg.set_value("account", "blocked", blocked)
	cfg.save(CFG_PATH)
	Game.model.chat_hide_player(player_id)


## callback(top: Array, me: Dictionary, players: int); top kosong bila gagal.
func fetch_leaderboard(cat: String, callback: Callable) -> void:
	_request(HTTPClient.METHOD_GET, "/v1/leaderboard?cat=%s&limit=50" % cat, {}, func(code: int, data: Dictionary):
		if code == 200:
			callback.call(data.get("top", []), data.get("me", {}), int(data.get("players", 0)))
		else:
			callback.call([], {}, 0))


## callback(opponents: Array, rating: int).
func fetch_opponents(callback: Callable) -> void:
	_request(HTTPClient.METHOD_GET, "/v1/arena/opponents", {}, func(code: int, data: Dictionary):
		callback.call(data.get("opponents", []) if code == 200 else [], int(data.get("rating", 0))))


## callback(result: Dictionary) — {win, delta, rating, opponent} atau {error}.
func arena_fight(opponent_id: String, callback: Callable) -> void:
	_request(HTTPClient.METHOD_POST, "/v1/arena/fight", {"opponent_id": opponent_id}, func(code: int, data: Dictionary):
		if code != 200:
			data = {"error": data.get("error", "Server tidak menjawab.")}
		callback.call(data))


## Raja Hari Ini: titahnya berlaku sebagai bonus kecil untuk semua pemain.
func poll_king() -> void:
	_request(HTTPClient.METHOD_GET, "/v1/king", {}, func(code: int, data: Dictionary):
		if code != 200:
			return
		king = data if data.get("king") != null else {}
		apply_king())


func apply_king() -> void:
	var decree := str(king.get("decree", "")) if not king.is_empty() and king.get("decree") != null else ""
	Game.model.king_effects = Data.KING_DECREES[decree]["effects"].duplicate() if Data.KING_DECREES.has(decree) else {}
	if bool(king.get("me", false)):
		Game.model.unlock_cosmetic("frame_raja_hari_ini")
	king_changed.emit()


func set_decree(decree: String, callback: Callable) -> void:
	_request(HTTPClient.METHOD_POST, "/v1/king/decree", {"decree": decree}, func(code: int, data: Dictionary):
		if code == 200:
			poll_king()
		callback.call(code == 200, str(data.get("error", ""))))


## callback(data: Dictionary) — {code, friends, inbox} atau {} bila gagal.
func fetch_friends(callback: Callable) -> void:
	_request(HTTPClient.METHOD_GET, "/v1/friends", {}, func(code: int, data: Dictionary):
		callback.call(data if code == 200 else {}))


## callback(ok: bool, message: String)
func add_friend(code_text: String, callback: Callable) -> void:
	_request(HTTPClient.METHOD_POST, "/v1/friends/add", {"code": code_text.strip_edges()}, func(code: int, data: Dictionary):
		callback.call(code == 200, str(data.get("error", "")) if code != 200 else str(data["friend"].get("name", ""))))


func remove_friend(player_id: String, callback: Callable) -> void:
	_request(HTTPClient.METHOD_POST, "/v1/friends/remove", {"id": player_id}, func(code: int, _data: Dictionary):
		callback.call(code == 200))


func send_gift(player_id: String, callback: Callable) -> void:
	_request(HTTPClient.METHOD_POST, "/v1/gift", {"to": player_id}, func(code: int, data: Dictionary):
		callback.call(code == 200, str(data.get("error", ""))))


## Klaim hadiah di server lalu berikan hadiahnya di game. callback(result: Dictionary).
func claim_gifts(callback: Callable) -> void:
	var left: int = Game.model.friend_gifts_left(Game.now())
	if left <= 0:
		callback.call({"ok": false, "msg": "Batas hadiah teman hari ini sudah tercapai."})
		return
	_request(HTTPClient.METHOD_POST, "/v1/gifts/claim", {}, func(code: int, data: Dictionary):
		if code != 200:
			callback.call({"ok": false, "msg": str(data.get("error", "Server tidak menjawab."))})
		elif int(data.get("claimed", 0)) <= 0:
			callback.call({"ok": false, "msg": "Belum ada hadiah dari teman."})
		else:
			callback.call(Game.model.receive_friend_gifts(int(data["claimed"]), Game.now())))


## callback(data: Dictionary) — {player, city, friend} atau {} bila gagal.
func visit_player(player_id: String, callback: Callable) -> void:
	_request(HTTPClient.METHOD_GET, "/v1/player?id=%s" % player_id.uri_encode(), {}, func(code: int, data: Dictionary):
		callback.call(data if code == 200 else {}))


func fetch_guildwar(callback: Callable) -> void:
	_request(HTTPClient.METHOD_GET, "/v1/guildwar", {}, func(code: int, data: Dictionary):
		callback.call(data if code == 200 else {}))


## callback(data: Dictionary) — {points, territory} atau {error}.
func guildwar_attack(territory: int, callback: Callable) -> void:
	_request(HTTPClient.METHOD_POST, "/v1/guildwar/attack", {"territory": territory}, func(code: int, data: Dictionary):
		if code != 200:
			data = {"error": data.get("error", "Server tidak menjawab.")}
		callback.call(data))


## callback(data: Dictionary) — status Bos Dunia atau {} bila gagal.
func fetch_world_boss(callback: Callable) -> void:
	_request(HTTPClient.METHOD_GET, "/v1/worldboss", {}, func(code: int, data: Dictionary):
		callback.call(data if code == 200 else {}))


## callback(data: Dictionary) — {damage, hp_max, total, defeated, hp_before} atau {error}.
func world_boss_attack(callback: Callable) -> void:
	_request(HTTPClient.METHOD_POST, "/v1/worldboss/attack", {}, func(code: int, data: Dictionary):
		if code != 200:
			data = {"error": data.get("error", "Server tidak menjawab.")}
		callback.call(data))


## Tukar kode: kode bawaan dicoba di perangkat dulu, lalu ke server bila online.
## callback(result: Dictionary) dengan "ok" dan "msg".
func redeem(code: String, callback: Callable) -> void:
	var local: Dictionary = Game.model.redeem_code(code)
	if local["ok"] or not is_online() or local["msg"] == "Kode ini sudah dipakai.":
		callback.call(local)
		return
	_request(HTTPClient.METHOD_POST, "/v1/redeem", {"code": Game.model.normalize_code(code)}, func(c: int, data: Dictionary):
		if c == 200 and data.get("reward") is Dictionary:
			callback.call(Game.model.redeem_server_reward(code, data["reward"]))
		else:
			callback.call({"ok": false, "msg": str(data.get("error", "Kode tidak dikenal atau sudah kedaluwarsa."))}))


func fetch_tourney(callback: Callable) -> void:
	_request(HTTPClient.METHOD_GET, "/v1/tourney", {}, func(code: int, data: Dictionary):
		callback.call(data if code == 200 else {}))


## callback(ok: bool, message: String)
func join_tourney(callback: Callable) -> void:
	push_profile()
	_request(HTTPClient.METHOD_POST, "/v1/tourney/join", {}, func(code: int, data: Dictionary):
		callback.call(code == 200, str(data.get("error", ""))))


func _request(method: int, path: String, body: Dictionary, callback: Callable, auth := true) -> void:
	if base_url() == "":
		callback.call(0, {"error": "Mode offline."})
		return
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if auth and _token != "":
		headers.append("Authorization: Bearer " + _token)
	http.request_completed.connect(func(result: int, code: int, _h, raw: PackedByteArray):
		http.queue_free()
		var data = JSON.parse_string(raw.get_string_from_utf8()) if raw.size() > 0 else {}
		if not (data is Dictionary):
			data = {}
		if result != HTTPRequest.RESULT_SUCCESS:
			_fail("Tidak bisa terhubung ke server.")
			code = 0
		elif code == 401 and auth and status == Status.ONLINE:
			_token = ""  # token kedaluwarsa/server direset: login ulang
			connect_server()
		callback.call(code, data))
	var err := http.request(base_url() + path, headers, method,
		JSON.stringify(body) if method == HTTPClient.METHOD_POST else "")
	if err != OK:
		http.queue_free()
		_fail("Alamat server tidak valid.")
		callback.call(0, {"error": error})


func _fail(message: String) -> void:
	error = message
	_set_status(Status.ERROR)


func _set_status(s: Status) -> void:
	if s != Status.ERROR:
		error = ""
	if s == status and s != Status.ERROR:
		return
	status = s
	status_changed.emit()


## Ambil surat dari server dan masukkan ke kotak surat lokal (id "server:<n>").
## callback(added: int)
func fetch_mail(callback: Callable = func(_n): pass) -> void:
	if not is_online():
		callback.call(0)
		return
	_request(HTTPClient.METHOD_GET, "/v1/mail", {}, func(code: int, data: Dictionary):
		var added := 0
		if code == 200 and data.get("mail") is Array:
			for m in data["mail"]:
				if not (m is Dictionary) or bool(m.get("claimed", false)):
					continue
				if Game.model.add_mail({"id": "server:%d" % int(m.get("id", 0)), "title": str(m.get("title", "")),
						"body": str(m.get("body", "")), "reward": m.get("reward", {})}, Game.now()):
					added += 1
			if added > 0:
				Game.model.changed.emit()
		callback.call(added))


## Ambil hadiah surat server (dicek server agar sekali per akun). callback(result: Dictionary)
func claim_server_mail(id: String, callback: Callable) -> void:
	var n := int(id.trim_prefix("server:"))
	_request(HTTPClient.METHOD_POST, "/v1/mail/claim", {"id": n}, func(code: int, data: Dictionary):
		if code == 200 and data.get("reward") is Dictionary:
			callback.call(Game.model.claim_server_mail(str(n), data["reward"]))
		elif code == 409:
			Game.model.claim_server_mail(str(n), {})
			callback.call({"ok": false, "msg": "Hadiah surat ini sudah diambil."})
		else:
			callback.call({"ok": false, "msg": str(data.get("error", "Tidak bisa terhubung ke server."))}))


## Verifikasi pembelian Google Play di server. callback(http_code: int); 0 = tidak terhubung.
func verify_purchase(product: String, token: String, callback: Callable) -> void:
	_request(HTTPClient.METHOD_POST, "/v1/iap/verify", {"product": product, "token": token}, func(code: int, _d: Dictionary):
		callback.call(code))


# --- Undang teman --------------------------------------------------------------------

func fetch_referral(callback: Callable) -> void:
	_request(HTTPClient.METHOD_GET, "/v1/referral", {}, func(code: int, data: Dictionary):
		callback.call(data if code == 200 else {}))


## callback(ok: bool, message: String)
func enter_referral(code_text: String, callback: Callable) -> void:
	_request(HTTPClient.METHOD_POST, "/v1/referral", {"code": code_text}, func(code: int, data: Dictionary):
		callback.call(code == 200, tr("Kode diterima! Hadiah untuk Tuan dan %s dikirim lewat Kotak Surat saat Tuan mencapai Tahap %d.")
			% [str(data.get("inviter", "")), int(data.get("stage_needed", 10))] if code == 200
			else str(data.get("error", "Tidak bisa terhubung ke server."))))


# --- Musim aliansi -------------------------------------------------------------------

func fetch_season(callback: Callable) -> void:
	_request(HTTPClient.METHOD_GET, "/v1/season", {}, func(code: int, data: Dictionary):
		callback.call(data if code == 200 else {}))


## callback(result: Dictionary) — hadiah diberikan lewat GameModel.claim_season_reward.
func claim_season(callback: Callable) -> void:
	_request(HTTPClient.METHOD_POST, "/v1/season/claim", {}, func(code: int, data: Dictionary):
		if code == 200 and data.get("reward") is Dictionary:
			callback.call(Game.model.claim_season_reward(int(data.get("season", 0)), int(data.get("rank", 0)), data["reward"],
				str(data.get("frame", ""))))
		else:
			callback.call({"ok": false, "msg": str(data.get("error", "Tidak bisa terhubung ke server."))}))


# --- Pasar antar pemain ---------------------------------------------------------------

func fetch_market(callback: Callable) -> void:
	_request(HTTPClient.METHOD_GET, "/v1/market", {}, func(code: int, data: Dictionary):
		callback.call(data if code == 200 else {}))


## Save dikirim dulu (server memeriksa item dari save itu), lalu item dipotong;
## bila server menolak, item dikembalikan. callback(result)
func market_sell(item: String, qty: int, price: int, callback: Callable) -> void:
	upload_save(func(ok: bool):
		if not ok:
			callback.call({"ok": false, "msg": "Tidak bisa terhubung ke server."})
			return
		_market_sell(item, qty, price, callback))


func _market_sell(item: String, qty: int, price: int, callback: Callable) -> void:
	var r: Dictionary = Game.model.market_reserve(item, qty)
	if not r["ok"]:
		callback.call(r)
		return
	_request(HTTPClient.METHOD_POST, "/v1/market/sell", {"item": item, "qty": qty, "price": price},
		func(code: int, data: Dictionary):
			if code == 200:
				Game.save_game()
				callback.call({"ok": true, "msg": tr("Dagangan dipasang. Perak hasil penjualan dikirim lewat Kotak Surat.")})
			else:
				Game.model.market_refund(item, qty)
				callback.call({"ok": false, "msg": str(data.get("error", "Tidak bisa terhubung ke server."))}))


func market_buy(listing: Dictionary, callback: Callable) -> void:
	var price := int(listing.get("price", 0))
	if Game.model.silver < price:
		callback.call({"ok": false, "msg": "Perak tidak cukup."})
		return
	_request(HTTPClient.METHOD_POST, "/v1/market/buy", {"id": int(listing.get("id", 0))}, func(code: int, data: Dictionary):
		if code == 200:
			callback.call(Game.model.market_bought(str(data.get("item", "")), int(data.get("qty", 0)), int(data.get("price", 0))))
			Game.save_game()
		else:
			callback.call({"ok": false, "msg": str(data.get("error", "Tidak bisa terhubung ke server."))}))


func market_cancel(id: int, callback: Callable) -> void:
	_request(HTTPClient.METHOD_POST, "/v1/market/cancel", {"id": id}, func(code: int, data: Dictionary):
		callback.call({"ok": code == 200, "msg": "Dagangan ditarik. Item dikembalikan lewat Kotak Surat." if code == 200
			else str(data.get("error", "Tidak bisa terhubung ke server."))}))



# --- Save di server & pindah perangkat ---------------------------------------------------

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST] and is_online():
		upload_save()


## Cadangkan save ke server. callback(ok: bool)
func upload_save(callback: Callable = func(_ok): pass) -> void:
	if not is_online():
		callback.call(false)
		return
	_request(HTTPClient.METHOD_POST, "/v1/save", {"save": Game.model.to_dict(),
		"version": str(ProjectSettings.get_setting("application/config/version", ""))}, func(code: int, _d: Dictionary):
			callback.call(code == 200))


## Buat kode pindah perangkat (berlaku 24 jam). callback(code: String, error: String)
func create_transfer(callback: Callable) -> void:
	upload_save(func(ok: bool):
		if not ok:
			callback.call("", "Sambungkan ke server dulu.")
			return
		_request(HTTPClient.METHOD_POST, "/v1/account/transfer", {}, func(code: int, data: Dictionary):
			callback.call(str(data.get("code", "")) if code == 200 else "", str(data.get("error", "")))))


## Tukar kode pindah di HP baru: akun lama terikat ke perangkat ini dan save-nya dipulihkan.
## callback(result: Dictionary)
func claim_transfer(code_text: String, callback: Callable) -> void:
	_request(HTTPClient.METHOD_POST, "/v1/account/claim", {"code": code_text, "device_id": _device_id},
		func(code: int, data: Dictionary):
			if code != 200:
				callback.call({"ok": false, "msg": str(data.get("error", "Tidak bisa terhubung ke server."))})
				return
			_token = str(data.get("token", ""))
			var cfg := ConfigFile.new()
			cfg.load(CFG_PATH)
			cfg.set_value("account", "token", _token)
			cfg.save(CFG_PATH)
			var save = data.get("save")
			if save is Dictionary and save.has("version"):
				Game.model.from_dict(save, Game.now())
				Game.save_game()
			connect_server()
			callback.call({"ok": true, "msg": "Akun dan progres berhasil dipindahkan ke perangkat ini."}), false)


# --- Konfigurasi jarak jauh & laporan crash -----------------------------------------------

func fetch_config() -> void:
	_request(HTTPClient.METHOD_GET, "/v1/config", {}, func(code: int, data: Dictionary):
		if code == 200:
			Game.model.apply_remote(data)
			config_changed.emit(), false)


## Kirim laporan crash terakhir (hanya bila pemain mengizinkan statistik anonim).
func send_crash(report: Dictionary) -> void:
	if base_url() == "":
		return
	_request(HTTPClient.METHOD_POST, "/v1/crash", report, func(_c: int, _d: Dictionary): pass, false)


# --- Umpan balik & raid aliansi ---------------------------------------------------------

## Kirim laporan masalah/saran; screenshot = gambar JPEG (PackedByteArray, boleh kosong).
## callback(ok: bool, message: String)
func send_feedback(kind: String, text: String, screenshot: PackedByteArray, callback: Callable) -> void:
	var body := {"kind": kind, "text": text, "version": str(ProjectSettings.get_setting("application/config/version", "")),
		"device": OS.get_model_name(), "lang": TranslationServer.get_locale().substr(0, 2)}
	if not screenshot.is_empty():
		body["screenshot"] = Marshalls.raw_to_base64(screenshot)
	_request(HTTPClient.METHOD_POST, "/v1/feedback", body, func(code: int, data: Dictionary):
		callback.call(code == 200, "Terima kasih! Laporan terkirim; balasan pengembang akan masuk ke Kotak Surat."
			if code == 200 else str(data.get("error", "Tidak bisa terhubung ke server."))))


func fetch_raid(callback: Callable) -> void:
	_request(HTTPClient.METHOD_GET, "/v1/raid", {}, func(code: int, data: Dictionary):
		callback.call(data if code == 200 else {"error": str(data.get("error", ""))}))


## callback(result: Dictionary) dengan "damage" bila berhasil.
func raid_attack(callback: Callable) -> void:
	push_profile()
	_request(HTTPClient.METHOD_POST, "/v1/raid/attack", {}, func(code: int, data: Dictionary):
		if code == 200:
			Game.model._track("raid_attack")
			callback.call({"ok": true, "damage": int(data.get("damage", 0)),
				"msg": tr("Serangan raid: %s kerusakan!") % str(int(data.get("damage", 0)))})
		else:
			callback.call({"ok": false, "msg": str(data.get("error", "Tidak bisa terhubung ke server."))}))


func claim_raid(callback: Callable) -> void:
	_request(HTTPClient.METHOD_POST, "/v1/raid/claim", {}, func(code: int, data: Dictionary):
		if code == 200 and data.get("reward") is Dictionary:
			callback.call(Game.model.claim_raid_reward(int(data.get("raid", 0)), data["reward"]))
		else:
			callback.call({"ok": false, "msg": str(data.get("error", "Tidak bisa terhubung ke server."))}))
