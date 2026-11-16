extends "res://scripts/core/game_model_core.gd"
## Fitur kerajaan (perburuan, pasar, kebijakan, riset, armada, kebun, diplomasi, candi,
## besalen, peliharaan, wayang, upacara, lencana, ...). Kelas dasar game_model.gd.

# --- Kerajaan: state bersama -----------------------------------------------------

func _empty_realm(now: float) -> Dictionary:
	var plots := []
	for i in Data.GARDEN_PLOTS:
		plots.append({})
	return {
		"hunt": {"day": -1, "used": 0},
		"kin": [],
		"kin_day": -1,
		"market": {"period": -1, "slots": [], "refresh_day": -1, "refreshes": 0},
		"policy": "seimbang",
		"policy_t": -1.0e12,
		"loyalty_day": day_index(now),
		"disaster": {"period": -1, "id": "", "resolved": false},
		"research": {"levels": {}, "job": {}},
		"fleet": {"ships": [], "voyages": {}},
		"garden": plots,
		"gifts": {"day": -1, "n": 0},
		"guildwar_claimed": -1,
		"army": "seimbang",
		"diplo": {"day": -1, "envoys": 0, "spies": 0, "rel": {}, "trade": [], "ally": [], "scout": {}, "sabotage": {},
			"jailed": [], "threat": {}, "drift_day": day_index(now)},
		"rebel": {"active": false, "soldiers": 0},
		"race": {"day": -1, "used": 0},
		"quiz": {"day": -1, "answers": {}},
		"candi": {"day": -1, "runs": 0, "run": {}},
		"pets": {"owned": {}, "active": ""},
		"comeback": {},
		"codes": [],
		"wb_claimed": -1,
		"usage": {},
		"wayang": {"done": {}, "day": -1},
		"ceremony": {"last_day": -1000, "id": "", "until": 0.0},
		"badges": {"season": -1, "base": {}, "earned": {}},
		"tourney_claimed": -1,
		"month_event": {"month": -1, "base": {}, "done": [], "final": false},
		"skins": {"owned": [], "worn": {}},
		"mail": [],
		"mail_claimed": [],
		"history_day": -1,
		"heirs": {},
		"heir_seq": 0,
		"kitchen": {"day": -1, "used": 0, "meal": {"id": "", "until": 0.0, "mult": 1.0}},
		"season_claimed": [],
		"sweep": {"day": -1, "used": 0},
		"decor": [],
		"review": {"count": 0, "last": 0.0},
		"raid_claimed": [],
		"holidays": [],
		"journey": [],
	}


## Muat state kerajaan dari save dengan validasi tiap bagian (save lama: kosong).
func _load_realm(src, now: float) -> void:
	realm = _empty_realm(now)
	if not (src is Dictionary):
		return
	var h = src.get("hunt", {})
	if h is Dictionary:
		realm["hunt"] = {"day": int(h.get("day", -1)), "used": clampi(int(h.get("used", 0)), 0, Data.HUNT_PER_DAY)}
	for k in src.get("kin", []):
		if k is Dictionary and realm["kin"].size() < 50:
			realm["kin"].append({"house": str(k.get("house", "")), "name": str(k.get("name", "")),
				"child": str(k.get("child", "")), "day": int(k.get("day", 0))})
	realm["kin_day"] = int(src.get("kin_day", -1))
	var m = src.get("market", {})
	if m is Dictionary:
		var slots := []
		for sl in m.get("slots", []):
			if sl is Dictionary and int(sl.get("pool", -1)) >= 0 and int(sl.get("pool", -1)) < Data.MARKET_POOL.size():
				slots.append({"pool": int(sl["pool"]), "price": maxi(1, int(sl.get("price", 1))),
					"bought": bool(sl.get("bought", false)), "haggled": bool(sl.get("haggled", false))})
		realm["market"] = {"period": int(m.get("period", -1)) if slots.size() == Data.MARKET_SLOTS else -1,
			"slots": slots, "refresh_day": int(m.get("refresh_day", -1)), "refreshes": int(m.get("refreshes", 0))}
	if Data.POLICIES.has(str(src.get("policy", ""))):
		realm["policy"] = str(src["policy"])
	realm["policy_t"] = float(src.get("policy_t", -1.0e12))
	realm["loyalty_day"] = mini(int(src.get("loyalty_day", day_index(now))), day_index(now))
	var dis = src.get("disaster", {})
	if dis is Dictionary and (str(dis.get("id", "")) == "" or not disaster_def(str(dis.get("id", ""))).is_empty()):
		realm["disaster"] = {"period": int(dis.get("period", -1)), "id": str(dis.get("id", "")),
			"resolved": bool(dis.get("resolved", false))}
	var rs = src.get("research", {})
	if rs is Dictionary:
		for id in rs.get("levels", {}):
			if Data.RESEARCH.has(str(id)):
				realm["research"]["levels"][str(id)] = clampi(int(rs["levels"][id]), 0, Data.RESEARCH_MAX_LEVEL)
		var job = rs.get("job", {})
		if job is Dictionary and Data.RESEARCH.has(str(job.get("id", ""))):
			realm["research"]["job"] = {"id": str(job["id"]), "end_t": float(job.get("end_t", now))}
	var fl = src.get("fleet", {})
	if fl is Dictionary:
		for id in fl.get("ships", []):
			if Data.SHIPS.has(str(id)) and not realm["fleet"]["ships"].has(str(id)):
				realm["fleet"]["ships"].append(str(id))
		var voy = fl.get("voyages", {})
		if voy is Dictionary:
			for id in voy:
				var v = voy[id]
				if realm["fleet"]["ships"].has(str(id)) and v is Dictionary and not region_def(str(v.get("region", ""))).is_empty():
					realm["fleet"]["voyages"][str(id)] = {"region": str(v["region"]), "end_t": float(v.get("end_t", now)),
						"cargo": maxi(0, int(v.get("cargo", 0))), "seed": int(v.get("seed", 0))}
	var g = src.get("garden", [])
	if g is Array:
		for i in mini(g.size(), Data.GARDEN_PLOTS):
			var pl = g[i]
			if pl is Dictionary and Data.PLANTS.has(str(pl.get("plant", ""))):
				realm["garden"][i] = {"plant": str(pl["plant"]), "end_t": float(pl.get("end_t", now))}
	var gf = src.get("gifts", {})
	if gf is Dictionary:
		realm["gifts"] = {"day": int(gf.get("day", -1)), "n": clampi(int(gf.get("n", 0)), 0, Data.FRIEND_GIFT_DAILY)}
	realm["guildwar_claimed"] = int(src.get("guildwar_claimed", -1))
	_load_realm5(src, now)


## Dipanggil dari sync(): riset selesai, bencana baru, dan perubahan kesetiaan harian.
func _sync_realm(now: float) -> bool:
	var changed_any := finish_research(now)
	changed_any = ensure_disaster(now) or changed_any
	changed_any = _sync_diplomacy(now) or changed_any
	changed_any = _check_rebellion() or changed_any
	# Kesetiaan berubah sekali per hari mengikuti kebijakan aktif.
	var today := day_index(now)
	var last := int(realm["loyalty_day"])
	if last < today:
		var days := mini(today - last, 30)
		var per := int(policy_def()["loyalty_day"])
		if policy_unlocked() and per != 0:
			court["loyalty"] = clampi(int(court.get("loyalty", 50)) + per * days, 0, 100)
			changed_any = true
		realm["loyalty_day"] = today
	return changed_any


## Total bonus kerajaan untuk suatu efek: riset, kebijakan, bencana aktif, titah raja.
func kingdom_bonus(effect: String) -> float:
	var total := research_bonus(effect)
	total += float(policy_def()["effects"].get(effect, 0.0)) if policy_unlocked() else 0.0
	total += float(disaster_active().get("effects", {}).get(effect, 0.0))
	total += float(king_effects.get(effect, 0.0))
	total += float(season_def(_last_now)["effects"].get(effect, 0.0))
	if effect == "yield_all" and bool(realm.get("rebel", {}).get("active", false)):
		total += Data.REBEL_PENALTY
	if effect == "yield_all" and comeback_active(_last_now):
		total += Data.COMEBACK_BOOST
	if effect == "yield_silver":
		total += Data.DIPLO_TRADE_BONUS * realm.get("diplo", {}).get("trade", []).size()
	if effect == "combat":
		total += Data.DIPLO_ALLY_BONUS * realm.get("diplo", {}).get("ally", []).size()
	total += pet_bonus(effect)
	total += ceremony_bonus(effect, _last_now)
	total += float(Data.RANK_PERKS.get(rank, {}).get(effect, 0.0))
	total += meal_bonus(effect, _last_now)
	total += decor_bonus(effect)
	if effect == "yield_all":
		total += float(remote.get("yield_bonus", 0.0))
	return total


## Sumber daya nyata dari kelipatan hasil urusan ({"silver": 2.0} -> {"silver": 4800}).
func _yields_of(mult: Dictionary, factor := 1.0) -> Dictionary:
	var out := {}
	for k in mult:
		out[k] = int(affair_yield(k) * float(mult[k]) * factor)
	return out


# --- Perburuan --------------------------------------------------------------------

func hunt_unlocked() -> bool:
	return stage >= Data.HUNT_UNLOCK_STAGE


func hunt_ground(id: String) -> Dictionary:
	for g in Data.HUNT_GROUNDS:
		if g["id"] == id:
			return g
	return {}


func hunts_left(now: float) -> int:
	var h: Dictionary = realm["hunt"]
	if int(h["day"]) != day_index(now):
		return Data.HUNT_PER_DAY
	return maxi(0, Data.HUNT_PER_DAY - int(h["used"]))


func hunt_score(counselor_id: String) -> int:
	return attr(counselor_id, "str") + attr(counselor_id, "cha") / 2


func hunt_difficulty(ground_id: String) -> int:
	return int(float(hunt_ground(ground_id)["diff"]) * (60 + stage * 18))


func hunt_chance(counselor_id: String, ground_id: String) -> float:
	var score := float(hunt_score(counselor_id))
	var diff := float(hunt_difficulty(ground_id))
	return clampf(score / maxf(1.0, score + diff) * 1.15 + pet_bonus("hunt"), 0.1, 0.95)


func hunt_rewards(ground_id: String) -> Dictionary:
	var g := hunt_ground(ground_id)
	var out := _yields_of(g["yields"])
	out["prestige"] = int(g["prestige"])
	return out


## Berburu. Hasil memuat "plan" untuk tayangan: {shots, hit, seed, animal, icon}.
func go_hunt(counselor_id: String, ground_id: String, now: float) -> Dictionary:
	if not hunt_unlocked():
		return _fail("Menangkan Tahap %d untuk membuka Perburuan." % Data.HUNT_UNLOCK_STAGE)
	var g := hunt_ground(ground_id)
	if g.is_empty():
		return _fail("Medan buruan tidak dikenal.")
	if not counselors.has(counselor_id):
		return _fail("Penasihat belum direkrut.")
	if hunts_left(now) <= 0:
		return _fail("Jatah berburu hari ini habis. Kembali besok.")
	var h: Dictionary = realm["hunt"]
	if int(h["day"]) != day_index(now):
		h["day"] = day_index(now)
		h["used"] = 0
	h["used"] = int(h["used"]) + 1
	use_counselor(counselor_id)
	var hit := rng.randf() < hunt_chance(counselor_id, ground_id)
	var shots := rng.randi_range(1, 3) if hit else 3
	var reward := hunt_rewards(ground_id)
	if not hit:
		reward = _yields_of(g["yields"], Data.HUNT_FAIL_SHARE)
	if hit and str(g["drop"]) != "" and rng.randf() < float(g["drop_chance"]):
		reward["items"] = {str(g["drop"]): 1}
	var text := _give_rewards(reward)
	_track("hunt")
	changed.emit()
	var who: String = Data.counselor_def(counselor_id)["name"]
	var result := _ok(("%s berhasil memburu %s! %s." if hit else "%s gagal, %s lolos ke hutan. Hasil hiburan: %s.")
		% [who, g["animal"], text])
	result["win"] = hit
	result["plan"] = {"shots": shots, "hit": hit, "seed": rng.randi(), "icon": g["icon"], "animal": g["animal"]}
	return result


# --- Pernikahan antar-kerajaan ------------------------------------------------------

func child_adult(index: int) -> bool:
	return index >= 0 and index < children.size() and int(children[index]["level"]) >= Data.CHILD_MAX_LEVEL


## Calon pasangan hari ini untuk anak `index` (stabil sepanjang hari).
func marriage_candidates(index: int, now: float) -> Array:
	if not child_adult(index):
		return []
	var child: Dictionary = children[index]
	var r := _seeded(["marry", day_index(now), child["name"], child.get("mother", ""), int(child["talent"]), index])
	var gender := "f" if child["gender"] == "m" else "m"
	var names: Array = Data.CHILD_NAMES[gender]
	var out := []
	for i in Data.MARRIAGE_CANDIDATES:
		var house: Dictionary = Data.NOBLE_HOUSES[r.randi_range(0, Data.NOBLE_HOUSES.size() - 1)]
		var roll := r.randf()
		var talent := 5 if roll < 0.08 else (4 if roll < 0.25 else (3 if roll < 0.55 else 2))
		out.append({"house": house["id"], "house_name": house["name"], "name": names[r.randi_range(0, names.size() - 1)],
			"talent": talent, "attr": house["attr"], "bonus": (int(child["talent"]) + talent) * Data.MARRIAGE_BONUS,
			"dowry": int(talent * affair_yield("silver") * Data.MARRIAGE_DOWRY)})
	return out


func marry_noble(index: int, candidate: int, now: float) -> Dictionary:
	if index < 0 or index >= children.size():
		return _fail("Anak tidak ditemukan.")
	if not child_adult(index):
		return _fail("%s belum dewasa." % children[index]["name"])
	var cands := marriage_candidates(index, now)
	if candidate < 0 or candidate >= cands.size():
		return _fail("Calon tidak ditemukan.")
	if counselors.is_empty():
		return _fail("Belum ada penasihat.")
	var c: Dictionary = cands[candidate]
	if silver < int(c["dowry"]):
		return _fail("Perak tidak cukup untuk mahar (butuh %d)." % c["dowry"])
	silver -= int(c["dowry"])
	var key: String = c["attr"]
	var best := ""
	for id in counselors:
		if best == "" or attr(id, key) > attr(best, key):
			best = id
	var b: Dictionary = counselors[best]["bonus"]
	b[key] = int(b.get(key, 0)) + int(c["bonus"])
	var child: Dictionary = children[index]
	children.remove_at(index)
	married_count += 1
	var gain := 20 * int(child["talent"])  # sama dengan pernikahan biasa
	prestige += gain
	realm["kin"].append({"house": c["house"], "name": c["name"], "child": child["name"], "day": day_index(now)})
	_track("marry")
	changed.emit()
	return _ok("%s menikah dengan %s dari %s! %s +%d %s, +%d prestise." % [child["name"], c["name"], c["house_name"],
		Data.counselor_def(best)["name"], c["bonus"], Data.ATTR_NAMES[key], gain])


func kin_count() -> int:
	return realm["kin"].size()


func kin_gift_amount() -> int:
	return int(affair_yield("silver") * Data.KIN_GIFT * mini(kin_count(), Data.KIN_MAX))


func kin_gift_ready(now: float) -> bool:
	return kin_count() > 0 and int(realm["kin_day"]) != day_index(now)


func claim_kin_gifts(now: float) -> Dictionary:
	if not kin_gift_ready(now):
		return _fail("Belum ada kiriman besan hari ini." if kin_count() > 0 else "Belum punya besan.")
	realm["kin_day"] = day_index(now)
	var amount := kin_gift_amount()
	silver += amount
	changed.emit()
	return _ok("Kiriman dari %d keluarga besan: +%d perak." % [kin_count(), amount])


# --- Pasar Malam ------------------------------------------------------------------

func market_unlocked() -> bool:
	return stage >= Data.MARKET_UNLOCK_STAGE


func market_period(now: float) -> int:
	return int(floor((now + tz_bias) / (Data.MARKET_HOURS * 3600.0)))


func market_seconds_left(now: float) -> int:
	return int(ceil((market_period(now) + 1) * Data.MARKET_HOURS * 3600.0 - tz_bias - now))


func _roll_market(period: int, salt: int) -> void:
	var r := _seeded(["market", period, salt])
	var slots := []
	var pool := range(Data.MARKET_POOL.size())
	for i in Data.MARKET_SLOTS:
		var pick: int = pool.pop_at(r.randi_range(0, pool.size() - 1))
		var def: Dictionary = Data.MARKET_POOL[pick]
		var price := int(def["price"])
		if def["cur"] == "silver":
			price = int(price * float(rank_info()["mult"]))
		slots.append({"pool": pick, "price": price, "bought": false, "haggled": false})
	realm["market"]["period"] = period
	realm["market"]["slots"] = slots


func ensure_market(now: float) -> void:
	if int(realm["market"]["period"]) != market_period(now):
		_roll_market(market_period(now), 0)


func market_slots(now: float) -> Array:
	ensure_market(now)
	return realm["market"]["slots"]


func market_refreshes_left(now: float) -> int:
	var m: Dictionary = realm["market"]
	return Data.MARKET_REFRESH_LIMIT - (int(m["refreshes"]) if int(m["refresh_day"]) == day_index(now) else 0)


func refresh_market(now: float) -> Dictionary:
	if not market_unlocked():
		return _fail("Menangkan Tahap %d untuk membuka Pasar Malam." % Data.MARKET_UNLOCK_STAGE)
	if market_refreshes_left(now) <= 0:
		return _fail("Batas ganti dagangan hari ini sudah habis.")
	if gold < Data.MARKET_REFRESH_GOLD:
		return _fail("Emas tidak cukup (butuh %d)." % Data.MARKET_REFRESH_GOLD)
	gold -= Data.MARKET_REFRESH_GOLD
	var m: Dictionary = realm["market"]
	if int(m["refresh_day"]) != day_index(now):
		m["refresh_day"] = day_index(now)
		m["refreshes"] = 0
	m["refreshes"] = int(m["refreshes"]) + 1
	_roll_market(market_period(now), rng.randi())
	changed.emit()
	return _ok("Pedagang baru menggelar dagangannya.")


func _currency_have(cur: String) -> int:
	return int(get(cur))


func market_buy(slot: int, now: float) -> Dictionary:
	if not market_unlocked():
		return _fail("Menangkan Tahap %d untuk membuka Pasar Malam." % Data.MARKET_UNLOCK_STAGE)
	var slots := market_slots(now)
	if slot < 0 or slot >= slots.size():
		return _fail("Dagangan tidak ditemukan.")
	var sl: Dictionary = slots[slot]
	if sl["bought"]:
		return _fail("Dagangan ini sudah terjual.")
	var def: Dictionary = Data.MARKET_POOL[int(sl["pool"])]
	var cur: String = def["cur"]
	if _currency_have(cur) < int(sl["price"]):
		return _fail("%s tidak cukup (butuh %d)." % [Data.MARKET_CUR_NAMES[cur].capitalize(), sl["price"]])
	set(cur, _currency_have(cur) - int(sl["price"]))
	sl["bought"] = true
	add_item(def["item"])
	_track("market")
	changed.emit()
	return _ok("Membeli %s seharga %d %s." % [Data.ITEMS[def["item"]]["name"], sl["price"], Data.MARKET_CUR_NAMES[cur]])


func market_haggle(slot: int, now: float) -> Dictionary:
	var slots := market_slots(now)
	if slot < 0 or slot >= slots.size():
		return _fail("Dagangan tidak ditemukan.")
	var sl: Dictionary = slots[slot]
	if sl["bought"] or sl["haggled"]:
		return _fail("Pedagang tidak mau ditawar lagi.")
	sl["haggled"] = true
	var ok := rng.randf() < Data.MARKET_HAGGLE_CHANCE
	var old := int(sl["price"])
	sl["price"] = maxi(1, int(round(old * (1.0 - Data.MARKET_HAGGLE_OFF if ok else 1.0 + Data.MARKET_HAGGLE_UP))))
	changed.emit()
	var result := _ok("Tawaran diterima! Harga turun menjadi %d." % sl["price"] if ok
		else "Pedagang tersinggung, harga naik menjadi %d." % sl["price"])
	result["haggle_ok"] = ok
	return result


# --- Kebijakan & bencana -----------------------------------------------------------

func policy_unlocked() -> bool:
	return stage >= Data.POLICY_UNLOCK_STAGE


func policy_def() -> Dictionary:
	return Data.POLICIES.get(str(realm.get("policy", "seimbang")), Data.POLICIES["seimbang"])


func policy_cooldown(now: float) -> int:
	return maxi(0, int(ceil(float(realm["policy_t"]) + Data.POLICY_COOLDOWN - now)))


func set_policy(id: String, now: float) -> Dictionary:
	if not policy_unlocked():
		return _fail("Menangkan Tahap %d untuk menetapkan kebijakan." % Data.POLICY_UNLOCK_STAGE)
	if not Data.POLICIES.has(id):
		return _fail("Kebijakan tidak dikenal.")
	if id == realm["policy"]:
		return _fail("Kebijakan ini sudah berlaku.")
	if policy_cooldown(now) > 0:
		return _fail("Kebijakan baru bisa diganti dalam %d jam." % ceili(policy_cooldown(now) / 3600.0))
	realm["policy"] = id
	realm["policy_t"] = now
	_track("policy")
	changed.emit()
	return _ok("Kebijakan baru berlaku: %s." % Data.POLICIES[id]["name"])


func disaster_def(id: String) -> Dictionary:
	for d in Data.DISASTERS:
		if d["id"] == id:
			return d
	return {}


func disaster_period(now: float) -> int:
	return int(floor((now + tz_bias) / (Data.DISASTER_HOURS * 3600.0)))


## Gulirkan bencana untuk periode baru. Mengembalikan true bila keadaannya berubah.
func ensure_disaster(now: float) -> bool:
	if not policy_unlocked():
		return false
	var period := disaster_period(now)
	var dis: Dictionary = realm["disaster"]
	if int(dis["period"]) == period:
		return false
	var r := _seeded(["disaster", period])
	var chance := Data.DISASTER_CHANCE + float(policy_def().get("disaster_chance", 0.0))
	var id := ""
	if r.randf() < chance:
		# Musim memberi bobot dua kali pada bencana khasnya.
		var pool := []
		var favored: Array = season_def(now)["disasters"]
		for d in Data.DISASTERS:
			pool.append(d["id"])
			if favored.has(d["id"]):
				pool.append(d["id"])
		id = pool[r.randi_range(0, pool.size() - 1)]
	var had: bool = str(dis["id"]) != "" and not dis["resolved"]
	realm["disaster"] = {"period": period, "id": id, "resolved": false}
	return had or id != ""


## Bencana yang sedang berlangsung (belum ditangani) atau {}.
func disaster_active() -> Dictionary:
	var dis: Dictionary = realm.get("disaster", {})
	if dis.is_empty() or str(dis["id"]) == "" or dis["resolved"]:
		return {}
	return disaster_def(str(dis["id"]))


func disaster_seconds_left(now: float) -> int:
	return int(ceil((disaster_period(now) + 1) * Data.DISASTER_HOURS * 3600.0 - tz_bias - now))


func disaster_option_cost(option: Dictionary) -> Dictionary:
	return _yields_of(option.get("cost", {}))


func resolve_disaster(option_index: int, now: float) -> Dictionary:
	ensure_disaster(now)
	var d := disaster_active()
	if d.is_empty():
		return _fail("Tidak ada bencana saat ini.")
	if option_index < 0 or option_index >= d["options"].size():
		return _fail("Pilihan tidak dikenal.")
	var o: Dictionary = d["options"][option_index]
	var cost := disaster_option_cost(o)
	for k in cost:
		if int(get(k)) < int(cost[k]):
			return _fail("%s tidak cukup (butuh %d)." % [Data.REWARD_NAMES[k].capitalize(), cost[k]])
	var parts := []
	for k in cost:
		set(k, int(get(k)) - int(cost[k]))
		if int(cost[k]) > 0:
			parts.append("-%d %s" % [cost[k], Data.REWARD_NAMES[k]])
	var gain := _yields_of(o.get("gain", {}))
	for k in gain:
		set(k, int(get(k)) + int(gain[k]))
		parts.append("+%d %s" % [gain[k], Data.REWARD_NAMES[k]])
	if int(o.get("prestige", 0)) > 0:
		prestige += int(o["prestige"])
		parts.append("+%d prestise" % int(o["prestige"]))
	var loy := int(o.get("loyalty", 0))
	if loy != 0:
		court["loyalty"] = clampi(int(court.get("loyalty", 50)) + loy, 0, 100)
		parts.append("kesetiaan %+d" % loy)
	realm["disaster"]["resolved"] = true
	_track("disaster")
	changed.emit()
	return _ok("%s ditangani: %s." % [d["name"], o["text"]] + (" " + ", ".join(parts) if not parts.is_empty() else ""))


# --- Perpustakaan Keraton (riset) --------------------------------------------------

func research_unlocked() -> bool:
	return stage >= Data.RESEARCH_UNLOCK_STAGE


func research_level(id: String) -> int:
	return int(realm["research"]["levels"].get(id, 0))


func research_total() -> int:
	var total := 0
	for id in realm["research"]["levels"]:
		total += int(realm["research"]["levels"][id])
	return total


func research_cost(id: String) -> int:
	return int(Data.RESEARCH_COST * float(rank_info()["mult"]) * pow(research_level(id) + 1, 2))


func research_seconds(id: String) -> int:
	return int(Data.RESEARCH_HOURS * 3600 * (research_level(id) + 1))


func research_req_ok(id: String) -> bool:
	var req: Dictionary = Data.RESEARCH[id]["req"]
	for k in req:
		if research_level(k) < int(req[k]):
			return false
	return true


func research_job() -> Dictionary:
	return realm["research"]["job"]


func research_eta(now: float) -> int:
	var job := research_job()
	return 0 if job.is_empty() else maxi(0, int(ceil(float(job["end_t"]) - now)))


func research_bonus(effect: String) -> float:
	var total := 0.0
	for id in realm.get("research", {}).get("levels", {}):
		if Data.RESEARCH[id]["effect"] == effect:
			total += float(Data.RESEARCH[id]["per"]) * int(realm["research"]["levels"][id])
	return total


func start_research(id: String, now: float) -> Dictionary:
	if not research_unlocked():
		return _fail("Menangkan Tahap %d untuk membuka Perpustakaan Keraton." % Data.RESEARCH_UNLOCK_STAGE)
	if not Data.RESEARCH.has(id):
		return _fail("Riset tidak dikenal.")
	finish_research(now)
	if not research_job().is_empty():
		return _fail("Masih ada riset yang berjalan.")
	if research_level(id) >= Data.RESEARCH_MAX_LEVEL:
		return _fail("Riset ini sudah tuntas.")
	if not research_req_ok(id):
		return _fail("Selesaikan riset prasyarat lebih dulu.")
	var cost := research_cost(id)
	if silver < cost:
		return _fail("Perak tidak cukup (butuh %d)." % cost)
	silver -= cost
	realm["research"]["job"] = {"id": id, "end_t": now + research_seconds(id)}
	_track("research")
	changed.emit()
	return _ok("Para pujangga mulai meneliti %s." % Data.RESEARCH[id]["name"])


## Selesaikan riset yang waktunya sudah habis. True bila ada yang selesai.
func finish_research(now: float) -> bool:
	var job := research_job()
	if job.is_empty() or now < float(job["end_t"]):
		return false
	var id: String = job["id"]
	realm["research"]["levels"][id] = mini(Data.RESEARCH_MAX_LEVEL, research_level(id) + 1)
	realm["research"]["job"] = {}
	return true


func research_rush_cost(now: float) -> int:
	return ceili(research_eta(now) / float(Data.RESEARCH_RUSH_SECONDS_PER_GOLD))


func rush_research(now: float) -> Dictionary:
	if research_job().is_empty():
		return _fail("Tidak ada riset yang berjalan.")
	var cost := research_rush_cost(now)
	if gold < cost:
		return _fail("Emas tidak cukup (butuh %d)." % cost)
	gold -= cost
	var id: String = research_job()["id"]
	realm["research"]["job"]["end_t"] = now
	finish_research(now)
	changed.emit()
	return _ok("%s naik ke level %d." % [Data.RESEARCH[id]["name"], research_level(id)])


# --- Armada Laut --------------------------------------------------------------------

func fleet_unlocked() -> bool:
	return territory.get("owned", []).size() >= Data.FLEET_UNLOCK_REGIONS


func ships_owned() -> Array:
	return realm["fleet"]["ships"]


func buy_ship(id: String) -> Dictionary:
	if not fleet_unlocked():
		return _fail("Kuasai %d wilayah di Peta Nusantara untuk membuka Armada Laut." % Data.FLEET_UNLOCK_REGIONS)
	if not Data.SHIPS.has(id):
		return _fail("Kapal tidak dikenal.")
	if ships_owned().has(id):
		return _fail("Kapal ini sudah dimiliki.")
	var cost: Dictionary = Data.SHIPS[id]["cost"]
	for k in cost:
		if int(get(k)) < int(cost[k]):
			return _fail("%s tidak cukup (butuh %d)." % [Data.REWARD_NAMES[k].capitalize(), cost[k]])
	for k in cost:
		set(k, int(get(k)) - int(cost[k]))
	ships_owned().append(id)
	_track("ship")
	changed.emit()
	return _ok("%s bergabung dengan armada Tuan!" % Data.SHIPS[id]["name"])


## Tujuan dagang: wilayah yang dikuasai selain ibu kota.
func fleet_routes() -> Array:
	return territory.get("owned", []).filter(func(id): return id != "mataram")


func voyage_cargo(ship: String, region: String) -> int:
	var s: Dictionary = Data.SHIPS[ship]
	var route := 1.0 + Data.FLEET_ROUTE_BONUS * int(region_def(region)["stage"]) / 10.0
	return int(affair_yield("silver") * float(s["cargo"]) * float(s["hours"]) * route * (1.0 + research_bonus("fleet")))


func pirate_chance(ship: String) -> float:
	return Data.PIRATE_CHANCE / float(Data.SHIPS[ship]["guard"]) / (1.0 + research_bonus("fleet"))


func voyage(ship: String) -> Dictionary:
	return realm["fleet"]["voyages"].get(ship, {})


func voyage_eta(ship: String, now: float) -> int:
	var v := voyage(ship)
	return 0 if v.is_empty() else maxi(0, int(ceil(float(v["end_t"]) - now)))


func send_ship(ship: String, region: String, now: float) -> Dictionary:
	if not ships_owned().has(ship):
		return _fail("Kapal belum dimiliki.")
	if not voyage(ship).is_empty():
		return _fail("Kapal masih berlayar.")
	if not fleet_routes().has(region):
		return _fail("Tujuan harus wilayah yang sudah dikuasai.")
	realm["fleet"]["voyages"][ship] = {"region": region, "end_t": now + float(Data.SHIPS[ship]["hours"]) * 3600.0,
		"cargo": voyage_cargo(ship, region), "seed": rng.randi()}
	_track("voyage")
	changed.emit()
	return _ok("%s berlayar ke %s." % [Data.SHIPS[ship]["name"], region_def(region)["name"]])


## Kapal pulang. Hasil: {pirates, win, plan (bila diserang)}.
func claim_voyage(ship: String, now: float) -> Dictionary:
	var v := voyage(ship)
	if v.is_empty():
		return _fail("Kapal tidak sedang berlayar.")
	if now < float(v["end_t"]):
		return _fail("Kapal belum kembali.")
	realm["fleet"]["voyages"].erase(ship)
	var r := RandomNumberGenerator.new()
	r.seed = int(v["seed"])
	var cargo := int(v["cargo"])
	var pirates := r.randf() < pirate_chance(ship)
	var win := true
	var name: String = Data.SHIPS[ship]["name"]
	var msg := ""
	if pirates:
		var guard := float(Data.SHIPS[ship]["guard"])
		win = r.randf() < clampf(0.35 + 0.15 * guard + research_bonus("fleet"), 0.3, 0.9)
		if win:
			cargo = int(cargo * 1.2)
			prestige += 10
			msg = "%s mengalahkan bajak laut dan pulang membawa %d perak, +10 prestise." % [name, cargo]
		else:
			cargo = int(cargo * 0.5)
			msg = "Bajak laut merampas separuh muatan %s. Sisa %d perak." % [name, cargo]
	else:
		msg = "%s pulang dengan selamat membawa %d perak." % [name, cargo]
	silver += cargo
	_track("earn_silver", cargo)
	changed.emit()
	var result := _ok(msg)
	result["pirates"] = pirates
	result["win"] = win
	if pirates:
		result["plan"] = battle_plan(r.randf_range(0.3, 0.7) if win else 0.0, 0.0 if win else r.randf_range(0.3, 0.7),
			int(v["seed"]))
	return result


# --- Kebun Keraton ------------------------------------------------------------------

func garden_unlocked() -> bool:
	return stage >= Data.GARDEN_UNLOCK_STAGE


func plant_seed_cost(plant: String) -> int:
	return int(affair_yield("silver") * float(Data.PLANTS[plant]["seed"]))


func plot_eta(index: int, now: float) -> int:
	var pl: Dictionary = realm["garden"][index]
	return 0 if pl.is_empty() else maxi(0, int(ceil(float(pl["end_t"]) - now)))


func plant_reward(plant: String) -> Dictionary:
	var def: Dictionary = Data.PLANTS[plant]
	var out := _yields_of(def.get("yields", {}))
	for k in ["gold", "prestige"]:
		if def.has(k):
			out[k] = int(def[k])
	if def.has("items"):
		out["items"] = def["items"].duplicate()
	return out


func plant_seed(index: int, plant: String, now: float) -> Dictionary:
	if not garden_unlocked():
		return _fail("Menangkan Tahap %d untuk membuka Kebun Keraton." % Data.GARDEN_UNLOCK_STAGE)
	if index < 0 or index >= realm["garden"].size():
		return _fail("Petak tidak ditemukan.")
	if not Data.PLANTS.has(plant):
		return _fail("Bibit tidak dikenal.")
	if not realm["garden"][index].is_empty():
		return _fail("Petak ini sudah ditanami.")
	var cost := plant_seed_cost(plant)
	if silver < cost:
		return _fail("Perak tidak cukup (butuh %d)." % cost)
	silver -= cost
	realm["garden"][index] = {"plant": plant, "end_t": now + float(Data.PLANTS[plant]["hours"]) * 3600.0}
	_track("plant")
	changed.emit()
	return _ok("%s ditanam. Panen dalam %d jam." % [Data.PLANTS[plant]["name"], Data.PLANTS[plant]["hours"]])


func garden_ready_count(now: float) -> int:
	var n := 0
	for i in realm["garden"].size():
		if not realm["garden"][i].is_empty() and plot_eta(i, now) <= 0:
			n += 1
	return n


func harvest_all(now: float) -> Dictionary:
	var parts := []
	for i in realm["garden"].size():
		var pl: Dictionary = realm["garden"][i]
		if pl.is_empty() or plot_eta(i, now) > 0:
			continue
		realm["garden"][i] = {}
		parts.append(_give_rewards(plant_reward(pl["plant"])))
		_track("harvest")
	if parts.is_empty():
		return _fail("Belum ada tanaman yang siap dipanen.")
	changed.emit()
	return _ok("Panen %d petak: %s." % [parts.size(), ", ".join(parts)])


# --- Syarat gelar lanjutan ----------------------------------------------------------

func rank_req_value(key: String) -> int:
	match key:
		"regions":
			return territory.get("owned", []).size()
		"research":
			return research_total()
		"ships":
			return ships_owned().size()
		"kin":
			return kin_count()
	return 0


## [{key, have, need}] untuk jabatan `rank_index`.
func rank_reqs(rank_index: int) -> Array:
	if rank_index < 0 or rank_index >= Data.RANKS.size():
		return []
	var out := []
	var req: Dictionary = Data.RANKS[rank_index].get("req", {})
	for k in req:
		out.append({"key": k, "have": rank_req_value(k), "need": int(req[k])})
	return out


func rank_reqs_met(rank_index: int) -> bool:
	return rank_reqs(rank_index).all(func(r): return r["have"] >= r["need"])


# --- Hadiah fitur online --------------------------------------------------------------

func friend_gifts_left(now: float) -> int:
	var g: Dictionary = realm["gifts"]
	return Data.FRIEND_GIFT_DAILY - (int(g["n"]) if int(g["day"]) == day_index(now) else 0)


## Terima `count` hadiah teman dari server (dibatasi per hari). Mengembalikan jumlah yang diterima.
func receive_friend_gifts(count: int, now: float) -> Dictionary:
	var take := mini(count, friend_gifts_left(now))
	if take <= 0:
		return _fail("Batas hadiah teman hari ini sudah tercapai.")
	var g: Dictionary = realm["gifts"]
	if int(g["day"]) != day_index(now):
		g["day"] = day_index(now)
		g["n"] = 0
	g["n"] = int(g["n"]) + take
	var amount := int(affair_yield("silver") * Data.FRIEND_GIFT) * take
	silver += amount
	changed.emit()
	var result := _ok("%d hadiah teman diterima: +%d perak." % [take, amount])
	result["taken"] = take
	return result


func claim_guildwar(week: int, territories: int) -> Dictionary:
	if week <= int(realm["guildwar_claimed"]):
		return _fail("Hadiah perang minggu itu sudah diambil.")
	if territories <= 0:
		return _fail("Aliansi Tuan tidak menguasai wilayah minggu lalu.")
	realm["guildwar_claimed"] = week
	var reward := {}
	for k in Data.GUILDWAR_REWARD:
		reward[k] = int(Data.GUILDWAR_REWARD[k]) * territories
	var text := _give_rewards(reward)
	changed.emit()
	return _ok("Hadiah Perang Wilayah (%d wilayah): %s." % [territories, text])


# --- Batch 5: muat & validasi ------------------------------------------------------

func _load_realm5(src: Dictionary, now: float) -> void:
	if Data.ARMY_PRESETS.has(str(src.get("army", ""))):
		realm["army"] = str(src["army"])
	var d = src.get("diplo", {})
	if d is Dictionary:
		var dp: Dictionary = realm["diplo"]
		dp["day"] = int(d.get("day", -1))
		dp["envoys"] = clampi(int(d.get("envoys", 0)), 0, Data.DIPLO_ENVOYS)
		dp["spies"] = clampi(int(d.get("spies", 0)), 0, Data.SPY_PER_DAY)
		dp["drift_day"] = mini(int(d.get("drift_day", day_index(now))), day_index(now))
		var rel = d.get("rel", {})
		if rel is Dictionary:
			for id in rel:
				if not kingdom_def(str(id)).is_empty():
					dp["rel"][str(id)] = clampi(int(rel[id]), -100, 100)
		for key in ["trade", "ally"]:
			for id in d.get(key, []):
				if not kingdom_def(str(id)).is_empty() and not dp[key].has(str(id)):
					dp[key].append(str(id))
		for key in ["scout", "sabotage"]:
			var m = d.get(key, {})
			if m is Dictionary:
				for id in m:
					if not kingdom_def(str(id)).is_empty():
						dp[key][str(id)] = float(m[id])
		for id in d.get("jailed", []):
			if Data.counselor_def(str(id)).size() > 0:
				dp["jailed"].append(str(id))
		var th = d.get("threat", {})
		if th is Dictionary and not kingdom_def(str(th.get("kingdom", ""))).is_empty():
			dp["threat"] = {"kingdom": str(th["kingdom"]), "day": int(th.get("day", day_index(now)))}
	var rb = src.get("rebel", {})
	if rb is Dictionary:
		realm["rebel"] = {"active": bool(rb.get("active", false)), "soldiers": maxi(0, int(rb.get("soldiers", 0)))}
	for key in ["race"]:
		var r = src.get(key, {})
		if r is Dictionary:
			realm[key] = {"day": int(r.get("day", -1)), "used": clampi(int(r.get("used", 0)), 0, Data.RACE_PER_DAY)}
	var q = src.get("quiz", {})
	if q is Dictionary:
		realm["quiz"]["day"] = int(q.get("day", -1))
		var ans = q.get("answers", {})
		if ans is Dictionary:
			for k in ans:
				if int(k) >= 0 and int(k) < Data.QUIZ_PER_DAY:
					realm["quiz"]["answers"][str(int(k))] = bool(ans[k])
	var c = src.get("candi", {})
	if c is Dictionary:
		realm["candi"]["day"] = int(c.get("day", -1))
		realm["candi"]["runs"] = clampi(int(c.get("runs", 0)), 0, Data.CANDI_FREE + Data.CANDI_EXTRA_LIMIT)
		var run = c.get("run", {})
		if run is Dictionary and not run.is_empty():
			var loot := {}
			var src_loot = run.get("loot", {})
			if src_loot is Dictionary:
				for k in src_loot:
					if k == "items":
						loot["items"] = {}
						for it in src_loot["items"]:
							if Data.ITEMS.has(str(it)):
								loot["items"][str(it)] = maxi(0, int(src_loot["items"][it]))
					elif Data.REWARD_NAMES.has(str(k)):
						loot[str(k)] = maxi(0, int(src_loot[k]))
			var doors := []
			for k in run.get("doors", []):
				if Data.CANDI_KINDS.has(str(k)):
					doors.append(str(k))
			realm["candi"]["run"] = {"room": clampi(int(run.get("room", 0)), 0, Data.CANDI_ROOMS - 1),
				"hp": clampi(int(run.get("hp", Data.CANDI_HP)), 1, Data.CANDI_HP), "loot": loot,
				"doors": doors, "seed": int(run.get("seed", 0)), "log": []}
	var p = src.get("pets", {})
	if p is Dictionary:
		var owned = p.get("owned", {})
		if owned is Dictionary:
			for id in owned:
				if Data.PETS.has(str(id)):
					realm["pets"]["owned"][str(id)] = clampi(int(owned[id]), 1, Data.PET_MAX_LEVEL)
		if realm["pets"]["owned"].has(str(p.get("active", ""))):
			realm["pets"]["active"] = str(p["active"])
	var cb = src.get("comeback", {})
	if cb is Dictionary and cb.has("until"):
		var base := {}
		for k in cb.get("base", {}):
			base[str(k)] = int(cb["base"][k])
		var done := []
		for k in cb.get("done", []):
			done.append(int(k))
		realm["comeback"] = {"until": float(cb["until"]), "pack": bool(cb.get("pack", false)), "base": base, "done": done}
	for code in src.get("codes", []):
		if str(code).length() <= 80 and not realm["codes"].has(str(code)):
			realm["codes"].append(str(code))
	realm["wb_claimed"] = int(src.get("wb_claimed", -1))
	_load_realm6(src)


# --- Jenis pasukan -----------------------------------------------------------------

func army_mix() -> Array:
	return Data.ARMY_PRESETS.get(str(realm.get("army", "seimbang")), Data.ARMY_PRESETS["seimbang"])["mix"]


func set_army(id: String) -> Dictionary:
	if not Data.ARMY_PRESETS.has(id):
		return _fail("Susunan pasukan tidak dikenal.")
	realm["army"] = id
	changed.emit()
	return _ok("Susunan pasukan: %s." % Data.ARMY_PRESETS[id]["name"])


## Susunan pasukan musuh di tahap `index` (tetap per tahap): satu jenis dominan 60%.
func enemy_mix(index: int) -> Array:
	var r := _seeded(["army", index])
	var main := r.randi_range(0, 2)
	var mix := [0.2, 0.2, 0.2]
	mix[main] = 0.6
	return mix


## Keunggulan susunan kita atas musuh (-1..1, praktis -0,15..0,15).
func troop_edge(mine: Array, theirs: Array) -> float:
	var edge := 0.0
	for i in 3:
		for j in 3:
			var a: String = Data.TROOP_TYPES[i]
			var b: String = Data.TROOP_TYPES[j]
			if Data.TROOP_BEATS[a] == b:
				edge += float(mine[i]) * float(theirs[j])
			elif Data.TROOP_BEATS[b] == a:
				edge -= float(mine[i]) * float(theirs[j])
	return edge * Data.TROOP_EDGE / 0.36  # 0,36 = keunggulan susunan 60% lawan 60% yang dikalahkannya


func troop_loss_factor(index: int) -> float:
	return clampf(1.0 - troop_edge(army_mix(), enemy_mix(index)), 0.6, 1.4)


## Susunan yang paling unggul melawan tahap `index`.
func best_army(index: int) -> String:
	var best := "seimbang"
	for id in Data.ARMY_ORDER:
		if troop_edge(Data.ARMY_PRESETS[id]["mix"], enemy_mix(index)) > troop_edge(Data.ARMY_PRESETS[best]["mix"], enemy_mix(index)):
			best = id
	return best


# --- Musim ------------------------------------------------------------------------

func season_id(now: float) -> String:
	return "kemarau" if posmod(week_index(now), 2) == 0 else "penghujan"


func season_def(now: float) -> Dictionary:
	return Data.SEASONS[season_id(now)]


# --- Diplomasi & mata-mata ------------------------------------------------------------

func diplo_unlocked() -> bool:
	return stage >= Data.DIPLO_UNLOCK_STAGE


func kingdom_def(id: String) -> Dictionary:
	for k in Data.KINGDOMS:
		if k["id"] == id:
			return k
	return {}


func relation(id: String) -> int:
	return int(realm["diplo"]["rel"].get(id, 0))


func _set_relation(id: String, value: int) -> void:
	var dp: Dictionary = realm["diplo"]
	dp["rel"][id] = clampi(value, -100, 100)
	if dp["trade"].has(id) and dp["rel"][id] < Data.DIPLO_TRADE_REL - 20:
		dp["trade"].erase(id)
	if dp["ally"].has(id) and dp["rel"][id] < Data.DIPLO_ALLY_REL - 20:
		dp["ally"].erase(id)


func kingdom_power(id: String) -> int:
	var k := kingdom_def(id)
	var p := Data.MAP_POWER_BASE * pow(Data.MAP_POWER_GROWTH, maxi(stage, 10)) * float(k["factor"])
	if float(realm["diplo"]["sabotage"].get(id, 0.0)) > _last_now:
		p *= 0.8
	return int(p)


func kingdom_scouted(id: String, now: float) -> bool:
	return float(realm["diplo"]["scout"].get(id, 0.0)) > now


func _diplo_day(now: float) -> Dictionary:
	var dp: Dictionary = realm["diplo"]
	if int(dp["day"]) != day_index(now):
		dp["day"] = day_index(now)
		dp["envoys"] = 0
		dp["spies"] = 0
		dp["jailed"] = []
	return dp


func envoys_left(now: float) -> int:
	return Data.DIPLO_ENVOYS - int(_diplo_day(now)["envoys"])


func spies_left(now: float) -> int:
	return Data.SPY_PER_DAY - int(_diplo_day(now)["spies"])


## Pergeseran hubungan harian dan ancaman serangan dari kerajaan yang memusuhi.
func _sync_diplomacy(now: float) -> bool:
	if not diplo_unlocked():
		return false
	var dp: Dictionary = realm["diplo"]
	var today := day_index(now)
	var last := int(dp["drift_day"])
	if last >= today:
		return false
	var days := mini(today - last, 30)
	# Ancaman yang diabaikan sampai hari berganti: kerajaan menjarah perak.
	if not dp["threat"].is_empty() and int(dp["threat"]["day"]) < today:
		silver -= mini(silver, int(affair_yield("silver") * 3))
		_set_relation(dp["threat"]["kingdom"], relation(dp["threat"]["kingdom"]) + 20)
		dp["threat"] = {}
	for k in Data.KINGDOMS:
		var r := relation(k["id"])
		var step := mini(absi(r), Data.DIPLO_DRIFT * days)
		_set_relation(k["id"], r - signi(r) * step)
	dp["drift_day"] = today
	if dp["threat"].is_empty():
		var rr := _seeded(["threat", today])
		for k in Data.KINGDOMS:
			if relation(k["id"]) <= Data.DIPLO_THREAT_REL and rr.randf() < 0.5:
				dp["threat"] = {"kingdom": k["id"], "day": today}
				break
	return true


func send_gift(id: String, now: float) -> Dictionary:
	if not diplo_unlocked():
		return _fail("Menangkan Tahap %d untuk membuka Diplomasi." % Data.DIPLO_UNLOCK_STAGE)
	if kingdom_def(id).is_empty():
		return _fail("Kerajaan tidak dikenal.")
	if envoys_left(now) <= 0:
		return _fail("Utusan hari ini sudah habis.")
	var cost := int(affair_yield("silver") * Data.DIPLO_GIFT)
	if silver < cost:
		return _fail("Perak tidak cukup (butuh %d)." % cost)
	silver -= cost
	realm["diplo"]["envoys"] = int(realm["diplo"]["envoys"]) + 1
	_set_relation(id, relation(id) + Data.DIPLO_GIFT_REL)
	_track("diplomacy")
	changed.emit()
	return _ok("Hadiah diterima %s. Hubungan kini %d." % [kingdom_def(id)["name"], relation(id)])


func demand_tribute(id: String, now: float) -> Dictionary:
	if not diplo_unlocked():
		return _fail("Menangkan Tahap %d untuk membuka Diplomasi." % Data.DIPLO_UNLOCK_STAGE)
	if kingdom_def(id).is_empty():
		return _fail("Kerajaan tidak dikenal.")
	if envoys_left(now) <= 0:
		return _fail("Utusan hari ini sudah habis.")
	realm["diplo"]["envoys"] = int(realm["diplo"]["envoys"]) + 1
	_track("diplomacy")
	if combat_power() < kingdom_power(id):
		_set_relation(id, relation(id) - 10)
		changed.emit()
		return _fail("%s menolak dan mengusir utusan Tuan. Hubungan memburuk." % kingdom_def(id)["name"])
	var amount := int(affair_yield("silver") * Data.DIPLO_TRIBUTE)
	silver += amount
	_set_relation(id, relation(id) + Data.DIPLO_TRIBUTE_REL)
	changed.emit()
	return _ok("%s menyerahkan upeti %d perak. Hubungan memburuk." % [kingdom_def(id)["name"], amount])


func sign_pact(id: String, kind: String) -> Dictionary:
	if kingdom_def(id).is_empty() or not kind in ["trade", "ally"]:
		return _fail("Perjanjian tidak dikenal.")
	var need := Data.DIPLO_TRADE_REL if kind == "trade" else Data.DIPLO_ALLY_REL
	if realm["diplo"][kind].has(id):
		return _fail("Perjanjian ini sudah berlaku.")
	if relation(id) < need:
		return _fail("Hubungan harus minimal %d." % need)
	realm["diplo"][kind].append(id)
	_track("diplomacy")
	changed.emit()
	return _ok(("Perjanjian dagang dengan %s: perak +2%%." if kind == "trade" else "%s kini sekutu Tuan: kekuatan tempur +2%%.")
		% kingdom_def(id)["name"])


func threat() -> Dictionary:
	return realm["diplo"]["threat"]


## Hadapi serangan kerajaan musuh. pay = bayar damai; selain itu bertempur.
func answer_threat(pay: bool, now: float) -> Dictionary:
	var th := threat()
	if th.is_empty():
		return _fail("Tidak ada ancaman.")
	var id: String = th["kingdom"]
	var name: String = kingdom_def(id)["name"]
	realm["diplo"]["threat"] = {}
	if pay:
		var cost := mini(silver, int(affair_yield("silver") * 2))
		silver -= cost
		_set_relation(id, relation(id) + 25)
		changed.emit()
		return _ok("Tuan membayar %d perak. %s menarik pasukannya." % [cost, name])
	var ratio := float(combat_power()) / maxf(1.0, kingdom_power(id))
	var win := rng.randf() < clampf(0.5 + (ratio - 1.0), 0.1, 0.95)
	var lost := mini(soldiers, int(affair_yield("soldiers") * (1.0 if win else 2.5)))
	soldiers -= lost
	var result: Dictionary
	if win:
		prestige += 30
		_set_relation(id, relation(id) + 15)
		result = _ok("Pasukan %s dipukul mundur! -%d prajurit, +30 prestise." % [name, lost])
	else:
		silver -= mini(silver, int(affair_yield("silver") * 2))
		result = _ok("Pasukan Tuan kalah melawan %s. -%d prajurit, perak dijarah." % [name, lost])
	result["win"] = win
	result["plan"] = battle_plan(rng.randf_range(0.35, 0.7) if win else 0.0, 0.0 if win else rng.randf_range(0.3, 0.7),
		rng.randi())
	_track("battle")
	changed.emit()
	return result


## Penasihat terbaik untuk mata-mata hari ini (Kecerdasan tertinggi yang tidak tertangkap).
func spy_agent(now: float) -> String:
	var dp := _diplo_day(now)
	var best := ""
	for id in counselors:
		if dp["jailed"].has(id):
			continue
		if best == "" or attr(id, "int") > attr(best, "int"):
			best = id
	return best


func spy_chance(agent: String, kingdom: String, mission: String) -> float:
	if agent == "":
		return 0.0
	return clampf(attr(agent, "int") * 12.0 / maxf(1.0, kingdom_power(kingdom)) * float(Data.SPY_MISSIONS[mission]["ease"]),
		0.1, 0.9)


func send_spy(kingdom: String, mission: String, now: float) -> Dictionary:
	if not diplo_unlocked():
		return _fail("Menangkan Tahap %d untuk membuka Diplomasi." % Data.DIPLO_UNLOCK_STAGE)
	if kingdom_def(kingdom).is_empty() or not Data.SPY_MISSIONS.has(mission):
		return _fail("Misi tidak dikenal.")
	if spies_left(now) <= 0:
		return _fail("Mata-mata hari ini sudah habis.")
	var agent := spy_agent(now)
	if agent == "":
		return _fail("Tidak ada penasihat yang bisa dikirim.")
	var dp: Dictionary = realm["diplo"]
	dp["spies"] = int(dp["spies"]) + 1
	var who: String = Data.counselor_def(agent)["name"]
	var name: String = kingdom_def(kingdom)["name"]
	_track("spy")
	use_counselor(agent)
	if rng.randf() >= spy_chance(agent, kingdom, mission):
		dp["jailed"].append(agent)
		_set_relation(kingdom, relation(kingdom) - 10)
		changed.emit()
		return _fail("%s tertangkap di %s! Hubungan memburuk dan %s tidak bisa bertugas lagi hari ini." % [who, name, who])
	var msg := ""
	match mission:
		"intai":
			dp["scout"][kingdom] = now + 86400.0
			msg = "%s mengintai %s: kekuatan %d." % [who, name, kingdom_power(kingdom)]
		"curi":
			var amount := int(affair_yield("silver") * 2)
			silver += amount
			msg = "%s mencuri %d perak dari %s." % [who, amount, name]
		"sabotase":
			dp["sabotage"][kingdom] = now + 86400.0
			msg = "%s menyabotase %s: kekuatannya -20%% selama sehari." % [who, name]
	changed.emit()
	return _ok(msg)


# --- Pemberontakan -------------------------------------------------------------------

func _check_rebellion() -> bool:
	if not policy_unlocked() or realm["rebel"]["active"]:
		return false
	if int(court.get("loyalty", 50)) >= Data.REBEL_LOYALTY:
		return false
	realm["rebel"] = {"active": true, "soldiers": int(affair_yield("soldiers") * Data.REBEL_SOLDIERS)}
	return true


func rebellion() -> Dictionary:
	return realm["rebel"] if realm["rebel"]["active"] else {}


## Tumpas (prajurit) atau bujuk (pangan) pemberontak.
func end_rebellion(crush: bool) -> Dictionary:
	if rebellion().is_empty():
		return _fail("Tidak ada pemberontakan.")
	var need := int(realm["rebel"]["soldiers"])
	var result: Dictionary
	if crush:
		if soldiers < need:
			return _fail("Prajurit tidak cukup (butuh %d)." % need)
		soldiers -= need
		prestige += 20
		court["loyalty"] = maxi(int(court["loyalty"]), Data.REBEL_LOYALTY + 5)
		result = _ok("Pemberontakan ditumpas. -%d prajurit, +20 prestise. Rakyat takut, kesetiaan %d." % [need, court["loyalty"]])
		result["plan"] = battle_plan(rng.randf_range(0.4, 0.75), 0.0, rng.randi())
	else:
		var cost := int(affair_yield("grain") * 3)
		if grain < cost:
			return _fail("Pangan tidak cukup (butuh %d)." % cost)
		grain -= cost
		court["loyalty"] = maxi(int(court["loyalty"]) + 15, Data.REBEL_LOYALTY + 10)
		result = _ok("Pemberontak dibujuk dengan %d pangan. Kesetiaan rakyat %d." % [cost, court["loyalty"]])
	realm["rebel"] = {"active": false, "soldiers": 0}
	_track("rebellion")
	changed.emit()
	return result


# --- Pacuan Kuda ----------------------------------------------------------------------

func races_left(now: float) -> int:
	var r: Dictionary = realm["race"]
	return Data.RACE_PER_DAY - (int(r["used"]) if int(r["day"]) == day_index(now) else 0)


func horse_speed(id: String) -> float:
	var def: Dictionary = Data.HORSES[id]
	return float(Data.RACE_SPEED[def["rarity"]]) * (1.0 + Data.RACE_LEVEL_SPEED * (int(horses[id]["level"]) - 1))


## Pacuan: hasil memuat "lanes" (urut jalur) dan "order" (indeks jalur sesuai urutan finis).
func go_race(horse: String, now: float) -> Dictionary:
	if horses.is_empty():
		return _fail("Beli kuda di Kandang Kuda dulu.")
	if not horses.has(horse):
		return _fail("Kuda belum dimiliki.")
	if races_left(now) <= 0:
		return _fail("Pacuan hari ini sudah selesai. Kembali besok.")
	var r: Dictionary = realm["race"]
	if int(r["day"]) != day_index(now):
		r["day"] = day_index(now)
		r["used"] = 0
	r["used"] = int(r["used"]) + 1
	var lanes := []
	var names: Array = Data.RACE_RIVAL_NAMES.duplicate()
	for i in Data.RACE_RIVALS:
		var pick: String = names.pop_at(rng.randi_range(0, names.size() - 1))
		var hid: String = Data.HORSE_ORDER[rng.randi_range(0, Data.HORSE_ORDER.size() - 1)]
		lanes.append({"name": pick, "horse": hid, "speed": rng.randf_range(0.95, 1.38), "me": false})
	var me_lane := rng.randi_range(0, lanes.size())
	lanes.insert(me_lane, {"name": me_name(), "horse": horse, "speed": horse_speed(horse), "me": true})
	var scores := []
	for i in lanes.size():
		scores.append([float(lanes[i]["speed"]) * rng.randf_range(0.88, 1.12), i])
	scores.sort_custom(func(a, b): return a[0] > b[0])
	var order: Array = scores.map(func(x): return x[1])
	var place: int = order.find(me_lane) + 1
	if place == 1:
		_track("race_win")
	var def: Dictionary = Data.RACE_REWARDS[place - 1]
	var reward := _yields_of({"silver": def["silver"]})
	if def.has("gold"):
		reward["gold"] = int(def["gold"])
	var text := _give_rewards(reward)
	_track("race")
	changed.emit()
	var result := _ok("%s finis di urutan ke-%d! %s." % [Data.HORSES[horse]["name"], place, text])
	result["place"] = place
	result["lanes"] = lanes
	result["order"] = order
	result["me_lane"] = me_lane
	return result


# --- Kuis Sejarah Nusantara ---------------------------------------------------------------

## Soal hari ini: [{index, q, options (diacak), answer (indeks pilihan benar)}].
func quiz_today(now: float) -> Array:
	var r := _seeded(["quiz", day_index(now)])
	var pool := range(Data.QUIZ.size())
	var out := []
	for i in Data.QUIZ_PER_DAY:
		var qi: int = pool.pop_at(r.randi_range(0, pool.size() - 1))
		var q: Dictionary = Data.QUIZ[qi]
		var order := [0, 1, 2, 3]
		for k in range(3, 0, -1):
			var j := r.randi_range(0, k)
			var tmp = order[k]
			order[k] = order[j]
			order[j] = tmp
		out.append({"index": qi, "q": q["q"], "options": order.map(func(o): return q["a"][o]),
			"answer": order.find(int(q["c"]))})
	return out


func _quiz_state(now: float) -> Dictionary:
	var q: Dictionary = realm["quiz"]
	if int(q["day"]) != day_index(now):
		q["day"] = day_index(now)
		q["answers"] = {}
	return q


func quiz_answered(slot: int, now: float) -> int:
	var a: Dictionary = _quiz_state(now)["answers"]
	return -1 if not a.has(str(slot)) else (1 if a[str(slot)] else 0)


func quiz_left(now: float) -> int:
	return Data.QUIZ_PER_DAY - _quiz_state(now)["answers"].size()


func answer_quiz(slot: int, choice: int, now: float) -> Dictionary:
	if slot < 0 or slot >= Data.QUIZ_PER_DAY:
		return _fail("Soal tidak ditemukan.")
	var st := _quiz_state(now)
	if st["answers"].has(str(slot)):
		return _fail("Soal ini sudah dijawab.")
	var q: Dictionary = quiz_today(now)[slot]
	var correct: bool = choice == int(q["answer"])
	st["answers"][str(slot)] = correct
	_track("quiz")
	var msg := ""
	if correct:
		_track("quiz_correct")
		msg = "Benar! %s." % _give_rewards(_yields_of(Data.QUIZ_REWARD))
	else:
		msg = "Kurang tepat. Jawaban yang benar: %s." % q["options"][q["answer"]]
	if st["answers"].size() == Data.QUIZ_PER_DAY and st["answers"].values().all(func(v): return v):
		gold += Data.QUIZ_PERFECT_GOLD
		msg += " Sempurna, lima benar! +%d emas." % Data.QUIZ_PERFECT_GOLD
	changed.emit()
	var result := _ok(msg)
	result["correct"] = correct
	return result


# --- Penjelajahan Candi ----------------------------------------------------------------------

func candi_unlocked() -> bool:
	return stage >= Data.CANDI_UNLOCK_STAGE


func _candi_state(now: float) -> Dictionary:
	var c: Dictionary = realm["candi"]
	if int(c["day"]) != day_index(now):
		c["day"] = day_index(now)
		c["runs"] = 0
	return c


func candi_run() -> Dictionary:
	return realm["candi"]["run"]


func candi_free_left(now: float) -> int:
	return maxi(0, Data.CANDI_FREE - int(_candi_state(now)["runs"]))


func candi_extra_left(now: float) -> int:
	return Data.CANDI_FREE + Data.CANDI_EXTRA_LIMIT - maxi(int(_candi_state(now)["runs"]), Data.CANDI_FREE)


func _candi_doors(seed_key: int, room: int) -> Array:
	if room == Data.CANDI_ROOMS - 1:
		return ["boss"]
	var r := _seeded(["candi", seed_key, room])
	var pool := []
	for k in Data.CANDI_KINDS:
		for w in int(Data.CANDI_KINDS[k]["weight"]):
			pool.append(k)
	var a: String = pool[r.randi_range(0, pool.size() - 1)]
	var b: String = pool[r.randi_range(0, pool.size() - 1)]
	while b == a:
		b = pool[r.randi_range(0, pool.size() - 1)]
	return [a, b]


func enter_candi(now: float) -> Dictionary:
	if not candi_unlocked():
		return _fail("Menangkan Tahap %d untuk membuka Penjelajahan Candi." % Data.CANDI_UNLOCK_STAGE)
	if not candi_run().is_empty():
		return _fail("Penjelajahan masih berlangsung.")
	var c := _candi_state(now)
	if candi_free_left(now) <= 0:
		if candi_extra_left(now) <= 0:
			return _fail("Batas penjelajahan hari ini sudah habis.")
		if gold < Data.CANDI_EXTRA_GOLD:
			return _fail("Emas tidak cukup (butuh %d)." % Data.CANDI_EXTRA_GOLD)
		gold -= Data.CANDI_EXTRA_GOLD
	c["runs"] = int(c["runs"]) + 1
	var seed_key := rng.randi()
	c["run"] = {"room": 0, "hp": Data.CANDI_HP, "loot": {}, "doors": _candi_doors(seed_key, 0), "seed": seed_key, "log": []}
	_track("candi")
	changed.emit()
	return _ok("Rombongan memasuki candi kuno.")


func _loot_add(loot: Dictionary, reward: Dictionary) -> void:
	for k in reward:
		if k == "items":
			if not loot.has("items"):
				loot["items"] = {}
			for it in reward["items"]:
				loot["items"][it] = int(loot["items"].get(it, 0)) + int(reward["items"][it])
		else:
			loot[k] = int(loot.get(k, 0)) + int(reward[k])


func candi_boss_power() -> int:
	return int(Data.MAP_POWER_BASE * pow(Data.MAP_POWER_GROWTH, stage) * 0.9)


## Masuki pintu `door`. Ruangan terakhir: penjaga utama (hasil "boss" berisi naskah duel).
func candi_choose(door: int) -> Dictionary:
	var run := candi_run()
	if run.is_empty():
		return _fail("Belum masuk candi.")
	var doors: Array = run["doors"]
	if door < 0 or door >= doors.size():
		return _fail("Pintu tidak ada.")
	var kind: String = doors[door]
	var r := RandomNumberGenerator.new()
	r.seed = hash([run["seed"], run["room"], door])
	var msg := ""
	match kind:
		"harta":
			var reward := _yields_of({"silver": r.randf_range(1.0, 2.0)})
			reward["items"] = {"besi_tempa" if r.randf() < 0.6 else "kayu_cendana": 1}
			_loot_add(run["loot"], reward)
			msg = "Ruang harta! Didapat %s." % _reward_list(reward)
		"jebakan":
			var dmg := r.randi_range(20, 35)
			run["hp"] = int(run["hp"]) - dmg
			msg = "Jebakan panah! Semangat -%d." % dmg
		"penjaga":
			var win := r.randf() < clampf(float(combat_power()) / maxf(1.0, candi_boss_power() * 0.6), 0.2, 0.9)
			if win:
				var reward := {"besi_tempa": 1}
				_loot_add(run["loot"], {"items": reward, "soldiers": int(affair_yield("soldiers") * 0.5)})
				msg = "Arca penjaga dikalahkan! Didapat Besi Tempa dan prajurit tawanan."
			else:
				var dmg := r.randi_range(25, 40)
				run["hp"] = int(run["hp"]) - dmg
				msg = "Arca penjaga terlalu kuat. Semangat -%d." % dmg
		"mata_air":
			run["hp"] = mini(Data.CANDI_HP, int(run["hp"]) + 30)
			msg = "Mata air suci memulihkan semangat +30."
		"relik":
			var reward := {"gold": r.randi_range(4, 10)}
			if r.randf() < 0.35:
				reward["items"] = {"batu_meteor": 1}
			_loot_add(run["loot"], reward)
			msg = "Relik kuno ditemukan! Didapat %s." % _reward_list(reward)
		"boss":
			return _candi_boss(r)
	if int(run["hp"]) <= 0:
		return _candi_end(false, msg + " Semangat habis, rombongan mundur dan separuh harta tertinggal.")
	run["room"] = int(run["room"]) + 1
	run["doors"] = _candi_doors(int(run["seed"]), int(run["room"]))
	changed.emit()
	var result := _ok(msg)
	result["kind"] = kind
	return result


func _candi_boss(r: RandomNumberGenerator) -> Dictionary:
	var ratio := float(combat_power()) / maxf(1.0, candi_boss_power())
	var win := r.randf() < clampf(0.5 + (ratio - 1.0) * 0.8, 0.15, 0.9)
	if win:
		_track("candi_boss")
		_loot_add(candi_run()["loot"], {"gold": 20, "items": {"batu_meteor": 1}})
		_loot_add(candi_run()["loot"], _yields_of({"silver": 3.0}))
	var result := _candi_end(win, "Buto penjaga candi tumbang! Harta disempurnakan." if win
		else "Buto penjaga candi terlalu kuat. Rombongan mundur dengan separuh harta.")
	result["boss"] = true
	result["win"] = win
	result["ratio"] = ratio
	return result


## Akhiri penjelajahan. full = bawa semua harta; selain itu separuhnya.
func _candi_end(full: bool, msg: String) -> Dictionary:
	var loot: Dictionary = candi_run()["loot"]
	if not full:
		for k in loot:
			if k == "items":
				for it in loot["items"]:
					loot["items"][it] = int(loot["items"][it]) / 2
			else:
				loot[k] = int(loot[k]) / 2
	realm["candi"]["run"] = {}
	var text := _give_rewards(loot)
	changed.emit()
	return _ok(msg + (" Dibawa pulang: %s." % text if text != "" else ""))


func leave_candi() -> Dictionary:
	if candi_run().is_empty():
		return _fail("Belum masuk candi.")
	return _candi_end(true, "Rombongan keluar dari candi dengan selamat.")


func _reward_list(reward: Dictionary) -> String:
	var parts := []
	for k in Data.REWARD_KEYS:
		if int(reward.get(k, 0)) > 0:
			parts.append("+%d %s" % [reward[k], Data.REWARD_NAMES[k]])
	for it in reward.get("items", {}):
		parts.append("+%d %s" % [reward["items"][it], Data.ITEMS[it]["name"]])
	return ", ".join(parts)


# --- Besalen (tempa pusaka) -------------------------------------------------------------------

func forge_unlocked() -> bool:
	return stage >= Data.FORGE_UNLOCK_STAGE


func forge_silver() -> int:
	return int(affair_yield("silver") * Data.FORGE_SILVER)


func forge(slot: String, use_meteor: bool) -> Dictionary:
	if not forge_unlocked():
		return _fail("Menangkan Tahap %d untuk membuka Besalen." % Data.FORGE_UNLOCK_STAGE)
	if not Data.EQUIP_SLOTS.has(slot):
		return _fail("Jenis pusaka tidak dikenal.")
	for it in Data.FORGE_COST:
		if item_count(it) < int(Data.FORGE_COST[it]):
			return _fail("Bahan kurang: butuh %d %s." % [Data.FORGE_COST[it], Data.ITEMS[it]["name"]])
	if use_meteor and item_count("batu_meteor") <= 0:
		return _fail("Tidak punya Batu Meteor.")
	if silver < forge_silver():
		return _fail("Perak tidak cukup (butuh %d)." % forge_silver())
	if equipment.size() >= Data.EQUIP_CAPACITY:
		return _fail("Gudang pusaka penuh.")
	for it in Data.FORGE_COST:
		inventory[it] = item_count(it) - int(Data.FORGE_COST[it])
	if use_meteor:
		inventory["batu_meteor"] = item_count("batu_meteor") - 1
	silver -= forge_silver()
	var odds: Array = Data.FORGE_ODDS_METEOR if use_meteor else Data.FORGE_ODDS
	var roll := rng.randf()
	var rarity := "ssr" if roll < float(odds[1]) else ("sr" if roll < float(odds[0]) + float(odds[1]) else "r")
	var pool := Data.EQUIPMENT.keys().filter(func(k): return Data.EQUIPMENT[k]["slot"] == slot and Data.EQUIPMENT[k]["rarity"] == rarity)
	if pool.is_empty():
		pool = Data.EQUIPMENT.keys().filter(func(k): return Data.EQUIPMENT[k]["slot"] == slot)
	var id: String = pool[rng.randi_range(0, pool.size() - 1)]
	var eq := add_equipment(id)
	_track("forge")
	changed.emit()
	var result := _ok("Empu menempa %s (%s)!" % [Data.EQUIPMENT[id]["name"], Data.RARITIES[Data.EQUIPMENT[id]["rarity"]]["name"]])
	result["equip"] = eq
	return result


# --- Hewan peliharaan --------------------------------------------------------------------------

func pet_unlocked() -> bool:
	return stage >= Data.PET_UNLOCK_STAGE


func pet_level(id: String) -> int:
	return int(realm.get("pets", {}).get("owned", {}).get(id, 0))


func pet_value(id: String) -> float:
	var def: Dictionary = Data.PETS[id]
	return float(def["base"]) + float(def["per"]) * (pet_level(id) - 1)


func pet_bonus(effect: String) -> float:
	var active := str(realm.get("pets", {}).get("active", ""))
	if active == "" or Data.PETS[active]["effect"] != effect:
		return 0.0
	return pet_value(active)


func adopt_pet(id: String) -> Dictionary:
	if not pet_unlocked():
		return _fail("Menangkan Tahap %d untuk memelihara hewan." % Data.PET_UNLOCK_STAGE)
	if not Data.PETS.has(id):
		return _fail("Hewan tidak dikenal.")
	if pet_level(id) > 0:
		return _fail("Hewan ini sudah dipelihara.")
	var cost: Dictionary = Data.PETS[id]["cost"]
	for k in cost:
		if int(get(k)) < int(cost[k]):
			return _fail("%s tidak cukup (butuh %d)." % [Data.REWARD_NAMES[k].capitalize(), cost[k]])
	for k in cost:
		set(k, int(get(k)) - int(cost[k]))
	realm["pets"]["owned"][id] = 1
	if str(realm["pets"]["active"]) == "":
		realm["pets"]["active"] = id
	_track("pet")
	changed.emit()
	return _ok("%s kini tinggal di istana!" % Data.PETS[id]["name"])


func set_active_pet(id: String) -> Dictionary:
	if pet_level(id) <= 0:
		return _fail("Hewan belum dipelihara.")
	realm["pets"]["active"] = id
	changed.emit()
	return _ok("%s menemani Tuan." % Data.PETS[id]["name"])


func pet_feed_cost(id: String) -> int:
	return int(affair_yield("silver") * Data.PET_FEED * maxi(1, pet_level(id)))


func feed_pet(id: String) -> Dictionary:
	if pet_level(id) <= 0:
		return _fail("Hewan belum dipelihara.")
	if pet_level(id) >= Data.PET_MAX_LEVEL:
		return _fail("%s sudah mencapai level tertinggi." % Data.PETS[id]["name"])
	var cost := pet_feed_cost(id)
	if silver < cost:
		return _fail("Perak tidak cukup (butuh %d)." % cost)
	silver -= cost
	realm["pets"]["owned"][id] = pet_level(id) + 1
	changed.emit()
	return _ok("%s naik ke level %d." % [Data.PETS[id]["name"], pet_level(id)])


# --- Bonus pemain kembali ----------------------------------------------------------------------

func comeback_active(now: float) -> bool:
	return float(realm.get("comeback", {}).get("until", 0.0)) > now


## Mulai bonus kembali (dari away_report). False bila masih berlangsung.
func start_comeback(now: float) -> bool:
	if comeback_active(now):
		return false
	var base := {}
	for m in Data.COMEBACK_MISSIONS:
		base[m["event"]] = int(counters.get(m["event"], 0))
	realm["comeback"] = {"until": now + Data.COMEBACK_HOURS * 3600.0, "pack": false, "base": base, "done": []}
	var letter: Dictionary = Data.COMEBACK_MAIL.duplicate(true)
	letter["id"] = "local:kembali_%d" % day_index(now)
	add_mail(letter, now)
	changed.emit()
	return true


func comeback_progress(index: int) -> int:
	var m: Dictionary = Data.COMEBACK_MISSIONS[index]
	var cb: Dictionary = realm["comeback"]
	return mini(int(m["target"]), int(counters.get(m["event"], 0)) - int(cb.get("base", {}).get(m["event"], 0)))


func claim_comeback_pack(now: float) -> Dictionary:
	if not comeback_active(now) or realm["comeback"]["pack"]:
		return _fail("Paket bantuan tidak tersedia.")
	realm["comeback"]["pack"] = true
	var text := _give_rewards(Data.COMEBACK_PACK)
	changed.emit()
	return _ok("Paket bantuan: %s." % text)


func claim_comeback_mission(index: int, now: float) -> Dictionary:
	if not comeback_active(now) or index < 0 or index >= Data.COMEBACK_MISSIONS.size():
		return _fail("Misi tidak tersedia.")
	var cb: Dictionary = realm["comeback"]
	if cb["done"].has(index):
		return _fail("Hadiah misi ini sudah diambil.")
	if comeback_progress(index) < int(Data.COMEBACK_MISSIONS[index]["target"]):
		return _fail("Misi belum selesai.")
	cb["done"].append(index)
	var text := _give_rewards(Data.COMEBACK_MISSIONS[index]["reward"])
	changed.emit()
	return _ok("Misi kembali selesai: %s." % text)


# --- Kode hadiah -------------------------------------------------------------------------------

static func normalize_code(code: String) -> String:
	return code.strip_edges().to_upper().replace(" ", "")


## Kode bawaan (offline). Kode dari server ditukar lewat redeem_server_reward().
func redeem_code(code: String) -> Dictionary:
	var c := normalize_code(code)
	if c.length() < 4:
		return _fail("Kode tidak valid.")
	var h := c.sha256_text()
	if realm["codes"].has(h):
		return _fail("Kode ini sudah dipakai.")
	if not Data.GIFT_CODES.has(h):
		return _fail("Kode tidak dikenal atau sudah kedaluwarsa.")
	realm["codes"].append(h)
	var text := _give_rewards(Data.GIFT_CODES[h]["reward"])
	changed.emit()
	return _ok("Kode berhasil ditukar: %s." % text)


## Hadiah kode dari server, dibatasi GIFT_CODE_LIMITS. Kode dicatat agar tidak dipakai dua kali.
func redeem_server_reward(code: String, reward: Dictionary) -> Dictionary:
	var c := normalize_code(code)
	var h := c.sha256_text()
	if realm["codes"].has(h):
		return _fail("Kode ini sudah dipakai.")
	var safe := {}
	for k in Data.GIFT_CODE_LIMITS:
		if reward.has(k):
			safe[k] = clampi(int(reward[k]), 0, int(Data.GIFT_CODE_LIMITS[k]))
	var items = reward.get("items", {})
	if items is Dictionary:
		safe["items"] = {}
		for it in items:
			if Data.ITEMS.has(str(it)):
				safe["items"][str(it)] = clampi(int(items[it]), 0, Data.GIFT_CODE_ITEM_LIMIT)
	realm["codes"].append(h)
	var text := _give_rewards(safe)
	changed.emit()
	return _ok("Kode berhasil ditukar: %s." % (text if text != "" else "-"))


# --- Bos Dunia (online) -------------------------------------------------------------------------

## Hadiah minggu lalu: rank (1 = terbaik) dari `players` penyerang.
func world_boss_reward(rank: int, players: int, defeated: bool) -> Dictionary:
	if rank <= 0 or players <= 0:
		return {}
	var pct := float(rank) / players
	for tier in Data.WORLD_BOSS_REWARDS:
		if pct <= float(tier["top"]):
			var r: Dictionary = tier["reward"].duplicate(true)
			if not defeated:
				r["gold"] = int(r.get("gold", 0)) / 2
				r.erase("items")
			return r
	return {}


func claim_world_boss(week: int, rank: int, players: int, defeated: bool) -> Dictionary:
	if week <= int(realm["wb_claimed"]):
		return _fail("Hadiah Bos Dunia minggu itu sudah diambil.")
	var reward := world_boss_reward(rank, players, defeated)
	if reward.is_empty():
		return _fail("Tuan tidak ikut menyerang Bos Dunia minggu lalu.")
	realm["wb_claimed"] = week
	var text := _give_rewards(reward)
	changed.emit()
	return _ok("Hadiah Bos Dunia (peringkat %d dari %d): %s." % [rank, players, text])


# --- Batch 6: muat & validasi ------------------------------------------------------

func _load_realm6(src: Dictionary) -> void:
	var u = src.get("usage", {})
	if u is Dictionary:
		for id in u:
			if not Data.counselor_def(str(id)).is_empty():
				realm["usage"][str(id)] = maxi(0, int(u[id]))
	var w = src.get("wayang", {})
	if w is Dictionary:
		realm["wayang"]["day"] = int(w.get("day", -1))
		var done = w.get("done", {})
		if done is Dictionary:
			for id in done:
				if not folktale_def(str(id)).is_empty():
					realm["wayang"]["done"][str(id)] = clampi(int(done[id]), 0, 3)
	var c = src.get("ceremony", {})
	if c is Dictionary:
		realm["ceremony"] = {"last_day": int(c.get("last_day", -1000)),
			"id": str(c.get("id", "")) if Data.CEREMONIES.has(str(c.get("id", ""))) else "",
			"until": float(c.get("until", 0.0))}
	var b = src.get("badges", {})
	if b is Dictionary:
		realm["badges"]["season"] = int(b.get("season", -1))
		for k in b.get("base", {}):
			realm["badges"]["base"][str(k)] = int(b["base"][k])
		var earned = b.get("earned", {})
		if earned is Dictionary:
			for season in earned:
				var ids := []
				for id in earned[season]:
					if not badge_def(str(id)).is_empty() and not ids.has(str(id)):
						ids.append(str(id))
				realm["badges"]["earned"][str(int(season))] = ids
	realm["tourney_claimed"] = int(src.get("tourney_claimed", -1))
	_load_realm7(src)
	_load_realm8(src)
	_load_realm9(src)
	for key in ["holidays"]:
		for v in src.get(key, []):
			if str(v).length() <= 24 and not realm[key].has(str(v)):
				realm[key].append(str(v))
	for v in src.get("journey", []):
		if int(v) >= 0 and int(v) < Data.JOURNEY.size() and not realm["journey"].has(int(v)):
			realm["journey"].append(int(v))
	for v in src.get("raid_claimed", []):
		if not realm["raid_claimed"].has(int(v)):
			realm["raid_claimed"].append(int(v))


# --- Gelar kehormatan penasihat ---------------------------------------------------------

func use_counselor(id: String, amount := 1) -> void:
	if counselors.has(id):
		realm["usage"][id] = int(realm["usage"].get(id, 0)) + amount


func counselor_uses(id: String) -> int:
	return int(realm.get("usage", {}).get(id, 0))


## Gelar tertinggi yang dicapai {name, bonus, uses} atau {}.
func counselor_title(id: String) -> Dictionary:
	var best := {}
	for t in Data.COUNSELOR_TITLES:
		if counselor_uses(id) >= int(t["uses"]):
			best = t
	return best


func title_bonus(id: String) -> float:
	return float(counselor_title(id).get("bonus", 0.0))


## Gelar berikutnya {name, uses} atau {}.
func next_counselor_title(id: String) -> Dictionary:
	for t in Data.COUNSELOR_TITLES:
		if counselor_uses(id) < int(t["uses"]):
			return t
	return {}


# --- Wayang & cerita rakyat -----------------------------------------------------------------

func wayang_unlocked() -> bool:
	return stage >= Data.WAYANG_UNLOCK_STAGE


func folktale_def(id: String) -> Dictionary:
	for t in Data.FOLKTALES:
		if t["id"] == id:
			return t
	return {}


func wayang_progress(id: String) -> int:
	return int(realm["wayang"]["done"].get(id, 0))


func wayang_ready(now: float) -> bool:
	return wayang_unlocked() and int(realm["wayang"]["day"]) != day_index(now)


## Tonton babak berikutnya sebuah lakon. Satu babak per hari (lakon mana pun).
func watch_wayang(id: String, now: float) -> Dictionary:
	if not wayang_unlocked():
		return _fail("Menangkan Tahap %d untuk menonton wayang." % Data.WAYANG_UNLOCK_STAGE)
	var t := folktale_def(id)
	if t.is_empty():
		return _fail("Lakon tidak dikenal.")
	var part := wayang_progress(id)
	if part >= t["episodes"].size():
		return _fail("Lakon ini sudah tamat.")
	if not wayang_ready(now):
		return _fail("Sang dalang beristirahat. Babak berikutnya besok.")
	realm["wayang"]["day"] = day_index(now)
	realm["wayang"]["done"][id] = part + 1
	var reward := _yields_of(Data.WAYANG_EPISODE_REWARD)
	var finished: bool = part + 1 >= t["episodes"].size()
	if finished:
		reward["gold"] = Data.WAYANG_TALE_GOLD
		unlock_cosmetic(t["frame"])
	var text := _give_rewards(reward)
	_track("wayang")
	changed.emit()
	var result := _ok(("Lakon %s tamat! %s, bingkai baru terbuka." if finished else "Babak %d %s: %s.")
		% ([t["name"], text] if finished else [part + 1, t["name"], text]))
	result["episode"] = t["episodes"][part]
	result["part"] = part
	return result


# --- Upacara kerajaan --------------------------------------------------------------------

func ceremony_unlocked() -> bool:
	return stage >= Data.CEREMONY_UNLOCK_STAGE


func ceremony_cooldown_days(now: float) -> int:
	return maxi(0, int(realm["ceremony"]["last_day"]) + Data.CEREMONY_DAYS - day_index(now))


func ceremony_active(now: float) -> String:
	var c: Dictionary = realm.get("ceremony", {})
	return str(c.get("id", "")) if float(c.get("until", 0.0)) > now else ""


func ceremony_bonus(effect: String, now: float) -> float:
	var id := ceremony_active(now)
	return float(Data.CEREMONIES[id]["effects"].get(effect, 0.0)) if id != "" else 0.0


func ceremony_cost(id: String) -> Dictionary:
	return _yields_of(Data.CEREMONIES[id]["cost"])


func hold_ceremony(id: String, now: float) -> Dictionary:
	if not ceremony_unlocked():
		return _fail("Menangkan Tahap %d untuk menggelar upacara." % Data.CEREMONY_UNLOCK_STAGE)
	if not Data.CEREMONIES.has(id):
		return _fail("Upacara tidak dikenal.")
	if ceremony_cooldown_days(now) > 0:
		return _fail("Upacara berikutnya bisa digelar dalam %d hari." % ceremony_cooldown_days(now))
	var cost := ceremony_cost(id)
	for k in cost:
		if int(get(k)) < int(cost[k]):
			return _fail("%s tidak cukup (butuh %d)." % [Data.REWARD_NAMES[k].capitalize(), cost[k]])
	for k in cost:
		set(k, int(get(k)) - int(cost[k]))
	var def: Dictionary = Data.CEREMONIES[id]
	if int(def.get("loyalty", 0)) != 0:
		court["loyalty"] = clampi(int(court.get("loyalty", 50)) + int(def["loyalty"]), 0, 100)
	realm["ceremony"] = {"last_day": day_index(now), "id": id, "until": now + Data.CEREMONY_HOURS * 3600.0}
	_track("ceremony")
	changed.emit()
	return _ok("Upacara %s digelar! Berkah berlaku 24 jam." % def["name"])


# --- Lencana musiman ---------------------------------------------------------------------

func badge_def(id: String) -> Dictionary:
	for b in Data.BADGES:
		if b["id"] == id:
			return b
	return {}


func badge_season(now: float) -> int:
	return int(floor(day_index(now) / float(Data.BADGE_SEASON_DAYS)))


## Nomor musim untuk pemain (1 = musim saat mulai bermain).
func badge_season_number(season: int) -> int:
	return season - int(floor(start_day / float(Data.BADGE_SEASON_DAYS))) + 1


func badge_season_days_left(now: float) -> int:
	return (badge_season(now) + 1) * Data.BADGE_SEASON_DAYS - day_index(now)


func _ensure_badge_season(now: float) -> void:
	var b: Dictionary = realm["badges"]
	if int(b["season"]) == badge_season(now):
		return
	b["season"] = badge_season(now)
	b["base"] = {}
	for d in Data.BADGES:
		b["base"][d["event"]] = int(counters.get(d["event"], 0))


func badge_progress(id: String, now: float) -> int:
	_ensure_badge_season(now)
	var d := badge_def(id)
	return mini(int(d["target"]), int(counters.get(d["event"], 0)) - int(realm["badges"]["base"].get(d["event"], 0)))


func badges_earned(season: int) -> Array:
	return realm["badges"]["earned"].get(str(season), [])


## Semua lencana yang pernah didapat: [{id, season}].
func badge_album() -> Array:
	var out := []
	var seasons: Array = realm["badges"]["earned"].keys()
	seasons.sort_custom(func(a, b): return int(a) > int(b))
	for s in seasons:
		for id in realm["badges"]["earned"][s]:
			out.append({"id": id, "season": int(s)})
	return out


## Berikan lencana yang targetnya tercapai musim ini. True bila ada yang baru.
func check_badges(now: float) -> bool:
	_ensure_badge_season(now)
	var season := badge_season(now)
	var key := str(season)
	var got := false
	for d in Data.BADGES:
		if badges_earned(season).has(d["id"]) or badge_progress(d["id"], now) < int(d["target"]):
			continue
		if not realm["badges"]["earned"].has(key):
			realm["badges"]["earned"][key] = []
		realm["badges"]["earned"][key].append(d["id"])
		gold += Data.BADGE_GOLD
		badge_earned.emit(d["id"])
		got = true
	return got


# --- Ambil semua hadiah harian -----------------------------------------------------------------

## Kumpulkan semua yang siap tanpa tayangan: login, VIP, besan, kebun, upeti, ekspedisi,
## kapal (yang tidak diserang bajak laut tetap memakai hasil acaknya), paket kembali.
func collect_daily(now: float) -> Dictionary:
	var parts := []
	var add := func(label: String, r: Dictionary):
		if r.get("ok", false):
			parts.append(label)
	if login_can_claim(now):
		add.call("hadiah login", claim_login(now))
	if vip_daily_can_claim(now):
		add.call("hadiah VIP", claim_vip_daily(now))
	if kin_gift_ready(now):
		add.call("kiriman besan", claim_kin_gifts(now))
	if garden_unlocked() and garden_ready_count(now) > 0:
		add.call("panen kebun", harvest_all(now))
	if not tribute_pending(now).values().all(func(v): return v <= 0):
		add.call("upeti", collect_tribute(now))
	if expeditions_ready(now) > 0:
		add.call("ekspedisi", claim_all_expeditions(now))
	for ship in ships_owned():
		if not voyage(ship).is_empty() and voyage_eta(ship, now) <= 0:
			add.call("kapal %s" % Data.SHIPS[ship]["name"], claim_voyage(ship, now))
	if comeback_active(now) and not realm["comeback"]["pack"]:
		add.call("paket bantuan", claim_comeback_pack(now))
	if parts.is_empty():
		return _fail("Belum ada yang bisa diambil. Kembali nanti, Tuan.")
	_track("collect_all")
	return _ok("Diambil: %s." % ", ".join(parts))


func collect_daily_count(now: float) -> int:
	var n := 0
	n += 1 if login_can_claim(now) else 0
	n += 1 if vip_daily_can_claim(now) else 0
	n += 1 if kin_gift_ready(now) else 0
	n += 1 if garden_unlocked() and garden_ready_count(now) > 0 else 0
	n += 0 if tribute_pending(now).values().all(func(v): return v <= 0) else 1
	n += 1 if expeditions_ready(now) > 0 else 0
	for ship in ships_owned():
		n += 1 if not voyage(ship).is_empty() and voyage_eta(ship, now) <= 0 else 0
	n += 1 if comeback_active(now) and not realm["comeback"]["pack"] else 0
	return n


# --- Turnamen silat online ----------------------------------------------------------------------

func tourney_reward(round_reached: int) -> Dictionary:
	return Data.TOURNEY_REWARDS[clampi(round_reached, 0, Data.TOURNEY_REWARDS.size() - 1)]


func claim_tourney(week: int, round_reached: int) -> Dictionary:
	if week <= int(realm["tourney_claimed"]):
		return _fail("Hadiah turnamen minggu itu sudah diambil.")
	if round_reached < 0:
		return _fail("Tuan tidak ikut turnamen minggu itu.")
	realm["tourney_claimed"] = week
	var text := _give_rewards(tourney_reward(round_reached))
	changed.emit()
	return _ok("Hadiah Turnamen Silat (%s): %s." % [Data.TOURNEY_ROUND_NAMES[clampi(round_reached, 0, 4)], text])


# --- Titik sambung ke bagian model berikutnya -------------------------------------------
## Diisi (di-override) oleh game_model.gd. Bagian ini memanggilnya, tetapi
## definisinya ada di file turunan yang dimuat sesudahnya.

func _load_realm7(src: Dictionary) -> void:
	pass

func _load_realm8(src: Dictionary) -> void:
	pass

func _load_realm9(src: Dictionary) -> void:
	pass

func add_mail(mail: Dictionary, now: float) -> bool:
	return false

func decor_bonus(effect: String) -> float:
	return 0.0

func meal_bonus(effect: String, now: float) -> float:
	return 0.0
