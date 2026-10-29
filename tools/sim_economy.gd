extends SceneTree
## Bot simulasi ekonomi: memainkan GameModel selama N hari dengan beberapa sesi
## per hari (pemain gratis, tanpa IAP), lalu mencetak tabel progres harian.
##
##   godot --headless --path . --script res://tools/sim_economy.gd -- [hari] [sesi/hari] [seed]
##
## Dipakai untuk menyeimbangkan angka di game_data.gd: kecepatan naik tahap,
## jabatan, emas masuk/keluar, dan sumber daya yang menumpuk atau kurang.

const Model := preload("res://scripts/core/game_model.gd")
const Data := preload("res://scripts/core/game_data.gd")

## Jam sesi bermain (jam lokal) untuk 2–6 sesi per hari.
const SESSION_HOURS := {
	2: [8.0, 20.0],
	3: [8.0, 13.0, 21.0],
	4: [7.5, 12.5, 18.0, 22.0],
	6: [7.0, 10.0, 13.0, 16.0, 19.0, 22.0],
}

var m: Model
var stats := {}
var watch_ads := true


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var days := int(args[0]) if args.size() > 0 else 30
	var sessions := int(args[1]) if args.size() > 1 else 4
	var seed_value := int(args[2]) if args.size() > 2 else 1
	watch_ads = not (args.size() > 3 and args[3] == "noads")
	run(days, sessions, seed_value)
	quit()


func run(days: int, sessions: int, seed_value: int) -> void:
	m = Model.new()
	m.rng.seed = seed_value
	var start := 20000 * 86400.0  # tengah malam UTC; tz_bias 0
	m.new_game(start)
	m.skip_tutorial()
	stats = {"gold_src": {}, "births": 0, "gold_in": 0, "gold_gacha": 0, "pulls": 0, "fails": 0, "wins": 0, "level_capped": 0}
	print("hari | tahap | jabatan          | kekuatan | penasihat | perak    | pangan   | prajurit | emas  | rekrut | anak | aliansi | arena")
	var hours: Array = SESSION_HOURS.get(sessions, SESSION_HOURS[4])
	var rank_day := {}
	var stage_at := {}
	for day in days:
		for h in hours:
			session(start + day * 86400.0 + h * 3600.0)
		row(day + 1)
		if not rank_day.has(m.rank):
			for r in m.rank + 1:
				if not rank_day.has(r):
					rank_day[r] = day + 1
		stage_at[day + 1] = m.stage
	var ranks := []
	for r in range(1, Data.RANKS.size()):
		ranks.append("%s:h%s" % [Data.RANKS[r]["name"], str(rank_day.get(r, "-"))])
	var stages := []
	for d in [1, 3, 7, 14, 21, 30]:
		if stage_at.has(d):
			stages.append("h%d=%d" % [d, stage_at[d]])
	print("")
	print("Tonggak: tahap ", " ".join(stages), " | ", " ".join(ranks), " | prestise ", m.prestige)
	print("")
	print("Ringkasan %d hari, %d sesi/hari, seed %d:" % [days, sessions, seed_value])
	print("  emas didapat %d, dipakai rekrut %d (%d tarikan)" % [stats["gold_in"], stats["gold_gacha"], stats["pulls"]])
	print("  sumber emas: ", stats["gold_src"])
	print("  anak lahir %d, menikah %d, pejabat %d" % [stats["births"], m.married_count, m.officials.size()])
	print("  kampanye: %d menang, %d kalah; sesi tertahan batas level: %d" % [
		stats["wins"], stats["fails"], stats["level_capped"]])
	print("  bangunan: ", m.buildings["levels"])
	print("  penasihat: %d/%d, bintang total %d, cerita bab %d" % [
		m.counselors.size(), Data.COUNSELORS.size(), m.story_metric("stars_total"), m.story["chapter"] + 1])


func gold_add(before: int, source := "lain") -> void:
	if m.gold > before:
		stats["gold_in"] += m.gold - before
		var src: Dictionary = stats["gold_src"]
		src[source] = int(src.get(source, 0)) + m.gold - before


func session(now: float) -> void:
	m.sync(now)
	var g := m.gold
	if m.login_can_claim(now):
		m.claim_login(now)
	if m.vip_daily_can_claim(now):
		m.claim_vip_daily(now)
	if m.free_pull_eta(now) == 0:
		m.recruit(1, now, true)
	while m.item_count("recruit_ticket") > 0:
		m.recruit(1, now, false, true)
	gold_add(g, "login/vip")

	# Urusan kota sampai charge habis.
	for kind in ["silver", "grain", "soldiers"]:
		while m.do_affair(kind, now)["ok"]:
			pass
	# Item: teh mengisi urusan, gulungan ke penasihat terkuat.
	if m.item_count("tea") > 0 and m.use_item("tea", "", now)["ok"]:
		for kind in ["silver", "grain", "soldiers"]:
			while m.do_affair(kind, now)["ok"]:
				pass

	# Istana: kunjungi selir, didik anak, nikahkan / ujian yang dewasa.
	var ids: Array = m.beauties.keys()
	var i := 0
	var kids := m.children.size()
	while not ids.is_empty() and m.visit_beauty(ids[i % ids.size()], now)["ok"]:
		i += 1
	stats["births"] += m.children.size() - kids
	for c in range(m.children.size() - 1, -1, -1):
		m.train_child(c, now)
	for c in range(m.children.size() - 1, -1, -1):
		if int(m.children[c]["level"]) >= Data.CHILD_MAX_LEVEL:
			if m.exam_available(c, now) and m.silver >= m.exam_cost(c) and m.officials.size() < Data.OFFICIALS_MAX:
				m.take_exam(c, now)
			elif c < m.children.size() and int(m.children[c]["level"]) >= Data.CHILD_MAX_LEVEL:
				m.marry_child(c)

	# Kampanye selama prajurit cukup (sisakan cadangan 10%).
	g = m.gold
	while m.soldiers >= m.expected_losses() * 1.1:
		var r := m.fight_stage()
		stats["wins" if r["ok"] else "fails"] += 1
		if not r["ok"]:
			break
	while m.can_promote():
		m.promote()
	gold_add(g, "kampanye/jabatan")

	# Bangunan: bangun yang termurah bila perak masih cukup untuk 2x biayanya.
	if m.build_job().is_empty():
		var pick := ""
		for id in Data.BUILDING_ORDER:
			if m.building_level(id) < m.building_cap(id) and (pick == "" or m.building_cost(id) < m.building_cost(pick)):
				pick = id
		if pick != "" and m.silver >= m.building_cost(pick) * 2:
			m.start_build(pick, now)

	# Latih penasihat termurah selama perak cukup.
	var capped := false
	while true:
		var best := ""
		var best_cost := 1 << 40
		for id in m.counselors:
			if int(m.counselors[id]["level"]) >= int(m.rank_info()["level_cap"]):
				capped = true
				continue
			var cost := m.upgrade_cost(id)
			if cost < best_cost:
				best_cost = cost
				best = id
		if best == "" or m.silver < best_cost or not m.upgrade_counselor(best)["ok"]:
			break
	if capped:
		stats["level_capped"] += 1

	# Penjara.
	while not m.prison["prisoners"].is_empty() and m.prison_left(now) > 0:
		if not m.interrogate(0, "interrogate", now)["ok"]:
			break

	# Aliansi, bos, perang, arena.
	g = m.gold
	if m.alliance.is_empty() and m.alliance_unlocked():
		m.join_alliance(Data.ALLIANCES[0]["id"], now)
	if not m.alliance.is_empty():
		for kind in ["silver", "grain"]:
			if m.donations_left(now) > 0:
				m.donate(kind, now)
		while m.attack_boss(now)["ok"]:
			pass
		m.claim_boss(now)
		for item in Data.ALLIANCE_SHOP:
			while m.shop_buy(item["id"], now)["ok"]:
				pass
		if not m.war.is_empty():
			for f in Data.WAR_FORTS.size():
				while m.war_attacks_left(now) > 0 and not m.war_fort_locked(f) and m.attack_fort(f, now)["ok"]:
					pass
		if not m.war_reward.is_empty():
			m.claim_war_reward()
	if m.arena_unlocked():
		m.ensure_arena(now)
		while m.arena_tickets_left(now) > 0 and not m.arena["opponents"].is_empty():
			# lawan dengan peluang menang terbaik
			var pick := 0
			for o in m.arena["opponents"].size():
				if m.arena_win_chance(m.arena["opponents"][o]["power"]) > m.arena_win_chance(m.arena["opponents"][pick]["power"]):
					pick = o
			if not m.arena_fight(pick, now)["ok"]:
				break
		if not m.arena["season_reward"].is_empty():
			m.claim_arena_season()
		for item in Data.ARENA_SHOP:
			while m.arena_shop_buy(item["id"], now)["ok"]:
				pass
	if not m.leaderboard.get("reward", {}).is_empty():
		m.claim_lb_reward()
	gold_add(g, "aliansi/arena/peringkat")
	g = m.gold

	# Klaim semua hadiah misi, peti, event, cerita.
	for idx in m.daily["missions"].size():
		m.claim_mission(idx)
	for idx in Data.DAILY_CHESTS.size():
		m.claim_chest(idx)
	for idx in Data.EVENT_TIERS.size():
		m.claim_event_tier(idx)
	for idx in m.story_quests().size():
		m.claim_quest(idx)
	m.claim_chapter()
	gold_add(g, "misi/event/cerita")

	# Fitur tambahan: menara, Tiket Musim (jalur gratis), pencapaian, dan iklan
	# berhadiah (pemain gratis yang mau menonton iklan).
	g = m.gold
	if m.tower_unlocked():
		while m.tower_attempts_left(now) > 0:
			m.tower_fight(now)
	m.claim_pass_all(now)
	m.check_achievements()
	for a in Data.ACHIEVEMENTS:
		while m.claim_achievement(a["id"])["ok"]:
			pass
	if not m.festival.is_empty():
		m.claim_festival_gift(now)
		for t in Data.FESTIVAL_TASKS:
			m.claim_festival_task(t["id"], now)
		for item in Data.FESTIVAL_SHOP:
			while m.festival_buy(item["id"], now)["ok"]:
				pass
	gold_add(g, "menara/pass/pencapaian")
	g = m.gold
	if watch_ads:
		for kind in Data.AD_REWARDS:
			while m.ad_left(kind, now) > 0:
				m.grant_ad_reward(kind, now)
	gold_add(g, "iklan")

	# Rekrut x10 dengan emas yang terkumpul (pemain gratis menabung untuk x10).
	while m.gold >= Data.GACHA_COST_10:
		if not m.recruit(10, now)["ok"]:
			break
		stats["gold_gacha"] += Data.GACHA_COST_10
		stats["pulls"] += 10


func row(day: int) -> void:
	print("%4d | %5d | %-16s | %8d | %9d | %8d | %8d | %8d | %5d | %6d | %4d | %7s | %5s" % [
		day, m.stage, m.rank_info()["name"], m.combat_power(), m.counselors.size(), m.silver, m.grain,
		m.soldiers, m.gold, stats["pulls"], m.children.size(),
		("Lv.%d" % m.alliance_level()) if not m.alliance.is_empty() else "-",
		str(m.arena.get("rating", "-")) if not m.arena.is_empty() else "-"])
