extends RefCounted
## Seluruh logika game (ekonomi, penasihat, kampanye, istana, simpan/muat).
## Tidak bergantung pada scene/UI sehingga bisa diuji secara headless.
## Semua fungsi yang bergantung waktu menerima `now` (detik unix).

signal changed
## Dipancarkan saat progres sebuah misi harian mencapai target.
signal mission_completed(text: String)
## Dipancarkan untuk setiap aksi pemain yang dicatat (dipakai tutorial).
signal tracked(event: String)
## Paket terbatas waktu baru muncul (UI menampilkannya sekali).
signal offer_created(offer: Dictionary)
## Tingkat pencapaian baru tercapai (untuk Google Play Games & notifikasi UI).
signal achievement_reached(id: String, tier: int)

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
var soldiers := 2500
var prestige := 0
var rank := 0
var stage := 0
var married_count := 0
var gold := 0
## Tarikan sejak Legenda terakhir (untuk jaminan pity).
var pity := 0
## true bila Legenda terakhir bukan unggulan: Legenda berikutnya pasti unggulan.
var rateup_guarantee := false
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
## Misi utama: {"chapter": int, "claimed": [indeks misi bab ini], "seen": [bab yang ceritanya sudah tampil]}
var story := {}
## Pejabat dari anak yang lulus ujian: [{"name", "gender", "talent", "title"}]
var officials: Array = []
## Perjamuan: {"day": hari pesta terakhir per jenis {jenis: hari}, "invite_day": int, "attended": [indeks]}
var banquet := {}
## Penjara: {"prisoners": [{"name", "avatar", "stage", "hp", "max"}], "day": int, "used": int}
var prison := {}
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
## Nama Tuan pilihan pemain; kosong = belum diatur (tampil sebagai "Anda"/"Tuan").
var lord_name := ""
## Pusaka milik pemain: [{"uid", "id", "level", "owner"}]; owner = id penasihat atau "".
var equipment: Array = []
## Menara Ujian: {"week", "floor" (lantai tertinggi minggu ini), "best", "day", "attempts"}
var tower := {}
## Iklan berhadiah yang sudah ditonton hari ini: {"day", "counts": {jenis: n}}
var ads := {}
## Tiket Musim: {"season", "xp", "premium", "free": [tingkat], "paid": [tingkat]}
var season_pass := {}
## Paket terbatas aktif: [{"id": id produk, "expires": waktu, "reward": {...}}]
var offers: Array = []
var loss_streak := 0
## Penghitung aksi seumur akun (event _track -> jumlah) untuk pencapaian.
var counters := {}
## Pencapaian: id -> jumlah tingkat yang hadiahnya sudah diklaim.
var achievements := {}
var _equip_uid := 0
## Formasi pasukan yang dipakai di semua pertempuran (lihat Data.FORMATIONS).
var formation := "balanced"
## Festival musiman yang sedang berjalan: key (id-tahun), progress tugas, klaim, token,
## pembelian toko, dan hari hadiah harian terakhir. Kosong bila tidak ada festival.
var festival := {}
## Kosmetik: owned (id), frame & costume yang dipakai.
var cosmetics := {}
## Bangunan kota: levels {id: level} dan job pembangunan berjalan {id, end_t} atau {}.
var buildings := {}
## Ekspedisi berjalan: [{dest, counselor, end_t, reward}].
var expeditions: Array = []
var rng := RandomNumberGenerator.new()


func new_game(now: float) -> void:
	_last_now = now
	lord_name = ""
	formation = "balanced"
	festival = {}
	expeditions = []
	buildings = {"levels": {"istana": 1, "pasar": 0, "lumbung": 0, "barak": 0}, "job": {}}
	cosmetics = {"owned": ["frame_kayu", "costume_lord"], "frame": "frame_kayu", "costume": "costume_lord"}
	equipment = []
	_equip_uid = 0
	tower = {}
	ads = {"day": -1, "counts": {}}
	season_pass = {}
	offers = []
	loss_streak = 0
	counters = {}
	achievements = {}
	silver = 500
	grain = 500
	soldiers = 2500
	prestige = 0
	rank = 0
	stage = 0
	married_count = 0
	gold = Data.START_GOLD
	pity = 0
	rateup_guarantee = false
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
	prison = {"prisoners": [], "day": -1, "used": 0}
	officials = []
	banquet = {"held": {}, "invite_day": -1, "attended": []}
	story = {"chapter": 0, "claimed": [], "seen": []}
	_npc_cache = {}
	_unlock_content()
	ensure_daily(now)
	ensure_weekly(now)
	ensure_festival(now)
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
	_create_offer("offer_promote", {"gold": 300 + 150 * rank, "silver": 20000 * rank,
		"items": {"star_stone": 1, "recruit_ticket": 2}}, _last_now)
	changed.emit()
	return _ok("Selamat! Anda kini menjabat sebagai %s. +%d emas." % [rank_info()["name"], Data.PROMOTE_GOLD])


# --- Charge (energi yang terisi seiring waktu) ----------------------------

## Waktu sinkronisasi terakhir, untuk aksi yang tidak menerima `now`.
var _last_now := 0.0


func sync(now: float) -> void:
	_last_now = now
	var built := finish_build(now)
	for key in CHARGE_KEYS:
		_sync_charge(key, now)
	var daily_reset := ensure_daily(now)
	var weekly_reset := ensure_weekly(now)
	ensure_leaderboard(now)
	ensure_festival(now)
	var alliance_changed := _alliance_rollover(now)
	alliance_changed = ensure_war(now) or alliance_changed
	if ensure_arena(now) or alliance_changed or weekly_reset or daily_reset or built:
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
	return int(int(def[key]) * int(st["level"]) * mult) + int(st["bonus"].get(key, 0)) + equipment_bonus(id, key)


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
	return int(Data.UPGRADE_COST_BASE * pow(int(counselors[id]["level"]), Data.UPGRADE_COST_EXP)
		* (1.0 - skill_bonus("train_cost")))


# --- Skill & ikatan ----------------------------------------------------------

func skill_value(id: String) -> float:
	var sk: Dictionary = Data.SKILLS.get(id, {})
	if sk.is_empty() or not counselors.has(id):
		return 0.0
	return float(sk["base"]) + float(sk["per_star"]) * int(counselors[id].get("stars", 0))


func bonds_active() -> Array:
	return Data.BONDS.filter(func(b): return b["members"].all(func(id): return counselors.has(id)))


## Total bonus suatu efek dari skill dan ikatan (dibatasi SKILL_CAP).
func skill_bonus(effect: String) -> float:
	var total := 0.0
	for id in counselors:
		if Data.SKILLS.has(id) and Data.SKILLS[id]["effect"] == effect:
			total += skill_value(id)
	for b in bonds_active():
		if b["effect"] == effect:
			total += float(b["value"])
	return minf(total, Data.SKILL_CAP)


## Kekuatan yang dipakai untuk pertarungan arena, bos aliansi, dan perang.
func combat_power() -> int:
	return int(power() * (1.0 + skill_bonus("combat")) * (1.0 + float(formation_def()["power"])))


# --- Formasi & rencana pertempuran ---------------------------------------------

func formation_def() -> Dictionary:
	return Data.FORMATIONS.get(formation, Data.FORMATIONS["balanced"])


func set_formation(id: String) -> Dictionary:
	if not Data.FORMATIONS.has(id):
		return _fail("Formasi tidak dikenal.")
	formation = id
	changed.emit()
	return _ok("Formasi %s dipakai." % Data.FORMATIONS[id]["name"])


## Penasihat yang tampil di layar perang: tiga terkuat (atribut kekuatan) beserta jurusnya.
func battle_heroes(count := 3) -> Array:
	var ids := counselors.keys()
	ids.sort_custom(func(a, b): return attr(a, "str") > attr(b, "str"))
	var out := []
	for id in ids.slice(0, count):
		var sk: Dictionary = Data.SKILLS.get(id, {})
		out.append({"id": id, "name": Data.counselor_def(id)["name"],
			"skill": str(sk.get("name", "Serangan Pamungkas"))})
	return out


## Naskah tayangan perang. Hasil sudah dihitung lebih dulu; naskah hanya membagi
## sisa pasukan kedua pihak (1.0 = utuh) ke tiap ronde agar animasinya sesuai hasil.
## Memakai RNG tersendiri sehingga tidak mengubah hasil acak game.
func battle_plan(me_end: float, them_end: float, seed_key: int, rounds := 3) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = seed_key
	me_end = clampf(me_end, 0.0, 1.0)
	them_end = clampf(them_end, 0.0, 1.0)
	var me := [1.0]
	var them := [1.0]
	for k in range(1, rounds + 1):
		var t := float(k) / rounds
		var jm := r.randf_range(-0.08, 0.08) if k < rounds else 0.0
		var jt := r.randf_range(-0.08, 0.08) if k < rounds else 0.0
		me.append(clampf(lerpf(1.0, me_end, t) + jm, me_end, me[-1]))
		them.append(clampf(lerpf(1.0, them_end, t) + jt, them_end, them[-1]))
	var heroes := battle_heroes()
	var skills := []
	for k in rounds:
		skills.append(k % heroes.size() if not heroes.is_empty() else -1)
	return {"me": me, "them": them, "heroes": heroes, "skills": skills, "formation": formation}


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
		* (1.0 + event_bonus("yield_" + kind) + alliance_bonus() + vip_perk("yield"))
		* (1.0 + skill_bonus("yield_" + kind) + skill_bonus("yield_all") + officials_bonus() + honor_bonus()
			+ building_bonus("yield_" + kind) + building_bonus("yield_all")))


func do_affair(kind: String, now: float) -> Dictionary:
	if not AFFAIRS.has(kind):
		return _fail("Urusan tidak dikenal.")
	var amount := affair_yield(kind)
	var grain_used := 0
	if kind == "soldiers":
		# Prajurit baru butuh pangan; rekrut sebanyak yang bisa diberi makan.
		amount = mini(amount, int(grain / Data.SOLDIER_GRAIN))
		if amount <= 0:
			return _fail("Pangan habis. Kelola sawah dulu untuk memberi makan prajurit baru.")
		grain_used = int(ceil(amount * Data.SOLDIER_GRAIN))
	if not _spend_charge(kind, now):
		return _fail("Belum ada urusan baru. Tunggu sebentar.")
	grain -= grain_used
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
	if grain_used > 0:
		return _ok("+%d %s, -%d Pangan" % [amount, resource_name(kind), grain_used])
	return _ok("+%d %s" % [amount, resource_name(kind)])


## Jabatan minimal untuk tombol "Kerjakan Semua" (pemain baru belajar satu per satu dulu).
const DO_ALL_RANK := 1


func do_all_unlocked() -> bool:
	return rank >= DO_ALL_RANK


## Habiskan semua urusan kota, energi kunjungan (bergiliran ke tiap selir), dan
## didik semua anak yang siap. Hasil sama dengan menekan tiap tombol satu per satu.
func do_all(now: float) -> Dictionary:
	if not do_all_unlocked():
		return _fail("Kerjakan Semua terbuka setelah naik jabatan menjadi %s." % Data.RANKS[DO_ALL_RANK]["name"])
	var gained := {"silver": 0, "grain": 0, "soldiers": 0}
	# Pangan dulu agar prajurit baru bisa diberi makan.
	for kind in ["silver", "grain", "soldiers"]:
		var before: int = get(kind)
		while do_affair(kind, now)["ok"]:
			pass
		gained[kind] = int(get(kind)) - before
	var visits := 0
	var births := 0
	var ids := beauties.keys()
	while not ids.is_empty():
		var r := visit_beauty(ids[visits % ids.size()], now)
		if not r["ok"]:
			break
		visits += 1
		if r.get("born", false):
			births += 1
	var trained := 0
	for i in children.size():
		if train_child(i, now)["ok"]:
			trained += 1
	var parts := []
	for kind in ["silver", "grain", "soldiers"]:
		if gained[kind] != 0:
			parts.append("%+d %s" % [gained[kind], resource_name(kind)])
	if visits > 0:
		parts.append("%d kunjungan" % visits)
	if births > 0:
		parts.append("%d anak lahir" % births)
	if trained > 0:
		parts.append("%d anak dididik" % trained)
	if parts.is_empty():
		return _fail("Belum ada yang bisa dikerjakan. Tunggu urusan dan energi terisi.")
	var result := _ok("Semua dikerjakan: %s." % ", ".join(parts))
	result["born"] = births > 0
	return result


static func resource_name(kind: String) -> String:
	return {"silver": "Perak", "grain": "Pangan", "soldiers": "Prajurit"}.get(kind, kind)


# --- Kampanye -------------------------------------------------------------

func current_stage_info() -> Dictionary:
	return Data.stage_info(stage)


## Perkiraan prajurit yang gugur bila menyerang tahap saat ini.
func expected_losses() -> int:
	var info := current_stage_info()
	var ratio := clampf(float(info["enemy_str"]) / maxi(1, total_attr("str")), Data.LOSS_RATIO_MIN, 4.0)
	return int(ceil(int(info["enemy_soldiers"]) * ratio * (1.0 + event_bonus("losses")) * (1.0 - skill_bonus("battle"))
		* (1.0 + float(formation_def()["losses"]))))


func fight_stage() -> Dictionary:
	var info := current_stage_info()
	var losses := expected_losses()
	_track("battle")
	if soldiers < losses:
		var lost := int(soldiers * 0.5)
		soldiers -= lost
		loss_streak += 1
		if loss_streak >= Data.OFFER_LOSS_STREAK:
			_create_offer("offer_rescue", {"soldiers": int(losses * 3), "grain": 50000, "items": {"energy_tea": 2}},
				_last_now)
		changed.emit()
		return _fail("Kalah di %s! %d prajurit gugur. Butuh sekitar %d prajurit." % [info["name"], lost, losses])
	soldiers -= losses
	loss_streak = 0
	silver += int(info["reward_silver"])
	var gained_prestige := int(int(info["reward_prestige"]) * (1.0 + skill_bonus("prestige"))
		* (1.0 + float(formation_def()["prestige"])))
	prestige += gained_prestige
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
		info["name"], losses, info["reward_silver"], gained_prestige, info["reward_gold"]]
	if stage_item != "":
		msg += " Rampasan: %s." % Data.ITEMS[stage_item]["name"]
		if rng.randf() < Data.EQUIP_DROP_CHANCE:
			var eq := add_equipment(Data.equip_roll(stage, rng.randf(), rng.randf()))
			if not eq.is_empty():
				msg += " Pusaka: %s." % Data.equip_def(eq["id"])["name"]
	var captured := _capture_prisoner(info)
	if captured != "":
		msg += " Tertangkap: %s!" % captured
	if not unlocked.is_empty():
		msg += " Bergabung: %s" % ", ".join(unlocked)
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
		var id: String = pool[rng.randi_range(0, pool.size() - 1)]["id"]
		var featured := false
		if rarity == "ssr":
			id = _pick_ssr(now)
			featured = id == rateup_id(now)
		var granted := _grant_counselor(id, rarity)
		granted["featured"] = featured
		results.append(granted)
	_track("recruit", count)
	changed.emit()
	var names := []
	for r in results:
		if r["new"]:
			names.append(Data.counselor_def(r["id"])["name"])
	var msg := "Rekrut selesai."
	if not names.is_empty():
		msg += " Bergabung: %s" % ", ".join(names)
	var result := _ok(msg)
	result["results"] = results
	return result


## Legenda unggulan minggu ini (bergilir di antara semua Legenda).
func rateup_id(now: float) -> String:
	var pool := Data.counselors_of_rarity("ssr")
	return pool[posmod(week_index(now), pool.size())]["id"]


func _pick_ssr(now: float) -> String:
	var feat := rateup_id(now)
	if rateup_guarantee or rng.randf() < Data.RATEUP_CHANCE:
		rateup_guarantee = false
		return feat
	var others := Data.counselors_of_rarity("ssr").filter(func(c): return c["id"] != feat)
	rateup_guarantee = true
	return others[rng.randi_range(0, others.size() - 1)]["id"] if not others.is_empty() else feat


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
		if m.get("requires", "") == "prisoners" and prison.get("prisoners", []).is_empty():
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
	counters[event] = int(counters.get(event, 0)) + amount
	if Data.PASS_XP.has(event):
		add_pass_xp(int(Data.PASS_XP[event]) * amount)
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
	if not festival.is_empty():
		var prog: Dictionary = festival["progress"]
		for t in Data.FESTIVAL_TASKS:
			if t["event"] == event:
				prog[t["id"]] = mini(int(t["target"]), int(prog.get(t["id"], 0)) + amount)


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
	_track("mission")
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
	_track("chest")
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
	out.append({"name": me_name(), "role": "Anggota", "power": power(), "damage": int(alliance["boss"]["damage"]),
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
	var dmg := mini(int(combat_power() * Data.BOSS_DAMAGE_PER_POWER * rng.randf_range(0.9, 1.1)), int(info["hp"]))
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
	var vals := {"player": lord_name if lord_name != "" else "Tuan", "alliance": alliance_def()["name"], "boss": Data.BOSS_NAME, "hp": 100,
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
	var dmg := mini(int(combat_power() * Data.WAR_DAMAGE_PER_POWER * rng.randf_range(0.9, 1.1)), int(war["their"][index]))
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
	if war_reward["win"]:
		var eq := add_equipment(Data.equip_roll(stage + 30, rng.randf(), rng.randf()))
		if not eq.is_empty():
			parts.append(Data.equip_def(eq["id"])["name"])
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
	var a := pow(float(maxi(1, combat_power())), 3.0)
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
	_arena_log(("Anda menang melawan %s (%+d poin)." if win else "Anda kalah melawan %s (%+d poin).") % [
		opp["name"], delta])
	var rounds := _arena_rounds(win)
	_refresh_opponents()
	changed.emit()
	var msg := ("Menang melawan %s! %+d poin arena, +%d koin arena, +%d perak." % [
		opp["name"], delta, reward.get("coins", 0), reward["silver"]]) if win \
		else "Kalah melawan %s! %+d poin arena, +%d koin arena." % [opp["name"], delta, reward.get("coins", 0)]
	var result := _ok(msg)
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
			_arena_log(("%s menyerang Anda dan kalah (%+d poin)." if held else "%s menyerang Anda dan menang (%+d poin).")
				% [opp["name"], delta])


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
	var mine := {"name": me_name(), "avatar": "lord", "rating": int(arena["rating"]), "me": true}
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
		"offer":
			var offer := active_offer(id, now)
			if offer.is_empty():
				return _fail("Penawaran %s sudah berakhir." % def["name"])
			offers.erase(offer)
			parts.append(_give_rewards(offer["reward"]))
		"pass":
			ensure_pass(now)
			if season_pass["premium"]:
				return _fail("Tiket Musim Premium musim ini sudah aktif.")
			season_pass["premium"] = true
			parts.append("Tiket Musim Premium aktif")
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
		"tower":
			return int(tower.get("best", 0))
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
		rows.insert(mine["rank"] - 1, {"name": me_name(), "tag": tag, "avatar": "lord", "value": mine["value"], "me": true})
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


# --- Cerita & misi utama -------------------------------------------------------

## Gelar kehormatan tertinggi yang sudah diraih (kosong bila belum ada).
func honor_title() -> Dictionary:
	var out := {}
	for h in Data.HONOR_TITLES:
		if int(story.get("chapter", 0)) >= int(h["chapters"]):
			out = h
	return out


func honor_bonus() -> float:
	return float(honor_title().get("bonus", 0.0))


func story_done() -> bool:
	return int(story["chapter"]) >= Data.STORY_CHAPTERS.size()


func story_chapter_def() -> Dictionary:
	return {} if story_done() else Data.STORY_CHAPTERS[int(story["chapter"])]


## Nilai sekarang untuk jenis misi tertentu.
func story_metric(type: String) -> int:
	match type:
		"stage":
			return stage
		"power":
			return power()
		"rank":
			return rank
		"counselors":
			return counselors.size()
		"max_level":
			var best := 0
			for id in counselors:
				best = maxi(best, int(counselors[id]["level"]))
			return best
		"prestige":
			return prestige
		"children_total":
			return children.size() + married_count + officials.size()
		"intimacy":
			return total_intimacy()
		"alliance":
			return 0 if alliance.is_empty() else 1
		"arena_wins":
			return 0 if arena.is_empty() else int(arena["wins"])
		"officials":
			return officials.size()
		"tower":
			return int(tower.get("best", 0))
		"equipment":
			return equipment.size()
		"equip_level":
			var best_eq := 0
			for eq in equipment:
				best_eq = maxi(best_eq, int(eq["level"]))
			return best_eq
		"stars_total":
			var total := 0
			for id in counselors:
				total += int(counselors[id].get("stars", 0))
			return total
	return 0


## Misi bab sekarang: [{"text", "current", "target", "done", "claimed", "reward"}]
func story_quests() -> Array:
	var out := []
	var def := story_chapter_def()
	for i in def.get("quests", []).size():
		var q: Dictionary = def["quests"][i]
		var cur := story_metric(q["type"])
		out.append({"text": q["text"], "current": cur, "target": int(q["target"]), "done": cur >= int(q["target"]),
			"claimed": i in story["claimed"], "reward": q["reward"]})
	return out


func story_claimable() -> int:
	var n := 0
	for q in story_quests():
		if q["done"] and not q["claimed"]:
			n += 1
	if not story_done() and story["claimed"].size() == story_quests().size():
		n += 1
	return n


func claim_quest(index: int) -> Dictionary:
	var quests := story_quests()
	if index < 0 or index >= quests.size():
		return _fail("Misi tidak ditemukan.")
	if quests[index]["claimed"]:
		return _fail("Hadiah misi sudah diambil.")
	if not quests[index]["done"]:
		return _fail("Misi belum selesai.")
	story["claimed"].append(index)
	var text := _give_rewards(quests[index]["reward"])
	changed.emit()
	return _ok("Misi utama selesai: %s." % text)


func claim_chapter() -> Dictionary:
	if story_done():
		return _fail("Semua bab sudah tamat.")
	if story["claimed"].size() < story_quests().size():
		return _fail("Selesaikan semua misi bab ini dulu.")
	var def := story_chapter_def()
	var text := _give_rewards(def["reward"])
	story["chapter"] = int(story["chapter"]) + 1
	story["claimed"] = []
	changed.emit()
	var msg := "Bab \"%s\" tamat! %s." % [def["title"], text]
	if story_done():
		msg += " Selamat, seluruh kisah telah tamat!"
	var honor := honor_title()
	if not honor.is_empty() and int(story["chapter"]) == int(honor["chapters"]):
		msg += " Gelar kehormatan: %s (semua hasil urusan +%d%%)." % [honor["name"], roundi(float(honor["bonus"]) * 100)]
	return _ok(msg)


## Bab yang ceritanya belum ditampilkan (-1 bila tidak ada).
func story_pending_dialog() -> int:
	if story_done() or tutorial_active() or int(story["chapter"]) in story["seen"]:
		return -1
	return int(story["chapter"])


func mark_story_seen(chapter: int) -> void:
	if not (chapter in story["seen"]):
		story["seen"].append(chapter)


# --- Ujian anak & pejabat ---------------------------------------------------

func exam_chance(index: int) -> float:
	return minf(0.95, Data.EXAM_BASE_CHANCE + Data.EXAM_CHANCE_PER_TALENT * int(children[index]["talent"]))


func exam_cost(index: int) -> int:
	return Data.EXAM_COST_PER_TALENT * int(children[index]["talent"])


func exam_available(index: int, now: float) -> bool:
	var c: Dictionary = children[index]
	return int(c["level"]) >= Data.CHILD_MAX_LEVEL and int(c.get("exam_day", -1)) != day_index(now)


func officials_bonus() -> float:
	var total := 0.0
	for o in officials:
		for t in Data.OFFICIAL_TITLES:
			if t["name"] == o["title"]:
				total += float(t["bonus"])
	return total


func take_exam(index: int, now: float) -> Dictionary:
	if index < 0 or index >= children.size():
		return _fail("Anak tidak ditemukan.")
	var c: Dictionary = children[index]
	if int(c["level"]) < Data.CHILD_MAX_LEVEL:
		return _fail("%s belum dewasa." % c["name"])
	if not exam_available(index, now):
		return _fail("%s sudah ikut ujian hari ini. Coba lagi besok." % c["name"])
	if officials.size() >= Data.OFFICIALS_MAX:
		return _fail("Kursi pejabat sudah penuh (%d)." % Data.OFFICIALS_MAX)
	var cost := exam_cost(index)
	if silver < cost:
		return _fail("Perak tidak cukup (butuh %d)." % cost)
	silver -= cost
	if rng.randf() >= exam_chance(index):
		c["exam_day"] = day_index(now)
		changed.emit()
		var fail := _fail("%s belum lulus ujian. Coba lagi besok, atau nikahkan." % c["name"])
		fail["exam"] = true
		return fail
	var score := int(c["talent"]) + rng.randi_range(0, 2)
	var title: Dictionary = Data.OFFICIAL_TITLES[0]
	for t in Data.OFFICIAL_TITLES:
		if score >= int(t["min"]):
			title = t
	officials.append({"name": c["name"], "gender": c.get("gender", "m"), "talent": int(c["talent"]), "title": title["name"]})
	children.remove_at(index)
	prestige += 10 * int(c["talent"])
	changed.emit()
	return _ok("%s lulus ujian dan menjadi %s! Hasil urusan kota +%d%%." % [c["name"], title["name"],
		roundi(float(title["bonus"]) * 100)])


# --- Perjamuan ---------------------------------------------------------------

func banquet_available(kind: String, now: float) -> bool:
	return int(banquet["held"].get(kind, -1)) != day_index(now)


func hold_banquet(kind: String, now: float) -> Dictionary:
	if not Data.BANQUETS.has(kind):
		return _fail("Jenis perjamuan tidak dikenal.")
	var def: Dictionary = Data.BANQUETS[kind]
	if not banquet_available(kind, now):
		return _fail("%s sudah diadakan hari ini." % def["name"])
	for key in def["cost"]:
		if int(get(key)) < int(def["cost"][key]):
			return _fail("%s tidak cukup." % Data.REWARD_NAMES[key].capitalize())
	for key in def["cost"]:
		set(key, int(get(key)) - int(def["cost"][key]))
	banquet["held"][kind] = day_index(now)
	var guests := int(def["guests"]) + (mini(8, _npc_members().size()) if not alliance.is_empty() else 0)
	var gained := int(def["prestige"]) + guests * int(def["per_guest"])
	prestige += gained
	var parts := ["%d tamu hadir" % guests, "+%d prestise" % gained]
	for i in int(def["items"]):
		var item: String = Data.BANQUET_GIFT_ITEMS[rng.randi_range(0, Data.BANQUET_GIFT_ITEMS.size() - 1)]
		add_item(item)
		parts.append(Data.ITEMS[item]["name"])
	if int(def["alliance_exp"]) > 0 and not alliance.is_empty():
		alliance["exp"] = int(alliance["exp"]) + int(def["alliance_exp"])
		parts.append("+%d exp aliansi" % def["alliance_exp"])
	_track("banquet")
	changed.emit()
	return _ok("%s meriah! %s." % [def["name"], ", ".join(parts)])


## Undangan hari ini dari tuan lain (anggota aliansi bila ada).
func banquet_invites(now: float) -> Array:
	var today := day_index(now)
	var r := _seeded(["invite", today, alliance.get("id", "")])
	var out := []
	for i in Data.INVITES_PER_DAY:
		var host := _npc_name(r)
		if not alliance.is_empty():
			host = _npc_members()[r.randi_range(0, _npc_members().size() - 1)]["name"]
		var attended: bool = int(banquet["invite_day"]) == today and i in banquet["attended"]
		out.append({"host": host, "avatar": _npc_avatar(host), "attended": attended})
	return out


func attend_banquet(index: int, now: float) -> Dictionary:
	var invites := banquet_invites(now)
	if index < 0 or index >= invites.size():
		return _fail("Undangan tidak ditemukan.")
	if invites[index]["attended"]:
		return _fail("Anda sudah menghadiri perjamuan ini.")
	if silver < Data.INVITE_GIFT_SILVER:
		return _fail("Perak untuk hadiah tidak cukup (butuh %d)." % Data.INVITE_GIFT_SILVER)
	if int(banquet["invite_day"]) != day_index(now):
		banquet["invite_day"] = day_index(now)
		banquet["attended"] = []
	banquet["attended"].append(index)
	silver -= Data.INVITE_GIFT_SILVER
	prestige += Data.INVITE_PRESTIGE
	changed.emit()
	return _ok("Anda menghadiri perjamuan %s: -%d perak, +%d prestise." % [invites[index]["host"],
		Data.INVITE_GIFT_SILVER, Data.INVITE_PRESTIGE])


# --- Penjara ---------------------------------------------------------------

func _capture_prisoner(info: Dictionary) -> String:
	if prison["prisoners"].size() >= Data.PRISON_CAPACITY or rng.randf() >= Data.PRISON_CAPTURE_CHANCE:
		return ""
	var st := Data.prisoner_stats(stage - 1)
	# "Nama (Kelompok)": kelompok musuh tetap bisa diterjemahkan, nama orang tidak.
	var name := "%s (%s)" % [Data.NPC_NAMES[rng.randi_range(0, Data.NPC_NAMES.size() - 1)], info["enemy_name"]]
	prison["prisoners"].append({"name": name, "avatar": info["enemy_id"], "stage": stage - 1, "hp": st["hp"],
		"max": st["hp"]})
	return name


func prison_left(now: float) -> int:
	if int(prison["day"]) != day_index(now):
		return Data.PRISON_DAILY_LIMIT
	return Data.PRISON_DAILY_LIMIT - int(prison["used"])


## Perkiraan kerusakan interogasi untuk cara tertentu.
func prison_damage(method: String) -> int:
	var m: Dictionary = Data.PRISON_METHODS[method]
	return maxi(1, int(total_attr(m["attr"]) * float(m["factor"])))


func interrogate(index: int, method: String, now: float) -> Dictionary:
	if index < 0 or index >= prison["prisoners"].size():
		return _fail("Tahanan tidak ditemukan.")
	if not Data.PRISON_METHODS.has(method):
		return _fail("Cara interogasi tidak dikenal.")
	if prison_left(now) <= 0:
		return _fail("Batas interogasi hari ini sudah habis.")
	if grain < Data.PRISON_COST_GRAIN:
		return _fail("Pangan tidak cukup (butuh %d)." % Data.PRISON_COST_GRAIN)
	if int(prison["day"]) != day_index(now):
		prison["day"] = day_index(now)
		prison["used"] = 0
	prison["used"] = int(prison["used"]) + 1
	grain -= Data.PRISON_COST_GRAIN
	var p: Dictionary = prison["prisoners"][index]
	var dmg := mini(int(prison_damage(method) * rng.randf_range(0.8, 1.2)), int(p["hp"]))
	p["hp"] = int(p["hp"]) - dmg
	silver += Data.PRISON_HIT_SILVER
	_track("interrogate")
	var msg := "%s: %s -%d daya tahan, +%d perak." % [Data.PRISON_METHODS[method]["name"], p["name"], dmg,
		Data.PRISON_HIT_SILVER]
	var result := _ok(msg)
	result["damage"] = dmg
	if int(p["hp"]) <= 0:
		var st := Data.prisoner_stats(int(p["stage"]))
		silver += int(st["silver"])
		prestige += int(st["prestige"])
		var parts := ["+%d perak" % st["silver"], "+%d prestise" % st["prestige"]]
		if rng.randf() < 0.5:
			var item: String = Data.PRISON_CONFESS_ITEMS[rng.randi_range(0, Data.PRISON_CONFESS_ITEMS.size() - 1)]
			add_item(item)
			parts.append(Data.ITEMS[item]["name"])
		prison["prisoners"].remove_at(index)
		result["msg"] = "%s mengaku! %s." % [p["name"], ", ".join(parts)]
		result["confessed"] = true
	changed.emit()
	return result


func release_prisoner(index: int) -> Dictionary:
	if index < 0 or index >= prison["prisoners"].size():
		return _fail("Tahanan tidak ditemukan.")
	var p: Dictionary = prison["prisoners"][index]
	prison["prisoners"].remove_at(index)
	prestige += Data.PRISON_RELEASE_PRESTIGE
	changed.emit()
	return _ok("%s dibebaskan. Rakyat memuji kemurahan hati Anda: +%d prestise." % [p["name"], Data.PRISON_RELEASE_PRESTIGE])


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
	_last_now = maxf(_last_now, now)
	_track("login")
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
	var chance := minf(0.25 + int(st["intimacy"]) * 0.01, 0.6) + event_bonus("child_chance") + skill_bonus("visit")
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
	return Data.CHILD_TRAIN_GRAIN * (int(children[index]["level"]) + 1)


## Detik sampai anak `index` bisa dididik lagi; 0 = siap.
func train_wait(index: int, now: float) -> int:
	return maxi(0, int(ceil(float(children[index].get("train_t", -1.0e12)) + Data.CHILD_TRAIN_SECONDS - now)))


func train_child(index: int, now := -1.0) -> Dictionary:
	if now < 0.0:
		now = _last_now
	if index < 0 or index >= children.size():
		return _fail("Anak tidak ditemukan.")
	var child: Dictionary = children[index]
	if child["level"] >= Data.CHILD_MAX_LEVEL:
		return _fail("%s sudah dewasa." % child["name"])
	if train_wait(index, now) > 0:
		return _fail("%s masih beristirahat. Didik lagi dalam %d menit." % [
			child["name"], ceili(train_wait(index, now) / 60.0)])
	var cost := train_cost(index)
	if grain < cost:
		return _fail("Pangan tidak cukup (butuh %d)." % cost)
	grain -= cost
	child["train_t"] = now
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


# --- Rencana notifikasi lokal ---------------------------------------------

const NOTIFY_LOGIN_HOUR := 9  ## jam lokal pengingat hadiah login esok hari
const NOTIFY_IDLE_SECONDS := 2 * 86400  ## pengingat bila lama tidak bermain


## Detik sampai charge `key` penuh; 0 bila sudah penuh.
func charge_full_eta(key: String, now: float) -> int:
	var missing := max_charges() - charge_value(key, now)
	if missing <= 0:
		return 0
	return charge_eta(key, now) + (missing - 1) * int(CHARGE_SECONDS)


## Notifikasi yang dijadwalkan saat pemain meninggalkan game:
## [{"id": int, "delay": detik, "title", "text"}]. id tetap per jenis agar
## penjadwalan ulang menimpa yang lama.
func notification_plan(now: float) -> Array:
	var plan := []
	var city := 0
	for key in ["silver", "grain", "soldiers"]:
		city = maxi(city, charge_full_eta(key, now))
	if city > 0:
		plan.append({"id": 1, "delay": city, "title": "Urusan kota penuh",
			"text": "Pajak, sawah, dan prajurit siap dikerjakan, Tuan."})
	var visit := charge_full_eta("visit", now)
	if visit > 0:
		plan.append({"id": 2, "delay": visit, "title": "Energi kunjungan penuh",
			"text": "Para selir menanti kunjungan Tuan di istana."})
	var free := free_pull_eta(now)
	if free > 0:
		plan.append({"id": 3, "delay": free, "title": "Rekrut gratis siap",
			"text": "Satu rekrut penasihat gratis menunggu di Balai Rekrut."})
	var login_at := seconds_until_reset(now) + NOTIFY_LOGIN_HOUR * 3600
	plan.append({"id": 4, "delay": login_at, "title": "Hadiah login menunggu",
		"text": "Ambil hadiah harian dan jaga rangkaian login Tuan."})
	plan.append({"id": 5, "delay": NOTIFY_IDLE_SECONDS, "title": "Kerajaan merindukan Tuan",
		"text": "Rakyat menunggu perintah. Urusan dan hadiah sudah menumpuk."})
	var back := -1
	for i in expeditions.size():
		var eta := expedition_eta(i, now)
		if eta > 0 and (back < 0 or eta < back):
			back = eta
	if back > 0:
		plan.append({"id": 7, "delay": back, "title": "Rombongan ekspedisi kembali",
			"text": "Penasihat Tuan pulang membawa hasil ekspedisi."})
	var build := build_eta(now)
	if build > 0:
		plan.append({"id": 6, "delay": build, "title": "Pembangunan selesai",
			"text": "%s sudah selesai dibangun. Mulai pembangunan berikutnya, Tuan." % Data.BUILDINGS[build_job()["id"]]["name"]})
	return plan


# --- Pusaka (peralatan) ------------------------------------------------------

## Tambah pusaka baru. Kosong bila gudang penuh.
func add_equipment(id: String) -> Dictionary:
	if Data.equip_def(id).is_empty() or equipment.size() >= Data.EQUIP_CAPACITY:
		return {}
	_equip_uid += 1
	var eq := {"uid": _equip_uid, "id": id, "level": 1, "owner": ""}
	equipment.append(eq)
	changed.emit()
	return eq


func equip_find(uid: int) -> Dictionary:
	for eq in equipment:
		if int(eq["uid"]) == uid:
			return eq
	return {}


## Bonus atribut sebuah pusaka pada levelnya sekarang: {"str": 30, ...}
func equip_stats(eq: Dictionary) -> Dictionary:
	var out := {}
	var mult := 1.0 + Data.EQUIP_LEVEL_BONUS * (int(eq["level"]) - 1)
	var attrs: Dictionary = Data.equip_def(eq["id"])["attrs"]
	for k in attrs:
		out[k] = int(round(int(attrs[k]) * mult))
	return out


func equipment_bonus(counselor_id: String, key: String) -> int:
	var total := 0
	for eq in equipment:
		if eq["owner"] == counselor_id:
			total += int(equip_stats(eq).get(key, 0))
	return total


## Pusaka yang dipakai penasihat di slot tertentu (kosong bila tidak ada).
func equipped(counselor_id: String, slot: String) -> Dictionary:
	for eq in equipment:
		if eq["owner"] == counselor_id and Data.equip_def(eq["id"])["slot"] == slot:
			return eq
	return {}


func equip(uid: int, counselor_id: String) -> Dictionary:
	var eq := equip_find(uid)
	if eq.is_empty():
		return _fail("Pusaka tidak ditemukan.")
	if not counselors.has(counselor_id):
		return _fail("Penasihat belum direkrut.")
	var def := Data.equip_def(eq["id"])
	var current := equipped(counselor_id, def["slot"])
	if not current.is_empty():
		current["owner"] = ""
	eq["owner"] = counselor_id
	changed.emit()
	return _ok("%s dipakai oleh %s." % [def["name"], Data.counselor_def(counselor_id)["name"]])


func unequip(uid: int) -> Dictionary:
	var eq := equip_find(uid)
	if eq.is_empty() or eq["owner"] == "":
		return _fail("Pusaka tidak sedang dipakai.")
	eq["owner"] = ""
	changed.emit()
	return _ok("%s dilepas." % Data.equip_def(eq["id"])["name"])


func equip_upgrade_cost(eq: Dictionary) -> int:
	var base: int = Data.EQUIP_UPGRADE_BASE[Data.equip_def(eq["id"])["rarity"]]
	return int(base * pow(int(eq["level"]), 1.6))


func upgrade_equipment(uid: int) -> Dictionary:
	var eq := equip_find(uid)
	if eq.is_empty():
		return _fail("Pusaka tidak ditemukan.")
	if int(eq["level"]) >= Data.EQUIP_MAX_LEVEL:
		return _fail("Pusaka sudah level maksimal.")
	var cost := equip_upgrade_cost(eq)
	if silver < cost:
		return _fail("Perak tidak cukup (butuh %d)." % cost)
	silver -= cost
	eq["level"] = int(eq["level"]) + 1
	_track("equip_upgrade")
	changed.emit()
	return _ok("%s naik ke +%d." % [Data.equip_def(eq["id"])["name"], int(eq["level"]) - 1])


func equip_salvage_value(eq: Dictionary) -> int:
	var rarity: String = Data.equip_def(eq["id"])["rarity"]
	var spent := 0
	for lv in range(1, int(eq["level"])):
		spent += int(Data.EQUIP_UPGRADE_BASE[rarity] * pow(lv, 1.6))
	return int(Data.EQUIP_SALVAGE_BASE[rarity] + spent * Data.EQUIP_SALVAGE_REFUND)


func salvage_equipment(uid: int) -> Dictionary:
	var eq := equip_find(uid)
	if eq.is_empty():
		return _fail("Pusaka tidak ditemukan.")
	var value := equip_salvage_value(eq)
	silver += value
	equipment.erase(eq)
	changed.emit()
	return _ok("%s dilebur: +%d perak." % [Data.equip_def(eq["id"])["name"], value])


# --- Menara Ujian -------------------------------------------------------------

func tower_unlocked() -> bool:
	return stage >= Data.TOWER_UNLOCK_STAGE


## Reset kemajuan mingguan dan percobaan harian bila perlu.
func ensure_tower(now: float) -> void:
	if tower.is_empty():
		tower = {"week": week_index(now), "floor": 0, "best": 0, "day": day_index(now), "attempts": 0}
	if int(tower["week"]) != week_index(now):
		tower["week"] = week_index(now)
		tower["floor"] = 0
	if int(tower["day"]) != day_index(now):
		tower["day"] = day_index(now)
		tower["attempts"] = 0


func tower_attempts_left(now: float) -> int:
	ensure_tower(now)
	return maxi(0, Data.TOWER_ATTEMPTS + int(vip_perk("arena_tickets")) - int(tower["attempts"]))


func tower_win_chance(level: int) -> float:
	var a := pow(float(maxi(1, combat_power())), 3.0)
	var b := pow(float(maxi(1, Data.tower_floor(level)["power"])), 3.0)
	return a / (a + b)


## Lawan lantai berikutnya. Menang naik satu lantai dan mendapat hadiahnya;
## kalah hanya memakai percobaan.
func tower_fight(now: float) -> Dictionary:
	if not tower_unlocked():
		return _fail("Menangkan Tahap %d untuk membuka Menara Ujian." % Data.TOWER_UNLOCK_STAGE)
	if tower_attempts_left(now) <= 0:
		return _fail("Percobaan menara hari ini habis. Kembali besok!")
	var level := int(tower["floor"]) + 1
	var info := Data.tower_floor(level)
	tower["attempts"] = int(tower["attempts"]) + 1
	_track("tower")
	var win := rng.randf() < tower_win_chance(level)
	if not win:
		changed.emit()
		var lost := _fail("Gagal di lantai %d. Perkuat penasihat lalu coba lagi." % level)
		lost["win"] = false
		return lost
	tower["floor"] = level
	tower["best"] = maxi(int(tower["best"]), level)
	silver += int(info["silver"])
	gold += int(info["gold"])
	var parts := ["+%d perak" % info["silver"], "+%d emas" % info["gold"]]
	if info["equip"]:
		var eq := add_equipment(Data.equip_roll(level * 4 + (60 if info["rare"] else 0), rng.randf(), rng.randf()))
		if not eq.is_empty():
			parts.append(Data.equip_def(eq["id"])["name"])
	_track("tower_win")
	changed.emit()
	var r := _ok("Lantai %d ditaklukkan! %s." % [level, ", ".join(parts)])
	r["win"] = true
	return r


# --- Bangunan kota ------------------------------------------------------------

func building_level(id: String) -> int:
	return int(buildings.get("levels", {}).get(id, 0))


func building_cap(id: String) -> int:
	if id == "istana":
		return Data.keraton_cap(rank)
	return mini(Data.BUILDING_MAX_LEVEL, building_level("istana"))


func building_cost(id: String) -> int:
	var def: Dictionary = Data.BUILDINGS[id]
	return int(float(def["cost_base"]) * pow(float(def["cost_growth"]), building_level(id)))


func build_seconds(id: String) -> int:
	return int(Data.BUILD_SECONDS_BASE * pow(Data.BUILD_SECONDS_GROWTH, building_level(id)))


## Total bonus suatu efek dari semua bangunan.
func building_bonus(effect: String) -> float:
	var total := 0.0
	for id in Data.BUILDINGS:
		if Data.BUILDINGS[id]["effect"] == effect:
			total += float(Data.BUILDINGS[id]["per_level"]) * building_level(id)
	return total


func build_job() -> Dictionary:
	return buildings.get("job", {})


func build_eta(now: float) -> int:
	var job := build_job()
	return maxi(0, int(ceil(float(job["end_t"]) - now))) if not job.is_empty() else 0


func start_build(id: String, now: float) -> Dictionary:
	if not Data.BUILDINGS.has(id):
		return _fail("Bangunan tidak dikenal.")
	finish_build(now)
	var name: String = Data.BUILDINGS[id]["name"]
	if not build_job().is_empty():
		return _fail("Tukang sedang membangun %s. Tunggu sampai selesai." % Data.BUILDINGS[build_job()["id"]]["name"])
	if building_level(id) >= Data.BUILDING_MAX_LEVEL:
		return _fail("%s sudah mencapai level tertinggi." % name)
	if building_level(id) >= building_cap(id):
		if id == "istana":
			return _fail("Naikkan jabatan untuk memperluas Keraton.")
		return _fail("Tingkatkan Keraton dulu agar %s bisa naik level." % name)
	var cost := building_cost(id)
	if silver < cost:
		return _fail("Perak tidak cukup (butuh %d)." % cost)
	silver -= cost
	buildings["job"] = {"id": id, "end_t": now + build_seconds(id)}
	changed.emit()
	return _ok("Pembangunan %s ke level %d dimulai." % [name, building_level(id) + 1])


## Selesaikan pembangunan bila waktunya sudah lewat. Mengembalikan true bila selesai.
func finish_build(now: float) -> bool:
	var job := build_job()
	if job.is_empty() or now < float(job["end_t"]):
		return false
	var id: String = job["id"]
	buildings["levels"][id] = building_level(id) + 1
	buildings["job"] = {}
	_track("build")
	return true


func rush_cost(now: float) -> int:
	return int(ceil(float(build_eta(now)) / Data.BUILD_RUSH_SECONDS_PER_GOLD))


func rush_build(now: float) -> Dictionary:
	var job := build_job()
	if job.is_empty():
		return _fail("Tidak ada pembangunan yang berjalan.")
	var cost := rush_cost(now)
	if gold < cost:
		return _fail("Emas tidak cukup (butuh %d)." % cost)
	gold -= cost
	var id: String = job["id"]
	buildings["job"]["end_t"] = now
	finish_build(now)
	changed.emit()
	return _ok("%s selesai dibangun: level %d!" % [Data.BUILDINGS[id]["name"], building_level(id)])


# --- Ekspedisi ------------------------------------------------------------------

func expedition_unlocked() -> bool:
	return stage >= Data.EXPEDITION_UNLOCK_STAGE


func expedition_slots() -> int:
	return Data.EXPEDITION_SLOTS + (1 if rank >= Data.EXPEDITION_EXTRA_SLOT_RANK else 0)


func expedition_def(id: String) -> Dictionary:
	for d in Data.EXPEDITIONS:
		if d["id"] == id:
			return d
	return {}


func expedition_busy(counselor_id: String) -> bool:
	return expeditions.any(func(e): return e["counselor"] == counselor_id)


## Pengali hadiah dari atribut penasihat dibanding rata-rata penasihat Anda (0.6–2.0).
func expedition_mult(dest: Dictionary, counselor_id: String) -> float:
	if not counselors.has(counselor_id):
		return 0.0
	var key: String = dest["attr"]
	var avg := float(total_attr(key) - (total_intimacy() if key == "cha" else 0)) / maxi(1, counselors.size())
	return clampf(0.6 + 0.4 * attr(counselor_id, key) / maxf(1.0, avg), 0.6, 2.0)


## Perkiraan hadiah sumber daya (tanpa emas & item acak) untuk ditampilkan sebelum berangkat.
func expedition_preview(dest: Dictionary, counselor_id: String) -> Dictionary:
	var mult := expedition_mult(dest, counselor_id)
	var out := {}
	for key in dest["yields"]:
		out[key] = int(affair_yield(key) * float(dest["yields"][key]) * mult)
	return out


func send_expedition(dest_id: String, counselor_id: String, now: float) -> Dictionary:
	if not expedition_unlocked():
		return _fail("Menangkan Tahap %d untuk membuka Ekspedisi." % Data.EXPEDITION_UNLOCK_STAGE)
	var dest := expedition_def(dest_id)
	if dest.is_empty():
		return _fail("Tujuan tidak dikenal.")
	if stage < int(dest["stage"]):
		return _fail("%s terbuka setelah Tahap %d." % [dest["name"], dest["stage"]])
	if not counselors.has(counselor_id):
		return _fail("Penasihat belum direkrut.")
	if expedition_busy(counselor_id):
		return _fail("%s sedang dalam ekspedisi." % Data.counselor_def(counselor_id)["name"])
	if expeditions.size() >= expedition_slots():
		return _fail("Semua rombongan ekspedisi sedang berangkat.")
	# Hadiah ditentukan saat berangkat agar tidak berubah saat game dibuka ulang.
	var reward := expedition_preview(dest, counselor_id)
	var gold_range: Array = dest["gold"]
	reward["gold"] = rng.randi_range(int(gold_range[0]), int(gold_range[1]))
	var items := {}
	var equip := ""
	for entry in dest["items"]:
		if rng.randf() >= float(entry[1]):
			continue
		if entry[0] == "equip":
			equip = Data.equip_roll(stage, rng.randf(), rng.randf())
		else:
			items[entry[0]] = int(items.get(entry[0], 0)) + 1
	if not items.is_empty():
		reward["items"] = items
	if equip != "":
		reward["equip"] = equip
	expeditions.append({"dest": dest_id, "counselor": counselor_id,
		"end_t": now + float(dest["hours"]) * 3600.0, "reward": reward})
	changed.emit()
	return _ok("%s berangkat ke %s. Kembali dalam %d jam." % [Data.counselor_def(counselor_id)["name"], dest["name"],
		dest["hours"]])


func expedition_eta(index: int, now: float) -> int:
	return maxi(0, int(ceil(float(expeditions[index]["end_t"]) - now)))


func expeditions_ready(now: float) -> int:
	return expeditions.filter(func(e): return now >= float(e["end_t"])).size()


func claim_expedition(index: int, now: float) -> Dictionary:
	if index < 0 or index >= expeditions.size():
		return _fail("Ekspedisi tidak ditemukan.")
	var e: Dictionary = expeditions[index]
	if now < float(e["end_t"]):
		return _fail("Rombongan belum kembali.")
	expeditions.remove_at(index)
	var reward: Dictionary = e["reward"]
	var parts := []
	var text := _give_rewards(reward)
	if text != "":
		parts.append(text)
	if reward.has("equip"):
		var eq := add_equipment(str(reward["equip"]))
		if not eq.is_empty():
			parts.append(Data.equip_def(eq["id"])["name"])
	_track("expedition")
	changed.emit()
	return _ok("%s kembali dari %s: %s." % [Data.counselor_def(e["counselor"])["name"],
		expedition_def(e["dest"])["name"], ", ".join(parts)])


func claim_all_expeditions(now: float) -> Dictionary:
	var msgs := []
	for i in range(expeditions.size() - 1, -1, -1):
		var r := claim_expedition(i, now)
		if r["ok"]:
			msgs.append(r["msg"])
	if msgs.is_empty():
		return _fail("Belum ada rombongan yang kembali.")
	return _ok(" ".join(msgs))


# --- Festival musiman ---------------------------------------------------------

## Unix time tengah malam waktu lokal pemain untuk tanggal tertentu.
func _local_midnight(y: int, m: int, d: int) -> float:
	return Time.get_unix_time_from_datetime_dict({"year": y, "month": m, "day": d, "hour": 0, "minute": 0,
		"second": 0}) - tz_bias


## Rentang festival yang mungkin berlaku di sekitar tahun `year`: [{def, key, start_t, end_t}].
func _festival_windows(year: int) -> Array:
	var out := []
	for def in Data.FESTIVALS:
		for y in [year - 1, year]:
			var a: Array
			var b: Array
			var end_year: int = y
			if def.has("dates"):
				if not def["dates"].has(y):
					continue
				a = def["dates"][y][0]
				b = def["dates"][y][1]
			else:
				a = def["start"]
				b = def["end"]
				if int(b[0]) < int(a[0]):
					end_year = y + 1
			out.append({"def": def, "key": "%s-%d" % [def["id"], y],
				"start_t": _local_midnight(y, int(a[0]), int(a[1])),
				"end_t": _local_midnight(end_year, int(b[0]), int(b[1])) + 86400.0})
	return out


func _local_year(now: float) -> int:
	return int(Time.get_date_dict_from_unix_time(int(now + tz_bias))["year"])


## Festival yang berlangsung pada `now` (def + key, start_t, end_t), atau {}.
func festival_at(now: float) -> Dictionary:
	for w in _festival_windows(_local_year(now)):
		if now >= float(w["start_t"]) and now < float(w["end_t"]):
			return w
	return {}


## Festival berikutnya setelah `now` (untuk pengumuman "segera hadir").
func next_festival(now: float) -> Dictionary:
	var year := _local_year(now)
	var best := {}
	for w in _festival_windows(year) + _festival_windows(year + 1):
		if float(w["start_t"]) > now and (best.is_empty() or float(w["start_t"]) < float(best["start_t"])):
			best = w
	return best


## Mulai festival baru atau akhiri yang sudah lewat (token festival hangus).
func ensure_festival(now: float) -> bool:
	var w := festival_at(now)
	var key: String = w.get("key", "")
	if key == str(festival.get("key", "")):
		return false
	if key == "":
		festival = {}
	else:
		festival = {"key": key, "id": w["def"]["id"], "progress": {}, "claimed": [], "tokens": 0, "bought": {},
			"gift_day": -1}
	changed.emit()
	return true


func festival_def() -> Dictionary:
	for def in Data.FESTIVALS:
		if def["id"] == festival.get("id", ""):
			return def
	return {}


func festival_seconds_left(now: float) -> int:
	var w := festival_at(now)
	return maxi(0, int(float(w["end_t"]) - now)) if not w.is_empty() else 0


func festival_task_progress(id: String) -> int:
	return int(festival.get("progress", {}).get(id, 0))


func festival_task_claimable(t: Dictionary) -> bool:
	return not festival.is_empty() and festival_task_progress(t["id"]) >= int(t["target"]) \
		and not festival["claimed"].has(t["id"])


func festival_claimable_count(now: float) -> int:
	ensure_festival(now)
	if festival.is_empty():
		return 0
	var n := 1 if festival_gift_can_claim(now) else 0
	for t in Data.FESTIVAL_TASKS:
		if festival_task_claimable(t):
			n += 1
	return n


func claim_festival_task(id: String, now: float) -> Dictionary:
	ensure_festival(now)
	if festival.is_empty():
		return _fail("Tidak ada festival yang sedang berlangsung.")
	for t in Data.FESTIVAL_TASKS:
		if t["id"] != id:
			continue
		if festival["claimed"].has(id):
			return _fail("Hadiah tugas sudah diambil.")
		if festival_task_progress(id) < int(t["target"]):
			return _fail("Tugas festival belum selesai.")
		festival["claimed"].append(id)
		festival["tokens"] = int(festival["tokens"]) + int(t["tokens"])
		changed.emit()
		return _ok("+%d %s" % [t["tokens"], festival_def()["token"]])
	return _fail("Tugas tidak ditemukan.")


func festival_gift_can_claim(now: float) -> bool:
	return not festival.is_empty() and int(festival["gift_day"]) != day_index(now)


func claim_festival_gift(now: float) -> Dictionary:
	ensure_festival(now)
	if not festival_gift_can_claim(now):
		return _fail("Hadiah festival hari ini sudah diambil.")
	festival["gift_day"] = day_index(now)
	festival["tokens"] = int(festival["tokens"]) + Data.FESTIVAL_GIFT
	changed.emit()
	return _ok("Hadiah festival: +%d %s" % [Data.FESTIVAL_GIFT, festival_def()["token"]])


func festival_shop_left(id: String) -> int:
	for item in Data.FESTIVAL_SHOP:
		if item["id"] == id:
			var left := int(item["limit"]) - int(festival.get("bought", {}).get(id, 0))
			if item["reward"].has("frame") and owns_cosmetic("frame_" + str(festival.get("id", ""))):
				left = 0
			return maxi(0, left)
	return 0


func festival_buy(id: String, now: float) -> Dictionary:
	ensure_festival(now)
	if festival.is_empty():
		return _fail("Tidak ada festival yang sedang berlangsung.")
	var item := {}
	for it in Data.FESTIVAL_SHOP:
		if it["id"] == id:
			item = it
	if item.is_empty():
		return _fail("Barang tidak ditemukan.")
	if festival_shop_left(id) <= 0:
		return _fail("Batas pembelian festival sudah habis.")
	if int(festival["tokens"]) < int(item["cost"]):
		return _fail("%s tidak cukup (butuh %d)." % [festival_def()["token"], item["cost"]])
	festival["tokens"] = int(festival["tokens"]) - int(item["cost"])
	festival["bought"][id] = int(festival["bought"].get(id, 0)) + 1
	var reward: Dictionary = item["reward"]
	var text := ""
	if reward.has("equip"):
		# Pusaka festival: peluang langka setara tahap sangat jauh.
		var eq := add_equipment(Data.equip_roll(150, rng.randf() * 0.5, rng.randf()))
		text = Data.equip_def(eq["id"])["name"] if not eq.is_empty() else ""
	elif reward.has("frame"):
		var cid: String = "frame_" + str(festival["id"])
		unlock_cosmetic(cid)
		text = Data.COSMETICS[cid]["name"]
	else:
		text = _give_rewards(reward)
	changed.emit()
	return _ok("Membeli %s: %s." % [item["name"], text])


# --- Kosmetik ---------------------------------------------------------------

func owns_cosmetic(id: String) -> bool:
	return cosmetics.get("owned", []).has(id)


func unlock_cosmetic(id: String) -> bool:
	if not Data.COSMETICS.has(id) or owns_cosmetic(id):
		return false
	cosmetics["owned"].append(id)
	changed.emit()
	return true


## Buka kosmetik yang syaratnya (jabatan, VIP, tahap) sudah terpenuhi. Mengembalikan id baru.
func check_cosmetic_unlocks() -> Array:
	var got := []
	for id in Data.COSMETIC_ORDER:
		var u := str(Data.COSMETICS[id].get("unlock", ""))
		var ok := false
		if u.begins_with("rank:"):
			ok = rank >= int(u.substr(5))
		elif u.begins_with("vip:"):
			ok = vip_level() >= int(u.substr(4))
		elif u.begins_with("stage:"):
			ok = stage >= int(u.substr(6))
		if ok and unlock_cosmetic(id):
			got.append(id)
	return got


func buy_cosmetic(id: String) -> Dictionary:
	var def: Dictionary = Data.COSMETICS.get(id, {})
	if def.is_empty():
		return _fail("Kosmetik tidak ditemukan.")
	if owns_cosmetic(id):
		return _fail("Sudah dimiliki.")
	if int(def.get("gold", 0)) <= 0:
		return _fail("Kosmetik ini tidak dijual dengan emas.")
	if gold < int(def["gold"]):
		return _fail("Emas tidak cukup (butuh %d)." % def["gold"])
	gold -= int(def["gold"])
	unlock_cosmetic(id)
	wear_cosmetic(id)
	return _ok("%s didapat!" % def["name"])


func wear_cosmetic(id: String) -> Dictionary:
	if not owns_cosmetic(id):
		return _fail("Kosmetik belum dimiliki.")
	var def: Dictionary = Data.COSMETICS[id]
	cosmetics[def["type"]] = id
	changed.emit()
	return _ok("%s dipakai." % def["name"])


## Potret Tuan sesuai kostum yang dipakai.
func lord_portrait() -> String:
	return str(Data.COSMETICS.get(cosmetics.get("costume", ""), {}).get("portrait", "lord"))


func frame_colors() -> Array:
	return Data.COSMETICS.get(cosmetics.get("frame", ""), Data.COSMETICS["frame_kayu"])["colors"]

# --- Pencapaian --------------------------------------------------------------

func achievement_value(def: Dictionary) -> int:
	var metric: String = def["metric"]
	if metric.begins_with("count:"):
		return int(counters.get(metric.substr(6), 0))
	return story_metric(metric)


## Jumlah tingkat yang sudah tercapai.
func achievement_tier(def: Dictionary) -> int:
	var value := achievement_value(def)
	var n := 0
	for target in def["targets"]:
		if value >= int(target):
			n += 1
	return n


func achievement_claimable(def: Dictionary) -> bool:
	return achievement_tier(def) > int(achievements.get(def["id"], 0))


func achievements_claimable_count() -> int:
	return Data.ACHIEVEMENTS.filter(func(a): return achievement_claimable(a)).size()


func claim_achievement(id: String) -> Dictionary:
	var def := {}
	for a in Data.ACHIEVEMENTS:
		if a["id"] == id:
			def = a
	if def.is_empty():
		return _fail("Pencapaian tidak ditemukan.")
	if not achievement_claimable(def):
		return _fail("Belum ada tingkat baru untuk diklaim.")
	var tier := int(achievements.get(id, 0))
	achievements[id] = tier + 1
	var reward: int = Data.ACHIEVEMENT_GOLD[mini(tier, Data.ACHIEVEMENT_GOLD.size() - 1)]
	gold += reward
	changed.emit()
	return _ok("Pencapaian %s tingkat %d: +%d emas." % [def["name"], tier + 1, reward])


## Periksa tingkat baru yang tercapai (dipanggil UI tiap detik, hanya memancarkan
## sinyal sekali per tingkat; status "sudah dilaporkan" tidak perlu disimpan karena
## Google Play Games mengabaikan pembukaan ulang).
var _reported := {}


func check_achievements() -> void:
	for a in Data.ACHIEVEMENTS:
		var tier := achievement_tier(a)
		if tier > int(_reported.get(a["id"], 0)):
			for t in range(int(_reported.get(a["id"], 0)) + 1, tier + 1):
				achievement_reached.emit(a["id"], t)
			_reported[a["id"]] = tier


# --- Paket terbatas waktu ------------------------------------------------------

func _create_offer(id: String, reward: Dictionary, now: float) -> void:
	if not active_offer(id, now).is_empty():
		return  # satu paket per jenis sampai berakhir
	var offer := {"id": id, "expires": now + float(Data.OFFER_SECONDS[id]), "reward": reward}
	offers.append(offer)
	offer_created.emit(offer)


## Paket aktif (belum kedaluwarsa) untuk produk ini, atau kosong.
func active_offer(id: String, now: float) -> Dictionary:
	for o in offers:
		if o["id"] == id and float(o["expires"]) > now:
			return o
	return {}


func active_offers(now: float) -> Array:
	offers = offers.filter(func(o): return float(o["expires"]) > now)
	return offers


# --- Tiket Musim (battle pass) ----------------------------------------------

func pass_season(now: float) -> int:
	return day_index(now) / Data.PASS_DAYS


func pass_days_left(now: float) -> int:
	return (pass_season(now) + 1) * Data.PASS_DAYS - day_index(now)


## Mulai musim baru bila perlu (hadiah musim lalu yang belum diklaim hangus).
func ensure_pass(now: float) -> void:
	if season_pass.is_empty() or int(season_pass["season"]) != pass_season(now):
		season_pass = {"season": pass_season(now), "xp": 0, "premium": false, "free": [], "paid": []}


func add_pass_xp(amount: int) -> void:
	ensure_pass(_last_now)
	season_pass["xp"] = mini(int(season_pass["xp"]) + amount, Data.PASS_TIERS * Data.PASS_XP_PER_TIER)


func pass_tier() -> int:
	return mini(Data.PASS_TIERS, int(season_pass.get("xp", 0)) / Data.PASS_XP_PER_TIER)


func pass_can_claim(tier: int, premium: bool) -> bool:
	if tier < 1 or tier > pass_tier() or (premium and not season_pass.get("premium", false)):
		return false
	return not tier in season_pass["paid" if premium else "free"]


func pass_claimable_count(now: float) -> int:
	ensure_pass(now)
	var n := 0
	for t in range(1, Data.PASS_TIERS + 1):
		for premium in [false, true]:
			if pass_can_claim(t, premium):
				n += 1
	return n


func claim_pass(tier: int, premium: bool, now: float) -> Dictionary:
	ensure_pass(now)
	if premium and not season_pass["premium"]:
		return _fail("Beli Tiket Musim Premium untuk membuka jalur ini.")
	if not pass_can_claim(tier, premium):
		return _fail("Hadiah tingkat %d belum bisa diklaim." % tier)
	season_pass["paid" if premium else "free"].append(tier)
	var text := _give_pass_reward(Data.pass_reward(tier, premium))
	changed.emit()
	return _ok("Tiket Musim tingkat %d: %s." % [tier, text])


## Klaim semua hadiah yang tersedia sekaligus.
func claim_pass_all(now: float) -> Dictionary:
	ensure_pass(now)
	var parts := []
	for t in range(1, Data.PASS_TIERS + 1):
		for premium in [false, true]:
			if pass_can_claim(t, premium):
				season_pass["paid" if premium else "free"].append(t)
				parts.append(_give_pass_reward(Data.pass_reward(t, premium)))
	if parts.is_empty():
		return _fail("Belum ada hadiah Tiket Musim yang bisa diklaim.")
	changed.emit()
	return _ok("Tiket Musim: %d hadiah diklaim." % parts.size())


func _give_pass_reward(def: Dictionary) -> String:
	var text := _give_rewards(def)
	if def.has("equip"):
		var eq := add_equipment(def["equip"])
		if not eq.is_empty():
			text += (", " if text != "" else "") + Data.equip_def(def["equip"])["name"]
	return text


# --- Iklan berhadiah -----------------------------------------------------------

func ad_left(kind: String, now: float) -> int:
	var def: Dictionary = Data.AD_REWARDS.get(kind, {})
	if def.is_empty():
		return 0
	if int(ads.get("day", -1)) != day_index(now):
		ads = {"day": day_index(now), "counts": {}}
	return maxi(0, int(def["limit"]) - int(ads["counts"].get(kind, 0)))


## Berikan hadiah setelah iklan selesai ditonton (dipanggil oleh autoload Ads).
func grant_ad_reward(kind: String, now: float) -> Dictionary:
	if ad_left(kind, now) <= 0:
		return _fail("Batas iklan hadiah hari ini sudah habis.")
	ads["counts"][kind] = int(ads["counts"].get(kind, 0)) + 1
	var text := ""
	if kind == "refill":
		for key in CHARGE_KEYS:
			charges[key] = {"value": max_charges(), "t": now}
		text = "semua urusan dan energi terisi penuh"
	else:
		text = _give_rewards(Data.AD_REWARDS[kind]["reward"])
	_track("ad")
	changed.emit()
	return _ok("Terima kasih telah menonton! Hadiah: %s." % text)


# --- Nama Tuan -------------------------------------------------------------

const NAME_MIN := 2
const NAME_MAX := 16


## Nama yang tampil di daftar (anggota, arena, peringkat).
func me_name() -> String:
	return lord_name if lord_name != "" else "Anda"


static func _clean_name(raw: String) -> String:
	var out := ""
	for ch in raw.strip_edges():
		# huruf, angka, spasi, dan sedikit tanda baca saja
		if ch == " " or ch in "-_.'" or ch.to_upper() != ch.to_lower() or ch.is_valid_int():
			out += ch
	while "  " in out:
		out = out.replace("  ", " ")
	return out.substr(0, NAME_MAX).strip_edges()


func set_lord_name(raw: String) -> Dictionary:
	var name := _clean_name(raw)
	if name.length() < NAME_MIN:
		return _fail("Nama minimal %d huruf (huruf, angka, spasi)." % NAME_MIN)
	if name == lord_name:
		return _fail("Nama tidak berubah.")
	lord_name = name
	changed.emit()
	return _ok("Mulai sekarang Anda dikenal sebagai %s." % name)


# --- Ringkasan saat kembali ----------------------------------------------

## Minimal lama pergi (detik) sebelum ringkasan "Selamat datang kembali" muncul.
const AWAY_MIN_SECONDS := 300.0
const AWAY_CHARGE_NAMES := {"silver": "Tarik Pajak", "grain": "Kelola Sawah",
	"soldiers": "Rekrut Prajurit", "visit": "Energi kunjungan"}


## Potret keadaan saat pemain pergi; dibandingkan dengan away_report() nanti.
func away_snapshot(now: float) -> Dictionary:
	var ch := {}
	for key in CHARGE_KEYS:
		ch[key] = charge_value(key, now)
	return {
		"t": now, "charges": ch, "free": free_pull_eta(now) == 0, "day": day_index(now),
		"week": week_index(now), "unread": chat_unread(now),
		"war_reward": not war_reward.is_empty(),
		"season": not arena.is_empty() and not arena.get("season_reward", {}).is_empty(),
		"lb_reward": not leaderboard.get("reward", {}).is_empty(),
		"exp_ready": expeditions_ready(now), "building": build_job().get("id", ""),
		"building_level": building_level(build_job().get("id", "istana")),
	}


## Daftar hal yang terjadi selama pemain pergi: [{"icon", "text"}].
## Kosong bila pergi kurang dari AWAY_MIN_SECONDS atau snapshot tidak valid.
func away_report(snap: Dictionary, now: float) -> Dictionary:
	if snap.is_empty():
		return {}
	var away := now - float(snap.get("t", now))
	if away < AWAY_MIN_SECONDS:
		return {}
	var lines := []
	var cap := max_charges()
	var refilled := []
	for key in CHARGE_KEYS:
		var before := int(snap.get("charges", {}).get(key, cap))
		var after := charge_value(key, now)
		if after > before:
			refilled.append("%s +%d%s" % [AWAY_CHARGE_NAMES[key], after - before, " (penuh)" if after >= cap else ""])
	if not refilled.is_empty():
		lines.append({"icon": "tab_city", "text": "Urusan terisi kembali: %s." % ", ".join(refilled)})
	if free_pull_eta(now) == 0 and not bool(snap.get("free", false)):
		lines.append({"icon": "ticket_recruit", "text": "Rekrut gratis sudah siap."})
	if day_index(now) != int(snap.get("day", day_index(now))):
		lines.append({"icon": "mission", "text": "Hari baru: misi harian dan batas harian telah direset."})
		if login_can_claim(now):
			lines.append({"icon": "calendar", "text": "Hadiah login hari ini menunggu."})
	if week_index(now) != int(snap.get("week", week_index(now))):
		lines.append({"icon": event_def()["icon"], "text": "Event mingguan baru dimulai: %s." % event_def()["name"]})
	var unread := chat_unread(now)
	if unread > int(snap.get("unread", 0)):
		lines.append({"icon": "tab_alliance", "text": "%d pesan baru di chat aliansi." % unread})
	if not war_reward.is_empty() and not bool(snap.get("war_reward", false)):
		lines.append({"icon": "fort", "text": "Perang guild melawan %s berakhir: %s! Ambil hadiahnya." % [
			war_reward.get("enemy", "musuh"), "MENANG" if war_reward.get("win", false) else "kalah"]})
	var season: bool = not arena.is_empty() and not arena.get("season_reward", {}).is_empty()
	if season and not bool(snap.get("season", false)):
		lines.append({"icon": "trophy", "text": "Musim arena selesai. Hadiah liga siap diklaim."})
	if not leaderboard.get("reward", {}).is_empty() and not bool(snap.get("lb_reward", false)):
		lines.append({"icon": "gold_crown", "text": "Peringkat global minggu lalu sudah keluar. Ambil hadiahnya."})
	var built := str(snap.get("building", ""))
	if Data.BUILDINGS.has(built) and building_level(built) > int(snap.get("building_level", 0)):
		lines.append({"icon": Data.BUILDINGS[built]["icon"], "text": "Pembangunan %s selesai: level %d." % [
			Data.BUILDINGS[built]["name"], building_level(built)]})
	if expeditions_ready(now) > int(snap.get("exp_ready", 0)):
		lines.append({"icon": "exp_hutan", "text": "%d rombongan ekspedisi sudah kembali." % expeditions_ready(now)})
	if lines.is_empty():
		lines.append({"icon": "tab_city", "text": "Kerajaan aman. Semua urusan menunggu perintah Tuan."})
	return {"seconds": int(away), "lines": lines}


# --- Kode cadangan ----------------------------------------------------------

const SAVE_CODE_PREFIX := "TLG1:"


## Ubah data save (hasil to_dict) menjadi teks pendek yang bisa disalin:
## JSON -> gzip -> base64, dengan awalan versi.
static func encode_save(data: Dictionary) -> String:
	var raw := JSON.stringify(data).to_utf8_buffer()
	return SAVE_CODE_PREFIX + Marshalls.raw_to_base64(raw.compress(FileAccess.COMPRESSION_GZIP))


## Kebalikan encode_save. Kosong bila kode tidak valid atau bukan save game ini.
static func decode_save(code: String) -> Dictionary:
	code = code.strip_edges().replace("\n", "").replace(" ", "")
	if not code.begins_with(SAVE_CODE_PREFIX):
		return {}
	var packed := Marshalls.base64_to_raw(code.substr(SAVE_CODE_PREFIX.length()))
	if packed.is_empty():
		return {}
	var raw := packed.decompress_dynamic(32 * 1024 * 1024, FileAccess.COMPRESSION_GZIP)
	if raw.is_empty():
		return {}
	var data = JSON.parse_string(raw.get_string_from_utf8())
	if not (data is Dictionary) or not data.has("version") or not data.has("counselors"):
		return {}
	return data


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
		"rateup_guarantee": rateup_guarantee,
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
		"prison": prison,
		"officials": officials,
		"story": story,
		"banquet": banquet,
		"start_day": start_day,
		"leaderboard": leaderboard,
		"lord_name": lord_name,
		"equipment": equipment,
		"tower": tower,
		"ads": ads,
		"pass": season_pass,
		"offers": offers,
		"counters": counters,
		"achievements": achievements,
		"loss_streak": loss_streak,
		"equip_uid": _equip_uid,
		"formation": formation,
		"festival": festival,
		"buildings": buildings,
		"expeditions": expeditions,
		"cosmetics": cosmetics,
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
	rateup_guarantee = bool(d.get("rateup_guarantee", false))
	formation = str(d.get("formation", "balanced"))
	var src_fest: Dictionary = d.get("festival", {})
	if not src_fest.is_empty():
		festival = {"key": str(src_fest.get("key", "")), "id": str(src_fest.get("id", "")), "progress": {},
			"claimed": [], "tokens": int(src_fest.get("tokens", 0)), "bought": {},
			"gift_day": int(src_fest.get("gift_day", -1))}
		for k in src_fest.get("progress", {}):
			festival["progress"][str(k)] = int(src_fest["progress"][k])
		for k in src_fest.get("bought", {}):
			festival["bought"][str(k)] = int(src_fest["bought"][k])
		for v in src_fest.get("claimed", []):
			festival["claimed"].append(str(v))
	var src_bld: Dictionary = d.get("buildings", {})
	for id in Data.BUILDINGS:
		buildings["levels"][id] = clampi(int(src_bld.get("levels", {}).get(id, buildings["levels"][id])), 0,
			Data.BUILDING_MAX_LEVEL)
	var src_job: Dictionary = src_bld.get("job", {})
	if Data.BUILDINGS.has(str(src_job.get("id", ""))):
		buildings["job"] = {"id": str(src_job["id"]), "end_t": float(src_job.get("end_t", now))}
	for e in d.get("expeditions", []):
		if not (e is Dictionary) or expedition_def(str(e.get("dest", ""))).is_empty() \
				or Data.counselor_def(str(e.get("counselor", ""))).is_empty():
			continue
		var r := {}
		var src_r: Dictionary = e.get("reward", {})
		for key in Data.REWARD_KEYS:
			if src_r.has(key):
				r[key] = int(src_r[key])
		if src_r.has("items"):
			r["items"] = {}
			for id in src_r["items"]:
				if Data.ITEMS.has(id):
					r["items"][str(id)] = int(src_r["items"][id])
		if not Data.equip_def(str(src_r.get("equip", ""))).is_empty():
			r["equip"] = str(src_r["equip"])
		expeditions.append({"dest": str(e["dest"]), "counselor": str(e["counselor"]),
			"end_t": float(e.get("end_t", now)), "reward": r})
	var src_cos: Dictionary = d.get("cosmetics", {})
	for id in src_cos.get("owned", []):
		unlock_cosmetic(str(id))
	for slot in ["frame", "costume"]:
		var worn := str(src_cos.get(slot, ""))
		if owns_cosmetic(worn) and Data.COSMETICS[worn]["type"] == slot:
			cosmetics[slot] = worn
	if not Data.FORMATIONS.has(formation):
		formation = "balanced"
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
		if c.has("exam_day"):
			children[-1]["exam_day"] = int(c["exam_day"])
		if c.has("train_t"):
			children[-1]["train_t"] = float(c["train_t"])
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
	var src_story: Dictionary = d.get("story", {})
	story = {"chapter": clampi(int(src_story.get("chapter", 0)), 0, Data.STORY_CHAPTERS.size()), "claimed": [], "seen": []}
	for k in ["claimed", "seen"]:
		for v in src_story.get(k, []):
			story[k].append(int(v))
	officials = []
	for o in d.get("officials", []):
		officials.append({"name": str(o.get("name", "")), "gender": str(o.get("gender", "m")),
			"talent": int(o.get("talent", 1)), "title": str(o.get("title", "Juru Tulis"))})
	var src_bq: Dictionary = d.get("banquet", {})
	banquet = {"held": {}, "invite_day": int(src_bq.get("invite_day", -1)), "attended": []}
	for k in src_bq.get("held", {}):
		banquet["held"][str(k)] = int(src_bq["held"][k])
	for i in src_bq.get("attended", []):
		banquet["attended"].append(int(i))
	var src_prison: Dictionary = d.get("prison", {})
	prison = {"prisoners": [], "day": int(src_prison.get("day", -1)), "used": int(src_prison.get("used", 0))}
	for pr in src_prison.get("prisoners", []):
		prison["prisoners"].append({"name": str(pr.get("name", "")), "avatar": str(pr.get("avatar", "enemy_bandit")),
			"stage": int(pr.get("stage", 0)), "hp": int(pr.get("hp", 1)), "max": int(pr.get("max", 1))})
	start_day = int(d.get("start_day", day_index(now)))
	lord_name = _clean_name(str(d.get("lord_name", "")))
	equipment = []
	for e in d.get("equipment", []):
		var owner := str(e.get("owner", ""))
		if Data.equip_def(str(e.get("id", ""))).is_empty():
			continue
		equipment.append({"uid": int(e.get("uid", 0)), "id": str(e["id"]),
			"level": clampi(int(e.get("level", 1)), 1, Data.EQUIP_MAX_LEVEL),
			"owner": owner if counselors.has(owner) else ""})
	_equip_uid = int(d.get("equip_uid", equipment.size()))
	offers = []
	for o in d.get("offers", []):
		var reward := {}
		var src_r: Dictionary = o.get("reward", {})
		for k in src_r:
			if k == "items":
				reward["items"] = {}
				for item in src_r["items"]:
					reward["items"][str(item)] = int(src_r["items"][item])
			else:
				reward[str(k)] = int(src_r[k])
		if Data.OFFER_SECONDS.has(str(o.get("id", ""))):
			offers.append({"id": str(o["id"]), "expires": float(o.get("expires", 0.0)), "reward": reward})
	loss_streak = int(d.get("loss_streak", 0))
	counters = {}
	for k in d.get("counters", {}):
		counters[str(k)] = int(d["counters"][k])
	achievements = {}
	for k in d.get("achievements", {}):
		achievements[str(k)] = int(d["achievements"][k])
	season_pass = {}
	var src_pass: Dictionary = d.get("pass", {})
	if not src_pass.is_empty():
		season_pass = {"season": int(src_pass.get("season", 0)), "xp": int(src_pass.get("xp", 0)),
			"premium": bool(src_pass.get("premium", false)), "free": [], "paid": []}
		for k in ["free", "paid"]:
			for v in src_pass.get(k, []):
				season_pass[k].append(int(v))
	var src_ads: Dictionary = d.get("ads", {})
	ads = {"day": int(src_ads.get("day", -1)), "counts": {}}
	for k in src_ads.get("counts", {}):
		ads["counts"][str(k)] = int(src_ads["counts"][k])
	tower = {}
	var src_tower: Dictionary = d.get("tower", {})
	if not src_tower.is_empty():
		for k in ["week", "floor", "best", "day", "attempts"]:
			tower[k] = int(src_tower.get(k, 0))
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
