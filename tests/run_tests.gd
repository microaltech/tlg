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
		"test_alliance_join_leave", "test_alliance_donate_level", "test_alliance_shop", "test_alliance_boss",
		"test_alliance_npc_and_save", "test_arena_unlock_tickets", "test_arena_fight", "test_arena_season_defense",
		"test_arena_shop_board_save", "test_tutorial_flow", "test_tutorial_skip_old_save", "test_feature_intros",
		"test_iap_gold_packs", "test_iap_starter_card", "test_iap_save_format", "test_vip_levels",
		"test_vip_perks", "test_vip_daily_packs_save", "test_war_setup", "test_war_attack", "test_war_simulation_result",
		"test_war_save_leave", "test_chat_send_reply", "test_chat_ambient_unread", "test_chat_save_leave",
		"test_lb_rank", "test_lb_top", "test_lb_alliances_reward", "test_items_use", "test_items_sources",
		"test_skills", "test_bonds", "test_prison", "test_exam_officials", "test_banquet",
		"test_story", "test_away_report", "test_lord_name",
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


func _allied(seed := 1) -> Model:
	var m := fresh(seed)
	m.stage = Data.ALLIANCE_UNLOCK_STAGE
	m.join_alliance("garuda", 1000.0)
	return m


func test_alliance_join_leave() -> void:
	var m := fresh()
	check(not m.join_alliance("garuda", 1000.0)["ok"], "aliansi terkunci sebelum tahap 5")
	m.stage = Data.ALLIANCE_UNLOCK_STAGE
	check(m.join_alliance("garuda", 1000.0)["ok"], "bergabung dengan aliansi")
	check(not m.join_alliance("macan", 1000.0)["ok"], "tidak bisa bergabung dua aliansi")
	check(m.alliance_level() == 3, "level awal Garuda dari exp awal")
	check(m.alliance_members(1000.0).size() == 19, "18 anggota NPC + pemain")
	check(m.leave_alliance(2000.0)["ok"] and m.alliance.is_empty(), "keluar aliansi")
	check(not m.join_alliance("teratai", 2000.0 + 3600)["ok"], "jeda sebelum bergabung lagi")
	check(m.join_alliance("teratai", 2000.0 + Data.ALLIANCE_LEAVE_COOLDOWN)["ok"], "bergabung lagi setelah jeda")


func test_alliance_donate_level() -> void:
	var m := _allied()
	var base_yield := m.affair_yield("silver")
	var lv := m.alliance_level()
	m.silver = 100000
	m.grain = 100000
	m.gold = 1000
	var exp := int(m.alliance["exp"])
	check(m.donate("silver", 1000.0)["ok"] and m.silver == 95000, "sumbang perak")
	check(int(m.alliance["exp"]) == exp + 50 and m.alliance["jasa"] == 50, "exp aliansi dan jasa bertambah")
	m.donate("gold", 1000.0)
	m.donate("grain", 1000.0)
	check(m.donations_left(1000.0) == 0 and not m.donate("silver", 1000.0)["ok"], "batas 3 sumbangan per hari")
	check(m.donations_left(1000.0 + 86400) == 3, "batas sumbangan reset besok")
	m.alliance["exp"] = Data.ALLIANCE_LEVELS[4] - 10
	m.donate("silver", 1000.0 + 86400)
	check(m.alliance_level() == 5, "naik level dari sumbangan")
	check(m.affair_yield("silver") > base_yield, "level aliansi menaikkan hasil urusan")
	check(is_equal_approx(m.alliance_bonus(), 0.15), "bonus 3% per level")
	m.gold = 0
	check(not m.donate("gold", 1000.0 + 86400)["ok"], "sumbangan gagal tanpa biaya")
	check(lv == 3, "level awal")


func test_alliance_shop() -> void:
	var m := _allied()
	check(not m.shop_buy("gold30", 1000.0)["ok"], "jasa tidak cukup")
	m.alliance["jasa"] = 1000
	var gold := m.gold
	check(m.shop_buy("gold30", 1000.0)["ok"] and m.gold == gold + 30 and m.alliance["jasa"] == 900, "beli di toko")
	m.shop_buy("gold30", 1000.0)
	check(not m.shop_buy("gold30", 1000.0)["ok"], "batas pembelian harian")
	check(m.shop_left("gold30", 1000.0 + 86400) == 2, "batas pembelian reset besok")
	check(not m.shop_buy("gold100", 1000.0)["ok"], "barang terkunci level aliansi")


func test_alliance_boss() -> void:
	var m := _allied()
	var info := m.boss_info(1000.0)
	# Bos mulai hari Senin; anggota NPC sudah menyerang sejak itu walau pemain baru bergabung.
	check(info["hp"] > 0 and info["hp"] <= info["hp_max"] and info["attacks_left"] == 3, "bos tersedia saat bergabung")
	var monday := Model.new()
	monday.rng.seed = 1
	monday.new_game(4 * 86400.0)
	monday.stage = Data.ALLIANCE_UNLOCK_STAGE
	monday.join_alliance("garuda", 4 * 86400.0)
	info = monday.boss_info(4 * 86400.0)
	check(info["hp"] == info["hp_max"], "bos penuh di hari Senin")
	var r := m.attack_boss(1000.0)
	check(r["ok"] and r["damage"] > 0 and m.alliance["jasa"] == Data.BOSS_ATTACK_JASA, "serang bos")
	m.attack_boss(1000.0)
	m.attack_boss(1000.0)
	check(not m.attack_boss(1000.0)["ok"], "maksimal 3 serangan per hari")
	check(m.boss_info(1000.0 + 86400)["attacks_left"] == 3, "serangan reset besok")
	check(m.boss_info(1000.0 + 86400)["npc_damage"] > 0, "anggota NPC ikut menyerang tiap hari")
	check(not m.claim_boss(1000.0)["ok"], "hadiah belum bisa sebelum bos kalah")
	m.alliance["boss"]["damage"] = m.alliance["boss"]["hp_max"]
	info = m.boss_info(1000.0)
	check(info["defeated"] and info["can_claim"], "bos kalah")
	check(not m.attack_boss(1000.0 + 86400)["ok"], "tidak bisa menyerang bos yang sudah kalah")
	var gold := m.gold
	check(m.claim_boss(1000.0)["ok"] and m.gold == gold + 100, "hadiah bos")
	check(not m.claim_boss(1000.0)["ok"], "hadiah bos sekali")
	m.sync(1000.0 + 7 * 86400)
	check(m.boss_info(1000.0 + 7 * 86400)["hp"] > 0 and not m.alliance["boss"]["claimed"], "bos baru di minggu berikutnya")
	var m2 := _allied()
	var t := 1000.0
	for d in 7:
		if m2.boss_info(t + d * 86400)["defeated"]:
			break
	check(m2.boss_info(t + 6 * 86400)["npc_damage"] > m2.boss_info(t + 86400)["npc_damage"], "kerusakan NPC bertambah tiap hari")


func test_alliance_npc_and_save() -> void:
	var m := _allied()
	var exp := int(m.alliance["exp"])
	var p0: int = m.alliance_members(1000.0).filter(func(x): return not x["me"])[0]["power"]
	m.sync(1000.0 + 3 * 86400)
	check(int(m.alliance["exp"]) > exp, "NPC menyumbang exp saat hari berganti")
	var p3: int = m.alliance_members(1000.0 + 3 * 86400).filter(func(x): return not x["me"])[0]["power"]
	check(p3 > p0, "kekuatan NPC tumbuh tiap hari")
	check(m.alliance["log"].size() >= 3, "catatan aktivitas aliansi")
	var other := _allied(99)
	check(var_to_str(other.alliance_members(1000.0)) == var_to_str(_allied(5).alliance_members(1000.0)),
		"anggota NPC deterministik")
	m.alliance["jasa"] = 77
	var m2 := Model.new()
	m2.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())), 1000.0 + 3 * 86400)
	check(var_to_str(m2.alliance) == var_to_str(m.alliance), "simpan/muat aliansi")
	_set_missions(m, [])
	m.daily = {}
	m.ensure_daily(1000.0 + 10 * 86400)
	var seen := false
	for d in 20:
		m.daily = {}
		m.ensure_daily(1000.0 + (11 + d) * 86400)
		for x in m.daily["missions"]:
			if x["id"] in ["donate1", "boss2"]:
				seen = true
	check(seen, "misi aliansi muncul setelah bergabung")
	var solo := fresh()
	for d in 20:
		solo.daily = {}
		solo.ensure_daily(1000.0 + d * 86400)
		for x in solo.daily["missions"]:
			check(not (x["id"] in ["donate1", "boss2"]), "misi aliansi tidak muncul tanpa aliansi")


func _arena_model(seed := 1) -> Model:
	var m := fresh(seed)
	m.soldiers = 100000000
	for i in Data.ARENA_UNLOCK_STAGE:
		m.fight_stage()
	m.ensure_arena(1000.0)
	return m


func test_arena_unlock_tickets() -> void:
	var m := fresh()
	check(not m.arena_unlocked() and not m.arena_fight(0, 1000.0)["ok"], "arena terkunci sebelum tahap 8")
	m = _arena_model()
	check(not m.arena.is_empty() and m.arena["rating"] == Data.ARENA_START_RATING, "arena terbuka dengan 1000 poin")
	check(m.arena["opponents"].size() == 3, "tiga lawan")
	var ratings: Array = m.arena["opponents"].map(func(o): return o["rating"])
	check(ratings[0] < 1000 and ratings[2] > 1000, "lawan lebih lemah dan lebih kuat")
	for i in Data.ARENA_TICKETS:
		m.arena_fight(0, 1000.0)
	check(m.arena_tickets_left(1000.0) == 0 and not m.arena_fight(0, 1000.0)["ok"], "tiket harian habis")
	m.gold = 1000
	check(m.buy_arena_ticket(1000.0)["ok"] and m.gold == 1000 - Data.ARENA_TICKET_COST, "beli tiket")
	check(m.arena_tickets_left(1000.0) == 1, "tiket tambahan")
	check(m.arena_tickets_left(1000.0 + 86400) == Data.ARENA_TICKETS, "tiket reset besok")
	for i in Data.ARENA_REFRESH_FREE:
		m.refresh_arena(1000.0)
	check(not m.refresh_arena(1000.0)["ok"], "batas segarkan lawan")


func test_arena_fight() -> void:
	var m := _arena_model()
	var opp: Dictionary = m.arena["opponents"][1]
	var stakes := m.arena_stakes(int(opp["rating"]))
	var r := m.arena_fight(1, 1000.0)
	check(r["ok"] and r["rounds"].size() == 4, "pertarungan 3 ronde")
	var last: Dictionary = r["rounds"][3]
	check((last["them"] == 0) == r["win"] and (last["me"] == 0) == (not r["win"]), "HP akhir sesuai hasil")
	check(r["delta"] == (stakes[0] if r["win"] else -stakes[1]), "perubahan poin sesuai taruhan")
	check(m.arena["rating"] == 1000 + r["delta"], "poin arena berubah")
	check(m.arena["coins"] == (20 if r["win"] else 5), "koin arena")
	var weak := 0
	var strong := 0
	for i in 400:
		weak += 1 if m.rng.randf() < m.arena_win_chance(int(m.power() * 0.6)) else 0
		strong += 1 if m.rng.randf() < m.arena_win_chance(int(m.power() * 1.6)) else 0
	check(m.arena_win_chance(int(m.power() * 0.6)) > 0.8 and m.arena_win_chance(int(m.power() * 1.6)) < 0.2,
		"peluang menang mengikuti selisih kekuatan")
	check(weak > 280 and strong < 120, "lawan lemah mudah dikalahkan, lawan kuat sulit (%d / %d)" % [weak, strong])
	check(m.arena_stakes(1400)[0] > m.arena_stakes(800)[0], "menang lawan berpoin tinggi memberi lebih banyak")
	check(Data.league_of(1250)["name"] == "Perak" and Data.league_of(2300)["name"] == "Legenda", "liga dari poin")


func test_arena_season_defense() -> void:
	var m := _arena_model()
	m.arena["rating"] = 1600
	m.arena_fight(0, 1000.0)
	var rating: int = m.arena["rating"]
	var log_before: int = m.arena["log"].size()
	m.sync(1000.0 + 86400 * 2)
	check(m.arena["log"].size() >= log_before, "catatan pertahanan saat offline")
	m.arena["rating"] = 1600
	m.sync(1000.0 + 86400 * 7)
	# 1600 -> 1300, lalu pertahanan offline (maks. 3 hari x 3 serangan x 8 poin) mengubah sedikit.
	check(absi(m.arena["rating"] - 1300) <= 72, "poin direset sebagian di musim baru (%d)" % m.arena["rating"])
	check(not m.arena["season_reward"].is_empty() and m.arena["season_reward"]["league"] == "Emas", "hadiah musim sesuai liga")
	var gold := m.gold
	check(m.claim_arena_season()["ok"] and m.gold == gold + 200, "klaim hadiah musim")
	check(not m.claim_arena_season()["ok"], "hadiah musim sekali")
	m.sync(1000.0 + 86400 * 14)
	check(m.arena["season_reward"].is_empty(), "tanpa bertarung tidak ada hadiah musim")
	check(rating > 0, "poin valid")


func test_arena_shop_board_save() -> void:
	var m := _arena_model()
	check(not m.arena_shop_buy("a_gold", 1000.0)["ok"], "koin arena tidak cukup")
	m.arena["coins"] = 500
	var gold := m.gold
	check(m.arena_shop_buy("a_gold", 1000.0)["ok"] and m.gold == gold + 40, "beli di toko arena")
	m.arena_shop_buy("a_gold", 1000.0)
	check(not m.arena_shop_buy("a_gold", 1000.0)["ok"], "batas toko arena")
	check(not m.arena_shop_buy("gold30", 1000.0)["ok"], "barang toko aliansi tidak dijual di arena")
	var board := m.arena_leaderboard()
	check(board["total"] == 41 and board["rows"].size() == 10, "papan peringkat 41 pemain")
	m.arena["rating"] = 3000
	check(m.arena_leaderboard()["rank"] == 1, "poin tertinggi peringkat 1")
	var m2 := Model.new()
	m2.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())), 1000.0)
	check(var_to_str(m2.arena) == var_to_str(m.arena), "simpan/muat arena")
	var seen := false
	for d in 20:
		m.daily = {}
		m.ensure_daily(1000.0 + d * 86400)
		for x in m.daily["missions"]:
			if x["id"] == "arena3":
				seen = true
	check(seen, "misi arena muncul setelah arena terbuka")


func test_tutorial_flow() -> void:
	var m := fresh()
	check(m.tutorial_active() and m.tutorial["step"] == 0, "pemain baru mulai tutorial")
	var events := []
	m.tracked.connect(func(e): events.append(e))
	m.do_affair("silver", 1000.0)
	m.fight_stage()
	check("affair_silver" in events and "battle" in events, "aksi dilaporkan untuk tutorial")
	var gold := m.gold
	var silver := m.silver
	var last := {}
	for i in Data.TUTORIAL_STEPS.size():
		last = m.tutorial_advance()
	check(last.get("done", false) and not m.tutorial_active(), "tutorial selesai setelah langkah terakhir")
	check(m.gold == gold + 100 and m.silver == silver + 2000, "hadiah tutorial")
	check(not m.tutorial_advance()["ok"], "hadiah tutorial hanya sekali")
	for step in Data.TUTORIAL_STEPS:
		var w: String = step["wait"]
		check(w == "next" or w.begins_with("page:") or w in ["affair_silver", "affair_soldiers", "upgrade", "battle",
			"recruit", "visit"], "langkah tutorial menunggu aksi yang dikenal (%s)" % w)


func test_tutorial_skip_old_save() -> void:
	var m := fresh()
	var gold := m.gold
	check(m.skip_tutorial()["ok"] and not m.tutorial_active() and m.gold == gold, "lewati tanpa hadiah")
	var old := fresh().to_dict()
	old.erase("tutorial")
	old["stage"] = 9
	var m2 := Model.new()
	m2.from_dict(JSON.parse_string(JSON.stringify(old)), 1000.0)
	check(not m2.tutorial_active(), "save lama tidak memulai tutorial")
	check(m2.pending_intro().is_empty(), "save lama tidak menampilkan pengenalan fitur lama")
	var m3 := fresh()
	m3.tutorial_advance()
	var m4 := Model.new()
	m4.from_dict(JSON.parse_string(JSON.stringify(m3.to_dict())), 1000.0)
	check(m4.tutorial_active() and m4.tutorial["step"] == 1, "progres tutorial tersimpan")


func test_feature_intros() -> void:
	var m := fresh()
	m.skip_tutorial()
	check(m.pending_intro().is_empty(), "belum ada fitur baru")
	m.stage = Data.ALLIANCE_UNLOCK_STAGE
	check(m.pending_intro().get("id", "") == "alliance", "pengenalan aliansi di tahap 5")
	m.mark_intro_seen("alliance")
	check(m.pending_intro().is_empty(), "pengenalan hanya sekali")
	m.stage = Data.ARENA_UNLOCK_STAGE
	check(m.pending_intro().get("id", "") == "arena", "pengenalan arena di tahap 8")
	var t := fresh()
	t.stage = 10
	check(t.pending_intro().is_empty(), "pengenalan fitur ditunda selama tutorial")


## Tandai semua hadiah naik level VIP sudah diberikan, agar tes IAP hanya mengukur isi paket.
func _no_vip_gifts(m: Model) -> void:
	for lv in range(1, Data.VIP_LEVELS.size()):
		m.vip["gifts"].append(lv)


func test_iap_gold_packs() -> void:
	var m := fresh()
	_no_vip_gifts(m)
	var gold := m.gold
	check(m.iap_first_bonus("gold_330"), "bonus pembelian pertama tersedia")
	var r := m.grant_purchase("gold_330", "tok1", 1000.0)
	check(r["ok"] and m.gold == gold + 300 + 30 + 300, "paket emas + bonus + x2 pembelian pertama")
	check(not m.iap_first_bonus("gold_330"), "bonus pertama hanya sekali")
	gold = m.gold
	check(m.grant_purchase("gold_330", "tok2", 1000.0)["ok"] and m.gold == gold + 330, "pembelian kedua tanpa bonus x2")
	gold = m.gold
	var dup := m.grant_purchase("gold_330", "tok2", 1000.0)
	check(not dup["ok"] and dup.get("duplicate", false) and m.gold == gold, "token yang sama tidak diproses dua kali")
	check(not m.grant_purchase("palsu", "tok3", 1000.0)["ok"], "produk tidak dikenal ditolak")
	check(m.iap["spent_idr"] == 150000, "total belanja tercatat")


func test_iap_starter_card() -> void:
	var m := fresh()
	_no_vip_gifts(m)
	var gold := m.gold
	check(m.grant_purchase("starter_pack", "s1", 1000.0)["ok"], "paket pemula")
	check(m.gold == gold + 500 and m.counselors.has("wening"), "isi paket pemula termasuk penasihat Epik")
	check(m.iap_owned("starter_pack") and not m.grant_purchase("starter_pack", "s2", 1000.0)["ok"], "paket pemula sekali beli")
	gold = m.gold
	check(m.grant_purchase("monthly_card", "c1", 1000.0)["ok"] and m.gold == gold + 300, "kartu bulanan: emas langsung")
	check(m.card_days_left(1000.0) == 30, "kartu aktif 30 hari")
	gold = m.gold
	check(m.claim_card(1000.0)["ok"] and m.gold == gold + 100, "ambil emas harian kartu")
	check(not m.claim_card(1000.0)["ok"], "emas kartu sekali per hari")
	check(m.card_can_claim(1000.0 + 86400), "bisa diambil lagi besok")
	check(m.card_days_left(1000.0 + 29 * 86400) == 1 and m.card_days_left(1000.0 + 30 * 86400) == 0, "kartu berakhir setelah 30 hari")
	m.grant_purchase("monthly_card", "c2", 1000.0 + 10 * 86400)
	check(m.card_days_left(1000.0 + 10 * 86400) == 50, "membeli lagi memperpanjang kartu")


func test_iap_save_format() -> void:
	var m := fresh()
	m.grant_purchase("gold_60", "t1", 1000.0)
	m.grant_purchase("monthly_card", "t2", 1000.0)
	var m2 := Model.new()
	m2.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())), 1000.0)
	check(var_to_str(m2.iap) == var_to_str(m.iap), "simpan/muat data pembelian")
	check(not m2.grant_purchase("gold_60", "t1", 1000.0)["ok"], "token tetap tercatat setelah dimuat")
	check(Data.format_idr(75000) == "Rp75.000" and Data.format_idr(1500000) == "Rp1.500.000"
		and Data.format_idr(500) == "Rp500", "format rupiah")


func test_vip_levels() -> void:
	var m := fresh()
	check(m.vip_level() == 0, "mulai VIP 0")
	var gold := m.gold
	m.grant_purchase("gold_60", "v1", 1000.0)  # Rp15.000 = 15 poin
	check(m.vip["points"] == 15 and m.vip_level() == 1, "pembelian memberi poin VIP")
	check(m.gold == gold + 120 + 30, "hadiah naik ke VIP 1 (+30 emas)")
	gold = m.gold
	m.grant_purchase("gold_680", "v2", 1000.0)  # +149 poin -> 164 = VIP 3
	check(m.vip_level() == 3, "loncat beberapa level sekaligus")
	check(m.gold == gold + 1280 + 50 + 80, "hadiah semua level yang dilewati")
	var p := m.vip_progress()
	check(p[0] == 64 and p[1] == 100, "progres ke VIP berikutnya")
	m.claim_login(1000.0)
	check(m.vip["points"] == 165, "klaim login memberi 1 poin VIP")
	m.vip["points"] = 999999
	check(m.vip_level() == Data.VIP_LEVELS.size() - 1 and m.vip_progress() == [0, 0], "VIP maksimal")


func test_vip_perks() -> void:
	var m := fresh()
	m.soldiers = 100000000
	for i in Data.ARENA_UNLOCK_STAGE:
		m.fight_stage()
	m.ensure_arena(1000.0)
	m.join_alliance("garuda", 1000.0)
	var base_yield := m.affair_yield("silver")
	var base_charges := m.max_charges()
	m.vip["points"] = Data.VIP_LEVELS[8]["points"]  # VIP 8
	check(m.max_charges() == base_charges + 3, "VIP menambah kapasitas urusan")
	check(m.affair_yield("silver") > base_yield, "VIP menaikkan hasil urusan")
	check(m.arena_tickets_left(1000.0) == Data.ARENA_TICKETS + 2, "VIP menambah tiket arena")
	check(m.donations_left(1000.0) == Data.ALLIANCE_DONATIONS_PER_DAY + 2, "VIP menambah sumbangan aliansi")
	check(m.boss_info(1000.0)["attacks_left"] == Data.BOSS_ATTACKS_PER_DAY + 1, "VIP menambah serangan bos")
	for i in Data.BOSS_ATTACKS_PER_DAY + 1:
		check(m.attack_boss(1000.0)["ok"], "serangan bos ke-%d dengan VIP" % (i + 1))
	check(not m.attack_boss(1000.0)["ok"], "batas serangan bos VIP")


func test_vip_daily_packs_save() -> void:
	var m := fresh()
	check(not m.claim_vip_daily(1000.0)["ok"], "VIP 0 tanpa hadiah harian")
	check(not m.buy_vip_pack(1)["ok"], "paket VIP terkunci")
	m.vip["points"] = Data.VIP_LEVELS[7]["points"]
	var gold := m.gold
	check(m.claim_vip_daily(1000.0)["ok"] and m.gold == gold + 50, "hadiah harian VIP 7")
	check(not m.claim_vip_daily(1000.0)["ok"] and m.vip_daily_can_claim(1000.0 + 86400), "harian sekali per hari")
	m.gold = 10000
	check(m.buy_vip_pack(7)["ok"] and m.counselors.has("kedaton") and m.gold == 10000 - 700, "paket VIP 7 berisi Legenda")
	check(not m.buy_vip_pack(7)["ok"], "paket VIP sekali beli")
	check(not m.buy_vip_pack(8)["ok"], "paket level lebih tinggi terkunci")
	m.gold = 10
	check(not m.buy_vip_pack(5)["ok"], "paket VIP butuh emas")
	var m2 := Model.new()
	m2.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())), 1000.0)
	check(var_to_str(m2.vip) == var_to_str(m.vip), "simpan/muat VIP")
	check(m2.max_charges() == m.max_charges(), "keuntungan VIP aktif setelah dimuat")


## Model dengan aliansi, dimulai hari Senin agar perang mulai penuh.
func _war_model(seed := 1) -> Model:
	var m := Model.new()
	m.rng.seed = seed
	m.new_game(4 * 86400.0)
	m.stage = Data.ALLIANCE_UNLOCK_STAGE
	m.join_alliance("garuda", 4 * 86400.0)
	return m


func test_war_setup() -> void:
	var solo := fresh()
	solo.sync(1000.0)
	check(solo.war.is_empty() and not solo.attack_fort(0, 1000.0)["ok"], "perang butuh aliansi")
	var m := _war_model()
	check(not m.war.is_empty() and m.war["enemy"] != "garuda", "lawan adalah aliansi lain")
	check(m.war["their"] == m.war["their_max"] and m.war["our"] == m.war["our_max"], "benteng penuh di hari Senin")
	check(m.war_score(true) == 0 and m.war_score(false) == 0, "skor awal 0")
	check(m.war_fort_locked(4) and not m.war_fort_locked(0), "Keraton Inti terkunci di awal")
	var enemies := {}
	for w in 6:
		enemies[m._war_enemy_for(w)] = true
	check(enemies.size() == 2 and not enemies.has("garuda"), "lawan bergiliran tiap minggu")


func test_war_attack() -> void:
	var m := _war_model()
	var t := 4 * 86400.0
	var hp: int = m.war["their"][0]
	var r := m.attack_fort(0, t)
	check(r["ok"] and m.war["their"][0] == hp - r["damage"], "serangan mengurangi HP benteng")
	check(m.war["merit"] > 0 and m.war_score(true) > 0, "jasa perang dan skor bertambah")
	check(not m.attack_fort(4, t)["ok"], "Keraton Inti tidak bisa diserang di awal")
	m.attack_fort(1, t)
	m.attack_fort(2, t)
	check(not m.attack_fort(0, t)["ok"], "maksimal 3 serangan per hari")
	check(m.war_attacks_left(t + 86400) == 3, "serangan reset besok")
	m.vip["points"] = Data.VIP_LEVELS[6]["points"]
	check(m.war_attacks_left(t + 86400) == 4, "VIP menambah serangan perang")
	m.sync(t + 86400)  # terapkan dulu serangan NPC hari itu
	for i in 3:
		m.war["their"][i] = 1
	var merit: int = m.war["merit"]
	var cap := m.attack_fort(0, t + 86400)
	check(cap["captured"] and m.war["merit"] >= merit + Data.WAR_CAPTURE_MERIT, "merebut benteng memberi bonus jasa")
	m.attack_fort(1, t + 86400)
	m.attack_fort(2, t + 86400)
	check(not m.war_fort_locked(4), "Keraton Inti terbuka setelah 3 benteng direbut")
	check(not m.attack_fort(0, t + 86400)["ok"], "benteng yang sudah direbut tidak bisa diserang")


func test_war_simulation_result() -> void:
	var m := _war_model()
	var t := 4 * 86400.0
	m.sync(t + 3 * 86400)
	check(m.war_score(true) > 0 and m.war_score(false) > 0, "NPC kedua pihak menyerang tiap hari")
	var mid_ours := m.war_score(true)
	m.sync(t + 5 * 86400)
	check(m.war_score(true) > mid_ours, "skor bertambah seiring hari")
	check(m.war["log"].size() > 1, "kabar perang tercatat")
	# Pemain sangat aktif: rebut semua benteng lawan agar pasti menang.
	for i in Data.WAR_FORTS.size():
		m.war["their"][i] = 0
	m.war["merit"] = 1000
	m.sync(t + 7 * 86400)
	check(not m.war_reward.is_empty() and m.war_reward["win"], "perang selesai di akhir minggu, menang")
	check(int(m.war["week"]) == m.week_index(t + 7 * 86400) and m.war["merit"] == 0, "perang baru di minggu berikutnya")
	var gold := m.gold
	var jasa: int = m.alliance["jasa"]
	check(m.claim_war_reward()["ok"], "klaim hadiah perang")
	check(m.gold == gold + 300 + 50 and m.alliance["jasa"] == jasa + 500, "hadiah menang + bonus jasa perang")
	check(not m.claim_war_reward()["ok"], "hadiah perang sekali")
	var lazy := _war_model(3)
	for i in Data.WAR_FORTS.size():
		lazy.war["our"][i] = 0
	lazy.sync(t + 7 * 86400)
	check(not lazy.war_reward["win"] and lazy.war_reward["reward"]["gold"] == 100, "kalah memberi hadiah lebih kecil")


func test_war_save_leave() -> void:
	var m := _war_model()
	m.attack_fort(0, 4 * 86400.0)
	var m2 := Model.new()
	m2.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())), 4 * 86400.0)
	check(var_to_str(m2.war) == var_to_str(m.war), "simpan/muat perang")
	m.leave_alliance(4 * 86400.0)
	check(m.war.is_empty(), "keluar aliansi menghentikan perang")


func test_chat_send_reply() -> void:
	var solo := fresh()
	check(not solo.chat_send("halo", 1000.0)["ok"], "chat butuh aliansi")
	var m := _allied()
	var t := 5000.0
	check(not m.chat_send("   ", t)["ok"], "pesan kosong ditolak")
	check(not m.chat_send("a".repeat(Data.CHAT_MAX_LENGTH + 1), t)["ok"], "pesan terlalu panjang ditolak")
	var before: int = m.chat_messages(t).size()
	check(m.chat_send("Halo semua!", t)["ok"], "kirim pesan")
	check(not m.chat_send("lagi", t + 1.0)["ok"], "jeda antar pesan")
	var visible_now: Array = m.chat_messages(t)
	check(visible_now.size() == before + 1 and visible_now[-1]["me"], "pesan sendiri langsung terlihat")
	var later: Array = m.chat_messages(t + 10.0)
	var replies := later.filter(func(x): return float(x["t"]) > t and not x.get("me", false))
	check(replies.size() >= 1, "anggota membalas dalam beberapa detik")
	var greet := false
	for r in replies:
		greet = greet or "Tuan" in r["text"] or r["text"] in Data.CHAT_REPLIES["greet"]
	check(greet, "balasan sesuai salam")
	check(m.chat_send("dasar goblok", t + 20.0)["ok"], "pesan dengan kata kasar tetap terkirim")
	var last_me: Array = m.chat_messages(t + 20.0).filter(func(x): return x.get("me", false))
	check(last_me[-1]["text"] == "dasar ******", "kata kasar disaring")


func test_chat_ambient_unread() -> void:
	var m := _allied()
	var t := 1000.0
	var base: int = m.chat_messages(t + 10).size()
	m.chat_mark_read(t + 10)
	var later := t + 6 * 3600.0
	var msgs: Array = m.chat_messages(later)
	check(msgs.size() > base, "anggota mengobrol saat game ditutup")
	check(m.chat_unread(later) == msgs.size() - base, "jumlah pesan belum dibaca")
	m.chat_mark_read(later)
	check(m.chat_unread(later) == 0, "tandai sudah dibaca")
	var m2 := _allied(77)
	check(var_to_str(m2.chat_messages(later).map(func(x): return x["text"])).length() > 0, "obrolan terisi")
	var far := t + 30 * 86400.0
	var count_before: int = m.chat_messages(later).size()
	check(m.chat_messages(far).size() - count_before <= Data.CHAT_CATCHUP_SLOTS, "obrolan terlewat dibatasi")
	for i in 100:
		m.chat_send("pesan %d" % i, far + i * 3.0)
	check(m.chat_messages(far + 1000.0).size() <= Data.CHAT_MAX_MESSAGES, "riwayat chat dibatasi")


func test_chat_save_leave() -> void:
	var m := _allied()
	m.chat_send("Halo", 2000.0)
	m.chat_messages(2010.0)
	var m2 := Model.new()
	m2.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())), 2010.0)
	check(var_to_str(m2.alliance["chat"]) == var_to_str(m.alliance["chat"]), "simpan/muat chat")
	m.leave_alliance(3000.0)
	check(m.chat_messages(3000.0).is_empty(), "keluar aliansi mengosongkan chat")


func test_lb_rank() -> void:
	var m := fresh()
	var r := m.lb_rank("power", 1000.0)
	check(r["total"] == Data.LB_PLAYERS + 1 and r["rank"] > 1 and r["rank"] <= r["total"], "peringkat dalam rentang")
	var prev: int = r["rank"]
	var better := true
	for p in [200, 1000, 5000, 50000]:
		m.counselors["arya"]["bonus"]["str"] = p
		var rank: int = m.lb_rank("power", 1000.0)["rank"]
		better = better and rank < prev
		prev = rank
	check(better, "kekuatan lebih tinggi = peringkat lebih baik")
	check(prev == 1, "kekuatan sangat tinggi = peringkat 1")
	m.counselors["arya"]["bonus"]["str"] = 1000
	check(m.lb_rank("power", 1000.0 + 60 * 86400)["rank"] > m.lb_rank("power", 1000.0)["rank"],
		"pemain lain ikut tumbuh seiring waktu")
	check(m.lb_rank("stage", 1000.0)["rank"] == r["total"], "belum menang tahap = peringkat terakhir")
	check(m.lb_rank("arena", 1000.0)["value"] == 0, "arena belum terbuka tidak berperingkat")
	check(absf(Model._erf(0.5) - 0.5205) < 0.001 and absf(Model._normal_tail_inv(0.5)) < 0.001, "rumus distribusi")


func test_lb_top() -> void:
	var m := fresh()
	var top := m.lb_top("power", 1000.0)
	check(top.size() == Data.LB_TOP, "50 baris teratas")
	var sorted := true
	for i in top.size() - 1:
		sorted = sorted and top[i]["value"] >= top[i + 1]["value"]
	check(sorted, "urut menurun")
	check(not top.any(func(x): return x["me"]), "pemain lemah tidak masuk daftar teratas")
	check(var_to_str(m.lb_top("power", 1000.0)) == var_to_str(top), "daftar stabil dalam satu hari")
	m.counselors["arya"]["bonus"]["str"] = 12000
	var rank: int = m.lb_rank("power", 1000.0)["rank"]
	top = m.lb_top("power", 1000.0)
	check(rank <= Data.LB_TOP and top[rank - 1]["me"], "pemain kuat muncul di posisi peringkatnya")
	sorted = true
	for i in top.size() - 1:
		sorted = sorted and top[i]["value"] >= top[i + 1]["value"]
	check(sorted, "tetap urut setelah pemain disisipkan")


func test_lb_alliances_reward() -> void:
	var m := _allied()
	var rows := m.lb_alliances(1000.0)
	check(rows.size() == Data.LB_ALLIANCE_COUNT, "30 aliansi berperingkat")
	check(rows.filter(func(x): return x["me"]).size() == 1, "aliansi sendiri ditandai")
	var sorted := true
	for i in rows.size() - 1:
		sorted = sorted and rows[i]["power"] >= rows[i + 1]["power"]
	check(sorted, "aliansi urut kekuatan")
	check(m.lb_reward_tier(0.5)["gold"] == 300 and m.lb_reward_tier(15.0)["gold"] == 100
		and m.lb_reward_tier(99.0)["gold"] == 20, "tingkat hadiah dari persentil")
	check(not m.claim_lb_reward()["ok"], "belum ada hadiah minggu ini")
	m.counselors["arya"]["bonus"]["str"] = 50000
	m.sync(1000.0 + 7 * 86400)
	check(m.leaderboard["reward"].get("gold", 0) == 300, "hadiah mingguan Top 1%")
	var gold := m.gold
	check(m.claim_lb_reward()["ok"] and m.gold == gold + 300, "klaim hadiah peringkat")
	check(not m.claim_lb_reward()["ok"], "hadiah peringkat sekali")
	m.sync(1000.0 + 14 * 86400)
	var m2 := Model.new()
	m2.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())), 1000.0 + 14 * 86400)
	check(m2.start_day == m.start_day and var_to_str(m2.leaderboard) == var_to_str(m.leaderboard),
		"simpan/muat leaderboard")


func test_items_use() -> void:
	var m := fresh()
	check(m.item_count("recruit_ticket") == 1 and m.item_count("scroll_train") == 2, "item awal pemain baru")
	var lv: int = m.counselors["arya"]["level"]
	check(m.use_item("scroll_train", "arya", 1000.0)["ok"] and m.counselors["arya"]["level"] == lv + 1, "gulungan latihan")
	check(not m.use_item("scroll_train", "bukan", 1000.0)["ok"], "item bertarget butuh target valid")
	m.use_item("scroll_train", "arya", 1000.0)
	check(m.item_count("scroll_train") == 0 and not m.use_item("scroll_train", "arya", 1000.0)["ok"], "item habis")
	m.add_item("star_stone", 1)
	check(m.use_item("star_stone", "sekar", 1000.0)["ok"] and m.counselors["sekar"]["stars"] == 1, "batu bintang")
	m.add_item("pill_intimacy", 1)
	check(m.use_item("pill_intimacy", "melati", 1000.0)["ok"] and m.beauties["melati"]["intimacy"] == 10, "pil keakraban")
	m.do_affair("silver", 1000.0)
	m.do_affair("silver", 1000.0)
	m.add_item("energy_tea", 1)
	check(m.use_item("energy_tea", "", 1000.0)["ok"] and m.charge_value("silver", 1000.0) == m.max_charges(), "teh semangat")
	m.add_item("silver_box", 1)
	var silver := m.silver
	check(m.use_item("silver_box", "", 1000.0)["ok"] and m.silver == silver + 10000, "buka peti perak")
	var gold := m.gold
	var r := m.recruit(1, 1000.0, false, true)
	check(r["ok"] and m.gold == gold and m.item_count("recruit_ticket") == 0, "rekrut dengan tiket tanpa emas")
	check(not m.recruit(1, 1000.0, false, true)["ok"], "tiket habis")
	m.add_item("palsu", 3)
	check(m.item_count("palsu") == 0, "item tidak dikenal diabaikan")
	var m2 := Model.new()
	m.add_item("troop_writ", 4)
	m2.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())), 1000.0)
	check(var_to_str(m2.inventory) == var_to_str(m.inventory), "simpan/muat tas")


func test_items_sources() -> void:
	var m := fresh()
	m.inventory = {}
	m.soldiers = 100000000
	for i in 5:
		m.fight_stage()
	var total := 0
	for id in m.inventory:
		total += m.inventory[id]
	check(total == 1, "tahap besar memberi item rampasan")
	m.daily["points"] = 100
	m.claim_chest(2)
	check(m.item_count("scroll_train") >= 1, "peti aktivitas berisi item")
	for i in 7:
		m.claim_login(1000.0 + i * 86400)
	check(m.item_count("recruit_ticket") >= 1 and m.item_count("pill_intimacy") >= 2, "hadiah login berisi item")


func test_skills() -> void:
	var m := fresh()
	check(is_equal_approx(m.skill_value("sekar"), 0.05), "skill awal Sekar 5%")
	m.counselors["sekar"]["stars"] = 3
	check(is_equal_approx(m.skill_value("sekar"), 0.11), "skill naik dengan bintang")
	check(m.skill_value("resi") == 0.0, "penasihat yang belum dimiliki tanpa skill")
	var silver_before := m.affair_yield("silver")
	m.counselors["sekar"]["stars"] = 0
	check(m.affair_yield("silver") < silver_before, "skill pajak menaikkan hasil pajak")
	var losses := m.expected_losses()
	m._grant_counselor("gajah", "sr")
	check(m.expected_losses() < losses, "skill Gajah mengurangi korban")
	var cost := m.upgrade_cost("arya")
	m.counselors["arya"]["level"] = 10
	cost = m.upgrade_cost("arya")
	m._grant_counselor("danu", "r")
	check(m.upgrade_cost("arya") < cost, "skill Danu memotong biaya latih")
	check(m.combat_power() == m.power(), "tanpa skill tempur, kekuatan tempur = kekuatan")
	m._grant_counselor("satria", "ssr")
	check(m.combat_power() > m.power(), "skill tempur menaikkan kekuatan tempur")
	for id in ["sekar", "wening"]:
		m._grant_counselor(id, "r")
		m.counselors[id]["stars"] = 5
	m._grant_counselor("dewi", "sr")
	m._grant_counselor("resi", "ssr")
	check(m.skill_bonus("yield_silver") <= Data.SKILL_CAP, "bonus skill dibatasi")


func test_bonds() -> void:
	var m := fresh()
	check(m.bonds_active().is_empty(), "belum ada ikatan")
	m._grant_counselor("gajah", "sr")
	check(m.bonds_active().is_empty(), "ikatan butuh semua anggota")
	m._grant_counselor("satria", "ssr")
	var names: Array = m.bonds_active().map(func(b): return b["name"])
	check("Pendekar Nusantara" in names, "ikatan Pendekar Nusantara aktif")
	var sk := m.skill_bonus("combat")
	check(is_equal_approx(sk, m.skill_value("satria") + 0.10), "bonus ikatan ditambahkan")
	for b in Data.BONDS:
		for id in b["members"]:
			check(Data.SKILLS.has(id) and not Data.counselor_def(id).is_empty(), "anggota ikatan valid: %s" % id)


func test_prison() -> void:
	var m := fresh(5)
	m.soldiers = 100000000
	for i in 30:
		m.fight_stage()
	check(m.prison["prisoners"].size() == Data.PRISON_CAPACITY, "tahanan tertangkap sampai penjara penuh")
	var p: Dictionary = m.prison["prisoners"][0]
	check(p["hp"] == p["max"] and p["max"] > 0, "tahanan dengan daya tahan")
	m.grain = 1000000
	m.silver = 0
	var r := m.interrogate(0, "interrogate", 1000.0)
	check(r["ok"] and m.prison["prisoners"][0]["hp"] < p["max"], "interogasi mengurangi daya tahan")
	check(m.silver == Data.PRISON_HIT_SILVER and m.grain == 1000000 - Data.PRISON_COST_GRAIN, "biaya dan perak interogasi")
	check(not m.interrogate(0, "palsu", 1000.0)["ok"], "cara tidak dikenal ditolak")
	m.prison["prisoners"][0]["hp"] = 1
	var prestige := m.prestige
	var c := m.interrogate(0, "intimidate", 1000.0)
	check(c.get("confessed", false) and m.prestige > prestige, "tahanan mengaku memberi hadiah")
	check(m.prison["prisoners"].size() == Data.PRISON_CAPACITY - 1, "tahanan yang mengaku keluar dari penjara")
	for i in Data.PRISON_DAILY_LIMIT:
		m.interrogate(0, "interrogate", 1000.0)
	check(not m.interrogate(0, "interrogate", 1000.0)["ok"] and m.prison_left(1000.0 + 86400) == Data.PRISON_DAILY_LIMIT,
		"batas interogasi harian")
	prestige = m.prestige
	check(m.release_prisoner(0)["ok"] and m.prestige == prestige + Data.PRISON_RELEASE_PRESTIGE, "bebaskan tahanan")
	m.grain = 0
	check(not m.interrogate(0, "interrogate", 1000.0 + 86400)["ok"], "interogasi butuh pangan")
	var m2 := Model.new()
	m2.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())), 1000.0)
	check(var_to_str(m2.prison) == var_to_str(m.prison), "simpan/muat penjara")


func test_exam_officials() -> void:
	var m := fresh(2)
	m.children.append({"name": "Gita", "gender": "f", "mother": "melati", "talent": 5, "level": 10})
	m.children.append({"name": "Adi", "gender": "m", "mother": "melati", "talent": 1, "level": 3})
	check(not m.take_exam(1, 1000.0)["ok"], "anak belum dewasa tidak bisa ujian")
	check(absf(m.exam_chance(0) - 0.9) < 0.001, "peluang lulus dari bakat")
	m.silver = 0
	check(not m.take_exam(0, 1000.0)["ok"], "ujian butuh perak")
	m.silver = 100000
	var yield_before := m.affair_yield("silver")
	var passed := false
	var day := 0
	while not passed and day < 20:
		var r := m.take_exam(0, 1000.0 + day * 86400)
		passed = r["ok"]
		if not passed:
			check(r.get("exam", false) and not m.exam_available(0, 1000.0 + day * 86400), "gagal ujian: coba besok")
		day += 1
	check(passed and m.officials.size() == 1 and m.children.size() == 1, "anak lulus menjadi pejabat")
	check(m.officials_bonus() > 0.0 and m.affair_yield("silver") > yield_before, "pejabat menaikkan hasil urusan")
	var m2 := Model.new()
	m2.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())), 1000.0)
	check(var_to_str(m2.officials) == var_to_str(m.officials), "simpan/muat pejabat")


func test_banquet() -> void:
	var m := fresh()
	m.silver = 100000
	m.grain = 100000
	var prestige := m.prestige
	check(m.hold_banquet("simple", 1000.0)["ok"] and m.prestige > prestige, "jamuan sederhana memberi prestise")
	check(m.silver == 95000 and m.grain == 97000, "biaya jamuan")
	check(not m.hold_banquet("simple", 1000.0)["ok"] and m.banquet_available("simple", 1000.0 + 86400), "sekali per hari")
	m.gold = 0
	check(not m.hold_banquet("grand", 1000.0)["ok"], "pesta agung butuh emas")
	var invites := m.banquet_invites(1000.0)
	check(invites.size() == Data.INVITES_PER_DAY and var_to_str(m.banquet_invites(1000.0)) == var_to_str(invites),
		"undangan harian stabil")
	prestige = m.prestige
	check(m.attend_banquet(0, 1000.0)["ok"] and m.prestige == prestige + Data.INVITE_PRESTIGE, "hadiri undangan")
	check(not m.attend_banquet(0, 1000.0)["ok"] and m.banquet_invites(1000.0)[0]["attended"], "undangan sekali")
	check(not m.banquet_invites(1000.0 + 86400)[0]["attended"], "undangan baru besok")
	var a := _allied()
	a.gold = 1000
	var exp: int = a.alliance["exp"]
	check(a.hold_banquet("grand", 1000.0)["ok"] and int(a.alliance["exp"]) == exp + 100, "pesta agung menambah exp aliansi")
	var m2 := Model.new()
	m2.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())), 1000.0)
	check(var_to_str(m2.banquet) == var_to_str(m.banquet), "simpan/muat perjamuan")


func test_story() -> void:
	var m := fresh()
	check(m.story["chapter"] == 0 and m.story_quests().size() == 3, "bab 1 dengan 3 misi")
	check(m.story_pending_dialog() == -1, "cerita ditunda selama tutorial")
	m.skip_tutorial()
	check(m.story_pending_dialog() == 0, "cerita bab 1 menunggu ditampilkan")
	m.mark_story_seen(0)
	check(m.story_pending_dialog() == -1, "cerita tampil sekali")
	check(not m.claim_quest(0)["ok"], "misi belum selesai")
	m.soldiers = 100000000
	m.fight_stage()
	var gold := m.gold
	check(m.claim_quest(0)["ok"] and m.gold == gold + 30, "klaim misi utama")
	check(not m.claim_quest(0)["ok"], "misi utama sekali")
	check(not m.claim_chapter()["ok"], "bab belum tamat")
	m.counselors["arya"]["level"] = 5
	m.claim_quest(1)
	m.claim_quest(2)
	check(m.story_claimable() == 1, "hadiah bab siap")
	gold = m.gold
	check(m.claim_chapter()["ok"] and m.story["chapter"] == 1 and m.gold == gold + 100, "bab tamat, lanjut bab 2")
	check(m.story_pending_dialog() == 1, "cerita bab 2 menunggu")
	for ch in Data.STORY_CHAPTERS:
		for q in ch["quests"]:
			check(m.story_metric(q["type"]) >= 0 and q["type"] in ["stage", "power", "rank", "counselors", "max_level",
				"prestige", "children_total", "intimacy", "alliance", "arena_wins", "officials", "stars_total"],
				"jenis misi dikenal: %s" % q["type"])
	var m2 := Model.new()
	m2.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())), 1000.0)
	check(var_to_str(m2.story) == var_to_str(m.story), "simpan/muat misi utama")
	m.story["chapter"] = Data.STORY_CHAPTERS.size()
	check(m.story_done() and m.story_quests().is_empty() and not m.claim_chapter()["ok"], "cerita tamat")


func test_away_report() -> void:
	var m := fresh()
	m.skip_tutorial()
	var t := 1000.0
	m.do_affair("silver", t)
	m.do_affair("silver", t)
	var snap := m.away_snapshot(t)
	check(m.away_report(snap, t + 60.0).is_empty(), "tidak ada ringkasan bila pergi sebentar")
	check(m.away_report({}, t + 9999.0).is_empty(), "tanpa snapshot tidak ada ringkasan")
	var r := m.away_report(snap, t + 600.0)
	check(r["seconds"] == 600, "lama pergi tercatat")
	check(r["lines"].any(func(l): return "Tarik Pajak +2" in l["text"]), "urusan yang terisi dilaporkan")
	var later := t + 3 * 86400.0
	r = m.away_report(m.away_snapshot(t), later)
	check(r["lines"].any(func(l): return "Hari baru" in l["text"]), "hari baru dilaporkan")
	# snapshot ikut tersimpan lewat JSON (angka menjadi float)
	var snap2 = JSON.parse_string(JSON.stringify(m.away_snapshot(later)))
	r = m.away_report(snap2, later + 400.0)
	check(not r.is_empty() and r["lines"].size() >= 1, "ringkasan dari snapshot JSON")


func test_lord_name() -> void:
	var m := fresh()
	check(m.lord_name == "" and m.me_name() == "Anda", "nama default")
	check(not m.set_lord_name(" !! ")["ok"], "nama terlalu pendek ditolak")
	check(m.set_lord_name("  Wira   Jaya<b> ")["ok"] and m.lord_name == "Wira Jayab", "nama dibersihkan")
	check(not m.set_lord_name("Wira Jayab")["ok"], "nama sama ditolak")
	m.set_lord_name("Abcdefghijklmnopqrstu")
	check(m.lord_name.length() == m.NAME_MAX, "nama dipotong ke batas")
	var m2 := Model.new()
	m2.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())), 1000.0)
	check(m2.lord_name == m.lord_name and m2.me_name() == m.lord_name, "simpan/muat nama")
	m2.new_game(1000.0)
	check(m2.lord_name == "", "game baru menghapus nama")
