extends RefCounted
## Seluruh logika game (ekonomi, penasihat, kampanye, istana, simpan/muat).
## Tidak bergantung pada scene/UI sehingga bisa diuji secara headless.
## Semua fungsi yang bergantung waktu menerima `now` (detik unix).

signal changed
## Dipancarkan saat progres sebuah misi harian mencapai target.
signal mission_completed(text: String)

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
## Waktu keluar aliansi terakhir (untuk jeda sebelum bergabung lagi).
var alliance_left_t := -1.0e12
## Selisih zona waktu (detik) supaya misi direset pada tengah malam lokal.
var tz_bias := 0
var rng := RandomNumberGenerator.new()


func new_game(now: float) -> void:
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
	return rank_info()["max_charges"]


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

func sync(now: float) -> void:
	for key in CHARGE_KEYS:
		_sync_charge(key, now)
	var daily_reset := ensure_daily(now)
	var weekly_reset := ensure_weekly(now)
	if _alliance_rollover(now) or weekly_reset or daily_reset:
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
		* (1.0 + event_bonus("yield_" + kind) + alliance_bonus()))


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
	if soldiers < losses:
		var lost := int(soldiers * 0.5)
		soldiers -= lost
		changed.emit()
		return _fail("Kalah di %s! %d prajurit gugur. Butuh sekitar %d prajurit." % [info["name"], lost, losses])
	soldiers -= losses
	silver += int(info["reward_silver"])
	prestige += int(info["reward_prestige"])
	gold += int(info["reward_gold"])
	stage += 1
	_track("win")
	var unlocked := _unlock_content()
	changed.emit()
	var msg := "Menang di %s! -%d prajurit, +%d perak, +%d prestise, +%d emas." % [
		info["name"], losses, info["reward_silver"], info["reward_prestige"], info["reward_gold"]]
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
func recruit(count: int, now: float, free := false) -> Dictionary:
	if count != 1 and count != 10:
		return _fail("Jumlah rekrut tidak valid.")
	var cost := 0
	if free:
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
		"boss": {}, "log": [],
	}
	_ensure_boss(now)
	_alliance_log("Anda bergabung dengan %s. Selamat datang!" % def["name"])
	_alliance_log("%s: \"Selamat datang di %s, Tuan!\"" % [_npc_members()[0]["name"], def["name"]])
	changed.emit()
	return _ok("Anda bergabung dengan %s!" % def["name"])


func leave_alliance(now: float) -> Dictionary:
	if alliance.is_empty():
		return _fail("Anda belum tergabung dalam aliansi.")
	var name: String = alliance_def()["name"]
	alliance = {}
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


## Anggota NPC: nama, jabatan, dan kekuatan dasar (tetap untuk tiap aliansi).
func _npc_members() -> Array:
	var id: String = alliance["id"]
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


func donations_left(now: float) -> int:
	var d: Dictionary = alliance["donations"]
	if int(d["day"]) != day_index(now):
		return Data.ALLIANCE_DONATIONS_PER_DAY
	return Data.ALLIANCE_DONATIONS_PER_DAY - int(d["count"])


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


func shop_left(id: String, now: float) -> int:
	var shop: Dictionary = alliance["shop"]
	var limit := int(Data.shop_def(id)["limit"])
	if int(shop["day"]) != day_index(now):
		return limit
	return limit - int(shop["bought"].get(id, 0))


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
	var shop: Dictionary = alliance["shop"]
	if int(shop["day"]) != day_index(now):
		shop["day"] = day_index(now)
		shop["bought"] = {}
	shop["bought"][id] = int(shop["bought"].get(id, 0)) + 1
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
		"my_damage": int(boss["damage"]), "npc_damage": npc, "attacks_left": Data.BOSS_ATTACKS_PER_DAY - used,
		"defeated": hp <= 0, "claimed": bool(boss["claimed"]),
		"can_claim": hp <= 0 and not bool(boss["claimed"]) and int(boss["damage"]) > 0,
	}


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
	changed.emit()
	var result := _ok("Hadiah login Hari %d: %s." % [day, text])
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
	_unlock_content()
	sync(now)
	changed.emit()


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
	return out


func _ok(msg: String) -> Dictionary:
	return {"ok": true, "msg": msg}


func _fail(msg: String) -> Dictionary:
	return {"ok": false, "msg": msg}
