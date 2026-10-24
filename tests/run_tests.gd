extends SceneTree
## Tes logika game tanpa UI.
## Jalankan: godot --headless --path . --script res://tests/run_tests.gd

const Model := preload("res://scripts/core/game_model.gd")
const Data := preload("res://scripts/core/game_data.gd")

var _failures := 0
var _count := 0


func _init() -> void:
	for t in [
		"test_new_game", "test_affair_and_charge_regen", "test_upgrade",
		"test_campaign_win_unlock", "test_campaign_loss", "test_promote",
		"test_palace_children", "test_save_roundtrip", "test_gacha_basic", "test_gacha_ten_and_pity",
		"test_gacha_duplicates", "test_gacha_free", "test_gold_sources",
		"test_daily_generate", "test_daily_progress_claim", "test_daily_chests_reset", "test_daily_save",
		"test_login_streak", "test_login_break_and_save",
		"test_event_calendar", "test_event_points", "test_event_bonuses", "test_event_tiers_reset_save",
	]:
		call(t)
	print("%d cek, %d gagal" % [_count, _failures])
	quit(1 if _failures > 0 else 0)


func check(cond: bool, what: String) -> void:
	_count += 1
	if not cond:
		_failures += 1
		printerr("GAGAL: " + what)


func fresh(seed := 1) -> Model:
	var m := Model.new()
	m.rng.seed = seed
	m.new_game(1000.0)
	return m


func test_new_game() -> void:
	var m := fresh()
	check(m.counselors.size() == 2, "dua penasihat awal")
	check(m.beauties.has("melati"), "selir awal")
	check(m.charge_value("silver", 1000.0) == 3, "charge awal penuh")
	check(m.power() > 0, "kekuatan > 0")


func test_affair_and_charge_regen() -> void:
	var m := fresh()
	var before := m.silver
	var expected := m.affair_yield("silver")
	check(m.do_affair("silver", 1000.0)["ok"], "urusan berhasil")
	check(m.silver == before + expected, "perak bertambah")
	m.do_affair("silver", 1000.0)
	m.do_affair("silver", 1000.0)
	check(not m.do_affair("silver", 1000.0)["ok"], "charge habis")
	check(m.charge_eta("silver", 1030.0) == 30, "eta 30 detik")
	check(m.charge_value("silver", 1060.0) == 1, "terisi 1 setelah 60 dtk")
	check(m.charge_value("silver", 1125.0) == 2, "terisi 2 setelah 125 dtk")
	check(m.charge_value("silver", 99999.0) == 3, "tidak melebihi batas")


func test_upgrade() -> void:
	var m := fresh()
	var str_before := m.attr("arya", "str")
	m.silver = 100000
	check(m.upgrade_counselor("arya")["ok"], "upgrade berhasil")
	check(m.attr("arya", "str") == str_before * 2, "atribut naik sesuai level")
	m.silver = 0
	check(not m.upgrade_counselor("arya")["ok"], "upgrade gagal tanpa perak")
	m.silver = 10000000
	m.counselors["arya"]["level"] = m.rank_info()["level_cap"]
	check(not m.upgrade_counselor("arya")["ok"], "batas level jabatan")


func test_campaign_win_unlock() -> void:
	var m := fresh()
	m.soldiers = 10000000
	for i in 3:
		check(m.fight_stage()["ok"], "menang tahap %d" % i)
	check(m.stage == 3, "maju ke tahap 3")
	check(m.counselors.has("bayu"), "penasihat terbuka di tahap 3")
	check(m.prestige > 0, "prestise didapat")


func test_campaign_loss() -> void:
	var m := fresh()
	m.soldiers = 10
	check(m.current_stage_info()["enemy_id"] == "enemy_bandit", "musuh tahap pertama")
	check(not m.fight_stage()["ok"], "kalah tanpa prajurit")
	check(m.stage == 0 and m.soldiers == 5, "tahap tetap, separuh prajurit gugur")


func test_promote() -> void:
	var m := fresh()
	check(not m.promote()["ok"], "belum bisa naik")
	m.prestige = 150
	check(m.promote()["ok"] and m.rank == 1, "naik ke Camat")
	check(m.max_charges() == 4, "batas charge naik")
	m.rank = Data.RANKS.size() - 1
	m.prestige = 1 << 40
	check(not m.can_promote(), "jabatan tertinggi")


func test_palace_children() -> void:
	var m := fresh(7)
	var t := 1000.0
	var born := false
	while m.children.is_empty():
		t += 60.0
		born = m.visit_beauty("melati", t)["born"]
	check(born, "hasil kunjungan menandai kelahiran")
	check(m.beauties["melati"]["intimacy"] > 0, "keakraban naik")
	check(m.children[0]["gender"] in ["m", "f"], "anak punya jenis kelamin")
	m.grain = 1000000
	for i in Data.CHILD_MAX_LEVEL:
		m.train_child(0)
	check(m.children[0]["level"] == Data.CHILD_MAX_LEVEL, "anak dewasa")
	var power_before := m.power()
	check(m.marry_child(0)["ok"], "menikahkan anak")
	check(m.children.is_empty() and m.married_count == 1, "kursi kosong lagi")
	check(m.power() > power_before, "bonus atribut dari pernikahan")


func test_save_roundtrip() -> void:
	var m := fresh()
	m.soldiers = 10000000
	for i in 6:
		m.fight_stage()
	m.do_affair("grain", 1000.0)
	m.children.append({"name": "Adi", "gender": "m", "mother": "melati", "talent": 3, "level": 4})
	m.counselors["arya"]["bonus"]["str"] = 30
	var json := JSON.stringify(m.to_dict())
	var m2 := Model.new()
	m2.from_dict(JSON.parse_string(json), 1000.0)
	check(var_to_str(m2.to_dict()) == var_to_str(m.to_dict()), "simpan/muat identik")
	check(typeof(m2.counselors["arya"]["level"]) == TYPE_INT, "angka dikembalikan ke int")
	check(m2.power() == m.power(), "kekuatan sama setelah muat")


func test_gacha_basic() -> void:
	var m := fresh(3)
	check(m.gold == Data.START_GOLD, "emas awal")
	check(not m.counselors.has("resi"), "penasihat gacha tidak terbuka dari tahap")
	var before := m.counselors.size()
	var r := m.recruit(1, 1000.0)
	check(r["ok"] and r["results"].size() == 1, "rekrut x1 berhasil")
	check(m.gold == Data.START_GOLD - Data.GACHA_COST, "emas terpakai")
	var res: Dictionary = r["results"][0]
	check(m.counselors.has(res["id"]), "hasil rekrut dimiliki")
	check(res["new"] == (m.counselors.size() > before), "penanda penasihat baru")
	m.gold = 50
	check(not m.recruit(1, 1000.0)["ok"], "gagal tanpa emas")
	check(not m.recruit(3, 1000.0)["ok"], "jumlah tidak valid")


func test_gacha_ten_and_pity() -> void:
	for seed in 20:
		var m := fresh(seed)
		m.gold = 100000
		var r := m.recruit(10, 1000.0)
		var epic: int = r["results"].filter(func(x): return x["rarity"] != "r").size()
		check(r["results"].size() == 10 and epic >= 1, "10x menjamin minimal satu Epik (seed %d)" % seed)
	var m := fresh(1)
	m.gold = 1000000
	m.rng.seed = 99
	var since := 0
	var worst := 0
	for i in 400:
		var rarity: String = m.recruit(1, 1000.0)["results"][0]["rarity"]
		since += 1
		if rarity == "ssr":
			worst = maxi(worst, since)
			since = 0
	check(worst <= Data.GACHA_PITY, "Legenda dijamin dalam %d tarikan (terburuk %d)" % [Data.GACHA_PITY, worst])


func test_gacha_duplicates() -> void:
	var m := fresh()
	var r := m._grant_counselor("arya", "r")
	check(not r["new"] and r["stars"] == 1, "duplikat menambah bintang")
	var base := m.attr("arya", "str")
	check(base == int(9 * 1.2), "bintang menaikkan atribut")
	for i in Data.MAX_STARS - 1:
		m._grant_counselor("arya", "r")
	check(m.counselors["arya"]["stars"] == Data.MAX_STARS, "bintang maksimal")
	var silver := m.silver
	r = m._grant_counselor("arya", "r")
	check(r["silver"] > 0 and m.silver == silver + r["silver"], "duplikat bintang penuh jadi perak")
	check(m._grant_counselor("resi", "ssr")["new"], "penasihat baru dari gacha")


func test_gacha_free() -> void:
	var m := fresh()
	check(m.free_pull_eta(1000.0) == 0, "rekrut gratis tersedia di awal")
	check(m.recruit(1, 1000.0, true)["ok"] and m.gold == Data.START_GOLD, "rekrut gratis tanpa emas")
	check(not m.recruit(1, 1001.0, true)["ok"], "gratis hanya sekali per hari")
	check(m.free_pull_eta(1000.0 + 3600) == Data.GACHA_FREE_SECONDS - 3600, "hitung mundur gratis")
	check(m.recruit(1, 1000.0 + Data.GACHA_FREE_SECONDS, true)["ok"], "gratis lagi setelah 24 jam")
	check(not m.recruit(10, 999999.0, true)["ok"], "gratis hanya untuk x1")


func test_gold_sources() -> void:
	var m := fresh()
	m.soldiers = 10000000
	var g := m.gold
	for i in 5:
		m.fight_stage()
	check(m.gold > g + 50, "emas dari kampanye termasuk bonus tahap ke-5")
	m.prestige = 150
	g = m.gold
	m.promote()
	check(m.gold == g + Data.PROMOTE_GOLD, "emas dari naik jabatan")
	m.gold += Data.GACHA_COST_10
	m.recruit(10, 1000.0)
	m.counselors["arya"]["stars"] = 3
	var m2 := Model.new()
	m2.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())), 1000.0)
	check(var_to_str(m2.to_dict()) == var_to_str(m.to_dict()), "simpan/muat data gacha")


func _mission_index(m: Model, id: String) -> int:
	for i in m.daily["missions"].size():
		if m.daily["missions"][i]["id"] == id:
			return i
	return -1


## Paksa daftar misi hari ini (supaya tes tidak bergantung pada pilihan acak).
func _set_missions(m: Model, ids: Array) -> void:
	m.daily["missions"] = []
	for id in ids:
		m.daily["missions"].append({"id": id, "progress": 0, "claimed": false})


func test_daily_generate() -> void:
	var m := fresh()
	check(m.daily["missions"].size() == Data.DAILY_COUNT, "%d misi harian" % Data.DAILY_COUNT)
	var ids := {}
	for x in m.daily["missions"]:
		ids[x["id"]] = true
	check(ids.size() == Data.DAILY_COUNT, "misi tidak kembar")
	check(not ids.has("train3"), "misi didik anak tidak muncul tanpa anak")
	var m2 := fresh(42)
	check(var_to_str(m2.daily["missions"]) == var_to_str(m.daily["missions"]), "misi hari yang sama selalu sama")
	m.tz_bias = 0
	check(m.seconds_until_reset(86400.0 * 10 + 3600) == 82800, "hitung mundur reset")
	m.tz_bias = 7 * 3600
	check(m.day_index(86400.0 * 10 + 18 * 3600) == 11, "zona waktu WIB menggeser pergantian hari")


func test_daily_progress_claim() -> void:
	var m := fresh()
	_set_missions(m, ["tax5", "upgrade5", "win3", "visit3", "silver3k"])
	var completed := []
	m.mission_completed.connect(func(t): completed.append(t))
	var t := 1000.0
	for i in 5:
		t += 60.0
		m.do_affair("silver", t)
	check(m.mission_done(_mission_index(m, "tax5")), "misi pajak selesai")
	check(completed.size() == 1, "sinyal misi selesai sekali")
	check(m.daily["missions"][_mission_index(m, "silver3k")]["progress"] > 0, "perak dari pajak terhitung")
	check(not m.claim_mission(_mission_index(m, "win3"))["ok"], "misi belum selesai tidak bisa diklaim")
	var gold := m.gold
	var grain := m.grain
	check(m.claim_mission(_mission_index(m, "tax5"))["ok"], "klaim misi")
	check(m.gold == gold + 20 and m.grain == grain + 500, "hadiah misi diterima")
	check(m.daily["points"] == Data.DAILY_POINTS, "poin aktivitas bertambah")
	check(not m.claim_mission(_mission_index(m, "tax5"))["ok"], "tidak bisa klaim dua kali")
	m.soldiers = 10000000
	m.silver = 1000000
	for i in 3:
		m.fight_stage()
		m.upgrade_counselor("arya")
	check(m.mission_done(_mission_index(m, "win3")), "misi kampanye selesai")
	check(m.daily["missions"][_mission_index(m, "upgrade5")]["progress"] == 3, "progres latih 3/5")
	check(m.claimable_count() == 1, "satu hadiah siap diklaim")


func test_daily_chests_reset() -> void:
	var m := fresh()
	check(not m.claim_chest(0)["ok"], "peti terkunci tanpa poin")
	m.daily["points"] = 80
	check(m.can_claim_chest(0) and m.can_claim_chest(1) and not m.can_claim_chest(2), "peti terbuka sesuai poin")
	var gold := m.gold
	check(m.claim_chest(0)["ok"] and m.gold == gold + 30, "hadiah peti")
	check(not m.claim_chest(0)["ok"], "peti hanya sekali")
	m.daily["missions"][0]["progress"] = 999
	m.sync(1000.0 + 86400.0)
	check(m.daily["points"] == 0 and not m.daily["chests"][0], "reset poin & peti di hari baru")
	check(m.daily["missions"][0]["progress"] == 0, "progres misi direset")
	m.children.append({"name": "Adi", "gender": "m", "mother": "melati", "talent": 1, "level": 1})
	var seen := false
	for d in 30:
		m.sync(1000.0 + 86400.0 * (d + 2))
		if _mission_index(m, "train3") >= 0:
			seen = true
	check(seen, "misi didik anak muncul setelah punya anak")


func test_daily_save() -> void:
	var m := fresh()
	m.daily["missions"][0]["progress"] = 2
	m.daily["missions"][1]["claimed"] = true
	m.daily["points"] = 40
	m.daily["chests"][0] = true
	var m2 := Model.new()
	m2.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())), 1000.0)
	check(var_to_str(m2.daily) == var_to_str(m.daily), "simpan/muat misi harian")
	var m3 := Model.new()
	m3.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())), 1000.0 + 86400.0)
	check(m3.daily["points"] == 0, "muat di hari berikutnya mereset misi")


func test_login_streak() -> void:
	var m := fresh()
	var day := 86400.0
	var t := 1000.0
	check(m.login_can_claim(t) and m.login_day(t) == 1, "hari pertama bisa diklaim")
	var gold := m.gold
	var r := m.claim_login(t)
	check(r["ok"] and r["day"] == 1 and m.gold == gold + 50, "hadiah Hari 1")
	check(not m.claim_login(t + 3600)["ok"], "hanya sekali per hari")
	check(m.login_claimed_days(t) == 1, "kalender menandai Hari 1")
	for d in range(2, 8):
		t += day
		check(m.login_day(t) == d and m.claim_login(t)["ok"], "klaim Hari %d berturut-turut" % d)
	check(m.login["streak"] == 7, "streak 7 hari")
	gold = m.gold
	t += day
	check(m.login_day(t) == 1, "setelah Hari 7 siklus kembali ke Hari 1")
	check(m.login_claimed_days(t) == 0, "kalender kosong di siklus baru")
	m.claim_login(t)
	check(m.login["total"] == 8, "total hari login")


func test_login_break_and_save() -> void:
	var m := fresh()
	var day := 86400.0
	m.claim_login(1000.0)
	m.claim_login(1000.0 + day)
	check(m.login_day(1000.0 + 2 * day) == 3, "lanjut Hari 3 bila tidak terlewat")
	check(m.login_streak_broken(1000.0 + 3 * day), "terlewat sehari memutus rangkaian")
	check(m.login_day(1000.0 + 3 * day) == 1, "rangkaian terputus kembali ke Hari 1")
	m.claim_login(1000.0 + 3 * day)
	var m2 := Model.new()
	m2.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())), 1000.0 + 3 * day)
	check(var_to_str(m2.login) == var_to_str(m.login), "simpan/muat data login")
	check(not m2.login_can_claim(1000.0 + 3 * day), "status klaim bertahan setelah dimuat")


## Paksa event tertentu untuk minggu ini.
func _set_event(m: Model, id: String) -> void:
	for i in Data.EVENTS.size():
		if Data.EVENTS[i]["id"] == id:
			m.weekly["week"] = i
	m.weekly["points"] = 0


func test_event_calendar() -> void:
	var m := fresh()
	m.tz_bias = 0
	var monday := 4 * 86400.0  # 5 Jan 1970 adalah hari Senin
	check(m.week_index(monday - 1) == 0 and m.week_index(monday) == 1, "minggu berganti hari Senin 00:00")
	check(m.seconds_until_week_end(monday - 3600) == 3600, "hitung mundur akhir minggu")
	check(m.seconds_until_week_end(monday) == 7 * 86400, "minggu penuh 7 hari")
	var ids := {}
	for w in Data.EVENTS.size():
		m.sync(monday + w * 7 * 86400.0)
		ids[m.event_def()["id"]] = true
	check(ids.size() == Data.EVENTS.size(), "semua event bergiliran")


func test_event_points() -> void:
	var m := fresh()
	_set_event(m, "market")
	var t := 1000.0
	for i in 3:
		t += 60.0
		m.do_affair("silver", t)
	m.do_affair("grain", t)
	check(m.weekly["points"] == 30, "poin event dari aksi sesuai tema saja")
	_set_missions(m, ["tax5", "farm5", "win3", "visit3", "gacha1"])
	m.daily["missions"][0]["progress"] = 5
	m.claim_mission(0)
	check(m.weekly["points"] == 30 + Data.EVENT_MISSION_POINTS, "misi harian menambah poin event")
	_set_event(m, "ritual")
	m.gold = 10000
	m.recruit(10, t)
	check(m.weekly["points"] == 600, "rekrut x10 dihitung per tarikan")
	_set_event(m, "palace")
	m.children.append({"name": "Adi", "gender": "m", "mother": "melati", "talent": 2, "level": Data.CHILD_MAX_LEVEL})
	m.marry_child(0)
	check(m.weekly["points"] == 150, "menikahkan anak memberi poin Pesta Istana")


func test_event_bonuses() -> void:
	var m := fresh()
	_set_event(m, "tournament")
	var base_grain := m.affair_yield("grain")
	var base_silver := m.affair_yield("silver")
	var base_losses := m.expected_losses()
	_set_event(m, "harvest")
	check(m.affair_yield("grain") == int(base_grain * 1.5) or absi(m.affair_yield("grain") - int(base_grain * 1.5)) <= 1,
		"Festival Panen: hasil sawah +50%")
	check(m.affair_yield("silver") == base_silver, "bonus panen tidak mempengaruhi pajak")
	_set_event(m, "market")
	check(absi(m.affair_yield("silver") - int(base_silver * 1.5)) <= 1, "Pasar Malam: hasil pajak +50%")
	_set_event(m, "harvest")
	var normal_losses := m.expected_losses()
	_set_event(m, "tournament")
	check(m.expected_losses() < normal_losses and absi(m.expected_losses() - int(ceil(normal_losses * 0.8))) <= 1,
		"Turnamen Ksatria: korban -20%")
	check(base_losses == m.expected_losses(), "korban konsisten")
	_set_event(m, "ritual")
	check(is_equal_approx(m.event_bonus("ssr_rate"), 0.03), "Ritual Purnama menaikkan peluang Legenda")
	m.gold = 100000000
	m.rng.seed = 11
	var ssr := 0
	var n := 3000
	for i in n:
		if m.recruit(1, 1000.0)["results"][0]["rarity"] == "ssr":
			ssr += 1
	var rate := float(ssr) / n
	check(rate > 0.06, "peluang Legenda efektif naik saat ritual (%.3f)" % rate)
	_set_event(m, "palace")
	check(is_equal_approx(m.event_bonus("child_chance"), 0.15), "Pesta Istana menaikkan peluang anak")


func test_event_tiers_reset_save() -> void:
	var m := fresh()
	check(not m.claim_event_tier(0)["ok"], "hadiah terkunci tanpa poin")
	m.weekly["points"] = 650
	check(m.event_claimable_count() == 3, "tiga hadiah terbuka di 650 poin")
	var gold := m.gold
	check(m.claim_event_tier(2)["ok"] and m.gold == gold + 80, "klaim hadiah tingkat 3")
	check(not m.claim_event_tier(2)["ok"], "hadiah event hanya sekali")
	var m2 := Model.new()
	m2.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())), 1000.0)
	check(var_to_str(m2.weekly) == var_to_str(m.weekly), "simpan/muat event mingguan")
	m.sync(1000.0 + 7 * 86400.0)
	check(m.weekly["points"] == 0 and not m.weekly["claimed"][2], "event direset di minggu baru")
