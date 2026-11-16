extends "res://scripts/core/game_model_realm.gd"
## GameModel lengkap: fitur tambahan (acara bulanan, kostum, kotak surat, pewaris, dapur,
## konfigurasi jarak jauh, sapu tahap, dekorasi, raid, hari besar, perjalanan 7 hari).
## Inilah kelas yang dipakai game dan tes (preload game_model.gd).

# --- Batch 7: muat & validasi ------------------------------------------------------

func _load_realm7(src: Dictionary) -> void:
	var me = src.get("month_event", {})
	if me is Dictionary:
		var base := {}
		for k in me.get("base", {}):
			base[str(k)] = int(me["base"][k])
		var done := []
		for i in me.get("done", []):
			if int(i) >= 0 and int(i) < 5 and not done.has(int(i)):
				done.append(int(i))
		realm["month_event"] = {"month": int(me.get("month", -1)), "base": base, "done": done,
			"final": bool(me.get("final", false))}
	var sk = src.get("skins", {})
	if sk is Dictionary:
		for id in sk.get("owned", []):
			if Data.SKINS.has(str(id)) and not realm["skins"]["owned"].has(str(id)):
				realm["skins"]["owned"].append(str(id))
		var worn = sk.get("worn", {})
		if worn is Dictionary:
			for c in worn:
				var id := str(worn[c])
				if realm["skins"]["owned"].has(id) and Data.SKINS[id]["counselor"] == str(c):
					realm["skins"]["worn"][str(c)] = id
	var src_mail = src.get("mail", null)
	if src_mail is Array:
		realm["mail"] = []
		for m in src_mail:
			if m is Dictionary and m.get("id") is String and m["id"] != "" and realm["mail"].size() < Data.MAIL_KEEP:
				realm["mail"].append({"id": str(m["id"]), "title": str(m.get("title", "")), "body": str(m.get("body", "")),
					"reward": _safe_reward(m.get("reward", {})), "claimed": bool(m.get("claimed", false)),
					"t": float(m.get("t", 0.0))})
	for id in src.get("mail_claimed", []):
		if str(id).length() <= 64 and not realm["mail_claimed"].has(str(id)):
			realm["mail_claimed"].append(str(id))


## Hadiah dari sumber luar (surat server, kode) dibatasi GIFT_CODE_LIMITS.
func _safe_reward(reward) -> Dictionary:
	var safe := {}
	if not (reward is Dictionary):
		return safe
	for k in Data.GIFT_CODE_LIMITS:
		if reward.has(k):
			safe[k] = clampi(int(reward[k]), 0, int(Data.GIFT_CODE_LIMITS[k]))
	var items = reward.get("items", {})
	if items is Dictionary:
		for it in items:
			if Data.ITEMS.has(str(it)):
				if not safe.has("items"):
					safe["items"] = {}
				safe["items"][str(it)] = clampi(int(items[it]), 0, Data.GIFT_CODE_ITEM_LIMIT)
	return safe


# --- Acara sejarah bulanan -----------------------------------------------------------------

func month_index(now: float) -> int:
	var d := Time.get_datetime_dict_from_unix_time(int(now + tz_bias))
	return int(d["year"]) * 12 + int(d["month"]) - 1


func month_event_def(now: float) -> Dictionary:
	return Data.MONTH_EVENTS[posmod(month_index(now), Data.MONTH_EVENTS.size())]


## Mulai acara bulan baru: catat penghitung saat ini sebagai titik nol.
func ensure_month_event(now: float) -> void:
	var me: Dictionary = realm["month_event"]
	if int(me["month"]) == month_index(now):
		return
	var base := {}
	for m in month_event_def(now)["missions"]:
		base[m["event"]] = int(counters.get(m["event"], 0))
	realm["month_event"] = {"month": month_index(now), "base": base, "done": [], "final": false}


func month_event_progress(index: int, now: float) -> int:
	ensure_month_event(now)
	var m: Dictionary = month_event_def(now)["missions"][index]
	return mini(int(m["target"]), int(counters.get(m["event"], 0)) - int(realm["month_event"]["base"].get(m["event"], 0)))


func month_event_days_left(now: float) -> int:
	var d := Time.get_datetime_dict_from_unix_time(int(now + tz_bias))
	var y := int(d["year"])
	var mo := int(d["month"])
	var next := Time.get_unix_time_from_datetime_dict({"year": y + (1 if mo == 12 else 0), "month": 1 if mo == 12 else mo + 1,
		"day": 1, "hour": 0, "minute": 0, "second": 0})
	return int(ceil((next - (now + tz_bias)) / 86400.0))


func month_event_claimable(now: float) -> int:
	var n := 0
	var ev := month_event_def(now)
	for i in ev["missions"].size():
		if not realm["month_event"]["done"].has(i) and month_event_progress(i, now) >= int(ev["missions"][i]["target"]):
			n += 1
	return n + (1 if realm["month_event"]["done"].size() == ev["missions"].size() and not realm["month_event"]["final"] else 0)


func claim_month_mission(index: int, now: float) -> Dictionary:
	ensure_month_event(now)
	var ev := month_event_def(now)
	if index < 0 or index >= ev["missions"].size():
		return _fail("Tugas tidak ditemukan.")
	var me: Dictionary = realm["month_event"]
	if me["done"].has(index):
		return _fail("Hadiah tugas ini sudah diambil.")
	var m: Dictionary = ev["missions"][index]
	if month_event_progress(index, now) < int(m["target"]):
		return _fail("Tugas belum selesai.")
	me["done"].append(index)
	var text := _give_rewards(m["reward"])
	changed.emit()
	return _ok("Tugas acara selesai: %s." % text)


## Hadiah akhir: emas, kostum acara, dan bingkai acara.
func claim_month_final(now: float) -> Dictionary:
	ensure_month_event(now)
	var ev := month_event_def(now)
	var me: Dictionary = realm["month_event"]
	if me["final"]:
		return _fail("Hadiah akhir acara sudah diambil.")
	if me["done"].size() < ev["missions"].size():
		return _fail("Selesaikan semua tugas acara dulu.")
	me["final"] = true
	gold += Data.MONTH_EVENT_GOLD
	unlock_cosmetic("frame_acara_" + str(ev["id"]))
	var skin: String = ev["skin"]
	if not realm["skins"]["owned"].has(skin):
		realm["skins"]["owned"].append(skin)
	_track("month_event")
	changed.emit()
	return _ok("Acara %s tuntas! +%d emas, kostum %s, dan bingkai baru." % [ev["name"], Data.MONTH_EVENT_GOLD,
		Data.SKINS[skin]["name"]])


# --- Kostum penasihat -------------------------------------------------------------------

func owns_skin(id: String) -> bool:
	return realm["skins"]["owned"].has(id)


func skin_worn(counselor_id: String) -> String:
	return str(realm.get("skins", {}).get("worn", {}).get(counselor_id, ""))


func buy_skin(id: String) -> Dictionary:
	var def: Dictionary = Data.SKINS.get(id, {})
	if def.is_empty():
		return _fail("Kostum tidak dikenal.")
	if owns_skin(id):
		return _fail("Kostum ini sudah dimiliki.")
	if not def.has("gold"):
		return _fail("Kostum ini hadiah acara bulanan.")
	if gold < int(def["gold"]):
		return _fail("Emas tidak cukup (butuh %d)." % def["gold"])
	gold -= int(def["gold"])
	realm["skins"]["owned"].append(id)
	_track("skin")
	changed.emit()
	return _ok("Kostum %s didapat!" % def["name"])


## Pakai kostum (id kosong = kembali ke busana asli penasihat `counselor_id`).
func wear_skin(counselor_id: String, id: String) -> Dictionary:
	if id == "":
		realm["skins"]["worn"].erase(counselor_id)
		changed.emit()
		return _ok("Busana asli dipakai kembali.")
	if not owns_skin(id):
		return _fail("Kostum belum dimiliki.")
	if Data.SKINS[id]["counselor"] != counselor_id:
		return _fail("Kostum ini bukan untuk penasihat itu.")
	realm["skins"]["worn"][counselor_id] = id
	changed.emit()
	return _ok("%s kini memakai %s." % [Data.counselor_def(counselor_id)["name"], Data.SKINS[id]["name"]])


## Peta penasihat -> potret kostum yang dipakai (untuk Art).
func skin_portraits() -> Dictionary:
	var out := {}
	for id in realm.get("heirs", {}):
		out[id] = "heir_" + str(realm["heirs"][id].get("gender", "m"))
	for c in realm.get("skins", {}).get("worn", {}):
		out[c] = realm["skins"]["worn"][c]
	return out


# --- Kotak surat ---------------------------------------------------------------------------

## Tambah surat lokal (tanpa server). Id sama tidak ditambah dua kali.
func add_mail(mail: Dictionary, now: float) -> bool:
	var id := str(mail.get("id", ""))
	if id == "" or realm["mail"].any(func(m): return m["id"] == id) or realm["mail_claimed"].has(id):
		return false
	realm["mail"].push_front({"id": id, "title": str(mail.get("title", "")), "body": str(mail.get("body", "")),
		"reward": _safe_reward(mail.get("reward", {})), "claimed": false, "t": now})
	while realm["mail"].size() > Data.MAIL_KEEP:
		realm["mail"].pop_back()
	return true


func mail_unread() -> int:
	return realm["mail"].filter(func(m): return not m["claimed"] and not m["reward"].is_empty()).size()


func claim_mail(id: String) -> Dictionary:
	for m in realm["mail"]:
		if m["id"] != id:
			continue
		if m["claimed"]:
			return _fail("Hadiah surat ini sudah diambil.")
		m["claimed"] = true
		realm["mail_claimed"].append(id)
		var text := _give_rewards(m["reward"])
		_track("mail")
		changed.emit()
		return _ok("Isi surat diterima: %s." % (text if text != "" else "-"))
	return _fail("Surat tidak ditemukan.")


## Hadiah surat dari server (sudah ditandai diklaim di server). Dicatat agar tidak dobel.
func claim_server_mail(id: String, reward: Dictionary) -> Dictionary:
	var key := "server:" + id
	if realm["mail_claimed"].has(key):
		return _fail("Hadiah surat ini sudah diambil.")
	realm["mail_claimed"].append(key)
	while realm["mail_claimed"].size() > 200:
		realm["mail_claimed"].pop_front()
	for m in realm["mail"]:
		if m["id"] == key:
			m["claimed"] = true
	var text := _give_rewards(_safe_reward(reward))
	_track("mail")
	changed.emit()
	return _ok("Isi surat diterima: %s." % (text if text != "" else "-"))


# --- Uji cepat (hanya dipanggil dari panel debug di build debug) ---------------------------

func debug_skip_stages(n: int) -> Dictionary:
	stage += maxi(0, n)
	changed.emit()
	return _ok("Tahap dilompati ke %d." % (stage + 1))


func debug_grant() -> Dictionary:
	silver += 1000000
	grain += 1000000
	soldiers += 1000000
	gold += 5000
	prestige += 5000
	for id in ["recruit_ticket", "energy_tea", "star_stone", "scroll_train"]:
		if Data.ITEMS.has(id):
			add_item(id, 10)
	changed.emit()
	return _ok("Sumber daya uji ditambahkan.")



# --- Batch 8: sejarah harian, pewaris, dapur, musim aliansi, pasar pemain ----------------

func _load_realm8(src: Dictionary) -> void:
	realm["history_day"] = int(src.get("history_day", -1))
	realm["heirs"] = Data.heirs.duplicate(true)
	realm["heir_seq"] = maxi(int(src.get("heir_seq", 0)), realm["heirs"].size())
	var k = src.get("kitchen", {})
	if k is Dictionary:
		var meal = k.get("meal", {})
		var mid := str(meal.get("id", "")) if meal is Dictionary else ""
		realm["kitchen"] = {"day": int(k.get("day", -1)), "used": clampi(int(k.get("used", 0)), 0, Data.KITCHEN_DAILY),
			"meal": {"id": mid if Data.RECIPES.has(mid) else "", "until": float(meal.get("until", 0.0)) if mid != "" else 0.0,
				"mult": clampf(float(meal.get("mult", 1.0)) if mid != "" else 1.0, 0.0, Data.KITCHEN_QUALITY[-1])}}
	for v in src.get("season_claimed", []):
		if not realm["season_claimed"].has(int(v)):
			realm["season_claimed"].append(int(v))


## Pewaris dari save: hanya id "heir_N" dengan atribut dalam batas wajar.
func _parse_heirs(src) -> Dictionary:
	var out := {}
	if not (src is Dictionary):
		return out
	for id in src:
		var h = src[id]
		if not (h is Dictionary) or not str(id).begins_with("heir_") or out.size() >= Data.HEIR_MAX:
			continue
		var def := {"id": str(id), "name": str(h.get("name", "Pewaris")).left(24),
			"rarity": "sr" if str(h.get("rarity", "r")) == "sr" else "r", "gender": "f" if str(h.get("gender", "m")) == "f" else "m",
			"unlock_stage": -1, "heir": true}
		for a in Data.ATTRS:
			def[a] = clampi(int(h.get(a, 1)), 1, 20)
		out[str(id)] = def
	return out


# Hari ini dalam sejarah ------------------------------------------------------------

func history_key(now: float) -> String:
	var d := Time.get_datetime_dict_from_unix_time(int(now + tz_bias))
	return "%02d-%02d" % [int(d["month"]), int(d["day"])]


## Peristiwa hari ini, atau yang terdekat sebelumnya: {date, year, text, exact}.
func history_today(now: float) -> Dictionary:
	var key := history_key(now)
	var keys: Array = Data.HISTORY.keys()
	keys.sort()
	var pick: String = keys[-1]  # awal Januari tanpa catatan: pakai akhir Desember
	for k in keys:
		if k <= key:
			pick = k
	var e: Array = Data.HISTORY[pick]
	return {"date": pick, "year": int(e[0]), "text": str(e[1]), "exact": pick == key}


func history_claimable(now: float) -> bool:
	return int(realm["history_day"]) != day_index(now)


func claim_history(now: float) -> Dictionary:
	if not history_claimable(now):
		return _fail("Kisah hari ini sudah dibaca. Kembali besok untuk kisah berikutnya.")
	realm["history_day"] = day_index(now)
	var reward: Dictionary = Data.HISTORY_REWARD.duplicate()
	reward["silver"] = int(affair_yield("silver") * Data.HISTORY_SILVER)
	var text := _give_rewards(reward)
	_track("history")
	changed.emit()
	return _ok("Pengetahuan bertambah: %s." % text)


# Pewaris ---------------------------------------------------------------------------

## Indeks anak dewasa yang bisa diangkat menjadi pewaris.
func heir_candidates() -> Array:
	var out := []
	for i in children.size():
		var c: Dictionary = children[i]
		if int(c["level"]) >= Data.CHILD_MAX_LEVEL and int(c["talent"]) >= Data.HEIR_TALENT_MIN:
			out.append(i)
	return out


func make_heir(index: int) -> Dictionary:
	if not heir_candidates().has(index):
		return _fail("Hanya anak dewasa berbakat %d ke atas yang bisa menjadi pewaris." % Data.HEIR_TALENT_MIN)
	if realm["heirs"].size() >= Data.HEIR_MAX:
		return _fail("Istana sudah punya %d pewaris." % Data.HEIR_MAX)
	if gold < int(Data.HEIR_COST["gold"]):
		return _fail("Emas tidak cukup (butuh %d)." % Data.HEIR_COST["gold"])
	gold -= int(Data.HEIR_COST["gold"])
	var child: Dictionary = children[index]
	var talent := int(child["talent"])
	realm["heir_seq"] = int(realm["heir_seq"]) + 1
	var id := "heir_%d" % realm["heir_seq"]
	var def := {"id": id, "name": str(child["name"]), "rarity": "sr" if talent >= 5 else "r",
		"gender": str(child.get("gender", "m")), "unlock_stage": -1, "heir": true}
	# Atribut: dasar dari bakat, ditambah bakat ibu pada atribut yang paling menonjol darinya.
	for a in Data.ATTRS:
		def[a] = 2 + talent * 2 + rng.randi_range(0, 3)
	var fav: String = Data.ATTRS[hash(str(child.get("mother", ""))) % Data.ATTRS.size()]
	def[fav] = int(def[fav]) + 3
	realm["heirs"][id] = def
	Data.heirs[id] = def
	counselors[id] = {"level": 1, "stars": 0, "bonus": {}}
	children.remove_at(index)
	_track("heir")
	changed.emit()
	return _ok("%s diangkat menjadi pewaris dan kini bertugas sebagai penasihat!" % def["name"])


# Dapur Nusantara -------------------------------------------------------------------

func kitchen_unlocked() -> bool:
	return stage >= Data.KITCHEN_UNLOCK_STAGE


func cooks_left(now: float) -> int:
	var k: Dictionary = realm["kitchen"]
	return Data.KITCHEN_DAILY - (int(k["used"]) if int(k["day"]) == day_index(now) else 0)


func recipe_cost(id: String) -> Dictionary:
	return _yields_of(Data.RECIPES[id]["cost"])


func meal_active(now: float) -> Dictionary:
	var meal: Dictionary = realm.get("kitchen", {}).get("meal", {})
	if str(meal.get("id", "")) == "" or float(meal.get("until", 0.0)) <= now:
		return {}
	return meal


func meal_bonus(effect: String, now: float) -> float:
	var meal := meal_active(now)
	if meal.is_empty():
		return 0.0
	return float(Data.RECIPES[meal["id"]]["effects"].get(effect, 0.0)) * float(meal["mult"])


## Masak hidangan. stars = jumlah adukan tepat di mini-game (0–3).
func cook(id: String, stars: int, now: float) -> Dictionary:
	if not kitchen_unlocked():
		return _fail("Dapur terbuka di Tahap %d." % Data.KITCHEN_UNLOCK_STAGE)
	if not Data.RECIPES.has(id):
		return _fail("Resep tidak dikenal.")
	if cooks_left(now) <= 0:
		return _fail("Juru masak sudah lelah. Dapur buka lagi besok.")
	var cost := recipe_cost(id)
	for k in cost:
		if int(get(k)) < int(cost[k]):
			return _fail("Bahan tidak cukup (%s)." % Data.REWARD_NAMES.get(k, k))
	for k in cost:
		set(k, int(get(k)) - int(cost[k]))
	var k: Dictionary = realm["kitchen"]
	if int(k["day"]) != day_index(now):
		k["day"] = day_index(now)
		k["used"] = 0
	k["used"] = int(k["used"]) + 1
	stars = clampi(stars, 0, 3)
	var mult: float = Data.KITCHEN_QUALITY[stars]
	k["meal"] = {"id": id, "until": now + Data.KITCHEN_HOURS * 3600.0, "mult": mult}
	_track("cook")
	changed.emit()
	var quality: String = ["Agak gosong", "Lumayan", "Lezat", "Sempurna!"][stars]
	return _ok("%s: %s Berkah hidangan x%s selama %d jam." % [Data.RECIPES[id]["name"], quality, str(mult),
		Data.KITCHEN_HOURS])


# Musim aliansi (hadiah dicek server) --------------------------------------------------

func claim_season_reward(season: int, season_rank: int, reward: Dictionary, frame: String) -> Dictionary:
	if realm["season_claimed"].has(season):
		return _fail("Hadiah musim ini sudah diambil.")
	realm["season_claimed"].append(season)
	var text := _give_rewards(_safe_reward(reward))
	if Data.COSMETICS.has(frame):
		unlock_cosmetic(frame)
	_track("season")
	changed.emit()
	return _ok("Hadiah musim (peringkat %d): %s dan bingkai baru!" % [season_rank, text])


# Pasar pemain (online) ----------------------------------------------------------------

## Pisahkan item dari tas untuk dijual (dikembalikan bila server menolak).
func market_reserve(item: String, qty: int) -> Dictionary:
	if not Data.BAZAAR_ITEMS.has(item):
		return _fail("Item ini tidak bisa dijual di pasar.")
	if qty < 1 or item_count(item) < qty:
		return _fail("Item di tas tidak cukup.")
	add_item(item, -qty)
	changed.emit()
	return _ok("")


func market_refund(item: String, qty: int) -> void:
	add_item(item, qty)
	changed.emit()


func market_bought(item: String, qty: int, price: int) -> Dictionary:
	if not Data.BAZAAR_ITEMS.has(item):
		return _fail("Item tidak dikenal.")
	silver = maxi(0, silver - price)
	add_item(item, clampi(qty, 0, 10))
	_track("bazaar")
	changed.emit()
	return _ok("Dibeli: %d %s." % [qty, Data.ITEMS[item]["name"]])



# --- Batch 9: konfigurasi jarak jauh, sapu tahap, dekorasi, saran, ulasan ----------------

func _load_realm9(src: Dictionary) -> void:
	var sw = src.get("sweep", {})
	if sw is Dictionary:
		realm["sweep"] = {"day": int(sw.get("day", -1)), "used": clampi(int(sw.get("used", 0)), 0, Data.SWEEP_DAILY)}
	for id in src.get("decor", []):
		if Data.DECORATIONS.has(str(id)) and not realm["decor"].has(str(id)):
			realm["decor"].append(str(id))
	var rv = src.get("review", {})
	if rv is Dictionary:
		realm["review"] = {"count": clampi(int(rv.get("count", 0)), 0, Data.REVIEW_MAX), "last": float(rv.get("last", 0.0))}


## Terapkan konfigurasi dari server (GET /v1/config) dengan batas aman.
func apply_remote(cfg: Dictionary) -> void:
	remote = {
		"yield_bonus": clampf(float(cfg.get("yield_bonus", 0.0)), 0.0, 1.0),
		"gacha_discount": clampf(float(cfg.get("gacha_discount", 0.0)), 0.0, 0.5),
		"rateup": str(cfg.get("rateup", "")),
		"event": str(cfg.get("event", "")),
		"min_version": int(cfg.get("min_version", 0)),
		"announcement": cfg.get("announcement") if cfg.get("announcement") is Dictionary else {},
		"groups": {},
	}
	# Uji A/B: varian dipilih tetap per pemasangan (hash ID pemasangan + id eksperimen).
	var exps = cfg.get("experiments", [])
	if exps is Array and install_id != "":
		for e in exps:
			if not (e is Dictionary) or not (e.get("variants") is Array) or e["variants"].size() < 2:
				continue
			var v: Dictionary = e["variants"][posmod(hash(install_id + ":" + str(e.get("id", ""))), e["variants"].size())]
			remote["groups"][str(e.get("id", ""))] = str(v.get("name", ""))
			var o: Dictionary = v.get("overrides", {}) if v.get("overrides") is Dictionary else {}
			if o.has("yield_bonus"):
				remote["yield_bonus"] = clampf(float(o["yield_bonus"]), 0.0, 1.0)
			if o.has("gacha_discount"):
				remote["gacha_discount"] = clampf(float(o["gacha_discount"]), 0.0, 0.5)
	changed.emit()


func gacha_cost(count: int) -> int:
	var base: int = Data.GACHA_COST if count == 1 else Data.GACHA_COST_10
	return int(ceil(base * (1.0 - float(remote.get("gacha_discount", 0.0)))))


func update_required() -> bool:
	return int(remote.get("min_version", 0)) > Data.VERSION_CODE


# Sapu tahap --------------------------------------------------------------------------

func sweeps_left(now: float) -> int:
	var sw: Dictionary = realm["sweep"]
	return Data.SWEEP_DAILY - (int(sw["used"]) if int(sw["day"]) == day_index(now) else 0)


## Biaya prajurit satu kali sapu (tahap terakhir yang dimenangkan).
func sweep_cost() -> int:
	if stage <= 0:
		return 0
	return int(int(Data.stage_info(stage - 1)["enemy_soldiers"]) * Data.SWEEP_LOSSES)


func sweep(count: int, now: float) -> Dictionary:
	if stage <= 0:
		return _fail("Menangkan satu tahap dulu.")
	count = mini(count, sweeps_left(now))
	if count <= 0:
		return _fail("Jatah sapu hari ini habis.")
	var cost := sweep_cost() * count
	if soldiers < cost:
		return _fail("Prajurit tidak cukup (butuh %d)." % cost)
	var info := Data.stage_info(stage - 1)
	soldiers -= cost
	var got_silver := int(int(info["reward_silver"]) * Data.SWEEP_SILVER) * count
	var got_prestige := int(int(info["reward_prestige"]) * Data.SWEEP_PRESTIGE) * count
	silver += got_silver
	prestige += got_prestige
	var items := []
	for i in count:
		if rng.randf() < Data.SWEEP_ITEM_CHANCE:
			var it: String = Data.STAGE_ITEM_POOL[rng.randi_range(0, Data.STAGE_ITEM_POOL.size() - 1)]
			add_item(it)
			items.append(Data.ITEMS[it]["name"])
	var sw: Dictionary = realm["sweep"]
	if int(sw["day"]) != day_index(now):
		sw["day"] = day_index(now)
		sw["used"] = 0
	sw["used"] = int(sw["used"]) + count
	_track("sweep", count)
	changed.emit()
	var msg := "Sapu %s x%d: -%d prajurit, +%d perak, +%d prestise." % [info["name"], count, cost, got_silver, got_prestige]
	if not items.is_empty():
		msg += " Rampasan: %s." % ", ".join(items)
	return _ok(msg)


# Dekorasi kota -----------------------------------------------------------------------

func decor_unlocked() -> bool:
	return stage >= Data.DECOR_UNLOCK_STAGE


func decor_cost(id: String) -> int:
	return int(affair_yield("silver") * float(Data.DECORATIONS[id]["cost"]))


func decor_bonus(effect: String) -> float:
	var total := 0.0
	for id in realm.get("decor", []):
		total += float(Data.DECORATIONS[id]["effects"].get(effect, 0.0))
	return total


func buy_decor(id: String) -> Dictionary:
	if not Data.DECORATIONS.has(id):
		return _fail("Dekorasi tidak dikenal.")
	if not decor_unlocked():
		return _fail("Dekorasi terbuka di Tahap %d." % Data.DECOR_UNLOCK_STAGE)
	if realm["decor"].has(id):
		return _fail("Dekorasi ini sudah terpasang.")
	var cost := decor_cost(id)
	if silver < cost:
		return _fail("Perak tidak cukup (butuh %d)." % cost)
	silver -= cost
	realm["decor"].append(id)
	_track("decor")
	changed.emit()
	return _ok("%s terpasang di kota!" % Data.DECORATIONS[id]["name"])


# Ulasan Play Store ---------------------------------------------------------------------

func review_ready(now: float) -> bool:
	var rv: Dictionary = realm["review"]
	return int(rv["count"]) < Data.REVIEW_MAX and day_index(now) - start_day >= Data.REVIEW_MIN_DAYS \
		and (int(rv["count"]) == 0 or now - float(rv["last"]) >= Data.REVIEW_GAP_DAYS * 86400.0) and not tutorial_active()


func mark_review(now: float) -> void:
	realm["review"]["count"] = int(realm["review"]["count"]) + 1
	realm["review"]["last"] = now


# Saran penasihat -----------------------------------------------------------------------

## Hal paling berguna yang bisa dikerjakan sekarang, berurutan menurut prioritas:
## [{"text", "target"}]; target: "page:<halaman>", "realm:<panel>", atau nama tindakan UI.
func advice(now: float) -> Array:
	var out := []
	var add := func(cond: bool, text: String, target: String):
		if cond:
			out.append({"text": text, "target": target})
	add.call(login_can_claim(now), "Hadiah login hari ini menunggu.", "login")
	add.call(mail_unread() > 0, "Ada hadiah di Kotak Surat.", "realm:mail")
	add.call(story_claimable() > 0, "Hadiah misi cerita siap diambil.", "story")
	add.call(claimable_count() > 0, "Misi harian selesai, ambil hadiahnya.", "missions")
	var full := 0
	for key in ["silver", "grain", "soldiers"]:
		if charge_full_eta(key, now) == 0:
			full += 1
	add.call(full > 0, "Urusan kota penuh. Kerjakan sebelum terbuang.", "page:city")
	add.call(free_pull_eta(now) == 0, "Rekrut gratis hari ini tersedia.", "page:gacha")
	add.call(soldiers >= expected_losses(), "Pasukan cukup untuk menang di %s." % current_stage_info()["name"], "page:campaign")
	add.call(garden_unlocked() and garden_ready_count(now) > 0, "Kebun siap dipanen.", "realm:garden")
	add.call(expeditions_ready(now) > 0, "Ekspedisi sudah kembali.", "page:counselor")
	add.call(month_event_claimable(now) > 0, "Tugas Acara Sejarah siap diklaim.", "realm:month_event")
	add.call(kitchen_unlocked() and cooks_left(now) > 0 and meal_active(now).is_empty(),
		"Dapur siap memasak hidangan berkah.", "realm:kitchen")
	add.call(stage > 0 and sweeps_left(now) > 0 and soldiers >= sweep_cost() * 3 and soldiers < expected_losses(),
		"Belum cukup kuat? Sapu tahap lalu untuk perak dan prestise.", "page:campaign")
	add.call(history_claimable(now) and not tutorial_active(), "Baca kisah sejarah hari ini.", "page:city")
	if out.is_empty():
		out.append({"text": "Latih penasihat terkuat untuk menaikkan kekuatan.", "target": "page:counselor"})
	return out



# --- Batch 10: raid aliansi, batas belanja ----------------------------------------------

func claim_raid_reward(raid: int, reward: Dictionary) -> Dictionary:
	if realm["raid_claimed"].has(raid):
		return _fail("Hadiah raid sudah diambil.")
	realm["raid_claimed"].append(raid)
	while realm["raid_claimed"].size() > 50:
		realm["raid_claimed"].pop_front()
	var text := _give_rewards(_safe_reward(reward))
	_track("raid")
	changed.emit()
	return _ok("Hadiah raid: %s." % text)


## Kunci bulan (tahun*12+bulan) untuk menghitung belanja bulanan.
func spend_month(now: float) -> int:
	return month_index(now)


## Rupiah yang sudah dibelanjakan bulan ini (pembelian sungguhan, dicatat grant_purchase).
func spent_this_month(now: float) -> int:
	var sp: Dictionary = iap.get("spend", {})
	return int(sp.get("amount", 0)) if int(sp.get("month", -1)) == spend_month(now) else 0


## Boleh membeli produk ini dengan batas belanja bulanan `limit` (0 = tanpa batas)?
func spend_allowed(id: String, limit: int, now: float) -> bool:
	if limit <= 0:
		return true
	return spent_this_month(now) + int(Data.iap_def(id).get("price_idr", 0)) <= limit


func _record_spend(id: String, now: float) -> void:
	var m := spend_month(now)
	var sp: Dictionary = iap.get("spend", {})
	if int(sp.get("month", -1)) != m:
		sp = {"month": m, "amount": 0}
	sp["amount"] = int(sp["amount"]) + int(Data.iap_def(id).get("price_idr", 0))
	iap["spend"] = sp



## Teks widget layar beranda: [judul, baris1, baris2, baris3] (bahasa sumber; diterjemahkan Notifier).
func widget_lines(now: float) -> Array:
	var clock := func(eta: int) -> String:
		var d := Time.get_datetime_dict_from_unix_time(int(now + eta + tz_bias))
		return "%02d.%02d" % [int(d["hour"]), int(d["minute"])]
	var city := 0
	for key in ["silver", "grain", "soldiers"]:
		city = maxi(city, charge_full_eta(key, now))
	var free := free_pull_eta(now)
	return [
		"%s · %s" % [me_name(), rank_info()["name"]],
		"Urusan kota penuh" if city <= 0 else "Urusan kota penuh pukul %s" % clock.call(city),
		"Rekrut gratis siap" if free <= 0 else "Rekrut gratis pukul %s" % clock.call(free),
		"Hadiah login menunggu" if login_can_claim(now) else "Hadiah login berikutnya besok",
	]



# --- Batch 11: hari besar, perjalanan 7 hari pertama ---------------------------------------

## Hari besar yang sedang berlangsung: {def, year, key} atau {} (key = "<id>:<tahun>").
func holiday_active(now: float) -> Dictionary:
	var d := Time.get_datetime_dict_from_unix_time(int(now + tz_bias))
	var today := Time.get_unix_time_from_datetime_dict({"year": d["year"], "month": d["month"], "day": d["day"]})
	for h in Data.HOLIDAYS:
		for year in [int(d["year"]), int(d["year"]) - 1]:
			var md = h["fixed"] if h.has("fixed") else h.get("dates", {}).get(year)
			if md == null:
				continue
			var start := Time.get_unix_time_from_datetime_dict({"year": year, "month": md[0], "day": md[1]})
			if today >= start and today < start + int(h["days"]) * 86400:
				return {"def": h, "year": year, "key": "%s:%d" % [h["id"], year]}
	return {}


func claim_holiday(now: float) -> Dictionary:
	var hol := holiday_active(now)
	if hol.is_empty():
		return _fail("Tidak ada hari besar hari ini.")
	if realm["holidays"].has(hol["key"]):
		return _fail("Hadiah hari raya ini sudah diambil.")
	realm["holidays"].append(hol["key"])
	while realm["holidays"].size() > 40:
		realm["holidays"].pop_front()
	var text := _give_rewards(Data.HOLIDAY_REWARD)
	unlock_cosmetic(str(hol["def"]["frame"]))
	_track("holiday")
	changed.emit()
	return _ok("%s: %s dan bingkai khusus!" % [hol["def"]["name"], text])


## Hari ke berapa sejak mulai bermain (1 = hari pertama).
func play_day(now: float) -> int:
	return day_index(now) - start_day + 1


## Perjalanan aktif selama belum semua hadiah diambil dan pemain masih di 14 hari pertama.
func journey_active(now: float) -> bool:
	return realm["journey"].size() < Data.JOURNEY.size() and play_day(now) <= 14


func journey_progress(day: int, task: int) -> int:
	var t: Dictionary = Data.JOURNEY[day]["tasks"][task]
	return mini(int(t["target"]), int(counters.get(t["event"], 0)))


func journey_day_done(day: int) -> bool:
	for i in Data.JOURNEY[day]["tasks"].size():
		if journey_progress(day, i) < int(Data.JOURNEY[day]["tasks"][i]["target"]):
			return false
	return true


## Hari perjalanan terbuka bertahap: hari ke-N terbuka pada hari bermain ke-N.
func journey_unlocked(day: int, now: float) -> bool:
	return day < play_day(now)


func journey_claimable(now: float) -> int:
	var n := 0
	for d in Data.JOURNEY.size():
		if journey_unlocked(d, now) and journey_day_done(d) and not realm["journey"].has(d):
			n += 1
	return n


func claim_journey(day: int, now: float) -> Dictionary:
	if day < 0 or day >= Data.JOURNEY.size():
		return _fail("Hari tidak dikenal.")
	if not journey_unlocked(day, now):
		return _fail("Hari ke-%d terbuka besok atau nanti." % (day + 1))
	if realm["journey"].has(day):
		return _fail("Hadiah hari ini sudah diambil.")
	if not journey_day_done(day):
		return _fail("Selesaikan target hari ke-%d dulu." % (day + 1))
	realm["journey"].append(day)
	var text := _give_rewards(Data.JOURNEY[day]["reward"])
	_track("journey")
	changed.emit()
	return _ok("Perjalanan hari ke-%d: %s." % [day + 1, text])
