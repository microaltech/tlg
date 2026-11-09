extends RefCounted
## Tampilan fitur kerajaan: Perburuan, Pasar Malam, Kebijakan & Bencana, Kebun,
## Perpustakaan, Armada, Besan & Pernikahan, Teman, Perang Wilayah, Raja Hari Ini.
##
## Memakai komponen bersama dari main.gd (_open_panel, _button, _label, ...).
## Panel yang terbuka diisi ulang lewat refresh() setiap kali main membangun ulang.

const Data := preload("res://scripts/core/game_data.gd")
const Art := preload("res://scripts/ui/art.gd")
const UI := preload("res://scripts/ui/ui_theme.gd")
const HuntView := preload("res://scripts/ui/hunt_view.gd")
const RaceView := preload("res://scripts/ui/race_view.gd")

var ui  ## main.gd
var model

## key -> {"overlay", "box", "subtitle", "fill": Callable}
var _panels := {}
var _hunt_pick := ""
var _garden_seed := "jahe"
var _ship_route := {}  ## kapal -> indeks tujuan terpilih
var _friends := {}  ## data terakhir /v1/friends
var _guildwar := {}
var _friend_code_edit: LineEdit
var _race_pick := ""
var _forge_meteor := false
var _world_boss := {}
var _code_edit: LineEdit
var _hub_tab := "ekonomi"
var _tourney := {}


func _init(main) -> void:
	ui = main
	model = main.model


# --- Kerangka panel ----------------------------------------------------------------

func _show(key: String, title: String, icon: String, fill: Callable) -> void:
	if is_open(key):
		return
	var p: Dictionary = ui._open_panel(title, icon, func(): close(key))
	_panels[key] = {"overlay": p["overlay"], "box": p["content"], "subtitle": p["subtitle"], "fill": fill}
	_fill(key)


func is_open(key: String) -> bool:
	return _panels.has(key) and is_instance_valid(_panels[key]["overlay"])


func close(key: String) -> void:
	if is_open(key):
		Audio.play("click")
		_panels[key]["overlay"].queue_free()
	_panels.erase(key)


func _fill(key: String) -> void:
	var p: Dictionary = _panels[key]
	ui._clear(p["box"])
	p["fill"].call(p["box"], p["subtitle"])


## Isi ulang semua panel yang terbuka (dipanggil dari main._rebuild).
func refresh() -> void:
	for key in _panels.keys():
		if is_open(key):
			_fill(key)
		else:
			_panels.erase(key)


## Perbarui hitung mundur di panel yang terbuka tanpa membangun ulang (dari main._tick).
func tick() -> void:
	for key in ["market", "garden", "research", "fleet"]:
		if is_open(key):
			var p: Dictionary = _panels[key]
			if p.has("timer"):
				p["timer"].call()


func _result(r) -> void:
	if r is Dictionary and r.has("msg"):
		ui._show(r)


# --- Kota: kartu & spanduk ------------------------------------------------------------

func build_city_cards(box: VBoxContainer) -> void:
	_king_banner(box)
	_comeback_card(box)
	_rebellion_banner(box)
	_threat_banner(box)
	_disaster_banner(box)
	_hub_card(box)


func _king_banner(box: VBoxContainer) -> void:
	if not Online.is_online() or Online.king.is_empty():
		return
	var k: Dictionary = Online.king["king"]
	var card: HBoxContainer = ui._card(box)
	card.add_child(ui._tex(Art.icon("crown"), 72))
	var col: VBoxContainer = ui._col(card)
	var name_l: Label = ui._label(col, tr("Raja Hari Ini: %s") % k["name"], "CardTitle")
	name_l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var decree := str(Online.king.get("decree", "")) if Online.king.get("decree") != null else ""
	ui._label(col, Data.KING_DECREES[decree]["desc"] if Data.KING_DECREES.has(decree) else "Raja belum bertitah hari ini.",
		"CardLabel")
	var b: Button = ui._button(card, "Lihat", func():
		show_king()
		return null, true, "", "GoldButton")
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _disaster_banner(box: VBoxContainer) -> void:
	var d: Dictionary = model.disaster_active()
	if d.is_empty():
		return
	var card: HBoxContainer = ui._card(box)
	card.add_child(ui._tex(Art.icon("disaster"), 80))
	var col: VBoxContainer = ui._col(card)
	var t: Label = ui._label(col, "Bencana: %s" % d["name"], "CardTitle")
	t.add_theme_color_override("font_color", UI.RED)
	ui._label(col, d["desc"] + " " + _effects_text(d["effects"]), "CardLabel")
	var b: Button = ui._button(card, "Tangani", func():
		show_policy()
		return null, true, "", "")
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER


## Kartu "Urusan Kerajaan": pintu ke semua fitur kerajaan, dengan tanda yang siap.
func _hub_card(box: VBoxContainer) -> void:
	var now: float = Game.now()
	var inner: VBoxContainer = ui._col(ui._card(box))
	var head := _row(inner)
	var hl: Label = ui._label(head, "Urusan Kerajaan", "CardTitle")
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var season: Dictionary = model.season_def(now)
	head.add_child(ui._tex(Art.icon(season["icon"]), 40))
	var sl := _small(head, season["name"])
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ready: int = model.collect_daily_count(now)
	var all: Button = ui._button(inner, tr("Ambil Semua Harian (%d)") % ready if ready > 0 else tr("Ambil Semua Harian"),
		func(): return model.collect_daily(Game.now()), ready > 0, "chest_open", "GreenButton", false, "reveal_sr")
	all.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	all.add_theme_font_size_override("font_size", 24)
	var tiles := _hub_tiles(now)
	# Tab: hanya fitur yang sudah terbuka yang ditampilkan.
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	inner.add_child(tabs)
	for tab in Data.HUB_TABS:
		var count := 0
		for id in tab["tiles"]:
			if tiles.has(id) and tiles[id]["open"]:
				count += int(tiles[id]["badge"])
		var tb := Button.new()
		tb.text = tr(tab["name"]) + (" (%d)" % count if count > 0 else "")
		tb.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.custom_minimum_size.y = 58
		tb.clip_text = true
		tb.add_theme_font_size_override("font_size", 19)
		tb.theme_type_variation = "GoldButton" if tab["id"] == _hub_tab else ""
		var tid: String = tab["id"]
		tb.pressed.connect(func():
			Audio.play("click")
			_hub_tab = tid
			ui._queue_rebuild())
		tabs.add_child(tb)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	inner.add_child(grid)
	var next_stage := 9999
	var shown := 0
	for tab in Data.HUB_TABS:
		if tab["id"] != _hub_tab:
			continue
		for id in tab["tiles"]:
			if not tiles.has(id):
				continue
			var t: Dictionary = tiles[id]
			if not t["open"]:
				if int(t.get("stage", -1)) > 0:
					next_stage = mini(next_stage, int(t["stage"]))
				continue
			shown += 1
			var fn: Callable = t["fn"]
			var b := Button.new()
			b.text = tr(t["name"]) + (" (%d)" % int(t["badge"]) if int(t["badge"]) > 0 else "")
			b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			b.icon = Art.icon(t["icon"])
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			b.add_theme_constant_override("icon_max_width", 56)
			b.add_theme_font_size_override("font_size", 19)
			b.custom_minimum_size = Vector2(0, 112)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.theme_type_variation = "GoldButton" if int(t["badge"]) > 0 else ""
			b.clip_text = true
			b.pressed.connect(func():
				Audio.play("click")
				fn.call())
			grid.add_child(b)
	if next_stage < 9999:
		_small(inner, tr("Fitur berikutnya di tab ini terbuka di Tahap %d.") % next_stage).auto_translate_mode = \
			Node.AUTO_TRANSLATE_MODE_DISABLED
	elif shown == 0:
		_small(inner, "Isi alamat server di Pengaturan untuk membuka fitur online.")


## Semua ubin Urusan Kerajaan: id -> {name, icon, open, badge, fn, stage}.
func _hub_tiles(now: float) -> Dictionary:
	var online: bool = Online.is_online()
	var has_server: bool = Settings.server_url != ""
	return {
		"hunt": {"name": "Perburuan", "icon": "hunt", "open": model.hunt_unlocked(), "stage": Data.HUNT_UNLOCK_STAGE,
			"badge": model.hunts_left(now) if model.hunt_unlocked() else 0, "fn": show_hunt},
		"market": {"name": "Pasar Malam", "icon": "market", "open": model.market_unlocked(),
			"stage": Data.MARKET_UNLOCK_STAGE, "badge": 0, "fn": show_market},
		"policy": {"name": "Kebijakan", "icon": "policy", "open": model.policy_unlocked(),
			"stage": Data.POLICY_UNLOCK_STAGE, "badge": 1 if not model.disaster_active().is_empty() else 0, "fn": show_policy},
		"garden": {"name": "Kebun", "icon": "garden", "open": model.garden_unlocked(), "stage": Data.GARDEN_UNLOCK_STAGE,
			"badge": model.garden_ready_count(now) if model.garden_unlocked() else 0, "fn": show_garden},
		"research": {"name": "Perpustakaan", "icon": "research", "open": model.research_unlocked(),
			"stage": Data.RESEARCH_UNLOCK_STAGE,
			"badge": 1 if model.research_unlocked() and model.research_job().is_empty() else 0, "fn": show_research},
		"fleet": {"name": "Armada", "icon": "ship", "open": model.fleet_unlocked(), "badge": _fleet_ready(now),
			"fn": show_fleet},
		"kin": {"name": "Besan", "icon": "ring", "open": _adult_count() > 0 or model.kin_count() > 0,
			"badge": _adult_count() + (1 if model.kin_gift_ready(now) else 0), "fn": show_kin},
		"friends": {"name": "Teman", "icon": "friends", "open": has_server,
			"badge": _friends.get("inbox", []).size() if online else 0, "fn": show_friends},
		"guildwar": {"name": "Perang Wilayah", "icon": "war_flag", "open": has_server and not model.alliance.is_empty(),
			"badge": int(_guildwar.get("attacks_left", 0)) if online else 0, "fn": show_guildwar},
		"diplomacy": {"name": "Diplomasi", "icon": "diplomacy", "open": model.diplo_unlocked(),
			"stage": Data.DIPLO_UNLOCK_STAGE,
			"badge": (model.envoys_left(now) if model.diplo_unlocked() else 0) + (1 if not model.threat().is_empty() else 0),
			"fn": show_diplomacy},
		"race": {"name": "Pacuan Kuda", "icon": "race", "open": not model.horses.is_empty(),
			"badge": model.races_left(now) if not model.horses.is_empty() else 0, "fn": show_race},
		"quiz": {"name": "Kuis Sejarah", "icon": "quiz", "open": model.stage >= 2, "stage": 2,
			"badge": model.quiz_left(now), "fn": show_quiz},
		"candi": {"name": "Candi", "icon": "candi", "open": model.candi_unlocked(), "stage": Data.CANDI_UNLOCK_STAGE,
			"badge": model.candi_free_left(now) + (1 if not model.candi_run().is_empty() else 0), "fn": show_candi},
		"forge": {"name": "Besalen", "icon": "forge", "open": model.forge_unlocked(), "stage": Data.FORGE_UNLOCK_STAGE,
			"badge": 0, "fn": show_forge},
		"pets": {"name": "Peliharaan", "icon": "pet_elang", "open": model.pet_unlocked(), "stage": Data.PET_UNLOCK_STAGE,
			"badge": 0, "fn": show_pets},
		"worldboss": {"name": "Bos Dunia", "icon": "world_boss", "open": has_server,
			"badge": int(_world_boss.get("attacks_left", 0)) if online else 0, "fn": show_world_boss},
		"tourney": {"name": "Turnamen Online", "icon": "tourney", "open": has_server,
			"badge": 1 if online and _tourney.get("phase", "") == "register" and not _tourney.get("registered", true) else 0,
			"fn": show_tourney},
		"wayang": {"name": "Wayang", "icon": "wayang", "open": model.wayang_unlocked(), "stage": Data.WAYANG_UNLOCK_STAGE,
			"badge": 1 if model.wayang_ready(now) and _wayang_left() > 0 else 0, "fn": show_wayang},
		"ceremony": {"name": "Upacara", "icon": "ceremony", "open": model.ceremony_unlocked(),
			"stage": Data.CEREMONY_UNLOCK_STAGE,
			"badge": 1 if model.ceremony_unlocked() and model.ceremony_cooldown_days(now) == 0 else 0, "fn": show_ceremony},
		"badges": {"name": "Lencana", "icon": "badge", "open": model.stage >= 3, "stage": 3, "badge": 0, "fn": show_badges},
	}


func _wayang_left() -> int:
	var n := 0
	for t in Data.FOLKTALES:
		n += t["episodes"].size() - model.wayang_progress(t["id"])
	return n


func _adult_count() -> int:
	var n := 0
	for i in model.children.size():
		if model.child_adult(i):
			n += 1
	return n


func _fleet_ready(now: float) -> int:
	var n := 0
	for ship in model.ships_owned():
		if not model.voyage(ship).is_empty() and model.voyage_eta(ship, now) <= 0:
			n += 1
	return n


func _effects_text(effects: Dictionary) -> String:
	var parts := []
	for k in effects:
		var label: String = {"yield_silver": "Perak", "yield_grain": "Pangan", "yield_soldiers": "Prajurit",
			"yield_all": "Semua hasil"}.get(k, k)
		parts.append("%s %+d%%" % [tr(label), roundi(float(effects[k]) * 100)])
	return ", ".join(parts)


func _cost_text(cost: Dictionary) -> String:
	var parts := []
	for k in cost:
		parts.append("%s %s" % [ui._num(int(cost[k])), Data.REWARD_NAMES.get(k, k)])
	return ", ".join(parts)


func _row(parent: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	return row


func _small(parent: Node, text: String, color := Color.TRANSPARENT) -> Label:
	var l: Label = ui._label(parent, text, "SmallLabel")
	l.add_theme_color_override("font_color", color if color != Color.TRANSPARENT else UI.INK)
	return l


func _side_button(row: Node, text: String, action: Callable, enabled := true, variation := "GreenButton",
		sound := "") -> Button:
	var b: Button = ui._button(row, text, action, enabled, "", variation if enabled else "", false, sound)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.custom_minimum_size.x = 150
	b.add_theme_font_size_override("font_size", 22)
	return b


# --- Perburuan ------------------------------------------------------------------------

func show_hunt() -> void:
	_show("hunt", "Perburuan", "hunt", _fill_hunt)


func _fill_hunt(box: VBoxContainer, subtitle: Label) -> void:
	var now: float = Game.now()
	subtitle.text = tr("Sisa berburu hari ini: %d / %d") % [model.hunts_left(now), Data.HUNT_PER_DAY]
	if model.counselors.is_empty():
		return
	if not model.counselors.has(_hunt_pick):
		var best := ""
		for id in model.counselors:
			if best == "" or model.hunt_score(id) > model.hunt_score(best):
				best = id
		_hunt_pick = best
	var pick_box: VBoxContainer = ui._inner_box(box)
	ui._label(pick_box, "Pilih pemburu", "CardLabel").add_theme_font_override("font", UI.font_bold)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	pick_box.add_child(flow)
	var ids: Array = model.counselors.keys()
	ids.sort_custom(func(a, b): return model.hunt_score(a) > model.hunt_score(b))
	for id in ids.slice(0, 8):
		var b := Button.new()
		b.icon = Art.portrait(id)
		b.add_theme_constant_override("icon_max_width", 64)
		b.text = str(model.hunt_score(id))
		b.custom_minimum_size = Vector2(150, 80)
		b.theme_type_variation = "GoldButton" if id == _hunt_pick else ""
		b.add_theme_font_size_override("font_size", 20)
		var cid: String = id
		b.pressed.connect(func():
			_hunt_pick = cid
			Audio.play("click")
			_fill("hunt"))
		flow.add_child(b)
	_small(pick_box, "%s · Skor buruan %d (Kekuatan + separuh Karisma)" % [
		Data.counselor_def(_hunt_pick)["name"], model.hunt_score(_hunt_pick)])
	for g in Data.HUNT_GROUNDS:
		var card: HBoxContainer = ui._card(box)
		card.add_child(ui._tex(Art.icon(g["icon"]), 84))
		var col: VBoxContainer = ui._col(card)
		ui._label(col, g["name"], "CardTitle")
		var chance: float = model.hunt_chance(_hunt_pick, g["id"])
		ui._label(col, "Buruan: %s · Peluang %d%%" % [g["animal"], roundi(chance * 100)], "CardLabel")
		var reward: Dictionary = model.hunt_rewards(g["id"])
		var text: String = ui._reward_text(reward)
		if str(g["drop"]) != "":
			text += ", " + tr("peluang %s") % tr(Data.ITEMS[g["drop"]]["name"])
		_small(col, text)
		var gid: String = g["id"]
		_side_button(card, "Berburu", func(): return _go_hunt(gid), model.hunts_left(now) > 0, "GreenButton")


func _go_hunt(ground: String):
	var r: Dictionary = model.go_hunt(_hunt_pick, ground, Game.now())
	if not r["ok"]:
		return r
	var view := HuntView.new()
	view.setup(r["plan"], {"title": model.hunt_ground(ground)["name"], "portrait": _hunt_pick, "win": r["win"],
		"detail": r["msg"]})
	ui.add_child(view)
	ui.move_child(view, ui._toast.get_index())
	view.finished.connect(ui._queue_rebuild)
	return null


# --- Pasar Malam ----------------------------------------------------------------------

func show_market() -> void:
	_show("market", "Pasar Malam", "market", _fill_market)


func _fill_market(box: VBoxContainer, subtitle: Label) -> void:
	var now: float = Game.now()
	var set_timer := func():
		subtitle.text = tr("Dagangan berganti dalam %s") % ui._duration(model.market_seconds_left(Game.now()))
	set_timer.call()
	_panels["market"]["timer"] = set_timer
	var slots: Array = model.market_slots(now)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	for i in slots.size():
		var sl: Dictionary = slots[i]
		var def: Dictionary = Data.MARKET_POOL[int(sl["pool"])]
		var item: Dictionary = Data.ITEMS[def["item"]]
		var cell: VBoxContainer = ui._inner_box(grid)
		cell.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var head := _row(cell)
		head.add_child(ui._tex(Art.icon(item["icon"]), 56))
		var name_l: Label = ui._label(ui._col(head), item["name"], "CardLabel")
		name_l.add_theme_font_override("font", UI.font_bold)
		var price := "%s %s" % [ui._num(int(sl["price"])), tr(Data.MARKET_CUR_NAMES[def["cur"]])]
		var price_l: Label = _small(cell, price + (tr(" (sudah ditawar)") if sl["haggled"] else ""))
		price_l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		var row := _row(cell)
		var idx: int = i
		if sl["bought"]:
			_small(cell, "Terjual", UI.GREEN.darkened(0.2))
			continue
		var buy: Button = ui._button(row, "Beli", func(): return model.market_buy(idx, Game.now()),
			model._currency_have(def["cur"]) >= int(sl["price"]), "", "GoldButton", false, "coin")
		buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buy.add_theme_font_size_override("font_size", 22)
		var haggle: Button = ui._button(row, "Tawar", func(): return model.market_haggle(idx, Game.now()),
			not sl["haggled"], "", "GreenButton" if not sl["haggled"] else "")
		haggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		haggle.add_theme_font_size_override("font_size", 22)
	var left: int = model.market_refreshes_left(now)
	var refresh: Button = ui._button(box, tr("Ganti Dagangan · %d emas (sisa %d)") % [Data.MARKET_REFRESH_GOLD, left],
		func(): return model.refresh_market(Game.now()), left > 0 and model.gold >= Data.MARKET_REFRESH_GOLD, "gold", "")
	refresh.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED


# --- Kebijakan & bencana -------------------------------------------------------------

func show_policy() -> void:
	_show("policy", "Kebijakan & Bencana", "policy", _fill_policy)


func _fill_policy(box: VBoxContainer, subtitle: Label) -> void:
	var now: float = Game.now()
	model.ensure_disaster(now)
	var loyalty: int = int(model.court.get("loyalty", 50))
	subtitle.text = tr("Kesetiaan rakyat %d/100 · bonus hasil %+d%%") % [loyalty, roundi(model.loyalty_bonus() * 100)]
	var d: Dictionary = model.disaster_active()
	var dbox: VBoxContainer = ui._inner_box(box)
	if d.is_empty():
		var calm := _row(dbox)
		calm.add_child(ui._tex(Art.icon("check"), 48))
		ui._label(ui._col(calm), "Negeri aman. Belum ada bencana di periode ini.", "CardLabel")
	else:
		var head := _row(dbox)
		head.add_child(ui._tex(Art.icon("disaster"), 72))
		var col: VBoxContainer = ui._col(head)
		var t: Label = ui._label(col, d["name"], "CardTitle")
		t.add_theme_color_override("font_color", UI.RED)
		ui._label(col, d["desc"], "CardLabel")
		_small(col, _effects_text(d["effects"]) + " · " + tr("berakhir dalam %s") % ui._duration(model.disaster_seconds_left(now)))
		for i in d["options"].size():
			var o: Dictionary = d["options"][i]
			var cost: Dictionary = model.disaster_option_cost(o)
			var row := _row(dbox)
			var oc: VBoxContainer = ui._col(row)
			ui._label(oc, o["text"], "CardLabel").add_theme_font_override("font", UI.font_bold)
			var info := []
			if not cost.is_empty():
				info.append(tr("Biaya: %s") % _cost_text(cost))
			if int(o.get("loyalty", 0)) != 0:
				info.append(tr("kesetiaan %+d") % int(o["loyalty"]))
			if int(o.get("prestige", 0)) > 0:
				info.append(tr("+%d prestise") % int(o["prestige"]))
			var il := _small(oc, ", ".join(info))
			il.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			var afford := true
			for k in cost:
				afford = afford and int(model.get(k)) >= int(cost[k])
			var idx: int = i
			_side_button(row, "Pilih", func(): return model.resolve_disaster(idx, Game.now()), afford, "GoldButton")
	ui._label(box, "Kebijakan Kota", "CardTitle")
	var cd: int = model.policy_cooldown(now)
	if cd > 0:
		_small(box, tr("Kebijakan bisa diganti lagi dalam %s.") % ui._duration(cd))
	for id in Data.POLICY_ORDER:
		var p: Dictionary = Data.POLICIES[id]
		var card: HBoxContainer = ui._card(box)
		var col: VBoxContainer = ui._col(card)
		ui._label(col, p["name"], "CardLabel").add_theme_font_override("font", UI.font_bold)
		_small(col, p["desc"])
		var active: bool = model.realm["policy"] == id
		var pid: String = id
		var b := _side_button(card, "Berlaku" if active else "Terapkan", func(): return model.set_policy(pid, Game.now()),
			not active and cd == 0, "GreenButton")
		if active:
			b.theme_type_variation = "GoldButton"


# --- Kebun Keraton --------------------------------------------------------------------

func show_garden() -> void:
	_show("garden", "Kebun Keraton", "garden", _fill_garden)


func _fill_garden(box: VBoxContainer, subtitle: Label) -> void:
	var now: float = Game.now()
	subtitle.text = "Tanam bibit, panen setelah matang."
	var seeds: VBoxContainer = ui._inner_box(box)
	ui._label(seeds, "Pilih bibit", "CardLabel").add_theme_font_override("font", UI.font_bold)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	seeds.add_child(flow)
	for id in Data.PLANT_ORDER:
		var p: Dictionary = Data.PLANTS[id]
		var b := Button.new()
		b.icon = Art.icon(p["icon"])
		b.add_theme_constant_override("icon_max_width", 44)
		b.text = p["name"]
		b.add_theme_font_size_override("font_size", 19)
		b.custom_minimum_size = Vector2(0, 64)
		b.theme_type_variation = "GoldButton" if id == _garden_seed else ""
		var pid: String = id
		b.pressed.connect(func():
			_garden_seed = pid
			Audio.play("click")
			_fill("garden"))
		flow.add_child(b)
	var sel: Dictionary = Data.PLANTS[_garden_seed]
	var info := _small(seeds, tr("%s: bibit %s perak · %d jam · hasil %s") % [tr(sel["name"]),
		ui._num(model.plant_seed_cost(_garden_seed)), sel["hours"], tr(ui._reward_text(model.plant_reward(_garden_seed)))])
	info.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	var timers := []
	for i in model.realm["garden"].size():
		var pl: Dictionary = model.realm["garden"][i]
		var cell: VBoxContainer = ui._inner_box(grid)
		cell.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		var idx: int = i
		if pl.is_empty():
			ui._label(cell, tr("Petak %d · kosong") % (i + 1), "CardLabel")
			var b: Button = ui._button(cell, tr("Tanam %s") % tr(sel["name"]), func():
				return model.plant_seed(idx, _garden_seed, Game.now()), model.silver >= model.plant_seed_cost(_garden_seed),
				sel["icon"], "GreenButton", false, "upgrade")
			b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			b.add_theme_font_size_override("font_size", 21)
			continue
		var p: Dictionary = Data.PLANTS[pl["plant"]]
		var head := _row(cell)
		head.add_child(ui._tex(Art.icon(p["icon"]), 56))
		ui._label(ui._col(head), p["name"], "CardLabel").add_theme_font_override("font", UI.font_bold)
		var total := float(p["hours"]) * 3600.0
		var bar: ProgressBar = ui._bar(cell, total - model.plot_eta(i, now), total, UI.GREEN)
		var l := _small(cell, "")
		timers.append({"bar": bar, "label": l, "index": i, "total": total})
	var update := func():
		for t in timers:
			if not is_instance_valid(t["label"]):
				return
			var eta: int = model.plot_eta(t["index"], Game.now())
			t["bar"].value = t["total"] - eta
			t["label"].text = tr("Siap panen!") if eta <= 0 else tr("Matang dalam %s") % ui._duration(eta)
	update.call()
	_panels["garden"]["timer"] = update
	ui._button(box, "Panen Semua", func(): return model.harvest_all(Game.now()), model.garden_ready_count(now) > 0,
		"garden", "GoldButton", false, "reveal_sr")


# --- Perpustakaan Keraton ---------------------------------------------------------------

func show_research() -> void:
	_show("research", "Perpustakaan Keraton", "research", _fill_research)


func _fill_research(box: VBoxContainer, subtitle: Label) -> void:
	var now: float = Game.now()
	subtitle.text = tr("Total level riset: %d") % model.research_total()
	var job: Dictionary = model.research_job()
	if not job.is_empty():
		var jb: VBoxContainer = ui._inner_box(box)
		var r: Dictionary = Data.RESEARCH[job["id"]]
		ui._label(jb, tr("Meneliti %s ke level %d") % [tr(r["name"]), model.research_level(job["id"]) + 1],
			"CardLabel").add_theme_font_override("font", UI.font_bold)
		var total := float(model.research_seconds(job["id"]))
		var bar: ProgressBar = ui._bar(jb, total - model.research_eta(now), total, Color("6fa8dc"))
		var row := _row(jb)
		var l := _small(row, "")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var rush: Button = ui._button(row, "", func(): return model.rush_research(Game.now()), true, "gold", "GoldButton")
		rush.add_theme_font_size_override("font_size", 22)
		rush.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		var update := func():
			if not is_instance_valid(l):
				return
			var eta: int = model.research_eta(Game.now())
			bar.value = total - eta
			l.text = tr("Selesai dalam %s") % ui._duration(eta)
			rush.text = tr("Percepat · %d emas") % model.research_rush_cost(Game.now())
			if eta <= 0:
				ui._queue_rebuild()
		update.call()
		_panels["research"]["timer"] = update
	for id in Data.RESEARCH_ORDER:
		var r: Dictionary = Data.RESEARCH[id]
		var lv: int = model.research_level(id)
		var card: HBoxContainer = ui._card(box)
		card.add_child(ui._tex(Art.icon(r["icon"]), 72))
		var col: VBoxContainer = ui._col(card)
		ui._label(col, tr("%s · Lv %d/%d") % [tr(r["name"]), lv, Data.RESEARCH_MAX_LEVEL], "CardLabel") \
			.add_theme_font_override("font", UI.font_bold)
		_small(col, r["desc"])
		var rid: String = id
		if lv >= Data.RESEARCH_MAX_LEVEL:
			_small(col, "Tuntas", UI.GREEN.darkened(0.2))
			continue
		if not model.research_req_ok(id):
			var req := []
			for k in r["req"]:
				req.append("%s Lv %d" % [tr(Data.RESEARCH[k]["name"]), int(r["req"][k])])
			var rl := _small(col, tr("Butuh: %s") % ", ".join(req), UI.RED)
			rl.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			continue
		var cl := _small(col, tr("%s perak · %s") % [ui._num(model.research_cost(id)), ui._duration(model.research_seconds(id))])
		cl.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_side_button(card, "Teliti", func(): return model.start_research(rid, Game.now()),
			job.is_empty() and model.silver >= model.research_cost(id), "GreenButton", "upgrade")


# --- Armada Laut ---------------------------------------------------------------------

func show_fleet() -> void:
	_show("fleet", "Armada Laut", "ship", _fill_fleet)


func _fill_fleet(box: VBoxContainer, subtitle: Label) -> void:
	var now: float = Game.now()
	var routes: Array = model.fleet_routes()
	subtitle.text = tr("%d kapal · %d rute dagang") % [model.ships_owned().size(), routes.size()]
	var timers := []
	for id in Data.SHIP_ORDER:
		var s: Dictionary = Data.SHIPS[id]
		var owned: bool = model.ships_owned().has(id)
		var card: HBoxContainer = ui._card(box)
		card.add_child(ui._tex(Art.icon(s["icon"]), 84))
		var col: VBoxContainer = ui._col(card)
		ui._label(col, s["name"], "CardTitle")
		var stats := _small(col, tr("Muatan x%.1f · Penjaga %.1f · %d jam · risiko bajak laut %d%%") % [
			float(s["cargo"]) * float(s["hours"]), float(s["guard"]), s["hours"], roundi(model.pirate_chance(id) * 100)])
		stats.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		var sid: String = id
		if not owned:
			var cost: Dictionary = s["cost"]
			var afford := true
			for k in cost:
				afford = afford and int(model.get(k)) >= int(cost[k])
			_small(col, tr("Harga: %s") % _cost_text(cost)).auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			_side_button(card, "Beli", func(): return model.buy_ship(sid), afford, "GoldButton", "upgrade")
			continue
		var v: Dictionary = model.voyage(id)
		if not v.is_empty():
			var hours := float(s["hours"]) * 3600.0
			ui._label(col, tr("Berlayar ke %s · muatan %s perak") % [tr(model.region_def(v["region"])["name"]),
				ui._num(int(v["cargo"]))], "CardLabel").auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			var bar: ProgressBar = ui._bar(col, hours - model.voyage_eta(id, now), hours, Color("2e86c1"))
			var l := _small(col, "")
			timers.append({"bar": bar, "label": l, "ship": id, "total": hours})
			_side_button(card, "Bongkar", func(): return _claim_voyage(sid), model.voyage_eta(id, now) <= 0, "GoldButton")
			continue
		if routes.is_empty():
			_small(col, "Kuasai wilayah lain di Peta Nusantara untuk membuka rute dagang.")
			continue
		var pick: int = clampi(int(_ship_route.get(id, routes.size() - 1)), 0, routes.size() - 1)
		var region: String = routes[pick]
		var rb: Button = ui._button(col, tr("Tujuan: %s · %s perak ▸") % [tr(model.region_def(region)["name"]),
			ui._num(model.voyage_cargo(id, region))], func():
				_ship_route[sid] = (pick + 1) % routes.size()
				_fill("fleet")
				return null, true, "map", "")
		rb.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		rb.add_theme_font_size_override("font_size", 19)
		rb.clip_text = true
		rb.custom_minimum_size.x = 0
		_side_button(card, "Berlayar", func(): return model.send_ship(sid, region, Game.now()), true, "GreenButton")
	var update := func():
		for t in timers:
			if not is_instance_valid(t["label"]):
				return
			var eta: int = model.voyage_eta(t["ship"], Game.now())
			t["bar"].value = t["total"] - eta
			t["label"].text = tr("Kapal sudah berlabuh!") if eta <= 0 else tr("Tiba dalam %s") % ui._duration(eta)
	update.call()
	_panels["fleet"]["timer"] = update


func _claim_voyage(ship: String):
	var r: Dictionary = model.claim_voyage(ship, Game.now())
	if not r["ok"] or not r["pirates"]:
		return r
	ui._play_battle(r["plan"], {"title": "Serangan Bajak Laut", "me_name": Data.SHIPS[ship]["name"],
		"them_name": "Bajak Laut", "me_count": 300, "them_count": 260, "me_portrait": model.lord_portrait(),
		"them_portrait": "enemy_pirate", "win": r["win"], "detail": r["msg"], "bg": "sea",
		"headline": "BAJAK LAUT KALAH!" if r["win"] else "MUATAN DIRAMPAS..."})
	return null


# --- Besan & pernikahan antar-kerajaan --------------------------------------------------

func show_kin() -> void:
	_show("kin", "Pernikahan Antar-Kerajaan", "ring", _fill_kin)


func show_marriage(index: int) -> void:
	close("marry")
	_show("marry", "Pernikahan Antar-Kerajaan", "ring", func(box, subtitle): _fill_marriage(box, subtitle, index))


func _fill_kin(box: VBoxContainer, subtitle: Label) -> void:
	var now: float = Game.now()
	subtitle.text = tr("%d keluarga besan") % model.kin_count()
	var gift: VBoxContainer = ui._inner_box(box)
	ui._label(gift, tr("Kiriman harian besan: %s perak") % ui._num(model.kin_gift_amount()), "CardLabel") \
		.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	ui._button(gift, "Terima Kiriman", func(): return model.claim_kin_gifts(Game.now()), model.kin_gift_ready(now),
		"silver", "GoldButton", false, "coin")
	ui._label(box, "Anak yang siap menikah", "CardTitle")
	var any := false
	for i in model.children.size():
		if not model.child_adult(i):
			continue
		any = true
		var c: Dictionary = model.children[i]
		var card: HBoxContainer = ui._card(box)
		var col: VBoxContainer = ui._col(card)
		ui._label(col, c["name"], "CardLabel").add_theme_font_override("font", UI.font_bold)
		_small(col, tr("Bakat %d/5") % int(c["talent"]))
		var idx: int = i
		_side_button(card, "Cari Jodoh", func():
			show_marriage(idx)
			return null, true, "GoldButton")
	if not any:
		_small(box, "Belum ada anak dewasa. Didik anak di Istana sampai level %d." % Data.CHILD_MAX_LEVEL)
	if model.kin_count() > 0:
		ui._label(box, "Keluarga Besan", "CardTitle")
		for k in model.realm["kin"]:
			var house := ""
			for h in Data.NOBLE_HOUSES:
				if h["id"] == k["house"]:
					house = h["name"]
			var l := _small(box, "%s — %s (%s)" % [k["child"], k["name"], tr(house)])
			l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED


func _fill_marriage(box: VBoxContainer, subtitle: Label, index: int) -> void:
	if not model.child_adult(index):
		ui._label(box, "Anak ini sudah menikah atau belum dewasa.", "CardLabel")
		return
	var c: Dictionary = model.children[index]
	subtitle.text = tr("Lamaran untuk %s (bakat %d/5)") % [c["name"], int(c["talent"])]
	subtitle.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_small(box, "Calon berganti setiap hari. Bonus atribut diberikan kepada penasihat terkuat di atribut itu.")
	var cands: Array = model.marriage_candidates(index, Game.now())
	for i in cands.size():
		var cand: Dictionary = cands[i]
		var card: HBoxContainer = ui._card(box)
		card.add_child(ui._tex(Art.icon("ring"), 72))
		var col: VBoxContainer = ui._col(card)
		var nl: Label = ui._label(col, "%s · %s" % [cand["name"], tr(cand["house_name"])], "CardLabel")
		nl.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		nl.add_theme_font_override("font", UI.font_bold)
		var info := _small(col, tr("Bakat %d/5 · +%d %s · mahar %s perak") % [cand["talent"], cand["bonus"],
			tr(Data.ATTR_NAMES[cand["attr"]]), ui._num(cand["dowry"])])
		info.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		var ci: int = i
		_side_button(card, "Lamar", func():
			var r: Dictionary = model.marry_noble(index, ci, Game.now())
			if r["ok"]:
				close("marry")
			return r, model.silver >= int(cand["dowry"]), "GoldButton", "birth")


# --- Online: Teman ---------------------------------------------------------------------

func _need_online() -> bool:
	if Online.is_online():
		return false
	ui._show({"ok": false, "msg": "Fitur ini butuh server. Isi alamat server di Pengaturan."})
	return true


func show_friends() -> void:
	if _need_online():
		return
	_show("friends", "Teman", "friends", _fill_friends)
	_load_friends()


func _load_friends() -> void:
	Online.fetch_friends(func(data: Dictionary):
		_friends = data
		if is_open("friends"):
			_fill("friends"))


func _fill_friends(box: VBoxContainer, subtitle: Label) -> void:
	if _friends.is_empty():
		subtitle.text = "Memuat..."
		return
	var friends: Array = _friends.get("friends", [])
	subtitle.text = tr("Kode Tuan: %s · %d teman") % [_friends.get("code", "-"), friends.size()]
	subtitle.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var add: VBoxContainer = ui._inner_box(box)
	ui._label(add, "Tambah teman dengan kode", "CardLabel").add_theme_font_override("font", UI.font_bold)
	var row := _row(add)
	_friend_code_edit = LineEdit.new()
	_friend_code_edit.placeholder_text = tr("Kode 8 karakter")
	_friend_code_edit.max_length = 8
	_friend_code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_friend_code_edit.custom_minimum_size.y = 64
	row.add_child(_friend_code_edit)
	_side_button(row, "Tambah", func():
		Online.add_friend(_friend_code_edit.text, func(ok: bool, msg: String):
			ui._show({"ok": ok, "msg": (tr("%s kini teman Tuan.") % msg) if ok else msg})
			if ok:
				_load_friends())
		return null, true, "GreenButton")
	var copy: Button = ui._button(add, "Salin Kode Saya", func():
		DisplayServer.clipboard_set(str(_friends.get("code", "")))
		return {"ok": true, "msg": "Kode disalin. Bagikan ke teman Tuan."}, true, "", "")
	copy.add_theme_font_size_override("font_size", 22)
	var inbox: Array = _friends.get("inbox", [])
	var claim: Button = ui._button(box, tr("Terima Hadiah Teman (%d)") % inbox.size(), func():
		Online.claim_gifts(func(r: Dictionary):
			ui._show(r)
			_load_friends())
		return null, not inbox.is_empty(), "gift", "GoldButton", false, "coin")
	claim.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	for f in friends:
		var card: HBoxContainer = ui._card(box)
		card.add_child(ui._tex(Art.portrait(str(f.get("portrait", "lord"))), 72))
		var col: VBoxContainer = ui._col(card)
		var nl: Label = ui._label(col, str(f.get("name", "")), "CardLabel")
		nl.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		nl.add_theme_font_override("font", UI.font_bold)
		_small(col, tr("Kekuatan %s · Tahap %d") % [ui._num(int(f.get("power", 0))), int(f.get("stage", 0))]) \
			.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		var btns := VBoxContainer.new()
		card.add_child(btns)
		var fid := str(f.get("id", ""))
		var sent := bool(f.get("gift_sent", false))
		var g: Button = ui._button(btns, "Terkirim" if sent else "Kirim Hadiah", func():
			Online.send_gift(fid, func(ok: bool, msg: String):
				ui._show({"ok": ok, "msg": "Hadiah terkirim." if ok else msg})
				_load_friends())
			return null, not sent, "gift", "GreenButton")
		g.add_theme_font_size_override("font_size", 19)
		var visit: Button = ui._button(btns, "Kunjungi", func():
			show_visit(fid)
			return null, true, "", "GoldButton")
		visit.add_theme_font_size_override("font_size", 19)


func show_visit(player_id: String) -> void:
	close("visit")
	var state := {"data": {}}
	_show("visit", "Kunjungan Kota", "tab_city", func(box, subtitle): _fill_visit(box, subtitle, state))
	Online.visit_player(player_id, func(data: Dictionary):
		state["data"] = data if not data.is_empty() else {"error": true}
		if is_open("visit"):
			_fill("visit"))


func _fill_visit(box: VBoxContainer, subtitle: Label, state: Dictionary) -> void:
	var data: Dictionary = state["data"]
	if data.is_empty():
		subtitle.text = "Memuat..."
		return
	if data.has("error"):
		subtitle.text = "Pemain tidak ditemukan."
		return
	var p: Dictionary = data["player"]
	var city: Dictionary = data.get("city", {})
	subtitle.text = str(p.get("name", ""))
	subtitle.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var head: HBoxContainer = ui._card(box)
	head.add_child(ui._tex(Art.portrait(str(p.get("portrait", "lord"))), 110))
	var col: VBoxContainer = ui._col(head)
	var rank_i: int = clampi(int(city.get("rank", 0)), 0, Data.RANKS.size() - 1)
	ui._label(col, Data.RANKS[rank_i]["name"], "CardTitle")
	var stats := [
		tr("Kekuatan %s") % ui._num(int(p.get("power", 0))),
		tr("Tahap kampanye %d") % int(p.get("stage", 0)),
		tr("Prestise %s") % ui._num(int(p.get("prestige", 0))),
		tr("Penasihat %d · Wilayah %d") % [int(city.get("counselors", 0)), int(city.get("regions", 0))],
		tr("Kapal %d · Besan %d") % [int(city.get("ships", 0)), int(city.get("kin", 0))],
	]
	for s in stats:
		_small(col, s).auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var badges: Array = city.get("badges", [])
	if not badges.is_empty():
		ui._label(box, tr("Lencana (%d)") % badges.size(), "CardTitle").auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 6)
		box.add_child(flow)
		for id in badges:
			var d: Dictionary = model.badge_def(str(id))
			if not d.is_empty():
				flow.add_child(ui._tex(Art.icon(d["icon"]), 52))
	ui._label(box, "Bangunan Kota", "CardTitle")
	var grid := GridContainer.new()
	grid.columns = 2
	box.add_child(grid)
	var levels: Dictionary = city.get("buildings", {})
	for id in Data.BUILDING_ORDER:
		var lv := int(levels.get(id, 0))
		var tier: int = Data.building_tier(lv)
		var cell: VBoxContainer = ui._inner_box(grid)
		cell.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_child(ui._tex(Art.building("%s_%d" % [id, tier]) if tier > 0 else Art.building("plot"), 96))
		var l: Label = ui._label(cell, "%s · Lv %d" % [tr(Data.BUILDINGS[id]["name"]), lv], "CardLabel")
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


# --- Online: Perang Wilayah -------------------------------------------------------------

func show_guildwar() -> void:
	if _need_online():
		return
	_show("guildwar", "Perang Wilayah", "war_flag", _fill_guildwar)
	_load_guildwar()


func _load_guildwar() -> void:
	Online.fetch_guildwar(func(data: Dictionary):
		_guildwar = data
		if is_open("guildwar"):
			_fill("guildwar"))


func _alliance_name(id) -> String:
	if id == null or str(id) == "":
		return tr("Belum dikuasai")
	var a: Dictionary = Data.alliance_def(str(id))
	return tr(a["name"]) if not a.is_empty() else str(id)


func _fill_guildwar(box: VBoxContainer, subtitle: Label) -> void:
	if _guildwar.is_empty():
		subtitle.text = "Memuat..."
		return
	var mine = _guildwar.get("alliance")
	subtitle.text = tr("Aliansi Tuan: %s · serangan tersisa %d · berakhir dalam %s") % [_alliance_name(mine),
		int(_guildwar.get("attacks_left", 0)), ui._duration(int(float(_guildwar.get("ends_in", 0)) / 1000.0))]
	subtitle.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var won := int(_guildwar.get("last_won", 0))
	var last_week := int(_guildwar.get("last_week", -1))
	if won > 0 and int(model.realm["guildwar_claimed"]) < last_week:
		var rb: VBoxContainer = ui._inner_box(box)
		ui._label(rb, tr("Minggu lalu aliansi Tuan menguasai %d wilayah!") % won, "CardLabel") \
			.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		ui._button(rb, "Ambil Hadiah Perang", func(): return model.claim_guildwar(last_week, won), true, "chest",
			"GoldButton", false, "reveal_ssr")
	if mine == null or str(mine) == "":
		_small(box, "Bergabunglah dengan aliansi untuk ikut berperang.", UI.RED)
	for t in _guildwar.get("territories", []):
		var card: HBoxContainer = ui._card(box)
		card.add_child(ui._tex(Art.icon("war_flag"), 64))
		var col: VBoxContainer = ui._col(card)
		var nl: Label = ui._label(col, str(t.get("name", "")), "CardLabel")
		nl.add_theme_font_override("font", UI.font_bold)
		var owner = t.get("owner")
		var ol := _small(col, tr("Penguasa: %s") % _alliance_name(owner),
			UI.GREEN.darkened(0.2) if owner != null and owner == mine else UI.INK)
		ol.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		var pts := []
		var points: Dictionary = t.get("points", {})
		for a in points:
			pts.append("%s %s" % [_alliance_name(a), ui._num(int(points[a]))])
		if not pts.is_empty():
			_small(col, ", ".join(pts)).auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		var tid := int(t.get("id", 0))
		_side_button(card, "Serang", func():
			Online.guildwar_attack(tid, func(r: Dictionary):
				if r.has("error"):
					ui._show({"ok": false, "msg": r["error"]})
				else:
					ui._show({"ok": true, "msg": tr("Serangan berhasil: +%d poin untuk aliansi.") % int(r["points"])})
				_load_guildwar())
			return null, int(_guildwar.get("attacks_left", 0)) > 0 and mine != null, "GreenButton", "attack")


# --- Online: Raja Hari Ini -----------------------------------------------------------------

func show_king() -> void:
	if _need_online():
		return
	_show("king", "Raja Hari Ini", "crown", _fill_king)
	Online.poll_king()


func _fill_king(box: VBoxContainer, subtitle: Label) -> void:
	if Online.king.is_empty():
		subtitle.text = "Belum ada raja hari ini."
		return
	var k: Dictionary = Online.king["king"]
	subtitle.text = "Pemain terkuat di server hari ini"
	var card: HBoxContainer = ui._card(box)
	card.add_child(ui._tex(Art.portrait(str(k.get("portrait", "lord"))), 120))
	var col: VBoxContainer = ui._col(card)
	var nl: Label = ui._label(col, str(k.get("name", "")), "CardTitle")
	nl.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_small(col, tr("Kekuatan %s") % ui._num(int(k.get("power", 0)))).auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var decree := str(Online.king.get("decree", "")) if Online.king.get("decree") != null else ""
	if Data.KING_DECREES.has(decree):
		var d: Dictionary = Data.KING_DECREES[decree]
		var db: VBoxContainer = ui._inner_box(box)
		ui._label(db, d["name"], "CardLabel").add_theme_font_override("font", UI.font_bold)
		_small(db, d["desc"])
	elif bool(Online.king.get("me", false)):
		ui._label(box, "Tuan adalah Raja Hari Ini! Pilih satu titah untuk semua pemain:", "CardLabel")
		for id in Data.KING_DECREES:
			var d: Dictionary = Data.KING_DECREES[id]
			var row: HBoxContainer = ui._card(box)
			var dc: VBoxContainer = ui._col(row)
			ui._label(dc, d["name"], "CardLabel").add_theme_font_override("font", UI.font_bold)
			_small(dc, d["desc"])
			var did: String = id
			_side_button(row, "Titahkan", func():
				Online.set_decree(did, func(ok: bool, msg: String):
					ui._show({"ok": ok, "msg": "Titah diumumkan ke seluruh negeri!" if ok else msg})
					if is_open("king"):
						_fill("king"))
				return null, true, "GoldButton", "promote")
	else:
		_small(box, "Raja belum bertitah hari ini.")



# --- Kota: pemain kembali, pemberontakan, ancaman ----------------------------------------

func _comeback_card(box: VBoxContainer) -> void:
	var now: float = Game.now()
	if not model.comeback_active(now):
		return
	var inner: VBoxContainer = ui._col(ui._card(box))
	var head := _row(inner)
	head.add_child(ui._tex(Art.icon("comeback"), 64))
	var hc: VBoxContainer = ui._col(head)
	ui._label(hc, "Semangat Kembali", "CardTitle")
	_small(hc, tr("Semua hasil +30%% · berakhir dalam %s") % ui._duration(
		int(float(model.realm["comeback"]["until"]) - now))).auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	if not model.realm["comeback"]["pack"]:
		ui._button(inner, "Ambil Paket Bantuan", func(): return model.claim_comeback_pack(Game.now()), true, "gift",
			"GoldButton", false, "reveal_sr")
	for i in Data.COMEBACK_MISSIONS.size():
		var m: Dictionary = Data.COMEBACK_MISSIONS[i]
		var row := _row(inner)
		var col: VBoxContainer = ui._col(row)
		var prog: int = model.comeback_progress(i)
		ui._label(col, tr(m["text"]) + " (%d/%d)" % [prog, m["target"]], "CardLabel").auto_translate_mode = \
			Node.AUTO_TRANSLATE_MODE_DISABLED
		_small(col, ui._reward_text(m["reward"]))
		var done: bool = model.realm["comeback"]["done"].has(i)
		var idx: int = i
		_side_button(row, "Diambil" if done else "Klaim", func(): return model.claim_comeback_mission(idx, Game.now()),
			not done and prog >= int(m["target"]), "GreenButton", "coin")


func _rebellion_banner(box: VBoxContainer) -> void:
	var rb: Dictionary = model.rebellion()
	if rb.is_empty():
		return
	var card: HBoxContainer = ui._card(box)
	card.add_child(ui._tex(Art.icon("rebel"), 80))
	var col: VBoxContainer = ui._col(card)
	var t: Label = ui._label(col, "Pemberontakan!", "CardTitle")
	t.add_theme_color_override("font_color", UI.RED)
	ui._label(col, "Rakyat yang kecewa angkat senjata. Semua hasil -20%, sampai pemberontakan berakhir.", "CardLabel")
	var row := _row(col)
	var need := int(rb["soldiers"])
	var crush: Button = ui._button(row, tr("Tumpas · %s prajurit") % ui._num(need), func():
		var r: Dictionary = model.end_rebellion(true)
		if r["ok"]:
			ui._play_battle(r["plan"], {"title": tr("Menumpas Pemberontakan"), "me_name": model.me_name(),
				"them_name": tr("Pemberontak"), "me_count": model.soldiers + need, "them_count": need,
				"me_portrait": model.lord_portrait(), "them_portrait": "enemy_rebel", "win": true, "detail": r["msg"],
				"bg": "city", "me_mix": model.army_mix()})
			return null
		return r, model.soldiers >= need, "", "")
	crush.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	crush.add_theme_font_size_override("font_size", 20)
	crush.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cost := int(model.affair_yield("grain") * 3)
	var talk: Button = ui._button(row, tr("Bujuk · %s pangan") % ui._num(cost), func(): return model.end_rebellion(false),
		model.grain >= cost, "", "GreenButton")
	talk.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	talk.add_theme_font_size_override("font_size", 20)
	talk.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _threat_banner(box: VBoxContainer) -> void:
	var th: Dictionary = model.threat()
	if th.is_empty():
		return
	var k: Dictionary = model.kingdom_def(th["kingdom"])
	var card: HBoxContainer = ui._card(box)
	card.add_child(ui._tex(Art.icon(k["icon"]), 80))
	var col: VBoxContainer = ui._col(card)
	var t: Label = ui._label(col, tr("Serangan %s!") % tr(k["name"]), "CardTitle")
	t.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	t.add_theme_color_override("font_color", UI.RED)
	ui._label(col, "Pasukan musuh di perbatasan. Bila dibiarkan sampai besok, mereka menjarah perak.", "CardLabel")
	var row := _row(col)
	var fight: Button = ui._button(row, "Hadapi", func(): return _answer_threat(false), true, "", "")
	fight.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pay: Button = ui._button(row, "Bayar Damai", func(): return _answer_threat(true), true, "", "GreenButton")
	pay.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _answer_threat(pay: bool):
	var th: Dictionary = model.threat()
	var name: String = model.kingdom_def(th.get("kingdom", "banten"))["name"]
	var r: Dictionary = model.answer_threat(pay, Game.now())
	if not r.has("plan"):
		return r
	ui._play_battle(r["plan"], {"title": tr("Serangan %s") % tr(name), "me_name": model.me_name(), "them_name": tr(name),
		"me_count": model.soldiers, "them_count": int(model.affair_yield("soldiers") * 2), "me_portrait": model.lord_portrait(),
		"them_portrait": "enemy_warlord", "win": r["win"], "detail": r["msg"], "bg": "campaign", "me_mix": model.army_mix()})
	return null


# --- Kampanye: susunan pasukan -------------------------------------------------------------

func build_army(box: VBoxContainer) -> void:
	var inner: VBoxContainer = ui._col(ui._card(box))
	ui._label(inner, "Susunan Pasukan", "CardTitle")
	var enemy: Array = model.enemy_mix(model.stage)
	var main := 0
	for i in 3:
		if float(enemy[i]) > float(enemy[main]):
			main = i
	var er := _row(inner)
	er.add_child(ui._tex(Art.icon("troop_" + Data.TROOP_TYPES[main]), 44))
	var el := _small(ui._col(er), tr("Musuh mengandalkan %s. Tombak unggul atas berkuda, berkuda atas panah, panah atas tombak.")
		% tr(Data.TROOP_NAMES[Data.TROOP_TYPES[main]]))
	el.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	inner.add_child(grid)
	var best: String = model.best_army(model.stage)
	for id in Data.ARMY_ORDER:
		var preset: Dictionary = Data.ARMY_PRESETS[id]
		var edge: float = model.troop_edge(preset["mix"], enemy) * -1.0
		var b := Button.new()
		b.text = tr(preset["name"]) + ("\n" + tr("korban %+d%%") % roundi(edge * 100))
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.add_theme_font_size_override("font_size", 20)
		b.custom_minimum_size = Vector2(0, 76)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.theme_type_variation = "GoldButton" if model.realm["army"] == id else ("GreenButton" if id == best else "")
		var aid: String = id
		b.pressed.connect(func():
			Audio.play("click")
			model.set_army(aid))
		grid.add_child(b)


# --- Pengaturan: kode hadiah ----------------------------------------------------------------

func build_redeem(box: VBoxContainer) -> void:
	var inner: VBoxContainer = ui._inner_box(box)
	ui._label(inner, "Kode Hadiah", "CardLabel").add_theme_font_override("font", UI.font_bold)
	var row := _row(inner)
	_code_edit = LineEdit.new()
	_code_edit.placeholder_text = tr("Masukkan kode")
	_code_edit.max_length = 32
	_code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code_edit.custom_minimum_size.y = 64
	_code_edit.add_theme_stylebox_override("normal", UI.box(UI.INPUT_BG, UI.GOLD_DARK, 2, 12))
	_code_edit.add_theme_color_override("font_color", UI.INK)
	row.add_child(_code_edit)
	_side_button(row, "Tukar", func():
		Online.redeem(_code_edit.text, func(r: Dictionary):
			if r["ok"]:
				Audio.play("reveal_sr")
				_code_edit.text = ""
			ui._show(r))
		return null, true, "GoldButton")
	_small(inner, "Kode dibagikan lewat media sosial dan acara game. Tiap kode hanya bisa dipakai sekali.")


# --- Diplomasi & mata-mata ------------------------------------------------------------------

func show_diplomacy() -> void:
	_show("diplo", "Diplomasi", "diplomacy", _fill_diplomacy)


func _fill_diplomacy(box: VBoxContainer, subtitle: Label) -> void:
	var now: float = Game.now()
	var agent: String = model.spy_agent(now)
	subtitle.text = tr("Utusan tersisa %d · mata-mata tersisa %d") % [model.envoys_left(now), model.spies_left(now)]
	subtitle.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_small(box, tr("Kekuatan Tuan %s · agen terbaik: %s") % [ui._num(model.combat_power()),
		Data.counselor_def(agent)["name"] if agent != "" else "-"]).auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	for k in Data.KINGDOMS:
		var id: String = k["id"]
		var rel: int = model.relation(id)
		var card: HBoxContainer = ui._card(box)
		card.add_child(ui._tex(Art.icon(k["icon"]), 76))
		var col: VBoxContainer = ui._col(card)
		ui._label(col, k["name"], "CardTitle")
		var pw: int = model.kingdom_power(id)
		var power_text: String = ui._num(pw) if model.kingdom_scouted(id, now) else "~" + ui._num(int(round(pw / 1000.0) * 1000))
		var status := []
		if model.realm["diplo"]["trade"].has(id):
			status.append(tr("Dagang"))
		if model.realm["diplo"]["ally"].has(id):
			status.append(tr("Sekutu"))
		var info := _small(col, tr("Hubungan %+d · kekuatan %s") % [rel, power_text] + (" · " + ", ".join(status)
			if not status.is_empty() else ""), UI.GREEN.darkened(0.2) if rel >= 40 else (UI.RED if rel < 0 else UI.INK))
		info.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		var bar: ProgressBar = ui._bar(col, rel + 100, 200, UI.GREEN if rel >= 0 else UI.RED)
		bar.custom_minimum_size.y = 10
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		col.add_child(flow)
		var gift_cost := int(model.affair_yield("silver") * Data.DIPLO_GIFT)
		_mini(flow, tr("Hadiah · %s") % ui._num(gift_cost), func(): return model.send_gift(id, Game.now()),
			model.envoys_left(now) > 0 and model.silver >= gift_cost, "GreenButton")
		_mini(flow, "Minta Upeti", func(): return model.demand_tribute(id, Game.now()), model.envoys_left(now) > 0, "")
		if not model.realm["diplo"]["trade"].has(id):
			_mini(flow, "Perjanjian Dagang", func(): return model.sign_pact(id, "trade"), rel >= Data.DIPLO_TRADE_REL,
				"GoldButton")
		if not model.realm["diplo"]["ally"].has(id):
			_mini(flow, "Persekutuan", func(): return model.sign_pact(id, "ally"), rel >= Data.DIPLO_ALLY_REL, "GoldButton")
		for mission in Data.SPY_ORDER:
			var m: Dictionary = Data.SPY_MISSIONS[mission]
			var mid: String = mission
			_mini(flow, "%s %d%%" % [tr(m["name"]), roundi(model.spy_chance(agent, id, mission) * 100)],
				func(): return model.send_spy(id, mid, Game.now()), model.spies_left(now) > 0 and agent != "", "")


## Tombol kecil di baris aksi.
func _mini(parent: Node, text: String, action: Callable, enabled: bool, variation: String) -> Button:
	var b: Button = ui._button(parent, text, action, enabled, "", variation if enabled else "")
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.text = tr(text) if not text.contains("·") and not text.contains("%") else text
	b.add_theme_font_size_override("font_size", 18)
	b.custom_minimum_size = Vector2(0, 52)
	return b


# --- Pacuan Kuda ------------------------------------------------------------------------------

func show_race() -> void:
	_show("race", "Pacuan Kuda", "race", _fill_race)


func _fill_race(box: VBoxContainer, subtitle: Label) -> void:
	var now: float = Game.now()
	subtitle.text = tr("Pacuan tersisa hari ini: %d / %d") % [model.races_left(now), Data.RACE_PER_DAY]
	if model.horses.is_empty():
		ui._label(box, "Beli kuda di Kandang Kuda (halaman Penasihat) untuk ikut pacuan.", "CardLabel")
		return
	if not model.horses.has(_race_pick):
		var best := ""
		for id in model.horses:
			if best == "" or model.horse_speed(id) > model.horse_speed(best):
				best = id
		_race_pick = best
	for id in Data.HORSE_ORDER:
		if not model.horses.has(id):
			continue
		var card: HBoxContainer = ui._card(box)
		card.add_child(ui._tex(Art.icon("horse_" + id), 84))
		var col: VBoxContainer = ui._col(card)
		ui._label(col, Data.HORSES[id]["name"], "CardTitle")
		_small(col, tr("Level %d · kecepatan %.2f") % [int(model.horses[id]["level"]), model.horse_speed(id)]) \
			.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		var hid: String = id
		var b := _side_button(card, "Terpilih" if id == _race_pick else "Pilih", func():
			_race_pick = hid
			_fill("race")
			return null, true, "GoldButton" if id == _race_pick else "GreenButton")
		b.disabled = false
	var rewards := []
	for i in Data.RACE_REWARDS.size():
		var def: Dictionary = Data.RACE_REWARDS[i]
		rewards.append(tr("Peringkat %d: %s") % [i + 1, ui._reward_text(model._yields_of({"silver": def["silver"]}).merged(
			{"gold": def.get("gold", 0)}))])
	var rl := _small(box, "\n".join(rewards))
	rl.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	ui._button(box, "Mulai Pacuan", func():
		var r: Dictionary = model.go_race(_race_pick, Game.now())
		if not r["ok"]:
			return r
		var view := RaceView.new()
		view.setup(r)
		ui.add_child(view)
		ui.move_child(view, ui._toast.get_index())
		view.finished.connect(ui._queue_rebuild)
		return null, model.races_left(now) > 0, "race", "GoldButton")


# --- Kuis Sejarah -------------------------------------------------------------------------------

func show_quiz() -> void:
	_show("quiz", "Kuis Sejarah Nusantara", "quiz", _fill_quiz)


func _fill_quiz(box: VBoxContainer, subtitle: Label) -> void:
	var now: float = Game.now()
	var qs: Array = model.quiz_today(now)
	subtitle.text = tr("Soal tersisa hari ini: %d / %d") % [model.quiz_left(now), Data.QUIZ_PER_DAY]
	for i in qs.size():
		var q: Dictionary = qs[i]
		var inner: VBoxContainer = ui._inner_box(box)
		ui._label(inner, "%d. %s" % [i + 1, tr(q["q"])], "CardLabel").add_theme_font_override("font", UI.font_bold)
		var state: int = model.quiz_answered(i, now)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		inner.add_child(grid)
		for o in q["options"].size():
			var b := Button.new()
			b.text = q["options"][o]
			b.add_theme_font_size_override("font_size", 19)
			b.custom_minimum_size = Vector2(0, 60)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.clip_text = true
			if state >= 0:
				b.disabled = o != int(q["answer"])
				b.theme_type_variation = "GreenButton" if o == int(q["answer"]) else ""
			var slot: int = i
			var choice: int = o
			b.pressed.connect(func():
				var r: Dictionary = model.answer_quiz(slot, choice, Game.now())
				Audio.play("reveal_sr" if r.get("correct", false) else "error")
				ui._show(r))
			grid.add_child(b)
		if state >= 0:
			_small(inner, "Benar!" if state == 1 else "Kurang tepat.", UI.GREEN.darkened(0.2) if state == 1 else UI.RED)


# --- Penjelajahan Candi -----------------------------------------------------------------------

func show_candi() -> void:
	_show("candi", "Penjelajahan Candi", "candi", _fill_candi)


func _fill_candi(box: VBoxContainer, subtitle: Label) -> void:
	var now: float = Game.now()
	var run: Dictionary = model.candi_run()
	if run.is_empty():
		subtitle.text = tr("Penjelajahan gratis: %d · tambahan: %d") % [model.candi_free_left(now),
			model.candi_extra_left(now) if model.candi_free_left(now) == 0 else Data.CANDI_EXTRA_LIMIT]
		subtitle.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		var card: HBoxContainer = ui._card(box)
		card.add_child(ui._tex(Art.bg("temple"), 160))
		var col: VBoxContainer = ui._col(card)
		ui._label(col, "Candi Kuno di Tengah Hutan", "CardTitle")
		ui._label(col, "Enam ruangan berisi harta, jebakan, dan arca penjaga. Di ruangan terakhir, Buto penjaga candi menunggu.",
			"CardLabel")
		_small(col, tr("Kekuatan Buto penjaga: %s · Tuan: %s") % [ui._num(model.candi_boss_power()),
			ui._num(model.combat_power())]).auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		var free: bool = model.candi_free_left(now) > 0
		var b: Button = ui._button(box, "Masuki Candi" if free else tr("Masuki Candi · %d emas") % Data.CANDI_EXTRA_GOLD,
			func(): return model.enter_candi(Game.now()),
			free or (model.candi_extra_left(now) > 0 and model.gold >= Data.CANDI_EXTRA_GOLD), "candi", "GoldButton")
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		return
	subtitle.text = tr("Ruangan %d dari %d") % [int(run["room"]) + 1, Data.CANDI_ROOMS]
	var stat: VBoxContainer = ui._inner_box(box)
	_small(stat, tr("Semangat %d/%d") % [run["hp"], Data.CANDI_HP])
	ui._bar(stat, run["hp"], Data.CANDI_HP, UI.GREEN if int(run["hp"]) > 40 else UI.RED)
	var loot_text: String = model._reward_list(run["loot"])
	var ll := _small(stat, tr("Harta: %s") % (loot_text if loot_text != "" else "-"))
	ll.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	ui._label(box, "Pilih pintu", "CardTitle")
	var doors: Array = run["doors"]
	var grid := GridContainer.new()
	grid.columns = doors.size()
	grid.add_theme_constant_override("h_separation", 8)
	box.add_child(grid)
	for d in doors.size():
		var kind: String = doors[d]
		var b := Button.new()
		b.text = tr("Buto Penjaga Candi") if kind == "boss" else tr(Data.CANDI_KINDS[kind]["name"])
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.icon = Art.icon("world_boss" if kind == "boss" else Data.CANDI_KINDS[kind]["icon"])
		b.add_theme_constant_override("icon_max_width", 72)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.custom_minimum_size = Vector2(0, 150)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.theme_type_variation = "GoldButton"
		var door: int = d
		b.pressed.connect(func(): _candi_door(door))
		grid.add_child(b)
	ui._button(box, "Keluar Membawa Harta", func(): return model.leave_candi(), true, "chest", "GreenButton", false,
		"coin")


func _candi_door(door: int) -> void:
	Audio.play("click")
	var r: Dictionary = model.candi_choose(door)
	if not r.get("boss", false):
		ui._show(r)
		return
	var ratio: float = r["ratio"]
	var win: bool = r["win"]
	var plan: Dictionary = model.duel_plan(1.0, 1.0, clampf(1.0 - 0.5 / maxf(ratio, 0.2), 0.15, 0.9) if win else 0.0,
		0.0 if win else clampf(1.0 - 0.6 * ratio, 0.1, 0.9), hash(r["msg"]))
	ui._play_duel(plan, {"title": tr("Buto Penjaga Candi"), "me_name": model.me_name(), "them_name": tr("Buto Penjaga"),
		"me_total": model.combat_power(), "them_total": model.candi_boss_power(), "units": ["power", "hp"],
		"me_portrait": model.lord_portrait(), "them_portrait": "boss_buto", "me_weapon": "keris", "them_weapon": "gada",
		"them_big": true, "win": win, "bg": "arena", "detail": r["msg"]})


# --- Besalen (tempa pusaka) ------------------------------------------------------------------

func show_forge() -> void:
	_show("forge", "Besalen", "forge", _fill_forge)


func _fill_forge(box: VBoxContainer, subtitle: Label) -> void:
	subtitle.text = tr("Pusaka di gudang: %d / %d") % [model.equipment.size(), Data.EQUIP_CAPACITY]
	var mats: VBoxContainer = ui._inner_box(box)
	ui._label(mats, "Bahan", "CardLabel").add_theme_font_override("font", UI.font_bold)
	var row := _row(mats)
	for it in ["besi_tempa", "kayu_cendana", "batu_meteor"]:
		row.add_child(ui._tex(Art.icon(Data.ITEMS[it]["icon"]), 48))
		var l: Label = ui._label(row, "%s x%d" % [tr(Data.ITEMS[it]["name"]), model.item_count(it)], "SmallLabel")
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.add_theme_color_override("font_color", UI.INK)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cost := []
	for it in Data.FORGE_COST:
		cost.append("%d %s" % [Data.FORGE_COST[it], tr(Data.ITEMS[it]["name"])])
	cost.append(tr("%s perak") % ui._num(model.forge_silver()))
	_small(mats, tr("Biaya tempa: %s") % ", ".join(cost)).auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var odds: Array = Data.FORGE_ODDS_METEOR if _forge_meteor else Data.FORGE_ODDS
	var mb: Button = ui._button(mats, (tr("Pakai Batu Meteor: ya") if _forge_meteor else tr("Pakai Batu Meteor: tidak"))
		+ " · " + tr("Epik %d%%, Legenda %d%%") % [roundi(float(odds[0]) * 100), roundi(float(odds[1]) * 100)], func():
			_forge_meteor = not _forge_meteor
			_fill("forge")
			return null, model.item_count("batu_meteor") > 0 or _forge_meteor, "mat_meteor", "GoldButton" if _forge_meteor else "")
	mb.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	mb.add_theme_font_size_override("font_size", 20)
	var can: bool = model.silver >= model.forge_silver()
	for it in Data.FORGE_COST:
		can = can and model.item_count(it) >= int(Data.FORGE_COST[it])
	for slot in Data.EQUIP_SLOTS:
		var sd: Dictionary = Data.EQUIP_SLOTS[slot]
		var card: HBoxContainer = ui._card(box)
		card.add_child(ui._tex(Art.icon(sd["icon"]), 72))
		var col: VBoxContainer = ui._col(card)
		ui._label(col, tr("Tempa %s") % tr(sd["name"]), "CardTitle").auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		var sid: String = slot
		_side_button(card, "Tempa", func():
			var r: Dictionary = model.forge(sid, _forge_meteor)
			if r["ok"] and model.item_count("batu_meteor") <= 0:
				_forge_meteor = false
			return r, can and (not _forge_meteor or model.item_count("batu_meteor") > 0), "GoldButton", "upgrade")


# --- Hewan peliharaan ----------------------------------------------------------------------

func show_pets() -> void:
	_show("pets", "Hewan Peliharaan", "pet_elang", _fill_pets)


func _fill_pets(box: VBoxContainer, subtitle: Label) -> void:
	var active := str(model.realm["pets"]["active"])
	subtitle.text = tr("Menemani Tuan: %s") % (tr(Data.PETS[active]["name"]) if active != "" else "-")
	subtitle.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	for id in Data.PET_ORDER:
		var def: Dictionary = Data.PETS[id]
		var lv: int = model.pet_level(id)
		var card: HBoxContainer = ui._card(box)
		card.add_child(ui._tex(Art.icon(def["icon"]), 84))
		var col: VBoxContainer = ui._col(card)
		ui._label(col, def["name"] + (" · Lv %d/%d" % [lv, Data.PET_MAX_LEVEL] if lv > 0 else ""), "CardTitle") \
			.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		var value: float = model.pet_value(id) if lv > 0 else float(def["base"])
		_small(col, tr(def["desc"]) % roundi(value * 100)).auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		var btns := VBoxContainer.new()
		card.add_child(btns)
		var pid: String = id
		if lv <= 0:
			var cost: Dictionary = def["cost"]
			var afford := true
			for k in cost:
				afford = afford and int(model.get(k)) >= int(cost[k])
			_small(col, tr("Harga: %s") % _cost_text(cost)).auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			_side_button(btns, "Pelihara", func(): return model.adopt_pet(pid), afford, "GoldButton", "reveal_sr")
			continue
		if active != id:
			_side_button(btns, "Temani", func(): return model.set_active_pet(pid), true, "GreenButton")
		else:
			_small(col, "Sedang menemani Tuan", UI.GREEN.darkened(0.2))
		if lv < Data.PET_MAX_LEVEL:
			var fc: int = model.pet_feed_cost(id)
			var fb := _side_button(btns, tr("Pakan · %s") % ui._num(fc), func(): return model.feed_pet(pid),
				model.silver >= fc, "GoldButton", "upgrade")
			fb.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED


# --- Online: Bos Dunia -----------------------------------------------------------------------

func show_world_boss() -> void:
	if _need_online():
		return
	_show("wboss", "Bos Dunia", "world_boss", _fill_world_boss)
	_load_world_boss()


func _load_world_boss() -> void:
	Online.fetch_world_boss(func(data: Dictionary):
		_world_boss = data
		if is_open("wboss"):
			_fill("wboss"))


func _fill_world_boss(box: VBoxContainer, subtitle: Label) -> void:
	if _world_boss.is_empty():
		subtitle.text = "Memuat..."
		return
	var wb := _world_boss
	var hp_max := int(wb.get("hp_max", 1))
	var dmg := int(wb.get("damage", 0))
	subtitle.text = tr("Serangan tersisa %d · berakhir dalam %s") % [int(wb.get("attacks_left", 0)),
		ui._duration(int(float(wb.get("ends_in", 0)) / 1000.0))]
	subtitle.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var last: Dictionary = wb.get("last", {})
	var last_week := int(wb.get("last_week", -1))
	if int(last.get("rank", 0)) > 0 and int(model.realm["wb_claimed"]) < last_week:
		var rb: VBoxContainer = ui._inner_box(box)
		ui._label(rb, tr("Minggu lalu Tuan di peringkat %d dari %d penyerang.") % [int(last["rank"]), int(last["players"])],
			"CardLabel").auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		ui._button(rb, "Ambil Hadiah Bos", func(): return model.claim_world_boss(last_week, int(last["rank"]),
			int(last["players"]), bool(last.get("defeated", false))), true, "chest", "GoldButton", false, "reveal_ssr")
	var card: HBoxContainer = ui._card(box)
	card.add_child(ui._tex(Art.portrait("boss_buto"), 120))
	var col: VBoxContainer = ui._col(card)
	ui._label(col, "Buto Ijo Raksasa", "CardTitle")
	_small(col, tr("Nyawa %s / %s") % [ui._num(maxi(0, hp_max - dmg)), ui._num(hp_max)]).auto_translate_mode = \
		Node.AUTO_TRANSLATE_MODE_DISABLED
	ui._bar(col, maxi(0, hp_max - dmg), hp_max, UI.RED)
	if bool(wb.get("defeated", false)):
		_small(col, "Bos sudah tumbang minggu ini! Serangan tetap menambah peringkat.", UI.GREEN.darkened(0.2))
	var me: Dictionary = wb.get("me", {})
	_small(col, tr("Kerusakan Tuan %s · peringkat %d dari %d") % [ui._num(int(me.get("damage", 0))), int(me.get("rank", 0)),
		int(me.get("players", 0))]).auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	ui._button(box, "Serang Bos", func():
		Online.world_boss_attack(func(r: Dictionary):
			if r.has("error"):
				ui._show({"ok": false, "msg": r["error"]})
				return
			var before := float(r.get("hp_before", hp_max)) / maxf(1.0, float(r.get("hp_max", hp_max)))
			var after := maxf(0.0, before - float(r["damage"]) / maxf(1.0, float(r.get("hp_max", hp_max))))
			var plan: Dictionary = model.duel_plan(1.0, before, 0.55, after, int(r["damage"]), 8, 0)
			ui._play_duel(plan, {"title": tr("Bos Dunia"), "me_name": model.me_name(), "them_name": tr("Buto Ijo Raksasa"),
				"me_total": model.combat_power(), "them_total": int(r.get("hp_max", hp_max)), "units": ["power", "hp"],
				"me_portrait": model.lord_portrait(), "them_portrait": "boss_buto", "me_weapon": "keris",
				"them_weapon": "gada", "them_big": true, "win": true, "headline": tr("-%s NYAWA") % ui._num(int(r["damage"])),
				"bg": "arena", "detail": tr("Kerusakan %s untuk Bos Dunia.") % ui._num(int(r["damage"]))})
			_load_world_boss())
		return null, int(wb.get("attacks_left", 0)) > 0, "attack", "GoldButton", false, "attack")
	ui._label(box, "Penyerang Teratas", "CardTitle")
	var top: Array = wb.get("top", [])
	for i in top.size():
		var t: Dictionary = top[i]
		var l := _small(box, "%d. %s — %s" % [i + 1, str(t.get("name", "")), ui._num(int(t.get("damage", 0)))])
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED


# --- Wayang & cerita rakyat ------------------------------------------------------------

func show_wayang() -> void:
	_show("wayang", "Pertunjukan Wayang", "wayang", _fill_wayang)


func _fill_wayang(box: VBoxContainer, subtitle: Label) -> void:
	var now: float = Game.now()
	subtitle.text = "Babak baru siap ditonton!" if model.wayang_ready(now) else "Babak berikutnya besok."
	for t in Data.FOLKTALES:
		var id: String = t["id"]
		var done: int = model.wayang_progress(id)
		var total: int = t["episodes"].size()
		var card: HBoxContainer = ui._card(box)
		card.add_child(ui._tex(Art.icon("wayang"), 80))
		var col: VBoxContainer = ui._col(card)
		ui._label(col, t["name"], "CardTitle")
		_small(col, tr("Cerita rakyat %s · babak %d/%d") % [tr(t["origin"]), done, total]).auto_translate_mode = \
			Node.AUTO_TRANSLATE_MODE_DISABLED
		ui._bar(col, done, total, UI.GOLD)
		var btns := VBoxContainer.new()
		card.add_child(btns)
		if done < total:
			_side_button(btns, tr("Tonton Babak %d") % (done + 1), func():
				var r: Dictionary = model.watch_wayang(id, Game.now())
				if r["ok"]:
					_show_episode(t["name"], int(r["part"]), str(r["episode"]), r["msg"])
					return null
				return r, model.wayang_ready(now), "GoldButton", "reveal_sr").auto_translate_mode = \
				Node.AUTO_TRANSLATE_MODE_DISABLED
		else:
			_small(col, "Tamat", UI.GREEN.darkened(0.2))
		if done > 0:
			_side_button(btns, "Baca Ulang", func():
				var text := []
				for i in done:
					text.append(tr(t["episodes"][i]))
				_show_episode(t["name"], -1, "\n\n".join(text), "")
				return null, true, "")


## Naskah babak wayang dalam panel tersendiri.
func _show_episode(title: String, part: int, text: String, reward: String) -> void:
	var holder := {}
	var p: Dictionary = ui._open_panel(title, "wayang", func():
		Audio.play("click")
		if is_instance_valid(holder.get("overlay")):
			holder["overlay"].queue_free(), 0.1, 0.9)
	holder["overlay"] = p["overlay"]
	p["subtitle"].text = tr("Babak %d") % (part + 1) if part >= 0 else tr("Seluruh babak")
	p["subtitle"].auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var stage := PanelContainer.new()
	stage.add_theme_stylebox_override("panel", UI.box(Color("1e120a"), UI.GOLD, 3, 14))
	p["content"].add_child(stage)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	stage.add_child(v)
	var pic: TextureRect = ui._tex(Art.icon("wayang"), 140)
	pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(pic)
	var l: Label = ui._label(v, text, "")
	l.add_theme_color_override("font_color", UI.PARCHMENT)
	if reward != "":
		var rl: Label = ui._label(p["content"], reward, "CardLabel")
		rl.add_theme_font_override("font", UI.font_bold)


# --- Upacara kerajaan ----------------------------------------------------------------------

func show_ceremony() -> void:
	_show("ceremony", "Upacara Kerajaan", "ceremony", _fill_ceremony)


func _fill_ceremony(box: VBoxContainer, subtitle: Label) -> void:
	var now: float = Game.now()
	var active: String = model.ceremony_active(now)
	var cd: int = model.ceremony_cooldown_days(now)
	if active != "":
		subtitle.text = tr("Berkah %s berlaku %s lagi") % [tr(Data.CEREMONIES[active]["name"]),
			ui._duration(int(float(model.realm["ceremony"]["until"]) - now))]
	elif cd > 0:
		subtitle.text = tr("Upacara berikutnya dalam %d hari") % cd
	else:
		subtitle.text = "Upacara bisa digelar sekarang"
	subtitle.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	for id in Data.CEREMONY_ORDER:
		var def: Dictionary = Data.CEREMONIES[id]
		var cost: Dictionary = model.ceremony_cost(id)
		var card: HBoxContainer = ui._card(box)
		card.add_child(ui._tex(Art.icon(def["icon"]), 80))
		var col: VBoxContainer = ui._col(card)
		ui._label(col, def["name"], "CardTitle")
		ui._label(col, def["desc"], "CardLabel")
		_small(col, tr("Biaya: %s") % _cost_text(cost)).auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		var afford := true
		for k in cost:
			afford = afford and int(model.get(k)) >= int(cost[k])
		var cid: String = id
		_side_button(card, "Berlangsung" if active == id else "Gelar", func(): return model.hold_ceremony(cid, Game.now()),
			cd == 0 and afford, "GoldButton", "promote")


# --- Lencana musiman -------------------------------------------------------------------------

func show_badges() -> void:
	_show("badges", "Lencana Musim", "badge", _fill_badges)


func _fill_badges(box: VBoxContainer, subtitle: Label) -> void:
	var now: float = Game.now()
	var season: int = model.badge_season(now)
	subtitle.text = tr("Musim %d · berakhir dalam %d hari") % [model.badge_season_number(season),
		model.badge_season_days_left(now)]
	subtitle.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var earned: Array = model.badges_earned(season)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	for d in Data.BADGES:
		var cell: VBoxContainer = ui._inner_box(grid)
		cell.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var head := _row(cell)
		var icon: TextureRect = ui._tex(Art.icon(d["icon"]), 52)
		if not earned.has(d["id"]):
			icon.modulate = Color(1, 1, 1, 0.45)
		head.add_child(icon)
		ui._label(ui._col(head), d["name"], "CardLabel").add_theme_font_override("font", UI.font_bold)
		var prog: int = model.badge_progress(d["id"], now)
		ui._bar(cell, prog, d["target"], UI.GOLD)
		_small(cell, (tr("Didapat! +%d emas") % Data.BADGE_GOLD) if earned.has(d["id"]) else "%d / %d" % [prog, d["target"]],
			UI.GREEN.darkened(0.2) if earned.has(d["id"]) else UI.INK).auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var album: Array = model.badge_album()
	ui._label(box, tr("Album Lencana (%d)") % album.size(), "CardTitle").auto_translate_mode = \
		Node.AUTO_TRANSLATE_MODE_DISABLED
	if album.is_empty():
		_small(box, "Belum ada lencana. Lencana yang didapat tampil di profil dan saat kota Tuan dikunjungi.")
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	box.add_child(flow)
	for b in album:
		var d: Dictionary = model.badge_def(b["id"])
		var t: TextureRect = ui._tex(Art.icon(d["icon"]), 56)
		t.tooltip_text = "%s · %s" % [tr(d["name"]), tr("Musim %d") % model.badge_season_number(int(b["season"]))]
		flow.add_child(t)


# --- Online: Turnamen silat ---------------------------------------------------------------

func show_tourney() -> void:
	if _need_online():
		return
	_show("tourney", "Turnamen Silat Online", "tourney", _fill_tourney)
	_load_tourney()


func _load_tourney() -> void:
	Online.fetch_tourney(func(data: Dictionary):
		_tourney = data
		if is_open("tourney"):
			_fill("tourney"))


## Babak tercapai dari jumlah kemenangan: juara selalu indeks terakhir.
func _tourney_round(wins: int, rounds: int) -> int:
	if wins < 0:
		return -1
	return Data.TOURNEY_REWARDS.size() - 1 if wins >= rounds else mini(wins, Data.TOURNEY_REWARDS.size() - 2)


func _fill_tourney(box: VBoxContainer, subtitle: Label) -> void:
	if _tourney.is_empty():
		subtitle.text = "Memuat..."
		return
	var tn := _tourney
	var done: bool = tn.get("phase", "") == "done"
	subtitle.text = tr("%d pendaftar · hasil diumumkan hari Minggu") % int(tn.get("count", 0)) if not done \
		else "Hasil turnamen minggu ini"
	subtitle.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var last_week := int(tn.get("last_week", -1))
	var last_round := _tourney_round(int(tn.get("last_wins", -1)), int(tn.get("last_rounds", 0)))
	if last_round >= 0 and int(model.realm["tourney_claimed"]) < last_week:
		var rb: VBoxContainer = ui._inner_box(box)
		ui._label(rb, tr("Minggu lalu Tuan mencapai %s.") % tr(Data.TOURNEY_ROUND_NAMES[last_round]), "CardLabel") \
			.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		ui._button(rb, "Ambil Hadiah Turnamen", func(): return model.claim_tourney(last_week, last_round), true, "chest",
			"GoldButton", false, "reveal_ssr")
	if not done:
		var reg: bool = tn.get("registered", false)
		ui._label(box, "Daftarkan diri sebelum hari Minggu. 16 pesilat terkuat yang mendaftar akan bertanding.", "CardLabel")
		ui._button(box, "Sudah Terdaftar" if reg else "Daftar Turnamen", func():
			Online.join_tourney(func(ok: bool, msg: String):
				ui._show({"ok": ok, "msg": "Tuan terdaftar di turnamen minggu ini!" if ok else msg})
				_load_tourney())
			return null, not reg, "tourney", "GoldButton")
		var names: Array = tn.get("entrants", [])
		if not names.is_empty():
			_small(box, tr("Peserta teratas: %s") % ", ".join(names)).auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	else:
		var bracket = tn.get("bracket")
		if bracket == null:
			ui._label(box, "Peserta kurang dari dua. Turnamen minggu ini batal.", "CardLabel")
			return
		var rounds: Array = bracket["rounds"]
		var me_round := _tourney_round(int(tn.get("my_wins", -1)), rounds.size())
		if me_round >= 0:
			ui._label(box, tr("Tuan mencapai %s!") % tr(Data.TOURNEY_ROUND_NAMES[me_round]), "CardTitle") \
				.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		for r in rounds.size():
			var rb: VBoxContainer = ui._inner_box(box)
			var rname: String = Data.TOURNEY_ROUND_NAMES[Data.TOURNEY_ROUND_NAMES.size() - 1 - rounds.size() + r]
			ui._label(rb, rname, "CardLabel").add_theme_font_override("font", UI.font_bold)
			for mt in rounds[r]:
				var a = mt.get("a")
				var b = mt.get("b")
				var an := str(a["name"]) if a != null else tr("(bye)")
				var bn := str(b["name"]) if b != null else tr("(bye)")
				var wn := an if a != null and str(a["id"]) == str(mt.get("winner")) else bn
				_small(rb, "%s vs %s → %s" % [an, bn, wn]).auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
