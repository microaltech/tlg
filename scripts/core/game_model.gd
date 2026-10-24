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
	if ensure_weekly(now) or daily_reset:
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
		* (1.0 + event_bonus("yield_" + kind)))


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
	_unlock_content()
	sync(now)
	changed.emit()


func _ok(msg: String) -> Dictionary:
	return {"ok": true, "msg": msg}


func _fail(msg: String) -> Dictionary:
	return {"ok": false, "msg": msg}
