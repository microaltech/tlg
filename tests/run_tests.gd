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
