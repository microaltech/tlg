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
	ui._label(inner, "Urusan Kerajaan", "CardTitle")
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	inner.add_child(grid)
	var online: bool = Online.is_online()
	var tiles := [
		["Perburuan", "hunt", model.hunt_unlocked(), Data.HUNT_UNLOCK_STAGE, model.hunts_left(now), show_hunt],
		["Pasar Malam", "market", model.market_unlocked(), Data.MARKET_UNLOCK_STAGE, 0, show_market],
		["Kebijakan", "policy", model.policy_unlocked(), Data.POLICY_UNLOCK_STAGE,
			1 if not model.disaster_active().is_empty() else 0, show_policy],
		["Kebun", "garden", model.garden_unlocked(), Data.GARDEN_UNLOCK_STAGE, model.garden_ready_count(now), show_garden],
		["Perpustakaan", "research", model.research_unlocked(), Data.RESEARCH_UNLOCK_STAGE,
			1 if model.research_unlocked() and model.research_job().is_empty() else 0, show_research],
		["Armada", "ship", model.fleet_unlocked(), -1, _fleet_ready(now), show_fleet],
		["Besan", "ring", true, 0, _adult_count() + (1 if model.kin_gift_ready(now) else 0), show_kin],
		["Teman", "friends", true, 0, _friends.get("inbox", []).size() if online else 0, show_friends],
		["Perang Wilayah", "war_flag", true, 0, int(_guildwar.get("attacks_left", 0)) if online else 0, show_guildwar],
	]
	for t in tiles:
		var unlocked: bool = t[2]
		var fn: Callable = t[5]
		var label: String = tr(t[0])
		if unlocked and int(t[4]) > 0:
			label += " (%d)" % int(t[4])
		elif not unlocked:
			label = tr("Tahap %d") % int(t[3]) if int(t[3]) >= 0 else tr("%d wilayah") % Data.FLEET_UNLOCK_REGIONS
		var b := Button.new()
		b.text = label
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.icon = Art.icon(t[1])
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.add_theme_constant_override("icon_max_width", 56)
		b.add_theme_font_size_override("font_size", 19)
		b.custom_minimum_size = Vector2(0, 112)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.theme_type_variation = "GoldButton" if unlocked and int(t[4]) > 0 else ("" if unlocked else "GreenButton")
		b.disabled = not unlocked
		b.clip_text = true
		b.pressed.connect(func():
			Audio.play("click")
			fn.call())
		grid.add_child(b)


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
		"them_portrait": "enemy_bandit", "win": r["win"], "detail": r["msg"], "bg": "sea",
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
