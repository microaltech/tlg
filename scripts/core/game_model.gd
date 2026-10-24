extends RefCounted
## Seluruh logika game (ekonomi, penasihat, kampanye, istana, simpan/muat).
## Tidak bergantung pada scene/UI sehingga bisa diuji secara headless.
## Semua fungsi yang bergantung waktu menerima `now` (detik unix).

signal changed
## Dipancarkan saat progres sebuah misi harian mencapai target.
signal mission_completed(text: String)
## Dipancarkan untuk setiap aksi pemain yang dicatat (dipakai tutorial).
signal tracked(event: String)

const Data := preload("res://scripts/core/game_data.gd")

const SAVE_VERSION := 1
const CHARGE_SECONDS := 60.0
## Jenis urusan kota dan charge yang dipakai.
const AFFAIRS := {
	"silver": {"label": "Tarik Pajak", "attr": "int", "per_point": 2, "base": 50},
	"grain": {"label": "Kelola Sawah", "attr": "pol", "per_point": 2, "base": 50},
	"soldiers": {"label": "Rekrut Prajurit", "attr": "cha", "per_point": 3, "base": 80},
}
const CHARGE_KEYS := ["silver", "grain", "soldiers", "visit"]

var silver := 500
var grain := 500
var soldiers := 1000
var prestige := 0
var rank := 0
var stage := 0
var married_count := 0
var gold := 0
## Tarikan sejak Legenda terakhir (untuk jaminan pity).
var pity := 0
## Waktu rekrut gratis terakhir (detik unix).
var free_pull_t := 0.0
## id -> {"level": int, "stars": int, "bonus": {attr: int}}
var counselors := {}
## id -> {"intimacy": int}
var beauties := {}
## [{"name", "gender", "mother", "talent", "level"}]
var children: Array = []
## key -> {"value": int, "t": float}
var charges := {}
## Misi harian: {"day": int, "missions": [{"id", "progress", "claimed"}],
##   "points": int, "chests": [bool, ...]}
var daily := {}
## Hadiah login: streak = hari yang sudah diklaim di siklus ini (0..7),
## last_day = indeks hari klaim terakhir, total = total hari login.
var login := {}
## Event mingguan: {"week": int, "points": int, "claimed": [bool, ...]}
var weekly := {}
## Aliansi (kosong bila belum bergabung). Lihat bagian "Aliansi" di bawah.
var alliance := {}
## Pembelian dalam aplikasi: {"first": [id paket emas yang sudah pernah dibeli],
##   "processed": [token transaksi], "once": [id produk sekali beli], "card_until": int (hari terakhir
##   kartu bulanan aktif), "card_claimed": int (hari klaim terakhir), "spent_idr": int}
var iap := {}
## VIP: {"points": int, "daily_day": int (hari klaim hadiah harian), "packs": [level paket yang dibeli],
##   "gifts": [level yang hadiah naik levelnya sudah diberikan]}
var vip := {}
## Tas: id item -> jumlah.
var inventory := {}
## Hari pertama bermain (umur akun, dipakai untuk mensimulasikan pertumbuhan server).
var start_day := 0
## Leaderboard: {"week": int, "reward": {} hadiah minggu lalu yang belum diklaim}
var leaderboard := {}
## Tutorial: {"step": int, "done": bool, "intros": [id fitur yang sudah diperkenalkan]}
var tutorial := {}
## Arena PvP (kosong sampai terbuka). Lihat bagian "Arena" di bawah.
var arena := {}
## Perang aliansi minggu ini (kosong bila tidak beraliansi). Lihat bagian "Perang aliansi".
var war := {}
## Hasil perang minggu lalu yang belum diklaim (kosong bila tidak ada).
var war_reward := {}
## Waktu keluar aliansi terakhir (untuk jeda sebelum bergabung lagi).
var alliance_left_t := -1.0e12
## Selisih zona waktu (detik) supaya misi direset pada tengah malam lokal.
var tz_bias := 0
var rng := RandomNumberGenerator.new()


func new_game(now: float) -> void:
	_last_now = now
	silver = 500
	grain = 500
	soldiers = 1000
	prestige = 0
	rank = 0
	stage = 0
	married_count = 0
	gold = Data.START_GOLD
	pity = 0
	free_pull_t = now - Data.GACHA_FREE_SECONDS
	counselors = {}
	beauties = {}
	children = []
	charges = {}
	for key in CHARGE_KEYS:
		charges[key] = {"value": max_charges(), "t": now}
	daily = {}
	login = {"streak": 0, "last_day": -1, "total": 0}
	weekly = {}
	alliance = {}
	alliance_left_t = -1.0e12
	arena = {}
	war = {}
	war_reward = {}
	tutorial = {"step": 0, "done": false, "intros": []}
	iap = _empty_iap()
	vip = {"points": 0, "daily_day": -1, "packs": [], "gifts": []}
	start_day = day_index(now)
	leaderboard = {"week": week_index(now), "reward": {}}
	inventory = {"recruit_ticket": 1, "scroll_train": 2}
	_npc_cache = {}
	_unlock_content()
	ensure_daily(now)
	ensure_weekly(now)
	changed.emit()


# --- Jabatan --------------------------------------------------------------

func rank_info() -> Dictionary:
	return Data.RANKS[rank]


func next_rank_info() -> Dictionary:
	if rank + 1 >= Data.RANKS.size():
		return {}
	return Data.RANKS[rank + 1]


func max_charges() -> int:
	return int(rank_info()["max_charges"]) + int(vip_perk("charges"))


func can_promote() -> bool:
	var nxt := next_rank_info()
	return not nxt.is_empty() and prestige >= int(nxt["prestige"])


func promote() -> Dictionary:
	if not can_promote():
		return _fail("Prestise belum cukup untuk naik jabatan.")
	rank += 1
	gold += Data.PROMOTE_GOLD
	changed.emit()
	return _ok("Selamat! Anda kini menjabat sebagai %s. +%d emas." % [rank_info()["name"], Data.PROMOTE_GOLD])


# --- Charge (energi yang terisi seiring waktu) ----------------------------

## Waktu sinkronisasi terakhir, untuk aksi yang tidak menerima `now`.
var _last_now := 0.0


func sync(now: float) -> void:
	_last_now = now
	for key in CHARGE_KEYS:
		_sync_charge(key, now)
	var daily_reset := ensure_daily(now)
	var weekly_reset := ensure_weekly(now)
	ensure_leaderboard(now)
	var alliance_changed := _alliance_rollover(now)
	alliance_changed = ensure_war(now) or alliance_changed
	if ensure_arena(now) or alliance_changed or weekly_reset or daily_reset:
		changed.emit()


func charge_value(key: String, now: float) -> int:
	_sync_charge(key, now)
	return charges[key]["value"]


## Detik sampai charge berikutnya terisi; 0 jika sudah penuh.
func charge_eta(key: String, now: float) -> int:
	_sync_charge(key, now)
	var c: Dictionary = charges[key]
	if c["value"] >= max_charges():
		return 0
	return int(ceil(CHARGE_SECONDS - (now - float(c["t"]))))


func _sync_charge(key: String, now: float) -> void:
	if not charges.has(key):
		charges[key] = {"value": max_charges(), "t": now}
	var c: Dictionary = charges[key]
	var cap := max_charges()
	if c["value"] >= cap:
		c["t"] = now
		return
	var gained := int(floor((now - float(c["t"])) / CHARGE_SECONDS))
	if gained <= 0:
		return
	c["value"] = min(cap, int(c["value"]) + gained)
	c["t"] = now if c["value"] >= cap else float(c["t"]) + gained * CHARGE_SECONDS


func _spend_charge(key: String, now: float) -> bool:
	_sync_charge(key, now)
	var c: Dictionary = charges[key]
	if c["value"] <= 0:
		return false
	if c["value"] >= max_charges():
		c["t"] = now
	c["value"] = int(c["value"]) - 1
	return true


# --- Penasihat ------------------------------------------------------------

func attr(id: String, key: String) -> int:
	var def := Data.counselor_def(id)
	var st: Dictionary = counselors[id]
	var mult := 1.0 + Data.STAR_BONUS * int(st.get("stars", 0))
	return int(int(def[key]) * int(st["level"]) * mult) + int(st["bonus"].get(key, 0))


func total_attr(key: String) -> int:
	var total := 0
	for id in counselors:
		total += attr(id, key)
	if key == "cha":
		total += total_intimacy()
	return total


func power() -> int:
	var total := 0
	for key in Data.ATTRS:
		total += total_attr(key)
	return total


func upgrade_cost(id: String) -> int:
	return int(50 * pow(int(counselors[id]["level"]), 1.6))


func upgrade_counselor(id: String) -> Dictionary:
	if not counselors.has(id):
		return _fail("Penasihat belum direkrut.")
	var st: Dictionary = counselors[id]
	if st["level"] >= rank_info()["level_cap"]:
		return _fail("Level maksimal untuk jabatan ini. Naikkan jabatan!")
	var cost := upgrade_cost(id)
	if silver < cost:
		return _fail("Perak tidak cukup (butuh %d)." % cost)
	silver -= cost
	st["level"] = int(st["level"]) + 1
	_track("upgrade")
	changed.emit()
	return _ok("%s naik ke level %d." % [Data.counselor_def(id)["name"], st["level"]])


# --- Urusan kota ----------------------------------------------------------

func affair_yield(kind: String) -> int:
	var a: Dictionary = AFFAIRS[kind]
	return int((int(a["base"]) + total_attr(a["attr"]) * int(a["per_point"])) * float(rank_info()["mult"])
		* (1.0 + event_bonus("yield_" + kind) + alliance_bonus() + vip_perk("yield")))


func do_affair(kind: String, now: float) -> Dictionary:
	if not AFFAIRS.has(kind):
		return _fail("Urusan tidak dikenal.")
	if not _spend_charge(kind, now):
		return _fail("Belum ada urusan baru. Tunggu sebentar.")
	var amount := affair_yield(kind)
	match kind:
		"silver":
			silver += amount
		"grain":
			grain += amount
		"soldiers":
			soldiers += amount
	_track("affair")
	_track("affair_" + kind)
	if kind == "silver":
		_track("earn_silver", amount)
	changed.emit()
	return _ok("+%d %s" % [amount, resource_name(kind)])


static func resource_name(kind: String) -> String:
	return {"silver": "Perak", "grain": "Pangan", "soldiers": "Prajurit"}.get(kind, kind)


# --- Kampanye -------------------------------------------------------------

func current_stage_info() -> Dictionary:
	return Data.stage_info(stage)


## Perkiraan prajurit yang gugur bila menyerang tahap saat ini.
func expected_losses() -> int:
	var info := current_stage_info()
	var ratio := clampf(float(info["enemy_str"]) / maxi(1, total_attr("str")), 0.25, 4.0)
	return int(ceil(int(info["enemy_soldiers"]) * ratio * (1.0 + event_bonus("losses"))))


func fight_stage() -> Dictionary:
	var info := current_stage_info()
	var losses := expected_losses()
	_track("battle")
	if soldiers < losses:
		var lost := int(soldiers * 0.5)
		soldiers -= lost
		changed.emit()
		return _fail("Kalah di %s! %d prajurit gugur. Butuh sekitar %d prajurit." % [info["name"], lost, losses])
	soldiers -= losses
	silver += int(info["reward_silver"])
	prestige += int(info["reward_prestige"])
	gold += int(info["reward_gold"])
	var stage_item := ""
	if (stage + 1) % 5 == 0:
		stage_item = Data.STAGE_ITEM_POOL[rng.randi_range(0, Data.STAGE_ITEM_POOL.size() - 1)]
		add_item(stage_item)
	stage += 1
	_track("win")
	ensure_arena(_last_now)
	var unlocked := _unlock_content()
	changed.emit()
	var msg := "Menang di %s! -%d prajurit, +%d perak, +%d prestise, +%d emas." % [
		info["name"], losses, info["reward_silver"], info["reward_prestige"], info["reward_gold"]]
	if stage_item != "":
		msg += " Rampasan: %s." % Data.ITEMS[stage_item]["name"]
	if not unlocked.is_empty():
		msg += " Bergabung: " + ", ".join(unlocked)
	return _ok(msg)


func _unlock_content() -> Array:
	var names := []
	for c in Data.COUNSELORS:
		if int(c["unlock_stage"]) >= 0 and stage >= int(c["unlock_stage"]) and not counselors.has(c["id"]):
			counselors[c["id"]] = {"level": 1, "stars": 0, "bonus": {}}
			names.append(c["name"])
	for b in Data.BEAUTIES:
		if stage >= int(b["unlock_stage"]) and not beauties.has(b["id"]):
			beauties[b["id"]] = {"intimacy": 0}
			names.append(b["name"])
	return names


# --- Rekrut (gacha) -------------------------------------------------------

func free_pull_eta(now: float) -> int:
	return maxi(0, int(ceil(free_pull_t + Data.GACHA_FREE_SECONDS - now)))


## Tarikan tersisa sampai Legenda dijamin.
func pity_left() -> int:
	return Data.GACHA_PITY - pity


## count: 1 atau 10. free: rekrut gratis harian (hanya untuk 1 tarikan).
## Hasil: {"ok", "msg", "results": [{"id", "rarity", "new", "stars", "silver"}]}
func recruit(count: int, now: float, free := false, ticket := false) -> Dictionary:
	if count != 1 and count != 10:
		return _fail("Jumlah rekrut tidak valid.")
	var cost := 0
	if ticket:
		if count != 1 or item_count("recruit_ticket") <= 0:
			return _fail("Tidak punya Tiket Rekrut.")
		add_item("recruit_ticket", -1)
	elif free:
		if count != 1 or free_pull_eta(now) > 0:
			return _fail("Rekrut gratis belum tersedia.")
	else:
		cost = Data.GACHA_COST if count == 1 else Data.GACHA_COST_10
		if gold < cost:
			return _fail("Emas tidak cukup (butuh %d)." % cost)
	gold -= cost
	if free:
		free_pull_t = now
	var results := []
	var got_epic := false
	for i in count:
		# 10x menjamin minimal satu Epik: tarikan terakhir dipaksa Epik bila belum ada.
		var rarity := _roll_rarity(count == 10 and i == count - 1 and not got_epic)
		pity = 0 if rarity == "ssr" else pity + 1
		if rarity != "r":
			got_epic = true
		var pool := Data.counselors_of_rarity(rarity)
		var def: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
		results.append(_grant_counselor(def["id"], rarity))
	_track("recruit", count)
	changed.emit()
	var names := []
	for r in results:
		if r["new"]:
			names.append(Data.counselor_def(r["id"])["name"])
	var msg := "Rekrut selesai."
	if not names.is_empty():
		msg += " Bergabung: " + ", ".join(names)
	var result := _ok(msg)
	result["results"] = results
	return result


func _roll_rarity(min_epic: bool) -> String:
	if pity >= Data.GACHA_PITY - 1:
		return "ssr"
	var r := rng.randf()
	var ssr_rate := float(Data.RARITIES["ssr"]["rate"]) + event_bonus("ssr_rate")
	if r < ssr_rate:
		return "ssr"
	if min_epic or r < ssr_rate + float(Data.RARITIES["sr"]["rate"]):
		return "sr"
	return "r"


## Penasihat baru bergabung; duplikat menambah bintang, atau perak bila bintang penuh.
func _grant_counselor(id: String, rarity: String) -> Dictionary:
	var out := {"id": id, "rarity": rarity, "new": false, "stars": 0, "silver": 0}
	if not counselors.has(id):
		counselors[id] = {"level": 1, "stars": 0, "bonus": {}}
		out["new"] = true
		return out
	var st: Dictionary = counselors[id]
	if int(st["stars"]) < Data.MAX_STARS:
		st["stars"] = int(st["stars"]) + 1
		out["stars"] = st["stars"]
	else:
		var bonus: int = Data.RARITIES[rarity]["dup_silver"]
		silver += bonus
		out["silver"] = bonus
	return out


# --- Misi harian ----------------------------------------------------------

func day_index(now: float) -> int:
	return int(floor((now + tz_bias) / 86400.0))


func seconds_until_reset(now: float) -> int:
	return int(ceil((day_index(now) + 1) * 86400.0 - tz_bias - now))


## Buat misi baru bila hari berganti. Mengembalikan true jika direset.
func ensure_daily(now: float) -> bool:
	var day := day_index(now)
	if not daily.is_empty() and int(daily["day"]) == day:
		return false
	# Pilihan misi ditentukan oleh tanggal, jadi stabil walau game dibuka ulang.
	var pick := RandomNumberGenerator.new()
	pick.seed = day * 7919 + 13
	var pool := []
	for m in Data.DAILY_MISSIONS:
		if m.get("requires", "") == "children" and children.is_empty():
			continue
		if m.get("requires", "") == "alliance" and alliance.is_empty():
			continue
		if m.get("requires", "") == "arena" and not arena_unlocked():
			continue
		pool.append(m["id"])
	for i in range(pool.size() - 1, 0, -1):
		var j := pick.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var missions := []
	for id in pool.slice(0, Data.DAILY_COUNT):
		missions.append({"id": id, "progress": 0, "claimed": false})
	var chests := []
	for c in Data.DAILY_CHESTS:
		chests.append(false)
	daily = {"day": day, "missions": missions, "points": 0, "chests": chests}
	return true


func _track(event: String, amount := 1) -> void:
	tracked.emit(event)
	for m in daily.get("missions", []):
		var def := Data.mission_def(m["id"])
		if def["event"] != event:
			continue
		var target := int(def["target"])
		var before := int(m["progress"])
		m["progress"] = mini(target, before + amount)
		if before < target and int(m["progress"]) >= target:
			mission_completed.emit(def["text"])
	if not weekly.is_empty():
		weekly["points"] = int(weekly["points"]) + int(event_def()["points"].get(event, 0)) * amount


func mission_done(index: int) -> bool:
	var m: Dictionary = daily["missions"][index]
	return int(m["progress"]) >= int(Data.mission_def(m["id"])["target"])


## Jumlah misi/peti yang siap diklaim (untuk lencana di UI).
func claimable_count() -> int:
	var n := 0
	for i in daily["missions"].size():
		if mission_done(i) and not daily["missions"][i]["claimed"]:
			n += 1
	for i in Data.DAILY_CHESTS.size():
		if can_claim_chest(i):
			n += 1
	return n


func claim_mission(index: int) -> Dictionary:
	if index < 0 or index >= daily["missions"].size():
		return _fail("Misi tidak ditemukan.")
	var m: Dictionary = daily["missions"][index]
	if m["claimed"]:
		return _fail("Hadiah misi sudah diambil.")
	if not mission_done(index):
		return _fail("Misi belum selesai.")
	m["claimed"] = true
	daily["points"] = int(daily["points"]) + Data.DAILY_POINTS
	weekly["points"] = int(weekly["points"]) + Data.EVENT_MISSION_POINTS
	var text := _give_rewards(Data.mission_def(m["id"]))
	changed.emit()
	return _ok("Hadiah misi: %s, +%d poin aktivitas, +%d poin event." % [
		text, Data.DAILY_POINTS, Data.EVENT_MISSION_POINTS])


func can_claim_chest(index: int) -> bool:
	return not daily["chests"][index] and int(daily["points"]) >= int(Data.DAILY_CHESTS[index]["points"])


func claim_chest(index: int) -> Dictionary:
	if index < 0 or index >= Data.DAILY_CHESTS.size():
		return _fail("Peti tidak ditemukan.")
	if daily["chests"][index]:
		return _fail("Peti sudah dibuka.")
	if not can_claim_chest(index):
		return _fail("Poin aktivitas belum cukup.")
	daily["chests"][index] = true
	var text := _give_rewards(Data.DAILY_CHESTS[index])
	changed.emit()
	return _ok("Peti dibuka: %s." % text)


func _give_rewards(def: Dictionary) -> String:
	var parts := []
	for key in Data.REWARD_KEYS:
		var amount := int(def.get(key, 0))
		if amount <= 0:
			continue
		set(key, int(get(key)) + amount)
		parts.append("+%d %s" % [amount, Data.REWARD_NAMES[key]])
	var items: Dictionary = def.get("items", {})
	for id in items:
		add_item(id, int(items[id]))
		parts.append("+%d %s" % [int(items[id]), Data.ITEMS[id]["name"]])
	return ", ".join(parts)


# --- Event mingguan --------------------------------------------------------

## Minggu dimulai hari Senin (1 Jan 1970 adalah hari Kamis, jadi digeser 3 hari).
func week_index(now: float) -> int:
	return int(floor((day_index(now) + 3) / 7.0))


func seconds_until_week_end(now: float) -> int:
	var end_day := (week_index(now) + 1) * 7 - 3
	return int(ceil(end_day * 86400.0 - tz_bias - now))


## Mulai event baru bila minggu berganti. Mengembalikan true jika direset.
func ensure_weekly(now: float) -> bool:
	var week := week_index(now)
	if not weekly.is_empty() and int(weekly["week"]) == week:
		return false
	var claimed := []
	for t in Data.EVENT_TIERS:
		claimed.append(false)
	weekly = {"week": week, "points": 0, "claimed": claimed}
	return true


func event_def() -> Dictionary:
	return Data.EVENTS[posmod(int(weekly["week"]), Data.EVENTS.size())]


## Besar bonus event untuk efek tertentu (0 bila event minggu ini tidak memilikinya).
func event_bonus(kind: String) -> float:
	if weekly.is_empty():
		return 0.0
	return float(event_def()["bonus"].get(kind, 0.0))


func can_claim_event_tier(index: int) -> bool:
	return not weekly["claimed"][index] and int(weekly["points"]) >= int(Data.EVENT_TIERS[index]["points"])


func event_claimable_count() -> int:
	var n := 0
	for i in Data.EVENT_TIERS.size():
		if can_claim_event_tier(i):
			n += 1
	return n


func claim_event_tier(index: int) -> Dictionary:
	if index < 0 or index >= Data.EVENT_TIERS.size():
		return _fail("Hadiah event tidak ditemukan.")
	if weekly["claimed"][index]:
		return _fail("Hadiah event sudah diambil.")
	if not can_claim_event_tier(index):
		return _fail("Poin event belum cukup.")
	weekly["claimed"][index] = true
	var text := _give_rewards(Data.EVENT_TIERS[index])
	changed.emit()
	return _ok("Hadiah %s: %s." % [event_def()["name"], text])


# --- Aliansi ---------------------------------------------------------------
# Belum ada server, jadi anggota lain adalah NPC yang disimulasikan secara
# deterministik dari id aliansi dan tanggal: kekuatan mereka tumbuh tiap hari,
# mereka menyumbang exp dan menyerang bos setiap hari. Bila nanti memakai
# server, ganti fungsi _npc_* dan _alliance_rollover dengan data dari server.

var _npc_cache := {}


func alliance_unlocked() -> bool:
	return stage >= Data.ALLIANCE_UNLOCK_STAGE


func alliance_join_wait(now: float) -> int:
	return maxi(0, int(ceil(alliance_left_t + Data.ALLIANCE_LEAVE_COOLDOWN - now)))


func join_alliance(id: String, now: float) -> Dictionary:
	var def := Data.alliance_def(id)
	if def.is_empty():
		return _fail("Aliansi tidak ditemukan.")
	if not alliance_unlocked():
		return _fail("Menangkan Tahap %d untuk membuka Aliansi." % Data.ALLIANCE_UNLOCK_STAGE)
	if not alliance.is_empty():
		return _fail("Anda sudah tergabung dalam aliansi.")
	if alliance_join_wait(now) > 0:
		return _fail("Tunggu jeda setelah keluar aliansi sebelum bergabung lagi.")
	var today := day_index(now)
	alliance = {
		"id": id, "join_day": today, "last_day": today, "exp": int(def["exp"]), "jasa": 0, "jasa_total": 0,
		"donations": {"day": today, "count": 0}, "shop": {"day": today, "bought": {}},
		"boss": {}, "log": [], "chat": {"msgs": [], "slot": int(now / Data.CHAT_SLOT_SECONDS), "read_t": now, "sent_t": 0.0},
	}
	_ensure_boss(now)
	ensure_war(now)
	_alliance_log("Anda bergabung dengan %s. Selamat datang!" % def["name"])
	_alliance_log("%s: \"Selamat datang di %s, Tuan!\"" % [_npc_members()[0]["name"], def["name"]])
	_chat_add({"t": now, "system": true, "text": "Anda bergabung dengan %s." % def["name"]})
	_chat_npc_reply("greet", now, 1.5, _npc_members()[0])
	changed.emit()
	return _ok("Anda bergabung dengan %s!" % def["name"])


func leave_alliance(now: float) -> Dictionary:
	if alliance.is_empty():
		return _fail("Anda belum tergabung dalam aliansi.")
	var name: String = alliance_def()["name"]
	alliance = {}
	war = {}
	alliance_left_t = now
	changed.emit()
	return _ok("Anda keluar dari %s." % name)


func alliance_def() -> Dictionary:
	return Data.alliance_def(alliance["id"])


func alliance_level() -> int:
	var lv := 1
	for i in Data.ALLIANCE_LEVELS.size():
		if int(alliance["exp"]) >= int(Data.ALLIANCE_LEVELS[i]):
			lv = i + 1
	return lv


## [exp di level ini, exp yang dibutuhkan ke level berikutnya]; [0, 0] bila level maksimal.
func alliance_level_progress() -> Array:
	var lv := alliance_level()
	if lv >= Data.ALLIANCE_LEVELS.size():
		return [0, 0]
	var base := int(Data.ALLIANCE_LEVELS[lv - 1])
	return [int(alliance["exp"]) - base, int(Data.ALLIANCE_LEVELS[lv]) - base]


func alliance_bonus() -> float:
	if alliance.is_empty():
		return 0.0
	return Data.ALLIANCE_YIELD_PER_LEVEL * alliance_level()


func _seeded(parts: Array) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash(parts)
	return r


## Anggota NPC aliansi sendiri.
func _npc_members() -> Array:
	return _npc_members_of(alliance["id"])


## Anggota NPC: nama, jabatan, dan kekuatan dasar (tetap untuk tiap aliansi).
func _npc_members_of(id: String) -> Array:
	if _npc_cache.has(id):
		return _npc_cache[id]
	var def := Data.alliance_def(id)
	var r := _seeded(["npc", id])
	var out := []
	var used := {}
	for i in int(def["members"]):
		var name := ""
		while name == "" or used.has(name):
			name = "%s %s" % [Data.NPC_TITLES[r.randi_range(0, Data.NPC_TITLES.size() - 1)],
				Data.NPC_NAMES[r.randi_range(0, Data.NPC_NAMES.size() - 1)]]
		used[name] = true
		var role := "Ketua" if i == 0 else ("Wakil" if i < 3 else "Anggota")
		var base := int((120 + r.randi_range(0, 380)) * float(def["power"]) * (2.0 if i == 0 else 1.0))
		out.append({"name": name, "role": role, "base": base})
	_npc_cache[id] = out
	return out


func _npc_power(npc: Dictionary, day: int) -> int:
	var days := clampi(day - int(alliance["join_day"]), 0, 200)
	return int(int(npc["base"]) * (1.0 + 0.015 * days))


## Daftar anggota (termasuk pemain) urut kekuatan, dengan kerusakan ke bos minggu ini.
func alliance_members(now: float) -> Array:
	var today := day_index(now)
	var out := []
	var dmg := _npc_boss_damage_each(now)
	var members := _npc_members()
	for i in members.size():
		out.append({"name": members[i]["name"], "role": members[i]["role"], "power": _npc_power(members[i], today),
			"damage": dmg[i], "me": false})
	out.append({"name": "Anda", "role": "Anggota", "power": power(), "damage": int(alliance["boss"]["damage"]),
		"me": true})
	out.sort_custom(func(a, b): return a["power"] > b["power"])
	return out


## Proses hari yang lewat: sumbangan NPC menambah exp aliansi. True bila ada perubahan.
func _alliance_rollover(now: float) -> bool:
	if alliance.is_empty():
		return false
	var today := day_index(now)
	var last := int(alliance["last_day"])
	var changed_any := _ensure_boss(now)
	if last >= today:
		return changed_any
	var total := 0
	var members := _npc_members()
	for day in range(maxi(last, today - 30), today):
		var r := _seeded(["donate", alliance["id"], day])
		for i in members.size():
			if r.randf() < 0.75:
				total += r.randi_range(20, 120)
	var before := alliance_level()
	alliance["exp"] = int(alliance["exp"]) + total
	alliance["last_day"] = today
	if total > 0:
		_alliance_log("Para anggota menyumbang %d exp sejak kunjungan terakhir Anda." % total)
	if alliance_level() > before:
		_alliance_log("Aliansi naik ke level %d!" % alliance_level())
	return true


func _alliance_log(text: String) -> void:
	var log: Array = alliance["log"]
	log.push_front(text)
	if log.size() > 20:
		log.resize(20)


func donations_per_day() -> int:
	return Data.ALLIANCE_DONATIONS_PER_DAY + int(vip_perk("donations"))


func donations_left(now: float) -> int:
	var d: Dictionary = alliance["donations"]
	if int(d["day"]) != day_index(now):
		return donations_per_day()
	return donations_per_day() - int(d["count"])


func donate(kind: String, now: float) -> Dictionary:
	if alliance.is_empty():
		return _fail("Anda belum tergabung dalam aliansi.")
	var def: Dictionary = {}
	for x in Data.ALLIANCE_DONATIONS:
		if x["id"] == kind:
			def = x
	if def.is_empty():
		return _fail("Jenis sumbangan tidak dikenal.")
	if donations_left(now) <= 0:
		return _fail("Batas sumbangan hari ini sudah habis.")
	for key in def["cost"]:
		if int(get(key)) < int(def["cost"][key]):
			return _fail("%s tidak cukup." % Data.REWARD_NAMES[key].capitalize())
	for key in def["cost"]:
		set(key, int(get(key)) - int(def["cost"][key]))
	var d: Dictionary = alliance["donations"]
	if int(d["day"]) != day_index(now):
		d["day"] = day_index(now)
		d["count"] = 0
	d["count"] = int(d["count"]) + 1
	var before := alliance_level()
	alliance["exp"] = int(alliance["exp"]) + int(def["exp"])
	_add_jasa(int(def["jasa"]))
	_alliance_log("Anda: %s (+%d exp)." % [def["label"], def["exp"]])
	_chat_react("donate", now)
	var msg := "%s: +%d exp aliansi, +%d jasa." % [def["label"], def["exp"], def["jasa"]]
	if alliance_level() > before:
		_alliance_log("Aliansi naik ke level %d!" % alliance_level())
		msg += " Aliansi naik ke level %d!" % alliance_level()
	_track("donate")
	changed.emit()
	return _ok(msg)


func _add_jasa(amount: int) -> void:
	alliance["jasa"] = int(alliance["jasa"]) + amount
	alliance["jasa_total"] = int(alliance["jasa_total"]) + amount


## Sisa pembelian hari ini untuk barang berbatas harian (state: {"day", "bought": {id: n}}).
func _daily_left(state: Dictionary, id: String, limit: int, now: float) -> int:
	if int(state["day"]) != day_index(now):
		return limit
	return limit - int(state["bought"].get(id, 0))


func _daily_record(state: Dictionary, id: String, now: float) -> void:
	if int(state["day"]) != day_index(now):
		state["day"] = day_index(now)
		state["bought"] = {}
	state["bought"][id] = int(state["bought"].get(id, 0)) + 1


func shop_left(id: String, now: float) -> int:
	return _daily_left(alliance["shop"], id, int(Data.shop_def(id)["limit"]), now)


func shop_buy(id: String, now: float) -> Dictionary:
	if alliance.is_empty():
		return _fail("Anda belum tergabung dalam aliansi.")
	var item := Data.shop_def(id)
	if item.is_empty():
		return _fail("Barang tidak ditemukan.")
	if alliance_level() < int(item["level"]):
		return _fail("Butuh aliansi level %d." % item["level"])
	if shop_left(id, now) <= 0:
		return _fail("Batas pembelian hari ini sudah habis.")
	if int(alliance["jasa"]) < int(item["cost"]):
		return _fail("Jasa tidak cukup (butuh %d)." % item["cost"])
	_daily_record(alliance["shop"], id, now)
	alliance["jasa"] = int(alliance["jasa"]) - int(item["cost"])
	var text := _give_rewards(item["reward"])
	changed.emit()
	return _ok("Membeli %s: %s." % [item["name"], text])


## Bos baru tiap minggu. Mengembalikan true bila bos direset.
func _ensure_boss(now: float) -> bool:
	var week := week_index(now)
	var boss: Dictionary = alliance["boss"]
	if not boss.is_empty() and int(boss["week"]) == week:
		return false
	var start_day := week * 7 - 3
	var total_power := 0
	for npc in _npc_members():
		total_power += _npc_power(npc, start_day)
	var hp := int(total_power * Data.BOSS_NPC_DAMAGE_PER_POWER * Data.BOSS_HP_DAYS)
	alliance["boss"] = {"week": week, "hp_max": hp, "damage": 0, "attack_day": -1, "attacks": 0, "claimed": false}
	return true


## Kerusakan tiap NPC ke bos minggu ini (dihitung dari hari-hari yang sudah lewat).
func _npc_boss_damage_each(now: float) -> Array:
	var today := day_index(now)
	var start_day := int(alliance["boss"]["week"]) * 7 - 3
	var key := [alliance["id"], int(alliance["join_day"]), start_day, today]
	if _npc_cache.has(key):
		return _npc_cache[key]
	var members := _npc_members()
	var out := []
	for i in members.size():
		out.append(0)
	for day in range(start_day, mini(today, start_day + 7)):
		var r := _seeded(["boss", alliance["id"], day])
		for i in members.size():
			if r.randf() < 0.85:
				out[i] += int(_npc_power(members[i], day) * Data.BOSS_NPC_DAMAGE_PER_POWER * r.randf_range(0.6, 1.4))
	_npc_cache[key] = out
	return out


func boss_info(now: float) -> Dictionary:
	var boss: Dictionary = alliance["boss"]
	var npc := 0
	for d in _npc_boss_damage_each(now):
		npc += int(d)
	var hp := maxi(0, int(boss["hp_max"]) - npc - int(boss["damage"]))
	var used := int(boss["attacks"]) if int(boss["attack_day"]) == day_index(now) else 0
	return {
		"name": "%s Lv.%d" % [Data.BOSS_NAME, alliance_level()], "hp_max": int(boss["hp_max"]), "hp": hp,
		"my_damage": int(boss["damage"]), "npc_damage": npc, "attacks_left": boss_attacks_per_day() - used,
		"defeated": hp <= 0, "claimed": bool(boss["claimed"]),
		"can_claim": hp <= 0 and not bool(boss["claimed"]) and int(boss["damage"]) > 0,
	}


func boss_attacks_per_day() -> int:
	return Data.BOSS_ATTACKS_PER_DAY + int(vip_perk("boss_attacks"))


func attack_boss(now: float) -> Dictionary:
	if alliance.is_empty():
		return _fail("Anda belum tergabung dalam aliansi.")
	var info := boss_info(now)
	if info["defeated"]:
		return _fail("%s sudah dikalahkan minggu ini." % Data.BOSS_NAME)
	if int(info["attacks_left"]) <= 0:
		return _fail("Serangan hari ini sudah habis. Kembali besok!")
	var boss: Dictionary = alliance["boss"]
	if int(boss["attack_day"]) != day_index(now):
		boss["attack_day"] = day_index(now)
		boss["attacks"] = 0
	boss["attacks"] = int(boss["attacks"]) + 1
	var dmg := mini(int(power() * Data.BOSS_DAMAGE_PER_POWER * rng.randf_range(0.9, 1.1)), int(info["hp"]))
	boss["damage"] = int(boss["damage"]) + dmg
	_add_jasa(Data.BOSS_ATTACK_JASA)
	_track("boss")
	var msg := "Anda memberi %d kerusakan ke %s! +%d jasa." % [dmg, Data.BOSS_NAME, Data.BOSS_ATTACK_JASA]
	_alliance_log("Anda menyerang %s: %d kerusakan." % [Data.BOSS_NAME, dmg])
	_chat_react("boss_hit", now)
	if boss_info(now)["defeated"]:
		msg += " %s tumbang!" % Data.BOSS_NAME
		_alliance_log("%s berhasil dikalahkan!" % Data.BOSS_NAME)
	changed.emit()
	var result := _ok(msg)
	result["damage"] = dmg
	return result


func claim_boss(now: float) -> Dictionary:
	if alliance.is_empty():
		return _fail("Anda belum tergabung dalam aliansi.")
	var info := boss_info(now)
	if not info["defeated"]:
		return _fail("%s belum dikalahkan." % Data.BOSS_NAME)
	if info["claimed"]:
		return _fail("Hadiah bos sudah diambil.")
	if int(info["my_damage"]) <= 0:
		return _fail("Anda harus ikut menyerang untuk mendapat hadiah.")
	alliance["boss"]["claimed"] = true
	gold += int(Data.BOSS_REWARD["gold"])
	_add_jasa(int(Data.BOSS_REWARD["jasa"]))
	changed.emit()
	return _ok("Hadiah kemenangan: +%d emas, +%d jasa." % [Data.BOSS_REWARD["gold"], Data.BOSS_REWARD["jasa"]])


# --- Chat aliansi ------------------------------------------------------------
# Pesan disimpan dengan waktu "t"; balasan NPC dijadwalkan beberapa detik ke depan
# dan baru terlihat saat waktunya tiba (chat_messages). Tanpa timer, mudah diuji.

func _chat() -> Dictionary:
	if not alliance.has("chat"):
		alliance["chat"] = {"msgs": [], "slot": 0, "read_t": 0.0, "sent_t": 0.0}
	return alliance["chat"]


func _chat_add(msg: Dictionary) -> void:
	var msgs: Array = _chat()["msgs"]
	msgs.append(msg)
	msgs.sort_custom(func(a, b): return float(a["t"]) < float(b["t"]))
	if msgs.size() > Data.CHAT_MAX_MESSAGES:
		_chat()["msgs"] = msgs.slice(-Data.CHAT_MAX_MESSAGES)


## Pesan yang sudah terlihat pada waktu `now` (lama ke baru). Obrolan NPC yang
## terlewat saat game ditutup ditambahkan lebih dulu.
func chat_messages(now: float) -> Array:
	if alliance.is_empty():
		return []
	_chat_catch_up(now)
	return _chat()["msgs"].filter(func(m): return float(m["t"]) <= now)


func chat_unread(now: float) -> int:
	if alliance.is_empty():
		return 0
	var read_t := float(_chat()["read_t"])
	return chat_messages(now).filter(func(m): return float(m["t"]) > read_t and not m.get("me", false)).size()


func chat_mark_read(now: float) -> void:
	if not alliance.is_empty():
		_chat()["read_t"] = now


## Saring kata kasar menjadi bintang.
static func chat_filter(text: String) -> String:
	var out := text
	for word in Data.CHAT_BANNED:
		var i := out.to_lower().find(word)
		while i >= 0:
			out = out.substr(0, i) + "*".repeat(word.length()) + out.substr(i + word.length())
			i = out.to_lower().find(word)
	return out


func chat_send(text: String, now: float) -> Dictionary:
	if alliance.is_empty():
		return _fail("Bergabunglah dengan aliansi untuk chat.")
	var clean := text.strip_edges()
	if clean == "":
		return _fail("Pesan kosong.")
	if clean.length() > Data.CHAT_MAX_LENGTH:
		return _fail("Pesan terlalu panjang (maks. %d huruf)." % Data.CHAT_MAX_LENGTH)
	if now - float(_chat()["sent_t"]) < Data.CHAT_COOLDOWN:
		return _fail("Tunggu sebentar sebelum mengirim lagi.")
	_chat()["sent_t"] = now
	clean = chat_filter(clean)
	_chat_add({"t": now, "me": true, "from": "Anda", "text": clean})
	_chat()["read_t"] = now
	# 1-2 anggota membalas sesuai isi pesan.
	var category := "default"
	var lower := clean.to_lower()
	for cat in Data.CHAT_KEYWORDS:
		for kw in Data.CHAT_KEYWORDS[cat]:
			if lower.contains(kw):
				category = cat
				break
		if category != "default":
			break
	var replies := 1 if rng.randf() < 0.6 else 2
	var used := {}
	for i in replies:
		var npc: Dictionary = _npc_members()[rng.randi_range(0, _npc_members().size() - 1)]
		if used.has(npc["name"]):
			continue
		used[npc["name"]] = true
		_chat_npc_reply(category, now, rng.randf_range(1.5, 4.0) + i * 2.0, npc)
	return _ok("")


func _chat_npc_reply(category: String, now: float, delay: float, npc: Dictionary) -> void:
	var lines: Array = Data.CHAT_REPLIES.get(category, Data.CHAT_AMBIENT.get(category, Data.CHAT_REPLIES["default"]))
	_chat_add(_npc_msg(npc, lines[rng.randi_range(0, lines.size() - 1)], now + delay))


## Reaksi anggota atas aksi pemain (tidak selalu, agar tidak berlebihan).
func _chat_react(category: String, now: float, chance := 0.5) -> void:
	if rng.randf() >= chance:
		return
	var npc: Dictionary = _npc_members()[rng.randi_range(0, _npc_members().size() - 1)]
	_chat_npc_reply(category, now, rng.randf_range(2.0, 5.0), npc)


func _npc_msg(npc: Dictionary, template: String, t: float) -> Dictionary:
	return {"t": t, "from": npc["name"], "role": npc["role"], "avatar": _npc_avatar(npc["name"]),
		"text": _chat_fill(template, t)}


func _npc_avatar(name: String) -> String:
	return Data.ARENA_AVATARS[posmod(hash(name), Data.ARENA_AVATARS.size())]


func _chat_fill(template: String, t: float) -> String:
	var vals := {"player": "Tuan", "alliance": alliance_def()["name"], "boss": Data.BOSS_NAME, "hp": 100,
		"enemy": "-", "ours": 0, "theirs": 0, "event": event_def()["name"] if not weekly.is_empty() else "-"}
	if not alliance["boss"].is_empty():
		var b := boss_info(t)
		vals["hp"] = int(100.0 * b["hp"] / maxf(1.0, b["hp_max"]))
	if not war.is_empty():
		vals["enemy"] = war_enemy_def()["name"]
		vals["ours"] = war_score(true)
		vals["theirs"] = war_score(false)
	return template.format(vals)


## Obrolan NPC untuk slot waktu yang terlewat (paling banyak CHAT_CATCHUP_SLOTS slot).
func _chat_catch_up(now: float) -> void:
	var chat := _chat()
	var current := int(now / Data.CHAT_SLOT_SECONDS)
	var start := maxi(int(chat["slot"]) + 1, current - Data.CHAT_CATCHUP_SLOTS + 1)
	if start > current:
		return
	chat["slot"] = current
	var members := _npc_members()
	for slot in range(start, current + 1):
		var r := _seeded(["chat", alliance["id"], slot])
		if r.randf() >= Data.CHAT_SLOT_CHANCE:
			continue
		var t := slot * float(Data.CHAT_SLOT_SECONDS) + r.randf_range(0, Data.CHAT_SLOT_SECONDS)
		var lines: Array = Data.CHAT_AMBIENT[_chat_topic(r, t)]
		var npc: Dictionary = members[r.randi_range(0, members.size() - 1)]
		_chat_add(_npc_msg(npc, lines[r.randi_range(0, lines.size() - 1)], t))


func _chat_topic(r: RandomNumberGenerator, t: float) -> String:
	var topics := ["greet", "donate", "tips", "chatter", "chatter"]
	if not alliance["boss"].is_empty():
		topics.append("boss_dead" if boss_info(t)["defeated"] else "boss")
	if not war.is_empty():
		topics.append("war_ahead" if war_score(true) >= war_score(false) else "war_behind")
	return topics[r.randi_range(0, topics.size() - 1)]


# --- Perang aliansi -----------------------------------------------------------
# Perang mingguan melawan aliansi NPC lain. Kerusakan harian NPC kedua pihak
# diterapkan saat hari berganti (deterministik dari minggu & hari); pemain
# menyerang benteng lawan dengan jatah harian.

func war_enemy_def() -> Dictionary:
	return Data.alliance_def(war["enemy"])


func _war_enemy_for(week: int) -> String:
	var others := []
	for a in Data.ALLIANCES:
		if a["id"] != alliance["id"]:
			others.append(a["id"])
	return others[posmod(week, others.size())]


func _side_power(id: String, day: int) -> int:
	var total := 0
	for npc in _npc_members_of(id):
		total += _npc_power(npc, day)
	return total


## Siapkan perang minggu ini; selesaikan perang minggu lalu. True bila ada perubahan.
func ensure_war(now: float) -> bool:
	if alliance.is_empty():
		var had := not war.is_empty()
		war = {}
		return had
	var week := week_index(now)
	var today := day_index(now)
	var changed_any := false
	if not war.is_empty() and int(war["week"]) != week:
		_war_simulate_until((int(war["week"]) + 1) * 7 - 3)
		_war_finish()
		war = {}
		changed_any = true
	if war.is_empty():
		var start := week * 7 - 3
		var enemy := _war_enemy_for(week)
		var ours := []
		var theirs := []
		var our_unit := _side_power(enemy, start) * Data.WAR_HP_PER_POWER
		var their_unit := _side_power(alliance["id"], start) * Data.WAR_HP_PER_POWER
		for f in Data.WAR_FORTS:
			ours.append(int(our_unit * float(f["hp"])))
			theirs.append(int(their_unit * float(f["hp"])))
		war = {"week": week, "enemy": enemy, "our_max": ours.duplicate(), "our": ours,
			"their_max": theirs.duplicate(), "their": theirs, "last_day": start, "attack_day": -1,
			"attacks": 0, "merit": 0, "log": []}
		_war_log("Perang melawan %s dimulai!" % Data.alliance_def(enemy)["name"])
		changed_any = true
	if int(war["last_day"]) < today:
		_war_simulate_until(today)
		changed_any = true
	return changed_any


## Terapkan serangan harian NPC kedua pihak untuk hari-hari yang sudah lewat (sampai sebelum end_day).
func _war_simulate_until(end_day: int) -> void:
	for day in range(int(war["last_day"]), end_day):
		var r := _seeded(["war", alliance["id"], int(war["week"]), day])
		var ally := int(_side_power(alliance["id"], day) * Data.WAR_NPC_DAMAGE_PER_POWER * r.randf_range(0.7, 1.3))
		var enemy := int(_side_power(war["enemy"], day) * Data.WAR_NPC_DAMAGE_PER_POWER * r.randf_range(0.7, 1.3))
		for i in _war_apply(war["their"], ally):
			_war_log("Pasukan kita merebut %s!" % Data.WAR_FORTS[i]["name"])
		for i in _war_apply(war["our"], enemy):
			_war_log("Musuh merebut %s kita!" % Data.WAR_FORTS[i]["name"])
	war["last_day"] = maxi(int(war["last_day"]), end_day)


## Kerusakan berurutan ke benteng yang masih berdiri. Mengembalikan indeks benteng yang baru direbut.
func _war_apply(forts: Array, damage: int) -> Array:
	var captured := []
	for i in forts.size():
		if damage <= 0:
			break
		if int(forts[i]) <= 0:
			continue
		if i == forts.size() - 1 and _captured_count(forts) < Data.WAR_CORE_UNLOCK:
			break
		var take := mini(int(forts[i]), damage)
		forts[i] = int(forts[i]) - take
		damage -= take
		if int(forts[i]) <= 0:
			captured.append(i)
	return captured


func _captured_count(forts: Array) -> int:
	var n := 0
	for i in forts.size() - 1:
		if int(forts[i]) <= 0:
			n += 1
	return n


## Skor: poin benteng sebanding dengan kerusakannya (benteng direbut = poin penuh).
func war_score(our_side: bool) -> int:
	var forts: Array = war["their"] if our_side else war["our"]
	var maxes: Array = war["their_max"] if our_side else war["our_max"]
	var total := 0.0
	for i in forts.size():
		total += float(Data.WAR_FORTS[i]["points"]) * (1.0 - float(forts[i]) / maxf(1.0, float(maxes[i])))
	return int(total)


func war_fort_locked(index: int) -> bool:
	return index == Data.WAR_FORTS.size() - 1 and _captured_count(war["their"]) < Data.WAR_CORE_UNLOCK


func war_attacks_per_day() -> int:
	return Data.WAR_ATTACKS_PER_DAY + int(vip_perk("war_attacks"))


func war_attacks_left(now: float) -> int:
	if int(war["attack_day"]) != day_index(now):
		return war_attacks_per_day()
	return war_attacks_per_day() - int(war["attacks"])


func attack_fort(index: int, now: float) -> Dictionary:
	if alliance.is_empty():
		return _fail("Bergabunglah dengan aliansi untuk ikut perang.")
	ensure_war(now)
	if index < 0 or index >= Data.WAR_FORTS.size():
		return _fail("Benteng tidak ditemukan.")
	if int(war["their"][index]) <= 0:
		return _fail("%s sudah direbut." % Data.WAR_FORTS[index]["name"])
	if war_fort_locked(index):
		return _fail("Rebut %d benteng lain dulu untuk menyerang Keraton Inti." % Data.WAR_CORE_UNLOCK)
	if war_attacks_left(now) <= 0:
		return _fail("Serangan perang hari ini sudah habis.")
	if int(war["attack_day"]) != day_index(now):
		war["attack_day"] = day_index(now)
		war["attacks"] = 0
	war["attacks"] = int(war["attacks"]) + 1
	var dmg := mini(int(power() * Data.WAR_DAMAGE_PER_POWER * rng.randf_range(0.9, 1.1)), int(war["their"][index]))
	war["their"][index] = int(war["their"][index]) - dmg
	var merit := maxi(1, dmg / 100)
	var name: String = Data.WAR_FORTS[index]["name"]
	var msg := "Anda menyerang %s: %d kerusakan, +%d jasa perang." % [name, dmg, merit]
	var captured := int(war["their"][index]) <= 0
	if captured:
		merit += Data.WAR_CAPTURE_MERIT
		msg += " %s berhasil direbut! +%d jasa perang." % [name, Data.WAR_CAPTURE_MERIT]
		_war_log("Anda merebut %s!" % name)
		_chat_react("capture", now, 1.0)
	else:
		_war_log("Anda menyerang %s (%d kerusakan)." % [name, dmg])
	war["merit"] = int(war["merit"]) + merit
	_track("war")
	changed.emit()
	var result := _ok(msg)
	result.merge({"damage": dmg, "captured": captured})
	return result


func _war_log(text: String) -> void:
	var log: Array = war["log"]
	log.push_front(text)
	if log.size() > 20:
		log.resize(20)


func _war_finish() -> void:
	var ours := war_score(true)
	var theirs := war_score(false)
	var win := ours > theirs
	var reward: Dictionary = (Data.WAR_REWARD_WIN if win else Data.WAR_REWARD_LOSE).duplicate()
	reward["gold"] = int(reward["gold"]) + mini(Data.WAR_MERIT_GOLD_MAX, int(war["merit"]) / Data.WAR_MERIT_PER_GOLD)
	war_reward = {"win": win, "ours": ours, "theirs": theirs, "enemy": war_enemy_def()["name"],
		"merit": int(war["merit"]), "reward": reward}


func claim_war_reward() -> Dictionary:
	if war_reward.is_empty():
		return _fail("Tidak ada hadiah perang.")
	var r: Dictionary = war_reward["reward"]
	gold += int(r["gold"])
	var parts := ["+%d emas" % r["gold"]]
	if not alliance.is_empty():
		_add_jasa(int(r["jasa"]))
		parts.append("+%d jasa" % r["jasa"])
	var msg := "Hadiah perang (%s): %s." % ["menang" if war_reward["win"] else "kalah", ", ".join(parts)]
	war_reward = {}
	changed.emit()
	return _ok(msg)


# --- Arena PvP -------------------------------------------------------------
# Belum ada server, jadi lawan adalah "pemain" NPC yang dibuat di sekitar poin
# dan kekuatan pemain. Untuk PvP online, ganti _gen_opponent, _arena_defense,
# dan arena_leaderboard dengan data dari server.

func arena_unlocked() -> bool:
	return stage >= Data.ARENA_UNLOCK_STAGE


func arena_league() -> Dictionary:
	return Data.league_of(int(arena["rating"]))


## Siapkan/reset data arena: harian (tiket, segarkan, toko, pertahanan) dan
## mingguan (musim). Mengembalikan true bila ada perubahan.
func ensure_arena(now: float) -> bool:
	if not arena_unlocked():
		return false
	var today := day_index(now)
	var week := week_index(now)
	if arena.is_empty():
		arena = {
			"rating": Data.ARENA_START_RATING, "best": Data.ARENA_START_RATING, "coins": 0, "wins": 0,
			"losses": 0, "week": week, "season_fights": 0, "season_reward": {}, "last_day": today,
			"day": today, "tickets_used": 0, "tickets_bought": 0, "refresh_used": 0,
			"shop": {"day": today, "bought": {}}, "opponents": [], "log": [],
		}
		_refresh_opponents()
		_arena_log("Selamat datang di Arena! Kalahkan lawan untuk naik liga.")
		return true
	var changed_any := false
	if int(arena["week"]) != week:
		# Musim berakhir: simpan hadiah liga (bila ikut bertarung) dan reset sebagian poin.
		var league := arena_league()
		if int(arena["season_fights"]) > 0:
			arena["season_reward"] = {"league": league["name"], "reward": league["reward"]}
		var r := int(arena["rating"])
		if r > Data.ARENA_START_RATING:
			arena["rating"] = Data.ARENA_START_RATING + (r - Data.ARENA_START_RATING) / 2
		arena["week"] = week
		arena["season_fights"] = 0
		_arena_log("Musim baru dimulai! Liga musim lalu: %s." % league["name"])
		changed_any = true
	if int(arena["day"]) != today:
		arena["day"] = today
		arena["tickets_used"] = 0
		arena["tickets_bought"] = 0
		arena["refresh_used"] = 0
		changed_any = true
	if int(arena["last_day"]) < today:
		_arena_defense(mini(today - int(arena["last_day"]), 3))
		arena["last_day"] = today
		changed_any = true
	return changed_any


func _arena_log(text: String) -> void:
	var log: Array = arena["log"]
	log.push_front(text)
	if log.size() > 20:
		log.resize(20)


func _npc_name(r: RandomNumberGenerator) -> String:
	return "%s %s" % [Data.NPC_TITLES[r.randi_range(0, Data.NPC_TITLES.size() - 1)],
		Data.NPC_NAMES[r.randi_range(0, Data.NPC_NAMES.size() - 1)]]


func _gen_opponent(rating_offset: int) -> Dictionary:
	var mine := int(arena["rating"])
	var rating := maxi(0, mine + rating_offset)
	var factor := rng.randf_range(0.8, 1.2) * (1.0 + (rating - mine) / 800.0)
	return {
		"name": _npc_name(rng),
		"avatar": Data.ARENA_AVATARS[rng.randi_range(0, Data.ARENA_AVATARS.size() - 1)],
		"rating": rating,
		"power": maxi(10, int(power() * factor)),
	}


func _refresh_opponents() -> void:
	arena["opponents"] = [
		_gen_opponent(rng.randi_range(-150, -30)),
		_gen_opponent(rng.randi_range(-40, 60)),
		_gen_opponent(rng.randi_range(50, 200)),
	]


## Peluang menang berdasarkan perbandingan kekuatan (pangkat 3 agar selisih terasa).
func arena_win_chance(opp_power: int) -> float:
	var a := pow(float(maxi(1, power())), 3.0)
	var b := pow(float(maxi(1, opp_power)), 3.0)
	return a / (a + b)


func _elo_expected(opp_rating: int) -> float:
	return 1.0 / (1.0 + pow(10.0, (opp_rating - int(arena["rating"])) / 400.0))


## Poin yang didapat bila menang / hilang bila kalah melawan lawan ini.
func arena_stakes(opp_rating: int) -> Array:
	var e := _elo_expected(opp_rating)
	return [maxi(5, roundi(Data.ARENA_ELO_K * (1.0 - e))), maxi(5, roundi(Data.ARENA_ELO_K * e))]


func arena_tickets_left(now: float) -> int:
	var daily := Data.ARENA_TICKETS + int(vip_perk("arena_tickets"))
	if int(arena["day"]) != day_index(now):
		return daily
	return daily + int(arena["tickets_bought"]) - int(arena["tickets_used"])


func buy_arena_ticket(now: float) -> Dictionary:
	ensure_arena(now)
	if int(arena["tickets_bought"]) >= Data.ARENA_TICKET_BUY_MAX:
		return _fail("Batas pembelian tiket hari ini sudah habis.")
	if gold < Data.ARENA_TICKET_COST:
		return _fail("Emas tidak cukup (butuh %d)." % Data.ARENA_TICKET_COST)
	gold -= Data.ARENA_TICKET_COST
	arena["tickets_bought"] = int(arena["tickets_bought"]) + 1
	changed.emit()
	return _ok("Tiket arena +1.")


func arena_refresh_left() -> int:
	return Data.ARENA_REFRESH_FREE - int(arena["refresh_used"])


func refresh_arena(now: float) -> Dictionary:
	ensure_arena(now)
	if arena_refresh_left() <= 0:
		return _fail("Batas menyegarkan lawan hari ini sudah habis.")
	arena["refresh_used"] = int(arena["refresh_used"]) + 1
	_refresh_opponents()
	changed.emit()
	return _ok("Daftar lawan diperbarui.")


func arena_fight(index: int, now: float) -> Dictionary:
	if not arena_unlocked():
		return _fail("Menangkan Tahap %d untuk membuka Arena." % Data.ARENA_UNLOCK_STAGE)
	ensure_arena(now)
	if index < 0 or index >= arena["opponents"].size():
		return _fail("Lawan tidak ditemukan.")
	if arena_tickets_left(now) <= 0:
		return _fail("Tiket arena habis. Beli tiket atau kembali besok.")
	var opp: Dictionary = arena["opponents"][index]
	var stakes := arena_stakes(int(opp["rating"]))
	var win := rng.randf() < arena_win_chance(int(opp["power"]))
	arena["tickets_used"] = int(arena["tickets_used"]) + 1
	arena["season_fights"] = int(arena["season_fights"]) + 1
	var delta: int = stakes[0] if win else -int(stakes[1])
	arena["rating"] = maxi(0, int(arena["rating"]) + delta)
	arena["best"] = maxi(int(arena["best"]), int(arena["rating"]))
	var reward: Dictionary = Data.ARENA_WIN if win else Data.ARENA_LOSS
	arena["coins"] = int(arena["coins"]) + int(reward.get("coins", 0))
	silver += int(reward.get("silver", 0))
	if win:
		arena["wins"] = int(arena["wins"]) + 1
		_track("arena_win")
	else:
		arena["losses"] = int(arena["losses"]) + 1
	_track("arena")
	_arena_log("Anda %s melawan %s (%+d poin)." % ["menang" if win else "kalah", opp["name"], delta])
	var rounds := _arena_rounds(win)
	_refresh_opponents()
	changed.emit()
	var msg := "%s melawan %s! %+d poin arena, +%d koin arena" % [
		"Menang" if win else "Kalah", opp["name"], delta, reward.get("coins", 0)]
	if win:
		msg += ", +%d perak" % reward["silver"]
	var result := _ok(msg + ".")
	result.merge({"win": win, "delta": delta, "opponent": opp, "rounds": rounds,
		"coins": int(reward.get("coins", 0))})
	return result


## Persentase HP kedua pihak di awal dan tiap akhir ronde (3 ronde), sesuai hasil.
func _arena_rounds(win: bool) -> Array:
	var final_winner := rng.randi_range(15, 70)
	var me := [100]
	var them := [100]
	for k in range(1, 4):
		var w := 100 - (100 - final_winner) * k / 3.0 + (rng.randf_range(-8, 8) if k < 3 else 0.0)
		var l := 100 - 100 * k / 3.0 + (rng.randf_range(-10, 10) if k < 3 else 0.0)
		var wv := clampi(int(w), final_winner, me[-1] if win else them[-1])
		var lv := clampi(int(l), 0, them[-1] if win else me[-1])
		if win:
			me.append(wv)
			them.append(lv)
		else:
			me.append(lv)
			them.append(wv)
	var out := []
	for i in 4:
		out.append({"me": me[i], "them": them[i]})
	return out


## "Pemain" lain menyerang pemain saat offline: hasilnya mengubah poin sedikit.
func _arena_defense(days: int) -> void:
	for d in days:
		for i in rng.randi_range(0, 3):
			var opp := _gen_opponent(rng.randi_range(-100, 100))
			var held := rng.randf() < arena_win_chance(int(opp["power"]))
			var delta := rng.randi_range(3, 8) * (1 if held else -1)
			arena["rating"] = maxi(0, int(arena["rating"]) + delta)
			_arena_log("%s menyerang Anda dan %s (%+d poin)." % [opp["name"], "kalah" if held else "menang", delta])


func claim_arena_season() -> Dictionary:
	if arena.is_empty() or arena["season_reward"].is_empty():
		return _fail("Tidak ada hadiah musim.")
	var sr: Dictionary = arena["season_reward"]
	var text := _give_rewards(sr["reward"])
	arena["season_reward"] = {}
	changed.emit()
	return _ok("Hadiah musim liga %s: %s." % [sr["league"], text])


func arena_shop_left(id: String, now: float) -> int:
	return _daily_left(arena["shop"], id, int(Data.shop_def(id)["limit"]), now)


func arena_shop_buy(id: String, now: float) -> Dictionary:
	ensure_arena(now)
	var item := Data.shop_def(id)
	if arena.is_empty() or item.is_empty() or not item["id"].begins_with("a_"):
		return _fail("Barang tidak ditemukan.")
	if arena_shop_left(id, now) <= 0:
		return _fail("Batas pembelian hari ini sudah habis.")
	if int(arena["coins"]) < int(item["cost"]):
		return _fail("Koin arena tidak cukup (butuh %d)." % item["cost"])
	_daily_record(arena["shop"], id, now)
	arena["coins"] = int(arena["coins"]) - int(item["cost"])
	var text := _give_rewards(item["reward"])
	changed.emit()
	return _ok("Membeli %s: %s." % [item["name"], text])


## Papan peringkat musim ini: 40 "pemain" + Anda. {"rows": [...10 teratas], "rank": int, "total": int}
func arena_leaderboard() -> Dictionary:
	var r := _seeded(["arena_board", int(arena["week"])])
	var npcs := []
	var rating := 2550
	for i in 40:
		npcs.append({"name": _npc_name(r), "avatar": Data.ARENA_AVATARS[r.randi_range(0, Data.ARENA_AVATARS.size() - 1)],
			"rating": rating, "me": false})
		rating -= r.randi_range(15, 60)
	var mine := {"name": "Anda", "avatar": "lord", "rating": int(arena["rating"]), "me": true}
	var all := npcs + [mine]
	all.sort_custom(func(a, b): return a["rating"] > b["rating"] or (a["rating"] == b["rating"] and a["me"]))
	var rank := all.find(mine) + 1
	return {"rows": all.slice(0, 10), "rank": rank, "total": all.size(), "me": mine}


# --- Pembelian dalam aplikasi ------------------------------------------------
# Hanya mencatat dan memberi hadiah; proses pembayaran ada di autoload Store.

func _empty_iap() -> Dictionary:
	return {"first": [], "processed": [], "once": [], "card_until": -1, "card_claimed": -1, "spent_idr": 0}


func iap_first_bonus(id: String) -> bool:
	var def := Data.iap_def(id)
	return def.get("type", "") == "gold" and not (id in iap["first"])


func iap_owned(id: String) -> bool:
	return id in iap["once"]


## Berikan isi produk untuk satu transaksi. Aman dipanggil berulang: token yang sama
## hanya diproses sekali (hasil {"ok": false, "duplicate": true}).
func grant_purchase(id: String, token: String, now: float) -> Dictionary:
	var def := Data.iap_def(id)
	if def.is_empty():
		return _fail("Produk tidak dikenal: %s" % id)
	if token != "" and token in iap["processed"]:
		var dup := _fail("Transaksi ini sudah diproses.")
		dup["duplicate"] = true
		return dup
	var parts := []
	match def["type"]:
		"gold":
			var amount := int(def["gold"]) + int(def.get("bonus", 0))
			if iap_first_bonus(id):
				amount += int(def["gold"])
				iap["first"].append(id)
				parts.append("bonus pembelian pertama")
			gold += amount
			parts.push_front("+%d emas" % amount)
		"card":
			var today := day_index(now)
			var start := maxi(today, int(iap["card_until"]) + 1)
			iap["card_until"] = start + int(def["days"]) - 1
			gold += int(def["gold"])
			parts.append("+%d emas" % def["gold"])
			parts.append("kartu aktif %d hari" % card_days_left(now))
		"once":
			if iap_owned(id):
				return _fail("%s hanya bisa dibeli sekali." % def["name"])
			iap["once"].append(id)
			parts.append(_give_rewards(def))
			if def.has("counselor"):
				var c := Data.counselor_def(def["counselor"])
				var r := _grant_counselor(c["id"], c["rarity"])
				parts.append(("%s bergabung" if r["new"] else "%s +1 bintang") % c["name"])
	if token != "":
		iap["processed"].append(token)
		if iap["processed"].size() > 100:
			iap["processed"] = iap["processed"].slice(-100)
	iap["spent_idr"] = int(iap["spent_idr"]) + int(def["price_idr"])
	var vip_points := int(def["price_idr"]) / Data.VIP_IDR_PER_POINT
	parts.append("+%d poin VIP" % vip_points)
	var vip_msg := add_vip_points(vip_points)
	if vip_msg != "":
		parts.append(vip_msg)
	changed.emit()
	var result := _ok("Pembelian %s berhasil: %s." % [def["name"], ", ".join(parts)])
	result["product"] = id
	return result


func card_days_left(now: float) -> int:
	return maxi(0, int(iap["card_until"]) - day_index(now) + 1)


func card_can_claim(now: float) -> bool:
	return card_days_left(now) > 0 and int(iap["card_claimed"]) != day_index(now)


func claim_card(now: float) -> Dictionary:
	if card_days_left(now) <= 0:
		return _fail("Kartu Bulanan tidak aktif.")
	if not card_can_claim(now):
		return _fail("Emas Kartu Bulanan hari ini sudah diambil.")
	var daily := int(Data.iap_def("monthly_card")["daily_gold"])
	iap["card_claimed"] = day_index(now)
	gold += daily
	changed.emit()
	return _ok("Kartu Bulanan: +%d emas. Sisa %d hari." % [daily, card_days_left(now) - 1])


# --- VIP --------------------------------------------------------------------

func vip_level() -> int:
	var lv := 0
	for i in Data.VIP_LEVELS.size():
		if int(vip["points"]) >= int(Data.VIP_LEVELS[i]["points"]):
			lv = i
	return lv


func vip_perk(key: String) -> float:
	if vip.is_empty():
		return 0.0
	return float(Data.VIP_LEVELS[vip_level()]["perks"].get(key, 0))


## [poin di level ini, poin yang dibutuhkan ke level berikutnya]; [0, 0] bila maksimal.
func vip_progress() -> Array:
	var lv := vip_level()
	if lv + 1 >= Data.VIP_LEVELS.size():
		return [0, 0]
	var base := int(Data.VIP_LEVELS[lv]["points"])
	return [int(vip["points"]) - base, int(Data.VIP_LEVELS[lv + 1]["points"]) - base]


## Tambah poin VIP dan berikan hadiah naik level. Mengembalikan pesan naik level ("" bila tidak naik).
func add_vip_points(amount: int) -> String:
	var before := vip_level()
	vip["points"] = int(vip["points"]) + amount
	var after := vip_level()
	if after == before:
		return ""
	var gifts := []
	for lv in range(before + 1, after + 1):
		if lv in vip["gifts"]:
			continue
		vip["gifts"].append(lv)
		var text := _give_rewards(Data.VIP_LEVELS[lv]["gift"])
		if text != "":
			gifts.append(text)
	return "naik ke VIP %d (hadiah %s)" % [after, ", ".join(gifts)] if not gifts.is_empty() \
		else "naik ke VIP %d" % after


func vip_daily_can_claim(now: float) -> bool:
	return vip_level() > 0 and int(vip["daily_day"]) != day_index(now)


func claim_vip_daily(now: float) -> Dictionary:
	if vip_level() <= 0:
		return _fail("Capai VIP 1 untuk hadiah harian VIP.")
	if not vip_daily_can_claim(now):
		return _fail("Hadiah harian VIP sudah diambil hari ini.")
	vip["daily_day"] = day_index(now)
	var text := _give_rewards(Data.VIP_LEVELS[vip_level()]["daily"])
	changed.emit()
	return _ok("Hadiah harian VIP %d: %s." % [vip_level(), text])


func buy_vip_pack(level: int) -> Dictionary:
	if level < 1 or level >= Data.VIP_LEVELS.size():
		return _fail("Paket VIP tidak ditemukan.")
	if vip_level() < level:
		return _fail("Capai VIP %d untuk membeli paket ini." % level)
	if level in vip["packs"]:
		return _fail("Paket VIP %d sudah dibeli." % level)
	var pack: Dictionary = Data.VIP_LEVELS[level]["pack"]
	if gold < int(pack["cost"]):
		return _fail("Emas tidak cukup (butuh %d)." % pack["cost"])
	gold -= int(pack["cost"])
	vip["packs"].append(level)
	var parts := []
	var text := _give_rewards(pack)
	if text != "":
		parts.append(text)
	if pack.has("counselor"):
		var c := Data.counselor_def(pack["counselor"])
		var r := _grant_counselor(c["id"], c["rarity"])
		parts.append(("%s bergabung" if r["new"] else "%s +1 bintang") % c["name"])
	changed.emit()
	return _ok("Paket VIP %d: %s." % [level, ", ".join(parts)])


# --- Leaderboard global -----------------------------------------------------
# Belum ada server, jadi 100.000 pemain lain disimulasikan dengan distribusi
# statistik: peringkat pemain = 1 + N x P(nilai pemain lain > nilai pemain).
# Daftar teratas diambil dari kuantil distribusi yang sama, jadi konsisten.
# Untuk leaderboard online, ganti lb_rank / lb_top / lb_alliances dengan data server.

static func _erf(x: float) -> float:
	# Pendekatan Abramowitz & Stegun 7.1.26 (galat < 1.5e-7).
	var sgn := 1.0 if x >= 0.0 else -1.0
	x = absf(x)
	var t := 1.0 / (1.0 + 0.3275911 * x)
	var y := 1.0 - (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t
		+ 0.254829592) * t * exp(-x * x)
	return sgn * y


## Peluang nilai normal baku lebih besar dari z.
static func _normal_tail(z: float) -> float:
	return 0.5 * (1.0 - _erf(z / sqrt(2.0)))


## Kebalikan _normal_tail (bisection; cukup untuk 50 baris).
static func _normal_tail_inv(p: float) -> float:
	var lo := -9.0
	var hi := 9.0
	for i in 60:
		var mid := (lo + hi) / 2.0
		if _normal_tail(mid) > p:
			lo = mid
		else:
			hi = mid
	return (lo + hi) / 2.0


## [median, sigma] distribusi kategori pada hari ini (tumbuh seiring umur akun).
func _lb_dist(def: Dictionary, now: float) -> Array:
	var age := maxi(0, day_index(now) - start_day)
	return [float(def["median"]) * (1.0 + float(def["growth"]) * age), float(def["sigma"])]


func lb_value(id: String) -> int:
	match id:
		"power":
			return power()
		"stage":
			return stage
		"prestige":
			return prestige
		"arena":
			return int(arena["rating"]) if not arena.is_empty() else 0
	return 0


func _lb_z(def: Dictionary, value: float, now: float) -> float:
	var d := _lb_dist(def, now)
	if def["dist"] == "log":
		return (log(maxf(value, 0.0) + 1.0) - log(float(d[0]) + 1.0)) / float(d[1])
	return (value - float(d[0])) / float(d[1])


func _lb_value_at(def: Dictionary, z: float, now: float) -> float:
	var d := _lb_dist(def, now)
	if def["dist"] == "log":
		return (float(d[0]) + 1.0) * exp(float(d[1]) * z) - 1.0
	return float(d[0]) + float(d[1]) * z


## {"rank", "total", "top_percent", "value"} pemain pada kategori ini.
func lb_rank(id: String, now: float) -> Dictionary:
	var def := Data.leaderboard_def(id)
	var value := lb_value(id)
	var total := Data.LB_PLAYERS + 1
	var rank := total
	if value > 0:
		rank = clampi(1 + int(_normal_tail(_lb_z(def, value, now)) * Data.LB_PLAYERS), 1, total)
	return {"rank": rank, "total": total, "top_percent": 100.0 * rank / total, "value": value}


## Daftar teratas (LB_TOP baris); pemain disisipkan sesuai peringkatnya bila masuk.
func lb_top(id: String, now: float) -> Array:
	var def := Data.leaderboard_def(id)
	var today := day_index(now)
	var r := _seeded(["lb", id, today])
	var names := _seeded(["lb_names", id])
	var rows := []
	for i in Data.LB_TOP:
		var z := _normal_tail_inv((i + 0.5) / Data.LB_PLAYERS)
		var v := _lb_value_at(def, z, now) * r.randf_range(0.985, 1.0)
		# Tag merujuk ke aliansi simulasi yang juga tampil di peringkat Aliansi.
		var tag_index := names.randi_range(0, Data.LB_ALLIANCE_COUNT - Data.ALLIANCES.size() - 1)
		rows.append({"name": _npc_name(names), "tag": _lb_tag(tag_index),
			"avatar": Data.ARENA_AVATARS[names.randi_range(0, Data.ARENA_AVATARS.size() - 1)],
			"value": maxi(1, int(v)), "me": false})
	rows.sort_custom(func(a, b): return a["value"] > b["value"])
	var mine := lb_rank(id, now)
	if mine["rank"] <= Data.LB_TOP:
		var tag := _lb_tag(-1) if alliance.is_empty() else "[%s]" % alliance_def()["name"].substr(0, 3).to_upper()
		rows.insert(mine["rank"] - 1, {"name": "Anda", "tag": tag, "avatar": "lord", "value": mine["value"], "me": true})
		rows.resize(Data.LB_TOP)
		# Jaga urutan menurun di sekitar pemain (nilai simulasi disesuaikan, bukan nilai pemain).
		for i in rows.size():
			if rows[i]["me"]:
				continue
			if i < mine["rank"] - 1:
				rows[i]["value"] = maxi(rows[i]["value"], mine["value"] + (mine["rank"] - 1 - i))
			else:
				rows[i]["value"] = mini(rows[i]["value"], mine["value"] - (i - mine["rank"] + 1))
	return rows


func _lb_tag(index: int) -> String:
	if index < 0:
		return ""
	var r := _seeded(["lb_alliance", index])
	var word: String = Data.LB_ALLIANCE_WORDS[r.randi_range(0, Data.LB_ALLIANCE_WORDS.size() - 1)]
	return "[%s]" % word.substr(0, 3).to_upper()


## Peringkat aliansi: 3 aliansi yang bisa dimasuki + aliansi simulasi lain, urut kekuatan total.
func lb_alliances(now: float) -> Array:
	var today := day_index(now)
	var age := maxi(0, today - start_day)
	var rows := []
	for a in Data.ALLIANCES:
		var members := _npc_members_of(a["id"])
		var total := 0
		for npc in members:
			total += int(int(npc["base"]) * (1.0 + 0.015 * mini(age, 200)))
		var me: bool = not alliance.is_empty() and alliance["id"] == a["id"]
		if me:
			total += power()
		rows.append({"name": a["name"], "emblem": a["emblem"], "power": total, "members": members.size() + (1 if me else 0),
			"me": me})
	for i in Data.LB_ALLIANCE_COUNT - Data.ALLIANCES.size():
		var r := _seeded(["lb_alliance", i])
		var word: String = Data.LB_ALLIANCE_WORDS[r.randi_range(0, Data.LB_ALLIANCE_WORDS.size() - 1)]
		var word2: String = Data.LB_ALLIANCE_WORDS[r.randi_range(0, Data.LB_ALLIANCE_WORDS.size() - 1)]
		var base := r.randf_range(2500, 30000) * (1.0 + 0.02 * mini(age, 200))
		rows.append({"name": "%s %s" % [word, word2], "emblem": ["emblem_garuda", "emblem_teratai", "emblem_macan"][i % 3],
			"power": int(base), "members": r.randi_range(10, 30), "me": false})
	rows.sort_custom(func(a, b): return a["power"] > b["power"])
	return rows


func lb_reward_tier(top_percent: float) -> Dictionary:
	for t in Data.LB_REWARDS:
		if top_percent <= float(t["top"]):
			return t
	return Data.LB_REWARDS[-1]


## Hadiah mingguan: dihitung saat minggu berganti dari persentil Kekuatan.
func ensure_leaderboard(now: float) -> bool:
	var week := week_index(now)
	if leaderboard.is_empty():
		leaderboard = {"week": week, "reward": {}}
		return true
	if int(leaderboard["week"]) == week:
		return false
	var rank := lb_rank("power", now)
	var tier := lb_reward_tier(rank["top_percent"])
	leaderboard = {"week": week, "reward": {"tier": tier["name"], "rank": rank["rank"], "gold": int(tier["gold"])}}
	return true


func claim_lb_reward() -> Dictionary:
	var r: Dictionary = leaderboard.get("reward", {})
	if r.is_empty():
		return _fail("Tidak ada hadiah peringkat.")
	gold += int(r["gold"])
	leaderboard["reward"] = {}
	changed.emit()
	return _ok("Hadiah peringkat mingguan (%s, #%d): +%d emas." % [r["tier"], r["rank"], r["gold"]])


# --- Tas & item ---------------------------------------------------------------

func item_count(id: String) -> int:
	return int(inventory.get(id, 0))


func add_item(id: String, amount := 1) -> void:
	if not Data.ITEMS.has(id):
		return
	var n := item_count(id) + amount
	if n <= 0:
		inventory.erase(id)
	else:
		inventory[id] = n


## Pakai item. target = id penasihat/selir untuk item bertarget.
func use_item(id: String, target: String, now: float) -> Dictionary:
	if not Data.ITEMS.has(id) or item_count(id) <= 0:
		return _fail("Item tidak ada di tas.")
	var def: Dictionary = Data.ITEMS[id]
	var msg := ""
	match id:
		"scroll_train":
			if not counselors.has(target):
				return _fail("Pilih penasihat.")
			var st: Dictionary = counselors[target]
			if int(st["level"]) >= int(rank_info()["level_cap"]):
				return _fail("Level maksimal untuk jabatan ini.")
			st["level"] = int(st["level"]) + 1
			_track("upgrade")
			msg = "%s naik ke level %d." % [Data.counselor_def(target)["name"], st["level"]]
		"star_stone":
			if not counselors.has(target):
				return _fail("Pilih penasihat.")
			var st: Dictionary = counselors[target]
			if int(st["stars"]) >= Data.MAX_STARS:
				return _fail("Bintang %s sudah penuh." % Data.counselor_def(target)["name"])
			st["stars"] = int(st["stars"]) + 1
			msg = "%s kini bintang %d." % [Data.counselor_def(target)["name"], st["stars"]]
		"pill_intimacy":
			if not beauties.has(target):
				return _fail("Pilih selir.")
			beauties[target]["intimacy"] = int(beauties[target]["intimacy"]) + 10
			msg = "Keakraban dengan %s +10." % Data.beauty_def(target)["name"]
		"energy_tea":
			for key in CHARGE_KEYS:
				charges[key] = {"value": max_charges(), "t": now}
			msg = "Semua urusan dan energi kunjungan terisi penuh."
		"recruit_ticket":
			return _fail("Pakai Tiket Rekrut di halaman Rekrut.")
		_:
			if not def.has("open"):
				return _fail("Item ini tidak bisa dipakai.")
			msg = "Dibuka: %s." % _give_rewards(def["open"])
	add_item(id, -1)
	changed.emit()
	return _ok("%s: %s" % [def["name"], msg])


# --- Tutorial & pengenalan fitur -------------------------------------------

func tutorial_active() -> bool:
	return not bool(tutorial.get("done", true))


func tutorial_step_def() -> Dictionary:
	return Data.TUTORIAL_STEPS[clampi(int(tutorial["step"]), 0, Data.TUTORIAL_STEPS.size() - 1)]


## Maju ke langkah berikutnya; selesai (dengan hadiah) setelah langkah terakhir.
func tutorial_advance() -> Dictionary:
	if not tutorial_active():
		return _fail("Tutorial sudah selesai.")
	tutorial["step"] = int(tutorial["step"]) + 1
	if int(tutorial["step"]) < Data.TUTORIAL_STEPS.size():
		return _ok("")
	tutorial["done"] = true
	var text := _give_rewards(Data.TUTORIAL_REWARD)
	changed.emit()
	var result := _ok("Tutorial selesai! %s." % text)
	result["done"] = true
	return result


func skip_tutorial() -> Dictionary:
	if not tutorial_active():
		return _fail("Tutorial sudah selesai.")
	tutorial["done"] = true
	changed.emit()
	return _ok("Tutorial dilewati. Buka Panduan di menu Kota kapan saja.")


## Fitur yang baru terbuka tapi belum diperkenalkan (kosong bila tidak ada).
func pending_intro() -> Dictionary:
	if tutorial_active():
		return {}
	for intro in Data.FEATURE_INTROS:
		if stage >= int(intro["stage"]) and not (intro["id"] in tutorial["intros"]):
			return intro
	return {}


func mark_intro_seen(id: String) -> void:
	if not (id in tutorial["intros"]):
		tutorial["intros"].append(id)


# --- Hadiah login harian --------------------------------------------------

## Hari (1..7) yang hadiahnya bisa/terakhir diklaim hari ini.
func login_day(now: float) -> int:
	var today := day_index(now)
	var last := int(login["last_day"])
	if last == today:
		return int(login["streak"])
	if last == today - 1:
		return int(login["streak"]) % Data.LOGIN_REWARDS.size() + 1
	return 1


func login_can_claim(now: float) -> bool:
	return int(login["last_day"]) != day_index(now)


## True bila rangkaian login terputus (ada hari yang terlewat sejak klaim terakhir).
func login_streak_broken(now: float) -> bool:
	var last := int(login["last_day"])
	return last >= 0 and last < day_index(now) - 1


## Jumlah hari yang tampil sudah diklaim di kalender saat ini.
func login_claimed_days(now: float) -> int:
	if not login_can_claim(now):
		return int(login["streak"])
	return login_day(now) - 1


func claim_login(now: float) -> Dictionary:
	if not login_can_claim(now):
		return _fail("Hadiah login hari ini sudah diambil.")
	var day := login_day(now)
	login["streak"] = day
	login["last_day"] = day_index(now)
	login["total"] = int(login["total"]) + 1
	var text := _give_rewards(Data.LOGIN_REWARDS[day - 1])
	var vip_msg := add_vip_points(Data.VIP_LOGIN_POINTS)
	changed.emit()
	var result := _ok("Hadiah login Hari %d: %s, +%d poin VIP%s." % [day, text, Data.VIP_LOGIN_POINTS,
		", " + vip_msg if vip_msg != "" else ""])
	result["day"] = day
	return result


# --- Istana: selir & anak -------------------------------------------------

func total_intimacy() -> int:
	var total := 0
	for id in beauties:
		total += int(beauties[id]["intimacy"])
	return total


func child_seats() -> int:
	return rank_info()["child_seats"]


func visit_beauty(id: String, now: float) -> Dictionary:
	if not beauties.has(id):
		return _fail("Belum dikenal.")
	if not _spend_charge("visit", now):
		return _fail("Anda lelah. Tunggu energi kunjungan terisi.")
	var st: Dictionary = beauties[id]
	var gain := 1 + rng.randi_range(0, 2)
	st["intimacy"] = int(st["intimacy"]) + gain
	var name: String = Data.beauty_def(id)["name"]
	var msg := "Keakraban dengan %s +%d." % [name, gain]
	var chance := minf(0.25 + int(st["intimacy"]) * 0.01, 0.6) + event_bonus("child_chance")
	var born := false
	if children.size() < child_seats() and rng.randf() < chance:
		born = true
		var gender := "m" if rng.randf() < 0.5 else "f"
		var names: Array = Data.CHILD_NAMES[gender]
		var child := {
			"name": names[rng.randi_range(0, names.size() - 1)],
			"gender": gender,
			"mother": id,
			"talent": _roll_talent(),
			"level": 1,
		}
		children.append(child)
		msg += " Seorang anak lahir: %s (bakat %d/5)!" % [child["name"], child["talent"]]
	_track("visit")
	changed.emit()
	var result := _ok(msg)
	result["born"] = born
	return result


func _roll_talent() -> int:
	var r := rng.randf()
	if r < 0.05:
		return 5
	if r < 0.15:
		return 4
	if r < 0.35:
		return 3
	if r < 0.65:
		return 2
	return 1


func train_cost(index: int) -> int:
	return 60 * (int(children[index]["level"]) + 1)


func train_child(index: int) -> Dictionary:
	if index < 0 or index >= children.size():
		return _fail("Anak tidak ditemukan.")
	var child: Dictionary = children[index]
	if child["level"] >= Data.CHILD_MAX_LEVEL:
		return _fail("%s sudah dewasa." % child["name"])
	var cost := train_cost(index)
	if grain < cost:
		return _fail("Pangan tidak cukup (butuh %d)." % cost)
	grain -= cost
	child["level"] = int(child["level"]) + 1
	_track("train")
	changed.emit()
	return _ok("%s tumbuh ke level %d." % [child["name"], child["level"]])


## Menikahkan anak dewasa: memberi bonus atribut permanen ke penasihat acak.
func marry_child(index: int) -> Dictionary:
	if index < 0 or index >= children.size():
		return _fail("Anak tidak ditemukan.")
	var child: Dictionary = children[index]
	if child["level"] < Data.CHILD_MAX_LEVEL:
		return _fail("%s belum dewasa." % child["name"])
	var ids := counselors.keys()
	var target: String = ids[rng.randi_range(0, ids.size() - 1)]
	var key: String = Data.ATTRS[rng.randi_range(0, Data.ATTRS.size() - 1)]
	var bonus := int(child["talent"]) * 30
	var b: Dictionary = counselors[target]["bonus"]
	b[key] = int(b.get(key, 0)) + bonus
	children.remove_at(index)
	married_count += 1
	_track("marry")
	prestige += 20 * int(child["talent"])
	changed.emit()
	return _ok("%s menikah! %s mendapat +%d %s." % [
		child["name"], Data.counselor_def(target)["name"], bonus, Data.ATTR_NAMES[key]])


# --- Simpan / muat --------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"silver": silver,
		"grain": grain,
		"soldiers": soldiers,
		"prestige": prestige,
		"rank": rank,
		"stage": stage,
		"married_count": married_count,
		"gold": gold,
		"pity": pity,
		"free_pull_t": free_pull_t,
		"counselors": counselors,
		"beauties": beauties,
		"children": children,
		"charges": charges,
		"daily": daily,
		"login": login,
		"weekly": weekly,
		"alliance": alliance,
		"alliance_left_t": alliance_left_t,
		"arena": arena,
		"war": war,
		"war_reward": war_reward,
		"tutorial": tutorial,
		"iap": iap,
		"vip": vip,
		"inventory": inventory,
		"start_day": start_day,
		"leaderboard": leaderboard,
	}


func from_dict(d: Dictionary, now: float) -> void:
	new_game(now)
	silver = int(d.get("silver", silver))
	grain = int(d.get("grain", grain))
	soldiers = int(d.get("soldiers", soldiers))
	prestige = int(d.get("prestige", prestige))
	rank = clampi(int(d.get("rank", 0)), 0, Data.RANKS.size() - 1)
	stage = int(d.get("stage", 0))
	married_count = int(d.get("married_count", 0))
	gold = int(d.get("gold", gold))
	pity = int(d.get("pity", 0))
	free_pull_t = float(d.get("free_pull_t", free_pull_t))
	# JSON mengubah semua angka menjadi float, jadi normalisasi ke int.
	counselors = {}
	for id in d.get("counselors", {}):
		if Data.counselor_def(id).is_empty():
			continue
		var src: Dictionary = d["counselors"][id]
		var bonus := {}
		for k in src.get("bonus", {}):
			bonus[k] = int(src["bonus"][k])
		counselors[id] = {
			"level": int(src.get("level", 1)),
			"stars": clampi(int(src.get("stars", 0)), 0, Data.MAX_STARS),
			"bonus": bonus,
		}
	beauties = {}
	for id in d.get("beauties", {}):
		if not Data.beauty_def(id).is_empty():
			beauties[id] = {"intimacy": int(d["beauties"][id].get("intimacy", 0))}
	children = []
	for c in d.get("children", []):
		children.append({
			"name": str(c.get("name", "Anak")),
			"gender": "f" if str(c.get("gender", "m")) == "f" else "m",
			"mother": str(c.get("mother", "")),
			"talent": int(c.get("talent", 1)),
			"level": int(c.get("level", 1)),
		})
	charges = {}
	for key in CHARGE_KEYS:
		var c: Dictionary = d.get("charges", {}).get(key, {})
		charges[key] = {"value": int(c.get("value", max_charges())), "t": float(c.get("t", now))}
	daily = {}
	var src_daily: Dictionary = d.get("daily", {})
	if not src_daily.is_empty():
		var missions := []
		for m in src_daily.get("missions", []):
			if not Data.mission_def(str(m.get("id", ""))).is_empty():
				missions.append({"id": str(m["id"]), "progress": int(m.get("progress", 0)),
					"claimed": bool(m.get("claimed", false))})
		var chests := []
		for i in Data.DAILY_CHESTS.size():
			var saved: Array = src_daily.get("chests", [])
			chests.append(bool(saved[i]) if i < saved.size() else false)
		daily = {"day": int(src_daily.get("day", -1)), "missions": missions,
			"points": int(src_daily.get("points", 0)), "chests": chests}
	var src_login: Dictionary = d.get("login", {})
	login = {
		"streak": clampi(int(src_login.get("streak", 0)), 0, Data.LOGIN_REWARDS.size()),
		"last_day": int(src_login.get("last_day", -1)),
		"total": int(src_login.get("total", 0)),
	}
	var src_weekly: Dictionary = d.get("weekly", {})
	if not src_weekly.is_empty():
		var saved: Array = src_weekly.get("claimed", [])
		var claimed := []
		for i in Data.EVENT_TIERS.size():
			claimed.append(bool(saved[i]) if i < saved.size() else false)
		weekly = {"week": int(src_weekly.get("week", -1)), "points": int(src_weekly.get("points", 0)),
			"claimed": claimed}
	alliance_left_t = float(d.get("alliance_left_t", alliance_left_t))
	alliance = _load_alliance(d.get("alliance", {}))
	arena = _load_arena(d.get("arena", {}))
	war = _load_war(d.get("war", {}))
	war_reward = {}
	var src_wr: Dictionary = d.get("war_reward", {})
	if not src_wr.is_empty():
		war_reward = {"win": bool(src_wr.get("win", false)), "ours": int(src_wr.get("ours", 0)),
			"theirs": int(src_wr.get("theirs", 0)), "enemy": str(src_wr.get("enemy", "")),
			"merit": int(src_wr.get("merit", 0)),
			"reward": {"gold": int(src_wr.get("reward", {}).get("gold", 0)),
				"jasa": int(src_wr.get("reward", {}).get("jasa", 0))}}
	var src_iap: Dictionary = d.get("iap", {})
	iap = _empty_iap()
	for k in ["first", "processed", "once"]:
		for v in src_iap.get(k, []):
			iap[k].append(str(v))
	for k in ["card_until", "card_claimed", "spent_idr"]:
		iap[k] = int(src_iap.get(k, iap[k]))
	inventory = {}
	for id in d.get("inventory", {}):
		if Data.ITEMS.has(str(id)) and int(d["inventory"][id]) > 0:
			inventory[str(id)] = int(d["inventory"][id])
	start_day = int(d.get("start_day", day_index(now)))
	var src_lb: Dictionary = d.get("leaderboard", {})
	leaderboard = {"week": int(src_lb.get("week", week_index(now))), "reward": {}}
	var src_lbr: Dictionary = src_lb.get("reward", {})
	if not src_lbr.is_empty():
		leaderboard["reward"] = {"tier": str(src_lbr.get("tier", "")), "rank": int(src_lbr.get("rank", 0)),
			"gold": int(src_lbr.get("gold", 0))}
	var src_vip: Dictionary = d.get("vip", {})
	vip = {"points": int(src_vip.get("points", 0)), "daily_day": int(src_vip.get("daily_day", -1)),
		"packs": [], "gifts": []}
	for k in ["packs", "gifts"]:
		for v in src_vip.get(k, []):
			vip[k].append(int(v))
	var src_tut: Dictionary = d.get("tutorial", {})
	if src_tut.is_empty():
		# Save dari versi sebelum ada tutorial: pemain lama tidak perlu tutorial
		# maupun pengenalan fitur yang sudah lama terbuka.
		tutorial = {"step": Data.TUTORIAL_STEPS.size(), "done": true, "intros": []}
		for intro in Data.FEATURE_INTROS:
			if stage >= int(intro["stage"]):
				tutorial["intros"].append(intro["id"])
	else:
		var intros := []
		for id in src_tut.get("intros", []):
			intros.append(str(id))
		tutorial = {"step": int(src_tut.get("step", 0)), "done": bool(src_tut.get("done", false)), "intros": intros}
	_unlock_content()
	sync(now)
	changed.emit()


func _load_war(src: Dictionary) -> Dictionary:
	if src.is_empty() or Data.alliance_def(str(src.get("enemy", ""))).is_empty():
		return {}
	var out := {"enemy": str(src["enemy"])}
	for k in ["week", "last_day", "attack_day", "attacks", "merit"]:
		out[k] = int(src.get(k, 0))
	for k in ["our", "our_max", "their", "their_max"]:
		out[k] = []
		for v in src.get(k, []):
			out[k].append(int(v))
		if out[k].size() != Data.WAR_FORTS.size():
			return {}
	out["log"] = []
	for line in src.get("log", []):
		out["log"].append(str(line))
	return out


func _load_arena(src: Dictionary) -> Dictionary:
	if src.is_empty():
		return {}
	var out := {}
	for k in ["rating", "best", "coins", "wins", "losses", "week", "season_fights", "last_day", "day",
			"tickets_used", "tickets_bought", "refresh_used"]:
		out[k] = int(src.get(k, 0))
	var sr: Dictionary = src.get("season_reward", {})
	out["season_reward"] = {}
	if not sr.is_empty():
		var reward := {}
		for k in sr.get("reward", {}):
			reward[str(k)] = int(sr["reward"][k])
		out["season_reward"] = {"league": str(sr.get("league", "")), "reward": reward}
	var shop: Dictionary = src.get("shop", {})
	var bought := {}
	for k in shop.get("bought", {}):
		bought[str(k)] = int(shop["bought"][k])
	out["shop"] = {"day": int(shop.get("day", -1)), "bought": bought}
	out["opponents"] = []
	for o in src.get("opponents", []):
		out["opponents"].append({"name": str(o.get("name", "")), "avatar": str(o.get("avatar", "arya")),
			"rating": int(o.get("rating", 0)), "power": int(o.get("power", 10))})
	out["log"] = []
	for line in src.get("log", []):
		out["log"].append(str(line))
	return out


func _load_alliance(src: Dictionary) -> Dictionary:
	if src.is_empty() or Data.alliance_def(str(src.get("id", ""))).is_empty():
		return {}
	var don: Dictionary = src.get("donations", {})
	var shop: Dictionary = src.get("shop", {})
	var bought := {}
	for k in shop.get("bought", {}):
		bought[str(k)] = int(shop["bought"][k])
	var boss: Dictionary = src.get("boss", {})
	var out := {
		"id": str(src["id"]), "join_day": int(src.get("join_day", 0)), "last_day": int(src.get("last_day", 0)),
		"exp": int(src.get("exp", 0)), "jasa": int(src.get("jasa", 0)), "jasa_total": int(src.get("jasa_total", 0)),
		"donations": {"day": int(don.get("day", -1)), "count": int(don.get("count", 0))},
		"shop": {"day": int(shop.get("day", -1)), "bought": bought},
		"boss": {},
		"log": [],
	}
	if not boss.is_empty():
		out["boss"] = {"week": int(boss.get("week", -1)), "hp_max": int(boss.get("hp_max", 1)),
			"damage": int(boss.get("damage", 0)), "attack_day": int(boss.get("attack_day", -1)),
			"attacks": int(boss.get("attacks", 0)), "claimed": bool(boss.get("claimed", false))}
	for line in src.get("log", []):
		out["log"].append(str(line))
	var chat: Dictionary = src.get("chat", {})
	out["chat"] = {"msgs": [], "slot": int(chat.get("slot", 0)), "read_t": float(chat.get("read_t", 0.0)),
		"sent_t": float(chat.get("sent_t", 0.0))}
	for m in chat.get("msgs", []):
		var msg := {"t": float(m.get("t", 0.0)), "text": str(m.get("text", ""))}
		for k in ["from", "role", "avatar"]:
			if m.has(k):
				msg[k] = str(m[k])
		for k in ["me", "system"]:
			if m.get(k, false):
				msg[k] = true
		out["chat"]["msgs"].append(msg)
	return out


func _ok(msg: String) -> Dictionary:
	return {"ok": true, "msg": msg}


func _fail(msg: String) -> Dictionary:
	return {"ok": false, "msg": msg}
